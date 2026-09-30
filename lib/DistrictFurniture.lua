-- Regional street furniture, always contained by the planner's checked footprint.
local V=...;local C=V.require('SurfaceCraft');local M={}
function M.bench(x,z,h,f,emit,id)
 local function colored(q,mat,tone)
  if mat=='wood' and id=='CERULEAN_CITY' then mat='cityBorder';tone=tone*.98
  elseif mat=='wood' and id=='SAFFRON_CITY' then tone=tone*.72
  elseif mat=='wood' and id=='CINNABAR_ISLAND' then tone=tone*.86
  elseif mat=='shadow' and id=='PALLET_TOWN' then mat='wood';tone=tone*1.4 end
  emit(q,mat,tone)
 end
 V.require('HarborBench').build(x,z,h,f,colored)
 local G=C.builder(x,z,emit)
 local function pos(u,v)
  if f.edge=='n' then return f.cx+u,f.cz+v elseif f.edge=='s' then return f.cx+u,f.cz-v
  elseif f.edge=='w' then return f.cx+v,f.cz+u else return f.cx-v,f.cz+u end
 end
 local function box(u,v,a,b,lo,hi,mat,t)
  local px,pz=pos(u,v);local qx,qz=pos(a,b)
  G.box(math.min(px,qx),math.min(pz,qz),math.max(px,qx),math.max(pz,qz),h+lo,h+hi,mat,t)
 end
 if id=='PEWTER_CITY' then
  for _,u in ipairs({-8,7})do box(u,-1.2,u+1,2.5,.18,5,'cityBorder',.83);box(u-.25,-1.4,u+1.25,2.7,4.75,5.15,'stonePaving',1)end
  -- Mineral inlays vary deterministically without moving the seating group.
  local variant=math.floor(f.cx/16+f.cz/16)%3
  for _,u in ipairs({-7.8,7.2})do
   for j=0,2 do box(u,-1.46,u+.6,-1.38,1.1+j*.85,1.28+j*.85,'shadow',.78)end
  end
  if variant~=1 then box(-2.2,-1.35,2.2,-1.21,10.8,11.12,'cityBorder',.91)end
 elseif id=='CERULEAN_CITY'then
  -- Pale waterfront bench, blue accent and restrained end hardware.
  box(-8.2,-1.28,8.2,-1.15,10.7,11.05,'cityAccent',.91)
  for _,u in ipairs({-8.4,8.1})do
   box(u,-1.35,u+.3,-1.0,6.4,11.6,'shadow',.86)
   box(u,-1.05,u+.3,2.05,7.75,8.03,'cityBorder',1)
  end
 elseif id=='VIRIDIAN_CITY' or id=='FUCHSIA_CITY' then
  for _,u in ipairs({-8.6,8})do box(u,-1.25,u+.55,-.7,6.8,12,'wood',1.04)end
 elseif id=='SAFFRON_CITY' then
  for _,u in ipairs({-8.5,8})do box(u,-1.0,u+.4,2.3,8,8.3,'cityBorder',.9)end
 elseif id=='CINNABAR_ISLAND' then
  -- Coastal bench: deep end brackets and pale salt-weathered top rail.
  for _,u in ipairs({-8.6,8})do
   box(u,-1.2,u+.55,2.5,.3,1.0,'shadow',.70)
   box(u,-1.2,u+.55,-.65,1,11.8,'wood',.88)
  end
  box(-9,-1.15,9,-.62,11.2,11.65,'wood',1.13)
 end
end
function M.lamp(x,z,h,f,emit,id)
 local G=C.builder(x,z,emit);local a,b=f.cx,f.cz
 local town=id=='PALLET_TOWN';local stone=id=='PEWTER_CITY';local urban=id=='SAFFRON_CITY'
 local height=town and 15 or urban and 22 or 20
 local metal=urban or id=='CERULEAN_CITY' or id=='ROUTE_17'
 local post=metal and 'shadow' or stone and 'stonePaving' or 'wood'
 local function box(rx,rz,lo,hi,mat,t)G.box(a-rx,b-rz,a+rx,b+rz,h+lo,h+hi,mat,t)end
 box(1,1,.10,.42,'cityBorder',.95)
 box(.64,.64,.42,1.25,post,.80)
 box(stone and .48 or .32,stone and .48 or .32,1.25,height-3.3,post,metal and .63 or .94)
 for _,y in ipairs({2.0,height-4.8,height-3.6})do box(.47,.47,y,y+.28,urban and 'cityBorder' or 'shadow',.82)end
 box(.94,.94,height-3.5,height-3.15,'shadow',.78)
 box(.69,.69,height-3.15,height-.35,'glass',1.04)
 for _,dx in ipairs({-.84,.64})do for _,dz in ipairs({-.84,.64})do
  G.box(a+dx,b+dz,a+dx+.20,b+dz+.20,h+height-3.2,h+height-.2,'shadow',.72)
 end end
 box(.88,.88,height-1.8,height-1.6,'shadow',.72)
 box(1,1,height-.35,height+.05,'shadow',.7)
 box(.76,.76,height+.05,height+.35,urban and 'cityBorder' or post,.94)
 box(.35,.35,height+.35,height+.65,'shadow',.8)
