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
local MAX_WORLD_COORDINATE = 65536
local MAX_LOCAL_COORDINATE = 256
local MAX_ROTATION = math.pi * 2
local MAX_SCALE = 64
local MAX_DIMENSION = 4096
local MAX_COMMAND_DIMENSION = 256
local MAX_GEOMETRY_COMMANDS = 64
local MAX_TEXT_COMMANDS = 4
local MAX_TEXT_BYTES = 64
local MAX_COMMAND_PRIMITIVES = 2048

local REPLACEMENT_KEYS = {
  schemaVersion = true, kind = true, objectId = true,
  geometry = true, text = true,
}
local GEOMETRY_KEYS = {
  shape = true, position = true, rotation = true, scale = true,
  pivot = true, dimensions = true, material = true,
}
local TEXT_KEYS = {
  value = true, encoding = true, position = true, rotation = true,
  scale = true, orientation = true, align = true, material = true,
}
local VECTOR_KEYS = { x = true, y = true, z = true }
local ROTATION_KEYS = { yaw = true, pitch = true, roll = true }
local DIMENSION_KEYS = { width = true, height = true, depth = true }
local PLANE_DIMENSION_KEYS = { width = true, height = true }
local MATERIAL_KEYS = { color = true }

-- Fixed host-owned 5x7 glyph rows. Each number is one five-bit scanline.
-- The public command accepts only keys in this table, so text never resolves a
-- font, texture, file, model, or other external resource.
local GLYPHS = {
  [" "] = { 0, 0, 0, 0, 0, 0, 0 },
  A = { 14, 17, 17, 31, 17, 17, 17 },
  B = { 30, 17, 17, 30, 17, 17, 30 },
  C = { 14, 17, 16, 16, 16, 17, 14 },
  D = { 30, 17, 17, 17, 17, 17, 30 },
  E = { 31, 16, 16, 30, 16, 16, 31 },
  F = { 31, 16, 16, 30, 16, 16, 16 },
  G = { 14, 17, 16, 23, 17, 17, 15 },
  H = { 17, 17, 17, 31, 17, 17, 17 },
  I = { 31, 4, 4, 4, 4, 4, 31 },
  J = { 7, 2, 2, 2, 18, 18, 12 },
  K = { 17, 18, 20, 24, 20, 18, 17 },
  L = { 16, 16, 16, 16, 16, 16, 31 },
  M = { 17, 27, 21, 21, 17, 17, 17 },
  N = { 17, 25, 21, 19, 17, 17, 17 },
  O = { 14, 17, 17, 17, 17, 17, 14 },
  P = { 30, 17, 17, 30, 16, 16, 16 },
  Q = { 14, 17, 17, 17, 21, 18, 13 },
  R = { 30, 17, 17, 30, 20, 18, 17 },
  S = { 15, 16, 16, 14, 1, 1, 30 },
  T = { 31, 4, 4, 4, 4, 4, 4 },
  U = { 17, 17, 17, 17, 17, 17, 14 },
  V = { 17, 17, 17, 17, 17, 10, 4 },
  W = { 17, 17, 17, 21, 21, 21, 10 },
  X = { 17, 17, 10, 4, 10, 17, 17 },
  Y = { 17, 17, 10, 4, 4, 4, 4 },
  Z = { 31, 1, 2, 4, 8, 16, 31 },
  ["0"] = { 14, 17, 19, 21, 25, 17, 14 },
  ["1"] = { 4, 12, 4, 4, 4, 4, 14 },
  ["2"] = { 14, 17, 1, 2, 4, 8, 31 },
  ["3"] = { 30, 1, 1, 14, 1, 1, 30 },
  ["4"] = { 2, 6, 10, 18, 31, 2, 2 },
  ["5"] = { 31, 16, 16, 30, 1, 1, 30 },
  ["6"] = { 14, 16, 16, 30, 17, 17, 14 },
  ["7"] = { 31, 1, 2, 4, 8, 8, 8 },
  ["8"] = { 14, 17, 17, 14, 17, 17, 14 },
  ["9"] = { 14, 17, 17, 15, 1, 1, 14 },
  ["-"] = { 0, 0, 0, 31, 0, 0, 0 },
  ["."] = { 0, 0, 0, 0, 0, 12, 12 },
  [":"] = { 0, 12, 12, 0, 12, 12, 0 },
  ["'"] = { 12, 12, 8, 0, 0, 0, 0 },
  ["/"] = { 1, 2, 2, 4, 8, 8, 16 },
  ["&"] = { 12, 18, 20, 8, 21, 18, 13 },
}

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

