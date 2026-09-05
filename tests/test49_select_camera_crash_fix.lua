-- TEST49: Select/Back camera cycling must not depend on optional diagnostics.

local function read(path)
  local f = assert(io.open(path, "rb"))
  local source = f:read("*a")
  f:close()
  return source
end

local main = read("main.lua")
local manifest = read("manifest.json")
local voxel = read("lib/VoxelState.lua")

assert(main:find("local function cycleVoxelCamera(game)", 1, true)
       and main:find('input:wasPressed("select")', 1, true),
       "Select/Back camera implementation is missing")
assert(not main:find('V.log:event("voxel", "select-camera-cycle"', 1, true),
       "unsafe optional logger call was restored")
assert(main:find("camera cycling is gameplay behavior and must never depend on", 1, true),
       "TEST49 logger-independence guard is missing")
assert(voxel:find("Voxel.HOTKEY_ORDER = { 0, 2, 3, 4, 5, 6, 7 }", 1, true),
       "camera ladder changed during crash hotfix")
assert(main:find('mod.exports.version = "1.10.2"', 1, true)
       and manifest:find('"version": "1.10.2"', 1, true)
       and manifest:find("BATTLE ART VOXEL FORK", 1, true),
       "integration package identity is missing")

print("TEST49 Select camera crash fix: logger-independent camera step locked")
