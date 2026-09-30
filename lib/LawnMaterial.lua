-- Organic turf texture generated once in the shared atlas. No periodic stripes.
local V=...;local C=V and V.require('SurfaceCraft') or assert(loadfile('lib/SurfaceCraft.lua'))()
local M={}
function M.draw(g,x,y,size,id)
 local lavender=id=='LAVENDER_TOWN'
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
end
return M
