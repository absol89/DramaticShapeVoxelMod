local V=...;local C=V.require('SurfaceCraft');local M={}
function M.draw(g,detail)
 detail=detail or 1
 local colors={{.66,.65,.59},{.59,.36,.28},{.64,.44,.33},{.42,.28,.26}}
 for band=0,3 do
  local ox=(band%2)*64;local oy=400+math.floor(band/2)*48;local base=colors[band+1]
  for iy=0,48*detail-1 do for ix=0,64*detail-1 do
   local x,y=ix/detail,iy/detail
   local grain=(C.field(x/2,y/2,8310)-.5)*.045+(C.hash(ix,iy,8311)-.5)*.085
   local fleck=C.hash(ix,iy,8312)>.99 and .085 or 0
   g.setColor(base[1]+grain+fleck,base[2]+grain+fleck,base[3]+grain+fleck,1)
   g.rectangle('fill',ox+x,oy+y,1/detail,1/detail)
  end end
 end
end
return M