local function knownKeys(value, allowed, path)
  if type(value) ~= "table" or getmetatable(value) ~= nil then
    return nil, path .. " must be a plain table"
  end
  for key in pairs(value) do
    if type(key) ~= "string" or not allowed[key] then
      return nil, path .. " contains an unsupported field"
    end
  end
  return true
end

local function boundedNumber(value, minimum, maximum, path)
  if not finite(value) or value < minimum or value > maximum then
    return nil, path .. " is outside its finite range"
  end
  return value
end

local function vector3(value, keys, minimum, maximum, path)
  local ok, err = knownKeys(value, keys, path)
  if not ok then return nil, err end
  local names = keys == ROTATION_KEYS and { "yaw", "pitch", "roll" }
    or { "x", "y", "z" }
  local out = {}
  for _, name in ipairs(names) do
    local number
    number, err = boundedNumber(value[name], minimum, maximum,
      path .. "." .. name)
    if number == nil then return nil, err end
    out[name] = number
  end
  return out
end

local function positiveVector(value, maximum, path)
  local out, err = vector3(value, VECTOR_KEYS, 0, maximum, path)
  if not out then return nil, err end
  for _, name in ipairs({ "x", "y", "z" }) do
    if out[name] <= 0 then return nil, path .. "." .. name .. " must be positive" end
  end
  return out
end

local function dimensions(value, path, shape)
  local keys = shape == "plane" and PLANE_DIMENSION_KEYS or DIMENSION_KEYS
  local ok, err = knownKeys(value, keys, path)
  if not ok then return nil, err end
  local out = {}
  local names = shape == "plane" and { "width", "height" }
    or { "width", "height", "depth" }
  for _, name in ipairs(names) do
    local number
    number, err = boundedNumber(value[name], 0, MAX_COMMAND_DIMENSION,
      path .. "." .. name)
    if number == nil then return nil, err end
    if number <= 0 then return nil, path .. "." .. name .. " must be positive" end
    out[name] = number
  end
  if shape == "plane" then out.depth = 0 end
  return out
end

local function material(value, path)
  local ok, err = knownKeys(value, MATERIAL_KEYS, path)
  if not ok then return nil, err end
  local count
  count, err = denseCount(value.color, path .. ".color", 4)
  if not count then return nil, err end
  if count ~= 4 then return nil, path .. ".color must have four RGBA channels" end
  local color = {}
  for index = 1, 4 do
    local channel
    channel, err = boundedNumber(value.color[index], 0, 1,
      ("%s.color[%d]"):format(path, index))
    if channel == nil then return nil, err end
    color[index] = channel
  end
  if color[4] ~= 1 then return nil, path .. ".color alpha must be 1" end
  return { color = color }
end

local function commandTransform(value, path)
  local position, err = vector3(value.position, VECTOR_KEYS,
    -MAX_LOCAL_COORDINATE, MAX_LOCAL_COORDINATE, path .. ".position")
  if not position then return nil, err end
  local rotation
  rotation, err = vector3(value.rotation, ROTATION_KEYS,
    -MAX_ROTATION, MAX_ROTATION, path .. ".rotation")
  if not rotation then return nil, err end
  local scale
  scale, err = positiveVector(value.scale, MAX_SCALE, path .. ".scale")
  if not scale then return nil, err end
  return position, rotation, scale
end

local function glyphPrimitiveCount(text, path)
  if type(text) ~= "string" or #text < 1 or #text > MAX_TEXT_BYTES then
    return nil, path .. " must be 1..64 ASCII bytes"
  end
  local count = 0
  for index = 1, #text do
    local character = text:sub(index, index)
    local rows = GLYPHS[character]
    if not rows then
      return nil, path .. " accepts only A-Z, 0-9, space, - . : ' / and &"
    end
    for row = 1, 7 do
      local bits = rows[row]
      for column = 0, 4 do
        if math.floor(bits / 2 ^ column) % 2 == 1 then count = count + 1 end
      end
    end
  end
  if count == 0 then return nil, path .. " must contain a visible glyph" end
  return count
end

