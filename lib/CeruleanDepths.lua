-- TEST204: THE UNKNOWN DUNGEON. Cerulean Cave is the last place in Kanto,
-- the cave where Mewtwo waits, and until now it looked like any other cave
-- with a different fog. Here it gets a character of its own that builds as
-- you go down:
--
--   * CRYSTAL CROWNS. Since TEST203 the maze walls stand at 16, so you see
--     their tops. Some wall tops now carry clusters of glowing crystal that
--     light the path beside them. They work as landmarks, and as lamps
--     along the corridors.
--   * LEVITATING SHARDS. Chunks of rock with crystal undersides hang in the
--     air over the water and the deep rock, bobbing and turning slowly,
--     each throwing its colour onto the water below. One that would come
--     between the camera and you rises and shrinks out of the way.
--   * LUMINOUS WATER. Points of light drift and twinkle on the channels,
--     with broad soft patches of glow under the surface.
--   * IT GETS STRONGER AS YOU DESCEND. 1F is cerulean (cyan crystals, few
--     shards), 2F turns violet, and B1F is deep psychic violet with the
--     most shards and crowns.
--   * THE SANCTUM (B1F). Where Mewtwo stands: a carved stone ring inlaid in
--     the floor with glowing grooves and turning glyphs, a column of violet
--     light rising out of sight, shards orbiting overhead, motes spiralling
--     up and a slow pulse rolling out across the floor. Once Mewtwo has
--     been caught or beaten the chamber goes quiet: the column and the
--     pulse fade, the shards sink and slow, and the ring keeps a faint glow.
--
-- No Pokemon is modelled here: the sanctum is all stone and light, and the
-- engine's own Mewtwo stands in the middle of it as always.
-- Presentation only: no collision, warp, encounter, tile or Surf change.
-- CAVE DETAILS: OFF draws none of it, SUBTLE about half of it, FULL all.
local V=...
local Assets=require("src.render.Assets")
local Mat4=V.require("Mat4")
local Voxel3D=V.require("Voxel3D")
local CommunityVisuals=V.require("CommunityVisuals")

local M={REVISION='cerulean-depths-207'}
local pi,cos,sin,floor,min,max,abs,sqrt=math.pi,math.cos,math.sin,math.floor,math.min,math.max,math.abs,math.sqrt
local cache=setmetatable({},{__mode='k'})
local toneTex,beamTex,glyphTex
local shardKit
local awakeByMap={}
local lastAwake

local function hash01(x,z,salt)
 local n=(x*73856093+z*19349663+salt*83492791)%104729
 if n<0 then n=n+104729 end
 return n/104729
end
local function smooth(a,b,x)
 local t=min(1,max(0,(x-a)/(b-a)));return t*t*(3-2*t)
end
local function mapId(map)return tostring(map and map.id or""):upper()end
-- which floor: 1 (1F), 2 (2F), 3 (B1F); nil elsewhere
local FLOOR={CERULEAN_CAVE_1F=1,CERULEAN_CAVE_2F=2,CERULEAN_CAVE_B1F=3}
function M.floorOf(map)return FLOOR[mapId(map)]end
local function caveMap(map)
 local tid=map and tostring((map.def and map.def.tileset)or(map.tileset and map.tileset.id)or"")or""
 return tid=="CAVERN"
end
local function detail()
 local ok,d=pcall(CommunityVisuals.caveDetailLevel)
 return ok and d or"full"
end
function M.applies(map)
 if not(M.floorOf(map)and caveMap(map))then return false end
 local ok,custom=pcall(CommunityVisuals.customCaves)
 return ok and custom and true or false
end

-- How much each floor gets. B1F is the climax.
M.TIER={
 {crowns=.060,shards=.050,shardCap=10,specks=2,spacing=58,crownCap=22},
 {crowns=.080,shards=.075,shardCap=14,specks=2,spacing=52,crownCap=28},
 {crowns=.110,shards=.110,shardCap=20,specks=3,spacing=44,crownCap=36},
}
-- Mewtwo's cell on B1F (pokered: object_event 27, 13)
M.SANCTUM={cx=27,cy=13}
M.SANCTUM_COL={core={.84,.42,1.00},cyan={.44,.90,1.00},pale={.95,.88,1.00}}
M.ROCK={.42,.40,.48}
-- TEST205/206: each floor's water ({deep, shallow, glowA, glowB}; see
-- CeruleanWater)
M.WATER={
 {deep={.010,.036,.060},shallow={.050,.150,.200},glowA={.22,.82,.96},glowB={.42,.40,.98}},
 {deep={.018,.026,.066},shallow={.064,.084,.190},glowA={.46,.42,1.00},glowB={.24,.78,.96}},
 {deep={.026,.014,.058},shallow={.096,.060,.190},glowA={.72,.36,1.00},glowB={.26,.80,1.00}},
}


------------------------------------------------------------------ textures
local function newTex(w,h,fn,wrap)
 local ok,img=pcall(function()
  local d=love.image.newImageData(w,h)
  for y=0,h-1 do for x=0,w-1 do
   local r,g,b,a=fn(x,y)
   d:setPixel(x,y,r,g,b,a)
  end end
  local made=love.graphics.newImage(d,{mipmaps=false})
  made:setFilter("linear","linear");made:setWrap(wrap or"clamp","clamp")
  d:release()
  return made
 end)
 return ok and img or nil
end
-- a brightness ramp picked by u: lets one unlit mesh carry its own facet
-- shading (the unlit pass ignores vertex shade). u=0 dark, u=1 white.
local function tone()
 if not toneTex then toneTex=newTex(16,1,function(x)
  local v=.30+.70*(x/15);return v,v,v,1 end)end
 return toneTex
