-- Voxel Companion API v1 adapter for Battle Art Voxel Fork.
--
-- The dispatcher owns extension lifecycle and fault isolation. This adapter
-- owns the real Battle Art seams: copied world facts, additive camera deltas,
-- three ordered overworld phases, a bounded draw facade, and integrity data.
-- It does not advertise terrain, shadow, or battle capabilities.

local V = ...

local API = V.require("VoxelCompanionAPI")
local VisualObjects = V.require("VoxelVisualObjects")
local Mat4 = V.require("Mat4")
local TileShape = V.require("TileShape")
local ChunkMesher = V.require("ChunkMesher")
local Voxel = V.require("VoxelState")
local Voxel3D = V.require("Voxel3D")
local DayNight = V.require("DayNight")
local Map = require("src.world.Map")

local VoxelCompanion = {}
VoxelCompanion.__index = VoxelCompanion

local CAPABILITIES = {
  "world_snapshot",
  "camera_delta",
  "render_phases",
  "quality_tier",
  "integrity_status",
  "visual_object_overrides",
}

local DISPATCH_CAPABILITIES = {
  "world_snapshot",
  "camera_delta",
  "render_phases",
  "quality_tier",
  "integrity_status",
}

local WORLD_PHASES = {
  background = true,
  opaque_after_terrain = true,
  translucent_after_actors = true,
}

local MAX_CELLS = 262144
local MAX_ACTORS = 2048
local MAX_NEIGHBORS = 8
local MAX_VISUAL_OBJECTS = 4096
local MAX_PACKET_ITEMS = 2048
local MAX_DRAWS_PER_FRAME = 4096
local MAX_WORLD_COORDINATE = 65536
local MAX_PRIMITIVE_SIZE = 65536
local MAX_COMMAND_SIGNATURES = 4096
local MAX_SIGNATURE_NODES = 32768
local MAX_SIGNATURE_BYTES = 256 * 1024
local MAX_SKY_LAYER = 16
local PANORAMA_SEGMENTS = 32
local CLOUD_LONGITUDE_SEGMENTS = 32
local CLOUD_LATITUDE_SEGMENTS = 16
local RAINBOW_SEGMENTS = 24
local PANORAMA_RADIUS = 900
local PANORAMA_TOP = 300
local PANORAMA_BOTTOM = -120
local PANORAMA_DEEP_BOTTOM = -1400

-- Semantic density roles are intentionally narrower than TileShape classes.
-- A `cylinder` is only a host geometry choice; it is not proof that a cell is
-- a tree. Likewise, a generic wall or cliff is not proof of mountain rock.
-- These authored OVERWORLD ids are the public KFP 1.60 distinctions that the
-- host can verify without exposing engine state to an extension.
local SEMANTIC_TILESETS = {
  OVERWORLD = {
    tree_support = { [64] = true, [65] = true, [80] = true, [81] = true },
    boulder_tree = { [42] = true, [43] = true, [58] = true, [59] = true },
    mountain_seed = { [2] = true, [36] = true },
  },
}
local MOUNTAIN_REACH = 2

local MESH_PRIMITIVES = {
  box = true,
  plane = true,
  world_apron = true,
  panorama = true,
  cloud_layer = true,
  rainbow = true,
}

local INSTANCE_PRIMITIVES = {
  box = true,
  plane = true,
  door_frame = true,
  window = true,
  poster = true,
  rail = true,
  fixture = true,
  sconce = true,
  cave_roof = true,
  grass_clump = true,
  canopy = true,
  vine = true,
  umbrella = true,
  mountain = true,
  hood = true,
}

-- These are exact literals written by released KFP 1.x patchers. Only known
-- host targets are scanned, so this scanner cannot match its own vocabulary.
local LEGACY_MARKERS = {
  ["lib/VoxelScene.lua"] = {
    "pcall(Ceiling.draw",
    "pcall(Flora.draw",
    "pcall(Backdrop.draw",
    "pcall(SkyLayer.draw",
    "local function __dsMod(name, statusKey)",
    "__ds_ceiling_status",
  },
  ["lib/FirstPerson.lua"] = {
    'V.require("Jump")',
    "Jump.eyeOffset(me)",
    "Jump.swayX(me)",
    "Jump.swayZ(me)",
  },
  ["lib/Structures.lua"] = {
    "__ds_tree_lift",
    "__ds_round_key",
    "__ds_round_tomb",
    'rawget(_G, "__ds_ceiling_config")',
  },
  ["lib/ChunkMesher.lua"] = {
    "ds_fp_ceilings __ds_round_base",
    "ds_fp_ceilings fastchunks",
    'rawget(_G, "__ds_round_base")',
  },
  ["main.lua"] = {
    "Ceiling.setting",
    "__ds_ceiling_config",
  },
  ["lib/Ceiling.lua"] = { "payload-version:", "__ds_ceiling_config" },
  ["lib/Backdrop.lua"] = { "payload-version:", "__ds_ceiling_config" },
  ["lib/SkyLayer.lua"] = { "payload-version:", "__ds_ceiling_config" },
  ["lib/Flora.lua"] = { "payload-version:", "__ds_ceiling_config" },
  ["lib/Jump.lua"] = { "payload-version:", "Jump.eyeOffset" },
}

local COLORS = {
  interior = { 0.82, 0.76, 0.67, 1 },
  cave = { 0.42, 0.39, 0.45, 1 },
  rock = { 0.48, 0.47, 0.52, 1 },
  stone = { 0.52, 0.52, 0.56, 1 },
  grass = { 0.28, 0.62, 0.31, 1 },
  tree = { 0.20, 0.48, 0.25, 1 },
  canopy = { 0.16, 0.43, 0.22, 1 },
  vine = { 0.23, 0.55, 0.25, 0.92 },
  water = { 0.26, 0.55, 0.78, 0.64 },
  puddle = { 0.35, 0.62, 0.80, 0.50 },
  rain = { 0.70, 0.84, 0.96, 0.70 },
  panorama = { 1.00, 1.00, 1.00, 1.00 },
  cloud = { 0.93, 0.96, 1.00, 0.22 },
  rainbow = { 0.96, 0.62, 0.84, 0.48 },
  star = { 1.00, 0.98, 0.78, 0.90 },
  shadow = { 0.04, 0.05, 0.07, 0.28 },
  light = { 1.00, 0.88, 0.55, 0.72 },
  firefly = { 0.90, 1.00, 0.45, 0.88 },
  smoke = { 0.70, 0.72, 0.76, 0.52 },
  default = { 0.68, 0.70, 0.72, 1 },
}

local function finite(value, fallback)
  value = tonumber(value)
  if not value or value ~= value or value == math.huge or value == -math.huge then
    return fallback
  end
  return value
end

local function integer(value, fallback)
  value = finite(value, fallback)
  if value == nil then return nil end
  return math.floor(value)
end

local function clamp(value, minimum, maximum, fallback)
  value = finite(value, fallback)
  if value < minimum then return minimum end
  if value > maximum then return maximum end
  return value
end

local function boundedText(value, fallback, limit)
  if type(value) ~= "string" or value == "" then return fallback end
  return value:sub(1, limit or 128)
end

local function shallowCopy(source)
  local out = {}
  for key, value in pairs(source or {}) do out[key] = value end
  return out
end

local function copyTags(source)
  local out = {}
  for key, value in pairs(source or {}) do
    if type(key) == "string" and value == true then out[key] = true end
  end
  return out
end

local function copySnapshot(source)
  if type(source) ~= "table" then return nil end
  local out = shallowCopy(source)
  out.tags = copyTags(source.tags)
  out.player = shallowCopy(source.player)
  out.cells, out.actors, out.neighbors = {}, {}, {}
  out.visualObjects = {}
  for index, cell in ipairs(source.cells or {}) do
    local copy = shallowCopy(cell)
    copy.tags = copyTags(cell.tags)
    copy.metadata = shallowCopy(cell.metadata)
    out.cells[index] = copy
  end
  for index, actor in ipairs(source.actors or {}) do
    local copy = shallowCopy(actor)
    copy.pose = shallowCopy(actor.pose)
    copy.tags = copyTags(actor.tags)
    out.actors[index] = copy
  end
  for index, neighbor in ipairs(source.neighbors or {}) do
    local copy = shallowCopy(neighbor)
    copy.tags = copyTags(neighbor.tags)
    out.neighbors[index] = copy
  end
  local function copyPlain(value)
    if type(value) ~= "table" then return value end
    local copy = {}
    for key, item in pairs(value) do copy[key] = copyPlain(item) end
    return copy
  end
  for index, visual in ipairs(source.visualObjects or {}) do
    out.visualObjects[index] = copyPlain(visual)
  end
  return out
end

local function loggerCall(mod, level, message)
  local log = mod and mod.log
  local callback = type(log) == "table" and log[level]
  if type(callback) == "function" then
    pcall(callback, log, "%s", tostring(message))
  end
end

