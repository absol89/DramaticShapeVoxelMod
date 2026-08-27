-- Voxel Companion API v1 reference dispatcher.
--
-- This module is pure Lua 5.1/LuaJIT. It does not require LÖVE, gen1recomp,
-- or a voxel renderer. Hosts own rendering and call this dispatcher at the
-- documented lifecycle and render seams.

local API = {
  VERSION = 1,
}

API.CAPABILITIES = {
  RENDER_PHASES = "render_phases",
  CAMERA_DELTA = "camera_delta",
  TERRAIN_PATCH = "terrain_patch",
  WORLD_SNAPSHOT = "world_snapshot",
  QUALITY_TIER = "quality_tier",
  SHADOW_PASS = "shadow_pass",
  BATTLE_PASS = "battle_pass",
  INTEGRITY_STATUS = "integrity_status",
}
-- Short aliases name capability-backed attach facades. Materials and draw are
-- normalized render services, not negotiated wire capabilities.
API.CAPABILITIES.WORLD = API.CAPABILITIES.WORLD_SNAPSHOT
API.CAPABILITIES.QUALITY = API.CAPABILITIES.QUALITY_TIER
API.CAPABILITIES.INTEGRITY = API.CAPABILITIES.INTEGRITY_STATUS

API.DRAW_SCHEMA_VERSION = 1
API.DRAW_KINDS = {
  MESH = "mesh",
  INSTANCES = "instances",
  BILLBOARDS = "billboards",
}

local STANDARD_CAPABILITY_SET = {
  render_phases = true,
  camera_delta = true,
  terrain_patch = true,
  world_snapshot = true,
  quality_tier = true,
  shadow_pass = true,
  battle_pass = true,
  integrity_status = true,
}

API.PHASES = {
  "update",
  "map_changed",
  "background",
  "opaque_after_terrain",
  "translucent_after_actors",
  "shadow_casters",
  "battle_opaque",
}

local PHASE_SET = {}
for _, phase in ipairs(API.PHASES) do PHASE_SET[phase] = true end

local RENDER_PHASE_SET = {
  background = true,
  opaque_after_terrain = true,
  translucent_after_actors = true,
  shadow_casters = true,
  battle_opaque = true,
}

local SERVICE_CAPABILITIES = {
  world_snapshot = "world",
  quality_tier = "quality",
  integrity_status = "integrity",
}

local TOP_LEVEL_SPEC_KEYS = {
  api = true,
  id = true,
  name = true,
  version = true,
  priority = true,
  requires = true,
  optional = true,
  attach = true,
  worldChanged = true,
  update = true,
  modifyCamera = true,
  terrainPatch = true,
  render = true,
  invalidate = true,
  dispose = true,
  lifecycle = true,
  phases = true,
  camera = true,
  terrain = true,
}

local LIFECYCLE_KEYS = {
  attach = true,
  start = true,
  invalidate = true,
  dispose = true,
}

local TERRAIN_RESULT_KEYS = {
  cacheKey = true,
  suppressCells = true,
  transforms = true,
  instances = true,
  tags = true,
  invalidate = true,
}

local CAMERA_RESULT_KEYS = {
  positionDelta = true,
  rotationDelta = true,
  fovDelta = true,
}

local POSITION_KEYS = { x = true, y = true, z = true }
local ROTATION_KEYS = { yaw = true, pitch = true, roll = true }

local MAX_ID_LENGTH = 128
local MAX_VERSION_LENGTH = 64
local MAX_CACHE_KEY_LENGTH = 512
local MAX_REQUIREMENTS = 64
local MAX_PATCH_ITEMS = 8192
local MAX_MERGED_PATCH_ITEMS = 32768
local MAX_DATA_DEPTH = 16
local MAX_DATA_NODES = 32768
local MAX_DATA_BYTES = 256 * 1024
local MAX_ERROR_MESSAGE_LENGTH = 4096
local MAX_DRAW_ITEMS = 8192
local MAX_DRAW_TEXT_LENGTH = 512
local MAX_DRAW_CACHE_KEY_LENGTH = 64

API.DRAW_LIMITS = {
  cacheKeyBytes = MAX_DRAW_CACHE_KEY_LENGTH,
  items = MAX_DRAW_ITEMS,
  dataDepth = MAX_DATA_DEPTH,
  dataNodes = MAX_DATA_NODES,
  dataBytes = MAX_DATA_BYTES,
}

local DRAW_KIND_SET = {
  mesh = true,
  instances = true,
  billboards = true,
}

local MESH_COMMAND_KEYS = {
  schemaVersion = true,
  cacheKey = true,
  kind = true,
  owner = true,
  phase = true,
  sequence = true,
  sortKey = true,
  material = true,
  color = true,
  texture = true,
  geometry = true,
  mesh = true,
  resource = true,
  model = true,
}

local INSTANCES_COMMAND_KEYS = {
  schemaVersion = true,
  cacheKey = true,
  kind = true,
  owner = true,
  phase = true,
  sequence = true,
  sortKey = true,
  material = true,
  color = true,
  texture = true,
  key = true,
  prototype = true,
  items = true,
}

local BILLBOARDS_COMMAND_KEYS = {
  schemaVersion = true,
  cacheKey = true,
  kind = true,
  owner = true,
  phase = true,
  sequence = true,
  sortKey = true,
  material = true,
  color = true,
  texture = true,
  key = true,
  items = true,
  procedural = true,
  animated = true,
}

local MESH_GEOMETRY_SCHEMAS = {
  box = {
    fields = { primitive = "text", x = "finite", y = "finite", z = "finite",
      width = "positive", height = "positive", depth = "positive" },
    required = { width = true, height = true, depth = true },
  },
  plane = {
    fields = { primitive = "text", x = "finite", y = "finite", z = "finite",
      width = "positive", depth = "positive" },
    required = { width = true, depth = true },
  },
  world_apron = {
    fields = { primitive = "text", width = "positive", depth = "positive",
      skirtDepth = "positive", neighbors = "plain" },
    required = { width = true, depth = true, skirtDepth = true },
  },
  panorama = {
    fields = { primitive = "text", sourceWidth = "positive",
      targetWidth = "positive", deepSkirt = "boolean", distanceHaze = "boolean" },
    required = { sourceWidth = true, targetWidth = true },
    needsTexture = true,
  },
  cloud_layer = {
    fields = { primitive = "text", layer = "positive_integer", parallax = "finite",
      density = "unit", seed = "finite" },
    required = { layer = true, parallax = true, density = true, seed = true },
    needsTexture = true,
  },
  rainbow = {
    fields = { primitive = "text", seed = "finite" },
    required = { seed = true },
  },
}

local INSTANCE_PROTOTYPE_SCHEMAS = {
  box = {
    fields = { primitive = "text", width = "positive", height = "positive",
      depth = "positive", cutaway = "boolean", role = "token" },
  },
  plane = {
    fields = { primitive = "text", width = "positive", depth = "positive",
      role = "token", alphaCutoff = "unit" },
  },
  door_frame = {
    fields = { primitive = "text", role = "token", double = "boolean" },
  },
  window = { fields = { primitive = "text", role = "token" } },
  poster = { fields = { primitive = "text", role = "token" }, needsTexture = true },
  rail = { fields = { primitive = "text", role = "token" } },
  fixture = { fields = { primitive = "text", role = "token" } },
  sconce = { fields = { primitive = "text", role = "token" } },
  grass_clump = {
    fields = { primitive = "text", width = "positive", wind = "token" },
  },
  canopy = {
    fields = { primitive = "text", width = "positive", cutaway = "boolean" },
  },
  vine = { fields = { primitive = "text", animated = "boolean" } },
  cave_roof = {
    fields = { primitive = "text", width = "positive", depth = "positive",
      role = "token" },
  },
  mountain = {
    fields = { primitive = "text", role = "token", shadow = "boolean" },
  },
  hood = {
    fields = { primitive = "text", role = "token", shadow = "boolean" },
  },
  umbrella = { fields = { primitive = "text" } },
}

local INSTANCE_ITEM_KEYS = {
  x = true,
  y = true,
  z = true,
  cellX = true,
  cellZ = true,
  side = true,
  facing = true,
  poster = true,
  seed = true,
  lift = true,
  summit = true,
  kind = true,
}

local BILLBOARD_ITEM_KEYS = {
  x = true,
  y = true,
  z = true,
  width = true,
  height = true,
  seed = true,
  extra = true,
}

local STAR_PROCEDURAL_KEYS = {
  kind = true,
  count = true,
  seed = true,
  twinkle = true,
  nebula = true,
  shootingStars = true,
}

local function is_finite(value)
  return type(value) == "number"
     and value == value
     and value ~= math.huge
     and value ~= -math.huge
end

local function is_integer(value)
  return is_finite(value) and value == math.floor(value)
end

local function pack(...)
  return { n = select("#", ...), ... }
end