end
-- a column of light: bright at its foot, fading to nothing at the top,
-- with soft vertical edges round the cylinder (u wraps)
local function beam()
 if not beamTex then beamTex=newTex(32,64,function(x,y)
  local u=(x+.5)/32;local v=(y+.5)/64          -- v=0 the foot
  local fade=(1-v)^1.6*min(1,v*10)
  local ripple=.88+.12*sin(u*pi*2*3+v*7)
  return 1,1,1,max(0,min(1,fade*ripple))
 end,"repeat")end
 return beamTex
end
-- six glyphs round a ring: small pointed lozenges with a dot, drawn as a
-- radial texture so one quad carries the whole ring of them
local function glyphs()
 if not glyphTex then glyphTex=newTex(128,128,function(x,y)
  local u,v=(x+.5)/64-1,(y+.5)/64-1
  local r=sqrt(u*u+v*v);local a=math.atan2(v,u)
  local seg=(a/(pi*2)*6)%1-.5             -- -.5..5 within a glyph's sector
  local s=0
  -- the lozenge: thin along the ring, pointed at both ends
  local dr=abs(r-.78)/.10;local da=abs(seg)/.11
  if dr+da<1 then s=max(s,(1-(dr+da))^.6)end
  -- a dot inside the ring, between the glyphs
  local seg2=((a/(pi*2)*6)+.5)%1-.5
  local dd=sqrt((r-.60)^2*90+(seg2*.60*6.283/6)^2*90)
  if dd<1 then s=max(s,(1-dd)^1.2*.8)end
  -- two hairline rings
  s=max(s,max(0,1-abs(r-.92)/.018)*.9,max(0,1-abs(r-.52)/.014)*.7)
  if r>.99 then s=0 end
  return 1,1,1,min(1,s)
 end)end
 return glyphTex
end

