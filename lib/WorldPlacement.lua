-- Stable world coordinates for maps joined by seamless overworld connections.
--
-- OverworldState deliberately re-roots its neighbour offsets at the current
-- map after every crossing.  That is ideal for ordinary drawing, but it made
-- an otherwise identical HorizonWall union miss its cache and rebuild at the
-- seam.  This module walks the COMPLETE connection component and anchors it
-- at the lexicographically first map id.  The resulting coordinates do not
-- depend on which map happens to be current or which two-hop subset is visible.
--
-- Runtime map edits can produce an inconsistent connection cycle.  In that
-- case we fail closed and let HorizonWall use its old root-local address: a
-- redundant rebuild is preferable to reusing geometry at the wrong position.

local WorldPlacement = {}

local registryRef
local positions = {}
local invalid = {}

local DIRECTIONS = { "north", "south", "west", "east" }

local function engineMaps()
  local ok, Game = pcall(require, "src.core.Game")
  return ok and Game and Game.data and Game.data.maps or nil
end

local function registry(maps)
  maps = maps or engineMaps()
  if maps ~= registryRef then
    registryRef = maps
    positions, invalid = {}, {}
  end
  return maps
end

local function delta(def, dest, direction, connection)
  local offset = (connection and connection.offset or 0) * 32
  if direction == "north" then
    return offset, -dest.height * 32
  elseif direction == "south" then
    return offset, def.height * 32
  elseif direction == "west" then
    return -dest.width * 32, offset
  elseif direction == "east" then
    return def.width * 32, offset
  end
end

local function buildComponent(maps, startId)
  local start = maps and maps[startId]
  if not start then
    invalid[startId] = true
    return false
  end

  local localPos = { [startId] = { x = 0, y = 0 } }
  local queue, qi = { startId }, 1
  local members = {}
  local consistent = true
  while queue[qi] do
    local id = queue[qi]
    qi = qi + 1
    members[#members + 1] = id
    local def, here = maps[id], localPos[id]
    for _, direction in ipairs(DIRECTIONS) do
      local connection = def.connections and def.connections[direction]
      local dest = connection and maps[connection.map]
      if dest then
        local dx, dy = delta(def, dest, direction, connection)
        local x, y = here.x + dx, here.y + dy
        local prior = localPos[connection.map]
        if prior then
          if prior.x ~= x or prior.y ~= y then consistent = false end
        else
          localPos[connection.map] = { x = x, y = y }
          queue[#queue + 1] = connection.map
        end
      end
    end
  end

  if not consistent then
    for _, id in ipairs(members) do invalid[id] = true end
    return false
  end

  table.sort(members, function(a, b) return tostring(a) < tostring(b) end)
  local anchor = localPos[members[1]]
  for _, id in ipairs(members) do
    local p = localPos[id]
    positions[id] = {
      x = p.x - anchor.x,
      y = p.y - anchor.y,
      anchor = members[1],
    }
  end
  return true
end

function WorldPlacement.position(mapId, maps)
  maps = registry(maps)
  if not (maps and mapId) or invalid[mapId] then return nil end
  if not positions[mapId] and not buildComponent(maps, mapId) then return nil end
  return positions[mapId]
end

-- Convert a root-local visible union to stable component coordinates.  Every
-- local offset is verified against the full graph before reuse; this catches a
-- hot-patched/modded connection even when the component itself was previously
-- valid.  `baseX/baseY` translate canonical mesh offsets back into the current
-- root's local world frame.
function WorldPlacement.canonical(localMaps, rootId, maps)
  maps = registry(maps)
  local root = WorldPlacement.position(rootId, maps)
  if not root then return nil end

  local out = {}
  for _, entry in ipairs(localMaps or {}) do
    local id = entry.map and entry.map.id
    local p = WorldPlacement.position(id, maps)
    if not p or p.anchor ~= root.anchor
       or p.x - root.x ~= entry.ox or p.y - root.y ~= entry.oy then
      return nil
    end
    local copy = {}
    for key, value in pairs(entry) do copy[key] = value end
    copy.ox, copy.oy = p.x, p.y
    copy.x0, copy.z0 = p.x, p.y
    copy.x1, copy.z1 = p.x + copy.w, p.y + copy.h
    out[#out + 1] = copy
  end
  table.sort(out, function(a, b)
    local aid, bid = tostring(a.map.id), tostring(b.map.id)
    if aid ~= bid then return aid < bid end
    if a.ox ~= b.ox then return a.ox < b.ox end
    return a.oy < b.oy
  end)
  return out, -root.x, -root.y
end

function WorldPlacement.invalidate()
  registryRef = nil
  positions, invalid = {}, {}
end

return WorldPlacement
