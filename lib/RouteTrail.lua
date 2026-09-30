-- Route 11 only: low relief, bounded geometry, no new textures or objects.
local V=...
local C=V and V.require('SurfaceCraft') or assert(loadfile('lib/SurfaceCraft.lua'))()
local M={}
local function clamp(v)return math.max(0,math.min(1,v))end
function M.finish(x,z,warps)
 -- Western city connection stays paved; roughness increases across the route.
 local finish=1-clamp((x-16)/112)
 for _,w in ipairs(warps or {})do
  if type(w.x)=='number' and type(w.y)=='number' then
   local dx,dz=x-(w.x*16+8),z-(w.y*16+8)
   finish=math.max(finish,1-clamp((math.sqrt(dx*dx+dz*dz)-12)/32))
  end
 end
 return finish
end
function M.build(x,z,h,edges,warps,emit,ledge)
 local G=C.builder(x,z,emit)
 local f=M.finish(x+4,z+4,warps)
 local footprints={}
 -- A continuous earthy bed, never holes in the collision surface.
 for iz=0,1 do for ix=0,1 do
  local a,b=x+ix*4,z+iz*4
  local t=.91+C.field((a+2)/23,(b+2)/23,4801)*.24
  G.flat(a,b,a+4,b+4,h,ledge and 'body' or 'earth',ledge and .66 or t)
 end end
 -- World-space staggered, chipped flags. Their seeds and finish are shared
 -- across tile cuts, preventing cracks at chunk boundaries.
 for row=math.floor(z/4.4)-1,math.floor((z+8)/4.4)+1 do
  for col=math.floor(x/5.2)-1,math.floor((x+8)/5.2)+1 do
   local cx=(col+.5)*5.2+(row%2)*2.6+(C.hash(col,row,4820)-.5)*2.5
   local cz=(row+.5)*4.4+(C.hash(col,row,4821)-.5)*1.7
   local sf=ledge and 1 or M.finish(cx,cz,warps)
   local n=C.hash(col,row,4802)
   if ledge or n<.60+sf*.40 then
    local rx=(2.05+C.hash(col,row,4803)*.55)*(ledge and 1 or .72+sf*.28)
    local rz=(1.8+C.hash(col,row,4804)*.4)*(ledge and 1 or .72+sf*.28)
    local p={};local top=h+.09+C.hash(col,row,4805)*.11
    for j=0,7 do local a=j*math.pi/4;local r=.83+C.hash(col+j,row,4806)*.17
     p[#p+1]={cx+math.cos(a)*rx*r,top,cz+math.sin(a)*rz*r}
    end
    local t=.76+C.hash(col,row,4807)*.30
    G.face(p,'body',t)
    local footprint={}
    for _,v in ipairs(p)do footprint[#footprint+1]={cx+(v[1]-cx)*1.08,cz+(v[3]-cz)*1.08}end
    footprints[#footprints+1]=footprint
    for j=1,8 do local a,b=p[j],p[j%8+1]
     G.face({{cx+(a[1]-cx)*1.08,h+.015,cz+(a[3]-cz)*1.08},
       {cx+(b[1]-cx)*1.08,h+.015,cz+(b[3]-cz)*1.08},b,a},'body',t*.76)
    end
    if n>.6 then
     G.face({{cx-.45,top+.006,cz-.15},{cx+.5,top+.006,cz+.1},{cx+.05,top+.006,cz+.05}},'shadow',.85)
    end
   end
  end
 end
 if ledge then return end
 -- Sparse physical sprouts in clear joints, not painted on rock faces.
 local function clear(cx,cz)
  for _,p in ipairs(footprints)do
   local inside=false;local last=p[#p]
   for _,v in ipairs(p)do
    if (v[2]>cz)~=(last[2]>cz) and cx<(last[1]-v[1])*(cz-v[2])/(last[2]-v[2])+v[1] then inside=not inside end
    -- Keep blade bases clear of the stone bevel, too.
    local dx,dz=v[1]-last[1],v[2]-last[2]
    local t=clamp(((cx-last[1])*dx+(cz-last[2])*dz)/math.max(.0001,dx*dx+dz*dz))
    if (cx-last[1]-dx*t)^2+(cz-last[2]-dz*t)^2<.12 then return false end
    last=v
   end
   if inside then return false end
  end
  return true
 end
 local sprouts=0
 for i=1,10 do
  local cx=x+.5+C.hash(x+i,z,5201)*7
  local cz=z+.5+C.hash(x,z+i,5202)*7
  if sprouts<4 and C.hash(x+i,z,5203)>.20+f*.25 and clear(cx,cz) then
   for j=0,3 do
    G.blade(cx,cz,h+.045,1.2+C.hash(x+i,z+j,5204)*.8,.15,.28,j*1.57,'leaf',.96)
   end
   sprouts=sprouts+1
  end
 end
 -- Small gravel clusters, sparse at finished entrances. No raised obstacles.
 for i=1,6 do
  local cx=x+.4+C.hash(x+i,z,4810)*7.2
  local cz=z+.4+C.hash(x,z+i,4811)*7.2
  local r=.10+C.hash(x+i,z,4812)*.18
  G.face({{cx-r,h+.025,cz},{cx,h+.065,cz-r},{cx+r,h+.025,cz+.08},{cx,h+.025,cz+r}},'body',.70+C.hash(x,z+i,4813)*.28)
 end
 -- Irregular lawn shoulders follow the world coordinate, never a tile grid.
 local band=.75+(1-f)*.65
 for _,d in ipairs({{'w',true,false},{'e',true,true},{'n',false,false},{'s',false,true}})do
  if edges and edges[d[1]] then
   local vertical,far=d[2],d[3]
   local along=vertical and z or x
   local cross=(vertical and x or z)+(far and 8 or 0)
   local function pt(u,v,y)
    return vertical and {cross+(far and -v or v),y,u} or {u,y,cross+(far and -v or v)}
   end
   for j=0,3 do
    local a,b=along+j*2,along+(j+1)*2
    local wa=band*(.65+C.field(a/7,cross/11,5101)*.8)
    local wb=band*(.65+C.field(b/7,cross/11,5101)*.8)
    G.face({pt(a,0,h+.04),pt(b,0,h+.04),pt(b,wb,h+.04),pt(a,wa,h+.04)},'turf',.96)
    if j==1 and C.hash(x,z,5102)>.45 then
     local v=pt(a+.8,wa*.65,h+.045)
     for k=0,2 do G.blade(v[1],v[3],v[2],1.0+k*.25,.15,.25,k*2.1,'leaf',.88)end
    end
   end
  end
 end
end
return M
