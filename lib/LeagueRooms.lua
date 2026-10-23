-- TEST172: THE POKEMON LEAGUE, INSIDE. The Indigo Plateau lobby, the four
-- Elite Four rooms, the Champion's room and the Hall of Fame are rebuilt as
-- authored rooms in the League's own finishes, each with its own world:
--
--   INDIGO PLATEAU LOBBY  a marble concourse: chandeliers, the Pokemon
--                         Center counter, trophy cabinets, the Elite Four
--                         portal at the end of the crimson road
--   LORELEI               an ice palace under the aurora: a frozen lake,
--                         crystal spires, blue fire, falling snow
--   BRUNO                 a mountain dojo: timber and granite, the rocks
--                         breaking through the boards, braziers, war drums
--   AGATHA                a gothic crypt: tombs, violet glass, candles,
--                         drifting mist and wisps
--   LANCE                 a dragon temple on causeways over a lava abyss,
--                         under a storm
--   CHAMPION              a sanctum of marble and gold under a dome of light
--   HALL OF FAME          open to the night sky: fireworks, confetti,
--                         spotlights and the golden record
--
-- The ROM map still owns collision, warps, trainers and scripts. Every
-- model stands on cells the game already blocks; the walkable floor is
-- flat at y=0 and clear. Doors that the scripts open and shut (the Elite
-- Four exits, Lance's gate) follow the live tiles. Animated light, fire,
-- snow and fireworks are LeagueRoomFx; the soundscape is LeagueAmbience.
--
-- This module is the shared frame: the layouts, the build context (lit
-- emitter, walls from the grid, floors, light), the meshes and the draw.
-- The rooms themselves are LeagueRoomsE4 and LeagueRoomsHall.
local V=...
local M={REVISION='league-rooms-202'}
local RM=V.require('ReferenceMaterials')
local pi,cos,sin,floor,min,max,abs,sqrt=math.pi,math.cos,math.sin,math.floor,math.min,math.max,math.abs,math.sqrt
local function rh(a,b,s)local v=sin(a*12.9898+b*78.233+s*37.719)*43758.5453;return v-floor(v)end
local CS=16

------------------------------------------------------------------ layouts
-- One character per 16-unit cell, from the ROM blocks (pokered .blk + .bst
-- and the tilesets' collision lists). '.' is walkable floor. The other
-- letters name what stands on a blocked cell (each room reads its own):
--   W wall   D a door the scripts open and shut   E an open exit
--   X solid mass   V void
--   L frozen lake   S statue   F brazier   B boulder   G grave   T tomb
--   K fireplace wall   M mart counter   C Pokemon Center   P planter
--   R trophy cabinet   H the Hall of Fame machine   U unreachable shrine
local LAYOUT={
 INDIGO_PLATEAU_LOBBY={w=8,h=6,set='LeagueRoomsHall',room='lobby',rows={
  "KKKKWWWWEWXXXXXX",
  "KKKK......XXXXXX",
  "..........XXXXXX",
  "MM..XXXXXXXXXXXX",
  "MM..CCCCCCCC.C.C",
  ".M..CCC..CCC....",
  "MM..CCCCCCCCC.CC",
  "...............P",
  "RRRR............",
  "RRRR............",
  "............PPPP",
  "............PPPP"},
  -- TEST179: gen1recomp's union room puts a staircase up (and a PC) where
  -- the Cable Club desk stood; the live map says which (lobbyUnion)
  union={rows={
  "KKKKWWWWEWXXXXXX",
  "KKKK......XXXXXX",
  "..........XXXXXX",
  "MM..XXXXXXXXXXXX",
  "MM..CCCCCCCCXXXX",
  ".M..CCC..CCCX..^",
  "MM..CCCCCCCCC...",
  "...............Q",
  "RRRR............",
  "RRRR............",
  "............PPPP",
  "............PPPP"}}},
 LORELEIS_ROOM={w=5,h=6,set='LeagueRoomsE4',room='lorelei',door={tx=8,ty=0,open=17},rows={
  "WWWWDDWWWW",
  "LLLL..LLLL",
  "LL......LL",
  "LL......LL",
  "LL......LL",
  "LL......LL",
  "LLLL..LLLL",
  "LLLL..LLLL",
  "LLLS..LLLL",
  "LLLS..LLLL",
  "LLFF..FFLL",
  "LLFF..FFLL"}},
 BRUNOS_ROOM={w=5,h=6,set='LeagueRoomsE4',room='bruno',door={tx=8,ty=0,open=17},rows={
  "WWWWDDWWWW",
  "..........",
  "BB......BB",
  "B.........",
  "B........B",
  "BBB....BBB",
  "B.BB....B.",
  "BB....BBBB",
  "BB....B.BB",
  "B.BS..BBB.",
  ".B.S..BB.B",
  "RR......RR"}},
 AGATHAS_ROOM={w=5,h=6,set='LeagueRoomsE4',room='agatha',door={tx=8,ty=0,open=1},rows={
  "WWWWDDWWWW",
  "..........",
  "G......G.G",
  "GG......G.",
  "GG.G...GGG",
  "GG....G.GG",
  ".GG....G.G",
  "G.GG..G.G.",
  "GG.T...GGG",
  "GG.T..G.GG",
  "G.GG...G.G",
  "GGGG..GGGG"}},
 LANCES_ROOM={w=13,h=13,set='LeagueRoomsE4',room='lance',door={tx=10,ty=24,open=17},rows={
  "WWWWSEESWWWVVVVVVWWUSUUSUW",
  "W...S..S...WVVVVVVWUSUUSUW",
  "W..S....S..WVVVVVVWUUUUUUW",
  "W..S....S..WVVVVVVWUUUUUUW",
  "W..S....S..WVVVVVVWUUUUUUW",
  "W..S....S..WVVVVVVWUUUUUUW",
  "W..S....S..WVVVVVVWUSUUSUW",
  "W..S....S..WVVVVVVWWSUUSWW",
  "W..S....S..WVVVVVVVVVVVVVV",
  "W..S....S..WVVVVVVVVVVVVVV",
  "W..S....S..WVVVVVVVVVVVVVV",
  "W..S....S..WVVVVVVVVVVVVVV",
  "W...SDDS...WVVVVVVVVVVVVVV",
  "WWWWS..SWWWWVVVVVVVVVVVVVV",
  "VVW......WVVVVVVWWWWWWWWWW",
  "VVW......WVVVVVVW........W",
  "VVW......WVVVVVVW........W",
  "VVW......WVVVVVVW........W",
  "VVW......WVVVVVVW........W",
  "VVW......WVVVVVVW..WWWWWWW",
  "VVW......WVVVVVVW..WVVVVVV",
  "VVW......WVVVVVVW..WVVVVVV",
  "VVW......WWWWWWWW..WVVVVVV",
  "VVW................WVVVVVV",
  "VVW................WVVVVVV",
  "VVWWWWWWWWWWWWWWWWWWVVVVVV"}},
 CHAMPIONS_ROOM={w=4,h=4,set='LeagueRoomsHall',room='champion',rows={
  "WWS..SWW",
  "W.S..S.W",
  "W......W",
  "W......W",
  "W......W",
  "W......W",
  "W.S..S.W",
  "WWS..SWW"}},
 -- TEST201: the union room's upstairs (gen1recomp's shared POKECENTER_2F),
 -- dressed as the League's when you came up from the Plateau's lobby. From
 -- any town's Center it stays the town's own (see upstairsLeague below).
 POKECENTER_2F={w=7,h=4,set='LeagueRoomsHall',room='upstairs',when='upstairs',rows={
  "WWWWWWEWWWEWWW",
  "............W^",
  "CCCCCCCCCCCCC.",
  "..............",
  "..............",
  "..............",
  "PP..........PP",
  "PP..........PP"}},
 HALL_OF_FAME={w=5,h=4,set='LeagueRoomsHall',room='fame',rows={
  "WWWWWWWWWW",
  "....HH....",
  "..........",
  "..........",
  "..........",
  "..........",
  "..........",
  ".........."}},
}
M.LAYOUT=LAYOUT

local function styleOn()
 local ok,on=pcall(function()return V.require('LeagueArchitecture').leagueStyle()end)
 return (ok and on)and true or false
end
-- TEST201: which Center the shared upstairs belongs to. The engine has ONE
-- POKECENTER_2F for every Center, so the answer is where you came up from:
-- the Plateau's lobby makes it the League's. Remembered across the union
-- room next door; anything else (a town, a load straight onto the floor)
-- makes it a town's. When the answer changes, that floor's meshes are
-- dropped so it is rebuilt in the right dress (the disk records already
-- differ: VoxelMeshDisk adds this module's REVISION only when it claims).
-- TEST202: the exact map you came up from is kept too (upstairsOrigin), so
-- a town's Center dresses the floor as its own (InteriorRooms), and the
-- watch runs on EVERY accepts call: the engine asks about the map you are
-- on each frame, so the Center downstairs is seen before you climb.
local upstairsFrom,upstairsAt=nil,nil
local cached,release -- (defined with the runtime below)
local PASS={POKECENTER_2F=true,UNION_ROOM=true}
local GameMod=nil
local function currentMapId()
 local ok,id=pcall(function()
  GameMod=GameMod or require('src.core.Game')
  local ow=GameMod and GameMod.overworld
  return ow and ow.map and ow.map.id
 end)
 return ok and id or nil
end
local function upstairsLeague()
 local here=currentMapId()
 local was=upstairsFrom
 if here=='INDIGO_PLATEAU_LOBBY'then upstairsFrom='league';upstairsAt=here
 elseif here and not PASS[here]then upstairsFrom='town';upstairsAt=here end
 if was~=nil and was~=upstairsFrom then
  pcall(function()V.require('ChunkMesher').evictRuntime('POKECENTER_2F')end)
  local r=cached and cached.POKECENTER_2F
  if r then pcall(release,r);cached.POKECENTER_2F=nil end
 end
 return upstairsFrom=='league'
end
M.upstairsLeague=upstairsLeague
-- the map the shared upstairs was climbed to from (nil before any), and
-- whether that makes it the League's
function M.upstairsOrigin()
 local league=upstairsLeague()
 return upstairsAt,league
end
function M.accepts(map)
 if map and map.id~='POKECENTER_2F'then upstairsLeague()end
 local L=map and LAYOUT[map.id]
 if not(L and map.def and map.def.width==L.w and map.def.height==L.h)then return false end
 if L.when=='upstairs' and not upstairsLeague()then return false end
 return styleOn()
end
function M.owns(map)return M.accepts(map)end

------------------------------------------------------------------ helpers
local function kit()return V.require('LeagueArchitecture').kit end
local lib={rh=rh,CS=CS}
M.lib=lib
-- discs and stars in a vertical (x/y) plane at depth z
function lib.fan(L,cx,cy,z,r,n,mat,t,rot,ry,a0,a1)
 rot=rot or 0;ry=ry or r;a0=a0 or 0;a1=a1 or pi*2
 for i=0,n-1 do
  local b0,b1=rot+a0+(a1-a0)*i/n,rot+a0+(a1-a0)*(i+1)/n
  L.quad({cx,cy,z},{cx+cos(b0)*r,cy+sin(b0)*ry,z},{cx+cos(b1)*r,cy+sin(b1)*ry,z},{cx,cy,z},mat,t)
 end
end
function lib.ringXY(L,cx,cy,z,r0,r1,n,mat,t,a0,a1)
 a0,a1=a0 or 0,a1 or pi*2
 for i=0,n-1 do
  local b0,b1=a0+(a1-a0)*i/n,a0+(a1-a0)*(i+1)/n
  L.quad({cx+cos(b0)*r1,cy+sin(b0)*r1,z},{cx+cos(b0)*r0,cy+sin(b0)*r0,z},{cx+cos(b1)*r0,cy+sin(b1)*r0,z},{cx+cos(b1)*r1,cy+sin(b1)*r1,z},mat,t)
 end
end
function lib.starXY(L,cx,cy,z,r1,r2,n,mat,t,rot)
 rot=rot or pi/2
 for i=0,n*2-1 do
  local a0,a1=rot+i/(n*2)*pi*2,rot+(i+1)/(n*2)*pi*2
  local ra,rb=i%2==0 and r1 or r2,i%2==0 and r2 or r1
  L.quad({cx,cy,z},{cx+cos(a0)*ra,cy+sin(a0)*ra,z},{cx+cos(a1)*rb,cy+sin(a1)*rb,z},{cx,cy,z},mat,t)
 end
end
-- discs and stars lying flat (facing up) at height y
function lib.ringH(E,cx,cz,y,r0,r1,n,mat,t,a0,a1)
 a0,a1=a0 or 0,a1 or pi*2
 for i=0,n-1 do
  local b0,b1=a0+(a1-a0)*i/n,a0+(a1-a0)*(i+1)/n
  E.quad({cx+cos(b0)*r0,y,cz+sin(b0)*r0},{cx+cos(b0)*r1,y,cz+sin(b0)*r1},{cx+cos(b1)*r1,y,cz+sin(b1)*r1},{cx+cos(b1)*r0,y,cz+sin(b1)*r0},mat,t)
 end
end
function lib.fanH(E,cx,cz,y,r,n,mat,t,a0,a1)
 a0,a1=a0 or 0,a1 or pi*2
 for i=0,n-1 do
  local b0,b1=a0+(a1-a0)*i/n,a0+(a1-a0)*(i+1)/n
  E.quad({cx,y,cz},{cx+cos(b0)*r,y,cz+sin(b0)*r},{cx+cos(b1)*r,y,cz+sin(b1)*r},{cx,y,cz},mat,t)
 end
end
function lib.starH(E,cx,cz,y,r1,r2,n,matA,matB,t,rot)
 rot=rot or -pi/2
 for i=0,n-1 do
  local a=rot+i/n*pi*2;local w=pi/n
  local tip={cx+cos(a)*r1,y,cz+sin(a)*r1}
  local l={cx+cos(a-w)*r2,y,cz+sin(a-w)*r2}
  local r={cx+cos(a+w)*r2,y,cz+sin(a+w)*r2}
  local o={cx,y,cz}
  E.quad(o,l,tip,tip,matA,t)
  E.quad(o,tip,r,r,matB or matA,t)
 end
end
-- a flat strip on the floor between two points (width w)
function lib.stripH(E,x0,z0,x1,z1,y,w,mat,t)
 local dx,dz=x1-x0,z1-z0;local l=sqrt(dx*dx+dz*dz);if l<1e-4 then return end
 local px,pz=-dz/l*w*.5,dx/l*w*.5
 E.quad({x0-px,y,z0-pz},{x0+px,y,z0+pz},{x1+px,y,z1+pz},{x1-px,y,z1-pz},mat,t)
end
-- a six-armed snowflake inlaid in a floor (Lorelei's emblem)
function lib.snowflake(E,cx,cz,y,R,mat,mat2,rot)
 rot=rot or 0
 for k=0,5 do
  local a=rot+k*pi/3
  local ca,sa=cos(a),sin(a)
  local function P(u,v)return{cx+ca*u-sa*v,y,cz+sa*u+ca*v}end
  local w=R*.055
  E.quad(P(0,-w),P(R,-w*.4),P(R,w*.4),P(0,w),mat,1.05)
  for _,b in ipairs({{.38,.30},{.66,.22}})do
   local u0,bl=R*b[1],R*b[2]
   for _,sg in ipairs({-1,1})do
    local bx,bz=u0+bl*.62,sg*bl*.78
    local function Q(u,v)return P(u,v)end
    E.quad(Q(u0,sg*w*.3),Q(u0+w*.9,sg*w*.3),Q(bx+w*.3,bz),Q(bx-w*.3,bz),mat,1.02)
   end
  end
  E.quad(P(R,0),P(R*.93,-w*1.4),P(R*1.1,0),P(R*.93,w*1.4),mat2 or mat,1.1)
 end
 lib.fanH(E,cx,cz,y+.01,R*.13,6,mat2 or mat,1.08,rot)
end
-- a faceted crystal spire from (x,y,z): n sides, radius r, height h,
-- leaning (lx,lz) per unit of height; returns the tip
function lib.crystal(L,x,y,z,r,h,n,lx,lz,mat,rot)
 n=n or 6;lx,lz=lx or 0,lz or 0;rot=rot or 0;mat=mat or 'lgCrystal'
 local hb=h*.80
 local base,top={},{}
 for i=0,n-1 do
  local a=rot+i/n*pi*2
  base[i]={x+cos(a)*r,y,z+sin(a)*r}
  top[i]={x+cos(a)*r*.86+lx*hb,y+hb,z+sin(a)*r*.86+lz*hb}
 end
 local tip={x+lx*h,y+h,z+lz*h}
 for i=0,n-1 do local j=(i+1)%n
  L.quad(base[i],base[j],top[j],top[i],mat,1)
  L.quad(top[i],top[j],tip,tip,mat,1.08)
 end
 return tip
end
-- a hanging icicle (or stalactite) from (x,y,z) down by len
function lib.icicle(L,x,y,z,r,len,mat,n)
 n=n or 5;mat=mat or 'lgIce'
 for i=0,n-1 do
  local a0,a1=i/n*pi*2,(i+1)/n*pi*2
  L.quad({x+cos(a1)*r,y,z+sin(a1)*r},{x+cos(a0)*r,y,z+sin(a0)*r},{x,y-len,z},{x,y-len,z},mat,.95)
 end
end

------------------------------------------------------------------ context
-- The build context handed to a room: grid queries, named parts (each one
-- mesh, with a visibility rule), a light field baked into vertex shades,
-- walls generated from the grid, floors with contact shading at the walls.
local Budget
-- the background prebuild (see M.step) runs as our own coroutine with its
-- own small slice per frame; inside the scene build, BuildBudget paces us
local job,jobDeadline,jobCount=nil,0,0
local clock=(love and love.timer and love.timer.getTime)or os.clock
local function tick()
 if job and coroutine.running()==job.co then
  jobCount=jobCount+1
  if jobCount%16==0 and clock()>jobDeadline then coroutine.yield()end
  return
 end
 if Budget then Budget.tick()end
end

-- TEST179: is the lobby the engine's union-room variant? Its map def then
-- carries a warp to POKECENTER_2F. Read from the game's data, so a room
-- prebuilt before the map is loaded gets it right too.
local function lobbyUnion()
 local ok,res=pcall(function()
  local Game=require('src.core.Game')
  local def=Game.data and Game.data.maps and Game.data.maps.INDIGO_PLATEAU_LOBBY
  if not def then return nil end
  for _,w in ipairs(def.warps or{})do if w.destMap=='POKECENTER_2F' then return true end end
  return false
 end)
 -- Map definitions may be augmented after the first prebuild. Recheck the
 -- small warp list rather than caching a premature ROM-only verdict.
 return ok and res or false
end
M.lobbyUnion=lobbyUnion
local variants={}
local function layoutOf(id)
 local Lt=LAYOUT[id]
 if Lt and Lt.union and id=='INDIGO_PLATEAU_LOBBY' and lobbyUnion()then
  local u=variants[id]
  if not u then
   u={};for k,v in pairs(Lt)do u[k]=v end
   for k,v in pairs(Lt.union)do u[k]=v end
   u.variant='union';u.union=nil;variants[id]=u
  end
  return u
 end
 return Lt
end
M.layoutOf=layoutOf
local function newContext(id,Lt)
 Lt=Lt or layoutOf(id)
 local K=kit()
 local C={id=id,layout=Lt,cw=Lt.w*2,ch=Lt.h*2,W=Lt.w*32,D=Lt.h*32,K=K,lib=lib,
  parts={},fx={fires={},candles={},pools={},glows={},badges={},glow=.55},lights={},ambient=.86,maxLight=1.5,variant=Lt.variant}
 function C.at(cx,cy)
  if cx<0 or cy<0 or cx>=C.cw or cy>=C.ch then return nil end
  local r=Lt.rows[cy+1];return r:sub(cx+1,cx+1)
 end
 function C.is(cx,cy,set)local c=C.at(cx,cy);return c~=nil and set:find(c,1,true)~=nil end
 function C.walk(cx,cy)return C.at(cx,cy)=='.'end
 function C.cells(set)
  local out={}
  for cy=0,C.ch-1 do for cx=0,C.cw-1 do if set:find(C.at(cx,cy),1,true)then out[#out+1]={cx,cy}end end end
  return out
 end
 ---------------------------------------------------------------- light
 -- lights: {x,y,z,r,k}; light(p) = ambient + falloff, capped
 function C.addLight(x,y,z,r,k)C.lights[#C.lights+1]={x,y,z,r,k,r*r}end
 function C.light(p)
  local x,y,z=p[1],p[2],p[3]
  local v=C.ambient
  if C.lightY then v=v*C.lightY(y)end
  local Ls=C.lights
  for i=1,#Ls do
   local l=Ls[i]
   local dx,dy,dz=x-l[1],y-l[2],z-l[3]
   local d2=dx*dx+dy*dy+dz*dz
   if d2<l[6]then local f=1-sqrt(d2)/l[4];v=v+l[5]*f*f end
  end
  return v<C.maxLight and v or C.maxLight
 end
 ---------------------------------------------------------------- parts
 -- vis: nil (always) | {axis='x'|'z',c=..,s=1|-1} camera on the front |
 --      {below=y} camera under y | {door=true} the scripted door is shut |
 --      {open=true} it is open
 local function litWrap(E)
  local Wr={out=E.out}
  Wr.decor=E.decor
  function Wr.quad(a,b,c,d,mat,s,glow)
   tick()
   -- a glowing bed of coals (LeagueArchitecture's fire bowl) lights only
   -- after dark outdoors; indoors it is embers, self-lit
   if glow and mat=='lgRock'then mat,glow='lgLava',nil;s=.75 end
   if C.flat then return E.quad(a,b,c,d,mat,s,glow)end
   local s1,s2,s3,s4
   if type(s)=='table'then s1,s2,s3,s4=s[1],s[2],s[3],s[4]else s=s or 1;s1,s2,s3,s4=s,s,s,s end
   local Lf=C.light
   E.quad(a,b,c,d,mat,{s1*Lf(a),s2*Lf(b),s3*Lf(c),s4*Lf(d)})
  end
  local function vs(t,y)return t*(.80+.20*min(1,max(0,y)/9))end
  Wr.vs=vs
  function Wr.box(x0,y0,z0,x1,y1,z1,mat,t,skip)
   if x1-x0<.001 or y1-y0<.001 or z1-z0<.001 then return end
   t=t or 1;skip=skip or {}
   if not skip.top then Wr.quad({x0,y1,z0},{x1,y1,z0},{x1,y1,z1},{x0,y1,z1},mat,t)end
   if not skip.bottom then Wr.quad({x0,y0,z1},{x1,y0,z1},{x1,y0,z0},{x0,y0,z0},mat,t*.6)end
   if not skip.s then Wr.quad({x0,y0,z1},{x1,y0,z1},{x1,y1,z1},{x0,y1,z1},mat,{vs(t*.92,y0),vs(t*.92,y0),vs(t*.92,y1),vs(t*.92,y1)})end
   if not skip.n then Wr.quad({x1,y0,z0},{x0,y0,z0},{x0,y1,z0},{x1,y1,z0},mat,{vs(t*.72,y0),vs(t*.72,y0),vs(t*.72,y1),vs(t*.72,y1)})end
   if not skip.w then Wr.quad({x0,y0,z0},{x0,y0,z1},{x0,y1,z1},{x0,y1,z0},mat,{vs(t*.80,y0),vs(t*.80,y0),vs(t*.80,y1),vs(t*.80,y1)})end
   if not skip.e then Wr.quad({x1,y0,z1},{x1,y0,z0},{x1,y1,z0},{x1,y1,z1},mat,{vs(t*.86,y0),vs(t*.86,y0),vs(t*.86,y1),vs(t*.86,y1)})end
  end
  return Wr
 end
 local byName={}
 function C.part(name,vis,shadow)
  local p=byName[name]
  if not p then
   local q={}
   p={name=name,quads=q,vis=vis,shadow=shadow}
   p.E=litWrap(K.newEmitter(q,{.5,.5}))
   byName[name]=p;C.parts[#C.parts+1]=p
  end
  return p.E
 end
 -- a model frame (K.model) on a part's emitter
 function C.model(E,ox,oy,oz,yaw,scale,tone)return K.model(E,ox,oy,oz,yaw,scale,tone)end
 ---------------------------------------------------------------- walls
 -- Runs of wall faces between solid cells and open space, merged per plane.
 -- solid(cx,cy) says which cells are wall; cells outside the map are solid
 -- when outside=true. Each run is handed to style(L,len,run) in a local
 -- frame: x along the wall, y up, +z out of the wall into the room.
 -- run = {o='S'|'N'|'E'|'W', c=plane, a0,a1 world span, cells, len,
 --        toWorld(x,y,z), holes={{x0,x1,h}} where door cells cut it}
 function C.walls(solid,style,opts)
  opts=opts or {}
  local function S(cx,cy)
   if cx<0 or cy<0 or cx>=C.cw or cy>=C.ch then return opts.outside and true or false end
   return solid(cx,cy)
  end
  local runs={}
  local function emit(o,c,list)
   -- list: sorted cell indices along the run axis
   local i=1
   while i<=#list do
    local j=i
    while j<#list and list[j+1]==list[j]+1 do j=j+1 end
    runs[#runs+1]={o=o,c=c,a0=list[i]*CS,a1=(list[j]+1)*CS,from=list[i],to=list[j]}
    i=j+1
   end
  end
  local x0,x1,y0,y1=-1,C.cw,-1,C.ch
  -- S faces (wall north of open), N faces (wall south of open)
  for cy=y0,y1 do
   local sl,nl={},{}
   for cx=0,C.cw-1 do
    if S(cx,cy)and not S(cx,cy+1)and cy+1<=C.ch-1 and cy+1>=0 then sl[#sl+1]=cx end
    if S(cx,cy)and not S(cx,cy-1)and cy-1>=0 and cy-1<=C.ch-1 then nl[#nl+1]=cx end
   end
   emit('S',(cy+1)*CS,sl);emit('N',cy*CS,nl)
  end
  for cx=x0,x1 do
   local el,wl={},{}
   for cy=0,C.ch-1 do
    if S(cx,cy)and not S(cx+1,cy)and cx+1<=C.cw-1 and cx+1>=0 then el[#el+1]=cy end
    if S(cx,cy)and not S(cx-1,cy)and cx-1>=0 and cx-1<=C.cw-1 then wl[#wl+1]=cy end
   end
   emit('E',(cx+1)*CS,el);emit('W',cx*CS,wl)
  end
  for _,run in ipairs(runs)do
   local len=run.a1-run.a0;run.len=len
   local ox,oz,yaw,vis
   if run.o=='S'then ox,oz,yaw=run.a0,run.c,0;vis={axis='z',c=run.c,s=1}
    run.toWorld=function(x,y,z)return run.a0+x,y,run.c+z end
   elseif run.o=='N'then ox,oz,yaw=run.a1,run.c,pi;vis={axis='z',c=run.c,s=-1}
    run.toWorld=function(x,y,z)return run.a1-x,y,run.c-z end
   elseif run.o=='E'then ox,oz,yaw=run.c,run.a1,pi/2;vis={axis='x',c=run.c,s=1}
    run.toWorld=function(x,y,z)return run.c+z,y,run.a1-x end
   else ox,oz,yaw=run.c,run.a0,-pi/2;vis={axis='x',c=run.c,s=-1}
    run.toWorld=function(x,y,z)return run.c-z,y,run.a0+x end
   end
   -- door cells along this run cut holes (local x ranges)
   run.holes={}
   if opts.door then
    for k=run.from,run.to do
     local cx,cy,ox,oy
     if run.o=='S'then cx,cy,ox,oy=k,run.c/CS-1,k,run.c/CS elseif run.o=='N'then cx,cy,ox,oy=k,run.c/CS,k,run.c/CS-1
     elseif run.o=='E'then cx,cy,ox,oy=run.c/CS-1,k,run.c/CS,k else cx,cy,ox,oy=run.c/CS,k,run.c/CS-1,k end
     -- (TEST173: the open cell in front is passed too)
     if opts.door(cx,cy,ox,oy)then
      local wa,wb=k*CS,(k+1)*CS
      local la,lb
      if run.o=='S'or run.o=='W'then la,lb=wa-run.a0,wb-run.a0 else la,lb=run.a1-wb,run.a1-wa end
      local last=run.holes[#run.holes]
      if last and abs(last[2]-la)<.01 then last[2]=lb elseif last and abs(last[1]-lb)<.01 then last[1]=la
      else run.holes[#run.holes+1]={la,lb}end
     end
    end
   end
   local pname=(opts.prefix or'wall')..':'..run.o..':'..run.c
   -- (TEST174) a caller may give a run its own rule (a side face of a
   -- wall that hides with the south wall it belongs to)
   if opts.visFor then
    local v2=opts.visFor(run)
    if v2 then vis=v2;pname=pname..':'..(v2.tag or'v')end
   end
   local E=C.part(pname,opts.always and nil or vis,opts.shadow)
   run.E=E
   local L=K.model(E,ox,0,oz,yaw,1)
   style(L,len,run)
  end
  return runs
 end
 ---------------------------------------------------------------- floors
 -- Contact shading: floor vertices darken toward solid cells.
 function C.aoField(solid,reach)
  reach=reach or 14
  local cache={}
  return function(x,z)
   local k=floor(x*4+.5)*100003+floor(z*4+.5)
   local v=cache[k];if v then return v end
   local cx,cz=floor(x/CS),floor(z/CS)
   local best=reach
   for dy=-2,2 do for dx=-2,2 do
    local ax,ay=cx+dx,cz+dy
    if solid(ax,ay)then
     local rx0,rz0=ax*CS,ay*CS
     local qx=max(rx0-x,0,x-(rx0+CS));local qz=max(rz0-z,0,z-(rz0+CS))
     local d=sqrt(qx*qx+qz*qz)
     if d<best then best=d end
    end
   end end
   local t=best/reach;t=t*t*(3-2*t)
   v=.70+.30*t;cache[k]=v;return v
  end
 end
 -- a floor quad subdivided to `step` so the light and contact shade read
 function C.floorRect(E,x0,z0,x1,z1,y,mat,t,ao,step)
  step=step or 8;t=t or 1
  local nx=max(1,floor((x1-x0)/step+.5));local nz=max(1,floor((z1-z0)/step+.5))
  for j=0,nz-1 do for i=0,nx-1 do
   local a0,a1=x0+(x1-x0)*i/nx,x0+(x1-x0)*(i+1)/nx
   local b0,b1=z0+(z1-z0)*j/nz,z0+(z1-z0)*(j+1)/nz
   local s1,s2,s3,s4=t,t,t,t
   if ao then s1,s2,s3,s4=t*ao(a0,b1),t*ao(a1,b1),t*ao(a1,b0),t*ao(a0,b0)end
   E.quad({a0,y,b1},{a1,y,b1},{a1,y,b0},{a0,y,b0},mat,{s1,s2,s3,s4})
  end end
 end
 -- a sky dome: the night painted at infinity (lgNight), style 1/2/3
 function C.sky(cx,cz,R,style,y0)
  local E=C.part('sky')
  local saveFlat=C.flat;C.flat=true
  local n,rings=24,6
  y0=y0 or -40
  local function P(i,j)
   local a=i/n*pi*2;local e=j/rings*pi/2
   return{cx+cos(a)*cos(e)*R,y0+sin(e)*R*.62,cz+sin(a)*cos(e)*R}
  end
  for j=0,rings-1 do for i=0,n-1 do
   E.quad(P(i+1,j),P(i,j),P(i,j+1),P(i+1,j+1),'lgNight',style or 1)
  end end
  -- a skirt down to the abyss so no edge shows
  for i=0,n-1 do
   local a0,a1=i/n*pi*2,(i+1)/n*pi*2
   E.quad({cx+cos(a1)*R,y0-600,cz+sin(a1)*R},{cx+cos(a0)*R,y0-600,cz+sin(a0)*R},P(i,0),P(i+1,0),'lgNight',style or 1)
  end
  C.flat=saveFlat
 end
 return C
end
M.newContext=newContext
-- TEST173: the same context for any layout record ({w,h,rows}): the town
-- interiors (InteriorRooms) build with it
function M.newContextFor(Lt,id)return newContext(id,Lt)end
-- the scene build's pacer, for a context built outside M.build
function M.useBudget(B)Budget=B end

------------------------------------------------------------------ geometry
-- Every part as quads, and the effect points. Pure: no LOVE needed.
function M.geometry(id)
 local Lt=LAYOUT[id];if not Lt then return nil end
 local C=newContext(id)
 local set=V.require(Lt.set)
 local fn=set[Lt.room];assert(fn,'no room '..tostring(Lt.room))
 fn(C)
 return C
end

------------------------------------------------------------------ runtime
-- Room meshes are kept for the room you are in and the one after it in the
-- League's order (prebuilt in the background a slice a frame, so walking
-- through a door never waits for a build).
local NEXT={INDIGO_PLATEAU='INDIGO_PLATEAU_LOBBY',INDIGO_PLATEAU_LOBBY='LORELEIS_ROOM',LORELEIS_ROOM='BRUNOS_ROOM',
 BRUNOS_ROOM='AGATHAS_ROOM',AGATHAS_ROOM='LANCES_ROOM',LANCES_ROOM='CHAMPIONS_ROOM',CHAMPIONS_ROOM='HALL_OF_FAME'}
M.NEXT=NEXT
cached={}   -- id -> {parts, fx, ...} or false after a failure
local current=nil -- the room id last drawn
local white
local function texture()
 if not white then
  local d=love.image.newImageData(2,2);for y=0,1 do for x=0,1 do d:setPixel(x,y,1,1,1,1)end end
  white=love.graphics.newImage(d);white:setFilter('nearest','nearest');d:release()
 end
 return white
end
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
local logged={}
local function log(fmt,...)
 if V.mod and V.mod.log and V.mod.log.info then pcall(V.mod.log.info,V.mod.log,fmt,...)end
end
release=function(r)
 if r then for _,p in ipairs(r.parts)do pcall(p.mesh.release,p.mesh)end end
end
-- geometry -> meshes; the quads are dropped part by part as they upload
local function cancelPrebuild()
 local pending=job;job=nil
 if pending then
  release(pending);pending.parts={};pending.co=nil
 end
end
local function upload(id,C,owner)
 local R=V.require('Voxel3D')
 -- The caller owns each mesh before the next yield, so cancellation and
 -- allocation failure can release incomplete uploads deterministically.
 local parts=owner.parts;local count=0
 for _,p in ipairs(C.parts)do
  if #p.quads>0 then
   local vs,ix=toMesh(p.quads)
   p.quads={}
   local mesh,err=R.newMesh(vs,ix)
   if not mesh then error('League mesh upload '..tostring(p.name)..': '..tostring(err or'no mesh returned'),0)end
   parts[#parts+1]={name=p.name,mesh=mesh,vis=p.vis,shadow=p.shadow};count=count+#vs
   if job and coroutine.running()==job.co then coroutine.yield()end
  end
 end
 if #parts==0 then error('League room contains no meshes',0)end
 return {parts=parts,fx=C.fx,vertices=count,H=C.H or 90,door=C.layout.door,W=C.W,D=C.D}
end
local function buildNow(id)
 local owner={parts={}}
 local ok,res=pcall(function()return upload(id,M.geometry(id),owner)end)
 if ok and res then cached[id]=res;return res end
 release(owner)
 cached[id]=false
 if not logged[id]then logged[id]=true;log('League room %s failed: %s',tostring(id),tostring(res))end
 return nil
end
local function prepare(map)
 if not M.accepts(map)then return nil end
 local id=map.id
 local r=cached[id]
 if r then return r end
 if r==false then return nil end
 -- a background build of this very room: finish it now
 if job and job.id==id then
  jobDeadline=math.huge
  while job and coroutine.status(job.co)~='dead'do
   local ok,err=coroutine.resume(job.co)
   if not ok then cached[id]=false;cancelPrebuild();log('League room %s failed: %s',tostring(id),tostring(err));return nil end
  end
  job=nil
  r=cached[id];if r then return r end
 end
 return buildNow(id)
end
M.prepare=prepare
-- One slice (a few ms) of building the room after `id` in the League's
-- order. Called every frame from the room effects and the Plateau.
function M.step(id)
 -- TEST194: this room's battle stadium first (the fight comes before the
 -- next room), a slice a frame; then the next room in line
 do
  local okS,St=pcall(V.require,'LeagueStadium')
  if okS and St and styleOn()then
   local okB,busy=pcall(St.step,tostring(id or''))
   if okB and busy then return end
  end
 end
 local nid=NEXT[tostring(id or'')]
 if not nid or cached[nid]~=nil then return end
 if not styleOn()then return end
 if not job or job.id~=nid then
  cancelPrebuild()
  local pending={id=nid,parts={}}
  pending.co=coroutine.create(function()
   local r=upload(nid,M.geometry(nid),pending)
   cached[nid]=r
   pending.parts={} -- publication transfers ownership to cached[nid]
  end)
  job=pending
 end
 jobDeadline=clock()+.004;jobCount=0
 local ok,err=coroutine.resume(job.co)
 if not ok then
  cached[nid]=false;cancelPrebuild()
  if not logged[nid]then logged[nid]=true;log('League room %s failed: %s',tostring(nid),tostring(err))end
 elseif coroutine.status(job.co)=='dead'then job=nil end
end
-- whether a room's meshes are ready (true), failed (false) or not built (nil)
function M.ready(id)local r=cached[id];if r==nil then return nil end;return r and true or false end
function M.build(S,map)
 if not M.accepts(map)then return end
 Budget=V.require('BuildBudget')
 -- Claim native cells only after a complete room exists, including when
 -- finishing a prebuild. A failed upload must leave native fallback intact.
 if not prepare(map)then return end
 -- TEST173: the lobby's Mart counter draws a till the engine would lift
 -- into a standee on the (claimed) floor; keep it out
 pcall(function()V.require('InteriorRooms').neutralize(S,map)end)
 -- the map and the engine's three-block border ring round it: the rooms
 -- open onto skies, lakes and abysses of their own
 for ty=-12,map.def.height*4+11 do for tx=-12,map.def.width*4+11 do
  local k=(ty+64)*4096+tx+64
  S.skip[k]=true;S.ground[k]=nil
  S.shapeAt[k]={class='ground',h=0,flat=true,art='flat',authored=true}
 end end
 S.leagueRoom=map.id
end
-- whether the scripted door (an Elite Four exit, Lance's gate) is shut
function M.doorShut(map)
 local L=map and LAYOUT[map.id];local d=L and L.door
 if not(d and map.tileAt)then return false end
 local ok,t=pcall(map.tileAt,map,d.tx,d.ty)
 return ok and t~=nil and t~=d.open
end
-- where the player stands (LeagueRoomFx reports it each frame)
M.player=nil
local function visible(vis,eye,shut,player)
 if not vis then return true end
 if vis.behind then return shut and player~=nil and player[2]<vis.behind end
 if vis.axis then
  local e=vis.axis=='x'and eye[1]or eye[3]
  return (e-vis.c)*vis.s>-.5
 end
 if vis.below then return eye[2]<vis.below end
 if vis.above then return eye[2]>vis.above end
 if vis.door then return shut end
 if vis.open then return not shut end
 return true
end
M.visible=visible
function M.fx(map,eye)
 local r=prepare(map);if not r then return nil end
 return r.fx,r
end
function M.draw(map,shadow)
 -- TEST194: a battle staged here is fought in the room's stadium
 local okS,St=pcall(V.require,'LeagueStadium')
 if okS and St and St.drawing(map)then
  local okD,drawn=pcall(St.draw,map,shadow)
  if okD and drawn then return end
 end
 local r=prepare(map);if not r then return end
 current=map.id
 local tex=texture()
 if shadow then
  for _,p in ipairs(r.parts)do if p.shadow then pcall(shadow.draw,p.mesh,tex)end end
  return
 end
 local R=V.require('Voxel3D')
 local shut=M.doorShut(map)
 R.glass(false)
 local ok,err=pcall(function()
  if R.seams then R.seams(false)end
  local eye=R.eye or {r.W/2,30,r.D}
  local player=M.player
  for _,p in ipairs(r.parts)do
   if visible(p.vis,eye,shut,player)then R.draw(p.mesh,tex)end
  end
 end)
 if R.seams then R.seams(true)end
 R.glass(true)
 if not ok then
  -- never take the whole 3D view down with a room: drop the room instead
  release(r);cached[map.id]=false
  if not logged[map.id]then logged[map.id]=true;log('League room %s draw failed: %s',tostring(map.id),tostring(err))end
 end
end
function M.invalidate()
 pcall(function()V.require('LeagueStadium').invalidate()end)
 cancelPrebuild()
 for _,r in pairs(cached)do release(r)end
 cached={};current=nil
end
-- keep the live rooms and the next one in line; free the rest
function M.setLive(live)
 local keep={}
 for id in pairs(live or{})do keep[id]=true;if NEXT[id]then keep[NEXT[id]]=true end end
 if current and not keep[current]then current=nil end
 for id,r in pairs(cached)do
  if not keep[id]then release(r);cached[id]=nil end
 end
 if job and not keep[job.id]then cancelPrebuild()end
 -- TEST194: a stadium lives only while its room does
 pcall(function()V.require('LeagueStadium').setLive(live)end)
end
-- the underlay plane must sit below Lance's abyss
function M.underlayDrop(map)
 if map and map.id=='LANCES_ROOM'and M.accepts(map)then return -420 end
 return nil
end
return M
