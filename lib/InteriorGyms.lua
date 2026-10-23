-- TEST173: the eight gyms (InteriorRooms), each in its leader's element:
--   PEWTER    a rock canyon under spotlights: boulders and cliffs, torches
--   CERULEAN  a pool hall walled with great aquariums: fish, light on water
--   VERMILION a power station: generators, coils, the electric gate and
--             the trash cans of Lt. Surge's puzzle
--   CELADON   a glass greenhouse: flower beds, clipped shrubs, sunbeams
--   FUCHSIA   a ninja hall of paper screens and violet mist (the walls you
--             cannot see stay unseen)
--   SAFFRON   psychic chambers of black glass, glowing warp pads
--   CINNABAR  a volcanic laboratory: basalt, lava, quiz terminals, the
--             fire gates
--   VIRIDIAN  black glass and gold: the maze's low walls, glowing spinners
-- Scripted doors and the trees you Cut follow the live tiles.
local V=...
local M={}
local K=V.require('InteriorKit')
local Town=V.require('InteriorTown')
local pi,cos,sin,floor,min,max,abs,sqrt=math.pi,math.cos,math.sin,math.floor,math.min,math.max,math.abs,math.sqrt
local rh=K.rh
local CS=16
local groups,cellsOf=Town.groups,Town.cellsOf
local LA=function()return V.require('LeagueArchitecture').kit end

