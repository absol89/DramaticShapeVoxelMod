-- TEST191: VICTORY ROAD'S BOULDER FIELDS. Victory Road's blocked cells are
-- mostly the CAVERN rock mass ($02/$03 over $12/$13, and the boulder-cluster
-- mass $0C/$0D over $1C/$1D) scattered ONE CELL AT A TIME across the floor:
-- the Game Boy draws a field of loose round rocks you thread between while
-- you push the Strength boulders about. Every other cave uses the same tiles
-- as solid wall, and the mesher stands cave walls at 30 (TEST39) -- which in
-- Victory Road turned each loose rock into a 30-high block and the boulder
-- puzzles into corridors between cliffs, the boulders and the floor round
-- them hidden from the camera.
--
-- Here, on Victory Road only:
--   * the rock-mass cells stand 3 high (ChunkMesher asks heightFor) and
--     each wears a heap of rounded stones instead -- a big one and one or
--     two at its foot, about 20 high at most, so you see over them. TEST192:
--     flat-shaded grey stone from a small palette (the shader's earth
--     finish read as beige sandbags in boxes), on a base that barely shows;
--   * the shelf faces round the lit plateaus keep their source height (16,
--     not 30), a rim at the plateau's edge rather than a wall;
--   * torches and crystal veins are not hung on the loose rocks (they want
--     a full-height wall; CaveSconces and CaveMood ask isLow).
--   * TEST192: THE BOULDER SWITCHES. The cave floor finish painted over the
--     round floor switch ($2B-$2E) like any other dirt, so there was no
--     telling where a boulder had to go. Each switch is now a stone
--     pressure plate (a pale ring, a grey plate, a boss) with a cool light
--     pulsing round it, steady green once a boulder rests on it.
-- Presentation only: collision, Strength and the switches are the engine's.
local V=...
local Assets=require("src.render.Assets")
local Mat4=V.require("Mat4")
local Voxel3D=V.require("Voxel3D")
local CommunityVisuals=V.require("CommunityVisuals")

local M={REVISION='cave-rubble-206'}
local pi,cos,sin,floor,min,max,abs,sqrt=math.pi,math.cos,math.sin,math.floor,math.min,math.max,math.abs,math.sqrt
local function rh(a,b,s)local v=sin(a*12.9898+b*78.233+s*37.719)*43758.5453;return v-floor(v)end
local cache=setmetatable({},{__mode='k'})

M.MAPS={VICTORY_ROAD_1F=true,VICTORY_ROAD_2F=true,VICTORY_ROAD_3F=true}
-- the loose rock: the speckled mass and the boulder-cluster mass
M.ROCK={[2]=true,[3]=true,[18]=true,[19]=true,[12]=true,[13]=true,[28]=true,[29]=true}
M.ROCK_H=3        -- what the mesher stands a loose-rock tile at (a low base)
M.SHELF_H=16      -- the other CAVERN wall tiles here: their source height

local function caveMap(map)
 local tid=map and tostring((map.def and map.def.tileset)or(map.tileset and map.tileset.id)or"")or""
 return tid=="CAVERN"
end
-- does this map get the boulder-field treatment?
function M.applies(map)
 if not(map and M.MAPS[tostring(map.id or""):upper()]and caveMap(map))then return false end
 local ok,custom=pcall(CommunityVisuals.customCaves)
 return ok and custom and true or false
