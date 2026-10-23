-- TEST158: grand cave mouths. Overworld warps into Mt. Moon, Rock Tunnel,
-- Cerulean Cave, Victory Road and Seafoam get a proper mountain entrance
-- built around the existing doorway.
-- TEST176: NATURAL ROCK, ONE GEOLOGY PER CAVE. The timber mine frame, the
-- torches, the lantern and the ring of cut voussoirs are gone: each mouth is
-- now raw rock heaped round a dark throat, a rough lintel slab overhanging
-- it, in the cave's own stone (shader materials rk*, see Voxel3D
-- caveRockSurface):
--   Mt. Moon        speckled grey granite, moss on the tops, moonstone
--                   crystals glinting at the foot;
--   Rock Tunnel     red sandstone in blocky strata, dry and bare;
--   Cerulean Cave   jagged wet blue-black slate with cyan veins, slate
--                   spires, cyan and magenta crystals;
--   Seafoam         frosted ice-rock, icicles hanging from the lintel,
--                   ice crystals;
--   Diglett's Cave  (new) a low earthen mound of banded clay, roots
--                   hanging over the hole, glowing toadstools at its foot.
-- Cold mist still breathes out across the approach and the crystals glow.
-- TEST191: THE MOUNTAIN, NOT JUST THE DOOR. The mouth used to be a heap of
-- rock round the doorway in a plain of brick: the cliff block the cave is cut
-- into stayed masonry. Now the rock runs over the whole block round the door
-- (the cells the ROM draws as mountain, up to six either side and six deep):
-- a massif of boulders that rises behind the arch and falls away to its
-- edges, a stone crust over the brick tops and rock faces over the brick
-- walls, ending in low rubble where a big range carries on as brick. Two
-- mouths on one mountain (Route 4) share it out cell by cell. A brow of
-- rock now juts over the doorway, so you walk in UNDER the mountain.
-- Presentation only: no collision, warp or tile changes. Rocks stay behind
-- the cliff face line, so the approach and the paths beside it stay clear,
-- and they never reach over a building beside the cave (Route 10's Center).
local V=...
local Assets=require("src.render.Assets")
local Mat4=V.require("Mat4")
local Voxel3D=V.require("Voxel3D")
local CommunityVisuals=V.require("CommunityVisuals")
local RM=V.require("ReferenceMaterials")

local M={REVISION='cave-mouths-192'}
local cache=setmetatable({},{__mode='k'})
local whiteTex,softTex,unitCross,unitQuad
local pi,cos,sin,floor,min,max,abs,sqrt=math.pi,math.cos,math.sin,math.floor,math.min,math.max,math.abs,math.sqrt

-- Each cave's stone. crystal: the crystal colour codes (rkCrystal: 1 cyan,
-- 2 magenta, 3 moonstone, 4 ice, 7 green, 8 gold) and their glow colours.
local STYLES={
 moon ={rock='rkMoon', cap='rkMoss',capAt=.82,shape='round', fangs='drip',  crystal={3,6},
        glow={{.75,.84,1.0},{.78,.58,1.0}},mist={.62,.62,.80},scale=1},
 red  ={rock='rkRed',  cap='rkRed', capAt=2,  shape='block', fangs='drip',  crystal=nil,
        glow=nil,mist={.66,.54,.44},scale=1},
 blue ={rock='rkBlue', cap='rkBlue',capAt=2,  shape='jagged',fangs='drip',  crystal={1,2},
        glow={{.35,.95,1.0},{1.0,.42,.92}},mist={.50,.46,.86},scale=1,spires=true},
 ice  ={rock='rkIce',  cap='rkIce', capAt=2,  shape='round', fangs='icicle',crystal={4,3},
        glow={{.55,.80,1.0},{.80,.90,1.0}},mist={.82,.90,1.0},scale=1},
 earth={rock='rkEarth',cap='rkMoss',capAt=.78,shape='round', fangs='roots', crystal=nil,
        glow={{.55,1.0,.45},{1.0,.85,.40}},mist={.62,.56,.46},scale=.62,fungi={7,8}},
}
local CAVES={{"^MT_MOON",'moon'},{"^ROCK_TUNNEL",'red'},{"^CERULEAN_CAVE",'blue'},
 {"^VICTORY_ROAD",'moon'},{"^SEAFOAM",'ice'},{"^DIGLETTS_CAVE",'earth'}}
-- Buildings that share a cave's name (MT_MOON_POKECENTER, ROCK_TUNNEL_
-- POKECENTER, ...) are not caves: only the cave floors themselves count.
local NOT_CAVE={"POKECENTER","MART","HOUSE","GATE","LOBBY","LAB","SHOP"}
local function caveStyle(id)
 id=tostring(id or ""):upper()
 for _,n in ipairs(NOT_CAVE)do if id:find(n,1,true)then return nil end end
 for _,p in ipairs(CAVES)do if id:match(p[1])then return p[2] end end
 return nil
end
local function rh(a,b,s)local v=sin(a*12.9898+b*78.233+s*37.719)*43758.5453;return v-floor(v)end
-- TEST191: the OVERWORLD tiles that draw the mountain itself: the speckled
-- rock mass and its slopes, edges and foot (not trees, water, fences or
-- signs). A cell is mountain when three of its four tiles are.
local ROCK_TILES={[1]=true,[2]=true,[17]=true,[18]=true,[19]=true,[36]=true,[39]=true,
 [50]=true,[52]=true,[53]=true,[54]=true,[55]=true}
