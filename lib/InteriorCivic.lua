-- TEST173: the towns' other rooms (InteriorRooms): the Pewter Museum, the
-- Cerulean Bike Shop, the Celadon Diner, the Celadon Department Store and
-- its elevator, Celadon Mansion and the chief's house, the Cinnabar Lab and
-- its rooms, the Safari offices, the Warden's house, the Fighting Dojo,
-- Bill's cottage, the Pokemon Fan Club and the two ship-built houses.
-- One generic builder reads the common pieces of a plan (walls, partitions,
-- tables and seats, desks, shelves, counters, plants, machines, stairs);
-- each room adds what makes it itself.
local V=...
local M={}
local K=V.require('InteriorKit')
local Town=V.require('InteriorTown')
local pi,cos,sin,floor,min,max,abs,sqrt=math.pi,math.cos,math.sin,math.floor,math.min,math.max,math.abs,math.sqrt
local rh=K.rh
local CS=16
local groups,cellsOf=Town.groups,Town.cellsOf
-- the cells of any of a set of characters
local function cellsIn(C,set)
 local out={}
 for cy=0,C.ch-1 do for cx=0,C.cw-1 do if C.is(cx,cy,set)then out[#out+1]={cx,cy}end end end
 return out
end
local LA=function()return V.require('LeagueArchitecture').kit end

-- seats and tables: the heights actors sit and items stand at
function M.support(id,ch)
 if ch=='s'then return 6 end
 if ch=='T'then return 10 end
 return 0
end

------------------------------------------------------------------ generic
-- St: H, paint, upper, wainscot, rail, floor, ceiling, cap, wood, accent,
-- cloth, plant, view, innerH, walls (chars that are outer wall), inner
-- (chars that are partitions), walk (chars that are walkable), and hooks
local function generic(C,St)
 local H=St.H or 52;C.H=H
 C.ambient=St.ambient or .80;C.maxLight=1.45
 local wallSet=St.walls or'WV'
 local innerSet=St.inner or'L'
 local walkSet=St.walk or'.ms^vdgf'
 local solid=function(cx,cy)
  if cy==0 and St.topWall~=false and not C.is(cx,cy,walkSet..'E')then return true end
  -- characters that are wall only in the two-row wall band
  if St.band and cy<=1 and C.is(cx,cy,St.band)then return true end
  return C.is(cx,cy,wallSet..innerSet)
 end
 local inner=function(cx,cy)return C.is(cx,cy,innerSet)and cy>0 end
 local blocked=function(cx,cy)local c=C.at(cx,cy);return c~=nil and not walkSet:find(c,1,true)end
 local S=K.shell(C,{H=H,solid=solid,inner=inner,innerH=St.innerH or 40,blocked=blocked,door=Town.doorFn(C,'md'),
  paint=St.paint or'ktPlaster',upper=St.upper,wainscot=St.wainscot,wainscotH=St.wainscotH or 13,beadboard=St.bead,
  rail=St.rail or'white',skirting=St.skirt or St.rail or'white',cornice=St.cornice or'white',cap=St.cap or'ktLime',
  floor=St.floor or'inOak',ceiling=St.ceiling or'white',innerPaint=St.innerPaint,picture=St.picture,
  nofloor=function(cx,cy)return C.at(cx,cy)=='v'end,style=St.style,innerStyle=St.innerStyle})
 local R=C.part('room')
 local function F(x,y,z,yaw)return K.frame(C,R,x,y,z,yaw)end
 C.F=F;C.S=S;C.St=St
 local wood=St.wood or'inOak'
 -- tables and their seats
 local seats=cellsOf(C,'s')
 for _,tb in ipairs(groups(C,'T'))do
  if not(St.skip and St.skip.T)then
   local x0,x1,z0,z1=tb.x0*CS,(tb.x1+1)*CS,tb.y0*CS,(tb.y1+1)*CS
   local L=F((x0+x1)/2,0,(z0+z1)/2,0)
   K.table(L,x1-x0-3,z1-z0-3,10,St.tableStyle or'dining',{wood=wood,cloth=St.cloth})
  end
 end
 if not(St.skip and St.skip.s)then
  for _,c in ipairs(seats)do
   local sx,sz=c[1]*CS+8,c[2]*CS+8
   -- the back away from the nearest table
   local back
   local best=1e9
   for _,tb in ipairs(groups(C,'TD'))do
    local dx,dz=tb.cx-sx,tb.cz-sz
    local d=dx*dx+dz*dz
    if d<best then best=d;if abs(dx)>abs(dz)then back=dx>0 and'w'or'e'else back=dz>0 and'n'or's'end end
   end
   K.seat(F(sx,0,sz,0),6,St.seat or'spindle',back,{wood=wood,cushion=St.cushion or'inRugRed'})
  end
 end
 -- desks with computers (D)
 if not(St.skip and St.skip.D)then
  for _,g in ipairs(groups(C,'D'))do
   local x0,x1,z0,z1=g.x0*CS,(g.x1+1)*CS,g.y0*CS,(g.y1+1)*CS
   local L=F((x0+x1)/2,0,(z0+z1)/2,0)
   K.table(L,x1-x0-2,z1-z0-4,11,'desk',{wood=St.deskWood or wood})
   -- monitors along the desk, papers and a lamp
   local n=max(1,floor((x1-x0)/32+.5))
   for i=0,n-1 do
    local mx=x0+(i+.5)*(x1-x0)/n
    local Lm=F(mx-3,11,(z0+z1)/2-2,0)
    Lm.box(-4,0,-2.4,4,.6,2,'inEnamel',1)
    Lm.box(-3.6,.6,-2,3.6,7.6,1,'inEnamel',1.02)
    Lm.raw({-3,1.2,1.05},{3,1.2,1.05},{3,7,1.05},{-3,7,1.05},'inScreen',1+(i%3))
    Lm.box(-3,0,2.4,3,.4,4.6,'ktPearl',1.1)
    local Lp=F(mx+6,11,(z0+z1)/2,.2);Lp.box(-2,0,-2.6,2,.4,2.6,'cream',1.15)
   end
  end
 end
 -- shelves (B)
 if not(St.skip and St.skip.B)then
  for _,g in ipairs(groups(C,'B'))do
   local x0,x1=g.x0*CS,(g.x1+1)*CS
   local z1=(g.y1+1)*CS
   local d=min(14,(g.y1-g.y0+1)*CS-2)
   K.bookcase(F((x0+x1)/2,0,z1-d/2-1,0),x1-x0-2,St.shelfH or 36,d,{wood=St.shelfWood or wood,items=St.items or'books',doors=St.shelfDoors,glass=St.shelfGlass,seed=g.x0+g.y0})
  end
 end
 -- counters (C)
 if not(St.skip and St.skip.C)then
  local L=F(0,0,0,0)
  local cs=St.counterSet or'C'
  for _,c in ipairs(cellsIn(C,cs))do
   local a0,a1,b0,b1=c[1]*CS,(c[1]+1)*CS,c[2]*CS,(c[2]+1)*CS
   local n=C.is(c[1],c[2]-1,cs);local s=C.is(c[1],c[2]+1,cs)
   local w=C.is(c[1]-1,c[2],cs);local e=C.is(c[1]+1,c[2],cs)
   local ia0,ia1=w and a0 or a0+2,e and a1 or a1-2
   local ib0,ib1=n and b0 or b0+2,s and b1 or b1-2
   L.box(ia0,0,ib0,ia1,13,ib1,St.counter or'inEnamel',1.0)
   L.box(ia0-.4,13,ib0-.4,ia1+.4,14.6,ib1+.4,St.counterTop or'lgMarble',1.06)
   L.box(ia0,0,ib0,ia1,1.2,ib1,'dark',.7)
  end
 end
 -- plants (P): one per pot cell (the lower of a stacked pair)
 for _,g in ipairs(groups(C,'P'))do
  for cx=g.x0,g.x1 do
   local cy=g.y1
   K.plant(F(cx*CS+8,0,cy*CS+8,0),St.plant or'ficus',{s=1.25,pot=St.pot or'ktTerracotta',seed=cx*7+cy})
  end
 end
 -- stairs
 for _,g in ipairs(groups(C,'^'))do
  local z0=g.y0*CS
  if g.y0==0 or C.is(g.x0,g.y0-1,'WLV')or g.y0==1 then z0=max(S.n,z0)end
  K.stairsUp(C,R,g.x0*CS,(g.x1+1)*CS,z0,(g.y1+1)*CS,{tread=St.tread or'inOak',riser='white',rail=St.stairRail or'white',side=g.x0*CS+1,n=4,top=14})
 end
 for _,g in ipairs(groups(C,'v'))do
  K.stairsDown(C,R,g.x0*CS,(g.x1+1)*CS,g.y0*CS,(g.y1+1)*CS,{tread=St.tread or'inOak',riser='white',wall=St.paint,railX=g.x0*CS})
 end
 -- doors in the north wall (d) and the front door (m)
 for _,sp in ipairs(Town.doorSpans(C))do
  K.frontDoor(C,sp[1],sp[2],{view=St.view or 1,frame=St.frame or'white',leaf=St.leaf or wood,
   inside=St.inside,insideFloor=St.insideFloor,insideWall=St.insideWall})
 end
 for _,g in ipairs(groups(C,'d'))do
  if g.y0==0 then K.exitPortal(C,'N',g.x0*CS+1,(g.x1+1)*CS-1,{view=St.view or 1,frame=St.frame or'white'})end
 end
 -- ceiling lights
 if St.lights~=false then
  local E=C.part('ceilfx',{below=H+2})
  local Lc=K.frame(C,E,0,0,0,0)
  for x=S.w+24,S.e-16,St.lightStep or 48 do for z=S.n+24,S.s-16,St.lightStep or 48 do
   if not solid(floor(x/CS),floor(z/CS))then
    Lc.raw({x-6,H-.4,z-6},{x+6,H-.4,z-6},{x+6,H-.4,z+6},{x-6,H-.4,z+6},'inPanel',1)
    C.addLight(x,H-6,z,56,.13)
   end
  end end
 end
 C.fx.ambience=St.ambience or{room=.35}
 return F,S,R
end
M.generic=generic

-- the windows of a room's north wall where the plan has a bare wall band
local function northWindows(C,St,list)
 local Ln=K.onWall(C,'N',0,0)
 for _,x in ipairs(list)do
  K.window(C,Ln,x-10,x+10,18,38,{frame=St.frame or'white',view=St.view or 1,curtain=St.curtain,cloth=St.curtainCloth or'white',panes={2,3},scenic=St.scenic})
 end
 return Ln
end

------------------------------------------------------------------ MUSEUM
-- Pewter Museum of Science: polished stone, the great fossil skeletons in
-- their cases, the amber on its pedestal; upstairs the space shuttle and
-- the moon stone.
local function fossilSkeleton(C,F,cx,cz,kind,w)
 local P=F(cx,0,cz,0)
 P.box(-w/2,0,-11,w/2,10,11,'lgMarble',1)
 P.box(-w/2-.6,10,-11.6,w/2+.6,10.8,11.6,'lgGold',1.05)
 -- a bed of sand and a few stones round the stand
 P.box(-w/2+.4,10.8,-10.6,w/2-.4,11.4,10.6,'ktSandstone',1.1)
 for k=0,4 do P.sphere(-w/2+5+k*(w-10)/4,11.6,-7+rh(k,1,4)*14,1.2+rh(k,2,4),.7,1.1,({'lgRock','ktSandstone','lvSlate'})[k%3+1],6,3,k)end
 local L=K.frame(C,C.part('room'),cx,11.4,cz,0,1.3)
 local y=0
 local bone='cream'
 if kind=='flyer'then
  -- a winged skeleton on a stand, wings spread
  L.rod({0,y,0},{0,y+14,0},.5,'lgBronze')
  for i=0,6 do L.sphere(-6+i*2,y+16+sin(i*.6)*1.4,0,1.1,.9,.9,bone,6,3)end
  L.sphere(9,y+19,0,2.2,1.6,1.3,bone,8,4);L.rod({9,y+19,0},{16,y+17.6,0},.5,bone);L.rod({9,y+20.4,0},{12,y+24,0},.35,bone)
  for _,s in ipairs({-1,1})do
   L.rod({0,y+17,s*.8},{2,y+20,s*9},.4,bone);L.rod({2,y+20,s*9},{-1,y+18,s*17},.3,bone)
   for k=0,3 do L.rod({2-k*1,y+20-k*.5,s*(9+k*2)},{-4-k,y+12+k,s*(8+k*2)},.18,bone)end
  end
  L.rod({-6,y+16,0},{-14,y+13,0},.4,bone)
 else
  -- a scythed swimmer, upright
  L.rod({0,y,0},{0,y+5,0},.5,'lgBronze')
  for i=0,5 do L.sphere(0,y+6+i*2.2,-i*.3,1.4-i*.08,1.1,1.1,bone,6,3)end
  L.sphere(0,y+20,-1,3,2.6,2.6,bone,8,5)
  L.disc(-1.2,y+20.4,1.4,.6,'dark',6);L.disc(1.2,y+20.4,1.4,.6,'dark',6)
  for _,s in ipairs({-1,1})do
   L.rod({s*1.4,y+15,0},{s*6,y+17,2},.4,bone);L.rod({s*6,y+17,2},{s*8,y+23,1},.5,bone)
   L.quad({s*8,y+23,1},{s*9,y+22,1.2},{s*6.4,y+28,1},{s*6.4,y+28,1},bone,1.05)
   for k=0,3 do L.rod({0,y+8+k*2,0},{s*4,y+7+k*2,1.4},.2,bone)end
  end
  L.rod({0,y+6,0},{-3,y+2,-4},.4,bone);L.rod({0,y+6,0},{3,y+2,-4},.4,bone)
 end
end
local function glassCase(C,x0,x1,z0,z1,h)
 -- the case's frame (drawn) and its glass (the effects pass)
 local L=C.F(0,0,0,0)
 for _,x in ipairs({x0,x1-1})do for _,z in ipairs({z0,z1-1})do L.box(x,10,z,x+1,h,z+1,'lgGold',1.05)end end
 L.box(x0,h,z0,x1,h+1,z0+1,'lgGold',1.05);L.box(x0,h,z1-1,x1,h+1,z1,'lgGold',1.05)
 L.box(x0,h,z0+1,x0+1,h+1,z1-1,'lgGold',1.05);L.box(x1-1,h,z0+1,x1,h+1,z1-1,'lgGold',1.05)
 C.fx.glass=C.fx.glass or{}
 C.fx.glass[#C.fx.glass+1]={x0=x0+1,x1=x1-1,y0=10,y1=h,z=z1-.2}
end
function M.museum(C)
 local up=C.id=='MUSEUM_2F'
 local St={H=60,paint='ktSandstone',upper='ktLime',wainscot='lvStone',wainscotH=14,rail='lgGold',cornice='white',cap='ktLime',
  floor='lgMarble',ceiling='white',inner='',counterSet='CL',counter='inWalnut',counterTop='lgMarble',wood='inWalnut',
  plant='ficus',pot='lvStone',view=4,items='books',shelfDoors=true,skip={T=true},ambience={hall=.2},lightStep=56}
 local F,S=generic(C,St)
 -- the fossil cases (F groups)
 for i,g in ipairs(groups(C,'F'))do
  local x0,x1,z0,z1=g.x0*CS,(g.x1+1)*CS,g.y0*CS,(g.y1+1)*CS
  local cx,cz=(x0+x1)/2,(z0+z1)/2+3
  if up then
   -- the moon stone under glass, on a dark velvet plinth
   local L=F(cx,0,cz,0)
   L.box(-(x1-x0)/2+3,0,-8,(x1-x0)/2-3,10,8,'inWalnut',1)
   L.box(-(x1-x0)/2+4,10,-7,(x1-x0)/2-4,11,7,'lgPlum',1)
   L.sphere(0,14,0,3.6,3,3.4,'lgAmethyst',10,6,7)
   C.fx.glows[#C.fx.glows+1]={x=cx,y=15,z=cz,r=10,col='violet',a=.3}
   for k=0,2 do local Lm=F(cx-12+k*12,11,cz+4,0);Lm.sphere(0,1.4,0,1.6,1.2,1.4,({'lvSlate','lgRock','ktBasalt'})[k+1],7,4,k)end
   glassCase(C,x0+3,x1-3,cz-8,cz+8,24)
  else
   fossilSkeleton(C,F,cx,cz,i==1 and'flyer'or'swimmer',x1-x0-6)
   glassCase(C,x0+3,x1-3,cz-11,cz+11,50)
   local L=F(cx,0,cz+11.4,0)
   L.box(-6,4,0,6,8,.4,'lgGold',1.1);L.box(-5,4.6,.4,5,7.4,.5,'dark',.8)
  end
 end
 -- the old amber on its pedestal (A)
 for _,c in ipairs(cellsOf(C,'A'))do
  local L=F(c[1]*CS+8,0,c[2]*CS+8,0)
  L.cyl(0,0,12,0,4,3.4,'lgMarble',12)
  L.cyl(0,12,13,0,4.4,4.4,'lgGold',12)
  L.sphere(0,15.4,0,2.4,2,2.2,'gold',8,5,3)
  C.fx.glows[#C.fx.glows+1]={x=c[1]*CS+8,y=16,z=c[2]*CS+8,r=7,col='gold',a=.3}
 end
 -- the space shuttle (S) on its stand
 for _,g in ipairs(groups(C,'S'))do
  local x0,x1,z0,z1=g.x0*CS,(g.x1+1)*CS,g.y0*CS,(g.y1+1)*CS
  local L=K.frame(C,C.part('room'),(x0+x1)/2,0,(z0+z1)/2-2,0,1.15)
  L.box(-20,0,-10,20,8,12,'lgMarble',1);L.box(-21,8,-11,21,9,13,'lgGold',1.05)
  L.rod({-6,9,0},{-6,16,0},.6,'inSteel');L.rod({8,9,0},{8,16,0},.6,'inSteel')
  -- fuselage, nose, wings, tail, engines
  L.cyl(-18,18,18,0,0,0,'white',1)
  for i=0,9 do local a0,a1=i/10*pi*2,(i+1)/10*pi*2
   L.quad({-14,18+sin(a0)*3.4,cos(a0)*3.4},{14,18+sin(a0)*3.4,cos(a0)*3.4},{14,18+sin(a1)*3.4,cos(a1)*3.4},{-14,18+sin(a1)*3.4,cos(a1)*3.4},sin(a0)<-.3 and'dark'or'inEnamel',1)
   L.quad({14,18+sin(a0)*3.4,cos(a0)*3.4},{20,18,0},{20,18,0},{14,18+sin(a1)*3.4,cos(a1)*3.4},sin(a0)<-.3 and'dark'or'inEnamel',1)
  end
  for _,s in ipairs({-1,1})do L.quad({-12,16.4,s*3},{4,16.4,s*3},{-8,16.4,s*13},{-12,16.4,s*13},'inEnamel',1.02)end
  L.quad({-14,21,0},{-6,21,0},{-11,29,0},{-14,29,0},'inEnamel',1.05)
  for k=0,2 do L.cyl(-14.5,18+(k-1)*2.2,18+(k-1)*2.2,(k-1)*1.6,1,1.4,'ktSteel',8,false)end
  LA().inscription(L,'SPACE',0,1.4,12.1,.6,'navy',20)
  -- brass posts and a red rope in front
  local Lr=F((x0+x1)/2,0,z1+5,0)
  for k=-2,2 do Lr.cyl(k*10,0,1,0,1.6,1.6,'lgGold',10);Lr.cyl(k*10,1,9,0,.45,.45,'lgGold',6);Lr.sphere(k*10,9.6,0,.9,.9,.9,'lgGold',6,4)end
  for k=-2,1 do for j=0,3 do local a,b=k*10+j*2.5,k*10+(j+1)*2.5
   local ya,yb=8.4-sin(j/4*pi)*2.2,8.4-sin((j+1)/4*pi)*2.2
   Lr.rod({a,ya,0},{b,yb,0},.35,'red')end end
 end
 if up then
  -- the planets hung over the hall, the moon's phases on the wall
  -- (along the north wall, where they hide nothing but wall)
  local Lp=F(0,0,0,0)
  local P={{24,'ktOchre',3.6},{44,'lgAmethyst',2.4},{66,'blue',4.2},{88,'ktCopper',2.8},{112,'gold',5.4}}
  for i,p in ipairs(P)do
   local x,z,y=p[1],26+(i%2)*4,C.H-12-(i%3)*3
   if x<C.cw*CS-8 then
    Lp.rod({x,C.H,z},{x,y+p[3],z},.12,'inSteel')
    Lp.sphere(x,y,z,p[3],p[3],p[3],p[2],10,6)
    if i==5 then Lp.ring(x,y,z,p[3]*1.3,p[3]*1.9,'cream',20,1.1)end
   end
  end
  local Lw=K.onWall(C,'W',0,0)
  for k=0,3 do Lw.disc(28+k*14,34,.5,4.4,'dark',16);Lw.disc(28+k*14+(k-1.5)*1.6,34,.6,4.4-abs(k-1.5)*.9,'cream',16,nil,1.15)end
  Lw.box(20,26,0,80,27,.6,'lgGold',1.05)
 else
  -- the dinosaur-age mural over the west wall, an old map on the east
  K.picture(C,K.onWall(C,'W',0,0),24,84,20,44,'mountain',{frame='lgGold'})
 end
 -- the long cabinet wall (B) in the office; a reception desk chair (s) is
 -- handled; the posters (p) on the north wall: fossil prints
 local Ln=K.onWall(C,'N',0,0)
 for _,c in ipairs(cellsOf(C,'p'))do
  K.picture(C,Ln,c[1]*CS-2,c[1]*CS+18,22,40,c[1]%2==0 and'fossil'or'mountain',{frame='lgGold'})
 end
 if not up then
  -- a banner over the hall
  Ln.box(30,42,0,110,54,.8,'lgGold',1.05);Ln.box(31,43,.8,109,53,1,'navy',1)
  LA().inscription(Ln,'MUSEUM',70,45,1,1.5,'lgGold',70)
 else
  Ln.box(10,40,0,90,52,.8,'lgGold',1.05);Ln.box(11,41,.8,89,51,1,'navy',1)
  LA().inscription(Ln,'SPACE',50,43,1,1.5,'lgGold',70)
 end
 C.fx.ambience={hall=.25}
end

------------------------------------------------------------------ BIKE SHOP
-- The Cerulean Bike Shop: bicycles on the floor and hung on the wall, the
-- counter with its till, a work bench, tyres, a price board.
local function bike(L,col,s)
 s=s or 1
 for _,x in ipairs({-6*s,6*s})do
  L.ring(x,4.6*s,0,3.6*s,4.4*s,'dark',18,1)
  L.ring(x,4.6*s,.05,1.2*s,1.6*s,'inSteel',10,1.1)
  for k=0,5 do local a=k*pi/3;L.rod({x,4.6*s,0},{x+cos(a)*3.6*s,4.6*s+sin(a)*3.6*s,0},.08,'inSteel')end
 end
 L.rod({-6*s,4.6*s,0},{-1*s,4.6*s,0},.35,col);L.rod({-1*s,4.6*s,0},{4*s,10*s,0},.35,col)
 L.rod({-6*s,4.6*s,0},{-3*s,10*s,0},.35,col);L.rod({-3*s,10*s,0},{4*s,10*s,0},.35,col)
 L.rod({-1*s,4.6*s,0},{-3*s,10*s,0},.35,col);L.rod({4*s,10*s,0},{6*s,4.6*s,0},.35,col)
 L.rod({-3*s,10*s,0},{-3.4*s,11.4*s,0},.3,'inSteel');L.box(-5*s,11.4*s,-.8*s,-1.8*s,12*s,.8*s,'dark',1)
 L.rod({4*s,10*s,0},{4.4*s,12.4*s,0},.3,'inSteel');L.rod({4.4*s,12.4*s,-2.4*s},{4.4*s,12.4*s,2.4*s},.25,'inSteel')
end
function M.bikeShop(C)
 local St={H=52,paint='white',upper='ktPearl',wainscot='inChecker',wainscotH=10,rail='red',cornice='white',cap='ktLime',
  floor='inChecker',ceiling='white',wood='inOak',counter='red',counterTop='inSteel',skip={},ambience={shop=.25}}
 local F,S=generic(C,St)
 local cols={'red','blue','gold','leaf','flower','ktCopper'}
 -- floor bikes (b): each two cells wide, on a stand
 local n=0
 for _,g in ipairs(groups(C,'b'))do
  for cy=g.y0,g.y1 do
   for cx=g.x0,g.x1,2 do
    n=n+1
    local L=F(cx*CS+16,0,cy*CS+8,0)
    bike(L,cols[n%#cols+1],1.05)
    L.box(-8,0,-1.2,8,.5,1.2,'inSteel',1)
   end
  end
 end
 -- bikes hung on the wall (k)
 local Ln=K.onWall(C,'N',0,0)
 for i,c in ipairs(cellsOf(C,'k'))do
  if i%2==1 then
   local L=K.frame(C,Ln.E,c[1]*CS+16,22,S.n+3,0)
   bike(L,cols[(i+2)%#cols+1],.9)
   Ln.box(c[1]*CS+10,34,0,c[1]*CS+22,35,3,'inSteel',1)
  end
 end
 -- the price board and a poster
 Ln.box(68,30,0,92,46,.6,'lvSlate',.9)
 for i=0,4 do Ln.box(70,32.5+i*2.6,.6,78+rh(i,1,3)*6,33.6+i*2.6,.7,'white',1.15);Ln.box(86,32.5+i*2.6,.6,90,33.6+i*2.6,.7,'gold',1.2)end
 LA().inscription(Ln,'BIKES',80,47,.6,1.0,'red',22)
 -- the till on the counter, a pump and tyres by the bench (X)
 local cc=cellsOf(C,'C')
 if #cc>0 then local c=cc[1];local Lt=F(c[1]*CS+8,14.6,c[2]*CS+8,pi/2)
  Lt.box(-4,0,-3,4,2.6,3,'inEnamel',1);Lt.box(-3.4,2.6,-3,3.4,7,-1.4,'inEnamel',1);Lt.raw({-2.8,3.4,-1.35},{2.8,3.4,-1.35},{2.8,6.4,-1.35},{-2.8,6.4,-1.35},'inScreen',3)end
 for _,c in ipairs(cellsOf(C,'X'))do
  local L=F(c[1]*CS+8,0,c[2]*CS+8,0)
  L.box(-7,0,-6,7,10,6,'inOak',1);L.box(-7.4,10,-6.4,7.4,11,6.4,'inSteel',1.05)
  L.ring(-2,15,0,3,4,'dark',14,1);L.ring(3,14,1,2.6,3.4,'dark',14,1)
  L.cyl(5,11,13,-3,.6,.6,'red',6);L.rod({5,13,-3},{5,16,-3},.25,'red')
 end
end

------------------------------------------------------------------ DINER
-- The Celadon Diner: a checkerboard floor, booths of red leather round
-- chrome tables, the counter and the kitchen behind it, a menu board.
function M.diner(C)
 local St={H=52,paint='white',upper='ktPearl',wainscot='inLacquer',wainscotH=12,rail='inSteel',cornice='white',cap='ktLime',
  floor='inChecker',ceiling='white',wood='inSteel',counter='inLacquer',counterTop='inSteel',seat='bar',cushion='inLacquer',
  tableStyle='round',cloth=nil,skip={T=true,s=true},ambience={hall=.3}}
 local F,S=generic(C,St)
 -- the booths: red leather benches, back to back between the tables
 for _,g in ipairs(groups(C,'s'))do
  local x0,x1,z0,z1=g.x0*CS,(g.x1+1)*CS,g.y0*CS,(g.y1+1)*CS
  local tN,tS=C.is(g.x0,g.y0-1,'T'),C.is(g.x0,g.y1+1,'T')
  local L=F(0,0,0,0)
  if g.x1>g.x0 and(tN or tS)then
   -- (the seat is the height actors sit at; a back never stands where
   -- someone sits, and the one on the camera's side stays low)
   local function bench(za,zb)
    L.box(x0+1,0,za,x1-1,4,zb,'inSteel',1.0)
    L.box(x0+1,4,za,x1-1,5.8,zb,'inLacquer',1.05)
    for k=0,3 do L.box(x0+2+k*(x1-x0-4)/4,5.8,za+.5,x0+1.6+(k+1)*(x1-x0-4)/4,6.05,zb-.5,'inLacquer',1.1)end
   end
   local function back(za,zb,h)
    L.box(x0+1,5.8,za,x1-1,h-1.2,zb,'inLacquer',.98)
    L.box(x0+.6,h-1.2,za-.3,x1-.6,h,zb+.3,'inSteel',1.1)
    for k=1,3 do local x=x0+1+k*(x1-x0-2)/4;L.box(x-.3,6,za-.05,x+.3,h-1.2,zb+.05,'dark',.8)end
   end
   local armH=10
   if tN and tS then bench(z0+1,z1-1)
   elseif tS then bench(z0+3,z1-1);back(z0+1,z0+3.4,20);armH=20
   else bench(z0+1,z1-3);back(z1-3.4,z1-1,12);armH=12 end
   L.box(x0-.4,0,z0+1,x0+1,armH,z1-1,'inSteel',1.05);L.box(x1-1,0,z0+1,x1+.4,armH,z1-1,'inSteel',1.05)
  else
   for _,c in ipairs(g.cells)do K.seat(F(c[1]*CS+8,0,c[2]*CS+8,0),6.6,'bar',nil,{wood='inSteel',cushion='inLacquer'})end
  end
 end
 -- formica tables on chrome pedestals, a jukebox lamp over each
 for _,tb in ipairs(groups(C,'T'))do
  local x0,x1,z0,z1=tb.x0*CS,(tb.x1+1)*CS,tb.y0*CS,(tb.y1+1)*CS
  local L=F(tb.cx,0,tb.cz,0)
  local hw,hd=(x1-x0)/2-3,(z1-z0)/2-4
  L.cyl(0,0,.8,0,4,4,'inSteel',12);L.cyl(0,.8,9,0,.9,.9,'inSteel',8)
  L.box(-hw,9,-hd,hw,10,hd,'inSteel',1.05)
  L.box(-hw+.4,10,-hd+.4,hw-.4,10.1,hd-.4,'ktPearl',1.12)
  local p=L.P({0,30,0})
  local E=C.part('ceilfx',{below=C.H+2})
  local Lp=K.frame(C,E,p[1],0,p[3],0)
  Lp.rod({0,C.H,0},{0,32,0},.12,'dark');Lp.cyl(0,28,32,0,4.4,1.2,'red',12,false)
  Lp.disc(0,28.05,0,4.2,'inLamp',12,'y')
  C.addLight(p[1],26,p[3],40,.25)
 end
 -- the kitchen behind the counter: a range, a griddle, a fridge, steam
 local W=C.cw*CS
 local L=F(0,0,0,0)
 L.box(7*CS+2,0,S.n+1,W-1,14,S.n+12,'ktSteel',1)
 L.box(7*CS+2,14,S.n+1,W-1,15,S.n+12,'inSteel',1.05)
 for k=0,3 do L.cyl(7*CS+10+k*10,15,15.3,S.n+6,2.4,2.4,'dark',10)end
 L.cyl(7*CS+10,15.3,19,S.n+6,2.2,2.2,'inSteel',10);L.cyl(7*CS+30,15.3,17,S.n+6,2.6,2.8,'ktSteel',10)
 L.box(7*CS+2,22,S.n,W-1,32,S.n+10,'inSteel',1)
 C.fx.mist={{x=7*CS+20,y=24,z=S.n+8,r=10,phase=1,drift=3,col={1,1,1},a=.10},{x=7*CS+34,y=26,z=S.n+8,r=8,phase=2.3,drift=3,col={1,1,1},a=.08}}
 -- a menu board and the shelf of glasses
 local Ln=K.onWall(C,'N',0,0)
 Ln.box(8,26,0,56,44,.6,'dark',.9)
 for i=0,5 do Ln.box(10,28.5+i*2.6,.6,26+rh(i,2,5)*14,29.6+i*2.6,.7,'white',1.15);Ln.box(48,28.5+i*2.6,.6,54,29.6+i*2.6,.7,'gold',1.2)end
 LA().inscription(Ln,'DINER',32,45.4,.6,1.2,'red',40)
 K.wallShelf(Ln,7*CS+2,W-2,40,{wood='inSteel',items='jars',seed=3})
 -- napkin holders and ketchup on the tables
 for _,tb in ipairs(groups(C,'T'))do
  local Lt=F(tb.cx,10.1,tb.cz,0)
  Lt.box(-1.4,0,-1,1.4,2.2,1,'inSteel',1.1)
  Lt.cyl(3,0,3,0,.7,.6,'red',8);Lt.cyl(-3,0,3,0,.7,.6,'gold',8)
 end
 C.addLight(W/2,40,60,140,.12)
end

------------------------------------------------------------------ DEPT STORE
-- The Celadon Department Store: five floors on one frame -- the elevator,
-- the stairs, the floor directory, the counters, the gondolas of goods;
-- the 3F's game kiosks, the 1F's vending machines and benches.
function M.deptStore(C)
 local fl=tonumber(C.id:match('_(%d)F'))or 1
 local St={H=56,paint='ktPlaster',upper='white',wainscot='inWalnut',wainscotH=12,rail='lgGold',cornice='white',cap='ktLime',
  floor=fl==1 and'lgMarble'or'inTerrazzo',ceiling='white',wood='inOak',counter='inWalnut',counterTop='lgMarble',
  walls='WVp',band='ZN',seat='modern',skip={T=true},ambience={shop=.3,hall=.15},scenic=true,view=3}
 local F,S=generic(C,St)
 local W,D=C.cw*CS,C.ch*CS
 -- the two-row wall band: the elevator (E), the signs (p), the machines'
 -- tops, a big screen (N) - all on the wall at z=32
 local Ln=K.onWall(C,'N',0,0)
 for _,g in ipairs(groups(C,'E'))do
  local x0,x1=g.x0*CS,(g.x1+1)*CS
  local L=K.frame(C,Ln.E,0,0,0,0)
  L.box(x0-2,0,16,x0,36,19,'lgGold',1.05);L.box(x1,0,16,x1+2,36,19,'lgGold',1.05);L.box(x0-2,34,16,x1+2,37,19,'lgGold',1.08)
  L.box(x0,0,16.2,(x0+x1)/2-.2,34,16.8,'inSteel',1.05);L.box((x0+x1)/2+.2,0,16.2,x1,34,16.8,'inSteel',1.02)
  L.box(x1+3,14,16,x1+6,22,17.4,'lgGold',1.05);L.disc(x1+4.5,19,17.5,.7,'inLamp',8);L.disc(x1+4.5,16.4,17.5,.7,'inLamp',8)
  LA().inscription(L,tostring(({'A','B','C','D','E'})[fl]or'A'),(x0+x1)/2,38,17,.9,'lgGold')
 end
 for _,c in ipairs(cellsOf(C,'p'))do
  if c[2]==1 then
   local x=c[1]*CS+8
   Ln.box(x-7,34,16,x+7,48,17,'lgGold',1.05)
   Ln.box(x-6.2,34.8,17,x+6.2,47.2,17.2,'navy',1.0)
   for i=0,4 do Ln.box(x-5,36+i*2.2,17.2,x-5+rh(c[1],i,fl)*9+1,36.8+i*2.2,17.3,'white',1.15)end
  end
 end
 -- windows over the city where the band has a clear run of wall
 do
  local Lb=K.frame(C,Ln.E,S.w,0,32,0)
  local run0
  for cx=0,C.cw do
   local wall=cx<C.cw and C.at(cx,1)=='W'and C.at(cx,0)=='W'and not C.is(cx,2,'ZN')
   if wall and not run0 then run0=cx end
   if not wall and run0 then
    local n=cx-run0
    if n>=3 then
     local mid=(run0+cx)*CS/2-S.w
     local hw=min(n*8-8,26)
     K.window(C,Lb,mid-hw,mid+hw,16,42,{frame='lgGold',view=3,curtain='valance',cloth='inRugRed',panes={max(2,floor(hw/8)),2},scenic=true})
    end
    run0=nil
   end
  end
 end
 -- vending machines (Z): drinks behind glass, lit
 for _,g in ipairs(groups(C,'Z'))do
  local x0,x1=g.x0*CS,(g.x1+1)*CS
  for cx=g.x0,g.x1 do
   if C.at(cx,2)=='Z'then
    local L=F(cx*CS+8,0,40,0)
    L.box(-7,0,-7,7,32,6,cx%2==0 and'inLacquer'or'blue',1)
    L.raw({-6,10,6.05},{2,10,6.05},{2,29,6.05},{-6,29,6.05},'inLamp',2)
    for k=0,2 do L.quad({-5.8,11+k*6,6.1},{1.8,11+k*6,6.1},{1.8,16+k*6,6.1},{-5.8,16+k*6,6.1},'inGoods',1.1)end
    L.box(3,12,6,6,24,6.4,'inSteel',1);for k=0,3 do L.box(3.6,22-k*2.4,6.4,5.4,23-k*2.4,6.6,'gold',1.2)end
    L.box(-6,2,6,6,7,6.6,'dark',.7)
   end
  end
 end
 -- the big screen (N in the wall band) on 3F
 for _,g in ipairs(groups(C,'N'))do
  if g.y0<=1 then
   local x0,x1=g.x0*CS,(g.x1+1)*CS
   Ln.box(x0+1,20,16,x1-1,46,17.4,'dark',.8)
   Ln.raw({x0+2,21,17.45},{x1-2,21,17.45},{x1-2,45,17.45},{x0+2,45,17.45},'inScreen',2)
  end
 end
 -- the gondolas (G): the Mart's, in the store's colours
 for _,g in ipairs(groups(C,'G'))do
  local x0,x1,z0,z1=g.x0*CS,(g.x1+1)*CS,g.y0*CS,(g.y1+1)*CS
  local L=F(0,0,0,0)
  local h=24;local za,zb=z0+4,z1-3
  L.box(x0+1,0,za,x1-1,1.6,zb,'inWalnut',1.0)
  L.box(x0+1,1.6,(za+zb)/2-1,x1-1,h,(za+zb)/2+1,'ktPearl',1.0)
  L.box(x0+.6,h,za-.4,x1-.6,h+1.4,zb+.4,'inWalnut',1.05)
  for _,e in ipairs({x0+1,x1-2.2})do L.box(e,1.6,za,e+1.2,h,zb,'inWalnut',1.0)end
  for k=0,1 do
   local y=4+k*8
   for _,side in ipairs({-1,1})do
    local zf=side>0 and zb or za
    local zi=(za+zb)/2+side*1
    L.box(x0+2.2,y-.6,min(zi,zf),x1-2.2,y,max(zi,zf),'ktPearl',1.05)
    L.quad(side>0 and{x0+2.4,y,zf-1.2}or{x1-2.4,y,zf+1.2},side>0 and{x1-2.4,y,zf-1.2}or{x0+2.4,y,zf+1.2},
     side>0 and{x1-2.4,y+7.2,zf-1.2}or{x0+2.4,y+7.2,zf+1.2},side>0 and{x0+2.4,y+7.2,zf-1.2}or{x1-2.4,y+7.2,zf+1.2},'inGoods',1.05)
   end
  end
 end
 -- 3F: the game kiosks (N over T): screens on tables, controllers
 if fl==3 then
  for _,g in ipairs(groups(C,'T'))do
   local x0,x1,z0,z1=g.x0*CS,(g.x1+1)*CS,g.y0*CS,(g.y1+1)*CS
   local L=F(0,0,0,0)
   L.box(x0+1,0,z0-12,x1-1,10,z1-2,'inEnamel',1)
   L.box(x0+.6,10,z0-12.4,x1-.6,11,z1-1.6,'ktSteel',1.05)
   for cx=g.x0,g.x1 do
    local Lk=F(cx*CS+8,11,z0-6,0)
    Lk.box(-6,0,-4,6,11,1,'dark',.9)
    Lk.raw({-5.2,1,1.05},{5.2,1,1.05},{5.2,10,1.05},{-5.2,10,1.05},'inScreen',2)
    Lk.box(-4,0,3,4,1,5.6,'ktPearl',1.05);Lk.box(-2,1,3.6,2,1.4,4.8,'red',1.1)
    C.fx.glows[#C.fx.glows+1]={x=cx*CS+8,y=16,z=z0-4,r=7,col='cyan',a=.12}
   end
  end
 end
 -- benches along the 1F's east wall (the s cells there)
 -- (the generic seats face away from the nearest table; on the 1F they
 -- line the wall)
 -- the info desk's sign and a flower stand on the 1F
 if fl==1 then
  LA().inscription(Ln,'CELADON',W/2,48,16.5,1.6,'lgGold',90)
 end
 -- a chandelier of light panels
 local E=C.part('ceilfx',{below=C.H+2})
 local Lc=K.frame(C,E,0,0,0,0)
 for x=40,W-30,64 do Lc.raw({x-14,C.H-.5,40},{x+14,C.H-.5,40},{x+14,C.H-.5,D-20},{x-14,C.H-.5,D-20},'inPanel',1)end
 C.addLight(W/2,40,D/2,300,.14)
end
function M.elevator(C)
 local St={H=48,paint='inSteel',upper='inSteel',rail='lgGold',cornice='lgGold',cap='ktLime',floor='inChecker',ceiling='inPanel',
  walls='WVK',skip={},lights=false,ambience={hum=.1},
  -- (TEST178: its door opens on the floor's landing)
  inside=true,insideFloor=C.id:match('^SILPH')and'dnCarpet'or'inTerrazzo',insideWall='ktPearl'}
 local F,S=generic(C,St)
 local Ln=K.onWall(C,'N',0,0)
 for _,c in ipairs(cellsOf(C,'K'))do
  local x=c[1]*CS+8
  Ln.box(x-6,12,16,x+6,36,17,'lgGold',1.05)
  for k=0,4 do Ln.disc(x,16+k*4,17.1,1.3,'dark',10);Ln.disc(x,16+k*4,17.2,.9,'inLamp',8)end
 end
 Ln.box(4,40,0,40,46,.6,'dark',.8);Ln.raw({5,41,.65},{39,41,.65},{39,45,.65},{5,45,.65},'inScreen',3)
 C.addLight(16,40,24,60,.3)
end

------------------------------------------------------------------ MANSION
-- Celadon Mansion: the manager's flat (1F), Game Freak's offices (2F, 3F),
-- the corridor and its stairs; the chief's house next door.
function M.mansion(C)
 local fl=tonumber(C.id:match('_(%d)F'))or 1
 local St={H=52,paint=fl==1 and'inPaperSage'or'ktPearl',upper=fl==1 and'inPaperSage'or'white',wainscot='inWalnut',wainscotH=12,rail='lgGold',
  cornice='white',cap='ktLime',floor=fl==1 and'inParquet'or'inOak',ceiling='white',wood='inWalnut',innerPaint='ktPlaster',innerH=40,
  plant='ficus',pot='white',cloth=fl==1 and'inRugRed'or nil,items='books',shelfDoors=true,deskWood='inOak',seat='modern',
  counter='inWalnut',counterTop='lgMarble',walls='WVX',scenic=true,view=3}
 local F,S=generic(C,St)
 local W=C.cw*CS
 -- televisions (N)
 for _,g in ipairs(groups(C,'N'))do K.tv(F(g.cx,0,(g.y1+1)*CS-8,0),{wood='inWalnut',kind='crt',channel=2})end
 -- the office corner (k): a copier and a water cooler
 for _,g in ipairs(groups(C,'k'))do
  local x=g.x0*CS+8
  local L=F(x,0,g.y0*CS+8,0)
  L.box(-6,0,-6,6,12,6,'inEnamel',1.02);L.box(-6.4,12,-6.4,6.4,13,6.4,'ktSteel',1.05)
  L.box(-5,13,-5,5,14.4,5,'ktPearl',1.1);L.raw({-4,6,6.05},{0,6,6.05},{0,10,6.05},{-4,10,6.05},'inScreen',3)
  for k=0,2 do L.box(-5.4,1.5+k*1.6,6,5.4,2.6+k*1.6,6.5,'ktPearl',1.0)end
  if g.y1>g.y0 then
   local Lw=F(x,0,(g.y0+1)*CS+8,0)
   Lw.box(-4,0,-4,4,16,4,'inEnamel',1)
   Lw.cyl(0,16,17,0,3.4,3.4,'inEnamel',10)
   Lw.cyl(0,17,25,0,3.2,3.2,'glass',12)
   Lw.cyl(0,17,23,0,3.0,3.0,'blue',12,true)
   Lw.box(-1.4,10,4,-.4,11,4.8,'red',1.2);Lw.box(.4,10,4,1.4,11,4.8,'blue',1.2)
   Lw.box(-3,6,4,3,7,5,'ktSteel',1)
  end
 end
 -- the corridor's windows (the mansion overlooks the city)
 local Ln=K.onWall(C,'N',0,0)
 for _,c in ipairs(cellsOf(C,'W'))do
  if c[2]==0 and C.is(c[1],1,'.')then
   K.window(C,Ln,c[1]*CS+2,c[1]*CS+14,22,42,{frame='white',view=3,curtain=fl==1 and'drape'or'blind',cloth=fl==1 and'inRugRed'or'white',panes={1,3},scenic=true})
  end
 end
 -- a rug in the flat, a desk lamp per desk upstairs
 if fl==1 then
  K.rug(C,C.part('floor'),18,56,74,100,{field='inRugRed',border='inRugGold',pattern='medallion',fringe='cream'})
 end
 C.fx.ambience={room=.3}
end
function M.chiefHouse(C)
 local St={H=52,paint='inPaperRose',upper='inPaperRose',wainscot='inWalnut',wainscotH=14,rail='lgGold',cornice='white',cap='ktLime',
  floor='inParquet',ceiling='white',wood='inWalnut',plant='palm',pot='white',cloth='white',skip={B=true,T=true}}
 local F,S=generic(C,St)
 -- the grand table (T)
 for _,tb in ipairs(groups(C,'T'))do
  local x0,x1,z0,z1=tb.x0*CS,(tb.x1+1)*CS,tb.y0*CS,(tb.y1+1)*CS
  local L=F((x0+x1)/2,0,(z0+z1)/2,0)
  K.table(L,x1-x0-3,z1-z0-3,10,'dining',{wood='inWalnut',runner='inRugRed'})
  for k=0,2 do K.lamp(C,F((x0+x1)/2-16+k*16,10.1,(z0+z1)/2,0),'candle',{h=4,metal='lgGold'})end
 end
 -- a pair of display cabinets (B) and the great painting over the hearth (N)
 for _,g in ipairs(groups(C,'B'))do
  K.bookcase(F(g.cx,0,24,0),14,38,12,{wood='inWalnut',items='curios',glass=true,seed=g.x0})
 end
 for _,g in ipairs(groups(C,'N'))do
  local Ln=K.onWall(C,'N',0,0)
  local x=g.cx
  Ln.box(x-14,0,-.2,x+14,26,2,'lgMarble',1);Ln.quad({x-8,0,2.05},{x+8,0,2.05},{x+8,14,2.05},{x-8,14,2.05},'dark',.3)
  Ln.box(x-15,26,-.2,x+15,28,3,'lgMarble',1.08)
  local p=Ln.P({x,1.4,1.6});C.fx.fires[#C.fx.fires+1]={x=p[1],y=p[2],z=p[3],s=.7}
  C.addLight(p[1],8,p[3],60,.45)
  K.picture(C,Ln,x-12,x+12,31,48,'portrait',{frame='lgGold',coat='red',hair='white'})
 end
 K.rug(C,C.part('floor'),24,40,104,88,{field='inRugRed',border='inRugGold',pattern='medallion',fringe='cream'})
 C.fx.ambience={room=.35,fire=.3}
end

------------------------------------------------------------------ LABS
-- The Cinnabar Lab and its rooms, the Safari Zone's office and secret house:
-- white rooms of machines, chemistry benches, computers.
local function labMachine(C,F,c,seed)
 local L=F(c[1]*CS+8,0,c[2]*CS+8,0)
 local kind=seed%3
 L.box(-7.6,0,-7,7.6,26,6,'inEnamel',1)
 if kind==0 then
  -- tape reels
  L.disc(-3.4,18,6.05,3,'dark',14);L.disc(3.4,18,6.05,3,'dark',14)
  L.disc(-3.4,18,6.1,1,'inSteel',8);L.disc(3.4,18,6.1,1,'inSteel',8)
  for k=0,3 do L.box(-6+k*3.4,6,6,-4+k*3.4,8,6.4,({'red','gold','leaf','blue'})[k+1],1.15)end
 elseif kind==1 then
  -- a glass cylinder of bubbling liquid
  L.raw({-5,4,6.05},{5,4,6.05},{5,24,6.05},{-5,24,6.05},'inAqua',1)
  C.fx.fish=C.fx.fish or{}
 else
  L.raw({-6,10,6.05},{6,10,6.05},{6,22,6.05},{-6,22,6.05},'inScreen',3)
  for k=0,5 do L.disc(-5+k*2,6,6.05,.6,k%2==0 and'red'or'leaf',8,nil,1.2)end
 end
 L.box(-8,26,-7.4,8,27.4,6.4,'ktSteel',1.05)
end
function M.lab(C)
 local id=C.id
 local St={H=52,paint='white',upper='ktPearl',wainscot='ktSteel',wainscotH=10,rail='inSteel',cornice='white',cap='ktLime',
  floor='inTile',ceiling='white',wood='white',deskWood='inEnamel',shelfWood='white',items='files',shelfDoors=true,
  plant='snake',pot='inEnamel',seat='modern',counter='inEnamel',counterTop='ktSteel',walls='WVp',view=2,ambience={hum=.18}}
 if id=='WARDENS_HOUSE'then
  St.paint,St.upper,St.wainscot,St.floor,St.wood,St.deskWood,St.plant,St.pot,St.view='ktOchre','ktSandstone','inWalnut','inOak','inWalnut','inWalnut','palm','ktTerracotta',5
  St.ambience={room=.35}
 elseif id=='FUCHSIA_MEETING_ROOM'or id=='SAFARI_ZONE_SECRET_HOUSE'then
  St.paint,St.wainscot,St.floor,St.wood='ktSandstone','inWalnut','inOak','inWalnut'
 end
 -- (TEST178: the lab's back rooms open on its hall, not the street)
 if id:match('^CINNABAR_LAB_')then St.inside=true;St.insideFloor='inTile';St.insideWall='white'end
 local F,S=generic(C,St)
 -- machines (Q)
 for i,c in ipairs(cellsOf(C,'Q'))do labMachine(C,F,c,c[1]*3+c[2]+i)end
 -- the chemistry bench (J): flasks and retorts
 for _,g in ipairs(groups(C,'J'))do
  local x0,x1=g.x0*CS,(g.x1+1)*CS
  local L=F(0,0,0,0)
  L.box(x0+1,0,S.n+1,x1-1,13,(g.y1+1)*CS-1,'inEnamel',1)
  L.box(x0+.6,13,S.n+.6,x1-.6,14.4,(g.y1+1)*CS-.6,'ktSteel',1.08)
  -- a reagent shelf on the wall behind
  L.box(x0+2,24,S.n,x1-2,25,S.n+5,'inEnamel',1.05)
  for i=0,floor((x1-x0-4)/3.4)-1 do
   L.cyl(x0+4+i*3.4,25,27.4+rh(i,2,7)*1.6,S.n+2.6,1,1,({'ktCopper','lvSlate','ktGlass','ktOchre'})[i%4+1],6)
  end
  for i=0,floor((x1-x0)/6)-1 do
   local x=x0+4+i*6
   local Lf=F(x,14.4,S.n+8,0)
   local liq=({'leaf','flower','blue','gold','ktCopper'})[i%5+1]
   if i%3==0 then
    -- a round flask on a ring stand over a burner
    Lf.cyl(0,0,3,0,.25,.25,'inSteel',4);Lf.cyl(0,0,.4,0,1.4,1.4,'inSteel',8)
    Lf.sphere(0,4.6,0,2,1.9,2,liq,8,5);Lf.cyl(0,6.2,9,0,.5,.5,'ktGlass',6)
   elseif i%3==1 then
    -- a conical flask
    Lf.cyl(0,0,3.6,0,2,.6,liq,8,true);Lf.cyl(0,3.6,6,0,.55,.55,'ktGlass',6)
   else
    -- a rack of test tubes
    Lf.box(-2.4,0,-1,2.4,1.6,1,'inWalnut',1)
    for k=0,3 do Lf.cyl(-1.8+k*1.2,1.6,4.4,0,.4,.4,({'leaf','flower','blue','gold'})[k+1],5)end
   end
   C.fx.glows[#C.fx.glows+1]={x=x,y=17,z=S.n+8,r=3,col=({'green','violet','cyan','gold'})[i%4+1],a=.18}
  end
 end
 -- the grating floor (g) over the machinery
 do local E=C.part('floor')
  for _,c in ipairs(cellsOf(C,'g'))do
   local x0,z0=c[1]*CS,c[2]*CS
   for k=0,7 do E.quad({x0+k*2,.08,z0},{x0+k*2+.6,.08,z0},{x0+k*2+.6,.08,z0+16},{x0+k*2,.08,z0+16},'ktSteel',.6)end
  end
 end
 -- exhibits (F): the warden's photographs of the Safari's creatures
 for _,g in ipairs(groups(C,'F'))do
  local L=F(g.cx,0,(g.y1+1)*CS-8,0)
  L.box(-14,0,-6,14,12,6,'inWalnut',1)
  L.box(-13,12,-2,13,30,0,'lgGold',1.05)
  K.picture(C,F(g.cx,12,0+(g.y1+1)*CS-8,0),-12,12,1,17,'meadow',{frame='lgGold',mat=.6})
 end
 -- the rock ring (R) round the warden's prize
 for _,c in ipairs(cellsOf(C,'R'))do
  local L=F(c[1]*CS+8,0,c[2]*CS+8,0)
  L.sphere(0,6,0,7,6.4,7,'lgRock',9,5,c[1]*5+c[2])
 end
 -- posters (p) and the doors (d) to the lab's rooms
 local Ln=K.onWall(C,'N',0,0)
 for i,c in ipairs(cellsOf(C,'p'))do
  -- (each on the face of its own cell, which may stand out from the wall)
  local Lf=F(c[1]*CS+8,0,(c[2]+1)*CS,0)
  if C.is(c[1]-1,c[2],'d')then
   -- the room's name plate beside its door
   Lf.box(-5,22,0,5,28,.6,'inSteel',1.05);Lf.box(-4.4,22.6,.6,4.4,27.4,.7,'navy',1)
   for k=0,2 do Lf.box(-3.6,23.6+k*1.2,.7,-3.6+2+rh(c[1],k,5)*5,24.2+k*1.2,.75,'white',1.2)end
  else
   K.picture(C,Lf,-8,8,24,38,i%2==0 and'fossil'or'pokemon',{frame='inSteel',mat=.6,ground='white',body='blue'})
  end
 end
 -- between the lobby's doors: notice boards and the lab's crest
 for _,g in ipairs(groups(C,'W'))do
  if g.y0>0 and g.y0==g.y1 and g.x1>g.x0 and C.is(g.x0,g.y1+1,'.')then
   local Lf=F((g.x0+g.x1+1)*CS/2,0,(g.y1+1)*CS,0)
   local w=(g.x1-g.x0+1)*CS/2-6
   Lf.box(-w,20,0,w,40,.6,'ktCopper',.9);Lf.box(-w+1,21,.6,w-1,39,.8,'ktOchre',1)
   for k=0,4 do local x=-w+3+rh(g.x0,k,2)*(2*w-10);local y=23+rh(g.x0,k,3)*10
    Lf.box(x,y,.8,x+5,y+6,.9,({'white','cream','gold','white','flower'})[k+1],1.15)
    Lf.box(x+2.2,y+5.2,.9,x+2.8,y+5.8,1.1,'red',1.2)end
  end
 end
 -- whiteboards and a clock on the side walls of the plain rooms
 local S=C.shellBox
 if id~='CINNABAR_LAB'then
  local depth=S.s-S.n
  local Lw=K.onWall(C,'W',0,0)
  local u=depth*.5
  if id=='WARDENS_HOUSE'then
   Town.WALLS.antlers(C,Town.THEMES.FUCHSIA,Lw,u+16)
   Town.WALLS.map(C,Town.THEMES.FUCHSIA,Lw,u-22)
  else
   Lw.box(u-16,20,0,u+16,40,.8,'inSteel',1.05);Lw.box(u-15,21,.8,u+15,39,1,'white',1.2)
   for k=0,4 do local y=24+k*3;Lw.rod({u-12,y,1.05},{u-12+6+rh(k,1,9)*14,y+rh(k,2,9)*2,1.05},.14,({'navy','red','navy','leaf','navy'})[k+1])end
   Lw.ring(u+8,30,1.05,3,3.4,'red',14,1.1)
   Lw.box(u-14,18.6,0,u+14,19.6,2.4,'inSteel',1.05)
  end
  local Le=K.onWall(C,'E',0,0)
  if id=='WARDENS_HOUSE'then
   Town.WALLS.photos(C,Town.THEMES.FUCHSIA,Le,depth*.4)
   Town.WALLS.feathers(C,Town.THEMES.FUCHSIA,Le,depth*.75)
   K.picture(C,Ln,40,64,22,40,'meadow',{frame='inWalnut'});K.picture(C,Ln,88,108,24,38,'tree',{frame='inWalnut'})
  else
   K.clock(C,Le,depth*.5,36,3.4,{case='inSteel'})
   Le.box(depth*.5-12,16,0,depth*.5-4,28,.6,'white',1.12)
   for k=0,3 do Le.box(depth*.5-11,18+k*2.4,.6,depth*.5-6,18.8+k*2.4,.7,'dark',.8)end
  end
 end
 for _,g in ipairs(groups(C,'d'))do
  if g.y0>0 then
   -- doors set in the lobby's back wall
   local x0,x1=g.x0*CS,(g.x1+1)*CS
   local z=g.y0*CS
   local L=F(0,0,0,0)
   L.box(x0-1,0,z,x0+1,36,z+2,'inSteel',1.05);L.box(x1-1,0,z,x1+1,36,z+2,'inSteel',1.05);L.box(x0-1,34,z,x1+1,37,z+2,'inSteel',1.08)
   L.box(x0+1,0,z,x1-1,34,z+.4,'ktPearl',1.0)
   L.box(x1-4,14,z+.4,x1-3,18,z+1,'inSteel',1.1)
  end
 end
 C.addLight(C.cw*CS/2,40,C.ch*CS/2,200,.12)
end

------------------------------------------------------------------ DOJO
-- The Fighting Dojo: timber posts and white plaster, polished boards, the
-- calligraphy scrolls, the master's dais, drums and the training gear.
function M.dojo(C)
 local St={H=60,paint='white',upper='white',wainscot='lgWood',wainscotH=10,rail='inWalnut',cornice='inWalnut',cap='inWalnut',
  floor='lgWood',ceiling='inPine',wood='inWalnut',walls='WVI',skip={},ambience={dojo=.4},view=4}
 local F,S=generic(C,St)
 local W,D=C.cw*CS,C.ch*CS
 -- the timber posts (I): square posts along the walls and the alcoves
 for _,c in ipairs(cellsOf(C,'I'))do
  local L=F(c[1]*CS+8,0,c[2]*CS+8,0)
  L.box(-4.4,0,-4.4,4.4,C.H,4.4,'inWalnut',1)
  L.box(-5,0,-5,5,3,5,'ktBasalt',1)
 end
 -- ceiling beams
 local E=C.part('ceilfx',{below=C.H+2})
 local Lb=K.frame(C,E,0,0,0,0)
 for z=S.n+8,D-8,32 do Lb.box(0,C.H-4,z-2,W,C.H,z+2,'inWalnut',1)end
 -- the scrolls (p) on the north wall, and the master's altar
 local Ln=K.onWall(C,'N',0,0)
 for _,c in ipairs(cellsOf(C,'p'))do
  local x=c[1]*CS+8
  Ln.box(x-5,14,0,x+5,46,.4,'cream',1.1);Ln.box(x-5.6,45.6,-.2,x+5.6,47,1,'inWalnut',1);Ln.box(x-5.6,13.4,-.2,x+5.6,14.8,1,'inWalnut',1)
  for i=0,6 do Ln.box(x-1.2,18+i*3.8,.45,x+1.2,20.6+i*3.8,.5,'dark',.7)end
 end
 -- the side alcoves' banners and a pair of drums
 for _,x in ipairs({24,W-24})do
  Ln.box(x-6,20,0,x+6,50,.5,'inLacquer',1.0)
  Ln.disc(x,40,.6,4,'white',16,nil,1.1)
  LA().inscription(Ln,'K',x,37.6,.7,1,'dark')
 end
 -- the members' name boards along both side walls
 for _,side in ipairs({'W','E'})do
  local Lw=K.onWall(C,side,0,0)
  local depth=S.s-S.n
  Lw.box(depth*.25-2,40,0,depth*.75+2,42,1.4,'inWalnut',1)
  for k=0,floor(depth*.5/4.4)-1 do
   local u=depth*.25+k*4.4
   Lw.box(u,28,0,u+3.6,40,.6,'inPine',1.05)
   for j=0,2 do Lw.box(u+1.4,30+j*3.4,.6,u+2.2,32.4+j*3.4,.7,'dark',.7)end
  end
 end
 -- statues (Y): stone fighters' plinths with a lantern each
 for _,g in ipairs(groups(C,'Y'))do
  local L=F(g.cx,0,(g.y1+1)*CS-8,0)
  L.box(-7,0,-7,7,2,7,'ktBasalt',1);L.box(-1.6,2,-1.6,1.6,10,1.6,'lvStone',1)
  L.box(-5,10,-5,5,11.4,5,'lvStone',1);L.box(-3.4,11.4,-3.4,3.4,18,3.4,'inShoji',1)
  L.quad({-6,18,-6},{6,18,-6},{0,23,0},{0,23,0},'lvStone',1);L.quad({-6,18,6},{6,18,6},{0,23,0},{0,23,0},'lvStone',1.05)
  local p=L.P({0,15,0});C.addLight(p[1],p[2],p[3],40,.2)
 end
 -- a training mat in the hall
 K.rug(C,C.part('floor'),36,80,124,150,{field='inTatami',border='inRugRed',bw=2,y=.1})
 C.addLight(W/2,40,D/2,200,.14)
end

------------------------------------------------------------------ BILL
-- Bill's cottage: the twin cell separators joined by their pipe, his desk
-- and computer, the sea beyond the window.
local function separator(C,F,g)
 local x0,x1,z0,z1=g.x0*CS,(g.x1+1)*CS,g.y0*CS,(g.y1+1)*CS
 local cx,cz=(x0+x1)/2,(z0+z1)/2+4
 local L=F(cx,0,cz,0)
 L.cyl(0,0,3,0,17,17,'ktSteel',20)
 L.cyl(0,3,34,0,15,15,'inEnamel',20,false)
 for k=0,2 do L.cyl(0,6+k*10,7.4+k*10,0,15.6,15.6,'ktSteel',20,false)end
 L.cyl(0,34,38,0,15.6,12,'ktSteel',20)
 L.cyl(0,38,40,0,8,6,'inSteel',16)
 -- the door: a dark slot with a glowing frame
 L.box(-5,3,14.6,5,28,15.3,'dark',.5)
 L.box(-6,3,14.4,-5,29,15.6,'lgGold',1.1);L.box(5,3,14.4,6,29,15.6,'lgGold',1.1);L.box(-6,28,14.4,6,29.4,15.6,'lgGold',1.1)
 L.raw({-4.4,24,15.35},{4.4,24,15.35},{4.4,27,15.35},{-4.4,27,15.35},'inScreen',3)
 C.fx.glows[#C.fx.glows+1]={x=cx,y=16,z=cz+16,r=12,col='cyan',a=.12}
end
function M.bill(C)
 local St={H=52,paint='ktPearl',upper='white',wainscot='inPine',wainscotH=12,bead=3,rail='white',cornice='white',cap='ktLime',
  floor='inPine',ceiling='white',wood='inOak',deskWood='inOak',walls='WV',skip={},view=2,ambience={hum=.2,room=.2}}
 local F,S=generic(C,St)
 for _,g in ipairs(groups(C,'M'))do separator(C,F,g)end
 -- the pipe between them (J), on a low cabinet of gauges
 local W=C.cw*CS
 local L=F(0,0,0,0)
 for _,g in ipairs(groups(C,'J'))do
  local x0,x1=g.x0*CS-6,(g.x1+1)*CS+6
  local z=g.cz
  L.rod({x0,22,z},{x1,22,z},2.4,'inSteel')
  for _,x in ipairs({x0+6,x1-6})do L.rod({x-1.2,22,z},{x+1.2,22,z},2.9,'ktSteel')end
  L.box(x0+8,0,z-5,x1-8,12,z+5,'inEnamel',1)
  L.box(x0+7.6,12,z-5.4,x1-7.6,13,z+5.4,'ktSteel',1.05)
  for k=0,2 do local x=x0+12+k*(x1-x0-24)/2
   L.disc(x,8,z+5.05,1.8,'white',12,nil,1.15);L.rod({x,8,z+5.1},{x+1.2,9.2,z+5.1},.12,'red')end
  L.rod({(x0+x1)/2,13,z},{(x0+x1)/2,19.6,z},.5,'inSteel')
 end
 -- a window between the machines, over the pipe
 local Ln=K.onWall(C,'N',0,0)
 K.window(C,Ln,52,76,30,46,{frame='white',view=2,panes={2,2}})
 -- his books and charts on the side walls
 local Lw=K.onWall(C,'W',0,0)
 K.wallShelf(Lw,40,72,30,{wood='inOak',items='books',seed=2})
 K.picture(C,Lw,76,96,22,36,'map',{frame='inOak',mount=false})
 local Le=K.onWall(C,'E',0,0)
 K.picture(C,Le,40,64,22,38,'sea',{frame='inOak'})
 K.clock(C,Le,80,32,3,{case='inOak'})
 C.addLight(W/2,40,60,140,.12)
end

------------------------------------------------------------------ FAN CLUB
-- The Pokemon Fan Club, Vermilion: the chairman's sofa, the great round
-- table with its showpiece, fans' chairs, posters of favourites.
function M.fanClub(C)
 local St={H=52,paint='inPaperRose',upper='inPaperRose',wainscot='white',wainscotH=12,bead=3,rail='flower',cornice='white',cap='ktLime',
  floor='inParquet',ceiling='white',wood='inOak',seat='spindle',cushion='inRugRed',walls='WVU',skip={T=true},ambience={room=.3,hall=.15}}
 local F,S=generic(C,St)
 -- the sofa (U on the wall, its seats s below)
 for _,g in ipairs(groups(C,'U'))do
  local x0,x1=g.x0*CS,(g.x1+1)*CS
  local L=F(0,0,0,0)
  L.box(x0,0,S.n,x1,16,S.n+5,'inLeather',1)
  L.box(x0,0,S.n+5,x1,6,S.n+15,'inLeather',1.02)
  L.box(x0-2,0,S.n,x0,11,S.n+15,'inLeather',1.0);L.box(x1,0,S.n,x1+2,11,S.n+15,'inLeather',1.0)
 end
 -- the great round table and its showpiece (S): a gold cup
 for _,tb in ipairs(groups(C,'TS'))do
  local L=F(tb.cx,0,tb.cz,0)
  K.table(L,(tb.x1-tb.x0+1)*CS-6,(tb.y1-tb.y0+1)*CS-6,10,'round',{wood='inWalnut',cloth='white'})
  local Lc=F(tb.cx,10.1,tb.cz,0)
  Lc.cyl(0,0,1,0,3,3,'inWalnut',12);Lc.cyl(0,1,5,0,.8,.8,'lgGold',8);Lc.cyl(0,5,10,0,1.2,3.6,'lgGold',12,false)
  for _,s in ipairs({-1,1})do Lc.ring(s*4,8,0,1.2,1.7,'lgGold',10,1.1)end
  for k=0,5 do local a=k*pi/3;K.plant(F(tb.cx+cos(a)*14,10.1,tb.cz+sin(a)*10,0),'flowers',{s=.35,potR=.9,potH=1.4,pot='white'})end
 end
 -- the club's posters: fans' favourites (a gallery of balls and stars)
 local Ln=K.onWall(C,'N',0,0)
 for _,c in ipairs(cellsOf(C,'p'))do
  local x=c[1]*CS+8
  K.picture(C,Ln,x-7,x+7,24,38,'pokemon',{frame='lgGold',mat=.8,body=({'gold','flower','ktCopper','leaf'})[c[1]%4+1]})
 end
 local Lw=K.onWall(C,'W',0,0);Town.WALLS.photos(C,Town.THEMES.VERMILION,Lw,64)
 local Le=K.onWall(C,'E',0,0);Town.WALLS.bunting(C,Town.THEMES.VERMILION,Le,48)
 K.rug(C,C.part('floor'),20,32,108,96,{field='inRugRed',border='inRugGold',pattern='oval'})
 C.addLight(64,40,60,140,.14)
end

------------------------------------------------------------------ SHIP HOUSES
-- The two houses built of the ship's timbers (Cerulean's badge house with
-- its back door, Fuchsia's Good Rod house by the pond).
function M.shipHouse(C)
 local fuchsia=C.id=='FUCHSIA_GOOD_ROD_HOUSE'
 local T=Town.theme(fuchsia and'FUCHSIA'or'CERULEAN')
 local St={H=48,paint=fuchsia and'cream'or'inPaperBlue',upper=fuchsia and'cream'or'inPaperBlue',wainscot='inWalnut',wainscotH=13,
  rail='lgBronze',cornice='inWalnut',cap='ktLime',floor=fuchsia and'inTatami'or'inChecker',ceiling='inPine',wood='inWalnut',
  plant=fuchsia and'bamboo'or'fern',pot='ktCopper',seat='stool',cushion=T.rug[1],view=2}
 local F,S=generic(C,St)
 local W=C.cw*CS
 local Ln=K.onWall(C,'N',0,0)
 -- portholes along the back wall
 for _,x in ipairs({W*.6,W*.85})do K.porthole(C,Ln,x,30,4.6,{view=fuchsia and 1 or 2})end
 -- the table's setting
 for _,tb in ipairs(groups(C,'T'))do
  local L=F(tb.cx,10.1,tb.cz,0)
  if fuchsia then
   L.box(-6,0,-3,6,.3,3,'inWalnut',1);L.quad({-5,.4,0},{0,.4,2.2},{4,.4,0},{0,.4,-2.2},'ktCopper',1.1)
  else
   L.cyl(-3,0,2,0,1.2,1.4,'white',8);L.box(2,0,-2,7,.2,2,'cream',1.15)
  end
 end
 if fuchsia then
  -- rods on the wall and a creel
  local Lw=K.onWall(C,'W',0,0)
  for k=0,3 do Lw.rod({30+k*8,8,.8},{36+k*8,44,.8},.3,k%2==0 and'inWalnut'or'ktSteel')end
  Town.WALLS.mounted(C,T,K.onWall(C,'E',0,0),60)
 else
  Town.WALLS.wheel(C,T,K.onWall(C,'W',0,0),64)
  Town.WALLS.anchor(C,T,K.onWall(C,'E',0,0),50)
 end
 K.rug(C,C.part('floor'),16,40,80,96,{field=T.rug[1],border=T.rug[2],pattern='stripes',inner=T.rug[2]})
 C.addLight(W/2,40,60,120,.12)
end

return M
