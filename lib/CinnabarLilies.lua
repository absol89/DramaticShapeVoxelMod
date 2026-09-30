-- TEST123: complete, world-anchored pads in selected sheltered shore pockets.
-- No source-map edits, collision, or plants in open sea / dock approaches.
local V=...;local C=V.require('SurfaceCraft');local Gardens=V.require('WorldGardens')
local M={VISUAL_ID='legendary:cinnabar-water-plants'}
function M.sites(x,z,classAt,warps,checked)
 local result={}
 for _,site in ipairs(Gardens.lilySites(x,z))do
  local cx,cz,r=site[1],site[2],site[3]+1.1
  local key=string.format('%.9f:%.9f',cx,cz)
  local safe=checked[key]
  if safe==nil then
   safe=true
   -- Include every tile touched by the pad, its smaller partner and flower.
   for tz=math.floor((cz-r)/8),math.floor((cz+r)/8)do
    for tx=math.floor((cx-r)/8),math.floor((cx+r)/8)do
     if classAt(tx,tz)~='water' then safe=false end
    end
   end
   for _,warp in ipairs(warps or {})do
    if math.abs(cx-(warp.x*16+8))<36+r and math.abs(cz-(warp.y*16+8))<36+r then safe=false end
   end
   local tx,tz=math.floor(cx/8),math.floor(cz/8);local bank=false
   for dz=-3,3 do for dx=-3,3 do
    local class=classAt(tx+dx,tz+dz)
    if class=='dock' then safe=false end
    if class=='ground' or class=='ledge' or class=='wall' then bank=true end
   end end
   safe=safe and bank and C.field(cx/39,cz/39,910)>.36
   checked[key]=safe
  end
  if safe then result[#result+1]=site end
 end
 return result
end
return M
