-- Voxel world mode: turn a map's tile layer into one static 3D mesh.
--
-- The scene description comes from Structures.lua, which -- 3dSen-style --
-- detects each connected drawn thing on the map and picks its model:
--
--   flat      ground / water / void: a single quad.
--   top art   ledges, roofs (profile-authored): a box with the art on its
--             TOP face; partial side bands crop the art (a 6px ledge face
--             is the bottom of the lip drawing).
--   volume    walls, buildings, tree lines: each column rises to the
--             structure's REAL drawn height (Structures measures it,
--             repeat-aware and region-consistent -- a 6-row house is 48px,
--             a 40-row border forest is rows of 16px trees). The south
--             face folds the full artwork upright, 8px band by band, band
--             k sampling the map row k tiles north; the top wears the
--             structure's top rows.
--   object    small props with a silhouette (plants, signs, lone trees):
--             per-pixel voxel prisms prebuilt by Structures, standing on
--             synthesized ground -- this mesher just emits their quads.
--             Round trees arrive as STAMPS (a shared hull template plus a
--             cell offset) and expand here, straight into the vertex
--             stream, so no map retains per-cell copies of its forests.
--
-- Side faces are never stretched: all sides are 8px bands with the art
-- tiled per band and cropped at partial bands.
--
-- Texturing samples the TILESET ATLAS, not a rendered copy of the map. The
-- atlas is 128x48; a map-space canvas covering the biggest routes would be
-- ~5 MB each with up to five live at once (connected maps), which is real
-- memory on the mobile targets. Sampling the atlas costs 24 KB, and costs
-- nothing in fidelity because TerrainAtlas hands back the same atlas
-- TileRenderer draws with -- including the fully recolored one RED++
-- bakes -- so terrain color comes through untouched.
--
-- BUILDS ARE ASYNCHRONOUS. A frame never blocks on meshing: VoxelScene
-- requests what it wants to draw, request() queues a build job, and
-- pump() -- called once a frame from the pipeline's update -- advances
-- the queue inside a few-millisecond budget (BuildBudget suspends the
-- job's coroutine mid-loop when the slice is spent). Until a mesh lands
-- the scene simply draws without it: the engine's flat path while the
-- current map has nothing, the body-only variant while the full one (the
-- border ring) is still cooking, neighbours popping in as they finish.
-- The synchronous get() remains for probes and tests.
--
-- Meshes are cached per map id and EVICTED down to the live set (current
-- map + connected neighbours) whenever that set changes -- setLive()
-- releases far maps' GPU meshes and their Structures analysis, which is
-- what used to grow the heap by gigabytes over a cross-region trek.

-- the mod namespace (see main.lua): V.require loads a sibling module
local V = ...

local Assets = require("src.render.Assets")
local Structures = V.require("Structures")
local TileShape = V.require("TileShape")
local Voxel3D = V.require("Voxel3D")
local Budget = V.require("BuildBudget")
local MeshDisk = V.require("VoxelMeshDisk")

local ffi = nil
do
  local ok, mod = pcall(require, "ffi")
  if ok then ffi = mod end
end

local ChunkMesher = {}

local function visualObjectVisible(id)
  if id == nil then return true end
  local companion = V.companion
  if not (companion and type(companion.suppressesVisualObject) == "function") then
    return true
  end
  local ok, suppressed = pcall(companion.suppressesVisualObject, companion, id)
  return not (ok and suppressed == true)
end

-- Small host-test seam used by the ROM-free contract suite.
ChunkMesher.visualObjectVisible = visualObjectVisible

-- True only when Structures produced geometry that this mesher can route to
-- the named sidecar. Catalog callers use this instead of assuming that a
-- sign-class map cell survived object extraction as one suppressible mesh.
-- Analysis faults fail closed: the ordinary terrain path remains untouched.
function ChunkMesher.visualObjectAnnotated(map, id)
  if type(map) ~= "table" or type(id) ~= "string" then return false end
  local ok, analysis = pcall(Structures.forMap, map)
  if not ok or type(analysis) ~= "table" then return false end
  for _, quad in ipairs(analysis.objectQuads or {}) do
    if quad.visualObjectId == id then return true end
  end
  return false
end

-- Which drawn row a FLAT-topped volume's top face wears at depth `ty`.
--
-- A structure is usually deeper than the art that draws it, so the rows
-- cycle and the drawing repeats down the top. That is right for art which
-- genuinely repeats -- the Safari Zone's fence alternates two tiles the
-- whole way down -- and wrong for a RIM over a uniform body: a cliff
-- mound's first row is its top edge, and cycling lays that edge again
-- every second tile, striping a plateau with rims it should not have.
--
-- Where Structures found the body uniform, the rim is laid once at the
-- north edge and the body held after it. Everything else cycles as before.
function ChunkMesher.flatTopRow(run, ty)
  local m = math.min(2, run.extent)
  local d = ty - run.north
  if run.topUniform then
    return run.north + math.min(d, m - 1)
  end
  return run.north + (d % m)
end

-- Ring of border blocks meshed around the body, matching the width
-- TileRenderer draws so the two modes end at the same place.
local RING = 3

-- A sliver of a texel, to keep a quad's sampling inside its own tile.
-- Without any inset the perspective rasteriser lands on a NEIGHBOURING
-- tile's texel along the shared edge and stitches bright seams across the
-- whole map.
--
-- It has to be a sliver and not, as it first was, half a texel. A tile is
-- 8 texels of art across 8 world pixels -- one texel per pixel exactly --
-- and insetting the uv by half a texel at each end squeezes that art into
-- a 7-texel sample range while the quad still covers 8 world pixels. The
-- art then advances 7/8 of a texel per pixel: boundaries drift off the
-- pixel grid, one art pixel gets sampled twice and another never at all.
-- Nothing showed it until the voxel wireframe drew the grid those pixels
-- were supposed to be sitting on. Interpolation error is nowhere near a
-- fiftieth of a texel, so this is as safe against bleed and costs 0.25% of
-- a pixel of drift across a whole tile.
local INSET = 0.02

-- The south face of a volume is the artwork itself, so it draws at full
-- brightness; its top face darkens a touch so the plateau behind a
-- standing drawing reads as depth rather than repeating the same art at
-- the same energy.
local VOLUME_TOP_SHADE = 0.85

local cache = {}     -- map id -> { full = mesh|false, body = ..., grass = ... }
local gen = {}       -- map id -> generation, bumped by invalidate/evict

-- Horizontal neighbours: tile step, face direction id (see Voxel3D).
local SIDES = {
  { 1, 0, 1 },    -- +X east
  { -1, 0, 2 },   -- -X west
  { 0, 1, 5 },    -- +Z south
  { 0, -1, 6 },   -- -Z north
}

local function keyOf(tx, ty)
  return (ty + 64) * 4096 + (tx + 64)
end

-- ------------------------------------------------------------ vertex sinks

-- A sink accepts quads (4 corners, 4 uv pairs, flat or per-corner shade)
-- and finishes into a drawable mesh. The TABLE sink reproduces the
-- historical pure-Lua output -- geometry() returns its arrays for the
-- headless suite. The FFI sink packs the same six floats per vertex
-- straight into one growing native buffer, unindexed (v1 v2 v3 v1 v3 v4),
-- skipping ~a million short-lived Lua tables per route and LOVE's slow
-- table-by-table vertex upload.

local function newTableSink()
  local verts, indices, quads = {}, {}, 0
  local spans = newSpans(function() return #verts end)
  return {
    own = spans.own,
    spans = spans.runs,
    push = function(c, uv, shade)
      local flat = type(shade) ~= "table"
      for i = 1, 4 do
        local cc, t = c[i], uv[i]
        verts[#verts + 1] = { cc[1], cc[2], cc[3], t[1], t[2],
                              flat and shade or shade[i] }
      end
      Voxel3D.pushQuad(indices, quads)
      quads = quads + 1
    end,
    results = function()
      spans.close()
      return verts, indices, quads
    end,
    finish = function()
      spans.close()
      return Voxel3D.newMesh(verts, indices)
    end,
  }
end

local TRI_ORDER = { 1, 2, 3, 1, 3, 4 }

-- Sandboxed engines no longer expose FFI to mod-authored chunks. LOVE's own
-- binary packer still gives newMesh the same tightly packed six-float stream,
-- without the historical fallback's table per vertex and million-table heap
-- pressure on large routes. Strings are folded into moderate chunks as they
-- are emitted, then uploaded cooperatively just like the FFI path.
-- ------------------------------------------------------------------ spans
--
-- Records where each prop a sink was handed ended up in the vertex stream.
-- own(x0, z0, x1, z1) closes the previous run and opens one owned by that
-- world-pixel footprint. Only the prop passes call it. The tile loop's
-- ground is what a prop stands on, so dropping that would leave a hole.
--
-- This is what lets Cut take a tree out of the mesh already on screen. The
-- rebuild after a block edit takes about a third of a second here and longer
-- on a phone, and refresh() keeps the old mesh drawing while it runs, so the
-- tree stayed up for all of it.
--
-- One flat array of numbers, four per run (first vertex, vertex count,
-- footprint center x and z). It rides along with every cached mesh, on disk
-- as well as in memory, so a table per run would be wasteful.
local function newSpans(count)
  local runs, first, cx, cz = {}, nil, 0, 0
  local function close()
    if not first then return end
    local n = count() - first
    if n > 0 then
      runs[#runs + 1] = first
      runs[#runs + 1] = n
      runs[#runs + 1] = cx
      runs[#runs + 1] = cz
    end
    first = nil
  end
  return {
    own = function(x0, z0, x1, z1)
      close()
      first, cx, cz = count(), (x0 + x1) / 2, (z0 + z1) / 2
    end,
    close = close,
    runs = function() close() return runs end,
  }
end

local PACKED_VERTEX = "<" .. string.rep("f", 6 * 6)
local PACKED_VERTEX_BYTES = 6 * 4
local PACKED_QUADS_PER_CHUNK = 4096

local function newPackedSink()
  local chunks, parts, values = {}, {}, {}
  local quads, n = 0, 0
  local spans = newSpans(function() return n end)

  local function flush()
    if #parts == 0 then return end
    chunks[#chunks + 1] = table.concat(parts)
    parts = {}
  end

  return {
    own = spans.own,
    spans = spans.runs,
    push = function(c, uv, shade)
      local flat = type(shade) ~= "table"
      local at = 1
      for k = 1, 6 do
        local i = TRI_ORDER[k]
        local cc, t = c[i], uv[i]
        values[at], values[at + 1], values[at + 2] = cc[1], cc[2], cc[3]
        values[at + 3], values[at + 4] = t[1], t[2]
        values[at + 5] = flat and shade or shade[i]
        at = at + 6
      end
      parts[#parts + 1] = love.data.pack(
        "string", PACKED_VERTEX, unpack(values, 1, 36))
      quads, n = quads + 1, n + 6
      if quads % PACKED_QUADS_PER_CHUNK == 0 then flush() end
    end,
    finish = function()
      spans.close()
      if n == 0 then return nil end
      flush()
      local ok, mesh = pcall(function()
        local result = love.graphics.newMesh(Voxel3D.FORMAT, n,
                                             "triangles", "static")
        local first = 1
        for _, chunk in ipairs(chunks) do
          local data = love.data.newByteData(chunk)
          result:setVertices(data, first)
          first = first + math.floor(#chunk / PACKED_VERTEX_BYTES)
          data:release()
          Budget.check()
        end
        return result
      end)
      chunks, parts = {}, {}
      return ok and mesh or nil
    end,
    raw = function()
      flush()
      return { chunks = chunks, n = n, spans = spans.runs() }
    end,
  }
end

local function newFfiSink()
  local cap = 4096 * 6
  local buf = ffi.new("float[?]", cap * 6)
  local n = 0
  local spans = newSpans(function() return n end)
  local sink
  sink = {
    own = spans.own,
    spans = spans.runs,
    push = function(c, uv, shade)
      if n + 6 > cap then
        local grown = ffi.new("float[?]", cap * 2 * 6)
        ffi.copy(grown, buf, n * 6 * 4)
        buf, cap = grown, cap * 2
      end
      local flat = type(shade) ~= "table"
      local base = n * 6
      for k = 1, 6 do
        local i = TRI_ORDER[k]
        local cc, t = c[i], uv[i]
        buf[base] = cc[1]
        buf[base + 1] = cc[2]
        buf[base + 2] = cc[3]
        buf[base + 3] = t[1]
        buf[base + 4] = t[2]
        buf[base + 5] = flat and shade or shade[i]
        base = base + 6
      end
      n = n + 6
    end,
    finish = function()
      spans.close()
      if n == 0 then return nil end
      -- upload in slices with budget ticks between: a route-sized mesh
      -- is ~10-20MB and one atomic setVertices was the last remaining
      -- frame spike. The mesh is not cached (so never drawn) until the
      -- whole upload lands, and LuaJIT yields fine across pcall.
      local ok, mesh = pcall(function()
        local m = love.graphics.newMesh(Voxel3D.FORMAT, n,
                                        "triangles", "static")
        local CHUNK = 65536              -- vertices per slice (~1.5MB)
        local i = 0
        while i < n do
          local count = math.min(CHUNK, n - i)
          local bytes = count * 6 * 4
          local data = love.data.newByteData(bytes)
          ffi.copy(data:getFFIPointer(), buf + i * 6, bytes)
          m:setVertices(data, i + 1)
          data:release()
          i = i + count
          Budget.check()
        end
        return m
      end)
      return ok and mesh or nil
    end,
    raw = function()
      return { ptr = buf, n = n, spans = spans.runs() }
    end,
  }
  return sink
end

local function newSink()
  -- 0.1.83 and older retain the native filesystem/FFI path. Sandboxed mobile
  -- releases use LOVE's packer and mod.storage instead.
  if MeshDisk.available() and MeshDisk.legacy() and ffi
     and love and love.data and love.data.newByteData
     and love.graphics and love.graphics.newMesh then
    return newFfiSink()
  end
  if MeshDisk.available() and love and love.data and love.data.pack
     and love.data.newByteData and love.graphics and love.graphics.newMesh then
    return newPackedSink()
  end
  if ffi and love and love.data and love.data.newByteData
     and love.graphics and love.graphics.newMesh then
    return newFfiSink()
  end
  if love and love.data and love.data.pack and love.data.newByteData
     and love.graphics and love.graphics.newMesh then
    return newPackedSink()
  end
  return newTableSink()
end

-- Upload one cached/fresh packed stream in bounded vertex-aligned slices.
local function meshFromRaw(record)
  if not (record and record.n and record.n > 0) then return nil end
  if record.ptr and ffi then
    local ok, mesh = pcall(function()
      local result = love.graphics.newMesh(Voxel3D.FORMAT, record.n,
                                           "triangles", "static")
      local first = 0
      while first < record.n do
        local count = math.min(65536, record.n - first)
        local byteCount = count * PACKED_VERTEX_BYTES
        local data = love.data.newByteData(byteCount)
        ffi.copy(data:getFFIPointer(),
          ffi.cast("const uint8_t*", record.ptr)
            + first * PACKED_VERTEX_BYTES, byteCount)
        result:setVertices(data, first + 1)
        data:release()
        first = first + count
        Budget.check()
      end
      return result
    end)
    return ok and mesh or nil
  end
  if not record.chunks then return nil end
  local ok, mesh = pcall(function()
    local result = love.graphics.newMesh(Voxel3D.FORMAT, record.n,
                                         "triangles", "static")
    local first, carry = 1, ""
    for _, chunk in ipairs(record.chunks) do
      local bytes = carry .. chunk
      local usable = math.floor(#bytes / PACKED_VERTEX_BYTES)
                     * PACKED_VERTEX_BYTES
      carry = bytes:sub(usable + 1)
      if usable > 0 then
        local data = love.data.newByteData(bytes:sub(1, usable))
        result:setVertices(data, first)
        first = first + usable / PACKED_VERTEX_BYTES
        data:release()
      end
      Budget.check()
    end
    if #carry ~= 0 or first ~= record.n + 1 then
      error("invalid packed voxel vertex stream", 0)
    end
    return result
  end)
  -- setVertices copied every slice into the Mesh; release the decoded strings
  -- immediately instead of retaining a second world-sized CPU representation.
  record.chunks = nil
  return ok and mesh or nil
end

-- -------------------------------------------------------------- geometry

-- Emit the raw geometry for `map` into `sink`. `bodyOnly` skips the
-- border ring -- the shape the 2D path's drawMapOnly has always had: a
-- neighbour map contributes its body, and only the CURRENT map supplies
-- the ring around the view.
--
-- `masks` (full variant only) lists rectangles, in this map's world
-- pixels, where connected neighbour BODIES sit: ring geometry inside them
-- is suppressed. The 2D renderer never needed this because it painted
-- neighbour bodies OVER the ring; with a depth buffer the ring's standing
-- trees would rise straight through the neighbour's flat ground -- cross
-- into Route 1 and a wall of border trees sprouts over Pallet.
--
-- Kept free of any GPU call so it can be exercised headless -- the
-- geometry is the part with the interesting invariants, and a suite that
-- needed a real GL context to check them would never run in CI.
-- `waterSink`, when given, takes the WATER SURFACE quads instead of the
-- main sink -- the one class in this world that is drawn as its own pass
-- (see Water: a mirror cannot be drawn until what it reflects exists).
-- Nothing else moves: the quads are the same quads, emitted by the same
-- corner and uv arithmetic at the same recessed height, and the shoreline
-- faces around them still belong to the GROUND that exposes them.
--
-- Omitted, water stays in the terrain mesh exactly as it always did, which
-- is what the headless geometry() below and the sun's own pass both want.
local function runGeometry(map, bodyOnly, masks, sink, waterSink, visualSinks)
  local push = sink.push
  local waterPush = waterSink and waterSink.push or nil
  local tileset = map.tileset
  local S = Structures.forMap(map)
  local def = map.def
  local tw, th = def.width * 4, def.height * 4         -- map size in tiles
  local perRow = tileset.tilesPerRow or 16
  local atlasW = tileset.imageWidth or (perRow * 8)
  local atlasH = tileset.imageHeight or 48

  local function heightAt(tx, ty)
    local k = keyOf(tx, ty)
    if S.skip[k] then return 0 end
    local run = S.runs[k]
    if run then return run.h end
    local s = S.shapeAt[k]
    return s and s.h or 0
  end

  -- Does the cell one step past the body belong to a CONNECTED NEIGHBOUR
  -- rather than to the border ring?
  --
  -- Structures fills the whole ring with the map's border block, and
  -- heightAt answers out of that analysis wherever it is asked -- so a
  -- cell just outside the body always reports a neighbour standing there,
  -- and outdoors that neighbour is the solid tree wall. Where the map ENDS
  -- that is the truth. Where it CONNECTS it is not: the ring is not drawn
  -- there at all (`masks` suppress it under the neighbour's body, and a
  -- body-only build emits no ring in the first place) and the neighbour's
  -- own ground runs flush with the seam.
  --
  -- Only the AO probe asks. The faces themselves still read heightAt
  -- straight, because a face is a hole if it is wrong and a crease is only
  -- a shade.
  --
  -- A cell outside the body on BOTH axes is not flush whatever connects: a
  -- neighbour to the east is not also north of itself, and the ring really
  -- does stand in the corner past the end of the seam.
  local conn = def.connections
  local cN = (conn and conn.north) ~= nil
  local cS = (conn and conn.south) ~= nil
  local cE = (conn and conn.east) ~= nil
  local cW = (conn and conn.west) ~= nil
  local anyConn = cN or cS or cE or cW
  local function flush(tx, ty)
    if not anyConn then return false end
    if ty >= 0 and ty < th then
      if tx >= tw then return cE end
      if tx < 0 then return cW end
    end
    if tx >= 0 and tx < tw then
      if ty >= th then return cS end
      if ty < 0 then return cN end
    end
    return false
  end

  -- The AO probe's own neighbour test: raised enough to crowd this corner,
  -- and actually THERE to do it.
  local function crowds(tx, ty, h)
    if flush(tx, ty) then return false end
    return heightAt(tx, ty) > h
  end

  -- one atlas-rect UV, optionally cropped to art rows [vTop, vBot] of 8
  local function uvRect(tile, vTop, vBot)
    local ax = (tile % perRow) * 8
    local ay = math.floor(tile / perRow) * 8
    local vi = math.min(INSET, (vBot - vTop) / 4)
    return (ax + INSET) / atlasW, (ax + 8 - INSET) / atlasW,
           (ay + vTop + vi) / atlasH, (ay + vBot - vi) / atlasH
  end

  -- ------------------------------------------------------ ambient occlusion
  --
  -- Ambient light is what reaches a surface from the sky at large, so it is
  -- blocked by how much geometry crowds a point rather than by where the
  -- sun happens to be -- which makes it the exact complement of the shadow
  -- pass, and the reason both are worth having. The shadow map draws the
  -- long directional shadow a building throws; this draws the dark seam in
  -- every corner the sky cannot see into, at every scale finer than a
  -- shadow map texel.
  --
  -- Baked per vertex, the classic voxel way: each corner counts the
  -- neighbours that crowd it and steps down once per neighbour, and the
  -- rasteriser interpolates the steps into a smooth falloff. Costs exactly
  -- nothing at draw time, and it is resolution-independent -- a screen
  -- space pass would blur across the pixel grid this whole mode is built
  -- to keep crisp.
  --
  -- (What was here before was a one-directional contact shadow keyed to a
  -- sun in the northwest: two neighbours, one corner, top faces only.)

  -- Intensity. Both terms below are DARKENING amounts rather than
  -- multipliers, so this one number scales the whole effect: 1.0 is the
  -- barely-there first cut, and everything is expressed against it.
  local AO_STRENGTH = 2.4
  local AO_STEP = 0.09 * AO_STRENGTH      -- per crowding neighbour, max 3
  local AO_EDGE = 1 - 0.14 * AO_STRENGTH  -- creases / corners on a face
  local AO_GROUND = 0.12 * AO_STRENGTH    -- a prop's contact with the floor
  local AO_RISE = 6                       -- px over which the floor lets go
  local AO_FLOOR = 0.25                   -- never let a vertex reach black

  -- Both sinks copy a per-corner shade straight out into the vertex stream
  -- and keep no reference, so these two scratch rows are reused for every
  -- quad on the map rather than allocating a table per face -- a route
  -- builds a few hundred thousand of them.
  local aoTop = { 0, 0, 0, 0 }
  local aoSide = { 0, 0, 0, 0 }

  -- A top face's four corners, each occluded by the three cells that touch
  -- it: two edge neighbours and the diagonal between them.
  local function aoShades(tx, ty, h, shade)
    local n = crowds(tx, ty - 1, h)
    local s = crowds(tx, ty + 1, h)
    local e = crowds(tx + 1, ty, h)
    local w = crowds(tx - 1, ty, h)
    local nw = crowds(tx - 1, ty - 1, h)
    local ne = crowds(tx + 1, ty - 1, h)
    local sw = crowds(tx - 1, ty + 1, h)
    local se = crowds(tx + 1, ty + 1, h)
    if not (n or s or e or w or nw or ne or sw or se) then return shade end
    local function corner(a, b, d)
      local k = 0
      if a then k = k + 1 end
      if b then k = k + 1 end
      -- a diagonal wedged behind both of its edges adds nothing: the
      -- corner is already as enclosed as it can get, and counting it
      -- again is what turns an ordinary inside corner black
      if d and not (a and b) then k = k + 1 end
      -- floored, so cranking AO_STRENGTH deepens the seams instead of
      -- punching holes of pure black through the world
      return shade * math.max(AO_FLOOR, 1 - AO_STEP * k)
    end
    -- corners in topQuad order: NW, NE, SE, SW
    aoTop[1], aoTop[2] = corner(n, w, nw), corner(n, e, ne)
    aoTop[3], aoTop[4] = corner(s, e, se), corner(s, w, sw)
    return aoTop
  end

  -- The same idea on an upright face, where the crowding is of two kinds:
  -- the CREASE it rises out of (the band sitting on the ground, or on
  -- whatever lower neighbour exposed the face) and the INSIDE CORNERS
  -- where the columns flanking it stand proud of the band. `hl`/`hr` are
  -- those flanking heights in FACE order -- left then right as seen from
  -- outside, per LATERAL below -- so the shades line up with sideQuad's
  -- corners without the caller thinking about compass directions.
  local LATERAL = {
    [1] = { 0, 1, 0, -1 },    -- east face:  left south, right north
    [2] = { 0, -1, 0, 1 },    -- west face:  left north, right south
    [5] = { -1, 0, 1, 0 },    -- south face: left west,  right east
    [6] = { 1, 0, -1, 0 },    -- north face: left east,  right west
  }
  -- Ground contact for the prebuilt prop quads -- the per-pixel plants,
  -- signs and lone trees, and the round-tree stamps. Those arrive from
  -- Structures already finished, so the neighbour counting above has no
  -- columns to count. What it CAN say is that the ground plane itself
  -- blocks half the sky, so the closer a voxel sits to it the less ambient
  -- light reaches it -- which is what plants a prop on the floor instead
  -- of leaving it looking pasted over the top.
  local aoProp = { 0, 0, 0, 0 }
  local function groundShades(c, shade)
    if type(shade) == "table" then return shade end
    local y1, y2, y3, y4 = c[1][2], c[2][2], c[3][2], c[4][2]
    if math.min(y1, y2, y3, y4) >= AO_RISE then return shade end
    for i = 1, 4 do
      local t = c[i][2] / AO_RISE
      aoProp[i] = shade * (t >= 1 and 1 or (1 - AO_GROUND * (1 - t)))
    end
    return aoProp
  end

  local AO_CORNER = math.max(AO_FLOOR, AO_EDGE * AO_EDGE)  -- crease AND flank
  local function sideShades(hl, hr, y0, y1, crease, shade)
    if not (crease or hl > y0 or hr > y0) then return shade end
    -- corners run bottom-left, bottom-right, top-right, top-left
    local base = crease and AO_EDGE or 1
    aoSide[1] = shade * (hl > y0 and (crease and AO_CORNER or AO_EDGE) or base)
    aoSide[2] = shade * (hr > y0 and (crease and AO_CORNER or AO_EDGE) or base)
    aoSide[3] = shade * (hr > y1 and AO_EDGE or 1)
    aoSide[4] = shade * (hl > y1 and AO_EDGE or 1)
    return aoSide
  end

  -- `to` routes the quad somewhere other than the main sink -- the water
  -- surface is the only caller that ever does (see runGeometry's header).
  local function topQuad(x0, z0, h, tile, shade, to)
    local u0, u1, v0, v1 = uvRect(tile, 0, 8)
    ;(to or push)({ { x0, h, z0 }, { x0 + 8, h, z0 },
                    { x0 + 8, h, z0 + 8 }, { x0, h, z0 + 8 } },
                  { { u0, v0 }, { u1, v0 }, { u1, v1 }, { u0, v1 } },
                  aoShades(x0 / 8, z0 / 8, h, shade))
  end

  -- vertical quad for face direction `d` of the tile column at (x0, z0),
  -- spanning heights [y0, y1] and showing art rows [vTop, vBot] of `tile`.
  -- Corners run bottom-left, bottom-right, top-right, top-left as seen
  -- from outside; u follows +X on the north/south faces so a door or sign
  -- never draws mirrored.
  local function sideQuad(d, x0, z0, y0, y1, tile, vTop, vBot, shade)
    local x1, z1 = x0 + 8, z0 + 8
    local c
    if d == 5 then                                       -- south, at z1
      c = { { x0, y0, z1 }, { x1, y0, z1 }, { x1, y1, z1 }, { x0, y1, z1 } }
    elseif d == 6 then                                   -- north, at z0
      c = { { x1, y0, z0 }, { x0, y0, z0 }, { x0, y1, z0 }, { x1, y1, z0 } }
    elseif d == 1 then                                   -- east, at x1
      c = { { x1, y0, z1 }, { x1, y0, z0 }, { x1, y1, z0 }, { x1, y1, z1 } }
    else                                                 -- west, at x0
      c = { { x0, y0, z0 }, { x0, y0, z1 }, { x0, y1, z1 }, { x0, y1, z0 } }
    end
    local u0, u1, v0, v1 = uvRect(tile, vTop, vBot)
    push(c, { { u0, v1 }, { u1, v1 }, { u1, v0 }, { u0, v0 } }, shade)
  end

  local r = bodyOnly and 0 or RING * 4

  -- true when the (ring) position lies under a connected neighbour's body
  local function masked(px0, pz0, px1, pz1)
    if not masks then return false end
    for _, mk in ipairs(masks) do
      if px1 > mk[1] and px0 < mk[3] and pz1 > mk[2] and pz0 < mk[4] then
        return true
      end
    end
    return false
  end

  -- The inclusive variant for OBJECT quads: a quad TOUCHING a neighbour
  -- body counts as under it. The old test took the quad's center with
  -- strict bounds, and a quad whose center sat exactly on the body's
  -- edge line escaped the mask -- stringing stray pixel fragments of
  -- otherwise-dropped border trees along every map seam.
  local function maskedClosed(px0, pz0, px1, pz1)
    if not masks then return false end
    for _, mk in ipairs(masks) do
      if px1 >= mk[1] and px0 <= mk[3] and pz1 >= mk[2] and pz0 <= mk[4] then
        return true
      end
    end
    return false
  end

  for ty = -r, th + r - 1 do
    for tx = -r, tw + r - 1 do
      Budget.tick()
      local k = keyOf(tx, ty)
      local s, tile = S.shapeAt[k], S.tileAt[k]
      local inBody = tx >= 0 and ty >= 0 and tx < tw and ty < th
      if not inBody and masked(tx * 8, ty * 8, tx * 8 + 8, ty * 8 + 8) then
        s = nil
      end

      -- Under the TREES fill the border wall is MODELLED or it is not there
      -- (see Structures' hullRingOnly): a ring cell nothing claimed would
      -- be a flat-topped box standing beside carved trunks, which reads as
      -- a painted-on plateau rather than forest. Structures already stops
      -- the ring at the carve distance; this catches the odd cell inside it
      -- that the 2x2 grouping could not take -- a canopy whose partners
      -- fall outside the shortened ring is left unclaimed, and one strip of
      -- boxes along an edge is the whole artefact this avoids.
      if not inBody and S.hideBareRing and not S.skip[k] then
        s = nil
      end

      if s and S.skip[k] then
        -- an object stands here; paint its synthesized ground and let the
        -- prebuilt prism quads (appended below) carry the art
        local g = S.ground[k]
        if g then
          topQuad(tx * 8, ty * 8, 0, g, 1)
          -- the claimed tile is still ground at height 0, and water next
          -- door still recesses below it: without the same below-ground
          -- side bands ordinary ground emits, the two-pixel shoreline
          -- face is a slit into the sky behind the mesh -- which is
          -- exactly what a building plot or a sign standing at the
          -- waterline showed. Same bands, cut from the synthesized
          -- ground's own art
          for _, side in ipairs(SIDES) do
            local nh = heightAt(tx + side[1], ty + side[2])
            if nh < 0 then
              local d = side[3]
              local lat = LATERAL[d]
              local hl = lat and heightAt(tx + lat[1], ty + lat[2]) or 0
              local hr = lat and heightAt(tx + lat[3], ty + lat[4]) or 0
              for band = math.floor(nh / 8), -1 do
                local y0 = math.max(nh, band * 8)
                local y1 = math.min(0, band * 8 + 8)
                if y1 > y0 then
                  sideQuad(d, tx * 8, ty * 8, y0, y1, g,
                           (band * 8 + 8) - y1, (band * 8 + 8) - y0,
                           sideShades(hl, hr, y0, y1, y0 <= nh,
                                      Voxel3D.FACE_SHADE[d]))
                end
              end
            end
          end
        end
      elseif s then
        local run = S.runs[k]
        local h = run and run.h or s.h
        local x0, z0 = tx * 8, ty * 8

        -- top face. A roofed volume gets a GABLE segment: the roof rises
        -- from the facade top at the south eave to a ridge across the
        -- footprint's middle, then falls back to the facade at the north
        -- edge -- so the far side sits LOW. (The first cut was a shed
        -- plane rising all the way north, which turns a building into a
        -- ramp.) The south slope wears the structure's roof rows (ridge
        -- art at the ridge, eaves art at the eave); the back slope
        -- mirrors them. Exposed east/west flanks hip: their outer edge
        -- drops toward the eave, rounding the drawn corner tiles into 45
        -- degree corners. Flat-topped volumes wear their top rows;
        -- everything else its own art.
        if run and run.rise > 0 then
          local mid = run.extent / 2
          local function gableH(d)     -- d = rows north of the south eave
            local t = d <= mid and d / mid or (run.extent - d) / (run.extent - mid)
            return run.h + run.rise * math.max(0, math.min(1, t))
          end
          local d0 = run.front - ty                -- rows from the south edge
          local hS = gableH(d0)
          local hN = gableH(d0 + 1)
          -- art by proximity to the ridge, mirrored over the back
          local rel = 1 - math.abs(d0 + 0.5 - mid) / math.max(mid, 0.5)
          local idx = math.min(run.roofRows - 1,
                               math.floor((1 - rel) * run.roofRows))
          local roofTile = map:tileAt(tx, run.north + idx)
          local swY, seY, neY, nwY = hS, hS, hN, hN
          if heightAt(tx - 1, ty) < run.h then     -- west flank: hip
            swY = math.max(run.h, hS - 8)
            nwY = math.max(run.h, hN - 8)
          end
          if heightAt(tx + 1, ty) < run.h then     -- east flank: hip
            seY = math.max(run.h, hS - 8)
            neY = math.max(run.h, hN - 8)
          end
          local u0, u1, v0, v1 = uvRect(roofTile, 0, 8)
          push({ { x0, swY, z0 + 8 }, { x0 + 8, seY, z0 + 8 },
                 { x0 + 8, neY, z0 }, { x0, nwY, z0 } },
               { { u0, v1 }, { u1, v1 }, { u1, v0 }, { u0, v0 } }, 0.95)
        elseif run then
          local topTile = s.topTile
            or map:tileAt(tx, ChunkMesher.flatTopRow(run, ty))
          topQuad(x0, z0, h, topTile, VOLUME_TOP_SHADE)
        else
          local topTile = s.topTile or tile
          if s.art == "upright" and s.authored then
            -- Top art for a pinned box.  A furniture drawing is top-view
            -- rows over floor(h/8) face-on rows the fold stands upright;
            -- a face row's top would repeat its front art lying flat, so
            -- it wears the nearest row above the face block instead --
            -- the drawn tabletop (and whatever sits on it) stays on top,
            -- and a fully-folded structure (wall, desk) tops with its
            -- northmost row.
            local north, front = ty, ty
            while ty - north < 6 do
              local bs = S.shapeAt[keyOf(tx, north - 1)]
              if bs and bs.authored and bs.class == s.class then
                north = north - 1
              else
                break
              end
            end
            while front - ty < 6 do
              local bs = S.shapeAt[keyOf(tx, front + 1)]
              if bs and bs.authored and bs.class == s.class then
                front = front + 1
              else
                break
              end
            end
            local row = math.min(ty, front - math.floor(h / 8))
            if row < north then
              -- the whole run folded onto the face: top with the drawn
              -- row just above it when that row is furniture too (a
              -- bookcase wearing its shelf-top trim), else with the
              -- run's own top row
              local above = S.shapeAt[keyOf(tx, north - 1)]
              row = (above and above.authored and above.art == "upright")
                    and (north - 1) or north
            end
            topTile = S.tileAt[keyOf(tx, row)]
          end
          -- water's surface, and only water's: the recessed sheet itself,
          -- never the ground's shoreline bands around it. A cell an object
          -- stands on took the branch above and paints synthesized GROUND,
          -- which is right -- a sign at the waterline stands on a plot, not
          -- on the pond.
          topQuad(x0, z0, h, topTile,
                  s.art == "upright" and VOLUME_TOP_SHADE or 1,
                  (s.class == "water") and waterPush or nil)
        end

        -- sides: 8px bands wherever the neighbour is lower. Band k spans
        -- heights [8k, 8k+8) and shows one full tile of art; a partial
        -- band crops the art rows to match, so nothing ever stretches.
        for _, side in ipairs(SIDES) do
          local nh = heightAt(tx + side[1], ty + side[2])
          if nh < h then
            local d = side[3]
            -- the columns flanking this face, for the inside-corner term:
            -- fixed for the whole face, so they are read once rather than
            -- once per 8px band
            local lat = LATERAL[d]
            local hl = lat and heightAt(tx + lat[1], ty + lat[2]) or 0
            local hr = lat and heightAt(tx + lat[3], ty + lat[4]) or 0
            for band = math.floor(nh / 8), math.ceil(h / 8) - 1 do
              local y0 = math.max(nh, band * 8)
              local y1 = math.min(h, band * 8 + 8)
              if y1 > y0 then
                local src, shade = tile, Voxel3D.FACE_SHADE[d]
                if run then
                  -- fold the structure's artwork up this face: band k
                  -- samples the map row k tiles north of the structure's
                  -- front, clamped to its extent. The south face is the
                  -- drawing itself (full brightness); the other sides wear
                  -- the same rows darkened, so a building's flank matches
                  -- its face instead of smearing one tile
                  if d == 6 then
                    src = map:tileAt(tx, math.min(run.front,
                                                  run.north + band))
                  else
                    src = map:tileAt(tx, math.max(run.north,
                                                  run.front - band))
                  end
                  if d == 5 then shade = 1 end
                elseif s.art == "upright" then
                  -- profile-authored upright (a pinned wall or furniture
                  -- box): fold the drawing up the face, band 0 the
                  -- structure's southmost same-class row and higher bands
                  -- the rows north of it, repeating past the top.  The
                  -- south face is the drawing itself (full brightness);
                  -- flanks and back wear the same front stack darkened, so
                  -- a desk's side matches its face instead of smearing a
                  -- different jumble per row.
                  if d == 5 then shade = 1 end
                  local front = ty
                  while front < ty + 6 do
                    local fs2 = S.shapeAt[keyOf(tx, front + 1)]
                    if fs2 and fs2.authored and fs2.class == s.class then
                      front = front + 1
                    else
                      break
                    end
                  end
                  local fk = keyOf(tx, front - band)
                  local fs = S.shapeAt[fk]
                  if fs and fs.authored and fs.class == s.class then
                    src = S.tileAt[fk]
                  end
                end
                sideQuad(d, x0, z0, y0, y1, src,
                         (band * 8 + 8) - y1, (band * 8 + 8) - y0,
                         sideShades(hl, hr, y0, y1, y0 <= nh, shade))
              end
            end
          end
        end
      end
    end
  end

  -- Prebuilt quads from Structures (per-pixel voxel props, lathed
  -- columns) plus the round-tree stamps expanded in place. Keep rules,
  -- by the quad's own extent:
  --   body-only   the quad must overlap the OPEN body interval -- a
  --               neighbour's ring props must not march past its edge
  --               into this map, and a quad lying exactly ON the edge
  --               plane would z-fight the map that owns that plane.
  --   full        anything overlapping the body stays whole (props that
  --               straddle the edge no longer shed their outer half);
  --               pure ring quads drop when they touch a neighbour body
  --               (maskedClosed), which is what strings of seam pixels
  --               were: fragments of dropped border trees whose centers
  --               sat exactly on the boundary line.
  local bw, bh = tw * 8, th * 8
  local function keepQuad(x0, z0, x1, z1)
    local overBody = x1 > 0 and x0 < bw and z1 > 0 and z0 < bh
    if bodyOnly then return overBody end
    return overBody or not maskedClosed(x0, z0, x1, z1)
  end

  -- A face lying EXACTLY on a body boundary plane is ambiguous to the
  -- rect tests above: a body structure's outward facade (a Saffron row
  -- house whose front row is the map's last row, its south wall on the
  -- shared plane with Route 6) and the inward face of a ring scrap
  -- occupy the same degenerate rect, and the strict overBody plus the
  -- closed mask dropped BOTH -- which is why those facades were missing.
  -- The winding tells them apart: a face pointing AWAY from the body
  -- belongs to this map's own edge-row structure and nothing in the
  -- neighbour will ever draw that plane, so it stays; a face pointing
  -- INTO the body is the scrap the mask rules exist to kill, and falls
  -- through to them.
  local function outwardOnEdge(q, x0, z0, x1, z1)
    if z0 == z1 and (z0 == 0 or z0 == bh) and x1 > 0 and x0 < bw then
      local nz = (q[2][1] - q[1][1]) * (q[3][2] - q[1][2])
                 - (q[2][2] - q[1][2]) * (q[3][1] - q[1][1])
      return (z0 == bh and nz > 0) or (z0 == 0 and nz < 0)
    end
    if x0 == x1 and (x0 == 0 or x0 == bw) and z1 > 0 and z0 < bh then
      local nx = (q[2][2] - q[1][2]) * (q[3][3] - q[1][3])
                 - (q[2][3] - q[1][3]) * (q[3][2] - q[1][2])
      return (x0 == bw and nx > 0) or (x0 == 0 and nx < 0)
    end
    return false
  end

  local scUV = { { 0, 0 }, { 0, 0 }, { 0, 0 }, { 0, 0 } }
  local function quadUV(q)
    if q.uv then return q.uv end
    for i = 1, 4 do
      scUV[i][1], scUV[i][2] = q.u, q.v
    end
    return scUV
  end

  -- Ownership for the prop passes (see the span header). A prop's quads
  -- arrive cell by cell, so consecutive quads landing in the same 16px cell
  -- share one run -- fine enough to name a felled tree, coarse enough that a
  -- route's props cost a few hundred runs and not tens of thousands. Quads
  -- routed to a visual-object sidecar are not the main mesh's to drop, so
  -- they claim nothing.
  -- Only the body is worth recording. Runs are selected by block edits,
  -- block coordinates are body coordinates, so a ring tree's runs could
  -- never be picked and would just add weight to the cached record.
  local own = sink.own
  local ownedCell = nil
  local function inBodyPx(cx, cz)
    return cx >= 0 and cx < tw * 8 and cz >= 0 and cz < th * 8
  end
  local function ownCell(x0, z0, x1, z1)
    if not own then return end
    local ccx = math.floor((x0 + x1) / 32)
    local ccz = math.floor((z0 + z1) / 32)
    if not inBodyPx(ccx * 16 + 8, ccz * 16 + 8) then
      ownedCell = nil
      return
    end
    local cell = ccz * 4096 + ccx
    if cell == ownedCell then return end
    ownedCell = cell
    own(ccx * 16, ccz * 16, ccx * 16 + 16, ccz * 16 + 16)
  end

  -- Emit the object quads cell by cell instead of in the order the producers
  -- appended them.
  --
  -- The producers interleave, so consecutive quads kept changing cell and a
  -- run opened for nearly every one: 18596 runs for a body of 1440 cells on
  -- Cerulean, about 300KB of record per slot, and a cut that needed hundreds
  -- of small uploads. Grouped, that is 449 runs and one or two uploads.
  --
  -- Reordering is safe here. These are opaque triangles drawn against a
  -- depth buffer, and water and the visual sidecars have their own sinks.
  local objectOrder = {}
  for i = 1, #S.objectQuads do objectOrder[i] = i end
  do
    local keys = {}
    for i, q in ipairs(S.objectQuads) do
      local cx = math.floor((q[1][1] + q[3][1]) / 32)
      local cz = math.floor((q[1][3] + q[3][3]) / 32)
      keys[i] = cz * 4096 + cx
    end
    table.sort(objectOrder, function(a, b)
      if keys[a] ~= keys[b] then return keys[a] < keys[b] end
      return a < b            -- stable: producers' own order inside a cell
    end)
  end

  for _, qi in ipairs(objectOrder) do
    local q = S.objectQuads[qi]
    Budget.tick()
    local x0 = math.min(q[1][1], q[2][1], q[3][1], q[4][1])
    local x1 = math.max(q[1][1], q[2][1], q[3][1], q[4][1])
    local z0 = math.min(q[1][3], q[2][3], q[3][3], q[4][3])
    local z1 = math.max(q[1][3], q[2][3], q[3][3], q[4][3])
    -- q.own: a body-anchored structure's own quad (a building placed by
    -- Buildings.build, whose scan never leaves the body). Exempt from
    -- the edge keep-rules entirely: its eave legitimately overhangs the
    -- boundary plane into the neighbour's airspace, and no variant of
    -- the neighbour will ever draw that geometry
    if q.own or outwardOnEdge(q, x0, z0, x1, z1)
        or keepQuad(x0, z0, x1, z1) then
      local target = push
      if q.visualObjectId and visualSinks then
        local visualSink = visualSinks[q.visualObjectId]
        if not visualSink then
          visualSink = newSink()
          visualSinks[q.visualObjectId] = visualSink
        end
        target = visualSink.push
      end
      if target == push then ownCell(x0, z0, x1, z1) end
      target({ q[1], q[2], q[3], q[4] }, quadUV(q),
        groundShades(q, q.shade))
    end
  end

  -- true when the rect sits entirely inside one neighbour-body rect
  local function containedInMask(x0, z0, x1, z1)
    if not masks then return false end
    for _, mk in ipairs(masks) do
      if x0 >= mk[1] and x1 <= mk[3] and z0 >= mk[2] and z1 <= mk[4] then
        return true
      end
    end
    return false
  end

  -- round-tree stamps: the shared hull template translated per cell,
  -- through reusable scratch corners so expansion allocates nothing.
  -- A hull spans at most its own footprint -- one 16px cell unless the
  -- stamp carries a wider radius (the 2x2-cell canopy groups) -- so one
  -- rect test usually answers for the whole stamp: strictly interior
  -- stamps keep every quad, ring stamps buried under a neighbour body
  -- (or, body-only, ring stamps full stop) skip without touching their
  -- quads. Only stamps crossing a boundary walk quad by quad.
  local sc = { { 0, 0, 0 }, { 0, 0, 0 }, { 0, 0, 0 }, { 0, 0, 0 } }
  for _, st in ipairs(S.roundStamps or {}) do
    local mx, mz = st.mx, st.mz
    local sr = st.r or 8
    local sx0, sz0, sx1, sz1 = mx - sr, mz - sr, mx + sr, mz + sr
    local interior = sx0 > 0 and sx1 < bw and sz0 > 0 and sz1 < bh
    local overBody = sx1 > 0 and sx0 < bw and sz1 > 0 and sz0 < bh
    local keepAll, skipAll
    if bodyOnly then
      keepAll = interior
      skipAll = not overBody
    else
      keepAll = interior or not maskedClosed(sx0, sz0, sx1, sz1)
      skipAll = not overBody and containedInMask(sx0, sz0, sx1, sz1)
    end
    if not skipAll then
      -- a stamp is one prop whatever it spans, so it owns its whole
      -- footprint in one run: the 2x2-cell canopy groups are exactly a
      -- block, which is exactly what Cut swaps
      if own and inBodyPx(mx, mz) then
        own(sx0, sz0, sx1, sz1)
        ownedCell = nil
      end
      for _, q in ipairs(st.quads) do
        Budget.tick()
        for i = 1, 4 do
          local c, s2 = q[i], sc[i]
          s2[1] = c[1] + mx
          s2[2] = c[2]
          s2[3] = c[3] + mz
        end
        local ok = keepAll
        if not ok then
          local x0 = math.min(sc[1][1], sc[2][1], sc[3][1], sc[4][1])
          local x1 = math.max(sc[1][1], sc[2][1], sc[3][1], sc[4][1])
          local z0 = math.min(sc[1][3], sc[2][3], sc[3][3], sc[4][3])
          local z1 = math.max(sc[1][3], sc[2][3], sc[3][3], sc[4][3])
          ok = keepQuad(x0, z0, x1, z1)
        end
        if ok then
          push(sc, quadUV(q), groundShades(sc, q.shade))
        end
      end
    end
  end
end

-- The raw geometry for `map`: (vertex list, triangle index list, quad
-- count). Synchronous and GPU-free -- the headless suite and the probes
-- exercise the invariants through this.
--
-- `split` lifts the water surface out, as it is lifted out for the
-- reflective pass, and appends that sink's own three values -- so the suite
-- can check the same separation the GPU path relies on without a GPU.
-- Without it the water is in the first list, which is what every existing
-- caller reads.
function ChunkMesher.geometry(map, bodyOnly, masks, split)
  local sink = newTableSink()
  local waterSink = split and newTableSink() or nil
  runGeometry(map, bodyOnly, masks, sink, waterSink)
  if not waterSink then return sink.results() end
  local v, i, n = sink.results()
  local wv, wi, wn = waterSink.results()
  return v, i, n, wv, wi, wn
end

-- Build the mesh for `map` synchronously. Returns nil when there is
-- nothing to draw or meshes are unavailable (headless).
--
-- `split` asks for the water surface as a SECOND mesh, returned after the
-- terrain one -- the shape the reflective pass needs (see Water). Without
-- it the water is inside the terrain mesh, which is the historical
-- contract and what every other caller still wants.
function ChunkMesher.build(map, bodyOnly, masks, split, separateVisuals)
  local sink = newSink()
  local waterSink = split and newSink() or nil
  local visualSinks = separateVisuals and {} or nil
  runGeometry(map, bodyOnly, masks, sink, waterSink, visualSinks)
  local visuals = nil
  if visualSinks then
    visuals = {}
    for id, visualSink in pairs(visualSinks) do
      local mesh = visualSink.finish()
      if mesh then visuals[id] = mesh end
    end
  end
  return sink.finish(), waterSink and waterSink.finish() or nil, visuals
end

-- Prop runs for a quad list. Cut swaps tall grass as well as trees, so the
-- grass and flower records carry runs too.
-- `perQuad` is how many vertices the consumer writes per quad: the raw
-- records are unindexed triangles (six), quadsMesh indexes four corners.
local function quadListSpans(quads, perQuad)
  local spans, first, cellKey, cellX, cellZ = {}, nil, nil, 0, 0
  local at = 0
  perQuad = perQuad or 6
  for _, q in ipairs(quads or {}) do
    local qx = math.floor((q[1][1] + q[3][1]) / 32)
    local qz = math.floor((q[1][3] + q[3][3]) / 32)
    local key = qz * 4096 + qx
    if key ~= cellKey then
      if first and at > first then
        spans[#spans + 1] = first
        spans[#spans + 1] = at - first
        spans[#spans + 1] = cellX
        spans[#spans + 1] = cellZ
      end
      cellKey, cellX, cellZ = key, qx * 16 + 8, qz * 16 + 8
      first = at
    end
    at = at + perQuad
  end
  if first and at > first then
    spans[#spans + 1] = first
    spans[#spans + 1] = at - first
    spans[#spans + 1] = cellX
    spans[#spans + 1] = cellZ
  end
  return spans
end

local function quadsMesh(quads)
  if #quads == 0 then return nil end
  local spans = quadListSpans(quads, 4)
  local verts, indices, n = {}, {}, 0
  for _, q in ipairs(quads) do
    for i = 1, 4 do
      local c = q[i]
      local uv = q.uv and q.uv[i] or { q.u, q.v }
      verts[#verts + 1] = { c[1], c[2], c[3], uv[1], uv[2], q.shade }
    end
    Voxel3D.pushQuad(indices, n)
    n = n + 1
  end
  return Voxel3D.newMesh(verts, indices), spans
end

-- Flatten auxiliary quads into the same unindexed six-float stream terrain
-- uses. This path is selected only when persistent caching is available; the
-- historical table builder remains the headless/non-FFI fallback.
local function rawQuads(quads)
  local n = #(quads or {}) * 6
  if n == 0 then return { n = 0 } end
  if MeshDisk.legacy() and ffi then
    local buf, at = ffi.new("float[?]", n * 6), 0
    for _, q in ipairs(quads) do
      for k = 1, 6 do
        local i = TRI_ORDER[k]
        local c = q[i]
        local uv = q.uv and q.uv[i] or { q.u, q.v }
        buf[at], buf[at + 1], buf[at + 2] = c[1], c[2], c[3]
        buf[at + 3], buf[at + 4], buf[at + 5] = uv[1], uv[2], q.shade
        at = at + 6
      end
      Budget.tick()
    end
    return { ptr = buf, n = n, spans = quadListSpans(quads) }
  end
  local chunks, parts, values = {}, {}, {}
  for _, q in ipairs(quads) do
    local at = 1
    for k = 1, 6 do
      local i = TRI_ORDER[k]
      local c = q[i]
      local uv = q.uv and q.uv[i] or { q.u, q.v }
      values[at], values[at + 1], values[at + 2] = c[1], c[2], c[3]
      values[at + 3], values[at + 4], values[at + 5] = uv[1], uv[2], q.shade
      at = at + 6
    end
    parts[#parts + 1] = love.data.pack(
      "string", PACKED_VERTEX, unpack(values, 1, 36))
    if #parts == PACKED_QUADS_PER_CHUNK then
      chunks[#chunks + 1], parts = table.concat(parts), {}
    end
    Budget.tick()
  end
  if #parts > 0 then chunks[#chunks + 1] = table.concat(parts) end
  return { chunks = chunks, n = n, spans = quadListSpans(quads) }
end

local function buildRawAux(map)
  local structures = Structures.forMap(map)
  local aux = {
    grass = rawQuads(structures.grassQuads),
    flowers = rawQuads(structures.flowerQuads),
    figures = {},
  }
  for _, figure in ipairs(structures.figures or {}) do
    local raw = rawQuads(figure.quads)
    if raw.n > 0 then
      local width = 0
      for _, q in ipairs(figure.quads) do
        for i = 1, 4 do
          local x = q[i] and q[i][1]
          if x and x > width then width = x end
        end
      end
      raw.wx, raw.wz, raw.y, raw.w = figure.wx, figure.wz, figure.y, width
      aux.figures[#aux.figures + 1] = raw
    end
  end
  return aux
end

local function meshesFromRawAux(aux)
  local figures = {}
  for _, raw in ipairs(aux.figures or {}) do
    local mesh = meshFromRaw(raw)
    if mesh then
      figures[#figures + 1] = {
        mesh = mesh, wx = raw.wx, wz = raw.wz, y = raw.y, w = raw.w,
      }
    end
  end
  return meshFromRaw(aux.grass), meshFromRaw(aux.flowers), figures,
         aux.grass and aux.grass.spans or nil,
         aux.flowers and aux.flowers.spans or nil
end

-- The tall-grass rows as their own mesh: VoxelScene draws it AFTER the
-- characters so the southern row of a grass cell still overdraws a
-- walker's feet (characters stamp over terrain, Gen 1 style, so ordinary
-- terrain could never do this).
local function buildGrassMesh(map)
  return quadsMesh(Structures.forMap(map).grassQuads)
end

-- The flower billboards as their own mesh, for the same reason as the
-- grass one: it draws AFTER the characters WITH the same camera-ward
-- pull, so a flower south of a walker occludes their feet and one north
-- of them hides behind them. Baked into the terrain mesh they lost that
-- depth fight against the pulled character card whenever the player
-- stood among flowers. Unlike grass this mesh still CASTS shadows (the
-- sun pass draws it): a handful of flowers per meadow, not thousands of
-- tufts.
local function buildFlowerMesh(map)
  return quadsMesh(Structures.forMap(map).flowerQuads)
end

-- Authored FIGURES (a person drawn into furniture) as one mesh each, in
-- the card's own local space -- because each one is placed by its own
-- matrix at draw time, leaned back by the camera pitch exactly like a
-- character card (VoxelScene). A figure baked into the terrain mesh could
-- not lean, and a shared mesh could not carry per-figure placement.
--
-- A list, not a mesh: `{ mesh, wx, wz, y, w }` per figure. Maps have one
-- or none, so the loop that draws them is shorter than the terrain's.
-- `w` is the card's own width in its local space (its quads start at
-- x = 0), measured here because the first-person pass yaws a card about
-- its middle -- a card yawed about its left edge swings off its seat.
local function buildFigureMeshes(map)
  local out = {}
  for _, f in ipairs(Structures.forMap(map).figures or {}) do
    local mesh = quadsMesh(f.quads)
    if mesh then
      local w = 0
      for _, q in ipairs(f.quads) do
        for c = 1, 4 do
          local x = q[c] and q[c][1]
          if x and x > w then w = x end
        end
      end
      out[#out + 1] = { mesh = mesh, wx = f.wx, wz = f.wz, y = f.y, w = w }
    end
  end
  return out
end

-- Figure lists hold their meshes one level down, so the generic slot
-- release cannot reach them.
local function releaseFigures(list)
  for _, f in ipairs(type(list) == "table" and list or {}) do
    if f.mesh and f.mesh.release then pcall(f.mesh.release, f.mesh) end
  end
end

-- Replace a cached slot, releasing whatever mesh it held.
local function swapSlot(c, slot, mesh)
  local old = c[slot]
  if old and old ~= mesh and old.release then pcall(old.release, old) end
  c[slot] = mesh
end

local function releaseVisualMeshes(list)
  for _, mesh in pairs(type(list) == "table" and list or {}) do
    if mesh and mesh.release then pcall(mesh.release, mesh) end
  end
end

local function visualSlot(slot)
  return slot .. "Visuals"
end

local function swapVisualSlot(c, slot, visuals)
  local name = visualSlot(slot)
  if c[name] ~= visuals then releaseVisualMeshes(c[name]) end
  c[name] = visuals
end

local function mapHasVisualObjects(map)
  local companion = V.companion
  if companion and type(companion.wantsVisualObjects) == "function" then
    local ok, wanted = pcall(companion.wantsVisualObjects, companion)
    if ok and not wanted then return false end
  end
  for _, quad in ipairs(Structures.forMap(map).objectQuads or {}) do
    if quad.visualObjectId then return true end
  end
  return false
end

-- ------------------------------------------------------------- the cache

local function entry(id)
  local c = cache[id]
  if not c then
    c = {}
    cache[id] = c
  end
  return c
end

-- The water surface that came out of a terrain slot's own build. Kept
-- beside it rather than in a slot of its own because the two are ONE
-- answer: a full mesh drawn beside a body build's water would draw the
-- ring's ponds twice and miss the body's own.
local function waterSlot(slot)
  return slot .. "Water"
end

local function releaseEntry(c)
  for _, slot in ipairs({ "full", "body", "fullWater", "bodyWater",
                          "grass", "flowers" }) do
    local mesh = c[slot]
    if mesh and mesh.release then pcall(mesh.release, mesh) end
    c[slot] = nil
    c[slot .. "Spans"] = nil
  end
  releaseVisualMeshes(c.fullVisuals)
  releaseVisualMeshes(c.bodyVisuals)
  c.fullVisuals, c.bodyVisuals = nil, nil
  releaseFigures(c.figures)
  c.figures = nil
  c.stale = nil
end

-- ---------------------------------------------------------- async builds

local jobs = {}       -- FIFO of pending jobs
local jobIndex = {}   -- "id:slot" -> job
local jobFailures = {} -- settled coroutine errors, consumed by diagnostics

local clock = (love and love.timer and love.timer.getTime) or os.clock

local function jobKey(id, slot)
  return id .. ":" .. slot
end

local function finishJob(job, ok, err)
  local key = jobKey(job.id, job.slot)
  jobIndex[key] = nil
  for i, j in ipairs(jobs) do
    if j == job then
      table.remove(jobs, i)
      break
    end
  end
  if not ok then
    -- name the reason: in a real session a lost build is a black map
    print("[warn] voxel mesh build failed for " .. tostring(job.id)
          .. ": " .. tostring(err))
    if (gen[job.id] or 0) == job.gen then
      entry(job.id)[job.slot] = false
    end
    jobFailures[key] = tostring(err or "unknown mesh build error")
  else
    jobFailures[key] = nil
  end
end

-- A build only lands if the map's generation still matches the one the
-- job was queued under -- invalidate/evict bump it to cancel in-flight
-- work whose inputs went stale.
local function runJob(job)
  local map = job.map
  local c = entry(job.id)
  local function current()
    return (gen[job.id] or 0) == job.gen
  end
  if c.grass == nil or c.flowers == nil or c.figures == nil
     or (c.stale and c.stale.aux) then
    local grass, flowers, figures, grassSpans, flowerSpans
    if MeshDisk.available() then
      local aux = MeshDisk.loadAux(map)
      if not aux then
        aux = buildRawAux(map)
        if not current() then return end
        local savedAux, auxError = MeshDisk.saveAux(map, aux)
        if not savedAux then
          print("[warn] voxel aux cache write failed for " .. tostring(job.id)
                .. ": " .. tostring(auxError))
        end
        if not current() then
          return
        end
      end
      grass, flowers, figures, grassSpans, flowerSpans = meshesFromRawAux(aux)
    else
      local okG, builtGrass, builtGrassSpans = pcall(buildGrassMesh, map)
      local okF, builtFlowers, builtFlowerSpans = pcall(buildFlowerMesh, map)
      local okX, builtFigures = pcall(buildFigureMeshes, map)
      grass = (okG and builtGrass) or false
      flowers = (okF and builtFlowers) or false
      figures = (okX and builtFigures) or false
      grassSpans = (okG and builtGrass) and builtGrassSpans or nil
      flowerSpans = (okF and builtFlowers) and builtFlowerSpans or nil
    end
    if not current() then
      if grass and grass.release then pcall(grass.release, grass) end
      if flowers and flowers.release then pcall(flowers.release, flowers) end
      releaseFigures(figures)
      return
    end
    swapSlot(c, "grass", grass or false)
    swapSlot(c, "flowers", flowers or false)
    c.grassSpans = grass and grassSpans or nil
    c.flowersSpans = flowers and flowerSpans or nil
    releaseFigures(c.figures)
    c.figures = figures or false
    if c.stale then c.stale.aux = nil end
  end

  local mesh, water, visualMeshes, spans
  -- Annotated originals are small session meshes beside the canonical terrain.
  -- Older persistent terrain records contain those quads, so annotated maps do
  -- not read those records. New records contain only the canonical terrain;
  -- write them so the title precache can complete, while the sign sidecars are
  -- rebuilt in-session and remain available to the companion pass.
  local annotatedVisuals = mapHasVisualObjects(map)
  local cached = not annotatedVisuals
    and MeshDisk.loadTerrain(map, job.slot, job.masks) or nil
  if cached then
    mesh = meshFromRaw(cached.terrain)
    water = meshFromRaw(cached.water)
    -- the prop runs were written with the record: a precached map can drop a
    -- felled tree without ever having run the geometry pass this session
    spans = cached.spans
  else
    local sink, waterSink = newSink(), newSink()
    local visualSinks = annotatedVisuals and {} or nil
    runGeometry(map, job.slot == "body", job.masks, sink, waterSink,
      visualSinks)
    local terrainRaw = sink.raw and sink.raw() or nil
    local waterRaw = waterSink.raw and waterSink.raw() or nil
    mesh, water = sink.finish(), waterSink.finish()
    spans = (terrainRaw and terrainRaw.spans)
            or (sink.spans and sink.spans()) or nil
    if visualSinks then
      visualMeshes = {}
      for id, visualSink in pairs(visualSinks) do
        local visualMesh = visualSink.finish()
        if visualMesh then visualMeshes[id] = visualMesh end
      end
    end
    if not current() then
      if mesh and mesh.release then pcall(mesh.release, mesh) end
      if water and water.release then pcall(water.release, water) end
      releaseVisualMeshes(visualMeshes)
      return
    end
    if terrainRaw and waterRaw then
      local savedTerrain, terrainError =
        MeshDisk.saveTerrain(map, job.slot, job.masks, terrainRaw, waterRaw)
      if not savedTerrain then
        print("[warn] voxel terrain cache write failed for " .. tostring(job.id)
              .. " " .. tostring(job.slot) .. ": " .. tostring(terrainError))
      end
    end
  end
  if not current() then
    if mesh and mesh.release then pcall(mesh.release, mesh) end
    if water and water.release then pcall(water.release, water) end
    releaseVisualMeshes(visualMeshes)
    return
  end
  swapSlot(c, job.slot, mesh or false)
  swapSlot(c, waterSlot(job.slot), water or false)
  swapVisualSlot(c, job.slot, visualMeshes)
  -- the runs describe THIS mesh, so they land and die with it
  c[job.slot .. "Spans"] = mesh and spans or nil
  if c.stale then
    c.stale[job.slot] = nil
    if not (c.stale.full or c.stale.body or c.stale.aux) then
      c.stale = nil
    end
  end
end

-- Queue a build unless the slot is already cached or queued. Returns the
-- cached mesh when there is one (false-cached misses return nil).
-- `priority` is true/"current" for the current map, a 1..<2 distance score
-- for connected bodies, and false/nil for speculative warp precaching.
-- Current and connected work both get a foreground slice, but the current map
-- always wins first. A slot refresh() marked
-- stale queues its rebuild AND keeps handing back the old mesh, so a
-- one-block edit never drops the scene to the flat 2D path while the
-- replacement cooks.
local function priorityValue(priority)
  if priority == true or priority == "current" then return 2 end
  if priority == "visible" then return 1 end
  if type(priority) == "number" then
    return math.max(0, math.min(1.99, priority))
  end
  return 0
end

function ChunkMesher.request(map, bodyOnly, masks, priority)
  local slot = bodyOnly and "body" or "full"
  local c = cache[map.id]
  local stale = c and c.stale and (c.stale[slot] or c.stale.aux)
  if c and c[slot] ~= nil and not stale then return c[slot] or nil end
  local key = jobKey(map.id, slot)
  local job = jobIndex[key]
  local requested = priorityValue(priority)
  if not job then
    jobFailures[key] = nil
    job = { id = map.id, map = map, slot = slot, masks = masks,
            priority = requested, gen = gen[map.id] or 0 }
    jobIndex[key] = job
    jobs[#jobs + 1] = job
  elseif type(priority) == "number" and (job.priority or 0) < 2 then
    -- Distance-ranked connected bodies can move both toward and away from the
    -- player. Re-rank them every prefetch tick instead of permanently pinning
    -- whichever map happened to be close first.
    job.priority = requested
  elseif requested > (job.priority or 0) then
    job.priority = requested
  end
  -- Crossing a seam asks for the destination FULL mesh while its already
  -- started neighbour BODY may still be packing. Finish that smaller body
  -- first so it can draw immediately as the current-map fallback; otherwise
  -- the new full job (priority 2) starves the nearly-ready body (priority 1)
  -- and recreates the Android flowers-without-terrain delay at the seam.
  if slot == "full" and requested == 2 then
    local body = jobIndex[jobKey(map.id, "body")]
    if body then body.priority = math.max(body.priority or 0, 3) end
  end
  return (c and c[slot]) or nil
end

function ChunkMesher.pending()
  return #jobs
end

-- Precachers/tooling need to know when one requested slot has landed without
-- retaining or inspecting its GPU mesh.  This is intentionally only a queue
-- probe; a failed build and a completed build both stop being pending.
function ChunkMesher.jobPending(mapId, bodyOnly)
  return jobIndex[jobKey(mapId, bodyOnly and "body" or "full")] ~= nil
end

-- A completed and a failed coroutine both disappear from jobPending(). Keep
-- the latter's exact exception until the sole consumer (precache diagnostics)
-- records it. Runtime callers need no special handling: false remains cached
-- as before and ordinary rendering continues to fail open.
function ChunkMesher.takeJobFailure(mapId, bodyOnly)
  local key = jobKey(mapId, bodyOnly and "body" or "full")
  local err = jobFailures[key]
  jobFailures[key] = nil
  return err
end

-- Small diagnostic used by probes/tests to verify that a queued neighbour was
-- promoted instead of remaining behind speculative precache work.
function ChunkMesher.jobPriority(mapId, bodyOnly)
  local job = jobIndex[jobKey(mapId, bodyOnly and "body" or "full")]
  return job and (job.priority or 0) or nil
end

-- True once a slot has produced an answer, including a cached `false` after a
-- failed/empty build.  Unlike peek(), this distinguishes that settled state
-- from an invalidated slot so the background precacher retries only real
-- invalidations, not an unsupported map forever.
function ChunkMesher.slotKnown(map, bodyOnly)
  local c = map and cache[map.id]
  return c ~= nil and c[bodyOnly and "body" or "full"] ~= nil
end

-- Advance queued builds inside a per-frame time budget. A partially built body
-- for a seam just crossed runs first, then current-map jobs, visible neighbours,
-- and speculative destinations. All foreground classes get enough time to
-- finish a packed Android route before the player reaches its seam. `covered`
-- says the world pass is hidden
-- this frame (a warp's fade, a menu): nothing visible can hitch, so the
-- slice opens up and a door fade swallows most of a destination build.
local FOREGROUND_SLICE = 0.012
local IDLE_SLICE = 0.005
local COVERED_SLICE = 0.030

local function nextJob()
  local pick = jobs[1]
  for i = 2, #jobs do
    local candidate = jobs[i]
    if (candidate.priority or 0) > (pick.priority or 0) then pick = candidate end
  end
  return pick
end

function ChunkMesher.pump(covered)
  if #jobs == 0 then return end
  local pick = nextJob()
  local slice = covered and COVERED_SLICE
                or ((pick.priority or 0) > 0 and FOREGROUND_SLICE
                    or IDLE_SLICE)
  local deadline = clock() + slice
  while pick do
    if not pick.co then
      pick.co = coroutine.create(runJob)
    end
    Budget.begin(pick.co, deadline - clock())
    local ok, err = coroutine.resume(pick.co, pick)
    Budget.finish()
    if not ok then
      finishJob(pick, false, err)
    elseif coroutine.status(pick.co) == "dead" then
      finishJob(pick, true)
    else
      return   -- slice spent mid-build; resume next frame
    end
    if clock() >= deadline or #jobs == 0 then return end
    pick = nextJob()
  end
end

-- Meshes for `map`, built SYNCHRONOUSLY on first use -- the historical
-- contract, kept for probes and any direct caller. `false` is cached for
-- a map whose mesh could not be built so a headless run does not retry
-- every frame. `masks` (the full variant's neighbour-body rects) is
-- static per map id -- a map's connections never change -- so it caches
-- like everything else.
function ChunkMesher.get(map, bodyOnly, masks)
  local slot = bodyOnly and "body" or "full"
  local c = entry(map.id)
  if c.grass == nil or c.flowers == nil or (c.stale and c.stale.aux) then
    local okG, grass = pcall(buildGrassMesh, map)
    local okF, flowers = pcall(buildFlowerMesh, map)
    swapSlot(c, "grass", (okG and grass) or false)
    swapSlot(c, "flowers", (okF and flowers) or false)
    if c.stale then c.stale.aux = nil end
  end
  if c[slot] == nil or (c.stale and c.stale[slot]) then
    local ok, mesh, water, visuals = pcall(ChunkMesher.build, map, bodyOnly,
      masks, true, mapHasVisualObjects(map))
    if not ok then
      print("[warn] voxel mesh build failed for " .. tostring(map.id)
            .. ": " .. tostring(mesh))
    end
    swapSlot(c, slot, (ok and mesh) or false)
    swapSlot(c, waterSlot(slot), (ok and water) or false)
    swapVisualSlot(c, slot, (ok and visuals) or nil)
    if c.stale then
      c.stale[slot] = nil
      if not (c.stale.full or c.stale.body or c.stale.aux) then
        c.stale = nil
      end
    end
    local key = jobKey(map.id, slot)
    local job = jobIndex[key]
    if job then finishJob(job, true) end
  end
  return c[slot] or nil
end

-- The cached mesh, or nil -- never builds. The async path's read side.
function ChunkMesher.peek(map, bodyOnly)
  local c = cache[map.id]
  local mesh = c and c[bodyOnly and "body" or "full"]
  return mesh or nil
end

-- A slot's terrain mesh AND the water surface lifted out of it, as one
-- answer. Never builds, like peek.
--
-- Both or neither, always from the SAME slot: the water was cut out of that
-- exact geometry, so pairing a full mesh with a body build's water would
-- draw the border ring's ponds twice and leave the body's as holes. Callers
-- that fall back from one variant to the other fall back through this, so
-- there is nowhere for the two to be chosen separately.
function ChunkMesher.pair(map, bodyOnly)
  local c = cache[map.id]
  if not c then return nil, nil end
  local slot = bodyOnly and "body" or "full"
  local list = c[visualSlot(slot)]
  local visible, shadow = nil, nil
  if type(list) == "table" then
    local ids = {}
    for id in pairs(list) do ids[#ids + 1] = id end
    table.sort(ids)
    visible, shadow = {}, {}
    for _, id in ipairs(ids) do
      local record = { id = id, mesh = list[id] }
      shadow[#shadow + 1] = record
      if visualObjectVisible(id) then visible[#visible + 1] = record end
    end
  end
  return c[slot] or nil, c[waterSlot(slot)] or nil, visible, shadow
end

function ChunkMesher.grass(map)
  local c = cache[map.id]
  return c and c.grass or nil
end

function ChunkMesher.flowers(map)
  local c = cache[map.id]
  return c and c.flowers or nil
end

-- Authored figures as `{ mesh, wx, wz, y, w }` records -- each placed by
-- its own leaning matrix at draw time, so they cannot share one mesh.
function ChunkMesher.figures(map)
  local c = cache[map.id]
  local list = c and c.figures
  return (type(list) == "table") and list or nil
end

-- ------- taking one prop out of a mesh that is already on screen
--
-- Zeroing a run's vertices leaves degenerate triangles, which draw nothing.
-- The ground stays, because it comes from the tile loop and owns no runs.
-- The spans ride the disk cache too, so a precached map can do this without
-- having run the geometry pass this session.
--
-- This only removes what a build already placed. Anything an edit adds, and
-- the shading corrections around it, still wait for the rebuild.

-- position/uv/shade, six floats (Voxel3D.FORMAT)
local BLANK_VERTEX_BYTES = 6 * 4

-- The vertex ranges owned by props inside a world-pixel rect, merged where
-- they are adjacent so one tree costs one upload.
--
-- A run belongs to the rect when the center of its footprint does. Testing
-- for overlap instead pulled in the neighbouring tree every time, because
-- the 2x2-cell canopy groups are a whole block wide.
function ChunkMesher.blockRanges(spans, px0, pz0, px1, pz1)
  local out = {}
  if type(spans) ~= "table" then return out end
  local i, n = 1, #spans
  local function inRect(k)
    local cx, cz = spans[k + 2], spans[k + 3]
    return cx >= px0 and cx < px1 and cz >= pz0 and cz < pz1
  end
  while i <= n do
    if inRect(i) then
      local first = spans[i]
      local last = first + spans[i + 1]
      local j = i + 4
      while j <= n and spans[j] == last and inRect(j) do
        last = spans[j] + spans[j + 1]
        j = j + 4
      end
      out[#out + 1] = { first, last - first }
      i = j
    else
      i = i + 4
    end
  end
  return out
end

local zeroCache = ""
local function zeroBytes(n)
  if #zeroCache < n then zeroCache = string.rep(string.char(0), n) end
  return zeroCache:sub(1, n)
end

local function blankMesh(mesh, spans, px0, pz0, px1, pz1)
  if not (mesh and mesh.setVertices and spans
          and love and love.data and love.data.newByteData) then
    return 0
  end
  local dropped = 0
  for _, r in ipairs(ChunkMesher.blockRanges(spans, px0, pz0, px1, pz1)) do
    local ok, data = pcall(love.data.newByteData,
                           zeroBytes(r[2] * BLANK_VERTEX_BYTES))
    if ok and data then
      -- setVertices takes a 1-based start vertex; runs are recorded 0-based
      if pcall(mesh.setVertices, mesh, data, r[1] + 1) then
        dropped = dropped + r[2]
      end
      pcall(data.release, data)
    end
  end
  return dropped
end

-- The part of a block a swap actually changed, in world pixels, rounded out
-- to whole 16px cells because that is what a prop is owned by.
--
-- Cut swaps a whole block id but the two ids usually differ in one cell.
-- Cerulean's cuttable block is a single tree in the middle of a hedge, and
-- dropping the block's props wholesale took the hedge down with it.
--
-- nil when nothing changed. The whole block when the tileset cannot answer,
-- which leaves the caller with the old behaviour.
function ChunkMesher.changedRect(map, bx, by, before)
  local px0, pz0 = bx * 32, by * 32
  local blocks = map and map.tileset and map.tileset.blocks
  local a = before and blocks and blocks[before + 1]
  local b = blocks and map.blockAt and blocks[map:blockAt(bx, by) + 1]
  if not (a and b) then return px0, pz0, px0 + 32, pz0 + 32 end
  local x0, z0, x1, z1 = math.huge, math.huge, -math.huge, -math.huge
  for i = 1, 16 do
    if a[i] ~= b[i] then
      local tx, tz = (i - 1) % 4, math.floor((i - 1) / 4)
      x0 = math.min(x0, px0 + tx * 8)
      x1 = math.max(x1, px0 + tx * 8 + 8)
      z0 = math.min(z0, pz0 + tz * 8)
      z1 = math.max(z1, pz0 + tz * 8 + 8)
    end
  end
  if x1 < x0 then return nil end
  -- out to cell boundaries: a prop is owned by the 16px cell it stands in,
  -- and a rect cutting a cell in half excludes that cell's own center
  return math.floor(x0 / 16) * 16, math.floor(z0 / 16) * 16,
         math.ceil(x1 / 16) * 16, math.ceil(z1 / 16) * 16
end

-- Drop the props on the changed part of a block from whatever this map is
-- drawing now. Returns how many vertices were zeroed, which is 0 when the
-- block held nothing the prop passes owned. Walls and ledges come from the
-- tile loop, so those still wait for the rebuild.
--
-- `before` is the block id that was there. Without it the whole block goes.
function ChunkMesher.dropBlock(mapId, bx, by, map, before)
  local c = mapId and cache[mapId]
  if not (c and bx and by) then return 0 end
  local px0, pz0, px1, pz1 = ChunkMesher.changedRect(map, bx, by, before)
  if not px0 then return 0 end
  local n = 0
  for _, slot in ipairs({ "full", "body" }) do
    n = n + blankMesh(c[slot], c[slot .. "Spans"], px0, pz0, px1, pz1)
  end
  -- tufts and billboards are meshes of their own, so a cut through tall
  -- grass has to reach them as well
  n = n + blankMesh(c.grass, c.grassSpans, px0, pz0, px1, pz1)
  n = n + blankMesh(c.flowers, c.flowersSpans, px0, pz0, px1, pz1)
  return n
end

-- Rebuild a map's meshes IN PLACE: the stale meshes keep drawing while
-- replacements cook, and each slot swaps as its build lands. This is
-- the block-edit path (a cut tree, a door stamp) -- invalidate() drops
-- the mesh outright, and until the async rebuild landed the scene fell
-- to the flat 2D path, a whole-world blink for a one-block edit.
-- `bx, by` name the block that changed and `map`/`before` narrow the drop to
-- the part of it that moved, so a felled tree goes on the frame it was cut
-- rather than waiting out the rebuild. Called without them, nothing changes.
function ChunkMesher.refresh(mapId, bx, by, map, before)
  if not mapId then return ChunkMesher.invalidate() end
  -- Never erase the immutable persistent record. Some engine/mod paths emit a
  -- conservative block notification while loading an area even when its final
  -- geometry is unchanged. The queued refresh reads BAVC only for canonical
  -- geometry; a real live edit is rebuilt in RAM and cannot replace it.
  local c = cache[mapId]
  -- nothing drawable cached: the plain drop costs nothing visible
  if not (c and (c.full or c.body)) then
    return ChunkMesher.invalidate(mapId)
  end
  ChunkMesher.dropBlock(mapId, bx, by, map, before)
  Structures.invalidate(mapId)
  gen[mapId] = (gen[mapId] or 0) + 1
  for i = #jobs, 1, -1 do
    local job = jobs[i]
    if job.id == mapId then
      jobIndex[jobKey(job.id, job.slot)] = nil
      table.remove(jobs, i)
    end
  end
  -- false-cached slots count as stale too: a retry after a failed build
  -- is exactly a rebuild
  c.stale = { aux = true,
              full = (c.full ~= nil) or nil,
              body = (c.body ~= nil) or nil }
end

-- Evict everything outside `live` (a set of map ids): far maps' meshes
-- are released -- GPU buffer and LOVE's CPU copy both -- and their
-- Structures analysis dropped. The live set is the current map plus its
-- rendered neighbours, so memory stays bounded by what is on or near the
-- screen instead of growing with every area ever visited.
--
-- The PREVIOUS live set is retained too: warping into a building
-- collapses the set to one small interior, and evicting the town at the
-- door means rebuilding the whole neighbourhood on the way out -- a
-- flat-world flash after every house. One set of history makes the
-- round trip free while staying bounded at two neighbourhoods.
local prevLive = {}

function ChunkMesher.setLive(live)
  for id, c in pairs(cache) do
    if not live[id] and not prevLive[id] then
      releaseEntry(c)
      cache[id] = nil
      gen[id] = (gen[id] or 0) + 1
      Structures.invalidate(id)
    end
  end
  for i = #jobs, 1, -1 do
    local job = jobs[i]
    if not live[job.id] and not prevLive[job.id] then
      jobIndex[jobKey(job.id, job.slot)] = nil
      table.remove(jobs, i)
    end
  end
  prevLive = live
end

-- Release session-only meshes/analysis while deliberately keeping the
-- persistent BAVC files.  The title-screen whole-game generator builds one
-- map at a time and calls this between maps so a complete cache does not also
-- become a complete copy of the world in GPU/RAM.  This differs from
-- invalidate(), which also cancels queued work and discards live GPU meshes.
function ChunkMesher.evictRuntime(mapId)
  local function evict(id)
    local c = cache[id]
    if c then releaseEntry(c) end
    cache[id] = nil
    gen[id] = (gen[id] or 0) + 1
    Structures.invalidate(id)
  end
  if mapId then
    evict(mapId)
  else
    local ids = {}
    for id in pairs(cache) do ids[#ids + 1] = id end
    for _, id in ipairs(ids) do evict(id) end
    prevLive = {}
  end
  for i = #jobs, 1, -1 do
    local job = jobs[i]
    if mapId == nil or job.id == mapId then
      jobIndex[jobKey(job.id, job.slot)] = nil
      table.remove(jobs, i)
    end
  end
end

-- Drop one map's mesh (Cut swapped a block) or all of them (hot reload).
-- Structures' analysis is derived from the same block layer, so it drops
-- in the same breath; in-flight builds of the map are cancelled through
-- the generation counter.
function ChunkMesher.invalidate(mapId)
  Structures.invalidate(mapId)
  if mapId then
    local c = cache[mapId]
    if c then releaseEntry(c) end
    cache[mapId] = nil
    gen[mapId] = (gen[mapId] or 0) + 1
  else
    for _, c in pairs(cache) do releaseEntry(c) end
    cache = {}
    for id in pairs(gen) do gen[id] = gen[id] + 1 end
  end
  for i = #jobs, 1, -1 do
    local job = jobs[i]
    if mapId == nil or job.id == mapId then
      jobIndex[jobKey(job.id, job.slot)] = nil
      table.remove(jobs, i)
    end
  end
end

-- Void-fill toggle (trees <-> black) changes ONLY the apron ring that lives in
-- the FULL slot. Disk.fingerprint keeps `void` in the FULL key alone, and
-- Structures.lua's hullRingOnly gates the ring on TileRenderer.voidFill, while
-- BODY (built with r=0, no ring) and AUX (grass/flowers/figures) are
-- void-invariant. A global invalidate() on toggle therefore released the heavy
-- body/aux GPU meshes for every live map -- the "every map stutters" on
-- toggle. Keep body/aux drawn and mark only the FULL slot stale; the ring
-- rebuilds in the background while the body stays on screen, exactly like the
-- body-only phase of a normal build. Structures must re-analyse (hullRingOnly
-- is read at analysis time) so the new ring comes out right.
function ChunkMesher.invalidateVoidRings()
  for id, c in pairs(cache) do
    Structures.invalidate(id)
    gen[id] = (gen[id] or 0) + 1
    c.stale = c.stale or {}
    c.stale.full = true
    for i = #jobs, 1, -1 do
      local job = jobs[i]
      if job.id == id and not job.bodyOnly then
        jobIndex[jobKey(job.id, job.slot)] = nil
        table.remove(jobs, i)
      end
    end
  end
end

Assets.register(function() ChunkMesher.invalidate() end)

-- Drop the entire voxel mesh cache -- both the live GPU/RAM meshes (via
-- invalidate) and the on-disk BAVC files (via Disk.purge) -- so the mesher
-- rebuilds every area from scratch on the next frame. This is the "DROP MESH
-- CACHE" pause-menu action: use it after a geometry/grounding change (e.g. the
-- pinBase cylinder/tree fix) left stale floating meshes baked into the cache.
-- Fails open; a missing or read-only backend simply leaves the disk as-is.
function ChunkMesher.purgeCache()
  ChunkMesher.invalidate()
  if Disk and Disk.purge then
    pcall(Disk.purge)
  end
end

return ChunkMesher
