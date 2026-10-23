-- TEST191: THE STRENGTH BOULDERS, IN THE ROUND. The boulders you push in
-- Victory Road and the Seafoam Islands were the Game Boy sprite on a card:
-- an orange disc that turned with the camera, hard to judge which cell it
-- stood in or which side you were pushing from. Now each is a solid
-- boulder sitting squarely in its cell, and it ROLLS as it is pushed (its
-- turn follows the distance it travels). Shadows and reflections draw the
-- same model.
-- TEST192: it sits ON the floor (the engine lifts every sprite four pixels;
-- a ball doesn't want that), it is faceted warm sandstone in the Game Boy
-- boulder's own brown (the granite finish read as pixel noise at this
-- size), two old cracks across it, and the push throws up a ring of real
-- dust in place of the flat Game Boy smoke tiles.
-- Live actors only, like ItemPokeballs: the engine still owns the boulder,
-- Strength, the push and the switches; this only changes how it looks.
local V=...
local M={REVISION='strength-boulders-192'}
local pi,cos,sin,floor,min,max,abs,sqrt=math.pi,math.cos,math.sin,math.floor,math.min,math.max,math.abs,math.sqrt
local mesh,texture
M.R=7.3   -- its radius (a cell is 16)
-- the palette, by u: body, light, shadowed, crack
M.PALETTE={{.66,.50,.34},{.76,.60,.42},{.54,.40,.27},{.27,.19,.12}}

local function isBoulderDef(d)
 return type(d)=='table' and(d.id=='SPRITE_BOULDER' or d.sprite=='SPRITE_BOULDER'
  or d.image=='assets/generated/sprites/boulder.png')
end
function M.accepts(c)
 if not c or c.isPlayer or c.role=='player' then return false end
 if c.spriteId=='SPRITE_BOULDER' then return true end
 local p=c.pose or c
 local e=c.entity or c.actor or p.entity
 local sprite=c.sprite or p.sprite
 return isBoulderDef(sprite and sprite.def) or isBoulderDef(e and e.def)
  or isBoulderDef(e and e.spriteDef) or isBoulderDef(e and e.sprite and e.sprite.def)
end

