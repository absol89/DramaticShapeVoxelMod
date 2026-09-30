-- Original sculpted reserve mascot: continuous bronze forms on a stone plinth.
-- Replaces only statues in the four outdoor Safari areas, within the same 16px base.
local V=...;local M={};local template,vertices
function M.quads()
 if template then return template end
 local G=V.require('CityMesh').new({.5/128,.5/48})
 local function mass(x,y,z,rx,ry,rz,mat)
  local rows={};local small=math.max(rx,ry,rz)<1;local n=small and 8 or 12;local lat=small and 4 or 8
  for j=0,lat do rows[j+1]={};local a=-math.pi/2+j*math.pi/lat
   for i=0,n-1 do local b=i*2*math.pi/n;rows[j+1][i+1]={x+math.cos(a)*math.cos(b)*rx,y+math.sin(a)*ry,z+math.cos(a)*math.sin(b)*rz}end
  end
  for j=1,lat do for i=1,n do local k=i%n+1;G.face(rows[j][i],rows[j][k],rows[j+1][k],rows[j+1][i],mat,.74+.055*(i%3))end end
 end
 -- Chamfered plinth courses and a recessed band catch edge light. Keep the
 -- established mascot, palette and exact source-sized pedestal footprint.
 local function plinth(lo,hi,r,mat,tone)
  local corners={{-1,-.76},{-.76,-1},{.76,-1},{1,-.76},{1,.76},{.76,1},{-.76,1},{-1,.76}}
  for i,p in ipairs(corners)do local q=corners[i%8+1]
   local a,b={8+p[1]*r,lo,8+p[2]*r},{8+q[1]*r,lo,8+q[2]*r}
   local c,d={b[1],hi,b[3]},{a[1],hi,a[3]}
   G.face(a,b,c,d,mat,tone);G.face(d,c,{8,hi,8},{8,hi,8},mat,tone*1.04)
  end
 end
 plinth(0,.65,7.75,'slate',.95)
 plinth(.65,.88,7.24,'stone',1)
 plinth(.88,1.83,6.95,'stone',.91)
 plinth(1.83,2.1,7.15,'slate',.91)
 plinth(2.1,2.6,6.5,'stone',.98)
 mass(8,8.4,8,4.3,5.6,3.2,'gold');mass(8,14,8,3.8,3.6,3,'gold')
 mass(5.1,3.6,10.7,2.0,1.2,2.2,'gold');mass(10.9,3.6,10.7,2.0,1.2,2.2,'gold')
 mass(3.8,9,8.7,1.1,3.1,1.35,'gold');mass(12.2,9,8.7,1.1,3.1,1.35,'gold')
 mass(8,7.5,10.65,2.8,3.5,.65,'stone');mass(8,12.1,10.75,2.4,1.25,1.3,'gold')
 for _,x in ipairs({5.6,10.4})do
  G.beam({x,15.4,8},{x+(x<8 and -.6 or .6),18.7,7.6},1.3,'gold',.87)
  mass(x,14.3,10.15,.72,.88,.42,'dark');mass(x+.08,14.4,10.5,.27,.38,.14,'stone')
 end
 for i=0,7 do local a,b=i*math.pi/4,(i+1)*math.pi/4
  G.face({8+math.cos(a)*.65,12.7+math.sin(a)*.45,11.65},{8+math.cos(b)*.65,12.7+math.sin(b)*.45,11.65},{8,14.8,13},{8,14.8,13},'stone',.9+i*.018)
 end
 G.beam({6.3,11.8,11.7},{9.7,11.8,11.7},.16,'dark',.8)
 for _,x in ipairs({6.6,9.4})do G.box(x-.14,11.45,11.7,x+.14,12.05,11.83,'white',.9)end
 -- Raised flank markings and a low tail stay within the occupied cell.
 for _,side in ipairs({-1,1})do for j=0,2 do mass(8+side*3.55,6+j*2.2,8.8,.22,.38,.5,'sage')end end
 mass(8,4.6,4.4,1.5,1.5,2.4,'gold')
 G.box(5.1,.90,14.96,10.9,1.70,15.02,'dark',.95)
 for _,x in ipairs({5.35,10.65})do G.box(x-.07,1.17,15.025,x+.07,1.31,15.06,'gold',.9)end
 for j=0,2 do G.box(6.1,1.04+j*.19,15.025,9.9-j*.35,1.095+j*.19,15.04,'stone',1)end
 template=G.out;return template
end
function M.template()
 if vertices then return vertices end
 local out={};local R=V.require('ReferenceMaterials')
 for _,q in ipairs(M.quads())do local face={}
  local shades=R.encode(q.referenceMaterial,q.shade)
  for i,p in ipairs(q)do if i<=4 then face[i]={p[1],p[2],p[3],.5/128,.5/48,type(shades)=='table'and shades[i]or shades}end end
  out[#out+1]=face
 end
 vertices=out;return out
end
return M
