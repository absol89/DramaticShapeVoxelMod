-- TEST233: where the tree CROWNS are, for the battle camera.
--
-- The battle camera's spring arm (BattleSightline) and the arena search
-- (BattleArena.clearance) see the map as a grid of cells with a height each.
-- A route tree is a 16px `cylinder` cell to them -- but the Legendary tree
-- standing on that cell (WorldTrees, TEST23) is up to 47px tall with a crown
-- reaching 24px past its trunk, so a camera 38px up can sit INSIDE it, or
-- right behind it, while every cell under the shot is "clear". That is the
-- green screen in the Route 1 wild battle: the long-lens eye stood a cell
-- and a half south of the row of trees at (4..11, 23) and looked at the
-- fight through them.
--
-- This module answers the question the grid cannot: does a camera pose
-- (eye, and the lines from it to the two Pokemon) touch a crown?
--
-- The crowns are not read back from any mesh. A Legendary route tree is a
-- pure function of its cell -- WorldTrees.stamp/family pick its size,
-- variant and turn from (cx, cy) -- so the same cells the mesher stamps
-- (the OVERWORLD tree quartet 64/65/80/81, inside the map and on the tree-
-- wall ring outside it) are found from the map's tiles, and each one's crown
-- is rebuilt from the template's own lobe recipe: a handful of round leafy
-- lobes, padded by how far a leaf sprig stands off them. No template faces
-- are built (that is megabytes of tables), nothing is cached on disk, and
-- the set is made once per battle for the ground around the arena.
--
-- Everything here is a QUESTION: it changes no geometry, no settings, no
-- battle state. Callers wrap it in pcall and fall back to what they did
-- before.

local V = ...

local M = {}
M.REVISION = "battle-crowns-232"

-- How far from the arena midpoint a battle eye can be: the long lens stands
-- 165 back (BattleCam tele), a raised or hosted camera a little more. Trees
-- further than this plus their own radius can never touch a battle sightline.
M.RANGE = 272
-- A leaf sprig is 0.115..0.16 of the tree radius long (WorldTrees) and the
-- lobe surface ripples 13.5% sideways / 8% vertically; the padded lobe is
-- what the camera has to stay out of.
M.LEAF_PAD = 0.16
M.RIPPLE_H = 1.135
M.RIPPLE_V = 1.08
-- The eye keeps this much further away again: the placed camera's near
-- plane is 5% of its distance to the focus (5..9px), and an eye grazing a
-- crown still fills the lens with it.
M.EYE_MARGIN = 6
-- Sightlines aim at the middle of each Pokemon and stop this far short of
-- it: the last stretch is the Pokemon's own spot (a crown overhanging the
-- arena cell is scenery around it, not a wall in front of the lens).
M.MID_Y = 8
M.SUBJECT_END = 14

local CELL = 16
local pi = math.pi
local cos, sin, sqrt, floor, max, min, abs = math.cos, math.sin, math.sqrt,
  math.floor, math.max, math.min, math.abs

-- ------- WorldTrees lobes, from the template's own recipe
--
-- Mirrors WorldTrees.template's lobe() calls exactly (size table, lean, the
-- six side lobes, the two leaders) without building a single face.
-- validation/test232 checks this against the real templates; if WorldTrees
-- is ever retuned that check fails rather than this drifting silently.
local WT_SIZES = {
  { height = 25, radius = 9.0 },
  { height = 31, radius = 12.0 },
  { height = 39, radius = 16.5 },
  { height = 47, radius = 22.0 },
}
M.WT_SIZES = WT_SIZES

local function noise(n, s)
  local a = sin(n * 12.9898 + s * 78.233) * 43758.5453
  return a - floor(a)
end

