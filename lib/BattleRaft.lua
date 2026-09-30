-- TEST25: bounded, reusable battle-only props. No actor transforms or cache changes.
local V=...
local R=V.require('Voxel3D')
local Mat4=V.require('Mat4')
local M={}
local deck,ring,texture
local currentBattle,currentArena,trainerPoint
local swimmers={ [72]=true,[73]=true,[86]=true,[87]=true,[90]=true,[91]=true,
 [116]=true,[117]=true,[118]=true,[119]=true,[120]=true,[121]=true,
 [129]=true,[130]=true,[131]=true,[170]=true,[171]=true,[211]=true,[222]=true,[226]=true,[230]=true }
local flyers={ [12]=true,[15]=true,[16]=true,[17]=true,[18]=true,[21]=true,[22]=true,
 [41]=true,[42]=true,[49]=true,[81]=true,[82]=true,[92]=true,[93]=true,[94]=true,
 [109]=true,[110]=true,[142]=true,[144]=true,[145]=true,[146]=true,[151]=true }
function M.speciesKind(id)
 if swimmers[id] then return 'swimmer' end
 if flyers[id] then return 'air' end
 return 'land'
end
function M.kind(battle,side)
 local id=V.require('BattleArt').speciesFor(battle and battle[side])
 if type(id)~='number' then
  local def=battle and battle.data and battle.data.pokemon and battle.data.pokemon[id]
  id=def and tonumber(def.dex or def.index)
 end
 return M.speciesKind(id)
end
-- TEST127: place the body in the water, not its lowest point on the surface.
-- Fractions keep shells/faces readable and put long tentacles/fish below it.
local waterlines={ [72]=.62,[73]=.62,[86]=.38,[87]=.38,[90]=.32,[91]=.36,
 [116]=.42,[117]=.42,[118]=.50,[119]=.24,[120]=.42,[121]=.42,
 [129]=.50,[130]=.32,[131]=.28,[170]=.48,[171]=.48,[211]=.48,
 [222]=.30,[226]=.40,[230]=.42,[9]=.30,[143]=.32,[134]=.30,[149]=.30,[25]=.25 }
-- TEST128 live review: Seaking's fin-heavy silhouette needs a shallower
-- waterline so its face/body remain readable, not just its dorsal/tail fins.
function M.immersion(dex,height)
 if type(height)~='number'or height~=height or height<=0 or height>10000 then return 0 end
 return height*(waterlines[dex]or .38)
end
function M.dex(battle,side)
 local id=V.require('BattleArt').speciesFor(battle and battle[side])
 if type(id)~='number'then
  local def=battle and battle.data and battle.data.pokemon and battle.data.pokemon[id]
  id=def and tonumber(def.dex or def.index)
 end
 return id
end
-- World-space support for the Stadium model path; callers keep move flight separate.
function M.support(arena,battle,side,groundY,worldHeight,hover)
 if not V.require('CommunityVisuals').customRoads() or not M.onWater(arena.map,arena[side]) then
  return groundY,hover
 end
 local kind=M.kind(battle,side)
 if kind=='land' then return groundY,0 end
 if kind=='swimmer' then
  local waterY=(V.require('TileShape').heights() or {}).water or -2
  -- The same support matrix reaches color/shadow and preserves action lift.
  return waterY-M.immersion(M.dex(battle,side),worldHeight),0
 end
 return groundY,hover
end
function M.onWater(map,point)
 if not (map and map.isWaterCell and point) then return false end
 return map:isWaterCell(math.floor(point[1]/16),math.floor(point[2]/16))==true
