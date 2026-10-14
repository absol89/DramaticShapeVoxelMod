-- Live item actors only: no static copies, no changes to pickup scripts.
local V=...
local M={}
M.setting=V.require('ModSetting').new('itemBall','ITEM BALL',
 {'default','legendary'},{'BATTLE ART','LEGENDARY VISUALS'})
function M.enabled() return M.setting:get()=='legendary' end
local mesh,texture
local function ballDef(d)
 return type(d)=='table'and(d.id=='SPRITE_POKE_BALL' or d.sprite=='SPRITE_POKE_BALL'
  or d.image=='assets/generated/sprites/poke_ball.png')
end
function M.accepts(c)
 if not c or c.isPlayer or c.role=='player' then return false end
 local p=c.pose or c
 local e=c.entity or c.actor or p.entity
 local sprite=c.sprite or p.sprite
 return c.spriteId=='SPRITE_POKE_BALL' or ballDef(sprite and sprite.def)
  or ballDef(e and e.def) or ballDef(e and e.spriteDef)
  or ballDef(e and e.sprite and e.sprite.def)
end

function M.geometry()
 local vs,ix={},{}
 local function quad(a,b,c,d,col)
  local n=#vs
  for _,p in ipairs({a,b,c,d})do
   local shade=.85+.12*(p[2]-4.5)/4.5+.08*p[3]/4.5
   vs[#vs+1]={p[1],p[2],p[3],(col-.5)/4,.5,shade}
  end
  for _,i in ipairs({1,2,3,1,3,4})do ix[#ix+1]=n+i end
 end
 local edge=math.acos(.35/4.5)
 local rings={}
 for i=0,8 do rings[#rings+1]=edge*i/8 end
 rings[#rings+1]=math.pi-edge
 for i=1,8 do rings[#rings+1]=math.pi-edge+edge*i/8 end
 local function p(t,a)return {4.5*math.sin(t)*math.cos(a),4.5+4.5*math.cos(t),4.5*math.sin(t)*math.sin(a)}end
 for j=1,#rings-1 do for i=0,23 do
  local a,b=i*math.pi/12,(i+1)*math.pi/12
  local col=j<=8 and 1 or(j==9 and 3 or 2)
  quad(p(rings[j],a),p(rings[j],b),p(rings[j+1],b),p(rings[j+1],a),col)
 end end
 local function button(radius,z,depth,col)
  for i=0,23 do
   local a,b=i*math.pi/12,(i+1)*math.pi/12
   local x,y=radius*math.cos(a),4.5+radius*math.sin(a)
   local X,Y=radius*math.cos(b),4.5+radius*math.sin(b)
   quad({0,4.5,z+depth},{x,y,z+depth},{X,Y,z+depth},{0,4.5,z+depth},col)
   quad({x,y,z},{X,Y,z},{X,Y,z+depth},{x,y,z+depth},col)
  end
 end
 button(1.3,4.27,.3,3);button(.88,4.57,.2,4);button(.64,4.77,.06,2)
 return vs,ix
end
local function prepare()
 if mesh then return end
 local v,i=M.geometry();mesh=V.require('Voxel3D').newMesh(v,i)
 local d=love.image.newImageData(4,1)
 local colors={{.82,.035,.025},{.90,.91,.92},{.035,.04,.05},{.38,.41,.44}}
 for i,c in ipairs(colors)do d:setPixel(i-1,0,c[1],c[2],c[3],1)end
 texture=love.graphics.newImage(d);texture:setFilter('nearest','nearest');d:release()
end
function M.transform(c,reflection)
 local A=V.require('Mat4')
 local p=c.pose or c
 local model=A.translate((c.px or p.px)+8,(c.groundHeight or p.gh or 0)+(c.lift or p.lift or 0),(c.py or p.py)+8)
 if reflection and c.reflectionPlane then
  model=A.mul(A.translate(0,2*c.reflectionPlane+(c.reflectionRaise or 0),0),A.mul(A.scale(1,-1,1),model))
 end
 return model
end
function M.draw(c,shadow)
 if not M.enabled() or not M.accepts(c)then return false end
 prepare()
 local model=M.transform(c,not shadow)
 if shadow then shadow.draw(mesh,texture,model)
 else V.require('Voxel3D').draw(mesh,texture,model)end
 return true
end
function M.invalidate()
 if mesh then mesh:release();texture:release();mesh,texture=nil,nil end
end
return M
