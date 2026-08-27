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

local fakeVoxel3D = {
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

local visualRefreshes = {}
local fakeChunkMesher = {
  refreshVisualObjects = function(mapId)
    visualRefreshes[#visualRefreshes + 1] = mapId
    return true
  end,
}

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
    VoxelCompanionAPI = API,
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

local VoxelCompanion = assert(loadfile("lib/VoxelCompanion.lua"))(namespace(cleanMod()))
local mod = cleanMod()
local companion = VoxelCompanion.new({ mod = mod })
local provider = companion.provider

do
  local delayedMod = cleanMod()
  local delayed = VoxelCompanion.new({ mod = delayedMod })
  local delayedWorlds, delayedUpdates = {}, 0
  local delayedHandle, delayedError = delayed.provider.register({
    api = 1,
    id = "test.delayed-world-readiness",
    requires = { "world_snapshot" },
    worldChanged = function(snapshot)
      delayedWorlds[#delayedWorlds + 1] = {
        id = snapshot.id,
        revision = snapshot.revision,
      }
    end,
    update = function() delayedUpdates = delayedUpdates + 1 end,
  })
  check(delayedHandle, delayedError or "delayed-world extension registers")
  check(delayed:start(), "delayed-world host starts before the overworld")

  local game = {}
  check(delayed:updateFromGame(0.016, game),
    "a missing startup overworld does not fault the dispatcher")
  equal(#delayedWorlds, 0,
    "no worldChanged callback is sent before a real map exists")
  check(delayed.worldPending,
    "missing startup state keeps one world snapshot pending")

  game.overworld = worldState()
  check(delayed:updateFromGame(0.016, game),
    "the public game object supplies a later ready overworld")
  equal(#delayedWorlds, 1,
    "the first ready overworld dispatches one normalized snapshot")
  equal(delayedWorlds[1].id, "PALLET_TOWN",
    "the delayed snapshot reports the live map identity")
  check(not delayed.worldPending,
    "a successful delayed snapshot clears the pending state")

  local firstRevision = delayedWorlds[1].revision
  game.overworld = worldState()
  game.overworld.map.id = "VIRIDIAN_CITY"
  check(delayed:updateFromGame(0.016, game),
    "a replacement overworld remains observable through the same game object")
  equal(#delayedWorlds, 2,
    "a later map identity dispatches one replacement snapshot")
  equal(delayedWorlds[2].id, "VIRIDIAN_CITY",
    "the replacement snapshot reports the new live map")
  check(delayedWorlds[2].revision > firstRevision,
    "the replacement snapshot advances the adapter revision")

  delayed:worldChanged("synthetic-block-edit")
  check(delayed:updateFromGame(0.016, game),
    "an announced map revision is pumped by core lifecycle updates")
  equal(#delayedWorlds, 3,
    "an announced revision dispatches one refreshed snapshot")
  check(delayedWorlds[3].revision > delayedWorlds[2].revision,
    "the refreshed snapshot carries the newer revision")
  check(delayedUpdates >= 4,
    "extension updates continue before and after world readiness")
  check(delayed:dispose("delayed-world-test"),
    "delayed-world host disposes cleanly")
end

local function wireCommand(kind, phase, sequence, fields)
  local command = fields or {}
  command.schemaVersion = 1
  command.cacheKey = command.cacheKey or ("other.extension:%s:%d"):format(kind, sequence)
  command.kind = kind
  command.owner = command.owner or "test.extension"
  command.phase = phase
  command.sequence = sequence
  command.sortKey = command.sortKey or command.cacheKey
  command.material = command.material or "test:material"
  return command
end

do
  local function signMap(id, signX, signZ)
    local map = {
      id = id,
      widthCells = 2,
      heightCells = 2,
      def = { width = 1, height = 1, tileset = "OVERWORLD" },
      tileset = { id = "OVERWORLD", image = "synthetic-atlas" },
    }
    function map:cellTile(x, z)
      return x == signX and z == signZ and 4 or 0
    end
    function map:isWalkableCell(x, z) return not (x == signX and z == signZ) end
    function map:isWaterCell() return false end
    function map:isGrassCell() return false end
    function map:warpAtCell() return nil end
    function map:isWarpTileCell() return false end
    return map
  end

  local current = signMap("PALLET_TOWN", 1, 0)
  local neighbor = signMap("ROUTE_1", 0, 1)
  local player = { id = "player", px = 0, py = 0, cellX = 0, cellY = 0,
    facing = "down", gh = 0 }
  local visualState = {
    map = current,
    player = player,
    entities = { player },
    neighbors = { { map = neighbor, ox = 64, oy = -32 } },
  }

  local ambiguousCount
  local ambiguousHost = VoxelCompanion.new({ mod = cleanMod() })
  assert(ambiguousHost.provider.register({
    api = 1,
    id = "test.visual-ambiguous-placement",
    requires = { "world_snapshot" },
    worldChanged = function(snapshot) ambiguousCount = #snapshot.visualObjects end,
  }))
  check(ambiguousHost:start(), "ambiguous-placement host starts")
  check(ambiguousHost:update(0.016, {
    map = current,
    player = player,
    entities = { player },
    neighbors = { { map = current, ox = 64, oy = 0 } },
  }), "duplicate map placement snapshot dispatches")
  equal(ambiguousCount, 0,
    "one stable ID with two rendered transforms is omitted fail closed")
  check(ambiguousHost:dispose("ambiguous-placement-test"),
    "ambiguous-placement host disposes cleanly")

  local function visualSignature(objects)
    local out = {}
    for _, object in ipairs(objects or {}) do
      local t, d = object.transform, object.dimensions
      out[#out + 1] = table.concat({ object.id, object.map.role,
        object.map.offsetX, object.map.offsetZ, object.cell.x, object.cell.z,
        t.localPosition.x, t.localPosition.y, t.localPosition.z,
        t.worldPosition.x, t.worldPosition.y, t.worldPosition.z,
        t.rotation.yaw, t.rotation.pitch, t.rotation.roll,
        object.pivot.kind, object.pivot.x, object.pivot.y, object.pivot.z,
        d.width, d.height, d.depth, object.material.phase }, "|")
    end
    return table.concat(out, "\n")
  end

  local host = VoxelCompanion.new({ mod = cleanMod() })
  local handle, callbackClaimed, callbackClaimError
  local claimedIds, replacements, callbackModes = {}, {}, {}
  local invalidations, disposals = 0, 0
  handle = assert(host.provider.register({
    api = 1,
    id = "test.visual-owner",
    requires = { "visual_object_overrides", "world_snapshot", "render_phases" },
    worldChanged = function(snapshot)
      claimedIds, replacements = {}, {}
      for _, object in ipairs(snapshot.visualObjects or {}) do
        claimedIds[#claimedIds + 1] = object.id
        replacements[#replacements + 1] = {
          id = object.id,
          x = object.transform.worldPosition.x,
          y = object.transform.worldPosition.y + object.dimensions.height * 0.5,
          z = object.transform.worldPosition.z,
          width = object.dimensions.width,
          height = object.dimensions.height,
          depth = object.dimensions.depth,
        }
      end
      callbackClaimed, callbackClaimError = handle:claim_visual_objects(claimedIds)
    end,
    render = {
      opaque_after_terrain = function(context)
        local mode = context.camera.mode
        callbackModes[mode] = callbackModes[mode] or {}
        for index, object in ipairs(replacements) do
          local accepted, drawError = context.draw.mesh(wireCommand(
            "mesh", "opaque_after_terrain", 300 + index, {
              cacheKey = "visual.replace:" .. tostring(index),
              owner = "test.visual-owner",
              sortKey = "visual-replacement:" .. tostring(index),
              material = "test:visual-replacement",
              geometry = {
                primitive = "box", x = object.x, y = object.y, z = object.z,
                width = object.width, height = object.height, depth = object.depth,
              },
            }), context)
          if not accepted then error(drawError, 0) end
          callbackModes[mode][object.id] = fakeVoxel3D.drawLog[#fakeVoxel3D.drawLog].model
        end
      end,
    },
    invalidate = function() invalidations = invalidations + 1 end,
    dispose = function() disposals = disposals + 1 end,
  }))
  check(host:start(), "visual-object host starts")
  visualRefreshes = {}
  fakeCameraMode = "first_person"
  check(host:update(0.016, visualState), "visual-object current/neighbor snapshot dispatches")
  check(callbackClaimed, callbackClaimError or "known visual IDs are claimed")

  local first = assert(host.world.snapshot())
  equal(#first.visualObjects, 2,
    "current and rendered-neighbor signposts receive public descriptors")
  local byMap = {}
  for _, object in ipairs(first.visualObjects) do byMap[object.map.id] = object end
  local currentObject, neighborObject = byMap.PALLET_TOWN, byMap.ROUTE_1
  check(currentObject and neighborObject, "both map identities are present")
  equal(currentObject.map.role, "current", "current-map object keeps its role")
  equal(neighborObject.map.role, "neighbor", "neighbor object keeps its role")
  equal(currentObject.id,
    "BATTLE_ART_VOXEL_FORK:signpost:PALLET_TOWN:1:0",
    "current signpost ID is deterministic and safe")
  equal(neighborObject.id,
    "BATTLE_ART_VOXEL_FORK:signpost:ROUTE_1:0:1",
    "neighbor signpost ID is deterministic and safe")
  equal(currentObject.transform.localPosition.x, 24,
    "current object local transform uses its cell")
  equal(currentObject.transform.localPosition.z, 12,
    "signpost pivot uses the exact two-unit host depth band")
  equal(neighborObject.transform.localPosition.z, 28,
    "neighbor local transform remains map-local")
  equal(neighborObject.transform.worldPosition.x, 72,
    "neighbor world transform includes the connection X offset")
  equal(neighborObject.transform.worldPosition.z, -4,
    "neighbor world transform includes the connection Z offset")
  equal(currentObject.dimensions.depth, 2, "descriptor reports exact signpost depth")
  equal(currentObject.material.phase, "opaque_after_terrain",
    "descriptor reports the eligible replacement phase")
  check(currentObject.material.castsShadow and currentObject.material.receivesShadow,
    "descriptor reports host shadow material facts")
  check(host:suppressesVisualObject(currentObject.id),
    "a valid known-ID claim suppresses the current original")
  check(host:suppressesVisualObject(neighborObject.id),
    "a valid known-ID claim suppresses the neighbor original")

  local originalX = host.world.snapshot().visualObjects[1].transform.worldPosition.x
  first.visualObjects[1].transform.worldPosition.x = 9999
  equal(host.world.snapshot().visualObjects[1].transform.worldPosition.x, originalX,
    "visual descriptors are defensive data copies")

  local firstSignature = visualSignature(host.world.snapshot().visualObjects)
  check(host:render("opaque_after_terrain", visualState),
    "first-person replacement uses the normal opaque render seam")
  for _, object in ipairs(host.world.snapshot().visualObjects) do
    local translation = findTagged(callbackModes.first_person[object.id], "translate")[1]
    equal(translation[2], object.transform.worldPosition.x,
      "first-person replacement uses descriptor world X")
    equal(translation[3], object.transform.worldPosition.y + object.dimensions.height * 0.5,
      "first-person replacement derives its center from the descriptor pivot")
    equal(translation[4], object.transform.worldPosition.z,
      "first-person replacement uses descriptor world Z")
  end

  fakeCameraMode = "third_person"
  host:worldChanged("camera-mode-test")
  check(host:update(0.016, visualState), "third-person visual snapshot dispatches")
  equal(visualSignature(host.world.snapshot().visualObjects), firstSignature,
    "first- and third-person use identical IDs and transforms")
  check(host:render("opaque_after_terrain", visualState),
    "third-person replacement uses the same opaque render seam")
  for _, object in ipairs(host.world.snapshot().visualObjects) do
    equal(treeSignature(callbackModes.third_person[object.id]),
      treeSignature(callbackModes.first_person[object.id]),
      "first- and third-person replacement matrices match for " .. object.id)
  end

  local duplicateOk, duplicateError = handle:claim_visual_objects({
    currentObject.id, currentObject.id,
  })
  equal(duplicateOk, nil, "duplicate claims fail closed")
  contains(duplicateError, "duplicate id", "duplicate claim explains the fault")
  check(not host:suppressesVisualObject(currentObject.id)
      and not host:suppressesVisualObject(neighborObject.id),
    "a malformed replacement registration restores all originals for its owner")

  local malformedOk, malformedError = handle:claim_visual_objects("not-an-array")
  equal(malformedOk, nil, "malformed claim registration fails closed")
  contains(malformedError, "must be an array",
    "malformed claim registration explains the array contract")

  local invalidIdOk, invalidIdError = handle:claim_visual_objects({ "bad/id" })
  equal(invalidIdOk, nil, "malformed visual ID fails closed")
  contains(invalidIdError, "safe ASCII identifier characters",
    "malformed visual ID explains the safe-ID contract")

  local noOpaque = assert(host.provider.register({
    api = 1, id = "test.visual-no-opaque", update = function() end,
  }))
  local noOpaqueOk, noOpaqueError = noOpaque:claim_visual_objects({ currentObject.id })
  equal(noOpaqueOk, nil, "claim without the eligible render path fails closed")
  contains(noOpaqueError, "opaque_after_terrain",
    "missing render path reports the eligibility rule")
  check(not host:suppressesVisualObject(currentObject.id),
    "ineligible registration never hides the original")

  local unknownOk, unknownError = handle:claim_visual_objects({ "UNKNOWN:visual:object" })
  equal(unknownOk, nil, "unknown visual ID fails closed")
  contains(unknownError, "unknown visual object id", "unknown claim is diagnostic")
  check(not host:suppressesVisualObject(currentObject.id),
    "unknown registration leaves the known original visible")
  check(handle:claim_visual_objects(claimedIds), "valid claims can be restored")

  local contender = assert(host.provider.register({
    api = 1,
    id = "test.visual-contender",
    render = { opaque_after_terrain = function() end },
  }))
  local conflictOk, conflictError = contender:claim_visual_objects({ currentObject.id })
  equal(conflictOk, nil, "conflicting owner fails closed")
  contains(conflictError, "ownership conflict", "conflict has a deterministic diagnostic")
  check(not host:suppressesVisualObject(currentObject.id),
    "conflicting ownership keeps the current original visible")
  check(host:suppressesVisualObject(neighborObject.id),
    "conflict invalidates only the contested visual object")
  check(contender:dispose({}, "conflict-release"), "conflicting owner disposes")
  check(host:suppressesVisualObject(currentObject.id),
    "removing the contender deterministically restores the unique owner")

  check(handle:invalidate({}, "visual-invalidate"), "owner invalidation succeeds")
  check(not host:suppressesVisualObject(currentObject.id)
      and not host:suppressesVisualObject(neighborObject.id),
    "owner invalidation restores current and neighbor originals")
  check(handle:invalidate({}, "visual-invalidate-repeat"),
    "repeated owner invalidation is safe")
  equal(invalidations, 2, "existing invalidation lifecycle remains authoritative")
  check(handle:claim_visual_objects(claimedIds), "owner can reclaim known objects")
  check(handle:dispose({}, "visual-dispose"), "visual owner disposes")
  check(handle:dispose({}, "visual-dispose-repeat"), "repeated visual disposal is safe")
  equal(disposals, 1, "existing disposal lifecycle releases owner resources once")
  check(not host:suppressesVisualObject(currentObject.id)
      and not host:suppressesVisualObject(neighborObject.id),
    "owner disposal restores originals without touching another extension")
  check(#visualRefreshes >= 2,
    "ownership transitions invalidate only named visual-map terrain caches")
  check(host:dispose("visual-object-test"), "visual-object host disposes cleanly")
  fakeCameraMode = "first_person"
  pushCount, popCount = 0, 0
end

do
  local conversionCalls = 0
  local hostileKey = setmetatable({}, {
    __tostring = function()
      conversionCalls = conversionCalls + 1
      error("untrusted key conversion ran", 0)
    end,
  })
  local command = wireCommand("mesh", "background", 90, {
    geometry = { primitive = "plane", width = 1, depth = 1 },
  })
  command[hostileKey] = true

  local callOk, valid, validationError = pcall(
    API.validate_draw_command, command, "mesh")
  check(callOk, "draw validation contains hostile keys without throwing")
  equal(valid, nil, "draw validation rejects an unknown hostile key")
  contains(validationError, "<table key>",
    "draw validation labels a hostile key without converting it")

  command[hostileKey] = nil
  command.kind = hostileKey
  callOk, valid, validationError = pcall(
    API.validate_draw_command, command, "mesh")
  check(callOk, "draw kind validation contains hostile values without throwing")
  equal(valid, nil, "draw validation rejects a hostile kind")
  contains(validationError, "<table key>",
    "draw kind validation labels a hostile value without converting it")

  local dispatcher = API.new({ capabilities = {} })
  callOk, valid, validationError = pcall(
    dispatcher.dispatch, dispatcher, hostileKey, {})
  check(callOk, "dispatch phase validation contains hostile values without throwing")
  equal(valid, nil, "dispatch rejects a hostile phase")
  contains(validationError, "<table key>",
    "dispatch labels a hostile phase without converting it")
  equal(conversionCalls, 0, "untrusted key conversion callbacks never run")
end

do
  local command = wireCommand("mesh", "background", 91, {
    mesh = { id = "extension-owned-mesh" },
    texture = { id = "extension-owned-texture" },
  })
  local ok, validationError = API.validate_draw_command(command, "mesh")
  equal(ok, nil,
    "direct opaque mesh and borrowed texture cannot be combined")
  contains(validationError,
    "cannot combine an opaque mesh/resource with a texture",
    "direct mesh and texture rejection explains the unsafe ownership mix")

  command.mesh = nil
  command.resource = { id = "extension-owned-resource" }
  ok, validationError = API.validate_draw_command(command, "mesh")
  equal(ok, nil,
    "direct opaque resource and borrowed texture cannot be combined")
  contains(validationError,
    "cannot combine an opaque mesh/resource with a texture",
    "direct resource and texture rejection explains the unsafe ownership mix")
end

do
  local lifecycleCalls = {}
  local spec = {
    api = 1,
    id = "test.flat-callback-snapshot",
    invalidate = function(reason)
      lifecycleCalls[#lifecycleCalls + 1] = "invalidate:" .. reason
    end,
    dispose = function()
      lifecycleCalls[#lifecycleCalls + 1] = "dispose"
    end,
  }
  local dispatcher = API.new({ capabilities = {} })
  local handle, registerError = dispatcher:register(spec)
  check(handle, registerError or "flat callback snapshot registers")
  spec.invalidate = function() error("mutated invalidate callback ran", 0) end
  spec.dispose = function() error("mutated dispose callback ran", 0) end
  check(dispatcher:attach({}), "flat callback snapshot dispatcher attaches")
  check(dispatcher:start({}), "flat callback snapshot dispatcher starts")
  local report = dispatcher:invalidate({}, "map")
  equal(report.succeeded, 1, "captured invalidate callback succeeds")
  check(dispatcher:dispose({}, "shutdown"), "captured dispose callback succeeds")
  equal(#lifecycleCalls, 2, "only the captured lifecycle callbacks run")
  equal(lifecycleCalls[1], "invalidate:map", "captured invalidate receives its reason")
  equal(lifecycleCalls[2], "dispose", "captured dispose runs exactly once")
end

do
  local dispatcher = newRunningDispatcher()
  local attempts
  local handle, registerError = dispatcher:register({
    api = 1,
    id = "test.fault-guard-hot-attach",
    lifecycle = {
      attach = function() error("expected hot attach fault", 0) end,
      dispose = function()
        attempts = attemptCleanupReentry(dispatcher, "hot.attach")
      end,
    },
  }, {})
  check(handle, registerError or "hot attach fault registration returns its handle")
  check(handle:status().faulted, "hot attach failure faults only its extension")
  expectCleanupReentryBlocked(attempts)
  equal(dispatcher:status().state, "running",
    "hot attach fault cleanup leaves the dispatcher running")
  check(dispatcher:dispose({}, "test-end"),
    "hot attach fault-cleanup dispatcher disposes normally")
end

do
  local dispatcher = newRunningDispatcher()
  local attempts
  local handle, registerError = dispatcher:register({
    api = 1,
    id = "test.fault-guard-hot-start",
    lifecycle = {
      start = function() error("expected hot start fault", 0) end,
      dispose = function()
        attempts = attemptCleanupReentry(dispatcher, "hot.start")
      end,
    },
  }, {})
  check(handle, registerError or "hot start fault registration returns its handle")
  check(handle:status().faulted, "hot start failure faults only its extension")
  expectCleanupReentryBlocked(attempts)
  equal(dispatcher:status().state, "running",
    "hot start fault cleanup leaves the dispatcher running")
  check(dispatcher:dispose({}, "test-end"),
    "hot start fault-cleanup dispatcher disposes normally")
end

do
  local dispatcher = newRunningDispatcher()
  local attempts
  local handle, registerError = dispatcher:register({
    api = 1,
    id = "test.fault-guard-handle-invalidate",
    lifecycle = {
      invalidate = function() error("expected handle invalidate fault", 0) end,
      dispose = function()
        attempts = attemptCleanupReentry(dispatcher, "handle.invalidate")
      end,
    },
  }, {})
  check(handle, registerError or "handle invalidate fault extension registers")
  local invalidated, invalidateError = handle:invalidate({}, "test")
  equal(invalidated, nil, "handle invalidate failure is reported")
  contains(invalidateError, "expected handle invalidate fault",
    "handle invalidate returns the callback failure")
  check(handle:status().faulted, "handle invalidate failure faults only its extension")
  expectCleanupReentryBlocked(attempts)
  equal(dispatcher:status().state, "running",
    "handle invalidate fault cleanup leaves the dispatcher running")
  check(dispatcher:dispose({}, "test-end"),
    "handle invalidate fault-cleanup dispatcher disposes normally")
end

do
  local noDraw = function() return true end
  local services = {
    materials = {},
    draw = { mesh = noDraw, instances = noDraw, billboards = noDraw },
  }
  local validContext = {
    world = {}, camera = {}, frame = {},
    materials = services.materials, draw = services.draw,
  }
  local calls = 0
  local dispatcher = API.new({ capabilities = { API.CAPABILITIES.RENDER_PHASES } })
  local handle, registerError = dispatcher:register({
    api = 1,
    id = "test.dispatch-validation-recovery",
    render = { background = function() calls = calls + 1 end },
  })
  check(handle, registerError or "dispatch validation recovery registers")
  check(dispatcher:attach(services), "dispatch validation recovery attaches")
  check(dispatcher:start(validContext), "dispatch validation recovery starts")

  local report, dispatchError = dispatcher:dispatch("background", {})
  equal(report, nil, "missing render context is rejected")
  contains(dispatchError, "world", "missing render context identifies world")

  local hostileContext = setmetatable({}, {
    __index = function() error("validation proxy access failed", 0) end,
  })
  report, dispatchError = dispatcher:dispatch("background", hostileContext)
  equal(report, nil, "throwing render context is rejected")
  contains(dispatchError, "validation proxy access failed",
    "throwing render context reports its validation fault")

  report, dispatchError = dispatcher:dispatch("background", validContext)
  check(report, dispatchError or "dispatch recovers after validation faults")
  equal(report.succeeded, 1, "recovered dispatch succeeds")
  equal(calls, 1, "recovered dispatch invokes its handler once")
  check(dispatcher:dispose({}, "test"), "dispatch validation recovery disposes")
end

do
  local dispatcher = API.new({ capabilities = { API.CAPABILITIES.CAMERA_DELTA } })
  local first = dispatcher:register({
    api = 1,
    id = "test.camera-large-first",
    priority = 0,
    camera = function()
      return {
        positionDelta = { x = 1e308 },
        rotationDelta = { yaw = 1e308 },
        fovDelta = 1e308,
      }
    end,
  })
  check(first, "first large finite camera contribution registers")
  local overflow = dispatcher:register({
    api = 1,
    id = "test.camera-large-overflow",
    priority = 1,
    camera = function()
      return { positionDelta = { x = 1e308, y = 50 } }
    end,
  })
  check(overflow, "overflowing camera contribution registers")
  local recovery = dispatcher:register({
    api = 1,
    id = "test.camera-large-recovery",
    priority = 2,
    camera = function()
      return {
        positionDelta = { x = -1e308, y = 2 },
        rotationDelta = { yaw = -1e308 },
        fovDelta = -1e308,
      }
    end,
  })
  check(recovery, "camera recovery contribution registers")
  check(dispatcher:attach({}), "camera overflow dispatcher attaches")
  check(dispatcher:start({}), "camera overflow dispatcher starts")

  local result, report = dispatcher:dispatch_camera({})
  equal(result.positionDelta.x, 0, "finite camera position aggregate is preserved")
  equal(result.positionDelta.y, 2, "overflowing camera contribution is transactional")
  equal(result.rotationDelta.yaw, 0, "finite camera rotation aggregate is preserved")
  equal(result.fovDelta, 0, "finite camera FOV aggregate is preserved")
  equal(report.succeeded, 2, "two finite camera contributions succeed")
  equal(report.failed, 1, "only the overflowing camera contribution fails")
  equal(#report.contributors, 2, "camera report contains only finite contributors")
  equal(report.contributors[1], "test.camera-large-first",
    "first finite camera contributor remains")
  equal(report.contributors[2], "test.camera-large-recovery",
    "later finite camera contributor still runs")
  check(overflow:status().faulted, "overflowing camera extension is faulted")
  check(dispatcher:dispose({}, "test"), "camera overflow dispatcher disposes")
end

equal(provider.api, 1, "provider reports API v1")
equal(provider.host.id, "BATTLE_ART_VOXEL_FORK", "provider reports stable host id")
equal(provider.host.version, "1.9.7", "provider preserves upstream version")
for _, capability in ipairs({
  "world_snapshot", "camera_delta", "render_phases", "quality_tier",
  "integrity_status", "visual_object_overrides",
}) do
  equal(provider.capabilities[capability], 1, "provider advertises " .. capability)
end
for _, capability in ipairs({
  "terrain_patch", "shadow_pass", "battle_pass", "materials", "draw",
}) do
  equal(provider.capabilities[capability], nil,
    "provider does not over-advertise " .. capability)
end
equal(mod.writes, 0, "clean integrity scan is read-only")

local calls = {
  world = 0,
  update = 0,
  healthyRender = 0,
  faultyDispose = 0,
  invalidated = 0,
  disposed = 0,
}

local borrowedTexture = {
  releases = 0,
  release = function(self) self.releases = self.releases + 1 end,
}

local faulty, err = provider.register({
  api = 1,
  id = "test.draw-fault",
  priority = 0,
  requires = { "render_phases" },
  render = {
    background = function(context)
      love.graphics.setColor(0.1, 0.2, 0.3, 0.4)
      fakeVoxel3D.failNextDraw = true
      local accepted, drawError = context.draw.mesh(wireCommand("mesh", "background", 1, {
        geometry = { primitive = "box", width = 1, height = 1, depth = 1 },
        material = "test:fault",
      }), context)
      if not accepted then error(drawError, 0) end
    end,
  },
  dispose = function() calls.faultyDispose = calls.faultyDispose + 1 end,
})
check(faulty, err or "fault extension registers")

local healthy
healthy, err = provider.register({
  api = 1,
  id = "test.kfp-like",
  priority = 10,
  requires = {
    "world_snapshot", "camera_delta", "render_phases", "quality_tier",
  },
  optional = {
    "terrain_patch", "shadow_pass", "battle_pass", "integrity_status",
  },
  attach = function(services)
    equal(services.quality:getTier(), "BALANCED", "quality facade returns canonical tier")
    local status = services.integrity:status()
    check(status.clean and not status.legacyMarkers, "integrity facade reports a clean host")
  end,
  worldChanged = function(snapshot)
    calls.world = calls.world + 1
    calls.worldId = snapshot.id
    calls.worldRevision = snapshot.revision
    calls.cellCount = #snapshot.cells
  end,
  update = function(frame)
    calls.update = calls.update + 1
    calls.quality = frame.qualityTier
    calls.dt = frame.dt
  end,
  modifyCamera = function(camera)
    equal(camera.mode, "first_person", "camera callback gets the canonical camera")
    return {
      positionDelta = { x = 1, y = 2, z = 3 },
      rotationDelta = { yaw = 0.1, pitch = -0.02, roll = 0 },
      fovDelta = 0.04,
    }
  end,
  render = {
    background = function(context)
      calls.healthyRender = calls.healthyRender + 1
      local accepted, drawError = context.draw.mesh(wireCommand("mesh", "background", 2, {
        geometry = { primitive = "box", x = 8, y = 4, z = 8,
          width = 2, height = 3, depth = 2 },
        material = "test:healthy",
        texture = borrowedTexture,
      }), context)
      if not accepted then error(drawError, 0) end
      calls.borrowedMeshDraw = fakeVoxel3D.drawLog[#fakeVoxel3D.drawLog]
      calls.borrowedMeshCleared = calls.borrowedMeshDraw.mesh.texture == nil
      accepted, drawError = context.draw.mesh(wireCommand("mesh", "background", 3, {
        geometry = { primitive = "world_apron", width = 32, depth = 32,
          skirtDepth = 16 },
        material = "world:apron",
      }), context)
      if not accepted then error(drawError, 0) end
    end,
  },
  invalidate = function(reason)
    calls.invalidated = calls.invalidated + 1
    calls.invalidateReason = reason
  end,
  dispose = function() calls.disposed = calls.disposed + 1 end,
})
check(healthy, err or "KFP-like extension registers")

local collisionProbe
collisionProbe, err = provider.register({
  api = 1,
  id = "test.no-command-cache",
  priority = 20,
  requires = { "render_phases" },
  render = {
    background = function(context)
      local first = wireCommand("mesh", "background", 4, {
        cacheKey = "other.extension:shared",
        geometry = { primitive = "box", width = 1, height = 1, depth = 1 },
      })
      local second = wireCommand("mesh", "background", 5, {
        cacheKey = "other.extension:shared",
        geometry = { primitive = "box", width = 7, height = 1, depth = 1 },
      })
      local accepted, drawError = context.draw.mesh(first, context)
      calls.collisionFirst = accepted
      calls.collisionFirstModel = fakeVoxel3D.drawLog[#fakeVoxel3D.drawLog].model
      if not accepted then error(drawError, 0) end
      accepted, drawError = context.draw.mesh(first, context)
      calls.collisionRepeat = accepted
      calls.collisionRepeatModel = fakeVoxel3D.drawLog[#fakeVoxel3D.drawLog].model
      if not accepted then error(drawError, 0) end
      accepted, drawError = context.draw.mesh(second, context)
      calls.collisionSecond = accepted
      calls.collisionError = drawError
    end,
  },
})
check(collisionProbe, err or "no-cache probe extension registers")

local shadow
shadow, err = provider.register({
  api = 1,
  id = "test.flat-shadow",
  render = { shadow_casters = function() end },
})
equal(shadow, nil, "flat shadow callback is refused")
contains(err, "shadow_pass", "flat shadow refusal explains the missing capability")

local battle
battle, err = provider.register({
  api = 1,
  id = "test.flat-battle",
  render = { battle_opaque = function() end },
})
equal(battle, nil, "flat battle callback is refused")
contains(err, "battle_pass", "flat battle refusal explains the missing capability")

local nested
nested, err = provider.register({
  api = 1,
  id = "test.nested-shadow",
  phases = { shadow_casters = function() end },
})
equal(nested, nil, "legacy nested shadow callback is refused")
contains(err, "shadow_pass", "nested shadow refusal explains the missing capability")

check(companion:start(), "host dispatcher starts")
local state = worldState()

local rejectedDraws = fakeVoxel3D.draws
local rejected = wireCommand("mesh", "background", 20, {
  geometry = { primitive = "plane", width = 1, depth = 1 },
})
rejected.schemaVersion = 0
local accepted, rejection = companion.draw.mesh(rejected, companion:_context())
equal(accepted, false, "wrong draw schema returns exactly false")
contains(rejection, "schemaVersion", "wrong draw schema explains the rejection")

rejected = wireCommand("mesh", "background", 21, {
  cacheKey = "unsafe key",
  geometry = { primitive = "plane", width = 1, depth = 1 },
})
accepted, rejection = companion.draw.mesh(rejected, companion:_context())
equal(accepted, false, "unsafe cache key returns exactly false")
contains(rejection, "safe ASCII", "unsafe cache key explains the rejection")

rejected = wireCommand("mesh", "background", 22, {
  geometry = { primitive = "plane", width = 1, depth = 1 },
  texture = "assets/foreign/texture.png",
})
accepted, rejection = companion.draw.mesh(rejected, companion:_context())
equal(accepted, false, "texture path returns exactly false")
contains(rejection, "path string", "texture path explains the rejection")

rejected = wireCommand("mesh", "background", 23, {
  geometry = { primitive = "plane", width = 1, depth = 1 },
})
accepted, rejection = companion.draw.mesh(rejected, nil)
equal(accepted, false, "missing callback context returns exactly false")
contains(rejection, "borrowed render context", "missing context explains the rejection")
equal(fakeVoxel3D.draws, rejectedDraws, "rejected commands never reach Voxel3D.draw")

local invalidBaseline = {
  wireCommand("mesh", "background", 24, {
    cacheKey = "other.extension:panorama-no-texture",
    geometry = { primitive = "panorama", sourceWidth = 4096, targetWidth = 2048 },
  }),
  wireCommand("mesh", "background", 25, {
    cacheKey = "other.extension:cloud-bad-density",
    geometry = { primitive = "cloud_layer", layer = 1, parallax = 0.2,
      density = 2, seed = 1 },
  }),
  wireCommand("mesh", "background", 251, {
    cacheKey = "other.extension:cloud-no-texture",
    geometry = { primitive = "cloud_layer", layer = 1, parallax = 0.2,
      density = 0.5, seed = 1 },
  }),
  wireCommand("mesh", "background", 26, {
    cacheKey = "other.extension:rainbow-bad-seed",
    geometry = { primitive = "rainbow", seed = 0 / 0 },
  }),
  wireCommand("billboards", "background", 27, {
    cacheKey = "other.extension:stars-empty",
    material = "sky:stars",
    procedural = { kind = "stars", count = 0, seed = 1 },
  }),
}
for _, command in ipairs(invalidBaseline) do
  accepted, rejection = companion.draw[command.kind](command, companion:_context())
  equal(accepted, false, "invalid complete-baseline command returns exactly false")
  check(type(rejection) == "string" and rejection ~= "",
    "invalid complete-baseline command explains its rejection")
  if command.cacheKey == "other.extension:cloud-no-texture" then
    contains(rejection, "texture is required for cloud_layer",
      "untextured cloud fails closed at the shared validator")
  end
end
equal(fakeVoxel3D.draws, rejectedDraws,
  "invalid complete-baseline commands never reach Voxel3D.draw")

local starTexture = {
  releases = 0,
  release = function(self) self.releases = self.releases + 1 end,
}
local stars = wireCommand("billboards", "background", 28, {
  cacheKey = "other.extension:procedural-stars",
  material = "sky:stars",
  texture = starTexture,
  procedural = {
    kind = "stars", count = 24, seed = 1234.5,
    twinkle = true, nebula = true, shootingStars = true,
  },
})
local oldRandom, oldRandomSeed = math.random, math.randomseed
math.random = function() error("procedural stars touched global random", 0) end
math.randomseed = function() error("procedural stars reseeded global random", 0) end
local firstStarStart = #fakeVoxel3D.drawLog + 1
local callOk, firstAccepted, firstError = pcall(
  companion.draw.billboards, stars, companion:_context())
local firstStarEnd = #fakeVoxel3D.drawLog
local secondStarStart = firstStarEnd + 1
local secondCallOk, secondAccepted, secondError = pcall(
  companion.draw.billboards, stars, companion:_context())
local secondStarEnd = #fakeVoxel3D.drawLog
math.random, math.randomseed = oldRandom, oldRandomSeed
check(callOk, firstAccepted or "procedural stars avoid global random")
check(secondCallOk, secondAccepted or "repeat procedural stars avoid global random")
equal(firstAccepted, true, firstError or "procedural stars are accepted")
equal(secondAccepted, true, secondError or "repeat procedural stars are accepted")
equal(firstStarEnd - firstStarStart + 1, 24,
  "star procedure expands to the requested bounded item count")
equal(secondStarEnd - secondStarStart + 1, 24,
  "repeat star procedure keeps the requested item count")
for offset = 0, 23 do
  local firstDraw = fakeVoxel3D.drawLog[firstStarStart + offset]
  local secondDraw = fakeVoxel3D.drawLog[secondStarStart + offset]
  equal(treeSignature(firstDraw.model), treeSignature(secondDraw.model),
    "star expansion is repeatable for item " .. tostring(offset + 1))
  local translations = findTagged(firstDraw.model, "translate")
  local scales = findTagged(firstDraw.model, "scale")
  equal(#translations, 1, "star model has one bounded translation")
  equal(#scales, 1, "star model has one bounded scale")
  for coordinate = 2, 4 do
    check(translations[1][coordinate] >= -65536
      and translations[1][coordinate] <= 65536,
      "star coordinate stays inside the host world bound")
  end
  check(scales[1][2] >= 0.25 and scales[1][2] <= 8,
    "star width stays inside the host primitive bound")
  check(scales[1][3] >= 0.25 and scales[1][3] <= 8,
    "star height stays inside the host primitive bound")
  equal(firstDraw.texture, starTexture,
    "procedural star draw uses the callback-borrowed texture")
  equal(firstDraw.mesh.texture, nil,
    "procedural star texture is unbound before callback return")
end
equal(starTexture.releases, 0,
  "procedural star texture is neither retained nor released")
graphicsState = { color = "host", depth = "host", blend = "host" }

local updateReport = companion:update(0.016, state)
check(updateReport and updateReport.succeeded >= 1, "canonical update dispatch succeeds")
equal(calls.world, 1, "initial world identity dispatches one snapshot")
equal(calls.worldId, "PALLET_TOWN", "worldChanged receives the direct snapshot")
equal(calls.cellCount, 4, "world snapshot contains the real map cells")
equal(calls.quality, "BALANCED", "update receives the direct canonical frame")
equal(calls.dt, 0.016, "update frame retains bounded delta time")

local firstSnapshot = assert(companion.world.snapshot())
equal(firstSnapshot.game, "red", "snapshot reports the real Gen 1 game")
check(firstSnapshot.tags.outdoor, "snapshot derives outdoor map tags")
check(firstSnapshot.cells[1].tags.grass, "snapshot derives grass cell tags")
check(firstSnapshot.cells[3].tags.door, "snapshot derives warp cell tags")
check(firstSnapshot.cells[4].tags.water, "snapshot derives water cell tags")
firstSnapshot.cells[1].kind = "corrupted-copy"
equal(companion.world.snapshot().cells[1].kind, "grass",
  "snapshot facade returns defensive copies")

do
  -- ROM-free semantic fixture. Tile ids match the public KFP 1.60 authored
  -- OVERWORLD policy; all map, collision, roof, door, and connection facts are
  -- synthetic host inputs.
  local previousShapes = fakeShapes
  fakeShapes = {
    [0] = { class = "ground", h = 0 },
    [2] = { class = "wall", h = 16 },
    [9] = { class = "cliff", h = 32 },
    [10] = { class = "wall", h = 16 },
    [36] = { class = "wall", h = 16 },
    [42] = { class = "cylinder", h = 16 },
    [64] = { class = "cylinder", h = 16 },
    [90] = { class = "cylinder", h = 16 },
    [100] = { class = "roof", h = 28 },
  }

  local width, height = 12, 7
  local tiles = {}
  local function key(x, z) return x .. ":" .. z end
  local function put(x, z, tile) tiles[key(x, z)] = tile end
  put(0, 0, 64)   -- verified tree cylinder
  put(1, 0, 42)   -- verified boulder cylinder
  put(2, 0, 64)   -- walkable seam ghost
  put(3, 0, 90)   -- unknown cylinder
  put(4, 0, 42)   -- water-shaped boulder id
  put(11, 0, 2)   -- rock seed inside an active north connection band
  put(9, 3, 100)  -- roof that vetoes the nearby seed below
  put(9, 4, 36)   -- authored rock id, but part of a building context
  put(0, 4, 2)    -- valid mountain seed
  put(1, 4, 9)    -- first support cell
  put(2, 4, 10)   -- second support cell, at the exact reach limit
  put(3, 4, 10)   -- third cell, beyond the bounded seed reach
  put(5, 5, 36)   -- valid seed beside a cave-style doorway
  put(6, 5, 10)   -- non-seed support vetoed by that doorway
  put(11, 6, 9)   -- isolated generic cliff

  local semanticMap = {
    id = "SYNTHETIC_SEMANTICS",
    widthCells = width,
    heightCells = height,
    def = {
      width = 6,
      height = 4,
      tileset = "OVERWORLD",
      connections = { north = {} },
    },
    tileset = { id = "OVERWORLD", image = "synthetic-overworld-atlas" },
  }
  function semanticMap:cellTile(x, z) return tiles[key(x, z)] or 0 end
  function semanticMap:isWalkableCell(x, z)
    return self:cellTile(x, z) == 0 or (x == 2 and z == 0)
      or (x == 7 and z == 5)
  end
  function semanticMap:isWaterCell(x, z) return x == 4 and z == 0 end
  function semanticMap:isGrassCell() return false end
  function semanticMap:warpAtCell(x, z)
    return x == 7 and z == 5 and { target = "SYNTHETIC_CAVE" } or nil
  end
  function semanticMap:isWarpTileCell() return false end

  local semanticPlayer = { id = "player", px = 0, py = 0,
    cellX = 0, cellY = 0, facing = "down", gh = 0 }
  local semanticState = {
    map = semanticMap,
    player = semanticPlayer,
    entities = { semanticPlayer },
    neighbors = {},
  }
  local semanticCompanion = VoxelCompanion.new({ mod = cleanMod() })
  local callbackWorldId, callbackTreeSupport
  local semanticHandle, semanticError = semanticCompanion.provider.register({
    api = 1,
    id = "test.semantic-world-output",
    requires = { "world_snapshot" },
    worldChanged = function(snapshot)
      callbackWorldId = snapshot.id
      callbackTreeSupport = snapshot.cells[1].tags.tree_support
    end,
  })
  check(semanticHandle,
    semanticError or "semantic world-output extension registers")
  check(semanticCompanion:start(), "semantic world-output host starts")
  check(semanticCompanion:update(0.016, semanticState),
    "semantic fixture dispatches through the normal world lifecycle")
  equal(callbackWorldId, "SYNTHETIC_SEMANTICS",
    "worldChanged receives the semantic fixture")

  local semanticSnapshot = assert(semanticCompanion.world.snapshot())
  local function cell(x, z)
    return semanticSnapshot.cells[z * width + x + 1]
  end
  check(cell(0, 0).tags.tree_support,
    "known OVERWORLD tree cylinder receives tree_support")
  check(cell(0, 0).tags.tree and cell(0, 0).tags.object,
    "verified tree support retains truthful broad tags")
  check(not cell(0, 0).tags.boulder_tree,
    "tree cylinder is not mislabeled as a boulder")
  check(cell(1, 0).tags.boulder_tree and cell(1, 0).tags.boulder,
    "known OVERWORLD boulder cylinder receives boulder_tree")
  check(not cell(1, 0).tags.tree,
    "boulder cylinder does not retain the old generic tree guess")
  check(not cell(2, 0).tags.tree_support
      and not cell(2, 0).tags.boulder_tree
      and not cell(2, 0).tags.tree,
    "walkable cylinder ghost fails closed")
  check(cell(2, 0).walkable and cell(2, 0).tags.cylinder,
    "walkable ghost keeps only its truthful raw shape facts")
  check(not cell(3, 0).tags.tree_support
      and not cell(3, 0).tags.boulder_tree
      and not cell(3, 0).tags.tree,
    "unknown cylinder fails closed")
  check(not cell(4, 0).tags.boulder_tree,
    "water suppresses an otherwise known boulder id")

  check(cell(0, 4).tags.mountain_seed
      and cell(0, 4).tags.mountain_support,
    "authored rock seed is also a mountain support cell")
  check(cell(0, 4).tags.mountain and cell(0, 4).tags.object,
    "verified mountain seed retains truthful broad tags")
  check(cell(1, 4).tags.mountain_support
      and not cell(1, 4).tags.mountain_seed,
    "adjacent upright rock receives support but not seed")
  check(cell(2, 4).tags.mountain_support,
    "upright rock at the exact two-cell reach limit receives support")
  check(not cell(3, 4).tags.mountain_support
      and not cell(3, 4).tags.mountain,
    "upright rock beyond the seed reach fails closed")
  check(cell(5, 5).tags.mountain_seed,
    "authored rock seed survives a nearby cave doorway")
  check(not cell(6, 5).tags.mountain_support,
    "door proximity vetoes non-seed mountain support")
  check(not cell(9, 4).tags.mountain_seed
      and not cell(9, 4).tags.mountain_support,
    "roof proximity vetoes an authored rock id")
  check(not cell(11, 0).tags.mountain_seed,
    "active connection band suppresses a mountain seed")
  check(not cell(11, 6).tags.mountain_support
      and not cell(11, 6).tags.mountain,
    "isolated generic cliff is not guessed to be a mountain")

  check(callbackTreeSupport,
    "worldChanged output contains the normalized tree_support tag")
  semanticSnapshot.cells[1].tags.tree_support = false
  check(semanticCompanion.world.snapshot().cells[1].tags.tree_support,
    "semantic tags survive defensive snapshot copying")
  check(semanticCompanion:dispose("semantic-fixture"),
    "semantic fixture disposes cleanly")
  fakeShapes = previousShapes
end

state.player.px, state.player.py = 16, 16
state.player.cellX, state.player.cellY = 1, 1
companion:update(0.016, state)
equal(calls.world, 1, "player movement does not rebuild the whole world snapshot")

local beforeRevision = companion.revision
companion:worldChanged("first-edit")
companion:worldChanged("second-edit")
equal(companion.revision, beforeRevision + 1,
  "multiple block edits coalesce into one world revision")
companion:update(0.016, state)
equal(calls.world, 2, "coalesced edits dispatch one replacement snapshot")

local delta = companion:cameraDelta(state)
equal(delta.positionDelta.y, 2, "canonical camera delta is returned")
equal(delta.rotationDelta.yaw, 0.1, "camera rotation remains in radians")
equal(delta.fovDelta, 0.04, "camera FOV delta remains in radians")

local renderLogStart = #fakeVoxel3D.drawLog
local renderReport = companion:render("background", state)
check(renderReport, "background render dispatch returns a report")
equal(renderReport.called, 3, "all active render extensions are called")
equal(renderReport.failed, 1, "one extension draw fault is contained")
equal(renderReport.succeeded, 2, "later extensions render after an earlier fault")
equal(calls.faultyDispose, 1, "faulted extension is disposed exactly once")
equal(calls.healthyRender, 1, "healthy extension rendered")
equal(calls.borrowedMeshDraw.texture, borrowedTexture,
  "extension texture is passed directly to Voxel3D.draw")
equal(calls.borrowedMeshCleared, true,
  "borrowed texture is unbound before draw.mesh returns")
check(companion.texture ~= borrowedTexture,
  "extension texture is not retained as the adapter fallback")
equal(borrowedTexture.releases, 0, "adapter does not release the borrowed texture")
equal(calls.collisionFirstModel[2][2], 1,
  "first same-key command uses its own declarative width")
equal(calls.collisionRepeatModel[2][2], 1,
  "an identical same-key command remains valid")
equal(calls.collisionFirst, true, "first key and content pair is accepted")
equal(calls.collisionRepeat, true, "same key and content pair is accepted again")
equal(calls.collisionSecond, false, "same key with different content fails closed")
contains(calls.collisionError, "content collision",
  "same-key content mismatch reports a collision")
equal(#fakeVoxel3D.drawLog - renderLogStart, 5,
  "colliding declarative content is not drawn")
equal(fakeVoxel3D.glassState, true, "host shader selector is restored after draw fault")
equal(pushCount, 1, "graphics state is pushed once for the phase")
equal(popCount, 1, "graphics state is popped once for the phase")
equal(graphicsState.color, "host", "graphics color state is restored")
equal(graphicsState.depth, "host", "graphics depth state is restored")
equal(graphicsState.blend, "host", "graphics blend state is restored")

local fixturePhaseIds = {
  background = "1",
  opaque_after_terrain = "2",
  translucent_after_actors = "3",
}
local fixtureTexture
local fixtureValidated = 0
local fixtureMeshPrimitives = {}
for _, phase in ipairs({
  "background", "opaque_after_terrain", "translucent_after_actors",
}) do
  for _, command in ipairs(DrawFixture.phases[phase]) do
    local valid, validationError = API.validate_draw_command(command, command.kind)
    check(valid, validationError or "shared baseline command validates")
    local scene, generation, phaseId, wireSequence, content = command.cacheKey:match(
      "^kfp1:([0-9a-f]+):([0-9]+):([1-5]):([0-9]+):([0-9a-f]+)$")
    check(scene ~= nil, "KFP fixture key uses the exact producer profile")
    equal(#scene, 8, "KFP fixture scene digest has eight lowercase hex digits")
    check(generation == "0" or not generation:match("^0"),
      "KFP fixture generation is canonical unsigned decimal")
    equal(phaseId, fixturePhaseIds[phase], "KFP fixture key phase matches command phase")
    equal(wireSequence, tostring(command.sequence),
      "KFP fixture key sequence matches command sequence")
    equal(#content, 16, "KFP fixture content digest has sixteen lowercase hex digits")
    check(#command.cacheKey <= 64, "KFP fixture key stays within the host limit")
    if command.texture then fixtureTexture = command.texture end
    if command.kind == "mesh" then
      fixtureMeshPrimitives[command.geometry.primitive] = true
    end
    fixtureValidated = fixtureValidated + 1
  end
end
equal(fixtureValidated, DrawFixture.commandCount,
  "shared fixture covers every declared baseline command")
equal(DrawFixture.commandCount, 23,
  "shared fixture locks the complete 23-command API baseline")
equal(#DrawFixture.instancePrimitives, 15,
  "shared fixture covers every common instance primitive")
for _, primitive in ipairs({
  "box", "plane", "panorama", "cloud_layer", "rainbow", "world_apron",
}) do
  check(fixtureMeshPrimitives[primitive],
    "shared fixture covers mesh primitive " .. primitive)
end
check(fixtureTexture, "shared fixture includes an opaque poster texture")
fixtureTexture.releases = 0
fixtureTexture.release = function(self) self.releases = self.releases + 1 end

local fixtureRender = {}
calls.fixturePrimitiveAccepted = {}
calls.fixtureTextureCleared = true
calls.fixtureModels = {}
calls.fixtureDraws = {}
for _, phase in ipairs({
  "background", "opaque_after_terrain", "translucent_after_actors",
}) do
  local phaseName = phase
  fixtureRender[phaseName] = function(context)
    for _, command in ipairs(DrawFixture.phases[phaseName]) do
      local beforeDraws = #fakeVoxel3D.drawLog
      local accepted, drawError = context.draw[command.kind](command, context)
      if accepted ~= true then error(drawError or "fixture draw rejected", 0) end
      calls.fixtureAccepted = (calls.fixtureAccepted or 0) + 1
      local primitive = command.geometry and command.geometry.primitive
        or command.procedural and command.procedural.kind
        or command.prototype and command.prototype.primitive
        or "explicit_billboards"
      calls.fixturePrimitiveAccepted[primitive] =
        (calls.fixturePrimitiveAccepted[primitive] or 0) + 1
      if command.kind == "mesh" then
        calls.fixtureModels[primitive] = fakeVoxel3D.drawLog[#fakeVoxel3D.drawLog].model
        calls.fixtureDraws[primitive] = fakeVoxel3D.drawLog[#fakeVoxel3D.drawLog]
      end
      if command.procedural then
        calls.fixtureStarsExpanded = (calls.fixtureStarsExpanded or 0)
          + (#fakeVoxel3D.drawLog - beforeDraws)
      end
      if command.texture then
        calls.fixtureTextureCleared = calls.fixtureTextureCleared
          and fakeVoxel3D.drawLog[#fakeVoxel3D.drawLog].mesh.texture == nil
        if primitive == "panorama" then
          calls.panoramaTextureUsed = fakeVoxel3D.drawLog[#fakeVoxel3D.drawLog]
            .texture == command.texture
        elseif primitive == "cloud_layer" then
          calls.cloudTextureUsed = fakeVoxel3D.drawLog[#fakeVoxel3D.drawLog]
            .texture == command.texture
        end
      end
    end
  end
end

local fixtureHandle
fixtureHandle, err = provider.register({
  api = 1,
  id = "test.shared-draw-fixture",
  priority = 30,
  requires = { "render_phases" },
  render = fixtureRender,
})
check(fixtureHandle, err or "shared fixture extension registers")
for pass = 1, 2 do
  local fixtureBackground = companion:render("background", state)
  local fixtureOpaque = companion:render("opaque_after_terrain", state)
  local fixtureTranslucent = companion:render("translucent_after_actors", state)
  check(fixtureBackground and fixtureBackground.failed == 0,
    "shared background commands render on pass " .. pass)
  check(fixtureOpaque and fixtureOpaque.failed == 0,
    "shared world apron and instance commands render on pass " .. pass)
  check(fixtureTranslucent and fixtureTranslucent.failed == 0,
    "shared explicit billboard command renders on pass " .. pass)
end
equal(calls.fixtureAccepted, DrawFixture.commandCount * 2,
  "host accepts and cache-validates every baseline command twice")
for _, primitive in ipairs({ "panorama", "cloud_layer", "rainbow" }) do
  equal(calls.fixturePrimitiveAccepted[primitive], 2,
    primitive .. " is accepted with identical cached content twice")
end
equal(calls.fixturePrimitiveAccepted.stars, 2,
  "procedural stars are accepted with identical cached content twice")
equal(calls.fixtureStarsExpanded, 48,
  "the fixture expands 24 deterministic stars on each pass")
equal(calls.panoramaTextureUsed, true,
  "panorama uses its callback-borrowed texture")
equal(calls.cloudTextureUsed, true,
  "cloud layer uses its callback-borrowed texture")
equal(calls.fixtureTextureCleared, true,
  "shared panorama, cloud, and poster textures are unbound before return")
check(companion.texture ~= fixtureTexture,
  "shared fixture texture is not retained as a host fallback")
equal(fixtureTexture.releases, 0,
  "shared panorama, cloud, and poster texture is not released")
check(#companion.meshes.panorama_deep.vertices <= 256,
  "deep panorama uses bounded host-owned band and skirt geometry")
local cloudMesh = companion.meshes.cloud_layer
equal(#cloudMesh.vertices, 2 + 15 * 32,
  "cloud layer uses one bounded closed-shell vertex set")
equal(#cloudMesh.indices, 960 * 3,
  "cloud layer uses a finite closed-shell triangle set")
local cloudEdges, cloudVertexUses = {}, {}
local function useCloudEdge(a, b)
  local low, high = math.min(a, b), math.max(a, b)
  local key = tostring(low) .. ":" .. tostring(high)
  local edge = cloudEdges[key] or { count = 0, orientation = 0 }
  edge.count = edge.count + 1
  edge.orientation = edge.orientation + (a < b and 1 or -1)
  cloudEdges[key] = edge
end
for index = 1, #cloudMesh.indices, 3 do
  local a, b, c = cloudMesh.indices[index], cloudMesh.indices[index + 1],
    cloudMesh.indices[index + 2]
  cloudVertexUses[a], cloudVertexUses[b], cloudVertexUses[c] = true, true, true
  useCloudEdge(a, b)
  useCloudEdge(b, c)
  useCloudEdge(c, a)
end
local cloudEdgeCount, badCloudEdge = 0, nil
for key, edge in pairs(cloudEdges) do
  cloudEdgeCount = cloudEdgeCount + 1
  if edge.count ~= 2 or edge.orientation ~= 0 then badCloudEdge = key end
end
equal(badCloudEdge, nil,
  "every cloud-shell edge has two oppositely wound faces and no boundary")
equal(cloudEdgeCount, #cloudMesh.indices / 2,
  "closed cloud-shell edges have exactly two triangle uses")
equal(#cloudMesh.vertices - cloudEdgeCount + #cloudMesh.indices / 3, 2,
  "cloud shell has the Euler characteristic of one closed sphere")
for index, vertex in ipairs(cloudMesh.vertices) do
  check(cloudVertexUses[index], "every cloud-shell vertex belongs to a face")
  check(math.abs(vertex[1] * vertex[1] + vertex[2] * vertex[2]
      + vertex[3] * vertex[3] - 0.25) <= 1e-12,
    "cloud-shell vertices stay on the fixed half-unit sphere")
  check(math.abs(vertex[4] - (vertex[1] + 0.5)) <= 1e-12
      and math.abs(vertex[5] - (vertex[3] + 0.5)) <= 1e-12,
    "cloud UVs are a continuous projection of shared shell coordinates")
end
check(#companion.meshes.rainbow.vertices <= 96,
  "rainbow uses bounded host-owned geometry")
equal(companion.meshes.panorama_deep.texture, nil,
  "deep panorama mesh does not retain its borrowed texture")
local panoramaTranslation = findTagged(calls.fixtureModels.panorama, "translate")[1]
local panoramaScale = findTagged(calls.fixtureModels.panorama, "scale")[1]
equal(panoramaTranslation[3], 0,
  "deep panorama keeps authored vertical positions in its mesh")
equal(panoramaScale[2], 1800,
  "panorama diameter is fixed physical geometry, not texture resolution")
equal(panoramaScale[3], 1,
  "panorama model does not stretch the authored vertical band")
equal(panoramaScale[4], 1800,
  "panorama depth uses the fixed physical diameter")
local deepVertices = companion.meshes.panorama_deep.vertices
equal(#deepVertices, 32 * 8,
  "deep panorama has one band quad and one skirt quad per segment")
for index, vertex in ipairs(deepVertices) do
  local y, v = vertex[2], vertex[5]
  if index <= 32 * 4 then
    check((y == -120 and v == 1) or (y == 300 and v == 0),
      "authored panorama band retains its full vertical UV range")
  else
    check(y == -1400 or y == -120,
      "deep panorama skirt retains the released vertical bounds")
    equal(v, 1,
      "deep panorama skirt samples only the texture bottom row")
  end
end
local function assertCloudEnclosure(model, eye, label)
  local translation = findTagged(model, "translate")[1]
  local scale = findTagged(model, "scale")[1]
  local rotation = findTagged(model, "rotateY")[1]
  check(scale[2] >= 120 and scale[2] <= 192
      and scale[4] >= 120 and scale[4] <= 192,
    label .. " stays inside the bounded horizontal diameter")
  check(scale[3] >= 544 and scale[3] <= 736,
    label .. " stays inside the bounded vertical diameter")
  equal(translation[2], eye[1],
    label .. " remains centered on the public eye X position")
  equal(translation[4], eye[3],
    label .. " remains centered on the public eye Z position")
  local top = translation[3] + scale[3] * 0.5
  check(top >= eye[2] + 200,
    label .. " retains a high overhead deck")
  local localX = (eye[1] - translation[2]) / scale[2]
  local localY = (eye[2] - translation[3]) / scale[3]
  local localZ = (eye[3] - translation[4]) / scale[4]
  check(localX * localX + localY * localY + localZ * localZ < 0.25,
    label .. " strictly encloses the public eye")

  local minX, maxX, minZ, maxZ = math.huge, -math.huge,
    math.huge, -math.huge
  local cosine, sine = math.cos(rotation[2]), math.sin(rotation[2])
  for _, vertex in ipairs(cloudMesh.vertices) do
    local x, z = vertex[1] * scale[2], vertex[3] * scale[4]
    local transformedX = x * cosine - z * sine + translation[2]
    local transformedZ = x * sine + z * cosine + translation[4]
    minX, maxX = math.min(minX, transformedX), math.max(maxX, transformedX)
    minZ, maxZ = math.min(minZ, transformedZ), math.max(maxZ, transformedZ)
  end
  check(maxX - minX <= 192 + 1e-9,
    label .. " cannot exceed its claimed transformed X span")
  check(maxZ - minZ <= 192 + 1e-9,
    label .. " cannot exceed its claimed transformed Z span")
end

assertCloudEnclosure(calls.fixtureModels.cloud_layer, fakeVoxel3D.eye,
  "fixture cloud shell")
for index, geometry in ipairs({
  { primitive = "cloud_layer", layer = 1, parallax = -2,
    density = 0, seed = 1 },
  { primitive = "cloud_layer", layer = 16, parallax = 2,
    density = 1, seed = 1 },
}) do
  local command = wireCommand("mesh", "background", 216 + index, {
    cacheKey = "test.cloud.enclosure:" .. tostring(index),
    material = "sky:clouds:enclosure-probe",
    texture = fixtureTexture,
    geometry = geometry,
  })
  local accepted, enclosureError = companion.draw.mesh(
    command, companion:_context())
  check(accepted, enclosureError or "cloud enclosure extreme is accepted")
  assertCloudEnclosure(fakeVoxel3D.drawLog[#fakeVoxel3D.drawLog].model,
    fakeVoxel3D.eye, "cloud enclosure extreme " .. tostring(index))
end
equal(calls.fixtureDraws.cloud_layer.depth, "lequal:false",
  "cloud decks never occlude later world geometry through depth writes")
check(calls.fixtureDraws.panorama.color:match(":1$") ~= nil,
  "distance haze does not turn panorama alpha into checker coverage")
equal(calls.fixtureDraws.panorama.depth, "lequal:false",
  "panorama retains depth testing without occluding later world geometry")
check(calls.fixtureDraws.cloud_layer.color:match(":1$") ~= nil,
  "cloud material uses binary texture coverage without alpha dithering")
equal(calls.fixtureDraws.cloud_layer.mesh.texture, nil,
  "cloud layer unbinds its borrowed texture after each draw")

local detachTexture = {
  releases = 0,
  release = function(self) self.releases = self.releases + 1 end,
}
local failedDetachMesh = companion.meshes.cloud_layer
failedDetachMesh.failDetach = true
local detachCommand = wireCommand("mesh", "background", 219, {
  cacheKey = "test.cloud.detach-failure",
  material = "sky:clouds:detach-probe",
  texture = detachTexture,
  geometry = {
    primitive = "cloud_layer", layer = 1, parallax = 0.14,
    density = 0.5, seed = 99,
  },
})
local detachAccepted, detachError = companion.draw.mesh(
  detachCommand, companion:_context())
equal(detachAccepted, false,
  "a borrowed cloud texture detach failure fails the draw closed")
contains(detachError, "could not unbind borrowed extension texture",
  "detach failure reports the borrowed-texture ownership problem")
equal(companion.meshes.cloud_layer, nil,
  "detach failure evicts the mesh that still references borrowed texture")
equal(failedDetachMesh.releaseCount, 1,
  "detach failure releases the evicted host-owned mesh exactly once")
equal(detachTexture.releases, 0,
  "detach failure never releases the callback-borrowed cloud texture")

detachAccepted, detachError = companion.draw.mesh(
  detachCommand, companion:_context())
check(detachAccepted, detachError or "cloud draw retries after safe mesh eviction")
check(companion.meshes.cloud_layer ~= failedDetachMesh,
  "a later cloud draw creates a fresh host-owned mesh")
equal(companion.meshes.cloud_layer.texture, nil,
  "the replacement cloud mesh unbinds the borrowed texture")
equal(failedDetachMesh.releaseCount, 1,
  "the evicted host mesh is not released twice")
equal(detachTexture.releases, 0,
  "successful retry still does not release the borrowed cloud texture")

local panoramaModels = {}
for index, width in ipairs({ 4096, 1024 }) do
  local command = wireCommand("mesh", "background", 200 + index, {
    cacheKey = "test.panorama.physical:" .. tostring(width),
    material = "horizon:quality-probe",
    texture = fixtureTexture,
    geometry = {
      primitive = "panorama", sourceWidth = width, targetWidth = width,
      deepSkirt = index == 1, distanceHaze = true,
    },
  })
  local before = #fakeVoxel3D.drawLog
  local panoramaAccepted, panoramaError = companion.draw.mesh(
    command, companion:_context())
  check(panoramaAccepted, panoramaError or "panorama quality probe is accepted")
  equal(#fakeVoxel3D.drawLog, before + 1,
    "panorama quality probe emits one bounded draw")
  panoramaModels[index] = fakeVoxel3D.drawLog[#fakeVoxel3D.drawLog].model
end
equal(treeSignature(panoramaModels[1]), treeSignature(panoramaModels[2]),
  "panorama world geometry is independent of texture quality width")
check(#companion.meshes.panorama.vertices <= 128,
  "normal panorama uses one bounded authored-band cylinder")
equal(companion.meshes.panorama.texture, nil,
  "normal panorama mesh does not retain its borrowed texture")

-- KFP emits explicit ceiling and wall cutaway intent for every camera mode.
-- Ceiling intent opens a bounded player area. Wall intent opens only the
-- camera-near shell, so a small room keeps a useful far cross-section.
-- Canopy cutaway remains first-person-only.
local cutawayResults = {}
local cutawayHandle
cutawayHandle, err = provider.register({
  api = 1,
  id = "test.kfp-cutaway",
  priority = 40,
  requires = { "render_phases" },
  render = {
    opaque_after_terrain = function(context)
      local mode = context.camera.mode
      local result = {
        contextMode = mode,
        contextEyeX = context.camera.eye and context.camera.eye[1] or nil,
      }
      cutawayResults[mode] = result

      local function draw(label, sequence, prototype, items)
        local before = #fakeVoxel3D.drawLog
        local accepted, drawError = context.draw.instances(wireCommand(
          "instances", "opaque_after_terrain", sequence, {
            cacheKey = "test.kfp-cutaway:" .. label,
            prototype = prototype,
            items = items,
          }), context)
        if not accepted then error(drawError, 0) end
        result[label] = #fakeVoxel3D.drawLog - before
      end

      local cells = {
        { x = 16, y = 24, z = 16, cellX = 1, cellZ = 1 },
        { x = 80, y = 24, z = 80, cellX = 5, cellZ = 5 },
        { x = 96, y = 24, z = 16, cellX = 6, cellZ = 1 },
      }
      draw("ceiling", 101, {
        primitive = "box", width = 16, height = 1, depth = 16,
        cutaway = true, role = "ceiling",
      }, cells)
      draw("wall", 102, {
        primitive = "box", width = 1, height = 24, depth = 16,
        cutaway = true, role = "wall",
      }, cells)
      draw("ceiling-disabled", 103, {
        primitive = "box", width = 16, height = 1, depth = 16,
        cutaway = false, role = "ceiling",
      }, { cells[1] })
      draw("wall-disabled", 104, {
        primitive = "box", width = 1, height = 24, depth = 16,
        cutaway = false, role = "wall",
      }, { cells[1] })
      draw("other-role", 105, {
        primitive = "box", width = 1, height = 24, depth = 16,
        cutaway = true, role = "door",
      }, { cells[1] })
      draw("missing-cell", 106, {
        primitive = "box", width = 1, height = 24, depth = 16,
        cutaway = true, role = "wall",
      }, { { x = 16, y = 24, z = 16 } })
      draw("canopy-derived-cell", 107, {
        primitive = "canopy", width = 16, cutaway = true,
      }, {
        { x = 16, y = 24, z = 16 },
        { x = 80, y = 24, z = 80 },
        { x = 96, y = 24, z = 16 },
      })
      draw("wall-cross-section", 108, {
        primitive = "box", width = 1, height = 24, depth = 16,
        cutaway = true, role = "wall",
      }, {
        { x = 16, y = 24, z = 24, cellX = 1, cellZ = 1 },
        { x = 32, y = 24, z = 24, cellX = 1, cellZ = 1 },
        { x = 24, y = 24, z = 16, cellX = 1, cellZ = 1 },
        { x = 24, y = 24, z = 32, cellX = 1, cellZ = 1 },
      })
    end,
  },
})
check(cutawayHandle, err or "KFP cutaway probe registers")

local savedCamera, savedEye = fakeVoxel3D.camera, fakeVoxel3D.eye
for _, mode in ipairs({ "first_person", "third_person", "diorama" }) do
  fakeCameraMode = mode
  if mode == "diorama" then
    fakeVoxel3D.camera = nil
    fakeVoxel3D.eye = { 8, 16, 24 }
  else
    fakeVoxel3D.camera = savedCamera
    fakeVoxel3D.eye = savedEye
  end
  local report = companion:render("opaque_after_terrain", state)
  local cutawayStatus = cutawayHandle:status()
  check(report and report.failed == 0,
    "KFP cutaway probe renders in " .. mode .. ": "
      .. tostring(cutawayStatus.fault and cutawayStatus.fault.message))
  equal(cutawayResults[mode].contextMode, mode,
    "cutaway reads the public callback camera mode in " .. mode)
  equal(cutawayResults[mode].contextEyeX, 8,
    "cutaway reads a public host eye in " .. mode)
end
fakeVoxel3D.camera, fakeVoxel3D.eye = savedCamera, savedEye

for _, mode in ipairs({ "first_person", "third_person", "diorama" }) do
  equal(cutawayResults[mode].ceiling, 1,
    mode .. " applies emitted ceiling intent at the inclusive radius")
  equal(cutawayResults[mode].wall, 2,
    mode .. " removes only the camera-near wall and keeps the far shell")
  equal(cutawayResults[mode]["wall-cross-section"], 3,
    mode .. " keeps far and side walls in a one-cell room")
  equal(cutawayResults[mode]["ceiling-disabled"], 1,
    mode .. " preserves cutaway=false ceilings")
  equal(cutawayResults[mode]["wall-disabled"], 1,
    mode .. " preserves cutaway=false walls")
  equal(cutawayResults[mode]["other-role"], 1,
    mode .. " does not suppress a different semantic role")
  equal(cutawayResults[mode]["missing-cell"], 1,
    mode .. " fails open when an item has no cell position")
end
equal(cutawayResults.first_person["canopy-derived-cell"], 1,
  "first-person cutaway derives released canopy cell positions")
for _, mode in ipairs({ "third_person", "diorama" }) do
  equal(cutawayResults[mode]["canopy-derived-cell"], 3,
    mode .. " preserves all canopy cells")
end
fakeCameraMode = "first_person"

local lateUpdates = 0
local late
late, err = provider.register({
  api = 1,
  id = "test.late-registration",
  update = function(frame)
    check(frame.dt >= 0, "late extension receives the canonical frame")
    lateUpdates = lateUpdates + 1
  end,
})
check(late, err or "late registration joins a running dispatcher")
check(late:is_active(), "late registration is active without a private context argument")
companion:update(0.02, state)
equal(lateUpdates, 1, "late extension runs on the next update")

companion:invalidate("test-invalidate")
equal(calls.invalidated, 1, "host invalidation reaches the healthy extension")
equal(calls.invalidateReason, "test-invalidate", "invalidation reason is canonical")
companion:dispose("test-dispose")
equal(calls.disposed, 1, "healthy extension is disposed exactly once")
equal(borrowedTexture.releases, 0,
  "adapter never releases a borrowed texture during invalidation or disposal")
equal(starTexture.releases, 0,
  "adapter never releases a procedural-star texture during disposal")
equal(fixtureTexture.releases, 0,
  "adapter never releases shared panorama/cloud/poster texture during disposal")
equal(companion.state, nil, "adapter drops retained world state on dispose")
equal(companion.startContext, nil, "adapter drops retained activation context on dispose")
equal(love.update, sentinelUpdate, "adapter does not replace global callbacks")

local legacyMod = cleanMod()
local contaminated = false
function legacyMod:read(path)
  if contaminated and path == "lib/VoxelScene.lua" then
    return "local function __dsMod(name, statusKey) end\n"
  end
  return "-- clean\n"
end
local LegacyCompanion = assert(loadfile("lib/VoxelCompanion.lua"))(namespace(legacyMod))
local legacy = LegacyCompanion.new({ mod = legacyMod })
contaminated = true
local refused
refused, err = legacy.provider.register({
  api = 1,
  id = "test.must-refuse",
  update = function() end,
})
equal(refused, nil, "legacy-spliced host refuses companion registration")
contains(err, "legacy KFP splice markers detected in lib/VoxelScene.lua",
  "legacy refusal names the exact contaminated target")
contains(err, "reinstall a clean voxel host", "legacy refusal gives the recovery action")
equal(legacyMod.writes, 0, "legacy refusal scan never edits host files")

local cameraMat4 = { captured = {} }
function cameraMat4.identity() return { "identity" } end
function cameraMat4.perspective(fov, aspect, nearPlane, farPlane)
  cameraMat4.captured.fov = fov
  cameraMat4.captured.aspect = aspect
  return { "projection", nearPlane, farPlane }
end
function cameraMat4.lookAt(eye, focus, up)
  cameraMat4.captured.eye = eye
  cameraMat4.captured.focus = focus
  cameraMat4.captured.up = up
  return { "view" }
end
function cameraMat4.scale(x, y, z) return { "scale", x, y, z } end
function cameraMat4.mul(a, b) return { a, b } end

local cameraNamespace = {
  require = function(name)
    if name == "Mat4" then return cameraMat4 end
    if name == "VoxelState" then return { angle = 0, FOCAL = 1 } end
    return {}
  end,
}
local RealVoxel3D = assert(loadfile("lib/Voxel3D.lua"))(cameraNamespace)
RealVoxel3D.camera = {
  eye = { 0, 0, 0 },
  focus = { 0, 0, 10 },
  up = { 0, 1, 0 },
  fov = 1,
}
RealVoxel3D.setCompanionCameraDelta({
  positionDelta = { x = 100, y = 2, z = 0 },
  rotationDelta = { yaw = 0.1, pitch = 0, roll = 0 },
  fovDelta = 10,
})
RealVoxel3D.viewProjection(0, 0, 160, 144)
equal(cameraMat4.captured.eye[1], 32, "camera position delta is bounded")
equal(cameraMat4.captured.eye[2], 2, "camera position delta is additive")
check(cameraMat4.captured.focus[1] > cameraMat4.captured.eye[1],
  "radian yaw rotates the host focus direction")
local expectedFov = 1 + math.rad(30)
check(math.abs(cameraMat4.captured.fov - expectedFov) < 1e-9,
  "large FOV deltas are radian values bounded at the host boundary")

print(("%d checks passed (Voxel Companion API v1 BATTLE_ART host)"):format(checks))
