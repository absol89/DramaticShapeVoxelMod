-- TEST38: Professor Oak's laboratory interior, rebuilt as one authored room.
-- The ROM map still owns collision, warps, NPCs, the starter balls and the
-- Pokedexes; this module only replaces what the room looks like, on the
-- original furniture footprints (pokered OaksLab.blk):
--   row 0-1, cells 0-1  research workstation (monitors, server rack)
--   row 1,   cells 2-3  Pokedex table
--   row 0,   cells 4-5  two hanging scrolls on the back wall
--   row 0-1, cells 6-9  tall bookcases
--   row 3,   cells 6-8  starter display table
--   row 6-7, cells 0-3 / 6-9  double-sided book stacks
--   row 11,  cells 4-5  exit mat
-- Materials are Battle Art reference materials (procedural wood, plaster,
-- stone, metal), drawn with a plain white texture.
local V=...
local M={REVISION='oak-lab-room-41-clear-floor'}
local RM=V.require('ReferenceMaterials')
local pi,cos,sin,floor,min,max=math.pi,math.cos,math.sin,math.floor,math.min,math.max
local cached,white
local W,D,WALL,NORTH=160,192,64,9
M.TABLE=12 -- support height of the lab tables (data/voxel_heights OAKS_LAB pin)
local function key(x,y)return (y+64)*4096+x+64 end
function M.accepts(map)
 if not(map and map.id=='OAKS_LAB'and map.def and map.def.width==5 and map.def.height==6)then return false end
 local CV=V.require('CommunityVisuals')
 if CV.oakLab and CV.oakLab:get()~='n64memory'then return false end
 return true
end
local function builder()
 local G={vs={},ix={},tris=0}
 local ox,oz,turn=0,0,0
 function G.frame(x,z,t)ox,oz,turn=x,z,t end
 local function point(p)
  if turn==1 then return ox+p[3],p[2],oz-p[1]end
  if turn==-1 then return ox-p[3],p[2],oz+p[1]end
  if turn==2 then return ox-p[1],p[2],oz-p[3]end
  return ox+p[1],p[2],oz+p[3]
 end
 function G.face(a,b,c,d,mat,tone,glow)
  local shade=RM.encode(mat,(tone or 1)+(glow and 64 or 0))
  local n=#G.vs
  for _,p in ipairs({a,b,c,d})do local x,y,z=point(p);G.vs[n+1]={x,y,z,.5,.5,shade};n=n+1 end
  local i=#G.ix;local s=n-4
  G.ix[i+1],G.ix[i+2],G.ix[i+3],G.ix[i+4],G.ix[i+5],G.ix[i+6]=s+1,s+2,s+3,s+1,s+3,s+4
 end
 local face=G.face
 function G.box(x0,y0,z0,x1,y1,z1,mat,t,glow)
  if x1-x0<.001 or y1-y0<.001 or z1-z0<.001 then return end;t=t or 1
  face({x0,y1,z0},{x0,y1,z1},{x1,y1,z1},{x1,y1,z0},mat,t,glow)
  face({x0,y0,z1},{x1,y0,z1},{x1,y1,z1},{x0,y1,z1},mat,t*.94,glow)
  face({x1,y0,z0},{x0,y0,z0},{x0,y1,z0},{x1,y1,z0},mat,t*.80,glow)
  face({x0,y0,z0},{x0,y0,z1},{x0,y1,z1},{x0,y1,z0},mat,t*.85,glow)
  face({x1,y0,z1},{x1,y0,z0},{x1,y1,z0},{x1,y1,z1},mat,t*.90,glow)
  face({x0,y0,z0},{x1,y0,z0},{x1,y0,z1},{x0,y0,z1},mat,t*.65,glow)
 end
 function G.cyl(x,y0,y1,z,r0,r1,mat,n,t,glow)
  n=n or 12;r1=r1 or r0
  for i=0,n-1 do local a,b=i*2*pi/n,(i+1)*2*pi/n
   face({x+r0*cos(a),y0,z+r0*sin(a)},{x+r0*cos(b),y0,z+r0*sin(b)},{x+r1*cos(b),y1,z+r1*sin(b)},{x+r1*cos(a),y1,z+r1*sin(a)},mat,(t or 1)*(.84+.14*cos(a-.7)),glow)
   face({x,y1,z},{x+r1*cos(b),y1,z+r1*sin(b)},{x+r1*cos(a),y1,z+r1*sin(a)},{x+r1*cos(a),y1,z+r1*sin(a)},mat,(t or 1)*1.04,glow)
  end
 end
 -- Vertical panel facing +z (or any axis-aligned plane via frame()).
 function G.panel(x0,y0,x1,y1,z,mat,t,glow)face({x0,y0,z},{x1,y0,z},{x1,y1,z},{x0,y1,z},mat,t or 1,glow)end
 return G
