-- TEST172: the Elite Four's rooms (see LeagueRooms for the frame).
--   lorelei  an ice palace under the aurora
--   bruno    a mountain dojo of timber and granite
--   agatha   a gothic crypt in violet glass and candlelight
--   lance    a dragon temple on causeways over a lava abyss
local V=...
local M={}
local pi,cos,sin,floor,min,max,abs,sqrt=math.pi,math.cos,math.sin,math.floor,math.min,math.max,math.abs,math.sqrt
local function R()return V.require('LeagueRooms')end
local function rh(a,b,s)local v=sin(a*12.9898+b*78.233+s*37.719)*43758.5453;return v-floor(v)end
local CS=16

------------------------------------------------------------------ shared
-- A wall face with rectangular holes cut from the bottom: holes={{x0,x1,h}}
local function faceWithHoles(L,len,y0,y1,holes,mat,t,z,step)
 z=z or 0;step=step or 16
 local cuts={}
 for _,h in ipairs(holes or{})do cuts[#cuts+1]={h[1],h[2],h[3]or y1}end
 table.sort(cuts,function(a,b)return a[1]<b[1]end)
 local xs={0}
 for _,c in ipairs(cuts)do xs[#xs+1]=c[1];xs[#xs+1]=c[2]end
 xs[#xs+1]=len
 for i=1,#xs-1 do
  local a,b=xs[i],xs[i+1]
  if b-a>.01 then
   local bottom=y0
   for _,c in ipairs(cuts)do if a>=c[1]-.01 and b<=c[2]+.01 then bottom=max(bottom,c[3])end end
   if bottom<y1 then
    local nx=max(1,floor((b-a)/step+.5));local ny=max(1,floor((y1-bottom)/step+.5))
    for jy=0,ny-1 do for ix=0,nx-1 do
     local xa,xb=a+(b-a)*ix/nx,a+(b-a)*(ix+1)/nx
     local ya,yb=bottom+(y1-bottom)*jy/ny,bottom+(y1-bottom)*(jy+1)/ny
     L.quad({xa,ya,z},{xb,ya,z},{xb,yb,z},{xa,yb,z},mat,t)
    end end
   end
  end
 end
end
M.faceWithHoles=faceWithHoles
local function inHole(holes,x)
 for _,h in ipairs(holes or{})do if x>h[1]-.01 and x<h[2]+.01 then return h end end
 return nil
end

-- ====================================================================
-- LORELEI: AN ICE PALACE UNDER THE AURORA
-- The walk is a polished-ice causeway over a frozen lake: up to a dais set
-- with a silver snowflake, ringed by crystal spires that glow from within.
-- Glacier cliffs close the lake in; the north wall is the palace front,
-- its portal sealed by a sheet of ice until Lorelei falls. Blue fire
-- burns in silver braziers by the entrance, an ice obelisk stands beside
-- the causeway, and over everything the aurora and the falling snow.
-- ====================================================================
local LAKE=-4.5
function M.lorelei(C)
 local K,lib=C.K,C.lib
 local W,D=C.W,C.D
 C.H=124;C.ambient=.70;C.maxLight=1.40
 C.lightY=function(y)return 1-.42*max(0,min(1,(y-30)/100))end
 local fx=C.fx
 fx.fires,fx.blueFire,fx.snow,fx.aurora,fx.sparkles,fx.mist,fx.pools={},{},nil,{},{},{},{}
 fx.ambience={ice=.75}
 -- light: blue fires by the entrance, the crystal spires round the dais
 for _,b in ipairs({{48,176},{112,176}})do C.addLight(b[1],28,b[2],86,.50)end
 for _,s in ipairs({{24,24},{136,24},{24,104},{136,104}})do C.addLight(s[1],30,s[2],64,.36)end
 C.addLight(80,40,64,96,.24)
 C.addLight(56,40,144,50,.28)
 C.addLight(80,40,10,70,.22)

 ---------------------------------------------------------------- the sky
 C.sky(80,96,620,2,-60)

 ---------------------------------------------------------------- the lake
 local Ef=C.part('floor',nil,true)
 local solid=function(cx,cy)return C.is(cx,cy,'WD')or cx<0 or cy<0 or cx>=C.cw or cy>=C.ch end
 local ao=C.aoField(solid,18)
 for cy=0,C.ch-1 do for cx=0,C.cw-1 do
  local ch=C.at(cx,cy)
  if ch~='W'and ch~='D'and ch~='.'then
   C.floorRect(Ef,cx*CS,cy*CS,cx*CS+CS,cy*CS+CS,LAKE,'lgIce',.82,ao,8)
  end
 end end
 -- floes: thin snowy slabs frozen into the lake
 local Eg=C.part('lake',nil,true)
 local function floe(x,z,r,seed)
  local n=9;local pts={}
  for i=0,n-1 do local a=i/n*pi*2+rh(seed,i,3)*.5;local k=.55+.6*rh(seed,i,5);pts[i]={x+cos(a)*r*k*1.4,z+sin(a)*r*k}end
  local y=LAKE+.25
  for i=0,n-1 do local j=(i+1)%n
   Eg.quad({x,y,z},{pts[i][1],y,pts[i][2]},{pts[j][1],y,pts[j][2]},{x,y,z},'lgSnow',.82)
   Eg.quad({pts[i][1],y,pts[i][2]},{pts[i][1],LAKE,pts[i][2]},{pts[j][1],LAKE,pts[j][2]},{pts[j][1],y,pts[j][2]},'lgIce',.7)
  end
 end
 for k,f in ipairs({{12,40,7},{150,30,6},{14,150,8},{146,140,7},{30,124,5},{132,120,6},{10,88,5},{150,80,6},{120,160,5},{36,186,4},{128,186,5}})do
  floe(f[1],f[2],f[3],k*7)
 end
 -- snow drifts along the foot of the cliffs
 local F=V.require('LeagueFlora')
 for k=0,22 do
  local side=k%3
  local x,z
  if side==0 then x,z=3+rh(k,1,3)*6,24+k/22*160
  elseif side==1 then x,z=W-3-rh(k,1,3)*6,24+k/22*160
  else x,z=8+k/22*144,D-3-rh(k,2,5)*5 end
  if not(side==2 and x>56 and x<104)then
   F.cluster(Eg,'lgSnow',x,LAKE+1.0,z,6+rh(k,3,7)*6,2.4+rh(k,4,1)*2,5+rh(k,5,9)*5,7,3,k*13,{y0=LAKE,y1=LAKE+5,lump=.2})
  end
 end

 ---------------------------------------------------------------- causeway
 -- the walk: polished ice on a raised causeway, silver at its lip
 local Ew=C.part('walk',nil,true)
 local walk=function(cx,cy)return C.at(cx,cy)=='.'end
 local wao=C.aoField(function(cx,cy)return solid(cx,cy)end,14)
 for cy=0,C.ch-1 do for cx=0,C.cw-1 do
  if walk(cx,cy)then
   local x0,z0=cx*CS,cy*CS
   C.floorRect(Ew,x0,z0,x0+CS,z0+CS,0,'lgIce',1.0,wao,8)
   -- the causeway's flank down to the lake, and its silver lip
   local function flank(nx,nz,a,b)
    if not walk(cx+nx,cy+nz)and not solid(cx+nx,cy+nz)then
     Ew.quad(b,a,{a[1],LAKE,a[3]},{b[1],LAKE,b[3]},'lgIce',.72)
     local ox,oz=nx*.6,nz*.6
     Ew.box(min(a[1],b[1]+ox)-(nx~=0 and 0 or 0),-.6,min(a[3],b[3]+oz),max(a[1],b[1]+ox),.35,max(a[3],b[3]+oz),'lgSilver',1,{bottom=true})
    end
   end
   flank(0,-1,{x0,0,z0},{x0+CS,0,z0})
   flank(0,1,{x0+CS,0,z0+CS},{x0,0,z0+CS})
   flank(-1,0,{x0,0,z0+CS},{x0,0,z0})
   flank(1,0,{x0+CS,0,z0},{x0+CS,0,z0+CS})
  end
 end end
 -- inlay: silver lines on the cell joints of the walk, a snowflake every
 -- other cell up the causeway, the great snowflake on the dais
 Ew.decor(function()
  for cy=0,C.ch-1 do for cx=0,C.cw-1 do
   if walk(cx,cy)then
    local x0,z0=cx*CS,cy*CS
    if walk(cx+1,cy)then lib.stripH(Ew,x0+CS,z0+1.2,x0+CS,z0+CS-1.2,.06,.45,'lgSilver',1)end
    if walk(cx,cy+1)then lib.stripH(Ew,x0+1.2,z0+CS,x0+CS-1.2,z0+CS,.06,.45,'lgSilver',1)end
   end
  end end
  for cy=6,11 do lib.snowflake(Ew,80,cy*CS+8,.08,5.6,'lgSilver','lgCrystal',cy*.3)end
  lib.snowflake(Ew,80,16+8,.08,5.6,'lgSilver','lgCrystal',.2)
  -- the dais: a ring of silver round a crystal-cored snowflake
  local cx,cz=80,64
  lib.ringH(Ew,cx,cz,.07,27.5,29,48,'lgSilver',1)
  lib.ringH(Ew,cx,cz,.07,24.4,25.2,48,'lgSilver',1)
  for k=0,11 do
   local a=k/12*pi*2
   lib.fanH(Ew,cx+cos(a)*26.8,cz+sin(a)*26.8,.09,1.2,6,'lgCrystal',1.1)
  end
  lib.snowflake(Ew,cx,cz,.10,22,'lgSilver','lgCrystal',pi/6)
  lib.fanH(Ew,cx,cz,.12,4.2,6,'lgCrystal',1.15,pi/6)
  lib.ringH(Ew,cx,cz,.13,4.2,5.0,6,'lgSilver',1,pi/6,pi/6+pi*2)
 end)

 ---------------------------------------------------------------- balustrade
 -- a low ice curb with crystal-capped posts along the lake side of the walk
 local Eb=C.part('rail',nil,true)
 local Lb=K.model(Eb,0,0,0,0,1)
 local posts={}
 for cy=0,C.ch-1 do for cx=0,C.cw-1 do
  if walk(cx,cy)then
   local x0,z0=cx*CS,cy*CS
   for _,d in ipairs({{-1,0},{1,0},{0,1}})do
    local nx,nz=d[1],d[2]
    if not walk(cx+nx,cy+nz)and not solid(cx+nx,cy+nz)and not(cy==C.ch-1 and nz==1)then
     local ax,az,bx,bz
     if nx==-1 then ax,az,bx,bz=x0-2.4,z0,x0-.6,z0+CS
     elseif nx==1 then ax,az,bx,bz=x0+CS+.6,z0,x0+CS+2.4,z0+CS
     else ax,az,bx,bz=x0,z0+CS+.6,x0+CS,z0+CS+2.4 end
     Lb.box(ax,LAKE,az,bx,2.2,bz,'lgIce',.95,{bottom=true})
     Lb.box(ax-.15,2.2,az-.15,bx+.15,2.7,bz+.15,'lgSilver',1,{bottom=true})
     posts[#posts+1]={(ax+bx)/2+(nx==0 and -(bx-ax)/2+1.2 or 0),(az+bz)/2+(nz==0 and -(bz-az)/2+1.2 or 0)}
    end
   end
  end
 end end
 for i,p in ipairs(posts)do
  Lb.box(p[1]-1.3,LAKE,p[2]-1.3,p[1]+1.3,4.6,p[2]+1.3,'lgIce',1,{bottom=true})
  Lb.box(p[1]-1.6,4.6,p[2]-1.6,p[1]+1.6,5.2,p[2]+1.6,'lgSilver',1,{bottom=true})
  local tip=lib.crystal(Lb,p[1],5.2,p[2],.9,4.2,6,0,0,'lgCrystal',i*.4)
  if i%2==0 then fx.sparkles[#fx.sparkles+1]={x=tip[1],y=tip[2]-.6,z=tip[3],s=.6,phase=i*1.3}end
 end

 ---------------------------------------------------------------- crystal spires
 local Ec=C.part('crystals',nil,true)
 local Lc=K.model(Ec,0,0,0,0,1)
 local function spireCluster(x,z,big,seed)
  local n=big and 5 or 3
  for k=0,n-1 do
   local a=rh(seed,k,3)*pi*2
   local d=k==0 and 0 or (2.5+rh(seed,k,5)*4.5)*(big and 1.2 or 1)
   local px,pz=x+cos(a)*d,z+sin(a)*d
   local h=(k==0 and(big and 74 or 40)or(big and 30 or 18)+rh(seed,k,7)*(big and 34 or 18))
   local r=(k==0 and(big and 4.6 or 3.2)or 1.8+rh(seed,k,9)*1.6)
   local lean=k==0 and .04 or .14+rh(seed,k,11)*.16
   local tip=lib.crystal(Lc,px,LAKE,pz,r,h,6,cos(a)*lean,sin(a)*lean,'lgCrystal',rh(seed,k,13))
   if k<=1 then fx.sparkles[#fx.sparkles+1]={x=tip[1],y=tip[2]-1,z=tip[3],s=big and 1.4 or .9,phase=seed+k}end
  end
  -- a frozen base of ice and snow
  V.require('LeagueFlora').cluster(Ec,'lgSnow',x,LAKE+.6,z,big and 8 or 5.5,2.2,big and 8 or 5.5,8,3,seed,{y0=LAKE,y1=LAKE+3,lump=.25})
 end
 spireCluster(24,24,true,11);spireCluster(136,24,true,23)
 spireCluster(24,104,true,37);spireCluster(136,104,true,41)
 for k,s in ipairs({{24,48},{24,72},{136,48},{136,72},{40,104},{120,104},{40,24},{120,24}})do spireCluster(s[1],s[2],false,60+k*7)end
 -- lesser crystals scattered on the lake
 for k=0,15 do
  local x=6+rh(k,1,1)*148;local z=36+rh(k,2,2)*150
  local cx,cy=floor(x/CS),floor(z/CS)
  local near=false
  for dy=-1,1 do for dx=-1,1 do if walk(cx+dx,cy+dy)then near=true end end end
  if not near and C.at(cx,cy)=='L'then
   lib.crystal(Lc,x,LAKE,z,1.2+rh(k,3,3),8+rh(k,4,4)*12,5,(rh(k,5,5)-.5)*.3,(rh(k,6,6)-.5)*.3,'lgCrystal',k)
  end
 end

 ---------------------------------------------------------------- the obelisk
 do
  local Lo=K.model(Ec,56,LAKE,144,0,1)
  Lo.box(-7.5,0,-15,7.5,3.5,15,'lgIce',.95,{bottom=true})
  Lo.box(-6.8,3.5,-14.2,6.8,4.2,14.2,'lgSilver',1,{bottom=true})
  Lo.box(-6,4.2,-6,6,9,6,'lgIce',1,{bottom=true})
  Lo.box(-6.4,9,-6.4,6.4,9.8,6.4,'lgSilver',1,{bottom=true})
  -- the shaft, tapering, with a crystal heart showing through a slot
  local y0,y1=9.8,62
  Lo.frustum(0,y0,0,5.4,y1,3.4,4,'lgIce',false,pi/4)
  Lo.decor(function()
   for _,s in ipairs({{0,1},{0,-1},{1,0},{-1,0}})do
    local Lf=K.model(Ec,56+s[1]*3.95,LAKE,144+s[2]*3.95,math.atan2(s[1],s[2]),1)
    Lf.quad({-1.1,20,0},{1.1,20,0},{.9,48,0},{-.9,48,0},'lgCrystal',1.1)
   end
  end)
  local tip=lib.crystal(Lo,0,y1,0,3.4*1.02,9,4,0,0,'lgCrystal',pi/4)
  Lo.box(-3.9,y1-.6,-3.9,3.9,y1+.3,3.9,'lgSilver',1,{})
  fx.sparkles[#fx.sparkles+1]={x=56,y=LAKE+y1+7,z=144,s=1.8,phase=2}
  fx.pools[#fx.pools+1]={x=56,y=.2,z=144,r=22,a=.10,col={.45,.75,1}}
 end

 ---------------------------------------------------------------- braziers
 for i,b in ipairs({{48,176},{112,176}})do
  local Lr=K.model(Ec,b[1],LAKE,b[2],0,1)
  Lr.box(-14,0,-14,14,3.5,14,'lgIce',.92,{bottom=true})
  Lr.box(-13,3.5,-13,13,4.3,13,'lgSilver',1,{bottom=true})
  Lr.box(-10,4.3,-10,10,8,10,'lgIce',1,{bottom=true})
  Lr.frustum(0,8,0,4.6,9.4,4.0,12,'lgSilver')
  Lr.frustum(0,9.4,0,3.2,26,2.6,12,'lgIce')
  Lr.frustum(0,15,0,3.0,15.8,3.0,12,'lgSilver')
  Lr.frustum(0,26,0,2.6,27.4,3.6,12,'lgSilver')
  local yc
  do
   local y0,y1=27.4,30.8
   Lr.frustum(0,y0,0,2.8,y1,7.2,12,'lgSilver')
   Lr.frustum(0,y1,0,7.2,y1+.4,7.6,12,'lgSilver')
   Lr.frustum(0,y1+.4,0,7.6,y1-.5,6.0,12,'lgSilver')
   yc=y1-.5
   for k=0,11 do
    local a0,a1=k/12*pi*2,(k+1)/12*pi*2
    Lr.quad({0,yc+.3,0},{0,yc+.3,0},{cos(a1)*6,yc,sin(a1)*6},{cos(a0)*6,yc,sin(a0)*6},'lgCrystal',.9)
   end
  end
  -- crystal fangs round the bowl's rim
  for k=0,5 do
   local a=k/6*pi*2+.3
   lib.crystal(Lr,cos(a)*6.4,30.2,sin(a)*6.4,.7,5,4,cos(a)*.25,sin(a)*.25,'lgCrystal',k)
  end
  for k=0,3 do
   local a=k/4*pi*2+pi/4
   lib.crystal(Lr,cos(a)*11.5,8,sin(a)*11.5,1.5,14+rh(i,k,3)*6,6,cos(a)*.12,sin(a)*.12,'lgCrystal',k*.5)
  end
  fx.fires[#fx.fires+1]={x=b[1],y=LAKE+yc+.3,z=b[2],s=1.35,phase=i*2.1,col='ice'}
  fx.pools[#fx.pools+1]={x=b[1],y=.25,z=b[2]-20,r=34,a=.12,col={.35,.65,1}}
 end

 ---------------------------------------------------------------- walls
 local DH=40   -- the portal's height
 local function glacier(L,len,run)
  -- the glacier: one continuous wall of pressed ice, its columns and
  -- bulges flowing into each other, a ragged crest capped with snow and
  -- hung with icicles
  local c=run.c*.013+(run.o=='E'and 1.7 or run.o=='W'and 3.1 or .4)
  local function top(u)return 116+15*sin(u*.058+c)+9*sin(u*.17+1.3+c)+5*sin(u*.41+c*2)end
  local function zo(u,y)
   return 2.4+2.2*sin(u*.21+sin(y*.035+c)*1.3)+1.4*sin(u*.53+y*.021+c*3)+1.1*sin(y*.085+u*.05+c)
  end
  local entry=run.o=='N'and run.c==D
  local du=6
  local nu=max(1,floor(len/du+.5))
  local rows=9
  for i=0,nu-1 do
   local u0,u1=len*i/nu,len*(i+1)/nu
   local hole=entry and inHole(run.holes,(u0+u1)/2)
   local t0,t1=top(u0),top(u1)
   local y00=hole and 46 or LAKE-1
   for j=0,rows-1 do
    local v0,v1=j/rows,(j+1)/rows
    local function P(u,t,v)local y=y00+(t-y00)*v;return{u,y,zo(u,y)}end
    L.quad(P(u0,t0,v0),P(u1,t1,v0),P(u1,t1,v1),P(u0,t0,v1),'lgIce',.95)
   end
   -- the crest
   local a={u0,t0,zo(u0,t0)};local b={u1,t1,zo(u1,t1)}
   L.quad(a,b,{u1,t1+2.6,-7},{u0,t0+2.6,-7},'lgSnow',1)
   if rh(i,run.c,13)>.35 then
    local um=(u0+u1)/2;local tm=top(um)
    lib.icicle(L,um,tm-.4,zo(um,tm)+.4,.7,5+rh(i,run.c,17)*9,'lgIce',4)
   end
  end
  if entry then
   -- the way in: an ice arch over a dark passage
   for _,h in ipairs(run.holes)do
    local a,b=h[1],h[2]
    local cx=(a+b)/2;local hw=(b-a)/2
    L.quad({a,0,-26},{b,0,-26},{b,46,-26},{a,46,-26},'lgIce',.30)
    L.quad({a,LAKE,0},{a,LAKE,-26},{a,46,-26},{a,46,0},'lgIce',.6)
    L.quad({b,LAKE,-26},{b,LAKE,0},{b,46,0},{b,46,-26},'lgIce',.55)
    L.quad({a,46,0},{b,46,0},{b,46,-26},{a,46,-26},'lgIce',.5)
    L.quad({a,.02,0},{b,.02,0},{b,.02,-26},{a,.02,-26},'lgIce',.6)
    -- the arch ring
    for i=0,11 do
     local a0,a1=i/12*pi,(i+1)/12*pi
     L.quad({cx+cos(a0)*(hw+5),38+sin(a0)*12,2.4},{cx+cos(a1)*(hw+5),38+sin(a1)*12,2.4},{cx+cos(a1)*(hw+1),38+sin(a1)*9,2.4},{cx+cos(a0)*(hw+1),38+sin(a0)*9,2.4},'lgSilver',1)
    end
    for _,sx in ipairs({a-3,b+3})do
     L.box(sx-3,LAKE,0,sx+3,38,4,'lgIce',1,{})
     lib.crystal(L,sx,38,2,2.2,10,6,0,0,'lgCrystal',sx)
    end
   end
  end
 end
 local function palace(L,len,run)
  -- the palace front: ice ashlar, fluted ice pilasters, crystal lancets,
  -- a silver frieze with LORELEI, a crest of crystal spikes, the portal
  local H=C.H
  local holes={}
  for _,h in ipairs(run.holes)do holes[#holes+1]={h[1],h[2],DH+12}end
  faceWithHoles(L,len,LAKE,H,holes,'lgIce',.92,0,16)
  L.box(0,LAKE,0,len,1.2,2.2,'lgSilver',1,{bottom=true})
  local pil={4,24,48,112,136,156}
  for _,px in ipairs(pil)do
   L.box(px-4,LAKE,0,px+4,4,2.8,'lgIce',1,{bottom=true})
   L.box(px-3.4,4,0,px+3.4,H-20,2.0,'lgIce',1.05,{bottom=true})
   L.decor(function()
    for f=-2,2 do L.box(px+f*1.3-.25,6,2.0,px+f*1.3+.25,H-22,2.25,'lgSilver',.9,{})end
   end)
   L.box(px-4.2,H-20,0,px+4.2,H-17,3.0,'lgSilver',1,{})
  end
  -- crystal lancets in the bays
  for _,bay in ipairs({{8,20},{28,44},{116,132},{140,152}})do
   local a,b=bay[1],bay[2]
   local m=(a+b)/2;local hw=(b-a)/2-1
   L.box(a,20,0,b,82,.6,'lgSilver',1,{})
   L.quad({m-hw,22,.62},{m+hw,22,.62},{m+hw,72,.62},{m-hw,72,.62},'lgCrystal',.95)
   L.quad({m-hw,72,.62},{m+hw,72,.62},{m,80,.62},{m,80,.62},'lgCrystal',1)
   L.decor(function()
    L.box(m-.25,22,.62,m+.25,78,.8,'lgSilver',1,{})
    for _,yy in ipairs({34,48,62})do L.box(m-hw,yy,.62,m+hw,yy+.5,.8,'lgSilver',1,{})end
   end)
   fx.sparkles[#fx.sparkles+1]={x=run.a0+m,y=50,z=run.c+1.5,s=1.2,phase=a*.3,soft=true}
  end
  -- the frieze and its name
  L.box(0,H-17,0,len,H-6,1.6,'lgSilver',.95,{bottom=true})
  L.box(0,H-15.6,1.6,len,H-7.4,1.9,'lgObsidian',1,{})
  L.decor(function()
   C.K.inscription(L,'LORELEI',len/2,H-14.8,1.9,1.25,'lgCrystal',40)
  end)
  -- a crest of crystal spikes on the parapet
  L.box(0,H-6,-.5,len,H,2.6,'lgIce',1,{top=false})
  L.box(-1,H,-6,len+1,H+1,2.6,'lgSnow',1,{bottom=true})
  local k=0
  for x=6,len-6,10 do
   k=k+1
   local h=(x>56 and x<104)and 22 or 9+rh(k,3,3)*8
   lib.crystal(L,x,H+1,-1,1.6+h*.06,h,6,0,0,'lgCrystal',k)
  end
  -- the portal: a pointed ice arch in silver, the reveal, the passage
  for _,h in ipairs(run.holes)do
   local a,b=h[1],h[2];local cx=(a+b)/2;local hw=(b-a)/2
   -- the reveal (back to the map's north edge and beyond into the dark)
   local zb=-run.c-22
   L.quad({a,0,zb},{b,0,zb},{b,DH,zb},{a,DH,zb},'lgIce',.25)
   L.quad({a,0,0},{a,0,zb},{a,DH,zb},{a,DH,0},'lgIce',.62)
   L.quad({b,0,zb},{b,0,0},{b,DH,0},{b,DH,zb},'lgIce',.58)
   L.quad({a,.02,0},{b,.02,0},{b,.02,zb},{a,.02,zb},'lgIce',.7)
   -- the arch head: a pointed vault over the opening
   for i=0,7 do
    local u0,u1=i/8,(i+1)/8
    local function P(u)local x=a+(b-a)*u;local y=DH+sin(u*pi)*10;return x,y end
    local x0,y0=P(u0);local x1,y1=P(u1)
    L.quad({x0,y0,0},{x1,y1,0},{x1,y1,zb},{x0,y0,zb},'lgIce',.55)
    L.quad({x0,y0,.05},{x1,y1,.05},{x1,DH+12,.05},{x0,DH+12,.05},'lgIce',.9)
   end
   -- silver archivolt and crystal keystone
   for i=0,11 do
    local u0,u1=i/12,(i+1)/12
    local function P(u,r)local x=a-r+(b-a+2*r)*u;local y=DH+sin(u*pi)*(10+r*.8);return {x,y,1.8}end
    L.quad(P(u0,0),P(u1,0),P(u1,3.2),P(u0,3.2),'lgSilver',1)
   end
   lib.crystal(L,cx,DH+13.5,1.4,2.6,7,4,0,0,'lgCrystal',.785)
   for _,sx in ipairs({a-5,b+5})do
    L.box(sx-3.2,LAKE,0,sx+3.2,DH,3.6,'lgIce',1.05,{})
    L.box(sx-3.6,DH,0,sx+3.6,DH+2,4,'lgSilver',1,{})
    lib.crystal(L,sx,DH+2,2,2.4,12,6,0,0,'lgCrystal',sx)
   end
   -- the great snowflake over the portal
   L.decor(function()
    local fy=DH+34
    lib.ringXY(L,cx,fy,.7,13,14.2,36,'lgSilver',1)
    for kk=0,5 do
     local an=kk*pi/3+pi/2
     local ex,ey=cos(an),sin(an)
     L.quad({cx-ey*.6,fy+ex*.6,.9},{cx+ex*12-ey*.3,fy+ey*12+ex*.3,.9},{cx+ex*12+ey*.3,fy+ey*12-ex*.3,.9},{cx+ey*.6,fy-ex*.6,.9},'lgCrystal',1.1)
     for _,u in ipairs({5,8.5})do
      for _,sg in ipairs({-1,1})do
       local bx,by=cx+ex*u,fy+ey*u
       local an2=an+sg*.75
       L.quad({bx,by,.95},{bx+cos(an2)*3.4,by+sin(an2)*3.4,.95},{bx+cos(an2)*3.4+.2,by+sin(an2)*3.4+.2,.95},{bx+.3,by+.3,.95},'lgSilver',1.05)
      end
     end
    end
    lib.fan(L,cx,fy,1.0,2.4,6,'lgCrystal',1.2,0)
   end)
   -- the seal: a frosted sheet of ice across the portal while it is shut
   local Es=C.part('seal',{door=true})
   local Ls=K.model(Es,run.a0,0,run.c,0,1)
   for i=0,7 do
    local u0,u1=i/8,(i+1)/8
    local x0,x1=a+(b-a)*u0,a+(b-a)*u1
    local t0,t1=DH+sin(u0*pi)*10,DH+sin(u1*pi)*10
    Ls.quad({x0,0,-6},{x1,0,-6},{x1,t1,-6},{x0,t0,-6},'lgIce',1.05)
   end
   Ls.decor(function()
    for kk=0,5 do
     local an=kk*pi/3+pi/2
     Ls.quad({cx,24,-5.7},{cx+cos(an)*14,24+sin(an)*14,-5.7},{cx+cos(an+.08)*14,24+sin(an+.08)*14,-5.7},{cx,24,-5.7},'lgSnow',1.1)
    end
   end)
   fx.portal={x=run.a0+cx,y=20,z=run.c-6,w=b-a,h=DH}
  end
 end
 C.walls(function(cx,cy)return C.is(cx,cy,'WD')end,function(L,len,run)
  if run.o=='S'and run.c==16 then palace(L,len,run)else glacier(L,len,run)end
 end,{outside=true,shadow=false,door=function(cx,cy)return C.at(cx,cy)=='D'or(cy==C.ch and(cx==4 or cx==5))end})

 ---------------------------------------------------------------- effects
 fx.snow={x0=-30,x1=W+30,z0=-10,z1=D+20,y0=LAKE,y1=150,n=240}
 fx.aurora={
  {x0=-260,z0=-200,x1=420,z1=-300,y=250,h=120,phase=0},
  {x0=-300,z0=40,x1=-180,z1=380,y=230,h=100,phase=2.1},
  {x0=340,z0=-60,x1=420,z1=360,y=240,h=110,phase=4.2},
 }
 for k,m in ipairs({{20,60},{140,60},{20,150},{140,150},{30,100},{130,100}})do
  fx.mist[#fx.mist+1]={x=m[1],y=LAKE+1.5,z=m[2],r=34,phase=k*1.7,col={.70,.85,1},a=.10}
 end
end

-- ====================================================================
-- BRUNO: A MOUNTAIN DOJO
-- Granite walls under a frame of dark timber, crimson banners between the
-- posts and torches on them; the mountain's own rock breaking up through
-- the boards; a crimson sparring ring under a paper-screened lantern that
-- throws a shaft of light; braziers on the rocks, a bronze gong in a
-- timber frame, war drums by the door, a lacquered gate round the exit.
-- ====================================================================
function M.bruno(C)
 local K,lib=C.K,C.lib
 local W,D=C.W,C.D
 local F=V.require('LeagueFlora')
 C.H=100;C.ambient=.70;C.maxLight=1.45
 C.lightY=function(y)return 1-.30*max(0,min(1,(y-40)/60))end
 local fx=C.fx
 fx.embers,fx.beams,fx.motes={}, {}, {}
 fx.ambience={dojo=.8}
 local H=C.H
 local solid=function(cx,cy)return C.is(cx,cy,'WD')or cx<0 or cx>=C.cw or cy<0 or cy>=C.ch end
 local function blocked(cx,cy)return C.at(cx,cy)~='.'end
 ---------------------------------------------------------------- lights
 local braziers={{24,40},{136,40},{40,88},{120,88}}
 for _,b in ipairs(braziers)do C.addLight(b[1],24,b[2],70,.46)end
 C.addLight(80,70,48,90,.30)
 ---------------------------------------------------------------- floor
 local Ef=C.part('floor',nil,true)
 local ao=C.aoField(function(cx,cy)return solid(cx,cy)end,16)
 for cy=0,C.ch-1 do for cx=0,C.cw-1 do
  if not C.is(cx,cy,'W')then
   C.floorRect(Ef,cx*CS,cy*CS,cx*CS+CS,cy*CS+CS,0,'lgWood',1,ao,8)
  end
 end end
 -- the sparring ring: crimson, bordered in gold, a gold sun at its heart
 Ef.decor(function()
  local cx,cz=80,48
  lib.ringH(Ef,cx,cz,.05,30,34,48,'lgCrimson',1)
  lib.ringH(Ef,cx,cz,.07,33.2,34.2,48,'lgGold',1)
  lib.ringH(Ef,cx,cz,.07,29.6,30.4,48,'lgGold',1)
  lib.ringH(Ef,cx,cz,.06,8.5,10,32,'lgCrimson',1)
  lib.fanH(Ef,cx,cz,.06,8.5,32,'lgGold',.95)
  for k=0,11 do
   local a=k/12*pi*2
   local w=.11
   Ef.quad({cx+cos(a-w)*11,.06,cz+sin(a-w)*11},{cx+cos(a)*17,.06,cz+sin(a)*17},{cx+cos(a+w)*11,.06,cz+sin(a+w)*11},{cx+cos(a-w)*11,.06,cz+sin(a-w)*11},'lgGold',1)
  end
  -- the starting lines
  lib.stripH(Ef,cx-12,cz-4,cx-12,cz+4,.07,1.4,'lgGold',1)
  lib.stripH(Ef,cx+12,cz-4,cx+12,cz+4,.07,1.4,'lgGold',1)
  -- a crimson runner from the door in the south to the ring
  Ef.box(70,0,82,90,.18,D,'lgCarpet',1,{bottom=true})
  Ef.box(70,0,82,71.2,.24,D,'lgGold',1,{bottom=true})
  Ef.box(88.8,0,82,90,.24,D,'lgGold',1,{bottom=true})
 end)
 ---------------------------------------------------------------- the rock
 local Er=C.part('rock',nil,true)
 local seen={}
 for cy=0,C.ch-1 do for cx=0,C.cw-1 do
  if C.at(cx,cy)=='B'then
   local x,z=cx*CS+8,cy*CS+8
   local seed=cx*31+cy*17
   -- a big rounded mass with a smaller one leaning on it; rock under the
   -- boards: the floor is broken round it
   local h=9+rh(seed,1,3)*16
   F.cluster(Er,'lgRock',x+(rh(seed,2,5)-.5)*3,h*.42,z+(rh(seed,3,7)-.5)*3,8.6,h*.62,8.4,9,5,seed,{y0=-2,y1=h,lump=.28})
   if rh(seed,4,9)>.4 then
    local a=rh(seed,5,11)*pi*2
    F.cluster(Er,'lgRock',x+cos(a)*5,3.2,z+sin(a)*5,4.6,3.8,4.2,7,4,seed+3,{y0=-1,y1=7,lump=.3})
   end
   -- splintered boards round the foot
   for k=0,2 do
    local a=rh(seed,k,13)*pi*2
    local bx,bz=x+cos(a)*9,z+sin(a)*9
    Er.quad({bx-.9,.02,bz-2.4},{bx+.9,.02,bz-2.4},{bx+.9,1.6,bz+1.2},{bx-.9,1.6,bz+1.2},'lgWood',.8)
   end
  end
 end end
 ---------------------------------------------------------------- braziers
 for i,b in ipairs(braziers)do
  local Lb=K.model(Er,b[1],0,b[2],i*.7,1)
  -- an iron tripod on a slab of granite set into the rock
  Lb.box(-4.5,0,-4.5,4.5,9,4.5,'lgGranite',1,{bottom=true})
  for k=0,2 do
   local a=k/3*pi*2
   F.limb(Er,'lgObsidian',{b[1]+cos(a)*4.5,9,b[2]+sin(a)*4.5},{b[1]+cos(a)*1.6,19,b[2]+sin(a)*1.6},.45,.35,4)
  end
  Lb.frustum(0,18,0,2.2,22.5,5.4,10,'lgObsidian')
  Lb.frustum(0,22.5,0,5.4,23,5.8,10,'lgBronze')
  for k=0,9 do
   local a0,a1=k/10*pi*2,(k+1)/10*pi*2
   Lb.quad({0,22.6,0},{0,22.6,0},{cos(a1)*5,22.2,sin(a1)*5},{cos(a0)*5,22.2,sin(a0)*5},'lgLava',.9)
  end
  fx.fires[#fx.fires+1]={x=b[1],y=22.6,z=b[2],s=1.25,phase=i*1.9}
  fx.embers[#fx.embers+1]={x=b[1],y=24,z=b[2],r=4,n=10}
 end
 ---------------------------------------------------------------- the gong
 do
  local x0,x1,z0,z1=48,64,144,176
  local cx,cz=(x0+x1)/2,(z0+z1)/2
  local Lg=K.model(Er,cx,0,cz,0,1)
  Lg.box(-7.5,0,-15.5,7.5,4,15.5,'lgGranite',1,{bottom=true})
  Lg.box(-6.8,4,-14.8,6.8,4.8,14.8,'lgCrimson',1,{bottom=true})
  for _,z in ipairs({-12.5,12.5})do
   Lg.box(-2,4.8,z-2,2,46,z+2,'lgWood',1,{bottom=true})
   Lg.box(-2.6,4.8,z-2.6,2.6,8,z+2.6,'lgBronze',1,{bottom=true})
  end
  Lg.box(-2.6,40,-17,2.6,44,17,'lgWood',1,{})
  Lg.box(-3,46,-19.5,3,48.5,19.5,'lgCrimson',1,{})
  Lg.box(-3.1,48.5,-20,3.1,49.2,20,'lgGold',1,{})
  -- the gong: a bronze disc with a raised boss, facing the walk (east)
  local gy=24
  local Lgd=K.model(Er,cx+.6,0,cz,pi/2,1)
  lib.fan(Lgd,0,gy,1.2,10.5,28,'lgBronze',1.05,0)
  lib.fan(Lgd,0,gy,-0.2,10.5,28,'lgBronze',.8,0)
  Lgd.decor(function()
   lib.ringXY(Lgd,0,gy,1.25,9.4,10.5,28,'lgGold',1)
   lib.ringXY(Lgd,0,gy,1.3,5.2,5.8,24,'lgGold',1)
   lib.fan(Lgd,0,gy,1.9,3.2,16,'lgGold',1.1,0)
  end)
  for k=0,27 do
   local a0,a1=k/28*pi*2,(k+1)/28*pi*2
   Lgd.quad({cos(a0)*10.5,gy+sin(a0)*10.5,1.2},{cos(a1)*10.5,gy+sin(a1)*10.5,1.2},{cos(a1)*10.5,gy+sin(a1)*10.5,-.2},{cos(a0)*10.5,gy+sin(a0)*10.5,-.2},'lgBronze',.9)
  end
  -- cords from the beam
  for _,z in ipairs({-6,6})do Lg.box(-.2,gy+8,z-.2,.2,40,z+.2,'lgCrimson',1,{})end
  -- the mallet, resting across the base
  F.limb(Er,'lgWood',{cx+4,5.2,cz-10},{cx+4,5.6,cz+6},.35,.35,5)
  F.cluster(Er,'lgCarpet',cx+4,5.6,cz+7,1.6,1.6,1.8,6,3,9,{y0=4,y1=7})
  fx.glows[#fx.glows+1]={x=cx+2,y=gy,z=cz,r=16,col='gold',a=.10}
 end
 ---------------------------------------------------------------- drums
 for i,d in ipairs({{16,184},{144,184}})do
  local Ld=K.model(Er,d[1],0,d[2],0,1)
  -- a heavy stand of timber, the drum on its side facing the walk
  Ld.box(-13,0,-6,-10,12,6,'lgWood',1,{bottom=true})
  Ld.box(10,0,-6,13,12,6,'lgWood',1,{bottom=true})
  Ld.box(-13,10,-6.5,13,12.5,-4,'lgWood',1,{})
  Ld.box(-13,10,4,13,12.5,6.5,'lgWood',1,{})
  local Lx=K.model(Er,d[1],20,d[2],0,1)
  local yaw=0
  -- barrel along x: rings of staves
  local n=16;local prof={{-10,8.2},{-7,9.6},{-3,10.4},{3,10.4},{7,9.6},{10,8.2}}
  for k=1,#prof-1 do
   local x0,r0,x1,r1=prof[k][1],prof[k][2],prof[k+1][1],prof[k+1][2]
   for q=0,n-1 do
    local a0,a1=q/n*pi*2,(q+1)/n*pi*2
    Lx.quad({x0,cos(a0)*r0,sin(a0)*r0},{x0,cos(a1)*r0,sin(a1)*r0},{x1,cos(a1)*r1,sin(a1)*r1},{x1,cos(a0)*r1,sin(a0)*r1},'lgCrimson',1)
   end
  end
  for _,sx in ipairs({-1,1})do
   local Lh=K.model(Er,d[1]+sx*10.05,20,d[2],sx*pi/2,1)
   lib.fan(Lh,0,0,0,8.2,20,'lgMarble',1.05,0)
   Lh.decor(function()lib.ringXY(Lh,0,0,.05,7.4,8.2,20,'lgBronze',1)end)
   for q=0,11 do
    local a=q/12*pi*2
    Lh.box(cos(a)*7.8-.35,sin(a)*7.8-.35,-.1,cos(a)*7.8+.35,sin(a)*7.8+.35,.35,'lgGold',1,{})
   end
  end
  Lx.decor(function()
   for _,x in ipairs({-8.6,8.6})do
    for q=0,n-1 do
     local a0,a1=q/n*pi*2,(q+1)/n*pi*2
     local r=9.05
     Lx.quad({x-.5,cos(a0)*r,sin(a0)*r},{x-.5,cos(a1)*r,sin(a1)*r},{x+.5,cos(a1)*r,sin(a1)*r},{x+.5,cos(a0)*r,sin(a0)*r},'lgGold',1)
    end
   end
  end)
 end
 ---------------------------------------------------------------- walls
 local DH=38
 local function dojo(L,len,run)
  local north=run.o=='S'and run.c==16
  local holes={}
  for _,h in ipairs(run.holes)do holes[#holes+1]={h[1],h[2],DH}end
  -- granite, battered at the foot
  faceWithHoles(L,len,0,H,holes,'lgGranite',.95,0,16)
  for _,sp in ipairs(holes[1]and{{0,holes[1][1]},{holes[1][2],len}}or{{0,len}})do
   if sp[2]-sp[1]>.5 then
    L.box(sp[1],0,0,sp[2],8,3.2,'lgGranite',.98,{bottom=true})
    L.box(sp[1],8,0,sp[2],9.4,2.2,'lgGranite',1,{bottom=true})
   end
  end
  -- the timber frame: posts, sill, mid rail, top plate
  local posts={}
  local x=0
  while x<=len+.01 do posts[#posts+1]=x;x=x+32 end
  if len-posts[#posts]>12 then posts[#posts+1]=len end
  for _,px in ipairs(posts)do
   if not inHole(holes,px)then
    local a,b=max(0,px-3),min(len,px+3)
    L.box(a,9.4,0,b,H-6,3.6,'lgWood',1,{bottom=true})
    L.box(a-.6,9.4,0,b+.6,12,4.2,'lgBronze',1,{bottom=true})
   end
  end
  local function rail(y0,y1,d)
   for _,sp in ipairs(holes[1]and{{0,holes[1][1]-3},{holes[1][2]+3,len}}or{{0,len}})do
    if sp[2]-sp[1]>.5 then L.box(sp[1],y0,0,sp[2],y1,d,'lgWood',.95,{})end
   end
  end
  rail(52,56,3.0)
  L.box(0,H-8,0,len,H,4.4,'lgWood',.92,{})
  -- crimson banners in the bays, torches on alternate posts
  for i=1,#posts-1 do
   local a,b=posts[i],posts[i+1]
   local m=(a+b)/2
   local nearGate=false
   if north then for _,h in ipairs(holes)do if b>h[1]-18 and a<h[2]+18 then nearGate=true end end end
   if b-a>20 and not nearGate and not inHole(holes,m)and not inHole(holes,a+4)and not inHole(holes,b-4)then
    local top,bot=H-10,18
    L.box(m-9,top,1.2,m+9,top+1.4,3.4,'lgWood',1,{})
    L.quad({m-7.5,bot+5,1.6},{m+7.5,bot+5,1.6},{m+7.5,top,1.6},{m-7.5,top,1.6},'lgCrimson',1)
    L.quad({m-7.5,bot+5,1.6},{m,bot,1.6},{m+7.5,bot+5,1.6},{m-7.5,bot+5,1.6},'lgCrimson',1)
    L.decor(function()
     L.box(m-7.5,bot+5,1.6,m-6.8,top,1.75,'lgGold',1,{})
     L.box(m+6.8,bot+5,1.6,m+7.5,top,1.75,'lgGold',1,{})
     -- the emblem: a gold sun in a ring
     local ey=(top+bot)/2+6
     lib.ringXY(L,m,ey,1.7,4.6,5.4,24,'lgGold',1)
     lib.fan(L,m,ey,1.7,2.2,16,'lgGold',1.05,0)
     for k=0,7 do
      local an=k/8*pi*2
      L.quad({m+cos(an-.12)*2.8,ey+sin(an-.12)*2.8,1.72},{m+cos(an)*4.2,ey+sin(an)*4.2,1.72},{m+cos(an+.12)*2.8,ey+sin(an+.12)*2.8,1.72},{m+cos(an-.12)*2.8,ey+sin(an-.12)*2.8,1.72},'lgGold',1)
     end
     L.box(m-4,ey-12,1.6,m+4,ey-11.3,1.75,'lgGold',1,{})
    end)
   end
  end
  for i,px in ipairs(posts)do
   if i%2==0 and not inHole(holes,px)and px>8 and px<len-8 then
    L.box(px-1,40,3.6,px+1,42,7.5,'lgObsidian',1,{})
    L.frustum(px,42,6.4,1.4,46,2.4,8,'lgObsidian')
    local wx,wy,wz=run.toWorld(px,46.2,6.4)
    fx.fires[#fx.fires+1]={x=wx,y=wy,z=wz,s=.62,phase=wx*.07+wz*.05}
    C.addLight(wx,wy,wz,46,.30)
   end
  end
  if north then
   -- the gate: lacquered posts and a double lintel, gold caps
   for _,h in ipairs(holes)do
    local a,b=h[1],h[2];local cx=(a+b)/2
    local zb=-26
    L.quad({a,0,zb},{b,0,zb},{b,DH,zb},{a,DH,zb},'lgWood',.25)
    L.quad({a,0,0},{a,0,zb},{a,DH,zb},{a,DH,0},'lgGranite',.62)
    L.quad({b,0,zb},{b,0,0},{b,DH,0},{b,DH,zb},'lgGranite',.58)
    L.quad({a,DH,0},{b,DH,0},{b,DH,zb},{a,DH,zb},'lgWood',.5)
    for _,px in ipairs({a-4,b+4})do
     L.box(px-3.6,0,0,px+3.6,DH+16,7,'lgCrimson',1,{bottom=true})
     L.box(px-4.4,0,0,px+4.4,4,7.8,'lgObsidian',1,{bottom=true})
    end
    L.box(a-9,DH+4,0,b+9,DH+8,7.6,'lgCrimson',1,{})
    L.box(a-15,DH+16,-.5,b+15,DH+19,8.6,'lgCrimson',1,{})
    -- upturned ends of the top lintel
    for _,sg in ipairs({-1,1})do
     local ex=sg<0 and a-15 or b+15
     L.quad({ex,DH+19,8.6},{ex+sg*5,DH+23,8.6},{ex+sg*5,DH+23,-.5},{ex,DH+19,-.5},'lgCrimson',1)
     L.quad({ex,DH+16,8.6},{ex+sg*5,DH+21,8.6},{ex+sg*5,DH+23,8.6},{ex,DH+19,8.6},'lgCrimson',.9)
    end
    L.box(a-15.5,DH+19,-.5,b+15.5,DH+20,8.6,'lgObsidian',1,{})
    -- the plaque with his name
    L.box(cx-14,DH+8,6.6,cx+14,DH+16,7.6,'lgObsidian',1,{})
    L.decor(function()
     C.K.inscription(L,'BRUNO',cx,DH+9.6,7.6,1.0,'lgGold',22)
    end)
    -- the doors, shut until he is beaten
    local Es=C.part('doors',{door=true})
    local Ls=K.model(Es,run.a0,0,run.c,0,1)
    for i=0,1 do
     local l0=a+i*(b-a)/2;local l1=l0+(b-a)/2-.2
     Ls.box(l0,0,-5,l1,DH,-3,'lgWood',1,{})
     Ls.decor(function()
      for row=1,5 do for col=1,3 do
       local sx=l0+(l1-l0)*col/4;local sy=DH*row/6
       Ls.box(sx-.6,sy-.6,-3,sx+.6,sy+.6,-2.4,'lgBronze',1,{})
      end end
      Ls.box(l0,DH*.5-1,-3,l1,DH*.5+1,-2.6,'lgObsidian',1,{})
     end)
    end
   end
  end
 end
 C.walls(function(cx,cy)return C.is(cx,cy,'WD')end,dojo,{outside=true,door=function(cx,cy)return C.at(cx,cy)=='D'or(cy==C.ch and(cx==4 or cx==5))end})
 -- the south entrance: a dark passage behind the opening
 do
  local E=C.part('entry',{axis='z',c=D,s=-1})
  E.quad({64,0,D+24},{96,0,D+24},{96,DH,D+24},{64,DH,D+24},'lgWood',.25)
  E.quad({64,0,D},{64,0,D+24},{64,DH,D+24},{64,DH,D},'lgGranite',.6)
  E.quad({96,0,D+24},{96,0,D},{96,DH,D},{96,DH,D+24},'lgGranite',.6)
  E.quad({64,.01,D},{96,.01,D},{96,.01,D+24},{64,.01,D+24},'lgWood',.5)
  E.quad({64,DH,D+24},{96,DH,D+24},{96,DH,D},{64,DH,D},'lgWood',.4)
 end
 ---------------------------------------------------------------- ceiling
 local Ec=C.part('ceiling',{below=H})
 -- tie beams across, boards between, the lantern over the ring
 local LX0,LX1,LZ0,LZ1=56,104,24,72
 for z=0,D-1,16 do
  for x=0,W-1,16 do
   if not(x>=LX0 and x<LX1 and z>=LZ0 and z<LZ1)then
    Ec.quad({x,H,z+16},{x+16,H,z+16},{x+16,H,z},{x,H,z},'lgWood',.62)
   end
  end
 end
 for z=32,D-16,32 do Ec.box(0,H-9,z-3,W,H,z+3,'lgWood',.85,{top=true})end
 for x=32,W-16,32 do Ec.box(x-2,H-5,0,x+2,H,D,'lgWood',.75,{top=true})end
 -- the lantern: a raised box of paper screens in a timber lattice
 local LH=H+22
 local function screen(a,b,c,d)Ec.quad(a,b,c,d,'cream',1.25)end
 screen({LX0,H,LZ0},{LX1,H,LZ0},{LX1,LH,LZ0},{LX0,LH,LZ0})
 screen({LX1,H,LZ1},{LX0,H,LZ1},{LX0,LH,LZ1},{LX1,LH,LZ1})
 screen({LX0,H,LZ1},{LX0,H,LZ0},{LX0,LH,LZ0},{LX0,LH,LZ1})
 screen({LX1,H,LZ0},{LX1,H,LZ1},{LX1,LH,LZ1},{LX1,LH,LZ0})
 Ec.quad({LX0,LH,LZ1},{LX1,LH,LZ1},{LX1,LH,LZ0},{LX0,LH,LZ0},'cream',1.35)
 Ec.decor(function()
  for x=LX0,LX1,8 do
   Ec.box(x-.5,H,LZ0-.2,x+.5,LH,LZ0+.6,'lgWood',.7,{})
   Ec.box(x-.5,H,LZ1-.6,x+.5,LH,LZ1+.2,'lgWood',.7,{})
   Ec.box(x-.5,LH-.6,LZ0,x+.5,LH,LZ1,'lgWood',.7,{})
  end
  for z=LZ0,LZ1,8 do
   Ec.box(LX0-.2,H,z-.5,LX0+.6,LH,z+.5,'lgWood',.7,{})
   Ec.box(LX1-.6,H,z-.5,LX1+.2,LH,z+.5,'lgWood',.7,{})
   Ec.box(LX0,LH-.6,z-.5,LX1,LH,z+.5,'lgWood',.7,{})
  end
  for _,y in ipairs({H+7,H+14})do
   Ec.box(LX0-.2,y,LZ0-.2,LX1+.2,y+.8,LZ0+.6,'lgWood',.7,{})
   Ec.box(LX0-.2,y,LZ1-.6,LX1+.2,y+.8,LZ1+.2,'lgWood',.7,{})
   Ec.box(LX0-.2,y,LZ0,LX0+.6,y+.8,LZ1,'lgWood',.7,{})
   Ec.box(LX1-.6,y,LZ0,LX1+.2,y+.8,LZ1,'lgWood',.7,{})
  end
 end)
 fx.beams[#fx.beams+1]={x=80,y=H+10,z=48,tx=80,ty=0,tz=48,r0=22,r1=30,col={1,.92,.75},a=.07}
 fx.motes={x=80,z=48,r=26,y0=4,y1=H,n=36,col={1,.9,.7}}
 fx.pools[#fx.pools+1]={x=80,y=.3,z=48,r=38,a=.08,col={1,.86,.6}}
end

-- ====================================================================
-- AGATHA: A GOTHIC CRYPT
-- Dark slate under ribbed vaults; tall lancets of violet glass and a rose
-- window over the door glow in the dark; the graves are leaning headstones,
-- small obelisks and sarcophagi with candles guttering on them; a canopied
-- tomb with a violet orb; iron crowns of candles hang from the vault; mist
-- creeps along the floor and wisps drift between the stones.
-- ====================================================================
local function headstone(E,K,x,z,seed,kind)
 local lean=(rh(seed,1,3)-.5)*.18
 local yaw=(rh(seed,2,5)-.5)*.35
 local Lm=K.model(E,x,0,z,yaw,1)
 local w=4.2+rh(seed,3,7)*1.6
 local h=9+rh(seed,4,9)*7
 local t=1.6
 local mat=rh(seed,5,11)>.55 and 'lgMarble'or'lgSlate'
 local tone=mat=='lgMarble'and .62 or .95
 -- the plinth
 Lm.box(-w-1,0,-t-1.2,w+1,1.4,t+1.2,'lgSlate',.9,{bottom=true})
 -- the slab, leaning: a profile in x/y extruded through z, its top
 -- pushed forward by the lean
 local prof={}
 if kind=='point' then prof={{-w,0},{w,0},{w,h},{0,h+w*.9},{-w,h}}
 else
  prof={{-w,0},{w,0}}
  for i=0,8 do local a=i/8*pi;prof[#prof+1]={cos(a)*w,h+sin(a)*w*.75}end
 end
 local function P(px,py,pz)return{px,py+1.4,pz+py/h*lean*h}end
 local n=#prof
 for i=1,n do
  local a,b=prof[i],prof[i%n+1]
  if not(i==1)then
   Lm.quad(P(a[1],a[2],t),P(b[1],b[2],t),P(b[1],b[2],-t),P(a[1],a[2],-t),mat,tone)
  end
 end
 -- faces (fan from the centre)
 local cx,cy=0,h*.6
 for i=1,n do
  local a,b=prof[i],prof[i%n+1]
  Lm.quad(P(cx,cy,t),P(a[1],a[2],t),P(b[1],b[2],t),P(cx,cy,t),mat,tone)
  Lm.quad(P(cx,cy,-t),P(b[1],b[2],-t),P(a[1],a[2],-t),P(cx,cy,-t),mat,tone*.8)
 end
 -- a carved panel and a quatrefoil
 Lm.decor(function()
  Lm.box(-w*.6,h*.25+1.4,t,w*.6,h*.25+1.9,t+.15,'lgSilver',.5,{})
 end)
 return h
end
local function obeliskGrave(E,K,x,z,seed)
 local Lm=K.model(E,x,0,z,rh(seed,1,1)*.3,1)
 Lm.box(-5,0,-5,5,2,5,'lgSlate',.9,{bottom=true})
 Lm.box(-4,2,-4,4,6,4,'lgSlate',1,{bottom=true})
 Lm.box(-4.5,6,-4.5,4.5,7,4.5,'lgSlate',.95,{})
 local h=18+rh(seed,2,2)*8
 Lm.frustum(0,7,0,3.1,7+h,1.8,4,'lgSlate',false,pi/4)
 Lm.frustum(0,7+h,0,1.8*1.41,7+h+3,0,4,'lgSlate',false,pi/4)
 return 7+h+3
end
local function sarcophagus(E,K,x,z,len,seed,alongX)
 local Lm=K.model(E,x,0,z,alongX and pi/2 or 0,1)
 local hw,hl=5.5,len/2-1.5
 Lm.box(-hw-.8,0,-hl-.8,hw+.8,1.6,hl+.8,'lgSlate',.9,{bottom=true})
 Lm.box(-hw,1.6,-hl,hw,9,hl,'lgSlate',1,{bottom=true})
 Lm.decor(function()
  for k=-2,2 do
   local zz=k*hl/2.6
   Lm.box(-hw-.15,3,zz-1.6,hw+.15,7.5,zz+1.6,'lgSlate',.8,{})
  end
 end)
 Lm.box(-hw-1,9,-hl-1,hw+1,10.4,hl+1,'lgMarble',.55,{})
 Lm.frustum(0,10.4,0,0,11.2,0,4,'lgMarble')
 -- the lid's ridge
 Lm.quad({-hw-1,10.4,-hl-1},{hw+1,10.4,-hl-1},{0,12.4,-hl-1},{0,12.4,-hl-1},'lgMarble',.5)
 Lm.quad({hw+1,10.4,hl+1},{-hw-1,10.4,hl+1},{0,12.4,hl+1},{0,12.4,hl+1},'lgMarble',.55)
 Lm.quad({-hw-1,10.4,hl+1},{-hw-1,10.4,-hl-1},{0,12.4,-hl-1},{0,12.4,hl+1},'lgMarble',.6)
 Lm.quad({hw+1,10.4,-hl-1},{hw+1,10.4,hl+1},{0,12.4,hl+1},{0,12.4,-hl-1},'lgMarble',.62)
 return 12.4
end
local function candles(E,K,fx,x,y,z,n,seed,col)
 for k=0,n-1 do
  local a=rh(seed,k,3)*pi*2;local r=rh(seed,k,5)*2.4
  local cx,cz=x+cos(a)*r,z+sin(a)*r
  local h=1.4+rh(seed,k,7)*3.2
  local Lc=K.model(E,cx,y,cz,0,1)
  Lc.frustum(0,0,0,.42,h,.36,6,'lgMarble',true)
  -- a drip of wax at the foot
  Lc.frustum(0,0,0,.8,.3,.45,6,'lgMarble',false)
  fx.candles[#fx.candles+1]={x=cx,y=y+h+.1,z=cz,s=.62,phase=seed+k*1.7,col=col}
 end
end
function M.agatha(C)
 local K,lib=C.K,C.lib
 local W,D=C.W,C.D
 local F=V.require('LeagueFlora')
 C.H=132;C.ambient=.56;C.maxLight=1.38
 C.lightY=function(y)return 1-.30*max(0,min(1,(y-30)/90))end
 local H=C.H
 local fx=C.fx
 fx.mist,fx.wisps,fx.beams={},{},{}
 fx.ambience={crypt=.85}
 local solid=function(cx,cy)return C.is(cx,cy,'WD')or cx<0 or cx>=C.cw or cy<0 or cy>=C.ch end
 -- light: the rose window, the candles (added as they are placed), the
 -- crowns of candles over the aisle
 C.addLight(80,84,20,110,.30)
 C.addLight(80,60,72,60,.22);C.addLight(80,60,140,60,.22)
 ---------------------------------------------------------------- graves
 -- choose each grave first (candles light their surroundings)
 local graves={}
 local used={}
 for cy=0,C.ch-1 do for cx=0,C.cw-1 do
  if C.at(cx,cy)=='G'and not used[cy*100+cx]then
   local seed=cx*37+cy*11
   local g={cx=cx,cy=cy,seed=seed}
   -- a sarcophagus spans two cells side by side, now and then
   if C.at(cx+1,cy)=='G'and not used[cy*100+cx+1]and rh(seed,9,9)>.55 then
    g.kind='sarc';g.w=2;used[cy*100+cx+1]=true
   else
    local r=rh(seed,8,8)
    g.kind=r<.18 and'obelisk'or(r<.60 and'point'or'round')
   end
   used[cy*100+cx]=true
   g.candles=rh(seed,7,7)>.45
   graves[#graves+1]=g
  end
 end end
 for _,g in ipairs(graves)do
  if g.candles then C.addLight(g.cx*CS+8,14,g.cy*CS+8,38,.34)end
 end
 ---------------------------------------------------------------- floor
 local Ef=C.part('floor',nil,true)
 local ao=C.aoField(function(cx,cy)return solid(cx,cy)end,16)
 for cy=0,C.ch-1 do for cx=0,C.cw-1 do
  if not C.is(cx,cy,'W')then C.floorRect(Ef,cx*CS,cy*CS,cx*CS+CS,cy*CS+CS,0,'lgSlate',1,ao,8)end
 end end
 Ef.decor(function()
  Ef.box(66,0,0,94,.16,D,'lgPlum',1,{bottom=true})
  Ef.box(66,0,0,67.2,.22,D,'lgGold',1,{bottom=true})
  Ef.box(92.8,0,0,94,.22,D,'lgGold',1,{bottom=true})
  local z=8
  while z<D do
   Ef.quad({80,.2,z-2.4},{82.2,.2,z},{80,.2,z+2.4},{77.8,.2,z},'lgGold',1)
   z=z+16
  end
 end)
 local Eg=C.part('graves',nil,true)
 for _,g in ipairs(graves)do
  local x,z=g.cx*CS+8,g.cy*CS+8
  local top
  if g.kind=='sarc'then top=sarcophagus(Eg,K,x+8,z,30,g.seed,true);x=x+8
  elseif g.kind=='obelisk'then top=obeliskGrave(Eg,K,x,z,g.seed)
  else top=headstone(Eg,K,x,z,g.seed,g.kind)end
  if g.candles then
   local cz=z+(g.kind=='sarc'and 0 or 4.6)
   local cy=g.kind=='sarc'and top-1.6 or 0
   candles(Eg,K,fx,x+(g.kind=='sarc'and 0 or 2.5),g.kind=='sarc'and 10.4 or 0,cz,g.kind=='sarc'and 3 or 4,g.seed,rh(g.seed,6,6)>.5 and'violet'or nil)
  end
  -- moss and dead leaves at the foot
  if rh(g.seed,10,10)>.5 then
   F.cluster(Eg,'lgMeadow',x+(rh(g.seed,11,1)-.5)*8,.4,z+5,3.2,.9,2.2,6,2,g.seed,{y0=0,y1=1.4,lump=.3})
  end
 end
 ---------------------------------------------------------------- the tomb
 do
  local x,z=56,144
  local Lt=K.model(Eg,x,0,z,0,1)
  Lt.box(-7.6,0,-15.6,7.6,2.4,15.6,'lgSlate',.92,{bottom=true})
  Lt.box(-6.8,2.4,-14.8,6.8,3.2,14.8,'lgMarble',.6,{bottom=true})
  sarcophagus(Eg,K,x,z,22,77,false)
  -- four slender shafts and pointed arches, a spire, the violet orb
  local cols={{-5.6,-13},{5.6,-13},{-5.6,13},{5.6,13}}
  for _,c in ipairs(cols)do
   Lt.frustum(c[1],3.2,c[2],1.1,4.4,.9,8,'lgSlate')
   Lt.frustum(c[1],4.4,c[2],.75,30,.75,8,'lgSlate',false)
   Lt.box(c[1]-1.2,30,c[2]-1.2,c[1]+1.2,31.6,c[2]+1.2,'lgSlate',1,{})
  end
  -- arches on all four sides
  local function arch(ax,az,bx,bz,y0,rise)
   local n=8
   for i=0,n-1 do
    local u0,u1=i/n,(i+1)/n
    local function P(u,dy)
     local px,pz=ax+(bx-ax)*u,az+(bz-az)*u
     local yy=y0+rise*(1-abs(2*u-1)^1.6)
     return{px,yy+(dy or 0),pz}
    end
    Lt.quad(P(u0),P(u1),P(u1,y0+rise+4-P(u1)[2]),P(u0,y0+rise+4-P(u0)[2]),'lgSlate',.9)
   end
  end
  arch(-5.6,-13,5.6,-13,31.6,7);arch(5.6,13,-5.6,13,31.6,7)
  arch(-5.6,13,-5.6,-13,31.6,9);arch(5.6,-13,5.6,13,31.6,9)
  Lt.box(-7,42.6,-14.6,7,44,14.6,'lgSlate',1,{})
  -- the spire
  Lt.frustum(0,44,0,9.5,62,2.2,4,'lgSlate',false,pi/4)
  Lt.frustum(0,62,0,2.2,70,0,4,'lgSlate',false,pi/4)
  for _,c in ipairs(cols)do
   Lt.frustum(c[1],44,c[2],1.4,52,0,4,'lgSlate',false,pi/4)
  end
  -- the orbs: plain violet glass lit from within (shade >2 drops the leading)
  C.flat=true
  local Lo=K.model(Eg,x,0,z,0,1,3.5)
  Lo.sphere(0,72,0,2.4,2.4,2.4,'lgAmethyst',10,6)
  Lo.sphere(0,20,0,2.6,2.6,2.6,'lgAmethyst',10,6)
  C.flat=false
  fx.glows[#fx.glows+1]={x=x,y=72,z=z,r=14,col='violet',a=.40}
  fx.glows[#fx.glows+1]={x=x,y=20,z=z,r=16,col='violet',a=.45}
  C.addLight(x,22,z,44,.35)
  candles(Eg,K,fx,x-5,3.2,z-15.5,3,91,'violet')
  candles(Eg,K,fx,x+5,3.2,z+15.5,3,93,'violet')
 end
 ---------------------------------------------------------------- walls
 local DH=46
 local SPRING=H-36
 local function gothic(L,len,run)
  local north=run.o=='S'and run.c==16
  local south=run.o=='N'and run.c==D
  local holes={}
  for _,h in ipairs(run.holes)do holes[#holes+1]={h[1],h[2],DH+12}end
  faceWithHoles(L,len,0,H,holes,'lgSlate',.95,0,16)
  -- plinth and string courses
  local spans=holes[1]and{{0,holes[1][1]-6},{holes[1][2]+6,len}}or{{0,len}}
  for _,sp in ipairs(spans)do
   if sp[2]-sp[1]>.5 then
    L.box(sp[1],0,0,sp[2],4,2.4,'lgSlate',.92,{bottom=true})
    L.box(sp[1],4,0,sp[2],5,2.8,'lgSlate',1,{bottom=true})
    L.box(sp[1],40,0,sp[2],42,2.4,'lgSlate',1,{})
   end
  end
  if north then
   L.box(0,SPRING-2,0,len/2-17,SPRING,2.6,'lgSlate',1,{})
   L.box(len/2+17,SPRING-2,0,len,SPRING,2.6,'lgSlate',1,{})
  else L.box(0,SPRING-2,0,len,SPRING,2.6,'lgSlate',1,{})end
  -- piers every 32: a clustered shaft from the floor to the vault
  local piers={}
  local x=0
  while x<=len+.01 do piers[#piers+1]=x;x=x+32 end
  for _,px in ipairs(piers)do
   if not inHole(holes,px)then
    L.box(max(0,px-4),0,0,min(len,px+4),6,4.4,'lgSlate',.95,{bottom=true})
    L.frustum(px,6,3.0,2.2,SPRING,2.2,8,'lgSlate',false)
    for _,sx in ipairs({-2.6,2.6})do
     if px+sx>0 and px+sx<len then L.frustum(px+sx,6,1.6,1.1,SPRING,1.1,6,'lgSlate',false)end
    end
    L.box(px-3.6,SPRING,0,px+3.6,SPRING+2.2,5,'lgSlate',1,{})
   end
  end
  -- blind arcade under the windows, lancets of violet glass above
  for i=1,#piers-1 do
   local a,b=piers[i],piers[i+1]
   local m=(a+b)/2
   local nearDoor=false
   for _,h in ipairs(holes)do if b>h[1]-14 and a<h[2]+14 then nearDoor=true end end
   if b-a>20 then
    if not nearDoor then
     -- the arcade: three pointed arches in relief
     for k=0,2 do
      local u0,u1=a+5+(b-a-10)*k/3,a+5+(b-a-10)*(k+1)/3
      local um=(u0+u1)/2
      L.box(u0-.4,5,0,u0+.4,30,1.4,'lgSlate',1,{})
      for q=0,5 do
       local t0,t1=q/6,(q+1)/6
       local function A(t)return u0+(u1-u0)*t,28+6*(1-abs(2*t-1)^1.5)end
       local xa,ya=A(t0);local xb,yb=A(t1)
       L.quad({xa,ya,1.2},{xb,yb,1.2},{xb,yb+1.2,1.2},{xa,ya+1.2,1.2},'lgSlate',1)
      end
     end
    end
    -- two lancets per bay
    if not(north and nearDoor)then
     for k=0,1 do
      local u0,u1=a+6+(b-a-12)*k/2+1,a+6+(b-a-12)*(k+1)/2-1
      local w0,w1=48,SPRING-15
      local um=(u0+u1)/2
      L.box(u0-1,w0-1,0,u1+1,w1,.4,'lgSlate',.8,{})
      L.quad({u0,w0,.42},{u1,w0,.42},{u1,w1,.42},{u0,w1,.42},'lgAmethyst',1)
      L.quad({u0,w1,.42},{u1,w1,.42},{um,w1+9,.42},{um,w1+9,.42},'lgAmethyst',1.05)
      L.decor(function()
       L.box(u0-1.2,w0-1.4,.42,u1+1.2,w0,1.0,'lgSlate',1,{})
       for _,yy in ipairs({w0+(w1-w0)*.33,w0+(w1-w0)*.66})do L.box(u0,yy-.3,.42,u1,yy+.3,.7,'lgObsidian',1,{})end
      end)
      local wx,wy,wz=run.toWorld(um,(w0+w1)/2,1)
      local tx,ty,tz=run.toWorld(um,0,46)
      fx.beams[#fx.beams+1]={x=wx,y=wy,z=wz,tx=tx,ty=ty,tz=tz,r0=3,r1=9,col={.62,.36,1},a=.045}
     end
    end
   end
  end
  if north then
   for _,h in ipairs(holes)do
    local a,b=h[1],h[2];local cx=(a+b)/2;local hw=(b-a)/2
    -- the doorway: a deep pointed arch with moulded jambs
    local zb=-run.c-20
    L.quad({a,0,zb},{b,0,zb},{b,DH,zb},{a,DH,zb},'lgSlate',.22)
    L.quad({a,0,0},{a,0,zb},{a,DH,zb},{a,DH,0},'lgSlate',.55)
    L.quad({b,0,zb},{b,0,0},{b,DH,0},{b,DH,zb},'lgSlate',.5)
    L.quad({a,.02,0},{b,.02,0},{b,.02,zb},{a,.02,zb},'lgSlate',.5)
    for i=0,9 do
     local t0,t1=i/10,(i+1)/10
     local function A(t)return a+(b-a)*t,DH+12*(1-abs(2*t-1)^1.4)end
     local xa,ya=A(t0);local xb,yb=A(t1)
     L.quad({xa,ya,0},{xb,yb,0},{xb,yb,zb},{xa,ya,zb},'lgSlate',.45)
     L.quad({xa,ya,.05},{xb,yb,.05},{xb,DH+12,.05},{xa,DH+12,.05},'lgSlate',.95)
     for _,r in ipairs({.6,3.4})do
      L.quad({xa,ya+r,1.2+r*.3},{xb,yb+r,1.2+r*.3},{xb,yb+r+1.6,1.2+r*.3},{xa,ya+r+1.6,1.2+r*.3},'lgSlate',1)
     end
    end
    for _,sx in ipairs({a-4,b+4})do
     for _,r in ipairs({0,2.6})do L.frustum(sx+(sx<cx and -r or r),0,1.6+r*.4,1.2,DH,1.2,6,'lgSlate',false)end
    end
    -- AGATHA in gold on a band over the door
    L.box(cx-26,DH+18,0,cx+26,DH+26,1.6,'lgObsidian',1,{})
    L.decor(function()C.K.inscription(L,'AGATHA',cx,DH+19.4,1.6,1.05,'lgGold',30)end)
    -- the rose window
    local ry,rr=SPRING+11,13.5
    lib.ringXY(L,cx,ry,1.0,rr,rr+2.6,40,'lgSlate',1)
    lib.fan(L,cx,ry,.4,rr,40,'lgAmethyst',1,0)
    L.decor(function()
     lib.ringXY(L,cx,ry,.7,rr*.36,rr*.36+1.2,24,'lgObsidian',1)
     lib.ringXY(L,cx,ry,.7,rr*.70,rr*.70+1.0,32,'lgObsidian',1)
     for k=0,15 do
      local an=k/16*pi*2
      local c0,s0=cos(an),sin(an)
      L.quad({cx+c0*rr*.37-s0*.5,ry+s0*rr*.37+c0*.5,.7},{cx+c0*rr-s0*.5,ry+s0*rr+c0*.5,.7},{cx+c0*rr+s0*.5,ry+s0*rr-c0*.5,.7},{cx+c0*rr*.37+s0*.5,ry+s0*rr*.37-c0*.5,.7},'lgObsidian',1)
      -- trefoil heads between the spokes
      local ah=an+pi/16
      lib.ringXY(L,cx+cos(ah)*rr*.83,ry+sin(ah)*rr*.83,.75,1.3,1.8,10,'lgObsidian',1)
     end
     for k=0,7 do
      local an=k/8*pi*2
      L.quad({cx,ry,.75},{cx+cos(an)*rr*.36,ry+sin(an)*rr*.36,.75},{cx+cos(an+.06)*rr*.36,ry+sin(an+.06)*rr*.36,.75},{cx,ry,.75},'lgObsidian',1)
     end
     lib.fan(L,cx,ry,.8,3.0,12,'lgGold',1.1,0)
    end)
    local wx,wy,wz=run.toWorld(cx,ry,1)
    fx.glows[#fx.glows+1]={x=wx,y=wy,z=wz+1,r=30,col='violet',a=.16}
    fx.beams[#fx.beams+1]={x=wx,y=wy,z=wz,tx=wx,ty=0,tz=wz+110,r0=14,r1=26,col={.66,.36,1},a=.05}
    -- the doors, iron-strapped, shut until she is beaten
    local Es=C.part('doors',{door=true})
    local Ls=K.model(Es,run.a0,0,run.c,0,1)
    for i=0,1 do
     local l0=a+i*(b-a)/2;local l1=l0+(b-a)/2-.2
     Ls.box(l0,0,-6,l1,DH,-4,'lgWood',.55,{})
     Ls.decor(function()
      for _,yy in ipairs({8,22,36})do Ls.box(l0,yy,-4,l1,yy+1.6,-3.6,'lgObsidian',1,{})end
      Ls.box(i==0 and l1-2 or l0+.6,DH*.45,-4,i==0 and l1-.6 or l0+2,DH*.45+3,-3.2,'lgObsidian',1,{})
     end)
     for q=0,5 do
      local t0,t1=q/6,(q+1)/6
      local function A(t)return a+(b-a)*t,DH+12*(1-abs(2*t-1)^1.4)end
      local xa,ya=A(t0);local xb,yb=A(t1)
      if (i==0 and t1<=.5)or(i==1 and t0>=.5)then
       Ls.quad({xa,DH,-5},{xb,DH,-5},{xb,yb,-5},{xa,ya,-5},'lgWood',.55)
      end
     end
    end
   end
  end
  if south then
   for _,h in ipairs(run.holes)do
    local a,b=h[1],h[2]
    local zb=-24
    L.quad({a,0,zb},{b,0,zb},{b,DH,zb},{a,DH,zb},'lgSlate',.2)
    L.quad({a,0,0},{a,0,zb},{a,DH,zb},{a,DH,0},'lgSlate',.5)
    L.quad({b,0,zb},{b,0,0},{b,DH,0},{b,DH,zb},'lgSlate',.5)
    L.quad({a,.02,0},{b,.02,0},{b,.02,zb},{a,.02,zb},'lgSlate',.45)
    for i=0,9 do
     local t0,t1=i/10,(i+1)/10
     local function A(t)return a+(b-a)*t,DH+12*(1-abs(2*t-1)^1.4)end
     local xa,ya=A(t0);local xb,yb=A(t1)
     L.quad({xa,ya,0},{xb,yb,0},{xb,yb,zb},{xa,ya,zb},'lgSlate',.4)
     L.quad({xa,ya,.05},{xb,yb,.05},{xb,DH+12,.05},{xa,DH+12,.05},'lgSlate',.95)
    end
   end
  end
 end
 C.walls(function(cx,cy)return C.is(cx,cy,'WD')end,gothic,{outside=true,door=function(cx,cy)return C.at(cx,cy)=='D'or(cy==C.ch and(cx==4 or cx==5))end})
 ---------------------------------------------------------------- vaults
 local Ev=C.part('vault',{below=H})
 local NX,NZ=5,5
 local BX,BZ=W/NX,(D-16)/NZ
 local RISE=H-SPRING+6
 local function prof(t)return 1-abs(2*t-1)^1.7 end
 for bz=0,NZ-1 do for bx=0,NX-1 do
  local x0,z0=bx*BX,16+bz*BZ
  local n=8
  local function P(i,j)
   local u,v=i/n,j/n
   return{x0+BX*u,SPRING+RISE*max(prof(u),prof(v)),z0+BZ*v}
  end
  for j=0,n-1 do for i=0,n-1 do
   Ev.quad(P(i,j+1),P(i+1,j+1),P(i+1,j),P(i,j),'lgSlate',.80)
  end end
  -- diagonal ribs and the boss
  Ev.decor(function()
   for _,dgn in ipairs({1,-1})do
    for i=0,n-1 do
     local function R(t,off)
      local u=t;local v=dgn==1 and t or 1-t
      local y=SPRING+RISE*prof(t)-.5
      return{x0+BX*u+off,y,z0+BZ*v+(dgn==1 and -off or off)}
     end
     local a,b=R(i/n,0),R((i+1)/n,0)
     Ev.quad({a[1]-.8,a[2],a[3]},{b[1]-.8,b[2],b[3]},{b[1]+.8,b[2],b[3]},{a[1]+.8,a[2],a[3]},'lgSlate',.62)
    end
   end
   -- transverse ribs on the bay's edges
   for i=0,n-1 do
    local u0,u1=i/n,(i+1)/n
    local y0,y1=SPRING+RISE*prof(u0)-.4,SPRING+RISE*prof(u1)-.4
    Ev.quad({x0+BX*u0,y0,z0-.9},{x0+BX*u1,y1,z0-.9},{x0+BX*u1,y1,z0+.9},{x0+BX*u0,y0,z0+.9},'lgSlate',.6)
    local zz0,zz1=z0+BZ*u0,z0+BZ*u1
    Ev.quad({x0-.9,y0,zz0},{x0-.9,y1,zz1},{x0+.9,y1,zz1},{x0+.9,y0,zz0},'lgSlate',.6)
   end
   lib.fanH(Ev,x0+BX/2,z0+BZ/2,SPRING+RISE-.8,2.2,8,'lgGold',.9)
  end)
 end end
 -- the crowns of candles over the aisle
 for i,cz in ipairs({72,140})do
  local cx,cy=80,62
  Ev.box(cx-.25,cy+6,cz-.25,cx+.25,SPRING+RISE,cz+.25,'lgObsidian',1,{})
  local Lk=K.model(Ev,cx,cy,cz,0,1)
  Lk.frustum(0,0,0,11,1.2,11,20,'lgObsidian')
  Lk.frustum(0,1.2,0,11,1.2,10,20,'lgObsidian')
  Lk.frustum(0,-3,0,1.2,6,1.2,6,'lgObsidian')
  for k=0,5 do
   local a=k/6*pi*2
   F.limb(Ev,'lgObsidian',{cx,cy+6,cz},{cx+cos(a)*10.5,cy+1.2,cz+sin(a)*10.5},.18,.18,4)
  end
  for k=0,9 do
   local a=k/10*pi*2+i
   local px,pz=cx+cos(a)*10.5,cz+sin(a)*10.5
   Ev.box(px-.5,cy+1.2,pz-.5,px+.5,cy+1.6,pz+.5,'lgObsidian',1,{})
   local Lc=K.model(Ev,px,cy+1.6,pz,0,1)
   Lc.frustum(0,0,0,.4,2.6,.34,6,'lgMarble',true)
   fx.candles[#fx.candles+1]={x=px,y=cy+4.3,z=pz,s=.6,phase=k*1.3+i,col=k%3==0 and'violet'or nil,ceil=true}
  end
  fx.glows[#fx.glows+1]={x=cx,y=cy+4,z=cz,r=22,col='warm',a=.12}
 end
 ---------------------------------------------------------------- effects
 for k=0,9 do
  fx.mist[#fx.mist+1]={x=16+rh(k,1,1)*128,y=1.2,z=30+rh(k,2,2)*150,r=26+rh(k,3,3)*14,phase=k*1.3,col={.55,.42,.75},a=.12,drift=6}
 end
 for k=0,6 do
  fx.wisps[#fx.wisps+1]={x=20+rh(k,4,4)*120,y=14+rh(k,5,5)*16,z=40+rh(k,6,6)*130,s=.9+rh(k,7,7)*.5,phase=k*2.2,code=k%3==0 and 6 or 2,range=18}
 end
end

-- ====================================================================
-- LANCE: THE DRAGON TEMPLE OVER THE ABYSS
-- The halls are causeways of obsidian over a crater of lava, open to a
-- storm. Parapets with fire on tall columns line every edge; the cliffs
-- drop away to the molten floor far below; bronze dragons coil on their
-- plinths along the statue hall, and two great ones rear at the dragon
-- gate behind Lance. A crimson road leads from the stair you arrive by to
-- the gate that shuts behind you, and on to him. Across the abyss a lost
-- shrine floats on its own rock.
-- ====================================================================
local ABYSS=-170
-- a heraldic dragon coiled on a plinth top at (ox,oy,oz), facing local +z
local function dragon(E,K,F,lib,ox,oy,oz,yaw,sc,seed,fx)
 local co,si=cos(yaw),sin(yaw)
 local function P(x,y,z)return{ox+(x*co+z*si)*sc,oy+y*sc,oz+(-x*si+z*co)*sc}end
 local B,G='lgBronze','lgGold'
 local path={{-13,1.0,-4},{-10,2.0,-5.6},{-6,3.0,-5.8},{-2,3.4,-4.2},{1.4,3.8,-1.2},{3.2,4.8,2.0},{1.2,6.2,4.6},{-3,7.6,4.2},{-6.2,8.4,1.2},{-6.2,9.4,-2.0},{-3.2,10.8,-3.6},{.8,12.4,-2.2},{2.4,14.6,.4},{2.0,18.2,2.4},{1.2,22.0,3.4},{.6,25.8,4.4},{.4,28.6,6.0}}
 local rad={.45,.9,1.4,1.9,2.3,2.6,2.8,2.9,3.0,3.1,3.2,3.2,2.9,2.4,2.1,1.9,1.8}
 for i=1,#path-1 do
  F.limb(E,B,P(path[i][1],path[i][2],path[i][3]),P(path[i+1][1],path[i+1][2],path[i+1][3]),rad[i]*sc,rad[i+1]*sc,8,.95)
 end
 -- the dorsal crest: gold fins along the spine
 for i=3,#path-1,1 do
  local a,b=path[i],path[i+1]
  local mx,my,mz=(a[1]+b[1])/2,(a[2]+b[2])/2,(a[3]+b[3])/2
  local r=(rad[i]+rad[i+1])/2
  local h=.9+r*.45
  E.quad(P(a[1],a[2]+r*.85,a[3]),P(b[1],b[2]+r*.85,b[3]),P(mx,my+r+h,mz),P(mx,my+r+h,mz),G,1)
 end
 -- forelegs and claws
 for _,sx in ipairs({-1,1})do
  F.limb(E,B,P(sx*1.8,10.5,1.0),P(sx*2.6,5.6,4.2),1.1*sc,.9*sc,6)
  F.limb(E,B,P(sx*2.6,5.6,4.2),P(sx*2.8,.2,5.6),.9*sc,.7*sc,6)
  for k=-1,1 do F.limb(E,G,P(sx*2.8+k*.5,.4,5.8),P(sx*2.8+k*.9,.0,7.2),.28*sc,.06*sc,4)end
 end
 -- wings: four gold ribs fanning up and back, bronze membranes between
 for _,sx in ipairs({-1,1})do
  local sh={sx*2.6,14.0,-1.2}
  local tips={{sx*7,26,-4},{sx*11,30,-6},{sx*14,25,-7},{sx*15,17,-6.5},{sx*12,11,-4.5}}
  for k=1,#tips do
   F.limb(E,G,P(sh[1],sh[2],sh[3]),P(tips[k][1],tips[k][2],tips[k][3]),.55*sc,.12*sc,4)
  end
  for k=1,#tips-1 do
   local a,b=tips[k],tips[k+1]
   local m={(a[1]+b[1])/2*.86+sh[1]*.14,(a[2]+b[2])/2*.86+sh[2]*.14-1.5,(a[3]+b[3])/2}
   E.quad(P(sh[1],sh[2],sh[3]),P(a[1],a[2],a[3]),P(m[1],m[2],m[3]),P(b[1],b[2],b[3]),B,.78)
  end
 end
 -- the head: cranium, snout, open jaws, horns, glowing eyes
 local hx,hy,hz=.4,29.4,7.0
 local Lh=K.model(E,P(hx,hy,hz)[1],P(hx,hy,hz)[2],P(hx,hy,hz)[3],yaw,sc)
 Lh.box(-1.9,-1.5,-1.8,1.9,1.7,1.6,B,1,{bottom=false})
 Lh.box(-1.3,-.3,1.6,1.3,1.1,6.4,B,1,{bottom=false})
 Lh.box(-1.05,-.15,6.4,1.05,.9,7.0,B,1,{})
 Lh.box(-1.1,-2.3,1.4,1.1,-1.3,5.6,B,.9,{})
 Lh.box(-1.5,1.1,-1.0,1.5,1.9,2.6,B,1,{})
 for _,sx in ipairs({-1,1})do
  -- teeth
  for k=0,2 do
   local zz=2.4+k*1.3
   Lh.quad({sx*1.15,-.3,zz},{sx*1.15,-.3,zz+.6},{sx*1.0,-1.1,zz+.3},{sx*1.0,-1.1,zz+.3},G,1.1)
  end
  -- the eyes
  Lh.quad({sx*1.92,.4,.2},{sx*1.92,.4,1.2},{sx*1.92,1.0,1.0},{sx*1.92,1.0,.4},'lgLava',1.6)
  -- horns, swept back
  F.limb(E,G,P(hx+sx*1.3,hy+1.6,hz-.8),P(hx+sx*2.6,hy+5.2,hz-4.6),.55*sc,.08*sc,5)
  F.limb(E,G,P(hx+sx*1.6,hy+.4,hz-1.4),P(hx+sx*3.4,hy+.8,hz-4.0),.35*sc,.05*sc,4)
 end
 -- the beard: spikes under the jaw
 for k=-1,1 do F.limb(E,G,P(hx+k*.6,hy-2.2,hz+2.4),P(hx+k*.9,hy-4.6,hz+1.6),.25*sc,.04*sc,4)end
 -- the tail's barb
 E.quad(P(-13,1.0,-4),P(-14.6,1.6,-2.4),P(-15.4,1.0,-4.4),P(-14.6,1.6,-5.6),G,1)
 if fx then
  local e1=P(hx+1.95,hy+.7,hz+.7);local e2=P(hx-1.95,hy+.7,hz+.7)
  fx.glows[#fx.glows+1]={x=(e1[1]+e2[1])/2,y=e1[2],z=(e1[3]+e2[3])/2,r=3.4*sc,col='red',a=.55}
 end
end
M.dragon=dragon
function M.lance(C)
 local K,lib=C.K,C.lib
 local W,D=C.W,C.D
 local F=V.require('LeagueFlora')
 C.H=200;C.ambient=.62;C.maxLight=1.5
 -- the lava lights everything from below
 C.lightY=function(y)
  if y<0 then return 1-.40*min(1,-y/120)+.55*max(0,(-y-130)/40)end
  return 1-.18*min(1,y/90)
 end
 local fx=C.fx
 fx.embers,fx.lava,fx.lightning,fx.beams={}, {}, {}, {}
 fx.ambience={storm=.85}
 local function plat(cx,cy)local c=C.at(cx,cy);return c~=nil and c~='V'end
 local function walkish(cx,cy)local c=C.at(cx,cy);return c=='.'or c=='D'or c=='E'or c=='U'end
 ---------------------------------------------------------------- the sky, the crater
 C.sky(208,208,1100,3,-60)
 local Ek=C.part('crater')
 do
  -- the lava sea
  local saveFlat=C.flat;C.flat=true
  local R0=760
  for j=-7,12 do for i=-7,12 do
   local x0,z0=i*64-64,j*64-64
   Ek.quad({x0,ABYSS,z0+64},{x0+64,ABYSS,z0+64},{x0+64,ABYSS,z0},{x0,ABYSS,z0},'lgLava',1)
  end end
  C.flat=saveFlat
  -- the crater wall: a ring of rock cliffs rising out of the lava
  local cx,cz,Rr=208,208,560
  local n=56
  local function top(a)return 150+60*sin(a*3+1)+34*sin(a*7.3)+18*sin(a*17)end
  local rows=7
  for i=0,n-1 do
   local a0,a1=i/n*pi*2,(i+1)/n*pi*2
   local t0,t1=top(a0),top(a1)
   for j=0,rows-1 do
    local v0,v1=j/rows,(j+1)/rows
    local function Q(a,t,v)
     local y=ABYSS+(t-ABYSS)*v
     local r=Rr+18*sin(a*9+y*.02)+24*v*v+10*sin(y*.05+a*5)
     return{cx+cos(a)*r,y,cz+sin(a)*r}
    end
    Ek.quad(Q(a1,t1,v0),Q(a0,t0,v0),Q(a0,t0,v1),Q(a1,t1,v1),j==0 and'lgObsidian'or'lgRock',.34-.03*j)
   end
   -- now and then a fall of lava down the crater's face
   if rh(i,7,7)>.78 then
    local am=(a0+a1)/2;local w=.010+rh(i,8,8)*.012
    local function Q2(a,v)
     local t=top(a)
     local y=ABYSS+(t*.7-ABYSS)*v
     local vw=(y-ABYSS)/(t-ABYSS)
     local r=Rr+18*sin(a*9+y*.02)+24*vw*vw+10*sin(y*.05+a*5)-1.5
     return{cx+cos(a)*r,y,cz+sin(a)*r}
    end
    local saveFlat=C.flat;C.flat=true
    for j=0,5 do
     local v0,v1=j/6,(j+1)/6
     Ek.quad(Q2(am+w,v0),Q2(am-w,v0),Q2(am-w*.7,v1),Q2(am+w*.7,v1),'lgLava',.9-j*.08)
    end
    C.flat=saveFlat
    fx.lavafalls=fx.lavafalls or{}
    local b=Q2(am,0)
    fx.lavafalls[#fx.lavafalls+1]={x=b[1],z=b[3]}
   end
  end
 end
 ---------------------------------------------------------------- platforms
 local Ef=C.part('floor',nil,true)
 local Ecl=C.part('cliffs',nil,true)
 for cy=0,C.ch-1 do for cx=0,C.cw-1 do
  if plat(cx,cy)then
   local x0,z0=cx*CS,cy*CS
   C.floorRect(Ef,x0,z0,x0+CS,z0+CS,0,'lgObsidian',1,nil,8)
   -- cliffs where the platform meets the abyss (or the map's edge)
   local function cliff(nx,nz,a,b)
    if plat(cx+nx,cy+nz)then return end
    local rows=7
    local bottom=ABYSS-12
    for j=0,rows-1 do
     local y0,y1=bottom*j/rows,bottom*(j+1)/rows
     local function off(px,pz,y)
      local w=4.5*sin(px*.21+pz*.17+y*.05)+3.0*sin(y*.11+px*.07-pz*.09)+2.0*sin(px*.6-pz*.5+y*.2)
      local flare=(-y)*.05+max(0,(-y-120))*.35
      return px+nx*(w+flare),y,pz+nz*(w+flare)
     end
     local ax,ay,az=off(a[1],a[3],y0);local bx,by,bz=off(b[1],b[3],y0)
     local cx2,cy2,cz2=off(b[1],b[3],y1);local dx,dy,dz=off(a[1],a[3],y1)
     if j==0 then ax,az=a[1],a[3];bx,bz=b[1],b[3] end
     Ecl.quad({ax,ay,az},{bx,by,bz},{cx2,cy2,cz2},{dx,dy,dz},j==0 and'lgObsidian'or'lgRock',j==0 and .85 or .42)
    end
   end
   cliff(0,-1,{x0+CS,0,z0},{x0,0,z0})
   cliff(0,1,{x0,0,z0+CS},{x0+CS,0,z0+CS})
   cliff(-1,0,{x0,0,z0},{x0,0,z0+CS})
   cliff(1,0,{x0+CS,0,z0+CS},{x0+CS,0,z0})
  end
 end end
 -- gold inlay on the halls' slabs, and the crimson road
 Ef.decor(function()
  local function road(x0,z0,x1,z1)
   Ef.box(x0,0,z0,x1,.18,z1,'lgCarpet',1,{bottom=true})
   if x1-x0>z1-z0 then
    Ef.box(x0,0,z0,x1,.24,z0+1.2,'lgGold',1,{bottom=true});Ef.box(x0,0,z1-1.2,x1,.24,z1,'lgGold',1,{bottom=true})
   else
    Ef.box(x0,0,z0,x0+1.2,.24,z1,'lgGold',1,{bottom=true});Ef.box(x1-1.2,0,z0,x1,.24,z1,'lgGold',1,{bottom=true})
   end
  end
  road(296,258,402,282)      -- the right hall, from the stair
  road(274,258,298,382)      -- down the passage
  road(84,370,298,394)       -- the corridor west
  road(84,24,108,394)        -- up the lower hall, through the gate, to him
  -- the dragon seal before Lance: a gold sun of flames in a ring
  local cx,cz=96,40
  lib.ringH(Ef,cx,cz,.26,20,22,48,'lgGold',1)
  lib.ringH(Ef,cx,cz,.25,17,20,48,'lgCrimson',1)
  for k=0,15 do
   local a=k/16*pi*2
   local w=k%2==0 and .16 or .10
   local r=k%2==0 and 16.5 or 12
   Ef.quad({cx+cos(a-w)*7,.27,cz+sin(a-w)*7},{cx+cos(a)*r,.27,cz+sin(a)*r},{cx+cos(a+w)*7,.27,cz+sin(a+w)*7},{cx+cos(a-w)*7,.27,cz+sin(a-w)*7},'lgGold',1.05)
  end
  lib.fanH(Ef,cx,cz,.27,6.4,24,'lgLava',1.2)
  lib.ringH(Ef,cx,cz,.28,6.4,7.2,24,'lgGold',1)
 end)
 ---------------------------------------------------------------- parapets
 -- every rim cell carries a parapet of obsidian with a gold coping; tall
 -- columns with fire on them stand along the halls
 local Ep=C.part('parapets',nil,true)
 local function rim(cx,cy)return C.at(cx,cy)=='W'end
 for cy=0,C.ch-1 do for cx=0,C.cw-1 do
  if rim(cx,cy)then
   local x0,z0=cx*CS,cy*CS
   local m=5
   local a0,a1,b0,b1=x0+m,x0+CS-m,z0+m,z0+CS-m
   if rim(cx-1,cy)then a0=x0 end
   if rim(cx+1,cy)then a1=x0+CS end
   if rim(cx,cy-1)then b0=z0 end
   if rim(cx,cy+1)then b1=z0+CS end
   Ep.box(a0,0,b0,a1,9,b1,'lgObsidian',.95,{bottom=true})
   Ep.box(a0-.4,9,b0-.4,a1+.4,9.8,b1+.4,'lgObsidian',1,{bottom=true})
   Ep.decor(function()
    Ep.box(a0-.5,9.1,b0-.5,a1+.5,9.5,b1+.5,'lgGold',1,{top=true,bottom=true})
   end)
   Ep.decor(function()
    Ep.box(a0-.2,1.5,b0-.2,a1+.2,2.2,b1+.2,'lgGold',.9,{})
   end)
  end
 end end
 -- the columns of fire: on rim cells along the halls, every few cells
 local columns={}
 local function addColumn(cx,cy)columns[#columns+1]={cx*CS+8,cy*CS+8}end
 for cy=2,11,3 do addColumn(0,cy);addColumn(11,cy)end
 for cy=15,22,3 do addColumn(2,cy);addColumn(9,cy)end
 addColumn(16,16);addColumn(22,14);addColumn(22,19)
 addColumn(7,25);addColumn(13,25)
 for i,c in ipairs(columns)do
  local x,z=c[1],c[2]
  local h=58+rh(i,3,3)*10
  local Lc=K.model(Ep,x,0,z,0,1)
  Lc.box(-5.5,0,-5.5,5.5,11,5.5,'lgObsidian',1,{bottom=true})
  Lc.box(-6,11,-6,6,12.4,6,'lgGold',1,{bottom=true})
  Lc.frustum(0,12.4,0,3.4,h,2.9,10,'lgObsidian',false)
  Lc.decor(function()
   for _,yy in ipairs({16,h*.5,h-6})do Lc.frustum(0,yy,0,3.6,yy+1.2,3.6,10,'lgGold',false)end
  end)
  Lc.frustum(0,h,0,2.9,h+2,4.6,10,'lgGold',false)
  Lc.frustum(0,h+2,0,4.6,h+2.4,4.6,10,'lgGold',false)
  local yc=K.fireBowl(Lc,h+2.4,2.4,5.4,3.0)
  fx.fires[#fx.fires+1]={x=x,y=h+2.4+yc-(h+2.4)+.2,z=z,s=1.1,phase=i*1.37}
  C.addLight(x,h,z,70,.30)
 end
 ---------------------------------------------------------------- dragons
 local Ed=C.part('dragons',nil,true)
 local paired={}
 local statues={}
 for cy=0,C.ch-1 do for cx=0,C.cw-1 do
  if C.at(cx,cy)=='S'and not paired[cy*100+cx]and C.at(cx,cy+1)=='S'then
   paired[cy*100+cx]=true;paired[(cy+1)*100+cx]=true
   statues[#statues+1]={cx=cx,cy=cy}
  end
 end end
 for i,st in ipairs(statues)do
  local x,z=st.cx*CS+8,st.cy*CS+16
  -- which way: toward the hall's middle
  local yaw
  local shrine=st.cx>=18
  if shrine then yaw=st.cy<4 and 0 or pi
  else yaw=(st.cx<6)and pi/2 or -pi/2 end
  local big=(st.cy==0 and st.cx<12)
  local Lp=K.model(Ed,x,0,z,yaw,1)
  Lp.box(-15,0,-7,15,7,7,'lgObsidian',1,{bottom=true})
  Lp.box(-15.6,7,-7.6,15.6,8.2,7.6,'lgObsidian',1,{bottom=true})
  Lp.decor(function()Lp.box(-15.7,7.0,-7.7,15.7,7.5,7.7,'lgGold',1,{top=true,bottom=true})end)
  Lp.decor(function()
   Lp.box(-12,2,7,12,5.4,7.25,'lgGold',1,{})
   Lp.box(-11,2.6,7.25,11,4.8,7.4,'lgCrimson',1,{})
  end)
  dragon(Ed,K,F,lib,x,8.2,z,yaw,big and 1.65 or 1.0,i*7,fx)
 end
 ---------------------------------------------------------------- the dragon gate
 do
  local E=C.part('gate')
  local L=K.model(E,96,0,0,0,1)
  -- two great pylons either side of the way out, an arch, the crimson veil
  for _,sx in ipairs({-1,1})do
   local px=sx*27
   L.box(px-8,0,-14,px+8,78,-2,'lgObsidian',1,{bottom=true})
   L.box(px-9,0,-15,px+9,8,-1,'lgObsidian',.9,{bottom=true})
   L.box(px-9,8,-15,px+9,9.4,-1,'lgGold',1,{})
   L.decor(function()
    for _,yy in ipairs({24,46,66})do L.box(px-8.3,yy,-14.3,px+8.3,yy+1.4,-1.7,'lgGold',1,{})end
    -- dragon scales in relief up the pylon's face
    for row=0,9 do for col=0,2 do
     local cxp=px-5+col*5+(row%2)*2.5-1.2;local cy=12+row*5
     if cxp>px-7 and cxp<px+7 then
      L.quad({cxp-2,cy,-1.7},{cxp+2,cy,-1.7},{cxp,cy-3,-1.6},{cxp,cy-3,-1.6},'lgBronze',.9)
     end
    end end
   end)
   L.box(px-9.5,78,-15.5,px+9.5,81,-.5,'lgGold',1,{})
   local yc=K.fireBowl(K.model(E,96+px,0,-8,0,1),81,4,8,4)
   fx.fires[#fx.fires+1]={x=96+px,y=yc+.2,z=-8,s=1.9,phase=sx*2}
   C.addLight(96+px,80,-8,90,.4)
  end
  -- the arch over the way
  local cx,cy=0,52
  for i=0,15 do
   local a0,a1=i/16*pi,(i+1)/16*pi
   local r0,r1=19,26
   L.quad({cos(a0)*r1,cy+sin(a0)*r1*.9,-2},{cos(a1)*r1,cy+sin(a1)*r1*.9,-2},{cos(a1)*r0,cy+sin(a1)*r0*.9,-2},{cos(a0)*r0,cy+sin(a0)*r0*.9,-2},'lgObsidian',1)
   L.quad({cos(a0)*r0,cy+sin(a0)*r0*.9,-2},{cos(a1)*r0,cy+sin(a1)*r0*.9,-2},{cos(a1)*r0,cy+sin(a1)*r0*.9,-14},{cos(a0)*r0,cy+sin(a0)*r0*.9,-14},'lgObsidian',.7)
   L.decor(function()
    L.quad({cos(a0)*r1,cy+sin(a0)*r1*.9,-1.8},{cos(a1)*r1,cy+sin(a1)*r1*.9,-1.8},{cos(a1)*(r1-1.4),cy+sin(a1)*(r1-1.4)*.9,-1.8},{cos(a0)*(r1-1.4),cy+sin(a0)*(r1-1.4)*.9,-1.8},'lgGold',1)
   end)
  end
  L.box(-19,0,-14,-19+.1,cy,-2,'lgObsidian',.7,{})
  -- the veil: crimson fire in the opening (self-lit)
  for i=0,7 do
   local a0,a1=i/8*pi,(i+1)/8*pi
   L.quad({cos(a0)*19,cy+sin(a0)*17.1,-10},{cos(a1)*19,cy+sin(a1)*17.1,-10},{cos(a1)*19,0,-10},{cos(a0)*19,0,-10},'lgLava',.95)
  end
  L.quad({-19,0,-10},{19,0,-10},{19,cy,-10},{-19,cy,-10},'lgLava',.95)
  fx.glows[#fx.glows+1]={x=96,y=28,z=-6,r=40,col='red',a=.30}
  fx.portal={x=96,y=30,z=-8,w=38,h=68,col='red'}
  -- the dragon's head over the arch, gold, jaws open
  dragon(E,K,F,lib,96,cy+18,-10,0,1.2,99,fx)
  C.addLight(96,30,0,90,.45)
 end
 ---------------------------------------------------------------- the lock gate
 do
  -- a fixed arch over the gate cells; bars when the gate is shut
  local E=C.part('archway',nil,true)
  local L=K.model(E,96,0,200,0,1)
  for _,sx in ipairs({-1,1})do
   L.box(sx*18-3,0,-4,sx*18+3,42,4,'lgObsidian',1,{bottom=true})
   L.box(sx*18-3.6,42,-4.6,sx*18+3.6,44,4.6,'lgGold',1,{})
  end
  L.box(-21.6,44,-4.6,21.6,50,4.6,'lgObsidian',1,{})
  L.box(-22.2,50,-5.2,22.2,51.4,5.2,'lgGold',1,{})
  L.decor(function()C.K.inscription(L,'LANCE',0,45.4,4.6,1.0,'lgGold',26)end)
  -- the bars show once the gate has shut behind you (north of it)
  local Eb=C.part('bars',{behind=196})
  local Lb=K.model(Eb,96,0,200,0,1)
  for k=-7,7 do Lb.box(k*2.2-.45,0,-.45,k*2.2+.45,44,.45,'lgObsidian',1,{})end
  for _,yy in ipairs({6,24,40})do Lb.box(-15.5,yy,-.7,15.5,yy+1.4,.7,'lgObsidian',1,{})end
  for k=-7,7 do Lb.frustum(k*2.2,44,0,.5,47,0,4,'lgGold',false)end
 end
 ---------------------------------------------------------------- the stair you arrive by
 do
  local E=C.part('stair')
  local L=K.model(E,416,0,264,-pi/2,1)
  -- in the east rim: an arch, steps going down into the dark
  L.box(-14,0,-1,-8,40,6,'lgObsidian',1,{bottom=true})
  L.box(8,0,-1,14,40,6,'lgObsidian',1,{bottom=true})
  L.box(-15,40,-2,15,46,7,'lgObsidian',1,{})
  L.box(-15.6,46,-2.6,15.6,47.4,7.6,'lgGold',1,{})
  for k=0,6 do
   L.box(-8,-k*3,-k*4-4,8,-k*3+.01,-k*4,'lgObsidian',.7-k*.06,{})
  end
  L.quad({-8,-24,-30},{8,-24,-30},{8,40,-30},{-8,40,-30},'lgObsidian',.15)
 end
 ---------------------------------------------------------------- the lost shrine
 do
  local x,z=344,64
  local Ls=K.model(Ed,x,0,z,0,1)
  Ls.frustum(0,0,0,12,3,10,12,'lgObsidian')
  Ls.frustum(0,3,0,10,4,10.5,12,'lgGold')
  Ls.frustum(0,4,0,7,14,5,8,'lgObsidian')
  Ls.frustum(0,14,0,5.6,15,6.2,8,'lgGold')
  C.flat=true
  local Lx=K.model(Ed,x,0,z,0,1,1.5)
  local tip=lib.crystal(Lx,0,15,0,3.6,22,6,0,0,'lgLava',.3)
  C.flat=false
  fx.glows[#fx.glows+1]={x=x,y=28,z=z,r=26,col='red',a=.35}
  fx.fires[#fx.fires+1]={x=x,y=37,z=z,s=1.2,phase=3}
 end
 ---------------------------------------------------------------- effects
 for k=0,19 do
  fx.lava[#fx.lava+1]={x=-200+rh(k,1,1)*820,z=-200+rh(k,2,2)*820,r=60+rh(k,3,3)*80,phase=k*1.3}
 end
 fx.embers[#fx.embers+1]={x=208,y=ABYSS,z=208,r=420,n=90,rise=260,abyss=true}
 fx.lightning={x=208,z=208,r=700,y=420}
 fx.lavaLevel=ABYSS
end

return M
