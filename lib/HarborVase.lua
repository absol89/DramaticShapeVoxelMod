local V=...
local C=V and V.require('SurfaceCraft') or assert(loadfile('lib/SurfaceCraft.lua'))()
local M={}
function M.build(x,z,h,f,emit)
 local G=C.builder(x,z,emit);local cx,cz=f.x,f.z
 local function p(a,r,y)return {cx+math.cos(a)*r,h+y,cz+math.sin(a)*r}end
 -- Tapered terracotta vessel, raised foot, wide shoulder and rolled pale rim.
 local rings={{1.45,.25},{1.65,.65},{1.5,1.0},{2.35,5.3},{2.6,5.6},{2.6,6.15},{2.12,6.15},{2.06,5.65}}
 for k=1,#rings-1 do
  local a,b=rings[k],rings[k+1]
  for j=0,7 do
   local u,v=j*math.pi/4,(j+1)*math.pi/4
   G.face({p(u,a[1],a[2]),p(v,a[1],a[2]),p(v,b[1],b[2]),p(u,b[1],b[2])},k>=5 and 'sand' or 'cinder',.84+(j%3)*.06)
  end
 end
 for j=0,7 do
  local a,b=j*math.pi/4,(j+1)*math.pi/4
  G.face({{cx,h+5.68,cz},p(a,2.05,5.68),p(b,2.05,5.68)},'shadow',.52)
  -- Narrow decorative band around the pot's shoulder.
  G.face({p(a,2.37,4.9),p(b,2.37,4.9),p(b,2.39,5.12),p(a,2.39,5.12)},'sand',.91)
 end
 -- Two tiers of broad curved leaves, with a raised central ridge.
 local phase=C.hash(f.seed,0,4101)*6.28
 for tier=0,1 do for j=0,5 do
  local a=phase+j*math.pi/3+tier*.43
  local dx,dz=math.cos(a),math.sin(a)
  local reach=tier==0 and 3.35 or 2.25
  local high=(tier==0 and 9.5 or 13.1)+C.hash(f.seed,j+tier*9,4102)*1.1
  local root={cx,h+5.7,cz}
  local mid={cx+dx*reach*.5,h+high,cz+dz*reach*.5}
  local left={mid[1]-dz*.72,mid[2]-.45,mid[3]+dx*.72}
  local right={mid[1]+dz*.72,mid[2]-.45,mid[3]-dx*.72}
  local tip={cx+dx*reach,h+high-1.8,cz+dz*reach}
  for k,t in ipairs({{root,left,mid},{left,tip,mid},{tip,right,mid},{right,root,mid}})do
   local tone=.86+tier*.1+(k%2)*.14
   G.face(t,'leaf',tone);G.face({t[3],t[2],t[1]},'leaf',tone*.88)
  end
 end end
end
return M
