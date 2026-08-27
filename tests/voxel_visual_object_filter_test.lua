-- ROM-free integration checks for annotated sign ownership and cached terrain.
local checks = 0
local function check(value, message)
  checks = checks + 1
  if not value then error("FAIL: " .. message, 0) end
end
local function equal(actual, expected, message)
  checks = checks + 1
  if actual ~= expected then
    error(("FAIL: %s (expected %s, got %s)")
      :format(message, tostring(expected), tostring(actual)), 0)
  end
end
local function contains(text, fragment, message)
  check(type(text) == "string" and text:find(fragment, 1, true) ~= nil, message)
end

local API = assert(loadfile("lib/VoxelCompanionAPI.lua"))()
local VisualObjects = assert(loadfile("lib/VoxelVisualObjects.lua"))()
local Budget = {
  tick = function() end, check = function() end,
  begin = function() end, finish = function() end,
}
local Buildings = {
  build = function() end, invalidate = function() end,
}
local TileShape = { propBg = function() return nil end }
local Assets = { register = function() end }
package.loaded["src.render.Assets"] = Assets
package.loaded["src.world.Map"] = { isOutdoor = function() return true end }
package.loaded["src.core.Game"] = { save = { version = "red" } }

local structureNamespace = {
  require = function(name)
    return assert(({
      Buildings = Buildings,
      TileShape = TileShape,
      BuildBudget = Budget,
      VoxelVisualObjects = VisualObjects,
    })[name], "unexpected Structures module " .. tostring(name))
  end,
}
local Structures = assert(loadfile("lib/Structures.lua"))(structureNamespace)
local keyOf = function(x, z) return (z + 64) * 4096 + (x + 64) end