end
function M.amenity(x,z,h,f,emit,id)
 local G=C.builder(x,z,emit);local a,b=f.cx,f.cz
 local cross=f.edge=='w' or f.edge=='e'
 local U=cross and f.rz or f.rx;local W=cross and f.rx or f.rz
 local function pos(u,v)
  if f.edge=='n'then return a+u,b+v elseif f.edge=='s'then return a+u,b-v
  elseif f.edge=='w'then return a+v,b+u else return a-v,b+u end
 end
 local function box(u,v,c,d,lo,hi,mat,t)
  local px,pz=pos(u,v);local qx,qz=pos(c,d)
  G.box(math.min(px,qx),math.min(pz,qz),math.max(px,qx),math.max(pz,qz),h+lo,h+hi,mat,t)
 end
 if f.kind=='research' then
  -- Oak's low potting table, herb trays, seed drawers and enamel labels.
  for _,u in ipairs({-6.4,5.9})do for _,v in ipairs({-2.8,2.3})do box(u,v,u+.5,v+.5,.15,6.5,'wood',.9)end end
  box(-7,-3.3,7,3.3,6.2,6.65,'wood',1.04)
  box(-6.5,-2.9,6.5,2.9,1.6,2,'wood',.88)
  for i=0,2 do
   local u=-4.6+i*4.6
   box(u-1.65,-2,u+1.65,1.5,6.65,7.65,'cityAccent',.94)
   box(u-1.3,-1.65,u+1.3,1.15,7.65,7.75,'soil',.82)
   local px,pz=pos(u,-.1);V.require('WorldGardens').foliage(G,px,pz,h+7.76,8900+i,.82)
   box(u-.7,2,u+.7,2.3,6.7,7.4,'cityBorder',1)
   box(u-1.7,-2.2,u+1.7,2,2,3.5,'wood',.8)
   box(u-.45,2.02,u+.45,2.15,2.5,2.8,'shadow',.7)
  end
 elseif f.kind=='fossil' then
  -- Museum display: stepped plinth and a spiral ammonite relief.
  box(-7,-4,7,4,.1,.65,'stonePaving',.86)
  box(-6,-3.5,6,3.5,.65,3.8,'cityBorder',.91)
  box(-6.5,-3.8,6.5,3.8,3.8,4.3,'stonePaving',1)
  box(-4.8,-1.6,4.8,1.6,4.3,10.5,'stonePaving',.92)
  for i=0,27 do
   local t=i*.37;local r=3.3*(1-i/34);local u=math.cos(t)*r;local y=7.7+math.sin(t)*r*.68
   box(u-.25,1.61,u+.25,1.95,y-.20,y+.20,'cityBorder',1.10)
  end
  box(-2.5,2.5,2.5,3.3,4.31,4.6,'shadow',.7)
  for u=-1.7,1.5,.7 do box(u,2.72,u+.4,3.0,4.6,4.64,'cityBorder',1)end
 elseif f.kind=='pondDeck' then
  -- A dry viewing terrace on checked lawn beside water; no collision changes.
  box(-U,-W,U,W,.10,.32,'shadow',.8)
  for v=-W+.18,W-.6,1.6 do
   box(-U+.15,v,U-.15,math.min(v+1.4,W-.15),.32,.60,'wood',.87+(math.floor(v)%3)*.04)
  end
  local back=-(W-1)
  for _,u in ipairs({-U+1,U-1})do
   box(u-.45,back-.45,u+.45,back+.45,.6,7.8,'wood',.9)
   box(u-.65,back-.65,u+.65,back+.65,7.8,8.1,'cityBorder',1)
  end
  box(-U+1,back-.3,U-1,back+.3,4.6,5.1,'shadow',.65)
  box(-U+1,back-.42,U-1,back+.42,7.1,7.7,'wood',1)
  for u=-U+3,U-2,4 do box(u-.12,back-.13,u+.12,back+.13,1,7.2,'shadow',.7)end
 elseif f.kind=='pergola' then
  -- A low timber landing anchors the pavilion to its checked approach.
  box(-10.6,-5.8,10.6,5.8,.015,.07,'shadow',.82)
  for v=-5.6,5,1.55 do box(-10.4,v,10.4,math.min(v+1.42,5.6),.07,.12,'wood',.9)end
  -- Garden entrance pavilion: open center, vines kept on the uprights.
  for _,u in ipairs({-10,10})do for _,v in ipairs({-5,5})do
   box(u-.55,v-.55,u+.55,v+.55,.1,22,'wood',.9)
   box(u-.8,v-.8,u+.8,v+.8,.1,.7,'cityBorder',.9)
   for y=4,19,3 do box(u-.75,v-.7,u+.75,v+.7,y,y+1,'canopy',.98)end
  end end
  for _,v in ipairs({-5,5})do box(-11.5,v-.48,11.5,v+.48,21.4,22.4,'wood',1.02)end
  for u=-11,11,2.75 do box(u-.4,-6.5,u+.4,6.5,22.4,23,'wood',1)end
  for u=-9,9,3 do for _,v in ipairs({-4.8,4.8})do
   local px,pz=pos(u,v);V.require('WorldGardens').foliage(G,px,pz,h+23,math.floor(u),.85)
  end end
 end
end
return M
