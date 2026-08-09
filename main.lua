-- DRAMATIC SHAPE VOXEL MOD BATTLE ART: a full 3D diorama overworld, shipped as a
-- rendering pipeline mod.
--
-- The engine's render_pipelines registry (src/mods/Schemas.lua) lets a mod
-- own part of the frame.  This mod registers two:
--
--   voxel      a drawWorld pipeline.  Instead of the flat tile blit, the
--              overworld's terrain is extruded into real geometry, walked
--              by a depth-buffered 3D camera, with characters as leaning
--              sprite slabs and a shadow map throwing real cast shadows
--              across whatever they land on.  Occlusion is the depth
--              buffer, not a y-sort: walk behind a building and the
--              building is simply in front.
--
--   tiltshift  a worldPresent pipeline -- the stage that post-processes
--              the finished world BEFORE the UI composites over it.  A
--              tilt-shift blur that sells the miniature-model look, on the
--              diorama only, leaving text boxes and menus crisp.
--
-- Everything a display mode needs beyond the two draw functions -- the
-- OFF/15/35/50 ladder, the options rows, the hotkeys, persistence in
-- save.options.pipelines, the free-roam gate, the mutual exclusion with
-- the engine's TILT mode -- is engine plumbing driven by the records
-- below.  This file declares; lib/ draws.
--
-- Voxel mode is presentational: it changes what the world LOOKS like and
-- nothing about what it IS.  ONE rung is the deliberate exception. 1ST --
-- the first-person camera -- replaces the grid WALK with a free,
-- camera-relative one while it is selected (lib/FreeMove.lua), because a
-- head you can steer with a mouse demands feet that go where it looks.
-- Even there the game is untouched: the walk asks the engine's own
-- collision the same questions a grid step asks, keeps the player's
-- logical cell synced, and fires the engine's own landing pipeline per
-- cell crossed -- warps, encounters, ledges, gates and scripts all run
-- exactly as themselves. Step off the rung and the grid walk is back.

local mod = ...

-- ------- the mod namespace
--
-- lib/ modules require each other through V rather than package.path: a
-- mod directory is not on it, and may live inside a mounted .love archive
-- that plain require cannot reach.  Each module is loaded once, with V
-- passed in as its vararg (`local V = ...`).

local V = { mod = mod, path = mod.path }

local function chunkFor(rel)
  local source = mod:read(rel)
  if not source then
    error(("BATTLE_ART_VOXEL_FORK: %s is missing -- reinstall the mod"):format(rel), 0)
  end
  local chunk, err = load(source, "@" .. mod.path .. "/" .. rel)
  if not chunk then
    error(("BATTLE_ART_VOXEL_FORK: %s did not compile: %s"):format(rel, tostring(err)), 0)
  end
  return chunk
end

local modules = {}
function V.require(name)
  local hit = modules[name]
  if hit ~= nil then return hit end
  local value = chunkFor("lib/" .. name .. ".lua")(V)
  modules[name] = value
  return value
end

local dataFiles = {}
function V.data(name)
  local hit = dataFiles[name]
  if hit ~= nil then return hit end
  local value = chunkFor("data/" .. name .. ".lua")(V)
  dataFiles[name] = value
  return value
end

-- ------- pipelines

local Voxel = V.require("VoxelState")
local Voxel3D = V.require("Voxel3D")
local VoxelScene = V.require("VoxelScene")
local TiltShift = V.require("TiltShift")
local ChunkMesher = V.require("ChunkMesher")
local VoxelGrid = V.require("VoxelGrid")
local WorldCurve = V.require("WorldCurve")
local OverworldBattle = V.require("OverworldBattle")
local BattleArt = V.require("BattleArt")
local UiBackplates = V.require("UiBackplates")
local BattleExit = V.require("BattleExit")
local DayNight = V.require("DayNight")
local DayTint = V.require("DayTint")
local Water = V.require("Water")
local AntiAlias = V.require("AntiAlias")
local FirstPerson = V.require("FirstPerson")
local FreeMove = V.require("FreeMove")

-- Forward declaration: the voxel pipeline's update hook (registered below)
-- calls this, and it is defined further down with the settings it drives.
-- Declared rather than left global -- a mod writing to _G would leak into
-- every other mod's namespace.
local applyFull

-- The last VOID FILL the terrain was meshed under; see the update hook.
-- The scene canvas's size, in FRAMEBUFFER PIXELS.
--
-- `ctx.width/height` are the window measured in LOVE UNITS
-- (love.graphics.getDimensions), but the engine composites a pipeline's
-- returned canvas with `draw(canvas, 0, 0, 0, 1/dpiX, 1/dpiY)` -- a scale
-- that only covers the window when the canvas is at PIXEL resolution.
-- Sizing it in units costs the DPI scale TWICE: the canvas is that much
-- smaller, then it is drawn that much smaller again, so the diorama lands
-- in the top-left corner at 1/dpi of the screen.  Desktop never sees it --
-- units and pixels are the same thing there -- but on Android the DPI scale
-- is the display density (2.625 on a 420dpi panel), and the world came out
-- a third of the size in each direction.
--
-- So ask for the pixel dimensions rather than trusting the ctx.  That is
-- the number a fixed engine would hand over, so this keeps working either
-- way instead of double-correcting.  It also squares the FX pass: ctx.scale
-- is ALREADY in pixels per world pixel (Zoom.scale over Renderer:fitScale,
-- which measures the drawable), so the closures ctx.drawFx runs were being
-- scaled for a canvas 2.6x bigger than the one they drew into.
local function sceneSize(ctx)
  if love.graphics and love.graphics.getPixelDimensions then
    local pw, ph = love.graphics.getPixelDimensions()
    if pw and ph and pw > 0 and ph > 0 then return pw, ph end
  end
  return ctx.width, ctx.height
end

local voidFill = { last = nil }
function voidFill.check()
  local TileRenderer = require("src.render.TileRenderer")
  local now = TileRenderer.voidFill
  if voidFill.last ~= nil and now ~= voidFill.last then
    ChunkMesher.invalidate()   -- no map id: every ring on every map is stale
  end
  voidFill.last = now
end