local function safe_error_text(problem)
  local kind = type(problem)
  local message
  if kind == "string" then
    message = problem
  elseif kind == "number" or kind == "boolean" then
    message = tostring(problem)
  else
    message = "error value of type " .. kind
  end
  if #message > MAX_ERROR_MESSAGE_LENGTH then
    message = message:sub(1, MAX_ERROR_MESSAGE_LENGTH - 14) .. "...[truncated]"
  end
  return message
end

local function traceback_error(problem)
  local message = safe_error_text(problem)
  if debug and debug.traceback then return debug.traceback(message, 2) end
  return message
end

local function safe_key_label(key)
  local kind = type(key)
  if kind == "string" then
    local value = key
    if #value > 128 then value = value:sub(1, 128) .. "...[truncated]" end
    return value
  end
  if kind == "number" then return tostring(key) end
  if kind == "boolean" then return key and "true" or "false" end
  return "<" .. kind .. " key>"
end

local function safe_key_path(key)
  return "[" .. safe_key_label(key) .. "]"
end

local function copy_array(values)
  local out = {}
  for i = 1, #values do out[i] = values[i] end
  return out
end

local function sorted_keys(set)
  local out = {}
  for key in pairs(set) do out[#out + 1] = key end
  table.sort(out)
  return out
end

local function validate_known_keys(value, allowed, path)
  for key in pairs(value) do
    if not allowed[key] then
      return nil, ("%s has unknown field %s"):format(path, safe_key_label(key))
    end
  end
  return true
end

local function validate_dense_array(value, path, limit)
  if type(value) ~= "table" then
    return nil, path .. " must be an array"
  end
  if getmetatable(value) ~= nil then
    return nil, path .. " must not have a metatable"
  end

  local count, maximum = 0, 0
  for key in pairs(value) do
    if not is_integer(key) or key < 1 then
      return nil, path .. " must use positive integer indexes"
    end
    count = count + 1
    if key > maximum then maximum = key end
  end
  if count ~= maximum then
    return nil, path .. " must not contain holes"
  end
  if maximum > limit then
    return nil, ("%s exceeds its %d item limit"):format(path, limit)
  end
  return maximum
end

local function clone_declarative(value, path, state, depth)
  local kind = type(value)
  if kind == "string" then
    state.bytes = state.bytes + #value
    if state.bytes > MAX_DATA_BYTES then
      return nil, path .. " exceeds the maximum data byte size"
    end
    return value
  end
  if kind == "nil" or kind == "boolean" then return value end
  if kind == "number" then
    if not is_finite(value) then
      return nil, path .. " contains a non-finite number"
    end
    state.bytes = state.bytes + 8
    if state.bytes > MAX_DATA_BYTES then
      return nil, path .. " exceeds the maximum data byte size"
    end
    return value
  end
  if kind ~= "table" then
    return nil, ("%s contains unsupported %s data"):format(path, kind)
  end
  if getmetatable(value) ~= nil then
    return nil, path .. " contains a table with a metatable"
  end
  if depth >= MAX_DATA_DEPTH then
    return nil, path .. " exceeds the maximum data depth"
  end
  if state.active[value] then
    return nil, path .. " contains a cycle"
  end

  state.active[value] = true
  local out = {}
  for key, item in pairs(value) do
    state.nodes = state.nodes + 1
    if state.nodes > MAX_DATA_NODES then
      state.active[value] = nil
      return nil, path .. " exceeds the maximum data size"
    end

    local key_kind = type(key)
    if key_kind == "number" then
      if not is_integer(key) or key < 1 then
        state.active[value] = nil
        return nil, path .. " has an invalid numeric key"
      end
      state.bytes = state.bytes + 8
    elseif key_kind ~= "string" then
      state.active[value] = nil
      return nil, path .. " has a non-string, non-integer key"
    else
      state.bytes = state.bytes + #key
    end
    if state.bytes > MAX_DATA_BYTES then
      state.active[value] = nil
      return nil, path .. " exceeds the maximum data byte size"
    end

    local cloned, err = clone_declarative(
      item,
      path .. safe_key_path(key),
      state,
      depth + 1
    )
    if err then
      state.active[value] = nil
      return nil, err
    end
    out[key] = cloned
  end
  state.active[value] = nil
  return out
end

local function clone_data(value, path, state)
  state = state or { active = {}, nodes = 0, bytes = 0 }
  return clone_declarative(value, path, state, 0)
end

local function bounded_text(value, path, maximum)
  if type(value) ~= "string" or value == "" then
    return nil, path .. " must be a non-empty string"
  end
  if #value > maximum then
    return nil, ("%s must be at most %d bytes"):format(path, maximum)
  end
  if value:find("\0", 1, true) then return nil, path .. " must not contain NUL" end
  return value
end

local function looks_like_resource_path(value)
  if type(value) ~= "string" then return false end
  local lower = value:lower()
  if value:find("/", 1, true) or value:find("\\", 1, true)
      or value:match("^[A-Za-z][A-Za-z0-9+%.%-]*://") then
    return true
  end
  return lower:match("%.png$") ~= nil
    or lower:match("%.jpe?g$") ~= nil
    or lower:match("%.webp$") ~= nil
    or lower:match("%.mp3$") ~= nil
    or lower:match("%.ogg$") ~= nil
    or lower:match("%.wav$") ~= nil
    or lower:match("%.flac$") ~= nil
    or lower:match("%.glsl$") ~= nil
    or lower:match("%.obj$") ~= nil
    or lower:match("%.gltf$") ~= nil
    or lower:match("%.glb$") ~= nil
end

local function semantic_token(value, path, maximum)
  local text, err = bounded_text(value, path, maximum or MAX_DRAW_TEXT_LENGTH)
  if not text then return nil, err end
  if looks_like_resource_path(text) then
    return nil, path .. " must be a semantic identifier, not an asset or path string"
  end
  return text
end

local function validate_draw_cache_key(value)
  local key, err = bounded_text(
    value,
    "draw command.cacheKey",
    MAX_DRAW_CACHE_KEY_LENGTH
  )
  if not key then return nil, err end
  if not key:match("^[A-Za-z0-9%._:%-]+$") then
    return nil, "draw command.cacheKey can contain only A-Z, a-z, 0-9, dot, underscore, colon, and hyphen"
  end
  return true
end

local function locator_field(key)
  if type(key) ~= "string" then return false end
  local lower = key:lower()
  return lower:find("asset", 1, true) ~= nil
    or lower:find("path", 1, true) ~= nil
    or lower == "file"
    or lower == "filename"
    or lower == "uri"
    or lower == "url"
end

local function validate_no_resource_locator(value, path, active)
  local kind = type(value)
  if kind == "string" then
    if looks_like_resource_path(value) then
      return nil, path .. " contains an asset or path string"
    end
    return true
  end
  if kind ~= "table" then return true end
  active = active or {}
  if active[value] then return nil, path .. " contains a cycle" end
  active[value] = true
  for key, item in pairs(value) do
    if locator_field(key) then
      active[value] = nil
      return nil, path .. " contains forbidden resource locator field " .. safe_key_label(key)
    end
    local ok, err = validate_no_resource_locator(
      item,
      path .. safe_key_path(key),
      active
    )
    if not ok then active[value] = nil; return nil, err end
  end
  active[value] = nil
  return true
end

local function validate_plain_wire_data(value, path, state)
  local copy, err = clone_data(value, path, state)
  if err then return nil, err end
  local ok
  ok, err = validate_no_resource_locator(copy, path)
  if not ok then return nil, err end
  return true
end

local function validate_opaque_resource(value, path)
  if value == nil then return true end
  if type(value) == "string" then
    return nil, path .. " must be an opaque extension-owned resource, not an asset/path string"
  end
  local kind = type(value)
  if kind ~= "table" and kind ~= "userdata" and kind ~= "cdata" then
    return nil, path .. " must be an opaque extension-owned resource"
  end
  return true
end

local function validate_schema_field(value, rule, path, state)
  if rule == "finite" then
    if not is_finite(value) then return nil, path .. " must be finite" end
  elseif rule == "positive" then
    if not is_finite(value) or value <= 0 then return nil, path .. " must be positive" end
  elseif rule == "positive_integer" then
    if not is_integer(value) or value < 1 then return nil, path .. " must be a positive integer" end
  elseif rule == "unit" then
    if not is_finite(value) or value < 0 or value > 1 then
      return nil, path .. " must be from 0 through 1"
    end
  elseif rule == "boolean" then
    if type(value) ~= "boolean" then return nil, path .. " must be a Boolean" end
  elseif rule == "text" then
    return bounded_text(value, path, MAX_DRAW_TEXT_LENGTH)
  elseif rule == "token" then
    return semantic_token(value, path, MAX_DRAW_TEXT_LENGTH)
  elseif rule == "plain" then
    return validate_plain_wire_data(value, path, state)
  else
    return nil, path .. " has an unknown schema rule"
  end
  return true
end

local function validate_schema_table(value, schemas, path, state)
  if type(value) ~= "table" or getmetatable(value) ~= nil then
    return nil, path .. " must be a plain table"
  end
  local primitive = value.primitive
  if type(primitive) ~= "string" or primitive == "" then
    return nil, path .. ".primitive must be a non-empty string"
  end
  local schema = schemas[primitive]
  if not schema then
    return nil, path .. ".primitive is not in the API v1 baseline: " .. primitive
  end
  local allowed = {}
  for key in pairs(schema.fields) do allowed[key] = true end
  local ok, err = validate_known_keys(value, allowed, path)
  if not ok then return nil, err end
  for key in pairs(schema.required or {}) do
    if value[key] == nil then return nil, path .. "." .. key .. " is required" end
  end
  for key, rule in pairs(schema.fields) do
    if key ~= "primitive" and value[key] ~= nil then
      ok, err = validate_schema_field(value[key], rule, path .. "." .. key, state)
      if not ok then return nil, err end
    end
  end
  return schema
end

local function validate_color(value, path)
  if value == nil then return true end
  local count, err = validate_dense_array(value, path, 4)
  if not count then return nil, err end
  if count ~= 3 and count ~= 4 then return nil, path .. " must have 3 or 4 values" end
  for index = 1, count do
    local channel = value[index]
    if not is_finite(channel) or channel < 0 or channel > 1 then
      return nil, ("%s[%d] must be from 0 through 1"):format(path, index)
    end
  end
  return true
end

local function validate_instance_item(item, path, state)
  if type(item) ~= "table" or getmetatable(item) ~= nil then
    return nil, path .. " must be a plain table"
  end
  local ok, err = validate_known_keys(item, INSTANCE_ITEM_KEYS, path)
  if not ok then return nil, err end
  for _, key in ipairs({ "x", "y", "z" }) do
    if not is_finite(item[key]) then return nil, path .. "." .. key .. " must be finite" end
  end
  for _, key in ipairs({ "cellX", "cellZ" }) do
    if item[key] ~= nil and not is_integer(item[key]) then
      return nil, path .. "." .. key .. " must be an integer"
    end
  end
  for _, key in ipairs({ "seed", "lift" }) do
    if item[key] ~= nil and not is_finite(item[key]) then
      return nil, path .. "." .. key .. " must be finite"
    end
  end
  for _, key in ipairs({ "side", "facing", "kind" }) do
    if item[key] ~= nil then
      ok, err = semantic_token(item[key], path .. "." .. key, MAX_DRAW_TEXT_LENGTH)
      if not ok then return nil, err end
    end
  end
  if item.poster ~= nil then
    local kind = type(item.poster)
    if kind == "string" then
      ok, err = semantic_token(item.poster, path .. ".poster", MAX_DRAW_TEXT_LENGTH)
      if not ok then return nil, err end
    elseif kind ~= "number" or not is_finite(item.poster) then
      return nil, path .. ".poster must be a finite number or semantic identifier"
    end
  end
  if item.summit ~= nil and type(item.summit) ~= "boolean" then
    return nil, path .. ".summit must be a Boolean"
  end
  return true
end

local function validate_billboard_item(item, path, state)
  if type(item) ~= "table" or getmetatable(item) ~= nil then
    return nil, path .. " must be a plain table"
  end
  local ok, err = validate_known_keys(item, BILLBOARD_ITEM_KEYS, path)
  if not ok then return nil, err end
  for _, key in ipairs({ "x", "y", "z" }) do
    if not is_finite(item[key]) then return nil, path .. "." .. key .. " must be finite" end
  end
  for _, key in ipairs({ "width", "height" }) do
    if item[key] ~= nil and (not is_finite(item[key]) or item[key] <= 0) then
      return nil, path .. "." .. key .. " must be positive"
    end
  end
  if item.seed ~= nil and not is_finite(item.seed) then
    return nil, path .. ".seed must be finite"
  end
  if item.extra ~= nil then
    ok, err = validate_plain_wire_data(item.extra, path .. ".extra", state)
    if not ok then return nil, err end
  end
  return true
end

local function validate_draw_common(command, expected_kind)
  if type(command) ~= "table" or getmetatable(command) ~= nil then
    return nil, "draw command must be a plain table"
  end
  local kind = command.kind
  if not DRAW_KIND_SET[kind] then
    return nil, "draw command.kind is not in the API v1 baseline: " .. safe_key_label(kind)
  end
  if expected_kind ~= nil and expected_kind ~= kind then
    return nil, ("draw.%s received a %s command")
      :format(safe_key_label(expected_kind), safe_key_label(kind))
  end
  local allowed = kind == "mesh" and MESH_COMMAND_KEYS
    or (kind == "instances" and INSTANCES_COMMAND_KEYS or BILLBOARDS_COMMAND_KEYS)
  local ok, err = validate_known_keys(command, allowed, "draw command")
  if not ok then return nil, err end
  if command.schemaVersion ~= API.DRAW_SCHEMA_VERSION then
    return nil, ("draw command.schemaVersion must be %d"):format(API.DRAW_SCHEMA_VERSION)
  end
  ok, err = semantic_token(command.owner, "draw command.owner", MAX_ID_LENGTH)
  if not ok then return nil, err end
  if not RENDER_PHASE_SET[command.phase] then
    return nil, "draw command.phase must be a render phase"
  end
  if not is_integer(command.sequence) or command.sequence < 1 then
    return nil, "draw command.sequence must be a positive integer"
  end
  ok, err = validate_draw_cache_key(command.cacheKey)
  if not ok then return nil, err end
  ok, err = semantic_token(command.sortKey, "draw command.sortKey", MAX_DRAW_TEXT_LENGTH)
  if not ok then return nil, err end
  ok, err = semantic_token(command.material, "draw command.material", MAX_DRAW_TEXT_LENGTH)
  if not ok then return nil, err end
  ok, err = validate_color(command.color, "draw command.color")
  if not ok then return nil, err end
  ok, err = validate_opaque_resource(command.texture, "draw command.texture")
  if not ok then return nil, err end
  if command.key ~= nil then
    ok, err = semantic_token(command.key, "draw command.key", MAX_DRAW_TEXT_LENGTH)
    if not ok then return nil, err end
  end
  if command.animated ~= nil and type(command.animated) ~= "boolean" then
    return nil, "draw command.animated must be a Boolean"
  end
  return true
end

local function validate_draw_mesh(command, state)
  local direct_count = (command.mesh ~= nil and 1 or 0) + (command.resource ~= nil and 1 or 0)
  if direct_count > 1 then return nil, "mesh command cannot contain both mesh and resource" end
  if command.geometry ~= nil and direct_count > 0 then
    return nil, "mesh command cannot combine declarative geometry with an opaque mesh/resource"
  end
  if command.geometry == nil and direct_count == 0 then
    return nil, "mesh command needs geometry or one opaque mesh/resource"
  end
  if direct_count > 0 and command.texture ~= nil then
    return nil, "mesh command cannot combine an opaque mesh/resource with a texture"
  end
  local ok, err
  if direct_count > 0 then
    ok, err = validate_opaque_resource(command.mesh or command.resource, "mesh command resource")
    if not ok then return nil, err end
  else
    local schema
    schema, err = validate_schema_table(command.geometry, MESH_GEOMETRY_SCHEMAS,
      "mesh command.geometry", state)
    if not schema then return nil, err end
    if schema.needsTexture and command.texture == nil then
      return nil, "mesh command.texture is required for "
        .. tostring(command.geometry.primitive) .. " geometry"
    end
  end
  ok, err = validate_opaque_resource(command.model, "mesh command.model")
  if not ok then return nil, err end
  return true
end

local function validate_draw_instances(command, state)
  local schema, err = validate_schema_table(
    command.prototype,
    INSTANCE_PROTOTYPE_SCHEMAS,
    "instances command.prototype",
    state
  )
  if not schema then return nil, err end
  if schema.needsTexture and command.texture == nil then
    return nil, "instances command.texture is required for poster geometry"
  end
  local count
  count, err = validate_dense_array(command.items, "instances command.items", MAX_DRAW_ITEMS)
  if not count then return nil, err end
  if count < 1 then return nil, "instances command.items must not be empty" end
  for index = 1, count do
    local ok
    ok, err = validate_instance_item(
      command.items[index],
      ("instances command.items[%d]"):format(index),
      state
    )
    if not ok then return nil, err end
  end
  return true
end

local function validate_draw_billboards(command, state)
  local has_items = command.items ~= nil
  local has_procedural = command.procedural ~= nil
  if has_items == has_procedural then
    return nil, "billboards command needs exactly one of items or procedural"
  end
  local err
  if has_items then
    local count
    count, err = validate_dense_array(command.items, "billboards command.items", MAX_DRAW_ITEMS)
    if not count then return nil, err end
    if count < 1 then return nil, "billboards command.items must not be empty" end
    for index = 1, count do
      local ok
      ok, err = validate_billboard_item(
        command.items[index],
        ("billboards command.items[%d]"):format(index),
        state
      )
      if not ok then return nil, err end
    end
    return true
  end

  local procedural = command.procedural
  if type(procedural) ~= "table" or getmetatable(procedural) ~= nil then
    return nil, "billboards command.procedural must be a plain table"
  end
  local ok
  ok, err = validate_known_keys(procedural, STAR_PROCEDURAL_KEYS,
    "billboards command.procedural")
  if not ok then return nil, err end
  if procedural.kind ~= "stars" then
    return nil, "billboards command.procedural.kind must be stars"
  end
  if not is_integer(procedural.count) or procedural.count < 1
      or procedural.count > MAX_DRAW_ITEMS then
    return nil, ("billboards command.procedural.count must be from 1 through %d")
      :format(MAX_DRAW_ITEMS)
  end
  if not is_finite(procedural.seed) then
    return nil, "billboards command.procedural.seed must be finite"
  end
  for _, key in ipairs({ "twinkle", "nebula", "shootingStars" }) do
    if procedural[key] ~= nil and type(procedural[key]) ~= "boolean" then
      return nil, "billboards command.procedural." .. key .. " must be a Boolean"
    end
  end
  return true
end

-- Hosts call this pure validator, or an equivalent implementation, before
-- executing a draw facade command. It never changes or retains the command.
function API.validate_draw_command(command, expected_kind)
  if expected_kind ~= nil and not DRAW_KIND_SET[expected_kind] then
    return nil, "expected draw kind is not in the API v1 baseline"
  end
  local ok, err = validate_draw_common(command, expected_kind)
  if not ok then return nil, err end
  local state = { active = {}, nodes = 0, bytes = 0 }
  if command.kind == "mesh" then return validate_draw_mesh(command, state) end
  if command.kind == "instances" then return validate_draw_instances(command, state) end
  return validate_draw_billboards(command, state)
end

API.validateDrawCommand = API.validate_draw_command

-- LuaJIT 2.1 follows Lua 5.1 table semantics. It does not honor __pairs for
-- tables, so the lease intentionally protects named top-level fields only.
-- Nested facades and handles remain borrowed under the documented contract.
local function borrowed_view(source, label)
  local lease = { active = true }
  local proxy
  proxy = setmetatable({}, {
    __index = function(_, key)
      if not lease.active then
        error(label .. " is no longer valid", 2)
      end
      return source[key]
    end,
    __newindex = function()
      error(label .. " is read-only", 2)
    end,
    __metatable = "voxel-companion borrowed view",
  })

  local function close()
    lease.active = false
    local dirty_key = nil
    for key in next, proxy do
      if dirty_key == nil then dirty_key = key end
      rawset(proxy, key, nil)
    end
    if dirty_key ~= nil then
      return nil, ("%s was changed with rawset at field %s")
        :format(label, safe_key_label(dirty_key))
    end
    return true
  end

  return proxy, close
end

local function validate_draw_facade(draw, path)
  if type(draw) ~= "table" then
    return nil, path .. " must be a table"
  end
  for _, method in ipairs({ "mesh", "instances", "billboards" }) do
    if type(draw[method]) ~= "function" then
      return nil, ("%s.%s must be a function"):format(path, method)
    end
  end
  return true
end

local function validate_required_facades(services, requirements, path, uses_render_services)
  for capability in pairs(requirements) do
    local facade_name = SERVICE_CAPABILITIES[capability]
    if facade_name then
      local facade = services[facade_name]
      if type(facade) ~= "table" then
        return nil, ("%s.%s is required by capability %q")
          :format(path, facade_name, capability)
      end
    end
  end
  if uses_render_services then
    if type(services.materials) ~= "table" then
      return nil, path .. ".materials is required by a render handler"
    end
    local ok, err = validate_draw_facade(services.draw, path .. ".draw")
    if not ok then return nil, err end
  end
  return true
end

local function validate_render_context(context, path)
  for _, key in ipairs({ "world", "camera", "frame", "materials", "draw" }) do
    if type(context[key]) ~= "table" then
      return nil, ("%s.%s must be a borrowed table facade"):format(path, key)
    end
  end
  return validate_draw_facade(context.draw, path .. ".draw")
end

local function normalize_capability_list(value, path)
  if value == nil then return {}, {} end
  local count, err = validate_dense_array(value, path, MAX_REQUIREMENTS)
  if not count then return nil, err end

  local set, list = {}, {}
  for i = 1, count do
    local capability = value[i]
    if type(capability) ~= "string" or capability == "" then
      return nil, ("%s[%d] must be a non-empty string"):format(path, i)
    end
    if not STANDARD_CAPABILITY_SET[capability] then
      return nil, ("%s[%d] is not a standard API v1 capability: %q")
        :format(path, i, capability)
    end
    if set[capability] then
      return nil, ("%s contains duplicate %q"):format(path, capability)
    end
    set[capability] = true
    list[#list + 1] = capability
  end
  table.sort(list)
  return set, list
end

local function add_automatic_requirement(set, list, capability)
  if not set[capability] then
    set[capability] = true
    list[#list + 1] = capability
    table.sort(list)
  end
end

local function normalize_spec(spec, host_capabilities)
  if type(spec) ~= "table" then
    return nil, "extension must be a table"
  end
  local ok, err = validate_known_keys(spec, TOP_LEVEL_SPEC_KEYS, "extension")
  if not ok then return nil, err end
  if spec.api ~= API.VERSION then
    return nil, ("extension.api must be %d"):format(API.VERSION)
  end
  if type(spec.id) ~= "string"
     or #spec.id < 1
     or #spec.id > MAX_ID_LENGTH
     or not spec.id:match("^[A-Za-z0-9][A-Za-z0-9_.%-]*$") then
    return nil, "extension.id must be a stable 1-128 character identifier"
  end
  if spec.name ~= nil and (type(spec.name) ~= "string" or spec.name == "") then
    return nil, "extension.name must be a non-empty string when present"
  end
  if spec.version ~= nil
     and (type(spec.version) ~= "string"
          or spec.version == ""
          or #spec.version > MAX_VERSION_LENGTH) then
    return nil, "extension.version must be a 1-64 character string when present"
  end

  local priority = spec.priority or 0
  if not is_integer(priority) or priority < -100000 or priority > 100000 then
    return nil, "extension.priority must be an integer from -100000 to 100000"
  end

  local requirements, requirement_list = normalize_capability_list(
    spec.requires,
    "extension.requires"
  )
  if not requirements then return nil, requirement_list end
  local optional, optional_list = normalize_capability_list(
    spec.optional,
    "extension.optional"
  )
  if not optional then return nil, optional_list end
  for _, capability in ipairs(optional_list) do
    if requirements[capability] then
      return nil, ("capability %q cannot be both required and optional")
        :format(capability)
    end
  end

  local lifecycle = {}
  if spec.lifecycle ~= nil then
    if type(spec.lifecycle) ~= "table" then
      return nil, "extension.lifecycle must be a table"
    end
    ok, err = validate_known_keys(spec.lifecycle, LIFECYCLE_KEYS, "extension.lifecycle")
    if not ok then return nil, err end
    for name in pairs(LIFECYCLE_KEYS) do
      local handler = spec.lifecycle[name]
      if handler ~= nil and type(handler) ~= "function" then
        return nil, ("extension.lifecycle.%s must be a function"):format(name)
      end
      lifecycle[name] = handler
    end
  end
  for _, name in ipairs({ "attach", "invalidate", "dispose" }) do
    if spec[name] ~= nil and type(spec[name]) ~= "function" then
      return nil, ("extension.%s must be a function"):format(name)
    end
    if spec[name] ~= nil and lifecycle[name] ~= nil then
      return nil, ("extension.%s conflicts with extension.lifecycle.%s")
        :format(name, name)
    end
  end
  if spec.attach then lifecycle.attach = spec.attach end
  if spec.invalidate then
    local invalidate = spec.invalidate
    lifecycle.invalidate = function(_, reason) return invalidate(reason) end
  end
  if spec.dispose then
    local dispose = spec.dispose
    lifecycle.dispose = function() return dispose() end
  end

  local phases = {}
  local has_phase = false
  local uses_render_services = false
  if spec.phases ~= nil then
    if type(spec.phases) ~= "table" then
      return nil, "extension.phases must be a table"
    end
    ok, err = validate_known_keys(spec.phases, PHASE_SET, "extension.phases")
    if not ok then return nil, err end
    for _, phase in ipairs(API.PHASES) do
      local handler = spec.phases[phase]
      if handler ~= nil and type(handler) ~= "function" then
        return nil, ("extension.phases.%s must be a function"):format(phase)
      end
      if handler ~= nil then
        has_phase = true
        if RENDER_PHASE_SET[phase] then uses_render_services = true end
      end
      phases[phase] = handler
    end
  end

  if spec.render ~= nil then
    if type(spec.render) ~= "table" then
      return nil, "extension.render must be a table"
    end
    ok, err = validate_known_keys(spec.render, RENDER_PHASE_SET, "extension.render")
    if not ok then return nil, err end
    for phase in pairs(RENDER_PHASE_SET) do
      local handler = spec.render[phase]
      if handler ~= nil and type(handler) ~= "function" then
        return nil, ("extension.render.%s must be a function"):format(phase)
      end
      if handler ~= nil and phases[phase] ~= nil then
        return nil, ("extension.render.%s conflicts with extension.phases.%s")
          :format(phase, phase)
      end
      if handler ~= nil then
        phases[phase] = handler
        has_phase = true
        uses_render_services = true
      end
    end
  end

  for flat_name, phase in pairs({
    update = "update",
    worldChanged = "map_changed",
  }) do
    local handler = spec[flat_name]
    if handler ~= nil and type(handler) ~= "function" then
      return nil, ("extension.%s must be a function"):format(flat_name)
    end
    if handler ~= nil and phases[phase] ~= nil then
      return nil, ("extension.%s conflicts with extension.phases.%s")
        :format(flat_name, phase)
    end
    if handler ~= nil then
      phases[phase] = handler
      has_phase = true
    end
  end

  if spec.camera ~= nil and type(spec.camera) ~= "function" then
    return nil, "extension.camera must be a function"
  end
  if spec.modifyCamera ~= nil and type(spec.modifyCamera) ~= "function" then
    return nil, "extension.modifyCamera must be a function"
  end
  if spec.camera ~= nil and spec.modifyCamera ~= nil then
    return nil, "extension.modifyCamera conflicts with extension.camera"
  end
  if spec.terrain ~= nil and type(spec.terrain) ~= "function" then
    return nil, "extension.terrain must be a function"
  end
  if spec.terrainPatch ~= nil and type(spec.terrainPatch) ~= "function" then
    return nil, "extension.terrainPatch must be a function"
  end
  if spec.terrain ~= nil and spec.terrainPatch ~= nil then
    return nil, "extension.terrainPatch conflicts with extension.terrain"
  end
  local camera = spec.modifyCamera or spec.camera
  local terrain = spec.terrainPatch or spec.terrain

  if has_phase then
    add_automatic_requirement(requirements, requirement_list, "render_phases")
  end
  if phases.shadow_casters then
    add_automatic_requirement(requirements, requirement_list, "shadow_pass")
  end
  if phases.battle_opaque then
    add_automatic_requirement(requirements, requirement_list, "battle_pass")
  end
  if camera then
    add_automatic_requirement(requirements, requirement_list, "camera_delta")
  end
  if terrain then
    add_automatic_requirement(requirements, requirement_list, "terrain_patch")
  end

  local promoted_optional = {}
  for _, capability in ipairs(optional_list) do
    if requirements[capability] then
      optional[capability] = nil
    else
      promoted_optional[#promoted_optional + 1] = capability
    end
  end
  optional_list = promoted_optional

  for _, capability in ipairs(requirement_list) do
    if not host_capabilities[capability] then
      return nil, ("host does not provide required capability %q"):format(capability)
    end
  end

  local has_handler = camera ~= nil or terrain ~= nil or has_phase
  for _, handler in pairs(lifecycle) do
    if handler ~= nil then has_handler = true break end
  end
  if not has_handler then
    return nil, "extension must declare at least one handler"
  end

  return {
    source = spec,
    id = spec.id,
    name = spec.name or spec.id,
    version = spec.version,
    priority = priority,
    requirements = requirements,
    requirement_list = requirement_list,
    optional = optional,
    optional_list = optional_list,
    lifecycle = lifecycle,
    phases = phases,
    camera = camera,
    terrain = terrain,
    state = "registered",
    active = false,
    attached = false,
    started = false,
    faulted = false,
    dispose_called = false,
    uses_render_services = uses_render_services,
  }
end

local function validate_vector(value, allowed, path)
  if value == nil then
    local zero = {}
    for key in pairs(allowed) do zero[key] = 0 end
    return zero
  end
  if type(value) ~= "table" or getmetatable(value) ~= nil then
    return nil, path .. " must be a plain table"
  end
  local ok, err = validate_known_keys(value, allowed, path)
  if not ok then return nil, err end
  local out = {}
  for key in pairs(allowed) do
    local number = value[key]
    if number ~= nil and not is_finite(number) then
      return nil, ("%s.%s must be a finite number"):format(path, key)
    end
    out[key] = number or 0
  end
  return out
end

local function validate_camera_result(value)
  if value == nil then
    return {
      positionDelta = { x = 0, y = 0, z = 0 },
      rotationDelta = { yaw = 0, pitch = 0, roll = 0 },
      fovDelta = 0,
    }
  end
  if type(value) ~= "table" or getmetatable(value) ~= nil then
    return nil, "camera result must be a plain table or nil"
  end
  local ok, err = validate_known_keys(value, CAMERA_RESULT_KEYS, "camera result")
  if not ok then return nil, err end
  local position
  position, err = validate_vector(value.positionDelta, POSITION_KEYS, "camera result.positionDelta")
  if not position then return nil, err end
  local rotation
  rotation, err = validate_vector(value.rotationDelta, ROTATION_KEYS, "camera result.rotationDelta")
  if not rotation then return nil, err end
  local fov = value.fovDelta or 0
  if not is_finite(fov) then
    return nil, "camera result.fovDelta must be a finite number"
  end
  return {
    positionDelta = position,
    rotationDelta = rotation,
    fovDelta = fov,
  }
end

local function merge_camera_result(aggregate, contribution)
  local merged = {
    positionDelta = {
      x = aggregate.positionDelta.x + contribution.positionDelta.x,
      y = aggregate.positionDelta.y + contribution.positionDelta.y,
      z = aggregate.positionDelta.z + contribution.positionDelta.z,
    },
    rotationDelta = {
      yaw = aggregate.rotationDelta.yaw + contribution.rotationDelta.yaw,
      pitch = aggregate.rotationDelta.pitch + contribution.rotationDelta.pitch,
      roll = aggregate.rotationDelta.roll + contribution.rotationDelta.roll,
    },
    fovDelta = aggregate.fovDelta + contribution.fovDelta,
  }
  for _, value in ipairs({
    merged.positionDelta.x,
    merged.positionDelta.y,
    merged.positionDelta.z,
    merged.rotationDelta.yaw,
    merged.rotationDelta.pitch,
    merged.rotationDelta.roll,
    merged.fovDelta,
  }) do
    if not is_finite(value) then
      return nil, "camera contribution would make the aggregate non-finite"
    end
  end
  return merged
end

local function patch_entry_key(entry, path, allow_string)
  if allow_string and type(entry) == "string" and entry ~= "" then
    return entry
  end
  if type(entry) ~= "table" then
    return nil, path .. " must be a table with a non-empty key"
  end
  if getmetatable(entry) ~= nil then
    return nil, path .. " must be a plain table with a non-empty key"
  end
  if type(entry.key) ~= "string" or entry.key == "" then
    return nil, path .. ".key must be a non-empty string"
  end
  return entry.key
end

local function validate_patch_array(value, path, kind, clone_state)
  if value == nil then return {}, {} end
  local count, err = validate_dense_array(value, path, MAX_PATCH_ITEMS)
  if not count then return nil, err end

  local out, keys = {}, {}
  for i = 1, count do
    local item = value[i]
    if kind == "instances" and type(item) ~= "table" then
      return nil, ("%s[%d] must be a declarative table"):format(path, i)
    end
    local key = nil
    if kind ~= "instances" then
      key, err = patch_entry_key(item, ("%s[%d]"):format(path, i), kind == "suppressCells")
      if not key then return nil, err end
      if keys[key] then
        return nil, ("%s contains duplicate key %q"):format(path, key)
      end
      keys[key] = true
    end
    local cloned
    cloned, err = clone_data(item, ("%s[%d]"):format(path, i), clone_state)
    if err then return nil, err end
    out[i] = cloned
  end
  return out, keys
end

local function validate_tags(value, clone_state)
  if value == nil then return {} end
  if type(value) ~= "table" or getmetatable(value) ~= nil then
    return nil, "terrain result.tags must be a plain table"
  end
  for key in pairs(value) do
    if type(key) ~= "string" or key == "" then
      return nil, "terrain result.tags must use non-empty string keys"
    end
  end
  return clone_data(value, "terrain result.tags", clone_state)
end

local function validate_terrain_result(value)
  if value == nil then
    return {
      cacheKey = nil,
      suppressCells = {},
      suppressionKeys = {},
      transforms = {},
      transformKeys = {},
      instances = {},
      tags = {},
      invalidate = false,
      hasPatchData = false,
    }
  end
  if type(value) ~= "table" or getmetatable(value) ~= nil then
    return nil, "terrain result must be a plain table or nil"
  end
  local ok, err = validate_known_keys(value, TERRAIN_RESULT_KEYS, "terrain result")
  if not ok then return nil, err end

  local cache_key = value.cacheKey
  if cache_key ~= nil
     and (type(cache_key) ~= "string"
          or cache_key == ""
          or #cache_key > MAX_CACHE_KEY_LENGTH) then
    return nil, "terrain result.cacheKey must be a 1-512 character string when present"
  end
  if value.invalidate ~= nil and type(value.invalidate) ~= "boolean" then
    return nil, "terrain result.invalidate must be a boolean when present"
  end

  local clone_state = { active = {}, nodes = 0, bytes = 0 }

  local suppressions, suppression_keys = validate_patch_array(
    value.suppressCells,
    "terrain result.suppressCells",
    "suppressCells",
    clone_state
  )
  if not suppressions then return nil, suppression_keys end
  local transforms, transform_keys = validate_patch_array(
    value.transforms,
    "terrain result.transforms",
    "transforms",
    clone_state
  )
  if not transforms then return nil, transform_keys end
  local instances
  instances, err = validate_patch_array(
    value.instances,
    "terrain result.instances",
    "instances",
    clone_state
  )
  if not instances then return nil, err end
  local tags
  tags, err = validate_tags(value.tags, clone_state)
  if not tags then return nil, err end

  return {
    cacheKey = cache_key,
    suppressCells = suppressions,
    suppressionKeys = suppression_keys,
    transforms = transforms,
    transformKeys = transform_keys,
    instances = instances,
    tags = tags,
    invalidate = value.invalidate == true,
    hasPatchData = #suppressions > 0
      or #transforms > 0
      or #instances > 0
      or next(tags) ~= nil,
  }
end

local function cache_segment(value)
  return tostring(#value) .. ":" .. value
end

local Dispatcher = {}
Dispatcher.__index = Dispatcher

local Handle = {}
Handle.__index = Handle

local function new_report(kind, name)
  return {
    kind = kind,
    name = name,
    called = 0,
    succeeded = 0,
    failed = 0,
    skipped = 0,
    contributors = {},
  }
end

function API.new(options)
  options = options or {}
  if type(options) ~= "table" then error("options must be a table", 2) end
  local allowed = {
    host_id = true,
    host_version = true,
    capabilities = true,
    logger = true,
    clock = true,
    max_errors = true,
    max_extensions = true,
  }
  local ok, err = validate_known_keys(options, allowed, "options")
  if not ok then error(err, 2) end

  local host_id = options.host_id or "voxel-host"
  if type(host_id) ~= "string" or host_id == "" then
    error("options.host_id must be a non-empty string", 2)
  end
  local host_version = options.host_version or "unknown"
  if type(host_version) ~= "string" or host_version == "" then
    error("options.host_version must be a non-empty string", 2)
  end
  if options.logger ~= nil and type(options.logger) ~= "function" then
    error("options.logger must be a function", 2)
  end
  if options.clock ~= nil and type(options.clock) ~= "function" then
    error("options.clock must be a function", 2)
  end
  local max_errors = options.max_errors or 64
  if not is_integer(max_errors) or max_errors < 1 or max_errors > 4096 then
    error("options.max_errors must be an integer from 1 to 4096", 2)
  end
  local max_extensions = options.max_extensions or 64
  if not is_integer(max_extensions) or max_extensions < 1 or max_extensions > 1024 then
    error("options.max_extensions must be an integer from 1 to 1024", 2)
  end

  local capabilities = {}
  if options.capabilities ~= nil then
    local count
    count, err = validate_dense_array(options.capabilities, "options.capabilities", 128)
    if not count then error(err, 2) end
    for i = 1, count do
      local capability = options.capabilities[i]
      if type(capability) ~= "string" or capability == "" then
        error(("options.capabilities[%d] must be a non-empty string"):format(i), 2)
      end
      if not STANDARD_CAPABILITY_SET[capability] then
        error(("options.capabilities[%d] is not a standard API v1 capability: %q")
          :format(i, capability), 2)
      end
      if capabilities[capability] then
        error(("options.capabilities contains duplicate %q"):format(capability), 2)
      end
      capabilities[capability] = true
    end
  end

  return setmetatable({
    _host_id = host_id,
    _host_version = host_version,
    _capabilities = capabilities,
    _logger = options.logger,
    _clock = options.clock or os.clock,
    _max_errors = max_errors,
    _max_extensions = max_extensions,
    _errors = {},
    _error_sequence = 0,
    _records = {},
    _order = {},
    _services = nil,
    _running_context = nil,
    _attached = false,
    _state = "open",
    _dispatch_depth = 0,
  }, Dispatcher)
end

function Dispatcher:_time()
  local ok, value = pcall(self._clock)
  if ok and is_finite(value) then return value end
  return 0
end

function Dispatcher:_log(event)
  if not self._logger then return end
  pcall(self._logger, event)
end

function Dispatcher:_append_error(record, stage, message)
  message = safe_error_text(message)
  self._error_sequence = self._error_sequence + 1
  local fault = {
    sequence = self._error_sequence,
    time = self:_time(),
    host = self._host_id,
    extension = record and record.id or nil,
    stage = stage,
    message = message,
  }
  local errors = self._errors
  errors[#errors + 1] = fault
  if #errors > self._max_errors then table.remove(errors, 1) end
  self:_log({
    level = "error",
    event = "voxel_companion.extension_fault",
    fault = {
      sequence = fault.sequence,
      time = fault.time,
      host = fault.host,
      extension = fault.extension,
      stage = fault.stage,
      message = fault.message,
    },
  })
  return fault
end

function Dispatcher:_rebuild_order()
  local order = {}
  for _, record in pairs(self._records) do
    if record.state ~= "disposed" then order[#order + 1] = record end
  end
  table.sort(order, function(a, b)
    if a.priority ~= b.priority then return a.priority < b.priority end
    return a.id < b.id
  end)
  self._order = order
end

function Dispatcher:_invoke(record, stage, handler, source, ...)
  local context, close = borrowed_view(source, stage .. " context")
  local extra = pack(...)
  local function run()
    return pack(handler(context, unpack(extra, 1, extra.n)))
  end
  local ok, result = xpcall(run, traceback_error)
  local clean, mutation = close()
  if not ok then return nil, result end
  if not clean then return nil, mutation end
  return result
end

function Dispatcher:_invoke_dispose(record, source, reason, keep_fault_state)
  if record.dispose_called then return true end
  record.dispose_called = true
  record.active = false
  local handler = record.lifecycle.dispose
  if handler then
    local result, err = self:_invoke(record, record.id .. ".dispose", handler, source, reason)
    if not result then
      self:_append_error(record, "dispose", err)
      if not keep_fault_state then record.state = "disposed" end
      return nil, err
    end
    for i = 1, result.n do
      if result[i] ~= nil then
        local message = "lifecycle.dispose must not return a value"
        self:_append_error(record, "dispose", message)
        if not keep_fault_state then record.state = "disposed" end
        return nil, message
      end
    end
  end
  if not keep_fault_state then record.state = "disposed" end
  return true
end

function Dispatcher:_fault(record, stage, message, source)
  if record.faulted or record.state == "disposed" then return record.fault end
  local owns_guard = self._dispatch_depth == 0
  if owns_guard then self._dispatch_depth = 1 end
  record.active = false
  record.faulted = true
  record.state = "faulted"
  record.fault = self:_append_error(record, stage, message)
  self:_invoke_dispose(record, source or {}, "fault", true)
  if owns_guard then self:_leave() end
  return record.fault
end

function Dispatcher:_handler_records(selector)
  local out = {}
  for _, record in ipairs(self._order) do
    if selector(record) then out[#out + 1] = record end
  end
  return out
end

function Dispatcher:_enter(operation)
  if self._state ~= "running" then
    return nil, ("cannot %s while dispatcher state is %s"):format(operation, self._state)
  end
  if self._dispatch_depth > 0 then
    return nil, "reentrant dispatch is not allowed"
  end
  self._dispatch_depth = self._dispatch_depth + 1
  return true
end

function Dispatcher:_leave()
  self._dispatch_depth = math.max(0, self._dispatch_depth - 1)
end

function Dispatcher:_run_dispatch(operation, callback)
  local entered, err = self:_enter(operation)
  if not entered then return nil, err end

  local result
  local ok, problem = xpcall(function()
    result = pack(callback())
  end, traceback_error)
  self:_leave()
  if not ok then return nil, problem end
  return unpack(result, 1, result.n)
end

function Dispatcher:capabilities()
  return sorted_keys(self._capabilities)
end

-- Return the public wire descriptor used at `mod.exports.voxel_companion`.
-- The returned tables are fresh copies. The register closure is intentionally
-- a plain function because Gen1recomp consumers call exports without `self`.
function Dispatcher:provider()
  local dispatcher = self
  local capabilities = {}
  for capability in pairs(self._capabilities) do capabilities[capability] = 1 end
  return {
    api = API.VERSION,
    host = {
      id = self._host_id,
      version = self._host_version,
    },
    capabilities = capabilities,
    register = function(spec, running_context)
      return dispatcher:register(spec, running_context or dispatcher._running_context)
    end,
  }
end

Dispatcher.export = Dispatcher.provider

function Dispatcher:attach(services)
  if self._state == "disposed" or self._state == "disposing" then
    return nil, "cannot attach services to a disposed dispatcher"
  end
  if self._dispatch_depth > 0 then return nil, "cannot attach during dispatch" end
  if self._attached then
    if self._services == services then return true end
    return nil, "services are already attached"
  end
  if type(services) ~= "table" then return nil, "services must be a table" end

  for _, record in ipairs(self._order) do
    local ok, err = validate_required_facades(
      services,
      record.requirements,
      "services",
      record.uses_render_services
    )
    if not ok then return nil, ("extension %s: %s"):format(record.id, err) end
  end

  self._services = services
  self._attached = true
  local report = new_report("lifecycle", "attach")
  self._dispatch_depth = self._dispatch_depth + 1
  for _, record in ipairs(copy_array(self._order)) do
    if not record.faulted and record.state ~= "disposed" then
      local handler = record.lifecycle.attach
      report.called = report.called + (handler and 1 or 0)
      if handler then
        local result, err = self:_invoke(record, record.id .. ".attach", handler, services)
        if not result then
          self:_fault(record, "attach", err, services)
          report.failed = report.failed + 1
        else
          local invalid = false
          for i = 1, result.n do
            if result[i] ~= nil then invalid = true break end
          end
          if invalid then
            self:_fault(record, "attach", "lifecycle.attach must not return a value", services)
            report.failed = report.failed + 1
          else
            record.attached = true
            report.succeeded = report.succeeded + 1
            report.contributors[#report.contributors + 1] = record.id
          end
        end
      else
        record.attached = true
      end
    end
  end
  self._dispatch_depth = self._dispatch_depth - 1
  return report
end

function Dispatcher:register(spec, running_context)
  if self._state == "disposed" or self._state == "disposing" then
    return nil, "cannot register on a disposed dispatcher"
  end
  if self._dispatch_depth > 0 then return nil, "cannot register during dispatch" end

  local record, err = normalize_spec(spec, self._capabilities)
  if not record then return nil, err end

  local existing = self._records[record.id]
  if existing then
    if existing.source == spec and existing.state ~= "disposed" then
      return existing.handle
    end
    return nil, ("extension id %q is already registered"):format(record.id)
  end

  local extension_count = 0
  for _ in pairs(self._records) do extension_count = extension_count + 1 end
  if extension_count >= self._max_extensions then
    return nil, ("dispatcher reached its %d extension limit"):format(self._max_extensions)
  end

  if self._attached then
    local ok
    ok, err = validate_required_facades(
      self._services,
      record.requirements,
      "services",
      record.uses_render_services
    )
    if not ok then return nil, err end
  end
  if self._state == "running" and type(running_context) ~= "table" then
    return nil, "running_context is required for registration after start"
  end

  local handle = setmetatable({ _dispatcher = self, _record = record }, Handle)
  record.handle = handle
  self._records[record.id] = record
  self:_rebuild_order()

  if self._attached then
    local handler = record.lifecycle.attach
    if handler then
      self._dispatch_depth = self._dispatch_depth + 1
      local result
      result, err = self:_invoke(record, record.id .. ".attach", handler, self._services)
      if not result then
        self:_fault(record, "attach", err, self._services)
      else
        for i = 1, result.n do
          if result[i] ~= nil then
            self:_fault(record, "attach", "lifecycle.attach must not return a value", self._services)
            break
          end
        end
        if not record.faulted then record.attached = true end
      end
      self:_leave()
    else
      record.attached = true
    end
  end

  if self._state == "running" and not record.faulted then
    local handler = record.lifecycle.start
    if handler then
      self._dispatch_depth = self._dispatch_depth + 1
      local result
      result, err = self:_invoke(record, record.id .. ".start", handler, running_context)
      if not result then
        self:_fault(record, "start", err, running_context)
      else
        for i = 1, result.n do
          if result[i] ~= nil then
            self:_fault(record, "start", "lifecycle.start must not return a value", running_context)
            break
          end
        end
      end
      self:_leave()
    end
    if not record.faulted then
      record.started = true
      record.active = true
      record.state = "active"
    end
  end
  return handle
end

function Dispatcher:start(context)
  if self._state == "running" then return true end
  if self._state ~= "open" then
    return nil, ("cannot start while dispatcher state is %s"):format(self._state)
  end
  if not self._attached then return nil, "attach services before start" end
  if type(context) ~= "table" then return nil, "start context must be a table" end
  if self._dispatch_depth > 0 then return nil, "cannot start during dispatch" end

  self._state = "starting"
  self._running_context = context
  self._dispatch_depth = self._dispatch_depth + 1
  local report = new_report("lifecycle", "start")
  for _, record in ipairs(copy_array(self._order)) do
    if record.state ~= "disposed" and not record.faulted then
      local handler = record.lifecycle.start
      report.called = report.called + (handler and 1 or 0)
      if handler then
        local result, err = self:_invoke(record, record.id .. ".start", handler, context)
        if not result then
          self:_fault(record, "start", err, context)
          report.failed = report.failed + 1
        else
          local invalid = false
          for i = 1, result.n do
            if result[i] ~= nil then invalid = true break end
          end
          if invalid then
            self:_fault(record, "start", "lifecycle.start must not return a value", context)
            report.failed = report.failed + 1
          else
            record.started = true
            record.active = true
            record.state = "active"
            report.succeeded = report.succeeded + 1
            report.contributors[#report.contributors + 1] = record.id
          end
        end
      else
        record.started = true
        record.active = true
        record.state = "active"
      end
    end
  end
  self._dispatch_depth = self._dispatch_depth - 1
  self._state = "running"
  return report
end

function Dispatcher:dispatch(phase, context)
  if not PHASE_SET[phase] then return nil, "unknown phase " .. safe_key_label(phase) end
  if type(context) ~= "table" then return nil, "phase context must be a table" end
  return self:_run_dispatch("dispatch " .. phase, function()
    local records = self:_handler_records(function(record)
      return record.phases[phase] ~= nil
    end)
    if #records > 0 and RENDER_PHASE_SET[phase] then
      local valid, validation_error = validate_render_context(context, phase .. " context")
      if not valid then return nil, validation_error end
    end

    local report = new_report("phase", phase)
    for _, record in ipairs(records) do
      if not record.active then
        report.skipped = report.skipped + 1
      else
        report.called = report.called + 1
        local result, err = self:_invoke(
          record,
          record.id .. "." .. phase,
          record.phases[phase],
          context
        )
        if not result then
          self:_fault(record, phase, err, context)
          report.failed = report.failed + 1
        else
          local invalid = false
          for i = 1, result.n do
            if result[i] ~= nil then invalid = true break end
          end
          if invalid then
            self:_fault(record, phase, "phase handlers must not return a value", context)
            report.failed = report.failed + 1
          else
            report.succeeded = report.succeeded + 1
            report.contributors[#report.contributors + 1] = record.id
          end
        end
      end
    end
    return report
  end)
end

Dispatcher.dispatch_phase = Dispatcher.dispatch

function Dispatcher:update(frame)
  return self:dispatch("update", frame)
end

function Dispatcher:world_changed(snapshot)
  return self:dispatch("map_changed", snapshot)
end

Dispatcher.worldChanged = Dispatcher.world_changed

function Dispatcher:render(phase, context)
  if not RENDER_PHASE_SET[phase] then
    return nil, "unknown render phase " .. safe_key_label(phase)
  end
  return self:dispatch(phase, context)
end

function Dispatcher:dispatch_camera(context)
  if type(context) ~= "table" then return nil, "camera context must be a table" end
  return self:_run_dispatch("dispatch camera", function()
    local records = self:_handler_records(function(record) return record.camera ~= nil end)
    local aggregate = {
      positionDelta = { x = 0, y = 0, z = 0 },
      rotationDelta = { yaw = 0, pitch = 0, roll = 0 },
      fovDelta = 0,
    }
    local report = new_report("result", "camera")
    for _, record in ipairs(records) do
      if not record.active then
        report.skipped = report.skipped + 1
      else
        report.called = report.called + 1
        local packed, err = self:_invoke(
          record,
          record.id .. ".camera",
          record.camera,
          context
        )
        if not packed then
          self:_fault(record, "camera", err, context)
          report.failed = report.failed + 1
        elseif packed.n > 1 then
          self:_fault(record, "camera", "camera handler must return zero or one value", context)
          report.failed = report.failed + 1
        else
          local contribution
          contribution, err = validate_camera_result(packed[1])
          if contribution then
            local merged
            merged, err = merge_camera_result(aggregate, contribution)
            contribution = merged
          end
          if not contribution then
            self:_fault(record, "camera.result", err, context)
            report.failed = report.failed + 1
          else
            aggregate = contribution
            report.succeeded = report.succeeded + 1
            report.contributors[#report.contributors + 1] = record.id
          end
        end
      end
    end
    return aggregate, report
  end)
end

Dispatcher.modify_camera = Dispatcher.dispatch_camera
Dispatcher.modifyCamera = Dispatcher.dispatch_camera

function Dispatcher:dispatch_terrain(context)
  if type(context) ~= "table" then return nil, "terrain context must be a table" end
  return self:_run_dispatch("dispatch terrain", function()
    local records = self:_handler_records(function(record) return record.terrain ~= nil end)
    local aggregate = {
      cacheKey = nil,
      suppressCells = {},
      transforms = {},
      instances = {},
      tags = {},
      invalidate = false,
    }
    local suppression_owners, transform_owners = {}, {}
    local cache_parts = {}
    local cacheable, has_patch_data = true, false
    local report = new_report("result", "terrain")
    local err

    for _, record in ipairs(records) do
      if not record.active then
        report.skipped = report.skipped + 1
      else
        report.called = report.called + 1
        local packed
        packed, err = self:_invoke(record, record.id .. ".terrain", record.terrain, context)
        if not packed then
          self:_fault(record, "terrain", err, context)
          report.failed = report.failed + 1
        elseif packed.n > 1 then
          self:_fault(record, "terrain", "terrain handler must return zero or one value", context)
          report.failed = report.failed + 1
        else
          local contribution
          contribution, err = validate_terrain_result(packed[1])
          if contribution then
            for key in pairs(contribution.suppressionKeys) do
              if suppression_owners[key] then
                err = ("suppression key %q is already owned by %s")
                  :format(key, suppression_owners[key])
                break
              end
            end
          end
          if contribution and not err then
            for key in pairs(contribution.transformKeys) do
              if transform_owners[key] then
                err = ("transform key %q is already owned by %s")
                  :format(key, transform_owners[key])
                break
              end
            end
          end
          if contribution and not err then
            local merged_items = #aggregate.suppressCells
              + #aggregate.transforms
              + #aggregate.instances
              + #contribution.suppressCells
              + #contribution.transforms
              + #contribution.instances
            if merged_items > MAX_MERGED_PATCH_ITEMS then
              err = ("merged terrain patch exceeds its %d item limit")
                :format(MAX_MERGED_PATCH_ITEMS)
            end
          end

          if not contribution or err then
            self:_fault(record, "terrain.result", err or "invalid terrain result", context)
            report.failed = report.failed + 1
          else
            for key in pairs(contribution.suppressionKeys) do
              suppression_owners[key] = record.id
            end
            for key in pairs(contribution.transformKeys) do
              transform_owners[key] = record.id
            end
            for _, item in ipairs(contribution.suppressCells) do
              aggregate.suppressCells[#aggregate.suppressCells + 1] = item
            end
            for _, item in ipairs(contribution.transforms) do
              aggregate.transforms[#aggregate.transforms + 1] = item
            end
            for _, item in ipairs(contribution.instances) do
              aggregate.instances[#aggregate.instances + 1] = item
            end
            for key, value in pairs(contribution.tags) do
              aggregate.tags[key] = value
            end
            aggregate.invalidate = aggregate.invalidate or contribution.invalidate

            if contribution.cacheKey then
              cache_parts[#cache_parts + 1] = cache_segment(record.id)
                .. cache_segment(contribution.cacheKey)
            elseif contribution.hasPatchData or contribution.invalidate then
              cacheable = false
            end
            has_patch_data = has_patch_data or contribution.hasPatchData
            report.succeeded = report.succeeded + 1
            report.contributors[#report.contributors + 1] = record.id
          end
        end
      end
    end

    if cacheable and #cache_parts > 0 and (has_patch_data or aggregate.invalidate) then
      aggregate.cacheKey = table.concat(cache_parts, "|")
    end
    return aggregate, report
  end)
end

Dispatcher.terrain_patch = Dispatcher.dispatch_terrain
Dispatcher.terrainPatch = Dispatcher.dispatch_terrain

function Dispatcher:invalidate(context, reason)
  if type(context) ~= "table" then return nil, "invalidate context must be a table" end
  return self:_run_dispatch("invalidate", function()
    local report = new_report("lifecycle", "invalidate")
    for _, record in ipairs(copy_array(self._order)) do
      local handler = record.lifecycle.invalidate
      if handler then
        if not record.active then
          report.skipped = report.skipped + 1
        else
          report.called = report.called + 1
          local result, err = self:_invoke(
            record,
            record.id .. ".invalidate",
            handler,
            context,
            reason
          )
          if not result then
            self:_fault(record, "invalidate", err, context)
            report.failed = report.failed + 1
          else
            local invalid = false
            for i = 1, result.n do
              if result[i] ~= nil then invalid = true break end
            end
            if invalid then
              self:_fault(record, "invalidate", "lifecycle.invalidate must not return a value", context)
              report.failed = report.failed + 1
            else
              report.succeeded = report.succeeded + 1
              report.contributors[#report.contributors + 1] = record.id
            end
          end
        end
      end
    end
    return report
  end)
end

function Dispatcher:dispose(context, reason)
  if self._state == "disposed" then return true end
  if self._dispatch_depth > 0 then return nil, "cannot dispose during dispatch" end
  if type(context) ~= "table" then return nil, "dispose context must be a table" end

  self._state = "disposing"
  self._dispatch_depth = self._dispatch_depth + 1
  local report = new_report("lifecycle", "dispose")
  for i = #self._order, 1, -1 do
    local record = self._order[i]
    if record.state ~= "disposed" then
      local had_handler = record.lifecycle.dispose ~= nil and not record.dispose_called
      if had_handler then report.called = report.called + 1 end
      local ok = self:_invoke_dispose(record, context, reason or "host-dispose", false)
      if had_handler then
        if ok then
          report.succeeded = report.succeeded + 1
          report.contributors[#report.contributors + 1] = record.id
        else
          report.failed = report.failed + 1
        end
      end
      record.state = "disposed"
      record.active = false
    end
  end
  self._dispatch_depth = self._dispatch_depth - 1
  self._services = nil
  self._running_context = nil
  self._records = {}
  self._order = {}
  self._state = "disposed"
  return report
end

function Dispatcher:errors()
  local out = {}
  for i, fault in ipairs(self._errors) do
    out[i] = {
      sequence = fault.sequence,
      time = fault.time,
      host = fault.host,
      extension = fault.extension,
      stage = fault.stage,
      message = fault.message,
    }
  end
  return out
end

function Dispatcher:status()
  local extensions = {}
  for _, record in ipairs(self._order) do
    extensions[#extensions + 1] = {
      id = record.id,
      name = record.name,
      version = record.version,
      priority = record.priority,
      requires = copy_array(record.requirement_list),
      state = record.state,
      active = record.active,
      faulted = record.faulted,
    }
  end
  return {
    api = API.VERSION,
    host = self._host_id,
    state = self._state,
    attached = self._attached,
    capabilities = self:capabilities(),
    extensions = extensions,
    errorCount = #self._errors,
  }
end

function Handle:id()
  return self._record.id
end

function Handle:is_active()
  return self._record.active == true
end

function Handle:status()
  local record = self._record
  return {
    id = record.id,
    state = record.state,
    active = record.active,
    faulted = record.faulted,
    fault = record.fault and {
      sequence = record.fault.sequence,
      stage = record.fault.stage,
      message = record.fault.message,
    } or nil,
  }
end

function Handle:invalidate(context, reason)
  local dispatcher, record = self._dispatcher, self._record
  if record.state == "disposed" then return true end
  if not record.active then return nil, "extension is not active" end
  if dispatcher._dispatch_depth > 0 then return nil, "cannot invalidate during dispatch" end
  if type(context) ~= "table" then
    reason = context
    context = {}
  end
  if type(context) ~= "table" then return nil, "invalidate context must be a table" end
  local handler = record.lifecycle.invalidate
  if not handler then return true end

  dispatcher._dispatch_depth = dispatcher._dispatch_depth + 1
  local result, err = dispatcher:_invoke(
    record,
    record.id .. ".invalidate",
    handler,
    context,
    reason
  )
  if not result then
    dispatcher:_fault(record, "invalidate", err, context)
    dispatcher:_leave()
    return nil, err
  end
  for i = 1, result.n do
    if result[i] ~= nil then
      err = "lifecycle.invalidate must not return a value"
      dispatcher:_fault(record, "invalidate", err, context)
      dispatcher:_leave()
      return nil, err
    end
  end
  dispatcher:_leave()
  return true
end

function Handle:dispose(context, reason)
  local dispatcher, record = self._dispatcher, self._record
  if record.state == "disposed" then return true end
  if dispatcher._dispatch_depth > 0 then return nil, "cannot dispose handle during dispatch" end
  context = context or {}
  if type(context) ~= "table" then return nil, "dispose context must be a table" end

  dispatcher._dispatch_depth = dispatcher._dispatch_depth + 1
  local ok, err = dispatcher:_invoke_dispose(
    record,
    context,
    reason or "handle-dispose",
    false
  )
  dispatcher._dispatch_depth = dispatcher._dispatch_depth - 1
  record.state = "disposed"
  record.active = false
  dispatcher._records[record.id] = nil
  dispatcher:_rebuild_order()
  return ok, err
end

return API
