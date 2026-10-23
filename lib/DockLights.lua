-- TEST175: VERMILION DOCK, MAGICAL. Presentation only, drawn over the
-- engine's quay, water and the S.S. Anne (ShipHull); nothing is claimed.
--
--  * iron lamp posts along the north quay's kerb and on pilings off the
--    east quay, their lanterns lit; bollards between them
--  * festoon lights strung post to post (warm, amber, rose, cyan and
--    violet bulbs) with bunting for the day
--  * a welcome arch over the gangway head, ringed in bulbs, S.S. ANNE in
--    neon across it
--  * lanterns on the crate stacks
--  * the ship dressed overall while she is moored: two masts, lines of
--    bulbs bow to masthead to stern, her portholes and deck lit (the
--    lights go with her when she sails)
--  * after dark: paper lanterns floating on the harbour, their light
--    lying on the water; every lamp's reflection drawn across the ripples;
--    fireflies over the quay; glints on the water; two searchlights
--    sweeping the sky from the ship; warm pools on the stones; the scene's
--    street-lamp light thrown by the four nearest lamps
--
-- DOCK LIGHTS (CommunityVisuals.dockLights) turns all of it off.
local V=...
local M={REVISION='dock-lights-175'}
local pi,cos,sin,floor,min,max,abs,sqrt=math.pi,math.cos,math.sin,math.floor,math.min,math.max,math.abs,math.sqrt
local function rh(a,b,s)local v=sin(a*12.9898+b*78.233+s*37.719)*43758.5453;return v-floor(v)end

-- neon shades (ReferenceMaterials dnNeon)
local RED,AMBER,CYAN,WARM,VIOLET,GREEN,ROSE,BLUE=1,2,3,4,5,6,7,8
local BULBS={AMBER,ROSE,CYAN,WARM,VIOLET,AMBER,GREEN,ROSE}
-- the halo each bulb colour throws after dark
local HALO={[RED]={1,.25,.20},[AMBER]={1,.62,.24},[CYAN]={.30,.90,1},[WARM]={1,.84,.58},[VIOLET]={.70,.42,1},
 [GREEN]={.42,1,.52},[ROSE]={1,.42,.72},[BLUE]={.42,.56,1}}

-- the plan (world units: 8 a tile, 16 a cell). The quay is at 0, the water
-- at -2; the north quay's kerb runs z 32..40, the east quay x 416..448.
local NORTH={24,72,120,168,296,344,392}   -- lamp posts on the kerb (z 36)
local KERB=36
local EAST={64,108,152}                    -- lamp posts on pilings (x 411)
local EASTX=411
local ARCH={x0=216,x1=248,z=37}           -- over the gangway head
local CRATES={{16,16},{432,16},{432,176}} -- lanterns on the crate stacks
local POST_H=30

function M.enabled(map)
 if not(map and map.id=='VERMILION_DOCK')then return false end
 local ok,CV=pcall(V.require,'CommunityVisuals')
 if ok and CV and CV.dockLights then
  local okG,v=pcall(CV.dockLights.get,CV.dockLights)
  if okG and v=='default'then return false end
 end
 return true
end

------------------------------------------------------------------ geometry
local function context()
 local Rooms=V.require('LeagueRooms')
 local C=Rooms.newContextFor({w=14,h=6,rows={}},'VERMILION_DOCK')
 C.ambient=1.0;C.maxLight=1.0
 return C