mod.content.render_pipelines:register("voxel", {
  label = "VOXEL",
  levels = Voxel.ANGLE_LABELS,
  -- 3 is the engine's TILT key, which this mode supersedes -- see the
  -- hotkey block near the bottom of this file for how it is claimed
  hotkey = "3",
  -- above tiltshift, so the two sort together in the options list with the
  -- mode first and its post-process under it
  priority = 20,

  -- Headless runs and drivers without a depth canvas or shader support
  -- answer false here, and the engine keeps the vanilla 2D path -- which
  -- is why no caller ever has to guard for a missing 3D pass.
  available = function()
    return Voxel3D.available()
  end,

  -- the engine hands over the live level; we ease the camera toward it.
  -- pump() advances queued mesh builds inside a few-millisecond budget,
  -- so entering voxel mode (and streaming neighbours while walking)
  -- costs frames nothing visible -- the old synchronous build froze the
  -- first frame for seconds. prefetch() runs here as well as in the
  -- draw, because update ticks even while a warp's Transition covers
  -- the screen: the destination's meshes start building the moment the
  -- map swaps behind the fade, and the fade-covered frames get a wider
  -- pump slice -- so stepping out of a door lands on terrain that is
  -- already there instead of a flat flash.
  update = function(dt, level)
    -- BATTLE BG must be WHITE whenever this mode is on: WORLD is only valid
    -- for the engine's flat 2D battle and composites as broken dark bars with
    -- the 3D diorama (there is no "old system" to show through). Force it at
    -- the top of every update tick -- not gated on FULL -- so a boot that
    -- starts already at FULL, and the first battle before any transition, are
    -- both covered. Persists on change only, never every frame.
    local Game = require("src.core.Game")
    local o = Game.save and Game.save.options
    if o and o.battleBg ~= "white" then
      o.battleBg = "white"
      if Game.writeOptions then pcall(Game.writeOptions, Game) end
    end
    -- FULL is a preset, so it is applied ON THE PRESS rather than held every
    -- frame: it SETS the other rows and then leaves them alone. Holding them
    -- would make the zoom keys and the wheel dead while the mode was on, and
    -- would fight anyone who changed one deliberately.
    applyFull(level)
    Voxel.update(dt, level)
    -- the first-person head, on the same tick: its blend in and out of the
    -- orbit, the mouse capture lifecycle, and the frame's stick-rate look.
    -- Unconditional like Voxel.update, because the blend has to keep easing
    -- OUT after the rung is left
    FirstPerson.update(dt)
    -- the day/night clock, on the same always-running tick: Pipelines.update
    -- runs whatever the level, so time passes with the mode off, through
    -- battles and menus, and a CYCLE evening falls mid-fight exactly as it
    -- would mid-walk
    DayNight.update(dt)
    -- The overworld battle rides this hook rather than owning a pipeline of
    -- its own, because it owns no pass of the FRAME: it draws under a battle
    -- screen the engine composites, which is not a stage the registry has.
    -- What it needs is a tick that keeps running once the overworld stops
    -- being the top state, and this is one -- Game:update calls
    -- Pipelines.update unconditionally, so it survives the transition wipe
    -- and the whole battle. Ahead of the active() gate below, because a 3D
    -- battle does not require the free-roam mode to be switched on.
    OverworldBattle.update(dt)
    -- VOID FILL picks the block the border ring is made of, and in this
    -- mode that ring is BAKED INTO THE MESH rather than drawn each frame.
    -- So the option has to reach the cache or nothing happens on screen
    -- until the meshes are dropped for some other reason -- which reads
    -- exactly like the option doing nothing at all. Polled rather than
    -- hooked because the engine changes it from three places (the options
    -- row, applyOptions on load, TileRenderer.setVoidFill) and none of
    -- them announces it. Ahead of the active() gate, so switching it
    -- while voxel mode is OFF still invalidates what is cached.
    voidFill.check()
    if not Voxel.active() then return end
    local Game = require("src.core.Game")
    local ow = Game and Game.overworld
    if ow and ow.map and ow.camera then
      pcall(VoxelScene.prefetch, ow)
    end
    ChunkMesher.pump(Game and Game.stack
                     and Game.stack:top() ~= ow)
  end,

  drawWorld = function(ctx)
    -- Terrain and characters are geometry; the field FX stay ordinary 2D
    -- draws composited on top, anchored through the same camera the 3D
    -- pass used (ctx.drawFx below).  The scene renders at the window's
    -- PIXEL resolution (see sceneSize) so the 3D pass is crisp rather than
    -- a magnified low-res image, while the FX closures keep drawing in
    -- world-pixel units.
    local sw, sh = sceneSize(ctx)
    -- With AA on, the whole pass runs into a canvas BIGGER than the window
    -- and is folded back down at the end (see AntiAlias).  Nothing between
    -- these two lines knows: every pass in the frame measures itself in the
    -- canvas it was handed, so the sky's dither, the water's march and the
    -- camera itself all come out the same picture at a higher sample rate.
    local rw, rh = AntiAlias.expand(sw, sh)
    local canvas = VoxelScene.render(ctx.state, rw, rh,
                                     ctx.vw, ctx.vh, ctx.paletteFor)
    if not canvas then return nil end   -- fall back to the 2D path
    if Voxel3D.beginOverlay() then
      -- the FX closures are ordinary 2D draws sized in DISPLAY pixels, and
      -- they are drawing into the supersampled canvas alongside everything
      -- else -- so the scale goes up with it, or the "!" bubble lands the
      -- right place at half the size.  project() already answers in canvas
      -- pixels, so only the scale needs saying.
      ctx.drawFx(function(wx, wy) return Voxel3D.project(wx, 0, wy) end,
                 ctx.scale * AntiAlias.factor())
      Voxel3D.endOverlay()
    end
    -- and back to the window's own size, which is what the engine composites
    -- one canvas pixel to one display pixel.  A pass-through when AA is off.
    return AntiAlias.resolve(canvas, sw, sh, "world")
  end,

  invalidate = function()
    Voxel3D.invalidate()
    OverworldBattle.invalidate()
    AntiAlias.invalidate()
    ChunkMesher.invalidate()   -- no map id = every cached mesh
  end,
})

