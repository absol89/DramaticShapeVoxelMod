-- Regression coverage for the two overworld fixes that are easiest to
-- accidentally undo: rear building walls must not mirror facade doors, and
-- a first-time 32px canopy carve must cooperate with the frame build budget.

package.path = "./?.lua;./?/init.lua;" .. package.path

local T = require("tests.harness")
local MOD_PATH = os.getenv("DS_MOD_PATH") or "mods/DramaticShapeVoxelMod"
local ROOT = os.getenv("DS_REPO_ROOT") or "."
local base = ROOT .. "/" .. MOD_PATH
local modules, dataFiles = {}, {}
local V = {}
function V.require(name)
  if modules[name] ~= nil then return modules[name] end
  local value = assert(loadfile(base .. "/lib/" .. name .. ".lua"))(V)
  modules[name] = value
  return value
end
function V.data(name)
  if dataFiles[name] ~= nil then return dataFiles[name] end
  local value = assert(loadfile(base .. "/data/" .. name .. ".lua"))(V)
  dataFiles[name] = value
  return value
end
local Buildings = V.require("Buildings")
local Structures = V.require("Structures")
local Budget = V.require("BuildBudget")

local function upvalue(fn, wanted)
  for i = 1, 100 do
    local name, value = debug.getupvalue(fn, i)
    if not name then break end
    if name == wanted then return value end
  end
  return nil
end

local function setUpvalue(fn, wanted, value)
  for i = 1, 100 do
    local name = debug.getupvalue(fn, i)
    if not name then break end
    if name == wanted then
      debug.setupvalue(fn, i, value)
      return true
    end
  end
  return false
end

local spec = V.data("voxel_heights")
local donors = spec.building_back_tiles and spec.building_back_tiles.OVERWORLD
local rearTemplates = spec.building_back_templates
                      and spec.building_back_templates.OVERWORLD
T.eq(donors and donors[11] and donors[11][1], 10,
  "an upper facade door samples the plain upper wall on the rear face")
T.eq(donors and donors[12] and donors[12][1], 10,
  "both upper door halves have a rear-wall donor")
T.eq(donors and donors[27], 26,
  "a lower facade door samples the plain base course on the rear face")
T.eq(donors and donors[28], 26,
  "both lower door halves have a rear-wall donor")
T.check(rearTemplates and rearTemplates.gabled_house
    and rearTemplates.oaks_lab and rearTemplates.pokecenter
    and rearTemplates.pokemart,
  "doorless backs are enabled for the requested exterior building families")
T.check(not (spec.building_back_tiles and spec.building_back_tiles.HOUSE)
    and not (spec.building_back_templates and spec.building_back_templates.HOUSE)
    and not (spec.building_back_tiles and spec.building_back_tiles.POKECENTER),
  "interior house and Pokemon Center model tilesets are untouched")

-- Exercise the actual model lookup, not only its profile.  A one-tile black
-- facade is a sealed solid in the silhouette reader.  On its south face the
-- atlas x coordinate remains tile 11; on its north face it must be tile 10.
local read = upvalue(Buildings.build, "read")
local measure = upvalue(Buildings.build, "measure")
local model = upvalue(Buildings.build, "model")
T.check(read and measure and model,
  "the building pipeline exposes its reader/model as build upvalues")
if read and measure and model then
  local pixels = { getPixel = function() return 0, 0, 0, 1 end }
  local template = {
    tiles = { { 11 } }, roofRows = 0, roofBack = 0, roofFront = 0,
    roofCycle = { 0, 0 }, slab = 1, panes = false, depth = 1,
  }
  local sprite = read(template, pixels, 16, donors)
  local measured = measure(sprite, template)
  local shape = model(sprite, measured, template)
  local front = shape.at(3, 0, 7)
  local rear = shape.at(3, 0, 0)
  T.eq(math.floor(sprite.ax[front] / 8), 11,
    "the south facade keeps the authored door tile")
  T.eq(math.floor(sprite.ax[rear] / 8), 10,
    "the north face substitutes the doorless wall tile")
end

-- The canopy template used to run from pixel classification through all
-- voxel faces without one budget call.  Give it an already-expired slice:
-- it must yield before completing instead of holding input until the entire
-- hull is finished.  Existing visual/probe coverage owns the final geometry;
-- this focused test owns the newly restored scheduling contract.
local roundTemplate = upvalue(Structures.buildCylinders, "roundTemplate")
T.check(roundTemplate ~= nil,
  "the cylinder builder retains the shared round-template generator")
