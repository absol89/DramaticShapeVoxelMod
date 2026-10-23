-- Organic turf texture generated once in the shared atlas. No periodic stripes.
local V=...;local C=V and V.require('SurfaceCraft') or assert(loadfile('lib/SurfaceCraft.lua'))()
local M={}
function M.draw(g,x,y,size,id,autumn)
 local lavender=id=='LAVENDER_TOWN'
 -- TEST135: fall bakes the same turf through the dry-grass ramp, then adds
 -- sparse fallen leaves. Summer colors are unchanged.
 local A=autumn and V and V.require('AutumnGround')
 local setColor=g.setColor
 if A then
  local raw=g.setColor
  setColor=function(r,gg,b,a)local c=A.color({r,gg,b});raw(c[1],c[2],c[3],a or 1)end
 end
 local g0=g;g=setmetatable({setColor=setColor},{__index=g0})
 local cell=size/64
 for j=0,63 do for i=0,63 do
  -- Tile-periodic value noise keeps texture edges compatible; broad world
  -- variation is emitted independently by WorldGardens.
  local function periodic(a,b,s)return C.hash(a%8,b%8,s)end
  local a,b=i/8,j/8;local ix,iz=math.floor(a),math.floor(b);local u,v=a-ix,b-iz
  u=u*u*(3-2*u);v=v*v*(3-2*v)
  local n=(periodic(ix,iz,7)*(1-u)+periodic(ix+1,iz,7)*u)*(1-v)+(periodic(ix,iz+1,7)*(1-u)+periodic(ix+1,iz+1,7)*u)*v
  local grain=C.hash(i,j,61);local k=(n-.5)*(lavender and .14 or .054)+(grain-.5)*(lavender and .045 or .028)
  if lavender then
   local dry=C.hash(math.floor(i/4),math.floor(j/4),67)
   g.setColor(.235+k*.85+dry*.025,.335+k,.175+k*.45,1)
  else g.setColor(.245+k*.62,.35+k,.20+k*.48,1) end
  g.rectangle('fill',x+i*cell,y+j*cell,cell,cell)
 end end
 for i=0,2100 do
  local a=C.hash(i,3,62)*62+.5;local b=C.hash(i,7,63)*61+.5
  local t=C.hash(i,11,64);if lavender then g.setColor(.24+t*.10,.33+t*.115,.15+t*.08,1)
  else g.setColor(.26+t*.045,.37+t*.055,.20+t*.055,1) end
  g.rectangle('fill',x+a*cell,y+b*cell,cell*(.22+t*.25),cell*(.55+t*1.4))
 end
 if A then
  -- Leaf litter: small tilted flecks in clusters, wrapped inside the tile
  -- so repeats join without a cut leaf at the edge.
  for i=0,129 do
   local cluster=math.floor(i/5)
   local ca,cb=C.hash(cluster,5,401)*52+6,C.hash(cluster,9,402)*52+6
   local a=ca+(C.hash(i,13,403)-.5)*16;local b=cb+(C.hash(i,17,404)-.5)*16
   if a>.5 and a<61.5 and b>.5 and b<61.5 then
    local leaf=A.LEAVES[1+math.floor(C.hash(i,19,405)*#A.LEAVES)%#A.LEAVES]
    local t=.80+C.hash(i,23,406)*.25
    local w=cell*(1.1+C.hash(i,29,407)*.7)
    local h=cell*(.9+C.hash(i,31,408)*.6)
    -- a darker underside first, then the lit leaf, so each reads as a shape
    g0.setColor(leaf[1]*t*.60,leaf[2]*t*.60,leaf[3]*t*.60,1)
    g0.rectangle('fill',x+a*cell+cell*.25,y+b*cell+cell*.25,w,h)
    g0.setColor(leaf[1]*t,leaf[2]*t,leaf[3]*t,1)
    g0.rectangle('fill',x+a*cell,y+b*cell,w,h)
   end
  end
 end
end
return M
