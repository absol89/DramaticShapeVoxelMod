-- TEST47: dedicated Cut-tree presentation, isolated from mature trees.

local function read(path)
  local f = assert(io.open(path, "rb"))
  local source = f:read("*a")
  f:close()
  return source
end

local flora = read("lib/CommunityFlora.lua")
local structures = read("lib/Structures.lua")
local cache = read("lib/VoxelMeshDisk.lua")
local main = read("main.lua")
local manifest = read("manifest.json")

assert(flora:find('local saplingReg = (rawget(_G, "__ds_sapling_cells") or {})[rk] or {}', 1, true),
       "dedicated sapling registry lookup is missing")
assert(flora:find("local sapling = saplingReg[key] == true", 1, true)
       and flora:find("elseif sapling then", 1, true),
       "Cut tree did not split from the mature-tree builder")
assert(flora:find("TEST47 CITY-SUPPORTED SAPLING", 1, true)
       and flora:find("local stakeR=4.15", 1, true)
       and flora:find("Two plain city planting stakes", 1, true)
       and flora:find("Dark support ties", 1, true),
       "supported sapling geometry is incomplete")
assert(flora:find("Five separated bunches", 1, true),
       "sparse young crown is missing")
assert(structures:find("community_cut_tree_test47", 1, true),
       "round-template signature was not advanced")
assert(cache:find("Disk.CACHE_REVISION = 25", 1, true),
       "persistent mesh revision was not advanced")
assert(main:find("city sapling with two support stakes and dark ties", 1, true),
       "WORLD option description was not updated")
assert(manifest:find('"version": "1.10.2"', 1, true)
       and manifest:find("BATTLE ART VOXEL FORK", 1, true),
       "integration package identity is missing")

print("TEST47 city-supported sapling: isolated skinny trunk, stakes, ties and sparse crown locked")
