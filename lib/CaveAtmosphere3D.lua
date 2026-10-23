-- TEST97: solid cave walls with organic water, drifting 3D motes and a
-- high-vaulted cave ceiling whose attached clusters share its visibility.
--
-- The approved TEST72 walls and dirt remain the terrain authority. This
-- module only adds cached dressing over them: shallow wet relief, sparse
-- edge pools, natural wall-foot formations and shared low-poly water meshes.
-- Droplets are analytic rather than allocated every frame; each anchor reuses
-- the same mesh and clock, which keeps the effect bounded on mobile hardware.

local V = ...

local Assets = require("src.render.Assets")
local Mat4 = V.require("Mat4")
local Voxel3D = V.require("Voxel3D")
local VoxelState = V.require("VoxelState")
local Structures = V.require("Structures")
local CommunityVisuals = V.require("CommunityVisuals")
local CaveSconces = V.require("CaveSconces")

local CaveAtmosphere3D = {}

local cache = setmetatable({}, { __mode = "k" })
local whiteImg, dropMesh, ringMesh, moteMesh = nil, nil, nil, nil

local function keyOf(tx, ty)
  return (ty + 64) * 4096 + (tx + 64)
end

local function hash01(x, z, salt)
  local n = (x * 73856093 + z * 19349663 + salt * 83492791) % 104729
  if n < 0 then n = n + 104729 end
  return n / 104729
end

local function isCave(map)
  local tid = map and tostring((map.def and map.def.tileset)
              or (map.tileset and map.tileset.id) or "") or ""
  return tid == "CAVERN" and CommunityVisuals.customCaves()
end

-- Surf camera clearance below both the roof and its longest hanging tooth.
-- The lowest possible tooth is 66 - 3.25 - 1.2 - 1.4 - 18.5 = 41.65.
-- Leave more than the boom's five-pixel collision pad below that geometry.
-- SUBTLE/OFF and the original cave style do not draw this canopy.
function CaveAtmosphere3D.cameraCeiling(map)
  if isCave(map) and CommunityVisuals.caveDetailLevel() == "full" then
    return 36
  end
end

local function white()
  if whiteImg then return whiteImg end
  local ok, img = pcall(function()
    local data = love.image.newImageData(2, 2)
    for y = 0, 1 do
      for x = 0, 1 do data:setPixel(x, y, 1, 1, 1, 1) end
    end
    local made = love.graphics.newImage(data)
    made:setFilter("nearest", "nearest")
    return made
  end)
  if ok then whiteImg = img end
  return whiteImg
end

local function group()
  return { verts = {}, indices = {}, quads = 0 }
end