local function transformedReach(descriptor, position, xSpan, ySpan, zSpan)
  local localReach = math.abs(position.x) + math.abs(position.y)
    + math.abs(position.z) + xSpan + ySpan + zSpan
  local scale = descriptor.transform.scale
  local scaleMax = math.max(scale.x, scale.y, scale.z)
  local world = descriptor.transform.worldPosition
  return math.max(math.abs(world.x), math.abs(world.y), math.abs(world.z))
    + localReach * scaleMax
end

local function validateGeometryItem(value, path, descriptor)
  local ok, err = knownKeys(value, GEOMETRY_KEYS, path)
  if not ok then return nil, err end
  if value.shape ~= "box" and value.shape ~= "plane" then
    return nil, path .. ".shape must be box or plane"
  end
  if value.pivot ~= "center" and value.pivot ~= "bottom_center" then
    return nil, path .. ".pivot must be center or bottom_center"
  end
  if value.shape == "plane" and value.pivot ~= "center" then
    return nil, path .. ".pivot must be center for plane geometry"
  end
  local position, rotation, scale = commandTransform(value, path)
  if not position then return nil, rotation end
  local size
  size, err = dimensions(value.dimensions, path .. ".dimensions", value.shape)
  if not size then return nil, err end
  local surface
  surface, err = material(value.material, path .. ".material")
  if not surface then return nil, err end
  local xSpan = size.width * scale.x
  local ySpan = size.height * scale.y
  local zSpan = size.depth * scale.z
  if xSpan > MAX_COMMAND_DIMENSION or ySpan > MAX_COMMAND_DIMENSION
      or zSpan > MAX_COMMAND_DIMENSION then
    return nil, path .. " scaled dimensions exceed the command bound"
  end
  if transformedReach(descriptor, position, xSpan, ySpan, zSpan)
      > MAX_WORLD_COORDINATE then
    return nil, path .. " exceeds the transformed world bound"
  end
  return {
    shape = value.shape, position = position, rotation = rotation,
    scale = scale, pivot = value.pivot, dimensions = size, material = surface,
  }
end

