-- TEST175: THE ROCKET HIDEOUT (InteriorRooms), under the Celadon Game
-- Corner: B1F, B2F, B3F, B4F and the lift.
-- A villain's lair: black graphite floors with red inlay lines, gunmetal
-- panelling, a red neon line round every wall, the R emblem lit on the
-- walls, security cameras watching the corners, banks of surveillance
-- monitors, caged lamps. The spinner floors' arrow tiles are steel plates
-- with amber neon chevrons (the stop tiles: a red neon square in a hazard
-- ring), and the maze between them is server cabinets and supply crates,
-- their status lights blinking. Conference tables with the plans on them;
-- potted palms; the power cores by the B3F stairs; the blast doors (live
-- tiles: they rise when the grunts that guard them are beaten, and the
-- room rebuilds); the lift doors. B4F: the boss's office -- the monitor
-- wall under the great R, a red runner up to the desk, the rug.
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

-- neon colours (dnNeon's exact shade)
local RED,AMBER,CYAN,WARM,VIOLET,GREEN=1,2,3,4,5,6
local MAXGLOW,MAXLIGHT=20,26

-- a door's live tile: the top-left tile of a cell (8 a horizontal door,
-- 36 a vertical one)
local function gateAt(C,cx,cy)
 local t=C.tile(cx*2,cy*2)
 if t==8 then return'h'elseif t==36 then return'v'end
end
local function runFrame(C,run)
 local ox,oz,yaw
 if run.o=='S'then ox,oz,yaw=run.a0,run.c,0
 elseif run.o=='N'then ox,oz,yaw=run.a1,run.c,pi
 elseif run.o=='E'then ox,oz,yaw=run.c,run.a1,pi/2
 else ox,oz,yaw=run.c,run.a0,-pi/2 end
 return K.frame(C,run.E,ox,0,oz,yaw)
end

------------------------------------------------------------------ emblems
-- the R in a black roundel ringed with red neon (frame: +z out)
local function emblem(L,x,y,z,s)
 L.disc(x,y,z,7.4*s,'dark',16,nil,.7)
 L.ring(x,y,z+.05,6.4*s,7.2*s,'dnNeon',16,RED)
 local ok=pcall(LA().inscription,L,'R',x+.3*s,y-4.4*s,z+.1,1.8*s,'dnNeon')
 if not ok then L.quad({x-2*s,y-4*s,z+.1},{x+2*s,y-4*s,z+.1},{x+2*s,y+4*s,z+.1},{x-2*s,y+4*s,z+.1},'dnNeon',RED)end
end