end
-- a lamp post: plinth, fluted shaft, collar, the lantern (lit), its cap
local function post(K,L,y0,head)
 L.box(-2.2,y0,-2.2,2.2,y0+2.4,2.2,'ktBasalt',.95)
 L.cyl(0,y0+2.4,y0+4,0,1.6,1.1,'green',6)
 L.cyl(0,y0+4,y0+POST_H-4,0,.8,.6,'green',6,false,0,'ktBasalt')
 L.cyl(0,y0+POST_H-4,y0+POST_H-3,0,1.3,1.3,'lgGold',6)
 -- the scroll arms the strings hang from
 L.rod({-.4,y0+POST_H-6,0},{-4.4,y0+POST_H-4.6,0},.25,'green')
 L.rod({.4,y0+POST_H-6,0},{4.4,y0+POST_H-4.6,0},.25,'green')
 if head~=false then
  local y=y0+POST_H-3
  L.box(-1.8,y,-1.8,1.8,y+.6,1.8,'green',1)
  L.raw({-1.5,y+.6,1.5},{1.5,y+.6,1.5},{1.7,y+5,1.7},{-1.7,y+5,1.7},'dnNeon',WARM)
  L.raw({1.5,y+.6,-1.5},{-1.5,y+.6,-1.5},{-1.7,y+5,-1.7},{1.7,y+5,-1.7},'dnNeon',WARM)
  L.raw({1.5,y+.6,1.5},{1.5,y+.6,-1.5},{1.7,y+5,-1.7},{1.7,y+5,1.7},'dnNeon',WARM)
  L.raw({-1.5,y+.6,-1.5},{-1.5,y+.6,1.5},{-1.7,y+5,1.7},{-1.7,y+5,-1.7},'dnNeon',WARM)
  for _,c in ipairs({{-1.7,-1.7},{1.7,-1.7},{1.7,1.7},{-1.7,1.7}})do L.box(c[1]-.2,y+.6,c[2]-.2,c[1]+.2,y+5,c[2]+.2,'green',1)end
  L.quad({-2.4,y+5,-2.4},{2.4,y+5,-2.4},{0,y+7.6,0},{0,y+7.6,0},'green',1)
  L.quad({2.4,y+5,2.4},{-2.4,y+5,2.4},{0,y+7.6,0},{0,y+7.6,0},'green',1)
  L.quad({2.4,y+5,-2.4},{2.4,y+5,2.4},{0,y+7.6,0},{0,y+7.6,0},'green',.9)
  L.quad({-2.4,y+5,2.4},{-2.4,y+5,-2.4},{0,y+7.6,0},{0,y+7.6,0},'green',.9)
  L.cyl(0,y+7.6,y+8.6,0,.4,.1,'lgGold',4)
 end
