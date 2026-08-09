-- Figures: a person drawn INTO furniture, cut out by an authored pixel
-- mask and stood up on top of it (TileShape.figures / Structures.
-- buildFigures).  The Pokemon Center's seated man is the case the feature
-- exists for, so this drives the real profile entry over a hand-built
-- copy of the couch block he is drawn in -- POKECENTER blockset entry $08,
-- as every Center places it:
--
--     y=8   36 37 57 11        36/52 west wall strip, 37/53 the MAN,
--     y=9   52 53 60 27        57/60 floor he overhangs east onto,
--     y=10  38 39 54 11        38/39 cushion, 42/43 the couch's base
--     y=11  42 43 26 27
--
-- No love, no GPU and no pixel access: a figure is authored rather than
-- detected, which is exactly what lets it build headless.
--
--   luajit mods/DramaticShapeVoxelMod/tests/voxel_figure_test.lua

package.path = "./?.lua;./?/init.lua;" .. package.path

local T = require("tests.harness")

-- ------- the mod namespace (mirrors main.lua's V, minus the mod loader)

local ROOT = os.getenv("DS_MOD_PATH") or "mods/DramaticShapeVoxelMod"
local V = { path = ROOT }

local function chunkFor(rel)
  local f = assert(io.open(ROOT .. "/" .. rel, "rb"), rel .. " is missing")
  local src = f:read("*a")
  f:close()
  return assert(load(src, "@" .. ROOT .. "/" .. rel))
end

local modules, dataFiles = {}, {}
function V.require(name)
  if modules[name] == nil then
    modules[name] = chunkFor("lib/" .. name .. ".lua")(V)
  end
  return modules[name]
end
function V.data(name)
  if dataFiles[name] == nil then
    dataFiles[name] = chunkFor("data/" .. name .. ".lua")(V)
  end
  return dataFiles[name]
end

local TileShape = V.require("TileShape")
local Structures = V.require("Structures")

-- ------- the authored mask parses

local figs = TileShape.figures("POKECENTER")
T.check(type(figs) == "table" and #figs == 1,
  "POKECENTER carries exactly one figure")

local fig = figs[1]
T.eq(fig.w, 3, "the figure is three tiles across")
T.eq(fig.h, 2, "the figure is two tiles tall")
T.eq(fig.n, 139, "the mask claims 139 pixels of the 384 it spans")
T.check(fig.class == nil,
  "a figure carries no class -- it is always a flat sprite card")

local W = fig.w * 8
local function on(lx, ly) return fig.mask[ly * W + lx] == true end

-- the BACK OF HIS HEAD, in the two rightmost columns of tile 36 (the
-- couch's west arm): rows 0-1 are the arm, row 2 is his hair in column 7
-- only, rows 3-7 are his hair in both
T.check(not on(6, 0) and not on(7, 0) and not on(6, 1) and not on(7, 1),
  "the arm's own top rows stay with the couch")
T.check(not on(6, 2) and on(7, 2), "his hair starts in column 7 at row 2")
for ly = 3, 7 do
  T.check(on(6, ly) and on(7, ly),
    "the back of his head fills both columns at row " .. ly)
end

-- no holes in him: 37/53's column 7 (local 15) is the couch's east rule AND
-- the right side of his face, and masking it out by shade slit his cheek
for ly = 5, 8 do
  T.check(on(15, ly),
    "his cheek is solid at row " .. ly .. " (the column-7 slit)")
end

T.eq(fig.tiles[1], 36, "it starts at the couch's west arm")
T.eq(fig.tiles[2], 37, "then the tile his head is drawn in")
T.eq(fig.under[1], 52, "the arm wears the plain strip once his hair is off")
T.eq(fig.under[2], 39, "his head tile wears the couch's own cushion")
T.eq(fig.under[3], 1, "and the floor tiles wear the clean art (57 -> 1)")
T.eq(fig.under[6], 26, "and (60 -> 26)")

-- the mask is one connected figure: an overhang that floats free of him
-- is the failure this feature exists to avoid
local seen, first = {}, nil
for i in pairs(fig.mask) do first = first or i end
local stack, reached = { first }, 0
seen[first] = true
while #stack > 0 do
  local i = table.remove(stack)
  reached = reached + 1
  local x, y = i % W, math.floor(i / W)
  for dy = -1, 1 do
    for dx = -1, 1 do
      local nx, ny = x + dx, y + dy
      local ni = ny * W + nx
      if (dx ~= 0 or dy ~= 0) and nx >= 0 and nx < W
         and fig.mask[ni] and not seen[ni] then
        seen[ni] = true
        stack[#stack + 1] = ni
      end
    end
  end
end
T.eq(reached, fig.n, "the mask is a single connected figure")

-- ------- the couch block, as the Centers place it

local function keyOf(tx, ty) return (ty + 64) * 4096 + (tx + 64) end

local COUNTER = { class = "counter", h = 8, art = "upright",
                  flat = false, authored = true }
local GROUND = { class = "ground", h = 0, art = "flat",
                 flat = true, authored = false }

local BLOCK = { 36, 37, 57, 11,
                52, 53, 60, 27,
                38, 39, 54, 11,
                42, 43, 26, 27 }
local COUCH = { [36] = true, [37] = true, [38] = true, [39] = true,
                [42] = true, [43] = true, [52] = true, [53] = true }

local function scene()
  local S = { shapeAt = {}, tileAt = {}, figures = {}, skip = {},
              ground = {}, runs = {} }
  for i = 1, 16 do
    local tx, ty = (i - 1) % 4, 8 + math.floor((i - 1) / 4)
    local tile = BLOCK[i]
    S.tileAt[keyOf(tx, ty)] = tile
    S.shapeAt[keyOf(tx, ty)] = COUCH[tile] and COUNTER or GROUND
  end
  return S
end

-- collision is per 16x16 cell: the couch's cell is blocked (he is drawn
-- sitting on it), the floor cell east of it is walkable
local map = {
  tileset = { id = "POKECENTER", tilesPerRow = 16,
              imageWidth = 128, imageHeight = 48 },
  isWalkableCell = function(_, cx) return cx >= 1 end,
}

-- ------- he comes off the couch

local S = scene()
Structures.buildFigures(S, map, 0, 3, 8, 11)

T.eq(#S.figures, 1, "one figure card was built")
local card = S.figures[1]
T.eq(#card.quads, fig.n, "one quad per masked pixel, and nothing else")

T.eq(S.tileAt[keyOf(0, 8)], 52, "the arm wears the plain strip now")
T.eq(S.tileAt[keyOf(1, 8)], 39, "his head tile now wears the cushion")
T.eq(S.tileAt[keyOf(1, 9)], 39, "his body tile too")
T.eq(S.tileAt[keyOf(2, 8)], 1, "the floor he overhung is clean floor again")
T.eq(S.tileAt[keyOf(2, 9)], 26, "both rows of it")
T.eq(S.tileAt[keyOf(1, 10)], 39, "the couch's own cushion row is untouched")
T.eq(S.tileAt[keyOf(1, 11)], 43, "and so is its drawn base")

-- the couch keeps its box: a figure changes ART, never class
T.eq(S.shapeAt[keyOf(1, 8)].class, "counter",
  "his tiles are still the couch's half-cell box")
T.check(S.skip[keyOf(1, 8)] ~= true,
  "and are not skipped -- the couch still renders there")

-- ------- the card is flat, and stands at its feet

local minX, maxX, minY, maxY, minZ, maxZ
for _, q in ipairs(card.quads) do
  for c = 1, 4 do
    local p = q[c]
    minX = math.min(minX or p[1], p[1]); maxX = math.max(maxX or p[1], p[1])
    minY = math.min(minY or p[2], p[2]); maxY = math.max(maxY or p[2], p[2])
    minZ = math.min(minZ or p[3], p[3]); maxZ = math.max(maxZ or p[3], p[3])
  end
end

T.eq(minZ, 0, "the card is a single plane at z = 0 (no thickness)")
T.eq(maxZ, 0, "on both sides -- it is a sprite, not a slab")
T.eq(minY, 0, "local space: his feet are the card's origin")
T.eq(maxY, 16, "and he is his drawn 16px tall")
T.eq(minX, 0, "his west edge is the card's origin too")
T.eq(maxX, 12, "and he is 12px wide -- arm hair to floor overhang")

-- ------- and where VoxelScene stands it

T.eq(card.y, 8, "his feet stand on the couch's top face, not the floor")
T.eq(card.wx, 6, "anchored at the back of his head, in tile 36's column 6")
T.eq(card.wz, 76,
  "and pivoting at the middle of the tile row his feet are drawn in")

-- ------- a map that does not draw him builds nothing

local other = scene()
other.tileAt[keyOf(1, 8)] = 40
Structures.buildFigures(other, map, 0, 3, 8, 11)
T.eq(#other.figures, 0, "no match, no figure")
T.eq(other.tileAt[keyOf(2, 8)], 57, "and nothing repainted")

-- ------- and it never fires twice on the same drawing

local twice = scene()
Structures.buildFigures(twice, map, 0, 3, 8, 11)
Structures.buildFigures(twice, map, 0, 3, 8, 11)
T.eq(#twice.figures, 1,
  "the repaint replaces the pattern, so a rescan cannot match it again")

-- ------- prop_bg: the shades a pinned prop treats as background
--
-- The potted plants needed this: their pot's olive base is drawn flush on
-- the bottom of the plant block, so the ordinary vote (shades touching the
-- drawing's own bounding box) read "dark" as background and drained every
-- olive pixel in the plant.

local bgRules = TileShape.propBg("POKECENTER")
T.check(type(bgRules) == "table", "POKECENTER names prop background shades")
for _, tile in ipairs({ 32, 33, 34, 35, 48, 49, 50, 51 }) do
  local set = bgRules and bgRules[tile]
  T.check(type(set) == "table" and set.light and set.white
          and not set.dark and not set.black,
    "plant tile " .. tile .. ": light/white are background, dark is the pot")
end

-- and it is scoped: the healing consoles' screens and the PC keep the
-- ordinary vote, because they want the opposite call on those same shades
for _, tile in ipairs({ 58, 59, 66, 70, 74, 75, 82, 86 }) do
  T.check(bgRules[tile] == nil,
    "tile " .. tile .. " keeps the ordinary background vote")
end

-- a tileset with no prop_bg at all answers nil rather than an empty table,
-- so Structures can skip the lookup entirely
T.check(TileShape.propBg("CAVERN") == nil,
  "a tileset that names none answers nil")

T.finish("DRAMATIC_SHAPE figures")
