-- TEST174: SILPH CO. (InteriorRooms), Saffron City: the lobby, the ten
-- office floors, the president's floor.
-- Blue-grey carpet tiles, white walls with the company's blue band, glass
-- office partitions on steel mullions, windows over the city on every
-- outer wall, a ceiling of light panels. Workstations and server racks
-- with their status lights, desks with monitors and paperwork, conference
-- tables, storerooms of crates, the recovery beds, plants. The teleport
-- pads glow; the card-key doors are sliding steel with a reader beside
-- them, and they follow the live tiles (the room rebuilds when one opens).
-- The lobby has the reception desk under the company's name and an
-- indoor garden; the president's floor is walnut and marble, with the
-- meeting table and its golden centrepiece, the sofa, the desk.
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

local function gateAt(C,cx,cy)
 local t=C.tile(cx*2,cy*2)
 if t==8 then return'h'elseif t==36 then return'v'end
end

------------------------------------------------------------------ walls
-- a frame on a shell run (x along the face, +z into the room)
local function runFrame(C,run)
 local ox,oz,yaw
 if run.o=='S'then ox,oz,yaw=run.a0,run.c,0
 elseif run.o=='N'then ox,oz,yaw=run.a1,run.c,pi
 elseif run.o=='E'then ox,oz,yaw=run.c,run.a1,pi/2
 else ox,oz,yaw=run.c,run.a0,-pi/2 end
 return K.frame(C,run.E,ox,0,oz,yaw)
end
-- the world cell in front of a run's face at local x (the open side)
local function cellBefore(run,x)
 if run.o=='S'then return floor((run.a0+x)/CS),floor(run.c/CS)
 elseif run.o=='N'then return floor((run.a1-x)/CS),floor(run.c/CS)-1
 elseif run.o=='E'then return floor(run.c/CS),floor((run.a1-x)/CS)
 else return floor(run.c/CS)-1,floor((run.a0+x)/CS)end
end

