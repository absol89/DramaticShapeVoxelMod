-- Legendary Visuals Pokemon Tower exterior.
--
-- The stock Battle Art exterior is a faithful voxelization of Gen 1's authored
-- building drawing. Legendary's Tower option, however, promises a different
-- Gothic silhouette. Keep the ROM footprint/collision/warps untouched and draw
-- this presentation-only mesh at the exact pokemon_tower placement.
local V = ...
local Voxel3D = V.require("Voxel3D")
local Mat4 = V.require("Mat4")
local CommunityVisuals = V.require("CommunityVisuals")

local M = {}

-- The eight Lavender rows used by data/voxel_heights.lua's pokemon_tower
-- placement. The final guard id is placement-only; the rendered footprint is
-- the first twelve tiles (96 world pixels) wide.
local BODY = {
  {15,10,10,10,10,10,10,10,10,10,10,31},
  {15,75,75,75,75,75,75,75,75,75,75,31},
  {15,10,10,10,10,10,10,10,10,10,10,31},
  {15,75,75,75,75,75,75,75,75,75,75,31},
  {15,10,10,10,10,10,10,10,10,10,10,31},
  {15,75,75,75,75,75,75,75,75,75,75,31},
  {15,75,75,75,75,75,75,75,75,75,75,31},
  {78,26,26,26,26,26,26,26,26,26,26,79,17},
}

local mesh, texture, textureStyle
local placements = setmetatable({}, { __mode = "k" })

local function sameTile(map, x, y, id)
  if type(map.tileAt) ~= "function" then return false end
  local ok, got = pcall(map.tileAt, map, x, y)
  return ok and got == id
end