-- raw lobes: { center = {x,y,z}, radius = {rx,ry,rz} }, template space
function M.worldLobesRaw(size, variant)
  size = max(1, min(4, size)); variant = variant % 3
  local spec = WT_SIZES[size]
  local H, R = spec.height, spec.radius
  local lean = ({ .45, -.7, 1.1 })[variant + 1] * H / 31
  local out = {}
  out[#out + 1] = { center = { lean * .7, H * .68, 0 },
                    radius = { R * .35, H * .155, R * .34 } }
  for i = 0, 5 do
    local a = i * 2 * pi / 6 + variant * .71
    local rr = R * (.57 + .10 * noise(i, variant + 15))
    local h = H * (.65 + .095 * noise(i, variant + 27))
    out[#out + 1] = {
      center = { cos(a) * rr + lean * .5, h, sin(a) * rr },
      radius = { R * (.41 + .03 * noise(i, variant + 41)),
                 H * (.13 + .025 * noise(i, variant + 45)), R * .40 },
    }
  end
  out[#out + 1] = { center = { lean - R * .16, H * .83, R * .04 },
                    radius = { R * .46, H * .14, R * .44 } }
  out[#out + 1] = { center = { lean + R * .22, H * .77, -R * .14 },
                    radius = { R * .40, H * .16, R * .43 } }
  return out, R, H
end

