-- Engine-root test: OFF must use generated session records, never disk input.
package.path = "./?.lua;./?/init.lua;" .. package.path
local T = require("tests.harness")
local root = os.getenv("DS_MOD_PATH") or "mods/BATTLE_ART_VOXEL_FORK"
local ffi = require("ffi")
local reads, writes, lists = 0, 0, 0
local persisted = {}
local store = {
  readBytes = function(_, key) reads = reads + 1; return persisted[key] end,
  writeBytes = function(_, key, value) writes = writes + 1; persisted[key] = value; return true end,
  list = function() lists = lists + 1; local out = {}; for key in pairs(persisted) do out[#out + 1] = key end; return out end,
}
-- Deterministic test codec; production serialization/validation is unmodified.
love = { graphics = { newMesh = function() end }, data = {
  pack = function(_, fmt, ...)
    assert(fmt == "<ffff")
    local f = ffi.new("float[4]", { ... }); return ffi.string(f, 16)
  end,
  unpack = function(fmt, blob, pos)
    assert(fmt == "<ffff")
    local f = ffi.new("float[4]"); ffi.copy(f, blob:sub(pos, pos + 15), 16)
    return f[0], f[1], f[2], f[3], pos + 16
  end,
  compress = function(_, _, raw) return raw end,
  decompress = function(_, _, raw) return raw end,
  newByteData = function() end,
} }
local Disk = assert(loadfile(root .. "/lib/VoxelMeshDisk.lua"))({
  require = function() return { check = function() end } end,
})
Disk.staticEligible = function() return true end
Disk.fingerprint = function(map, slot) return map.id .. ":" .. slot end
local function setStore(value)
  for i = 1, 100 do
    local name = debug.getupvalue(Disk.loadIntoRam, i)
    if name == "storage" then debug.setupvalue(Disk.loadIntoRam, i, value); return end
  end
  error("storage test seam missing")
end
local map = { id = "ROUTE_1" }
local terrain = { n = 1, chunks = { string.rep("v", 24) }, spans = { 0, 1, 8, 8 } }
Disk.beginSession(true)
T.check(Disk.available(), "session RAM works without a persistent backend")
T.eq(Disk.loadTerrain(map, "full"), nil, "uncached OFF map requests live generation")
T.check(Disk.saveTerrain(map, "full", nil, terrain, { n = 0 }), "generated terrain saves to RAM")
local loaded = Disk.loadTerrain(map, "full")
T.eq(loaded.terrain.chunks[1], terrain.chunks[1], "generated terrain loads back from RAM")
T.same(loaded.spans, terrain.spans, "cut-tree ownership survives the session cache")
T.eq(Disk.ramStats().dirty, 1, "generated record is retained for this session")
setStore(store)
T.eq(writes, 0, "live generation did not write persistent storage")
T.check(Disk.saveRamToDisk(), "explicit SAVE still works")
T.eq(writes, 1, "only explicit SAVE writes disk")
Disk.setSessionOnly(false)
Disk.setSessionOnly(true)
T.eq(Disk.ramStats().files, 1, "OFF retains generated data even after explicit SAVE")
local savedGc = collectgarbage
collectgarbage = nil
T.check(pcall(Disk.dropRam), "DROP is safe without a garbage-collection API")
collectgarbage = savedGc
T.eq(Disk.loadTerrain(map, "full"), nil, "OFF ignores the now-existing disk record")
T.eq(Disk.loadIntoRam(Disk.DIRECTORY .. "/ROUTE_1/full-terrain"), false, "explicit preload helper also respects OFF")
T.same(Disk.ramPlan(), {}, "OFF never plans eager reads")
T.eq(reads, 0, "OFF performed no persistent reads")
T.eq(lists, 0, "OFF performed no directory scans")
Disk.setSessionOnly(false)
T.check(Disk.loadTerrain(map, "full") ~= nil, "non-OFF settings retain on-demand disk loading")
T.eq(reads, 1, "non-OFF loads the persisted record once")
Disk.setSessionOnly(true)
T.eq(Disk.ramStats().files, 0, "switching OFF drops disk-loaded records")
T.finish("RAM precache OFF storage policy")
