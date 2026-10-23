-- TEST172: the League's halls (see LeagueRooms for the frame).
--   lobby     the Indigo Plateau concourse
--   champion  the Champion's sanctum
--   fame      the Hall of Fame, open to the night and the fireworks
--   upstairs  the union room's floor over the lobby (TEST201)
local V=...
local M={}
local pi,cos,sin,floor,min,max,abs,sqrt=math.pi,math.cos,math.sin,math.floor,math.min,math.max,math.abs,math.sqrt
local function rh(a,b,s)local v=sin(a*12.9898+b*78.233+s*37.719)*43758.5453;return v-floor(v)end
local CS=16
local function E4()return V.require('LeagueRoomsE4')end
local function inHole(holes,x)
 for _,h in ipairs(holes or{})do if x>h[1]-.01 and x<h[2]+.01 then return h end end
 return nil
end

------------------------------------------------------------------ shared
-- the League's classical wall order (as the antechamber): marble face,
-- verde plinth, gilded chair rail, fluted pilasters, crimson frieze
local function classicWall(C,L,len,run,H,o)
 o=o or{}
 local lib=C.lib
 local holes={}
 for _,h in ipairs(run.holes)do holes[#holes+1]={h[1],h[2],o.DH and o.DH+6 or H}end
 for _,h in ipairs(o.holes or{})do holes[#holes+1]=h end
 E4().faceWithHoles(L,len,0,H,holes,o.mat or'lgMarble',1,0,16)
 local spans={}
 local x=0
 table.sort(holes,function(a,b)return a[1]<b[1]end)
 for _,h in ipairs(holes)do if h[1]>x then spans[#spans+1]={x,h[1]}end;x=h[2]end
 if x<len then spans[#spans+1]={x,len}end
 for _,sp in ipairs(spans)do
  local a,b=sp[1],sp[2]
  if b-a>.5 then
   L.box(a,0,0,b,5,1.2,'lgVerde',1,{bottom=true})
   L.box(a,5,0,b,5.7,1.35,'lgGold',1,{bottom=true})
   L.box(a,15.4,0,b,16.6,1.0,'lgMarble',1,{})
  end
 end
 local pil=o.pilasters or{}
 if #pil==0 then local px=o.first or 4;while px<len do pil[#pil+1]=px;px=px+(o.step or 24)end end
 for _,px in ipairs(pil)do
  if not inHole(holes,px-5)and not inHole(holes,px+5)then
   L.box(px-4.2,0,0,px+4.2,6.4,1.7,'lgVerde',1,{bottom=true})
   L.box(px-3.6,6.4,0,px+3.6,7.1,1.4,'lgGold',1,{bottom=true})
   L.decor(function()
    L.box(px-3,7.1,0,px+3,H-19,1.0,'lgFluteD',1,{bottom=true,top=true})
    L.box(px-3.5,H-19,0,px+3.5,H-17.6,1.3,'lgGold',1,{})
    L.box(px-4.2,H-17.6,0,px+4.2,H-16,1.6,'lgGold',.94,{})
   end)
  end
 end
 L.box(0,H-16,0,len,H-15,1.0,'lgGold',1,{})
 L.box(0,H-15,0,len,H-7,.6,'lgCrimson',1,{bottom=true})
 L.decor(function()
  local dx=1
  while dx<len-1 do L.quad({dx,H-6.8,.66},{dx+1.2,H-6.8,.66},{dx+1.2,H-5.8,.66},{dx,H-5.8,.66},'lgGold',.95);dx=dx+3.2 end
 end)
 L.box(0,H-5.6,0,len,H-2.6,1.8,'lgMarble',1,{})
 L.box(0,H-2.6,0,len,H-2,2.0,'lgGold',1,{})
 L.box(0,H-2,0,len,H,2.6,'lgMarble',1,{top=true,bottom=true})
 L.box(-1,H,-6,len+1,H+.8,2.6,'lgMarble',1,{bottom=true})
 return pil,spans
end
M.classicWall=classicWall
-- a crimson silk drape, swagged, between two points on a wall
local function drape(L,a,b,y0,y1)
 local m=(a+b)/2
 L.box(a-1,y1,0,b+1,y1+1.6,2.6,'lgGold',1,{})
 for k=0,7 do
  local u0,u1=k/8,(k+1)/8
  local x0,x1=a+(b-a)*u0,a+(b-a)*u1
  local z0,z1=1.2+.9*sin(u0*pi*4),1.2+.9*sin(u1*pi*4)
  L.quad({x0,y0+(1-abs(2*u0-1))*-3,z0},{x1,y0+(1-abs(2*u1-1))*-3,z1},{x1,y1,z1},{x0,y1,z0},'lgCrimson',.95+.08*sin(u0*pi*4))
 end
 L.decor(function()
  for k=0,7 do
   local u0,u1=k/8,(k+1)/8
   local x0,x1=a+(b-a)*u0,a+(b-a)*u1
   local z0,z1=1.25+.9*sin(u0*pi*4),1.25+.9*sin(u1*pi*4)
   local ya,yb=y0+(1-abs(2*u0-1))*-3,y0+(1-abs(2*u1-1))*-3
   L.quad({x0,ya,z0},{x1,yb,z1},{x1,yb+1.2,z1},{x0,ya+1.2,z0},'lgGold',1)
  end
 end)
end
M.drape=drape
-- a gold trophy cup at (x,y,z)
local function trophy(L,x,y,z,s)
 s=s or 1
 L.frustum(x,y,z,1.4*s,y+.6*s,1.4*s,10,'lgVerde')
 L.frustum(x,y+.6*s,z,1.0*s,y+1.4*s,.5*s,10,'lgGold')
 L.frustum(x,y+1.4*s,z,.35*s,y+3.6*s,.3*s,8,'lgGold')
 L.frustum(x,y+3.6*s,z,.4*s,y+4.4*s,1.6*s,12,'lgGold')
 L.frustum(x,y+4.4*s,z,1.6*s,y+6.2*s,2.0*s,12,'lgGold')
 for _,sx in ipairs({-1,1})do
  L.box(x+sx*2.0*s-.2*s,y+4.4*s,z-.2*s,x+sx*2.6*s+.2*s,y+5.6*s,z+.2*s,'lgGold',1,{})
 end
end
M.trophy=trophy
-- a laurel wreath in a wall plane, ring radius r
local function laurel(L,cx,cy,z,r,mat)
 mat=mat or'lgGold'
 for side=-1,1,2 do
  for k=0,9 do
   local a=pi*1.5+side*(.35+k*.27)
   local lx,ly=cx+cos(a)*r,cy+sin(a)*r
   local ox,oy=cos(a+side*1.2)*r*.17,sin(a+side*1.2)*r*.17
   L.quad({lx-ox*.4,ly-oy*.4,z},{lx+oy*.45,ly-ox*.45,z},{lx+ox,ly+oy,z},{lx-oy*.45,ly+ox*.45,z},mat,.98)
  end
 end
end
M.laurel=laurel
-- a coffered dome over (cx,cz): radius R, springing at y0, rise, with an
-- oculus of light; returns the oculus height
local function dome(C,E,cx,cz,R,y0,rise,n,rings)
 local lib=C.lib
 n=n or 32;rings=rings or 7
 local function P(a,j)
  local e=j/rings*pi/2
  local r=cos(e)*R;local y=y0+sin(e)*rise
  return{cx+cos(a)*r,y,cz+sin(a)*r}
 end
 for j=0,rings-2 do for i=0,n-1 do
  local a0,a1=i/n*pi*2,(i+1)/n*pi*2
  local cof=(i%2==0)
  E.quad(P(a0,j),P(a1,j),P(a1,j+1),P(a0,j+1),cof and'lgCrimson'or'lgMarble',cof and .78 or .86)
 end end
 E.decor(function()
  for i=0,n-1,2 do
   local a=i/n*pi*2;local w=.03
   for j=0,rings-2 do
    local p0,p1=P(a-w,j),P(a+w,j)
    local q0,q1=P(a-w,j+1),P(a+w,j+1)
    local function inw(p)return{p[1]-(p[1]-cx)*.012,p[2]-.1,p[3]-(p[3]-cz)*.012}end
    E.quad(inw(p0),inw(p1),inw(q1),inw(q0),'lgGold',1.05)
   end
  end
  for j=1,rings-2 do
   for i=0,n-1 do
    local a0,a1=i/n*pi*2,(i+1)/n*pi*2
    local p0,p1=P(a0,j),P(a1,j)
    E.quad({p0[1],p0[2]-.12,p0[3]},{p1[1],p1[2]-.12,p1[3]},{p1[1],p1[2]-.9,p1[3]},{p0[1],p0[2]-.9,p0[3]},'lgGold',.95)
   end
  end
 end)
 local orr=cos((rings-1)/rings*pi/2)*R
 local oy=y0+sin((rings-1)/rings*pi/2)*rise
 for i=0,n-1 do
  local a0,a1=i/n*pi*2,(i+1)/n*pi*2
  E.quad({cx+cos(a0)*orr,oy,cz+sin(a0)*orr},{cx+cos(a1)*orr,oy,cz+sin(a1)*orr},{cx+cos(a1)*orr,oy+3,cz+sin(a1)*orr},{cx+cos(a0)*orr,oy+3,cz+sin(a0)*orr},'lgGold',.95)
  E.quad({cx,oy+3,cz},{cx+cos(a1)*orr,oy+3,cz+sin(a1)*orr},{cx+cos(a0)*orr,oy+3,cz+sin(a0)*orr},{cx,oy+3,cz},'cream',1.55)
 end
 return oy,orr
end
M.dome=dome

-- ====================================================================
-- THE CHAMPION'S SANCTUM
-- White marble and gold under a coffered dome whose oculus pours light
-- onto the championship medallion; crimson drapes between colossal
-- pilasters; golden eagles flanking both doors; the way on to the Hall of
-- Fame a portal of light under HALL OF FAME, and CHAMPION on the frieze.
-- ====================================================================
function M.champion(C)
 local K,lib=C.K,C.lib
 local W,D=C.W,C.D
 C.H=104;C.ambient=.84;C.maxLight=1.45
 local H=C.H
 local fx=C.fx
 fx.beams,fx.spots,fx.motes={}, {}, nil
 fx.ambience={champion=.7}
 C.addLight(64,60,64,70,.30)
 local solid=function(cx,cy)return C.is(cx,cy,'W')or cx<0 or cx>=C.cw or cy<0 or cy>=C.ch end
 ---------------------------------------------------------------- floor
 local Ef=C.part('floor',nil,true)
 local ao=C.aoField(function(cx,cy)return solid(cx,cy)end,14)
 local c=3
 for cy=0,C.ch-1 do for cx=0,C.cw-1 do
  if not C.is(cx,cy,'W')then
   local x,z=cx*CS,cy*CS
   C.floorRect(Ef,x,z,x+CS,z+CS,0,'lgMarble',1,ao,8)
  end
 end end
 Ef.decor(function()
  for cy=0,C.ch-1 do for cx=0,C.cw-1 do
   if not C.is(cx,cy,'W')then
    local x,z=cx*CS,cy*CS
    for _,q in ipairs({{0,0},{16,0},{16,16},{0,16}})do
     local px,pz=x+q[1],z+q[2]
     Ef.quad({px-c*.7,.04,pz},{px,.04,pz-c*.7},{px+c*.7,.04,pz},{px,.04,pz+c*.7},'lgVerde',1)
    end
   end
  end end
  -- the runner, door to door
  Ef.box(50,0,0,78,.18,D,'lgCarpet',1,{bottom=true})
  Ef.box(50,0,0,51.2,.24,D,'lgGold',1,{bottom=true})
  Ef.box(76.8,0,0,78,.24,D,'lgGold',1,{bottom=true})
  -- the championship medallion
  local cx,cz=64,64
  lib.ringH(Ef,cx,cz,.28,33,36,64,'lgVerde',1)
  lib.ringH(Ef,cx,cz,.30,31.6,33,64,'lgGold',1)
  lib.fanH(Ef,cx,cz,.26,31.6,64,'lgMarble',1.06)
  lib.ringH(Ef,cx,cz,.31,25,30,64,'lgCrimson',1)
  for k=0,23 do
   local a=k/24*pi*2
   local lx,lz=cx+cos(a)*27.5,cz+sin(a)*27.5
   local ox,oz=cos(a+1.2)*1.6,sin(a+1.2)*1.6
   Ef.quad({lx-ox*.4,.33,lz-oz*.4},{lx+oz*.45,.33,lz-ox*.45},{lx+ox,.33,lz+oz},{lx-oz*.45,.33,lz+ox*.45},'lgGold',1)
  end
  lib.starH(Ef,cx,cz,.34,23,9,8,'lgGold','lgCrimson',1.02)
  lib.ringH(Ef,cx,cz,.35,7,8,32,'lgGold',1)
  lib.fanH(Ef,cx,cz,.36,7,16,'lgCrimson',1.05,pi,pi*2)
  lib.fanH(Ef,cx,cz,.36,7,16,'lgMarble',1.1,0,pi)
  Ef.quad({cx-7,.37,cz-.6},{cx+7,.37,cz-.6},{cx+7,.37,cz+.6},{cx-7,.37,cz+.6},'lgVerde',1)
  lib.fanH(Ef,cx,cz,.38,2.2,16,'lgVerde',1)
  lib.fanH(Ef,cx,cz,.39,1.5,16,'lgMarble',1.12)
 end)
 ---------------------------------------------------------------- eagles
 local Ee=C.part('statues',nil,true)
 for i,st in ipairs({{40,16,0},{88,16,0},{40,112,pi},{88,112,pi}})do
  local x,z,yaw=st[1],st[2],st[3]
  local Lm=K.model(Ee,x,0,z,yaw,1)
  Lm.box(-7.6,0,-14,7.6,2,14,'lgVerde',1,{bottom=true})
  Lm.box(-6.8,2,-13,6.8,2.8,13,'lgGold',1,{bottom=true})
  Lm.box(-5.8,2.8,-6,5.8,22,6,'lgMarble',1,{bottom=true})
  Lm.decor(function()
   Lm.box(-6.2,18,-6.4,6.2,19,6.4,'lgGold',1,{})
   Lm.box(-3.8,6,6,3.8,14,6.25,'lgGold',1,{})
   Lm.box(-3.2,6.6,6.25,3.2,13.4,6.4,'lgCrimson',1,{})
   lib.starXY(Lm,0,10,6.45,2.4,1.0,5,'lgGold',1.1)
  end)
  Lm.box(-6.6,22,-6.6,6.6,23.4,6.6,'lgMarble',1,{})
  Lm.box(-6.2,23.4,-6.2,6.2,24,6.2,'lgGold',1,{})
  K.eagle(K.model(Ee,x,24,z+(yaw==0 and .6 or -.6),yaw+(yaw==0 and 0 or 0),1.15),i*5)
  -- a fire bowl on the plinth's tail (the half in the alcove)
  local tz=z+(yaw==0 and -10 or 10)
  local Lb=K.model(Ee,x,2.8,tz,0,1)
  Lb.frustum(0,0,0,2.4,10,2.0,10,'lgMarble')
  local yc=K.fireBowl(Lb,10,1.6,4.2,2.6)
  fx.fires[#fx.fires+1]={x=x,y=2.8+yc+.2,z=tz,s=.95,phase=i*1.7}
  C.addLight(x,14,tz,46,.30)
 end
 ---------------------------------------------------------------- walls
 local DH=40
 local function sanctum(L,len,run)
  local north=run.o=='S'and run.c==0
  local south=run.o=='N'and run.c==D
  local side=run.o=='E'or run.o=='W'
  local pil
  if side and len>60 then pil={4,28,48,len-48,len-28,len-4}end
  pil=classicWall(C,L,len,run,H,{DH=DH,pilasters=pil,step=32,first=len<40 and 8 or 4})
  if side and len>60 then
   -- crimson drapes between the pilasters, sconces with flames
   for _,b in ipairs({{8,24},{len-24,len-8}})do
    drape(L,b[1],b[2],22,H-20)
   end
   L.box(32,20,0,len-32,H-20,.4,'lgGold',1,{})
   L.box(33.2,21.2,.4,len-33.2,H-21.2,.6,'lgCrimson',1,{})
   L.decor(function()
    local m=len/2
    lib.ringXY(L,m,H*.55,.65,9,10.2,32,'lgGold',1)
    lib.starXY(L,m,H*.55,.7,8,3.4,5,'lgGold',1.05)
    laurel(L,m,H*.55,.68,12.6)
   end)
   for _,px in ipairs({28,len-28})do
    L.box(px-1.6,40,1.7,px+1.6,42,6.5,'lgGold',1,{})
    L.frustum(px,42,5.2,1.4,46,2.6,10,'lgGold')
    local wx,wy,wz=run.toWorld(px,46.3,5.2)
    fx.fires[#fx.fires+1]={x=wx,y=wy,z=wz,s=.7,phase=wx*.1+wz*.07}
    C.addLight(wx,wy,wz,44,.28)
   end
  end
  if north or south then
   for _,h in ipairs(run.holes)do
    local a,b=h[1],h[2];local cx=(a+b)/2;local hw=(b-a)/2
    local zb=-26
    -- the reveal and, north, the light of the Hall of Fame beyond
    L.quad({a,0,0},{a,0,zb},{a,DH,zb},{a,DH,0},'lgMarble',.78)
    L.quad({b,0,zb},{b,0,0},{b,DH,0},{b,DH,zb},'lgMarble',.74)
    L.quad({a,DH,0},{b,DH,0},{b,DH,zb},{a,DH,zb},'lgMarble',.6)
    L.quad({a,.02,0},{b,.02,0},{b,.02,zb},{a,.02,zb},'lgMarble',.9)
    if north then
     local saveFlat=C.flat;C.flat=true
     L.quad({a,0,zb},{b,0,zb},{b,DH,zb},{a,DH,zb},'cream',1.6)
     C.flat=saveFlat
     local wx,wy,wz=run.toWorld(cx,DH/2,-6)
     fx.glows[#fx.glows+1]={x=wx,y=wy,z=wz,r=34,col='gold',a=.30}
     fx.beams[#fx.beams+1]={x=wx,y=DH*.8,z=wz-8,tx=wx,ty=0,tz=wz+60,r0=12,r1=22,col={1,.9,.6},a=.06}
    else
     L.quad({a,0,zb},{b,0,zb},{b,DH,zb},{a,DH,zb},'lgMarble',.22)
    end
    -- the arch: gold sunburst in a crimson lunette, the inscription
    local cy=DH
    local ri,ro=hw+1,hw+4.5
    for i=0,17 do
     local a0,a1=i/18*pi,(i+1)/18*pi
     L.quad({cx,cy,.06},{cx+cos(a0)*ri,cy+sin(a0)*ri,.06},{cx+cos(a1)*ri,cy+sin(a1)*ri,.06},{cx,cy,.06},'lgCrimson',.95)
     L.quad({cx+cos(a1)*ri,cy+sin(a1)*ri,1.4},{cx+cos(a0)*ri,cy+sin(a0)*ri,1.4},{cx+cos(a0)*ro,cy+sin(a0)*ro,1.4},{cx+cos(a1)*ro,cy+sin(a1)*ro,1.4},'lgMarble',1)
    end
    L.decor(function()
     lib.ringXY(L,cx,cy,1.46,ri+.3,ri+.9,18,'lgGold',1,0,pi)
     lib.ringXY(L,cx,cy,1.46,ro-.9,ro-.3,18,'lgGold',1,0,pi)
     for i=0,12 do
      local aa=(i+.5)/13*pi;local w=.07
      L.quad({cx+cos(aa-w)*3,cy+sin(aa-w)*3,.12},{cx+cos(aa)*(ri-1.2),cy+sin(aa)*(ri-1.2),.12},{cx+cos(aa+w)*3,cy+sin(aa+w)*3,.12},{cx+cos(aa-w)*3,cy+sin(aa-w)*3,.12},'lgGold',1)
     end
     lib.fan(L,cx,cy,.16,2.6,12,'lgGold',1.05,0,nil,0,pi)
    end)
    L.box(cx-2.2,cy+ri-.5,-.2,cx+2.2,cy+ro+1.2,1.9,'lgMarble',1,{})
    L.box(cx-1.4,cy+ri+.3,1.9,cx+1.4,cy+ro+.5,2.15,'lgGold',1,{})
    L.decor(function()
     C.K.inscription(L,north and'HALL OF FAME'or'CHAMPION',len/2,H-13.8,.6,1.1,'lgGold',len-12)
    end)
    for _,px in ipairs({a-4,b+4})do
     L.box(px-3,0,0,px+3,6.4,2.6,'lgVerde',1,{bottom=true})
     L.frustum(px,6.4,0,2.0,DH+2,1.8,10,'lgMarble',true)
     L.box(px-2.8,DH+2,0,px+2.8,DH+3.4,2.6,'lgGold',1,{})
    end
   end
  end
 end
 C.walls(function(cx,cy)return C.is(cx,cy,'W')end,sanctum,{outside=true,door=function(cx,cy)return(cy==-1 or cy==C.ch)and(cx==3 or cx==4)end})
 ---------------------------------------------------------------- the dome
 local Ec=C.part('ceiling',{below=H})
 -- a flat coffered ring from the walls to the drum, the drum, the dome
 local cx,cz=64,64
 local DR=44
 for z=0,D-16,16 do for x=0,W-16,16 do
  local inside=false
  for _,q in ipairs({{x,z},{x+16,z},{x,z+16},{x+16,z+16}})do
   if (q[1]-cx)^2+(q[2]-cz)^2<DR*DR then inside=true end
  end
  if not inside then
   Ec.quad({x,H,z+16},{x+16,H,z+16},{x+16,H,z},{x,H,z},'lgMarble',.8)
  end
 end end
 local n=40
 local function sq(a)local cs,sn=cos(a),sin(a);local k=64/max(abs(cs),abs(sn));return cx+cs*k,cz+sn*k end
 for i=0,n-1 do
  local a0,a1=i/n*pi*2,(i+1)/n*pi*2
  local o0x,o0z=sq(a0);local o1x,o1z=sq(a1)
  local function clampSq(x,z)
   return max(16,min(112,x)),max(16,min(112,z))
  end
  local ax,az=clampSq(o0x,o0z);local bx,bz=clampSq(o1x,o1z)
  Ec.quad({cx+cos(a1)*DR,H,cz+sin(a1)*DR},{cx+cos(a0)*DR,H,cz+sin(a0)*DR},{ax,H,az},{bx,H,bz},'lgMarble',.82)
 end
 Ec.decor(function()lib.ringH(Ec,cx,cz,H-.1,DR,DR+1.6,n,'lgGold',.95)end)
 local DRUM=10
 for i=0,n-1 do
  local a0,a1=i/n*pi*2,(i+1)/n*pi*2
  Ec.quad({cx+cos(a0)*DR,H,cz+sin(a0)*DR},{cx+cos(a1)*DR,H,cz+sin(a1)*DR},{cx+cos(a1)*DR,H+DRUM,cz+sin(a1)*DR},{cx+cos(a0)*DR,H+DRUM,cz+sin(a0)*DR},'lgMarble',.86)
  if i%4==1 then
   local am=(a0+a1)/2
   local mx,mz=cx+cos(am)*(DR-.3),cz+sin(am)*(DR-.3)
   local tx,tz=-sin(am),cos(am)
   for k=0,9 do
    local b0,b1=k/10*pi*2,(k+1)/10*pi*2
    Ec.quad({mx,H+5,mz},{mx+tx*cos(b0)*2.2,H+5+sin(b0)*2.2,mz+tz*cos(b0)*2.2},{mx+tx*cos(b1)*2.2,H+5+sin(b1)*2.2,mz+tz*cos(b1)*2.2},{mx,H+5,mz},'cream',1.45)
   end
  end
 end
 local oy=dome(C,Ec,cx,cz,DR,H+DRUM,24,n,7)
 -- the light of the oculus, falling on the medallion
 fx.beams[#fx.beams+1]={x=cx,y=oy,z=cz,tx=cx,ty=0,tz=cz,r0=7,r1=30,col={1,.94,.78},a=.09}
 fx.pools[#fx.pools+1]={x=cx,y=.4,z=cz,r=34,a=.10,col={1,.9,.65}}
 -- four spotlights high in the corners, sweeping the floor
 for k,c in ipairs({{20,20},{108,20},{20,108},{108,108}})do
  fx.spots[#fx.spots+1]={x=c[1],y=H-8,z=c[2],tx=64,tz=64,r=6,phase=k*1.6,col={1,.92,.72},a=.07,sweep=26}
 end
 fx.motes={x=cx,z=cz,r=40,y0=2,y1=H,n=40,col={1,.86,.5}}
end

-- ====================================================================
-- THE HALL OF FAME
-- Open to the night: a marble colonnade round a floor of gold, the record
-- itself a gilded console under a laurel arch before a golden apse, HALL
-- OF FAME across it. Overhead the fireworks never stop; confetti falls,
-- searchlights sweep the sky, gold light rises off the floor.
-- ====================================================================
function M.fame(C)
 local K,lib=C.K,C.lib
 local W,D=C.W,C.D
 C.H=96;C.ambient=.92;C.maxLight=1.5
 local H=C.H
 local fx=C.fx
 fx.beams,fx.spots,fx.confetti,fx.motes={}, {}, nil, nil
 fx.ambience={fame=.75}
 fx.fireworks={x=80,z=-120,y=200,scale=.9}
 fx.fanfare=true
 C.addLight(80,40,30,80,.35)
 C.sky(80,64,900,1,-60)
 local solid=function(cx,cy)return C.is(cx,cy,'W')or cx<0 or cx>=C.cw or cy<0 or cy>=C.ch end
 ---------------------------------------------------------------- floor
 local Ef=C.part('floor',nil,true)
 local ao=C.aoField(function(cx,cy)return C.is(cx,cy,'W')end,14)
 for cy=1,C.ch-1 do for cx=0,C.cw-1 do
  C.floorRect(Ef,cx*CS,cy*CS,cx*CS+CS,cy*CS+CS,0,'lgMarble',1.02,ao,8)
 end end
 -- the terrace beyond the colonnade, and the far mountains under the stars
 do
  local Et=C.part('terrace')
  for _,r in ipairs({{-48,16,0,D+40},{W,16,W+48,D+40},{0,D,W,D+40}})do
   C.floorRect(Et,r[1],r[2],r[3],r[4],0,'lgMarble',.82,nil,16)
  end
  -- the terrace edge: a low balustrade
  Et.box(-50,0,16,-46,6,D+40,'lgMarble',.9,{})
  Et.box(W+46,0,16,W+50,6,D+40,'lgMarble',.9,{})
  Et.box(-50,0,D+38,W+50,6,D+42,'lgMarble',.9,{})
  local n=48
  for i=0,n-1 do
   local a0,a1=i/n*pi*2,(i+1)/n*pi*2
   local function top(a)return 30+28*sin(a*3+1)+16*sin(a*7.3)+8*sin(a*17)end
   local R=620
   local function P(a,y)return{80+cos(a)*R,y,64+sin(a)*R}end
   Et.quad(P(a1,-60),P(a0,-60),P(a0,top(a0)),P(a1,top(a1)),'lgRock',.16)
  end
 end
 Ef.decor(function()
  -- the gold sunburst inlay and the star
  local cx,cz=80,80
  for k=0,31 do
   local a=k/32*pi*2
   local w=.035
   local r1=k%2==0 and 46 or 34
   Ef.quad({cx+cos(a-w)*12,.05,cz+sin(a-w)*12},{cx+cos(a)*r1,.05,cz+sin(a)*r1},{cx+cos(a+w)*12,.05,cz+sin(a+w)*12},{cx+cos(a-w)*12,.05,cz+sin(a-w)*12},'lgGold',1)
  end
  lib.ringH(Ef,cx,cz,.06,30,31.4,64,'lgGold',1)
  lib.ringH(Ef,cx,cz,.06,11.6,13,32,'lgGold',1)
  lib.starH(Ef,cx,cz,.08,11,4.6,5,'lgGold','lgCrimson',1.05)
  -- the runner from the door to the record
  Ef.box(68,0,34,92,.18,D,'lgCarpet',1,{bottom=true})
  Ef.box(68,0,34,69.2,.24,D,'lgGold',1,{bottom=true})
  Ef.box(90.8,0,34,92,.24,D,'lgGold',1,{bottom=true})
 end)
 ---------------------------------------------------------------- the record
 do
  local Er=C.part('record',nil,true)
  local L=K.model(Er,80,0,24,0,1)
  -- the plinth steps, the console, a slanted screen of light
  L.box(-17,0,-8,17,1.4,9,'lgVerde',1,{bottom=true})
  L.box(-15.6,1.4,-7,15.6,2.2,8.2,'lgGold',1,{bottom=true})
  L.box(-14,2.2,-6,14,15,6,'lgMarble',1,{bottom=true})
  L.decor(function()
   for k=-2,2 do L.box(k*5.4-1.8,4,6,k*5.4+1.8,12.4,6.25,'lgGold',1,{})end
   L.box(-14.2,13,-6.2,14.2,13.8,6.2,'lgGold',1,{})
  end)
  L.quad({-12,15,4.5},{12,15,4.5},{12,19,-2},{-12,19,-2},'lgMarble',.95)
  local saveFlat=C.flat;C.flat=true
  L.quad({-10.6,15.3,3.7},{10.6,15.3,3.7},{10.6,18.6,-1.3},{-10.6,18.6,-1.3},'lgCrystal',1.2)
  C.flat=saveFlat
  L.box(-14,15,-6,14,19,-2,'lgMarble',.9,{})
  -- the laurel arch over it, a gold star crowning it
  for _,sx in ipairs({-1,1})do
   L.box(sx*19-2.4,0,-4,sx*19+2.4,3,4,'lgVerde',1,{bottom=true})
   L.frustum(sx*19,3,0,1.8,40,1.6,10,'lgGold',true)
  end
  for i=0,15 do
   local a0,a1=i/16*pi,(i+1)/16*pi
   local r0,r1=17.4,20.6
   L.quad({cos(a0)*r1,40+sin(a0)*r1,-1.2},{cos(a1)*r1,40+sin(a1)*r1,-1.2},{cos(a1)*r0,40+sin(a1)*r0,-1.2},{cos(a0)*r0,40+sin(a0)*r0,-1.2},'lgGold',1)
   L.quad({cos(a0)*r1,40+sin(a0)*r1,1.2},{cos(a1)*r1,40+sin(a1)*r1,1.2},{cos(a1)*r0,40+sin(a1)*r0,1.2},{cos(a0)*r0,40+sin(a0)*r0,1.2},'lgGold',1)
   L.quad({cos(a0)*r1,40+sin(a0)*r1,1.2},{cos(a1)*r1,40+sin(a1)*r1,1.2},{cos(a1)*r1,40+sin(a1)*r1,-1.2},{cos(a0)*r1,40+sin(a0)*r1,-1.2},'lgGold',.9)
  end
  L.decor(function()
   for k=0,15 do
    local a=(k+.5)/16*pi
    local lx,ly=cos(a)*19,40+sin(a)*19
    for _,sg in ipairs({-1,1})do
     local ox,oy=cos(a+sg*1.0)*2.6,sin(a+sg*1.0)*2.6
     L.quad({lx,ly,1.25},{lx+ox*.6-oy*.25,ly+oy*.6+ox*.25,1.25},{lx+ox,ly+oy,1.25},{lx+ox*.6+oy*.25,ly+oy*.6-ox*.25,1.25},'lgVerde',1.05)
    end
   end
  end)
  lib.starXY(L,0,64,0,6.4,2.6,5,'lgGold',1.15)
  lib.starXY(L,0,64,-.3,6.4,2.6,5,'lgGold',1.0)
  fx.glows[#fx.glows+1]={x=80,y=64,z=24,r=26,col='gold',a=.45}
  fx.glows[#fx.glows+1]={x=80,y=18,z=28,r=16,col='cyan',a=.35}
  fx.beams[#fx.beams+1]={x=80,y=19,z=24,tx=80,ty=240,tz=10,r0=3,r1=26,col={1,.9,.6},a=.10}
 end
 ---------------------------------------------------------------- walls
 local DH=44
 local function apse(L,len,run)
  -- the north wall: gold-veined marble, a golden apse behind the record,
  -- HALL OF FAME across it, laurels and trophies in the bays
  local cx=len/2
  local R=26;local n=16
  classicWall(C,L,len,run,H,{pilasters={4,36,124,156},step=32,holes={{cx-R,cx+R,H-24}}})
  -- the apse: a half-round niche of gold, its floor marble
  for i=0,n-1 do
   local a0,a1=i/n*pi,(i+1)/n*pi
   L.quad({cx,.01,0},{cx-cos(a1)*R,.01,-sin(a1)*R*.55},{cx-cos(a0)*R,.01,-sin(a0)*R*.55},{cx,.01,0},'lgMarble',.9)
  end
  for i=0,n-1 do
   local a0,a1=i/n*pi,(i+1)/n*pi
   local function P(a,y)return{cx-cos(a)*R,y,-sin(a)*R*.55+.2}end
   L.quad(P(a1,0),P(a0,0),P(a0,H-24),P(a1,H-24),i%2==0 and'lgGold'or'lgCrimson',.95)
  end
  for i=0,n-1 do
   local a0,a1=i/n*pi,(i+1)/n*pi
   L.quad({cx,H-24,.2},{cx-cos(a0)*R,H-24,-sin(a0)*R*.55+.2},{cx-cos(a1)*R,H-24,-sin(a1)*R*.55+.2},{cx,H-24,.2},'lgGold',.7)
  end
  -- the sunburst over the apse
  L.decor(function()
   for i=0,22 do
    local aa=(i+.5)/23*pi;local w=.05
    L.quad({cx+cos(aa-w)*R,H-24+sin(aa-w)*R*.2,1.2},{cx+cos(aa)*(R+12),H-24+sin(aa)*14,1.2},{cx+cos(aa+w)*R,H-24+sin(aa+w)*R*.2,1.2},{cx+cos(aa-w)*R,H-24+sin(aa-w)*R*.2,1.2},'lgGold',1.05)
   end
   C.K.inscription(L,'HALL OF FAME',cx,H-13.8,.6,1.25,'lgGold',len-30)
  end)
  -- laurel medallions and trophies in the bays
  for _,bx in ipairs({20,140})do
   L.box(bx-11,22,0,bx+11,60,.5,'lgGold',1,{})
   L.box(bx-10,23,.5,bx+10,59,.8,'lgCrimson',1,{})
   L.decor(function()
    laurel(L,bx,44,.85,8)
    lib.starXY(L,bx,44,.9,5,2,5,'lgGold',1.08)
   end)
   L.box(bx-6,0,0,bx+6,14,7,'lgMarble',1,{bottom=true})
   L.box(bx-6.6,14,-.6,bx+6.6,15,7.6,'lgGold',1,{})
   trophy(L,bx,15,3.4,1.6)
  end
 end
 local function colonnade(L,len,run)
  -- the open sides: a balustrade, columns, an entablature; the night
  -- between them
  local holes=run.holes
  local spans={}
  local x=0
  for _,h in ipairs(holes)do if h[1]>x then spans[#spans+1]={x,h[1]}end;x=h[2]end
  if x<len then spans[#spans+1]={x,len}end
  for _,sp in ipairs(spans)do
   local a,b=sp[1],sp[2]
   if b-a>.5 then
    L.box(a,0,0,b,3,3.4,'lgVerde',1,{bottom=true})
    L.box(a,3,.6,b,12,2.8,'lgMarble',.92,{bottom=true})
    L.decor(function()
     local bx=a+2
     while bx<b-1.5 do L.frustum(bx,3,1.7,.7,12,.7,6,'lgMarble',false);bx=bx+3.2 end
    end)
    L.box(a,12,0,b,13.6,3.4,'lgGold',1,{})
   end
  end
  local cols={}
  local px=0
  while px<=len+.01 do cols[#cols+1]=px;px=px+32 end
  for _,c in ipairs(cols)do
   if not inHole(holes,c)then
    L.box(c-4,0,-1,c+4,6,5,'lgVerde',1,{bottom=true})
    L.box(c-3.4,6,-.4,c+3.4,7,4.4,'lgGold',1,{bottom=true})
    L.frustum(c,7,2,2.8,70,2.4,12,'lgMarble',false)
    L.decor(function()
     for f=0,11 do
      local a=f/12*pi*2
      L.box(c+cos(a)*2.55-.2,9,2+sin(a)*2.55-.2,c+cos(a)*2.55+.2,68,2+sin(a)*2.55+.2,'lgMarble',.8,{})
     end
    end)
    L.frustum(c,70,2,2.4,72,3.6,12,'lgGold',false)
    L.box(c-4,72,-2,c+4,74,6,'lgGold',1,{})
   end
  end
  -- the entablature (a span over the door too)
  L.box(0,74,-2,len,77,6,'lgMarble',1,{})
  L.box(0,77,-2.2,len,83,6.2,'lgCrimson',1,{})
  L.decor(function()
   local dx=1
   while dx<len-1 do
    L.quad({dx,79,6.25},{dx+1.4,79,6.25},{dx+1.4,81,6.25},{dx,81,6.25},'lgGold',1);dx=dx+4
   end
  end)
  L.box(0,83,-2.6,len,84.6,6.6,'lgGold',1,{})
  L.box(0,84.6,-3,len,87,7,'lgMarble',1,{})
  -- trophies standing on the balustrade between the columns
  for i=1,#cols-1 do
   local m=(cols[i]+cols[i+1])/2
   if not inHole(holes,m)then trophy(L,m,13.6,1.7,.9)end
  end
  -- the doorway in the south: an arch of gold
  for _,h in ipairs(holes)do
   local a,b=h[1],h[2];local cx=(a+b)/2;local hw=(b-a)/2
   for _,sx in ipairs({a-3,b+3})do
    L.box(sx-3,0,-1,sx+3,DH,5,'lgMarble',1,{bottom=true})
    L.box(sx-3.4,DH,-1.4,sx+3.4,DH+1.6,5.4,'lgGold',1,{})
   end
   for i=0,11 do
    local a0,a1=i/12*pi,(i+1)/12*pi
    L.quad({cx+cos(a0)*(hw+6),DH+sin(a0)*(hw+6)*.7,2},{cx+cos(a1)*(hw+6),DH+sin(a1)*(hw+6)*.7,2},{cx+cos(a1)*(hw+1),DH+sin(a1)*(hw+1)*.7,2},{cx+cos(a0)*(hw+1),DH+sin(a0)*(hw+1)*.7,2},'lgGold',1)
   end
   L.quad({a,0,-20},{b,0,-20},{b,DH,-20},{a,DH,-20},'lgMarble',.25)
   L.quad({a,0,0},{a,0,-20},{a,DH,-20},{a,DH,0},'lgMarble',.6)
   L.quad({b,0,-20},{b,0,0},{b,DH,0},{b,DH,-20},'lgMarble',.6)
   L.quad({a,.02,0},{b,.02,0},{b,.02,-20},{a,.02,-20},'lgMarble',.7)
   L.quad({a,DH,0},{b,DH,0},{b,DH,-20},{a,DH,-20},'lgMarble',.5)
  end
 end
 C.walls(function(cx,cy)return C.is(cx,cy,'W')end,function(L,len,run)
  if run.o=='S'and run.c==16 then apse(L,len,run)else colonnade(L,len,run)end
 end,{outside=true,always=true,door=function(cx,cy)return cy==C.ch and(cx==4 or cx==5)end})
 -- corners: square piers where the colonnades meet
 local Ep=C.part('piers',nil,true)
 for _,p in ipairs({{0,16},{W,16},{0,D},{W,D}})do
  local Lp=K.model(Ep,p[1],0,p[2],0,1)
  Lp.box(-5,0,-5,5,87,5,'lgMarble',1,{bottom=true})
  Lp.box(-5.6,0,-5.6,5.6,6,5.6,'lgVerde',1,{bottom=true})
  Lp.box(-5.8,84,-5.8,5.8,88,5.8,'lgGold',1,{})
  local Lb=K.model(Ep,p[1],88,p[2],0,1)
  local yc=K.fireBowl(Lb,0,2.6,5.6,3.2)
  fx.fires[#fx.fires+1]={x=p[1],y=88+yc+.2,z=p[2],s=1.3,phase=p[1]*.01+p[2]*.03}
  -- a searchlight from each corner, sweeping the sky
  fx.spots[#fx.spots+1]={x=p[1],y=95,z=p[2],sky=true,r=9,phase=p[1]*.02+p[2]*.05,col={.80,.88,1},a=.09}
 end
 ---------------------------------------------------------------- effects
 fx.confetti={x0=0,x1=W,z0=16,z1=D,y0=0,y1=110,n=160}
 fx.motes={x=80,z=72,r=60,y0=1,y1=80,n=40,col={1,.85,.45}}
 fx.pools[#fx.pools+1]={x=80,y=.3,z=80,r=60,a=.08,col={1,.86,.5}}
end

-- a crystal chandelier hung from y=top (the antechamber's, reused)
local function chandelier(C,Ec,fx,X,Y,Z,s,top,arms)
 local K=C.K
 local Lc=K.model(Ec,X,Y,Z,0,s)
 Ec.box(X-.25,Y+10.5*s,Z-.25,X+.25,top,Z+.25,'lgGold',1,{bottom=true,top=true})
 Lc.frustum(0,-1.6,0,.1,0,.9,8,'lgGold')
 Lc.frustum(0,0,0,.9,1.4,1.6,8,'lgGold')
 Lc.frustum(0,1.4,0,1.6,3.2,1.0,8,'lgGold')
 Lc.frustum(0,3.2,0,.55,9,.45,8,'lgGold')
 Lc.sphere(0,6.2,0,1.3,1.6,1.3,'lgGold',8,4)
 Lc.frustum(0,9,0,.45,10.5,1.8,8,'lgGold',true)
 Lc.frustum(0,3.4,0,6.6,4.2,6.6,20,'lgGold')
 Lc.frustum(0,4.2,0,6.6,4.2,6.0,20,'lgGold')
 Lc.frustum(0,7.6,0,3.6,8.2,3.6,16,'lgGold')
 for k=0,arms-1 do
  local a=k/arms*pi*2+pi/arms
  local La=K.model(Ec,X,Y,Z,-a,s)
  La.box(.6,2.4,-.22,7.4,2.9,.22,'lgGold',1,{bottom=false})
  La.box(7.0,2.9,-.22,7.5,4.0,.22,'lgGold',1,{bottom=false})
  La.frustum(7.25,4.0,0,.45,4.8,1.0,8,'lgGold',true)
  La.frustum(7.25,4.8,0,.36,7.0,.33,8,'lgMarble',true)
  La.frustum(6.6,1.2,0,.08,3.4,.42,6,'lgCrystal',false)
  La.frustum(3.6,5.2,0,.06,7.6,.32,6,'lgCrystal',false)
  local cx,cz=X+cos(a)*7.25*s,Z+sin(a)*7.25*s
  fx.candles[#fx.candles+1]={x=cx,y=Y+7.1*s,z=cz,s=.85*s,a=.30,phase=k*1.3+X*.1,ceil=true}
 end
 for k=0,arms/2-1 do
  local a=k/(arms/2)*pi*2
  local La=K.model(Ec,X,Y,Z,-a,s)
  La.box(.4,8.6,-.2,3.8,9.0,.2,'lgGold',1,{bottom=false})
  La.frustum(3.8,9.0,0,.4,9.7,.85,8,'lgGold',true)
  La.frustum(3.8,9.7,0,.3,11.4,.28,8,'lgMarble',true)
  fx.candles[#fx.candles+1]={x=X+cos(a)*3.8*s,y=Y+11.5*s,z=Z+sin(a)*3.8*s,s=.75*s,a=.28,phase=k*2.1+X*.07,ceil=true}
 end
 fx.pools[#fx.pools+1]={x=X,y=.32,z=Z,r=34*s,a=.07,ceil=true}
 C.addLight(X,Y,Z,64*s,.22)
end
M.chandelier=chandelier

-- ====================================================================
-- THE INDIGO PLATEAU LOBBY
-- A marble concourse in the League's finishes. The crimson road runs from
-- the doors to the Elite Four's portal; the Pokemon Center's counter is a
-- long marble bar under the League's crest; the mart is a little gilded
-- boutique; a fire burns in the gallery's hearth, trophies stand on a
-- podium, cypresses and flowers grow in great planters, and crystal
-- chandeliers hang from a coffered ceiling round a dome of light.
-- ====================================================================
function M.lobby(C)
 local K,lib=C.K,C.lib
 local W,D=C.W,C.D
 local F=V.require('LeagueFlora')
 C.H=96;C.ambient=.86;C.maxLight=1.45
 local H=C.H
 local fx=C.fx
 fx.beams,fx.motes={}, nil
 fx.ambience={lobby=.6}
 local solid=function(cx,cy)return C.is(cx,cy,'WX')or cx<0 or cx>=C.cw or cy<0 or cy>=C.ch end
 C.addLight(32,20,8,60,.40)
 C.addLight(128,30,190,70,.30)
 ---------------------------------------------------------------- floor
 local Ef=C.part('floor',nil,true)
 local ao=C.aoField(function(cx,cy)return solid(cx,cy)end,14)
 for cy=0,C.ch-1 do for cx=0,C.cw-1 do
  if not C.is(cx,cy,'WX')then C.floorRect(Ef,cx*CS,cy*CS,cx*CS+CS,cy*CS+CS,0,'lgMarble',1,ao,8)end
 end end
 Ef.decor(function()
  -- verde cabochons at the cell corners
  for cy=0,C.ch do for cx=0,C.cw do
   local ok=true
   for _,d in ipairs({{-1,-1},{0,-1},{-1,0},{0,0}})do if C.is(cx+d[1],cy+d[2],'WX')then ok=false end end
   if ok and cx>0 and cy>0 and cx<C.cw and cy<C.ch then
    local px,pz=cx*CS,cy*CS;local c=2.2
    Ef.quad({px-c,.04,pz},{px,.04,pz-c},{px+c,.04,pz},{px,.04,pz+c},'lgVerde',1)
   end
  end end
  -- the crimson road: doors -> concourse -> aisle -> gallery -> portal
  local function road(x0,z0,x1,z1)
   Ef.box(x0,0,z0,x1,.18,z1,'lgCarpet',1,{bottom=true})
   if x1-x0>z1-z0 then
    Ef.box(x0,0,z0,x1,.24,z0+1.2,'lgGold',1,{bottom=true});Ef.box(x0,0,z1-1.2,x1,.24,z1,'lgGold',1,{bottom=true})
   else
    Ef.box(x0,0,z0,x0+1.2,.24,z1,'lgGold',1,{bottom=true});Ef.box(x1-1.2,0,z0,x1,.24,z1,'lgGold',1,{bottom=true})
   end
  end
  road(116,126,140,192)
  road(36,114,140,126)
  road(36,24,60,126)
  road(36,24,140,36)
  road(130,4,142,36)
  -- the League's crest on the concourse floor
  local cx,cz=196,152
  lib.ringH(Ef,cx,cz,.06,24,26,48,'lgVerde',1)
  lib.ringH(Ef,cx,cz,.07,22.8,24,48,'lgGold',1)
  lib.starH(Ef,cx,cz,.08,21,8,8,'lgGold','lgCrimson',1.02)
  lib.ringH(Ef,cx,cz,.09,6.4,7.2,32,'lgGold',1)
  lib.fanH(Ef,cx,cz,.10,6.4,16,'lgCrimson',1.05,pi,pi*2)
  lib.fanH(Ef,cx,cz,.10,6.4,16,'lgMarble',1.1,0,pi)
  Ef.quad({cx-6.4,.11,cz-.5},{cx+6.4,.11,cz-.5},{cx+6.4,.11,cz+.5},{cx-6.4,.11,cz+.5},'lgVerde',1)
  lib.fanH(Ef,cx,cz,.12,1.8,16,'lgVerde',1)
 end)
 ---------------------------------------------------------------- the counter
 local Ec=C.part('counter',nil,true)
 do
  local L=K.model(Ec,0,0,0,0,1)
  -- the bar: marble body, verde panels, gold rail and top
  local function bar(x0,x1)
   L.box(x0,0,97,x1,13,110,'lgMarble',1,{bottom=true})
   L.box(x0-.4,13,96.4,x1+.4,14.4,110.6,'lgGold',1,{bottom=true})
   L.box(x0,0,110,x1,3,110.8,'lgVerde',1,{bottom=true})
   L.decor(function()
    local k=x0+3
    while k+10<=x1-2 do
     L.box(k,4.5,110,k+10,11,110.35,'lgGold',1,{})
     L.box(k+.8,5.2,110.35,k+9.2,10.3,110.55,'lgCrimson',1,{})
     k=k+12
    end
   end)
  end
  bar(64,208)
  if C.variant~='union'then bar(224,256)end
  -- the nurse's bell on the counter
  L.frustum(120,14.4,103,1.1,15.8,.2,10,'lgGold',true)
  -- behind: the healing machine, a cabinet, the link desk
  L.box(76,0,66,108,20,80,'lgMarble',1,{bottom=true})
  L.box(75.4,20,65.4,108.6,21.2,80.6,'lgGold',1,{})
  L.decor(function()
   for k=0,5 do
    local bx=80+(k%3)*9;local by=k<3 and 15 or 9
    L.box(bx,by,80,bx+6,by+4,80.4,'lgVerde',1,{})
   end
  end)
  for k=0,5 do
   local bx=83+(k%3)*9;local by=k<3 and 17 or 11
   L.sphere(bx,by,80.9,1.5,1.5,1.0,k%2==0 and'lgCrimson'or'lgMarble',8,4)
  end
  L.box(150,0,66,206,24,76,'lgWood',1,{bottom=true})
  L.decor(function()
   for k=0,3 do L.box(152+k*13.5,4,76,163+k*13.5,22,76.3,'lgGold',1,{})end
  end)
  for k=0,3 do trophy(L,157+k*13.5,24,71,.8)end
  if C.variant~='union'then
   L.box(212,0,66,254,16,78,'lgMarble',1,{bottom=true})
   L.box(211.4,16,65.4,254.6,17,78.6,'lgGold',1,{})
  else
   -- TEST179: the union room's stairs up (the engine's warp at 15,5) and
   -- its PC (15,7), in the League's marble and gold
   local IK=V.require('InteriorKit')
   IK.stairsUp(C,Ec,240,256,80,96,{tread='lgMarble',riser='lgVerde',rail='lgGold',handrail='lgGold',side=241,n=4,top=14})
   local Lp=K.model(Ec,248,0,120,0,1)
   Lp.box(-6,0,-5,6,12,5,'lgMarble',1,{bottom=true})
   Lp.box(-6.4,12,-5.4,6.4,13,5.4,'lgGold',1,{})
   Lp.box(-5,13,-3,5,22,-1,'lgVerde',1,{})
   local saveFlat=C.flat;C.flat=true
   Lp.quad({-4.2,14,-.95},{4.2,14,-.95},{4.2,21,-.95},{-4.2,21,-.95},'lgCrystal',1)
   C.flat=saveFlat
   Lp.box(-4,13.2,.5,4,14,4.5,'lgGold',1,{})
  end
 end
 ---------------------------------------------------------------- the mart
 do
  local L=K.model(Ec,0,0,0,0,1)
  -- the counter facing the aisle, shelves of bottles on the west wall
  L.box(17,0,49,31,13,111,'lgMarble',1,{bottom=true})
  L.box(16.4,13,48.4,31.6,14.4,111.6,'lgGold',1,{})
  L.decor(function()
   for k=0,4 do L.box(31,4.5,52+k*12,31.35,11,62+k*12,'lgGold',1,{})end
  end)
  for _,z0 in ipairs({50,66,98})do
   L.box(0,0,z0,8,44,z0+14,'lgWood',1,{bottom=true})
   for sh=0,3 do
    local y=8+sh*9
    L.box(0,y,z0,9,y+.8,z0+14,'lgGold',1,{})
    for b=0,3 do
     local bz=z0+2+b*3.4
     local col=({'lgAmethyst','lgCrystal','lgCrimson','lgGold'})[(sh+b)%4+1]
     L.frustum(5,y+.8,bz,1.0,y+4.6,.9,6,col,false)
     L.frustum(5,y+4.6,bz,.9,y+6.2,.35,6,col,true)
    end
   end
  end
  L.decor(function()C.K.inscription(L,'MART',17,50,48.2,.9,'lgGold',12)end)
 end
 ---------------------------------------------------------------- hearth
 do
  local L=K.model(Ec,32,0,0,0,1)
  L.box(-20,0,0,20,32,6,'lgMarble',1,{bottom=true})
  L.box(-11,0,6,11,20,6.2,'lgVerde',.3,{})
  L.quad({-10,.1,6.4},{10,.1,6.4},{10,.1,2},{-10,.1,2},'lgRock',.5)
  L.box(-22,32,0,22,35,10,'lgMarble',1,{})
  L.box(-22.6,35,-.6,22.6,36.2,10.6,'lgGold',1,{})
  L.box(-13,0,6,-11,20,9,'lgMarble',1,{})
  L.box(11,0,6,13,20,9,'lgMarble',1,{})
  L.box(-13,20,6,13,23,9,'lgMarble',1,{})
  L.decor(function()
   L.box(-14,0,9,-10,22,9.3,'lgGold',1,{})
   L.box(10,0,9,14,22,9.3,'lgGold',1,{})
   lib.starXY(L,0,27.5,6.05,3.2,1.3,5,'lgGold',1.1)
  end)
  -- the logs and the fire
  F.limb(Ec,'lgBark',{24,1.2,3},{40,1.6,4.5},1.1,1.0,6)
  F.limb(Ec,'lgBark',{26,1.0,5},{38,2.4,2.5},1.0,.9,6)
  fx.fires[#fx.fires+1]={x=32,y=2.4,z=4.5,s=1.15,phase=.7}
  fx.pools[#fx.pools+1]={x=32,y=.3,z=22,r=26,a=.12}
  -- a gilded mirror over the mantel
  L.box(-15,40,0,15,70,.8,'lgGold',1,{})
  L.box(-13,42,.8,13,68,1.0,'lgSilver',1,{})
  -- urns either side
  for _,ux in ipairs({8,56})do
   local Lu=K.model(Ec,ux,0,24,0,1)
   Lu.box(-6,0,-6,6,4,6,'lgVerde',1,{bottom=true})
   K.urn(K.model(Ec,ux,4,24,0,1.3),ux)
  end
 end
 ---------------------------------------------------------------- the podium
 do
  local L=K.model(Ec,32,0,144,0,1)
  L.box(-31,0,-15,31,4,15,'lgVerde',1,{bottom=true})
  L.box(-30,4,-14,30,5,14,'lgGold',1,{bottom=true})
  L.box(-26,5,-11,26,12,11,'lgMarble',1,{bottom=true})
  L.box(-14,12,-7,14,20,7,'lgMarble',1,{bottom=true})
  L.box(-14.5,20,-7.5,14.5,21,7.5,'lgGold',1,{})
  trophy(L,0,21,0,2.4)
  trophy(L,-20,12,0,1.4);trophy(L,20,12,0,1.4)
  trophy(L,-10,12,8,1.0);trophy(L,10,12,8,1.0)
  L.decor(function()
   C.K.inscription(L,'CHAMPIONS',0,6.2,11,.9,'lgGold',44)
  end)
  fx.glows[#fx.glows+1]={x=32,y=34,z=144,r=18,col='gold',a=.20}
 end
 ---------------------------------------------------------------- planters
 do
  local function planter(x,z,w,d,tall)
   local L=K.model(Ec,x,0,z,0,1)
   L.box(-w/2,0,-d/2,w/2,8,d/2,'lgMarble',1,{bottom=true})
   L.box(-w/2-.6,8,-d/2-.6,w/2+.6,9.2,d/2+.6,'lgGold',1,{})
   L.box(-w/2,0,-d/2,w/2,2,d/2,'lgVerde',1,{bottom=true})
   L.quad({-w/2+1,8.6,d/2-1},{w/2-1,8.6,d/2-1},{w/2-1,8.6,-d/2+1},{-w/2+1,8.6,-d/2+1},'lgBloom',1)
   for i,t in ipairs(tall)do F.cypress(Ec,x+t[1],8.6,z+t[2],t[3],i*7+x,0,1)end
  end
  planter(224,176,60,28,{{-18,0,42},{0,-2,50},{18,0,42}})
  if C.variant~='union'then planter(248,120,14,14,{{0,0,38}})end
 end
 ---------------------------------------------------------------- walls
 local DH=40
 local function hall(L,len,run)
  local main=run.o=='N'and run.c==D
  local back=run.o=='S'and run.c==64
  -- the Elite Four's doorway: its back is the portal's own light
  if run.o=='S'and run.c==0 and run.a0==128 then return end
  local o={DH=DH,step=32,first=8}
  local pil=classicWall(C,L,len,run,H,o)
  -- crimson banners between the pilasters, sconces
  for i=1,#pil-1 do
   local a,b=pil[i],pil[i+1]
   local m=(a+b)/2
   if b-a>20 and not inHole(run.holes,a+3)and not inHole(run.holes,b-3)and not inHole(run.holes,m)then
    if back and m>140 and m<190 then
     -- the League's crest over the counter
    else
     L.box(a+5,22,0,b-5,H-24,.4,'lgGold',1,{})
     L.box(a+6,23,.4,b-6,H-25,.6,'lgCrimson',1,{})
     L.decor(function()
      lib.ringXY(L,m,H*.52,.65,5.4,6.2,24,'lgGold',1)
      lib.starXY(L,m,H*.52,.7,4.6,1.9,5,'lgGold',1.05)
     end)
     local wx,wy,wz=run.toWorld(a+4,36,4)
     if b-a>28 then
      L.box(a+2.6,33,1.0,a+5.4,35,4.5,'lgGold',1,{})
      L.frustum(a+4,35,4,1.2,38,2.2,8,'lgGold')
      fx.fires[#fx.fires+1]={x=wx,y=38.3,z=wz,s=.55,phase=wx*.1+wz*.1}
     end
    end
   end
  end
  if back then
   -- the crest: a great gold star in a laurel over POKEMON CENTER
   local cx=len/2+8
   L.box(cx-30,26,0,cx+30,H-22,.5,'lgGold',1,{})
   L.box(cx-29,27,.5,cx+29,H-23,.8,'lgCrimson',1,{})
   L.decor(function()
    lib.ringXY(L,cx,52,.9,14,15.4,40,'lgGold',1)
    lib.starXY(L,cx,52,.95,12.6,5.2,5,'lgGold',1.08)
    laurel(L,cx,52,.92,18)
    C.K.inscription(L,'POKEMON CENTER',cx,30,.9,1.1,'lgGold',54)
   end)
  end
  if main then
   -- the doors out to the Plateau: gold and glass, daylight beyond
   for _,h in ipairs(run.holes)do
    local a,b=h[1],h[2]
    local zb=-14
    L.quad({a,0,0},{a,0,zb},{a,DH,zb},{a,DH,0},'lgMarble',.75)
    L.quad({b,0,zb},{b,0,0},{b,DH,0},{b,DH,zb},'lgMarble',.72)
    L.quad({a,DH,0},{b,DH,0},{b,DH,zb},{a,DH,zb},'lgMarble',.6)
    local saveFlat=C.flat;C.flat=true
    L.quad({a,0,zb},{b,0,zb},{b,DH,zb},{a,DH,zb},'cream',1.6)
    C.flat=saveFlat
    for _,sx in ipairs({a-4,b+4})do
     L.box(sx-3.2,0,0,sx+3.2,6.4,2.6,'lgVerde',1,{bottom=true})
     L.frustum(sx,6.4,0,2.2,DH+3,2.0,10,'lgMarble',true)
     L.box(sx-2.9,DH+3,0,sx+2.9,DH+4.4,2.6,'lgGold',1,{})
    end
    local cx=(a+b)/2
    L.box(a-8,DH+4.4,-.5,b+8,DH+9,3,'lgMarble',1,{})
    L.box(a-8.5,DH+9,-1,b+8.5,DH+10.2,3.5,'lgGold',1,{})
    L.decor(function()C.K.inscription(L,'INDIGO PLATEAU',cx,DH+5.6,3,.8,'lgGold',b-a+12)end)
    local wx,wy,wz=run.toWorld(cx,DH*.6,-8)
    fx.glows[#fx.glows+1]={x=wx,y=wy,z=wz,r=30,col='white',a=.25}
    fx.beams[#fx.beams+1]={x=wx,y=DH-4,z=wz,tx=wx,ty=0,tz=wz-50,r0=10,r1=20,col={1,.95,.85},a=.06}
   end
  end
 end
 C.walls(function(cx,cy)return C.is(cx,cy,'WX')end,hall,{outside=true,door=function(cx,cy)return cy==C.ch and(cx==7 or cx==8)end})
 ---------------------------------------------------------------- the Elite Four's portal
 do
  local E=C.part('portal',{axis='z',c=0,s=1})
  local L=K.model(E,136,0,0,0,1)
  -- the passage beyond: crimson light
  local saveFlat=C.flat;C.flat=true
  L.quad({-8,0,-.5},{8,0,-.5},{8,30,-.5},{-8,30,-.5},'lgCrimson',1.4)
  C.flat=saveFlat
  -- a tall gilded frame on the wall cells either side, a pediment
  for _,sx in ipairs({-1,1})do
   L.box(sx*8-(sx<0 and 6 or 0),0,16,sx*8+(sx>0 and 6 or 0),36,19,'lgMarble',1,{bottom=true})
   L.box(sx*11-2.6,0,16,sx*11+2.6,6.4,20,'lgVerde',1,{bottom=true})
   L.frustum(sx*11,6.4,18.5,2,36,1.8,10,'lgMarble',true)
   L.box(sx*11-2.8,36,16,sx*11+2.8,37.4,20.6,'lgGold',1,{})
  end
  L.box(-15,37.4,15.5,15,42,20.4,'lgMarble',1,{})
  L.box(-15.6,42,15,15.6,43.2,21,'lgGold',1,{})
  L.quad({-15,43.2,20.2},{15,43.2,20.2},{0,51,20.2},{0,51,20.2},'lgMarble',.95)
  L.decor(function()
   C.K.inscription(L,'ELITE FOUR',0,38.4,20.4,.75,'lgGold',28)
   L.quad({-12,43.6,20.3},{12,43.6,20.3},{0,49.6,20.3},{0,49.6,20.3},'lgCrimson',1)
  end)
  -- the four emblems over it: ice, the sun of the dojo, the violet orb, the dragon's eye
  local em={{'lgCrystal',-21},{'lgGold',-7},{'lgAmethyst',7},{'lgLava',21}}
  for _,e in ipairs(em)do
   local ex,ey=e[2],60
   lib.ringXY(L,ex,ey,16.6,4.2,5.2,20,'lgGold',1)
   local saveF=C.flat;C.flat=true
   local Lm=K.model(E,136,0,0,0,1,e[1]=='lgAmethyst'and 3 or 1.2)
   lib.fan(Lm,ex,ey,16.4,4.2,20,e[1],1,0)
   C.flat=saveF
  end
  L.box(-28,54,16,28,66,16.4,'lgCrimson',1,{})
  fx.glows[#fx.glows+1]={x=136,y=16,z=4,r=18,col='red',a=.25}
 end
 -- the roof over the solid masses, for a camera above the walls
 do
  local Ek=C.part('caps',{above=H})
  for cy=0,C.ch-1 do for cx=0,C.cw-1 do
   if C.is(cx,cy,'WX')then
    local x,z=cx*CS,cy*CS
    Ek.quad({x,H+.9,z+CS},{x+CS,H+.9,z+CS},{x+CS,H+.9,z},{x,H+.9,z},'lgMarble',.9)
   end
  end end
 end
 ---------------------------------------------------------------- ceiling
 local Ecl=C.part('ceiling',{below=H})
 local DX,DZ,DR=128,152,32
 for z=0,D-16,16 do for x=0,W-16,16 do
  local inDome=false
  for _,q in ipairs({{x,z},{x+16,z},{x,z+16},{x+16,z+16}})do if (q[1]-DX)^2+(q[2]-DZ)^2<DR*DR then inDome=true end end
  if not C.is(floor(x/16),floor(z/16),'WX')and not inDome then
   local f,g,dp=1.2,2.6,3.2
   local function down(x0,z0,x1,z1,y,mat,t)Ecl.quad({x0,y,z1},{x1,y,z1},{x1,y,z0},{x0,y,z0},mat,t)end
   down(x,z,x+16,z+f,H,'lgMarble',.82);down(x,z+16-f,x+16,z+16,H,'lgMarble',.82)
   down(x,z+f,x+f,z+16-f,H,'lgMarble',.82);down(x+16-f,z+f,x+16,z+16-f,H,'lgMarble',.82)
   local a0,a1,b0,b1=x+f,x+16-f,z+f,z+16-f
   local c0,c1,d0,d1=x+g,x+16-g,z+g,z+16-g
   Ecl.quad({a0,H,b0},{a1,H,b0},{c1,H+dp,d0},{c0,H+dp,d0},'lgMarble',.70)
   Ecl.quad({a1,H,b1},{a0,H,b1},{c0,H+dp,d1},{c1,H+dp,d1},'lgMarble',.76)
   Ecl.quad({a0,H,b1},{a0,H,b0},{c0,H+dp,d0},{c0,H+dp,d1},'lgMarble',.72)
   Ecl.quad({a1,H,b0},{a1,H,b1},{c1,H+dp,d1},{c1,H+dp,d0},'lgMarble',.74)
   down(c0,d0,c1,d1,H+dp,'lgCrimson',.85)
   Ecl.decor(function()
    local cx,cz=x+8,z+8
    for i=0,7 do
     local q0,q1=i/8*pi*2,(i+1)/8*pi*2
     local r=i%2==0 and 2.6 or 2.0
     Ecl.quad({cx,H+dp-.06,cz},{cx+cos(q1)*2.3,H+dp-.06,cz+sin(q1)*2.3},{cx+cos(q0)*r,H+dp-.06,cz+sin(q0)*r},{cx,H+dp-.06,cz},'lgGold',1)
    end
   end)
  end
 end end
 -- the dome over the concourse
 local n=32
 for i=0,n-1 do
  local a0,a1=i/n*pi*2,(i+1)/n*pi*2
  local function sq(a)local cs,sn=cos(a),sin(a);local k=(DR+10)/max(abs(cs),abs(sn));return DX+cs*k,DZ+sn*k end
  local o0x,o0z=sq(a0);local o1x,o1z=sq(a1)
  Ecl.quad({DX+cos(a1)*DR,H,DZ+sin(a1)*DR},{DX+cos(a0)*DR,H,DZ+sin(a0)*DR},{o0x,H,o0z},{o1x,H,o1z},'lgMarble',.82)
  Ecl.quad({DX+cos(a0)*DR,H,DZ+sin(a0)*DR},{DX+cos(a1)*DR,H,DZ+sin(a1)*DR},{DX+cos(a1)*DR,H+8,DZ+sin(a1)*DR},{DX+cos(a0)*DR,H+8,DZ+sin(a0)*DR},'lgMarble',.86)
 end
 local oy=dome(C,Ecl,DX,DZ,DR,H+8,18,n,6)
 fx.beams[#fx.beams+1]={x=DX,y=oy,z=DZ,tx=DX,ty=0,tz=DZ,r0=5,r1=24,col={1,.95,.8},a=.07}
 chandelier(C,Ecl,fx,DX,58,DZ,1.25,oy,12)
 chandelier(C,Ecl,fx,48,62,152,.9,H+3.2,8)
 chandelier(C,Ecl,fx,208,62,152,.9,H+3.2,8)
 chandelier(C,Ecl,fx,80,64,30,.75,H+3.2,8)
 fx.motes={x=DX,z=DZ,r=30,y0=4,y1=H,n=24,col={1,.92,.7}}
end

-- ====================================================================
-- TEST201: THE LEAGUE'S UPSTAIRS
-- gen1recomp's union floor (POKECENTER_2F) when you come up from the
-- Plateau's lobby: the lobby's marble, verde and gold one floor higher.
-- A long marble bar with the two receptionists behind it, the doors to
-- the Union Room and the Cable Club under gilded pediments, crimson
-- banners and torches between fluted pilasters, a crimson runner in front
-- of the bar with the League's crest, cypresses in the four corners, the
-- stairs down beside a column, and a coffered ceiling with a chandelier.
-- Cells (14 x 8): the back wall and its doors on row 0, the walk behind
-- the bar on row 1, the bar on row 2, the hall below.
-- ====================================================================
function M.upstairs(C)
 local K,lib=C.K,C.lib
 local W,D=C.W,C.D
 local F=V.require('LeagueFlora')
 C.H=72;C.ambient=.88;C.maxLight=1.45
 local H=C.H
 local fx=C.fx
 fx.beams,fx.motes={},nil
 fx.ambience={lobby=.45}
 local solid=function(cx,cy)return C.is(cx,cy,'W')or cx<0 or cx>=C.cw or cy<0 or cy>=C.ch end
 C.addLight(112,40,24,70,.30)
 C.addLight(112,40,96,80,.28)
 ---------------------------------------------------------------- floor
 local Ef=C.part('floor',nil,true)
 local ao=C.aoField(function(cx,cy)return solid(cx,cy)end,14)
 for cy=0,C.ch-1 do for cx=0,C.cw-1 do
  if not C.is(cx,cy,'W^')then C.floorRect(Ef,cx*CS,cy*CS,cx*CS+CS,cy*CS+CS,0,'lgMarble',1,ao,8)end
 end end
 Ef.decor(function()
  for cy=1,C.ch-1 do for cx=1,C.cw-1 do
   local ok=true
   for _,d in ipairs({{-1,-1},{0,-1},{-1,0},{0,0}})do if C.is(cx+d[1],cy+d[2],'W^C')then ok=false end end
   if ok then
    local px,pz=cx*CS,cy*CS;local c=2.2
    Ef.quad({px-c,.04,pz},{px,.04,pz-c},{px+c,.04,pz},{px,.04,pz+c},'lgVerde',1)
   end
  end end
  -- the crimson runner along the bar, from the stairs to the far end
  Ef.box(8,0,50,224,.18,62,'lgCarpet',1,{bottom=true})
  Ef.box(8,0,50,224,.24,51.2,'lgGold',1,{bottom=true})
  Ef.box(8,0,60.8,224,.24,62,'lgGold',1,{bottom=true})
  -- and the League's crest in the middle of the hall
  local cx,cz=112,92
  lib.ringH(Ef,cx,cz,.06,20,21.6,48,'lgVerde',1)
  lib.ringH(Ef,cx,cz,.07,18.8,20,48,'lgGold',1)
  lib.starH(Ef,cx,cz,.08,17,6.5,8,'lgGold','lgCrimson',1.02)
  lib.ringH(Ef,cx,cz,.09,5.2,6,32,'lgGold',1)
  lib.fanH(Ef,cx,cz,.10,5.2,16,'lgCrimson',1.05,pi,pi*2)
  lib.fanH(Ef,cx,cz,.10,5.2,16,'lgMarble',1.1,0,pi)
  lib.fanH(Ef,cx,cz,.12,1.5,16,'lgVerde',1)
 end)
 ---------------------------------------------------------------- the bar
 local Ec=C.part('counter',nil,true)
 do
  local L=K.model(Ec,0,0,0,0,1)
  local z0,z1=33,46
  L.box(0,0,z0,208,13,z1,'lgMarble',1,{bottom=true})
  L.box(-.4,13,z0-.6,208.4,14.4,z1+.6,'lgGold',1,{bottom=true})
  L.box(0,0,z1,208,3,z1+.8,'lgVerde',1,{bottom=true})
  L.decor(function()
   local k=3
   while k+10<=205 do
    -- the two gates (cells 6-7, 10-11) wear a gilded lattice
    local gate=(k>=96 and k<128)or(k>=160 and k<192)
    L.box(k,4.5,z1,k+10,11,z1+.35,'lgGold',1,{})
    L.box(k+.8,5.2,z1+.35,k+9.2,10.3,z1+.55,gate and'lgVerde'or'lgCrimson',1,{})
    if gate then
     for q=0,2 do L.box(k+2+q*3,5.6,z1+.55,k+2.6+q*3,9.9,z1+.75,'lgGold',1,{})end
    end
    k=k+12
   end
  end)
  -- bells and a little lamp on the bar, before each receptionist
  for _,bx in ipairs({120,184})do
   L.frustum(bx,14.4,40,1.1,15.8,.2,10,'lgGold',true)
  end
  local Ll=K.model(Ec,40,14.4,39,0,1)
  Ll.frustum(0,0,0,2.2,1,1.4,10,'lgGold')
  Ll.frustum(0,1,0,.4,9,.4,8,'lgGold')
  Ll.frustum(0,9,0,4.4,14,2.2,12,'lgCrystal',true)
  fx.glows[#fx.glows+1]={x=40,y=25,z=39,r=10,col='gold',a=.18}
  -- the round end of the bar by the stairs
  L.box(196,0,z0,208,13,z1,'lgMarble',1,{bottom=true})
 end
 ---------------------------------------------------------------- the stairs down
 do
  local IK=V.require('InteriorKit')
  IK.stairsDown(C,Ec,209,223,17,32,{tread='lgMarble',riser='lgVerde',rail='lgGold',handrail='lgGold',wall='lgMarble',railX=209.5,n=4,depth=16})
  -- the column beside them (cell 12, rows 0-1)
  local Lp=K.model(Ec,200,0,16,0,1)
  Lp.box(-7,0,-7,7,6.4,7,'lgVerde',1,{bottom=true})
  Lp.box(-6.4,6.4,-6.4,6.4,7.2,6.4,'lgGold',1,{})
  Lp.frustum(0,7.2,0,5,H-9,4.6,14,'lgFluteD',true)
  Lp.box(-6,H-9,-6,6,H-7.4,6,'lgGold',1,{})
  Lp.box(-7,H-7.4,-7,7,H,7,'lgMarble',1,{})
 end
 ---------------------------------------------------------------- planters
 local function planter(x,z,w,d,tall)
  local L=K.model(Ec,x,0,z,0,1)
  L.box(-w/2,0,-d/2,w/2,8,d/2,'lgMarble',1,{bottom=true})
  L.box(-w/2-.6,8,-d/2-.6,w/2+.6,9.2,d/2+.6,'lgGold',1,{})
  L.box(-w/2,0,-d/2,w/2,2,d/2,'lgVerde',1,{bottom=true})
  L.quad({-w/2+1,8.6,d/2-1},{w/2-1,8.6,d/2-1},{w/2-1,8.6,-d/2+1},{-w/2+1,8.6,-d/2+1},'lgBloom',1)
  for i,t in ipairs(tall)do F.cypress(Ec,x+t[1],8.6,z+t[2],t[3],i*7+x,0,1)end
 end
 planter(16,112,28,28,{{-6,-4,34},{6,4,40}})
 planter(208,112,28,28,{{-6,4,40},{6,-4,34}})
 ---------------------------------------------------------------- walls
 local DH=38
 local function hall(L,len,run)
  local back=run.o=='S'and run.c==16
  local o={DH=DH,step=32,first=8}
  local pil=classicWall(C,L,len,run,H,o)
  for i=1,#pil-1 do
   local a,b=pil[i],pil[i+1]
   local m=(a+b)/2
   if b-a>20 and not inHole(run.holes,a+3)and not inHole(run.holes,b-3)and not inHole(run.holes,m)then
    L.box(a+5,20,0,b-5,H-20,.4,'lgGold',1,{})
    L.box(a+6,21,.4,b-6,H-21,.6,'lgCrimson',1,{})
    L.decor(function()
     lib.ringXY(L,m,H*.52,.65,4.8,5.6,24,'lgGold',1)
     lib.starXY(L,m,H*.52,.7,4.1,1.7,5,'lgGold',1.05)
    end)
    if b-a>28 then
     local wx,wy,wz=run.toWorld(a+4,33,4)
     L.box(a+2.6,30,1.0,a+5.4,32,4.5,'lgGold',1,{})
     L.frustum(a+4,32,4,1.2,35,2.2,8,'lgGold')
     fx.fires[#fx.fires+1]={x=wx,y=35.3,z=wz,s=.5,phase=wx*.1+wz*.1}
    end
   end
  end
  if back then
   -- the two doors in the back wall: dark crimson passages under pediments
   for i,h in ipairs(run.holes)do
    local a,b=h[1],h[2]
    local saveFlat=C.flat;C.flat=true
    local T=DH+6
    L.quad({a,0,-6},{b,0,-6},{b,T,-6},{a,T,-6},'lgCrimson',1.25)
    C.flat=saveFlat
    L.quad({a,0,0},{a,0,-6},{a,T,-6},{a,T,0},'lgMarble',.75)
    L.quad({b,0,-6},{b,0,0},{b,T,0},{b,T,-6},'lgMarble',.72)
    L.quad({a,T,0},{b,T,0},{b,T,-6},{a,T,-6},'lgMarble',.6)
    for _,sx in ipairs({a-3.6,b+3.6})do
     L.box(sx-3,0,0,sx+3,6,2.4,'lgVerde',1,{bottom=true})
     L.frustum(sx,6,1.2,2,DH+2,1.8,10,'lgMarble',true)
     L.box(sx-2.7,DH+2,0,sx+2.7,DH+3.3,2.4,'lgGold',1,{})
    end
    local cx=(a+b)/2
    L.box(a-7,DH+3.3,-.5,b+7,DH+8,2.8,'lgMarble',1,{})
    L.box(a-7.5,DH+8,-1,b+7.5,DH+9.2,3.3,'lgGold',1,{})
    L.quad({a-7,DH+9.2,2.6},{b+7,DH+9.2,2.6},{cx,DH+15,2.6},{cx,DH+15,2.6},'lgMarble',.95)
    L.decor(function()C.K.inscription(L,i==1 and'UNION ROOM'or'CABLE CLUB',cx,DH+4.4,2.8,.7,'lgGold',b-a+12)end)
    local wx,wy,wz=run.toWorld(cx,DH*.5,-3)
    fx.glows[#fx.glows+1]={x=wx,y=wy,z=wz,r=16,col='red',a=.20}
   end
  end
 end
 C.walls(function(cx,cy)return C.is(cx,cy,'WE')end,hall,{outside=true,door=function(cx,cy)return C.is(cx,cy,'E')end})
 -- the roof over the wall cells, for a camera above
 do
  local Ek=C.part('caps',{above=H})
  for cy=0,C.ch-1 do for cx=0,C.cw-1 do
   if C.is(cx,cy,'WE')then
    local x,z=cx*CS,cy*CS
    Ek.quad({x,H+.9,z+CS},{x+CS,H+.9,z+CS},{x+CS,H+.9,z},{x,H+.9,z},'lgMarble',.9)
   end
  end end
 end
 ---------------------------------------------------------------- ceiling
 local Ecl=C.part('ceiling',{below=H})
 for z=0,D-16,16 do for x=0,W-16,16 do
  if not C.is(floor(x/16),floor(z/16),'WE')then
   local f,g,dp=1.2,2.6,3.0
   local function down(x0,z0,x1,z1,y,mat,t)Ecl.quad({x0,y,z1},{x1,y,z1},{x1,y,z0},{x0,y,z0},mat,t)end
   down(x,z,x+16,z+f,H,'lgMarble',.82);down(x,z+16-f,x+16,z+16,H,'lgMarble',.82)
   down(x,z+f,x+f,z+16-f,H,'lgMarble',.82);down(x+16-f,z+f,x+16,z+16-f,H,'lgMarble',.82)
   local a0,a1,b0,b1=x+f,x+16-f,z+f,z+16-f
   local c0,c1,d0,d1=x+g,x+16-g,z+g,z+16-g
   Ecl.quad({a0,H,b0},{a1,H,b0},{c1,H+dp,d0},{c0,H+dp,d0},'lgMarble',.70)
   Ecl.quad({a1,H,b1},{a0,H,b1},{c0,H+dp,d1},{c1,H+dp,d1},'lgMarble',.76)
   Ecl.quad({a0,H,b1},{a0,H,b0},{c0,H+dp,d0},{c0,H+dp,d1},'lgMarble',.72)
   Ecl.quad({a1,H,b0},{a1,H,b1},{c1,H+dp,d1},{c1,H+dp,d0},'lgMarble',.74)
   down(c0,d0,c1,d1,H+dp,'lgCrimson',.85)
  end
 end end
 chandelier(C,Ecl,fx,112,44,92,.85,H+3,8)
 chandelier(C,Ecl,fx,48,48,80,.6,H+3,6)
 chandelier(C,Ecl,fx,176,48,80,.6,H+3,6)
end

return M
