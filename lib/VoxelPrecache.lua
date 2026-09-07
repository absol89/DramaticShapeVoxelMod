-- Predictive voxel-area precaching.
--
-- VoxelScene already streams the current map and the bodies of connected
-- neighbours.  That makes a seamless route crossing cheap, but a door/stair
-- warp names a map which is not rendered yet, so historically its first mesh
-- request happened only after the map swap.  This module uses the engine's
-- authoritative warp resolver to discover those destinations while the player
-- is still in the current area and feeds them through ChunkMesher's ordinary
-- cooperative queue.  Nothing is built synchronously and no option/menu action
-- is needed.
--
-- Only exits from the CURRENT map are warmed.  ChunkMesher's live-set eviction
-- drops unused candidates on the next area change, bounding GPU/Structures
-- memory without an all-world cache (important on Android).

local V = ...

local ChunkMesher = V.require("ChunkMesher")
local MeshDisk = V.require("VoxelMeshDisk")
local RamPrecache = V.require("RamPrecache")

local Precache = {}

local rootId = nil
local candidates = {}
local nextCandidate = 1
local active = nil

function Precache.cacheable(map)
  return MeshDisk.staticEligible(map)
end

local function addCandidate(out, seen, id, distance, kind)
  if not id or seen[id] then return end
  seen[id] = true
  out[#out + 1] = { id = id, distance = distance or math.huge, kind = kind }
end

local function warpDistance(player, warp)
  if not (player and warp) then return math.huge end
  local px = player.targetX or player.cellX or 0
  local py = player.targetY or player.cellY or 0
  local dx, dy = (warp.x or px) - px, (warp.y or py) - py
  return dx * dx + dy * dy
end

local function edgeDistance(player, def, dir)
  if not (player and def) then return math.huge end
  local x = player.targetX or player.cellX or 0
  local y = player.targetY or player.cellY or 0
  if dir == "north" then return y * y end
  if dir == "south" then
    local d = (def.height * 2 - 1) - y
    return d * d
  end
  if dir == "west" then return x * x end
  local d = (def.width * 2 - 1) - x
  return d * d
end

-- Pure candidate discovery, exposed for the headless suite.  Warp.destination
-- is deliberately used instead of reading destMap directly: LAST_MAP exits and
-- compatibility hooks must predict the same place the real step will enter.
function Precache.candidates(data, overworld)
  local map = overworld and overworld.map
  local maps = data and data.maps
  if not (map and map.def and maps) then return {} end

  local out, seen = {}, { [map.id] = true }
  local okWarp, Warp = pcall(require, "src.world.Warp")
  if okWarp and Warp then
    for _, warp in ipairs(map.def.warps or {}) do
      local ok, id = pcall(function()
        local dest = Warp.destination(data, warp, overworld.lastOutdoor)
        return dest
      end)
      if ok and maps[id] then
        addCandidate(out, seen, id, warpDistance(overworld.player, warp), "warp")
      end
    end
  end

  -- Connected bodies are already warm because they are visible, but their
  -- FULL variants (including the destination's own border ring) are not.
  -- Queue direct connections here so crossing a seam promotes a complete map.
  for dir, connection in pairs(map.def.connections or {}) do
    if connection and maps[connection.map] then
      addCandidate(out, seen, connection.map,
                   edgeDistance(overworld.player, map.def, dir), "connection")
    end
  end

  table.sort(out, function(a, b)
    if a.distance ~= b.distance then return a.distance < b.distance end
    if a.kind ~= b.kind then return a.kind == "warp" end
    return tostring(a.id) < tostring(b.id)
  end)
  return out
end

-- Full-mesh masks must match the placement logic used by the live renderer;
-- otherwise a cached destination could grow border trees through a connected
-- route.  The engine owns this graph math, so do not duplicate it here.
function Precache.masksFor(data, mapId)
  local ok, Controller = pcall(require, "src.world.OverworldController")
  if not (ok and Controller and Controller.computeNeighbors) then return {} end
  local out = {}
  for _, nb in ipairs(Controller.computeNeighbors(data.maps, mapId, 2) or {}) do
    local def = data.maps[nb.id]
    if def then
      out[#out + 1] = {
        nb.ox, nb.oy,
        nb.ox + def.width * 32,
        nb.oy + def.height * 32,
      }
    end
  end
  return out
end

-- Every persistent variant gameplay can request, in deterministic map order.
-- FULL is the map when current. BODY is only needed for maps which participate
-- in an outdoor connection and may therefore be drawn as somebody else's
-- neighbour; interiors reached solely by warps never request that duplicate.
-- Kept pure so the title screen and tests can explain exactly what "all" is.
function Precache.allJobs(data)
  local maps = data and data.maps or {}
  local ids, connected = {}, {}
  for id, def in pairs(maps) do
    if type(id) == "string" and type(def) == "table" then
      ids[#ids + 1] = id
      for _, connection in pairs(def.connections or {}) do
        local other = type(connection) == "table" and connection.map or nil
        if other and maps[other] then
          connected[id], connected[other] = true, true
        end
      end
    end
  end
  table.sort(ids)
  local jobs = {}
  for _, id in ipairs(ids) do
    jobs[#jobs + 1] = { id = id, bodyOnly = false, kind = "full" }
    if connected[id] then
      jobs[#jobs + 1] = { id = id, bodyOnly = true, kind = "body" }
    end
  end
  return jobs
end

local function restart(data, overworld)
  rootId = overworld.map.id
  candidates = Precache.candidates(data, overworld)
  nextCandidate = 1
  active = nil
end

local function jobPending(id)
  return ChunkMesher.jobPending and ChunkMesher.jobPending(id, false)
end

-- Called once from the voxel pipeline update.  It only ENQUEUES work; the
-- existing ChunkMesher.pump call remains the single place CPU/GPU work runs,
-- under the same 5 ms idle slice as neighbour streaming.
function Precache.update(game)
  if RamPrecache.off() then
    Precache.reset()
    return
  end
  local overworld = game and game.overworld
  local data = game and game.data
  if not (overworld and overworld.map and data and data.maps) then return end

  if rootId ~= overworld.map.id then restart(data, overworld) end

  -- Asset reloads, void-fill changes and block edits can invalidate meshes
  -- without changing the map id.  Re-arm whichever completed prediction was
  -- dropped, rather than leaving the precacher permanently "done" on this
  -- area.  This scan runs only after the queue has reached its end.
  if not active and nextCandidate > #candidates then
    for i, candidate in ipairs(candidates) do
      if candidate.map and not ChunkMesher.slotKnown(candidate.map, false) then
        nextCandidate = i
        break
      end
    end
  end

  if active then
    if jobPending(active.id) then return end
    -- Texture creation is deferred until its mesh has landed, so the visible
    -- area's own queue always wins.  VoxelScene remembers the live palette
    -- callback and can prepare RED++/SGB atlas variants faithfully.
    local ok, scene = pcall(V.require, "VoxelScene")
    if ok and scene and scene.warmAtlas then pcall(scene.warmAtlas, active.map) end
    candidates[nextCandidate].map = active.map
    active = nil
    nextCandidate = nextCandidate + 1
  end

  local candidate = candidates[nextCandidate]
  if not candidate then return end

  -- Never compete with the current map or visible neighbours.  Begin the next
  -- destination only when their queue is empty and the current FULL mesh is
  -- already drawable.
  if ChunkMesher.pending() ~= 0 or not ChunkMesher.peek(overworld.map, false) then
    return
  end

  local okLoader, MapLoader = pcall(require, "src.world.MapLoader")
  if not (okLoader and MapLoader and MapLoader.load) then return end
  local okMap, map = pcall(MapLoader.load, data, candidate.id)
  if not (okMap and map) then
    nextCandidate = nextCandidate + 1
    return
  end

  -- A destination whose live geometry differs from the immutable post-mod
  -- snapshot is deliberately RAM-only. Do not spend background time building
  -- a variant which the persistent cache is forbidden to save; the visible
  -- renderer will build it if/when the player actually enters that state.
  if not Precache.cacheable(map) then
    nextCandidate = nextCandidate + 1
    return
  end

  ChunkMesher.request(map, false, Precache.masksFor(data, map.id), false)
  active = { id = map.id, map = map }
end

function Precache.reset()
  if active then ChunkMesher.cancelSpeculative(active.id, false) end
  rootId, candidates, nextCandidate, active = nil, {}, 1, nil
end

function Precache.progress()
  return nextCandidate - 1, #candidates, active and active.id or nil, rootId
end

return Precache
