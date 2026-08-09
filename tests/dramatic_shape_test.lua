-- Dramatic Shape Voxel Mod's own SDK suite: the mod loads clean, both
-- render pipelines land in the "render_pipelines" registry with the shape
-- the engine dispatches on, and the whole thing stays inert on a machine
-- that cannot run the 3D pass (which is exactly what the headless harness
-- is).

package.path = "./?.lua;./?/init.lua;" .. package.path

local T = require("tests.modkit")
local Pipelines = require("src.render.Pipelines")

local Data = T.fixtures.load()
-- DS_MOD_PATH lets the suite run against a copy of the mod. The game holds
-- an open handle on the live directory while it is running, and on Windows
-- that is enough to make the headless loader's directory probe fail, so a
-- run alongside a live session points at a copy instead.
local MOD_PATH = os.getenv("DS_MOD_PATH") or "mods/DramaticShapeVoxelMod"
local run = T.sdk.loadMod(MOD_PATH, { data = Data })

T.eq(#run.errors, 0,
  "DRAMATIC_SHAPE loads clean: " .. table.concat(run.errors, "; "))

-- Game:load does this after the merge; the SDK harness merges into a
-- fixture dataset instead, so point the dispatcher at that one.
Pipelines.install(Data)

-- ------- the records reached the registry

local defs = Data.render_pipelines
T.check(type(defs) == "table", "the merge created the render_pipelines namespace")
T.check(type(defs.voxel) == "table", "the voxel pipeline is registered")
T.check(type(defs.tiltshift) == "table", "the tiltshift pipeline is registered")

T.eq(defs.voxel.label, "VOXEL", "voxel carries its options-row label")
T.eq(defs.tiltshift.label, "T-SHIFT", "tiltshift carries its options-row label")
T.eq(defs.voxel.hotkey, "3", "voxel claims hotkey 3")
T.eq(defs.tiltshift.hotkey, "6", "tiltshift claims hotkey 6")
T.check(type(defs.voxel.drawWorld) == "function",
  "voxel is a world pipeline (drawWorld)")
T.check(type(defs.tiltshift.worldPresent) == "function",
  "tiltshift is a world post-process (worldPresent)")
T.check(defs.tiltshift.drawWorld == nil,
  "tiltshift does not claim the world pass")

-- provenance: a callback that throws at play time must be attributable to
-- this mod, not reported as an engine fault
T.eq(defs._owners and defs._owners.voxel, "DRAMATIC_SHAPE",
  "the merge stamped the pipeline's owning mod")

-- ------- the ladders the engine drives