function M.detect(map)
  if not map or tostring(map.id or ""):upper() ~= "LAVENDER_TOWN"
      or not map.tileset or map.tileset.id ~= "OVERWORLD" then return nil end
  local cached = placements[map]
  if cached ~= nil then return cached or nil end
  local def = map.def or {}
  local tw, th = (tonumber(def.width) or 0) * 4, (tonumber(def.height) or 0) * 4
  if tw <= 0 or th <= 0 then placements[map] = false; return nil end
  local widest = 0
  for _, row in ipairs(BODY) do widest = math.max(widest, #row) end
  for ty = 0, th - #BODY do
    for tx = 0, tw - widest do
      local hit = true
      for r, row in ipairs(BODY) do
        for c, id in ipairs(row) do
          if not sameTile(map, tx + c - 1, ty + r - 1, id) then
            hit = false; break
          end
        end
        if not hit then break end
      end
      if hit then
        cached = { tx = tx, ty = ty, width = 12, height = 8 }
        placements[map] = cached
        return cached
      end
    end
  end
  placements[map] = false
  return nil
end

function M.activeFor(map, template)
  return CommunityVisuals.customTower()
    and template and template.id == "pokemon_tower"
    and tostring(map and map.id or ""):upper() == "LAVENDER_TOWN"
    and M.detect(map) ~= nil
end

local function uv(slot, n)
  return { (slot + 0.5) / n, 0.5 }
end

function M.geometry()
  local vertices, indices = {}, {}
  local N = 8
  local function vertex(p, slot, shade)
    local t = uv(slot, N)
    vertices[#vertices + 1] = { p[1], p[2], p[3], t[1], t[2], shade or 1 }
    return #vertices
  end
  local function quad(a,b,c,d,slot,shade)
    local n = #vertices
    vertex(a,slot,shade); vertex(b,slot,shade); vertex(c,slot,shade); vertex(d,slot,shade)
    indices[#indices+1]=n+1; indices[#indices+1]=n+2; indices[#indices+1]=n+3
    indices[#indices+1]=n+1; indices[#indices+1]=n+3; indices[#indices+1]=n+4
  end
  local function tri(a,b,c,slot,shade)
    local n = #vertices
    vertex(a,slot,shade); vertex(b,slot,shade); vertex(c,slot,shade)
    indices[#indices+1]=n+1; indices[#indices+1]=n+2; indices[#indices+1]=n+3
  end
  local function box(x0,y0,z0,x1,y1,z1,slot,front)
    quad({x0,y0,z0},{x1,y0,z0},{x1,y1,z0},{x0,y1,z0},slot,.78)
    if front ~= false then quad({x1,y0,z1},{x0,y0,z1},{x0,y1,z1},{x1,y1,z1},slot,1.00) end
    quad({x0,y0,z1},{x0,y0,z0},{x0,y1,z0},{x0,y1,z1},slot,.84)
    quad({x1,y0,z0},{x1,y0,z1},{x1,y1,z1},{x1,y1,z0},slot,.90)
    quad({x0,y1,z0},{x1,y1,z0},{x1,y1,z1},{x0,y1,z1},slot,1.08)
  end
  local function roof(x0,z0,x1,z1,y0,y1)
    local cx,cz=(x0+x1)/2,(z0+z1)/2
    -- low square hip transitioning into a steep Gothic point
    quad({x0,y0,z0},{x1,y0,z0},{x1,y0,z1},{x0,y0,z1},3,.72)
    tri({x0,y0,z1},{x1,y0,z1},{cx,y1,cz},4,1.05)
    tri({x1,y0,z1},{x1,y0,z0},{cx,y1,cz},3,.88)
    tri({x1,y0,z0},{x0,y0,z0},{cx,y1,cz},3,.76)
    tri({x0,y0,z0},{x0,y0,z1},{cx,y1,cz},4,.94)
  end
  local function trim(x0,z0,x1,z1,y,h)
    box(x0-1,y,z0-1,x1+1,y+h,z1+1,2)
  end
  local function windowFront(x0,x1,y0,y1,z)
    quad({x1,y0,z},{x0,y0,z},{x0,y1,z},{x1,y1,z},5,1.0)
    local ix0,ix1=x0+2,x1-2
    local mid=(y0+y1)/2
    if ix1>ix0 then
      quad({ix1,mid-1,z+.02},{ix0,mid-1,z+.02},{ix0,mid+1,z+.02},{ix1,mid+1,z+.02},6,1.0)
    end
  end
  local function roundWindow(cx,cy,z,r)
    local center = {cx,cy,z}
    for i=0,7 do
      local a=i*math.pi/4+math.pi/8
      local b=(i+1)*math.pi/4+math.pi/8
      tri(center,
          {cx+math.cos(a)*r,cy+math.sin(a)*r,z},
          {cx+math.cos(b)*r,cy+math.sin(b)*r,z},5,1)
    end
    local r2=r*.55
    for i=0,7 do
      local a=i*math.pi/4+math.pi/8
      local b=(i+1)*math.pi/4+math.pi/8
      tri(center,
          {cx+math.cos(a)*r2,cy+math.sin(a)*r2,z+.03},
          {cx+math.cos(b)*r2,cy+math.sin(b)*r2,z+.03},6,1)
    end
  end

  -- Lower mausoleum mass: full source footprint, but split front wall around
  -- the authored centre entrance so walking into the warp still reads as a door.
  box(0,0,0,96,64,64,0,false)
  box(0,0,63.9,40,64,64,0)
  box(56,0,63.9,96,64,64,0)
  box(40,24,63.9,56,64,64,0)
  quad({56,0,64.05},{40,0,64.05},{40,24,64.05},{56,24,64.05},7,1)
  trim(0,0,96,64,62,4)

  -- Three connected Gothic tower masses. The centre tower is tallest, with
  -- slightly lower flanking towers like the Legendary reference model.
  box(24,64,8,72,140,56,0)
  trim(24,8,72,56,88,3)
  trim(24,8,72,56,116,3)
  roof(22,6,74,58,140,170)

  box(0,58,14,32,116,50,1)
  trim(0,14,32,50,82,3)
  roof(-2,12,34,52,116,140)

  box(64,60,14,96,124,50,1)
  trim(64,14,96,50,86,3)
  roof(62,12,98,52,124,150)

  -- Narrow corner buttresses and repeated dark lancet windows.
  for _, x in ipairs({2,18,76,92}) do box(x,0,58,x+3,86,66,2) end
  for _, x in ipairs({28,42,56,68}) do
    windowFront(x,x+8,76,91,56.05)
    windowFront(x,x+8,100,115,56.05)
  end
  for _, x in ipairs({5,17,69,81}) do windowFront(x,x+7,68,82,50.05) end
  roundWindow(48,128,56.08,7)

  -- TEST61: dressed black masonry and stone window heads, same silhouette.
  if CommunityVisuals.referenceBuildings() then
  for _,x in ipairs({2,18,76,92})do
    for y=4,80,6 do box(x-.25,y,65.8,x+3.25,y+.45,66.35,2)end
  end
  for _,x in ipairs({28,42,56,68})do
    for _,y in ipairs({91,115})do box(x-.5,y,56.1,x+8.5,y+.7,56.9,2)end
  end
  for _,x in ipairs({40,55})do box(x-.6,0,64.1,x+.6,24,65,2)end
  trim(24,8,72,56,137,1)
  end
  return vertices, indices
end

local PALETTES = {
  smoke_black = {
    {.20,.19,.22,1},{.28,.27,.31,1},{.39,.37,.42,1},
    {.23,.12,.31,1},{.33,.16,.43,1},{.055,.045,.065,1},
    {.83,.66,.30,1},{.17,.10,.08,1},
  },
  storm_white = {
    {.46,.47,.50,1},{.58,.59,.62,1},{.72,.73,.75,1},
    {.23,.12,.31,1},{.34,.17,.44,1},{.06,.06,.075,1},
    {.87,.72,.34,1},{.18,.11,.09,1},
  },
  pearl_white = {
    {.64,.64,.66,1},{.75,.75,.77,1},{.88,.87,.88,1},
    {.25,.13,.33,1},{.37,.18,.48,1},{.065,.06,.08,1},
    {.91,.77,.39,1},{.19,.12,.10,1},
  },
}

local function ensure()
  if not mesh then
    local v,i=M.geometry(); mesh=Voxel3D.newMesh(v,i)
  end
  local style=CommunityVisuals.towerWallStyle()
  if texture and textureStyle==style then return mesh,texture end
  if texture and texture.release then pcall(texture.release,texture) end
  texture=nil; textureStyle=style
  if not (love and love.image and love.graphics) then return mesh,nil end
  local p=PALETTES[style] or PALETTES.smoke_black
  local d=love.image.newImageData(#p,1)
  for x,c in ipairs(p) do d:setPixel(x-1,0,c[1],c[2],c[3],c[4]) end
  texture=love.graphics.newImage(d)
  if d.release then pcall(d.release,d) end
  texture:setFilter("nearest","nearest")
  return mesh,texture
end

function M.drawMap(map, transform, renderer)
  if not CommunityVisuals.customTower() then return false end
  local at=M.detect(map); if not at then return false end
  local m,t=ensure(); if not (m and t) then return false end
  local localTransform=Mat4.translate(at.tx*8,0,at.ty*8)
  local model=transform and Mat4.mul(transform,localTransform) or localTransform
  local draw = renderer or Voxel3D
  if not (draw and type(draw.draw) == "function") then return false end
  draw.draw(m,t,model)
  return true
end

function M.invalidate()
  placements=setmetatable({}, { __mode = "k" })
  if mesh and mesh.release then pcall(mesh.release,mesh) end
  if texture and texture.release then pcall(texture.release,texture) end
  mesh,texture,textureStyle=nil,nil,nil
end

return M
