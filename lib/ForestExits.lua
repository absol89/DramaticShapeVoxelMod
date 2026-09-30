-- TEST93: open doors at the live forest's existing north/south warp groups.
-- Nothing changes warps or collision. Frames and held-open leaves stay
-- inside those source cells; the center of every warp remains unobstructed.
local V=...
local M={REVISION='forest-floor-and-exits-93'}

function M.placements(map)
 local out,rows={},{}
 if not V.require('ForestTrees').enabled(map,true)then return out end
 local def=map.def or{};local wc,hc=(def.width or 0)*2,(def.height or 0)*2
 for _,w in ipairs(def.warps or{})do
  local x,z,d=w.x,w.y,w.destMap
  local face=d=='VIRIDIAN_FOREST_NORTH_GATE'and 'north'
    or d=='VIRIDIAN_FOREST_SOUTH_GATE'and 'south'
  if face and type(x)=='number'and type(z)=='number'
    and x==math.floor(x)and z==math.floor(z)and x>=0 and x<wc
    and ((face=='north'and z==0)or(face=='south'and z==hc-1))then
   local k=face..':'..z;rows[k]=rows[k]or{face=face,z=z,xs={}}
   rows[k].xs[x]=true
  end
 end
 for _,row in pairs(rows)do
  local xs={};for x in pairs(row.xs)do xs[#xs+1]=x end;table.sort(xs)
  local i=1
  while i<=#xs do
   local j=i;while j<#xs and xs[j+1]==xs[j]+1 do j=j+1 end
   local width=j-i+1
   -- Never force a double doorway into a single-cell or oversized opening.
   if width>=2 and width<=4 then out[#out+1]={x=xs[i],z=row.z,width=width,face=row.face}end
   i=j+1
  end
 end
 table.sort(out,function(a,b)return a.z==b.z and a.x<b.x or a.z<b.z end)
 return out
end

local function support(S,p,key)
 local h
 for z=p.z*2,p.z*2+1 do for x=p.x*2,(p.x+p.width)*2-1 do
  local k=key(x,z);local s=S.shapeAt[k]
  if not s or not s.flat or s.class~='ground' or S.skip[k]then return nil end
  local y=s.h or 0
  if h and math.abs(y-h)>.001 then return nil end
  h=y
 end end
 return h
end

local function opaqueGroundUV(map,data)
 if not data then return nil end
 local aw,ah=data:getDimensions()
 -- Tile zero is the forest's authored ground. Use one opaque texel only;
 -- the established material shader provides the doorway's surface colors.
 for y=0,7 do for x=0,7 do
  local _,_,_,a=data:getPixel(x,y)
  if a and a>.99 then return {(x+.5)/aw,(y+.5)/ah}end
 end end
end

function M.build(S,map,key,data)
 local placements=M.placements(map);if #placements==0 then return 0 end
 local uv=opaqueGroundUV(map,data);if not uv then return 0 end
 local count=0;S.forestExits={}
 for _,p in ipairs(placements)do
  local base=support(S,p,key)
  if base then
   local G=V.require('CityMesh').new(uv);local w=p.width*16
   -- Subdivide long beams for the existing curved-world vertex transform.
   local function box(x,y,z,X,Y,Z,mat,tone)
    for a=x,X-.001,8 do for b=y,Y-.001,8 do for c=z,Z-.001,8 do
     G.box(a,b,c,math.min(a+8,X),math.min(b+8,Y),math.min(c+8,Z),mat,tone)
    end end end
   end
   for _,right in ipairs({false,true})do
    local x=right and w-2.6 or .6
    box(x,0,3,x+2,2.1,7,'stone',.9)
    box(x+.25,2.1,3.6,x+1.75,26,6.4,'forestBark',1.15)
    box(x+.1,23.5,3.4,x+1.9,24.4,6.6,'wood',1)
    -- Door leaves are held fully open along the travel direction, with
    -- vertical boards, cross rails, hinges and a small brass handle.
    local dx=right and w-3.15 or 2.5
    for j=0,3 do box(dx,.35,4+j*1.95,dx+.65,22,5.87+j*1.95,'oak',.86+j*.025)end
    for _,y in ipairs({3.8,17.2})do
     box(dx-.12,y,4,dx+.77,y+.8,11.72,'wood',1)
     box(dx-.16,y,4.15,dx+.81,y+.45,5.2,'dark',1)
    end
    box(dx-.28,10.3,10.5,dx+.93,11.1,11.15,'gold',.85)
   end
   box(.6,25,3.6,w-.6,28.6,6.4,'wood',1.08)
   box(w/2-6,25.25,6.42,w/2+6,28.3,6.85,'green',.95)
   G.text('EXIT',w/2,25.85,6.87,.40,'cream')
   -- Compact pitched weather cap, entirely inside the warp row.
   for x=.25,w-.25-.001,8 do
    local X=math.min(x+8,w-.25)
    G.face({x,28.6,2.6},{X,28.6,2.6},{X,31,5},{x,31,5},'slate',.91)
    G.face({x,31,5},{X,31,5},{X,28.6,7.4},{x,28.6,7.4},'slate',1.03)
   end
   box(.25,28.15,2.5,w-.25,28.6,2.9,'wood',1)
   box(.25,28.15,7.1,w-.25,28.6,7.5,'wood',1)
   for _,q in ipairs(G.out)do
    -- Turn the complete doorway, including its sign, toward the forest.
    for i=1,4 do local v=q[i];local x,y,z=v[1],v[2],v[3]
     q[i]={p.x*16+(p.face=='north'and x or w-x),base+y,
       p.z*16+(p.face=='north'and z or 16-z)}
    end
    q.forestExit=true;S.objectQuads[#S.objectQuads+1]=q
   end
   p.base=base;p.quads=#G.out;S.forestExits[#S.forestExits+1]=p;count=count+1
  end
 end
 return count
end
return M
