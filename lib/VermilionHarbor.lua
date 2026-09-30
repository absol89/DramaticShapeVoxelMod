local V=...
local C=V and V.require('SurfaceCraft') or assert(loadfile('lib/SurfaceCraft.lua'))()
local M={}
function M.enabled(id,roads,tileset)return id=='VERMILION_CITY' and roads and tileset=='OVERWORLD'end
local function point(x,z,e,inside,along)
 if e=='w'then return x+inside,z+along elseif e=='e'then return x+8-inside,z+along
 elseif e=='n'then return x+along,z+inside else return x+along,z+8-inside end
end
local function strip(G,x,z,h,e,a,b,lo,hi,mat,tone)
 local p,q=point(x,z,e,a,lo);local r,s=point(x,z,e,b,hi)
 G.box(math.min(p,r),math.min(q,s),math.max(p,r),math.max(q,s),h-.02,h+.27,mat,tone)
end
local function foliage(G,x,z,h,seed)
 for j=0,5 do
  local a=j*math.pi/3+C.hash(seed,j,4002)*.45;local dx,dz=math.cos(a),math.sin(a)
  local tip={x+dx*1.45,h+.55,z+dz*1.45};local mid={x+dx*.5,h+1.35+C.hash(seed,j,4003)*.78,z+dz*.5}
  local left={mid[1]-dz*.4,h+1.45,mid[3]+dx*.4};local right={mid[1]+dz*.4,h+1.45,mid[3]-dx*.4}
  for _,tri in ipairs({{{x,h,z},left,mid},{left,tip,mid},{tip,right,mid},{right,{x,h,z},mid}})do
   G.face(tri,'leaf',.82+C.hash(seed,j,3810)*.2);G.face({tri[3],tri[2],tri[1]},'leaf',.8)
  end
 end
end
local function flower(G,x,z,h,seed)
 local top=h+2.8+C.hash(seed,0,3811)*1.0
 G.blade(x,z,h,top-h,.07,.05,seed,'leaf',.85)
 for j=0,4 do local a=j*math.pi*.4
  G.face({{x,top,z},{x+math.cos(a-.4)*.52,top+.05,z+math.sin(a-.4)*.52},
   {x+math.cos(a)*.78,top+.15,z+math.sin(a)*.78},{x+math.cos(a+.4)*.52,top+.05,z+math.sin(a+.4)*.52}},'petal',1)
 end
 G.flat(x-.1,z-.1,x+.1,z+.1,top+.17,'light',1)
