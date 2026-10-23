-- TEST166: THE LEAGUE ANTECHAMBER. The Route 22 gate is the last room
-- before the badge road, so it is rebuilt as one authored marble hall in
-- the League's own finishes (LeagueArchitecture's emitter and models):
--
--  * north: the grand portal to Route 23 -- gilded bronze doors under a
--    crimson sunburst lunette, the eight gym badges turning in an arc
--    around it, POKEMON LEAGUE in gold on a crimson frieze;
--  * the source's four statues: bronze eagles on marble plinths flanking
--    the portal, blazing braziers on fluted columns by the entrance;
--  * a crimson runner on a veined-marble floor set with verde cabochons,
--    an inlaid compass medallion under a coffered dome and chandeliers;
--  * side walls of fluted pilasters, crimson banners and gilded steles
--    naming the Elite Four, candle sconces throughout.
--
-- The ROM map still owns collision, warps and the guard. Everything built
-- here sits on the cells the game already blocks (row 0, the statues) or
-- on the walls and ceiling; the walkable floor stays clear.
-- Fires, candles and the badges are animated by LeagueRoad.drawRoomFx.
local V=...
local M={REVISION='league-gate-room-167'}
local RM=V.require('ReferenceMaterials')
local pi,cos,sin,floor,min,max,abs,sqrt=math.pi,math.cos,math.sin,math.floor,math.min,math.max,math.abs,math.sqrt
local W,D,H=160,128,84      -- room footprint (5x4 blocks) and wall height
local NZ=16                 -- the north wall's face (row 0 is wall)
local DA,DB=64,96           -- the portal / the exit (cells 4-5)
local DH=30                 -- portal leaf height
local PZ=7                  -- the doors' plane: a deep marble reveal, so the
                            -- player stepping onto the warp never meets them
local CZ=64                 -- dome, medallion and main chandelier
M.W,M.D,M.H,M.NZ=W,D,H,NZ
local cached,white
local function key(x,y)return (y+64)*4096+x+64 end

function M.accepts(map)
 if not(map and map.id=='ROUTE_22_GATE' and map.def and map.def.width==5 and map.def.height==4)then return false end
 local ok,on=pcall(function()return V.require('LeagueArchitecture').leagueStyle()end)
 return (ok and on)and true or false
end

local function kit()return V.require('LeagueArchitecture').kit end

------------------------------------------------------------------ helpers
-- A wall plane in a local frame: x along the wall, y up, +z into the room.
local BADGES={'BOULDER','CASCADE','THUNDER','RAINBOW','SOUL','MARSH','VOLCANO','EARTH'}
local function fan(L,cx,cy,z,r,n,mat,t,rot,ry)
 rot=rot or 0;ry=ry or r
 for i=0,n-1 do
  local a0,a1=rot+i/n*pi*2,rot+(i+1)/n*pi*2
  L.quad({cx,cy,z},{cx+cos(a0)*r,cy+sin(a0)*ry,z},{cx+cos(a1)*r,cy+sin(a1)*ry,z},{cx,cy,z},mat,t)
 end
end
local function ringXY(L,cx,cy,z,r0,r1,n,mat,t,a0,a1)
 a0,a1=a0 or 0,a1 or pi*2
 for i=0,n-1 do
  local b0,b1=a0+(a1-a0)*i/n,a0+(a1-a0)*(i+1)/n
  L.quad({cx+cos(b0)*r1,cy+sin(b0)*r1,z},{cx+cos(b0)*r0,cy+sin(b0)*r0,z},{cx+cos(b1)*r0,cy+sin(b1)*r0,z},{cx+cos(b1)*r1,cy+sin(b1)*r1,z},mat,t)
 end
end
local function starXY(L,cx,cy,z,r1,r2,n,mat,t)
 for i=0,n*2-1 do
  local a0,a1=pi/2+i/(n*2)*pi*2,pi/2+(i+1)/(n*2)*pi*2
  local ra,rb=i%2==0 and r1 or r2,i%2==0 and r2 or r1
  L.quad({cx,cy,z},{cx+cos(a0)*ra,cy+sin(a0)*ra,z},{cx+cos(a1)*rb,cy+sin(a1)*rb,z},{cx,cy,z},mat,t)
 end
