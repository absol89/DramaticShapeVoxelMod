-- Complete source fence drawings and traversable timber approaches.
local V=...;local M={}
local function key(x,z)return(z+64)*4096+x+64 end
function M.ramp(map,cx,cz)
 if not V.require('SafariReserve').enabled(map)then return end
 local x,z=cx*2,cz*2
 if map:tileAt(x,z)~=64 or map:tileAt(x+1,z)~=65
  or map:tileAt(x,z+1)~=64 or map:tileAt(x+1,z+1)~=65 then return end
 local shapes=V.require('TileShape').forMap(map)
 local a,b=shapes[map:tileAt(x,z-1)],shapes[map:tileAt(x+1,z-1)]
 if not(a and b and a.class=='ledge'and b.class=='ledge'and a.h==b.h)then return end
 return{x=x*8,z=z*8,w=16,d=16,high=a.h,low=0}
end
function M.support(map,wx,wz)
 local r=M.ramp(map,math.floor(wx/16),math.floor(wz/16))
 if r then return r.high+(r.low-r.high)*math.max(0,math.min(1,(wz-r.z)/r.d))end
end
function M.drawRamp(G,r)
 local x,z,w,d=r.x,r.z,r.w,r.d
 local function pt(u,v,offset)return{x+u,r.high+(r.low-r.high)*v/d+(offset or 0),z+v}end
 for j=0,7 do local a,b=j*2,(j+1)*2
  G.face(pt(0,a),pt(0,b),pt(w,b),pt(w,a),'oak',.9+(j%3)*.045)
  -- Thin engraved joints and paired iron fasteners follow the slope.
  if j>0 then G.face(pt(0,a,.012),pt(0,a+.04,.012),pt(w,a+.04,.012),pt(w,a,.012),'wood',.73)end
  for _,u in ipairs({.8,w-1})do
   G.face(pt(u,a+.75,.015),pt(u,a+.93,.015),pt(u+.18,a+.93,.015),pt(u+.18,a+.75,.015),'dark',.8)
  end
 end
 G.face({x,0,z},{x,0,z+d},pt(0,d),pt(0,0),'wood',.88)
 G.face({x+w,0,z+d},{x+w,0,z},pt(w,0),pt(w,d),'wood',.92)
 G.face({x+w,0,z},{x,0,z},pt(0,0),pt(w,0),'wood',.8)
end
function M.build(S,map,G,W,H)
 S.safariRamps={};S.safariFences={}
 for z=0,H-2,2 do for x=0,W-2,2 do
  local r=M.ramp(map,x/2,z/2)
  if r then
   M.drawRamp(G,r);S.safariRamps[#S.safariRamps+1]=r
   for dz=0,1 do for dx=0,1 do
    local k=key(x+dx,z+dz);S.skip[k]=true;S.ground[k]=48
   end end
  end
 end end
 for z=0,H-2 do for x=0,W-1 do
  -- 66 ABOVE 67 is one north/south drawing of an east/west fence.
  -- Neither tile is an orientation selector. Own both before meshing.
  local a,b=key(x,z),key(x,z+1)
  if not S.skip[a]and not S.skip[b]and map:tileAt(x,z)==66 and map:tileAt(x,z+1)==67
   and not map:isWalkableCell(math.floor(x/2),math.floor(z/2))
   and not map:isWalkableCell(math.floor(x/2),math.floor((z+1)/2))then
   local xx,zz=x*8,z*8+8
   G.box(xx+3.35,0,zz-.7,xx+4.65,10,zz+.7,'wood',.93)
   G.box(xx+3.2,9.6,zz-.85,xx+4.8,10.15,zz+.85,'oak',.98)
   for _,y in ipairs({3.4,7.4})do G.box(xx,y,zz-.4,xx+8,y+1,zz+.4,'oak',.96)end
   S.safariFences[#S.safariFences+1]={x=xx,z=zz,w=8}
   for _,k in ipairs({a,b})do
    S.skip[k]=true;S.ground[k]=48;S.shapeAt[k]={class='ground',h=0,flat=true,art='flat',authored=true};S.safariClaims[k]='fence'
   end
  end
 end end
end
return M