end
function M.build(x,z,h,edges,emit,cell,plaza)
 local G=C.builder(x,z,emit);edges=edges or {};cell=cell or {}
 G.flat(x,z,x+8,z+8,h-.025,'shadow',.78)
 if cell.courtGarden then
  local D=V and V.require('HarborCourt') or assert(loadfile('lib/HarborCourt.lua'))()
  D.garden(x,z,h,emit,cell.gardenEdges)
 elseif cell.stone then
  -- Large, quiet limestone slabs define terraces and entrance aprons.
  for row=0,1 do for col=0,1 do
   local a,b=x+col*4,z+row*4;local t=.92+C.hash(a,b,3801)*.12
   G.box(a+.07,b+.07,a+3.93,b+3.93,h-.02,h+.18,'body',t*.9)
   G.flat(a+.14,b+.14,a+3.86,b+3.86,h+.22,'body',t)
   if C.hash(a,b,3901)>.82 then
    G.face({{a+.22,h+.226,b+.5},{a+.29,h+.226,b+.54},{a+1.1,h+.226,b+1.4}},'shadow',.84)
   end
  end end
 else
  if cell.open then
   for row=0,1 do for col=0,1 do
    local a,b=x+col*4,z+row*4
    local turned=(math.floor(a/4)+math.floor(b/4))%2==1
    for j=0,1 do
     local u,v=turned and a+j*2 or a,turned and b or b+j*2
     local w,d=turned and 2 or 4,turned and 4 or 2
     local t=.87+C.hash(a+j,b,4001)*.22
     G.box(u+.06,v+.06,u+w-.06,v+d-.06,h-.02,h+.16,'cinder',t*.9)
     G.flat(u+.13,v+.13,u+w-.13,v+d-.13,h+.20,'cinder',t)
    end
   end end
  else
   for row=math.floor(z/2),math.floor((z+8)/2)do
    local shift=(row%2)*2
    for col=math.floor((x-shift)/4),math.floor((x+8-shift)/4)do
     local a,b=col*4+shift,row*2;local t=.9+C.hash(col,row,3802)*.18
     G.box(a+.06,b+.06,a+3.94,b+1.94,h-.02,h+.16,'cinder',t*.9)
     G.flat(a+.13,b+.13,a+3.87,b+1.87,h+.20,'cinder',t)
    end
   end
  end
 end
 for _,e in ipairs({'w','e','n','s'})do
  if cell.join and cell.join[e]then
   for j=0,3 do strip(G,x,z,h,e,.05,.8,j*2+.04,j*2+1.96,'sand',.95)end
  end
  if edges[e]then
   for j=0,1 do strip(G,x,z,h,e,.05,.8,j*4+.05,j*4+3.95,'body',1.1)end
  end
 end
 -- The walkable plaza medallion uses the same cell clipping as the paving.
 if not cell.inCourt and plaza and math.abs(x+4-plaza.cx)<plaza.radius+5 and math.abs(z+4-plaza.cz)<plaza.radius+5 then
  local Mosaic=V and V.require('HarborMosaic') or assert(loadfile('lib/HarborMosaic.lua'))()
  Mosaic.build(x,z,h,plaza,emit)
 end
 if cell.bed then
  local e=cell.bed
  -- Raised low rim, soil and broad foliage occupy the perimeter of the sidewalk.
  local outline={{.3,1.15},{.95,.4},{3.65,.4},{4.35,1.1},{4.35,6.9},{3.6,7.6},{.95,7.6},{.3,6.85}}
  local inner={};local outer={}
  for _,v in ipairs(outline)do
   local a,b=point(x,z,e,v[1],v[2]);outer[#outer+1]={a,h+.85,b}
   a,b=point(x,z,e,2.3+(v[1]-2.3)*.8,4+(v[2]-4)*.86);inner[#inner+1]={a,h+.85,b}
  end
  G.face(inner,'shadow',.65)
  for j,a in ipairs(outer)do local k=j%#outer+1;local b=outer[k]
   G.face({a,b,inner[k],inner[j]},'body',.88+(j%3)*.055)
   G.face({{a[1],h+.23,a[3]},{b[1],h+.23,b[3]},b,a},'sand',.72)
  end
  for j=0,2 do
   local cx,cz=point(x,z,e,2.0,1.6+j*2.3)
   foliage(G,cx,cz,h+.9,x+z+j)
   flower(G,cx+.12,cz,h+.9,x+z+j)
   if cell.coastalBed then
    for k=0,2 do G.blade(cx+(k-1)*.25,cz,h+.43,3.1+C.hash(x+j,z+k,3902)*1.8,.10,.35,k,'leaf',.96)end
   end
  end
 end
 -- Waterfront fixtures stay completely within their owning tile.
 if cell.lamp then
  local cx,cz=cell.lamp.x,cell.lamp.z
  G.box(cx-.95,cz-.95,cx+.95,cz+.95,h+.25,h+.85,'body',1.05)
  G.box(cx-.38,cz-.38,cx+.38,cz+.38,h+.85,h+10.8,'shadow',.57)
  G.box(cx-.85,cz-.85,cx+.85,cz+.85,h+10.5,h+10.9,'shadow',.60)
  G.box(cx-.62,cz-.62,cx+.62,cz+.62,h+10.9,h+13.1,'glass',1.2)
  for _,dx in ipairs({-.76,.58})do for _,dz in ipairs({-.76,.58})do
   G.box(cx+dx,cz+dz,cx+dx+.18,cz+dz+.18,h+10.8,h+13.25,'shadow',.55)
  end end
  G.box(cx-.94,cz-.94,cx+.94,cz+.94,h+13.15,h+13.6,'shadow',.63)
  G.box(cx-.65,cz-.65,cx+.65,cz+.65,h+13.6,h+13.95,'shadow',.7)
 end
 local Details=V and V.require('HarborDetails') or assert(loadfile('lib/HarborDetails.lua'))()
 if not cell.courtGarden then Details.paving(x,z,h,cell,emit) end
 if cell.dockDetail then Details.dock(x,z,h,cell.dockDetail,emit) end
 if cell.focal then Details.anchor(x,z,h,cell.focal,emit) end
 if cell.bin then
  local D=V and V.require('HarborCourt') or assert(loadfile('lib/HarborCourt.lua'))()
  D.bin(x,z,h,cell.bin,emit)
 end
 if cell.flowerbed then
  local F=V and V.require('HarborFlowerbed') or assert(loadfile('lib/HarborFlowerbed.lua'))()
  F.build(x,z,h,cell.flowerbed,emit)
 end
 if cell.vase then
  local A=V and V.require('HarborVase') or assert(loadfile('lib/HarborVase.lua'))()
  A.build(x,z,h,cell.vase,emit)
 end
 if cell.bench then
  local B=V and V.require('HarborBench') or assert(loadfile('lib/HarborBench.lua'))()
  B.build(x,z,h,cell.bench,emit)
 end
end
return M
