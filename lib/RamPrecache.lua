-- Session RAM budget for compressed voxel containers loaded at CONTINUE.
-- It limits only the eager preload; ordinary play may still create or load
-- map data on demand. OFF skips the preload, FULL has no byte ceiling.

local V = ...
local ModSetting = V.require("ModSetting")

local RamPrecache = {}

RamPrecache.setting = ModSetting.new(
  "ramPrecacheMb", "RAM PRECACHE MB",
  { 256, 512, 768, 1024, 1536, 2048, 2560, 3072, false, 0 },
  { "256", "512", "768", "1024", "1536", "2048", "2560", "3072",
    "FULL", "OFF" })

function RamPrecache.bytes()
  local mb = RamPrecache.setting:get()
  if mb == false then return nil end -- nil means uncapped/FULL
  if tonumber(mb) == 0 then
    -- Phosphor/iOS has been reliable with 1.9.6's pre-game full compressed
    -- preload, but can terminate while mod.storage is read and decompressed
    -- during the first Pallet -> Route 1 transition. OFF is the explicit
    -- compatibility choice there: retain its label/save value while routing
    -- CONTINUE through that proven full preload. Other platforms keep the
    -- ordinary on-demand OFF behavior.
    local ok, Voxel3D = pcall(V.require, "Voxel3D")
    if ok and Voxel3D and Voxel3D.metalRenderer then
      local detected, ios = pcall(Voxel3D.metalRenderer)
      if detected and ios then return nil end
    end
  end
  return math.max(0, tonumber(mb) or 0) * 1024 * 1024
end

-- Match the overworld's ordinary connection neighborhood: saved map first,
-- then direct connections, then connections of connections. Direction order
-- is fixed so identical saves always produce the same disk-read order.
function RamPrecache.priorityMaps(data, rootId, hops)
  local maps = data and data.maps or {}
  if type(rootId) ~= "string" or not maps[rootId] then return {} end
  hops = math.max(0, math.floor(tonumber(hops) or 2))
  local out, seen = { rootId }, { [rootId] = true }
  local queue, index = { { id = rootId, depth = 0 } }, 1
  local directions = { "north", "south", "west", "east" }
  while queue[index] do
    local item = queue[index]
    index = index + 1
    if item.depth < hops then
      local connections = maps[item.id].connections or {}
      local ordered, named = {}, {}
      for _, direction in ipairs(directions) do
        local connection = connections[direction]
        if connection then
          ordered[#ordered + 1] = connection
          named[direction] = true
        end
      end
      local extra = {}
      for name in pairs(connections) do
        if not named[name] then extra[#extra + 1] = name end
      end
      table.sort(extra)
      for _, name in ipairs(extra) do
        ordered[#ordered + 1] = connections[name]
      end
      for _, connection in ipairs(ordered) do
        local id = connection and connection.map
        if maps[id] and not seen[id] then
          seen[id] = true
          out[#out + 1] = id
          queue[#queue + 1] = { id = id, depth = item.depth + 1 }
        end
      end
    end
  end
  return out
end

return RamPrecache