------------------------------------------------------------------ walls
-- the red neon line under the cornice, caged lamps, cameras, monitors,
-- the emblem on the long walls
local function dress(C,st,run,len,Hh,outer)
 local L=runFrame(C,run)
 local seed=run.a0*.37+run.c*.11
 -- the neon line and its channel
 L.box(0,Hh-7.4,0,len,Hh-5.2,.8,'ktBasalt',.8)
 L.raw({0,Hh-6.8,.85},{len,Hh-6.8,.85},{len,Hh-5.8,.85},{0,Hh-5.8,.85},'dnNeon',RED)
 -- the long walls: the emblem in the middle (the eye's side only)
 local seen=run.o~='N'
 if seen and len>=80 and(outer or len>=112)then
  emblem(L,len/2,Hh*.56,.2,outer and 1.15 or .9)
  if st.glows<MAXGLOW then
   st.glows=st.glows+1
   local p=L.P({len/2,Hh*.56,4})
   C.fx.glows[#C.fx.glows+1]={x=p[1],y=p[2],z=p[3],r=12,col='red',a=.16}
  end
 end
 -- along the run: caged lamps, a camera at the ends, a monitor or a vent
 local x=20+rh(seed,1,1)*20;local i=0
 while x<len-14 do
  if not(len>=80 and abs(x-len/2)<16)then
   local k=rh(seed,i,2)
   if k<.30 then
    -- a wall monitor: the feed from another floor
    L.box(x-6,Hh*.42,0,x+6,Hh*.42+9,1.6,'dark',.8)
    L.raw({x-5.2,Hh*.42+.8,1.65},{x+5.2,Hh*.42+.8,1.65},{x+5.2,Hh*.42+8.2,1.65},{x-5.2,Hh*.42+8.2,1.65},'inScreen',1+floor(rh(seed,i,3)*3))
   elseif k<.52 then
    -- a vent grille
    L.box(x-5,8,0,x+5,14,.6,'ktSteel',.85)
    for j=0,3 do L.quad({x-4.4,8.8+j*1.3,.65},{x+4.4,8.8+j*1.3,.65},{x+4.4,9.4+j*1.3,.65},{x-4.4,9.4+j*1.3,.65},'dark',.6)end
   elseif k<.66 then
    -- a pipe pair up the wall into the ceiling run
    L.rod({x-1.6,0,1.2},{x-1.6,Hh-8,1.2},.8,'ktSteel')
    L.rod({x+1.6,0,1.2},{x+1.6,Hh-8,1.2},.6,'red')
   end
  end
  x=x+34+rh(seed,i,4)*30;i=i+1
 end
 -- a security camera at a run's start (outer walls), watching
 if outer and len>=48 and rh(seed,7,1)<.6 then
  local cx=8
  L.box(cx-.6,Hh-12,0,cx+.6,Hh-9,3,'ktBasalt',.9)
  L.box(cx-1.4,Hh-13.4,2.4,cx+1.4,Hh-10.6,7.4,'inEnamel',.95)
  L.disc(cx,Hh-12,7.45,1,'dark',8)
  L.disc(cx+.9,Hh-11,7.5,.3,'dnNeon',6,nil,RED)
 end
 -- caged lamps: cool light in pools along the walls
 local lx=48+rh(seed,5,5)*30
 while lx<len-24 do
  local y=Hh-17
  L.box(lx-2.4,y-1.6,0,lx+2.4,y+1.6,3.8,'ktSteel',.8)
  L.raw({lx-2,y-1.7,1},{lx+2,y-1.7,1},{lx+2,y-1.7,3.6},{lx-2,y-1.7,3.6},'inPanel',1)
  local p=L.P({lx,y-4,6})
  local far=true
  for _,q in ipairs(st.lamps)do if(q[1]-p[1])^2+(q[3]-p[3])^2<72*72 then far=false;break end end
  if far and #st.lamps<MAXLIGHT then st.lamps[#st.lamps+1]=p;C.addLight(p[1],p[2],p[3],96,.30)end
  lx=lx+96+rh(seed,lx,7)*40
 end
end

------------------------------------------------------------------ floors
-- a spinner tile: a steel plate, two amber chevrons pointing the way
local function arrow(C,E,cx,cy,dir)
 local yaw=({['2']=0,['1']=pi/2,['4']=pi,['3']=-pi/2})[dir]
 local L=K.frame(C,E,cx*CS+8,.06,cy*CS+8,yaw)
 L.quad({-7,0,-7},{7,0,-7},{7,0,7},{-7,0,7},'ktSteel',.62)
 L.quad({-7,.01,-7},{7,.01,-7},{7,.01,-6.2},{-7,.01,-6.2},'ktBasalt',.7)
 L.quad({-7,.01,6.2},{7,.01,6.2},{7,.01,7},{-7,.01,7},'ktBasalt',.7)
 for _,o in ipairs({-3,2})do
  -- (local +x is the way the tile throws you)
  L.quad({o-1.2,.02,-4.2},{o+.2,.02,-4.2},{o+3.2,.02,0},{o+1.8,.02,0},'dnNeon',AMBER)
  L.quad({o+1.8,.02,0},{o+3.2,.02,0},{o+.2,.02,4.2},{o-1.2,.02,4.2},'dnNeon',AMBER)
 end
end
-- a stop tile: a hazard ring round a red neon square
local function stop(C,E,cx,cy)
 local L=K.frame(C,E,cx*CS+8,.06,cy*CS+8,0)
 L.quad({-7,0,-7},{7,0,-7},{7,0,7},{-7,0,7},'ktSteel',.62)
 for i=0,7 do
  local a0,a1=i/8*pi*2+pi/8,(i+1)/8*pi*2+pi/8
  L.quad({cos(a0)*6.4,.01,sin(a0)*6.4},{cos(a1)*6.4,.01,sin(a1)*6.4},{cos(a1)*4.6,.01,sin(a1)*4.6},{cos(a0)*4.6,.01,sin(a0)*4.6},'dnHazard',1)
 end
 L.quad({-2.4,.02,-2.4},{2.4,.02,-2.4},{2.4,.02,2.4},{-2.4,.02,2.4},'dnNeon',RED)
end

------------------------------------------------------------------ pieces
-- a maze block (B): server cabinets with status lights, or supply crates
local function block(C,F,cx,cy)
 local x,z=cx*CS+8,cy*CS+8
 local L=F(x,0,z,0)
 local function isB(dx,dy)return C.is(cx+dx,cy+dy,'B')end
 local n_,s_,w_,e_=isB(0,-1),isB(0,1),isB(-1,0),isB(1,0)
 local s=cx*17+cy*7
 local crate=rh(s,1,1)<.28
 if crate then
  -- a stack of supply crates, the red band, sometimes the R stencilled
  local h1=10+rh(s,2,1)*3
  L.box(-7.2,0,-7.2,7.2,h1,7.2,'slate',.9)
  L.box(-7.4,h1-1.2,-7.4,7.4,h1,7.4,'ktBasalt',.85)
  L.box(-7.25,4,-7.25,7.25,5.4,7.25,'red',.95,{bottom=true,top=true})
  if rh(s,3,1)<.7 then
   local h2=7+rh(s,3,2)*5
   local dx,dz=(rh(s,4,1)-.5)*2.4,(rh(s,4,2)-.5)*2.4
   L.box(-5.6+dx,h1,-5.6+dz,5.6+dx,h1+h2,5.6+dz,rh(s,4,3)<.5 and'slate'or'ktSteel',.95)
   L.box(-5.8+dx,h1+h2-1,-5.8+dz,5.8+dx,h1+h2,5.8+dz,'ktBasalt',.85)
  end
  return
 end
 -- a server cabinet; neighbours join into a run (no inner faces)
 local h=22
 L.box(w_ and -8 or -7.4,0,n_ and -8 or -7.4,e_ and 8 or 7.4,h,s_ and 8 or 7.4,'dark',.95,
  {bottom=true,n=n_,s=s_,w=w_,e=e_})
 L.box(w_ and -8 or -7.6,h,n_ and -8 or -7.6,e_ and 8 or 7.6,h+1,s_ and 8 or 7.6,'ktSteel',1.0,
  {bottom=true,n=n_,s=s_,w=w_,e=e_})
 -- a vent on the roof
 L.quad({-4,h+1.02,-3},{4,h+1.02,-3},{4,h+1.02,3},{-4,h+1.02,3},'ktSteel',.55)
 for j=0,2 do L.quad({-3.4,h+1.04,-2.2+j*1.8},{3.4,h+1.04,-2.2+j*1.8},{3.4,h+1.04,-1.4+j*1.8},{-3.4,h+1.04,-1.4+j*1.8},'dark',.6)end
 -- the status lights on the faces the floor sees
 local function face(fx,fz,yaw)
  local Lf=F(x+fx,0,z+fz,yaw)
  local k=floor(rh(s,yaw*3+1,5)*3)
  for j=0,2 do
   local y=5+j*5.4
   local w=2+rh(s,j,6+yaw)*8
   Lf.raw({-6,y,.05},{-6+w,y,.05},{-6+w,y+.9,.05},{-6,y+.9,.05},'dnNeon',({GREEN,CYAN,RED})[(k+j)%3+1])
  end
  Lf.quad({-6.6,2,.03},{6.6,2,.03},{6.6,20,.03},{-6.6,20,.03},'ktBasalt',.75)
 end
 if not s_ then face(0,7.45,0)end
 if not n_ and rh(s,8,1)<.5 then face(0,-7.45,pi)end
 if not e_ and rh(s,9,1)<.5 then face(7.45,0,pi/2)end
 if not w_ and rh(s,10,1)<.5 then face(-7.45,0,-pi/2)end
end

-- a conference table: a table starts at its top-left cell (raw 15), two
-- cells wide, down to its bottom row (raw 22)
local function tables(C)
 local out={}
 for cy=0,C.ch-1 do for cx=0,C.cw-1 do
  if C.raw(cx,cy)==15 then
   local y1=cy
   while y1<C.ch-1 and C.raw(cx,y1)~=22 do y1=y1+1 end
   out[#out+1]={x0=cx,x1=cx+1,y0=cy,y1=y1}
  end
 end end
 return out
end
local function confTable(C,F,g,seed,exec)
 local x0,x1,z0,z1=g.x0*CS+1.4,(g.x1+1)*CS-1.4,g.y0*CS+1.4,(g.y1+1)*CS-1.4
 local L=F(0,0,0,0)
 local top=exec and'inWalnut'or'dnGraniteDark'
 L.box(x0,10.4,z0,x1,12,z1,top,1.05)
 L.box(x0-.3,10,z0-.3,x1+.3,10.6,z1+.3,exec and'lgGold'or'red',1.05)
 L.box(x0+2,0,z0+2,x1-2,10,z1-2,'ktBasalt',.75,{bottom=true,top=true})
 if exec then
  -- the desk's leather inlay, a lamp, the telephone, the files
  L.box(x0+3,12,z0+3,x1-3,12.1,z1-3,'inLeather',1)
  local Ll=F(x0+5,12,z0+5,0)
  Ll.cyl(0,0,.8,0,1.6,1.6,'lgGold',8);Ll.rod({0,.8,0},{0,7,0},.3,'lgGold')
  Ll.cyl(0,6,8.6,0,3,1.6,'green',8,false)
  C.fx.glows[#C.fx.glows+1]={x=x0+5,y=17,z=z0+5,r=7,col='warm',a=.20}
  local Lt=F(x1-6,12,z0+5,0)
  Lt.box(-2,0,-1.4,2,1.4,1.4,'dark',.9);Lt.box(-2.4,1.4,-.6,2.4,2.2,.6,'dark',.85)
  for k=0,2 do L.box(x0+8+k*.3,12.1+k*.4,z1-10+k*.3,x0+16+k*.3,12.4+k*.4,z1-4+k*.3,({'cream','red','cream'})[k+1],1.1)end
  return
 end
 -- the plans: a map, folders, a monitor or two
 local long=(z1-z0)>(x1-x0)
 local n=max(1,floor((long and(z1-z0)or(x1-x0))/26))
 for i=0,n-1 do
  local t=(i+.5)/n
  local mx=long and(x0+x1)/2 or x0+(x1-x0)*t
  local mz=long and z0+(z1-z0)*t or(z0+z1)/2
  local k=rh(seed,i,1)
  if k<.45 then
   local Lm=F(mx,12,mz,long and(rh(seed,i,2)<.5 and pi/2 or -pi/2)or 0)
   Lm.box(-3.4,0,-1.6,3.4,.4,.6,'ktSteel',1);Lm.box(-.4,.4,-1.2,.4,3,-.6,'ktSteel',1)
   Lm.box(-4.2,3,-1.4,4.2,8.6,-.6,'dark',.8)
   Lm.raw({-3.8,3.4,-.55},{3.8,3.4,-.55},{3.8,8.2,-.55},{-3.8,8.2,-.55},'inScreen',1+floor(rh(seed,i,3)*3))
  elseif k<.75 then
   -- a plan unrolled, weighted at the corners
   L.quad({mx-6,12.06,mz-4},{mx+6,12.06,mz-4},{mx+6,12.06,mz+4},{mx-6,12.06,mz+4},'cream',1.1)
   L.quad({mx-5,12.08,mz-1},{mx+3,12.08,mz-3},{mx+4,12.08,mz-2.4},{mx-4.6,12.08,mz-.2},'blue',.9)
   L.quad({mx-1,12.08,mz+.6},{mx+4,12.08,mz+.8},{mx+4,12.08,mz+1.6},{mx-1,12.08,mz+1.4},'red',.9)
  else
   for j=0,2 do L.box(mx-3+j*.3,12+j*.35,mz-2+j*.4,mx+2+j*.3,12.3+j*.35,mz+2+j*.4,({'navy','cream','red'})[j+1],1.08)end
  end
 end
end

-- a monitor bank (Q) against the wall, its upper screens on the band (q)
local function monitors(C,F,st,c,i)
 local x,z=c[1]*CS+8,c[2]*CS+8
 local L=F(x,0,z,0)
 local back=C.is(c[1],c[2]-1,'qW')
 local we,ea=C.is(c[1]-1,c[2],'Q'),C.is(c[1]+1,c[2],'Q')
 L.box(we and -8 or -7.6,0,-8,ea and 8 or 7.6,13,6,'dark',.9)
 L.box(we and -8 or -7.8,13,-8,ea and 8 or 7.8,14,6.6,'ktSteel',1)
 -- the keys and the switches on the desk
 L.box(-5,14,1.6,5,14.5,5,'ktBasalt',.9)
 for k=0,4 do L.raw({-4.4+k*1.9,14.55,2},{-3.2+k*1.9,14.55,2},{-3.2+k*1.9,14.55,2.8},{-4.4+k*1.9,14.55,2.8},'dnNeon',({RED,GREEN,AMBER,GREEN,RED})[k+1])end
 -- two rows of screens above
 L.box(we and -8 or -7.6,14,-8,ea and 8 or 7.6,34,-4.4,'dark',.85)
 for r=0,1 do
  for k=0,1 do
   local a=-7+k*7.2
   L.raw({a,16+r*9,-4.35},{a+6.6,16+r*9,-4.35},{a+6.6,23.6+r*9,-4.35},{a,23.6+r*9,-4.35},'inScreen',1+((i+k+r)%3))
  end
 end
 if st.glows<MAXGLOW and i%2==1 then
  st.glows=st.glows+1
  local p=L.P({0,24,0});C.fx.glows[#C.fx.glows+1]={x=p[1],y=p[2],z=p[3],r=9,col='cyan',a=.12}
 end
 if back then
  -- the cable run up into the ceiling
  L.rod({-5,34,-6.4},{-5,C.H-4,-6.4},.7,'ktSteel');L.rod({5,34,-6.4},{5,C.H-4,-6.4},.7,'red')
 end
end

-- a tall machine (K): server tower, or on B3F the power cores
local function tower(C,F,st,g,core)
 local x0,x1,z0,z1=g.x0*CS,(g.x1+1)*CS,g.y0*CS,(g.y1+1)*CS
 local cx,cz=(x0+x1)/2,(z0+z1)/2
 if core then
  -- a power core: a steel cylinder banded in red neon, cables at the foot
  local L=F(cx,0,cz,0)
  local r=min(x1-x0,z1-z0)/2-1.2
  L.cyl(0,0,3,0,r+1,r+1,'ktBasalt',12)
  L.cyl(0,3,40,0,r,r,'ktSteel',12,false,0,'inSteel')
  L.cyl(0,40,43,0,r+.8,r+.8,'ktBasalt',12)
  for k=0,3 do
   local y=8+k*8.4
   for i=0,11 do
    local a0,a1=i/12*pi*2,(i+1)/12*pi*2
    L.raw({cos(a0)*(r+.1),y,sin(a0)*(r+.1)},{cos(a1)*(r+.1),y,sin(a1)*(r+.1)},{cos(a1)*(r+.1),y+1.2,sin(a1)*(r+.1)},{cos(a0)*(r+.1),y+1.2,sin(a0)*(r+.1)},'dnNeon',RED)
   end
  end
  for k=0,2 do
   local a=k*2.1+.4
   L.rod({cos(a)*r,1,sin(a)*r},{cos(a)*(r+7),.5,sin(a)*(r+7)},.7,'dark')
  end
  if st.glows<MAXGLOW then
   st.glows=st.glows+1
   C.fx.glows[#C.fx.glows+1]={x=cx,y=22,z=cz,r=16,col='red',a=.18}
  end
  C.fx.sparks=C.fx.sparks or{}
  C.fx.sparks[#C.fx.sparks+1]={x=cx,y=42,z=cz,r=5,col={1,.35,.35}}
  C.addLight(cx,24,cz,70,.22)
  return
 end
 local L=F(0,0,0,0)
 L.box(x0+1,0,z0+1,x1-1,38,z1-1,'dark',.9)
 L.box(x0+.6,38,z0+.6,x1-.6,39.4,z1-.6,'ktSteel',1)
 for k=0,7 do
  local y=4+k*4.2
  L.raw({x0+2,y,z1-.95},{x1-2,y,z1-.95},{x1-2,y+.8,z1-.95},{x0+2,y+.8,z1-.95},'dnNeon',k%3==0 and RED or GREEN)
 end
end

-- a blast door (live tile): steel leaves banded in hazard stripes, the R
local function blastDoor(C,F,cx,cy,kind)
 local L=F(cx*CS+8,0,cy*CS+8,kind=='v'and pi/2 or 0)
 L.box(-8,0,-1.8,8,36,1.8,'ktSteel',.95)
 L.box(-8,0,1.8,8,4,2.2,'dnHazard',1)
 L.box(-8,32,1.8,8,36,2.2,'dnHazard',1)
 L.box(-.25,4,1.8,.25,32,2.1,'dark',.6)
 emblem(L,0,20,2.2,.75)
 L.box(-9,0,-2.4,-8,38,2.4,'ktBasalt',1);L.box(8,0,-2.4,9,38,2.4,'ktBasalt',1)
 L.box(-9,36,-2.4,9,38,2.4,'ktBasalt',1)
 L.box(9.2,14,1.2,11.4,19,2.2,'dark',.8)
 L.raw({9.6,16.6,2.25},{11,16.6,2.25},{11,18,2.25},{9.6,18,2.25},'dnNeon',RED)
end

-- a potted palm (raw 11 is the head cell; it stands over two cells)
local function palm(C,F,cx,cy)
 K.plant(F(cx*CS+8,0,cy*CS+14,0),'palm',{s=1.25,pot='ktBasalt',seed=cx*7+cy})
end

-- stairs: up against a wall, a steel spiral where it stands free; down
-- through a lit well
local function stairs(C,R,c,up)
 local x0,z0=c[1]*CS,c[2]*CS
 if up and C.is(c[1],c[2]-1,'WqV')then
  K.stairsUp(C,R,x0,x0+CS,z0,z0+CS,{tread='ktSteel',riser='dark',rail='red',side=x0+1,n=4,top=14})
 elseif up then
  local L=K.frame(C,R,x0+8,0,z0+8,0)
  L.cyl(0,0,C.H-4,0,1.2,1.2,'ktSteel',8,false)
  for k=0,9 do
   local a=k*.7;local y=2+k*4.4
   L.quad({0,y,0},{cos(a)*7.4,y,sin(a)*7.4},{cos(a+.62)*7.4,y,sin(a+.62)*7.4},{0,y,0},'ktSteel',.95)
   L.quad({cos(a)*7.4,y,sin(a)*7.4},{cos(a+.62)*7.4,y,sin(a+.62)*7.4},{cos(a+.62)*7.4,y-.8,sin(a+.62)*7.4},{cos(a)*7.4,y-.8,sin(a)*7.4},'dark',.8)
   L.rod({cos(a+.3)*7.4,y,sin(a+.3)*7.4},{cos(a+.3)*7.4,y+9,sin(a+.3)*7.4},.2,'red')
  end
  L.cyl(0,C.H-6,C.H-4,0,8,8,'dark',12)
 else
  K.stairsDown(C,R,x0,x0+CS,z0,z0+CS,{tread='ktSteel',riser='dark',wall='dnGunmetal',rail='red',handrail='red',nosing='dnHazard',railX=x0+.6})
  local E=C.part('floor')
  local L=K.frame(C,E,0,.05,0,0)
  L.raw({x0,0,z0-1},{x0+CS,0,z0-1},{x0+CS,0,z0},{x0,0,z0},'dnNeon',AMBER)
 end
end

------------------------------------------------------------------ the floors
function M.hideout(C)
 local fl=tonumber(C.id:match('_B(%d)F$'))or 1
 local H=52;C.H=H
 C.ambient=.50;C.maxLight=1.4
 C.watchAll=true
 local W,D=C.cw*CS,C.ch*CS
 local st={lamps={},glows=0}
 C.fx.glows=C.fx.glows or{}
 local function solid(cx,cy)return C.is(cx,cy,'WqV')end
 local function inner(cx,cy)
  if not C.is(cx,cy,'Wq')then return false end
  for dy=-1,1 do for dx=-1,1 do
   local nx,ny=cx+dx,cy+dy
   if nx<0 or ny<0 or nx>=C.cw or ny>=C.ch or C.is(nx,ny,'V')then return false end
  end end
  return true
 end
 local blocked=function(cx,cy)local c=C.at(cx,cy);return c~=nil and not('.1234srm^v'):find(c,1,true)end
 local S=K.shell(C,{H=H,solid=solid,inner=inner,innerH=40,blocked=blocked,door=function()return false end,
  paint='dnGunmetal',upper='dnGunmetal',wainscot='ktBasalt',wainscotH=9,rail='red',skirting='dark',
  cornice='ktSteel',cap='ktBasalt',floor='dnLair',floorT=.9,ceiling=false,innerPaint='dnGunmetal',
  nofloor=function(cx,cy)return C.at(cx,cy)=='v'end,
  style=function(L,len,run)dress(C,st,run,len,H,true)end,
  innerStyle=function(L,len,run,Hi)
   L.quad({0,0,.06},{len,0,.06},{len,9,.06},{0,9,.06},'ktBasalt',.9)
   L.box(0,8.6,0,len,9.8,.9,'red',1)
   dress(C,st,run,len,Hi,false)
  end,ao=10})
 local R=C.part('room')
 local function F(x,y,z,yaw)return K.frame(C,R,x,y,z,yaw)end
 -- the spinner floor
 do
  local E=C.part('floor')
  for cy=0,C.ch-1 do for cx=0,C.cw-1 do
   local ch=C.at(cx,cy)
   if ch=='1'or ch=='2'or ch=='3'or ch=='4'then arrow(C,E,cx,cy,ch)
   elseif ch=='s'then stop(C,E,cx,cy)end
  end end
 end
 -- the maze and the stores
 for _,c in ipairs(cellsOf(C,'B'))do block(C,F,c[1],c[2])end
 -- the tables (the boss's desk on B4F, in his office)
 local desk
 for i,g in ipairs(tables(C))do
  if fl==4 and g.x0>=22 and g.y0<=6 then
   -- (the office's two tables are one great desk)
   if desk then desk.x0=min(desk.x0,g.x0);desk.x1=max(desk.x1,g.x1);desk.y0=min(desk.y0,g.y0);desk.y1=max(desk.y1,g.y1)
   else desk={x0=g.x0,x1=g.x1,y0=g.y0,y1=g.y1}end
  else
   confTable(C,F,g,i*5+fl,false)
  end
 end
 if desk then confTable(C,F,desk,7,true)end
 -- the palms
 for _,c in ipairs(cellsOf(C,'P'))do
  if C.raw(c[1],c[2])==11 then palm(C,F,c[1],c[2])end
 end
 -- the monitor banks and the tall machines
 for i,c in ipairs(cellsOf(C,'Q'))do monitors(C,F,st,c,i)end
 for _,g in ipairs(groups(C,'K'))do tower(C,F,st,g,fl==3)end
 -- stairs
 for _,c in ipairs(cellsOf(C,'^'))do stairs(C,R,c,true)end
 for _,c in ipairs(cellsOf(C,'v'))do stairs(C,R,c,false)end
 -- the lift doors at the back of their alcove (south), lit above
 for _,g in ipairs(groups(C,'r'))do
  local x0,x1=g.x0*CS,(g.x1+1)*CS
  local z=(g.y1+1)*CS
  local E=C.part('decor:lift'..g.y1,{axis='z',c=z,s=-1})
  local L=K.frame(C,E,0,0,z,0)
  L.box(x0+.4,0,-1.4,(x0+x1)/2-.2,34,0,'ktSteel',1)
  L.box((x0+x1)/2+.2,0,-1.4,x1-.4,34,0,'ktSteel',.95)
  L.box(x0-1.4,0,-2.2,x0+.4,40,0,'ktBasalt',1);L.box(x1-.4,0,-2.2,x1+1.4,40,0,'ktBasalt',1)
  L.box(x0-1.4,34,-2.2,x1+1.4,40,0,'ktBasalt',1)
  L.raw({x0+4,35.4,-2.25},{x1-4,35.4,-2.25},{x1-4,38.6,-2.25},{x0+4,38.6,-2.25},'dnNeon',AMBER)
  local Ef=C.part('floor')
  local Lf=K.frame(C,Ef,0,.05,0,0)
  Lf.quad({x0+1,0,z-14},{x1-1,0,z-14},{x1-1,0,z-1},{x0+1,0,z-1},'dnHazard',.9)
  Lf.quad({x0+3,.01,z-12},{x1-3,.01,z-12},{x1-3,.01,z-3},{x0+3,.01,z-3},'ktSteel',.7)
 end
 -- the blast doors (live)
 for cy=0,C.ch-1 do for cx=0,C.cw-1 do
  local g=gateAt(C,cx,cy);if g then blastDoor(C,F,cx,cy,g)end
 end end
 -- B4F: the boss's office -- the great R over the monitor wall, a red
 -- runner from the door to the desk, a rug under it
 if fl==4 then
  local Ln=K.onWall(C,'N',0,0)
  local ox=25*CS
  Ln.box(ox-S.w-30,36,-.2,ox-S.w+30,50,1,'dark',.8)
  emblem(Ln,ox-S.w,43,1.2,1.25)
  local Ef=C.part('floor')
  K.rug(C,Ef,22*CS+4,3*CS+2,28*CS+12,6*CS+14,{field='inRugRed',border='lgGold',bw=1.6,y=.08})
  local Lr=K.frame(C,Ef,0,.1,0,0)
  Lr.quad({24*CS+3,0,7*CS},{26*CS-3,0,7*CS},{26*CS-3,0,11*CS},{24*CS+3,0,11*CS},'inRugRed',.8)
  Lr.quad({24*CS+2,.01,7*CS},{24*CS+3,.01,7*CS},{24*CS+3,.01,11*CS},{24*CS+2,.01,11*CS},'lgGold',.9)
  Lr.quad({26*CS-3,.01,7*CS},{26*CS-2,.01,7*CS},{26*CS-2,.01,11*CS},{26*CS-3,.01,11*CS},'lgGold',.9)
  C.addLight(25*CS,30,4*CS,90,.30)
 end
 -- B1F: the floor's sign by the stairs from the Game Corner
 do
  local Ln=K.onWall(C,'N',0,0)
  local sx
  for _,c in ipairs(cellsOf(C,'^'))do if not sx then sx=c[1]*CS end end
  if sx then
   Ln.box(sx-S.w-24,32,-.2,sx-S.w-4,42,1,'dark',.8)
   pcall(LA().inscription,Ln,'B'..fl..'F',sx-S.w-14,34,1.05,1.3,'dnNeon',16)
  end
 end
 -- pipes and beams overhead (seen from under them)
 do
  local E=C.part('rafters',{below=H+10})
  local L=K.frame(C,E,0,0,0,0)
  for z=32,D-16,80 do
   L.box(0,H+4,z-2,W,H+8,z+2,'dark',.8)
   L.rod({0,H+2,z+5},{W,H+2,z+5},1.2,'ktSteel')
   L.rod({0,H+2,z-5},{W,H+2,z-5},.8,'red')
  end
 end
 C.fx.mist={}
 for i=1,4 do C.fx.mist[i]={x=rh(i,fl,1)*W,y=2,z=rh(i,fl,2)*D,r=30,phase=i*1.7,drift=10,col={.40,.30,.34},a=.05}end
 C.addLight(W/2,44,D/2,700,.05)
 C.fx.ambience={hum=.26,hall=.10}
end

------------------------------------------------------------------ the lift
function M.lift(C)
 local H=48;C.H=H
 C.ambient=.62;C.maxLight=1.4
 local W,D=C.cw*CS,C.ch*CS
 local function solid(cx,cy)return C.is(cx,cy,'W')end
 local S=K.shell(C,{H=H,solid=solid,blocked=function(cx,cy)return C.is(cx,cy,'WK')end,door=function()return false end,
  paint='dnGunmetal',upper='dnGunmetal',wainscot='ktBasalt',wainscotH=9,rail='red',skirting='dark',
  cornice='ktSteel',cap='ktBasalt',floor='dnLair',floorT=.95,ceiling='dark',
  style=function(L,len,run)
   local Lf=runFrame(C,run)
   Lf.box(0,H-7.4,0,len,H-5.2,.8,'ktBasalt',.8)
   Lf.raw({0,H-6.8,.85},{len,H-6.8,.85},{len,H-5.8,.85},{0,H-5.8,.85},'dnNeon',RED)
   -- brushed steel handrail round the car
   if run.o~='N'then Lf.box(2,16,0,len-2,17.4,2.4,'inSteel',1.05)end
  end,ao=8})
 local R=C.part('room')
 local F=function(x,y,z,yaw)return K.frame(C,R,x,y,z,yaw)end
 -- the doors (E) on the north wall
 local Ln=K.onWall(C,'N',0,0)
 local e=cellsOf(C,'E')
 if #e>0 then
  local a,b=math.huge,-math.huge
  for _,c in ipairs(e)do a=min(a,c[1]*CS);b=max(b,(c[1]+1)*CS)end
  a,b=a-S.w,b-S.w
  Ln.box(a+.4,0,0,(a+b)/2-.2,34,1.2,'ktSteel',1)
  Ln.box((a+b)/2+.2,0,0,b-.4,34,1.2,'ktSteel',.95)
  Ln.box(a-1.6,0,0,a+.4,40,2,'ktBasalt',1);Ln.box(b-.4,0,0,b+1.6,40,2,'ktBasalt',1)
  Ln.box(a-1.6,34,0,b+1.6,40,2,'ktBasalt',1)
  Ln.raw({a+4,35.4,2.05},{b-4,35.4,2.05},{b-4,38.6,2.05},{a+4,38.6,2.05},'dnNeon',AMBER)
  emblem(Ln,(a+b)/2,20,1.3,.7)
 end
 -- the control panel (K): floor buttons B1-B4, the key slot
 for _,c in ipairs(cellsOf(C,'K'))do
  local L=F(c[1]*CS+8,0,c[2]*CS+8,0)
  L.box(-7,0,-8,7,30,4,'dark',.9)
  L.box(-7.4,30,-8,7.4,31,4.4,'ktSteel',1)
  for k=0,3 do
   L.box(-3,10+k*4.4,4,3,13+k*4.4,4.6,'ktBasalt',.9)
   L.raw({-2.4,10.6+k*4.4,4.65},{2.4,10.6+k*4.4,4.65},{2.4,12.4+k*4.4,4.65},{-2.4,12.4+k*4.4,4.65},'dnNeon',k==0 and AMBER or WARM)
  end
  L.box(-1.4,4,4,1.4,7,4.8,'lgGold',1.1)
  L.box(-.3,5,4.8,.3,6,4.9,'dark',.6)
  C.fx.glows[#C.fx.glows+1]={x=c[1]*CS+8,y=18,z=c[2]*CS+13,r=7,col='gold',a=.14}
 end
 -- the floor: a hazard border inside the doors, the R inlaid
 do
  local E=C.part('floor')
  local L=K.frame(C,E,0,.06,0,0)
  for _,c in ipairs(cellsOf(C,'m'))do
   local x0,z0=c[1]*CS,c[2]*CS
   L.quad({x0,0,z0},{x0+CS,0,z0},{x0+CS,0,z0+4},{x0,0,z0+4},'dnHazard',.9)
  end
  local Lc=K.frame(C,E,W/2,.08,D*.62,0)
  Lc.disc(0,0,0,12,'dark',16,'y',.8)
  for i=0,15 do
   local a0,a1=i/16*pi*2,(i+1)/16*pi*2
   Lc.raw({cos(a0)*12,.01,sin(a0)*12},{cos(a1)*12,.01,sin(a1)*12},{cos(a1)*11,.01,sin(a1)*11},{cos(a0)*11,.01,sin(a0)*11},'dnNeon',RED)
  end
 end
 -- a light panel overhead
 do
  local E=C.part('ceilfx',{below=H+2})
  local L=K.frame(C,E,0,0,0,0)
  L.raw({W/2-14,H-.4,D/2-10},{W/2+14,H-.4,D/2-10},{W/2+14,H-.4,D/2+10},{W/2-14,H-.4,D/2+10},'inPanel',1)
 end
 C.addLight(W/2,40,D/2,90,.32)
 C.fx.ambience={hum=.22}
end

return M
