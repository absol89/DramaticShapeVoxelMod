-- A cut tree goes on the frame it was cut.
--
-- A block edit makes the whole map's mesh stale, and refresh() keeps the old
-- mesh drawing while the rebuild runs, so the tree stayed up for about a
-- third of a second here and longer on a phone. The prop passes now record
-- where each thing they emit lands in the vertex stream, so those vertices
-- can be zeroed in the mesh already on screen.
--
-- Picking the right runs is the part worth pinning and it is pure, so it is
-- driven here. The zeroing itself needs a real mesh and was checked in game.
--
--   luajit mods/BattleArtVoxelFork/tests/cut_drop_test.lua

package.path = "./?.lua;./?/init.lua;" .. package.path

local T = require("tests.harness")
local MOD_PATH = os.getenv("DS_MOD_PATH") or "mods/BattleArtVoxelFork"
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

local ChunkMesher = V.require("ChunkMesher")

-- ------- which vertices belong to the thing standing on a block

-- four numbers per run: first vertex, vertex count, footprint center x, z.
-- Block (1,0) is world pixels x 32..64, z 0..32.
local spans = {
  0,  6,   16, 16,   -- a prop in block (0,0)
  6,  12,  40, 8,    -- two runs inside block (1,0), adjacent in the buffer
  18, 6,   56, 24,
  24, 6,   40, 40,   -- same column, the block to the SOUTH
  30, 9,   48, 16,   -- back inside (1,0), but not adjacent to run 3
}

T.eq(#ChunkMesher.blockRanges(spans, 320, 320, 352, 352), 0,
  "a block nothing stands in selects no vertices at all")

local got = ChunkMesher.blockRanges(spans, 32, 0, 64, 32)
T.eq(#got, 2, "the runs standing in the block are selected, and only those")
T.eq(got[1][1], 6, "the first range starts where the block's first run does")
T.eq(got[1][2], 18,
  "and runs ADJACENT in the vertex buffer merge into it -- one tree comes "
  .. "out of several stamps, and each upload is a separate GPU call")
T.eq(got[2][1], 30, "a run separated by other geometry stays its own range")
T.eq(got[2][2], 9, "carrying its own length")

-- The rule is the run's CENTER, not overlap. The canopy groups are 2x2 cells
-- -- exactly one block -- so an overlap test would take the neighbouring
-- tree's canopy down with every cut.
local edge = ChunkMesher.blockRanges({ 0, 6, 31.9, 16, 6, 6, 32.1, 16 },
                                     32, 0, 64, 32)
T.eq(#edge, 1, "a run whose center sits outside the block is not selected")
T.eq(edge[1][1], 6, "and the one whose center is inside it is")

T.eq(#ChunkMesher.blockRanges(nil, 0, 0, 32, 32), 0,
  "a mesh built before spans existed selects nothing rather than throwing")

-- ------- and only the part of the block that moved
--
-- A block is 4x4 tiles and Cut swaps the whole id, but Cerulean's cuttable
-- block is one tree in the middle of a hedge: the two ids differ in a single
-- cell. Dropping the block's props wholesale took the hedge down with the
-- tree -- four times the geometry the cut actually removes.
local blocks = {}
-- tile slots are row-major, 1-based: slots 3,4,7,8 are the NE 16px cell
blocks[51] = { 1, 1, 9, 9,
               1, 1, 9, 9,
               1, 1, 1, 1,
               1, 1, 1, 1 }
blocks[110] = { 1, 1, 2, 2,
                1, 1, 2, 2,
                1, 1, 1, 1,
                1, 1, 1, 1 }
local hedge = {
  tileset = { blocks = blocks },
  blockAt = function() return 109 end,   -- blocks[] is id + 1
}

local x0, z0, x1, z1 = ChunkMesher.changedRect(hedge, 2, 3, 50)
T.eq(x0, 2 * 32 + 16, "the changed rect starts at the cell that moved")
T.eq(z0, 3 * 32, "on the row it moved in")
T.eq(x1, 2 * 32 + 32, "and ends with it")
T.eq(z1, 3 * 32 + 16,
  "-- one 16px cell of the four, not the whole block the id names")

-- a swap that changes nothing is not an edit: the door code rewrites a block
-- with the value it already holds, and that must not blank anything
T.eq(ChunkMesher.changedRect(hedge, 2, 3, 109), nil,
  "a block rewritten with the value it already held changes no rect")

-- with nothing to compare against, the whole block goes -- the behaviour
-- every caller had before the narrowing existed
local wx0, wz0, wx1, wz1 = ChunkMesher.changedRect(hedge, 2, 3, nil)
T.eq(wx0, 64, "with no previous id the rect is the whole block")
T.eq(wx1, 96, "all four tiles wide")
T.eq(wz0, 96, "from its own corner")
T.eq(wz1, 128, "and four tiles deep")
T.eq(select(1, ChunkMesher.changedRect(nil, 2, 3, 50)), 64,
  "and a map that cannot answer for its tileset falls back the same way")

-- ------- and it is inert where there is nothing to drop
--
-- the regrowth rewrites blocks on maps that are not on screen, and a warp
-- can land an edit on a map whose mesh was evicted
T.eq(ChunkMesher.dropBlock("BA_NOT_A_MAP", 3, 4), 0,
  "dropping a block from a map with no cached mesh is a no-op")
T.eq(ChunkMesher.dropBlock(nil, 3, 4), 0, "so is dropping one from no map")
T.eq(ChunkMesher.dropBlock("BA_NOT_A_MAP"), 0,
  "and so is an edit that never said which block it changed")

if T.failures > 0 then
  error(("cut drop: %d failure(s)"):format(T.failures))
end
print(("PASS cut drop (%d checks)"):format(T.checks))
