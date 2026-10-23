-- TEST173: the town rooms (InteriorRooms): the Pokemon Centers, the Marts,
-- the Celadon Hotel lobby and every town's houses. Each town furnishes its
-- rooms in its own way (THEMES), and every house has its own character
-- (HOUSES) on the one floor plan the game gives most of them.
local V=...
local M={}
local K=V.require('InteriorKit')
local pi,cos,sin,floor,min,max,abs,sqrt=math.pi,math.cos,math.sin,math.floor,math.min,math.max,math.abs,math.sqrt
local rh=K.rh
local CS=16

------------------------------------------------------------------ themes
-- paint/upper/wainscot: the walls; floor; wood: the furniture; cloth:
-- curtains; rug: field/border; view: what the windows look out on
-- (1 garden, 2 sea, 3 city, 4 mountains, 5 forest); plants; pot; accent.
local THEMES={
 PALLET={paint='inPaperRose',wainscot='white',bead=true,rail='white',floor='inPine',wood='inOak',
  cloth='white',curtain='lace',rug={'inRugBlue','white'},view=1,plants={'flowers','fern'},pot='ktTerracotta',
  accent='blue',ceiling='white',cornice='white'},
 VIRIDIAN={paint='ktSage',wainscot='inOak',bead=true,rail='inWalnut',floor='inOak',wood='inWalnut',
  cloth='ktSage',curtain='drape',rug={'inRugGreen','inRugGold'},view=5,plants={'fern','ficus'},pot='ktTerracotta',
  accent='green',ceiling='ktLime',cornice='inOak'},
 PEWTER={paint='ktLime',wainscot='lvStone',rail='inWalnut',floor='inStone',wood='inWalnut',
  cloth='ktOchre',curtain='drape',rug={'inRugRed','inRugGold'},view=4,plants={'cactus','snake'},pot='ktBasalt',
  accent='ktOchre',ceiling='ktLime',cornice='inWalnut',beams=true},
 CERULEAN={paint='inPaperBlue',wainscot='white',bead=true,rail='white',floor='inPine',wood='white',
  cloth='white',curtain='cafe',rug={'inRugBlue','white'},view=2,plants={'fern','monstera'},pot='ktCopper',
  accent='ktCopper',ceiling='white',cornice='white'},
 VERMILION={paint='cream',wainscot='inWalnut',rail='lgBronze',floor='inOak',wood='inWalnut',
  cloth='navy',curtain='drape',rug={'inRugBlue','inRugRed'},view=2,plants={'palm','fern'},pot='white',
  accent='navy',ceiling='white',cornice='inWalnut'},
 LAVENDER={paint='lvMauve',wainscot='lvTimber',rail='lvWalnut',floor='inWalnut',wood='lvWalnut',
  cloth='lgPlum',curtain='drape',rug={'lgPlum','inRugGold'},view=4,plants={'orchid','fern'},pot='lvSlate',
  accent='lgPlum',ceiling='lvPlaster',cornice='lvTimber',dim=true},
 CELADON={paint='inPaperSage',wainscot='inOak',rail='lgGold',floor='inParquet',wood='inOak',
  cloth='flower',curtain='drape',rug={'inRugGold','inRugRed'},view=3,plants={'flowers','ficus'},pot='white',
  accent='flower',ceiling='white',cornice='white'},
 SAFFRON={paint='white',upper='ktPearl',rail='inSteel',floor='inTerrazzo',wood='dark',
  cloth='ktPearl',curtain='blind',rug={'inRugBlue','dark'},view=3,plants={'snake','monstera'},pot='inEnamel',
  accent='inSteel',ceiling='white',cornice='white',modern=true},
 FUCHSIA={paint='cream',wainscot='inWalnut',rail='inWalnut',floor='inTatami',wood='inWalnut',
  cloth='inShoji',curtain=nil,rug={'inRugRed','inRugGold'},view=1,plants={'bonsai','bamboo'},pot='ktBasalt',
  accent='red',ceiling='inPine',cornice='inWalnut',japan=true},
 CINNABAR={paint='ktOchre',wainscot='ktTerracotta',rail='inOak',floor='inTile',wood='inOak',
  cloth='ktOchre',curtain='valance',rug={'inRugRed','inRugGold'},view=2,plants={'palm','cactus'},pot='ktTerracotta',
  accent='red',ceiling='white',cornice='white'},
 MTMOON={paint='ktLime',wainscot='lvStone',rail='inWalnut',floor='inStone',wood='inWalnut',
  cloth='navy',curtain='drape',rug={'inRugBlue','inRugGold'},view=4,plants={'fern','snake'},pot='ktBasalt',
  accent='navy',ceiling='ktLime',cornice='inWalnut',beams=true},
 ROCKTUNNEL={paint='ktSandstone',wainscot='lvStone',rail='inWalnut',floor='inStone',wood='inWalnut',
  cloth='ktOchre',curtain='drape',rug={'inRugRed','inRugGold'},view=4,plants={'cactus','fern'},pot='ktBasalt',
  accent='ktOchre',ceiling='ktLime',cornice='inWalnut',beams=true},
 ROUTE2={paint='inPine',wainscot='inWalnut',rail='inWalnut',floor='inOak',wood='inWalnut',
  cloth='inRugRed',curtain='cafe',rug={'inRugRed','inRugGreen'},view=5,plants={'fern','tree'},pot='ktTerracotta',
  accent='red',ceiling='inPine',cornice='inWalnut',beams=true},
 ROUTE5={paint='ktPearl',wainscot='white',bead=true,rail='white',floor='inPine',wood='inOak',
  cloth='gold',curtain='valance',rug={'inRugBlue','inRugGold'},view=1,plants={'flowers','fern'},pot='white',
  accent='gold',ceiling='white',cornice='white'},
 ROUTE12={paint='inPine',wainscot='ktMarine',rail='white',floor='inOak',wood='inOak',
  cloth='white',curtain='cafe',rug={'inRugBlue','white'},view=2,plants={'fern','snake'},pot='ktCopper',
  accent='ktMarine',ceiling='inPine',cornice='white',beams=true},
 ROUTE16={paint='ktSage',wainscot='inPine',rail='inOak',floor='inOak',wood='inOak',
  cloth='ktOchre',curtain='lace',rug={'inRugGreen','inRugGold'},view=5,plants={'tree','fern'},pot='ktTerracotta',
  accent='ktOchre',ceiling='ktLime',cornice='inOak'},
}
M.THEMES=THEMES
local function theme(city)return THEMES[city]or THEMES.PALLET end
M.theme=theme

------------------------------------------------------------------ helpers
-- solid cells for a room whose top row is the wall band
local function topWall(C)
 return function(cx,cy)
  if cy<=0 then return true end
  local c=C.at(cx,cy);return c=='W'or c=='V'
 end
end
local function blocked(C)
 return function(cx,cy)
  local c=C.at(cx,cy)
  return c~=nil and c~='.'and c~='m'and c~='s'and c~='f'and c~='t'and c~='c'and c~='^'and c~='v'
 end
