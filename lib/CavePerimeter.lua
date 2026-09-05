-- TEST32: retain TEST31's physical facets and TEST27's 30-percent-higher
-- silhouette, then replace the smooth tonal range with a limited stepped ramp.
-- The ridge reads as older low-poly cave rock while all variation remains in
-- stable mesh geometry and vertex tones; it cannot become confetti or move.
--
-- The engine intentionally border-extends each map by three blocks. That is
-- enough to close gameplay, but the pitched voxel camera can still see past
-- the finite ring into a flat void. This mesh stands beyond that authored
-- ring, so it never changes a tile, collision, path, ladder, warp or NPC. Its
-- uneven ridge merely gives the indoor horizon a cave silhouette. TEST27
-- scales both its base and variation so it stays irregular instead of becoming
-- a flat barricade, while every playable maze wall remains unchanged.

local V = ...

local Assets = require("src.render.Assets")
local Voxel3D = V.require("Voxel3D")

local CavePerimeter = {}

local OUTSET = 112
local DEPTH = 18
local BOTTOM = -20
local SEGMENT = 16
local RIDGE_BASE = 62
-- Tile 2 is reserved for the D/S/B/L geometry swatches. The visible ridge
-- draws only the two calm wall patterns so that its silhouette does not turn
-- into a repeated four-colour pixel field.
local SWATCH_TILES = { 3, 12 }

local cache = setmetatable({}, { __mode = "k" })

local function noise(i, salt)
  local n = (i * 73856093 + salt * 19349663) % 104729
  if n < 0 then n = n + 104729 end
  return n / 104729
end

local function ridge(i, salt)
  local broad = noise(math.floor(i / 3), salt + 11) * 17
  local detail = noise(i, salt + 29) * 12
  return RIDGE_BASE + math.floor(broad + detail)
end

local function ridgeMid(i, salt, a, b)
  local y = (a + b) * 0.5 + (noise(i, salt + 97) - 0.5) * 5
  return math.max(RIDGE_BASE, math.min(89, y))
end

local function facetBulge(i, salt)
  return 1.15 + noise(i, salt + 137) * 2.45
end

local function facetShade(i, half, salt)
  local n = noise(i * 2 + half, salt + 179)
  return n < 0.18 and 0.78 or n < 0.45 and 0.86
      or n < 0.78 and 0.94 or 1.02
end

local function capShade(i, half, salt)
  local n = noise(i * 2 + half, salt + 211)
  return n < 0.22 and 0.84 or n < 0.72 and 0.91 or 0.98
end

local function uvRect(atlas, tileset, tile)
  local w, h = atlas:getDimensions()
  local perRow = tileset.tilesPerRow or 16
  local x, y = (tile % perRow) * 8, math.floor(tile / perRow) * 8
  local inset = 0.08
  return (x + inset) / w, (x + 8 - inset) / w,
         (y + inset) / h, (y + 8 - inset) / h
end