------------------------------------------------------------------ pieces
-- a server rack or a workstation bank (Q), its top in the wall band (q)
local function rack(C,F,c,seed)
 local x,z=c[1]*CS+8,c[2]*CS+8
 local L=F(x,0,z,0)
 local kind=floor(rh(c[1],c[2],1)*3)
 L.box(-7.6,0,-8,7.6,34,6.4,'ktSteel',.95)
 L.box(-7.8,34,-8,7.8,35.4,6.8,'inEnamel',1.05)
 L.box(-7.2,0,6.4,7.2,2,6.8,'dark',.6)
 if kind==0 then
  -- a server rack: rows of blades, status lights
  for k=0,6 do
   local y=4+k*4.2
   L.box(-6.6,y,6.4,6.6,y+3.4,6.7,'navy',.9)
   L.raw({-6,y+1.2,6.75},{-6+1+rh(seed,k,2)*7,y+1.2,6.75},{-6+1+rh(seed,k,2)*7,y+1.9,6.75},{-6,y+1.2+.7,6.75},'inScreen',3)
  end
  C.fx.glows[#C.fx.glows+1]={x=x,y=18,z=z+8,r=7,col='green',a=.10}
 elseif kind==1 then
  -- a workstation: a screen, a keyboard shelf, the tape drive above
  L.box(-7.2,12,6.4,7.2,13,10,'inEnamel',1.05)
  L.box(-5.4,13,8,5.4,13.4,9.6,'ktPearl',1.1)
  L.raw({-6,15,6.45},{6,15,6.45},{6,25,6.45},{-6,25,6.45},'inScreen',1+seed%2)
  L.disc(-3.2,30,6.45,2.2,'dark',10);L.disc(3.2,30,6.45,2.2,'dark',10)
  C.fx.glows[#C.fx.glows+1]={x=x,y=20,z=z+9,r=8,col='cyan',a=.12}
 else
  -- a mainframe console: a field of lamps, two dials
  L.raw({-6.4,18,6.45},{6.4,18,6.45},{6.4,30,6.45},{-6.4,30,6.45},'inScreen',3)
  for k=0,5 do for j=0,1 do L.disc(-5+k*2,8+j*3,6.45,.55,({'red','gold','leaf'})[(k+j)%3+1],6,nil,1.3)end end
 end
 if C.is(c[1],c[2]-1,'q')then
  for k=0,1 do L.rod({-4+k*8,35.4,-6},{-4+k*8,48,-6},.9,'ktSteel')end
 end
end

-- a cabinet (K): tall filing cabinet, steel
local function cabinet(C,F,c)
 local L=F(c[1]*CS+8,0,c[2]*CS+8,0)
 L.box(-7,0,-7,7,32,7,'inEnamel',.95)
 for k=0,3 do
  L.box(-6.4,1+k*7.6,7,6.4,7.6+k*7.6,7.4,'ktPearl',1.0)
  L.box(-2,5.4+k*7.6,7.4,2,6,7.8,'inSteel',1.1)
 end
end

-- desks and tables (T groups): white tops on steel legs, the day's work
local function desk(C,F,g,seed)
 local x0,x1,z0,z1=g.x0*CS,(g.x1+1)*CS,g.y0*CS,(g.y1+1)*CS
 local L=F(0,0,0,0)
 local a0,a1,b0,b1=x0+1.6,x1-1.6,z0+1.6,z1-1.6
 L.box(a0,10.6,b0,a1,12,b1,'inEnamel',1.05)
 L.box(a0+.3,12,b0+.3,a1-.3,12.05,b1-.3,'ktPearl',1.1)
 for _,px in ipairs({a0+1,a1-1.8})do for _,pz in ipairs({b0+1,b1-1.8})do L.box(px,0,pz,px+.8,10.6,pz+.8,'inSteel',1)end end
 if b1-b0>40 then for _,px in ipairs({a0+1,a1-1.8})do L.box(px,0,(b0+b1)/2-.4,px+.8,10.6,(b0+b1)/2+.4,'inSteel',1)end end
 -- along the long side: a monitor every 22, papers, a mug, a pen pot
 local long=(b1-b0)>(a1-a0)
 local n=max(1,floor((long and(b1-b0)or(a1-a0))/22))
 for i=0,n-1 do
  local t=(i+.5)/n
  local mx,mz=long and(a0+a1)/2 or a0+(a1-a0)*t,long and b0+(b1-b0)*t or(a0 and(b0+b1)/2)
  local yaw=long and(rh(seed,i,1)<.5 and pi/2 or -pi/2)or 0
  local Lm=F(mx,12,mz,yaw)
  if rh(seed,i,3)<.75 then
   Lm.box(-3.4,0,-1.6,3.4,.4,.6,'inSteel',1)
   Lm.box(-.4,.4,-1.2,.4,3,-.6,'inSteel',1)
   Lm.box(-4.2,3,-1.4,4.2,8.6,-.6,'dark',.8)
   Lm.raw({-3.8,3.4,-.55},{3.8,3.4,-.55},{3.8,8.2,-.55},{-3.8,8.2,-.55},'inScreen',1+floor(rh(seed,i,4)*3))
   Lm.box(-3,0,1.4,3,.4,3.4,'ktPearl',1.1)
  else
   for k=0,2 do Lm.box(-3+k*.2,k*.3,-2+k*.4,2+k*.2,k*.3+.25,2+k*.4,'cream',1.15-k*.03)end
  end
  local Lp=F(mx+(long and 0 or 5),12,mz+(long and 6 or 0),0)
  if rh(seed,i,5)<.5 then Lp.cyl(0,0,2,0,.8,.8,({'white','blue','red'})[i%3+1],6)
  else Lp.box(-2,0,-1.4,2,.2,1.4,'white',1.15)end
  -- binders and a folder
  local Lb=F(mx+(long and(rh(seed,i,6)-.5)*4 or -6),12,mz+(long and -6 or(rh(seed,i,6)-.5)*4),long and pi/2 or 0)
  for k=0,2 do Lb.box(-1.6+k*1.2,0,-2.2,-.6+k*1.2,4.4,2.2,({'navy','red','leaf','gold'})[(i+k)%4+1],1.05)end
 end
end

-- crates (B groups off the lobby): the stores, stacked
local function crates(C,F,g,seed)
 for _,c in ipairs(g.cells)do
  local L=F(c[1]*CS+8,0,c[2]*CS+8,0)
  local s=c[1]*7+c[2]*3
  local h1=6+rh(s,1,1)*4
  local m=rh(s,1,2)<.5 and'ktSandstone'or'inOak'
  L.box(-7,0,-7,7,h1,7,m,.95)
  L.box(-7.2,h1-1,-7.2,7.2,h1,7.2,m,.85)
  L.box(-3,2,7,3,5,7.2,'white',1.15)
  if rh(s,2,1)<.6 then
   local h2=4+rh(s,2,2)*4
   local dx,dz=(rh(s,3,1)-.5)*3,(rh(s,3,2)-.5)*3
   L.box(-5+dx,h1,-5+dz,5+dx,h1+h2,5+dz,rh(s,2,3)<.5 and'ktSandstone'or'inEnamel',1)
   if rh(s,4,1)<.4 then L.box(-3,h1+h2,-3,3,h1+h2+3.4,3,'blue',1)end
  end
 end
end

-- the recovery beds (b): white frames, blue blankets, a monitor beside
local function bed(C,F,g)
 local x=(g.x0+g.x1+1)*CS/2;local z0,z1=g.y0*CS+2,(g.y1+1)*CS-2
 local L=F(x,0,(z0+z1)/2,0)
 local hd=(z1-z0)/2
 L.box(-6,0,-hd,6,5,hd,'inEnamel',1)
 L.box(-6,5,-hd,6,7,hd,'white',1.1)
 L.box(-5.4,7,-hd+.6,5.4,8.6,-hd+5,'white',1.15)
 L.box(-6.2,6,-hd+6,6.2,7.6,hd,'blue',1.0)
 L.box(-6,0,-hd-1,6,13,-hd,'inSteel',1)
 L.raw({-3,9,-hd-.05},{3,9,-hd-.05},{3,12.4,-hd-.05},{-3,12.4,-hd-.05},'inScreen',3)
end

-- a teleport pad (k): steel ring, a lit disc, the air over it shimmering
local function pad(C,c)
 local x,z=c[1]*CS+8,c[2]*CS+8
 local E=C.part('floor')
 local L=K.frame(C,E,x,.06,z,0)
 for i=0,15 do
  local a0,a1=i/16*pi*2,(i+1)/16*pi*2
  L.quad({cos(a0)*7,0,sin(a0)*7},{cos(a1)*7,0,sin(a1)*7},{cos(a1)*5.4,0,sin(a1)*5.4},{cos(a0)*5.4,0,sin(a0)*5.4},'inSteel',1.1)
  L.raw({cos(a0)*5.2,.01,sin(a0)*5.2},{cos(a1)*5.2,.01,sin(a1)*5.2},{cos(a1)*1.4,.01,sin(a1)*1.4},{cos(a0)*1.4,.01,sin(a0)*1.4},'inAqua',1)
 end
 for i=0,3 do local a=i*pi/2+pi/4
  L.raw({cos(a)*6,.02,sin(a)*6},{cos(a+.25)*6,.02,sin(a+.25)*6},{cos(a+.25)*6.8,.02,sin(a+.25)*6.8},{cos(a)*6.8,.02,sin(a)*6.8},'inPanel',1)end
 C.fx.glows[#C.fx.glows+1]={x=x,y=3,z=z,r=9,col='cyan',a=.22}
 C.fx.glows[#C.fx.glows+1]={x=x,y=14,z=z,r=6,col='cyan',a=.08}
end

-- a card-key door (live gate): steel leaves, a blue band, the reader
local function keyDoor(C,F,cx,cy,kind)
 local L=F(cx*CS+8,0,cy*CS+8,kind=='v'and pi/2 or 0)
 L.box(-8,0,-1.6,8,34,1.6,'inSteel',1)
 L.box(-.2,0,1.6,.2,34,1.8,'dark',.6)
 L.box(-8,20,1.6,8,22,1.75,'blue',1.05)
 L.box(-8.8,34,-2,8.8,36,2,'ktSteel',1.05)
 L.box(-8.8,0,-2,-8,36,2,'ktSteel',1);L.box(8,0,-2,8.8,36,2,'ktSteel',1)
 L.box(9,14,1.4,11.2,19,2.2,'dark',.8)
 L.disc(10.1,17.6,2.25,.5,'red',6,nil,1.4)
 local p=L.P({10.1,17.6,3})
 C.fx.glows[#C.fx.glows+1]={x=p[1],y=p[2],z=p[3],r=2.6,col='red',a=.4}
end

------------------------------------------------------------------ floors 1-10
function M.silph(C)
 local fl=tonumber(C.id:match('_(%d+)F$'))or 1
 local H=56;C.H=H
 C.ambient=.80;C.maxLight=1.45
 C.watchAll=true
 local W,D=C.cw*CS,C.ch*CS
 local function solid(cx,cy)return C.is(cx,cy,'Wq')end
 local function inner(cx,cy)return solid(cx,cy)and cx>0 and cy>0 and cx<C.cw-1 and cy<C.ch-1 end
 local blocked=function(cx,cy)local c=C.at(cx,cy);return c~=nil and not('.k^vEr'):find(c,1,true)end
 local S
 S=K.shell(C,{H=H,solid=solid,inner=inner,innerH=40,blocked=blocked,
  door=function(cx,cy,ox,oy)
   if not ox then return false end
   local off=cx<0 or cy<0 or cx>=C.cw or cy>=C.ch
   return off and oy==C.ch-1 and C.is(ox,oy,'r')
  end,
  paint='ktPearl',upper='white',wainscot='ktPearl',wainscotH=11,rail='blue',skirting='navy',cornice='white',cap='ktPearl',
  floor='dnCarpet',ceiling='white',innerPaint='ktPearl',
  style=function(L,len,run)
   -- the company's blue band, and windows over the city on the outer walls
   L.box(0,24,0,len,26,.4,'blue',1.0)
   if run.o=='N'then return end
   local Lf=runFrame(C,run)
   local step=run.o=='S'and 40 or 48
   local x=step/2
   while x<len-10 do
    local cx,cy=cellBefore(run,x)
    if C.is(cx,cy,'.k')and C.is(cellBefore(run,x-9),cy,'.k')and C.is(cellBefore(run,x+9),cy,'.k')then
     K.window(C,Lf,x-9,x+9,28,48,{frame='inSteel',view=3,curtain='blind',cloth='white',panes={2,1}})
    end
    x=x+step
   end
  end,
  innerStyle=function(L,len,run,Hi)
   -- frosted glass over a white panel, steel mullions every twelve
   L.quad({0,16,.06},{len,16,.06},{len,Hi-2.4,.06},{0,Hi-2.4,.06},'ktGlass',1.18)
   L.box(0,15,0,len,16.4,.5,'inSteel',1.05)
   L.box(0,Hi-2.6,0,len,Hi,.6,'inSteel',1.05)
   local m=12
   local x=m
   while x<len-2 do L.box(x-.4,16,0,x+.4,Hi-2.4,.5,'inSteel',1.05);x=x+m end
  end,ao=10})
 local R=C.part('room')
 local function F(x,y,z,yaw)return K.frame(C,R,x,y,z,yaw)end
 -- machines, cabinets, desks, beds, plants
 for i,c in ipairs(cellsOf(C,'Q'))do rack(C,F,c,i)end
 for _,c in ipairs(cellsOf(C,'K'))do cabinet(C,F,c)end
 for i,g in ipairs(groups(C,'T'))do desk(C,F,g,i*3+fl)end
 -- (each bed is a head cell and the cell below it)
 for _,c in ipairs(cellsOf(C,'b'))do
  if C.raw(c[1],c[2])==33 then bed(C,F,{x0=c[1],x1=c[1],y0=c[2],y1=c[2]+1})end
 end
 for _,g in ipairs(groups(C,'P'))do
  for cx=g.x0,g.x1 do
   K.plant(F(cx*CS+8,0,g.y1*CS+8,0),({'snake','ficus','monstera'})[(cx+g.y1+fl)%3+1],{s=1.2,pot='inEnamel',seed=cx*5+g.y1})
  end
 end
 for _,c in ipairs(cellsOf(C,'k'))do pad(C,c)end
 -- crates, or (in the lobby) the garden's low stone walls
 if fl==1 then
  local L=F(0,0,0,0)
  -- a marble kerb, a clipped hedge on it
  for _,c in ipairs(cellsOf(C,'B'))do
   local x0,z0=c[1]*CS,c[2]*CS
   L.box(x0+.3,0,z0+.3,x0+CS-.3,4,z0+CS-.3,'lgMarble',1)
   L.box(x0,4,z0,x0+CS,4.8,z0+CS,'ktPearl',1.08)
   L.box(x0+1.2,4.8,z0+1.2,x0+CS-1.2,11+rh(c[1],c[2],1)*1.5,z0+CS-1.2,'lgFoliage',1)
  end
  -- the garden: soil, flowers, low shrubs, two small trees
  local E=C.part('floor')
  for _,c in ipairs(cellsOf(C,'F'))do
   local x0,z0=c[1]*CS,c[2]*CS
   L.box(x0,0,z0,x0+CS,4.6,z0+CS,'lgBloom',.95,{bottom=true})
   local s=c[1]*11+c[2]*5
   if rh(s,9,1)<.35 then L.sphere(x0+8,6,z0+8,4.4,3.2,4.4,'lgFoliage',6,3,s)end
  end
  local fg=groups(C,'F')[1]
  if fg then
   for _,dx in ipairs({-.25,.25})do
    local tx=(fg.x0+fg.x1+1)*CS/2+(fg.x1-fg.x0+1)*CS*dx
    K.plant(F(tx,5,(fg.y0+fg.y1+1)*CS/2,0),'tree',{s=1.3,pot='forestFloor',potH=.6,potR=2,seed=floor(tx)})
   end
  end
 else
  for i,g in ipairs(groups(C,'B'))do crates(C,F,g,i)end
 end
 -- the counters (lobby reception; the 7F's lab bench)
 do
  local L=F(0,0,0,0)
  for _,c in ipairs(cellsOf(C,'C'))do
   local a0,a1,b0,b1=c[1]*CS,(c[1]+1)*CS,c[2]*CS,(c[2]+1)*CS
   local n,s,w,e=C.is(c[1],c[2]-1,'C'),C.is(c[1],c[2]+1,'C'),C.is(c[1]-1,c[2],'C'),C.is(c[1]+1,c[2],'C')
   local ia0,ia1=w and a0 or a0+2,e and a1 or a1-2
   local ib0,ib1=n and b0 or b0+2,s and b1 or b1-2
   L.box(ia0,0,ib0,ia1,13,ib1,'inEnamel',1)
   L.box(ia0,3,ib1,ia1,10,ib1+.3,'blue',1.0)
   L.box(ia0-.5,13,ib0-.5,ia1+.5,14.6,ib1+.5,'ktPearl',1.1)
  end
  if fl==1 then
   local cc=cellsOf(C,'C')
   for i,c in ipairs(cc)do
    if i%2==1 and not C.is(c[1],c[2]+1,'C')then
     local Lm=F(c[1]*CS+8,14.6,c[2]*CS+6,0)
     Lm.box(-3.4,0,-1.6,3.4,.4,.6,'inSteel',1);Lm.box(-4,3,-1.4,4,8.4,-.6,'dark',.8)
     Lm.raw({-3.6,3.4,-.55},{3.6,3.4,-.55},{3.6,8,-.55},{-3.6,8,-.55},'inScreen',1)
    end
   end
  end
 end
 -- the north band: the elevator, the stairs
 local Ln=K.onWall(C,'N',0,0)
 for _,c in ipairs(cellsOf(C,'E'))do
  local x0,x1=c[1]*CS,(c[1]+1)*CS
  local L=F(0,0,0,0)
  local z=c[2]*CS
  L.box(x0+1,0,z,x0+8,34,z+.8,'inSteel',1.05);L.box(x0+8,0,z,x1-1,34,z+.8,'inSteel',1.0)
  L.box(x0,34,z,x1,40,z+1.4,'ktSteel',1.05)
  L.raw({x0+4,35.5,z+1.45},{x1-4,35.5,z+1.45},{x1-4,38.5,z+1.45},{x0+4,38.5,z+1.45},'inScreen',3)
  L.box(x0-1.6,0,z,x0,40,z+2,'ktSteel',1);L.box(x1,0,z,x1+1.6,40,z+2,'ktSteel',1)
 end
 for _,c in ipairs(cellsOf(C,'^'))do
  K.stairsUp(C,R,c[1]*CS,(c[1]+1)*CS,c[2]*CS,(c[2]+1)*CS,{tread='dnCarpet',riser='ktPearl',rail='inSteel',side=c[1]*CS+1,n=4,top=14})
 end
 for _,c in ipairs(cellsOf(C,'v'))do
  K.stairsDown(C,R,c[1]*CS,(c[1]+1)*CS,c[2]*CS,(c[2]+1)*CS,{tread='dnCarpet',riser='ktPearl',wall='ktPearl',rail='inSteel',handrail='inSteel',nosing='inSteel',railX=c[1]*CS+.6})
 end
 -- the lobby: the doors, the name over reception
 if fl==1 then
  local x0,x1
  for cx=0,C.cw-1 do if C.is(cx,C.ch-1,'r')then x0=x0 and min(x0,cx)or cx;x1=x1 and max(x1,cx)or cx end end
  if x0 then K.exitPortal(C,'S',x0*CS,(x1+1)*CS,{view=3,frame='inSteel',glassDoors=true})end
  Ln.box(16,38,0,104,50,.8,'navy',1)
  LA().inscription(Ln,'SILPH CO.',60,40.6,.85,1.5,'white',80)
  -- a mat inside the doors
  if x0 then K.rug(C,C.part('floor'),x0*CS+2,D-30,(x1+1)*CS-2,D-2,{field='navy',border='blue',bw=1,y=.1})end
 else
  -- the floor's number by the stairs
  local sx
  for _,c in ipairs(cellsOf(C,'^v'))do sx=c[1]*CS end
  if sx then Ln.box(sx-26,30,16,sx-8,44,17,'navy',1);LA().inscription(Ln,tostring(fl)..'F',sx-17,33.5,17.05,1.2,'white',14)end
 end
 -- the card-key doors (live)
 for cy=0,C.ch-1 do for cx=0,C.cw-1 do
  local g=gateAt(C,cx,cy);if g then keyDoor(C,F,cx,cy,g)end
 end end
 -- light panels overhead (seen from under them) and the lights they give
 do
  local E=C.part('ceilfx',{below=H+2})
  local L=K.frame(C,E,0,0,0,0)
  for x=40,W-24,64 do for z=40,D-24,48 do
   if not solid(floor(x/CS),floor(z/CS))then
    L.raw({x-10,H-.4,z-5},{x+10,H-.4,z-5},{x+10,H-.4,z+5},{x-10,H-.4,z+5},'inPanel',1)
    C.addLight(x,H-8,z,64,.12)
   end
  end end
 end
 C.fx.ambience={hum=.16,hall=.12}
end

------------------------------------------------------------------ 11F
-- The president's floor: walnut panelling and marble, the city beyond the
-- windows, the meeting table with its golden centrepiece, the sofa under
-- the painting, the desk and its terminal.
function M.office(C)
 local H=58;C.H=H
 C.ambient=.80;C.maxLight=1.45
 local W,D=C.cw*CS,C.ch*CS
 local function solid(cx,cy)return C.is(cx,cy,'WVp')end
 local function inner(cx,cy)return C.is(cx,cy,'Wp')and cx>0 and cy>0 and cx<C.cw-2 and cy<C.ch-1 end
 local blocked=function(cx,cy)local c=C.at(cx,cy);return c~=nil and not('.skvE'):find(c,1,true)end
 local S=K.shell(C,{H=H,solid=solid,inner=inner,innerH=44,blocked=blocked,
  paint='inWalnut',upper='ktPearl',wainscot='inWalnut',wainscotH=16,rail='lgGold',skirting='inWalnut',cornice='lgGold',cap='inWalnut',
  floor='lgMarble',ceiling='white',innerPaint='inWalnut',
  style=function(L,len,run)
   if run.o=='N'then return end
   local Lf=runFrame(C,run)
   local x=24
   while x<len-14 do
    local cx,cy=cellBefore(run,x)
    if C.is(cx,cy,'.')then K.window(C,Lf,x-10,x+10,26,50,{frame='lgGold',view=3,curtain='drape',cloth='navy',panes={2,2}})end
    x=x+48
   end
  end,
  innerStyle=function(L,len,run,Hi)
   L.box(0,Hi-2.4,0,len,Hi,.8,'lgGold',1.08)
   L.box(0,15.4,0,len,16.4,.7,'lgGold',1.05)
   local x=8
   while x<len-4 do L.box(x-.3,1,0,x+.3,15,.4,'inWalnut',.8);x=x+16 end
  end,ao=10})
 local R=C.part('room')
 local function F(x,y,z,yaw)return K.frame(C,R,x,y,z,yaw)end
 -- the meeting table: an octagon of dark wood, its gilt centrepiece
 for _,g in ipairs(groups(C,'T'))do
  local x,z=(g.x0+g.x1+1)*CS/2,(g.y0+g.y1+1)*CS/2
  local L=F(x,0,z,0)
  local r=(g.x1-g.x0+1)*CS/2-2
  L.cyl(0,0,9,0,r*.35,r*.35,'inWalnut',8,false,pi/8)
  L.cyl(0,9,11.6,0,r,r,'inWalnut',8,true,pi/8)
  L.cyl(0,11.6,11.7,0,r-1.2,r-1.2,'lgMarble',8,true,pi/8)
  L.cyl(0,11.7,13.4,0,5.4,5.4,'lgGold',8,true,pi/8)
  L.cyl(0,13.4,16,0,2.4,3.4,'lgGold',8,false)
  L.sphere(0,19,0,3.4,3.4,3.4,'lgGold',8,5)
  for k=0,3 do local a=k*pi/2+pi/4;L.rod({cos(a)*1.4,16,sin(a)*1.4},{cos(a)*3.4,22.4,sin(a)*3.4},.35,'lgGold')end
  C.fx.glows[#C.fx.glows+1]={x=x,y=19,z=z,r=9,col='gold',a=.14}
 end
 -- the sofa under the painting
 for _,g in ipairs(groups(C,'U'))do
  local x0,x1=g.x0*CS,(g.x1+1)*CS
  local z0=g.y0*CS
  local L=F(0,0,0,0)
  L.box(x0+1,0,z0+2,x1-1,6,z0+14,'inLeather',1)
  L.box(x0+1,6,z0+2,x1-1,17,z0+6,'inLeather',1.02)
  L.box(x0-1,0,z0+2,x0+2,11,z0+14,'inLeather',.95);L.box(x1-2,0,z0+2,x1+1,11,z0+14,'inLeather',.95)
  for k=0,2 do local cx=x0+3+k*(x1-x0-6)/3;L.box(cx+.3,6,z0+6,cx+(x1-x0-6)/3-.3,8,z0+13.6,'inLeather',1.06)end
 end
 for _,c in ipairs(cellsOf(C,'p'))do
  local L=F(c[1]*CS+8,0,(c[2]+1)*CS,0)
  K.picture(C,L,-12,12,22,40,'mountain',{frame='lgGold'})
 end
 -- the desk and its terminal
 for _,g in ipairs(groups(C,'D'))do
  local x0,x1,z0,z1=g.x0*CS,(g.x1+1)*CS,g.y0*CS,(g.y1+1)*CS
  local L=F((x0+x1)/2,0,(z0+z1)/2,0)
  K.table(L,x1-x0-2,z1-z0-3,12,'desk',{wood='inWalnut'})
  local Lm=F((x0+x1)/2+5,12,(z0+z1)/2-2,0)
  Lm.box(-4,0,-2.4,4,.6,2,'inEnamel',1)
  Lm.box(-3.6,.6,-2,3.6,7.6,1,'inEnamel',1.02)
  Lm.raw({-3,1.2,1.05},{3,1.2,1.05},{3,7,1.05},{-3,7,1.05},'inScreen',3)
  local Lb=F((x0+x1)/2-6,12,(z0+z1)/2,0)
  Lb.box(-3,0,-2,3,.6,2,'inLeather',1);Lb.cyl(4.6,0,2.6,1,.9,.9,'lgGold',8)
 end
 for _,c in ipairs(cellsOf(C,'s'))do
  K.seat(F(c[1]*CS+8,0,c[2]*CS+8,0),6,'modern','s',{wood='inSteel',cushion='inLeather'})
 end
 for _,c in ipairs(cellsOf(C,'k'))do pad(C,c)end
 for _,c in ipairs(cellsOf(C,'v'))do
  K.stairsDown(C,R,c[1]*CS,(c[1]+1)*CS,c[2]*CS,(c[2]+1)*CS,{tread='inWalnut',riser='ktPearl',wall='ktPearl',rail='lgGold',handrail='inWalnut',nosing='lgGold',railX=c[1]*CS+.6})
 end
 for _,c in ipairs(cellsOf(C,'E'))do
  local x0,x1=c[1]*CS,(c[1]+1)*CS;local z=c[2]*CS
  local L=F(0,0,0,0)
  L.box(x0+1,0,z,x1-1,34,z+.8,'lgGold',1.0);L.box(x0+7.8,0,z+.8,x0+8.2,34,z+.9,'dark',.6)
  L.box(x0-1.6,0,z,x0,40,z+2,'inWalnut',1);L.box(x1,0,z,x1+1.6,40,z+2,'inWalnut',1)
  L.box(x0,34,z,x1,40,z+1.4,'inWalnut',1.05)
 end
 -- a carpet under the table, plants by the windows
 local tg=groups(C,'T')[1]
 if tg then K.rug(C,C.part('floor'),tg.x0*CS-14,tg.y0*CS-12,(tg.x1+1)*CS+14,(tg.y1+1)*CS+14,{field='inRugRed',border='inRugGold',pattern='medallion',fringe='cream'})end
 do
  local E=C.part('ceilfx',{below=H+2})
  local L=K.frame(C,E,0,0,0,0)
  for x=48,W-32,64 do for z=48,D-32,64 do
   if not solid(floor(x/CS),floor(z/CS))then
    L.raw({x-8,H-.4,z-8},{x+8,H-.4,z-8},{x+8,H-.4,z+8},{x-8,H-.4,z+8},'inPanel',1)
    C.addLight(x,H-8,z,70,.13)
   end
  end end
 end
 C.fx.ambience={hall=.15,hum=.06}
end

return M
