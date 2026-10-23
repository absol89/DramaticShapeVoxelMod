-- TEST176: every route in the colours of its own country.
--
-- Until now one paving (TEST86's light cobble) ran down every route in
-- Kanto, and every lawn was the same green. Here each route's PATH is built
-- from its own ground -- a country lane, a forest track, mountain scree,
-- red earth, suburban flagstones, crushed slate, beach sand, a boardwalk,
-- a prairie track, crushed shell -- with turf creeping in over its edges,
-- stones trodden into it and the odd tuft; and each route's GRASS (the
-- lawn and the tall grass) is re-coloured for its country, with that
-- country's wild flowers in the lawns.
--
-- The path is shader materials (ReferenceMaterials rt*, world-space, no
-- atlas). The grass keeps its atlas texel and art: the vertex carries a
-- tint id (tg*) and the shader recolours the texel (Voxel3D routeTint).
-- Presentation only: the path tiles stay where the map has them; nothing
-- here touches collision, warps, encounters or the tall grass's cells.
-- Bespoke roads keep their own builders: Route 11's trail, Route 17's
-- cycling road, Route 23's League road and every town.
local V=...
local C=V and V.require('SurfaceCraft') or assert(loadfile('lib/SurfaceCraft.lua'))()
local M={REVISION='route-looks-176'}
local pi,cos,sin,floor,min,max,sqrt=math.pi,math.cos,math.sin,math.floor,math.min,math.max,math.sqrt
local hash,field=C.hash,C.field

-- path: how the walking surface is built; grass: the lawn's country
M.looks={
 ROUTE_1 ={path='lane',    grass='Meadow'},   -- Pallet's country lane
 ROUTE_2 ={path='loam',    grass='Lush'},     -- beside Viridian Forest
 ROUTE_3 ={path='scree',   grass='Dry'},      -- the stony climb to Mt. Moon
 ROUTE_4 ={path='redearth',grass='Dry'},      -- down off the mountain
 ROUTE_5 ={path='flag',    grass='Park'},     -- Saffron's suburbs
 ROUTE_6 ={path='flag',    grass='Park'},
 ROUTE_7 ={path='flag',    grass='Park'},
 ROUTE_8 ={path='flag',    grass='Park'},
 ROUTE_9 ={path='slate',   grass='Highland'}, -- the highland to Rock Tunnel
 ROUTE_10={path='slate'},                     -- (its approved bright lawn stays)
 ROUTE_12={path='board',   grass='Coast'},    -- the boardwalk by the sea
 ROUTE_13={path='sand',    grass='Coast'},
 ROUTE_14={path='prairie', grass='Prairie'},
 ROUTE_15={path='prairie', grass='Prairie'},
 ROUTE_16={path='flag',    grass='Park'},     -- Celadon's west side
 ROUTE_18={path='sand',    grass='Coast'},
 ROUTE_19={path='sand',    grass='Coast'},    -- Fuchsia's beach
 ROUTE_20={path='sand',    grass='Coast'},
 ROUTE_21={path='sand',    grass='Coast'},
 ROUTE_22={path='wild',    grass='Wild'},     -- the overgrown way west
 ROUTE_24={path='shell',   grass='Cape'},     -- Nugget Bridge's cape
 ROUTE_25={path='shell',   grass='Cape'},     -- the cape to Bill's
}

local function setting()
 local ok,CV=pcall(function()return V.require('CommunityVisuals')end)
 if not ok or not CV or not CV.routeStyles then return true end
 local okG,v=pcall(CV.routeStyles.get,CV.routeStyles)
 return not okG or v~='default'
end
function M.enabled()return setting()end

local function autumn()
 local ok,A=pcall(function()return V.require('AutumnGround')end)
 if not ok or not A then return false end
 local okA,on=pcall(A.active);return okA and on or false
end