local function validateTextItem(value, path, descriptor)
  local ok, err = knownKeys(value, TEXT_KEYS, path)
  if not ok then return nil, err end
  if value.encoding ~= "ascii-5x7" then
    return nil, path .. ".encoding must be ascii-5x7"
  end
  if value.orientation ~= "object" and value.orientation ~= "billboard_yaw" then
    return nil, path .. ".orientation must be object or billboard_yaw"
  end
  if value.align ~= "left" and value.align ~= "center"
      and value.align ~= "right" then
    return nil, path .. ".align must be left, center, or right"
  end
  local position, rotation, scale = commandTransform(value, path)
  if not position then return nil, rotation end
  if value.orientation == "billboard_yaw"
      and (rotation.pitch ~= 0 or rotation.roll ~= 0) then
    return nil, path .. " billboard_yaw requires zero pitch and roll"
  end
  local surface
  surface, err = material(value.material, path .. ".material")
  if not surface then return nil, err end
  local primitiveCount
  primitiveCount, err = glyphPrimitiveCount(value.value, path .. ".value")
  if not primitiveCount then return nil, err end
  local width = (#value.value * 6 - 1) * scale.x
  local height, depth = 7 * scale.y, 0.125 * scale.z
  if width > MAX_COMMAND_DIMENSION or height > MAX_COMMAND_DIMENSION
      or depth > MAX_COMMAND_DIMENSION then
    return nil, path .. " scaled text exceeds the command bound"
  end
  if transformedReach(descriptor, position, width, height, depth)
      > MAX_WORLD_COORDINATE then
    return nil, path .. " exceeds the transformed world bound"
  end
  return {
    value = value.value, encoding = value.encoding, position = position,
    rotation = rotation, scale = scale, orientation = value.orientation,
    align = value.align, material = surface,
  }, primitiveCount
end

local function requireFiniteFields(value, fields, path, positive)
  if type(value) ~= "table" or getmetatable(value) ~= nil then
    return nil, path .. " must be a plain table"
  end
  for _, field in ipairs(fields) do
    local number = value[field]
    if not finite(number) then
      return nil, path .. "." .. field .. " must be finite"
    end
    if positive and number <= 0 then
      return nil, path .. "." .. field .. " must be positive"
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
  if math.abs(map.offsetX) > MAX_WORLD_COORDINATE
      or math.abs(map.offsetZ) > MAX_WORLD_COORDINATE then
    return nil, path .. ".map offsets exceed the world bound"
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
  for _, field in ipairs({ "localPosition", "worldPosition" }) do
    for _, axis in ipairs({ "x", "y", "z" }) do
      if math.abs(value.transform[field][axis]) > MAX_WORLD_COORDINATE then
        return nil, path .. ".transform." .. field .. " exceeds the world bound"
      end
    end
  end
  for _, axis in ipairs({ "yaw", "pitch", "roll" }) do
    if math.abs(value.transform.rotation[axis]) > MAX_ROTATION then
      return nil, path .. ".transform.rotation exceeds the rotation bound"
    end
  end
  for _, axis in ipairs({ "x", "y", "z" }) do
    if value.transform.scale[axis] > MAX_SCALE then
      return nil, path .. ".transform.scale exceeds the scale bound"
    end
  end
  if type(value.pivot) ~= "table" or value.pivot.kind ~= "bottom_center" then
    return nil, path .. ".pivot must use bottom_center"
  end
  local ok
  ok, err = requireFiniteFields(value.pivot, { "x", "y", "z" },
    path .. ".pivot", false)
  if not ok then return nil, err end
  for _, axis in ipairs({ "x", "y", "z" }) do
    if math.abs(value.pivot[axis]) > MAX_LOCAL_COORDINATE then
      return nil, path .. ".pivot exceeds the local bound"
    end
  end
  ok, err = requireFiniteFields(value.dimensions,
    { "width", "height", "depth" }, path .. ".dimensions", true)
  if not ok then return nil, err end
  for _, field in ipairs({ "width", "height", "depth" }) do
    if value.dimensions[field] > MAX_DIMENSION then
      return nil, path .. ".dimensions exceeds the dimension bound"
    end
  end
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

-- Validate and normalize one callback-borrowed visual replacement command.
-- The result contains only copied scalar tables. It is used only for the
-- current draw call and is never retained by the registry.
function Visual.validateReplacementCommand(value, descriptor)
  local ok, err = knownKeys(value, REPLACEMENT_KEYS,
    "visual object replacement")
  if not ok then return nil, err end
  if value.schemaVersion ~= 1 then
    return nil, "visual object replacement.schemaVersion must be 1"
  end
  if value.kind ~= "visual_object_replacement" then
    return nil, "visual object replacement.kind must be visual_object_replacement"
  end
  local id
  id, err = safeId(value.objectId, "visual object replacement.objectId")
  if not id then return nil, err end
  if type(descriptor) ~= "table" or descriptor.id ~= id then
    return nil, "visual object replacement needs its current claimed descriptor"
  end

  local geometryCount
  geometryCount, err = denseCount(value.geometry,
    "visual object replacement.geometry", MAX_GEOMETRY_COMMANDS)
  if not geometryCount then return nil, err end
  local textCount
  textCount, err = denseCount(value.text,
    "visual object replacement.text", MAX_TEXT_COMMANDS)
  if not textCount then return nil, err end
  if geometryCount + textCount < 1 then
    return nil, "visual object replacement must contain geometry or text"
  end

  local out = {
    schemaVersion = 1, kind = value.kind, objectId = id,
    geometry = {}, text = {},
  }
  local primitiveCount = 0
  for index = 1, geometryCount do
    local item
    item, err = validateGeometryItem(value.geometry[index],
      ("visual object replacement.geometry[%d]"):format(index), descriptor)
    if not item then return nil, err end
    out.geometry[index] = item
    primitiveCount = primitiveCount + 1
  end
  for index = 1, textCount do
    local item, glyphs
    item, glyphs = validateTextItem(value.text[index],
      ("visual object replacement.text[%d]"):format(index), descriptor)
    if not item then return nil, glyphs end
    out.text[index] = item
    primitiveCount = primitiveCount + glyphs
  end
  if primitiveCount > MAX_COMMAND_PRIMITIVES then
    return nil, "visual object replacement exceeds its primitive limit"
  end
  return out, primitiveCount
end

function Visual.glyph(character)
  return GLYPHS[character]
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

function Registry:ownedDescriptor(record, id)
  if not self.records[record] or self.owners[id] ~= record then
    return nil, "visual object replacement requires the current unique owner"
  end
  local descriptor = self.catalog[id]
  if not descriptor then
    return nil, "visual object replacement descriptor is no longer current"
  end
  return descriptor
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
Visual.MAX_COMMAND_PRIMITIVES = MAX_COMMAND_PRIMITIVES

return Visual
