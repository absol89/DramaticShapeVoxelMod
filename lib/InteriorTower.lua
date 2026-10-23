-- TEST174: POKEMON TOWER (InteriorRooms), all seven floors.
-- The Legendary tower's look, carried into authored rooms: honed amethyst
-- stone in the TOWER STONE finish you chose (smoke black, storm white,
-- pearl white), a ribbed violet dome over every floor with a glowing
-- oculus, lancet windows of violet glass round the ring, pilasters and a
-- stepped cornice. The graves are headstones of four kinds, each with its
-- own offerings: flowers in vases, incense smouldering, candles, a dish of
-- berries, a toy ball. Ghost wisps drift; the grave mist (TowerGraveMist)
-- still rolls between the stones.
--   1F  the reception: the counter with its guest book, flowers and
--       incense for sale, the floor's great mosaic
--   5F  the purified zone: a ring of light set into the floor
--   7F  the corridor of censers up to the memorial where Mr. Fuji kneels
-- Graves and walls are cells the game already blocks; the floor stays flat.
local V=...
local M={}
local K=V.require('InteriorKit')
local Town=V.require('InteriorTown')
local pi,cos,sin,floor,min,max,abs,sqrt=math.pi,math.cos,math.sin,math.floor,math.min,math.max,math.abs,math.sqrt
local rh=K.rh
local CS=16
local groups,cellsOf=Town.groups,Town.cellsOf

-- actors stand on the floor everywhere
function M.support(id,ch)return 0 end

------------------------------------------------------------------ finishes
-- the TOWER STONE setting picks the stone; the trim is always its foil
local STONES={
 smoke_black={wall='dnTower',band='dnTower',trim='dnTowerPale',floor='dnTower',grave={'dnGranite','dnGraniteDark','lgMarble','ktPearl','dnGranite'}},
 storm_white={wall='dnTowerPale',band='dnTower',trim='dnTower',floor='dnTower',grave={'dnGranite','dnGraniteDark','lgMarble','dnGraniteDark'}},
 pearl_white={wall='dnTowerPearl',band='dnTowerPale',trim='dnTower',floor='dnTowerPale',grave={'dnGraniteDark','dnGranite','lgMarble','ktPearl'}},
}
local function finish()
 local ok,CV=pcall(V.require,'CommunityVisuals')
 local st='smoke_black'
 if ok and CV and CV.towerWallStyle then
  local okS,v=pcall(CV.towerWallStyle)
  if okS and STONES[v]then st=v end
 end
 return STONES[st],st
end

------------------------------------------------------------------ pieces
-- a slab w wide, h tall, t thick standing at local (x,y,z) facing +z, its
-- top 'round', 'gable' or 'flat'
local function slab(L,x,y,z,w,h,t,mat,top)
 local hw=w/2;local hz=t/2
 local hs=top=='round'and h-hw or(top=='gable'and h-hw*.55 or h)
 L.box(x-hw,y,z-hz,x+hw,y+hs,z+hz,mat,1,top=='flat'and{bottom=true}or{bottom=true,top=true})
 if top=='round'then
  local n=8
  for i=0,n-1 do
   local a0,a1=i/n*pi,(i+1)/n*pi
   local p0={x+cos(a0)*hw,y+hs+sin(a0)*hw};local p1={x+cos(a1)*hw,y+hs+sin(a1)*hw}
   L.quad({x,y+hs,z+hz},{p0[1],p0[2],z+hz},{p1[1],p1[2],z+hz},{x,y+hs,z+hz},mat,1)
   L.quad({x,y+hs,z-hz},{p1[1],p1[2],z-hz},{p0[1],p0[2],z-hz},{x,y+hs,z-hz},mat,.9)
   L.quad({p1[1],p1[2],z-hz},{p1[1],p1[2],z+hz},{p0[1],p0[2],z+hz},{p0[1],p0[2],z-hz},mat,1)
  end
 elseif top=='gable'then
  local ty=y+h
  L.quad({x-hw,y+hs,z+hz},{x+hw,y+hs,z+hz},{x,ty,z+hz},{x,ty,z+hz},mat,1)
  L.quad({x+hw,y+hs,z-hz},{x-hw,y+hs,z-hz},{x,ty,z-hz},{x,ty,z-hz},mat,.9)
  L.quad({x-hw,y+hs,z-hz},{x-hw,y+hs,z+hz},{x,ty,z+hz},{x,ty,z-hz},mat,1.05)
  L.quad({x,ty,z-hz},{x,ty,z+hz},{x+hw,y+hs,z+hz},{x+hw,y+hs,z-hz},mat,1.05)
 end
 return hs
end

-- engraved lines on a stone's face (a name and dates, illegibly)
local function engrave(L,x,y,z,w,rows,seed,gold)
 for i=0,rows-1 do
  local l=w*(.45+.5*rh(seed,i,7))
  local yy=y-i*2.1
  L.quad({x-l/2,yy,z+.12},{x+l/2,yy,z+.12},{x+l/2,yy+.8,z+.12},{x-l/2,yy+.8,z+.12},gold and'lgGold'or'dark',gold and 1.1 or .7)
 end
