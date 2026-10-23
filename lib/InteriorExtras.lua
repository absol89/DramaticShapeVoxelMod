-- TEST175: the last rooms (InteriorRooms):
--  * the CELADON MANSION ROOF: a roof terrace over the city -- deck boards,
--    a white parapet, the little penthouse with its red roof, lit windows
--    and flower boxes (the house the Eevee waits in), planters of flowers,
--    the two stair hatches, lanterns on the corners and festoon lights over
--    the terrace after dark (the city view beyond stays ScenicViews')
--  * the CABLE CLUB's TRADE CENTER and COLOSSEUM: a tech room in white and
--    blue, the ring inlaid in the floor in blue neon, the link table -- two
--    consoles facing for a trade, the battle console with its holographic
--    field for the Colosseum -- the club's screens and posters, the
--    pillars.
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

local AMBER,CYAN,WARM,VIOLET,ROSE,BLUE=2,3,4,5,7,8
local BULBS={AMBER,ROSE,CYAN,WARM,VIOLET,AMBER}

local function letter(L,str,x,y,z,scale,mat,shade,maxw)
 local P={box=function(a,b,c,d,e,f,m,t,skip)L.box(a,b,c,d,e,f,mat,shade,skip)end}
 pcall(LA().inscription,P,str,x,y,z,scale,mat,maxw)
end
-- a string of bulbs, sagging
local function festoon(C,L,a,b,sag,seed)
 local dx,dy,dz=b[1]-a[1],b[2]-a[2],b[3]-a[3]
 local n=max(3,floor(sqrt(dx*dx+dz*dz)/5))
 local function P(u)return{a[1]+dx*u,a[2]+dy*u-sag*4*u*(1-u),a[3]+dz*u}end
 local prev=P(0)
 for i=1,n do
  local p=P(i/n)
  L.quad({prev[1],prev[2],prev[3]},{p[1],p[2],p[3]},{p[1],p[2]-.2,p[3]},{prev[1],prev[2]-.2,prev[3]},'dark',.8)
  if i<n then
   local c=BULBS[(i+seed)%#BULBS+1]
   L.raw({p[1]-.6,p[2]-1.6,p[3]},{p[1]+.6,p[2]-1.6,p[3]},{p[1]+.6,p[2]-.3,p[3]},{p[1]-.6,p[2]-.3,p[3]},'dnNeon',c)
   L.raw({p[1],p[2]-1.6,p[3]-.6},{p[1],p[2]-1.6,p[3]+.6},{p[1],p[2]-.3,p[3]+.6},{p[1],p[2]-.3,p[3]-.6},'dnNeon',c)
  end
  prev=p
 end
end

------------------------------------------------------------------ the roof
function M.roof(C)
 local H=12;C.H=H
 C.ambient=.92;C.maxLight=1.3
 local W,D=C.cw*CS,C.ch*CS
 -- the penthouse stands on cells 1..3 x 4..7
 local function house(cx,cy)return cx>=1 and cx<=3 and cy>=4 and cy<=7 end
 local function solid(cx,cy)return C.is(cx,cy,'L')and not house(cx,cy)end
 local blocked=function(cx,cy)return house(cx,cy)or C.is(cx,cy,'LXT')end
 local S=K.shell(C,{H=H,solid=solid,blocked=blocked,door=function()return false end,
  paint='white',upper='white',rail='ktPearl',skirting='ktPearl',cornice='ktPearl',cap='ktPearl',
  floor='inOak',floorT=.95,ceiling=false,nofloor=function(cx,cy)return C.at(cx,cy)=='v'end,ao=6})
 local R=C.part('room')
 local function F(x,y,z,yaw)return K.frame(C,R,x,y,z,yaw)end
 -- the penthouse: cream walls, the red roof, the door and its lamp
 do
  local x0,x1,z0,z1=1*CS+.5,4*CS-.5,4*CS+.5,8*CS-.5
  local L=F(0,0,0,0)
  L.box(x0,0,z0,x1,30,z1,'ktPlaster',1)
  L.box(x0-.5,0,z0-.5,x1+.5,3,z1+.5,'ktBasalt',.9)
  -- the gable roof, ridge east-west
  local zm=(z0+z1)/2
  L.quad({x0-2,30,z0-2},{x1+2,30,z0-2},{x1+2,42,zm},{x0-2,42,zm},'red',.95)
  L.quad({x1+2,30,z1+2},{x0-2,30,z1+2},{x0-2,42,zm},{x1+2,42,zm},'red',1.05)
  L.quad({x0-2,30,z1+2},{x0-2,30,z0-2},{x0-2,42,zm},{x0-2,42,zm},'ktPlaster',.9)
  L.quad({x1+2,30,z0-2},{x1+2,30,z1+2},{x1+2,42,zm},{x1+2,42,zm},'ktPlaster',.9)
  L.box(x0-2.4,41.6,zm-1,x1+2.4,43,zm+1,'terra',1)
  L.box(x1-10,36,zm+2,x1-6,48,zm+6,'inBrick',1)
  -- the door (south, at the door cell) and the lamp beside it
  local dc=cellsOf(C,'d')[1]
  local dx=dc and dc[1]*CS+8 or(x0+x1)/2
  L.box(dx-5,0,z1,dx+5,22,z1+.6,'inWalnut',1)
  L.box(dx-6,22,z1,dx+6,23.4,z1+1.2,'white',1.05)
  L.box(dx+3,10,z1+.6,dx+3.8,11,z1+1.2,'lgGold',1.1)
  local Ll=F(dx+8,18,z1+1,0)
  Ll.box(-.8,0,-.4,.8,3,.6,'dark',.9)
  Ll.raw({-.6,.3,.65},{.6,.3,.65},{.6,2.7,.65},{-.6,2.7,.65},'dnNeon',WARM)
  C.fx.glows[#C.fx.glows+1]={x=dx+8,y=19.5,z=z1+2,r=6,col='warm',a=.25}
  -- windows lit warm, a flower box under each
  for _,wx in ipairs({x0+6,x1-6})do
   if abs(wx-dx)>9 then
    L.box(wx-4.6,11,z1,wx+4.6,22,z1+.5,'white',1.05)
    L.raw({wx-3.8,11.8,z1+.55},{wx+3.8,11.8,z1+.55},{wx+3.8,21.2,z1+.55},{wx-3.8,21.2,z1+.55},'inShoji',1)
    L.box(wx-4.8,8,z1,wx+4.8,10.6,z1+2.4,'inWalnut',.95)
    for k=0,4 do L.sphere(wx-3.6+k*1.8,11.2,z1+1.4,1.1,1,1.1,({'flower','gold','white','red','flower'})[k+1],5,2)end
   end
  end
  -- an aerial and the water tank on the ridge
  L.rod({x0+6,42,zm},{x0+6,56,zm},.25,'ktSteel')
  L.rod({x0+3,52,zm},{x0+9,52,zm},.2,'ktSteel');L.rod({x0+4,49,zm},{x0+8,49,zm},.2,'ktSteel')
 end
 -- the planters (X): raised boxes of flowers
 do
  local L=F(0,0,0,0)
  for _,g in ipairs(groups(C,'X'))do
   if not(g.x0<=3 and g.x1>=1 and g.y0==7)then
    local x0,x1,z0,z1=g.x0*CS+1,(g.x1+1)*CS-1,g.y0*CS+3,(g.y1+1)*CS-3
    L.box(x0,0,z0,x1,7,z1,'inOak',.95)
    L.box(x0-.4,7,z0-.4,x1+.4,7.8,z1+.4,'inWalnut',1)
    L.box(x0+.8,7.8,z0+.8,x1-.8,8.2,z1-.8,'forestFloor',.9)
    local n=floor((x1-x0)/3.2)
    for k=0,n-1 do
     local x=x0+2+k*3.2
     L.sphere(x,9.6,(z0+z1)/2+(rh(k,g.y0,1)-.5)*3,1.6,1.8,1.6,'lgLeaf',5,2)
     L.sphere(x+.4,11,(z0+z1)/2+(rh(k,g.y0,2)-.5)*3,.9,.8,.9,({'flower','gold','white','red','flower','blue'})[(k+g.y0)%6+1],5,2)
    end
   end
  end
 end
 -- the stair hatches
 for _,c in ipairs(cellsOf(C,'v'))do
  local x0,z0=c[1]*CS,c[2]*CS
  K.stairsDown(C,R,x0,x0+CS,z0,z0+CS,{tread='inOak',riser='ktPlaster',wall='ktPlaster',rail='white',handrail='white',nosing='ktPearl',railX=x0+.6})
 end
 -- the corner lanterns on the parapet and the lights across the terrace
 -- (on the parapet: the corners and the divider's ends)
 local posts={{14,14},{5*CS+8,14},{14,11*CS+8},{5*CS+8,9*CS+8},{7*CS+8,14},{7*CS+8,11*CS+8}}
 local L=F(0,0,0,0)
 for i,p in ipairs(posts)do
  L.rod({p[1],H,p[2]},{p[1],H+18,p[2]},.35,'dark')
  local Lt=F(p[1],H+18,p[2],0)
  Lt.box(-1.4,0,-1.4,1.4,.5,1.4,'dark',.9)
  Lt.raw({-1.1,.5,1.1},{1.1,.5,1.1},{1.1,3.6,1.1},{-1.1,3.6,1.1},'dnNeon',AMBER)
  Lt.raw({1.1,.5,-1.1},{-1.1,.5,-1.1},{-1.1,3.6,-1.1},{1.1,3.6,-1.1},'dnNeon',AMBER)
  Lt.raw({1.1,.5,1.1},{1.1,.5,-1.1},{1.1,3.6,-1.1},{1.1,3.6,1.1},'dnNeon',AMBER)
  Lt.raw({-1.1,.5,-1.1},{-1.1,.5,1.1},{-1.1,3.6,1.1},{-1.1,3.6,-1.1},'dnNeon',AMBER)
  Lt.box(-1.4,3.6,-1.4,1.4,4.2,1.4,'dark',.9)
  C.fx.glows[#C.fx.glows+1]={x=p[1],y=H+20,z=p[2],r=7,col='warm',a=.22}
 end
 festoon(C,L,{posts[1][1],H+17,posts[1][2]},{posts[4][1],H+17,posts[4][2]},5,1)
 festoon(C,L,{posts[2][1],H+17,posts[2][2]},{posts[3][1],H+17,posts[3][2]},5,4)
 festoon(C,L,{posts[5][1],H+17,posts[5][2]},{posts[6][1],H+17,posts[6][2]},6,7)
 C.fx.motes={x=W/2,z=D/2,y0=2,y1=30,r=60,n=20,col={1,.92,.5}}
 C.fx.ambience={wind=.20}
end

------------------------------------------------------------------ the club
function M.club(C)
 local colosseum=C.id=='COLOSSEUM'
 local H=48;C.H=H
 C.ambient=.82;C.maxLight=1.4
 local W,D=C.cw*CS,C.ch*CS
 local function solid(cx,cy)return cy==0 end
 local S=K.shell(C,{H=H,solid=solid,blocked=function(cx,cy)return C.is(cx,cy,'X')and cy>0 end,door=function()return false end,
  paint='ktPearl',upper='white',wainscot='blue',wainscotH=11,rail='white',skirting='navy',cornice='white',cap='ktPearl',
  floor='inTile',floorT=1.0,ceiling='white',
  style=function(L,len,run)L.box(0,24,0,len,26,.4,'blue',1.05)end,ao=8})
 local R=C.part('room')
 local function F(x,y,z,yaw)return K.frame(C,R,x,y,z,yaw)end
 -- the ring in the floor: blue neon round an octagon, white inside
 do
  local E=C.part('floor')
  local L=K.frame(C,E,W/2,.06,4.5*CS,0)
  local rx,rz=3.4*CS,2.6*CS
  for i=0,7 do
   local a0,a1=(i+.5)/8*pi*2,(i+1.5)/8*pi*2
   local p0,p1={cos(a0)*rx,sin(a0)*rz},{cos(a1)*rx,sin(a1)*rz}
   L.quad({p0[1],0,p0[2]},{p1[1],0,p1[2]},{p1[1]*.86,0,p1[2]*.86},{p0[1]*.86,0,p0[2]*.86},'white',1.1)
   L.raw({p0[1]*1.02,.01,p0[2]*1.02},{p1[1]*1.02,.01,p1[2]*1.02},{p1[1]*.99,.01,p1[2]*.99},{p0[1]*.99,.01,p0[2]*.99},'dnNeon',BLUE)
   L.raw({p0[1]*.86,.01,p0[2]*.86},{p1[1]*.86,.01,p1[2]*.86},{p1[1]*.83,.01,p1[2]*.83},{p0[1]*.83,.01,p0[2]*.83},'dnNeon',CYAN)
  end
  C.fx.glows[#C.fx.glows+1]={x=W/2,y=2,z=4.5*CS,r=40,col='cyan',a=.08}
 end
 -- the link table (X cells off the wall)
 local tx0,tx1,tz=math.huge,-math.huge,nil
 for _,c in ipairs(cellsOf(C,'X'))do if c[2]>0 then tx0=min(tx0,c[1]*CS);tx1=max(tx1,(c[1]+1)*CS);tz=c[2]*CS end end
 if tz then
  local L=F(0,0,0,0)
  L.box(tx0+1,0,tz+2,tx1-1,11,tz+14,'inEnamel',1)
  L.box(tx0,11,tz+1,tx1,12.4,tz+15,'blue',1.05)
  local cx=(tx0+tx1)/2
  if colosseum then
   -- the battle console: a ring of light, the field projected over it
   local Lc=F(cx,12.4,tz+8,0)
   Lc.cyl(0,0,1.4,0,7,7,'ktSteel',12)
   for i=0,11 do
    local a0,a1=i/12*pi*2,(i+1)/12*pi*2
    Lc.raw({cos(a0)*6.6,1.45,sin(a0)*6.6},{cos(a1)*6.6,1.45,sin(a1)*6.6},{cos(a1)*5.4,1.45,sin(a1)*5.4},{cos(a0)*5.4,1.45,sin(a0)*5.4},'dnNeon',CYAN)
   end
   Lc.raw({-4.4,1.5,-2.6},{4.4,1.5,-2.6},{4.4,1.5,2.6},{-4.4,1.5,2.6},'inScreen',3)
   C.fx.glows[#C.fx.glows+1]={x=cx,y=18,z=tz+8,r=12,col='cyan',a=.22}
   C.fx.sparkles={}
   for i=1,8 do local a=i/8*pi*2;C.fx.sparkles[i]={x=cx+cos(a)*5,y=16+rh(i,1,1)*4,z=tz+8+sin(a)*5,s=.5,phase=i*1.3,soft=false}end
  else
   -- two consoles facing over the table, the cable between them
   for _,s in ipairs({-1,1})do
    local Lm=F(cx+s*7,12.4,tz+8,s>0 and pi/2 or -pi/2)
    Lm.box(-4,0,-2,4,.6,2,'ktSteel',1)
    Lm.box(-4.6,.6,-1.4,4.6,7,-.6,'dark',.85)
    Lm.raw({-4,1.2,-.55},{4,1.2,-.55},{4,6.4,-.55},{-4,6.4,-.55},'inScreen',1+(s>0 and 1 or 0))
   end
   L.rod({cx-5,12.6,tz+10},{cx+5,12.6,tz+10},.25,'dark')
   C.fx.glows[#C.fx.glows+1]={x=cx,y=18,z=tz+8,r=10,col='cyan',a=.16}
  end
 end
 -- the north wall: the club's great screen, posters, the pillars
 local Ln=K.onWall(C,'N',0,0)
 Ln.box(W/2-28,22,0,W/2+28,42,1,'dark',.85)
 Ln.raw({W/2-26,23.5,1.05},{W/2+26,23.5,1.05},{W/2+26,40.5,1.05},{W/2-26,40.5,1.05},'inScreen',colosseum and 2 or 1)
 letter(Ln,colosseum and'COLOSSEUM'or'TRADE CENTER',W/2,43.4,1.05,.75,'dnNeon',BLUE,52)
 for _,x in ipairs({W*.16,W*.84})do
  K.picture(C,Ln,x-11,x+11,14,34,'pokemon',{frame='blue',mat=1})
 end
 for _,x in ipairs({CS-2,W-CS+2})do
  local Lp=F(x,0,CS-1,0)
  Lp.cyl(0,0,H,0,3,3,'white',10,false,0,'ktPearl')
  Lp.cyl(0,0,2,0,3.8,3.8,'blue',10)
  Lp.cyl(0,H-3,H,0,3.8,3.8,'blue',10)
 end
 -- panels overhead
 do
  local E=C.part('ceilfx',{below=H+2})
  local L=K.frame(C,E,0,0,0,0)
  for _,p in ipairs({{W*.3,D*.4},{W*.7,D*.4},{W*.3,D*.78},{W*.7,D*.78}})do
   L.raw({p[1]-12,H-.4,p[2]-6},{p[1]+12,H-.4,p[2]-6},{p[1]+12,H-.4,p[2]+6},{p[1]-12,H-.4,p[2]+6},'inPanel',1)
   C.addLight(p[1],H-8,p[2],80,.16)
  end
 end
 C.fx.ambience={hum=.14,room=.08}
end

return M