end
-- Model is a 24x24 deck, top at zero. Transform scales in X/Z only.
function M.geometry(ripple)
 local vs,ix={},{}
 local function q(a,b,c,d,u,shade)
  local n=#vs
  for _,p in ipairs({a,b,c,d})do vs[#vs+1]={p[1],p[2],p[3],(u+.5)/6,.5,shade or 1}end
  for _,i in ipairs({1,2,3,1,3,4})do ix[#ix+1]=n+i end
 end
 local function box(x0,z0,x1,z1,y0,y1,u)
  q({x0,y1,z0},{x0,y1,z1},{x1,y1,z1},{x1,y1,z0},u,1)
  q({x0,y0,z0},{x1,y0,z0},{x1,y1,z0},{x0,y1,z0},u,.72)
  q({x1,y0,z1},{x0,y0,z1},{x0,y1,z1},{x1,y1,z1},u,.88)
  q({x0,y0,z1},{x0,y0,z0},{x0,y1,z0},{x0,y1,z1},u,.68)
  q({x1,y0,z0},{x1,y0,z1},{x1,y1,z1},{x1,y1,z0},u,.84)
 end
 if ripple then
  for i=0,47 do
   if i%12<9 then
    local a,b=i*math.pi/24,(i+1)*math.pi/24
    -- Taper each broken arc to a point instead of ending in a blunt stripe.
    local wa=.016*math.sin((i%12)*math.pi/9)
    local wb=.016*math.sin((i%12+1)*math.pi/9)
    q({math.cos(a),0,math.sin(a)},{math.cos(b),0,math.sin(b)},
      {(1-wb)*math.cos(b),0,(1-wb)*math.sin(b)},
      {(1-wa)*math.cos(a),0,(1-wa)*math.sin(a)},5,1)
   end
  end
 else
  for i=0,11 do
   local z=-12+i*2
   local inset=(i%4)*.10
   box(-12+inset,z+.06,12-inset,z+1.94,-1.05,0,i%3)
   for k=0,1 do
    local x=-10+k*20
    box(x-.14,z+.8,x+.14,z+1.1,0,.035,3)
   end
   -- Fine grain follows each board; retained as a single shared static mesh.
   box(-10+(i%3),z+.45,9-(i%4),z+.49,.01,.025,4)
  end
  -- Framed deck edges and cross bearers, all below the unchanged foot plane.
  for _,x in ipairs({-12.15,12.15})do
   box(x-.22,-12.25,x+.22,12.25,-1.55,-.10,1)
   for _,z in ipairs({-10,0,10})do box(x-.28,z-.28,x+.28,z+.28,-.32,-.07,3)end
  end
  for _,z in ipairs({-12.15,12.15})do box(-12.35,z-.22,12.35,z+.22,-1.55,-.10,1)end
  for _,z in ipairs({-8,8})do box(-14,z-.50,14,z+.50,-1.95,-1.10,4)end
  -- Outboard pontoons expose their curved shoulders beyond the deck edge.
  for _,x in ipairs({-12.4,12.4})do
   local function cylinder(z0,z1,r,u)
    for j=0,11 do
     local a,b=j*math.pi/6,(j+1)*math.pi/6
     q({x+r*math.cos(a),-2.7+r*math.sin(a),z0},{x+r*math.cos(b),-2.7+r*math.sin(b),z0},
       {x+r*math.cos(b),-2.7+r*math.sin(b),z1},{x+r*math.cos(a),-2.7+r*math.sin(a),z1},u,.72+.2*math.max(0,math.sin(a)))
    end
   end
   cylinder(-13.5,13.5,2.5,1)
   for _,z in ipairs({-13.5,13.5})do for j=0,11 do
    local a,b=j*math.pi/6,(j+1)*math.pi/6
    q({x,-2.7,z},{x+2.5*math.cos(a),-2.7+2.5*math.sin(a),z},
      {x+2.5*math.cos(b),-2.7+2.5*math.sin(b),z},{x,-2.7,z},1,.78)
   end end
   for _,z in ipairs({-10,0,10})do cylinder(z-.28,z+.28,2.58,3)end
  end
 end
 return vs,ix
end
local function build()
 if deck then return true end
 local d=love.image.newImageData(6,1)
 local colors={{.44,.25,.105},{.52,.31,.14},{.60,.37,.18},{.12,.13,.14},{.25,.14,.065},{.23,.38,.46}}
 for i,c in ipairs(colors)do d:setPixel(i-1,0,c[1],c[2],c[3],1)end
 local ok,t=pcall(love.graphics.newImage,d);d:release()
 if not ok then return false end
 texture=t;texture:setFilter('nearest','nearest')
 deck=R.newMesh(M.geometry(false));ring=R.newMesh(M.geometry(true))
 if not (deck and ring) then
  for _,obj in ipairs({deck or false,ring or false,texture})do if obj and obj.release then obj:release()end end
  deck,ring,texture=nil,nil,nil;return false
 end
 return true
end
function M.layout(arena,hand)
 local p,e=arena.player,arena.enemy
 local dx,dz=e[1]-p[1],e[2]-p[2];local len=math.max(.001,math.sqrt(dx*dx+dz*dz))
 local tx,tz=p[1]-dx/len*18,p[2]-dz/len*18
 if type(hand)=='table' and tonumber(hand[1]) and tonumber(hand[3]) then
  local hx,hz=tonumber(hand[1]),tonumber(hand[3])
  if (hx-p[1])^2+(hz-p[2])^2<48^2 then tx,tz=hx,hz end
 end
 return {tx,tz}
end
local function model(x,y,z,sx,sz)
 return Mat4.mul(Mat4.translate(x,y,z),Mat4.scale(sx,1,sz))
end
function M.draw(map,arena,groundY,battle)
 if not (arena and arena.player and arena.enemy and V.require('CommunityVisuals').customRoads()) then return end
 local pw,ew=M.onWater(map,arena.player),M.onWater(map,arena.enemy)
 if not (pw or ew) then return end
 if not build() then return end
 if currentBattle~=battle or currentArena~=arena then
  currentBattle,currentArena,trainerPoint=battle,arena,nil
 end
 local hand=V.require('CharacterRenderers').battleHandWorld() or rawget(_G,'RED3D_BATTLE_HAND_WORLD')
 -- Latch only a valid nearby hand; do not make the raft chase attack animations.
 if not trainerPoint and type(hand)=='table' and tonumber(hand[1]) and tonumber(hand[3]) then
  local p=arena.player
  if (tonumber(hand[1])-p[1])^2+(tonumber(hand[3])-p[2])^2<48^2 then trainerPoint=M.layout(arena,hand)end
 end
 local tp=trainerPoint or M.layout(arena)
 local waterY=(V.require('TileShape').heights() or {}).water or -2
 local time=love.timer and love.timer.getTime and love.timer.getTime() or 0
 R.glass(false)
 local function ripples(p,radius,radiusZ)
  for i=0,2 do
   local phase=(time*.20+i/3)%1
   local growth=1+phase*.16
   local size=radius*growth
   R.draw(ring,texture,model(p[1],waterY+.07+i*.02,p[2],size,(radiusZ or radius*.78)*growth))
  end
 end
 if pw then
  local p=arena.player
  if M.kind(battle,'player')=='land' then
   local x0,x1=math.min(tp[1],p[1])-9,math.max(tp[1],p[1])+9
   local z0,z1=math.min(tp[2],p[2])-9,math.max(tp[2],p[2])+9
   R.draw(deck,texture,model((x0+x1)/2,groundY-.06,(z0+z1)/2,math.max(20,x1-x0)/24,math.max(20,z1-z0)/24))
   ripples({(x0+x1)/2,(z0+z1)/2},math.max(20,x1-x0)*.54,math.max(20,z1-z0)*.54)
  else
   R.draw(deck,texture,model(tp[1],groundY-.06,tp[2],.8,.8))
   ripples(tp,10.5,10.5)
   if M.kind(battle,'player')=='swimmer' then ripples(p,8)end
  end
 end
 if ew then
  local kind=M.kind(battle,'enemy')
  -- Intro/outro portraits occupy this slot even when the last mon swims.
  local trainer=battle and battle.showEnemyTrainer and battle.trainerPic
  if kind=='land' or trainer then
   R.draw(deck,texture,model(arena.enemy[1],groundY-.06,arena.enemy[2],1,1))
   ripples(arena.enemy,13,13)
  elseif kind=='swimmer' and not (battle and battle.dramaticShape3DBallHide) then ripples(arena.enemy,9)end
 end
 R.glass(true)
end
return M