local analyses = {}
local function annotatedMap(id)
  local map = {
    id = id,
    widthCells = 2,
    heightCells = 2,
    def = { width = 1, height = 1, tileset = "OVERWORLD" },
    tileset = {
      id = "OVERWORLD", image = "synthetic-atlas", tilesPerRow = 16,
      imageWidth = 128, imageHeight = 48,
    },
  }
  function map:tileAt(x, z) return (x == 2 and z == 0) and 1 or 0 end
  function map:cellTile(x, z) return (x == 0 and z == 0) and 4 or 0 end
  function map:isWalkableCell(x, z) return not (x == 0 and z == 0) end
  function map:isWaterCell() return false end
  function map:isGrassCell() return false end
  function map:warpAtCell() return nil end
  function map:isWarpTileCell() return false end

  local sign = { class = "signpost", authored = true, art = "upright", h = 16 }
  local ground = { class = "ground", flat = true, art = "flat", h = 0 }
  local S = {
    shapeAt = {}, tileAt = {}, outdoor = true,
    runs = {}, skip = {}, ground = {}, doorFold = {}, objectQuads = {},
    grassQuads = {}, flowerQuads = {}, roundStamps = {}, figures = {},
  }
  local tiles = { { 0, 0 }, { 1, 0 }, { 0, 1 }, { 1, 1 } }
  for _, cell in ipairs(tiles) do
    S.shapeAt[keyOf(cell[1], cell[2])] = sign
    S.tileAt[keyOf(cell[1], cell[2])] = 0
  end
  S.shapeAt[keyOf(2, 0)], S.tileAt[keyOf(2, 0)] = ground, 1
  local region = { minX = 0, maxX = 1, minY = 0, maxY = 1, tiles = tiles }
  local data = { getPixel = function() return 0, 0, 0, 1 end }
  Structures.extractObjects(S, map, region, data, 16, true)
  check(#S.objectQuads > 0, "Structures emits a real pinned sign mesh")
  local expected = assert(VisualObjects.id("BATTLE_ART_VOXEL_FORK",
    "signpost", id, 0, 0))
  for _, quad in ipairs(S.objectQuads) do
    equal(quad.visualObjectId, expected,
      "Structures annotates every sign quad with one stable object ID")
  end
  analyses[id] = S
  return map, expected
end

local current, currentId = annotatedMap("PALLET_TOWN")
local neighbor, neighborId = annotatedMap("ROUTE_1")
Structures.forMap = function(map) return analyses[map.id] end

local meshSequence = 0
local Voxel3D = {
  FORMAT = {}, FACE_CORNERS = {}, FACE_SHADE = {},
  pushQuad = function(indices, quad)
    local first = quad * 4 + 1
    for _, index in ipairs({ first, first + 1, first + 2,
                              first, first + 2, first + 3 }) do
      indices[#indices + 1] = index
    end
  end,
  newMesh = function(vertices, indices)
    meshSequence = meshSequence + 1
    return {
      id = meshSequence, vertices = vertices, indices = indices,
      release = function(self) self.released = true end,
    }
  end,
}
local MeshDisk = {
  available = function() return false end,
  legacy = function() return false end,
  loadTerrain = function() return nil end,
  saveTerrain = function() return false, "disabled in ROM-free test" end,
  loadAux = function() return nil end,
  saveAux = function() return false, "disabled in ROM-free test" end,
  purge = function() return true end,
}
local namespace = { companion = nil }
function namespace.require(name)
  return assert(({
    Structures = Structures, TileShape = TileShape, Voxel3D = Voxel3D,
    BuildBudget = Budget, VoxelMeshDisk = MeshDisk,
  })[name], "unexpected ChunkMesher module " .. tostring(name))
end
local ChunkMesher = assert(loadfile("lib/ChunkMesher.lua"))(namespace)

local currentFull = assert(ChunkMesher.get(current, false))
local currentBody = assert(ChunkMesher.get(current, true))
local neighborFull = assert(ChunkMesher.get(neighbor, false))
local neighborBody = assert(ChunkMesher.get(neighbor, true))
check(currentFull ~= currentBody and neighborFull ~= neighborBody,
  "full and body terrain variants are cached independently")
local beforeTerrain, _, beforeVisuals, beforeShadows = ChunkMesher.pair(current, false)
equal(beforeTerrain, currentFull, "the cached full terrain identity is stable")
equal(#(beforeVisuals or {}), 1, "the canonical color variant includes the sign")
equal(#(beforeShadows or {}), 1, "the canonical shadow variant includes the sign")

local cameraMode = "first_person"
local fakeVoxelState = {
  isFirstPerson = function() return cameraMode == "first_person" end,
  isThirdPerson = function() return cameraMode == "third_person" end,
}
local fakeShapes = {
  [0] = { class = "ground", h = 0 },
  [4] = { class = "signpost", h = 16 },
}
TileShape.forMap = function() return fakeShapes end
local fakeDayNight = {
  tod = function() return "DAY" end,
  time = function() return 12 end,
  isCanopy = function() return false end,
}
local fakeMat4 = {
  identity = function() return {} end,
  mul = function(a, b) return { a, b } end,
  translate = function() return {} end,
  scale = function() return {} end,
  rotateX = function() return {} end,
  rotateY = function() return {} end,
  rotateZ = function() return {} end,
}
local cleanMod = function()
  return {
    read = function() return "-- clean\n" end,
    log = { error = function() end, warn = function() end },
  }
end
local companionNamespace = { mod = cleanMod() }
function companionNamespace.require(name)
  return assert(({
    VoxelCompanionAPI = API, VoxelVisualObjects = VisualObjects,
    Mat4 = fakeMat4, TileShape = TileShape, ChunkMesher = ChunkMesher,
    VoxelState = fakeVoxelState, Voxel3D = Voxel3D, DayNight = fakeDayNight,
  })[name], "unexpected Companion module " .. tostring(name))
end
local VoxelCompanion = assert(loadfile("lib/VoxelCompanion.lua"))(companionNamespace)
love = {
  system = { getOS = function() return "Windows" end },
  graphics = { push = function() end, pop = function() end },
}

local host = VoxelCompanion.new({ mod = companionNamespace.mod })
namespace.companion = host
local owner, firstSignature, thirdSignature, replacementFrames
local callbackClaimed, callbackClaimError
replacementFrames = 0
owner = assert(host.provider.register({
  api = 1,
  id = "integration.owner",
  requires = { "visual_object_overrides", "world_snapshot", "render_phases" },
  worldChanged = function(snapshot)
    local rows, ids = {}, {}
    for _, descriptor in ipairs(snapshot.visualObjects) do
      ids[#ids + 1] = descriptor.id
      rows[#rows + 1] = table.concat({ descriptor.id, descriptor.map.id,
        descriptor.map.role, descriptor.map.offsetX, descriptor.map.offsetZ,
        descriptor.transform.localPosition.x,
        descriptor.transform.worldPosition.x }, "|")
    end
    local signature = table.concat(rows, "\n")
    if snapshot.mode == "first_person" then firstSignature = signature end
    if snapshot.mode == "third_person" then thirdSignature = signature end
    callbackClaimed, callbackClaimError = owner:claim_visual_objects(ids)
  end,
  render = {
    opaque_after_terrain = function() replacementFrames = replacementFrames + 1 end,
  },
}))
local player = { id = "player", px = 0, py = 0, cellX = 0, cellY = 0 }
local state = {
  map = current, player = player, entities = { player },
  neighbors = { { map = neighbor, ox = 64, oy = -32 } },
}
check(host:start(), "the integration host starts")
check(host:update(0.016, state), "first-person descriptors dispatch")
check(callbackClaimed, callbackClaimError
  or table.concat(host:status().diagnostics or {}, "; ")
  or "the integration callback claims objects")
check(host:suppressesVisualObject(currentId),
  "the accepted current-map claim becomes active")
check(host:suppressesVisualObject(neighborId),
  "the accepted neighbor-map claim becomes active")
local claimedTerrain, _, claimedVisuals, claimedShadows = ChunkMesher.pair(current, false)
equal(claimedTerrain, beforeTerrain,
  "claim activation keeps the selected cached terrain identity")
equal(#(claimedVisuals or {}), 0,
  "claim activation removes the original color sidecar immediately")
equal(#(claimedShadows or {}), 1,
  "claim activation preserves the original shadow caster")
check(host:render("opaque_after_terrain", state),
  "the replacement renders through the bounded opaque phase")
equal(replacementFrames, 1,
  "the replacement starts only with the override color variant selected")

local contender = assert(host.provider.register({
  api = 1, id = "integration.rejected",
  render = { opaque_after_terrain = function() end },
}))
local conflict, conflictError = contender:claim_visual_objects({ currentId })
equal(conflict, nil, "a conflicting owner is rejected")
contains(conflictError, "ownership conflict", "conflict rejection is diagnostic")
equal(#(select(3, ChunkMesher.pair(current, false)) or {}), 0,
  "conflict rejection does not change the selected override variant")
local duplicate, duplicateError = owner:claim_visual_objects({ currentId, currentId })
equal(duplicate, nil, "a duplicate claim call is rejected")
contains(duplicateError, "duplicate id", "duplicate rejection is diagnostic")
equal(#(select(3, ChunkMesher.pair(neighbor, true)) or {}), 0,
  "duplicate rejection preserves every accepted map claim")

cameraMode = "third_person"
host:worldChanged("third-person-identity")
check(host:update(0.016, state), "third-person descriptors dispatch")
equal(thirdSignature, firstSignature,
  "first- and third-person read the same map, neighbor, ID, and transform identity")

check(owner:invalidate({}, "integration-invalidate"), "owner invalidation succeeds")
local invalidatedTerrain, _, invalidatedVisuals, invalidatedShadows =
  ChunkMesher.pair(current, false)
equal(invalidatedTerrain, beforeTerrain,
  "invalidation restores without a terrain rebuild or future pump")
equal(#(invalidatedVisuals or {}), 1,
  "invalidation restores the original color sidecar immediately")
equal(#(invalidatedShadows or {}), 1,
  "invalidation keeps the original shadow behavior")
check(not host:suppressesVisualObject(currentId),
  "the rejected conflict does not become a future owner")
check(contender:dispose({}, "integration-rejected-dispose"),
  "the rejected contender disposes cleanly")

check(owner:claim_visual_objects({ currentId, neighborId }),
  "the accepted owner can reclaim both cached map identities")
check(owner:dispose({}, "integration-owner-dispose"), "owner disposal succeeds")
local disposedTerrain, _, disposedVisuals, disposedShadows =
  ChunkMesher.pair(current, false)
equal(disposedTerrain, beforeTerrain,
  "disposal restores without a terrain rebuild or future pump")
equal(#(disposedVisuals or {}), 1,
  "disposal restores the original color sidecar immediately")
equal(#(disposedShadows or {}), 1,
  "disposal keeps the original shadow behavior")
check(host:dispose("integration-host-dispose"), "the integration host disposes")

print(("%d checks passed (visual-object cache transition integration)"):format(checks))
