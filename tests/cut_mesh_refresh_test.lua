-- GPU-free regression for live mesh uploads and cache retention after Cut.
-- Run from the engine root with DS_MOD_PATH=dev/DramaticShapeVoxelMod.
package.path = "./?.lua;./?/init.lua;" .. package.path
local T = require("tests.harness")
local root = os.getenv("DS_MOD_PATH") or "mods/BATTLE_ART_VOXEL_FORK"
local invalidated = {}
local modules = {
  Structures = { invalidate = function(id) invalidated[#invalidated + 1] = id end },
  Voxel3D = { pushQuad = function() end, newMesh = function(v) return v end },
}
local M = assert(loadfile(root .. "/lib/ChunkMesher.lua"))({
  require = function(name) return modules[name] or {} end,
})
local function upvalue(fn, wanted)
  for i = 1, 100 do
    local name, value = debug.getupvalue(fn, i)
    if name == wanted then return value end
    if not name then break end
  end
  error("missing test seam: " .. wanted)
end
-- The table fallback must record vertex ownership too; it is also the path
-- geometry probes use when neither packed uploads nor FFI are available.
local sink = upvalue(M.geometry, "newTableSink")()
local corners = { {0, 0, 0}, {1, 0, 0}, {1, 1, 0}, {0, 1, 0} }
local uv = { {0, 0}, {0, 0}, {0, 0}, {0, 0} }
sink.push(corners, uv, 1) -- floor remains unowned
sink.own(0, 0, 16, 16)
sink.push(corners, uv, 1)
sink.own(16, 0, 32, 16)
sink.push(corners, uv, 1)
sink.own() -- unowned border must not join the last body's prop run
sink.push(corners, uv, 1)
sink.finish()
T.same(sink.spans(), { 4, 4, 8, 8, 8, 4, 24, 8 },
  "table spans exclude ground and distinguish adjacent props")

local uploads = {}
local mesh = { setVertices = function(_, data, start)
  uploads[#uploads + 1] = { bytes = data.bytes, start = start }
end }
love = { data = { newByteData = function(bytes)
  return { bytes = bytes, release = function() end }
end } }
local cache = upvalue(M.dropBlock, "cache")
local current = { full = mesh, fullSpans = sink.spans(), grass = false, flowers = false }
local neighbor = { full = {} }
cache.CUT, cache.NEIGHBOR = current, neighbor
local before, after = {}, {}
for i = 1, 16 do before[i], after[i] = 1, 1 end
after[1] = 2 -- only the north-west cell changes; the hedge stays
local map = { tileset = { blocks = { before, after } }, blockAt = function() return 1 end }
M.refresh("CUT", 0, 0, map, 0)
T.eq(#uploads, 1, "cut uploads only one owned range")
T.eq(uploads[1].start, 5, "upload starts after the ground vertices")
T.eq(uploads[1].bytes, string.rep(string.char(0), 4 * 24),
  "only the removed prop is collapsed to zero-sized triangles")
T.eq(cache.CUT, current, "current map cache remains drawable during rebuild")
T.eq(current.full, mesh, "terrain mesh is retained")
T.eq(current.stale.full, true, "replacement shading is rebuilt asynchronously")
T.eq(cache.NEIGHBOR, neighbor, "neighbour cache is retained")
T.eq(neighbor.stale, nil, "neighbour does not require rebuilding")
T.same(invalidated, { "CUT" }, "only edited map analysis is refreshed")
T.finish("cut mesh refresh")
