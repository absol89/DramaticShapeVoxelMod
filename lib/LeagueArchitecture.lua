-- TEST164: THE ROAD TO THE LEAGUE, rebuilt.
--
-- Route 23 and the Indigo Plateau are drawn by the PLATEAU blockset: striated
-- rock terraces, white marble wall-tops, a four-row gate wall (13/15/15/14)
-- with pilasters (21/22, 5/6, 48/49), bird statues (16/18 or 37/38 over
-- 40/41), boulders, a few ornamental canopies and checker paving (44/35).
-- The generic voxel pipeline turned that vocabulary into 8px-texel boxes
-- with Game Boy art folded onto them. This module claims those tiles and
-- builds the architecture they depict instead, as Structures objectQuads
-- with world-space League finishes (ReferenceMaterials lg*, Voxel3D
-- leagueSurface): granite ashlar terraces with lawn tops and cypress, white
-- marble parapets, crimson-and-gold gate facades with fluted pilasters and
-- lit sconces, bronze eagle statues on verde plinths, marble checker paving,
-- a crimson carpet to the League, the League hall raised as the centrepiece,
-- the seven badge checkpoints as gilded marble gateways, and the boulder
-- field as weathered granite in a meadow.
--
-- TEST165: the Route 22 gate's roof at Route 23's south end becomes a
-- marble gatehouse (arched portal, gilded doors, INDIGO PLATEAU frieze,
-- towers with fire bowls); the border ring past every open map edge drops
-- to a forest floor of cypress, stone pine and broadleaf below the plateau,
-- with retaining walls and balustrades along the rim; facade relief is
-- drawn as shadowless DETAIL (ReferenceMaterials *D) so a grazing sun no
-- longer prints stair-stepped shadow down the walls; obelisks are lower,
-- with open, glowing fire bowls; flagpoles and uplights for the animated
-- pass (LeagueRoad).
--
-- Presentation only: collision is the map's own walkability and every warp
-- and door cell stays where it is. Water, tall grass, signs and any tile
-- another builder already claimed are left alone.
local V=...
local M={REVISION='league-arch-192'}

local MAPS={ROUTE_23=true,INDIGO_PLATEAU=true}
local FLOOR={[35]='light',[45]='light',[59]='light',[44]='dark'}
local FACADE={[13]=true,[14]=true,[15]=true,[21]=true,[22]=true,[5]=true,[6]=true,[48]=true,[49]=true,
 [40]=true,[41]=true,[11]=true,[12]=true,[27]=true,[28]=true}
local MASS={[3]=true,[13]=true,[14]=true,[15]=true,[46]=true,[47]=true,[32]=true,[33]=true,[37]=true,[38]=true,
 [40]=true,[41]=true,[21]=true,[22]=true,[5]=true,[6]=true,[48]=true,[49]=true,[11]=true,[12]=true,[27]=true,[28]=true}
local PARAPET={[46]=true,[47]=true,[32]=true,[33]=true,[37]=true,[38]=true,[40]=true,[41]=true,
 [21]=true,[22]=true,[5]=true,[6]=true,[48]=true,[49]=true}
local PILASTER={[21]=true,[22]=true,[5]=true,[6]=true,[48]=true,[49]=true,[40]=true,[41]=true}
local DOOR={[11]=true,[12]=true,[27]=true,[28]=true}
local WATERISH={[20]=true,[31]=true,[50]=true,[51]=true}
-- the Route 22 gate's roof, drawn across Route 23's south end
local GATEROOF={[61]=true,[62]=true,[63]=true,[64]=true,[65]=true,[66]=true,[67]=true,[68]=true}
-- the ring outside open map edges: the plateau drops to a forest floor
local RING_T,RING_Y=12,-19.5
-- TEST166: the canal is a pool: mosaic floor this far below the paving
local POOL_Y=-11
-- Route 23's checkpoints by guard row (pokered Route23GuardsYCoords order).
M.BADGES={[136]='CASCADE',[119]='THUNDER',[105]='RAINBOW',[96]='SOUL',[85]='MARSH',[56]='VOLCANO',[35]='EARTH'}

local pi,cos,sin,floor,min,max,abs,sqrt=math.pi,math.cos,math.sin,math.floor,math.min,math.max,math.abs,math.sqrt
local function rh(a,b,s)local v=sin(a*12.9898+b*78.233+s*37.719)*43758.5453;return v-floor(v)end
-- TEST169: the League's rebuilt trees and understory
local function Flora()return V.require('LeagueFlora')end

function M.enabled(map)
 if not(map and MAPS[map.id]and map.tileset and map.tileset.id=='PLATEAU')then return false end
 local ok,CV=pcall(V.require,'CommunityVisuals')
 if not(ok and CV)then return true end
 local function on(f)local g,r=pcall(f);return g and r end
 return on(CV.customWalls)or on(CV.customRoads)or on(CV.referenceBuildings)or false
end

