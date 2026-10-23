-- Authored, rounded observation viewers. Source map cells still own all
-- collision and interaction; replace only complete original binocular art.
local V=...;local M={};local P=V.require('ScenicProfiles')
local Mat=V.require('Mat4');local mesh,white
function M.placements(map)
 local out={}
 if not(map and map.def and map.def.generation~=2 and P.gates[map.id] and map.tileAt)then return out end
 for y=0,map.def.height*4-3 do for x=0,map.def.width*4-2 do
  if P.binocularArt(map,x,y)then out[#out+1]={tx=x,ty=y,x=x*8+8,z=y*8+20}end
 end end
 return out
end
local function key(x,y)return (y+64)*4096+x+64 end
function M.build(S,map)
 for _,p in ipairs(M.placements(map))do
  for y=p.ty,p.ty+2 do for x=p.tx,p.tx+1 do
   local k=key(x,y);S.skip[k]=true;S.ground[k]=false
   S.shapeAt[k]={class='ground',h=0,flat=true,art='flat',authored=true}
  end end
 end
end
function M.geometry()
 local G=V.require('RedsHouseRoom').kit.builder()
 -- Cast base, tapered pedestal, pivot and a narrow brass identification plate.
 G.cyl(0,0,.8,0,6.8,6.8,'ktObsidian',24,.9)
 G.cyl(0,.8,2.3,0,6.8,5.5,'ktSteel',24,.96)
 G.cyl(0,2.3,3,0,5.5,4.7,'ktSteel',24,1.05)
 G.cyl(0,3,17,0,2.1,1.55,'ktSteel',20,1.02)
 G.cyl(0,3,4.2,0,2.5,2.5,'ktObsidian',20,1)
 G.box(-2.4,16,-2,2.4,20,2,'ktObsidian',1)
 G.box(-1.8,12.4,1.9,1.8,14,2.15,'gold',1.12)
 G.box(-4.1,19,-.7,4.1,21,.7,'ktSteel',1)
 local function barrel(x,z0,z1,r0,r1,material,tone)
  for i=0,23 do
   local a,b=i*math.pi/12,(i+1)*math.pi/12
   local function q(r,angle,z)return {x+r*math.cos(angle),22+r*math.sin(angle),z}end
   G.face(q(r0,a,z0),q(r0,b,z0),q(r1,b,z1),q(r1,a,z1),material,(tone or 1)*(.88+.12*math.sin(a)))
  end
 end
 for _,x in ipairs({-3.4,3.4})do
  barrel(x,-5,3,3.15,2.65,'ktSteel',1)
  barrel(x,-5.8,-4.8,3.3,3.3,'ktObsidian',.9)
  barrel(x,-5.85,-5.8,2.6,3.2,'gold',1.1)
  barrel(x,3,4.5,2.7,2.35,'ktObsidian',1)
  barrel(x,4.5,5.3,2.35,2.35,'ktObsidian',.8)
  G.disc(x,22,5.31,1.85,'ktMarine',1.15,24,true)
  G.disc(x,22,-5.86,2.65,'ktMarine',1.05,24,true)
  G.disc(x-.65,22.7,5.32,.52,'ktPearl',1.05,16,true)
  G.disc(x-.9,22.9,-5.87,.7,'ktPearl',1.05,16,true)
 end
 -- Central focus wheel and side grips.
 G.cyl(0,21.6,24,1.7,.9,.9,'ktObsidian',16,1)
 G.box(-7.1,19,-1,-6.3,23,2.5,'ktObsidian',.9)
 G.box(6.3,19,-1,7.1,23,2.5,'ktObsidian',.9)
 return G.vs,G.ix
end
function M.draw(map,shadow)
 local placements=M.placements(map);if #placements==0 then return end
 local R=V.require('Voxel3D')
 if not mesh then local v,ix=M.geometry();mesh=R.newMesh(v,ix)end
 if not white then
  local data=love.image.newImageData(1,1);data:setPixel(0,0,1,1,1,1)
  white=love.graphics.newImage(data);white:setFilter('nearest','nearest');data:release()
 end
 for _,p in ipairs(placements)do
  local model=Mat.translate(p.x,0,p.z)
  if shadow then shadow.draw(mesh,white,model)else R.draw(mesh,white,model)end
 end
end
function M.invalidate()
 if mesh then mesh:release();mesh=nil end
 if white then white:release();white=nil end
end
return M
