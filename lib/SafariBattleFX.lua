-- Legendary Safari presentation. Engine choices, RNG and queues remain owners.
-- No input polling, gameplay writes, new shader or per-frame mesh allocation.
local V=...;local M={DURATION=1.28,CONTACT=.78,ROCK_SCALE=.565}
local actions=setmetatable({},{__mode='k'});local meshes={};local palette;local resourceFailed=false
local function pack(...)return {n=select('#',...),...}end
local function finite(n)return type(n)=='number'and n==n and math.abs(n)<1e7 end
local function time(b)return (tonumber(b and b.frame)or 0)/60 end
function M.start(b,kind)
 if not(b and b.safari)or(kind~='bait'and kind~='rock')then return false end
 actions[b]={kind=kind,started=time(b)};return true
end
function M.clear(b)if b then actions[b]=nil else actions=setmetatable({},{__mode='k'})end end
function M.action(b)
 local a=actions[b];if not a then return end
 local age=math.max(0,time(b)-a.started)
 if age>M.DURATION or b.result or not b.safari then actions[b]=nil;return end
 return a,age
end
function M.install(BattleState,active)
 if BattleState.legendarySafariFX114 or type(BattleState.safariAction)~='function'then return false end
 local inner=BattleState.safariAction
 BattleState.safariAction=function(self,choice,...)
  local eligible=self.safari and self.phase=='menu'and (choice=='bait'or choice=='rock')and active(self)
  -- Run exactly once before adding presentation; preserve its returns/errors.
  local result=pack(inner(self,choice,...))
  if eligible and not self.result then M.start(self,choice)end
  return unpack(result,1,result.n)
 end
 BattleState.legendarySafariFX114=true;return true
end
-- A source-owned 3D character, using the same documented bridge as free roam.
-- Never invent a player Pokemon to make an ordinary-battle callback accept it.
function M.drawTrainer(state,battle,arena,groundY)
 if not(battle and battle.safari and not battle.demo and arena and state and state.player)
    or not V.require('OverworldBattle').legendaryTrainerEnabled()then return false end
 local CR=V.require('CharacterRenderers');local Mat4=V.require('Mat4')
 local R=V.require('Voxel3D');local Shadow=V.require('ShadowMap')
 local a,age=M.action(battle)
 local action=a and {kind=a.kind,time=age,duration=M.DURATION}or nil
 local ctx={state=state,battle=battle,arena=arena,groundY=groundY,safariAction=action,
  host={Voxel3D=R,Mat4=Mat4,ShadowMap=Shadow},
  setHandWorld=function(p)CR.setBattleHand(p)end}
 CR.setBattleHand(nil)
 if CR.first('drawBattleTrainer',ctx)then return true end
 local entity=state.player;local sprite=entity.sprite
 if not sprite then return false end
 local dx,dz=arena.enemy[1]-arena.player[1],arena.enemy[2]-arena.player[2]
 local facing=math.abs(dx)>math.abs(dz)and(dx>0 and 'right'or 'left')or(dz>0 and 'down'or 'up')
 local pose={entity=entity,sprite=sprite,px=arena.player[1]-8,py=arena.player[2]-8,
  gh=groundY,phase=0,flip=false,lift=0,isPlayer=true,role='player',facing=facing}
 -- actorContext retains all host facilities and the real selected player ID.
 local scene=V.require('VoxelScene');local context=scene.characterContext(state,pose)
 context.facing=facing;context.battle=battle;context.safariAction=action
 return CR.first('drawEntity',context)
end
local function anchor(a,arena,groundY,hand,battle)
 if a.origin then return end
 local p,e=arena.player,arena.enemy
 local dx,dz=e[1]-p[1],e[2]-p[2];local len=math.max(.001,math.sqrt(dx*dx+dz*dz))
 dx,dz=dx/len,dz/len
 local origin={p[1]-dz*3,groundY+12,p[2]+dx*3}
 if type(hand)=='table'and finite(hand[1])and finite(hand[2])and finite(hand[3])
    and (hand[1]-p[1])^2+(hand[3]-p[2])^2<24^2 and hand[2]>groundY+2 and hand[2]<groundY+40 then
  origin={hand[1],hand[2],hand[3]}
 end
 local enemyGround=V.require('SafariFooting').ground(battle,arena,'enemy',groundY)
 a.origin=origin;a.target={e[1]-dx*(a.kind=='rock'and 1.5 or 5),enemyGround+(a.kind=='rock'and 7 or .8),e[2]-dz*(a.kind=='rock'and 1.5 or 5)}
 a.direction={dx,dz};a.ground=enemyGround;a.arc=math.min(15,math.max(8,len*.19))
