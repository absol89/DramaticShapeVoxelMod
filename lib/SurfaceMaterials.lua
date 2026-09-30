-- Code-native high density material fields. Geometry supplies seams/joins.
local V=...;local C=V and V.require('SurfaceCraft') or assert(loadfile('lib/SurfaceCraft.lua'))()
local M={}
function M.stone(g,x,y,w,h,style)
 local base=style=='cinnabar' and {.46,.49,.51} or style=='brick' and {.56,.31,.22} or style=='lavender' and {.54,.56,.65} or {.60,.61,.57}
 for j=0,63 do for i=0,63 do
  if style=='cinnabar' then base=i<21 and {.46,.49,.52} or i<43 and {.49,.33,.25} or {.56,.49,.37} end
  if style=='vermilion' then base=i<21 and {.66,.63,.52} or i<43 and {.59,.30,.20} or {.36,.35,.32} end
  if style=='trail' then base=i<32 and {.56,.57,.53} or {.54,.51,.44} end
  local v=(C.field(i/11,j/11,211)-.5)*.11+(C.hash(i,j,212)-.5)*.075
  local fleck=C.hash(i,j,213)>.965 and .12 or 0
  g.setColor(base[1]+v+fleck,base[2]+v+fleck,base[3]+v+fleck,1)
  g.rectangle('fill',x+i*w/64,y+j*h/64,w/64,h/64)
 end end
end
function M.wood(g,x,y,size)
 for j=0,63 do for i=0,63 do
  local v=C.field(i*.85,j*.065,215)*.11+C.hash(i,j,216)*.032
  g.setColor(.36+v,.215+v*.8,.105+v*.5,1)
  g.rectangle('fill',x+i*size/64,y+j*size/64,size/64,size/64)
 end end
 -- End grain donor in the bottom-right quarter, separate from side grain.
 for j=0,15 do for i=0,15 do
  local d=math.sqrt((i-7.2)^2+(j-8.4)^2)
  local v=.025*math.sin(d*3)+(C.hash(i,j,217)-.5)*.04
  g.setColor(.52+v,.34+v,.18+v*.7,1)
  g.rectangle('fill',x+(48+i)*size/64,y+(48+j)*size/64,size/64,size/64)
 end end
 -- Preserve point-sampled wood roles used by the existing board builder.
 local palette={{.075,.085,.105},{.28,.16,.085},{.51,.33,.17},{.65,.46,.26}}
 for i,c in ipairs(palette)do g.setColor(c[1],c[2],c[3],1);g.rectangle('fill',x+(i-1)*size/8,y,size/8,size/8)end
end
return M
