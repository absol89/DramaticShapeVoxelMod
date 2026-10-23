-- TEST174: THE S.S. ANNE (InteriorRooms): the 1F, 2F, 3F and B1F decks,
-- the cabins, the galley, the captain's cabin and the bow.
-- Polished deck boards with a red runner down every passage, walnut
-- panelling under cream paint and a brass rail, portholes on the sea,
-- brass sconces, the cabin doors with their numbers. The cabins: a berth
-- with its blanket, a table, a stool or a palm, a rug, a lamp. The crew
-- deck below is riveted steel and pipes. The galley: tiled walls, steel
-- tables laid with plates, the ranges with their pots, the bins. The
-- captain's cabin: the desk and the log, the radio set, the books, the
-- wheel on the wall. The bow: the deck in the open, white bulwarks and
-- rails, vents and bollards, the superstructure's white walls and its
-- funnel, and the sea all round.
-- Every model stands on a cell the game blocks; the walkable floor is flat.
local V=...
local M={}
local K=V.require('InteriorKit')
local Town=V.require('InteriorTown')
local pi,cos,sin,floor,min,max,abs,sqrt=math.pi,math.cos,math.sin,math.floor,math.min,math.max,math.abs,math.sqrt
local rh=K.rh
local CS=16
local groups,cellsOf=Town.groups,Town.cellsOf
local LA=function()return V.require('LeagueArchitecture').kit end

function M.support(id,ch)return 0 end

local function runFrame(C,run)
 local ox,oz,yaw
 if run.o=='S'then ox,oz,yaw=run.a0,run.c,0
 elseif run.o=='N'then ox,oz,yaw=run.a1,run.c,pi
 elseif run.o=='E'then ox,oz,yaw=run.c,run.a1,pi/2
 else ox,oz,yaw=run.c,run.a0,-pi/2 end
 return K.frame(C,run.E,ox,0,oz,yaw)
end
-- the solid cell behind a run's face at local x
local function cellBehind(run,x)
 if run.o=='S'then return floor((run.a0+x)/CS),floor(run.c/CS)-1
 elseif run.o=='N'then return floor((run.a1-x)/CS),floor(run.c/CS)
 elseif run.o=='E'then return floor(run.c/CS)-1,floor((run.a1-x)/CS)
 else return floor(run.c/CS),floor((run.a0+x)/CS)end
end

