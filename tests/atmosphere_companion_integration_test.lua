-- Focused standalone contract tests for the Voxel Companion API v1 host.

local checks = 0

local function check(value, message)
  checks = checks + 1
  if not value then error("FAIL: " .. message, 0) end
end

local function equal(actual, expected, message)
  checks = checks + 1
  if actual ~= expected then
    error(("FAIL: %s (expected %s, got %s)")
      :format(message, tostring(expected), tostring(actual)), 0)
  end
end

local function contains(text, fragment, message)
  check(type(text) == "string" and text:find(fragment, 1, true) ~= nil, message)
end

local function treeSignature(value)
  if type(value) ~= "table" then
    if type(value) == "number" then return string.format("%.12g", value) end
    return tostring(value)
  end
  local out = { "[" }
  for index = 1, #value do out[#out + 1] = treeSignature(value[index]) end
  out[#out + 1] = "]"
  return table.concat(out, ",")
end

local function findTagged(value, tag, out)
  out = out or {}
  if type(value) ~= "table" then return out end
  if value[1] == tag then out[#out + 1] = value end
  for index = 1, #value do findTagged(value[index], tag, out) end
  return out
end

local API = assert(loadfile("lib/VoxelCompanionAPI.lua"))()
equal(API.VERSION, 1, "vendored dispatcher reports API v1")
local VisualObjects = assert(loadfile("lib/VoxelVisualObjects.lua"))()
local DrawFixture = assert(loadfile("tests/fixtures/voxel_companion_draw_v1.lua"))()

local function newRunningDispatcher()
  local dispatcher = API.new({ capabilities = {} })
  check(dispatcher:attach({}), "fault-cleanup dispatcher attaches")
  check(dispatcher:start({}), "fault-cleanup dispatcher starts")
  return dispatcher
end

local function attemptCleanupReentry(dispatcher, id)
  local attempts = {}
  attempts.dispatch, attempts.dispatchError = dispatcher:dispatch("update", {})
  attempts.register, attempts.registerError = dispatcher:register({
    api = 1,
    id = "cleanup.reentry." .. id,
    lifecycle = { start = function() end },
  }, {})
  attempts.dispose, attempts.disposeError = dispatcher:dispose({}, "cleanup-reentry")
  return attempts
end

local function expectCleanupReentryBlocked(attempts)
  equal(attempts.dispatch, nil, "fault cleanup cannot reenter dispatch")
  contains(attempts.dispatchError, "reentrant dispatch",
    "fault cleanup reports blocked dispatch reentry")
  equal(attempts.register, nil, "fault cleanup cannot register an extension")
  contains(attempts.registerError, "register during dispatch",
    "fault cleanup reports blocked registration")
  equal(attempts.dispose, nil, "fault cleanup cannot dispose the dispatcher")
  contains(attempts.disposeError, "dispose during dispatch",
    "fault cleanup reports blocked dispatcher disposal")
end

local graphicsState = { color = "host", depth = "host", blend = "host" }
local graphicsStack = {}
local pushCount, popCount = 0, 0
local sentinelUpdate = function() end

love = {
  update = sentinelUpdate,
  system = { getOS = function() return "Windows" end },
  image = {},
  graphics = {},
}

function love.image.newImageData()
  return { setPixel = function() end }
end

function love.graphics.newImage()
  return {
    setFilter = function() end,
    release = function(self) self.released = true end,
  }
end

function love.graphics.push(kind)
  equal(kind, "all", "render isolation uses the full graphics state")
  pushCount = pushCount + 1
  graphicsStack[#graphicsStack + 1] = {
    color = graphicsState.color,
    depth = graphicsState.depth,
    blend = graphicsState.blend,
  }
end

function love.graphics.pop()
  popCount = popCount + 1
  local previous = table.remove(graphicsStack)
  assert(previous, "unbalanced graphics pop")
  graphicsState = previous
end

function love.graphics.setColor(r, g, b, a)
  graphicsState.color = table.concat({ r, g, b, a }, ":")
end

function love.graphics.setDepthMode(mode, write)
  graphicsState.depth = tostring(mode) .. ":" .. tostring(write)
end

function love.graphics.setBlendMode(mode, alpha)
  graphicsState.blend = tostring(mode) .. ":" .. tostring(alpha)
end

local fakeVoxel3D = { metalRenderer=function() return false end,
  FACE_CORNERS = {},
  FACE_SHADE = {},
  eye = { 0, 16, 32 },
  camera = {
    eye = { 8, 12, 24 },
    focus = { 8, 8, 8 },
    up = { 0, 1, 0 },
    fov = math.rad(65),
  },
  draws = 0,
  drawLog = {},
  glassState = true,
  failNextDraw = false,
}

for direction = 1, 6 do
  fakeVoxel3D.FACE_CORNERS[direction] = {
    { 0, 0, 0 }, { 1, 0, 0 }, { 1, 1, 0 }, { 0, 1, 0 },
  }
  fakeVoxel3D.FACE_SHADE[direction] = 1
end

function fakeVoxel3D.pushQuad(indices, offset)
  indices[#indices + 1] = offset
end

function fakeVoxel3D.newMesh(vertices, indices)
  return {
    vertices = vertices,
    indices = indices,
    releaseCount = 0,
    setTexture = function(self, texture)
      if texture == nil and self.failDetach then
        error("synthetic borrowed texture detach failure", 0)
      end
      self.texture = texture
    end,
    release = function(self)
      self.releaseCount = self.releaseCount + 1
      self.released = true
    end,
  }
end

function fakeVoxel3D.glass(enabled)
  fakeVoxel3D.glassState = enabled
end

function fakeVoxel3D.draw(mesh, texture, model)
  fakeVoxel3D.draws = fakeVoxel3D.draws + 1
  if texture then mesh:setTexture(texture) end
  fakeVoxel3D.drawLog[#fakeVoxel3D.drawLog + 1] = {
    mesh = mesh,
    texture = texture,
    model = model,
    color = graphicsState.color,
    depth = graphicsState.depth,
  }
  if fakeVoxel3D.failNextDraw then
    fakeVoxel3D.failNextDraw = false
    error("synthetic GPU draw failure", 0)
  end
end

local fakeMat4 = {
  mul = function(a, b) return { a, b } end,
  translate = function(x, y, z) return { "translate", x, y, z } end,
  scale = function(x, y, z) return { "scale", x, y, z } end,
  rotateY = function(value) return { "rotateY", value } end,
  rotateX = function(value) return { "rotateX", value } end,
  rotateZ = function(value) return { "rotateZ", value } end,
}

local fakeCameraMode = "first_person"
local fakeVoxelState = {
  isFirstPerson = function() return fakeCameraMode == "first_person" end,
  isThirdPerson = function() return fakeCameraMode == "third_person" end,
}

local fakeDayNight
fakeDayNight = {
  period = "DAY",
  isCanopy = function() return false end,
  tod = function() return fakeDayNight.period end,
  time = function() return 12.5 end,
}

local fakeShapes = {
  [0] = { class = "grass", h = 0 },
  [1] = { class = "wall", h = 8 },
  [2] = { class = "tree", h = 12 },
  [3] = { class = "water", h = 0 },
  [4] = { class = "signpost", h = 16 },
}

local fakeTileShape = {
  forMap = function() return fakeShapes end,
}

local fakeMapModule = {
  isOutdoor = function() return true end,
}

local fakeChunkMesher = {}
function fakeChunkMesher.visualObjectAnnotated(map, id)
  for z = 0, (map.heightCells or 0) - 1 do
    for x = 0, (map.widthCells or 0) - 1 do
      if map:cellTile(x, z) == 4
          and VisualObjects.id("BATTLE_ART_VOXEL_FORK", "signpost",
            map.id, x, z) == id then
        return true
      end
    end
  end
  return false
end

local fakeGame = { save = { version = "red" } }
package.loaded["src.world.Map"] = fakeMapModule
package.loaded["src.core.Game"] = fakeGame

local function cleanMod()
  local mod = { writes = 0, messages = {} }
  function mod:read() return "-- clean upstream host\n" end
  function mod:write()
    self.writes = self.writes + 1
    error("integrity scan must never write", 0)
  end
  mod.log = {
    error = function(_, format, value)
      mod.messages[#mod.messages + 1] = tostring(format):format(value)
    end,
  }
  return mod
end

local function namespace(mod)
  local modules = {
    AtmosphereCamera = assert(loadfile("lib/AtmosphereCamera.lua"))(),
    AtmosphereEffects = assert(loadfile('lib/AtmosphereEffects.lua'))({require=function(name) return assert(loadfile('lib/'..name..'.lua'))() end}),
    VoxelCompanionAPI = API,
    VoxelVisualObjects = VisualObjects,
    Mat4 = fakeMat4,
    TileShape = fakeTileShape,
    ChunkMesher = fakeChunkMesher,
    VoxelState = fakeVoxelState,
    Voxel3D = fakeVoxel3D,
    DayNight = fakeDayNight,
  }
  return {
    mod = mod,
    require = function(name)
      local value = modules[name]
      assert(value, "unexpected module " .. tostring(name))
      return value
    end,
  }
end

local function worldState()
  local map = {
    id = "PALLET_TOWN",
    widthCells = 2,
    heightCells = 2,
    def = { width = 1, height = 1, tileset = "OVERWORLD" },
    tileset = { id = "OVERWORLD", image = "overworld-atlas" },
  }
  function map:cellTile(x, z) return z * 2 + x end
  function map:isWalkableCell(x, z) return not (x == 1 and z == 0) end
  function map:isWaterCell(x, z) return x == 1 and z == 1 end
  function map:isGrassCell(x, z) return x == 0 and z == 0 end
  function map:warpAtCell(x, z)
    return x == 0 and z == 1 and { target = "HOUSE" } or nil
  end
  function map:isWarpTileCell() return false end
  local player = { id = "player", px = 0, py = 0, cellX = 0, cellY = 0,
    facing = "down", gh = 0 }
  return {
    map = map,
    player = player,
    entities = {
      player,
      { id = "npc-1", kind = "npc", px = 16, py = 16,
        cellX = 1, cellY = 1, facing = "up" },
    },
    neighbors = {},
  }
end


local C=assert(loadfile('lib/VoxelCompanion.lua'))(namespace(cleanMod()))

local currentMod = cleanMod()
function currentMod:read(path)
  local file = assert(io.open(path, "rb"))
  local source = file:read("*a")
  file:close()
  return source
end
local currentHost = C.new({mod=currentMod})
local currentHandle, currentError = currentHost.provider.register({
  api=1, id='current-host-integrity', update=function() end,
})
assert(currentHandle, currentError or 'current built-in host markers were rejected')
assert(currentHost:status().integrity.clean, 'current built-in markers reported contamination')

local legacyMod = cleanMod()
local contaminated = false
function legacyMod:read(path)
  if contaminated and path == "lib/VoxelScene.lua" then
    return "local function __dsMod(name, statusKey) end\n"
  end
  return "-- clean upstream host\n"
end
local legacyHost = C.new({mod=legacyMod})
contaminated = true
local refused, legacyError = legacyHost.provider.register({
  api=1, id='legacy-host-integrity', update=function() end,
})
assert(not refused, 'genuine legacy splice was accepted')
assert(legacyError:find('legacy KFP splice markers detected in lib/VoxelScene.lua', 1, true),
  'legacy rejection did not name the contaminated target')

local host=C.new{mod=cleanMod()};local h
h=assert(host.provider.register{api=1,id='weather',requires={'atmosphere_effects_draft'},update=function()
 local api=assert(h:effects());assert(api:submitAtmosphere{sky={dim=.3}})
end})
assert(host:start());host:update(.016,worldState())
assert(host:atmosphereSnapshot().sky.dim==.3,'owner update did not publish')
local api=assert(h:effects());assert(h:dispose());assert(not api:submitAtmosphere{sky={dim=.2}},'disposed handle live')
assert(next(host:atmosphereSnapshot())==nil,'disposed state retained')
print('PASS companion draft registration, update publication and disposal')
