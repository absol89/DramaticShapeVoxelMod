-- TEST205/206: CERULEAN STONE, the shading that grounds the cave's rock.
-- (TEST205 also wrapped the walls in a slate skin; the engine's own faceted
-- cave rock stands further out than any skin can without narrowing the
-- paths, so TEST206 instead gives that rock Cerulean's slate finish in
-- ChunkMesher and CavePerimeter, and this module keeps only the floor work.)
--
--   * WALL FEET are shaded on the floor in front of every wall and every
--     shelf riser, which seats the rock on the ground and makes the paths
--     easier to read;
--   * SHORES get a damp dark band on the land side;
--   * and a faint lapping glow on the water side (drawn after the water).
--
-- Presentation only: collision, warps, encounters and tiles are untouched.
local V=...
local Assets=require("src.render.Assets")
local Voxel3D=V.require("Voxel3D")

local M={REVISION='cerulean-stone-206'}
local floor,min,sin=math.floor,math.min,math.sin
local cache=setmetatable({},{__mode='k'})
local fadeTex

-- a soft falloff: opaque at v=0, nothing at v=1
local function fade()
 if fadeTex==nil then
  local ok,img=pcall(function()
   local d=love.image.newImageData(4,32)
   for y=0,31 do
    local v=(y+.5)/32;local a=(1-v)^2.2
    for x=0,3 do d:setPixel(x,y,1,1,1,a)end
   end
   local im=love.graphics.newImage(d,{mipmaps=false});im:setFilter("linear","linear");im:setWrap("clamp","clamp")
   d:release();return im
  end)
  fadeTex=ok and img or false
 end
 return fadeTex or nil
end

