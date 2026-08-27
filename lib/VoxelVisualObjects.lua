-- Battle Art's optional visual-object extension to the byte-frozen
-- Voxel Companion API v1 dispatcher.
--
-- This module owns only copied declarative descriptors and unique owner IDs.
-- It never exposes or retains a terrain mesh, texture, map, or draw context.

local Visual = {}

local MAX_ID = 128
local MAX_OBJECTS = 4096
local MAX_CLAIMS = 4096
local MAX_COPY_NODES = 262144
local MAX_COPY_DEPTH = 16

local function finite(value)
  return type(value) == "number" and value == value
    and value ~= math.huge and value ~= -math.huge
end

local function integer(value)
  return finite(value) and value == math.floor(value)
end

local function safeId(value, path)
  if type(value) ~= "string" or value == "" or #value > MAX_ID
      or not value:match("^[A-Za-z0-9][A-Za-z0-9%._:%-]*$") then
    return nil, path .. " must use safe ASCII identifier characters"
  end
  return value
end

local function safeSegment(value)
  return type(value) == "string" and value ~= "" and #value <= MAX_ID
    and value:match("^[A-Za-z0-9][A-Za-z0-9%._%-]*$") ~= nil
end

function Visual.id(hostId, kind, mapId, cellX, cellZ)
  if not safeSegment(hostId) or not safeSegment(kind) or not safeSegment(mapId) then
    return nil, "visual object identity contains an unsafe segment"
  end
  if not integer(cellX) or not integer(cellZ) then
    return nil, "visual object cell coordinates must be integers"
  end
  local id = table.concat({ hostId, kind, mapId, cellX, cellZ }, ":")
  if #id > MAX_ID then return nil, "visual object id is too long" end
  return id
end

local function copyDeclarative(value, path, state, depth)
  local kind = type(value)
  if kind == "nil" or kind == "boolean" or kind == "string" then return value end
  if kind == "number" then
    if finite(value) then return value end
    return nil, path .. " contains a non-finite number"
  end
  if kind ~= "table" or getmetatable(value) ~= nil then
    return nil, path .. " must contain only plain declarative data"
  end
  if depth > MAX_COPY_DEPTH then return nil, path .. " is too deeply nested" end
  if state.seen[value] then return nil, path .. " contains a cycle or alias" end
  state.seen[value] = true
  local out = {}
  for key, item in pairs(value) do
    state.nodes = state.nodes + 1
    if state.nodes > MAX_COPY_NODES then
      state.seen[value] = nil
      return nil, path .. " is too large"
    end
    local keyKind = type(key)
    if keyKind ~= "string" and not (keyKind == "number" and integer(key)) then
      state.seen[value] = nil
      return nil, path .. " contains an unsupported key"
    end
    local copied, err = copyDeclarative(item,
      path .. "." .. tostring(key), state, depth + 1)
    if err then state.seen[value] = nil; return nil, err end
    out[key] = copied
  end
  state.seen[value] = nil
  return out
end

function Visual.copy(value, path)
  return copyDeclarative(value, path or "visual data",
    { seen = {}, nodes = 0 }, 0)
end

local function denseCount(value, path, maximum)
  if type(value) ~= "table" or getmetatable(value) ~= nil then
    return nil, path .. " must be an array"
  end
  local count = #value
  if count > maximum then return nil, path .. " exceeds its item limit" end
  for key in pairs(value) do
    if not integer(key) or key < 1 or key > count then
      return nil, path .. " must be a dense array"
    end
  end
  return count
end

local function requireFiniteFields(value, fields, path, positive)
  if type(value) ~= "table" or getmetatable(value) ~= nil then
    return nil, path .. " must be a plain table"
  end
  for _, field in ipairs(fields) do
    local number = value[field]
    if not finite(number) or (positive and number <= 0) then
      return nil, path .. "." .. field .. " must be finite"
    end
  end
  return true
end

local function validateDescriptor(value, path)
  if type(value) ~= "table" or getmetatable(value) ~= nil then
    return nil, path .. " must be a plain table"
  end
  if value.schemaVersion ~= 1 then return nil, path .. ".schemaVersion must be 1" end
  local id, err = safeId(value.id, path .. ".id")
  if not id then return nil, err end
  if type(value.kind) ~= "string" or value.kind == "" then
    return nil, path .. ".kind must be text"
  end
  local tagCount
  tagCount, err = denseCount(value.tags, path .. ".tags", 32)
  if not tagCount then return nil, err end
  local tags = {}
  for index = 1, tagCount do
    local tag = value.tags[index]
    if type(tag) ~= "string" or tag == "" or #tag > 64 then
      return nil, path .. ".tags contains invalid text"
    end
    if tags[tag] then return nil, path .. ".tags contains a duplicate" end
    tags[tag] = true
  end
  local map = value.map
  if type(map) ~= "table" or not safeSegment(map.id) then
    return nil, path .. ".map.id is invalid"
  end
  if map.role ~= "current" and map.role ~= "neighbor" then
    return nil, path .. ".map.role must be current or neighbor"
  end
  if not finite(map.offsetX) or not finite(map.offsetZ) then
    return nil, path .. ".map offsets must be finite"
  end
  if type(value.cell) ~= "table" or not integer(value.cell.x)
      or not integer(value.cell.z) then
    return nil, path .. ".cell coordinates must be integers"
  end
  if type(value.transform) ~= "table" then
    return nil, path .. ".transform must be a plain table"
  end
  for _, field in ipairs({ "localPosition", "worldPosition", "rotation", "scale" }) do
    local keys = field == "rotation" and { "yaw", "pitch", "roll" }
      or { "x", "y", "z" }
    local ok
    ok, err = requireFiniteFields(value.transform[field], keys,
      path .. ".transform." .. field, field == "scale")
    if not ok then return nil, err end
  end
  if type(value.pivot) ~= "table" or value.pivot.kind ~= "bottom_center" then
    return nil, path .. ".pivot must use bottom_center"
  end
  local ok
  ok, err = requireFiniteFields(value.pivot, { "x", "y", "z" },
    path .. ".pivot", false)
  if not ok then return nil, err end
  ok, err = requireFiniteFields(value.dimensions,
    { "width", "height", "depth" }, path .. ".dimensions", true)
  if not ok then return nil, err end
  local material = value.material
  if type(material) ~= "table" or type(material.id) ~= "string"
      or material.id == "" then
    return nil, path .. ".material.id must be text"
  end
  if material.phase ~= "opaque_after_terrain" then
    return nil, path .. ".material.phase must be opaque_after_terrain"
  end
  for _, field in ipairs({ "opaque", "alphaCutout", "castsShadow",
                            "receivesShadow" }) do
    if type(material[field]) ~= "boolean" then
      return nil, path .. ".material." .. field .. " must be Boolean"
    end
  end
  return Visual.copy(value, path)
