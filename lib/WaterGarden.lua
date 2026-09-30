-- Static underwater scenery, drawn with opaque terrain before the water pass.
local V=...;local C=V and V.require('SurfaceCraft') or assert(loadfile('lib/SurfaceCraft.lua'))()
local M={}
function M.build(x,z,h,nearBank,emit)
 local G=C.builder(x,z,emit)
 local depth=(nearBank and 2.7 or 5.8)+math.floor(C.field((x+4)/24,(z+4)/24,230)*3)*.65
 local y=h-depth
 G.box(x,z,x+8,z+8,h-9,y,'body',.82+C.field(x/30,z/30,231)*.25)
 if C.hash(x,z,232)>.64 then
  local cx,cz=x+1.5+C.hash(x,z,233)*5,z+1.5+C.hash(x,z,234)*5
  G.box(cx-.65,cz-.48,cx+.65,cz+.48,y,y+.43,'body',.71)
  G.box(cx+.7,cz+.2,cx+1.2,cz+.65,y,y+.22,'light',.82)
 end
 if C.field(x/18,z/18,235)>.64 then
  for k=0,2 do
   local cx,cz=x+1.4+k*1.7,z+2+C.hash(x,k,236)*3
   local ht=math.min(depth-.5,1.1+C.hash(x+k,z,237)*1.35)
   G.box(cx-.10,cz-.10,cx+.10,cz+.10,y,y+ht,'leaf',1.2)
   for j=0,1 do G.blade(cx,cz,y+.35,ht*.65,.15,.65,j*2.1+k,'leaf',1.15+j*.15)end
  end
 end
 return depth
end
return M