end
-- a candle sconce on a wall (local frame); returns the flame point
local function sconce(L,toWorld,x,y,dz)
 dz=dz or 0
 L.box(x-1.5,y-3.2,dz,x+1.5,y+2.2,dz+.45,'lgGold',1,{bottom=false})
 L.box(x-.9,y-2.6,dz+.45,x+.9,y+1.6,dz+.7,'lgCrimson',1,{bottom=false})
 L.box(x-.35,y-.3,dz+.45,x+.35,y+.3,dz+2.6,'lgGold',1,{bottom=false})
 local out={}
 for _,dx in ipairs({-2.2,2.2})do
  L.box(math.min(x,x+dx),y-.3,dz+2.3,math.max(x,x+dx),y+.3,dz+2.9,'lgGold',1,{bottom=false})
  L.frustum(x+dx,y+.3,dz+2.6,.45,y+1.2,1.0,8,'lgGold',true)
  L.frustum(x+dx,y+1.2,dz+2.6,.36,y+3.2,.34,8,'lgMarble',true)
  local wx,wy,wz=toWorld(x+dx,y+3.3,dz+2.6)
  out[#out+1]={x=wx,y=wy,z=wz,s=.75}
 end
 L.frustum(x,y-3.2,dz+.9,.2,y-1.8,.75,6,'lgGold')
 return out
end
-- the shared wall order: plinth, dado panels, chair rail, fluted pilasters,
-- entablature, cove and an overhead cap. spans = solid runs {x0,x1};
-- pil = pilaster centres.
local function wallBody(L,len,spans,pil,frieze)
 -- the face itself is emitted by the caller (it knows the openings)
 for _,sp in ipairs(spans)do
  local a,b=sp[1],sp[2]
  L.box(a,0,0,b,5,1.2,'lgVerde',1,{bottom=true})
  L.box(a,5,0,b,5.7,1.35,'lgGold',1,{bottom=true})
  L.box(a,15.4,0,b,16.6,1.0,'lgMarble',1,{})
 end
 for _,px in ipairs(pil)do
  L.box(px-4.2,0,0,px+4.2,6.4,1.7,'lgVerde',1,{bottom=true})
  L.box(px-3.6,6.4,0,px+3.6,7.1,1.4,'lgGold',1,{bottom=true})
  L.decor(function()
   L.box(px-3,7.1,0,px+3,H-19,1.0,'lgFluteD',1,{bottom=true,top=true})
   L.box(px-3.5,H-19,0,px+3.5,H-17.6,1.3,'lgGold',1,{})
   L.box(px-4.2,H-17.6,0,px+4.2,H-16,1.6,'lgGold',.94,{})
   -- acanthus hint: a gilded lozenge on the capital
   L.quad({px,H-18.7,1.32},{px+1.4,H-18.3,1.32},{px,H-17.9,1.32},{px-1.4,H-18.3,1.32},'lgMarble',1.1)
  end)
 end
 -- entablature (full length)
 L.box(0,H-16,0,len,H-15,1.0,'lgGold',1,{})
 L.box(0,H-15,0,len,H-7,.6,'lgCrimson',1,{bottom=true})
 L.decor(function()
  local dx=1
  while dx<len-1 do L.quad({dx,H-6.8,.66},{dx+1.2,H-6.8,.66},{dx+1.2,H-5.8,.66},{dx,H-5.8,.66},'lgGold',.95);dx=dx+3.2 end
  for _,fx in ipairs(frieze or{})do
   L.quad({fx,H-13.4,.66},{fx+2.4,H-11,.66},{fx,H-8.6,.66},{fx-2.4,H-11,.66},'lgGold',1)
  end
 end)
 L.box(0,H-5.6,0,len,H-2.6,1.8,'lgMarble',1,{})
 L.box(0,H-2.6,0,len,H-2,2.0,'lgGold',1,{})
 L.box(0,H-2,0,len,H,2.6,'lgMarble',1,{top=true,bottom=true})
 -- the wall's top, seen when an overhead camera looks down into the room
 L.box(-1,H,-6,len+1,H+.8,2.6,'lgMarble',1,{bottom=true})
end
local function face(L,x0,y0,x1,y1,mat,t)
 if x1-x0<.01 or y1-y0<.01 then return end
 L.quad({x0,y0,0},{x1,y0,0},{x1,y1,0},{x0,y1,0},mat or 'lgMarble',t or 1)
end
-- a crimson silk panel in a gilded frame (between pilasters)
local function silkPanel(L,a,b,y0,y1)
 L.box(a,y0,0,b,y1,.35,'lgGold',1,{bottom=false})
 L.box(a+.8,y0+.8,.35,b-.8,y1-.8,.5,'lgCrimson',1,{bottom=false})
 L.decor(function()
  L.box(a+2.2,y0+2.2,.5,b-2.2,y0+2.7,.62,'lgGold',1,{})
  L.box(a+2.2,y1-2.7,.5,b-2.2,y1-2.2,.62,'lgGold',1,{})
  L.box(a+2.2,y0+2.7,.5,a+2.7,y1-2.7,.62,'lgGold',1,{})
  L.box(b-2.7,y0+2.7,.5,b-2.2,y1-2.7,.62,'lgGold',1,{})
 end)
end
-- dado panels: verde inlays in gilded frames under the chair rail
local function dado(L,a,b)
 if b-a<6 then return end
 L.box(a+1.4,7.2,0,b-1.4,14.2,.35,'lgGold',1,{})
 L.box(a+2,7.8,.35,b-2,13.6,.5,'lgVerde',1,{})
end
-- a crimson banner hanging from the frieze: gold rod, border, star, fringe
local function banner(L,x,top,bot)
 local w=6.6
 L.box(x-8.4,top+.2,.4,x+8.4,top+1.2,1.6,'lgGold',1,{})
 L.sphere(x-8.9,top+.7,1.0,.8,.8,.8,'lgGold',6,4)
 L.sphere(x+8.9,top+.7,1.0,.8,.8,.8,'lgGold',6,4)
 local z=1.0
 L.quad({x-w,bot+4,z},{x+w,bot+4,z},{x+w,top,z},{x-w,top,z},'lgCrimson',1)
 L.quad({x-w,bot+4,z},{x,bot,z},{x+w,bot+4,z},{x-w,bot+4,z},'lgCrimson',1)
 L.decor(function()
  local g=.06
  L.box(x-w,bot+4,z,x-w+.7,top,z+.15,'lgGold',1,{})
  L.box(x+w-.7,bot+4,z,x+w,top,z+.15,'lgGold',1,{})
  L.box(x-w,top-1.4,z,x+w,top-.7,z+.15,'lgGold',1,{})
  -- the V hem, gilded
  for _,sx in ipairs({-1,1})do
   L.quad({x+sx*w,bot+4,z+g},{x+sx*(w-.9),bot+4,z+g},{x,bot+.9,z+g},{x,bot,z+g},'lgGold',1)
  end
  starXY(L,x,(top+bot)/2+5,z+.1,4.6,1.9,5,'lgGold',1.05)
  ringXY(L,x,(top+bot)/2+5,z+.08,5.4,6.0,20,'lgGold',1)
  -- a gold bar and diamond under the star
  L.box(x-4,(top+bot)/2-2.6,z,x+4,(top+bot)/2-2,z+.15,'lgGold',1,{})
  L.quad({x,(top+bot)/2-6.2,z+.1},{x+1.6,(top+bot)/2-4.4,z+.1},{x,(top+bot)/2-2.8,z+.1},{x-1.6,(top+bot)/2-4.4,z+.1},'lgGold',1)
 end)
end
-- a gilded stele naming one of the Elite Four
local function stele(L,x,name,seed)
 local K=kit()
 local y0,y1=18,50
 L.box(x-8.2,y0-1.2,0,x+8.2,y0,1.6,'lgMarble',1,{bottom=false})
 L.box(x-8,y0,0,x+8,y1,.6,'lgGold',1,{bottom=false})
 L.box(x-7,y0+1,.6,x+7,y1-1,.9,'lgVerde',1,{bottom=false})
 -- a round pediment
 for i=0,11 do
  local a0,a1=i/12*pi,(i+1)/12*pi
  L.quad({x+cos(a1)*8,y1+sin(a1)*8,.6},{x+cos(a0)*8,y1+sin(a0)*8,.6},{x+cos(a0)*8,y1+sin(a0)*8,0},{x+cos(a1)*8,y1+sin(a1)*8,0},'lgGold',.9)
 end
 L.decor(function()
  fan(L,x,y1,.6,8,12,'lgGold',1,0)
  for i=0,11 do
   local a0,a1=i/12*pi,(i+1)/12*pi
   L.quad({x,y1,.9},{x+cos(a0)*6.6,y1+sin(a0)*6.6,.9},{x+cos(a1)*6.6,y1+sin(a1)*6.6,.9},{x,y1,.9},'lgCrimson',1)
  end
  starXY(L,x,y1+2.6,1.0,3.0,1.25,5,'lgGold',1.1)
  -- laurel round a star medallion
  local my=37
  ringXY(L,x,my,.95,4.2,4.8,20,'lgGold',1)
  starXY(L,x,my,1.0,3.6,1.5,5,'lgGold',1.08)
  for side=-1,1,2 do
   for k=0,6 do
    local a=pi*1.5+side*(.55+k*.33)
    local lx,ly=x+cos(a)*6.4,my+sin(a)*6.4
    local ox,oy=cos(a+side*1.2)*1.1,sin(a+side*1.2)*1.1
    L.quad({lx-ox*.4,ly-oy*.4,1.0},{lx+oy*.45,ly-ox*.45,1.0},{lx+ox,ly+oy,1.0},{lx-oy*.45,ly+ox*.45,1.0},'lgGold',.96)
   end
  end
  K.inscription(L,name,x,y0+3.2,.9,.62,'lgGold',12.4)
  L.box(x-5.5,y0+7.4,.9,x+5.5,y0+7.8,1.05,'lgGold',1,{})
 end)
end

------------------------------------------------------------------ the room
local function toMesh(quads)
 local vs,ix={},{}
 for _,q in ipairs(quads)do
  local sh=RM.encode(q.referenceMaterial,q.shade)
  local n=#vs
  for i=1,4 do local p=q[i];vs[n+i]={p[1],p[2],p[3],.5,.5,type(sh)=='table'and sh[i]or sh}end
  local k=#ix
  ix[k+1],ix[k+2],ix[k+3],ix[k+4],ix[k+5],ix[k+6]=n+1,n+2,n+3,n+1,n+3,n+4
 end
 return vs,ix
end

-- Every part as quads (and the effect points). Pure: no LOVE needed.
function M.geometry()
 local K=kit()
 local parts={}
 local fx={fires={},candles={},badges={},pools={},glow=.55}
 local function part(name)
  local q={};parts[name]=q
  return K.newEmitter(q,{.5,.5}),q
 end

 ---------------------------------------------------------------- floor
 local E=part('room')
 local c=3
 for z=NZ,D-16,16 do for x=0,W-16,16 do
  local function P(a,b)return{x+a,0,z+b}end
  E.quad(P(c,0),P(16-c,0),P(16-c,16),P(c,16),'lgMarble',1)
  E.quad(P(0,c),P(c,0),P(c,16),P(0,16-c),'lgMarble',1)
  E.quad(P(16-c,0),P(16,c),P(16,16-c),P(16-c,16),'lgMarble',1)
  E.quad(P(0,0),P(c,0),P(0,c),P(0,c),'lgVerde',1)
  E.quad(P(16-c,0),P(16,0),P(16,c),P(16,c),'lgVerde',1)
  E.quad(P(16,16-c),P(16,16),P(16-c,16),P(16-c,16),'lgVerde',1)
  E.quad(P(0,16-c),P(c,16),P(0,16),P(0,16),'lgVerde',1)
 end end
 -- the runner: crimson, gilded borders, a diamond every cell; it parts
 -- round the medallion
 local MR=22
 local function runner(z0,z1)
  local x0,x1=66,94
  E.box(x0,0,z0,x1,.2,z1,'lgCarpet',1,{bottom=true})
  E.box(x0,0,z0,x0+1.3,.28,z1,'lgGold',1,{bottom=true})
  E.box(x1-1.3,0,z0,x1,.28,z1,'lgGold',1,{bottom=true})
  E.decor(function()
   E.box(x0+2.6,.2,z0+.6,x0+3.1,.25,z1-.6,'lgGold',1,{bottom=true})
   E.box(x1-3.1,.2,z0+.6,x1-2.6,.25,z1-.6,'lgGold',1,{bottom=true})
   local z=z0+8
   while z<z1-5 do
    E.quad({80,.23,z-1.6},{81.6,.23,z},{80,.23,z+1.6},{78.4,.23,z},'lgGold',1.05)
    z=z+16
   end
  end)
 end
 runner(PZ-3.4,CZ-MR+.5)
 runner(CZ+MR-.5,D+6.6)
 -- the medallion: verde and gold rings, an eight-point star, a Poke Ball
 local function ringH(cx,cz,y,r0,r1,n,mat,t)
  for i=0,n-1 do
   local a0,a1=i/n*pi*2,(i+1)/n*pi*2
   E.quad({cx+cos(a0)*r0,y,cz+sin(a0)*r0},{cx+cos(a0)*r1,y,cz+sin(a0)*r1},{cx+cos(a1)*r1,y,cz+sin(a1)*r1},{cx+cos(a1)*r0,y,cz+sin(a1)*r0},mat,t)
  end
 end
 local function fanH(cx,cz,y,r,n,mat,t,a0,a1)
  a0,a1=a0 or 0,a1 or pi*2
  for i=0,n-1 do
   local b0,b1=a0+(a1-a0)*i/n,a0+(a1-a0)*(i+1)/n
   E.quad({cx,y,cz},{cx+cos(b0)*r,y,cz+sin(b0)*r},{cx+cos(b1)*r,y,cz+sin(b1)*r},{cx,y,cz},mat,t)
  end
 end
 E.decor(function()
  ringH(80,CZ,.08,MR-1.6,MR,40,'lgVerde',1)
  ringH(80,CZ,.10,MR-2.4,MR-1.6,40,'lgGold',1)
  fanH(80,CZ,.06,MR-2.4,40,'lgMarble',1.04)
  -- the compass star: eight long points, eight short, gold and crimson halves
  for i=0,15 do
   local a=i/16*pi*2
   local r=i%2==0 and 18.5 or 11
   local w=i%2==0 and .17 or .20
   local tip={80+cos(a)*r,.12,CZ+sin(a)*r}
   local l={80+cos(a-w)*7.6,.12,CZ+sin(a-w)*7.6}
   local rr={80+cos(a+w)*7.6,.12,CZ+sin(a+w)*7.6}
   local o={80,.12,CZ}
   E.quad(o,l,tip,tip,i%2==0 and'lgGold'or'lgVerde',1)
   E.quad(o,tip,rr,rr,i%2==0 and'lgCrimson'or'lgGold',1)
  end
  ringH(80,CZ,.14,7.6,8.4,32,'lgGold',1)
  -- a Poke Ball at the heart
  fanH(80,CZ,.15,7.6,16,'lgCrimson',1.05,pi,pi*2)
  fanH(80,CZ,.15,7.6,16,'lgMarble',1.08,0,pi)
  E.quad({72.4,.17,CZ-.7},{87.6,.17,CZ-.7},{87.6,.17,CZ+.7},{72.4,.17,CZ+.7},'lgVerde',1)
  fanH(80,CZ,.19,2.6,16,'lgVerde',1)
  fanH(80,CZ,.21,1.8,16,'lgMarble',1.12)
  fanH(80,CZ,.23,.9,12,'lgGold',1.1)
 end)

 ---------------------------------------------------------------- statues
 -- north pair: bronze eagles on marble plinths, facing the entrance
 for i,X in ipairs({56,104})do
  local Z=24
  local Lm=K.model(E,X,0,Z,0,1)
  Lm.box(-7.4,0,-7.4,7.4,1.6,7.4,'lgVerde',1,{bottom=true})
  Lm.box(-6.6,1.6,-6.6,6.6,2.5,6.6,'lgGold',1,{bottom=true})
  Lm.box(-5.6,2.5,-5.6,5.6,14,5.6,'lgMarble',1,{bottom=true})
  Lm.decor(function()
   Lm.box(-6.0,11.2,-6.0,6.0,12.0,6.0,'lgGold',1,{bottom=true})
   Lm.box(-3.6,4.0,5.6,3.6,9.8,5.85,'lgGold',1,{})
   Lm.box(-3.0,4.6,5.85,3.0,9.2,6.0,'lgCrimson',1,{})
   starXY(Lm,0,6.9,6.05,2.2,.9,5,'lgGold',1.1)
  end)
  Lm.box(-6.4,14,-6.4,6.4,15.3,6.4,'lgMarble',1,{bottom=false})
  Lm.box(-6.0,15.3,-6.0,6.0,15.9,6.0,'lgGold',1,{})
  K.eagle(K.model(E,X,15.9,Z+.6,0,.95),17+i)
 end
 -- south pair: braziers on fluted columns either side of the entrance
 for i,X in ipairs({56,104})do
  local Z=112
  local Lm=K.model(E,X,0,Z,0,1)
  Lm.box(-6.6,0,-6.6,6.6,2,6.6,'lgVerde',1,{bottom=true})
  Lm.box(-5.8,2,-5.8,5.8,2.8,5.8,'lgGold',1,{bottom=true})
  Lm.box(-5,2.8,-5,5,9,5,'lgMarble',1,{bottom=true})
  Lm.decor(function()
   for _,f in ipairs({{0,0,1},{0,0,-1},{1,0,0},{-1,0,0}})do
    local Lf=K.model(E,X+f[1]*5,0,Z+f[3]*5,math.atan2(f[1],f[3]),1)
    Lf.box(-2.6,4.2,0,2.6,7.6,.25,'lgGold',1,{})
    Lf.box(-2.0,4.8,.25,2.0,7.0,.4,'lgCrimson',1,{})
   end
  end)
  Lm.box(-5.6,9,-5.6,5.6,10,5.6,'lgMarble',1,{bottom=false})
  Lm.frustum(0,10,0,3.1,11.3,2.7,12,'lgGold',false)
  Lm.frustum(0,11.3,0,2.45,24,2.15,12,'lgMarble',false)
  Lm.frustum(0,15.6,0,2.40,16.3,2.40,12,'lgGold',false)
  Lm.frustum(0,24,0,2.15,25.2,3.0,12,'lgGold',false)
  local yc=K.fireBowl(Lm,25.2,1.8,5.4,3.6)
  fx.fires[#fx.fires+1]={x=X,y=yc+.2,z=Z,s=1.15,phase=i*2.3}
  fx.pools[#fx.pools+1]={x=X,y=.3,z=Z-10,r=26,a=.10}
 end

 ---------------------------------------------------------------- walls
 local pilNS={4,24,44,116,136,156}
 local baysNS={{7.5,20.5},{27.5,40.5},{119.5,132.5},{139.5,152.5}}
 -- NORTH (the hero wall): local x = world x, face at z=NZ
 do
  local E2=part('north')
  local L=K.model(E2,0,0,NZ,0,1)
  local function toWorld(x,y,z)return x,y,NZ+z end
  face(L,0,0,DA,H,'lgMarble',1);face(L,DB,0,W,H,'lgMarble',1)
  face(L,DA,DH+3.4,DB,H,'lgMarble',1)
  wallBody(L,W,{{0,DA-.5},{DB+.5,W}},pilNS,{14,146})
  for _,b in ipairs(baysNS)do
   silkPanel(L,b[1],b[2],19,H-22)
   dado(L,b[1],b[2])
   for _,c in ipairs(sconce(L,toWorld,(b[1]+b[2])/2,32,.5))do fx.candles[#fx.candles+1]=c;c.phase=#fx.candles*1.7 end
  end
  dado(L,47.5,56);dado(L,104,112.5)
  -- the portal: gilded bronze doors (LeagueArchitecture's doorway)
  K.doorway(E2,DA+.5,DB-.5,PZ,DH,true)
  -- the reveal: marble cheeks with gilded panels, a coffered soffit, and
  -- the floor running through under the runner
  do
   local x0,x1,y1=DA,DB,DH+3.4
   E2.quad({x0,0,PZ},{x0,0,NZ},{x0,y1,NZ},{x0,y1,PZ},'lgMarble',.82)
   E2.quad({x1,0,NZ},{x1,0,PZ},{x1,y1,PZ},{x1,y1,NZ},'lgMarble',.78)
   E2.quad({x0,y1,NZ},{x1,y1,NZ},{x1,y1,PZ},{x0,y1,PZ},'lgMarble',.62)
   E2.quad({x0,0,PZ-3.6},{x1,0,PZ-3.6},{x1,0,NZ},{x0,0,NZ},'lgMarble',1)
   E2.decor(function()
    for _,x in ipairs({x0+.05,x1-.05})do
     local sx=x<80 and 1 or -1
     E2.box(math.min(x,x+sx*.3),6,PZ+1.4,math.max(x,x+sx*.3),DH-2,NZ-1.4,'lgGold',1,{})
     E2.box(math.min(x,x+sx*.45),8,PZ+2.4,math.max(x,x+sx*.45),DH-4,NZ-2.4,'lgCrimson',1,{})
    end
    E2.box(x0+2,y1-.3,PZ+1.2,x1-2,y1-.05,NZ-1.2,'lgGold',1,{})
    E2.box(x0+3.4,y1-.45,PZ+2.4,x1-3.4,y1-.25,NZ-2.4,'lgCrimson',1,{})
   end)
  end
  -- fluted half-columns either side of the arch
  for _,px in ipairs({DA-4.5,DB+4.5})do
   L.box(px-3.2,0,0,px+3.2,6.4,2.6,'lgVerde',1,{bottom=true})
   L.box(px-2.8,6.4,0,px+2.8,7.1,2.3,'lgGold',1,{bottom=true})
   L.frustum(px,7.1,0,2.2,DH+3.4,2.0,10,'lgMarble',true)
   L.box(px-2.9,DH+3.4,0,px+2.9,DH+4.8,2.6,'lgGold',1,{})
  end
  -- the arch: crimson tympanum, gold sunburst, marble archivolt, keystone
  local cx,cy=80,DH+3.4
  local ri,ro=(DB-DA)/2+1.2,(DB-DA)/2+4.2
  local N=18
  for i=0,N-1 do
   local a0,a1=i/N*pi,(i+1)/N*pi
   local c0,s0,c1,s1=cos(a0),sin(a0),cos(a1),sin(a1)
   L.quad({cx,cy,.06},{cx+c0*ri,cy+s0*ri,.06},{cx+c1*ri,cy+s1*ri,.06},{cx,cy,.06},'lgCrimson',.95)
   L.quad({cx+c1*ri,cy+s1*ri,1.4},{cx+c0*ri,cy+s0*ri,1.4},{cx+c0*ro,cy+s0*ro,1.4},{cx+c1*ro,cy+s1*ro,1.4},'lgMarble',1)
   L.quad({cx+c0*ri,cy+s0*ri,1.4},{cx+c1*ri,cy+s1*ri,1.4},{cx+c1*ri,cy+s1*ri,-.2},{cx+c0*ri,cy+s0*ri,-.2},'lgMarble',.8)
   L.quad({cx+c1*ro,cy+s1*ro,1.4},{cx+c0*ro,cy+s0*ro,1.4},{cx+c0*ro,cy+s0*ro,-.2},{cx+c1*ro,cy+s1*ro,-.2},'lgMarble',1)
  end
  L.decor(function()
   ringXY(L,cx,cy,1.46,ri+.3,ri+.9,N,'lgGold',1,0,pi)
   ringXY(L,cx,cy,1.46,ro-.9,ro-.3,N,'lgGold',1,0,pi)
   for i=0,12 do
    local aa=(i+.5)/13*pi;local w=.07
    local r0,r1=3.4,ri-1.4
    L.quad({cx+cos(aa-w)*r0,cy+sin(aa-w)*r0,.12},{cx+cos(aa)*r1,cy+sin(aa)*r1,.12},{cx+cos(aa+w)*r0,cy+sin(aa+w)*r0,.12},{cx+cos(aa-w)*r0,cy+sin(aa-w)*r0,.12},'lgGold',1)
   end
   fan(L,cx,cy,.16,2.8,12,'lgGold',1.05,0)
  end)
  L.box(cx-2.4,cy+ri-.5,-.2,cx+2.4,cy+ro+1.4,1.9,'lgMarble',1,{})
  L.box(cx-1.5,cy+ri+.3,1.9,cx+1.5,cy+ro+.6,2.15,'lgGold',1,{})
  -- the eight badges in an arc round the arch: gilded medallions on the
  -- wall; the badges themselves turn in front of them (LeagueRoad)
  for i,name in ipairs(BADGES)do
   local a=pi-(i-.5)/8*pi
   local bx,by=cx+cos(a)*28,cy+sin(a)*26
   L.box(bx-.5,by-6.4,0,bx+.5,by-3.6,.5,'lgGold',1,{})
   ringXY(L,bx,by,.5,3.4,4.1,20,'lgMarble',1)
   L.decor(function()
    ringXY(L,bx,by,.62,2.9,3.4,20,'lgGold',1)
    fan(L,bx,by,.42,2.9,20,'lgVerde',1,0)
   end)
   fx.badges[#fx.badges+1]={name=name,x=bx,y=by,z=NZ+2.6,s=.78,phase=i*.9}
  end
  -- the inscription on the frieze, gilded star either side
  L.decor(function()
   K.inscription(L,'POKEMON LEAGUE',80,H-13.8,.6,1.15,'lgGold',66)
   starXY(L,36,H-11,.66,2.6,1.1,5,'lgGold',1.05)
   starXY(L,124,H-11,.66,2.6,1.1,5,'lgGold',1.05)
  end)
 end
 -- SOUTH: the way back to Route 22. Local x = W - world x, face at z=D.
 do
  local E2=part('south')
  local L=K.model(E2,W,0,D,pi,1)
  local function toWorld(x,y,z)return W-x,y,D-z end
  local a,b=W-DB,W-DA
  face(L,0,0,a,H,'lgMarble',1);face(L,b,0,W,H,'lgMarble',1)
  face(L,a,DH+3.4,b,H,'lgMarble',1)
  wallBody(L,W,{{0,a-.5},{b+.5,W}},pilNS,{14,36,124,146})
  for _,bb in ipairs(baysNS)do
   silkPanel(L,bb[1],bb[2],19,H-22)
   dado(L,bb[1],bb[2])
   for _,c in ipairs(sconce(L,toWorld,(bb[1]+bb[2])/2,32,.5))do fx.candles[#fx.candles+1]=c;c.phase=#fx.candles*1.7 end
  end
  dado(L,47.5,56);dado(L,104,112.5)
  -- TEST167: the exit is a portal like the north one: gilded doors in a
  -- deep marble reveal, fluted half-columns, and a crimson arch whose
  -- sunburst frames a gilded clock. VIRIDIAN CITY on the frieze.
  local QZ=-7
  K.doorway(L,a+.5,b-.5,QZ,DH,true)
  L.quad({b,0,QZ},{b,0,0},{b,DH+3.4,0},{b,DH+3.4,QZ},'lgMarble',.82)
  L.quad({a,0,0},{a,0,QZ},{a,DH+3.4,QZ},{a,DH+3.4,0},'lgMarble',.78)
  L.quad({a,DH+3.4,0},{b,DH+3.4,0},{b,DH+3.4,QZ},{a,DH+3.4,QZ},'lgMarble',.62)
  L.quad({a,.01,QZ-3.6},{b,.01,QZ-3.6},{b,.01,0},{a,.01,0},'lgMarble',1)
  L.decor(function()
   for _,x in ipairs({a+.05,b-.05})do
    local sx=x<80 and 1 or -1
    L.box(math.min(x,x+sx*.3),6,QZ+1.4,math.max(x,x+sx*.3),DH-2,-1.4,'lgGold',1,{})
    L.box(math.min(x,x+sx*.45),8,QZ+2.4,math.max(x,x+sx*.45),DH-4,-2.4,'lgCrimson',1,{})
   end
   L.box(a+2,DH+3.1,QZ+1.2,b-2,DH+3.35,-1.2,'lgGold',1,{})
  end)
  for _,px in ipairs({a-4.5,b+4.5})do
   L.box(px-3.2,0,0,px+3.2,6.4,2.6,'lgVerde',1,{bottom=true})
   L.box(px-2.8,6.4,0,px+2.8,7.1,2.3,'lgGold',1,{bottom=true})
   L.frustum(px,7.1,0,2.2,DH+3.4,2.0,10,'lgMarble',true)
   L.box(px-2.9,DH+3.4,0,px+2.9,DH+4.8,2.6,'lgGold',1,{})
  end
  do
   local cx,cy=80,DH+3.4
   local ri,ro=(b-a)/2+1.2,(b-a)/2+4.2
   local N=18
   for i=0,N-1 do
    local a0,a1=i/N*pi,(i+1)/N*pi
    local c0,s0,c1,s1=cos(a0),sin(a0),cos(a1),sin(a1)
    L.quad({cx,cy,.06},{cx+c0*ri,cy+s0*ri,.06},{cx+c1*ri,cy+s1*ri,.06},{cx,cy,.06},'lgCrimson',.95)
    L.quad({cx+c1*ri,cy+s1*ri,1.4},{cx+c0*ri,cy+s0*ri,1.4},{cx+c0*ro,cy+s0*ro,1.4},{cx+c1*ro,cy+s1*ro,1.4},'lgMarble',1)
    L.quad({cx+c0*ri,cy+s0*ri,1.4},{cx+c1*ri,cy+s1*ri,1.4},{cx+c1*ri,cy+s1*ri,-.2},{cx+c0*ri,cy+s0*ri,-.2},'lgMarble',.8)
    L.quad({cx+c1*ro,cy+s1*ro,1.4},{cx+c0*ro,cy+s0*ro,1.4},{cx+c0*ro,cy+s0*ro,-.2},{cx+c1*ro,cy+s1*ro,-.2},'lgMarble',1)
   end
   L.decor(function()
    ringXY(L,cx,cy,1.46,ri+.3,ri+.9,N,'lgGold',1,0,pi)
    ringXY(L,cx,cy,1.46,ro-.9,ro-.3,N,'lgGold',1,0,pi)
    for i=0,12 do
     local aa=(i+.5)/13*pi;local w=.07
     local r0,r1=8.4,ri-1.4
     L.quad({cx+cos(aa-w)*r0,cy+sin(aa-w)*r0,.12},{cx+cos(aa)*r1,cy+sin(aa)*r1,.12},{cx+cos(aa+w)*r0,cy+sin(aa+w)*r0,.12},{cx+cos(aa-w)*r0,cy+sin(aa-w)*r0,.12},'lgGold',1)
    end
   end)
   L.box(cx-2.4,cy+ri-.5,-.2,cx+2.4,cy+ro+1.4,1.9,'lgMarble',1,{})
   L.box(cx-1.5,cy+ri+.3,1.9,cx+1.5,cy+ro+.6,2.15,'lgGold',1,{})
   -- the clock, set in the tympanum
   local ky=cy+8.2
   ringXY(L,cx,ky,.5,5.4,6.6,24,'lgGold',1)
   fan(L,cx,ky,.4,5.4,24,'lgMarble',1.12,0)
   L.decor(function()
    for k=0,11 do
     local aa=k/12*pi*2
     local hx,hy=cx+cos(aa)*4.4,ky+sin(aa)*4.4
     L.box(hx-.3,hy-.3,.4,hx+.3,hy+.3,.7,'lgVerde',1,{})
    end
    L.box(cx-.3,ky-.2,.6,cx+.3,ky+3.9,.8,'lgVerde',1,{})
    L.box(cx-.2,ky-.3,.6,cx+3.1,ky+.3,.8,'lgVerde',1,{})
    fan(L,cx,ky,.85,.6,8,'lgGold',1.1,0)
   end)
  end
  L.decor(function()
   K.inscription(L,'VIRIDIAN CITY',80,H-13.8,.6,1.15,'lgGold',60)
  end)
 end
 -- WEST (local x = D - world z, face at x=0) and EAST (local x = world z - NZ)
 local SL=D-NZ
 local function side(name,ox,oz,yaw,toWorld,items)
  local E2=part(name)
  local L=K.model(E2,ox,0,oz,yaw,1)
  face(L,0,0,SL,H,'lgMarble',1)
  wallBody(L,SL,{{0,SL}},{0,28,56,84,SL},{14,42,70,98})
  for k,it in ipairs(items)do
   local a,b=(k-1)*28+3.5,k*28-3.5
   local mid=(a+b)/2
   dado(L,a,b)
   if it[1]=='banner'then banner(L,mid,H-16.6,22)
   else stele(L,mid,it[2],k)end
  end
  for _,px in ipairs({28,56,84})do
   for _,c in ipairs(sconce(L,toWorld,px,38,1.0))do fx.candles[#fx.candles+1]=c;c.phase=#fx.candles*1.7 end
  end
 end
 -- the sconces ride the pilasters: push them out past the shaft
 do
  local function west(x,y,z)return z,y,D-x end
  side('west',0,D,pi/2,west,{{'stele','LORELEI'},{'banner'},{'stele','BRUNO'},{'banner'}})
  local function east(x,y,z)return W-z,y,NZ+x end
  side('east',W,NZ,-pi/2,east,{{'banner'},{'stele','LANCE'},{'banner'},{'stele','AGATHA'}})
 end

 ---------------------------------------------------------------- ceiling
 local Ec=part('ceiling')
 local function down(x0,z0,x1,z1,y,mat,t)
  Ec.quad({x0,y,z1},{x1,y,z1},{x1,y,z0},{x0,y,z0},mat,t)
 end
 -- coffers: marble ribs, crimson wells with gold rosettes. The dome sits
 -- in the 4x4 block over the medallion.
 local DX0,DX1,DZ0,DZ1=48,112,CZ-32,CZ+32
 for z=NZ,D-16,16 do for x=0,W-16,16 do
  if not(x>=DX0 and x<DX1 and z>=DZ0 and z<DZ1)then
   local f,g,dp=1.2,2.6,3.2
   down(x,z,x+16,z+f,H,'lgMarble',.82);down(x,z+16-f,x+16,z+16,H,'lgMarble',.82)
   down(x,z+f,x+f,z+16-f,H,'lgMarble',.82);down(x+16-f,z+f,x+16,z+16-f,H,'lgMarble',.82)
   local a0,a1,b0,b1=x+f,x+16-f,z+f,z+16-f
   local c0,c1,d0,d1=x+g,x+16-g,z+g,z+16-g
   Ec.quad({a0,H,b0},{a1,H,b0},{c1,H+dp,d0},{c0,H+dp,d0},'lgMarble',.70)
   Ec.quad({a1,H,b1},{a0,H,b1},{c0,H+dp,d1},{c1,H+dp,d1},'lgMarble',.76)
   Ec.quad({a0,H,b1},{a0,H,b0},{c0,H+dp,d0},{c0,H+dp,d1},'lgMarble',.72)
   Ec.quad({a1,H,b0},{a1,H,b1},{c1,H+dp,d1},{c1,H+dp,d0},'lgMarble',.74)
   down(c0,d0,c1,d1,H+dp,'lgCrimson',.85)
   Ec.decor(function()
    local cx,cz=x+8,z+8
    for i=0,7 do
     local q0,q1=i/8*pi*2,(i+1)/8*pi*2
     local r=i%2==0 and 2.6 or 2.0
     Ec.quad({cx,H+dp-.06,cz},{cx+cos(q1)*2.3,H+dp-.06,cz+sin(q1)*2.3},{cx+cos(q0)*r,H+dp-.06,cz+sin(q0)*r},{cx,H+dp-.06,cz},'lgGold',1)
    end
    down(x+f,z+f-.25,x+16-f,z+f+.25,H-.05,'lgGold',.9)
    down(x+f-.25,z+f,x+f+.25,z+16-f,H-.05,'lgGold',.9)
   end)
  end
 end end
 -- the flat ring between the dome's drum and its square
 local DR,DN=30,24
 for i=0,DN-1 do
  local a0,a1=i/DN*pi*2,(i+1)/DN*pi*2
  local function sq(a)local cs,sn=cos(a),sin(a);local k=32/max(abs(cs),abs(sn));return 80+cs*k,CZ+sn*k end
  local ox0,oz0=sq(a0);local ox1,oz1=sq(a1)
  Ec.quad({80+cos(a1)*DR,H,CZ+sin(a1)*DR},{80+cos(a0)*DR,H,CZ+sin(a0)*DR},{ox0,H,oz0},{ox1,H,oz1},'lgMarble',.82)
 end
 Ec.decor(function()
  for i=0,DN-1 do
   local a0,a1=i/DN*pi*2,(i+1)/DN*pi*2
   Ec.quad({80+cos(a1)*(DR+1.2),H-.05,CZ+sin(a1)*(DR+1.2)},{80+cos(a0)*(DR+1.2),H-.05,CZ+sin(a0)*(DR+1.2)},{80+cos(a0)*DR,H-.05,CZ+sin(a0)*DR},{80+cos(a1)*DR,H-.05,CZ+sin(a1)*DR},'lgGold',.95)
  end
 end)
 -- drum, gold band, dome (marble gores between gilded ribs), oculus
 local DRUM=8
 for i=0,DN-1 do
  local a0,a1=i/DN*pi*2,(i+1)/DN*pi*2
  local p0={80+cos(a0)*DR,CZ+sin(a0)*DR};local p1={80+cos(a1)*DR,CZ+sin(a1)*DR}
  Ec.quad({p0[1],H,p0[2]},{p1[1],H,p1[2]},{p1[1],H+DRUM,p1[2]},{p0[1],H+DRUM,p0[2]},'lgMarble',.86)
  local q0={80+cos(a0)*(DR-.4),CZ+sin(a0)*(DR-.4)};local q1={80+cos(a1)*(DR-.4),CZ+sin(a1)*(DR-.4)}
  Ec.quad({q0[1],H+DRUM-2.2,q0[2]},{q1[1],H+DRUM-2.2,q1[2]},{q1[1],H+DRUM-1.2,q1[2]},{q0[1],H+DRUM-1.2,q0[2]},'lgGold',1)
  -- little round windows of light in the drum
  if i%3==1 then
   local m={80+cos((a0+a1)/2)*(DR-.3),CZ+sin((a0+a1)/2)*(DR-.3)}
   local tx,tz=-sin((a0+a1)/2),cos((a0+a1)/2)
   for k=0,7 do
    local b0,b1=k/8*pi*2,(k+1)/8*pi*2
    Ec.quad({m[1],H+3.2,m[2]},{m[1]+tx*cos(b0)*1.6,H+3.2+sin(b0)*1.6,m[2]+tz*cos(b0)*1.6},{m[1]+tx*cos(b1)*1.6,H+3.2+sin(b1)*1.6,m[2]+tz*cos(b1)*1.6},{m[1],H+3.2,m[2]},'cream',1.45)
   end
  end
 end
 local RINGS=6;local DY=16
 local function domeP(a,j)
  local e=j/RINGS*pi/2
  local r=cos(e)*DR;local y=H+DRUM+sin(e)*DY
  return {80+cos(a)*r,y,CZ+sin(a)*r}
 end
 for j=0,RINGS-2 do for i=0,DN-1 do
  local a0,a1=i/DN*pi*2,(i+1)/DN*pi*2
  local t=.74+.05*j
  Ec.quad(domeP(a0,j),domeP(a1,j),domeP(a1,j+1),domeP(a0,j+1),'lgPool',t+.12)
 end end
 Ec.decor(function()
  for i=0,DN-1,2 do
   local a=i/DN*pi*2;local w=.035
   for j=0,RINGS-2 do
    local p0,p1=domeP(a-w,j),domeP(a+w,j)
    local q0,q1=domeP(a-w*1.4,j+1),domeP(a+w*1.4,j+1)
    local function inw(p)return{p[1]-(p[1]-80)*.012,p[2]-.08,p[3]-(p[3]-CZ)*.012}end
    Ec.quad(inw(p0),inw(p1),inw(q1),inw(q0),'lgGold',1.05)
   end
  end
 end)
 -- the oculus: a gilded ring round a lantern of light
 local orr=cos((RINGS-1)/RINGS*pi/2)*DR
 local oy=H+DRUM+sin((RINGS-1)/RINGS*pi/2)*DY
 for i=0,DN-1 do
  local a0,a1=i/DN*pi*2,(i+1)/DN*pi*2
  Ec.quad({80+cos(a0)*orr,oy,CZ+sin(a0)*orr},{80+cos(a1)*orr,oy,CZ+sin(a1)*orr},{80+cos(a1)*orr,oy+3,CZ+sin(a1)*orr},{80+cos(a0)*orr,oy+3,CZ+sin(a0)*orr},'lgGold',.95)
  Ec.quad({80,oy+3,CZ},{80+cos(a1)*orr,oy+3,CZ+sin(a1)*orr},{80+cos(a0)*orr,oy+3,CZ+sin(a0)*orr},{80,oy+3,CZ},'cream',1.5)
 end
 -- chandeliers: the great one under the dome, two smaller in the coffers
 local function chandelier(X,Y,Z,s,top,arms)
  local Lc=K.model(Ec,X,Y,Z,0,s)
  Ec.box(X-.25,Y+10.5*s,Z-.25,X+.25,top,Z+.25,'lgGold',1,{bottom=true,top=true})
  Lc.frustum(0,-1.6,0,.1,0,.9,8,'lgGold')
  Lc.frustum(0,0,0,.9,1.4,1.6,8,'lgGold')
  Lc.frustum(0,1.4,0,1.6,3.2,1.0,8,'lgGold')
  Lc.frustum(0,3.2,0,.55,9,.45,8,'lgGold')
  Lc.sphere(0,6.2,0,1.3,1.6,1.3,'lgGold',8,4)
  Lc.frustum(0,9,0,.45,10.5,1.8,8,'lgGold',true)
  -- the lower ring and its arms
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
   -- crystal drops off the ring
   La.frustum(6.6,1.2,0,.08,3.4,.42,6,'lgMarble',false)
   La.frustum(3.6,5.2,0,.06,7.6,.32,6,'lgMarble',false)
   local cx,cz=X+cos(a)*7.25*s,Z+sin(a)*7.25*s
   fx.candles[#fx.candles+1]={x=cx,y=Y+7.1*s,z=cz,s=.85*s,a=.30,phase=k*1.3+X*.1,ceil=true}
  end
  -- upper tier of candles
  for k=0,arms/2-1 do
   local a=k/(arms/2)*pi*2
   local La=K.model(Ec,X,Y,Z,-a,s)
   La.box(.4,8.6,-.2,3.8,9.0,.2,'lgGold',1,{bottom=false})
   La.frustum(3.8,9.0,0,.4,9.7,.85,8,'lgGold',true)
   La.frustum(3.8,9.7,0,.3,11.4,.28,8,'lgMarble',true)
   fx.candles[#fx.candles+1]={x=X+cos(a)*3.8*s,y=Y+11.5*s,z=Z+sin(a)*3.8*s,s=.75*s,a=.28,phase=k*2.1+X*.07,ceil=true}
  end
  fx.pools[#fx.pools+1]={x=X,y=.32,z=Z,r=34*s,a=.07,ceil=true}
 end
 chandelier(80,62,CZ,1.3,oy,12)
 chandelier(26,60,CZ,.85,H+3.2,8)
 chandelier(134,60,CZ,.85,H+3.2,8)
 return parts,fx
end

------------------------------------------------------------------ runtime
local function texture()
 if not white then
  local d=love.image.newImageData(2,2);for y=0,1 do for x=0,1 do d:setPixel(x,y,1,1,1,1)end end
  white=love.graphics.newImage(d);white:setFilter('nearest','nearest');d:release()
 end
 return white
end
local ORDER={'room','north','south','west','east','ceiling'}
-- LOADING-STUTTER: `track` (the warm-ahead job below) makes the build yield
-- between the parts (the geometry yields per quad there) and holds the meshes
-- made so far, so a cancelled job can release them. A background build that a
-- draw finished first, or that an invalidate overtook, is thrown away.
local epoch=0
local function prepare(map,track)
 if not M.accepts(map)then return end
 if cached then return cached end
 local e0=epoch
 local R=V.require('Voxel3D')
 local ok,parts,fx=pcall(M.geometry)
 if not ok then
  if V.mod and V.mod.log and V.mod.log.info then pcall(V.mod.log.info,V.mod.log,'League gate room failed: %s',tostring(parts))end
  return
 end
 local Budget=track and V.require('BuildBudget')
 local meshes={};local count=0
 if track then track.meshes=meshes end
 for _,name in ipairs(ORDER)do
  if Budget then Budget.check()end
  local vs,ix=toMesh(parts[name]or{})
  if #vs>0 then meshes[name]=R.newMesh(vs,ix);count=count+#vs end
 end
 if track then track.meshes=nil end   -- no yield from here on: kept or released below
 if not meshes.room then return end
 if cached or epoch~=e0 then
  for _,m in pairs(meshes)do pcall(m.release,m)end
  return cached
 end
 cached={meshes=meshes,fx=fx,vertices=count}
 return cached
end

-- LOADING-STUTTER: build the room before the player walks in. It used to be
-- built on the first frame inside (12k quads: 55-80 ms in the phone's
-- interpreter, 290 ms seen with a busy heap). From Route 22 or Route 23,
-- within WARM_CELLS of a door into the gate, a job on ChunkMesher's queue
-- builds it in slices (and the portal's badge meshes LeagueRoad draws), and
-- the room is kept while either road is in the live set (about 2 MB).
-- Nothing waits for it: if it is not ready, the first frame builds it as before.
M.WARM_CELLS=12
M.WARM_PRIORITY=.3
local warmAt=-1e9
local function gateMap()
 local ok,Game=pcall(require,'src.core.Game')
 local def=ok and Game and Game.data and Game.data.maps and Game.data.maps.ROUTE_22_GATE
 return def and {id='ROUTE_22_GATE',def=def} or nil
end
function M.warmNear(state)
 if cached then return false end
 local now=love.timer.getTime()
 if now-warmAt<.5 then return false end
 warmAt=now
 local map,p=state and state.map,state and state.player
 if not(map and map.def and p)then return false end
 local px=tonumber(p.cellX)or math.floor((tonumber(p.px)or 0)/16)
 local py=tonumber(p.cellY)or math.floor((tonumber(p.py)or 0)/16)
 for _,w in ipairs(map.def.warps or{})do
  if w.destMap=='ROUTE_22_GATE'and math.abs((tonumber(w.x)or 0)-px)+math.abs((tonumber(w.y)or 0)-py)<=M.WARM_CELLS then
   local gate=gateMap()
   if not(gate and M.accepts(gate))then return false end
   local okC,CM=pcall(V.require,'ChunkMesher')
   if not(okC and CM and type(CM.requestWork)=='function')then return false end
   local track={}
   return(pcall(CM.requestWork,map,'gate-room','v1',M.WARM_PRIORITY,function()
    -- LeagueArchitecture's kit yields in this job only (its scoped budget)
    local okL,LA=pcall(V.require,'LeagueArchitecture')
    if okL and LA and LA.sliceJob then LA.sliceJob()end
    local r=prepare(gate,track)
    local okR,LR=pcall(V.require,'LeagueRoad')
    if r and okR and LR and LR.warmBadges then pcall(LR.warmBadges,r.fx)end
   end,function()
    -- cancelled mid-build: release what it made (ChunkMesher frees only its own uploads)
    for _,m in pairs(track.meshes or{})do pcall(m.release,m)end
    track.meshes=nil
   end))
  end
 end
 return false
end
function M.build(S,map)
 if not M.accepts(map)then return end
 for ty=-2,map.def.height*4+1 do for tx=-2,map.def.width*4+1 do
  local k=key(tx,ty)
  S.skip[k]=true;S.ground[k]=nil
  S.shapeAt[k]={class='ground',h=0,flat=true,art='flat',authored=true}
 end end
 S.leagueGateRoom=true
end
-- Keep the far walls; omit any wall between an outside camera and the room.
function M.visibleShell(eye)
 eye=eye or {W/2,30,D}
 local inside=eye[2]<H
 return {room=true,north=eye[3]>NZ,south=eye[3]<D,west=eye[1]>0,east=eye[1]<W,ceiling=inside}
end
function M.fx(map,eye)
 local r=prepare(map);if not r then return nil end
 local fx=r.fx
 local e=eye or {W/2,30,D}
 if (e[2] or 0)>=H then
  -- above the ceiling line: the chandeliers are not drawn, nor their candles
  local out={fires=fx.fires,badges=fx.badges,glow=fx.glow,pools={},candles={}}
  for _,c in ipairs(fx.candles)do if not c.ceil then out.candles[#out.candles+1]=c end end
  for _,p in ipairs(fx.pools)do if not p.ceil then out.pools[#out.pools+1]=p end end
  return out
 end
 return fx
end
function M.draw(map,shadow)
 local r=prepare(map);if not r then return end
 local tex=texture()
 if shadow then if r.meshes.room then shadow.draw(r.meshes.room,tex)end;return end
 local R=V.require('Voxel3D')
 R.glass(false)
 local ok,err=pcall(function()
  if R.seams then R.seams(false)end
  local visible=M.visibleShell(R.eye)
  for _,name in ipairs(ORDER)do
   if visible[name]and r.meshes[name]then R.draw(r.meshes[name],tex)end
  end
 end)
 if R.seams then R.seams(true)end
 R.glass(true)
 if not ok then error(err)end
end
function M.invalidate()
 epoch=epoch+1
 if cached then for _,m in pairs(cached.meshes)do pcall(m.release,m)end;cached=nil end
end
-- LOADING-STUTTER: also kept while a road leading in is live (see warmNear)
function M.setLive(live)
 if not(live and(live.ROUTE_22_GATE or live.ROUTE_22 or live.ROUTE_23))then M.invalidate()end
end
return M