end
-- the bounds of the cells of one character (or a list of runs)
local function cellsOf(C,ch)
 local out={}
 for cy=0,C.ch-1 do for cx=0,C.cw-1 do if C.at(cx,cy)==ch then out[#out+1]={cx,cy}end end end
 return out
end
-- group cells of `set` into connected blocks (4-connected)
local function groups(C,set)
 local seen,out={},{}
 for cy=0,C.ch-1 do for cx=0,C.cw-1 do
  local k=cy*C.cw+cx
  if not seen[k]and C.is(cx,cy,set)then
   local g={x0=cx,x1=cx,y0=cy,y1=cy,cells={}}
   local q={{cx,cy}};seen[k]=true
   while #q>0 do
    local c=table.remove(q);g.cells[#g.cells+1]=c
    g.x0,g.x1,g.y0,g.y1=min(g.x0,c[1]),max(g.x1,c[1]),min(g.y0,c[2]),max(g.y1,c[2])
    for _,d in ipairs({{1,0},{-1,0},{0,1},{0,-1}})do
     local nx,ny=c[1]+d[1],c[2]+d[2];local nk=ny*C.cw+nx
     if nx>=0 and ny>=0 and nx<C.cw and ny<C.ch and not seen[nk]and C.is(nx,ny,set)then seen[nk]=true;q[#q+1]={nx,ny}end
    end
   end
   g.cx=(g.x0+g.x1+1)*CS/2;g.cz=(g.y0+g.y1+1)*CS/2
   out[#out+1]=g
  end
 end end
 return out
end
M.groups=groups;M.cellsOf=cellsOf;M.topWall=topWall;M.blocked=blocked
-- exit mats in the bottom row: the front door's span
-- TEST180: every run of door mats on the south row (the Museum and the
-- Celadon Mart have two front doors; they were one 128-wide opening)
local function doorSpans(C)
 local out={};local x0
 for cx=0,C.cw do
  local m=cx<C.cw and C.at(cx,C.ch-1)=='m'
  if m and not x0 then x0=cx elseif not m and x0 then out[#out+1]={x0*CS,cx*CS};x0=nil end
 end
 return out
end
M.doorSpans=doorSpans
local function doorSpan(C)
 local s=doorSpans(C)[1]
 if s then return s[1],s[2]end
end
M.doorSpan=doorSpan
-- the front door cells cut the south wall
local function doorFn(C,set)
 set=set or'm'
 -- the solid cell (cx,cy) is cut where the open cell in front is an exit
 -- and the solid one is off the map (the building's outer wall)
 return function(cx,cy,ox,oy)
  if not ox then return false end
  local off=cx<0 or cy<0 or cx>=C.cw or cy>=C.ch
  return off and C.is(ox,oy,set)
 end
end
M.doorFn=doorFn

------------------------------------------------------------------ lights
-- a room lit from above: ceiling lights over a grid, a little window light
local function ceilingLights(C,H,step,k,x0,x1,z0,z1)
 for x=x0+step/2,x1-step/2+.1,step do for z=z0+step/2,z1-step/2+.1,step do
  C.addLight(x,H-6,z,step*1.15,k)
 end end
end
M.ceilingLights=ceilingLights

------------------------------------------------------------------ the man
-- A gentleman resting on the lounge couch (the Center's tile art draws one
-- there): a low-poly figure seated facing east, his hat on his knee.
local function sitter(L,seat,o)
 o=o or{}
 local coat,trou,skin,hair=o.coat or'navy',o.trousers or'lvSlate',o.skin or'ktOchre',o.hair or'dark'
 -- thighs forward (+z), shins down, shoes
 L.box(-2.2,seat,-1.6,-.4,seat+2,4.2,trou,1.0)
 L.box(.4,seat,-1.6,2.2,seat+2,4.2,trou,1.0)
 L.box(-2.1,.8,3.4,-.5,seat+.2,5.0,trou,.95)
 L.box(.5,.8,3.4,2.1,seat+.2,5.0,trou,.95)
 L.box(-2.3,0,3.2,-.3,1.0,6.4,'dark',.9);L.box(.3,0,3.2,2.3,1.0,6.4,'dark',.9)
 -- torso, arms resting on the thighs
 L.box(-2.8,seat+1.4,-2.4,2.8,seat+9.4,1.2,coat,1.0)
 L.box(-3.6,seat+4,-1.8,-2.6,seat+9,1.0,coat,.95);L.box(2.6,seat+4,-1.8,3.6,seat+9,1.0,coat,.95)
 L.box(-3.4,seat+2.2,0,-2.4,seat+4.4,3.2,coat,.95);L.box(2.4,seat+2.2,0,3.4,seat+4.4,3.2,coat,.95)
 L.box(-.9,seat+7.6,1.2,.9,seat+9.4,1.4,'white',1.1)                   -- collar
 L.box(-.3,seat+5,1.2,.3,seat+9,1.5,'red',1.0)                           -- tie
 -- head and hair
 L.box(-.8,seat+9.4,-.8,.8,seat+10.4,.8,skin,1.0)
 L.sphere(0,seat+12.2,0,2.1,2.4,2.1,skin,8,5)
 L.sphere(0,seat+13.2,-.5,2.25,1.7,2.15,hair,8,4)
 L.box(-.9,seat+12.2,1.9,-.4,seat+12.8,2.1,'dark',1);L.box(.4,seat+12.2,1.9,.9,seat+12.8,2.1,'dark',1)
 -- his hat on his knee
 L.cyl(1.4,seat+2,seat+2.3,3.4,2.2,2.2,'dark',10)
 L.cyl(1.4,seat+2.3,seat+4,3.4,1.5,1.4,'dark',10)
end
M.sitter=sitter

------------------------------------------------------------------ CENTER
-- The Pokemon Center lobby (all eleven share the plan): the nurse's long
-- counter under the Poke Ball emblem, two healing consoles, the Cable Club
-- desk, the PC kiosk, the lounge couch, planters; every town's own touches.
local CENTER_ART={
 VIRIDIAN={'tree','meadow'},PEWTER={'fossil','mountain'},CERULEAN={'sea','fish'},MTMOON={'night','mountain'},
 ROCKTUNNEL={'mountain','night'},VERMILION={'ship','sea'},LAVENDER={'night','flowers'},CELADON={'flowers','city'},
 SAFFRON={'city','abstract'},FUCHSIA={'pagoda','tree'},CINNABAR={'sunset','sea'},
}
function M.center(C)
 local T=theme(C.city)
 local H=60;C.H=H
 C.ambient=.80;C.maxLight=1.45
 local solid=topWall(C)
 local W,D=C.cw*CS,C.ch*CS
 local S=K.shell(C,{H=H,solid=solid,blocked=blocked(C),door=doorFn(C),
  paint=T.modern and'white'or'ktPlaster',upper=T.modern and'ktPearl'or'white',wainscot='inEnamel',wainscotH=16,
  rail='red',skirting='red',cornice='white',cap='ktLime',floor=C.city=='FUCHSIA'and'inTile'or'inTile',ceiling='white',
  style=function(L,len,run)
   -- the Center's red band at shoulder height
   L.box(0,22,0,len,24.4,.5,'inLacquer',1.0)
   L.box(0,24.4,0,len,25,.6,'white',1.1)
  end})
 local R=C.part('room')
 local function F(x,y,z,yaw)return K.frame(C,R,x,y,z,yaw)end
 -- floor inlay: a great Poke Ball in the middle of the lobby
 do
  local E=C.part('inlay')
  local cx,cz=W*.5+8,D*.56
  local r=21
  local n=40
  for i=0,n-1 do local a0,a1=i/n*pi*2,(i+1)/n*pi*2
   local top=sin((a0+a1)/2)<0
   E.quad({cx,.06,cz},{cx+cos(a1)*r,.06,cz+sin(a1)*r},{cx+cos(a0)*r,.06,cz+sin(a0)*r},{cx,.06,cz},top and'inLacquer'or'inEnamel',1)
   E.quad({cx+cos(a0)*r,.07,cz+sin(a0)*r},{cx+cos(a1)*r,.07,cz+sin(a1)*r},{cx+cos(a1)*(r+1.6),.07,cz+sin(a1)*(r+1.6)},{cx+cos(a0)*(r+1.6),.07,cz+sin(a0)*(r+1.6)},'dark',1)
  end
  E.quad({cx-r,.08,cz-1},{cx+r,.08,cz-1},{cx+r,.08,cz+1},{cx-r,.08,cz+1},'dark',1)
  for layer,rr in ipairs({{6.5,'dark'},{5,'inEnamel'},{3,'ktPearl'}})do
   local y=.10+(layer-1)*.015
   for i=0,19 do local a0,a1=i/20*pi*2,(i+1)/20*pi*2
    E.quad({cx,y,cz},{cx+cos(a1)*rr[1],y,cz+sin(a1)*rr[1]},{cx+cos(a0)*rr[1],y,cz+sin(a0)*rr[1]},{cx,y,cz},rr[2],1)end
  end
 end
 -- the pillars (I): red-and-white columns from the floor to the cornice,
 -- running through the counter
 for _,g in ipairs(groups(C,'I'))do
  local x=g.cx
  local L=F(x,0,24,0)
  L.box(-6,0,-8,6,H-2.4,8,'inEnamel',1.0)
  L.box(-6.6,0,-8.6,6.6,3,8.6,'inLacquer',1.0)
  L.box(-6.6,H-6,-8.6,6.6,H-2.4,8.6,'inLacquer',1.0)
  L.box(-6.4,22,-8.4,6.4,25,8.4,'inLacquer',1.0)
  for _,sx in ipairs({-1,1})do L.box(sx*6-.3,3,-8.2,sx*6+.3,H-6,8.2,'white',1.1)end
  L.box(-6.6,0,8,6.6,15,22.6,'inEnamel',1.02)         -- the counter's end block
  L.box(-7,15,7.6,7,16.4,23,'inLacquer',1.05)
 end
 -- the posters (p): the Center's Poke Ball emblem over the nurse
 do
  local ps=cellsOf(C,'p')
  if #ps>0 then
   local x0,x1=ps[1][1]*CS,(ps[#ps][1]+1)*CS
   local Lw=K.onWall(C,'N',0,0)
   local cx=(x0+x1)/2
   Lw.box(cx-15,30,0,cx+15,52,.8,'inEnamel',1.05)
   Lw.box(cx-15.6,29.4,-.1,cx+15.6,30,1.2,'inLacquer',1)
   Lw.box(cx-15.6,52,-.1,cx+15.6,52.6,1.2,'inLacquer',1)
   local y=41;local r=8.4
   for i=0,23 do local a0,a1=i/24*pi*2,(i+1)/24*pi*2
    local top=sin((a0+a1)/2)>0
    Lw.quad({cx,y,1},{cx+cos(a0)*r,y+sin(a0)*r,1},{cx+cos(a1)*r,y+sin(a1)*r,1},{cx,y,1},top and'inLacquer'or'inEnamel',1.05)
   end
   Lw.ring(cx,y,1.1,r,r+.9,'dark',24,1)
   Lw.box(cx-r,y-.5,1.1,cx+r,y+.5,1.2,'dark',1)
   Lw.disc(cx,y,1.3,2.6,'dark',14);Lw.disc(cx,y,1.4,1.8,'inEnamel',14,nil,1.1)
   -- a cross for the healing, either side
   for _,sx in ipairs({-11.2,11.2})do
    Lw.box(cx+sx-.9,y-3,1,cx+sx+.9,y+3,1.3,'inLacquer',1.05)
    Lw.box(cx+sx-3,y-.9,1,cx+sx+3,y+.9,1.3,'inLacquer',1.05)
   end
  end
 end
 -- the healing consoles (H): cabinet front at z=26 (the heal animation's
 -- Poke Balls land in its two columns of slots), the monitor at z=24
 for gi,g in ipairs(groups(C,'H'))do
  local x0,x1=g.x0*CS,(g.x1+1)*CS
  local cx=(x0+x1)/2
  local L=F(cx,0,0,0)
  -- cabinet
  L.box(-11,0,16.4,11,16,26,'inEnamel',1.0)
  L.box(-11.4,16,16,11.4,17.2,26.6,'inLacquer',1.05)
  L.box(-11,0,25.6,11,1.4,26.4,'dark',.8)
  -- the dark panel and its six slots (two columns of three)
  L.box(-6,3.4,26,6,20.4,26.3,'lvSlate',.75)
  for k=0,2 do for _,sx in ipairs({-3,3})do
   L.disc(sx,7+k*5,26.35,2.0,'dark',12,nil,.8)
   L.ring(sx,7+k*5,26.4,2.0,2.5,'inSteel',12,1.1)
  end end
  -- side panels with vents
  for _,sx in ipairs({-1,1})do
   for k=0,3 do L.box(sx*8.5-2,4+k*2.4,26,sx*8.5+2,4.8+k*2.4,26.35,'inSteel',.9)end
   L.box(sx*8.5-1,12.6,26,sx*8.5+1,14.2,26.4,gi==1 and'gold'or'ktCopper',1.2)
  end
  -- the console on the lid: sloped, with the monitor
  L.box(-9,17.2,17,9,30,24,'inEnamel',1.0)
  L.box(-9.4,30,16.6,9.4,31.4,24.4,'inLacquer',1.05)
  L.box(-7,19.2,24,7,28.6,24.2,'dark',.6)
  L.raw({-6.2,20,24.25},{6.2,20,24.25},{6.2,27.8,24.25},{-6.2,27.8,24.25},'inScreen',gi==1 and 1 or 3)
  -- the pipes into the floor at the flanks (the drawing's L-bends)
  for _,sx in ipairs(gi==1 and{-1}or{-1,1})do
   L.rod({sx*11,10,21},{sx*13.4,10,21},.9,'inSteel')
   L.rod({sx*13.4,10,21},{sx*13.4,0,21},.9,'inSteel')
   L.cyl(sx*13.4,0,.6,21,1.6,1.6,'inSteel',8)
  end
  -- the keyboard at the first console's east flank
  if gi==1 then
   local kx=13.6
   L.box(kx-2.6,0,18,kx+2.6,11,24,'inEnamel',.98)
   L.quad({kx-2.4,11,18.4},{kx+2.4,11,18.4},{kx+2.4,9.6,23.8},{kx-2.4,9.6,23.8},'inSteel',1.05)
   for r=0,2 do for c=0,2 do L.box(kx-2+c*1.4,9.9+r*.2,19.2+r*1.6,kx-1+c*1.4,10.3+r*.2,20.2+r*1.6,'dark',.9)end end
  end
 end
 -- the counter (C) and the Cable Club desks (L)
 do
  local runs={}
  for cx=0,C.cw-1 do
   local c=C.at(cx,2)
   if c=='C'or c=='L'then
    local last=runs[#runs]
    if last and last.x1==cx-1 and last.kind==c then last.x1=cx else runs[#runs+1]={x0=cx,x1=cx,kind=c}end
   end
  end
  for _,r in ipairs(runs)do
   local x0,x1=r.x0*CS,(r.x1+1)*CS
   -- skip the pillars' own blocks
   local L=F(0,0,0,0)
   local link=r.kind=='L'
   local body=link and'ktPearl'or'inEnamel'
   L.box(x0,0,33,x1,13.6,46.4,body,1.0)
   L.box(x0,0,46,x1,1.6,46.6,'dark',.8)
   L.box(x0,13.6,32.4,x1,15,47.4,link and'ktMarine'or'inLacquer',1.05)
   L.box(x0,15,33,x1,15.5,47.2,link and'inSteel'or'inEnamel',1.12)
   -- front: recessed panels and a red stripe
   for x=x0+1,x1-2,8 do L.box(x+.6,2.4,46.4,x+7.4,11.6,46.7,body,1.06)end
   L.box(x0,7,46.6,x1,8.2,46.9,link and'ktMarine'or'inLacquer',1.0)
   if link then
    -- the link desk: a trade terminal and its cable ports
    local cx=(x0+x1)/2
    local Lk=F(cx,15.5,40,0)
    Lk.box(-5,0,-3,5,1.2,3,'inSteel',1)
    Lk.box(-4.4,1.2,-2,4.4,8,-1,'dark',.7)
    Lk.raw({-3.8,1.8,-.95},{3.8,1.8,-.95},{3.8,7.4,-.95},{-3.8,7.4,-.95},'inScreen',3)
    for k=0,2 do Lk.box(-3+k*3-.5,1.2,1.6,-3+k*3+.5,1.8,2.6,'gold',1.2)end
   end
  end
  -- the nurse's trays and a tidy row of Poke Balls waiting
  for _,cx in ipairs({1,3})do
   if C.at(cx,2)=='C'then
    local L=F(cx*CS+8,15.5,40,0)
    L.box(-5,0,-3.4,5,.6,3.4,'inSteel',1.1)
    L.box(-5.3,0,-3.7,5.3,1.2,-3.3,'inSteel',1.0);L.box(-5.3,0,3.3,5.3,1.2,3.7,'inSteel',1.0)
    for k=0,2 do
     local bx=-3.2+k*3.2
     L.sphere(bx,1.8,0,1.3,1.3,1.3,'inLacquer',8,4)
     L.box(bx-1.32,1.7,-.2,bx+1.32,1.9,.2,'dark',1)
     L.disc(bx,1.8,1.32,.4,'inEnamel',6,nil,1.1)
    end
   end
  end
  -- a bell and a little sign on the counter
  local L=F(4*CS+8,15.5,40,0)
  L.cyl(0,0,.4,0,1.8,1.8,'lgGold',10);L.sphere(0,1.2,0,1.4,1.2,1.4,'lgGold',8,4);L.cyl(0,2.3,2.9,0,.3,.3,'lgGold',6)
 end
 -- TEST179: the stairs up to the union room (gen1recomp's 2F), where the
 -- engine has put them; the warp is the engine's, the flight is ours
 for _,g in ipairs(groups(C,'^'))do
  K.stairsUp(C,R,g.x0*CS,(g.x1+1)*CS,max(S.n,g.y0*CS),(g.y1+1)*CS,{tread='inOak',riser='white',rail='inLacquer',side=g.x0*CS+1,n=4,top=14})
  -- a sign over the flight
  local Lw=K.onWall(C,'N',0,0)
  Lw.box(g.x0*CS+2,46,0,(g.x1+1)*CS-2,51,.8,'inLacquer',1.05)
  Lw.box(g.x0*CS+3,46.8,.8,(g.x1+1)*CS-3,50.2,1.0,'white',1.12)
  V.require('LeagueArchitecture').kit.inscription(Lw,'2F',(g.x0+g.x1+1)*CS/2,47.4,1.0,.6,'inLacquer',10)
 end
 -- the PC kiosk (K), facing the lobby
 for _,g in ipairs(groups(C,'K'))do
  local x0,x1=g.x0*CS,(g.x1+1)*CS
  local z1=(g.y1+1)*CS
  local L=F((x0+x1)/2,0,z1-2,0)
  L.box(-6.6,0,-20,6.6,12,0,'inEnamel',1.0)
  L.box(-6.6,0,-.4,6.6,1.4,.2,'dark',.8)
  L.quad({-6.2,12,-6},{6.2,12,-6},{6.2,10.4,.2},{-6.2,10.4,.2},'inSteel',1.05)
  for r=0,3 do for c=0,7 do L.box(-5.4+c*1.4,10.7+r*.38*(1)-r*.0,-5.2+r*1.4,-4.6+c*1.4,11.1+r*.38-r*.0,-4.4+r*1.4,'dark',.9)end end
  L.box(-6.6,12,-20,6.6,32,-8,'inEnamel',1.0)
  L.box(-7,32,-20.4,7,33.6,-7.6,'inLacquer',1.05)
  L.box(-5.8,14.6,-8,5.8,28.6,-7.7,'dark',.6)
  L.raw({-5.2,15.2,-7.65},{5.2,15.2,-7.65},{5.2,28,-7.65},{-5.2,28,-7.65},'inScreen',1)
  -- "PC" over the screen
  V.require('LeagueArchitecture').kit.inscription(L,'PC',0,29.2,-7.7,.55,'gold')
 end
 -- the lounge couch (U) against the west wall, facing east, and its man
 for _,g in ipairs(groups(C,'U'))do
  local z0,z1=g.y0*CS,(g.y1+1)*CS
  local L=F(8,0,(z0+z1)/2,pi/2)
  local len=(z1-z0)-2
  local hl=len/2
  local cloth=T.rug[1]
  L.box(-hl,0,-6,hl,2,7,'inWalnut',.8)
  L.box(-hl,2,-4,hl,7,7.6,cloth,1.0)                -- seat
  L.box(-hl,2,-6.6,hl,15,-3,cloth,.98)              -- back
  L.box(-hl-1.6,2,-6.6,-hl,11,7.8,cloth,1.0)        -- arms
  L.box(hl,2,-6.6,hl+1.6,11,7.8,cloth,1.0)
  for k=0,1 do L.box(-hl+.6+k*hl,7,-3,-.4+k*hl,8.6,7,cloth,1.08)end   -- cushions
  L.box(-hl+2,8.6,-2.8,-hl+6,11.6,-1.6,'ktPearl',1.1)                  -- a pillow
  -- a coffee table with magazines, on the floor in front would block the
  -- walk; the magazines sit on the couch's arm instead
  L.box(hl+.1,11,-1,hl+1.5,11.3,4,'flower',1.1)
  -- the gentleman of the tile art, resting
  local Lm=F(8,0,(z0+z1)/2+3,pi/2)
  sitter(Lm,8.4,{coat='navy'})
 end
 -- the planters (P): two tall plants in round white pots, as drawn
 local tall={PEWTER='snake',ROCKTUNNEL='snake',MTMOON='snake',CINNABAR='palm',VERMILION='palm',FUCHSIA='bamboo',
  SAFFRON='snake',CELADON='ficus',CERULEAN='monstera',LAVENDER='fern',VIRIDIAN='ficus'}
 for _,g in ipairs(groups(C,'P'))do
  local x0,x1=g.x0*CS,(g.x1+1)*CS
  local z0,z1=g.y0*CS,(g.y1+1)*CS
  local n=max(1,floor((x1-x0)/16+.5))
  for i=0,n-1 do
   local px=x0+(i+.5)*(x1-x0)/n;local pz=z1-8.5
   local L=F(px,0,pz,0)
   L.cyl(0,0,1,0,5.2,5.6,'dark',14)
   L.cyl(0,1,9,0,5.6,6.6,'inEnamel',14,false)
   L.cyl(0,4,6,0,6.25,6.35,'inLacquer',14,false)
   L.cyl(0,9,10,0,6.9,6.9,'inEnamel',14,false)
   L.cyl(0,9.6,9.8,0,6.2,6.2,'forestFloor',14)
   local kind=(i%2==0)and(tall[C.city]or'ficus')or(C.city=='FUCHSIA'and'bamboo'or'monstera')
   K.plant(F(px,9.6,pz,0),kind,{s=1.55,seed=g.x0*3+i,potR=.01,potH=.01})
   -- the crowns rise into the cell behind, as the drawing shows
   if kind=='snake'or kind=='bamboo'then K.plant(F(px,9.6,pz,0),'fern',{s=1.1,seed=g.x0*7+i,potR=.01,potH=.01})end
  end
 end
 -- windows (w) behind the counter, the town beyond
 for _,c in ipairs(cellsOf(C,'w'))do
  local Lw=K.onWall(C,'N',0,0)
  local x=c[1]*CS+8
  K.window(C,Lw,x-9,x+9,24,46,{frame='white',view=T.view,panes={2,3},curtain='valance',cloth='inLacquer'})
 end
 -- the town's own pictures on the bare wall
 do
  local art=CENTER_ART[C.city]or{'meadow','sea'}
  local Lw=K.onWall(C,'N',0,0)
  K.picture(C,Lw,8*CS+5,9*CS+11,30,44,art[1],{frame='inWalnut'})
  -- a notice board by the Cable Club (TEST179: beside the stairs when the
  -- engine's union room has put them there)
  local bx=(C.variant=='union'and 12 or 13)*CS
  Lw.box(bx+2,27,0,bx+14,45,.8,'inOak',1.0)
  Lw.box(bx+3,28,.8,bx+13,44,1.0,'ktSandstone',1.0)
  for i=0,4 do local px=bx+3.5+rh(i,1,5)*6;local py=30+rh(i,2,5)*10
   Lw.box(px,py,1,px+3.4,py+4,1.15,({'white','gold','ktPearl','flower','white'})[i+1],1.15)
   Lw.box(px+1.4,py+3.4,1.15,px+2,py+4,1.4,'red',1.2)end
  -- the west wall: a picture and a clock over the couch
  local Lw2=K.onWall(C,'W',0,0)
  K.picture(C,Lw2,D-6*CS+2,D-4*CS-2,30,44,art[2],{frame='lgGold'})
  K.clock(C,Lw2,D-6.5*CS,50,3.6,{case='inEnamel',rim='inLacquer'})
 end
 -- the front door
 local d0,d1=doorSpan(C)
 if d0 then K.frontDoor(C,d0,d1,{view=T.view==2 and 2 or 1,frame='white',leaf='ktPearl'})end
 -- a welcome mat at the door
 if d0 then K.rug(C,C.part('floor'),d0+2,D-12,d1-2,D-1,{field='inRugRed',border='dark',bw=1,y=.12})end
 -- ceiling: light panels in a coffered grid
 do
  local E=C.part('ceilfx',{below=H+2})
  local L=K.frame(C,E,0,0,0,0)
  for x=40,W-30,48 do for z=S.n+30,D-20,40 do
   L.raw({x-9,H-.4,z-9},{x+9,H-.4,z-9},{x+9,H-.4,z+9},{x-9,H-.4,z+9},'inPanel',1)
   L.box(x-10,H-.8,z-10,x+10,H-.3,z-9,'white',1);L.box(x-10,H-.8,z+9,x+10,H-.3,z+10,'white',1)
   L.box(x-10,H-.8,z-10,x-9,H-.3,z+10,'white',1);L.box(x+9,H-.8,z-10,x+10,H-.3,z+10,'white',1)
  end end
 end
 ceilingLights(C,H,48,.16,0,W,S.n,D)
 -- light pools on the floor under the panels (soft, additive)
 for x=40,W-30,48 do for z=S.n+30,D-20,40 do
  C.fx.pools[#C.fx.pools+1]={x=x,y=.3,z=z,r=20,a=.035,col={1,.97,.92},ceil=true}
 end end
 -- the consoles' screens glow a little
 for gi,g in ipairs(groups(C,'H'))do
  local cx=(g.x0+g.x1+1)*CS/2
  C.fx.glows[#C.fx.glows+1]={x=cx,y=24,z=25,r=8,col=gi==1 and'cyan'or'green',a=.16}
 end
 C.fx.ambience={hall=.35}
 -- the town's touch
 M.centerTouch(C,T,F)
end
------------------------------------------------------------------ UPSTAIRS
-- TEST202: the union room's upstairs (gen1recomp's shared POKECENTER_2F)
-- in the dress of the Center you came up from (C.city is that town): the
-- lobby's walls and red band, its tile, its counter, pillars, planters,
-- emblem and light panels. The engine's plan: the Union Room's door and
-- the closed doorway beside it in the back wall (cells 6 and 10), the two
-- Cable Club receptionists behind the counter, its two closed gates
-- (cells 6 and 10 of row 2), the flight down at (13,1) and the planters
-- in the corners.
local UP_DOORS={[6]='UNION ROOM',[10]='CABLE CLUB'}
function M.upstairs(C)
 local T=theme(C.city)
 local H=60;C.H=H
 C.ambient=.80;C.maxLight=1.45
 local solid=topWall(C)
 local W,D=C.cw*CS,C.ch*CS
 local S=K.shell(C,{H=H,solid=solid,blocked=blocked(C),
  door=function(cx,cy,ox,oy)return cy==0 and oy==1 and ox==cx and UP_DOORS[cx]~=nil end,
  nofloor=function(cx,cy)return C.at(cx,cy)=='v'end,
  paint=T.modern and'white'or'ktPlaster',upper=T.modern and'ktPearl'or'white',wainscot='inEnamel',wainscotH=16,
  rail='red',skirting='red',cornice='white',cap='ktLime',floor='inTile',ceiling='white',
  style=function(L,len,run)
   L.box(0,22,0,len,24.4,.5,'inLacquer',1.0)
   L.box(0,24.4,0,len,25,.6,'white',1.1)
  end})
 local R=C.part('room')
 local function F(x,y,z,yaw)return K.frame(C,R,x,y,z,yaw)end
 local Lw=K.onWall(C,'N',0,0)
 local kit=V.require('LeagueArchitecture').kit
 -- the two doorways: red frames, closed pearl doors, a sign over each
 for cx,label in pairs(UP_DOORS)do
  local x0,x1=cx*CS,(cx+1)*CS
  K.exitPortal(C,'N',x0,x1,{inside=true,scenic=false,frame='inLacquer',leaf='ktPearl',sill='inEnamel',top=34})
  Lw.box(x0-8,36,0,x1+8,43,.8,'inLacquer',1.05)
  Lw.box(x0-7,36.8,.8,x1+7,42.2,1.0,'white',1.12)
  kit.inscription(Lw,label,(x0+x1)/2,37.6,1.0,.8,'inLacquer',x1-x0+12)
 end
 -- flat red-and-white pilasters between the doors (the lobby's pillars,
 -- pressed to the wall: the receptionists' row stays clear)
 for _,x in ipairs({40,136})do
  Lw.box(x-6,0,0,x+6,H-2.4,2.4,'inEnamel',1.0)
  Lw.box(x-6.6,0,0,x+6.6,3,3,'inLacquer',1.0)
  Lw.box(x-6.6,H-6,0,x+6.6,H-2.4,3,'inLacquer',1.0)
  Lw.box(x-6.4,22,0,x+6.4,25,2.8,'inLacquer',1.0)
  for _,sx in ipairs({-1,1})do Lw.box(x+sx*6-.3,3,0,x+sx*6+.3,H-6,2.6,'white',1.1)end
 end
 -- the Center's emblem high on the middle pilaster
 do
  local cx,y,r=136,44,5.6
  for i=0,23 do local a0,a1=i/24*pi*2,(i+1)/24*pi*2
   local top=sin((a0+a1)/2)>0
   Lw.quad({cx,y,3.1},{cx+cos(a0)*r,y+sin(a0)*r,3.1},{cx+cos(a1)*r,y+sin(a1)*r,3.1},{cx,y,3.1},top and'inLacquer'or'inEnamel',1.05)
  end
  Lw.ring(cx,y,3.2,r,r+.7,'dark',24,1)
  Lw.box(cx-r,y-.35,3.2,cx+r,y+.35,3.3,'dark',1)
  Lw.disc(cx,y,3.4,1.8,'dark',14);Lw.disc(cx,y,3.5,1.2,'inEnamel',14,nil,1.1)
 end
 -- windows onto the town, west of the doors
 for _,x in ipairs({16,72})do
  K.window(C,Lw,x-9,x+9,28,46,{frame='white',view=T.view,panes={2,3},curtain='valance',cloth='inLacquer'})
 end
 -- the counter: the lobby's red-and-white desk, with the Cable Club's
 -- pearl-and-marine flaps at the two gates (L)
 do
  local runs={}
  for cx=0,C.cw-1 do
   local c=C.at(cx,2)
   if c=='C'or c=='L'then
    local last=runs[#runs]
    if last and last.x1==cx-1 and last.kind==c then last.x1=cx else runs[#runs+1]={x0=cx,x1=cx,kind=c}end
   end
  end
  local L=F(0,0,0,0)
  for _,r in ipairs(runs)do
   local x0,x1=r.x0*CS,(r.x1+1)*CS
   local gate=r.kind=='L'
   local body=gate and'ktPearl'or'inEnamel'
   L.box(x0,0,33,x1,13.6,46.4,body,1.0)
   L.box(x0,0,46,x1,1.6,46.6,'dark',.8)
   L.box(x0,13.6,32.4,x1,15,47.4,gate and'ktMarine'or'inLacquer',1.05)
   L.box(x0,15,33,x1,15.5,47.2,gate and'inSteel'or'inEnamel',1.12)
   for x=x0+1,x1-2,8 do L.box(x+.6,2.4,46.4,x+7.4,11.6,46.7,body,1.06)end
   L.box(x0,7,46.6,x1,8.2,46.9,gate and'ktMarine'or'inLacquer',1.0)
   if gate then
    -- the flap's hinge line and a trade terminal on it
    L.box(x0+.2,1.6,46.5,x0+.8,13.4,46.9,'inSteel',1.1)
    local Lk=F((x0+x1)/2,15.5,40,0)
    Lk.box(-5,0,-3,5,1.2,3,'inSteel',1)
    Lk.box(-4.4,1.2,-2,4.4,8,-1,'dark',.7)
    Lk.raw({-3.8,1.8,-.95},{3.8,1.8,-.95},{3.8,7.4,-.95},{-3.8,7.4,-.95},'inScreen',3)
    for k=0,2 do Lk.box(-3+k*3-.5,1.2,1.6,-3+k*3+.5,1.8,2.6,'gold',1.2)end
   end
  end
  -- the counter's west end, finished in red
  L.box(0,0,32.6,2,15.4,47.2,'inLacquer',1.0)
  -- a bell for each receptionist
  for _,x in ipairs({7*CS+8,11*CS+8})do
   local Lb=F(x,15.5,42,0)
   Lb.cyl(0,0,.4,0,1.8,1.8,'lgGold',10);Lb.sphere(0,1.2,0,1.4,1.2,1.4,'lgGold',8,4);Lb.cyl(0,2.3,2.9,0,.3,.3,'lgGold',6)
  end
  -- the visitors' book and a lamp on the west run
  local Lt=F(2*CS+8,15.5,40,0)
  Lt.box(-4,0,-3,4,.8,3,'inLacquer',1.05);Lt.box(-3.6,.8,-2.6,3.6,1.1,2.6,'ktPearl',1.15)
  Lt.box(-.2,.8,-2.6,.2,1.2,2.6,'inLacquer',1.0)
  K.lamp(C,F(4*CS+8,15.5,40,0),'table',{})
 end
 -- the flight down to the lobby, and its sign
 for _,g in ipairs(groups(C,'v'))do
  local x0,x1=g.x0*CS,(g.x1+1)*CS
  local z0,z1=max(S.n,g.y0*CS),(g.y1+1)*CS
  K.stairsDown(C,R,x0+1,x1-1,z0+1,z1,{tread='inOak',riser='white',rail='inLacquer',handrail='inLacquer',
   wall=T.modern and'white'or'ktPlaster',railX=x0+1.5,n=4,depth=16})
  Lw.box(x0+1,46,0,x1-1,51,.8,'inLacquer',1.05)
  Lw.box(x0+2,46.8,.8,x1-2,50.2,1.0,'white',1.12)
  kit.inscription(Lw,'1F',(x0+x1)/2,47.4,1.0,.6,'inLacquer',10)
 end
 -- floor inlay: the lobby's great Poke Ball, smaller, mid-room
 do
  local E=C.part('inlay')
  local cx,cz=W*.5,88
  local r=17
  local n=36
  for i=0,n-1 do local a0,a1=i/n*pi*2,(i+1)/n*pi*2
   local top=sin((a0+a1)/2)<0
   E.quad({cx,.06,cz},{cx+cos(a1)*r,.06,cz+sin(a1)*r},{cx+cos(a0)*r,.06,cz+sin(a0)*r},{cx,.06,cz},top and'inLacquer'or'inEnamel',1)
   E.quad({cx+cos(a0)*r,.07,cz+sin(a0)*r},{cx+cos(a1)*r,.07,cz+sin(a1)*r},{cx+cos(a1)*(r+1.4),.07,cz+sin(a1)*(r+1.4)},{cx+cos(a0)*(r+1.4),.07,cz+sin(a0)*(r+1.4)},'dark',1)
  end
  E.quad({cx-r,.08,cz-.9},{cx+r,.08,cz-.9},{cx+r,.08,cz+.9},{cx-r,.08,cz+.9},'dark',1)
  for layer,rr in ipairs({{5.4,'dark'},{4.1,'inEnamel'},{2.5,'ktPearl'}})do
   local y=.10+(layer-1)*.015
   for i=0,19 do local a0,a1=i/20*pi*2,(i+1)/20*pi*2
    E.quad({cx,y,cz},{cx+cos(a1)*rr[1],y,cz+sin(a1)*rr[1]},{cx+cos(a0)*rr[1],y,cz+sin(a0)*rr[1]},{cx,y,cz},rr[2],1)end
  end
 end
 -- the planters (P), as downstairs
 local tall={PEWTER='snake',ROCKTUNNEL='snake',MTMOON='snake',CINNABAR='palm',VERMILION='palm',FUCHSIA='bamboo',
  SAFFRON='snake',CELADON='ficus',CERULEAN='monstera',LAVENDER='fern',VIRIDIAN='ficus'}
 for _,g in ipairs(groups(C,'P'))do
  local x0,x1=g.x0*CS,(g.x1+1)*CS
  local z0,z1=g.y0*CS,(g.y1+1)*CS
  local n=max(1,floor((x1-x0)/16+.5))
  for i=0,n-1 do
   local px=x0+(i+.5)*(x1-x0)/n;local pz=z1-8.5
   local L=F(px,0,pz,0)
   L.cyl(0,0,1,0,5.2,5.6,'dark',14)
   L.cyl(0,1,9,0,5.6,6.6,'inEnamel',14,false)
   L.cyl(0,4,6,0,6.25,6.35,'inLacquer',14,false)
   L.cyl(0,9,10,0,6.9,6.9,'inEnamel',14,false)
   L.cyl(0,9.6,9.8,0,6.2,6.2,'forestFloor',14)
   local kind=(i%2==0)and(tall[C.city]or'ficus')or(C.city=='FUCHSIA'and'bamboo'or'monstera')
   K.plant(F(px,9.6,pz,0),kind,{s=1.55,seed=g.x0*3+i+5,potR=.01,potH=.01})
   if kind=='snake'or kind=='bamboo'then K.plant(F(px,9.6,pz,0),'fern',{s=1.1,seed=g.x0*7+i+5,potR=.01,potH=.01})end
  end
 end
 -- the side walls: the town's pictures, the clock, the Club's notices
 do
  local art=CENTER_ART[C.city]or{'meadow','sea'}
  local Lw2=K.onWall(C,'W',0,0)
  K.picture(C,Lw2,D-5*CS+2,D-3*CS-2,28,44,art[1],{frame='inWalnut'})
  K.clock(C,Lw2,D-6.5*CS,50,3.6,{case='inEnamel',rim='inLacquer'})
  local Le=K.onWall(C,'E',0,0)
  K.picture(C,Le,3*CS+2,5*CS-2,28,44,art[2],{frame='lgGold'})
  local bx=1.2*CS
  Le.box(bx+2,27,0,bx+14,45,.8,'inOak',1.0)
  Le.box(bx+3,28,.8,bx+13,44,1.0,'ktSandstone',1.0)
  for i=0,4 do local px=bx+3.5+rh(i,3,5)*6;local py=30+rh(i,4,5)*10
   Le.box(px,py,1,px+3.4,py+4,1.15,({'white','gold','ktPearl','flower','white'})[i+1],1.15)
   Le.box(px+1.4,py+3.4,1.15,px+2,py+4,1.4,'red',1.2)end
 end
 -- a red runner along the counter
 K.rug(C,C.part('floor'),4,50,W-20,60,{field='inRugRed',border='dark',bw=1,y=.12})
 -- ceiling: the lobby's light panels
 do
  local E=C.part('ceilfx',{below=H+2})
  local L=K.frame(C,E,0,0,0,0)
  for x=40,W-30,48 do for z=S.n+30,D-20,40 do
   L.raw({x-9,H-.4,z-9},{x+9,H-.4,z-9},{x+9,H-.4,z+9},{x-9,H-.4,z+9},'inPanel',1)
   L.box(x-10,H-.8,z-10,x+10,H-.3,z-9,'white',1);L.box(x-10,H-.8,z+9,x+10,H-.3,z+10,'white',1)
   L.box(x-10,H-.8,z-10,x-9,H-.3,z+10,'white',1);L.box(x+9,H-.8,z-10,x+10,H-.3,z+10,'white',1)
  end end
 end
 ceilingLights(C,H,48,.16,0,W,S.n,D)
 for x=40,W-30,48 do for z=S.n+30,D-20,40 do
  C.fx.pools[#C.fx.pools+1]={x=x,y=.3,z=z,r=20,a=.035,col={1,.97,.92},ceil=true}
 end end
 for _,g in ipairs(groups(C,'L'))do
  C.fx.glows[#C.fx.glows+1]={x=(g.x0+g.x1+1)*CS/2,y=20,z=39,r=6,col='cyan',a=.12}
 end
 C.fx.ambience={hall=.35}
end
-- one thing in each Center that belongs to its town
function M.centerTouch(C,T,F)
 local c=C.city
 local W,D=C.cw*CS,C.ch*CS
 local Lw=K.onWall(C,'E',0,0)
 if c=='CERULEAN'then
  -- a little aquarium on the counter's end
  local L=F(13*CS+8,15.5,40,0)
  L.box(-6,0,-4,6,.8,4,'inWalnut',1)
  L.raw({-5.6,.8,3.6},{5.6,.8,3.6},{5.6,8,3.6},{-5.6,8,3.6},'inAqua',1)
  L.raw({5.6,.8,-3.6},{5.6,.8,3.6},{5.6,8,3.6},{5.6,8,-3.6},'inAqua',1)
  L.raw({-5.6,.8,-3.6},{-5.6,.8,3.6},{-5.6,8,3.6},{-5.6,8,-3.6},'inAqua',1)
  L.raw({-5.6,8,-3.6},{5.6,8,-3.6},{5.6,8,3.6},{-5.6,8,3.6},'inAqua',1)
  L.box(-6,8,-4,6,8.8,4,'inWalnut',1)
 elseif c=='VERMILION'then
  -- a life ring on the east wall
  Lw.ring(30,36,.6,4,6.4,'inLacquer',20,1.05)
  for i=0,3 do local a=i*pi/2+pi/4;Lw.box(30+cos(a)*5.2-1,36+sin(a)*5.2-1,.65,30+cos(a)*5.2+1,36+sin(a)*5.2+1,.9,'white',1.1)end
 elseif c=='LAVENDER'then
  -- a memorial candle shelf
  K.wallShelf(Lw,22,40,30,{wood='lvWalnut'})
  for i=0,2 do K.lamp(C,F(W-2.2,30,C.shellBox.n+25+i*6,0),'candle',{h=3+i,col=i==1 and'violet'or nil})end
 elseif c=='CELADON'then
  local L=F(13*CS+8,15.5,40,0)
  K.plant(L,'flowers',{s=.8,pot='white',potR=2.2,potH=3,colors={'flower','white','gold'}})
 elseif c=='SAFFRON'then
  K.picture(C,Lw,20,44,26,42,'abstract',{frame='dark',mat=.6})
 elseif c=='FUCHSIA'then
  -- a hanging scroll and a lantern
  Lw.box(28,24,0,38,48,.4,'cream',1.1);Lw.box(27,47,0,39,48.6,1,'inWalnut',1);Lw.box(27,23.4,0,39,24.4,1,'inWalnut',1)
  for i=0,4 do Lw.box(31.5,28+i*3.8,.4,34.5,30.4+i*3.8,.5,'dark',.7)end
 elseif c=='CINNABAR'then
  K.picture(C,Lw,20,44,26,42,'sunset',{frame='inOak'})
 elseif c=='PEWTER'or c=='MTMOON'or c=='ROCKTUNNEL'then
  -- a display of stones
  K.wallShelf(Lw,20,44,32,{wood='inWalnut',items=c=='PEWTER'and'fossils'or'rocks',seed=c=='MTMOON'and 4 or 2})
 elseif c=='VIRIDIAN'then
  K.picture(C,Lw,20,44,26,42,'tree',{frame='inOak'})
 end
end

------------------------------------------------------------------ MART
-- The Poke Mart (one plan in every town): refrigerated cases under their
-- SALE boards, glass display cabinets of potions, two gondolas of goods, the
-- clerk's counter and till, baskets by the door, strip lights overhead.
function M.mart(C)
 local T=theme(C.city)
 local H=56;C.H=H
 C.ambient=.82;C.maxLight=1.45
 local solid=topWall(C)
 local W,D=C.cw*CS,C.ch*CS
 local S=K.shell(C,{H=H,solid=solid,blocked=blocked(C),door=doorFn(C),
  paint='white',upper='ktPearl',wainscot='inEnamel',wainscotH=12,rail='blue',skirting='blue',cornice='white',
  cap='ktLime',floor=T.modern and'inChecker'or'inTerrazzo',ceiling='white',
  style=function(L,len,run)
   L.box(0,28,0,len,31,.5,'blue',1.0)
   L.box(0,31,0,len,31.6,.6,'white',1.1)
  end})
 local R=C.part('room')
 local function F(x,y,z,yaw)return K.frame(C,R,x,y,z,yaw)end
 local ins=V.require('LeagueArchitecture').kit.inscription
 local accent=T.accent=='blue'and'blue'or'blue'
 ---------------------------------------------------------------- the goods
 -- TEST178: real stock, modelled, instead of a painted strip of cartons.
 -- Every item stands on its shelf facing the aisle (local +z is the front).
 local function ball(L,x,y,z,r,top)
  -- a Poke Ball: 7 sides, 4 bands; the top half in its colour, a dark
  -- band at the middle, white below, a button in front
  local n,rings=8,4
  local pts={}
  for j=0,rings do pts[j]={}
   local bb=-pi/2+j*pi/rings
   for i=0,n-1 do local aa=i/n*pi*2+.3
    pts[j][i]={x+cos(aa)*cos(bb)*r,y+r+sin(bb)*r,z+sin(aa)*cos(bb)*r}
   end
  end
  for j=0,rings-1 do for i=0,n-1 do local i2=(i+1)%n
   local mat=j>=rings/2 and top or'white'
   L.quad(pts[j][i],pts[j][i2],pts[j+1][i2],pts[j+1][i],mat,1.0)
  end end
  L.cyl(x,y+r-.18,y+r+.18,z,r*1.02,r*1.02,'dark',n,false,.3)
  L.box(x-.3,y+r-.3,z+r-.3,x+.3,y+r+.3,z+r+.15,'dark',1);L.box(x-.18,y+r-.18,z+r+.15,x+.18,y+r+.18,z+r+.3,'white',1.15)
 end
 local function potion(L,x,y,z,col,h)
  h=h or 4.2
  L.cyl(x,y,y+h*.7,z,.9,.9,col,7,false)
  L.cyl(x,y+h*.7,y+h*.82,z,.9,.5,col,7,false)
  L.cyl(x,y+h*.82,y+h,z,.5,.5,'white',6)
  L.box(x-.5,y+h-.3,z-.2,x+.9,y+h+.6,z+.2,'white',1.1)
  L.box(x-.9,y+h*.28,z+.88,x+.9,y+h*.52,z+.95,'white',1.15)
  L.box(x-.6,y+h*.34,z+.95,x+.6,y+h*.46,z+1.0,col,1.1)
 end
 local function can(L,x,y,z,col,h)
  h=h or 5.2
  L.cyl(x,y,y+h,z,.85,.85,col,7)
  L.cyl(x,y+h,y+h+.5,z,.45,.45,'dark',6)
  L.box(x-.85,y+h*.35,z+.78,x+.85,y+h*.65,z+.9,'white',1.15)
 end
 local function carton(L,x,y,z,w,h,d,col,lab)
  L.box(x-w/2,y,z-d/2,x+w/2,y+h,z+d/2,col,1.0)
  L.box(x-w/2+.3,y+h*.35,z+d/2,x+w/2-.3,y+h*.7,z+d/2+.08,lab or'white',1.15)
  L.box(x-w/2+.6,y+h*.42,z+d/2+.08,x+w/2-.6,y+h*.5,z+d/2+.12,col,1.0)
 end
 local function rope(L,x,y,z)
  L.ring(x,y+1.6,z,.8,1.6,'ktOchre',10,1.0)
  L.ring(x,y+1.6,z+.3,.9,1.5,'gold',10,1.05)
  L.box(x-.4,y+2.6,z-.2,x+.4,y+3.6,z+.4,'red',1.1)
 end
 local BALLS={{'red','red'},{'blue','red'},{'gold','dark'},{'red','red'}}
 local POTS={'lgPlum','blue','gold','red','leaf'}
 local CANS={'leaf','ktMarine','gold','red'}
 local CART={'red','blue','gold','leaf','flower','ktCopper'}
 -- one shelf of a kind: facings in threes, the same item three times
 local function stock(L,kind,x0,x1,y,z,seed)
  local pitch=kind=='balls'and 3.0 or(kind=='cans'and 2.2 or(kind=='cartons'and 3.6 or 2.6))
  local n=floor((x1-x0-1)/pitch);if n<1 then return end
  local left=x0+((x1-x0)-n*pitch)/2+pitch/2
  for i=0,n-1 do
   local x=left+i*pitch;local g=floor(i/3)+seed
   if rh(i,seed,11)<.08 then -- a gap, something sold
   elseif kind=='balls'then local b=BALLS[g%#BALLS+1];ball(L,x,y,z,1.25,b[1])
   elseif kind=='potions'then potion(L,x,y,z,POTS[g%#POTS+1],3.8+(g%3)*.5)
   elseif kind=='cans'then can(L,x,y,z,CANS[g%#CANS+1],4.6+(g%2)*.8)
   elseif kind=='cartons'then
    if g%4==3 then rope(L,x,y,z)else carton(L,x,y,z,2.8,3.4+(g%3)*.8,2.2,CART[g%#CART+1])end
   end
  end
 end
 local KINDS={'balls','potions','cartons','cans'}
 -- a shelf-edge price strip: white, with a coloured tag now and then
 local function priceStrip(L,x0,x1,y,z,seed)
  L.box(x0,y-1.1,z-.15,x1,y,z,'white',1.15)
  for x=x0+2,x1-3,6 do
   if rh(x,seed,5)<.6 then L.box(x,y-.9,z,x+2.2,y-.2,z+.08,rh(x,seed,6)<.3 and'red'or'gold',1.2)end
  end
 end
 ---------------------------------------------------------------- the cases
 -- the refrigerated cases (F) under SALE boards: drinks behind glass doors
 for _,g in ipairs(groups(C,'F'))do
  local x0,x1=g.x0*CS,(g.x1+1)*CS
  local L=F(0,0,0,0)
  L.box(x0+.5,0,16.2,x1-.5,30,29,'inEnamel',1.0)
  L.box(x0+.5,0,28.6,x1-.5,2.4,29.4,'dark',.8)
  L.box(x0+.5,0,16.2,x1-.5,.8,29,'dark',.7)
  -- the lit back and three shelves of drinks
  L.raw({x0+1,3,17.2},{x1-1,3,17.2},{x1-1,28,17.2},{x0+1,28,17.2},'inLamp',2)
  for k=0,2 do
   local y=3.4+k*8
   L.box(x0+1,y-.5,17.2,x1-1,y,28.4,'ktSteel',1.05)
   stock(L,'cans',x0+1.2,x1-1.2,y,24.4,k+g.x0*3)
  end
  -- two glass doors, with a handle each
  local n=2;local dw=(x1-x0-3)/n
  for i=0,n-1 do local a=x0+1.5+i*dw
   L.box(a,3,29,a+dw-.6,27.4,29.4,'inSteel',1.05)
   C.fx.glass=C.fx.glass or{}
   C.fx.glass[#C.fx.glass+1]={x0=a+.8,x1=a+dw-1.4,y0=3.8,y1=26.6,z=29.45}
   L.box(a+dw-2.4,12,29.4,a+dw-1.6,20,30.4,'inSteel',1.15)
  end
  -- a frost line and the compressor grille under the doors
  L.box(x0+1,2.4,29,x1-1,3,29.3,'ktSteel',1.0)
  for x=x0+2,x1-3,1.6 do L.box(x,.6,29.1,x+.8,2.2,29.3,'dark',.9)end
  -- the SALE board on the wall above
  local Lw=K.onWall(C,'N',0,0)
  Lw.box(x0+1,33,0,x1-1,45,1,'inLacquer',1.05)
  Lw.box(x0+1.6,33.6,1,x1-1.6,44.4,1.2,'white',1.1)
  ins(Lw,'SALE',(x0+x1)/2,35.6,1.2,1.25,'inLacquer',x1-x0-6)
  C.fx.glows[#C.fx.glows+1]={x=(x0+x1)/2,y=16,z=30,r=10,col='white',a=.12}
 end
 -- the glass display cabinets (E): potions on lit glass shelves
 do
  local gs=groups(C,'E')
  for _,g in ipairs(gs)do
   local x0,x1=g.x0*CS,(g.x1+1)*CS
   local L=F(0,0,0,0)
   L.box(x0+.6,0,16.2,x1-.6,10,28.6,'inWalnut',1.0)
   L.box(x0+.6,0,28.2,x1-.6,1.4,29,'dark',.8)
   for x=x0+2,x1-9,8 do L.box(x,2,28.6,x+7,9,28.9,'inWalnut',1.06);L.box(x+3,5.4,28.9,x+4,6.2,29.3,'lgGold',1.1)end
   L.box(x0+.2,10,16,x1-.2,11,29,'inWalnut',1.05)
   L.raw({x0+1,11,16.4},{x1-1,11,16.4},{x1-1,34,16.4},{x0+1,34,16.4},'inLamp',2)
   for k=0,2 do
    local y=16+k*7.6
    L.box(x0+1,y-.5,16.4,x1-1,y,27.6,'ktGlass',1.15)
    stock(L,k==1 and'balls'or'potions',x0+1.4,x1-1.4,y,22.6,k*5+g.x0)
   end
   L.box(x0+1,11,24.6,x1-1,11.6,27.6,'ktGlass',1.1)
   stock(L,'cartons',x0+1.4,x1-1.4,11.6,22,g.x0+9)
   L.box(x0+.2,34,16,x1-.2,36,29,'inWalnut',1.05)
   for x=x0+.2,x1-1,(x1-x0-1.4)/4 do L.box(x,11,28,x+1.2,34,29,'inWalnut',1.0)end
   C.fx.glass=C.fx.glass or{}
   C.fx.glass[#C.fx.glass+1]={x0=x0+1,x1=x1-1,y0=11,y1=34,z=28.7}
  end
 end
 ---------------------------------------------------------------- gondolas
 -- the gondolas (G): three shelves a side of real stock, price strips, a
 -- kick plate, end caps and a hanging aisle sign
 local aisle=0
 for _,g in ipairs(groups(C,'G'))do
  local x0,x1=g.x0*CS,(g.x1+1)*CS
  local z0,z1=g.y0*CS,(g.y1+1)*CS
  local single=g.y0==g.y1
  local L=F(0,0,0,0)
  local h=single and 26 or 28
  local za,zb=z0+(single and 2.5 or 3),z1-(single and 2.5 or 3)
  local zc=(za+zb)/2
  -- kick plate, back panel, uprights and the top rail
  local e0,e1=x0+4,x1-4   -- the end caps take 4 units at each end
  L.box(e0,0,za+.6,e1,1.6,zb-.6,'dark',.8)
  L.box(e0,1.6,zc-1,e1,h,zc+1,'inEnamel',1.0)
  for _,e in ipairs({e0,e1-1.2})do L.box(e,1.6,za,e+1.2,h,zb,'inEnamel',1.0)end
  L.box(e0-.4,h,za-.4,e1+.4,h+1.4,zb+.4,accent,1.05)
  local shelves=single and{1.6,9.6,17.6}or{1.6,10.2,18.8}
  for si,y in ipairs(shelves)do
   for _,side in ipairs({-1,1})do
    local zf=side>0 and zb or za
    local zi=zc+side*1
    L.box(e0+1.2,y-.6,math.min(zi,zf),e1-1.2,y,math.max(zi,zf),'inEnamel',1.05)
    -- the stock, facing out, a frame turned to this side
    local Ls=F(side>0 and e0 or e1,0,zf,side>0 and 0 or pi)
    local kind=KINDS[(aisle*2+si+(side>0 and 0 or 1))%#KINDS+1]
    stock(Ls,kind,1.4,e1-e0-1.4,y,-2.6,aisle*7+si*3+side)
    priceStrip(Ls,1.2,e1-e0-1.2,y-.1,.1,aisle+si)
   end
  end
  -- the end caps: a stack of cartons at each end, a poster on the upright
  for _,e in ipairs({{e0,-1},{e1,1}})do
   local Le=F(e[1],0,zc,e[2]>0 and pi/2 or -pi/2)
   local cols=floor((zb-za)/3.2)
   for row=0,2 do
    for k=0,cols-row-1 do
     local zz=(k-(cols-row-1)/2)*3.2
     carton(Le,zz,row*3.6,1.5,2.8,3.4,2.4,CART[(k+row+aisle)%#CART+1])
    end
   end
   Le.box(-(zb-za)/2+1,13,0,(zb-za)/2-1,22,.25,'white',1.12)
   Le.box(-(zb-za)/2+1.8,13.8,.25,(zb-za)/2-1.8,21.2,.35,({'red','blue','gold'})[aisle%3+1],1.1)
   ball(Le,0,15.2,1.6,2.0,({'red','blue','gold'})[(aisle+1)%3+1])
  end
  -- the aisle sign hanging from the ceiling
  do
   local E=C.part('ceilfx',{below=H+2})
   local Lc=K.frame(C,E,(x0+x1)/2,0,zc,0)
   Lc.rod({-8,H,0},{-8,H-5,0},.2,'inSteel');Lc.rod({8,H,0},{8,H-5,0},.2,'inSteel')
   Lc.box(-11,H-11,-.4,11,H-5,.4,accent,1.05)
   local label=({'BALLS','POTIONS','ITEMS','DRINKS'})[aisle%4+1]
   for _,sd in ipairs({1,-1})do
    local Lt=K.frame(C,E,(x0+x1)/2,0,zc+sd*.4,sd>0 and 0 or pi)
    ins(Lt,label,0,H-9.6,0,1.1,'white',20)
   end
  end
  aisle=aisle+1
 end
 ---------------------------------------------------------------- checkout
 -- the clerk's counter (C) round the clerk, the till (R), the belt, the
 -- bag rack and the front counter's baskets
 do
  local cells={};local rcy
  for _,c in ipairs(cellsOf(C,'R'))do rcy=c[2]end
  for _,c in ipairs(cellsOf(C,'C'))do cells[#cells+1]=c end
  for _,c in ipairs(cellsOf(C,'R'))do cells[#cells+1]=c end
  local L=F(0,0,0,0)
  for _,c in ipairs(cells)do
   local x0,x1,z0,z1=c[1]*CS,(c[1]+1)*CS,c[2]*CS,(c[2]+1)*CS
   local front=rcy and c[2]>rcy
   L.box(x0+.4,0,z0+.4,x1-.4,14,z1-.4,'inEnamel',1.0)
   L.box(x0,14,z0,x1,15.4,z1,accent,1.06)
   L.box(x0+.4,0,z1-1,x1-.4,1.6,z1-.4,'dark',.8)
   L.box(x0+.2,6.6,z1-.5,x1-.2,7.8,z1-.2,accent,1.0)
   if front then
    -- the front counter: a stack of baskets and a leaflet rack
    if c[1]%2==0 then
     for k=0,3 do
      local y=15.4+k*1.6
      L.box(x0+3,y,z0+3,x1-3,y+1.6,z1-3,'inSteel',1.0,{bottom=true,top=true})
      L.box(x0+3.4,y+1.4,z0+3.4,x1-3.4,y+1.6,z1-3.4,accent,1.05)
     end
     L.box(x0+4,22,z0+7.4,x1-4,25,z0+8.6,accent,1.05)
    else
     L.box(x0+3,15.4,z0+6,x1-3,16,z0+9,'inSteel',1.05)
     for k=0,2 do
      L.box(x0+3.4+k*3.2,16,z0+6.4,x0+6.2+k*3.2,22,z0+6.8,({'gold','blue','red'})[k+1],1.1)
      L.box(x0+4+k*3.2,17,z0+6.8,x0+5.6+k*3.2,20.6,z0+6.9,'white',1.15)
     end
     -- a bowl of free samples, and the promotional ball pyramid
     ball(L,(x0+x1)/2-3.2,15.4,z1-4.5,1.4,'red');ball(L,(x0+x1)/2+.6,15.4,z1-4.5,1.4,'blue')
     ball(L,(x0+x1)/2-1.3,17.6,z1-4.3,1.4,'gold')
    end
   end
  end
  for _,c in ipairs(cellsOf(C,'R'))do
   local Lr=F(c[1]*CS+8,15.4,c[2]*CS+8,-pi/2)
   -- the till faces the shopper (west to east here: the clerk is west)
   Lr.box(-5,0,-4,5,3,4,'inEnamel',1.0)
   Lr.quad({-4.6,3,-1},{4.6,3,-1},{4.6,2.2,3.6},{-4.6,2.2,3.6},'lvSlate',1.0)
   for r=0,2 do for k=0,3 do Lr.box(-3.6+k*2,2.5+(2-r)*.25,-.2+r*1.2,-2.4+k*2,2.9+(2-r)*.25,.8+r*1.2,k==3 and'red'or'ktPearl',1.05)end end
   Lr.box(-4,3,-4,4,9,-1.6,'inEnamel',1.0)
   Lr.raw({-3.2,4.4,-1.55},{3.2,4.4,-1.55},{3.2,8.2,-1.55},{-3.2,8.2,-1.55},'inScreen',3)
   Lr.box(1.8,9,-3.4,3.4,10.6,-2.2,'white',1.1)
   -- the card reader and the bagging rack beside it
   Lr.box(-7.4,0,-2,-5.4,1.2,1.2,'dark',1.0);Lr.raw({-7.1,1.2,-1.6},{-5.7,1.2,-1.6},{-5.7,1.2,.6},{-7.1,1.2,.6},'inScreen',3)
   Lr.rod({-6.6,0,4.6},{-6.6,10.5,4.6},.3,'inSteel');Lr.rod({-6.6,0,-4.6},{-6.6,10.5,-4.6},.3,'inSteel')
   Lr.rod({-6.6,10.5,4.8},{-6.6,10.5,-4.8},.25,'inSteel')
   for k=0,3 do Lr.box(-6.95+k*.22,2.4-k*.3,-3.8,-6.75+k*.22,9.8,3.8,k%2==0 and'white'or'ktPearl',1.05)end
   Lr.box(-7.4,9.4,-3.4,-6.2,10,3.4,'white',1.1)
   -- the OPEN lamp over the till
   local E=C.part('ceilfx',{below=H+2})
   local Lo=K.frame(C,E,c[1]*CS+8,0,c[2]*CS+8,0)
   Lo.rod({0,H,0},{0,H-6,0},.2,'inSteel')
   Lo.box(-5,H-11,-.6,5,H-6,.6,'inEnamel',1.05)
   Lo.raw({-4.4,H-10.4,.65},{4.4,H-10.4,.65},{4.4,H-6.6,.65},{-4.4,H-6.6,.65},'inLamp',2)
   Lo.raw({4.4,H-10.4,-.65},{-4.4,H-10.4,-.65},{-4.4,H-6.6,-.65},{4.4,H-6.6,-.65},'inLamp',2)
   C.fx.glows[#C.fx.glows+1]={x=c[1]*CS+8,y=H-8,z=c[2]*CS+8,r=8,col='white',a=.10}
  end
 end
 -- a mat, the door
 local d0,d1=doorSpan(C)
 if d0 then
  K.frontDoor(C,d0,d1,{view=T.view==2 and 2 or 1,frame='white',leaf='ktPearl'})
  K.rug(C,C.part('floor'),d0+2,D-12,d1-2,D-1,{field=accent,border='dark',bw=1,y=.12})
 end
 -- the east wall: a pegboard of hanging goods (TEST178: carded balls,
 -- sprays and ropes on their hooks) and a poster
 do
  local Lw=K.onWall(C,'E',0,0)
  Lw.box(26,18,0,70,42,.6,'ktSandstone',1.0)
  for x=28,69,2.4 do for y=20,41,2.4 do Lw.box(x-.2,y-.2,.6,x+.2,y+.2,.75,'dark',.6)end end
  for i=0,7 do for j=0,2 do
   local x,y=29+i*5.4,23+j*6
   Lw.rod({x,y+3.2,.6},{x,y+3.2,2.4},.15,'inSteel')
   local k=(i+j)%4
   if k==0 then
    Lw.box(x-1.8,y-1.4,1.6,x+1.8,y+3.4,1.8,'white',1.12)
    Lw.box(x-1.5,y+2.2,1.8,x+1.5,y+3.0,1.9,'red',1.1)
    ball(Lw,x,y-.2,2.4,1.0,({'red','blue','gold'})[(i+j)%3+1])
   elseif k==1 then
    can(Lw,x,y-1.2,1.8,CANS[(i+j)%#CANS+1],4.2)
   elseif k==2 then
    Lw.box(x-1.8,y-1.4,1.6,x+1.8,y+3.4,1.8,'white',1.12)
    rope(Lw,x,y-1.2,2.0)
   else
    Lw.box(x-1.8,y-1.4,1.6,x+1.8,y+3.4,1.8,({'gold','blue','flower'})[(i+j)%3+1],1.1)
    Lw.box(x-1.2,y,1.8,x+1.2,y+2.4,1.9,'white',1.15)
   end
  end end
  local Lw2=K.onWall(C,'W',0,0)
  K.picture(C,Lw2,40,64,26,42,'pokemon',{frame='blue',mat=.8,ground='ktPearl',body=({'gold','flower','ktCopper','leaf'})[#C.city%4+1]})
  -- the town's own picture by the door (each Mart hangs a local scene)
  local art=CENTER_ART[C.city]
  if art then K.picture(C,Lw2,12,32,26,40,art[2],{frame=T.wood=='white'and'inOak'or T.wood})end
  -- the price list by the till
  Lw2.box(70,24,0,86,44,.5,'lvSlate',.9)
  for i=0,6 do Lw2.box(72,26.5+i*2.4,.5,72+6+rh(i,1,2)*5,27.6+i*2.4,.6,'white',1.15);Lw2.box(81,26.5+i*2.4,.5,84,27.6+i*2.4,.6,'gold',1.2)end
 end
 -- strip lights
 do
  local E=C.part('ceilfx',{below=H+2})
  local L=K.frame(C,E,0,0,0,0)
  for z=S.n+20,D-16,36 do
   L.raw({16,H-.4,z-2.5},{W-16,H-.4,z-2.5},{W-16,H-.4,z+2.5},{16,H-.4,z+2.5},'inPanel',1)
   L.box(15,H-1.2,z-3.2,W-15,H-.4,z-2.5,'white',1);L.box(15,H-1.2,z+2.5,W-15,H-.4,z+3.2,'white',1)
   C.addLight(W*.3,H-6,z,60,.14);C.addLight(W*.7,H-6,z,60,.14)
  end
 end
 C.fx.ambience={shop=.3}
end

------------------------------------------------------------------ HOUSES
-- Most houses share one plan: a wide case top-left (B), a narrow one top-
-- right (b), a table with four stools, a picture and a window, two corner
-- plants, the door. Each house furnishes it as its own: what the cases
-- hold, the table and its setting, the seats, the corners, the walls.
-- seat/table: the heights actors sit and items stand at (see support).
local HOUSES={
 BLUES_HOUSE={left='dresser',right='clock',table='dining',cloth='white',setting='townmap',seat='spindle',
  corner={'flowers','fern'},side='lamp',pic='meadow',walls={'clock','photos'},rug='oval',lamp='pendant',fire=false},
 VIRIDIAN_NICKNAME_HOUSE={left='books',right='perch',table='trestle',setting='books',seat='spindle',
  corner={'fern','ficus'},side='basket',pic='tree',walls={'antlers','pennant'},rug='checks',lamp='pendant'},
 PEWTER_NIDORAN_HOUSE={left='rocks',right='cabinet',table='stone',setting='fruit',seat='log',
  corner={'cactus','snake'},side='lamp',pic='mountain',walls={'hearth'},rug='plain',lamp='lantern'},
 PEWTER_SPEECH_HOUSE={left='fossils',right='books',table='stone',setting='lamp',seat='log',
  corner={'snake','fern'},side='pick',pic='fossil',walls={'map','clock'},rug='stripes',lamp='lantern'},
 CERULEAN_TRADE_HOUSE={left='shells',right='aquarium',table='round',cloth='ktPearl',setting='tea',seat='spindle',
  corner={'monstera','fern'},side='lamp',pic='sea',walls={'mirror','photos'},rug='stripes',lamp='pendant'},
 VERMILION_PIDGEY_HOUSE={left='models',right='perch',table='trestle',setting='letters',seat='stool',
  corner={'palm','fern'},side='globe',pic='ship',walls={'wheel','porthole'},rug='stripes',lamp='lantern'},
 VERMILION_OLD_ROD_HOUSE={left='tackle',right='rods',table='trestle',setting='fish',seat='stool',
  corner={'fern','snake'},side='bucket',pic='fish',walls={'mounted','net'},rug='plain',lamp='lantern'},
 VERMILION_TRADE_HOUSE={left='books',right='clock',table='dining',setting='chart',seat='spindle',
  corner={'palm','fern'},side='globe',pic='sea',walls={'anchor','porthole'},rug='medallion',lamp='pendant'},
 LAVENDER_CUBONE_HOUSE={left='shrine',right='cabinet',table='dining',cloth='lgPlum',setting='candles',seat='spindle',
  corner={'orchid','fern'},side='candles',pic='portrait',walls={'photos','candles'},rug='plain',lamp='pendant',dim=true},
 MR_FUJIS_HOUSE={left='toys',right='books',table='round',cloth='white',setting='flute',seat='stool',
  corner={'flowers','fern'},side='toys',pic='pokemon',walls={'drawings','clock'},rug='checks',lamp='pendant'},
 NAME_RATERS_HOUSE={left='scrolls',right='books',table='desk',setting='quill',seat='spindle',
  corner={'fern','orchid'},side='lamp',pic='portrait',walls={'names','clock'},rug='medallion',lamp='pendant'},
 SAFFRON_PIDGEY_HOUSE={left='records',right='fridge',table='glass',setting='vase',seat='modern',
  corner={'snake','monstera'},side='lamp',pic='abstract',walls={'tv','photos'},rug='plain',lamp='modern'},
 MR_PSYCHICS_HOUSE={left='crystal',right='books',table='round',cloth='lgPlum',setting='crystal',seat='stool',
  corner={'orchid','snake'},side='candles',pic='night',walls={'stars','spoons'},rug='oval',lamp='pendant',dim=true},
 FUCHSIA_BILLS_GRANDPAS_HOUSE={left='tansu',right='scrollstand',table='kotatsu',setting='teapot',seat='zabuton',
  corner={'bonsai','bamboo'},side='lantern',pic='pagoda',walls={'scroll','shoji'},rug=false,lamp='paper',japan=true},
 ROUTE_2_TRADE_HOUSE={left='dresser',right='woodstove',table='trestle',setting='bread',seat='log',
  corner={'fern','tree'},side='logs',pic='tree',walls={'antlers','quilt'},rug='checks',lamp='lantern'},
 DAYCARE={left='toys',right='cabinet',table='round',cloth='gold',setting='blocks',seat='stool',
  corner={'flowers','fern'},side='balls',pic='pokemon',walls={'drawings','bunting'},rug='checks',lamp='pendant'},
 ROUTE_12_SUPER_ROD_HOUSE={left='tackle',right='rods',table='trestle',setting='fish',seat='stool',
  corner={'fern','snake'},side='bucket',pic='fish',walls={'mounted','net'},rug='stripes',lamp='lantern'},
 ROUTE_16_FLY_HOUSE={left='books',right='perch',table='round',setting='feathers',seat='spindle',
  corner={'tree','fern'},side='birdcage',pic='bird',walls={'feathers','clock'},rug='oval',lamp='pendant'},
 VIRIDIAN_SCHOOL_HOUSE={school=true,right='books',corner={'fern','ficus'},side='globe',walls={'alphabet','charts'},seat='spindle'},
 CELADON_MANSION_ROOF_HOUSE={school=true,right='cabinet',corner={'flowers','ficus'},side='lamp',walls={'photos','charts'},seat='spindle',eevee=true},
 CERULEAN_TRASHED_HOUSE={left='books',right='books',table='dining',setting='none',seat='spindle',corner={'fern','fern'},
  pic='sea',walls={'tilted'},trashed=true},
}
M.HOUSES=HOUSES
-- the heights actors sit at (stools) and items stand at (tables)
function M.support(id,ch)
 local h=HOUSES[id]
 if h then
  if ch=='s'then return h.seat=='zabuton'and 1.6 or 6 end
  if ch=='T'then return h.table=='kotatsu'and 8.4 or 10 end
 end
 if ch=='s'then return 6 end
 if ch=='T'then return 10 end
 return nil
end

local function caseL(C,T,Rp,F,kind,x0,x1,seed)
 -- the wide case: stands in row 1 against the north wall (z 16..31)
 local cx=(x0+x1)/2;local w=x1-x0-1.4
 local L=F(cx,0,24,0)
 local wd=T.wood=='white'and'white'or T.wood
 if kind=='books'or kind=='rocks'or kind=='fossils'or kind=='shells'or kind=='models'or kind=='toys'or kind=='scrolls'or kind=='records'then
  local items=({books='books',rocks='rocks',fossils='fossils',shells='shells',models='curios',toys='toys',scrolls='scrolls',records='books'})[kind]
  K.bookcase(L,w,38,14,{wood=wd,items=items,doors=kind~='books',glass=kind=='shells'or kind=='models'or kind=='fossils',seed=seed,
   rowItems=kind=='books'and{'books','books','mixed','books'}or nil})
  if kind=='records'then
   -- a record player on top, and a speaker
   L.box(-8,40.2,-4,4,41.6,5,'inWalnut',1);L.disc(-2,41.7,.5,3.4,'dark',16,'y');L.disc(-2,41.8,.5,1,'red',10,'y')
   L.rod({2.6,42,-2.6},{.4,42.2,1.4},.25,'inSteel')
   L.box(6,40.2,-4,11,48,4,'inWalnut',1);L.disc(8.5,44.5,4.05,1.8,'dark',12);L.disc(8.5,41.8,4.05,.9,'dark',10)
  end
 elseif kind=='dresser'or kind=='tansu'or kind=='shrine'or kind=='crystal'or kind=='tackle'then
  if kind=='tansu'then
   -- a Japanese step chest (kaidan dansu)
   L.box(-w/2,0,-7,w/2,14,7,'inWalnut',1.0)
   L.box(-w/2,14,-7,0,26,7,'inWalnut',1.0)
   L.box(-w/2,26,-7,-w/4,36,7,'inWalnut',1.0)
   for _,b in ipairs({{-w/2,w/2,0,14},{-w/2,0,14,26},{-w/2,-w/4,26,36}})do
    local n=max(1,floor((b[2]-b[1])/7));local dw=(b[2]-b[1])/n
    for i=0,n-1 do local a=b[1]+i*dw
     L.box(a+.4,b[3]+.6,7,a+dw-.4,b[4]-.6,7.3,'inOak',1.05)
     L.box(a+dw/2-1,(b[3]+b[4])/2-.3,7.3,a+dw/2+1,(b[3]+b[4])/2+.3,7.8,'dark',1)
    end
   end
   -- things on the steps: a vase, a doll, a lantern
   L.cyl(w/4,14,20,0,1.4,2,'ktCopper',10);L.cyl(w/4,20,21,0,1.2,1.2,'ktCopper',10)
   K.plant(F(cx+w/4,20.5,24,0),'flowers',{s=.5,potR=.01,potH=.01,colors={'white','flower'}})
   K.lamp(C,F(cx-w/8,26,24,0),'lantern',{})
  elseif kind=='shrine'then
   -- a family altar: a dark cabinet with doors open on a shrine, candles,
   -- incense, flowers and a photograph
   K.cabinet(L,w,14,14,{wood='lvWalnut',drawers=3,top='lvWalnut'})
   L.box(-w/2+2,14,-6,w/2-2,34,6,'lvWalnut',1.0)
   L.box(-w/2+2.6,15,-5.4,w/2-2.6,32,5,'lgGold',.95)
   L.box(-w/2+3,15,-5,w/2-3,16,4.6,'lgGold',1.1)
   L.box(-w/2+1.4,34,-6.6,w/2-1.4,36,6.6,'lvWalnut',1.05)
   L.quad({-w/2+1,36,-6.6},{w/2-1,36,-6.6},{0,40,0},{0,40,0},'lvWalnut',1.0)
   -- doors swung open
   L.box(-w/2+2,14,6,-w/2+2.6,32,13,'lvWalnut',1.0);L.box(w/2-2.6,14,6,w/2-2,32,13,'lvWalnut',1.0)
   -- the photo, the candles, incense
   L.box(-2.6,15,-4,2.6,22,-3.4,'lgGold',1.1);L.box(-2,15.6,-3.4,2,21.4,-3.2,'ktOchre',.9)
   K.lamp(C,F(cx-6,14,26,0),'candle',{h=4,col='violet'})
   K.lamp(C,F(cx+6,14,26,0),'candle',{h=4})
   L.cyl(0,14,15.4,3,1.4,1.6,'lgBronze',10);for k=0,2 do L.rod({-.6+k*.6,15.4,3},{-.6+k*.6,20,3},.1,'ktOchre')end
   K.plant(F(cx+9,14,28,0),'flowers',{s=.45,potR=.01,potH=.01,colors={'white','lgPlum'}})
   K.plant(F(cx-9,14,28,0),'flowers',{s=.45,potR=.01,potH=.01,colors={'white','lgPlum'}})
  elseif kind=='crystal'then
   K.bookcase(L,w,38,14,{wood='lvWalnut',items='curios',glass=true,seed=seed,rowItems={'curios','jars','curios'}})
   L.cyl(0,40.2,41.2,0,2.4,2.8,'lgGold',12)
   L.sphere(0,44.4,0,3.4,3.4,3.4,'lgAmethyst',12,8)
   C.fx.glows[#C.fx.glows+1]={x=cx,y=44,z=24,r=9,col='violet',a=.3}
  elseif kind=='tackle'then
   -- a gear wall: tackle boxes below, lures on a board, a coiled net
   K.cabinet(L,w,14,14,{wood=wd,drawers=3,rows=2})
   K.shelfItems(L,'tackle',-w/2,w/2,14,20,-6,6,seed)
   L.box(-w/2,14,-7,w/2,40,-6,'inPine',1.0)
   for i=0,9 do local lx=-w/2+3+i*2.8;local ly=24+rh(i,seed,1)*12
    L.rod({lx,ly+3,-5.8},{lx,ly,-5.8},.08,'inSteel')
    L.box(lx-.7,ly-1.6,-5.8,lx+.7,ly,-4.8,({'red','gold','leaf','flower','white'})[i%5+1],1.15)end
   L.ring(w/4,30,-5.6,4,5,'ktOchre',14,1)
  else
   -- the dresser: plates on a rack over a cupboard
   K.cabinet(L,w,14,14,{wood=wd,drawers=2,rows=2,top=wd})
   L.box(-w/2,14,-7,w/2,38,-5,wd,1.0)
   L.box(-w/2,14,-7,-w/2+1,38,2,wd,1.0);L.box(w/2-1,14,-7,w/2,38,2,wd,1.0)
   L.box(-w/2-.4,38,-7.4,w/2+.4,40,3,wd,1.05)
   for k,y in ipairs({22,30})do
    L.box(-w/2+1,y-.6,-5,w/2-1,y,2,wd,1.02)
    K.shelfItems(L,k==1 and'plates'or'jars',-w/2+1.4,w/2-1.4,y,y+7.4,-5,2,seed+k)
   end
   K.shelfItems(L,'jars',-w/2+2,w/2-2,14,20,-3,5,seed+5)
  end
 end
end
local function caseR(C,T,F,kind,x0,x1,seed)
 local cx=(x0+x1)/2
 local L=F(cx,0,24,0)
 local bw=x1-x0-2
 local wd=T.wood=='white'and'white'or T.wood
 if kind=='clock'then
  K.grandfather(L,{wood=wd=='white'and'inOak'or wd})
 elseif kind=='books'then
  K.bookcase(L,bw,38,13,{wood=wd,items='books',seed=seed,rowItems={'books','curios','books','books'}})
 elseif kind=='cabinet'then
  K.cabinet(L,14,18,12,{wood=wd,drawers=1,rows=3})
  L.box(-6,18,-5,6,34,-4,wd,1)
  K.picture(C,F(cx,22,19.4,0),-4.6,4.6,0,9,'flowers',{frame='lgGold',mat=.8})
  K.lamp(C,F(cx-3,18,25,0),'table',{base='ktPearl'})
 elseif kind=='aquarium'then
  K.cabinet(L,14.4,12,12,{wood=wd,drawers=1,rows=1})
  L.box(-7,12,-6,7,13,6,'inSteel',1.05)
  L.raw({-6.6,13,5.6},{6.6,13,5.6},{6.6,30,5.6},{-6.6,30,5.6},'inAqua',1)
  L.raw({6.6,13,-5.6},{6.6,13,5.6},{6.6,30,5.6},{6.6,30,-5.6},'inAqua',1)
  L.raw({-6.6,13,-5.6},{-6.6,13,5.6},{-6.6,30,5.6},{-6.6,30,-5.6},'inAqua',1)
  L.raw({-6.6,30,-5.6},{6.6,30,-5.6},{6.6,30,5.6},{-6.6,30,5.6},'inAqua',1)
  L.box(-7,30,-6,7,32,6,'inSteel',1.05)
  for i=0,4 do L.box(-5+i*2.4,13,-4+rh(i,1,1)*8,-4+i*2.4,14+rh(i,2,1)*6,-3+rh(i,1,1)*8,'leaf',1.1)end
  C.fx.fish=C.fx.fish or{}
  C.fx.fish[#C.fx.fish+1]={x=cx,y=21,z=24,w=11,h=12,d=8}
  C.fx.glows[#C.fx.glows+1]={x=cx,y=22,z=31,r=10,col='cyan',a=.14}
 elseif kind=='perch'then
  -- a tall bird perch with a seed cup and a little house
  L.cyl(0,0,1,0,5,5,'inWalnut',12)
  L.cyl(0,1,30,0,.6,.5,'inOak',6,false)
  L.rod({-5,22,0},{5,22,0},.4,'inOak');L.rod({-4,28,0},{4,28,0},.35,'inOak')
  L.box(-3,30,-3,3,35,3,'inPine',1);L.quad({-3.6,35,-3.6},{3.6,35,-3.6},{0,39,0},{0,39,0},'red',1);L.quad({-3.6,35,3.6},{3.6,35,3.6},{0,39,0},{0,39,0},'red',1.05)
  L.disc(0,32.5,3.05,1.2,'dark',10)
  L.cyl(4,21.2,22.4,0,1,1.2,'white',8)
 elseif kind=='fridge'then
  L.box(-7,0,-6,7,36,6,'inEnamel',1.02)
  L.box(-6.6,24,6,6.6,35.4,6.4,'inEnamel',1.06);L.box(-6.6,.6,6,6.6,23.4,6.4,'inEnamel',1.05)
  L.box(5,26,6.4,5.8,32,7,'inSteel',1.1);L.box(5,14,6.4,5.8,22,7,'inSteel',1.1)
  for i,c in ipairs({'red','gold','blue'})do L.box(-5+i*2.6,28,6.4,-4+i*2.6,29,6.8,c,1.1)end
  L.box(-4,16,6.4,0,20,6.5,'white',1.15)
 elseif kind=='rods'then
  -- a rack of rods leaning in the corner and a creel
  L.box(-7,0,-6,7,2,6,'inWalnut',1)
  for i=0,4 do local x=-5.6+i*2.8
   L.rod({x,2,0},{x+(i-2)*.6,40,-4},.25,i%2==0 and'inWalnut'or'ktSteel')
   L.cyl(x+.2,8,9.6,.4,.9,.9,'inSteel',6)
  end
  L.box(-6.6,2,2,-1,8,6,'ktOchre',1);L.box(-6.6,8,2,-1,8.6,6,'inWalnut',1)
 elseif kind=='woodstove'then
  L.box(-6.6,0,-5,6.6,1.2,7,'lvStone',1)
  L.box(-5,1.2,-4,5,13,5,'ktBasalt',.9)
  L.box(-5.4,13,-4.4,5.4,14,5.4,'ktBasalt',1)
  L.box(-3.4,3,5,3.4,10,5.3,'dark',.6)
  L.raw({-2.8,3.6,5.35},{2.8,3.6,5.35},{2.8,9.4,5.35},{-2.8,9.4,5.35},'lgLava',1)
  L.cyl(0,14,48,-1,1.4,1.4,'ktBasalt',8,false)
  local p=L.P({0,6,6});C.fx.fires[#C.fx.fires+1]={x=p[1],y=4,z=p[3]-1,s=.45}
  C.addLight(p[1],8,p[3],40,.32)
  L.cyl(-2.5,14,16,0,1.6,1.2,'lvSlate',10);L.box(-3.4,16,-.3,-2.8,17,.3,'lvSlate',1)
 elseif kind=='scrollstand'then
  -- a tall cabinet with a hanging scroll and an ikebana
  L.box(-7,0,-5,7,10,5,'inWalnut',1)
  L.box(-7.4,10,-5.4,7.4,11,5.4,'inWalnut',1.05)
  L.box(-4,14,-5,4,40,-4.6,'cream',1.1);L.box(-4.6,39.6,-5.2,4.6,40.6,-4.2,'inWalnut',1);L.box(-4.6,13.4,-5.2,4.6,14.4,-4.2,'inWalnut',1)
  for i=0,5 do L.box(-1,18+i*3.4,-4.5,1,20+i*3.4,-4.4,'dark',.7)end
  L.cyl(0,11,13,1,2,1.6,'ktBasalt',10)
  for i=0,4 do L.rod({0,13,1},{(i-2)*1.6,19+rh(i,3,3)*5,1+(i%2)},.12,'leaf')end
  L.box(-.8,22,.4,.8,23.6,2,'flower',1.15);L.box(1.6,20,1,3,21.4,2.2,'white',1.15)
 end
end
-- a corner group in two blocked cells (rows 6-7 against a side wall):
-- the plant in front and a side piece behind it
local function corner(C,T,F,cx,kindPlant,side,seed,west)
 local x=cx*CS+8
 local zPot,zSide=7*CS+7,6*CS+7
 local pot=T.pot
 K.plant(F(x,0,zPot,0),kindPlant,{s=1.25,pot=pot,seed=seed})
 local L=F(x,0,zSide,west and pi/2 or -pi/2)
 if side=='lamp'then
  K.cabinet(L,10,9,9,{wood=T.wood=='white'and'white'or T.wood,drawers=1,legs=true})
  K.lamp(C,F(x,9,zSide,0),'table',{base=T.accent=='blue'and'ktPearl'or'cream'})
 elseif side=='basket'then
  L.cyl(0,0,7,0,4,4.6,'ktOchre',12,false);L.ring(0,7,0,4.4,4.8,'ktOchre',12)
  for i=0,4 do L.sphere((rh(i,1,1)-.5)*4,7.4,(rh(i,2,1)-.5)*4,1.4,1,1.4,({'red','gold','leaf'})[i%3+1],6,3)end
 elseif side=='globe'then
  L.cyl(0,0,1,0,3.4,3.4,'inWalnut',12);L.cyl(0,1,11,0,.5,.5,'inWalnut',6,false)
  L.sphere(0,15,0,4,4,4,'ktMarine',12,8);L.sphere(0,15,0,4.05,1.4,4.05,'leaf',12,3)
  L.ring(0,15,0,4.4,4.9,'lgBronze',16,1.1)
 elseif side=='pick'then
  L.box(-4,0,-4,4,7,4,'inWalnut',1);L.rod({-2,7,0},{2,18,0},.4,'inWalnut');L.box(-2,16,-.4,5,17.2,.4,'inSteel',1.1)
  L.sphere(0,9,0,3.4,2.4,3.4,'gold',8,4)
 elseif side=='bucket'then
  L.cyl(0,0,7,0,3.2,3.8,'ktSteel',12,false);L.cyl(0,6.4,6.6,0,3.6,3.6,'ktGlass',12)
  L.rod({-3.6,7,0},{0,11,0},.2,'inSteel');L.rod({0,11,0},{3.6,7,0},.2,'inSteel')
 elseif side=='candles'then
  K.cabinet(L,10,10,9,{wood='lvWalnut',drawers=1,legs=true})
  for i=0,2 do K.lamp(C,F(x-2.6+i*2.6,10,zSide+(i%2)*1.6,0),'candle',{h=2+i*1.4,col=i==1 and'violet'or nil})end
 elseif side=='toys'or side=='balls'then
  L.box(-5,0,-5,5,6,5,'red',1);L.box(-5.2,6,-5.2,5.2,6.6,5.2,'gold',1)
  for i=0,3 do local c=({'red','blue','gold','leaf'})[i+1]
   L.sphere(-2.4+(i%2)*4.8,8,-2+floor(i/2)*4,1.8,1.8,1.8,c,8,5)end
  if side=='balls'then L.sphere(0,9.2,0,2,2,2,'inLacquer',10,5)end
 elseif side=='lantern'then
  L.box(-3,0,-3,3,1,3,'lvStone',1);L.box(-1.2,1,-1.2,1.2,8,1.2,'lvStone',1)
  L.box(-3.4,8,-3.4,3.4,9,3.4,'lvStone',1);L.box(-2.4,9,-2.4,2.4,13,2.4,'inShoji',1)
  L.quad({-4.2,13,-4.2},{4.2,13,-4.2},{0,16,0},{0,16,0},'lvStone',1);L.quad({-4.2,13,4.2},{4.2,13,4.2},{0,16,0},{0,16,0},'lvStone',1.05)
  local p=L.P({0,11,0});C.addLight(p[1],p[2],p[3],24,.16)
 elseif side=='logs'then
  for i=0,5 do local yy=1.6+floor(i/3)*3;local xx=-3.4+(i%3)*3.4
   L.cyl(xx,yy-1.6,yy+1.6,0,1.5,1.5,'lgBark',8,'inPine',0)end
 elseif side=='birdcage'then
  L.cyl(0,0,1,0,3,3,'inWalnut',10);L.cyl(0,1,14,0,.4,.4,'inWalnut',6,false)
  L.cyl(0,14,15,0,4.4,4.4,'lgGold',12)
  for i=0,11 do local a=i*pi/6;L.rod({cos(a)*4.2,15,sin(a)*4.2},{cos(a)*4.2,24,sin(a)*4.2},.12,'lgGold')end
  L.cyl(0,24,27,0,4.4,.4,'lgGold',12)
  L.rod({-3,18,0},{3,18,0},.25,'inWalnut');L.sphere(0,19.6,0,1.4,1.5,1.2,'ktOchre',6,4)
 end
end
-- the table, its setting and the four seats round it
local function tableSet(C,T,Hh,F,tb,stools)
 local x0,x1,z0,z1=tb.x0*CS,(tb.x1+1)*CS,tb.y0*CS,(tb.y1+1)*CS
 local cx,cz=(x0+x1)/2,(z0+z1)/2
 local top=Hh.table=='kotatsu'and 8.4 or 10
 local w,d=x1-x0-4,z1-z0-4
 local L=F(cx,0,cz,0)
 local wd=T.wood=='white'and'inPine'or T.wood
 K.table(L,w,d,top,Hh.table,{wood=wd,cloth=Hh.cloth,runner=Hh.table=='trestle'and'white'or nil,quilt=T.rug[1]})
 local y=top+.1
 local st=Hh.setting
 if st=='tea'or st=='teapot'then
  local L2=F(cx-4,y,cz-2,0)
  L2.cyl(0,0,3.2,0,1.8,2.2,st=='teapot'and'ktBasalt'or'white',10);L2.cyl(0,3.2,3.8,0,1.4,.6,st=='teapot'and'ktBasalt'or'white',10)
  L2.rod({2,2,0},{3.6,3.4,0},.3,st=='teapot'and'ktBasalt'or'white')
  for i=0,1 do local L3=F(cx+3+i*4,y,cz+2-i*4,0);L3.cyl(0,0,1.6,0,1.1,1.3,st=='teapot'and'cream'or'white',8);L3.disc(0,.05,0,1.9,'white',10,'y')end
  if st=='tea'then K.plant(F(cx+6,y,cz-5,0),'flowers',{s=.5,potR=1,potH=1.6,pot='white'})end
 elseif st=='fruit'then
  local L2=F(cx,y,cz,0)
  L2.cyl(0,0,1.6,0,2.4,4,'white',12)
  for i=0,6 do local a=i*.9;L2.sphere(cos(a)*2,2.2+(i%3)*.5,sin(a)*2,1.3,1.3,1.3,({'red','gold','leaf','red','ktOchre'})[i%5+1],6,4)end
 elseif st=='townmap'then
  -- Daisy's gift: the Town Map, unrolled
  local L2=F(cx-2,y,cz,0)
  L2.box(-7,0,-5,7,.15,5,'ktMarine',1.05)
  for i=0,5 do L2.box(-6+rh(i,1,1)*9,.15,-4+rh(i,2,1)*6,-3+rh(i,1,1)*9,.25,-2+rh(i,2,1)*6,'leaf',1.05)end
  L2.cyl(-7,.8,.8,0,.8,.8,'ktOchre',8);L2.cyl(7,.8,.8,0,.8,.8,'ktOchre',8)
  local L3=F(cx+7,y,cz+4,0);L3.cyl(0,0,1.6,0,1.1,1.3,'white',8)
 elseif st=='books'or st=='quill'then
  for i=0,2 do local L2=F(cx-4+i*1,y+i*1.2,cz-2+i*.6,i*.3);L2.box(-3,0,-2,3,1.2,2,({'red','navy','green'})[i+1],1.05)end
  if st=='quill'then
   local L2=F(cx+4,y,cz+1,0);L2.box(-3,0,-4,3,.1,4,'cream',1.15)
   L2.cyl(3.6,0,1.6,-2,.9,.9,'dark',8);L2.rod({3.6,1.4,-2},{1,7,-1},.2,'white')
   for k=0,3 do L2.box(-2.4,.12,-3+k*1.6,1.4,.18,-2.6+k*1.6,'dark',.8)end
  end
 elseif st=='candles'then
  for i=0,2 do K.lamp(C,F(cx-5+i*5,y,cz+(i%2)*2,0),'candle',{h=3+i,col=i==2 and'violet'or nil})end
  K.plant(F(cx,y,cz-3,0),'flowers',{s=.5,potR=1,potH=1.8,pot='white',colors={'white','lgPlum'}})
 elseif st=='flute'then
  local L2=F(cx,y,cz,0.4);L2.cyl(-6,.6,.6,0,.6,.6,'ktCopper',8);L2.rod({-6,.6,0},{5,.6,0},.55,'ktCopper')
  for k=0,4 do L2.disc(-3+k*1.8,1.2,0,.25,'dark',6,'y')end
  K.plant(F(cx+5,y,cz-3,0),'flowers',{s=.55,potR=1.2,potH=2,pot='ktPearl'})
 elseif st=='vase'then
  local L2=F(cx,y,cz,0);L2.cyl(0,0,5,0,1.2,.8,'inEnamel',10)
  for i=0,2 do L2.rod({0,5,0},{(i-1)*2.4,10+i,(i%2)},.12,'leaf');L2.sphere((i-1)*2.4,10.4+i,(i%2),1,1,1,'white',6,4)end
 elseif st=='crystal'then
  local L2=F(cx,y,cz,0);L2.cyl(0,0,1.4,0,2.6,2,'lgGold',12);L2.sphere(0,4.4,0,3.2,3.2,3.2,'lgAmethyst',12,8)
  C.fx.glows[#C.fx.glows+1]={x=cx,y=y+4,z=cz,r=10,col='violet',a=.35}
  for i=0,3 do local a=i*pi/2+.4;local L3=F(cx+cos(a)*6,y,cz+sin(a)*5,a);L3.box(-.3,0,-1.6,.3,.25,1.6,'lgSilver',1.2)end
 elseif st=='letters'then
  for i=0,3 do local L2=F(cx-4+i*2.6,y+i*.05,cz-1+(i%2)*2,i*.5);L2.box(-2,0,-1.4,2,.12,1.4,'cream',1.15);L2.box(-.4,.12,-.2,.4,.2,.2,'red',1.1)end
  local L3=F(cx+5,y,cz-3,0);L3.cyl(0,0,1.6,0,1.1,1.3,'white',8)
 elseif st=='fish'then
  local L2=F(cx,y,cz,0);L2.box(-6,0,-3,6,.3,3,'inWalnut',1)
  L2.quad({-5,.4,0},{0,.4,2.2},{4,.4,0},{0,.4,-2.2},'ktCopper',1.1);L2.quad({4,.4,0},{6,.4,1.8},{6,.4,-1.8},{4,.4,0},'ktCopper',1)
  local L3=F(cx-6,y,cz+4,0);L3.box(-2,0,-1.4,2,2,1.4,'ktSteel',1);L3.disc(0,2.05,0,.8,'red',8,'y')
 elseif st=='chart'then
  local L2=F(cx,y,cz,0);L2.box(-8,0,-6,8,.12,6,'ktSandstone',1.05)
  L2.box(-6,.12,-4,-1,.2,1,'ktMarine',1);L2.box(1,.12,-2,6,.2,4,'ktMarine',1)
  L2.rod({-4,.3,-3},{5,.3,3},.15,'red');L2.cyl(5,.2,2,-4,.5,.5,'lgBronze',6)
 elseif st=='lamp'then
  K.lamp(C,F(cx,y,cz,0),'table',{base='lgBronze'})
 elseif st=='bread'then
  local L2=F(cx,y,cz,0);L2.box(-5,0,-3,5,.6,3,'inOak',1.05)
  L2.sphere(-1,1.8,0,3.4,1.6,2.2,'ktOchre',8,4);L2.box(2,.6,-1,4.6,1.2,1,'cream',1.1)
  local L3=F(cx+6,y,cz-3,0);L3.cyl(0,0,2.6,0,1.2,1.2,'ktTerracotta',8)
 elseif st=='blocks'then
  for i=0,4 do local L2=F(cx-4+(i%3)*3.4,y+floor(i/3)*2.4,cz-1+(i%2)*2,i*.3);L2.box(-1.2,0,-1.2,1.2,2.4,1.2,({'red','blue','gold','leaf','flower'})[i+1],1.1)end
 elseif st=='feathers'then
  for i=0,4 do local L2=F(cx-4+i*2,y,cz+(i%2)*2,i*.6);L2.quad({0,.1,-3},{1,.1,0},{0,.1,3},{-1,.1,0},({'ktOchre','white','ktCopper','red','ktOchre'})[i+1],1.15)end
  local L3=F(cx+5,y,cz-3,0);L3.cyl(0,0,2,0,1.6,1.8,'ktTerracotta',8);L3.sphere(0,2.2,0,1.6,.5,1.6,'gold',8,3)
 elseif st=='none'then
 end
 -- the seats
 for _,c in ipairs(stools)do
  local sx,sz=c[1]*CS+8,c[2]*CS+8
  local back=nil
  if Hh.seat=='spindle'then back=(sx<cx)and'w'or'e'end
  local L2=F(sx,0,sz,0)
  K.seat(L2,Hh.seat=='zabuton'and 1.6 or 6,Hh.seat or'spindle',back,{wood=wd,cushion=T.rug[1]})
 end
end
local WALLS={}
-- each wall dressing: (C,T,side,u0,u1) on the open stretch of a wall
function WALLS.clock(C,T,Lw,u)K.clock(C,Lw,u,34,3.6,{case=T.wood=='white'and'inOak'or T.wood})end
function WALLS.photos(C,T,Lw,u)
 for i=0,2 do local a=u-9+i*6.4;local lo=26+(i%2)*4
  K.picture(C,Lw,a,a+4.6,lo,lo+5.6,({'portrait','meadow','sea'})[i+1],{frame=i==1 and'lgGold'or'inWalnut',mat=.7})end
end
function WALLS.mirror(C,T,Lw,u)
 Lw.box(u-6,22,0,u+6,40,.8,'lgGold',1.05);Lw.box(u-5,23,.8,u+5,39,1,'ktGlass',1.25)
 Lw.quad({u-4,25,1.05},{u-1,25,1.05},{u+3,37,1.05},{u,37,1.05},'ktPearl',1.3)
end
function WALLS.antlers(C,T,Lw,u)
 Lw.box(u-3,34,0,u+3,40,1,'inWalnut',1)
 for _,s in ipairs({-1,1})do Lw.rod({u+s*1.5,38,1},{u+s*7,44,3},.35,'cream');Lw.rod({u+s*4,41,2},{u+s*3,46,2.6},.3,'cream');Lw.rod({u+s*6,43,2.6},{u+s*9,44,3},.3,'cream')end
end
function WALLS.pennant(C,T,Lw,u)
 Lw.quad({u-7,40,.4},{u+7,40,.4},{u-7,32,.4},{u-7,32,.4},'leaf',1.05);Lw.box(u-7.4,31.6,0,u-6.6,40.4,.6,'cream',1)
 Lw.quad({u-5,38,.5},{u,38,.5},{u-5,35,.5},{u-5,35,.5},'white',1.1)
end
function WALLS.hearth(C,T,Lw,u)
 -- a shallow stone hearth set into the wall (it stands proud by a hand)
 Lw.box(u-11,0,-.2,u-7,24,1.6,'lvStone',1.0);Lw.box(u+7,0,-.2,u+11,24,1.6,'lvStone',1.0)
 Lw.box(u-7,14,-.2,u+7,24,1.6,'lvStone',1.0)
 Lw.box(u-12,24,-.2,u+12,26,2.4,'inWalnut',1.05)
 Lw.quad({u-7,0,.15},{u+7,0,.15},{u+7,14,.15},{u-7,14,.15},'dark',.3)
 Lw.quad({u-7,14,.15},{u-7,0,.15},{u-7,0,1.6},{u-7,14,1.6},'ktBasalt',.5);Lw.quad({u+7,0,.15},{u+7,14,.15},{u+7,14,1.6},{u+7,0,1.6},'ktBasalt',.5)
 Lw.box(u-7.5,0,-.2,u+7.5,.8,3.2,'lvSlate',.9)
 for i=0,2 do Lw.cyl(u-3+i*3,.8,.8,1,1,1,'lgBark',8)end
 local p=Lw.P({u,1.6,1.2});C.fx.fires[#C.fx.fires+1]={x=p[1],y=p[2],z=p[3],s=.6}
 C.addLight(p[1],8,p[3],56,.5)
 Lw.box(u-10,26,.4,u-7,30,2,'lgBronze',1.1);Lw.box(u+7,26,.4,u+10,29,2,'ktCopper',1.1)
 K.clock(C,Lw,u,33,2.6,{case='inWalnut'})
end
function WALLS.map(C,T,Lw,u)K.picture(C,Lw,u-10,u+10,24,40,'map',{frame='inWalnut',mount=false})end
function WALLS.wheel(C,T,Lw,u)
 Lw.ring(u,34,.6,5.4,6.4,'inWalnut',20,1.05);Lw.disc(u,34,.6,1.8,'inWalnut',10)
 for i=0,7 do local a=i*pi/4;Lw.rod({u+cos(a)*1.6,34+sin(a)*1.6,.8},{u+cos(a)*8.4,34+sin(a)*8.4,.8},.4,'inWalnut')
  Lw.cyl(u+cos(a)*8.4,34+sin(a)*8.4,34+sin(a)*8.4,.8,.6,.6,'inWalnut',6)end
end
function WALLS.porthole(C,T,Lw,u)K.porthole(C,Lw,u,32,4.6,{view=2})end
function WALLS.anchor(C,T,Lw,u)
 Lw.rod({u,26,.8},{u,42,.8},.6,'ktBasalt');Lw.rod({u-4,40,.8},{u+4,40,.8},.5,'ktBasalt')
 Lw.ring(u,43.4,.8,1,1.6,'ktBasalt',10)
 for _,s in ipairs({-1,1})do Lw.rod({u,26,.8},{u+s*6,30,.8},.6,'ktBasalt');Lw.quad({u+s*6,30,.8},{u+s*7.4,28,.8},{u+s*6.4,32,.8},{u+s*6.4,32,.8},'ktBasalt',1)end
 Lw.rod({u,43,.9},{u+5,38,.9},.3,'ktOchre');Lw.rod({u+5,38,.9},{u+2,30,.9},.3,'ktOchre')
end
function WALLS.mounted(C,T,Lw,u)
 Lw.box(u-9,30,0,u+9,40,.8,'inWalnut',1)
 Lw.quad({u-7,35,1.2},{u,39,1.6},{u+5,35,1.6},{u,31,1.2},'ktCopper',1.1);Lw.quad({u+5,35,1.4},{u+8,38,1.2},{u+8,32,1.2},{u+5,35,1.4},'ktCopper',1)
 Lw.disc(u-5,35.6,1.7,.6,'dark',6)
end
function WALLS.net(C,T,Lw,u)
 for i=0,6 do Lw.rod({u-10+i*3.4,44,.4},{u-8+i*3,24+rh(i,1,1)*4,.8},.12,'ktOchre')end
 for j=0,4 do Lw.rod({u-10,42-j*4,.6},{u+10,41-j*4.2,.6},.12,'ktOchre')end
 for i=0,2 do Lw.sphere(u-6+i*6,30+i*3,1.2,1.4,1.4,1.2,'white',8,4)end
end
function WALLS.candles(C,T,Lw,u)
 K.wallShelf(Lw,u-8,u+8,28,{wood='lvWalnut'})
 for i=0,2 do local p=Lw.P({u-5+i*5,28,2});K.lamp(C,K.frame(C,Lw.E,p[1],p[2],p[3],0),'candle',{h=2.6+i,col=i==1 and'violet'or nil})end
end
function WALLS.drawings(C,T,Lw,u)
 for i=0,3 do local a=u-12+i*6.4;local lo=24+(i%2)*6
  Lw.box(a,lo,0,a+5.4,lo+5.4,.3,'white',1.15)
  Lw.disc(a+2.7,lo+2.7,.35,1.6,({'gold','flower','blue','leaf'})[i+1],10,nil,1.1)
  Lw.box(a+2.2,lo+5,.3,a+3.2,lo+5.8,.5,'red',1.1)end
end
function WALLS.names(C,T,Lw,u)
 Lw.box(u-11,24,0,u+11,42,.6,'cream',1.1);Lw.box(u-11.6,41.6,0,u+11.6,43,1.2,'inWalnut',1);Lw.box(u-11.6,23,0,u+11.6,24.4,1.2,'inWalnut',1)
 for i=0,5 do Lw.box(u-9,26+i*2.6,.6,u-9+8+rh(i,1,4)*8,27.2+i*2.6,.7,'dark',.75)end
end
function WALLS.tv(C,T,Lw,u)
 Lw.box(u-11,22,0,u+11,36,1.2,'dark',.8)
 Lw.raw({u-10.2,22.8,1.25},{u+10.2,22.8,1.25},{u+10.2,35.2,1.25},{u-10.2,35.2,1.25},'inScreen',2)
end
function WALLS.stars(C,T,Lw,u)
 Lw.box(u-10,24,0,u+10,42,.5,'navy',.8)
 for i=0,11 do local sx,sy=u-9+rh(i,1,6)*18,25+rh(i,2,6)*16;Lw.box(sx-.3,sy-.3,.5,sx+.3,sy+.3,.6,'gold',1.4)end
 for i=0,4 do Lw.rod({u-8+i*4,26+rh(i,3,6)*12,.6},{u-4+i*4,28+rh(i,4,6)*12,.6},.08,'cream')end
 Lw.ring(u,33,.6,6,6.4,'lgGold',20,1.1)
end
function WALLS.spoons(C,T,Lw,u)
 for i=0,4 do local a=u-8+i*4;local y=30+sin(i*1.3)*2
  Lw.rod({a,y,1.4},{a+.6,y+5,1.4},.18,'lgSilver');Lw.sphere(a+.7,y+5.6,1.4,.7,1,.4,'lgSilver',6,4)end
end
function WALLS.scroll(C,T,Lw,u)
 Lw.box(u-5,16,0,u+5,44,.4,'cream',1.1);Lw.box(u-5.6,43.6,-.2,u+5.6,44.8,1,'inWalnut',1);Lw.box(u-5.6,15.4,-.2,u+5.6,16.6,1,'inWalnut',1)
 Lw.quad({u-3.5,36,.45},{u+3.5,36,.45},{u,41,.45},{u,41,.45},'lvSlate',.9)
 Lw.quad({u-4,34,.45},{u+4,34,.45},{u+2,36.5,.45},{u-2,36.5,.45},'lvSlate',.85)
 Lw.disc(u+2.6,40,.5,1.2,'red',10,nil,1.1)
 for i=0,3 do Lw.box(u-.4,20+i*3.4,.45,u+.4,22.4+i*3.4,.5,'dark',.7)end
end
function WALLS.shoji(C,T,Lw,u)
 Lw.raw({u-12,6,.6},{u+12,6,.6},{u+12,40,.6},{u-12,40,.6},'inShoji',1)
 Lw.box(u-12.8,5,0,u+12.8,6,1.4,'inWalnut',1);Lw.box(u-12.8,40,0,u+12.8,41.2,1.4,'inWalnut',1)
 Lw.box(u-12.8,5,0,u-12,41.2,1.4,'inWalnut',1);Lw.box(u+12,5,0,u+12.8,41.2,1.4,'inWalnut',1);Lw.box(u-.4,6,0,u+.4,40,1.2,'inWalnut',1)
end
function WALLS.quilt(C,T,Lw,u)
 Lw.box(u-10,22,0,u+10,42,.5,'cream',1.05)
 for i=0,4 do for j=0,4 do Lw.box(u-9+i*3.6,23+j*3.8,.5,u-6+i*3.6,26+j*3.8,.65,({'inRugRed','inRugGreen','inRugGold','inRugBlue','cream'})[(i+j*2)%5+1],1.05)end end
 Lw.rod({u-11,43,.8},{u+11,43,.8},.4,'inWalnut')
end
function WALLS.feathers(C,T,Lw,u)
 for i=0,4 do local a=u-8+i*4;local y=30+rh(i,1,8)*6
  Lw.quad({a,y,.5},{a+1.2,y+5,.6},{a,y+10,.5},{a-1.2,y+5,.6},({'ktOchre','white','ktCopper','red','ktOchre'})[i+1],1.15)
  Lw.rod({a,y,.7},{a,y+9.5,.7},.08,'cream')end
end
function WALLS.alphabet(C,T,Lw,u)
 local LA=V.require('LeagueArchitecture').kit
 Lw.box(u-14,38,0,u+14,44,.4,'cream',1.1)
 LA.inscription(Lw,'ABCDEFG',u,39.4,.4,.65,'blue',26)
end
function WALLS.charts(C,T,Lw,u)
 Lw.box(u-10,22,0,u+10,38,.5,'white',1.12)
 for i=0,5 do for j=0,2 do Lw.disc(u-7.5+i*3,26+j*4.4,.55,1.2,({'red','blue','leaf','gold','flower','ktCopper'})[(i+j)%6+1],8,nil,1.1)end end
 Lw.box(u-10.4,37.6,0,u+10.4,38.6,.8,'red',1)
end
function WALLS.bunting(C,T,Lw,u)
 for i=0,7 do local a=u-14+i*3.6;local y=42-sin(i/7*pi)*3
  Lw.quad({a,y,.6},{a+3.2,y,.6},{a+1.6,y-3.4,.6},{a+1.6,y-3.4,.6},({'red','gold','blue','leaf'})[i%4+1],1.1)end
 Lw.rod({u-14,42,.6},{u+14,42,.6},.1,'cream')
end
function WALLS.tilted(C,T,Lw,u)
 -- a picture knocked askew
 local P=Lw.P
 Lw.quad({u-7,26,.6},{u+5,24,.6},{u+7,34,.6},{u-5,36,.6},'inWalnut',1)
 Lw.quad({u-5.6,27,.7},{u+4,25.4,.7},{u+5.6,33,.7},{u-4,34.6,.7},'ktMarine',1.05)
end
M.WALLS=WALLS

-- the house on the common plan
function M.house(C)
 local id=C.id;local Hh=HOUSES[id]or HOUSES.BLUES_HOUSE
 local T=theme(C.city)
 local H=48;C.H=H
 C.ambient=(Hh.dim or T.dim)and .70 or .80;C.maxLight=1.4
 local solid=topWall(C)
 local W,D=C.cw*CS,C.ch*CS
 local wainscot=T.wainscot
 local S=K.shell(C,{H=H,solid=solid,blocked=blocked(C),door=doorFn(C),
  paint=Hh.trashed and'ktPearl'or T.paint,upper=T.upper,wainscot=wainscot,wainscotH=13,beadboard=T.bead and 3 or nil,
  rail=T.rail,skirting=T.rail,cornice=T.cornice,cap='ktLime',floor=T.floor,ceiling=T.ceiling,picture=T.japan and nil or 38})
 local R=C.part('room')
 local function F(x,y,z,yaw)return K.frame(C,R,x,y,z,yaw)end
 local seed=#id
 -- the cases
 if not Hh.school then
  for _,g in ipairs(groups(C,'B'))do caseL(C,T,R,F,Hh.left or'books',g.x0*CS,(g.x1+1)*CS,seed)end
 end
 for _,g in ipairs(groups(C,'b'))do caseR(C,T,F,Hh.right or'books',g.x0*CS,(g.x1+1)*CS,seed)end
 -- the table and seats
 if Hh.school then
  M.schoolRoom(C,T,Hh,F)
 else
  local tg=groups(C,'Tx')
  for _,tb in ipairs(tg)do tableSet(C,T,Hh,F,tb,cellsOf(C,'s'))end
 end
 -- the corners: a plant in front, a side piece behind
 local cs=groups(C,'P')
 for i,g in ipairs(cs)do
  local west=g.x0==0
  corner(C,T,F,g.x0,(Hh.corner or T.plants)[i]or'fern',Hh.side,seed+i,west)
 end
 -- the north wall: the window and the picture of the drawing, and more
 local Ln=K.onWall(C,'N',0,0)
 for _,c in ipairs(cellsOf(C,'w'))do
  local x=c[1]*CS+8
  if T.japan then
   WALLS.shoji(C,T,Ln,x)
  else
   K.window(C,Ln,x-10,x+10,17,37,{frame=T.wood=='white'and'white'or(T.modern and'inSteel'or'white'),view=T.view,
    curtain=T.curtain,cloth=T.cloth,panes=T.modern and{1,1}or{2,3},box=(C.city=='PALLET'or C.city=='CELADON')and'inPine'or nil,
    shutters=nil})
  end
 end
 for _,c in ipairs(cellsOf(C,'p'))do
  local x=c[1]*CS+8
  K.picture(C,Ln,x-7,x+7,24,35,Hh.pic or'meadow',{frame=T.wood=='white'and'lgGold'or(T.modern and'dark'or'lgGold')})
 end
 -- side walls: the house's own dressings on the open stretches
 local walls=Hh.walls or{}
 local Lw=K.onWall(C,'W',0,0);local Le=K.onWall(C,'E',0,0)
 -- open stretch on each side wall: z 32..96 (rows 2-5) -> u = S.s - z
 if walls[1]and WALLS[walls[1]]then WALLS[walls[1]](C,T,Lw,D-64)end
 if walls[2]and WALLS[walls[2]]then WALLS[walls[2]](C,T,Le,64-S.n)end
 -- a calendar or coat hooks on the south wall by the door
 local d0,d1=doorSpan(C)
 if d0 then
  K.frontDoor(C,d0,d1,{view=T.view==2 and 2 or(T.view==5 and 5 or 1),frame=T.wood=='white'and'white'or'white',leaf=T.japan and'inShoji'or(T.wood=='white'and'inPine'or T.wood)})
  local Ls=K.onWall(C,'S',0,0)
  -- hooks with a coat and a hat
  local u=W-d1-14
  Ls.box(u-6,30,0,u+6,31.6,.8,T.wood=='white'and'inPine'or T.wood,1)
  for k=0,2 do Ls.box(u-4+k*4-.3,30.4,.8,u-4+k*4+.3,31,2.4,'lgGold',1.1)end
  Ls.box(u-5,18,1,u-1,30.6,2.6,T.accent=='blue'and'navy'or'inRugRed',1)
  Ls.cyl(u+4,27,30,2,1.8,1.6,'ktOchre',10)
 end
 -- the rug under the table
 local tb=groups(C,'T')[1]
 if Hh.rug~=false and tb then
  local x0,x1,z0,z1=tb.x0*CS-14,(tb.x1+1)*CS+14,tb.y0*CS-10,(tb.y1+1)*CS+10
  local pat=Hh.rug or'plain'
  K.rug(C,C.part('floor'),x0,z0,x1,z1,{field=T.rug[1],border=T.rug[2],inner=T.rug[2],pattern=pat,fringe=pat=='medallion'and'cream'or nil})
 end
 -- a runner at the door
 if d0 then K.rug(C,C.part('floor'),d0+3,D-14,d1-3,D-1,{field=T.rug[2]=='white'and'inRugBlue'or T.rug[2],border='dark',bw=1,pattern='stripes',inner=T.rug[1]})end
 -- the ceiling lamp over the table (hidden from high above)
 if tb then
  local cx,cz=(tb.x0+tb.x1+1)*CS/2,(tb.y0+tb.y1+1)*CS/2
  local E=C.part('ceilfx',{below=H+70})
  local Lp=K.frame(C,E,cx,H,cz,0)
  local lk=Hh.lamp or'pendant'
  if lk=='lantern'then
   Lp.cyl(0,-10,0,0,.1,.1,'dark',4,false)
   Lp.box(-2.6,-17,-2.6,2.6,-10,2.6,'lgBronze',1)
   Lp.raw({-2.2,-16.4,2.65},{2.2,-16.4,2.65},{2.2,-10.6,2.65},{-2.2,-10.6,2.65},'inLamp',1)
   Lp.raw({-2.2,-16.4,-2.65},{2.2,-16.4,-2.65},{2.2,-10.6,-2.65},{-2.2,-10.6,-2.65},'inLamp',1)
   C.addLight(cx,H-20,cz,60,.3)
  elseif lk=='paper'then
   Lp.cyl(0,-8,0,0,.1,.1,'dark',4,false)
   Lp.sphere(0,-12,0,5,4.4,5,'inShoji',12,6)
   C.addLight(cx,H-18,cz,60,.3)
  elseif lk=='modern'then
   Lp.cyl(0,-12,0,0,.1,.1,'dark',4,false)
   Lp.cyl(0,-16,-12,0,6,1,'dark',16,false);Lp.cyl(0,-16.2,-15.8,0,5.6,5.6,'inLamp',16)
   C.addLight(cx,H-20,cz,60,.3)
  else
   K.lamp(C,Lp,'pendant',{drop=10,r1=5,shadeMat=T.accent=='green'and'ktSage'or nil})
  end
 end
 -- general light: a little from the window, the room's glow
 C.addLight(W/2,40,30,90,.10)
 C.fx.ambience={room=.45}
 if #C.fx.fires>0 then C.fx.ambience.fire=.35 end
 if C.fx.fish then C.fx.ambience.aqua=.2 end
 if Hh.trashed then M.trashed(C,T,F)end
end

-- the classroom / study plan (blackboard on the north wall, one desk)
function M.schoolRoom(C,T,Hh,F)
 local Ln=K.onWall(C,'N',0,0)
 local bb=groups(C,'O')[1]
 if bb then
  local x0,x1=bb.x0*CS,(bb.x1+1)*CS
  Ln.box(x0-4,16,0,x1+4,40,1,'inWalnut',1)
  Ln.box(x0-3,17,1,x1+3,39,1.2,Hh.eevee and'ktCopper'or'ktObsidian',Hh.eevee and .9 or .6)
  Ln.box(x0-4,15,0,x1+4,16.4,3,'inWalnut',1.05)
  for i=0,2 do Ln.box(x0+i*6,16.4,1.6,x0+i*6+2,17,2.4,'white',1.2)end
  -- chalk words and a drawing
  for i=0,3 do Ln.box(x0+2,35-i*3.2,1.25,x0+4+rh(i,1,2)*12,35.6-i*3.2,1.3,'white',1.1)end
  Ln.ring((x0+x1)/2+7,26,1.25,3.4,3.9,'white',16,1.1)
  Ln.box((x0+x1)/2+3.4,25.7,1.25,(x0+x1)/2+10.6,26.3,1.3,'white',1.1)
 end
 for _,c in ipairs(cellsOf(C,'w'))do
  local x=c[1]*CS+8
  K.window(C,Ln,x-10,x+10,17,37,{frame='white',view=T.view,curtain=T.curtain,cloth=T.cloth,panes={2,3}})
 end
 -- the desk with a book (and on the roof, Eevee's ball waits there)
 local tb=groups(C,'T')[1]
 if tb then
  local x0,x1,z0,z1=tb.x0*CS,(tb.x1+1)*CS,tb.y0*CS,(tb.y1+1)*CS
  local cx,cz=(x0+x1)/2,(z0+z1)/2
  local L=F(cx,0,cz,0)
  K.table(L,x1-x0-4,z1-z0-4,10,'desk',{wood=T.wood})
  local Lb=F(cx-6,10.1,cz,0)
  Lb.box(-4,0,-3,0,.6,3,'cream',1.15);Lb.box(0,0,-3,4,.6,3,'cream',1.12);Lb.box(-.2,0,-3,.2,.9,3,'red',1)
  for k=0,3 do Lb.box(-3.4,.62,-2+k*1.2,-.8,.68,-1.6+k*1.2,'dark',.8);Lb.box(.8,.62,-2+k*1.2,3.4,.68,-1.6+k*1.2,'dark',.8)end
  local Lp=F(cx+7,10.1,cz-4,0);Lp.cyl(0,0,3,0,1,1,'lgBronze',8);for k=0,2 do Lp.rod({0,3,0},{-.6+k*.6,6,(k-1)*.4},.12,({'red','blue','gold'})[k+1])end
  -- a globe on the desk's corner
  local Lg=F(cx+7,10.1,cz+5,0);Lg.cyl(0,0,.6,0,1.6,1.6,'inWalnut',10);Lg.sphere(0,3.2,0,2.4,2.4,2.4,'ktMarine',10,6);Lg.sphere(0,3.2,0,2.45,.8,2.45,'leaf',10,3)
 end
 for _,c in ipairs(cellsOf(C,'s'))do K.seat(F(c[1]*CS+8,0,c[2]*CS+8,0),6,'spindle','s',{wood=T.wood,cushion=T.rug[1]})end
 -- school: little desks would block the floor; the cubbies go on the wall
 if not Hh.eevee then
  local Lw=K.onWall(C,'W',0,0)
  for i=0,3 do for j=0,1 do
   local a=36+i*7;local y=22+j*7
   Lw.box(a,y,0,a+6.4,y+6.4,4,'inOak',1);Lw.box(a+.5,y+.5,3.6,a+5.9,y+5.9,4,'dark',.5)
   Lw.box(a+1,y+.6,1,a+5.4,y+3.4,3.6,({'red','blue','gold','leaf'})[(i+j)%4+1],1.05)
  end end
 end
end

-- the ransacked house: the shelves knocked out, things on the floor, a hole
-- broken through the back wall, footprints everywhere
function M.trashed(C,T,F)
 local W,D=C.cw*CS,C.ch*CS
 local E=C.part('debris')
 -- footprints (f) and scattered paper
 for cy=0,C.ch-1 do for cx=0,C.cw-1 do
  local c=C.at(cx,cy)
  if c=='f'or c=='t'or c=='c'then
   for k=0,2 do
    local x,z=cx*CS+3+rh(cx,cy,k)*10,cy*CS+3+rh(cy,cx,k+5)*10
    local a=rh(cx,cy,k+9)*pi
    local L=K.frame(C,E,x,.15,z,a)
    if k<2 then
     -- a muddy boot print: sole and heel
     L.quad({-.7,0,-1.4},{.7,0,-1.4},{.8,0,.2},{-.8,0,.2},'lvWalnut',.7)
     L.quad({-.6,0,.6},{.6,0,.6},{.6,0,1.5},{-.6,0,1.5},'lvWalnut',.7)
    else L.quad({-2,0,-1.4},{2,0,-1.4},{2,0,1.4},{-2,0,1.4},'cream',1.1)end
   end
  end
  if c=='t'then
   -- a toppled stool
   local L=F(cx*CS+8,0,cy*CS+8,.6)
   L.box(-4.6,0,-4.6,4.6,1.2,4.6,T.wood=='white'and'inPine'or T.wood,1)
   for k=0,3 do L.rod({-3.4+(k%2)*6.8,1.2,-3.4+floor(k/2)*6.8},{-3.4+(k%2)*6.8,1.2+.4,-3.4+floor(k/2)*6.8+5},.5,T.wood=='white'and'inPine'or T.wood)end
  elseif c=='c'then
   for k=0,1 do local L=F(cx*CS+5+k*6,1.2,cy*CS+7+k*2,pi/2+k);L.cyl(0,-1.2,1.2,0,1.2,1.2,'ktSteel',8)end
  end
 end end
 -- the broken table corner (x) and rubble (r)
 for _,c in ipairs(cellsOf(C,'r'))do
  local L=F(c[1]*CS+8,0,c[2]*CS+8,0)
  for k=0,5 do L.sphere((rh(k,c[1],1)-.5)*10,1.6,(rh(k,c[2],2)-.5)*10,2.4+rh(k,1,3)*1.6,1.6+rh(k,2,3),2.2,({'lvStone','ktBasalt','ktSandstone'})[k%3+1],7,4,k)end
  L.rod({-5,1,4},{6,4,-3},.6,T.wood=='white'and'inPine'or T.wood)
 end
 -- the hole in the back wall (h): broken edges, daylight beyond
 for _,c in ipairs(cellsOf(C,'h'))do
  local Ln=K.onWall(C,'N',0,0)
  local x=c[1]*CS+8
  -- (TEST178: in front of the wainscot rail and skirting, which used to run
  -- straight across the hole; and the real yard behind the house through it)
  Ln.raw({x-6,0,1.25},{x+6,0,1.25},{x+5,18,1.25},{x-5,16,1.25},'inWindow',1)
  K.pane(C,Ln,x-5.6,x+5.6,0,16.6,1.3,1)
  for k=0,6 do local a=k/6*pi;local r=8+rh(k,1,7)*3
   Ln.box(x+cos(a)*r-1.6,sin(a)*r*2-1,.2,x+cos(a)*r+1.6,sin(a)*r*2+1.6,1.8,'lvStone',1)end
  for k=0,4 do local L=F(x-6+k*3,0,18+rh(k,2,2)*4,k);L.sphere(0,.8,0,1.6,1,1.4,'lvStone',6,3,k)end
 end
 -- the cracked wall stretches (k)
 for _,c in ipairs(cellsOf(C,'k'))do
  local Ln=K.onWall(C,'N',0,0)
  local x=c[1]*CS
  local px,py=x+3,44
  for k=0,5 do
   local nx,ny=px+(rh(k,x,1)-.3)*5,py-3-rh(k,x,2)*4
   local dx,dy=nx-px,ny-py;local l=sqrt(dx*dx+dy*dy);local ox,oy=-dy/l*.35,dx/l*.35
   Ln.quad({px-ox,py-oy,.2},{nx-ox,ny-oy,.2},{nx+ox,ny+oy,.2},{px+ox,py+oy,.2},'dark',.6)
   px,py=nx,ny
  end
 end
end

------------------------------------------------------------------ HOTEL
-- The Celadon Hotel's lobby on the Center plan: a long reception desk of
-- walnut and marble, the pigeonholes of room keys, a bell and the guest
-- book, palms, a crystal chandelier, a carpet runner, the waiting couch.
function M.hotel(C)
 local T=theme('CELADON')
 local H=60;C.H=H
 C.ambient=.80;C.maxLight=1.45
 local solid=topWall(C)
 local W,D=C.cw*CS,C.ch*CS
 local S=K.shell(C,{H=H,solid=solid,blocked=blocked(C),door=doorFn(C),
  paint='inPaperSage',upper='inPaperSage',wainscot='inWalnut',wainscotH=16,rail='lgGold',skirting='inWalnut',
  cornice='white',cap='ktLime',floor='inParquet',ceiling='white',picture=44})
 local R=C.part('room')
 local function F(x,y,z,yaw)return K.frame(C,R,x,y,z,yaw)end
 -- the desk (row 2), with a marble top and a gilt rail
 local L=F(0,0,0,0)
 local x0,x1=0,0
 for cx=0,C.cw-1 do if C.at(cx,2)=='C'then x1=(cx+1)*CS end end
 L.box(x0,0,33,x1,14,46,'inWalnut',1.0)
 L.box(x0,14,32.4,x1,15.6,47.2,'lgMarble',1.08)
 L.box(x0,0,45.6,x1,1.6,46.4,'dark',.8)
 for x=x0+3,x1-12,12 do
  L.box(x,2.4,46,x+9,12,46.5,'inWalnut',1.08)
  L.box(x+1,3.4,46.5,x+8,11,46.7,'inWalnut',.92)
 end
 L.box(x0,12.4,46.4,x1,13,47,'lgGold',1.15)
 -- the bell, the guest book, a lamp
 local Lb=F(4*CS,15.6,40,0)
 Lb.cyl(0,0,.4,0,1.8,1.8,'lgGold',10);Lb.sphere(0,1.2,0,1.4,1.2,1.4,'lgGold',8,4);Lb.cyl(0,2.3,2.9,0,.3,.3,'lgGold',6)
 local Lg=F(2*CS+8,15.6,40,.2);Lg.box(-4,0,-3,0,.8,3,'cream',1.15);Lg.box(0,0,-3,4,.8,3,'cream',1.12);Lg.box(-4.2,0,-3.2,4.2,.4,3.2,'red',1)
 Lg.rod({1,1,-1},{3,3.4,1},.15,'dark')
 K.lamp(C,F(9*CS,15.6,38,0),'table',{base='lgGold'})
 K.plant(F(12*CS,15.6,39,0),'orchid',{s=.7,pot='white',potR=1.6,potH=2.6,colors={'white','flower'}})
 -- the key board behind the desk, on the north wall
 local Ln=K.onWall(C,'N',0,0)
 Ln.box(64,20,0,128,44,1.2,'inWalnut',1)
 for i=0,7 do for j=0,2 do
  local a,y=66+i*7.8,22+j*7.4
  Ln.box(a,y,1.2,a+6.8,y+6.6,1.4,'dark',.5)
  if (i+j)%3~=1 then Ln.rod({a+3.4,y+5,1.4},{a+3.4,y+2,2.6},.2,'lgGold');Ln.box(a+2.6,y+.4,2,a+4.2,y+2.4,2.4,'red',1.1)end
 end end
 V.require('LeagueArchitecture').kit.inscription(Ln,'HOTEL',96,46,1,1.4,'lgGold',40)
 -- pictures and sconces along the wall
 K.picture(C,Ln,10,46,24,46,'flowers',{frame='lgGold'})
 K.picture(C,Ln,140,176,24,46,'city',{frame='lgGold'})
 for _,x in ipairs({54,136,182})do K.lamp(C,K.frame(C,Ln.E,x,36,S.n,0),'sconce',{metal='lgGold'})end
 -- the couch and its resting guest (U), the palms (P)
 for _,g in ipairs(groups(C,'U'))do
  local z0,z1=g.y0*CS,(g.y1+1)*CS
  local Lc=F(8,0,(z0+z1)/2,pi/2)
  local hl=(z1-z0-2)/2
  Lc.box(-hl,0,-6,hl,2,7,'inWalnut',.8);Lc.box(-hl,2,-4,hl,7,7.6,'inLeather',1.0)
  Lc.box(-hl,2,-6.6,hl,15,-3,'inLeather',.98)
  Lc.box(-hl-1.6,2,-6.6,-hl,11,7.8,'inLeather',1.0);Lc.box(hl,2,-6.6,hl+1.6,11,7.8,'inLeather',1.0)
  sitter(F(8,0,(z0+z1)/2+3,pi/2),8.4,{coat='lvSlate'})
 end
 for _,g in ipairs(groups(C,'P'))do
  local gx0,gx1=g.x0*CS,(g.x1+1)*CS
  local gz1=(g.y1+1)*CS
  for i=0,1 do
   local px=gx0+8+i*16
   K.plant(F(px,0,gz1-8,0),i==0 and'palm'or'ficus',{s=1.3,pot='inEnamel',potR=4.6,potH=8,seed=g.x0+i})
   local Lp=F(px,0,gz1-8,0);Lp.cyl(0,5,5.8,0,4.7,4.7,'lgGold',12,false)
  end
 end
 -- a long runner from the door to the desk, and a round rug by the couch
 local d0,d1=doorSpan(C)
 if d0 then
  K.frontDoor(C,d0,d1,{view=3,frame='lgGold',leaf='inWalnut'})
  K.rug(C,C.part('floor'),d0+2,50,d1-2,D-2,{field='inRugRed',border='inRugGold',bw=1.4,pattern='stripes',inner='inRugGold'})
 end
 K.rug(C,C.part('floor'),18,58,44,100,{field='inRugGreen',border='inRugGold',pattern='medallion',fringe='cream'})
 -- a chandelier (seen from below and at an angle)
 local E=C.part('ceilfx',{below=H+70})
 local Lc=K.frame(C,E,W/2,H,D*.6,0)
 Lc.cyl(0,-6,0,0,.25,.25,'lgGold',4,false)
 Lc.cyl(0,-9,-6,0,6,1,'lgGold',12,false)
 for i=0,7 do local a=i*pi/4
  Lc.rod({0,-8,0},{cos(a)*8,-10,sin(a)*8},.25,'lgGold')
  K.lamp(C,K.frame(C,E,W/2+cos(a)*8,H-10.4,D*.6+sin(a)*8,0),'candle',{h=1.6,s=.6,r=26,k=.08})
  Lc.sphere(cos(a)*6,-12,sin(a)*6,.6,1.2,.6,'lgCrystal',4,3)
 end
 C.addLight(W/2,H-14,D*.6,110,.22)
 ceilingLights(C,H,64,.10,0,W,S.n,D)
 C.fx.ambience={hall=.3}
end

------------------------------------------------------------------ COPYCAT
-- Copycat's house, Saffron: a pastel family home downstairs (a cupboard,
-- the television, the table, the stairs), and her room upstairs: a canopy
-- bed, the games console, her desk and computer, dolls everywhere.
function M.copycat(C)
 local T=theme('SAFFRON')
 local up=C.id=='COPYCATS_HOUSE_2F'
 local H=48;C.H=H
 C.ambient=.82;C.maxLight=1.4
 local solid=topWall(C)
 local W,D=C.cw*CS,C.ch*CS
 local downCells={}
 local S=K.shell(C,{H=H,solid=solid,blocked=blocked(C),door=doorFn(C),
  paint=up and'inPaperRose'or'ktPearl',upper=up and'inPaperRose'or'ktPearl',wainscot='white',wainscotH=12,beadboard=3,
  rail=up and'flower'or'white',skirting='white',cornice='white',cap='ktLime',floor=up and'inPine'or'inOak',ceiling='white',
  nofloor=function(cx,cy)return C.at(cx,cy)=='v'end})
 local R=C.part('room')
 local function F(x,y,z,yaw)return K.frame(C,R,x,y,z,yaw)end
 local Ln=K.onWall(C,'N',0,0)
 for _,c in ipairs(cellsOf(C,'w'))do
  local x=c[1]*CS+8
  K.window(C,Ln,x-7,x+7,17,37,{frame='white',view=3,curtain=up and'lace'or'blind',cloth=up and'flower'or'white',panes={2,3}})
 end
 for _,g in ipairs(groups(C,'^'))do K.stairsUp(C,R,g.x0*CS,(g.x1+1)*CS,16,(g.y1+1)*CS,{tread='inOak',riser='white',rail='white',side=g.x0*CS+1})end
 for _,g in ipairs(groups(C,'v'))do K.stairsDown(C,R,g.x0*CS,(g.x1+1)*CS,16,(g.y1+1)*CS,{tread='inOak',riser='white',wall='ktPearl',railX=g.x0*CS})end
 if not up then
  -- the cupboard (B), the television (N), the table
  for _,g in ipairs(groups(C,'B'))do
   local L=F((g.x0+g.x1+1)*CS/2,0,24,0)
   K.bookcase(L,(g.x1-g.x0+1)*CS-1.4,38,14,{wood='white',items='mixed',doors=true,glass=true,seed=4,rowItems={'plates','dolls','jars'}})
  end
  for _,g in ipairs(groups(C,'N'))do K.tv(F((g.x0+g.x1+1)*CS/2,0,24,0),{wood='white',kind='flat'})end
  for _,tb in ipairs(groups(C,'T'))do
   tableSet(C,T,{table='glass',setting='vase',seat='modern'},F,tb,cellsOf(C,'s'))
  end
  K.rug(C,C.part('floor'),36,52,92,100,{field='inRugBlue',border='white',pattern='plain'})
  local Lw=K.onWall(C,'W',0,0);WALLS.photos(C,T,Lw,D-64)
  local Le=K.onWall(C,'E',0,0);K.picture(C,Le,40,60,24,38,'abstract',{frame='white',mat=.6})
  K.plant(F(8,0,D-40,0),'monstera',{s=1.2,pot='inEnamel'})
 else
  -- the desk and computer (K, D)
  local kd=groups(C,'KD')[1]
  if kd then
   local x0,x1=kd.x0*CS,(kd.x1+1)*CS
   local L=F((x0+x1)/2,0,25,0)
   K.table(L,x1-x0-2,13,11,'desk',{wood='white'})
   local Lk=F(x0+9,11,22,0)
   Lk.box(-6,0,-4,6,1,4,'inEnamel',1)
   Lk.box(-5,1,-4,5,10,2,'inEnamel',1.02);Lk.raw({-4.2,2,2.05},{4.2,2,2.05},{4.2,9,2.05},{-4.2,9,2.05},'inScreen',1)
   Lk.box(-4,0,3,4,.6,6,'ktPearl',1.1)
   -- dolls along the desk and a shelf of them on the wall
   for i=0,3 do local Ld=F(x0+22+i*5.6,11,22,0);K.shelfItems(Ld,'dolls',-2.4,2.4,0,6,-2,2,i+3)end
   K.wallShelf(Ln,x0+4,x1-4,34,{wood='white',items='dolls',seed=7})
  end
  -- the television and the console (N)
  for _,g in ipairs(groups(C,'N'))do
   local L=F((g.x0+g.x1+1)*CS/2,0,(g.y0+g.y1+1)*CS/2,0)
   K.tv(L,{wood='white',kind='crt',case='white'})
   local Lc=F((g.x0+g.x1+1)*CS/2,6,(g.y0+g.y1+1)*CS/2+3,0)
   Lc.box(-3,0,-1,3,1.2,2,'ktPearl',1.05);Lc.box(-1.2,1.2,-.6,1.2,1.6,.8,'red',1.1)
  end
  -- the canopy bed (U)
  for _,g in ipairs(groups(C,'U'))do
   local z0,z1=g.y0*CS,(g.y1+1)*CS
   local L=F(8,0,(z0+z1)/2,0)
   L.box(-7,0,-15,7,5,15,'white',1)
   L.box(-6.6,5,-14.6,6.6,7.6,14.6,'white',1.08)
   L.box(-6.8,7.6,-6,6.8,8.4,14.8,'inRugRed',1.05)
   L.box(-5,7.6,-14,5,9.6,-9,'white',1.15)
   for _,c in ipairs({{-7,-15},{6,-15},{-7,14},{6,14}})do L.box(c[1],0,c[2],c[1]+1,30,c[2]+1,'white',1.05)end
   L.box(-7.4,30,-15.4,7.4,31,15.4,'flower',1.05)
   for _,sx in ipairs({-1,1})do L.box(sx*7.2-.2,14,-15,sx*7.2+.2,30,15,'flower',.85)end
   for i=0,2 do K.shelfItems(F(4,8.4,(z0+z1)/2-8+i*5,0),'dolls',-2,2,0,6,-2,2,i)end
  end
  for _,g in ipairs(groups(C,'P'))do K.plant(F((g.x0+g.x1+1)*CS/2,0,(g.y1+1)*CS-8,0),'flowers',{s=1.3,pot='white',colors={'flower','white','gold'}})end
  K.rug(C,C.part('floor'),30,60,96,104,{field='inRugRed',border='white',pattern='oval'})
  local Le=K.onWall(C,'E',0,0);WALLS.drawings(C,T,Le,48)
  K.wallShelf(Le,64,92,30,{wood='white',items='dolls',seed=3})
 end
 local d0,d1=doorSpan(C)
 if d0 then K.frontDoor(C,d0,d1,{view=3,frame='white',leaf='white'})end
 C.addLight(W/2,40,60,100,.12)
end

return M
