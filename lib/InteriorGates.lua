-- TEST173: the route gates (InteriorRooms): the guard houses between the
-- towns and the routes, their upper lounges with the big windows and the
-- binoculars, the Safari Zone's gate and rest houses, and the Viridian
-- Forest gates. One builder reads the plan: the outer walls (W), the guard
-- desks (C), filing cases (B), plants (P), lounge chairs (S), the road
-- doors (d north/south, e east/west), the stairs and the window wall (g, I).
local V=...
local M={}
local K=V.require('InteriorKit')
local Town=V.require('InteriorTown')
local pi,cos,sin,floor,min,max,abs=math.pi,math.cos,math.sin,math.floor,math.min,math.max,math.abs
local rh=K.rh
local CS=16
local groups,cellsOf=Town.groups,Town.cellsOf

-- each gate's character: finishes and the view out of its doors
local STYLE={
 ROUTE_2_GATE={kind='forest',view=5},
 VIRIDIAN_FOREST_NORTH_GATE={kind='forest',view=5},
 VIRIDIAN_FOREST_SOUTH_GATE={kind='forest',view=5},
 ROUTE_5_GATE={kind='city',view=3},ROUTE_6_GATE={kind='city',view=3},
 ROUTE_7_GATE={kind='city',view=3},ROUTE_8_GATE={kind='city',view=3},
 ROUTE_11_GATE_1F={kind='coast',view=2},ROUTE_11_GATE_2F={kind='coast',view=2},
 ROUTE_12_GATE_1F={kind='coast',view=2},ROUTE_12_GATE_2F={kind='coast',view=2},
 ROUTE_15_GATE_1F={kind='coast',view=1},ROUTE_15_GATE_2F={kind='coast',view=1},
 ROUTE_16_GATE_1F={kind='cycle',view=1},ROUTE_16_GATE_2F={kind='cycle',view=1},
 ROUTE_18_GATE_1F={kind='cycle',view=2},ROUTE_18_GATE_2F={kind='cycle',view=2},
 SAFARI_ZONE_GATE={kind='safari',view=5},
 SAFARI_ZONE_CENTER_REST_HOUSE={kind='safari',view=5,rest=true},SAFARI_ZONE_EAST_REST_HOUSE={kind='safari',view=5,rest=true},
 SAFARI_ZONE_NORTH_REST_HOUSE={kind='safari',view=5,rest=true},SAFARI_ZONE_WEST_REST_HOUSE={kind='safari',view=5,rest=true},
}
local FIN={
 forest={paint='ktSage',upper='ktLime',wainscot='inOak',rail='inWalnut',floor='inOak',desk='inOak',top='inWalnut',accent='leaf',plant='fern',cloth='inRugGreen'},
 city={paint='ktPlaster',upper='white',wainscot='ktSteel',rail='inSteel',floor='inTerrazzo',desk='inEnamel',top='ktSteel',accent='blue',plant='snake',cloth='inRugBlue'},
 coast={paint='ktPearl',upper='white',wainscot='ktMarine',rail='white',floor='inTile',desk='white',top='ktMarine',accent='ktMarine',plant='palm',cloth='inRugBlue'},
 cycle={paint='ktPlaster',upper='white',wainscot='inLacquer',rail='white',floor='inChecker',desk='inEnamel',top='inLacquer',accent='red',plant='monstera',cloth='inRugRed'},
 safari={paint='ktOchre',upper='ktSandstone',wainscot='inWalnut',rail='inWalnut',floor='inPine',desk='inOak',top='inWalnut',accent='ktOchre',plant='palm',cloth='inRugGold'},
}

local function solidOf(C)
 return function(cx,cy)
  local c=C.at(cx,cy);return c=='W'or c=='V'or c=='g'or c=='I'
 end
end
local function blockedOf(C)
 return function(cx,cy)
  local c=C.at(cx,cy)
  return c~=nil and c~='.'and c~='m'and c~='d'and c~='e'and c~='^'and c~='v'
 end
end