T.eq(#defs.voxel.levels, 6, "voxel exposes a six-rung ladder")
T.eq(defs.voxel.levels[1], "OFF", "rung 0 is OFF")
T.eq(defs.voxel.levels[2], "FULL",
  "FULL is the first rung after OFF -- the order those two get used in")
T.eq(defs.voxel.levels[6], "75", "the top rung is the 75-degree camera")
T.eq(Pipelines.maxLevel("voxel"), 5, "the engine reads the ladder height")
T.eq(Pipelines.levelLabel("voxel", 3), "35", "the engine reads the rung labels")

-- ------- gating: inert until switched on, and inert without a GPU

T.eq(Pipelines.level("voxel"), 0, "the mode starts switched off")
T.eq(Pipelines.worldPipeline(), nil,
  "nothing owns the world pass while every pipeline is off")

Pipelines.setLevel("voxel", 2)
T.eq(Pipelines.level("voxel"), 2, "the engine can set the mode's level")
-- the headless love stub has no depth canvas, so `available` says no and
-- the engine keeps the vanilla 2D path -- the property that makes the mod
-- safe to ship enabled
T.eq(Pipelines.worldPipeline(), nil,
  "an unavailable pipeline never takes the world pass")

-- one world pipeline at a time, and never alongside the engine's tilt
local Tilt = require("src.render.Tilt")
Tilt.setLevel(3)
Pipelines.setLevel("voxel", 1)
T.eq(Tilt.level, 0, "switching a world pipeline on switches TILT off")

-- a post-process is not a world pipeline, so it composes with tilt
Tilt.setLevel(2)
Pipelines.setLevel("tiltshift", 3)
T.eq(Tilt.level, 2, "a worldPresent pipeline leaves TILT alone")

-- ------- persistence round-trip

local opts = { tilt = 0, pipelines = {} }
Pipelines.syncOptions(opts)
T.eq(opts.pipelines.voxel, 1, "the level is written back to save.options")
T.eq(opts.pipelines.tiltshift, 3, "every pipeline's level is written back")

Pipelines.reset()
T.eq(Pipelines.level("voxel"), 0, "reset clears the live levels")
Pipelines.applyOptions(opts)
T.eq(Pipelines.level("voxel"), 1, "a restored save restores the mode")
T.eq(Pipelines.level("tiltshift"), 3, "a restored save restores the blur")

-- ------- the options rows the menu splices in

local rows = Pipelines.rows({ save = { options = opts } })
T.eq(#rows, 2, "each pipeline contributes exactly one options row")
local byLabel = {}
for _, row in ipairs(rows) do byLabel[row.label] = row end
T.check(byLabel.VOXEL ~= nil, "the VOXEL row is offered")
T.check(byLabel["T-SHIFT"] ~= nil, "the T-SHIFT row is offered")
T.eq(byLabel.VOXEL.value(), "FULL", "the row renders the current rung's label")

-- ------- this mod's own settings
--
-- None of them is a pipeline -- two parameterise the voxel pass rather than
-- owning one, and the third decides what a BATTLE is drawn over, which is
-- not a stage the registry has -- so they reach the same menu through the
-- ui.options.rows hook, and store themselves where the mod manager's
-- settings page looks.

local Runtime = require("src.mods.Runtime")
local VoxelState = run.loader.exports.DRAMATIC_SHAPE.lib.require("VoxelState")

-- ------- FULL is a preset that owns the rows describing the LOOK
--
-- While it is selected the settings it drives come OFF the menu -- including
-- T-SHIFT, which is a pipeline row the engine spliced in. A row that no
-- longer decides anything is worse than no row.
--
-- The two BATTLE rows are the exception and stay. 3D-BTL decides what a fight
-- is drawn over and BACK SPRITES how it is framed; neither is a knob on the
-- diorama the preset is a preset FOR. FULL sets them on arrival and then lets
-- go, which is what makes it a preset rather than a lock.
Pipelines.setLevel("voxel", VoxelState.FULL_LEVEL)
local fullRows = Runtime.call("ui.options.rows", function(_, r) return r end,
                              { data = Data },
                              { { id = "tilt" }, { id = "pipeline:voxel" },
                                { id = "pipeline:tiltshift" } })
local fullIds = {}
for _, row in ipairs(fullRows) do fullIds[row.id] = true end
T.check(fullIds["pipeline:voxel"], "FULL keeps the VOXEL row it lives on")
T.check(not fullIds["pipeline:tiltshift"],
  "FULL takes T-SHIFT off the menu -- it owns the blur")
T.check(not fullIds["DRAMATIC_SHAPE:grid"], "and V-GRID")
T.check(not fullIds["DRAMATIC_SHAPE:curve"], "and V-CURVE")
T.check(not fullIds["DRAMATIC_SHAPE:daytime"], "and DAYTIME")

-- but the battle rows survive it: they are not knobs on the look, and FULL
-- sets them once rather than holding them, so a player who wants the classic
-- back sprite (or no staged fights at all) can still say so from inside FULL
T.check(fullIds["DRAMATIC_SHAPE:battles"], "3D-BTL is still on the menu under FULL")
T.check(fullIds["DRAMATIC_SHAPE:battleBack"], "and BACK SPRITES with it")

-- DAYTIME is not only hidden under FULL, it is HELD at SYNC: the row cannot
-- be reached while FULL owns it, so a value changed underneath (the mod
-- manager's page, an edited options file) snaps back when the menu asks
do
  local DayNight = run.loader.exports.DRAMATIC_SHAPE.lib.require("DayNight")
  DayNight.setting:sync("night")
  Runtime.call("ui.options.rows", function(_, r) return r end,
               { data = Data }, { { id = "tilt" } })
  T.eq(DayNight.setting:get(), "sync",
    "under FULL the rows hook pins DAYTIME back to SYNC, whatever was chosen")
end

-- ------- BATTLE LAYOUT is pinned to OG while a fight can be staged on the map
--
-- The staged battle is composed in the GB's own 160x144 frame: the anchors the
-- arena camera is solved to put a cell under, the HUD rects the frosted panels
-- are cut to, the full-frame white intercepted to let the world through. WIDE
-- lays the same battle out on a 304x144 surface and moves every one of them. So
-- the value is set and the ENGINE's row comes off the menu -- the one row this
-- mod takes away that is not its own.
--
-- Scoped in a block of its own, like the sections below: this file is one Lua
-- chunk and a chunk has 200 local slots, so a section that wants half a dozen
-- borrows them rather than spending them for the rest of the run.
do
local Battles = run.loader.exports.DRAMATIC_SHAPE.lib.require("OverworldBattle")
T.eq(Battles.enabled(), true, "3D-BTL is on by default, which is what pins it")

-- off FULL first: the row on its own has to be enough, and FULL is checked
-- separately below
Pipelines.setLevel("voxel", 2)
local layoutGame = {
  data = Data,
  save = { options = { battleLayout = "wide", pipelines = {}, modOptions = {} } },
  mods = { modOptions = {} },
  writeOptions = function() end,
}
local pinned = Runtime.call("ui.options.rows", function(_, r) return r end,
                            layoutGame,
                            { { id = "battleLayout" }, { id = "tilt" },
                              { id = "pipeline:voxel" } })
local pinnedIds = {}
for _, row in ipairs(pinned) do pinnedIds[row.id] = true end
T.check(not pinnedIds["battleLayout"],
  "with staged battles on, BATTLE LAYOUT is off the menu")
T.eq(layoutGame.save.options.battleLayout, "og",
  "and a save that had WIDE is set to OG -- the only layout the shot composes in")

-- switching 3D-BTL off hands the row straight back, WIDE and all
Battles.setting:setIndex(2, layoutGame)
T.eq(Battles.enabled(), false, "3D-BTL off")
local handedBack = Runtime.call("ui.options.rows", function(_, r) return r end,
                                layoutGame,
                                { { id = "battleLayout" }, { id = "tilt" },
                                  { id = "pipeline:voxel" } })
local backIds = {}
for _, row in ipairs(handedBack) do backIds[row.id] = true end
T.check(backIds["battleLayout"], "the engine's row is back on the menu")
layoutGame.save.options.battleLayout = "wide"
Runtime.call("ui.options.rows", function(_, r) return r end, layoutGame,
             { { id = "battleLayout" } })
T.eq(layoutGame.save.options.battleLayout, "wide",
  "and WIDE is left alone once no battle can be staged on the map")

-- and FULL does not override that. It used to: the preset owned the 3D-BTL row
-- and hid it, so "FULL is selected" was a safe stand-in for "battles are
-- staged". The row is on the menu under FULL now and can be switched off
-- there, so the stand-in would pin BATTLE LAYOUT to OG for a fight that is
-- never staged. The ROW decides, which is what every other reader of this
-- setting already believed.
Pipelines.setLevel("voxel", VoxelState.FULL_LEVEL)
Runtime.call("ui.options.rows", function(_, r) return r end, layoutGame,
             { { id = "battleLayout" } })
T.eq(layoutGame.save.options.battleLayout, "wide",
  "with 3D-BTL off, FULL leaves the layout alone -- it no longer owns that row")

-- switch the row back on and the pin comes back with it, FULL or no FULL.
-- (Arriving at FULL for real runs applyFull, which switches the row on -- so
-- in the game the pin still follows the preset, by way of the row.)
Battles.setting:setIndex(1, layoutGame)
Runtime.call("ui.options.rows", function(_, r) return r end, layoutGame,
             { { id = "battleLayout" } })
T.eq(layoutGame.save.options.battleLayout, "og",
  "and the row switched back on pins it again, from inside FULL")
end

-- ------- TILT and GBC FX are off the menu entirely
--
-- Two ENGINE rows, taken away for as long as this mod is installed. Both fight
-- the diorama and both were already half-taken -- the mode's own key forces
-- them off on every press, and the registry switches TILT off whenever a world
-- pipeline takes the pass -- so what was left was two rows a player could set
-- and watch get reverted.
--
-- Dropped AND held at zero, which is the part that matters: a save written
-- before the mod was installed can carry TILT 3, and a row that is not there
-- is a row that cannot turn it back off.
do
local fxGame = {
  data = Data,
  save = { options = { tilt = 3, gbcfx = 2, pipelines = {}, modOptions = {} } },
  mods = { modOptions = {} },
  writeOptions = function() end,
}
local Tilt = require("src.render.Tilt")
local GBCFX = require("src.render.GBCFX")
Tilt.setLevel(3)
GBCFX.setLevel(2)

local fxRows = Runtime.call("ui.options.rows", function(_, r) return r end,
                            fxGame,
                            { { id = "tilt" }, { id = "gbcfx" },
                              { id = "colors" }, { id = "pipeline:voxel" } })
local fxIds = {}
for _, row in ipairs(fxRows) do fxIds[row.id] = true end
T.check(not fxIds["tilt"], "TILT is off the OPTIONS menu")
T.check(not fxIds["gbcfx"], "and so is GBC FX")
T.check(fxIds["colors"] and fxIds["pipeline:voxel"],
  "with every other row the engine offered still on it")

T.eq(fxGame.save.options.tilt, 0,
  "a save that had TILT on is pinned back to off, not left on with no row")
T.eq(fxGame.save.options.gbcfx, 0, "and GBC FX with it")
T.eq(Tilt.level, 0, "the live level follows, so the frame is not still tilted")

-- and FULL, which takes its own branch through the rows hook, must not be a
-- way back in
Pipelines.setLevel("voxel", VoxelState.FULL_LEVEL)
local fullFx = Runtime.call("ui.options.rows", function(_, r) return r end,
                            fxGame, { { id = "tilt" }, { id = "gbcfx" } })
local fullFxIds = {}
for _, row in ipairs(fullFx) do fullFxIds[row.id] = true end
T.check(not fullFxIds["tilt"] and not fullFxIds["gbcfx"],
  "under FULL they are gone too -- the drop is above every branch")
Pipelines.setLevel("voxel", 2)
end

-- ------- and off FULL, the rows come back, grouped with the mode
--
-- The engine splices a pipeline row in beside TILT and lands a mod's own
-- additions at the END of the list, which would leave this mode's four rows
-- in two places with unrelated rows between them.
Pipelines.setLevel("voxel", 2)
local grouped = Runtime.call("ui.options.rows", function(_, r) return r end,
                             { data = Data },
                             { { id = "tilt" }, { id = "pipeline:voxel" },
                               { id = "pipeline:tiltshift" },
                               { id = "void_fill" } })
local order = {}
for i, row in ipairs(grouped) do order[row.id] = i end
T.check(order["pipeline:tiltshift"] < order["DRAMATIC_SHAPE:grid"],
  "the mode's settings follow its pipeline rows")
T.eq(order["DRAMATIC_SHAPE:battles"] - order["pipeline:tiltshift"], 3,
  "and sit in one unbroken block, not scattered to the end of the list")
T.check(order["void_fill"] > order["DRAMATIC_SHAPE:battles"],
  "with the engine's own later rows still after them")

-- ------- the open menu notices when FULL is stepped onto or off
--
-- OptionsMenu reads its row list every frame but builds it once, so without
-- a rebuild the rows FULL owns stay on screen until the menu is reopened --
-- and stepping OFF FULL never brings them back.
local OptionsMenu = require("src.ui.OptionsMenu")
local pressed = {}
local menuGame = {
  data = Data,
  save = { options = { pipelines = {}, modOptions = {} } },
  mods = { modOptions = {} },
  input = { wasPressed = function(_, k) return pressed[k] or false end },
  stack = { pop = function() end },
  writeOptions = function() end,
}

Pipelines.setLevel("voxel", 2)
local menu = OptionsMenu.new(menuGame)
local function rowIndex(m, id)
  for i, row in ipairs(m.rows) do if row.id == id then return i end end
end
T.check(rowIndex(menu, "DRAMATIC_SHAPE:grid"),
  "off FULL the menu opens with the mode's settings on it")

-- step the VOXEL row from 15 down to FULL, the way the player would
menu.index = rowIndex(menu, "pipeline:voxel")
pressed = { left = true }
menu:update(0)
pressed = {}
T.eq(Pipelines.level("voxel"), 1, "the step landed on FULL")
T.check(not rowIndex(menu, "DRAMATIC_SHAPE:grid"),
  "and the rows FULL owns left the OPEN menu at once")
T.check(not rowIndex(menu, "pipeline:tiltshift"), "T-SHIFT with them")
T.check(menu.index <= #menu.rows + 1, "the cursor stayed in range")

-- and back off it again
menu.index = rowIndex(menu, "pipeline:voxel")
pressed = { right = true }
menu:update(0)
pressed = {}
T.eq(Pipelines.level("voxel"), 2, "the step left FULL")
T.check(rowIndex(menu, "DRAMATIC_SHAPE:grid"),
  "and the rows came straight back without reopening the menu")
T.check(rowIndex(menu, "pipeline:tiltshift"), "T-SHIFT too")

-- ------- 3D-BTL owns BATTLE LAYOUT, and takes it off the OPEN menu too
--
-- The row this one takes away sits ABOVE it in the list, so the cursor has to
-- follow the row it was ON rather than the slot it was in -- otherwise the very
-- press that switched staged battles on would leave the cursor a row further
-- down than the player left it.
do
local Battles = run.loader.exports.DRAMATIC_SHAPE.lib.require("OverworldBattle")
Battles.setting:setIndex(2, menuGame)             -- staged battles off
menuGame.save.options.battleLayout = "wide"
Pipelines.setLevel("voxel", 2)
local layoutMenu = OptionsMenu.new(menuGame)
T.check(rowIndex(layoutMenu, "battleLayout"),
  "with staged battles off, the engine's BATTLE LAYOUT row is on the menu")
layoutMenu.index = rowIndex(layoutMenu, "DRAMATIC_SHAPE:battles")
pressed = { right = true }
layoutMenu:update(0)
pressed = {}
T.eq(Battles.setting:get(), true, "the step switched staged battles on")
T.check(not rowIndex(layoutMenu, "battleLayout"),
  "and BATTLE LAYOUT left the open menu with the same keypress")
T.eq(menuGame.save.options.battleLayout, "og", "pinned to OG on the way out")
T.eq(layoutMenu.index, rowIndex(layoutMenu, "DRAMATIC_SHAPE:battles"),
  "with the cursor still on the row the player just used")
end

-- level 2 is the "15" rung: any rung that is not FULL, so the settings the
-- preset owns are back on the menu
Pipelines.setLevel("voxel", 2)
local hookedRows = Runtime.call("ui.options.rows", function(_, r) return r end,
                               { data = Data }, { { id = "text_speed" } })
T.eq(#hookedRows, 6, "the options hook added a row per setting")
local grid, curve, battles = hookedRows[2], hookedRows[3], hookedRows[4]
local backRow, daytime = hookedRows[5], hookedRows[6]
T.eq(daytime.label, "DAYTIME", "the day/night row carries its label")
T.eq(daytime.value(), "SYNC",
  "and defaults to SYNC -- no value set follows the clock on the wall")
T.eq(grid.label, "V-GRID", "the grid row carries its label")
T.eq(grid.value(), "OFF", "the grid starts off")
T.eq(curve.label, "V-CURVE", "the curve row carries its label")
T.eq(curve.value(), "OFF", "the curve starts off")
T.eq(battles.label, "3D-BTL", "the overworld-battle row carries its label")
T.eq(battles.value(), "ON",
  "overworld battles are on by default -- the mode's headline is the world "
  .. "in 3D, and a battle is where the player spends half the game")
T.eq(backRow.label, "BACK SPRITES", "the back-pic row carries its label")
T.eq(backRow.value(), "OFF",
  "and is off by default -- what the mode advertises is BOTH mons out on the "
  .. "map, so the classic slot is opt-in")
T.check(backRow.id ~= battles.id and backRow.id:find("battleBack", 1, true),
  "on its own key, so it persists beside 3D-BTL rather than over it")

-- stepping writes through to the one place both rows read
local settingGame = { save = { options = {} }, mods = { modOptions = {} } }
grid.step(settingGame)
T.eq(grid.value(), "ON", "stepping the row toggles the grid")
T.eq(settingGame.save.options.modOptions.DRAMATIC_SHAPE.grid, true,
  "the toggle lands in options.modOptions, where the mod manager reads it")
T.eq(settingGame.mods.modOptions.DRAMATIC_SHAPE.grid, true,
  "and in the loader's live copy, which mod.options:get reads")
grid.step(settingGame)
T.eq(grid.value(), "OFF", "stepping again toggles it back")

-- the curve is a four-rung ladder rather than a toggle, and wraps
curve.step(settingGame, 1)
T.eq(curve.value(), "1", "stepping the curve climbs its ladder")
T.eq(settingGame.save.options.modOptions.DRAMATIC_SHAPE.curve, 1,
  "the curve level persists alongside the grid, not over it")
T.eq(settingGame.save.options.modOptions.DRAMATIC_SHAPE.grid, false,
  "and the grid it shares a bucket with is untouched")
curve.step(settingGame, 1)
curve.step(settingGame, 1)
T.eq(curve.value(), "3", "the ladder reaches its top rung")
curve.step(settingGame, 1)
T.eq(curve.value(), "OFF", "and wraps back to OFF")
curve.step(settingGame, -1)
T.eq(curve.value(), "3", "stepping down from OFF wraps to the top")
curve.step(settingGame, 1)

-- the strength scales with the view height, so a rung looks the same at
-- every zoom -- and is exactly zero when the setting is off
local WorldCurve = run.loader.exports.DRAMATIC_SHAPE.lib.require("WorldCurve")
T.eq(WorldCurve.k(154), 0, "an OFF curve bends nothing")
curve.step(settingGame, 1)
T.check(math.abs(WorldCurve.k(154) - WorldCurve.AMOUNTS[2] / 154) < 1e-9,
  "rung 1's coefficient is its amount over the view height")
T.check(WorldCurve.AMOUNTS[2] < WorldCurve.AMOUNTS[3]
        and WorldCurve.AMOUNTS[3] < WorldCurve.AMOUNTS[4],
  "the ladder climbs")
T.check(math.abs(WorldCurve.k(308) * 2 - WorldCurve.k(154)) < 1e-9,
  "halving the zoom halves the coefficient, so the bend looks the same")
-- the CPU copy Voxel3D.project uses must agree with the shader's quadratic
local k = WorldCurve.k(154)
T.eq(WorldCurve.drop(k, 100, 100, 100, 100), 0,
  "nothing drops at the focus, so the ground underfoot stays flat")
T.check(math.abs(WorldCurve.drop(k, 0, 0, 3, 4) - 25 * k) < 1e-9,
  "the drop is the squared distance times the coefficient")
T.check(WorldCurve.drop(k, 0, 0, 20, 0) > 4 * WorldCurve.drop(k, 0, 0, 10, 0)
        - 1e-9,
  "and accelerates, so the far edge rolls away faster than the near one")
curve.step(settingGame, 1)
curve.step(settingGame, 1)
curve.step(settingGame, 1)
T.eq(curve.value(), "OFF", "the curve is left off for the rows below")

-- ------- the animated terrain atlas survives an engine without its seams
--
-- Regression: cycling palette modes with voxel mode on eventually killed
-- the pass outright --
--
--   render pipeline voxel failed: lib/TerrainAtlas.lua:192: attempt to
--   call field 'atlasImageData' (a nil value) -- disabled for this session
--
-- TerrainAtlas reads three OPTIONAL engine seams (README, "engine
-- internals"); this build ships only defaultAnimatedTiles, so animFrame and
-- atlasImageData are both absent. animFrame was already read guarded and
-- degrades to a frozen clock. atlasImageData was called straight, and only
-- on the branch where staticAtlas did NOT bake its own pixels -- which is
-- exactly what a palette change flips. Every mode whose world palette is
-- absent (pal() -> nil), plus RED++ (whose per-map bake sets gbcAtlas) and
-- any trueColor tileset, hands `baked = false` down to newEntry. So the
-- first map with animated water or flowers entered under one of those modes
-- took the whole pipeline down for the session.
--
-- The harness has no love.image at all, which is why the checks above never
-- reached this branch. Stand up just enough of one to walk it.

local TerrainAtlas = run.loader.exports.DRAMATIC_SHAPE.lib.require("TerrainAtlas")
local TileRenderer = require("src.render.TileRenderer")

local realImage, realNewImage = love.image, love.graphics.newImage

local function fakePixels(w, h)
  local d = { w = w or 128, h = h or 48 }
  function d:getDimensions() return self.w, self.h end
  function d:getPixel() return 0.5, 0.5, 0.5, 1 end
  function d:setPixel() end
  function d:paste() end
  return d
end

love.image = { newImageData = function(a, b)
  if type(a) == "number" then return fakePixels(a, b) end
  return fakePixels()          -- the "decoded from a path" overload
end }
-- animate() only uploads when the animation step actually turns over, so
-- counting replacePixels is how the suite sees the step move from outside.
-- builds counts entries made, and uploadFails forces the upload to throw.
local patches, builds, uploadFails = 0, 0, false
love.graphics.newImage = function()
  builds = builds + 1
  return { setFilter = function() end,
           replacePixels = function()
             if uploadFails then error("transient upload failure", 0) end
             patches = patches + 1
           end }
end

-- a tileset whose water tile rotates, i.e. one specsFor will accept
local function animatedMap(id, renderer)
  return {
    id = id,
    tileset = {
      -- a label, never opened: love.image is stubbed above
      image = "assets/tilesets/overworld.png",
      tilesPerRow = 16,
      animatedTiles = { { tile = 0x14, kind = "hshift",
                          offsets = { 0, 1, 2, 3 }, period = 20 } },
    },
    renderer = renderer,
  }
end

-- stands in for the atlas texture: what the engine hands over as
-- renderer.image, and what animate() patches through replacePixels
local base = { replacePixels = function() end,
               getDimensions = function() return 128, 48 end }

T.eq(TileRenderer.atlasImageData, nil,
  "this engine build does not carry the atlasImageData seam (the premise)")

-- 1. the crash itself: no bake of our own, and no engine seam to ask
TerrainAtlas.invalidate()
local plain = animatedMap("PLAIN", { image = base })
local ok, err = pcall(TerrainAtlas.animate, plain, nil, base, false)
T.check(ok, "an unbaked atlas does not take the pipeline down: " .. tostring(err))

-- 2. and it is a real recovery, not a shrug: the pixels behind an atlas the
--    engine never replaced are the tileset art, so the animation still runs
TerrainAtlas.invalidate()
local okArt, artImg = pcall(TerrainAtlas.animate, plain, nil, base, false)
T.check(okArt and artImg ~= nil,
  "unbaked terrain still animates, from the tileset art the atlas was built from")

-- 3. RED++ bakes per map and keeps no ImageData, so those pixels come back
--    off the texture. Where the driver will not read a canvas back -- which
--    is this harness, whose stub canvas has no newImageData -- the fallback
--    is to decline rather than patch grey art into a coloured atlas.
TerrainAtlas.invalidate()
local gbc = animatedMap("GBC", { image = base, gbcAtlas = true })
local okGbc, gbcImg = pcall(TerrainAtlas.animate, gbc, nil, base, false)
T.check(okGbc, "a RED++ atlas does not take the pipeline down either")
T.eq(gbcImg, nil, "and declines rather than patching raw art into a baked atlas")

-- 3b. give the harness a canvas it CAN read back and the same map animates,
--     with the pass's own render target put back afterwards -- this runs
--     mid-frame, so unbinding instead of restoring would cost the frame.
TerrainAtlas.invalidate()
local passCanvas = { name = "the pipeline's own target" }
love.graphics.setCanvas(passCanvas)
local realNewCanvas = love.graphics.newCanvas
love.graphics.newCanvas = function(w, h)
  return { w = w, h = h, setFilter = function() end,
           release = function() end,
           newImageData = function() return fakePixels(w, h) end }
end
local okRead, readImg = pcall(TerrainAtlas.animate, gbc, nil, base, false)
T.check(okRead and readImg ~= nil,
  "a RED++ atlas animates from a texture readback when the driver allows it")
T.eq(love.graphics.getCanvas(), passCanvas,
  "and the readback puts the pass's render target back")
love.graphics.newCanvas = realNewCanvas
love.graphics.setCanvas()

-- 3c. RED++ WITH the renderer's data in hand: the atlas is rebuilt on the
--     CPU from the raw art and the map's palette groups, so water animates
--     under RED++ without asking the driver for anything. This is the case
--     that was actually broken on hardware -- RED++ is the only mode where
--     staticAtlas declines to bake, so it was the only mode whose animated
--     tiles depended on a readback, and it stood still.
TerrainAtlas.invalidate()
local realNewCanvas2 = love.graphics.newCanvas
love.graphics.newCanvas = function() error("driver refuses canvas readback", 0) end
local redppMap = animatedMap("REDPP",
  { image = base, gbcAtlas = true, data = Data })
redppMap.id = "PALLET_TOWN"          -- a map the palette groups know about
redppMap.tileset.id = "OVERWORLD"
local PaletteFX = require("src.render.PaletteFX")
local modeWas = PaletteFX.mode
PaletteFX.mode = "redpp"
local okRedpp, redppImg = pcall(TerrainAtlas.animate, redppMap, nil, base, false)
T.check(okRedpp and redppImg ~= nil,
  "RED++ animates from a CPU rebuild, with no readback available at all")
PaletteFX.mode = modeWas
love.graphics.newCanvas = realNewCanvas2

-- 3d. A failure that might not repeat must not cost the animation for the
--     rest of the session. It used to: the key was condemned on the first
--     miss and nothing rebuilt it, so water stopped and stayed stopped.
TerrainAtlas.invalidate()
uploadFails = true
T.eq(TerrainAtlas.animate(plain, nil, base, false), nil,
  "a patch that throws declines the frame")
uploadFails = false
local okRetry, retryImg = pcall(TerrainAtlas.animate, plain, nil, base, false)
T.check(okRetry and retryImg ~= nil,
  "and the next frame rebuilds, rather than staying dead until a hot reload")

-- but a key that keeps failing is given up on, not rebuilt every frame
TerrainAtlas.invalidate()
uploadFails = true
for _ = 1, 6 do TerrainAtlas.animate(plain, nil, base, false) end
local settledBuilds = builds
for _ = 1, 6 do TerrainAtlas.animate(plain, nil, base, false) end
T.eq(builds, settledBuilds,
  "a key that fails repeatedly is condemned rather than rebuilt forever")
uploadFails = false
TerrainAtlas.invalidate()

-- 4. the reported path end to end: cycle every palette mode over a map with
--    animated tiles. PaletteFX.pal returns nil for a mode with no world
--    palette, which is the `colors = nil` that flips staticAtlas to no-bake.
local PaletteFX = require("src.render.PaletteFX")
local sgb = { { 1, 1, 1 }, { 0.6, 0.6, 0.6 }, { 0.3, 0.3, 0.3 }, { 0, 0, 0 } }
for _, mode in ipairs(PaletteFX.MODES) do
  for _, colors in ipairs({ sgb, false }) do   -- false stands in for nil
    TerrainAtlas.invalidate()
    local okMode = pcall(TerrainAtlas.forMap, animatedMap("M_" .. mode, { image = base }),
                         colors or nil)
    T.check(okMode, "palette mode " .. mode .. " survives a terrain atlas build"
                    .. (colors and " (with a world palette)" or " (with none)"))
  end
end

-- 5. forward compatible: a build that DOES carry the seam is preferred over
--    reading the art back off disk, and one that throws is still survivable
TerrainAtlas.invalidate()
local asked = false
TileRenderer.atlasImageData = function() asked = true; return fakePixels() end
local okSeam, seamImg = pcall(TerrainAtlas.animate, plain, nil, base, false)
T.check(okSeam and seamImg ~= nil,
  "an engine that provides the seam still animates")
T.check(asked, "and the engine's own accessor is what was asked")

TerrainAtlas.invalidate()
TileRenderer.atlasImageData = function() error("seam is angry") end
local okThrow = pcall(TerrainAtlas.animate, plain, nil, base, false)
T.check(okThrow, "a seam that throws costs the animation, not the pipeline")

TileRenderer.atlasImageData = nil

-- ------- the tile clock, the other half of the same seam problem
--
-- animFrame is the engine's 60Hz tile-animation counter and this build does
-- not export it either. It was read guarded, so it never crashed -- it just
-- answered 0 forever, which pinned every animated tile at step 0: water and
-- flowers stood still in voxel mode and nowhere else. It is a plain local in
-- TileRenderer, but an upvalue of the exported tick(), so the mod reads the
-- real counter rather than inventing one. That distinction is the point: the
-- flat tile layer draws from this same number, so a mode switch mid-cycle
-- continues the animation instead of restarting it.

local clock = TerrainAtlas._animFrame
T.check(type(clock) == "function", "the atlas exposes its clock for the suite")

T.eq(TileRenderer.animFrame, nil,
  "this engine build does not carry the animFrame seam either (the premise)")

local before = clock()
for _ = 1, 7 do TileRenderer.tick(nil) end
T.eq(clock() - before, 7, "the clock follows the engine's tick, rather than sitting at 0")
TileRenderer.tick(1 / 60)
T.eq(clock() - before, 8, "and a 60Hz frame of wall time advances it exactly one step")

-- End to end, and observed from OUTSIDE the clock: animate() re-uploads the
-- atlas only when the step turns over, so walking a full cycle has to
-- produce one upload per step. This is what a frozen clock silently
-- prevented -- it uploads once and then agrees with itself forever, which
-- is why reading the counter back here would prove nothing.
local spec = plain.tileset.animatedTiles[1]
TerrainAtlas.invalidate()
patches = 0
TerrainAtlas.animate(plain, nil, base, false)   -- builds, uploads step 0
local built = patches
for _ = 1, #spec.offsets do
  for _ = 1, spec.period do TileRenderer.tick(nil) end
  TerrainAtlas.animate(plain, nil, base, false)
end
T.eq(patches - built, #spec.offsets,
  "walking a full cycle re-patches the atlas once per step, rather than freezing at step 0")

-- repeat calls inside one step must NOT re-upload: animate() runs once per
-- map in the neighbourhood every frame, and repatching ~130 pixels each
-- time is the cost the step check exists to avoid
local settled = patches
for _ = 1, 5 do TerrainAtlas.animate(plain, nil, base, false) end
T.eq(patches, settled, "and holds still between steps rather than repatching every call")

-- and the same two guarantees the pixel seam gets: prefer the real thing,
-- survive a broken one
TileRenderer.animFrame = function() return 4242 end
T.eq(clock(), 4242, "an engine that exports the clock is preferred over the upvalue")
TileRenderer.animFrame = function() error("clock is angry") end
local okClock, clockVal = pcall(clock)
T.check(okClock and type(clockVal) == "number",
  "a clock that throws falls back to a working one rather than propagating")
TileRenderer.animFrame = nil

-- ------- the flower's slot carries an animated SILHOUETTE, not a tile
--
-- The flower tile stands in voxel mode as a billboard one voxel deep
-- (Structures.buildFlowers), cut to the drawing's darkest tones. Meshes
-- are static, so the geometry spans the union of every frame's dark
-- pixels and the animation lives in the atlas: patch() keys everything
-- lighter to alpha 0, the shader discards it, and the silhouette trims
-- itself frame by frame. Two halves to pin down: the CLASS is derived
-- (any frames-animated tile resolves `flower` with no profile entry),
-- and the PATCH writes alpha where the frame is not dark.

local TileShape = run.loader.exports.DRAMATIC_SHAPE.lib.require("TileShape")

local flowerSet = {
  id = "T_FLOWER_PIN", image = "assets/tilesets/stub.png",
  tilesPerRow = 16, imageWidth = 128, imageHeight = 48,
  animatedTiles = { { tile = 0x03, kind = "frames", period = 20,
                      images = { "stub_flowerframe.png" },
                      sequence = { 1 } } },
}
local flowerShapes = TileShape.forMap({ tileset = flowerSet })
T.eq(flowerShapes[0x03].class, "flower",
  "a frames-animated tile is pinned `flower` with no profile entry, like grass")
T.check(flowerShapes[0x03].flat,
  "the flower cell still counts as flat ground for its neighbours")
T.eq(flowerShapes[0x03].h, 0,
  "and carries no height, so a build with no pixel access degrades to the flat tile")
T.check(flowerShapes[0x03].authored,
  "the pin is authored-strength: cell walkability cannot re-file it as plain ground")

-- the patch, observed through a recording atlas copy: a crafted frame
-- whose dark pixels form a diamond ring around one light pixel -- the
-- billboard must keep the ring AND the pale pixel it encloses, and key
-- the reachable background (light or transparent) to alpha
local slotPx = {}
local sectionNewImageData = love.image.newImageData
do
  local crafted = fakePixels()
  local ring = { ["1,0"] = true, ["0,1"] = true,
                 ["2,1"] = true, ["1,2"] = true }
  local frame = fakePixels()
  function frame:getPixel(x, y)
    if ring[x .. "," .. y] then return 0.3, 0.3, 0.3, 1 end -- dark outline
    if x == 7 and y == 0 then return 0.9, 0.9, 0.9, 0 end   -- transparent
    return 1, 1, 1, 1                       -- light: petal inside at (1,1),
  end                                       -- background everywhere else
  love.image.newImageData = function(a, b)
    if type(a) == "number" then
      local d = fakePixels(a, b)
      function d:setPixel(x, y, r, g, b2, al)
        slotPx[x .. "," .. y] = { r, g, b2, al }
      end
      return d
    end
    if tostring(a):find("flowerframe") then return frame end
    return crafted
  end
end

TerrainAtlas.invalidate()
local fmap = {
  id = "T_FLOWER_PATCH_MAP",
  tileset = {
    id = "T_FLOWER_PATCH", image = "assets/tilesets/stub2.png",
    tilesPerRow = 16, imageWidth = 128, imageHeight = 48,
    animatedTiles = { { tile = 0x03, kind = "frames", period = 20,
                        images = { "stub_flowerframe.png" },
                        sequence = { 1 } } },
  },
  renderer = { image = base },
}
local okFlower, flowerImg = pcall(TerrainAtlas.animate, fmap, nil, base, false)
T.check(okFlower and flowerImg ~= nil,
  "a flower map animates: " .. tostring(flowerImg))

local fdx = (0x03 % 16) * 8
local function slotAlpha(x, y)
  local p = slotPx[(fdx + x) .. "," .. y]
  return p and p[4]
end
T.eq(slotAlpha(1, 0), 1,
  "a dark frame pixel lands opaque -- it is the standing cutout")
T.eq(slotAlpha(1, 1), 1,
  "and so does the pale pixel the outline encloses -- the petal's inside "
  .. "rides the billboard, not just its outline")
T.eq(slotAlpha(5, 5), 0,
  "a background pixel is keyed to alpha, so the billboard's shader discards it")
T.eq(slotAlpha(7, 0), 0,
  "a transparent frame pixel stays clear rather than painting black")

love.image.newImageData = sectionNewImageData

TerrainAtlas.invalidate()
love.image, love.graphics.newImage = realImage, realNewImage

-- ------- a palette switch must not drop the geometry
--
-- Regression: toggling palettes in voxel mode flashed the flat 2D world for
-- a moment on every switch.
--
-- PaletteFX.setMode reloads the live map to rebuild its atlas, passing
-- reason "colors", and this mod dropped the map's terrain mesh on any
-- map.reloaded at all. Mesh builds are asynchronous, so the frames between
-- the drop and the first rebuilt mesh have no terrain -- and a voxel
-- drawWorld with no terrain returns nil, which IS the engine's 2D
-- fallback. The geometry was never stale to begin with: the mesher reads
-- block layout and tile ids, and the palette lives in the texture.
--
-- Every OTHER reload still has to drop it, so this pins the distinction
-- rather than just the fix.

local ChunkMesher = run.loader.exports.DRAMATIC_SHAPE.lib.require("ChunkMesher")
local Runtime = require("src.mods.Runtime")

local realInvalidate = ChunkMesher.invalidate
local realRefresh = ChunkMesher.refresh
local dropped, refreshed = {}, {}
ChunkMesher.invalidate = function(id) dropped[#dropped + 1] = id or "<every map>" end
ChunkMesher.refresh = function(id) refreshed[#refreshed + 1] = id or "<every map>" end

Runtime.emit("map.reloaded", { mapId = "PALLET_TOWN", reason = "colors" })
T.eq(#dropped, 0,
  "a palette switch keeps the terrain mesh, so the diorama stays on screen")

Runtime.emit("map.reloaded", { mapId = "PALLET_TOWN", reason = "invalidate" })
T.eq(#dropped, 1, "a reload for any other reason still drops the stale mesh")
T.eq(dropped[1], "PALLET_TOWN", "and drops exactly the map that reloaded")

-- the reason field is the engine's, not ours: a payload without one is a
-- real reload and must still invalidate
Runtime.emit("map.reloaded", { mapId = "VIRIDIAN_CITY" })
T.eq(#dropped, 2, "a reload with no stated reason is treated as a real one")

-- a block edit (Cut, a door stamp, the tree regrowing on re-entry) is a
-- REFRESH, not a drop: the stale mesh keeps drawing while the rebuild
-- cooks, so the scene never blinks down to the flat 2D path
Runtime.emit("world.block_replaced", { mapId = "PALLET_TOWN" })
T.eq(#dropped, 2, "a replaced block does not drop the mesh outright")
T.eq(#refreshed, 1, "it refreshes the mesh in place instead")
T.eq(refreshed[1], "PALLET_TOWN", "and refreshes exactly the edited map")

-- ------- and the edits the engine does NOT announce
--
-- Cut swaps its tree block, the regrowth restores it on re-entry, and the
-- card-key doors are stamped on floor load -- all writing the block layer
-- directly, none of them emitting world.block_replaced. The mod wraps
-- Map:setBlock rather than asking the engine to announce each one (an
-- earlier cut changed the engine, which is the wrong place: it edits the
-- game for one mod, and every future block write has to remember).
--
-- These run through a REAL Map, so they also pin that the wrap survives
-- whatever the engine does to that method.

local Map = require("src.world.Map")
local function fakeMap(id)
  return setmetatable({
    id = id,
    def = { width = 2, height = 2, blocks = { 1, 1, 1, 1 }, borderBlock = 0 },
  }, Map)
end

local m = fakeMap("ROUTE_2")
refreshed = {}

m:setBlock(0, 0, 9)
T.eq(#refreshed, 1, "a direct setBlock refreshes the mesh -- this is Cut's path")
T.eq(refreshed[1], "ROUTE_2", "and names the map that was edited")
T.eq(m:blockAt(0, 0), 9, "and the block really changed")

-- the regrowth rewrites every block it recorded, changed or not; a write
-- that changes nothing must not throw the mesh away
m:setBlock(0, 0, 9)
T.eq(#refreshed, 1, "rewriting a block with the value it already held is not an edit")

-- setBlock silently ignores an out-of-bounds write, so there is nothing
-- to rebuild for one
m:setBlock(99, 99, 3)
T.eq(#refreshed, 1, "an out-of-bounds write refreshes nothing")

ChunkMesher.invalidate = realInvalidate
ChunkMesher.refresh = realRefresh

-- ------- the non-colour palette modes must not come through as SGB
--
-- Regression: GRAY, INVERTED and CLASSIC all rendered as the SGB palette in
-- voxel mode -- grey and inverted came out blue.
--
-- The engine's paletteFor hands back a map's RAW SGB zone palette. The flat
-- path then runs it through PaletteFX.effectiveColors on the way to the
-- shade-remap shader, and THAT is where the non-colour modes happen: OG and
-- OG INV swap in the DMG greys, CLASSIC swaps in the green set, GBC INV
-- permutes the zone's own shades. This pass bakes colour into the atlas
-- ahead of the draw instead of shading at blit time, so it never reached
-- that call and every mode drew the raw zone palette.
--
-- Asserted against what each mode should PAINT, not against the engine
-- function, so this stays a claim about the picture rather than a
-- restatement of the implementation.

local VoxelScene = run.loader.exports.DRAMATIC_SHAPE.lib.require("VoxelScene")
local modeColors = VoxelScene._modeColors
T.check(type(modeColors) == "function", "the scene exposes its palette resolve")

-- a recognisable stand-in for a map's SGB zone palette: strongly blue, so
-- "came through as SGB" is visible in the values themselves
local sgbBlue = { { 248, 248, 248 }, { 96, 152, 232 },
                  { 40, 80, 176 }, { 8, 24, 64 } }
local function paletteForBlue() return sgbBlue end
local function under(mode, fn)
  local prev = PaletteFX.mode
  PaletteFX.mode = mode
  local ok, err = pcall(fn)
  PaletteFX.mode = prev
  if not ok then error(err, 0) end
end

local function sameColors(a, b)
  if not (a and b) then return false end
  for i = 1, 4 do
    for ch = 1, 3 do
      if a[i][ch] ~= b[i][ch] then return false end
    end
  end
  return true
end

under("gbc", function()
  T.check(sameColors(modeColors(paletteForBlue), sgbBlue),
    "GBC is a colour mode, so the zone palette passes through untouched")
end)

under("og", function()
  local c = modeColors(paletteForBlue)
  T.check(sameColors(c, PaletteFX.GRAYS),
    "GRAY paints the DMG greys, not the map's SGB blue")
  T.check(not sameColors(c, sgbBlue), "and is not the SGB palette in disguise")
end)

under("og_inv", function()
  local c = modeColors(paletteForBlue)
  T.check(sameColors(c, PaletteFX.permute(PaletteFX.GRAYS,
                                          { [0] = 3, [1] = 2, [2] = 1, [3] = 0 })),
    "GRAY INV paints the greys with the shade ramp reversed")
  T.eq(c[1][1], PaletteFX.GRAYS[4][1],
    "so the lightest shade becomes the darkest -- an actual inversion")
end)

under("classic", function()
  T.check(sameColors(modeColors(paletteForBlue), PaletteFX.CLASSIC),
    "CLASSIC paints the green DMG set")
end)

under("gbc_inv", function()
  local c = modeColors(paletteForBlue)
  T.check(not sameColors(c, sgbBlue), "GBC INV does not pass the zone palette through")
  for i = 1, 4 do
    T.check(sameColors({ c[i], c[i], c[i], c[i] },
                       { sgbBlue[5 - i], sgbBlue[5 - i], sgbBlue[5 - i], sgbBlue[5 - i] }),
      "GBC INV reverses the zone's own shades, keeping its colours (shade " .. i .. ")")
  end
end)

-- a map with no palette at all stays uncoloured rather than inventing one,
-- which is what the flat path does when it has nothing to send the shader
T.eq(modeColors(function() return nil end), nil,
  "a map with no world palette bakes no colour, as on the flat path")
T.eq(modeColors(nil), nil, "and a pipeline given no paletteFor at all is safe")

-- ------- the hotkeys this mod claims
--
--   3  VOXEL    cycle the camera ladder
--   5  V-GRID   toggle the wireframe
--   6  T-SHIFT  cycle the blur ladder
--   7  V-CURVE  cycle the horizon bend
--   8  3D-BTL   toggle overworld battles
--
-- Only 6 reaches the pipeline registry the documented way. Game:keypressed
-- answers the engine's own display keys first and returns -- 3 is TILT and
-- 5 is GBC FX -- expressly so a pipeline cannot shadow one, and 7 and 8
-- belong to settings that own no pass and so have no registry to claim
-- from. The mod therefore wraps Game:keypressed, and these pin what that
-- wrapper is allowed to take.

local Game = require("src.core.Game")
Pipelines.reset()
Pipelines.setLevel("voxel", 0)
Pipelines.setLevel("tiltshift", 0)

-- a free-roam game: Zoom.gateOK wants the top screen to BE the overworld,
-- not transitioning and not running a script
local keyGame
local overworld = { transitioning = false }
keyGame = {
  overworld = overworld,
  stack = { top = function() return overworld end },
  save = { options = { modOptions = {} } },
  mods = { modOptions = {} },
  writeOptions = function() end,
}

local VoxelGrid = run.loader.exports.DRAMATIC_SHAPE.lib.require("VoxelGrid")
local Curve = run.loader.exports.DRAMATIC_SHAPE.lib.require("WorldCurve")

-- ------- 3 walks the ANGLE rungs and steps over FULL
--
-- The key is a display-mode cycler: it should change the camera and nothing
-- else. FULL reaches in and rewrites four other settings, so landing on it
-- mid-walk would silently turn the blur to maximum and flatten the horizon
-- with nothing on screen saying a keypress had done it.
Pipelines.setLevel("voxel", 0)
local walk = {}
for _ = 1, 6 do
  Game.keypressed(keyGame, "3")
  walk[#walk + 1] = Pipelines.levelLabel("voxel")
end
T.eq(table.concat(walk, ","), "15,35,50,75,OFF,15",
  "3 walks OFF -> 15 -> 35 -> 50 -> 75 and wraps, never touching FULL")

-- FULL is 35 degrees, so a press from it goes ON to 50 rather than back to
-- the rung that shows the same camera -- the key never appears to do nothing.
-- Matched by angle, so this follows FULL if it is ever retuned.
T.eq(VoxelState.ANGLES_DEG[VoxelState.FULL_LEVEL + 1], 35,
  "FULL is the 35-degree camera")
Pipelines.setLevel("voxel", VoxelState.FULL_LEVEL)
Game.keypressed(keyGame, "3")
T.eq(Pipelines.levelLabel("voxel"), "50",
  "a press from FULL goes to 50, since FULL already IS the 35 camera")

Pipelines.setLevel("voxel", 0)
Game.keypressed(keyGame, "3")
T.eq(Pipelines.level("voxel"), 2, "3 cycles the voxel camera ladder")
Game.keypressed(keyGame, "3")
T.eq(Pipelines.level("voxel"), 3, "and keeps climbing it")

Game.keypressed(keyGame, "6")
T.eq(Pipelines.level("tiltshift"), 1, "6 cycles the tilt-shift blur")

Game.keypressed(keyGame, "5")
T.eq(VoxelGrid.setting:get(), true, "5 toggles V-GRID on")
Game.keypressed(keyGame, "5")
T.eq(VoxelGrid.setting:get(), false, "and off again")

local curveBefore = Curve.setting:get()
Game.keypressed(keyGame, "7")
T.neq(Curve.setting:get(), curveBefore, "7 cycles V-CURVE")

local Battles = run.loader.exports.DRAMATIC_SHAPE.lib.require("OverworldBattle")
T.eq(Battles.setting:get(), true, "3D-BTL starts on")
Game.keypressed(keyGame, "8")
T.eq(Battles.setting:get(), false, "8 toggles overworld battles off")
Game.keypressed(keyGame, "8")
T.eq(Battles.setting:get(), true, "and back on")

-- 3 also clears the two engine modes it displaced. Without this a player
-- who left TILT or GBC FX on before enabling the mod has no key left to
-- turn them off with, and both fight the diorama -- TILT is the flat fake
-- of what this mode does for real, GBC FX a present pass over the top.
local GBCFX = require("src.render.GBCFX")
Tilt.setLevel(2)
GBCFX.setLevel(3)
keyGame.save.options.tilt = 2
keyGame.save.options.gbcfx = 3

Game.keypressed(keyGame, "3")
T.eq(keyGame.save.options.tilt, 0, "3 turns TILT off in the save")
T.eq(Tilt.level, 0, "and on the live renderer")
T.eq(keyGame.save.options.gbcfx, 0, "3 turns GBC FX off in the save")
T.eq(GBCFX.level, 0, "and on the live renderer")

-- Every press, not just the one that switches the mode on. This is the
-- half the registry does NOT cover: its tilt exclusion fires when a world
-- pipeline takes the pass, so a press that switches voxel ON would clear
-- TILT with or without us. Park the ladder on its top rung and turn both
-- back on, so the single press under test is the one that wraps to OFF --
-- where nothing else is going to clear them.
-- 5 is the "75" rung, the last one the key walks before it wraps to OFF
Pipelines.setLevel("voxel", 5)
Tilt.setLevel(3)
GBCFX.setLevel(4)
keyGame.save.options.tilt = 3
keyGame.save.options.gbcfx = 4

Game.keypressed(keyGame, "3")
T.eq(Pipelines.level("voxel"), 0, "the press wraps the ladder back to OFF")
T.eq(keyGame.save.options.tilt, 0, "the press that wraps to OFF still clears TILT")
T.eq(Tilt.level, 0, "with the renderer agreeing")
T.eq(keyGame.save.options.gbcfx, 0, "and still clears GBC FX")
T.eq(GBCFX.level, 0, "with the renderer agreeing there too")

-- but 6 must not: T-SHIFT is a post-process that composes with TILT, and
-- the registry deliberately leaves it alone
Tilt.setLevel(2)
keyGame.save.options.tilt = 2
Game.keypressed(keyGame, "6")
T.eq(keyGame.save.options.tilt, 2, "6 leaves TILT alone -- the blur composes with it")
Tilt.setLevel(0)
keyGame.save.options.tilt = 0

-- the engine's own keys the mod did NOT claim must still reach it: 4 is
-- ZOOM, and taking it would be a bug rather than a feature
local zoomKeyReached = false
local realZoomGate = require("src.render.Zoom").gateOK
require("src.render.Zoom").gateOK = function() zoomKeyReached = true; return false end
Game.keypressed(keyGame, "4")
require("src.render.Zoom").gateOK = realZoomGate
T.check(zoomKeyReached, "a key this mod does not claim still reaches the engine")

-- A screen with its own key handler owns the keyboard: typing a nickname
-- must not cycle a render mode behind the text box.
local gridBefore = VoxelGrid.setting:get()
local voxelBefore = Pipelines.level("voxel")
local typed = {}
local menu = { onKeyPressed = function(_, k) typed[#typed + 1] = k end }
keyGame.stack.top = function() return menu end
for _, k in ipairs({ "3", "5", "6", "7" }) do Game.keypressed(keyGame, k) end
T.eq(#typed, 4, "every claimed key goes to a screen that handles keys itself")
T.eq(VoxelGrid.setting:get(), gridBefore, "V-GRID is untouched while a screen has focus")
T.eq(Pipelines.level("voxel"), voxelBefore, "and so is the voxel ladder")

-- and the free-roam gate the engine applies to its own display keys applies
-- to the settings too: no flipping the wireframe mid-cutscene
keyGame.stack.top = function() return overworld end
overworld.transitioning = true
local midWarp = VoxelGrid.setting:get()
Game.keypressed(keyGame, "5")
T.eq(VoxelGrid.setting:get(), midWarp, "V-GRID refuses mid-transition, as the mode does")
overworld.transitioning = false

-- ------- the sky at the top rung
--
-- At 75 degrees the camera is pitched far enough over that the horizon is
-- in frame, so the void behind the diorama becomes a sky rather than the
-- black plate it reads as at every rung below. Outdoors only: a house or a
-- cave is a room with a ceiling, and the void past its walls is the
-- outside of a box, not open air.

local Voxel = run.loader.exports.DRAMATIC_SHAPE.lib.require("VoxelState")
local skyFor = VoxelScene._skyFor
local skyStrength = VoxelScene._skyStrength
T.check(type(skyFor) == "function", "the scene exposes its sky resolve")

-- pinned to DAY for every sky assertion below: the row ships defaulting to
-- SYNC -- the machine's own clock -- which would hand these tests whatever
-- palette the hour of the test run happened to be
run.loader.exports.DRAMATIC_SHAPE.lib.require("DayNight").setting:sync("day")

local outside = { def = { id = "PALLET_TOWN", tileset = "OVERWORLD" } }
local inside = { def = { id = "REDS_HOUSE_1F", tileset = "HOUSE" } }
local TOP = math.rad(Voxel.ANGLES_DEG[Voxel.MAX_LEVEL + 1])

-- the ladder, by angle: every rung that tilts at all paints a sky
for level = 0, Voxel.MAX_LEVEL do
  Voxel.angle = math.rad(Voxel.ANGLES_DEG[level + 1])
  local sky = skyFor(outside)
  if level == 0 then
    T.eq(sky, nil, "rung 0 is the flat camera: no tilt, no void, no sky")
  else
    T.check(sky ~= nil, "rung " .. level .. " paints a sky outdoors")
    T.eq(sky[4], 1, "and paints it at full strength")
    T.check(sky.bands ~= nil, "with its bands on it")
  end
end

-- indoors, never -- at any rung, including the top one
for level = 0, Voxel.MAX_LEVEL do
  Voxel.angle = math.rad(Voxel.ANGLES_DEG[level + 1])
  T.eq(skyFor(inside), nil, "an interior has no sky at rung " .. level)
end
Voxel.angle = TOP
T.eq(skyFor(inside), nil, "not even at 75 degrees, where outdoors would")

-- a map record with nothing to ask is not a crash
T.eq(skyFor(nil), nil, "no map, no sky")
T.eq(skyFor({}), nil, "a map with no def is not an outdoor map")

-- full strength at every rung, with the ramp left only for the ARRIVAL: the
-- camera eases up from flat when the mode is switched on, and the sky comes up
-- with it rather than appearing whole on the keypress
T.eq(skyStrength(math.rad(15)), 1, "the shallowest rung is full sky")
T.eq(skyStrength(math.rad(50)), 1, "so is the one below the top")
T.eq(skyStrength(TOP), 1, "and the top rung")
T.eq(skyStrength(0), 0, "a camera that has not tilted at all paints none")
local rising = skyStrength(math.rad(4))
T.check(rising > 0 and rising < 1,
  "and the first few degrees off flat are the fade-in")
T.check(skyStrength(math.rad(6)) > skyStrength(math.rad(3)),
  "which strengthens as the camera lifts")

-- the colour answers to the display mode, exactly as the terrain does: a
-- hardcoded blue would sit wrong in the modes that are not colour modes
Voxel.angle = TOP
local function skyRGB(mode)
  local prev = PaletteFX.mode
  PaletteFX.mode = mode
  local c = skyFor(outside)
  PaletteFX.mode = prev
  return c
end

local blue = skyRGB("gbc")
T.check(blue[3] > blue[1], "in a colour mode the sky is blue -- more blue than red")

local grey = skyRGB("og")
T.check(math.abs(grey[1] - grey[2]) < 1e-6 and math.abs(grey[2] - grey[3]) < 1e-6,
  "GRAY paints a grey sky, not a blue one")

local green = skyRGB("classic")
T.check(green[2] > green[1] and green[2] > green[3],
  "CLASSIC paints a green sky, matching its green world")

T.check(skyRGB("gbc_inv")[3] ~= blue[3],
  "GBC INV does not paint the same sky as GBC")

-- ------- and the sky is a banded gradient, with no picture behind it
--
-- One flat blue was enough while the void was a sliver; with the horizon a
-- quarter of the way down the frame it is a wall of paint. So the sky is the
-- 8-bit skybox recipe: a short palette of blues painted as flat bands, deepest
-- overhead, with a checkerboard of the next band dithered into the bottom of
-- each. Nothing is baked to a fixed size and upscaled -- the bands fill the
-- window and the dither grid is cut to the diorama's own pixel scale.
do
local Sky = run.loader.exports.DRAMATIC_SHAPE.lib.require("Sky")
local Voxel3D = run.loader.exports.DRAMATIC_SHAPE.lib.require("Voxel3D")
local DayNight = run.loader.exports.DRAMATIC_SHAPE.lib.require("DayNight")

local function luma(c) return 0.299 * c[1] + 0.587 * c[2] + 0.114 * c[3] end

-- the palette is the band list, and it belongs to the CLOCK now: DayNight
-- owns one per phase and blends between them. The row defaults to DAY, so
-- what the sky paints here is the day palette -- still every inch a GBC one.
local dayPal = DayNight.PALETTES.day
for i, c in ipairs(dayPal) do
  T.check(c[1] % 8 == 0 and c[2] % 8 == 0 and c[3] % 8 == 0,
    "palette entry " .. i .. " is a colour a Game Boy Color could show -- five "
    .. "bits a channel, so every one is a multiple of 8")
  T.check(c[3] > c[1], "and it is blue: more blue than red")
end
T.eq(#dayPal, 6, "six of them: twilight needs the rungs, and day matches")

Voxel.angle = TOP
local skyGrad = skyRGB("gbc")
T.eq(#(skyGrad.bands or {}), #dayPal,
  "the sky arrives with one band per palette entry")

for i, band in ipairs(skyGrad.bands) do
  if i > 1 then
    T.check(luma(band) > luma(skyGrad.bands[i - 1]),
      "band " .. i .. " is lighter than the one above it: the sky pales toward "
      .. "the horizon")
  end
end
-- read backwards out of the palette, which is stored in shade order (lightest
-- first) so a display mode's own four colours drop straight in
local deepest = dayPal[#dayPal]
T.check(math.abs(skyGrad.bands[1][1] - deepest[1] / 255) < 1e-9,
  "the top band is the palette's deep rung, unmixed")

-- the fill a caller clears to IS the palest band, so the haze below the horizon
-- and the bottom of the sky are one colour and the horizon has no seam
local palest = skyGrad.bands[#skyGrad.bands]
T.check(math.abs(skyGrad[1] - palest[1]) < 1e-9
        and math.abs(skyGrad[2] - palest[2]) < 1e-9
        and math.abs(skyGrad[3] - palest[3]) < 1e-9,
  "the flat fill is the palest band, so the horizon line has no seam of its own")
T.eq(skyGrad[4], 1, "and the tween strength still rides on the descriptor")

-- the gradient belongs to the VOXEL 75 rung and the walking camera on it. The
-- arena shot asks for the sky by the flat route (VoxelScene.skyColor) and gets
-- exactly the sky it always had -- its placed camera's horizon is above the
-- frame, so there would be no gradient to see from down there anyway.
local flat = VoxelScene.skyColor(outside, 1)
T.eq(flat.bands, nil, "a battle's arena sky is the flat fill, not the gradient")
T.check(math.abs(flat[1] - palest[1]) < 1e-9
        and math.abs(flat[3] - palest[3]) < 1e-9,
  "and it is the hour's haze, so a staged fight stands under the same sky "
  .. "free-roam does -- navy at midnight, gold at dusk")

-- the same call, the same numbers, and the same TABLE: the bands are memoised
-- per display mode, so a frame that paints the sky allocates nothing to do it
local again = Sky.bands()
T.eq(Sky.bands(), again, "the bands are computed once and held, not rebuilt")

local greyBands = skyRGB("og").bands
for i, band in ipairs(greyBands) do
  T.check(math.abs(band[1] - band[2]) < 1e-9
          and math.abs(band[2] - band[3]) < 1e-9,
    "GRAY gets four greys, not four blues (band " .. i .. ")")
end
T.check(luma(greyBands[#greyBands]) > luma(greyBands[1]),
  "and they still climb toward the horizon")

-- ------- where the bands go is the camera's own answer
--
-- The pale end has to meet the horizon at any pitch, fov or window shape, so it
-- is placed on the ground plane's vanishing line -- which is what projecting a
-- direction ALONG the ground through the scene matrix gives. Checked against the
-- limit of projecting real ground points further and further away, so a retuned
-- camera either still agrees with this or says so.
local function groundY(h, dist)
  local m = Voxel3D.vp
  local y = m[5] * 0 + m[7] * -dist + m[8]
  local w = m[13] * 0 + m[15] * -dist + m[16]
  return (y / w * 0.5 + 0.5) * h
end

Voxel.angle = TOP
local vh = 288
Voxel3D.vp = Voxel3D.viewProjection(0, 0, 320, vh)
local horizon = Voxel3D.horizonY(vh)
T.check(horizon and horizon > 0 and horizon < vh,
  "at the top rung the horizon is inside the frame, which is why there is a sky")
T.check(math.abs(groundY(vh, 200000) - horizon) < 0.5,
  ("ground at infinity converges on it: %.2f vs %.2f")
  :format(groundY(vh, 200000), horizon))
T.check(groundY(vh, 200) > groundY(vh, 2000)
        and groundY(vh, 2000) > horizon,
  "and nearer ground is always below it, never above")
T.check(horizon < vh / 2,
  "the horizon sits in the upper half: the sky is a band across the top, not "
  .. "half the picture")

-- the fraction is a property of the camera, not of the canvas
Voxel3D.vp = Voxel3D.viewProjection(0, 0, 320, vh)
local tall = Voxel3D.horizonY(vh * 3)
T.check(math.abs(tall / (vh * 3) - horizon / vh) < 1e-9,
  "a taller canvas puts it at the same fraction, so the bands scale with it")

Voxel.angle = 0
Voxel3D.vp = Voxel3D.viewProjection(0, 0, 320, vh)
T.eq(Voxel3D.horizonY(vh), nil,
  "a camera looking straight down has no horizon to find, and paints no bands")

-- ------- where the sky's bottom edge goes at each rung
--
-- The camera's own horizon when that is in frame -- which is the top rung -- and
-- otherwise a fixed slice of the frame, because at the steeper rungs the void
-- that shows is where the ground runs OUT rather than what is above the horizon.
-- One sky across the whole ladder either way.
T.check(math.abs(Sky.region(288, 66.83) - 66.83) < 1e-9,
  "a horizon in frame is where the sky ends")
T.eq(Sky.region(288, -930), 288 * Sky.SPAN,
  "a horizon above the frame falls back to a fixed slice of it")
T.eq(Sky.region(288, nil), 288 * Sky.SPAN, "and so does no horizon at all")
T.eq(Sky.region(288, 4000), 288, "a horizon below the frame fills it")
T.eq(Sky.region(0, 40), nil, "and a canvas with no height paints nothing")
T.check(Sky.SPAN > 0.1 and Sky.SPAN < 0.5,
  "the fallback slice is a band across the top, not half the picture")

-- ------- the pass, as it is actually issued
--
-- One rectangle through one shader: no baked picture of a sky, nothing being
-- resampled -- which is the whole reason it is drawn this way rather than
-- generated once and scaled. Every pixel answers from its own canvas coordinate,
-- so it is computed at the size it is shown at.
--
-- The one texture bound is the band RAMP, and it is a palette rather than a
-- picture: one texel per band, sampled nearest. It used to be a uniform array,
-- and that is the bug this shape exists to have fixed -- on Android the array's
-- later slots arrived as zero and painted the bottom of the sky black, while the
-- identical colour delivered by love.graphics.clear (the haze under the horizon)
-- landed correctly. So the assertions below pin the ramp, not an array.
--
-- And the depth mode is put back to what it was, which is the piece that would
-- break the frame: a rectangle drawn under the pass's own ("lequal", true) stamps
-- itself across the depth buffer at the near plane and hides the whole world
-- behind the sky.
local realGraphics, realImage = love.graphics, love.image
local rects, depthCalls, sent, shaderUses = {}, {}, {}, 0
local fakeShader = {
  send = function(_, name, a, b, c, d)
    sent[name] = { a, b, c, d }
  end,
}
-- enough of an image to be built and measured; the ramp only ever has pixels
-- written into it and its dimensions read back
local function fakeImage(w, h)
  return {
    pixels = {},
    getWidth = function(self) return w end,
    getHeight = function(self) return h end,
    getDimensions = function(self) return w, h end,
    setPixel = function(self, x, _, r, g, b, a)
      self.pixels[x] = { r, g, b, a }
    end,
    setFilter = function() end,
    setWrap = function() end,
  }
end
love.image = { newImageData = function(w, h) return fakeImage(w, h) end }
love.graphics = {
  getShader = function() return nil end,
  setShader = function(sh) if sh then shaderUses = shaderUses + 1 end end,
  getDepthMode = function() return "lequal", true end,
  setDepthMode = function(cmp, write)
    depthCalls[#depthCalls + 1] = tostring(cmp) .. "/" .. tostring(write)
  end,
  setColor = function() end,
  newShader = function() return fakeShader end,
  newImage = function(data) return data end,
  rectangle = function(_, x, y, w, h)
    rects[#rects + 1] = { x = x, y = y, w = w, h = h }
  end,
}
Sky.invalidate()   -- so the ramp is built through the fakes above, not held

-- 320x288 canvas, horizon at 66.83, diorama pixels 7 canvas pixels square
local painted = Sky.paint(320, 288, skyGrad, 66.83, 7)
local ramp = Sky._rampFor(skyGrad.bands)
love.graphics, love.image = realGraphics, realImage

T.eq(painted, true, "the sky paints")
T.eq(shaderUses, 1, "through one shader")
T.eq(#rects, 1, "over one rectangle -- not one per band, and not one per cell")
T.eq(rects[1].x, 0, "from the left edge")
T.eq(rects[1].w, 320, "across the full width of the frame")
T.eq(rects[1].y, 0, "and from the top edge")
T.eq(rects[1].h, 67, "down to the horizon")

T.eq(sent.count[1], #skyGrad.bands, "the band count goes to the shader")
T.check(math.abs(sent.edge[1] - 66.83) < 1e-9, "with the sky's bottom edge")
T.eq(sent.cell[1], 7,
  "and the diorama's pixel size, which is what puts the bands and the dither "
  .. "cells on the world's own grid")
T.eq(sent.start[1], Sky.DITHER_START, "and where in a band the checker begins")
T.eq(sent.alpha[1], 1, "and the tween strength")
-- The palette goes as ONE ramp texture, not as eight uniform vectors. The width
-- is the contract the shader divides by: it samples texel (i + 0.5) / count, so
-- a ramp of any other width reads between two bands or off the end -- and off
-- the end is exactly the black the Android bug painted.
T.eq(sent.ramp[1], ramp, "the palette goes to the shader as its ramp texture")
T.eq(ramp:getWidth(), #skyGrad.bands, "one texel per band, and no spare slots")
T.eq(ramp:getHeight(), 1, "on a single row -- it is a palette, not a picture")
T.eq(Sky._rampFor(skyGrad.bands), ramp,
  "and it is built once and held, not rebuilt per frame")
-- every texel is a real colour: the failure being fixed here is a slot that
-- was never written reading back as zero, which is black
for i = 1, #skyGrad.bands do
  local texel = ramp.pixels[i - 1]
  T.check(texel ~= nil, "band " .. i .. " was written into the ramp")
  T.check(texel[1] == skyGrad.bands[i][1] and texel[2] == skyGrad.bands[i][2]
          and texel[3] == skyGrad.bands[i][3],
    "and it is that band's own colour, in the order the sky reads them")
end

T.eq(depthCalls[1], "always/false", "the sky is drawn with depth writes OFF")
T.eq(depthCalls[#depthCalls], "lequal/true",
  "and the pass's own depth mode is handed straight back")

-- ------- and it follows the zoom, in the frame the zoom changed
--
-- The cell size is handed in every frame rather than cached, so a ZOOM keypress
-- -- which is what changes the diorama's pixels-per-world-pixel -- lands in the
-- next frame with nothing to rebuild and nothing left over at the old scale.
local zoomed = {}
love.graphics = {
  getShader = function() return nil end, setShader = function() end,
  getDepthMode = function() return "lequal", true end,
  setDepthMode = function() end,
  setColor = function() end,
  newShader = function() return fakeShader end,
  rectangle = function(_, _, _, w, h) zoomed.rect = { w = w, h = h } end,
}
sent = {}
Sky.paint(1920, 1080, skyGrad, 250.6, 12)
love.graphics = realGraphics
T.eq(zoomed.rect.w, 1920, "a bigger window is filled to its own width")
T.eq(zoomed.rect.h, 251, "and its own horizon")
T.eq(sent.cell[1], 12, "with the cell size that came in with it, not a cached one")

T.eq(Sky.paint(320, 288, { 0, 0, 1, 1 }, 40, 7), false,
  "a descriptor with no bands on it is the old flat sky, untouched")
T.eq(Sky.paint(320, 0, skyGrad, 40, 7), false,
  "and a frame with no height paints nothing at all")
end

Voxel.angle = 0

-- ------- overworld battles: where the fight is staged
--
-- The arena search is pure map arithmetic, so it is driven here against
-- hand-drawn maps rather than a fixture: the shape it looks for, the order
-- it relaxes in, and what it refuses are all things a picture can state
-- exactly.
--
-- The stub answers the small surface BattleArena asks a Map for. `rows` are
-- strings, one per cell row, "." open and anything else solid; "w" is water
-- (open to a surfer only) and "d" a warp tile.

local BattleArena = run.loader.exports.DRAMATIC_SHAPE.lib.require("BattleArena")

local function stubMap(rows)
  local at = function(cx, cy)
    local row = rows[cy + 1]
    return row and row:sub(cx + 1, cx + 1) or "#"
  end
  return {
    widthCells = #rows[1],
    heightCells = #rows,
    inBounds = function(_, cx, cy)
      return cx >= 0 and cy >= 0 and cx < #rows[1] and cy < #rows
    end,
    warpAtCell = function() return nil end,
    isWarpTileCell = function(_, cx, cy) return at(cx, cy) == "d" end,
    isWalkableCell = function(_, cx, cy) return at(cx, cy) == "." end,
    isWaterCell = function(_, cx, cy) return at(cx, cy) == "w" end,
    isGrassCell = function(_, cx, cy) return at(cx, cy) == "g" end,
  }
end

-- a field with room for the wide arena on its right-hand side only
local field = stubMap({
  "##########",
  "#....#####",
  "#....#####",
  "#....#####",
  "#....#####",
  "#....#####",
  "#....#####",
  "##########",
})

local arena = BattleArena.find(field, 2, 3, false)
T.check(arena ~= nil, "a field with a 3x6 clearing has an arena")
T.eq(arena.shape, "wide", "and it is the wide shape, not the fallback")
T.eq(arena.w, 3, "the wide arena is three cells across")
T.eq(arena.h, 6, "and six deep")

-- the two mons stand three cells apart down the middle column, which is
-- what the picture in BattleArena says and what the camera is built around
T.eq(arena.enemyCell[1], arena.playerCell[1],
  "both mons stand in the arena's middle column")
T.eq(arena.playerCell[2] - arena.enemyCell[2], 3,
  "with three cells of ground between them")
T.check(arena.enemyCell[2] < arena.playerCell[2],
  "the enemy is the NORTH one -- the far end from a camera parked south")

-- every cell of the shape is open, apron included: that one-cell margin is
-- the difference between a staged shot and a fight in a doorway
for cy = arena.y, arena.y + arena.h - 1 do
  for cx = arena.x, arena.x + arena.w - 1 do
    T.check(field:isWalkableCell(cx, cy),
      ("arena cell (%d,%d) is open ground"):format(cx, cy))
  end
end

-- world-pixel centres, which is the unit everything downstream works in
T.eq(arena.player[1], arena.playerCell[1] * 16 + 8,
  "the player's mark is the centre of its cell in world pixels")
T.eq(arena.mid[2], (arena.enemy[2] + arena.player[2]) / 2,
  "and the midpoint is halfway between the two")

-- nearest, not first found: two clearings, and the one under the player wins.
-- Wide enough that the battle camera -- which stands a few cells east and
-- south of whatever it is aimed at -- is over real ground for BOTH of them,
-- so this measures proximity rather than the clearance preference below.
local twin = stubMap({
  "########################",
  "#.##########.###########",
  "#.##########.###########",
  "#.##########.###########",
  "#.##########.###########",
  "########################",
  "########################",
  "########################",
  "########################",
  "########################",
})
local near = BattleArena.find(twin, 12, 3, false)
T.eq(near.shape, "narrow", "no 3x6 anywhere, so the search relaxes")
T.eq(near.x, 12, "and takes the corridor the player is standing in")
T.eq(BattleArena.find(twin, 1, 3, false).x, 1,
  "the same map from the other side picks the other one")

-- the wide shape wins even when a narrow one is closer: it is the shot this
-- mode is framed for, so proximity does not get to overrule it
local both = stubMap({
  "#.#########",
  "#.####...##",
  "#.####...##",
  "#.####...##",
  "######...##",
  "######...##",
  "######...##",
})
T.eq(BattleArena.find(both, 1, 1, false).shape, "wide",
  "a wide arena across the map beats a narrow one underfoot")

-- water is ground for a surfer and nothing at all for anyone else
local sea = stubMap({
  "wwwwww",
  "wwwwww",
  "wwwwww",
  "wwwwww",
  "wwwwww",
  "wwwwww",
})
T.eq(BattleArena.find(sea, 2, 2, false), nil,
  "open water is not open ground to someone walking")
T.check(BattleArena.find(sea, 2, 2, true) ~= nil,
  "but it is to a surfer, who is standing on it")

-- tall grass is walkable and is still not a stage: it is knee-high geometry
-- standing between a nearly-level camera and the mon behind it
local meadow = stubMap({
  "########",
  "#ggg..g#",
  "#ggg..g#",
  "#ggg..g#",
  "#ggg..g#",
  "#ggg..g#",
  "#ggg..g#",
  "########",
})
local mown = BattleArena.find(meadow, 2, 3, false)
T.check(mown ~= nil, "a meadow with a bare strip still has an arena")
for cy = mown.y, mown.y + mown.h - 1 do
  for cx = mown.x, mown.x + mown.w - 1 do
    T.check(not meadow:isGrassCell(cx, cy),
      ("no cell of the arena is tall grass (%d,%d)"):format(cx, cy))
  end
end
T.eq(BattleArena.find(stubMap({
  "#####", "#ggg#", "#ggg#", "#ggg#", "#ggg#", "#ggg#", "#ggg#", "#####",
}), 2, 3, false), nil,
  "a map that is nothing but grass has nowhere to stand a fight")

-- a doormat is walkable and is still not a stage
local hall = stubMap({
  "######",
  "#..d.#",
  "#....#",
  "#....#",
  "#....#",
  "######",
})
local halled = BattleArena.find(hall, 2, 3, false)
T.check(halled == nil or halled.shape == "narrow",
  "a warp tile is excluded, so the room's only 3x6 does not qualify")

T.eq(BattleArena.find(stubMap({ "###", "###" }), 1, 1, false), nil,
  "a map with no room at all yields no arena, and the battle draws plainly")

-- an authored refusal is honoured over the search: a map looked at and found
-- to have nowhere a fight reads has to be able to say so, or the fallback
-- goes and finds one of the spots that were already rejected by eye
local roomy = stubMap({
  "#####", "#...#", "#...#", "#...#", "#...#", "#...#", "#...#", "#####",
})
roomy.id = "TEST_REFUSED"
T.check(BattleArena.find(roomy, 2, 3, false) ~= nil,
  "a roomy map finds an arena by search when nothing is authored")
BattleArena.setOverride("TEST_REFUSED", false)
T.eq(BattleArena.find(roomy, 2, 3, false), nil,
  "an authored false refuses the map outright, search and all")
BattleArena.setOverride("TEST_REFUSED", nil)
T.check(BattleArena.find(roomy, 2, 3, false) ~= nil,
  "and dropping the refusal restores the search")

-- ------- overworld battles: the over-the-shoulder framing
--
-- The claim the whole shot rests on. The two pics are PINNED to their cells,
-- so the rig has to put those two patches of ground exactly where the GB's
-- own battle screen puts its two pics -- the player's low and left at
-- (40, 96), the enemy's high and right at (124, 56). Reprojected through the
-- real camera rather than asserted about the constants, so the day someone
-- retunes the rig this either still lands or says so.

local BattleCam = run.loader.exports.DRAMATIC_SHAPE.lib.require("BattleCam")
local BattleScene = run.loader.exports.DRAMATIC_SHAPE.lib.require("BattleScene")
local Voxel3Dcam = run.loader.exports.DRAMATIC_SHAPE.lib.require("Voxel3D")

-- where a world point lands in the 160x144 frame, or nil behind the camera
local function project(cam, point, w, h, fov)
  local saved = cam.fov
  if fov then cam.fov = fov end
  Voxel3Dcam.camera = cam
  local m = Voxel3Dcam.viewProjection(0, 0, w or 160, h or 144)
  Voxel3Dcam.camera = nil
  cam.fov = saved
  local x = m[1] * point[1] + m[2] * 0 + m[3] * point[2] + m[4]
  local y = m[5] * point[1] + m[6] * 0 + m[7] * point[2] + m[8]
  local cw = m[13] * point[1] + m[14] * 0 + m[15] * point[2] + m[16]
  if cw <= 1e-6 then return nil end
  return (x / cw * 0.5 + 0.5) * (w or 160), (y / cw * 0.5 + 0.5) * (h or 144)
end

BattleCam.reset()
local shot = BattleArena.find(field, 2, 3, false)
local rig, pitch = BattleCam.rig(shot, 0)

local px, py = project(rig, shot.player)
local ex, ey = project(rig, shot.enemy)
T.check(px ~= nil and ex ~= nil, "both marks are in front of the camera")
T.check(math.abs(px - 26) < 1 and math.abs(py - 96) < 1,
  ("the player's cell projects onto its pic's feet at (26, 96): got "
   .. "(%.2f, %.2f)"):format(px, py))
T.check(math.abs(ex - 124) < 1 and math.abs(ey - 56) < 1,
  ("the enemy's cell projects onto its pic's feet at (124, 56): got "
   .. "(%.2f, %.2f)"):format(ex, ey))
T.check(px < ex, "which puts the player's mon LEFT of the enemy's")
T.check(py > ey, "and lower in the frame -- nearer the camera")

-- low and long: the eye is near the floor looking almost along it, which is
-- what a 56-pixel sprite standing on a 16-pixel tile costs
T.check(pitch > math.rad(60) and pitch < math.rad(85),
  "the rig watches the arena from near ground level")

-- ------- a mon covers its own square
--
-- The pics are drawn at INTEGER scales -- 56 pixels for a front pic at 1x, 64
-- for a back pic at 2x -- so the only way a mon can stand in one overworld
-- square is for the camera to make that square that big. This is the pair of
-- equations the default rig was solved against alongside the two anchors, and
-- it is the one that sets how far away the camera has to be.
local function span(cam, point)
  local a = project(cam, { point[1] - 8, point[2] })
  local b = project(cam, { point[1] + 8, point[2] })
  return math.abs(b - a)
end

T.check(math.abs(span(rig, shot.player) - 64) < 4,
  ("the player's square is a back pic wide (64px at 2x): got %.2f")
  :format(span(rig, shot.player)))
T.check(math.abs(span(rig, shot.enemy) - 56) < 4,
  ("the enemy's square is a front pic wide (56px at 1x): got %.2f")
  :format(span(rig, shot.enemy)))

-- ------- the close rig, for rooms the default cannot stand back from
--
-- Five blocks is further than a gym is wide, so on one the default eye lands
-- outside the map and the border ring crosses the near mon. An arena asks for
-- the short rig by name, and the two things that have to hold are that it
-- really is close enough to sit in a room, and that it frames the SAME shot
-- -- both marks still on their anchors -- so swapping rigs changes the lens
-- and nothing about the composition.
local function eyeDistance(cam)
  local dx = cam.eye[1] - cam.focus[1]
  local dy = cam.eye[2] - cam.focus[2]
  local dz = cam.eye[3] - cam.focus[3]
  return math.sqrt(dx * dx + dy * dy + dz * dz)
end

T.check(eyeDistance(rig) > 120,
  "the default long lens stands well back -- that is what sizes the mons")

BattleCam.reset()
local snug = { mid = shot.mid, cam = "wide" }
local closeRig = BattleCam.rig(snug, 0)
local cd = eyeDistance(closeRig)
T.check(cd < 80,
  ("the wide lens is within five cells, so it fits inside a gym: got %.1f")
  :format(cd))
T.check(cd < eyeDistance(rig), "and is nearer than the default")

local cpx, cpy = project(closeRig, shot.player)
local cex, cey = project(closeRig, shot.enemy)
T.check(math.abs(cpx - 26) < 1 and math.abs(cpy - 96) < 1,
  ("the wide lens lands the player's mark on the same anchor: (%.2f, %.2f)")
  :format(cpx, cpy))
T.check(math.abs(cex - 124) < 1 and math.abs(cey - 56) < 1,
  ("and the enemy's too: (%.2f, %.2f)"):format(cex, cey))
T.check(span(closeRig, shot.player) < span(rig, shot.player),
  "the mons render smaller on it, which is what it trades for fitting")

-- an arena picks its rig by name, and anything unnamed gets the default
T.eq(BattleCam.rigFor({ cam = "wide" }), BattleCam.RIGS.wide,
  "an arena that asks for the wide lens gets it")
T.eq(BattleCam.rigFor({}), BattleCam.RIGS.tele, "and one that asks for nothing")
T.eq(BattleCam.rigFor({ cam = "nonsense" }), BattleCam.RIGS.tele,
  "as does one that asks for a rig that does not exist")

-- ------- the pins survive the window
--
-- The scene renders at the WINDOW's resolution, not the GB's, so the rig's
-- field of view is widened by the ratio the window bears to the letterbox.
-- What that has to buy is exactness: the letterbox sub-rectangle of the
-- widened render must be the framing the rig asked for, or the pics come
-- unpinned from the ground by however much it is out.

for _, win in ipairs({ { 1920, 1080, 7 }, { 640, 576, 4 }, { 1280, 1024, 7 },
                       { 800, 720, 5 } }) do
  local pw, ph, s = win[1], win[2], win[3]
  local lx = math.floor((pw - 160 * s) / 2)
  local ly = math.floor((ph - 144 * s) / 2)
  local wide = BattleScene.letterboxFov(rig.fov, ph, s)
  T.check(wide >= rig.fov - 1e-9,
    "a window taller than the letterbox needs a wider lens, never a tighter one")
  local wx, wy = project(rig, shot.player, pw, ph, wide)
  local gx, gy = (wx - lx) / s, (wy - ly) / s
  T.check(math.abs(gx - px) < 0.01 and math.abs(gy - py) < 0.01,
    ("%dx%d at scale %d reproduces the GB framing exactly: (%.3f, %.3f) vs "
     .. "(%.3f, %.3f)"):format(pw, ph, s, gx, gy, px, py))
end

-- ------- the drift
--
-- With the pics pinned, the drift is not decoration on a backdrop -- it
-- moves the mons themselves, and the whole reason it reads as depth is that
-- it moves the near one and the far one by DIFFERENT amounts. A backdrop
-- that merely slid would move them by the same one.
BattleCam.update(BattleCam.PAN_PERIOD / 4)
local rig2 = BattleCam.rig(shot, 0)
local px2 = project(rig2, shot.player)
local ex2 = project(rig2, shot.enemy)
T.check(math.abs(px2 - px) > 0.5, "the drift moves the near mark")
T.check((px2 - px) * (ex2 - ex) < 0,
  "and the far one the OTHER WAY -- parallax about a point between them")
T.check(math.abs(px2 - px) < 8 and math.abs(ex2 - ex) < 8,
  "neither is flung across the frame: the mons drift, they do not travel")

-- very slow: a quarter of the cycle is several seconds, and what it moves in
-- one FRAME has to be imperceptible
BattleCam.reset()
BattleCam.update(1 / 60)
local slow = BattleCam.rig(shot, 0)
local sx = project(slow, shot.player)
T.check(math.abs(sx - px) < 0.2,
  "one frame of drift moves a mon by a fifth of a pixel")

-- a placed camera declines the world curve outright: the bend exists to
-- drop the horizon away from a walking player, and here it would tip the
-- arena floor out from under the two mons pinned to it
T.eq(rig.curve, 0, "the battle camera switches the world curve off")

-- ------- the hit flash belongs to the mons, not the screen
--
-- The engine draws it as a full-screen white rectangle, which is a flash on
-- a white battle field and a whiteout of the map, the HUD and the text box
-- over a world. It is dropped on the way past and put back on the two cards.
local Battles = run.loader.exports.DRAMATIC_SHAPE.lib.require("OverworldBattle")
T.eq(Battles.flashing(nil), false, "no battle, no flash")
T.eq(Battles.flashing({ fx = {}, frame = 0 }), false,
  "a battle with no flash counter is not flashing")
T.eq(Battles.flashing({ fx = { flash = 0 }, frame = 0 }), false,
  "nor one whose counter has run out")
T.eq(Battles.flashing({ fx = { flash = 16 }, frame = 0 }), true,
  "a live counter flashes on the frames the engine would")
T.eq(Battles.flashing({ fx = { flash = 16 }, frame = 2 }), false,
  "and is dark on the others, which is what makes it flicker")
T.eq(Battles.flashing({ fx = { flash = 16 }, frame = 5 }), true,
  "on a four-frame cycle")

-- ------- the wireframe is forced on in a battle
--
-- A fight is a staged shot rather than the world being walked through, so it
-- always wears the seams. The player's own V-GRID row must not be touched by
-- that -- an override, not a write, or switching the mode off mid-battle
-- would quietly rewrite a setting they chose.
local Grid = run.loader.exports.DRAMATIC_SHAPE.lib.require("VoxelGrid")
Grid.override = nil
local rowWas = Grid.setting:get()
T.eq(Grid.enabled(), rowWas and true or false,
  "with no override the wireframe follows the row")
Grid.override = true
T.eq(Grid.enabled(), true, "an override forces it on")
T.eq(Grid.setting:get(), rowWas, "and leaves the player's row alone")
Grid.override = false
T.eq(Grid.enabled(), false, "an override can force it off too")
Grid.override = nil
T.eq(Grid.enabled(), rowWas and true or false,
  "and clearing it hands the answer back to the row")

-- ------- the depth of field is measured off the two marks
--
-- The slab held sharp is the one the mons are standing in, so the band has
-- to be derived from where they landed rather than from a constant -- and it
-- has to hold BOTH, which a band narrower than the gap between them would
-- not.
local BattleDOF = run.loader.exports.DRAMATIC_SHAPE.lib.require("BattleDOF")
local focusY, band, range = BattleDOF.bandFor(96, 56, 144)
T.check(math.abs(focusY - 76 / 144) < 1e-9,
  "the band centres between the two marks")
T.check(focusY - band < 56 / 144 and focusY + band > 96 / 144,
  "and is wide enough that both of them are inside it")
T.check(range > 0, "with a ramp out of it, so the band edge has no seam")
local wide = select(2, BattleDOF.bandFor(120, 30, 144))
T.check(wide > band, "marks further apart hold a deeper slab in focus")

-- ------- the HUDs are snapped to the window's own edges
--
-- The battle screen is 160x144 in the middle of the window and the world is the
-- whole of it, which left both HUD blocks huddled in the middle of the frame
-- with map on either side of them. Each is snapped to its own side instead: the
-- foe's to the left edge, the player's to the right. Measured in world-canvas
-- pixels, because that is the surface they are composited into -- the GB canvas
-- they are drawn in cannot reach past its own 160 columns.
do
local hudShot = { lx = 100, ly = 12, scale = 3, pw = 1000, ph = 500 }
local hudRects, bandX = Battles.snapRects(hudShot)
local hudRect = Battles.HUD_RECT

T.eq(hudRects.enemy[1], 0, "the foe's panel starts at the window's left edge")
T.eq(hudRects.player[1] + hudRects.player[3], hudShot.pw,
  "and the player's ends at the right one")
T.check(hudRects.enemy[1] < hudShot.lx,
  "so the foe's block has left the letterbox it used to sit in")
T.check(hudRects.player[1] > hudShot.lx + hudRect.player[1] * hudShot.scale,
  "and the player's has gone the other way")

-- the vertical is untouched: both blocks stay on the rows the GB put them on
T.eq(hudRects.enemy[2], hudShot.ly + hudRect.enemy[2] * hudShot.scale,
  "the foe's block keeps its own rows")
T.eq(hudRects.player[2], hudShot.ly + hudRect.player[2] * hudShot.scale,
  "and so does the player's")

-- and their size: a block is the same GB tiles at the same scale as the rest of
-- the art, moved and not stretched
T.eq(hudRects.enemy[3], hudRect.enemy[3] * hudShot.scale,
  "a block is its own width at the frame's scale")
T.eq(hudRects.player[4], hudRect.player[4] * hudShot.scale,
  "and its own height")

-- the band each block is cut out of is placed so the block lands on the rect
-- above; that is what the panel and the glyphs agreeing depends on
T.eq(bandX.enemy + hudRect.enemy[1] * hudShot.scale, hudRects.enemy[1],
  "the foe's band is offset so its block lands on its panel")
T.eq(bandX.player + hudRect.player[1] * hudShot.scale, hudRects.player[1],
  "and the player's likewise")

-- a window the shape of the GB screen has nowhere to snap TO, and the player's
-- block already ends at column 160, so it must not move at all
local snug = { lx = 0, ly = 0, scale = 4, pw = 160 * 4, ph = 144 * 4 }
local snugRects = Battles.snapRects(snug)
T.eq(snugRects.player[1], hudRect.player[1] * snug.scale,
  "on a GB-shaped window the player's block stays exactly where it was")
T.eq(snugRects.enemy[1], 0, "and the foe's is flush with a left edge it already met")

-- the bands together cover every row drawHUDs draws into (0-96: the two HUDs,
-- the pokeball rows and the safari ball count) and never overlap, so nothing it
-- draws is dropped or shown twice
local e, p = Battles.HUD_BAND.enemy, Battles.HUD_BAND.player
T.eq(e[2], 0, "the foe's band starts at the top of the frame")
T.eq(e[2] + e[4], p[2], "the player's picks up exactly where it ends")
T.check(p[2] + p[4] >= 96, "and together they reach the bottom of the HUD rows")
T.check(e[2] + e[4] <= hudRect.player[2],
  "the split falls between the two blocks, so neither is cut in half")
T.eq(e[1], 0, "the bands are full width")
T.eq(e[3], 160, "so a shaken HUD or a long name is carried out with its block")
end

-- ------- and the box at the bottom is on the same glass
--
-- The HUDs got frosted panels because black glyphs on grass are not readable.
-- The text box had the opposite problem and the same cause: an opaque white
-- slab over the bottom third of the diorama, which was the field's own colour
-- back when the field was white. The rects here are what the glass is cut to,
-- and they are a READ-ONLY mirror of drawTextArea's own branches -- so this is
-- where a future engine that moves a box says so.
do
local rects = Battles.textRects({ phase = "messages" })
T.check(rects.box ~= nil, "there is always a box: drawTextArea opens with one")
T.eq(rects.box[2] + rects.box[4], 144,
  "and it reaches the bottom of the frame")
T.eq(rects.box[3], 160, "full width, like Font.drawBox(0, 12, 20, 6)")
T.eq(rects.box[2], 96, "starting on the row the player's mon stands on")

-- the menu the player picks FIGHT on is that same box, so nothing is added
T.eq(Battles.textRects({ phase = "menu" }).moves, nil,
  "the battle menu draws inside the box already there")

-- the two phases that put a SECOND box above it get a second panel, trimmed
-- to the rows above the first: two panels over the same pixels would frost it
-- twice and leave a step along the seam
for _, phase in ipairs({ "moveSelect", "mimicSelect" }) do
  local more = Battles.textRects({ phase = phase })
  local extra = more.moves or more.mimic
  T.check(extra ~= nil, phase .. " raises a box of its own, and it is frosted")
  T.eq(extra[2] + extra[4], more.box[2],
    "which stops exactly where the box below it starts, so they never overlap")
  T.check(extra[1] >= 0 and extra[1] + extra[3] <= 160 and extra[2] >= 0,
    "and stays inside the frame the battle is drawn in")
end

-- AskName blanks the field on purpose -- the nickname prompt is meant to sit
-- on nothing -- so there is no box and no glass under one
T.eq(next(Battles.textRects({ phase = "menu", blankForAskName = true })), nil,
  "the nickname prompt's blank field gets no glass")
T.eq(next(Battles.textRects(nil)), nil, "and no battle, no boxes")
end

-- ------- BACK: the player's own mon stays on the menu
--
-- The staged shot stands both mons on the map, which costs the framing Gen 1
-- is most recognisable by: your own Pokemon seen from behind, sitting on the
-- battle menu. BACK SPRITES hands that back without giving up the fight on the map --
-- the foe is still geometry on its own tile.
do
T.eq(Battles.backSetting:get(), false,
  "BACK SPRITES is off by default: both mons out on the map is what the mode is")
T.eq(Battles.backPinned(), false, "so nothing is pinned to the menu")

local backGame = { save = { options = { modOptions = {} } },
                   mods = { modOptions = {} } }
Battles.setting:setIndex(1, backGame)              -- 3D-BTL on
Battles.backSetting:setIndex(2, backGame)          -- BACK SPRITES on
T.eq(Battles.backPinned(), true, "switched on, the back pic is pinned")
T.eq(backGame.save.options.modOptions.DRAMATIC_SHAPE.battleBack, true,
  "and it persists on its own key, beside 3D-BTL rather than over it")
T.eq(backGame.save.options.modOptions.DRAMATIC_SHAPE.battles, true,
  "which is still where it always was")

-- and it means nothing at all with staged battles off: there is no staged
-- shot for a back pic to be pinned in front of, and the engine's own battle
-- screen already draws exactly this
Battles.setting:setIndex(2, backGame)
T.eq(Battles.backPinned(), false,
  "with 3D-BTL off the setting decides nothing, whatever it is left at")
T.eq(Battles.backSetting:get(), true, "without being rewritten underneath")

-- ...so the row comes off the menu with it, on the same reasoning the mod's
-- other absent rows come off: a row that no longer decides anything is worse
-- than no row
local offRows = Runtime.call("ui.options.rows", function(_, r) return r end,
                             backGame, { { id = "tilt" } })
local offIds = {}
for _, row in ipairs(offRows) do offIds[row.id] = true end
T.check(offIds["DRAMATIC_SHAPE:battles"], "3D-BTL itself is still offered")
T.check(not offIds["DRAMATIC_SHAPE:battleBack"],
  "but BACK SPRITES is off the menu while there is no staged fight to be about")

Battles.setting:setIndex(1, backGame)
local onRows = Runtime.call("ui.options.rows", function(_, r) return r end,
                            backGame, { { id = "tilt" } })
local onAt = {}
for i, row in ipairs(onRows) do onAt[row.id] = i end
T.check(onAt["DRAMATIC_SHAPE:battleBack"], "switched back on, so is the row")
T.eq(onAt["DRAMATIC_SHAPE:battleBack"] - onAt["DRAMATIC_SHAPE:battles"], 1,
  "directly under the row it belongs to")

Battles.backSetting:setIndex(1, backGame)          -- and off for the rows below
end

-- ------- the hour reaches the FLAT world too
--
-- The clock reaches the diorama through the voxel shader's tint uniform, which
-- the 2D tile path never runs. With the mode off the same evening left the flat
-- world at permanent noon.
--
-- The fix is one multiplied rectangle, and the whole difficulty is WHERE. Not
-- on the world canvas -- in a colorized mode that is grayscale art the palette
-- shader classifies by RED CHANNEL, so tinting first would move every pixel
-- into the wrong shade bucket rather than darkening it. Not over the finished
-- frame either, or the dialog boxes darken with the world they are held up in
-- front of. Between the two, which is the one instant with no engine seam in
-- it -- worldPresent only runs when a pipeline drew the world, which in flat
-- mode is exactly what did not happen.
--
-- So the boundary is found by identity: `blit` passes the canvas it is
-- compositing as the first argument, so the first draw of the renderer's UI
-- canvas IS the moment the world is finished and the paper has not started.
-- That is what this drives -- the gates, and the ordering.
do
local DayTint = run.loader.exports.DRAMATIC_SHAPE.lib.require("DayTint")
local DayNight = run.loader.exports.DRAMATIC_SHAPE.lib.require("DayNight")

-- the map the hour is asked about is the one the player is standing on, read
-- off the live game rather than passed in -- so there has to be one
local Game = require("src.core.Game")
local owWas = Game.overworld
Game.overworld = { map = { id = "ROUTE_1", def = { tileset = "OVERWORLD" } } }

-- ------- the gates
--
-- A frame with a pipeline's world image in it was tinted inside that
-- pipeline's own shader; painting again would apply the hour twice.
DayNight.setting:sync("night")
T.check(DayTint.forFrame({ worldActive = true, worldOverride = {} }) == nil,
  "a frame a render pipeline drew is left alone -- it tinted itself")
T.check(DayTint.forFrame({ worldActive = false }) == nil,
  "and so is a frame with no world in it at all, like a menu over nothing")
T.check(DayTint.forFrame(nil) == nil, "and no renderer, no tint")

-- midday is a multiply by white, so it is skipped rather than drawn: a game
-- with the clock at DAY issues not one extra call
DayNight.setting:sync("day")
T.check(DayTint.forFrame({ worldActive = true }) == nil,
  "at midday the tint is white, so nothing is painted")

-- and a room has no sky to take its light from, which is the same answer
-- DayNight.tint gives on its own and the same one applyRig gives the sun
DayNight.setting:sync("night")
T.check(DayTint.forFrame({ worldActive = true }) ~= nil,
  "at night, outdoors, there is a tint to paint")
Game.overworld = { map = { id = "OAKS_LAB", def = { tileset = "HOUSE" } } }
T.check(DayTint.forFrame({ worldActive = true }) == nil,
  "but indoors the hour does not reach the floor")
Game.overworld = { map = { id = "ROUTE_1", def = { tileset = "OVERWORLD" } } }

-- ------- and the ordering, driven through the real wrap
--
-- A stand-in renderer whose endFrame issues the two draws the real one does,
-- in the real order: the world canvas, then the UI canvas.
DayNight.setting:sync("night")
local Renderer = require("src.render.Renderer")
local realEnd, realHook = Renderer.endFrame, Renderer.dramaticShapeTintHook
local log = {}
local uiCanvas, worldPixels = { "the UI canvas" }, { "the world canvas" }
Renderer.dramaticShapeTintHook = nil
Renderer.endFrame = function(self)
  log[#log + 1] = "world"
  love.graphics.draw(worldPixels, 0, 0)
  log[#log + 1] = "ui"
  love.graphics.draw(self.canvas, 0, 0)
  love.graphics.draw(self.canvas, 0, 0)   -- a second SGB zone's quad
end
DayTint.install()

local realRect = love.graphics.rectangle
love.graphics.rectangle = function(...)
  log[#log + 1] = "tint"
  return realRect(...)
end
Renderer.endFrame({ canvas = uiCanvas, worldActive = true, map = true })
love.graphics.rectangle = realRect

T.eq(table.concat(log, ","), "world,ui,tint",
  "the tint lands after the world is composited and before the UI blit draws")
local painted = 0
for _, step in ipairs(log) do if step == "tint" then painted = painted + 1 end end
T.eq(painted, 1,
  "once, not once per SGB zone quad the UI blit issues")

-- a frame the gates decline must not leave the shim installed on love.graphics
local drawWas = love.graphics.draw
Renderer.endFrame({ canvas = uiCanvas, worldActive = true, worldOverride = {} })
T.eq(love.graphics.draw, drawWas,
  "a declined frame does not leave a wrapper on love.graphics.draw")

Renderer.endFrame, Renderer.dramaticShapeTintHook = realEnd, realHook
Game.overworld = owWas
DayNight.setting:sync("sync")
end

-- ------- and a pinned back pic is not a stencil
--
-- Gen 1 battle pics are two-bit art whose lightest shade is WHITE, and the
-- decoded PNGs key that shade to alpha 0 -- free on a white field, a hole with
-- the world showing through over a route. BattlePics puts the paper back.
--
-- It does that by flooding the background INWARD and filling whatever the
-- background cannot reach. Started at the image border that finds nothing at
-- all -- a Gen 1 figure is an open drawing, and its belly walks out between
-- two legs and off the bottom of the frame -- so every mon was a stencil.
--
-- So the flood starts at the edges of the ARTWORK'S OWN BOX, and at three of
-- them: left, right and top. The bottom is closed, because it is not a side
-- the background is behind -- it is where the drawing was CUT. A pic is
-- bottom-aligned in its slot with the margin all at the top, so a mon's lowest
-- row is the last row it was given. Seed that cut and the background pours up
-- inside the figure, which was the channel of world showing through the middle
-- of a Clefairy.
--
-- Both halves are driven here, because getting one right at the other's
-- expense is exactly what went wrong twice: an earlier rule that filled
-- anything with ink to its left, right and above closed the channel and then
-- filled the notch between a Rattata's ears and the gap between its body and
-- its tail, which are background and have the drawing over them.
do
local BattlePics = run.loader.exports.DRAMATIC_SHAPE.lib.require("BattlePics")

-- Run one hand-drawn figure through the real BattlePics and hand back a
-- reader over what came out. The pic is faked at the readback seam, which is
-- the only thing between this and the pixels the engine would have blitted.
local lastCanvas = nil                  -- what the readback asked newCanvas for
local function fill(rows)
  local W, H = #rows[1], #rows
  local built = nil
  local function fakeData()
    local px = {}
    for y = 0, H - 1 do
      for x = 0, W - 1 do
        px[y * W + x] = rows[y + 1]:sub(x + 1, x + 1) == "#" and 1 or 0
      end
    end
    return {
      px = px,
      getDimensions = function() return W, H end,
      getPixel = function(self, x, y) return 0, 0, 0, self.px[y * W + x] end,
      setPixel = function(self, x, y, r, g, b, a) self.px[y * W + x] = a end,
    }
  end

  local realNewCanvas, realNewImage = love.graphics.newCanvas, love.graphics.newImage
  love.graphics.newCanvas = function(cw, ch, opts)
    lastCanvas = { w = cw, h = ch, opts = opts }
    return { setFilter = function() end, release = function() end,
             newImageData = fakeData }
  end
  love.graphics.newImage = function(data)
    built = data
    return { setFilter = function() end }
  end
  local pic = { getDimensions = function() return W, H end }
  local out = BattlePics.filled(pic)
  love.graphics.newCanvas, love.graphics.newImage = realNewCanvas, realNewImage
  -- deliberately NOT invalidated: each figure brings its own pic, and the
  -- cache check at the bottom needs one of them still in there
  return out, pic, built and function(x, y) return built.px[y * W + x] > 0.5 end
end

-- ------- the cut at the feet, which is what the closed bottom edge is for
local out, pic, opaque = fill({
  "..#..#..",   -- two ears, with sky between them
  "..#..#..",
  "..####..",   -- and the head closing under them
  ".#....#.",   -- belly: nothing under it but the edge the drawing stops at
  ".#....#.",
  ".#....#.",
  ".#.##.#.",   -- legs, with the gap between them running down to that edge
  ".#.##.#.",
})
T.check(out ~= pic and opaque, "the pic comes back rebuilt: there was paper to put back")

T.check(opaque(2, 3) and opaque(3, 4) and opaque(5, 5),
  "the belly is filled edge to edge -- no channel of world down the middle")
T.check(opaque(2, 7),
  "and so is the notch between its legs, which the same cut runs through")

-- the sky between two ears reaches the top of the box, so it is background
T.check(not opaque(3, 0) and not opaque(4, 1),
  "the sky between its ears stays sky")
-- and everything outside the artwork's own box is never touched, which is what
-- keeps the silhouette cutting cleanly instead of standing in a white rectangle
T.check(not opaque(0, 0) and not opaque(7, 0), "the corners stay transparent")
T.check(not opaque(0, 4) and not opaque(7, 4), "and the columns beside it")

-- ------- and a pocket that drains out to the SIDE is background, however
-- much of the drawing is over it
--
-- This is the regression the ray rule caused: ink to the left, ink to the
-- right, ink above, and still plainly the gap between a body and a tail.
-- Every transparent pixel in this one drains out through the notch at (2,3)
-- and away to the left, so NONE of it is paper -- and a pic with no paper to
-- put back is handed straight back, unrebuilt. That identity IS the assertion:
-- under the ray rule this figure came back rebuilt with the pocket filled in.
local gapOut, gapPic = fill({
  "..#####.",   -- a brow, with the drawing over the pocket
  "..#...#.",
  "..#...#.",
  "....###.",   -- which opens at the left, and drains out that way
  "..#####.",
  "..#####.",
})
T.eq(gapOut, gapPic,
  "a pocket the background can walk into from the side is not paper")

-- ------- and neither is a wide MOUTH along the bottom
--
-- Two things meet the underside of a figure. A DRAIN is where the drawing ran
-- out -- a belly leaking through the inch between a body and a leg -- and is
-- sealed. A MOUTH is the space between two legs, background that happens to be
-- enclosed on three sides, and is left open so the world shows through a
-- trainer's stride. Width tells them apart, and on this game's art the drains
-- run 3-4 pixels and the mouths 10-17, so BattlePics.DRAIN sits at 6.
--
-- This figure's stride is eight wide, so nothing in it is paper and it comes
-- back unrebuilt -- the identity again.
local strideOut, stridePic = fill({
  "..##############..",
  "..##############..",
  "..##############..",
  "..###........###..",   -- a stride eight wide, past the drain cut
  "..###........###..",
  "..###........###..",
})
T.eq(strideOut, stridePic,
  "the world shows through the gap between a trainer's legs")

-- the same figure with a two-pixel gap IS a drain, and fills
local drainOut, drainPic, drain = fill({
  "..##############..",
  "..##############..",
  "..##############..",
  "..######..######..",   -- a belly running out, not a stride
  "..######..######..",
  "..######..######..",
})
T.check(drainOut ~= drainPic and drain and drain(8, 4),
  "a narrow one is where the drawing ran out, and is paper")

-- ------- and the readback is measured in PIXELS, which is what kept the mons
-- the size of the squares they stand on
--
-- love.graphics.newCanvas takes the SURFACE's dpi scale when it is not told
-- otherwise, conf.lua turns highdpi on for Android and iOS, and Android's
-- density is routinely 2.75. So an untold newCanvas(56, 56) allocated a
-- 154x154 texture on a phone, the pic was magnified into it, and newImageData
-- read the magnified copy back at its own size -- an image 2.75x the artwork,
-- which drawPicsLayer then drew at 1:1 because it trusts getWidth(). The mon
-- stood on the map three times the size of its tile.
--
-- Only for a pic with paper to put back, which is why it read as a bug in
-- particular Pokemon (a giant Pidgey beside a normal mon) rather than as a
-- scale that was wrong everywhere.
T.check(lastCanvas and lastCanvas.opts and lastCanvas.opts.dpiscale == 1,
  "the readback canvas is one texel per pic pixel, on a highdpi phone too")
T.eq(lastCanvas.w, 18, "and it is the size of the pic, in those pixels")

-- the answer is cached on the image, so a pic costs one readback a session
-- rather than one a frame -- checked on the first figure, which is still in
-- there because fill() does not clear it
T.eq(BattlePics.filled(pic), out, "the rebuilt pic is cached on the original")
BattlePics.invalidate()
end

-- ------- the way out of a battle is a fade, not a cut
--
-- The engine wipes INTO a battle and cuts straight out of it. While voxel mode
-- is on that cut is between a placed camera looking across an arena and a
-- diorama looking down on a walking player, so the battle fades out, closes
-- behind the black, and the map fades up.
--
-- The pop ORDER is the part that has to be right: BattleState:finish pops
-- whatever is on top, which is the fade while it is up, so the fade has to be
-- off the stack before the battle finishes and back on it afterwards.
do
local Exit = run.loader.exports.DRAMATIC_SHAPE.lib.require("BattleExit")

T.eq(Data.transitions and Data.transitions[Exit.ID] and
     Data.transitions[Exit.ID].frames, Exit.FRAMES,
  "the fade's timing is a registered transitions record, retunable in data")

local function fakeStack(...)
  local s = { states = { ... } }
  function s:top() return self.states[#self.states] end
  function s:push(state) self.states[#self.states + 1] = state end
  function s:pop() return table.remove(self.states) end
  return s
end

-- headless has no depth buffer, so the real gate answers no on every rung;
-- pin it, which is what the seam is there for
local realModeOn = Exit.modeOn
Exit.modeOn = function() return true end

T.eq(Exit.wanted(nil), false, "no battle, no fade")
T.eq(Exit.wanted({ game = { stack = {} } }), true, "a battle in voxel mode fades")
T.eq(Exit.wanted({ game = { stack = {} }, payDay = 100, result = "win" }), false,
  "but not on an unpaid PAY DAY -- that finish() prints a message and comes "
  .. "back, so the fade belongs to the call that really leaves")
Exit.modeOn = function() return false end
T.eq(Exit.wanted({ game = { stack = {} } }), false,
  "and with voxel mode off the battle keeps the cut it always had")
Exit.modeOn = function() return true end

local exitOw = { isOverworld = true }
local exitGame = { data = Data, overworld = exitOw }
local exitBattle = { game = exitGame }
exitGame.stack = fakeStack(exitOw, exitBattle)

local finished = 0
local fade = Exit.start(exitBattle, function()
  finished = finished + 1
  exitGame.stack:pop()          -- what BattleState:finish does: pops itself
end)
T.eq(exitGame.stack:top(), fade, "the fade goes on top of the battle it closes")
T.eq(Exit.veil(), 0, "and starts on the battle's own last live frame")

for _ = 1, fade.frames - 1 do fade:update() end
T.check(Exit.veil() > 0.5, "the veil climbs while the battle is still up")
T.eq(exitGame.stack:top(), fade, "which is a frozen battle: the fade is on top")
T.eq(finished, 0, "and nothing has finished yet")

fade:update()                    -- the frame the cut lands on
T.eq(finished, 1, "at full black the battle finishes for real")
T.eq(Exit.veil(), 1, "with the screen fully black over the swap")
T.eq(#exitGame.stack.states, 2, "the battle left the stack")
T.eq(exitGame.stack.states[1], exitOw, "the map is under it")
T.eq(exitGame.stack:top(), fade,
  "and the fade went back on top of the map to bring it up")

for _ = 1, fade.frames - 1 do fade:update() end
T.check(Exit.veil() < 0.5, "the veil falls away over the map")
fade:update()
T.eq(Exit.veil(), nil, "and the fade is done -- no veil left on the screen")
T.eq(exitGame.stack:top(), exitOw, "with the map back on top, playable")
T.eq(finished, 1, "the battle finished exactly once")

-- ------- a blackout (or an evolution prompt) owns the way out itself
--
-- Those push their own transition on the way through onFinish, so this fade
-- stops at the cut rather than fading in over the top of somebody else's.
local other = { isSomeoneElse = true }
local blackout = { game = exitGame }
exitGame.stack = fakeStack(exitOw, blackout)
local warpFade = Exit.start(blackout, function()
  exitGame.stack:pop()                     -- the battle leaves
  exitGame.stack:push(other)               -- and a warp fade takes the screen
end)
for _ = 1, warpFade.frames do warpFade:update() end
T.eq(exitGame.stack:top(), other, "the state that took over is on top")
T.eq(Exit.veil(), nil, "and this fade let go of the screen at the cut")
T.eq(blackout.dramaticShapeLeaving, nil,
  "with the flag cleared, so a finish() that really leaves fades again")

-- ------- a stack cleared from under a fade cannot black the game out
--
-- A script (or the shot driver) pops down to the overworld without asking. The
-- fade is gone, so the veil has to go with it -- nothing is left to fade it in.
exitGame.stack = fakeStack(exitOw, exitBattle)
local orphan = Exit.start(exitBattle, function() end)
orphan:update()
T.check(Exit.veil() > 0, "a live fade veils the frame")
while exitGame.stack:top() ~= exitOw do exitGame.stack:pop() end
T.eq(Exit.veil(), nil, "and a fade popped from under itself veils nothing")

Exit.modeOn = realModeOn
end

-- ------- the day/night cycle
--
-- One twenty-minute clock, and everything is a pure function of it: the
-- pinned DAYTIME settings are fixed times on the dial, CYCLE lets it run,
-- and the sun, the moon, the shadows, the sky and the tint all read the same
-- number. What is checked here is the dial itself, the noon-exactness pledge
-- (DAY is the mod's existing sun, to the digit), the arcs' visibility (the
-- camera looks north, so the discs must actually cross the northern sky),
-- and the clock's ride through the save file.
do
local DayNight = run.loader.exports.DRAMATIC_SHAPE.lib.require("DayNight")
local ShadowMap = run.loader.exports.DRAMATIC_SHAPE.lib.require("ShadowMap")
local Voxel3D = run.loader.exports.DRAMATIC_SHAPE.lib.require("Voxel3D")
local Voxel = run.loader.exports.DRAMATIC_SHAPE.lib.require("VoxelState")

-- the dial and its pins
T.eq(DayNight.setting.values[1], "sync",
  "no value set means SYNC: values[1] is the row's contract default, and "
  .. "it follows the machine's clock")
DayNight.setting:sync("day")
T.eq(DayNight.time(), 300, "and DAY is noon on the dial")
local PINS = { day = 300, night = 900, dusk = 600, dawn = 0 }
for name, t in pairs(PINS) do
  DayNight.setting:sync(name)
  T.eq(DayNight.time(), t, name .. " pins the clock to " .. t)
end

-- CYCLE picks up from the pin the player was just looking at
DayNight.setting:sync("dusk")
DayNight.update(0)
DayNight.setting:sync("cycle")
DayNight.update(0)
T.eq(DayNight.clock, 600, "stepping onto CYCLE picks up from the pin: dusk")
DayNight.update(30)
T.check(math.abs(DayNight.time() - 630) < 1e-9, "and the clock then runs")
DayNight.clock = 1195
DayNight.update(10)
T.check(math.abs(DayNight.clock - 5) < 1e-9,
  "the dial wraps at twenty minutes, back into dawn")

-- the sun: noon is the mod's existing sun, exactly
local kx, kz, moon = DayNight.shearAt(300)
T.check(not moon, "noon is the sun's")
T.check(math.abs(kx - (-0.85)) < 1e-9 and math.abs(kz - (-0.55)) < 1e-9,
  ("DAY throws the shadows the mod always threw: (%.4f, %.4f)"):format(kx, kz))
local kx0, kz0 = DayNight.shearAt(0)
T.check(math.abs(math.sqrt(kx0 * kx0 + kz0 * kz0) - DayNight.K_MAX) < 1e-9,
  "a rising sun throws a LONG shadow, clamped -- never an infinite one")
T.eq(DayNight.strengthAt(0), 0, "and at the horizon it presses nothing")
T.eq(DayNight.strengthAt(300), 1, "at noon it presses in full")

-- the moon: due north at mid-night, pressing softly south
local mkx, mkz, mmoon = DayNight.shearAt(900)
T.check(mmoon, "mid-night is the moon's")
T.check(math.abs(mkx) < 1e-9, "due north: no east-west drift at all")
T.check(math.abs(mkz - 1 / math.tan(math.rad(40))) < 1e-9,
  "shadows fall south, away from it, cot(40) long")

-- the palettes: pins land on their phase palette unmixed, blends stay on
-- the 5-bit lattice
local function palEq(a, b)
  for i = 1, #a do
    for ch = 1, 3 do if a[i][ch] ~= b[i][ch] then return false end end
  end
  return #a == #b
end
T.check(palEq(DayNight.palette(300), DayNight.PALETTES.day),
  "noon paints the day palette, unmixed")
T.check(palEq(DayNight.palette(600), DayNight.PALETTES.dusk),
  "the dusk pin paints dusk proper -- the blend is centred on it, not over it")
T.check(palEq(DayNight.palette(0), DayNight.PALETTES.dawn),
  "and dawn's pin paints dawn")
local mid = DayNight.palette(562)         -- halfway through day -> dusk
for i, c in ipairs(mid) do
  T.check(c[1] % 8 == 0 and c[2] % 8 == 0 and c[3] % 8 == 0,
    "blended band " .. i .. " is re-quantised onto the GBC lattice")
end
T.check(mid[1][3] < DayNight.PALETTES.day[1][3]
        and mid[1][3] > DayNight.PALETTES.dusk[1][3],
  "and sits between the two phases it blends")
-- day's blue horizon and dusk's gold one are near-complements, and a
-- straight lerp between complements bottoms out in grey -- so the evening
-- path bends through the golden-hour waypoint, and halfway down the blend
-- the horizon band must already be WARM
T.check(mid[1][1] > mid[1][3],
  "mid-evening the horizon is gold, not the grey between blue and gold")
-- and the far side of sunset bends through violet the same way: halfway
-- from dusk to night the horizon is rose, not the taupe between gold and navy
local ev = DayNight.palette(645)[1]
T.check(ev[1] > ev[2] and ev[3] > ev[2],
  "mid-fall of night the horizon is violet-rose, not grey")
T.eq(DayNight.palette(300), DayNight.palette(300.4),
  "the palette is memoised within the second, not rebuilt per frame")

-- the tint: noon is neutral, night is dim and blue, indoors is always noon
local tn = DayNight.tint(true, 900)
T.check(tn[1] < 1 and tn[3] > tn[1], "night light is dim and leans blue")
T.eq(DayNight.tint(true, 300)[1], 1, "noon multiplies by one")
T.eq(DayNight.tint(false, 900)[1], 1,
  "a cave at midnight is exactly as dark as a cave at noon: neutral indoors")

-- the twilight glow: gold at the sun's horizons, never for the moon
local amt, gc = DayNight.glow(600)
T.check(math.abs(amt - 1) < 1e-9, "dusk glows in full")
T.check(gc[1] > gc[3], "and warm: more red than blue")
T.eq((DayNight.glow(300)), 0, "noon does not glow")
T.eq((DayNight.glow(900)), 0, "and the moon rises silver, not gold")

-- the discs cross the sky the camera can actually see
Voxel.angle = math.rad(75)
Voxel3D.camera = nil
Voxel3D.vp = Voxel3D.viewProjection(0, 0, 320, 288)
local horizon = Voxel3D.horizonY(288)

DayNight.setting:sync("night")
local mb = Voxel3D.skyBody(320, 288)
T.check(mb and mb.moon, "at the NIGHT pin the moon is in frame")
T.check(math.abs(mb.x - 160) < 8,
  ("due north is screen centre: got x %.1f"):format(mb.x))
T.check(mb.y > 0 and mb.y < horizon,
  ("hanging above the horizon point: y %.1f vs %.1f"):format(mb.y, horizon))

DayNight.setting:sync("day")
T.eq(Voxel3D.skyBody(320, 288), nil,
  "the noon sun is overhead behind the camera -- correctly not in frame")

DayNight.setting:sync("dawn")
local db = Voxel3D.skyBody(320, 288)
T.check(db and not db.moon, "at the DAWN pin the rising sun is in frame")
T.check(db.x > 160 and db.x < 320,
  ("north of east is screen right: got x %.1f"):format(db.x))
T.check(math.abs(db.y - horizon) < 2,
  "standing on the horizon point, half-risen")
T.check(db.glowAmt > 0.9, "and wrapped in the dawn glow")

DayNight.setting:sync("dusk")
local sb = Voxel3D.skyBody(320, 288)
T.check(sb and sb.x < 160, "the DUSK sun sets screen LEFT -- north of west")

-- the rig: outdoor follows the clock, indoor is pinned to noon
DayNight.setting:sync("night")
DayNight.applyRig(true)
T.check(math.abs(ShadowMap.KX - mkx) < 1e-9
        and math.abs(ShadowMap.KZ - mkz) < 1e-9,
  "outdoors at night the sun pass is lit by the moon")
T.check(math.abs(Voxel3D.SHADOW_ALPHA - DayNight.ALPHA_MOON) < 1e-9,
  "at the moon's own softer weight")
DayNight.applyRig(false)
T.check(math.abs(ShadowMap.KX - (-0.85)) < 1e-9
        and math.abs(ShadowMap.KZ - (-0.55)) < 1e-9,
  "indoors the rig stays the mod's noon sun, whatever the clock says")
T.check(math.abs(Voxel3D.SHADOW_ALPHA - DayNight.ALPHA_SUN) < 1e-9,
  "at the weight it always had")
T.eq(DayNight.shadowScale(false), 1, "an indoor arena keeps its full shadows")
T.check(math.abs(DayNight.shadowScale(true, 900)
                 - DayNight.ALPHA_MOON / DayNight.ALPHA_SUN) < 1e-9,
  "an outdoor arena under the moon presses at the moon's ratio")
T.check(DayNight.shadowScale(true, 600) < 1e-9,
  "and a sunset takes the arena's shadows with it")

-- the engine's own vocabulary, for map.palette and music.select
T.eq(DayNight.tod(300), "DAY", "noon is DAY")
T.eq(DayNight.tod(900), "NIGHT", "mid-night is NIGHT")
T.eq(DayNight.tod(0), "MORNING", "dawn is MORNING")
T.eq(DayNight.tod(600), "EVENING", "dusk is EVENING")

-- the clock rides the save slot
local modApi = run.loader.exports.DRAMATIC_SHAPE.lib.mod
DayNight.setting:sync("cycle")
DayNight.clock = 777
DayNight.store()
DayNight.clock = 5
DayNight.restore()
T.eq(DayNight.clock, 777, "the clock survives the round trip through mod.save")
modApi.save:set(DayNight.SAVE_KEY, nil)
DayNight.restore()
T.eq(DayNight.clock, 300, "a save with no clock in it starts at day")

-- SYNC lays the machine's own clock onto the dial: local noon is the DAY
-- pin, midnight is NIGHT, six and eighteen the twilights
local hoursWas = DayNight.hours
DayNight.setting:sync("sync")
DayNight.hours = function() return 12 end
T.eq(DayNight.time(), 300, "local noon is the DAY pin")
DayNight.hours = function() return 18 end
T.eq(DayNight.time(), 600, "six in the evening is DUSK")
DayNight.hours = function() return 0 end
T.eq(DayNight.time(), 900, "midnight is mid-night")
DayNight.hours = function() return 6.5 end
T.check(math.abs(DayNight.time() - 25) < 1e-9,
  "half past six in the morning is just after dawn")
-- and stepping from SYNC onto CYCLE picks up from the sky already showing
DayNight.update(0)
DayNight.setting:sync("cycle")
DayNight.update(0)
T.check(math.abs(DayNight.clock - 25) < 1e-9,
  "CYCLE picks up from wherever SYNC's sky already was")
DayNight.hours = hoursWas

-- arriving at FULL pins the sky to the clock on the wall
local Game = require("src.core.Game")
local hadSave = Game.save
Game.save = { options = {} }
DayNight.setting:sync("day")
defs.voxel.update(0, 2)               -- any rung that is not FULL
defs.voxel.update(0, 1)               -- and the arrival
T.eq(DayNight.setting:get(), "sync",
  "FULL pins DAYTIME to SYNC, whatever was chosen before")
Game.save = hadSave

-- put the room back the way it was found (SYNC is the shipped default)
DayNight.setting:sync("sync")
DayNight.clock = 300
DayNight.applyRig(false)
Voxel3D.tint = { 1, 1, 1 }
Voxel3D.vp = nil
end

-- ------- a scripted fight wipes in like a walked-into one
--
-- An engine seam this mod leans on: Commands.start_battle used to push the
-- BattleState bare, so the rival in Oak's lab CUT to battle with no
-- transition -- no flash, no wipe, the theme starting late. It now routes
-- through the overworld's own pushBattle, the same path a grass encounter
-- takes (and the path this mod wraps to stage the arena before the wipe).
do
local Commands = require("src.script.Commands")
local realBS = package.loaded["src.battle.BattleState"]
package.loaded["src.battle.BattleState"] = {
  newWild = function() return { kind = "wild" } end,
  newTrainer = function() return { kind = "trainer" } end,
}
local pushed, viaOverworld = nil, nil
local runner = { yield = function() end, resume = function() end }
local ctx = {
  runner = runner,
  game = { stack = { push = function(_, s) pushed = s end } },
  overworld = {
    pushBattle = function(_, b) viaOverworld = b end,
    afterBattle = function() end,
  },
}
Commands.start_battle(ctx, "trainer", "RIVAL1", 1)
T.check(viaOverworld ~= nil and pushed == nil,
  "a scripted trainer goes through pushBattle: the flash, the wipe and the "
  .. "theme, like any fight walked into")
T.eq(viaOverworld.kind, "trainer", "with the battle it was asked to start")
ctx.overworld = nil
Commands.start_battle(ctx, "wild", "PIDGEY", 5)
T.check(pushed ~= nil,
  "and a battle scripted with no overworld under it still starts bare")
package.loaded["src.battle.BattleState"] = realBS
end

-- ------- night falls in the forest
--
-- Viridian Forest is not outdoor (no sky, and the light through the leaves
-- has no direction to swing) and not a sealed room either. Of everything
-- the clock does, exactly one thing reaches a canopy map: the hour's tint.
-- The scenes wire it as tint(outdoor or isCanopy(map)) over the unchanged
-- noon rig, so what is checked here is the classification itself.
do
local DayNight = run.loader.exports.DRAMATIC_SHAPE.lib.require("DayNight")
T.check(DayNight.isCanopy({ id = "VIRIDIAN_FOREST" }),
  "Viridian Forest stands under a canopy")
T.check(not DayNight.isCanopy({ id = "MT_MOON_1F" }),
  "a cave does not -- midnight there is exactly as dark as noon")
T.check(not DayNight.isCanopy({ id = "PALLET_TOWN" }),
  "and an outdoor town is already the clock's in full")
T.check(not DayNight.isCanopy(nil), "no map, no canopy")
end

-- ------- a shadow keeps hold of the feet that throw it
--
-- The depth compare forgives `slack` world pixels so lit ground does not
-- acne, and that forgiveness detaches a standing card's shadow from its
-- feet by the same amount -- worse the lower the sun. Cards are drawn into
-- the map snugged TOWARD the sun along their own ray -- which moves their
-- stored depth and nothing about where their shadow falls -- taking most of
-- the forgiveness back for the shadow they throw and for nothing else.
do
local ShadowMap = run.loader.exports.DRAMATIC_SHAPE.lib.require("ShadowMap")
local Mat4 = run.loader.exports.DRAMATIC_SHAPE.lib.require("Mat4")
local dir = ShadowMap.sunDir()
local s = -ShadowMap.slack * ShadowMap.SNUG
local m = ShadowMap.snug(nil)
T.check(math.abs(m[4] - dir[1] * s) < 1e-9
        and math.abs(m[8] - dir[2] * s) < 1e-9
        and math.abs(m[12] - dir[3] * s) < 1e-9,
  "snug() moves a caster toward the sun -- AGAINST the light's travel")
T.check(m[8] > 0, "which is upward: the sun is above the world it lights")
T.check(ShadowMap.SNUG < 1,
  "and takes back less than the whole forgiveness, so a card cannot land "
  .. "on the float-equality knife edge against its own stored depth")
local snugged = ShadowMap.snug(Mat4.translate(10, 0, 6))
T.check(math.abs(snugged[4] - (10 + dir[1] * s)) < 1e-9
        and math.abs(snugged[12] - (6 + dir[3] * s)) < 1e-9,
  "and composes over the caster's own transform, not instead of it")
end

-- ------- the glass in the windows
--
-- Panes are found by SHAPE in the tileset art -- a black border row, four
-- or five black-flanked glass rows, a closing border -- at pixel
-- granularity, because the door's pane straddles a 2x2 tile block and the
-- building's sits a row down inside its tile. The scan takes a pure reader,
-- so the geometry is checked here without an image in sight.
do
local GlassMask = run.loader.exports.DRAMATIC_SHAPE.lib.require("GlassMask")
local DayNight = run.loader.exports.DRAMATIC_SHAPE.lib.require("DayNight")
local Voxel3D = run.loader.exports.DRAMATIC_SHAPE.lib.require("Voxel3D")

local W, H = 32, 16
local blackAt = {}
local function paint(x, y) blackAt[y * W + x] = true end
local function pane(x0, y0, rows, hole)
  for c = 1, 6 do paint(x0 + c, y0); paint(x0 + c, y0 + rows + 1) end
  for r = 1, rows do
    paint(x0, y0 + r); paint(x0 + 7, y0 + r)
    if hole and r == 2 then paint(x0 + 3, y0 + r) end
  end
end
pane(8, 1, 5)              -- a building pane, one row down inside its tile
pane(20, 3, 4)             -- a door pane, straddling a tile row boundary
pane(0, 8, 5, true)        -- a near-miss: one black texel inside the glass

local function getPixel(x, y)
  if blackAt[y * W + x] then return 0, 0, 0 end
  return 0.66, 0.66, 0.66
end

local rects = GlassMask.scan(getPixel, W, H)
T.eq(#rects, 2, "the scan finds the two real panes and rejects the near-miss")
T.check(rects[1].x == 9 and rects[1].y == 2
        and rects[1].w == 6 and rects[1].h == 5,
  "the building pane's glass is the 6x5 interior, border excluded")
T.check(rects[2].x == 21 and rects[2].y == 4
        and rects[2].w == 6 and rects[2].h == 4,
  "the door pane's glass is the 6x4 interior, wherever it sits in the grid")

-- black is the BORDER black, not the art's dark grey rung
T.check(GlassMask._isBlack(0, 0, 0), "true black is border")
T.check(not GlassMask._isBlack(85 / 255, 85 / 255, 85 / 255),
  "the dark grey shade is not")

-- the lamps behind the glass follow the clock, not the sky's own light
T.eq(DayNight.windowLight(300), 0, "no lamps at noon")
T.eq(DayNight.windowLight(900), 1, "all of them at mid-night")
T.check(math.abs(DayNight.windowLight(600) - 0.7) < 1e-9,
  "they come on through dusk -- lit windows against the sunset")
T.check(DayNight.windowLight(645) > 0.9,
  "and are fully on by the fall of night")
T.check(math.abs(DayNight.windowLight(0) - 0.25) < 1e-9,
  "mostly out again by dawn")

-- the pass defaults to no glass at all until a scene says otherwise
T.eq(Voxel3D.glassMask, nil, "no mask bound by default")
T.eq(Voxel3D.glassNight, 0, "and the lamps off")

-- the glint is fed by TRAVEL, not by a clock: still camera, still glass
local g = {}
VoxelScene.glintStep(g, 100, 100)
T.eq(g.amp, 0, "the first frame establishes position and shows no sheen")
for i = 1, 12 do VoxelScene.glintStep(g, 100 + i, 100) end
T.eq(g.amp, 1, "a dozen frames of walking fades the glint fully in")
local held = g.phase
T.check(held > 0 and held < 2 * math.pi, "with the phase advanced by the travel")
for _ = 1, 20 do VoxelScene.glintStep(g, 112, 100) end
T.eq(g.amp, 0, "standing still fades it back out within a beat")
T.eq(g.phase, held, "and the phase does not move while the camera does not")
end

Pipelines.reset()
run.release()

T.finish("DRAMATIC_SHAPE")
