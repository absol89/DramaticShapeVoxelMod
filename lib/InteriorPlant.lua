-- TEST174: THE POWER PLANT (InteriorRooms), Route 10, long abandoned.
-- Tread-plate floors, painted block walls with a steel kick plate and a
-- hazard rail, conduit and junction boxes along every wall, caged lamps
-- (the few still lit), warning signs. The transformer banks stand in rows
-- on their plinths, porcelain insulators and bus bars on top, red lamps on
-- their fronts, sparks still jumping here and there; hazard stripes on the
-- floor round them. The generators' control consoles line the walls under
-- their gauge boards; tall breaker cabinets; heaps of broken concrete and
-- scrap where the roof and the machinery came down. In the west room the
-- floor is scorched in branching lightning round the place the legendary
-- bird roosts (the bird itself is the game's own sprite).
-- Every model stands on a cell the game blocks; the walkable floor is flat.
local V=...
local M={}
local K=V.require('InteriorKit')
local Town=V.require('InteriorTown')
local pi,cos,sin,floor,min,max,abs,sqrt=math.pi,math.cos,math.sin,math.floor,math.min,math.max,math.abs,math.sqrt
local rh=K.rh
local CS=16
local groups,cellsOf=Town.groups,Town.cellsOf

function M.support(id,ch)return 0 end

-- caps on what the room asks of the frame: lamps that light, glows drawn
local MAXLIGHT,MAXGLOW=30,18

------------------------------------------------------------------ walls
-- a warning sign: a yellow triangle, a black bolt (frame: +z out)
local function sign(L,x,y,z,s)
 s=s or 1
 L.quad({x-4.4*s,y-3.6*s,z},{x+4.4*s,y-3.6*s,z},{x,y+4*s,z},{x,y+4*s,z},'dark',1)
 L.quad({x-3.6*s,y-3.1*s,z+.05},{x+3.6*s,y-3.1*s,z+.05},{x,y+3.2*s,z+.05},{x,y+3.2*s,z+.05},'gold',1.15)
 L.quad({x+.2*s,y+2.2*s,z+.1},{x+1*s,y+2.2*s,z+.1},{x-.1*s,y-.2*s,z+.1},{x-.9*s,y-.2*s,z+.1},'dark',.9)
 L.quad({x-.6*s,y+.2*s,z+.1},{x+.9*s,y+.2*s,z+.1},{x-.2*s,y-2.4*s,z+.1},{x-.2*s,y-2.4*s,z+.1},'dark',.9)
end

-- conduit, junction boxes, breaker boxes, signs and caged lamps along a
-- wall face (frame: x along, y up, +z into the room), Hh its height
local function services(C,st,len,Hh,seed,run,outer)
 -- (the shell's own wall frame draws faces only: an interior frame on the
 -- same part, in the same axes, for the rest)
 local ox,oz,yaw
 if run.o=='S'then ox,oz,yaw=run.a0,run.c,0
 elseif run.o=='N'then ox,oz,yaw=run.a1,run.c,pi
 elseif run.o=='E'then ox,oz,yaw=run.c,run.a1,pi/2
 else ox,oz,yaw=run.c,run.a0,-pi/2 end
 local L=K.frame(C,run.E,ox,0,oz,yaw)
 -- two conduits under the top, on brackets
 L.rod({0,Hh-8,1.4},{len,Hh-8,1.4},.75,'ktSteel')
 L.rod({0,Hh-11.5,1.1},{len,Hh-11.5,1.1},.5,'dnRust')
 for x=12,len-4,32 do L.box(x-.5,Hh-13,0,x+.5,Hh-6.6,2.2,'ktBasalt',.9)end
 local x=18+rh(seed,1,1)*24
 local i=0
 while x<len-10 do
  local k=rh(seed,i,2)
  if k<.30 then
   -- a junction box, its conduit dropping to a socket by the kick plate
   L.box(x-3.2,Hh-17,0,x+3.2,Hh-7,2.6,'ktSteel',.95)
   L.box(x-2.6,Hh-16.4,2.6,x+2.6,Hh-7.6,2.8,'slate',.9)
   L.rod({x,Hh-17,1.3},{x,14,1.3},.45,'ktSteel')
   L.box(x-2,10.6,0,x+2,15,2,'inSteel',.9)
  elseif k<.50 then
   sign(L,x,Hh*.56,.12,1)
  elseif k<.68 then
   -- a breaker box, its handle down (red) or up (green)
   L.box(x-4.5,16,0,x+4.5,30,2.2,'inSteel',.88)
   L.quad({x-4.3,16.3,2.25},{x+4.3,16.3,2.25},{x+4.3,29.7,2.25},{x-4.3,29.7,2.25},'slate',.85)
   local up=rh(seed,i,4)<.4
   L.box(x+2.4,up and 24 or 19,2.2,x+3.4,up and 28 or 23,3,up and'green'or'red',1.05)
   sign(L,x-1,26,2.3,.42)
  elseif k<.80 then
   -- a stencilled unit plate
   L.quad({x-6,Hh*.48-2.6,.1},{x+6,Hh*.48-2.6,.1},{x+6,Hh*.48+2.6,.1},{x-6,Hh*.48+2.6,.1},'white',.85)
   for j=0,3 do
    local a=x-5+j*2.8
    L.quad({a,Hh*.48-1.6,.15},{a+1.8,Hh*.48-1.6,.15},{a+1.8,Hh*.48+1.6,.15},{a,Hh*.48+1.6,.15},'dark',.8)
   end
  end
  x=x+36+rh(seed,i,3)*36;i=i+1
 end
 -- caged lamps; the ones still lit throw a pool of light, and the ones on
 -- the walls the eye faces glow
 local lx=40+rh(seed,5,5)*40
 while lx<len-20 do
  local y=Hh-20
  L.box(lx-.6,y+1.6,0,lx+.6,y+4,2.6,'ktBasalt',.9)
  L.box(lx-2.6,y-1.8,1.4,lx+2.6,y+1.8,4.8,'ktSteel',.8,{bottom=true,s=true,top=false})
  local lit=rh(seed,lx,6)<.78
  L.raw({lx-2.2,y-1.4,4.7},{lx+2.2,y-1.4,4.7},{lx+2.2,y+1.4,4.7},{lx-2.2,y+1.4,4.7},lit and'inLamp'or'dark',1)
  L.raw({lx-2.2,y-1.5,1.6},{lx+2.2,y-1.5,1.6},{lx+2.2,y-1.5,4.6},{lx-2.2,y-1.5,4.6},lit and'inLamp'or'dark',1)
  for _,bx in ipairs({-1.4,0,1.4})do L.rod({lx+bx,y-1.8,4.9},{lx+bx,y+1.8,4.9},.18,'ktBasalt')end
  if lit then
   local p=L.P({lx,y,8})
   local far=true
   for _,q in ipairs(st.lamps)do if(q[1]-p[1])^2+(q[3]-p[3])^2<80*80 then far=false;break end end
   if far and #st.lamps<MAXLIGHT then
    st.lamps[#st.lamps+1]=p
    C.addLight(p[1],p[2],p[3],110,.30)
    if run.o=='S'and outer and st.glows<MAXGLOW then
     st.glows=st.glows+1
     C.fx.glows[#C.fx.glows+1]={x=p[1],y=p[2],z=p[3]-3,r=7,col='warm',a=.20}
    end
   end
  end
  lx=lx+104+rh(seed,lx,7)*40
 end
end

------------------------------------------------------------------ pieces
-- a heap of broken concrete and scrap on one cell
local function heap(C,F,cx,cy)
 local x,z=cx*CS+8,cy*CS+8
 local L=F(x,0,z,0)
 local s=cx*13+cy*7
 local shut=C.is(cx-1,cy,'RW')and C.is(cx+1,cy,'RW')and C.is(cx,cy-1,'RW')and C.is(cx,cy+1,'RW')
 local n=shut and 1 or 2
 for i=0,n-1 do
  local a=rh(s,i,1)*pi*2;local r=shut and 1 or rh(s,i,2)*4
  local rx=shut and 8.6 or(4.4+rh(s,i,3)*3);local ry=shut and(4.5+rh(s,i,4)*3)or(3+rh(s,i,4)*4)
  local m=({'lgRock','stone','lgRock','slate','ktBasalt','lgRock','ktPlaster'})[1+floor(rh(s,i,5)*7)]
  if i==0 then L.sphere(cos(a)*r,ry*.4,sin(a)*r,rx,ry,rx*.9,m,6,3,s+i,'lgRock')
  else L.sphere(cos(a)*r,ry*.4,sin(a)*r,rx,ry,rx*.9,m,5,2,s+i)end
 end
 -- rebar out of the broken slabs
 if rh(s,6,1)<.3 then
  for k=0,1 do
   local a=rh(s,k,40)*pi*2
   local bx,bz=cos(a)*2.5,sin(a)*2.5
   L.rod({bx,2,bz},{bx+cos(a)*2,8+rh(s,k,41)*4,bz+sin(a)*2},.25,'dnRust')
  end
 end
 if shut then return end
 local k=rh(s,7,1)
 if k<.30 then
  -- a bent girder across the heap
  local a=rh(s,8,1)*pi
  L.rod({-cos(a)*9,1+rh(s,8,2)*2,-sin(a)*7},{cos(a)*2,4+rh(s,8,3)*3,sin(a)*2},1.1,'dnRust')
  L.rod({cos(a)*2,4+rh(s,8,3)*3,sin(a)*2},{cos(a+.5)*8,2,sin(a+.5)*8},1.1,'dnRust')
 elseif k<.50 then
  -- a sheet of tread plate, buckled and propped
  L.quad({-6,.4,-3},{5,.6,-4},{6,5.6,1},{-5,5,2},'dnPlate',1)
  L.quad({-5,5,2.1},{6,5.6,1.1},{5,.6,-3.9},{-6,.4,-2.9},'dnRust',.7)
 elseif k<.65 then
  -- a length of broken pipe jutting from the heap, open-ended
  local a=rh(s,9,1)*pi*2
  L.cyl(cos(a)*3,0,7+rh(s,9,2)*5,sin(a)*3,2.2,2.2,'dnRust',6,'dark')
 elseif k<.78 then
  -- a coil of cable
  L.ring(0,3.2,0,2.6,4.2,'dark',8,1)
 end
 -- concrete crumbs round the foot
 for i=0,1 do
  local bx,bz=-6+rh(s,i,30)*12,-6+rh(s,i,31)*12
  L.box(bx-1.4,0,bz-.8,bx+1.4,1.1,bz+.8,'stone',.9,{bottom=true,n=true,w=true})
 end
end

-- a transformer on its plinth: finned tank, insulators, the red lamp
local function transformer(C,F,st,cx,cy)
 local x,z=cx*CS+8,cy*CS+8
 local L=F(x,0,z,0)
 local function isB(dx,dy)return C.is(cx+dx,cy+dy,'B')end
 local e,w,s_,n_=isB(1,0),isB(-1,0),isB(0,1),isB(0,-1)
 L.box(w and -8 or -7.4,0,n_ and -8 or -7.4,e and 8 or 7.4,1.6,s_ and 8 or 7.4,'ktBasalt',.8)
 local tank=rh(cx,cy,3)<.5 and'slate'or'ktSteel'
 L.box(-6,1.6,-5.6,6,17,5.6,tank,.92)
 L.box(-6.4,17,-6,6.4,18.2,6,'ktSteel',1.0)
 -- the cooling fins on the faces the floor sees
 if not s_ then for k=0,3 do local fx=-4.5+k*3;L.box(fx-.35,3,5.6,fx+.35,15,7.2,tank,.75,{bottom=true,n=true})end end
 if not e then for k=0,1 do local fz=-2.5+k*5;L.box(6,3,fz-.35,7.6,15,fz+.35,tank,.75,{bottom=true,w=true})end end
 if not w then for k=0,1 do local fz=-2.5+k*5;L.box(-7.6,3,fz-.35,-6,15,fz+.35,tank,.75,{bottom=true,e=true})end end
 -- two porcelain insulators with a shed each
 for _,ix in ipairs({-3.4,3.4})do
  L.cyl(ix,18.2,25,0,1.0,.7,'white',6,false)
  L.disc(ix,21.4,0,2.0,'white',6,'y',1.05)
  L.box(ix-.5,25,-.5,ix+.5,26,.5,'lgBronze',1.05)
 end
 -- bus bars to the next tank along
 if e then L.rod({3.4,25.5,0},{16-3.4,25.5,0},.45,'lgBronze')end
 if s_ and rh(cx,cy,9)<.5 then L.rod({3.4,25.5,0},{3.4,25.5,16},.4,'lgBronze')end
 -- the red lamp, still lit on most; a rating plate; a sign on some
 if not s_ then
  local on=rh(cx,cy,4)<.7
  L.box(2.6,12,5.6,5.4,14.8,6.4,'ktBasalt',.9)
  L.quad({2.9,12.3,6.45},{5.1,12.3,6.45},{5.1,14.5,6.45},{2.9,14.5,6.45},on and'lgLava'or'dark',1)
  L.quad({-5,8,5.65},{0,8,5.65},{0,11,5.65},{-5,11,5.65},'white',.8)
  if rh(cx,cy,5)<.3 then sign(L,-2.4,14.4,5.7,.55)end
  if on and st.glows<MAXGLOW and rh(cx,cy,6)<.35 then
   st.glows=st.glows+1
   C.fx.glows[#C.fx.glows+1]={x=x+4,y=13.4,z=z+7,r=3.4,col='red',a=.32}
  end
 end
end

-- a generator's control console against the wall, its gauge board above
local function console(C,F,st,c,i)
 local x,z=c[1]*CS+8,c[2]*CS+8
 local back=C.is(c[1],c[2]-1,'Wq')
 local L=F(x,0,z,0)
 local we,ea=C.is(c[1]-1,c[2],'Q'),C.is(c[1]+1,c[2],'Q')
 L.box(we and -8 or -7.6,0,-8,ea and 8 or 7.6,24,5.4,'slate',.9)
 L.box(we and -8 or -7.8,24,-8,ea and 8 or 7.8,25.4,6,'ktSteel',1)
 -- the desk: a sloped panel
 L.quad({we and -8 or -7.6,14,5.4},{ea and 8 or 7.6,14,5.4},{ea and 8 or 7.6,18,2},{we and -8 or -7.6,18,2},'ktBasalt',.95)
 local kind=floor(rh(c[1],c[2],1)*3)
 if kind==0 then
  -- two dial gauges
  for _,gx in ipairs({-3.6,3.6})do
   L.disc(gx,20.6,5.45,2.6,'white',10)
   L.ring(gx,20.6,5.5,2.6,3.1,'ktBasalt',10)
   local a=rh(c[1]+gx,c[2],2)*2.4+.4
   L.quad({gx,20.6,5.55},{gx+.25,20.6,5.55},{gx+cos(a)*2.1,20.6+sin(a)*2.1,5.55},{gx+cos(a)*2.1,20.6+sin(a)*2.1,5.55},'red',1)
  end
 elseif kind==1 then
  -- an oscilloscope, the trace still running
  L.raw({-5.6,18.4,5.45},{1.6,18.4,5.45},{1.6,23.4,5.45},{-5.6,23.4,5.45},'inScreen',3)
  for k=0,2 do L.disc(4.4,19+k*1.8,5.5,.7,'ktSteel',6)end
  if st.glows<MAXGLOW then
   st.glows=st.glows+1
   local p=L.P({-2,21,7});C.fx.glows[#C.fx.glows+1]={x=p[1],y=p[2],z=p[3],r=6,col='green',a=.14}
  end
 else
  -- a bank of indicator lamps
  for r=0,1 do for k=0,4 do
   local lit=rh(c[1]*5+k,c[2]+r,3)<.55
   L.quad({-5.6+k*2.6,19+r*2.4,5.45},{-4.2+k*2.6,19+r*2.4,5.45},{-4.2+k*2.6,20.4+r*2.4,5.45},{-5.6+k*2.6,20.4+r*2.4,5.45},
    lit and(k%2==0 and'lgLava'or'inLamp')or'dark',1)
  end end
 end
 -- switches on the desk, the vents below
 for k=0,3 do L.box(-5+k*3.2,15.4,4.2,-4+k*3.2,16.6,5,(k%2==0)and'red'or'ktSteel',1)end
 for k=0,2 do L.quad({-6,3+k*2.6,5.45},{6,3+k*2.6,5.45},{6,4.2+k*2.6,5.45},{-6,4.2+k*2.6,5.45},'dark',.7)end
 if back then
  -- the gauge board on the wall above, the cable runs up to the conduit
  L.box(-7,28,-8,7,42,-7,'slate',.9)
  for k=0,2 do
   local gx=-4.4+k*4.4
   L.disc(gx,37,-6.9,1.7,'white',8)
   local a=rh(c[1],c[2]+k,8)*2.6+.3
   L.quad({gx,37,-6.85},{gx+.2,37,-6.85},{gx+cos(a)*1.4,37+sin(a)*1.4,-6.85},{gx+cos(a)*1.4,37+sin(a)*1.4,-6.85},'red',1)
  end
  L.quad({-6,30,-6.95},{6,30,-6.95},{6,32.6,-6.95},{-6,32.6,-6.95},'white',.8)
  L.rod({-5.6,42,-7.4},{-5.6,C.H-8,-7.4},.6,'ktSteel')
  L.rod({5.6,42,-7.4},{5.6,C.H-8,-7.4},.6,'dnRust')
 end
end

-- a tall breaker cabinet along a group of cells, facing the open side
local function cabinet(C,F,g)
 local x0,x1,z0,z1=g.x0*CS,(g.x1+1)*CS,g.y0*CS,(g.y1+1)*CS
 local cx,cz=(x0+x1)/2,(z0+z1)/2
 local len=(g.x1-g.x0==0)and(z1-z0)or(x1-x0)
 local alongZ=g.x1-g.x0==0 and g.y1>g.y0
 local yaw
 if alongZ then
  yaw=C.is(g.x0-1,g.y0,'Wq')and pi/2 or -pi/2
 else
  yaw=C.is(g.x0,g.y0-1,'Wq')and 0 or pi
 end
 local L=F(cx,0,cz,yaw)
 local h=len/2-.6
 L.box(-h,0,-7.6,h,40,5,'ktSteel',.88)
 L.box(-h-.4,40,-7.8,h+.4,41.4,5.4,'slate',.95)
 -- doors, handles, vents, the sign
 local nd=max(1,floor(len/12))
 for k=0,nd-1 do
  local a=-h+k*(2*h/nd)
  L.quad({a+.2,1.4,5.05},{a+2*h/nd-.2,1.4,5.05},{a+2*h/nd-.2,38.6,5.05},{a+.2,38.6,5.05},'inSteel',.9)
  L.box(a+2*h/nd-2.6,18,5,a+2*h/nd-1.6,24,5.8,'ktBasalt',1)
  for v=0,3 do L.quad({a+2,30+v*1.6,5.1},{a+2*h/nd-4,30+v*1.6,5.1},{a+2*h/nd-4,30.8+v*1.6,5.1},{a+2,30.8+v*1.6,5.1},'dark',.7)end
 end
 sign(L,0,24,5.2,.9)
 L.quad({-h,0,5.2},{h,0,5.2},{h,1.2,5.2},{-h,1.2,5.2},'dnHazard',1)
end

------------------------------------------------------------------ the room
function M.plant(C)
 local H=56;C.H=H
 C.ambient=.48;C.maxLight=1.35
 local W,D=C.cw*CS,C.ch*CS
 local st={lamps={},glows=0}
 C.fx.glows=C.fx.glows or{}
 local function solid(cx,cy)return C.is(cx,cy,'Wq')end
 local function inner(cx,cy)
  return solid(cx,cy)and cx>0 and cy>0 and cx<C.cw-1 and cy<C.ch-1
 end
 local blocked=function(cx,cy)local c=C.at(cx,cy);return c~=nil and not('.r'):find(c,1,true)end
 -- (the exits: the front doors south, the side door west)
 local S=K.shell(C,{H=H,solid=solid,inner=inner,innerH=44,blocked=blocked,
  door=function(cx,cy,ox,oy)
   if not ox then return false end
   local off=cx<0 or cy<0 or cx>=C.cw or cy>=C.ch
   if not off then return false end
   if cy>=C.ch then return C.is(ox,oy,'r')end
   if cx<0 then return C.is(ox,oy,'.')end
   return false
  end,
  paint='dnBlock',upper='dnBlock',wainscot='ktSteel',wainscotH=10,rail='dnHazard',
  skirting='ktBasalt',cornice='ktSteel',cap='ktBasalt',floor='dnPlate',floorT=.86,
  ceiling=false,innerPaint='dnBlock',
  style=function(L,len,run)
   services(C,st,len,H,run.a0*.37+run.c*.11,run,true)
  end,
  innerStyle=function(L,len,run,Hi)
   -- the kick plate and the hazard rail, as on the outer walls
   L.quad({0,0,.06},{len,0,.06},{len,10,.06},{0,10,.06},'ktSteel',.9)
   L.box(0,9.4,0,len,10.8,1.1,'dnHazard',1.05)
   services(C,st,len,Hi,run.a0*.29+run.c*.17,run,false)
  end,ao=10})
 local R=C.part('room')
 local function F(x,y,z,yaw)return K.frame(C,R,x,y,z,yaw)end
 -- the floor: hazard stripes round the machines, oil, drains, the scorch
 do
  local E=C.part('floor')
  local L=K.frame(C,E,0,.06,0,0)
  local function open(cx,cy)return C.is(cx,cy,'.r')end
  for cy=0,C.ch-1 do for cx=0,C.cw-1 do
   if C.is(cx,cy,'BQK')then
    local x0,z0=cx*CS,cy*CS
    if open(cx,cy+1)then L.quad({x0,0,z0+CS},{x0+CS,0,z0+CS},{x0+CS,0,z0+CS+2.6},{x0,0,z0+CS+2.6},'dnHazard',.9)end
    if C.at(cx,cy)=='B'then
     if open(cx,cy-1)then L.quad({x0,0,z0-2.6},{x0+CS,0,z0-2.6},{x0+CS,0,z0},{x0,0,z0},'dnHazard',.9)end
     if open(cx-1,cy)then L.quad({x0-2.6,0,z0},{x0,0,z0},{x0,0,z0+CS},{x0-2.6,0,z0+CS},'dnHazard',.9)end
     if open(cx+1,cy)then L.quad({x0+CS,0,z0},{x0+CS+2.6,0,z0},{x0+CS+2.6,0,z0+CS},{x0+CS,0,z0+CS},'dnHazard',.9)end
    end
   elseif C.is(cx,cy,'.')then
    local k=rh(cx,cy,40)
    if k<.045 then
     -- an oil stain
     local x,z=cx*CS+4+rh(cx,cy,41)*8,cy*CS+4+rh(cx,cy,42)*8
     local r=2.4+rh(cx,cy,43)*3.4
     for q=0,5 do
      local a0,a1=q/6*pi*2,(q+1)/6*pi*2
      local r0,r1=r*(.7+.5*rh(cx*6+q,cy,44)),r*(.7+.5*rh(cx*6+(q+1)%6,cy,44))
      L.quad({x,0,z},{x+cos(a1)*r1,0,z+sin(a1)*r1},{x+cos(a0)*r0,0,z+sin(a0)*r0},{x,0,z},'ktBasalt',.72)
     end
    elseif k<.085 then
     -- a drain grate
     local x,z=cx*CS+5,cy*CS+5
     L.quad({x,0,z},{x+6,0,z},{x+6,0,z+6},{x,0,z+6},'dark',.35)
     for b=0,3 do L.quad({x+.6+b*1.5,.02,z+.4},{x+1.2+b*1.5,.02,z+.4},{x+1.2+b*1.5,.02,z+5.6},{x+.6+b*1.5,.02,z+5.6},'ktSteel',.8)end
    end
   end
  end end
  -- the scorch round the roost (west room): lightning burnt into the plate
  local zx,zz=4*CS+8,9*CS+8
  for b=0,8 do
   local a=b/9*pi*2+rh(b,1,1)*.5
   local px,pz=zx+cos(a)*6,zz+sin(a)*6
   local wdt=1.2
   for sgm=1,5 do
    a=a+(rh(b,sgm,2)-.5)*1.1
    local l=5+rh(b,sgm,3)*7
    local nx,nz=px+cos(a)*l,pz+sin(a)*l
    if nx<CS+1 or nx>8*CS-1 or nz<6.6*CS or nz>12*CS-1 then break end
    local ox,oz=-sin(a)*wdt,cos(a)*wdt
    L.quad({px-ox,.01,pz-oz},{px+ox,.01,pz+oz},{nx+ox*.7,.01,nz+oz*.7},{nx-ox*.7,.01,nz-oz*.7},'dark',.32)
    if rh(b,sgm,4)<.35 then
     local ba=a+(rh(b,sgm,5)<.5 and .8 or -.8)
     L.quad({nx-ox*.4,.012,nz-oz*.4},{nx+ox*.4,.012,nz+oz*.4},{nx+cos(ba)*6,.012,nz+sin(ba)*6},{nx+cos(ba)*6,.012,nz+sin(ba)*6},'dark',.36)
    end
    px,pz=nx,nz;wdt=wdt*.78
   end
  end
  for q=0,9 do
   local a0,a1=q/10*pi*2,(q+1)/10*pi*2
   L.quad({zx,0,zz},{zx+cos(a1)*9,0,zz+sin(a1)*9},{zx+cos(a0)*9,0,zz+sin(a0)*9},{zx,0,zz},'dark',.3)
  end
 end
 -- the roost: the air still charged
 C.fx.sparks=C.fx.sparks or{}
 C.fx.sparks[#C.fx.sparks+1]={x=4*CS+8,y=10,z=9*CS+8,r=10,col={1,.95,.55}}
 C.fx.glows[#C.fx.glows+1]={x=4*CS+8,y=6,z=9*CS+8,r=20,col='gold',a=.12}
 C.addLight(4*CS+8,24,9*CS+8,120,.28)
 -- the heaps, the transformers, the consoles, the cabinets
 for _,c in ipairs(cellsOf(C,'R'))do heap(C,F,c[1],c[2])end
 local Bs=cellsOf(C,'B')
 for _,c in ipairs(Bs)do transformer(C,F,st,c[1],c[2])end
 -- sparks jumping at a few of the banks
 local ns=0
 for i,c in ipairs(Bs)do
  if ns<7 and rh(c[1],c[2],12)<.09 then
   ns=ns+1
   C.fx.sparks[#C.fx.sparks+1]={x=c[1]*CS+8,y=26,z=c[2]*CS+8,r=5,col={.6,.85,1}}
  end
 end
 for i,c in ipairs(cellsOf(C,'Q'))do console(C,F,st,c,i)end
 for _,g in ipairs(groups(C,'K'))do cabinet(C,F,g)end
 -- the exits: the front doors and the side door, open on the day
 for _,g in ipairs(groups(C,'r'))do
  K.exitPortal(C,'S',g.x0*CS,(g.x1+1)*CS,{view=1,frame='ktSteel',sill='dnHazard'})
 end
 for cy=0,C.ch-1 do
  if C.is(0,cy,'.')then K.exitPortal(C,'W',cy*CS,(cy+1)*CS,{view=1,frame='ktSteel',sill='dnHazard'})end
 end
 -- the roof trusses (seen from under them), and where the roof is gone
 do
  local E=C.part('rafters',{below=H+14})
  local L=K.frame(C,E,0,0,0,0)
  for z=40,D-24,72 do
   L.box(0,H+6,z-2,W,H+8,z+2,'ktSteel',.75)
   L.box(0,H+8,z-.5,W,H+12,z+.5,'ktSteel',.7)
   L.box(0,H+12,z-2,W,H+14,z+2,'ktSteel',.75)
  end
  for x=48,W-16,96 do L.box(x-1.6,H+14,0,x+1.6,H+16,D,'ktSteel',.7)end
 end
 -- dust hanging in the lamplight
 C.fx.motes={x=W*.5,z=D*.5,y0=2,y1=44,r=min(W,D)*.45,n=40,col={.85,.85,.75}}
 C.addLight(W/2,48,D/2,900,.04)
 C.fx.ambience={hum=.34,wind=.05}
end

return M
