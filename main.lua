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
local VoxelPrecache = V.require("VoxelPrecache")
local VoxelLoadingVeil = V.require("VoxelLoadingVeil")
local VoxelTransitionGate = V.require("VoxelTransitionGate")
local VoxelPrecacheScreen = V.require("VoxelPrecacheScreen")
local VoxelCacheRamScreen = V.require("VoxelCacheRamScreen")
local VoxelMeshDisk = V.require("VoxelMeshDisk")
local ModSetting = V.require("ModSetting")
local RamPrecache = V.require("RamPrecache")
local StaticGeometry = V.require("StaticGeometry")
local VoxelGrid = V.require("VoxelGrid")
local WorldCurve = V.require("WorldCurve")
local WorldUnderlay = V.require("WorldUnderlay")
local RenderDistance = V.require("RenderDistance")
local OverworldBattle = V.require("OverworldBattle")
local PokeballSettings = V.require("PokeballSettings")
local LegendaryPokeballs = V.require("LegendaryPokeballs")
local BattlePresentation = V.require("BattlePresentation")
local BattleStage = V.require("BattleStage")
local BattleArt = V.require("BattleArt")
local StadiumModels = V.require("StadiumModels")
local StadiumBackground = V.require("StadiumBackground")
local InterfaceSprites = V.require("InterfaceSprites")
local UiBackplates = V.require("UiBackplates")
local BattleExit = V.require("BattleExit")
local DayNight = V.require("DayNight")
local DayTint = V.require("DayTint")
local Water = V.require("Water")
local Shadows = V.require("Shadows")
local AntiAlias = V.require("AntiAlias")
local FirstPerson = V.require("FirstPerson")
local FreeMove = V.require("FreeMove")
local PoisonFlash = V.require("PoisonFlash")
local MomHealFlash = V.require("MomHealFlash")
local TransformCompat = V.require("TransformCompat")
local VoxelCompanion = V.require("VoxelCompanion")
local CompanionLifecycle = V.require("CompanionLifecycle")
local CharacterRenderers = V.require("CharacterRenderers")
local CommunityVisuals = V.require("CommunityVisuals")

-- The public provider is created while this mod loads, before consumers resolve
-- optional dependencies. The dispatcher starts at mods.loaded; a consumer that
-- registers later in that event joins the running dispatcher automatically.
local Companion = VoxelCompanion.new({ mod = mod })
V.companion = Companion

-- mods.loaded runs before Game.overworld necessarily has a live map. Use the
-- engine's public per-frame hook to retry after the real overworld update and
-- to observe later map/revision changes. This must not depend on a render
-- pipeline being active: KFP can attach while Battle Art's voxel mode is off.
local uninstallCompanion = CompanionLifecycle.install(mod, Companion)

-- `core.quit_to_launcher` is the engine's native mod-unload boundary. Retain
-- the exact disposer returned above and run it before this loader is replaced,
-- so claims, adapter GPU resources, and the update hook cannot survive unload.
mod.hooks:wrap("core.quit_to_launcher", function(next)
  uninstallCompanion()
  return next()
end)

-- `mods.loaded` is the first point at which every content mod has finished
-- patching the registries and the last point before a save can mutate live map
-- blocks. Persistent voxel meshes are keyed exclusively from this snapshot.
mod.events:on("mods.loaded", function(payload)
  StaticGeometry.capture(payload and payload.data)
  -- Sprite providers commonly wrap BattleState.update from their main chunk.
  -- Reassert BATTLE ART ownership outside the completed chain so ordinary and
  -- shiny opponent fronts cannot alternate after those providers advance.
  OverworldBattle.refreshSpriteOwnershipHook()
  local started, err = Companion:start()
  if not started and mod.log and mod.log.error then
    mod.log:error("Voxel Companion host did not start: %s", tostring(err))
  end
end)

-- Forward declaration: the voxel pipeline's update hook (registered below)
-- calls this, and it is defined further down with the settings it drives.
-- Declared rather than left global -- a mod writing to _G would leak into
-- every other mod's namespace.
local applyFull

-- WORLD depends on the engine's flat battle compositing the frozen overworld
-- behind its UI. A staged 3D battle owns that space instead, so WORLD cannot
-- be represented and falls back to WHITE. BLACK is an ordinary opaque
-- letterbox and remains a valid explicit choice.
local function ensureBattleBgCompatible(opts)
  if opts and opts.battleBg == "world" then
    opts.battleBg = "white"
    return true
  end
  return false
end

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

-- A naming screen is a foreground state, but render-pipeline drawWorld calls
-- still receive the live OverworldState as ctx.state.  Checking only that
-- object therefore misses caught-Pokemon naming: the overworld is complete,
-- so the voxel pass clears and redraws the frame behind (and, with some UI
-- renderers, after) the native naming canvas.  Colosseum's replacement flow
-- happens to draw at the final HUD stage, which is why that one mode survives.
--
-- Resolve ownership from the authoritative screen stack instead.  Native and
-- third-party Gen I naming screens do not consistently expose screenId, so the
-- grid/confirm/update contract is the stable fallback.  Colosseum-tagged flows
-- are deliberately exempt: that renderer already owns the final overlay and
-- its approved live voxel background must remain unchanged.
local function colosseumNamingState(state)
  return type(state) == "table" and (
    state.__colosseumFlowKind == "naming"
    or state.__colosseumCaughtNaming == true
    or state.__colosseumGiftNaming == true
    or state.__colosseumIntroSafe == true
    or state.__colosseumNicknamePrompt == true
    or state.__colosseumNicknameChoice == true
  )
end

local function nativeNamingState(state)
  if type(state) ~= "table" or colosseumNamingState(state) then return false end

  local id = tostring(state.screenId or state.id or ""):lower()
  if id == "naming" or id == "namingscreen"
      or id:find("naming", 1, true) then
    return true
  end

  local namingContract = type(state.grid) == "function"
      and type(state.confirm) == "function"
      and type(state.update) == "function"
  local namingData = type(state.glyphs) == "table"
      or state.maxLen ~= nil or state.maxLength ~= nil
      or type(state.onDone) == "function"
  return namingContract and namingData
