-- TEST194: THE LEAGUE'S STADIUMS. The Elite Four's rooms and the
-- Champion's are places to walk through: walls, tombs, boulders and
-- braziers a few cells from the fight, and a battle camera with nowhere to
-- stand. So each battle there is fought in a stadium built in that
-- member's own style, full of people:
--
--   LORELEI   the Glacier Bowl: a bowl of ice and snow round a lake
--             frozen black, the fight on a great floe of ice in it, spikes
--             of ice and floes about it (TEST196), crystal spires on the
--             rim, the aurora and falling snow
--   BRUNO     the Mountain Ring: a timber-and-granite arena round the top
--             of a mountain, the fight on its crown above a sea of cloud,
--             rope bridges, war drums, prayer flags (TEST196), the crimson
--             sparring mat, torches, banners, a gong over the gate
--   AGATHA    the Crypt Colosseum: slate tiers under a gothic arcade of
--             violet glass round a well of spirits, the fight on a dais
--             floating over it on four chains, graves drifting on islands
--             of rock (TEST196), candles, mist, wisps and a pale moon
--   LANCE     the Dragon Caldera: obsidian tiers round a pit of fire, the
--             fight on a platform on a pillar rising out of the lava,
--             bridges to the dragon gate, a storm overhead (TEST195); the
--             lake boils, bubbles bursting and spurts of lava (TEST197)
--   CHAMPION  Indigo Stadium: two tiers under a floodlit roof, the
--             biggest crowd, LED boards, giant screens with the Champion's
--             name, sweeping searchlights, confetti, pyro round the field
--             (TEST196)
--
-- TEST196: the crowd is heard and answers the fight (LeagueCrowd): its
-- cheers, roars, chants and the wave, and the stands rising, jumping on the
-- beat and the stage's fires and lights flaring with them.
--
-- The room is untouched for walking. While a battle is staged in one of
-- these rooms (BattleScene.stagedHost), LeagueRooms.draw hands the frame to
-- the stadium instead, and LeagueRoomFx draws the stadium's effects. The
-- swap happens behind the battle's own opening transition. The stadium is
-- built in the background while you walk the room (LeagueRooms.step) and
-- freed when you leave it. Presentation only: the arena, the mons, the
-- camera, the scripts are the game's and BattleArena's.
local V=...
-- TEST231: Lance's dragon's eye reads as an eye (THEME_DRESS.lance).
local M={REVISION='league-stadium-245'}
local RM=V.require('ReferenceMaterials')
local pi,cos,sin,floor,min,max,abs,sqrt=math.pi,math.cos,math.sin,math.floor,math.min,math.max,math.abs,math.sqrt
local function rh(a,b,s)local v=sin(a*12.9898+b*78.233+s*37.719)*43758.5453;return v-floor(v)end
local TAU=pi*2

M.ROOMS={LORELEIS_ROOM='lorelei',BRUNOS_ROOM='bruno',AGATHAS_ROOM='agatha',LANCES_ROOM='lance',CHAMPIONS_ROOM='champion'}

------------------------------------------------------------------ themes
local SKIN={{.98,.82,.68},{.88,.66,.48},{.66,.45,.30},{.42,.27,.17}}
local HAIR={{.10,.08,.07},{.34,.21,.11},{.86,.70,.36},{.62,.24,.12},{.82,.82,.84},{.16,.12,.10}}
local THEMES={
 lorelei={title='LORELEI',fx=190,fz=200,seg=96,
  field='lgIce',line='lgSilver',walk='lgSnow',
  barrier={h=8,mat='lgIce',cap='lgSilver'},
  tiers={{rows=12,depth=8,rise=5.4,back=14,tread='lgSnow',riser='lgIce',backMat='lgIce',trim='lgSilver'}},
  aisle='lgSilver',gate={half=2,rows=6},south={half=1,rows=5},sky={style=2,R=1300},ambient=.86,maxLight=1.45,
  lake={level=-6,floe=86,bridge=24},bridges=true,
  crowd={density=.80,hats=.45,hatCol={.92,.95,1},scarves=.40,accent={.55,.82,1},
   shirts={{.30,.55,.92},{.90,.94,1.0},{.14,.22,.48},{.30,.80,.92},{.66,.72,.86},{.52,.50,.86}}},
  ambience={crowd=.95,ice=.35}},
 bruno={title='BRUNO',fx=190,fz=200,seg=96,
  field='lgWood',line='lgGold',walk='lgGranite',
  barrier={h=8,mat='lgWood',cap='lgGranite'},
  tiers={{rows=12,depth=8,rise=5.4,back=16,tread='lgWood',riser='lgGranite',backMat='lgGranite',trim='lgWood'}},
  aisle='lgGranite',gate={half=2,rows=6},south={half=1,rows=5},sky={style=1,R=1300},ambient=.84,maxLight=1.5,
  summit={depth=96,top=94,bridge=20},bridges=true,
  crowd={density=.80,hats=.15,hatCol={.85,.12,.10},scarves=.45,accent={.86,.14,.12},
   shirts={{.80,.16,.12},{.93,.90,.84},{.46,.28,.14},{.14,.13,.13},{.88,.50,.16},{.70,.58,.40}}},
  ambience={crowd=.95,dojo=.30}},
 agatha={title='AGATHA',fx=190,fz=200,seg=96,
  field='lgSlate',line='lgAmethyst',walk='lgSlate',
  barrier={h=8,mat='lgSlate',cap='lgSilver'},
  tiers={{rows=12,depth=8,rise=5.4,back=34,tread='lgSlate',riser='lgSlate',backMat='lgSlate',trim='lgSilver'}},
  aisle='lgSilver',gate={half=2,rows=6},south={half=1,rows=5},sky={style=1,R=1300},ambient=.72,maxLight=1.4,
  well={depth=110,dais=82,step=17},bridges=true,
  crowd={density=.76,hats=.40,hatCol={.20,.10,.26},scarves=.30,accent={.66,.36,1},
   shirts={{.42,.18,.58},{.13,.11,.16},{.30,.14,.34},{.42,.42,.46},{.66,.24,.58},{.46,.62,.48}}},
  ambience={crowd=.85,crypt=.40}},
 lance={title='LANCE',fx=184,fz=194,seg=96,pit={depth=72,platform=78,bridge=26},bridges=true,
  field='lgObsidian',line='lgGold',walk='lgObsidian',
  barrier={h=8,mat='lgObsidian',cap='lgGold'},
  tiers={{rows=12,depth=8,rise=5.6,back=14,tread='lgObsidian',riser='lgObsidian',backMat='lgObsidian',trim='lgGold'}},
  aisle='lgGold',gate={half=2,rows=6},south={half=1,rows=5},sky={style=3,R=1300},ambient=.80,maxLight=1.5,
  crowd={density=.80,hats=.10,hatCol={.80,.10,.10},scarves=.50,accent={.95,.72,.20},
   shirts={{.76,.10,.10},{.12,.11,.12},{.90,.70,.20},{.16,.20,.46},{.86,.40,.12},{.52,.08,.10}}},
  ambience={crowd=.95,storm=.25,lava=.55}},
 champion={title='CHAMPION',fx=214,fz=232,seg=128,
  field='lgMarble',line='lgGold',walk='lgPaveDark',
  barrier={h=9,mat='lgMarble',cap='lgGold',boards=true},
  tiers={{rows=12,depth=8,rise=5.4,back=12,tread='lgCrimson',riser='lgMarble',backMat='lgMarble',trim='lgGold',ribbon=true},
         {rows=14,depth=8,rise=6.6,back=10,tread='lgCrimson',riser='lgMarble',backMat='lgMarble',trim='lgGold',walk=4}},
  aisle='lgMarble',gate={half=3,rows=7},south={half=2,rows=6},roof=true,sky={style=1,R=1500},ambient=.92,maxLight=1.5,
  pyro=16,
  crowd={density=.92,hats=.30,scarves=.50,accent={.95,.82,.25},
   shirts={{.86,.14,.16},{.20,.40,.90},{.95,.82,.20},{.22,.66,.30},{.94,.94,.96},{.56,.28,.78},{.96,.50,.72},{.95,.55,.16}}},
  ambience={crowd=1.0,champion=.25}},
}
M.THEMES=THEMES

