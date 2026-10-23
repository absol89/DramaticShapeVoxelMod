-- Restrained reception detailing for Pokemon Tower 1F.
-- The authored counter remains the approved pearl/black granite mesh. This
-- pass adds only a hairline aged-brass rim along its exposed top edges, giving
-- the otherwise empty lobby a warm focal accent without changing collision,
-- counter proportions or any source material.

local V = ...

local Assets = require("src.render.Assets")
local Voxel3D = V.require("Voxel3D")
local Structures = V.require("Structures")
local TowerFogSettings = V.require("TowerFogSettings")

local Detail = {}
local cache = setmetatable({}, { __mode = "k" })
local whiteImg

local function keyOf(tx, ty) return (ty + 64) * 4096 + (tx + 64) end

local function isLobby(map)
  return map and map.tileset and map.tileset.id == "CEMETERY"
    and tostring(map.id or ""):upper() == "POKEMON_TOWER_1F"
end

local function white()
  if whiteImg then return whiteImg end
  local ok, img = pcall(function()
    local data = love.image.newImageData(2, 2)
    for y = 0, 1 do for x = 0, 1 do
      data:setPixel(x, y, 1, 1, 1, 1)
    end end
    local made = love.graphics.newImage(data)
    made:setFilter("nearest", "nearest")
    return made
  end)
  if ok then whiteImg = img end
  return whiteImg
end

local function group() return { verts = {}, indices = {}, quads = 0 } end

local function quad(g, a, b, c, d, shade)
  local s = shade or 1
  g.verts[#g.verts + 1] = { a[1], a[2], a[3], 0, 0, s }
  g.verts[#g.verts + 1] = { b[1], b[2], b[3], 1, 0, s }
  g.verts[#g.verts + 1] = { c[1], c[2], c[3], 1, 1, s }
  g.verts[#g.verts + 1] = { d[1], d[2], d[3], 0, 1, s }
  Voxel3D.pushQuad(g.indices, g.quads)
  g.quads = g.quads + 1
end

local function box(g, x0, y0, z0, x1, y1, z1)
  quad(g,{x1,y0,z0},{x1,y0,z1},{x1,y1,z1},{x1,y1,z0},.86)
  quad(g,{x0,y0,z1},{x0,y0,z0},{x0,y1,z0},{x0,y1,z1},.67)
  quad(g,{x0,y1,z0},{x1,y1,z0},{x1,y1,z1},{x0,y1,z1},1.08)
  quad(g,{x0,y0,z1},{x1,y0,z1},{x1,y0,z0},{x0,y0,z0},.58)
  quad(g,{x0,y0,z1},{x1,y0,z1},{x1,y1,z1},{x0,y1,z1},.94)
  quad(g,{x1,y0,z0},{x0,y0,z0},{x0,y1,z0},{x1,y1,z0},.73)
end

local function build(map)
  local g = group()
  if not isLobby(map) then return { mesh = nil } end
  local S = Structures.forMap(map)
  local tw = ((map.def and map.def.width) or 1) * 4
  local th = ((map.def and map.def.height) or 1) * 4

  local function counter(tx, ty)
    if tx < 0 or ty < 0 or tx >= tw or ty >= th then return false end
    local k = keyOf(tx, ty)
    local s = S.shapeAt[k]
    return s and s.class == "counter" and not S.skip[k]
  end

  local y0, y1 = 8.04, 8.46
  local half = .24
  for ty = 0, th - 1 do
    for tx = 0, tw - 1 do
      if counter(tx, ty) then
        local x0, z0 = tx * 8, ty * 8
        local x1, z1 = x0 + 8, z0 + 8
        if not counter(tx, ty - 1) then
          box(g, x0, y0, z0 - half, x1, y1, z0 + half)
        end
        if not counter(tx, ty + 1) then
          box(g, x0, y0, z1 - half, x1, y1, z1 + half)
        end
        if not counter(tx - 1, ty) then
          box(g, x0 - half, y0, z0, x0 + half, y1, z1)
        end
        if not counter(tx + 1, ty) then
          box(g, x1 - half, y0, z0, x1 + half, y1, z1)
        end
      end
    end
  end
  return { mesh = Voxel3D.newMesh(g.verts, g.indices) }
end

local function drawMap(map)
  if not isLobby(map) then return false end
  -- TEST174: the authored lobby (InteriorRooms) has its own counter trim
  do
    local okI, own = pcall(function() return V.require("InteriorRooms").accepts(map) end)
    if okI and own then return false end
  end
  -- The brass reception accent belongs to FULL; SUBTLE is the restrained
  -- high-sconce treatment and OFF draws no added Tower detail pass.
  if TowerFogSettings.detailsLevel() ~= "full" then return false end
  local slot = cache[map]
  if not slot then slot = build(map); cache[map] = slot end
  local img = white()
  if not (slot.mesh and img) then return false end
  local g = love.graphics
  local pushed = g and g.push and pcall(g.push, "all")
  pcall(function()
    g.setDepthMode("lequal", true)
    g.setBlendMode("alpha")
    g.setColor(.48, .33, .105, 1)
    Voxel3D.draw(slot.mesh, img, nil, .45)
  end)
  if pushed then pcall(g.pop) end
  return true
end

function Detail.draw(state) return drawMap(state and state.map) end
function Detail.drawBattle(map) return drawMap(map) end

function Detail.invalidate()
  for _, slot in pairs(cache) do
    if slot.mesh and slot.mesh.release then pcall(slot.mesh.release, slot.mesh) end
  end
  cache = setmetatable({}, { __mode = "k" })
  if whiteImg and whiteImg.release then pcall(whiteImg.release, whiteImg) end
  whiteImg = nil
end

Assets.register(Detail.invalidate)

return Detail
