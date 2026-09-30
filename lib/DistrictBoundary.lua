-- Boundary geometry uses the source occupied cells; openings stay exactly open.
local V=...;local M={}
local styles={PEWTER_CITY='mineral',PALLET_TOWN='picket',VIRIDIAN_CITY='woodland',ROUTE_16='cycle',ROUTE_17='cycle',ROUTE_18='cycle',ROUTE_24='bridge',ROUTE_25='bridge',CERULEAN_CITY='bridge'}
function M.style(id,roads)return roads and styles[id] or nil end
function M.build(id,mx,mz,base,dirs,pier,emit)
 local style=styles[id];if not style then return false end
 dirs=dirs or {}
 local function box(a,b,c,d,lo,hi,tone,swatch)
  local function p(x,y,z)return {x,base+y,z}end
  emit({p(a,hi,b),p(c,hi,b),p(c,hi,d),p(a,hi,d)},tone*1.08,swatch)
  emit({p(a,lo,d),p(c,lo,d),p(c,hi,d),p(a,hi,d)},tone,swatch)
  emit({p(c,lo,b),p(a,lo,b),p(a,hi,b),p(c,hi,b)},tone*.82,swatch)
  emit({p(a,lo,b),p(a,lo,d),p(a,hi,d),p(a,hi,b)},tone*.87,swatch)
  emit({p(c,lo,d),p(c,lo,b),p(c,hi,b),p(c,hi,d)},tone*.95,swatch)
 end
 if style=='mineral'then
  box(mx-1.35,mz-1.35,mx+1.35,mz+1.35,.1,1.0,.82,'stone')
  box(mx-.95,mz-.95,mx+.95,mz+.95,1.0,7.8,.91,'stone')
  for _,y in ipairs({2.4,5.6})do box(mx-1.02,mz-1.02,mx+1.02,mz+1.02,y,y+.25,.60,'stone')end
  box(mx-1.5,mz-1.5,mx+1.5,mz+1.5,7.8,8.3,1.05,'stone')
  for _,d in ipairs({{'north',0,-1},{'south',0,1},{'west',-1,0},{'east',1,0}})do if dirs[d[1]]then
   local x,z=mx+d[2]*8,mz+d[3]*8
   box(math.min(mx,x)-.65,math.min(mz,z)-.65,math.max(mx,x)+.65,math.max(mz,z)+.65,.15,3.7,.83,'stone')
   box(math.min(mx,x)-.75,math.min(mz,z)-.75,math.max(mx,x)+.75,math.max(mz,z)+.75,3.7,4.15,1.02,'stone')
  end end
  return true
 end
 local wood=style=='picket' or style=='woodland' 
 local h=style=='picket' and 7.4 or 9.2
 local radius=style=='bridge' and pier and 1.5 or wood and .64 or .48
 local tone=style=='picket' and 1.1 or wood and .65 or .40
 box(mx-radius-.3,mz-radius-.3,mx+radius+.3,mz+radius+.3,.1,.65,.85,'stone')
 box(mx-radius,mz-radius,mx+radius,mz+radius,.65,h,tone,wood and 'wood' or 'metal')
 box(mx-radius-.22,mz-radius-.22,mx+radius+.22,mz+radius+.22,h,h+.4,wood and .9 or .72,wood and 'wood' or 'stone')
 for _,d in ipairs({{'north',0,-1},{'south',0,1},{'west',-1,0},{'east',1,0}})do if dirs[d[1]]then
  local x,z=mx+d[2]*8,mz+d[3]*8
  for _,y in ipairs({2.1,h-1.6})do
   box(math.min(mx,x)-.22,math.min(mz,z)-.22,math.max(mx,x)+.22,math.max(mz,z)+.22,y,y+.55,tone,wood and 'wood' or 'metal')
  end
  for k=2,6,style=='picket' and 2 or 4 do
   local x,z=mx+d[2]*k,mz+d[3]*k;local r=style=='picket' and .45 or .15
   box(x-r,z-r,x+r,z+r,1.1,style=='picket' and h-.5 or h-1.6,tone,wood and 'wood' or 'metal')
  end
 end end
 -- A small amber reflector marks cycling ends and selected structural posts.
 if not wood and pier then
  box(mx-.32,mz-radius-.04,mx+.32,mz-radius+.01,h-2.1,h-1.0,.96,'reflector')
  box(mx-.32,mz+radius-.01,mx+.32,mz+radius+.04,h-2.1,h-1.0,.96,'reflector')
 end
 return true
end
return M
