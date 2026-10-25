-- FORMAT 3 cache contract: fixed version header, geometry variants in paths,
-- and safe reuse of matching FORMAT 2 flat records.
local ffi = require("ffi")
local checks = 0
local function check(value, message)
  checks = checks + 1
  assert(value, message)
end
local function eq(actual, expected, message)
  check(actual == expected, (message or "values differ") ..
    (actual == expected and "" or (" (got %s, expected %s)"):format(
      tostring(actual), tostring(expected))))
end

package.loaded["src.core.Version"] = { engine = "0.2.53" }
package.loaded["src.core.Platform"] = { detect = function() return { os = "Windows" } end }

love = { graphics = { newMesh = function() end }, data = {
  pack = function(_, fmt, ...)
    assert(fmt == "<ffff")
    return ffi.string(ffi.new("float[4]", { ... }), 16)
  end,
  unpack = function(fmt, blob, pos)
    assert(fmt == "<ffff")
    local f = ffi.new("float[4]")
    ffi.copy(f, blob:sub(pos, pos + 15), 16)
    return f[0], f[1], f[2], f[3], pos + 16
  end,
  compress = function(_, _, raw) return raw end,
  decompress = function(_, _, raw) return raw end,
  newByteData = function() end,
} }

local trace = {}
local Timings = { wrap = function(_, fn) return fn end }
local V = { require = function(name)
  if name == "CacheTrace" then
    return { log = function(event, map, detail)
      trace[#trace + 1] = { event = event, map = map, detail = detail }
    end }
  end
  if name == "BuildBudget" then return { check = function() end } end
  if name == "LoadTimings" then return Timings end
  if name == "StaticGeometry" then
    return { source = function(map) return map end, record = function() end }
  end
  return {}
end }

local Disk = assert(loadfile("lib/VoxelMeshDisk.lua"))(V)
Disk.staticEligible = function() return true end

local stored, reads = {}, {}
local storage = {
  readBytes = function(_, key)
    reads[key] = (reads[key] or 0) + 1
    return stored[key]
  end,
  writeBytes = function(_, key, bytes)
    stored[key] = bytes
    return true
  end,
  list = function(_, prefix)
    local out = {}
    for key, bytes in pairs(stored) do
      if type(bytes) == "string" and bytes ~= ""
          and key:sub(1, #prefix) == prefix then out[#out + 1] = key end
    end
    table.sort(out)
    return out
  end,
}
for i = 1, 100 do
  local name = debug.getupvalue(Disk.loadIntoRam, i)
  if name == "storage" then
    debug.setupvalue(Disk.loadIntoRam, i, storage)
    break
  end
end

local function u32(n)
  n = math.floor(n) % 4294967296
  return string.char(n % 256, math.floor(n / 256) % 256,
                     math.floor(n / 65536) % 256,
                     math.floor(n / 16777216) % 256)
end
local function readU32(s, pos)
  return s:byte(pos) + s:byte(pos + 1) * 256
       + s:byte(pos + 2) * 65536 + s:byte(pos + 3) * 16777216
end
local function withU32(blob, pos, value)
  return blob:sub(1, pos - 1) .. u32(value) .. blob:sub(pos + 4)
end
local function legacyBlob(fp, v3blob)
  return "BAVC" .. u32(2) .. u32(#fp) .. fp .. v3blob:sub(13)
end
local function findKey(product, variant)
  local suffix = "/" .. product .. "/variant-"
  for key, bytes in pairs(stored) do
    if type(bytes) == "string" and bytes ~= ""
        and key:find(suffix, 1, true) and key:sub(1, #Disk.DIRECTORY) == Disk.DIRECTORY then
      if not variant or key:sub(-16) == Disk.variantId(variant) then return key end
    end
  end
end
local function saw(event)
  for _, row in ipairs(trace) do if row.event == event then return true, row.detail end end
  return false
end
local function clearTrace() trace = {} end

local mode = "off"
Disk.fingerprint = function(map, slot, masks, kind)
  return table.concat({ "rev", Disk.CACHE_REVISION, "map", map.id,
                        "kind", kind, "slot", slot, "mode", mode }, "|")
end

local map = { id = "FORMAT_TEST" }
local terrainA = { n = 1, chunks = { string.rep("a", 24) }, spans = { 0, 1, 2, 3 } }
local terrainB = { n = 1, chunks = { string.rep("b", 24) }, spans = { 4, 5, 6, 7 } }
local water = { n = 0 }
local aux = { grass = { n = 0, spans = {} }, flowers = { n = 0, spans = {} }, figures = {} }

local fpA = Disk.fingerprint(map, "ring", nil, "terrain")
check(Disk.saveTerrain(map, "ring", nil, terrainA, water), "OFF terrain saves")
check(Disk.saveAux(map, aux), "OFF aux saves")
local keyA = assert(findKey("ring-terrain", fpA), "OFF variant key missing")
local auxKeyA = assert(findKey("deco", Disk.fingerprint(map, "aux", nil, "aux")),
  "OFF aux variant key missing")
local blobA, auxBlobA = stored[keyA], stored[auxKeyA]
eq(blobA:sub(1, 4), "BAVC", "new cache keeps BAVC magic")
eq(readU32(blobA, 5), 3, "new cache writes FORMAT 3")
eq(readU32(blobA, 9), Disk.CACHE_REVISION, "fixed header stores cache revision")
eq(#blobA:sub(1, 12), 12, "FORMAT 3 compatibility header is fixed-size")
check(not blobA:sub(1, 12):find(fpA, 1, true),
  "exact visual fingerprint is not serialized in the FORMAT 3 header")
check(keyA:match("/ring%-terrain/variant%-%x+$") ~= nil and #keyA:match("variant%-(%x+)$") == 16,
  "geometry identity is a 64-bit variant path component")
check(not Disk.complete(map, false, nil), "ring alone cannot certify a whole map")
check(Disk.saveTerrain(map, "body", nil, terrainA, water), "shared body saves")
check(Disk.complete(map, false, nil), "title resume recognizes the current FORMAT 3 variant")

local prefix = Disk.DIRECTORY .. "/"
local ordered = {
  prefix .. "OTHER/full-terrain/variant-0000000000000001",
  prefix .. "NEIGHBOR/full-terrain/variant-0000000000000002",
  prefix .. "FORMAT_TEST/body-terrain/variant-0000000000000003",
  prefix .. "NEIGHBOR/deco", -- legacy flat paths remain classifiable too
  prefix .. "FORMAT_TEST/full-terrain/variant-0000000000000004",
  prefix .. "NEIGHBOR/body-terrain/variant-0000000000000005",
  prefix .. "FORMAT_TEST/deco/variant-0000000000000006",
}
Disk.orderRamNames(ordered, { "FORMAT_TEST", "NEIGHBOR" })
eq(ordered[1], prefix .. "FORMAT_TEST/deco/variant-0000000000000006",
  "RAM ordering recognizes current-map FORMAT 3 deco")
eq(ordered[2], prefix .. "FORMAT_TEST/body-terrain/variant-0000000000000003",
  "RAM ordering loads the current shared body before any border")
eq(ordered[3], prefix .. "NEIGHBOR/body-terrain/variant-0000000000000005",
  "RAM ordering recognizes neighbor FORMAT 3 body terrain")
eq(ordered[4], prefix .. "NEIGHBOR/deco",
  "RAM ordering still recognizes legacy flat neighbor deco")

mode = "full"
local fpB = Disk.fingerprint(map, "ring", nil, "terrain")
check(Disk.saveTerrain(map, "ring", nil, terrainB, water), "FULL terrain saves beside OFF")
check(Disk.saveAux(map, aux), "FULL aux saves beside OFF")
local keyB = assert(findKey("ring-terrain", fpB), "FULL variant key missing")
check(keyA ~= keyB and stored[keyA] and stored[keyB],
  "different geometry variants coexist instead of overwriting one flat file")
check(Disk.saveTerrain(map, "body", nil, terrainB, water), "second visual body saves")
local stats = Disk.stats()
check(stats.files == 6 and stats.maps == 1 and stats.aux == 2 and stats.full == 2,
  "nested FORMAT 3 variants are classified correctly by cache stats")
local blobB = stored[keyB]
local loadedB = assert(Disk.loadTerrain(map, "ring"), "FULL variant reloads")
eq(loadedB.terrain.chunks[1], terrainB.chunks[1], "FULL selects its own variant body")

mode = "off"
local loadedA = assert(Disk.loadTerrain(map, "ring"), "OFF variant reloads")
eq(loadedA.terrain.chunks[1], terrainA.chunks[1], "OFF selects its own variant body")

local emptyTrees = { count = 0, tN = 0, bN = 0, cells = {}, parts = {} }
check(Disk.saveTreeParts(map, "balanced", "abc123", emptyTrees),
  "OFF tree sections save into a variant path")
local treeA
for key in pairs(stored) do
  if key:find("/tree-balanced-abc123/variant-", 1, true) then treeA = key end
end
mode = "full"
check(Disk.saveTreeParts(map, "balanced", "abc123", emptyTrees),
  "FULL tree sections save beside OFF")
local treeKeys = {}
for key in pairs(stored) do
  if key:find("/tree-balanced-abc123/variant-", 1, true) then
    treeKeys[#treeKeys + 1] = key
  end
end
check(treeA and #treeKeys == 2 and treeKeys[1] ~= treeKeys[2],
  "tree recipe/signature paths also separate visual geometry variants")
check(Disk.loadTreeParts(map, "balanced", "abc123") ~= nil,
  "FULL selects its matching tree variant")
mode = "off"
check(Disk.loadTreeParts(map, "balanced", "abc123") ~= nil,
  "OFF can switch back to its matching tree variant")

-- Replace the new OFF records with exact legacy FORMAT 2 flat records. Resume
-- and gameplay must reuse them without duplicating the user's existing cache.
local legacyTerrain = Disk.DIRECTORY .. "/FORMAT_TEST/ring-terrain"
local legacyAux = Disk.DIRECTORY .. "/FORMAT_TEST/deco"
stored[keyA], stored[auxKeyA] = nil, nil
stored[legacyTerrain] = legacyBlob(fpA, blobA)
local auxFpA = Disk.fingerprint(map, "aux", nil, "aux")
stored[legacyAux] = legacyBlob(auxFpA, auxBlobA)
check(Disk.complete(map, false, nil), "title resume accepts matching FORMAT 2 fallback")

Disk.beginSession(false)
mode = "full"
stored[keyB] = nil
clearTrace()
check(Disk.loadTerrain(map, "ring") == nil,
  "a legacy OFF record cannot satisfy the FULL geometry variant")
check(saw("reject-variant"), "legacy mismatch is diagnosed as a variant mismatch")
local mismatchReads = reads[legacyTerrain] or 0

mode = "off"
local legacyA = assert(Disk.loadTerrain(map, "ring"),
  "legacy mismatch does not poison the flat record for a later matching mode")
eq(legacyA.terrain.chunks[1], terrainA.chunks[1], "matching legacy body remains usable")
check((reads[legacyTerrain] or 0) > mismatchReads,
  "matching retry can read the legacy record after a prior variant mismatch")

-- Wrong cache revision and wrong stream format are genuine compatibility
-- failures. They are rejected even though the variant path itself is correct.
Disk.dropRam()
mode = "full"
stored[keyB] = withU32(blobB, 9, Disk.CACHE_REVISION + 1)
clearTrace()
check(Disk.loadTerrain(map, "ring") == nil, "wrong cache revision is rejected")
check(saw("reject-cache-version"), "revision mismatch has an explicit diagnostic")

Disk.dropRam()
stored[keyB] = withU32(blobB, 5, 99)
clearTrace()
check(Disk.loadTerrain(map, "ring") == nil, "wrong BAVC format is rejected")
local formatRejected, formatDetail = saw("reject-cache-header")
check(formatRejected and tostring(formatDetail):find("unsupported BAVC format", 1, true),
  "format mismatch is reported as format/header incompatibility")

Disk.dropRam()
stored[keyB] = blobB:sub(1, 12) .. "bad"
clearTrace()
check(Disk.loadTerrain(map, "ring") == nil, "malformed payload is rejected after a valid header")
check(saw("reject-cache-body"), "payload corruption has a distinct body diagnostic")

Disk.dropRam()
stored[keyB] = blobB
local restored = assert(Disk.loadTerrain(map, "ring"), "valid FORMAT 3 survives after rejection reset")
eq(restored.terrain.chunks[1], terrainB.chunks[1], "valid variant still decodes normally")

-- <=0.1.83 has a flat native-filesystem backend. FORMAT 3 logical variants
-- must survive its logical<->physical filename adapter too.
local legacyFiles = {}
love.filesystem = {
  createDirectory = function() return true end,
  getInfo = function(path)
    return legacyFiles[path] and { type = "file" } or { type = "directory" }
  end,
  read = function(path) return legacyFiles[path] end,
  write = function(path, bytes) legacyFiles[path] = bytes; return true end,
  getDirectoryItems = function(root)
    local out, prefix = {}, root .. "/"
    for path in pairs(legacyFiles) do
      if path:sub(1, #prefix) == prefix then out[#out + 1] = path:sub(#prefix + 1) end
    end
    table.sort(out)
    return out
  end,
}
local LegacyDisk = assert(loadfile("lib/VoxelMeshDisk.lua"))(V)
LegacyDisk.staticEligible = function() return true end
LegacyDisk._setCompatibilityForTests("0.1.83", "Windows")
check(LegacyDisk.bind({ save = { version = "yellow" } }),
  "legacy native-filesystem cache backend binds")
LegacyDisk.fingerprint = Disk.fingerprint
mode = "off"
local legacyFp = LegacyDisk.fingerprint(map, "ring", nil, "terrain")
check(LegacyDisk.saveTerrain(map, "ring", nil, terrainA, water),
  "FORMAT 3 variant writes through legacy flat filesystem adapter")
local legacyPhysical
for path in pairs(legacyFiles) do
  if path:find("FORMAT_TEST.ring.terrain.variant-", 1, true) then legacyPhysical = path end
end
check(legacyPhysical and legacyPhysical:match("%.variant%-%x%x%x%x%x%x%x%x%x%x%x%x%x%x%x%x%.bavc$"),
  "legacy backend flattens the nested variant into a safe physical filename")
local legacyNames = LegacyDisk.ramPlan({ "FORMAT_TEST" })
local wantedLegacyLogical = LegacyDisk.DIRECTORY .. "/FORMAT_TEST/ring-terrain/variant-"
  .. LegacyDisk.variantId(legacyFp)
check(legacyNames[1] == wantedLegacyLogical,
  "legacy backend enumerates the flattened file back to its FORMAT 3 logical key")
check(LegacyDisk.saveTerrain(map, "full", nil, terrainA, water),
  "old FULL product remains writable for rollback consumers")
check(LegacyDisk.loadTerrain(map, "full") ~= nil,
  "old FULL product remains readable")
local activeNames=LegacyDisk.ramPlan({"FORMAT_TEST"})
eq(#activeNames,1,"unused historical FULL must not consume preload RAM")
eq(activeNames[1],wantedLegacyLogical,"active preload retains RING")

print(checks .. " checks passed (voxel cache FORMAT 3 + legacy migration)")