------------------------------------------------------------------ pieces
local function sconce(C,Lf,x,y)
 Lf.box(x-1.2,y-2,0,x+1.2,y+2,.6,'lgBronze',1.1)
 Lf.rod({x,y,.6},{x,y+1.2,2.6},.25,'lgBronze')
 Lf.cyl(x,y+.8,y+4,2.6,1.7,1.0,'inLamp',8,false)
 local p=Lf.P({x,y+2.4,2.6})
 C.fx.glows[#C.fx.glows+1]={x=p[1],y=p[2],z=p[3],r=6,col='warm',a=.22}
 C.addLight(p[1],p[2],p[3],40,.16)
end
-- a cabin door at the back of its notch (facing +z): panels, a number,
-- a brass handle, a little round light
local function door(C,F,cx,cy,num,steel)
 local L=F(cx*CS+8,0,cy*CS,0)
 local leaf=steel and'ktSteel'or'inWalnut'
 L.box(-7.6,0,0,7.6,36,1,leaf,1)
 L.box(-8.4,0,0,-7.6,38,1.6,steel and'inSteel'or'lgBronze',1.05);L.box(7.6,0,0,8.4,38,1.6,steel and'inSteel'or'lgBronze',1.05)
 L.box(-8.4,36,0,8.4,38,1.6,steel and'inSteel'or'lgBronze',1.05)
 if not steel then
  L.box(-5.6,4,1,5.6,15,1.3,'inWalnut',1.1);L.box(-5.6,18,1,5.6,32,1.3,'inWalnut',1.1)
 else
  for k=0,4 do L.disc(-6.6,4+k*7.6,1.05,.35,'inSteel',5);L.disc(6.6,4+k*7.6,1.05,.35,'inSteel',5)end
 end
 L.ring(0,26,1.35,2,2.8,steel and'inSteel'or'lgBronze',12,1.1)
 L.raw({-2,24,1.32},{2,24,1.32},{2,28,1.32},{-2,28,1.32},'inWindow',10)
 L.box(4.4,15,1.3,6.2,16.4,2.6,'lgGold',1.15)
 if num then
  L.box(-2.4,33,1.3,2.4,35.4,1.5,'lgGold',1.1)
  LA().inscription(L,tostring(num),0,33.4,1.55,.55,'dark',4)
 end
end
-- a berth: the frame, the mattress, the pillow, a folded blanket
local function berth(C,F,cx,cy,len,cloth)
 local x,z0,z1=cx*CS+8,cy*CS+1.5,(cy+len)*CS-1.5
 local L=F(x,0,(z0+z1)/2,0)
 local hd=(z1-z0)/2
 L.box(-7,0,-hd,7,6,hd,'inWalnut',1)
 L.box(-6.6,6,-hd+.4,6.6,8.4,hd-.4,'cream',1.12)
 L.box(-5.6,8.4,-hd+.8,5.6,10,-hd+5,'white',1.18)
 L.box(-6.8,7.6,-hd+6,6.8,8.8,hd-.2,cloth or'inRugBlue',1.0)
 L.box(-7,6,-hd-.6,7,17,-hd+.4,'inWalnut',1.04)
 L.box(-7.4,17,-hd-.8,7.4,18,-hd+.6,'inWalnut',1.1)
end

------------------------------------------------------------------ decks
-- corridors, cabins, galley, captain's cabin (one builder; the map says
-- which finishes)
function M.ship(C)
 local id=C.id
 local cabin=id:match('_ROOMS$')~=nil
 local galley=id=='SS_ANNE_KITCHEN'
 local captain=id=='SS_ANNE_CAPTAINS_ROOM'
 local crew=id=='SS_ANNE_B1F'or id=='SS_ANNE_B1F_ROOMS'
 local H=(cabin or captain)and 44 or 48;C.H=H
 C.ambient=.78;C.maxLight=1.45
 local W,D=C.cw*CS,C.ch*CS
 local function solid(cx,cy)return C.is(cx,cy,'WVwH')end
 local blocked=function(cx,cy)local c=C.at(cx,cy);return c~=nil and not('.d^vs'):find(c,1,true)end
 -- the finishes
 local paint,wain,rail,fl
 if galley then paint,wain,rail,fl='inTile','ktSteel','inSteel','inTile'
 elseif crew then paint,wain,rail,fl='ktPearl','ktSteel','inSteel','inPine'
 elseif cabin then paint,wain,rail,fl='inPaperBlue','inWalnut','lgBronze','inParquet'
 else paint,wain,rail,fl='cream','inWalnut','lgBronze','inOak' end
 -- exits: the gangway north (1F), the cabins' doormats south (raw 12)
 local function exitCell(ox,oy)
  if not(ox and oy and ox>=0 and oy>=0 and ox<C.cw and oy<C.ch)then return false end
  return C.raw(ox,oy)==12
 end
 local S=K.shell(C,{H=H,solid=solid,blocked=blocked,
  door=function(cx,cy,ox,oy)
   if not ox then return false end
   local off=cx<0 or cy<0 or cx>=C.cw or cy>=C.ch
   -- the hull's real ways out: the gangway (1F), the passage to the bow (3F)
   if off and C.is(ox,oy,'.')and(id=='SS_ANNE_1F'or id=='SS_ANNE_3F')then return true end
   return exitCell(ox,oy)and(off or C.is(cx,cy,'V'))
  end,
  paint=paint,upper=paint,wainscot=wain,wainscotH=galley and 12 or 16,rail=rail,skirting=wain,cornice=crew and'ktSteel'or'white',
  cap=crew and'ktSteel'or'inWalnut',floor=fl,ceiling=crew and'ktSteel'or'white',
  capWhere=function(cx,cy)return C.is(cx,cy,'Ww')end,
  style=function(L,len,run)
   if run.o=='N'then return end
   local Lf=runFrame(C,run)
   -- portholes where the wall is a porthole cell; sconces between
   local lastLamp=-99
   for x=8,len-8,16 do
    local bx,by=cellBehind(run,x)
    if C.at(bx,by)=='w'then
     K.porthole(C,Lf,x,crew and 30 or 31,4.2,{view=2,frame=crew and'inSteel'or'lgBronze'})
    elseif x-lastLamp>=40 and not galley then
     sconce(C,Lf,x,26);lastLamp=x
    end
   end
   if crew then
    -- pipes along the top, rivet rows
    Lf.rod({0,H-6,2.2},{len,H-6,2.2},1.0,'ktSteel')
    Lf.rod({0,H-9,2.6},{len,H-9,2.6},.7,'dnRust')
    for x=4,len-2,8 do Lf.disc(x,17.6,.25,.35,'inSteel',5)end
   end
  end,ao=10})
 local R=C.part('room')
 local function F(x,y,z,yaw)return K.frame(C,R,x,y,z,yaw)end
 -- the red runner down the passages (deck-board cells, not the edges)
 if not(cabin or galley or captain or crew)then
  local E=C.part('floor')
  local L=K.frame(C,E,0,.07,0,0)
  for cy=0,C.ch-1 do for cx=0,C.cw-1 do
   if C.raw(cx,cy)==2 and C.is(cx,cy,'.')then
    local x0,z0=cx*CS,cy*CS
    L.quad({x0,0,z0},{x0+CS,0,z0},{x0+CS,0,z0+CS},{x0,0,z0+CS},'inRugRed',.95)
    -- a gold edge where the runner ends
    for _,d in ipairs({{0,-1},{0,1},{-1,0},{1,0}})do
     local nx,ny=cx+d[1],cy+d[2]
     if not(C.raw(nx,ny)==2 and C.is(nx,ny,'.'))then
      local a={x0+(d[1]==1 and CS-1.2 or 0),z0+(d[2]==1 and CS-1.2 or 0)}
      local b={d[1]==0 and x0+CS or a[1]+1.2,d[2]==0 and z0+CS or a[2]+1.2}
      L.quad({a[1],.01,a[2]},{b[1],.01,a[2]},{b[1],.01,b[2]},{a[1],.01,b[2]},'lgGold',.85)
     end
    end
   end
  end end
 end
 -- doors at the back of their notches (the ones the eye can see)
 local num=1
 for _,c in ipairs(cellsOf(C,'d'))do
  if c[2]==0 or solid(c[1],c[2]-1)then door(C,F,c[1],c[2],cabin and nil or num,crew);num=num+1 end
 end
 -- stairs
 for _,c in ipairs(cellsOf(C,'^'))do
  local x0,z0=c[1]*CS,c[2]*CS
  K.stairsUp(C,R,x0,x0+CS,z0,z0+CS,{tread=crew and'ktSteel'or'inOak',riser=crew and'inSteel'or'white',rail=crew and'inSteel'or'lgBronze',side=x0+1,n=4,top=14})
 end
 for _,c in ipairs(cellsOf(C,'v'))do
  local x0,z0=c[1]*CS,c[2]*CS
  K.stairsDown(C,R,x0,x0+CS,z0,z0+CS,{tread='inOak',riser='white',wall=paint,rail='lgBronze',handrail='inWalnut',nosing='lgBronze',railX=x0+.6})
 end
 -- the cabins: berths (a head cell, then down), tables, stools and palms
 for _,c in ipairs(cellsOf(C,'b'))do
  local r=C.raw(c[1],c[2])
  if r==14 then
   local len=C.is(c[1],c[2]+1,'b')and 2 or 1
   berth(C,F,c[1],c[2],len,({'inRugBlue','inRugRed','inRugGreen','inRugGold'})[(c[1]+c[2])%4+1])
  end
 end
 if cabin or captain then
  for _,g in ipairs(groups(C,'T'))do
   if not captain then
    local x0,x1,z0,z1=g.x0*CS,(g.x1+1)*CS,g.y0*CS,(g.y1+1)*CS
    local L=F((x0+x1)/2,0,(z0+z1)/2,0)
    K.table(L,x1-x0-3,z1-z0-3,10,'dining',{wood='inWalnut',cloth='white'})
    local Lt=F((x0+x1)/2,10.1,(z0+z1)/2,0)
    Lt.cyl(-4,0,.3,0,1.8,1.8,'white',8);Lt.cyl(-4,.3,1.2,0,.9,.7,'white',6)
    Lt.cyl(4,0,4,0,.7,.5,'ktGlass',6);Lt.sphere(4,4.6,0,.7,.7,.7,'flower',5,3)
    K.lamp(C,F((x0+x1)/2+1,10.1,(z0+z1)/2-2,0),'table',{metal='lgBronze',k=.2})
   end
  end
  for _,c in ipairs(cellsOf(C,'O'))do
   K.plant(F(c[1]*CS+8,0,c[2]*CS+8,0),'palm',{s=.9,pot='lgBronze',seed=c[1]*3+c[2]})
  end
  -- a rug in each cabin's middle
  if cabin then
   for _,g in ipairs(groups(C,'.dsTbO^v')) do
    if (g.x1-g.x0)<=5 and (g.y1-g.y0)<=6 then
     K.rug(C,C.part('floor'),g.x0*CS+10,g.y0*CS+22,(g.x1+1)*CS-10,(g.y1+1)*CS-22,{field=crew and'inRugGreen'or'inRugRed',border='inRugGold',pattern='oval'})
    end
   end
  end
 end
 -- the galley
 if galley then
  C.fx.mist=C.fx.mist or{}
  local L=F(0,0,0,0)
  for i,g in ipairs(groups(C,'T'))do
   local x0,x1,z0,z1=g.x0*CS,(g.x1+1)*CS,g.y0*CS,(g.y1+1)*CS
   L.box(x0+1.4,0,z0+1.4,x1-1.4,12,z1-1.4,'inSteel',.95)
   L.box(x0+1,12,z0+1,x1-1,13.2,z1-1,'ktSteel',1.08)
   L.box(x0+1.4,3,z0+1.4,x1-1.4,3.8,z1-1.4,'ktSteel',.9)
   for cy=g.y0,g.y1 do
    for k=0,1 do
     local px,pz=x0+8+k*16,cy*CS+8
     local r=C.raw(g.x0+k,cy)
     if r>=31 and r<=34 or rh(px,pz,1)<.4 then
      L.cyl(px,13.2,13.6,pz,3.4,3.6,'white',10);L.cyl(px,13.6,13.7,pz,2.2,2.2,'cream',8)
      if rh(px,pz,2)<.5 then L.sphere(px,14.6,pz,1.6,1.0,1.6,({'red','gold','leaf','ktOchre'})[i%4+1],6,3)end
     else
      L.cyl(px,13.2,18,pz,2.6,2.6,'inSteel',10,'ktSteel');L.rod({px+2.6,16,pz},{px+5,16.4,pz},.3,'ktSteel')
     end
    end
   end
  end
  -- the ranges along the south wall: burners, pots, steam
  for _,c in ipairs(cellsOf(C,'K'))do
   if not C.is(c[1],c[2]-1,'K')then
    local x0,z0=c[1]*CS,c[2]*CS
    L.box(x0,0,z0+1,x0+CS,14,z0+2*CS,'inSteel',.95)
    L.box(x0-.2,14,z0+.6,x0+CS+.2,15,z0+2*CS,'ktSteel',1.05)
    L.box(x0+1,3,z0+.7,x0+CS-1,11,z0+1,'dark',.7)
    for k=0,1 do
     local bx=x0+5+k*6;local bz=z0+9
     L.disc(bx,15.05,bz,2.2,'dark',10,'y');L.ring(bx,15.1,bz,1,1.5,'red',10,1.2)
    end
    if rh(c[1],c[2],5)<.6 then
     local px=x0+5+floor(rh(c[1],c[2],6)*2)*6
     L.cyl(px,15,21,z0+9,3,3,'inSteel',10,'ktSteel');L.box(px-4.6,20,z0+8.6,px-3,20.6,z0+9.4,'dark',.8)
     C.fx.mist[#C.fx.mist+1]={x=px,y=24,z=z0+9,r=7,phase=c[1]*.7,drift=2,col={1,1,1},a=.10}
    end
   end
  end
  for _,c in ipairs(cellsOf(C,'c'))do
   local Lb=F(c[1]*CS+8,0,c[2]*CS+8,0)
   Lb.cyl(0,0,12,0,4.4,5,'inSteel',10,false);Lb.cyl(0,12,13,0,5.2,5.2,'ktSteel',10)
   Lb.rod({-1.6,13,0},{1.6,13,0},.5,'ktSteel')
  end
  -- pans on the north wall, a shelf of jars
  local Ln=K.onWall(C,'N',0,0)
  K.wallShelf(Ln,140,200,30,{wood='inSteel',items='jars',seed=4})
  Ln.rod({16,40,1.2},{88,40,1.2},.5,'inSteel')
  for k=0,5 do local x=22+k*12;Ln.rod({x,40,1.2},{x,35,1.2},.12,'inSteel');Ln.disc(x,31,1.6,3+(k%2),k%2==0 and'ktCopper'or'inSteel',10)end
 end
 -- the captain's cabin
 if captain then
  local L=F(0,0,0,0)
  for _,g in ipairs(groups(C,'T'))do
   local x0,x1,z0,z1=g.x0*CS,(g.x1+1)*CS,g.y0*CS,(g.y1+1)*CS
   local Ld=F((x0+x1)/2,0,(z0+z1)/2,0)
   K.table(Ld,x1-x0-3,z1-z0-4,12,'desk',{wood='inWalnut'})
   local Lb=F((x0+x1)/2-6,12,(z0+z1)/2,.2)
   Lb.box(-4.6,0,-3,0,.5,3,'inLeather',1);Lb.box(0,0,-3,4.6,.5,3,'inLeather',1)
   Lb.quad({-4.2,.52,-2.6},{-.2,.62,-2.6},{-.2,.62,2.6},{-4.2,.52,2.6},'cream',1.15)
   Lb.quad({.2,.62,-2.6},{4.2,.52,-2.6},{4.2,.52,2.6},{.2,.62,2.6},'cream',1.12)
   for i=0,4 do Lb.quad({-3.8,.64,-2+i},{-.8,.64,-2+i},{-.8,.64,-1.6+i},{-3.8,.64,-1.6+i},'dark',.6)end
   K.lamp(C,F((x0+x1)/2+10,12,(z0+z1)/2-4,0),'table',{metal='lgBronze',base='inLeather',k=.24})
   local Lg=F((x0+x1)/2+3,12,(z0+z1)/2+3,0)
   Lg.cyl(0,0,1,0,1.6,1.4,'lgBronze',8);Lg.rod({0,1,0},{0,3,0},.25,'lgBronze');Lg.sphere(0,5.4,0,2.6,2.6,2.6,'ktMarine',8,5)
  end
  for _,c in ipairs(cellsOf(C,'R'))do
   local Lr=F(c[1]*CS+8,0,c[2]*CS+8,0)
   Lr.box(-7,0,-7,7,14,6,'inWalnut',1)
   Lr.box(-6.6,14,-6,6.6,26,4,'ktSteel',.9)
   Lr.raw({-5,17,4.05},{0,17,4.05},{0,23,4.05},{-5,23,4.05},'inScreen',3)
   for k=0,2 do Lr.disc(3,16+k*3.6,4.05,1.1,'dark',10);Lr.disc(3,16+k*3.6,4.1,.4,'lgGold',6)end
   Lr.rod({0,26,0},{2,40,-2},.2,'inSteel')
   C.fx.glows[#C.fx.glows+1]={x=c[1]*CS+5,y=20,z=c[2]*CS+13,r=5,col='green',a=.16}
  end
  for _,c in ipairs(cellsOf(C,'B'))do
   K.bookcase(F(c[1]*CS+8,0,c[2]*CS+8,0),14,34,12,{wood='inWalnut',items='books',seed=c[1]})
  end
  for _,c in ipairs(cellsOf(C,'c'))do
   local Lb=F(c[1]*CS+8,0,c[2]*CS+8,0)
   Lb.cyl(0,0,9,0,3.4,3.8,'inWalnut',10,false);Lb.cyl(0,9,9.6,0,3.9,3.9,'lgBronze',10)
  end
  local Lw=K.onWall(C,'W',0,0)
  Town.WALLS.wheel(C,Town.THEMES.VERMILION,Lw,(S.s-S.n)*.55)
  local Le=K.onWall(C,'E',0,0)
  Town.WALLS.map(C,Town.THEMES.VERMILION,Le,(S.s-S.n)*.6)
  K.clock(C,Le,(S.s-S.n)*.3,34,3.2,{case='lgBronze'})
  K.rug(C,C.part('floor'),18,40,78,100,{field='inRugBlue',border='inRugGold',pattern='medallion',fringe='cream'})
 end
 -- the ways out through the hull: the gangway to the dock (1F), the
 -- passage onto the bow (3F)
 for cx=0,C.cw-1 do
  if id=='SS_ANNE_1F'and C.is(cx,0,'.')and not C.is(cx-1,0,'.')then
   local x1=cx
   while C.is(x1+1,0,'.')do x1=x1+1 end
   K.exitPortal(C,'N',cx*CS,(x1+1)*CS,{view=2,frame='lgBronze'})
  end
 end
 for cy=0,C.ch-1 do
  if id=='SS_ANNE_3F'and C.is(0,cy,'.')and not C.is(0,cy-1,'.')then
   local y1=cy
   while C.is(0,y1+1,'.')do y1=y1+1 end
   K.exitPortal(C,'W',cy*CS,(y1+1)*CS,{view=2,frame='lgBronze'})
  end
 end
 -- doormats where the cabins open onto the passage
 do
  local E=C.part('floor')
  for cy=0,C.ch-1 do for cx=0,C.cw-1 do
   if C.raw(cx,cy)==12 and C.is(cx,cy,'.')then
    K.rug(C,E,cx*CS+1,cy*CS+3,(cx+1)*CS-1,(cy+1)*CS-1,{field='navy',border='inRugGold',bw=1,y=.1})
   end
  end end
 end
 -- light from the ceiling
 for x=32,W-16,64 do for z=24,D-8,48 do
  if not solid(floor(x/CS),floor(z/CS))then C.addLight(x,H-8,z,60,.10)end
 end end
 C.fx.ambience=crew and{hum=.22,wind=.06}or{room=.20,hum=.08,wind=.06}
end

------------------------------------------------------------------ the bow
function M.bow(C)
 local H=40;C.H=H
 C.ambient=.98;C.maxLight=1.55
 local W,D=C.cw*CS,C.ch*CS
 -- the deckhouse wall's column: everything east of it is superstructure
 local wx=C.cw
 for cy=0,C.ch-1 do for cx=0,C.cw-1 do if C.is(cx,cy,'W')then wx=min(wx,cx)end end end
 local function solid(cx,cy)return C.is(cx,cy,'W')or(C.is(cx,cy,'V')and cx>=wx)end
 local function sea(cx,cy)
  if cx<0 or cy<0 or cx>=C.cw or cy>=C.ch then return true end
  return C.is(cx,cy,'S')or(C.is(cx,cy,'V')and cx<wx)
 end
 local open=function(cx,cy)return C.is(cx,cy,'.^v')end
 local blocked=function(cx,cy)return not open(cx,cy)end
 local S=K.shell(C,{H=H,solid=solid,blocked=blocked,paint='white',upper='white',wainscot='ktPearl',wainscotH=8,
  rail='inWalnut',skirting='ktPearl',cornice='white',cap='ktPearl',floor='inOak',ceiling=false,outside=false,
  nofloor=function(cx,cy)return sea(cx,cy)end,
  style=function(L,len,run)
   if run.o=='N'then return end
   local Lf=runFrame(C,run)
   for x=10,len-6,20 do K.porthole(C,Lf,x,26,3.8,{view=2,frame='lgBronze'})end
   Lf.ring(len*.5,16,1.4,3.2,4.6,'red',16,1.05)
  end,ao=8})
 local R=C.part('room')
 local L=K.frame(C,R,0,0,0,0)
 -- the sea: a plane far out, glints over it
 do
  local E=C.part('sea')
  local Ls=K.frame(C,E,0,0,0,0)
  local y=-22
  for x=-480,W+480,160 do for z=-480,D+480,160 do
   Ls.quad({x,y,z},{x+160,y,z},{x+160,y,z+160},{x,y,z+160},'ktMarine',.85)
  end end
  C.fx.water={}
  for x=-240,W+240,120 do for z=-240,D+240,120 do
   C.fx.water[#C.fx.water+1]={x=x,y=y+.4,z=z,r=60}
  end end
 end
 -- the bulwarks and rails round the deck; the hull falling to the sea
 for cy=0,C.ch-1 do for cx=0,C.cw-1 do
  if C.is(cx,cy,'H')then
   local x0,z0=cx*CS,cy*CS
   L.box(x0+1,0,z0+1,x0+CS-1,7,z0+CS-1,'white',1)
   L.box(x0,7,z0,x0+CS,8,z0+CS,'inWalnut',1.05)
   for k=0,1 do L.box(x0+4+k*8-.4,8,z0+7.6,x0+4+k*8+.4,15,z0+8.4,'white',1.05)end
   L.box(x0,15,z0+7.3,x0+CS,16.2,z0+8.7,'inWalnut',1.08)
   -- the hull below, where the sea is beside it
   for _,d in ipairs({{0,-1},{0,1},{-1,0},{1,0}})do
    if sea(cx+d[1],cy+d[2])then
     local ax,az,bx,bz
     if d[2]==-1 then ax,az,bx,bz=x0,z0,x0+CS,z0
     elseif d[2]==1 then ax,az,bx,bz=x0+CS,z0+CS,x0,z0+CS
     elseif d[1]==-1 then ax,az,bx,bz=x0,z0+CS,x0,z0
     else ax,az,bx,bz=x0+CS,z0,x0+CS,z0+CS end
     L.quad({ax,0,az},{bx,0,bz},{bx,-10,bz},{ax,-10,az},'white',.9)
     L.quad({ax,-10,az},{bx,-10,bz},{bx,-14,bz},{ax,-14,az},'navy',.9)
     L.quad({ax,-14,az},{bx,-14,bz},{bx,-22,bz},{ax,-22,az},'red',.7)
    end
   end
  end
 end end
 -- the deck's furniture: vents and bollards on the blocked deck cells
 for _,c in ipairs(cellsOf(C,'L'))do
  local x,z=c[1]*CS+8,c[2]*CS+8
  if C.raw(c[1],c[2])==43 and rh(c[1],c[2],1)<2 then
   L.cyl(x,0,1,z,4,4,'ktBasalt',10)
   L.cyl(x-2,1,6,z,1.4,1.4,'ktBasalt',8);L.cyl(x+2,1,6,z,1.4,1.4,'ktBasalt',8)
   L.cyl(x-2,6,6.8,z,1.9,1.9,'ktBasalt',8);L.cyl(x+2,6,6.8,z,1.9,1.9,'ktBasalt',8)
  end
 end
 -- a coil of rope, a life ring, a flagstaff at the stem
 local stem
 for cy=0,C.ch-1 do for cx=0,C.cw-1 do
  if open(cx,cy)and(not stem or cx<stem[1])then stem={cx,cy}end
 end end
 if stem then
  local x,z=stem[1]*CS-6,stem[2]*CS+8
  L.cyl(x,0,1,z,1.6,1.6,'lgBronze',8)
  L.rod({x,1,z},{x,44,z},.5,'white')
  L.quad({x,43,z},{x+12,41,z},{x+12,34,z},{x,35,z},'red',1)
  L.quad({x+.1,36.6,z+.05},{x+12,35,z+.05},{x+12,38.6,z+.05},{x+.1,40,z+.05},'white',1.1)
 end
 -- the superstructure behind the deckhouse wall: a second tier and the funnel
 do
  local x0=W
  for cy=0,C.ch-1 do for cx=0,C.cw-1 do if C.is(cx,cy,'W')then x0=min(x0,cx*CS)end end end
  local Ls=K.frame(C,C.part('room'),0,0,0,0)
  Ls.box(x0+24,H,48,W,H+26,D-48,'white',1)
  for z=60,D-60,18 do Ls.raw({x0+23.9,H+10,z},{x0+23.9,H+10,z+10},{x0+23.9,H+18,z+10},{x0+23.9,H+18,z},'inWindow',2)end
  Ls.box(x0+20,H+26,40,W,H+28,D-40,'inWalnut',1)
  Ls.cyl(W-40,H+28,H+64,D/2,14,12,'white',14,'dark')
  Ls.cyl(W-40,H+50,H+58,D/2,12.6,12.4,'red',14,false)
  C.fx.smoke=C.fx.smoke or{}
  C.fx.smoke[#C.fx.smoke+1]={x=W-40,y=H+66,z=D/2,h=60,s=6,speed=.08,col={.85,.85,.88},a=.18}
 end
 C.addLight(W*.4,80,D*.4,500,.25)
 C.fx.ambience={wind=.45}
end

return M
