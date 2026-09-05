-- Source-shaped S.S. Anne hull and its engine-owned departure snapshot.
local V = ...
local Budget = V.require('BuildBudget')
local M = {}
local cached, mesh, gangwayMesh
local function key(x,z) return (z+64)*4096+x+64 end
local function finite(x) return type(x)=='number' and x==x and x>-math.huge and x<math.huge end
local function spec()
  local s=V.data('voxel_heights')
  return s and s.tilesets and s.tilesets.SHIP_PORT and s.tilesets.SHIP_PORT.ship_hull
end
local function match(grid, read, x,z)
  for r,row in ipairs(grid) do for c,tile in ipairs(row) do
    if read(x+c-1,z+r-1)~=tile then return false end
  end end
  return true
end
-- The outline follows the source bow and stern; the surrounding wave pixels
-- are background, never side-wall material. Coordinates are original pixels.
local outline={{0,22},{1,18},{8,13},{16,8},{27,8},{38,4},{47,0},{61,0},{64,2},{103,2},{108,6},{118,6},{124,10},{128,17},{128,38},{124,44},{121,48},{27,48},{17,43},{9,39},{4,34},{0,28}}
local function inHull(x,z)
  local hit=false;local j=#outline
  for i=1,#outline do local a,b=outline[i],outline[j]
    if (a[2]>z)~=(b[2]>z) and x<(b[1]-a[1])*(z-a[2])/(b[2]-a[2])+a[1] then hit=not hit end
    j=i
  end
  return hit
end
M.inHull=inHull
function M.model(sp)
  return V.require('ShipExterior').model(sp)
end
local function meshData(quads)
  local V3=V.require('Voxel3D');local verts,indices={},{}
  for _,q in ipairs(quads) do Budget.tick()
    V3.pushQuad(indices,#verts/4)
    for i=1,4 do local c,uv=q[i],q.uv[i];local sh=type(q.shade)=='table' and q.shade[i] or q.shade
      verts[#verts+1]={c[1],c[2],c[3],uv[1],uv[2],sh}
    end
  end
  return verts,indices
end
function M.prepare(S,map,data,perRow,t,read,emit)
  if map.id~='VERMILION_DOCK' or not t or not data then return end
  if not cached then
    local sp=read(t,data,perRow)
    local model=M.model(sp)
    local quads=emit(model,sp,map.tileset.imageWidth or 128,map.tileset.imageHeight or 48)
    local verts,indices=meshData(quads)
    cached={quads=quads,source=sp,model=model,profile=t,verts=verts,indices=indices}
  end
  local tx,tz=t.anchor[1],t.anchor[2]
  if not match(t.tiles,function(x,z)return map:tileAt(x,z)end,tx,tz) then return end
  -- Render water beneath the independent hull. This touches only the mesher's
  -- private tile view, preserving original map/collision/support/warp data.
  for z=0,5 do for x=0,15 do
    local k=key(tx+x,tz+z)
    S.tileAt[k]=20;S.shapeAt[k]={class='water',h=-2,art='flat',flat=true,authored=true}
    S.skip[k]=nil;S.ground[k]=nil
  end end
  S.shipHull={x=tx*8,z=tz*8}
end
function M.enabled(map)
  return map and map.id=='VERMILION_DOCK' and spec()~=nil or false
end
function M.pose(state)
  if not state or not state.map or state.map.id~='VERMILION_DOCK' then return nil end
  local t=spec();if not t then return nil end
  local sa=state.shipAnim
  if sa then
    if not finite(sa.px) or not finite(sa.py) or not finite(sa.off) or sa.off<0 or sa.off>128 or type(sa.tiles)~='table' then return nil end
    if not match(t.tiles,function(x,z)local row=sa.tiles[z+3];return row and row[x+1]end,0,0) then return nil end
    return {x=sa.px-sa.off,y=-2,z=sa.py+16,gone=sa.gone==true,gangway={x=sa.px+64,z=sa.py}}
  end
  if match(t.tiles,function(x,z)return state.map:tileAt(x,z)end,t.anchor[1],t.anchor[2]) then
    return {x=t.anchor[1]*8,y=-2,z=t.anchor[2]*8,gone=false}
  end
end
local function gangway()
  if gangwayMesh then return gangwayMesh end
  local q={};local cols={50,59}
  for z=0,1 do for x=0,1 do local tile=cols[x+1];local ax=(tile%16)*8;local ay=math.floor(tile/16)*8
    q[#q+1]={{x*8,0,z*8},{x*8+8,0,z*8},{x*8+8,0,z*8+8},{x*8,0,z*8+8},shade=1,
      uv={{(ax+.05)/128,(ay+.05)/48},{(ax+7.95)/128,(ay+.05)/48},{(ax+7.95)/128,(ay+7.95)/48},{(ax+.05)/128,(ay+7.95)/48}}}
  end end
  local verts,indices=meshData(q)
  gangwayMesh=V.require('Voxel3D').newMesh(verts,indices);return gangwayMesh
end
function M.draw(state,texture,shadow)
  local p=M.pose(state);if not p or not cached then return end
  local Mat4=V.require('Mat4');local renderer=V.require(shadow and 'ShadowMap' or 'Voxel3D')
  if not p.gone then
    if not mesh then
      -- CPU assembly ran in the budgeted build; only upload remains here.
      mesh=V.require('Voxel3D').newMesh(cached.verts,cached.indices)
      if mesh then cached.verts=nil;cached.indices=nil end
    end
    if mesh then renderer.draw(mesh,texture,Mat4.translate(p.x,p.y,p.z)) end
  end
  if p.gangway then local gm=gangway();if gm then renderer.draw(gm,texture,Mat4.translate(p.gangway.x,0,p.gangway.z)) end end
end
function M.signature(state)
  local p=M.pose(state);if not p then return '' end
  return table.concat({p.x,p.z,p.gone and 1 or 0,tostring(mesh)},':')
end
function M.diagnostics() return cached end
return M
