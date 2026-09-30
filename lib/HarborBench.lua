local V=...
local C=V and V.require('SurfaceCraft') or assert(loadfile('lib/SurfaceCraft.lua'))()
local M={}
-- World-space bench, clipped into each participating terrain tile.
function M.build(x,z,h,f,emit)
 local G=C.builder(x,z,emit)
 local function pos(u,v)
  v=v*(f.depthScale or 1)
  if f.edge=='n' then return f.cx+u,f.cz+v elseif f.edge=='s' then return f.cx+u,f.cz-v
  elseif f.edge=='w' then return f.cx+v,f.cz+u else return f.cx-v,f.cz+u end
 end
 local function box(u,v,a,b,lo,hi,mat,t)
  local px,pz=pos(u,v);local qx,qz=pos(a,b)
  G.box(math.min(px,qx),math.min(pz,qz),math.max(px,qx),math.max(pz,qz),h+lo,h+hi,mat,t)
 end
 -- 18 units long; seating surface at 5.8, back at 11.3.
 for _,u in ipairs({-8.4,7.9})do
  for _,v in ipairs({-.9,2.0})do
   box(u,v,u+.5,v+.5,.25,5.45,'shadow',.40)
   box(u-.25,v-.2,u+.75,v+.7,.22,.48,'shadow',.48)
  end
  box(u,-1,u+.5,-.5,4.9,11.35,'shadow',.44)
  box(u,-1,u+.5,2.7,7.6,8.0,'wood',.84)
  box(u,2.1,u+.5,2.6,5.4,7.6,'shadow',.44)
 end
 for j=0,3 do box(-9,-1+j*.94,9,-.18+j*.94,5.25,5.8,'wood',.91+j*.025)end
 for j=0,2 do box(-9,-1.1,9,-.65,7+j*1.48,8.12+j*1.48,'wood',.92+j*.025)end
 box(-8.15,.65,8.15,1.05,2.65,3.05,'shadow',.5)
 -- Metal fasteners on back slats, visible at the walking camera.
 for _,u in ipairs({-8.15,8.15})do for j=0,2 do
  box(u-.1,-.64,u+.1,-.60,7.4+j*1.48,7.6+j*1.48,'light',.65)
 end end
end
return M
