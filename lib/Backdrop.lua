-- The BACKDROP: a distant horizon for the outdoor world.
-- payload-version: 9
--
-- Dramatic Shape's outdoor maps end where their meshes end -- past the
-- last connected map is sky meeting nothing.  This hangs a painted
-- panorama around the world at a great radius: hills, forest, mountains,
-- a lighthouse headland and a walled town, wrapped 360 degrees and
-- centred on the player, so it reads as distance rather than as scenery.
--
-- Centred on the player is the whole trick.  A cylinder that follows you
-- never gets closer, which is exactly how a horizon behaves: it turns
-- with the camera and refuses to be approached.  A slow drift of the
-- texture against world position adds the last touch -- walk east far
-- enough and the mountains slide across the sky -- without ever letting
-- the player reach them.
--
-- Drawn after the sky and before the terrain, with depth writes off, so
-- every piece of real world draws over it and it never occludes anything.
-- Interiors and canopy maps skip it: the ceiling module owns those.

local V = ...

local Voxel3D = V.require("Voxel3D")
local Mat4 = V.require("Mat4")
local okDN, DayNight = pcall(V.require, "DayNight")
local CommunityVisuals = V.require("CommunityVisuals")

local Backdrop = {}
local Scenic = V.require("ScenicLandscape")
local imagePath
local lastReport

local function backdropPath()
  return rawget(_G, "__ds_backdrop_path")
         or ((V.path or "mods/BATTLE_ART_VOXEL_FORK") .. "/assets/legendary/backdrop.png")
end

-- TEST130: detailed painted mountains/woodland and a continuous meadow.
-- Same world radius and regional yaw; twice the cylinder segments smooths
-- camera turns while the real maps keep complete depth/collision ownership.
local RADIUS = 760
local SEGMENTS = 64
local Y_BOTTOM = -1       -- the illustration's foot meets the world's
                          -- ground plane (community request): painted
                          -- ranges stand ON the ground instead of
                          -- sinking past it
-- TEST389 replaces the old vertical deep skirt with one horizontal ground
-- disc at this same height. The old skirt was the large flat blue-grey band;
-- recolouring the panorama in TEST388 merely made that wall green. A ground
-- plane recedes toward the painted hills instead of standing upright beneath
-- them, while the real map (drawn later) still owns every playable surface.
local GROUND_TEXTURE_SIZE = 96
local GROUND_TEXTURE_SPAN = 128
local Y_TOP = 230         -- tighter distant band; sky remains dominant
local DRIFT = 1 / 24000   -- texture drift per world pixel walked

-- TEST119: CERULEAN REGIONAL HORIZON v1
-- Promote TEST118's successful location-aware rotation probe into a small
-- authored regional composition.  The panorama, radius, segment budget and
-- draw path remain IDENTICAL: this only changes which part of the existing
-- cheap 360-degree painting faces each connected Cerulean-area map.
--
-- Cerulean itself keeps the proven TEST118 composition.  The surrounding
-- routes get restrained offsets so the same landmarks do not sit in the same
-- screen direction everywhere.  This creates the illusion that the player is
-- moving around one larger basin while preserving TEST117/118 performance.
-- No ChunkMesher changes. No new geometry. No extra draw calls.
local REGION_YAW = {
  CERULEANCITY = math.rad(12), -- locked TEST118 hero composition
  ROUTE4       = math.rad(4),  -- west approach: subtly shift the range
  ROUTE5       = math.rad(20), -- south exit: rotate landmarks away
  ROUTE24      = math.rad(-6), -- north bridge: open a different horizon face
  ROUTE25      = math.rad(-16),-- northeast route: continue the regional turn
}

local function mapKey(map)
  if not map then return "" end
  local id = map.id or (map.def and (map.def.id or map.def.name)) or ""
  return tostring(id):upper():gsub("[^A-Z0-9]", "")
end