-- the exits on the outer walls: spans per side
local function exits(C)
 local out={}
 local function add(side,a,b)out[#out+1]={side=side,a=a,b=b}end
 local function scan(side,cells)
  local run=nil
  for i,c in ipairs(cells)do
   if c then if run then run[2]=i else run={i,i}end
   elseif run then add(side,run[1]-1,run[2]);run=nil end
  end
  if run then add(side,run[1]-1,run[2])end
 end
 local n,s,w,e={},{},{},{}
 for cx=0,C.cw-1 do n[cx+1]=C.is(cx,0,'dm');s[cx+1]=C.is(cx,C.ch-1,'dm')end
 for cy=0,C.ch-1 do w[cy+1]=C.is(0,cy,'e');e[cy+1]=C.is(C.cw-1,cy,'e')end
 scan('N',n);scan('S',s);scan('W',w);scan('E',e)
 return out
end

function M.gate(C)
 local St=STYLE[C.id]or{kind='city',view=1}
 local Fn=FIN[St.kind]
 local up=C.is(0,0,'g')or C.is(1,0,'gI')
 local H=up and 60 or 52;C.H=H
 C.ambient=.82;C.maxLight=1.45
 local solid=solidOf(C)
 local W,D=C.cw*CS,C.ch*CS
 local S=K.shell(C,{H=H,solid=solid,blocked=blockedOf(C),
  door=function(cx,cy,ox,oy)
   if not ox then return false end
   local off=cx<0 or cy<0 or cx>=C.cw or cy>=C.ch
   return off and C.is(ox,oy,'dme')
  end,
  paint=Fn.paint,upper=Fn.upper,wainscot=Fn.wainscot,wainscotH=14,rail=Fn.rail,skirting=Fn.rail,cornice='white',
  cap='ktLime',floor=Fn.floor,ceiling='white',nofloor=function(cx,cy)return C.at(cx,cy)=='v'end,
  style=up and function(L,len,run)
   -- the great window wall of the lounge (the g/I band): glass between
   -- the pillars, the route beyond
   if run.o~='S'then return end
   local h0,h1=10,H-6
   local at=0
   while at<len-1 do
    local b=min(len,at+30)
    L.box(at,0,0,b,h0,1.2,'white',1.0)
    L.quad({at+1,h0,.6},{b-1,h0,.6},{b-1,h1,.6},{at+1,h1,.6},'inWindow',St.view)
    L.box(at,h0-1,0,b,h0,2.4,'white',1.1)
    L.box(at,h1,0,b,h1+1.2,1.6,'white',1.05)
    L.box(b-1,h0,0,b+1,h1,1.6,'white',1.05)
    for k=1,2 do local y=h0+(h1-h0)*k/3;L.box(at,y-.3,.6,b,y+.3,1.1,'white',1.05)end
    at=b
   end
   -- (TEST178/179: the whole glass wall looks out at the route, in panels
   -- that share one eye so they join)
   K.pane(C,K.runFrame(C,run),1,len-1,h0,h1,.9,1,{split=30})
  end or nil})
 local R=C.part('room')
 local function F(x,y,z,yaw)return K.frame(C,R,x,y,z,yaw)end
 -- the window wall's panes, for the scenic views (the route itself)
 if up then
  -- (TEST178: the panes are exported panel by panel with the wall, above)
  -- pillars (I) stand proud of the glass
  for _,g in ipairs(groups(C,'I'))do
   local x=g.cx
   local L=F(x,0,S.n,0)
   L.box(-4,0,0,4,H-2,4,'white',1.02)
   L.box(-4.6,0,-.2,4.6,3,4.6,Fn.wainscot,1)
   L.box(-4.6,H-6,-.2,4.6,H-2,4.6,'white',1.08)
  end
 end
 -- the guard desks: every run of C, with a computer and a logbook
 local runs={}
 for _,g in ipairs(groups(C,'C'))do runs[#runs+1]=g end
 for i,g in ipairs(runs)do
  local x0,x1,z0,z1=g.x0*CS,(g.x1+1)*CS,g.y0*CS,(g.y1+1)*CS
  local L=F(0,0,0,0)
  local horiz=(g.x1-g.x0)>=(g.y1-g.y0)
  -- each cell of the run (runs may be L-shaped)
  for _,c in ipairs(g.cells)do
   local a0,a1,b0,b1=c[1]*CS,(c[1]+1)*CS,c[2]*CS,(c[2]+1)*CS
   local n=C.is(c[1],c[2]-1,'C');local s=C.is(c[1],c[2]+1,'C')
   local w=C.is(c[1]-1,c[2],'C');local e=C.is(c[1]+1,c[2],'C')
   local ia0,ia1=w and a0 or a0+2,e and a1 or a1-2
   local ib0,ib1=n and b0 or b0+2,s and b1 or b1-2
   L.box(ia0,0,ib0,ia1,13,ib1,Fn.desk,1.0)
   L.box(ia0-.4,13,ib0-.4,ia1+.4,14.6,ib1+.4,Fn.top,1.06)
   L.box(ia0,0,ib0,ia1,1.2,ib1,'dark',.7)
  end
  -- a computer on the desk's middle and a stack of forms
  local mid=g.cells[floor(#g.cells/2)+1]
  local mx,mz=mid[1]*CS+8,mid[2]*CS+8
  local yaw=horiz and pi or(mx<W/2 and pi/2 or -pi/2)
  if horiz then mz=mz-2 end
  local Lm=F(mx,14.6,mz,yaw)
  Lm.box(-4,0,-2.4,4,.6,2.4,'inEnamel',1)
  Lm.box(-3.4,.6,-2,3.4,7,1,'inEnamel',1.02)
  Lm.raw({-2.8,1.2,1.05},{2.8,1.2,1.05},{2.8,6.4,1.05},{-2.8,6.4,1.05},'inScreen',1)
  local ex=g.cells[#g.cells]
  local Lb=F(ex[1]*CS+8,14.6,ex[2]*CS+8,.3)
  Lb.box(-2.4,0,-1.8,2.4,1.4,1.8,'cream',1.12);Lb.box(-2.5,1.4,-1.9,2.5,1.6,1.9,'navy',1)
  Lb.rod({1,1.7,-1},{2.6,1.9,1},.12,'dark')
  -- a rubber stamp and a desk lamp at the other end
  local st=g.cells[1]
  K.lamp(C,F(st[1]*CS+8,14.6,st[2]*CS+6,0),'table',{base=Fn.top=='white'and'ktPearl'or'lgBronze',r=26,k=.14})
 end
 -- filing cases (B)
 for _,g in ipairs(groups(C,'B'))do
  local x0,x1=g.x0*CS,(g.x1+1)*CS
  local z1=(g.y1+1)*CS
  local L=F((x0+x1)/2,0,z1-8,0)
  local w=x1-x0-2
  if St.rest and w>40 then
   -- the rest house's long sideboard: a kettle, cups, a radio, maps
   K.cabinet(L,w,13,12,{wood=Fn.desk,drawers=4,rows=2})
   local Lk=F((x0+x1)/2-14,13,z1-8,0)
   Lk.cyl(0,0,4,0,2.4,2,'ktSteel',10);Lk.rod({2.2,3,0},{4,4.4,0},.35,'ktSteel');Lk.cyl(0,4,4.6,0,1,1,'dark',8)
   for k=0,2 do local Lc=F((x0+x1)/2-6+k*4,13,z1-6,0);Lc.cyl(0,0,1.8,0,1.1,1.3,'white',8)end
   local Lr=F((x0+x1)/2+12,13,z1-9,0);Lr.box(-4,0,-2,4,5,2,'ktCopper',1);Lr.disc(-1.6,2.5,2.05,1.4,'dark',10);Lr.box(1.2,1,2,3.2,4,2.1,'cream',1.1)
   local Lw=K.onWall(C,'N',0,0)
   K.picture(C,Lw,x0+4,x0+28,20,40,'map',{frame='inWalnut',mount=false})
   K.picture(C,Lw,x1-28,x1-4,22,40,'tree',{frame='inWalnut'})
  else
   K.bookcase(L,w,36,12,{wood=Fn.desk=='white'and'ktPearl'or Fn.desk,items='files',doors=true,seed=g.x0})
  end
 end
 -- plants (P): the drawing's crown-over-pot pairs
 for _,g in ipairs(groups(C,'P'))do
  -- one plant per pot cell: the lower cell of each vertical pair
  for cy=g.y0,g.y1 do
   if (cy-g.y0)%2==1 or g.y0==g.y1 then
    for cx=g.x0,g.x1 do
     K.plant(F(cx*CS+8,0,cy*CS+9,0),Fn.plant,{s=1.3,pot=St.kind=='safari'and'ktTerracotta'or'inEnamel',seed=cx*7+cy})
    end
   end
  end
 end
 -- lounge chairs (S), facing the windows
 for _,c in ipairs(cellsOf(C,'S'))do
  local L=F(c[1]*CS+8,0,c[2]*CS+8,0)
  local face=St.rest and((c[1]%3==0)and -pi/2 or pi/2)or pi
  local Lc=F(c[1]*CS+8,0,c[2]*CS+8,face)
  Lc.box(-5,0,-5,5,1.2,5,'inSteel',1)
  Lc.box(-5,1.2,-4.6,5,6,4.6,Fn.cloth,1.0)
  Lc.box(-5,6,-4.8,5,15,-3,Fn.cloth,1.0)
  Lc.box(-5.6,4,-4.6,-4.6,10,4.6,Fn.cloth,1.02);Lc.box(4.6,4,-4.6,5.6,10,4.6,Fn.cloth,1.02)
 end
 -- stairs
 for _,g in ipairs(groups(C,'^'))do K.stairsUp(C,R,g.x0*CS,(g.x1+1)*CS,g.y0*CS,(g.y1+1)*CS,{tread=Fn.floor=='inOak'and'inWalnut'or'inOak',riser='white',rail='white',side=g.x0*CS+1,n=4,top=14})end
 for _,g in ipairs(groups(C,'v'))do K.stairsDown(C,R,g.x0*CS,(g.x1+1)*CS,g.y0*CS,(g.y1+1)*CS,{tread='inOak',riser='white',wall=Fn.paint,railX=g.x0*CS})end
 -- the road doors, open to the route
 for _,ex in ipairs(exits(C))do
  local a,b=ex.a*CS,ex.b*CS
  K.exitPortal(C,ex.side,a+1,b-1,{view=St.view,frame='white',glassDoors=St.kind=='city'})
  -- a mat inside each
  local E=C.part('floor')
  if ex.side=='N'then K.rug(C,E,a+2,S.n+1,b-2,S.n+10,{field=Fn.cloth,border='dark',bw=1})
  elseif ex.side=='S'then K.rug(C,E,a+2,S.s-10,b-2,S.s-1,{field=Fn.cloth,border='dark',bw=1})
  elseif ex.side=='W'then K.rug(C,E,S.w+1,a+2,S.w+10,b-2,{field=Fn.cloth,border='dark',bw=1})
  else K.rug(C,E,S.e-10,a+2,S.e-1,b-2,{field=Fn.cloth,border='dark',bw=1})end
 end
 -- the walls: a route map, a notice board, the flag, a clock
 M.gateWalls(C,St,Fn,S)
 -- a long runner down the road between the doors
 do
  local ex=exits(C)
  local xs,zs={}, {}
  for _,e in ipairs(ex)do if e.side=='N'or e.side=='S'then xs[#xs+1]=e end;if e.side=='W'or e.side=='E'then zs[#zs+1]=e end end
  local E=C.part('floor')
  if #xs>=2 then
   local a,b=xs[1].a*CS+4,xs[1].b*CS-4
   K.rug(C,E,a,S.n+12,b,S.s-12,{field='lvSlate',border=Fn.cloth,bw=1.2,y=.08})
  elseif #zs>=2 then
   local a,b=zs[1].a*CS+4,zs[1].b*CS-4
   K.rug(C,E,S.w+12,a,S.e-12,b,{field='lvSlate',border=Fn.cloth,bw=1.2,y=.08})
  end
 end
 -- ceiling lights
 local E=C.part('ceilfx',{below=H+2})
 local Lc=K.frame(C,E,0,0,0,0)
 for x=S.w+24,S.e-16,40 do for z=S.n+20,S.s-12,40 do
  if not solid(floor(x/CS),floor(z/CS))then
   Lc.raw({x-7,H-.4,z-7},{x+7,H-.4,z-7},{x+7,H-.4,z+7},{x-7,H-.4,z+7},'inPanel',1)
   C.addLight(x,H-6,z,52,.14)
  end
 end end
 C.fx.ambience={hall=.2}
end

function M.gateWalls(C,St,Fn,S)
 local W,D=C.cw*CS,C.ch*CS
 -- find a long open stretch on the west and east walls (not an exit)
 local function stretch(side)
  local best,cur=nil,nil
  local n=C.ch
  for cy=0,n-1 do
   local cx=side=='W'and 0 or C.cw-1
   local open=not C.is(cx,cy,'WVgIe')and not C.is(cx,cy,'P')
   -- the wall face exists where the edge cell is open and is not an exit
   if open then if cur then cur[2]=cy else cur={cy,cy}end
   else if cur and(not best or cur[2]-cur[1]>best[2]-best[1])then best=cur end;cur=nil end
  end
  if cur and(not best or cur[2]-cur[1]>best[2]-best[1])then best=cur end
  return best
 end
 local LA=V.require('LeagueArchitecture').kit
 for _,side in ipairs({'W','E'})do
  local s=stretch(side)
  if s and s[2]-s[1]>=1 then
   local z0,z1=s[1]*CS,(s[2]+1)*CS
   local zc=(z0+z1)/2
   local Lw=K.onWall(C,side,0,0)
   local u=side=='W'and(S.s-zc)or(zc-S.n)
   if side=='W'then
    K.picture(C,Lw,u-14,u+14,22,42,'map',{frame=Fn.rail=='white'and'inWalnut'or Fn.rail,mount=false})
   else
    -- a notice board of the route's news
    Lw.box(u-12,22,0,u+12,40,.8,'inOak',1)
    Lw.box(u-11,23,.8,u+11,39,1,'ktSandstone',1)
    for i=0,5 do local px=u-9+rh(i,1,3)*14;local py=25+rh(i,2,3)*9
     Lw.box(px,py,1,px+4,py+4.6,1.15,({'white','gold','ktPearl','flower','white','leaf'})[i+1],1.15)
     Lw.box(px+1.6,py+4,1.15,px+2.4,py+4.6,1.5,'red',1.2)end
    K.clock(C,Lw,u,47,3.2,{case='white',rim=Fn.accent=='leaf'and'inOak'or'red'})
   end
  end
 end
 -- the route's banner on the north wall when there is wall to hang it on
 if not(C.is(0,0,'g')or C.is(1,0,'gI'))then
  local Ln=K.onWall(C,'N',0,0)
  local x=W/2
  -- keep clear of a north door
  local blocked=false
  for cx=floor((x-20)/CS),floor((x+20)/CS)do if C.is(cx,0,'dm')then blocked=true end end
  if not blocked then
   Ln.box(x-16,34,0,x+16,46,.8,Fn.accent=='leaf'and'inOak'or'white',1.05)
   Ln.box(x-15,35,.8,x+15,45,1.0,St.kind=='safari'and'ktOchre'or(St.kind=='forest'and'leaf'or'blue'),1.0)
   LA.inscription(Ln,St.kind=='safari'and'SAFARI'or(St.kind=='forest'and'FOREST'or'ROUTE'),x,37.2,1.0,1.1,'white',28)
  end
 end
end

return M
