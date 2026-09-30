-- Bounded Viridian-only falling leaves and dusk/night fireflies.
-- Native depth-tested geometry; no additional shader or particle API.
local V=...
local M={MAX_VERTICES=4704}
local mesh,texture,tick,lastMap
function M.invalidate()
 if mesh then mesh:release() end
 if texture then texture:release() end
 mesh,texture,tick,lastMap=nil,nil,nil,nil
end
local function hash(x,z,s)
 local n=math.sin(x*127.1+z*311.7+s*74.7)*43758.5453
 return n-math.floor(n)
end
function M.vertices(w,h,px,pz,t,night)
 local out={};local leaves,flies=0,0
 local function tri(a,b,c,u,shade)
  for _,p in ipairs({a,b,c,c,b,a})do out[#out+1]={p[1],p[2],p[3],u,.5,shade}end
 end
 for iz=math.floor(pz/32)-3,math.floor(pz/32)+3 do
 for ix=math.floor(px/32)-3,math.floor(px/32)+3 do
  local x=(ix+.2+.6*hash(ix,iz,1))*32
  local z=(iz+.2+.6*hash(ix,iz,2))*32
  if x>12 and z>12 and x<w-12 and z<h-12 then
   local distance=math.sqrt((x-px)^2+(z-pz)^2)
   local fade=math.max(0,math.min(1,(96-distance)/24))
   if fade>0 then
    local phase=hash(ix,iz,3);local speed=.105+.054*hash(ix,iz,4)
    local progress=(t*speed+phase)%1
    local y=2+(1-progress)*42
    local s=fade*math.min(1,progress*12,(1-progress)*12)*(.62+.25*hash(ix,iz,6))
    local a=t*(1.6+phase)+phase*20
    local cx=x+math.sin(a*.63)*4;local cz=z+math.cos(a*.47)*4
    local tilt=.5+math.sin(a*1.7)*.8
    local function point(lx,ly,lz)
     local yy=ly*math.cos(tilt)-lz*math.sin(tilt)
     local zz=ly*math.sin(tilt)+lz*math.cos(tilt)
     return {cx+s*(lx*math.cos(a)-zz*math.sin(a)),y+s*yy,cz+s*(lx*math.sin(a)+zz*math.cos(a))}
    end
    -- Unequal curved lobes taper toward a bent tip and a narrow stem.
    -- Each template varies breadth and curl; the outline is not a diamond.
    local contour={{.12,1.8},{-.26,1.35},{-.57,.90},{-.76,.36},
      {-.66,-.22},{-.39,-.79},{-.06,-1.34},{.31,-.98},
      {.63,-.51},{.81,.08},{.65,.67},{.39,1.22}}
    local ring={};local breadth=.8+.3*hash(ix,iz,7)
    for k,p in ipairs(contour)do
     local curl=.15*p[2]*p[2]+.12*math.sin(k*1.7+phase*7)
     ring[k]=point(p[1]*breadth,p[2],curl)
    end
    local center=point(0,0,-.17)
    local u=(math.floor(phase*3)+.5)/4
    for k=1,#ring do tri(ring[k],ring[k%#ring+1],center,u,.91+.035*math.sin(k*1.2))end
    tri(point(-.035,-1.8,.31),point(.04,-1.8,.31),point(-.06,-1.15,.18),u,.69)
    tri(point(-.035,-1.15,.02),point(.035,-1.15,.02),point(.10,1.58,.39),u,1.06)
    leaves=leaves+1
    if night>0.02 then
     local fx=x+math.sin(t*.43+phase*13)*7
     local fz=z+math.cos(t*.31+phase*17)*7
     local fy=4+hash(ix,iz,5)*7+math.sin(t*.62+phase*8)*2
     local r=(.08+.32*math.max(0,math.sin(t*1.7+phase*30))^2)*fade*night
     tri({fx-r,fy-r,fz},{fx+r,fy-r,fz},{fx,fy+r,fz},.875,65)
     tri({fx,fy-r,fz-r},{fx,fy-r,fz+r},{fx,fy+r,fz},.875,65)
     flies=flies+1
    end
   end
  end
 end end
 assert(#out<=M.MAX_VERTICES)
 return out,leaves,flies
end
function M.draw(state)
 local map=state and state.map
 local F=V.require('ForestAtmos')
 if not map or map.id~='VIRIDIAN_FOREST' or not V.require('CommunityVisuals').customForest() or F.setting:get()=='off' then
  if mesh then M.invalidate()end
  return
 end
 if lastMap and lastMap~=map then M.invalidate()end
 local frame=F.frame(map);if not frame then return end
 V.require('ForestLifeAudio').touch(frame.fireflyLevel)
 local p=state.player or {};local px=(p.px or p.x or (p.cellX and p.cellX*16) or 0)+8
 local pz=(p.py or p.y or (p.cellY and p.cellY*16) or 0)+8
 local now=F.time;local nextTick=math.floor(now*30)
 if tick~=nextTick or lastMap~=map then
  local d=map.def or {}
  local verts=M.vertices((d.width or 16)*32,(d.height or 16)*32,px,pz,now,frame.fireflyLevel)
  if #verts==0 then tick=nil;return end
  local R=V.require('Voxel3D')
  if not mesh then
   mesh=love.graphics.newMesh(R.FORMAT,M.MAX_VERTICES,'triangles','dynamic')
   local data=love.image.newImageData(4,1)
   for i,c in ipairs({{.28,.43,.13},{.45,.49,.18},{.48,.32,.12},{.80,1,.32}})do data:setPixel(i-1,0,c[1],c[2],c[3],1)end
   texture=love.graphics.newImage(data);texture:setFilter('nearest','nearest');data:release()
  end
  mesh:setVertices(verts,1,#verts);mesh:setDrawRange(1,#verts)
  tick,lastMap=nextTick,map
 end
 if mesh then V.require('Voxel3D').draw(mesh,texture)end
end
return M
