-- TEST164: the road to the Pokemon League, animated.
--
-- With LeagueArchitecture on (any of the community wall/road/building
-- options), the gates, carpet and League hall are real map geometry, and
-- this pass adds only what moves or glows, anchored to that layout:
--   * fire in every obelisk brazier and in the hall's eternal-flame bowls
--   * each checkpoint's BADGE turning above its crossbeam in a halo of its
--     colour, a badge-coloured emblem on both banners, light on the path
--   * the parapet lanterns' halos after dark
--   * golden motes along Route 23; searchlights and fireworks over the League
-- With the architecture off, the TEST163 standalone gates and carpet are
-- drawn as before, now labelled by the guard's row so the two swimmer
-- checkpoints keep their own badges (Soul and Marsh).
--
-- Presentation only: no collision, warp, tile or script changes.
local V=...
local Assets=require("src.render.Assets")
local Mat4=V.require("Mat4")
local Voxel3D=V.require("Voxel3D")

local M={REVISION='league-road-245'}
local cache=setmetatable({},{__mode='k'})
-- LOADING-STUTTER: League maps the warm-ahead found about to come into view
-- (map -> time); setLive keeps their slots a moment longer (see warmAhead)
local warmKeep=setmetatable({},{__mode='k'})
M.WARM_KEEP_SECONDS=2
local whiteTex,softTex,unitCross,unitQuad,coneMesh,unitPanel,flameTex,streakTex,ringTex
local pi,cos,sin,floor,min,max,abs,sqrt=math.pi,math.cos,math.sin,math.floor,math.min,math.max,math.abs,math.sqrt
local function rh(a,b,s)local v=sin(a*12.9898+b*78.233+s*37.719)*43758.5453;return v-floor(v)end

local function newTex(w,h,fn,nearest)
 local ok,img=pcall(function()
  local d=love.image.newImageData(w,h)
  for y=0,h-1 do for x=0,w-1 do d:setPixel(x,y,1,1,1,fn(x,y))end end
  local made=love.graphics.newImage(d,{mipmaps=false})
  made:setFilter(nearest and"nearest"or"linear",nearest and"nearest"or"linear");made:setWrap("clamp","clamp")
  d:release();return made
 end)
 return ok and img or nil
end
local function white()if not whiteTex then whiteTex=newTex(2,2,function()return 1 end,true)end;return whiteTex end
local function soft()
 if not softTex then softTex=newTex(64,64,function(x,y)
  local u,v=(x+.5)/32-1,(y+.5)/32-1;local r=sqrt(u*u+v*v)
  if r>=1 then return 0 end;return min(1,(1-r)^1.8*1.3)end)end
 return softTex
end

-- A teardrop flame: soft round base narrowing into a tip.
local function flameT()
 if not flameTex then flameTex=newTex(48,96,function(x,y)
  local u=(x+.5)/24-1;local v=(y+.5)/96            -- image row 0 = flame base
  local w=v<.32 and sqrt(max(0,1-((v-.32)/.32)^2))or max(0,1-(v-.32)/.68)^1.25
  w=w*.95
  if w<=.001 then return 0 end
  local d=abs(u)/w
  if d>=1 then return 0 end
  local a=(1-d*d)^1.4*min(1,v*6)*min(1,(1-v)*3.5)
  return min(1,a*1.25)
 end)end
 return flameTex
end

-- TEST166: falling-water streaks (curtains, jets) and a thin ripple ring.
local function streakT()
 if not streakTex then streakTex=newTex(32,64,function(x,y)
  local u=(x+.5)/32;local v=(y+.5)/64
  local s=.55+.45*sin(u*6.283*5+sin(u*31)*1.7)
  s=s*(.7+.3*sin(u*6.283*11+1.3))
  local edge=min(1,v*5)*min(1,(1-v)*2.5)
  return max(0,min(1,s*edge))
 end)end
 return streakTex
end
local function ringT()
 if not ringTex then ringTex=newTex(64,64,function(x,y)
  local u,v=(x+.5)/32-1,(y+.5)/32-1;local r=sqrt(u*u+v*v)
  local d=abs(r-.86)
  return max(0,1-d/.08)^1.6
 end)end
 return ringTex
end

