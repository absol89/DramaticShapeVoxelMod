-- ROM-free end-to-end regression for main.lua's native unload wiring.

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

local function readFile(path)
  local file = assert(io.open(path, "rb"))
  local source = assert(file:read("*a"))
  file:close()
  return source
end

local hooks, events = {}, {}
local updateRemovals = 0

local function removeEntry(list, entry)
  for index, candidate in ipairs(list) do
    if candidate == entry then
      table.remove(list, index)
      return true
    end
  end
  return false
end

local hookFacade = {}
function hookFacade:wrap(name, callback)
  local list = hooks[name] or {}
  hooks[name] = list
  local entry = { callback = callback }
  list[#list + 1] = entry
  return function()
    local removed = removeEntry(list, entry)
    if removed and name == "core.update" then
      updateRemovals = updateRemovals + 1
    end
    return true
  end
end

local function callHook(name, vanilla, ...)
  local list = hooks[name] or {}
  local function run(index, ...)
    local entry = list[index]
    if not entry then return vanilla(...) end
    return entry.callback(function(...) return run(index + 1, ...) end, ...)
  end
  return run(1, ...)
end

local eventFacade = {}
function eventFacade:on(name, callback)
  local list = events[name] or {}
  events[name] = list
  list[#list + 1] = callback
  return function() return removeEntry(list, callback) end
end

local function emit(name, payload)
  for _, callback in ipairs(events[name] or {}) do callback(payload) end
end

local settingSource = [=[
local setting = { key = "test-setting" }
function setting:schema(description)
  return { key = self.key, description = description, default = 1 }
end
function setting:get() return "static" end
function setting:setIndex() return true end
function setting:cycle() return true end
function setting:sync() return true end

local settings = {
  setting = true, trainerSetting = true, playerArtSetting = true,
  playerAnimationSetting = true, frontAnimationSetting = true,
  backAnimationSetting = true, duplicateSetting = true, viewSetting = true,
  frontFlipSetting = true, backPlacementSetting = true,
  hudScaleSetting = true, spriteLight = true, hudColor = true,
  arenaFill = true, stadiumCircle = true, backdropOffset = true,
  bossBg = true, textboxFill = true,
}

local module = {}
return setmetatable(module, { __index = function(_, key)
  if settings[key] then return setting end
  if key == "export" then return function() return {} end end
  if key == "installed" then return function() return false end end
  if key == "enabled" then return function() return true end end
  return function() return true end
end })
]=]

local mat4Source = [=[
return {
  identity = function() return { "identity" } end,
  mul = function(a, b) return { a, b } end,
  translate = function(x, y, z) return { "translate", x, y, z } end,
  scale = function(x, y, z) return { "scale", x, y, z } end,
  rotateX = function(value) return { "rotateX", value } end,
  rotateY = function(value) return { "rotateY", value } end,
  rotateZ = function(value) return { "rotateZ", value } end,
}
]=]

local voxelStateSource = [=[
local setting = { key = "voxel" }
function setting:schema(description) return { key = self.key, description = description } end
function setting:get() return 1 end
function setting:setIndex() return true end
function setting:cycle() return true end
function setting:sync() return true end
return {
  ANGLE_LABELS = { "OFF", "FULL" }, HOTKEY_ORDER = { 0, 1 }, setting = setting,
  isFirstPerson = function() return true end,
  isThirdPerson = function() return false end,
  isFull = function() return false end,
  active = function() return false end,
  nextHotkeyLevel = function() return 0 end,
  update = function() end,
  seedOptions = function() return false end,
}
]=]

local tileShapeSource = [=[
local shapes = {
  [0] = { class = "ground", h = 0 },
  [4] = { class = "signpost", h = 16 },
}
return {
  forMap = function() return shapes end,
  propBg = function() return nil end,
}
]=]

local chunkMesherSource = [=[
local V = ...
local SIGN_ID = "BATTLE_ART_VOXEL_FORK:signpost:PALLET_TOWN:1:0"
local original = { id = "original-sign-color" }
local shadow = { id = "original-sign-shadow" }
local terrain = { id = "terrain" }
local M = {}
function M.visualObjectAnnotated(_, id) return id == SIGN_ID end
function M.pair()
  local hidden = V.companion and V.companion:suppressesVisualObject(SIGN_ID)
  return terrain, nil, hidden and {} or { original }, { shadow }
end
return setmetatable(M, { __index = function() return function() return true end end })
]=]

local meshResources, textureResources = {}, {}
local voxel3D = {
  FACE_CORNERS = {}, FACE_SHADE = {}, eye = { 0, 16, 32 },
  camera = { eye = { 0, 16, 32 }, focus = { 0, 0, 0 },
    up = { 0, 1, 0 }, fov = math.rad(65) },
}
for direction = 1, 6 do
  voxel3D.FACE_CORNERS[direction] = {
    { 0, 0, 0 }, { 1, 0, 0 }, { 1, 1, 0 }, { 0, 1, 0 },
  }
  voxel3D.FACE_SHADE[direction] = 1
end
function voxel3D.pushQuad(indices, offset) indices[#indices + 1] = offset end
function voxel3D.newMesh()
  local mesh = { releases = 0 }
  function mesh:setTexture(texture) self.texture = texture end
  function mesh:release() self.releases = self.releases + 1 end
  meshResources[#meshResources + 1] = mesh
  return mesh
end
function voxel3D.draw() end
function voxel3D.glass() end

love = {
  system = { getOS = function() return "Windows" end },
  image = { newImageData = function()
    return { setPixel = function() end }
  end },
  graphics = {
    push = function() end, pop = function() end,
    setColor = function() end, setDepthMode = function() end,
    setBlendMode = function() end,
    newImage = function()
      local texture = { releases = 0, setFilter = function() end }
      function texture:release() self.releases = self.releases + 1 end
      textureResources[#textureResources + 1] = texture
      return texture
    end,
  },
}

local fakeMapModule = {
  isOutdoor = function() return true end,
  setBlock = function(self, bx, by, block)
    self.blocks = self.blocks or {}
    self.blocks[by * 100 + bx] = block
  end,
}
local fakeGame = {
  save = { version = "red", options = {} },
  keypressed = function() end,
  writeOptions = function() end,
}
local fakePipelines = {
  level = function() return 0 end, canToggle = function() return false end,
  hotkey = function() return false end, setLevel = function() end,
  syncOptions = function() end, maxLevel = function() return 0 end,
}
local fakeOptionsMenu = {
  update = function() end,
  new = function() return { rows = {} } end,
}
package.loaded["src.world.Map"] = fakeMapModule
package.loaded["src.core.Game"] = fakeGame
package.loaded["src.render.Pipelines"] = fakePipelines
package.loaded["src.ui.OptionsMenu"] = fakeOptionsMenu

local actualModules = {
  CompanionLifecycle = true,
  VoxelCompanion = true,
  VoxelCompanionAPI = true,
  VoxelVisualObjects = true,
}

local moduleSources = {
  Mat4 = mat4Source,
  VoxelState = voxelStateSource,
  TileShape = tileShapeSource,
  ChunkMesher = chunkMesherSource,
  Voxel3D = "return ... and _G.__COMPANION_TEST_VOXEL3D",
  DayNight = [=[
    local setting = { key = "daynight" }
    function setting:schema(description) return { key = self.key, description = description } end
    function setting:get() return "day" end
    function setting:setIndex() return true end
    function setting:cycle() return true end
    function setting:sync() return true end
    return { setting = setting, isCanopy = function() return false end,
      tod = function() return "DAY" end, time = function() return 12 end,
      update = function() end, forceSync = function() end,
      store = function() end, restore = function() end }
  ]=],
}
_G.__COMPANION_TEST_VOXEL3D = voxel3D

local registries = setmetatable({}, { __index = function(self, name)
  local registry = { records = {} }
  function registry:register(id, value)
    self.records[id] = value
    return value
  end
  rawset(self, name, registry)
  return registry
end })

local mod = {
  id = "BATTLE_ART_VOXEL_FORK",
  path = ".",
  hooks = hookFacade,
  events = eventFacade,
  content = registries,
  exports = {},
  options = { define = function() end },
  log = { error = function(_, format, value)
    error(tostring(format):format(value), 0)
  end },
}
function mod:read(relative)
  local name = relative:match("^lib/(.+)%.lua$")
  if actualModules[name] then return readFile(relative) end
  return moduleSources[name] or settingSource
end

assert(loadfile("main.lua"))(mod)
_G.__COMPANION_TEST_VOXEL3D = nil

equal(#(hooks["core.update"] or {}), 1,
  "main.lua installs one companion update hook")
equal(#(hooks["core.quit_to_launcher"] or {}), 1,
  "main.lua binds the returned disposer to the native unload hook")

local host = mod.exports.lib.companion
local ChunkMesher = mod.exports.lib.require("ChunkMesher")
local signId = "BATTLE_ART_VOXEL_FORK:signpost:PALLET_TOWN:1:0"
local extensionDisposals, claimed, claimError, replacement = 0
local handle
handle = assert(mod.exports.voxel_companion.register({
  api = 1,
  id = "test.main-uninstall-owner",
  requires = { "visual_object_overrides", "world_snapshot", "render_phases" },
  worldChanged = function(snapshot)
    replacement = assert(snapshot.visualObjects[1])
    claimed, claimError = handle:claim_visual_objects({ replacement.id })
  end,
  render = {
    opaque_after_terrain = function(context)
      local ok, err = context.draw.visual_object({
        schemaVersion = 1,
        kind = "visual_object_replacement",
        objectId = replacement.id,
        geometry = { {
          shape = "box",
          position = { x = 0, y = 0, z = 0 },
          rotation = { yaw = 0, pitch = 0, roll = 0 },
          scale = { x = 1, y = 1, z = 1 },
          pivot = "bottom_center",
          dimensions = { width = 16, height = 16, depth = 2 },
          material = { color = { 0.55, 0.32, 0.16, 1 } },
        } },
        text = {},
      }, context)
      if not ok then error(err, 0) end
    end,
  },
  dispose = function() extensionDisposals = extensionDisposals + 1 end,
}))

emit("mods.loaded", { data = {} })
local map = {
  id = "PALLET_TOWN", widthCells = 2, heightCells = 2,
  def = { width = 1, height = 1, tileset = "OVERWORLD" },
  tileset = { id = "OVERWORLD", image = "synthetic-atlas" },
}
function map:cellTile(x, z) return x == 1 and z == 0 and 4 or 0 end
function map:isWalkableCell(x, z) return not (x == 1 and z == 0) end
function map:isWaterCell() return false end
function map:isGrassCell() return false end
function map:warpAtCell() return nil end
function map:isWarpTileCell() return false end
local player = { id = "player", px = 0, py = 0, cellX = 0, cellY = 0,
  facing = "down", gh = 0 }
local state = { map = map, player = player, entities = { player }, neighbors = {} }
local game = { overworld = state }
callHook("core.update", function() return "updated" end, game, 0.016)
check(claimed, claimError or "the annotated sign claim succeeds")
equal(handle:status().visualClaims, 1, "the live extension owns one sign")
check(host:suppressesVisualObject(signId), "the claimed sign suppresses original color")
equal(#select(3, ChunkMesher.pair(map, false)), 0,
  "the claimed sign's original color sidecar is hidden")
check(host:render("opaque_after_terrain", state),
  "the claimed replacement renders through the real adapter")
equal(#meshResources, 1, "one host-owned GPU mesh is allocated")
equal(#textureResources, 1, "one host-owned adapter texture is allocated")

local firstQuit = callHook("core.quit_to_launcher",
  function() return "first-unload" end)
equal(firstQuit, "first-unload", "native unload preserves the host result")
equal(host:status().visualOverrides, 0, "actual unload clears all claims")
equal(handle:status().visualClaims, 0, "the extension claim count becomes zero")
check(not host:suppressesVisualObject(signId),
  "actual unload stops suppressing the original sign")
equal(#select(3, ChunkMesher.pair(map, false)), 1,
  "the original sign color is restored immediately")
equal(extensionDisposals, 1, "extension disposal runs exactly once")
equal(meshResources[1].releases, 1, "the host GPU mesh releases exactly once")
equal(textureResources[1].releases, 1,
  "the host adapter texture releases exactly once")
equal(updateRemovals, 1, "actual unload removes the companion update hook")
equal(#(hooks["core.update"] or {}), 0,
  "the companion update hook is absent after unload")

local secondQuit = callHook("core.quit_to_launcher",
  function() return "second-unload" end)
equal(secondQuit, "second-unload", "a second native unload is safe")
equal(extensionDisposals, 1, "the second unload does not dispose twice")
equal(meshResources[1].releases, 1, "the second unload does not release the mesh twice")
equal(textureResources[1].releases, 1,
  "the second unload does not release the texture twice")
equal(updateRemovals, 1, "the second unload does not remove the update hook twice")

print(("%d checks passed (main.lua companion uninstall integration)"):format(checks))
