-- Four north/south shelf treads drawn by CAVERN's repeated 21/22 pair.
-- Geometry and rendered support share this contract; game cells and warps
-- remain untouched. Flights between two raised shelves are level landings.
local V = ...
local Shape = V.require("TileShape")
local M = {}
local function key(x,z) return (z+64)*4096+x+64 end
local function profile(map)
  if not map.def or map.def.tileset ~= "CAVERN" then return nil end
  local spec = V.data("voxel_heights")
  local cave = spec and spec.tilesets and spec.tilesets.CAVERN
  return cave and cave.cave_steps
end
function M.match(map,cx,cz)
  local p = profile(map)
  if not p or not map:inBounds(cx,cz) or map:warpAtCell(cx,cz) then return nil end
  for z,row in ipairs(p.tiles) do for x,t in ipairs(row) do
    if map:tileAt(cx*2+x-1,cz*2+z-1) ~= t then return nil end
  end end
  return p
end
function M.levels(map,cx,cz)
  local p = M.match(map,cx,cz)
  if not p then return nil end
  local shapes = Shape.forMap(map)
  local south = map:inBounds(cx,cz+1) and shapes[map:cellTile(cx,cz+1)]
  -- Five Mt Moon placements join raised floor at both ends. Cutting them
  -- to zero would create a pit absent from both the source and the map.
  local low = south and south.class == "ledge" and south.h == p.rise and p.rise or 0
  return p.rise,low
end
function M.height(map,cx,cz,z)
  local high,low = M.levels(map,cx,cz)
  if not high then return nil end
  local band = math.min(3,math.max(0,math.floor(z/4)))
  return high-(high-low)*band/4
end
-- wx/wz are map-local world coordinates of the physical contact point.
function M.support(map,wx,wz)
  local cx,cz = math.floor(wx/16),math.floor(wz/16)
  return M.height(map,cx,cz,wz-cz*16)
end
function M.build(S,map,data,cx,cz)
  local high,low = M.levels(map,cx,cz)
  assert(high,"complete non-warp cave step cell")
  local mx,mz = cx*16,cz*16
  local aw,ah = map.tileset.imageWidth or 128,map.tileset.imageHeight or 40
  local perRow = map.tileset.tilesPerRow or 16
  local function point(x,y,z) return {mx+x,y,mz+z} end
  local function emit(points,coords,shade,role)
    local sx,sy = 0,0
    for i=1,4 do sx=sx+coords[i][1]/4;sy=sy+coords[i][2]/4 end
    local bx,by = math.floor(sx/8),math.floor(sy/8)
    local tile = assert(S.tileAt[key(cx*2+bx,cz*2+by)])
    local q = {points[1],points[2],points[3],points[4],uv={},shade=shade,caveStepRole=role}
    for i=1,4 do
      local x=math.max(.05,math.min(7.95,coords[i][1]-bx*8))
      local y=math.max(.05,math.min(7.95,coords[i][2]-by*8))
      q.uv[i]={((tile%perRow)*8+x)/aw,(math.floor(tile/perRow)*8+y)/ah}
    end
    S.objectQuads[#S.objectQuads+1]=q
  end
  local function solid(points,x,y,shade,role)
    local c={x+.5,y+.5};emit(points,{c,c,c,c},shade,role)
  end
  for band=0,3 do
    local z0,z1=band*4,band*4+4
    local h=high-(high-low)*band/4
    local nextH=high-(high-low)*(band+1)/4
    for x0=0,8,8 do local x1=x0+8
      -- Three horizontal art rows become the tread. The fourth black
      -- row folds down onto its own riser instead of repeating on a wall.
      local topEnd=high==low and z1 or z1-1
      emit({point(x0,h,z0),point(x1,h,z0),point(x1,h,z1),point(x0,h,z1)},
        {{x0,z0},{x1,z0},{x1,topEnd},{x0,topEnd}},1,"tread")
      if h>nextH then
        emit({point(x0,nextH,z1),point(x1,nextH,z1),point(x1,h,z1),point(x0,h,z1)},
          {{x0,z1},{x1,z1},{x1,z1-1},{x0,z1-1}},.82,"riser")
      end
    end
    solid({point(0,0,z0),point(0,0,z1),point(0,h,z1),point(0,h,z0)},1,2,.78,"west")
    solid({point(16,0,z1),point(16,0,z0),point(16,h,z0),point(16,h,z1)},14,2,.68,"east")
  end
  for x0=0,8,8 do local x1=x0+8
    solid({point(x1,0,0),point(x0,0,0),point(x0,high,0),point(x1,high,0)},1,2,.68,"north")
    if low>0 then
      solid({point(x0,0,16),point(x1,0,16),point(x1,low,16),point(x0,low,16)},1,2,.82,"south")
    end
  end
end
return M