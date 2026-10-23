-- TEST175: THE UNDERGROUND PATHS (InteriorRooms): the north-south tunnel
-- (Route 5 to Route 6), the west-east tunnel (Route 7 to Route 8) and the
-- four entrance halls.
-- A pedestrian subway: speckled terrazzo underfoot with a yellow guide line
-- and painted arrows, glazed white tile walls over a dark dado, a coloured
-- band (green west-east, blue north-south), steel ribs every few metres
-- with strip lights between them, framed travel posters of Kanto, the
-- route boards at each end, the stairs up to the halls lit green. The
-- entrance halls: the stairwell behind steel-and-glass barriers, the
-- UNDERGROUND PATH board over it, palms in the corners, the doors on the
-- day.
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

local GREEN,WARM=6,4
local SCENES={'mountain','sea','city','meadow','sunset','pagoda','ship','flowers','tree','night'}

local function runFrame(C,run)
 local ox,oz,yaw
 if run.o=='S'then ox,oz,yaw=run.a0,run.c,0
 elseif run.o=='N'then ox,oz,yaw=run.a1,run.c,pi
 elseif run.o=='E'then ox,oz,yaw=run.c,run.a1,pi/2
 else ox,oz,yaw=run.c,run.a0,-pi/2 end
 return K.frame(C,run.E,ox,0,oz,yaw)
end
-- lettering in a given finish (the inscription kit draws boxes)
local function letter(L,str,x,y,z,scale,mat,shade,maxw)
 local P={box=function(a,b,c,d,e,f,m,t,skip)L.box(a,b,c,d,e,f,mat,shade,skip)end}
 pcall(LA().inscription,P,str,x,y,z,scale,mat,maxw)
end