end
-- Presentation-only recoil: no native picFx, HP, AI, queue or RNG writes.
function M.recoil(b)
 local a,t=M.action(b);if not a or a.kind~='rock'then return 0 end
 local q=(t-M.CONTACT)/.34;if q<=0 or q>=1 then return 0 end
 return math.sin(q*math.pi)*math.exp(-q*1.8)
end
local function hitTarget(a)
 if a.impact then return a.impact end
 return a.observed or a.target
end
-- Use the rendered enemy's bind metrics and world matrix. Target the body,
-- not a fixed spot five pixels in front of every species. Freeze on contact.
function M.model(b,side,model,metrics,arena)
 local a,t=M.action(b)
 if side~='enemy'or not a or a.kind~='rock'or not arena then return model end
 local Mat4=V.require('Mat4');local p,e=arena.player,arena.enemy
 local dx,dz=e[1]-p[1],e[2]-p[2];local len=math.max(.001,math.sqrt(dx*dx+dz*dz));dx,dz=dx/len,dz/len
 if metrics and finite(metrics.height)and metrics.height>0 then
  local bounds=metrics.bounds or {};local h=metrics.height
  local cx,cz=tonumber(bounds.cx)or 0,tonumber(bounds.cz)or 0
  local cy=(tonumber(bounds.minY)or tonumber(metrics.floor)or 0)+h*.46
  local function point(x,y,z)return{model[1]*x+model[2]*y+model[3]*z+model[4],model[5]*x+model[6]*y+model[7]*z+model[8],model[9]*x+model[10]*y+model[11]*z+model[12]}end
  local center=point(cx,cy,cz)
  local rx=math.max(.1,((tonumber(bounds.maxX)or h*.3)-(tonumber(bounds.minX)or -h*.3))*.5)
  local rz=math.max(.1,((tonumber(bounds.maxZ)or h*.3)-(tonumber(bounds.minZ)or -h*.3))*.5)
  local radius=math.abs(dx*model[1]+dz*model[9])*rx+math.abs(dx*model[3]+dz*model[11])*rz
  radius=math.max(.6,math.min(8,radius*.55))
  if not a.impact then a.observed={center[1]-dx*radius,center[2],center[3]-dz*radius}end
 end
 local amount=M.recoil(b)
 if amount==0 then return model end
 return Mat4.mul(Mat4.translate(dx*2.8*amount,.55*amount,dz*2.8*amount),model)
end
-- Pure pose function, also used by the headless trajectory/cleanup checks.
function M.poses(b,arena,groundY,hand)
 local a,age=M.action(b);if not a or not(arena and arena.player and arena.enemy)then return{}end
 anchor(a,arena,groundY,hand,b)
 local out={};local dx,dz=a.direction[1],a.direction[2]
 local target=a.kind=='rock'and hitTarget(a)or a.target
 if a.kind=='rock'and age>=M.CONTACT and not a.impact then
  a.impact={target[1],target[2],target[3]};target=a.impact
 end
 local count=a.kind=='bait'and 3 or 1
 for i=1,count do
  local t=age-(i-1)*.042;local s=math.max(0,math.min(1,(t-.14)/.64))
  local x=a.origin[1]+(target[1]-a.origin[1])*s
  local y=a.origin[2]+(target[2]-a.origin[2])*s+4*a.arc*s*(1-s)
  local z=a.origin[3]+(target[3]-a.origin[3])*s
  local size=a.kind=='bait'and (.83-(i-1)*.13)or M.ROCK_SCALE
  if t<.14 then local wind=math.sin(math.max(0,t)/.14*math.pi)
   x=x-dx*1.6*wind;y=y+.9*wind;z=z-dz*1.6*wind
  end
  if count>1 then local spread=(i-2)*1.15*s;x=x-dz*spread;z=z+dx*spread end
  if s>=1 then
   local q=math.min(1,(t-.78)/.32)
   local side=a.kind=='rock'and 4 or .7*(i-2)
   x=x-dz*side*q;z=z+dx*side*q
   -- Ricochet toward the thrower, then settle beside the opponent.
   if a.kind=='rock'then x=x-dx*3.5*q;z=z-dz*3.5*q end
   y=target[2]+(a.ground+.7-target[2])*q+2.4*math.sin(q*math.pi)
   size=size*math.max(0,math.min(1,(M.DURATION-age)/.15))
  end
  if size>.01 then out[#out+1]={kind=a.kind,x=x,y=y,z=z,scale=size,
    yaw=t*7+(i-1)*2,roll=t*(a.kind=='rock'and 10 or 6)}end
 end
 -- Four tiny bright contact motes expand for 0.18 s; the same cached mesh
 -- serves every hit. No full-screen flash or per-frame resource allocation.
 if a.kind=='rock'and age>=M.CONTACT and age<M.CONTACT+.18 then
  local q=(age-M.CONTACT)/.18
  for i=1,4 do local angle=(i-1)*math.pi/2+.4;local radius=.4+q*2.2
   out[#out+1]={kind='impact',x=target[1]-dz*math.cos(angle)*radius-dx*.45,
    y=target[2]+math.sin(angle)*radius,z=target[3]+dx*math.cos(angle)*radius-dz*.45,
    scale=.24*(1-q),yaw=angle,roll=angle}
  end
 end
 return out