local function rh(a,b,s)local v=sin(a*12.9898+b*78.233+s*37.719)*43758.5453;return v-floor(v)end
-- a faceted boulder, centred R above its own origin
function M.geometry()
 local R=M.R
 local vs,ix={},{}
 local NL,NR=11,7
 local function bump(x,y,z)
  -- low, broad lumps: the rock stays round enough to roll
  return 1+.06*sin(x*3.1+y*1.7)+.05*sin(y*2.6-z*3.3)+.045*sin(z*2.2+x*2.9)
 end
 local P={}
 for j=0,NR do
  P[j]={}
  local b=-pi/2+j*pi/NR
  for i=0,NL-1 do
   local a=i/NL*pi*2+(j%2)*pi/NL
   local ux,uy,uz=cos(a)*cos(b),sin(b),sin(a)*cos(b)
   local k=(j==0 or j==NR)and 1 or bump(ux,uy,uz)
   P[j][i]={ux*R*k,R+uy*R*k,uz*R*k,ux,uy,uz}
  end
 end
 local function quad(a,b,c,d,col,shade)
  local n=#vs
  local u=(col-.5)/4
  for _,p in ipairs({a,b,c,d})do vs[#vs+1]={p[1],p[2],p[3],u,.5,shade}end
  for _,q in ipairs({1,2,3,1,3,4})do ix[#ix+1]=n+q end
 end
 for j=0,NR-1 do for i=0,NL-1 do
  local i2=(i+1)%NL
  local a,b,c,d=P[j][i],P[j][i2],P[j+1][i2],P[j+1][i]
  local ny=(a[5]+b[5]+c[5]+d[5])/4
  local nx=(a[4]+b[4]+c[4]+d[4])/4
  -- flat facets lit from above and a little south
  local sh=.70+.30*max(0,ny)+.06*nx
  local p=rh(i,j,11)
  local col=ny>.62 and 2 or(p<.25 and 3 or 1)
  -- two old cracks running round it
  local mx,my,mz=(a[4]+c[4])/2,(a[5]+c[5])/2,(a[6]+c[6])/2
  if abs(.55*mx+.30*my-.78*mz)<.04 or abs(.20*mx-.62*my+.76*mz)<.035 then col=4 end
  quad(a,b,c,d,col,sh)
 end end
 return vs,ix
end
local function prepare()
 if mesh and texture then return true end
 local m,tex,d
 local ok=pcall(function()
  local v,i=M.geometry();m=V.require('Voxel3D').newMesh(v,i)
  assert(m,'boulder mesh allocation failed')
  d=love.image.newImageData(4,1)
  for k,c in ipairs(M.PALETTE)do d:setPixel(k-1,0,c[1],c[2],c[3],1)end
  tex=love.graphics.newImage(d);tex:setFilter('nearest','nearest')
 end)
 if d and d.release then pcall(d.release,d)end
 if not ok then
  if m and m.release then pcall(m.release,m)end
  if tex and tex.release then pcall(tex.release,tex)end
  return false
 end
 mesh,texture=m,tex
 return true
end
-- where it stands, and how far it has rolled
function M.transform(c,reflection)
 local A=V.require('Mat4')
 local p=c.pose or c
 local px,py=(c.px or p.px or 0),(c.py or p.py or 0)
 -- the floor it stands on; not the sprite's four-pixel lift
 local base=(c.groundHeight or p.gh or 0)
 local R=M.R
 local id=tonumber(c.actorId)or 0
 local model=A.translate(px+8,base,py+8)
 model=A.mul(model,A.translate(0,R,0))
 -- rolling: a push east turns it about the north-south axis, a push south
 -- about the east-west one, by the arc it has travelled
 model=A.mul(model,A.rotateZ(-px/R))
 model=A.mul(model,A.rotateX(py/R))
 model=A.mul(model,A.rotateY(id*.9))  -- each boulder its own face
 model=A.mul(model,A.translate(0,-R,0))
 if reflection and c.reflectionPlane then
  model=A.mul(A.translate(0,2*c.reflectionPlane+(c.reflectionRaise or 0),0),A.mul(A.scale(1,-1,1),model))
 end
 return model
end

------------------------------------------------------------------ the dust
-- The engine's push ends in OverworldState.dustAnim {x,y,frames,total,
-- boulder=true}, drawn as Game Boy smoke tiles over the cell. While one is
-- running the smoke image is set aside (state.smokeImg=false, which its
-- drawing skips) and put back after, and the dust is drawn here round the
-- boulder that raised it: soft puffs rolling out along the floor.
local saved,savedFor=nil,nil
function M.maintain(state)
 if savedFor and savedFor~=state then
  if savedFor.smokeImg==false then savedFor.smokeImg=saved end
  saved,savedFor=nil,nil
 end
 if type(state)~='table'then return end
 local da=state.dustAnim
 if da and da.boulder then
  if savedFor~=state then saved,savedFor=state.smokeImg,state end
  state.smokeImg=false
 elseif savedFor==state then
  if state.smokeImg==false then state.smokeImg=saved end
  saved,savedFor=nil,nil
 end
end
local function drawDust(c)
 local state=c.state
 local da=state and state.dustAnim
 if not(da and da.boulder)then return end
 local p=c.pose or c
 local px,py=(c.px or p.px or 0),(c.py or p.py or 0)
 if floor((px+8)/16)~=da.x or floor((py+8)/16)~=da.y then return end
 local okK,K=pcall(function()return V.require('LeagueRoad').fxKit()end)
 if not(okK and K and K.soft and K.cross)then return end
 local Voxel3D,Mat4=V.require('Voxel3D'),V.require('Mat4')
 local total=max(1,da.total or 24)
 local u=1-max(0,min(1,(da.frames or 0)/total))
 local base=c.groundHeight or p.gh or 0
 local cx,cz=px+8,py+8
 local sx,sz=0,0
 if da.step then sx,sz=-(da.step[1]or 0),-(da.step[2]or 0)end  -- the push direction
 local g=love.graphics
 pcall(Voxel3D.withEffect,"alpha",function()
  for i=0,9 do
   local a=i/10*pi*2+rh(i,da.x,3)*.5
   local r=5.5+u*(7.5+rh(i,da.y,5)*3)
   -- more of it thrown out ahead and to the sides than back at the pusher
   local back=cos(a)*sx+sin(a)*sz
   local k=back<-.5 and .55 or 1
   local x,z=cx+cos(a)*r*k,cz+sin(a)*r*k
   local y=base+1.2+u*(2.5+rh(i,3,7)*2.5)
   local s=(2.2+u*3.6)*(.8+rh(i,7,9)*.4)
   g.setColor(.70,.62,.52,(1-u)*.55*k)
   Voxel3D.draw(K.cross,K.soft,Mat4.mul(Mat4.translate(x,y,z),Mat4.scale(s,s*.8,s)))
  end
 end)
 g.setColor(1,1,1,1)
end

function M.draw(c,shadow)
 if not M.accepts(c)then return false end
 if not prepare()then return false end
 local model=M.transform(c,not shadow)
 if shadow then shadow.draw(mesh,texture,model)
 else
  V.require('Voxel3D').draw(mesh,texture,model)
  if not c.reflectionPlane then pcall(drawDust,c)end
 end
 return true
end
function M.invalidate()
 if savedFor and savedFor.smokeImg==false then savedFor.smokeImg=saved end
 saved,savedFor=nil,nil
 if mesh and mesh.release then pcall(mesh.release,mesh)end
 if texture and texture.release then pcall(texture.release,texture)end
 mesh,texture=nil,nil
end
pcall(function()require("src.render.Assets").register(M.invalidate)end)
return M