mod.content.render_pipelines:register("tiltshift", {
  label = "T-SHIFT",
  levels = TiltShift.LABELS,
  -- 6 is free: no engine branch claims it, so this one alone reaches the
  -- registry by the documented route
  hotkey = "6",
  priority = 10,

  update = function(dt, level)
    TiltShift.update(dt, level)
  end,

  -- worldPresent, not present: the blur belongs on the diorama, not on the
  -- dialog box in front of it.  A pass-through when the level is 0 or the
  -- shader is unavailable, so the frame is untouched in every other case.
  worldPresent = function(canvas)
    return TiltShift.apply(canvas)
  end,

  invalidate = function()
    TiltShift.invalidate()
  end,
})

-- ------- this mod's own settings
--
-- Neither of these is a pipeline: they own no pass of the frame, they
-- PARAMETERISE the voxel one, so they have nothing to put in drawWorld or
-- present and the registry would rightly reject them.  Plain mod settings
-- instead -- see ModSetting for where they persist and how the two rows
-- each ends up on stay in step.

-- ------- the FULL preset
--
-- Everything the mode wants switched to at once. Applied when the VOXEL row
-- ARRIVES at FULL and not again, so the player can still move the camera or
-- the zoom afterwards -- it is a starting point, not a lock.
--
-- Leaving FULL deliberately does NOT undo any of it. A preset that reverted
-- would throw away whatever the player had changed since, and "put it back
-- how it was" is not a thing this can know.
local fullWas = nil

applyFull = function(level)
  local isFull = Voxel.isFull(level)
  local was = fullWas
  fullWas = isFull
  if not isFull or was == true or was == nil then return end

  local Game = require("src.core.Game")
  local Pipelines = require("src.render.Pipelines")
  local Zoom = require("src.render.Zoom")
  local opts = Game.save and Game.save.options
  if not opts then return end

  -- the miniature blur at its strongest: FULL is the diorama look, and the
  -- tilt-shift is most of what makes it read as a model
  Pipelines.setLevel("tiltshift", Pipelines.maxLevel("tiltshift"))
  Pipelines.syncOptions(opts)
  -- the horizon flat. The curve bends the world away from a walking player,
  -- which fights a fixed diorama framing
  WorldCurve.setting:setIndex(1, Game)
  -- and the water reflecting everything it can: FULL is the diorama at its
  -- most photographed, and a lake with the sky and the shoreline in it is
  -- most of what makes the model read as being outdoors
  Water.setting:setIndex(1, Game)
  -- and the view fitted to the window
  opts.zoom = 0
  Zoom.applyOptions(opts)
  -- battles on the map too: FULL means the whole mode, and a fight is where
  -- half of it is spent. Set and then LET GO of -- unlike the rows above, both
  -- battle rows stay on the menu under FULL (see the rows hook), so this is
  -- where the preset puts them and not where they are held.
  OverworldBattle.setting:setIndex(1, Game)
  -- default to the player's front view, with both battlers world-placed.
  BattleArt.viewSetting:setIndex(1, Game)
  -- and the battle screen the staged fight is composed for. WIDE re-lays that
  -- screen out on a 304x144 surface, which moves every anchor the arena camera
  -- is solved against (OverworldBattle.forceOG); FULL has just switched staged
  -- fights on, so the layout follows them.
  OverworldBattle.forceOG(Game)
  -- BATTLE BG: WORLD leaves the frozen overworld showing through a battle and
  -- is only valid for the engine's flat 2D battle; with the 3D diorama there
  -- is no "old system" to show through, so WORLD composites as broken dark
  -- bars. Force WHITE (the opaque paper field) for every user, since the mode
  -- cannot render the world-behind-battle path at all.
  opts.battleBg = "white"
  -- and the sky on the clock on the wall: FULL pins DAYTIME to SYNC. Unlike
  -- the rest of the preset this one IS held, not just set -- the row is off
  -- the menu while FULL owns it (the rows hook below), so a value changed
  -- under it could never be seen or changed back.
  DayNight.forceSync(Game)
  if Game.writeOptions then pcall(Game.writeOptions, Game) end
end

-- Whether a fight can be staged on the map, as far as the OPTIONS menu is
-- concerned: the 3D-BTL row, and nothing else.
--
-- It used to answer yes under FULL as well, on the grounds that FULL owned
-- that row and switched it on. FULL no longer owns it -- the row stays on the
-- menu under FULL and can be switched off there (see the rows hook) -- so that
-- clause would now claim staged battles for a preset the player had just
-- turned them off inside, pinning BATTLE LAYOUT to OG for a fight that is
-- never staged. The row is the only thing that decides, which is what every
-- other reader of this setting already believed: OverworldBattle.begin and
-- wantsFront both gate on enabled() alone.
--
-- Deliberately NOT gated on Voxel3D.available(): the engine offers a
-- pipeline's row whether or not the hardware can run it (Pipelines.rows), so
-- this mode's rows say ON on a machine without a depth buffer too, and a menu
-- that claims 3D battles are on must not also offer the layout they cannot be
-- drawn in.
local function stagedBattles()
  return OverworldBattle.enabled()
end