M.MASSIF_SIDE=7.2   -- cells either side of the doorway (an oval's half axes)
M.MASSIF_DEPTH=6.6  -- cells back into the cliff
M.MASSIF_FRONT=3    -- cells of a spur running out in front of the face

local function newTex(w,h,fn,nearest)
 local ok,img=pcall(function()
  local d=love.image.newImageData(w,h)
  for y=0,h-1 do for x=0,w-1 do d:setPixel(x,y,1,1,1,fn(x,y))end end
  local made=love.graphics.newImage(d,{mipmaps=false})
  made:setFilter(nearest and "nearest" or "linear",nearest and "nearest" or "linear");made:setWrap("clamp","clamp")
  d:release();return made
 end)
 return ok and img or nil
end
local function white()
 if not whiteTex then whiteTex=newTex(2,2,function()return 1 end,true)end
 return whiteTex
end
local function soft()
 if not softTex then softTex=newTex(64,64,function(x,y)
  local u,v=(x+.5)/32-1,(y+.5)/32-1;local r=sqrt(u*u+v*v)
  if r>=1 then return 0 end
  return min(1,(1-r)^1.8*1.3)
 end)end
 return softTex
end

------------------------------------------------------------------ geometry
local function group()return{verts={},indices={},quads=0}end
local function quad(g,a,b,c,d,shade)
 local s=shade or 1
 g.verts[#g.verts+1]={a[1],a[2],a[3],0,0,s}
 g.verts[#g.verts+1]={b[1],b[2],b[3],1,0,s}
 g.verts[#g.verts+1]={c[1],c[2],c[3],1,1,s}
 g.verts[#g.verts+1]={d[1],d[2],d[3],0,1,s}
 Voxel3D.pushQuad(g.indices,g.quads);g.quads=g.quads+1
end
local function mesh(g)if g.quads==0 then return nil end;return Voxel3D.newMesh(g.verts,g.indices)end
local function units()
 if not unitQuad then local g=group();quad(g,{-1,0,-1},{1,0,-1},{1,0,1},{-1,0,1});unitQuad=mesh(g)end
 if not unitCross then local g=group()
  quad(g,{-1,-1,0},{1,-1,0},{1,1,0},{-1,1,0});quad(g,{0,-1,-1},{0,-1,1},{0,1,1},{0,1,-1});unitCross=mesh(g)end
end
-- a face in a shader material: the vertex shade carries the material tag
local function mat(name,shade)return RM.encode(name,shade)end

-- Each mouth is built in a local frame: x across the doorway, y up from the
-- approach floor, z outward from the cliff face (the face itself is z=0).
local function framer(m)
 local ox,oz,fy,fx,fz=m.ox,m.oz,m.fy,m.fx,m.fz
 local rx,rz=fz,-fx
 return function(x,y,z)return{ox+x*rx+z*fx,fy+y,oz+x*rz+z*fz}end
end
local function facing(a,b,d)
 local ux,uy,uz=b[1]-a[1],b[2]-a[2],b[3]-a[3]
 local vx,vy,vz=d[1]-a[1],d[2]-a[2],d[3]-a[3]
 local nx,ny,nz=uy*vz-uz*vy,uz*vx-ux*vz,ux*vy-uy*vx
 local l=sqrt(nx*nx+ny*ny+nz*nz);if l<1e-6 then return nil end
 return abs(ny/l)
end

------------------------------------------------------------------ find
local function walkable(map,cx,cy)
 local ok,r=pcall(map.isWalkableCell,map,cx,cy);return ok and r or false
end
local function groundAt(map,cx,cy)
 local ok,h=pcall(V.require("VoxelScene").groundAt,map,cx,cy,cx*16,cy*16)
 return(ok and tonumber(h))or 0
end
-- the buildings on a map (BuildingInventory, in map pixels), so rock never
-- spills over one standing beside a cave (Route 10's Pokemon Center)
local function buildingsOf(map)
 local out={}
 local ok,inv=pcall(V.require,"BuildingInventory")
 local id=tostring(map.id or ""):upper()
 if ok and type(inv)=="table" then
  for _,b in ipairs(inv)do if b.map==id then out[#out+1]=b end end
 end
 return out
end
local function buildingCell(list,cx,cy)
 local x0,z0=cx*16,cy*16
 for _,b in ipairs(list)do
  if x0<b.x+b.w and x0+16>b.x and z0<b.z+b.d and z0+16>b.z then return true end
 end
 return false
end
local function findMouths(map)
 local tid=tostring((map.def and map.def.tileset)or(map.tileset and map.tileset.id)or"")
 if tid=="CAVERN" then return {} end
 -- Victory Road's Route 23 entrance is a built gatehouse (LeagueRoad dresses that road)
 if tostring(map.id or"")=="ROUTE_23" then return {} end
 local warps=(map.def and map.def.warps)or map.warps or{}
 local S=buildingsOf(map)
 local list={}
 for _,w in ipairs(warps)do
  local style=w.x and w.y and caveStyle(w.destMap)
  if style then
   -- the open side is the walkable neighbour (south first: Kanto's caves
   -- face the player walking north into them)
   local face
   for _,d in ipairs({{0,1},{1,0},{-1,0},{0,-1}})do
    if not face and walkable(map,w.x+d[1],w.y+d[2])then face=d end
   end
   if face then
    -- merge side-by-side cells of one doorway
    local merged=false
    for _,m in ipairs(list)do
     if m.dest==w.destMap and m.face[1]==face[1]and m.face[2]==face[2]then
      local along=face[2]~=0 and(w.y==m.y0 and abs(w.x-m.x1)==1 or abs(w.x-m.x0)==1)
        or(w.x==m.x0 and abs(w.y-m.y1)==1 or abs(w.y-m.y0)==1)
      if along then
       m.x0,m.x1=min(m.x0,w.x),max(m.x1,w.x);m.y0,m.y1=min(m.y0,w.y),max(m.y1,w.y)
       m.width=m.width+1;merged=true
      end
     end
    end
    if not merged then list[#list+1]={dest=w.destMap,style=style,face=face,x0=w.x,x1=w.x,y0=w.y,y1=w.y,width=1}end
   end
  end
 end
 for _,m in ipairs(list)do
  local fx,fz=m.face[1],m.face[2]
  local cx,cz=(m.x0+m.x1)/2*16+8,(m.y0+m.y1)/2*16+8
  m.fx,m.fz=fx,fz
  m.ox,m.oz=cx+fx*8,cz+fz*8
  local ax,ay=m.x0+fx,m.y0+fz
  m.fy=groundAt(map,ax,ay)
  -- how much solid cliff stands beside the doorway on each side (cells);
  -- a building beside the cave ends it
  local rxs,rzs=fz,-fx
  m.room={}
  for side=-1,1,2 do
   local n=0
   for k=1,3 do
    local bx=(side<0 and(rxs>=0 and m.x0 or m.x1)or(rxs>=0 and m.x1 or m.x0))
    local by=(side<0 and(rzs>=0 and m.y0 or m.y1)or(rzs>=0 and m.y1 or m.y0))
    local cx2,cy2=bx+side*rxs*k,by+side*rzs*k
    if n==k-1 and not walkable(map,cx2,cy2)and not buildingCell(S,cx2,cy2)then n=k end
   end
   m.room[side]=n
  end
 end
 -- TEST191: the massif. Each cell round a mouth is classed once.
 local kinds={}
 local warpAt={}
 for _,w in ipairs(warps)do if w.x and w.y then warpAt[w.y*4096+w.x]=true end end
 local canTiles=type(map.tileAt)=="function" and tid=="OVERWORLD"
 local function kindAt(cx,cy)
  local key=cy*4096+cx
  local k=kinds[key]
  if k then return k end
  if warpAt[key]then k='door'
  elseif walkable(map,cx,cy)then k='walk'
  elseif buildingCell(S,cx,cy)then k='building'
  elseif canTiles then
   local n,water=0,false
   for dy=0,1 do for dx=0,1 do
    local ok,t=pcall(map.tileAt,map,cx*2+dx,cy*2+dy)
    t=ok and t or nil
    if t and ROCK_TILES[t]then n=n+1 end
    if t==20 then water=true end
   end end
   k=(n>=3 and'rock')or(water and'water')or'other'
  else
   k='rock'
  end
  kinds[key]=k
  return k
 end
 local claim={}   -- cell key -> the nearest mouth that reaches it
 for mi,m in ipairs(list)do
  local fx,fz=m.fx,m.fz
  local rxs,rzs=fz,-fx
  local hwC=(m.width-1)/2
  local dcx,dcy=(m.x0+m.x1)/2,(m.y0+m.y1)/2
  -- local cell coordinates: a across the doorway, d back into the cliff
  local function loc(cx,cy)
   local ox,oy=cx-dcx,cy-dcy
   return ox*rxs+oy*rzs,-(ox*fx+oy*fz)
  end
  local seen={}
  local queue={}
  local function push(cx,cy)
   local key=cy*4096+cx
   if seen[key]then return end
   seen[key]=true
   if kindAt(cx,cy)~='rock'then return end
   local a,d=loc(cx,cy)
   if d<-M.MASSIF_FRONT then return end
   -- a rounded outline: a broad oval round the door, not a box
   local ea,ed=abs(a)-hwC,max(d,0)
   if ea<0 then ea=0 end
   if (ea/M.MASSIF_SIDE)^2+(ed/M.MASSIF_DEPTH)^2>1.0 then return end
   queue[#queue+1]={cx,cy}
  end
  -- seeds: the cells beside the doorway and behind it
  for cx=m.x0-1,m.x1+1 do for cy=m.y0-1,m.y1+1 do push(cx,cy)end end
  local qi=1
  while qi<=#queue do
   local c=queue[qi];qi=qi+1
   local a,d=loc(c[1],c[2])
   local key=c[2]*4096+c[1]
   local dist=sqrt(a*a+(d>0 and d or d*1.5)^2)
   local cur=claim[key]
   if not cur or dist<cur.dist then claim[key]={m=mi,dist=dist,cx=c[1],cy=c[2],a=a,d=d}end
   for _,o in ipairs({{1,0},{-1,0},{0,1},{0,-1}})do push(c[1]+o[1],c[2]+o[2])end
  end
 end
 for _,m in ipairs(list)do m.cells={}end
 for _,c in pairs(claim)do
  local m=list[c.m]
  m.cells[#m.cells+1]=c
 end
 for _,m in ipairs(list)do
  table.sort(m.cells,function(p,q)return p.cy*4096+p.cx<q.cy*4096+q.cx end)
  m.claim=claim
  m.kindAt=kindAt
 end
 return list
end

------------------------------------------------------------------ build
local function buildMouth(m,seed)
 local st=STYLES[m.style] or STYLES.moon
 local P=framer(m)
 local K=st.scale
 local hw=m.width*8-1.2
 local H0=22
 local rock,dark=group(),group()
 local rockMat,capMat,capAt=st.rock,st.cap,st.capAt
 local clampBox,keepOut=nil,nil   -- TEST191: set while the massif is laid
 -- A boulder. 'round': a jittered seven-sided lump; 'block': a five-sided
 -- slab with a flat top (bedded sandstone); 'jagged': a narrow-shouldered
 -- crag with a broken peak. Up-facing faces take the cap material (moss,
 -- frost); every vertex stays behind maxZ so nothing spills over the path.
 local function boulder(cx,cy,cz,rx,ry,rz,sd,maxZ,reach)
  if reach and abs(cx)-rx*.7>reach then return end
  local shape=st.shape
  local n=shape=='block' and 5 or 7
  local rot=rh(sd,0,71)*pi*2
  local rings
  if shape=='block' then rings={{0,1.0},{.12,1.04},{.80,1.0},{.92,.80}}
  elseif shape=='jagged' and keepOut then rings={{0,1.0},{.42,1.0},{.78,.66},{1.02,.28}} -- (blunter across the massif)
  elseif shape=='jagged' then rings={{0,1.0},{.40,.95},{.78,.58},{1.12,.14}}
  else rings={{0,1.0},{.48,1.08},{.82,.72},{1,.18}} end
  local pts={}
  for ri,rg in ipairs(rings)do
   pts[ri]={}
   for i=0,n-1 do
    local a=rot+i/n*pi*2+(rh(sd,i+ri*9,73)-.5)*(shape=='block' and .25 or .5)
    local k=rg[2]*(.80+rh(sd,i*3+ri,75)*.40)
    local jy=ri>1 and(rh(sd,i,77+ri)-.5)*(shape=='jagged' and .30 or shape=='block' and .04 or .12)or -.03
    local x,y,z=cx+cos(a)*rx*k,cy+(rg[1]+jy)*ry,cz+sin(a)*rz*k
    if maxZ then z=min(z,maxZ)end
    -- TEST191: massif rock keeps out of the throat (below its roof, in
    -- the doorway's width, as deep as the dark goes) ...
    if keepOut and z>keepOut.z and y<keepOut.y and abs(x)<keepOut.x then
     x=(x<0 or(x==0 and cx<0))and -keepOut.x or keepOut.x
    end
    local p=P(x,y,z)
    -- ... and inside the ground its cell may cover (world space)
    if clampBox then
     p[1]=min(max(p[1],clampBox[1]),clampBox[2])
     p[3]=min(max(p[3],clampBox[3]),clampBox[4])
    end
    pts[ri][i]=p
   end
  end
  local function face(a,b,c,d)
   local ny=facing(a,b,d);if not ny then return end
   local sh=.64+.36*ny+(rh(a[1],a[3],79)-.5)*.08
   quad(rock,a,b,c,d,mat(ny>capAt and capMat or rockMat,sh))
  end
  for ri=1,#rings-1 do
   for i=0,n-1 do local j=(i+1)%n
    face(pts[ri][i],pts[ri][j],pts[ri+1][j],pts[ri+1][i])
   end
  end
  -- close the top
  local top=pts[#rings];local c=top[0]
  for i=1,n-2 do
   local ny=facing(c,top[i],top[i+1]) or 1
   quad(rock,c,top[i],top[i+1],top[i+1],mat(ny>capAt and capMat or rockMat,.64+.36*ny))
  end
 end
 -- a hanging point: dripstone, an icicle, a root
 local function fang(x,y,z,r,len,sd,matName,tone)
  local n=4;local tip=P(x+(rh(sd,1,23)-.5)*r,y-len,z)
  for i=0,n-1 do
   local a0,a1=i/n*pi*2+sd,(i+1)/n*pi*2+sd
   quad(rock,P(x+cos(a0)*r,y,z+sin(a0)*r),P(x+cos(a1)*r,y,z+sin(a1)*r),tip,tip,mat(matName,(i%2==0 and .82 or .64)*(tone or 1)))
  end
 end
 -- a standing point: a slate spire
 local function spire(x,z,r,len,sd)
  local n=5;local tip=P(x+(rh(sd,2,29)-.5)*r*1.2,len,z+(rh(sd,3,29)-.5)*r*.6)
  for i=0,n-1 do
   local a0,a1=i/n*pi*2+sd,(i+1)/n*pi*2+sd
   quad(rock,P(x+cos(a0)*r,-.3,z+sin(a0)*r*.8),P(x+cos(a1)*r,-.3,z+sin(a1)*r*.8),tip,tip,mat(rockMat,.66+.30*abs(sin(a0+1.1))))
  end
 end
 local function crystal(code,x,y,z,ax,ay,az,r,len)
  local n=6
  local ux,uy,uz
  if abs(ay)<.9 then ux,uy,uz=-az,0,ax else ux,uy,uz=1,0,0 end
  local ul=sqrt(ux*ux+uy*uy+uz*uz);ux,uy,uz=ux/ul,uy/ul,uz/ul
  local vx,vy,vz=ay*uz-az*uy,az*ux-ax*uz,ax*uy-ay*ux
  local body=len*.78
  local tip=P(x+ax*len,y+ay*len,z+az*len)
  local r0,r1={},{}
  for i=0,n-1 do
   local a=i/n*pi*2
   local cx,cy,cz=(ux*cos(a)+vx*sin(a))*r,(uy*cos(a)+vy*sin(a))*r,(uz*cos(a)+vz*sin(a))*r
   r0[i]=P(x+cx,y+cy,z+cz)
   r1[i]=P(x+cx*.92+ax*body,y+cy*.92+ay*body,z+cz*.92+az*body)
  end
  local s=mat('rkCrystal',code)
  for i=0,n-1 do local j=(i+1)%n
   quad(rock,r0[i],r0[j],r1[j],r1[i],s);quad(rock,r1[i],r1[j],tip,tip,s)
  end
 end
 -- a glowing toadstool: a stem and a domed cap that lights itself
 local function toadstool(code,x,z,size,sd)
  local n=6;local hgt=size*1.6;local cr=size*1.1
  for i=0,n-1 do
   local a0,a1=i/n*pi*2,(i+1)/n*pi*2
   local sr=size*.22
   quad(rock,P(x+cos(a0)*sr,0,z+sin(a0)*sr),P(x+cos(a1)*sr,0,z+sin(a1)*sr),P(x+cos(a1)*sr,hgt,z+sin(a1)*sr),P(x+cos(a0)*sr,hgt,z+sin(a0)*sr),mat('rkEarth',.9))
   local top=P(x,hgt+cr*.55,z)
   quad(rock,P(x+cos(a0)*cr,hgt,z+sin(a0)*cr),P(x+cos(a1)*cr,hgt,z+sin(a1)*cr),top,top,mat('rkCrystal',code))
   quad(rock,P(x+cos(a1)*cr,hgt,z+sin(a1)*cr),P(x+cos(a0)*cr,hgt,z+sin(a0)*cr),P(x,hgt-.2,z),P(x,hgt-.2,z),mat('rkCrystal',code))
  end
 end

 local yc=H0-hw-.6
 for side=-1,1,2 do
  local s=seed+(side+1)*37
  local reach=hw+(m.room and m.room[side]or 3)*16+2
  local X=function(v)return side*v end
  -- the jambs: two heaped stones each side of the throat
  boulder(X(hw+3.8),0,-.6,4.4,yc*.62,3.8,s+1,3.2,reach)
  boulder(X(hw+3.0),yc*.52,-1.2,3.9,yc*.66,3.4,s+2,2.4,reach)
  boulder(X(hw+1.6),yc*1.0,-1.4,3.4,6.0,3.0,s+20,1.6,reach)
  -- the mountain's shoulders: broad, layered, leaning in
  boulder(X(hw+14*K),0,-3.5,11*K,19*K,8.5,s+3,5.0,reach)
  boulder(X(hw+12*K),15*K,-6,10.5*K,13*K,8,s+4,2.5,reach)
  boulder(X(hw+9*K),25*K,-8,9*K,11*K,7,s+5,.5,reach)
  boulder(X(hw+27*K),0,-4,11*K,14*K,8,s+6,4.5,reach)
  boulder(X(hw+24*K),11*K,-8,9.5*K,11*K,7,s+7,1.5,reach)
  if K>.8 then
   boulder(X(hw+38),0,-4,8,9,6.5,s+8,3.5,reach)
   boulder(X(hw+34),7,-8,7,9,5.5,s+9,1,reach)
   boulder(X(hw+19),20,-11,8,10,6,s+13,0,reach)
  end
  -- loose rocks fallen at the foot of the face
  boulder(X(hw+8.5*K),0,2.0,3.0*K,3.2*K,2.4,s+10,5.5,reach)
  boulder(X(hw+21*K),0,3.2,3.6*K,4.0*K,2.8,s+11,6.5,reach)
  if K>.8 then boulder(X(hw+33),0,3.0,2.4,2.4,2.0,s+12,6.0,reach)end
  if st.spires then
   for i=0,2 do
    local x=hw+6+i*9+rh(s,i,41)*4
    if x<reach then spire(X(x),.8+rh(i,s,43)*1.6,1.5+rh(s,i,45),16+rh(i,s,47)*12+(i==0 and 8 or 0),s+i*7)end
   end
  end
 end
 -- the lintel: one rough slab overhanging the throat, a stone or two
 -- wedged above it -- no cut ring of voussoirs
 boulder(0,H0-1.6,-1.0,hw+4.6,6.4*(st.shape=='block' and .9 or 1),4.4,seed+40,1.4)
 boulder(-hw*.35,H0+3.4,-2.6,hw*.75+2.5,5.5,3.8,seed+41,.6)
 boulder(hw*.4,H0+3.0,-2.4,hw*.7+2.2,5.2,3.6,seed+42,.6)
 -- TEST191: a brow of rock jutting out over the doorway, so the way in
 -- runs under the mountain rather than up to a hole in a wall
 boulder(0,H0+1.7,1.0,hw+3.4,4.8,3.8,seed+43,4.8)
 boulder(-hw*.5,H0+4.6,0,hw*.6+2.6,4.2,3.4,seed+44,3.6)
 boulder(hw*.5,H0+4.2,-.2,hw*.6+2.4,4.4,3.4,seed+45,3.4)
 -- the crown: a broad hump of the mountain over the entrance (wide and
 -- low, so it reads as the hill the cave is cut into, not a cairn)
 boulder(0,H0+5*K,-6,hw+12*K,10*K,8,seed+90,1.0)
 boulder(-hw*.6-4*K,H0+9*K,-10,hw+8*K,9*K,7,seed+91,0)
 boulder(hw*.6+4*K,H0+8*K,-10,hw+7*K,9*K,7,seed+92,0)
 if K>.8 then
  boulder(-hw*.1,H0+14,-12,hw+5,8,6,seed+93,0)
  boulder(-hw-14,H0+4,-12,9,8,6,seed+94,0)
  boulder(hw+15,H0+3,-12,9,8,6,seed+95,0)
 end
 -- what hangs inside the arch head
 local nf=st.fangs=='icicle' and 8 or 5
 for i=0,nf-1 do
  local x=-hw+1.0+(2*hw-2)*(i+.5)/nf+(rh(seed,i,31)-.5)*1.2
  local top=H0-1.2
  -- (TEST192: in front of the doorway's dark face, see below)
  local z=.7+rh(seed,i,33)*.9
  if st.fangs=='icicle' then
   fang(x,top,z,.45+rh(i,seed,35)*.45,3.0+rh(seed,i,37)*5.5,seed+i,'rkIce',1.1)
  elseif st.fangs=='roots' then
   fang(x,top,z,.14+rh(i,seed,35)*.10,3.5+rh(seed,i,37)*5.0,seed+i,'rkEarth',.55)
   fang(x+.5,top-1,z-.3,.10,2.0+rh(seed,i,39)*3.0,seed+i+9,'rkEarth',.50)
  else
   fang(x,top,z,.6+rh(i,seed,35)*.6,1.8+rh(seed,i,37)*3.2,seed+i,rockMat,1)
  end
 end
 -- the dark throat behind the doorway
 -- (TEST191: in front of the brick face of the cell behind the door, which
 -- used to show through the doorway as a wall with a slot in it)
 local back=-15.6
 -- TEST192: and the doorway itself. The engine folds a cave door cell into
 -- the cliff (Structures' door fold) with the Game Boy door art standing AT
 -- the face line, rock painted as brick round a black slot, in front of all
 -- of the above. A dark face just proud of it closes the opening: what you
 -- see is the dark under the brow, and you walk into it.
 quad(dark,P(-hw-1,0,.35),P(hw+1,0,.35),P(hw+1,H0+1,.35),P(-hw-1,H0+1,.35))
 quad(dark,P(-hw,0,back),P(hw,0,back),P(hw,H0+1,back),P(-hw,H0+1,back))
 quad(dark,P(-hw,0,-1),P(-hw,0,back),P(-hw,H0+1,back),P(-hw,H0+1,-1))
 quad(dark,P(hw,0,back),P(hw,0,-1),P(hw,H0+1,-1),P(hw,H0+1,back))
 quad(dark,P(-hw,H0+1,-1),P(hw,H0+1,-1),P(hw,H0+1,back),P(-hw,H0+1,back))
 quad(dark,P(-hw,.12,-1),P(hw,.12,-1),P(hw,.12,back),P(-hw,.12,back))
 -- crystals in the cave's own colours, pushing out of the rock feet
 local sites={{-(hw+3.2),3.6},{hw+3.4,3.8},{-(hw+17*K),4.8},{hw+16.5*K,4.6},{-(hw+29*K),4.2},{hw+30*K,4.0}}
 -- TEST191: and further along the foot of the massif, where the face meets
 -- open ground: up to two more clusters a side
 do
  local ext={[-1]={},[1]={}}
  for _,c in ipairs(m.cells or{})do
   if c.d<.6 and c.d>-.6 and abs(c.a)>=2.6 and m.kindAt
      and m.kindAt(c.cx+m.fx,c.cy+m.fz)=='walk' then
    local sd=c.a<0 and -1 or 1
    ext[sd][#ext[sd]+1]=c
   end
  end
  for sd=-1,1,2 do
   local l=ext[sd]
   table.sort(l,function(p,q)return abs(p.a)<abs(q.a)end)
   local took=0
   for i=1,#l do
    if took<2 and(i==#l or rh(l[i].cx,l[i].cy,433)<.6)then
     sites[#sites+1]={l[i].a*16+(rh(l[i].cx,l[i].cy,435)-.5)*6,3.4+rh(l[i].cy,l[i].cx,437)*1.2}
     took=took+1
    end
   end
  end
 end
 local halo={}
 if st.crystal then
  for si,sp in ipairs(sites)do
   local ci=si%2+1;local count=4+floor(rh(seed,si,41)*3)
   local k=si<=2 and 1.45 or 1.1
   for c=0,count-1 do
    local a=c/count*pi*2+rh(seed,c+si,43)
    local lx,lz=cos(a)*.55,.35+sin(a)*.35
    local ly=1.1+rh(c,si,45)*.8;local l=sqrt(lx*lx+ly*ly+lz*lz)
    local len=(2.6+rh(si,c,47)*(c==0 and 6 or 3.8))*k
    local r=(.45+rh(c,si,49)*.5)*k
    crystal(st.crystal[ci],sp[1]+cos(a)*1.4,0,sp[2]+sin(a)*.8,lx/l,ly/l,lz/l,r,len)
   end
   local p=P(sp[1],3.5,sp[2]+.8);halo[#halo+1]={x=p[1],y=p[2],z=p[3],ci=ci,r=si<=2 and 9 or 7}
  end
 end
 if st.fungi then
  for si,sp in ipairs(sites)do
   if si<=4 then
    local ci=si%2+1
    for c=0,2+floor(rh(seed,si,51)*3)do
     local a=c*2.1+rh(seed,si,53)*6
     toadstool(st.fungi[ci],sp[1]*.8+cos(a)*1.3,sp[2]+sin(a)*.9,.55+rh(c,si,55)*.55,seed+c)
    end
    local p=P(sp[1]*.8,1.6,sp[2]+.6);halo[#halo+1]={x=p[1],y=p[2],z=p[3],ci=ci,r=5}
   end
  end
 end

 ------------------------------------------------------------------ TEST191
 -- THE MASSIF: rock over the rest of the mountain block round the door
 if m.cells and #m.cells>0 then
  local own={}
  for _,c in ipairs(m.cells)do own[c.cy*4096+c.cx]=c end
  local claimAll=m.claim or{}
  local kindAt=m.kindAt
  local DIR4={{1,0},{-1,0},{0,1},{0,-1}}
  -- how each neighbour meets a massif cell
  local function edgeKind(cx,cy)
   local key=cy*4096+cx
   if own[key]then return'own'end
   if claimAll[key]then return'rock'end      -- the next mouth's massif
   local k=kindAt and kindAt(cx,cy)or'other'
   if k=='rock'then return'soft'end          -- the range carries on as brick
   return k                                  -- walk, water, door, building, other
  end
  local HARD={walk=true,water=true,door=true,building=true,other=true}
  -- how far rock from a cell may reach over each kind of neighbour
  local MARGIN={own=7,rock=7,soft=6,walk=2.4,water=1.6,door=.25,building=.25,other=.4}
  local CRUST={own=0,rock=0,soft=0,walk=1.0,water=.8,door=0,building=0,other=.3}
  -- cells from the nearest hard edge, and from the nearest soft one
  local hardD,softD,q1,q2={},{},{},{}
  for _,c in ipairs(m.cells)do
   local key=c.cy*4096+c.cx
   c.e={}
   local hard,soft=false,false
   for i,o in ipairs(DIR4)do
    local k=edgeKind(c.cx+o[1],c.cy+o[2]);c.e[i]=k
    if HARD[k]then hard=true elseif k=='soft'then soft=true end
   end
   if hard then hardD[key]=1;q1[#q1+1]=c end
   if soft then softD[key]=1;q2[#q2+1]=c end
  end
  local function spread(D,q)
   local i=1
   while i<=#q do
    local c=q[i];i=i+1
    local dv=D[c.cy*4096+c.cx]
    for _,o in ipairs(DIR4)do
     local nk=(c.cy+o[2])*4096+c.cx+o[1]
     local nc=own[nk]
     if nc and not D[nk]then D[nk]=dv+1;q[#q+1]=nc end
    end
   end
  end
  spread(hardD,q1);spread(softD,q2)
  local throatX=hw+.4
  local t1,t2=P(-throatX,0,1.0),P(throatX,0,-17)
  local thr={min(t1[1],t2[1]),max(t1[1],t2[1]),min(t1[3],t2[3]),max(t1[3],t2[3])}
  local rxs,rzs=m.fz,-m.fx
  local function toLocal(wx,wz)
   local dx,dz=wx-m.ox,wz-m.oz
   return dx*rxs+dz*rzs,dx*m.fx+dz*m.fz
  end
  -- a rectangle minus the throat's footprint
  local function crust(x0,x1,z0,z1,y,sh)
   local rects={{x0,x1,z0,z1}}
   if x0<thr[2] and x1>thr[1] and z0<thr[4] and z1>thr[3] then
    rects={}
    if z0<thr[3]then rects[#rects+1]={x0,x1,z0,thr[3]}end
    if z1>thr[4]then rects[#rects+1]={x0,x1,thr[4],z1}end
    local zz0,zz1=max(z0,thr[3]),min(z1,thr[4])
    if x0<thr[1]then rects[#rects+1]={x0,thr[1],zz0,zz1}end
    if x1>thr[2]then rects[#rects+1]={thr[2],x1,zz0,zz1}end
   end
   for _,r in ipairs(rects)do
    if r[2]-r[1]>.05 and r[4]-r[3]>.05 then
     quad(rock,{r[1],y,r[4]},{r[2],y,r[4]},{r[2],y,r[3]},{r[1],y,r[3]},mat(rockMat,sh))
    end
   end
  end
  for ci,c in ipairs(m.cells)do
   local key=c.cy*4096+c.cx
   local x0w,z0w=c.cx*16,c.cy*16
   local lx,lz=toLocal(x0w+8,z0w+8)
   local a,dd=lx/16,-lz/16
   local eh,es=hardD[key]or 9,softD[key]or 9
   -- tallest a cell or two behind the arch, falling away to the sides,
   -- lower along open edges, down to rubble where the range carries on
   local f=math.exp(-(a*a)/(2*3.4*3.4)-((dd-1.4)^2)/(2*2.6*2.6))
   local rise=(6+30*f)*K
   if eh==1 then rise=rise*.72 end
   if dd<0 then rise=rise*.8 end   -- a spur running out in front stays lower
   if es==1 then rise=min(rise,3.5+2*rh(c.cx,c.cy,401))elseif es==2 then rise=rise*.72 end
   local top=16+rise+rh(c.cx,c.cy,403)*3
   clampBox={x0w-MARGIN[c.e[2]],x0w+16+MARGIN[c.e[1]],z0w-MARGIN[c.e[4]],z0w+16+MARGIN[c.e[3]]}
   keepOut={x=throatX,y=H0+1.6,z=-17}
   local sd=seed*7+ci*13
   local base=eh==1 and 0 or 7
   if abs(lx)<hw+8 and lz>-34 and lz<0 then base=max(base,H0+1.2);top=max(top,H0+10)end
   local r0=9.5+rh(sd,1,405)*2
   local jx,jz=(rh(sd,2,407)-.5)*4,(rh(sd,3,409)-.5)*4
   boulder(lx+jx,base,lz+jz,r0,max(4,top-base),r0*(.9+rh(sd,4,411)*.2),sd)
   if top-base>20 then
    local r1=5.5+rh(sd,5,413)*2.5
    boulder(lx-jx*1.4,top-12,lz-jz*1.4,r1,12+rh(sd,6,415)*5,r1,sd+1)
   end
   clampBox=nil;keepOut=nil
   if st.spires and dd>1 and es>1 and rh(sd,7,417)<.14 then
    spire(lx+jx*.5,lz+jz*.5,1.5+rh(sd,8,419),top+4+rh(sd,9,421)*9,sd+3)
   end
   -- a crust of stone over the brick top
   crust(x0w-CRUST[c.e[2]],x0w+16+CRUST[c.e[1]],z0w-CRUST[c.e[4]],z0w+16+CRUST[c.e[3]],17.3,.86+rh(c.cx,c.cy,425)*.1)
   -- and rock faces over the brick walls that meet open ground
   for i,o in ipairs(DIR4)do
    local k=c.e[i]
    if k=='walk'or k=='water'then
     local nx,nz=o[1],o[2];local tx,tz=-nz,nx
     local ex,ez=x0w+8+nx*8,z0w+8+nz*8
     for sg=0,2 do
      local s0,s1=-8.9+sg*5.94,-8.9+(sg+1)*5.94
      local hb=rh(c.cx*3+i,c.cy*5+sg,431)
      local o0,o1=1.9+hb*.8,.75+hb*.45
      local y1=17.2+hb*1.8
      quad(rock,{ex+nx*o0+tx*s0,-.2,ez+nz*o0+tz*s0},{ex+nx*o0+tx*s1,-.2,ez+nz*o0+tz*s1},
                {ex+nx*o1+tx*s1,y1,ez+nz*o1+tz*s1},{ex+nx*o1+tx*s0,y1,ez+nz*o1+tz*s0},mat(rockMat,.64+hb*.12))
     end
    end
   end
  end
 end
 -- mist breathing out across the approach
 local mist={}
 for i=0,3 do
  local p=P((rh(seed,i,61)-.5)*hw*1.4,0,3+i*3.2)
  mist[#mist+1]={x=p[1],y=m.fy+.9+i*.25,z=p[3],r=hw*1.2+5+i*3,phase=rh(i,seed,63)*6.28,
   drift=2+rh(seed,i,65)*3,fx=m.fx,fz=m.fz}
 end
 return{rock=mesh(rock),dark=mesh(dark),mist=mist,halo=halo,
  glow=st.glow,mistColor=st.mist,cx=m.ox,cz=m.oz,quads=rock.quads+dark.quads}
end

local function build(map)
 local out={}
 for i,m in ipairs(findMouths(map))do
  local ok,b=pcall(buildMouth,m,i*131+(m.x0 or 0)*7+(m.y0 or 0)*3)
  if ok and b then out[#out+1]=b
  else print('[CaveMouths] '..tostring(m.dest)..' mouth failed: '..tostring(b))end
 end
 return out
end

local function release(list)
 for _,b in ipairs(list or{})do
  for _,mm in ipairs({b.rock,b.dark})do
   if mm and mm.release then pcall(mm.release,mm)end
  end
 end
end

------------------------------------------------------------------ draw
local function drawMap(map,model,focusX,focusZ)
 local list=cache[map]
 if list==nil then list=build(map);cache[map]=list end
 if #list==0 then return end
 units()
 local wt,st=white(),soft()
 if not(wt and st)then return end
 local t=0;pcall(function()t=love.timer.getTime()end)
 local g=love.graphics
 local ox,oz=0,0
 if model then ox,oz=model[4] or 0,model[12] or 0 end
 local pushed=pcall(g.push,"all")
 pcall(function()
  g.setDepthMode("lequal",true);g.setBlendMode("alpha")
  Voxel3D.lighting(true)
  g.setColor(1,1,1,1)
  for _,b in ipairs(list)do if b.rock then Voxel3D.draw(b.rock,wt,model)end end
  Voxel3D.lighting(false)
  g.setColor(.012,.010,.014,1)
  for _,b in ipairs(list)do if b.dark then Voxel3D.draw(b.dark,wt,model)end end
  Voxel3D.lighting(true)
 end)
 pcall(Voxel3D.lighting,true)
 if pushed then pcall(g.pop)end
 local function M4(x,y,z,sx,sy,sz,yaw)
  local m=Mat4.translate(x+ox,y,z+oz)
  if yaw then m=Mat4.mul(m,Mat4.rotateY(yaw))end
  return Mat4.mul(m,Mat4.scale(sx,sy,sz))
 end
 pcall(Voxel3D.withEffect,"add",function()
  for _,b in ipairs(list)do
   if b.glow then
    for _,h in ipairs(b.halo)do
     local c=b.glow[h.ci];local p=.80+.20*sin(t*.9+h.ci*1.7)
     g.setColor(c[1],c[2],c[3],.20*p);Voxel3D.draw(unitCross,st,M4(h.x,h.y,h.z,h.r,h.r*.85,h.r))
     g.setColor(c[1],c[2],c[3],.22*p);Voxel3D.draw(unitQuad,st,M4(h.x,h.y-3.2,h.z,h.r*1.4,1,h.r*1.4))
    end
   end
  end
 end)
 pcall(Voxel3D.withEffect,"alpha",function()
  for _,b in ipairs(list)do
   local mc=b.mistColor or{.6,.62,.8}
   for i,p in ipairs(b.mist)do
    local breathe=.5+.5*sin(t*.35+p.phase)
    local push=((t*.06+i*.25)%1)
    local x=p.x+p.fx*push*p.drift*3+sin(t*.07+p.phase)*2
    local z=p.z+p.fz*push*p.drift*3+cos(t*.05+p.phase)*2
    g.setColor(mc[1],mc[2],mc[3],(.07+breathe*.04)*sin(push*pi))
    Voxel3D.draw(unitQuad,st,M4(x,p.y,z,p.r,1,p.r*.8,t*.02+p.phase))
   end
  end
 end)
end

function M.draw(state)
 local map=state and state.map
 if not map then return false end
 local ok,d=pcall(CommunityVisuals.caveDetailLevel)
 if ok and d=="off" then return false end
 local p=state.player
 local fx,fz=(p and p.px or 0)+8,(p and p.py or 0)+8
 drawMap(map,nil,fx,fz)
 local RD=V.require("RenderDistance")
 for _,nb in ipairs(state.neighbors or{})do
  if nb.map and(not RD or RD.neighbor(nb,p))then
   drawMap(nb.map,Mat4.translate(nb.ox or 0,0,nb.oy or 0),fx,fz)
  end
 end
 return true
end
function M.drawBattle(map)
 if not map then return false end
 drawMap(map,nil,0,0);return true
end
function M.placements(map)
 local list=cache[map];if list==nil then list=build(map);cache[map]=list end
 return list
end
M.findMouths=findMouths
M.buildMouth=buildMouth
M.STYLES=STYLES
function M.invalidate()
 for _,l in pairs(cache)do release(l)end
 cache=setmetatable({},{__mode='k'})
 for _,m in ipairs({whiteTex,softTex,unitCross,unitQuad})do if m and m.release then pcall(m.release,m)end end
 whiteTex,softTex,unitCross,unitQuad=nil,nil,nil,nil
end
Assets.register(M.invalidate)
return M