end

local function nativeNamingOwnsFrame(ctxState)
  local okGame, Game = pcall(require, "src.core.Game")
  if not okGame or type(Game) ~= "table" then
    return nativeNamingState(ctxState)
  end

  local stack = Game.stack
  local states = stack and stack.states
  local top
  if stack and type(stack.top) == "function" then
    local okTop, value = pcall(stack.top, stack)
    if okTop then top = value end
  end
  if not top and type(states) == "table" then top = states[#states] end

  -- Preserve the already-working Colosseum flow exactly, including the live
  -- voxel field visible behind its translucent naming deck.
  if colosseumNamingState(top) then return false end

  if nativeNamingState(top) then return true end
  if type(states) == "table" then
    -- Preset/choice menus may temporarily sit above NamingScreen. Inspect the
    -- complete active stack rather than assuming the naming object is on top.
    for i = #states, 1, -1 do
      local state = states[i]
      if colosseumNamingState(state) then return false end
      if nativeNamingState(state) then return true end
      -- BattleState deliberately raises this while its stock nickname prompt
      -- and native naming flow own the canvas. It remains the reliable bridge
      -- on engine builds whose NamingScreen exposes neither ID nor metadata.
      if type(state) == "table" and state.blankForAskName == true then
        return true
      end
    end
  end
  return nativeNamingState(ctxState)
end

V.nativeNamingOwnsFrame = nativeNamingOwnsFrame

local voidFill = { last = nil }
function voidFill.check()
  local TileRenderer = require("src.render.TileRenderer")
  local now = TileRenderer.voidFill
  if voidFill.last ~= nil and now ~= voidFill.last then
    -- Only the FULL-slot apron ring depends on void fill (see
    -- Disk.fingerprint and ChunkMesher.invalidateVoidRings); body/aux stay
    -- drawn while just the ring rebuilds, so toggling never stutters every map.
    ChunkMesher.invalidateVoidRings()
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
    -- WORLD is only valid for the engine's flat 2D battle and composites as
    -- broken bars with the 3D diorama (there is no frozen overworld to show
    -- through). Correct that incompatible mode at the top of every update
    -- tick -- not gated on FULL -- while preserving the valid BLACK option.
    -- Persists on change only, never every frame.
    local Game = require("src.core.Game")
    local o = Game.save and Game.save.options
    if ensureBattleBgCompatible(o) then
      if Game.writeOptions then pcall(Game.writeOptions, Game) end
    end
    -- FULL is a preset, so it is applied ON THE PRESS rather than held every
    -- frame: it SETS the other rows and then leaves them alone. Holding them
    -- would make the zoom keys and the wheel dead while the mode was on, and
    -- would fight anyone who changed one deliberately.
    applyFull(level)
    Voxel.update(dt, level)
    local transitionGame = require("src.core.Game")
    local transitionWorld = transitionGame and transitionGame.overworld
    VoxelTransitionGate.update(dt, Voxel.active() and Voxel3D.available(),
      transitionWorld and transitionWorld.map)
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
      -- Once the visible neighbourhood is ready, cooperatively prepare the
      -- current map's real warp/connection destinations.  This is automatic:
      -- no prebuild button, startup pause or whole-world resident cache.
      pcall(VoxelPrecache.update, Game)
    end
    ChunkMesher.pump(Game and Game.stack
                     and Game.stack:top() ~= ow)
  end,

  drawWorld = function(ctx)
    -- Naming screens can be pushed before Oak has finished constructing a
    -- save, an overworld, or even a live player. The render-pipeline registry
    -- still asks every enabled world pipeline for a frame during that early UI
    -- state. VoxelScene requires the complete OverworldState contract, so
    -- decline the pass until all of its authoritative pieces exist. Returning
    -- nil is the registry's documented fail-open path: the engine keeps its
    -- native intro/name-entry canvas and resumes 3D automatically on the first
    -- real overworld frame.
    local state = ctx and ctx.state
    if nativeNamingOwnsFrame(state) then return nil end
    if type(state) ~= "table" or not (state.map and state.camera and state.player) then
      return nil
    end

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
    -- TEST435's protected handoff is intentional compatibility, not merely a
    -- diagnostic wrapper. If a future engine introduces another incomplete
    -- world-like state, fail open to its native renderer instead of aborting
    -- the remainder of the frame (which otherwise leaves only the naming
    -- canvas's green clear colour visible).
    local okRender, canvas, waiting = pcall(VoxelScene.render, state, rw, rh,
                                            ctx.vw, ctx.vh, ctx.paletteFor)
    local map = state.map
    if not okRender then
      VoxelTransitionGate.cancel(map)
      if not V.worldStateCompatWarned and mod.log and mod.log.error then
        V.worldStateCompatWarned = true
        mod.log:error("Voxel world pass failed open: %s", tostring(canvas))
      end
      return nil
    end
    if not canvas then
      local generating = map and not ChunkMesher.slotKnown(map, false)
      if waiting or generating then
        VoxelTransitionGate.observe(map, false)
        -- Only an explicitly qualified Continue/travel gate may cover the
        -- world. Ordinary doors and first-time route loads fail open to the
        -- engine renderer while their voxels build instead of inventing an
        -- unrelated black transition. The gate itself also has a hard ceiling,
        -- so a failed neighbour/cache record cannot soft-lock a save here.
        if VoxelTransitionGate.blocking(map) then
          return VoxelLoadingVeil.get(sw, sh)
        end
        return nil
      end
      -- A genuine renderer failure must fail open instead of trapping the
      -- player behind an eternal modal cover.
      VoxelTransitionGate.cancel(map)
      return nil                    -- genuine build/driver failure: safe 2D
    end
    if waiting then
      -- The canvas is the last wholly rendered neighbourhood. Do not composite
      -- the new area's field FX over that old camera; reveal both together once
      -- all connected BODY meshes are ready.
      VoxelTransitionGate.observe(map, false)
      if VoxelTransitionGate.blocking(map) then
        return VoxelLoadingVeil.get(sw, sh)
      end
      -- Seamless route/city connections are intentionally not modal: retain
      -- their last complete voxel frame instead of flashing a black cover.
      return AntiAlias.resolve(canvas, sw, sh, "world")
    end
    VoxelTransitionGate.observe(map, true)
    if VoxelTransitionGate.blocking(map) then
      return VoxelLoadingVeil.get(sw, sh)
    end
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
    VoxelScene.invalidate()
    Voxel3D.invalidate()
    V.require("Pokeball").invalidate()
    OverworldBattle.invalidate()
    AntiAlias.invalidate()
    VoxelLoadingVeil.invalidate()
    ChunkMesher.invalidate()   -- no map id = every cached mesh
    pcall(Companion.invalidate, Companion, "render_pipeline")
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
  -- default to the classic player back view. The foe remains world-placed;
  -- AUTO decides whether the selected back belongs in-world or on OG UI.
  BattleArt.viewSetting:setIndex(2, Game)
  -- and the battle screen the staged fight is composed for. WIDE re-lays that
  -- screen out on a 304x144 surface, which moves every anchor the arena camera
  -- is solved against (OverworldBattle.forceOG); FULL has just switched staged
  -- fights on, so the layout follows them.
  OverworldBattle.forceOG(Game)
  -- BATTLE BG: WORLD leaves the frozen overworld showing through a battle and
  -- is only valid for the engine's flat 2D battle; with the 3D diorama there
  -- is no "old system" to show through, so WORLD composites as broken dark
  -- bars. Correct WORLD to WHITE while preserving BLACK, which is already an
  -- opaque field and needs no world-behind-battle path.
  ensureBattleBgCompatible(opts)
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
  { CommunityVisuals.pillars,
    "Choose the original Battle Art pillars or the community granite design: "
    .. "standalone, joined by the approved low wall, or interlocked across "
    .. "the crown. Changing this rebuilds derived map geometry in the normal "
    .. "background queue; collision and map data never change.",
    full = true },
  { CommunityVisuals.masonry,
    "Color TEST435's synchronized retaining walls and authored ledges as "
    .. "granite, red brick, sandstone or slate. Pillars stay in their locked "
    .. "TEST366 granite material.",
    full = true },
  { CommunityVisuals.trees,
    "Choose Battle Art's authored round trees or the finalized Legendary Visuals "
    .. "small, medium, large and mature XL tree family.", full = true },
  { CommunityVisuals.cutTrees,
    "Choose Battle Art's original cuttable bush or the super-skinny Legendary "
    .. "Visuals city sapling with two support stakes and dark ties. The "
    .. "original Cut action, collision, replacement "
    .. "block and regrowth remain authoritative.", full = true },
  { CommunityVisuals.signs,
    "Choose Battle Art's readable white town sign or add the Legendary "
    .. "Visuals grained wooden frame behind that same authored face and label.",
    full = true },
  { CommunityVisuals.grass,
    "Choose the original Overworld turf and encounter grass or TEST435's "
    .. "harmonized natural-green materials.", full = true },
  { CommunityVisuals.roads,
    "Choose original route surfaces or TEST435's quiet packed-earth roads "
    .. "and dark timber bridge deck.", full = true },
  { CommunityVisuals.walls,
    "Choose original terrain faces or TEST435's architectural masonry walls "
    .. "and authored stone ledges.", full = true },
  { CommunityVisuals.courtyards,
    "Choose original courtyard/fence treatment or TEST435's timber fences, "
    .. "warm flagstone courts and flush claimed-cell finish.", full = true },
  { VoxelGrid.setting,
    "One-pixel wireframe along every voxel edge." },
  { WorldCurve.setting,
    "Bend the world down over the horizon, Animal Crossing style." },
  { WorldUnderlay.setting,
    "Choose the solid outdoor world beneath terrain holes and beyond map edges: "
    .. "CYAN or BLACK. OFF/KFP leaves the underlay to Kanto First Person. "
    .. "NATURE uses cyan by default and continues each biome beyond loaded "
    .. "ROM cells with stable random-sized tree or rock billboards; selected "
    .. "forest, Safari-house and Seafoam void maps use black and stay clear. "
    .. "Indoor horizons automatically match "
    .. "the room's own border/void material so the finite map ring cannot reveal "
    .. "a differently coloured infinite fill behind it.",
    full = true },
  { RenderDistance.setting,
    "Limit connected-map terrain, water, figures and characters outside the "
    .. "camera neighborhood. MEDIUM is the balanced default for the current "
    .. "sandboxed engine's pure-Lua mesh path; FULL preserves the uncapped "
    .. "legacy draw distance.",
    full = true },
  { RamPrecache.setting,
    "Maximum compressed voxel cache eagerly loaded after CONTINUE, in MiB. "
    .. "FULL loads every generated cache file; OFF skips the preload and "
    .. "handles voxel data on demand during play. On Phosphor/iOS, OFF uses "
    .. "the compatible 1.9.6 full preload to avoid transition-time storage "
    .. "reads.",
    full = true },
  { Water.setting,
    "Reflections on water. FULL adds screen-space reflections of the "
    .. "shoreline, the trees and the buildings behind it; SKY is the sky, "
    .. "the sun and the moon alone, which is most of the look for a "
    .. "fraction of the cost." },
  { Shadows.setting,
    "Enable shadows. OFF removes both the real cast-shadow map and its flat "
    .. "fallback from free roam and staged battles; UNLIT battle cards also "
    .. "decline shadows even while this global switch is ON.",
    full = true },
  { InterfaceSprites.setting,
    "INTERFACE SPRITES: show BATTLE ART's regular-form FRONT outside battle. "
    .. "Title and status support timed atlas animation; other hook-aware "
    .. "screens use single-image sets or retain ROM art, independent of "
    .. "DUPLICATE FIX (which owns only battle pictures). "
    .. "MODDED leaves the interfaces to another sprite mod or the ROM." },
  -- `full` marks a row FULL does not take away. FULL owns the diorama's own
  -- knobs; what a battle is drawn over, and how it is framed, are not that.
  { OverworldBattle.setting,
    "Fight on the map: the battle draws over the nearest clear ground, "
    .. "shot over the shoulder with a slow parallax drift.",
    full = true },
  { OverworldBattle.trainerBattleSetting,
    "STOCK keeps Battle Art's native trainer and player-Pokemon presentation. "
    .. "LEGENDARY keeps the selected 3D trainer standing through a normal "
    .. "battle and reserves the player side for the Stadium/N64 model, with "
    .. "no duplicate 2D card attached to either the camera or UI box. Select "
    .. "STOCK when the model provider is unavailable. Battle state and "
    .. "gameplay stats are untouched.",
    when = function() return stagedBattles() end, full = true },
  { PokeballSettings.enabled,
    "Choose Battle Art's original capture animation or Legendary Visuals' "
    .. "real 3D Poke Ball throw, intake beam, ground shakes, catch click and "
    .. "breakout. This changes presentation only; items, odds and outcomes "
    .. "remain Battle Art's.",
    when = function() return stagedBattles() end, full = true },
  { PokeballSettings.size,
    "Scale the Legendary 3D capture ball without changing its trajectory.",
    when = function()
      return stagedBattles() and PokeballSettings.active()
    end, full = true },
  { PokeballSettings.suction,
    "Enable the Legendary intake beam and suction presentation.",
    when = function()
      return stagedBattles() and PokeballSettings.active()
    end, full = true },
  { PokeballSettings.preset,
    "Choose a coordinated capture-effects profile. CUSTOM exposes the "
    .. "individual beam, streamer and star controls below.",
    when = function()
      return stagedBattles() and PokeballSettings.active()
    end, full = true },
  { PokeballSettings.beam,
    "Set intake-beam strength for the CUSTOM capture profile.",
    when = function()
      return stagedBattles() and PokeballSettings.active()
        and PokeballSettings.preset:get() == "CUSTOM"
    end, full = true },
  { PokeballSettings.streamers,
    "Set airborne trail strength for the CUSTOM capture profile.",
    when = function()
      return stagedBattles() and PokeballSettings.active()
        and PokeballSettings.preset:get() == "CUSTOM"
    end, full = true },
  { PokeballSettings.stars,
    "Set successful-catch star strength for the CUSTOM capture profile.",
    when = function()
      return stagedBattles() and PokeballSettings.active()
        and PokeballSettings.preset:get() == "CUSTOM"
    end, full = true },
  { PokeballSettings.pokemonGlow,
    "Control the opponent glow while it is drawn into the ball.",
    when = function()
      return stagedBattles() and PokeballSettings.active()
    end, full = true },
  { PokeballSettings.suctionParticles,
    "Control the particles pulled inward during capture.",
    when = function()
      return stagedBattles() and PokeballSettings.active()
    end, full = true },
  { PokeballSettings.captureSpeed,
    "Choose the timing of the visual intake; battle timing remains native.",
    when = function()
      return stagedBattles() and PokeballSettings.active()
    end, full = true },
  { PokeballSettings.openTime,
    "Choose how long the 3D ball visibly holds open before closing.",
    when = function()
      return stagedBattles() and PokeballSettings.active()
    end, full = true },
  { PokeballSettings.fxScale,
    "Scale the Legendary beam, trails, particles and catch effects together.",
    when = function()
      return stagedBattles() and PokeballSettings.active()
    end, full = true },
  { FirstPerson.invertYSetting,
    "Invert vertical look input in 1ST and 3RD free-camera modes only. "
    .. "It does not change overhead camera movement.",
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
  { BattleArt.duplicateSetting,
    "Choose who owns Pokemon pictures when another sprite mod is installed. "
    .. "BATTLE ART keeps this mod's selected front and back collections on "
    .. "top, including its DV-routed shiny collections. MODDED installs no "
    .. "Pokemon art and captures the pictures chosen by another sprite mod "
    .. "or the ROM on both sides. This replaces both old FRONT SHINY FIX and "
    .. "BACK SHINY FIX rows.",
    when = function() return stagedBattles() end, full = true },
  { BattleArt.viewSetting,
    "Show the player's Pokemon from the front or back. Supplied art stays "
    .. "world-placed; a missing selected back falls back to the ROM UI pic.",
    when = function() return stagedBattles() end, full = true },
  { BattleArt.frontFlipSetting,
    "Orient the player-side FRONT SPRITES card. BATTLE ART mirrors ordinary "
    .. "front art so it faces the opponent. DEFAULT preserves the image's "
    .. "authored direction, for sprite mods that already supply a flipped "
    .. "player picture such as Crystal Animated Sprites.",
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
  { UiBackplates.battleUi,
    "BOTH shows the battle textbox and Pokemon HUDs. TEXTBOX keeps only "
    .. "the textbox with TEXTBOX FILL. HUD keeps only the Pokemon HUDs with "
    .. "HUD COLOR. HIDE hides both so another UI mod can draw them. "
    .. "Battle controls remain active in every mode.",
    when = function() return stagedBattles() end, full = true },
  { UiBackplates.hudColor,
    "COLOR keeps the engine's black names, levels and HP text plus its "
    .. "green/yellow/red HP bars, with a bright one-pixel shadow for the "
    .. "world behind them. INVERTED uses white HUD ink with a dark shadow. "
    .. "ARENA FILL: WHITE always uses COLOR so the HUD remains visible.",
    when = function() return stagedBattles() end, full = true },
  { UiBackplates.arenaFill,
    "OFF uses the voxel level. WHITE draws a solid white arena. GEN6 "
    .. "selects a flat illustrated background by city, route, cave or "
    .. "story location and follows DAWN/DAY/DUSK/NIGHT where variants exist. "
    .. "BLUE uses Stadium 2's native background and ground circles. "
    .. "Both fill and crop to every window shape, softly defocus the plate, "
    .. "retain the normal battle camera, keep only "
    .. "mons, attacks and menus above it, and force SPRITE LIGHT: UNLIT.",
    when = function() return stagedBattles() end, full = true },
  { UiBackplates.stadiumCircle,
    "Control Stadium's ground circles independently of ARENA FILL. ON uses "
    .. "the normal radius, HALF uses two-thirds radius, and OFF hides them. "
    .. "This has no effect unless a compatible Stadium scene is installed.",
    when = function() return StadiumBackground.installed() end,
    provider = true, full = true },
  { UiBackplates.backdropOffset,
    "Choose how far down into an illustrated background its top crop begins, "
    .. "from 0 to 400 source-image pixels (100 by default). Larger values reveal lower floor "
    .. "detail in wide windows and are safely clamped when no vertical crop "
    .. "is available. This affects GEN6 and enabled boss backgrounds.",
    -- Keep it visible beside ARENA FILL so a player can prepare the crop
    -- before entering GEN6 or enabling an illustrated boss override.
    when = function() return stagedBattles() end, full = true },
  { UiBackplates.bossBg,
    "Independently replace the selected illustrated location plate for true "
    .. "Gym Leader, Elite Four, Champion and static legendary encounters. "
    .. "Rival battles continue to use Oak's Lab, Route 2, Route 24, SS Anne, "
    .. "Pokemon Tower or Silph Co art. This row has no effect with ARENA "
    .. "FILL: OFF or WHITE.",
    when = function() return stagedBattles() end, full = true },
  { UiBackplates.textboxFill,
    "WHITE keeps the latest build's opaque paper. HALF draws translucent "
    .. "black, BLACK draws opaque black, and OFF removes only the paper. "
    .. "Dark and transparent modes use white ink with a one-pixel shadow. "
    .. "The fill is drawn with the engine textbox so BATTLE SIZE FIXED and "
    .. "FILL stay aligned. ARENA FILL: WHITE overrides this row to WHITE.",
    when = function() return stagedBattles() end, full = true },
  -- AA is marked `full` for the opposite reason the battle rows are: this is not a
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
for _, entry in ipairs(SETTINGS) do
  -- Provider-only settings should not leave a dead row when the optional
  -- provider is absent. The in-game row has the same availability guard.
  if not entry.provider or StadiumModels.installed() then
    schema[#schema + 1] = entry[1]:schema(entry[2])
  end
end
mod.options:define(schema)

-- Read the raw pre-1.7.7 keys before duplicateFix's schema default can be
-- mistaken for an explicit choice. The same helper runs again when a real
-- save is attached below; this early call covers the already-loaded profile.
pcall(BattleArt.migrateDuplicateSetting)

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

-- The latest engine can drive fixed-row OPTIONS submenus. Sort this mod's
-- settings into a few small pages there; engines before that screen contract
-- retain the original flat list, including v0.2.36.
local OPTION_CATEGORIES = {
  { id = "world", label = "WORLD", settings = {
    CommunityVisuals.pillars, CommunityVisuals.masonry,
    CommunityVisuals.trees, CommunityVisuals.cutTrees,
    CommunityVisuals.signs, CommunityVisuals.grass,
    CommunityVisuals.roads, CommunityVisuals.walls,
    CommunityVisuals.courtyards,
    VoxelGrid.setting, WorldCurve.setting, WorldUnderlay.setting,
    Water.setting, DayNight.setting, FirstPerson.invertYSetting,
  } },
  { id = "performance", label = "PERFORMANCE", settings = {
    RenderDistance.setting, RamPrecache.setting,
    Shadows.setting, AntiAlias.setting,
  } },
  { id = "pokemon", label = "POKEMON ART", settings = {
    InterfaceSprites.setting, BattleArt.setting, BattleArt.trainerSetting,
    BattleArt.playerArtSetting, BattleArt.playerAnimationSetting,
    BattleArt.frontAnimationSetting, BattleArt.backAnimationSetting,
    BattleArt.duplicateSetting, BattleArt.viewSetting,
    BattleArt.frontFlipSetting,
  } },
  { id = "battle", label = "BATTLE SCENE", settings = {
    OverworldBattle.setting, OverworldBattle.trainerBattleSetting,
    OverworldBattle.hudScaleSetting,
    PokeballSettings.enabled, PokeballSettings.size,
    PokeballSettings.suction, PokeballSettings.preset,
    PokeballSettings.beam, PokeballSettings.streamers,
    PokeballSettings.stars, PokeballSettings.pokemonGlow,
    PokeballSettings.suctionParticles, PokeballSettings.captureSpeed,
    PokeballSettings.openTime, PokeballSettings.fxScale,
    BattleArt.backPlacementSetting,
    UiBackplates.spriteLight, UiBackplates.battleUi,
    UiBackplates.hudColor, UiBackplates.arenaFill,
    UiBackplates.stadiumCircle, UiBackplates.backdropOffset,
    UiBackplates.bossBg, UiBackplates.textboxFill,
  } },
}

local OPTION_CATEGORY = {}
for _, category in ipairs(OPTION_CATEGORIES) do
  for _, setting in ipairs(category.settings) do
    OPTION_CATEGORY[setting] = category
  end
end

-- Categorized OPTIONS first shipped in 0.2.37. Development trees keep the
-- deliberately non-orderable 0.0.0-dev version, so they must advertise the
-- exact extension instead; this also prevents an old checkout at the same
-- placeholder version from accidentally taking the new path.
local function categorizedOptionsAvailable()
  local okVersion, Version = pcall(require, "src.core.Version")
  if not okVersion or type(Version) ~= "table" then return false end
  local major, minor, patch = tostring(Version.engine or "")
    :match("^(%d+)%.(%d+)%.(%d+)")
  major, minor, patch = tonumber(major), tonumber(minor), tonumber(patch)
  local released = major and (major > 0
    or minor > 2 or (minor == 2 and patch >= 37))
  if released then return true end
  if Version.isDev and Version.isDev() then
    local okMenu, OptionsMenu = pcall(require, "src.ui.OptionsMenu")
    return okMenu and type(OptionsMenu.focusRow) == "function"
  end
  return false
end

local function categorizedRows(rows)
  local buckets = {}
  for _, category in ipairs(OPTION_CATEGORIES) do buckets[category] = {} end
  local uncategorized = {}
  for _, row in ipairs(rows) do
    local category = row.optionSetting and OPTION_CATEGORY[row.optionSetting]
    local bucket = category and buckets[category] or uncategorized
    bucket[#bucket + 1] = row
  end

  local out = {}
  local OptionsMenu = require("src.ui.OptionsMenu")
  local function opener(category, members)
    local id = "BATTLE_ART_VOXEL_FORK:group:" .. category.id
    return {
      id = id, label = category.label, group = true, members = members,
      value = function() return ("%d OPTIONS"):format(#members) end,
      activate = function(game)
        local sub = OptionsMenu.new(game, { rows = members })
        sub.dramaticShapeCategory = id
        game.stack:push(sub)
      end,
    }
  end
  for _, category in ipairs(OPTION_CATEGORIES) do
    local members = buckets[category]
    if #members > 0 then
      out[#out + 1] = opener(category, members)
    end
  end
  for _, row in ipairs(uncategorized) do out[#out + 1] = row end
  return out
end

-- GBC FX was a private engine module in older Gen1Recomp builds. Newer builds
-- expose the generalized ShaderFX system instead, and sandbox require errors
-- are fatal even when the effect is only being cleared. Detect the legacy
-- seam once and keep this mod's compatibility policy narrow: clear it when
-- present, but never disable a newer engine effect by guessing its API.
local legacyGBCFX
local function clearLegacyGBCFX()
  if legacyGBCFX == nil then
    local ok, module = pcall(require, "src.render.GBCFX")
    legacyGBCFX = ok and type(module) == "table" and module or false
  end
  if legacyGBCFX and type(legacyGBCFX.setLevel) == "function" then
    pcall(legacyGBCFX.setLevel, 0)
  end
end

-- TEST48: one authoritative step for both the keyboard's "3" hotkey and
-- the handheld/controller SELECT (Back) button. This is the proven N64
-- Memory camera ladder: OFF -> 15 -> 35 -> 50 -> 75 -> 1ST -> 3RD.
-- FULL remains an OPTIONS preset rather than a hotkey stop; pressing from
-- FULL advances from its matching 35-degree view to 50 degrees.
local function cycleVoxelCamera(game)
  local Pipelines = require("src.render.Pipelines")
  local top = game.stack and game.stack:top()
  if not Pipelines.canToggle("voxel", top, game.overworld) then return false end
  local nextLevel = Voxel.nextHotkeyLevel(Pipelines.level("voxel"))
  Pipelines.setLevel("voxel", nextLevel)
  Pipelines.syncOptions(game.save.options)
  -- Preserve the established Battle Art compatibility rule: a real voxel
  -- camera owns the view, so the engine's flat TILT/GBC post effects stay off.
  game.save.options.tilt = 0
  game.save.options.gbcfx = 0
  clearLegacyGBCFX()
  require("src.render.Tilt").setLevel(0)
  game:writeOptions()
  -- TEST49: camera cycling is gameplay behavior and must never depend on
  -- optional diagnostics. Battle Art's 0.2.53 compatibility host has no
  -- V.log object, so logging here previously crashed after a successful step.
  return true
end

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
        if key == "3" then
          if cycleVoxelCamera(self) then return end
        else
          local stepped = Pipelines.hotkey(key, top, self.overworld) and true
          if stepped then
            Pipelines.syncOptions(self.save.options)
            require("src.render.Tilt").setLevel(self.save.options.tilt or 0)
            self:writeOptions()
            return
          end
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
  local changed = false
  if opts then
    changed = (opts.tilt or 0) ~= 0 or (opts.gbcfx or 0) ~= 0
    opts.tilt, opts.gbcfx = 0, 0
  end
  pcall(Tilt.setLevel, 0)
  clearLegacyGBCFX()
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
    if offered then
      local row = entry[1]:row()
      row.optionSetting = entry[1]
      extra[#extra + 1] = row
    end
  end
  return insertGrouped(out, extra)
end)

-- The title menu is the one place a whole-game cache belongs: before
-- CONTINUE/NEW GAME has put an overworld and its live streaming workload on
-- screen.  Keep the compact menu label within the stock title box; the screen
-- it opens spells out GENERATE PRECACHE, its exact products and live disk use.
mod.hooks:wrap("ui.title_menu.items", function(next, game, items)
  local out = next(game, items)
  if type(out) ~= "table" then return out end
  -- Always offer PRECACHE from the title screen. Whether this build can
  -- actually persist a disk cache is decided inside VoxelPrecacheScreen,
  -- which shows the "not available" message on builds whose storage
  -- backend would otherwise freeze (e.g. Windows 0.1.84+).
  VoxelMeshDisk.bind(game, true)
  local cacheAvailable = VoxelMeshDisk.available()
  for _, item in ipairs(out) do
    if tostring(item and item.label or "") == "CONTINUE"
        and type(item.onSelect) == "function" and cacheAvailable then
      local continue = item.onSelect
      item.onSelect = function()
        VoxelMeshDisk.beginSession()
        local savedMap
        local okSave, saved = pcall(require("src.core.SaveData").load)
        if okSave and saved and saved.player then savedMap = saved.player.map end
        local priority = RamPrecache.priorityMaps(game.data, savedMap, 2)
        local names, total = VoxelMeshDisk.ramPlan(priority)
        local limit = RamPrecache.bytes()
        local held = VoxelMeshDisk.ramStats().bytes or 0
        local ready = limit ~= nil and held >= limit
                   or limit == nil and VoxelMeshDisk.ramReady(names)
        if limit == 0 or not names or #names == 0 or ready then
          continue()
        else
          game.stack:push(VoxelCacheRamScreen.new(
            game, continue, limit, names, total))
        end
      end
    elseif tostring(item and item.label or "") == "NEW GAME"
        and type(item.onSelect) == "function" then
      local newGame = item.onSelect
      item.onSelect = function()
        -- A save which has never run PRECACHE still gets the same RAM-only
        -- gameplay layer. Its first adjacent maps are generated lazily and
        -- may later be persisted with pause-menu CACHE -> SAVE.
        newGame()
        VoxelMeshDisk.bind(game, false)
        VoxelMeshDisk.beginSession()
      end
    end
  end
  if not VoxelMeshDisk.precacheAvailable() then return out end
  local entry = {
    label = "PRECACHE",
    onSelect = function()
      VoxelMeshDisk.beginPrecache()
      game.stack:push(VoxelPrecacheScreen.new(game))
    end,
  }
  local at = #out + 1
  for i, item in ipairs(out) do
    if tostring(item and item.label or "") == "EXIT GAME" then
      at = i
      break
    end
  end
  table.insert(out, at, entry)
  return out
end)

-- Gameplay cache writes are opt-in. Generated/repaired BAVC containers stay
-- dirty in RAM until CACHE -> SAVE; DROP abandons the whole preload and those
-- unsaved changes, leaving uploaded current-area meshes intact and allowing
-- subsequent adjacent-area requests to refill RAM lazily.
mod.hooks:wrap("ui.start_menu.items", function(next, game, items)
  local out = next(game, items)
  if type(out) ~= "table" then return out end
  -- CACHE is always offered; VoxelPrecacheScreen surfaces the
  -- "not available" message on builds without a usable storage backend.
  VoxelMeshDisk.bind(game, false)
  for _, item in ipairs(out) do
    if tostring(item and item.label or "") == "CACHE" then return out end
  end

  local entry = {
    label = "CACHE",
    onSelect = function()
      if VoxelMeshDisk.cacheReadOnly() then
        game.stack:push(VoxelPrecacheScreen.new(game))
        return
      end
      local Menu = require("src.ui.Menu")
      local Screens = require("src.ui.Screens")
      local TextBox = require("src.render.TextBox")
      local function reopen() Screens.push(game, "StartMenu") end
      game.stack:push(Menu.new(game, {
        { label = "SAVE", onSelect = function()
          local before = VoxelMeshDisk.ramStats()
          local ok, saved, failed, errors = VoxelMeshDisk.saveRamToDisk()
          if not ok then
            local Logger = require("src.core.Logger")
            for _, err in ipairs(errors or {}) do
              Logger.error("voxel cache save: %s", tostring(err))
            end
            game.stack:push(TextBox.new(game,
              ("CACHE SAVE FAILED\n%d FILE%s NOT WRITTEN\fCHECK STORAGE ACCESS\nTHEN TRY SAVE AGAIN")
                :format(failed, failed == 1 and "" or "S")))
          elseif saved == 0 then
            game.stack:push(TextBox.new(game, "CACHE ALREADY SAVED"))
          else
            game.stack:push(TextBox.new(game,
              ("CACHE SAVED\n%d FILE%s\n%d IN RAM")
                :format(saved, saved == 1 and "" or "S", before.files)))
          end
        end },
        { label = "DROP", onSelect = function()
          local CM = V.require("ChunkMesher")
          pcall(CM.purgeCache)
          game.stack:push(TextBox.new(game,
            "MESH CACHE DROPPED\nAREAS REBUILD GROUNDED"))
        end },
      }, { tx = 10, ty = 0, tw = 10, onCancel = reopen }))
    end,
  }

  local at = #out + 1
  for i, item in ipairs(out) do
    if tostring(item and item.label or "") == "SAVE" then at = i break end
  end
  table.insert(out, at, entry)
  return out
end)

-- The mod manager writes and persists on its own, so the only thing left
-- to do is move our cached index and pick the new value up.
mod.events:on("mod.options_changed", function(payload)
  if not (payload and payload.mod == mod.id) then return end
  for _, entry in ipairs(SETTINGS) do
    if payload.key == entry[1].key then entry[1]:sync(payload.value) end
  end
  CommunityVisuals.changed(payload.key)
  LegendaryPokeballs.changed()
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
  if mapId then
    ChunkMesher.refresh(mapId)
    Companion:worldChanged("world.block_replaced")
  end
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
        Companion:worldChanged("map.setBlock")
      end
    end
    Map.dramaticShapeBlockHook = true
  end
end

-- A reloaded map replaces the live Map object (warps that re-enter the same
-- map, hot reload), so its GPU mesh and Structures analysis must be released.
-- Do NOT invalidate its persistent files here: their exact fingerprints
-- include the reloaded block layer and tileset. A genuine geometry change is
-- rejected by the disk loader and rebuilt, while an unchanged area can reuse
-- the precache instead of deleting it merely because the player entered it.
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
  Companion:worldChanged("map.reloaded")
  if payload and payload.reason == "colors" then return end
  local mapId = payload and (payload.mapId or (payload.map and payload.map.id))
  if mapId then ChunkMesher.evictRuntime(mapId) end
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
    local newMenu = OptionsMenu.new
    local inner = OptionsMenu.update

    -- Keep ui.options.rows flat, as promised by the hook contract. Only the
    -- latest screen's visible list is collapsed, just like the engine's own
    -- categories keep OptionsMenu.rows flat for mods and focus helpers.
    function OptionsMenu.new(game, opts)
      local menu = newMenu(game, opts)
      if (opts and opts.rows) or not categorizedOptionsAvailable() then
        return menu
      end
      local source, own, first = menu.view or menu.rows or {}, {}, nil
      for i, row in ipairs(source) do
        if row.optionSetting then
          own[#own + 1] = row
          first = first or i
        end
      end
      if not first then return menu end
      local categories = categorizedRows(own)
      local view = {}
      for i, row in ipairs(source) do
        if i == first then
          for _, category in ipairs(categories) do
            view[#view + 1] = category
          end
        end
        if not row.optionSetting then view[#view + 1] = row end
      end
      menu.view = view
      return menu
    end

    local function visibleRows(menu)
      return menu.view or menu.rows or {}
    end

    local function idAt(menu, index)
      local row = visibleRows(menu)[index or 1]
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
        if self.dramaticShapeCategory then
          local members = nil
          for _, row in ipairs(rebuilt.view or rebuilt.rows or {}) do
            if row.id == self.dramaticShapeCategory then
              members = row.members
              break
            end
          end
          self.rows = members or {}
          self.view = self.rows
        else
          self.rows = rebuilt.rows
          self.view = rebuilt.view
        end
        -- Follow the row the cursor was ON rather than the slot it was in:
        -- 3D-BTL takes BATTLE LAYOUT off the list ABOVE itself, which would
        -- otherwise slide the cursor onto the row under the one just used.
        local visible = visibleRows(self)
        for i = 1, #visible do
          if wasOn and idAt(self, i) == wasOn then self.index = i; break end
        end
        local cancel = #visible + 1
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
StadiumBackground.install()

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
VoxelTransitionGate.install()

-- TEST48 SELECT/BACK CAMERA CYCLER, transplanted from N64 Memory TEST455.
-- OverworldController:handleInput is reached only when the overworld itself
-- owns input. Menus (where SELECT opens help), dialogue, scripted movement,
-- transitions and battles are therefore untouched. Installed after FreeMove
-- so 1ST and 3RD cannot swallow the button that is also their way back out.
do
  local OverworldState = require("src.world.OverworldController")
  if not OverworldState.legendarySelectCameraHook then
    local inner = OverworldState.handleInput
    function OverworldState:handleInput(...)
      local Game = require("src.core.Game")
      local input = Game.input
      if input and input.wasPressed and input:wasPressed("select") then
        if cycleVoxelCamera(Game) then return end
      end
      return inner(self, ...)
    end
    OverworldState.legendarySelectCameraHook = true
  end
end

-- Field poison still ticks every fourth step and retains its sound, damage,
-- faint messages and blackout.  Only the engine's full-screen dark pulse is
-- suppressed; on a 3D scene that legacy palette flicker reads as an intrusive
-- display flash rather than feedback on the poisoned party member.
PoisonFlash.install()

-- Red's mom uses a pair of 160x144 white fades around her healing jingle.
-- That legacy rectangle covers only part of a modern 3D viewport, so omit
-- this one script's flashes while preserving its heal, music and dialogue.
MomHealFlash.install()

-- Preserve Ditto's copied species after the engine's Transform animation.
-- This is native Battle Art behaviour and uses no other mod's marker or API.
TransformCompat.install()

-- CamControl.install wires the battle-camera zoom (wheel / pinch) and the
-- right-stick orbit: the inputs that steer the staged battle's rig. It is
-- pcall-guarded inside OverworldBattle.update, so calling it here only
-- matters when a battle is actually on screen.
V.require("CamControl").install()
LegendaryPokeballs.install()

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
-- The intro caches Oak before building its steps. Use the public build hook
-- to replace that portrait without changing generated ROM assets or scripts.
mod.hooks:wrap("intro.oak_speech.build", function(next, steps, speech)
  local out = next(steps, speech)
  local oak = BattleArt.introOakImage()
  if speech and oak then
    speech.oakPic, speech.oakTrueColor = oak, true
    -- The custom trainer sheets are 96px tall. The intro's ROM-authentic
    -- 7-tile bottom alignment otherwise starts them at y=-8 and clips Oak's
    -- hair. Current engines apply this only while oakPic is the active image.
    speech.oakPicOffsetY = 8
  end
  return out
end)

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

-- Interface sprites: our selected-generation front in the non-battle
-- interfaces (title, dex, status/party, hall of fame). Registered after the
-- battle wrap above; it ignores battle contexts and only substitutes for
-- interface ones.
InterfaceSprites.install()

-- Every ending path emits this, including a battle skipped before it drew,
-- so this is where the map's cast comes back.
mod.events:on("battle.ended", function()
  LegendaryPokeballs.finish()
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

-- Render pipelines are engine-owned settings and therefore have no
-- ModSetting schema default. Save creation fires before Game:applyOptions,
-- so writing FULL into an absent key here makes it the true fresh-install
-- default while leaving an explicitly saved OFF untouched.
mod.events:on("save.loaded", function(payload)
  local save = payload and payload.save
  if save and Voxel.seedOptions(save.options) then
    require("src.render.Pipelines").applyOptions(save.options)
  end
  BattleArt.migrateDuplicateSetting()
  DayNight.restore()
  -- a save written before this mod was installed can carry TILT or GBC FX
  -- switched on, and their rows are not there to switch them back off (see
  -- pinEngineFx). Answered here rather than only when the menu opens, so a
  -- player who never opens it is not left playing under one.
  pinEngineFx()
end)

mod.events:on("save.created", function(payload)
  local save = payload and payload.save
  if save then Voxel.seedOptions(save.options) end
  BattleArt.migrateDuplicateSetting()
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

mod.exports.version = "1.10.3"
mod.exports.battlePresentation = BattlePresentation.export()
mod.exports.battleStage = BattleStage.export(OverworldBattle)
mod.exports.voxel_companion = Companion.provider
mod.exports.characterRenderers = CharacterRenderers.export()
-- exposed so a companion mod can pin its own tiles' shapes or read the
-- camera without reaching into this mod's file layout
mod.exports.lib = V