local function variedUV(atlas, tileset, segment, band, salt)
  local pick = 1 + math.floor(noise(segment + band * 17, salt) * #SWATCH_TILES)
  local u0, u1, v0, v1 = uvRect(atlas, tileset, SWATCH_TILES[pick])
  if noise(segment, salt + band * 23 + 71) > .5 then u0, u1 = u1, u0 end
  if noise(band, salt + segment * 29 + 83) > .5 then v0, v1 = v1, v0 end
  return u0, u1, v0, v1
end

local function push(verts, indices, corners, u0, u1, v0, v1, shade)
  local n = #verts / 4
  local uv = { { u0, v1 }, { u1, v1 }, { u1, v0 }, { u0, v0 } }
  for i = 1, 4 do
    local p = corners[i]
    local s = type(shade) == "table" and shade[i] or shade
    verts[#verts + 1] = { p[1], p[2], p[3], uv[i][1], uv[i][2], s }
  end
  Voxel3D.pushQuad(indices, n)
end

local function lerp(a, b, t)
  return a + (b - a) * t
end

-- Low-frequency noise sampled at shared segment/band nodes. Bilinear blending
-- makes neighbouring quads meet at the same value, while the mesh's two broad
-- triangles still catch enough tonal change to read as a faceted rock wall.
local function facetTone(segmentNode, bandNode, salt)
  local scaleX, scaleY = 3, 2
  local gx, gy = math.floor(segmentNode / scaleX), math.floor(bandNode / scaleY)
  local fx = (segmentNode - gx * scaleX) / scaleX
  local fy = (bandNode - gy * scaleY) / scaleY
  local function sample(x, y)
    return noise(x + y * 4093, salt + 151)
  end
  local n0 = lerp(sample(gx, gy), sample(gx + 1, gy), fx)
  local n1 = lerp(sample(gx, gy + 1), sample(gx + 1, gy + 1), fx)
  return 0.84 + lerp(n0, n1, fy) * 0.18
end

-- Split each face into short bands for geometry, but shade it as one continuous
-- macro field roughly 48px wide by 16px tall. The solid atlas contributes no
-- pixel grain; all visible variation is broad and world-stable.
local function vertical(verts, indices, a0, a1, b0, b1, top0, top1,
                        atlas, tileset, segment, salt, shade)
  local y = BOTTOM
  while y < math.max(top0, top1) do
    local lo0, lo1 = math.min(y, top0), math.min(y, top1)
    local hi0, hi1 = math.min(y + 8, top0), math.min(y + 8, top1)
    if hi0 > lo0 or hi1 > lo1 then
      local band = math.floor((y - BOTTOM) / 8)
      local u0, u1, v0, v1 = variedUV(atlas, tileset, segment, band, salt)
      push(verts, indices,
           { { a0, lo0, b0 }, { a1, lo1, b1 },
             { a1, hi1, b1 }, { a0, hi0, b0 } },
           u0, u1, v0, v1,
           { shade * facetTone(segment, band, salt),
             shade * facetTone(segment + 1, band, salt),
             shade * facetTone(segment + 1, band + 1, salt),
             shade * facetTone(segment, band + 1, salt) })
    end
    y = y + 8
  end
end

local function build(map, atlas)
  if not (map and atlas and map.tileset) then return nil end
  local w = (map.widthCells or ((map.def and map.def.width or 0) * 2)) * 16
  local h = (map.heightCells or ((map.def and map.def.height or 0) * 2)) * 16
  if w <= 0 or h <= 0 then return nil end

  local verts, indices = {}, {}

  local function northSouth(z, outward, salt, shade)
    local startX, finishX = -OUTSET, w + OUTSET
    local count = math.ceil((finishX - startX) / SEGMENT)
    for i = 0, count - 1 do
      local x0 = startX + i * SEGMENT
      local x1 = math.min(finishX, x0 + SEGMENT)
      local t0, t1 = ridge(i, salt), ridge(i + 1, salt)
      local xm = (x0 + x1) * 0.5
      local tm = ridgeMid(i, salt, t0, t1)
      local zm = z + (outward < 0 and -1 or 1) * facetBulge(i, salt)
      vertical(verts, indices, x0, xm, z, zm, t0, tm,
               atlas, map.tileset, i * 2, salt,
               shade * facetShade(i, 0, salt))
      vertical(verts, indices, xm, x1, zm, z, tm, t1,
               atlas, map.tileset, i * 2 + 1, salt,
               shade * facetShade(i, 1, salt))
      local u0, u1, v0, v1 = variedUV(
        atlas, map.tileset, i * 2, -1, salt + 101)
      push(verts, indices,
           { { x0, t0, z + outward }, { xm, tm, z + outward },
             { xm, tm, zm }, { x0, t0, z } },
           u0, u1, v0, v1, capShade(i, 0, salt))
      u0, u1, v0, v1 = variedUV(
        atlas, map.tileset, i * 2 + 1, -1, salt + 101)
      push(verts, indices,
           { { xm, tm, z + outward }, { x1, t1, z + outward },
             { x1, t1, z }, { xm, tm, zm } },
           u0, u1, v0, v1, capShade(i, 1, salt))
    end
  end

  local function eastWest(x, outward, salt, shade)
    local startZ, finishZ = -OUTSET, h + OUTSET
    local count = math.ceil((finishZ - startZ) / SEGMENT)
    for i = 0, count - 1 do
      local z0 = startZ + i * SEGMENT
      local z1 = math.min(finishZ, z0 + SEGMENT)
      local t0, t1 = ridge(i, salt), ridge(i + 1, salt)
      local zm = (z0 + z1) * 0.5
      local tm = ridgeMid(i, salt, t0, t1)
      local xm = x + (outward < 0 and -1 or 1) * facetBulge(i, salt)
      vertical(verts, indices, x, xm, z0, zm, t0, tm,
               atlas, map.tileset, i * 2, salt,
               shade * facetShade(i, 0, salt))
      vertical(verts, indices, xm, x, zm, z1, tm, t1,
               atlas, map.tileset, i * 2 + 1, salt,
               shade * facetShade(i, 1, salt))
      local u0, u1, v0, v1 = variedUV(
        atlas, map.tileset, i * 2, -1, salt + 101)
      push(verts, indices,
           { { x + outward, t0, z0 }, { x, t0, z0 },
             { xm, tm, zm }, { x + outward, tm, zm } },
           u0, u1, v0, v1, capShade(i, 0, salt))
      u0, u1, v0, v1 = variedUV(
        atlas, map.tileset, i * 2 + 1, -1, salt + 101)
      push(verts, indices,
           { { x + outward, tm, zm }, { xm, tm, zm },
             { x, t1, z1 }, { x + outward, t1, z1 } },
           u0, u1, v0, v1, capShade(i, 1, salt))
    end
  end

  northSouth(-OUTSET, -DEPTH, 7, Voxel3D.FACE_SHADE[5])
  northSouth(h + OUTSET, DEPTH, 19, Voxel3D.FACE_SHADE[6])
  eastWest(-OUTSET, -DEPTH, 31, Voxel3D.FACE_SHADE[1])
  eastWest(w + OUTSET, DEPTH, 43, Voxel3D.FACE_SHADE[2])

  return Voxel3D.newMesh(verts, indices)
end

function CavePerimeter.draw(map, atlas)
  if not (map and map.tileset and map.tileset.id == "CAVERN" and atlas) then
    return false
  end
  local mesh = cache[map]
  if mesh == nil then
    mesh = build(map, atlas) or false
    cache[map] = mesh
  end
  if not mesh then return false end
  Voxel3D.draw(mesh, atlas)
  return true
end

function CavePerimeter.invalidate()
  for _, mesh in pairs(cache) do
    if mesh and mesh.release then pcall(mesh.release, mesh) end
  end
  cache = setmetatable({}, { __mode = "k" })
end

Assets.register(CavePerimeter.invalidate)

return CavePerimeter
