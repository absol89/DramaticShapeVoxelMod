package.path = "./?.lua;./?/init.lua;" .. package.path

local T = require("tests.modkit")
local Pipelines = require("src.render.Pipelines")
local Runtime = require("src.mods.Runtime")
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

run.release()
print("textbox_mod_integration_test: PASS")
