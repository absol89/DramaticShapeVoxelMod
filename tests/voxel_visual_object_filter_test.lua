-- ROM-free checks for the terrain visual-object filter and cache boundary.
local checks = 0
local function check(value, message)
  checks = checks + 1
  if not value then error("FAIL: " .. message, 0) end
end

local invalidations = 0
package.loaded["src.render.Assets"] = {
  register = function() end,
}

local structures = {
  invalidate = function() invalidations = invalidations + 1 end,
}
local namespace = {
  companion = nil,
  require = function(name)
    local modules = {
      Structures = structures,
      TileShape = {},
      Voxel3D = { pushQuad = function() end },
      BuildBudget = { tick = function() end },
      VoxelMeshDisk = {
        available = function() return false end,
        legacy = function() return false end,
        purge = function() return true end,
      },
    }
    return assert(modules[name], "unexpected module " .. tostring(name))
  end,
}

local ChunkMesher = assert(loadfile("lib/ChunkMesher.lua"))(namespace)
local known = "BATTLE_ART_VOXEL_FORK:signpost:PALLET_TOWN:7:9"

check(ChunkMesher.visualObjectVisible(known),
  "an absent Companion owner preserves original geometry")
namespace.companion = {
  suppressesVisualObject = function(_, id) return id == known end,
  hasVisualObjectOverrides = function(_, mapId) return mapId == "PALLET_TOWN" end,
}
check(not ChunkMesher.visualObjectVisible(known),
  "a valid active owner suppresses only its annotated object quads")
check(ChunkMesher.visualObjectVisible("BATTLE_ART_VOXEL_FORK:signpost:ROUTE_1:9:27"),
  "an unclaimed object keeps its original geometry")
namespace.companion.suppressesVisualObject = function() error("synthetic owner fault", 0) end
check(ChunkMesher.visualObjectVisible(known),
  "a suppression lookup fault fails open")

check(ChunkMesher.refreshVisualObjects("PALLET_TOWN"),
  "a named visual cache refresh is accepted")
check(invalidations == 0,
  "visual ownership does not invalidate structure analysis or unrelated auxiliary caches")
check(ChunkMesher.refreshVisualObjects(nil) == false,
  "a malformed visual cache target fails closed")

print(("%d checks passed (visual-object terrain filter)"):format(checks))