local SETTINGS = {
  { VoxelGrid.setting, "One-pixel wireframe along every voxel edge." },
  { WorldCurve.setting,
    "Bend the world down over the horizon, Animal Crossing style." },
  { Water.setting,
    "Reflections on water. FULL adds screen-space reflections of the "
    .. "shoreline, the trees and the buildings behind it; SKY is the sky, "
    .. "the sun and the moon alone, which is most of the look for a "
    .. "fraction of the cost." },
  -- `full` marks a row FULL does not take away. FULL owns the diorama's own
  -- knobs; what a battle is drawn over, and how it is framed, are not that.
  { OverworldBattle.setting,
    "Fight on the map: the battle draws over the nearest clear ground, "
    .. "shot over the shoulder with a slow parallax drift.",
    full = true },
  -- HUD SCALE lives with the battle rows: SCALED is the mod's default HUD
  -- (it grows with the battle zoom); OG pins it to the window-fit scale like
  -- upstream gen1recomp's player HUD, so an external XP-bar mod -- which this
  -- mod does NOT provide -- lines up with a window-scaling HUD.
  { OverworldBattle.hudScaleSetting,
    "Size of the player and opponent HUD. SCALED grows with the battle "
    .. "zoom (the mod default); OG pins it to the window-fit scale like "
    .. "upstream gen1recomp's player HUD, so an external XP-bar mod -- which "
    .. "this mod does not include -- lines up with a window-scaling HUD.",
    full = true },
  -- Only offered while a fight can actually be staged on the map.
  { BattleArt.setting,
    "Use optional PNGs from assets/battle in fights. Missing art falls "
    .. "back to the ROM. STATIC is the zero-configuration default.",
    when = function() return stagedBattles() end, full = true },
  { BattleArt.trainerSetting,
    "Choose the static opponent trainer collection. A class missing from "
    .. "the selected generation falls back directly to its ROM portrait.",
    when = function()
      return stagedBattles() and BattleArt.setting:get() ~= "rom"
    end, full = true },
  { BattleArt.playerArtSetting,
    "Choose the player trainer's static battle-intro portrait. A missing "
    .. "named choice tries player.png, then ROM. PNG uses player.png "
    .. "directly. BATTLE ART: ROM pins this row to ROM.",
    when = function()
      local mode = BattleArt.setting:get()
      return stagedBattles() and (mode == "static" or mode == "rom")
    end, full = true },
  { BattleArt.playerAnimationSetting,
    "Choose player.png as a static portrait or a five-frame player trainer "
    .. "atlas under ANIMATED. Atlas playback starts with the leftward intro "
    .. "slide, runs once, and never loops. Missing art and ROM retain the "
    .. "engine portrait.",
    when = function()
      return stagedBattles() and BattleArt.setting:get() == "animated"
    end, full = true },
  { BattleArt.frontAnimationSetting,
    "Choose the front generation used by BATTLE ART: ANIMATED. GEN 1 reads "
    .. "single-frame PNGs; GEN 2-5 read atlases. STATIC ignores this row. "
    .. "Missing art falls directly back to ROM.",
    when = function()
      return stagedBattles() and BattleArt.setting:get() == "animated"
    end, full = true },
  { BattleArt.backAnimationSetting,
    "Choose the player back-art generation. STATIC reads only a PNG from "
    .. "back-static/GEN for every choice. ANIMATED reads static GEN 1, 2, "
    .. "and 4 PNGs, or animated GEN 3 and 5 atlases. Missing art falls "
    .. "back to the ROM.",
    when = function()
      return stagedBattles() and BattleArt.setting:get() ~= "rom"
    end, full = true },
  { BattleArt.frontShinySetting,
    "When ON, front sprites are read from assets/battle/front-static/shiny "
    .. "or front-animated/shiny first. A missing shiny file falls back to the "
    .. "selected generation's normal front, then to ROM. Keep the shiny "
    .. "folders empty for a shiny mod to populate.",
    when = function() return stagedBattles() end, full = true },
  { BattleArt.backShinySetting,
    "When ON, back sprites are read from assets/battle/back-static/shiny or "
    .. "back-animated/shiny first. A missing shiny file falls back to the "
    .. "selected generation's normal back, then to ROM. Players can never be "
    .. "shiny, so this never touches the player's own portrait.",
    when = function()
      return stagedBattles() and BattleArt.setting:get() ~= "rom"
    end, full = true },
  { BattleArt.viewSetting,
    "Show the player's Pokemon from the front or back. Supplied art stays "
    .. "world-placed; a missing selected back falls back to the ROM UI pic.",
    when = function() return stagedBattles() end, full = true },
  { BattleArt.backPlacementSetting,
    "Place player back art automatically, force it into the 3D world, or "
    .. "use gen1recomp's OG UI anchor. AUTO keeps STATIC fallbacks in the "
    .. "world and ANIMATED/ROM fallbacks on the UI.",
    when = function() return stagedBattles() end, full = true },
  { DayNight.setting,
    "What time it is outdoors: pin the sky to DAY, NIGHT, DUSK or DAWN, "
    .. "let CYCLE run it -- ten minutes of sun, ten of moon, with the "
    .. "shadows, the sky and the light following -- or SYNC it to the "
    .. "clock on the wall, so Kanto's evening falls when yours does." },
  -- ------- 1.66 UI backplates (see lib/UiBackplates.lua) -------
  { UiBackplates.spriteLight,
    "SHADED lets the mons receive the world's day tint and cast shadows; "
    .. "UNLIT draws them flat and full bright. UNLIT is what the white "
    .. "arena fill needs, and what the OG battle's sprites look like.",
    when = function() return stagedBattles() end, full = true },
  { UiBackplates.arenaFill,
    "WHITE draws a solid white layer in front of the whole voxel world, "
    .. "with only the mons, their attack animations and the menus above it "
    .. "-- the step between the OG battle and the full 3D one. Forces SPRITE "
    .. "LIGHT: UNLIT so the sprites stay flat and true-colour with no night "
    .. "tint (as in the traditional games).",
    when = function() return stagedBattles() end, full = true },
  -- The battle box is ALWAYS an opaque white panel with black ink (see
  -- BattleState:drawTextArea), so TEXTBOX FILL was dropped -- no option row.
  -- Marked `full` for the opposite reason the battle rows are: this is not a
  -- knob on the look at all, it is what the look COSTS. FULL is a preset for
  -- the diorama, not a licence to spend four times the fill rate on the
  -- machine it happens to be running on, so it neither sets this nor takes
  -- the row away -- the player decides what their hardware can carry, from
  -- inside FULL like anywhere else.
  { AntiAlias.setting,
    "Smooth the stair-stepped edges of the 3D world -- roof ridges, ledge "
    .. "lips, a tree against the sky -- by rendering the diorama larger than "
    .. "the window and folding it back down. Every edge in the picture "
    .. "softens with them, the tileset's own texels included, so the diorama "
    .. "reads smoother rather than sharper. 2X costs half again as many "
    .. "pixels in each direction and 4X twice, which makes this the most "
    .. "expensive row in the mod.",
    full = true },
}

local schema = {}
for i, entry in ipairs(SETTINGS) do
  schema[i] = entry[1]:schema(entry[2])
end
mod.options:define(schema)