local function group()return{verts={},indices={},quads=0}end
local function strip(g,a,b,c,d)
 g.verts[#g.verts+1]={a[1],a[2],a[3],.5,0,1}
 g.verts[#g.verts+1]={b[1],b[2],b[3],.5,0,1}
 g.verts[#g.verts+1]={c[1],c[2],c[3],.5,1,1}
 g.verts[#g.verts+1]={d[1],d[2],d[3],.5,1,1}
 Voxel3D.pushQuad(g.indices,g.quads);g.quads=g.quads+1
end
local function mesh(g)if g.quads==0 then return nil end;return Voxel3D.newMesh(g.verts,g.indices)end

local function floorAt(map,cx,cy)
 local ok,h=pcall(V.require("VoxelScene").groundAt,map,cx,cy,cx*16,cy*16)
 return(ok and tonumber(h))or 0
end
local WATER_Y=0      -- TEST207: cave water is ground, at the floor plane

-- The cave's cells: 'wall', 'shelf' (the lit floor, 6 up), 'floor',
-- 'water', 'stair', 'warp' or nil (off the map)
local function classify(map)
 local wc,hc=map.widthCells or 0,map.heightCells or 0
 local okS,shapes=pcall(function()return V.require("TileShape").forMap(map)end)
 if not okS then shapes=nil end
 local warps={}
 for _,w in ipairs((map.def and map.def.warps)or map.warps or{})do
  if w.x and w.y then warps[w.y*4096+w.x]=true end
 end
 local cls,hgt={},{}
 for cy=0,hc-1 do for cx=0,wc-1 do
  local k=cy*4096+cx
  local okW,w=pcall(map.isWalkableCell,map,cx,cy);w=okW and w
  local q=false
  if map.isWaterCell then local okQ,r=pcall(map.isWaterCell,map,cx,cy);q=okQ and r end
  local c,h
  if q then c,h='water',WATER_Y
  elseif not w then c,h='wall',0
  else
   c,h='floor',floorAt(map,cx,cy)
   if warps[k]then c='warp'
   elseif shapes and map.tileAt then
    local stair,shelf=false,0
    for oy=0,1 do for ox=0,1 do
     local okT,t=pcall(map.tileAt,map,cx*2+ox,cy*2+oy)
     if okT then
      if t==21 or t==22 then stair=true end
      local sh=shapes[t]
      if sh and sh.class=="ledge" and(t==5 or t==41)then shelf=shelf+1 end
     end
    end end
    if stair then c='stair' elseif shelf==4 then c='shelf' end
   end
  end
  cls[k],hgt[k]=c,h
 end end
 return cls,hgt
end
M.classify=classify

local DIRS={{1,0},{-1,0},{0,1},{0,-1}}
local function edge(cx,cy,dx,dz)
 local x0,z0=cx*16,cy*16
 if dx==1 then return x0+16,z0,x0+16,z0+16
 elseif dx==-1 then return x0,z0+16,x0,z0
 elseif dz==1 then return x0+16,z0+16,x0,z0+16 end
 return x0,z0,x0+16,z0
end

local function build(map)
 local wc,hc=map.widthCells or 0,map.heightCells or 0
 local cls,hgt=classify(map)
 local function C(cx,cy)if cx<0 or cy<0 or cx>=wc or cy>=hc then return nil end;return cls[cy*4096+cx]end
 local function H(cx,cy)return hgt[cy*4096+cx]end
 local feet,damp,shore=group(),group(),group()
 for cy=0,hc-1 do for cx=0,wc-1 do
  local c=C(cx,cy)
  for _,d in ipairs(DIRS)do
   local dx,dz=d[1],d[2]
   local nb=C(cx+dx,cy+dz)
   local ax,az,bx,bz=edge(cx,cy,dx,dz)
   -- the shade at the foot of a wall, or of a shelf's riser, on the
   -- lower floor in front of it
   local riser=(c=='wall')or(c=='shelf' and nb=='floor' and H(cx,cy)-H(cx+dx,cy+dz)>=2)
   if riser and(nb=='floor' or nb=='shelf' or nb=='stair')and not(c=='shelf' and nb=='shelf')then
    local fy=H(cx+dx,cy+dz)+.22
    local w=c=='wall' and 8 or 6
    strip(feet,{ax+dx*.2,fy,az+dz*.2},{bx+dx*.2,fy,bz+dz*.2},{bx+dx*w,fy,bz+dz*w},{ax+dx*w,fy,az+dz*w})
   end
   -- the shore
   if(c=='floor' or c=='shelf')and nb=='water' then
    local fy=H(cx,cy)+.20
    strip(damp,{ax,fy,az},{bx,fy,bz},{bx-dx*5,fy,bz-dz*5},{ax-dx*5,fy,az-dz*5})
    local wy=WATER_Y+.26
    strip(shore,{ax,wy,az},{bx,wy,bz},{bx+dx*4.5,wy,bz+dz*4.5},{ax+dx*4.5,wy,az+dz*4.5})
   end
  end
 end end
 return{feet=mesh(feet),damp=mesh(damp),shore=mesh(shore)}
end

local function release(s)
 if not s then return end
 for _,m in ipairs({s.feet,s.damp,s.shore})do if m and m.release then pcall(m.release,m)end end
end
local function applies(map)
 local ok,r=pcall(function()return V.require("CeruleanDepths").applies(map)end)
 return ok and r or false
end
local function detail()
 local ok,d=pcall(function()return V.require("CommunityVisuals").caveDetailLevel()end)
 return ok and d or"full"
end
function M.slotFor(map)
 if not(map and applies(map))or detail()=="off" then return nil end
 local s=cache[map]
 if s==nil then
  local ok,r=pcall(build,map)
  if not ok then
   if V.mod and V.mod.log and V.mod.log.info then pcall(V.mod.log.info,V.mod.log,'Cerulean stone failed: %s',tostring(r))end
   r=false
  end
  s=r or false;cache[map]=s
 end
 return s or nil
end

-- the water's lapping edge (after the water pass: see CeruleanDepths)
function M.drawLight(map,glow)
 local s=M.slotFor(map)
 if not(s and s.shore and glow)then return false end
 local ft=fade()
 if not ft then return false end
 local g=love.graphics
 local t=0;pcall(function()t=love.timer.getTime()end)
 pcall(Voxel3D.withEffect,"add",function()
  g.setColor(glow[1],glow[2],glow[3],.16+.08*sin(t*1.1))
  Voxel3D.draw(s.shore,ft)
 end)
 pcall(g.setColor,1,1,1,1)
 return true
end
-- the floor shading: wall feet and damp shores (alpha, no depth write),
-- drawn after the cave floor so it lies on top of it
function M.drawFloor(map)
 local s=M.slotFor(map)
 if not s then return false end
 local ft=fade()
 if not ft then return false end
 local g=love.graphics
 pcall(Voxel3D.withEffect,"alpha",function()
  if s.feet then g.setColor(.02,.02,.05,.50);Voxel3D.draw(s.feet,ft)end
  if s.damp then g.setColor(.01,.02,.04,.34);Voxel3D.draw(s.damp,ft)end
 end)
 pcall(g.setColor,1,1,1,1)
 return true
end

function M.invalidate()
 for _,s in pairs(cache)do release(s)end
 cache=setmetatable({},{__mode='k'})
 if fadeTex and fadeTex.release then pcall(fadeTex.release,fadeTex)end
 fadeTex=nil
end
Assets.register(M.invalidate)
return M