end
-- a string of bulbs from a to b, sagging; bunting between the bulbs
local function festoon(L,a,b,sag,seed,flags,bulbs)
 local dx,dy,dz=b[1]-a[1],b[2]-a[2],b[3]-a[3]
 local len=sqrt(dx*dx+dz*dz)
 local n=max(3,floor(len/5.5))
 local function P(u)return{a[1]+dx*u,a[2]+dy*u-sag*4*u*(1-u),a[3]+dz*u}end
 local prev=P(0)
 for i=1,n do
  local u=i/n
  local p=P(u)
  -- the wire: a thin dark ribbon
  L.quad({prev[1],prev[2],prev[3]},{p[1],p[2],p[3]},{p[1],p[2]-.22,p[3]},{prev[1],prev[2]-.22,prev[3]},'dark',.8)
  if i<n then
   local c=BULBS[(i+seed)%#BULBS+1]
   local s=.7
   if bulbs then local w=L.P({p[1],p[2]-.3-s,p[3]});bulbs[#bulbs+1]={w[1],w[2],w[3],c}end
   L.raw({p[1]-s,p[2]-.3-s*2,p[3]},{p[1]+s,p[2]-.3-s*2,p[3]},{p[1]+s,p[2]-.3,p[3]},{p[1]-s,p[2]-.3,p[3]},'dnNeon',c)
   L.raw({p[1],p[2]-.3-s*2,p[3]-s},{p[1],p[2]-.3-s*2,p[3]+s},{p[1],p[2]-.3,p[3]+s},{p[1],p[2]-.3,p[3]-s},'dnNeon',c)
   if flags and i%2==0 then
    -- a pennant hanging between the bulbs
    local q=P(u-.5/n)
    local m=({'red','blue','gold','white','leaf'})[(i+seed)%5+1]
    L.quad({q[1]-1.4,q[2]-.2,q[3]},{q[1]+1.4,q[2]-.2,q[3]},{q[1],q[2]-3.6,q[3]},{q[1],q[2]-3.6,q[3]},m,1.05)
   end
  end
  prev=p
 end
end
-- a hand lantern standing on a crate
local function lantern(L,y0)
 L.box(-1.6,y0,-1.6,1.6,y0+.6,1.6,'ktBasalt',.9)
 L.raw({-1.3,y0+.6,1.3},{1.3,y0+.6,1.3},{1.3,y0+4.2,1.3},{-1.3,y0+4.2,1.3},'dnNeon',AMBER)
 L.raw({1.3,y0+.6,-1.3},{-1.3,y0+.6,-1.3},{-1.3,y0+4.2,-1.3},{1.3,y0+4.2,-1.3},'dnNeon',AMBER)
 L.raw({1.3,y0+.6,1.3},{1.3,y0+.6,-1.3},{1.3,y0+4.2,-1.3},{1.3,y0+4.2,1.3},'dnNeon',AMBER)
 L.raw({-1.3,y0+.6,-1.3},{-1.3,y0+.6,1.3},{-1.3,y0+4.2,1.3},{-1.3,y0+4.2,-1.3},'dnNeon',AMBER)
 L.box(-1.6,y0+4.2,-1.6,1.6,y0+4.8,1.6,'ktBasalt',.9)
 L.rod({0,y0+4.8,0},{0,y0+6.4,0},.2,'ktBasalt')
end

-- the quay: posts, strings, the arch, bollards, the crate lanterns
local function buildQuay(C)
 local K=V.require('InteriorKit')
 local E=C.part('quay')
 local W=K.frame(C,E,0,0,0,0)
 C.bulbs=C.bulbs or{quay={},ship={}}
 local QB=C.bulbs.quay
 local tops={}
 for i,x in ipairs(NORTH)do
  post(K,K.frame(C,E,x,0,KERB,0),0)
  tops[#tops+1]={x,POST_H-4.6,KERB}
 end
 -- the piled posts off the east quay
 local etops={}
 for _,z in ipairs(EAST)do
  local L=K.frame(C,E,EASTX,0,z,0)
  L.cyl(0,-12,0,0,2.4,2.4,'inWalnut',6,true)
  L.box(-2.6,-.5,-2.6,2.6,0,2.6,'inWalnut',1)
  post(K,L,0)
  etops[#etops+1]={EASTX,POST_H-4.6,z}
 end
 -- the strings, post to post (the arch breaks the north run)
 for i=1,#tops-1 do
  local a,b=tops[i],tops[i+1]
  if not(a[1]<ARCH.x0 and b[1]>ARCH.x1)then
   festoon(W,{a[1]+4.4,a[2],a[3]},{b[1]-4.4,b[2],b[3]},4.5,i*3,true,QB)
  end
 end
 -- into the arch from the posts either side
 local la,lb=tops[4],tops[5]
 festoon(W,{la[1]+4.4,la[2],la[3]},{ARCH.x0-1,POST_H+4,ARCH.z},3.5,11,true,QB)
 festoon(W,{ARCH.x1+1,POST_H+4,ARCH.z},{lb[1]-4.4,lb[2],lb[3]},3.5,13,true,QB)
 for i=1,#etops-1 do
  local a,b=etops[i],etops[i+1]
  festoon(W,{a[1],a[2],a[3]+4.4},{b[1],b[2],b[3]-4.4},4,i*5+2,false,QB)
 end
 -- round the corner: the last north post to the first east one
 local t7,e1=tops[#tops],etops[1]
 festoon(W,{t7[1]+4.4,t7[2],t7[3]},{e1[1],e1[2],e1[3]-4.4},5,17,false,QB)
 -- bollards on the kerb between the posts
 for i=1,#NORTH-1 do
  local x=(NORTH[i]+NORTH[i+1])/2
  if not(x>ARCH.x0-12 and x<ARCH.x1+12)then
   local L=K.frame(C,E,x,0,KERB+.5,0)
   L.cyl(0,0,3.6,0,1.3,1.1,'ktBasalt',6)
   L.cyl(0,3.6,4.6,0,1.8,1.6,'ktBasalt',6)
  end
 end
 -- the welcome arch over the gangway head
 do
  local x0,x1,z=ARCH.x0,ARCH.x1,ARCH.z
  for _,x in ipairs({x0,x1})do
   W.box(x-2,0,z-2,x+2,2,z+2,'ktBasalt',1)
   W.box(x-1.3,2,z-1.3,x+1.3,POST_H+6,z+1.3,'white',1)
   W.box(x-1.8,POST_H+6,z-1.8,x+1.8,POST_H+7,z+1.8,'lgGold',1.05)
  end
  -- the arch itself: a white band on a half circle, bulbs along it
  local cx,r,base=(x0+x1)/2,(x1-x0)/2,POST_H+7
  local n=12
  for i=0,n-1 do
   local a0,a1=pi-i/n*pi,pi-(i+1)/n*pi
   local p0={cx+cos(a0)*r,base+sin(a0)*r*.55,z};local p1={cx+cos(a1)*r,base+sin(a1)*r*.55,z}
   W.quad({p0[1],p0[2],z+1},{p1[1],p1[2],z+1},{p1[1],p1[2]+2.4,z+1},{p0[1],p0[2]+2.4,z+1},'white',1.05)
   W.quad({p1[1],p1[2],z-1},{p0[1],p0[2],z-1},{p0[1],p0[2]+2.4,z-1},{p1[1],p1[2]+2.4,z-1},'white',.9)
   W.quad({p0[1],p0[2]+2.4,z-1},{p0[1],p0[2]+2.4,z+1},{p1[1],p1[2]+2.4,z+1},{p1[1],p1[2]+2.4,z-1},'white',1.1)
   local c=BULBS[i%#BULBS+1]
   W.raw({p0[1]-.6,p0[2]+.6,z+1.05},{p0[1]+.6,p0[2]+.6,z+1.05},{p0[1]+.6,p0[2]+1.8,z+1.05},{p0[1]-.6,p0[2]+1.8,z+1.05},'dnNeon',c)
   QB[#QB+1]={p0[1],p0[2]+1.2,z+1.2,c}
  end
  -- the name board under the crown, lettered in neon
  local by=base-1
  W.box(x0+1.3,by,z-.6,x1-1.3,by+5.6,z+.6,'navy',1)
  local P={box=function(a,b,c,d,e,f,mat,t,skip)W.box(a,b,c,d,e,f,'dnNeon',CYAN,skip)end}
  local okI=pcall(function()V.require('LeagueArchitecture').kit.inscription(P,'S.S. ANNE',cx,by+1.2,z+.65,.7,'dnNeon',x1-x0-4)end)
  if not okI then W.raw({x0+3,by+2,z+.7},{x1-3,by+2,z+.7},{x1-3,by+3.4,z+.7},{x0+3,by+3.4,z+.7},'dnNeon',CYAN)end
 end
 -- lanterns on the crate stacks
 for _,c in ipairs(CRATES)do lantern(K.frame(C,E,c[1],0,c[2],0),16)end
end

-- the ship dressed overall (hull-local: x 0..128 bow to stern, z 0..48,
-- y 0 at the waterline pose; her deck at 28)
local DECK=28
local function buildShip(C)
 local K=V.require('InteriorKit')
 local E=C.part('ship')
 local L=K.frame(C,E,0,0,0,0)
 C.bulbs=C.bulbs or{quay={},ship={}}
 local SB=C.bulbs.ship
 local masts={{38,24},{92,24}}
 for _,m in ipairs(masts)do
  L.cyl(m[1],DECK,DECK+44,m[2],.9,.5,'white',6,false)
  L.box(m[1]-5,DECK+30,m[2]-.3,m[1]+5,DECK+30.6,m[2]+.3,'white',1)
  L.raw({m[1]-.5,DECK+44,m[2]-.5},{m[1]+.5,DECK+44,m[2]-.5},{m[1]+.5,DECK+45.2,m[2]+.5},{m[1]-.5,DECK+45.2,m[2]+.5},'dnNeon',RED)
 end
 -- dressing lines: bow to the foremast, mast to mast, the mainmast to the stern
 local bow,stern={2,DECK+4,24},{126,DECK+4,24}
 local m1,m2={38,DECK+44,24},{92,DECK+44,24}
 festoon(L,bow,m1,2,1,false,SB);festoon(L,m1,m2,6,4,false,SB);festoon(L,m2,stern,2,7,false,SB)
 -- and the yards down to the rails on both sides
 for _,m in ipairs(masts)do
  for _,side in ipairs({2,46})do festoon(L,{m[1]-5,DECK+30,24},{m[1]-16,DECK+2,side},1.5,m[1]+side,false,SB)end
 end
 -- portholes along her side (the flank the quay and the camera see), a
 -- line of deck lights along the rail
 for x=14,116,7 do
  for _,z in ipairs({48.1})do
   L.raw({x-1,12,z},{x+1,12,z},{x+1,14,z},{x-1,14,z},'dnNeon',WARM)
  end
 end
 for x=10,120,10 do L.raw({x-.5,DECK+.1,46.6},{x+.5,DECK+.1,46.6},{x+.5,DECK+.1,47.6},{x-.5,DECK+.1,47.6},'dnNeon',AMBER)end
end

local function toMesh(quads)
 local RM=V.require('ReferenceMaterials')
 local vs,ix={},{}
 for _,q in ipairs(quads)do
  local sh=RM.encode(q.referenceMaterial,q.shade)
  local n=#vs
  for i=1,4 do local p=q[i];vs[n+i]={p[1],p[2],p[3],.5,.5,type(sh)=='table'and sh[i]or sh}end
  local k=#ix
  ix[k+1],ix[k+2],ix[k+3],ix[k+4],ix[k+5],ix[k+6]=n+1,n+2,n+3,n+1,n+3,n+4
 end
 return vs,ix
end
-- Pure: the parts as quads (offline tools read this)
function M.geometry()
 local C=context()
 buildQuay(C)
 buildShip(C)
 return C
end

-- one floating lantern: a paper lantern on a little float
function M.lanternGeometry()
 local C2=context();local K=V.require('InteriorKit')
 local L=K.frame(C2,C2.part('lantern'),0,0,0,0)
 L.cyl(0,-.6,.4,0,2.2,2.2,'inWalnut',6)
 local s,c=1.6,AMBER
 L.raw({-s,.4,s},{s,.4,s},{s*1.2,3,s*1.2},{-s*1.2,3,s*1.2},'dnNeon',c)
 L.raw({s,.4,-s},{-s,.4,-s},{-s*1.2,3,-s*1.2},{s*1.2,3,-s*1.2},'dnNeon',c)
 L.raw({s,.4,s},{s,.4,-s},{s*1.2,3,-s*1.2},{s*1.2,3,s*1.2},'dnNeon',c)
 L.raw({-s,.4,-s},{-s,.4,s},{-s*1.2,3,s*1.2},{-s*1.2,3,-s*1.2},'dnNeon',c)
 L.raw({-s*1.2,3,s*1.2},{s*1.2,3,s*1.2},{s,5.4,s},{-s,5.4,s},'dnNeon',c)
 L.raw({s*1.2,3,-s*1.2},{-s*1.2,3,-s*1.2},{-s,5.4,-s},{s,5.4,-s},'dnNeon',c)
 L.raw({s*1.2,3,s*1.2},{s*1.2,3,-s*1.2},{s,5.4,-s},{s,5.4,s},'dnNeon',c)
 L.raw({-s*1.2,3,-s*1.2},{-s*1.2,3,s*1.2},{-s,5.4,s},{-s,5.4,-s},'dnNeon',c)
 L.box(-1.2,5.4,-1.2,1.2,6,1.2,'red',1)
 return C2
end

------------------------------------------------------------------ the plan
-- every lamp, for the glows, the pools, the reflections and the street
-- light; the lanterns floating on the harbour
local LAMPS
local function lamps()
 if LAMPS then return LAMPS end
 LAMPS={}
 for _,x in ipairs(NORTH)do LAMPS[#LAMPS+1]={x,POST_H+1,KERB,1}end
 for _,z in ipairs(EAST)do LAMPS[#LAMPS+1]={EASTX,POST_H+1,z,1}end
 LAMPS[#LAMPS+1]={(ARCH.x0+ARCH.x1)/2,POST_H+12,ARCH.z,.8}
 for _,c in ipairs(CRATES)do LAMPS[#LAMPS+1]={c[1],19,c[2],.6}end
 return LAMPS
end
local FLOAT
local function floaters()
 if FLOAT then return FLOAT end
 FLOAT={}
 local n=0;local i=0
 while n<16 and i<200 do
  i=i+1
  local x,z=24+rh(i,1,1)*370,52+rh(i,2,2)*120
  -- clear of the ship and the gangway
  if not(x>140 and x<310 and z<112)and not(x>200 and x<260 and z<60)then
   n=n+1
   FLOAT[n]={x=x,z=z,ph=rh(i,3,3)*6.28,col=({AMBER,WARM,ROSE,AMBER,VIOLET,WARM})[n%6+1],drift=8+rh(i,4,4)*14}
  end
 end
 return FLOAT
end
local function floatAt(f,t)
 return f.x+sin(t*.045+f.ph)*f.drift,-1.2+sin(t*.9+f.ph)*.35,f.z+sin(t*.031+f.ph*1.7)*f.drift*.5
end

------------------------------------------------------------------ runtime
local slot     -- {quay=mesh, ship=mesh}
local lanternMesh
local white
local function whiteTex()
 if not white then
  local d=love.image.newImageData(2,2);for y=0,1 do for x=0,1 do d:setPixel(x,y,1,1,1,1)end end
  white=love.graphics.newImage(d);white:setFilter('nearest','nearest');d:release()
 end
 return white
end
local function build()
 if slot~=nil then return slot end
 slot=false
 local ok,err=pcall(function()
  local R=V.require('Voxel3D')
  local C=M.geometry()
  local out={}
  out.bulbs=C.bulbs
  for _,p in ipairs(C.parts)do
   if #p.quads>0 then local vs,ix=toMesh(p.quads);out[p.name]=R.newMesh(vs,ix)end
  end
  out.halos=nil
  local C2=M.lanternGeometry()
  local p=C2.parts[1]
  if p and #p.quads>0 then local vs,ix=toMesh(p.quads);lanternMesh=R.newMesh(vs,ix)end
  slot=out
 end)
 if not ok then
  slot=false
  if V.mod and V.mod.log and V.mod.log.info then pcall(V.mod.log.info,V.mod.log,'Dock lights failed: %s',tostring(err))end
 end
 return slot
end
local function nightK()
 local okR,R=pcall(V.require,'Voxel3D')
 return okR and R and(R.glassNight or 0)or 0
end

-- the opaque pass (CaveMood's outdoor hook): the posts, the strings, the
-- arch, and the ship's dressing riding on her pose
function M.draw(state)
 local map=state and state.map
 if not M.enabled(map)then return false end
 local s=build();if not s then return false end
 local R=V.require('Voxel3D');local Mat4=V.require('Mat4')
 local tex=whiteTex()
 if s.quay then R.draw(s.quay,tex)end
 if s.ship then
  local okP,p=pcall(function()return V.require('ShipHull').pose(state)end)
  if okP and p and not p.gone then R.draw(s.ship,tex,Mat4.translate(p.x,p.y,p.z))end
 end
 return true
end

-- the effects (glows, pools, motes, glints, searchlights) as a room for
-- LeagueRoomFx; rebuilt each frame from the hour
local FX={glows={},pools={},sparkles={},spots={},candles={},fires={}}
local Shim={}
local shipPose
M.floaters,M.floatAt,M.lamps=floaters,floatAt,lamps
local function fxFor(night,shipPose,t)
 for k in pairs(FX)do if type(FX[k])=='table'then for i=#FX[k],1,-1 do FX[k][i]=nil end end end
 FX.motes=nil
 local glowA=.10+.22*night
 for _,l in ipairs(lamps())do
  FX.glows[#FX.glows+1]={x=l[1],y=l[2],z=l[3],r=9*l[4]+4*night,col='warm',a=glowA*l[4]}
  if night>.05 then FX.pools[#FX.pools+1]={x=l[1],y=l[3]<KERB+4 and .3 or -1.7,z=l[3]+(l[3]<KERB+4 and -8 or 0),r=22*l[4],col={1,.72,.40},a=.07*night*l[4]}end
 end
 if night>.05 then
  for i,f in ipairs(floaters())do
   local x,y,z=floatAt(f,t)
   FX.glows[#FX.glows+1]={x=x,y=y+3,z=z,r=7,col=f.col==VIOLET and'violet'or'gold',a=.24*night}
   FX.pools[#FX.pools+1]={x=x,y=-1.75,z=z,r=9,col={1,.70,.36},a=.10*night}
  end
  -- fireflies over the quay and the water's edge
  FX.motes={x=230,z=70,y0=2,y1=34,r=170,n=56,col={1,.92,.45}}
  -- glints on the harbour, twinkling
  for i=1,28 do FX.sparkles[i]={x=20+rh(i,7,1)*390,y=-1.5,z=50+rh(i,8,2)*130,s=.7,phase=i*1.7,soft=false}end
  -- two searchlights from the ship, sweeping the sky
  if shipPose and not shipPose.gone then
   FX.spots[1]={x=shipPose.x+30,y=60,z=shipPose.z+24,sky=true,phase=0,col={.80,.90,1},a=.05*night}
   FX.spots[2]={x=shipPose.x+100,y=60,z=shipPose.z+24,sky=true,phase=2.4,col={1,.86,.70},a=.05*night}
  end
 end
 return FX,{W=448,D=192,H=400}
end
M.fxFor=fxFor
-- what LeagueRoomFx draws for us after dark: the fireflies, the glints, the
-- searchlights (the glows and reflections are our own batched streams)
local FXR={sparkles={},spots={}}
function Shim.fx(map,eye)
 local night=nightK()
 FXR.motes=nil
 for i=#FXR.sparkles,1,-1 do FXR.sparkles[i]=nil end
 for i=#FXR.spots,1,-1 do FXR.spots[i]=nil end
 if night>.05 then
  FXR.motes={x=230,z=70,y0=2,y1=34,r=170,n=48,col={1,.92,.45}}
  for i=1,24 do FXR.sparkles[i]={x=20+rh(i,7,1)*390,y=-1.5,z=50+rh(i,8,2)*130,s=.7,phase=i*1.7,soft=false}end
  if shipPose and not shipPose.gone then
   FXR.spots[1]={x=shipPose.x+30,y=60,z=shipPose.z+24,sky=true,phase=0,col={.80,.90,1},a=.05*night}
   FXR.spots[2]={x=shipPose.x+100,y=60,z=shipPose.z+24,sky=true,phase=2.4,col={1,.86,.70},a=.05*night}
  end
 end
 return FXR,{W=448,D=192,H=400}
end
function Shim.step()end

------------------------------------------------------------------ streams
-- one mesh per batch, one draw: the bulbs' halos (a static stream per
-- colour), the lamps' glows (static), the floating lanterns' glows and
-- the reflections (rewritten each frame), the lantern bodies themselves
local ST={}
local function rect(sm,i,x,y,z,hx,hz)
 local v=sm.verts;local b=i*8;local e
 e=v[b+1];e[1],e[2],e[3],e[4],e[5]=x-hx,y,z-hz,0,0
 e=v[b+2];e[1],e[2],e[3],e[4],e[5]=x+hx,y,z-hz,1,0
 e=v[b+3];e[1],e[2],e[3],e[4],e[5]=x+hx,y,z+hz,1,1
 e=v[b+4];e[1],e[2],e[3],e[4],e[5]=x-hx,y,z+hz,0,1
 for k=5,8 do e=v[b+k];e[1],e[2],e[3],e[4],e[5]=x,y,z,0,0 end
end
local function halos(s,K)
 if s.halos~=nil then return s.halos end
 s.halos=false
 local out={}
 for _,set in ipairs({'quay','ship'})do
  local by={}
  for _,b in ipairs((s.bulbs or{})[set]or{})do local l=by[b[4]];if not l then l={};by[b[4]]=l end;l[#l+1]=b end
  for c,list in pairs(by)do
   local sm=K.newStream(#list)
   if sm then
    for i,b in ipairs(list)do K.streamPut(sm,i-1,b[1],b[2],b[3],2.2,false)end
    pcall(sm.mesh.setVertices,sm.mesh,sm.verts)
    out[#out+1]={mesh=sm.mesh,col=HALO[c]or HALO[WARM],ship=set=='ship'}
   end
  end
 end
 -- the lamps' glows: static too
 local L=lamps()
 local sm=K.newStream(#L)
 if sm then
  for i,l in ipairs(L)do K.streamPut(sm,i-1,l[1],l[2],l[3],9*l[4],false)end
  pcall(sm.mesh.setVertices,sm.mesh,sm.verts)
  ST.lampGlow=sm
 end
 ST.floatGlow=K.newStream(#floaters())
 ST.reflect=K.newStream(#L)
 s.halos=out
 return out
end
-- the lantern bodies, all in one stream mesh with their own finishes
local function bodies(R)
 if ST.bodies~=nil then return ST.bodies end
 ST.bodies=false
 local ok=pcall(function()
  local RM=V.require('ReferenceMaterials')
  local q=M.lanternGeometry().parts[1].quads
  local base={}
  for _,qq in ipairs(q)do
   local sh=RM.encode(qq.referenceMaterial,qq.shade)
   for i=1,4 do local p=qq[i];base[#base+1]={p[1],p[2],p[3],type(sh)=='table'and sh[i]or sh}end
  end
  local n=#floaters()
  local verts={}
  for i=1,#base*n do verts[i]={0,0,0,.5,.5,1}end
  local mesh=love.graphics.newMesh(R.FORMAT,verts,'triangles','stream')
  local idx={};for k=0,(#base/4)*n-1 do R.pushQuad(idx,k)end
  mesh:setVertexMap(idx)
  ST.bodies={mesh=mesh,verts=verts,base=base}
 end)
 return ST.bodies
end

-- the late pass (after the water and the actors): the floating lanterns,
-- the glows and the reflections, then LeagueRoomFx's fireflies, glints and
-- searchlights
function M.drawLate(state)
 local map=state and state.map
 -- TEST205: Cerulean Cave's light also has to come after the water
 pcall(function()V.require("CeruleanDepths").drawLate(state)end)
 if not M.enabled(map)then return false end
 local s=build();if not s then return false end
 local R=V.require('Voxel3D');local Mat4=V.require('Mat4')
 local night=nightK()
 local t=0;pcall(function()t=love.timer.getTime()end)
 local okP,p=pcall(function()return V.require('ShipHull').pose(state)end)
 shipPose=okP and p or nil
 local FL=floaters()
 -- the lanterns set on the water at dusk
 local B=night>.05 and bodies(R)or nil
 if B then
  local v,base=B.verts,B.base;local nb=#base;local k=0
  for _,f in ipairs(FL)do
   local x,y,z=floatAt(f,t)
   for j=1,nb do local b=base[j];k=k+1;local e=v[k];e[1],e[2],e[3],e[6]=b[1]+x,b[2]+y,b[3]+z,b[4]end
  end
  pcall(B.mesh.setVertices,B.mesh,v)
  R.draw(B.mesh,whiteTex())
 end
 local okK,K=pcall(function()return V.require('LeagueRoad').fxKit()end)
 if okK and K and K.soft and K.newStream then
  local H=halos(s,K)
  local g=love.graphics
  local L=lamps()
  -- the floaters' glows and every lamp drawn out across the ripples
  if ST.floatGlow then
   for i,f in ipairs(FL)do local x,y,z=floatAt(f,t);K.streamPut(ST.floatGlow,i-1,x,y+3,z,6.5,false)end
   pcall(ST.floatGlow.mesh.setVertices,ST.floatGlow.mesh,ST.floatGlow.verts)
  end
  if ST.reflect and night>.05 then
   for i,l in ipairs(L)do
    local z0=max(l[3],44)
    rect(ST.reflect,i-1,l[1]+sin(t*1.3+i)*.6,-1.8,z0+24,2.4*l[4],26)
   end
   pcall(ST.reflect.mesh.setVertices,ST.reflect.mesh,ST.reflect.verts)
  end
  pcall(R.withEffect,'add',function()
   local tw=.88+.12*sin(t*2.1)
   if night>.05 then
    for _,h in ipairs(H or{})do
     if not h.ship or(shipPose and not shipPose.gone)then
      g.setColor(h.col[1],h.col[2],h.col[3],.42*night*tw)
      R.draw(h.mesh,K.soft,h.ship and Mat4.translate(shipPose.x,shipPose.y,shipPose.z)or nil)
     end
    end
    if ST.reflect then g.setColor(1,.68,.34,.20*night);R.draw(ST.reflect.mesh,K.soft)end
   end
   if ST.lampGlow then g.setColor(1,.72,.40,(.10+.26*night)*tw);R.draw(ST.lampGlow.mesh,K.soft)end
   if ST.floatGlow and night>.05 then g.setColor(1,.78,.42,.30*night);R.draw(ST.floatGlow.mesh,K.soft)end
  end)
  pcall(g.setColor,1,1,1,1)
 end
 if night>.05 then
  local okF,Fx=pcall(V.require,'LeagueRoomFx')
  if okF and Fx then pcall(Fx.draw,state,Shim)end
 end
 return true
end

-- the four lamps nearest the player, for the scene's street-lamp light
function M.lampPools(state)
 local map=state and state.map
 if not M.enabled(map)then return nil end
 local p=state.player;local px,pz=(p and p.px or 0)+8,(p and p.py or 0)+8
 local sorted={}
 for _,l in ipairs(lamps())do sorted[#sorted+1]={l[1],0,l[3],(l[1]-px)^2+(l[3]-pz)^2}end
 table.sort(sorted,function(a,b)return a[4]<b[4]end)
 local out={}
 for i=1,4 do local q=sorted[min(i,#sorted)];out[i]={q[1],q[2],q[3]}end
 return out
end

function M.invalidate()
 for _,sm in pairs(ST)do if sm and sm.mesh and sm.mesh.release then pcall(sm.mesh.release,sm.mesh)end end
 ST={}
 if slot then
  for _,h in ipairs(slot.halos or{})do if h.mesh and h.mesh.release then pcall(h.mesh.release,h.mesh)end end
  for k,m in pairs(slot)do if k~='bulbs'and k~='halos'and m and m.release then pcall(m.release,m)end end
 end
 if lanternMesh and lanternMesh.release then pcall(lanternMesh.release,lanternMesh)end
 if white and white.release then pcall(white.release,white)end
 slot,lanternMesh,white=nil,nil,nil
end
pcall(function()require('src.render.Assets').register(M.invalidate)end)
return M