end

local Registry = {}
Registry.__index = Registry

function Visual.new(options)
  options = options or {}
  return setmetatable({
    catalog = {}, order = {}, owners = {}, records = {},
    claimAllowed = options.claimAllowed,
  }, Registry)
end

function Registry:addRecord(id, eligible)
  local record = { id = id, eligible = eligible == true, claims = nil }
  self.records[record] = true
  return record
end

function Registry:setCatalog(descriptors)
  local count, err = denseCount(descriptors, "visual objects", MAX_OBJECTS)
  if not count then return nil, err end
  local byId, order = {}, {}
  for index = 1, count do
    local descriptor
    descriptor, err = validateDescriptor(descriptors[index],
      ("visual objects[%d]"):format(index))
    if not descriptor then return nil, err end
    if byId[descriptor.id] then
      return nil, "visual object catalog contains duplicate id " .. descriptor.id
    end
    byId[descriptor.id] = descriptor
    order[#order + 1] = descriptor
  end
  table.sort(order, function(a, b) return a.id < b.id end)

  local owners = {}
  for record in pairs(self.records) do
    if record.claims then
      local retained = {}
      for id in pairs(record.claims) do
        if byId[id] then retained[id], owners[id] = true, record end
      end
      record.claims = next(retained) and retained or nil
    end
  end
  self.catalog, self.order, self.owners = byId, order, owners
  return true
end

function Registry:claim(record, ids)
  if not self.records[record] then
    return nil, "extension cannot claim visual objects in its current state"
  end
  if self.claimAllowed then
    local allowed, err = self.claimAllowed(record)
    if not allowed then return nil, err end
  end
  if not record.eligible then
    return nil, "visual object claims require an opaque_after_terrain render handler"
  end
  local count, err = denseCount(ids, "visual object claims", MAX_CLAIMS)
  if not count then return nil, err end
  local proposed = {}
  for index = 1, count do
    local id
    id, err = safeId(ids[index], ("visual object claims[%d]"):format(index))
    if not id then return nil, err end
    if proposed[id] then
      return nil, "visual object claims contains duplicate id " .. id
    end
    if not self.catalog[id] then
      return nil, "unknown visual object id " .. id
    end
    proposed[id] = true
  end

  local conflicts = {}
  for id in pairs(proposed) do
    local owner = self.owners[id]
    if owner and owner ~= record then
      local pair = { owner.id, record.id }
      table.sort(pair)
      conflicts[#conflicts + 1] = id .. " [" .. table.concat(pair, ",") .. "]"
    end
  end
  table.sort(conflicts)
  if #conflicts > 0 then
    return nil, "visual object ownership conflict: " .. table.concat(conflicts, "; ")
  end

  for id in pairs(record.claims or {}) do
    if self.owners[id] == record then self.owners[id] = nil end
  end
  record.claims = next(proposed) and proposed or nil
  for id in pairs(proposed) do self.owners[id] = record end
  return true
end

function Registry:clear(record)
  if not self.records[record] then return false end
  for id in pairs(record.claims or {}) do
    if self.owners[id] == record then self.owners[id] = nil end
  end
  record.claims = nil
  return true
end

function Registry:remove(record)
  self:clear(record)
  self.records[record] = nil
end

function Registry:clearAll()
  for record in pairs(self.records) do self:clear(record) end
end

function Registry:dispose()
  self:clearAll()
  self.catalog, self.order, self.owners, self.records = {}, {}, {}, {}
end

function Registry:isSuppressed(id)
  return type(id) == "string" and self.owners[id] ~= nil or false
end

function Registry:owner(id)
  local record = type(id) == "string" and self.owners[id] or nil
  return record and record.id or nil
end

function Registry:status(record)
  local claims = 0
  for _ in pairs(record and record.claims or {}) do claims = claims + 1 end
  local owners = 0
  for _ in pairs(self.owners) do owners = owners + 1 end
  return { visualObjects = #self.order, visualOverrides = owners,
           visualClaims = claims, visualConflicts = 0 }
end

Visual.MAX_OBJECTS = MAX_OBJECTS
Visual.MAX_CLAIMS = MAX_CLAIMS

return Visual