------------------------------------------------------------------ the tunnels
function M.tunnel(C)
 local ns=C.id:find('NORTH_SOUTH')~=nil
 local H=44;C.H=H
 C.ambient=.62;C.maxLight=1.4
 local W,D=C.cw*CS,C.ch*CS
 local band=ns and'blue'or'leaf'
 local lamps={}
 local function solid(cx,cy)return C.is(cx,cy,'WV')end
 local S=K.shell(C,{H=H,solid=solid,blocked=function(cx,cy)return solid(cx,cy)end,door=function()return false end,
  paint='inTile',upper='inTile',wainscot='navy',wainscotH=12,rail=band,skirting='dark',cornice='white',cap='ktBasalt',
  floor='inTerrazzo',floorT=.95,ceiling=false,
  style=function(L,len,run)
   local Lf=runFrame(C,run)
   -- the route's colour band, a second fine line
   Lf.box(0,26,0,len,29,.5,band,1.05)
   Lf.box(0,30,0,len,30.6,.4,band,1)
   -- steel ribs, a strip light between each pair, posters on the long walls
   local step=64
   local seen=run.o~='N'
   local x=24
   local i=0
   while x<len-8 do
    Lf.box(x-2,0,0,x+2,H,1.6,'ktSteel',.95)
    Lf.box(x-2.6,0,0,x+2.6,2,2.2,'dark',.8)
    local mx=x+step/2
    if mx<len-16 then
     Lf.box(mx-12,H-7,0,mx+12,H-4.6,1.8,'ktSteel',1)
     Lf.raw({mx-11,H-7.05,.4},{mx+11,H-7.05,.4},{mx+11,H-7.05,1.6},{mx-11,H-7.05,1.6},'inPanel',1)
     Lf.raw({mx-11,H-6.6,1.85},{mx+11,H-6.6,1.85},{mx+11,H-5,1.85},{mx-11,H-5,1.85},'inPanel',1)
     local p=Lf.P({mx,H-10,8})
     local far=true
     for _,q in ipairs(lamps)do if(q[1]-p[1])^2+(q[3]-p[3])^2<56*56 then far=false;break end end
     if far then lamps[#lamps+1]=p;C.addLight(p[1],p[2],p[3],80,.26)end
     if seen and rh(run.a0+x,run.c,1)<.7 then
      K.picture(C,Lf,mx-10,mx+10,13,25,SCENES[(floor(x/step)+floor(run.c/16))%#SCENES+1],{frame='ktSteel',mat=1})
     end
    end
    x=x+step;i=i+1
   end
  end,ao=8})
 local R=C.part('room')
 local function F(x,y,z,yaw)return K.frame(C,R,x,y,z,yaw)end
 -- the floor: a yellow guide line down the middle, arrows, the tactile
 -- strip along the wall where the source has it
 do
  local E=C.part('floor')
  local L=K.frame(C,E,0,.06,0,0)
  local a0,a1,b0,b1=math.huge,-math.huge,math.huge,-math.huge
  for cy=0,C.ch-1 do for cx=0,C.cw-1 do
   if C.is(cx,cy,'.^')then a0=min(a0,cx);a1=max(a1,cx);b0=min(b0,cy);b1=max(b1,cy)end
   if C.raw(cx,cy)==6 then
    local x0,z0=cx*CS,cy*CS
    L.quad({x0+3,0,z0},{x0+9,0,z0},{x0+9,0,z0+CS},{x0+3,0,z0+CS},'gold',.95)
    for k=0,3 do L.quad({x0+4,.01,z0+1.5+k*4},{x0+8,.01,z0+1.5+k*4},{x0+8,.01,z0+2.5+k*4},{x0+4,.01,z0+2.5+k*4},'ktSandstone',.9)end
   end
  end end
  if ns then
   local x=(a0+a1+1)*CS/2
   L.quad({x-.6,0,b0*CS+20},{x+.6,0,b0*CS+20},{x+.6,0,(b1+1)*CS-20},{x-.6,0,(b1+1)*CS-20},'gold',1)
   for z=b0*CS+64,(b1+1)*CS-64,128 do
    for _,d in ipairs({-1,1})do
     local xx=x+d*14
     L.quad({xx-3,.01,z-d*3},{xx+3,.01,z-d*3},{xx,.01,z+d*3},{xx,.01,z+d*3},'white',1)
    end
   end
  else
   local z=(b0+b1+1)*CS/2
   L.quad({a0*CS+20,0,z-.6},{(a1+1)*CS-20,0,z-.6},{(a1+1)*CS-20,0,z+.6},{a0*CS+20,0,z+.6},'gold',1)
   for x=a0*CS+64,(a1+1)*CS-64,128 do
    for _,d in ipairs({-1,1})do
     local zz=z+d*14
     L.quad({x-d*3,.01,zz-3},{x-d*3,.01,zz+3},{x+d*3,.01,zz},{x+d*3,.01,zz},'white',1)
    end
   end
  end
 end
 -- the stairs up to the halls: a flight rising toward the nearer end
 -- wall, steel rails, the green EXIT light over it
 local stairs=cellsOf(C,'^')
 for _,c in ipairs(stairs)do
  local x0,z0=c[1]*CS,c[2]*CS
  -- which way the flight climbs: to the solid side
  local dx,dz=0,0
  if ns then dz=(c[2]<C.ch/2)and -1 or 1 else dx=(c[1]<C.cw/2)and -1 or 1 end
  local yaw=dx==1 and 0 or dx==-1 and pi or dz==-1 and pi/2 or -pi/2
  local L=F(x0+8,0,z0+8,yaw)
  -- (local +x climbs)
  for k=0,4 do
   local a=-8+k*3.2
   L.box(a,0,-7.4,a+3.2,(k+1)*3,7.4,'inTerrazzo',.95)
   L.box(a-.2,(k+1)*3-.4,-7.6,a+3.2,(k+1)*3,7.6,'gold',1)
  end
  for _,s in ipairs({-7.8,7.8})do
   L.rod({-8,10,s},{8,25,s},.35,'ktSteel')
   L.box(-8.4,0,s-.4,-7.6,10,s+.4,'ktSteel',1)
  end
  -- the opening above the flight, dark
  L.quad({8,15,-8},{8,15,8},{8,40,8},{8,40,-8},'dark',.3)
  L.box(5,40,-6,8,43,6,'dark',.8)
  L.raw({4.9,40.6,-4.6},{4.9,40.6,4.6},{4.9,42.4,4.6},{4.9,42.4,-4.6},'dnNeon',GREEN)
  local p=L.P({4,38,0});C.fx.glows[#C.fx.glows+1]={x=p[1],y=p[2],z=p[3],r=8,col='green',a=.18}
  C.addLight(p[1],30,p[3],70,.22)
 end
 -- the route boards at each end (on the walls the eye sees)
 do
  local names=ns and{'ROUTE 5','ROUTE 6'}or{'ROUTE 7','ROUTE 8'}
  if ns then
   for i,cy in ipairs({4,C.ch-8})do
    local Lw=K.onWall(C,'W',0,0)
    local u=S.s-(cy*CS+8)
    Lw.box(u-18,30,0,u+18,40,1,'navy',1)
    letter(Lw,names[i],u,32,1.05,1.4,'white',1.1,32)
   end
  else
   local Ln=K.onWall(C,'N',0,0)
   for i,x in ipairs({6*CS,C.cw*CS-6*CS})do
    local u=x-S.w
    Ln.box(u-20,31,0,u+20,41,1,'navy',1)
    letter(Ln,names[i],u,33,1.05,1.4,'white',1.1,36)
   end
  end
 end
 C.addLight(W/2,40,D/2,900,.05)
 C.fx.ambience={hall=.20,hum=.08}
end

------------------------------------------------------------------ the halls
function M.hall(C)
 local H=48;C.H=H
 C.ambient=.80;C.maxLight=1.4
 local W,D=C.cw*CS,C.ch*CS
 local route=tonumber(C.id:match('ROUTE_(%d)'))or 5
 local band=(route==7 or route==8)and'leaf'or'blue'
 local function solid(cx,cy)return C.is(cx,cy,'W')end
 local blocked=function(cx,cy)local c=C.at(cx,cy);return c~=nil and not('.mv'):find(c,1,true)end
 local S=K.shell(C,{H=H,solid=solid,blocked=blocked,
  door=function(cx,cy,ox,oy)
   if not ox then return false end
   local off=cx<0 or cy<0 or cx>=C.cw or cy>=C.ch
   return off and oy==C.ch-1 and C.is(ox,oy,'m.')and C.is(ox,oy,'m')
  end,
  paint='inTile',upper='white',wainscot='navy',wainscotH=12,rail=band,skirting='dark',cornice='white',cap='ktLime',
  floor='inTerrazzo',ceiling='white',nofloor=function(cx,cy)return C.at(cx,cy)=='v'end,
  style=function(L,len,run)
   local Lf=runFrame(C,run)
   Lf.box(0,26,0,len,29,.5,band,1.05)
  end,ao=9})
 local R=C.part('room')
 local function F(x,y,z,yaw)return K.frame(C,R,x,y,z,yaw)end
 -- the barriers round the stairwell (C): steel posts, glass, a rail
 do
  local L=F(0,0,0,0)
  for _,c in ipairs(cellsOf(C,'C'))do
   local x0,z0=c[1]*CS,c[2]*CS
   local function bar(ax,az,bx,bz)
    L.box(min(ax,bx)-.5,0,min(az,bz)-.5,max(ax,bx)+.5,1.6,max(az,bz)+.5,'ktSteel',.95)
    L.quad({ax,1.6,az},{bx,1.6,bz},{bx,13,bz},{ax,13,az},'ktGlass',1.15)
    L.quad({bx,1.6,bz},{ax,1.6,az},{ax,13,az},{bx,13,bz},'ktGlass',1.0)
    L.box(min(ax,bx)-.6,13,min(az,bz)-.6,max(ax,bx)+.6,14.2,max(az,bz)+.6,'inSteel',1.08)
   end
   local n,s,w,e=C.is(c[1],c[2]-1,'C'),C.is(c[1],c[2]+1,'C'),C.is(c[1]-1,c[2],'C'),C.is(c[1]+1,c[2],'C')
   local cx,cz=x0+8,z0+8
   if w or e then bar(w and x0 or cx,cz,e and x0+CS or cx,cz)end
   if n or s then bar(cx,n and z0 or cz,cx,s and z0+CS or cz)end
   L.box(cx-1,0,cz-1,cx+1,15,cz+1,'ktSteel',1)
  end
 end
 -- the stairwell
 for _,c in ipairs(cellsOf(C,'v'))do
  local x0,z0=c[1]*CS,c[2]*CS
  K.stairsDown(C,R,x0,x0+CS,z0,z0+CS,{tread='inTerrazzo',riser='inTile',wall='inTile',rail='inSteel',handrail='inSteel',nosing='gold',railX=x0+.6})
 end
 -- the palms in the corners (one per pair of cells)
 for _,c in ipairs(cellsOf(C,'P'))do
  if not C.is(c[1],c[2]-1,'P')then
   K.plant(F(c[1]*CS+8,0,c[2]*CS+16,0),'palm',{s=1.2,pot='inEnamel',seed=c[1]*5+c[2]})
  end
 end
 -- the board over the stairs: UNDERGROUND PATH, the arrow down
 -- (on the wall's face behind the corner palms: the shell's north line
 -- runs in front of it)
 local zN=CS
 for cy=0,C.ch-1 do if C.is(floor(C.cw/2),cy,'W')then zN=(cy+1)*CS end end
 local Ln=K.frame(C,C.part('decor:board',{axis='z',c=zN,s=1}),0,0,zN,0)
 local cx=W/2
 Ln.box(cx-34,30,0,cx+34,42,1,'navy',1)
 letter(Ln,'UNDERGROUND PATH',cx,33.2,1.05,1.0,'white',1.12,62)
 Ln.box(cx-30,24,0,cx+30,28,1,band,1.05)
 letter(Ln,'ROUTE '..route,cx,24.6,1.05,.6,'white',1.1,20)
 -- the doors on the day
 local x0,x1
 for cx2=0,C.cw-1 do if C.is(cx2,C.ch-1,'m')then x0=x0 and min(x0,cx2)or cx2;x1=x1 and max(x1,cx2)or cx2 end end
 if x0 then
  K.exitPortal(C,'S',x0*CS,(x1+1)*CS,{view=3,frame='inSteel',glassDoors=true})
  K.rug(C,C.part('floor'),x0*CS+2,D-28,(x1+1)*CS-2,D-2,{field='dark',border=band,bw=1,y=.1})
 end
 -- light panels overhead
 do
  local E=C.part('ceilfx',{below=H+2})
  local L=K.frame(C,E,0,0,0,0)
  for _,p in ipairs({{W*.3,D*.35},{W*.7,D*.35},{W*.3,D*.72},{W*.7,D*.72}})do
   L.raw({p[1]-10,H-.4,p[2]-6},{p[1]+10,H-.4,p[2]-6},{p[1]+10,H-.4,p[2]+6},{p[1]-10,H-.4,p[2]+6},'inPanel',1)
   C.addLight(p[1],H-8,p[2],70,.16)
  end
 end
 C.fx.ambience={hall=.16}
end

return M
