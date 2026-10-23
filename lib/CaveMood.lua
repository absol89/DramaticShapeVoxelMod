-- TEST139: cave wonder. Adds four things on top of the approved cave walls,
-- dripstone, pools, motes and sconces (none of which change):
--   1. Depth fog. Caves had no fog; distant rock now fades into a cool
--      cave-dark haze, thicker near the floor, so tunnels feel deep.
--   2. Rolling ground mist. Soft, slowly turning sheets of mist hang just
--      above the floor in open chambers.
--   3. Glowing crystal clusters. Mineral crystals grow from the wall foot and
--      spill colored light onto the floor with a slow pulse. Each cave has its
--      own palette (Mt. Moon violet/blue, Rock Tunnel amber, Cerulean Cave
--      cyan/magenta, Seafoam ice, Victory Road gold, Diglett's earth-gold).
--   4. Light shafts. A few pale beams fall from cracks in the vault onto open
--      floor, with dust drifting through them.
-- Everything is presentation only: no collision, warps, encounters or tiles
-- change. CAVE DETAILS controls it: OFF disables all of it, SUBTLE uses
-- lighter fog, less mist, fewer crystals and a single shaft, FULL is all.
local V=...
local Assets=require("src.render.Assets")
local Mat4=V.require("Mat4")
local Voxel3D=V.require("Voxel3D")
local Structures=V.require("Structures")
local CommunityVisuals=V.require("CommunityVisuals")
local CaveSconces=V.require("CaveSconces")
local VoxelState=V.require("VoxelState")

local M={REVISION='cave-mood-206'}
local cache=setmetatable({},{__mode='k'})
local softTex,beamTex,whiteTex,unitQuad,unitCross,coneMesh
local floorTex,puddleTex,ringTex
local slateTex   -- TEST205: Cerulean Cave's floor
local pi,cos,sin,floor,min,max,abs,sqrt=math.pi,math.cos,math.sin,math.floor,math.min,math.max,math.abs,math.sqrt

local function keyOf(tx,ty)return (ty+64)*4096+(tx+64)end
local function hash01(x,z,salt)
 local n=(x*73856093+z*19349663+salt*83492791)%104729
 if n<0 then n=n+104729 end
 return n/104729
end
local function isCave(map)
 local tid=map and tostring((map.def and map.def.tileset)or(map.tileset and map.tileset.id)or"")or""
 return tid=="CAVERN" and CommunityVisuals.customCaves()
end
local function detail()
 local ok,d=pcall(CommunityVisuals.caveDetailLevel)
 return ok and d or "full"
end

------------------------------------------------------------------ palettes
local PALETTES={
 {match="^MT_MOON",       fog={.055,.055,.090}, mist={.58,.60,.80},
  crystals={{.62,.46,1.00},{.42,.72,1.00}}, beam={.78,.84,1.00}},
 {match="^ROCK_TUNNEL",   fog={.050,.042,.040}, mist={.62,.56,.50},
  crystals={{1.00,.62,.24},{1.00,.42,.18}}, beam={1.00,.88,.70}},
 -- TEST204: Cerulean Cave deepens floor by floor (CeruleanDepths): 1F
 -- cerulean, 2F violet, B1F the deep psychic violet of Mewtwo's chamber
 {match="^CERULEAN_CAVE_1F", fog={.026,.056,.086}, mist={.46,.70,.88},
  crystals={{.30,.92,1.00},{.66,.48,1.00}}, beam={.78,.92,1.00}},
 {match="^CERULEAN_CAVE_2F", fog={.040,.042,.094}, mist={.58,.60,.94},
  crystals={{.58,.50,1.00},{.30,.90,1.00}}, beam={.84,.86,1.00}},
 {match="^CERULEAN_CAVE_B1F", fog={.056,.028,.092}, mist={.74,.54,.98},
  crystals={{.86,.40,1.00},{.42,.86,1.00}}, beam={.92,.80,1.00}},
 {match="^CERULEAN_CAVE", fog={.040,.060,.075}, mist={.50,.68,.74},
  crystals={{.30,.96,.92},{.82,.40,1.00}}, beam={.80,.95,1.00}},
 {match="^SEAFOAM",       fog={.050,.075,.100}, mist={.66,.80,.92},
  crystals={{.55,.86,1.00},{.80,.95,1.00}}, beam={.85,.95,1.00}},
 {match="^VICTORY_ROAD",  fog={.060,.048,.040}, mist={.64,.58,.50},
  crystals={{1.00,.80,.30},{1.00,.38,.24}}, beam={1.00,.90,.70}},
 {match="^DIGLETTS_CAVE", fog={.055,.045,.036}, mist={.60,.54,.46},
  crystals={{.96,.74,.34},{.78,.92,.42}}, beam={1.00,.90,.72}},
}
local DEFAULT={fog={.050,.058,.068},mist={.56,.64,.70},
 crystals={{.42,.92,.84},{.60,.56,1.00}},beam={.85,.90,1.00}}
-- TEST154: glowworm and glowing-fungus colours per cave.
local LIFE={
 ["^MT_MOON"]={worm={.46,.88,1.00},fungi={{.40,1.00,.86},{.86,.52,1.00}},rock={.30,.27,.30}},
 ["^ROCK_TUNNEL"]={worm={.52,.96,.90},fungi={{.44,1.00,.70},{1.00,.62,.30}},rock={.33,.27,.22}},
 ["^CERULEAN_CAVE"]={worm={.42,.96,1.00},fungi={{.30,1.00,.92},{1.00,.40,.86}},rock={.25,.28,.31}},
 ["^SEAFOAM"]={worm={.62,.92,1.00},fungi={{.52,.90,1.00},{.70,1.00,.92}},rock={.30,.33,.37}},
 ["^VICTORY_ROAD"]={worm={.56,.96,.88},fungi={{.60,1.00,.52},{1.00,.74,.30}},rock={.33,.28,.23}},
 ["^DIGLETTS_CAVE"]={worm={.52,.94,.86},fungi={{.70,1.00,.46},{1.00,.80,.40}},rock={.32,.26,.20}},
}
local DEFAULT_LIFE={worm={.46,.94,1.00},fungi={{.38,1.00,.84},{.90,.50,1.00}},rock={.30,.27,.25}}
local function paletteFor(map)
 local id=tostring(map and map.id or ""):upper()
 local pal=DEFAULT
 for _,p in ipairs(PALETTES)do if id:match(p.match)then pal=p;break end end
 local life=DEFAULT_LIFE
 for k,l in pairs(LIFE)do if id:match(k)then life=l end end
 pal.worm,pal.fungi,pal.rock=life.worm,life.fungi,life.rock
 return pal
end

------------------------------------------------------------------ fog
-- Fog for the scene shader's existing fog uniforms. Units: 16 per cell.
function M.fog(map)
 if not isCave(map)then return nil end
 local d=detail()
 if d=="off" then return nil end
 local p=paletteFor(map)
 local full=d=="full"
 return {color=p.fog, density=full and .0105 or .0072, start=full and 34 or 52,
  heightK=.0045}
end
function M.battleFog(map)
 local f=M.fog(map)
 if not f then return nil end
 return {color=f.color,density=f.density*.55,start=f.start+30,heightK=f.heightK}
end

------------------------------------------------------------------ textures
local function newTex(w,h,fn)
 local ok,img=pcall(function()
  local d=love.image.newImageData(w,h)
  for y=0,h-1 do for x=0,w-1 do d:setPixel(x,y,1,1,1,fn(x,y))end end
  local made=love.graphics.newImage(d,{mipmaps=false})
  made:setFilter("linear","linear");made:setWrap("clamp","clamp")
  d:release()
  return made
 end)
 return ok and img or nil
end
local function noise2(x,y,s)
 local ix,iy=floor(x),floor(y);local fx,fy=x-ix,y-iy
 fx,fy=fx*fx*(3-2*fx),fy*fy*(3-2*fy)
 local a,b=hash01(ix,iy,s),hash01(ix+1,iy,s)
 local c,d=hash01(ix,iy+1,s),hash01(ix+1,iy+1,s)
 return (a+(b-a)*fx)*(1-fy)+(c+(d-c)*fx)*fy
end
local function soft()
 if softTex then return softTex end
 softTex=newTex(64,64,function(x,y)
  local u,v=(x+.5)/32-1,(y+.5)/32-1
  local r=sqrt(u*u+v*v)
  if r>=1 then return 0 end
  local n=.55*noise2(x/9,y/9,3)+.45*noise2(x/4,y/4,5)
  local a=(1-r)^1.7*(.62+.38*n)
  return min(1,a*1.35)
 end)
 return softTex
end
local function solid()
 if not whiteTex then whiteTex=newTex(2,2,function()return 1 end);if whiteTex then whiteTex:setFilter("nearest","nearest")end end
 return whiteTex
end
local function beam()
 if beamTex then return beamTex end
 beamTex=newTex(32,64,function(x,y)
  local u,v=(x+.5)/32,(y+.5)/64
  local along=sin(pi*v)^1.1*(1-.55*v)          -- fades at the crack and floor
  local streak=.62+.38*noise2(x/3.5,0,11)
  local edge=sin(pi*u)^.7
  return along*streak*edge
 end)
 return beamTex
end

-- TEST158: a high-resolution cave floor. The atlas earth is one texel per
-- world unit; this seamless 256px sheet spans two cells (8 texels per unit)
-- with packed earth, damp patches, lit pebbles, hairline cracks and mica
-- glints. Mipmapped so distant floor stays calm instead of shimmering.
local function rh(a,b,s)
 local v=sin(a*12.9898+b*78.233+s*37.719)*43758.5453
 return v-floor(v)
end
local function tnoise(x,y,period,s)
 local ix,iy=floor(x),floor(y);local fx,fy=x-ix,y-iy
 fx,fy=fx*fx*(3-2*fx),fy*fy*(3-2*fy)
 local x0,x1,y0,y1=ix%period,(ix+1)%period,iy%period,(iy+1)%period
 local a,b=rh(x0,y0,s),rh(x1,y0,s)
 local c,d=rh(x0,y1,s),rh(x1,y1,s)
 return (a+(b-a)*fx)*(1-fy)+(c+(d-c)*fx)*fy
end
local EARTH={{.070,.040,.024},{.118,.068,.038},{.176,.108,.058},{.238,.156,.084},{.300,.212,.126}}
-- TEST205: Cerulean Cave stands on cool slate and blue-grey grit, so the
-- floor sits with its blue-grey walls and its crystal light
local SLATE={{.040,.044,.056},{.074,.080,.100},{.118,.126,.150},{.168,.176,.200},{.226,.232,.258}}
local GROUND=EARTH
local function earthAt(v)
 v=max(0,min(.9999,v))*4
 local i=floor(v);local f=v-i
 local a,b=GROUND[i+1],GROUND[i+2]
 return a[1]+(b[1]-a[1])*f,a[2]+(b[2]-a[2])*f,a[3]+(b[3]-a[3])*f
end
local function makeFloorTex(slate)
 GROUND=slate and SLATE or EARTH
 local N=256
 local ok,img=pcall(function()
  local d=love.image.newImageData(N,N)
  local R,G,B={},{},{}
  for y=0,N-1 do for x=0,N-1 do
   local o1=tnoise(x/32,y/32,8,2101)
   local o2=tnoise(x/16,y/16,16,2103)
   local o3=tnoise(x/8,y/8,32,2105)
   local o4=tnoise(x/4,y/4,64,2107)
   local grain=rh(floor(x/2),floor(y/2),2109)
   local v=.30*o1+.24*o2+.20*o3+.14*o4+.12*grain
   local r,g,b=earthAt(.18+v*.78)
   -- damp hollows: darker and a touch cooler
   local damp=max(0,.40-(o1*.6+o2*.4))*1.5
   r,g,b=r*(1-damp*.45),g*(1-damp*.42),b*(1-damp*.30)
   local k=y*N+x;R[k],G[k],B[k]=r,g,b
  end end
  local function put(x,y,r,g,b,a)
   x,y=x%N,y%N;local k=y*N+x;a=a or 1
   R[k]=R[k]+(r-R[k])*a;G[k]=G[k]+(g-G[k])*a;B[k]=B[k]+(b-B[k])*a
  end
  local function darken(x,y,f)x,y=x%N,y%N;local k=y*N+x;R[k],G[k],B[k]=R[k]*f,G[k]*f,B[k]*f end
  -- hairline cracks: wandering dark lines with the odd branch
  for c=1,9 do
   local x,y=rh(c,1,2111)*N,rh(c,2,2113)*N
   local a=rh(c,3,2115)*pi*2
   local len=30+floor(rh(c,4,2117)*60)
   for i=1,len do
    a=a+(rh(c,i,2119)-.5)*.9
    x,y=x+cos(a),y+sin(a)
    darken(floor(x),floor(y),.48);darken(floor(x)+1,floor(y),.80)
    if rh(i,c,2121)<.04 then
     local bx,by,ba=x,y,a+(rh(i,c,2123)<.5 and 1 or -1)*1.1
     for j=1,8+floor(rh(j or 1,i,2125)*10)do ba=ba+(rh(c,j,2127)-.5)*.8;bx,by=bx+cos(ba),by+sin(ba);darken(floor(bx),floor(by),.62)end
    end
   end
  end
  -- pebbles and grit: shaded little stones with contact shadows
  for i=1,300 do
   local cx,cy=rh(i,7,2131)*N,rh(i,9,2133)*N
   local big=rh(i,11,2135)
   local rx=i<=10 and 6+big*5 or 0.9+big*big*big*4.2
   local ry=rx*(.55+rh(i,13,2137)*.45)
   local rot=rh(i,15,2139)*pi
   local tone=(i<=10 and .62 or .58)+rh(i,17,2141)*.42
   local warm=rh(i,19,2143)
   local sr,sg,sb=(.27+warm*.07)*tone,(.21+warm*.04)*tone,(.17-warm*.02)*tone
   if slate then sr,sg,sb=(.20+warm*.05)*tone,(.21+warm*.05)*tone,(.25+warm*.04)*tone end
   local cr,sr2=cos(rot),sin(rot)
   for oy=-floor(ry+3),floor(ry+3)do for ox=-floor(rx+3),floor(rx+3)do
    local px,py=ox+.5,oy+.5
    local u=(px*cr+py*sr2)/rx;local v=(-px*sr2+py*cr)/ry
    local q=u*u+v*v
    -- contact shadow, offset down-right
    local su=((px-1.2)*cr+(py-1.2)*sr2)/rx;local sv=(-(px-1.2)*sr2+(py-1.2)*cr)/ry
    if q>1 and su*su+sv*sv<1.25 then darken(floor(cx+ox),floor(cy+oy),.62)end
    if q<=1 then
     local light=1.10-.45*((px+py)/(rx+ry))-q*.22
     put(floor(cx+ox),floor(cy+oy),min(1,sr*light),min(1,sg*light),min(1,sb*light),q>.75 and .75 or 1)
    end
   end end
  end
  -- mica and quartz specks that catch the torchlight
  for i=1,110 do
   local x,y=floor(rh(i,21,2151)*N),floor(rh(i,23,2153)*N)
   put(x,y,.40,.37,.33,.75)
  end
  -- TEST205: on the slate, crystal grit: tiny cyan and violet chips
  if slate then
   for i=1,50 do
    local x,y=floor(rh(i,25,2155)*N),floor(rh(i,27,2157)*N)
    if rh(i,29,2159)<.5 then put(x,y,.30,.62,.70,.85)else put(x,y,.52,.40,.72,.85)end
   end
  end
  for y=0,N-1 do for x=0,N-1 do local k=y*N+x;d:setPixel(x,y,min(1,R[k]),min(1,G[k]),min(1,B[k]),1)end end
  local made=love.graphics.newImage(d,{mipmaps=true})
  made:setFilter("linear","nearest");pcall(made.setMipmapFilter,made,"linear")
  made:setWrap("repeat","repeat")
  d:release()
  return made
 end)
 return ok and img or nil
end
local function floorTexture(slate)
 if slate then
  if slateTex==nil then slateTex=makeFloorTex(true)or false end
  GROUND=EARTH
  return slateTex or nil
 end
 if floorTex==nil then floorTex=makeFloorTex()or false end
 GROUND=EARTH
 return floorTex or nil
end
-- Puddle body: opaque middle, a soft few-texel shoreline.
local function puddleTexture()
 if puddleTex then return puddleTex end
 puddleTex=newTex(64,64,function(x,y)
  local u,v=(x+.5)/32-1,(y+.5)/32-1
  local r=sqrt(u*u+v*v)
  if r>=1 then return 0 end
  return min(1,(1-r)/.16)
 end)
 return puddleTex
end
-- A thin ring for drip ripples.
local function ringTexture()
 if ringTex then return ringTex end
 ringTex=newTex(64,64,function(x,y)
  local u,v=(x+.5)/32-1,(y+.5)/32-1
  local r=sqrt(u*u+v*v)
  return max(0,1-abs(r-.86)/.10)^1.5
 end)
 return ringTex
end

------------------------------------------------------------------ meshes
local function group()return {verts={},indices={},quads=0}end
local function quad(g,a,b,c,d,shade,uv)
 local s=shade or 1
 uv=uv or {0,0,1,0,1,1,0,1}
 g.verts[#g.verts+1]={a[1],a[2],a[3],uv[1],uv[2],s}
 g.verts[#g.verts+1]={b[1],b[2],b[3],uv[3],uv[4],s}
 g.verts[#g.verts+1]={c[1],c[2],c[3],uv[5],uv[6],s}
 g.verts[#g.verts+1]={d[1],d[2],d[3],uv[7],uv[8],s}
 Voxel3D.pushQuad(g.indices,g.quads)
 g.quads=g.quads+1
end
local function mesh(g)
 if g.quads==0 then return nil end
 return Voxel3D.newMesh(g.verts,g.indices)
end
local function hquad(g,x,y,z,r)
 quad(g,{x-r,y,z-r},{x+r,y,z-r},{x+r,y,z+r},{x-r,y,z+r})
end
local function cross(g,x,y,z,w,h)
 quad(g,{x-w,y-h,z},{x+w,y-h,z},{x+w,y+h,z},{x-w,y+h,z})
 quad(g,{x,y-h,z-w},{x,y-h,z+w},{x,y+h,z+w},{x,y+h,z-w})
end
local function units()
 if not unitQuad then local g=group();hquad(g,0,0,0,1);unitQuad=mesh(g)end
 if not unitCross then local g=group();cross(g,0,0,0,1,1);unitCross=mesh(g)end
 if not coneMesh then
  -- open cone: radius .45 at the crack (y=1), 1 at the floor (y=0)
  local g,n=group(),12
  for i=0,n-1 do
   local a0,a1=i/n*pi*2,(i+1)/n*pi*2
   quad(g,{cos(a0),0,sin(a0)},{cos(a1),0,sin(a1)},{cos(a1)*.45,1,sin(a1)*.45},{cos(a0)*.45,1,sin(a0)*.45},
    1,{0,1,1,1,1,0,0,0})
  end
  coneMesh=mesh(g)
 end
end

-- A leaning hexagonal crystal; facets alternate between the bright and dim
-- groups so the cluster keeps its form while drawn unlit (self-luminous).
local function crystal(bright,dim,x,y,z,ax,ay,az,r,len)
 local n=6
 -- build an orthonormal frame around the axis
 local ux,uy,uz
 if abs(ay)<.9 then ux,uy,uz=-az,0,ax else ux,uy,uz=1,0,0 end
 local ul=sqrt(ux*ux+uy*uy+uz*uz);ux,uy,uz=ux/ul,uy/ul,uz/ul
 local vx,vy,vz=ay*uz-az*uy,az*ux-ax*uz,ax*uy-ay*ux
 local body=len*.78
 local tip={x+ax*len,y+ay*len,z+az*len}
 local ring0,ring1={},{}
 for i=0,n-1 do
  local a=i/n*pi*2
  local cx,cy,cz=(ux*cos(a)+vx*sin(a))*r,(uy*cos(a)+vy*sin(a))*r,(uz*cos(a)+vz*sin(a))*r
  ring0[i]={x+cx-ax*.6,y+cy-ay*.6,z+cz-az*.6}
  ring1[i]={x+cx*.92+ax*body,y+cy*.92+ay*body,z+cz*.92+az*body}
 end
 for i=0,n-1 do
  local j=(i+1)%n
  local g=(i%2==0)and bright or dim
  quad(g,ring0[i],ring0[j],ring1[j],ring1[i])
  quad(bright,ring1[i],ring1[j],tip,tip)
 end
end

------------------------------------------------------------------ build
local function floorAt(map,cx,cy)
 local ok,h=pcall(V.require("VoxelScene").groundAt,map,cx,cy,cx*16,cy*16)
 return (ok and tonumber(h))or 0
end

local function build(map,level)
 local wc,hc=map.widthCells or 0,map.heightCells or 0
 local S=Structures.forMap(map)
 local pal=paletteFor(map)
 local full=level=="full"
 local function walk(cx,cy)
  if cx<0 or cy<0 or cx>=wc or cy>=hc then return false end
  local ok,r=pcall(map.isWalkableCell,map,cx,cy)
  return ok and r or false
 end
 local function water(cx,cy)
  if not map.isWaterCell then return false end
  local ok,r=pcall(map.isWaterCell,map,cx,cy)
  return ok and r or false
 end
 local function wallFace(cx,cy,dx,dz)
  local samples
  if dx>0 then samples={{cx*2+1,cy*2},{cx*2+1,cy*2+1}}
  elseif dx<0 then samples={{cx*2,cy*2},{cx*2,cy*2+1}}
  elseif dz>0 then samples={{cx*2,cy*2+1},{cx*2+1,cy*2+1}}
  else samples={{cx*2,cy*2},{cx*2+1,cy*2}}end
  for _,p in ipairs(samples)do
   local k=keyOf(p[1],p[2])
   local s=S and S.shapeAt and S.shapeAt[k]
   if not s or s.class~="wall" then return false end
  end
  return true
 end

 -- TEST191: Victory Road's loose rocks are low heaps (CaveRubble): no
 -- veins up them, and the veins on its 16-high shelf faces stop short
 local Rubble=V.require("CaveRubble")
 local rubbleMap=Rubble.shelfWalls(map)   -- TEST203: + Cerulean (isLow stays Victory Road)
 local function lowRock(cx,cy)
  return rubbleMap and S and S.tileAt and Rubble.isLow(map,S.tileAt[keyOf(cx*2,cy*2)]) or false
 end
 local slot={pal=pal,mist={},shafts={},clusters={}}
 local bright={group(),group()}
 local dim={group(),group()}
 local pools={group(),group()}
 local halos={group(),group()}

 -- crystal clusters at the wall foot, spaced apart and clear of torches
 local placed={}
 local spacing2=(full and 44 or 64)^2
 local cap=full and 46 or 22
 local function farFromOthers(x,z)
  for _,p in ipairs(placed)do local dx,dz=p[1]-x,p[2]-z;if dx*dx+dz*dz<spacing2 then return false end end
  return true
 end
 for cy=0,hc-1 do for cx=0,wc-1 do
  if #placed<cap and not walk(cx,cy) and not water(cx,cy) then
   for _,d in ipairs({{1,0},{-1,0},{0,1},{0,-1}})do
    local dx,dz=d[1],d[2]
    local ox,oz=cx+dx,cy+dz
    if #placed<cap and walk(ox,oz) and not water(ox,oz) and wallFace(cx,cy,dx,dz)
       and hash01(cx*4+dx+2,cy*4+dz+2,1301)<(full and .24 or .14) then
     local reserved=false
     pcall(function()reserved=CaveSconces.reserved(map,cx,cy)end)
     local t=(hash01(cx,cy,1303)-.5)*9
     local x=cx*16+8+dx*9.4-dz*t
     local z=cy*16+8+dz*9.4+dx*t
     if not reserved and farFromOthers(x,z) then
      placed[#placed+1]={x,z}
      local fy=floorAt(map,ox,oz)
      local ci=hash01(cx,cy,1305)<.62 and 1 or 2
      local seed=cx*131+cy*71
      local count=4+floor(hash01(seed,3,1307)*4)
      local sizeK=1.25+hash01(seed,5,1309)*.70
      -- TEST154: now and then a towering hero formation
      if full and hash01(seed,11,1327)>.82 then sizeK=sizeK*1.7;count=count+3 end
      for k=0,count-1 do
       local a=(k/count)*pi*2+hash01(seed,k,1311)*1.2
       local spread=(.4+hash01(k,seed,1313)*1.6)*sizeK
       local bx=x+cos(a)*spread*1.4+dx*spread*.5
       local bz=z+sin(a)*spread*1.4+dz*spread*.5
       -- lean away from the wall and outward from the cluster
       local lx=dx*.55+cos(a)*.45
       local lz=dz*.55+sin(a)*.45
       local ly=1.15+hash01(seed,k,1317)*.9
       local l=sqrt(lx*lx+ly*ly+lz*lz)
       local len=(2.4+hash01(seed,k,1319)*(k==0 and 6.5 or 4.2))*sizeK
       local r=(.42+hash01(k,seed,1321)*.55)*sizeK*(k==0 and 1.35 or 1)
       crystal(bright[ci],dim[ci],bx,fy,bz,lx/l,ly/l,lz/l,r,len)
      end
      hquad(pools[ci],x+dx*6,fy+.09,z+dz*6,(13+hash01(seed,7,1323)*6)*sizeK)
      cross(halos[ci],x,fy+4.2*sizeK,z,8*sizeK,7*sizeK)
      slot.clusters[#slot.clusters+1]={x=x,z=z,y=fy,ci=ci,phase=hash01(seed,9,1325)*6.28}
     end
    end
   end
  end
 end end

 -- open-floor sites for mist and light shafts
 local open={}
 for cy=1,hc-2 do for cx=1,wc-2 do
  if walk(cx,cy) and not water(cx,cy) then
   local n=0
   for oy=-1,1 do for ox=-1,1 do if walk(cx+ox,cy+oy)then n=n+1 end end end
   if n>=8 then open[#open+1]={cx,cy,hash01(cx,cy,1401)}end
  end
 end end
 table.sort(open,function(a,b)return a[3]<b[3]end)
 local mistCap=full and 20 or 10
 local shaftCap=full and 3 or 1
 local function spaced(list,x,z,d2)
  for _,p in ipairs(list)do local dx,dz=p.x-x,p.z-z;if dx*dx+dz*dz<d2 then return false end end
  return true
 end
 for _,c in ipairs(open)do
  local x,z=c[1]*16+8,c[2]*16+8
  if #slot.shafts<shaftCap and c[3]<.5 and spaced(slot.shafts,x,z,110*110) then
   slot.shafts[#slot.shafts+1]={x=x,z=z,y=floorAt(map,c[1],c[2]),phase=c[3]*20,
    r=10+hash01(c[1],c[2],1403)*5}
  end
  if #slot.mist<mistCap and spaced(slot.mist,x,z,(full and 46 or 60)^2) then
   slot.mist[#slot.mist+1]={x=x,z=z,y=floorAt(map,c[1],c[2]),
    r=22+hash01(c[1],c[2],1405)*20,phase=hash01(c[1],c[2],1407)*6.28,
    spin=(hash01(c[1],c[2],1409)-.5)*.10,drift=3+hash01(c[1],c[2],1411)*5}
  end
 end

 ------------------------------------------------------ TEST154 layers
 local veinB={group(),group()}
 local fungiB,fungiD,fungiP={group(),group()},{group(),group()},{group(),group()}
 local rubble=group()
 slot.spores={}
 -- 1. Glowing crystal veins zig-zagging up the rock faces.
 local veins={}
 for cy=0,hc-1 do for cx=0,wc-1 do
  if #veins<(full and 40 or 16) and not walk(cx,cy) and not water(cx,cy) then
   for _,d in ipairs({{1,0},{-1,0},{0,1},{0,-1}})do
    local dx,dz=d[1],d[2]
    if walk(cx+dx,cy+dz) and wallFace(cx,cy,dx,dz) and hash01(cx*4+dx+2,cy*4+dz+2,1601)<(full and .13 or .06)
       and not lowRock(cx,cy) then
     local fx,fz=cx*16+8+dx*8.25,cy*16+8+dz*8.25
     local ok=true
     for _,v in ipairs(veins)do if (v[1]-fx)^2+(v[2]-fz)^2<34*34 then ok=false end end
     for _,p in ipairs(placed)do if (p[1]-fx)^2+(p[2]-fz)^2<18*18 then ok=false end end
     local reserved=false;pcall(function()reserved=CaveSconces.reserved(map,cx,cy)end)
     if ok and not reserved then
      veins[#veins+1]={fx,fz}
      local seed=cx*97+cy*53+dx*7+dz*3
      local ci=hash01(seed,1,1603)<.6 and 1 or 2
      local ux,uz=-dz,dx                       -- along the face
      local fy=floorAt(map,cx+dx,cy+dz)
      local y,u=fy+2.5+hash01(seed,2,1605)*3,(hash01(seed,3,1607)-.5)*8
      local top=fy+18+hash01(seed,4,1609)*14
      if rubbleMap then top=min(top,(Rubble.wallTop(map)or 16)-2) end   -- TEST191/206: the lower walls
      local prev={fx+ux*u,y,fz+uz*u}
      local k=0
      while y<top and k<12 do
       k=k+1;y=y+2.2+hash01(seed,k,1611)*2.6;u=math.max(-7,math.min(7,u+(hash01(k,seed,1613)-.5)*6.5))
       local p={fx+ux*u,y,fz+uz*u}
       local w=.32+hash01(seed,k,1615)*.38
       -- a thin glowing seam standing just proud of the rock
       quad(veinB[ci],{prev[1]-ux*w,prev[2],prev[3]-uz*w},{prev[1]+ux*w,prev[2],prev[3]+uz*w},{p[1]+ux*w,p[2],p[3]+uz*w},{p[1]-ux*w,p[2],p[3]-uz*w})
       if hash01(seed,k,1617)>.62 then
        crystal(veinB[ci],dim[ci],p[1],p[2],p[3],dx*.8+ux*.2,.45,dz*.8+uz*.2,.22+hash01(k,seed,1619)*.22,1.2+hash01(seed,k,1621)*1.4)
       end
       prev=p
      end
     end
    end
   end
  end
 end end
 -- 2. Glowing mushroom patches at the wall foot, with drifting spores.
 local fungiSites={}
 local fcap=full and 30 or 12
 for cy=0,hc-1 do for cx=0,wc-1 do
  if #fungiSites<fcap and walk(cx,cy) and not water(cx,cy) then
   local wallDir
   for _,d in ipairs({{1,0},{-1,0},{0,1},{0,-1}})do
    if not walk(cx+d[1],cy+d[2]) and not water(cx+d[1],cy+d[2]) then wallDir=d end
   end
   if wallDir and hash01(cx,cy,1631)<(full and .11 or .05) then
    local x=cx*16+8+wallDir[1]*5.2+(hash01(cx,cy,1633)-.5)*6*wallDir[2]
    local z=cy*16+8+wallDir[2]*5.2+(hash01(cx,cy,1635)-.5)*6*wallDir[1]
    local ok=true
    for _,f in ipairs(fungiSites)do if (f.x-x)^2+(f.z-z)^2<50*50 then ok=false end end
    for _,p in ipairs(placed)do if (p[1]-x)^2+(p[2]-z)^2<26*26 then ok=false end end
    local reserved=false;pcall(function()reserved=CaveSconces.reserved(map,cx+wallDir[1],cy+wallDir[2])end)
    if ok and not reserved then
     local fy=floorAt(map,cx,cy);local seed=cx*61+cy*29
     local ci=hash01(seed,1,1637)<.55 and 1 or 2
     fungiSites[#fungiSites+1]={x=x,z=z,y=fy,ci=ci,phase=hash01(seed,2,1639)*6.28}
     local n=5+floor(hash01(seed,3,1641)*5)
     for k=0,n-1 do
      local a=k*2.399+hash01(seed,k,1643);local d=.6+hash01(k,seed,1645)*3.4
      local mx,mz=x+cos(a)*d,z+sin(a)*d
      local h=(.9+hash01(seed,k,1647)*2.6)*(k==0 and 1.5 or 1)
      local cr=(.55+hash01(k,seed,1649)*.9)*(k==0 and 1.6 or 1)
      -- stem: four thin faces; cap: an eight-sided dome with a pale gill ring
      local sw=cr*.22
      quad(fungiD[ci],{mx-sw,fy,mz},{mx+sw,fy,mz},{mx+sw*.8,fy+h,mz},{mx-sw*.8,fy+h,mz})
      quad(fungiD[ci],{mx,fy,mz-sw},{mx,fy,mz+sw},{mx,fy+h,mz+sw*.8},{mx,fy+h,mz-sw*.8})
      local top={mx,fy+h+cr*.62,mz}
      for i=0,7 do local a0,a1=i/8*pi*2,(i+1)/8*pi*2
       local p0={mx+cos(a0)*cr,fy+h,mz+sin(a0)*cr};local p1={mx+cos(a1)*cr,fy+h,mz+sin(a1)*cr}
       local q0={mx+cos(a0)*cr*.62,fy+h+cr*.45,mz+sin(a0)*cr*.62};local q1={mx+cos(a1)*cr*.62,fy+h+cr*.45,mz+sin(a1)*cr*.62}
       quad(fungiB[ci],p0,p1,q1,q0);quad(fungiB[ci],q0,q1,top,top)
       quad(fungiD[ci],p1,p0,{mx,fy+h-.1,mz},{mx,fy+h-.1,mz})
      end
     end
     hquad(fungiP[ci],x,fy+.1,z,9+hash01(seed,5,1651)*4)
     slot.spores[#slot.spores+1]=fungiSites[#fungiSites]
    end
   end
  end
 end end
 -- 3. Rubble and pebbles: lit stone breaking up the flat floor.
 local function rock(x,y,z,r,h,seed)
  local n=5;local ring={}
  for i=0,n-1 do local a=i/n*pi*2+seed;local rr=r*(.8+hash01(i,seed,1661)*.45)
   ring[i]={x+cos(a)*rr,y,z+sin(a)*rr*.85}
  end
  local apex={x+(hash01(seed,1,1663)-.5)*r*.4,y+h,z+(hash01(seed,2,1665)-.5)*r*.4}
  for i=0,n-1 do local j=(i+1)%n
   quad(rubble,ring[i],ring[j],apex,apex,.62+.36*hash01(i,seed,1667))
  end
 end
 local rubbleCap=full and 900 or 300;local rocks=0
 for cy=0,hc-1 do for cx=0,wc-1 do
  if rocks<rubbleCap and walk(cx,cy) and not water(cx,cy) then
   local fy=floorAt(map,cx,cy)
   local nearWall=false
   for _,d in ipairs({{1,0},{-1,0},{0,1},{0,-1}})do
    if not walk(cx+d[1],cy+d[2]) and not water(cx+d[1],cy+d[2]) then
     nearWall=true
     -- scree along the wall foot
     if hash01(cx*4+d[1]+2,cy*4+d[2]+2,1671)<(full and .55 or .25) then
      for k=0,2 do local t=(hash01(cx,cy,1673+k)-.5)*12
       local x=cx*16+8+d[1]*6.2-d[2]*t;local z=cy*16+8+d[2]*6.2+d[1]*t
       rock(x,fy,z,.8+hash01(k,cx,1675)*1.5,.6+hash01(cy,k,1677)*1.4,cx*3+cy*5+k);rocks=rocks+1
      end
     end
    end
   end
   if not nearWall and hash01(cx,cy,1681)<(full and .16 or .06) then
    for k=0,1 do
     rock(cx*16+3+hash01(cx,k,1683)*10,fy,cy*16+3+hash01(k,cy,1685)*10,.45+hash01(cx,cy,1687+k)*.6,.3+hash01(cy,cx,1689+k)*.5,cx+cy*7+k)
     rocks=rocks+1
    end
   end
  end
 end end
 -- 4. Glowworms on the cave roof, chunked so a battle can clear its arena.
 slot.worms={}
 if full or level=="subtle" then
  local chunks={}
  local density=full and .62 or .30
  for cy=0,hc-1 do for cx=0,wc-1 do
   if walk(cx,cy) or water(cx,cy) then
    local bk=floor(cx/4)..":"..floor(cy/4)
    local c=chunks[bk]
    if not c then c={a=group(),b=group(),threads=group(),x=(floor(cx/4)*4+2)*16,z=(floor(cy/4)*4+2)*16};chunks[bk]=c end
    for k=0,2 do
     if hash01(cx*3+k,cy,1701)<density then
      local x=cx*16+2+hash01(cx,cy*3+k,1703)*12;local z=cy*16+2+hash01(cx*3+k,cy,1705)*12
      local y=61.6-hash01(k,cx+cy,1707)*1.8
      local r=.28+hash01(cy,k,1709)*.34
      local g2=hash01(cx,cy,1711+k)<.5 and c.a or c.b
      quad(g2,{x-r,y,z-r},{x-r,y,z+r},{x+r,y,z+r},{x+r,y,z-r})
      -- a few hang silk threads tipped with a bright bead
      if hash01(cx+k,cy,1713)<.16 then
       local L=3+hash01(cy+k,cx,1715)*7
       quad(c.threads,{x-.05,y,z},{x+.05,y,z},{x+.05,y-L,z},{x-.05,y-L,z})
       local br=.32
       quad(g2,{x-br,y-L-br,z},{x+br,y-L-br,z},{x+br,y-L+br,z},{x-br,y-L+br,z})
       quad(g2,{x,y-L-br,z-br},{x,y-L-br,z+br},{x,y-L+br,z+br},{x,y-L+br,z-br})
      end
     end
    end
   end
  end end
  for _,c in pairs(chunks)do
   local w={x=c.x,z=c.z,a=mesh(c.a),b=mesh(c.b),threads=mesh(c.threads)}
   if w.a or w.b then slot.worms[#slot.worms+1]=w end
  end
 end
 slot.veinB={mesh(veinB[1]),mesh(veinB[2])}
 slot.fungiB={mesh(fungiB[1]),mesh(fungiB[2])}
 slot.fungiD={mesh(fungiD[1]),mesh(fungiD[2])}
 slot.fungiP={mesh(fungiP[1]),mesh(fungiP[2])}
 slot.rubble=mesh(rubble)

 slot.bright={mesh(bright[1]),mesh(bright[2])}
 slot.dim={mesh(dim[1]),mesh(dim[2])}
 slot.pools={mesh(pools[1]),mesh(pools[2])}
 slot.halos={mesh(halos[1]),mesh(halos[2])}
 ------------------------------------------------------ TEST158 floor
 -- High-res earth over every plain floor cell, plus reflective puddles.
 local okShape,shapes=pcall(function()return V.require("TileShape").forMap(map)end)
 if not okShape then shapes=nil end
 local warpCells={}
 for _,w in ipairs((map.def and map.def.warps)or map.warps or {})do
  if w.x and w.y then warpCells[keyOf(w.x,w.y)]=true end
 end
 local okD,depthsMap=pcall(function()return V.require("CeruleanDepths").applies(map)end)
 depthsMap=okD and depthsMap or false
 slot.slate=depthsMap
 local function plainFloor(cx,cy)
  if not walk(cx,cy) or water(cx,cy) or warpCells[keyOf(cx,cy)] then return false end
  if not(shapes and map.tileAt)then return true end
  local shelves,grounds=0,0
  for oy=0,1 do for ox=0,1 do
   local okT,tile=pcall(map.tileAt,map,cx*2+ox,cy*2+oy)
   if not okT then return false end
   local sh=shapes[tile]
   -- TEST205: Cerulean Cave's lit shelves ($05 and its shading row $29,
   -- 6 up) wear the floor too; elsewhere only the ground plane does
   local shelf=depthsMap and sh and sh.class=="ledge" and(tile==5 or tile==41)
   if not shelf and(not sh or sh.class~="ground" or tile==20 or tile==34 or tile==47)then return false end
   if shelf then shelves=shelves+1 else grounds=grounds+1 end
  end end
  -- a cell half shelf and half floor stands at two heights: leave it
  return shelves==0 or grounds==0
 end
 local fl=group();local floorY={}
 for cy=0,hc-1 do for cx=0,wc-1 do
  if plainFloor(cx,cy)then
   local fy=floorAt(map,cx,cy);floorY[keyOf(cx,cy)]=fy
   local x0,z0,x1,z1=cx*16,cy*16,cx*16+16,cy*16+16
   local y=fy+.14
   local function sh(x,z)return .86+.20*noise2(x/72,z/72,2231)+.06*noise2(x/23,z/23,2233)end
   local q0={x0,y,z0,x0/32,z0/32,sh(x0,z0)};local q1={x1,y,z0,x1/32,z0/32,sh(x1,z0)}
   local q2={x1,y,z1,x1/32,z1/32,sh(x1,z1)};local q3={x0,y,z1,x0/32,z1/32,sh(x0,z1)}
   for _,v in ipairs({q0,q1,q2,q3})do fl.verts[#fl.verts+1]=v end
   Voxel3D.pushQuad(fl.indices,fl.quads);fl.quads=fl.quads+1
  end
 end end
 slot.floor=mesh(fl)
 -- Lights the puddles can mirror.
 local lights={}
 for _,c in ipairs(slot.clusters)do
  local col=pal.crystals[c.ci];lights[#lights+1]={x=c.x,z=c.z,y=c.y+6,col=col,size=4.2,k=1}
 end
 local okS,src=pcall(CaveSconces.sources,map)
 for _,t in ipairs(okS and src or {})do
  local tcx,tcz=floor((t.x+(t.dx or 0)*8)/16),floor((t.z+(t.dz or 0)*8)/16)
  lights[#lights+1]={x=t.x,z=t.z,y=floorAt(map,tcx,tcz)+19.15,col={1,.60,.26},size=3.2,k=1.15,flame=true}
 end
 for _,sft in ipairs(slot.shafts)do
  lights[#lights+1]={x=sft.x,z=sft.z,y=sft.y+38,col=pal.beam,size=sft.r*.9,k=.55}
 end
 for _,f in ipairs(slot.spores or {})do
  local col=pal.fungi and pal.fungi[f.ci] or {.5,1,.9}
  lights[#lights+1]={x=f.x,z=f.z,y=f.y+2.2,col=col,size=2.4,k=.8}
 end
 slot.lights=lights
 -- Puddle sites: open plain floor, flat across their footprint, favouring
 -- spots that have something glowing to reflect.
 local cands={}
 -- First choice: just south of a light, where the default north-facing
 -- camera sees that light mirrored (offset ~1.5x the light's height).
 for li,l in ipairs(lights)do
  local h=max(2,l.y-floorAt(map,floor(l.x/16),floor(l.z/16)))
  local off=min(70,h*1.5+4)
  local x,z=l.x+(hash01(li,7,2241)-.5)*6,l.z+off
  local cx,cy=floor(x/16),floor(z/16)
  local fy=floorY[keyOf(cx,cy)]
  if fy then cands[#cands+1]={x,z,fy,-1+hash01(li,9,2243)*.3,cx,cy}end
 end
 for cy=1,hc-2 do for cx=1,wc-2 do
  local fy=floorY[keyOf(cx,cy)]
  if fy then
   local n=0
   for oy=-1,1 do for ox=-1,1 do if floorY[keyOf(cx+ox,cy+oy)]==fy then n=n+1 end end end
   if n>=6 then
    local x=cx*16+8+(hash01(cx,cy,2203)-.5)*6
    local z=cy*16+8+(hash01(cy,cx,2205)-.5)*6
    cands[#cands+1]={x,z,fy,hash01(cx,cy,2201),cx,cy}
   end
  end
 end end
 table.sort(cands,function(a,b)return a[4]<b[4]end)
 local pcap=full and 30 or 12
 slot.puddles={}
 local pb,prim,pstar=group(),group(),group()
 for _,c in ipairs(cands)do
  if #slot.puddles>=pcap then break end
  local x,z,fy,cx,cy=c[1],c[2],c[3],c[5],c[6]
  local big=hash01(cx,cy,2207)
  local rx=6.5+big*8.5;local rz=rx*(.50+hash01(cy,cx,2209)*.35)
  -- light-side puddles lie across the view so the reflection has room
  if c[4]<0 then rx=max(rx,9);rz=max(rz,rx*.62)end
  local rot=hash01(cx,cy,2211)*pi
  local ok=true
  for _,p in ipairs(slot.puddles)do local dx,dz=p.x-x,p.z-z;if dx*dx+dz*dz<(p.rx+rx+38)^2 then ok=false;break end end
  if ok then
   -- every cell under the footprint must be the same flat plain floor;
   -- shrink a little before giving up
   local fit=false
   for _,k in ipairs({1,.8,.62})do
    if not fit then
     local good=true
     for oz=-1,1 do for ox=-1,1 do
      local sx,sz=x+ox*rx*k*1.15,z+oz*rz*k*1.25
      if floorY[keyOf(floor(sx/16),floor(sz/16))]~=fy then good=false end
     end end
     if good then fit=true;rx,rz=rx*k,rz*k end
    end
   end
   ok=fit and rx>=4
  end
  if ok then
   local cr,sr=cos(rot),sin(rot)
   local y=fy+.22
   local sides=18
   local function rim(i,scale)
    local a=i/sides*pi*2
    local w=.84+hash01(cx*sides+i%sides,cy,2213)*.30
    local u,v=cos(a)*rx*w*scale,sin(a)*rz*w*scale
    return x+u*cr-v*sr,z+u*sr+v*cr,cos(a)*w,sin(a)*w
   end
   for i=0,sides-1 do
    local ax,az,au,av=rim(i,1);local bx,bz,bu,bv=rim(i+1,1)
    quad(pb,{x,y,z},{ax,y,az},{bx,y,bz},{x,y,z},1,{.5,.5,.5+au*.5,.5+av*.5,.5+bu*.5,.5+bv*.5,.5,.5})
    local ax2,az2,au2,av2=rim(i,1.45);local bx2,bz2,bu2,bv2=rim(i+1,1.45)
    local y2=fy+.18
    quad(prim,{x,y2,z},{ax2,y2,az2},{bx2,y2,bz2},{x,y2,z},1,{.5,.5,.5+au2*.36,.5+av2*.36,.5+bu2*.36,.5+bv2*.36,.5,.5})
   end
   -- mirrored glowworm sky: tiny specks in the water
   for k=1,floor(rx*rz/7)do
    local a=hash01(cx*31+k,cy,2215)*pi*2;local r=sqrt(hash01(k,cx+cy*7,2217))*.78
    local u,v=cos(a)*rx*r,sin(a)*rz*r
    local px,pz=x+u*cr-v*sr,z+u*sr+v*cr
    local q=.16+hash01(k,cy,2219)*.18
    quad(pstar,{px-q,y+.05,pz-q},{px+q,y+.05,pz-q},{px+q,y+.05,pz+q},{px-q,y+.05,pz+q})
   end
   local near={}
   for li,l in ipairs(lights)do
    local dx,dz=l.x-x,l.z-z;local d2=dx*dx+dz*dz
    if d2<150*150 then near[#near+1]={li,d2}end
   end
   table.sort(near,function(a,b)return a[2]<b[2]end)
   local list={};for i=1,min(7,#near)do list[i]=near[i][1]end
   -- the glow of nearby lights tints the whole sheet of water
   local tr,tg,tb=0,0,0
   for _,li in ipairs(list)do local l=lights[li]
    local d=sqrt((l.x-x)^2+(l.z-z)^2);local f=max(0,1-d/130)^2*l.k
    tr,tg,tb=tr+l.col[1]*f,tg+l.col[2]*f,tb+l.col[3]*f
   end
   local tm=max(tr,tg,tb,1e-6);if tm>1 then tr,tg,tb=tr/tm,tg/tm,tb/tm end
   slot.puddles[#slot.puddles+1]={x=x,z=z,y=y,rx=rx,rz=rz,cr=cr,sr=sr,lights=list,rot=rot,tint={tr,tg,tb},
    phase=hash01(cx,cy,2221)*9,every=4.5+hash01(cy,cx,2223)*5}
  end
 end
 slot.puddleBody=mesh(pb);slot.puddleRim=mesh(prim);slot.puddleStars=mesh(pstar)

 slot.level=level
 return slot
end

local function release(slot)
 if not slot then return end
 for _,set in ipairs({slot.bright,slot.dim,slot.pools,slot.halos,slot.veinB,slot.fungiB,slot.fungiD,slot.fungiP,{slot.rubble}})do
  for _,m in pairs(set or {})do if m and m.release then pcall(m.release,m)end end
 end
 for _,m in ipairs({slot.floor,slot.puddleBody,slot.puddleRim,slot.puddleStars})do if m and m.release then pcall(m.release,m)end end
 for _,w in ipairs(slot.worms or {})do
  for _,m in ipairs({w.a,w.b,w.threads})do if m and m.release then pcall(m.release,m)end end
 end
end

------------------------------------------------------------------ draw
local function drawMap(map,focusX,focusZ,battle)
 local level=detail()
 if level=="off" or not isCave(map)then return false end
 local slot=cache[map]
 if slot and slot.level~=level then release(slot);slot=nil end
 if not slot then slot=build(map,level);cache[map]=slot end
 units()
 local st,bt,wt=soft(),beam(),solid()
 if not(st and bt and wt)then return false end
 local t=0;pcall(function()t=love.timer.getTime()end)
 local full=level=="full"
 local pal=slot.pal
 local g=love.graphics

 -- 1. self-lit crystals (unlit, opaque, depth-writing)
 local pushed=g and g.push and pcall(g.push,"all")
 pcall(function()
  g.setDepthMode("lequal",true)
  g.setBlendMode("alpha")
  Voxel3D.lighting(false)
  -- TEST154: lit scree and pebbles first (normal cave lighting)
  if slot.rubble then
   Voxel3D.lighting(true)
   local r=pal.rock or {.30,.27,.25}
   g.setColor(r[1],r[2],r[3],1);Voxel3D.draw(slot.rubble,wt)
   Voxel3D.lighting(false)
  end
  for ci=1,2 do
   local c=pal.crystals[ci]
   local pulse=.80+.20*sin(t*.6+ci*2.3)
   if slot.veinB and slot.veinB[ci] then
    g.setColor(min(1,(c[1]*.75+.25)*pulse),min(1,(c[2]*.75+.25)*pulse),min(1,(c[3]*.75+.25)*pulse),1)
    Voxel3D.draw(slot.veinB[ci],wt)
   end
   local f=pal.fungi and pal.fungi[ci]
   if f then
    local fp=.86+.14*sin(t*1.3+ci)
    if slot.fungiD and slot.fungiD[ci] then g.setColor(f[1]*.36+.10,f[2]*.36+.10,f[3]*.36+.10,1);Voxel3D.draw(slot.fungiD[ci],wt)end
    if slot.fungiB and slot.fungiB[ci] then g.setColor(min(1,f[1]*fp),min(1,f[2]*fp),min(1,f[3]*fp),1);Voxel3D.draw(slot.fungiB[ci],wt)end
   end
  end
  for ci=1,2 do
   local c=pal.crystals[ci]
   local pulse=.88+.12*sin(t*.9+ci*1.7)
   if slot.dim[ci] then g.setColor(c[1]*.42*pulse,c[2]*.42*pulse,c[3]*.42*pulse,1);Voxel3D.draw(slot.dim[ci],wt)end
   if slot.bright[ci] then
    g.setColor(min(1,(c[1]*.80+.20)*pulse),min(1,(c[2]*.80+.20)*pulse),min(1,(c[3]*.80+.20)*pulse),1)
    Voxel3D.draw(slot.bright[ci],wt)
   end
  end
  Voxel3D.lighting(true)
 end)
 pcall(Voxel3D.lighting,true)
 if pushed then pcall(g.pop)end

 -- 2. additive light: crystal floor pools, halos, light shafts, dust
 pcall(Voxel3D.withEffect,"add",function()
  for ci=1,2 do
   local c=pal.crystals[ci]
   local pulse=.80+.20*sin(t*.9+ci*1.7)
   if slot.pools[ci] then g.setColor(c[1],c[2],c[3],(full and .44 or .32)*pulse);Voxel3D.draw(slot.pools[ci],st)end
   if slot.halos[ci] then g.setColor(c[1],c[2],c[3],(full and .20 or .14)*pulse);Voxel3D.draw(slot.halos[ci],st)end
  end
  -- TEST154: fungus light on the floor, glowworm sky, rising spores
  for ci=1,2 do
   local f=pal.fungi and pal.fungi[ci]
   if f and slot.fungiP and slot.fungiP[ci] then
    g.setColor(f[1],f[2],f[3],(full and .34 or .24)*(.85+.15*sin(t*1.3+ci)))
    Voxel3D.draw(slot.fungiP[ci],st)
   end
  end
  local roofShown=battle or VoxelState.isFreeCam()
  if roofShown and slot.worms then
   local w=pal.worm or {.46,.94,1}
   for _,c in ipairs(slot.worms)do
    local dx,dz=c.x-focusX,c.z-focusZ
    if not battle or dx*dx+dz*dz>80*80 then
     if c.a then g.setColor(w[1],w[2],w[3],.62+.30*sin(t*.8+c.x*.01));Voxel3D.draw(c.a,st)end
     if c.b then g.setColor(w[1],w[2],w[3],.62+.30*sin(t*.8+c.z*.01+2.1));Voxel3D.draw(c.b,st)end
     if c.threads then g.setColor(w[1],w[2],w[3],.14);Voxel3D.draw(c.threads,wt)end
    end
   end
  end
  for i,f in ipairs(slot.spores or {})do
   if abs(f.x-focusX)<200 and abs(f.z-focusZ)<200 then
    local col=pal.fungi and pal.fungi[f.ci] or {.5,1,.9}
    local motes=full and 6 or 3
    for k=0,motes-1 do
     local life=(t*.07+k/motes+f.phase)%1
     local a=k*2.4+f.phase+t*.2
     local mx=f.x+cos(a)*(1.5+life*4.5);local mz=f.z+sin(a)*(1.5+life*4.5)
     g.setColor(col[1],col[2],col[3],.65*sin(life*pi))
     Voxel3D.draw(unitCross,st,Mat4.mul(Mat4.translate(mx,f.y+1+life*16,mz),Mat4.scale(.42,.42,.42)))
    end
   end
  end
  local b=pal.beam
  for i,s in ipairs(slot.shafts)do
   if abs(s.x-focusX)<260 and abs(s.z-focusZ)<260 then
    local flick=.85+.10*sin(t*.7+s.phase)+.05*sin(t*2.3+s.phase*1.7)
    local h=78
    g.setColor(b[1],b[2],b[3],(battle and .08 or .12)*flick)
    Voxel3D.draw(coneMesh,bt,Mat4.mul(Mat4.translate(s.x,s.y,s.z),Mat4.scale(s.r,h,s.r)))
    g.setColor(b[1],b[2],b[3],(battle and .08 or .11)*flick)
    Voxel3D.draw(coneMesh,bt,Mat4.mul(Mat4.translate(s.x,s.y,s.z),Mat4.scale(s.r*.62,h*.96,s.r*.62)))
    g.setColor(b[1],b[2],b[3],.26*flick)
    Voxel3D.draw(unitQuad,st,Mat4.mul(Mat4.translate(s.x,s.y+.12,s.z),Mat4.scale(s.r*1.45,1,s.r*1.45)))
    -- dust drifting down through the beam
    local motes=full and 9 or 4
    for k=0,motes-1 do
     local life=(t*.045+k/motes+s.phase)%1
     local y=s.y+h*(1-life)*.92
     local spread=s.r*(.45+.55*(1-life))*.8
     local a=k*2.4+t*.12
     local mx,mz=s.x+cos(a)*spread*hash01(k,i,1501),s.z+sin(a)*spread*hash01(i,k,1503)
     g.setColor(b[1],b[2],b[3],.55*sin(life*pi))
     Voxel3D.draw(unitCross,st,Mat4.mul(Mat4.translate(mx,y,mz),Mat4.scale(.55,.55,.55)))
    end
   end
  end
 end)

 -- 3. rolling ground mist (alpha), two layers turning against each other
 pcall(Voxel3D.withEffect,"alpha",function()
  local m=pal.mist
  local drawn,cap=0,full and 20 or 10
  for _,p in ipairs(slot.mist)do
   if drawn>=cap then break end
   if abs(p.x-focusX)<230 and abs(p.z-focusZ)<230 then
    drawn=drawn+1
    local breathe=.5+.5*sin(t*.33+p.phase)
    local ox=sin(t*.05+p.phase)*p.drift
    local oz=cos(t*.04+p.phase*1.3)*p.drift
    local a=(battle and .55 or 1)
    g.setColor(m[1],m[2],m[3],(.055+breathe*.03)*a)
    Voxel3D.draw(unitQuad,st,Mat4.mul(Mat4.translate(p.x+ox,p.y+1.3,p.z+oz),
     Mat4.mul(Mat4.rotateY(t*p.spin+p.phase),Mat4.scale(p.r,1,p.r))))
    if full then
     g.setColor(m[1],m[2],m[3],(.035+(1-breathe)*.025)*a)
     Voxel3D.draw(unitQuad,st,Mat4.mul(Mat4.translate(p.x-oz*.8,p.y+3.6,p.z+ox*.8),
      Mat4.mul(Mat4.rotateY(-t*p.spin*1.4+p.phase*2),Mat4.scale(p.r*.82,1,p.r*.82))))
    end
   end
  end
 end)
 return true
end

------------------------------------------------------------------ TEST158
-- Floor pass, drawn straight after the terrain (before shadows, decals and
-- characters) so everything else still lands on top of it.
local function drawFloorMap(map,focusX,focusZ,battle)
 local level=detail()
 if level=="off" or not isCave(map)then return false end
 local slot=cache[map]
 if slot and slot.level~=level then release(slot);slot=nil end
 if not slot then slot=build(map,level);cache[map]=slot end
 units()
 local ft,pt,st,rt,wt=floorTexture(slot.slate),puddleTexture(),soft(),ringTexture(),solid()
 local g=love.graphics
 local t=0;pcall(function()t=love.timer.getTime()end)
 local pal=slot.pal
 local pushed=g and g.push and pcall(g.push,"all")
 pcall(function()
  Voxel3D.glass(false)
  g.setDepthMode("lequal",false)
  g.setBlendMode("alpha")
  if slot.floor and ft then
   Voxel3D.lighting(true)
   g.setColor(1,1,1,1);Voxel3D.draw(slot.floor,ft)
  end
 end)
 pcall(Voxel3D.lighting,true)
 if pushed then pcall(g.pop)end
 pcall(Voxel3D.glass,true)
 -- wet soil around each puddle, then the dark mirror itself
 pcall(Voxel3D.withEffect,"alpha",function()
  if slot.puddleRim and st then g.setColor(0,0,0,.42);Voxel3D.draw(slot.puddleRim,st)end
  if slot.puddleBody and pt then
   local f=pal.fog
   g.setColor(f[1]*.45,f[2]*.55,f[3]*.70,.66);Voxel3D.draw(slot.puddleBody,pt)
  end
 end)
 local eye=Voxel3D.eye
 pcall(Voxel3D.withEffect,"add",function()
  local roofShown=battle or VoxelState.isFreeCam()
  -- the glowworm sky, mirrored
  if roofShown and slot.puddleStars and st then
   local w=pal.worm or {.46,.94,1}
   g.setColor(w[1],w[2],w[3],.55+.25*sin(t*.8))
   Voxel3D.draw(slot.puddleStars,st)
  end
  if not(eye and st)then return end
  local ex,ey,ez=eye[1],eye[2],eye[3]
  local lights=slot.lights or {}
  for _,p in ipairs(slot.puddles or {})do
   local pdx,pdz=p.x-focusX,p.z-focusZ
   if pdx*pdx+pdz*pdz<240*240 and ey>p.y+1 then
    -- a drip lands now and then; its ripple shakes the reflections
    local cyc=(t+p.phase)%p.every
    local life=cyc/2.4
    local shake=0
    if life<1 then
     shake=(1-life)*.35
     local r=(.2+life*.9)
     if rt then
      g.setColor(.55,.70,.78,.30*(1-life))
      Voxel3D.draw(unitQuad,rt,Mat4.mul(Mat4.translate(p.x,p.y+.08,p.z),Mat4.scale(p.rx*.55*r,1,p.rz*.55*r+p.rx*.15*r)))
     end
    end
    -- coloured glow of the chamber on the water, and a cool sheen
    local tn=p.tint
    if tn then
     g.setColor(tn[1],tn[2],tn[3],.30)
     Voxel3D.draw(unitQuad,st,Mat4.mul(Mat4.translate(p.x,p.y+.06,p.z),Mat4.mul(Mat4.rotateY(-p.rot),Mat4.scale(p.rx*.95,1,p.rz*.95))))
    end
    local mc=pal.mist
    g.setColor(mc[1],mc[2],mc[3],.07+.03*sin(t*.7+p.phase))
    Voxel3D.draw(unitQuad,st,Mat4.mul(Mat4.translate(p.x,p.y+.07,p.z),Mat4.mul(Mat4.rotateY(-p.rot),Mat4.scale(p.rx*.8,1,p.rz*.8))))
    for _,li in ipairs(p.lights)do
     local l=lights[li]
     -- mirror the light through the water plane; where the eye ray to the
     -- mirrored light crosses the plane is where its reflection sits
     local my=2*p.y-l.y
     local k=(ey-p.y)/(ey-my)
     local rx_,rz_=ex+(l.x-ex)*k,ez+(l.z-ez)*k
     local dx,dz=rx_-p.x,rz_-p.z
     local u=(dx*p.cr+dz*p.sr)/p.rx;local v=(-dx*p.sr+dz*p.cr)/p.rz
     local q=u*u+v*v
     -- a wet surface smears a reflection along the line of sight, so test
     -- the whole streak through the mirror point against the puddle
     local vx,vz=rx_-ex,rz_-ez;local vl=sqrt(vx*vx+vz*vz);if vl<.001 then vl=.001 end
     vx,vz=vx/vl,vz/vl
     local du=(vx*p.cr+vz*p.sr)/p.rx;local dv=(-vx*p.sr+vz*p.cr)/p.rz
     local A=du*du+dv*dv;local B=2*(u*du+v*dv);local C=q-.86
     local disc=B*B-4*A*C
     if disc>0 and A>0 then
      do
       local sq=sqrt(disc);local s0,s1=(-B-sq)/(2*A),(-B+sq)/(2*A)
       local want=l.size*(2.2+min(3,(l.y-p.y)/9))
       local a0,a1=max(s0,-want*.6),min(s1,want*1.4)
       if a1>a0+.3 then
        local mid=(a0+a1)*.5;local half=(a1-a0)*.5
        local fade=max(0,1-max(0,a0>0 and a0 or(a1<0 and -a1 or 0))/want)
        local cx_,cz_=rx_+vx*mid,rz_+vz*mid
        local flick=l.flame and(.80+.12*sin(t*9.1+li)+.08*sin(t*15.7+li*2))or(.88+.12*sin(t*.9+li))
        local wob=1+shake*sin(t*22+li)
        local wdt=l.size*.58*wob
        local c=l.col;local a=fade*l.k*flick
        local yaw=math.atan2(-vz,vx)
        g.setColor(c[1],c[2],c[3],.95*a)
        Voxel3D.draw(unitQuad,st,Mat4.mul(Mat4.translate(cx_,p.y+.10,cz_),Mat4.mul(Mat4.rotateY(yaw),Mat4.scale(half,1,wdt))))
        if q<.70 then
         g.setColor(min(1,c[1]*.5+.5),min(1,c[2]*.5+.5),min(1,c[3]*.5+.5),.85*a*(1-q/.70))
         Voxel3D.draw(unitQuad,st,Mat4.mul(Mat4.translate(rx_,p.y+.12,rz_),Mat4.mul(Mat4.rotateY(yaw),Mat4.scale(min(half,l.size*.6),1,wdt*.45))))
        end
       end
      end
     end
    end
   end
  end
 end)
 return true
end
function M.drawFloor(state)
 local map,p=state and state.map,state and state.player
 local drew=false
 if map then drew=drawFloorMap(map,(p and p.px or 0)+8,(p and p.py or 0)+8,false)end
 -- TEST205: Cerulean Cave's water colours and its floor shading, on top
 -- of the floor (and the water's cave colours are cleared everywhere else)
 pcall(function()V.require("CeruleanDepths").drawFloor(state)end)
 return drew
end
function M.drawFloorBattle(map,arena)
 local mid=arena and arena.mid
 return drawFloorMap(map,(mid and mid[1])or 0,(mid and mid[2])or 0,true)
end
M.paletteFor=paletteFor

function M.draw(state)
 local map,p=state and state.map,state and state.player
 if not map then return false end
 -- TEST158: grand cave entrances on the overworld side
 if isCave(map)then pcall(V.require("CaveRubble").draw,state)end
 -- TEST204: Cerulean Cave's crowns, shards, water light and the sanctum
 if isCave(map)then pcall(function()V.require("CeruleanDepths").draw(state)end)end
 if not isCave(map)then pcall(V.require("CaveMouths").draw,state);pcall(function()V.require("NuggetBridge").draw(state)end);pcall(V.require("LeagueRoad").draw,state);pcall(function()V.require("LeagueRoomFx").drawInterior(state)end);pcall(function()V.require("DockLights").draw(state)end);return false end
 return drawMap(map,(p and p.px or 0)+8,(p and p.py or 0)+8,false)
end
function M.drawBattle(map,arena)
 local mid=arena and arena.mid
 -- TEST172: the League's rooms keep their fire, snow and light in battle
 if not isCave(map)then pcall(function()V.require("LeagueRoomFx").drawBattle(map,arena)end);pcall(function()V.require("LeagueRoomFx").drawInteriorBattle(map,arena)end)end
 if isCave(map)then pcall(function()V.require("CeruleanDepths").drawBattle(map,arena)end)end
 return drawMap(map,(mid and mid[1])or 0,(mid and mid[2])or 0,true)
end
function M.invalidate()
 for _,slot in pairs(cache)do release(slot)end
 cache=setmetatable({},{__mode='k'})
 for _,m in ipairs({unitQuad,unitCross,coneMesh,softTex,beamTex,whiteTex,floorTex or nil,slateTex or nil,puddleTex,ringTex})do
  if m and m.release then pcall(m.release,m)end
 end
 unitQuad,unitCross,coneMesh,softTex,beamTex,whiteTex=nil,nil,nil,nil,nil,nil
 floorTex,puddleTex,ringTex,slateTex=nil,nil,nil,nil
end
Assets.register(M.invalidate)
return M
