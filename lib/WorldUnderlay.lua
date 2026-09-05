-- One cheap, curved floor beneath the loaded voxel neighborhood.
--
-- The terrain remains authoritative: this mesh is drawn first at Y=-20 with
-- depth writes, so ordinary ground, recessed water and every structure cover
-- it naturally. Only literal holes expose it -- and sitting 20 units down (not
-- at foot level) the fill reads as a shaft dropping away through the hole
-- rather than a flat puddle filling the gap. Coarse tessellation is required
-- because V-CURVE bends vertices; one four-corner quad would remain two flat
-- triangles between its corners.

local V = ...

local Map = require("src.world.Map")
local TileRenderer = require("src.render.TileRenderer")

local Voxel3D = V.require("Voxel3D")
local Mat4 = V.require("Mat4")
local ModSetting = V.require("ModSetting")
local TerrainAtlas = V.require("TerrainAtlas")
local biomes = V.data("world_fill_biomes")

local WorldUnderlay = {}

local STEP = 32
local RANGE = 32768
local HEIGHT = -20

WorldUnderlay.setting = ModSetting.new(
  "worldFill", "WORLD FILL",
  { "cyan", "black", "off", "nature" },
  { "CYAN", "BLACK", "OFF/KFP", "NATURE" })

local COLORS = {
  cyan  = {   0 / 255,  71 / 255, 109 / 255, 1 }, -- #00476D
  black = {  24 / 255,  24 / 255,  24 / 255, 1 }, -- #181818
  cave  = {  18 / 255,  12 / 255,  12 / 255, 1 }, -- deep earth below shafts
}

local DEFAULT_FILL = "cyan"

local cachedMesh = nil
local textures = {}

function WorldUnderlay.selected()
  return WorldUnderlay.setting:get() or DEFAULT_FILL
end

function WorldUnderlay.enabled()
  return WorldUnderlay.selected() ~= "off"
end

function WorldUnderlay.natureEnabled()
  return WorldUnderlay.selected() == "nature"
end

-- Dense where the camera can inspect the curve, increasingly coarse after
-- each doubled radius. A solid material has no texture scale to reveal those
-- outer cells, and V-CURVE has already carried them below the horizon.
local function axis()
  local positive, p, step, band = { 0 }, 0, STEP, 512
  while p < RANGE do
    p = math.min(RANGE, p + step)
    positive[#positive + 1] = p
    if p >= band then
      step = math.min(step * 2, 2048)
      band = band * 2
    end
  end
  local out = {}
  for i = #positive, 2, -1 do out[#out + 1] = -positive[i] end
  for i = 1, #positive do out[#out + 1] = positive[i] end
  return out
end

local function meshFor()
  if cachedMesh then return cachedMesh end
  local verts, indices = {}, {}
  local points = axis()
  local columns, rows = #points - 1, #points - 1
  for z = 1, #points do
    for x = 1, #points do
      verts[#verts + 1] = { points[x], HEIGHT, points[z], 0.5, 0.5, 1 }
    end
  end
  local stride = columns + 1
  for z = 0, rows - 1 do
    for x = 0, columns - 1 do
      local a = z * stride + x + 1
      indices[#indices + 1] = a
      indices[#indices + 1] = a + 1
      indices[#indices + 1] = a + stride + 1
      indices[#indices + 1] = a
      indices[#indices + 1] = a + stride + 1
      indices[#indices + 1] = a + stride
    end
  end
  cachedMesh = Voxel3D.newMesh(verts, indices)
  return cachedMesh
end

local function colorKey(color)
  return ("%.6f,%.6f,%.6f,%.6f"):format(
    color[1] or 0, color[2] or 0, color[3] or 0, color[4] or 1)
end

local function textureFor(color)
  local key = colorKey(color)
  if textures[key] then return textures[key] end
  if not (love and love.image and love.image.newImageData
          and love.graphics and love.graphics.newImage) then return nil end
  local ok, texture = pcall(function()
    local data = love.image.newImageData(1, 1)
    data:setPixel(0, 0, unpack(color))
    local image = love.graphics.newImage(data)
    image:setFilter("nearest", "nearest")
    return image
  end)
  if ok then textures[key] = texture end
  return ok and texture or nil
end

-- Resolve the underlay BEFORE Voxel3D.beginScene binds the scene shader/canvas.
-- Outdoors keeps the explicit WORLD FILL material. Indoors instead follows the
-- map's own border block, because the engine's three-block void ring is the
-- authored room boundary and a perspective camera can see beyond it.
function WorldUnderlay.resolve(state, colors)
  if not WorldUnderlay.enabled() then return nil, "world:off" end
  local map = state and state.map
  local mapId = map and (map.id or (map.def and map.def.id))
  if map and map.tileset and map.tileset.id == "CAVERN" then
    return COLORS.cave, "cave:earth"
  end
  if WorldUnderlay.selected() == "nature"
      and biomes.black and biomes.black[mapId] then
    return COLORS.black, "nature:black"
  end
  if map and map.def and not Map.isOutdoor(map.def) then
    local borderId = TileRenderer.borderBlockFor(map)
    if borderId == false then return { 0, 0, 0, 1 }, "indoor:black" end
    local color = TerrainAtlas.borderBlockColor(map, colors, borderId)
    if color then return color, "indoor:border:" .. tostring(borderId) end
  end
  local material = WorldUnderlay.selected()
  if material == "nature" then material = "cyan" end
  return COLORS[material] or COLORS[DEFAULT_FILL], "world:" .. tostring(material)
end

function WorldUnderlay.draw(state, cx, cy, resolvedColor)
  if not state or not WorldUnderlay.enabled() then return false end
  local material = WorldUnderlay.selected()
  if material == "nature" then material = "cyan" end
  local color = resolvedColor or COLORS[material] or COLORS[DEFAULT_FILL]
  local mesh, texture = meshFor(), textureFor(color)
  if not (mesh and texture) then return false end
  -- A clean material layer: no voxel-grid seams or accidental glass-mask
  -- sampling. Drawn unlit so it never receives the sun's cast/self shadow
  -- (the inner border must not drop a shadow onto the outer fill).
  Voxel3D.lighting(false)
  Voxel3D.seams(false)
  Voxel3D.glass(false)
  -- The untextured plane follows the camera focus exactly. Its 65K-wide edge
  -- therefore stays beyond the practical far plane forever, without making a
  -- new GPU mesh at a map boundary or visibly sliding any pattern underfoot.
  Voxel3D.draw(mesh, texture, Mat4.translate(cx or 0, 0, cy or 0))
  Voxel3D.glass(true)
  Voxel3D.seams(true)
  Voxel3D.lighting(true)
  return true
end

WorldUnderlay.COLORS = COLORS
WorldUnderlay.HEIGHT = HEIGHT
WorldUnderlay.STEP = STEP
WorldUnderlay.RANGE = RANGE

return WorldUnderlay