-- ------- this mod's hotkeys
--
--   3  VOXEL    cycle the camera ladder      (was 6; skips FULL)
--   5  V-GRID   toggle the wireframe         (new)
--   6  T-SHIFT  cycle the blur ladder        (was 9)
--   7  V-CURVE  cycle the horizon bend       (new)
--   8  3D-BTL   toggle overworld battles     (new)
--   9  WATER    cycle the water reflections  (new; 9 was T-SHIFT's old key)
--
-- Only 6 arrives by the documented route. Game:keypressed answers the
-- engine's own display keys FIRST and returns -- 2 COLORS, 3 TILT, 4 ZOOM,
-- 5 GBC FX -- and only then offers the key to Pipelines.hotkey, expressly
-- so "a pipeline can never shadow one" (Schemas, render_pipelines.hotkey).
-- 3 and 5 are two of those, and 7 and 8 belong to plain mod settings that
-- own no pass and so have no registry to claim a key from at all.
--
-- So this wraps Game:keypressed. It is the invasive option and it is the
-- only one: polling the keyboard in update() would fire alongside the
-- engine's handler rather than instead of it, so 3 would cycle this mode
-- AND the engine's TILT on the same press.
--
-- Consequences worth being explicit about: while this mod is enabled, TILT
-- (3) and GBC FX (5) are unreachable by key -- and unreachable on the OPTIONS
-- menu too, where both rows are taken away and both values held at zero (see
-- pinEngineFx). Nothing is being hidden that still does something: TILT is the
-- flat fake of what this mode does for real, the registry already forces it
-- off whenever a world pipeline takes the pass, and GBC FX is a full-screen
-- present pass over the top of the diorama. Uninstalling puts both back.
--
-- Everything the engine does around a pipeline hotkey has to happen here
-- too, so the work is DELEGATED rather than reimplemented: Pipelines.hotkey
-- applies its own gate and ladder, and the three lines after it are the
-- engine's own (syncOptions, the tilt exclusion, writeOptions).

local HOTKEYS = {
  ["3"] = "pipeline",           -- voxel, by its declared hotkey
  ["6"] = "pipeline",           -- tiltshift, likewise
  ["5"] = VoxelGrid.setting,
  ["7"] = WorldCurve.setting,
  ["8"] = OverworldBattle.setting,
  ["9"] = Water.setting,
}

do
  local Game = require("src.core.Game")
  local Pipelines = require("src.render.Pipelines")
  local inner = Game.keypressed

  function Game:keypressed(key)
    local claim = HOTKEYS[key]
    local top = self.stack and self.stack:top()
    -- A screen with its own key handler gets the key first, exactly as the
    -- engine's first branch does: typing a nickname must not toggle a
    -- render mode. Only free-roam presses are ours to take.
    if claim and not (top and top.onKeyPressed) then
      if claim == "pipeline" then
        -- 3 walks the ANGLE rungs and steps over FULL (Voxel.HOTKEY_ORDER),
        -- so the registry's plain "advance one and wrap" is not what it
        -- wants; 6 still is. The gate is the registry's own either way.
        local stepped = false
        if key == "3" then
          if Pipelines.canToggle("voxel", top, self.overworld) then
            Pipelines.setLevel("voxel",
              Voxel.nextHotkeyLevel(Pipelines.level("voxel")))
            stepped = true
          end
        else
          stepped = Pipelines.hotkey(key, top, self.overworld) and true
        end
        if stepped then
          Pipelines.syncOptions(self.save.options)
          -- 3 is the key that used to turn TILT on and sits next to the one
          -- that used to turn GBC FX on, and this mod has taken both away.
          -- A player who left either running before enabling the mod would
          -- otherwise have no way back to off, and both fight the diorama:
          -- TILT is the flat fake of what this mode does for real, and GBC
          -- FX is a full-screen present pass over the top of it. So the
          -- VOXEL key clears them on EVERY press, not just the press that
          -- switches the mode on -- cycling back round to OFF leaves them
          -- off too, which is the state the key is now the only route to.
          if key == "3" then
            self.save.options.tilt = 0
            self.save.options.gbcfx = 0
            require("src.render.GBCFX").setLevel(0)
          end
          require("src.render.Tilt").setLevel(self.save.options.tilt or 0)
          self:writeOptions()
          return
        end
      elseif Pipelines.canToggle("voxel", top, self.overworld) then
        -- All four answer to the voxel pass's own free-roam gate --
        -- borrowed from the registry rather than restated, so a press
        -- mid-warp or mid-cutscene is refused for the wireframe exactly when
        -- it would be for the mode itself. Three of them parameterise that
        -- pass; the fourth (3D-BTL) decides what a battle is drawn over, and
        -- wants the same gate for a different reason: the answer is read
        -- when the fight starts, so flipping it from inside one would be a
        -- switch that appeared to do nothing.
        claim:cycle(self)
        -- 8 is one of the two ways staged battles get switched on, and they
        -- pin BATTLE LAYOUT to OG (see the rows hook). The other keys
        -- parameterise the pass and leave the layout alone; the guard answers
        -- for all of them, so nothing here has to know which key it was.
        if stagedBattles() then OverworldBattle.forceOG(self) end
        return
      end
    end
    return inner(self, key)
  end
end

-- ------- the mode's rows, kept together
--
-- The engine splices a pipeline's row in beside TILT, because a display mode
-- belongs with the other display modes; a mod's own ui.options.rows
-- additions land at the END of the list. That left this mod's four rows in
-- two places with unrelated engine rows between them, which reads as two
-- unrelated features rather than one mode with settings.
--
-- So the plain settings are inserted directly after the last of this mod's
-- PIPELINE rows instead of appended. Nothing else moves: the block lands
-- where the engine already decided display modes go.
local function insertGrouped(out, extra)
  local anchor = nil
  for i, row in ipairs(out) do
    local id = type(row) == "table" and row.id
    if id == "pipeline:voxel" or id == "pipeline:tiltshift" then anchor = i end
  end
  if not anchor then
    for _, row in ipairs(extra) do out[#out + 1] = row end
    return out
  end
  for i, row in ipairs(extra) do table.insert(out, anchor + i, row) end
  return out
end

-- FULL owns the settings that describe the LOOK, so while it is selected those
-- are taken off the menu rather than left to be changed under it -- including
-- T-SHIFT, which is a pipeline row the engine put there. A row that no longer
-- decides anything is worse than no row.
--
-- The battle rows are the exception and they stay; see the rows hook.
local function dropRow(out, id)
  for i = #out, 1, -1 do
    if type(out[i]) == "table" and out[i].id == id then table.remove(out, i) end
  end
  return out
end

-- ------- TILT and GBC FX are gone while this mod is installed
--
-- Both fight the diorama, and both were already half-taken: the mode's own key
-- (3) forces them off on every press, and the registry switches TILT off
-- whenever a world pipeline takes the pass. What was left was two rows the
-- player could set and watch get reverted -- TILT is the flat fake of what
-- this mode does for real, and GBC FX is a full-screen present pass over the
-- top of the whole thing.
--
-- So they come OFF the menu, and are HELD at zero rather than merely dropped.
-- Hiding a live setting is a trap: a save written before the mod was installed
-- can carry TILT 3, and a row that is not there is a row that cannot turn it
-- back off. Pinned wherever the value could have arrived from -- the menu
-- opening, a save being loaded or begun -- so there is no route by which one
-- of them is on and unreachable.
--
-- Everything they did is still reachable: uninstall the mod and both rows are
-- back, at whatever they were last set to.
local function pinEngineFx(game)
  game = game or require("src.core.Game")
  local opts = game and game.save and game.save.options
  local Tilt = require("src.render.Tilt")
  local GBCFX = require("src.render.GBCFX")
  local changed = false
  if opts then
    changed = (opts.tilt or 0) ~= 0 or (opts.gbcfx or 0) ~= 0
    opts.tilt, opts.gbcfx = 0, 0
  end
  pcall(Tilt.setLevel, 0)
  pcall(GBCFX.setLevel, 0)
  if changed and game.writeOptions then pcall(game.writeOptions, game) end
end

-- call next() first and decorate what comes back, so every other mod's
-- rows survive this one
mod.hooks:wrap("ui.options.rows", function(next, game, rows)
  local out = next(game, rows)
  if type(out) ~= "table" then return out end
  local Pipelines = require("src.render.Pipelines")
  -- ahead of every branch below, including FULL's early return: these two are
  -- off the menu whatever else this mod is or is not doing
  pinEngineFx(game)
  dropRow(out, "tilt")
  dropRow(out, "gbcfx")
  -- BATTLE LAYOUT is the ENGINE's row, and this is the one place the mod takes
  -- one away. While a fight can be staged on the map, OG is the only layout it
  -- can be composed in (OverworldBattle.forceOG), so the value is pinned there
  -- and the row comes off the list on the same reasoning as the rows FULL owns:
  -- a row that no longer decides anything is worse than no row. Nothing is
  -- lost by switching 3D-BTL off -- the row is back, WIDE and all, on the same
  -- keypress.
  if stagedBattles() then
    OverworldBattle.forceOG(game)
    BattleArt.forceRomPlayer(game)
    dropRow(out, "battleLayout")
  end
  local full = Voxel.isFull(Pipelines.level("voxel"))
  if full then
    -- FULL owns the rows that PARAMETERISE the diorama -- the wireframe, the
    -- horizon bend, the blur, the hour -- so those come off the menu and
    -- DAYTIME is held at SYNC while its row is unreachable.
    DayNight.forceSync(game)
    dropRow(out, "pipeline:tiltshift")
  end
  local extra = {}
  for _, entry in ipairs(SETTINGS) do
    -- Two things decide whether a row is offered.
    --
    -- FULL: a preset that owns the look, so the rows that describe the look go
    -- with it. The BATTLE rows are not that -- 3D-BTL decides what a fight is
    -- drawn over and BATTLE ART how its world cards are sourced, neither a knob on
    -- the diorama FULL is a preset for. FULL still SETS them on arrival (see
    -- applyFull); it does not hold them, so leaving them on the menu is the
    -- difference between a preset and a lock.
    --
    -- And a row whose own switch is off the table this frame (battle-art rows
    -- need a staged fight to be about) is left off with it. The mod
    -- manager's page carries every one of them either way.
    local offered = (entry.full or not full)
                    and (not entry.when or entry.when())
    if offered then extra[#extra + 1] = entry[1]:row() end
  end
  return insertGrouped(out, extra)
end)

-- The mod manager writes and persists on its own, so the only thing left
-- to do is move our cached index and pick the new value up.
mod.events:on("mod.options_changed", function(payload)
  if not (payload and payload.mod == mod.id) then return end
  for _, entry in ipairs(SETTINGS) do
    if payload.key == entry[1].key then entry[1]:sync(payload.value) end
  end
  -- 3D-BTL switched on from the manager's page pins BATTLE LAYOUT exactly as
  -- the OPTIONS row does. The manager persists its own value; this is the one
  -- that has to follow it.
  if stagedBattles() then OverworldBattle.forceOG() end
  BattleArt.forceRomPlayer()
  -- and DAYTIME changed from the manager's page while FULL owns it snaps
  -- straight back to SYNC -- the OPTIONS row is hidden, but the manager's is
  -- not, and FULL's pin must hold against both
  local Pipelines = require("src.render.Pipelines")
  if Voxel.isFull(Pipelines.level("voxel")) then DayNight.forceSync() end
end)

-- ------- keeping the geometry in step with the world
--
-- Terrain meshes are derived from a map's block layer, so anything that
-- rewrites a block (a cut tree, a smashed rock, a script's replaceBlock)
-- has to drop that map's cached mesh or the 3D world keeps showing the
-- tree that is no longer there.  The 2D tile renderer invalidates its own
-- caches off the same edit.

-- refresh, not invalidate: the stale mesh keeps drawing while the
-- replacement builds in the background, so a one-block edit (Cut, a
-- door stamp, the tree regrowing on re-entry) repopulates in place
-- instead of blinking the whole scene down to the flat 2D path
mod.events:on("world.block_replaced", function(payload)
  local mapId = payload and (payload.mapId or (payload.map and payload.map.id))
  if mapId then ChunkMesher.refresh(mapId) end
end)

-- The event above is the ANNOUNCED edit -- OverworldState:replaceBlock
-- emits it, which is the path Victory Road's barriers and a script's
-- replaceBlock take. Several edits do not go through it:
--
--   Cut          swaps the tree block and rebuilds the 2D renderer
--   the regrowth restores those blocks when the map is re-entered
--   card-key doors are stamped closed on floor load
--
-- all of them writing the block layer directly. Meshes derived from that
-- layer went stale with no announcement -- the cut tree stayed standing,
-- and after a round trip through a door the stump stayed cut because this
-- map's mesh survives in the cache (that is what prevLive is for).
--
-- The engine could announce each of those, and an earlier cut of this
-- work changed it to. That is the wrong place: it edits the game for one
-- mod's benefit, and every future path that writes a block has to
-- remember to do the same. They all funnel through ONE choke point --
-- Map:setBlock -- so wrap that from here instead. Map is a plain
-- metatable shared by every map instance, so this covers all of them,
-- including paths written after this mod.
--
-- Read back rather than trust the argument: setBlock silently ignores an
-- out-of-bounds write, and a stamp that rewrites a block with the value
-- it already held (the door code guards for this, the regrowth does not)
-- is not a change and must not throw the mesh away.
do
  local Map = require("src.world.Map")
  if not Map.dramaticShapeBlockHook then
    local setBlock = Map.setBlock
    Map.setBlock = function(self, bx, by, block)
      local before = self:blockAt(bx, by)
      setBlock(self, bx, by, block)
      if self.id and self:blockAt(bx, by) ~= before then
        ChunkMesher.refresh(self.id)
      end
    end
    Map.dramaticShapeBlockHook = true
  end
end

-- A reloaded map is rebuilt from scratch (warps that re-enter the same map,
-- hot reload), so its mesh is stale for the same reason -- with one
-- exception, and it is the common one.
--
-- A palette switch reloads the map ONLY to rebuild its atlas
-- (PaletteFX.setMode -> reloadMap(id, "colors")). The geometry that comes
-- back is identical: this mesher reads block layout and tile ids and never
-- reads colour, and the palette lives entirely in the texture TerrainAtlas
-- hands back per frame -- which is keyed BY palette, so the new colours are
-- already built by the time the next frame draws.
--
-- Dropping the mesh anyway cost a visible flash of the flat 2D world on
-- every palette toggle. Mesh builds are asynchronous, so the frames between
-- the drop and the first finished mesh have no terrain to draw, and
-- drawWorld returning nil IS the 2D fallback. Keeping the geometry lets the
-- new colours land on the diorama already on screen, in one frame, which is
-- what a palette toggle should look like from inside voxel mode.
mod.events:on("map.reloaded", function(payload)
  if payload and payload.reason == "colors" then return end
  local mapId = payload and (payload.mapId or (payload.map and payload.map.id))
  if mapId then ChunkMesher.invalidate(mapId) end
end)

-- ------- rows come and go, so the menu has to notice
--
-- OptionsMenu builds its row list ONCE, when it is opened, and then reads
-- that list every frame. So stepping the VOXEL row onto or off FULL changed
-- which rows the hook would return but not which rows were on screen -- the
-- settings FULL owns stayed visible until the menu was closed and reopened,
-- and a player who stepped off FULL could not see the rows come back.
--
-- Rebuilt in place, and only on a step that changes the LIST: crossing FULL,
-- toggling 3D-BTL, which owns BATTLE LAYOUT, or changing BATTLE ART, which
-- owns the TRAINER ART row and, under ANIMATED, the two generation rows.
-- Every other rung returns the same list, and rebuilding on all of them would
-- rerun every mod's ui.options.rows hook once per keypress. The cursor is
-- clamped rather than reset, so it stays on the row it was just used on
-- instead of jumping to the top when the list below it shortens.
do
  local OptionsMenu = require("src.ui.OptionsMenu")
  if not OptionsMenu.dramaticShapeFullHook then
    local Pipelines = require("src.render.Pipelines")
    local inner = OptionsMenu.update

    local function idAt(menu, index)
      local row = menu.rows and menu.rows[index or 1]
      return type(row) == "table" and row.id or nil
    end

    function OptionsMenu:update(dt)
      local before = Pipelines.level("voxel")
      local hadBattles = OverworldBattle.enabled()
      local hadBattleArt = BattleArt.setting:get()
      local wasOn = idAt(self, self.index)
      inner(self, dt)
      BattleArt.forceRomPlayer(self.game)
      local after = Pipelines.level("voxel")
      local crossedFull = after ~= before
                          and (Voxel.isFull(before) or Voxel.isFull(after))
      local hasBattleArt = BattleArt.setting:get()
      if crossedFull or OverworldBattle.enabled() ~= hadBattles
         or hasBattleArt ~= hadBattleArt then
        local rebuilt = OptionsMenu.new(self.game)
        self.rows = rebuilt.rows
        -- Follow the row the cursor was ON rather than the slot it was in:
        -- 3D-BTL takes BATTLE LAYOUT off the list ABOVE itself, which would
        -- otherwise slide the cursor onto the row under the one just used.
        for i = 1, #self.rows do
          if wasOn and idAt(self, i) == wasOn then self.index = i; break end
        end
        local cancel = #self.rows + 1
        if (self.index or 1) > cancel then self.index = cancel end
      end
    end

    OptionsMenu.dramaticShapeFullHook = true
  end
end

-- ------- battles on the map
--
-- The wraps this needs -- OverworldState:pushBattle, BattleState:draw and
-- BattleState:drawHUDs -- all live in lib/OverworldBattle.lua, which is
-- where the reasoning for each one is written down. Installed once, here,
-- so this file keeps naming every engine seam the mod touches.
OverworldBattle.install()

-- ------- the first-person rung's inputs and its walk
--
-- 1ST needs two things no other rung does, and each is a named seam:
--
-- FirstPerson.install claims the LOOK inputs the engine ignores: the right
-- stick's axes (Game:gamepadaxis passes them to Input, which returns early
-- on anything but the left pair), relative mouse motion (love.mousemoved --
-- there is no Game handler to wrap; the engine's own callback only feeds
-- the mouse-as-touch debug path, which stays untouched), the mouse buttons
-- while the cursor is captured (A and B -- there is no cursor to click UI
-- with), and any touch that lands off the overlay's controls (a drag on
-- open screen is the look; the d-pad and buttons still go to
-- TouchControls, whose own d-pad finger is also read back analog as the
-- move vector). Every wrap forwards whatever it does not claim, and claims
-- only while 1ST is actually driving.
--
-- FreeMove.install wraps OverworldState:handleInput -- the one choke point
-- where the grid walk reads the pad, and the same seam the engine's own
-- Cycling Road pull lives behind. While 1ST drives, the walk is continuous
-- and camera-relative; the player's logical cell stays synced and every
-- per-cell consequence still runs through the engine's own machinery
-- (onStepComplete, checkEdgeExit, checkLedgeHop, checkBoulderPush). The
-- file argues the whole arrangement.
FirstPerson.install()
FreeMove.install()

-- CamControl.install wires the battle-camera zoom (wheel / pinch) and the
-- right-stick orbit: the inputs that steer the staged battle's rig. It is
-- pcall-guarded inside OverworldBattle.update, so calling it here only
-- matters when a battle is actually on screen.
V.require("CamControl").install()

-- The overworld's own pushBattle is the choke point for a wild encounter or
-- a trainer, and it is wrapped. A battle that arrives some other way -- a
-- link battle, a script pushing a BattleState directly -- reaches this
-- instead, which stages the arena from wherever the player is standing.
-- Nothing visible is lost by being late: the cull only has to beat the
-- battle screen, and the wipe those battles skip is where it would have
-- shown.
mod.events:on("battle.started", function(payload)
  OverworldBattle.ensure(payload and payload.battle)
end)

-- Both mons face the camera, so the player's side wants its FRONT pic where
-- the battle screen would have used the back one. The engine's own
-- pokemon.sprite hook is the seam for exactly this: it is asked for every
-- battle pic with the side it is resolving, so swapping one side's answer
-- needs no battle code at all -- and every path that builds a battler goes
-- through it, including a Transform mid-fight.
--
-- next() first, so a sprite-replacing mod loaded before this one still gets
-- the last word on WHICH art is used; this only changes which SIDE is asked
-- for.
mod.hooks:wrap("pokemon.sprite", function(next, path, ctx)
  local out = next(path, ctx)
  if not (ctx and ctx.kind == "battle" and ctx.side == "back") then
    return out
  end
  if BattleArt.playerSide() ~= "front" or not OverworldBattle.wantsFront() then
    return out
  end
  local def = ctx.data and ctx.data.pokemon and ctx.data.pokemon[ctx.species]
  return (def and def.spriteFront) or out
end)

-- Every ending path emits this, including a battle skipped before it drew,
-- so this is where the map's cast comes back.
mod.events:on("battle.ended", function()
  OverworldBattle.finish()
end)

-- ------- and the way back out
--
-- The engine wipes INTO a battle with one of the original's eight transitions
-- and cuts straight OUT of it. That cut is between two very different cameras
-- in this mode, so while voxel mode is on the battle fades out, closes behind
-- the black, and the map fades up. The two seams it needs -- BattleState:finish
-- and Renderer:endFrame -- and the reasoning for each live in lib/BattleExit.lua.
--
-- Declared as a transitions record rather than a constant in that file, so the
-- fade is retunable in data exactly like the eight wipes it answers, and a total
-- conversion can make it as long or as short as its own pacing wants.
mod.content.transitions:register(BattleExit.ID, {
  frames = BattleExit.FRAMES,
})

BattleExit.install()

-- ------- and the hour on the flat world
--
-- The clock reaches the diorama through the voxel shader's own tint uniform,
-- which the 2D tile path never runs -- so with the mode off, the same evening
-- that fell on the diorama left the flat world at permanent noon. One clock,
-- two worlds, one of them ignoring it. DayTint paints the same multiply over
-- the composited flat world, between the world blit and the UI blit; the
-- reasoning for that exact instant is in the file.
DayTint.install()

-- ------- what time it is
--
-- The cycle's clock rides the SAVE SLOT (save.modData, via mod.save): what
-- time it is in Kanto is a fact about that journey, like where the player is
-- standing. Written on the engine's save.writing event -- the moment before
-- the bytes hit disk -- and read back whenever a save is opened or begun. A
-- save with no clock in it starts at day; that is DayNight.restore's
-- fallback, and also the DAYTIME row's own default.
mod.events:on("save.writing", function()
  DayNight.store()
end)

mod.events:on("save.loaded", function()
  DayNight.restore()
  -- a save written before this mod was installed can carry TILT or GBC FX
  -- switched on, and their rows are not there to switch them back off (see
  -- pinEngineFx). Answered here rather than only when the menu opens, so a
  -- player who never opens it is not left playing under one.
  pinEngineFx()
end)

mod.events:on("save.created", function()
  DayNight.restore()
  pinEngineFx()
end)

-- The engine's own time-of-day seam. OverworldState:timeOfDay() is an
-- eternal "DAY" until a mod answers here; answering it hands the period to
-- the map.palette hook (ctx.tod) and music.select, so a palette or music
-- pack keyed to night works with this mod's clock for free. next() first: a
-- mod loaded before this one that already moved the time keeps its answer.
mod.hooks:wrap("world.tod", function(next, tod, ctx)
  local out = next(tod, ctx)
  if out ~= tod then return out end
  return DayNight.tod()
end)

mod.exports.version = "1.7.6"
-- exposed so a companion mod can pin its own tiles' shapes or read the
-- camera without reaching into this mod's file layout
mod.exports.lib = V

-- =====================================================================
-- FIX: SILENCE VOXEL HUD WHEN MODERN UI BATTLE PRESENTER IS ACTIVE
-- This wraps the Voxel Mod's own HUD hooks to prevent them from drawing
-- the classic floating lifebars when Modern UI is handling the battle.
-- =====================================================================
local okBS, BattleState = pcall(require, "src.battle.BattleState")
if okBS and BattleState then
    local orig_drawHUDs = BattleState.drawHUDs
    BattleState.drawHUDs = function(self, ...)
        local modernMod = mod.find and mod.find("gen1_modern_ui")
        local wipOn = modernMod and modernMod.options and modernMod.options:get("battleUiWip")
        if wipOn then return end
        if orig_drawHUDs then return orig_drawHUDs(self, ...) end
    end

    local orig_drawTextArea = BattleState.drawTextArea
    BattleState.drawTextArea = function(self, ...)
        local modernMod = mod.find and mod.find("gen1_modern_ui")
        local wipOn = modernMod and modernMod.options and modernMod.options:get("battleUiWip")
        if wipOn then return end
        if orig_drawTextArea then return orig_drawTextArea(self, ...) end
    end
end