end
-- Deterministic hash so every load builds the same books and leaves.
local function hash(a,b)local h=(a*73856093+b*19349663)%2147483647;h=(h*48271)%2147483647;return h/2147483647 end
local spines={'red','navy','ktMarine','green','gold','terra','sage','cream','ktBronze','ktViolet','blue','oak'}
-- A run of books standing on a shelf, spines facing +z (side) or -z.
local function books(G,x0,x1,y,zFront,depth,face,seed)
 local x=x0+.3;local i=0
 while x<x1-1 do i=i+1
  local w=.9+hash(seed,i)*1.4;local h=4.6+hash(i,seed)*2.6;local lean=hash(seed+7,i)<.06
  if x+w>x1-.3 then break end
  local mat=spines[floor(hash(seed*3+i,i*5)*#spines)+1]
  local z0,z1
  if face>0 then z0,z1=zFront-depth,zFront-.25-hash(i,seed+3)*.5 else z0,z1=zFront+.25+hash(i,seed+3)*.5,zFront+depth end
  if lean then G.box(x,y,z0,x+w,y+h*.8,z1,mat,.95)else G.box(x,y,z0,x+w,y+h,z1,mat,.9+hash(i,i)*.2)end
  -- A gold band on some spines.
  if hash(i*11,seed)<.35 then
   local zz=face>0 and z1+.02 or z0-.02
   G.face({x+.1,y+h*.72,zz},{x+w-.1,y+h*.72,zz},{x+w-.1,y+h*.78,zz},{x+.1,y+h*.78,zz},'gold',1.1)
  end
  x=x+w+.08
  if hash(seed,i*13)<.08 then x=x+2.2 end
 end
end
-- A bookcase on cells [x0,x1] with its back at zBack and front at zFront.
local function bookcase(G,x0,x1,zBack,zFront,h,seed,both)
 local wood='oak';local frame='wood'
 G.box(x0,0,zBack,x1,1.6,zFront,frame,.75)                 -- plinth
 G.box(x0,h-1.2,zBack-.3,x1,h,zFront+.5,frame,1.0)          -- top
 G.box(x0,h,zBack,x1,h+.6,zFront+.2,frame,.9)               -- crown
 if not both then G.box(x0,1.6,zBack,x1,h-1.2,zBack+.6,wood,.62)end
 local bays=max(1,floor((x1-x0)/16+.5));local bw=(x1-x0)/bays
 for b=0,bays do local x=x0+b*bw
  G.box(x-(b==0 and 0 or .6),1.6,zBack,x+(b==bays and 0 or .6),h-1.2,zFront,wood,.95)
 end
 local shelf=both and(zBack+zFront)/2 or zBack+.6
 for y=1.6,h-6,7.4 do
  G.box(x0,y-.5,zBack,x1,y,zFront,wood,1.02)
  for b=0,bays-1 do local a=x0+b*bw+.6;local c=x0+(b+1)*bw-.6
   books(G,a,c,y,zFront-.4,(zFront-shelf)-.8,1,seed+b*31+floor(y))
   if both then books(G,a,c,y,zBack+.4,(shelf-zBack)-.8,-1,seed+b*37+floor(y)+500)end
  end
 end
end
local function plant(G,x,y0,z,s,seed)
 local cyl0,face0=G.cyl,G.face;local G={cyl=function(x,a,b,z,...)return cyl0(x,a+y0,b+y0,z,...)end,face=function(a,b,c,d,...)local function f(p)return{p[1],p[2]+y0,p[3]}end;return face0(f(a),f(b),f(c),f(d),...)end}
 G.cyl(x,0,4.5*s,z,2.3*s,2.7*s,'ktBrick',10,.95)
 G.cyl(x,4.5*s,4.9*s,z,2.85*s,2.85*s,'ktSandstone',10,1.05)
 G.cyl(x,4.85*s,4.95*s,z,2.4*s,2.4*s,'dark',10,.6)
 for i=0,10 do local a=i*2*pi/11+hash(seed,i);local r=(3.2+hash(i,seed)*2.4)*s;local hh=(6+hash(seed+i,3)*6)*s
  local base={x,4.9*s,z};local tip={x+cos(a)*r,hh,z+sin(a)*r};local mid={(base[1]+tip[1])/2,hh+1.4*s,(base[3]+tip[3])/2}
  local wv=1.0*s;local px,pz=-sin(a)*wv,cos(a)*wv
  G.face(base,{mid[1]+px,mid[2],mid[3]+pz},tip,tip,i%2==0 and'leaf'or'green',1.0)
  G.face(base,tip,{mid[1]-px,mid[2]-.3,mid[3]-pz},{mid[1]-px,mid[2]-.3,mid[3]-pz},i%2==0 and'green'or'leaf',.85)
 end
end
local function pokeball(G,x,y,z,r)
 -- Flat relief facing +z.
 for i=0,19 do local a,b=i*pi/10,(i+1)*pi/10
  G.face({x,y,z},{x+r*cos(a),y+r*sin(a),z},{x+r*cos(b),y+r*sin(b),z},{x+r*cos(b),y+r*sin(b),z},i<10 and'red'or'white',1.05)
 end
 G.box(x-r,y-r*.1,z,x+r,y+r*.1,z+.15,'dark',.8)
 for i=0,11 do local a,b=i*pi/6,(i+1)*pi/6
  G.face({x,y,z+.2},{x+r*.32*cos(a),y+r*.32*sin(a),z+.2},{x+r*.32*cos(b),y+r*.32*sin(b),z+.2},{x+r*.32*cos(b),y+r*.32*sin(b),z+.2},'dark',.8)
  G.face({x,y,z+.25},{x+r*.2*cos(a),y+r*.2*sin(a),z+.25},{x+r*.2*cos(b),y+r*.2*sin(b),z+.25},{x+r*.2*cos(b),y+r*.2*sin(b),z+.25},'white',1.2)
 end
end
-- Furniture, floor and fixtures that never cut away.
function M.room()
 local G=builder();local box,face,cyl=G.box,G.face,G.cyl
 local T=M.TABLE
 -- Floor: warm oak planks, a pale tile research bay and a navy runner.
 for z=NORTH,D-.01,4 do
  local off=(floor(z/4)%3)*8;local endZ=min(D,z+4)
  for x=-off,W-.01,24 do local a=max(0,x);local b=min(W,x+24)
   if b>a then face({a,0,z},{a,0,endZ},{b,0,endZ},{b,0,z},'oak',.92+hash(floor(x),floor(z))*.12)end
  end
 end
 for x=0,95.9,8 do for z=36,91.9,8 do
  face({x,.05,z},{x,.05,z+8},{x+8,.05,z+8},{x+8,.05,z},(floor(x/8)+floor(z/8))%2==0 and'ktPearl'or'white',.98)
 end end
 box(66,0,96,94,.12,D-18,'navy',.95)
 for _,x in ipairs({66,93.4})do box(x,.12,96,x+.6,.18,D-18,'gold',1.05)end
 -- Runner emblem: a Poke Ball inlay lying on the floor.
 for i=0,23 do local a,b=i*pi/12,(i+1)*pi/12;local r=7
  face({80,.2,150},{80+r*cos(b),.2,150+r*sin(b)},{80+r*cos(a),.2,150+r*sin(a)},{80+r*cos(a),.2,150+r*sin(a)},i<12 and'white'or'red',1)
 end
 box(73,.2,149.3,87,.26,150.7,'dark',.8)
 cyl(80,.2,.32,150,2.3,2.3,'dark',12,.8);cyl(80,.32,.38,150,1.4,1.4,'white',12,1.1)
 -- Exit mat (row 11, cells 4-5).
 box(66,0,178,94,.35,191,'red',.9)
 box(68,.35,180,92,.4,189,'terra',.95)
 -- North-left: research workstation, cells 0-1 rows 0-1 (x 0..32).
 do
  box(1,0,NORTH,31,T,30,'ktSteel',.9)                         -- cabinet base
  box(.5,T,NORTH,31.5,T+.8,30.5,'ktPearl',1.05)               -- desk top
  for k=0,2 do box(2+k*10,1.5,30,10+k*10,T-1.5,30.25,'ktSteel',1.05);box(5+k*10,T-3.6,30.25,7+k*10,T-3.1,30.6,'gold',1.1)end
  -- Server rack against the wall with blinking status lights.
  box(1,0,NORTH,10,40,NORTH+10,'dark',.8)
  for y=4,37,3 do box(1.6,y,NORTH+10,9.4,y+2.2,NORTH+10.2,'ktSteel',.75)
   for k=0,3 do local lit=hash(y,k)<.55
    box(2.4+k*1.9,y+.9,NORTH+10.2,3.1+k*1.9,y+1.5,NORTH+10.5,lit and(k%2==0 and'green'or'gold')or'dark',1.2,lit)
   end
  end
  -- Three monitors on arms.
  for k,cx in ipairs({14,21.5,29})do
   local tilt=k==2 and 0 or(k==1 and .25 or -.25)
   box(cx-.4,T+.8,20,cx+.4,T+5,21,'dark',.8)
   box(cx-3.4,T+4.6,19.6,cx+3.4,T+10,20.6,'dark',.75)
   face({cx-3,T+5,20.65},{cx+3,T+5,20.65},{cx+3,T+9.6,20.65},{cx-3,T+9.6,20.65},k==2 and'ktMarine'or'green',1.25,true)
   box(cx-2.6,T+8.4,20.7,cx+1,T+8.8,20.75,'white',1.3,true)
   box(cx-2.6,T+7.3,20.7,cx+2.2,T+7.6,20.75,'white',1.2,true)
  end
  box(15,T+.8,24,27,T+1.3,27,'dark',.85)                       -- keyboard
  for i=0,5 do box(15.5+i*1.9,T+1.3,24.5,16.9+i*1.9,T+1.55,26.5,'ktSteel',1)end
  box(28,T+.8,24.5,30,T+1.4,26.5,'dark',.85)                   -- mouse
  -- Wall-mounted region map above the workstation.
  box(12,22,NORTH,31,36,NORTH+.6,'wood',.9)
  face({12.8,22.8,NORTH+.65},{30.2,22.8,NORTH+.65},{30.2,35.2,NORTH+.65},{12.8,35.2,NORTH+.65},'sage',1.1)
  for i=0,7 do local x=14+hash(i,2)*14;local y=24+hash(2,i)*9
   box(x,y,NORTH+.7,x+1.1,y+1.1,NORTH+.9,i%3==0 and'red'or'navy',1)end
  box(14,30.5,NORTH+.7,28,30.9,NORTH+.85,'ktCedar',1)
 end
 -- Pokedex table, cells 2-3 row 1 (x 32..64, z 16..32).
 do
  box(33,T-1.2,16.5,63,T,31.5,'ktPearl',1.06)
  box(33.4,T-3,17,62.6,T-1.2,31,'oak',.95)
  for _,x in ipairs({34,61})do for _,z in ipairs({18,29.5})do box(x,0,z,x+1.6,T-3,z+1.6,'ktSteel',.9)end end
  box(36,T,20,46,T+.15,28,'ktMarine',1.05)                     -- desk mat
  -- A microscope and a rack of test tubes either side of the Pokedexes.
  box(56,T,19,61,T+.6,23,'dark',.8);box(58,T+.6,20,59,T+6,21.2,'ktSteel',1);box(56.8,T+5.2,19.5,59.8,T+6.2,22.5,'ktSteel',1.05)
  cyl(58.4,T+2.5,T+4,23,.7,.5,'dark',8,.8)
  box(48,T,26,55,T+1,29,'wood',.95)
  for i=0,3 do cyl(49+i*1.8,T+1,T+4.5,27.5,.55,.55,'glass',8,1.1,true);cyl(49+i*1.8,T+1,T+2.2,27.5,.5,.5,({'red','green','ktMarine','gold'})[i+1],8,1.2,true)end
 end
 -- Tall bookcases, cells 6-9 rows 0-1.
 bookcase(G,96,160,NORTH,31,46,11,false)
 box(118,2,31.2,119,44,31.9,'ktSteel',1);box(121.5,2,31.2,122.5,44,31.9,'ktSteel',1)  -- rolling ladder
 for y=5,41,4.5 do box(118,y,31.3,122.5,y+.5,31.8,'ktSteel',1)end
 box(117,44.5,30.5,124,45.2,31.8,'ktSteel',1)
 -- Starter display table, cells 6-8 row 3 (x 96..144, z 48..64).
 do
  box(97,T-1.4,49,143,T,63,'white',1.08)
  box(96.6,T-1.6,48.6,143.4,T-1.2,63.4,'red',1.05)
  box(98,1.2,50,142,T-1.6,62,'ktPearl',.92)
  box(97.4,0,49.4,142.6,1.2,62.6,'ktSteel',.8)
  for _,x in ipairs({104,120,136})do
   cyl(x,T,T+.35,56,3.4,3.4,'navy',16,1.05)                    -- cushions under each ball
   box(x-3,T-1.2,62.9,x+3,T-.35,63.15,'gold',1.15)
  end
  pokeball(G,120,T-4.6,62.1,2.0)
 end
 -- Double-sided book stacks, rows 6-7 (z 96..128).
 bookcase(G,0,64,98,126,34,201,true)
 bookcase(G,96,160,98,126,34,377,true)
 -- Wall-height potted palms in the two north corners of the walkway.
 -- Trailing plants on top of the bookcases and stacks.
 for i,x in ipairs({104,152})do plant(G,x,46.6,20,.75,i)end
 for i,x in ipairs({8,56,104,152})do plant(G,x,34.6,112,.6,i+4)end
 -- Wall: the two source scrolls (cells 4-5 row 0) as framed hanging scrolls.
 for _,x in ipairs({72,88})do
  box(x-6.2,40,NORTH,x+6.2,41,NORTH+1.6,'wood',.95)
  for _,e in ipairs({x-7.2,x+6.2})do box(e,39.6,NORTH+.2,e+1,41.4,NORTH+2,'wood',1.05)end
  face({x-5.4,20,NORTH+1},{x+5.4,20,NORTH+1},{x+5.4,40,NORTH+1},{x-5.4,40,NORTH+1},'cream',1.1)
  box(x-6,19,NORTH+.6,x+6,20,NORTH+1.6,'wood',.95)
  -- Brush calligraphy strokes.
  for i=0,4 do local y=37-i*3.6;local w=1.6+hash(x,i)*2.4
   box(x-w,y,NORTH+1.02,x+w,y+.7,NORTH+1.1,'dark',.7)
   box(x-.4+hash(i,x)*1.2,y-1.6,NORTH+1.02,x+.3+hash(i,x)*1.2,y+.7,NORTH+1.1,'dark',.7)
  end
  box(x-1.4,22,NORTH+1.02,x+1.4,24.8,NORTH+1.1,'red',1)
 end
 return G
end
-- Wall and ceiling shells, separate so the camera can cut them away.
local function wallSpan(G,left,right,opts)
 opts=opts or {}
 local box,face=G.box,G.face
 local base=opts.base or 0
 box(left,base,-2,right,WALL,0,'ktPlaster',.98)
 if base==0 then
  box(left,0,0,right,16,.6,'oak',.82)                          -- wainscot
  box(left,16,0,right,17.2,1.0,'wood',1.05)                    -- chair rail
  box(left,0,0,right,1.5,1.0,'wood',.78)                       -- skirting
  for x=left+4,right-6,12 do box(x,3,.6,x+8,13.5,.75,'oak',.9)end -- raised panels
 end
 box(left,WALL-3,0,right,WALL-1.6,1.4,'white',1.05)            -- cornice
 box(left,WALL-1.6,0,right,WALL,2.2,'white',1.1)
 for _,w in ipairs(opts.windows or{})do
  local a,b,lo,hi=w[1],w[2],w[3] or 22,w[4] or 50
  box(a-1.2,lo-1.2,-.2,b+1.2,hi+1.2,.9,'white',1.08)
  box(a-1.6,lo-2,-.2,b+1.6,lo-1.1,2.2,'white',1.1)             -- sill
  face({a,lo,.95},{b,lo,.95},{b,hi,.95},{a,hi,.95},'glass',1.2,true)
  local mid=(a+b)/2
  box(mid-.4,lo,.95,mid+.4,hi,1.3,'white',1.05)
  for y=lo+(hi-lo)/3,hi-1,(hi-lo)/3 do box(a,y-.35,.95,b,y+.35,1.3,'white',1.05)end
 end
 for _,c in ipairs(opts.charts or{})do
  local a,b,lo,hi,mat=c[1],c[2],c[3],c[4],c[5]
  box(a-.6,lo-.6,0,b+.6,hi+.6,.5,'wood',.9)
  face({a,lo,.55},{b,lo,.55},{b,hi,.55},{a,hi,.55},mat or'cream',1.1)
  if c.ball then
   for i=0,15 do local an,bn=i*pi/8,(i+1)*pi/8;local cx,cy,r=(a+b)/2,(lo+hi)/2+1,min(b-a,hi-lo)*.3
    face({cx,cy,.6},{cx+r*cos(an),cy+r*sin(an),.6},{cx+r*cos(bn),cy+r*sin(bn),.6},{cx+r*cos(bn),cy+r*sin(bn),.6},i<8 and'red'or'white',1.05)end
  else
   for i=0,4 do local y=lo+2+i*(hi-lo-4)/5;box(a+1.2,y,.56,a+1.2+(b-a-2.4)*(.4+hash(i,a)*.55),y+.6,.62,i==0 and'red'or'navy',1)end
  end
 end
end
function M.shell(part)
 local G=builder()
 if part=='north' then
  G.frame(0,NORTH,0)
  wallSpan(G,0,W,{charts={{38,58,22,36,'cream',ball=true}}})
 elseif part=='west' then
  G.frame(0,D/2,1)
  wallSpan(G,-D/2,D/2-NORTH,{windows={{28,52},{-64,-40}},charts={{4,20,26,42,'sage'}}})
 elseif part=='east' then
  G.frame(W,D/2,-1)
  wallSpan(G,-(D/2-NORTH),D/2,{windows={{-52,-28},{40,64}},charts={{-20,-4,26,42,'cream',ball=true}}})
 elseif part=='south' then
  G.frame(W/2,D,2)
  -- Doorway over the exit mat (x 64..96) stays open to the warp.
  wallSpan(G,-W/2,-16);wallSpan(G,16,W/2);wallSpan(G,-16,16,{base=36})
  local box=G.box
  box(-17.5,0,-2,-16,36,1.6,'white',1.1);box(16,0,-2,17.5,36,1.6,'white',1.1)
  box(-17.5,34.5,-2,17.5,36,1.8,'white',1.1)
  G.face({-16,26,1.4},{16,26,1.4},{16,34.4,1.4},{-16,34.4,1.4},'glass',1.2,true)
  -- Closed glass double doors just beyond the warp mat.
  box(-16,25.4,-1.6,16,26.4,1.2,'ktSteel',1)
  for _,sg in ipairs({-1,1})do
   local a,b=sg<0 and -15.6 or .3,sg<0 and -.3 or 15.6
   box(a,0,-1.5,b,25.4,-.9,'ktSteel',.95)
   G.face({a+1.4,2.5,-.85},{b-1.4,2.5,-.85},{b-1.4,24,-.85},{a+1.4,24,-.85},'glass',1.15,true)
   local hx=sg<0 and -2.6 or 1.6
   box(hx,11,-.85,hx+1,15,-.2,'gold',1.1)
  end
 elseif part=='ceiling' then
  local box,face=G.box,G.face
  box(0,WALL,NORTH-2,W,WALL+1,D,'ktPlaster',1)
  for x=8,W-8,48 do for z=NORTH+14,D-12,40 do
   box(x+2,WALL-.8,z,x+30,WALL,z+14,'ktSteel',.9)
   face({x+3,WALL-.85,z+1},{x+29,WALL-.85,z+1},{x+29,WALL-.85,z+13},{x+3,WALL-.85,z+13},'white',1.35,true)
  end end
 end
 return G
end
local function texture()
 if not white then
  local d=love.image.newImageData(2,2);for y=0,1 do for x=0,1 do d:setPixel(x,y,1,1,1,1)end end
  white=love.graphics.newImage(d);white:setFilter('nearest','nearest');d:release()
 end
 return white
end
local function prepare(map)
 if not M.accepts(map)then return end
 if cached then return cached end
 local R=V.require('Voxel3D')
 local G=M.room()
 local mesh=R.newMesh(G.vs,G.ix);if not mesh then return end
 local shell={}
 for _,part in ipairs({'north','south','east','west','ceiling'})do
  local s=M.shell(part);shell[part]=R.newMesh(s.vs,s.ix)
 end
 cached={mesh=mesh,shell=shell,vertices=#G.vs}
 return cached
end
function M.build(S,map)
 if not M.accepts(map)then return end
 for ty=0,map.def.height*4-1 do for tx=0,map.def.width*4-1 do
  local k=key(tx,ty)
  -- nil means no source underlay. false requests a donor floor from the
  -- final Structures fallback, which would sit coplanar with our wood.
  S.skip[k]=true;S.ground[k]=nil
  S.shapeAt[k]={class='ground',h=0,flat=true,art='flat',authored=true}
 end end
 S.oakLabRoom=true
end
-- Keep the far walls; omit any wall between the camera and the room.
function M.visibleShell(eye)
 eye=eye or {W/2,30,D}
 return {north=eye[3]>NORTH,south=eye[3]<D,west=eye[1]>0,east=eye[1]<W,ceiling=eye[2]<WALL}
end
function M.draw(map,shadow)
 local r=prepare(map);if not r then return end
 local tex=texture()
 if shadow then shadow.draw(r.mesh,tex);return end
 local R=V.require('Voxel3D')
 R.glass(false)
 local ok,err=pcall(function()
  if R.seams then R.seams(false)end
  R.draw(r.mesh,tex)
  local visible=M.visibleShell(R.eye)
  for _,part in ipairs({'north','south','east','west','ceiling'})do
   if visible[part]and r.shell[part]then R.draw(r.shell[part],tex)end
  end
 end)
 if R.seams then R.seams(true)end
 R.glass(true)
 if not ok then error(err)end
end
function M.invalidate()
 if cached then cached.mesh:release();for _,m in pairs(cached.shell)do m:release()end;cached=nil end
end
function M.setLive(live)if not(live and live.OAKS_LAB)then M.invalidate()end end
return M
