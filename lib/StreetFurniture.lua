-- Coordinated town furniture; geometry is clipped into the existing terrain batch.
local V=...;local C=V.require('SurfaceCraft');local M={}
function M.build(x,z,h,f,emit,id)
 local G=C.builder(x,z,emit);local a,b=f.cx,f.cz
 local function box(x0,z0,x1,z1,lo,hi,mat,t)G.box(x0,z0,x1,z1,h+lo,h+hi,mat,t)end
 if f.kind=='bench' then
  local q=f.bounds
  G.flat(q[1],q[2],q[3],q[4],h+.10,'cityBorder',.94)
  G.flat(q[1]+.38,q[2]+.38,q[3]-.38,q[4]-.38,h+.12,'stonePaving',1.02)
  local horizontal=f.edge=='n' or f.edge=='s'
  if horizontal then for u=a-6,a+6,6 do G.flat(u-.035,q[2]+.4,u+.035,q[4]-.4,h+.125,'pavingBand',.8)end
  else for u=b-6,b+6,6 do G.flat(q[1]+.4,u-.035,q[3]-.4,u+.035,h+.125,'pavingBand',.8)end end
  V.require('DistrictFurniture').bench(x,z,h+.04,f,emit,id)
  return
 elseif f.kind=='lamp' then
  return V.require('DistrictFurniture').lamp(x,z,h,f,emit,id)
 elseif f.kind=='bin' then
  box(a-1.8,b-1.8,a+1.8,b+1.8,.10,.45,'shadow',.7)
  local body=id=='SAFFRON_CITY' and 'shadow' or id=='CERULEAN_CITY' and 'cityBorder' or id=='PEWTER_CITY' and 'stonePaving' or 'wood'
  box(a-1.5,b-1.5,a+1.5,b+1.5,.4,4.7,body,id=='SAFFRON_CITY' and .7 or .92)
  for side=0,1 do for j=-1,1 do
   if side==0 then for _,v in ipairs({-1.52,1.52})do box(a+j-.05,b+v-.025,a+j+.05,b+v+.025,.5,4.65,'shadow',.63)end
   else for _,u in ipairs({-1.52,1.52})do box(a+u-.025,b+j-.05,a+u+.025,b+j+.05,.5,4.65,'shadow',.63)end end
  end end
  for _,v in ipairs({.65,4.25})do box(a-1.57,b-1.57,a+1.57,b+1.57,v,v+.22,'shadow',.65)end
  box(a-1.75,b-1.75,a+1.75,b+1.75,4.65,5.08,'shadow',.7)
  G.flat(a-.9,b-.58,a+.9,b+.58,h+5.09,'dark',.4)
  box(a-.4,b+1.58,a+.4,b+1.62,2.25,3.0,'cityBorder',.9)
  if id=='PALLET_TOWN' then
   box(a-1.45,b-1.5,a+1.45,b+1.5,5.1,5.4,'wood',1.05)
  elseif id=='VIRIDIAN_CITY' or id=='FUCHSIA_CITY' then
   for _,y in ipairs({1.0,3.65})do box(a-1.6,b-1.6,a+1.6,b+1.6,y,y+.22,id=='VIRIDIAN_CITY' and 'canopy' or 'cityAccent',1)end
  elseif id=='PEWTER_CITY'then
   box(a-1.85,b-1.85,a+1.85,b+1.85,.1,.7,'cityBorder',.95)
  elseif id=='CERULEAN_CITY'then
   for _,v in ipairs({-1.52,1.52})do box(a-1.3,b+v-.04,a+1.3,b+v+.04,3.7,4.3,'pavingBand',.8)end
  elseif id=='CINNABAR_ISLAND'then
   for _,v in ipairs({-.8,.8})do box(a+v-.09,b-1.6,a+v+.09,b+1.6,.5,4.6,'shadow',.62)end
  end
  return
 elseif f.kind=='bikeRack' then
  local function pos(u,v)
   if f.edge=='n' or f.edge=='s' then return a+u,b+v else return a+v,b+u end
  end
  local function rail(u,v,U,Vv,lo,hi)
   local p,q=pos(u,v);local r,s=pos(U,Vv);box(math.min(p,r),math.min(q,s),math.max(p,r),math.max(q,s),lo,hi,'shadow',.7)
  end
  for _,u in ipairs({-4,0,4})do
   rail(u-.17,-2,u+.17,-1.65,.15,4.7);rail(u-.17,1.65,u+.17,2,.15,4.7);rail(u-.17,-2,u+.17,2,4.45,4.8)
  end
  return
 elseif V.require('DistrictLife').kinds[f.kind] then
  return V.require('DistrictLife').build(x,z,h,f,emit,id)
 elseif f.kind=='tree' then
  return V.require('DistrictGardens').tree(x,z,h,f,emit,id)
 elseif f.kind=='research' or f.kind=='fossil' or f.kind=='pondDeck' or f.kind=='pergola' then
  return V.require('DistrictFurniture').amenity(x,z,h,f,emit,id)
 end
 return V.require('DistrictGardens').build(x,z,h,f,emit,id)
end
return M