-- The look for a map, or nil. `roads` and `grass` are the ROADS and GRASS
-- settings: the path needs Legendary roads, the tint Legendary grass.
function M.lookFor(mapId,tilesetId)
 if tilesetId~='OVERWORLD' or not setting()then return nil end
 return M.looks[tostring(mapId or ''):upper()]
end
function M.pathKind(mapId,tilesetId,roads)
 local look=roads and M.lookFor(mapId,tilesetId)
 return look and look.path or nil
end
-- The grass tint's material name (lawn), or nil. Not in autumn: the fall
-- turf is its own palette and stays as it is.
function M.lawnMaterial(mapId,tilesetId,grass)
 local look=grass and M.lookFor(mapId,tilesetId)
 if not look or not look.grass or autumn()then return nil end
 return 'tg'..look.grass
end
function M.bladeMaterial(mapId,tilesetId,grass)
 local m=M.lawnMaterial(mapId,tilesetId,grass)
 return m and m..'Blade' or nil
end
-- The cache key part for a map's meshes, or nil when nothing here applies.
function M.fingerprint(mapId,tilesetId,roads,grass)
 local look=M.lookFor(mapId,tilesetId)
 if not look then return nil end
 local p=roads and look.path or '-'
 local g=M.lawnMaterial(mapId,tilesetId,grass) or '-'
 if p=='-' and g=='-' then return nil end
 return M.REVISION..':'..p..':'..g
end

------------------------------------------------------------------ builders
-- The lawn's own tone at a spot (WorldGardens 'lawn'), so turf creeping
-- over a path edge is the same turf as the lawn it comes from.
local function lawnTone(a,b)
 return .90+.20*field((a+1)/27,(b+1)/27,130)+.08*field((a+1)/9,(b+1)/9,131)
end

-- Turf lobes creeping in over each edge that meets grass. The lobes sit on
-- a world lattice along the edge line, so a run of path tiles shares one
-- continuous fringe; each tile clips its own share (the turf texture is
-- mapped per tile).
local function grassy(v)return v=='grass' or v=='tall'end
local SIDES={
 {k='w',ax=3,inx=1, inz=0},{k='e',ax=3,inx=-1,inz=0},
 {k='n',ax=1,inx=0, inz=1},{k='s',ax=1,inx=0, inz=-1},
}
local function sideLine(s,x,z)
 if s.k=='w' then return x,z elseif s.k=='e' then return x+8,z
 elseif s.k=='n' then return z,x else return z+8,x end