------------------------------------------------------------------ meshes
local function group()return{verts={},indices={},quads=0}end
-- u: tone (0 dark .. 1 white), shade: lit-pass face light
local function quad(g,a,b,c,d,u,shade,uvs)
 local s=shade or 1
 if uvs then
  g.verts[#g.verts+1]={a[1],a[2],a[3],uvs[1],uvs[2],s}
  g.verts[#g.verts+1]={b[1],b[2],b[3],uvs[3],uvs[4],s}
  g.verts[#g.verts+1]={c[1],c[2],c[3],uvs[5],uvs[6],s}
  g.verts[#g.verts+1]={d[1],d[2],d[3],uvs[7],uvs[8],s}
 else
  local uu=min(.97,max(.03,u or 1))
  g.verts[#g.verts+1]={a[1],a[2],a[3],uu,.5,s}
  g.verts[#g.verts+1]={b[1],b[2],b[3],uu,.5,s}
  g.verts[#g.verts+1]={c[1],c[2],c[3],uu,.5,s}
  g.verts[#g.verts+1]={d[1],d[2],d[3],uu,.5,s}
 end
 Voxel3D.pushQuad(g.indices,g.quads);g.quads=g.quads+1
end
local function mesh(g)if g.quads==0 then return nil end;return Voxel3D.newMesh(g.verts,g.indices)end
local SOFTUV={0,0,1,0,1,1,0,1}
local function hquad(g,x,y,z,r)
 quad(g,{x-r,y,z-r},{x+r,y,z-r},{x+r,y,z+r},{x-r,y,z+r},nil,1,SOFTUV)
end
local function cross(g,x,y,z,w,h)
 quad(g,{x-w,y-h,z},{x+w,y-h,z},{x+w,y+h,z},{x-w,y+h,z},nil,1,SOFTUV)
 quad(g,{x,y-h,z-w},{x,y-h,z+w},{x,y+h,z+w},{x,y+h,z-w},nil,1,SOFTUV)
end
local function faceShade(a,b,d)
 local ux,uy,uz=b[1]-a[1],b[2]-a[2],b[3]-a[3]
 local vx,vy,vz=d[1]-a[1],d[2]-a[2],d[3]-a[3]
 local nx,ny,nz=uy*vz-uz*vy,uz*vx-ux*vz,ux*vy-uy*vx
 local l=sqrt(nx*nx+ny*ny+nz*nz);if l<1e-6 then return .8 end
 ny,nx=abs(ny/l),nx/l
 return .62+.30*ny+.10*nx
end

-- A hexagonal crystal leaning along (ax,ay,az): facets alternate tones so it
-- keeps its form while self-lit; the tip is the brightest
local function crystal(g,x,y,z,ax,ay,az,r,len)
 local n=6
 local ux,uy,uz
 if abs(ay)<.9 then ux,uy,uz=-az,0,ax else ux,uy,uz=1,0,0 end
 local ul=sqrt(ux*ux+uy*uy+uz*uz);ux,uy,uz=ux/ul,uy/ul,uz/ul
 local vx,vy,vz=ay*uz-az*uy,az*ux-ax*uz,ax*uy-ay*ux
 local body=len*.74
 local tip={x+ax*len,y+ay*len,z+az*len}
 local r0,r1={},{}
 for i=0,n-1 do
  local a=i/n*pi*2
  local cx,cy,cz=(ux*cos(a)+vx*sin(a))*r,(uy*cos(a)+vy*sin(a))*r,(uz*cos(a)+vz*sin(a))*r
  r0[i]={x+cx-ax*.5,y+cy-ay*.5,z+cz-az*.5}
  r1[i]={x+cx*.9+ax*body,y+cy*.9+ay*body,z+cz*.9+az*body}
 end
 for i=0,n-1 do
  local j=(i+1)%n
  quad(g,r0[i],r0[j],r1[j],r1[i],(i%2==0)and .62 or .40)
  quad(g,r1[i],r1[j],tip,tip,(i%2==0)and 1 or .80)
 end
end

-- The floating shard, built once in three shapes about the origin: a
-- rough rock cap (lit) over an inverted crystal point (self-lit), with a
-- couple of crystal spurs breaking through the cap.
local function buildShardKit()
 local kit={}
 for v=1,3 do
  local rock,cry=group(),group()
  local n=6+(v%2)
  local ring,cap={},{}
  for i=0,n-1 do
   local a=i/n*pi*2+hash01(v,i,2101)*.5
   local k=.78+hash01(i,v,2103)*.40
   ring[i]={cos(a)*k,(hash01(v,i,2105)-.5)*.18,sin(a)*k}
   local k2=.42+hash01(i,v,2107)*.22
   cap[i]={cos(a+.2)*k2,.42+hash01(v,i,2109)*.22,sin(a+.2)*k2}
  end
  local top={(hash01(v,1,2111)-.5)*.2,.62+hash01(v,2,2113)*.16,(hash01(v,3,2115)-.5)*.2}
  for i=0,n-1 do local j=(i+1)%n
   quad(rock,ring[i],ring[j],cap[j],cap[i],nil,faceShade(ring[i],ring[j],cap[i]))
   quad(rock,cap[i],cap[j],top,top,nil,1.0)
  end
  -- the crystal underside: an inverted point, slightly off centre
  local tip={(hash01(v,4,2117)-.5)*.35,-1.05-hash01(v,5,2119)*.45,(hash01(v,6,2121)-.5)*.35}
  for i=0,n-1 do local j=(i+1)%n
   local a,b={ring[i][1]*.94,ring[i][2]-.02,ring[i][3]*.94},{ring[j][1]*.94,ring[j][2]-.02,ring[j][3]*.94}
   quad(cry,a,b,tip,tip,(i%2==0)and .95 or .60)
  end
  -- two spurs through the cap
  for s=1,2 do
   local a=hash01(v,s,2123)*pi*2
   local bx,bz=cos(a)*.30,sin(a)*.30
   local lx,lz=cos(a)*.45,sin(a)*.45
   local l=sqrt(lx*lx+1+lz*lz)
   crystal(cry,bx,.38,bz,lx/l,1/l,lz/l,.13+.05*s,.55+hash01(s,v,2125)*.35)
  end
  kit[v]={rock=mesh(rock),cry=mesh(cry)}
 end
 return kit
end
local function shards()
 if not shardKit then
  local ok,k=pcall(buildShardKit)
  shardKit=ok and k or false
 end
 return shardKit or nil
end

-- the sanctum's stone inlay: an annulus of flagstones (lit) and the
-- grooves between them (self-lit), centred on the origin
-- ok(dx,dz): is the floor there walkable? (stones never float over the
-- water or sink into a wall)
local function buildInlay(ok)
 ok=ok or function()return true end
 local stone,groove=group(),group()
 local rings={{9,17,10},{17,27,14},{27,34,20}}
 for ri,rg in ipairs(rings)do
  local r0,r1,n=rg[1],rg[2],rg[3]
  for i=0,n-1 do
   local a0=(i+.06)/n*pi*2+ri*.3
   local a1=(i+.94)/n*pi*2+ri*.3
   local y=.10+hash01(ri,i,2201)*.05
   local sh=.78+hash01(i,ri,2203)*.20
   local am,rm=(a0+a1)*.5,(r0+r1)*.5
   if ok(cos(am)*rm,sin(am)*rm)then
   quad(stone,{cos(a0)*(r0+.35),y,sin(a0)*(r0+.35)},{cos(a1)*(r0+.35),y,sin(a1)*(r0+.35)},
              {cos(a1)*(r1-.35),y,sin(a1)*(r1-.35)},{cos(a0)*(r1-.35),y,sin(a0)*(r1-.35)},nil,sh)
   -- the radial groove after this stone
   local g0,g1=(i+.94)/n*pi*2+ri*.3,(i+1.06)/n*pi*2+ri*.3
   quad(groove,{cos(g0)*r0,.13,sin(g0)*r0},{cos(g1)*r0,.13,sin(g1)*r0},
               {cos(g1)*r1,.13,sin(g1)*r1},{cos(g0)*r1,.13,sin(g0)*r1},.85)
   end
  end
  -- the ring groove at the inner edge
  local m=36
  for i=0,m-1 do
   local a0,a1=i/m*pi*2,(i+1)/m*pi*2
   local am=(a0+a1)*.5
   if ok(cos(am)*r0,sin(am)*r0)then
   quad(groove,{cos(a0)*(r0-.35),.14,sin(a0)*(r0-.35)},{cos(a1)*(r0-.35),.14,sin(a1)*(r0-.35)},
               {cos(a1)*(r0+.35),.14,sin(a1)*(r0+.35)},{cos(a0)*(r0+.35),.14,sin(a0)*(r0+.35)},1)
   end
  end
 end
 local m=48
 for i=0,m-1 do
  local a0,a1=i/m*pi*2,(i+1)/m*pi*2
  local am=(a0+a1)*.5
  if ok(cos(am)*34,sin(am)*34)then
  quad(groove,{cos(a0)*33.6,.14,sin(a0)*33.6},{cos(a1)*33.6,.14,sin(a1)*33.6},
              {cos(a1)*34.4,.14,sin(a1)*34.4},{cos(a0)*34.4,.14,sin(a0)*34.4},1)
  end
 end
 return mesh(stone),mesh(groove)
end
-- an open cylinder of radius 1, height 1, for the light column
local function buildColumn()
 local g,n=group(),16
 for i=0,n-1 do
  local a0,a1=i/n*pi*2,(i+1)/n*pi*2
  quad(g,{cos(a0),0,sin(a0)},{cos(a1),0,sin(a1)},{cos(a1)*.7,1,sin(a1)*.7},{cos(a0)*.7,1,sin(a0)*.7},
   nil,1,{i/n,0,(i+1)/n,0,(i+1)/n,1,i/n,1})
 end
 return mesh(g)
end

------------------------------------------------------------------ build
local function floorAt(map,cx,cy)
 local ok,h=pcall(V.require("VoxelScene").groundAt,map,cx,cy,cx*16,cy*16)
 return(ok and tonumber(h))or 0
end
local WATER_Y=0       -- TEST207: cave water is ground, at the floor plane

local function build(map,level)
 local fl=M.floorOf(map)
 local tier=M.TIER[fl]
 local full=level=="full"
 local wc,hc=map.widthCells or 0,map.heightCells or 0
 local function inb(cx,cy)return cx>=0 and cy>=0 and cx<wc and cy<hc end
 local function walk(cx,cy)
  if not inb(cx,cy)then return false end
  local ok,r=pcall(map.isWalkableCell,map,cx,cy)
  return ok and r or false
 end
 local function water(cx,cy)
  if not(map.isWaterCell and inb(cx,cy))then return false end
  local ok,r=pcall(map.isWaterCell,map,cx,cy)
  return ok and r or false
 end
 local function wall(cx,cy)return inb(cx,cy)and not walk(cx,cy)and not water(cx,cy)end
 local okR,Rubble=pcall(V.require,"CaveRubble")
 local top=(okR and Rubble and Rubble.wallTop and Rubble.wallTop(map))or 30
 local Sconces=V.require("CaveSconces")
 local function torchy(cx,cy)
  local r=false;pcall(function()r=Sconces.reserved(map,cx,cy)end);return r
 end
 local sanc=nil
 if fl==3 then
  local s=M.SANCTUM
  sanc={x=s.cx*16+8,z=s.cy*16+8,y=floorAt(map,s.cx,s.cy),cx=s.cx,cy=s.cy}
 end
 local function sanctumNear(x,z,r)
  if not sanc then return false end
  local dx,dz=x-sanc.x,z-sanc.z;return dx*dx+dz*dz<r*r
 end

 local slot={level=level,floor=fl,top=top,sanctum=sanc,shards={},crowns={}}
 local crys={group(),group()}
 local halo={group(),group()}
 local spill={group(),group()}
 local placed={}
 local function spaced(x,z,d)
  for _,p in ipairs(placed)do local dx,dz=p[1]-x,p[2]-z;if dx*dx+dz*dz<d*d then return false end end
  return true
 end

 -- 1. crystal crowns on the wall tops that face a path or the water
 local cap=full and tier.crownCap or floor(tier.crownCap*.45)
 local density=full and tier.crowns or tier.crowns*.6
 for cy=0,hc-1 do for cx=0,wc-1 do
  if #placed<cap and wall(cx,cy)then
   local openSide=nil
   for _,d in ipairs({{0,1},{1,0},{-1,0},{0,-1}})do
    if walk(cx+d[1],cy+d[2])then openSide=d;break end
   end
   local x,z=cx*16+8,cy*16+8
   local p=density
   if sanc then
    if sanctumNear(x,z,44)then p=0             -- keep the sanctum's own light clean
    elseif sanctumNear(x,z,130)then p=p*2.4 end -- the approach glitters
   end
   if openSide and hash01(cx,cy,2301)<p and not torchy(cx,cy)
      and spaced(x,z,tier.spacing*(full and 1 or 1.3))then
    placed[#placed+1]={x,z}
    local seed=cx*131+cy*71
    local ci=hash01(seed,1,2303)<(fl==1 and .70 or(fl==2 and .55 or .62))and 1 or 2
    local count=3+floor(hash01(seed,2,2305)*4)
    local sizeK=.9+hash01(seed,3,2307)*.6
    if hash01(seed,4,2309)>.86 then sizeK=sizeK*1.3;count=count+2 end
    -- lean toward the path below, as if grown toward the light
    local dx,dz=openSide[1],openSide[2]
    local ox,oz=(hash01(seed,5,2311)-.5)*6,(hash01(seed,6,2313)-.5)*6
    for k=0,count-1 do
     local a=(k/count)*pi*2+hash01(seed,k,2315)*1.3
     local spread=(k==0)and 0 or(1.0+hash01(k,seed,2317)*2.6)*sizeK
     local bx=x+ox+cos(a)*spread
     local bz=z+oz+sin(a)*spread
     local lx=dx*.30+cos(a)*.42
     local lz=dz*.30+sin(a)*.42
     local ly=1.2+hash01(seed,k,2319)*.8
     local l=sqrt(lx*lx+ly*ly+lz*lz)
     local len=(k==0 and(6+hash01(seed,k,2321)*5)or(2.6+hash01(seed,k,2323)*3.6))*sizeK
     local r=(k==0 and 1.15 or .55+hash01(k,seed,2325)*.45)*sizeK
     crystal(crys[ci],bx,top,bz,lx/l,ly/l,lz/l,r,len)
    end
    cross(halo[ci],x+ox,top+5*sizeK,z+oz,8*sizeK,7*sizeK)
    hquad(halo[ci],x+ox,top+.12,z+oz,9*sizeK)
    -- the light it throws on the path below
    local px,pz=(cx+dx)*16+8,(cy+dz)*16+8
    local fy=floorAt(map,cx+dx,cy+dz)
    hquad(spill[ci],px-dx*3,fy+.16,pz-dz*3,13+4*sizeK)
    slot.crowns[#slot.crowns+1]={x=x+ox,z=z+oz,y=top,ci=ci,phase=hash01(seed,7,2327)*6.28}
   end
  end
 end end

 -- 2. levitating shards over the water and the deep rock
 local scap=full and tier.shardCap or floor(tier.shardCap*.45)
 local sdens=full and tier.shards or tier.shards*.6
 local spots={}
 for cy=1,hc-2 do for cx=1,wc-2 do
  local w=water(cx,cy)
  local n=0
  if wall(cx,cy)then
   for _,d in ipairs({{1,0},{-1,0},{0,1},{0,-1}})do if wall(cx+d[1],cy+d[2])then n=n+1 end end
  end
  -- over the water, or over the rock where the wall is thick (never over
  -- a path, so one never hangs in front of you in a corridor)
  if(w or n>=3)and hash01(cx,cy,2401)<sdens*(w and 4 or 2)then
   spots[#spots+1]={cx,cy,w,hash01(cx,cy,2403)}
  end
 end end
 table.sort(spots,function(a,b)return a[4]<b[4]end)
 local sp={}
 for _,s in ipairs(spots)do
  if #slot.shards>=scap then break end
  local x=s[1]*16+8+(hash01(s[1],s[2],2405)-.5)*8
  local z=s[2]*16+8+(hash01(s[1],s[2],2407)-.5)*8
  local ok=not sanctumNear(x,z,56)
  local gap=fl==3 and 48 or 56
  for _,q in ipairs(sp)do local dx,dz=q[1]-x,q[2]-z;if dx*dx+dz*dz<gap*gap then ok=false;break end end
  if ok then
   sp[#sp+1]={x,z}
   local seed=s[1]*97+s[2]*53
   local size=2.4+hash01(seed,1,2409)*2.8
   if hash01(seed,2,2411)>.80 then size=size*1.5 end
   slot.shards[#slot.shards+1]={
    x=x,z=z,overWater=s[3],
    y=(s[3]and 22 or top+10)+hash01(seed,3,2413)*14,
    s=size,v=1+floor(hash01(seed,4,2415)*3)%3,
    spin=(hash01(seed,5,2417)-.5)*.5,phase=hash01(seed,6,2419)*6.28,
    bob=1.2+hash01(seed,7,2421)*1.6,tilt=(hash01(seed,8,2423)-.5)*.5,
    ci=hash01(seed,9,2425)<.55 and 1 or 2,
    glowY=s[3]and WATER_Y+.25 or top+.15}
  end
 end

 -- 3. luminous water: twinkling points (two sets, out of phase) and broad
 --    soft patches of light under the surface
 local speckA,speckB,patch=group(),group(),group()
 local per=full and tier.specks or 1
 for cy=0,hc-1 do for cx=0,wc-1 do
  if water(cx,cy)then
   for k=1,per do
    local x=cx*16+2+hash01(cx*7+k,cy,2501)*12
    local z=cy*16+2+hash01(cx,cy*7+k,2503)*12
    local r=.35+hash01(cx,cy+k,2505)*.50
    hquad((k+cx+cy)%2==0 and speckA or speckB,x,WATER_Y+.30,z,r)
   end
   if hash01(cx,cy,2507)<(fl==3 and .30 or .20)then
    hquad(patch,cx*16+8,WATER_Y+.20,cy*16+8,10+hash01(cx,cy,2509)*8)
   end
  end
 end end

 slot.crys={mesh(crys[1]),mesh(crys[2])}
 slot.halo={mesh(halo[1]),mesh(halo[2])}
 slot.spill={mesh(spill[1]),mesh(spill[2])}
 slot.speckA,slot.speckB,slot.patch=mesh(speckA),mesh(speckB),mesh(patch)
 if sanc then
  sanc.stone,sanc.groove=buildInlay(function(dx,dz)
   return walk(floor((sanc.x+dx)/16),floor((sanc.z+dz)/16))
  end)
  sanc.column=buildColumn()
  sanc.orbit={}
  local n=full and 6 or 4
  for i=1,n do
   sanc.orbit[i]={a=(i-1)/n*pi*2,r=31+hash01(i,1,2601)*7,y=19+hash01(i,2,2603)*12,
    s=1.6+hash01(i,3,2605)*1.8,v=1+(i%3),spin=(hash01(i,4,2607)-.5)*1.2,phase=i*1.7}
  end
 end
 return slot
end

local function release(slot)
 if not slot then return end
 local list={slot.speckA,slot.speckB,slot.patch}
 for _,set in ipairs({slot.crys,slot.halo,slot.spill})do for _,m in pairs(set or{})do list[#list+1]=m end end
 if slot.sanctum then
  list[#list+1]=slot.sanctum.stone;list[#list+1]=slot.sanctum.groove;list[#list+1]=slot.sanctum.column
 end
 for _,m in ipairs(list)do if m and m.release then pcall(m.release,m)end end
end
local function slotFor(map)
 local level=detail()
 if level=="off" or not M.applies(map)then return nil end
 local s=cache[map]
 if s and s.level~=level then release(s);s=nil;cache[map]=nil end
 if s==nil then
  local ok,r=pcall(build,map,level)
  if not ok then
   if V.mod and V.mod.log and V.mod.log.info then pcall(V.mod.log.info,V.mod.log,'Cerulean depths failed: %s',tostring(r))end
   r=false
  end
  s=r or false;cache[map]=s
 end
 return s or nil
end

------------------------------------------------------------------ Mewtwo
-- Is the engine's Mewtwo still standing in the sanctum? (The object is
-- hidden once it has been caught or beaten.) Unknown -> assume yes.
local function isMewtwo(n)
 local d=type(n)=='table'and n.def
 if type(d)~='table'then return false end
 for _,k in ipairs({'name','id','text','sprite','pokemon','species'})do
  local v=d[k]
  if type(v)=='string'and v:upper():find('MEWTWO',1,true)then return true end
 end
 return d.sprite=='SPRITE_MONSTER'
end
function M.mewtwoPresent(state)
 local npcs=type(state)=='table'and state.npcs
 if type(npcs)~='table'then return nil end
 local s=M.SANCTUM
 for _,n in ipairs(npcs)do
  if type(n)=='table'and isMewtwo(n)then
   local cx,cy=tonumber(n.cellX),tonumber(n.cellY)
   if not cx or(abs(cx-s.cx)<=3 and abs(cy-s.cy)<=3)then return true end
  end
 end
 return false
end

------------------------------------------------------------------ draw
local lastT
local function nowT()
 local ok,t=pcall(love.timer.getTime);return ok and t or 0
end
local function kit()
 local ok,K=pcall(function()return V.require('LeagueRoad').fxKit()end)
 if ok and K and K.soft and K.quad and K.cross and K.ring and K.white then return K end
 return nil
end
local TR,SC,RY,RX,MUL=Mat4.translate,Mat4.scale,Mat4.rotateY,Mat4.rotateX,Mat4.mul

-- phase: 'solid', 'light' or nil for both (battle)
local function drawScene(map,slot,focusX,focusZ,battle,awake,phase)
 local K=kit();local tt,bt,gt=tone(),beam(),glyphs()
 if not(K and tt)then return false end
 local SK=shards()
 local g=love.graphics
 local t=nowT()
 local full=slot.level=="full"
 local okP,pal=pcall(function()return V.require("CaveMood").paletteFor(map)end)
 local cols=(okP and pal and pal.crystals)or{{.30,.92,1},{.70,.46,1}}
 local rock=M.ROCK
 local sanc=slot.sanctum
 local C=M.SANCTUM_COL
 local near=battle and 300 or 260

 -- which shards to draw: the nearest few in range, and how far each has
 -- shrunk away from the player (so none sits between camera and you)
 local list={}
 for _,s in ipairs(slot.shards)do
  local dx,dz=s.x-focusX,s.z-focusZ
  local d2=dx*dx+dz*dz
  if d2<near*near then list[#list+1]={s=s,d2=d2}end
 end
 table.sort(list,function(a,b)return a.d2<b.d2 end)
 local maxShards=full and 9 or 5
 for i=#list,maxShards+1,-1 do list[i]=nil end
 for _,e in ipairs(list)do
  local d=sqrt(e.d2)
  e.k=battle and smooth(40,70,d)or smooth(22,50,d)
  local s=e.s
  local b=sin(t*.55+s.phase)*s.bob
  e.y=s.y+b+(1-e.k)*16
  e.rot=t*s.spin+s.phase
 end

 -- 1. solid pieces: crowns, shard rock and crystal, the sanctum inlay
 if phase~='light' then
 local pushed=g.push and pcall(g.push,"all")
 pcall(function()
  g.setDepthMode("lequal",true)
  g.setBlendMode("alpha")
  if g.setMeshCullMode then g.setMeshCullMode("none")end
  Voxel3D.lighting(true)
  if SK then
   g.setColor(rock[1],rock[2],rock[3],1)
   for _,e in ipairs(list)do
    if e.k>.03 then
     local s=e.s;local sz=s.s*e.k
     Voxel3D.draw(SK[s.v].rock,K.white,MUL(TR(s.x,e.y,s.z),MUL(RY(e.rot),MUL(RX(s.tilt),SC(sz,sz,sz)))))
    end
   end
  end
  if sanc and sanc.stone then
   g.setColor(.34,.31,.40,1)
   Voxel3D.draw(sanc.stone,K.white,TR(sanc.x,sanc.y,sanc.z))
  end
  Voxel3D.lighting(false)
  for ci=1,2 do
   local c=cols[ci];local p=.86+.14*sin(t*.7+ci*2.1)
   if slot.crys[ci]then
    g.setColor(min(1,c[1]*p+.08),min(1,c[2]*p+.08),min(1,c[3]*p+.08),1)
    Voxel3D.draw(slot.crys[ci],tt)
   end
  end
  if SK then
   for _,e in ipairs(list)do
    if e.k>.03 then
     local s=e.s;local sz=s.s*e.k;local c=cols[s.ci]
     local p=.85+.15*sin(t*1.1+s.phase)
     g.setColor(min(1,c[1]*p+.10),min(1,c[2]*p+.10),min(1,c[3]*p+.10),1)
     Voxel3D.draw(SK[s.v].cry,tt,MUL(TR(s.x,e.y,s.z),MUL(RY(e.rot),MUL(RX(s.tilt),SC(sz,sz,sz)))))
    end
   end
   -- the sanctum's orbiting shards
   if sanc then
    local dx,dz=sanc.x-focusX,sanc.z-focusZ
    if dx*dx+dz*dz<near*near then
     for _,o in ipairs(sanc.orbit)do
      local a=o.a+t*(.10+.16*awake)
      local x,z=sanc.x+cos(a)*o.r,sanc.z+sin(a)*o.r
      local y=sanc.y+4+(o.y-4)*(.35+.65*awake)+sin(t*.8+o.phase)*1.4*awake
      local px,pz=x-focusX,z-focusZ
      local k=battle and 1 or smooth(10,24,sqrt(px*px+pz*pz))
      if k>.03 then
       local sz=o.s*k
       local m=MUL(TR(x,y,z),MUL(RY(t*o.spin+o.phase),MUL(RX(.3*sin(o.phase)),SC(sz,sz,sz))))
       local p=.75+.25*sin(t*1.6+o.phase)
       g.setColor(min(1,C.core[1]*p+.12),min(1,C.core[2]*p+.12),min(1,C.core[3]*p+.12),1)
       Voxel3D.draw(SK[o.v].cry,tt,m)
       Voxel3D.lighting(true)
       g.setColor(rock[1]*.9,rock[2]*.9,rock[3],1)
       Voxel3D.draw(SK[o.v].rock,K.white,m)
       Voxel3D.lighting(false)
      end
     end
    end
   end
  end
  Voxel3D.lighting(true)
 end)
 pcall(Voxel3D.lighting,true)
 if pushed then pcall(g.pop)end

 end
 if phase=='solid' then return true end
 -- 2. light: halos, path spill, water glow, shard glow, the sanctum.
 -- TEST205: drawn AFTER the water pass (drawLate) on the overworld: the
 -- water is drawn after the cave's set pieces and would paint over any
 -- light lying on it or hanging in front of it.
 pcall(Voxel3D.withEffect,"add",function()
  local fade=battle and .7 or 1
  for ci=1,2 do
   local c=cols[ci];local p=.80+.20*sin(t*.7+ci*2.1)
   if slot.halo[ci]then g.setColor(c[1],c[2],c[3],(full and .24 or .18)*p*fade);Voxel3D.draw(slot.halo[ci],K.soft)end
   if slot.spill[ci]then g.setColor(c[1],c[2],c[3],(full and .30 or .22)*p*fade);Voxel3D.draw(slot.spill[ci],K.soft)end
  end
  -- the water: wide glow, then the points twinkling in two sets
  local wc=cols[1]
  if slot.floor==3 then wc={(cols[1][1]+cols[2][1])*.5,(cols[1][2]+cols[2][2])*.5,(cols[1][3]+cols[2][3])*.5}end
  local drift=TR(sin(t*.11)*2.2,0,cos(t*.09)*2.2)
  if slot.patch then g.setColor(wc[1],wc[2],wc[3],(.06+.02*sin(t*.4))*fade);Voxel3D.draw(slot.patch,K.soft,drift)end
  if slot.speckA then g.setColor(wc[1],wc[2],wc[3],(.20+.26*(.5+.5*sin(t*1.3)))*fade);Voxel3D.draw(slot.speckA,K.soft,drift)end
  if slot.speckB then g.setColor(wc[1],wc[2],wc[3],(.20+.26*(.5+.5*sin(t*1.3+pi)))*fade);Voxel3D.draw(slot.speckB,K.soft,TR(-sin(t*.10)*2.0,0,-cos(t*.12)*2.0))end
  -- each shard's light on the surface beneath it, and a soft halo round it
  for _,e in ipairs(list)do
   if e.k>.03 then
    local s=e.s;local c=cols[s.ci];local sz=s.s*e.k
    local p=.8+.2*sin(t*1.1+s.phase)
    g.setColor(c[1],c[2],c[3],.26*p*e.k*fade)
    Voxel3D.draw(K.quad,K.soft,MUL(TR(s.x,s.glowY,s.z),SC(sz*3.2,1,sz*3.2)))
    g.setColor(c[1],c[2],c[3],.12*p*e.k*fade)
    Voxel3D.draw(K.cross,K.soft,MUL(TR(s.x,e.y-sz*.6,s.z),SC(sz*2.0,sz*2.0,sz*2.0)))
   end
  end
  -- the sanctum
  if sanc then
   local dx,dz=sanc.x-focusX,sanc.z-focusZ
   if dx*dx+dz*dz<(near+80)^2 then
    local x,y,z=sanc.x,sanc.y,sanc.z
    local breathe=.5+.5*sin(t*.9)
    local lvl=.30+.70*awake
    -- grooves in the inlay
    if sanc.groove then
     g.setColor(C.core[1],C.core[2],C.core[3],(.30+.25*breathe)*lvl)
     Voxel3D.draw(sanc.groove,K.white,TR(x,y+.02,z))
    end
    -- glyph rings turning against each other
    if gt then
     g.setColor(C.pale[1],C.pale[2],C.pale[3],(.40+.20*breathe)*lvl)
     Voxel3D.draw(K.quad,gt,MUL(TR(x,y+.24,z),MUL(RY(t*.12),SC(22,1,22))))
     g.setColor(C.cyan[1],C.cyan[2],C.cyan[3],(.26+.14*breathe)*lvl)
     Voxel3D.draw(K.quad,gt,MUL(TR(x,y+.26,z),MUL(RY(-t*.20+.5),SC(13,1,13))))
    end
    -- the floor under Mewtwo, and the glow of the whole ring
    g.setColor(C.core[1],C.core[2],C.core[3],(.20+.10*breathe)*lvl)
    Voxel3D.draw(K.quad,K.soft,MUL(TR(x,y+.20,z),SC(34,1,34)))
    g.setColor(C.pale[1],C.pale[2],C.pale[3],(.22+.12*breathe)*lvl)
    Voxel3D.draw(K.quad,K.soft,MUL(TR(x,y+.22,z),SC(12,1,12)))
    if awake>.02 then
     -- the slow pulse rolling out across the floor
     for k=0,1 do
      local u=(t*.30+k*.5)%1
      local r=10+u*70
      g.setColor(C.core[1],C.core[2],C.core[3],.34*(1-u)^1.5*awake)
      Voxel3D.draw(K.quad,K.ring,MUL(TR(x,y+.30,z),SC(r,1,r)))
     end
     -- the column of light (not in battle: it would stand over the fight)
     if not battle and bt and sanc.column then
      local flick=.88+.08*sin(t*1.7)+.04*sin(t*4.3)
      g.setColor(C.core[1],C.core[2],C.core[3],.38*flick*awake)
      Voxel3D.draw(sanc.column,bt,MUL(TR(x,y,z),SC(14,120,14)))
      g.setColor(C.pale[1],C.pale[2],C.pale[3],.34*flick*awake)
      Voxel3D.draw(sanc.column,bt,MUL(TR(x,y,z),MUL(RY(t*.3),SC(6.5,150,6.5))))
     end
     -- motes spiralling up round the column
     local motes=full and 10 or 5
     for k=0,motes-1 do
      local u=(t*.09+k/motes)%1
      local a=k*2.39996+t*(.5+.2*(k%3))
      local r=8+((k*7)%5)*2.6+u*4
      g.setColor(C.pale[1],C.pale[2],C.pale[3],.70*sin(u*pi)*awake)
      local sz=.55+.35*(1-u)
      Voxel3D.draw(K.cross,K.soft,MUL(TR(x+cos(a)*r,y+2+u*70,z+sin(a)*r),SC(sz,sz,sz)))
     end
    end
    -- the orbiting shards' glow
    for _,o in ipairs(sanc.orbit)do
     local a=o.a+t*(.10+.16*awake)
     local ox,oz=x+cos(a)*o.r,z+sin(a)*o.r
     local oy=y+4+(o.y-4)*(.35+.65*awake)
     g.setColor(C.core[1],C.core[2],C.core[3],.14*lvl)
     Voxel3D.draw(K.cross,K.soft,MUL(TR(ox,oy-o.s*.5,oz),SC(o.s*2.2,o.s*2.2,o.s*2.2)))
     g.setColor(C.core[1],C.core[2],C.core[3],.16*lvl)
     Voxel3D.draw(K.quad,K.soft,MUL(TR(ox,y+.28,oz),SC(o.s*3,1,o.s*3)))
    end
   end
  end
 end)
 pcall(g.setColor,1,1,1,1)
 return true
end

-- the sanctum wakes and settles gently rather than switching
local function awakeFor(map,present,dt)
 local id=mapId(map)
 local cur=awakeByMap[id]
 local target=(present==false)and 0 or 1
 if cur==nil then cur=target end
 local step=min(1,(dt or 0)*.5)
 cur=cur+(target-cur)*step
 awakeByMap[id]=cur
 return cur
end

local function partsFor(map)
 local fl=M.floorOf(map)
 if not fl then return nil end
 local okS,St=pcall(V.require,"CeruleanStone")
 local okW,Wa=pcall(V.require,"CeruleanWater")
 return okS and St or nil,okW and Wa or nil,M.WATER[fl]
end
function M.draw(state)
 local map,p=state and state.map,state and state.player
 local slot=map and slotFor(map)
 if not slot then return false end
 -- TEST206: the water's own body, before the engine's water pass (opaque)
 local _,Wa,spec=partsFor(map)
 if Wa then pcall(Wa.draw,map,spec)end
 local t=nowT();local dt=lastT and min(.25,max(0,t-lastT))or 0;lastT=t
 local awake=1
 if slot.sanctum then awake=awakeFor(map,M.mewtwoPresent(state),dt)end
 lastAwake=awake
 return drawScene(map,slot,(p and p.px or 0)+8,(p and p.py or 0)+8,false,awake,'solid')
end
-- TEST205: the light, after the water and the cast (DockLights.drawLate)
function M.drawLate(state)
 local map,p=state and state.map,state and state.player
 local slot=map and slotFor(map)
 if not slot then return false end
 local St,Wa,spec=partsFor(map)
 if Wa then pcall(Wa.drawLight,map,spec,false)end
 if St then pcall(St.drawLight,map,spec and spec.glowA)end
 return drawScene(map,slot,(p and p.px or 0)+8,(p and p.py or 0)+8,false,lastAwake or 1,'light')
end
function M.drawBattle(map,arena)
 local slot=map and slotFor(map)
 if not slot then return false end
 local St,Wa,spec=partsFor(map)
 if Wa then pcall(Wa.draw,map,spec);pcall(Wa.drawLight,map,spec,true)end
 if St then pcall(St.drawLight,map,spec and spec.glowA)end
 local mid=arena and arena.mid
 local awake=awakeByMap[mapId(map)]or 1
 return drawScene(map,slot,(mid and mid[1])or 0,(mid and mid[2])or 0,true,awake)
end

-- TEST205: the floor pass: the wall feet and the shores, on the floor
function M.drawFloor(state)
 local map=state and state.map
 if not(map and M.applies(map)and detail()~="off")then return false end
 local St=partsFor(map)
 if St then pcall(St.drawFloor,map)end
 return true
end

function M.invalidate()
 for _,s in pairs(cache)do release(s)end
 cache=setmetatable({},{__mode='k'})
 if shardKit then
  for _,v in ipairs(shardKit)do
   for _,m in pairs(v)do if m and m.release then pcall(m.release,m)end end
  end
 end
 shardKit=nil
 for _,m in ipairs({toneTex,beamTex,glyphTex})do if m and m.release then pcall(m.release,m)end end
 toneTex,beamTex,glyphTex=nil,nil,nil
end
Assets.register(M.invalidate)
return M