------------------------------------------------------------------ the crowd
-- 16x24 spectators, sixteen of them side by side; two poses (arms down,
-- arms up and cheering). Pure: returns rows of {r,g,b,a}.
M.SPRITE_W,M.SPRITE_H,M.VARIANTS=16,24,16
local function sprite(theme,v,up)
 local P=theme.crowd
 local px={}
 local function set(x,y,c)if x>=0 and x<16 and y>=0 and y<24 then px[y*16+x]=c end end
 local function rect(x0,y0,x1,y1,c)for y=y0,y1 do for x=x0,x1 do set(x,y,c)end end end
 local shirt=P.shirts[(v%#P.shirts)+1]
 local skin=SKIN[floor(rh(v,1,3)*#SKIN)+1]
 local hair=HAIR[floor(rh(v,2,5)*#HAIR)+1]
 local pants={.16,.16,.20}
 local hat=rh(v,3,7)<(P.hats or .2)and(P.hatCol or shirt)
 local scarf=rh(v,4,9)<(P.scarves or .3)and P.accent
 local long=rh(v,5,11)<.35
 local dark={.10,.08,.10}
 local shade={shirt[1]*.78,shirt[2]*.78,shirt[3]*.78}
 rect(5,19,10,23,pants);rect(7,21,8,23,nil)
 rect(4,11,11,18,shirt);rect(10,12,11,18,shade);rect(3,12,12,13,shirt)
 rect(7,10,8,10,skin)
 rect(5,3,10,9,skin)
 rect(5,2,10,3,hair);set(5,4,hair);set(10,4,hair)
 if long then rect(5,4,5,8,hair);rect(10,4,10,8,hair)end
 set(6,6,dark);set(9,6,dark)
 if up then set(7,8,dark);set(8,8,dark)end
 if hat then rect(5,1,10,2,hat);rect(4,3,11,3,hat)end
 if up then
  rect(2,5,3,12,shirt);rect(12,5,13,12,shirt)
  rect(2,2,3,4,skin);rect(12,2,13,4,skin)
  if scarf then rect(2,0,13,1,scarf)end
 else
  rect(3,13,3,16,shirt);rect(12,13,12,16,shade);set(3,17,skin);set(12,17,skin)
  if scarf then rect(5,11,10,11,scarf);rect(6,12,7,15,scarf)end
 end
 -- a dark outline round the figure, so it reads at a distance
 local out={}
 for y=0,23 do for x=0,15 do
  if not px[y*16+x]then
   for _,d in ipairs({{1,0},{-1,0},{0,1},{0,-1}})do
    local nx,ny=x+d[1],y+d[2]
    if nx>=0 and nx<16 and ny>=0 and ny<24 and px[ny*16+nx]and px[ny*16+nx]~=true then out[y*16+x]=true;break end
   end
  end
 end end
 for k in pairs(out)do px[k]=dark end
 return px
end
-- the whole strip for one pose: rows[y][x] = {r,g,b,a}
function M.crowdAtlas(themeName,up)
 local theme=THEMES[themeName]
 local W,H=M.SPRITE_W*M.VARIANTS,M.SPRITE_H
 local rows={}
 for y=0,H-1 do rows[y]={}end
 for v=0,M.VARIANTS-1 do
  local px=sprite(theme,v,up)
  for y=0,H-1 do for x=0,M.SPRITE_W-1 do
   local c=px[y*16+x]
   rows[y][v*M.SPRITE_W+x]=c and{c[1],c[2],c[3],1}or{0,0,0,0}
  end end
 end
 return rows,W,H
end

------------------------------------------------------------------ where
-- The arena's midpoint in this room: the authored battle spot
-- (data/battle_arenas.lua, through BattleArena), else the room's centre.
local function centreFor(id)
 local okB,BA=pcall(V.require,'BattleArena')
 if okB and BA and BA.authoredFor and BA.SHAPES then
  local okP,pick=pcall(BA.authoredFor,id)
  if okP and type(pick)=='table'and not pick.map then
   for _,sh in ipairs(BA.SHAPES)do
    if sh.id==(pick.shape or'wide')then
     local ex,ey=pick.x+sh.enemy[1],pick.y+sh.enemy[2]
     local px,py=pick.x+sh.player[1],pick.y+sh.player[2]
     return(ex+px)/2*16+8,(ey+py)/2*16+8
    end
   end
  end
 end
 local Lt=V.require('LeagueRooms').LAYOUT[id]
 return Lt and Lt.w*16 or 80,Lt and Lt.h*16 or 80
end
M.centreFor=centreFor

------------------------------------------------------------------ the bowl
-- S: the shared frame. Angles run from +x toward +z; north (behind the
-- opponent) is 3pi/2. P(th,d,y) is a point d beyond the field's edge.
local function frame(T,cx,cz)
 local S={cx=cx,cz=cz,fx=T.fx,fz=T.fz,seg=T.seg}
 function S.P(th,d,y)return{cx+(T.fx+d)*cos(th),y,cz+(T.fz+d)*sin(th)}end
 function S.th(i)return i/T.seg*TAU end
 S.north=floor(T.seg*3/4+.5);S.south=floor(T.seg/4+.5)
 local function inGate(i,g,centre)
  if not g then return false end
  local k=(i-centre)%T.seg;if k>T.seg/2 then k=k-T.seg end
  return k>=-g.half and k<g.half
 end
 function S.gateAt(i,row)
  if inGate(i,T.gate,S.north)and row<T.gate.rows then return'north'end
  if inGate(i,T.south,S.south)and row<T.south.rows then return'south'end
  return nil
 end
 function S.aisleAt(i)return i%8==4 end
 return S
end

-- a ring band of quads between (d0,y0) and (d1,y1) for segments i0..i1-1
local function band(E,S,i0,i1,d0,y0,d1,y1,mat,t,glow)
 for i=i0,i1-1 do
  local a,b=S.th(i),S.th(i+1)
  E.quad(S.P(a,d0,y0),S.P(b,d0,y0),S.P(b,d1,y1),S.P(a,d1,y1),mat,t,glow)
 end
end
-- self-lit neon: the shade IS the colour code, so it must not be lit
local function neon(C,fn)
 local was=C.flat;C.flat=true
 local ok,err=pcall(fn)
 C.flat=was
 if not ok then error(err,0)end
end

local function field(C,S,T,lib)
 local E=C.part('field')
 local NR=12
 for j=0,NR-1 do
  local f0,f1=j/NR,(j+1)/NR
  for i=0,T.seg-1 do
   local a,b=S.th(i),S.th(i+1)
   local function Q(f,th)return{S.cx+T.fx*f*cos(th),0,S.cz+T.fz*f*sin(th)}end
   E.quad(Q(f0,a),Q(f0,b),Q(f1,b),Q(f1,a),T.field,1)
  end
 end
 -- the markings, just proud of the floor and shadowless
 local D=C.part('marks')
 D.decor(function()
  local y=.06
  -- the boundary line and the battle circle round the two mons
  for i=0,T.seg-1 do
   local a,b=S.th(i),S.th(i+1)
   D.quad(S.P(a,-9,y),S.P(b,-9,y),S.P(b,-7.4,y),S.P(a,-7.4,y),T.line,1.04)
  end
  lib.ringH(D,S.cx,S.cz,y,52,53.8,64,T.line,1.04)
  lib.stripH(D,S.cx-T.fx+9,S.cz,S.cx+T.fx-9,S.cz,y,1.6,T.line,1.04)
  -- the two trainers' boxes
  for _,sg in ipairs({-1,1})do
   local z0,z1=S.cz+sg*64,S.cz+sg*92
   for _,s in ipairs({{-18,z0,18,z0},{-18,z1,18,z1},{-18,z0,-18,z1},{18,z0,18,z1}})do
    lib.stripH(D,S.cx+s[1],s[2],S.cx+s[3],s[4],y,1.4,T.line,1.04)
   end
  end
 end)
 return D
end

-- the wall round the field and the walkway behind it
local function barrier(C,S,T)
 local B=T.barrier
 local d0=T.moat or 0
 S.wallD=d0
 for i=0,T.seg-1 do
  local E=C.part('barrier:'..floor(i/16))
  -- (over a pit, the lake, the cloud or the well, the wall opens where a
  -- bridge lands)
  if T.bridges and S.gateAt(i,0)then
   band(E,S,i,i+1,d0,0,d0+2.5,0,T.walk,.85)
  else
   band(E,S,i,i+1,d0,0,d0,B.h,B.mat,.95)
   band(E,S,i,i+1,d0,B.h,d0+2.5,B.h,B.cap,1.05)
   band(E,S,i,i+1,d0-.3,B.h-1.2,d0-.3,B.h,B.cap,1.0)
  end
  -- (TEST196: Lorelei's wall goes on down into the water)
  if T.lake then band(E,S,i,i+1,d0,T.lake.level-.5,d0,0,B.mat,.62)end
  band(E,S,i,i+1,d0+2.5,0,d0+8,0,T.walk,.85)
 end
 S.gap=d0+8
end

-- TEST194 (Lance): no floor at all. A pit to a lake of fire, the fight on
-- an obsidian platform on a pillar of rock rising out of it, two bridges
-- across to the gate and the tunnel opposite
local function pit(C,S,T,lib)
 local P=T.pit
 local Y=-P.depth
 local fx=C.fx
 local cx,cz=S.cx,S.cz
 -- the light of the fire comes up from below
 C.addLight(cx,Y+30,cz,P.depth*2.6,.42)
 for k=0,5 do
  local a=k/6*TAU+.4
  C.addLight(cx+cos(a)*T.fx*.72,Y+16,cz+sin(a)*T.fz*.72,240,.30)
 end
 -- the walls, funnelling in as they go down
 for i=0,T.seg-1,16 do
  local E=C.part('pitwall:'..i)
  local i1=min(T.seg,i+16)
  band(E,S,i,i1,0,0,0,Y*.34,'lgObsidian',.62)
  band(E,S,i,i1,0,Y*.34,-4,Y*.68,'lgObsidian',.70)
  band(E,S,i,i1,-4,Y*.68,-9,Y+.5,'lgObsidian',.82)
 end
 -- the lake of fire
 local L=C.part('lava')
 local NR=8
 for j=0,NR-1 do
  local f0,f1=j/NR,(j+1)/NR
  for i=0,T.seg-1 do
   local a,b=S.th(i),S.th(i+1)
   local function Q(f,th)return{cx+(T.fx-9)*f*cos(th),Y,cz+(T.fz-9)*f*sin(th)}end
   L.quad(Q(f0,a),Q(f0,b),Q(f1,b),Q(f1,a),'lgLava',.92+.12*rh(i,j,3))
  end
 end
 -- glowing seams in the rock and falls of lava pouring from the cracks
 local Sm=C.part('seams')
 for i=0,T.seg-1 do
  if not S.gateAt(i,0)and rh(i,7,3)<.28 then
   local th=S.th(i+.5)
   local w=.010+rh(i,8,5)*.008
   local x0=th+(rh(i,9,7)-.5)*.02
   local pts={{x0,-4},{x0+.012,Y*.12},{x0-.008,Y*.22},{x0+.006,Y*.33}}
   for k=1,#pts-1 do
    local a,b=pts[k],pts[k+1]
    Sm.quad(S.P(a[1]-w,-.25,a[2]),S.P(a[1]+w,-.25,a[2]),S.P(b[1]+w,-.25,b[2]),S.P(b[1]-w,-.25,b[2]),'lgLava',1.0)
   end
  end
 end
 for k=0,7 do
  local i=floor((k+.5)/8*T.seg+rh(k,1,1)*4)
  if not S.gateAt(i,0)and not S.gateAt(i+1,0)then
   local th=S.th(i)
   local w=.022
   local prof={{-.6,-6},{-.6,Y*.34},{-4.6,Y*.68},{-9.6,Y+.6}}
   for m=1,#prof-1 do
    local a,b=prof[m],prof[m+1]
    Sm.quad(S.P(th-w,a[1],a[2]),S.P(th+w,a[1],a[2]),S.P(th+w,b[1],b[2]),S.P(th-w,b[1],b[2]),'lgLava',1.05)
   end
   local foot=S.P(th,-14,Y)
   fx.lavafalls[#fx.lavafalls+1]={x=foot[1],z=foot[3]}
  end
 end
 -- spires of rock standing in the fire, flames on some of them
 local Sp=C.part('spires')
 local placed=0
 for k=0,40 do
  if placed>=12 then break end
  local a=rh(k,2,3)*TAU
  local f=.52+rh(k,3,5)*.36
  local x,z=cx+cos(a)*T.fx*f,cz+sin(a)*T.fz*f
  -- keep the bridges' corridors and the platform clear
  if abs(x-cx)>30 and sqrt((x-cx)^2+(z-cz)^2)>P.platform+24 then
   local h=P.depth*(.42+rh(k,4,7)*.42)
   local tip=lib.crystal(Sp,x,Y-2,z,6+rh(k,5,9)*6,h,5,(rh(k,6,1)-.5)*.10,(rh(k,7,1)-.5)*.10,'lgObsidian',k)
   if rh(k,8,3)<.75 then
    fx.fires[#fx.fires+1]={x=tip[1],y=tip[2]-1.5,z=tip[3],s=2.4,phase=k*1.7,batch=true}
    fx.glows[#fx.glows+1]={x=tip[1],y=tip[2]+4,z=tip[3],r=30,col='red',a=.28}
   end
   placed=placed+1
  end
 end
 -- the platform: an octagon of obsidian, gold-edged, on its pillar
 local R=P.platform
 local Pl=C.part('platform')
 local function oct(k,r,y)local a=k/8*TAU+pi/8;return{cx+cos(a)*r,y,cz+sin(a)*r}end
 for k=0,7 do
  for j=0,2 do
   local r0,r1=R*j/3,R*(j+1)/3
   Pl.quad(oct(k,r0,0),oct(k+1,r0,0),oct(k+1,r1,0),oct(k,r1,0),T.field,1)
  end
  Pl.quad(oct(k,R,0),oct(k+1,R,0),oct(k+1,R,-9),oct(k,R,-9),'lgObsidian',.72)
  Pl.quad(oct(k,R+.25,-1.4),oct(k+1,R+.25,-1.4),oct(k+1,R+.25,0),oct(k,R+.25,0),'lgGold',1.0)
 end
 local D=C.part('platformTrim')
 D.decor(function()
  for k=0,7 do D.quad(oct(k,R-2.4,.06),oct(k+1,R-2.4,.06),oct(k+1,R,.06),oct(k,R,.06),'lgGold',1.02)end
 end)
 -- the pillar under it: sixteen ragged sides spreading to the lake
 local Pi=C.part('pillar')
 local NS,rings=16,4
 local function pp(i,j)
  local a=i/NS*TAU
  local t=j/rings
  local r=R*(.90-.30*t+.18*t*t*t)*(1+(rh(i%NS,j,11)-.5)*.14*t)
  return{cx+cos(a)*r,-9+(Y+9)*t,cz+sin(a)*r}
 end
 for j=0,rings-1 do for i=0,NS-1 do
  Pi.quad(pp(i,j),pp(i+1,j),pp(i+1,j+1),pp(i,j+1),'lgObsidian',.62+.10*j)
 end end
 for k=0,5 do
  local i=floor(rh(k,4,4)*NS)
  local a=(i+.5)/NS*TAU
  local function cp(t,off)local r=R*(.90-.30*t+.18*t*t*t)+.5;return{cx+cos(a+off)*r,-12+(Y+12)*t,cz+sin(a+off)*r}end
  Pi.quad(cp(.05,-.012),cp(.05,.012),cp(.95,.024),cp(.95,-.004),'lgLava',1.0)
 end
 -- the bridges, north to the dragon gate and south to the tunnel
 local apo=R*cos(pi/8)
 local W=P.bridge/2
 for _,sg in ipairs({-1,1})do
  local B=C.part(sg<0 and'bridgeN'or'bridgeS')
  local z0,z1=cz+sg*(apo-1),cz+sg*(T.fz+8)
  local za,zb=min(z0,z1),max(z0,z1)
  B.box(cx-W,-7,za,cx+W,0,zb,'lgObsidian',.92,{top=true})
  B.quad({cx-W,0,zb},{cx+W,0,zb},{cx+W,0,za},{cx-W,0,za},T.field,1)
  B.decor(function()
   lib.stripH(B,cx,za,cx,zb,.07,18,'lgCrimson',.95)
   lib.stripH(B,cx-9.4,za,cx-9.4,zb,.08,1.2,'lgGold',1)
   lib.stripH(B,cx+9.4,za,cx+9.4,zb,.08,1.2,'lgGold',1)
  end)
  B.box(cx-W-.3,-1.4,za,cx-W,0,zb,'lgGold',1)
  B.box(cx+W,-1.4,za,cx+W+.3,0,zb,'lgGold',1)
  -- piers down into the fire
  for _,u in ipairs({.36,.70})do
   local z=z0+(z1-z0)*u
   B.box(cx-W+2,Y,z-5,cx+W-2,-7,z+5,'lgObsidian',.70)
  end
  -- posts with fire bowls along both sides
  local n=floor((zb-za)/22)
  for k=1,n-1 do
   local z=za+(zb-za)*k/n
   for _,sx in ipairs({-1,1})do
    local x=cx+sx*(W-1.4)
    B.box(x-1,0,z-1,x+1,6.5,z+1,'lgObsidian',.85)
    B.box(x-1.8,6.5,z-1.8,x+1.8,7.6,z+1.8,'lgGold',1)
    if (k+(sx>0 and 1 or 0))%2==0 then fx.fires[#fx.fires+1]={x=x,y=7.8,z=z,s=.85,phase=k*1.3+sx}end
   end
  end
 end
 -- the fire's own light and smoke
 fx.lavaLevel=Y
 for k=0,15 do
  local a=k/16*TAU+rh(k,1,1)*.3
  local f=.35+rh(k,2,2)*.55
  fx.lava[#fx.lava+1]={x=cx+cos(a)*T.fx*f,z=cz+sin(a)*T.fz*f,r=50+rh(k,3,3)*40,phase=k*1.3}
 end
 -- flames licking up off the lake all round the pit
 for k=0,23 do
  local a=k/24*TAU+rh(k,4,4)*.2
  local f=.58+rh(k,5,5)*.32
  local x,z=cx+cos(a)*(T.fx-9)*f,cz+sin(a)*(T.fz-9)*f
  if abs(x-cx)>18 then fx.fires[#fx.fires+1]={x=x,y=Y+.5,z=z,s=2.6+rh(k,6,6)*1.6,phase=k*.9,batch=true}end
 end
 fx.embers[#fx.embers+1]={x=cx,y=Y,z=cz,r=T.fx-10,n=110,rise=P.depth+150,abyss=true}
 fx.glows[#fx.glows+1]={x=cx,y=Y+40,z=cz,r=T.fx,col='red',a=.12}
 S.platformR=R
 -- TEST197: the lake BOILS. Where blisters of crust swell and burst, and
 -- where the lake now and then throws a spurt of lava up into the pit
 -- (drawn and heard at runtime: see lavaFrame)
 local bubbles,spurts={},{}
 for k=0,160 do
  if #bubbles>=22 then break end
  -- (more of them on the side the battle camera looks down on)
  local a=k%5<3 and(-1.0+rh(k,11,5)*2.6)or rh(k,11,5)*TAU
  local f=.36+sqrt(rh(k,12,7))*.56
  local x,z=cx+cos(a)*(T.fx-14)*f,cz+sin(a)*(T.fz-14)*f
  if abs(x-cx)>P.bridge/2+6 and sqrt((x-cx)^2+(z-cz)^2)>R*.95+8 then
   local big=rh(k,13,9)<.32
   bubbles[#bubbles+1]={x=x,z=z,r=big and 7+rh(k,14,3)*5 or 2.6+rh(k,15,5)*3.4,
    per=2.4+rh(k,16,7)*3.0,ph=rh(k,17,9)*10,big=big}
  end
 end
 for k=0,40 do
  if #spurts>=4 then break end
  local a=(#spurts+.5)/4*TAU+(rh(k,18,3)-.5)*.6
  local f=.62+rh(k,19,5)*.22
  local x,z=cx+cos(a)*(T.fx-14)*f,cz+sin(a)*(T.fz-14)*f
  if abs(x-cx)>P.bridge/2+10 then
   spurts[#spurts+1]={x=x,z=z,per=11+rh(k,20,7)*6,ph=rh(k,21,9)*17,h=1+rh(k,22,3)*.35}
  end
 end
 C.lava={Y=Y,bubbles=bubbles,spurts=spurts}
end

------------------------------------------------------------------ TEST196
-- The other three get a stage of their own, as Lance has his pit of fire:
-- Lorelei fights on a floe of ice in a lake of black water, Bruno on a
-- summit above a sea of cloud, Agatha on a dais floating over a well of
-- spirits. The Pokemon stand where they always stand (y=0, 24 either side
-- of the centre), well inside each stage.

local function push(list,e)list[#list+1]=e;return e end
-- the stage's things that flare with the crowd's big moments (LeagueCrowd):
-- e[key] becomes base*(1+k*F), or base+k*F when `add`
local function flareTag(C,e,key,k,add)
 C.flares[#C.flares+1]={e=e,key=key,base=e[key]or 0,k=k,add=add}
 return e
end
-- a ragged radius r(a): an outline that is not a circle
local function ragged(R,seed,amt)
 amt=amt or .06
 local p1,p2,p3=rh(seed,1,1)*TAU,rh(seed,2,2)*TAU,rh(seed,3,3)*TAU
 return function(a)return R*(1+amt*(.55*sin(3*a+p1)+.30*sin(5*a+p2)+.15*sin(11*a+p3)))end
end
-- a slab of n sides round (cx,cz), radius rf(a): its top at y in `rings`
-- rings, its edge down by th
local function slab(E,cx,cz,y,th,n,rf,top,side,ts,ss,rings)
 rings=rings or 1
 local function P(k,yy,f)local a=k/n*TAU;local r=rf(a)*f;return{cx+cos(a)*r,yy,cz+sin(a)*r}end
 for k=0,n-1 do
  for j=0,rings-1 do
   local f0,f1=j/rings,(j+1)/rings
   E.quad(P(k,y,f0),P(k+1,y,f0),P(k+1,y,f1),P(k,y,f1),top,ts or 1)
  end
  E.quad(P(k,y,1),P(k+1,y,1),P(k+1,y-th,1),P(k,y-th,1),side,ss or .8)
 end
end
-- a box on any axes: centre p, half-axes u,v,w
local function obox(E,p,u,v,w,mat,t)
 local function c(a,b,d)return{p[1]+u[1]*a+v[1]*b+w[1]*d,p[2]+u[2]*a+v[2]*b+w[2]*d,p[3]+u[3]*a+v[3]*b+w[3]*d}end
 local A,B,Cc,D=c(-1,-1,-1),c(1,-1,-1),c(1,1,-1),c(-1,1,-1)
 local A2,B2,C2,D2=c(-1,-1,1),c(1,-1,1),c(1,1,1),c(-1,1,1)
 E.quad(A,B,Cc,D,mat,t*.9);E.quad(A2,B2,C2,D2,mat,t*.9)
 E.quad(A,B,B2,A2,mat,t*.75);E.quad(D,Cc,C2,D2,mat,t*1.05)
 E.quad(A,D,D2,A2,mat,t*.85);E.quad(B,Cc,C2,B2,mat,t*.85)
end
-- a hanging chain from a to b, sagging by `sag`, links turned alternately
local function chain(E,a,b,sag,mat,thick)
 thick=thick or 1
 local dx,dy,dz=b[1]-a[1],b[2]-a[2],b[3]-a[3]
 local len=sqrt(dx*dx+dy*dy+dz*dz)
 local n=max(2,floor(len/(3.6*thick)))
 local function at(u)return{a[1]+dx*u,a[2]+dy*u-sag*4*u*(1-u),a[3]+dz*u}end
 for k=0,n-1 do
  if M.pace then M.pace()end
  local p0,p1=at(k/n),at((k+1)/n)
  local ux,uy,uz=p1[1]-p0[1],p1[2]-p0[2],p1[3]-p0[3]
  local l=sqrt(ux*ux+uy*uy+uz*uz);ux,uy,uz=ux/l,uy/l,uz/l
  local hx,hz=-uz,ux;local hl=sqrt(hx*hx+hz*hz);if hl<1e-4 then hx,hz,hl=1,0,1 end;hx,hz=hx/hl,hz/hl
  local vx,vy,vz=uy*hz,uz*hx-ux*hz,-uy*hx
  local c={(p0[1]+p1[1])/2,(p0[2]+p1[2])/2,(p0[3]+p1[3])/2}
  local hu=l*.62
  local wA,wB=1.15*thick,.42*thick
  if k%2==1 then wA,wB=wB,wA end
  obox(E,c,{ux*hu,uy*hu,uz*hu},{hx*wA,0,hz*wA},{vx*wB,vy*wB,vz*wB},mat,.95)
 end
end
-- a funnelled wall down from the field's edge to y=Y in three courses
local function funnel(C,S,T,Y,mats,shades,inset,tag)
 inset=inset or{4,9}
 for i=0,T.seg-1,16 do
  local E=C.part((tag or'funnel')..':'..i)
  local i1=min(T.seg,i+16)
  band(E,S,i,i1,0,0,0,Y*.34,mats[1],shades[1])
  band(E,S,i,i1,0,Y*.34,-inset[1],Y*.68,mats[2],shades[2])
  band(E,S,i,i1,-inset[1],Y*.68,-inset[2],Y+.5,mats[3],shades[3])
 end
end
-- keep clear of the bridges' corridors and the stage
local function clearOf(S,x,z,R,margin,corridor)
 return abs(x-S.cx)>(corridor or 26)and sqrt((x-S.cx)^2+(z-S.cz)^2)>R+(margin or 20)
end

-- LORELEI: THE FROZEN LAKE. The bowl is a lake frozen black, mist lying on
-- it; the fight is on a great floe of ice standing up out of it, snow
-- drifted on its edge and cracks glowing in it; ice bridges run to the gate
-- and the tunnel; smaller floes are frozen into the lake, spikes of ice
-- stand out of it, icicles hang off the wall all round.
local function lake(C,S,T,lib)
 local P=T.lake
 local L=P.level
 local fx=C.fx
 local cx,cz=S.cx,S.cz
 -- the lake: black ice, deep and clear (its fractures slide under the
 -- surface as the camera moves), darker toward the wall
 local Wt=C.part('water')
 local NR=6
 for j=0,NR-1 do
  local f0,f1=j/NR,(j+1)/NR
  for i=0,T.seg-1 do
   local a,b=S.th(i),S.th(i+1)
   local function Q(f,th)return{cx+T.fx*f*cos(th),L,cz+T.fz*f*sin(th)}end
   Wt.quad(Q(f0,a),Q(f0,b),Q(f1,b),Q(f1,a),'lgIce',{.50-.10*f0,.50-.10*f0,.50-.10*f1,.50-.10*f1})
  end
 end
 -- the floe: thick ice, its edge going down under the water
 local R=P.floe
 local rf=ragged(R,7,.035)
 local F=C.part('floe')
 slab(F,cx,cz,0,-L+4,48,rf,T.field,'lgIce',1,.78,4)
 -- snow drifted round its edge, and the ice's edge under it
 local Dr=C.part('drift')
 for k=0,47 do
  local a0,a1=k/48*TAU,(k+1)/48*TAU
  local function Pt(a,f,y)local r=rf(a)*f;return{cx+cos(a)*r,y,cz+sin(a)*r}end
  local h0,h1=.9+rh(k,1,3)*1.1,.9+rh(k+1,1,3)*1.1
  if k==47 then h1=.9+rh(0,1,3)*1.1 end
  Dr.quad(Pt(a0,.90,.02),Pt(a1,.90,.02),Pt(a1,.965,h1),Pt(a0,.965,h0),'lgSnow',1.0)
  Dr.quad(Pt(a0,.965,h0),Pt(a1,.965,h1),Pt(a1,1.002,.25),Pt(a0,1.002,.25),'lgSnow',.92)
 end
 -- cracks in the floe, glowing from inside the ice
 local Ck=C.part('cracks')
 Ck.decor(function()
  for k=0,8 do
   local a=k/9*TAU+rh(k,2,1)*.5
   if abs(cos(a))>.25 then
    local r0=rf(a)*.97
    local r1=r0*(.62+rh(k,3,2)*.18)
    local x,z=cx+cos(a)*r0,cz+sin(a)*r0
    for q=1,3 do
     local u=q/3
     local aa=a+(rh(k,q,5)-.5)*.10
     local rr=r0+(r1-r0)*u
     local nx,nz=cx+cos(aa)*rr,cz+sin(aa)*rr
     lib.stripH(Ck,x,z,nx,nz,.05,1.2-u*.5,'lgCrystal',1.05)
     x,z=nx,nz
    end
   end
  end
 end)
 S.platformR=R*.965
 -- ice bridges to the gate and the tunnel
 local W=P.bridge/2
 for _,sg in ipairs({-1,1})do
  local B=C.part(sg<0 and'bridgeN'or'bridgeS')
  local z0,z1=cz+sg*(rf(sg<0 and -pi/2 or pi/2)*.93),cz+sg*(T.fz+8)
  local za,zb=min(z0,z1),max(z0,z1)
  B.box(cx-W,L-1,za,cx+W,0,zb,'lgIce',.82,{top=true})
  B.quad({cx-W,0,zb},{cx+W,0,zb},{cx+W,0,za},{cx-W,0,za},'lgIce',1)
  B.decor(function()
   lib.stripH(B,cx-W+2.2,za,cx-W+2.2,zb,.06,3.6,'lgSnow',1.0)
   lib.stripH(B,cx+W-2.2,za,cx+W-2.2,zb,.06,3.6,'lgSnow',1.0)
   lib.stripH(B,cx,za,cx,zb,.05,1.0,'lgSilver',1.0)
  end)
  -- crystal posts down both sides, a blue fire on every other
  local n=floor((zb-za)/22)
  for k=1,n-1 do
   local z=za+(zb-za)*k/n
   for _,sx in ipairs({-1,1})do
    local x=cx+sx*(W-1.6)
    local tip=lib.crystal(B,x,0,z,1.6,9+rh(k,sx,3)*4,5,0,0,'lgCrystal',k)
    if (k+(sx>0 and 1 or 0))%2==0 then
     flareTag(C,push(fx.fires,{x=x,y=tip[2]+.4,z=z,s=.8,phase=k*1.3+sx,col='ice'}),'s',.8)
    end
   end
  end
 end
 -- floes drifting, white with snow
 local Fl=C.part('floes')
 local placed=0
 for k=0,60 do
  if placed>=16 then break end
  local a=rh(k,4,3)*TAU
  local f=.60+rh(k,5,5)*.32
  local x,z=cx+cos(a)*T.fx*f,cz+sin(a)*T.fz*f
  if clearOf(S,x,z,R,14,P.bridge/2+10)then
   local r0=6+rh(k,6,7)*10
   slab(Fl,x,z,L+.8,1.4,7,ragged(r0,k+40,.18),'lgSnow','lgIce',.96,.8)
   placed=placed+1
  end
 end
 -- spikes of ice standing out of the water
 local Sp=C.part('icespikes')
 placed=0
 for k=0,60 do
  if placed>=11 then break end
  local a=rh(k,7,9)*TAU
  local f=.58+rh(k,8,11)*.30
  local x,z=cx+cos(a)*T.fx*f,cz+sin(a)*T.fz*f
  if clearOf(S,x,z,R,22,P.bridge/2+14)then
   local h=18+rh(k,9,13)*30
   local lean=.10+rh(k,10,3)*.12
   local ox,oz=(x-cx),(z-cz);local ol=sqrt(ox*ox+oz*oz);ox,oz=ox/ol,oz/ol
   local big=rh(k,11,5)<.4
   local tip=lib.crystal(Sp,x,L-1,z,big and 6 or 4,h,6,ox*lean,oz*lean,big and'lgCrystal'or'lgIce',k)
   lib.crystal(Sp,x+oz*5,L-1,z-ox*5,2.4,h*.45,5,ox*lean*1.4,oz*lean*1.4,'lgIce',k+3)
   if big then flareTag(C,push(fx.sparkles,{x=tip[1],y=tip[2]-2,z=tip[3],s=1.3,phase=k*.9}),'s',1.2)end
   fx.pools[#fx.pools+1]={x=x,y=L+.3,z=z,r=16,a=.10,col={.35,.70,1}}
   placed=placed+1
  end
 end
 -- icicles off the wall all round
 local Ic=C.part('icicles')
 for i=0,T.seg-1 do
  if not S.gateAt(i,0)then
   for q=0,1 do
    local th=S.th(i+.25+q*.5)
    local p=S.P(th,-.4,T.barrier.h-1.2)
    lib.icicle(Ic,p[1],p[2],p[3],.7+rh(i,q,3)*.5,3+rh(i,q,5)*6,'lgIce',4)
   end
  end
 end
 -- mist lying on the water
 for k=0,11 do
  local a=k/12*TAU+.2
  local f=.62+rh(k,1,9)*.25
  fx.mist[#fx.mist+1]={x=cx+cos(a)*T.fx*f,y=L+1.2,z=cz+sin(a)*T.fz*f,r=44,phase=k*1.7,col={.72,.86,1},a=.13,drift=16}
 end
 -- the cold light off the floe and the water
 C.addLight(cx,20,cz,R*1.6,.10)
 fx.pools[#fx.pools+1]={x=cx,y=.3,z=cz,r=R*.9,a=.05,col={.55,.80,1}}
end

-- BRUNO: THE SUMMIT. There is no floor: the arena stands round the top of
-- a mountain, the fight on its flat granite crown with the sparring mat on
-- it, cliffs falling away into a sea of cloud far below. Rope bridges of
-- timber run to the gate and the tunnel; two great war drums stand on the
-- crown's edge (they flare on the drummed chant); prayer flags run from the
-- mat's posts out to the stands.
local function summit(C,S,T,lib)
 local P=T.summit
 local Y=-P.depth
 local fx=C.fx
 local cx,cz=S.cx,S.cz
 -- the cliffs: granite going down into the cloud
 funnel(C,S,T,Y,{'lgRock','lgRock','lgRock'},{.70,.62,.55},{6,14},'cliff')
 -- the sea of cloud: a floor of it, and cloud-tops heaped on it in mounds
 local Cl=C.part('cloudsea')
 local NR,NS=4,48
 local function cp(j,i)
  local a=i/NS*TAU;local f=j/NR
  return{cx+cos(a)*(T.fx-12)*f,Y+4,cz+sin(a)*(T.fz-12)*f}
 end
 for j=0,NR-1 do for i=0,NS-1 do
  Cl.quad(cp(j,i),cp(j,i+1),cp(j+1,i+1),cp(j+1,i),'lgSnow',1.0)
 end end
 local mounds=0
 for k=0,90 do
  if mounds>=34 then break end
  local a=rh(k,1,29)*TAU
  local f=.25+sqrt(rh(k,2,31))*.70
  local x,z=cx+cos(a)*(T.fx-24)*f,cz+sin(a)*(T.fz-24)*f
  if sqrt((x-cx)^2+(z-cz)^2)>P.top*.55 then
   local r=16+rh(k,3,37)*22
   local h=r*(.45+rh(k,4,41)*.25)
   local NSg,NRg=9,3
   local function dp(i,j)
    local aa=i/NSg*TAU+k
    local t=j/NRg
    local rr=r*cos(t*pi/2)*(1+(rh(i%NSg,k,43)-.5)*.25*(1-t))
    return{x+cos(aa)*rr,Y+4+h*sin(t*pi/2),z+sin(aa)*rr}
   end
   for j=0,NRg-1 do for i=0,NSg-1 do
    Cl.quad(dp(i,j),dp(i+1,j),dp(i+1,j+1),dp(i,j+1),'lgSnow',1.0+.10*j)
   end end
   mounds=mounds+1
  end
 end
 -- the crown: flat granite, its edge ragged, the mountain under it
 local R=P.top
 local rf=ragged(R,11,.04)
 local Cr=C.part('crown')
 slab(Cr,cx,cz,0,5,40,rf,'lgGranite','lgRock',1,.80,3)
 local Mt=C.part('mountain')
 local NSd,rings=28,6
 local function mp(i,j)
  local a=i/NSd*TAU
  local t=j/rings
  local base=rf(a)
  -- ridges: every other side stands out, more so further down
  local ridge=(i%2==0)and .07 or -.03
  local r=base*(.99-.20*t+.66*t*t*t)*(1+(ridge+(rh(i%NSd,j,13)-.5)*.16)*min(1,t*3))
  return{cx+cos(a)*r,-5+(Y+2)*t,cz+sin(a)*r}
 end
 for j=0,rings-1 do for i=0,NSd-1 do
  Mt.quad(mp(i,j),mp(i+1,j),mp(i+1,j+1),mp(i,j+1),'lgRock',(i%2==0 and .74 or .62)-.03*j)
 end end
 -- snow clinging under the crown's edge, running down the ridges
 local Sn=C.part('mountainsnow')
 for i=0,NSd-1 do
  local a0,a1=i/NSd*TAU,(i+1)/NSd*TAU
  local function sp(a,y,f)local r=rf(a)*f;return{cx+cos(a)*r,y,cz+sin(a)*r}end
  local d0,d1=-6.2-rh(i,8,23)*1.6,-6.2-rh(i+1,8,23)*1.6
  if i==NSd-1 then d1=-6.2-rh(0,8,23)*1.6 end
  Sn.quad(sp(a0,-4.6,1.012),sp(a1,-4.6,1.012),sp(a1,d1,1.0),sp(a0,d0,1.0),'lgSnow',1.0)
  -- a tongue or two of snow down the rock, where the ridge holds it
  for q=0,1 do
   if rh(i,q,29)<.55 then
    local u0=.15+q*.45+rh(i,q,31)*.1
    local u1=u0+.18+rh(i,q,37)*.12
    local am=a0+(a1-a0)*(u0+u1)/2
    local len=4+rh(i,q,41)^1.6*24
    local ya,yb=d0+(d1-d0)*u0,d0+(d1-d0)*u1
    Sn.quad(sp(a0+(a1-a0)*u0,ya,1.0),sp(a0+(a1-a0)*u1,yb,1.0),sp(am,(ya+yb)/2-len,.99+.005*len),sp(am,(ya+yb)/2-len,.99+.005*len),'lgSnow',.95)
   end
  end
 end
 S.platformR=R*.96
 -- rope bridges: planks on ropes, sagging over the drop
 local W=P.bridge/2
 for _,sg in ipairs({-1,1})do
  local B=C.part(sg<0 and'bridgeN'or'bridgeS')
  local z0,z1=cz+sg*(rf(sg<0 and -pi/2 or pi/2)*.97),cz+sg*(T.fz+8)
  local sag=5
  local function y(u)return -sag*sin(pi*u)end
  local len=abs(z1-z0)
  local n=floor(len/4.2)
  for k=0,n-1 do
   if M.pace then M.pace()end
   local u0,u1=k/n,(k+.78)/n
   local za,zb=z0+(z1-z0)*u0,z0+(z1-z0)*u1
   local ya,yb=y(u0),y(u1)
   local lo,hi=min(za,zb),max(za,zb)
   local jag=(rh(k,sg,3)-.5)*1.4
   B.quad({cx-W+jag,ya,za},{cx+W+jag,ya,za},{cx+W+jag,yb,zb},{cx-W+jag,yb,zb},'lgWood',.92)
   B.quad({cx-W+jag,ya-.7,za},{cx+W+jag,ya-.7,za},{cx+W+jag,yb-.7,zb},{cx-W+jag,yb-.7,zb},'lgWood',.55)
  end
  -- the ropes: two under the planks, two hand ropes, hangers between
  for _,sx in ipairs({-1,1})do
   local x=cx+sx*(W+.6)
   local m=24
   for k=0,m-1 do
    local u0,u1=k/m,(k+1)/m
    local za,zb=z0+(z1-z0)*u0,z0+(z1-z0)*u1
    local hy0,hy1=y(u0)*.55+6.5,y(u1)*.55+6.5
    B.quad({x,hy0,za},{x,hy1,zb},{x,hy1+.5,zb},{x,hy0+.5,za},'lgWood',.75)
    B.quad({x,y(u0)-.4,za},{x,y(u1)-.4,zb},{x,y(u1)+.1,zb},{x,y(u0)+.1,za},'lgWood',.65)
    if k%3==0 then B.quad({x-.2,y(u0),za},{x+.2,y(u0),za},{x+.2,hy0,za},{x-.2,hy0,za},'lgWood',.75)end
   end
   -- posts at both ends
   for _,z in ipairs({z0,z1})do B.box(x-1.2,0,z-1.2,x+1.2,9,z+1.2,'lgWood',.88)end
  end
 end
 -- the great war drums on the crown either side of the opponent, their
 -- heads to the stands behind you (the battle camera sees them face on)
 local Dm=C.part('drums')
 for _,sx in ipairs({-1,1})do
  local x0,z0=cx+sx*(R*.82),cz-26
  local yc,rr,hl=13,9,6.5
  local NSg=16
  for k=0,NSg-1 do
   local a0,a1=k/NSg*TAU,(k+1)/NSg*TAU
   local bulge=1.08
   local function rim(a,dz,f)return{x0+cos(a)*rr*f,yc+sin(a)*rr*f,z0+dz}end
   Dm.quad(rim(a0,-hl,1),rim(a1,-hl,1),rim(a1,0,bulge),rim(a0,0,bulge),'inLacquer',.92)
   Dm.quad(rim(a0,0,bulge),rim(a1,0,bulge),rim(a1,hl,1),rim(a0,hl,1),'inLacquer',.92)
   for _,dz in ipairs({-hl,hl})do
    Dm.quad({x0,yc,z0+dz*1.002},rim(a0,dz*1.002,1),rim(a1,dz*1.002,1),{x0,yc,z0+dz*1.002},'lgSnow',1.05)
    Dm.quad(rim(a0,dz*1.004,1),rim(a1,dz*1.004,1),rim(a1,dz*1.004,1.08),rim(a0,dz*1.004,1.08),'lgGold',1.0)
   end
   -- a gold band round its middle
   Dm.quad(rim(a0,-.8,bulge*1.004),rim(a1,-.8,bulge*1.004),rim(a1,.8,bulge*1.004),rim(a0,.8,bulge*1.004),'lgGold',1.0)
  end
  -- its stand: two timber legs either side, a beam under it
  for _,dx in ipairs({-7,7})do
   Dm.box(x0+dx-1,0,z0-1,x0+dx+1,yc+2,z0+1,'lgWood',.85)
  end
  Dm.box(x0-8,1.5,z0-1.2,x0+8,3.2,z0+1.2,'lgWood',.8)
  flareTag(C,push(fx.glows,{x=x0,y=yc,z=z0+hl+1.5,r=16,col='gold',a=0}),'a',.55,true)
 end
 -- cloud drifting in the drop, and the air's light snow
 for k=0,13 do
  local a=k/14*TAU+.3
  local f=.45+rh(k,2,7)*.45
  fx.mist[#fx.mist+1]={x=cx+cos(a)*T.fx*f,y=Y+14+rh(k,3,5)*16,z=cz+sin(a)*T.fz*f,r=58+rh(k,4,3)*30,phase=k*1.9,col={1,1,1},a=.30,drift=26}
 end
 fx.snow={x0=cx-T.fx-80,x1=cx+T.fx+80,z0=cz-T.fz-80,z1=cz+T.fz+80,y0=Y,y1=160,n=110}
 C.addLight(cx,40,cz,R*2.2,.12)
end

-- AGATHA: THE SPIRIT WELL. There is no floor: a well goes down into a
-- violet glow, spirits rising out of it. The fight is on a dais of slate
-- that floats over it, a ring of glowing runes on it, a cone of broken rock
-- under it, held by four great chains to the wall. Stones float in a line
-- to the gate and to the tunnel; islands of rock drift in the well with
-- their graves on them.
local function well(C,S,T,lib)
 local P=T.well
 local Y=-P.depth
 local fx=C.fx
 local cx,cz=S.cx,S.cz
 C.addLight(cx,Y+30,cz,P.depth*2.4,.30)
 funnel(C,S,T,Y,{'lgSlate','lgSlate','lgSlate'},{.58,.52,.46},{5,11},'wellwall')
 -- violet seams glowing down the stone
 local Sm=C.part('wellseams')
 neon(C,function()
  for i=0,T.seg-1 do
   if not S.gateAt(i,0)and rh(i,7,5)<.13 then
    local th=S.th(i+.5)
    local w=.004+rh(i,8,3)*.004
    local pts={{th,-3,-.3},{th+.010,Y*.25,-.3},{th-.006,Y*.34,-.3},{th+.004,Y*.55,-2.6},{th-.004,Y*.68,-4.3}}
    for k=1,#pts-1 do
     local a,b=pts[k],pts[k+1]
     Sm.quad(S.P(a[1]-w,a[3],a[2]),S.P(a[1]+w,a[3],a[2]),S.P(b[1]+w,b[3],b[2]),S.P(b[1]-w,b[3],b[2]),'lgAmethyst',1)
    end
   end
  end
 end)
 -- the bottom: a void, the night sky's own dark, lit violet by what
 -- rises out of it
 local Gb=C.part('wellglow')
 neon(C,function()
  for j=0,3 do for i=0,T.seg-1,2 do
   local a,b=S.th(i),S.th(i+2)
   local function Q(f,th)return{cx+(T.fx-10)*f*cos(th),Y,cz+(T.fz-10)*f*sin(th)}end
   Gb.quad(Q(j/4,a),Q(j/4,b),Q((j+1)/4,b),Q((j+1)/4,a),'lgNight',1)
  end end
 end)
 -- the dais
 local R=P.dais
 local rf=function()return R end
 local Dz=C.part('dais')
 slab(Dz,cx,cz,0,5,40,rf,T.field,'lgSlate',1,.78,3)
 lib.ringH(Dz,cx,cz,.04,R-1.6,R+.3,40,'lgSilver',1.02)
 local Rn=C.part('runes')
 neon(C,function()
  Rn.decor(function()
   lib.ringH(Rn,cx,cz,.06,R-8,R-6.8,48,'lgAmethyst',3)
   for k=0,23 do
    local a=k/24*TAU
    local x,z=cx+cos(a)*(R-4.4),cz+sin(a)*(R-4.4)
    local tx,tz=-sin(a),cos(a)
    local s=1.2+rh(k,1,1)*.6
    Rn.quad({x-tx*s,.06,z-tz*s},{x+cos(a)*s*.8,.06,z+sin(a)*s*.8},{x+tx*s,.06,z+tz*s},{x-cos(a)*s*.8,.06,z-sin(a)*s*.8},'lgAmethyst',3)
   end
  end)
 end)
 -- the cone of broken rock under it, cracks of violet in it
 local Co=C.part('daiscone')
 local NSd,rings=18,4
 local tip=Y*.62
 local function kp(i,j)
  local a=i/NSd*TAU;local t=j/rings
  local r=R*.98*(1-t)^1.15*(1+(rh(i%NSd,j,17)-.5)*.30*min(1,t*2.5))
  return{cx+cos(a)*r,-5+(tip+5)*t,cz+sin(a)*r}
 end
 for j=0,rings-1 do for i=0,NSd-1 do Co.quad(kp(i,j),kp(i+1,j),kp(i+1,j+1),kp(i,j+1),'lgSlate',.60-.05*j)end end
 neon(C,function()
  for k=0,5 do
   local i=floor(rh(k,9,9)*NSd)
   local function cpp(t,off)local a=(i+.5)/NSd*TAU+off;local r=R*.98*(1-t)^1.15+.6;return{cx+cos(a)*r,-5+(tip+5)*t,cz+sin(a)*r}end
   Co.quad(cpp(.08,-.010),cpp(.08,.010),cpp(.85,.02),cpp(.85,-.002),'lgAmethyst',3)
  end
 end)
 S.platformR=R
 -- four great chains to the wall
 local Ch=C.part('chains')
 for k=0,3 do
  local a=k/4*TAU+pi/4
  local from={cx+cos(a)*(R-2),-1.5,cz+sin(a)*(R-2)}
  local to=S.P(a,-.6,T.barrier.h-2.5)
  chain(Ch,from,to,7,'dnGunmetal',1.15)
  -- the anchors: an iron plate on the dais, a ring on the wall
  Ch.box(from[1]-2.2,-.2,from[3]-2.2,from[1]+2.2,.5,from[3]+2.2,'dnGunmetal',.85)
  local w=S.P(a,-.2,T.barrier.h-2.5)
  Ch.box(w[1]-2,w[2]-2,w[3]-2,w[1]+2,w[2]+2,w[3]+2,'dnGunmetal',.8)
 end
 -- stones floating in a line to the gate and the tunnel
 local St=C.part('stones')
 for _,sg in ipairs({-1,1})do
  local z0,z1=cz+sg*(R+2),cz+sg*(T.fz+1)
  local n=max(3,floor(abs(z1-z0)/P.step))
  for k=0,n-1 do
   local u=(k+.5)/n
   local z=z0+(z1-z0)*u
   local w,d=9+rh(k,sg,3)*2,(abs(z1-z0)/n)*.36
   local x=cx+(rh(k,sg,5)-.5)*4
   local yt=(rh(k,sg,7)-.5)*.8
   St.box(x-w,yt-3,z-d,x+w,yt,z+d,'lgSlate',.9,{bottom=true})
   St.quad({x-w,yt-3,z-d},{x+w,yt-3,z-d},{x,yt-9,z},{x,yt-9,z},'lgSlate',.55)
   St.quad({x+w,yt-3,z+d},{x-w,yt-3,z+d},{x,yt-9,z},{x,yt-9,z},'lgSlate',.50)
   St.quad({x-w,yt-3,z+d},{x-w,yt-3,z-d},{x,yt-9,z},{x,yt-9,z},'lgSlate',.52)
   St.quad({x+w,yt-3,z-d},{x+w,yt-3,z+d},{x,yt-9,z},{x,yt-9,z},'lgSlate',.52)
   fx.candles[#fx.candles+1]={x=x+w-1.5,y=yt+.1,z=z,s=.6,phase=k*1.9+sg,col=k%2==0 and'violet'or nil}
  end
 end
 -- islands of rock drifting in the well, their graves on them
 local Is=C.part('islands')
 local placed=0
 for k=0,60 do
  if placed>=7 then break end
  local a=rh(k,1,19)*TAU
  local f=.52+rh(k,2,23)*.32
  local x,z=cx+cos(a)*T.fx*f,cz+sin(a)*T.fz*f
  if clearOf(S,x,z,R,20,24)then
   local r0=10+rh(k,3,3)*9
   local yt=-26+rh(k,4,5)*30
   local rr=ragged(r0,k+60,.14)
   slab(Is,x,z,yt,2.5,9,rr,'lgSlate','lgSlate',.88,.65)
   for q=0,8 do
    local a0,a1=q/9*TAU,(q+1)/9*TAU
    Is.quad({x+cos(a0)*rr(a0),yt-2.5,z+sin(a0)*rr(a0)},{x+cos(a1)*rr(a1),yt-2.5,z+sin(a1)*rr(a1)},{x,yt-2.5-r0*1.3,z},{x,yt-2.5-r0*1.3,z},'lgSlate',.50)
   end
   -- graves: a headstone or two, rounded, leaning a little
   local ng=1+floor(rh(k,5,7)*2.4)
   for g=0,ng-1 do
    local gx,gz=x+(rh(k,g,9)-.5)*r0*.9,z+(rh(k,g,11)-.5)*r0*.9
    local yaw=math.atan2(cx-gx,cz-gz)+(rh(k,g,13)-.5)*.5
    local L=C.K.model(Is,gx,yt,gz,yaw,1)
    L.box(-2.2,0,-.6,2.2,5,.6,'lgSlate',.95)
    lib.fan(L,0,5,.62,2.2,8,'lgSlate',.95,0,nil,0,pi)
    lib.fan(L,0,5,-.62,2.2,8,'lgSlate',.80,0,nil,0,pi)
    L.box(-1.2,3.2,.62,1.2,3.6,.7,'lgSilver',.9)
   end
   fx.candles[#fx.candles+1]={x=x,y=yt+.1,z=z+r0*.3,s=.65,phase=k*2.3,col='violet'}
   placed=placed+1
  end
 end
 -- the spirits: violet sparks rising out of the well, its mist, its glow
 fx.embers[#fx.embers+1]={x=cx,y=Y,z=cz,r=T.fx-14,n=90,rise=P.depth+120,abyss=true,col={.72,.45,1}}
 flareTag(C,push(fx.glows,{x=cx,y=Y+30,z=cz,r=T.fx*.9,col='violet',a=.16}),'a',1.4)
 for k=0,11 do
  local a=k/12*TAU+.4
  local f=.30+rh(k,6,3)*.55
  fx.mist[#fx.mist+1]={x=cx+cos(a)*T.fx*f,y=Y*.55+rh(k,7,7)*20,z=cz+sin(a)*T.fz*f,r=48+rh(k,8,9)*20,phase=k*1.3,col={.55,.40,.80},a=.14,drift=14}
 end
end

-- the tiers of seats; the crowd's places are collected as we go
local function tiers(C,S,T,places)
 local d=S.gap
 local y=T.barrier.h+3
 local first=true
 for ti,tier in ipairs(T.tiers)do
  if not first then d=d+(tier.walk or 3);y=y+2 end
  local y1=y
  for k=0,tier.rows-1 do
   local dA,dB=d+k*tier.depth,d+(k+1)*tier.depth
   local ty=y1+k*tier.rise
   local below=(k==0)and(first and 0 or y1-tier.rise-2)or ty-tier.rise
   for i=0,T.seg-1 do
    local gate=first and S.gateAt(i,k)
    if not gate then
     local E=C.part('tier'..ti..':'..floor(i/16))
     local a,b=S.th(i),S.th(i+1)
     local aisle=S.aisleAt(i)
     E.quad(S.P(a,dA,below),S.P(b,dA,below),S.P(b,dA,ty),S.P(a,dA,ty),tier.riser,.82)
     E.quad(S.P(a,dA,ty),S.P(b,dA,ty),S.P(b,dB,ty),S.P(a,dB,ty),aisle and T.aisle or tier.tread,aisle and 1.0 or .92)
     -- a seat-back lip along the back of each tread
     if not aisle then
      E.quad(S.P(a,dB-1.2,ty),S.P(b,dB-1.2,ty),S.P(b,dB-1.2,ty+1.6),S.P(a,dB-1.2,ty+1.6),tier.tread,.80)
      places[#places+1]={i=i,row=k,tier=ti,d=dA+tier.depth*.42,y=ty}
     end
    end
   end
  end
  local dEnd=d+tier.rows*tier.depth
  local top=y1+(tier.rows-1)*tier.rise
  local nxt=T.tiers[ti+1]
  local capW=nxt and(nxt.walk or 3)+1 or 3
  for i=0,T.seg-1,16 do
   local E=C.part('back'..ti..':'..i)
   local i1=min(T.seg,i+16)
   band(E,S,i,i1,dEnd,top,dEnd,top+tier.back,tier.backMat,.86)
   band(E,S,i,i1,dEnd,top+tier.back,dEnd+capW,top+tier.back,tier.trim,1.0)
   band(E,S,i,i1,dEnd-.2,top+tier.back-1.4,dEnd-.2,top+tier.back,tier.trim,1.0)
   if tier.ribbon then neon(C,function()band(E,S,i,i1,dEnd-.3,top+tier.back*.35,dEnd-.3,top+tier.back*.70,'dnNeon',5)end)end
  end
  tier.dEnd,tier.top,tier.d0,tier.y1=dEnd,top+tier.back,d,y1
  d=dEnd;y=top+tier.back;first=false
 end
 S.rimD,S.rimY=d,y
end

-- the players' tunnel under the stands (north behind the opponent; the
-- Champion's stadium has one south too)
local function tunnel(C,S,T,g,centre,tag)
 if not g then return end
 local tier=T.tiers[1]
 local E=C.part('tunnel:'..tag)
 local i0,i1=centre-g.half,centre+g.half
 local d0,d1=S.gap,S.gap+g.rows*tier.depth
 local yt=tier.y1+(g.rows-1)*tier.rise
 -- the soffit (the underside of the rows above), the back, the sides
 band(E,S,i0,i1,d0,yt,d1,yt,'lgObsidian',.35)
 band(E,S,i0,i1,d1,0,d1,yt,'lgObsidian',.18)
 band(E,S,i0,i1,d0,.02,d1,.02,T.walk,.45)
 for _,i in ipairs({i0,i1})do
  local a=S.th(i)
  E.quad(S.P(a,d0,0),S.P(a,d1,0),S.P(a,d1,yt),S.P(a,d0,yt),tier.riser,.55)
 end
 -- the front face of the rows above, a lintel over the opening, and a
 -- deck on the tunnel's roof (it is what a high camera sees of it)
 band(E,S,i0,i1,d0,yt-3,d0,yt,tier.trim,1.0)
 band(E,S,i0,i1,d0,yt+.12,d1,yt+.12,tier.riser,.92)
 band(E,S,i0,i1,d0,yt+.12,d0,yt+3.2,tier.trim,1.0)
 return {i0=i0,i1=i1,d0=d0,d1=d1,yt=yt}
end

------------------------------------------------------------------ dressing
-- the shared kit for the theme builders below
local function kit(C)
 local K=C.K
 return K,V.require('LeagueRooms').lib
end
-- a self-lit screen at angle th, d beyond the field's edge, its foot at y,
-- facing the field: on legs down to `legTo`, or hung on cables up to `hangTo`
local function screen(C,S,th,d,y,w,h,words,frameMat,glowMat,letterMat,legTo,hangTo)
 local K=C.K
 local E=C.part('screen:'..floor(th*100))
 local p=S.P(th,d,0)
 -- face the centre
 local dx,dz=S.cx-p[1],S.cz-p[3]
 local yaw=math.atan2(dx,dz)
 local L=K.model(E,p[1],y,p[3],yaw,1)
 L.box(-w/2-3,-3,-3,w/2+3,h+3,0,frameMat or'dnGunmetal',1)
 L.box(-w/2,0,0,w/2,h,.5,glowMat or'inScreen',1)
 if legTo then
  L.box(-w/2+4,legTo-y,-4,-w/2+9,-3,-1,frameMat or'dnGunmetal',.8)
  L.box(w/2-9,legTo-y,-4,w/2-4,-3,-1,frameMat or'dnGunmetal',.8)
 end
 if hangTo then
  for _,x in ipairs({-w/2+8,w/2-8})do L.box(x-.4,h+3,-1.9,x+.4,hangTo-y,-1.1,'lgSilver',.9)end
 end
 -- the lines, stacked and centred in the panel (each shrinks to fit the
 -- width; the whole block shrinks to fit the height)
 local total,gap=0,0
 for i,line in ipairs(words or{})do total=total+5*(line.s or 2);if i>1 then gap=gap+(line.s or 2)*.8 end end
 local k=min(1,(h-6)/max(1,total+gap))
 local yy=h-3-((h-6)-(total+gap)*k)/2
 for i,line in ipairs(words or{})do
  local sc=(line.s or 2)*k
  if i>1 then yy=yy-sc*.8 end
  K.inscription(L,line.t,0,yy-5*sc,.5,sc,letterMat or'inPanel',w-8)
  yy=yy-5*sc
 end
 return L
end
-- a floodlight bank: a lit panel on a mast or the roof edge, aimed in
local function floods(C,S,th,d,y,fx,col)
 local E=C.part('floods')
 local p=S.P(th,d,0)
 local dx,dz=S.cx-p[1],S.cz-p[3]
 local L=C.K.model(E,p[1],y,p[3],math.atan2(dx,dz),1)
 L.box(-11,-1,-2,11,9,0,'dnGunmetal',.8)
 for r=0,1 do for c=0,3 do
  L.box(-10+c*5,r*4.5,.0,-6+c*5,r*4.5+3.6,.6,'inPanel',1)
 end end
 C.fx.glows[#C.fx.glows+1]={x=p[1],y=y+4,z=p[3],r=26,col=col or'white',a=.30}
 C.fx.beams[#C.fx.beams+1]={x=p[1],y=y+4,z=p[3],tx=S.cx+(p[1]-S.cx)*.25,ty=0,tz=S.cz+(p[3]-S.cz)*.25,r0=10,r1=46,col={1,.97,.90},a=.035}
 C.addLight(p[1],y,p[3],520,.22)
end

local THEME_DRESS={}

THEME_DRESS.lorelei=function(C,S,T)
 local K,lib=kit(C)
 local fx=C.fx
 local D=C.part('emblem')
 D.decor(function()
  lib.ringH(D,S.cx,S.cz,.08,34,40,64,'lgCrystal',1.0)
  lib.snowflake(D,S.cx,S.cz,.10,30,'lgSilver','lgCrystal',0)
 end)
 -- crystal spires along the rim, glowing from within
 local E=C.part('spires')
 for i=0,T.seg-1,4 do
  local th=S.th(i+.5)
  local p=S.P(th,S.rimD+1,S.rimY)
  local big=(i%12==0)
  local h=big and 46+rh(i,1,3)*24 or 18+rh(i,2,5)*14
  local tip=lib.crystal(E,p[1],p[2],p[3],big and 4.2 or 2.4,h,6,(S.cx-p[1])*.0004,(S.cz-p[3])*.0004,'lgCrystal',i)
  if big then flareTag(C,push(fx.sparkles,{x=tip[1],y=tip[2]-2,z=tip[3],s=1.6,phase=i*.7}),'s',1.0)end
 end
 -- the ice palace gate behind the opponent: pillars, an arch of crystal
 local g=S.northTunnel
 if g then
  local G=C.part('gate')
  for _,i in ipairs({g.i0,g.i1})do
   local p=S.P(S.th(i),S.gap-1,0)
   lib.crystal(G,p[1],0,p[3],5.5,g.yt+22,6,0,0,'lgIce',i)
   flareTag(C,push(fx.fires,{x=p[1],y=g.yt+3,z=p[3]+4,s=1.5,phase=i,col='ice'}),'s',.7)
   fx.pools[#fx.pools+1]={x=p[1],y=.3,z=p[3]+10,r=30,a=.12,col={.35,.65,1}}
  end
  local mid=S.P(S.th(S.north),S.gap-2,g.yt+10)
  local L=K.model(G,mid[1],mid[2],mid[3]+1,0,1)
  lib.fan(L,0,0,.2,8,24,'lgIce',1)
  lib.ringXY(L,0,0,.4,8,10.5,24,'lgSilver',1.05)
  lib.starXY(L,0,0,.6,7,2.2,6,'lgCrystal',1.05,pi/2)
  L.box(-30,-12,-2,30,-8,2,'lgSilver',1)
 end
 screen(C,S,S.th(S.north),S.rimD+6,S.rimY+6,96,34,{{t=T.title,s=4},{t='ELITE FOUR',s=2}},'lgSilver','inScreen','inPanel',S.rimY)
 -- four floodlight banks on silver masts beyond the stands
 for k=0,3 do
  local th=S.th(T.seg/8+k*T.seg/4)
  local p=S.P(th,S.rimD+10,0)
  local M2=C.part('masts')
  M2.box(p[1]-2,0,p[3]-2,p[1]+2,S.rimY+70,p[3]+2,'lgSilver',.9)
  floods(C,S,th,S.rimD+10,S.rimY+70,fx,'ice')
 end
 fx.snow={x0=S.cx-T.fx-120,x1=S.cx+T.fx+120,z0=S.cz-T.fz-120,z1=S.cz+T.fz+120,y0=0,y1=200,n=320}
 fx.aurora={
  {x0=S.cx-500,z0=S.cz-420,x1=S.cx+500,z1=S.cz-520,y=340,h=150,phase=0},
  {x0=S.cx-560,z0=S.cz-80,x1=S.cx-460,z1=S.cz+460,y=320,h=120,phase=2.1},
  {x0=S.cx+520,z0=S.cz-200,x1=S.cx+560,z1=S.cz+420,y=330,h=130,phase=4.2},
 }
 -- (the mist lies on the lake now: see lake())
 if not T.lake then
  for k=0,5 do
   local a=k/6*TAU
   fx.mist[#fx.mist+1]={x=S.cx+cos(a)*T.fx*.6,y=1.5,z=S.cz+sin(a)*T.fz*.6,r=46,phase=k*1.7,col={.70,.85,1},a=.08}
  end
 end
end

THEME_DRESS.bruno=function(C,S,T)
 local K,lib=kit(C)
 local fx=C.fx
 local F=V.require('LeagueFlora')
 -- the crimson sparring mat, white-edged, with a gold sun at its heart
 local D=C.part('emblem')
 D.decor(function()
  local hw=60
  D.quad({S.cx-hw,.07,S.cz+hw},{S.cx+hw,.07,S.cz+hw},{S.cx+hw,.07,S.cz-hw},{S.cx-hw,.07,S.cz-hw},'lgCrimson',.95)
  for _,s in ipairs({{-hw,-hw,hw,-hw},{-hw,hw,hw,hw},{-hw,-hw,-hw,hw},{hw,-hw,hw,hw}})do
   lib.stripH(D,S.cx+s[1],S.cz+s[2],S.cx+s[3],S.cz+s[4],.09,2.4,'lgSnow',1.0)
  end
  lib.starH(D,S.cx,S.cz,.10,22,9,12,'lgGold','lgBronze',1.0)
  lib.ringH(D,S.cx,S.cz,.11,24,26,48,'lgGold',1.0)
 end)
 -- corner posts of the mat with banners and lanterns
 local P2=C.part('posts')
 for _,c in ipairs({{-60,-60},{60,-60},{-60,60},{60,60}})do
  local x,z=S.cx+c[1],S.cz+c[2]
  P2.box(x-1.2,0,z-1.2,x+1.2,14,z+1.2,'lgWood',.9)
  P2.box(x-2,14,z-2,x+2,16,z+2,'lgGold',1)
  flareTag(C,push(fx.fires,{x=x,y=16.3,z=z,s=.9,phase=x*.1+z*.07}),'s',.9)
 end
 -- timber posts on the rim: crimson banners and torches between
 local R=C.part('rim')
 for i=0,T.seg-1,4 do
  local th=S.th(i)
  local p=S.P(th,S.rimD+1,S.rimY)
  R.box(p[1]-1.6,p[2],p[3]-1.6,p[1]+1.6,p[2]+34,p[3]+1.6,'lgWood',.85)
  if i%8==0 then
   local p2=S.P(S.th(i+2),S.rimD+.5,S.rimY)
   local dx,dz=S.cx-p2[1],S.cz-p2[3]
   local L=K.model(R,p2[1],p2[2],p2[3],math.atan2(dx,dz),1)
   L.box(-6,10,-.3,6,32,.3,'lgCrimson',.95)
   L.box(-6.5,31,-.5,6.5,32.5,.5,'lgGold',1)
   lib.starXY(L,0,22,.35,3.6,1.6,8,'lgGold',1)
  else
   flareTag(C,push(fx.fires,{x=p[1],y=p[2]+35,z=p[3],s=1.1,phase=i*1.3}),'s',.6)
   R.box(p[1]-2.2,p[2]+34,p[3]-2.2,p[1]+2.2,p[2]+35,p[3]+2.2,'lgBronze',1)
  end
 end
 -- a pagoda eave round the back of the stands
 S.roofY=max(S.roofY or 0,S.rimY+35)
 for i=0,T.seg-1,16 do
  local E=C.part('eave:'..i)
  band(E,S,i,min(T.seg,i+16),S.rimD+3,S.rimY+34,S.rimD-18,S.rimY+29,'lgWood',.62)
  band(E,S,i,min(T.seg,i+16),S.rimD-18,S.rimY+27.6,S.rimD-18,S.rimY+29,'lgGold',1)
 end
 -- the gate behind Bruno: a lacquered gateway with the great gong above
 local g=S.northTunnel
 if g then
  local G=C.part('gate')
  local mid=S.P(S.th(S.north),S.gap-3,0)
  local L=K.model(G,mid[1],0,mid[3],0,1)
  for _,x in ipairs({-26,26})do L.box(x-2.4,0,-2.4,x+2.4,g.yt+16,2.4,'inLacquer',.95)end
  L.box(-34,g.yt+12,-3,34,g.yt+16,3,'inLacquer',1)
  L.box(-38,g.yt+17,-3.5,38,g.yt+20,3.5,'lgWood',.85)
  lib.fan(L,0,g.yt+38,-1,14,24,'lgBronze',1)
  lib.ringXY(L,0,g.yt+38,-.6,10,13,24,'lgGold',1)
  L.box(-1,g.yt+20,-1,1,g.yt+24,1,'lgWood',.9)
  for _,x in ipairs({-42,42})do
   local X=mid[1]+x
   F.limb(G,'lgWood',{X,0,mid[3]+6},{X,9,mid[3]+6},5.5,5.5,10,.9)
   lib.fanH(G,X,mid[3]+6,9.05,5.6,10,'lgSnow',1)
  end
  flareTag(C,push(fx.glows,{x=mid[1],y=g.yt+38,z=mid[3],r=34,col='gold',a=.22}),'a',2.4)
 end
 screen(C,S,S.th(S.north),S.rimD+6,S.rimY+40,90,32,{{t=T.title,s=4},{t='ELITE FOUR',s=2}},'lgWood','inLacquer','lgGold',S.rimY)
 -- the mountain round the arena: peaks in a ring, snow on their heads
 local Mtn=C.part('peaks')
 for k=0,17 do
  local a=k/18*TAU+rh(k,1,1)*.2
  local r=640+rh(k,2,2)*260
  local x,z=S.cx+cos(a)*r,S.cz+sin(a)*r
  local h=180+rh(k,3,3)*220;local w=150+rh(k,4,4)*110
  for s=0,6 do
   local b0,b1=s/7*TAU,(s+1)/7*TAU
   local p0={x+cos(b0)*w,-40,z+sin(b0)*w};local p1={x+cos(b1)*w,-40,z+sin(b1)*w}
   local q0={x+cos(b0)*w*.30,h*.72,z+sin(b0)*w*.30};local q1={x+cos(b1)*w*.30,h*.72,z+sin(b1)*w*.30}
   Mtn.quad(p0,p1,q1,q0,'lgRock',.70)
   Mtn.quad(q0,q1,{x,h,z},{x,h,z},'lgSnow',.95)
  end
 end
 for k=0,7 do
  local a=k/8*TAU
  fx.embers[#fx.embers+1]={x=S.cx+cos(a)*(T.fx+40),y=S.rimY+30,z=S.cz+sin(a)*(T.fz+40),r=30,n=10}
 end
 fx.motes={x=S.cx,z=S.cz,r=90,y0=4,y1=80,n=40,col={1,.86,.6}}
 if T.summit then
  -- TEST196: on the summit, prayer flags from the mat's far posts out to
  -- the stands
  local Pf=C.part('flags')
  local cols={'inRugBlue','lgSnow','lgCrimson','inRugGreen','inRugGold'}
  for _,c in ipairs({{-60,-60,S.north-12},{60,-60,S.north+12},{-60,-60,S.north-30},{60,-60,S.north+30}})do
   local a={S.cx+c[1],16,S.cz+c[2]}
   local b=S.P(S.th(c[3]),S.rimD+.5,S.rimY+30)
   local dx,dy,dz=b[1]-a[1],b[2]-a[2],b[3]-a[3]
   local len=sqrt(dx*dx+dz*dz)
   local m=floor(len/7)
   local hx,hz=dx/len,dz/len
   local function at(u)return{a[1]+dx*u,a[2]+dy*u-22*4*u*(1-u),a[3]+dz*u}end
   for k=0,m-1 do
    local p0,p1=at(k/m),at((k+1)/m)
    Pf.quad(p0,p1,{p1[1],p1[2]+.3,p1[3]},{p0[1],p0[2]+.3,p0[3]},'lgWood',.7)
    if k>0 then
     local q=at((k+.15)/m);local w=3.0
     local mat=cols[k%5+1]
     Pf.quad(q,{q[1]+hx*w,q[2],q[3]+hz*w},{q[1]+hx*w,q[2]-4.2,q[3]+hz*w},{q[1],q[2]-4.2,q[3]},mat,.95)
    end
   end
  end
 end
end

THEME_DRESS.agatha=function(C,S,T)
 local K,lib=kit(C)
 local fx=C.fx
 local D=C.part('emblem')
 D.decor(function()
  lib.ringH(D,S.cx,S.cz,.08,40,42.5,64,'lgAmethyst',1.0,nil,nil)
  lib.ringH(D,S.cx,S.cz,.08,30,31.2,64,'lgSilver',1.0)
  -- a crescent moon of silver, cut by a violet disc
  lib.fanH(D,S.cx,S.cz,.09,22,40,'lgSilver',1.02)
  lib.fanH(D,S.cx+8,S.cz-5,.10,19,40,'lgSlate',.9)
  for k=0,11 do
   local a=k/12*TAU
   lib.fanH(D,S.cx+cos(a)*36,S.cz+sin(a)*36,.11,1.6,6,'lgAmethyst',1.1)
  end
 end)
 -- candles along the barrier, iron spikes between
 local B=C.part('spikes')
 for i=0,T.seg-1 do
  local th=S.th(i+.5)
  local p=S.P(th,1.2,T.barrier.h)
  if i%2==0 then
   fx.candles[#fx.candles+1]={x=p[1],y=p[2]+.1,z=p[3],s=.75,phase=i*1.7,col=i%6==0 and'violet'or nil}
   B.box(p[1]-.5,p[2],p[3]-.5,p[1]+.5,p[2]+1.6,p[3]+.5,'lgSnow',.9)
  else
   B.box(p[1]-.3,p[2],p[3]-.3,p[1]+.3,p[2]+4,p[3]+.3,'dnGunmetal',.9)
  end
 end
 -- the gothic arcade round the back of the stands: piers, pointed arches,
 -- violet glass glowing in them
 local tier=T.tiers[1]
 for i=0,T.seg-1,3 do
  local E=C.part('arcade:'..floor(i/24))
  local th0,th1=S.th(i),S.th(i+3)
  local p0=S.P(th0,S.rimD-.1,0)
  local dx,dz=S.cx-p0[1],S.cz-p0[3]
  local yaw=math.atan2(dx,dz)
  local q=S.P(th1,S.rimD-.1,0)
  local w=sqrt((q[1]-p0[1])^2+(q[3]-p0[3])^2)
  local base=tier.top-tier.back
  local L=K.model(E,(p0[1]+q[1])/2,base,(p0[3]+q[3])/2,yaw,1)
  local hw=w/2
  L.box(-hw,0,-.2,-hw+3,tier.back+8,.8,'lgSlate',.9)
  -- the lancet: glass, then the pointed head of the arch
  L.quad({-hw+5,6,.3},{hw-2,6,.3},{hw-2,22,.3},{-hw+5,22,.3},'lgAmethyst',1.0)
  L.quad({-hw+5,22,.3},{hw-2,22,.3},{(hw+3)/2-hw/2,30,.3},{(hw+3)/2-hw/2,30,.3},'lgAmethyst',1.0)
  L.box(-hw+3,22,-.1,hw,23,.6,'lgSilver',.9)
  if i%6==0 then
   local c=S.P(S.th(i+1.5),S.rimD-2,base+16)
   flareTag(C,push(fx.glows,{x=c[1],y=c[2],z=c[3],r=20,col='violet',a=.22}),'a',1.6)
  end
 end
 -- obelisks on the rim
 local O=C.part('obelisks')
 for i=0,T.seg-1,6 do
  local p=S.P(S.th(i),S.rimD+1.5,S.rimY)
  O.box(p[1]-2.5,p[2],p[3]-2.5,p[1]+2.5,p[2]+3,p[3]+2.5,'lgSlate',.9)
  lib.crystal(O,p[1],p[2]+3,p[3],2.0,20,4,0,0,'lgSlate',pi/4)
 end
 -- the mausoleum gate behind Agatha, a rose window over it
 local g=S.northTunnel
 if g then
  local G=C.part('gate')
  local mid=S.P(S.th(S.north),S.gap-2,0)
  local L=K.model(G,mid[1],0,mid[3],0,1)
  for _,x in ipairs({-24,24})do L.box(x-3,0,-3,x+3,g.yt+20,3,'lgSlate',.9)
   lib.crystal(L,x,g.yt+20,0,3,12,4,0,0,'lgSlate',pi/4)end
  L.box(-27,g.yt+2,-3,27,g.yt+6,3,'lgSlate',.95)
  lib.fan(L,0,g.yt+20,3.2,13,24,'lgAmethyst',1)
  lib.ringXY(L,0,g.yt+20,3.4,12,14,24,'lgSilver',1)
  for k=0,7 do local a=k/8*TAU;L.box(cos(a)*6-.4,g.yt+20+sin(a)*6-.4,3.3,cos(a)*6+.4,g.yt+20+sin(a)*6+.4,3.6,'lgSilver',1)end
  flareTag(C,push(fx.glows,{x=mid[1],y=g.yt+20,z=mid[3]+6,r=36,col='violet',a=.40}),'a',1.0)
  fx.beams[#fx.beams+1]={x=mid[1],y=g.yt+20,z=mid[3]+4,tx=S.cx,ty=0,tz=S.cz-10,r0=8,r1=30,col={.66,.36,1},a=.05}
 end
 screen(C,S,S.th(S.north),S.rimD+6,S.rimY+12,84,30,{{t=T.title,s=4},{t='ELITE FOUR',s=2}},'lgSlate','lgPlum','lgAmethyst',S.rimY)
 -- the moon, low and huge over the north-east
 local Mo=C.part('moon')
 local mx,mz=S.cx+520,S.cz-760
 local L=K.model(Mo,mx,300,mz,math.atan2(S.cx-mx,S.cz-mz),1)
 lib.fan(L,0,0,0,70,40,'inPanel',1)
 fx.glows[#fx.glows+1]={x=mx,y=300,z=mz,r=170,col='white',a=.18}
 -- (over the well its mist is down in the well: see well())
 if not T.well then
  for k=0,9 do
   fx.mist[#fx.mist+1]={x=S.cx+(rh(k,1,1)-.5)*T.fx*1.5,y=1.2,z=S.cz+(rh(k,2,2)-.5)*T.fz*1.5,r=34+rh(k,3,3)*16,phase=k*1.3,col={.55,.42,.75},a=.11,drift=10}
  end
 end
 for k=0,13 do
  local a=rh(k,4,4)*TAU;local r=40+rh(k,5,5)*(T.fx+60)
  fx.wisps[#fx.wisps+1]={x=S.cx+cos(a)*r,y=16+rh(k,6,6)*30,z=S.cz+sin(a)*r,s=1+rh(k,7,7)*.6,phase=k*2.2,code=k%3==0 and 6 or 2,range=26}
 end
end

THEME_DRESS.lance=function(C,S,T)
 local K,lib=kit(C)
 local fx=C.fx
 local F=V.require('LeagueFlora')
 local E4=V.require('LeagueRoomsE4')
 -- a crimson road down the axis and a gold dragon's eye at the heart
 -- (TEST231: drawn as an eye. Its slit was one quad of the platform's own
 -- obsidian, slab joints and all, so in Joseph's recording it read as a
 -- hole cut through the carpet in every shot of the fight. Now a golden
 -- iris -- gold fibres radiating over the crimson, a dark ring at its rim,
 -- molten fire hugging the pupil -- and a gold-rimmed, blood-black slit
 -- with a glint of light on it. Each layer its own height, .10 to .16.)
 local D=C.part('emblem')
 D.decor(function()
  local cx,cz=S.cx,S.cz
  local reach=(S.platformR or 78)*cos(pi/8)
  lib.stripH(D,cx,cz-reach,cx,cz+reach,.07,18,'lgCrimson',.95)
  lib.stripH(D,cx-9.4,cz-reach,cx-9.4,cz+reach,.08,1.2,'lgGold',1.0)
  lib.stripH(D,cx+9.4,cz-reach,cx+9.4,cz+reach,.08,1.2,'lgGold',1.0)
  lib.ringH(D,cx,cz,.09,30,36,64,'lgGold',1.02)
  lib.fanH(D,cx,cz,.10,30,48,'lgCrimson',.95)
  -- the iris: gold fibres, long and short by turns, fanning out from the
  -- fire round the pupil (each a thin wedge, wider at its outer end)
  local NF=36
  for k=0,NF-1 do
   local a=(k+.5)/NF*TAU+.035*sin(k*2.3)
   local r0=10.4+rh(k,31,3)*1.4
   local r1=(k%2==0 and 27.2 or 22.6)+rh(k,32,5)*1.6
   local w0,w1=.018,.032+.008*(k%3)
   D.quad({cx+cos(a-w0)*r0,.11,cz+sin(a-w0)*r0},{cx+cos(a-w1)*r1,.11,cz+sin(a-w1)*r1},
    {cx+cos(a+w1)*r1,.11,cz+sin(a+w1)*r1},{cx+cos(a+w0)*r0,.11,cz+sin(a+w0)*r0},'lgGold',k%2==0 and .98 or .84)
  end
  -- the iris's dark rim, inside the gold ring
  lib.ringH(D,cx,cz,.12,27.4,30,64,'lgCrimson',.42)
  -- a lens along the axis (the slit's shape): half-width hw, half-length hl
  local function lens(y,x0,z0,hw,hl,mat,shade)
   local n=18
   for i=0,n-1 do
    local t0,t1=i/n,(i+1)/n
    local w0,w1=hw*sin(pi*t0)^.72,hw*sin(pi*t1)^.72
    local za,zb=z0-hl+2*hl*t0,z0-hl+2*hl*t1
    D.quad({x0-w0,y,za},{x0+w0,y,za},{x0+w1,y,zb},{x0-w1,y,zb},mat,shade)
   end
  end
  lens(.13,cx,cz,13.4,27.8,'lgLava',1.8)        -- molten fire round the pupil
  lens(.14,cx,cz,7.9,25.4,'lgGold',1.0)         -- the gold rim
  lens(.15,cx,cz,6.6,24.0,'lgCrimson',.13)      -- the slit: blood-black
  lens(.16,cx+2.2,cz-10.6,1.3,3.2,'lgMarble',1.25)  -- a glint of light on it
  lens(.16,cx-1.5,cz+8.4,.7,1.4,'lgMarble',1.15)
  for k=0,7 do
   local a=k/8*TAU+pi/8
   local p1={S.cx+cos(a)*40,.09,S.cz+sin(a)*40};local p2={S.cx+cos(a)*58,.09,S.cz+sin(a)*58}
   local n={-sin(a)*3,0,cos(a)*3}
   D.quad({p1[1]-n[1],.09,p1[3]-n[3]},{p1[1]+n[1],.09,p1[3]+n[3]},p2,p2,'lgGold',1.0)
  end
 end)
 -- fire columns on the rim
 local R=C.part('columns')
 for i=0,T.seg-1,6 do
  local p=S.P(S.th(i),S.rimD+1,S.rimY)
  R.box(p[1]-3,p[2],p[3]-3,p[1]+3,p[2]+40,p[3]+3,'lgObsidian',.85)
  R.box(p[1]-4,p[2]+40,p[3]-4,p[1]+4,p[2]+42,p[3]+4,'lgGold',1)
  flareTag(C,push(fx.fires,{x=p[1],y=p[2]+42.4,z=p[3],s=1.6,phase=i*1.37}),'s',1.4)
  flareTag(C,push(fx.glows,{x=p[1],y=p[2]+44,z=p[3],r=22,col='red',a=.25}),'a',1.2)
 end
 -- two great bronze dragons rearing at the gate behind Lance
 local g=S.northTunnel
 if g then
  local G=C.part('gate')
  local mid=S.P(S.th(S.north),S.gap-4,0)
  for _,sx in ipairs({-1,1})do
   local x=mid[1]+sx*40
   G.box(x-9,0,mid[3]-9,x+9,10,mid[3]+9,'lgObsidian',.9)
   G.box(x-9.5,10,mid[3]-9.5,x+9.5,11,mid[3]+9.5,'lgGold',1)
   pcall(E4.dragon,G,K,F,lib,x,11,mid[3],sx<0 and .5 or -.5,1.7,sx*11,fx)
  end
  fx.portal={x=mid[1],y=g.yt*.5,z=mid[3]-4,w=36,h=g.yt,col='red'}
  fx.glows[#fx.glows+1]={x=mid[1],y=20,z=mid[3],r=40,col='red',a=.30}
 end
 screen(C,S,S.th(S.north),S.rimD+6,S.rimY+50,92,32,{{t=T.title,s=4},{t='ELITE FOUR',s=2}},'lgObsidian','inLacquer','lgGold',S.rimY)
 -- the caldera's walls beyond the stands
 local Cw=C.part('caldera')
 for k=0,23 do
  local a0,a1=k/24*TAU,(k+1)/24*TAU
  local r0,r1=560,760
  local h0=140+rh(k,1,1)*90;local h1=140+rh(k+1,1,1)*90
  if k==23 then h1=140+rh(0,1,1)*90 end
  Cw.quad({S.cx+cos(a0)*r0,-60,S.cz+sin(a0)*r0},{S.cx+cos(a1)*r0,-60,S.cz+sin(a1)*r0},{S.cx+cos(a1)*r1,h1,S.cz+sin(a1)*r1},{S.cx+cos(a0)*r1,h0,S.cz+sin(a0)*r1},'lgRock',.55)
 end
 fx.lightning={x=S.cx,z=S.cz,r=700,y=420}
end

THEME_DRESS.champion=function(C,S,T)
 local K,lib=kit(C)
 local fx=C.fx
 -- the floor of the Champion's room, grown to a stadium: the compass star
 -- and the Poke Ball at its heart
 local D=C.part('emblem')
 D.decor(function()
  lib.ringH(D,S.cx,S.cz,.07,56,64,80,'lgCrimson',.95)
  lib.ringH(D,S.cx,S.cz,.075,64,66,80,'lgGold',1.02)
  lib.starH(D,S.cx,S.cz,.08,54,16,8,'lgGold','lgCrimson',1.0)
  lib.starH(D,S.cx,S.cz,.085,34,12,8,'lgCrimson','lgGold',1.0,-pi/2+pi/8)
  lib.fanH(D,S.cx,S.cz,.09,18,40,'lgMarble',1.05,pi,TAU)
  lib.fanH(D,S.cx,S.cz,.09,18,40,'lgCrimson',1.0,0,pi)
  lib.stripH(D,S.cx-18,S.cz,S.cx+18,S.cz,.10,2.4,'lgObsidian',1)
  lib.ringH(D,S.cx,S.cz,.11,5,7,24,'lgObsidian',1)
  lib.fanH(D,S.cx,S.cz,.105,5,24,'lgMarble',1.08)
  lib.ringH(D,S.cx,S.cz,.10,18,19.6,48,'lgObsidian',1)
  -- a broad crimson ring half way out, gold-edged, gold diamonds on it
  lib.ringH(D,S.cx,S.cz,.07,118,128,96,'lgCrimson',.95)
  lib.ringH(D,S.cx,S.cz,.075,116.5,118,96,'lgGold',1.02)
  lib.ringH(D,S.cx,S.cz,.075,128,129.5,96,'lgGold',1.02)
  for k=0,23 do
   local a=k/24*TAU
   local x,z=S.cx+cos(a)*123,S.cz+sin(a)*123
   D.quad({x+cos(a)*3.4,.08,z+sin(a)*3.4},{x-sin(a)*2,.08,z+cos(a)*2},{x-cos(a)*3.4,.08,z-sin(a)*3.4},{x+sin(a)*2,.08,z-cos(a)*2},'lgGold',1.05)
  end
 end)
 -- LED boards round the field wall
 local Bd=C.part('boards')
 for i=0,T.seg-1 do
  local a,b=S.th(i),S.th(i+1)
  local code=({1,2,8,2})[floor(i/4)%4+1]
  neon(C,function()Bd.quad(S.P(a,-.25,1.4),S.P(b,-.25,1.4),S.P(b,-.25,6.4),S.P(a,-.25,6.4),'dnNeon',code)end)
 end
 -- the roof over the upper tier, floodlight banks along its edge
 local top=T.tiers[#T.tiers]
 local yR=top.top+18
 S.roofY=yR+6
 for i=0,T.seg-1,16 do
  local E=C.part('roof:'..i)
  local i1=min(T.seg,i+16)
  band(E,S,i,i1,top.dEnd+3,yR,top.dEnd-84,yR,'dnGunmetal',.75)
  band(E,S,i,i1,top.dEnd-84,yR,top.dEnd-84,yR+4,'lgMarble',.9)
  band(E,S,i,i1,top.dEnd-84,yR+4,top.dEnd+3,yR+6,'dnGunmetal',.6)
  neon(C,function()band(E,S,i,i1,top.dEnd-84.3,yR+.6,top.dEnd-84.3,yR+3.2,'dnNeon',4)end)
  band(E,S,i,i1,top.dEnd,top.top,top.dEnd,yR,'lgMarble',.75)
 end
 for i=0,T.seg-1,8 do
  local p=S.P(S.th(i),top.dEnd-1,0)
  local C2=C.part('roofposts')
  C2.box(p[1]-2,top.top,p[3]-2,p[1]+2,yR,p[3]+2,'lgGold',.9)
 end
 for i=4,T.seg-1,16 do floods(C,S,S.th(i),top.dEnd-82,yR-10,fx,'white')end
 -- crimson banners with the League's gold star hanging from the roof
 local Bn=C.part('banners')
 for i=2,T.seg-1,8 do
  local p=S.P(S.th(i),top.dEnd-80,0)
  local L=K.model(Bn,p[1],yR,p[3],math.atan2(S.cx-p[1],S.cz-p[3]),1)
  L.box(-5,-30,-.3,5,0,.3,'lgCrimson',.95)
  L.box(-5.5,-1.5,-.5,5.5,0,.5,'lgGold',1)
  lib.starXY(L,0,-12,.4,3.6,1.5,5,'lgGold',1)
  L.quad({-5,-30,.32},{5,-30,.32},{0,-35,.32},{0,-35,.32},'lgCrimson',.9)
 end
 -- the Champion's portal behind the opponent
 local g=S.northTunnel
 if g then
  local G=C.part('gate')
  local mid=S.P(S.th(S.north),S.gap-3,0)
  local L=K.model(G,mid[1],0,mid[3],0,1)
  for _,x in ipairs({-34,-24,24,34})do
   L.box(x-3,0,-3,x+3,g.yt+20,3,'lgMarble',.92)
   L.box(x-3.6,g.yt+20,-3.6,x+3.6,g.yt+22,3.6,'lgGold',1)
  end
  L.box(-38,g.yt+22,-4,38,g.yt+28,4,'lgMarble',.95)
  L.box(-38.5,g.yt+28,-4.5,38.5,g.yt+29.5,4.5,'lgGold',1)
  lib.starXY(L,0,g.yt+40,4.6,9,3.8,5,'lgGold',1.05)
  lib.ringXY(L,0,g.yt+40,4.4,11,13,32,'lgCrimson',1)
  fx.glows[#fx.glows+1]={x=mid[1],y=g.yt+40,z=mid[3]+6,r=30,col='gold',a=.35}
  -- two great fire cauldrons either side of the portal
  for _,sx in ipairs({-1,1})do
   local x=mid[1]+sx*50
   G.box(x-5,0,mid[3]+2,x+5,12,mid[3]+12,'lgMarble',.9)
   lib.ringH(G,x,mid[3]+7,12.2,4.4,6,16,'lgGold',1)
   flareTag(C,push(fx.fires,{x=x,y=12.4,z=mid[3]+7,s=2.2,phase=sx*2}),'s',.6)
   fx.glows[#fx.glows+1]={x=x,y=18,z=mid[3]+7,r=30,col='warm',a=.30}
  end
 end
 -- the giant screens at each end: the Champion's name, and the challenger's
 local rival,player='CHAMPION','CHALLENGER'
 pcall(function()
  local Game=require('src.core.Game')
  local p=Game.save and Game.save.player
  local function clean(s)s=tostring(s or''):upper():gsub('[^A-Z0-9 ]','');return s~=''and s:sub(1,10)or nil end
  rival=clean(p and p.rival)or rival;player=clean(p and p.name)or player
 end)
 screen(C,S,S.th(S.north),top.dEnd-70,yR-74,150,56,{{t=rival,s=7},{t='POKEMON LEAGUE CHAMPION',s=2.2}},'dnGunmetal','inScreen','inPanel',nil,yR)
 screen(C,S,S.th(S.south),top.dEnd-70,yR-74,150,56,{{t=player,s=7},{t='THE CHALLENGER',s=2.4}},'dnGunmetal','inScreen','inPanel',nil,yR)
 -- the League's name in gold on the face of the lower tier's back wall
 local low=T.tiers[1]
 for _,a in ipairs({S.north-14,S.north+14,S.south-14,S.south+14})do
  local th=S.th(a)
  local p=S.P(th,low.dEnd-.6,0)
  local L=K.model(C.part('letters'),p[1],low.top-low.back*.30,p[3],math.atan2(S.cx-p[1],S.cz-p[3]),1)
  K.inscription(L,'POKEMON LEAGUE',0,0,0,1.15,'lgGold',70)
 end
 -- searchlights sweeping the sky and the field, confetti, gold motes
 for k=0,7 do
  local a=k/8*TAU+pi/8
  local p=S.P(a,S.rimD-40,yR+8)
  fx.spots[#fx.spots+1]={x=p[1],y=p[2],z=p[3],tx=S.cx,tz=S.cz,r=8,phase=k*1.6,col={1,.94,.80},a=.06,sweep=120}
 end
 -- TEST196: pyro round the field: pilot flames that go up with the crowd's
 -- big moments (the opening, a knockout, the win, the air horns)
 if T.pyro then
  local Py=C.part('pyro')
  for k=0,T.pyro-1 do
   local a=(k+.5)/T.pyro*TAU
   -- (not in front of the two gates)
   if abs(sin(a))<.92 then
    local p=S.P(a,-15,0)
    Py.box(p[1]-3,0,p[3]-3,p[1]+3,3.2,p[3]+3,'dnGunmetal',.85)
    Py.box(p[1]-3.4,3.2,p[3]-3.4,p[1]+3.4,3.8,p[3]+3.4,'lgGold',1)
    Py.box(p[1]-1.6,3.8,p[3]-1.6,p[1]+1.6,4.6,p[3]+1.6,'lgObsidian',.9)
    flareTag(C,push(fx.fires,{x=p[1],y=4.7,z=p[3],s=.35,phase=k*1.7,batch=true}),'s',8)
    flareTag(C,push(fx.glows,{x=p[1],y=12,z=p[3],r=20,col='warm',a=0}),'a',.40,true)
   end
  end
 end
 fx.confetti={x0=S.cx-T.fx*.7,x1=S.cx+T.fx*.7,z0=S.cz-T.fz*.7,z1=S.cz+T.fz*.7,y0=0,y1=180,n=200}
 fx.motes={x=S.cx,z=S.cz,r=120,y0=2,y1=120,n=50,col={1,.86,.5}}
 fx.pools[#fx.pools+1]={x=S.cx,y=.3,z=S.cz,r=120,a=.06,col={1,.9,.65}}
end

------------------------------------------------------------------ build
-- Every part as quads, the crowd as card lists by section, the effects.
-- Pure apart from LeagueRooms' context: no LOVE needed.
M.SECTIONS=24
function M.geometry(id)
 local themeName=M.ROOMS[id];if not themeName then return nil end
 local T=THEMES[themeName]
 local Rooms=V.require('LeagueRooms')
 local Lt=Rooms.LAYOUT[id]
 local C=Rooms.newContextFor(Lt,id..'@stadium')
 C.H=2000;C.ambient=T.ambient or .85;C.maxLight=T.maxLight or 1.5
 local fx=C.fx
 fx.beams,fx.spots,fx.sparkles,fx.mist,fx.wisps,fx.embers,fx.lava,fx.lavafalls={}, {}, {}, {}, {}, {}, {}, {}
 fx.ambience=T.ambience
 C.flares={}
 local cx,cz=centreFor(id)
 local S=frame(T,cx,cz)
 local lib=Rooms.lib
 C.addLight(cx,160,cz,420,.18)
 barrier(C,S,T)
 -- the stage: Lance's pit of fire, Lorelei's lake, Bruno's summit, Agatha's
 -- well, or the Champion's field
 if T.pit then pit(C,S,T,lib)
 elseif T.lake then lake(C,S,T,lib)
 elseif T.summit then summit(C,S,T,lib)
 elseif T.well then well(C,S,T,lib)
 else field(C,S,T,lib)end
 local places={}
 tiers(C,S,T,places)
 S.northTunnel=tunnel(C,S,T,T.gate,S.north,'north')
 S.southTunnel=tunnel(C,S,T,T.south,S.south,'south')
 THEME_DRESS[themeName](C,S,T)
 -- TEST245: the higher victory shells must stay inside the depth-writing
 -- sky dome. Same tessellation; only its distance changes.
 C.sky(cx,cz,max(T.sky.R,3000),T.sky.style,-80)
 -- the crowd: one card per spectator, facing the field
 local groups={}
 local flashes={}
 local NS=M.SECTIONS
 for _,pl in ipairs(places)do
  local tier=T.tiers[pl.tier]
  local a,b=S.th(pl.i),S.th(pl.i+1)
  local pa,pb=S.P(a,pl.d,pl.y),S.P(b,pl.d,pl.y)
  local len=sqrt((pb[1]-pa[1])^2+(pb[3]-pa[3])^2)
  local n=max(1,floor(len/5.4))
  for k=0,n-1 do
   if M.pace then M.pace()end
   local seed=pl.i*131+pl.row*17+pl.tier*911+k*7
   if rh(seed,1,3)<T.crowd.density then
    local u=(k+.5+(rh(seed,2,5)-.5)*.3)/n
    local th=a+(b-a)*u
    local p=S.P(th,pl.d+(rh(seed,3,7)-.5)*1.2,pl.y)
    local dx,dz=S.cx-p[1],S.cz-p[3]
    local l=sqrt(dx*dx+dz*dz);dx,dz=dx/l,dz/l
    local sc=.92+rh(seed,4,9)*.16
    local hw,h=2.5*sc,7.5*sc
    local rx,rz=-dz*hw,dx*hw
    local v=floor(rh(seed,5,11)*M.VARIANTS)
    local u0,u1=v/M.VARIANTS,(v+1)/M.VARIANTS
    local shade=min(1.15,(.80+rh(seed,6,13)*.16)*(.70+.30*C.light({p[1],p[2]+4,p[3]})/(C.maxLight or 1.5)*1.4))
    local sec=floor(((th%TAU)/TAU)*NS)%NS
    local key=sec*2+(k%2)+1
    local g=groups[key];if not g then g={sec=sec,parity=k%2,cards={}};groups[key]=g end
    local y0=p[2]-.6
    g.cards[#g.cards+1]={
     {p[1]-rx,y0,p[3]-rz,u0,1,shade},{p[1]+rx,y0,p[3]+rz,u1,1,shade},
     {p[1]+rx,y0+h,p[3]+rz,u1,0,shade},{p[1]-rx,y0+h,p[3]-rz,u0,0,shade}}
    if #flashes<240 and rh(seed,7,17)<.06 then flashes[#flashes+1]={p[1]+dx*1.5,y0+h*.8,p[3]+dz*1.5,rh(seed,8,19)}end
   end
  end
 end
 C.crowd={groups=groups,flashes=flashes,theme=themeName}
 C.crowd.flares=C.flares
 C.centre={cx,cz}
 -- TEST244: the bowl's outer edge (an ellipse, radii rx,rz) and the height
 -- of the highest thing on it (the top tier's back, or the Champion's roof):
 -- LeagueVictory sets its shells above and beyond it
 C.rim={cx=S.cx or cx,cz=S.cz or cz,rx=T.fx+(S.rimD or 0),rz=T.fz+(S.rimD or 0),y=max(S.rimY or 0,S.roofY or 0)}
 return C
end

------------------------------------------------------------------ runtime
local cached={}   -- id -> stadium record, or false after a failure
local job=nil     -- the background build {id,co,owner}
local logged={}
local white
local crowdTex={}
local clock=(love and love.timer and love.timer.getTime)or os.clock
local function log(fmt,...)
 if V.mod and V.mod.log and V.mod.log.info then pcall(V.mod.log.info,V.mod.log,fmt,...)end
end
local function whiteTex()
 if not white then
  local d=love.image.newImageData(2,2);for y=0,1 do for x=0,1 do d:setPixel(x,y,1,1,1,1)end end
  white=love.graphics.newImage(d);white:setFilter('nearest','nearest');d:release()
 end
 return white
end
local function crowdTextures(themeName)
 local t=crowdTex[themeName]
 if t then return t[1],t[2]end
 local out={}
 local data
 local ok,err=pcall(function()
 for k,up in ipairs({false,true})do
  local rows,W,H=M.crowdAtlas(themeName,up)
  local d=love.image.newImageData(W,H);data=d
  for y=0,H-1 do local r=rows[y];for x=0,W-1 do local c=r[x];d:setPixel(x,y,c[1],c[2],c[3],c[4])end end
  -- mipmapped (as CaveMood does) so thousands of far-off spectators do
  -- not sparkle as the camera drifts; sharp pixels up close
  local okI,img=pcall(love.graphics.newImage,d,{mipmaps=true})
  if okI and img then
   out[k]=img
   pcall(img.setFilter,img,'linear','nearest');pcall(img.setMipmapFilter,img,'linear')
  else
   img=love.graphics.newImage(d);out[k]=img;img:setFilter('nearest','nearest')
  end
  d:release();data=nil
  out[k]=img
 end
 end)
 if not ok then
  if data then pcall(data.release,data)end
  for _,img in pairs(out)do pcall(img.release,img)end
  error(err,0)
 end
 crowdTex[themeName]=out
 return out[1],out[2]
end
local function release(r)
 if not r then return end
 for _,p in ipairs(r.parts or{})do if p.mesh then pcall(p.mesh.release,p.mesh)end end
 for _,g in ipairs(r.crowd or{})do if g.mesh then pcall(g.mesh.release,g.mesh)end end
 -- (TEST197: the boiling lake's per-frame meshes)
 local L=r.lava
 if L then
  for _,k in ipairs({'dome','spray','rings'})do
   local m=L[k];if m and m.mesh then pcall(m.mesh.release,m.mesh)end;L[k]=nil
  end
 end
end
-- the build's pacer: yields our own coroutine when its slice is spent
local deadline=math.huge
local ticks=0
local PACER={}
function PACER.tick()
 ticks=ticks+1
 if ticks%16==0 and job and coroutine.running()==job.co and clock()>deadline then coroutine.yield()end
end
PACER.check=PACER.tick
M.pace=PACER.tick
local function upload(id,C,owner)
 local R=V.require('Voxel3D')
 local count=0
 for _,p in ipairs(C.parts)do
  if #p.quads>0 then
   local vs,ix={},{}
   for _,q in ipairs(p.quads)do
    local sh=RM.encode(q.referenceMaterial,q.shade)
    local n=#vs
    for i=1,4 do local pt=q[i];vs[n+i]={pt[1],pt[2],pt[3],.5,.5,type(sh)=='table'and sh[i]or sh}end
    local k=#ix
    ix[k+1],ix[k+2],ix[k+3],ix[k+4],ix[k+5],ix[k+6]=n+1,n+2,n+3,n+1,n+3,n+4
    PACER.tick()
   end
   p.quads={}
   local mesh,err=R.newMesh(vs,ix)
   if not mesh then error('stadium upload '..tostring(p.name)..': '..tostring(err),0)end
   owner.parts[#owner.parts+1]={name=p.name,mesh=mesh};count=count+#vs
   PACER.check()
  end
 end
 for _,g in pairs(C.crowd.groups)do
  if #g.cards>0 then
   local vs,ix={},{}
   for ci,cd in ipairs(g.cards)do
    local n=#vs
    for i=1,4 do vs[n+i]=cd[i]end
    R.pushQuad(ix,ci-1)
   end
   local mesh,err=R.newMesh(vs,ix)
   if not mesh then error('stadium crowd upload: '..tostring(err),0)end
   owner.crowd[#owner.crowd+1]={mesh=mesh,sec=g.sec,parity=g.parity,n=#g.cards};count=count+#vs
   PACER.check()
  end
 end
 return{parts=owner.parts,crowd=owner.crowd,fx=C.fx,flashes=C.crowd.flashes,theme=C.crowd.theme,
  flares=C.flares or{},lava=C.lava,centre=C.centre,rim=C.rim,vertices=count,H=C.H,W=C.W,D=C.D}
end
-- LeagueRooms' context paces itself through whatever budget it is given:
-- ours for exactly the length of each resume, the scene's again after
local function resume(co)
 local Rooms=V.require('LeagueRooms')
 pcall(Rooms.useBudget,PACER)
 local ok,res=coroutine.resume(co)
 local okB,B=pcall(V.require,'BuildBudget')
 if okB and B then pcall(Rooms.useBudget,B)end
 return ok,res
end
local function cancel()
 if job then release(job.owner);job=nil end
end
local function fail(id,err)
 cached[id]=false
 if not logged[id]then logged[id]=true;log('League stadium %s failed: %s',tostring(id),tostring(err))end
end
-- one slice of the background build of `id`'s stadium; true while busy
function M.step(id)
 id=tostring(id or'')
 if not M.ROOMS[id]or cached[id]~=nil then return false end
 if not(job and job.id==id)then
  cancel()
  local owner={parts={},crowd={}}
  job={id=id,owner=owner}
  job.co=coroutine.create(function()
   return upload(id,M.geometry(id),owner)
  end)
 end
 deadline=clock()+.004
 local ok,res=resume(job.co)
 deadline=math.huge
 if not ok then local j=job;job=nil;release(j.owner);fail(id,res);return false end
 if coroutine.status(job.co)=='dead'then cached[id]=res;job=nil;return false end
 return true
end
-- the stadium for `id`, finishing (or doing) its build now if need be
local function prepare(id)
 local r=cached[id]
 if r then return r end
 if r==false or not M.ROOMS[id]then return nil end
 if not(job and job.id==id)then M.step(id)end
 while job and job.id==id do
  deadline=math.huge
  local ok,res=resume(job.co)
  if not ok then local j=job;job=nil;release(j.owner);fail(id,res);return nil end
  if coroutine.status(job.co)=='dead'then cached[id]=res;job=nil end
 end
 return cached[id]or nil
end
M.prepare=prepare
function M.ready(id)local r=cached[id];if r==nil then return nil end;return r and true or false end
-- TEST244: a built stadium's rim (see geometry), or nil -- never builds
function M.rim(id)local r=cached[tostring(id)];return r and r.rim or nil end

-- Is a battle being staged in this room right now (the battle's own render
-- pass, not the overworld drawn under its opening transition)?
function M.drawing(map)
 local id=map and tostring(map.id)
 if not(id and M.ROOMS[id])then return false end
 local okS,BS=pcall(V.require,'BattleScene')
 local host=okS and BS and BS.stagedHost
 if not(host and tostring(host.id)==id)then return false end
 local okO,OB=pcall(V.require,'OverworldBattle')
 if not(okO and OB and OB.arena and OB.arena())then return false end
 return prepare(id)~=nil
end

-- TEST200: where the opponent stands while their stadium battle is up. In the
-- League rooms the trainer's own tile IS the opponent's battle spot, so their
-- Pokemon was sent out on top of them. For the battle only, the trainer is
-- drawn a step to the side of their Pokemon and a little behind it, facing
-- the fight. Render-only: the actor, its tile and its scripts are untouched.
M.TRAINER_SIDE=30   -- world units beside their Pokemon (two cells is 32)
M.TRAINER_BACK=6    -- and this far behind it
M.OPPONENT={SPRITE_LORELEI=true,SPRITE_BRUNO=true,SPRITE_AGATHA=true,SPRITE_LANCE=true,SPRITE_BLUE=true}
function M.trainerStand(ctx)
 if type(ctx)~='table' or ctx.isPlayer or not(ctx.px and ctx.py)then return nil end
 local st=ctx.state;local map=st and st.map
 local id=map and tostring(map.id)
 if not(id and M.ROOMS[id])then return nil end
 local okS,BS=pcall(V.require,'BattleScene')
 if not(okS and BS and BS.stadiumStage)then return nil end
 local host=BS.stagedHost
 if not(host and tostring(host.id)==id)then return nil end
 local okO,OB=pcall(V.require,'OverworldBattle')
 local arena=okO and OB and OB.arena and OB.arena()
 if not(arena and arena.enemy and arena.player)then return nil end
 local ex,ez=arena.enemy[1],arena.enemy[2]
 -- the room's own trainer (by sprite, whatever model a mod gives them), or
 -- anyone else standing right on the opponent's spot
 local cx,cz=ctx.px+8,ctx.py+8
 if not M.OPPONENT[tostring(ctx.spriteId)] and (cx-ex)^2+(cz-ez)^2>20*20 then return nil end
 local dx,dz=arena.player[1]-ex,arena.player[2]-ez
 local l=sqrt(dx*dx+dz*dz)
 if l<1e-3 then return nil end
 dx,dz=dx/l,dz/l
 local sx,sz=-dz,dx
 return ex+sx*M.TRAINER_SIDE-dx*M.TRAINER_BACK-8, ez+sz*M.TRAINER_SIDE-dz*M.TRAINER_BACK-8
end

-- the crowd: each section and parity cheers on its own beat, a wave runs
-- round the bowl now and then, and the whole house roars every so often.
-- TEST196: and with the fight (LeagueCrowd): `ex` (0..1) brings the stands
-- to their feet after a big moment, `beat` has the whole house jump on a
-- drum beat or a clap of a chant
local function cheer(t,sec,parity,ex,beat)
 if beat then return true end
 local NS=M.SECTIONS
 local roar=max(0,sin(t*.37)*sin(t*.23+1.3))
 local wave=0
 local cyc=t%30
 if cyc<9 then
  local head=(cyc/9)*NS
  local dist=(sec-head)%NS
  if dist<2.2 then wave=1 end
 end
 local own=.5+.5*sin(t*(1.7+rh(sec,parity,3)*1.4)+rh(sec,parity,5)*TAU)
 return wave>0 or own>(.78-roar*.45-(ex or 0)*.8)
end
M.cheer=cheer
-- the crowd's sound (TEST196); nil if it is not there
local function crowdAudio()
 local ok,Cr=pcall(V.require,'LeagueCrowd')
 return ok and type(Cr)=='table'and Cr or nil
end
-- LeagueRoomFx: the murmur under the music rises and falls with the stands
function M.crowdBed()
 local Cr=crowdAudio()
 return Cr and Cr.bed and Cr.bed()or 1
end
------------------------------------------------------------------ TEST197
-- LANCE'S LAKE OF FIRE, BOILING. Bubbles swell up out of the lava (their
-- foot the lake's own crust, their crown molten, white-gold, glowing), tear
-- open and throw up droplets, a flash and a ring spreading on the lake; now
-- and then the lake spurts a column of lava up into the pit that falls back
-- in. All of it rides three meshes rewritten each frame: the bubbles (drawn
-- with the stadium), the droplets, glows and flashes, the rings (both
-- additive). The big bursts and the spurts are heard (LeagueCrowd).
local DOME_NS,DOME_NR=9,3
local DOME={}
for j=0,DOME_NR do local a=j/DOME_NR*pi/2;DOME[j]={cos(a),sin(a)}end
local function lavaMeshes(L,R)
 if L.dome==nil then
  L.dome=false
  local n=#L.bubbles*DOME_NS*DOME_NR
  -- the foot of a bubble is the lake's crust, its shoulder molten amber
  -- and its crown white-hot (self-lit, so they glow whatever the light;
  -- the bands are what make it read as round)
  local band={RM.encode('lgLava',1.08),RM.encode('dnNeon',2),RM.encode('dnNeon',4)}
  local verts={}
  for i=1,n*4 do
   local q=floor((i-1)/4)
   local ring=floor(q/DOME_NS)%DOME_NR
   verts[i]={0,-9999,0,.5,.5,band[min(3,ring+1)]}
  end
  local ok,m=pcall(love.graphics.newMesh,R.FORMAT,verts,'triangles','stream')
  if ok and m then
   local idx={};for q=0,n-1 do R.pushQuad(idx,q)end
   pcall(m.setVertexMap,m,idx)
   L.dome={mesh=m,verts=verts}
  end
 end
 return L.dome or nil
end
local function hideSlots(sm,from)
 local v=sm.verts
 for k=from*8+1,sm.n*8 do local e=v[k];e[1],e[2],e[3]=0,-9999,0 end
end
-- this frame's lake: dome vertices, droplets, flashes, rings; and the
-- bursts and spurts that start now (they are heard)
local function lavaFrame(r,t,R,K,Cr)
 local L=r.lava
 local Y=L.Y
 local dome=lavaMeshes(L,R)
 if L.spray==nil then L.spray=K.newStream(160)or false end
 if L.rings==nil then L.rings=K.newStream(24)or false end
 local sp,rg=L.spray or nil,L.rings or nil
 local ns,nr=0,0
 local eye=R.eye or{0,0,0}
 local now=t
 -- (what is already under way when the lake is first seen, or seen again
 -- after a break, is not heard starting)
 local quiet=not L.seen or t-L.seen>1
 L.seen=t
 for bi,b in ipairs(L.bubbles)do
  local cyc=(t+b.ph)/b.per
  local c=floor(cyc);local u=cyc-c
  -- the blister: a flat swelling, rising into a dome, tearing open at .70
  local rr,hh=0,0
  if u<.70 then
   local g=u/.70
   rr=b.r*g^.5*(1+.05*sin(t*7+b.ph*3))
   hh=rr*(.50+.60*g)
  elseif u<.74 then
   local k=(u-.70)/.04
   rr=b.r*(1+.18*k);hh=b.r*.9*(1-k)
  end
  if dome then
   local v=dome.verts
   local base=(bi-1)*DOME_NS*DOME_NR*4
   local q=0
   for j=0,DOME_NR-1 do
    local r0,y0=DOME[j][1],DOME[j][2]
    local r1,y1=DOME[j+1][1],DOME[j+1][2]
    for i=0,DOME_NS-1 do
     local a0,a1=i/DOME_NS*TAU,(i+1)/DOME_NS*TAU
     local c0,s0,c1,s1=cos(a0),sin(a0),cos(a1),sin(a1)
     local b4=base+q*4
     local e
     if hh>0 then
      local yb=Y-.6
      e=v[b4+1];e[1],e[2],e[3]=b.x+c0*rr*r0,yb+hh*y0,b.z+s0*rr*r0
      e=v[b4+2];e[1],e[2],e[3]=b.x+c1*rr*r0,yb+hh*y0,b.z+s1*rr*r0
      e=v[b4+3];e[1],e[2],e[3]=b.x+c1*rr*r1,yb+hh*y1,b.z+s1*rr*r1
      e=v[b4+4];e[1],e[2],e[3]=b.x+c0*rr*r1,yb+hh*y1,b.z+s0*rr*r1
     else
      for k=1,4 do e=v[b4+k];e[1],e[2],e[3]=0,-9999,0 end
     end
     q=q+1
    end
   end
  end
  -- its glow while it swells
  if sp and hh>0 and ns<sp.n then
   K.streamPut(sp,ns,b.x,Y+hh*.6,b.z,rr*1.25,false);ns=ns+1
  end
  -- the burst: droplets thrown up and falling back, a flash, a ring
  if u>=.70 then
   local tau=(u-.70)*b.per
   if b.last~=c then
    b.last=c
    -- (heard if it is a big one, near enough, and not on top of the last)
    local dx,dz=b.x-eye[1],b.z-eye[3]
    local d=sqrt(dx*dx+dz*dz+(Y-eye[2])^2)
    if not quiet and b.big and d<330 and Cr and Cr.sfx and now-(L.lastGloop or 0)>1.4 then
     local near=max(.4,min(1,220/max(d,1)))
     L.lastGloop=now
     pcall(Cr.sfx,'gloop',.15*near,.80+.30*(12-b.r)/5)
    end
   end
   if sp then
    local nd=b.big and 10 or 6
    for d=0,nd-1 do
     if ns<sp.n then
      local a=d/nd*TAU+c*1.7+bi
      local vy=(14+rh(c,d,bi)*12)*(b.big and 1.35 or 1)
      local hs=2.5+b.r*.7
      local y=Y+vy*tau-35*tau*tau
      if y>Y-.4 then
       local rr2=b.r*.5+hs*tau
       K.streamPut(sp,ns,b.x+cos(a)*rr2,y,b.z+sin(a)*rr2,.8+.08*b.r,false);ns=ns+1
      end
     end
    end
    if tau<.3 and ns<sp.n then
     K.streamPut(sp,ns,b.x,Y+b.r*.5,b.z,b.r*2.8*(1-tau/.3),false);ns=ns+1
    end
   end
   if rg and tau<.7 and nr<rg.n then
    K.streamPut(rg,nr,b.x,Y+.5,b.z,b.r*(1.1+3.2*tau/.7),true);nr=nr+1
   end
  end
 end
 -- the spurts: a column of blobs thrown up, a glow at its foot
 for si,s in ipairs(L.spurts)do
  local cyc=(t+s.ph)/s.per
  local c=floor(cyc);local tau=(cyc-c)*s.per
  if tau<3.0 then
   if s.last~=c then
    s.last=c
    if not quiet and Cr and Cr.sfx then
     local dx,dz=s.x-eye[1],s.z-eye[3]
     local d=sqrt(dx*dx+dz*dz+(Y-eye[2])^2)
     pcall(Cr.sfx,'spurt',.22*max(.4,min(1,260/max(d,1))),.92+.16*rh(c,si,3))
    end
   end
   if sp then
    for k=0,21 do
     local tk=tau-k/22*.85
     if tk>=0 and ns<sp.n then
      local vy=(50+rh(c,k,si)*16)*s.h
      local y=Y+vy*tk-30*tk*tk
      if y>Y-.4 then
       local a=rh(c,k,si+5)*TAU
       local hs=2+rh(c,k,si+9)*4
       K.streamPut(sp,ns,s.x+cos(a)*hs*tk,y,s.z+sin(a)*hs*tk,(1.9+rh(c,k,si+3)*1.2)*(1-.35*min(1,tk/1.8)),false);ns=ns+1
      end
     end
    end
    if tau<1.1 and ns<sp.n then
     K.streamPut(sp,ns,s.x,Y+4,s.z,10*(1-tau/1.1)+3,false);ns=ns+1
    end
   end
   if rg and tau<1.2 and nr<rg.n then
    K.streamPut(rg,nr,s.x,Y+.5,s.z,6+16*tau/1.2,true);nr=nr+1
   end
  end
 end
 if dome then pcall(dome.mesh.setVertices,dome.mesh,dome.verts)end
 if sp then hideSlots(sp,ns);pcall(sp.mesh.setVertices,sp.mesh,sp.verts)end
 if rg then hideSlots(rg,nr);pcall(rg.mesh.setVertices,rg.mesh,rg.verts)end
 L.ns,L.nr=ns,nr
 return dome
end
M.lavaFrame=lavaFrame

local Mat4
function M.draw(map,shadow)
 local r=prepare(tostring(map.id));if not r then return false end
 -- the stands cast nothing the shot can see: the mons' own shadows fall on
 -- the field, which is all the sun pass is fitted to
 if shadow then return true end
 local R=V.require('Voxel3D')
 Mat4=Mat4 or V.require('Mat4')
 local tex=whiteTex()
 local ok,err=pcall(function()
  R.glass(false)
  if R.seams then R.seams(false)end
  for _,p in ipairs(r.parts)do R.draw(p.mesh,tex)end
  -- (the crowd is a sprite sheet, not the atlas: no seams, no glass mask)
  local down,up=crowdTextures(r.theme)
  local t=0;pcall(function()t=love.timer.getTime()end)
  -- TEST196: the crowd hears the fight (LeagueCrowd): its sounds, and how
  -- excited the stands are, and the beats they jump on
  local ex,beat,F=0,false,0
  local Cr=crowdAudio()
  if Cr then
   pcall(Cr.frame,r)
   local ok1,e1=pcall(Cr.excite,t);if ok1 and tonumber(e1)then ex=e1 end
   local ok2,b2=pcall(Cr.onBeat,t);beat=ok2 and b2 and true or false
   local ok3,f3=pcall(Cr.flare,t);if ok3 and tonumber(f3)then F=f3 end
  end
  -- the things that flare with it: fires, glows, crystals, drums, pyro
  for _,f in ipairs(r.flares or{})do
   if f.add then f.e[f.key]=f.base+f.k*F else f.e[f.key]=f.base*(1+f.k*F)end
  end
  -- TEST197: Lance's lake boiling: its blisters are drawn here, with the
  -- stadium; the droplets, flashes and rings with the camera flashes below
  if r.lava then
   local okK,K=pcall(function()return V.require('LeagueRoad').fxKit()end)
   if okK and K and K.newStream and K.streamPut then
    local okL,dome=pcall(lavaFrame,r,t,R,K,Cr)
    if okL and dome then R.draw(dome.mesh,tex)end
   end
  end
  for _,g in ipairs(r.crowd)do
   local on=cheer(t,g.sec,g.parity,ex,beat)
   if on then
    local bob=.5+(.6+ex*.5)*abs(sin(t*8.5+g.sec*1.3+g.parity*1.9))
    R.draw(g.mesh,up,Mat4.translate(0,bob,0))
   else
    R.draw(g.mesh,down)
   end
  end
  if R.seams then R.seams(true)end
  R.glass(true)
 end)
 if R.seams then pcall(R.seams,true)end
 pcall(R.glass,true)
 if not ok then
  release(r);cached[tostring(map.id)]=false
  if not logged[map.id]then logged[map.id]=true;log('League stadium %s draw failed: %s',tostring(map.id),tostring(err))end
  return false
 end
 -- camera flashes popping in the stands
 pcall(function()
  local okK,K=pcall(function()return V.require('LeagueRoad').fxKit()end)
  if not(okK and K and K.soft and K.cross)then return end
  local t=love.timer.getTime()
  local g=love.graphics
  R.withEffect("add",function()
   -- (TEST197: the boiling lake's droplets, flashes and spreading rings)
   local L=r.lava
   if L then
    if L.spray and(L.ns or 0)>0 then g.setColor(1,.62,.22,.90);R.draw(L.spray.mesh,K.soft,Mat4.translate(0,0,0))end
    if L.rings and(L.nr or 0)>0 then g.setColor(1,.45,.12,.50);R.draw(L.rings.mesh,K.ring or K.soft,Mat4.translate(0,0,0))end
   end
   local F=r.flashes
   local n=#F
   if n==0 then return end
   local slots=r.theme=='champion'and 14 or 7
   for k=0,slots-1 do
    local phase=t*1.9+k*.618
    local cyc=floor(phase)
    local age=phase-cyc
    if age<.10 then
     local f=F[floor(rh(cyc,k,3)*n)+1]
     local a=1-age/.10
     g.setColor(1,1,.96,a*.9)
     R.draw(K.cross,K.soft,Mat4.mul(Mat4.translate(f[1],f[2],f[3]),Mat4.scale(2.6,2.6,2.6)))
    end
   end
  end)
  g.setColor(1,1,1,1)
 end)
 return true
end

-- LeagueRoomFx asks a room provider for its effects
function M.fx(map,eye)
 local r=cached[tostring(map and map.id)]
 if not r then return nil end
 return r.fx,r
end

-- keep only the stadiums of the rooms still live
function M.setLive(live)
 for id,r in pairs(cached)do
  if not(live and live[id])then release(r);cached[id]=nil end
 end
 if job and not(live and live[job.id])then cancel()end
end
function M.invalidate()
 cancel()
 for _,r in pairs(cached)do release(r)end
 cached={}
 for _,t in pairs(crowdTex)do for _,img in ipairs(t)do pcall(img.release,img)end end
 crowdTex={}
 if white then pcall(white.release,white);white=nil end
end
pcall(function()require('src.render.Assets').register(M.invalidate)end)
return M
