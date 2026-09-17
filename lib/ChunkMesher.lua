local function shadeTimes(shade, factor)
  if type(shade) == "table" then
    return {shade[1]*factor, shade[2]*factor, shade[3]*factor, shade[4]*factor}
  end
  return shade * factor
end

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
local Timings = V.require("LoadTimings")
local MeshDisk = V.require("VoxelMeshDisk")
local traceOK, CacheTrace = pcall(V.require, "CacheTrace")
if not traceOK or type(CacheTrace) ~= "table" or type(CacheTrace.log) ~= "function" then
  CacheTrace = { log = function() end }
end
local function trees(method, ...)
  local ok, flora = pcall(V.require, "CommunityFlora")
  if ok and flora and type(flora[method]) == "function" then return flora[method](...) end
end
local CommunityVisuals = V.require("CommunityVisuals")

local ffi = nil
do
  local ok, mod = pcall(require, "ffi")
  if ok then ffi = mod end
end

local ChunkMesher = {}

-- Exact TEST435 material identities. These remain visual classifiers only;
-- Battle Art collision and source map tiles are never changed.
local KANTO_PATH_TILE = { [35] = true, [57] = true }
local KANTO_COURTYARD_ANCHOR_TILE = { [16] = true, [33] = true }
local KANTO_BLOCK55_COURT_TILE = 91
local KANTO_PATH_SWATCH_TILE = 57
local KANTO_WOOD_TILE = 60
local KANTO_GRASS_TILE = 44

function ChunkMesher.kantoSurfaceKind(tilesetId, class, tile)
  if tilesetId ~= "OVERWORLD" or class ~= "ground" then return nil end
  if KANTO_PATH_TILE[tile] then return "path" end
  if tile == KANTO_WOOD_TILE then return "wood" end
  return nil
end

function ChunkMesher.kantoCourtyardMember(tile, hasAnchor)
  return KANTO_COURTYARD_ANCHOR_TILE[tile] == true
         or (tile == 35 and hasAnchor == true)
end

function ChunkMesher.kantoBlock55CourtyardMember(tile)
  return tile == KANTO_BLOCK55_COURT_TILE
end

-- EDGE1: material exceptions belong to exact authored cliff blocks.
-- Full-block matching keeps ordinary path corners and wooden bridges intact.
function ChunkMesher.cliffGroundFinish(tileAt, tx, ty)
  local tile = tileAt(tx, ty)
  if tile ~= 35 and tile ~= 60 and tile ~= 57 then return nil end
  local bx, by = math.floor(tx / 4) * 4, math.floor(ty / 4) * 4
  local patterns = {
    {35, "grass", {35,30,1,1,30,39,17,17,39,39,17,17,39,39,17,17}},
    {60, "grass", {44,44,44,44,44,44,44,44,44,44,44,44,55,52,60,60}},
    {60, "path", {39,57,57,57,39,57,57,57,39,57,57,57,54,55,60,60}},
    {60, "path", {57,57,57,57,57,57,57,57,57,57,57,57,60,60,54,55}},
  }
  for _, p in ipairs(patterns) do
    if tile == p[1] or (tile == 57 and p[2] == "path") then
      local matches = true
      for i=1,16 do
        if tileAt(bx+(i-1)%4, by+math.floor((i-1)/4)) ~= p[3][i] then
          matches=false; break
        end
      end
      if matches then
        if p[2] == "path" then
          local connected=false
          for y=by-1,by+4 do for x=bx-1,bx+4 do
            if (x==bx-1 or x==bx+4) ~= (y==by-1 or y==by+4) then
              local t=tileAt(x,y)
              if t==35 or t==57 then connected=true end
            end
          end end
          if not connected then return "grass" end
          if tile==57 then return nil end
        end
        return p[2]
      end
    end
  end
end

function ChunkMesher.kantoWoodAxis(isWood, tx, ty)
  local function span(dx, dy)
    local n = 1
    for sign = -1, 1, 2 do
      for step = 1, 8 do
        if not isWood(tx + dx * step * sign, ty + dy * step * sign) then break end
        n = n + 1
      end
    end
    return n
  end
  return span(0, 1) >= span(1, 0) and "z" or "x"
end

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
      if x0 == nil then return end
      first, cx, cz = count(), (x0 + x1) / 2, (z0 + z1) / 2
    end,
    close = close,
    runs = function() close() return runs end,
  }