-- padded spheroids: { x, y, z, rh, ry } (rh: horizontal, about a vertical
-- axis, so the stamp's turn only moves the centre)
local lobeCache = {}
function M.worldLobes(size, variant)
  local key = size * 8 + variant
  local hit = lobeCache[key]
  if hit then return hit end
  local raw, R = M.worldLobesRaw(size, variant)
  local pad = R * M.LEAF_PAD
  local out = {}
  for i, l in ipairs(raw) do
    out[i] = { l.center[1], l.center[2], l.center[3],
               max(l.radius[1], l.radius[3]) * M.RIPPLE_H + pad,
               l.radius[2] * M.RIPPLE_V + pad }
  end
  lobeCache[key] = out
  return out
end

-- one placed tree: world lobes plus a bounding sphere for quick rejection
local function placeWorldTree(WT, cx, cy, ox, oz, lift)
  local size, variant = WT.family(cx, cy)
  local lobes = M.worldLobes(size, variant)
  -- WorldTrees.stamp: the same turn and centre the mesher uses
  local a = ((cx * 11 + cy * 7) % 16) * 2 * pi / 16
  local c, s = cos(a), sin(a)
  local mx, mz = cx * CELL + 8 + ox, cy * CELL + 8 + oz
  local tree = { cx = cx, cy = cy, size = size, x = mx, z = mz, lobes = {} }
  local lo, hi, reach = math.huge, -math.huge, 0
  for i, l in ipairs(lobes) do
    local x = mx + l[1] * c - l[3] * s
    local z = mz + l[1] * s + l[3] * c
    local y = l[2] + lift
    tree.lobes[i] = { x, y, z, l[4], l[5] }
    lo = min(lo, y - l[5]); hi = max(hi, y + l[5])
    reach = max(reach, sqrt((x - mx) ^ 2 + (z - mz) ^ 2) + l[4])
  end
  tree.bottom, tree.top, tree.reach = lo, hi, reach
  tree.y = (lo + hi) / 2
  tree.r = sqrt(reach * reach + ((hi - lo) / 2) ^ 2)
  return tree
end

-- ------- which cells carry a Legendary route tree
--
-- Structures stamps WorldTrees on an OVERWORLD map wherever a cell's four
-- tiles are the tree quartet 64/65/80/81 (classed `cylinder`), inside the
-- map and on the ring of border blocks around it -- out to ROUND_RING (four
-- tiles, two cells), and only when the void fill is the tree wall.
local TREE_Q = { 64, 65, 80, 81 }
local ROUND_RING_CELLS = 2

local function worldTreesOn(map)
  local ok, WT = pcall(V.require, "WorldTrees")
  if not (ok and WT and WT.enabled) then return nil end
  local okE, on = pcall(WT.enabled, map)
  return (okE and on) and WT or nil
end

local function ringBlock(map)
  local ok, TR = pcall(require, "src.render.TileRenderer")
  if not (ok and TR and TR.borderBlockFor) then return nil end
  local okB, id = pcall(TR.borderBlockFor, map)
  if not (okB and id) then return nil end
  local blocks = map.tileset and map.tileset.blocks
  return blocks and blocks[id + 1] or nil
end

local function treeQuartet(tile, cx, cy)
  return tile(cx * 2, cy * 2) == TREE_Q[1]
     and tile(cx * 2 + 1, cy * 2) == TREE_Q[2]
     and tile(cx * 2, cy * 2 + 1) == TREE_Q[3]
     and tile(cx * 2 + 1, cy * 2 + 1) == TREE_Q[4]
end

-- add the map's crowns that can reach the disc (wx, wz, radius); ox/oz is
-- the map's world offset (a connected neighbour), `covered(x, z)` says a
-- ring cell's world centre is really another map's ground
local function addWorldTrees(out, map, ox, oz, wx, wz, radius, ring, covered)
  local WT = worldTreesOn(map)
  if not WT then return 0 end
  local W, H = map.widthCells, map.heightCells
  if not (W and H) then return 0 end
  local border = ring and ringBlock(map) or nil
  local function tile(tx, ty)
    if tx >= 0 and ty >= 0 and tx < W * 2 and ty < H * 2 then
      return map:tileAt(tx, ty)
    end
    if not border then return nil end
    return border[(ty % 4) * 4 + (tx % 4) + 1]
  end
  -- a tree reaches at most ~26px from its cell centre (XL crown + leaves)
  local pad = 32
  local lx, lz = wx - ox, wz - oz
  local cx0 = floor((lx - radius - pad) / CELL)
  local cx1 = floor((lx + radius + pad) / CELL)
  local cy0 = floor((lz - radius - pad) / CELL)
  local cy1 = floor((lz + radius + pad) / CELL)
  local r0 = border and -ROUND_RING_CELLS or 0
  cx0 = max(cx0, r0); cy0 = max(cy0, r0)
  cx1 = min(cx1, W - 1 - r0); cy1 = min(cy1, H - 1 - r0)
  local n = 0
  for cy = cy0, cy1 do
    for cx = cx0, cx1 do
      local inside = cx >= 0 and cy >= 0 and cx < W and cy < H
      if (inside or not (covered and covered(cx * CELL + 8 + ox,
                                              cy * CELL + 8 + oz)))
         and treeQuartet(tile, cx, cy) then
        local dx, dz = cx * CELL + 8 - lx, cy * CELL + 8 - lz
        if dx * dx + dz * dz <= (radius + pad) ^ 2 then
          out[#out + 1] = placeWorldTree(WT, cx, cy, ox, oz, 0)
          n = n + 1
        end
      end
    end
  end
  return n
end

-- the overworld's own neighbour list, when the host is the map being walked
-- (BattleScene draws exactly these around the arena)
local function liveNeighbors(map)
  local ok, Game = pcall(require, "src.core.Game")
  local ow = ok and Game and Game.overworld
  if ow and ow.map == map and type(ow.neighbors) == "table" then
    return ow.neighbors
  end
  return nil
end

-- ------- the set for one battle
--
-- Built once per arena (and per tree setting), from the tiles; a later call
-- for the same arena returns the same table.
local setCache = { key = nil, set = nil }
local NONE = {}

local function treesOn()
  local ok, CV = pcall(V.require, "CommunityVisuals")
  return (ok and CV and CV.customTrees and CV.customTrees()) and true or false
end

local function voidFill()
  local okR, TR = pcall(require, "src.render.TileRenderer")
  return okR and TR and TR.voidFill or "trees"
end

function M.forArena(map, arena, neighbors)
  if not (map and arena and arena.mid) then return nil end
  neighbors = neighbors or liveNeighbors(map) or NONE
  local mx, mz = arena.mid[1], arena.mid[2]
  local on, fill = treesOn(), voidFill()
  -- the per-frame path: same arena, same neighbours, same settings
  local c = setCache
  if c.set and c.map == map and c.mx == mx and c.mz == mz and c.on == on
     and c.fill == fill and c.nb == neighbors and c.nbn == #neighbors then
    return c.set
  end
  local parts = { tostring(map.id), mx, mz, on and "T" or "-", tostring(fill) }
  for _, nb in ipairs(neighbors) do
    parts[#parts + 1] = tostring(nb.map and nb.map.id) .. "@"
      .. tostring(nb.ox) .. "," .. tostring(nb.oy)
  end
  local key = table.concat(parts, "|")
  if c.key == key and c.set then
    c.map, c.mx, c.mz, c.on, c.fill, c.nb, c.nbn = map, mx, mz, on, fill,
      neighbors, #neighbors
    return c.set
  end

  local trees = {}
  -- ring cells that a connected neighbour actually covers are its ground
  local rects = {}
  for _, nb in ipairs(neighbors) do
    local m = nb.map
    if m and m.widthCells then
      rects[#rects + 1] = { nb.ox or 0, nb.oy or 0,
        (nb.ox or 0) + m.widthCells * CELL, (nb.oy or 0) + m.heightCells * CELL }
    end
  end
  local function covered(x, z)
    for _, r in ipairs(rects) do
      if x >= r[1] and z >= r[2] and x < r[3] and z < r[4] then return true end
    end
    return false
  end
  addWorldTrees(trees, map, 0, 0, mx, mz, M.RANGE, true, covered)
  for _, nb in ipairs(neighbors) do
    if nb.map and nb.map ~= map then
      addWorldTrees(trees, nb.map, nb.ox or 0, nb.oy or 0, mx, mz, M.RANGE,
                    false, nil)
    end
  end
  local set = { key = key, trees = trees, count = #trees }
  setCache = { key = key, set = set, map = map, mx = mx, mz = mz, on = on,
               fill = fill, nb = neighbors, nbn = #neighbors }
  return set
end

function M.reset()
  setCache = { key = nil, set = nil }
end

-- ------- the tests

-- Normalised distance of a point from a lobe (< 1 inside), with `grow`
-- added to both radii.
local function lobeInside(l, x, y, z, grow)
  local rh, ry = l[4] + grow, l[5] + grow
  local dx, dy, dz = (x - l[1]) / rh, (y - l[2]) / ry, (z - l[3]) / rh
  return dx * dx + dy * dy + dz * dz < 1
end

-- First fraction in [0, smax] at which the segment a + s*(b - a) enters
-- the lobe, or nil.
local function lobeHit(l, ax, ay, az, dx, dy, dz, smax)
  local rh, ry = l[4], l[5]
  local px, py, pz = (ax - l[1]) / rh, (ay - l[2]) / ry, (az - l[3]) / rh
  local qx, qy, qz = dx / rh, dy / ry, dz / rh
  local A = qx * qx + qy * qy + qz * qz
  if A < 1e-12 then return nil end
  local B = 2 * (px * qx + py * qy + pz * qz)
  local C = px * px + py * py + pz * pz - 1
  local disc = B * B - 4 * A * C
  if disc < 0 then return nil end
  local r = sqrt(disc)
  local s1 = (-B - r) / (2 * A)
  local s2 = (-B + r) / (2 * A)
  if s2 < 0 or s1 > smax then return nil end
  return max(0, s1)
end

-- Is `eye` inside (or within `grow` px of) a crown? Returns the tree.
function M.eyeInside(set, x, y, z, grow)
  if not (set and set.trees) then return nil end
  grow = grow or M.EYE_MARGIN
  for _, t in ipairs(set.trees) do
    local dx, dz = x - t.x, z - t.z
    local rr = t.reach + grow
    if dx * dx + dz * dz <= rr * rr
       and y >= t.bottom - grow and y <= t.top + grow then
      for _, l in ipairs(t.lobes) do
        if lobeInside(l, x, y, z, grow) then return t end
      end
    end
  end
  return nil
end

-- First crown the segment a -> b passes through, stopping `stopShort` px
-- before b. Returns the fraction along a -> b and the tree.
function M.segmentHit(set, a, b, stopShort)
  if not (set and set.trees) then return nil end
  local dx, dy, dz = b[1] - a[1], b[2] - a[2], b[3] - a[3]
  local len = sqrt(dx * dx + dy * dy + dz * dz)
  if len < 1e-6 then return nil end
  local smax = 1 - (stopShort or 0) / len
  if smax <= 0 then return nil end
  local best, who = nil, nil
  for _, t in ipairs(set.trees) do
    -- bounding sphere vs segment
    local fx, fy, fz = t.x - a[1], t.y - a[2], t.z - a[3]
    local s = (fx * dx + fy * dy + fz * dz) / (len * len)
    s = max(0, min(smax, s))
    local cx, cy, cz = a[1] + dx * s - t.x, a[2] + dy * s - t.y,
                       a[3] + dz * s - t.z
    if cx * cx + cy * cy + cz * cz <= t.r * t.r then
      for _, l in ipairs(t.lobes) do
        local h = lobeHit(l, a[1], a[2], a[3], dx, dy, dz, smax)
        if h and (not best or h < best) then best, who = h, t end
      end
    end
  end
  return best, who
end

-- The two points a battle shot has to SEE: the middle of each Pokemon.
function M.targets(arena, groundY)
  local g = (groundY or 0) + M.MID_Y
  return { arena.player[1], g, arena.player[2] },
         { arena.enemy[1], g, arena.enemy[2] }
end

-- Whether a camera at `eye` is clear of every crown: not inside one, and
-- its sightlines (to both Pokemon, and optionally to the frame centre `aim`)
-- free of them. Returns clear, why, tree, fraction.
function M.poseClear(set, eye, targetA, targetB, aim)
  if not (set and set.count and set.count > 0) then return true end
  local inside = M.eyeInside(set, eye[1], eye[2], eye[3])
  if inside then return false, "inside", inside end
  local s, tree = nil, nil
  if targetA then s, tree = M.segmentHit(set, eye, targetA, M.SUBJECT_END) end
  if not s and targetB then s, tree = M.segmentHit(set, eye, targetB, M.SUBJECT_END) end
  if not s and aim then s, tree = M.segmentHit(set, eye, aim, M.SUBJECT_END) end
  if s then return false, "behind", tree, s end
  return true
end

-- The spring-arm answer for crowns: the longest arm k in (kMin, kStart]
-- (the eye at focus + k * (eye - focus)) whose pose is crown-clear, tried
-- in `step`s from kStart down. nil when no pose on the arm is clear.
M.ARM_STEP = 0.02
function M.clearArm(set, focus, eye, targetA, targetB, kStart, kMin)
  kStart = kStart or 1
  kMin = kMin or 0.3
  if not (set and set.count and set.count > 0) then return kStart end
  local dx, dy, dz = eye[1] - focus[1], eye[2] - focus[2], eye[3] - focus[3]
  local k = kStart
  local p = {}
  while k >= kMin - 1e-9 do
    p[1], p[2], p[3] = focus[1] + dx * k, focus[2] + dy * k, focus[3] + dz * k
    if M.poseClear(set, p, targetA, targetB, focus) then return k end
    k = k - M.ARM_STEP
  end
  return nil
end

-- Is the pose at arm k (eye = focus + k * (eye - focus)) crown-clear?
function M.armClear(set, focus, eye, targetA, targetB, k)
  local p = { focus[1] + (eye[1] - focus[1]) * k,
              focus[2] + (eye[2] - focus[2]) * k,
              focus[3] + (eye[3] - focus[3]) * k }
  return (M.poseClear(set, p, targetA, targetB, focus))
end

return M