------------------------------------------------------------------ emitter
local Budget
-- LOADING-STUTTER: this patch's own background jobs (KantoLife's habitat job,
-- LeagueRoad's and LeagueGateRoom's warm jobs) register their coroutine with
-- sliceJob(); only inside those do the emitter and the planning loops below
-- yield through BuildBudget before a full build() has set Budget. Every other
-- caller -- a full analysis, InteriorRooms/LeagueRooms building through the kit
-- (TEST177's non-yielding upload), the draw thread -- sees exactly the
-- original behaviour.
local ownJobs=setmetatable({},{__mode='k'})
local BuildBudget
local function ownBudget()
 local co=coroutine.running()
 if co and ownJobs[co]then BuildBudget=BuildBudget or V.require('BuildBudget');return BuildBudget end
end
function M.sliceJob()local co=coroutine.running();if co then ownJobs[co]=true end end
-- LOADING-STUTTER: a cooperative yield point for the long PLANNING loops (analyze,
-- ring, night plan, the emitter's tile scans) -- in this patch's own jobs only.
local function btick()local B=ownBudget();if B then B.tick()end end
-- Surface DETAIL: the same finishes, but no shadow (ReferenceMaterials *D).
local DETAIL={lgMarble='lgMarbleD',lgGranite='lgGraniteD',lgCrimson='lgCrimsonD',lgGold='lgGoldD',
 lgBronze='lgBronzeD',lgPaveLight='lgPaveLightD',lgPaveDark='lgPaveDarkD',lgLawn='lgLawnD',
 lgCarpet='lgCarpetD',lgRock='lgRockD',lgVerde='lgVerdeD'}
local function newEmitter(out,uv)
 local E={out=out,count=0,detail=0}
 local UV={uv,uv,uv,uv}
 local own=ownBudget()   -- LOADING-STUTTER: made inside one of this patch's jobs
 local function tick()local B=Budget or own;if B then B.tick()end end
 -- a quad with per-vertex shade (s may be a number or {s1,s2,s3,s4})
 function E.quad(a,b,c,d,mat,s,glow)
  tick()
  if E.detail>0 and DETAIL[mat]then mat=DETAIL[mat]end
  local shade
  if glow then shade=(type(s)=='table'and s[1]or s or 1)+64
  elseif type(s)=='table'then shade=s
  else shade={s or 1,s or 1,s or 1,s or 1}end
  out[#out+1]={a,b,c,d,uv=UV,own=true,shade=shade,referenceMaterial=mat,referenceGlass=glow or nil}
  E.count=E.count+1
 end
 -- vertical-face shade: deepens toward the ground (contact occlusion)
 local function vs(t,y)return t*(.80+.20*min(1,max(0,y)/9))end
 E.vs=vs
 -- axis-aligned box; faces: table of booleans {top,bottom,n,s,w,e} (nil = all)
 function E.box(x0,y0,z0,x1,y1,z1,mat,t,skip,glow)
  if x1-x0<.001 or y1-y0<.001 or z1-z0<.001 then return end
  t=t or 1;skip=skip or {}
  if not skip.top then E.quad({x0,y1,z0},{x1,y1,z0},{x1,y1,z1},{x0,y1,z1},mat,t,glow)end
  if not skip.bottom then E.quad({x0,y0,z1},{x1,y0,z1},{x1,y0,z0},{x0,y0,z0},mat,t*.6,glow)end
  if not skip.s then E.quad({x0,y0,z1},{x1,y0,z1},{x1,y1,z1},{x0,y1,z1},mat,{vs(t*.92,y0),vs(t*.92,y0),vs(t*.92,y1),vs(t*.92,y1)},glow)end
  if not skip.n then E.quad({x1,y0,z0},{x0,y0,z0},{x0,y1,z0},{x1,y1,z0},mat,{vs(t*.72,y0),vs(t*.72,y0),vs(t*.72,y1),vs(t*.72,y1)},glow)end
  if not skip.w then E.quad({x0,y0,z0},{x0,y0,z1},{x0,y1,z1},{x0,y1,z0},mat,{vs(t*.80,y0),vs(t*.80,y0),vs(t*.80,y1),vs(t*.80,y1)},glow)end
  if not skip.e then E.quad({x1,y0,z1},{x1,y0,z0},{x1,y1,z0},{x1,y1,z1},mat,{vs(t*.86,y0),vs(t*.86,y0),vs(t*.86,y1),vs(t*.86,y1)},glow)end
 end
 -- run fn with every lg finish drawn as shadowless detail
 function E.decor(fn)E.detail=E.detail+1;local ok,err=pcall(fn);E.detail=E.detail-1;if not ok then error(err,0)end end
 return E
end

-- Face shade by outward normal (matches the box convention above).
local function dirShade(nx,ny,nz)
 if ny>.6 then return 1 elseif ny<-.6 then return .6 end
 local l=sqrt(nx*nx+nz*nz);if l<1e-6 then return .85 end
 nx,nz=nx/l,nz/l
 -- south .92, north .72, east .86, west .80, blended
 local s=(nz>0 and nz*.92 or -nz*.72)+(nx>0 and nx*.86 or -nx*.80)
 local w=abs(nz)+abs(nx)
 local base=s/w
 return base*(1-.25*max(0,ny))+ (ny>0 and ny*.25 or 0)
end

-- A transformed model: a local builder whose quads are rotated about Y,
-- scaled and translated, and shaded by their true facing.
local function model(E,ox,oy,oz,yaw,scale,tone)
 local co,si=cos(yaw or 0),sin(yaw or 0);scale=scale or 1;tone=tone or 1
 local L={decor=E.decor}
 local function P(p)return{ox+(p[1]*co+p[3]*si)*scale,oy+p[2]*scale,oz+(-p[1]*si+p[3]*co)*scale}end
 function L.quad(a,b,c,d,mat,t,glow)
  local A,B,C,D=P(a),P(b),P(c),P(d)
  local ux,uy,uz=C[1]-A[1],C[2]-A[2],C[3]-A[3]
  local vx,vy,vz=D[1]-B[1],D[2]-B[2],D[3]-B[3]
  local nx,ny,nz=uy*vz-uz*vy,uz*vx-ux*vz,ux*vy-uy*vx
  local l=sqrt(nx*nx+ny*ny+nz*nz)
  local s=(t or 1)*tone*(l>1e-9 and dirShade(nx/l,ny/l,nz/l)or .85)
  E.quad(A,B,C,D,mat,s,glow)
 end
 -- closed prism ring between two horizontal rings (n sides)
 function L.frustum(x,y0,z,r0,y1,r1,n,mat,cap,rot,mat2)
  rot=rot or 0
  for i=0,n-1 do
   local a0,a1=rot+i/n*pi*2,rot+(i+1)/n*pi*2
   L.quad({x+cos(a0)*r0,y0,z+sin(a0)*r0},{x+cos(a1)*r0,y0,z+sin(a1)*r0},
          {x+cos(a1)*r1,y1,z+sin(a1)*r1},{x+cos(a0)*r1,y1,z+sin(a0)*r1},(mat2 and i%2==1)and mat2 or mat)
  end
  if cap and r1>.01 then
   for i=0,n-1 do
    local a0,a1=rot+i/n*pi*2,rot+(i+1)/n*pi*2
    L.quad({x,y1,z},{x,y1,z},{x+cos(a1)*r1,y1,z+sin(a1)*r1},{x+cos(a0)*r1,y1,z+sin(a0)*r1},mat)
   end
  end
 end
 -- box faces in LOCAL axes; skip={top,bottom,n,s,w,e} (default: no bottom)
 function L.box(x0,y0,z0,x1,y1,z1,mat,t,skip,glow)
  if x1-x0<.001 or y1-y0<.001 or z1-z0<.001 then return end
  t=t or 1;skip=skip or {bottom=true}
  if not skip.bottom then L.quad({x0,y0,z1},{x1,y0,z1},{x1,y0,z0},{x0,y0,z0},mat,t,glow)end
  if not skip.top then L.quad({x0,y1,z0},{x1,y1,z0},{x1,y1,z1},{x0,y1,z1},mat,t,glow)end
  if not skip.s then L.quad({x0,y0,z1},{x1,y0,z1},{x1,y1,z1},{x0,y1,z1},mat,t,glow)end
  if not skip.n then L.quad({x1,y0,z0},{x0,y0,z0},{x0,y1,z0},{x1,y1,z0},mat,t,glow)end
  if not skip.w then L.quad({x0,y0,z0},{x0,y0,z1},{x0,y1,z1},{x0,y1,z0},mat,t,glow)end
  if not skip.e then L.quad({x1,y0,z1},{x1,y0,z0},{x1,y1,z0},{x1,y1,z1},mat,t,glow)end
 end
 -- lumpy sphere (lat/long), optional per-vertex jitter seed
 function L.sphere(x,y,z,rx,ry,rz,mat,n,rings,seed,mat2)
  local pts={}
  for j=0,rings do
   pts[j]={}
   local b=-pi/2+j*pi/rings
   for i=0,n-1 do
    local a=i/n*pi*2
    local k=1
    if seed and j>0 and j<rings then k=.86+.28*rh(seed+i,j,3)end
    pts[j][i]={x+cos(a)*cos(b)*rx*k,y+sin(b)*ry*k,z+sin(a)*cos(b)*rz*k}
   end
  end
  for j=0,rings-1 do for i=0,n-1 do
   local i2=(i+1)%n
   L.quad(pts[j][i],pts[j][i2],pts[j+1][i2],pts[j+1][i],(mat2 and (i+j)%2==1)and mat2 or mat)
  end end
 end
 return L
end

------------------------------------------------------------------ models
-- An original heraldic eagle: wings raised and spread, gripping a gilded
-- orb. Faces +z. About 18 units tall at scale 1.
local WING={{0,-.8},{2.2,-.4},{4.4,-.6},{4.6,.8},{6.6,1.0},{6.4,2.6},{8.2,3.0},{7.8,4.6},{9.4,5.2},
 {8.6,6.6},{10.0,7.4},{9.2,8.6},{10.4,9.6},{10.0,11.0},{8.5,10.5},{6.0,8.5},{3.5,5.5},{1.5,2.5}}
local function eagle(L,seed)
 local B,G='lgBronze','lgGold'
 -- a faceted gilded orb under the talons
 L.frustum(0,0,0,.2,1.8,2.0,6,G)
 L.frustum(0,1.8,0,2.0,3.6,.4,6,G,true)
 -- talons gripping the orb
 for _,dx in ipairs({-1.0,1.0})do L.frustum(dx,2.8,.5,.55,4.6,.8,4,B)end
 -- body: a full, forward-leaning teardrop
 L.frustum(0,3.6,-.6,1.5,5.6,2.4,8,B)
 L.frustum(0,5.6,-.4,2.4,8.6,2.9,8,B)
 L.frustum(0,8.6,.1,2.9,11.0,2.0,8,B)
 -- neck, head and hooked beak
 L.frustum(0,11.0,.5,2.0,12.6,1.5,8,B)
 L.frustum(0,12.6,.8,1.5,14.4,1.4,8,B)
 L.frustum(0,14.4,.8,1.4,15.3,.45,8,B,true)
 L.quad({-.55,14.3,2.0},{.55,14.3,2.0},{.0,13.0,3.7},{.0,13.0,3.7},G)
 L.quad({.55,14.3,2.0},{.0,14.8,2.0},{.0,13.0,3.7},{.0,13.0,3.7},G)
 L.quad({.0,14.8,2.0},{-.55,14.3,2.0},{.0,13.0,3.7},{.0,13.0,3.7},G)
 L.quad({-.5,13.6,2.2},{.5,13.6,2.2},{.0,13.0,3.7},{.0,13.0,3.7},G)
 -- wings: solid raised blades with scalloped primaries, swept slightly back
 for _,sg in ipairs({-1,1})do
  local sx,sy,sz=sg*1.9,9.4,-.5
  local function P(u,v,d)return{sx+sg*u*.96,sy+v,sz-u*.16+d}end
  local n=#WING
  for i=1,n do
   local a,b=WING[i],WING[i%n+1]
   -- fan faces from the shoulder, front and back
   L.quad(P(0,0,.38),P(a[1],a[2],.38),P(b[1],b[2],.38),P(0,0,.38),B)
   L.quad(P(0,0,-.38),P(b[1],b[2],-.38),P(a[1],a[2],-.38),P(0,0,-.38),B)
   -- edge band: gilded along the leading edge and the primaries
   L.quad(P(a[1],a[2],.38),P(a[1],a[2],-.38),P(b[1],b[2],-.38),P(b[1],b[2],.38),G)
  end
 end
 -- tail fan
 L.quad({-1.2,6.4,-1.9},{1.2,6.4,-1.9},{2.0,2.6,-4.0},{-2.0,2.6,-4.0},B)
 L.quad({-1.2,6.4,-1.5},{-2.0,2.6,-3.6},{2.0,2.6,-3.6},{1.2,6.4,-1.5},B)
end

-- A cypress: short trunk, tall tapering evergreen spire.
local function cypress(L,seed,h)
 h=h or 26
 L.frustum(0,0,0,.85,h*.82,.18,5,'forestBark')
 for j=1,7 do
  local t=(j-1)/7;local y=h*(.13+t*.75)
  local r=(h*.135)*(1-t*.88)*(.87+.22*rh(seed,j,6))
  local off=(rh(seed,j,9)-.5)*r*.35
  L.frustum(off,y,off*.5,r*.64,y+h*.10,r,7,'lgFoliage',false,seed+j*.55)
  L.frustum(off,y+h*.10,off*.5,r,y+h*.29,r*.12,7,'lgFoliage',false,seed+j*.55)
 end
end

-- A clipped topiary ball on a short clear stem.
local function topiary(L,seed,r)
 r=r or 4.2
 L.frustum(0,0,0,.45,2.2,.4,5,'forestBark')
 L.sphere(0,2.2+r*.9,0,r,r*.92,r,'lgFoliage',8,5,seed,'lgFoliage')
end

-- TEST166: a knot-garden parterre. Clipped box border with a rounded
-- crown, a box saltire dividing four flower carpets (lgBloom, a planted
-- finish with a palette per bed), a few raised bloom clumps, and a clipped
-- box cone at the centre.
local function flowerBed(E,X,Y,Z,seed)
 local r,tk,hb=6.2,1.2,1.6
 local H='lgFoliage'
 E.box(X-r,Y,Z-r,X+r,Y+hb,Z-r+tk,H,1,{bottom=true})
 E.box(X-r,Y,Z+r-tk,X+r,Y+hb,Z+r,H,1,{bottom=true})
 E.box(X-r,Y,Z-r+tk,X-r+tk,Y+hb,Z+r-tk,H,1,{bottom=true,n=true,s=true})
 E.box(X+r-tk,Y,Z-r+tk,X+r,Y+hb,Z+r-tk,H,1,{bottom=true,n=true,s=true})
 -- four flower carpets between the saltire arms
 local ri,yb=r-tk,Y+.7
 local C={X,yb,Z}
 local corners={{X-ri,yb,Z-ri},{X+ri,yb,Z-ri},{X+ri,yb,Z+ri},{X-ri,yb,Z+ri}}
 for k=1,4 do
  local p1,p2=corners[k],corners[k%4+1]
  E.quad(p1,p2,C,C,'lgBloom',1)
 end
 -- the saltire: two clipped box bars on the diagonals
 for _,a in ipairs({pi/4,-pi/4})do
  model(E,X,Y,Z,a,1).box(-ri*1.36,0,-.55,ri*1.36,1.35,.55,H,1)
 end
 -- a raised bloom clump in each carpet
 for k=0,3 do
  local a=k*pi/2+pi/2
  local cx,cz=X+cos(a)*3.3,Z+sin(a)*3.3
  model(E,cx,yb,cz,a,1).frustum(0,0,0,1.5,1.3+rh(seed,k,31)*.5,.2,4,'lgBloom',false,pi/4)
 end
 -- clipped box cone at the heart
 model(E,X,Y,Z,0,1).frustum(0,0,0,1.55,3.8,.12,6,H,false,.3)
end

-- TEST166: FOUNTAINS. Octagonal marble basin (gold band, mosaic lining),
-- a pedestal with bowls; the water itself, the jets and the overflow are
-- animated by LeagueRoad from the record this returns.
local function octagon(E,X,Y,Z,r,mat,t,rot)
 rot=rot or pi/8
 for i=0,7 do
  local a0,a1=rot+i*pi/4,rot+(i+1)*pi/4
  E.quad({X,Y,Z},{X,Y,Z},{X+cos(a1)*r,Y,Z+sin(a1)*r},{X+cos(a0)*r,Y,Z+sin(a0)*r},mat,t or 1)
 end
end
local function basinRing(E,X,Y,Z,rIn,rOut,h,band)
 local rot=pi/8
 for i=0,7 do
  local a0,a1=rot+i*pi/4,rot+(i+1)*pi/4
  local c0,s0,c1,s1=cos(a0),sin(a0),cos(a1),sin(a1)
  local nx,nz=cos((a0+a1)/2),sin((a0+a1)/2)
  local t=dirShade(nx,0,nz)
  -- outer wall, gold band, rim, inner lining
  E.quad({X+c1*rOut,Y,Z+s1*rOut},{X+c0*rOut,Y,Z+s0*rOut},{X+c0*rOut,Y+h,Z+s0*rOut},{X+c1*rOut,Y+h,Z+s1*rOut},'lgMarble',t)
  if band then
   local r2=rOut+.12
   E.decor(function()E.quad({X+c1*r2,Y+h-1.1,Z+s1*r2},{X+c0*r2,Y+h-1.1,Z+s0*r2},{X+c0*r2,Y+h-.6,Z+s0*r2},{X+c1*r2,Y+h-.6,Z+s1*r2},'lgGold',t)end)
  end
  E.quad({X+c0*rIn,Y+h,Z+s0*rIn},{X+c1*rIn,Y+h,Z+s1*rIn},{X+c1*rOut,Y+h,Z+s1*rOut},{X+c0*rOut,Y+h,Z+s0*rOut},'lgMarble',1)
  E.quad({X+c0*rIn,Y+.3,Z+s0*rIn},{X+c1*rIn,Y+.3,Z+s1*rIn},{X+c1*rIn,Y+h,Z+s1*rIn},{X+c0*rIn,Y+h,Z+s0*rIn},'lgPool',dirShade(-nx,0,-nz))
 end
 octagon(E,X,Y+.3,Z,rIn,'lgPool',.95)
end
local function fountain(E,F)
 local X,Y,Z=F.x,F.y,F.z
 F.water,F.curtains,F.jets,F.arcs={},{},{},{}
 octagon(E,X,Y+.05,Z,F.plaza,'lgGravel',1)
 if F.kind=='single' then
  local R=6.4
  basinRing(E,X,Y,Z,R-.9,R,2.2,true)
  local Lm=model(E,X,Y+.3,Z,0,1)
  Lm.frustum(0,0,0,1.5,1.4,1.3,8,'lgVerde')
  Lm.frustum(0,1.4,0,.75,6.0,.62,8,'lgMarble')
  E.decor(function()Lm.frustum(0,3.6,0,.82,4.1,.82,8,'lgGold')end)
  Lm.frustum(0,6.0,0,.62,7.2,2.9,10,'lgMarble')
  Lm.frustum(0,7.2,0,2.9,7.55,3.05,10,'lgGold')
  Lm.frustum(0,7.55,0,3.05,7.3,2.4,10,'lgPool')
  Lm.frustum(0,7.3,0,.5,8.4,.38,6,'lgGold')
  Lm.sphere(0,8.75,0,.5,.5,.5,'lgGold',6,4)
  F.water[#F.water+1]={y=Y+1.85,r=R-.95}
  F.water[#F.water+1]={y=Y+7.45,r=2.45}
  F.curtains[#F.curtains+1]={r=2.95,y0=Y+1.85,y1=Y+7.5}
  F.jets[#F.jets+1]={x=X,y=Y+9.1,z=Z,h=6,spread=2.6,base=Y+7.45}
 else
  local R=F.R
  basinRing(E,X,Y,Z,R-1.4,R,2.6,true)
  -- an inner step ring under the water, for depth
  local Lm=model(E,X,Y+.3,Z,0,1)
  Lm.frustum(0,0,0,4.2,1.4,3.8,8,'lgVerde',false,pi/8)
  Lm.frustum(0,1.4,0,3.0,2.4,2.6,8,'lgMarble',false,pi/8)
  Lm.frustum(0,2.4,0,1.5,7.4,1.25,10,'lgMarble')
  E.decor(function()Lm.frustum(0,4.6,0,1.62,5.2,1.62,10,'lgGold')end)
  Lm.frustum(0,7.4,0,1.25,8.8,5.6,12,'lgMarble')
  Lm.frustum(0,8.8,0,5.6,9.2,5.8,12,'lgGold')
  Lm.frustum(0,9.2,0,5.8,8.9,5.0,12,'lgPool')
  Lm.frustum(0,8.9,0,.9,12.6,.7,8,'lgMarble')
  Lm.frustum(0,12.6,0,.7,13.4,2.7,10,'lgMarble')
  Lm.frustum(0,13.4,0,2.7,13.7,2.85,10,'lgGold')
  Lm.frustum(0,13.7,0,2.85,13.5,2.25,10,'lgPool')
  Lm.frustum(0,13.5,0,.45,14.6,.32,6,'lgGold')
  Lm.sphere(0,15.0,0,.55,.55,.55,'lgGold',6,4)
  F.water[#F.water+1]={y=Y+2.25,r=R-1.45}
  F.water[#F.water+1]={y=Y+9.15,r=5.05}
  F.water[#F.water+1]={y=Y+13.95,r=2.3}
  F.curtains[#F.curtains+1]={r=5.75,y0=Y+2.25,y1=Y+9.2}
  F.curtains[#F.curtains+1]={r=2.8,y0=Y+9.15,y1=Y+13.9}
  F.jets[#F.jets+1]={x=X,y=Y+15.4,z=Z,h=9,spread=3.4,base=Y+13.95}
  -- four bronze eagles on the rim, each spouting an arc into the basin
  for k=0,3 do
   local a=pi/4+k*pi/2
   local ex,ez=X+cos(a)*(R-.7),Z+sin(a)*(R-.7)
   E.box(ex-1.0,Y+2.6,ez-1.0,ex+1.0,Y+3.6,ez+1.0,'lgMarble',1,{bottom=true})
   local yaw=math.atan2(-cos(a),-sin(a))
   local es=.30
   eagle(model(E,ex,Y+3.6,ez,yaw,es),k+7)
   local bx,bz=ex-cos(a)*3.3*es,ez-sin(a)*3.3*es
   F.arcs[#F.arcs+1]={x0=bx,y0=Y+3.6+es*13.4,z0=bz,x1=X+cos(a)*(R*.42),y1=Y+2.25,z1=Z+sin(a)*(R*.42),h=3.8}
  end
 end
 return F
end

-- A gilded garden urn on a verde pedestal, spilling greenery.
local function urn(L,seed)
 L.box(-3.0,0,-3.0,3.0,3.4,3.0,'lgVerde')
 L.box(-3.4,3.4,-3.4,3.4,4.0,3.4,'lgGold')
 L.frustum(0,4.0,0,1.2,5.2,.75,8,'lgMarble')
 L.frustum(0,5.2,0,.75,6.2,2.3,8,'lgMarble')
 L.frustum(0,6.2,0,2.3,8.6,2.8,8,'lgMarble')
 L.frustum(0,8.6,0,2.8,9.2,3.1,8,'lgGold')
 L.sphere(0,9.9,0,2.5,1.7,2.5,'lgFoliage',8,4,seed,'lgFoliage')
end

-- An ornamental round tree with a layered crown.
local function roundTree(L,seed)
 L.frustum(0,0,0,1.4,4.0,1.0,7,'forestBark')
 L.frustum(0,4.0,0,1.0,10.5,.75,7,'forestBark')
 L.sphere(0,13.5,0,7.2,5.8,7.2,'lgFoliage',10,6,seed,'lgFoliage')
 L.sphere(2.4,17.2,-1.0,4.6,3.8,4.6,'lgFoliage',9,5,seed+3,'lgFoliage')
 L.sphere(-2.2,16.6,1.4,4.2,3.4,4.2,'lgFoliage',9,5,seed+7,'lgFoliage')
end

-- A weathered granite boulder (jittered rings), lichen comes from the finish.
local function boulder(L,seed,rx,ry,rz)
 local n=7;local rot=rh(seed,0,71)*pi*2
 local rings={{-.4,1.0},{.42,1.07},{.80,.74},{1,.22}}
 local pts={}
 for ri,rg in ipairs(rings)do
  pts[ri]={}
  for i=0,n-1 do
   local a=rot+i/n*pi*2+(rh(seed,i+ri*9,73)-.5)*.5
   local k=rg[2]*(.80+rh(seed,i*3+ri,75)*.40)
   pts[ri][i]={cos(a)*rx*k,rg[1]*ry+(ri>1 and(rh(seed,i,77+ri)-.5)*.15*ry or 0),sin(a)*rz*k}
  end
 end
 for ri=1,#rings-1 do for i=0,n-1 do local j=(i+1)%n
  L.quad(pts[ri][i],pts[ri][j],pts[ri+1][j],pts[ri+1][i],'lgRock')
 end end
 for i=0,n-1 do local j=(i+1)%n
  L.quad(pts[#rings][i],pts[#rings][j],{0,ry*1.05,0},{0,ry*1.05,0},'lgRock')
 end
end

-- Pixel capitals for the League's gilded inscription. Most glyphs are 3 wide;
-- M, N and W get 5/4 columns so they read properly at a distance.
local FONT={A='010101111101101',B='110101110101110',C='111100100100111',D='110101101101110',E='111100110100111',
 F='111100110100100',G='111100101101111',H='101101111101101',I='111010010010111',K='101101110101101',L='100100100100111',
 O='111101101101111',P='110101110100100',R='110101110101101',S='111100111001111',
 T='111010010010010',U='101101101101111',V='101101101101010',Y='101101010010010',
 M={'10001','11011','10101','10001','10001'},N={'1001','1101','1011','1001','1001'},
 W={'10001','10001','10101','11011','10001'},[' ']={'00','00','00','00','00'},
 -- TEST175: the digits and a few more (floor numbers, unit plates)
 ['0']='111101101101111',['1']='010110010010111',['2']='111001111100111',['3']='111001111001111',
 ['4']='101101111001001',['5']='111100111001111',['6']='111100111101111',['7']='111001001001001',
 ['8']='111101111101111',['9']='111101111001111',J='001001001101111',X='101101010101101',
 Z='111001010100111',['-']='000000111000000',['.']={'0','0','0','0','1'}}
for k,g in pairs(FONT)do if type(g)=='string'then
 FONT[k]={g:sub(1,3),g:sub(4,6),g:sub(7,9),g:sub(10,12),g:sub(13,15)}end end
local function inscription(E,str,cx,y,z,scale,mat,maxw)
 local cols=-1
 for i=1,#str do cols=cols+#(FONT[str:sub(i,i)]or FONT[' '])[1]+1 end
 if maxw then scale=math.min(scale,maxw/cols)end
 local left=cx-cols*scale/2;local at=0
 for i=1,#str do local g=FONT[str:sub(i,i)]or FONT[' '];local gw=#g[1]
  for row=1,5 do local r=g[row];local c=1
   while c<=gw do
    if r:sub(c,c)=='1'then local c2=c
     while c2<gw and r:sub(c2+1,c2+1)=='1'do c2=c2+1 end
     local a,b=left+(at+c-1)*scale,y+(5-row)*scale
     E.box(a,b,z,left+(at+c2)*scale,b+scale,z+scale*.6,mat,1,{bottom=row<5,n=true})
     c=c2+1
    else c=c+1 end
   end
  end
  at=at+gw+1
 end
 return scale
end


-- A doorway in a south-facing wall plane at z: dark recess, gilded bronze
-- double leaves, marble architrave, gold lintel and a small pediment.
local function doorway(E,A,B,z,dh,noPediment)
 local dw=B-A
 E.quad({A+1.5,0,z-3.5},{B-1.5,0,z-3.5},{B-1.5,dh,z-3.5},{A+1.5,dh,z-3.5},'lgVerde',.35)
 E.quad({A+1.5,.02,z-3.5},{B-1.5,.02,z-3.5},{B-1.5,.02,z+.4},{A+1.5,.02,z+.4},'lgPaveDark',.55)
 E.quad({A+1.5,dh-.05,z+.05},{B-1.5,dh-.05,z+.05},{B-1.5,dh+1.6,z+.05},{A+1.5,dh+1.6,z+.05},'lgMarble',.9)
 E.quad({A+1.5,dh,z},{B-1.5,dh,z},{B-1.5,dh,z-3.5},{A+1.5,dh,z-3.5},'lgMarble',.6)
 E.quad({A+1.5,0,z},{A+1.5,0,z-3.5},{A+1.5,dh,z-3.5},{A+1.5,dh,z},'lgMarble',.7)
 E.quad({B-1.5,0,z-3.5},{B-1.5,0,z},{B-1.5,dh,z},{B-1.5,dh,z-3.5},'lgMarble',.7)
 local leaf=(dw-3)/2
 for i=0,1 do
  local l0=A+1.5+i*leaf;local l1=l0+leaf-.2
  E.quad({l0,0,z-3.3},{l1,0,z-3.3},{l1,dh-.4,z-3.3},{l0,dh-.4,z-3.3},'lgBronze',.9)
  local zf=z-3.22
  E.quad({l0,dh-1.3,zf},{l1,dh-1.3,zf},{l1,dh-.4,zf},{l0,dh-.4,zf},'lgGold',.95)
  E.quad({l0,0,zf},{l1,0,zf},{l1,.9,zf},{l0,.9,zf},'lgGold',.95)
  E.quad({i==0 and l0 or l1-.6,0,zf},{i==0 and l0+.6 or l1,0,zf},{i==0 and l0+.6 or l1,dh-.4,zf},{i==0 and l0 or l1-.6,dh-.4,zf},'lgGold',.95)
  for _,py in ipairs({.18,.56})do
   local p0,p1=dh*py,dh*py+dh*.30
   E.box(l0+1.0,p0,z-3.3,l1-1.0,p1,z-3.05,'lgGold',1,{bottom=true,n=true})
   E.box(l0+1.4,p0+.4,z-3.3,l1-1.4,p1-.4,z-2.9,'lgBronze',1,{bottom=true,n=true})
   local mx,my=(l0+l1)/2,(p0+p1)/2;local r=min(1.3,(l1-l0)*.18)
   E.quad({mx,my-r*1.4,z-2.86},{mx+r,my,z-2.86},{mx,my+r*1.4,z-2.86},{mx-r,my,z-2.86},'lgGold',1)
  end
  E.box(i==0 and l1-1.6 or l0+.8,dh*.48,z-3.3,i==0 and l1-.8 or l0+1.6,dh*.48+1.6,z-2.6,'lgGold',1,{n=true})
 end
 -- architrave, gilded lintel, pediment (all shallow)
 E.box(A-.5,0,z-.2,A+1.5,dh+1.5,z+1.0,'lgMarble',1,{n=true,bottom=true})
 E.box(B-1.5,0,z-.2,B+.5,dh+1.5,z+1.0,'lgMarble',1,{n=true,bottom=true})
 E.box(A-1.2,dh+1.5,z-.2,B+1.2,dh+3.4,z+1.3,'lgGold',1,{n=true})
 if noPediment then return end
 local pm=(A+B)/2
 E.quad({A-1.0,dh+3.4,z+1.1},{B+1.0,dh+3.4,z+1.1},{pm,dh+8.0,z+1.1},{pm,dh+8.0,z+1.1},'lgMarble',.95)
 E.quad({A-1.0,dh+3.4,z+1.1},{pm,dh+8.0,z+1.1},{pm,dh+8.0,z-.2},{A-1.0,dh+3.4,z-.2},'lgMarble',1)
 E.quad({pm,dh+8.0,z+1.1},{B+1.0,dh+3.4,z+1.1},{B+1.0,dh+3.4,z-.2},{pm,dh+8.0,z-.2},'lgMarble',1)
end

-- An open fire bowl: gold outside, gold lip turning in, a bed of coals that
-- glows after dark (the animated flame stands on it).
local function fireBowl(Lm,y0,r0,r1,hgt)
 local y1=y0+hgt
 Lm.frustum(0,y0,0,r0,y1,r1,10,'lgGold')
 Lm.frustum(0,y1,0,r1,y1+.35,r1+.35,10,'lgGold')
 Lm.frustum(0,y1+.35,0,r1+.35,y1-.6,r1*.82,10,'lgGold')
 local yc=y1-.6
 for i=0,9 do
  local a0,a1=i/10*pi*2,(i+1)/10*pi*2
  Lm.quad({0,yc+.25,0},{0,yc+.25,0},{cos(a1)*r1*.82,yc,sin(a1)*r1*.82},{cos(a0)*r1*.82,yc,sin(a0)*r1*.82},'lgRock',.75,true)
 end
 return yc
end

-- The League hall's eternal-flame bowls: {x, y, z, scale}.
local function hallBowls(hl)
 local at=hl.attic
 return {{hl.x0+4,hl.h,hl.z1-4,1},{hl.x1-4,hl.h,hl.z1-4,1},
  {at.x0+5,at.h+1.2,at.z1-5,.8},{at.x1-5,at.h+1.2,at.z1-5,.8}}
end

------------------------------------------------------------------ layout
-- Pure analysis over a tile accessor, so the same plan serves the builder,
-- the animated pass (LeagueRoad) and offline checks.
function M.analyze(map,tileAt,claimed,walk,water)
 local tw=(map.def and map.def.width or 0)*4;local th=(map.def and map.def.height or 0)*4
 local L={tw=tw,th=th,id=map.id}
 local function t(x,y)if x<0 or y<0 or x>=tw or y>=th then return nil end;return tileAt(x,y)end
 local function free(x,y)return t(x,y)~=nil and not claimed(x,y)end
 local cls={};L.cls=cls
 local function K(x,y)return y*tw+x end
 L.K=K
 -- standalone statues: figure (16/18 over 40/41) on a plinth (21/22 over 48/49)
 L.statues={}
 for y=0,th-4 do btick() for x=0,tw-2 do
  if t(x,y)==16 and t(x+1,y)==18 and t(x,y+1)==40 and t(x+1,y+1)==41
     and t(x,y+2)==21 and t(x+1,y+2)==22 and t(x,y+3)==48 and t(x+1,y+3)==49 then
   local ok=true
   for yy=y,y+3 do for xx=x,x+1 do if not free(xx,yy)then ok=false end end end
   if ok then
    L.statues[#L.statues+1]={x=x*8+8,z0=y*8,z1=(y+4)*8,seed=x*31+y*7}
    for yy=y,y+3 do for xx=x,x+1 do cls[K(xx,yy)]='statue'end end
   end
  end
 end end
 -- boulders and ornamental canopies (2x2 tiles each)
 L.boulders,L.trees={},{}
 for y=0,th-2 do btick() for x=0,tw-2 do
  if t(x,y)==42 and t(x+1,y)==43 and t(x,y+1)==34 and t(x+1,y+1)==29 and free(x,y)then
   L.boulders[#L.boulders+1]={x=x*8+8,z=y*8+8,seed=x*13+y*17}
   for yy=y,y+1 do for xx=x,x+1 do cls[K(xx,yy)]='boulder'end end
  elseif t(x,y)==7 and t(x+1,y)==8 and t(x,y+1)==23 and t(x+1,y+1)==24 and free(x,y)then
   L.trees[#L.trees+1]={x=x*8+8,z=y*8+8,seed=x*7+y*3,kind='round'}
   for yy=y,y+1 do for xx=x,x+1 do cls[K(xx,yy)]='canopy'end end
  end
 end end
 -- TEST192: the signboard (9/10 over 25/26) becomes a League plaque; its
 -- Game Boy art read as a scrap of garbled pixels standing on a checker
 L.signs={}
 for y=0,th-2 do btick() for x=0,tw-2 do
  if t(x,y)==9 and t(x+1,y)==10 and t(x,y+1)==25 and t(x+1,y+1)==26
     and free(x,y)and free(x+1,y)and free(x,y+1)and free(x+1,y+1)
     and not cls[K(x,y)]and not cls[K(x+1,y)]and not cls[K(x,y+1)]and not cls[K(x+1,y+1)]then
   L.signs[#L.signs+1]={x=x*8+8,z=y*8+8,seed=x*7+y*11}
   for yy=y,y+1 do for xx=x,x+1 do cls[K(xx,yy)]='sign'end end
  end
 end end
 -- the Route 22 gate (Route 23's south end): its roof becomes a gatehouse
 L.gatehouse=nil
 if map.id=='ROUTE_23'then
  local gx0,gx1,gy0,gy1
  for y=0,th-1 do btick() for x=0,tw-1 do
   if GATEROOF[t(x,y)]and free(x,y)then
    gx0=min(gx0 or x,x);gx1=max(gx1 or x,x);gy0=min(gy0 or y,y);gy1=max(gy1 or y,y)
   end
  end end
  if gx0 and gx1-gx0>=8 and gy1-gy0>=2 then
   for y=gy0,gy1 do for x=gx0,gx1 do if GATEROOF[t(x,y)]and free(x,y)then cls[K(x,y)]='gatehouse'end end end
   local d0,d1
   for _,w in ipairs((map.def and map.def.warps)or{})do
    if tostring(w.destMap or''):find('ROUTE_22_GATE',1,true)and type(w.x)=='number'then
     d0=min(d0 or w.x*16,w.x*16);d1=max(d1 or (w.x+1)*16,(w.x+1)*16)
    end
   end
   if not d0 then local mx=(gx0+gx1+1)*4;d0,d1=mx-16,mx+16 end
   L.gatehouse={x0=gx0*8,x1=(gx1+1)*8,z0=gy0*8,z1=(gy1+1)*8,door0=d0,door1=d1,h=64,tw=28,th=72}
  end
 end
 -- floor and mass
 for y=0,th-1 do btick() for x=0,tw-1 do
  local k=K(x,y)
  if not cls[k]and free(x,y)then
   local v=t(x,y)
   if FLOOR[v]then cls[k]='floor'
   elseif MASS[v]then cls[k]='mass'end
  end
 end end
 -- heights: per column, from each facade run's bottom up through the mass
 local H={};L.H=H
 local facadeRun={};L.facadeRun=facadeRun;L.facadeTile={}
 local function isMass(x,y)return cls[K(x,y)]=='mass'end
 for x=0,tw-1 do
  local y=th-1
  while y>=0 do
   if isMass(x,y)and FACADE[t(x,y)]and not isMass(x,y+1)then
    local n=0;local yy=y
    while yy>=0 and isMass(x,yy)and FACADE[t(x,yy)]and n<6 do
     -- a bird body counts only when it sits on the pilaster below it
     if (t(x,yy)==40 or t(x,yy)==41)and n==0 then break end
     n=n+1;yy=yy-1
    end
    if n>=3 then
     local h=n*8
     facadeRun[K(x,y)]={top=y-n+1,bottom=y,h=h}
     for fy=y-n+1,y do L.facadeTile[K(x,fy)]=true end
     local ry=y
     while ry>=0 and isMass(x,ry)and not H[K(x,ry)]do H[K(x,ry)]=h;ry=ry-1 end
     y=ry
    else y=y-1 end
   else y=y-1 end
  end
 end
 -- a facade that would face straight into the gatehouse is never seen
 for k,fr in pairs(facadeRun)do
  if cls[K(k%tw,fr.bottom+1)]=='gatehouse'then fr.hidden=true end
 end
 -- fill unassigned mass from neighbours, default 32
 local changed=true;local guard=0
 while changed and guard<400 do
  changed=false;guard=guard+1
  for y=0,th-1 do btick() for x=0,tw-1 do
   local k=K(x,y)
   if isMass(x,y)and not H[k]then
    local best
    for _,d in ipairs({{1,0},{-1,0},{0,1},{0,-1}})do local v=H[K(x+d[1],y+d[2])];if isMass(x+d[1],y+d[2])and v then best=max(best or 0,v)end end
    if best then H[k]=best;changed=true end
   end
  end end
 end
 for y=0,th-1 do btick() for x=0,tw-1 do if isMass(x,y)and not H[K(x,y)]then H[K(x,y)]=32 end end end
 -- The League hall: the Indigo centre pavilion rises above its wings.
 L.hall=nil
 if map.id=='INDIGO_PLATEAU'then
  local doorX
  for y=0,th-1 do btick() for x=0,tw-1 do if t(x,y)==11 and t(x+1,y)==12 and not doorX then doorX={x,y}end end end
  if doorX then
   local x0,x1=12,27;local y0,y1=0,11
   -- locate the hall by its facade row (the door's run bottom) and flanking columns
   local fy=doorX[2]+1
   for y=y0,fy do for x=x0,x1 do if isMass(x,y)then H[K(x,y)]=56 end end end
   L.hall={x0=x0*8,x1=(x1+1)*8,z1=(fy+1)*8,h=56,attic={x0=14*8,x1=26*8,z0=0,z1=7*8,h=70}}
  end
 end
 -- wall eagles: bird heads standing on the parapet
 L.eagles={}
 for y=0,th-2 do btick() for x=0,tw-2 do
  if t(x,y)==37 and t(x+1,y)==38 and t(x,y+1)==40 and t(x+1,y+1)==41 and isMass(x,y)then
   L.eagles[#L.eagles+1]={x=x*8+8,z=y*8+8,y=(H[K(x,y)]or 32)+2.6,seed=x*5+y*11}
  end
 end end
 -- checkpoints (Route 23): guards and the two swimmer checks
 L.gates={}
 if map.id=='ROUTE_23'then
  for _,o in ipairs((map.def and map.def.objects)or{})do
   local badge=type(o.y)=='number'and M.BADGES[o.y]
   if badge and type(o.x)=='number'then
    local open=function(cx)return walk(cx,o.y)or water(cx,o.y)end
    local xa,xb=o.x,o.x
    while xa-1>=0 and open(xa-1)and o.x-xa<12 do xa=xa-1 end
    while xb+1<tw/2 and open(xb+1)and xb-o.x<12 do xb=xb+1 end
    local function topAt(cx)
     local h=0
     for dy=0,1 do for dx=0,1 do local k=K(cx*2+dx,o.y*2+dy);if isMass(cx*2+dx,o.y*2+dy)then h=max(h,H[k]or 0)end end end
     return h
    end
    local hl,hr=topAt(xa-1),topAt(xb+1)
    local base=max(hl,hr,32)
    local Lx,Rx=xa*16-8,(xb+1)*16+8
    if Lx<6 then Lx=6;hl=0 end
    if Rx>tw*8-6 then Rx=tw*8-6;hr=0 end
    -- beam and obelisk tops kept low enough to stay in frame from the path
    L.gates[#L.gates+1]={badge=badge,cy=o.y,xa=xa,xb=xb,z=o.y*16+8,L=Lx,R=Rx,
     baseL=hl,baseR=hr,base=base,beam=base+13,top=base+22,inWater=water(o.x,o.y)}
   end
  end
 end
 -- TERRACE GARDENS: every rock-top lawn strip becomes a formal parterre.
 -- Cypress allees on the strip edges, box-hedged flower beds and clipped
 -- topiary between, a gilded urn on the centre line now and then.
 L.garden={};L.cypress=L.garden;L.lamps={}
 local function lawnTile(x,y)
  if not isMass(x,y)then return false end
  local v=t(x,y)
  if v~=3 then
   -- the lawn over a gate wall's band rows (the bottom row is a marble parapet)
   if facadeRun[K(x,y)]or not(v==13 or v==14 or v==15 or DOOR[v])then return false end
   if v==13 and not L.facadeTile[K(x,y)]then return false end
   local yy=y
   while yy>=0 and isMass(x,yy)and(t(x,yy)==13 or t(x,yy)==14 or t(x,yy)==15 or DOOR[t(x,yy)])do yy=yy-1 end
   if not(isMass(x,yy)and t(x,yy)==3)then return false end
  end
  if L.hall and x*8>=L.hall.x0-8 and x*8<L.hall.x1+8 and y*8<L.hall.z1+8 then return false end
  return true
 end
 local GW,GH=floor(tw/2),floor(th/2)
 local gc={}
 local function G(cx,cy)if cx<0 or cy<0 or cx>=GW or cy>=GH then return nil end;return gc[cy*GW+cx]end
 for cy=0,GH-1 do btick() for cx=0,GW-1 do
  local x,y=cx*2,cy*2
  if lawnTile(x,y)and lawnTile(x+1,y)and lawnTile(x,y+1)and lawnTile(x+1,y+1)then
   local hh=H[K(x,y)]
   if H[K(x+1,y)]==hh and H[K(x,y+1)]==hh and H[K(x+1,y+1)]==hh then gc[cy*GW+cx]=hh end
  end
 end end
 local function nearGate(cx,cy,r)
  for _,g in ipairs(L.gates)do
   if abs(cy-g.cy)<=r and(abs(cx-(g.xa-1))<=r or abs(cx-(g.xb+1))<=r)then return true end
  end
  return false
 end
 -- TEST166: each lawn strip is laid out as a formal garden. Strips three
 -- or more cells across get a gravel aisle down the middle and FOUNTAINS
 -- on it (one cell across a 3-wide strip, a grand 2x2 or 3x3 basin on
 -- wider ones), urns flanking them, cypress allees on the edges and knot
 -- beds between. Narrow strips keep cypress and beds.
 L.fountains,L.aisles={},{}
 local done={}
 for cy=0,GH-1 do btick() for cx=0,GW-1 do
  local hh=G(cx,cy)
  if hh and not nearGate(cx,cy,1)then
   local ax,bx=cx,cx;while G(ax-1,cy)do ax=ax-1 end;while G(bx+1,cy)do bx=bx+1 end
   local az,bz=cy,cy;while G(cx,az-1)do az=az-1 end;while G(cx,bz+1)do bz=bz+1 end
   local wx,wz=bx-ax+1,bz-az+1
   local alongZ=wx<=wz
   local n,i,j,len
   if alongZ then n,i,j,len=wx,cx-ax,cy-az,wz else n,i,j,len=wz,cy-az,cx-ax,wx end
   -- the strip's fountain plan (once per strip, by its corner and extent)
   local skey=(alongZ and 1 or 0)..':'..(alongZ and ax or az)..':'..(alongZ and bx or bz)..':'..(alongZ and az or ax)..':'..(alongZ and bz or bx)
   local plan=done[skey]
   if not plan and n>=3 and len>=5 then
    plan={spots={}}
    local k=max(1,floor((len+3)/10));local step=len/k
    for m=0,k-1 do plan.spots[#plan.spots+1]=floor(step*(m+.5))end
    done[skey]=plan
   elseif not plan then plan={spots={}};done[skey]=plan end
   -- where across/along does this cell sit relative to the plan
   local even=n%2==0
   local c0,c1
   if even then c0,c1=n/2-1,n/2 else c0=(n-1)/2;c1=c0 end
   local onCenter=(i==c0 or i==c1)and n>=3
   local fspan=even and 1 or (n>=5 and 1 or 0)   -- half-extent along j
   local inFountain,nearF=false,99
   for _,p in ipairs(plan.spots)do
    local jlo,jhi
    if even then jlo,jhi=p,p+1 else jlo,jhi=p-fspan,p+fspan end
    local acrossIn=(even and (i==c0 or i==c1)) or ((not even) and abs(i-c0)<=fspan)
    if acrossIn and j>=jlo and j<=jhi then inFountain=true end
    nearF=min(nearF,j<jlo and jlo-j or (j>jhi and j-jhi or 0))
    -- the fountain is placed once, from its first cell
    if j==jlo and i==(even and c0 or c0-fspan) then
     local fx,fz
     local acrossC=(even and (c0+c1+1)/2 or (c0+.5))*16
     local alongC=(even and (jlo+jhi+1)/2 or (p+.5))*16
     if alongZ then fx,fz=ax*16+acrossC,az*16+alongC else fx,fz=ax*16+alongC,az*16+acrossC end
     local kind=(n>=4)and'grand'or'single'
     local R=even and 13 or 14
     local F={x=fx,y=hh,z=fz,kind=kind,R=R,plaza=kind=='grand'and R+3.5 or 7.9,seed=cx*13+cy*7}
     L.fountains[#L.fountains+1]=F
    end
   end
   -- the aisle (one quad per strip, emitted from the strip's first centre cell)
   if n>=3 and onCenter and j==0 and i==c0 then
    local w=even and 7 or 5.5
    local acrossC=(even and (c0+c1+1)/2 or (c0+.5))*16
    if alongZ then
     L.aisles[#L.aisles+1]={x0=ax*16+acrossC-w/2,x1=ax*16+acrossC+w/2,z0=az*16+1,z1=(bz+1)*16-1,y=hh}
    else
     L.aisles[#L.aisles+1]={x0=ax*16+1,x1=(bx+1)*16-1,z0=az*16+acrossC-w/2,z1=az*16+acrossC+w/2,y=hh}
    end
   end
   local kind
   if inFountain then kind=nil
   elseif n==1 then kind=(j%2==0)and'cypress'or'bed'
   elseif n==2 then kind=(j%3==0)and'cypress'or'bed'
   elseif onCenter then
    if (nearF==2 or j==0 or j==len-1)and not even then kind='urn'end
   elseif i==0 or i==n-1 then
    if n<=4 then kind=(j%2==0)and'cypress'or'bed'
    else kind=(j%2==0)and'cypress'or'topiary'end
   else
    kind=(j%3==2)and'topiary'or'bed'
   end
   if kind then
    local jx,jz=0,0
    if kind=='topiary'then jx,jz=(rh(cx,cy,11)-.5)*1.6,(rh(cy,cx,13)-.5)*1.6 end
    if kind=='cypress'then jx,jz=(rh(cx,cy,11)-.5)*.8,(rh(cy,cx,13)-.5)*.8 end
    -- edge cypress stand toward the outside of the strip, framing the aisle
    if kind=='cypress'and n>=3 then
     local push=(i==0)and -3 or 3
     if alongZ then jx=jx+push else jz=jz+push end
    end
    L.garden[#L.garden+1]={x=cx*16+8+jx,z=cy*16+8+jz,y=hh,seed=cx*17+cy*29,kind=kind,
     palette=floor(rh(cx+ax,cy+az,17)*3)}
   end
  end
 end end
 -- parapet lanterns along the white wall-top runs, every third cell
 local eagleAt={}
 for _,eg in ipairs(L.eagles)do eagleAt[floor(eg.z/16)*GW+floor(eg.x/16)]=true end
 for cy=0,GH-1 do btick() for cx=0,GW-1 do
  local x,y=cx*2,cy*2
  if t(x,y)==46 and t(x+1,y)==47 and t(x,y+1)==46 and t(x+1,y+1)==47 and isMass(x,y)and isMass(x,y+1)
     and (cx+cy)%2==1 and not nearGate(cx,cy,1)then
   local clear=true
   for dy=-1,1 do for dx=-1,1 do if eagleAt[(cy+dy)*GW+cx+dx]then clear=false end end end
   if clear and not(L.hall and x*8>=L.hall.x0-16 and x*8<L.hall.x1+16 and y*8<L.hall.z1+16)then
    L.lamps[#L.lamps+1]={x=cx*16+8,z=cy*16+8,y=(H[K(x,y)]or 32)+2.6,seed=cx*5+cy*3}
   end
  end
 end end
 -- capped pillars (32/33 over 46/47) carry a lantern each
 for y=0,th-2,2 do btick() for x=0,tw-2,2 do
  if t(x,y)==32 and t(x+1,y)==33 and t(x,y+1)==46 and t(x+1,y+1)==47 and isMass(x,y)and isMass(x,y+1)
     and not nearGate(x/2,y/2,1)and not eagleAt[(y/2)*GW+x/2]then
   L.lamps[#L.lamps+1]={x=x*8+8,z=y*8+8,y=(H[K(x,y)]or 32)+2.6,seed=x*5+y*3}
  end
 end end
 -- flames the animated pass lights: obelisk braziers and the hall's bowls
 L.flames={}
 for _,g in ipairs(L.gates)do
  -- the coal bed sits at top+1.8+3.0-0.6
  for _,x in ipairs({g.L,g.R})do L.flames[#L.flames+1]={x=x,y=g.top+4.4,z=g.z,s=1.45}end
 end
 if L.hall then
  for _,b in ipairs(hallBowls(L.hall))do L.flames[#L.flames+1]={x=b[1],y=b[2]+7.8*b[4],z=b[3],s=1.25*b[4]}end
 end
 if L.gatehouse then
  -- the gatehouse towers' fire bowls (see gatehouse(): crown at th+2.6,
  -- coal bed 7.0 above it)
  local G=L.gatehouse;local mid=(G.x0+G.x1)/2;local W2=(G.x1-G.x0)/2
  for _,sx in ipairs({-1,1})do
   L.flames[#L.flames+1]={x=mid-sx*(W2-G.tw/2),y=G.th+2.6+7.2,z=G.z0+G.tw/2-1,s=1.9}
  end
 end
 -- flagpoles (the animated pass flies the banners) and night uplights
 L.flags,L.uplights={},{}
 if L.hall then
  local hl=L.hall;local at=hl.attic
  for _,fx in ipairs({hl.x0+12,hl.x1-12})do L.flags[#L.flags+1]={x=fx,y=hl.h+24,z=hl.z1-9,base=hl.h,len=13,h=8}end
  for _,fx in ipairs({at.x0+15,at.x1-15})do L.flags[#L.flags+1]={x=fx,y=at.h+1.9+24,z=at.z1-6,base=at.h+1.9,len=14,h=8.5}end
  for _,cx in ipairs({hl.x0+5,hl.x0+30,hl.x1-30,hl.x1-5})do
   L.uplights[#L.uplights+1]={x=cx,y=0,z=hl.z1+6.4,h=hl.h-22,r=4.2}
  end
 end
 if L.gatehouse then
  local G=L.gatehouse;local mid=(G.x0+G.x1)/2;local W2=(G.x1-G.x0)/2
  local a,b=mid-G.door1,mid-G.door0
  for _,xc in ipairs({a-6.5,b+6.5})do L.uplights[#L.uplights+1]={x=mid-xc,y=0,z=G.z0-2.5,h=44,r=3.6}end
  for _,sx in ipairs({-1,1})do
   L.uplights[#L.uplights+1]={x=mid-sx*(W2-G.tw/2),y=40,z=G.z0-3,h=G.th-40,r=7}
   L.flags[#L.flags+1]={x=mid-sx*30,y=G.h+22,z=G.z0+22,base=G.h,len=12,h=7.5}
  end
 end
 -- the red carpet: the straight statue avenue (Indigo, and Route 23's head)
 L.carpet=nil
 do
  local x0,x1
  if map.id=='INDIGO_PLATEAU'then x0,x1=18,21 elseif map.id=='ROUTE_23'then x0,x1=18,21 end
  if x0 then
   local y0,y1
   for y=0,th-1 do
    local ok=true
    for x=x0,x1 do if cls[K(x,y)]~='floor'then ok=false end end
    -- the avenue is flanked by statues on both sides
    local flanked=cls[K(x0-1,y)]=='statue'and cls[K(x1+1,y)]=='statue'
    if ok and flanked then y0=y0 or y;y1=y elseif y0 and y>y1+1 then break end
   end
   if y0 then
    if map.id=='ROUTE_23'then y0=0 end
    if map.id=='INDIGO_PLATEAU'then y1=th-1 end
    L.carpet={x0=x0*8+1,x1=(x1+1)*8-1,z0=y0*8,z1=(y1+1)*8}
   end
  end
 end
 return L
end

------------------------------------------------------------------ build
local function floorKind(L,t,x,y)
 local v=t(x,y)
 if v~=44 then return 'lgPaveLight'end
 -- a 44 in a checker reads as dark marble; a solid 44 field is meadow.
 -- TEST168: it takes two pale neighbours to be checker -- a lawn's edge row
 -- touching a checker below no longer alternates lawn/marble (the comb).
 local n=0
 for _,d in ipairs({{1,0},{-1,0},{0,1},{0,-1}})do
  local w=t(x+d[1],y+d[2]);if w==35 or w==45 then n=n+1 end
 end
 return n>=2 and 'lgPaveDark' or 'lgLawn'
end

function M.plan(map,S)
 local key=function(x,y)return(y+64)*4096+x+64 end
 local tileAt=function(x,y)return S.tileAt[key(x,y)]end
 local claimed=function(x,y)return S.skip[key(x,y)]and true or false end
 local walk=function(cx,cy)local ok,r=pcall(map.isWalkableCell,map,cx,cy);return ok and r or false end
 local water=function(cx,cy)if not map.isWaterCell then return false end;local ok,r=pcall(map.isWaterCell,map,cx,cy);return ok and r or false end
 return M.analyze(map,tileAt,claimed,walk,water)
end

-- A vertical face on one edge of the tile box (X0,Z0)-(X1,Z1), facing out.
local FACE_TONE={s=.92,n=.72,e=.86,w=.80}
local function vface(E,side,X0,Z0,X1,Z1,ya,yb,mat,tone)
 if yb-ya<.01 then return end
 local vs=E.vs;local t=(tone or 1)*FACE_TONE[side]
 local sh={vs(t,ya),vs(t,ya),vs(t,yb),vs(t,yb)}
 if side=='s'then E.quad({X0,ya,Z1},{X1,ya,Z1},{X1,yb,Z1},{X0,yb,Z1},mat,sh)
 elseif side=='n'then E.quad({X1,ya,Z0},{X0,ya,Z0},{X0,yb,Z0},{X1,yb,Z0},mat,sh)
 elseif side=='e'then E.quad({X1,ya,Z1},{X1,ya,Z0},{X1,yb,Z0},{X1,yb,Z1},mat,sh)
 else E.quad({X0,ya,Z0},{X0,ya,Z1},{X0,yb,Z1},{X0,yb,Z0},mat,sh)end
end

-- A marble balustrade along one edge of a tile: plinth, turned balusters,
-- handrail. Shadowless detail.
local function balustrade(E,side,X0,Z0,X1,Z1)
 E.decor(function()
  local along=(side=='n'or side=='s')
  local a0,a1=along and X0 or Z0,along and X1 or Z1
  local c=(side=='s'and Z1)or(side=='n'and Z0)or(side=='e'and X1)or X0
  local inward=(side=='s'or side=='e')and -1 or 1
  local mid=c+inward*.4
  local function bx(u0,y0,u1,y1,half,mat,t)
   if along then E.box(u0,y0,mid-half,u1,y1,mid+half,mat,t)
   else E.box(mid-half,y0,u0,mid+half,y1,u1,mat,t)end
  end
  bx(a0,0,a1,1.0,1.0,'lgMarble',1)
  bx(a0,4.6,a1,5.5,1.05,'lgMarble',1)
  for _,f in ipairs({.25,.75})do
   local u=a0+(a1-a0)*f
   local Lm=along and model(E,u,1.0,mid,0,1)or model(E,mid,1.0,u,0,1)
   Lm.frustum(0,0,0,.62,1.2,.42,6,'lgMarble')
   Lm.frustum(0,1.2,0,.42,2.4,.7,6,'lgMarble')
   Lm.frustum(0,2.4,0,.7,3.6,.38,6,'lgMarble')
  end
 end)
end


-- THE GATEHOUSE: the Route 22 gate's roof at Route 23's south end becomes a
-- marble gatehouse facing up the badge road. Built in a local frame turned
-- to face north (local +z = world north, front plane local z=0), so the
-- facade code reads like every south-facing facade here.
local function gatehouse(E,G)
 local mid=(G.x0+G.x1)/2
 local W2=(G.x1-G.x0)/2;local D=G.z1-G.z0;local H=G.h
 local Lm=model(E,mid,0,G.z0,pi,1,1.22)    -- the north front sits in shade
 local Ls=model(E,mid,0,G.z0,pi,1,1.0)
 local a,b=mid-G.door1,mid-G.door0          -- door span, local x
 local dh=25
 local TW,TH=G.tw,G.th                      -- tower width and height
 local function F(x0,y0,x1,y1,z,mat,t,glow)Lm.quad({x0,y0,z},{x1,y0,z},{x1,y1,z},{x0,y1,z},mat,t,glow)end
 -- body: roof, flanks, back
 Ls.quad({-W2,H,-D},{W2,H,-D},{W2,H,0},{-W2,H,0},'lgMarble',1)
 Ls.quad({-W2,0,-D},{-W2,0,0},{-W2,H,0},{-W2,H,-D},'lgAshlar',1)   -- local west flank
 Ls.quad({W2,0,0},{W2,0,-D},{W2,H,-D},{W2,H,0},'lgAshlar',1)       -- local east flank
 Ls.quad({W2,0,-D},{-W2,0,-D},{-W2,H,-D},{W2,H,-D},'lgAshlar',1)   -- back (Route 22 side)
 -- front wall around the portal
 F(-W2,0,a,H,0,'lgAshlar')
 F(b,0,W2,H,0,'lgAshlar')
 F(a,dh+3.4,b,H,0,'lgAshlar')
 Lm.decor(function()
  doorway(Lm,a,b,0,dh,true)
  -- plinth and gold fillet either side of the portal
  for _,r in ipairs({{-W2,a-.5},{b+.5,W2}})do
   Lm.box(r[1],0,-.2,r[2],5,.9,'lgVerde',1,{bottom=true,n=true})
   Lm.box(r[1],5,-.2,r[2],5.7,1.05,'lgGold',1,{n=true})
  end
  -- fluted pilasters flanking the portal, lanterns between
  for _,px in ipairs({a-10,b+3})do
   Lm.box(px-.5,0,-.2,px+7.5,6.2,1.5,'lgVerde',1,{bottom=true,n=true})
   Lm.box(px,6.2,-.2,px+7,7.0,1.3,'lgGold',1,{bottom=true,n=true})
   Lm.box(px+.5,7.0,-.2,px+6.5,44,1.0,'lgFluteD',1,{bottom=true,top=true,n=true})
   Lm.box(px,44,-.2,px+7,45.4,1.3,'lgGold',1,{n=true})
   Lm.box(px-.5,45.4,-.2,px+7.5,47,1.6,'lgGold',.94,{n=true})
   local sx=px+3.5
   Lm.box(sx-1.0,17.2,1.0,sx+1.0,17.8,2.4,'lgGold',1,{n=true})
   Lm.box(sx-.85,17.8,1.2,sx+.85,21.2,2.2,'lgGold',1,{n=true,bottom=true,top=true},true)
   Lm.box(sx-1.1,21.2,1.0,sx+1.1,21.9,2.5,'lgGold',1,{n=true})
  end
  -- the arch over the portal: crimson tympanum with a gold sunburst,
  -- a marble archivolt and a gilded keystone
  local cx,cy=(a+b)/2,dh+3.4
  local ri,ro=(b-a)/2+1.2,(b-a)/2+4.2
  local N=16
  for i=0,N-1 do
   local a0,a1=i/N*pi,(i+1)/N*pi
   local c0,s0,c1,s1=cos(a0),sin(a0),cos(a1),sin(a1)
   Lm.quad({cx,cy,.06},{cx+c0*ri,cy+s0*ri,.06},{cx+c1*ri,cy+s1*ri,.06},{cx,cy,.06},'lgCrimson',.95)
   Lm.quad({cx+c1*ri,cy+s1*ri,1.1},{cx+c0*ri,cy+s0*ri,1.1},{cx+c0*ro,cy+s0*ro,1.1},{cx+c1*ro,cy+s1*ro,1.1},'lgMarble',1)
   Lm.quad({cx+c0*ri,cy+s0*ri,1.1},{cx+c1*ri,cy+s1*ri,1.1},{cx+c1*ri,cy+s1*ri,-.2},{cx+c0*ri,cy+s0*ri,-.2},'lgMarble',.8)
   Lm.quad({cx+c1*ro,cy+s1*ro,1.1},{cx+c0*ro,cy+s0*ro,1.1},{cx+c0*ro,cy+s0*ro,-.2},{cx+c1*ro,cy+s1*ro,-.2},'lgMarble',1)
   Lm.quad({cx+c1*(ri+.3),cy+s1*(ri+.3),1.16},{cx+c0*(ri+.3),cy+s0*(ri+.3),1.16},{cx+c0*(ri+.9),cy+s0*(ri+.9),1.16},{cx+c1*(ri+.9),cy+s1*(ri+.9),1.16},'lgGold',1)
  end
  for i=0,10 do
   local aa=(i+.5)/11*pi;local w=.07
   local r0,r1=3.2,ri-1.4
   Lm.quad({cx+cos(aa-w)*r0,cy+sin(aa-w)*r0,.12},{cx+cos(aa)*r1,cy+sin(aa)*r1,.12},{cx+cos(aa+w)*r0,cy+sin(aa+w)*r0,.12},{cx+cos(aa-w)*r0,cy+sin(aa-w)*r0,.12},'lgGold',1)
  end
  for i=0,11 do
   local a0,a1=i/12*pi,(i+1)/12*pi
   Lm.quad({cx,cy,.16},{cx+cos(a0)*2.6,cy+sin(a0)*2.6,.16},{cx+cos(a1)*2.6,cy+sin(a1)*2.6,.16},{cx,cy,.16},'lgGold',1)
  end
  Lm.box(cx-2.2,cy+ri-.5,-.2,cx+2.2,cy+ro+2.2,1.5,'lgMarble',1,{n=true})
  Lm.box(cx-1.4,cy+ri+.3,1.5,cx+1.4,cy+ro+1.4,1.75,'lgGold',1,{n=true})
  -- entablature across the whole front: architrave, crimson frieze with the
  -- gilded inscription, gold dentils, cornice
  local fy0,fy1=H-11.2,H-3.6
  Lm.box(-W2,fy0-1.0,-.2,W2,fy0,.75,'lgGold',1,{n=true})
  Lm.box(-W2,fy0,-.2,W2,fy1,.6,'lgCrimson',1,{n=true})
  inscription(Lm,'INDIGO PLATEAU',0,fy0+1.2,.6,1.2,'lgGold',2*W2-2*TW-28)
  for _,sx in ipairs({-1,1})do
   local lx=sx*(W2-TW-10)
   Lm.quad({lx,fy0+1.0,.66},{lx+2.2*sx,(fy0+fy1)/2,.66},{lx,fy1-1.0,.66},{lx-2.2*sx,(fy0+fy1)/2,.66},'lgGold',1)
  end
  local dx=-W2+1
  while dx<W2-1 do Lm.quad({dx,fy1+.15,.66},{dx+1.2,fy1+.15,.66},{dx+1.2,fy1+1.2,.66},{dx,fy1+1.2,.66},'lgGold',.95);dx=dx+3.2 end
  Lm.box(-W2-.6,fy1+1.4,-.2,W2+.6,H-.6,1.6,'lgMarble',1,{n=true})
  Lm.box(-W2-.6,H-.6,-.2,W2+.6,H-.1,1.8,'lgGold',1,{n=true})
  Lm.box(-W2-.3,H-.1,-.2,W2+.3,H+.4,1.3,'lgMarble',1,{n=true})
  -- roof balustrade between the towers
  local ba0,ba1=-W2+TW,W2-TW
  Lm.box(ba0,H+.4,-1.6,ba1,H+1.3,.2,'lgMarble',1,{})
  Lm.box(ba0,H+5.2,-1.7,ba1,H+6.1,.3,'lgMarble',1,{})
  local bx=ba0+2
  while bx<ba1-1 do
   local Lb=model(E,mid-bx,H+1.3,G.z0+.7,0,1)
   Lb.frustum(0,0,0,.6,1.2,.4,6,'lgMarble')
   Lb.frustum(0,1.2,0,.4,2.6,.68,6,'lgMarble')
   Lb.frustum(0,2.6,0,.68,3.9,.36,6,'lgMarble')
   bx=bx+3.6
  end
  -- long banners hanging from the cornice, both sides of the portal
  for _,sx in ipairs({-1,1})do
   local lx=sx*(W2-TW-24)
   local top,bot=fy0-1.2,fy0-15
   Lm.box(lx-5.0,top,.6,lx+5.0,top+.8,1.6,'lgGold',1,{})
   Lm.quad({lx-4.2,bot,1.25},{lx+4.2,bot,1.25},{lx+4.2,top,1.25},{lx-4.2,top,1.25},'lgCrimson',.95)
   Lm.quad({lx-4.2,bot,1.25},{lx,bot-3.6,1.25},{lx+4.2,bot,1.25},{lx-4.2,bot,1.25},'lgCrimson',.95)
   Lm.box(lx-4.2,bot,1.25,lx-3.7,top,1.45,'lgGold',1,{})
   Lm.box(lx+3.7,bot,1.25,lx+4.2,top,1.45,'lgGold',1,{})
   Lm.quad({lx,bot+2.2,1.32},{lx+2.4,bot+6.0,1.32},{lx,bot+9.8,1.32},{lx-2.4,bot+6.0,1.32},'lgGold',1)
  end
 end)
 -- the corner towers, each crowned by an open fire bowl
 for _,sx in ipairs({-1,1})do
  local x0,x1=sx<0 and -W2 or W2-TW,sx<0 and -W2+TW or W2
  local z0,z1=-TW,2
  Lm.box(x0,0,z0,x1,TH,z1,'lgAshlar',1,{bottom=true})
  Lm.decor(function()
   Lm.box(x0-.4,0,z1-.2,x1+.4,6,z1+.8,'lgVerde',1,{bottom=true,n=true})
   Lm.box(x0-.4,6,z1-.2,x1+.4,6.7,z1+.95,'lgGold',1,{n=true})
   -- a tall crimson panel above the gate walls, gilded frame and star
   local p0,p1,q0,q1=x0+4.5,x1-4.5,H-8,TH-6
   F(p0,q0,p1,q1,z1+.12,'lgCrimson',.95)
   F(p0-.6,q0-.6,p1+.6,q0,z1+.24,'lgGold',.95);F(p0-.6,q1,p1+.6,q1+.6,z1+.24,'lgGold',.95)
   F(p0-.6,q0,p0,q1,z1+.24,'lgGold',.95);F(p1,q0,p1+.6,q1,z1+.24,'lgGold',.95)
   local cx2,cy2=(x0+x1)/2,(q0+q1)/2
   for i=0,9 do
    local a0,a1=i/10*pi*2+pi/2,(i+1)/10*pi*2+pi/2
    local r0=i%2==0 and 4.4 or 1.9;local r1=(i+1)%2==0 and 4.4 or 1.9
    Lm.quad({cx2,cy2,z1+.3},{cx2+cos(a0)*r0,cy2+sin(a0)*r0,z1+.3},{cx2+cos(a1)*r1,cy2+sin(a1)*r1,z1+.3},{cx2,cy2,z1+.3},'lgGold',1)
   end
   -- a lantern on the tower face, lit after dark
   local lx=(x0+x1)/2
   Lm.box(lx-1.2,H-14.6,z1,lx+1.2,H-14,z1+2.0,'lgGold',1,{n=true})
   Lm.box(lx-1.0,H-14,z1+.4,lx+1.0,H-10.4,z1+1.9,'lgGold',1,{n=true,bottom=true,top=true},true)
   Lm.box(lx-1.3,H-10.4,z1,lx+1.3,H-9.7,z1+2.1,'lgGold',1,{n=true})
   -- tower cornice, gold line, stepped crown
   Lm.box(x0-.8,TH-2.6,z0-.8,x1+.8,TH,z1+.8,'lgMarble',1,{})
   Lm.box(x0-1.0,TH,z0-1.0,x1+1.0,TH+.5,z1+1.0,'lgGold',1,{})
   Lm.box(x0+2.5,TH+.5,z0+2.5,x1-2.5,TH+2.6,z1-2.5,'lgMarble',1,{})
  end)
  local cxl,czl=(x0+x1)/2,(z0+z1)/2
  local Lt=model(E,mid-cxl,TH+2.6,G.z0-czl,0,1)
  Lt.box(-5.6,0,-5.6,5.6,1.6,5.6,'lgVerde')
  Lt.frustum(0,1.6,0,4.4,4.0,3.0,8,'lgGold')
  fireBowl(Lt,4.0,3.0,6.2,3.6)
 end
 -- flanks and back: plinth, panels, frieze and cornice carried round
 Ls.decor(function()
  for _,sx in ipairs({-1,1})do
   local X=sx*W2
   local function SQ(z0,y0,z1,y1,off,mat,t)
    if sx<0 then Ls.quad({X-off,y0,z0},{X-off,y0,z1},{X-off,y1,z1},{X-off,y1,z0},mat,t)
    else Ls.quad({X+off,y0,z1},{X+off,y0,z0},{X+off,y1,z0},{X+off,y1,z1},mat,t)end
   end
   SQ(-D,0,0,5,.8,'lgVerde',1)
   SQ(-D,5,0,5.7,.95,'lgGold',1)
   SQ(-D,H-11.2,0,H-3.6,.55,'lgCrimson',1)
   SQ(-D,H-3.6,0,H,1.2,'lgMarble',1)
   for _,zc in ipairs({-D*.30,-D*.72})do
    local z0,z1,y0,y1=zc-9,zc+9,10,H-16
    SQ(z0,y0,z1,y1,.12,'lgCrimson',.95)
    SQ(z0-.6,y0-.6,z1+.6,y0,.24,'lgGold',.95);SQ(z0-.6,y1,z1+.6,y1+.6,.24,'lgGold',.95)
    SQ(z0-.6,y0,z0,y1,.24,'lgGold',.95);SQ(z1,y0,z1+.6,y1,.24,'lgGold',.95)
   end
  end
  Ls.quad({W2,H-3.6,-D-1.2},{-W2,H-3.6,-D-1.2},{-W2,H,-D-1.2},{W2,H,-D-1.2},'lgMarble',1)
  Ls.quad({W2,0,-D-.8},{-W2,0,-D-.8},{-W2,5,-D-.8},{W2,5,-D-.8},'lgVerde',1)
 end)
end


-- Forest-floor trees for the ring below the plateau (lighter meshes: there
-- are a thousand of them).
local function cypressLow(L,seed,h)
 h=h or 26
 L.frustum(0,0,0,.85,h*.82,.18,5,'forestBark')
 for j=1,5 do
  local t=(j-1)/5;local y=h*(.13+t*.75)
  local r=(h*.135)*(1-t*.88)*(.87+.22*rh(seed,j,6))
  local off=(rh(seed,j,9)-.5)*r*.35
  L.frustum(off,y,off*.5,r*.64,y+h*.10,r,5,'lgFoliage',false,seed+j*.55)
  L.frustum(off,y+h*.10,off*.5,r,y+h*.29,r*.12,5,'lgFoliage',false,seed+j*.55)
 end
end

local function stonePine(L,seed,h)
 local lean=(rh(seed,1,61)-.5)*2.4
 local tx,tz=lean,lean*.4
 for i=0,4 do
  local a0,a1=i/5*pi*2,(i+1)/5*pi*2
  L.quad({cos(a0)*1.3,0,sin(a0)*1.3},{cos(a1)*1.3,0,sin(a1)*1.3},
   {tx+cos(a1)*.7,h*.66,tz+sin(a1)*.7},{tx+cos(a0)*.7,h*.66,tz+sin(a0)*.7},'forestBark')
 end
 for j=1,3 do
  local a=j*2.399+seed
  L.sphere(tx+cos(a)*4.0,h*.73+(j%2)*1.6,tz+sin(a)*4.0,6.0,3.6,5.6,'lgFoliage',7,4,seed+j*7)
 end
end
local function roundLow(L,seed,h)
 L.frustum(0,0,0,1.4,h*.55,.65,5,'forestBark')
 for j=1,3 do
  local a=j*2.399+seed;local spread=h*.21
  L.sphere(cos(a)*spread,h*(.54+j*.045),sin(a)*spread,h*.25,h*.23,h*.26,'lgFoliage',7,4,seed+j*7)
 end
end

-- THE RING: the plateau's open edges drop to a forest floor. Lawn fading
-- toward the world fill, a deep wood of cypress, stone pine and broadleaf,
-- denser with distance so the edge of the world reads as forest.
local function ringScape(E,L)
 local R=L.ring;if not R then return end
 local tw,th=L.tw,L.th
 local function dist(tx,ty)
  local dx=tx<0 and -tx or(tx>=tw and tx-tw+1 or 0)
  local dy=ty<0 and -ty or(ty>=th and ty-th+1 or 0)
  return max(dx,dy)
 end
 local function sh(tx,ty)return .96-.14*min(1,dist(tx,ty)/RING_T)end
 -- TEST169: the ledge is a wild meadow now (lgMeadow), not the forest floor
 for _,cl in ipairs(R.cells)do
  local cx,cy=cl[1],cl[2]
  local X0,Z0=cx*16,cy*16;local X1,Z1=X0+16,Z0+16
  local tx0,ty0=cx*2,cy*2
  E.quad({X0,RING_Y,Z0},{X1,RING_Y,Z0},{X1,RING_Y,Z1},{X0,RING_Y,Z1},'lgMeadow',
   {sh(tx0,ty0),sh(tx0+2,ty0),sh(tx0+2,ty0+2),sh(tx0,ty0+2)})
 end
 local F=Flora()
 local nT,nU=0,0
 for _,cl in ipairs(R.cells)do
  local cx,cy=cl[1],cl[2]
  local d=max(1,floor(dist(cx*2,cy*2)/2+.5))
  local dens=d<=1 and .52 or(d>=5 and .34 or .46)
  local seed=cx*131+cy*71
  -- TEST167: no crown may lean over a neighbour's body from the corners
  local corner=(cy<0 or cy*2>=th)and(cx*16+16>-14 and cx*16<tw*8+14)
  local tree=false
  local lod=d>=2 and 2 or 1
  if not corner and rh(cx,cy,41)<dens then
   local x=cx*16+8+(rh(cx,cy,43)-.5)*8
   local z=cy*16+8+(rh(cy,cx,47)-.5)*8
   local k=rh(cx,cy,53)
   local yaw=rh(cx,cy,59)*pi*2
   -- crowns may reach toward the walls but never over the walk
   local ex=max(-x,x-tw*8,0);local ez=max(-z,z-th*8,0)
   local de=(ex>0 and ez>0)and sqrt(ex*ex+ez*ez)or max(ex,ez)
   local maxR=max(6,de+1)
   -- TEST169: the Roman wood. Cypress spires and umbrella pines along the
   -- foot of the walls, broadleaf filling in further out.
   local pC,pP=d<=1 and .44 or(d<=3 and .26 or .18),d<=1 and .38 or .40
   if k<pC then F.cypress(E,x,RING_Y,z,(d<=2 and 34 or 30)+rh(cx,cy,67)*16,seed,yaw,d>=3 and 2 or 1)
   elseif k<pC+pP then F.stonePine(E,x,RING_Y,z,28+rh(cx,cy,71)*9,seed,yaw,lod,maxR)
   else F.broadleaf(E,x,RING_Y,z,24+rh(cx,cy,73)*9,seed,yaw,lod,maxR)end
   tree=true;nT=nT+1
  end
  -- the understory: shrubs (some in flower), long-grass tussocks, ferns
  -- in the shade, the odd mossy stone
  if not corner then
   local u=rh(cx,cy,81)
   if not tree and u<.24 then
    local x=cx*16+8+(rh(cx,cy,83)-.5)*9;local z=cy*16+8+(rh(cy,cx,85)-.5)*9
    F.shrub(E,x,RING_Y,z,2.6+rh(cx,cy,87)*1.8,seed+3,rh(cx,cy,89)<.28);nU=nU+1
   elseif not tree and u<.29 then
    F.stone(E,cx*16+8+(rh(cx,cy,91)-.5)*8,RING_Y,cy*16+8+(rh(cy,cx,93)-.5)*8,2.2+rh(cx,cy,95)*2,seed+9);nU=nU+1
   end
   local nt=(d<=3 and rh(cx,cy,97)<.55)and 1 or 0
   if d<=2 and not tree and rh(cx,cy,99)<.45 then nt=nt+1 end
   for i=1,nt do
    local x=cx*16+2+rh(cx+i,cy,101)*12;local z=cy*16+2+rh(cy,cx+i,103)*12
    F.tussock(E,x,RING_Y,z,2.4+rh(cx,cy+i,105)*1.8,seed+i*17);nU=nU+1
   end
   if tree and rh(cx,cy,107)<.40 then
    local a=rh(cx,cy,109)*pi*2
    F.fern(E,cx*16+8+cos(a)*5,RING_Y,cy*16+8+sin(a)*5,1.8+rh(cx,cy,111),seed+21);nU=nU+1
   end
  end
 end
 L.floraStats={trees=nT,under=nU}
 -- where the ring meets a lower-lying neighbour (Route 22), close the cut
 for _,w in ipairs(R.walls or{})do
  E.quad({w[2],RING_Y,w[3]},{w[1],RING_Y,w[3]},{w[1],0,w[3]},{w[2],0,w[3]},'lgGranite',{.6,.6,.72,.72})
 end
end

------------------------------------------------------------------ the gorge
-- TEST167: past the ring's forest ledge the plateau ends at a rocky lip and
-- falls away in cliffs to a deep wooded valley with a river, waterfalls
-- spilling off the cliffs into plunge pools, and a far bank that climbs back
-- to the horizon. One deterministic plan serves the builder (terrain, trees,
-- rocks) and LeagueRoad (river, falls, mist) alike.
local GZ={LIP=12,CLIFF=74,FLOOR=-150,BANK0=350,BANK1=540,STEP=32,FADE=420,WATER=-151.5}
M.GZ=GZ
local function smooth01(t)t=max(0,min(1,t));return t*t*(3-2*t)end
local function vnoise(x,z,sc,seed)
 local fx,fz=x*sc,z*sc;local ix,iz=floor(fx),floor(fz);local tx,tz=fx-ix,fz-iz
 tx=tx*tx*(3-2*tx);tz=tz*tz*(3-2*tz)
 local a,b=rh(ix,iz,seed),rh(ix+1,iz,seed);local c,d=rh(ix,iz+1,seed),rh(ix+1,iz+1,seed)
 local u=a+(b-a)*tx;local v=c+(d-c)*tx
 return u+(v-u)*tz
end
function M.gorgePlan(L,map)
 if L.gorge~=nil then return L.gorge or nil end
 local id=tostring((map and map.id)or L.id or'')
 if id~='ROUTE_23'and id~='INDIGO_PLATEAU'then L.gorge=false;return nil end
 local conn=(map and map.def and map.def.connections)or{}
 local open={n=not conn.north,s=not conn.south,w=not conn.west,e=not conn.east}
 local W,H=L.tw*8,L.th*8
 local Rw=RING_T*8
 local G={id=id,open=open,W=W,H=H,x0=-Rw,x1=W+Rw,k0=-1e9,falls={},rivers={},mist={},rocks={}}
 if id=='ROUTE_23'then
  -- the north end runs on past Indigo's sides; the south end meets Route 22
  G.zA,G.zB,G.fadeA,G.fadeB=-760,H,true,true
  G.ring0,G.ring1=-Rw,H
 else
  if open.n then G.k0=-Rw end
  G.zA=open.n and(-Rw-GZ.BANK1-32)or -760;G.zB=H+760
  G.fadeA,G.fadeB=not open.n,true
  G.ring0,G.ring1=-Rw,H+Rw
 end
 G.zA=floor(G.zA/32)*32;G.zB=floor(G.zB/32)*32
 function G.dist(x,z)
  local dx=max(G.x0-x,x-G.x1,0)
  local dz=max(G.k0-z,0)
  return sqrt(dx*dx+dz*dz)
 end
 function G.fade(z)
  local e=1
  if G.fadeA then e=e*smooth01((z-G.zA)/GZ.FADE)end
  if G.fadeB then e=e*smooth01((G.zB-z)/GZ.FADE)end
  return e
 end
 function G.riverD(x,z)return 205+70*(vnoise(x,z,1/380,7)-.5)end
 local function heightRaw(x,z)
  local d=G.dist(x,z)
  if d<=0 then return RING_Y,0 end
  local wob=(vnoise(x,z,1/90,3)-.5)*16*min(1,d/20)
  local dd=d+wob
  local h
  if dd<GZ.LIP then h=RING_Y-4*smooth01(dd/GZ.LIP)
  elseif dd<GZ.CLIFF then local t=(dd-GZ.LIP)/(GZ.CLIFF-GZ.LIP);h=RING_Y-4+(GZ.FLOOR-RING_Y+4)*(1-(1-t)^1.7)
   -- weathered ledges down the face
   h=h+sin(t*pi*4.5+vnoise(x,z,1/50,19)*3)*5*sin(t*pi)
  elseif dd<GZ.BANK0 then h=GZ.FLOOR
  else h=GZ.FLOOR+(-1.5-GZ.FLOOR)*smooth01((dd-GZ.BANK0)/(GZ.BANK1-GZ.BANK0))end
  local roll=(vnoise(x,z,1/140,5)-.5)*14*smooth01((dd-GZ.CLIFF)/40)*(1-smooth01((dd-GZ.BANK1+60)/60))
  if dd>GZ.CLIFF-10 then
   -- the river runs in a flat bed; the ground rolls away from it
   local q=abs(d-G.riverD(x,z))
   local k=smooth01((q-46)/50)
   h=GZ.FLOOR-3+(h+roll-(GZ.FLOOR-3))*k
  else h=h+roll end
  for _,f in ipairs(G.falls)do
   local pr=f.pool
   local qd=sqrt((x-pr.x)^2+(z-pr.z)^2)
   if qd<pr.r+12 then h=min(h,GZ.FLOOR-8+max(0,qd-pr.r)*.6)end
  end
  return h,dd
 end
 function G.height(x,z)
  local h,dd=heightRaw(x,z)
  return RING_Y+(h-RING_Y)*G.fade(z),dd
 end
 -- a point on the ring boundary and the outward direction, per side
 local function along(side,a)
  if side=='w'then return G.x0,a,-1,0 elseif side=='e'then return G.x1,a,1,0 end
  return a,G.k0,0,-1
 end
 -- waterfalls: where they spill, their path down the cliff, their pool
 local FALLS=id=='ROUTE_23'and{{'w',512},{'w',1504},{'e',992},{'e',1824}}
  or{{'n',96},{'n',224},{'e',128}}
 if not open.n then
  for i=#FALLS,1,-1 do if FALLS[i][1]=='n'then table.remove(FALLS,i)end end
 end
 for i,fd in ipairs(FALLS)do
  local side,a=fd[1],fd[2]
  if (side=='w'and open.w)or(side=='e'and open.e)or(side=='n'and open.n)then
   local px,pz,nx,nz=along(side,a)
   local pd=GZ.CLIFF+22
   G.falls[#G.falls+1]={side=side,a=a,nx=nx,nz=nz,ox=px,oz=pz,seed=i*7.3,
    pool={x=px+nx*pd,z=pz+nz*pd,r=24,y=GZ.FLOOR-4}}
  end
 end
 for _,f in ipairs(G.falls)do
  local pts={}
  for _,d in ipairs({4,9,14,20,27,34,42,50,58,66,74,86})do
   local x,z=f.ox+f.nx*d,f.oz+f.nz*d
   local h=G.height(x,z)
   pts[#pts+1]={x,(d<=4)and RING_Y-.8 or h+1.6,z}
  end
  f.pts=pts;f.w=12
  G.rocks[#G.rocks+1]={x=f.ox+f.nx*(GZ.LIP-2)-f.nz*11,z=f.oz+f.nz*(GZ.LIP-2)+f.nx*11,s=1.25}
  G.rocks[#G.rocks+1]={x=f.ox+f.nx*(GZ.LIP-2)+f.nz*11,z=f.oz+f.nz*(GZ.LIP-2)-f.nx*11,s=1.1}
  G.mist[#G.mist+1]={x=f.pool.x,y=f.pool.y+10,z=f.pool.z,r=46,a=.10}
 end
 -- the river: traced along the valley floor through every open side
 local function solve(px,pz,nx,nz)
  local lo,hi=GZ.CLIFF+30,GZ.BANK0-30
  for _=1,18 do
   local m=(lo+hi)/2
   if m-G.riverD(px+nx*m,pz+nz*m)<0 then lo=m else hi=m end
  end
  local m=(lo+hi)/2
  return px+nx*m,pz+nz*m
 end
 local function trace()
  local pts={}
  local function add(px,pz,nx,nz)local x,z=solve(px,pz,nx,nz);pts[#pts+1]={x,GZ.WATER,z}end
  local zS,zN=G.zB-(G.fadeB and GZ.FADE or 0)-16,max(G.zA+(G.fadeA and GZ.FADE or 0)+16,G.k0)
  return pts,add,zS,zN
 end
 if id=='ROUTE_23'then
  for _,side in ipairs({'w','e'})do
   if open[side]then
    local pts,add,zS,zN=trace()
    for z=zN,zS,24 do local px,pz,nx,nz=along(side,z);add(px,pz,nx,nz)end
    G.rivers[#G.rivers+1]=pts
   end
  end
 else
  local pts,add,zS=trace()
  if open.w then for z=zS,G.k0,-24 do add(G.x0,z,-1,0)end end
  if open.n then
   if open.w then for k=1,7 do local t=k/8*pi/2;add(G.x0,G.k0,-cos(t),-sin(t))end end
   for x=G.x0,G.x1,24 do add(x,G.k0,0,-1)end
   if open.e then for k=1,7 do local t=k/8*pi/2;add(G.x1,G.k0,sin(t),-cos(t))end end
  end
  if open.e then for z=G.k0,zS,24 do add(G.x1,z,1,0)end end
  G.rivers[#G.rivers+1]=pts
 end
 for _,pts in ipairs(G.rivers)do
  for k=1,#pts,14 do local p=pts[k];G.mist[#G.mist+1]={x=p[1],y=GZ.FLOOR+16,z=p[3],r=110,a=.06}end
 end
 L.gorge=G
 return G
end

-- Valley trees: layered branch whorls and overlapping broadleaf crowns.
local function fir(L,seed,h)
 h=h or 26
 L.frustum(0,0,0,.85,h*.82,.18,5,'forestBark')
 for j=1,5 do
  local t=(j-1)/5;local y=h*(.13+t*.75)
  local r=(h* .20)*(1-t*.88)*(.87+.22*rh(seed,j,6))
  local off=(rh(seed,j,9)-.5)*r*.35
  L.frustum(off,y,off*.5,r*.64,y+h*.10,r,6,'lgFoliage',false,seed+j*.55)
  L.frustum(off,y+h*.10,off*.5,r,y+h*.29,r*.12,6,'lgFoliage',false,seed+j*.55)
 end
end

local function broadleaf(L,seed,h)
 L.frustum(0,0,0,1.3,h*.56,.62,5,'forestBark')
 for j=1,3 do
  local angle=j*2.399+seed;local spread=h*.15
  local x,z=cos(angle)*spread,sin(angle)*spread
  L.sphere(x,h*(.57+j*.065),z,h*.25,h*.22,h*.25,'lgFoliage',6,4,seed+j*11)
 end
end

local GD={0,4,9,14,20,27,34,42,50,58,66,74,86,100,118,140,160,180,200,220,240,260,285,315,350,395,445,495,540}
local function gorgeScape(E,L)
 local G=L.gorge;if not G then return end
 local W,H=G.W,G.H
 local AS=32
 local function shadeAt(x,z,h)
  local e=3
  local hx=G.height(x+e,z)-G.height(x-e,z);local hz=G.height(x,z+e)-G.height(x,z-e)
  local nx,ny,nz=-hx,2*e,-hz
  local l=sqrt(nx*nx+ny*ny+nz*nz);nx,ny,nz=nx/l,ny/l,nz/l
  local lit=max(0,nx*-.35+ny*.85+nz*.40)
  local depth=.66+.34*max(0,min(1,(h-GZ.FLOOR)/(RING_Y-GZ.FLOOR)))^.8
  return max(.34,min(1.05,(.46+.58*lit)*depth))
 end
 local function matFor(p)
  local hs={p[1][2],p[2][2],p[3][2],p[4][2]}
  local dx=sqrt((p[1][1]-p[3][1])^2+(p[1][3]-p[3][3])^2)
  local slope=(max(hs[1],hs[2],hs[3],hs[4])-min(hs[1],hs[2],hs[3],hs[4]))/max(4,dx*.75)
  local cx,cz=(p[1][1]+p[3][1])/2,(p[1][3]+p[3][3])/2
  local cd=G.dist(cx,cz)
  if cd<GZ.CLIFF+8 then
   if slope>.22 then return'lgRock'end
  elseif slope>2.2 then return'lgRock'end
  return'lgMeadow'
 end
 local function quad4(p)
  local sh={}
  for i=1,4 do sh[i]=shadeAt(p[i][1],p[i][3],p[i][2])end
  E.quad(p[1],p[2],p[3],p[4],matFor(p),sh)
 end
 local function V(x,z)return{x,G.height(x,z),z}end
 -- a strip of rows along a side: point(a,d) gives the vertex, rows step AS
 local function strip(a0,a1,point)
  local a=a0
  while a<a1-.01 do
   local b=min(a1,a+AS)
   for i=1,#GD-1 do
    local p1,p2=point(a,GD[i]),point(b,GD[i])
    local p3,p4=point(b,GD[i+1]),point(a,GD[i+1])
    quad4({V(p1[1],p1[2]),V(p2[1],p2[2]),V(p3[1],p3[2]),V(p4[1],p4[2])})
   end
   a=b
  end
 end
 local zS=(G.k0>-1e8)and G.k0 or G.zA
 if G.open.w then strip(zS,G.zB,function(a,d)return{G.x0-d,a}end)end
 if G.open.e then strip(zS,G.zB,function(a,d)return{G.x1+d,a}end)end
 if G.k0>-1e8 then
  strip(G.x0,G.x1,function(a,d)return{a,G.k0-d}end)
  local function corner(cx,th0)
   strip(0,1,function(a,d)local t=th0+a*pi/2;return{cx+cos(t)*d,G.k0+sin(t)*d}end)
  end
  -- the corner sweeps in rows of a sixth of a right angle
  AS=1/6
  if G.open.w then corner(G.x0,pi)end
  if G.open.e then corner(G.x1,pi*1.5)end
  AS=32
 end
 -- the ledge continued past this map's ring (beside the neighbour's sides)
 local function ledge(z0,z1)
  for _,side in ipairs({'w','e'})do
   if G.open[side]then
    local xa,xb=side=='w'and G.x0 or W,side=='w'and 0 or G.x1
    local z=z0
    while z<z1-.01 do
     local zb=min(z1,z+32)
     local x=xa
     while x<xb-.01 do
      local xe=min(xb,x+32)
      local ax0,ax1=x,xe
      if ax1==0 then ax1=-.5 end
      if ax0==W then ax0=W+.5 end
      quad4({{ax0,RING_Y,z},{ax1,RING_Y,z},{ax1,RING_Y,zb},{ax0,RING_Y,zb}})
      x=xe
     end
     z=zb
    end
   end
  end
 end
 if G.zA<G.ring0 and G.k0<-1e8 then ledge(G.zA,G.ring0)end
 if G.zB>G.ring1 then ledge(G.ring1,G.zB)end
 -- end walls where the gorge stops short (Route 22, the far ends)
 local function endWall(z,face)
  for _,side in ipairs({'w','e'})do
   if G.open[side]then
    local xs={}
    for i=#GD,1,-1 do xs[#xs+1]=side=='w'and G.x0-GD[i] or G.x1+GD[#GD+1-i]end
    if not(G.id=='ROUTE_23'and face>0)then
     if side=='w'then xs[#xs+1]=-.5 else table.insert(xs,1,W+.5)end
    end
    for i=1,#xs-1 do
     local xa,xb=xs[i],xs[i+1]
     local ya,yb=G.height(xa,z),G.height(xb,z)
     if face<0 then E.quad({xb,yb,z},{xa,ya,z},{xa,-1,z},{xb,-1,z},'lgRock',.66)
     else E.quad({xa,ya,z},{xb,yb,z},{xb,-1,z},{xa,-1,z},'lgRock',.86)end
    end
   end
  end
 end
 if G.fadeA then endWall(G.zA,-1)end
 if G.fadeB then endWall(G.zB,1)end
 local xs=G.x0-GZ.BANK1-16
 local xe=G.x1+GZ.BANK1+16
 -- trees, rocks
 local T=34
 local nTrees,nRocks=0,0
 for z=G.zA+T/2,G.zB-T/2,T do
  for x=xs+T/2,xe,T do
   local jx=x+(rh(x,z,201)-.5)*T*.8;local jz=z+(rh(z,x,203)-.5)*T*.8
   local ok=not(jx>G.x0-2 and jx<G.x1+2 and jz>G.ring0-2 and jz<G.ring1+2)
   if ok and jx>-12 and jx<W+12 and not(G.k0>-1e8 and jz<G.k0-12)then ok=false end
   if ok then
    local d=G.dist(jx,jz)
    if d<=GZ.BANK1-10 then
     local h,dd=G.height(jx,jz)
     local e=G.fade(jz)
     local seed=floor(jx*3+jz*7)
     local r=rh(jx,jz,207)
     local q=abs(d-G.riverD(jx,jz))
     local pool=false
     for _,f in ipairs(G.falls)do if (jx-f.pool.x)^2+(jz-f.pool.z)^2<(f.pool.r+14)^2 then pool=true end end
     local dens,kind=0,nil
     if dd<=0 or d<=0 then dens,kind=.45,'ledge'
     elseif dd<GZ.LIP+6 then dens,kind=.14,'lip'
     elseif dd<GZ.CLIFF-6 then dens,kind=.03,'cliff'
     elseif dd<GZ.BANK0 then
      local grove=vnoise(jx,jz,1/260,11)
      dens,kind=(grove>.54 and .78 or(grove>.46 and .30 or .03)),'floor'
      if q<40 or pool then dens=0 end
     else dens,kind=(dd>GZ.BANK1-100 and .66 or .34),'bank'end
     if e<.6 then dens=dens*.4 end
     if r<dens then
      local yaw=rh(jx,jz,209)*pi*2
      local k=rh(jx,jz,211)
      -- TEST169: the new species, by distance: full detail on the ledges and
      -- the lip, lighter down the valley, lightest on the far bank
      local F=Flora()
      local yb=h-1
      if kind=='ledge'then
       if k<.42 then F.cypress(E,jx,yb,jz,40+k*40,seed,yaw,1)
       elseif k<.76 then F.stonePine(E,jx,yb,jz,32+k*10,seed,yaw,1)
       else F.broadleaf(E,jx,yb,jz,28+k*12,seed,yaw,1)end
      elseif kind=='lip'or kind=='cliff'then
       if k<.30 then F.cypress(E,jx,yb,jz,22+k*20,seed,yaw,2)
       else F.stonePine(E,jx,yb,jz,(.62+.2*k)*32,seed,yaw,2)end
      else
       local tall=kind=='bank'and 1.15 or 1.0
       local lod=(kind=='bank'or dd>GZ.CLIFF+120)and 3 or 2
       if k<.45 then F.fir(E,jx,yb,jz,(42+k*40)*tall,seed,yaw,lod)
       elseif k<.60 then F.cypress(E,jx,yb,jz,(40+k*30)*tall,seed,yaw,lod)
       elseif k<.70 and lod<3 then F.stonePine(E,jx,yb,jz,(34+k*10)*tall,seed,yaw,lod)
       else F.broadleaf(E,jx,yb,jz,(32+k*22)*tall,seed,yaw,lod)end
      end
      nTrees=nTrees+1;L.kindN=L.kindN or{};L.kindN[kind]=(L.kindN[kind]or 0)+1
     elseif (kind=='lip'and r>.55)or(kind=='floor'and r>.985)then
      local k=rh(jx,jz,213)
      boulder(model(E,jx,h-1.5,jz,0,1),seed,5+k*5,3.5+k*3,4.5+k*4)
      nRocks=nRocks+1
     elseif kind=='ledge'or kind=='lip'then
      -- TEST169: understory along the ledge and the lip
      local F=Flora()
      local u=rh(jx,jz,215)
      if u<.40 then F.shrub(E,jx,h-.6,jz,2.8+u*4,seed+5,u<.10)
      elseif u<.75 then F.tussock(E,jx,h-.4,jz,2.6+u*1.5,seed+7)end
     end
    end
   end
  end
 end
 -- a broken rocky rim along the lip, so the edge of the drop reads
 local function rimRock(px,pz,nx,nz,a)
  if rh(a,px+pz,303)>.55 then return end
  local d=5+rh(a,px,301)*7
  local x,z=px+nx*d,pz+nz*d
  if G.fade(z)<.75 then return end
  local h=G.height(x,z);local k=rh(a,pz,305)
  boulder(model(E,x,h-2.2,z,0,1),floor(a*3+px),6+k*6,4+k*4,5+k*5)
  nRocks=nRocks+1
 end
 local zS=(G.k0>-1e8)and G.k0 or G.zA
 for a=zS+24,G.zB-24,46 do
  if G.open.w then rimRock(G.x0,a,-1,0,a)end
  if G.open.e then rimRock(G.x1,a,1,0,a+7)end
 end
 if G.k0>-1e8 then for a=G.x0+23,G.x1-23,46 do rimRock(a,G.k0,0,-1,a+13)end end
 for _,rk in ipairs(G.rocks)do
  local h=G.height(rk.x,rk.z)
  boulder(model(E,rk.x,h-1.5,rk.z,0,rk.s),floor(rk.x+rk.z),7,5.5,6)
 end
 L.gorgeStats={trees=nTrees,rocks=nRocks+#G.rocks,falls=#G.falls,rivers=#G.rivers}
end

------------------------------------------------------------------ the night
-- TEST168: the League after dark. One deterministic plan (from the analysis
-- and the tile accessor) gives the builder its wall dressing -- pilasters,
-- lantern sconces and banners on the long granite terrace walls, lantern
-- posts along the gorge rim -- and gives LeagueRoad/LeagueNight every light
-- it paints: wall washes, ground pools, halos.
local function sideFrame(side)
 -- outward normal and yaw for a wall face on this side
 if side=='s'then return 0,1,0 elseif side=='n'then return 0,-1,pi
 elseif side=='e'then return 1,0,pi/2 else return -1,0,-pi/2 end
end
M.sideFrame=sideFrame
function M.nightPlan(L,t,open)
 if L.night then return L.night end
 open=open or(L.ring and L.ring.open)or{}
 local tw,th,K,cls,H=L.tw,L.th,L.K,L.cls,L.H
 local function c(x,y)if x<0 or y<0 or x>=tw or y>=th then return 'edge'end;return cls[K(x,y)]end
 local function h(x,y)return H[K(x,y)]or 0 end
 local function topH(x,y)local v=t(x,y);return h(x,y)+(PARAPET[v]and 2.6 or 0)end
 local function dropTo(x,y)
  local cc=c(x,y)
  if cc=='edge'then return nil end
  if cc=='mass'then return topH(x,y)end
  if cc=='gatehouse'then return 'none'end
  local v=t(x,y)
  if cc==nil and v~=nil and WATERISH[v]then return POOL_Y end
  if cc==nil and v==nil then return nil end
  if cc==nil and v~=69 and not(v==9 or v==10 or v==25 or v==26)then return 'none'end
  return 0
 end
 local P={walls={},sconces={},banners={},pilasters={},washes={},pools={},aqua={},halos={},rim={}}
 -- 1. granite wall runs (the faces the emitter builds in section 2)
 local runs={}
 local sides={{0,1,'s'},{0,-1,'n'},{1,0,'e'},{-1,0,'w'}}
 for y=0,th-1 do btick() for x=0,tw-1 do
  if c(x,y)=='mass'then
   local top=topH(x,y);local base=h(x,y)
   for _,sd in ipairs(sides)do
    local d=dropTo(x+sd[1],y+sd[2])
    if d==nil then
     if open[sd[3]]then d=RING_Y elseif sd[3]=='e'or sd[3]=='w'then d=0 end
    end
    local fr=sd[3]=='s'and L.facadeRun[K(x,y)]
    if type(d)=='number'and d<top-.01 and not fr then
     local gtop=(top>base+.5 and d<base)and base-2.4 or(top<=base+.5 and top-2.4 or nil)
     if gtop and gtop-d>8 then
      local plane,a0
      if sd[3]=='s'then plane,a0=y*8+8,x*8 elseif sd[3]=='n'then plane,a0=y*8,x*8
      elseif sd[3]=='e'then plane,a0=x*8+8,y*8 else plane,a0=x*8,y*8 end
      local key=sd[3]..':'..plane..':'..d..':'..gtop
      local r=runs[key]
      local seg={a0,a0+8}
      if not r then r={side=sd[3],plane=plane,y0=d,gtop=gtop,segs={}};runs[key]=r end
      r.segs[#r.segs+1]=seg
     end
    end
   end
  end
 end end
 -- merge the tile segments of each plane into continuous runs
 local keys={}
 for k in pairs(runs)do keys[#keys+1]=k end
 table.sort(keys)
 for _,k in ipairs(keys)do
  local r=runs[k]
  table.sort(r.segs,function(p,q)return p[1]<q[1]end)
  local cur=nil
  for _,sg in ipairs(r.segs)do
   if cur and math.abs(sg[1]-cur.a1)<.01 then cur.a1=sg[2]
   else
    cur={side=r.side,plane=r.plane,y0=r.y0,gtop=r.gtop,a0=sg[1],a1=sg[2]}
    P.walls[#P.walls+1]=cur
   end
  end
 end
 -- 2. the dressing and its lights
 local function W(side,plane,a,y,out)
  -- a point on a wall face: along `a`, height y, `out` units off the face
  local nx,nz=sideFrame(side)
  if side=='s'or side=='n'then return a,y,plane+nz*out end
  return plane+nx*out,y,a
 end
 for wi,w in ipairs(P.walls)do
  local len=w.a1-w.a0
  local floorY=w.y0==POOL_Y and -2 or w.y0
  local tall=w.gtop-floorY
  if len>=24 and tall>=14 then
   local n=max(1,floor(len/32+.5));local bw=len/n
   for k=1,n-1 do P.pilasters[#P.pilasters+1]={wall=wi,a=w.a0+k*bw}end
   for k=0,n-1 do
    local a=w.a0+(k+.5)*bw
    local banner=(k%2==1)and tall>=24
    if banner then
     local y1=w.gtop-1.2;local y0=y1-min(18,tall*.45)
     P.banners[#P.banners+1]={wall=wi,a=a,y0=y0,y1=y1,seed=wi*7+k}
     -- a soft uplight onto the banner from below
     P.washes[#P.washes+1]={wall=wi,a=a,y0=y0-6,y1=y1+1.5,w=12,out=.7,dir=1,k=.55}
    else
     local ys=floorY+min(14,tall*.45)
     P.sconces[#P.sconces+1]={wall=wi,a=a,y=ys}
     local hx,hy,hz=W(w.side,w.plane,a,ys+.9,2.6)
     P.halos[#P.halos+1]={x=hx,y=hy,z=hz,r=4.5}
     P.washes[#P.washes+1]={wall=wi,a=a,y0=ys+1.2,y1=min(w.gtop+2.4,ys+26),w=17,out=.7,dir=1,k=1}
     P.washes[#P.washes+1]={wall=wi,a=a,y0=max(floorY,ys-13),y1=ys-.6,w=11,out=.7,dir=-1,k=.8}
     if w.y0~=POOL_Y then
      local px,py,pz=W(w.side,w.plane,a,floorY+.18,7)
      P.pools[#P.pools+1]={x=px,y=py,z=pz,r=13}
     end
    end
   end
  end
 end
 -- 3. facades: pilaster sconces, panel uplights, doorways
 for y=0,th-1 do
  local x=0
  while x<tw do
   local fr=L.facadeRun[K(x,y)]
   if fr and not fr.hidden then
    local x1=x
    while x1+1<tw and L.facadeRun[K(x1+1,y)]and not L.facadeRun[K(x1+1,y)].hidden and L.facadeRun[K(x1+1,y)].h==fr.h do x1=x1+1 end
    local z=(y+1)*8;local HH=h(x,y)
    local d=dropTo(x,y+1);local ybase=type(d)=='number'and min(d,0)or 0
    local xx=x
    while xx<=x1 do
     local function kind(cx)
      local kd='band'
      for yy=y,y-4,-1 do local v=t(cx,yy);if v==21 or v==22 or v==5 or v==6 or v==48 or v==49 then kd='pil'end end
      if DOOR[t(cx,y)]or DOOR[t(cx,y-1)]then kd='door'end
      return kd
     end
     local kd=kind(xx);local xe=xx
     while xe+1<=x1 and kind(xe+1)==kd do xe=xe+1 end
     local A,B=xx*8,(xe+1)*8
     if kd=='pil'then
      local px=A
      while px<B-.1 do
       local pw=min(16,B-px);local sx=px+pw/2;local sy=HH*.5
       P.halos[#P.halos+1]={x=sx,y=sy+.1,z=z+1.8,r=4}
       P.washes[#P.washes+1]={face=true,x=sx,z=z+2.6,y0=sy+1.4,y1=HH-9,w=13,dir=1,k=.9}
       P.washes[#P.washes+1]={face=true,x=sx,z=z+2.6,y0=max(ybase,sy-12),y1=sy-1.8,w=10,dir=-1,k=.75}
       if ybase>=-.01 then P.pools[#P.pools+1]={x=sx,y=ybase+.18,z=z+7,r=12}end
       px=px+pw
      end
     elseif kd=='band'then
      local bx=A
      while bx<B-.1 do
       local bw=min(16,B-bx);if B-(bx+bw)<6 and B-(bx+bw)>0 then bw=B-bx end
       if bw>7 then P.washes[#P.washes+1]={face=true,x=bx+bw/2,z=z+1.4,y0=max(ybase,0)+5.8,y1=HH-11,w=bw*.9,dir=1,k=.55}end
       bx=bx+bw
      end
     else
      local dh=min(26,HH-12)
      P.washes[#P.washes+1]={face=true,x=(A+B)/2,z=z+1.6,y0=max(ybase,0),y1=dh+4,w=(B-A)*1.15,dir=1,k=.75}
      if ybase>=-.01 then P.pools[#P.pools+1]={x=(A+B)/2,y=ybase+.18,z=z+9,r=17}end
     end
     xx=xe+1
    end
    x=x1+1
   else x=x+1 end
  end
 end
 -- 4. lamp posts, fountains, the gatehouse and hall uplights
 for _,lp in ipairs(L.lamps or{})do P.pools[#P.pools+1]={x=lp.x,y=lp.y+.18,z=lp.z,r=17}end
 for _,F in ipairs(L.fountains or{})do
  P.aqua[#P.aqua+1]={x=F.x,y=F.y+.12,z=F.z,r=(F.plaza or 8)+7}
 end
 for _,u in ipairs(L.uplights or{})do
  P.washes[#P.washes+1]={face=true,x=u.x,z=u.z,y0=u.y,y1=u.y+u.h,w=u.r*3.2,dir=1,k=.8}
 end
 -- 5. the gorge rim: lantern posts along the ledge, just short of the lip
 local G=L.gorge
 if G then
  local function post(px,pz,nx,nz,a)
   local x,z=px-nx*8,pz-nz*8
   if G.fade(z)<.8 then return end
   local sd=(nx<0 and'w')or(nx>0 and'e')or'n'
   P.rim[#P.rim+1]={x=x,z=z,y=RING_Y,seed=a,side=sd,a=a}
   P.halos[#P.halos+1]={x=x,y=RING_Y+11.6,z=z,r=5.5}
   P.pools[#P.pools+1]={x=x,y=RING_Y+.2,z=z,r=16}
  end
  local zS=(G.k0>-1e8)and G.k0 or G.zA
  for a=zS+40,G.zB-40,64 do
   if G.open.w then post(G.x0,a,-1,0,a)end
   if G.open.e then post(G.x1,a+32,1,0,a+32)end
  end
  if G.k0>-1e8 then for a=G.x0+40,G.x1-40,64 do post(a,G.k0,0,-1,a)end end
  for _,f in ipairs(G.falls or{})do
   P.aqua[#P.aqua+1]={x=f.pool.x,y=f.pool.y+.3,z=f.pool.z,r=f.pool.r+16}
  end
  -- festoons: strings of little lamps slung from lantern to lantern along
  -- the rim, so the whole lip of the gorge is drawn in light after dark
  P.festoons={}
  local bySide={}
  for _,rp in ipairs(P.rim)do
   local s=bySide[rp.side];if not s then s={};bySide[rp.side]=s end
   s[#s+1]=rp
  end
  for _,sd in ipairs({'w','e','n'})do
   local s=bySide[sd]
   if s then
    table.sort(s,function(p,q)return p.a<q.a end)
    for i=1,#s-1 do
     local A,B=s[i],s[i+1]
     local dx,dz=B.x-A.x,B.z-A.z;local d=sqrt(dx*dx+dz*dz)
     if d>8 and d<=72 then
      local ux,uz=dx/d,dz/d
      local f={ax=A.x+ux*1.1,az=A.z+uz*1.1,bx=B.x-ux*1.1,bz=B.z-uz*1.1,y=RING_Y+9.9,sag=3.6+(i%3)*.5,bulbs={}}
      local nb=max(3,floor(d/8+.5)-1)
      for k=1,nb do
       local s01=k/(nb+1)
       local bx,bz=f.ax+(f.bx-f.ax)*s01,f.az+(f.bz-f.az)*s01
       local by=f.y-f.sag*4*s01*(1-s01)-.55
       f.bulbs[#f.bulbs+1]={bx,by,bz}
       P.halos[#P.halos+1]={x=bx,y=by,z=bz,r=2.3}
      end
      P.festoons[#P.festoons+1]=f
     end
    end
   end
  end
 end
 -- 6. the walk's borders: a footlight let into the balustrade plinth every
 -- other tile along the drop, each fanning warm light across the paving
 P.feet={}
 for y=0,th-1 do btick() for x=0,tw-1 do
  for _,sd in ipairs(sides)do
   if open[sd[3]]and c(x+sd[1],y+sd[2])=='edge'then
    local cc=c(x,y)
    local along=(sd[3]=='n'or sd[3]=='s')
    local idx=along and x or y
    if(cc=='floor'or cc=='statue'or cc=='boulder'or cc=='canopy')and idx%2==0 then
     local X0,Z0,X1,Z1=x*8,y*8,x*8+8,y*8+8
     local edge=(sd[3]=='s'and Z1)or(sd[3]=='n'and Z0)or(sd[3]=='e'and X1)or X0
     local inward=(sd[3]=='s'or sd[3]=='e')and -1 or 1
     local f=edge+inward*1.4                   -- the plinth's inner face
     local a=along and X0+4 or Z0+4
     P.feet[#P.feet+1]={side=sd[3],a=a,f=f,inward=inward}
     local hw,len,yy=7,12,.12
     local p
     if along then
      p={{a-hw,yy,f},{a+hw,yy,f},{a+hw,yy,f+inward*len},{a-hw,yy,f+inward*len}}
     else
      p={{f,yy,a-hw},{f,yy,a+hw},{f+inward*len,yy,a+hw},{f+inward*len,yy,a-hw}}
     end
     P.washes[#P.washes+1]={p=p,dir=1,k=.8}
    end
   end
  end
 end end
 -- resolve wall-relative washes into world corners
 for _,ws in ipairs(P.washes)do
  local c1,c2
  if ws.p then
   -- already in world space (footlight fans)
  elseif ws.face then
   c1={ws.x-ws.w/2,ws.z};c2={ws.x+ws.w/2,ws.z}
  else
   local w=P.walls[ws.wall]
   local ax0,_,az0=W(w.side,w.plane,ws.a-ws.w/2,0,ws.out)
   local ax1,_,az1=W(w.side,w.plane,ws.a+ws.w/2,0,ws.out)
   c1={ax0,az0};c2={ax1,az1}
  end
  if c1 then ws.p={{c1[1],ws.y0,c1[2]},{c2[1],ws.y0,c2[2]},{c2[1],ws.y1,c2[2]},{c1[1],ws.y1,c1[2]}}end
 end
 P.W=W
 L.night=P
 return P
end

-- The dressing itself: marble pilasters, bronze lantern sconces (lit glass),
-- crimson banners with a gold star; posts and lanterns along the gorge rim.
local function nightDressing(E,L,P)
 for _,pl in ipairs(P.pilasters)do
  local w=P.walls[pl.wall]
  local nx,nz,yaw=sideFrame(w.side)
  local x,_,z=P.W(w.side,w.plane,pl.a,0,0)
  local Lm=model(E,x,0,z,yaw,1)
  local y0,y1=w.y0,w.gtop
  E.decor(function()
   local fy=w.y0==POOL_Y and -2 or y0
   Lm.box(-2.6,y0,0,2.6,min(y1-1.4,fy+3.2),1.4,'lgVerde',1,{bottom=true,n=true})
   Lm.box(-1.9,y0,0,1.9,y1-1.4,.9,'lgMarble',1,{bottom=true,top=true,n=true})
   Lm.box(-2.4,y1-1.4,0,2.4,y1,1.3,'lgGold',1,{n=true})
  end)
 end
 for _,sc in ipairs(P.sconces)do
  local w=P.walls[sc.wall]
  local nx,nz,yaw=sideFrame(w.side)
  local x,_,z=P.W(w.side,w.plane,sc.a,0,0)
  local Lm=model(E,x,0,z,yaw,1)
  local y=sc.y
  E.decor(function()
   Lm.box(-1.5,y-3.4,0,1.5,y+.6,.5,'lgGold',1,{n=true})
   Lm.box(-.35,y-1.4,.5,.35,y-.8,2.6,'lgGold',1,{n=true})
   Lm.box(-1.15,y-1.6,1.5,1.15,y-1.0,3.8,'lgGold',1,{n=true})
   Lm.box(-.95,y-1.0,1.7,.95,y+2.4,3.6,'lgGold',1,{n=true,bottom=true,top=true},true)
   Lm.box(-1.2,y+2.4,1.45,1.2,y+3.0,3.85,'lgGold',1,{n=true})
   Lm.frustum(0,y+3.0,2.65,1.0,y+4.2,.2,4,'lgGold',false,pi/4)
  end)
 end
 for _,bn in ipairs(P.banners)do
  local w=P.walls[bn.wall]
  local nx,nz,yaw=sideFrame(w.side)
  local x,_,z=P.W(w.side,w.plane,bn.a,0,0)
  local Lm=model(E,x,0,z,yaw,1)
  local y0,y1,hw=bn.y0,bn.y1,4.6
  E.decor(function()
   Lm.box(-5.6,y1,.2,5.6,y1+.8,1.3,'lgGold',1,{})
   Lm.quad({-hw,y0+3,.7},{hw,y0+3,.7},{hw,y1,.7},{-hw,y1,.7},'lgCrimson',1)
   Lm.quad({-hw,y0+3,.7},{0,y0,.7},{hw,y0+3,.7},{-hw,y0+3,.7},'lgCrimson',1)
   Lm.box(-hw,y0+3,.7,-hw+.5,y1,.85,'lgGold',1,{})
   Lm.box(hw-.5,y0+3,.7,hw,y1,.85,'lgGold',1,{})
   Lm.box(-hw,y1-1.4,.7,hw,y1-.9,.85,'lgGold',1,{})
   local cy=y0+(y1-y0)*.58
   for i=0,9 do
    local a0,a1=pi/2+i/10*pi*2,pi/2+(i+1)/10*pi*2
    local r0,r1=(i%2==0)and 2.8 or 1.15,(i%2==0)and 1.15 or 2.8
    Lm.quad({0,cy,.9},{cos(a0)*r0,cy+sin(a0)*r0,.9},{cos(a1)*r1,cy+sin(a1)*r1,.9},{0,cy,.9},'lgGold',1.05)
   end
   Lm.quad({0,y0+.6,.88},{1.1,y0+2.2,.88},{0,y0+3.8,.88},{-1.1,y0+2.2,.88},'lgGold',1)
  end)
 end
 for _,rp in ipairs(P.rim)do
  local Lm=model(E,rp.x,rp.y,rp.z,0,1)
  Lm.box(-1.4,0,-1.4,1.4,1.2,1.4,'lgVerde',1,{bottom=true})
  Lm.frustum(0,1.2,0,.55,9.6,.42,6,'lgBronze')
  E.decor(function()
   Lm.box(-1.1,9.6,-1.1,1.1,10.1,1.1,'lgGold',1,{})
   Lm.box(-.9,10.1,-.9,.9,13.1,.9,'lgGold',1,{bottom=true,top=true},true)
   Lm.box(-1.15,13.1,-1.15,1.15,13.6,1.15,'lgGold',1,{})
   Lm.frustum(0,13.6,0,1.0,14.8,.15,4,'lgGold',false,pi/4)
  end)
 end
 -- festoons between the rim lanterns: a bronze cable, little lamps on it
 for _,f in ipairs(P.festoons or{})do
  E.decor(function()
   local N=10
   local function at(s)
    return f.ax+(f.bx-f.ax)*s,f.y-f.sag*4*s*(1-s),f.az+(f.bz-f.az)*s
   end
   local px,py,pz=at(0)
   for i=1,N do
    local x,y,z=at(i/N)
    E.quad({px,py-.09,pz},{x,y-.09,z},{x,y+.09,z},{px,py+.09,pz},'lgBronze',.8)
    px,py,pz=x,y,z
   end
   for _,b in ipairs(f.bulbs)do
    local x,y,z=b[1],b[2],b[3]
    E.quad({x-.32,y-.38,z},{x+.32,y-.38,z},{x+.32,y+.38,z},{x-.32,y+.38,z},'lgGold',1,true)
    E.quad({x,y-.38,z-.32},{x,y-.38,z+.32},{x,y+.38,z+.32},{x,y+.38,z-.32},'lgGold',1,true)
    E.quad({x-.06,y+.38,z},{x+.06,y+.38,z},{x+.06,y+.62,z},{x-.06,y+.62,z},'lgBronze',.8)
   end
  end)
 end
 -- the footlights let into the balustrade plinths
 for _,ft in ipairs(P.feet or{})do
  E.decor(function()
   local a,f,i=ft.a,ft.f,ft.inward
   local f0,f1=min(f,f+i*.16),max(f,f+i*.16)
   local g0,g1=min(f,f+i*.06),max(f,f+i*.06)
   if ft.side=='n'or ft.side=='s'then
    E.box(a-1.5,.14,g0,a+1.5,.86,g1,'lgGold',1,{bottom=true})
    E.box(a-1.15,.26,f0,a+1.15,.74,f1,'lgGold',1,{bottom=true},true)
   else
    E.box(g0,.14,a-1.5,g1,.86,a+1.5,'lgGold',1,{bottom=true})
    E.box(f0,.26,a-1.15,f1,.74,a+1.15,'lgGold',1,{bottom=true},true)
   end
  end)
 end
end

-- Emit everything into `out` (objectQuads-shaped). `t` is the tile accessor.
function M.emit(L,t,out,uv)
 local E=newEmitter(out,uv)
 L.stats={}
 local open=(L.ring and L.ring.open)or{}
 local tw,th,K,cls,H=L.tw,L.th,L.K,L.cls,L.H
 local function c(x,y)if x<0 or y<0 or x>=tw or y>=th then return 'edge'end;return cls[K(x,y)]end
 local function h(x,y)return H[K(x,y)]or 0 end
 local function topH(x,y)local v=t(x,y);return h(x,y)+(PARAPET[v]and 2.6 or 0)end
 -- how far a face drops beside a neighbour tile
 local function dropTo(x,y)
  local cc=c(x,y)
  if cc=='edge'then return nil end
  if cc=='mass'then return topH(x,y)end
  if cc=='gatehouse'then return 'none'end
  local v=t(x,y)
  if cc==nil and v~=nil and WATERISH[v]then return POOL_Y end
  if cc==nil and v==nil then return nil end
  if cc==nil and v~=69 and not(v==9 or v==10 or v==25 or v==26)then
   -- a tile someone else claimed or modelled (roof, building): no face
   return 'none'
  end
  return 0
 end

 -- 1. FLOOR: paving / meadow per tile, contact-shaded beside walls
 local function massAt(x,y)return c(x,y)=='mass'or c(x,y)=='statue'or c(x,y)=='boulder'or c(x,y)=='canopy'end
 local function ao(x,y)
  -- corner (x,y) in tile-corner space: darker if any adjacent tile is solid
  local n=0
  for _,d in ipairs({{-1,-1},{0,-1},{-1,0},{0,0}})do if massAt(x+d[1],y+d[2])then n=n+1 end end
  return n==0 and 1 or (n==1 and .80 or .70)
 end
 for y=0,th-1 do btick() for x=0,tw-1 do
  local cc=c(x,y)
  if cc=='floor'or cc=='statue'or cc=='boulder'or cc=='canopy'or cc=='sign'then
   local mat=cc=='floor'and floorKind(L,t,x,y)or 'lgPaveLight'
   if cc=='boulder'or cc=='sign'then mat='lgLawn'end
   local x0,z0,x1,z1=x*8,y*8,x*8+8,y*8+8
   E.quad({x0,0,z0},{x1,0,z0},{x1,0,z1},{x0,0,z1},mat,{ao(x,y),ao(x+1,y),ao(x+1,y+1),ao(x,y+1)})
   -- a quay where the paving meets open water: granite wall, marble kerb
   for _,d in ipairs({{0,1,'s'},{0,-1,'n'},{1,0,'e'},{-1,0,'w'}})do
    local nx,ny=x+d[1],y+d[2]
    local v=t(nx,ny)
    if v and WATERISH[v]and c(nx,ny)==nil then
     local vs=E.vs
     if d[3]=='s'then
      E.quad({x0,POOL_Y,z1},{x1,POOL_Y,z1},{x1,0,z1},{x0,0,z1},'lgGranite',{vs(.92,-6),vs(.92,-6),.92,.92})
      E.decor(function()E.box(x0,0,z1-1.1,x1,.5,z1+.25,'lgMarble',1,{bottom=true,w=true,e=true})end)
     elseif d[3]=='n'then
      E.quad({x1,POOL_Y,z0},{x0,POOL_Y,z0},{x0,0,z0},{x1,0,z0},'lgGranite',{vs(.72,-6),vs(.72,-6),.72,.72})
      E.decor(function()E.box(x0,0,z0-.25,x1,.5,z0+1.1,'lgMarble',1,{bottom=true,w=true,e=true})end)
     elseif d[3]=='e'then
      E.quad({x1,POOL_Y,z1},{x1,POOL_Y,z0},{x1,0,z0},{x1,0,z1},'lgGranite',{vs(.86,-6),vs(.86,-6),.86,.86})
      E.decor(function()E.box(x1-1.1,0,z0,x1+.25,.5,z1,'lgMarble',1,{bottom=true,n=true,s=true})end)
     else
      E.quad({x0,POOL_Y,z0},{x0,POOL_Y,z1},{x0,0,z1},{x0,0,z0},'lgGranite',{vs(.80,-6),vs(.80,-6),.80,.80})
      E.decor(function()E.box(x0-.25,0,z0,x0+1.1,.5,z1,'lgMarble',1,{bottom=true,n=true,s=true})end)
     end
    end
   end
  end
 end end
 -- TEST166: THE CANAL is a pool: a mosaic floor under every water tile,
 -- lined walls where the water meets an unclaimed bank (grass, signs)
 for y=0,th-1 do btick() for x=0,tw-1 do
  local v=t(x,y)
  if c(x,y)==nil and v and WATERISH[v]then
   local x0,z0,x1,z1=x*8,y*8,x*8+8,y*8+8
   E.quad({x0,POOL_Y,z0},{x1,POOL_Y,z0},{x1,POOL_Y,z1},{x0,POOL_Y,z1},'lgPool',.92)
   for _,d in ipairs({{0,1,'s'},{0,-1,'n'},{1,0,'e'},{-1,0,'w'}})do
    local nx,ny=x+d[1],y+d[2];local nv=t(nx,ny);local nc=c(nx,ny)
    if nc==nil and nv and not WATERISH[nv]then
     -- face back into the pool (the bank's side, seen through the water)
     local back={s='n',n='s',e='w',w='e'}
     local bx0,bz0=nx*8,ny*8
     vface(E,back[d[3]],bx0,bz0,bx0+8,bz0+8,POOL_Y,-2,'lgPool',1)
    end
   end
  end
 end end

 -- the red carpet, with gold border rails
 if L.carpet then
  local cp=L.carpet;local y=.18
  E.quad({cp.x0+1.2,y,cp.z0},{cp.x1-1.2,y,cp.z0},{cp.x1-1.2,y,cp.z1},{cp.x0+1.2,y,cp.z1},'lgCarpet',1)
  E.decor(function()
   E.box(cp.x0,0,cp.z0,cp.x0+1.2,.32,cp.z1,'lgGold',1,{bottom=true,n=true,s=true})
   E.box(cp.x1-1.2,0,cp.z0,cp.x1,.32,cp.z1,'lgGold',1,{bottom=true,n=true,s=true})
  end)
 end

 -- the map rim on an open side: a retaining wall down to the forest floor,
 -- with a balustrade wherever the paving runs to the edge
 for y=0,th-1 do btick() for x=0,tw-1 do
  for _,sd in ipairs({{0,1,'s'},{0,-1,'n'},{1,0,'e'},{-1,0,'w'}})do
   if open[sd[3]]and c(x+sd[1],y+sd[2])=='edge'then
    local cc=c(x,y);local v=t(x,y)
    local X0,Z0,X1,Z1=x*8,y*8,x*8+8,y*8+8
    if cc=='floor'or cc=='statue'or cc=='boulder'or cc=='canopy'then
     vface(E,sd[3],X0,Z0,X1,Z1,RING_Y,-2.4,'lgGranite',1)
     vface(E,sd[3],X0,Z0,X1,Z1,-2.4,0,'lgMarble',1)
     balustrade(E,sd[3],X0,Z0,X1,Z1)
    elseif cc==nil and v~=nil then
     vface(E,sd[3],X0,Z0,X1,Z1,RING_Y,WATERISH[v]and -1.5 or 0,'lgGranite',1)
     if WATERISH[v]then
      -- the canal's end at the map rim: a marble coping with a gold line
      local o=.9
      local bx0,bz0,bx1,bz1=X0,Z0,X1,Z1
      if sd[3]=='s'then bz0=Z1-o elseif sd[3]=='n'then bz1=Z0+o elseif sd[3]=='e'then bx0=X1-o else bx1=X0+o end
      E.box(bx0,-1.5,bz0,bx1,1.0,bz1,'lgMarble',1,{bottom=true})
      vface(E,sd[3],X0,Z0,X1,Z1,POOL_Y,-1.5,'lgPool',1)
     end
    end
   end
  end
 end end

 L.stats[#L.stats+1]={'floor',E.count}
 -- 2. MASS: tops, sides, facades
 local function topMat(x,y)
  local v=t(x,y)
  if PARAPET[v]then return 'lgMarble'end
  if L.facadeRun[K(x,y)]then return 'lgMarble'end
  -- band rows behind a facade: lawn where the terrace continues behind
  if v==13 or v==14 or v==15 or DOOR[v]then
   if v==13 and not L.facadeTile[K(x,y)]then return 'lgMarble'end
   local yy=y
   while yy>=0 and c(x,yy)=='mass'and (t(x,yy)==14 or t(x,yy)==15 or t(x,yy)==13 or DOOR[t(x,yy)])do yy=yy-1 end
   if c(x,yy)=='mass'and t(x,yy)==3 then return 'lgLawn'end
   return 'hedge'
  end
  return 'lgLawn'
 end
 for y=0,th-1 do btick()
  -- tops, merged along x runs with equal material and height
  local x=0
  while x<tw do
   if c(x,y)=='mass'then
    local m,ht=topMat(x,y),topH(x,y)
    local x1=x
    while x1+1<tw and c(x1+1,y)=='mass'and topMat(x1+1,y)==m and topH(x1+1,y)==ht do x1=x1+1 end
    local X0,X1,Z0,Z1=x*8,(x1+1)*8,y*8,y*8+8
    if m=='hedge'then
     E.quad({X0,ht,Z0},{X1,ht,Z0},{X1,ht,Z1},{X0,ht,Z1},'lgMarble',1)
    else
     E.quad({X0,ht,Z0},{X1,ht,Z0},{X1,ht,Z1},{X0,ht,Z1},m,1)
    end
    x=x1+1
   else x=x+1 end
  end
 end
 -- hedge planters on free-standing gate walls (band-only masses)
 for y=0,th-1 do btick()
  local x=0
  while x<tw do
   if c(x,y)=='mass'and topMat(x,y)=='hedge'and(y==0 or topMat(x,y-1)~='hedge'or c(x,y-1)~='mass')then
    local x1=x
    while x1+1<tw and c(x1+1,y)=='mass'and topMat(x1+1,y)=='hedge'do x1=x1+1 end
    local y1=y
    while y1+1<th and c(x,y1+1)=='mass'and topMat(x,y1+1)=='hedge'do y1=y1+1 end
    local ht=topH(x,y)
    local X0,X1,Z0,Z1=x*8+2.2,(x1+1)*8-2.2,y*8+2.2,(y1+1)*8-2.2
    if X1-X0>2 and Z1-Z0>2 then
     -- a clipped box hedge, a row of topiary balls on top, blooms between
     local hb=2.6
     E.box(X0,ht,Z0,X1,ht+hb,Z1,'lgFoliage',1,{bottom=true})
     local long=X1-X0>=Z1-Z0
     local len=long and X1-X0 or Z1-Z0
     local nb=max(1,floor(len/12+.5))
     local step=len/nb
     for i=0,nb-1 do
      local u=(i+.5)*step
      local bx,bz=long and X0+u or (X0+X1)/2,long and (Z0+Z1)/2 or Z0+u
      local r=min(3.4,(long and Z1-Z0 or X1-X0)*.32)
      model(E,bx,ht+hb,bz,0,1).sphere(0,r*.85,0,r,r*.9,r,'lgFoliage',8,5,x*7+y*3+i,'lgFoliage')
      if i<nb-1 then
       local fu=(i+1)*step
       local fx,fz=long and X0+fu or (X0+X1)/2,long and (Z0+Z1)/2 or Z0+fu
       local m=(i%2==0)and'lgCrimson'or'lgGold'
       E.decor(function()E.box(fx-1.3,ht+hb,fz-1.3,fx+1.3,ht+hb+1.1,fz+1.3,m,1,{bottom=true,n=true})end)
      end
     end
    end
    x=x1+1
   else x=x+1 end
  end
 end
 -- side faces: granite ashlar with marble coping; facades handled below
 local sides={{0,1,'s'},{0,-1,'n'},{1,0,'e'},{-1,0,'w'}}
 for y=0,th-1 do btick() for x=0,tw-1 do
  if c(x,y)=='mass'then
   local top=topH(x,y);local base=h(x,y)
   for _,sd in ipairs(sides)do
    local nx,ny=x+sd[1],y+sd[2]
    local d=dropTo(nx,ny)
    -- the map rim: an open side drops to the forest floor; a connected one
    -- continues into the neighbour (east/west are closed regardless)
    if d==nil then
     if open[sd[3]]then d=RING_Y elseif sd[3]=='e'or sd[3]=='w'then d=0 end
    end
    local fr=sd[3]=='s'and L.facadeRun[K(x,y)]
    local isFacade=fr and not fr.hidden
    if isFacade and d~=nil and top>base+.5 then
     local X0,X1,Z1=x*8,x*8+8,y*8+8
     E.decor(function()
      E.quad({X0-.6,base,Z1+1.2},{X1+.6,base,Z1+1.2},{X1+.6,top,Z1+1.2},{X0-.6,top,Z1+1.2},'lgMarble',.92)
      E.quad({X0-.6,base,Z1},{X0-.6,base,Z1+1.2},{X0-.6,top,Z1+1.2},{X0-.6,top,Z1},'lgMarble',.80)
      E.quad({X1+.6,base,Z1+1.2},{X1+.6,base,Z1},{X1+.6,top,Z1},{X1+.6,top,Z1+1.2},'lgMarble',.86)
      E.quad({X0-.6,top,Z1},{X1+.6,top,Z1},{X1+.6,top,Z1+1.2},{X0-.6,top,Z1+1.2},'lgMarble',1)
     end)
    end
    if fr and fr.hidden then isFacade=true end
    if type(d)=='number'and d<top-.01 and not isFacade then
     local X0,X1,Z0,Z1=x*8,x*8+8,y*8,y*8+8
     local y0=d
     local function face(ya,yb,mat,tone)
      if yb-ya<.01 then return end
      local vs=E.vs
      if sd[3]=='s'then E.quad({X0,ya,Z1},{X1,ya,Z1},{X1,yb,Z1},{X0,yb,Z1},mat,{vs(tone*.92,ya),vs(tone*.92,ya),vs(tone*.92,yb),vs(tone*.92,yb)})
      elseif sd[3]=='n'then E.quad({X1,ya,Z0},{X0,ya,Z0},{X0,yb,Z0},{X1,yb,Z0},mat,{vs(tone*.72,ya),vs(tone*.72,ya),vs(tone*.72,yb),vs(tone*.72,yb)})
      elseif sd[3]=='e'then E.quad({X1,ya,Z1},{X1,ya,Z0},{X1,yb,Z0},{X1,yb,Z1},mat,{vs(tone*.86,ya),vs(tone*.86,ya),vs(tone*.86,yb),vs(tone*.86,yb)})
      else E.quad({X0,ya,Z0},{X0,ya,Z1},{X0,yb,Z1},{X0,yb,Z0},mat,{vs(tone*.80,ya),vs(tone*.80,ya),vs(tone*.80,yb),vs(tone*.80,yb)})end
     end
     if top>base+.5 then
      -- parapet: marble above the terrace line
      face(max(y0,base),top,top-base>6 and 'lgAshlar' or 'lgMarble',1)
      if y0<base then
       face(y0,max(y0,base-2.4),'lgGranite',1)
       face(max(y0,base-2.4),base,'lgMarble',1)
      end
     else
      face(y0,max(y0,top-2.4),'lgGranite',1)
      face(max(y0,top-2.4),top,'lgMarble',1)
     end
    end
   end
  end
 end end

 L.stats[#L.stats+1]={'mass',E.count}
 -- 2b. TEST168: the walls' night dressing (pilasters, sconces, banners,
 -- the gorge rim's lantern posts)
 do
  local okN,P=pcall(M.nightPlan,L,t,open)
  if okN and P then nightDressing(E,L,P)
  elseif not okN then print('[LeagueArchitecture] night plan: '..tostring(P))end
 end
 L.stats[#L.stats+1]={'night',E.count}
 -- 3. FACADES: per facade run, south face at the run's bottom edge
 -- Group runs into horizontal segments of equal bottom row and height.
 local segs={}
 for y=0,th-1 do btick()
  local x=0
  while x<tw do
   local fr=L.facadeRun[K(x,y)]
   if fr and not fr.hidden then
    local x1=x
    while x1+1<tw and L.facadeRun[K(x1+1,y)]and not L.facadeRun[K(x1+1,y)].hidden and L.facadeRun[K(x1+1,y)].h==fr.h do x1=x1+1 end
    segs[#segs+1]={x0=x,x1=x1,y=y,h=h(x,y)}
    x=x1+1
   else x=x+1 end
  end
 end
 for _,sg in ipairs(segs)do
  local z=(sg.y+1)*8;local HH=sg.h
  local d=dropTo(sg.x0,sg.y+1);local ybase=type(d)=='number'and min(d,0)or 0
  -- classify columns of this segment
  local col={}
  for x=sg.x0,sg.x1 do
   local kind='band'
   for yy=sg.y,sg.y-4,-1 do local v=t(x,yy);if v==21 or v==22 or v==5 or v==6 or v==48 or v==49 then kind='pil'end end
   if DOOR[t(x,sg.y)]or DOOR[t(x,sg.y-1)]then kind='door'end
   col[x]=kind
  end
  local X0,X1=sg.x0*8,(sg.x1+1)*8
  -- Relief is shallow and drawn as shadowless DETAIL: under a grazing sun a
  -- unit-deep cornice or pilaster prints stair-stepped shadow down the wall.
  -- The wall itself carries the contact shade instead (darker under the
  -- frieze, a touch darker at the plinth).
  E.decor(function()
  do
   local x=sg.x0
   while x<=sg.x1 do
    local kind=col[x];local x1=x
    while x1+1<=sg.x1 and col[x1+1]==kind do x1=x1+1 end
    local A,B=x*8,(x1+1)*8
    if kind=='door'then
     local dh=min(26,HH-12)
     E.quad({A,dh+3.4,z},{B,dh+3.4,z},{B,HH-7,z},{A,HH-7,z},'lgAshlar',{.88,.88,.80,.80})
    else
     E.box(A,ybase,z-.2,B,5,z+1.0,'lgVerde',1,{bottom=true,n=true,w=x>sg.x0,e=x1<sg.x1})
     E.box(A,5,z-.2,B,5.7,z+1.15,'lgGold',1,{n=true,w=x>sg.x0,e=x1<sg.x1})
     E.quad({A,5.7,z},{B,5.7,z},{B,HH-11,z},{A,HH-11,z},'lgAshlar',{.84,.84,.92,.92})
     E.quad({A,HH-11,z},{B,HH-11,z},{B,HH-7,z},{A,HH-7,z},'lgMarble',{.92,.92,.76,.76})
    end
    x=x1+1
   end
  end
  -- frieze (closed underneath: a low camera looks up into it), flush gold
  -- dentils, cornice, gold line and cap
  E.box(X0,HH-7,z-.2,X1,HH-3.2,z+.5,'lgMarble',1,{n=true})
  local dx=X0+1
  while dx<X1-1 do E.quad({dx,HH-6.2,z+.56},{dx+1.2,HH-6.2,z+.56},{dx+1.2,HH-4.8,z+.56},{dx,HH-4.8,z+.56},'lgGold',.95);dx=dx+3.2 end
  E.box(X0-.6,HH-3.2,z-.2,X1+.6,HH-.8,z+1.5,'lgMarble',1,{n=true})
  E.box(X0-.6,HH-.8,z-.2,X1+.6,HH-.35,z+1.7,'lgGold',1,{n=true})
  E.box(X0-.3,HH-.35,z-.2,X1+.3,HH,z+1.3,'lgMarble',1,{n=true,bottom=true})
  -- bays: crimson panels between pilasters, doors, pilasters
  local x=sg.x0
  while x<=sg.x1 do
   local kind=col[x];local x1=x
   while x1+1<=sg.x1 and col[x1+1]==kind do x1=x1+1 end
   local A,B=x*8,(x1+1)*8
   if kind=='band'then
    -- one panel per 16-unit bay
    local bx=A
    while bx<B-.1 do
     local bw=min(16,B-bx);if B-(bx+bw)<6 and B-(bx+bw)>0 then bw=B-bx end
     local p0,p1=bx+2.2,bx+bw-2.2
     if p1-p0>3 then
      local y0,y1=8.4,HH-11.6
      E.quad({p0,y0,z+.12},{p1,y0,z+.12},{p1,y1,z+.12},{p0,y1,z+.12},'lgCrimson',{.86,.86,.95,.95})
      -- gilded frame, nearly flush
      local zf=z+.24
      E.quad({p0-.6,y0-.6,zf},{p1+.6,y0-.6,zf},{p1+.6,y0,zf},{p0-.6,y0,zf},'lgGold',.95)
      E.quad({p0-.6,y1,zf},{p1+.6,y1,zf},{p1+.6,y1+.6,zf},{p0-.6,y1+.6,zf},'lgGold',.95)
      E.quad({p0-.6,y0,zf},{p0,y0,zf},{p0,y1,zf},{p0-.6,y1,zf},'lgGold',.95)
      E.quad({p1,y0,zf},{p1+.6,y0,zf},{p1+.6,y1,zf},{p1,y1,zf},'lgGold',.95)
      -- an inner gold line and a gilded lozenge at the panel's heart
      local q0,q1,r0,r1=p0+1.1,p1-1.1,y0+1.1,y1-1.1
      E.quad({q0,r0,z+.18},{q1,r0,z+.18},{q1,r0+.3,z+.18},{q0,r0+.3,z+.18},'lgGold',.9)
      E.quad({q0,r1-.3,z+.18},{q1,r1-.3,z+.18},{q1,r1,z+.18},{q0,r1,z+.18},'lgGold',.9)
      E.quad({q0,r0,z+.18},{q0+.3,r0,z+.18},{q0+.3,r1,z+.18},{q0,r1,z+.18},'lgGold',.9)
      E.quad({q1-.3,r0,z+.18},{q1,r0,z+.18},{q1,r1,z+.18},{q1-.3,r1,z+.18},'lgGold',.9)
      local cx,cy=(p0+p1)/2,(y0+y1)/2
      local r=min(2.6,(p1-p0)*.22)
      E.quad({cx,cy-r*1.3,z+.3},{cx+r,cy,z+.3},{cx,cy+r*1.3,z+.3},{cx-r,cy,z+.3},'lgGold',1)
     end
     bx=bx+bw
    end
   elseif kind=='pil'then
    -- fluted marble pilasters (flutes are in the finish), one per 16 units
    local px=A
    while px<B-.1 do
     local pw=min(16,B-px)
     local a,b=px+1.4,px+pw-1.4
     E.box(px+.4,ybase,z-.2,px+pw-.4,6.2,z+1.6,'lgVerde',1,{bottom=true,n=true})
     E.box(px+.9,6.2,z-.2,px+pw-.9,7.0,z+1.4,'lgGold',1,{bottom=true,n=true})
     E.box(a,7.0,z-.2,b,HH-11.5,z+1.1,'lgFluteD',1,{bottom=true,top=true,n=true})
     -- gilded capital
     E.box(a-.6,HH-11.5,z-.2,b+.6,HH-10.3,z+1.4,'lgGold',1,{n=true})
     E.box(a-1.0,HH-10.3,z-.2,b+1.0,HH-9.0,z+1.7,'lgGold',.94,{n=true})
     -- a lit bronze sconce
     local sx=(a+b)/2;local sy=HH*.5
     E.box(sx-.9,sy-1.8,z+1.1,sx+.9,sy-1.2,z+2.3,'lgGold',1,{n=true})
     E.box(sx-.75,sy-1.2,z+1.4,sx+.75,sy+1.4,z+2.2,'lgGold',1,{n=true,bottom=true,top=true},true)
     E.box(sx-1.0,sy+1.4,z+1.2,sx+1.0,sy+2.0,z+2.4,'lgGold',1,{n=true})
     px=px+pw
    end
   else
    -- the doorway: dark recess, gilded bronze double leaves, marble architrave
    local dh=min(26,HH-12)
    doorway(E,A,B,z,dh)
   end
   x=x1+1
  end
  end)
 end

 L.stats[#L.stats+1]={'facades',E.count}
 -- 3b. THE GATEHOUSE (Route 23's south end)
 if L.gatehouse then gatehouse(E,L.gatehouse)end

 L.stats[#L.stats+1]={'gatehouse',E.count}
 -- 4. THE LEAGUE HALL (Indigo): attic storey and gilded inscription
 if L.hall then
  local hl=L.hall;local at=hl.attic
  E.box(at.x0,hl.h,at.z0,at.x1,at.h,at.z1,'lgAshlar',1,{bottom=true,n=not open.n})
  E.box(at.x0-.8,at.h,at.z0,at.x1+.8,at.h+1.2,at.z1+.8,'lgGold',1,{n=not open.n,top=true})
  E.quad({at.x0-.8,at.h+1.2,at.z0},{at.x1+.8,at.h+1.2,at.z0},{at.x1+.8,at.h+1.2,at.z1+.8},{at.x0-.8,at.h+1.2,at.z1+.8},'lgMarble',1)
  E.box(at.x0+2,at.h+1.2,at.z0,at.x1-2,at.h+1.9,at.z1-1.2,'lgMarble',.97,{bottom=true,n=true})
  local zf=hl.z1+.6;local mid=(hl.x0+hl.x1)/2
  E.decor(function()
   -- attic pilasters
   local px=at.x0+2
   while px<at.x1-4 do E.box(px,hl.h,at.z1,px+3,at.h,at.z1+1.1,'lgMarble',.95,{n=true,bottom=true});px=px+12 end
   -- a gold-on-crimson sign band across the hall frieze
   E.box(hl.x0+17,hl.h-21.5,hl.z1-.2,hl.x1-17,hl.h-8.2,zf,'lgCrimson',1,{n=true})
   E.box(hl.x0+16.4,hl.h-22.1,hl.z1-.2,hl.x1-16.4,hl.h-21.5,zf+.3,'lgGold',1,{n=true})
   E.box(hl.x0+16.4,hl.h-8.2,hl.z1-.2,hl.x1-16.4,hl.h-7.6,zf+.3,'lgGold',1,{n=true})
   inscription(E,'POKEMON LEAGUE',mid,hl.h-18.7,zf,1.68,'lgGold',hl.x1-hl.x0-40)
   -- engaged columns across the hall front, flanking the doors and sign
   for _,cx in ipairs({hl.x0+5,hl.x0+30,hl.x1-30,hl.x1-5})do
    local Lm=model(E,cx,0,hl.z1+2.6,0,1)
    Lm.box(-3.6,0,-3.6,3.6,6.0,3.6,'lgVerde')
    Lm.box(-3.1,6.0,-3.1,3.1,7.0,3.1,'lgGold')
    Lm.frustum(0,7.0,0,2.7,hl.h-26,2.35,12,'lgMarble')
    Lm.frustum(0,hl.h-26,0,2.35,hl.h-24.6,3.2,12,'lgGold')
    Lm.box(-3.5,hl.h-24.6,-3.5,3.5,hl.h-23.2,3.5,'lgGold',1,{})
   end
   -- a pediment over the hall with a gilded sunburst
   local pz=hl.z1+2.6;local ph=18;local py=hl.h
   E.quad({hl.x0-1,py,pz},{hl.x1+1,py,pz},{mid,py+ph,pz},{mid,py+ph,pz},'lgMarble',.95)
   E.quad({hl.x0-1,py,pz-6},{mid,py+ph,pz-6},{mid,py+ph,pz},{hl.x0-1,py,pz},'lgMarble',1)
   E.quad({mid,py+ph,pz-6},{hl.x1+1,py,pz-6},{hl.x1+1,py,pz},{mid,py+ph,pz},'lgMarble',1)
   E.quad({hl.x1+1,py,pz},{hl.x0-1,py,pz},{hl.x0-1,py,pz-6},{hl.x1+1,py,pz-6},'lgMarble',.6)
   E.quad({hl.x0-2.5,py-.2,pz+.6},{mid,py+ph+1.2,pz+.6},{mid,py+ph+1.2,pz-6.4},{hl.x0-2.5,py-.2,pz-6.4},'lgGold',1)
   E.quad({mid,py+ph+1.2,pz+.6},{hl.x1+2.5,py-.2,pz+.6},{hl.x1+2.5,py-.2,pz-6.4},{mid,py+ph+1.2,pz-6.4},'lgGold',1)
   local sy=py+ph*.42
   for i=0,15 do
    local a0=i/16*pi*2;local r=i%2==0 and 6.2 or 3.6
    local a1=(i+1)/16*pi*2;local r1=(i+1)%2==0 and 6.2 or 3.6
    E.quad({mid,sy,pz+.5},{mid+cos(a0)*r,sy+sin(a0)*r*.82,pz+.5},{mid+cos(a1)*r1,sy+sin(a1)*r1*.82,pz+.5},{mid,sy,pz+.5},'lgGold',1)
   end
  end)
  -- eternal-flame bowls crowning the hall corners and the attic
  for _,b in ipairs(hallBowls(hl))do
   local Lm=model(E,b[1],b[2],b[3],0,b[4])
   Lm.box(-3.0,0,-3.0,3.0,1.6,3.0,'lgVerde')
   Lm.frustum(0,1.6,0,2.2,5.0,1.5,8,'lgMarble')
   Lm.frustum(0,5.0,0,1.5,5.8,1.2,8,'lgGold')
   fireBowl(Lm,5.8,1.2,3.4,2.4)
  end
 end

 L.stats[#L.stats+1]={'hall',E.count}
 -- 5. STATUES: eagle on a marble plinth, topiary behind
 for _,st in ipairs(L.statues)do
  local cx=st.x;local zs=st.z0+16;local ze=st.z1
  E.box(cx-7.6,0,st.z0+.4,cx+7.6,1.4,ze-.4,'lgVerde',1,{bottom=true})
  E.box(cx-6.2,1.4,zs+.6,cx+6.2,3.0,ze-1.6,'lgMarble',1,{bottom=true})
  E.box(cx-5.0,3.0,zs+1.6,cx+5.0,10.0,ze-2.6,'lgMarble',1,{bottom=true})
  E.decor(function()E.box(cx-5.4,7.6,zs+1.2,cx+5.4,8.4,ze-2.2,'lgGold',1,{bottom=true})end)
  E.box(cx-6.0,10.0,zs+.9,cx+6.0,11.2,ze-1.9,'lgMarble',1,{bottom=true})
  local Lm=model(E,cx,11.2,(zs+ze)/2-.8,0,.92)
  eagle(Lm,st.seed)
  -- planter + topiary on the north half
  E.box(cx-4.6,1.4,st.z0+2.6,cx+4.6,5.4,st.z0+12.4,'lgMarble',.96,{bottom=true})
  E.decor(function()E.box(cx-4.9,5.4,st.z0+2.3,cx+4.9,6.0,st.z0+12.7,'lgGold',1,{bottom=true})end)
  topiary(model(E,cx,6.0,st.z0+7.5,0,1),st.seed,3.8)
 end

 L.stats[#L.stats+1]={'statues',E.count}
 -- TEST192: the signboard as a League plaque: a granite step, two marble
 -- posts with gold caps, a crimson board in a gold frame, the name in gold
 -- on both faces (VICTORY ROAD beside its gate on Route 23)
 for _,sg in ipairs(L.signs or{})do
  local cx,cz=sg.x,sg.z
  local text=(L.id=='ROUTE_23')and'VICTORY ROAD'or'INDIGO PLATEAU'
  E.box(cx-7.8,0,cz-2.6,cx+7.8,.9,cz+2.6,'lgGranite',1,{bottom=true})
  for _,px in ipairs({-6.9,6.9})do
   E.box(cx+px-.9,.9,cz-.9,cx+px+.9,10.8,cz+.9,'lgMarble',1,{bottom=true})
   E.decor(function()E.box(cx+px-1.15,10.8,cz-1.15,cx+px+1.15,11.6,cz+1.15,'lgGold',1,{bottom=true})end)
  end
  E.box(cx-6.0,4.4,cz-.55,cx+6.0,10.2,cz+.55,'lgCrimson',1,{bottom=true})
  E.decor(function()
   E.box(cx-6.0,10.2,cz-.7,cx+6.0,10.7,cz+.7,'lgGold',1,{bottom=true})
   E.box(cx-6.0,3.9,cz-.7,cx+6.0,4.4,cz+.7,'lgGold',1,{bottom=true})
   inscription(E,text,cx,6.0,cz+.56,.42,'lgGold',10.6)
   -- the north face reads the same way round from behind
   local Lb=model(E,cx,0,cz,math.pi,1)
   if Lb and Lb.box then inscription(Lb,text,0,6.0,.56,.42,'lgGold',10.6)end
  end)
 end
 L.stats[#L.stats+1]={'signs',E.count}
 -- 6. WALL EAGLES: on the parapet ends, on a small gold-banded block
 for _,eg in ipairs(L.eagles)do
  E.box(eg.x-3.4,eg.y,eg.z-3.4,eg.x+3.4,eg.y+2.4,eg.z+3.4,'lgMarble',1,{bottom=true})
  E.decor(function()E.box(eg.x-3.7,eg.y+2.4,eg.z-3.7,eg.x+3.7,eg.y+2.9,eg.z+3.7,'lgGold',1,{bottom=true})end)
  eagle(model(E,eg.x,eg.y+2.9,eg.z,0,.68),eg.seed)
 end

 L.stats[#L.stats+1]={'eagles',E.count}
 -- 7. TREES: terrace cypress / topiary, ornamental canopies in planters
 -- gravel aisles and the fountains on them
 for _,a0 in ipairs(L.aisles or{})do
  local alongZ=a0.x1-a0.x0<a0.z1-a0.z0
  -- the aisle stops at each fountain plaza's flat edge (no kerb through
  -- the basin)
  local lo,hi=alongZ and a0.z0 or a0.x0,alongZ and a0.z1 or a0.x1
  local cuts={}
  for _,F in ipairs(L.fountains or{})do
   local ac,al=alongZ and F.x or F.z,alongZ and F.z or F.x
   local c0,c1=alongZ and a0.x0 or a0.z0,alongZ and a0.x1 or a0.z1
   if ac>=c0-1 and ac<=c1+1 and al>lo-F.plaza and al<hi+F.plaza then
    local h=F.plaza*cos(pi/8)-.05
    cuts[#cuts+1]={al-h,al+h}
   end
  end
  table.sort(cuts,function(p,q)return p[1]<q[1]end)
  local segs,at={},lo
  for _,c in ipairs(cuts)do
   if c[1]>at+.5 then segs[#segs+1]={at,min(c[1],hi)}end
   at=max(at,c[2])
  end
  if hi>at+.5 then segs[#segs+1]={at,hi}end
  for _,sg in ipairs(segs)do
   local a={x0=a0.x0,x1=a0.x1,z0=a0.z0,z1=a0.z1,y=a0.y}
   if alongZ then a.z0,a.z1=sg[1],sg[2] else a.x0,a.x1=sg[1],sg[2] end
   E.quad({a.x0,a.y+.04,a.z0},{a.x1,a.y+.04,a.z0},{a.x1,a.y+.04,a.z1},{a.x0,a.y+.04,a.z1},'lgGravel',1)
   -- a marble kerb along both sides of the aisle
   E.decor(function()
    if alongZ then
     E.box(a.x0-.5,a.y,a.z0,a.x0,a.y+.45,a.z1,'lgMarble',1,{bottom=true,n=true,s=true})
     E.box(a.x1,a.y,a.z0,a.x1+.5,a.y+.45,a.z1,'lgMarble',1,{bottom=true,n=true,s=true})
    else
     E.box(a.x0,a.y,a.z0-.5,a.x1,a.y+.45,a.z0,'lgMarble',1,{bottom=true,w=true,e=true})
     E.box(a.x0,a.y,a.z1,a.x1,a.y+.45,a.z1+.5,'lgMarble',1,{bottom=true,w=true,e=true})
    end
   end)
  end
 end
 for _,F in ipairs(L.fountains or{})do fountain(E,F)end
 L.stats[#L.stats+1]={'fountains',E.count}
 for _,tr in ipairs(L.garden)do
  if tr.kind=='bed'then E.decor(function()flowerBed(E,tr.x,tr.y,tr.z,tr.seed)end)
  elseif tr.kind=='urn'then E.decor(function()urn(model(E,tr.x,tr.y,tr.z,0,1),tr.seed)end)
  else
   -- TEST169: the garden's cypresses and clipped balls, rebuilt round
   local F=Flora()
   if tr.kind=='cypress'then F.cypress(E,tr.x,tr.y,tr.z,20+rh(tr.seed,2,3)*9,tr.seed,rh(tr.seed,1,2)*pi,1)
   else
    local r=3.4+rh(tr.seed,4,5)*1.2
    F.limb(E,'lgBark',{tr.x,tr.y,tr.z},{tr.x,tr.y+2.4,tr.z},.45,.38,5)
    F.cluster(E,'lgFoliage',tr.x,tr.y+2.2+r*.9,tr.z,r,r*.92,r,9,5,tr.seed,{lump=.05,y0=tr.y+2.2,y1=tr.y+2.2+r*1.9})
   end
  end
 end
 -- parapet lanterns: verde foot, marble post, gold collar, lit lantern, gold cap
 E.decor(function()
 for _,lp in ipairs(L.lamps)do
  local X,Y,Z=lp.x,lp.y,lp.z
  E.box(X-1.6,Y,Z-1.6,X+1.6,Y+1.5,Z+1.6,'lgVerde',1,{bottom=true})
  model(E,X,Y,Z,0,1).frustum(0,1.5,0,.78,9.2,.58,6,'lgMarble')
  E.box(X-1.05,Y+9.2,Z-1.05,X+1.05,Y+9.8,Z+1.05,'lgGold',1,{})
  E.box(X-.92,Y+9.8,Z-.92,X+.92,Y+12.6,Z+.92,'lgGold',1,{bottom=true,top=true},true)
  E.box(X-1.25,Y+12.6,Z-1.25,X+1.25,Y+13.1,Z+1.25,'lgGold',1,{})
  model(E,X,Y,Z,0,1).frustum(0,13.1,0,1.2,15.0,.12,4,'lgGold',false,pi/4)
 end
 end)
 for _,tr in ipairs(L.trees)do
  E.box(tr.x-6.2,0,tr.z-6.2,tr.x+6.2,3.4,tr.z+6.2,'lgMarble',1,{bottom=true})
  E.box(tr.x-6.6,3.4,tr.z-6.6,tr.x+6.6,4.0,tr.z+6.6,'lgGold',1,{bottom=true})
  E.quad({tr.x-5.6,3.6,tr.z-5.6},{tr.x+5.6,3.6,tr.z-5.6},{tr.x+5.6,3.6,tr.z+5.6},{tr.x-5.6,3.6,tr.z+5.6},'lgLawn',.8)
  roundTree(model(E,tr.x,3.6,tr.z,rh(tr.seed,3,1)*pi,1),tr.seed)
 end

 L.stats[#L.stats+1]={'gardens',E.count}
 -- 8. BOULDERS: weathered granite in the meadow
 for _,b in ipairs(L.boulders)do
  local s=b.seed
  boulder(model(E,b.x,0,b.z,0,1),s,5.6+rh(s,1,1)*1.6,5.2+rh(s,2,2)*2.6,5.4+rh(s,3,3)*1.6)
  boulder(model(E,b.x+(rh(s,4,4)-.5)*7,0,b.z+4.5,0,1),s+5,1.6,1.3,1.5)
 end

 L.stats[#L.stats+1]={'boulders',E.count}
 -- 9. BADGE GATES: gilded marble obelisks and a crossbeam with banners
 for _,g in ipairs(L.gates)do
  local z=g.z
  for i,x in ipairs({g.L,g.R})do
   local b=i==1 and g.baseL or g.baseR
   local Lm=model(E,x,b,z,0,1)
   Lm.box(-6.4,0,-6.4,6.4,4.2,6.4,'lgVerde')
   Lm.box(-6.8,4.2,-6.8,6.8,5.0,6.8,'lgGold',1,{})
   local top=g.top-b
   Lm.frustum(0,5.0,0,5.0,top,3.4,4,'lgMarble',false,pi/4)
   Lm.frustum(0,top,0,3.6,top+1.2,4.0,4,'lgGold',false,pi/4)
   Lm.frustum(0,top+1.2,0,4.0,top+1.8,2.6,4,'lgGold',false,pi/4)
   fireBowl(Lm,top+1.8,2.6,4.8,3.0)
  end
  -- crossbeam
  local y0=g.beam
  E.box(g.L+3,y0,z-2.3,g.R-3,y0+3.6,z+2.3,'lgMarble',1)
  E.box(g.L+3,y0+3.6,z-2.6,g.R-3,y0+4.4,z+2.6,'lgGold',1,{bottom=true})
  E.box(g.L+3,y0-.8,z-2.6,g.R-3,y0,z+2.6,'lgGold',1,{top=true})
  -- banners (crimson, gold trim) hanging on both faces of the beam
  local mid=(g.L+g.R)/2;local span=g.R-g.L
  E.decor(function()
   for _,f in ipairs({-.27,.27})do
    local bx=mid+span*f
    for _,sd in ipairs({1,-1})do
     local bz=z+sd*2.75;local o=sd*.25
     E.box(bx-4.4,y0-1.6,min(z+sd*2.3,z+sd*3.1),bx+4.4,y0-.8,max(z+sd*2.3,z+sd*3.1),'lgGold',1)
     local by=y0-1.6;local w,hh=3.6,10
     local function Q(a,b2,c2,d,m,t)if sd>0 then E.quad(a,b2,c2,d,m,t)else E.quad(b2,a,d,c2,m,t)end end
     Q({bx-w,by-hh,bz},{bx+w,by-hh,bz},{bx+w,by,bz},{bx-w,by,bz},'lgCrimson',.95)
     E.quad(sd>0 and {bx-w,by-hh,bz}or{bx+w,by-hh,bz},{bx,by-hh-3.2,bz},sd>0 and {bx+w,by-hh,bz}or{bx-w,by-hh,bz},sd>0 and {bx-w,by-hh,bz}or{bx+w,by-hh,bz},'lgCrimson',.95)
     E.box(bx-w,by-.8,min(bz,bz+o),bx+w,by,max(bz,bz+o),'lgGold',1)
     E.box(bx-w,by-hh,min(bz,bz+o),bx-w+.5,by,max(bz,bz+o),'lgGold',1)
     E.box(bx+w-.5,by-hh,min(bz,bz+o),bx+w,by,max(bz,bz+o),'lgGold',1)
    end
   end
  end)
 end
 L.stats[#L.stats+1]={'gates',E.count}
 -- flagpoles: marble staff, gold collar and finial (the cloth is animated)
 E.decor(function()
  for _,f in ipairs(L.flags)do
   local Lm=model(E,f.x,f.base,f.z,0,1)
   Lm.box(-1.4,0,-1.4,1.4,1.2,1.4,'lgVerde')
   Lm.frustum(0,1.2,0,.55,f.y-f.base,.32,6,'lgMarble')
   Lm.frustum(0,f.y-f.base-1.0,0,.5,f.y-f.base-.4,.5,6,'lgGold')
   Lm.sphere(0,f.y-f.base+.5,0,.75,.75,.75,'lgGold',6,4)
  end
 end)
 -- 10. THE RING below the open edges
 ringScape(E,L)
 L.stats[#L.stats+1]={'ring',E.count}
 -- 11. TEST167: the gorge beyond the ledge
 if L.gorge then gorgeScape(E,L)end
 L.stats[#L.stats+1]={'gorge',E.count}
 return E.count
end

------------------------------------------------------------------ gate statue
-- TEST165: the two statues in the Route 22 gate (the doorway to the badge
-- road) become bronze League eagles on marble plinths. Returned as
-- SafariStatues template faces: {x,y,z,u,v,encodedShade} x4, local 0..16.
local gateTemplate
function M.leagueStyle()
 local ok,CV=pcall(V.require,'CommunityVisuals')
 if not(ok and CV)then return true end
 local function on(f)local g,r=pcall(f);return g and r end
 return on(CV.customWalls)or on(CV.customRoads)or on(CV.referenceBuildings)or false
end
function M.gateStatueTemplate()
 if gateTemplate then return gateTemplate end
 local quads={}
 local E=newEmitter(quads,{.5/128,.5/48})
 local Lm=model(E,8,0,8,0,1)
 Lm.box(-7.2,0,-7.2,7.2,1.4,7.2,'lgVerde')
 Lm.box(-6.4,1.4,-6.4,6.4,2.4,6.4,'lgMarble')
 Lm.box(-5.4,2.4,-5.4,5.4,9.6,5.4,'lgMarble')
 E.decor(function()
  Lm.box(-5.8,6.8,-5.8,5.8,7.6,5.8,'lgGold')
  Lm.box(-2.6,4.0,5.4,2.6,6.0,5.7,'lgGold')
 end)
 Lm.box(-6.2,9.6,-6.2,6.2,10.8,6.2,'lgMarble')
 eagle(model(E,8,10.8,8.4,0,.82),17)
 local R=V.require('ReferenceMaterials')
 local out={}
 for _,q in ipairs(quads)do
  local sh=R.encode(q.referenceMaterial,q.shade)
  local face={}
  for i=1,4 do local p=q[i];face[i]={p[1],p[2],p[3],.5/128,.5/48,type(sh)=='table'and sh[i]or sh}end
  out[#out+1]=face
 end
 gateTemplate=out
 return out
end

------------------------------------------------------------------ engine
local planned={}
-- LOADING-STUTTER: a plan made from the map's tiles has its fountains' water
-- (basin discs, overflow curtains, jets, the eagles' arcs) filled in exactly as
-- a full build's geometry pass fills them: fountain() sets those four lists
-- from the fountain's own fields; its geometry goes to an emitter that keeps
-- nothing. Before, only a full Structures analysis recorded a wet plan -- in
-- warm-cache play KantoLife's synchronous habitat scan on the first Route 23
-- frame, which is gone -- so every slot rebuilt from the tiles plan had dry
-- basins. Worked out on copies and swapped in at once, with no yield between,
-- so a job cancelled half way leaves the plan untouched (and still pending).
local function nullEmitter()
 local E={out={},count=0,detail=0}
 function E.quad()end
 function E.box()end
 function E.decor(fn)fn()end
 E.vs=function(t)return t end
 return E
end
local function fillFountains(L)
 local list=L.fountains or{}
 local done={}
 local B=ownBudget()   -- in this patch's jobs: a clock check per fountain (~.3-1 ms each)
 for i,F in ipairs(list)do
  if B then B.check()end
  local C={};for k,v in pairs(F)do C[k]=v end
  fountain(nullEmitter(),C)
  done[i]=C
 end
 for i,F in ipairs(list)do
  local C=done[i];F.water,F.curtains,F.jets,F.arcs=C.water,C.curtains,C.jets,C.arcs
 end
 L.fountainsPending=nil
end
-- LOADING-STUTTER: whether layout() would return at once with a complete plan
-- (LeagueRoad's warm-ahead plans the map, or fills its fountains, in the
-- background when it would not)
function M.isPlanned(map)
 local P=map~=nil and planned[map.id]or nil
 return P~=nil and not P.fountainsPending
end
-- The plan LeagueRoad animates against. Normally recorded by build(); when
-- the map's meshes came from the disk cache and Structures never ran, plan
-- it straight from the map's tiles (nothing else claims PLATEAU tiles).
-- LOADING-STUTTER: `deferFill` (LeagueRoad's draw, with its warm-ahead on):
-- called on the frame thread, leave the fountains of a tiles plan to the
-- background job instead of filling them on this frame.
function M.layout(map,deferFill)
 if not map then return nil end
 local P=planned[map.id]
 if not P then
  if not M.enabled(map)or type(map.tileAt)~='function'then return nil end
  local ok,L=pcall(function()
   local tw,th=(map.def.width or 0)*4,(map.def.height or 0)*4
   local tileAt=function(x,y)if x<0 or y<0 or x>=tw or y>=th then return nil end;return map:tileAt(x,y)end
   local walk=function(cx,cy)local g,r=pcall(map.isWalkableCell,map,cx,cy);return g and r or false end
   local water=function(cx,cy)if not map.isWaterCell then return false end;local g,r=pcall(map.isWaterCell,map,cx,cy);return g and r or false end
   return M.analyze(map,tileAt,function()return false end,walk,water)
  end)
  if not(ok and L)then return nil end
  -- LOADING-STUTTER: in this patch's warm job analyze() yields; a full build()
  -- that recorded its plan meanwhile (fountains filled by the geometry pass)
  -- is kept, never replaced by this tiles-only one
  if not planned[map.id]then
   if L.fountains and #L.fountains>0 then L.fountainsPending=true end
   planned[map.id]=L
  end
  P=planned[map.id]
 end
 if P.fountainsPending and not(deferFill and not coroutine.running())then pcall(fillFountains,P)end
 return planned[map.id]
end
-- The ring tiles (Structures' border ring) past every OPEN edge -- one with
-- no neighbour map. Connected edges continue into the neighbour instead.
function M.ring(L,map,tileAt,skipped)
 local conn=(map.def and map.def.connections)or{}
 local open={n=not conn.north,s=not conn.south,w=not conn.west,e=not conn.east}
 local tw,th=L.tw,L.th
 local R={open=open,tiles={},cells={},walls={}}
 -- TEST166: CLAIM every ring tile, so neither this map's border block nor
 -- a neighbour's unclaimed ring is ever drawn at ground level across the
 -- forest below (Indigo's grey border floor was spilling down both sides
 -- of Route 23). EMIT forest only past open sides; anything past a
 -- connected side belongs to the neighbour (its body, or its own ring).
 local function inRing(x,y)
  if x>=0 and x<tw and y>=0 and y<th then return false end
  return tileAt(x,y)~=nil and not skipped(x,y)
 end
 -- TEST167: Route 23 and the Indigo Plateau meet plateau to plateau, so
 -- the corners past that seam are the same sunken forest, not ground.
 local sunkN=tostring(map.id)=='ROUTE_23'
 local sunkS=tostring(map.id)=='INDIGO_PLATEAU'
 R.sunkN,R.sunkS=sunkN,sunkS
 local function emits(x,y)
  local side=(x<0 and open.w)or(x>=tw and open.e)
  if y<0 and not open.n then return (side and sunkN)and true or false end
  if y>=th and not open.s then return (side and sunkS)and true or false end
  if x<0 and not open.w then return false end
  if x>=tw and not open.e then return false end
  return true
 end
 local ok={}
 for y=-RING_T,th+RING_T-1 do btick() for x=-RING_T,tw+RING_T-1 do
  if inRing(x,y)then
   local e=emits(x,y)
   R.tiles[#R.tiles+1]={x,y,e}
   if e then ok[(y+64)*4096+x+64]=true end
  end
 end end
 local function has(x,y)return ok[(y+64)*4096+x+64]end
 for cy=floor(-RING_T/2),floor((th+RING_T)/2)-1 do btick() for cx=floor(-RING_T/2),floor((tw+RING_T)/2)-1 do
  local x,y=cx*2,cy*2
  if has(x,y)and has(x+1,y)and has(x,y+1)and has(x+1,y+1)then R.cells[#R.cells+1]={cx,cy}end
 end end
 -- Route 23 runs south into Route 22, which sits at ground level: the
 -- sunken ring needs an end wall there
 if map.id=='ROUTE_23'and conn.south then
  for _,side in ipairs({{-RING_T,-1},{tw,tw+RING_T-1}})do
   if (side[1]<0 and open.w)or(side[1]>=tw and open.e)then
    R.walls[#R.walls+1]={side[1]*8,(side[2]+1)*8,th*8}
   end
  end
 end
 return R
end

-- Structures hook: claim the vocabulary and append the architecture.
function M.build(S,map)
 if not M.enabled(map)then return 0 end
 -- LOADING-STUTTER: a claims-only build runs in KantoLife's own job (sliced
 -- through sliceJob) and leaves the global budget exactly as it was
 if not S.lightweight then Budget=V.require('BuildBudget')end
 local L=M.plan(map,S)
 local key=function(x,y)return(y+64)*4096+x+64 end
 L.ring=M.ring(L,map,function(x,y)return S.tileAt[key(x,y)]end,function(x,y)return S.skip[key(x,y)]and true or false end)
 L.gorge=nil;M.gorgePlan(L,map)
 local t=function(x,y)if x<0 or y<0 or x>=L.tw or y>=L.th then return nil end;return S.tileAt[key(x,y)]end
 -- an opaque donor texel (tile 35, plain paving) for the shadow alpha test
 local perRow=16
 local u=((35%perRow)*8+3.5)/128;local v=(floor(35/perRow)*8+3.5)/40
 -- LOADING-STUTTER: a claims-only analysis (KantoLife's habitat) skips the
 -- geometry -- 90% of Route 23's analysis -- and leaves `planned` alone.
 local n=S.lightweight and 0 or M.emit(L,t,S.objectQuads,{u,v})
 local function claim(k)
  S.skip[k]=true;S.ground[k]=false
  S.shapeAt[k]={class='ground',h=0,art='flat',flat=true,authored=true}
 end
 for y=0,L.th-1 do btick() for x=0,L.tw-1 do
  if L.cls[L.K(x,y)]then claim(key(x,y))end
 end end
 -- TEST167: a ring tile under the sunken forest has NO engine ground at all.
 -- `false` asks Structures' end-of-build vote for the map's commonest ground,
 -- which drew the checker paving at road level straight across the forest.
 for _,tl in ipairs(L.ring.tiles)do
  local k=key(tl[1],tl[2]);claim(k)
  if tl[3]then S.ground[k]=nil end
 end
 if not S.lightweight then planned[map.id]=L end
 S.leagueArchitecture={quads=n,statues=#L.statues,eagles=#L.eagles,trees=#L.garden+#L.trees,lamps=#L.lamps,gates=#L.gates}
 return n
end
-- TEST167: the gorges fall far below the engine's fill plane (WorldUnderlay,
-- Y=-20); on the League maps it is lowered under the valley floor.
function M.underlayDrop(map)
 if map and(map.id=='ROUTE_23'or map.id=='INDIGO_PLATEAU')and M.enabled(map)then return GZ.FLOOR-30 end
 -- TEST172: Lance's abyss
 local okR,R=pcall(V.require,'LeagueRooms')
 if okR and R and R.underlayDrop then local ok,d=pcall(R.underlayDrop,map);if ok and d then return d end end
 return 0
end
-- TEST166: the emitter and models, shared with the Route 22 gate's
-- antechamber (LeagueGateRoom) so it is built in the very same finishes.
M.kit={newEmitter=newEmitter,model=model,eagle=eagle,urn=urn,inscription=inscription,
 doorway=doorway,fireBowl=fireBowl,octagon=octagon,dirShade=dirShade,rh=rh}
return M