end
function M.geometry(kind)
 local verts,indices={},{}
 local function triangle(a,b,c,slot)
  local n=#verts;local ux,uy,uz=b[1]-a[1],b[2]-a[2],b[3]-a[3]
  local vx,vy,vz=c[1]-a[1],c[2]-a[2],c[3]-a[3]
  local nx,ny,nz=uy*vz-uz*vy,uz*vx-ux*vz,ux*vy-uy*vx
  local len=math.sqrt(nx*nx+ny*ny+nz*nz);if len<1e-8 then return end
  local shade=.79+.18*ny/len+.06*nx/len+.10*nz/len
  for _,p in ipairs({a,b,c})do verts[#verts+1]={p[1],p[2],p[3],(slot-.5)/4,.5,shade}end
  indices[#indices+1]=n+1;indices[#indices+1]=n+2;indices[#indices+1]=n+3
 end
 local function lobe(cx,cy,cz,r,squash,slot,seed)
  local rings={}
  for j=0,4 do local lat=-math.pi/2+j*math.pi/4;rings[j+1]={}
   for i=0,7 do local angle=i*math.pi/4;local rough=1+.12*math.sin(i*2.7+j*3.2+seed)
    rings[j+1][i+1]={cx+math.cos(angle)*math.cos(lat)*r*rough,
      cy+math.sin(lat)*r*squash,cz+math.sin(angle)*math.cos(lat)*r*rough}
   end
  end
  for j=1,4 do for i=1,8 do local k=i%8+1
   triangle(rings[j][i],rings[j+1][k],rings[j][k],slot)
   triangle(rings[j][i],rings[j+1][i],rings[j+1][k],slot)
  end end
 end
 if kind=='bait'then
  lobe(0,0,0,1.45,.72,1,0);lobe(.7,.15,.15,.78,.9,2,2);lobe(-.55,.1,-.35,.72,.8,2,4)
 elseif kind=='impact'then lobe(0,0,0,1,1,4,0)
 else lobe(0,0,0,1.9,.76,3,1)end
 return verts,indices
end
local function resources(kind)
 if not palette then
  local d=love.image.newImageData(4,1)
  for i,c in ipairs({{.59,.37,.17},{.79,.61,.31},{.43,.45,.42},{1,.88,.54}})do d:setPixel(i-1,0,c[1],c[2],c[3],1)end
  palette=love.graphics.newImage(d);palette:setFilter('nearest','nearest');d:release()
 end
 if meshes[kind]==nil then
  local v,i=M.geometry(kind);meshes[kind]=V.require('Voxel3D').newMesh(v,i)or false
 end
 return meshes[kind],palette
end
function M.draw(battle,arena,groundY)
 if resourceFailed then return false end
 local poses=M.poses(battle,arena,groundY,V.require('CharacterRenderers').battleHandWorld())
 local R=V.require('Voxel3D');local Mat4=V.require('Mat4');local drawn=false
 for _,p in ipairs(poses)do
  local ok,mesh,tex=pcall(resources,p.kind)
  if not ok then resourceFailed=true;return false end
  if mesh then
   local model=Mat4.mul(Mat4.translate(p.x,p.y,p.z),Mat4.mul(Mat4.rotateY(p.yaw),Mat4.mul(Mat4.rotateZ(p.roll),Mat4.scale(p.scale,p.scale,p.scale))))
   R.draw(mesh,tex,model,0);drawn=true
  end
 end
 return drawn
end
function M.invalidate()
 M.clear();for _,m in pairs(meshes)do if m and m.release then m:release()end end
 meshes={};if palette and palette.release then palette:release()end;palette=nil;resourceFailed=false
end
return M