-- where actors stand: on the floor; swimmers float in the engine's water
-- as they always did (TEST177: the pool is the engine's own water again)
function M.support(id,ch)
 if ch=='~'then return nil end
 return 0
end
-- the cells the engine keeps drawing: the Cerulean Gym's pool, so its
-- water (surface, reflections) and the swimmers in it are the engine's own
function M.keep(id,ch)
 return id=='CERULEAN_GYM' and ch=='~'
end

------------------------------------------------------------------ shared
-- the gym statue: a plinth with a plaque and a great gilt-ringed ball
local function statue(C,F,g,o)
 o=o or{}
 local x=g.cx;local z=(g.y1+1)*CS-8
 local L=F(x,0,z,0)
 local st=o.stone or'lgMarble'
 L.box(-7,0,-7,7,2,7,o.base or'lgVerde',1)
 L.box(-6,2,-6,6,16,6,st,1.0)
 L.box(-6.6,15,-6.6,6.6,17,6.6,o.base or'lgVerde',1.05)
 L.box(-3.4,6,6,3.4,11,6.4,'lgGold',1.1)
 for k=0,2 do L.box(-2.6,7+k*1.3,6.4,2.6-k*.8,7.6+k*1.3,6.5,'dark',.7)end
 -- the ball
 local r=5.2
 for i=0,15 do for j=0,7 do
  local a0,a1=i/16*pi*2,(i+1)/16*pi*2
  local b0,b1=-pi/2+j/8*pi,-pi/2+(j+1)/8*pi
  local function P(a,b)return{cos(a)*cos(b)*r,22.4+sin(b)*r,sin(a)*cos(b)*r}end
  L.quad(P(a0,b0),P(a1,b0),P(a1,b1),P(a0,b1),j>=4 and(o.top or'inLacquer')or'inEnamel',1)
 end end
 L.ring(0,22.4,0,r+.05,r+.05,'dark',1)
 for i=0,15 do local a0,a1=i/16*pi*2,(i+1)/16*pi*2
  L.quad({cos(a0)*(r+.15),22,sin(a0)*(r+.15)},{cos(a1)*(r+.15),22,sin(a1)*(r+.15)},{cos(a1)*(r+.15),22.8,sin(a1)*(r+.15)},{cos(a0)*(r+.15),22.8,sin(a0)*(r+.15)},'lgGold',1.15)end
 L.disc(0,22.4,r+.2,1.6,'lgGold',12,nil,1.2);L.disc(0,22.4,r+.3,1,'inEnamel',10,nil,1.1)
end
local function statues(C,F,o)for _,g in ipairs(groups(C,'Y'))do statue(C,F,g,o)end end
-- the gym's front door and its welcome mat
local function entrance(C,o)
 o=o or{}
 local d0,d1=Town.doorSpan(C)
 if d0 then
  K.frontDoor(C,d0,d1,{view=o.view or 1,frame=o.frame or'white',leaf=o.leaf or'inSteel'})
  K.rug(C,C.part('floor'),d0+2,C.ch*CS-14,d1-2,C.ch*CS-1,{field=o.mat or'inRugRed',border='dark',bw=1})
 end
end
-- spotlights in a ceiling rig, sweeping the arena
local function rig(C,H,list,col)
 local E=C.part('ceilfx',{below=H+2})
 local L=K.frame(C,E,0,0,0,0)
 for _,s in ipairs(list)do
  L.cyl(s[1],H-6,H,s[2],1.6,1.6,'dark',8,false)
  L.cyl(s[1],H-9,H-6,s[2],2.4,1.4,'inSteel',10,false)
  L.raw({s[1]-1.6,H-9.05,s[2]-1.6},{s[1]+1.6,H-9.05,s[2]-1.6},{s[1]+1.6,H-9.05,s[2]+1.6},{s[1]-1.6,H-9.05,s[2]+1.6},'inLamp',2)
  C.fx.spots[#C.fx.spots+1]={x=s[1],y=H-9,z=s[2],tx=s[3]or s[1],tz=s[4]or s[2]+30,sweep=s[5]or 18,phase=s[1]*.07+s[2]*.03,col=col or{1,.97,.88},a=.05,r=6}
 end
end
local function fxInit(C)
 C.fx.spots=C.fx.spots or{};C.fx.beams=C.fx.beams or{};C.fx.fish=C.fx.fish or{};C.fx.sparks=C.fx.sparks or{}
end
-- an emblem board on the north wall
local function emblem(C,x,y,r,col,ring)
 local Ln=K.onWall(C,'N',0,0)
 Ln.disc(x,y,.6,r+1.4,ring or'lgGold',24,nil,1.1)
 Ln.disc(x,y,.9,r,col,24,nil,1.05)
 return Ln
end

------------------------------------------------------------------ PEWTER
function M.pewter(C)
 fxInit(C)
 local H=72;C.H=H;C.ambient=.70;C.maxLight=1.5
 local W,D=C.cw*CS,C.ch*CS
 local S=K.shell(C,{H=H,solid=function()return false end,
  blocked=function(cx,cy)return C.is(cx,cy,'RY')end,door=Town.doorFn(C),
  paint='lgRock',upper='lgRock',rail='lgRock',skirting='lgRock',cornice='lgRock',cap='lgRock',
  floor='lgGravel',ceiling='lvSlate',ao=12})
 local R=C.part('room')
 local function F(x,y,z,yaw)return K.frame(C,R,x,y,z,yaw)end
 -- the entrance hall's flagstones over the gravel
 do local E=C.part('floor')
  for cy=10,C.ch-1 do for cx=0,C.cw-1 do
   if not C.is(cx,cy,'RY')then C.floorRect(E,cx*CS,cy*CS,(cx+1)*CS,(cy+1)*CS,.05,'inStone',1,nil,16)end
  end end
 end
 -- the rocks: the ring stands tall as cliffs, the islands lower
 for cy=0,C.ch-1 do for cx=0,C.cw-1 do
  if C.at(cx,cy)=='R'then
   local edge=cx==0 or cx==C.cw-1 or cy==0
   local wall=edge or cy==3 or cy==9
   local x,z=cx*CS+8,cy*CS+8
   local L=F(x,0,z,rh(cx,cy,1)*6)
   local h=(edge and 30 or(wall and 20 or 12))+rh(cx,cy,2)*(edge and 18 or 6)
   local mats={'lgRock','ktSandstone','lgRock'}
   -- a cluster of boulders: a big one, a leaning slab, smaller stones
   L.sphere(0,h*.42,0,8.2,h*.48,8.2,mats[(cx*3+cy)%3+1],9,6,cx*17+cy)
   L.sphere((rh(cx,cy,4)-.5)*7,h*.78,(rh(cx,cy,5)-.5)*5,5.4,h*.28,5.6,mats[(cx+cy*2)%3+1],8,5,cx*7+cy*3)
   L.sphere((rh(cx,cy,10)-.5)*9,2.6,(rh(cx,cy,11)-.5)*9,4.2,3.2,4,mats[(cx+cy)%3+1],7,4,cx*5+cy*11)
   L.sphere((rh(cx,cy,12)-.5)*10,1.4,6,2.6,1.8,2.4,'lvStone',6,3,cx+cy*13)
   if rh(cx,cy,6)>.6 then
    -- a crystal growing out of the rock
    local p={(rh(cx,cy,7)-.5)*8,h*.6,(rh(cx,cy,8)-.5)*8}
    V.require('LeagueRooms').lib.crystal(L,p[1],p[2],p[3],1.1,5+rh(cx,cy,9)*3,6,.2,.1,'lgCrystal')
    local w=L.P({p[1],p[2]+3,p[3]})
    C.fx.sparkles=C.fx.sparkles or{}
    C.fx.sparkles[#C.fx.sparkles+1]={x=w[1],y=w[2],z=w[3],s=.7,phase=cx*3+cy}
   end
   -- torches on the tall rocks of the walls
   if wall and (cx+cy)%3==0 and cy<9 then
    local tL=F(x,h-2,z,0)
    tL.cyl(0,0,1,0,1.6,2.2,'lgBronze',8,false);tL.cyl(0,-3,0,0,.5,.5,'lgBronze',6,false)
    C.fx.fires[#C.fx.fires+1]={x=x,y=h-.5,z=z,s=.7,phase=cx+cy}
    C.addLight(x,h+4,z,70,.32)
   end
  end
 end end
 -- a fossil set in the north cliff, behind Brock
 do
  local Ln=K.onWall(C,'N',0,0)
  Ln.box(W/2-22,30,0,W/2+22,62,1.2,'ktSandstone',.95)
  for i=0,8 do local x=W/2-16+i*4;local y=46+sin(i*.7)*4
   Ln.sphere(x,y,1.6,1.8,1.2,.8,'cream',6,3)
   Ln.rod({x,y-1,1.4},{x+(i-4)*.4,y-7,1.4},.4,'cream');Ln.rod({x,y+1,1.4},{x+(i-4)*.2,y+6,1.4},.35,'cream')end
  Ln.sphere(W/2+20,50,1.8,4.4,3,1.2,'cream',8,4)
  Ln.disc(W/2+21.6,51,2.8,.9,'dark',6)
 end
 statues(C,F,{stone='lgGranite',base='lvSlate',top='ktSandstone'})
 entrance(C,{view=4,frame='lvSlate',leaf='inWalnut',mat='inRugRed'})
 rig(C,H,{{W*.3,40,W*.3,30},{W*.7,40,W*.7,30},{W*.5,100,W*.5,80}})
 C.addLight(W/2,40,40,120,.18)
 C.fx.ambience={hall=.15,fire=.3}
end

------------------------------------------------------------------ CERULEAN
function M.cerulean(C)
 fxInit(C)
 local H=64;C.H=H;C.ambient=.78;C.maxLight=1.5
 local W,D=C.cw*CS,C.ch*CS
 local solid=Town.topWall(C)
 local water=function(cx,cy)return C.at(cx,cy)=='~'end
 local S=K.shell(C,{H=H,solid=solid,blocked=function(cx,cy)return C.is(cx,cy,'FY')end,door=Town.doorFn(C),
  paint='white',upper='ktPearl',rail='inSteel',skirting='ktMarine',cornice='inCeiling',cap='inCeiling',floor='inTile',ceiling=false,
  nofloor=water,
  face=function(L,len,run,ya,yb,mat)
   if run.o=='N'then return false end
   -- A real 36-unit-deep tank replaces the wall between sill and head.
   -- Keeping the old opaque wall here would hide the swimming models.
   if ya<7 then L.quad({0,ya,0},{len,ya,0},{len,min(yb,7),0},{0,min(yb,7),0},mat,1)end
   if yb>H-9 then L.quad({0,max(ya,H-9),0},{len,max(ya,H-9),0},{len,yb,0},{0,yb,0},mat,1)end
   return true
  end,
  style=function(L,len,run)
   if run.o=='N' then return end   -- the south wall stays plain
   -- TEST95: continuous bay liners close the gaps behind the mullions.
   -- All planting is baked into this wall mesh; no per-plant update/draw.
   local depth=36
   local n=max(1,floor(len/34+.5));local pw=len/n
   L.quad({0,7,-depth},{len,7,-depth},{len,H-9,-depth},{0,H-9,-depth},'inAqua',1)
   L.quad({0,7,0},{len,7,0},{len,7,-depth},{0,7,-depth},'ktSandstone',1.05)
   L.quad({0,H-9,-depth},{len,H-9,-depth},{len,H-9,0},{0,H-9,0},'inAqua',1)
   for i=0,n-1 do
    local a,b=i*pw+2.2,(i+1)*pw-2.2
    L.box(a-2.2,0,0,a,H-6,1.6,'inSteel',1.05);L.box(b,0,0,b+2.2,H-6,1.6,'inSteel',1.05)
    L.box(a,5,0,b,7,2.2,'inSteel',1.08);L.box(a,H-9,0,b,H-7,1.8,'inSteel',1.05)
    -- Layered rounded stone shelves, with an open central swim corridor.
    for k=1,3 do
     local x=a+3+(b-a-6)*rh(i,k,17)
     local z=-29+rh(i,k,18)*3
     local h=2+rh(i,k,19)*3.5
     L.sphere(x,7+h*.6,z,3.5+rh(i,k,20)*3,h,3,'lvStone',8,4,i*7+k,'lgVerde')
    end
    -- Ribbon kelp behind the fish: tapering, bent blades and side leaves,
    -- distributed in unequal clumps rather than identical straight spikes.
    for clump=0,2 do
     local root=a+4+(b-a-8)*(clump/2)
     for k=0,4 do
      local x=root+(k-2)*.85;local z=-32+rh(i,k+clump*5,11)*2
      local h=10+rh(i*3+clump,k,12)*17
      local bend=(rh(i,k,13)-.5)*7;local width=.5+rh(i,k,14)*.65
      local mat=(k+clump)%3==0 and'lgVerde'or'lgLeaf'
      for step=0,3 do
       local t0,t1=step/4,(step+1)/4
       local x0,x1=x+bend*t0*t0,x+bend*t1*t1
       local w0,w1=width*(1-t0*.85),width*(1-t1*.85)
       L.quad({x0-w0,7+h*t0,z},{x0+w0,7+h*t0,z},
        {x1+w1,7+h*t1,z+sin(t1*pi)*1.5},{x1-w1,7+h*t1,z+sin(t1*pi)*1.5},mat,1.12)
      end
      for branch=1,3 do
       local y=7+h*branch/5;local bx=x+bend*(branch/5)^2
       local sign=(branch+k)%2==0 and 1 or -1
       L.quad({bx,y,z+.2},{bx+sign*3,y+1.5,z+1.2},{bx+sign*4,y+3,z+.7},{bx,y+.8,z+.2},mat,1.16)
      end
     end
    end
    -- Low rosettes and a few stones at the front give the sand real depth.
    for k=0,1 do
     local x=k==0 and a+3 or b-3;local z=-5-k*2
     L.sphere(x,8,z,2.5,1.3,2,'lvStone',7,3,i+k)
     for leaf=0,5 do
      local ang=leaf*pi/3;local dx,dz=cos(ang)*3.4,sin(ang)*2.2
      L.quad({x,7.5,z},{x+dx*.7-.6,10.5,z+dz*.7},
       {x+dx,12+rh(i,leaf,8)*3,z+dz},{x+dx*.7+.6,10.5,z+dz*.7},'lgLeaf',1.1)
     end
    end
   end
   L.quad({0,7,-depth},{0,7,0},{0,H-9,0},{0,H-9,-depth},'inAqua',1)
   L.quad({len,7,0},{len,7,-depth},{len,H-9,-depth},{len,H-9,0},'inAqua',1)
  end})
 -- TEST96: a purpose-built acoustic ceiling, one static cutaway part.
 -- Narrow recessed joints, shallow bevels and inset light bars give real
 -- scale and depth without animated ceiling textures or extra passes.
 do
  local E=C.part('ceiling',{below=H})
  local L=K.frame(C,E,0,0,0,0)
  local nx=max(1,floor((S.e-S.w)/28+.5))
  local nz=max(1,floor((S.s-S.n)/36+.5))
  local px,pz=(S.e-S.w)/nx,(S.s-S.n)/nz
  E.quad({S.w,H,S.n},{S.e,H,S.n},{S.e,H,S.s},{S.w,H,S.s},'inCeiling',.64)
  for iz=0,nz-1 do for ix=0,nx-1 do
   local x0,x1=S.w+ix*px+.45,S.w+(ix+1)*px-.45
   local z0,z1=S.n+iz*pz+.45,S.n+(iz+1)*pz-.45
   local bevel=.35;local y=H-.9
   E.quad({x0+bevel,y,z0+bevel},{x1-bevel,y,z0+bevel},
    {x1-bevel,y,z1-bevel},{x0+bevel,y,z1-bevel},'inCeiling',1.10)
   E.quad({x0,H-.35,z0},{x1,H-.35,z0},{x1-bevel,y,z0+bevel},{x0+bevel,y,z0+bevel},'inCeiling',.94)
   E.quad({x1,H-.35,z1},{x0,H-.35,z1},{x0+bevel,y,z1-bevel},{x1-bevel,y,z1-bevel},'inCeiling',.90)
   E.quad({x0,H-.35,z1},{x0,H-.35,z0},{x0+bevel,y,z0+bevel},{x0+bevel,y,z1-bevel},'inCeiling',.92)
   E.quad({x1,H-.35,z0},{x1,H-.35,z1},{x1-bevel,y,z1-bevel},{x1-bevel,y,z0+bevel},'inCeiling',.96)
   -- Paired lighting lanes with dark recessed surrounds; the diffuser is
   -- a separate, offset underside, so no coincident polygons can flicker.
   if ix==0 or ix==nx-1 then
    local x,z=(x0+x1)/2,(z0+z1)/2
    E.quad({x-1.1,y-.15,z-9},{x+1.1,y-.15,z-9},{x+1.1,y-.15,z+9},{x-1.1,y-.15,z+9},'ktMarine',.65)
    L.raw({x-.55,y-.35,z-8},{x+.55,y-.35,z-8},{x+.55,y-.35,z+8},{x-.55,y-.35,z+8},'inPanel',1)
   end
  end end
 end
 local R=C.part('room')
 local function F(x,y,z,yaw)return K.frame(C,R,x,y,z,yaw)end
 -- Nine real, animated imported Pokemon, bounded within three deep bays.
 -- Opaque room meshes and the engine's native pool remain independent.
 C.fx.aquarium={
  {x=(S.w+S.e)/2,z=S.n-18,w=S.e-S.w,side='N',wall=S.n},
  {x=S.w-18,z=(S.n+S.s)/2,w=S.s-S.n,side='W',wall=S.w,axis='z'},
  {x=S.e+18,z=(S.n+S.s)/2,w=S.s-S.n,side='E',wall=S.e,axis='z'},
 }
 -- the pool: a mosaic basin under the water, a white coping round it
 do
  local E=C.part('pool')
  local L=K.frame(C,E,0,0,0,0)
  local depth=12
  for cy=0,C.ch-1 do for cx=0,C.cw-1 do
   if water(cx,cy)then
    local x0,x1,z0,z1=cx*CS,(cx+1)*CS,cy*CS,(cy+1)*CS
    L.quad({x0,-depth,z1},{x1,-depth,z1},{x1,-depth,z0},{x0,-depth,z0},'inPoolBed',.9)
    -- basin walls toward dry cells
    if not water(cx,cy-1)then L.quad({x0,-depth,z0},{x1,-depth,z0},{x1,0,z0},{x0,0,z0},'inPoolBed',.8);L.box(x0,-.4,z0,x1,.5,z0+1.6,'inEnamel',1.1)end
    if not water(cx,cy+1)then L.quad({x1,-depth,z1},{x0,-depth,z1},{x0,0,z1},{x1,0,z1},'inPoolBed',.95);L.box(x0,-.4,z1-1.6,x1,.5,z1,'inEnamel',1.1)end
    if not water(cx-1,cy)then L.quad({x0,-depth,z1},{x0,-depth,z0},{x0,0,z0},{x0,0,z1},'inPoolBed',.85);L.box(x0,-.4,z0,x0+1.6,.5,z1,'inEnamel',1.1)end
    if not water(cx+1,cy)then L.quad({x1,-depth,z0},{x1,-depth,z1},{x1,0,z1},{x1,0,z0},'inPoolBed',.85);L.box(x1-1.6,-.4,z0,x1,.5,z1,'inEnamel',1.1)end
   end
  end end
  -- (the water's surface is the engine's own: these cells stay unclaimed,
  -- see M.keep)
 end
 -- the diving decks (_) in blue mosaic with white edges
 do
  local E=C.part('floor')
  for _,c in ipairs(cellsOf(C,'_'))do
   local x0,z0=c[1]*CS,c[2]*CS
   E.quad({x0+.5,.08,z0+15.5},{x0+15.5,.08,z0+15.5},{x0+15.5,.08,z0+.5},{x0+.5,.08,z0+.5},'lgPool',1.05)
  end
 end
 -- railings (F): glass balustrades on chrome posts
 for _,c in ipairs(cellsOf(C,'F'))do
  local x0,z0=c[1]*CS,c[2]*CS
  local L=F(x0+8,0,z0+8,0)
  L.box(-8,0,-1,8,1.4,1,'inSteel',1)
  L.box(-7.6,1.4,-.25,7.6,11,.25,'ktGlass',1.2)
  L.box(-8,11,-.8,8,12,.8,'inSteel',1.1)
  for _,x in ipairs({-7.4,7.4})do L.box(x-.5,0,-.5,x+.5,12,.5,'inSteel',1.05)end
 end
 statues(C,F,{stone='inEnamel',base='ktMarine',top='ktMarine'})
 entrance(C,{view=2,frame='white',leaf='ktGlass',mat='inRugBlue'})
 -- a big wave emblem over Misty's deck
 do
  local Ln=emblem(C,W/2,H-20,9,'ktMarine','inSteel')
  for i=0,2 do local y=H-24+i*3.6
   for k=0,5 do local x=W/2-8+k*3.2;Ln.quad({x,y,1.1},{x+3.2,y,1.1},{x+3.2,y+1.2+sin(k*1.4)*.8,1.1},{x,y+1.2+sin(k*1.2)*.8,1.1},'white',1.15)end
  end
 end
 -- light: blue from the tanks, shimmer on the floor
 for x=24,W-24,40 do for z=S.n+20,D-24,40 do C.fx.pools[#C.fx.pools+1]={x=x,y=.3,z=z,r=18,a=.03,col={.4,.85,1}}end end
 C.addLight(S.w+4,30,D/2,60,.25);C.addLight(S.e-4,30,D/2,60,.25);C.addLight(W/2,30,S.n+4,70,.25)
 C.fx.ambience={aqua=.45,hall=.12}
end

------------------------------------------------------------------ VERMILION
function M.vermilion(C)
 fxInit(C)
 C.fx.arcs,C.fx.flows,C.fx.beacons={},{},{}
 local H=68;C.H=H;C.ambient=.72;C.maxLight=1.55
 local W,D=C.cw*CS,C.ch*CS
 local S=K.shell(C,{H=H,solid=function()return false end,
  blocked=function(cx,cy)return C.is(cx,cy,'GEMBTY')end,door=Town.doorFn(C),
  paint='ktSteel',upper='lvSlate',wainscot='ktBasalt',wainscotH=12,rail='gold',skirting='dark',cornice='ktSteel',cap='ktBasalt',
  floor='ktSteel',ceiling='ktBasalt',
  style=function(L,len,run)
   -- hazard stripes along the foot of the walls
   local x=0
   while x<len do L.quad({x,12,.6},{x+2,12,.6},{x+4,14.4,.6},{x+2,14.4,.6},'gold',1.1);x=x+4 end
   L.box(0,11.6,0,len,12,.7,'dark',.8);L.box(0,14.4,0,len,14.8,.7,'dark',.8)
  end})
 local R=C.part('room')
 local function F(x,y,z,yaw)return K.frame(C,R,x,y,z,yaw)end
 -- floor plates
 do local E=C.part('floor')
  for x=0,W,16 do E.quad({x-.15,.06,0},{x+.15,.06,0},{x+.15,.06,D},{x-.15,.06,D},'dark',.6)end
  for z=0,D,16 do E.quad({0,.06,z-.15},{W,.06,z-.15},{W,.06,z+.15},{0,.06,z+.15},'dark',.6)end
 end
 -- the generators (G): towers of coils in each top corner
 for _,g in ipairs(groups(C,'G'))do
  local x,z=g.cx,(g.y0*CS+(g.y1+1)*CS)/2
  local L=F(x,0,z,0)
  L.box(-14,0,-30,14,4,30,'ktBasalt',1)
  for k,zz in ipairs({-15,15})do
   L.cyl(0,4,10,zz,10,9,'inSteel',16,false)
   L.cyl(0,10,44,zz,6,6,'ktSteel',14,false)
   for r=0,8 do L.cyl(0,13+r*3.4,14.6+r*3.4,zz,7.2,7.2,'lgBronze',16,false)end
   L.cyl(0,44,48,zz,6,3,'inSteel',12)
   L.sphere(0,52,zz,6.4,5,6.4,'inSteel',12,6)
   L.sphere(0,52,zz,4,3.2,4,'lgCrystal',10,5)
   local w=L.P({0,52,zz})
   C.fx.glows[#C.fx.glows+1]={x=w[1],y=w[2],z=w[3],r=14,col='cyan',a=.35}
   C.fx.sparks[#C.fx.sparks+1]={x=w[1],y=w[2],z=w[3],r=9,col={.6,.9,1}}
   C.addLight(w[1],w[2],w[3],90,.30)
   -- TEST191: now and then a coil throws a spark up into the ceiling
   local up=L.P({(k==1 and -3 or 3),H,zz+(k==1 and -4 or 4)})
   C.fx.arcs[#C.fx.arcs+1]={a={w[1],w[2]+5,w[3]},b=up,rest=.82,jag=.22,bow=.04,w=.8}
  end
  -- TEST191: the arc leaping between the generator's two coils
  C.fx.arcs[#C.fx.arcs+1]={a=L.P({0,52,-15}),b=L.P({0,52,15}),rest=.32,jag=.15,bow=.16,w=1.1}
 end
 -- the control panels on the north wall (E in the top row) and the big
 -- transformer (M)
 for _,c in ipairs(cellsOf(C,'E'))do
  if c[2]==0 then
   local L=F(c[1]*CS+8,0,8,0)
   L.box(-7.6,0,-7,7.6,22,4,'ktSteel',1.0)
   L.quad({-7.2,22,-6},{7.2,22,-6},{7.2,18,4.4},{-7.2,18,4.4},'lvSlate',1.0)
   L.raw({-6,14,4.05},{6,14,4.05},{6,20,4.05},{-6,20,4.05},'inScreen',3)
   for k=0,3 do L.box(-6+k*3.4,8,4,-4.4+k*3.4,11,4.6,({'red','gold','leaf','blue'})[k+1],1.15)end
   for k=0,5 do L.disc(-5+k*2,5,4.05,.7,'dark',8)end
  end
 end
 for _,g in ipairs(groups(C,'M'))do
  local L=F(g.cx,0,(g.y0*CS+(g.y1+1)*CS)/2,0)
  L.box(-7.6,0,-14,7.6,30,10,'ktBasalt',.95)
  for k=0,5 do L.box(-8.2,4+k*4,-12,8.2,5.6+k*4,8,'inSteel',1.05)end
  L.box(-4,30,-6,4,36,2,'inSteel',1)
  L.cyl(-3,36,42,-2,1.2,1.2,'inEnamel',8);L.cyl(3,36,42,-2,1.2,1.2,'inEnamel',8)
  local Lw=K.onWall(C,'N',0,0)
 end
 -- the barrier (B, and the E set into it) with the gate in the middle:
 -- the gate stands while the live tiles say it is shut
 local function wallPiece(c)
  local L=F(c[1]*CS+8,0,c[2]*CS+8,0)
  L.box(-8,0,-8,8,26,8,'ktSteel',1.0)
  L.box(-8.4,26,-8.4,8.4,28,8.4,'gold',1.05)
  local x=-8
  while x<8 do L.quad({x,2,8.05},{x+2,2,8.05},{x+4,4.4,8.05},{x+2,4.4,8.05},'gold',1.1);x=x+4 end
 end
 for _,c in ipairs(cellsOf(C,'B'))do wallPiece(c)end
 for _,c in ipairs(cellsOf(C,'E'))do if c[2]>0 then wallPiece(c)
  local L=F(c[1]*CS+8,0,c[2]*CS+8,0);L.raw({-5,12,8.1},{5,12,8.1},{5,20,8.1},{-5,20,8.1},'inScreen',1)end end
 -- the gate cells: (4..5, 4..5) in the plan; floor in the ROM, a barrier
 -- block while the cans are unsolved
 C.watchAll=true
 local gate={}
 for cy=4,5 do for cx=4,5 do
  local t=C.tile(cx*2,cy*2)
  if t and t~=17 then gate[#gate+1]={cx,cy}end
 end end
 do
  local L=F(W/2,0,4*CS,0)
  for _,sx in ipairs({-16,16})do
   L.box(sx-2.4,0,0,sx+2.4,30,32,'ktSteel',1.02)
   L.box(sx-2.8,30,0,sx+2.8,32,32,'gold',1.05)
   for k=0,3 do L.box(sx-2.6,5+k*6,8,sx+2.6,6.4+k*6,24,'lgBronze',1.1)end
  end
  if #gate>0 then
   -- the electric field: bars of light between the posts
   for k=0,5 do L.raw({-13.6,4+k*4.4,16},{13.6,4+k*4.4,16},{13.6,5+k*4.4,16},{-13.6,5+k*4.4,16},'inLamp',2)end
   for k=0,3 do C.fx.sparks[#C.fx.sparks+1]={x=W/2-10+k*7,y=8+k*4,z=4*CS+16,r=6,col={1,.95,.5}}end
   C.fx.glows[#C.fx.glows+1]={x=W/2,y=14,z=4*CS+16,r=20,col='gold',a=.22}
  end
 end
 -- the trash cans (T): steel bins, lids on
 for _,c in ipairs(cellsOf(C,'T'))do
  local L=F(c[1]*CS+8,0,c[2]*CS+9,0)
  L.cyl(0,0,12,0,5.2,6,'ktSteel',14,false)
  for k=0,3 do L.cyl(0,2+k*3,2.6+k*3,0,5.5+k*.2,5.6+k*.2,'inSteel',14,false)end
  L.cyl(0,12,13,0,6.4,6.4,'inSteel',14)
  L.cyl(0,13,14.4,0,5,1,'inSteel',14)
  L.box(-1.8,14,-.4,1.8,15,.4,'dark',1)
  -- TEST191: Lt. Surge's bolt stencilled on the front of every can
  -- (standing just proud of the tapering body and its hoops)
  local function zf(y)return 5.55+.0667*y end
  local function bolt(a,b,c,d)
   L.quad({a[1],a[2],zf(a[2])},{b[1],b[2],zf(b[2])},{c[1],c[2],zf(c[2])},{d[1],d[2],zf(d[2])},'gold',1.25)
  end
  bolt({1.3,10.6},{-.3,10.6},{-1.3,7.6},{.5,7.6})
  bolt({1.5,7.6},{-.5,7.6},{-1.1,3.2},{-1.1,3.2})
 end
 -- TEST191: the power plant's wiring. Conduits set into the floor, a lit
 -- core between two steel lips, carry pulses of light from the generators
 -- to the gate posts, and on through the barrier to its control panels.
 do
  local L0=F(0,0,0,0)
  local function up(a,b,c,d,mat,v,raw)
   -- a floor-level quad, wound to face up whatever order it was given
   local ux,uz=c[1]-a[1],c[3]-a[3];local vx,vz=d[1]-b[1],d[3]-b[3]
   if uz*vx-ux*vz<0 then a,b,c,d=a,d,c,b end
   if raw then L0.raw(a,b,c,d,mat,v)else L0.quad(a,b,c,d,mat,v)end
  end
  local function run(x0,z0,x1,z1)
   local lx,hx=min(x0,x1),max(x0,x1);local lz,hz=min(z0,z1),max(z0,z1)
   local along=hx-lx>hz-lz
   local w=2.1
   -- the trough (dark), its steel lips, the lit core
   if along then
    L0.box(lx-w,0,lz-w,hx+w,.12,lz+w,'dark',.7)
    L0.box(lx-w,0,lz-w,hx+w,.3,lz-w+.5,'inSteel',1)
    L0.box(lx-w,0,lz+w-.5,hx+w,.3,lz+w,'inSteel',1)
    up({lx-w+.5,.2,lz-.55},{hx+w-.5,.2,lz-.55},{hx+w-.5,.2,lz+.55},{lx-w+.5,.2,lz+.55},'dnNeon',3,true)
   else
    L0.box(lx-w,0,lz-w,lx+w,.12,hz+w,'dark',.7)
    L0.box(lx-w,0,lz-w,lx-w+.5,.3,hz+w,'inSteel',1)
    L0.box(lx+w-.5,0,lz-w,lx+w,.3,hz+w,'inSteel',1)
    up({lx-.55,.2,lz-w+.5},{lx+.55,.2,lz-w+.5},{lx+.55,.2,hz+w-.5},{lx-.55,.2,hz+w-.5},'dnNeon',3,true)
   end
  end
  local function circuit(pts)
   for i=2,#pts do run(pts[i-1][1],pts[i-1][2],pts[i][1],pts[i][2])end
   C.fx.flows[#C.fx.flows+1]={pts=pts,y=.42,speed=34,gap=26,r=2.4,col={.45,.95,1}}
  end
  local gx0,gx1=W/2-16,W/2+16   -- the gate posts
  local gz0,gz1=4*CS,6*CS        -- the barrier's north and south faces
  -- generators -> gate posts, either side of the leader's floor
  circuit({{34,46},{gx0,46},{gx0,gz0-2}})
  circuit({{W-34,46},{gx1,46},{gx1,gz0-2}})
  -- gate posts -> round the corridor -> up into the barrier's panels
  circuit({{gx0,gz1+1},{gx0,gz1+8},{32,gz1+8},{32,gz1+1}})
  circuit({{gx1,gz1+1},{gx1,gz1+8},{W-32,gz1+8},{W-32,gz1+1}})
  -- the leader's emblem inlaid in the floor before him: a gold ring, a
  -- navy field, a gold bolt
  local ex,ez=W/2,44
  L0.disc(ex,.14,ez,13,'gold',28,'y',1.15)
  L0.disc(ex,.22,ez,11.4,'navy',28,'y',1.0)
  local function fb(p)return{ex+p[1]*2.6,.30,ez-(p[2]-6.9)*2.3}end
  up(fb({1.3,10.6}),fb({-.3,10.6}),fb({-1.3,7.6}),fb({.5,7.6}),'gold',1.3)
  up(fb({1.5,7.6}),fb({-.5,7.6}),fb({-1.1,3.2}),fb({-1.1,3.2}),'gold',1.3)
  -- warning beacons on the gate posts: an amber lamp in a steel cage,
  -- its light turning
  for _,bx in ipairs({gx0,gx1})do
   local bz=(gz0+gz1)/2
   local Lb=F(bx,32,bz,0)
   Lb.cyl(0,0,1.2,0,2.2,2.0,'inSteel',10)
   for i=0,5 do
    local a0,a1=i/6*pi*2,(i+1)/6*pi*2
    Lb.raw({cos(a0)*1.5,1.2,sin(a0)*1.5},{cos(a1)*1.5,1.2,sin(a1)*1.5},{cos(a1)*1.3,4.4,sin(a1)*1.3},{cos(a0)*1.3,4.4,sin(a0)*1.3},'dnNeon',2)
    Lb.raw({0,5.0,0},{0,5.0,0},{cos(a1)*1.3,4.4,sin(a1)*1.3},{cos(a0)*1.3,4.4,sin(a0)*1.3},'dnNeon',2)
   end
   for i=0,3 do
    local a=i/4*pi*2+pi/4
    Lb.rod({cos(a)*1.9,1.2,sin(a)*1.9},{cos(a)*1.7,5.2,sin(a)*1.7},.18,'dark',1)
   end
   Lb.cyl(0,5.2,5.6,0,1.9,1.2,'inSteel',10)
   C.fx.beacons[#C.fx.beacons+1]={x=bx,y=35,z=bz,reach=34,spin=2.6,r=6,a=.06}
  end
 end
 -- a lightning emblem on the north wall
 do
  local Ln=emblem(C,W/2,H-18,10,'navy','gold')
  Ln.quad({W/2+2,H-9,1.2},{W/2+5,H-9,1.2},{W/2-1,H-19,1.2},{W/2-3,H-18,1.2},'gold',1.3)
  Ln.quad({W/2-3,H-18,1.2},{W/2+3,H-18,1.2},{W/2-2,H-27,1.2},{W/2-2,H-27,1.2},'gold',1.3)
 end
 statues(C,F,{stone='ktSteel',base='ktBasalt',top='gold'})
 entrance(C,{view=2,frame='ktSteel',leaf='inSteel',mat='gold'})
 -- industrial lamps
 local E=C.part('ceilfx',{below=H+2})
 local Lc=K.frame(C,E,0,0,0,0)
 for x=40,W-30,40 do for z=100,D-30,48 do
  Lc.cyl(x,H-8,H,z,.25,.25,'dark',4,false)
  Lc.cyl(x,H-12,H-8,z,6,1.4,'gold',12,false)
  Lc.cyl(x,H-12.2,H-11.8,z,1.6,1.6,'inLamp',8)
  C.addLight(x,H-16,z,70,.28)
 end end
 C.fx.ambience={power=.5}
end

------------------------------------------------------------------ CELADON
function M.celadon(C)
 fxInit(C)
 local H=64;C.H=H;C.ambient=.86;C.maxLight=1.5
 local W,D=C.cw*CS,C.ch*CS
 local solid=Town.topWall(C)
 local S=K.shell(C,{H=H,solid=solid,blocked=function(cx,cy)return C.is(cx,cy,'OXY')end,door=Town.doorFn(C),
  paint='inBrick',upper='inBrick',rail='white',skirting='white',cornice='white',cap='white',floor='lgGravel',ceiling=false,
  style=function(L,len,run)
   if run.o=='N'then return end
   -- glass walls above a brick plinth, white glazing bars
   local n=max(1,floor(len/16+.5));local pw=len/n
   L.box(0,10,0,len,11.4,2.2,'white',1.1)
   for i=0,n-1 do
    local a,b=i*pw+.8,(i+1)*pw-.8
    L.quad({a,11.4,.4},{b,11.4,.4},{b,H-2,.4},{a,H-2,.4},'inWindow',1)
    L.box(b,11.4,0,b+1.6,H,1.4,'white',1.05)
    L.box(a,34,.4,b,35,1.1,'white',1.05)
   end
   L.box(0,11.4,0,1,H,1.4,'white',1.05)
   -- TEST178: the real city through the glass (one view per wall, behind
   -- the glazing bars)
   for _,sg in ipairs(K.cutSpans(.8,len-.8,run.holes or{}))do
    if sg[2]-sg[1]>=24 then K.pane(C,K.runFrame(C,run),sg[1],sg[2],11.4,H-2,.6,1,{split=72})end
   end
  end})
 local R=C.part('room')
 local function F(x,y,z,yaw)return K.frame(C,R,x,y,z,yaw)end
 -- the glass roof (seen from below), white ribs. TEST179: the glass is
 -- real glass: the sky above is the game's own (the hour, the stars, the
 -- moon), painted behind the room (openSky); a faint sheen in the effects
 -- pass says the panes are there.
 C.openSky=true
 do
  local E=C.part('roof',{below=H+.5})
  local L=K.frame(C,E,0,0,0,0)
  for x=0,W-1,32 do
   L.box(x-.8,H-1.6,S.n,x+.8,H,D,'white',1.05)
  end
  L.box(W-.8,H-1.6,S.n,W+.8,H,D,'white',1.05)
  for z=S.n,D,32 do L.box(0,H-1.6,z-.8,W,H,z+.8,'white',1.05)end
  -- the eaves: a white fascia where the glass meets the walls
  L.box(-1.2,H-2.4,S.n-1.2,W+1.2,H,S.n+.4,'white',1.0)
  L.box(-1.2,H-2.4,D-.4,W+1.2,H,D+1.2,'white',1.0)
  C.fx.roofGlass=C.fx.roofGlass or{}
  for x=0,W-1,32 do for z=S.n,D-1,32 do
   C.fx.roofGlass[#C.fx.roofGlass+1]={x0=x+.8,z0=z+.8,x1=min(W,x+32)-.8,z1=min(D,z+32)-.8,y=H-.2}
  end end
 end
 -- sunbeams through the roof
 for i=0,3 do
  local x,z=W*(.2+i*.2),S.n+40+i*30
  C.fx.beams[#C.fx.beams+1]={x=x+20,y=H,z=z-30,tx=x,ty=0,tz=z,r1=14,a=.045,col={1,.96,.8}}
 end
 -- flower beds (f): a carpet of blooms with sprigs standing in it
 do
  local E=C.part('beds')
  for cy=0,C.ch-1 do for cx=0,C.cw-1 do
   if C.at(cx,cy)=='f'then
    local x0,z0=cx*CS,cy*CS
    E.quad({x0,.1,z0+16},{x0+16,.1,z0+16},{x0+16,.1,z0},{x0,.1,z0},'lgMeadow',1.05)
    local L=K.frame(C,E,0,0,0,0)
    for k=0,7 do
     local x,z=x0+1.5+rh(cx,cy,k)*13,z0+1.5+rh(cy,cx,k+3)*13
     local col=({'flower','gold','white','red','lgPlum','flower'})[(cx*3+cy+k)%6+1]
     L.quad({x-.9,1.6,z},{x+.9,1.6,z},{x+.9,2.6,z},{x-.9,2.6,z},col,1.15)
     L.quad({x,1.6,z-.9},{x,1.6,z+.9},{x,2.6,z+.9},{x,2.6,z-.9},col,1.05)
     L.quad({x-.12,.1,z},{x+.12,.1,z},{x+.12,1.7,z},{x-.12,1.7,z},'leaf',1)
    end
   end
  end end
 end
 -- clipped shrubs (O) and the trees to Cut (X)
 for _,c in ipairs(cellsOf(C,'O'))do
  local L=F(c[1]*CS+8,0,c[2]*CS+8,0)
  L.cyl(0,0,1.5,0,7.4,7.6,'forestFloor',10,false)
  L.sphere(0,8,0,7.6,7,7.6,'lgFoliage',10,6,c[1]*5+c[2])
  if (c[1]+c[2])%2==0 then
   for k=0,6 do local a=k*.9+c[1];L.sphere(cos(a)*5.8,8+sin(k*1.7)*4,sin(a)*5.8,1,1,1,({'flower','white','lgPlum'})[k%3+1],6,3)end
  end
 end
 C.watchAll=true
 for _,c in ipairs(cellsOf(C,'X'))do
  local t=C.tile(c[1]*2,c[2]*2)
  local L=F(c[1]*CS+8,0,c[2]*CS+8,0)
  if t==nil or t==64 then
   -- a young tree you could Cut
   L.cyl(0,0,1,0,3,3,'forestFloor',8)
   L.cyl(0,0,9,0,1,.7,'lgBark',6,false)
   L.sphere(0,12,0,5.4,5,5.4,'lgLeaf',9,5,c[1]*3)
   L.sphere(2,15,1,3.6,3.4,3.6,'lgLeaf',8,4,c[1]*5)
  else
   L.cyl(0,0,2.2,0,1.6,1.4,'lgBark',8,'inPine')
  end
 end
 -- a little stone fountain on the gravel at the hall's foot? the floor is
 -- walkable there; the fountain sound alone, and planters on the walls
 for _,side in ipairs({'W','E'})do
  local Lw=K.onWall(C,side,0,0)
  for i=0,3 do
   local u=40+i*44
   Lw.box(u-6,30,0,u+6,34,3.4,'ktTerracotta',1)
   for k=0,4 do Lw.box(u-5+k*2.4,34,1,u-4+k*2.4,36+rh(i,k,1)*3,2.4,'lgLeaf',1.05);Lw.box(u-5.3+k*2.4,35+rh(i,k,1)*3,1.2,u-3.7+k*2.4,37+rh(i,k,1)*3,2.6,({'flower','white','gold'})[k%3+1],1.15)end
   for k=0,3 do Lw.quad({u-4+k*2.6,30,3.2},{u-3+k*2.6,30,3.2},{u-2.6+k*2.6,18+rh(i,k,4)*6,3.4},{u-3.6+k*2.6,18+rh(i,k,4)*6,3.4},'forestLeaf',1)end
  end
 end
 -- hanging baskets from the roof ribs (high, out of the way)
 do
  local E=C.part('baskets',{below=H+70})
  for i=0,3 do
   local x,z=32+i*32,S.n+30+(i%2)*60
   local L=K.frame(C,E,x,0,z,0)
   L.rod({0,H,0},{0,H-12,0},.12,'dark')
   L.cyl(0,H-15,H-12,0,2,3.2,'ktTerracotta',10)
   for k=0,7 do local a=k*.8;L.quad({cos(a)*2.4,H-12,sin(a)*2.4},{cos(a)*4,H-14,sin(a)*4},{cos(a+.3)*3.6,H-20-rh(i,k,1)*6,sin(a+.3)*3.6},{cos(a+.3)*3.6,H-20-rh(i,k,1)*6,sin(a+.3)*3.6},'forestLeaf',1.05)end
   L.sphere(0,H-11.4,0,2.6,1.4,2.6,'flower',8,3)
  end
 end
 statues(C,F,{stone='lgMarble',base='lgVerde',top='lgLeaf'})
 entrance(C,{view=1,frame='white',leaf='ktGlass',mat='inRugGreen'})
 -- petals and butterflies turning in the light
 C.fx.motes={x=W/2,z=D*.45,r=70,y0=4,y1=40,n=40,col={1,.85,.9}}
 C.addLight(W/2,60,D/2,200,.18)
 C.fx.ambience={garden=.55}
end

------------------------------------------------------------------ FUCHSIA
function M.fuchsia(C)
 fxInit(C)
 local H=60;C.H=H;C.ambient=.70;C.maxLight=1.45
 local W,D=C.cw*CS,C.ch*CS
 local solid=Town.topWall(C)
 local S=K.shell(C,{H=H,solid=solid,blocked=function(cx,cy)return C.is(cx,cy,'Y')end,door=Town.doorFn(C),
  paint='cream',upper='cream',wainscot='inWalnut',wainscotH=8,rail='inWalnut',skirting='inWalnut',cornice='inWalnut',cap='inWalnut',
  floor='inWalnut',ceiling='inPine',
  style=function(L,len,run)
   if run.o=='N'then return end
   -- paper screens lit from beyond, in dark frames
   local n=max(1,floor(len/24+.5));local pw=len/n
   for i=0,n-1 do
    local a,b=i*pw+1,(i+1)*pw-1
    L.quad({a,9,.3},{b,9,.3},{b,H-12,.3},{a,H-12,.3},'inShoji',1)
    L.box(b,8,0,b+2,H,1.6,'inWalnut',1)
   end
   L.box(0,H-12,0,len,H-9,1.8,'inWalnut',1.05)
   L.box(0,8,0,len,9,1.8,'inWalnut',1.05)
  end})
 local R=C.part('room')
 local function F(x,y,z,yaw)return K.frame(C,R,x,y,z,yaw)end
 -- tatami laid in the floor (the invisible walls are left unseen)
 do
  local E=C.part('floor')
  for _,r in ipairs({{32,48,128,112},{16,160,64,208},{96,144,144,192}})do
   C.floorRect(E,r[1],r[2],r[3],r[4],.06,'inTatami',1,nil,16)
  end
 end
 -- Koga's dais: a low black lacquer step and a folding screen of mountains
 do
  local Ln=K.onWall(C,'N',0,0)
  for i=0,3 do
   local a=W/2-34+i*17
   Ln.box(a,6,1.6,a+16.4,40,2.4,'lgGold',1)
   Ln.quad({a+1,8,2.45},{a+15.4,8,2.45},{a+15.4,38,2.45},{a+1,38,2.45},'ktPearl',1.1)
   Ln.quad({a+1,8,2.5},{a+15.4,8,2.5},{a+8+(i%2)*4,30-(i%2)*4,2.5},{a+8+(i%2)*4,30-(i%2)*4,2.5},'lvSlate',1)
  end
  Ln.disc(W/2+18,33,2.6,3.2,'red',14,nil,1.2)
  -- throwing stars on a rack and crossed blades
  for i=0,4 do local x=24+i*7
   for k=0,3 do local a=k*pi/2+.4;Ln.quad({x,48,1},{x+cos(a)*2.4,48+sin(a)*2.4,1},{x+cos(a+.4)*1,48+sin(a+.4)*1,1},{x,48,1},'lgSilver',1.2)end end
 end
 -- violet lanterns down the hall
 for _,side in ipairs({'W','E'})do
  for i=0,3 do
   local z=48+i*40
   local x=side=='W'and 4 or W-4
   local L=F(x,30,z,0)
   L.box(-1.4,0,-1.4,1.4,1,1.4,'inWalnut',1)
   L.cyl(0,-8,0,0,2.6,2.6,'lgAmethyst',8,false)
   L.box(-2,-8.6,-2,2,-8,2,'inWalnut',1)
   C.fx.glows[#C.fx.glows+1]={x=x,y=26,z=z,r=9,col='violet',a=.35}
   C.addLight(x,26,z,40,.18)
  end
 end
 -- poison mist creeping across the floor
 C.fx.mist={}
 for i=0,9 do C.fx.mist[#C.fx.mist+1]={x=20+rh(i,1,1)*(W-40),y=1.5,z=40+rh(i,2,1)*(D-80),r=26,phase=i*1.3,drift=14,col={.75,.45,1},a=.07}end
 statues(C,F,{stone='inWalnut',base='dark',top='lgPlum'})
 entrance(C,{view=1,frame='inWalnut',leaf='inShoji',mat='lgPlum'})
 C.fx.ambience={hall=.1,crypt=.08}
end

------------------------------------------------------------------ SAFFRON
function M.saffron(C)
 fxInit(C)
 local H=56;C.H=H;C.ambient=.68;C.maxLight=1.5
 local W,D=C.cw*CS,C.ch*CS
 local solid=function(cx,cy)return C.at(cx,cy)=='W'end
 local inner=function(cx,cy)return solid(cx,cy)and cy>0 end
 local S=K.shell(C,{H=H,solid=solid,inner=inner,blocked=function(cx,cy)return C.is(cx,cy,'WY')end,door=Town.doorFn(C),
  paint='lvSlate',upper='lvSlate',innerPaint='lvSlate',rail='lgAmethyst',skirting='dark',cornice='lgSilver',cap='dark',
  floor='inChecker',ceiling='lgNight',innerH=34,
  innerStyle=function(L,len,run,Hi)
   L.box(0,Hi-3,0,len,Hi-2,.8,'lgAmethyst',3)
   L.box(0,14,0,len,15,.6,'lgSilver',1.1)
  end})
 local R=C.part('room')
 local function F(x,y,z,yaw)return K.frame(C,R,x,y,z,yaw)end
 -- the warp pads (p): rings of light on a dark disc
 for _,c in ipairs(cellsOf(C,'p'))do
  local x,z=c[1]*CS+8,c[2]*CS+8
  local E=C.part('pads')
  local L=K.frame(C,E,x,0,z,0)
  L.disc(0,.1,0,7.4,'ktBasalt',20,'y',1)
  for i=0,19 do local a0,a1=i/20*pi*2,(i+1)/20*pi*2
   L.raw({cos(a0)*6.2,.16,sin(a0)*6.2},{cos(a1)*6.2,.16,sin(a1)*6.2},{cos(a1)*7,.16,sin(a1)*7},{cos(a0)*7,.16,sin(a0)*7},'inLamp',3)
   if i%2==0 then L.raw({cos(a0)*3.4,.17,sin(a0)*3.4},{cos(a1)*3.4,.17,sin(a1)*3.4},{cos(a1)*4,.17,sin(a1)*4},{cos(a0)*4,.17,sin(a0)*4},'inLamp',3)end
  end
  C.fx.glows[#C.fx.glows+1]={x=x,y=2,z=z,r=9,col='violet',a=.28}
  C.fx.pools[#C.fx.pools+1]={x=x,y=.4,z=z,r=10,a=.06,col={.8,.45,1}}
 end
 -- floating orbs in each room's corners, high up
 for cy=0,2 do for cx=0,2 do
  local x0,z0=cx*7*CS+8,cy*6*CS+16
  C.fx.glows[#C.fx.glows+1]={x=x0+12,y=34,z=z0+10,r=6,col='violet',a=.4}
 end end
 -- Sabrina's room: a star chart in the floor, a ring of silver
 do
  local E=C.part('inlay')
  local cx,cz=W/2,9.5*CS
  local L=K.frame(C,E,cx,0,cz,0)
  L.ring(0,.12,0,26,27.4,'lgSilver',40)
  for i=0,40 do local a=rh(i,1,1)*pi*2;local r=rh(i,2,1)*24;L.disc(cos(a)*r,.14,sin(a)*r,.4+rh(i,3,1)*.4,'lgSilver',6,'y',1.3)end
  for i=0,4 do local a=i/5*pi*2-pi/2;local b=(i+2)/5*pi*2-pi/2
   L.quad({cos(a)*20,.15,sin(a)*20},{cos(a)*20+.5,.15,sin(a)*20+.5},{cos(b)*20+.5,.15,sin(b)*20+.5},{cos(b)*20,.15,sin(b)*20},'lgAmethyst',3)end
 end
 statues(C,F,{stone='lgObsidian',base='lgAmethyst',top='lgPlum'})
 entrance(C,{view=3,frame='lgSilver',leaf='lgObsidian',mat='lgPlum'})
 C.addLight(W/2,40,D/2,240,.10)
 C.fx.ambience={hum=.12,crypt=.12}
end

------------------------------------------------------------------ CINNABAR
function M.cinnabar(C)
 fxInit(C)
 local H=56;C.H=H;C.ambient=.66;C.maxLight=1.6
 local W,D=C.cw*CS,C.ch*CS
 local solid=function(cx,cy)return C.is(cx,cy,'Wq')end
 local inner=function(cx,cy)return solid(cx,cy)and cy>0 and cx>0 end
 local S=K.shell(C,{H=H,solid=solid,inner=inner,innerH=36,blocked=function(cx,cy)return C.is(cx,cy,'WqQY')end,door=Town.doorFn(C),
  paint='lgSlate',upper='lgSlate',innerPaint='lgSlate',rail='lgLava',skirting='ktBasalt',cornice='ktBasalt',cap='ktBasalt',
  floor='lgPaveDark',ceiling='ktBasalt',
  style=function(L,len,run)
   -- veins of lava glowing through the rock walls
   for x=10,len-6,26 do L.quad({x,6,.3},{x+1.6,6,.3},{x+3+rh(x,len,1)*3,40,.3},{x+1.4+rh(x,len,1)*3,40,.3},'lgLava',1)end
  end,
  innerStyle=function(L,len,run,Hi)
   -- lava running in a channel along the wall's foot, veins above
   L.quad({0,1.2,.4},{len,1.2,.4},{len,3.2,.4},{0,3.2,.4},'lgLava',1)
   L.box(0,3.2,0,len,4,1.4,'lgObsidian',1)
   for x=8,len-6,22 do L.quad({x,4,.3},{x+1.4,4,.3},{x+2.6+rh(x,run.c,2)*2,Hi-4,.3},{x+1.2+rh(x,run.c,2)*2,Hi-4,.3},'lgLava',1)end
  end})
 local R=C.part('room')
 local function F(x,y,z,yaw)return K.frame(C,R,x,y,z,yaw)end
 -- the quiz terminals (Q, with their tops q in the wall)
 for _,g in ipairs(groups(C,'Q'))do
  for _,c in ipairs(g.cells)do
   local L=F(c[1]*CS+8,0,c[2]*CS+6,0)
   L.box(-7,0,-6,7,20,6,'ktSteel',1)
   L.quad({-6.6,20,-5},{6.6,20,-5},{6.6,16,6.4},{-6.6,16,6.4},'lvSlate',1)
   L.raw({-5.4,9,6.05},{5.4,9,6.05},{5.4,17,6.05},{-5.4,17,6.05},'inScreen',1)
   LA().inscription(L,'?',0,10.6,6.1,1.1,'gold')
   for k=0,2 do L.box(-4+k*3.4,4,6,-2.6+k*3.4,6,6.6,({'red','gold','leaf'})[k+1],1.15)end
   L.box(-7.4,20,-6.4,7.4,22,6.4,'lgLava',1)
   C.fx.glows[#C.fx.glows+1]={x=c[1]*CS+8,y=13,z=c[2]*CS+13,r=7,col='cyan',a=.18}
  end
 end
 -- fire gates: where the live map has a gate block in an opening
 C.watchAll=true
 local Lt=V.require('InteriorRooms').layouts()[C.id]
 for cy=0,C.ch-1 do for cx=0,C.cw-1 do
  if C.at(cx,cy)=='.'then
   local i=(cy*C.cw+cx)*2
   local want=tonumber(Lt.check:sub(i+1,i+2),16)
   local t=C.tile(cx*2,cy*2)
   if t and want and t~=want then
    local L=F(cx*CS+8,0,cy*CS+8,0)
    L.box(-8,0,-1.4,-6,28,1.4,'lgObsidian',1);L.box(6,0,-1.4,8,28,1.4,'lgObsidian',1)
    for k=0,4 do L.raw({-6,3+k*5,0},{6,3+k*5,0},{6,4.2+k*5,0},{-6,4.2+k*5,0},'lgLava',1)end
    C.fx.fires[#C.fx.fires+1]={x=cx*CS+8,y=0,z=cy*CS+8,s=.5,col='warm'}
   end
  end
 end end
 -- braziers in the room corners
 for _,p in ipairs({{2,2},{12,2},{18,8},{2,16},{12,16},{18,15}})do
  if C.at(p[1],p[2])=='.'and C.at(p[1]-1,p[2])~='.'then
   local L=F(p[1]*CS+3,0,p[2]*CS+3,0)
   L.cyl(0,0,8,0,1.6,1,'lgObsidian',8,false);L.cyl(0,8,10,0,3.6,2.6,'lgObsidian',10,'lgLava')
   C.fx.fires[#C.fx.fires+1]={x=p[1]*CS+3,y=10,z=p[2]*CS+3,s=.8}
   C.addLight(p[1]*CS+3,16,p[2]*CS+3,70,.4)
  end
 end
 statues(C,F,{stone='ktBasalt',base='lgObsidian',top='inLacquer'})
 entrance(C,{view=2,frame='lgObsidian',leaf='inSteel',mat='inRugRed'})
 C.fx.embers=C.fx.embers or{}
 C.fx.embers[#C.fx.embers+1]={x=W/2,y=0,z=D/2,r=W*.45,n=40,rise=40}
 C.fx.ambience={fire=.35,hum=.1}
end

------------------------------------------------------------------ VIRIDIAN
function M.viridian(C)
 fxInit(C)
 local H=64;C.H=H;C.ambient=.74;C.maxLight=1.5
 local W,D=C.cw*CS,C.ch*CS
 local solid=function(cx,cy)return cy==0 and C.is(cx,cy,'W')end
 local mazeWall=function(cx,cy)return C.is(cx,cy,'KHGBW')and not solid(cx,cy)end
 local S=K.shell(C,{H=H,solid=solid,blocked=function(cx,cy)return mazeWall(cx,cy)or C.is(cx,cy,'Y')end,door=Town.doorFn(C),
  paint='lgSlate',upper='lgSlate',wainscot='ktBasalt',wainscotH=16,rail='lgGold',skirting='lgGold',cornice='lgGold',cap='ktBasalt',
  floor='lgPaveDark',ceiling='ktBasalt'})
 local R=C.part('room')
 local function F(x,y,z,yaw)return K.frame(C,R,x,y,z,yaw)end
 -- the maze's low walls: black granite with a gold cap
 local hW=15
 for cy=0,C.ch-1 do for cx=0,C.cw-1 do
  if mazeWall(cx,cy)then
   local x0,x1,z0,z1=cx*CS,(cx+1)*CS,cy*CS,(cy+1)*CS
   local L=F(0,0,0,0)
   -- thin where the drawing is a fence line; posts (K) stay square
   local post=C.at(cx,cy)=='K'
   local n=mazeWall(cx,cy-1);local s=mazeWall(cx,cy+1);local w=mazeWall(cx-1,cy);local e=mazeWall(cx+1,cy)
   local a0,a1,b0,b1=x0+3,x1-3,z0+3,z1-3
   if w then a0=x0 end;if e then a1=x1 end;if n then b0=z0 end;if s then b1=z1 end
   if not(w or e or n or s)then a0,a1,b0,b1=x0+2,x1-2,z0+2,z1-2 end
   L.box(a0,0,b0,a1,hW,b1,'lgGranite',.85)
   L.box(a0-.4,hW,b0-.4,a1+.4,hW+1.2,b1+.4,'lgGold',1.08)
   if post then L.box(x0+4.6,hW+1.2,z0+4.6,x1-4.6,hW+3,z1-4.6,'lgGold',1.15)end
  end
 end end
 -- the spinners: glowing arrows set in the floor; the stops: square pads
 local dirs={['<']={-1,0},['>']={1,0},y={0,1},a={0,-1}}
 local E=C.part('spinners')
 for cy=0,C.ch-1 do for cx=0,C.cw-1 do
  local c=C.at(cx,cy)
  local d=dirs[c]
  local x,z=cx*CS+8,cy*CS+8
  if d then
   local L=K.frame(C,E,x,0,z,math.atan2(d[1],d[2]))
   L.box(-7,0,-7,7,.25,7,'inSteel',1.05)
   for k=0,1 do
    local o=-3.6+k*6.2
    L.raw({-4.6,.3,o-1.4},{4.6,.3,o-1.4},{0,.3,o+3},{0,.3,o+3},'inLamp',2)
    L.raw({-2.6,.31,o-1.4},{2.6,.31,o-1.4},{0,.31,o+1},{0,.31,o+1},'ktBasalt',1)
   end
   C.fx.pools[#C.fx.pools+1]={x=x,y=.5,z=z,r=7,a=.05,col={.5,.85,1}}
  elseif c=='x'then
   local L=K.frame(C,E,x,0,z,0)
   L.box(-7,0,-7,7,.25,7,'lgGold',1.0)
   for _,q in ipairs({{-3.4,-3.4},{3.4,-3.4},{-3.4,3.4},{3.4,3.4}})do L.box(q[1]-2,.25,q[2]-2,q[1]+2,.45,q[2]+2,'lgObsidian',1)end
  end
 end end
 -- the leader's corner: a heavy desk and a great earth-green banner
 do
  local Ln=K.onWall(C,'N',0,0)
  Ln.box(14,18,0,62,58,.8,'lgGold',1.05)
  Ln.box(15.4,19.4,.8,60.6,56.6,1,'lgVerde',.9)
  Ln.disc(38,40,1.1,10,'lgGold',8,nil,1.15)
  Ln.disc(38,40,1.2,7.6,'leaf',8,nil,.9)
  Ln.disc(38,40,1.3,3,'lgGold',8,nil,1.2)
 end
 statues(C,F,{stone='lgObsidian',base='lgGold',top='leaf'})
 entrance(C,{view=5,frame='lgGold',leaf='lgObsidian',mat='inRugGreen'})
 rig(C,H,{{40,40,30,40},{W-60,60,W-50,60},{W/2,D-80,W/2,D-60}},{1,.95,.82})
 C.addLight(W/2,40,D/2,260,.12)
 C.fx.ambience={hall=.12,hum=.06}
end

return M