end
local function fringe(G,x,z,h,edges,o)
 local spacing,depth,keep=o.spacing or 1.8,o.depth or 1,o.keep or 1
 for si,s in ipairs(SIDES)do
  if grassy(edges[s.k]) then
   local line,a0=sideLine(s,x,z)
   local salt=si*97
   for i=floor((a0-3)/spacing),floor((a0+11)/spacing)do
    local r=hash(floor(line),i,701+salt)
    if r<keep then
     local u=(i+.5)*spacing+(hash(floor(line),i,702+salt)-.5)*spacing*.5
     local w=spacing*(.55+.55*hash(floor(line),i,703+salt))
     local d=depth*(.35+.85*hash(floor(line),i,704+salt))
     local p={}
     for j=0,6 do
      local t=j/6*pi
      local along=u-cos(t)*w*.5
      local into=-.04+sin(t)*d*(.85+.3*hash(i,j,705+salt))
      local px,pz
      if s.ax==3 then px,pz=line+s.inx*into,along else px,pz=along,line+s.inz*into end
      p[#p+1]={px,h+.045,pz}
     end
     -- wind the lobe up-facing whichever side it grows from
     local ux,uz=p[2][1]-p[1][1],p[2][3]-p[1][3]
     local vx,vz=p[4][1]-p[1][1],p[4][3]-p[1][3]
     if ux*vz-uz*vx>0 then local q={};for j=#p,1,-1 do q[#q+1]=p[j]end;p=q end
     local cx,cz=s.ax==3 and line+s.inx*d*.4 or u,s.ax==3 and u or line+s.inz*d*.4
     G.face(p,'turf',lawnTone(cx,cz))
     -- now and then a short clump of blades at the lobe's tip
     if o.blades and hash(floor(line),i,706+salt)<o.blades then
      local bx,bz=s.ax==3 and line+s.inx*d*.55 or u,s.ax==3 and u or line+s.inz*d*.55
      for b=0,2 do
       G.blade(bx,bz,h+.04,(o.bladeH or .45)*(.6+.8*hash(i,b,707+salt)),.10,.22,b*2.1+r*6,'turf',.80+.25*hash(b,i,708))
      end
     end
    end
   end
  end
 end
end

-- Soften the corners where a path steps: an outer corner (two sides on
-- grass) gets a sweep of turf over it, an inner corner (two sides on path,
-- lawn on the diagonal) a sweep of the path's own ground over the lawn's
-- point. A stepped diagonal path then reads as a curve, not a staircase.
local CORNERS={{'w','n','nw',0,0,1,1},{'e','n','ne',8,0,-1,1},{'w','s','sw',0,8,1,-1},{'e','s','se',8,8,-1,-1}}
local function fillet(cx,cz,sx,sz,r,y)
 -- the region between the corner point and a quarter circle of radius r
 -- centred r in from it along both sides
 local ox,oz=cx+sx*r,cz+sz*r
 local p={{cx,y,cz},{cx+sx*r,y,cz}}
 for j=1,5 do
  local a=j/6*pi*.5
  p[#p+1]={ox-sx*r*sin(a),y,oz-sz*r*cos(a)}
 end
 p[#p+1]={cx,y,cz+sz*r}
 return p
end
local function corners(G,emit,x,z,h,edges,r,mat,tone)
 for _,c in ipairs(CORNERS)do
  local cx,cz,sx,sz=x+c[4],z+c[5],c[6],c[7]
  if grassy(edges[c[1]])and grassy(edges[c[2]])then
   G.face(fillet(cx,cz,sx,sz,r,h+.046),'turf',lawnTone(cx+sx,cz+sz))
  elseif mat and edges[c[1]]=='path' and edges[c[2]]=='path' and edges[c[3]]=='grass' then
   -- over the lawn tile's corner, outside this tile: a fan, unclipped
   local q=fillet(cx,cz,-sx,-sz,r*.8,h+.05)
   for j=2,#q-1 do emit({q[1],q[j],q[j+1],q[j+1]},mat,tone or 1)end
  end
 end
end

-- A stone set into the path: an irregular five-sided lump. Owned by the tile
-- its centre falls in and NOT clipped (shader materials need no atlas), so
-- a stone may lean a little over the tile's edge.
local function stone(emit,cx,cz,y0,r,ht,mat,seed,tone)
 local n=5;local rot=hash(floor(cx*7),floor(cz*7),seed)*pi*2
 local base,top={},{}
 for j=0,n-1 do
  local a=rot+j/n*pi*2+(hash(j,seed,811)-.5)*.6
  local k=.80+.40*hash(seed,j,812)
  base[j]={cx+cos(a)*r*k,y0,cz+sin(a)*r*k*.85}
  top[j]={cx+cos(a)*r*k*.62,y0+ht*(.80+.20*hash(j,seed,813)),cz+sin(a)*r*k*.85*.62}
 end
 for j=0,n-1 do local q=(j+1)%n
  emit({base[q],base[j],top[j],top[q]},mat,tone*(.80+.12*sin(j*1.3+rot)))
 end
 emit({top[0],top[1],top[2],top[3]},mat,tone*1.06)
 emit({top[0],top[3],top[4],top[4]},mat,tone*1.06)
end
local function stones(emit,x,z,h,cell,dens,r0,r1,h0,h1,mat,seed,tone)
 for gz=floor(z/cell),floor((z+8-.001)/cell)do
  for gx=floor(x/cell),floor((x+8-.001)/cell)do
   if hash(gx,gz,seed)<dens then
    local cx=(gx+.2+.6*hash(gx,gz,seed+1))*cell
    local cz=(gz+.2+.6*hash(gx,gz,seed+2))*cell
    if cx>=x and cx<x+8 and cz>=z and cz<z+8 then
     local r=r0+(r1-r0)*hash(gx,gz,seed+3)
     stone(emit,cx,cz,h+.02,r,h0+(h1-h0)*hash(gx,gz,seed+4),mat,gx*31+gz*17+seed,(tone or 1)*(.90+.18*hash(gx,gz,seed+5)))
    end
   end
  end
 end
end

-- Small islands of turf in the middle of a little-used way.
local function islands(G,x,z,h,cell,dens,seed)
 for gz=floor((z-4)/cell),floor((z+12)/cell)do
  for gx=floor((x-4)/cell),floor((x+12)/cell)do
   if hash(gx,gz,seed)<dens then
    local cx=(gx+.25+.5*hash(gx,gz,seed+1))*cell
    local cz=(gz+.25+.5*hash(gx,gz,seed+2))*cell
    local r=.7+1.2*hash(gx,gz,seed+3)
    local p={}
    for j=0,7 do
     local a=-j/8*pi*2
     local k=.70+.45*hash(gx*8+j,gz,seed+4)
     p[#p+1]={cx+cos(a)*r*k,h+.045,cz+sin(a)*r*k*.8}
    end
    G.face(p,'turf',lawnTone(cx,cz))
   end
  end
 end
end

-- Short tufts standing in the way (the blades are 'turf', or a shader
-- material such as the prairie's straw).
local function tufts(G,x,z,h,cell,dens,height,mat,seed)
 for gz=floor((z-1)/cell),floor((z+9)/cell)do
  for gx=floor((x-1)/cell),floor((x+9)/cell)do
   if hash(gx,gz,seed)<dens then
    local cx=(gx+.2+.6*hash(gx,gz,seed+1))*cell
    local cz=(gz+.2+.6*hash(gx,gz,seed+2))*cell
    if cx>=x and cx<x+8 and cz>=z and cz<z+8 then
     for b=0,3 do
      G.blade(cx,cz,h+.03,height*(.55+.7*hash(gx*4+b,gz,seed+3)),.09,.25,b*1.6+hash(gx,gz,seed+4)*6,mat,.84+.3*hash(b,gx,seed+5))
     end
    end
   end
  end
 end
end

local function base(G,x,z,h,mat,tone)G.flat(x,z,x+8,z+8,h+.03,mat,tone or 1)end

local BUILD={}
-- the country lane: packed earth, turf over its verges, a few stones
function BUILD.lane(G,emit,x,z,h,e)
 base(G,x,z,h,'rtLane')
 fringe(G,x,z,h,e,{spacing=2.4,depth=1.9,keep=.92,blades=.25})
 corners(G,emit,x,z,h,e,6.0,'rtLane')
 stones(emit,x,z,h,3.1,.28,.22,.42,.08,.16,'rtScree',431)
end
-- the overgrown way: the lane gone to grass, islands and tufts in it
function BUILD.wild(G,emit,x,z,h,e)
 base(G,x,z,h,'rtLane',.92)
 fringe(G,x,z,h,e,{spacing=2.2,depth=2.4,keep=1,blades=.45,bladeH=.6})
 corners(G,emit,x,z,h,e,6.5,'rtLane',.92)
 islands(G,x,z,h,4.2,.30,441)
 tufts(G,x,z,h,3.6,.22,.55,'turf',445)
 stones(emit,x,z,h,3.4,.20,.25,.50,.10,.20,'rtScree',447)
end
-- the forest track: loam and leaf litter, mossy verges, roots across it
function BUILD.loam(G,emit,x,z,h,e)
 base(G,x,z,h,'rtLoam')
 fringe(G,x,z,h,e,{spacing=2.0,depth=1.9,keep=1,blades=.40,bladeH=.55})
 corners(G,emit,x,z,h,e,6.0,'rtLoam')
 -- a root now and then, crawling in from a verge
 for si,s in ipairs(SIDES)do
  if e[s.k]=='grass' and hash(floor(x),floor(z),451+si)<.30 then
   local line,a0=sideLine(s,x,z)
   local u=a0+1.5+5*hash(floor(x),floor(z),452+si)
   local len=1.6+2.2*hash(floor(z),floor(x),453+si);local bend=(hash(si,floor(x+z),454)-.5)*1.6
   local w=.20+.12*hash(floor(x),si,455)
   local pts={}
   for j=0,3 do
    local t=j/3;local into=t*len;local al=u+bend*t*t
    local px,pz
    if s.ax==3 then px,pz=line+s.inx*into,al else px,pz=al,line+s.inz*into end
    pts[#pts+1]={px,pz,w*(1-t*.7)}
   end
   for j=1,3 do
    local a,b=pts[j],pts[j+1]
    local dx,dz=b[1]-a[1],b[2]-a[2];local l=max(.001,sqrt(dx*dx+dz*dz));local nx,nz=-dz/l,dx/l
    local ya,yb=h+.03+a[3]*.9,h+.03+b[3]*.9
    G.face({{a[1]+nx*a[3],h+.03,a[2]+nz*a[3]},{b[1]+nx*b[3],h+.03,b[2]+nz*b[3]},{b[1],yb,b[2]},{a[1],ya,a[2]}},'rtLoam',.82)
    G.face({{b[1]-nx*b[3],h+.03,b[2]-nz*b[3]},{a[1]-nx*a[3],h+.03,a[2]-nz*a[3]},{a[1],ya,a[2]},{b[1],yb,b[2]}},'rtLoam',.70)
   end
  end
 end
end
-- mountain scree: gravel, stones, boulders along its verges
function BUILD.scree(G,emit,x,z,h,e)
 base(G,x,z,h,'rtScree')
 fringe(G,x,z,h,e,{spacing=2.4,depth=1.1,keep=.70,blades=.15})
 corners(G,emit,x,z,h,e,5.0,'rtScree')
 stones(emit,x,z,h,2.6,.42,.30,.70,.14,.38,'rtScree',461)
 for si,s in ipairs(SIDES)do
  if e[s.k]=='grass' or e[s.k]==false then
   local line,a0=sideLine(s,x,z)
   for i=0,2 do
    if hash(floor(line),floor(a0/2.7)+i,462+si)<.45 then
     local u=a0+(i+.5)*2.7+(hash(i,floor(line),463+si)-.5)*1.0
     local into=.45+.35*hash(floor(line),i,464+si)
     local cx,cz
     if s.ax==3 then cx,cz=line+s.inx*into,u else cx,cz=u,line+s.inz*into end
     if cx>=x and cx<x+8 and cz>=z and cz<z+8 then
      stone(emit,cx,cz,h+.02,.65+.45*hash(i,floor(a0),465+si),.35+.40*hash(floor(a0),i,466+si),'rtScree',si*13+i+floor(line),.95)
     end
    end
   end
  end
 end
end
-- red mountain earth: dusty, cracked, scattered with red stones
function BUILD.redearth(G,emit,x,z,h,e)
 base(G,x,z,h,'rtRedEarth')
 fringe(G,x,z,h,e,{spacing=2.4,depth=1.4,keep=.85,blades=.20})
 corners(G,emit,x,z,h,e,5.5,'rtRedEarth')
 stones(emit,x,z,h,2.8,.38,.25,.60,.12,.32,'rtRedEarth',471)
end
-- suburban flagstones: sandstone slabs in a bed, kerbs along the lawns
function BUILD.flag(G,emit,x,z,h,e)
 base(G,x,z,h,'rtFlag',.50)
 local gap=.11
 for row=floor(z/4),floor((z+8-.001)/4)do
  local z0,z1=row*4+gap,row*4+4-gap
  local stagger=(row%2)*2.2
  for col=floor((x-stagger)/4.4)-1,floor((x+8-stagger)/4.4)+1 do
   local function xb(c)return c*4.4+stagger+(hash(c,row,481)-.5)*1.4 end
   local x0,x1=xb(col)+gap,xb(col+1)-gap
   if x1>x and x0<x+8 then
    G.flat(x0,z0,x1,z1,h+.09,'rtFlag',.90+.18*hash(col,row,482))
   end
  end
 end
 for si,s in ipairs(SIDES)do
  if grassy(e[s.k]) then
   local line,a0=sideLine(s,x,z)
   for seg=0,1 do
    local u0,u1=a0+seg*4+.04,a0+seg*4+4-.04
    local i0,i1=.06,.86
    local tone=1.0+.08*hash(floor(line),floor(a0)+seg,483)
    if s.ax==3 then
     local xa,xb2=line+s.inx*i0,line+s.inx*i1
     G.box(min(xa,xb2),u0,max(xa,xb2),u1,h+.03,h+.34,'rtFlag',tone)
    else
     local za,zb=line+s.inz*i0,line+s.inz*i1
     G.box(u0,min(za,zb),u1,max(za,zb),h+.03,h+.34,'rtFlag',tone)
    end
   end
  end
 end
end
-- crushed slate: the gravel and a few flat slate rocks
function BUILD.slate(G,emit,x,z,h,e)
 base(G,x,z,h,'rtSlate')
 fringe(G,x,z,h,e,{spacing=2.4,depth=1.2,keep=.80,blades=.22})
 corners(G,emit,x,z,h,e,5.5,'rtSlate')
 stones(emit,x,z,h,2.7,.55,.70,1.25,.05,.09,'rtSlate',491)
end
-- beach sand: sparse turf, dune grass at its verges, a wet margin at water
function BUILD.sand(G,emit,x,z,h,e)
 base(G,x,z,h,'rtSand')
 fringe(G,x,z,h,e,{spacing=2.6,depth=1.2,keep=.55,blades=.55,bladeH=1.1})
 corners(G,emit,x,z,h,e,6.0,'rtSand')
 for si,s in ipairs(SIDES)do
  if e[s.k]=='water' then
   local line,a0=sideLine(s,x,z)
   if s.ax==3 then
    local xa,xb2=line,line+s.inx*1.1
    G.flat(min(xa,xb2),z,max(xa,xb2),z+8,h+.036,'rtSand',.80)
   else
    local za,zb=line,line+s.inz*1.1
    G.flat(x,min(za,zb),x+8,max(za,zb),h+.036,'rtSand',.80)
   end
  end
 end
end
-- the boardwalk: weathered planks over the sand, stringers at its sides
function BUILD.board(G,emit,x,z,h,e)
 base(G,x,z,h,'rtSand',.86)
 local ns=e.n=='path' or e.s=='path'
 local ew=e.w=='path' or e.e=='path'
 local alongX=not(ew and not ns)
 local mat=alongX and 'rtBoardX' or 'rtBoardZ'
 local inset=.35
 -- the planks span a0..a1 along their length and stand side by side
 -- across c0..c1; their ends stop short of an open side, showing sand
 local a0,a1
 if alongX then a0=x+(e.w~='path' and inset or 0);a1=x+8-(e.e~='path' and inset or 0)
 else a0=z+(e.n~='path' and inset or 0);a1=z+8-(e.s~='path' and inset or 0)end
 local lo=floor(x/8)+floor(z/8)*97
 local pitch,gap,top,bottom=1.45,.14,h+.24,h+.10
 local c0,c1
 if alongX then c0=z+(e.n~='path' and inset or 0);c1=z+8-(e.s~='path' and inset or 0)
 else c0=x+(e.w~='path' and inset or 0);c1=x+8-(e.e~='path' and inset or 0)end
 for i=floor(c0/pitch),floor((c1-.001)/pitch)do
  local b0,b1=max(c0,i*pitch+gap*.5),min(c1,(i+1)*pitch-gap*.5)
  if b1>b0 then
   local t=.86+.24*hash(i,lo,521)
   local function P(a,b,y)if alongX then return{a,y,b}else return{b,y,a}end end
   if alongX then
    emit({P(a0,b0,top),P(a1,b0,top),P(a1,b1,top),P(a0,b1,top)},mat,t)
    emit({P(a1,b0,bottom),P(a0,b0,bottom),P(a0,b0,top),P(a1,b0,top)},mat,t*.70)
    emit({P(a0,b1,bottom),P(a1,b1,bottom),P(a1,b1,top),P(a0,b1,top)},mat,t*.84)
   else
    emit({P(a0,b0,top),P(a0,b1,top),P(a1,b1,top),P(a1,b0,top)},mat,t)
    emit({P(a0,b0,bottom),P(a1,b0,bottom),P(a1,b0,top),P(a0,b0,top)},mat,t*.70)
    emit({P(a1,b1,bottom),P(a0,b1,bottom),P(a0,b1,top),P(a1,b1,top)},mat,t*.84)
   end
  end
 end
 -- stringers along the open sides
 for _,s in ipairs(SIDES)do
  if e[s.k]~='path' then
   local line,u0=sideLine(s,x,z)
   local smat=s.ax==3 and 'rtBoardZ' or 'rtBoardX'
   if s.ax==3 then
    local xa,xb2=line+s.inx*.05,line+s.inx*(inset+.05)
    G.box(min(xa,xb2),u0,max(xa,xb2),u0+8,h+.03,h+.30,smat,.78)
   else
    local za,zb=line+s.inz*.05,line+s.inz*(inset+.05)
    G.box(u0,min(za,zb),u0+8,max(za,zb),h+.03,h+.30,smat,.78)
   end
  end
 end
end
-- the prairie track: dust over hardpan, straw tufts standing in it
function BUILD.prairie(G,emit,x,z,h,e)
 base(G,x,z,h,'rtPrairie')
 fringe(G,x,z,h,e,{spacing=2.3,depth=1.6,keep=.85,blades=.35,bladeH=.6})
 corners(G,emit,x,z,h,e,6.0,'rtPrairie')
 tufts(G,x,z,h,3.4,.30,.75,'rtPrairie',531)
end
-- crushed shell: pale, clover creeping over its edges and in patches
function BUILD.shell(G,emit,x,z,h,e)
 base(G,x,z,h,'rtShell')
 fringe(G,x,z,h,e,{spacing=2.2,depth=1.8,keep=.95,blades=.15})
 corners(G,emit,x,z,h,e,6.0,'rtShell')
 islands(G,x,z,h,5.0,.14,541)
end

-- Build one path tile. `edges` gives each side's and diagonal's neighbour
-- (w e n s nw ne sw se): 'grass' (lawn), 'tall' (tall grass), 'water',
-- 'path' or false (anything else). emit(corners,material,tone)
-- takes four corners (a triangle repeats its last); material is an rt*
-- shader material, or 'turf'/'leaf' for the lawn's own atlas art.
function M.buildPath(kind,x,z,h,edges,emit)
 local B=BUILD[kind];if not B then return false end
 local G=C.builder(x,z,emit)
 B(G,emit,x,z,h,edges or {})
 return true
end
M.kinds={}
for k in pairs(BUILD)do M.kinds[#M.kinds+1]=k end
table.sort(M.kinds)
return M