local function quad(g, a, b, c, d, shade)
  local s = shade or 1
  g.verts[#g.verts + 1] = { a[1], a[2], a[3], 0, 0, s }
  g.verts[#g.verts + 1] = { b[1], b[2], b[3], 1, 0, s }
  g.verts[#g.verts + 1] = { c[1], c[2], c[3], 1, 1, s }
  g.verts[#g.verts + 1] = { d[1], d[2], d[3], 0, 1, s }
  Voxel3D.pushQuad(g.indices, g.quads)
  g.quads = g.quads + 1
end

local function box(g, x0, y0, z0, x1, y1, z1)
  quad(g, {x1,y0,z0}, {x1,y0,z1}, {x1,y1,z1}, {x1,y1,z0}, 0.86)
  quad(g, {x0,y0,z1}, {x0,y0,z0}, {x0,y1,z0}, {x0,y1,z1}, 0.66)
  quad(g, {x0,y1,z0}, {x1,y1,z0}, {x1,y1,z1}, {x0,y1,z1}, 1.04)
  quad(g, {x0,y0,z1}, {x1,y0,z1}, {x1,y0,z0}, {x0,y0,z0}, 0.54)
  quad(g, {x0,y0,z1}, {x1,y0,z1}, {x1,y1,z1}, {x0,y1,z1}, 0.92)
  quad(g, {x1,y0,z0}, {x0,y0,z0}, {x0,y1,z0}, {x1,y1,z0}, 0.72)
end

-- Squat, irregular stones form natural talus at the wall foot. A low shoulder
-- and tiny offset crown keep these distinct from the taller dripstone meshes.
local function rubbleStone(g, x, y, z, radius, height, seed)
  local sides = 7
  local levels = {0, 0.30, 0.70, 0.93}
  local widths = {0.68, 1.00, 0.72, 0.30}
  local rings = {}
  for level = 1, #levels do
    local f = levels[level]
    local driftX = (hash01(seed, level, 701)-0.5)*radius*0.28*f
    local driftZ = (hash01(level, seed, 709)-0.5)*radius*0.28*f
    rings[level] = {}
    for side = 0, sides-1 do
      local a = side/sides*math.pi*2
      local wobble = 0.82+hash01(seed+level, side, 719)*0.34
      rings[level][side+1] = {
        x+driftX+math.cos(a)*radius*widths[level]*wobble,
        y+height*f,
        z+driftZ+math.sin(a)*radius*widths[level]*wobble,
      }
    end
  end
  for level = 1, #rings-1 do
    for side = 1, sides do
      local nextSide = side%sides+1
      local shade = 0.64+0.29*math.cos((side-1)/sides*math.pi*2-0.55)
      quad(g, rings[level][side], rings[level][nextSide],
              rings[level+1][nextSide], rings[level+1][side], shade)
    end
  end
  local top = {x+(hash01(seed, 8, 723)-0.5)*radius*0.22,
               y+height,
               z+(hash01(seed, 9, 725)-0.5)*radius*0.22}
  for side = 1, sides do
    local nextSide = side%sides+1
    quad(g, rings[#rings][side], rings[#rings][nextSide],
            top, top, 0.76)
  end
end

-- A banded limestone spire. Alternating radii and a gentle deterministic
-- drift create the stacked, water-carved silhouette seen in large caverns
-- without needing a high-poly imported model.
local function layeredSpire(g, x, y, z, radius, height, down, seed, joined)
  local sides = 7
  local dir = down and -1 or 1
  local levels = {0, 0.18, 0.39, 0.61, 0.80, 1.00}
  local widths = joined
    and {1.16, 0.82, 0.98, 0.67, 0.88, 1.06}
     or {1.16, 0.82, 0.94, 0.58, 0.43, 0.06}
  local rings = {}
  for level = 1, #levels do
    local f = levels[level]
    local driftX = (hash01(seed, level, 691)-0.5)*radius*0.30*f
    local driftZ = (hash01(level, seed, 697)-0.5)*radius*0.30*f
    rings[level] = {}
    for side = 0, sides-1 do
      local a = side/sides*math.pi*2
      local wobble = 0.87+hash01(seed+level,side,699)*0.25
      rings[level][side+1] = {
        x+driftX+math.cos(a)*radius*widths[level]*wobble,
        y+dir*height*f,
        z+driftZ+math.sin(a)*radius*widths[level]*wobble,
      }
    end
  end
  for level = 1, #rings-1 do
    for side = 1, sides do
      local nextSide = side%sides+1
      local shade = 0.65+0.28*math.cos((side-1)/sides*math.pi*2-0.7)
      quad(g, rings[level][side], rings[level][nextSide],
              rings[level+1][nextSide], rings[level+1][side], shade)
    end
  end
end

local function ellipse(g, x, y, z, rx, rz, sides, salt)
  for i = 0, sides - 1 do
    local a0 = i / sides * math.pi * 2
    local a1 = (i + 1) / sides * math.pi * 2
    local w0 = 0.83 + hash01(i, salt, 727) * 0.28
    local w1 = 0.83 + hash01(i + 1, salt, 727) * 0.28
    local c = {x, y, z}
    quad(g, c,
      {x + math.cos(a0) * rx * w0, y, z + math.sin(a0) * rz * w0},
      {x + math.cos(a1) * rx * w1, y, z + math.sin(a1) * rz * w1},
      c, 0.94)
  end
end

-- A narrow irregular rim gives each wet patch a readable shoreline without a
-- bright flat sticker.  It shares the same deterministic wobble as the fill.
local function ellipseRing(g, x, y, z, rx, rz, thickness, sides, salt)
  local inner = math.max(0.46, 1-thickness)
  for i = 0, sides - 1 do
    local a0 = i / sides * math.pi * 2
    local a1 = (i + 1) / sides * math.pi * 2
    local w0 = 0.83 + hash01(i, salt, 727) * 0.28
    local w1 = 0.83 + hash01(i + 1, salt, 727) * 0.28
    quad(g,
      {x + math.cos(a0)*rx*inner*w0, y,
       z + math.sin(a0)*rz*inner*w0},
      {x + math.cos(a0)*rx*w0, y, z + math.sin(a0)*rz*w0},
      {x + math.cos(a1)*rx*w1, y, z + math.sin(a1)*rz*w1},
      {x + math.cos(a1)*rx*inner*w1, y,
       z + math.sin(a1)*rz*inner*w1}, 0.96)
  end
end

-- Cave pools use a shared multi-lobed outline for fill and shoreline. The
-- stronger two- and three-wave silhouette avoids the old sticker-like oval,
-- while wall-aligned axes keep every patch tucked safely against an edge.
local function poolRadius(i, sides, salt)
  local wrapped = i%sides
  local a = wrapped/sides*math.pi*2
  local phaseA = hash01(salt, 1, 929)*math.pi*2
  local phaseB = hash01(salt, 2, 929)*math.pi*2
  local noise = (hash01(wrapped, salt, 937)-0.5)*0.16
  return math.max(0.62, math.min(1.18,
    0.86+math.sin(a*2+phaseA)*0.15+math.sin(a*3+phaseB)*0.10+noise))
end

local function organicPool(g, x, y, z, dx, dz, tangentRadius,
                           forwardRadius, sides, salt)
  local tx, tz = -dz, dx
  local c = {x, y, z}
  for i = 0, sides-1 do
    local a0, a1 = i/sides*math.pi*2, (i+1)/sides*math.pi*2
    local w0, w1 = poolRadius(i,sides,salt), poolRadius(i+1,sides,salt)
    local p0 = {x+tx*math.cos(a0)*tangentRadius*w0
                  +dx*math.sin(a0)*forwardRadius*w0,
                y,
                z+tz*math.cos(a0)*tangentRadius*w0
                  +dz*math.sin(a0)*forwardRadius*w0}
    local p1 = {x+tx*math.cos(a1)*tangentRadius*w1
                  +dx*math.sin(a1)*forwardRadius*w1,
                y,
                z+tz*math.cos(a1)*tangentRadius*w1
                  +dz*math.sin(a1)*forwardRadius*w1}
    quad(g, c, p0, p1, c, 0.94)
  end
end

local function organicPoolRing(g, x, y, z, dx, dz, tangentRadius,
                               forwardRadius, thickness, sides, salt)
  local tx, tz = -dz, dx
  local inner = 1-thickness
  for i = 0, sides-1 do
    local a0, a1 = i/sides*math.pi*2, (i+1)/sides*math.pi*2
    local w0, w1 = poolRadius(i,sides,salt), poolRadius(i+1,sides,salt)
    local function point(a, w, scale)
      return {x+tx*math.cos(a)*tangentRadius*w*scale
                +dx*math.sin(a)*forwardRadius*w*scale,
              y,
              z+tz*math.cos(a)*tangentRadius*w*scale
                +dz*math.sin(a)*forwardRadius*w*scale}
    end
    quad(g, point(a0,w0,inner), point(a0,w0,1),
            point(a1,w1,1), point(a1,w1,inner), 0.96)
  end
end

-- A small irregular stain fused to one wall face.  Broad patches replace the
-- old long strokes, so the water source reads as saturated stone rather than
-- a wire or a letter painted onto the wall.
local function wallPatch(g, x, z, dx, dz, tangent, y, tangentRadius,
                         verticalRadius, sides, depth, seed)
  local tx, tz = -dz, dx
  local nx, nz = dx * depth, dz * depth
  local cx, cz = x + tx*tangent + nx, z + tz*tangent + nz
  local centre = {cx, y, cz}
  for i = 0, sides - 1 do
    local a0 = i / sides * math.pi * 2
    local a1 = (i + 1) / sides * math.pi * 2
    local w0 = 0.78 + hash01(seed, i, 733) * 0.40
    local w1 = 0.78 + hash01(seed, i + 1, 733) * 0.40
    local p0 = {cx + tx*math.cos(a0)*tangentRadius*w0,
                y + math.sin(a0)*verticalRadius*w0,
                cz + tz*math.cos(a0)*tangentRadius*w0}
    local p1 = {cx + tx*math.cos(a1)*tangentRadius*w1,
                y + math.sin(a1)*verticalRadius*w1,
                cz + tz*math.cos(a1)*tangentRadius*w1}
    quad(g, centre, p0, p1, centre, 0.94)
    quad(g, centre, p1, p0, centre, 0.94)
  end
end

local function makeDrop()
  local g = group()
  local sides = 7
  for i = 0, sides - 1 do
    local a0, a1 = i / sides * math.pi * 2, (i + 1) / sides * math.pi * 2
    local b0 = {math.cos(a0) * 0.34, 0.18, math.sin(a0) * 0.34}
    local b1 = {math.cos(a1) * 0.34, 0.18, math.sin(a1) * 0.34}
    local m0 = {math.cos(a0) * 0.48, 0.54, math.sin(a0) * 0.48}
    local m1 = {math.cos(a1) * 0.48, 0.54, math.sin(a1) * 0.48}
    quad(g, b0, b1, m1, m0, 0.82 + 0.18 * math.cos(a0 - 0.6))
    quad(g, m0, m1, {0, 1.35, 0}, {0, 1.35, 0}, 0.92)
    quad(g, b1, b0, {0, 0, 0}, {0, 0, 0}, 0.72)
  end
  return Voxel3D.newMesh(g.verts, g.indices)
end

local function makeRing()
  local g = group()
  local sides, inner = 12, 0.68
  for i = 0, sides - 1 do
    local a0, a1 = i / sides * math.pi * 2, (i + 1) / sides * math.pi * 2
    quad(g,
      {math.cos(a0) * inner, 0, math.sin(a0) * inner},
      {math.cos(a1) * inner, 0, math.sin(a1) * inner},
      {math.cos(a1), 0, math.sin(a1)},
      {math.cos(a0), 0, math.sin(a0)}, 1)
  end
  return Voxel3D.newMesh(g.verts, g.indices)
end

-- Shared eight-facet crystal/drop shape used for airborne moisture and dust.
-- Unlike the old white screen-facing circles, this silhouette rotates through
-- perspective naturally and reveals depth as the camera moves around it.
local function makeMote()
  local g = group()
  local sides = 6
  local top, bottom = {0, 0.72, 0}, {0, -0.55, 0}
  for i = 0, sides - 1 do
    local a0 = i / sides * math.pi * 2
    local a1 = (i + 1) / sides * math.pi * 2
    local p0 = {math.cos(a0)*0.48, 0, math.sin(a0)*0.48}
    local p1 = {math.cos(a1)*0.48, 0, math.sin(a1)*0.48}
    local shade = 0.72 + 0.26*math.cos(a0-0.55)
    quad(g, top, p0, p1, top, shade)
    quad(g, bottom, p1, p0, bottom, shade*0.82)
  end
  return Voxel3D.newMesh(g.verts, g.indices)
end

local function floorAt(map, cx, cy)
  local ok, h = pcall(V.require("VoxelScene").groundAt,
                      map, cx, cy, cx * 16, cy * 16)
  return (ok and tonumber(h)) or 0
end

local function build(map)
  local wc, hc = map.widthCells or 0, map.heightCells or 0
  local S = Structures.forMap(map)
  local anchors, waterAnchors, motes = {}, {}, {}
  local rock, litRock = group(), group()
  local pillars, litPillars = group(), group()
  local hanging, litHanging = group(), group()
  local ceilingChunks = {}
  local ceilingClusters = {}
  local seep, runnel = group(), group()
  local landing, landingSheen, landingRim = group(), group(), group()
  local pools, poolSheen, poolRim, haze = group(), group(), group(), group()
  local torchSources = CaveSconces.sources(map)

  local function nearTorch(x, z, radius)
    local r2 = radius * radius
    for _, source in ipairs(torchSources or {}) do
      local sx, sz = source.x or source[1], source.z or source[2]
      if sx and sz then
        local ox, oz = x - sx, z - sz
        if ox*ox + oz*oz <= r2 then return true end
      end
    end
    return false
  end

  local function walk(cx, cy)
    if cx < 0 or cy < 0 or cx >= wc or cy >= hc then return false end
    local ok, result = pcall(function() return map:isWalkableCell(cx, cy) end)
    return ok and result or false
  end

  local function wallFace(cx, cy, dx, dz)
    local samples
    if dx > 0 then samples = {{cx*2+1,cy*2},{cx*2+1,cy*2+1}}
    elseif dx < 0 then samples = {{cx*2,cy*2},{cx*2,cy*2+1}}
    elseif dz > 0 then samples = {{cx*2,cy*2+1},{cx*2+1,cy*2+1}}
    else samples = {{cx*2,cy*2},{cx*2+1,cy*2}} end
    for _, p in ipairs(samples) do
      local k = keyOf(p[1], p[2])
      local s = S and S.shapeAt and S.shapeAt[k]
      if not s or s.class ~= "wall" or (S.skip and S.skip[k]) then return false end
    end
    return true
  end

  -- TEST192: on Victory Road (CaveRubble) the loose rocks stand 3 high
  -- under their heaps and the other walls 16, not the usual 30: nothing
  -- there may hang from a 30-high crown, and on a loose rock nothing is
  -- mounted on the face at all
  local Rubble = V.require("CaveRubble")
  local rubbleMap = Rubble.shelfWalls(map)   -- TEST203: + Cerulean (isLow stays Victory Road)
  local function lowRock(cx, cy)
    return rubbleMap and S and S.tileAt
      and Rubble.isLow(map, S.tileAt[keyOf(cx * 2, cy * 2)]) or false
  end

  local function supported(cx, cy, dx, dz)
    if not wallFace(cx, cy, dx, dz) then return false end
    local lx, lz = -dz, dx
    return wallFace(cx + lx, cy + lz, dx, dz)
        or wallFace(cx - lx, cy - lz, dx, dz)
  end

  for cy = 0, hc - 1 do
    for cx = 0, wc - 1 do
      if not walk(cx, cy) then
        local candidates = {{1,0},{-1,0},{0,1},{0,-1}}
        for _, d in ipairs(candidates) do
          local dx, dz = d[1], d[2]
          local ox, oz = cx + dx, cy + dz
          if walk(ox, oz) and supported(cx, cy, dx, dz) then
            local torchClear = CaveSconces.reserved(map, cx, cy)
            local seed = cx * 97 + cy * 193 + dx * 17 + dz * 29
            local tangent = (hash01(cx, cy, 743) - 0.5) * 8.0
            local sx = cx * 16 + 8 + dx * 8 + dx * 2.2 - dz * tangent
            local sz = cy * 16 + 8 + dz * 8 + dz * 2.2 + dx * tangent
            local fy = floorAt(map, ox, oz)

            -- Every drop has a visible cause. Two compact mineral-dark wet
            -- patches overlap around the source and a bead forms at their
            -- lowest point. There is no long vertical stroke to resemble a
            -- cable, and nothing begins at the artificial wall crown.
            local low = lowRock(cx, cy)
            if not torchClear and not low
               and math.floor(hash01(cx, cy, 751) * 5) == 0 then
              local tx, tz = -dz, dx
              local sourceY = fy + 10.7 + hash01(cx, cy, 757)*3.0
              local bend = (hash01(cx, cy, 759)-0.5)*1.35
              local lower = bend + (hash01(cx, cy, 760)-0.5)*0.65
              wallPatch(runnel, sx, sz, dx, dz, bend, sourceY+1.45,
                        1.45, 2.45, 10, 0.20, seed+1)
              wallPatch(seep, sx, sz, dx, dz, lower, sourceY+0.48,
                        0.44, 0.86, 8, 0.25, seed+3)

              local ax = sx + tx*lower + dx*0.28
              local az = sz + tz*lower + dz*0.28
              local landingRx = 1.35+hash01(cx,cy,767)*0.82
              local landingRz = 0.90+hash01(cx,cy,768)*0.58
              ellipse(landing, ax, fy+0.18, az,
                      landingRx, landingRz, 9, seed+5)
              ellipse(landingSheen,
                      ax-dz*(hash01(cx,cy,770)-0.5)*0.55,
                      fy+0.215,
                      az+dx*(hash01(cx,cy,770)-0.5)*0.55,
                      landingRx*0.58, landingRz*0.50, 8, seed+7)
              ellipseRing(landingRim, ax, fy+0.235, az,
                          landingRx*1.04, landingRz*1.04,
                          0.24, 11, seed+5)
              anchors[#anchors + 1] = {
                x=ax, z=az, floor=fy + 0.24, top=sourceY-0.18,
                phase=hash01(cx, cy, 761)*5,
                speed=0.90+hash01(cx,cy,769)*0.22,
              }
            end

            -- Earlier unrelated vertical mineral bars could read like black
            -- cables. TEST88 keeps every moisture mark compact, sourced and
            -- paired with a visible bead and landing.

            -- Readable faceted rubble stays at the edge, never in the walking
            -- lane. One larger anchor stone and several loose companions make
            -- each pile visible without covering the dirt path.
            if not torchClear
               and math.floor(hash01(cx, cy, 811) * 6) == 0 then
              local tx, tz = -dz, dx
              local side = (hash01(cx,cy,813)<0.5) and -1 or 1
              local bx = sx+dx*(1.35+hash01(cx,cy,817)*0.75)
                       +tx*side*0.65
              local bz = sz+dz*(1.35+hash01(cx,cy,817)*0.75)
                       +tz*side*0.65
              local pile = nearTorch(bx, bz, 25) and litRock or rock
              rubbleStone(pile, bx, fy, bz,
                          1.35+hash01(cx,cy,821)*0.70,
                          1.45+hash01(cx,cy,823)*1.20, seed)
              local count = 3+math.floor(hash01(cx,cy,825)*3)
              for i = 1, count do
                local spread = (i-(count+1)*0.5)*1.45
                             +(hash01(seed,i,827)-0.5)*0.70
                local push = 0.85+hash01(seed,i,829)*1.20
                rubbleStone(pile,
                            sx+dx*push+tx*spread,
                            fy,
                            sz+dz*push+tz*spread,
                            0.48+hash01(seed,i,830)*0.68,
                            0.48+hash01(seed,i,832)*1.05,
                            seed+i*13)
              end
            end

            -- Tall layered columns remain tucked against the wall. Their
            -- bases never enter the centre of a 16-pixel walking cell, so the
            -- engine's collision, encounters and battle staging stay clear.
            local colK = rubbleMap and ((Rubble.wallTop(map) or 16) / 26) or 1.0
            if not torchClear and not low
               and math.floor(hash01(cx, cy, 831) * 6) == 0 then
              local side = (hash01(cx,cy,833)<0.5) and -1 or 1
              local bx = sx+dx*2.25-dz*side*1.1
              local bz = sz+dz*2.25+dx*side*1.1
              local pillarGroup = nearTorch(bx, bz, 26)
                                 and litPillars or pillars
              layeredSpire(pillarGroup, bx, fy, bz,
                           2.35+hash01(cx,cy,835)*1.10,
                           (9.5+hash01(cx,cy,837)*7.2)*colK, false, seed+17)
              layeredSpire(pillarGroup, bx-dz*side*2.7, fy,
                           bz+dx*side*2.7,
                           1.10+hash01(cx,cy,838)*0.75,
                           (4.5+hash01(cx,cy,840)*4.7)*colK, false, seed+19)
              if hash01(cx,cy,841)>0.56 then
                layeredSpire(pillarGroup, bx+dz*side*2.35, fy,
                             bz-dx*side*2.35,
                             0.82+hash01(cx,cy,852)*0.58,
                             3.1+hash01(cx,cy,854)*3.6, false, seed+21)
              end
            end

            -- FULL exposes denser upper-wall teeth. Their centres are buried
            -- behind the wall face and their roots begin inside the crown, so
            -- they break up the black opening as solid rock silhouettes rather
            -- than transparent bands or camera-crossing ceiling shelves.
            if not torchClear and not rubbleMap
               and math.floor(hash01(cx, cy, 856) * 3) == 0 then
              local anchorY = fy+24.4
              local hx, hz = sx+dx*0.42, sz+dz*0.42
              local crownGroup = nearTorch(hx, hz, 25)
                                 and litHanging or hanging
              layeredSpire(crownGroup, hx, anchorY, hz,
                           1.90+hash01(cx,cy,844)*1.30,
                           5.8+hash01(cx,cy,845)*4.7, true, seed+29)
              if hash01(cx,cy,846)>0.22 then
                local offset = (hash01(cx,cy,847)-0.5)*5.5
                layeredSpire(crownGroup,
                             hx-dz*offset, anchorY-0.25,
                             hz+dx*offset,
                             0.90+hash01(cx,cy,848)*0.82,
                             3.4+hash01(cx,cy,849)*3.4, true, seed+31)
              end
              if hash01(cx,cy,855)>0.74 then
                local offset = (hash01(cx,cy,857)-0.5)*5.6
                layeredSpire(crownGroup,
                             hx-dz*offset, anchorY-0.48,
                             hz+dx*offset,
                             0.58+hash01(cx,cy,858)*0.58,
                             2.4+hash01(cx,cy,860)*2.4, true, seed+33)
              end
            end

            -- Rare fused columns broaden at both ends and meet the upper wall
            -- mass directly. No added slab is needed to explain the join.
            if not torchClear and not rubbleMap
               and math.floor(hash01(cx, cy, 850) * 37) == 0 then
              local anchorY = fy+21.5
              local bx, bz = sx+dx*2.5, sz+dz*2.5
              local fusedGroup = nearTorch(bx, bz, 27)
                                and litHanging or hanging
              layeredSpire(fusedGroup, bx, fy, bz,
                           2.45+hash01(cx,cy,851)*0.85,
                           anchorY-fy-0.65, false, seed+41, true)
            end

            -- FULL pools hug walls so the dense dirt remains the main path.
            if not torchClear
               and math.floor(hash01(cx, cy, 859) * 10) == 0 then
              local px, pz = sx+dx*2.9, sz+dz*2.9
              local rx = 2.2+hash01(cx,cy,863)*2.1
              local rz = 1.35+hash01(cx,cy,877)*1.35
              organicPool(pools, px, fy+0.28, pz, dx, dz,
                          rx, rz, 14, seed)
              organicPool(poolSheen,
                          px-dz*0.22+dx*0.10, fy+0.31,
                          pz+dx*0.22+dz*0.10, dx, dz,
                          rx*0.62, rz*0.56, 12, seed+11)
              organicPoolRing(poolRim, px, fy+0.325, pz, dx, dz,
                              rx, rz, 0.17, 14, seed)
              local rippleX = math.abs(dx)*rz+math.abs(dz)*rx
              local rippleZ = math.abs(dx)*rx+math.abs(dz)*rz
              waterAnchors[#waterAnchors + 1] = {
                x=px, z=pz, y=fy+0.34, rx=rippleX, rz=rippleZ,
                phase=hash01(cx,cy,879)
              }
            end
          end
        end
      else
        local fy = floorAt(map, cx, cy)
        if math.floor(hash01(cx, cy, 881) * 29) == 0 then
          -- A few low, translucent pockets make the air feel cool and heavy.
          ellipse(haze, cx*16+8, fy+1.1, cy*16+8,
                  6+hash01(cx,cy,883)*5, 4+hash01(cx,cy,887)*4, 10,
                  cx+cy*wc)
        end
        if math.floor(hash01(cx, cy, 889) * 4) == 0 then
          -- Sparse deterministic anchor points drive smooth analytic motion;
          -- no meshes or tables are allocated while the player walks.
          local mx = cx*16+3+hash01(cx,cy,893)*10
          local mz = cy*16+3+hash01(cx,cy,895)*10
          motes[#motes+1] = {
            x=mx, z=mz, y=fy+4.0+hash01(cx,cy,897)*13.0,
            size=0.34+hash01(cx,cy,899)*0.46,
            phase=hash01(cx,cy,901)*math.pi*2,
            speed=0.24+hash01(cx,cy,903)*0.34,
            drift=0.85+hash01(cx,cy,905)*1.55,
            warm=nearTorch(mx,mz,29),
          }
        end
      end
    end
  end

  -- Shared corner heights weld every section into one visually continuous
  -- low-poly roof. The geometry is cached in small, edgeless chunks so battle
  -- staging can omit only the section directly over the arena while leaving
  -- the surrounding cavern canopy visible. Raising the roof also keeps its
  -- hanging formations clear of the player and companion cameras.
  local function roofHeight(gx, gy)
    return 66+(hash01(gx,gy,941)-0.5)*6.5
  end
  local roofChunkSize = 4
  for by = 0, hc-1, roofChunkSize do
    for bx = 0, wc-1, roofChunkSize do
      local roofGroup, litRoofGroup = group(), group()
      local endX = math.min(bx+roofChunkSize, wc)
      local endY = math.min(by+roofChunkSize, hc)
      for cy = by, endY-1 do
        for cx = bx, endX-1 do
          local x0, z0 = cx*16, cy*16
          local x1, z1 = x0+16, z0+16
          local p00 = {x0, roofHeight(cx,cy), z0}
          local p10 = {x1, roofHeight(cx+1,cy), z0}
          local p11 = {x1, roofHeight(cx+1,cy+1), z1}
          local p01 = {x0, roofHeight(cx,cy+1), z1}
          local centre = {
            x0+8+(hash01(cx,cy,943)-0.5)*3.8,
            (p00[2]+p10[2]+p11[2]+p01[2])*0.25
              -0.6-hash01(cx,cy,947)*1.8,
            z0+8+(hash01(cx,cy,949)-0.5)*3.8,
          }
          local target = nearTorch(x0+8,z0+8,38)
                         and litRoofGroup or roofGroup
          quad(target, p00, p01, centre, centre,
               0.52+hash01(cx,cy,951)*0.13)
          quad(target, p01, p11, centre, centre,
               0.58+hash01(cx,cy,953)*0.13)
          quad(target, p11, p10, centre, centre,
               0.48+hash01(cx,cy,957)*0.14)
          quad(target, p10, p00, centre, centre,
               0.55+hash01(cx,cy,959)*0.13)
        end
      end
      ceilingChunks[#ceilingChunks+1] = {
        x=(bx+endX)*8,
        z=(by+endY)*8,
        roof=Voxel3D.newMesh(roofGroup.verts, roofGroup.indices),
        litRoof=Voxel3D.newMesh(litRoofGroup.verts, litRoofGroup.indices),
      }
    end
  end

  -- Sparse, broad-rooted groups descend from the roof itself. Their narrower,
  -- shorter silhouettes retain readable cave teeth without hanging into the
  -- player camera or dominating the corridor.
  local stride = 4
  for by = 0, hc-1, stride do
    for bx = 0, wc-1, stride do
      local chosenX, chosenY = nil, nil
      local best = 2
      for oy = 0, stride-1 do
        for ox = 0, stride-1 do
          local cx, cy = bx+ox, by+oy
          if cx < wc and cy < hc and walk(cx, cy) then
            local score = hash01(cx,cy,967)
            if score < best then
              best, chosenX, chosenY = score, cx, cy
            end
          end
        end
      end
      if chosenX and hash01(bx,by,971) < 0.52 then
        local seed = chosenX*137+chosenY*271+977
        local x = chosenX*16+8+(hash01(seed,1,979)-0.5)*10
        local z = chosenY*16+8+(hash01(seed,2,979)-0.5)*10
        local roofY = roofHeight(chosenX,chosenY)-1.2
                        -hash01(seed,3,983)*1.4
        local teethMesh = group()
        local teeth = 2+math.floor(hash01(seed,7,991)*2)
        for i = 1, teeth do
          local a = hash01(seed,i,997)*math.pi*2
          local reach = i == 1 and 1.2
                        or 2.8+hash01(seed,i,1009)*8.5
          local tx = x+math.cos(a)*reach
          local tz = z+math.sin(a)*reach*0.76
          local height = (i == 1 and 12.0 or 6.0)
                       +hash01(seed,i,1013)*(i == 1 and 6.5 or 6.8)
          layeredSpire(teethMesh, tx, roofY, tz,
                       (i == 1 and 2.5 or 1.15)
                         +hash01(seed,i,1019)*(i == 1 and 1.20 or 1.00),
                       height, true, seed+i*17)
        end

        ceilingClusters[#ceilingClusters+1] = {
          x=x, z=z,
          lit=nearTorch(x,z,40),
          mesh=Voxel3D.newMesh(teethMesh.verts, teethMesh.indices),
        }
      end
    end
  end

  return {
    anchors=anchors,
    waterAnchors=waterAnchors,
    motes=motes,
    rock=Voxel3D.newMesh(rock.verts, rock.indices),
    litRock=Voxel3D.newMesh(litRock.verts, litRock.indices),
    pillars=Voxel3D.newMesh(pillars.verts, pillars.indices),
    litPillars=Voxel3D.newMesh(litPillars.verts, litPillars.indices),
    hanging=Voxel3D.newMesh(hanging.verts, hanging.indices),
    litHanging=Voxel3D.newMesh(litHanging.verts, litHanging.indices),
    ceilingChunks=ceilingChunks,
    ceilingClusters=ceilingClusters,
    seep=Voxel3D.newMesh(seep.verts, seep.indices),
    runnel=Voxel3D.newMesh(runnel.verts, runnel.indices),
    landing=Voxel3D.newMesh(landing.verts, landing.indices),
    landingSheen=Voxel3D.newMesh(landingSheen.verts, landingSheen.indices),
    landingRim=Voxel3D.newMesh(landingRim.verts, landingRim.indices),
    pools=Voxel3D.newMesh(pools.verts, pools.indices),
    poolSheen=Voxel3D.newMesh(poolSheen.verts, poolSheen.indices),
    poolRim=Voxel3D.newMesh(poolRim.verts, poolRim.indices),
    haze=Voxel3D.newMesh(haze.verts, haze.indices),
  }
end

local function drawMap(map, focusX, focusZ, battle)
  local detail = CommunityVisuals.caveDetailLevel()
  if detail == "off" or not isCave(map) then return false end
  local slot = cache[map]
  if not slot then slot = build(map); cache[map] = slot end
  local img = white()
  if not img then return false end

  dropMesh = dropMesh or makeDrop()
  ringMesh = ringMesh or makeRing()
  moteMesh = moteMesh or makeMote()
  local full = detail == "full"
  local g = love and love.graphics
  local pushed = g and g.push and pcall(g.push, "all")
  local t = 0
  pcall(function() t = love.timer.getTime() end)

  pcall(function()
    love.graphics.setDepthMode("lequal", true)
    love.graphics.setBlendMode("alpha")

    -- First- and third-person exploration draws every welded roof section.
    -- Battles keep the surrounding canopy but clear a stable arena-sized hole
    -- from its small cached chunks; orbit cameras retain the open diorama.
    local freeCam = not battle and VoxelState.isFreeCam()
    if full and slot.ceilingChunks and (freeCam or battle) then
      local battleRoofClear2 = 68*68
      for _, block in ipairs(slot.ceilingChunks) do
        local dx, dz = block.x-focusX, block.z-focusZ
        if not battle or dx*dx+dz*dz > battleRoofClear2 then
          love.graphics.setColor(0.092, 0.047, 0.033, 1)
          if block.roof then Voxel3D.draw(block.roof, img) end
          love.graphics.setColor(0.162, 0.076, 0.038, 1)
          if block.litRoof then Voxel3D.draw(block.litRoof, img) end
        end
      end
    end
    if full and slot.ceilingClusters and (freeCam or battle) then
      local battleClear2 = 70*70
      for _, block in ipairs(slot.ceilingClusters) do
        local dx, dz = block.x-focusX, block.z-focusZ
        if not battle or dx*dx+dz*dz > battleClear2 then
          if block.lit then
            love.graphics.setColor(0.275, 0.125, 0.052, 1)
          else
            love.graphics.setColor(0.145, 0.074, 0.044, 1)
          end
          if block.mesh then Voxel3D.draw(block.mesh, img) end
        end
      end
    end

    love.graphics.setColor(0.205, 0.112, 0.060, 1)
    if slot.rock then Voxel3D.draw(slot.rock, img) end
    love.graphics.setColor(0.355, 0.165, 0.060, 1)
    if slot.litRock then Voxel3D.draw(slot.litRock, img) end
    love.graphics.setColor(0.195, 0.108, 0.066, 1)
    if slot.pillars then Voxel3D.draw(slot.pillars, img) end
    love.graphics.setColor(0.335, 0.150, 0.058, 1)
    if slot.litPillars then Voxel3D.draw(slot.litPillars, img) end
    if full and slot.hanging then
      love.graphics.setColor(0.175, 0.098, 0.060, 1)
      Voxel3D.draw(slot.hanging, img)
      love.graphics.setColor(0.300, 0.132, 0.050, 1)
      if slot.litHanging then Voxel3D.draw(slot.litHanging, img) end
    end
    love.graphics.setDepthMode("lequal", false)
    Voxel3D.lighting(false)
    -- Broad rock-toned stains provide a physical water source without the
    -- long black/teal stems that could read as wires from gameplay cameras.
    love.graphics.setColor(0.055, 0.075, 0.070, full and 0.28 or 0.22)
    if slot.seep then Voxel3D.draw(slot.seep, img) end
    love.graphics.setColor(0.080, 0.105, 0.092, full and 0.22 or 0.17)
    if slot.runnel then Voxel3D.draw(slot.runnel, img) end
    love.graphics.setColor(0.035, 0.115, 0.128, full and 0.62 or 0.46)
    if slot.landing then Voxel3D.draw(slot.landing, img) end
    love.graphics.setColor(0.11, 0.28, 0.30, full and 0.28 or 0.19)
    if slot.landingRim then Voxel3D.draw(slot.landingRim, img) end
    if slot.landingSheen then
      local beadShimmer = 0.5+0.5*math.sin(t*1.65+0.4)
      love.graphics.setColor(0.18, 0.38, 0.41,
                             (full and 0.16 or 0.11)+beadShimmer*0.055)
      Voxel3D.draw(slot.landingSheen, img)
    end
    if full and slot.pools then
      -- Waterworks-inspired water remains cave-dark: a deep mineral base,
      -- slow cool sheen and infrequent expanding rings rather than a bright
      -- blue floor decal.
      love.graphics.setColor(0.050, 0.105, 0.108, 0.48)
      Voxel3D.draw(slot.pools, img)
      local shimmer = 0.5 + 0.5*math.sin(t*1.35)
      love.graphics.setColor(0.16, 0.34, 0.37, 0.11+shimmer*0.08)
      if slot.poolSheen then Voxel3D.draw(slot.poolSheen, img) end
      love.graphics.setColor(0.10, 0.24, 0.26, 0.24)
      if slot.poolRim then Voxel3D.draw(slot.poolRim, img) end

      local waterDrawn = 0
      for _, w in ipairs(slot.waterAnchors or {}) do
        if waterDrawn >= 4 then break end
        if ringMesh and math.abs(w.x-focusX) < 190
                    and math.abs(w.z-focusZ) < 190 then
          waterDrawn = waterDrawn + 1
          local age = (t*0.32+w.phase) % 1
          local swell = 0.20+age*0.62
          local fade = math.sin(age*math.pi)
          love.graphics.setColor(0.21, 0.46, 0.50, fade*0.24)
          Voxel3D.draw(ringMesh, img,
            Mat4.mul(Mat4.translate(w.x, w.y+0.025, w.z),
                     Mat4.scale(w.rx*swell, 1, w.rz*swell)))
        end
      end
    end
    if full and slot.haze then
      local breathe = 0.5+0.5*math.sin(t*0.48)
      love.graphics.setColor(0.16, 0.22, 0.22, 0.066+breathe*0.044)
      Voxel3D.draw(slot.haze, img)
    end

    -- Rebuild the old floating cave specks as true low-poly volumes.  Nearby
    -- flames warm their colour, while distant moisture remains cool. A small
    -- bright core inside a softer outer crystal gives each mote depth without
    -- a camera-facing billboard or screen-space particle system.
    local moteCap, moteDrawn = full and 22 or 10, 0
    if moteMesh then
      for i, m in ipairs(slot.motes or {}) do
        if moteDrawn >= moteCap then break end
        if math.abs(m.x-focusX) < 175 and math.abs(m.z-focusZ) < 175 then
          moteDrawn = moteDrawn + 1
          local phase = m.phase+i*0.37
          local mx = m.x+math.sin(t*m.speed+phase)*m.drift
          local mz = m.z+math.cos(t*m.speed*0.83+phase*1.31)*m.drift*0.72
          local my = m.y+math.sin(t*m.speed*0.61+phase*1.73)*1.35
          local pulse = 0.58+0.42*math.sin(t*(1.1+m.speed)+phase*2.1)
          if m.warm then
            love.graphics.setColor(1.00, 0.60, 0.22, 0.20+pulse*0.16)
          else
            love.graphics.setColor(0.62, 0.82, 0.86, 0.16+pulse*0.15)
          end
          Voxel3D.draw(moteMesh, img,
            Mat4.mul(Mat4.translate(mx,my,mz),
                     Mat4.scale(m.size,m.size*1.08,m.size)))
          if full and pulse > 0.69 then
            if m.warm then
              love.graphics.setColor(1.00, 0.84, 0.46, 0.24+pulse*0.18)
            else
              love.graphics.setColor(0.82, 0.96, 1.00, 0.22+pulse*0.17)
            end
            Voxel3D.draw(moteMesh, img,
              Mat4.mul(Mat4.translate(mx,my,mz),
                       Mat4.scale(m.size*0.42,m.size*0.50,m.size*0.42)))
          end
        end
      end
    end

    local cap, drawn = full and 10 or 5, 0
    for i, a in ipairs(slot.anchors or {}) do
      if drawn >= cap then break end
      if math.abs(a.x-focusX) < 190 and math.abs(a.z-focusZ) < 190 then
        drawn = drawn + 1
        local span = math.max(6, a.top-a.floor)
        local gravity = 28
        local fall = math.sqrt(2*span/gravity) / a.speed
        local pause = 1.1 + hash01(i, 0, 907)*1.8
        local form = 0.75 + hash01(i, 0, 911)*0.45
        local splash = 0.20
        local age = (t + a.phase) % (pause + form + fall + splash)
        if age >= pause and age < pause + form and dropMesh then
          -- A bead visibly gathers at the end of the damp trail before release.
          local p = (age-pause)/form
          local sxz = 0.10 + p*0.18
          local sy = 0.14 + p*0.26
          love.graphics.setColor(0.32, 0.67, 0.74, 0.82)
          Voxel3D.draw(dropMesh, img,
            Mat4.mul(Mat4.translate(a.x, a.top-1.35*sy, a.z),
                     Mat4.scale(sxz*1.18, sy*1.16, sxz*1.18)))
        elseif age >= pause + form and age < pause + form + fall and dropMesh then
          local falling = age-pause-form
          local stretch = 0.88 + math.min(0.62, falling*0.72)
          local y = a.top - 1.35*stretch
                    - 0.5*gravity*(falling*a.speed)*(falling*a.speed)
          love.graphics.setColor(0.34, 0.70, 0.78, 0.86)
          Voxel3D.draw(dropMesh, img,
            Mat4.mul(Mat4.translate(a.x, math.max(a.floor+0.25,y), a.z),
                     Mat4.scale(0.46, stretch*1.06, 0.46)))
        elseif age >= pause + form + fall and ringMesh then
          local p = (age-pause-form-fall)/splash
          local size = 0.28 + p*1.25
          love.graphics.setColor(0.30, 0.66, 0.72, (1-p)*0.62)
          Voxel3D.draw(ringMesh, img,
            Mat4.mul(Mat4.translate(a.x, a.floor+0.06, a.z),
                     Mat4.scale(size, 1, size)))
        end
      end
    end
    Voxel3D.lighting(true)
  end)
  pcall(Voxel3D.lighting, true)
  if pushed then pcall(g.pop) end
  return true
end

function CaveAtmosphere3D.draw(state)
  local map, p = state and state.map, state and state.player
  if not map then return false end
  return drawMap(map, (p and p.px or 0)+8, (p and p.py or 0)+8)
end

function CaveAtmosphere3D.drawBattle(map, arena)
  local mid = arena and arena.mid
  return drawMap(map, (mid and mid[1]) or 0, (mid and mid[2]) or 0, true)
end

function CaveAtmosphere3D.invalidate()
  for _, slot in pairs(cache) do
    for _, name in ipairs({"rock","litRock","pillars","litPillars",
                           "hanging","litHanging",
                           "seep","runnel","landing","landingSheen",
                           "landingRim","pools","poolSheen","poolRim",
                           "haze"}) do
      local mesh = slot and slot[name]
      if mesh and mesh.release then pcall(mesh.release, mesh) end
    end
    for _, block in ipairs((slot and slot.ceilingClusters) or {}) do
      local mesh = block and block.mesh
      if mesh and mesh.release then pcall(mesh.release, mesh) end
    end
    for _, block in ipairs((slot and slot.ceilingChunks) or {}) do
      for _, mesh in ipairs({block and block.roof, block and block.litRoof}) do
        if mesh and mesh.release then pcall(mesh.release, mesh) end
      end
    end
  end
  cache = setmetatable({}, { __mode = "k" })
  for _, mesh in ipairs({dropMesh, ringMesh, moteMesh}) do
    if mesh and mesh.release then pcall(mesh.release, mesh) end
  end
  dropMesh, ringMesh, moteMesh = nil, nil, nil
  if whiteImg and whiteImg.release then pcall(whiteImg.release, whiteImg) end
  whiteImg = nil
end

Assets.register(CaveAtmosphere3D.invalidate)

return CaveAtmosphere3D