end

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
local PACKED_VERTEX = "<" .. string.rep("f", 6 * 6)
local PACKED_VERTEX_BYTES = 6 * 4
-- TEST93: keep terrain transfers well below TEST91's 4096-quad bursts without
-- over-fragmenting first load. These 72 KiB packed chunks and 8192-vertex raw
-- slices are independent of CommunityFlora's mature-tree mesh publication.
local PACKED_QUADS_PER_CHUNK = 512
local UPLOAD_VERTICES_PER_SLICE = 8192

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
        local result = Timings.call("mesh_alloc", love.graphics.newMesh,
                                             Voxel3D.FORMAT, n,
                                             "triangles", "static")
        local first = 1
        for _, chunk in ipairs(chunks) do
          local data = love.data.newByteData(chunk)
          Timings.call("mesh_write", result.setVertices, result, data, first)
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
        local m = Timings.call("mesh_alloc", love.graphics.newMesh,
                                        Voxel3D.FORMAT, n,
                                        "triangles", "static")
        local CHUNK = UPLOAD_VERTICES_PER_SLICE
        local i = 0
        while i < n do
          local count = math.min(CHUNK, n - i)
          local bytes = count * 6 * 4
          local data = love.data.newByteData(bytes)
          ffi.copy(data:getFFIPointer(), buf + i * 6, bytes)
          Timings.call("mesh_write", m.setVertices, m, data, i + 1)
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
      local result = Timings.call("mesh_alloc", love.graphics.newMesh,
                                           Voxel3D.FORMAT, record.n,
                                           "triangles", "static")
      local first = 0
      while first < record.n do
        local count = math.min(UPLOAD_VERTICES_PER_SLICE, record.n - first)
        local byteCount = count * PACKED_VERTEX_BYTES
        local data = love.data.newByteData(byteCount)
        ffi.copy(data:getFFIPointer(),
          ffi.cast("const uint8_t*", record.ptr)
            + first * PACKED_VERTEX_BYTES, byteCount)
        Timings.call("mesh_write", result.setVertices, result, data, first + 1)
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
    local result = Timings.call("mesh_alloc", love.graphics.newMesh,
                                         Voxel3D.FORMAT, record.n,
                                         "triangles", "static")
    local first, carry = 1, ""
    local sliceBytes = UPLOAD_VERTICES_PER_SLICE * PACKED_VERTEX_BYTES
    for _, chunk in ipairs(record.chunks) do
      local bytes = carry .. chunk
      local offset = 1
      while #bytes - offset + 1 >= sliceBytes do
        local data = love.data.newByteData(
          bytes:sub(offset, offset + sliceBytes - 1))
        Timings.call("mesh_write", result.setVertices, result, data, first)
        first = first + UPLOAD_VERTICES_PER_SLICE
        data:release()
        offset = offset + sliceBytes
        Budget.check()
      end
      carry = bytes:sub(offset)
    end
    local usable = math.floor(#carry / PACKED_VERTEX_BYTES)
                   * PACKED_VERTEX_BYTES
    if usable > 0 then
      local data = love.data.newByteData(carry:sub(1, usable))
      Timings.call("mesh_write", result.setVertices, result, data, first)
      first = first + usable / PACKED_VERTEX_BYTES
      data:release()
      carry = carry:sub(usable + 1)
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
-- Detailed material faces subdivide a tile, but its ambient-light field still
-- spans the whole tile. Sample that field at each emitted corner instead of
-- restarting the full dark-to-light ramp on every stone or timber board.
-- Coordinates follow the PARENT face's corner order; reversing either extent
-- handles north/east walls without changing the child geometry's winding.
local function shadeRect(c, shade, axisU, u0, u1, axisV, v0, v1, tone)
  if type(shade) ~= "table" then return shade * tone end
  local out = {}
  for i = 1, 4 do
    local u = math.max(0, math.min(1, (c[i][axisU] - u0) / (u1 - u0)))
    local v = math.max(0, math.min(1, (c[i][axisV] - v0) / (v1 - v0)))
    local lower = shade[1] + (shade[2] - shade[1]) * u
    local upper = shade[4] + (shade[3] - shade[4]) * u
    out[i] = (lower + (upper - lower) * v) * tone
  end
  return out
end

local function runGeometry(map, bodyOnly, masks, sink, waterSink, visualSinks)
  local LG={} -- Group city material state to stay within Lua/LuaJIT local limits.
  local push = sink.push
  local waterPush = waterSink and waterSink.push or nil
  local tileset = map.tileset
  local viridianForest = CommunityVisuals.customForest()
    and tileset.id == "FOREST"
    and tostring(map.id or "") == "VIRIDIAN_FOREST"
  LG.mapId = tostring(map.id or ""):upper()
  LG.cityGroundMap = CommunityVisuals.isCityGroundMap(map)
  -- CITY GROUND owns Lavender/Fuchsia independently of the broad GRASS row.
  LG.legendaryCityGround = LG.cityGroundMap and CommunityVisuals.customCityGround()
  LG.lavenderGround = tileset.id == "OVERWORLD" and LG.mapId == "LAVENDER_TOWN"
  LG.lavenderLegendaryGround = LG.lavenderGround and LG.legendaryCityGround
  local KANTO_PATH_SWATCH_TILE = LG.lavenderLegendaryGround and 35 or KANTO_PATH_SWATCH_TILE
  LG.fuchsiaGround = LG.legendaryCityGround and LG.mapId == "FUCHSIA_CITY"
  LG.customGrass = CommunityVisuals.customGrass() and not LG.cityGroundMap
  LG.grassReplacement = LG.customGrass or LG.fuchsiaGround
  LG.lavenderBattleCurrentGround = LG.lavenderGround and not LG.legendaryCityGround
  local towerInterior = tileset.id == "CEMETERY"
    and LG.mapId:match("^POKEMON_TOWER_[1-7]F$") ~= nil
    and CommunityVisuals.customTower()
  local S = Structures.forMap(map)
  local perRow = tileset.tilesPerRow or 16
  local sourceAtlasW = tileset.imageWidth or (perRow * 8)
  local sourceAtlasH = tileset.imageHeight or 48
  local TOWER_WALL_SIZE = 2048
  local TOWER_COUNTER_SIZE = 1024
  local TOWER_FLOOR_SIZE = 2048
  local TOWER_DETAIL_SIZE = 1024
  local TOWER_WALL_REGION_X = sourceAtlasW
  local TOWER_WALL_REGION_Y = 0
  local TOWER_COUNTER_REGION_X = TOWER_WALL_REGION_X + TOWER_WALL_SIZE
  local TOWER_COUNTER_REGION_Y = 0
  local TOWER_FLOOR_REGION_X = sourceAtlasW
  local TOWER_FLOOR_REGION_Y = TOWER_WALL_SIZE
  local TOWER_STAIR_REGION_X = TOWER_COUNTER_REGION_X
  local TOWER_STAIR_REGION_Y = TOWER_COUNTER_SIZE
  local TOWER_GRAVE_REGION_X = TOWER_COUNTER_REGION_X
  local TOWER_GRAVE_REGION_Y = TOWER_WALL_SIZE
  local TOWER_COUNTER_TOP_REGION_X = TOWER_COUNTER_REGION_X
  local TOWER_COUNTER_TOP_REGION_Y = 3072
  local TOWER_MAP_MARGIN = RING * 4 * 8
  local towerWorldW = ((map.def and map.def.width) or 1) * 4 * 8
  local towerWorldH = ((map.def and map.def.height) or 1) * 4 * 8
  local towerWallSpan = math.max(towerWorldW, towerWorldH)
    + TOWER_MAP_MARGIN * 2
  -- TerrainAtlas packs TEST124's independent 2048px wall, approved 1024px
  -- counter and 2048px floor materials only on Tower maps. Wall and counter
  -- occupy the first material row; floor sits directly below wall. This keeps
  -- the finished atlas inside a conservative 4096px mobile-GPU edge while all
  -- legacy tiles remain at their original coordinates.
  local atlasW = towerInterior and
    (sourceAtlasW + TOWER_WALL_SIZE + TOWER_COUNTER_SIZE)
    or sourceAtlasW
  local atlasH = towerInterior and
    math.max(sourceAtlasH, TOWER_WALL_SIZE + TOWER_FLOOR_SIZE)
    or sourceAtlasH

  -- Give the counter its own full material range. TEST122 projected the whole
  -- room across this small L, so its few occupied texels looked soft even with
  -- a good source image. Bounds are visual only; collision and placement stay
  -- on the authored counter cells.
  local counterMinX, counterMinZ, counterMaxX, counterMaxZ
  if towerInterior then
    local tilesW = ((map.def and map.def.width) or 1) * 4
    local tilesH = ((map.def and map.def.height) or 1) * 4
    for cty = 0, tilesH - 1 do
      for ctx = 0, tilesW - 1 do
        local ck = keyOf(ctx, cty)
        local cs = S.shapeAt[ck]
        if cs and cs.class == "counter" and not S.skip[ck] then
          local cx0, cz0 = ctx * 8, cty * 8
          counterMinX = counterMinX and math.min(counterMinX, cx0) or cx0
          counterMinZ = counterMinZ and math.min(counterMinZ, cz0) or cz0
          counterMaxX = counterMaxX and math.max(counterMaxX, cx0 + 8) or (cx0 + 8)
          counterMaxZ = counterMaxZ and math.max(counterMaxZ, cz0 + 8) or (cz0 + 8)
        end
      end
    end
  end
  counterMinX, counterMinZ = counterMinX or 0, counterMinZ or 0
  counterMaxX, counterMaxZ = counterMaxX or 8, counterMaxZ or 8
  local counterSpanX = math.max(8, counterMaxX - counterMinX)
  local counterSpanZ = math.max(8, counterMaxZ - counterMinZ)

  local function towerMaterialUV(regionX, regionY, regionSize, fu, fv)
    fu = math.max(0, math.min(1, fu))
    fv = math.max(0, math.min(1, fv))
    local px = 0.5 + fu * (regionSize - 1)
    local py = 0.5 + fv * (regionSize - 1)
    return { (regionX + px) / atlasW, (regionY + py) / atlasH }
  end

  local function towerGraniteWallUV(axis, y)
    -- TEST121's fixed 256px range ended before the room did. Coordinates past
    -- it clamped to one texel and became the long horizontal stripes visible in
    -- the supplied screenshots. Normalize against this map's complete body and
    -- render ring, so no wall or rib can ever sample a stretched edge.
    return towerMaterialUV(TOWER_WALL_REGION_X, TOWER_WALL_REGION_Y,
      TOWER_WALL_SIZE,
      (axis + TOWER_MAP_MARGIN) / towerWallSpan,
      (y + 8) / 80)
  end

  local function towerGranitePlanUV(x, z)
    return towerMaterialUV(TOWER_WALL_REGION_X, TOWER_WALL_REGION_Y,
      TOWER_WALL_SIZE,
      (x + TOWER_MAP_MARGIN) / (towerWorldW + TOWER_MAP_MARGIN * 2),
      (z + TOWER_MAP_MARGIN) / (towerWorldH + TOWER_MAP_MARGIN * 2))
  end

  local function towerFloorUV(x, z)
    -- The floor owns a second, low-contrast honed-stone sheet. One mapping
    -- covers the whole room and border ring without repeats or edge clamping.
    return towerMaterialUV(TOWER_FLOOR_REGION_X, TOWER_FLOOR_REGION_Y,
      TOWER_FLOOR_SIZE,
      (x + TOWER_MAP_MARGIN) / (towerWorldW + TOWER_MAP_MARGIN * 2),
      (z + TOWER_MAP_MARGIN) / (towerWorldH + TOWER_MAP_MARGIN * 2))
  end

  local function towerCounterPlanUV(x, z)
    return towerMaterialUV(TOWER_COUNTER_TOP_REGION_X, TOWER_COUNTER_TOP_REGION_Y,
      TOWER_COUNTER_SIZE,
      (x - counterMinX) / counterSpanX,
      (z - counterMinZ) / counterSpanZ)
  end

  local function towerCounterSideUV(d, axis, y)
    local horizontal = (d == 5 or d == 6)
      and ((axis - counterMinX) / counterSpanX)
      or ((axis - counterMinZ) / counterSpanZ)
    return towerMaterialUV(TOWER_COUNTER_REGION_X, TOWER_COUNTER_REGION_Y,
      TOWER_COUNTER_SIZE,
      horizontal, 0.08 + (y / 8) * 0.84)
  end

  local function towerDetailUV(kind, c, q)
    local rx = kind == "stair" and TOWER_STAIR_REGION_X or TOWER_GRAVE_REGION_X
    local ry = kind == "stair" and TOWER_STAIR_REGION_Y or TOWER_GRAVE_REGION_Y
    local yFlat = math.abs(q[1][2] - q[2][2]) < .0001
      and math.abs(q[1][2] - q[3][2]) < .0001
    local xFlat = math.abs(q[1][1] - q[2][1]) < .0001
      and math.abs(q[1][1] - q[3][1]) < .0001
    local u, v
    if yFlat then
      u, v = (c[1] % 16) / 16, (c[3] % 16) / 16
    elseif xFlat then
      u, v = (c[3] % 16) / 16, 1 - math.max(0, math.min(16, c[2])) / 16
    else
      u, v = (c[1] % 16) / 16, 1 - math.max(0, math.min(16, c[2])) / 16
    end
    return towerMaterialUV(rx, ry, TOWER_DETAIL_SIZE, u, v)
  end

  local function heightAt(tx, ty)
    local k = keyOf(tx, ty)
    if S.skip[k] then return 0 end
    local run = S.runs[k]
    if run then return run.h end
    local s = S.shapeAt[k]
    return s and s.h or 0
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
    local n = heightAt(tx, ty - 1) > h
    local s = heightAt(tx, ty + 1) > h
    local e = heightAt(tx + 1, ty) > h
    local w = heightAt(tx - 1, ty) > h
    local nw = heightAt(tx - 1, ty - 1) > h
    local ne = heightAt(tx + 1, ty - 1) > h
    local sw = heightAt(tx - 1, ty + 1) > h
    local se = heightAt(tx + 1, ty + 1) > h
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
    local perCorner = type(shade) == "table"
    local y1, y2, y3, y4 = c[1][2], c[2][2], c[3][2], c[4][2]
    if math.min(y1, y2, y3, y4) >= AO_RISE then return shade end
    for i = 1, 4 do
      local t = c[i][2] / AO_RISE
      -- Compose with model contact shading and preserve the facade sign.
      local base = perCorner and shade[i] or shade
      aoProp[i] = base * (t >= 1 and 1 or (1 - AO_GROUND * (1 - t)))
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

  local def = map.def
  local tw, th = def.width * 4, def.height * 4         -- map size in tiles
  local r = bodyOnly and 0 or RING * 4

  -- The southern Route 10 approach is the eleven block rows from Rock
  -- Tunnel's lower mouth to Lavender Town. Keep the boundary authored by the
  -- map itself instead of baking viewport coordinates into the renderer:
  -- Route 10 is 36 block rows tall and its final 11 rows are this approach.
  -- This remains a GRASS-owned route, not a CITY GROUND map.
  local ROUTE10_LAVENDER_APPROACH_ROWS = 11 * 4
  local function route10LavenderApproachAt(ty)
    return tileset.id == "OVERWORLD" and LG.mapId == "ROUTE_10"
      and ty >= th - ROUTE10_LAVENDER_APPROACH_ROWS and ty < th
  end

  -- The very bottom Route 10 block at block coordinate (4,35) is the
  -- Lavender north-exit apron. In the source map it is block $31: a solid
  -- 4x4 field of tile $39. The broad cave-to-Lavender Battle Art treatment
  -- deliberately turns Route 10 ground/path donors sandy, which is correct
  -- for the approach but wrong for this one connection apron: when Route 10
  -- is drawn as Lavender's neighbour it appears as the isolated 32x32 "bald
  -- square" immediately north of the checker path. Keep only this authored
  -- seam block as plain grass in BOTH visual modes. No source/collision data
  -- is changed; this is a render-material override for the connection seam.
  function LG.route10LavenderExitLawnAt(tx, ty)
    return tileset.id == "OVERWORLD" and LG.mapId == "ROUTE_10"
      and tx >= 16 and tx <= 19
      and ty >= th - 4 and ty < th
  end

  -- Pokemon Tower's claim-only Route 10 half is presentation metadata owned
  -- by Buildings. Keep its exposed floor as a small Lavender lawn in BOTH
  -- visual modes: the Legendary option may evolve independently, while the
  -- approved grass/flower landscaping remains part of Battle Art. This also
  -- gives claimed cells with no neighbour-voted donor an opaque floor instead
  -- of exposing the neutral world underlay as a grey square.
  function LG.route10TowerLandscapeAt(tx, ty)
    local bed = S.lavenderFlowerbed
    return tileset.id == "OVERWORLD" and LG.mapId == "ROUTE_10" and not CommunityVisuals.customCityGround() and bed
      and tx >= bed.minX and tx <= bed.maxX
      and ty >= bed.minY and ty <= bed.maxY
  end

  -- TEST402 Kanto bedrock. TerrainAtlas writes these four warm-stone
  -- swatches into the first row of every authored ledge tile.  Sampling
  -- those texels keeps the replacement inside the existing terrain atlas:
  -- one cached chunk, one material, one draw call.
  local ROCK_TEXEL = {
    dark = { 0, 0 }, shadow = { 1, 0 },
    body = { 2, 0 }, light = { 3, 0 },
  }
  local CAVE_MOONSTONE_SWATCH_TILE = 2
  local TOWER_GRANITE_SWATCH_TILE = 17

  -- TEST403 Kanto retaining walls.  The cliff-mound family reuses tile 17
  -- for its broad body and the authored 2/36 corner-and-side pair.  Those
  -- same tile ids occur in roofs and walkable art, so the tile number alone
  -- is not permission to replace them: the resolved shape must still be an
  -- upright OVERWORLD wall.  Profiled buildings are claimed by Structures
  -- before this terrain path, which keeps their facades and roofs untouched.
  local KANTO_RETAINING_TILE = { [2] = true, [17] = true, [36] = true }
  local RETAINING_SWATCH_TILE = 13

  -- TEST416 paths.  $23 is the blank companion used around the dotted $39
  -- road tile; both become one continuous world-space limestone field. $3C
  -- is the real authored bridge surface (Route 24 block $54) and becomes wood.
  -- Classification stays visual only: TileShape, collision and map data are
  -- never changed.
  local function kantoSurfaceKind(s, tile)
    if not CommunityVisuals.customRoads() then return nil end
    return s and ChunkMesher.kantoSurfaceKind(tileset.id, s.class, tile) or nil
  end

  local function isKantoWoodAt(tx, ty)
    local s = S.shapeAt[keyOf(tx, ty)]
    return s and s.class == "ground"
           and S.tileAt[keyOf(tx, ty)] == KANTO_WOOD_TILE
  end

  local function isKantoPathAt(tx, ty)
    local s = S.shapeAt[keyOf(tx, ty)]
    return s and s.class == "ground"
           and KANTO_PATH_TILE[S.tileAt[keyOf(tx, ty)]] == true
  end

  -- TEST435: a claimed wall/prop cell can inherit the generic path tile even
  -- when only a narrow rim of that floor remains visible. Continue the real
  -- neighbouring material into that hidden cell so bridge timber and turf
  -- meet their pillars, trees and fences instead of stopping at a packed-
  -- earth outline. Only visible cardinal ground is allowed to vote; this
  -- prevents the finish from propagating through a structure or across a
  -- genuine road border. Timber wins when a bridge and grass meet at an end.
  local function claimedPathFinishAt(tx, ty)
    if tileset.id ~= "OVERWORLD" then return nil end
    local grass = false
    for _, side in ipairs(SIDES) do
      local nk = keyOf(tx + side[1], ty + side[2])
      local ns = S.shapeAt[nk]
      if not S.skip[nk] and ns and ns.class == "ground" then
        local tile = S.tileAt[nk]
        if tile == KANTO_WOOD_TILE then
          return "wood", ChunkMesher.kantoWoodAxis(
            isKantoWoodAt, tx + side[1], ty + side[2])
        end
        if tile == KANTO_GRASS_TILE then grass = true end
      end
    end
    return grass and "grass" or nil
  end

  -- TEST431: structure stamping may replace the visible shape and synthesized
  -- ground, but it deliberately leaves S.tileAt as the untouched map source.
  -- Read that source family here. TEST430 looked at S.ground after stamping,
  -- which is why the house court's original orange/white panel survived.
  -- The 3x3 context reaches a $10/$21 anchor from every $23 member of the
  -- authored $5D/$5E court blocks without turning ordinary $23 roads to stone.
  local function isKantoCourtyardAt(tx, ty, synthesizedTile)
    if not CommunityVisuals.customCourtyards() then return false end
    if tileset.id ~= "OVERWORLD" then return false end
    local tile = S.tileAt[keyOf(tx, ty)]
    -- TEST433: $5B occurs only in the all-$5B courtyard block $55. Props and
    -- building claims can replace the source tile while inheriting $5B as
    -- their synthesized floor, so accept either owner. This removes slivers
    -- beneath signs and applies the material to every authored $55 court.
    if ChunkMesher.kantoBlock55CourtyardMember(tile)
       or ChunkMesher.kantoBlock55CourtyardMember(synthesizedTile) then
      return true
    end
    if KANTO_COURTYARD_ANCHOR_TILE[tile] then return true end
    if tile ~= 35 then return false end
    for dy = -1, 1 do
      for dx = -1, 1 do
        if (dx ~= 0 or dy ~= 0)
           and KANTO_COURTYARD_ANCHOR_TILE[
                 S.tileAt[keyOf(tx + dx, ty + dy)]] then
          return true
        end
      end
    end
    return false
  end

  local function isKantoRetainingWall(s, tile, run, tx, ty)
    -- The southeast cliff corner is a shared ledge/wall cell, so it does
    -- not inherit a volume run. Match the exact original 2x2 footprint.
    local corner = false
    if tile == 19 and tx and ty then
      local x, z = math.floor(tx / 2) * 2, math.floor(ty / 2) * 2
      corner = map:tileAt(x,z)==55 and map:tileAt(x+1,z)==19
        and map:tileAt(x,z+1)==19 and map:tileAt(x+1,z+1)==39
    end
    return CommunityVisuals.customWalls() and tileset.id == "OVERWORLD" and (
      (run and run.kantoRetaining == true)
      or (s and s.class == "wall" and (KANTO_RETAINING_TILE[tile] == true or corner))
    )
  end

  local function rockUV(tile, sample)
    local ax = (tile % perRow) * 8
    local ay = math.floor(tile / perRow) * 8
    return { (ax + sample[1] + 0.5) / atlasW,
             (ay + sample[2] + 0.5) / atlasH }
  end

  local function pushSolid(c, uv, shade)
    push(c, { uv, uv, uv, uv }, shade)
  end

  local function topSolid(c, uv, shade, tone, x0, z0)
    pushSolid(c, uv, shadeRect(c, shade, 1, x0, x0 + 8,
                             3, z0, z0 + 8, tone))
  end

  local function sideSolid(c, uv, shade, tone, d, x0, z0, y0, y1)
    local axis = (d == 5 or d == 6) and 1 or 3
    local a0 = axis == 1 and x0 or z0
    local a1 = a0 + 8
    if d == 1 or d == 6 then a0, a1 = a1, a0 end
    pushSolid(c, uv, shadeRect(c, shade, axis, a0, a1,
                             2, y0, y1, tone))
  end

  -- Stable world-space variation.  It is evaluated only while the chunk is
  -- built, so camera movement, weather and battles cannot make a stone pop
  -- or change shape.
  local function rockNoise(a, b, salt)
    local n = a * 73856093 + b * 19349663 + salt * 83492791
    n = n % 104729
    if n < 0 then n = n + 104729 end
    return n / 104729
  end

  local function forestNoise(a, b, salt)
    local n = (a * 73856093 + b * 19349663 + salt * 83492791) % 104729
    if n < 0 then n = n + 104729 end
    n = (n * n * 37 + n * 17 + salt * 101) % 104729
    return n / 104729
  end

  -- Rotate and crop the four related forest-floor donors by stable world
  -- position, then apply a subtle continuous broad tone. This removes the
  -- repeated 8px dot grid without introducing a second floor pass.
  local function forestGroundTop(tx, ty, x0, z0, h, tile, shade)
    local u0, u1, v0, v1 = uvRect(tile, 0, 8)
    local turn = math.floor(forestNoise(tx, ty, 397) * 8)
    local sample = math.floor(forestNoise(tx, ty, 409) * 5)
    local span = sample == 0 and 1 or 0.62
    local offU = (sample == 2 or sample == 4) and 0.38 or 0
    local offV = (sample == 3 or sample == 4) and 0.38 or 0
    local mirror, rot = turn >= 4, turn % 4
    local uv = {}
    for i = 1, 4 do
      local du = (i == 2 or i == 3) and 1 or 0
      local dv = (i >= 3) and 1 or 0
      if mirror then du = 1 - du end
      if rot == 1 then
        du, dv = 1 - dv, du
      elseif rot == 2 then
        du, dv = 1 - du, 1 - dv
      elseif rot == 3 then
        du, dv = dv, 1 - du
      end
      du, dv = offU + du * span, offV + dv * span
      uv[i] = { u0 + (u1 - u0) * du, v0 + (v1 - v0) * dv }
    end
    local c = { { x0, h, z0 }, { x0 + 8, h, z0 },
                { x0 + 8, h, z0 + 8 }, { x0, h, z0 + 8 } }
    local lit = aoShades(tx, ty, h, shade)
    local perCorner, varied = type(lit) == "table", {}
    for i = 1, 4 do
      local gx, gz = c[i][1] / 8, c[i][3] / 8
      local tone = 0.955 + math.sin(gx * 0.24 + gz * 0.13) * 0.035
                         + math.sin(gx * 0.09 - gz * 0.21) * 0.025
      varied[i] = (perCorner and lit[i] or lit) * tone
    end
    push(c, uv, varied)
  end

  -- TEST36 warm cave materials. Ordinary top surfaces use solid atlas donors;
  -- all visible variation comes from broad cached geometry and low-frequency
  -- vertex tone. This prevents the old eight-pixel specks from repeating into
  -- confetti while keeping the cap visibly separate from the brick faces.
  local CAVE_PATTERN_TILES = {
    dirt = { 32, 33, 42 },
    shelf = { 5, 41 },
    -- Tile 2 is reserved for solid-colour geometry swatches. Keeping it out
    -- of visible top faces prevents its D/S/B/L sample row from reading as
    -- four-pixel confetti.
    rock = { 3, 12 },
  }
  local CAVE_SPECIAL_GROUND = { [20]=true, [34]=true, [47]=true }
  local CAVE_STAIR_PLATE = { [21]=true, [22]=true }
  -- TEST39 settles the true maze walls between TEST37 and TEST38: a 16px
  -- source wall renders at 30px. Walkable ledges are deliberately excluded
  -- from visual scaling so Ash, Pikachu and NPCs remain grounded on the same
  -- authored surface used by collision and movement.
  local CAVE_INNER_WALL_SCALE = 1.875

  local function caveSurfaceKind(s, tile)
    if tileset.id ~= "CAVERN" or not s
       or not CommunityVisuals.customCaves() then return nil end
    if s.class == "ground" and not CAVE_SPECIAL_GROUND[tile] then
      return "dirt"
    end
    if s.class == "ledge" and not CAVE_STAIR_PLATE[tile] then
      return "shelf"
    end
    if s.class == "wall" then return "rock" end
    return nil
  end

  -- Raise only true rendered cave-maze walls. TEST38 also lifted non-stair
  -- ledges, placing their visible surface above the actors' authored movement
  -- plane and making characters look submerged. Every ledge now keeps its
  -- source height; CavePerimeter still owns the untouched outer enclosure.
  local function caveRenderHeight(s, tile, h)
    if CommunityVisuals.customCaves() and tileset.id == "CAVERN"
       and h > 0 and s and s.class == "wall" then
      return h * CAVE_INNER_WALL_SCALE
    end
    return h
  end

  local function renderHeightAt(tx, ty)
    local k = keyOf(tx, ty)
    if S.skip[k] then return 0 end
    local s = S.shapeAt[k]
    local run = S.runs[k]
    local h = run and run.h or (s and s.h or 0)
    return caveRenderHeight(s, S.tileAt[k], h)
  end

  local function caveSolidUV(tile)
    local u0, u1, v0, v1 = uvRect(tile, 0, 8)
    return { (u0 + u1) * 0.5, (v0 + v1) * 0.5 }
  end

  local CAVE_FRACTURE_CELL = 22

  local function caveSeed(gx, gz, salt)
    local spread = CAVE_FRACTURE_CELL * 0.72
    return (gx + 0.5) * CAVE_FRACTURE_CELL
             + (rockNoise(gx, gz, salt + 41) - 0.5) * spread,
           (gz + 0.5) * CAVE_FRACTURE_CELL
             + (rockNoise(gx, gz, salt + 59) - 0.5) * spread
  end

  local function caveSeedWeight(gx, gz, salt)
    return (rockNoise(gx, gz, salt + 73) - 0.5) * 76
  end

  -- Clip a clockwise XZ polygon to a half plane A*x + B*z <= C.
  local function caveClip(poly, a, b, c)
    local out = {}
    local n = #poly
    if n == 0 then return out end
    local p = poly[n]
    local pd = a * p[1] + b * p[2] - c
    for i = 1, n do
      local q = poly[i]
      local qd = a * q[1] + b * q[2] - c
      local pin, qin = pd <= 0.0001, qd <= 0.0001
      if pin ~= qin then
        local t = pd / (pd - qd)
        out[#out + 1] = {
          p[1] + (q[1] - p[1]) * t,
          p[2] + (q[2] - p[2]) * t,
        }
      end
      if qin then out[#out + 1] = { q[1], q[2] } end
      p, pd = q, qd
    end
    return out
  end

  local function caveVoronoiCell(gx, gz, salt)
    local sx, sz = caveSeed(gx, gz, salt)
    local sw = caveSeedWeight(gx, gz, salt)
    local reach = CAVE_FRACTURE_CELL * 1.8
    local poly = {
      { sx - reach, sz - reach }, { sx + reach, sz - reach },
      { sx + reach, sz + reach }, { sx - reach, sz + reach },
    }
    for nz = gz - 2, gz + 2 do
      for nx = gx - 2, gx + 2 do
        if nx ~= gx or nz ~= gz then
          local ox, oz = caveSeed(nx, nz, salt)
          local ow = caveSeedWeight(nx, nz, salt)
          poly = caveClip(poly, ox - sx, oz - sz,
            (ox * ox + oz * oz - sx * sx - sz * sz + sw - ow) * 0.5)
          if #poly == 0 then return poly, sx, sz end
        end
      end
    end

    -- Pull the finished WORLD cell inward before clipping it to a source
    -- tile. This is the critical ordering: a stone split across two source
    -- tiles retains one continuous outline instead of gaining an 8px seam.
    local cx, cz = 0, 0
    for _, p in ipairs(poly) do cx, cz = cx + p[1], cz + p[2] end
    cx, cz = cx / #poly, cz / #poly
    -- Uneven opposing insets turn the clean TEST31 "grout" into narrow old
    -- fissures. Both values are stable per stone, so no edge can crawl.
    local gap = 0.34 + rockNoise(gx, gz, salt + 89) * 0.34
    for _, p in ipairs(poly) do
      local dx, dz = p[1] - cx, p[2] - cz
      local d = math.sqrt(dx * dx + dz * dz)
      local k = d > gap and (d - gap) / d or 0
      p[1], p[2] = cx + dx * k, cz + dz * k
    end
    -- Break the ruler-straight Voronoi edges with one broad inward bite on a
    -- subset of edges. The seed territory and overall crack route do not
    -- move; this only makes the exposed lip look eroded instead of machined.
    local chipped = {}
    for i, p in ipairs(poly) do
      chipped[#chipped + 1] = p
      local q = poly[i % #poly + 1]
      local ex, ez = q[1] - p[1], q[2] - p[2]
      local edgeLength = math.sqrt(ex * ex + ez * ez)
      local chip = rockNoise(gx * 37 + i, gz * 41 - i, salt + 97)
      if edgeLength > 4.5 and chip > 0.42 then
        local along = 0.38
          + rockNoise(gx * 43 + i, gz * 47, salt + 101) * 0.24
        local mx, mz = p[1] + ex * along, p[2] + ez * along
        local ix, iz = cx - mx, cz - mz
        local inward = math.sqrt(ix * ix + iz * iz)
        if inward > 0.001 then
          local bite = 0.22
            + rockNoise(gx * 53 + i, gz * 59 - i, salt + 103) * 0.46
          chipped[#chipped + 1] = {
            mx + ix / inward * bite,
            mz + iz / inward * bite,
          }
        end
      end
    end
    return chipped, sx, sz, cx, cz
  end

  local function caveClipTile(poly, x0, z0, x1, z1)
    poly = caveClip(poly, -1, 0, -x0)
    poly = caveClip(poly,  1, 0,  x1)
    poly = caveClip(poly, 0, -1, -z0)
    return caveClip(poly, 0, 1, z1)
  end

  -- The facet version carries a third component: its already-resolved world
  -- height. Intersections interpolate that value, allowing one full stone
  -- triangle to cross hidden 8px source-tile boundaries without a seam.
  local function caveClipFacet(poly, a, b, c)
    local out = {}
    local n = #poly
    if n == 0 then return out end
    local p = poly[n]
    local pd = a * p[1] + b * p[2] - c
    for i = 1, n do
      local q = poly[i]
      local qd = a * q[1] + b * q[2] - c
      local pin, qin = pd <= 0.0001, qd <= 0.0001
      if pin ~= qin then
        local t = pd / (pd - qd)
        out[#out + 1] = {
          p[1] + (q[1] - p[1]) * t,
          p[2] + (q[2] - p[2]) * t,
          p[3] + (q[3] - p[3]) * t,
        }
      end
      if qin then out[#out + 1] = { q[1], q[2], q[3] } end
      p, pd = q, qd
    end
    return out
  end

  local function caveClipFacetTile(poly, x0, z0, x1, z1)
    poly = caveClipFacet(poly, -1, 0, -x0)
    poly = caveClipFacet(poly,  1, 0,  x1)
    poly = caveClipFacet(poly, 0, -1, -z0)
    return caveClipFacet(poly, 0, 1, z1)
  end

  local function cavePointShade(lit, x, z, x0, z0, tone)
    if type(lit) ~= "table" then return lit * tone end
    local fx = math.max(0, math.min(1, (x - x0) / 8))
    local fz = math.max(0, math.min(1, (z - z0) / 8))
    local north = lit[1] + (lit[2] - lit[1]) * fx
    local south = lit[4] + (lit[3] - lit[4]) * fx
    return (north + (south - north) * fz) * tone
  end

  -- TEST60 keeps TEST59's connected bedrock language but gives the floor a
  -- calmer supporting role. Broader facets cut floor mesh work substantially,
  -- while restrained relief and contrast preserve a natural cave surface.
  local CAVE_GROUND_FACET_CELL = 15

  local function caveSmoothNoise(x, z, salt)
    local scale = 44
    local fx, fz = x / scale, z / scale
    local ix, iz = math.floor(fx), math.floor(fz)
    fx, fz = fx - ix, fz - iz
    fx, fz = fx * fx * (3 - 2 * fx), fz * fz * (3 - 2 * fz)
    local n00 = rockNoise(ix, iz, salt)
    local n10 = rockNoise(ix + 1, iz, salt)
    local n01 = rockNoise(ix, iz + 1, salt)
    local n11 = rockNoise(ix + 1, iz + 1, salt)
    local nx0 = n00 + (n10 - n00) * fx
    local nx1 = n01 + (n11 - n01) * fx
    return nx0 + (nx1 - nx0) * fz
  end

  -- Pokemon Tower wall caps use the 2048px reference granite, the counter top
  -- uses its own calm pearl-quartz sheet while its body keeps the approved
  -- TEST123 dark granite, and ordinary ground owns a 2048px polished floor.
  local function towerGraniteTop(tx, ty, x0, z0, h, shade, tile, material)
    local lit = aoShades(tx, ty, h, shade)
    local tone = material == "counter" and 1.06
      or material == "wall" and 1.18
      -- The 5F healing zone remains readable as a restrained pale-stone
      -- inlay. Sampling its original Cemetery tile made the staged battle
      -- camera expose vivid blue strips between graves and fog banks.
      or material == "healing" and 1.04 or 0.91
    local uvAt = material == "counter" and towerCounterPlanUV
      or material == "wall" and towerGranitePlanUV or towerFloorUV
    local c = { { x0, h, z0 }, { x0 + 8, h, z0 },
                { x0 + 8, h, z0 + 8 }, { x0, h, z0 + 8 } }
    push(c, { uvAt(x0, z0),
              uvAt(x0 + 8, z0),
              uvAt(x0 + 8, z0 + 8),
              uvAt(x0, z0 + 8) },
         { cavePointShade(lit, x0, z0, x0, z0, tone),
           cavePointShade(lit, x0 + 8, z0, x0, z0, tone),
           cavePointShade(lit, x0 + 8, z0 + 8, x0, z0, tone),
           cavePointShade(lit, x0, z0 + 8, x0, z0, tone) })
  end

  -- TEST37 very broad geological ridges. This is evaluated into the cached
  -- top mesh itself: there is no decal, coplanar strip or live-light layer to
  -- shimmer. Two soft ridges occur across roughly every hundred world pixels,
  -- and low-frequency warp keeps them from reading as manufactured grooves.
  local function caveRidgeField(x, z, salt)
    local warp = (caveSmoothNoise(x * 0.63, z * 0.63, salt + 131) - 0.5) * 4.8
    local wave = math.abs(math.sin((x * 0.60 + z * 0.36) / 8.2 + warp))
    local ridge = math.max(0, (wave - 0.61) / 0.39)
    return ridge * ridge
  end

  local function caveFloorField(x, z, salt)
    local macro = caveSmoothNoise(x * 0.94, z * 0.94, salt + 149)
    local ridge = caveRidgeField(x, z, salt)
    local warp = (caveSmoothNoise(x * 0.72, z * 0.69,
                                  salt + 157) - 0.5) * 7.5
    local cragWave = math.abs(math.sin(x / 5.8 - z / 8.7 + warp))
    local crag = math.max(0, (cragWave - 0.58) / 0.42)
    crag = crag * crag
    local splitWave = math.abs(math.sin(x / 6.9 + z / 10.8
      + (caveSmoothNoise(x * 1.11, z * 1.03, salt + 163) - 0.5) * 2.8))
    local fissure = math.max(0, (splitWave - 0.80) / 0.20)
    fissure = fissure * fissure
    return macro, ridge, crag, fissure
  end

  local function caveGroundVertex(gx, gz, h, salt)
    local cell = CAVE_GROUND_FACET_CELL
    local jitter = cell * 0.31
    local x = gx * cell
      + (rockNoise(gx, gz, salt + 11) - 0.5) * jitter
    local z = gz * cell
      + (rockNoise(gx, gz, salt + 21) - 0.5) * jitter
    local macro, ridge, crag, fissure = caveFloorField(x, z, salt)
    return {
      x,
      z,
      h + (macro - 0.5) * 0.60
        + (rockNoise(gx, gz, salt + 27) - 0.5) * 0.30
        + ridge * 0.25 + crag * 0.15 - fissure * 0.12,
    }
  end

  local function caveContinuousSurface(tx, ty, x0, z0, h, shade, kind)
    local x1, z1 = x0 + 8, z0 + 8
    local lit = aoShades(tx, ty, h, shade)
    local donors = CAVE_PATTERN_TILES[kind]
    local salt = kind == "rock" and 907 or kind == "shelf" and 947 or 881
    local cell = CAVE_GROUND_FACET_CELL
    local firstGX = math.floor((x0 - cell * 0.25) / cell) - 1
    local lastGX = math.floor((x1 + cell * 0.25) / cell) + 1
    local firstGZ = math.floor((z0 - cell * 0.25) / cell) - 1
    local lastGZ = math.floor((z1 + cell * 0.25) / cell) + 1

    local function emitFacet(facet, gx, gz, half)
      local poly = caveClipFacetTile(facet, x0, z0, x1, z1)
      if #poly < 3 then return end
      -- One calm material swatch plus broad geological shading. Dark changes
      -- follow valleys and ridges in the actual mesh rather than drawn marks.
      local uv = caveSolidUV(donors[1])
      local facetTone = 0.82
        + rockNoise(gx * 2 + half, gz, salt + 83) * 0.26
      local function point(p) return { p[1], p[3], p[2] } end
      local function pointShade(p)
        local macro, ridge, crag, fissure = caveFloorField(p[1], p[2], salt)
        local tone = facetTone * (0.84 + macro * 0.18
          + ridge * 0.09 + crag * 0.05 - fissure * 0.14)
        tone = math.max(0.62, math.min(1.14, tone))
        return cavePointShade(lit, p[1], p[2], x0, z0, tone)
      end
      if #poly == 4 then
        push({ point(poly[1]), point(poly[2]),
               point(poly[3]), point(poly[4]) },
             { uv, uv, uv, uv },
             { pointShade(poly[1]), pointShade(poly[2]),
               pointShade(poly[3]), pointShade(poly[4]) })
      else
        for i = 2, #poly - 1 do
          local a, b, c = poly[1], poly[i], poly[i + 1]
          push({ point(a), point(b), point(c), point(c) },
               { uv, uv, uv, uv },
               { pointShade(a), pointShade(b),
                 pointShade(c), pointShade(c) })
        end
      end
    end

    for gz = firstGZ, lastGZ do
      for gx = firstGX, lastGX do
        local nw = caveGroundVertex(gx, gz, h, salt)
        local ne = caveGroundVertex(gx + 1, gz, h, salt)
        local se = caveGroundVertex(gx + 1, gz + 1, h, salt)
        local sw = caveGroundVertex(gx, gz + 1, h, salt)
        if rockNoise(gx, gz, salt + 77) < 0.5 then
          emitFacet({ nw, ne, se }, gx, gz, 1)
          emitFacet({ nw, se, sw }, gx, gz, 2)
        else
          emitFacet({ nw, ne, sw }, gx, gz, 1)
          emitFacet({ ne, se, sw }, gx, gz, 2)
        end
      end
    end
  end

  -- TEST62 walkable cave ground is plain granular dirt, not designed rock.
  -- One flat-shaded quad per source tile removes every diagonal lighting
  -- triangle. Three dense, low-contrast grain donors are rotated in world
  -- space for abundant dirt speckles without adding a single geometry piece.
  local function caveDirtTop(tx, ty, x0, z0, h, shade)
    local x1, z1 = x0 + 8, z0 + 8
    local lit = aoShades(tx, ty, h, shade)
    local donors = CAVE_PATTERN_TILES.dirt
    local pick = math.min(#donors, math.floor(
      rockNoise(tx, ty, 1181) * #donors) + 1)
    local u0, u1, v0, v1 = uvRect(donors[pick], 0, 8)
    local uvCorners = {
      { u0, v0 }, { u1, v0 }, { u1, v1 }, { u0, v1 },
    }
    local rotation = math.floor(rockNoise(tx, ty, 1193) * 4)
    local uvs = {}
    for i = 1, 4 do
      uvs[i] = uvCorners[((i + rotation - 1) % 4) + 1]
    end

    -- Average ambient occlusion across the tile so the floor can darken near
    -- walls without producing a diagonal gradient inside either GPU triangle.
    local flat = lit
    if type(lit) == "table" then
      flat = (lit[1] + lit[2] + lit[3] + lit[4]) * 0.25
    end
    -- TEST65 keeps the approved grain exactly intact but stops the cave's
    -- warm light from blowing the path out to bright orange.
    flat = flat * (0.88 + rockNoise(tx, ty, 1201) * 0.04)

    push({ { x0, h, z0 }, { x1, h, z0 },
           { x1, h, z1 }, { x0, h, z1 } },
         uvs, { flat, flat, flat, flat })
  end

  local function caveNaturalTop(tx, ty, x0, z0, h, shade, kind)
    -- TEST64: the bright raised CAVERN `shelf` is also a walkable corridor,
    -- not a rock cap. Route both floor datums through dirt; stair plates and
    -- true wall tops are classified separately and retain their authored art.
    if kind == "dirt" or kind == "shelf" then
      caveDirtTop(tx, ty, x0, z0, h, shade)
    else
      caveContinuousSurface(tx, ty, x0, z0, h, shade, kind)
    end
  end

  -- Shared boundaries for a staggered world-space stone field.  The old
  -- attempt split every eight-pixel tile in half, which simply exchanged
  -- the zig-zag for gold wall panels. These courses are six by four pixels
  -- on average, cross tile edges, and vary their widths deterministically.
  local function rockXBoundary(col, row)
    local stagger = (row % 2 ~= 0) and 3 or 0
    return col * 6 + stagger + (rockNoise(col, row, 1) - 0.5) * 1.15
  end

  local function rockZBoundary(row)
    return row * 4 + (rockNoise(row, 0, 2) - 0.5) * 0.70
  end

  local function ledgeRockTop(tx, ty, x0, z0, h, tile, shade)
    local x1, z1 = x0 + 8, z0 + 8
    local uvDark = rockUV(tile, ROCK_TEXEL.dark)
    local uvShadow = rockUV(tile, ROCK_TEXEL.shadow)
    local uvBody = rockUV(tile, ROCK_TEXEL.body)
    local uvLight = rockUV(tile, ROCK_TEXEL.light)

    -- Recessed stone bed: every gap exposes this instead of the old art.
    topSolid({ { x0, h, z0 }, { x1, h, z0 },
                { x1, h, z1 }, { x0, h, z1 } },
              uvDark, shade, 0.82, x0, z0)

    local gap = 0.16
    local firstRow = math.floor((z0 - 5) / 4) - 1
    local lastRow = math.ceil((z1 + 5) / 4) + 1
    for row = firstRow, lastRow do
      local zs, ze = rockZBoundary(row), rockZBoundary(row + 1)
      if ze > z0 and zs < z1 then
        local stagger = (row % 2 ~= 0) and 3 or 0
        local firstCol = math.floor((x0 - stagger - 8) / 6) - 1
        local lastCol = math.ceil((x1 - stagger + 8) / 6) + 1
        for col = firstCol, lastCol do
          local xs = rockXBoundary(col, row)
          local xe = rockXBoundary(col + 1, row)
          if xe > x0 and xs < x1 then
            -- Gaps belong to real stone boundaries, never to the invisible
            -- 8px clipping boundary: one rock crossing two tiles stays one.
            local sx = math.max(x0, xs + gap)
            local ex = math.min(x1, xe - gap)
            local sz = math.max(z0, zs + gap)
            local ez = math.min(z1, ze - gap)
            if ex > sx and ez > sz then
              local variation = rockNoise(col, row, 3)
              local uv = variation > 0.82 and uvLight
                         or variation < 0.16 and uvShadow or uvBody
              local tone = 0.91 + rockNoise(col, row, 4) * 0.13
              topSolid({ { sx, h + 0.12, sz }, { ex, h + 0.12, sz },
                          { ex, h + 0.12, ez }, { sx, h + 0.12, ez } },
                        uv, shade, tone, x0, z0)
            end
          end
        end
      end
    end
  end

  local function pathExtent(tx, ty, dx, dy)
    local n = 0
    for i = 1, 8 do
      if not isKantoPathAt(tx + dx * i, ty + dy * i) then break end
      n = n + 1
    end
    return n
  end

  -- Full-tile orientations break the source repeat while retaining one flat
  -- quad. The subdued atlas marks are embedded grain, never raised objects.
  local function pavedUV(tile, variant)
    local u0, u1, v0, v1 = uvRect(tile, 0, 8)
    if variant == 1 then
      return { { u1, v0 }, { u0, v0 }, { u0, v1 }, { u1, v1 } }
    elseif variant == 2 then
      return { { u0, v1 }, { u1, v1 }, { u1, v0 }, { u0, v0 } }
    elseif variant == 3 then
      return { { u1, v1 }, { u0, v1 }, { u0, v0 }, { u1, v0 } }
    end
    return { { u0, v0 }, { u1, v0 }, { u1, v1 }, { u0, v1 } }
  end

  local function smoothPathNoise(x, z, salt)
    local scale = 32
    local gx, gz = x / scale, z / scale
    local ix, iz = math.floor(gx), math.floor(gz)
    local fx, fz = gx - ix, gz - iz
    fx, fz = fx * fx * (3 - 2 * fx), fz * fz * (3 - 2 * fz)
    local n00 = rockNoise(ix, iz, salt)
    local n10 = rockNoise(ix + 1, iz, salt)
    local n01 = rockNoise(ix, iz + 1, salt)
    local n11 = rockNoise(ix + 1, iz + 1, salt)
    local nx0, nx1 = n00 + (n10 - n00) * fx,
                           n01 + (n11 - n01) * fx
    return nx0 + (nx1 - nx0) * fz
  end

  local function pavedShades(tx, ty, x0, z0, shade)
    local west, east = pathExtent(tx, ty, -1, 0), pathExtent(tx, ty, 1, 0)
    local north, south = pathExtent(tx, ty, 0, -1), pathExtent(tx, ty, 0, 1)
    local horizontal, vertical = west + east, north + south
    local travelAxis, travelCenter, travelHalf
    if vertical >= horizontal + 2 then
      local edge0, edge1 = x0 - west * 8, x0 + (east + 1) * 8
      travelAxis, travelCenter = 1, (edge0 + edge1) * 0.5
      travelHalf = math.max(1, (edge1 - edge0) * 0.5)
    elseif horizontal >= vertical + 2 then
      local edge0, edge1 = z0 - north * 8, z0 + (south + 1) * 8
      travelAxis, travelCenter = 2, (edge0 + edge1) * 0.5
      travelHalf = math.max(1, (edge1 - edge0) * 0.5)
    end

    local nw = (west == 0 or north == 0) and 1.015 or 1
    local ne = (east == 0 or north == 0) and 1.015 or 1
    local se = (east == 0 or south == 0) and 1.015 or 1
    local sw = (west == 0 or south == 0) and 1.015 or 1
    local corners = {
      { x0, z0, nw }, { x0 + 8, z0, ne },
      { x0 + 8, z0 + 8, se }, { x0, z0 + 8, sw },
    }
    local out = {}
    for i, corner in ipairs(corners) do
      local base = type(shade) == "table" and shade[i] or shade
      local terrainTone = 0.97 + smoothPathNoise(corner[1], corner[2], 422) * 0.06
      local travelTone = 1
      if travelAxis then
        travelTone = 0.95 + math.min(1,
          math.abs(corner[travelAxis] - travelCenter) / travelHalf) * 0.05
      end
      out[i] = base * terrainTone * travelTone * corner[3]
    end
    return out
  end

  -- TEST422 ordinary roads are exactly one flat quad. Fine atlas grain and
  -- continuous world-space corner shading provide depth without seams,
  -- bricks, cracks, floating marks, or additional collision geometry.
  local function kantoPavedTop(tx, ty, x0, z0, h, shade)
    local x1, z1 = x0 + 8, z0 + 8
    local variant = math.floor(rockNoise(tx, ty, 422) * 4)
    push({ { x0, h, z0 }, { x1, h, z0 },
           { x1, h, z1 }, { x0, h, z1 } },
         pavedUV(KANTO_PATH_SWATCH_TILE, variant),
         pavedShades(tx, ty, x0, z0, shade))
  end

  -- TEST430's house court uses broad, quiet limestone flags rather than a
  -- second dirt road or another field of brick-sized marks. Slab boundaries
  -- live in world space and cross the source 8px tile grid; the tiny recessed
  -- bed supplies hairline joints while collision remains the original plane.
  local function courtyardXBoundary(col, row)
    local stagger = (row % 2 ~= 0) and 8.5 or 0
    return col * 17 + stagger
           + (rockNoise(col, row, 430) - 0.5) * 1.0
  end

  local function courtyardZBoundary(row)
    return row * 12 + (rockNoise(row, 0, 431) - 0.5) * 0.7
  end

  local function kantoCourtyardTop(tx, ty, x0, z0, h, shade)
    local x1, z1 = x0 + 8, z0 + 8
    local uvJoint = rockUV(KANTO_PATH_SWATCH_TILE, ROCK_TEXEL.dark)
    local uvShadow = rockUV(KANTO_PATH_SWATCH_TILE, ROCK_TEXEL.shadow)
    local uvBody = rockUV(KANTO_PATH_SWATCH_TILE, ROCK_TEXEL.body)
    local uvLight = rockUV(KANTO_PATH_SWATCH_TILE, ROCK_TEXEL.light)
    topSolid({ { x0, h, z0 }, { x1, h, z0 },
                { x1, h, z1 }, { x0, h, z1 } },
              uvJoint, shade, 0.965, x0, z0)

    local gap = 0.10
    local firstRow = math.floor((z0 - 13) / 12) - 1
    local lastRow = math.ceil((z1 + 13) / 12) + 1
    for row = firstRow, lastRow do
      local zs, ze = courtyardZBoundary(row), courtyardZBoundary(row + 1)
      if ze > z0 and zs < z1 then
        local stagger = (row % 2 ~= 0) and 8.5 or 0
        local firstCol = math.floor((x0 - stagger - 18) / 17) - 1
        local lastCol = math.ceil((x1 - stagger + 18) / 17) + 1
        for col = firstCol, lastCol do
          local xs = courtyardXBoundary(col, row)
          local xe = courtyardXBoundary(col + 1, row)
          if xe > x0 and xs < x1 then
            local sx, ex = math.max(x0, xs + gap), math.min(x1, xe - gap)
            local sz, ez = math.max(z0, zs + gap), math.min(z1, ze - gap)
            if ex > sx and ez > sz then
              local variation = rockNoise(col, row, 432)
              local uv = variation > 0.84 and uvLight
                         or variation < 0.13 and uvShadow or uvBody
              local tone = 0.985 + rockNoise(col, row, 433) * 0.03
              topSolid({ { sx, h + 0.025, sz }, { ex, h + 0.025, sz },
                          { ex, h + 0.025, ez }, { sx, h + 0.025, ez } },
                        uv, shade, tone, x0, z0)
            end
          end
        end
      end
    end
  end

  local function grassShades(x0, z0, shade)
    local corners = {
      { x0, z0 }, { x0 + 8, z0 },
      { x0 + 8, z0 + 8 }, { x0, z0 + 8 },
    }
    local out = {}
    for i, corner in ipairs(corners) do
      local base = type(shade) == "table" and shade[i] or shade
      local worldTone = 0.96 + smoothPathNoise(corner[1], corner[2], 425) * 0.08
      out[i] = base * worldTone
    end
    return out
  end

  -- TEST425 plain turf remains one flat cached terrain quad. Deterministic
  -- UV rotation breaks the old maze repeat; slow world-coordinate shading
  -- supplies broad natural variation without touching tall grass or flora.
  local function kantoGrassTop(tx, ty, x0, z0, h, shade)
    local x1, z1 = x0 + 8, z0 + 8
    local variant = math.floor(rockNoise(tx, ty, 425) * 4)
    push({ { x0, h, z0 }, { x1, h, z0 },
           { x1, h, z1 }, { x0, h, z1 } },
         pavedUV(KANTO_GRASS_TILE, variant),
         grassShades(x0, z0, shade))
  end

  local function lavenderPathTile(tile)
    return KANTO_PATH_TILE[tile] == true
  end


  function LG.cliffGroundFinishAt(tx, ty)
    if tileset.id ~= "OVERWORLD" or (LG.cityGroundMap and not LG.legendaryCityGround) then return nil end
    local finish = ChunkMesher.cliffGroundFinish(function(x,y)
      return map:tileAt(x,y)
    end, tx, ty)
    if finish == "grass" and CommunityVisuals.customGrass() then return finish end
    if finish == "path" and CommunityVisuals.customRoads() then return finish end
  end

  function LG.isLavenderGroundTile(tile)
    return tile == 48 or tile == KANTO_GRASS_TILE or KANTO_PATH_TILE[tile] == true
  end

  -- PLAZA1: only Lavender's paired 48/57 town ground becomes paving.
  -- A map-edge lawn band and all ordinary turf remain green.
  function LG.lavenderPlazaAt(tx, ty)
    if tx < 4 or ty < 4 or tx >= tw - 4 or ty >= th - 4 then return false end
    local k = keyOf(tx, ty)
    local t = S.tileAt[k]
    if t == 48 or t == 57 then return true end
    -- PLAZA2: extracted signs keep their source sign tiles, even when
    -- their synthesized ground is turf. Resolve the entire 2x2 footprint
    -- together so paving and edging remain continuous beneath the post.
    local shape = S.shapeAt[k]
    if not (S.skip[k] and shape and shape.class == "signpost") then return false end
    local sx, sy = math.floor(tx / 2) * 2, math.floor(ty / 2) * 2
    for y = sy - 1, sy + 2 do
      for x = sx - 1, sx + 2 do
        if x < sx or x > sx + 1 or y < sy or y > sy + 1 then
          local neighbor = S.tileAt[keyOf(x, y)]
          if x >= 4 and y >= 4 and x < tw - 4 and y < th - 4
              and (neighbor == 48 or neighbor == 57) then return true end
        end
      end
    end
    return false
  end

  function LG.lavenderPlazaTop(tx, ty, x0, z0, h, shade)
    local uvJoint = rockUV(48, ROCK_TEXEL.dark)
    local uvBody = rockUV(48, ROCK_TEXEL.body)
    local uvTrim = rockUV(48, ROCK_TEXEL.shadow)
    local function rect(ax, az, bx, bz, y, uv, tone)
      if bx <= ax or bz <= az then return end
      local corners={{ax,y,az},{bx,y,az},{bx,y,bz},{ax,y,bz}}
      local lit=shadeRect(corners,shade,1,x0,x0+8,3,z0,z0+8,tone)
      if type(lit) ~= "table" then lit={lit,lit,lit,lit} end
      for i,c in ipairs(corners) do
        lit[i]=lit[i]*(.97+smoothPathNoise(c[1],c[3],1209)*.06)
      end
      pushSolid(corners,uv,lit)
    end
    -- Recessed seam bed, with flush narrow edging where paving ends.
    rect(x0,z0,x0+8,z0+8,h,uvJoint,1)
    local west = not LG.lavenderPlazaAt(tx-1,ty) and 0.85 or 0
    local east = not LG.lavenderPlazaAt(tx+1,ty) and 0.85 or 0
    local north = not LG.lavenderPlazaAt(tx,ty-1) and 0.85 or 0
    local south = not LG.lavenderPlazaAt(tx,ty+1) and 0.85 or 0
    rect(x0,z0,x0+west,z0+8,h+0.025,uvTrim,1.10)
    rect(x0+8-east,z0,x0+8,z0+8,h+0.025,uvTrim,1.10)
    rect(x0+west,z0,x0+8-east,z0+north,h+0.025,uvTrim,1.10)
    rect(x0+west,z0+8-south,x0+8-east,z0+8,h+0.025,uvTrim,1.10)
    -- 24 x 16 world-unit flags: seams span the source tiles, alternate
    -- rows offset by half a flag. No extra collision or runtime objects.
    for row=math.floor(z0/16),math.floor((z0+7.999)/16) do
      local offset=(row%2)*12
      for col=math.floor((x0-offset)/24),math.floor((x0+7.999-offset)/24) do
        local xs, zs=col*24+offset,row*16
        local tone=0.965+rockNoise(col,row,1201)*0.07
        rect(math.max(x0+west,xs+0.10),math.max(z0+north,zs+0.10),
             math.min(x0+8-east,xs+23.90),math.min(z0+8-south,zs+15.90),
             h+0.025,uvBody,tone)
      end
    end
  end

  function LG.legendaryLavenderTop(tx, ty, x0, z0, h, shade, tile)
    -- Inferred prop/structure ground must use the local finish. Only
    -- a real source road may request the tan road material here.
    if LG.lavenderPlazaAt(tx, ty) then
      LG.lavenderPlazaTop(tx, ty, x0, z0, h, shade)
    elseif tile == 35 and map:tileAt(tx, ty) == 35 then
      kantoPavedTop(tx, ty, x0, z0, h, shade)
    else
      kantoGrassTop(tx, ty, x0, z0, h, shade)
    end
  end

  local function woodRect(axis, across0, across1, along0, along1, y)
    if axis == "z" then
      return { { across0, y, along0 }, { across1, y, along0 },
               { across1, y, along1 }, { across0, y, along1 } }
    end
    return { { along0, y, across0 }, { along1, y, across0 },
             { along1, y, across1 }, { along0, y, across1 } }
  end

  -- Warm crosswise timber boards for authored bridge/deck tile $3C.  The
  -- connected deck's long axis selects board orientation, while staggered
  -- world-space end joints and sparse grain strokes remove the old orange
  -- eight-pixel repeat without turning the bridge into a high-frequency mat.
  local function kantoWoodTop(tx, ty, x0, z0, h, shade, axisOverride)
    local axis = axisOverride
                 or ChunkMesher.kantoWoodAxis(isKantoWoodAt, tx, ty)
    local across0, across1 = x0, x0 + 8
    local along0, along1 = z0, z0 + 8
    if axis == "x" then
      across0, across1, along0, along1 = z0, z0 + 8, x0, x0 + 8
    end
    local uvDark = rockUV(KANTO_WOOD_TILE, ROCK_TEXEL.dark)
    local uvShadow = rockUV(KANTO_WOOD_TILE, ROCK_TEXEL.shadow)
    local uvBody = rockUV(KANTO_WOOD_TILE, ROCK_TEXEL.body)
    local uvLight = rockUV(KANTO_WOOD_TILE, ROCK_TEXEL.light)

    topSolid(woodRect(axis, across0, across1, along0, along1, h),
              uvDark, shade, 0.92, x0, z0)

    local boardDepth, boardLength, gap, salt = 3.2, 13.0, 0.11, 220
    local firstRow = math.floor((along0 - boardDepth) / boardDepth) - 1
    local lastRow = math.ceil((along1 + boardDepth) / boardDepth) + 1
    for row = firstRow, lastRow do
      local a0 = row * boardDepth
                 + (rockNoise(row, 0, salt) - 0.5) * 0.18
      local a1 = (row + 1) * boardDepth
                 + (rockNoise(row + 1, 0, salt) - 0.5) * 0.18
      if a1 > along0 and a0 < along1 then
        local stagger = (row % 2 ~= 0) and boardLength * 0.5 or 0
        local firstCol = math.floor((across0 - stagger - boardLength)
                                    / boardLength) - 1
        local lastCol = math.ceil((across1 - stagger + boardLength)
                                  / boardLength) + 1
        for col = firstCol, lastCol do
          local c0 = col * boardLength + stagger
                     + (rockNoise(col, row, salt + 1) - 0.5) * 0.34
          local c1 = (col + 1) * boardLength + stagger
                     + (rockNoise(col + 1, row, salt + 1) - 0.5) * 0.34
          if c1 > across0 and c0 < across1 then
            local sc, ec = math.max(across0, c0 + gap),
                           math.min(across1, c1 - gap)
            local sa, ea = math.max(along0, a0 + gap),
                           math.min(along1, a1 - gap)
            if ec > sc and ea > sa then
              local variation = rockNoise(col, row, salt + 2)
              local uv = variation > 0.88 and uvLight
                         or variation < 0.12 and uvShadow or uvBody
              local tone = 0.94 + rockNoise(col, row, salt + 3) * 0.11
              topSolid(woodRect(axis, sc, ec, sa, ea, h + 0.06),
                        uv, shade, tone, x0, z0)

              if ec - sc > 2.6 and rockNoise(col, row, salt + 4) > 0.48 then
                local grainA = sa + (ea - sa) * 0.68
                local grainC0, grainC1 = sc + 0.65, ec - 0.65
                if grainC1 > grainC0 then
                  topSolid(woodRect(axis, grainC0, grainC1,
                                     grainA, math.min(ea, grainA + 0.055),
                                     h + 0.065),
                            uvShadow, shade, tone * 0.94, x0, z0)
                end
              end
            end
          end
        end
      end
    end
  end

  local function faceAxisPoint(d, x0, z0, axis, y, out)
    if d == 5 then return { axis, y, z0 + 8 + out } end  -- south
    if d == 6 then return { axis, y, z0 - out } end      -- north
    if d == 1 then return { x0 + 8 + out, y, axis } end  -- east
    return { x0 - out, y, axis }                         -- west
  end

  local function ledgeRockSide(d, tx, ty, x0, z0, y0, y1,
                               tile, shade)
    tile = RETAINING_SWATCH_TILE
    local uvDark = rockUV(tile, ROCK_TEXEL.dark)
    local uvShadow = rockUV(tile, ROCK_TEXEL.shadow)
    local uvBody = rockUV(tile, ROCK_TEXEL.body)
    local uvLight = rockUV(tile, ROCK_TEXEL.light)
    local axis0 = (d == 5 or d == 6) and x0 or z0
    local axis1 = axis0 + 8

    sideSolid({ faceAxisPoint(d, x0, z0, axis0, y0, 0),
                faceAxisPoint(d, x0, z0, axis1, y0, 0),
                faceAxisPoint(d, x0, z0, axis1, y1, 0),
                faceAxisPoint(d, x0, z0, axis0, y1, 0) },
              uvDark, shade, 0.76, d, x0, z0, y0, y1)

    local rows = 2
    local rowH = (y1 - y0) / rows
    local gap = 0.16
    local depth = 0.30
    for row = 0, rows - 1 do
      local ys = y0 + row * rowH
      local ye = y0 + (row + 1) * rowH
      local offset = (row % 2 ~= 0) and 3 or 0
      local firstCol = math.floor((axis0 - offset - 8) / 6) - 1
      local lastCol = math.ceil((axis1 - offset + 8) / 6) + 1
      for col = firstCol, lastCol do
        -- Direction joins the seed only for colour; physical boundaries
        -- stay shared between opposite sides and around corners.
        local xs = col * 6 + offset
                   + (rockNoise(col, row, 10) - 0.5) * 1.15
        local xe = (col + 1) * 6 + offset
                   + (rockNoise(col + 1, row, 10) - 0.5) * 1.15
        if xe > axis0 and xs < axis1 then
          local sx = math.max(axis0, xs + gap)
          local ex = math.min(axis1, xe - gap)
          local sy = ys + gap
          local ey = ye - gap
          if ex > sx and ey > sy then
            local bbl = faceAxisPoint(d, x0, z0, sx, sy, 0)
            local bbr = faceAxisPoint(d, x0, z0, ex, sy, 0)
            local btr = faceAxisPoint(d, x0, z0, ex, ey, 0)
            local btl = faceAxisPoint(d, x0, z0, sx, ey, 0)
            local fbl = faceAxisPoint(d, x0, z0, sx, sy, depth)
            local fbr = faceAxisPoint(d, x0, z0, ex, sy, depth)
            local ftr = faceAxisPoint(d, x0, z0, ex, ey, depth)
            local ftl = faceAxisPoint(d, x0, z0, sx, ey, depth)
            local variation = rockNoise(col, row, 20 + d)
            local uv = variation > 0.82 and uvLight
                       or variation < 0.16 and uvShadow or uvBody
            local tone = 0.91 + rockNoise(col, row, 30 + d) * 0.12

            sideSolid({ fbl, fbr, ftr, ftl }, uv,
                      shade, tone, d, x0, z0, y0, y1)
            sideSolid({ btl, btr, ftr, ftl }, uvLight,
                      shade, 0.96, d, x0, z0, y0, y1)
            sideSolid({ bbr, bbl, fbl, fbr }, uvShadow,
                      shade, 0.82, d, x0, z0, y0, y1)

            -- Do not bevel an artificial tile clip: when the same stone
            -- continues into the neighbour, both pieces meet seamlessly.
            if xs + gap >= axis0 - 0.001 then
              sideSolid({ bbl, btl, ftl, fbl }, uvShadow,
                        shade, 0.86, d, x0, z0, y0, y1)
            end
            if xe - gap <= axis1 + 0.001 then
              sideSolid({ btr, bbr, fbr, ftr }, uvBody,
                        shade, 0.88, d, x0, z0, y0, y1)
            end
          end
        end
      end
    end
  end

  -- A taller companion to TEST402's six-pixel ledge face.  Courses are
  -- locked to world Y, so a 16/32px wall receives four/eight continuous
  -- courses even though the ordinary mesher visits its side in 8px bands.
  -- Horizontal joints use the same six-pixel rhythm as the accepted ledges,
  -- but a different stable noise salt keeps the wall from looking stamped.
  local function retainingRockSide(d, x0, z0, y0, y1, shade, tileOverride)
    local tile = tileOverride or RETAINING_SWATCH_TILE
    local uvDark = rockUV(tile, ROCK_TEXEL.dark)
    local uvShadow = rockUV(tile, ROCK_TEXEL.shadow)
    local uvBody = rockUV(tile, ROCK_TEXEL.body)
    local uvLight = rockUV(tile, ROCK_TEXEL.light)
    local axis0 = (d == 5 or d == 6) and x0 or z0
    local axis1 = axis0 + 8

    sideSolid({ faceAxisPoint(d, x0, z0, axis0, y0, 0),
                faceAxisPoint(d, x0, z0, axis1, y0, 0),
                faceAxisPoint(d, x0, z0, axis1, y1, 0),
                faceAxisPoint(d, x0, z0, axis0, y1, 0) },
              uvDark, shade, 0.74, d, x0, z0, y0, y1)

    local courseH = 4
    local gap = 0.16
    local depth = 0.28
    local firstRow = math.floor(y0 / courseH)
    local lastRow = math.ceil(y1 / courseH) - 1
    for row = firstRow, lastRow do
      local ys = math.max(y0, row * courseH)
      local ye = math.min(y1, (row + 1) * courseH)
      local offset = (row % 2 ~= 0) and 3 or 0
      local firstCol = math.floor((axis0 - offset - 8) / 6) - 1
      local lastCol = math.ceil((axis1 - offset + 8) / 6) + 1
      for col = firstCol, lastCol do
        -- TEST38 lets only the cave masonry wander farther from the ruler.
        -- The same world-space boundary sample is shared by both neighbours,
        -- so irregular widths never open a crack at a hidden source-tile cut.
        local boundaryJitter = tileOverride and 1.85 or 1.05
        local xs = col * 6 + offset
                   + (rockNoise(col, row, 41) - 0.5) * boundaryJitter
        local xe = (col + 1) * 6 + offset
                   + (rockNoise(col + 1, row, 41) - 0.5) * boundaryJitter
        if xe > axis0 and xs < axis1 then
          local sx = math.max(axis0, xs + gap)
          local ex = math.min(axis1, xe - gap)
          local sy = ys + gap
          local ey = ye - gap
          if ex > sx and ey > sy then
            -- Each cave brick has four independently weathered corners.
            -- The insets stay inside the original cell, leaving chipped,
            -- crooked silhouettes against the single dark backing face. At
            -- artificial 8px clips the inset is zero, allowing a stone to
            -- continue seamlessly into the neighbouring cached tile.
            local sxBottom, sxTop, exBottom, exTop = sx, sx, ex, ex
            local syLeft, syRight, eyLeft, eyRight = sy, sy, ey, ey
            local leftEdge, rightEdge = true, true
            if tileOverride then
              local spanX = ex - sx
              local spanY = ey - sy
              local xInset = math.min(0.30, spanX * 0.30)
              local yInset = math.min(0.27, spanY * 0.30)
              leftEdge = xs + gap >= axis0 - 0.001
              rightEdge = xe - gap <= axis1 + 0.001
              if leftEdge then
                sxBottom = sx + rockNoise(col, row, 70 + d) * xInset
                sxTop = sx + rockNoise(col, row, 71 + d) * xInset
              end
              if rightEdge then
                exBottom = ex - rockNoise(col, row, 72 + d) * xInset
                exTop = ex - rockNoise(col, row, 73 + d) * xInset
              end
              -- A brick split only for caching must meet itself exactly at
              -- that invisible cut. Fully contained bricks receive the full
              -- crooked upper/lower silhouette; clipped bricks keep their
              -- irregular natural end but share straight cut coordinates.
              if leftEdge and rightEdge then
                syLeft = sy + rockNoise(col, row, 74 + d) * yInset
                syRight = sy + rockNoise(col, row, 75 + d) * yInset
                eyLeft = ey - rockNoise(col, row, 76 + d) * yInset
                eyRight = ey - rockNoise(col, row, 77 + d) * yInset
              end
            end

            local bbl = faceAxisPoint(d, x0, z0, sxBottom, syLeft, 0)
            local bbr = faceAxisPoint(d, x0, z0, exBottom, syRight, 0)
            local btr = faceAxisPoint(d, x0, z0, exTop, eyRight, 0)
            local btl = faceAxisPoint(d, x0, z0, sxTop, eyLeft, 0)
            -- TEST38 keeps TEST37's recessed-to-proud relief, then adds stable
            -- corner wear. A minority of stones are deeply eroded or pushed
            -- forward, breaking the new tall walls into an ancient cave ruin
            -- without decals, extra overlays or live-light-dependent detail.
            -- Outdoor retaining masonry keeps its exact TEST36 geometry.
            local brickDepth = depth
            local brickTilt = 0
            local wear = 0.5
            if tileOverride then
              wear = rockNoise(col, row, 68 + d)
              brickDepth = 0.15 + rockNoise(col, row, 66 + d) * 0.46
              if wear > 0.84 then
                brickDepth = 0.09 + rockNoise(col, row, 69 + d) * 0.15
              elseif wear < 0.10 then
                brickDepth = 0.52 + rockNoise(col, row, 69 + d) * 0.12
              end
              if leftEdge and rightEdge then
                brickTilt = (rockNoise(col, row, 67 + d) - 0.5) * 0.10
              end
            end
            local function batteredDepth(salt, sideTilt)
              local cornerWear = tileOverride and leftEdge and rightEdge
                and (rockNoise(col, row, salt + d) - 0.5) * 0.14 or 0
              return math.max(0.08, math.min(0.68,
                                            brickDepth + sideTilt + cornerWear))
            end
            local depthBL = batteredDepth(78, -brickTilt)
            local depthBR = batteredDepth(79, brickTilt)
            local depthTR = batteredDepth(80, brickTilt)
            local depthTL = batteredDepth(81, -brickTilt)
            local fbl = faceAxisPoint(d, x0, z0, sxBottom, syLeft, depthBL)
            local fbr = faceAxisPoint(d, x0, z0, exBottom, syRight, depthBR)
            local ftr = faceAxisPoint(d, x0, z0, exTop, eyRight, depthTR)
            local ftl = faceAxisPoint(d, x0, z0, sxTop, eyLeft, depthTL)
            local variation = rockNoise(col, row, 50 + d)
            local uv = wear > 0.84 and uvShadow
                       or variation > 0.86 and uvLight
                       or variation < 0.13 and uvShadow or uvBody
            local tone = 0.87 + rockNoise(col, row, 60 + d) * 0.15

            sideSolid({ fbl, fbr, ftr, ftl }, uv,
                      shade, tone, d, x0, z0, y0, y1)
            sideSolid({ btl, btr, ftr, ftl }, uvLight,
                      shade, 0.94, d, x0, z0, y0, y1)
            sideSolid({ bbr, bbl, fbl, fbr }, uvShadow,
                      shade, 0.80, d, x0, z0, y0, y1)

            -- A stone clipped only by the hidden 8px source-tile boundary
            -- resumes in the neighbour without receiving a fake end bevel.
            if xs + gap >= axis0 - 0.001 then
              sideSolid({ bbl, btl, ftl, fbl }, uvShadow,
                        shade, 0.84, d, x0, z0, y0, y1)
            end
            if xe - gap <= axis1 + 0.001 then
              sideSolid({ btr, bbr, fbr, ftr }, uvBody,
                        shade, 0.87, d, x0, z0, y0, y1)
            end
          end
        end
      end
    end
  end

  -- TEST124 Pokemon Tower. The wall is continuous reference-matched granite,
  -- not masonry or horizontal banding: irregular diagonal smoky slabs sit
  -- behind tall pale monolithic ribs. Fronts remain coplanar and receive a
  -- gentle value lift toward the open ceiling rather than a repeated baked
  -- white strip in the texture.
  local function towerGraniteSide(d, x0, z0, y0, y1, shade)
    local axis0 = (d == 5 or d == 6) and x0 or z0
    local axis1 = axis0 + 8
    local uvDark = rockUV(TOWER_GRANITE_SWATCH_TILE, ROCK_TEXEL.dark)
    local uvShadow = rockUV(TOWER_GRANITE_SWATCH_TILE, ROCK_TEXEL.shadow)
    local uvBody = rockUV(TOWER_GRANITE_SWATCH_TILE, ROCK_TEXEL.body)
    local uvLight = rockUV(TOWER_GRANITE_SWATCH_TILE, ROCK_TEXEL.light)

    -- Dark stone behind the relief prevents cracks from revealing the void.
    sideSolid({ faceAxisPoint(d, x0, z0, axis0, y0, -0.18),
                faceAxisPoint(d, x0, z0, axis1, y0, -0.18),
                faceAxisPoint(d, x0, z0, axis1, y1, -0.18),
                faceAxisPoint(d, x0, z0, axis0, y1, -0.18) },
              uvShadow, shade, 0.78, d, x0, z0, y0, y1)

    local function upperWallLift(y)
      local t = math.max(0, math.min(1, (y - 36) / 28))
      t = t * t * (3 - 2 * t)
      return 1 + t * 0.30
    end

    local function shadeAt(axis, y, tone)
      local lift = upperWallLift(y)
      if type(shade) ~= "table" then return shade * tone * lift end
      local fx = math.max(0, math.min(1, (axis - axis0) / 8))
      local fy = math.max(0, math.min(1,
        (y - y0) / math.max(0.001, y1 - y0)))
      local bottom = shade[1] + (shade[2] - shade[1]) * fx
      local top = shade[4] + (shade[3] - shade[4]) * fx
      return (bottom + (top - bottom) * fy) * tone * lift
    end

    local function texturedFront(sx, ex, sy, ey, depth, _, baseTone)
      local fbl = faceAxisPoint(d, x0, z0, sx, sy, depth)
      local fbr = faceAxisPoint(d, x0, z0, ex, sy, depth)
      local ftr = faceAxisPoint(d, x0, z0, ex, ey, depth)
      local ftl = faceAxisPoint(d, x0, z0, sx, ey, depth)
      push({ fbl, fbr, ftr, ftl },
           { towerGraniteWallUV(sx, sy), towerGraniteWallUV(ex, sy),
             towerGraniteWallUV(ex, ey), towerGraniteWallUV(sx, ey) },
           { shadeAt(sx, sy, baseTone), shadeAt(ex, sy, baseTone),
             shadeAt(ex, ey, baseTone), shadeAt(sx, ey, baseTone) })
    end

    -- One uninterrupted material panel per authored wall face.  No internal
    -- edges, colour squares, relief noise, or changing normals remain.
    texturedFront(axis0, axis1, y0, y1, 0.24, nil, 0.88)

    local function projectedPanel(ax0, ax1, ay0, ay1,
                                  depth, back, uv, tone)
      local sx, ex = math.max(axis0, ax0), math.min(axis1, ax1)
      local sy, ey = math.max(y0, ay0), math.min(y1, ay1)
      if ex <= sx or ey <= sy then return end
      local bbl = faceAxisPoint(d, x0, z0, sx, sy, back)
      local bbr = faceAxisPoint(d, x0, z0, ex, sy, back)
      local btr = faceAxisPoint(d, x0, z0, ex, ey, back)
      local btl = faceAxisPoint(d, x0, z0, sx, ey, back)
      local fbl = faceAxisPoint(d, x0, z0, sx, sy, depth)
      local fbr = faceAxisPoint(d, x0, z0, ex, sy, depth)
      local ftr = faceAxisPoint(d, x0, z0, ex, ey, depth)
      local ftl = faceAxisPoint(d, x0, z0, sx, ey, depth)
      texturedFront(sx, ex, sy, ey, depth, uv, tone, 151)
      sideSolid({ btl, btr, ftr, ftl }, uvLight, shade, tone * 0.95,
                d, x0, z0, y0, y1)
      sideSolid({ bbr, bbl, fbl, fbr }, uvShadow, shade, tone * 0.82,
                d, x0, z0, y0, y1)
    end

    -- Low plinth and pale crown are the same stone family, separated through
    -- restrained value and depth rather than a manufactured panel texture.
    projectedPanel(axis0, axis1, 0.0, 2.0, 0.92, 0.46,
                   uvShadow, 1.00)
    projectedPanel(axis0, axis1, 61.4, 64.0, 1.12, 0.46,
                   uvLight, 1.16)

    -- Tall rectangular stone ribs. In the reference they are pale but still
    -- part of the wall, so their projection and value contrast stay modest.
    local spacing, half = 32, 3.25
    local first = math.ceil((axis0 - half - 0.8) / spacing)
    local last = math.floor((axis1 + half + 0.8) / spacing)
    for i = first, last do
      local center = i * spacing
      local rawS, rawE = center - half, center + half
      local sx, ex = math.max(axis0, rawS), math.min(axis1, rawE)
      if ex > sx then
        -- Rib rear remains beyond the wall's maximum 0.34 relief, preventing
        -- z-fighting while preserving the flatter silhouette of the source.
        local back, depth = 0.46, 1.48
        local bbl = faceAxisPoint(d, x0, z0, sx, y0, back)
        local bbr = faceAxisPoint(d, x0, z0, ex, y0, back)
        local btr = faceAxisPoint(d, x0, z0, ex, y1, back)
        local btl = faceAxisPoint(d, x0, z0, sx, y1, back)
        local fbl = faceAxisPoint(d, x0, z0, sx, y0, depth)
        local fbr = faceAxisPoint(d, x0, z0, ex, y0, depth)
        local ftr = faceAxisPoint(d, x0, z0, ex, y1, depth)
        local ftl = faceAxisPoint(d, x0, z0, sx, y1, depth)
        texturedFront(sx, ex, y0, y1, depth, uvLight, 1.20)
        if rawS >= axis0 - 0.001 then
          sideSolid({ bbl, btl, ftl, fbl }, uvShadow, shade, 0.87,
                    d, x0, z0, y0, y1)
        end
        if rawE <= axis1 + 0.001 then
          sideSolid({ btr, bbr, fbr, ftr }, uvBody, shade, 0.88,
                    d, x0, z0, y0, y1)
        end
      end

      projectedPanel(center - half - 0.75, center + half + 0.75,
                     0.0, 4.3, 1.78, 0.46, uvBody, 1.22)
      projectedPanel(center - half - 0.85, center + half + 0.85,
                     58.7, 64.0, 1.88, 0.46, uvLight, 1.23)
    end
  end

  -- The reception counter uses the same real slab material as the room. A
  -- recessed body and projecting polished upper band stop the old eight-pixel
  -- furniture art from reading as a stretched wooden box.
  local function towerGraniteCounterSide(d, x0, z0, y0, y1, shade)
    local axis0 = (d == 5 or d == 6) and x0 or z0
    local axis1 = axis0 + 8
    local function counterShade(axis, y, tone)
      if type(shade) ~= "table" then return shade * tone end
      local fx = math.max(0, math.min(1, (axis - axis0) / 8))
      local fy = math.max(0, math.min(1,
        (y - y0) / math.max(0.001, y1 - y0)))
      local bottom = shade[1] + (shade[2] - shade[1]) * fx
      local top = shade[4] + (shade[3] - shade[4]) * fx
      return (bottom + (top - bottom) * fy) * tone
    end
    local function counterUV(axis, y)
      return towerCounterSideUV(d, axis, y)
    end
    local bl = faceAxisPoint(d, x0, z0, axis0, y0, 0.16)
    local br = faceAxisPoint(d, x0, z0, axis1, y0, 0.16)
    local tr = faceAxisPoint(d, x0, z0, axis1, y1, 0.16)
    local tl = faceAxisPoint(d, x0, z0, axis0, y1, 0.16)
    local tone = 0.84
    push({ bl, br, tr, tl },
         { counterUV(axis0, y0), counterUV(axis1, y0),
           counterUV(axis1, y1), counterUV(axis0, y1) },
         { counterShade(axis0, y0, tone),
           counterShade(axis1, y0, tone),
           counterShade(axis1, y1, tone),
           counterShade(axis0, y1, tone) })

    -- A continuous raised lip separates the polished slab from the base. Its
    -- front is offset from the body, so no coplanar faces can shimmer.
    local lipY0 = math.max(y0, 6.15)
    if y1 > lipY0 then
      local lbl = faceAxisPoint(d, x0, z0, axis0, lipY0, 0.58)
      local lbr = faceAxisPoint(d, x0, z0, axis1, lipY0, 0.58)
      local ltr = faceAxisPoint(d, x0, z0, axis1, y1, 0.58)
      local ltl = faceAxisPoint(d, x0, z0, axis0, y1, 0.58)
      local lipTone = 1.08
      push({ lbl, lbr, ltr, ltl },
           { counterUV(axis0, lipY0), counterUV(axis1, lipY0),
             counterUV(axis1, y1), counterUV(axis0, y1) },
           { counterShade(axis0, lipY0, lipTone),
             counterShade(axis1, lipY0, lipTone),
             counterShade(axis1, y1, lipTone),
             counterShade(axis0, y1, lipTone) })
    end
  end

  -- TEST59 turns TEST58's successful geological direction up aggressively:
  -- tighter facets, deeper strata, crags, fissures, erosion and a heavy talus
  -- foot. The whole connected wall is textured rock rather than smooth slabs,
  -- masonry or isolated chocolate-chip inclusions.
  local function caveNaturalSide(d, x0, z0, y0, y1, shade)
    local axis0 = (d == 5 or d == 6) and x0 or z0
    local axis1 = axis0 + 8
    local plane = d == 5 and z0 + 8 or d == 6 and z0
               or d == 1 and x0 + 8 or x0
    local cellW, cellH = 8, 6
    local planeSalt = 1009 + d * 37 + math.floor(plane) * 3
    local uv = caveSolidUV(CAVE_MOONSTONE_SWATCH_TILE)
    local uvShadow = rockUV(CAVE_MOONSTONE_SWATCH_TILE, ROCK_TEXEL.shadow)
    local uvBody = rockUV(CAVE_MOONSTONE_SWATCH_TILE, ROCK_TEXEL.body)

    -- TEST71 closes the geological skin from behind. The natural facets all
    -- project slightly out from the authored wall plane; without a continuous
    -- rock face at depth zero, the battle camera could see the blue void
    -- through the hairline between their displaced top edge and the walkable
    -- cap. This single inexpensive quad also makes deep fissures reveal dark
    -- stone instead of the world behind the wall.
    sideSolid({ faceAxisPoint(d, x0, z0, axis0, y0, 0),
                faceAxisPoint(d, x0, z0, axis1, y0, 0),
                faceAxisPoint(d, x0, z0, axis1, y1, 0),
                faceAxisPoint(d, x0, z0, axis0, y1, 0) },
              uvShadow, shade, 0.56, d, x0, z0, y0, y1)

    -- Continuous fields rather than per-tile choices. The sediment wave is
    -- bent by macro noise; the sharper crossing field carves occasional deep
    -- seams that interrupt it, avoiding both horizontal brick rows and dots.
    local function wallField(axis, y)
      local macro = caveSmoothNoise(axis * 0.78 + plane * 0.19,
                                    y * 0.82, planeSalt + 43)
      local warp = (caveSmoothNoise(axis * 0.59, y * 0.61,
                                    planeSalt + 71) - 0.5) * 13.5
      local strataWave = math.sin((y + warp) / 2.7
        + math.sin((axis + plane * 0.17) / 13.5) * 1.12)
      local strata = math.max(0, (strataWave + 0.02) / 0.98)
      strata = strata * strata
      local cross = math.abs(math.sin(axis / 5.9 + y / 8.1
        + (caveSmoothNoise(axis * 0.71, y * 0.67,
                           planeSalt + 89) - 0.5) * 3.4))
      local fissure = math.max(0, (cross - 0.75) / 0.25)
      fissure = fissure * fissure
      local cragWave = math.abs(math.sin(axis / 4.4 - y / 6.7
        + (caveSmoothNoise(axis * 0.91, y * 0.87,
                           planeSalt + 97) - 0.5) * 3.0))
      local crag = math.max(0, (cragWave - 0.55) / 0.45)
      crag = crag * crag
      return macro, strata, fissure, crag
    end

    local function vertex(gx, gy)
      local axis = gx * cellW
        + (rockNoise(gx, gy, planeSalt + 11) - 0.5) * cellW * 0.28
      local y = gy * cellH
        + (rockNoise(gx, gy, planeSalt + 17) - 0.5) * cellH * 0.25
      local macro, strata, fissure, crag = wallField(axis, y)
      local baseBulge = math.max(0, 1 - math.abs(y) / 10)
        * (0.34 + macro * 0.48)
      local grain = (rockNoise(gx, gy, planeSalt + 23) - 0.5) * 0.42
      return {
        axis,
        y,
        math.max(0.03, 0.08 + macro * 1.22 + strata * 0.94
          + crag * 0.47 - fissure * 0.62 + baseBulge + grain),
      }
    end

    local function pointShade(p)
      local macro, strata, fissure, crag = wallField(p[1], p[2])
      local micro = caveSmoothNoise(p[1] * 1.31 + plane * 0.23,
                                    p[2] * 1.17, planeSalt + 113)
      local tone = (0.54 + macro * 0.31 + strata * 0.22
                    + crag * 0.13 - fissure * 0.43)
        * (0.88 + micro * 0.17)
      tone = math.max(0.28, math.min(1.22, tone))
      if type(shade) ~= "table" then return shade * tone end
      local fx = math.max(0, math.min(1, (p[1] - axis0) / 8))
      local fy = math.max(0, math.min(1, (p[2] - y0)
                                                / math.max(0.001, y1 - y0)))
      local bottom = shade[1] + (shade[2] - shade[1]) * fx
      local top = shade[4] + (shade[3] - shade[4]) * fx
      return (bottom + (top - bottom) * fy) * tone
    end

    local function point(p)
      return faceAxisPoint(d, x0, z0, p[1], p[2], p[3])
    end

    local function emitFacet(facet, gx, gy, half)
      local poly = caveClipFacetTile(facet, axis0, y0, axis1, y1)
      if #poly < 3 then return end
      local facetTone = 0.69
        + rockNoise(gx * 2 + half, gy, planeSalt + 127) * 0.47
      local function facetShade(p) return pointShade(p) * facetTone end
      if #poly == 4 then
        push({ point(poly[1]), point(poly[2]),
               point(poly[3]), point(poly[4]) },
             { uv, uv, uv, uv },
             { facetShade(poly[1]), facetShade(poly[2]),
               facetShade(poly[3]), facetShade(poly[4]) })
      else
        for i = 2, #poly - 1 do
          local a, b, c = poly[1], poly[i], poly[i + 1]
          push({ point(a), point(b), point(c), point(c) },
               { uv, uv, uv, uv },
               { facetShade(a), facetShade(b),
                 facetShade(c), facetShade(c) })
        end
      end
    end

    local firstGX = math.floor((axis0 - cellW * 0.30) / cellW) - 1
    local lastGX = math.floor((axis1 + cellW * 0.30) / cellW) + 1
    local firstGY = math.floor((y0 - cellH * 0.30) / cellH) - 1
    local lastGY = math.floor((y1 + cellH * 0.30) / cellH) + 1
    for gy = firstGY, lastGY do
      for gx = firstGX, lastGX do
        local bl, br = vertex(gx, gy), vertex(gx + 1, gy)
        local tr, tl = vertex(gx + 1, gy + 1), vertex(gx, gy + 1)
        if rockNoise(gx, gy, planeSalt + 131) < 0.5 then
          emitFacet({ bl, br, tr }, gx, gy, 1)
          emitFacet({ bl, tr, tl }, gx, gy, 2)
        else
          emitFacet({ bl, br, tl }, gx, gy, 1)
          emitFacet({ br, tr, tl }, gx, gy, 2)
        end
      end
    end

    -- A shallow, irregular talus lip breaks the ruler-straight base where the
    -- first wall band meets the floor. It is the same brown rock family—not a
    -- row of objects—and slopes back into the continuous face above it.
    if y0 < 7.9 then
      local footCell = 4.5
      local first = math.floor((axis0 - footCell) / footCell) - 1
      local last = math.floor((axis1 + footCell) / footCell) + 1
      for i = first, last do
        local rawA = i * footCell
          + (rockNoise(i, math.floor(plane), planeSalt + 151) - 0.5) * 1.45
        local rawB = (i + 1) * footCell
          + (rockNoise(i + 1, math.floor(plane), planeSalt + 151) - 0.5) * 1.45
        local a, b = math.max(axis0, rawA), math.min(axis1, rawB)
        if b > a then
          local topA = y0 + 0.88
            + rockNoise(i, math.floor(plane), planeSalt + 157) * 1.92
          local topB = y0 + 0.88
            + rockNoise(i + 1, math.floor(plane), planeSalt + 157) * 1.92
          local lowA = { a, y0 + 0.02,
            1.24 + rockNoise(i, math.floor(plane), planeSalt + 163) * 1.02 }
          local lowB = { b, y0 + 0.02,
            1.24 + rockNoise(i + 1, math.floor(plane), planeSalt + 163) * 1.02 }
          local highB = { b, topB,
            0.62 + rockNoise(i + 1, math.floor(plane), planeSalt + 167) * 0.73 }
          local highA = { a, topA,
            0.62 + rockNoise(i, math.floor(plane), planeSalt + 167) * 0.73 }
          local footTone = 0.72
            + rockNoise(i, math.floor(plane), planeSalt + 173) * 0.28
          push({ point(lowA), point(lowB), point(highB), point(highA) },
               { uvShadow, uvShadow, uvBody, uvBody },
               { pointShade(lowA) * footTone * 0.86,
                 pointShade(lowB) * footTone * 0.86,
                 pointShade(highB) * footTone,
                 pointShade(highA) * footTone })
        end
      end
    end
  end

  -- TEST18 cave mouth for an OVERWORLD retaining wall. TEST14 correctly
  -- stopped continuous masonry from sealing a ROM-marked doorway, but the
  -- fallback exposed the original flat blue/gold door sheet on every face of
  -- the volume. Build a restrained entrance from the same atlas-safe masonry
  -- swatch instead. TEST16 proved the door-run detection and warp-safe opening,
  -- but its thin sampled jambs read as bright blue trim and the tenth-pixel
  -- setback still looked like a flat black door. Put the void well behind the
  -- wall plane and join it with dark side/ceiling returns. The masonry around
  -- the run is already the honest frame, so no artificial trim is needed.
  -- TEST18 closes the one remaining opening in that passage shell: the floor.
  -- Without it, the bright source threshold/top face behind the facade showed
  -- through as a blue-white hairline below the black recess.
  -- Other compass faces remain ordinary retaining wall, preventing the source
  -- door art from wrapping around the mound.
  local function retainingCaveMouthSide(d, tx, ty, x0, z0, y0, y1, h, shade)
    if d ~= 5 then retainingRockSide(d,x0,z0,y0,y1,shade);return end
    local first,last=tx,tx
    while S.runs[keyOf(first-1,ty)] and S.runs[keyOf(first-1,ty)].door do first=first-1 end
    while S.runs[keyOf(last+1,ty)] and S.runs[keyOf(last+1,ty)].door do last=last+1 end
    local left=x0-(tx-first)*8;local width=(last-first+1)*8
    local crown=math.max(4,math.min(h-3,24));local depth=-6
    local dark=rockUV(RETAINING_SWATCH_TILE,ROCK_TEXEL.dark)
    local stone=rockUV(RETAINING_SWATCH_TILE,ROCK_TEXEL.body)
    local function put(a,b,c,e,uv,tone) pushSolid({a,b,c,e},uv,shadeTimes(shade,tone)) end
    local function point(x,y,r)return faceAxisPoint(d,x0,z0,x,y,r)end
    local function opening(x)
      local edge=math.min(x-left,left+width-x)
      if edge<2 then return 0 end
      if edge<4 then return math.max(2,crown-4) end
      if edge<6 then return math.max(3,crown-1) end
      return crown
    end
    for x=x0,x0+6,2 do
      local top=opening(x+1);local upper=math.min(y1,top)
      if top<=y0 then
        -- Same stone donor as surrounding masonry, bounded to this strip.
        put(point(x,y0,0),point(x+2,y0,0),point(x+2,y1,0),point(x,y1,0),stone,.78)
      else
        put(point(x,y0,depth),point(x+2,y0,depth),point(x+2,upper,depth),point(x,upper,depth),dark,.22)
        if y0==0 then put(point(x,0,depth),point(x+2,0,depth),point(x+2,0,0),point(x,0,0),stone,.40) end
        if y1>=top then
          put(point(x,top,depth),point(x+2,top,depth),point(x+2,top,0),point(x,top,0),stone,.55)
          if y1>top then put(point(x,top,0),point(x+2,top,0),point(x+2,y1,0),point(x,y1,0),stone,.78) end
        end
        for _,side in ipairs({-1,1}) do
          local neighbor=opening(x+1+side*2)
          local low=math.max(y0,neighbor)
          if upper>low then
            local edge=side==-1 and x or x+2
            put(point(edge,low,0),point(edge,low,depth),point(edge,upper,depth),point(edge,upper,0),stone,side==-1 and .65 or .48)
          end
        end
      end
    end
  end

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

  -- WALL4: legacy object/volume faces using cliff UVs receive the same
  -- world-aligned masonry as retained terrain, not an enlarged 8px bitmap.
  if tileset.id == "OVERWORLD" and CommunityVisuals.customWalls() then
    push = V.require("CliffMasonry").wrap(push, atlasW, atlasH,
      function(emit, top, side, x, z, y0, y1, shade)
        local saved = push
        push = emit
        local ok, err
        if top then
          ok, err = pcall(ledgeRockTop, math.floor(x/8), math.floor(z/8),
                          x, z, y0, RETAINING_SWATCH_TILE, shade)
        else
          ok, err = pcall(retainingRockSide, side, x, z, y0, y1, shade)
        end
        push = saved
        if not ok then error(err, 0) end
      end)
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

      -- TEST137 battle cameras do not draw the free-roam indoor underlay.
      -- Claimed grave/prop cells can therefore expose the blue scene void
      -- through a missing source-floor fragment even though the monument is
      -- correct. Give every claimed Tower footprint an opaque, slightly
      -- recessed copy of the continuous honed floor. Real descending
      -- stairwells remain open by design.
      if towerInterior and inBody and s and S.skip[k]
          and s.class ~= "stair_down_e" and s.class ~= "stair_down_w"
          and s.class ~= "stair_down_n" and s.class ~= "ladder_down" then
        towerGraniteTop(tx, ty, tx * 8, ty * 8, -0.04, 1,
                        TOWER_GRANITE_SWATCH_TILE, false)
      end

      if s and S.skip[k] then
        -- an object stands here; paint its synthesized ground and let the
        -- prebuilt prism quads (appended below) carry the art
        local g = S.ground[k]
        if LG.lavenderLegendaryGround and LG.lavenderPlazaAt(tx,ty) then g=57 end
        if LG.route10TowerLandscapeAt(tx, ty) or LG.route10LavenderExitLawnAt(tx, ty) then
          -- These Lavender-edge floors are deliberately independent of the
          -- GRASS option. Use Route 10's grass donor for both the Tower claim
          -- and the exact south-connection apron; claims/collision remain
          -- intact and the rest of the Battle Art approach stays sandy.
          kantoGrassTop(tx, ty, tx * 8, ty * 8, 0,
                        aoShades(tx, ty, 0, 1))
        elseif g then
          local caveKind = caveSurfaceKind({ class="ground" }, g)
          local edgeFinish=LG.cliffGroundFinishAt(tx,ty)
          if V.require("TowerGarden").contains(S,tx,ty) then edgeFinish="towerGarden" end
          if edgeFinish=="towerGarden" then
            local x,z=tx*8,ty*8
            push({{x,0,z},{x+8,0,z},{x+8,0,z+8},{x,0,z+8}},
              pavedUV(48,math.floor(rockNoise(tx,ty,1193)*4)),
              grassShades(x,z,aoShades(tx,ty,0,1)))
          elseif edgeFinish=="grass" then
            kantoGrassTop(tx,ty,tx*8,ty*8,0,aoShades(tx,ty,0,1))
          elseif edgeFinish=="path" then
            kantoPavedTop(tx,ty,tx*8,ty*8,0,aoShades(tx,ty,0,1))
          elseif viridianForest then
            forestGroundTop(tx, ty, tx * 8, ty * 8, 0, 0, 1)
          elseif towerInterior then
            towerGraniteTop(tx, ty, tx * 8, ty * 8, 0,
                            1, g, g == 34 and "healing" or false)
          elseif caveKind then
            caveNaturalTop(tx, ty, tx * 8, ty * 8, 0, 1, caveKind)
          elseif LG.lavenderLegendaryGround then
            LG.legendaryLavenderTop(tx,ty,tx*8,ty*8,0,aoShades(tx,ty,0,1),g)
          elseif LG.lavenderGround then
            -- Preserve Lavender's authored path membership even under signs
            -- and claimed building edges. Only the material family changes.
            if lavenderPathTile(g) then
              kantoPavedTop(tx, ty, tx * 8, ty * 8, 0,
                            aoShades(tx, ty, 0, 1))
            elseif LG.lavenderLegendaryGround then
              -- Legendary Lavender uses the same vivid lawn geometry as the
              -- approved bright Route 10 grass instead of mauve city earth.
              kantoGrassTop(tx, ty, tx * 8, ty * 8, 0,
                            aoShades(tx, ty, 0, 1))
            elseif LG.lavenderBattleCurrentGround then
              -- Battle Art snapshots the CURRENT approved Legendary lawn, but
              -- keeps its own branch so a future Legendary revision can change
              -- without taking this baseline away.
              kantoGrassTop(tx, ty, tx * 8, ty * 8, 0,
                            aoShades(tx, ty, 0, 1))
            end
          elseif isKantoCourtyardAt(tx, ty, g) then
            kantoCourtyardTop(tx, ty, tx * 8, ty * 8, 0,
                             aoShades(tx, ty, 0, 1))
          elseif route10LavenderApproachAt(ty)
              and not (CommunityVisuals.customRoads() and KANTO_PATH_TILE[g]) then
            -- From Rock Tunnel to the Lavender seam, Battle Art is one sandy
            -- field regardless of which flat donor the source block used.
            -- Legendary GRASS turns the exact same coverage vivid green.
            if LG.customGrass then
              kantoGrassTop(tx, ty, tx * 8, ty * 8, 0,
                            aoShades(tx, ty, 0, 1))
            else
              kantoPavedTop(tx, ty, tx * 8, ty * 8, 0,
                            aoShades(tx, ty, 0, 1))
            end
          elseif LG.grassReplacement and tileset.id == "OVERWORLD" and (g==44 or g==48) then
            kantoGrassTop(tx,ty,tx*8,ty*8,0,aoShades(tx,ty,0,1))
          elseif CommunityVisuals.customRoads() and KANTO_PATH_TILE[g] then
            local finish, finishAxis = claimedPathFinishAt(tx, ty)
            if finish == "wood" then
              kantoWoodTop(tx, ty, tx * 8, ty * 8, 0,
                           aoShades(tx, ty, 0, 1), finishAxis)
            elseif finish == "grass" and LG.grassReplacement then
              kantoGrassTop(tx, ty, tx * 8, ty * 8, 0,
                            aoShades(tx, ty, 0, 1))
            else
              kantoPavedTop(tx, ty, tx * 8, ty * 8, 0,
                            aoShades(tx, ty, 0, 1))
            end
          else
            topQuad(tx * 8, ty * 8, 0, g, 1)
          end
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
        local sourceH = run and run.h or s.h
        local h = caveRenderHeight(s, tile, sourceH)
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
          -- Ship portholes belong on vertical faces; tile 16 is plain white.
          if map.tileset.id == "SHIP" and s.class == "wall" then topTile = 16 end
          local caveKind = caveSurfaceKind(s, tile)
          local edgeFinish=s.class=="ground" and LG.cliffGroundFinishAt(tx,ty)
          if edgeFinish=="grass" then
            kantoGrassTop(tx,ty,x0,z0,h,aoShades(tx,ty,h,1))
          elseif edgeFinish=="path" then
            kantoPavedTop(tx,ty,x0,z0,h,aoShades(tx,ty,h,1))
          elseif towerInterior and s.class == "wall" then
            towerGraniteTop(tx, ty, x0, z0, h,
                            VOLUME_TOP_SHADE,
                            TOWER_GRANITE_SWATCH_TILE, "wall")
          elseif caveKind then
            caveNaturalTop(tx, ty, x0, z0, h, VOLUME_TOP_SHADE, caveKind)
          elseif isKantoRetainingWall(s, tile, run, tx, ty) then
            ledgeRockTop(tx, ty, x0, z0, h, RETAINING_SWATCH_TILE,
                         aoShades(tx, ty, h, VOLUME_TOP_SHADE))
          else
            topQuad(x0, z0, h, topTile, VOLUME_TOP_SHADE)
          end
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
          if map.tileset.id == "SHIP" and s.class == "wall" then topTile = 16 end
          -- water's surface, and only water's: the recessed sheet itself,
          -- never the ground's shoreline bands around it. A cell an object
          -- stands on took the branch above and paints synthesized GROUND,
          -- which is right -- a sign at the waterline stands on a plot, not
          -- on the pond.
          local paved = kantoSurfaceKind(s, tile)
          local caveKind = caveSurfaceKind(s, tile)
          local edgeFinish=s.class=="ground" and LG.cliffGroundFinishAt(tx,ty)
          if edgeFinish=="grass" then
            kantoGrassTop(tx,ty,x0,z0,h,aoShades(tx,ty,h,1))
          elseif edgeFinish=="path" then
            kantoPavedTop(tx,ty,x0,z0,h,aoShades(tx,ty,h,1))
          elseif towerInterior and s.class == "wall" then
            towerGraniteTop(tx, ty, x0, z0, h,
                            s.art == "upright" and VOLUME_TOP_SHADE or 1,
                            TOWER_GRANITE_SWATCH_TILE, "wall")
          elseif towerInterior and s.class == "counter" then
            towerGraniteTop(tx, ty, x0, z0, h,
                            s.art == "upright" and VOLUME_TOP_SHADE or 1,
                            TOWER_GRANITE_SWATCH_TILE, "counter")
          elseif caveKind then
            caveNaturalTop(tx, ty, x0, z0, h,
                           s.art == "upright" and VOLUME_TOP_SHADE or 1,
                           caveKind)
          elseif viridianForest and s.class == "ground" then
            forestGroundTop(tx, ty, x0, z0, h, topTile,
                            s.art == "upright" and VOLUME_TOP_SHADE or 1)
          elseif LG.lavenderLegendaryGround and s.class == "ground" then
            LG.legendaryLavenderTop(tx,ty,x0,z0,h,aoShades(tx,ty,h,1),topTile)
          elseif LG.lavenderGround and s.class == "ground" then
            local lavenderPath = lavenderPathTile(tile) or lavenderPathTile(topTile)
            if lavenderPath then
              -- Same textured path treatment used by the connected Kanto
              -- roads; the source $23/$39 cells retain their exact topology.
              kantoPavedTop(tx, ty, x0, z0, h, aoShades(tx, ty, h, 1))
            elseif LG.lavenderLegendaryGround then
              kantoGrassTop(tx, ty, x0, z0, h,
                            aoShades(tx, ty, h, 1))
            elseif LG.lavenderBattleCurrentGround then
              kantoGrassTop(tx, ty, x0, z0, h,
                            aoShades(tx, ty, h, 1))
            end
          elseif isKantoCourtyardAt(tx, ty) and s.flat then
            kantoCourtyardTop(tx, ty, x0, z0, h,
                             aoShades(tx, ty, h, 1))
          elseif towerInterior and s.class == "ground" then
            towerGraniteTop(tx, ty, x0, z0, h,
                            1, topTile,
                            (tile == 34 or topTile == 34)
                              and "healing" or false)
          elseif LG.route10LavenderExitLawnAt(tx, ty) and s.class == "ground" then
            -- This must win before the generic $39 path branch below. The
            -- authored seam block is entirely $39, but visually it belongs to
            -- Lavender's plain lawn rather than the checker/path network.
            kantoGrassTop(tx, ty, x0, z0, h, aoShades(tx, ty, h, 1))
          elseif paved == "path" then
            kantoPavedTop(tx, ty, x0, z0, h, aoShades(tx, ty, h, 1))
          elseif paved == "wood" then
            kantoWoodTop(tx, ty, x0, z0, h, aoShades(tx, ty, h, 1))
          elseif route10LavenderApproachAt(ty) and s.class == "ground" then
            if LG.customGrass then
              kantoGrassTop(tx, ty, x0, z0, h, aoShades(tx, ty, h, 1))
            else
              kantoPavedTop(tx, ty, x0, z0, h, aoShades(tx, ty, h, 1))
            end
          elseif LG.grassReplacement and tileset.id == "OVERWORLD"
                 and s.class == "ground" and (topTile == KANTO_GRASS_TILE or topTile == 48) then
            kantoGrassTop(tx, ty, x0, z0, h, aoShades(tx, ty, h, 1))
          -- Legendary ledge masonry belongs to Kanto's outdoor terrain.
          -- CAVERN also uses `ledge` for its raised lit shelf, and sending
          -- that floor through the outdoor rock builder turned Diglett's
          -- Cave into a purple masonry walkway. Preserve the cave profile's
          -- authored top art and six-pixel elevation instead.
          elseif CommunityVisuals.customWalls() and tileset.id == "OVERWORLD"
                 and s.class == "ledge" then
            ledgeRockTop(tx, ty, x0, z0, h, topTile,
                         aoShades(tx, ty, h, 1))
          elseif isKantoRetainingWall(s, tile, run, tx, ty) then
            ledgeRockTop(tx, ty, x0, z0, h, RETAINING_SWATCH_TILE,
                         aoShades(tx, ty, h, VOLUME_TOP_SHADE))
          else
            topQuad(x0, z0, h, topTile,
                    s.art == "upright" and VOLUME_TOP_SHADE or 1,
                    (s.class == "water") and waterPush or nil)
          end
        end

        -- sides: 8px bands wherever the neighbour is lower. Band k spans
        -- heights [8k, 8k+8) and shows one full tile of art; a partial
        -- band crops the art rows to match, so nothing ever stretches.
        for _, side in ipairs(SIDES) do
          local nh = renderHeightAt(tx + side[1], ty + side[2])
          if nh < h then
            local d = side[3]
            -- the columns flanking this face, for the inside-corner term:
            -- fixed for the whole face, so they are read once rather than
            -- once per 8px band
            local lat = LATERAL[d]
            local hl = lat and renderHeightAt(tx + lat[1], ty + lat[2]) or 0
            local hr = lat and renderHeightAt(tx + lat[3], ty + lat[4]) or 0
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
                local faceShade = sideShades(hl, hr, y0, y1,
                                             y0 <= nh, shade)
                -- TEST56 natural cave rock. Cave walls and shelf risers share
                -- one continuous, world-space geological skin: irregular
                -- facets cross hidden tile and vertical-band boundaries with
                -- no courses, mortar, repeated blocks or manufactured joints.
                -- Outdoor retaining walls keep their independent masonry path.
                local edgeFinish=s.class=="ground" and LG.cliffGroundFinishAt(tx,ty)
          if edgeFinish=="grass" then
            kantoGrassTop(tx,ty,x0,z0,h,aoShades(tx,ty,h,1))
          elseif edgeFinish=="path" then
            kantoPavedTop(tx,ty,x0,z0,h,aoShades(tx,ty,h,1))
          elseif towerInterior and s.class == "wall" then
                  towerGraniteSide(d, x0, z0, y0, y1, faceShade)
                elseif towerInterior and s.class == "counter" then
                  towerGraniteCounterSide(d, x0, z0, y0, y1, faceShade)
                elseif CommunityVisuals.customCaves() and tileset.id == "CAVERN"
                   and (s.class == "wall" or s.class == "ledge") then
                  caveNaturalSide(d, x0, z0, y0, y1, faceShade)
                -- Match the top-face scope above: indoor CAVERN ledges keep
                -- their own folded riser art rather than outdoor masonry.
                elseif CommunityVisuals.customWalls() and tileset.id == "OVERWORLD"
                   and s.class == "ledge" then
                  ledgeRockSide(d, tx, ty, x0, z0, y0, y1,
                                src, faceShade)
                -- ROM-marked door volumes receive a purpose-built dark cave
                -- mouth on their south face. Their side/back faces stay
                -- masonry, preventing the raw door sheet from wrapping around
                -- the mound as blue/gold decoration.
                elseif isKantoRetainingWall(s, tile, run, tx, ty)
                       and run and run.door then
                  retainingCaveMouthSide(d, tx, ty, x0, z0,
                                         y0, y1, h, faceShade)
                elseif isKantoRetainingWall(s, tile, run, tx, ty) then
                  retainingRockSide(d, x0, z0, y0, y1, faceShade)
                else
                  sideQuad(d, x0, z0, y0, y1, src,
                           (band * 8 + 8) - y1, (band * 8 + 8) - y0,
                           faceShade)
                end
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
    for i = 1, 4 do
      local uv = q.uv and q.uv[i] or nil
      -- Structures builds authored props against the source tileset atlas.
      -- Tower's finished atlas is larger only because TEST123 appends two
      -- 1024px stone materials,
      -- so renormalize those legacy pixel coordinates into the expanded image.
      if towerInterior and q.towerMaterial then
        local tuv = towerDetailUV(q.towerMaterial, q[i], q)
        scUV[i][1], scUV[i][2] = tuv[1], tuv[2]
      else
        scUV[i][1] = (uv and uv[1] or q.u) * sourceAtlasW / atlasW
        scUV[i][2] = (uv and uv[2] or q.v) * sourceAtlasH / atlasH
      end
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
      own() -- ring geometry must not extend the previous body's prop run
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
    -- Legendary Visuals crowns extend beyond the authored 16px owner. Resolve seam
    -- ownership at the original tree center so the complete tree is kept or
    -- dropped atomically instead of clipping individual canopy quads.
    if st.keepTree and not keepAll and not skipAll then
      local e = .25
      keepAll = keepQuad(mx - e, mz - e, mx + e, mz + e)
      skipAll = not keepAll
    end
    if not skipAll and st.forestBoulder then
      -- ForestDressing owns the complete replacement at this cell.
    elseif not skipAll and st.hideCrown and st.lift and st.lift > 0
       and st.baseY ~= nil then
      -- TEST92: the replacement owns every visible crown vertex. Publishing
      -- its cached template base is the only work this hidden stamp requires.
      local globalName = st.communityTree
        and "__ds_round_base" or "__bav_granite_pillar_base"
      local rb = rawget(_G, globalName)
      if not rb then rb = {}; _G[globalName] = rb end
      local mk = map.id or (map.def and map.def.id) or tostring(map)
      local bk = mk .. ":" .. st.mx .. "|" .. st.mz
      if rb[bk] == nil or st.baseY < rb[bk] then rb[bk] = st.baseY end
    elseif not skipAll then
      -- Keep ownership on the authored cell even when a Legendary crown
      -- extends beyond it. Cut must not remove a neighbouring tree.
      if own and inBodyPx(mx, mz) then
        if st.keepTree then
          ownCell(mx - 8, mz - 8, mx + 8, mz + 8)
        else
          own(sx0, sz0, sx1, sz1)
          ownedCell = nil
        end
      elseif own then
        own()
        ownedCell = nil
      end
      for _, q in ipairs(st.quads) do
        Budget.tick()
        for i = 1, 4 do
          local c, s2 = q[i], sc[i]
          s2[1] = c[1] + mx
          s2[2] = c[2] + (st.lift or 0)
          if st.hideCrown and st.lift and st.lift > 0 then
            local globalName = st.communityTree
              and "__ds_round_base" or "__bav_granite_pillar_base"
            local rb = rawget(_G, globalName)
            if not rb then rb = {}; _G[globalName] = rb end
            local mk = map.id or (map.def and map.def.id) or tostring(map)
            local bk = mk .. ":" .. st.mx .. "|" .. st.mz
            if rb[bk] == nil or c[2] < rb[bk] then rb[bk] = c[2] end
          end
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
        if ok and not st.hideCrown then
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

local function auxiliaryUVScale(map)
  local id = tostring(map and map.id or ""):upper()
  local tower = map and map.tileset and map.tileset.id == "CEMETERY"
    and id:match("^POKEMON_TOWER_[1-7]F$") ~= nil
    and CommunityVisuals.customTower()
  if not tower then return 1, 1 end
  local sw = map.tileset.imageWidth or 128
  local sh = map.tileset.imageHeight or 48
  -- Match TerrainAtlas: wall + counter across, wall + floor vertically.
  return sw / (sw + 2048 + 1024), sh / math.max(sh, 2048 + 2048)
end

local function quadsMesh(quads, uScale, vScale)
  if #quads == 0 then return nil end
  uScale, vScale = uScale or 1, vScale or 1
  local spans = quadListSpans(quads, 4)
  local verts, indices, n = {}, {}, 0
  for _, q in ipairs(quads) do
    for i = 1, 4 do
      local c = q[i]
      local uv = q.uv and q.uv[i] or { q.u, q.v }
      verts[#verts + 1] = {
        c[1], c[2], c[3], uv[1] * uScale, uv[2] * vScale, q.shade,
      }
    end
    Voxel3D.pushQuad(indices, n)
    n = n + 1
  end
  return Voxel3D.newMesh(verts, indices), spans
end

-- Flatten auxiliary quads into the same unindexed six-float stream terrain
-- uses. This path is selected only when persistent caching is available; the
-- historical table builder remains the headless/non-FFI fallback.
local function rawQuads(quads, uScale, vScale)
  local n = #(quads or {}) * 6
  if n == 0 then return { n = 0 } end
  uScale, vScale = uScale or 1, vScale or 1
  if MeshDisk.legacy() and ffi then
    local buf, at = ffi.new("float[?]", n * 6), 0
    for _, q in ipairs(quads) do
      for k = 1, 6 do
        local i = TRI_ORDER[k]
        local c = q[i]
        local uv = q.uv and q.uv[i] or { q.u, q.v }
        buf[at], buf[at + 1], buf[at + 2] = c[1], c[2], c[3]
        buf[at + 3], buf[at + 4], buf[at + 5] =
          uv[1] * uScale, uv[2] * vScale, q.shade
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
      values[at + 3], values[at + 4], values[at + 5] =
        uv[1] * uScale, uv[2] * vScale, q.shade
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
  local uScale, vScale = auxiliaryUVScale(map)
  local aux = {
    grass = rawQuads(structures.grassQuads, uScale, vScale),
    flowers = rawQuads(structures.flowerQuads, uScale, vScale),
    figures = {},
  }
  for _, figure in ipairs(structures.figures or {}) do
    local raw = rawQuads(figure.quads, uScale, vScale)
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
  local uScale, vScale = auxiliaryUVScale(map)
  return quadsMesh(Structures.forMap(map).grassQuads, uScale, vScale)
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
  local uScale, vScale = auxiliaryUVScale(map)
  return quadsMesh(Structures.forMap(map).flowerQuads, uScale, vScale)
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
  local uScale, vScale = auxiliaryUVScale(map)
  for _, f in ipairs(Structures.forMap(map).figures or {}) do
    local mesh = quadsMesh(f.quads, uScale, vScale)
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

-- TEST96 CACHED LEGENDARY SIDECAR:
-- Terrain streams survive a restart, but the tiny Lua registries that locate
-- replacement trees/pillars historically did not. Serialise only those owner
-- cells and their published bases beside the terrain stream. This is several
-- lines per prop, not another geometry copy, and lets a cache hit restore the
-- exact inputs CommunityFlora expects without rerunning Structures.
local function registrySnapshot(map)
  local key = tostring(map.id or (map.def and map.def.id) or map)
  local treeCells = (rawget(_G, "__ds_round_cells") or {})[key] or {}
  local saplings = (rawget(_G, "__ds_sapling_cells") or {})[key] or {}
  local treeBases = rawget(_G, "__ds_round_base") or {}
  local pillarCells = (rawget(_G, "__bav_granite_pillars") or {})[key] or {}
  local pillarBases = rawget(_G, "__bav_granite_pillar_base") or {}
  local lines = {}
  local function numberToken(value)
    return type(value) == "number" and string.format("%.17g", value) or "n"
  end
  for cell, lift in pairs(treeCells) do
    local cx, cy = tostring(cell):match("^(-?%d+)|(-?%d+)$")
    if cx and cy and type(lift) == "number" then
      local base = treeBases[key .. ":" .. (tonumber(cx) * 16 + 8)
                             .. "|" .. (tonumber(cy) * 16 + 8)]
      lines[#lines + 1] = table.concat({
        "T", cx, cy, numberToken(lift), numberToken(base),
        saplings[cell] == true and "1" or "0",
      }, "\t")
    end
  end
  for cell in pairs(pillarCells) do
    local cx, cy = tostring(cell):match("^(-?%d+)|(-?%d+)$")
    if cx and cy then
      local base = pillarBases[key .. ":" .. (tonumber(cx) * 16 + 8)
                               .. "|" .. (tonumber(cy) * 16 + 8)]
      lines[#lines + 1] = table.concat({
        "P", cx, cy, "1", numberToken(base), "0",
      }, "\t")
    end
  end
  table.sort(lines)
  return table.concat(lines, "\n")
end

local function restoreRegistrySnapshot(map, payload)
  if type(payload) ~= "string" then return false end
  local key = tostring(map.id or (map.def and map.def.id) or map)
  local rounds = rawget(_G, "__ds_round_cells") or {}
  local saplings = rawget(_G, "__ds_sapling_cells") or {}
  local treeBases = rawget(_G, "__ds_round_base") or {}
  local pillars = rawget(_G, "__bav_granite_pillars") or {}
  local pillarBases = rawget(_G, "__bav_granite_pillar_base") or {}
  _G.__ds_round_cells, _G.__ds_sapling_cells = rounds, saplings
  _G.__ds_round_base = treeBases
  _G.__bav_granite_pillars = pillars
  _G.__bav_granite_pillar_base = pillarBases
  local roundMap = rounds[key] or {}
  local saplingMap = saplings[key] or {}
  local pillarMap = pillars[key] or {}
  for cell in pairs(roundMap) do roundMap[cell] = nil end
  for cell in pairs(saplingMap) do saplingMap[cell] = nil end
  for cell in pairs(pillarMap) do pillarMap[cell] = nil end
  rounds[key], saplings[key], pillars[key] = roundMap, saplingMap, pillarMap
  for line in payload:gmatch("[^\n]+") do
    local kind, sx, sy, valueToken, baseToken, saplingToken =
      line:match("^([TP])\t(-?%d+)\t(-?%d+)\t([^\t]+)\t([^\t]+)\t([01])$")
    local cx, cy = tonumber(sx), tonumber(sy)
    local value, base = tonumber(valueToken), tonumber(baseToken)
    if kind and cx and cy and value then
      local cell = sx .. "|" .. sy
      local baseKey = key .. ":" .. (cx * 16 + 8) .. "|" .. (cy * 16 + 8)
      if kind == "T" then
        roundMap[cell] = value
        if saplingToken == "1" then saplingMap[cell] = true end
        if base ~= nil then treeBases[baseKey] = base end
      else
        pillarMap[cell] = true
        if base ~= nil then pillarBases[baseKey] = base end
      end
    end
  end
  if next(rounds[key]) then _G.__ds_tree_lift = true end
  return true
end

local function mapHasVisualObjects(map)
  -- Revision-36 caches one canonical split regardless of which companion
  -- extensions happened to be active while PRECACHE ran. Without this, a
  -- cache generated before an overworld-model provider loaded would bake the
  -- sign into terrain forever and could never suppress it later.
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
  CacheTrace.log(ok and "job-done" or "job-failed", job.id, "slot=" .. job.slot .. " error=" .. tostring(err))
  if not ok and job.cancel then job.cancel() end
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
  CacheTrace.log("job-start", job.id, "slot=" .. job.slot)
  if job.work then return job.work() end
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
        CacheTrace.log("build-aux", job.id, "cache miss")
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
  -- The moving vessel is a session mesh, also needed after disk restoration.
  local sessionVessel = map.id == "VERMILION_DOCK" and V.require("ShipHull").enabled(map)
  -- TEST96: ask for the complete cached answer before invoking Structures.
  -- Revision-36 records include suppressible sign streams plus tree/pillar
  -- registries, so those features no longer make a cache hit ineligible.
  local cached = not sessionVessel and not job.bypassCache
    and MeshDisk.loadTerrain(map, job.slot, job.masks) or nil
  if cached then
    CacheTrace.log("upload-cached", job.id, "slot=" .. job.slot)
    restoreRegistrySnapshot(map, cached.registry)
    mesh = meshFromRaw(cached.terrain)
    water = meshFromRaw(cached.water)
    -- the prop runs were written with the record: a precached map can drop a
    -- felled tree without ever having run the geometry pass this session
    spans = cached.spans
    visualMeshes = {}
    for id, raw in pairs(cached.visuals or {}) do
      local visualMesh = meshFromRaw(raw)
      if visualMesh then visualMeshes[id] = visualMesh end
    end
    if not next(visualMeshes) then visualMeshes = nil end
  else
    CacheTrace.log("build-terrain", job.id, "slot=" .. job.slot)
    local annotatedVisuals = mapHasVisualObjects(map)
    local sink, waterSink = newSink(), newSink()
    local visualSinks = annotatedVisuals and {} or nil
    runGeometry(map, job.slot == "body", job.masks, sink, waterSink,
      visualSinks)
    local terrainRaw = sink.raw and sink.raw() or nil
    local waterRaw = waterSink.raw and waterSink.raw() or nil
    mesh, water = sink.finish(), waterSink.finish()
    spans = (terrainRaw and terrainRaw.spans)
            or (sink.spans and sink.spans()) or nil
    local visualRaw = {}
    if visualSinks then
      visualMeshes = {}
      for id, visualSink in pairs(visualSinks) do
        local raw = visualSink.raw and visualSink.raw() or nil
        if raw and raw.n and raw.n > 0 then visualRaw[id] = raw end
        local visualMesh = visualSink.finish()
        if visualMesh then visualMeshes[id] = visualMesh end
      end
      if not next(visualMeshes) then visualMeshes = nil end
    end
    if not current() then
      if mesh and mesh.release then pcall(mesh.release, mesh) end
      if water and water.release then pcall(water.release, water) end
      releaseVisualMeshes(visualMeshes)
      return
    end
    if terrainRaw and waterRaw and not job.bypassCache then
      local savedTerrain, terrainError =
        MeshDisk.saveTerrain(map, job.slot, job.masks, terrainRaw, waterRaw,
          visualRaw, registrySnapshot(map))
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
  trees("requestCommunityTrees", map, job.masks, job.priority, job.slot == "body")
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
  if c and c[slot] ~= nil and not stale then
    trees("ensureCommunityTrees", map, masks, priorityValue(priority), bodyOnly)
    return c[slot] or nil
  end
  local key = jobKey(map.id, slot)
  local job = jobIndex[key]
  local requested = priorityValue(priority)
  if not job then
    CacheTrace.log("queue", map.id, "slot=" .. slot .. " priority=" .. requested)
    jobFailures[key] = nil
    job = { id = map.id, map = map, slot = slot, masks = masks,
            priority = requested, gen = gen[map.id] or 0,
            bypassCache = stale and true or false }
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

-- Presentation jobs share terrain's coroutine budget and cancellation lifecycle.
function ChunkMesher.requestWork(map, name, signature, priority, work, cancel)
  local slot = "work-" .. name
  local key = jobKey(map.id, slot)
  local prior = jobIndex[key]
  if prior and prior.signature == signature then
    prior.priority = math.max(prior.priority or 0, priority or 0)
    return false
  end
  if prior then
    if prior.cancel then prior.cancel() end
    for i = #jobs, 1, -1 do if jobs[i] == prior then table.remove(jobs, i) end end
  end
  local job = { id = map.id, map = map, slot = slot, signature = signature,
    priority = priority or 0, gen = gen[map.id] or 0, work = work, cancel = cancel }
  jobIndex[key] = job
  jobs[#jobs + 1] = job
  CacheTrace.log("queue", map.id, slot .. " priority=" .. job.priority)
  return true
end

function ChunkMesher.cancelWork(mapId, name)
  local key = jobKey(mapId, "work-" .. name)
  local job = jobIndex[key]
  if not job then return end
  if job.cancel then job.cancel() end
  jobIndex[key] = nil
  for i = #jobs, 1, -1 do if jobs[i] == job then table.remove(jobs, i) end end
end

function ChunkMesher.pending()
  return #jobs
end

-- Lightweight, read-only runtime state for external diagnostics. Do not expose
-- meshes, maps or coroutine objects: consumers only need queue/cache pressure,
-- and returning engine objects would make this an accidental ownership API.
function ChunkMesher.stats()
  local out = {
    maps = 0,
    settled = { full = 0, body = 0, aux = 0 },
    staleMaps = 0,
    pending = #jobs,
    unconsumedFailures = 0,
    queue = { current = 0, visible = 0, speculative = 0, work = 0,
              bypassCache = 0 },
    jobs = {},
    jobsTruncated = #jobs > 32,
  }
  for _, c in pairs(cache) do
    out.maps = out.maps + 1
    if c.full ~= nil then out.settled.full = out.settled.full + 1 end
    if c.body ~= nil then out.settled.body = out.settled.body + 1 end
    if c.grass ~= nil and c.flowers ~= nil and c.figures ~= nil then
      out.settled.aux = out.settled.aux + 1
    end
    if c.stale then out.staleMaps = out.staleMaps + 1 end
  end
  for _ in pairs(jobFailures) do
    out.unconsumedFailures = out.unconsumedFailures + 1
  end
  for i, job in ipairs(jobs) do
    local priority = tonumber(job.priority) or 0
    local work = tostring(job.slot or ""):match("^work%-") ~= nil
    if work then
      out.queue.work = out.queue.work + 1
    elseif priority >= 2 then
      out.queue.current = out.queue.current + 1
    elseif priority > 0 then
      out.queue.visible = out.queue.visible + 1
    else
      out.queue.speculative = out.queue.speculative + 1
    end
    if job.bypassCache then out.queue.bypassCache = out.queue.bypassCache + 1 end
    if i <= 32 then
      out.jobs[#out.jobs + 1] = {
        id = tostring(job.id or ""), slot = tostring(job.slot or ""),
        priority = priority, bypassCache = job.bypassCache and true or false,
      }
    end
  end
  return out
end

-- Stop an eager destination job after OFF is selected. A request already
-- promoted by the live renderer must finish; its terrain is needed on screen.
function ChunkMesher.cancelSpeculative(mapId, bodyOnly)
  local key = jobKey(mapId, bodyOnly and "body" or "full")
  local job = jobIndex[key]
  if not job or (job.priority or 0) > 0 then return false end
  jobIndex[key] = nil
  for i = #jobs, 1, -1 do
    if jobs[i] == job then table.remove(jobs, i); break end
  end
  return true
end

-- Precachers/tooling need to know when one requested slot has landed without
-- retaining or inspecting its GPU mesh.  This is intentionally only a queue
-- probe; a failed build and a completed build both stop being pending.
function ChunkMesher.jobPending(mapId, bodyOnly)
  return jobIndex[jobKey(mapId, bodyOnly and "body" or "full")] ~= nil
    or jobIndex[jobKey(mapId, "work-legendary-mature")] ~= nil
    or jobIndex[jobKey(mapId, "work-legendary-sapling")] ~= nil
end

-- A completed and a failed coroutine both disappear from jobPending(). Keep
-- the latter's exact exception until the sole consumer (precache diagnostics)
-- records it. Runtime callers need no special handling: false remains cached
-- as before and ordinary rendering continues to fail open.
function ChunkMesher.takeJobFailure(mapId, bodyOnly)
  local key = jobKey(mapId, bodyOnly and "body" or "full")
  local err = jobFailures[key] or jobFailures[jobKey(mapId, "work-legendary-mature")]
    or jobFailures[jobKey(mapId, "work-legendary-sapling")]
  jobFailures[jobKey(mapId, "work-legendary-mature")] = nil
  jobFailures[jobKey(mapId, "work-legendary-sapling")] = nil
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
-- and speculative destinations. Visible slices favor frame responsiveness
-- over completion speed; a current-map BODY gets a slightly larger bootstrap
-- slice so useful terrain lands first. `covered`
-- says the world pass is hidden
-- this frame (a warp's fade, a menu): nothing visible can hitch, so the
-- slice opens up and a door fade swallows most of a destination build.
local BODY_BOOTSTRAP_SLICE = 0.0065
local FOREGROUND_SLICE = 0.00475
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
  local bootstrap = pick.slot == "body" and (pick.priority or 0) >= 2
  local slice = covered and COVERED_SLICE
                or (bootstrap and BODY_BOOTSTRAP_SLICE)
                or ((pick.priority or 0) > 0 and FOREGROUND_SLICE
                    or IDLE_SLICE)
  local deadline = clock() + slice
  while pick do
    if not pick.co then
      pick.co = coroutine.create(runJob)
    end
    -- Cap the whole pump, not each resumed job separately. Keep the registered
    -- coroutine guard in BuildBudget even with more frequent visible polling.
    Budget.begin(pick.co, deadline - clock(), covered and 32 or 4)
    local ok, err = Timings.resume(pick.co, pick)
    Budget.finish()
    if not ok then
      Timings.jobError()
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
  trees("evictTrees", mapId)
  CacheTrace.log("refresh", mapId, "block=" .. tostring(bx) .. "," .. tostring(by))
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
      if job.cancel then job.cancel() end
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
  trees("setLive", live)
  for id, c in pairs(cache) do
    if not live[id] and not prevLive[id] then
      CacheTrace.log("evict-gpu", id, "outside current/previous live set")
      releaseEntry(c)
      cache[id] = nil
      gen[id] = (gen[id] or 0) + 1
      Structures.invalidate(id)
    end
  end
  for i = #jobs, 1, -1 do
    local job = jobs[i]
    if not live[job.id] and not prevLive[job.id] then
      if job.cancel then job.cancel() end
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
  CacheTrace.log("evict-runtime", mapId, "disk records retained")
  trees("evictTrees", mapId)
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
      if job.cancel then job.cancel() end
      jobIndex[jobKey(job.id, job.slot)] = nil
      table.remove(jobs, i)
    end
  end
end

-- Drop one map's mesh (Cut swapped a block) or all of them (hot reload).
-- Structures' analysis is derived from the same block layer, so it drops
-- in the same breath; in-flight builds of the map are cancelled through
-- the generation counter.
function ChunkMesher.invalidate(mapId, reason)
  CacheTrace.log("invalidate", mapId, reason or "unspecified caller")
  trees("evictTrees", mapId)
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
      if job.cancel then job.cancel() end
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
-- invalidate) and the on-disk BAVC files (via MeshDisk.purge) -- so the mesher
-- rebuilds every area from scratch on the next frame. This is the "DROP MESH
-- CACHE" pause-menu action: use it after a geometry/grounding change (e.g. the
-- pinBase cylinder/tree fix) left stale floating meshes baked into the cache.
-- Fails open; a missing or read-only backend simply leaves the disk as-is.
function ChunkMesher.purgeCache()
  ChunkMesher.invalidate()
  if MeshDisk and MeshDisk.purge then
    pcall(MeshDisk.purge)
  end
end

-- Exclusive timings: geometry includes its existing inline packing; upload
-- preparation excludes separately measured driver allocations and writes.
runGeometry = Timings.wrap("terrain_build", runGeometry)
buildRawAux = Timings.wrap("terrain_build", buildRawAux)
buildGrassMesh = Timings.wrap("terrain_build", buildGrassMesh)
buildFlowerMesh = Timings.wrap("terrain_build", buildFlowerMesh)
buildFigureMeshes = Timings.wrap("terrain_build", buildFigureMeshes)
meshFromRaw = Timings.wrap("terrain_upload", meshFromRaw)
meshesFromRawAux = Timings.wrap("terrain_upload", meshesFromRawAux)
runJob = Timings.wrap("terrain_other", runJob)
ChunkMesher.pump = Timings.wrap("terrain_other", ChunkMesher.pump)
ChunkMesher.build = Timings.wrap("terrain_other", ChunkMesher.build)
do
  local original = newSink
  newSink = function(...)
    local sink = original(...)
    sink.finish = Timings.wrap("terrain_upload", sink.finish)
    if sink.raw then sink.raw = Timings.wrap("terrain_upload", sink.raw) end
    return sink
  end
end

return ChunkMesher
