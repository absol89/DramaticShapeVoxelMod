-- TEST48: N64 Memory's Select/Back camera bridge, safely ported to Battle Art.

local function read(path)
  local f = assert(io.open(path, "rb"))
  local source = f:read("*a")
  f:close()
  return source
end

local main = read("main.lua")
local voxel = read("lib/VoxelState.lua")
local manifest = read("manifest.json")
local Voxel = assert(loadfile("lib/VoxelState.lua"))()

local expected = { 2, 3, 4, 5, 6, 7, 0 }
local level = 0
for _, want in ipairs(expected) do
  level = Voxel.nextHotkeyLevel(level)
  assert(level == want, "camera ladder order changed")
end
assert(Voxel.nextHotkeyLevel(Voxel.FULL_LEVEL) == 4,
       "FULL must continue from its matching 35-degree view to 50 degrees")

assert(voxel:find("Voxel.HOTKEY_ORDER = { 0, 2, 3, 4, 5, 6, 7 }", 1, true),
       "camera ladder no longer includes tilt, first-person and third-person rungs")
assert(main:find("local function cycleVoxelCamera(game)", 1, true)
       and main:find("Voxel.nextHotkeyLevel", 1, true),
       "authoritative camera cycle helper is missing")
assert(main:find('input:wasPressed("select")', 1, true)
       and main:find("OverworldState.legendarySelectCameraHook", 1, true),
       "Select/Back overworld bridge is missing or unguarded")
assert(main:find("FirstPerson.install()", 1, true)
       < main:find("TEST48 SELECT/BACK CAMERA CYCLER", 1, true),
       "Select bridge must wrap outside FirstPerson/FreeMove")
assert(main:find("cycleVoxelCamera(self)", 1, true),
       "keyboard and Select do not share one camera step")
assert(main:find('mod.exports.version = "1.10.0-test49-select-camera-log-hotfix-compat253"', 1, true)
       and manifest:find('"version": "1.10.0-test49-select-camera-log-hotfix-compat253"', 1, true),
       "TEST49 derivative package identity is missing")

print("TEST48 Select/Back camera cycle: overworld-only shared ladder locked")
