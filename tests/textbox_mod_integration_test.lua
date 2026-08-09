package.path = "./?.lua;./?/init.lua;" .. package.path

local T = require("tests.modkit")
local Pipelines = require("src.render.Pipelines")
local Runtime = require("src.mods.Runtime")
local Game = require("src.core.Game")
local Data = T.fixtures.load()
local modPath = os.getenv("DS_MOD_PATH") or "mods/BATTLE_ART_VOXEL_FORK"
local run = T.sdk.loadMod(modPath, { data = Data })

local function check(condition, message)
  if not condition then error(message, 0) end
end

check(#run.errors == 0,
  "mod failed to load: " .. table.concat(run.errors, "; "))
Pipelines.install(Data)

local VoxelState = run.loader.exports.BATTLE_ART_VOXEL_FORK.lib.require("VoxelState")
Pipelines.setLevel("voxel", VoxelState.FULL_LEVEL)

local rows = Runtime.call("ui.options.rows", function(_, offered) return offered end,
  { data = Data },
  { { id = "pipeline:voxel" }, { id = "pipeline:tiltshift" } })

local textboxRow
for _, row in ipairs(rows) do
  if row.id == "BATTLE_ART_VOXEL_FORK:textboxFill" then
    textboxRow = row
    break
  end
end

check(textboxRow ~= nil,
  "TEXTBOX FILL must remain exposed while VOXEL is FULL")
check(textboxRow.value() == "WHITE",
  "TEXTBOX FILL must preserve the latest build's WHITE default")

-- The 3D battle cannot composite WORLD's frozen-overworld path, but BLACK is
-- an ordinary opaque letterbox and remains valid. The voxel update must not
-- rewrite a deliberate BLACK choice on every frame.
local previousSave = Game.save
local previousWriteOptions = Game.writeOptions
local writes = 0
Game.save = { options = { battleBg = "black" } }
Game.writeOptions = function() writes = writes + 1 end

Pipelines.setLevel("voxel", 3)
Pipelines.update(0)
check(Game.save.options.battleBg == "black",
  "voxel update must preserve BATTLE BG BLACK")
check(writes == 0,
  "preserving BATTLE BG BLACK must not rewrite options")

Pipelines.setLevel("voxel", VoxelState.FULL_LEVEL)
Pipelines.update(0)
check(Game.save.options.battleBg == "black",
  "entering VOXEL FULL must preserve BATTLE BG BLACK")

-- Ignore the writes made by the rest of the FULL preset; this assertion is
-- specifically about the compatibility correction on subsequent frames.
writes = 0
Game.save.options.battleBg = "world"
Pipelines.update(0)
check(Game.save.options.battleBg == "white",
  "voxel update must replace incompatible BATTLE BG WORLD with WHITE")
check(writes == 1,
  "replacing BATTLE BG WORLD must persist exactly once")

Game.save = previousSave
Game.writeOptions = previousWriteOptions

run.release()
print("textbox_mod_integration_test: PASS")
