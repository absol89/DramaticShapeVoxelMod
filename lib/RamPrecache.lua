-- Session RAM budget for compressed voxel containers loaded at CONTINUE.
-- OFF generates only live areas and retains generated records in session RAM.
-- Other values permit persistent reads and predictive loading; FULL is uncapped.

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
  return math.max(0, tonumber(mb) or 0) * 1024 * 1024
end

function RamPrecache.off()
  return RamPrecache.bytes() == 0
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