end

-- small offerings set before a stone (local frame on the plinth's front)
local FLOWERS={'flower','white','gold','lgAmethyst','red'}
local FLOWERCOL={'flower','white','gold','red','lgAmethyst'}
local function vase(C,L,x,y,z,seed)
 L.cyl(x,y,y+3.2,z,.9,.7,'lgSilver',6,false)
 L.cyl(x,y+3.2,y+3.8,z,.7,1.0,'lgSilver',6,false)
 for i=0,2 do
  local a=i*2.1+seed;local tx,ty,tz=x+cos(a)*1.3,y+6.2+rh(seed,i,1)*1.6,z+sin(a)*.8
  L.quad({x-.08,y+3.6,z},{x+.08,y+3.6,z},{tx+.08,ty,tz},{tx-.08,ty,tz},'lgLeaf',1)
  local m=FLOWERCOL[(i+floor(seed*3))%#FLOWERCOL+1]
  L.box(tx-.55,ty-.4,tz-.55,tx+.55,ty+.4,tz+.55,m,1.1)
 end
end
local function incense(C,L,x,y,z,seed)
 L.cyl(x,y,y+1.2,z,1.5,1.9,'lgBronze',8,'ktSandstone')
 for i=0,2 do
  local dx=(i-1)*.6
  L.quad({x+dx-.07,y+1.2,z},{x+dx+.07,y+1.2,z},{x+dx*1.6+.07,y+5.6,z+.3},{x+dx*1.6-.07,y+5.6,z+.3},'ktOchre',1)
 end
 local p=L.P({x,y+5.8,z+.2})
 C.fx.smoke[#C.fx.smoke+1]={x=p[1],y=p[2],z=p[3],h=20+rh(seed,1,2)*8,s=.8}
 C.fx.candles[#C.fx.candles+1]={x=p[1],y=p[2]-.2,z=p[3],s=.18,phase=seed*3.1,col='warm'}
end
local function candles(C,L,x,y,z,seed)
 local n=1+floor(rh(seed,2,3)*2.99)
 for i=0,n-1 do
  local cx=x+(i-(n-1)/2)*1.8
  local h=1.8+rh(seed,i,4)*2.2
  L.cyl(cx,y,y+.3,z,.9,.9,'lgBronze',5)
  L.cyl(cx,y+.3,y+h,z,.42,.42,'cream',5)
  local p=L.P({cx,y+h+.35,z})
  C.fx.candles[#C.fx.candles+1]={x=p[1],y=p[2],z=p[3],s=.55,phase=p[1]*.37+p[3]*.11,col=(rh(seed,i,9)<.3)and'violet'or nil}
 end
 local p=L.P({x,y+3,z})
 if rh(seed,5,5)<.5 then C.addLight(p[1],p[2],p[3],26,.10)end
end
local function berries(C,L,x,y,z,seed)
 L.cyl(x,y,y+.4,z,2.0,2.4,'white',8)
 for i=0,4 do
  local a=i*1.26+seed;local bx,bz=x+cos(a)*.9,z+sin(a)*.6
  local m=({'red','flower','gold','red','leaf'})[i+1]
  L.box(bx-.5,y+.4,bz-.5,bx+.5,y+1.3,bz+.5,m,1.1)
 end
end
local function toyBall(C,L,x,y,z,seed)
 L.sphere(x,y+1.3,z,1.3,1.3,1.3,'red',6,4,nil,nil)
 L.box(x-1.35,y+1.15,z-1.35,x+1.35,y+1.45,z+1.35,'dark',.6)
 L.disc(x,y+1.3,z+1.36,.45,'white',6)
end

------------------------------------------------------------------ graves
-- four kinds: a rounded tablet, a tall stacked memorial, a slender obelisk,
-- a wide family stone; each with a plinth, an engraved face, some moss
local function grave(C,F,cx,cy,T,seed)
 local x,z=cx*CS+8,cy*CS+8
 local L=F(x,0,z,0)
 local kind=rh(cx,cy,3)
 local stone=T.grave[1+floor(rh(cx,cy,5)*#T.grave)]
 local plinth=T.band
 -- the plinth (a step of the floor's own stone)
 L.box(-7,0,-6.5,7,1.6,6.5,plinth,1)
 L.box(-6.4,1.6,-6,6.4,2.4,4.6,plinth,1.06)
 local face=0;local topY
 if kind<.38 then
  -- a rounded tablet on a shallow base
  L.box(-5.6,2.4,-3.4,5.6,4,1,stone,1)
  local h=13+rh(cx,cy,1)*4
  slab(L,0,4,-1.2,9.6,h,2.4,stone,'round')
  face=-1.2+1.21;topY=4+h
  L.box(-3.2,4+h*.38,face,3.2,4+h*.38+5.4,face+.08,'ktBasalt',.75)
  engrave(L,0,4+h*.38+4.3,face+.1,5.4,3,seed,true)
 elseif kind<.62 then
  -- the tall stacked memorial: two stepped bases and a pillar, a cap
  L.box(-5.8,2.4,-4.6,5.8,4.2,2.6,stone,1)
  L.box(-4.6,4.2,-3.8,4.6,5.8,1.8,stone,1.04)
  local h=9+rh(cx,cy,1)*4
  L.box(-3.1,5.8,-3,3.1,5.8+h,1,stone,1)
  L.box(-3.6,5.8+h,-3.4,3.6,6.8+h,1.4,stone,1.08)
  face=1.01;topY=6.8+h
  engrave(L,0,5.8+h-2,face+.02,3.6,4,seed,true)
  -- a wooden memorial board leaning behind
  L.quad({-.6,2.4,-5.4},{.6,2.4,-5.4},{.9,19,-6.4},{-.3,19,-6.4},'inWalnut',.85)
 elseif kind<.82 then
  -- a slender obelisk on a die
  L.box(-4.4,2.4,-4,4.4,6.4,2,stone,1)
  local h=11+rh(cx,cy,1)*4
  L.quad({-2.8,6.4,1.2},{2.8,6.4,1.2},{1.6,6.4+h,.4},{-1.6,6.4+h,.4},stone,1)
  L.quad({2.8,6.4,-3.2},{-2.8,6.4,-3.2},{-1.6,6.4+h,-2.4},{1.6,6.4+h,-2.4},stone,.9)
  L.quad({-2.8,6.4,-3.2},{-2.8,6.4,1.2},{-1.6,6.4+h,.4},{-1.6,6.4+h,-2.4},stone,.95)
  L.quad({2.8,6.4,1.2},{2.8,6.4,-3.2},{1.6,6.4+h,-2.4},{1.6,6.4+h,.4},stone,.95)
  L.quad({-1.6,6.4+h,.4},{1.6,6.4+h,.4},{0,8.8+h,-1},{0,8.8+h,-1},stone,1.08)
  L.quad({1.6,6.4+h,-2.4},{-1.6,6.4+h,-2.4},{0,8.8+h,-1},{0,8.8+h,-1},stone,1.0)
  L.quad({-1.6,6.4+h,-2.4},{-1.6,6.4+h,.4},{0,8.8+h,-1},{0,8.8+h,-1},stone,1.0)
  L.quad({1.6,6.4+h,.4},{1.6,6.4+h,-2.4},{0,8.8+h,-1},{0,8.8+h,-1},stone,1.0)
  face=2.02;topY=8.8+h
  L.box(-2.2,2.4+1.4,face,2.2,2.4+3.4,face+.08,'ktBasalt',.75)
  engrave(L,0,5.4,face+.1,3.4,2,seed,true)
 else
  -- a wide family stone, a gable top, two names
  L.box(-6.2,2.4,-3.8,6.2,4,1.4,stone,1)
  local h=10+rh(cx,cy,1)*3
  slab(L,0,4,-1.2,12,h,2.6,stone,'gable')
  face=.11;topY=4+h
  engrave(L,-2.6,4+h*.62,face,3.6,3,seed,true)
  engrave(L,2.6,4+h*.62,face,3.6,3,seed+1,true)
 end
 -- moss and weathering at the foot
 if rh(cx,cy,8)<.45 then
  for i=0,2 do
   local mx=-6+rh(cx,cy,10+i)*12
   local mz=4.6+rh(cx,cy,20+i)*1.4
   L.quad({mx-1.2,1.65,mz},{mx+1.2,1.65,mz},{mx+1.2,1.65,6.2},{mx-1.2,1.65,6.2},'lgLeaf',.8)
  end
 end
 -- the offerings on the plinth's front
 local y=2.4
 local pick=rh(cx,cy,12)
 if pick<.30 then vase(C,L,-4.2,y,3.4,seed);vase(C,L,4.2,y,3.4,seed+.7)
 elseif pick<.52 then incense(C,L,0,y,3.6,seed)
 elseif pick<.72 then candles(C,L,0,y,3.8,seed)
 elseif pick<.86 then berries(C,L,0,y,3.6,seed)
 elseif pick<.94 then toyBall(C,L,0,y,3.8,seed)
 end
 if pick>=.30 and rh(cx,cy,13)<.5 then vase(C,L,-4.6,y,3.2,seed+.3)end
 return topY
end

------------------------------------------------------------------ walls
-- the ring's dressing: pilasters at the turns, lancets of violet glass on
-- the long runs, iron sconces and bronze plaques between
local function ringStyle(C,T)
 local H=C.H
 return function(L,len,run)
  local ox,oz,yaw
  if run.o=='S'then ox,oz,yaw=run.a0,run.c,0
  elseif run.o=='N'then ox,oz,yaw=run.a1,run.c,pi
  elseif run.o=='E'then ox,oz,yaw=run.c,run.a1,pi/2
  else ox,oz,yaw=run.c,run.a0,-pi/2 end
  -- (TEST178: nothing of the dressing stands in the front door)
  local Lf=K.holeSafe(K.frame(C,run.E,ox,0,oz,yaw),run,38)
  local seen=run.o~='N'   -- the north-facing (south) walls face away from the eye
  -- a pilaster at the turn
  local function pilaster(x)
   -- (TEST178: not at the front door's cheeks, where it stood in the way)
   local p=Lf.P({x,0,0})
   for cx=0,C.cw-1 do
    if C.is(cx,C.ch-1,'.')and abs(p[3]-C.ch*CS)<5 and p[1]>cx*CS-5 and p[1]<(cx+1)*CS+5 then return end
   end
   Lf.box(x-2.2,0,0,x+2.2,H,1.6,T.trim,1)
   Lf.box(x-2.8,0,0,x+2.8,3.2,2.2,T.band,1)
   Lf.box(x-2.8,H-6,0,x+2.8,H-4.4,2.4,T.band,1.08)
   Lf.box(x-2.4,H-4.4,0,x+2.4,H-2.4,2.0,T.trim,1.1)
  end
  pilaster(0)
  if len>=48 then pilaster(len)end
  if not seen then return end
  local mid=len/2
  -- (no lancet where a flight's arch stands on this stretch of wall)
  local wp=Lf.P({mid,0,0});local nearStair=false
  for _,ch in ipairs({'^','v'})do for _,sc in ipairs(cellsOf(C,ch))do
   if abs(sc[1]*CS+8-wp[1])<20 and abs(sc[2]*CS+8-wp[3])<20 then nearStair=true end
  end end
  if len>=32 and not nearStair then
   -- a lancet window of violet glass, a pointed head, a stone sill
   local a,b=mid-5.5,mid+5.5;local lo,hi=17,42
   Lf.box(a-2,lo-1.2,0,b+2,lo,2.4,T.trim,1.1)
   Lf.box(a-2,lo,0,a,hi,1.4,T.trim,1)
   Lf.box(b,lo,0,b+2,hi,1.4,T.trim,1)
   Lf.quad({a-2,hi,1.4},{b+2,hi,1.4},{mid,hi+9,1.4},{mid,hi+9,1.4},T.trim,1.05)
   Lf.raw({a,lo,.5},{b,lo,.5},{b,hi,.5},{a,hi,.5},'lgAmethyst',1)
   Lf.raw({a,hi,.5},{b,hi,.5},{mid,hi+7,.5},{mid,hi+7,.5},'lgAmethyst',1)
   Lf.box(mid-.3,lo,.5,mid+.3,hi+6,.9,'ktBasalt',.8)
   Lf.box(a,lo+(hi-lo)*.5-.3,.5,b,lo+(hi-lo)*.5+.3,.9,'ktBasalt',.8)
   local p=Lf.P({mid,(lo+hi)/2,3})
   C.fx.glows[#C.fx.glows+1]={x=p[1],y=p[2],z=p[3],r=14,col='violet',a=.16}
   C.addLight(p[1],p[2],p[3],40,.10)
   -- plaques either side on a long wall
   if len>=64 then
    for _,u in ipairs({mid-22,mid+22})do
     Lf.box(u-4,24,0,u+4,30,.6,'lgBronze',1.05)
     engrave(Lf,u,28.6,.62,5.4,3,u,false)
    end
   end
  elseif len>=16 and rh(run.a0,run.c,1)<.55 then
   -- an iron sconce with a candle
   Lf.box(mid-1,26,0,mid+1,31,.7,'ktBasalt',.9)
   Lf.rod({mid,28,.7},{mid,30.4,3.2},.25,'ktBasalt')
   Lf.cyl(mid,30.4,31,3.2,1.4,1.6,'ktBasalt',8)
   Lf.cyl(mid,31,33.6,3.2,.5,.5,'cream',6)
   local p=Lf.P({mid,34,3.2})
   C.fx.candles[#C.fx.candles+1]={x=p[1],y=p[2],z=p[3],s=.75,phase=p[1]*.3,col=rh(run.a0,run.c,2)<.5 and'violet'or nil}
   C.addLight(p[1],p[2],p[3],36,.14)
  end
 end
end

------------------------------------------------------------------ vault
-- a ribbed dome over the ring, painted violet with gilt stars, sixteen ribs
-- running to a boss round a glowing oculus; seen only from under it
local function vault(C,T,W,D)
 local H=C.H
 local cx,cz=W/2,D/2
 local R=176;local rise=42;local drop=10
 local E=C.part('vault',{below=H+rise-drop})
 local L=K.frame(C,E,0,0,0,0)
 local function Y(r)return H-drop+rise*(1-(r/R)^2)end
 local rings={0,14,32,52,74,98,124,150,176}
 local n=32
 for j=1,#rings-1 do
  local r0,r1=rings[j],rings[j+1]
  for i=0,n-1 do
   local a0,a1=i/n*pi*2,(i+1)/n*pi*2
   local p00={cx+cos(a0)*r0,Y(r0),cz+sin(a0)*r0};local p01={cx+cos(a1)*r0,Y(r0),cz+sin(a1)*r0}
   local p10={cx+cos(a0)*r1,Y(r1),cz+sin(a0)*r1};local p11={cx+cos(a1)*r1,Y(r1),cz+sin(a1)*r1}
   if j>1 then L.quad(p00,p01,p11,p10,'dnVault',.9)end
  end
 end
 -- the ribs (sixteen), a step proud of the vault
 for i=0,15 do
  local a=i/16*pi*2
  for j=2,#rings-1 do
   local r0,r1=rings[j],rings[j+1]
   L.rod({cx+cos(a)*r0,Y(r0)-1.4,cz+sin(a)*r0},{cx+cos(a)*r1,Y(r1)-1.4,cz+sin(a)*r1},1.3,T.trim)
  end
 end
 -- two rings of moulding
 for _,r in ipairs({52,124})do
  for i=0,n-1 do
   local a0,a1=i/n*pi*2,(i+1)/n*pi*2
   L.rod({cx+cos(a0)*r,Y(r)-1.2,cz+sin(a0)*r},{cx+cos(a1)*r,Y(r)-1.2,cz+sin(a1)*r},.9,T.trim)
  end
 end
 -- the boss and the oculus
 L.disc(cx,Y(0)-.5,cz,14,'lgAmethyst',16,'y')
 for i=0,15 do
  local a0,a1=i/16*pi*2,(i+1)/16*pi*2
  L.quad({cx+cos(a0)*14,Y(14)-.4,cz+sin(a0)*14},{cx+cos(a1)*14,Y(14)-.4,cz+sin(a1)*14},
   {cx+cos(a1)*17,Y(17)-2.4,cz+sin(a1)*17},{cx+cos(a0)*17,Y(17)-2.4,cz+sin(a0)*17},'lgGold',1)
 end
 C.fx.glows[#C.fx.glows+1]={x=cx,y=Y(0)-4,z=cz,r=22,col='violet',a=.18,below=H+rise-drop}
end

------------------------------------------------------------------ stairs
-- the flight at the ring's edge: up into an arch, or down into the dark
local function stairs(C,T,R,c,up)
 local cx,cy=c[1],c[2]
 local dir
 if C.is(cx+1,cy,'WV')then dir='E' elseif C.is(cx-1,cy,'WV')then dir='W'
 elseif C.is(cx,cy-1,'WV')then dir='N' else dir='S' end
 local yaw=({E=pi/2,W=-pi/2,N=pi,S=0})[dir]
 -- a frame at the cell's centre, +z toward the wall
 local L=K.frame(C,R,cx*CS+8,0,cy*CS+8,yaw)
 local n=5
 if up then
  for i=0,n-1 do
   local z0=-8+i*16/n;local h=(i+1)*3.2
   L.box(-7,0,z0,7,h,z0+16/n,T.band,1)
   L.box(-7.2,h-.5,z0-.2,7.2,h,z0+16/n,T.trim,1.08)
  end
 else
  -- the opening: the flight sinks into the wall's shadow
  for i=0,n-1 do
   local z0=-8+i*16/n
   L.box(-7,-1.6-i*3,z0,7,-1.6-i*3+.6,z0+16/n,T.trim,.5-i*.07)
  end
  L.quad({-7,0,-8},{7,0,-8},{7,0,8},{-7,0,8},'dark',.12)
  -- a low stone kerb round the opening
  L.box(-8,0,-8.6,8,2.4,-7.6,T.band,1)
 end
 -- the arch on the wall's face over the flight (TEST177: the flight now
 -- climbs TOWARD the wall into this arch; the frame was turned the wrong
 -- way, which stood the arch out in the room with the steps rising at it
 -- from the wall side)
 L.box(-8,0,6.4,-6.4,36,8,T.trim,1)
 L.box(6.4,0,6.4,8,36,8,T.trim,1)
 L.box(-8,36,6.4,8,37.6,8,T.trim,1.05)
 L.quad({-8,37.6,6.4},{8,37.6,6.4},{0,44,6.4},{0,44,6.4},T.trim,1.05)
 L.quad({-6.4,up and 16 or 0,7.9},{6.4,up and 16 or 0,7.9},{6.4,36,7.9},{-6.4,36,7.9},'dark',.25)
 local p=L.P({0,40,5.6})
 C.fx.candles[#C.fx.candles+1]={x=p[1],y=p[2],z=p[3],s=.6,phase=cx,col='violet'}
end

------------------------------------------------------------------ floor art
-- a circle of gilt rings and an eight-pointed star in the floor (flat)
local function medallion(C,x,z,r)
 local E=C.part('floor')
 local L=K.frame(C,E,x,.06,z,0)
 for _,rr in ipairs({r,r*.82,r*.36})do
  local n=40
  for i=0,n-1 do
   local a0,a1=i/n*pi*2,(i+1)/n*pi*2
   L.quad({cos(a0)*rr,0,sin(a0)*rr},{cos(a1)*rr,0,sin(a1)*rr},{cos(a1)*(rr-1.2),0,sin(a1)*(rr-1.2)},{cos(a0)*(rr-1.2),0,sin(a0)*(rr-1.2)},'lgGold',1.05)
  end
 end
 for i=0,7 do
  local a=i/8*pi*2;local b=a+pi/8;local c=a-pi/8
  L.quad({cos(a)*r*.80,.01,sin(a)*r*.80},{cos(b)*r*.36,.01,sin(b)*r*.36},{0,.01,0},{cos(c)*r*.36,.01,sin(c)*r*.36},(i%2==0)and'lgAmethyst'or'dnVault',1)
 end
end

------------------------------------------------------------------ the room
function M.tower(C)
 local T,st=finish()
 local fl=tonumber(C.id:match('_(%d)F$'))or 1
 -- (7F: the corridor is cut through solid masonry; its top is level with
 -- the corridor walls, and the ring has nothing to face)
 local H=fl==7 and 48 or 60;C.H=H
 C.ambient=.56;C.maxLight=1.35
 local W,D=C.cw*CS,C.ch*CS
 local function solid(cx,cy)return C.is(cx,cy,'WV')end
 -- interior walls (7F's corridor) are the ones that never touch the void
 local function inner(cx,cy)
  if not C.is(cx,cy,'W')then return false end
  for dy=-1,1 do for dx=-1,1 do
   local nx,ny=cx+dx,cy+dy
   if nx<0 or ny<0 or nx>=C.cw or ny>=C.ch or C.is(nx,ny,'V')then return false end
  end end
  return true
 end
 local blocked=function(cx,cy)local c=C.at(cx,cy);return c~=nil and c~='.'and c~='Z'and c~='y'and c~='^'and c~='v'end
 local S=K.shell(C,{H=H,solid=solid,inner=fl==7 and inner or nil,innerH=48,blocked=blocked,doorH=38,
  door=function(cx,cy,ox,oy)
   if not ox then return false end
   local off=cx<0 or cy<0 or cx>=C.cw or cy>=C.ch
   return off and oy==C.ch-1 and C.is(ox,oy,'.')
  end,
  paint=T.wall,upper=T.wall,wainscot=T.band,wainscotH=10,rail=T.trim,skirting=T.band,cornice=T.trim,cap=T.band,
  floor=T.floor,ceiling=false,innerPaint=T.wall,
  style=fl~=7 and ringStyle(C,T)or nil,
  innerStyle=function(L,len,run,Hi)
   L.box(0,Hi-3,0,len,Hi,1.8,T.trim,1.08)
   L.box(0,0,0,len,8,1.0,T.band,1)
  end,ao=12})
 if fl==7 then
  -- the masonry round the corridor, capped level
  local E=C.part('caps')
  local function capped(cx,cy)
   for dy=-1,1 do for dx=-1,1 do
    local nx,ny=cx+dx,cy+dy
    if nx>=0 and ny>=0 and nx<C.cw and ny<C.ch and not solid(nx,ny)then return true end
   end end
   return false
  end
  for cy=0,C.ch-1 do for cx=0,C.cw-1 do
   if C.is(cx,cy,'W')and not capped(cx,cy)then
    -- (a hair above the buried ring's own cap and cornice; a skirt down
    -- to the shell's caps where the two meet)
    local y=H+.15
    local x0,x1,z0,z1=cx*CS,(cx+1)*CS,cy*CS,(cy+1)*CS
    E.quad({x0,y,z0},{x1,y,z0},{x1,y,z1},{x0,y,z1},T.band,.92)
    local function meets(nx,ny)return C.is(nx,ny,'W')and capped(nx,ny)end
    if meets(cx,cy-1)then E.quad({x1,H,z0},{x0,H,z0},{x0,y,z0},{x1,y,z0},T.band,.8)end
    if meets(cx,cy+1)then E.quad({x0,H,z1},{x1,H,z1},{x1,y,z1},{x0,y,z1},T.band,.8)end
    if meets(cx-1,cy)then E.quad({x0,H,z0},{x0,H,z1},{x0,y,z1},{x0,y,z0},T.band,.8)end
    if meets(cx+1,cy)then E.quad({x1,H,z1},{x1,H,z0},{x1,y,z0},{x1,y,z1},T.band,.8)end
   end
  end end
 end
 local R=C.part('room')
 local function F(x,y,z,yaw)return K.frame(C,R,x,y,z,yaw)end
 C.fx.smoke=C.fx.smoke or{}
 C.fx.wisps=C.fx.wisps or{}
 -- the graves
 local tops={}
 for _,c in ipairs(cellsOf(C,'G'))do
  tops[#tops+1]=grave(C,F,c[1],c[2],T,c[1]*7.3+c[2]*3.1)
 end
 -- the stairs
 for _,c in ipairs(cellsOf(C,'^'))do stairs(C,T,R,c,true)end
 for _,c in ipairs(cellsOf(C,'v'))do stairs(C,T,R,c,false)end
 -- the front door (1F): a pointed arch on the night
 if fl==1 then
  local x0,x1
  for cx=0,C.cw-1 do if C.is(cx,C.ch-1,'.')then x0=x0 and min(x0,cx)or cx;x1=x1 and max(x1,cx)or cx end end
  if x0 then
   K.frontDoor(C,x0*CS,(x1+1)*CS,{view=12,frame=T.trim,leaf='inWalnut',top=38})
   local E=C.part('decor:S',{axis='z',c=S.s,s=-1})
   local L=K.frame(C,E,0,0,S.s,0)
   L.quad({x0*CS-2,40,-1.6},{(x1+1)*CS+2,40,-1.6},{(x0+x1+1)*CS/2,52,-1.6},{(x0+x1+1)*CS/2,52,-1.6},T.trim,1.05)
  end
  -- the reception counter: dark stone, a gilt rim, the guest book, flowers
  -- and bundles of incense for sale, a donation box, a bell
  local cells=cellsOf(C,'C')
  local L=F(0,0,0,0)
  for _,c in ipairs(cells)do
   local a0,a1,b0,b1=c[1]*CS,(c[1]+1)*CS,c[2]*CS,(c[2]+1)*CS
   local n,s,w,e=C.is(c[1],c[2]-1,'C'),C.is(c[1],c[2]+1,'C'),C.is(c[1]-1,c[2],'C'),C.is(c[1]+1,c[2],'C')
   local ia0,ia1=w and a0 or a0+2,e and a1 or a1-2
   local ib0,ib1=n and b0 or b0+2,s and b1 or b1-2
   L.box(ia0,0,ib0,ia1,14,ib1,T.band,1)
   L.box(ia0-.6,14,ib0-.6,ia1+.6,15.6,ib1+.6,'dnGraniteDark',1.06)
   -- a hairline of aged brass along the top's open edges
   if not n then L.box(ia0-.7,15.6,ib0-.7,ia1+.7,15.9,ib0-.3,'lgBronze',1.12)end
   if not s then L.box(ia0-.7,15.6,ib1+.3,ia1+.7,15.9,ib1+.7,'lgBronze',1.12)end
   if not w then L.box(ia0-.7,15.6,ib0-.7,ia0-.3,15.9,ib1+.7,'lgBronze',1.12)end
   if not e then L.box(ia1+.3,15.6,ib0-.7,ia1+.7,15.9,ib1+.7,'lgBronze',1.12)end
   L.box(ia0+.6,1.5,ib1,ia1-.6,12.5,ib1+.3,T.trim,1.0)
  end
  local top=cells[1]
  if top then
   local y=16
   local Lb=F(top[1]*CS+10,y,top[2]*CS+8,0)
   Lb.box(-4,0,-3,4,.8,3,'inWalnut',1);Lb.box(-3.6,.8,-2.6,0,1.1,2.6,'cream',1.15);Lb.box(0,.8,-2.6,3.6,1.1,2.6,'cream',1.1)
   Lb.rod({1,1.2,0},{3,1.4,1.4},.12,'dark')
   for i=1,3 do
    local Lf=F(top[1]*CS+10+i*14,y,top[2]*CS+8,0)
    if i==1 then
     for k=0,2 do vase(C,Lf,-3+k*3,0,0,i*3+k)end
    elseif i==2 then
     Lf.box(-4,0,-2,4,4,2,'inWalnut',1);Lf.box(-1.4,4,-.2,1.4,4.1,.2,'dark',.6)
    else
     for k=0,4 do Lf.box(-4+k*1.8,0,-1.6,-3+k*1.8,.6,1.6,'lgPlum',1);Lf.rod({-3.5+k*1.8,.6,0},{-3.5+k*1.8,4.6,0},.08,'ktOchre')end
     Lf.cyl(3.4,0,1.6,0,1.2,.6,'lgGold',8);Lf.sphere(3.4,2,0,.5,.5,.5,'lgGold',6,3)
    end
   end
  end
  medallion(C,W/2-16,D/2-8,46)
 end
 -- 5F: the purified zone, a ring of light let into the floor
 if fl==5 then
  for _,g in ipairs(groups(C,'Z'))do
   local x,z=(g.x0+g.x1+1)*CS/2,(g.y0+g.y1+1)*CS/2
   local E=C.part('floor')
   local L=K.frame(C,E,x,.07,z,0)
   for _,rr in ipairs({15,12,6})do
    for i=0,31 do
     local a0,a1=i/32*pi*2,(i+1)/32*pi*2
     L.raw({cos(a0)*rr,0,sin(a0)*rr},{cos(a1)*rr,0,sin(a1)*rr},{cos(a1)*(rr-1.1),0,sin(a1)*(rr-1.1)},{cos(a0)*(rr-1.1),0,sin(a0)*(rr-1.1)},'inPanel',1)
    end
   end
   for i=0,7 do local a=i/8*pi*2
    L.raw({cos(a)*6,0,sin(a)*6},{cos(a+.08)*6,0,sin(a+.08)*6},{cos(a+.04)*12,0,sin(a+.04)*12},{cos(a+.04)*12,0,sin(a+.04)*12},'inPanel',1)
   end
   C.fx.glows[#C.fx.glows+1]={x=x,y=8,z=z,r=26,col='white',a=.22}
   C.fx.glows[#C.fx.glows+1]={x=x,y=30,z=z,r=18,col='gold',a=.10}
   C.fx.motes={x=x,z=z,y0=1,y1=46,r=13,n=40,col={1,.96,.80}}
   C.addLight(x,20,z,90,.55)
  end
 end
 -- 7F: censers flank the way to the memorial; the memorial on the end wall
 if fl==7 then
  for _,c in ipairs(cellsOf(C,'Y'))do
   local x,z=c[1]*CS+8,c[2]*CS+8
   local L=F(x,0,z,0)
   L.cyl(0,0,1.6,0,6.4,6.4,T.band,12)
   L.cyl(0,1.6,9,0,1.8,1.4,'lgBronze',10)
   L.cyl(0,9,10.6,0,3.6,3.2,'lgBronze',12)
   for k=0,2 do local a=k/3*pi*2;L.rod({cos(a)*3,10.6,sin(a)*3},{cos(a)*4.6,6,sin(a)*4.6},.4,'lgBronze')end
   L.cyl(0,10.6,16,0,5.6,6.4,'lgBronze',12,false)
   L.cyl(0,15.6,16.4,0,6.6,6.6,'lgGold',12,false)
   L.cyl(0,10.6,15.4,0,5.2,5.2,'dark',12)
   C.fx.fires[#C.fx.fires+1]={x=x,y=15.6,z=z,s=.8,col='violet'}
   C.fx.smoke[#C.fx.smoke+1]={x=x,y=20,z=z,h=36,s=2.4,speed=.12}
   C.fx.glows[#C.fx.glows+1]={x=x,y=20,z=z,r=20,col='violet',a=.22}
   C.addLight(x,22,z,80,.5)
  end
  -- the memorial on the north wall of the top of the corridor
  local Ln=K.frame(C,C.part('room'),0,0,0,0)
  local top=C.ch
  for cy=0,C.ch-1 do for cx=0,C.cw-1 do if C.is(cx,cy,'.y')and cy<top then top=cy end end end
  local x0,x1=1e9,-1e9
  for cx=0,C.cw-1 do if C.is(cx,top,'.y')then x0=min(x0,cx*CS);x1=max(x1,(cx+1)*CS)end end
  if x0<x1 then
   local z=top*CS
   local mx=(x0+x1)/2
   Ln.box(mx-14,0,z,mx+14,4,z+3,T.band,1)
   Ln.box(mx-10,4,z,mx+10,30,z+2.4,T.trim,1)
   Ln.quad({mx-11,30,z+2.4},{mx+11,30,z+2.4},{mx,38,z+2.4},{mx,38,z+2.4},T.trim,1.05)
   Ln.box(mx-7,8,z+2.4,mx+7,26,z+2.6,'ktObsidian',.9)
   engrave(Ln,mx,23,z+2.65,10,6,7,true)
   Ln.box(mx-14,4,z,mx+14,5,z+5,T.trim,1.08)
   for k=-2,2 do
    local Lc=K.frame(C,C.part('room'),mx+k*5,5,z+3.6,0)
    if k==0 then incense(C,Lc,0,0,0,9)else candles(C,Lc,0,0,0,k+5)end
   end
   C.fx.glows[#C.fx.glows+1]={x=mx,y=20,z=z+6,r=26,col='violet',a=.18}
  end
 end
 -- ghosts that drift over the graves (more of them the higher you climb)
 do
  local gs=cellsOf(C,'G')
  local nW=fl==1 and 1 or(fl>=6 and 5 or 3)
  for i=1,nW do
   local c=gs[1+floor(rh(i,fl,3)*max(1,#gs))]
   if c then C.fx.wisps[#C.fx.wisps+1]={x=c[1]*CS+8,y=24+rh(i,fl,4)*12,z=c[2]*CS+8,phase=i*2.1+fl,range=26,s=.8,code=i%3==0 and 6 or 2}end
  end
 end
 -- the vault (7F's springs from the tower's full height, clear of the
 -- masonry)
 if fl==7 then C.H=60;vault(C,T,W,D);C.H=H else vault(C,T,W,D)end
 -- a low ambient wash so the stone reads, and the floor's own dim light
 C.addLight(W/2,40,D/2,260,.08)
 C.fx.ambience={crypt=.30,hall=.08}
end

return M