------------------------------------------------------------------ geometry
local function group()return{verts={},indices={},quads=0}end
local function quad(g,a,b,c,d,shade)
 local s=shade or 1
 g.verts[#g.verts+1]={a[1],a[2],a[3],0,0,s};g.verts[#g.verts+1]={b[1],b[2],b[3],1,0,s}
 g.verts[#g.verts+1]={c[1],c[2],c[3],1,1,s};g.verts[#g.verts+1]={d[1],d[2],d[3],0,1,s}
 Voxel3D.pushQuad(g.indices,g.quads);g.quads=g.quads+1
end
local function mesh(g)if g.quads==0 then return nil end;return Voxel3D.newMesh(g.verts,g.indices)end
local function units()
 if not unitQuad then local g=group();quad(g,{-1,0,-1},{1,0,-1},{1,0,1},{-1,0,1});unitQuad=mesh(g)end
 if not unitCross then local g=group()
  quad(g,{-1,-1,0},{1,-1,0},{1,1,0},{-1,1,0});quad(g,{0,-1,-1},{0,-1,1},{0,1,1},{0,1,-1});unitCross=mesh(g)end
 if not unitPanel then
  -- a vertical panel from (0,0) to (1,1) in the XY plane, for cloth strips
  local g=group();quad(g,{0,0,0},{1,0,0},{1,1,0},{0,1,0});unitPanel=mesh(g)
 end
 if not coneMesh then
  local g,n=group(),14
  for i=0,n-1 do local a0,a1=i/n*pi*2,(i+1)/n*pi*2
   quad(g,{cos(a0)*.12,0,sin(a0)*.12},{cos(a1)*.12,0,sin(a1)*.12},{cos(a1),1,sin(a1)},{cos(a0),1,sin(a0)})end
  coneMesh=mesh(g)
 end
end
-- an axis-aligned box with face shading
local function box(g,x0,y0,z0,x1,y1,z1,k)
 k=k or 1
 quad(g,{x0,y1,z0},{x1,y1,z0},{x1,y1,z1},{x0,y1,z1},1.0*k)
 quad(g,{x0,y0,z1},{x1,y0,z1},{x1,y1,z1},{x0,y1,z1},.86*k)
 quad(g,{x1,y0,z0},{x0,y0,z0},{x0,y1,z0},{x1,y1,z0},.70*k)
 quad(g,{x0,y0,z0},{x0,y0,z1},{x0,y1,z1},{x0,y1,z0},.78*k)
 quad(g,{x1,y0,z1},{x1,y0,z0},{x1,y1,z0},{x1,y1,z1},.78*k)
end
-- a tapering square column (obelisk shaft) from y0 (half width a) to y1 (b)
local function taper(g,x,z,y0,y1,a,b,k)
 k=k or 1
 local P0={{x-a,z-a},{x+a,z-a},{x+a,z+a},{x-a,z+a}}
 local P1={{x-b,z-b},{x+b,z-b},{x+b,z+b},{x-b,z+b}}
 local sh={.70,.78,.86,.78}
 for i=1,4 do local j=i%4+1
  quad(g,{P0[i][1],y0,P0[i][2]},{P0[j][1],y0,P0[j][2]},{P1[j][1],y1,P1[j][2]},{P1[i][1],y1,P1[i][2]},sh[i]*k)
 end
 quad(g,{P1[1][1],y1,P1[1][2]},{P1[2][1],y1,P1[2][2]},{P1[3][1],y1,P1[3][2]},{P1[4][1],y1,P1[4][2]},k)
end
-- flat polygon "disc" in the x/y plane facing +z and -z, at depth z
local function disc(g,cx,cy,z,r,n,rot,ry,depth)
 n=n or 16;rot=rot or 0;ry=ry or r;depth=depth or .5
 for i=0,n-1 do local a0,a1=rot+i/n*pi*2,rot+(i+1)/n*pi*2
  local p0={cx+cos(a0)*r,cy+sin(a0)*ry};local p1={cx+cos(a1)*r,cy+sin(a1)*ry}
  quad(g,{cx,cy,z+depth},{p0[1],p0[2],z+depth},{p1[1],p1[2],z+depth},{cx,cy,z+depth},1)
  quad(g,{cx,cy,z-depth},{p1[1],p1[2],z-depth},{p0[1],p0[2],z-depth},{cx,cy,z-depth},.8)
  quad(g,{p0[1],p0[2],z-depth},{p1[1],p1[2],z-depth},{p1[1],p1[2],z+depth},{p0[1],p0[2],z+depth},.9)
 end
end
local function star(g,cx,cy,z,r1,r2,n,depth)
 depth=depth or .5
 local pts={}
 for i=0,n*2-1 do local a=i/(n*2)*pi*2-pi/2;local r=i%2==0 and r1 or r2;pts[#pts+1]={cx+cos(a)*r,cy+sin(a)*r}end
 for i=1,#pts do local p0,p1=pts[i],pts[i%#pts+1]
  quad(g,{cx,cy,z+depth},{p0[1],p0[2],z+depth},{p1[1],p1[2],z+depth},{cx,cy,z+depth},1)
  quad(g,{cx,cy,z-depth},{p1[1],p1[2],z-depth},{p0[1],p0[2],z-depth},{cx,cy,z-depth},.8)
  quad(g,{p0[1],p0[2],z-depth},{p1[1],p1[2],z-depth},{p1[1],p1[2],z+depth},{p0[1],p0[2],z+depth},.9)
 end
end

-- The seven badges checked on Route 23, south to north, as emblem builders.
-- Each returns {mesh=..., col=..} parts centred at the origin, ~5 units across.
local BADGES={
 {name='CASCADE',col={.35,.65,1.0},build=function(add)
   add({.45,.75,1},function(g)disc(g,0,-.8,0,2.6,18,0,2.6,.6);taper(g,0,0,.9,4.6,0,0)end)
   add({.45,.75,1},function(g)local n=8 for i=0,n-1 do local a0,a1=i/n*pi*2,(i+1)/n*pi*2
     quad(g,{0,4.8,0},{cos(a0)*1.9,.9,sin(a0)*.6},{cos(a1)*1.9,.9,sin(a1)*.6},{0,4.8,0},1)end end)end},
 {name='THUNDER',col={1.0,.70,.20},build=function(add)
   add({1,.72,.22},function(g)star(g,0,0,0,3.0,2.1,8,.6)end)
   add({.30,.85,.35},function(g)disc(g,0,0,.75,1.2,10,0,1.2,.15)end)end},
 {name='RAINBOW',col={.95,.55,.95},build=function(add)
   local cols={{1,.3,.3},{1,.65,.2},{1,.95,.3},{.3,.9,.4},{.35,.6,1},{.75,.4,1}}
   for i=1,6 do local a=i/6*pi*2
     add(cols[i],function(g)disc(g,cos(a)*1.9,sin(a)*1.9,0,1.25,10,0,1.25,.5)end)end
   add({1,1,.85},function(g)disc(g,0,0,.4,1.0,10,0,1.0,.3)end)end},
 {name='SOUL',col={1.0,.45,.70},build=function(add)
   add({1,.45,.72},function(g)
     disc(g,-1.2,.9,0,1.55,14,0,1.55,.6);disc(g,1.2,.9,0,1.55,14,0,1.55,.6)
     local d=.6
     quad(g,{-2.65,.6,d},{2.65,.6,d},{0,-3.0,d},{0,-3.0,d},1)
     quad(g,{2.65,.6,-d},{-2.65,.6,-d},{0,-3.0,-d},{0,-3.0,-d},.8)end)end},
 {name='MARSH',col={1.0,.82,.30},build=function(add)
   add({1,.82,.30},function(g)disc(g,0,0,0,2.9,20,0,2.9,.45)end)
   add({.55,.38,.12},function(g)disc(g,0,0,.5,2.0,20,0,2.0,.1)end)
   add({1,.86,.38},function(g)disc(g,0,0,.62,1.1,16,0,1.1,.1)end)end},
 {name='VOLCANO',col={1.0,.32,.15},build=function(add)
   add({1,.32,.15},function(g)disc(g,0,0,0,2.9,4,pi/2,3.4,.6)end)
   add({1,.75,.25},function(g)disc(g,0,-.2,.65,1.5,4,pi/2,1.9,.12)end)end},
 {name='EARTH',col={.35,.85,.40},build=function(add)
   add({.35,.85,.42},function(g)disc(g,0,0,0,2.4,4,pi/2,3.3,.6)end)
   add({.65,1,.55},function(g)disc(g,0,.6,.65,.9,4,pi/2,1.4,.12)end)end},
}

local BYNAME={}
for _,b in ipairs(BADGES)do BYNAME[b.name]=b end
-- TEST166: Pewter's badge too (not checked on the road; the Route 22 gate's
-- antechamber shows all eight). Kept out of BADGES so the road's order holds.
BYNAME.BOULDER={name='BOULDER',col={.72,.74,.80},build=function(add)
  add({.70,.72,.78},function(g)disc(g,0,0,0,2.8,8,pi/8,2.8,.6)end)
  add({.90,.92,.96},function(g)disc(g,0,0,.65,1.5,8,pi/8,1.5,.12)end)end}
local function architecture()
 local ok,LA=pcall(V.require,"LeagueArchitecture")
 return ok and LA or nil
end

------------------------------------------------------------------ build
local function walk(map,cx,cy)local ok,r=pcall(map.isWalkableCell,map,cx,cy);return ok and r or false end
local function groundAt(map,cx,cy)
 local ok,h=pcall(V.require("VoxelScene").groundAt,map,cx,cy,cx*16,cy*16)
 return(ok and tonumber(h))or 0
end

local function buildRoute23(map)
 local out={gates={},kind='route'}
 local guards={}
 for _,o in ipairs((map.def and map.def.objects)or{})do
  if not o.runtime and type(o.x)=='number'and type(o.y)=='number'then guards[#guards+1]=o end
 end
 table.sort(guards,function(a,b)return a.y>b.y end)   -- south first
 local used={}
 local marble,gold,dark=group(),group(),group()
 local emblems={}
 local bi=0
 for _,o in ipairs(guards)do
  if not used[o.y]then
   -- the open run across the guard's row
   local xa,xb=o.x,o.x
   while xa-1>=0 and walk(map,xa-1,o.y)and o.x-xa<12 do xa=xa-1 end
   while walk(map,xb+1,o.y)and xb-o.x<12 do xb=xb+1 end
   if xb-xa>=1 then
    used[o.y]=true;bi=bi+1
    local LA=architecture()
    local name=LA and LA.BADGES and LA.BADGES[o.y]
    local badge=(name and BYNAME[name])or BADGES[min(bi,#BADGES)]
    local fy=groundAt(map,o.x,o.y)
    local z=o.y*16+8
    local L,R=xa*16-7,(xb+1)*16+7
    local top=62
    for _,x in ipairs({L,R})do
     box(marble,x-7,fy,z-7,x+7,fy+5,z+7)                -- plinth
     box(gold,x-7.4,fy+5,z-7.4,x+7.4,fy+6.2,z+7.4)       -- gilded course
     taper(marble,x,z,fy+6.2,fy+top-6,5.2,3.4)          -- obelisk shaft
     box(gold,x-4,fy+top-6,z-4,x+4,fy+top-4.6,z+4)       -- collar
     taper(gold,x,z,fy+top-4.6,fy+top-1,3.2,4.4)        -- brazier bowl (flaring)
     box(dark,x-3.6,fy+top-1.2,z-3.6,x+3.6,fy+top-.9,z+3.6,.5)
    end
    -- crossbeam between the obelisks
    local by=fy+38
    box(marble,L+3,by,z-2.4,R-3,by+3.4,z+2.4)
    box(gold,L+3,by+3.4,z-2.7,R-3,by+4.2,z+2.7)
    box(gold,L+3,by-.8,z-2.7,R-3,by,z+2.7)
    -- banner rods
    local mid=(L+R)/2;local span=R-L
    local banners={}
    for _,f in ipairs({-.30,.30})do
     local bx=mid+span*f*.8
     box(gold,bx-4.2,by-1.6,z+2.6,bx+4.2,by-.9,z+3.2)
     banners[#banners+1]={x=bx,y=by-1.4,z=z+2.95}
    end
    local parts={}
    badge.build(function(col,fn)local g=group();fn(g);parts[#parts+1]={mesh=mesh(g),col=col}end)
    out.gates[#out.gates+1]={x=mid,z=z,y=by+13.5,badge=badge,parts=parts,banners=banners,
     fires={{x=L,y=fy+top-.6,z=z},{x=R,y=fy+top-.6,z=z}},phase=rh(o.x,o.y,5)*9,fy=fy}
   end
  end
 end
 out.marble,out.gold,out.dark=mesh(marble),mesh(gold),mesh(dark)
 -- banner cloth, one quad mesh per gate drawn with its badge colour
 for _,gt in ipairs(out.gates)do
  local g=group()
  for _,b in ipairs(gt.banners)do
   local w,h=3.6,8
   quad(g,{b.x-w,b.y,b.z},{b.x+w,b.y,b.z},{b.x+w,b.y-h,b.z},{b.x-w,b.y-h,b.z},1)
   quad(g,{b.x-w,b.y-h,b.z},{b.x+w,b.y-h,b.z},{b.x,b.y-h-3,b.z},{b.x,b.y-h-3,b.z},1)
  end
  gt.cloth=mesh(g)
  local t=group()
  for _,b in ipairs(gt.banners)do
   -- gold trim and a white emblem disc on each banner
   quad(t,{b.x-3.8,b.y,b.z+.05},{b.x+3.8,b.y,b.z+.05},{b.x+3.8,b.y-.8,b.z+.05},{b.x-3.8,b.y-.8,b.z+.05},1)
   disc(t,b.x,b.y-5.6,b.z+.1,1.9,12,0,1.9,.02)
  end
  gt.trim=mesh(t)
 end
 return out
end

local function buildPlateau(map)
 local out={kind='plateau',braziers={},lights={}}
 local door
 for _,w in ipairs((map.def and map.def.warps)or{})do
  if tostring(w.destMap or""):find("INDIGO_PLATEAU_LOBBY",1,true)then
   if not door or w.x<door.x then door={x=w.x,y=w.y,w=1}end
  end
 end
 if not door then return out end
 for _,w in ipairs((map.def and map.def.warps)or{})do
  if tostring(w.destMap or""):find("INDIGO_PLATEAU_LOBBY",1,true)and w.y==door.y and w.x==door.x+door.w then door.w=door.w+1 end
 end
 local cy=door.y+1;local fy=groundAt(map,door.x,cy)
 local x0,x1=door.x*16+2,(door.x+door.w)*16-2
 local carpet,gold=group(),group()
 local last=cy
 while walk(map,door.x,last)and last-cy<14 do last=last+1 end
 local z0,z1=cy*16-6,last*16
 quad(carpet,{x0,fy+.22,z0},{x1,fy+.22,z0},{x1,fy+.22,z1},{x0,fy+.22,z1},1)
 quad(gold,{x0-1.4,fy+.2,z0},{x0,fy+.2,z0},{x0,fy+.2,z1},{x0-1.4,fy+.2,z1},1)
 quad(gold,{x1,fy+.2,z0},{x1+1.4,fy+.2,z0},{x1+1.4,fy+.2,z1},{x1,fy+.2,z1},1)
 out.carpet,out.carpetGold=mesh(carpet),mesh(gold)
 -- braziers lining the carpet every two cells
 local bz=group()
 for zz=cy+1,last-1,2 do
  for _,x in ipairs({x0-9,x1+9})do
   local z=zz*16+8
   taper(bz,x,z,fy,fy+9,1.4,.9);taper(bz,x,z,fy+9,fy+12,1.2,2.6)
   out.braziers[#out.braziers+1]={x=x,y=fy+12.6,z=z,phase=rh(x,z,3)*9}
  end
 end
 out.stands=mesh(bz)
 -- searchlights at the plaza's four corners (walkable extremes)
 local wc,hc=map.widthCells or 20,map.heightCells or 20
 local cx=(door.x+door.w/2)*16
 for i,c in ipairs({{-1,0},{1,0},{-1,1},{1,1}})do
  out.lights[#out.lights+1]={x=cx+c[1]*wc*5.5,z=(cy+2+c[2]*(hc-cy-4)*.7)*16,y=fy,phase=i*1.7}
 end
 out.sky={x=cx,z=door.y*16-220,y=fy+140}
 return out
end

-- TEST166: the fountains' water. Static meshes in world space (discs,
-- overflow curtains, the jet column and the eagles' arcs) plus one stream
-- mesh per fountain for the spray, rebuilt each frame it is drawn.
local function parabola(a,b,h,t)
 return a[1]+(b[1]-a[1])*t,a[2]+(b[2]-a[2])*t+4*h*t*(1-t),a[3]+(b[3]-a[3])*t
end
local function buildFountain(F)
 local fo={x=F.x,z=F.z,y=F.y,kind=F.kind,jets=F.jets or{},arcs=F.arcs or{},water=F.water or{},
  phase=rh(F.x,F.z,7)*9}
 local d=group()
 for _,w in ipairs(fo.water)do
  local n=24
  for i=0,n-1 do
   local a0,a1=i/n*pi*2,(i+1)/n*pi*2
   quad(d,{F.x,w.y,F.z},{F.x+cos(a0)*w.r,w.y,F.z+sin(a0)*w.r},{F.x+cos(a1)*w.r,w.y,F.z+sin(a1)*w.r},{F.x,w.y,F.z},1)
  end
 end
 fo.discs=mesh(d)
 local c=group()
 for _,cu in ipairs(F.curtains or{})do
  local n=20
  for i=0,n-1 do
   local a0,a1=i/n*pi*2,(i+1)/n*pi*2
   local r0,r1=cu.r,cu.r+.25
   local p=#c.verts
   c.verts[p+1]={F.x+cos(a0)*r0,cu.y1,F.z+sin(a0)*r0,(i%5)/5,0,1}
   c.verts[p+2]={F.x+cos(a1)*r0,cu.y1,F.z+sin(a1)*r0,(i%5+1)/5,0,1}
   c.verts[p+3]={F.x+cos(a1)*r1,cu.y0,F.z+sin(a1)*r1,(i%5+1)/5,1,1}
   c.verts[p+4]={F.x+cos(a0)*r1,cu.y0,F.z+sin(a0)*r1,(i%5)/5,1,1}
   Voxel3D.pushQuad(c.indices,c.quads);c.quads=c.quads+1
  end
 end
 fo.curtains=mesh(c)
 local j=group()
 local function ribbon(pts,w)
  for k=1,#pts-1 do
   local a,b=pts[k],pts[k+1]
   for _,ax in ipairs({{w,0,0},{0,0,w}})do
    local p=#j.verts
    j.verts[p+1]={a[1]-ax[1],a[2],a[3]-ax[3],0,1-(k-1)/(#pts-1),1}
    j.verts[p+2]={a[1]+ax[1],a[2],a[3]+ax[3],1,1-(k-1)/(#pts-1),1}
    j.verts[p+3]={b[1]+ax[1],b[2],b[3]+ax[3],1,1-k/(#pts-1),1}
    j.verts[p+4]={b[1]-ax[1],b[2],b[3]-ax[3],0,1-k/(#pts-1),1}
    Voxel3D.pushQuad(j.indices,j.quads);j.quads=j.quads+1
   end
  end
 end
 for _,je in ipairs(fo.jets)do
  ribbon({{je.x,je.base,je.z},{je.x,je.base+je.h*.5,je.z},{je.x,je.base+je.h,je.z}},.32)
 end
 for _,ar in ipairs(fo.arcs)do
  local pts={}
  for k=0,8 do pts[#pts+1]={parabola({ar.x0,ar.y0,ar.z0},{ar.x1,ar.y1,ar.z1},ar.h,k/8)}end
  ribbon(pts,.22)
 end
 fo.jetMesh=mesh(j)
 -- spray: 18 drops around the crown of each jet, 4 along each arc
 fo.ndrops=#fo.jets*18+#fo.arcs*4
 if fo.ndrops>0 then
  local nv=fo.ndrops*8
  local verts={}
  for i=1,nv do verts[i]={0,0,0,0,0,1}end
  local ok,m=pcall(love.graphics.newMesh,Voxel3D.FORMAT,verts,"triangles","stream")
  if ok and m then
   local idx={}
   for q=0,fo.ndrops*2-1 do Voxel3D.pushQuad(idx,q)end
   pcall(m.setVertexMap,m,idx)
   fo.spray=m;fo.sprayVerts=verts
  end
 end
 return fo
end
local function updateSpray(fo,t)
 local v=fo.sprayVerts;if not(v and fo.spray)then return end
 local n=0
 local function drop(x,y,z,s)
  for _,ax in ipairs({{s,0},{0,s}})do
   local function put(px,py,pz,u,w)n=n+1;local e=v[n];e[1],e[2],e[3],e[4],e[5]=px,py,pz,u,w end
   put(x-ax[1],y-s,z-ax[2],0,0);put(x+ax[1],y-s,z+ax[2],1,0);put(x+ax[1],y+s,z+ax[2],1,1);put(x-ax[1],y+s,z-ax[2],0,1)
  end
 end
 for _,je in ipairs(fo.jets)do
  for i=0,17 do
   local life=(t*.55+i/18+fo.phase)%1
   local a=i*2.39996+fo.phase
   local r=je.spread*life
   local top=je.base+je.h
   local y=top-6.0*life*life*je.h/6
   if y<je.base then y=je.base end
   drop(je.x+cos(a)*r,y,je.z+sin(a)*r,.30+.15*(1-life))
  end
 end
 for k,ar in ipairs(fo.arcs)do
  for i=0,3 do
   local life=(t*.9+i/4+k*.13+fo.phase)%1
   local x,y,z=parabola({ar.x0,ar.y0,ar.z0},{ar.x1,ar.y1,ar.z1},ar.h,life)
   drop(x,y,z,.28)
  end
 end
 pcall(fo.spray.setVertices,fo.spray,v)
end

-- TEST167: the gorge's water -- rivers, waterfalls, plunge pools and mist,
-- from LeagueArchitecture.gorgePlan(). Per-frame flecks ride stream meshes.
local function newStream(n)
 local verts={}
 for i=1,n*8 do verts[i]={0,0,0,0,0,1}end
 local ok,m=pcall(love.graphics.newMesh,Voxel3D.FORMAT,verts,"triangles","stream")
 if not(ok and m)then return nil end
 local idx={};for q=0,n*2-1 do Voxel3D.pushQuad(idx,q)end
 pcall(m.setVertexMap,m,idx)
 return{mesh=m,verts=verts,n=n}
end
-- (TEST172: written without a closure per particle; this runs for every
-- spark of every firework every frame)
local function streamPut(sm,i,x,y,z,sz,flat)
 local v=sm.verts;local b=i*8
 local e
 if flat then
  e=v[b+1];e[1],e[2],e[3],e[4],e[5]=x-sz,y,z-sz,0,0
  e=v[b+2];e[1],e[2],e[3],e[4],e[5]=x+sz,y,z-sz,1,0
  e=v[b+3];e[1],e[2],e[3],e[4],e[5]=x+sz,y,z+sz,1,1
  e=v[b+4];e[1],e[2],e[3],e[4],e[5]=x-sz,y,z+sz,0,1
  for k=5,8 do e=v[b+k];e[1],e[2],e[3],e[4],e[5]=x,y,z,0,0 end
 else
  e=v[b+1];e[1],e[2],e[3],e[4],e[5]=x-sz,y-sz,z,0,0
  e=v[b+2];e[1],e[2],e[3],e[4],e[5]=x+sz,y-sz,z,1,0
  e=v[b+3];e[1],e[2],e[3],e[4],e[5]=x+sz,y+sz,z,1,1
  e=v[b+4];e[1],e[2],e[3],e[4],e[5]=x-sz,y+sz,z,0,1
  e=v[b+5];e[1],e[2],e[3],e[4],e[5]=x,y-sz,z-sz,0,0
  e=v[b+6];e[1],e[2],e[3],e[4],e[5]=x,y-sz,z+sz,1,0
  e=v[b+7];e[1],e[2],e[3],e[4],e[5]=x,y+sz,z+sz,1,1
  e=v[b+8];e[1],e[2],e[3],e[4],e[5]=x,y+sz,z-sz,0,1
 end
end
local function polyLen(pts)
 local Ls={0}
 for i=2,#pts do local a,b=pts[i-1],pts[i];Ls[i]=Ls[i-1]+sqrt((b[1]-a[1])^2+(b[2]-a[2])^2+(b[3]-a[3])^2)end
 return Ls
end
local function polyAt(pts,Ls,s)
 local target=s*Ls[#Ls]
 local lo,hi=1,#pts
 while hi-lo>1 do local m=floor((lo+hi)/2);if Ls[m]<=target then lo=m else hi=m end end
 local a,b=pts[lo],pts[hi];local seg=Ls[hi]-Ls[lo]
 local u=seg>1e-6 and(target-Ls[lo])/seg or 0
 local hl=sqrt((b[1]-a[1])^2+(b[3]-a[3])^2);if hl<1e-6 then hl=1 end
 return a[1]+(b[1]-a[1])*u,a[2]+(b[2]-a[2])*u,a[3]+(b[3]-a[3])*u,(b[1]-a[1])/hl,(b[3]-a[3])/hl
end
local function buildGorge(G)
 local gw={rivers={},falls={},mist=G.mist or{},x0=G.x0,x1=G.x1,zA=G.zA,zB=G.zB}
 for ri,pts in ipairs(G.rivers or{})do
  local n=#pts
  if n>=2 then
   local g=group()
   local function edge(k)
    local p0,p1=pts[max(1,k-1)],pts[min(n,k+1)]
    local dx,dz=p1[1]-p0[1],p1[3]-p0[3];local l=sqrt(dx*dx+dz*dz);if l<1e-6 then l=1 end
    local w=24*min(1,(k-1)/3+.2,(n-k)/3+.2)
    return -dz/l*w,dx/l*w
   end
   for i=1,n-1 do
    local a,b=pts[i],pts[i+1]
    local ax,az=edge(i);local bx,bz=edge(i+1)
    quad(g,{a[1]-ax,a[2],a[3]-az},{a[1]+ax,a[2],a[3]+az},{b[1]+bx,b[2],b[3]+bz},{b[1]-bx,b[2],b[3]-bz},1)
   end
   gw.rivers[#gw.rivers+1]={mesh=mesh(g),pts=pts,L=polyLen(pts),glints=newStream(80),phase=ri*.37}
  end
 end
 for fi,f in ipairs(G.falls or{})do
  local pts=f.pts;local n=#pts
  local tx,tz=-f.nz,f.nx
  local function ribbon(wd,lift)
   local c=group()
   for k=1,n-1 do
    local a,b=pts[k],pts[k+1]
    local v0,v1=(k-1)/(n-1),k/(n-1)
    local p=#c.verts
    c.verts[p+1]={a[1]-tx*wd,a[2]+lift,a[3]-tz*wd,0,v0,1}
    c.verts[p+2]={a[1]+tx*wd,a[2]+lift,a[3]+tz*wd,1,v0,1}
    c.verts[p+3]={b[1]+tx*wd,b[2]+lift,b[3]+tz*wd,1,v1,1}
    c.verts[p+4]={b[1]-tx*wd,b[2]+lift,b[3]-tz*wd,0,v1,1}
    Voxel3D.pushQuad(c.indices,c.quads);c.quads=c.quads+1
   end
   return mesh(c)
  end
  local pool=group();local pr=f.pool
  for i=0,19 do
   local a0,a1=i/20*pi*2,(i+1)/20*pi*2
   quad(pool,{pr.x,pr.y,pr.z},{pr.x+cos(a0)*pr.r,pr.y,pr.z+sin(a0)*pr.r},{pr.x+cos(a1)*pr.r,pr.y,pr.z+sin(a1)*pr.r},{pr.x,pr.y,pr.z},1)
  end
  gw.falls[#gw.falls+1]={c1=ribbon(f.w/2,0),c2=ribbon(f.w*.7,.8),pool=mesh(pool),drops=newStream(40),
   pts=pts,L=polyLen(pts),w=f.w,tx=tx,tz=tz,nx=f.nx,nz=f.nz,phase=fi*1.9,
   x=pr.x,z=pr.z,px=pr.x,py=pr.y,pz=pr.z,pr=pr.r,lx=pts[1][1],ly=pts[1][2],lz=pts[1][3]}
 end
 return gw
end
local function updateGlints(rv,t)
 local sm=rv.glints;if not sm then return end
 local W=V.require("LeagueArchitecture").GZ.WATER
 for i=0,sm.n-1 do
  local sp=(t*.010+i/sm.n+rv.phase)%1
  local x,_,z,dx,dz=polyAt(rv.pts,rv.L,sp)
  local off=(rh(i,rv.phase,5)-.5)*34
  local tw=max(0,sin(t*2.7+i*1.7))
  streamPut(sm,i,x-dz*off,W+.2,z+dx*off,.5+1.1*tw,true)
 end
 pcall(sm.mesh.setVertices,sm.mesh,sm.verts)
end
local function updateFall(fl,t)
 local sm=fl.drops;if not sm then return end
 for i=0,sm.n-1 do
  local life=(t*.42+i/sm.n+fl.phase)%1
  local x,y,z=polyAt(fl.pts,fl.L,life)
  local off=(rh(i,fl.phase,9)-.5)*fl.w
  streamPut(sm,i,x+fl.tx*off+fl.nx*1.2,y+.6,z+fl.tz*off+fl.nz*1.2,.45+.9*life,false)
 end
 pcall(sm.mesh.setVertices,sm.mesh,sm.verts)
end

-- The architecture's layout: badges over the real gates, real flame bowls.
-- LOADING-STUTTER: yield points for a background build of the slot (the
-- warm-ahead below); outside a pumped job BuildBudget.check returns at once.
local function yieldPoint()local ok,B=pcall(V.require,"BuildBudget");if ok and B and B.check then B.check()end end
local function buildArch(map,L,track)
 local out={kind='arch',gates={},flames={},lamps={},route=tostring(map.id)=='ROUTE_23'}
 -- LOADING-STUTTER: a background build's slot-in-progress (every mesh made so
 -- far hangs off `out` at each yield point), for release() should it be cancelled
 if track then track.slot=out end
 for _,gt in ipairs(L.gates or{})do
  yieldPoint()
  local badge=BYNAME[gt.badge]
  if badge then
   local mid=(gt.L+gt.R)/2;local span=gt.R-gt.L
   local parts={}
   badge.build(function(col,fn)local g=group();fn(g);parts[#parts+1]={mesh=mesh(g),col=col}end)
   local d=group()
   for _,f in ipairs({-.27,.27})do
    disc(d,mid+span*f,gt.beam-6.8,gt.z+2.75+.16,2.1,16,0,2.1,.06)
    disc(d,mid+span*f,gt.beam-6.8,gt.z-2.75-.16,2.1,16,0,2.1,.06)
   end
   out.gates[#out.gates+1]={x=mid,z=gt.z,y=gt.beam+11.5,badge=badge,parts=parts,discs=mesh(d),L=gt.L,R=gt.R,
    phase=rh(gt.xa,gt.cy,5)*9,fy=gt.inWater and -1.4 or .3}
  end
 end
 for _,f in ipairs(L.flames or{})do
  out.flames[#out.flames+1]={x=f.x,y=f.y,z=f.z,s=f.s or 1,phase=rh(f.x,f.z,3)*9}
 end
 for _,l in ipairs(L.lamps or{})do out.lamps[#out.lamps+1]={x=l.x,y=l.y+11.2,z=l.z}end
 out.flags={}
 for i,f in ipairs(L.flags or{})do out.flags[#out.flags+1]={x=f.x,y=f.y,z=f.z,len=f.len or 13,h=f.h or 8,phase=i*1.37}end
 out.uplights=L.uplights or{}
 out.fountains={}
 for _,F in ipairs(L.fountains or{})do
  yieldPoint()
  local ok,fo=pcall(buildFountain,F)
  if ok and fo then out.fountains[#out.fountains+1]=fo end
 end
 -- TEST167: the gorge's rivers, falls and mist
 local LA=architecture()
 if LA and LA.gorgePlan then
  yieldPoint()
  local okG,G=pcall(LA.gorgePlan,L,map)
  if okG and G then local okB,gw=pcall(buildGorge,G);if okB then out.gorge=gw end end
 end
 -- TEST168: the night -- washes, pools, halos (LeagueNight)
 if LA and LA.nightPlan then
  yieldPoint()
  local conn=(map.def and map.def.connections)or{}
  local open={n=not conn.north,s=not conn.south,w=not conn.west,e=not conn.east}
  local tw,th=(map.def and map.def.width or 0)*4,(map.def and map.def.height or 0)*4
  local function tile(x,y)
   if x<0 or y<0 or x>=tw or y>=th then return nil end
   local ok,v=pcall(map.tileAt,map,x,y);return ok and v or nil
  end
  local okP,P=pcall(LA.nightPlan,L,tile,open)
  if okP and P then
   local okN,LN=pcall(V.require,"LeagueNight")
   if okN and LN then local okB,nm=pcall(LN.build,P);if okB then out.night=nm end end
   -- TEST169: the lanterns the canal mirrors (sconces, posts, the rim)
   out.mirror={}
   for _,h in ipairs(P.halos or{})do
    if (h.r or 0)>=4 then out.mirror[#out.mirror+1]={h.x,h.y,h.z,1}end
   end
  end
 end
 out.mirror=out.mirror or{}
 for _,l in ipairs(out.lamps)do out.mirror[#out.mirror+1]={l.x,l.y,l.z,1}end
 for _,f in ipairs(out.flames)do out.mirror[#out.mirror+1]={f.x,f.y+2,f.z,1.7}end
 -- TEST168: Route 23 gets the Plateau's searchlights and fireworks too --
 -- beams from the gatehouse towers, bursts over the League to the north
 if out.route and not out.lights then
  local G=L.gatehouse
  out.lights={}
  if G then
   local mid=(G.x0+G.x1)/2;local W2=(G.x1-G.x0)/2
   for i,sx in ipairs({-1,1})do
    out.lights[#out.lights+1]={x=mid-sx*(W2-(G.tw or 16)/2),y=(G.th or 60)+4,z=G.z0-4,phase=i*2.1}
   end
  end
  local tw=(map.def and map.def.width or 10)*32
  out.lights[#out.lights+1]={x=24,y=48,z=60,phase=4.2}
  out.lights[#out.lights+1]={x=tw-24,y=48,z=60,phase=5.6}
  out.sky=out.sky or{x=tw/2,z=-460,y=175}
 end
 -- warm light pools on the ground beneath the fires (the scene's four
 -- street-lamp lights, nearest four to the player, after dark)
 out.pools={}
 for _,gt in ipairs(L.gates or{})do out.pools[#out.pools+1]={(gt.L+gt.R)/2,gt.inWater and -1.5 or 0,gt.z}end
 if L.gatehouse then local G=L.gatehouse;out.pools[#out.pools+1]={(G.door0+G.door1)/2,0,G.z0-10}end
 if L.hall then
  local hl=L.hall;local mid=(hl.x0+hl.x1)/2
  out.pools[#out.pools+1]={mid,0,hl.z1+14}
  out.pools[#out.pools+1]={hl.x0+5,0,hl.z1+10};out.pools[#out.pools+1]={hl.x1-5,0,hl.z1+10}
  if L.carpet then out.pools[#out.pools+1]={mid,0,(L.carpet.z0+L.carpet.z1)/2+40}end
 end
 if L.hall then
  local hl=L.hall;local at=hl.attic
  local function roof(tx,ty)return((L.H and L.H[L.K(tx,ty)])or 0)+2.6 end
  out.lights={
   {x=at.x0+5,y=at.h+2,z=at.z0+6,phase=.3},{x=at.x1-5,y=at.h+2,z=at.z0+6,phase=2.0},
   {x=20,y=roof(2,2),z=20,phase=3.4},{x=L.tw*8-20,y=roof(L.tw-3,2),z=20,phase=5.1}}
  out.sky={x=(hl.x0+hl.x1)/2,z=hl.z1-260,y=hl.h+100}
  out.door={x=(hl.x0+hl.x1)/2,y=22,z=hl.z1+2}
 end
 return out
end

local function build(map)
 local id=tostring(map.id or"")
 if id=='ROUTE_23'then return buildRoute23(map)end
 if id=='INDIGO_PLATEAU'then return buildPlateau(map)end
 return false
end

------------------------------------------------------------------ draw
-- TEST166: the animated layer is drawn for neighbour League maps too (the
-- gatehouse fires from Route 22, the League's searchlights from Route 23),
-- so every translate goes through this world offset.
local OX,OZ=0,0
local function TR(x,y,z)return Mat4.translate(x+OX,y,z+OZ)end
local function fire(g,st,x,y,z,t,ph,s)
 s=s or 1
 local fl=.82+.10*sin(t*9.3+ph)+.08*sin(t*15.1+ph*1.7)
 g.setColor(1,.50,.16,.85*fl);Voxel3D.draw(unitCross,st,Mat4.mul(TR(x,y+2.2*s,z),Mat4.scale(2.4*s,4.2*s*fl,2.4*s)))
 g.setColor(1,.85,.45,.95*fl);Voxel3D.draw(unitCross,st,Mat4.mul(TR(x,y+1.2*s,z),Mat4.scale(1.2*s,2.3*s*fl,1.2*s)))
 g.setColor(1,.55,.22,.20*fl);Voxel3D.draw(unitCross,st,Mat4.mul(TR(x,y+1.5*s,z),Mat4.scale(10*s,10*s,10*s)))
end

-- TEST165: a brazier fire that reads from any angle and against a bright
-- sky. The BODY (three crossed teardrops, outer to core, swaying and
-- licking) draws alpha-blended so daylight cannot wash it out; the GLOW,
-- rising tongues and embers draw additively on top.
local function flameBody(g,ft,x,y,z,t,ph,s)
 local fl=.86+.09*sin(t*9.3+ph)+.06*sin(t*15.1+ph*1.7)
 local sway=sin(t*2.3+ph)*.10
 local layers={{2.5,6.4,1,.48,.10,.70},{1.75,4.9,1,.70,.18,.80},{1.0,3.2,1,.92,.62,.85}}
 for li,L in ipairs(layers)do
  local f=li==1 and fl or(.9+.1*sin(t*11+ph*2+li))
  for k=0,2 do
   local rot=k*pi/3+ph+li*.4
   local m=Mat4.mul(TR(x,y-.2*s,z),Mat4.mul(Mat4.rotateZ(sway),
    Mat4.mul(Mat4.rotateY(rot),Mat4.mul(Mat4.translate(0,L[2]*s*f*.5,0),Mat4.scale(L[1]*s,L[2]*s*f*.5,L[1]*s)))))
   g.setColor(L[3],L[4],L[5],L[6]);Voxel3D.draw(unitCross,ft,m)
  end
 end
end
local function flameGlow(g,st,x,y,z,t,ph,s,night)
 local fl=.85+.10*sin(t*7.7+ph)
 g.setColor(1,.55,.22,(.16+.20*night)*fl)
 Voxel3D.draw(unitCross,st,Mat4.mul(TR(x,y+2.4*s,z),Mat4.scale(9*s,9*s,9*s)))
 g.setColor(1,.62,.26,(.20+.25*night)*fl)
 Voxel3D.draw(unitQuad,st,Mat4.mul(TR(x,y+.3,z),Mat4.scale(4.2*s,1,4.2*s)))
 -- tongues licking up off the flame
 for i=0,3 do
  local life=(t*1.7+i*.25+ph*.13)%1
  local a=i*1.9+ph
  local r=(1-life)*.9*s
  local px,pz=x+cos(a+t*2)*r,z+sin(a+t*2)*r
  local sz=(1-life)*1.3*s+.25
  g.setColor(1,.78-.38*life,.30-.22*life,(1-life)*.75)
  Voxel3D.draw(unitCross,st,Mat4.mul(TR(px,y+(3.5+life*6)*s,pz),Mat4.scale(sz,sz*1.4,sz)))
 end
 -- embers drifting up and away
 for i=0,3 do
  local life=(t*.42+i*.25+ph*.07)%1
  local a=i*2.4+ph+life*2
  local px,pz=x+cos(a)*life*3*s,z+sin(a)*life*3*s
  g.setColor(1,.70,.32,(1-life)*(.55+.35*night))
  Voxel3D.draw(unitCross,st,Mat4.mul(TR(px,y+(4+life*18)*s,pz),Mat4.scale(.35*s,.35*s,.35*s)))
 end
end

local function searchlights(g,st,lights,t,alpha)
 for _,l in ipairs(lights or{})do
  local a=sin(t*.35+l.phase)*.55
  local b=.35+.15*sin(t*.27+l.phase*2)
  local m=Mat4.mul(TR(l.x,l.y,l.z),Mat4.mul(Mat4.rotateY(l.phase*1.3+t*.12),
   Mat4.mul(Mat4.rotateX(b),Mat4.mul(Mat4.rotateZ(a),Mat4.scale(9,170,9)))))
  g.setColor(.75,.85,1,alpha);Voxel3D.draw(coneMesh,st,m)
 end
end
-- TEST170: FIREWORKS, BIG. Six shells in the air at staggered times. Each
-- one climbs as a bright rocket, flashes, and opens into a shell of sparks
-- 100-170 units across (it was about 70), every spark trailing three embers
-- behind it. Four kinds:
--   peony         one colour, a full round burst
--   chrysanthemum opens in its colour and burns down to gold
--   willow        gold, slow, the trails drooping long under their weight
--   ring          a tilted ring of sparks
-- Each shell's sparks are one stream mesh (one draw), so a sky full of
-- fireworks is still only a handful of draws.
local FW_N,FW_TRAIL=80,4
local fwPool
local FW_COLS={{1,.30,.26},{1,.80,.28},{.36,.60,1},{.50,1,.42},{1,.42,.86},{.82,.52,1},{1,.96,.90},{.30,.95,1}}
local FW_GOLD={1,.78,.36}
local function fwStreams()
 if fwPool==nil then
  fwPool={}
  -- 6 for the standing show, 10 for salvos (the gates, the arrival)
  for k=1,16 do
   local sm=newStream(FW_N*FW_TRAIL)
   if not sm then
    for _,made in ipairs(fwPool)do if made.mesh and made.mesh.release then pcall(made.mesh.release,made.mesh)end end
    fwPool=false;break
   end
   fwPool[k]=sm
  end
 end
 return fwPool or nil
end
-- Camera-facing sparks for the fitted celebration shows. Vertical crossed
-- planes become thin when the finale camera looks up; a billboard keeps its
-- bright core round. Reuse the existing stream (the spare quad degenerates).
local function sparkPut(sm,i,x,y,z,sz,rx,rz,ux,uy,uz)
 if not rx then return streamPut(sm,i,x,y,z,sz,false)end
 local ax,az,bx,by,bz=rx*sz,rz*sz,ux*sz,uy*sz,uz*sz
 local v,b=sm.verts,i*8
 local e=v[b+1];e[1],e[2],e[3],e[4],e[5]=x-ax-bx,y-by,z-az-bz,0,0
 e=v[b+2];e[1],e[2],e[3],e[4],e[5]=x+ax-bx,y-by,z+az-bz,1,0
 e=v[b+3];e[1],e[2],e[3],e[4],e[5]=x+ax+bx,y+by,z+az+bz,1,1
 e=v[b+4];e[1],e[2],e[3],e[4],e[5]=x-ax+bx,y+by,z-az+bz,0,1
 for k=5,8 do e=v[b+k];e[1],e[2],e[3],e[4],e[5]=x,y,z,0,0 end
end
-- One shell: s={id,launchT,rise,kind,bx,by,bz,lx,ly,lz,R,col,scale,seed}.
-- Draws the rocket, the flash, the glow and the spark shell; reports the
-- shell to the audio once (the audio dedupes by id).
local function drawShell(g,st,sm,s,t,bright,audio,listen)
 local age=t-s.launchT
 if age<0 then return end
 local scale,kind,R=s.scale or 1,s.kind,s.R
 -- Keep distant celebration sparks legible without increasing the particle
 -- count or changing the size/speed of their spherical burst.
 local sparkScale=scale*(s.sparkScale or 1)
 local bx,by,bz=s.bx,s.by,s.bz
 local rise=s.rise or 1.15
 if audio and age<rise+5 then pcall(audio.shell,s.id,s.launchT,s.launchT+rise,kind,bx,by,bz,listen[1],listen[2],listen[3])end
 local c=s.col
 if age<rise then
  -- the rocket: a hot point climbing on a fading tail
  local u=age/rise
  local lx,ly,lz=s.lx or bx,s.ly or by-190*scale,s.lz or bz
  for k=0,4 do
   local uk=max(0,u-k*.035)
   local e=1-(1-uk)^2
   local x,y,z=lx+(bx-lx)*e,ly+(by-ly)*e,lz+(bz-lz)*e
   local q=(2.6-k*.42)*sparkScale
   g.setColor(1,.85,.55,(.95-k*.17)*bright)
   Voxel3D.draw(unitCross,st,Mat4.mul(TR(x,y,z),Mat4.scale(q,q*1.6,q)))
  end
  return
 end
 local a=age-rise
 local life=kind==2 and 4.8 or 3.6
 if a>=life then return end
 local fade=(1-a/life)^1.15
 -- the flash, and the sky lit around the shell
 if a<.6 then
  local f=1-a/.6
  local q=(26+R*.35)*f+6
  g.setColor(1,.96,.86,.85*f*bright)
  Voxel3D.draw(unitCross,st,Mat4.mul(TR(bx,by,bz),Mat4.scale(q,q,q)))
 end
 local col=c
 if kind==1 and a>life*.45 then
  local k=min(1,(a-life*.45)/(life*.25))
  col={c[1]+(FW_GOLD[1]-c[1])*k,c[2]+(FW_GOLD[2]-c[2])*k,c[3]+(FW_GOLD[3]-c[3])*k}
 end
 g.setColor(col[1],col[2],col[3],.30*fade*bright)
 Voxel3D.draw(unitCross,st,Mat4.mul(TR(bx,by-a*a*4*scale,bz),Mat4.scale(R*1.25,R*1.25,R*1.25)))
 if not sm then return end
 -- the shell: sparks on a sphere (or a tilted ring), easing out, falling as
 -- they burn, each trailing three embers
 local seed=s.seed or 0
 local grav=(kind==2 and 15 or 8)*scale*(s.gravityScale or 1)
 local spread=kind==2 and 1.6 or 2.6
 local tilt=rh(seed,7,29)*pi;local tc,ts=cos(tilt),sin(tilt)
 local rx,rz,ux,uy,uz
 local eye,focus=Voxel3D.eye,Voxel3D.focus
 if s.sparkScale and eye and focus then
  local dx,dy,dz=focus[1]-eye[1],focus[2]-eye[2],focus[3]-eye[3]
  local flat=sqrt(dx*dx+dz*dz);local len=sqrt(flat*flat+dy*dy)
  if flat>1e-6 and len>1e-6 then
   rx,rz=-dz/flat,dx/flat;ux,uy,uz=-dx*dy/(flat*len),flat/len,-dz*dy/(flat*len)
  end
 end
 local n=0
 for i=0,FW_N-1 do
  local dx,dy,dz
  if kind==3 then
   local an=i/FW_N*pi*2
   dx,dy,dz=cos(an),sin(an)*tc,sin(an)*ts
  else
   local v=1-2*(i+.5)/FW_N;local h=sqrt(max(0,1-v*v));local an=i*2.39996+seed
   dx,dy,dz=h*cos(an),v,h*sin(an)
  end
  local jit=.88+.24*rh(i,seed,31)
  for k=0,FW_TRAIL-1 do
   local ak=max(0,a-k*(kind==2 and .17 or .065))
   local r=R*jit*(1-math.exp(-ak*spread))
   local drop=grav*ak*ak
   local sz=(kind==2 and 4.6 or 6.0)*(1-k*.21)*sparkScale*(.55+.45*fade)
   if kind~=2 and a>life*.7 and (i+k+floor(t*14))%3==0 then sz=sz*.35 end   -- the crackle at the end
   sparkPut(sm,n,bx+dx*r,by+dy*r-drop,bz+dz*r,sz,rx,rz,ux,uy,uz)
   n=n+1
  end
 end
 pcall(sm.mesh.setVertices,sm.mesh,sm.verts)
 g.setColor(col[1],col[2],col[3],.95*fade*bright)
 Voxel3D.draw(sm.mesh,st,TR(0,0,0))
end
-- TEST172: SALVOS -- shells fired on cue (a badge gate as you pass it, the
-- finale as you arrive at the Plateau), on top of the standing show. Map
-- local coordinates; each salvo belongs to the map it was fired on.
local salvos,salvoN={},0
function M.salvo(mapId,list)
 for _,s in ipairs(list)do
  salvoN=salvoN+1
  s.id=10000000+salvoN;s.map=mapId;s.seed=s.seed or salvoN*3.7
  salvos[#salvos+1]=s
 end
end
local function fireworks(g,st,sky,t,bright,scale,listen,mapId)
 scale=scale or 1;bright=bright or 1
 local pool=fwStreams()
 -- TEST171: the shells are heard too (main map only: `listen` is the player)
 local audio
 if listen then local okA,A=pcall(V.require,'LeagueFireworksAudio');if okA then audio=A end end
 if sky then
  local PER=6.4
  for j=0,5 do
   local tj=t+j*(PER/6)+j*.41
   local cyc=floor(tj/PER);local age=tj%PER
   local kind=floor(rh(j,cyc,19)*4)
   local s={id=cyc*8+j,launchT=t-age,kind=kind,scale=scale,seed=cyc+j*7,
    bx=sky.x+(rh(j,cyc,11)-.5)*360*scale,bz=sky.z+(rh(cyc,j,13)-.5)*140*scale,by=sky.y+(rh(j,cyc,17)-.35)*80*scale,
    R=(105+65*rh(j,cyc,23))*scale,col=FW_COLS[(j*3+cyc)%#FW_COLS+1]}
   if kind==2 then s.R=s.R*.9;s.col=FW_GOLD elseif kind==3 then s.R=s.R*1.1 end
   drawShell(g,st,pool and pool[j+1],s,t,bright,audio,listen)
  end
 end
 -- the salvos fired on this map
 if mapId and #salvos>0 then
  local k=0
  for i=#salvos,1,-1 do
   local s=salvos[i]
   if t-s.launchT>9 then table.remove(salvos,i)
   elseif s.map==mapId then
    k=k+1
    drawShell(g,st,pool and pool[6+((k-1)%10)+1],s,t,bright*(s.bright or 1),audio,listen)
   end
  end
 end
end
local function motes(g,st,fx,fz,t)
 for k=0,23 do
  local life=(t*.05+k/24)%1
  local a=k*2.39996
  local r=24+rh(k,1,7)*90
  local x=fx+cos(a)*r;local z=fz+sin(a)*r-20
  local y=4+life*46
  g.setColor(1,.85,.45,.55*sin(life*pi))
  Voxel3D.draw(unitCross,st,Mat4.mul(TR(x,y,z),Mat4.scale(.6,.6,.6)))
 end
end

local function drawRoute23(slot,map,fx,fz,t)
 local g=love.graphics
 local wt,st=white(),soft()
 local pushed=pcall(g.push,"all")
 pcall(function()
  g.setDepthMode("lequal",true);g.setBlendMode("alpha")
  Voxel3D.lighting(true)
  g.setColor(.95,.93,.88,1);if slot.marble then Voxel3D.draw(slot.marble,wt)end
  g.setColor(.92,.70,.28,1);if slot.gold then Voxel3D.draw(slot.gold,wt)end
  g.setColor(.12,.08,.06,1);if slot.dark then Voxel3D.draw(slot.dark,wt)end
  for _,gt in ipairs(slot.gates)do
   local c=gt.badge.col
   g.setColor(c[1]*.75,c[2]*.75,c[3]*.75,1);if gt.cloth then Voxel3D.draw(gt.cloth,wt)end
   g.setColor(.98,.86,.45,1);if gt.trim then Voxel3D.draw(gt.trim,wt)end
  end
  Voxel3D.lighting(false)
  -- the badges themselves, self-lit and slowly turning
  for _,gt in ipairs(slot.gates)do
   local dx,dz=gt.x-fx,gt.z-fz
   if dx*dx+dz*dz<520*520 then
    local bob=sin(t*1.2+gt.phase)*.8
    local m=Mat4.mul(TR(gt.x,gt.y+bob,gt.z),Mat4.mul(Mat4.rotateY(t*.7+gt.phase),Mat4.scale(1.6,1.6,1.6)))
    for _,p in ipairs(gt.parts)do
     if p.mesh then g.setColor(p.col[1],p.col[2],p.col[3],1);Voxel3D.draw(p.mesh,wt,m)end
    end
   end
  end
  Voxel3D.lighting(true)
 end)
 pcall(Voxel3D.lighting,true)
 if pushed then pcall(g.pop)end
 pcall(Voxel3D.withEffect,"add",function()
  for _,gt in ipairs(slot.gates)do
   local dx,dz=gt.x-fx,gt.z-fz
   if dx*dx+dz*dz<520*520 then
    for _,f in ipairs(gt.fires)do fire(g,st,f.x,f.y,f.z,t,gt.phase+f.x*.01,1.2)end
    local c=gt.badge.col;local p=.75+.25*sin(t*1.6+gt.phase)
    g.setColor(c[1],c[2],c[3],.34*p);Voxel3D.draw(unitCross,st,Mat4.mul(TR(gt.x,gt.y,gt.z),Mat4.scale(11,11,11)))
    g.setColor(1,.9,.6,.18*p);Voxel3D.draw(unitCross,st,Mat4.mul(TR(gt.x,gt.y,gt.z),Mat4.scale(18,18,18)))
    -- a soft pool of the badge's colour on the path below
    g.setColor(c[1],c[2],c[3],.16*p);Voxel3D.draw(unitQuad,st,Mat4.mul(TR(gt.x,gt.fy+.3,gt.z),Mat4.scale(26,1,18)))
   end
  end
  motes(g,st,fx,fz,t)
 end)
end

local function drawPlateau(slot,map,fx,fz,t)
 local g=love.graphics
 local wt,st=white(),soft()
 local pushed=pcall(g.push,"all")
 pcall(function()
  g.setDepthMode("lequal",false);g.setBlendMode("alpha")
  Voxel3D.lighting(true)
  g.setColor(.62,.06,.09,1);if slot.carpet then Voxel3D.draw(slot.carpet,wt)end
  g.setColor(.95,.74,.30,1);if slot.carpetGold then Voxel3D.draw(slot.carpetGold,wt)end
  g.setDepthMode("lequal",true)
  g.setColor(.92,.70,.30,1);if slot.stands then Voxel3D.draw(slot.stands,wt)end
 end)
 pcall(Voxel3D.lighting,true)
 if pushed then pcall(g.pop)end
 pcall(Voxel3D.withEffect,"add",function()
  for _,b in ipairs(slot.braziers or{})do fire(g,st,b.x,b.y,b.z,t,b.phase,.8)end
  searchlights(g,st,slot.lights,t,.10)
  fireworks(g,st,slot.sky,t,1,1,{fx,12,fz},tostring(map.id))
 end)
end

local function nightLevel()
 local n=0
 pcall(function()n=V.require("DayNight").windowLight()end)
 n=tonumber(n)or 0
 return max(0,min(1,n))
end

-- TEST172: a searchlight cone aimed from (o) at (target): coneMesh opens
-- along +Y, so Y maps onto the beam and X/Z onto its radius.
local function aimCone(ox,oy,oz,tx,ty,tz,rad)
 local dx,dy,dz=tx-ox,ty-oy,tz-oz
 local len=sqrt(dx*dx+dy*dy+dz*dz);if len<1e-3 then return nil end
 dx,dy,dz=dx/len,dy/len,dz/len
 local ux,uy,uz=dz,0,-dx
 local ul=sqrt(ux*ux+uz*uz);if ul<1e-4 then ux,uy,uz,ul=1,0,0,1 end
 ux,uz=ux/ul,uz/ul
 local wx,wy,wz=uy*dz-uz*dy,uz*dx-ux*dz,ux*dy-uy*dx
 return {ux*rad,dx*len,wx*rad,ox+OX, uy*rad,dy*len,wy*rad,oy, uz*rad,dz*len,wz*rad,oz+OZ, 0,0,0,1}
end
-- TEST172: THE BADGE GATES CELEBRATE YOU. Walk north through a gate and its
-- badge flares and spins, a bell rings, and a volley of shells in that
-- badge's colours goes up from the gate's own pillars.
local BADGE_ORDER={BOULDER=1,CASCADE=2,THUNDER=3,RAINBOW=4,SOUL=5,MARSH=6,VOLCANO=7,EARTH=8}
local function celebrateGate(gt,t,mapId)
 local c=gt.badge.col
 local L,R=gt.L or gt.x-40,gt.R or gt.x+40
 local list={}
 for k=0,6 do
  local side=(k%2==0)and L+6 or R-6
  local kind=(k==3)and 3 or((k==6)and 2 or(k%2))
  local col=kind==2 and FW_GOLD or{min(1,c[1]*1.1+.12),min(1,c[2]*1.1+.12),min(1,c[3]*1.1+.12)}
  list[#list+1]={launchT=t+.30+k*.45,rise=1.0,kind=kind,scale=.8,
   lx=side,ly=gt.y-4,lz=gt.z,
   bx=gt.x+(rh(k,gt.x,3)-.5)*110,by=gt.y+52+rh(k,gt.z,5)*34,bz=gt.z-36-rh(gt.z,k,7)*50,
   R=62+rh(k,gt.z,9)*34,col=col}
 end
 M.salvo(mapId,list)
 gt.flareT=t
 local okA,A=pcall(V.require,'LeagueFireworksAudio')
 if okA and A and A.chime then pcall(A.chime,BADGE_ORDER[gt.badge.name or'']or 1)end
end
-- TEST172: ARRIVAL. Step onto the Plateau from Route 23 and the League
-- answers: a finale of shells over the hall, a fanfare of bells and the
-- crowd, and every searchlight swings onto the doors.
M.arrival=nil
local lastMapId=nil
local function arrive(slot,t,mapId)
 local sky=slot.sky;if not sky then return end
 local list={}
 for k=0,19 do
  local kind=floor(rh(k,3,19)*4)
  local tt=t+.6+k*.42+(k>=16 and(k-16)*-.25 or 0)
  local col=kind==2 and FW_GOLD or FW_COLS[k%#FW_COLS+1]
  list[#list+1]={launchT=tt,rise=1.1,kind=kind,scale=1.05,
   bx=sky.x+(rh(k,5,11)-.5)*300,by=sky.y+(rh(k,6,17)-.3)*70,bz=sky.z+(rh(k,7,13)-.5)*120,
   R=(110+70*rh(k,8,23))*(k>=16 and 1.25 or 1),col=col,bright=1.1}
 end
 M.salvo(mapId,list)
 slot.finaleT=t
 local okA,A=pcall(V.require,'LeagueFireworksAudio')
 if okA and A and A.fanfare then pcall(A.fanfare)end
end

-- TEST172: THE DAY OVER THE GORGE. By daylight: birds wheel over the gorge
-- (some below you, between the cliffs), clouds drift through it under the
-- road, and shafts of sun slant down into it from the sun's own side.
local dayBirds,dayClouds
local function drawDay(slot,map,fx,fz,t,night)
 local day=1-min(1,night*1.6)
 if day<=.02 then return end
 local g=love.graphics
 local st,wt=soft(),white()
 if not(st and wt)then return end
 local gw=slot.gorge
 local W=(map.def and map.def.width or 10)*32
 local x0=gw and gw.x0 or -120
 local x1=gw and gw.x1 or W+120
 local zA,zB=gw and gw.zA or -1e9,gw and gw.zB or 1e9
 -- the flocks: two per side, kept near you along the gorge
 if dayBirds==nil then dayBirds=newStream(24)or false end
 if dayClouds==nil then dayClouds=newStream(48)or false end
 pcall(Voxel3D.withEffect,"alpha",function()
  local sm=dayBirds
  if sm then
   local n=0
   for side=-1,1,2 do
    for k=0,1 do
     local zc=floor((fz-k*300)/600+.5)*600+k*300
     local cx=side<0 and x0-115-k*50 or x1+115+k*50
     local cy=(k==0 and -40 or 30)+side*6
     if zc>zA+200 and zc<zB-200 then
      for i=0,5 do
       if n<sm.n then
        local ph=i*1.047+k*2.1+side
        local a=t*(.20+.03*i)*(k==0 and 1 or -1)+ph
        local r=38+i*12
        local px,pz=cx+cos(a)*r,zc+sin(a)*r*.8
        local py=cy+sin(t*.35+ph)*10+i*3
        -- heading: along the circle
        local dir=(k==0 and 1 or -1)
        local dx,dz=-sin(a)*dir,cos(a)*.8*dir
        local l=sqrt(dx*dx+dz*dz);dx,dz=dx/l,dz/l
        local rx,rz=-dz,dx
        local glide=.5+.5*sin(t*.5+ph)
        local flap=sin(t*7.5+ph*3)*(1-glide*.85)
        local span=7.5
        local lift=flap*span*.45+span*.12
        local v=sm.verts;local b=n*8
        local function put(q,x,y,z)local e=v[b+q];e[1],e[2],e[3],e[4],e[5]=x,y,z,.5,.5 end
        -- the left and right wings (each a swept quad from the body)
        for w=0,1 do
         local s=w==0 and -1 or 1
         local o=w*4
         put(o+1,px+dx*1.1,py,pz+dz*1.1)
         put(o+2,px-dx*.9,py,pz-dz*.9)
         put(o+3,px+rx*s*span-dx*1.2,py+lift,pz+rz*s*span-dz*1.2)
         put(o+4,px+rx*s*span*.55+dx*.3,py+lift*.6,pz+rz*s*span*.55+dz*.3)
        end
        n=n+1
       end
      end
     end
    end
   end
   for i=n,sm.n-1 do local b=i*8;for q=1,8 do local e=sm.verts[b+q];e[1],e[2],e[3]=0,-9999,0 end end
   pcall(sm.mesh.setVertices,sm.mesh,sm.verts)
   g.setColor(.12,.12,.15,.85*day)
   Voxel3D.draw(sm.mesh,wt,TR(0,0,0))
  end
  -- clouds drifting through the gorge, below the road
  local cm=dayClouds
  if cm then
   local n=0
   for side=-1,1,2 do
    for i=0,7 do
     local span=1400
     local zz=((t*6+i*span/8+side*90)%span)-span/2
     local z=floor(fz/span)*span+zz
     if z<fz-span/2 then z=z+span elseif z>fz+span/2 then z=z-span end
     local x=(side<0 and x0-130 or x1+130)+sin(i*2.1+side)*70
     local y=-70+sin(i*1.7)*22
     if z>zA+120 and z<zB-120 then
      for q=0,2 do
       if n<cm.n then
        streamPut(cm,n,x+(q-1)*30,y+(q==1 and 8 or 0),z+(q-1)*12,40+q*8,false)
        n=n+1
       end
      end
     end
    end
   end
   for i=n,cm.n-1 do local b=i*8;for q=1,8 do local e=cm.verts[b+q];e[1],e[2],e[3]=0,-9999,0 end end
   pcall(cm.mesh.setVertices,cm.mesh,cm.verts)
   g.setColor(.96,.97,1,.22*day)
   Voxel3D.draw(cm.mesh,st,TR(0,0,0))
  end
 end)
 -- shafts of sun slanting into the gorge
 pcall(Voxel3D.withEffect,"add",function()
  if not(coneMesh and st)then return end
  local kx,kz=.35,.25
  pcall(function()local DN=V.require("DayNight");kx,kz=DN.shearAt(DN.rigTime())end)
  kx,kz=max(-1.1,min(1.1,tonumber(kx)or .35)),max(-1.1,min(1.1,tonumber(kz)or .25))
  for k=0,5 do
   local side=k%2==0 and -1 or 1
   local gx=(side<0 and x0-90 or x1+90)-side*rh(k,3,3)*120
   local gz=fz+(k-2.5)*150+sin(t*.03+k)*40
   if gz>zA+150 and gz<zB-150 then
    local gy=-148
    local h=520
    local top={gx-kx*h,gy+h,gz-kz*h}
    local m=aimCone(top[1],top[2],top[3],gx,gy,gz,34+rh(k,5,5)*22)
    if m then
     local a=(.028+.022*sin(t*.11+k*1.7))*day
     g.setColor(1,.95,.80,max(0,a))
     Voxel3D.draw(coneMesh,st,m)
    end
   end
  end
 end)
end
local function drawArch(slot,map,fx,fz,t,neighbour)
 local g=love.graphics
 local wt,st=white(),soft()
 local night=nightLevel()
 if not neighbour then
  -- TEST172: a gate crossed northbound celebrates; an arrival from Route
  -- 23 sets off the finale
  local last=slot.lastFz
  if last and abs(last-fz)<64 then
   for _,gt in ipairs(slot.gates)do
    if last>gt.z+2 and fz<=gt.z+2 and(not gt.flareT or t-gt.flareT>25)then celebrateGate(gt,t,tostring(map.id))end
   end
  end
  slot.lastFz=fz
  if M.arrival and M.arrival.map==tostring(map.id)then arrive(slot,t,tostring(map.id));M.arrival=nil end
  -- TEST172: the lobby is built in the background while you cross the Plateau
  if tostring(map.id)=='INDIGO_PLATEAU'then
   local okR,Rooms=pcall(V.require,"LeagueRooms")
   if okR and Rooms and Rooms.step then pcall(Rooms.step,'INDIGO_PLATEAU')end
  end
  -- TEST172: the soundscape follows you
  local okA,Amb=pcall(V.require,'LeagueAmbience')
  if okA and Amb then
   local function near(list,r,getx)
    local best=1e9
    for _,o in ipairs(list or{})do
     local x,z=getx(o)
     local d=(x-fx)^2+(z-fz)^2
     if d<best then best=d end
    end
    return max(0,1-sqrt(best)/r)
   end
   local W=(map.def and map.def.width or 10)*32
   local edge=1-min(1,min(fx,W-fx)/70)
   local fire=near(slot.flames,95,function(o)return o.x,o.z end)
   local fount=near(slot.fountains,80,function(o)return o.x,o.z end)
   local falls=slot.gorge and near(slot.gorge.falls,330,function(o)return o.x,o.z end)or 0
   local crowd=.10
   if slot.door then crowd=.14+.30*max(0,1-abs(fz-slot.door.z)/220)
   elseif slot.route then crowd=.05+.12*max(0,1-fz/900)end
   pcall(Amb.touch,{wind=.10+.22*edge,falls=.55*falls^1.3,fire=.42*fire^1.5,fountain=.40*fount^1.4,crowd=crowd})
  end
 end
 local R2=900*900
 local F2=1500*1500     -- fires and their glow: few, cheap, and seen from afar
 local pushed=pcall(g.push,"all")
 pcall(function()
  g.setDepthMode("lequal",true);g.setBlendMode("alpha")
  Voxel3D.lighting(true)
  for _,gt in ipairs(slot.gates)do
   local c=gt.badge.col
   g.setColor(c[1]*.9,c[2]*.9,c[3]*.9,1);if gt.discs then Voxel3D.draw(gt.discs,wt,TR(0,0,0))end
  end
  Voxel3D.lighting(false)
  -- the badges themselves, self-lit and slowly turning over each gate
  for _,gt in ipairs(slot.gates)do
   local dx,dz=gt.x-fx,gt.z-fz
   if dx*dx+dz*dz<R2 then
    local bob=sin(t*1.2+gt.phase)*.8
    local sc,spin=1.7,0
    if gt.flareT then
     local k=t-gt.flareT
     if k<4.5 then
      local pulse=k<.45 and k/.45 or max(0,1-(k-.45)/4.05)
      sc=1.7*(1+.85*pulse);spin=(1-math.exp(-k*1.6))*pi*6
     end
    end
    local m=Mat4.mul(TR(gt.x,gt.y+bob,gt.z),Mat4.mul(Mat4.rotateY(t*.7+gt.phase+spin),Mat4.scale(sc,sc,sc)))
    for _,p in ipairs(gt.parts)do
     if p.mesh then g.setColor(p.col[1],p.col[2],p.col[3],1);Voxel3D.draw(p.mesh,wt,m)end
    end
   end
  end
  Voxel3D.lighting(true)
 end)
 pcall(Voxel3D.lighting,true)
 if pushed then pcall(g.pop)end
 -- banners on the hall roof, rippling in the wind (lit cloth strips)
 if #(slot.flags or{})>0 then
  local pushed2=pcall(g.push,"all")
  pcall(function()
   g.setDepthMode("lequal",true);g.setBlendMode("alpha")
   Voxel3D.lighting(true)
   local N=8
   for _,f in ipairs(slot.flags)do
    local dx,dz=f.x-fx,f.z-fz
    if dx*dx+dz*dz<R2*1.6 then
     local px,pz=f.x,f.z
     local seg=f.len/N
     for i=0,N-1 do
      local u0,u1=i/N,(i+1)/N
      local w0=sin(t*3.1-u0*5.2+f.phase)*u0*2.2
      local w1=sin(t*3.1-u1*5.2+f.phase)*u1*2.2
      local ang=-math.atan2(w1-w0,seg)
      local len=sqrt(seg*seg+(w1-w0)^2)
      local droop=u0*1.2
      local m=Mat4.mul(TR(px,f.y-f.h-droop,pz),Mat4.mul(Mat4.rotateY(ang),Mat4.scale(len,f.h,1)))
      local shade=.78+.22*cos(t*3.1-u0*5.2+f.phase)
      g.setColor(.62*shade,.07*shade,.09*shade,1);Voxel3D.draw(unitPanel,wt,m)
      if i==0 or i==N-1 then
       g.setColor(.95*shade,.72*shade,.28*shade,1)
       Voxel3D.draw(unitPanel,wt,Mat4.mul(TR(px,f.y-f.h-droop-.01,pz+.02),Mat4.mul(Mat4.rotateY(ang),Mat4.scale(len,1.0,1))))
      end
      if i==N/2-1 then
       g.setColor(.98*shade,.80*shade,.32*shade,1)
       Voxel3D.draw(unitPanel,wt,Mat4.mul(TR(px,f.y-f.h*.5-1.4-droop,pz+.03),Mat4.mul(Mat4.rotateY(ang),Mat4.scale(len*1.6,2.8,1))))
      end
      px=px+cos(ang)*len;pz=pz-sin(ang)*len
     end
    end
   end
  end)
  pcall(Voxel3D.lighting,true)
  if pushed2 then pcall(g.pop)end
 end
 -- TEST166: fountains -- still water, overflow, jets and spray (alpha),
 -- then ripples and, after dark, the underwater lights (additive)
 local near={}
 for _,fo in ipairs(slot.fountains or{})do
  local dx,dz=fo.x-fx,fo.z-fz
  if dx*dx+dz*dz<520*520 then near[#near+1]=fo end
 end
 if #near>0 then
  local skT,rgT=streakT() or st,ringT() or st
  local dayW=1-night*.6
  pcall(Voxel3D.withEffect,"alpha",function()
   for _,fo in ipairs(near)do
    local m=TR(0,0,0)
    g.setColor(.28*dayW+.06,.62*dayW+.12,.70*dayW+.16,.74)
    if fo.discs then Voxel3D.draw(fo.discs,wt,m)end
    local sh=.82+.18*sin(t*5.3+fo.phase)
    g.setColor(.86,.96,1,.42*sh)
    if fo.curtains then Voxel3D.draw(fo.curtains,skT,m)end
    g.setColor(.90,.97,1,.55)
    if fo.jetMesh then Voxel3D.draw(fo.jetMesh,skT,m)end
    if fo.spray then updateSpray(fo,t);g.setColor(.92,.98,1,.75);Voxel3D.draw(fo.spray,st,m)end
   end
  end)
  pcall(Voxel3D.withEffect,"add",function()
   for _,fo in ipairs(near)do
    for wi,w in ipairs(fo.water)do
     for k=0,1 do
      local life=(t*.45+k*.5+wi*.21+fo.phase)%1
      local r=w.r*(.25+.75*life)
      g.setColor(.75,.92,1,(1-life)*.30)
      Voxel3D.draw(unitQuad,rgT,Mat4.mul(TR(fo.x,w.y+.05,fo.z),Mat4.scale(r,1,r)))
     end
    end
    if night>.02 then
     g.setColor(.10*night,.45*night,.55*night,1)
     if fo.discs then Voxel3D.draw(fo.discs,wt,TR(0,.02,0))end
    end
    local tw=.5+.5*sin(t*2.1+fo.phase)
    g.setColor(1,1,1,.10+.08*tw)
    for _,je in ipairs(fo.jets)do
     Voxel3D.draw(unitCross,st,Mat4.mul(TR(je.x,je.base+je.h*.9,je.z),Mat4.scale(1.8,1.8,1.8)))
    end
   end
  end)
 end
 -- TEST167: the gorge -- river surfaces, falls and pools (alpha), then the
 -- river's glints, ripples, spray and the valley's mist (additive)
 local gw=(not neighbour)and slot.gorge or nil
 if gw then
  local skT,rgT=streakT() or st,ringT() or st
  local dayW=1-night*.6
  pcall(Voxel3D.withEffect,"alpha",function()
   local m=TR(0,0,0)
   for _,rv in ipairs(gw.rivers)do
    if rv.mesh then g.setColor(.10*dayW+.03,.34*dayW+.06,.40*dayW+.09,.84);Voxel3D.draw(rv.mesh,wt,m)end
   end
   for _,fl in ipairs(gw.falls)do
    local dx,dz=fl.x-fx,fl.z-fz
    if dx*dx+dz*dz<F2 then
     if fl.pool then g.setColor(.12*dayW+.04,.40*dayW+.08,.46*dayW+.10,.82);Voxel3D.draw(fl.pool,wt,m)end
     local sh=.85+.15*sin(t*7.1+fl.phase)
     g.setColor(.88*dayW+.10,.95*dayW+.05,dayW,.64*sh);if fl.c1 then Voxel3D.draw(fl.c1,skT,m)end
     g.setColor(.80*dayW+.10,.90*dayW+.05,dayW,.32);if fl.c2 then Voxel3D.draw(fl.c2,skT,m)end
     if fl.drops then updateFall(fl,t);g.setColor(.95,.98,1,.62*dayW+.18);Voxel3D.draw(fl.drops.mesh,st,m)end
    end
   end
  end)
  pcall(Voxel3D.withEffect,"add",function()
   for _,rv in ipairs(gw.rivers)do
    if rv.glints then updateGlints(rv,t);g.setColor(1,.98,.90,.34*dayW+.05);Voxel3D.draw(rv.glints.mesh,st,TR(0,0,0))end
   end
   for _,fl in ipairs(gw.falls)do
    local dx,dz=fl.x-fx,fl.z-fz
    if dx*dx+dz*dz<F2 then
     for k=0,1 do
      local life=(t*.5+k*.5+fl.phase)%1;local r=fl.pr*(.3+.7*life)
      g.setColor(.80,.92,1,(1-life)*.26*dayW+.03)
      Voxel3D.draw(unitQuad,rgT,Mat4.mul(TR(fl.px,fl.py+.12,fl.pz),Mat4.scale(r,1,r)))
     end
     -- TEST168: after dark the falls are lit from their pools
     if night>.03 then
      local sh=.85+.15*sin(t*6.3+fl.phase)
      g.setColor(.30,.80,.92,.30*night*sh);if fl.c1 then Voxel3D.draw(fl.c1,skT,TR(0,0,0))end
      g.setColor(.25,.70,.85,.18*night);if fl.c2 then Voxel3D.draw(fl.c2,skT,TR(0,0,0))end
      g.setColor(.25,.85,1,.22*night);if fl.pool then Voxel3D.draw(fl.pool,wt,TR(0,.05,0))end
     end
     local pf=.8+.2*sin(t*1.3+fl.phase)
     g.setColor(.90,.95,1,(.18*dayW+.04)*pf)
     Voxel3D.draw(unitCross,st,Mat4.mul(TR(fl.px,fl.py+10,fl.pz),Mat4.scale(28,15,28)))
     g.setColor(1,1,1,.12*dayW+.03)
     Voxel3D.draw(unitCross,st,Mat4.mul(TR(fl.lx,fl.ly+2,fl.lz),Mat4.scale(9,5,9)))
    end
   end
   for _,ms in ipairs(gw.mist)do
    local dx,dz=ms.x-fx,ms.z-fz
    if dx*dx+dz*dz<F2 then
     local drift=sin(t*.07+ms.x*.01)*14
     -- TEST168: by night the valley mist holds the moonlight, silver-blue
     local a=(ms.a or .06)*(dayW*.9+.1+.38*night)
     local mr,mg=.92-.30*night,.95-.21*night
     g.setColor(mr,mg,1,a)
     Voxel3D.draw(unitCross,st,Mat4.mul(TR(ms.x+drift,ms.y,ms.z),Mat4.scale(ms.r,ms.r*.26,ms.r)))
     g.setColor(mr,mg,1,a*.8)
     Voxel3D.draw(unitQuad,st,Mat4.mul(TR(ms.x-drift,ms.y-4,ms.z),Mat4.scale(ms.r*1.3,1,ms.r*1.3)))
    end
   end
  end)
 end
 -- TEST169: hand the canal the lanterns nearest the player to mirror
 if not neighbour and night>.03 and slot.mirror and #slot.mirror>0 then
  local best={}
  for _,m in ipairs(slot.mirror)do
   local dx,dz=m[1]-fx,m[3]-fz;local d=dx*dx+dz*dz
   if d<260*260 then
    local n=#best
    if n<8 or d<best[n][5]then
     local e={m[1],m[2],m[3],m[4]*min(1,night*1.4),d}
     local i=n+1
     while i>1 and best[i-1][5]>d do best[i]=best[i-1];i=i-1 end
     best[i]=e
     if #best>8 then best[9]=nil end
    end
   end
  end
  local okW,W=pcall(V.require,"Water")
  if okW and W and W.setLeagueLamps then W.setLeagueLamps(best)end
 end
 -- TEST168: the League after dark (washes, pools, halos)
 if slot.night and night>.03 then
  local okN,LN=pcall(V.require,"LeagueNight")
  if okN and LN then LN.draw(slot.night,night,t,TR(0,0,0))end
 end
 -- fire bodies (alpha: holds up against a bright sky), then the glow
 local ft=flameT() or st
 pcall(Voxel3D.withEffect,"alpha",function()
  for _,f in ipairs(slot.flames)do
   local dx,dz=f.x-fx,f.z-fz
   if dx*dx+dz*dz<F2 then flameBody(g,ft,f.x,f.y,f.z,t,f.phase,f.s)end
  end
 end)
 pcall(Voxel3D.withEffect,"add",function()
  for _,f in ipairs(slot.flames)do
   local dx,dz=f.x-fx,f.z-fz
   if dx*dx+dz*dz<F2 then flameGlow(g,st,f.x,f.y,f.z,t,f.phase,f.s,night)end
  end
  -- uplights washing the columns and towers after dark
  if night>.02 then
   for _,u in ipairs(slot.uplights or{})do
    local dx,dz=u.x-fx,u.z-fz
    if dx*dx+dz*dz<R2 then
     g.setColor(1,.78,.48,.10*night)
     Voxel3D.draw(unitCross,st,Mat4.mul(TR(u.x,u.y+u.h*.5,u.z),Mat4.scale(u.r,u.h*.55,u.r)))
     g.setColor(1,.70,.40,.16*night)
     Voxel3D.draw(unitQuad,st,Mat4.mul(TR(u.x,u.y+.25,u.z),Mat4.scale(u.r*1.4,1,u.r*1.4)))
    end
   end
  end
  for _,gt in ipairs(slot.gates)do
   local dx,dz=gt.x-fx,gt.z-fz
   if dx*dx+dz*dz<R2 then
    local c=gt.badge.col;local p=.75+.25*sin(t*1.6+gt.phase)
    g.setColor(c[1],c[2],c[3],.34*p);Voxel3D.draw(unitCross,st,Mat4.mul(TR(gt.x,gt.y,gt.z),Mat4.scale(11,11,11)))
    g.setColor(1,.9,.6,.18*p);Voxel3D.draw(unitCross,st,Mat4.mul(TR(gt.x,gt.y,gt.z),Mat4.scale(18,18,18)))
    g.setColor(c[1],c[2],c[3],(.12+.10*night)*p);Voxel3D.draw(unitQuad,st,Mat4.mul(TR(gt.x,gt.fy,gt.z),Mat4.scale(26,1,18)))
   end
  end
  -- lantern halos after dark
  if night>.02 then
   local L2=420*420
   for _,l in ipairs(slot.lamps)do
    local dx,dz=l.x-fx,l.z-fz
    if dx*dx+dz*dz<L2 then
     local fl=.92+.08*sin(t*7.1+l.x*.13)
     g.setColor(1,.76,.40,.45*night*fl);Voxel3D.draw(unitCross,st,Mat4.mul(TR(l.x,l.y,l.z),Mat4.scale(3.0,3.0,3.0)))
     g.setColor(1,.70,.36,.15*night);Voxel3D.draw(unitCross,st,Mat4.mul(TR(l.x,l.y,l.z),Mat4.scale(9,9,9)))
    end
   end
  end
  if slot.route and not neighbour then motes(g,st,fx,fz,t)end
  -- TEST172: a flaring badge: a burst of its light, a ring racing out
  -- across the path, a beam standing up into the sky
  for _,gt in ipairs(slot.gates)do
   if gt.flareT and t-gt.flareT<4.5 then
    local k=t-gt.flareT;local c=gt.badge.col
    local pulse=k<.45 and k/.45 or max(0,1-(k-.45)/4.05)
    g.setColor(c[1],c[2],c[3],.55*pulse)
    Voxel3D.draw(unitCross,st,Mat4.mul(TR(gt.x,gt.y,gt.z),Mat4.scale(16+30*pulse,16+30*pulse,16+30*pulse)))
    g.setColor(1,1,1,.35*pulse)
    Voxel3D.draw(unitCross,st,Mat4.mul(TR(gt.x,gt.y,gt.z),Mat4.scale(8+10*pulse,8+10*pulse,8+10*pulse)))
    local rk=min(1,k/1.6)
    g.setColor(c[1],c[2],c[3],.55*(1-rk))
    Voxel3D.draw(unitQuad,ringT() or st,Mat4.mul(TR(gt.x,gt.fy+.4,gt.z),Mat4.scale(14+90*rk,1,14+90*rk)))
    local cm=aimCone(gt.x,gt.y,gt.z,gt.x,gt.y+260,gt.z,10+6*pulse)
    if cm and coneMesh then g.setColor(c[1],c[2],c[3],.16*pulse);Voxel3D.draw(coneMesh,st,cm)end
   end
  end
  if slot.finaleT and t-slot.finaleT<13 and slot.door then
   -- every searchlight swings onto the League's doors, then lets go
   local k=t-slot.finaleT
   local w=min(1,k/1.5)*min(1,(13-k)/2)
   local d=slot.door
   for _,l in ipairs(slot.lights or{})do
    local sx=sin(t*1.7+l.phase)*14*(1-w)+sin(t*.9+l.phase)*4
    local cm=aimCone(l.x,l.y,l.z,d.x+sx,d.y+sin(t*1.3+l.phase)*4,d.z,9)
    if cm then g.setColor(.82,.90,1,(.10+.10*night)*w);Voxel3D.draw(coneMesh,st,cm)end
   end
   searchlights(g,st,slot.lights,t,(.05+.08*night)*(1-w))
  else
   searchlights(g,st,slot.lights,t,.05+.08*night)
  end
  -- TEST168: on Route 23 the bursts keep station ahead of you, over the
  -- League you are walking toward
  local sky=slot.sky
  if slot.route and sky and not neighbour then sky={x=sky.x,y=sky.y,z=max(sky.z,fz-600)}end
  fireworks(g,st,sky,t,.75+.25*night,slot.route and 1.1 or .9,(not neighbour)and{fx,12,fz}or nil,tostring(map.id))
 end)
 if not neighbour then pcall(drawDay,slot,map,fx,fz,t,night)end
end

local function release(s)
 if not s then return end
 for _,k in ipairs({'marble','gold','dark','carpet','carpetGold','stands'})do local m=s[k];if m and m.release then pcall(m.release,m)end end
 for _,fo in ipairs(s.fountains or{})do
  for _,m in pairs({fo.discs,fo.curtains,fo.jetMesh,fo.spray})do if m and m.release then pcall(m.release,m)end end
 end
 local gw=s.gorge
 if gw then
  for _,rv in ipairs(gw.rivers or{})do
   for _,m in pairs({rv.mesh,rv.glints and rv.glints.mesh})do if m and m.release then pcall(m.release,m)end end
  end
  for _,fl in ipairs(gw.falls or{})do
   for _,m in pairs({fl.c1,fl.c2,fl.pool,fl.drops and fl.drops.mesh})do if m and m.release then pcall(m.release,m)end end
  end
 end
 if s.night then local ok,LN=pcall(V.require,"LeagueNight");if ok and LN then LN.release(s.night)end end
 for _,gt in ipairs(s.gates or{})do
  for _,m in pairs({gt.cloth,gt.trim,gt.discs})do if m and m.release then pcall(m.release,m)end end
  for _,p in ipairs(gt.parts or{})do if p.mesh and p.mesh.release then pcall(p.mesh.release,p.mesh)end end
 end
end

-- TEST98: do not leave route waterfalls, gate meshes and light effects
-- attached to old engine map objects for the rest of a walking session.
local lastLive=nil
function M.setLive(live)
 lastLive=live
 local now=0;pcall(function()now=love.timer.getTime()end)
 for map,s in pairs(cache)do
  local kept=warmKeep[map]and now-warmKeep[map]<M.WARM_KEEP_SECONDS
  if not(live and live[map.id])and not kept then release(s);cache[map]=nil end
 end
end

local function drawMap(map,fx,fz,ox,oz)
 local LA=architecture()
 local archOn=false
 if LA then local ok,on=pcall(LA.enabled,map);archOn=ok and on or false end
 local slot=cache[map]
 if slot~=nil and(slot and slot.archOn or false)~=archOn then release(slot);slot=nil;cache[map]=nil end
 if slot==nil then
  local ok,res
  if archOn then
   -- LOADING-STUTTER: with the warm-ahead on, a plan first made here (on the
   -- frame thread) gets its fountains' water in the background job
   local L=LA.layout(map,M.WARM_AHEAD)
   if not L then return end
   ok,res=pcall(buildArch,map,L)
  else
   ok,res=pcall(build,map)
  end
  slot=ok and res or false
  if slot then slot.archOn=archOn end
  cache[map]=slot
 end
 if not slot then return end
 units()
 local t=0;pcall(function()t=love.timer.getTime()end)
 ox,oz=ox or 0,oz or 0
 local neighbour=(ox~=0 or oz~=0)
 if neighbour and slot.kind~='arch' then return end
 OX,OZ=ox,oz
 local ok,err=pcall(function()
  if slot.kind=='arch' then drawArch(slot,map,fx-ox,fz-oz,t,neighbour)
  elseif slot.kind=='route' then drawRoute23(slot,map,fx,fz,t)
  elseif slot.kind=='plateau' then drawPlateau(slot,map,fx,fz,t)end
 end)
 OX,OZ=0,0
 if not ok then error(err,0)end
end

local LEAGUE={ROUTE_23=true,INDIGO_PLATEAU=true}

-- LOADING-STUTTER: warm-ahead. The first sight of Route 23 (from Viridian or
-- Route 22) planned the League layout and built its animated slot on that
-- draw (60-120 ms on a phone); the Route 22 gate room was built on its first
-- frame inside (55-80 ms, 290 ms seen with a busy heap). Now background jobs
-- on ChunkMesher's queue do it first, in slices: the layout (kept for the
-- session) as soon as a League map is a neighbour; its slot once it is within
-- WARM_MARGIN of the view range; the gate room near the gate's doors. Nothing
-- waits for them -- whatever is not ready on its first draw is built there,
-- exactly as before.
M.WARM_AHEAD=true      -- false: everything is built on its first draw, as before
M.WARM_MARGIN=160      -- px beyond the render radius (about 3 s of walking)
M.WARM_PRIORITY=.5     -- under terrain and KantoLife's current-map job (.9), above its
                       -- warm-ahead (.45): a slot is short and needed soonest
local warmAt=-1e9
local function warmJob(state,what,m,fn,cancel)
 local okC,CM=pcall(V.require,"ChunkMesher")
 if not(okC and CM and type(CM.requestWork)=="function")then return end
 -- keyed to the current map (live while the player is there); the League
 -- loops yield in it through LeagueArchitecture's scoped budget (sliceJob)
 pcall(CM.requestWork,state.map,"league-"..what.."-"..tostring(m.id),"v1",M.WARM_PRIORITY,function()
  local LA=architecture()
  if LA and LA.sliceJob then LA.sliceJob()end
  return fn()
 end,cancel)
end
local function aboutToShow(nb,p)
 local ok,RD=pcall(V.require,"RenderDistance")
 if not(ok and RD and RD.radius)then return true end
 local okR,radius=pcall(RD.radius)
 if not(okR and radius)then return true end
 local px,pz=(p and p.px or 0)+8,(p and p.py or 0)+8
 local x0,z0=tonumber(nb.ox)or 0,tonumber(nb.oy)or 0
 local x1=x0+(tonumber(nb.map.def and nb.map.def.width)or 0)*32
 local z1=z0+(tonumber(nb.map.def and nb.map.def.height)or 0)*32
 local dx=px<x0 and x0-px or(px>x1 and px-x1 or 0)
 local dz=pz<z0 and z0-pz or(pz>z1 and pz-z1 or 0)
 local r=radius+M.WARM_MARGIN
 return dx*dx+dz*dz<=r*r
end
local function warmShared()
 -- the effect textures and unit meshes every League draw makes on first use
 for _,f in ipairs({units,white,soft,flameT,streakT,ringT})do yieldPoint();pcall(f)end
end
local function warmAhead(state)
 if not M.WARM_AHEAD then return end
 local now=love.timer.getTime()
 if now-warmAt<.5 then return end
 warmAt=now
 local mid=tostring(state.map.id or"")
 if mid=="ROUTE_22"or mid=="ROUTE_23"then
  local ok,Room=pcall(V.require,"LeagueGateRoom")
  if ok and Room and Room.warmNear then pcall(Room.warmNear,state)end
 end
 local LA=architecture()
 if not(LA and LA.isPlanned)then return end
 -- the current map too: when a first draw here planned it on the frame thread
 -- (arriving on a League map unannounced, e.g. a save loaded there), this job
 -- fills that plan's fountains
 if LEAGUE[mid]then
  local cm=state.map
  local okE,on=pcall(LA.enabled,cm)
  if okE and on and not LA.isPlanned(cm)then warmJob(state,"layout",cm,function()LA.layout(cm)end)end
 end
 for _,nb in ipairs(state.neighbors or{})do
  local m=nb.map
  if m and LEAGUE[tostring(m.id or"")]then
   local okE,on=pcall(LA.enabled,m)
   if okE and on then
    if not LA.isPlanned(m)then
     warmJob(state,"layout",m,function()LA.layout(m)end)
    elseif aboutToShow(nb,state.player)then
     warmKeep[m]=now
     if cache[m]==nil then
      local track={}
      warmJob(state,"slot",m,function()
       if cache[m]~=nil then return end
       local L=LA.layout(m)
       if not L then return end
       local ok,res=pcall(buildArch,m,L,track)
       if not ok then release(track.slot)end
       track.slot=nil
       local built=ok and res or nil
       -- still wanted? (live, or still about to come into view)
       local t=love.timer.getTime()
       local wanted=(lastLive and lastLive[m.id])or(warmKeep[m]and t-warmKeep[m]<M.WARM_KEEP_SECONDS)
       -- a failed background build stores nothing: the first draw then builds
       -- it as before (and caches its own result, failure included)
       if cache[m]==nil and wanted and built then
        built.archOn=true
        cache[m]=built
       elseif built then release(built)end   -- a draw built it meanwhile, or no longer wanted
       warmShared()
      end,function()release(track.slot);track.slot=nil end)
     end
    end
   end
  end
 end
end

function M.draw(state)
 local map=state and state.map
 if not map then return false end
 -- TEST172: the League's rooms (the lobby, the Elite Four, the Champion,
 -- the Hall of Fame) draw their own light, fire, snow and fireworks
 do
  local okR,Rooms=pcall(V.require,"LeagueRooms")
  if okR and Rooms and Rooms.LAYOUT and Rooms.LAYOUT[tostring(map.id)]then
   if Rooms.accepts(map)then
    lastMapId=tostring(map.id)
    local okF,Fx=pcall(V.require,"LeagueRoomFx")
    if okF and Fx then local ok,err=pcall(Fx.draw,state);if not ok then error(err,0)end;return true end
   end
   return false
  end
 end
 pcall(warmAhead,state)
 -- TEST172: note an arrival on the Plateau from Route 23
 local mid=tostring(map.id or"")
 if mid~=lastMapId then
  if mid=='INDIGO_PLATEAU'and lastMapId=='ROUTE_23'then M.arrival={map=mid}end
  lastMapId=mid
 end
 -- TEST166: the Route 22 gate's antechamber: its fires, candles and badges
 if tostring(map.id)=='ROUTE_22_GATE'then
  local ok,Room=pcall(V.require,"LeagueGateRoom")
  if ok and Room and Room.accepts(map)then
   local okF,fx=pcall(Room.fx,map,Voxel3D.eye)
   if okF and fx then local okD,err=pcall(M.drawRoomFx,fx);if not okD then error(err,0)end;return true end
  end
  return false
 end
 local p=state.player
 local fx,fz=(p and p.px or 0)+8,(p and p.py or 0)+8
 local drew=false
 if LEAGUE[tostring(map.id or"")]then drawMap(map,fx,fz);drew=true end
 -- neighbouring League maps: their fires, badges and flags stay alive
 local RD
 for _,nb in ipairs(state.neighbors or{})do
  if nb.map and LEAGUE[tostring(nb.map.id or"")]then
   if RD==nil then local ok,m=pcall(V.require,"RenderDistance");RD=ok and m or false end
   local visible=true
   if RD and RD.neighbor then local ok,v=pcall(RD.neighbor,nb,p);if ok then visible=v and true or false end end
   if visible then pcall(drawMap,nb.map,fx,fz,nb.ox or 0,nb.oy or 0);drew=true end
  end
 end
 return drew
end
-- TEST165: the four warm ground pools nearest the player (world space, with
-- the neighbour offset), for the scene's street-lamp lights. nil elsewhere.
function M.lampPools(state)
 local function pick(map,ox,oz)
  local LA=architecture()
  if not(LA and map)then return nil end
  local ok,on=pcall(LA.enabled,map);if not(ok and on)then return nil end
  local slot=cache[map]
  if not(slot and slot.kind=='arch'and slot.pools and #slot.pools>0)then return nil end
  return slot.pools,ox,oz
 end
 local map=state and state.map
 if not map then return nil end
 local pools,ox,oz=pick(map,0,0)
 if not pools then return nil end
 local p=state.player;local px,pz=(p and p.px or 0)+8,(p and p.py or 0)+8
 local sorted={}
 for _,q in ipairs(pools)do sorted[#sorted+1]={q[1]+ox,q[2],q[3]+oz,((q[1]+ox-px)^2+(q[3]+oz-pz)^2)}end
 table.sort(sorted,function(a,b)return a[4]<b[4]end)
 local out={}
 for i=1,4 do local q=sorted[min(i,#sorted)];out[i]={q[1],q[2],q[3]}end
 return out
end

-- TEST166: the Route 22 gate's antechamber (LeagueGateRoom) -- its two
-- braziers, candles and sconces, the eight badges turning over the north
-- portal, and warm pools under the chandeliers. fx is LeagueGateRoom.fx().
local badgeParts={}
local function partsFor(name)
 local p=badgeParts[name]
 if p==nil then
  local b=BYNAME[name];p=false
  if b then p={};b.build(function(col,fn)local g=group();fn(g);p[#p+1]={mesh=mesh(g),col=col}end)end
  badgeParts[name]=p
 end
 return p or nil
end
-- LOADING-STUTTER: the gate room's badge meshes, built ahead with the room
-- (LeagueGateRoom's warm-ahead job) instead of on its first frame inside
function M.warmBadges(fx)
 for _,b in ipairs(fx and fx.badges or{})do yieldPoint();partsFor(b.name)end
 warmShared()
end
local function drawRoomFx(fx)
 if not fx then return end
 units()
 local g=love.graphics
 local wt,st=white(),soft()
 if not(wt and st and unitCross and unitQuad)then return end
 local ft=flameT() or st
 local t=0;pcall(function()t=love.timer.getTime()end)
 OX,OZ=0,0
 local glow=fx.glow or .55
 local pushed=pcall(g.push,"all")
 pcall(function()
  g.setDepthMode("lequal",true);g.setBlendMode("alpha")
  Voxel3D.lighting(false)
  for _,b in ipairs(fx.badges or{})do
   local parts=partsFor(b.name)
   if parts then
    local bob=sin(t*1.1+b.phase)*.25
    local m=Mat4.mul(Mat4.translate(b.x,b.y+bob,b.z),Mat4.mul(Mat4.rotateY(sin(t*.55+b.phase)*.55),Mat4.scale(b.s,b.s,b.s)))
    for _,pt in ipairs(parts)do
     if pt.mesh then g.setColor(pt.col[1],pt.col[2],pt.col[3],1);Voxel3D.draw(pt.mesh,wt,m)end
    end
   end
  end
  Voxel3D.lighting(true)
 end)
 pcall(Voxel3D.lighting,true)
 if pushed then pcall(g.pop)end
 pcall(Voxel3D.withEffect,"alpha",function()
  for _,f in ipairs(fx.fires or{})do flameBody(g,ft,f.x,f.y,f.z,t,f.phase,f.s)end
  for _,c in ipairs(fx.candles or{})do
   local fl=.86+.14*sin(t*12.7+c.phase)
   g.setColor(1,.82,.42,.95)
   Voxel3D.draw(unitCross,ft,Mat4.mul(Mat4.translate(c.x,c.y+1.05*c.s*fl,c.z),Mat4.scale(.42*c.s,1.05*c.s*fl,.42*c.s)))
  end
 end)
 pcall(Voxel3D.withEffect,"add",function()
  for _,f in ipairs(fx.fires or{})do flameGlow(g,st,f.x,f.y,f.z,t,f.phase,f.s,glow)end
  for _,c in ipairs(fx.candles or{})do
   g.setColor(1,.64,.28,(c.a or .26)*(.88+.12*sin(t*8.3+c.phase)))
   Voxel3D.draw(unitCross,st,Mat4.mul(Mat4.translate(c.x,c.y+.9*c.s,c.z),Mat4.scale(3.4*c.s,3.4*c.s,3.4*c.s)))
  end
  for _,b in ipairs(fx.badges or{})do
   local c=(BYNAME[b.name]or{}).col or{1,1,1}
   g.setColor(c[1],c[2],c[3],.16+.05*sin(t*1.7+b.phase))
   Voxel3D.draw(unitCross,st,Mat4.mul(Mat4.translate(b.x,b.y,b.z-1.2),Mat4.scale(b.s*4.2,b.s*4.2,.2)))
  end
  for _,p in ipairs(fx.pools or{})do
   g.setColor(1,.74,.42,p.a or .08)
   Voxel3D.draw(unitQuad,st,Mat4.mul(Mat4.translate(p.x,p.y,p.z),Mat4.scale(p.r,1,p.r)))
  end
 end)
 pcall(g.setColor,1,1,1,1)
end
M.drawRoomFx=drawRoomFx
-- TEST172: the effect kit, shared with the League rooms (LeagueRoomFx):
-- textures, unit meshes, stream meshes, flames and the fireworks.
function M.fxKit()
 units()
 OX,OZ=0,0
 return {white=white(),soft=soft(),flame=flameT(),streak=streakT(),ring=ringT(),
  cross=unitCross,quad=unitQuad,cone=coneMesh,panel=unitPanel,
  newStream=newStream,streamPut=streamPut,flameBody=flameBody,flameGlow=flameGlow,
  fireworks=fireworks,partsFor=partsFor,BYNAME=BYNAME}
end

function M.invalidate()
 if fwPool then
  for _,sm in ipairs(fwPool)do if sm.mesh and sm.mesh.release then pcall(sm.mesh.release,sm.mesh)end end
 end
 fwPool=nil
 pcall(function()V.require("LeagueNight").invalidate()end)
 pcall(function()V.require("LeagueRoomFx").invalidate()end)
 for _,p in pairs(badgeParts)do
  if p then for _,pt in ipairs(p)do if pt.mesh and pt.mesh.release then pcall(pt.mesh.release,pt.mesh)end end end
 end
 badgeParts={}
 for _,s in pairs(cache)do release(s)end
 cache=setmetatable({},{__mode='k'})
 for _,m in pairs({whiteTex,softTex,unitCross,unitQuad,coneMesh,unitPanel,flameTex,streakTex,ringTex})do if m and m.release then pcall(m.release,m)end end
 whiteTex,softTex,unitCross,unitQuad,coneMesh,unitPanel,flameTex,streakTex,ringTex=nil,nil,nil,nil,nil,nil,nil,nil,nil
end
Assets.register(M.invalidate)
return M