local function regionYaw(map)
  local key = mapKey(map)
  local yaw = REGION_YAW[key]
  if yaw then return yaw, key end
  -- Be tolerant of engine prefixes/suffixes in private/recompiled map ids.
  if key:find("CERULEAN", 1, true) then return math.rad(12), key end
  if key:find("ROUTE4", 1, true) then return math.rad(4), key end
  if key:find("ROUTE5", 1, true) then return math.rad(20), key end
  if key:find("ROUTE24", 1, true) then return math.rad(-6), key end
  if key:find("ROUTE25", 1, true) then return math.rad(-16), key end
  return 0, key
end

local mesh, image, failed = nil, nil, false
local meshPacked
local underMesh, whiteImg, groundImg = nil, nil, nil
local groundColor = { 0.62, 0.60, 0.48 }   -- until the art is read

local function white()
  if whiteImg ~= nil then return whiteImg or nil end
  local ok, img = pcall(function()
    local d = love.image.newImageData(1, 1)
    d:setPixel(0, 0, 1, 1, 1, 1)
    local i = love.graphics.newImage(d)
    i:setFilter("nearest", "nearest")
    return i
  end)
  whiteImg = (ok and img) or false
  return whiteImg or nil
end

-- A tiny deterministic field texture built once in memory. It only uses
-- colours already present in TEST388's 61-colour panorama and repeats across
-- the distant ground plane. TEST390 widens the repeat, narrows the colour
-- range and removes the regular horizontal hedge rows visible in TEST389.
-- Staggered parcels, occasional broken side boundaries and very sparse dither
-- keep the land readable without creating bands or competing with HD grass.
local function groundTexture()
  local detailed=Scenic.meadow()
  if detailed then return detailed end
  if groundImg ~= nil then return groundImg or nil end
  local ok, img = pcall(function()
    local n = GROUND_TEXTURE_SIZE
    local data = love.image.newImageData(n, n)
    local fields = {
      { 109 / 255, 141 / 255, 75 / 255 },
      { 126 / 255, 151 / 255, 107 / 255 },
      { 135 / 255, 152 / 255, 116 / 255 },
      { 139 / 255, 164 / 255, 98 / 255 },
    }
    local hedge = { 99 / 255, 129 / 255, 72 / 255 }
    for z = 0, n - 1 do
      local row = math.floor(z / 16)
      for x = 0, n - 1 do
        local parcel = math.floor((x + row * 7) / 24)
        local idx = ((parcel * 3 + row * 5 + (parcel + row) % 2)
                     % #fields) + 1
        local c = fields[idx]
        local seam = (x + row * 7) % 31 == 0
                     and (z + parcel * 3) % 9 > 2
        if seam then
          c = hedge
        elseif (x * 7 + z * 11) % 37 == 0 then
          c = fields[(idx % #fields) + 1]
        end
        data:setPixel(x, z, c[1], c[2], c[3], 1)
      end
    end
    local tex = love.graphics.newImage(data)
    tex:setWrap("repeat", "repeat")
    tex:setFilter("nearest", "nearest")
    data:release()
    return tex
  end)
  groundImg = (ok and img) or false
  return groundImg or nil
end

local function status(s) _G.__ds_backdrop_status = s end
status("loaded; awaiting the first outdoor frame")

-- interiors and canopy maps belong to the ceiling, not the horizon

-- Draw blocks run inside this rather than a bare pcall.  Every one of
-- them changes graphics state -- colour, alpha, depth mode -- and a bare
-- pcall that throws midway leaves that state set for the REST OF THE
-- FRAME.  Anything drawn after us then inherits it: a stray alpha makes
-- another mod's sprites invisible, a stray depth mode makes them sort
-- wrongly, and the fault looks like theirs.  push("all")/pop() restores
-- the lot whatever happens inside.
local function guarded(fn)
  -- headless, or a driver without a graphics stack: just run it
  local g = love and love.graphics
  if not (g and g.push and g.pop) then return pcall(fn) end
  local pushed = pcall(g.push, "all")
  local ok,err=pcall(fn)
  if pushed then pcall(g.pop) end
  return ok,err
end

local OPEN_AIR_TILESETS = {
  OVERWORLD = true, FOREST = true, PLATEAU = true, SHIP_PORT = true,
}

local function isOutdoor(map)
  local def = map and map.def
  if not def then return false end
  if okDN and DayNight and DayNight.isCanopy then
    local okC, canopy = pcall(DayNight.isCanopy, map)
    if okC and canopy then return false end
  end
  local tid = def.tileset or (map.tileset and map.tileset.id)
  if tid and OPEN_AIR_TILESETS[tid] then return true end
  local ok, outdoor = pcall(function()
    local Map = require("src.world.Map")
    return Map.isOutdoor and Map.isOutdoor(def)
  end)
  if ok and outdoor ~= nil then return outdoor end
  local conns = def.connections
  return (conns and next(conns) ~= nil) and true or false
end

-- the cylinder, built once: a ring of quads facing inward, uv running
-- once around the circumference
local function build(packed)
  local verts, indexMap, quads = {}, {}, 0
  for i = 0, SEGMENTS - 1 do
    local a0 = (i / SEGMENTS) * math.pi * 2
    local a1 = ((i + 1) / SEGMENTS) * math.pi * 2
    local x0, z0 = math.cos(a0) * RADIUS, math.sin(a0) * RADIUS
    local x1, z1 = math.cos(a1) * RADIUS, math.sin(a1) * RADIUS
    local u0, u1 = i / SEGMENTS, (i + 1) / SEGMENTS
    -- TEST132: four atlas sectors preserve the same world cylinder/triangles.
    -- External panorama overrides and the legacy fallback retain original UVs.
    local a,b,c,d,e,f,g,h=u1,0,u0,0,u0,1,u1,1
    if packed then
      local perSector=SEGMENTS/4
      local sector=math.floor(i/perSector)
      local left=(i%perSector)/perSector
      local right=((i%perSector)+1)/perSector
      a,b=Scenic.uv(sector,right,0);c,d=Scenic.uv(sector,left,0)
      e,f=Scenic.uv(sector,left,1);g,h=Scenic.uv(sector,right,1)
    end
    -- wound so the painted face looks INWARD at the player
    verts[#verts + 1] = { x1, Y_TOP, z1, a, b, 1 }
    verts[#verts + 1] = { x0, Y_TOP, z0, c, d, 1 }
    verts[#verts + 1] = { x0, Y_BOTTOM, z0, e, f, 1 }
    verts[#verts + 1] = { x1, Y_BOTTOM, z1, g, h, 1 }
    Voxel3D.pushQuad(indexMap, quads)
    quads = quads + 1
  end
  return Voxel3D.newMesh(verts, indexMap)
end

-- One horizontal disc from the player to the panorama. It replaces the old
-- vertical cylinder/deep floor pair without adding a mesh or draw call. UVs
-- are proportional to local XZ, so the generated field texture lies across
-- the surface instead of stretching down it.
local function buildUnder()
  local verts,indices={},{}
  local radii={0,64,128,224,320,432,544,656,RADIUS}
  for _,radius in ipairs(radii)do
    for i=0,SEGMENTS do
      local angle=i/SEGMENTS*math.pi*2
      local x,z=math.cos(angle)*radius,math.sin(angle)*radius
      local strength=math.min(1,radius/320)*math.sin(math.pi*radius/RADIUS)
      local height=Y_BOTTOM-strength*(1.5+1.5*math.sin(x/92)*math.cos(z/117))
      verts[#verts+1]={x,height,z,x/GROUND_TEXTURE_SPAN,z/GROUND_TEXTURE_SPAN,1}
    end
  end
  local stride=SEGMENTS+1
  for row=0,#radii-2 do for col=0,SEGMENTS-1 do
    local a=row*stride+col+1
    local tri=row==0 and{a+1,a+stride,a+stride+1}or{a,a+stride,a+1,a+1,a+stride,a+stride+1}
    for _,index in ipairs(tri)do indices[#indices+1]=index end
  end end
  return Voxel3D.newMesh(verts,indices)
end

-- the panorama itself, written next to this module by the companion mod
-- HORIZON TEST1: repair accidentally transparent painted palette colours.
-- Only the shipped artwork is repaired; keyed sky/fringe and RGB are preserved.
local SOLID_PALETTE = {
  [11777419] = true,
  [7047855] = true,
  [6652070] = true,
  [10327690] = true,
  [14800531] = true,
  [4089509] = true,
  [4808801] = true,
  [3889249] = true,
  [2308667] = true,
  [3230281] = true,
  [11912337] = true,
}
local function restorePaintedAlpha(x, y, r, g, b, a)
  if a < 0.5 then
    local key = math.floor(r * 255 + 0.5) * 65536
              + math.floor(g * 255 + 0.5) * 256
              + math.floor(b * 255 + 0.5)
    if SOLID_PALETTE[key] then return r, g, b, 1 end
  end
  return r, g, b, a
end

local function texture()
  local wanted=backdropPath()
  if imagePath~=wanted then
    if image and image.release then image:release()end
    image=nil;failed=false;imagePath=wanted
  end
  local builtin=(V.path or "mods/BATTLE_ART_VOXEL_FORK").."/assets/legendary/backdrop.png"
  if backdropPath()==builtin then
    local detailed=Scenic.panorama()
    if detailed then return detailed,true end
  end
  if image or failed then return image end
  local ok, img = pcall(function()
    local path = backdropPath()
    local data = love.image.newImageData(path)
    local builtin = (V.path or "mods/BATTLE_ART_VOXEL_FORK") .. "/assets/legendary/backdrop.png"
    if path == builtin and data:getWidth() == 4096 and data:getHeight() == 256 then
      data:mapPixel(restorePaintedAlpha)
    end
    -- THE GROUND COLOUR, read once from the art itself: the average of
    -- the panorama's bottom row is the colour its land ends in, and the
    -- skirt and floor are painted in that single flat tone. Stretching
    -- the bottom ROW downward smeared every colour in it -- trees,
    -- fields, shore -- into vertical taffy; a plain of one colour reads
    -- as distant ground.
    pcall(function()
      local w, h = data:getWidth(), data:getHeight()
      local r, g, b, n = 0, 0, 0, 0
      for x = 0, w - 1, 8 do
        local pr, pg, pb, pa = data:getPixel(x, h - 1)
        if pa > 0.5 then r, g, b, n = r + pr, g + pg, b + pb, n + 1 end
      end
      if n > 0 then
        groundColor = { r / n, g / n, b / n }
      end
    end)
    local i = love.graphics.newImage(data)
    data:release()
    i:setWrap("repeat", "clamp")
    i:setFilter("nearest", "nearest")
    return i
  end)
  if ok and img then
    image = img
  else
    failed = true
    status("backdrop.png missing or unreadable")
  end
  return image
end

-- If the companion mod has been deleted, its config bridge is gone and
-- this module is an orphan: draw nothing. The ceiling module does the
-- actual clean-up; this just keeps quiet in the meantime.
local function abandoned()
  return not CommunityVisuals.customSky()
end

function Backdrop.draw(state)
  if abandoned() then return end
  local cfg = { backdrop = true }
  if cfg.backdrop == false then
    status("backdrop switched off")
    return
  end

  local map = state and state.map
  if not map then return end
  if not isOutdoor(map) then
    status("indoors -- the ceiling owns this map")
    return
  end

  local tex,packed = texture()
  if not tex then return end
  packed=not not packed
  if not mesh or meshPacked~=packed then
    if mesh and mesh.release then pcall(mesh.release,mesh)end
    mesh = build(packed)
    meshPacked=packed
    if not mesh then
      failed = true
      status("driver refused the backdrop mesh")
      return
    end
  end

  local p = state.player
  local px = (p and p.px) or 0
  local pz = (p and p.py) or 0

  -- drift: the horizon slides slowly against the world, so walking a long
  -- way east moves the mountains, but never brings them closer
  local okShift = pcall(function()
    tex:setWrap(packed and "clamp" or "repeat", "clamp")
  end)

  -- TEST20: cool distant scenery at night, smoothly following the clock.
  -- Only the Legendary city-ground presentation; no clock/arena changes.
  local nr,ng,nb=1,1,1
  if CommunityVisuals.customCityGround() and okDN and DayNight then
    local phase=DayNight.mix(DayNight.time())
    local night=(phase.night or 0)+(phase.violet or 0)*.35
    nr,ng,nb=1-.32*night,1-.27*night,1-.16*night
  end
  local drew = guarded(function()
    -- behind everything: test against depth but never write to it, so no
    -- real geometry can ever be occluded by the painting
    love.graphics.setDepthMode("lequal", false)
    -- the distant ground first, so the painted panorama draws over its rim
    underMesh = underMesh or buildUnder()
    local ground = V.require('SafariReserve').enabled(map)
      and V.require('SafariMaterials').distantGround() or groundTexture()
    local fallback = ground == nil
    ground = ground or white()
    if underMesh and ground then
      if fallback then
        love.graphics.setColor(groundColor[1]*nr, groundColor[2]*ng,
                               groundColor[3]*nb, 1)
      else
        love.graphics.setColor(nr, ng, nb, 1)
      end
      Voxel3D.draw(underMesh, ground, Mat4.translate(px, 0, pz))
      love.graphics.setColor(nr, ng, nb, 1)
    end
    local yaw, key = regionYaw(map)
    local model = Mat4.mul(Mat4.translate(px, 0, pz), Mat4.rotateY(yaw))
    Voxel3D.draw(mesh, tex, model)
  end)
  if drew then
    -- Report once per selected material (also available in the existing status
    -- bridge). This distinguishes an old active module, custom override, or a
    -- failed atlas allocation without adding anything to the gameplay view.
    local builtin=(V.path or "mods/BATTLE_ART_VOXEL_FORK").."/assets/legendary/backdrop.png"
    local material=packed and (Scenic.panoramaStatus or "four-sector atlas")
      or (imagePath~=builtin and ("external panorama: "..tostring(imagePath))
          or ("legacy fallback; "..tostring(Scenic.panoramaStatus)))
    local report="Legendary TEST134 backdrop: "..material
    if report~=lastReport then
      lastReport=report
      if V.mod and V.mod.log and V.mod.log.info then
        pcall(V.mod.log.info,V.mod.log,report)
      end
    end
    local yaw, key = regionYaw(map)
    status(report..("; drawn at r=%d, region=%s, yaw=%.1fdeg"):format(
      RADIUS, key ~= "" and key or "UNKNOWN", math.deg(yaw)))
  else
    status("draw failed")
  end
end

function Backdrop.invalidate()
  Scenic.invalidate()
  failed=false;lastReport=nil
  if mesh then pcall(mesh.release, mesh) end
  mesh = nil;meshPacked=nil
  if underMesh then pcall(underMesh.release, underMesh) end
  underMesh = nil
  if groundImg and groundImg.release then pcall(groundImg.release, groundImg) end
  groundImg = nil
end

-- live registration: the installer hot-swaps refreshed modules
-- into the running session through this table, killing the
-- boot-twice ritual (see main.lua, hotSwap)
_G.__ds_live = rawget(_G, "__ds_live") or {}
_G.__ds_live.Backdrop = Backdrop
_G.__ds_live.V = _G.__ds_live.V or V

return Backdrop