local function rememberDiagnostic(self, message)
  self.diagnostics[#self.diagnostics + 1] = tostring(message)
  if #self.diagnostics > 64 then table.remove(self.diagnostics, 1) end
end

local function scanIntegrity(mod)
  local findings = {}
  for path, markers in pairs(LEGACY_MARKERS) do
    local ok, source = pcall(mod.read, mod, path)
    if ok and type(source) == "string" then
      for _, marker in ipairs(markers) do
        if source:find(marker, 1, true) then
          findings[#findings + 1] = { path = path, marker = marker }
        end
      end
    end
  end
  table.sort(findings, function(a, b)
    if a.path ~= b.path then return a.path < b.path end
    return a.marker < b.marker
  end)
  return {
    clean = #findings == 0,
    legacyMarkers = #findings > 0,
    findings = findings,
    policy = "read-only-refusal",
  }
end

local function copyIntegrity(status)
  local out = {
    clean = status.clean,
    legacyMarkers = status.legacyMarkers,
    policy = status.policy,
    findings = {},
  }
  for index, finding in ipairs(status.findings or {}) do
    out.findings[index] = { path = finding.path, marker = finding.marker }
  end
  return out
end

local function platformName()
  if love and love.system and type(love.system.getOS) == "function" then
    local ok, value = pcall(love.system.getOS)
    if ok and type(value) == "string" then return value:upper() end
  end
  return "UNKNOWN"
end

local function face(mesh, indices, direction)
  local corners = Voxel3D.FACE_CORNERS[direction]
  local shade = Voxel3D.FACE_SHADE[direction] or 1
  local quad = #mesh / 4
  for index = 1, 4 do
    local corner = corners[index]
    mesh[#mesh + 1] = { corner[1] - 0.5, corner[2] - 0.5,
      corner[3] - 0.5, 0.5, 0.5, shade }
  end
  Voxel3D.pushQuad(indices, quad)
end

local function buildBox()
  local vertices, indices = {}, {}
  for direction = 1, 6 do face(vertices, indices, direction) end
  return Voxel3D.newMesh(vertices, indices)
end

local function buildPlane()
  local vertices = {
    { -0.5, 0, -0.5, 0.5, 0.5, 1 },
    {  0.5, 0, -0.5, 0.5, 0.5, 1 },
    {  0.5, 0,  0.5, 0.5, 0.5, 1 },
    { -0.5, 0,  0.5, 0.5, 0.5, 1 },
  }
  local indices = {}
  Voxel3D.pushQuad(indices, 0)
  return Voxel3D.newMesh(vertices, indices)
end

local function buildBillboard()
  local vertices = {
    { -0.5, 0, 0, 0.5, 0.5, 1 },
    {  0.5, 0, 0, 0.5, 0.5, 1 },
    {  0.5, 1, 0, 0.5, 0.5, 1 },
    { -0.5, 1, 0, 0.5, 0.5, 1 },
  }
  local indices = {}
  Voxel3D.pushQuad(indices, 0)
  return Voxel3D.newMesh(vertices, indices)
end

-- These conservative host-owned sky meshes implement the API v1 baseline.
-- They are bounded visual proxies, not a claim of legacy panorama or weather
-- parity. Declarative commands and callback-borrowed textures stay outside all
-- host caches; only these fixed meshes are retained by the adapter.
local function addPanoramaRing(vertices, indices, bottom, top, bottomV, topV)
  local radius = 0.5
  for segment = 0, PANORAMA_SEGMENTS - 1 do
    local a0 = segment * math.pi * 2 / PANORAMA_SEGMENTS
    local a1 = (segment + 1) * math.pi * 2 / PANORAMA_SEGMENTS
    local x0, z0 = math.cos(a0) * radius, math.sin(a0) * radius
    local x1, z1 = math.cos(a1) * radius, math.sin(a1) * radius
    local u0, u1 = segment / PANORAMA_SEGMENTS,
      (segment + 1) / PANORAMA_SEGMENTS
    local quad = #vertices / 4
    vertices[#vertices + 1] = { x0, bottom, z0, u0, bottomV, 1 }
    vertices[#vertices + 1] = { x1, bottom, z1, u1, bottomV, 1 }
    vertices[#vertices + 1] = { x1, top, z1, u1, topV, 1 }
    vertices[#vertices + 1] = { x0, top, z0, u0, topV, 1 }
    Voxel3D.pushQuad(indices, quad)
  end
end

local function buildPanorama(deepSkirt)
  local vertices, indices = {}, {}
  addPanoramaRing(vertices, indices, PANORAMA_BOTTOM, PANORAMA_TOP, 1, 0)
  if deepSkirt then
    -- The deep closure samples only the authored bottom row. Stretching the
    -- full panorama through this range compressed its skyline near the
    -- horizon and repeated transparent bands across the frame.
    addPanoramaRing(vertices, indices,
      PANORAMA_DEEP_BOTTOM, PANORAMA_BOTTOM, 1, 1)
  end
  return Voxel3D.newMesh(vertices, indices)
end

local function buildCloudLayer()
  -- A closed inward-facing shell has no perimeter at which an opaque cloud
  -- texel can be clipped. Planar X/Z projection keeps UVs continuous across
  -- every shared edge without a longitude seam or detached mesh facets.
  local vertices, indices = {}, {}
  vertices[1] = { 0, 0.5, 0, 0.5, 0.5, 1 }
  for latitude = 1, CLOUD_LATITUDE_SEGMENTS - 1 do
    local polar = latitude * math.pi / CLOUD_LATITUDE_SEGMENTS
    local ringRadius = math.sin(polar) * 0.5
    local y = math.cos(polar) * 0.5
    for longitude = 0, CLOUD_LONGITUDE_SEGMENTS - 1 do
      local azimuth = longitude * math.pi * 2 / CLOUD_LONGITUDE_SEGMENTS
      local x = math.cos(azimuth) * ringRadius
      local z = math.sin(azimuth) * ringRadius
      vertices[#vertices + 1] = { x, y, z, x + 0.5, z + 0.5, 1 }
    end
  end
  local south = #vertices + 1
  vertices[south] = { 0, -0.5, 0, 0.5, 0.5, 1 }

  local function ringVertex(latitude, longitude)
    return 2 + (latitude - 1) * CLOUD_LONGITUDE_SEGMENTS
      + longitude % CLOUD_LONGITUDE_SEGMENTS
  end

  for longitude = 0, CLOUD_LONGITUDE_SEGMENTS - 1 do
    indices[#indices + 1] = 1
    indices[#indices + 1] = ringVertex(1, longitude)
    indices[#indices + 1] = ringVertex(1, longitude + 1)
  end
  for latitude = 1, CLOUD_LATITUDE_SEGMENTS - 2 do
    for longitude = 0, CLOUD_LONGITUDE_SEGMENTS - 1 do
      local upper = ringVertex(latitude, longitude)
      local upperNext = ringVertex(latitude, longitude + 1)
      local lower = ringVertex(latitude + 1, longitude)
      local lowerNext = ringVertex(latitude + 1, longitude + 1)
      indices[#indices + 1] = upper
      indices[#indices + 1] = lower
      indices[#indices + 1] = lowerNext
      indices[#indices + 1] = upper
      indices[#indices + 1] = lowerNext
      indices[#indices + 1] = upperNext
    end
  end
  local lastRing = CLOUD_LATITUDE_SEGMENTS - 1
  for longitude = 0, CLOUD_LONGITUDE_SEGMENTS - 1 do
    indices[#indices + 1] = ringVertex(lastRing, longitude)
    indices[#indices + 1] = south
    indices[#indices + 1] = ringVertex(lastRing, longitude + 1)
  end
  return Voxel3D.newMesh(vertices, indices)
end

local function buildRainbow()
  local vertices, indices = {}, {}
  for segment = 0, RAINBOW_SEGMENTS - 1 do
    local a0 = segment * math.pi / RAINBOW_SEGMENTS
    local a1 = (segment + 1) * math.pi / RAINBOW_SEGMENTS
    local outer, inner = 0.5, 0.39
    local quad = #vertices / 4
    vertices[#vertices + 1] = {
      math.cos(a0) * outer, math.sin(a0) * outer, 0, 0, 0, 1,
    }
    vertices[#vertices + 1] = {
      math.cos(a0) * inner, math.sin(a0) * inner, 0, 0, 1, 1,
    }
    vertices[#vertices + 1] = {
      math.cos(a1) * inner, math.sin(a1) * inner, 0, 1, 1, 1,
    }
    vertices[#vertices + 1] = {
      math.cos(a1) * outer, math.sin(a1) * outer, 0, 1, 0, 1,
    }
    Voxel3D.pushQuad(indices, quad)
  end
  return Voxel3D.newMesh(vertices, indices)
end

local function colorFor(material)
  local text = tostring(material or ""):lower()
  for key, color in pairs(COLORS) do
    if key ~= "default" and text:find(key, 1, true) then return color end
  end
  return COLORS.default
end

local function transform(x, y, z, width, height, depth)
  return Mat4.mul(Mat4.translate(x, y, z),
                  Mat4.scale(width, height, depth))
end

local function billboardTransform(item, width, height)
  local x = clamp(item.x, -MAX_WORLD_COORDINATE, MAX_WORLD_COORDINATE, 0)
  local y = clamp(item.y, -MAX_WORLD_COORDINATE, MAX_WORLD_COORDINATE, 0)
  local z = clamp(item.z, -MAX_WORLD_COORDINATE, MAX_WORLD_COORDINATE, 0)
  local eye = Voxel3D.eye or { x, y, z + 1 }
  local yaw = math.atan2((eye[1] or x) - x, (eye[3] or z + 1) - z)
  return Mat4.mul(Mat4.mul(Mat4.translate(x, y, z), Mat4.rotateY(yaw)),
                  Mat4.scale(width, height, 1))
end

local function eyePosition()
  local eye = Voxel3D.eye
  if type(eye) ~= "table" and type(Voxel3D.camera) == "table" then
    eye = Voxel3D.camera.eye
  end
  eye = type(eye) == "table" and eye or {}
  return clamp(eye[1], -MAX_WORLD_COORDINATE, MAX_WORLD_COORDINATE, 0),
    clamp(eye[2], -MAX_WORLD_COORDINATE, MAX_WORLD_COORDINATE, 0),
    clamp(eye[3], -MAX_WORLD_COORDINATE, MAX_WORLD_COORDINATE, 0)
end

local RANDOM_MODULUS = 2147483647
local function localSeed(value)
  local number = finite(value, nil)
  if number == nil then return nil end
  local folded = math.fmod(math.abs(number), RANDOM_MODULUS - 1)
  return math.floor(folded * 1000 + 0.5) % (RANDOM_MODULUS - 1) + 1
end

local function nextUnit(state)
  state = state * 48271 % RANDOM_MODULUS
  return state, state / RANDOM_MODULUS
end

local function starItems(procedural)
  if type(procedural) ~= "table" or procedural.kind ~= "stars" then
    return nil, "billboard procedural kind must be stars"
  end
  local count = integer(procedural.count, nil)
  local state = localSeed(procedural.seed)
  if not count or count < 1 or count > MAX_PACKET_ITEMS or not state then
    return nil, "star procedure needs a bounded count and finite seed"
  end
  for _, key in ipairs({ "twinkle", "nebula", "shootingStars" }) do
    if procedural[key] ~= nil and type(procedural[key]) ~= "boolean" then
      return nil, "star procedure " .. key .. " must be Boolean"
    end
  end

  local eyeX, eyeY, eyeZ = eyePosition()
  local items = {}
  for index = 1, count do
    local azimuth, elevation, radial, sizeNoise
    state, azimuth = nextUnit(state)
    state, elevation = nextUnit(state)
    state, radial = nextUnit(state)
    state, sizeNoise = nextUnit(state)
    local angle = azimuth * math.pi * 2
    local lift = 0.22 + elevation * 0.58
    local radius = 96 + radial * 160
    local size = procedural.twinkle and (0.55 + sizeNoise * 1.25) or 1
    if procedural.nebula and index % 11 == 0 then size = size * 1.5 end
    local width, height = size, size
    if procedural.shootingStars and index % 19 == 0 then
      width, height = size * 3.5, math.max(0.25, size * 0.45)
    end
    items[index] = {
      x = clamp(eyeX + math.cos(angle) * radius,
        -MAX_WORLD_COORDINATE, MAX_WORLD_COORDINATE, 0),
      y = clamp(eyeY + 32 + math.sin(lift) * radius,
        -MAX_WORLD_COORDINATE, MAX_WORLD_COORDINATE, 0),
      z = clamp(eyeZ + math.sin(angle) * radius,
        -MAX_WORLD_COORDINATE, MAX_WORLD_COORDINATE, 0),
      width = clamp(width, 0.25, 8, 1),
      height = clamp(height, 0.25, 8, 1),
    }
  end
  return items
end

local function playerCell(state)
  local player = state and state.player
  if type(player) ~= "table" then return nil, nil end
  return integer(player.cellX, nil), integer(player.cellY, nil)
end

local function playerWorldPosition(self, cellX, cellZ)
  local player = self.state and self.state.player
  local size = self.snapshot and finite(self.snapshot.cellSize, nil) or 16
  if type(player) == "table" then
    local x = finite(player.px, finite(player.x, nil))
    local z = finite(player.py, finite(player.y, nil))
    if x ~= nil and z ~= nil then return x + size * 0.5, z + size * 0.5 end
  end
  if cellX ~= nil and cellZ ~= nil then
    return (cellX + 0.5) * size, (cellZ + 0.5) * size
  end
  return nil, nil
end

local function wallIsCameraNear(self, item, camera, playerX, playerZ)
  local eye = type(camera) == "table" and camera.eye or nil
  if type(eye) ~= "table" then return false end
  local eyeX = finite(eye[1], nil)
  local eyeZ = finite(eye[3], nil)
  local wallX = finite(item.x, nil)
  local wallZ = finite(item.z, nil)
  if not (eyeX and eyeZ and wallX and wallZ and playerX and playerZ) then
    return false
  end
  local towardX, towardZ = eyeX - playerX, eyeZ - playerZ
  if towardX * towardX + towardZ * towardZ < 0.0001 then return false end
  return (wallX - playerX) * towardX
      + (wallZ - playerZ) * towardZ > 0
end

local function shouldCutaway(self, prototype, item, context)
  if not (prototype and prototype.cutaway) then
    return false
  end
  local primitive, role = prototype.primitive, prototype.role
  if role ~= "ceiling" and role ~= "wall" and primitive ~= "canopy" then
    return false
  end
  -- The callback context is the public, frame-local source of camera mode and
  -- eye position. Do not infer either from extension data or retain it.
  local camera = type(context) == "table" and context.camera or nil
  if primitive == "canopy"
      and (type(camera) ~= "table" or camera.mode ~= "first_person") then
    return false
  end
  local px, pz = playerCell(self.state)
  local cx, cz = integer(item.cellX, nil), integer(item.cellZ, nil)
  -- Released KFP canopy packets predate explicit cell coordinates. Their
  -- positions are normalized cell centres, so derive the same public cell
  -- identity from the retained defensive snapshot instead of reaching into
  -- producer or engine-private state.
  if primitive == "canopy" and (cx == nil or cz == nil) then
    local size = self.snapshot and finite(self.snapshot.cellSize, nil)
    if size and size > 0 then
      cx = math.floor(finite(item.x, -1) / size)
      cz = math.floor(finite(item.z, -1) / size)
    end
  end
  if not (px and pz and cx and cz) then return false end
  local nearby = math.abs(px - cx) <= 4 and math.abs(pz - cz) <= 4
  if not nearby or role ~= "wall" then return nearby end

  -- A room cutaway is a cross-section, not deletion of the room shell. Cull
  -- only the nearby wall between the camera and player. Far and side walls
  -- keep the room readable in every camera mode. Without a public eye, fail
  -- open and preserve the wall.
  local playerX, playerZ = playerWorldPosition(self, px, pz)
  return wallIsCameraNear(self, item, camera, playerX, playerZ)
end

local function primitiveDimensions(prototype, item)
  local primitive = tostring(prototype.primitive or "box")
  local width = clamp(prototype.width or item.width, 0.01,
    MAX_PRIMITIVE_SIZE, 8)
  local height = clamp(prototype.height or item.height, 0,
    MAX_PRIMITIVE_SIZE, 8)
  local depth = clamp(prototype.depth or item.depth, 0.01,
    MAX_PRIMITIVE_SIZE, width)

  if primitive == "plane" then height = 0 end
  if primitive == "door_frame" then width, height, depth = 12, 24, 2 end
  if primitive == "window" then width, height, depth = 10, 9, 1 end
  if primitive == "poster" then width, height, depth = 9, 11, 1 end
  if primitive == "rail" then width, height, depth = 16, 3, 1 end
  if primitive == "fixture" then width, height, depth = 4, 3, 4 end
  if primitive == "cave_roof" then height = 3 end
  if primitive == "sconce" then width, height, depth = 3, 6, 3 end
  if primitive == "raised_structure" then width, height, depth = 15, 24, 15 end
  if primitive == "mountain" then width, height, depth = 18, 26, 18 end
  if primitive == "hood" then width, height, depth = 18, 10, 18 end
  if primitive == "grass_clump" then width, height, depth = width, 5, width end
  if primitive == "canopy" then width, height, depth = width * 1.5, 8, width * 1.5 end
  if primitive == "vine" then width, height, depth = 3, 16, 3 end
  if primitive == "umbrella" then width, height, depth = 14, 2, 14 end
  if primitive == "world_apron" then height = 1 end
  return primitive, clamp(width, 0.01, MAX_PRIMITIVE_SIZE, 8),
    clamp(height, 0, MAX_PRIMITIVE_SIZE, 8),
    clamp(depth, 0.01, MAX_PRIMITIVE_SIZE, 8)
end

local function useDrawBudget(self, count)
  count = math.max(0, math.floor(tonumber(count) or 0))
  if self.frameDraws + count > MAX_DRAWS_PER_FRAME then
    return false, "voxel companion frame draw limit reached"
  end
  self.frameDraws = self.frameDraws + count
  return true
end

local function ensureTexture(self)
  if self.texture ~= nil then return self.texture or nil end
  if not (love and love.image and love.image.newImageData
      and love.graphics and love.graphics.newImage) then
    self.texture = false
    return nil
  end
  local ok, texture = pcall(function()
    local data = love.image.newImageData(1, 1)
    data:setPixel(0, 0, 1, 1, 1, 1)
    local image = love.graphics.newImage(data)
    image:setFilter("nearest", "nearest")
    return image
  end)
  self.texture = ok and texture or false
  return self.texture or nil
end

local function ensureMesh(self, kind)
  if self.meshes[kind] ~= nil then return self.meshes[kind] or nil end
  local mesh
  if kind == "plane" then mesh = buildPlane()
  elseif kind == "billboard" then mesh = buildBillboard()
  elseif kind == "panorama" then mesh = buildPanorama(false)
  elseif kind == "panorama_deep" then mesh = buildPanorama(true)
  elseif kind == "cloud_layer" then mesh = buildCloudLayer()
  elseif kind == "rainbow" then mesh = buildRainbow()
  else mesh = buildBox() end
  self.meshes[kind] = mesh or false
  return mesh
end

local function setMaterial(color)
  love.graphics.setColor(color[1], color[2], color[3], color[4])
  if color[4] < 1 then
    love.graphics.setBlendMode("alpha", "alphamultiply")
    love.graphics.setDepthMode("lequal", false)
  else
    love.graphics.setDepthMode("lequal", true)
  end
end

local function evictMesh(self, mesh)
  for key, cached in pairs(self.meshes) do
    if cached == mesh then self.meshes[key] = nil end
  end
  if mesh and type(mesh.release) == "function" then
    local released, releaseError = pcall(mesh.release, mesh)
    if not released then return false, releaseError end
  end
  return true
end

local function drawVoxel(self, mesh, texture, model, borrowed)
  if borrowed and type(mesh and mesh.setTexture) ~= "function" then
    error("companion mesh cannot safely borrow an extension texture", 3)
  end
  local ok, err = xpcall(function()
    Voxel3D.draw(mesh, texture, model)
  end, function(message) return tostring(message) end)
  local cleared, clearError = true, nil
  if borrowed then
    cleared, clearError = pcall(mesh.setTexture, mesh)
  end
  if not cleared then
    -- The extension still owns the texture. Drop and release only the cached
    -- host mesh so no host object can retain the borrowed image after return.
    local released, releaseError = evictMesh(self, mesh)
    local message = "could not unbind borrowed extension texture: "
      .. tostring(clearError)
    if not released then
      message = message .. "; host mesh release failed: "
        .. tostring(releaseError)
    end
    error(message, 3)
  end
  if not ok then error(err, 3) end
end

local function skyPrimitive(self, prototype)
  local primitive = prototype.primitive
  local eyeX, eyeY, eyeZ = eyePosition()
  if primitive == "panorama" then
    -- sourceWidth and targetWidth describe texture quality, not world scale.
    -- Keep the released physical panorama bounds at every quality tier.
    -- Battle's scene shader converts partial material alpha to ordered
    -- coverage. Keep the material opaque so only the panorama texture's
    -- authored alpha controls its silhouette.
    local color = prototype.distanceHaze == true
      and { 0.92, 0.94, 0.98, 1.00 } or COLORS.panorama
    local meshKind = prototype.deepSkirt == true and "panorama_deep"
      or "panorama"
    return ensureMesh(self, meshKind),
      transform(eyeX, 0, eyeZ, PANORAMA_RADIUS * 2, 1,
        PANORAMA_RADIUS * 2), color
  end

  if primitive == "cloud_layer" then
    local layer = clamp(integer(prototype.layer, 1), 1, MAX_SKY_LAYER, 1)
    local parallax = clamp(prototype.parallax, -2, 2, 0)
    local density = clamp(prototype.density, 0, 1, 0.5)
    local state = localSeed(prototype.seed) or 1
    local angle
    state, angle = nextUnit(state)
    local visualLayer = math.min(layer, 3)
    local span = 112 + density * 56 + visualLayer * 8
    local verticalSpan = 448 + visualLayer * 96
    angle = math.fmod(angle * math.pi * 2
      + (eyeX + eyeZ) * parallax / math.max(span, 1), math.pi * 2)
    local model = Mat4.mul(Mat4.translate(
      eyeX,
      clamp(eyeY - 64,
        -MAX_WORLD_COORDINATE, MAX_WORLD_COORDINATE, 0),
      eyeZ),
      Mat4.mul(Mat4.rotateY(angle),
        Mat4.scale(span, verticalSpan, span)))
    return ensureMesh(self, "cloud_layer"), model,
      { 0.93, 0.96, 1.00, 1.00 }
  end

  if primitive == "rainbow" then
    local state = localSeed(prototype.seed) or 1
    local angle, distanceNoise, sizeNoise
    state, angle = nextUnit(state)
    state, distanceNoise = nextUnit(state)
    state, sizeNoise = nextUnit(state)
    local radians = angle * math.pi * 2
    local distance = 96 + distanceNoise * 96
    local item = {
      x = clamp(eyeX + math.cos(radians) * distance,
        -MAX_WORLD_COORDINATE, MAX_WORLD_COORDINATE, 0),
      y = clamp(eyeY + 12 + sizeNoise * 24,
        -MAX_WORLD_COORDINATE, MAX_WORLD_COORDINATE, 0),
      z = clamp(eyeZ + math.sin(radians) * distance,
        -MAX_WORLD_COORDINATE, MAX_WORLD_COORDINATE, 0),
    }
    return ensureMesh(self, "rainbow"),
      billboardTransform(item, 96 + sizeNoise * 64, 72 + sizeNoise * 32),
      COLORS.rainbow
  end
end

local function drawItem(self, prototype, item, material, borrowedTexture, context)
  if shouldCutaway(self, prototype, item, context) then return false end
  local primitive, width, height, depth = primitiveDimensions(prototype, item)
  -- An extension-owned texture is borrowed for this call only. Never place it
  -- on the adapter, a mesh cache, or any cleanup list.
  if primitive == "cloud_layer" and not borrowedTexture then
    error("companion cloud texture is unavailable", 3)
  end
  local texture = borrowedTexture or ensureTexture(self)
  if not texture then error("companion material texture is unavailable", 3) end
  local color = colorFor(material)
  local ok, err = xpcall(function()
    Voxel3D.glass(false)
    if primitive == "panorama" or primitive == "cloud_layer"
        or primitive == "rainbow" then
      local mesh, model, skyColor = skyPrimitive(self, prototype)
      if not mesh then error("companion sky mesh is unavailable", 0) end
      setMaterial(skyColor or color)
      if primitive == "panorama" or primitive == "cloud_layer" then
        -- Sky coverage must not reserve depth in front of terrain or actors
        -- drawn later in the frame.
        love.graphics.setDepthMode("lequal", false)
      end
      drawVoxel(self, mesh, texture, model, borrowedTexture ~= nil)
    elseif primitive == "billboard" then
      setMaterial(color)
      local mesh = ensureMesh(self, "billboard")
      if not mesh then error("companion billboard mesh is unavailable", 0) end
      drawVoxel(self, mesh, texture, billboardTransform(item, width, height),
        borrowedTexture ~= nil)
    else
      setMaterial(color)
      local meshKind = primitive == "plane" and "plane" or "box"
      local mesh = ensureMesh(self, meshKind)
      if not mesh then error("companion primitive mesh is unavailable", 0) end
      local x = clamp(item.x, -MAX_WORLD_COORDINATE, MAX_WORLD_COORDINATE, 0)
      local y = clamp(item.y, -MAX_WORLD_COORDINATE, MAX_WORLD_COORDINATE, 0)
      local z = clamp(item.z, -MAX_WORLD_COORDINATE, MAX_WORLD_COORDINATE, 0)
      drawVoxel(self, mesh, texture, transform(x, y, z, width,
        math.max(height, 0.01), depth), borrowedTexture ~= nil)
    end
  end, function(message) return tostring(message) end)
  -- Voxel3D keeps its active material shader outside LÖVE's graphics stack.
  -- Restore that host-owned selector even when an extension draw faults.
  pcall(Voxel3D.glass, true)
  if not ok then error(err, 3) end
  return true
end

local function validCacheKey(value)
  return type(value) == "string" and #value >= 1 and #value <= 64
    and value:match("^[A-Za-z0-9._:%-]+$") ~= nil
end

local function validOpaqueTexture(value)
  if value == nil then return true end
  local kind = type(value)
  return kind == "table" or kind == "userdata" or kind == "cdata"
end

local function signatureKeyOrder(a, b)
  local typeA, typeB = type(a), type(b)
  if typeA ~= typeB then return typeA < typeB end
  if typeA == "number" then return a < b end
  return tostring(a) < tostring(b)
end

local function commandSignature(command)
  local mod = 65521
  local a, b, c, d = 1, 0, 1, 0
  local nodes, bytes = 0, 0
  local active = {}

  local function feed(text)
    bytes = bytes + #text
    if bytes > MAX_SIGNATURE_BYTES then error("draw command signature byte limit", 0) end
    for index = 1, #text do
      local byte = text:byte(index)
      a = (a + byte) % mod
      b = (b + a) % mod
      c = (c + byte + index) % mod
      d = (d + c) % mod
    end
  end

  local encode
  encode = function(value, depth, root)
    if depth > 16 then error("draw command signature depth limit", 0) end
    local kind = type(value)
    if kind == "nil" then feed("n;"); return end
    if kind == "boolean" then feed(value and "b1;" or "b0;"); return end
    if kind == "number" then
      if finite(value, nil) == nil then error("draw command signature rejects non-finite numbers", 0) end
      if value == 0 then value = 0 end
      local text = string.format("%.17g", value)
      feed("d" .. #text .. ":" .. text .. ";")
      return
    end
    if kind == "string" then feed("s" .. #value .. ":" .. value .. ";"); return end
    if kind ~= "table" or getmetatable(value) ~= nil then
      error("draw command signature rejects " .. kind, 0)
    end
    if active[value] then error("draw command signature rejects cycles", 0) end
    active[value] = true
    local keys = {}
    for key in pairs(value) do
      if not (root and (key == "cacheKey" or key == "texture")) then
        local keyType = type(key)
        if keyType ~= "string" and keyType ~= "number" then
          active[value] = nil
          error("draw command signature rejects key type " .. keyType, 0)
        end
        keys[#keys + 1] = key
        nodes = nodes + 1
        if nodes > MAX_SIGNATURE_NODES then
          active[value] = nil
          error("draw command signature node limit", 0)
        end
      end
    end
    table.sort(keys, signatureKeyOrder)
    feed("t" .. #keys .. "{")
    for _, key in ipairs(keys) do
      encode(key, depth + 1, false)
      encode(value[key], depth + 1, false)
    end
    feed("};")
    active[value] = nil
  end

  local ok, err = pcall(encode, command, 0, true)
  if not ok then return nil, tostring(err) end
  return string.format("%08x%08x", b * 65536 + a, d * 65536 + c)
end

local function validateCommandSignature(self, command)
  local digest, err = commandSignature(command)
  if not digest then return false, err end
  local key = command.cacheKey
  local previous = self.commandSignatures[key]
  if previous then
    if previous ~= digest then
      return false, "draw command.cacheKey content collision"
    end
    return true
  end

  local slot
  if self.commandSignatureCount < MAX_COMMAND_SIGNATURES then
    self.commandSignatureCount = self.commandSignatureCount + 1
    slot = self.commandSignatureCount
  else
    slot = self.commandSignatureNext
    local evicted = self.commandSignatureOrder[slot]
    if evicted then self.commandSignatures[evicted] = nil end
    self.commandSignatureNext = slot % MAX_COMMAND_SIGNATURES + 1
  end
  self.commandSignatureOrder[slot] = key
  self.commandSignatures[key] = digest
  return true
end

local function positive(value)
  local number = finite(value, nil)
  return number ~= nil and number > 0
end

local function validateMeshGeometry(geometry)
  if type(geometry) ~= "table" then return false, "mesh command needs geometry" end
  local primitive = geometry.primitive
  if not MESH_PRIMITIVES[primitive] then
    return false, "unsupported Battle Art mesh primitive: " .. tostring(primitive)
  end
  if primitive == "box" then
    if not (positive(geometry.width) and positive(geometry.height)
        and positive(geometry.depth)) then
      return false, "box geometry needs positive width, height, and depth"
    end
  elseif primitive == "plane" then
    if not (positive(geometry.width) and positive(geometry.depth)) then
      return false, "plane geometry needs positive width and depth"
    end
  elseif primitive == "world_apron" then
    if not (positive(geometry.width) and positive(geometry.depth)
        and positive(geometry.skirtDepth)) then
      return false, "world_apron geometry needs positive width, depth, and skirtDepth"
    end
  elseif primitive == "panorama" then
    if not (positive(geometry.sourceWidth) and positive(geometry.targetWidth)) then
      return false, "panorama geometry needs positive sourceWidth and targetWidth"
    end
  elseif primitive == "cloud_layer" then
    local layer = finite(geometry.layer, nil)
    local density = finite(geometry.density, nil)
    if not (layer and layer >= 1 and layer == math.floor(layer)
        and finite(geometry.parallax, nil) ~= nil
        and density and density >= 0 and density <= 1
        and finite(geometry.seed, nil) ~= nil) then
      return false, "cloud_layer geometry needs an integer layer, finite parallax/seed, and unit density"
    end
  elseif finite(geometry.seed, nil) == nil then
    return false, "rainbow geometry needs a finite seed"
  end
  return true
end

local function validateDrawCommand(packet, expectedKind, context)
  if type(context) ~= "table" then
    return false, "draw command needs the current borrowed render context"
  end
  if type(packet) ~= "table" then return false, "draw command must be a table" end
  if packet.kind ~= expectedKind then
    return false, ("draw.%s received a %s command")
      :format(expectedKind, tostring(packet.kind))
  end
  if packet.schemaVersion ~= 1 then
    return false, "draw command.schemaVersion must be 1"
  end
  if not validCacheKey(packet.cacheKey) then
    return false, "draw command.cacheKey must be 1..64 safe ASCII bytes"
  end
  if not validOpaqueTexture(packet.texture) then
    return false, "draw command.texture must be an opaque borrowed resource, not a path string"
  end

  -- The final vendored dispatcher performs the complete shared baseline
  -- validation. Keep this adapter guard so the frozen wire rules also hold
  -- when an older dispatcher is loaded during a local amendment test.
  if type(API.validate_draw_command) == "function" then
    local called, accepted, err = pcall(API.validate_draw_command, packet, expectedKind)
    if not called then return false, tostring(accepted) end
    if accepted ~= true then return false, tostring(err or "invalid draw command") end
  end
  return true
end

local function runDraw(callback)
  local ok, result, err = xpcall(callback, function(message) return tostring(message) end)
  if not ok then return false, tostring(result) end
  if result ~= true then return false, tostring(err or "draw command was rejected") end
  return true
end

local function makeDrawFacade(self)
  return {
    mesh = function(packet, context)
      local valid, validationError = validateDrawCommand(packet, "mesh", context)
      if not valid then return false, validationError end
      valid, validationError = validateMeshGeometry(packet.geometry)
      if not valid then return false, validationError end
      valid, validationError = validateCommandSignature(self, packet)
      if not valid then return false, validationError end
      local budgeted, budgetError = useDrawBudget(self, 1)
      if not budgeted then return false, budgetError end
      return runDraw(function()
        local geometry = packet.geometry
        if geometry.primitive == "world_apron" then
          local baseWidth = clamp(geometry.width, 0.01,
            MAX_PRIMITIVE_SIZE, 16)
          local baseDepth = clamp(geometry.depth, 0.01,
            MAX_PRIMITIVE_SIZE, 16)
          local skirt = clamp(geometry.skirtDepth, 0,
            MAX_PRIMITIVE_SIZE * 0.5, 0)
          geometry = shallowCopy(geometry)
          geometry.primitive = "plane"
          geometry.width = baseWidth + skirt * 2
          geometry.depth = baseDepth + skirt * 2
          geometry.x = finite(geometry.x, baseWidth * 0.5)
          geometry.y = finite(geometry.y, -0.5)
          geometry.z = finite(geometry.z, baseDepth * 0.5)
        end
        drawItem(self, geometry, geometry, packet.material, packet.texture, context)
        return true
      end)
    end,
    instances = function(packet, context)
      local valid, validationError = validateDrawCommand(packet, "instances", context)
      if not valid then return false, validationError end
      if type(packet) ~= "table" or type(packet.prototype) ~= "table"
          or type(packet.items) ~= "table" then
        return false, "instance command needs prototype and items"
      end
      if not INSTANCE_PRIMITIVES[packet.prototype.primitive] then
        return false, "unsupported Battle Art instance primitive: "
          .. tostring(packet.prototype.primitive)
      end
      if #packet.items < 1 or #packet.items > MAX_PACKET_ITEMS then
        return false, "instance command item count must be 1.." .. MAX_PACKET_ITEMS
      end
      for _, item in ipairs(packet.items) do
        if type(item) ~= "table" then return false, "instance item must be a table" end
      end
      valid, validationError = validateCommandSignature(self, packet)
      if not valid then return false, validationError end
      local budgeted, budgetError = useDrawBudget(self, #packet.items)
      if not budgeted then return false, budgetError end
      return runDraw(function()
        for _, item in ipairs(packet.items) do
          drawItem(self, packet.prototype, item, packet.material, packet.texture,
            context)
        end
        return true
      end)
    end,
    billboards = function(packet, context)
      local valid, validationError = validateDrawCommand(packet, "billboards", context)
      if not valid then return false, validationError end
      local items = packet.items
      if packet.procedural ~= nil then
        items, validationError = starItems(packet.procedural)
        if not items then return false, validationError end
      elseif type(items) ~= "table" then
        return false, "billboard command needs explicit items or procedural stars"
      end
      if #items < 1 or #items > MAX_PACKET_ITEMS then
        return false, "billboard command item count must be 1.." .. MAX_PACKET_ITEMS
      end
      for _, item in ipairs(items) do
        if type(item) ~= "table" then return false, "billboard item must be a table" end
      end
      valid, validationError = validateCommandSignature(self, packet)
      if not valid then return false, validationError end
      local budgeted, budgetError = useDrawBudget(self, #items)
      if not budgeted then return false, budgetError end
      local baseWidth, baseHeight = 3, 5
      local material = tostring(packet.material or "")
      if material:find("bird", 1, true) then baseWidth, baseHeight = 5, 3 end
      if material:find("aircraft", 1, true) then baseWidth, baseHeight = 12, 4 end
      if material:find("rain", 1, true) then baseWidth, baseHeight = 0.6, 8 end
      if material:find("sun_shaft", 1, true) then baseWidth = 8 end
      return runDraw(function()
        for _, item in ipairs(items) do
          local prototype = {
            primitive = "billboard",
            width = finite(item.width, baseWidth),
            height = finite(item.height, baseHeight),
          }
          drawItem(self, prototype, item, packet.material, packet.texture, context)
        end
        return true
      end)
    end,
  }
end

local function cellClass(map, shapes, x, z)
  local tile = map:cellTile(x, z)
  local shape = tile ~= nil and shapes[tile] or nil
  return tile, shape and shape.class or "ground", shape and shape.h or 0
end

local function annotatedVisualObject(map, id)
  local inspect = ChunkMesher.visualObjectAnnotated
  if type(inspect) ~= "function" then return false end
  local ok, annotated = pcall(inspect, map, id)
  return ok and annotated == true
end

local function appendVisualObjects(map, role, offsetX, offsetZ, byId, counts, scan)
  if type(map) ~= "table" or type(map.id) ~= "string" or not map.tileset then return end
  local width = integer(map.widthCells, nil)
    or integer(map.def and map.def.width, 0) * 2
  local height = integer(map.heightCells, nil)
    or integer(map.def and map.def.height, 0) * 2
  if width < 1 or height < 1 or width * height > MAX_CELLS then return end
  local shapes = TileShape.forMap(map)
  local tilesetId = boundedText(map.tileset.id, "unknown", 64)
  if not tilesetId:match("^[A-Za-z0-9._%-]+$") then tilesetId = "unknown" end
  for z = 0, height - 1 do
    for x = 0, width - 1 do
      local _, class = cellClass(map, shapes, x, z)
      if class == "signpost" then
        scan.count = scan.count + 1
        if scan.count > MAX_VISUAL_OBJECTS then return end
        local id = VisualObjects.id("BATTLE_ART_VOXEL_FORK",
          "signpost", map.id, x, z)
        if id and annotatedVisualObject(map, id) then
          counts[id] = (counts[id] or 0) + 1
          if counts[id] > 1 then
            -- The public ID names map data, not one rendered placement. If the
            -- same map/cell appears twice, no single replacement transform is
            -- authoritative. Omit the descriptor so ownership fails closed.
            byId[id] = nil
          else
            local localX, localY, localZ = x * 16 + 8, 0, z * 16 + 12
            byId[id] = {
              schemaVersion = 1,
              id = id,
              kind = "signpost",
              tags = { "host_geometry", "signpost", "visual_object" },
              map = {
                id = map.id,
                role = role,
                offsetX = offsetX,
                offsetZ = offsetZ,
              },
              cell = { x = x, z = z },
              transform = {
                localPosition = { x = localX, y = localY, z = localZ },
                worldPosition = {
                  x = localX + offsetX,
                  y = localY,
                  z = localZ + offsetZ,
                },
                rotation = { yaw = 0, pitch = 0, roll = 0 },
                scale = { x = 1, y = 1, z = 1 },
              },
              pivot = { kind = "bottom_center", x = 0, y = 0, z = 0 },
              dimensions = { width = 16, height = 16, depth = 2 },
              material = {
                id = "host:tileset:" .. tilesetId .. ":signpost",
                phase = "opaque_after_terrain",
                opaque = true,
                alphaCutout = true,
                castsShadow = true,
                receivesShadow = true,
              },
            }
          end
        end
      end
    end
  end
end

local function addWorldTags(tags, map)
  local def = map and map.def or {}
  local mapId = tostring(map and map.id or ""):upper()
  local tilesetId = tostring(map and map.tileset and map.tileset.id
    or def.tileset or ""):upper()
  local outdoor = false
  local ok, result = pcall(Map.isOutdoor, def)
  if ok then outdoor = result == true end
  local cave = tilesetId:find("CAVERN", 1, true)
    or tilesetId:find("CAVE", 1, true)
    or mapId:find("ROCK_TUNNEL", 1, true)
  if cave then tags.cave = true
  elseif outdoor then tags.outdoor = true
  else tags.interior, tags.building = true, true end
  if DayNight.isCanopy(map) or mapId:find("FOREST", 1, true) then
    tags.forest, tags.canopy = true, true
  end
  if mapId:find("LAVENDER", 1, true) or mapId:find("POKEMON_TOWER", 1, true) then
    tags.lavender = true
  end
  if DayNight.tod() == "NIGHT" then tags.night = true end
end

local function cellRecord(map, shapes, x, z, worldTags)
  local tile, class, shapeHeight = cellClass(map, shapes, x, z)
  local walkable = map:isWalkableCell(x, z) == true
  local water = map:isWaterCell(x, z) == true
  local grass = map:isGrassCell(x, z) == true
  local warp = map:warpAtCell(x, z) or map:isWarpTileCell(x, z)
  local tags = { [class] = true }
  if worldTags.interior then tags.interior, tags.room = true, true end
  if worldTags.cave then tags.cave = true end
  if worldTags.forest then tags.forest = true end
  if water then tags.water = true end
  if grass then tags.grass = true end
  if warp then tags.door = true end
  if (class == "tree" or class == "canopy") and not walkable and not water then
    tags.tree = true
  end
  if class == "flower" then tags.flower = true end
  if class == "wall" or class == "tree" or class == "cliff" then
    tags.object = true
  end
  return {
    x = x,
    z = z,
    worldY = math.max(0, finite(shapeHeight, 0)),
    height = finite(shapeHeight, 0),
    kind = class,
    material = table.concat({ "tileset", tostring(map.tileset and map.tileset.id
      or "unknown"), class, tostring(tile or -1) }, ":"),
    solid = not walkable and not water,
    walkable = walkable,
    tags = tags,
    metadata = { tile = tile, class = class },
  }
end

local function cellAt(cells, width, height, x, z)
  if x < 0 or z < 0 or x >= width or z >= height then return nil end
  return cells[z * width + x + 1]
end

local function stableObstacle(cell)
  return cell ~= nil and cell.solid == true and cell.walkable ~= true
    and not (cell.tags and cell.tags.water)
end

local function nearClass(cells, width, height, cell, class, radius)
  for dz = -radius, radius do
    for dx = -radius, radius do
      if dx ~= 0 or dz ~= 0 then
        local neighbor = cellAt(cells, width, height,
          cell.x + dx, cell.z + dz)
        if neighbor and neighbor.metadata
            and neighbor.metadata.class == class then
          return true
        end
      end
    end
  end
  return false
end

local function nearTag(cells, width, height, cell, tag, radius)
  for dz = -radius, radius do
    for dx = -radius, radius do
      if dx ~= 0 or dz ~= 0 then
        local neighbor = cellAt(cells, width, height,
          cell.x + dx, cell.z + dz)
        if neighbor and neighbor.tags and neighbor.tags[tag] then return true end
      end
    end
  end
  return false
end

local function inConnectionBand(def, width, height, cell)
  local connections = type(def) == "table" and def.connections or nil
  if type(connections) ~= "table" then return false end
  return (connections.north and cell.z < 2)
    or (connections.south and cell.z > height - 3)
    or (connections.west and cell.x < 2)
    or (connections.east and cell.x > width - 3)
    or false
end

-- Add only host-proven semantic roles. Seeds and support candidates use the
-- corrected KFP 1.60 mountain gates: authored OVERWORLD rock ids start a
-- bounded four-neighbor flood through upright, solid cells. Roof proximity
-- rejects every candidate; door proximity rejects only non-seed support so a
-- real cave mouth can retain its rock shoulders. Unknowns fail closed.
local function applySemanticTags(cells, width, height, map, worldTags)
  if not (worldTags and worldTags.outdoor) then return end
  local def = map and map.def or {}
  local tilesetId = tostring(map and map.tileset and map.tileset.id
    or def.tileset or ""):upper()
  local semantic = SEMANTIC_TILESETS[tilesetId]
  if not semantic then return end

  local mountainCandidates = {}
  local mountainSeeds = {}
  local queue, distance = {}, {}
  local cardinalX = { -1, 1, 0, 0 }
  local cardinalZ = { 0, 0, -1, 1 }
  for index, cell in ipairs(cells) do
    local metadata = cell.metadata or {}
    local tile, class = metadata.tile, metadata.class
    if stableObstacle(cell) and class == "cylinder" then
      if semantic.tree_support[tile] then
        cell.tags.tree_support = true
        cell.tags.tree = true
        cell.tags.object = true
      elseif semantic.boulder_tree[tile] then
        cell.tags.boulder_tree = true
        cell.tags.boulder = true
        cell.tags.object = true
      end
    end

    if stableObstacle(cell) and (class == "wall" or class == "cliff")
        and not inConnectionBand(def, width, height, cell)
        and not nearClass(cells, width, height, cell, "roof", MOUNTAIN_REACH)
    then
      local seed = semantic.mountain_seed[tile] == true
      if seed or not nearTag(cells, width, height, cell,
          "door", MOUNTAIN_REACH) then
        mountainCandidates[index] = true
        if seed then
          mountainSeeds[index] = true
          distance[index] = 0
          queue[#queue + 1] = index
        end
      end
    end
  end

  local head = 1
  while queue[head] do
    local index = queue[head]
    head = head + 1
    local cell = cells[index]
    if distance[index] < MOUNTAIN_REACH then
      for direction = 1, 4 do
        local nextCell = cellAt(cells, width, height,
          cell.x + cardinalX[direction], cell.z + cardinalZ[direction])
        local nextIndex = nextCell and nextCell.z * width + nextCell.x + 1
        if nextIndex and mountainCandidates[nextIndex]
            and distance[nextIndex] == nil then
          distance[nextIndex] = distance[index] + 1
          queue[#queue + 1] = nextIndex
        end
      end
    end
  end

  for index in pairs(distance) do
    local tags = cells[index].tags
    tags.mountain_support = true
    tags.mountain = true
    tags.object = true
    if mountainSeeds[index] then tags.mountain_seed = true end
  end
end

local function poseOf(entity)
  entity = type(entity) == "table" and entity or {}
  local px = finite(entity.px, finite(entity.x, 0))
  local pz = finite(entity.py, finite(entity.y, 0))
  return {
    x = px + 8,
    y = finite(entity.gh, 0) + finite(entity.lift, 0),
    z = pz + 8,
    cellX = integer(entity.cellX, math.floor(px / 16)),
    cellZ = integer(entity.cellY, math.floor(pz / 16)),
    facing = boundedText(entity.facing, "down", 16),
  }
end

local function currentGameVersion()
  local ok, Game = pcall(require, "src.core.Game")
  local version = ok and Game and Game.save and Game.save.version
  if version == "red" or version == "blue" or version == "yellow" then
    return version
  end
  return nil
end

local function snapshotFor(self)
  local state, map = self.state, self.state and self.state.map
  if not (state and map and map.id and map.tileset) then
    return nil, "overworld map is unavailable"
  end
  local game = currentGameVersion()
  if not game then return nil, "Gen 1 game identity is unavailable" end
  local width = integer(map.widthCells, nil)
    or integer(map.def and map.def.width, 0) * 2
  local height = integer(map.heightCells, nil)
    or integer(map.def and map.def.height, 0) * 2
  if width < 1 or height < 1 or width * height > MAX_CELLS then
    return nil, "world dimensions exceed the companion limit"
  end

  local tags = {}
  addWorldTags(tags, map)
  local shapes = TileShape.forMap(map)
  local cells = {}
  for z = 0, height - 1 do
    for x = 0, width - 1 do
      cells[#cells + 1] = cellRecord(map, shapes, x, z, tags)
    end
  end
  applySemanticTags(cells, width, height, map, tags)

  local actors = {}
  for index, entity in ipairs(state.entities or {}) do
    if entity ~= state.player and #actors < MAX_ACTORS then
      actors[#actors + 1] = {
        id = boundedText(entity.id or entity.objectId, tostring(index), 128),
        kind = boundedText(entity.kind, "npc", 64),
        pose = poseOf(entity),
        tags = {},
      }
    end
  end

  local neighbors = {}
  for index = 1, math.min(#(state.neighbors or {}), MAX_NEIGHBORS) do
    local neighbor = state.neighbors[index]
    if neighbor and neighbor.map and neighbor.map.id then
      neighbors[#neighbors + 1] = {
        id = tostring(neighbor.map.id),
        revision = self.revision,
        offsetX = finite(neighbor.ox, 0),
        offsetZ = finite(neighbor.oy, 0),
        atlas = tostring(neighbor.map.tileset and neighbor.map.tileset.id or ""),
        tilesetRevision = tostring(neighbor.map.tileset and neighbor.map.tileset.id or "0"),
        tags = {},
      }
    end
  end


  local visualObjects, visualById, visualCounts = {}, {}, {}
  local visualScan = { count = 0 }
  appendVisualObjects(map, "current", 0, 0,
    visualById, visualCounts, visualScan)
  for index = 1, math.min(#(state.neighbors or {}), MAX_NEIGHBORS) do
    local neighbor = state.neighbors[index]
    if neighbor and neighbor.map then
      appendVisualObjects(neighbor.map, "neighbor",
        finite(neighbor.ox, 0), finite(neighbor.oy, 0),
        visualById, visualCounts, visualScan)
    end
  end
  for _, object in pairs(visualById) do
    visualObjects[#visualObjects + 1] = object
  end
  table.sort(visualObjects, function(a, b) return a.id < b.id end)

  local mode = "diorama"
  if Voxel.isFirstPerson() then mode = "first_person"
  elseif Voxel.isThirdPerson() then mode = "third_person" end
  return {
    id = tostring(map.id),
    revision = self.revision,
    game = game,
    width = width,
    height = height,
    cellSize = 16,
    paletteRevision = tostring(DayNight.tod()),
    tilesetRevision = tostring(map.tileset.id or "0"),
    atlasRevision = tostring(map.tileset.image or map.tileset.id or "0"),
    mode = mode,
    tags = tags,
    player = poseOf(state.player),
    actors = actors,
    neighbors = neighbors,
    visualObjects = visualObjects,
    cells = cells,
    time = finite(DayNight.time(), 0),
    weather = "clear",
  }
end

local function cameraContext(self)
  local camera = Voxel3D.camera
  local eye = camera and camera.eye or Voxel3D.eye
  local mode = Voxel.isFirstPerson() and "first_person"
    or (Voxel.isThirdPerson() and "third_person" or "diorama")
  return {
    mode = mode,
    eye = eye and { eye[1], eye[2], eye[3] } or nil,
    focus = camera and { camera.focus[1], camera.focus[2], camera.focus[3] } or nil,
    fov = camera and camera.fov or Voxel3D.fovY,
  }
end

local function updateFrame(self, dt)
  local state, player = self.state, self.state and self.state.player
  local px = player and finite(player.px, nil)
  local pz = player and finite(player.py, nil)
  local speed = 0
  if px and pz and self.lastPlayerX and self.lastPlayerZ and dt > 0 then
    local dx, dz = px - self.lastPlayerX, pz - self.lastPlayerZ
    speed = math.sqrt(dx * dx + dz * dz) / dt
  end
  self.lastPlayerX, self.lastPlayerZ = px, pz
  return {
    index = self.frameIndex,
    dt = dt,
    qualityTier = "BALANCED",
    platform = self.platform,
    playerSpeed = speed,
    mapId = state and state.map and state.map.id or nil,
    time = DayNight.time(),
  }
end

local hasOpaqueHandler, wrapSpec, VisualHandle

function VoxelCompanion.new(options)
  options = options or {}
  local mod = options.mod or V.mod
  assert(type(mod) == "table" and type(mod.read) == "function",
    "VoxelCompanion needs a mod reader")

  local self = setmetatable({
    mod = mod,
    integrity = scanIntegrity(mod),
    platform = platformName(),
    state = nil,
    mapIdentity = nil,
    timeIdentity = nil,
    revision = 0,
    snapshot = nil,
    worldPending = false,
    started = false,
    attached = false,
    startContext = nil,
    frame = { dt = 0, qualityTier = "BALANCED", platform = platformName() },
    frameDraws = 0,
    meshes = {},
    texture = nil,
    commandSignatures = {},
    commandSignatureOrder = {},
    commandSignatureCount = 0,
    commandSignatureNext = 1,
    diagnostics = {},
    clock = 0,
    frameIndex = 0,
    nextSnapshotAttempt = 0,
    lastSnapshotError = nil,
    callbackDepth = 0,
    callbackRecord = nil,
    callbackStage = nil,
    visualSources = {},
  }, VoxelCompanion)

  self.visuals = VisualObjects.new({
    claimAllowed = function(record)
      local status = record.raw and record.raw:status() or nil
      if not status or status.state == "disposed" or status.faulted then
        return nil, "extension cannot claim visual objects in its current state"
      end
      if self.callbackDepth > 0
          and not (self.callbackRecord == record
            and self.callbackStage == "map_changed") then
        return nil, "visual object claims are allowed only outside dispatch or during the owner's worldChanged callback"
      end
      return true
    end,
  })

  self.draw = makeDrawFacade(self)
  self.materials = {
    color = function(_, id)
      local color = colorFor(id)
      return { color[1], color[2], color[3], color[4] }
    end,
  }
  self.world = {
    snapshot = function()
      if not self.snapshot then
        local ok, source, err = pcall(snapshotFor, self)
        if not ok then return nil, tostring(source) end
        if not source then return nil, err end
        self.snapshot = source
      end
      return copySnapshot(self.snapshot)
    end,
  }
  self.quality = {
    tier = "BALANCED",
    platform = self.platform,
    getTier = function() return "BALANCED" end,
    getPlatform = function() return self.platform end,
  }
  self.integrityFacade = {
    status = function() return copyIntegrity(self.integrity) end,
  }

  self.dispatcher = API.new({
    host_id = "BATTLE_ART_VOXEL_FORK",
    host_version = "1.9.7",
    capabilities = DISPATCH_CAPABILITIES,
    max_extensions = 32,
    max_errors = 64,
    logger = function(event)
      local message = type(event) == "table" and event.message or tostring(event)
      rememberDiagnostic(self, message)
      loggerCall(mod, "error", "Voxel Companion: " .. tostring(message))
    end,
  })

  local raw = self.dispatcher:provider()
  self.provider = raw
  raw.capabilities.visual_object_overrides = 1
  local register = raw.register
  raw.register = function(spec)
    self.integrity = scanIntegrity(mod)
    if not self.integrity.clean then
      local finding = self.integrity.findings[1]
      local message = "legacy KFP splice markers detected"
      if finding then message = message .. " in " .. finding.path end
      loggerCall(mod, "error", "Voxel Companion registration refused: " .. message)
      return nil, message .. "; reinstall a clean voxel host"
    end
    local phases = type(spec) == "table" and spec.phases or nil
    local render = type(spec) == "table" and spec.render or nil
    if (type(phases) == "table" and phases.shadow_casters ~= nil)
        or (type(render) == "table" and render.shadow_casters ~= nil) then
      return nil, "shadow_casters requires unavailable shadow_pass capability"
    end
    if (type(phases) == "table" and phases.battle_opaque ~= nil)
        or (type(render) == "table" and render.battle_opaque ~= nil) then
      return nil, "battle_opaque requires unavailable battle_pass capability"
    end
    local existing = type(spec) == "table" and self.visualSources[spec] or nil
    if existing and existing.raw:status().state ~= "disposed" then return existing end
    local id = type(spec) == "table" and spec.id or nil
    local record = self.visuals:addRecord(id, hasOpaqueHandler(spec))
    local wrapped = wrapSpec(self, spec, record)
    -- Use the byte-frozen reference provider closure. The wrapper removes only
    -- this host extension's capability token and adds the optional claim method
    -- to the returned handle.
    local rawHandle, err = register(wrapped)
    if not rawHandle then self.visuals:remove(record); return nil, err end
    record.raw = rawHandle
    local handle = setmetatable({ host = self, raw = rawHandle, record = record },
      VisualHandle)
    self.visualSources[spec] = handle
    return handle
  end
  return self
end

function VoxelCompanion:_context()
  return {
    world = self.world,
    camera = cameraContext(self),
    frame = self.frame,
    materials = self.materials,
    draw = self.draw,
  }
end

function VoxelCompanion:start()
  if self.started then return true end
  if not self.attached then
    local ok, err = self.dispatcher:attach({
      world = self.world,
      materials = self.materials,
      draw = self.draw,
      quality = self.quality,
      integrity = self.integrityFacade,
    })
    if not ok then return nil, err end
    self.attached = true
  end
  self.startContext = self:_context()
  local report, err = self.dispatcher:start(self.startContext)
  if not report then return nil, err end
  self.started = true
  return report
end

function VoxelCompanion:_observeState(state)
  if type(state) == "table" and type(state.map) == "table" then self.state = state end
  local map = self.state and self.state.map
  local mapIdentity = map and (tostring(map.id) .. ":" .. tostring(map)) or "none"
  local timeIdentity = tostring(DayNight.tod())
  local changed = mapIdentity ~= self.mapIdentity
    or timeIdentity ~= self.timeIdentity
  if changed then
    self.mapIdentity, self.timeIdentity = mapIdentity, timeIdentity
    self:worldChanged("observed_world_identity")
  end
  return changed
end

-- Mark copied world facts stale without touching host geometry or adapter GPU
-- resources. Repeated edits before the next update coalesce into one revision
-- and one canonical worldChanged callback.
function VoxelCompanion:worldChanged(reason)
  if not self.worldPending then self.revision = self.revision + 1 end
  self.snapshot = nil
  self.worldPending = true
  self.nextSnapshotAttempt = 0
  self.worldChangeReason = boundedText(reason, "host_world_changed", 128)
  return true
end

function VoxelCompanion:update(dt, state)
  dt = math.max(0, math.min(0.1, finite(dt, 0)))
  self.clock = self.clock + dt
  self.frameIndex = self.frameIndex + 1
  local changed = self:_observeState(state)
  self.frame = updateFrame(self, dt)
  self.frameDraws = 0
  if not self.started then return false end
  if (changed or self.worldPending) and self.state and self.state.map
      and self.clock >= self.nextSnapshotAttempt then
    local snapshot, snapshotError = self.world.snapshot()
    if snapshot then
      local cataloged, catalogError = self.visuals:setCatalog(
        snapshot.visualObjects or {})
      if cataloged then
        local report, dispatchError = self.dispatcher:world_changed(snapshot)
        if report then
          self.worldPending = false
          self.worldChangeReason = nil
          self.lastSnapshotError = nil
        else
          snapshotError = dispatchError
        end
      else
        snapshotError = catalogError
      end
    end
    if not snapshot or self.worldPending then
      self.nextSnapshotAttempt = self.clock + 1
      snapshotError = tostring(snapshotError or "snapshot dispatch failed")
      if snapshotError ~= self.lastSnapshotError then
        self.lastSnapshotError = snapshotError
        rememberDiagnostic(self, "world snapshot: " .. snapshotError)
        loggerCall(self.mod, "warn", "Voxel Companion world snapshot: "
          .. snapshotError)
      end
    end
  end
  return self.dispatcher:update(self.frame)
end

-- Pump the adapter from the engine's public core.update hook. The companion
-- starts during mods.loaded, before Game.overworld necessarily has a map, so
-- the first calls can legitimately have no state. A later call observes the
-- live overworld and dispatches the pending normalized snapshot.
function VoxelCompanion:updateFromGame(dt, game)
  local state = type(game) == "table" and game.overworld or nil
  return self:update(dt, state)
end

function VoxelCompanion:cameraDelta(state)
  self:_observeState(state)
  if not self.started then return nil end
  local delta = self.dispatcher:modifyCamera(cameraContext(self))
  return delta
end

local function pack(...)
  return { n = select("#", ...), ... }
end

local unpackValues = table.unpack or unpack

local function callExtension(self, record, stage, handler, ...)
  local previousRecord, previousStage = self.callbackRecord, self.callbackStage
  local previousDepth = self.callbackDepth or 0
  self.callbackRecord, self.callbackStage = record, stage
  self.callbackDepth = previousDepth + 1
  local args = pack(...)
  local ok, result = xpcall(function()
    return pack(handler(unpackValues(args, 1, args.n)))
  end, function(problem) return problem end)
  self.callbackRecord, self.callbackStage = previousRecord, previousStage
  self.callbackDepth = previousDepth
  if not ok then error(result, 0) end
  return unpackValues(result, 1, result.n)
end

local function copyTable(source)
  local out = {}
  for key, value in pairs(source or {}) do out[key] = value end
  return out
end

local function defensiveSnapshot(source)
  local plain = {}
  for _, key in ipairs({
    "id", "revision", "game", "width", "height", "cellSize",
    "paletteRevision", "tilesetRevision", "atlasRevision", "mode", "tags",
    "player", "actors", "neighbors", "visualObjects", "cells", "time",
    "weather",
  }) do
    plain[key] = source[key]
  end
  return copySnapshot(plain)
end

local function filterVisualCapability(source)
  if type(source) ~= "table" then return source end
  local out, write = {}, 0
  for index = 1, #source do
    if source[index] ~= "visual_object_overrides" then
      write = write + 1
      out[write] = source[index]
    end
  end
  for key, value in pairs(source) do
    if type(key) ~= "number" or key < 1 or key > #source
        or key ~= math.floor(key) then
      out[key] = value
    end
  end
  return out
end

hasOpaqueHandler = function(spec)
  return type(spec) == "table"
    and ((type(spec.render) == "table"
          and type(spec.render.opaque_after_terrain) == "function")
      or (type(spec.phases) == "table"
          and type(spec.phases.opaque_after_terrain) == "function"))
end

local function wrapCallbackTable(self, record, source, prefix, snapshotPhase)
  if type(source) ~= "table" then return source end
  local out = copyTable(source)
  for name, handler in pairs(source) do
    if type(handler) == "function" then
      local callbackName, callback = name, handler
      out[callbackName] = function(...)
        local args = pack(...)
        if snapshotPhase and callbackName == "map_changed" then
          local snapshot, err = defensiveSnapshot(args[1])
          if not snapshot then error(err or "could not copy visual snapshot", 0) end
          args[1] = snapshot
        end
        return callExtension(self, record, prefix .. "." .. callbackName, callback,
          unpackValues(args, 1, args.n))
      end
    end
  end
  return out
end

wrapSpec = function(self, spec, record)
  if type(spec) ~= "table" then return spec end
  local out = copyTable(spec)
  out.requires = filterVisualCapability(spec.requires)
  out.optional = filterVisualCapability(spec.optional)
  out.lifecycle = wrapCallbackTable(self, record, spec.lifecycle, "lifecycle")
  out.phases = wrapCallbackTable(self, record, spec.phases, "phases", true)
  out.render = wrapCallbackTable(self, record, spec.render, "render")

  for _, name in ipairs({ "attach", "update", "modifyCamera", "terrainPatch",
                           "invalidate", "dispose" }) do
    local handler = spec[name]
    if type(handler) == "function" then
      local callbackName, callback = name, handler
      out[callbackName] = function(...)
        if callbackName == "invalidate" or callbackName == "dispose" then
          self.visuals:clear(record)
        end
        return callExtension(self, record, callbackName, callback, ...)
      end
    end
  end
  if type(spec.worldChanged) == "function" then
    local handler = spec.worldChanged
    out.worldChanged = function(snapshot, ...)
      local defensive, err = defensiveSnapshot(snapshot)
      if not defensive then error(err or "could not copy visual snapshot", 0) end
      return callExtension(self, record, "map_changed", handler, defensive, ...)
    end
  end
  if type(spec.camera) == "function" then
    local handler = spec.camera
    out.camera = function(...)
      return callExtension(self, record, "camera", handler, ...)
    end
  end
  if type(spec.terrain) == "function" then
    local handler = spec.terrain
    out.terrain = function(...)
      return callExtension(self, record, "terrain", handler, ...)
    end
  end

  local hasDispose = type(spec.dispose) == "function"
    or (type(spec.lifecycle) == "table"
        and type(spec.lifecycle.dispose) == "function")
  if not hasDispose then
    out.lifecycle = out.lifecycle or {}
    out.lifecycle.dispose = function()
      self.visuals:clear(record)
    end
  elseif type(spec.lifecycle) == "table"
      and type(spec.lifecycle.dispose) == "function" then
    local handler = spec.lifecycle.dispose
    out.lifecycle.dispose = function(...)
      self.visuals:clear(record)
      return callExtension(self, record, "lifecycle.dispose", handler, ...)
    end
  end
  return out
end

VisualHandle = {}
VisualHandle.__index = VisualHandle

function VisualHandle:id()
  return self.raw:id()
end

function VisualHandle:is_active()
  return self.raw:is_active()
end

function VisualHandle:status()
  local status = self.raw:status()
  status.visualClaims = self.host.visuals:status(self.record).visualClaims
  return status
end

function VisualHandle:claim_visual_objects(ids)
  return self.host.visuals:claim(self.record, ids)
end

function VisualHandle:invalidate(context, reason)
  local ok, err = self.raw:invalidate(context, reason)
  if ok then self.host.visuals:clear(self.record) end
  return ok, err
end

function VisualHandle:dispose(context, reason)
  local ok, err = self.raw:dispose(context, reason)
  if ok then self.host.visuals:remove(self.record) end
  return ok, err
end

function VoxelCompanion:suppressesVisualObject(id)
  return self.started and self.visuals:isSuppressed(id) or false
end

function VoxelCompanion:render(phase, state)
  if not WORLD_PHASES[phase] then return nil, "unsupported world phase" end
  self:_observeState(state)
  if not self.started then return false end
  local graphics = love and love.graphics
  if not (graphics and type(graphics.push) == "function"
      and type(graphics.pop) == "function") then
    return nil, "graphics state isolation is unavailable"
  end
  local pushed = pcall(graphics.push, "all")
  if not pushed then return nil, "could not isolate graphics state" end
  local ok, report, err = pcall(self.dispatcher.render, self.dispatcher,
    phase, self:_context())
  local popped, popError = pcall(graphics.pop)
  if not popped then
    loggerCall(self.mod, "error", "Voxel Companion graphics restore failed: "
      .. tostring(popError))
  end
  if not ok then return nil, tostring(report) end
  return report, err
end

function VoxelCompanion:invalidate(reason)
  self:worldChanged(reason or "host_invalidated")
  self.visuals:clearAll()
  for key, mesh in pairs(self.meshes) do
    if mesh and mesh.release then pcall(mesh.release, mesh) end
    self.meshes[key] = nil
  end
  if self.texture and self.texture.release then pcall(self.texture.release, self.texture) end
  self.texture = nil
  self.commandSignatures = {}
  self.commandSignatureOrder = {}
  self.commandSignatureCount = 0
  self.commandSignatureNext = 1
  if self.started then
    return self.dispatcher:invalidate(self:_context(), reason or "host_invalidated")
  end
  return true
end

function VoxelCompanion:dispose(reason)
  self:invalidate(reason or "host_dispose")
  local result, err = true, nil
  if self.started then
    result, err = self.dispatcher:dispose(self:_context(), reason or "host_dispose")
  end
  self.visuals:dispose()
  self.visualSources = {}
  self.started = false
  self.attached = false
  self.startContext = nil
  self.state = nil
  self.snapshot = nil
  self.worldPending = false
  self.worldChangeReason = nil
  self.mapIdentity = nil
  self.timeIdentity = nil
  self.lastSnapshotError = nil
  self.nextSnapshotAttempt = 0
  return result, err
end

function VoxelCompanion:status()
  local status = self.dispatcher:status()
  local visualStatus = self.visuals:status()
  status.capabilities[#status.capabilities + 1] = "visual_object_overrides"
  table.sort(status.capabilities)
  status.visualObjects = visualStatus.visualObjects
  status.visualOverrides = visualStatus.visualOverrides
  status.visualConflicts = visualStatus.visualConflicts
  status.integrity = copyIntegrity(self.integrity)
  status.revision = self.revision
  status.diagnostics = {}
  for index, message in ipairs(self.diagnostics) do status.diagnostics[index] = message end
  return status
end

VoxelCompanion.CAPABILITIES = CAPABILITIES
VoxelCompanion.LEGACY_MARKERS = LEGACY_MARKERS
VoxelCompanion.LIMITS = {
  cells = MAX_CELLS,
  actors = MAX_ACTORS,
  neighbors = MAX_NEIGHBORS,
  visualObjects = MAX_VISUAL_OBJECTS,
  packetItems = MAX_PACKET_ITEMS,
  frameDraws = MAX_DRAWS_PER_FRAME,
  commandSignatures = MAX_COMMAND_SIGNATURES,
}

return VoxelCompanion
