-- Static placement reservations. No source collision, NPC AI or warp edits.
local V=...;local M={}
local function overlap(a,b,gap)
 gap=gap or 0
 return a[1]<b[3]+gap and a[3]>b[1]-gap and a[2]<b[4]+gap and a[4]>b[2]-gap
end
M.overlap=overlap
function M.new(map,S,key,lawn,path)
 local A={actors={},routes={}}
 local w,h=map.def.width*4,map.def.height*4
 -- TEST92: the northern bridge continues across Cerulean's source lawn
 -- into the first cross street. Reserve its full 32px width plus 8px on
 -- each side, through the landing; a lawn-only check admitted a lamp here.
 if map.id=='CERULEAN_CITY' then
  A.routes[#A.routes+1]={312,0,360,192}
 end
 -- Keep the rejected Safari arch and its dead-end walkway as clear lawn.
 -- Removing it must not make the planner backfill the view with more beds.
 if map.id=='FUCHSIA_CITY' then
  A.routes[#A.routes+1]={245,98,275,118}
  A.routes[#A.routes+1]={254,104,266,144}
 end
 -- Cinnabar's Mansion/Gym alley is a through route to the northern dock.
 if map.id=='CINNABAR_ISLAND' then
  A.routes[#A.routes+1]={160,0,208,96}
 end
 for _,v in ipairs(map.def.warps or {})do
  local x,z=v.x*16+8,v.y*16+8
  A.actors[#A.actors+1]={x-24,z-24,x+24,z+32}
 end
 for _,v in ipairs(map.def.objects or {})do if not v.runtime and type(v.x)=='number' and type(v.y)=='number'then
  local x,z=v.x*16+8,v.y*16+8
  local radius=v.movement=='WALK' and (map.id=='SAFFRON_CITY' and 24 or 36) or 24
  local q={x-radius,z-radius,x+radius,z+radius}
  -- Directional walkers may patrol their whole unobstructed row/column.
  -- Reserve that lane, including the visible body width at either side.
  if map.id~='SAFFRON_CITY' and v.movement=='WALK' and (v.range=='LEFT_RIGHT' or v.range=='UP_DOWN') and map.isWalkableCell then
   local dx,dz=v.range=='LEFT_RIGHT' and 1 or 0,v.range=='UP_DOWN' and 1 or 0
   for _,sign in ipairs({-1,1})do
    for step=1,math.max(w,h)do
     local cx,cz=v.x+dx*step*sign,v.y+dz*step*sign
     if cx<0 or cz<0 or cx>=w/2 or cz>=h/2 or not map:isWalkableCell(cx,cz)then break end
     local warp=false;for _,p in ipairs(map.def.warps or {})do if p.x==cx and p.y==cz then warp=true end end
     if warp then break end
     q[1]=math.min(q[1],cx*16-8);q[2]=math.min(q[2],cz*16-8)
     q[3]=math.max(q[3],cx*16+24);q[4]=math.max(q[4],cz*16+24)
    end
   end
  end
  A.actors[#A.actors+1]=q
 end end
 if map.id=='ROUTE_17' then
  -- Continue every east/west paved connector through the lawn verge to its
  -- parallel lane. A bench fits on grass but must not seal this junction.
  for z=2,h-3 do for x=2,w-3 do if path(x,z)then
   for _,dx in ipairs({-1,1})do
    if lawn(x+dx,z) and path(x-dx,z) and path(x-dx*2,z) and path(x-dx*3,z) and path(x-dx*4,z)then
     for step=1,8 do
      local xx=x+dx*step
      if not lawn(xx,z)then break end
      A.routes[#A.routes+1]={xx*8-4,z*8-4,xx*8+12,z*8+12}
     end
    end
   end
  end end end
 end
 function A.actorBlocked(q)for _,r in ipairs(A.actors)do if overlap(q,r)then return true end end;return false end
 function A.routeBlocked(q)for _,r in ipairs(A.routes)do if overlap(q,r)then return true end end;return false end
 function A.reserve(q)A.routes[#A.routes+1]=q end
 return A
end
return M