if roundTemplate then
  local tileAt = setmetatable({}, { __index = function() return 11 end })
  local scene = { tileAt = tileAt }
  local map = { tileset = {
    id = "OVERWORLD", tilesPerRow = 16,
    imageWidth = 128, imageHeight = 48,
  } }
  local pixels = {
    getPixel = function(_, x, y)
      -- Small closed motifs exercise every stage of the 32px path without
      -- constructing a pathological solid 32^3 test ball.
      local lx, ly = x % 8, y % 8
      if lx >= 2 and lx <= 5 and ly >= 2 and ly <= 5 then
        return 0, 0, 0, 1
      end
      return 1, 1, 1, 1
    end,
  }
  local co = coroutine.create(function()
    return roundTemplate(scene, map, pixels, 0, 0, {}, 32,
                         nil, nil, nil, nil, nil, nil, nil, true)
  end)
  Budget.begin(co, -1)
  local ok, reason = coroutine.resume(co)
  Budget.finish()
  T.check(ok and reason == "budget" and coroutine.status(co) == "suspended",
    "a first-time 32px canopy yields when its frame slice is exhausted")
  -- Resume past the first cooperative yield. This catches positional optional
  -- arguments reaching their numeric branches (the production canopy once
  -- passed pinBase=true as taperVox and failed only after this yield).
  while ok and coroutine.status(co) ~= "dead" do
    Budget.begin(co, 1000)
    ok, reason = coroutine.resume(co)
    Budget.finish()
  end
  T.check(ok and coroutine.status(co) == "dead",
    "the 32px canopy completes with pinBase in its intended argument slot")

end

-- A warp destination is not a connected neighbour, so on a cold entry neither
-- mesh slot exists.  VoxelScene must request the useful body first, then FULL
-- (which promotes that body job); and its held-frame helper may only answer for
-- the map whose pixels the canvas actually contains.
do
  local requests = {}
  local chunk = {
    setLive = function() end,
    pair = function() return nil, nil end,
    slotKnown = function() return false end,
    request = function(map, bodyOnly)
      requests[#requests + 1] = { map = map, body = bodyOnly }
    end,
  }
  local sceneVoxel = {}
  local sceneModules = setmetatable({
    ChunkMesher = chunk,
    TerrainAtlas = { setLive = function() end },
    VoxelState = sceneVoxel,
    RenderDistance = { neighbor = function() return false end },
    GranitePillars = { invalidate = function() end },
    CommunityFlora = {
      invalidate = function() end,
      shadowSignature = function() return "" end,
      castShadows = function() end,
      drawCommunityTrees = function() end,
    },
    ModSetting = { new = function(_, _, values)
      return { get = function() return values[1] end }
    end },
  }, { __index = function() return {} end })
  local SceneV = { require = function(name) return sceneModules[name] end }
  local sceneChunk = assert(loadfile(base .. "/lib/VoxelScene.lua"))
  local VoxelScene = sceneChunk(SceneV)
  local forest = { id = "VIRIDIAN_FOREST", def = { width = 1, height = 1 } }
  VoxelScene.prefetch({ map = forest, neighbors = {}, player = {} })
  T.check(requests[1] and requests[1].body == true
      and requests[2] and requests[2].body == false,
    "a cold warp queues the current body before the full border-ring mesh")

  local heldFrame = upvalue(VoxelScene.render, "heldFrame")
  local canvas = { getDimensions = function() return 320, 240 end }
  T.check(heldFrame
      and setUpvalue(heldFrame, "lastCompleteCanvas", canvas)
      and setUpvalue(heldFrame, "lastCompleteW", 320)
      and setUpvalue(heldFrame, "lastCompleteH", 240)
      and setUpvalue(heldFrame, "lastCompleteMapId", "ROUTE_2"),
    "the held-frame map identity is retained beside its canvas")
  if heldFrame then
    T.eq(heldFrame(320, 240, "ROUTE_2"), canvas,
      "the same map may temporarily reuse its complete voxel frame")
    T.eq(heldFrame(320, 240, "VIRIDIAN_FOREST"), nil,
      "Viridian Forest cannot reuse the adjacent map's exit frame")
  end
end

if T.failures > 0 then
  error(("building/canopy regressions: %d failure(s)"):format(T.failures))
end
print(("PASS building/canopy regressions (%d checks)"):format(T.checks))
