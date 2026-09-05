-- TEST46: corrected readable sign + visible cut-tree port into Battle Art.

local function read(path)
  local f = assert(io.open(path, "rb"))
  local source = f:read("*a")
  f:close()
  return source
end

-- New options follow Battle Art's normal A/B convention and invalidate live.
local ModSetting = {}
function ModSetting.new(key, label, values, labels)
  local self = { key = key, label = label, values = values, labels = labels,
                 index = 1 }
  function self:get() return self.values[self.index] end
  function self:row()
    return { step = function() return true end }
  end
  return self
end
local CV = assert(loadfile("lib/CommunityVisuals.lua"))({
  require = function(name)
    if name == "ModSetting" then return ModSetting end
    return { invalidate = function() end }
  end,
})
assert(CV.cutTrees.label == "CUT TREES" and CV.signs.label == "SIGNS")
assert(not CV.customCutTrees() and not CV.customSigns(),
       "new props must preserve Battle Art defaults")
CV.cutTrees.index, CV.signs.index = 2, 2
assert(CV.customCutTrees() and CV.customSigns(),
       "Legendary world-prop choices did not enable")

-- The corrected sign frame must supplement, never claim, the authored face.
package.preload["src.render.Assets"] = function()
  return { imageData = function() return nil end,
           register = function() end }
end
package.preload["src.world.Map"] = function()
  return { isOutdoor = function() return true end }
end
local visualSwitches = {
  customSigns = function() return true end,
  customCourtyards = function() return false end,
  customPillars = function() return false end,
  customTrees = function() return false end,
  customCutTrees = function() return true end,
}
local V = {}
function V.require(name)
  return assert(({
    Buildings = {}, TileShape = {}, BuildBudget = { tick = function() end },
    VoxelVisualObjects = { id = function() return "sign" end },
    CommunityVisuals = visualSwitches,
  })[name], name)
end
local Structures = assert(loadfile("lib/Structures.lua"))(V)
local function keyOf(tx, ty) return (ty + 64) * 4096 + (tx + 64) end
local S = { shapeAt = {}, tileAt = {}, skip = {}, ground = {}, objectQuads = {} }
for ty = 0, 1 do
  for tx = 0, 1 do
    S.shapeAt[keyOf(tx, ty)] = { art = "billboard", class = "signpost" }
    S.tileAt[keyOf(tx, ty)] = 70 + tx + ty * 16
  end
end
local map = { tileset = { id = "OVERWORLD", tilesPerRow = 16 } }
local data = { getDimensions = function() return 128, 48 end }
assert(Structures.buildLegendarySigns(S, map, 0, 1, 0, 1, data))
assert(#S.objectQuads == 30, "corrected six-piece timber frame changed")
for ty = 0, 1 do
  for tx = 0, 1 do
    assert(not S.skip[keyOf(tx, ty)] and S.ground[keyOf(tx, ty)] == nil,
           "timber frame stole the readable authored sign")
  end
end
for _, quad in ipairs(S.objectQuads) do
  assert(quad.legendarySign, "unmarked geometry escaped sign builder")
end

-- Cut-tree tiles stay Battle Art props until the new option is selected.
local customCutTree = false
local V2 = {}
function V2.require(name)
  assert(name == "CommunityVisuals")
  return { customCutTrees = function() return customCutTree end }
end
function V2.data(name)
  assert(name == "voxel_heights")
  return {
    heights = { prop = 16, sapling = 16 },
    tilesets = { OVERWORLD = {
      prop = { 45, 46, 61, 62 },
      sapling_tiles = { 45, 46, 61, 62 },
    } },
  }
end
local TileShape = assert(loadfile("lib/TileShape.lua"))(V2)
local tileMap = {
  id = "ROUTE_2", tileset = {
    id = "OVERWORLD", imageWidth = 128, imageHeight = 48,
    animatedTiles = {},
  },
  waterTiles = {}, walkable = {},
  isWaterCell = function() return false end,
  isWalkableCell = function() return false end,
  tileAt = function() return 45 end,
}
local shapes = TileShape.forMap(tileMap)
assert(TileShape.at(tileMap, shapes, 45, 0, 0).class == "prop",
       "Battle Art cut-tree default changed")
customCutTree = true
assert(TileShape.at(tileMap, shapes, 45, 0, 0).class == "sapling",
       "Legendary cut tree did not enter round ownership")

local structures = read("lib/Structures.lua")
local flora = read("lib/CommunityFlora.lua")
local mesher = read("lib/ChunkMesher.lua")
local cache = read("lib/VoxelMeshDisk.lua")
local main = read("main.lua")
local manifest = read("manifest.json")
assert(structures:find("rounds[mapKey][cx .. \"|\" .. cy] = lift", 1, true)
       and structures:find("stamp.communityTree = true", 1, true)
       and structures:find("stamp.hideCrown = true", 1, true),
       "cut-tree registry/base handoff is incomplete")
assert(flora:find("MOUND.SAPLING_TILES", 1, true)
       and flora:find("OVERWORLD = { [45] = true, [46] = true, [61] = true, [62] = true }", 1, true)
       and flora:find("for k in pairs(s or {}) do u[k] = true end", 1, true),
       "TEST455 sapling visibility allow-list is incomplete")
assert(mesher:find("or CommunityVisuals.customCutTrees()", 1, true),
       "cut trees may incorrectly restore from disk without registry ownership")
assert(cache:find("Disk.CACHE_REVISION = 25", 1, true)
       and cache:find("CommunityVisuals.cutTrees:get()", 1, true)
       and cache:find("CommunityVisuals.signs:get()", 1, true),
       "world-prop cache separation is incomplete")
assert(main:find("CommunityVisuals.cutTrees", 1, true)
       and main:find("CommunityVisuals.signs", 1, true),
       "WORLD menu rows are missing")
assert(manifest:find('"version": "1.10.0-test49-select-camera-log-hotfix-compat253"', 1, true)
       and manifest:find("TEST49 Select Camera Crash Fix", 1, true),
       "TEST49 derivative package identity is missing")

print("TEST46 legendary world props: defaults, readable sign and visible cut tree locked")