end
-- TEST203: CERULEAN CAVE'S LOW WALLS. The Unknown Dungeon is a maze of
-- one-cell rock walls and water channels; stood at 30 (TEST39) each wall
-- was twice Ash's height, so the camera looked into a slot between cliffs,
-- the next turning hidden, and the corridors read as dead ends. Its walls
-- now keep their source height (16, a shoulder-high rim like Victory
-- Road's shelves), so you see the maze you are walking through. No rubble
-- heaps here: every wall tile is simply 16. Collision is the engine's.
M.LOW={CERULEAN_CAVE_1F=true,CERULEAN_CAVE_2F=true,CERULEAN_CAVE_B1F=true}
-- TEST206: a little taller than TEST203's 16 -- above Ash's head, so the
-- maze reads as walls, and still well under the old 30
M.LOW_H=22
function M.lowWalls(map)
 if not(map and M.LOW[tostring(map.id or""):upper()]and caveMap(map))then return false end
 local ok,custom=pcall(CommunityVisuals.customCaves)
 return ok and custom and true or false
end
-- walls stand at source height here (Victory Road or the low-wall caves):
-- torches hang six lower, and nothing hangs from a 30-high crown
function M.shelfWalls(map)
 return M.applies(map)or M.lowWalls(map)
end
-- the height the maze walls stand at here (nil: the usual 30)
function M.wallTop(map)
 if M.applies(map)then return M.SHELF_H end
 if M.lowWalls(map)then return M.LOW_H end
 return nil
end
-- the mesher's render height for a CAVERN wall tile here (nil: unchanged)
function M.heightFor(map,tile)
 if M.applies(map)then
  if M.ROCK[tile]then return M.ROCK_H end
  return M.SHELF_H
 end
 if M.lowWalls(map)then return M.LOW_H end
 return nil
end
-- is this tile key a loose rock (no torches, no veins)?
function M.isLow(map,tile)
 return M.applies(map)and M.ROCK[tile]==true
end

------------------------------------------------------------------ build
local function group()return{verts={},indices={},quads=0}end
-- the stone's palette: a texture of eight texels, picked by u. 1-4 the
-- rocks; 5-8 the switch plate (ring, plate, boss, seam)
M.PALETTE={{.47,.44,.41},{.40,.37,.35},{.55,.52,.48},{.31,.29,.27},
 {.82,.79,.72},{.45,.44,.46},{.90,.88,.82},{.17,.16,.16}}
local NPAL=#M.PALETTE
local function quad(g,a,b,c,d,shade,col)
 local u=((col or 1)-.5)/NPAL
 g.verts[#g.verts+1]={a[1],a[2],a[3],u,.5,shade}
 g.verts[#g.verts+1]={b[1],b[2],b[3],u,.5,shade}
 g.verts[#g.verts+1]={c[1],c[2],c[3],u,.5,shade}
 g.verts[#g.verts+1]={d[1],d[2],d[3],u,.5,shade}
 Voxel3D.pushQuad(g.indices,g.quads);g.quads=g.quads+1
end
local function facing(a,b,d)
 local ux,uy,uz=b[1]-a[1],b[2]-a[2],b[3]-a[3]
 local vx,vy,vz=d[1]-a[1],d[2]-a[2],d[3]-a[3]
 local nx,ny,nz=uy*vz-uz*vy,uz*vx-ux*vz,ux*vy-uy*vx
 local l=sqrt(nx*nx+ny*ny+nz*nz);if l<1e-6 then return nil end
 return abs(ny/l)
end
-- a rounded rock: seven sides, four rings, jittered; its crown a shade lighter
local function lump(g,cx,cy,cz,rx,ry,rz,sd,box)
 local n=7
 local rot=rh(sd,0,71)*pi*2
 local rings={{0,1.0},{.42,1.06},{.78,.74},{1,.22}}
 local pts={}
 for ri,rg in ipairs(rings)do
  pts[ri]={}
  for i=0,n-1 do
   local a=rot+i/n*pi*2+(rh(sd,i+ri*9,73)-.5)*.5
   local k=rg[2]*(.82+rh(sd,i*3+ri,75)*.36)
   local jy=ri>1 and(rh(sd,i,77+ri)-.5)*.14 or -.04
   local x,y,z=cx+cos(a)*rx*k,cy+(rg[1]+jy)*ry,cz+sin(a)*rz*k
   if box then x=min(max(x,box[1]),box[2]);z=min(max(z,box[3]),box[4])end
   pts[ri][i]={x,y,z}
  end
 end
 local function face(a,b,c,d)
  local ny=facing(a,b,d);if not ny then return end
  local sh=.66+.38*ny+(rh(a[1],a[3],79)-.5)*.06
  local p=rh(a[1]+b[3],a[3]+c[1],81)
  local col=ny>.80 and 3 or(p<.22 and 2 or(p>.93 and 4 or 1))
  quad(g,a,b,c,d,sh,col)
 end
 for ri=1,#rings-1 do
  for i=0,n-1 do local j=(i+1)%n
   face(pts[ri][i],pts[ri][j],pts[ri+1][j],pts[ri+1][i])
  end
 end
 local top=pts[#rings];local c=top[0]
 for i=1,n-2 do
  quad(g,c,top[i],top[i+1],top[i+1],1.02,3)
 end
end

local function tileAt(map,tx,ty)
 local ok,t=pcall(map.tileAt,map,tx,ty)
 return ok and t or nil
end
local function walkable(map,cx,cy)
 local ok,r=pcall(map.isWalkableCell,map,cx,cy);return ok and r or false
end

-- the floor switch: $2B $2C over $2D $2E
M.SWITCH={43,44,45,46}
local function switchCell(map,cx,cy)
 for i,t in ipairs(M.SWITCH)do
  if tileAt(map,cx*2+(i-1)%2,cy*2+floor((i-1)/2))~=t then return false end
 end
 return true
end
-- one band of a round plate, from radius r0 at y0 to r1 at y1
local function band(g,x,z,n,r0,y0,r1,y1,shade,col)
 for i=0,n-1 do
  local a0,a1=i/n*pi*2,(i+1)/n*pi*2
  local c0,s0,c1,s1=cos(a0),sin(a0),cos(a1),sin(a1)
  -- lit a touch from the north-west, like the Game Boy button's highlight
  local lit=shade+.05*(-(c0+c1)*.5-(s0+s1)*.5)*.7
  quad(g,{x+c0*r0,y0,z+s0*r0},{x+c1*r0,y0,z+s1*r0},{x+c1*r1,y1,z+s1*r1},{x+c0*r1,y1,z+s0*r1},lit,col)
 end
end
-- the pressure plate, centred on (x,z); its ring stands .8 proud of the floor
M.PLATE={ring=7.0,inner=5.9,plate=5.5,boss=2.4}
local function plate(g,x,z)
 local n=22
 local P=M.PLATE
 band(g,x,z,n,P.ring+.6,-.25,P.ring,.8,.82,5)        -- the ring's outer bevel
 band(g,x,z,n,P.ring,.8,P.inner,.8,1.06,5)            -- the pale ring
 band(g,x,z,n,P.inner,.8,P.plate,.32,.70,8)           -- the dark seam
 band(g,x,z,n,P.plate,.32,P.boss,.42,.96,6)           -- the plate
 band(g,x,z,n,P.boss,.42,P.boss*.72,.92,1.00,7)       -- the boss
 band(g,x,z,n,P.boss*.72,.92,P.boss*.32,1.18,1.06,7)
 band(g,x,z,n,P.boss*.32,1.18,0,1.24,1.10,7)
end

local function build(map)
 local g=group()
 local wc=map.widthCells or((map.def and map.def.width or 0)*2)
 local hc=map.heightCells or((map.def and map.def.height or 0)*2)
 local switches={}
 for cy=0,hc-1 do for cx=0,wc-1 do
  if switchCell(map,cx,cy)then
   switches[#switches+1]={cx=cx,cy=cy,x=cx*16+8,z=cy*16+8}
   plate(g,cx*16+8,cy*16+8)
  end
 end end
 -- how many cells (king's moves) to the nearest switch
 local function switchNear(cx,cy)
  local best=99
  for _,sw in ipairs(switches)do
   best=min(best,max(abs(sw.cx-cx),abs(sw.cy-cy)))
  end
  return best
 end
 local function rockCell(cx,cy)
  if cx<0 or cy<0 or cx>=wc or cy>=hc then return false end
  if walkable(map,cx,cy)then return false end
  local n=0
  for dy=0,1 do for dx=0,1 do if M.ROCK[tileAt(map,cx*2+dx,cy*2+dy)or -1]then n=n+1 end end end
  return n>=3
 end
 for cy=0,hc-1 do for cx=0,wc-1 do
  if rockCell(cx,cy)then
   local sd=cx*131+cy*71
   local x0,z0=cx*16,cy*16
   -- how far a rock may spread: well into a rock neighbour, only to the
   -- cell's own edge over open floor (the paths stay exactly as wide)
   local function m(dx,dy)return rockCell(cx+dx,cy+dy)and 5 or 0 end
   local box={x0-m(-1,0),x0+16+m(1,0),z0-m(0,-1),z0+16+m(0,1)}
   local r=7.6+rh(sd,1,81)*1.8
   local hgt=12+rh(sd,2,83)*7
   -- TEST192: beside a switch the rocks stay knee high, a step further
   -- waist high, so the plate shows from every side of its pocket
   local near=switchNear(cx,cy)
   local lowK=near<=1 and .48 or(near==2 and .72 or 1)
   hgt=hgt*lowK
   local ox,oz=(rh(sd,3,85)-.5)*4,(rh(sd,4,87)-.5)*4
   lump(g,x0+8+ox,-.5,z0+8+oz,r,hgt,r*(.86+rh(sd,5,89)*.24),sd,box)
   -- one or two more at its foot, toward the cell's open corners
   for k=1,1+floor(rh(sd,6,91)*2)do
    local a=rh(sd,k,93)*pi*2
    local d=6.0+rh(k,sd,95)*2.5
    local rr=4.0+rh(sd,k,97)*2.6
    lump(g,x0+8-ox*.5+cos(a)*d,-.4,z0+8-oz*.5+sin(a)*d,rr,rr*(1.1+rh(k,sd,99)*.6)*max(lowK,.7),rr*(.9+rh(sd,k,98)*.2),sd+k*17,box)
   end
  end
 end end
 if g.quads==0 then return false end
 return{mesh=Voxel3D.newMesh(g.verts,g.indices),quads=g.quads,switches=switches}
end

------------------------------------------------------------------ draw
local whiteTex
local function white()
 if not whiteTex then
  local ok,img=pcall(function()
   local d=love.image.newImageData(NPAL,1)
   for i,c in ipairs(M.PALETTE)do d:setPixel(i-1,0,c[1],c[2],c[3],1)end
   local im=love.graphics.newImage(d);im:setFilter("nearest","nearest");return im
  end)
  whiteTex=ok and img or nil
 end
 return whiteTex
end
local function slotFor(map)
 local s=cache[map]
 if s==nil then
  local ok,r=pcall(build,map)
  if not ok then
   if V.mod and V.mod.log and V.mod.log.info then pcall(V.mod.log.info,V.mod.log,'Cave rubble failed: %s',tostring(r))end
   r=false
  end
  s=r or false;cache[map]=s
 end
 return s or nil
end
-- is a Strength boulder resting on this cell?
local function boulderOn(state,cx,cy)
 local npcs=type(state)=='table'and state.npcs
 if type(npcs)~='table'then return false end
 for _,n in ipairs(npcs)do
  if type(n)=='table'and n.cellX==cx and n.cellY==cy and not n.moving then
   local d=n.def
   if type(d)=='table'and(d.sprite=='SPRITE_BOULDER'or d.id=='SPRITE_BOULDER')then return true end
  end
 end
 return false
end
M.boulderOn=boulderOn
-- the light round each switch: a cool pulse while it waits, steady green
-- once a boulder holds it down
local function drawSwitchLight(s,state)
 if not(s.switches and s.switches[1])then return end
 local okK,K=pcall(function()return V.require('LeagueRoad').fxKit()end)
 if not(okK and K and K.quad and K.ring and K.soft)then return end
 local okT,t=pcall(love.timer.getTime);t=okT and t or 0
 local g=love.graphics
 pcall(Voxel3D.withEffect,"add",function()
  for i,sw in ipairs(s.switches)do
   local held=boulderOn(state,sw.cx,sw.cy)
   local TR=Mat4.translate
   if held then
    g.setColor(.42,1.0,.50,.30)
    Voxel3D.draw(K.quad,K.ring,Mat4.mul(TR(sw.x,.9,sw.z),Mat4.scale(9.4,1,9.4)))
    g.setColor(.30,.85,.40,.10)
    Voxel3D.draw(K.quad,K.soft,Mat4.mul(TR(sw.x,.3,sw.z),Mat4.scale(14,1,14)))
   else
    local p=.5+.5*sin(t*2.6+i*1.3)
    g.setColor(.40,.80,1.0,.22+.30*p)
    Voxel3D.draw(K.quad,K.ring,Mat4.mul(TR(sw.x,.9,sw.z),Mat4.scale(7.6,1,7.6)))
    -- a second ring spreading out from it, so it reads from across the cave
    local u=(t*.55+i*.37)%1
    g.setColor(.40,.80,1.0,.30*(1-u))
    local r=7.6+u*9
    Voxel3D.draw(K.quad,K.ring,Mat4.mul(TR(sw.x,.6,sw.z),Mat4.scale(r,1,r)))
    g.setColor(.35,.70,1.0,.08+.06*p)
    Voxel3D.draw(K.quad,K.soft,Mat4.mul(TR(sw.x,.3,sw.z),Mat4.scale(13,1,13)))
    -- motes of light rising off it, seen over the rocks round its pocket
    if K.cross then
     for k=0,5 do
      local v=(t*.32+k/6+i*.11)%1
      local a=k*2.1+i
      local rr=2.5+2.5*rh(k,i,7)
      local y=1+v*24
      local s=1.1+.9*(1-v)
      g.setColor(.45,.85,1.0,.55*sin(v*pi))
      Voxel3D.draw(K.cross,K.soft,Mat4.mul(TR(sw.x+cos(a+v*1.4)*rr,y,sw.z+sin(a+v*1.4)*rr),Mat4.scale(s,s,s)))
     end
    end
   end
  end
 end)
 g.setColor(1,1,1,1)
end
function M.drawMap(map,state)
 if not M.applies(map)then return false end
 local s=slotFor(map);if not(s and s.mesh)then return false end
 local tex=white();if not tex then return false end
 local g=love.graphics
 local pushed=pcall(g.push,"all")
 pcall(function()
  g.setDepthMode("lequal",true);g.setBlendMode("alpha");g.setColor(1,1,1,1)
  Voxel3D.lighting(true)
  Voxel3D.draw(s.mesh,tex)
 end)
 if pushed then pcall(g.pop)end
 pcall(drawSwitchLight,s,state)
 return true
end
function M.draw(state)
 return M.drawMap(state and state.map,state)
end
M.build=build
function M.invalidate()
 for _,s in pairs(cache)do if s and s.mesh and s.mesh.release then pcall(s.mesh.release,s.mesh)end end
 cache=setmetatable({},{__mode='k'})
 if whiteTex and whiteTex.release then pcall(whiteTex.release,whiteTex)end
 whiteTex=nil
end
Assets.register(M.invalidate)
return M
