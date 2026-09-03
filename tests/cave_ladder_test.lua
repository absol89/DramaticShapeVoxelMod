-- The cave ladders must be ladders, not staircases.
--
-- Gen 1 draws both cave ladder graphics from ABOVE, as a shaft with two
-- rails and rungs between them, and the warp table says which is which:
-- across all nineteen cave maps every one of the 37 $08 cells warps to a
-- lower floor and every one of the 40 $0A cells to a higher one, 77 cells
-- with no exceptions.
--
-- They used to be pinned `stair_e` / `stair_down_e`.  A staircase runs
-- along an AXIS, so that threw a four-step stepped wedge across a cell
-- whose drawing is a ladder lying in it -- the profile's own note conceded
-- the flight was only "as close to a drawn ladder as stepped geometry
-- gets".  They are a standee pool now: the same per-pixel object pass that
-- builds signs, posts and bicycles stands the drawing up and voxelizes it.
--
-- There is no ladder-specific builder, by design, so the whole fix is
-- vocabulary and a pin -- which is exactly what can be silently undone.
-- A pin naming a class TileShape does not know is DEAD (heights() drops it
-- and the tile falls through to detection saying nothing), and an `art`
-- that is not "billboard" would route these cells to the box builder and
-- render a wall wearing ladder art.  Both are checked here.
--
--   DS_MOD_PATH=mods/BattleArtVoxelFork \
--     luajit mods/BattleArtVoxelFork/tests/cave_ladder_test.lua

package.path = "./?.lua;./?/init.lua;" .. package.path

local T = require("tests.harness")
local MOD_PATH = os.getenv("DS_MOD_PATH") or "mods/DramaticShapeVoxelMod"
local ROOT = os.getenv("DS_REPO_ROOT") or "."
local base = ROOT .. "/" .. MOD_PATH
local modules, dataFiles = {}, {}
local V = {}
function V.require(name)
  if modules[name] ~= nil then return modules[name] end
  local value = assert(loadfile(base .. "/lib/" .. name .. ".lua"))(V)
  modules[name] = value
  return value
end
function V.data(name)
  if dataFiles[name] ~= nil then return dataFiles[name] end
  local value = assert(loadfile(base .. "/data/" .. name .. ".lua"))(V)
  dataFiles[name] = value
  return value
end

local TileShape = V.require("TileShape")
local Structures = V.require("Structures")
local spec = V.data("voxel_heights")

-- PINNED_DEPTH is a file local, and the function that reads it is a local
-- too, so no exported function closes over it directly -- an exported one
-- closes over the LOCAL FUNCTION, which closes over the table.  Walk the
-- upvalue graph rather than naming a function that happens to reach it
-- today, and identify the table by its shape so a rename does not blind
-- the check.
local function findDepthTable(root)
  local seen = {}
  local function walk(fn, depth)
    if depth > 4 or seen[fn] then return nil end
    seen[fn] = true
    for i = 1, 200 do
      local name, value = debug.getupvalue(fn, i)
      if not name then break end
      if type(value) == "table" and type(value.bike) == "number"
         and type(value.billboard) == "number" then
        return value
      end
      if type(value) == "function" then
        local hit = walk(value, depth + 1)
        if hit then return hit end
      end
    end
    return nil
  end
  for _, v in pairs(root) do
    if type(v) == "function" then
      local hit = walk(v, 1)
      if hit then return hit end
    end
  end
  return nil
end

-- ---- the class exists and is a standee ----

local heights = TileShape.heights()
T.eq(heights.ladder, 16, "a ladder stands the height of the rock band")

local cavern = spec.tilesets.CAVERN
T.eq(table.concat(cavern.ladder or {}, ","), "10,11,26,27,8,9,24,25",
  "both ladder graphics pin `ladder`: $0A/$0B over $1A/$1B (the cells that "
  .. "warp UP) and $08/$09 over $18/$19 (the ones that warp DOWN)")
T.check(cavern.stair_e == nil and cavern.stair_down_e == nil,
  "and nothing in the caves is pinned to a staircase any more")

-- ---- it reaches the per-pixel object pass ----

local shapes = TileShape.forMap({
  tileset = { id = "CAVERN", image = "gfx/tilesets/ds_cave.png",
              tilesPerRow = 16, imageWidth = 128, imageHeight = 48,
              blocks = {}, grassTile = -1 },
})
for _, tile in ipairs({ 10, 11, 26, 27, 8, 9, 24, 25 }) do
  local s = shapes[tile]
  T.check(s ~= nil and s.class == "ladder",
    ("tile %d resolves to `ladder`"):format(tile))
  T.check(s ~= nil and s.art == "billboard",
    ("tile %d reaches the per-pixel object pass, not the box builder")
    :format(tile))
  T.check(s ~= nil and s.authored == true,
    ("tile %d is authored, so detection cannot overrule it"):format(tile))
  T.eq(s and s.h, 16, ("tile %d stands the full rock band"):format(tile))
end

-- ---- and it carves at the thickness that keeps the rungs apart ----

-- A ladder is mostly the air between its rungs, and that negative space is
-- what makes it read as a ladder from anywhere but dead-on.  At the 10 the
-- default standee pool gives, the side faces of neighbouring rungs close
-- every gap off-axis and the drawing silts up into a plate.  Two is the
-- `bike` figure and it is here for the same reason a bicycle needs it.
local depth = findDepthTable(Structures)
T.check(depth ~= nil, "the standee depth table is reachable to check")
if depth then
  T.eq(depth.ladder, 2, "a ladder carves two voxels thick, like `bike`")
end

-- ---- no dead pins anywhere in the profile ----

-- This has already cost this profile once: Celadon's four staircases were
-- pinned onto door tiles and silently did nothing.  A tileset entry holds
-- class pins alongside its own settings (`heights`, `figures`,
-- `when_above`, ...), and the two are told apart by SHAPE rather than by a
-- list of reserved names a later setting would fall off of -- a class pin
-- is an array of tile NUMBERS, every setting is keyed by tile or is an
-- array of tables.
local dead = {}
for setId, entry in pairs(spec.tilesets) do
  for class, tiles in pairs(entry) do
    if type(tiles) == "table" and type(tiles[1]) == "number"
       and heights[class] == nil then
      dead[#dead + 1] = setId .. "." .. class
    end
  end
end
table.sort(dead)
T.eq(#dead, 0, "every class the profile pins is one TileShape resolves: "
  .. table.concat(dead, ", "))

if T.failures > 0 then
  error(("cave ladders: %d failure(s)"):format(T.failures))
end
print(("PASS cave ladders (%d checks)"):format(T.checks))
