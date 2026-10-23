-- TEST174: THE POKEMON MANSION (InteriorRooms), Cinnabar Island: 1F, 2F,
-- 3F and the basement laboratory, long after the fire.
-- Scorched checker marble underfoot, soot and broken plaster up the walls
-- (old brick showing through), charred panelling, no roof left: blackened
-- rafters against the night. Rubble heaps of brick, stone and burnt beams;
-- the great hall's carpet burnt through between its broken columns; iron
-- beds; scorched tables with the research journals left open on them;
-- dead trees in their urns; the laboratory's consoles, some still
-- flickering; the floors that fell through, their joists bare over the
-- dark. The secret switches are in the statues; the iron gates they move
-- follow the live tiles (the room rebuilds when a switch is thrown).
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

-- a gate's live tile: the top-left tile of a cell (8 a horizontal gate, 36
-- a vertical one); nil when the cell is open or offline
local function gateAt(C,cx,cy)
 local t=C.tile(cx*2,cy*2)
 if t==8 then return'h'elseif t==36 then return'v'end
end

------------------------------------------------------------------ damage
-- soot, cracks and broken plaster over a wall face (frame: x along, y up,
-- +z out), Hh its height
local function scorch(L,len,Hh,seed,brick)
 -- soot creeping down from the top in a ragged edge
 local x=0
 local i=0
 while x<len do
  local w=3+rh(seed,i,1)*5
  local x1=min(len,x+w)
  local d=3+rh(seed,i,2)*7
  L.quad({x,Hh-d,.06},{x1,Hh-d*.7-rh(seed,i,3)*2,.06},{x1,Hh,.06},{x,Hh,.06},'dnChar',.55)
  x=x1;i=i+1
 end
 -- plaster fallen away: brick behind, a pale broken rim
 local n=floor(len/26+rh(seed,9,1))
 for k=0,n-1 do
  local cx=8+rh(seed,k,4)*(len-16)
  local cy=12+rh(seed,k,5)*(Hh-26)
  local w=5+rh(seed,k,6)*7;local h=4+rh(seed,k,7)*6
  local j=rh(seed,k,8)*2
  L.quad({cx-w,cy-h+j,.10},{cx+w-j,cy-h,.10},{cx+w,cy+h-j,.10},{cx-w+j,cy+h,.10},brick or'inBrick',.85)
  L.quad({cx-w-.8,cy-h+j-.8,.08},{cx+w-j+.8,cy-h-.8,.08},{cx+w+.8,cy+h-j+.8,.08},{cx-w+j-.8,cy+h+.8,.08},'ktPlaster',1.05)
 end
 -- a crack or two
 local m=floor(len/40+rh(seed,11,1)*1.5)
 for k=0,m-1 do
  local cx=6+rh(seed,k,12)*(len-12);local cy=Hh*.6+rh(seed,k,13)*Hh*.3
  local pts={{cx,cy}}
  for s=1,4 do local p=pts[#pts];pts[#pts+1]={p[1]+(rh(seed+k,s,14)-.5)*6,p[2]-3-rh(seed+k,s,15)*4}end
  for s=1,#pts-1 do
   local a,b=pts[s],pts[s+1]
   L.quad({a[1]-.25,a[2],.11},{a[1]+.25,a[2],.11},{b[1]+.25,b[2],.11},{b[1]-.25,b[2],.11},'dark',.4)
  end
 end
end
-- the wall's top broken off unevenly: chunks of masonry along the cap
local function ragged(L,len,Hh,seed)
 local x=0;local i=0
 while x<len-2 do
  local w=4+rh(seed,i,21)*8
  local h=rh(seed,i,22)*5
  if h>1.2 then L.box(x,Hh,-1.6,min(len,x+w),Hh+h,1.4,(i%3==0)and'ktPlaster'or'inBrick',.9)end
  x=x+w;i=i+1
 end
end

------------------------------------------------------------------ pieces
-- a heap of rubble on one cell: brick and stone lumps, a burnt beam, a slab
local function rubble(C,F,cx,cy,big)
 local x,z=cx*CS+8,cy*CS+8
 local L=F(x,0,z,0)
 local s=cx*13+cy*7
 -- (a heap buried in other heaps needs fewer stones)
 local shut=C.is(cx-1,cy,'RW')and C.is(cx+1,cy,'RW')and C.is(cx,cy-1,'RW')and C.is(cx,cy+1,'RW')
 local n=shut and 2 or(big and 4 or 3)
 for i=0,n-1 do
  local a=rh(s,i,1)*pi*2;local r=rh(s,i,2)*4.5
  local rx=3.4+rh(s,i,3)*3.4;local ry=1.8+rh(s,i,4)*(big and 4.4 or 3.2)
  local m=({'lgRock','inBrick','lgGranite','ktPlaster','lgRock'})[1+floor(rh(s,i,5)*5)]
  L.sphere(cos(a)*r,ry*.5,sin(a)*r,rx,ry,rx*.9,m,5,2,s+i)
 end
 if shut then return end
 local k=rh(s,7,1)
 if k<.45 then
  -- a burnt beam lying across the heap
  local a=rh(s,8,1)*pi
  L.rod({-cos(a)*8,1+rh(s,8,2)*3,-sin(a)*6},{cos(a)*8,3+rh(s,8,3)*4,sin(a)*6},1.2,'dnChar')
 elseif k<.75 then
  -- a slab of fallen plaster, propped
  L.quad({-5,.4,-3},{4,.6,-4},{5,5,1},{-4,4.6,2},'ktPlaster',1)
  L.quad({-4,4.6,2.1},{5,5,1.1},{4,.6,-3.9},{-5,.4,-2.9},'inBrick',.7)
 end
 -- scattered bricks round the foot
 for i=0,2 do
  local bx,bz=-6+rh(s,i,30)*12,-6+rh(s,i,31)*12
  L.box(bx-1.2,0,bz-.6,bx+1.2,.9,bz+.6,'inBrick',.9,{bottom=true,n=true,w=true})
 end
end

-- the mansion's switch statue: a tall plinth, a stone sentinel with a
-- clawed orb, the hidden switch's panel on the front
local function statue(C,F,c,on)
 local x,z=c[1]*CS+8,c[2]*CS+8
 local L=F(x,0,z,0)
 L.box(-7,0,-6.5,7,2,6.5,'lgMarble',.75)
 L.box(-5.6,2,-5.2,5.6,16,5.2,'lgMarble',.82)
 L.box(-6.4,16,-6,6.4,18,6,'lgMarble',.9)
 -- the sentinel: a hooded figure in robes, hands on an orb
 L.cyl(0,18,30,0,4.6,3.2,'lvStone',8)
 L.sphere(0,32.4,0,2.6,2.8,2.6,'lvStone',8,4)
 L.quad({-2.8,33.4,-1.6},{2.8,33.4,-1.6},{0,37.8,-2.2},{0,37.8,-2.2},'lvStone',.9)
 L.sphere(0,25.6,3.6,2.6,2.6,2.6,'lgAmethyst',8,4)
 for k=0,2 do local a=(k-1)*.9;L.rod({sin(a)*3.2,22,2.4},{sin(a)*2.4,27.6,4.4},.55,'lvStone')end
 -- scorch
 L.quad({-5.62,10,-5.2},{-5.62,16,-5.2},{-5.62,16,5.2},{-5.62,8,5.2},'dark',.4)
 -- the switch: a brass panel, a lever, a lamp telling its state
 L.box(-2.6,7,5.2,2.6,12,5.6,'lgBronze',1.05)
 L.rod({0,9.4,5.7},{on and 1.4 or -1.4,11.4,6.6},.25,'ktBasalt')
 L.disc(0,8.1,5.65,.6,on and'green'or'red',8,nil,1.4)
 C.fx.glows[#C.fx.glows+1]={x=x,y=8,z=z+6.4,r=3,col=on and'green'or'red',a=.35}
 C.fx.glows[#C.fx.glows+1]={x=x,y=25.6,z=z+3.6,r=7,col='violet',a=.20}
end

-- an iron bed, its mattress burnt and torn
local function bed(C,F,g)
 local x=(g.x0+g.x1+1)*CS/2;local z0,z1=g.y0*CS+2,(g.y1+1)*CS-2
 local L=F(x,0,(z0+z1)/2,0)
 local hd=(z1-z0)/2
 for _,sx in ipairs({-6,6})do
  L.box(sx-.5,0,-hd,sx+.5,14,-hd+1,'dnRust',.9)
  L.box(sx-.5,0,hd-1,sx+.5,9,hd,'dnRust',.9)
 end
 L.box(-6,10,-hd,6,11,-hd+1,'dnRust',.9);L.box(-6,6.5,hd-1,6,7.5,hd,'dnRust',.9)
 for k=0,3 do L.box(-4.5+k*3,7,-hd+.2,-3.9+k*3,13,-hd+.8,'dnRust',.85)end
 L.box(-6,3.6,-hd+1,6,4.4,hd-1,'dnRust',.8)
 L.box(-5.6,4.4,-hd+1.2,5.6,6.6,hd-1.2,'cream',.72)
 L.box(-4.6,6.6,-hd+1.6,4.6,7.6,-hd+5,'cream',.85)
 -- the burnt hole and a blanket half off
 L.quad({-2,6.65,-1},{3,6.65,0},{2,6.65,4},{-3,6.65,3},'dark',.35)
 L.quad({-5.8,6.7,1},{5.8,6.7,1.6},{6.6,1,hd-.6},{-6.6,1,hd-1},'inRugRed',.6)
end

-- a scorched table with an open journal, a lamp, papers
local function table_(C,F,g,seed)
 local x0,x1,z0,z1=g.x0*CS,(g.x1+1)*CS,g.y0*CS,(g.y1+1)*CS
 local L=F((x0+x1)/2,0,(z0+z1)/2,0)
 local w,d=(x1-x0)/2-2,(z1-z0)/2-3
 for _,sx in ipairs({-w+1.4,w-1.4})do for _,sz in ipairs({-d+1.4,d-1.4})do L.box(sx-.8,0,sz-.8,sx+.8,10,sz+.8,'dnChar',1)end end
 L.box(-w,10,-d,w,11.4,d,'inWalnut',.75)
 L.box(-w,10,-d,w-3,11.45,-d+5,'dnChar',.9)
 -- the journal, open
 local Lj=F((x0+x1)/2+rh(seed,1,1)*6-3,11.45,(z0+z1)/2,rh(seed,1,2)*.6-.3)
 Lj.box(-4.6,0,-3,0,.5,3,'inLeather',1);Lj.box(0,0,-3,4.6,.5,3,'inLeather',1)
 Lj.quad({-4.2,.52,-2.6},{-.2,.62,-2.6},{-.2,.62,2.6},{-4.2,.52,2.6},'cream',1.15)
 Lj.quad({.2,.62,-2.6},{4.2,.52,-2.6},{4.2,.52,2.6},{.2,.62,2.6},'cream',1.12)
 for i=0,4 do
  Lj.quad({-3.8,.64,-2+i*1},{-.8,.64,-2+i*1},{-.8,.64,-1.6+i*1},{-3.8,.64,-1.6+i*1},'dark',.6)
  Lj.quad({.8,.64,-2+i*1},{3.8-rh(seed,i,3)*1.5,.64,-2+i*1},{3.8-rh(seed,i,3)*1.5,.64,-1.6+i*1},{.8,.64,-1.6+i*1},'dark',.6)
 end
 -- loose pages
 for i=0,2 do
  local px,pz=-w+3+rh(seed,i,4)*(2*w-6),-d+2+rh(seed,i,5)*(2*d-4)
  local a=rh(seed,i,6)*pi
  L.quad({px+cos(a)*2,11.5,pz+sin(a)*2},{px+cos(a+1.6)*2,11.5,pz+sin(a+1.6)*2},{px+cos(a+pi)*2,11.5,pz+sin(a+pi)*2},{px+cos(a+4.7)*2,11.5,pz+sin(a+4.7)*2},'cream',1.05)
 end
 -- a lantern someone left
 if rh(seed,2,1)<.6 then
  K.lamp(C,F(x1-6,11.45,z0+5,0),'lantern',{metal='ktBasalt',r=46,k=.32})
  local p=L.P({w-4,15,-d+2})
  C.fx.glows[#C.fx.glows+1]={x=x1-6,y=15,z=z0+5,r=9,col='warm',a=.25}
 end
end

-- a dead tree in its urn, ivy over the rim
local function deadTree(C,F,x,z,seed)
 local L=F(x,0,z,0)
 L.cyl(0,0,1.2,0,4.6,4.6,'lvStone',8)
 L.cyl(0,1.2,8,0,4.0,5.2,'lvStone',8,'dark')
 L.rod({0,7,0},{rh(seed,1,1)*2-1,16,0},1.0,'lgBark')
 local top={rh(seed,1,1)*2-1,16,0}
 for i=0,4 do
  local a=i*1.3+seed
  local e={top[1]+cos(a)*6,top[2]+4+rh(seed,i,2)*7,sin(a)*5}
  L.rod(top,e,.45,'lgBark')
  L.rod(e,{e[1]+cos(a+.7)*3,e[2]+2.4,e[3]+sin(a+.7)*2},.25,'lgBark')
  if rh(seed,i,3)<.4 then L.box(e[1]-.8,e[2]-.4,e[3]-.8,e[1]+.8,e[2]+.6,e[3]+.8,'ktOchre',.8)end
 end
 for i=0,3 do
  local a=i*1.57+seed;local px,pz=cos(a)*4.6,sin(a)*4.6
  L.quad({px,8,pz},{px+cos(a)*.6,8,pz+sin(a)*.6},{px+cos(a)*1.2,3+rh(seed,i,5)*3,pz+sin(a)*1.2},{px,4,pz},'lgLeaf',.8)
 end
end

-- a laboratory console against the wall (its top in the wall band behind)
local function console(C,F,c,seed,burnt)
 local x,z=c[1]*CS+8,c[2]*CS+8
 local back=C.is(c[1],c[2]-1,'Wq')
 local L=F(x,0,z,0)
 L.box(-7.6,0,-8,7.6,24,6,'inEnamel',burnt and .55 or .9)
 L.box(-7.8,24,-8,7.8,25.6,6.4,'ktSteel',burnt and .6 or 1)
 local kind=floor(rh(c[1],c[2],1)*3)
 if kind==0 then
  L.disc(-3.4,17,6.05,2.8,'dark',12);L.disc(3.4,17,6.05,2.8,'dark',12)
  L.disc(-3.4,17,6.1,.9,'inSteel',6);L.disc(3.4,17,6.1,.9,'inSteel',6)
 elseif kind==1 then
  L.raw({-6,10,6.05},{6,10,6.05},{6,21,6.05},{-6,21,6.05},'inScreen',burnt and 3 or 1)
 else
  L.raw({-5.4,6,6.05},{5.4,6,6.05},{5.4,22,6.05},{-5.4,22,6.05},'inAqua',1)
 end
 for k=0,5 do L.box(-6+k*2.2,3.6,6,-5+k*2.2,5,6.5,({'red','gold','leaf','blue','red','gold'})[k+1],burnt and .6 or 1.1)end
 if burnt then L.quad({-7.6,14,6.15},{-1,10,6.15},{2,24,6.15},{-7.6,24,6.15},'dark',.35)end
 if back then
  -- pipes up the wall behind
  for k=0,2 do L.rod({-5+k*5,25.6,-6},{-5+k*5,44,-6},.8,k==1 and'dnRust'or'ktSteel')end
  L.rod({-7,40,-6},{7,40,-6},.7,'ktSteel')
 end
 if not burnt and kind==1 then
  local p=L.P({0,15,7});C.fx.glows[#C.fx.glows+1]={x=p[1],y=p[2],z=p[3],r=7,col='cyan',a=.16}
 end
end

-- a broken marble column: some still reach the rafters, most snapped
local function column(C,F,c,H,seed)
 local x,z=c[1]*CS+8,c[2]*CS+8
 local L=F(x,0,z,0)
 L.box(-6,0,-6,6,2.4,6,'lgMarble',.85)
 L.cyl(0,2.4,4,0,5,4.6,'lgMarble',10)
 local whole=rh(seed,1,1)<.3
 local h=whole and H-6 or(10+rh(seed,1,2)*16)
 L.cyl(0,4,4+h,0,3.8,3.5,'lgMarble',10,not whole,0,'lgMarbleD')
 if whole then
  L.cyl(0,4+h,6+h,0,3.6,5.6,'lgMarble',10)
  L.box(-6,6+h,-6,6,8+h,6,'lgMarble',.9)
 else
  -- the break: a jagged crown and a drum fallen at the foot
  for k=0,4 do local a=k/5*pi*2
   L.quad({cos(a)*3.5,4+h,sin(a)*3.5},{cos(a+1.25)*3.5,4+h,sin(a+1.25)*3.5},{cos(a+.6)*2,5.5+h+rh(seed,k,3)*2,sin(a+.6)*2},{cos(a+.6)*2,5.5+h+rh(seed,k,3)*2,sin(a+.6)*2},'lgMarble',1.05)end
  local a=rh(seed,2,1)*pi
  L.rod({cos(a)*1-2,3.2,sin(a)*1+3},{cos(a)*5-2,3.6,sin(a)*5+3},3.2,'lgMarble')
 end
 L.quad({-3.85,8,3.6},{3.85,8,3.6},{3.5,4+h*.6,3.4},{-3.5,4+h*.5,3.4},'dark',.35)
end

-- an iron gate across a cell (live tiles): 'h' along x, 'v' along z
local function gate(C,F,cx,cy,kind)
 local x,z=cx*CS+8,cy*CS+8
 local L=F(x,0,z,kind=='v'and pi/2 or 0)
 L.box(-8,0,-1.2,8,1.2,1.2,'dnRust',.9)
 L.box(-8,26,-.8,8,27.4,.8,'dnRust',.95)
 L.box(-8,13,-.6,8,14,.6,'dnRust',.9)
 for k=0,6 do
  local bx=-7+k*2.33
  L.box(bx-.35,1.2,-.35,bx+.35,30,.35,'dnRust',1)
  L.quad({bx-.6,30,0},{bx+.6,30,0},{bx,32.4,0},{bx,32.4,0},'dnRust',1.05)
 end
 L.box(-8.6,0,-1.6,-7.4,31,1.6,'ktBasalt',1);L.box(7.4,0,-1.6,8.6,31,1.6,'ktBasalt',1)
end

------------------------------------------------------------------ the hole
-- where a floor has fallen in: the boards end ragged over bare joists and
-- the dark below, a heap of what fell lying far down
local function hole(C,cells,isO)
 local E=C.part('room')
 local L=K.frame(C,E,0,0,0,0)
 local depth=58
 for _,c in ipairs(cells)do
  local x0,z0=c[1]*CS,c[2]*CS
  L.quad({x0,-depth,z0},{x0+CS,-depth,z0},{x0+CS,-depth,z0+CS},{x0,-depth,z0+CS},'dark',.18)
  -- the joists cross the hole east-west every second cell
  if c[2]%2==0 then L.box(x0,-7,z0+6,x0+CS,-3,z0+9,'dnChar',.7)end
  -- the heap below
  if rh(c[1],c[2],4)<.18 then
   L.sphere(x0+8,-depth+2,z0+8,9,3,8,'lgRock',6,2,c[1]+c[2])
   L.rod({x0+2,-depth+3,z0+4},{x0+15,-depth+6,z0+11},1.4,'dnChar')
  end
  -- ragged edges where it meets the floor
  local function edge(dx,dy,ax,az,bx,bz)
   if not isO(c[1]+dx,c[2]+dy)then
    L.quad({ax,0,az},{bx,0,bz},{bx,-6,bz},{ax,-6,az},'dnChar',.6)
    L.quad({ax,-6,az},{bx,-6,bz},{bx,-30,bz},{ax,-30,az},'inBrick',.32)
    L.quad({ax,-30,az},{bx,-30,bz},{bx,-depth,bz},{ax,-depth,az},'dark',.12)
    for k=0,3 do
     local t=(k+.5)/4
     local px,pz=ax+(bx-ax)*t,az+(bz-az)*t
     local len=1+rh(c[1]*3+k,c[2],dx+2*dy)*4
     L.box(px-.7-(dy~=0 and 0 or .3),-1.2,pz-.7,px+.7,0,pz+.7,'inWalnut',.7)
     L.quad({px-.6,0,pz},{px+.6,0,pz},{px+.6-dx*0,-.4-len*.3,pz+dy*len},{px-.6,-.4-len*.3,pz+dy*len},'inWalnut',.65)
    end
   end
  end
  edge(0,-1,x0,z0,x0+CS,z0)
  edge(0,1,x0+CS,z0+CS,x0,z0+CS)
  edge(-1,0,x0,z0+CS,x0,z0)
  edge(1,0,x0+CS,z0,x0+CS,z0+CS)
 end
end

------------------------------------------------------------------ the room
function M.mansion(C)
 local fl=C.id:match('_B1F$')and 0 or(tonumber(C.id:match('_(%d)F$'))or 1)
 local H=52;C.H=H
 C.ambient=.58;C.maxLight=1.35
 C.watchAll=true
 local W,D=C.cw*CS,C.ch*CS
 local function solid(cx,cy)return C.is(cx,cy,'Wq')end
 local function inner(cx,cy)
  return solid(cx,cy)and cx>0 and cy>0 and cx<C.cw-1 and cy<C.ch-1
 end
 local isO=function(cx,cy)return C.is(cx,cy,'O')end
 local blocked=function(cx,cy)local c=C.at(cx,cy);return c~=nil and not('.r^vy'):find(c,1,true)end
 local lab=fl==0
 local paint=lab and'ktPlaster'or'inPaperRose'
 local S=K.shell(C,{H=H,solid=solid,inner=inner,innerH=40,blocked=blocked,
  door=function(cx,cy,ox,oy)
   if not ox then return false end
   local off=cx<0 or cy<0 or cx>=C.cw or cy>=C.ch
   return off and oy==C.ch-1 and C.is(ox,oy,'.r')
  end,
  paint=paint,upper=paint,wainscot=lab and'ktSteel'or'dnChar',wainscotH=lab and 10 or 14,
  rail='dnChar',skirting='dnChar',cornice='dnChar',cap='dnChar',floor='inChecker',floorT=.78,
  ceiling=false,innerPaint=paint,
  nofloor=function(cx,cy)return isO(cx,cy)or C.at(cx,cy)=='v'end,
  style=function(L,len,run)
   local seed=run.a0*.37+run.c*.11
   scorch(L,len,H,seed)
   ragged(L,len,H,seed)
  end,
  innerStyle=function(L,len,run,Hi)
   local seed=run.a0*.29+run.c*.17
   scorch(L,len,Hi,seed)
   ragged(L,len,Hi,seed)
  end,ao=11})
 local R=C.part('room')
 local function F(x,y,z,yaw)return K.frame(C,R,x,y,z,yaw)end
 C.fx.smoke=C.fx.smoke or{}
 -- soot and ash across the floor (flat), debris decals
 do
  local E=C.part('floor')
  local L=K.frame(C,E,0,.05,0,0)
  for cy=0,C.ch-1 do for cx=0,C.cw-1 do
   if C.is(cx,cy,'.')and rh(cx,cy,40)<.20 then
    -- a scorch: a ragged patch of char, paler at its rim
    local x,z=cx*CS+rh(cx,cy,41)*8+4,cy*CS+rh(cx,cy,42)*8+4
    local r=3+rh(cx,cy,43)*5
    local n=8
    for k=0,n-1 do
     local a0,a1=k/n*pi*2,(k+1)/n*pi*2
     local r0,r1=r*(.65+.5*rh(cx*n+k,cy,44)),r*(.65+.5*rh(cx*n+(k+1)%n,cy,44))
     L.quad({x,0,z},{x+cos(a1)*r1,0,z+sin(a1)*r1},{x+cos(a0)*r0,0,z+sin(a0)*r0},{x,0,z},'dark',.5)
     L.quad({x+cos(a0)*r0,-.01,z+sin(a0)*r0},{x+cos(a1)*r1,-.01,z+sin(a1)*r1},{x+cos(a1)*(r1+1.8),-.01,z+sin(a1)*(r1+1.8)},{x+cos(a0)*(r0+1.8),-.01,z+sin(a0)*(r0+1.8)},'ktBasalt',.6)
    end
   elseif C.is(cx,cy,'.')and rh(cx,cy,45)<.10 then
    local x,z=cx*CS+8,cy*CS+8
    for k=0,2 do
     local bx,bz=x+(rh(cx,cy,46+k)-.5)*12,z+(rh(cx,cy,49+k)-.5)*12
     L.quad({bx-1,.01,bz-.5},{bx+1,.01,bz-.6},{bx+1.1,.01,bz+.5},{bx-.9,.01,bz+.6},k==1 and'ktPlaster'or'inBrick',.7)
    end
   end
  end end
 end
 -- the great hall's carpet (1F), burnt through in places
 do
  local E=C.part('floor')
  local L=K.frame(C,E,0,.08,0,0)
  for _,c in ipairs(cellsOf(C,'r'))do
   local x0,z0=c[1]*CS,c[2]*CS
   for i=0,1 do for j=0,1 do
    local a,b=x0+i*8,z0+j*8
    if rh(c[1]*2+i,c[2]*2+j,60)>.14 then
     L.quad({a,0,b},{a+8,0,b},{a+8,0,b+8},{a,0,b+8},'inRugRed',.62)
    else
     -- burnt through: char showing, the pile's edge singed round it
     local j1,j2,j3,j4=rh(a,b,61)*2,rh(a,b,62)*2,rh(a,b,63)*2,rh(a,b,64)*2
     L.quad({a,0,b},{a+8,0,b},{a+8,0,b+8},{a,0,b+8},'inRugRed',.4)
     L.quad({a+1+j1,.01,b+1.5},{a+7-j2,.01,b+1+j3},{a+6.5,.01,b+7-j4},{a+1.5+j3,.01,b+6.5},'dark',.5)
    end
   end end
   -- the gold border down its edges
   for _,dx in ipairs({-1,1})do
    if not C.is(c[1]+dx,c[2],'r^')then
     local ex=dx<0 and x0+1 or x0+CS-2
     L.quad({ex,.01,z0},{ex+1,.01,z0},{ex+1,.01,z0+CS},{ex,.01,z0+CS},'lgGold',.6)
    end
   end
  end
 end
 -- the columns, the rubble, the statues, the beds, the tables, the trees
 for _,c in ipairs(cellsOf(C,'B'))do column(C,F,c,H,c[1]*5+c[2]*3)end
 for _,c in ipairs(cellsOf(C,'R'))do rubble(C,F,c[1],c[2],rh(c[1],c[2],70)<.3)end
 -- the switch's state: one gate stands only while it is thrown
 local ON={[1]={24,13},[2]={9,4},[3]={15,4},[0]={26,17}}
 local on=ON[fl]and gateAt(C,ON[fl][1],ON[fl][2])~=nil
 for _,c in ipairs(cellsOf(C,'Y'))do statue(C,F,c,on)end
 for _,c in ipairs(cellsOf(C,'b'))do
  if C.raw(c[1],c[2])==33 then bed(C,F,{x0=c[1],x1=c[1],y0=c[2],y1=c[2]+1})end
 end
 for i,g in ipairs(groups(C,'T'))do table_(C,F,g,g.x0*3+g.y0+i)end
 for _,g in ipairs(groups(C,'P'))do
  for cx=g.x0,g.x1 do deadTree(C,F,cx*CS+8,g.y1*CS+8,cx*3+g.y1)end
 end
 for i,c in ipairs(cellsOf(C,'Q'))do console(C,F,c,i,not lab or rh(c[1],c[2],80)<.35)end
 for _,c in ipairs(cellsOf(C,'K'))do
  local L=F(c[1]*CS+8,0,c[2]*CS+8,0)
  L.box(-7,0,-7,7,30,7,'ktSteel',.8)
  L.box(-6.4,1,7,-.3,29,7.4,'dnRust',.9)
  L.box(.3,1,7,6.4,29,9.6,'dnRust',.85)
  for k=0,2 do L.box(-5,8+k*8,7.4,-1.6,9+k*8,7.6,'dark',.6)end
 end
 -- the railings at a fallen floor's edge (some posts gone)
 for _,c in ipairs(cellsOf(C,'-|'))do
  local x0,z0=c[1]*CS,c[2]*CS
  local L=F(0,0,0,0)
  local along=C.at(c[1],c[2])=='-'
  local z=along and(z0+CS-1.5)or nil
  local x=not along and(x0+CS-1.5)or nil
  for k=0,3 do
   if rh(c[1],c[2],90+k)>.25 then
    local px=along and(x0+2+k*4)or x;local pz=along and z or(z0+2+k*4)
    L.box(px-.6,0,pz-.6,px+.6,12,pz+.6,'dnChar',.9)
   end
  end
  if rh(c[1],c[2],95)>.2 then
   if along then L.box(x0,12,z-.9,x0+CS,13.4,z+.9,'dnChar',1)else L.box(x-.9,12,z0,x+.9,13.4,z0+CS,'dnChar',1)end
  end
 end
 -- the fallen floors
 local Ocells=cellsOf(C,'O')
 if #Ocells>0 then hole(C,Ocells,function(cx,cy)
  if cx<0 or cy<0 or cx>=C.cw or cy>=C.ch then return true end
  return isO(cx,cy)end)end
 -- the live gates
 for cy=0,C.ch-1 do for cx=0,C.cw-1 do
  local g=gateAt(C,cx,cy);if g then gate(C,F,cx,cy,g)end
 end end
 -- stairs: up against a wall, or a spiral where the flight stands free;
 -- down through a stairwell in the floor
 for _,c in ipairs(cellsOf(C,'^'))do
  local x0,z0=c[1]*CS,c[2]*CS
  if solid(c[1],c[2]-1)then
   K.stairsUp(C,R,x0,x0+CS,z0,z0+CS,{tread='inWalnut',riser='dnChar',rail='dnChar',side=x0+1,n=4,top=14})
  else
   local L=F(x0+8,0,z0+8,0)
   L.cyl(0,0,H,0,1.2,1.2,'dnRust',8,false)
   for k=0,9 do
    local a=k*.7;local y=2+k*4.6
    L.quad({0,y,0},{cos(a)*7.4,y,sin(a)*7.4},{cos(a+.62)*7.4,y,sin(a+.62)*7.4},{0,y,0},'inWalnut',.9)
    L.quad({cos(a)*7.4,y,sin(a)*7.4},{cos(a+.62)*7.4,y,sin(a+.62)*7.4},{cos(a+.62)*7.4,y-1,sin(a+.62)*7.4},{cos(a)*7.4,y-1,sin(a)*7.4},'dnChar',.8)
    L.rod({cos(a+.3)*7.4,y,sin(a+.3)*7.4},{cos(a+.3)*7.4,y+9,sin(a+.3)*7.4},.2,'dnRust')
   end
  end
 end
 for _,c in ipairs(cellsOf(C,'v'))do
  local x0,z0=c[1]*CS,c[2]*CS
  K.stairsDown(C,R,x0,x0+CS,z0,z0+CS,{tread='inWalnut',riser='dnChar',wall='inBrick',rail='dnChar',handrail='dnChar',nosing='dnChar',railX=x0+.6})
 end
 -- the north wall's windows: broken panes, burnt curtains, the sea at night
 -- (none in the basement)
 if not lab then
  local Ln=K.onWall(C,'N',0,0)
  local i=0
  for cx=1,C.cw-3 do
   if C.is(cx,0,'W')and C.is(cx+1,0,'W')and C.is(cx,1,'.R')and C.is(cx+1,1,'.R')and cx%5==2 then
    local a,b=cx*CS+4-S.w,cx*CS+28-S.w
    K.window(C,Ln,a,b,18,42,{frame='dnChar',view=10,panes={2,3}})
    -- missing panes and a scorched surround
    Ln.quad({a+1,30,.95},{a+11,30,.95},{a+11,42,.95},{a+1,42,.95},'dark',.25)
    Ln.quad({a-4,42,.08},{b+4,42,.08},{b+2,50,.08},{a-2,50,.08},'dark',.3)
    -- burnt curtain rags
    for _,cxx in ipairs({a-1.5,b+1.5})do
     Ln.quad({cxx-2,44,1.6},{cxx+2,44,1.6},{cxx+1.4,24+rh(cx,i,1)*8,1.8},{cxx-1.6,30,1.8},'inRugRed',.45)
    end
    local p=Ln.P({(a+b)/2,30,6})
    C.addLight(p[1],p[2],p[3]+10,70,.16)
    i=i+1
   end
  end
 end
 -- the rafters where the roof burnt away (seen from under them)
 do
  local E=C.part('rafters',{below=H+14})
  local L=K.frame(C,E,0,0,0,0)
  for z=24,D-8,40 do
   local x=0
   while x<W do
    local len=40+rh(z,x,1)*90
    if rh(z,x,2)>.25 then L.box(x,H+6,z-2.4,min(W,x+len),H+10,z+2.4,'dnChar',.8)end
    x=x+len+rh(z,x,3)*30
   end
  end
  for x=40,W-20,96 do L.box(x-2,H+10,0,x+2,H+13,D,'dnChar',.7)end
 end
 -- dust in the moonlight, a little smoke still hanging
 C.fx.motes={x=W*.5,z=D*.35,y0=2,y1=44,r=math.min(W,D)*.35,n=36,col={.75,.80,.95}}
 C.fx.mist={}
 for i=1,6 do C.fx.mist[i]={x=rh(i,fl,1)*W,y=3,z=rh(i,fl,2)*D,r=26,phase=i*1.3,drift=14,col={.45,.45,.50},a=.07}end
 C.addLight(W/2,40,D/2,600,.06)
 C.fx.ambience={wind=.22,crypt=.10}
end

return M
