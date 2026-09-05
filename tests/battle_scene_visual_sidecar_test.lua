-- ROM-free staged-battle checks for original visual-object sidecars.
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

local function mesh(name) return { name = name } end
local currentTerrain = mesh("current-terrain")
local neighborTerrain = mesh("neighbor-terrain")
local alternateFullTerrain = mesh("alternate-full-terrain")
local alternateBodyTerrain = mesh("alternate-body-terrain")
local currentWater = mesh("current-water")
local neighborWater = mesh("neighbor-water")
local alternateFullWater = mesh("alternate-full-water")
local alternateBodyWater = mesh("alternate-body-water")
local currentSign = mesh("current-sign-original")
local neighborSign = mesh("neighbor-sign-original")
local alternateFullSign = mesh("alternate-full-sign-original")
local alternateBodySign = mesh("alternate-body-sign-original")

local current = {
  id = "CURRENT", def = { width = 1, height = 1 },
  tileset = { id = "OVERWORLD" },
}
local neighbor = {
  id = "NEIGHBOR", def = { width = 1, height = 1 },
  tileset = { id = "OVERWORLD" },
}
local alternate = {
  id = "ALTERNATE", def = { width = 1, height = 1 },
  tileset = { id = "CAVERN" },
}

local colorDraws, shadowDraws, pairCalls = {}, {}, {}
local alternateFullReady = true
local function countDraws(log, target)
  local count = 0
  for _, draw in ipairs(log) do
    if draw.mesh == target then count = count + 1 end
  end
  return count
end
local function modelFor(log, target)
  for _, draw in ipairs(log) do
    if draw.mesh == target then return draw.model end
  end
end

local Mat4 = {
  translate = function(x, y, z) return { "translate", x, y, z } end,
  rotateY = function(value) return { "rotateY", value } end,
  scale = function(x, y, z) return { "scale", x, y, z } end,
  mul = function(a, b) return { "mul", a, b } end,
  lookAt = function() return { "lookAt" } end,
}

local Voxel3D = {
  SHADOW_ALPHA = 0.3,
  tint = { 1, 1, 1 },
  eye = { 0, 20, 40 },
  focus = { 0, 0, 0 },
  fovY = math.rad(60),
  vp = {
    0.01, 0, 0, 0,
    0, 0.01, 0, 0,
    0, 0, 0, 0,
    0, 0, 0, 1,
  },
}
function Voxel3D.available() return true end
function Voxel3D.viewProjection()
  if Voxel3D.camera then
    Voxel3D.eye = Voxel3D.camera.eye
    Voxel3D.focus = Voxel3D.camera.focus
  end
  return Voxel3D.vp
end
function Voxel3D.beginScene() return true end
function Voxel3D.draw(value, _, model)
  colorDraws[#colorDraws + 1] = { mesh = value, model = model }
end
function Voxel3D.endScene() return { name = "battle-canvas" } end
function Voxel3D.backdrop() end
function Voxel3D.flatten() end
function Voxel3D.seams() end
function Voxel3D.glass() end
function Voxel3D.dayTint() end
function Voxel3D.lighting() end

local ShadowMap = {
  KX = 0.25, KZ = 0.5, clipVP = {}, uvVP = {}, bias = 0, res = 0,
}
function ShadowMap.available() return true end
function ShadowMap.stale() return true end
function ShadowMap.begin() return true end
function ShadowMap.draw(value, _, model)
  shadowDraws[#shadowDraws + 1] = { mesh = value, model = model }
end
function ShadowMap.finish() end
function ShadowMap.sprites() end
function ShadowMap.snug(model) return model end
function ShadowMap.discard() end
function ShadowMap.active() return false end
function ShadowMap.texture() return nil end

local ChunkMesher = {}
function ChunkMesher.setLive() end
function ChunkMesher.request(map, bodyOnly)
  pairCalls[#pairCalls + 1] = { operation = "request", map = map, body = bodyOnly }
end
function ChunkMesher.pair(map, bodyOnly)
  pairCalls[#pairCalls + 1] = { operation = "pair", map = map, body = bodyOnly }
  if map ~= alternate then return nil, nil, nil, nil end
  if not bodyOnly then
    if not alternateFullReady then return nil, nil, nil, nil end
    return alternateFullTerrain, alternateFullWater, {}, {
      { id = "alternate-sign", mesh = alternateFullSign },
    }
  end
  -- The third result models an active overworld claim. BattleScene must use
  -- the fourth, original-shadow result for both of its own passes.
  return alternateBodyTerrain, alternateBodyWater, {}, {
    { id = "alternate-sign", mesh = alternateBodySign },
  }
end
function ChunkMesher.grass() return nil end
function ChunkMesher.flowers() return nil end
function ChunkMesher.visualObjectVisible()
  error("BattleScene must not apply overworld replacement claims", 0)
end

local VoxelScene = {}
function VoxelScene.prefetch(state)
  check(state.map == current, "current-map prefetch receives the overworld state")
  return currentTerrain, { neighborTerrain }, currentWater, { neighborWater },
    true, { { id = "current-sign", mesh = currentSign } },
    { { { id = "neighbor-sign", mesh = neighborSign } } }
end
function VoxelScene._modeColors() return {} end
function VoxelScene.groundAt() return 0 end
function VoxelScene.skyColor() return { 0.1, 0.2, 0.3, 1 } end
function VoxelScene.skyShade() return { 0.1, 0.1, 0.1, 1 } end
function VoxelScene.pull() return 0 end

local TerrainAtlas = {
  setLive = function() end,
  forMap = function(map) return { map = map.id } end,
}
local BattleCam = {
  rig = function(arena)
    return {
      eye = { arena.mid[1], 24, arena.mid[2] + 40 },
      focus = { arena.mid[1], 0, arena.mid[2] },
      up = { 0, 1, 0 }, fov = math.rad(60), curve = 0,
    }, math.rad(45)
  end,
  frameH = function() return 96 end,
}
local BattleBillboard = {
  FULL_W = 16, FULL_PIC = 56, PULL = 0,
  yawToward = function() return 0 end,
  mesh = function() return mesh("unused-card") end,
}
local StadiumModels = {
  placements = function() return {} end,
  uses = function() return false end,
  drawShadow = function() return false end,
  draw = function() return true end,
}
local DayNight = {
  applyRig = function() end,
  tint = function() return { 1, 1, 1 } end,
  isCanopy = function() return false end,
  windowLight = function() return 0 end,
  shadowScale = function() return 1 end,
}
local UiBackplates = {
  arenaWhite = function() return false end,
  arenaGen6 = function() return false end,
  arenaPng = function() return false end,
  arenaArt = function() return false end,
  bossEnabled = function() return false end,
  spritesUnlit = function() return false end,
  backdropOffsetPixels = function() return 0 end,
}
local AntiAlias = {
  expand = function(w, h) return w, h end,
  resolve = function(canvas) return canvas end,
}

package.loaded["src.render.PaletteFX"] = { pal = function() return {} end }
package.loaded["src.world.Map"] = { isOutdoor = function() return false end }
package.loaded["src.core.Game"] = { data = {}, stack = { top = function() end } }
package.loaded["src.render.TileRenderer"] = { tick = function() end }
package.loaded["src.render.Renderer"] = { fitScale = function() return 2 end }

love = {
  graphics = {
    getPixelDimensions = function() return 320, 288 end,
    getDimensions = function() return 320, 288 end,
    setShader = function() end,
    setDepthMode = function() end,
    setCanvas = function() end,
  },
}

local namespace = {}
function namespace.require(name)
  return assert(({
    Mat4 = Mat4,
    Voxel3D = Voxel3D,
    ShadowMap = ShadowMap,
    ChunkMesher = ChunkMesher,
    TerrainAtlas = TerrainAtlas,
    VoxelScene = VoxelScene,
    BattleCam = BattleCam,
    BattleBillboard = BattleBillboard,
    StadiumModels = StadiumModels,
    DayNight = DayNight,
    UiBackplates = UiBackplates,
    Gen6Backdrop = { image = function() return nil end },
    BackdropImage = { load = function() return nil end },
    BossBackdrop = { image = function() return nil end },
    AntiAlias = AntiAlias,
    GlassMask = { texture = function() return nil end },
  })[name], "unexpected BattleScene module " .. tostring(name))
end

local BattleScene = assert(loadfile("lib/BattleScene.lua"))(namespace)
local player = { id = "player" }
local state = {
  map = current,
  player = player,
  entities = { player },
  neighbors = { { map = neighbor, ox = 64, oy = -32 } },
  paletteNameFor = function() return "default" end,
}
local function arena(host)
  return {
    map = host,
    x = 0, y = 0, shape = "test",
    mid = { 24, 24 },
    player = { 16, 16 }, enemy = { 32, 32 },
    playerCell = { 1, 1 },
  }
end

local function resetLogs()
  colorDraws, shadowDraws, pairCalls = {}, {}, {}
end

resetLogs()
check(BattleScene.render(state, arena(nil), nil, 1),
  "current-map staged battle renders")
equal(countDraws(colorDraws, currentSign), 1,
  "current-map original sign draws in the color pass")
equal(countDraws(shadowDraws, currentSign), 1,
  "current-map original sign draws in the shadow pass")
equal(countDraws(colorDraws, neighborSign), 1,
  "neighbor original sign draws in the color pass")
equal(countDraws(shadowDraws, neighborSign), 1,
  "neighbor original sign draws in the shadow pass")
local neighborColorModel = modelFor(colorDraws, neighborSign)
local neighborShadowModel = modelFor(shadowDraws, neighborSign)
equal(neighborColorModel[1], "translate",
  "neighbor color sidecar uses its map transform")
equal(neighborColorModel[2], 64, "neighbor color sidecar keeps X offset")
equal(neighborColorModel[4], -32, "neighbor color sidecar keeps Z offset")
equal(neighborShadowModel[2], 64, "neighbor shadow sidecar keeps X offset")
equal(neighborShadowModel[4], -32, "neighbor shadow sidecar keeps Z offset")

resetLogs()
check(BattleScene.render(state, arena(alternate), nil, 2),
  "alternate full-arena staged battle renders")
equal(#pairCalls, 2, "alternate full arena needs no body fallback")
equal(pairCalls[2].body, false, "alternate arena selects the ready full cache")
equal(countDraws(colorDraws, alternateFullSign), 1,
  "alternate full original sign draws in the color pass")
equal(countDraws(shadowDraws, alternateFullSign), 1,
  "alternate full original sign draws in the shadow pass")
equal(countDraws(colorDraws, alternateBodySign), 0,
  "alternate full arena does not mix in the body sidecar")

alternateFullReady = false
resetLogs()
check(BattleScene.render(state, arena(alternate), nil, 3),
  "alternate-arena staged battle renders")
equal(#pairCalls, 3, "alternate arena requests full and falls back to body")
equal(pairCalls[2].body, false, "alternate arena checks the full cache first")
equal(pairCalls[3].body, true, "alternate arena selects the body cache fallback")
equal(countDraws(colorDraws, alternateBodySign), 1,
  "alternate body original sign draws in the color pass")
equal(countDraws(shadowDraws, alternateBodySign), 1,
  "alternate body original sign draws in the shadow pass")
equal(countDraws(colorDraws, currentSign), 0,
  "alternate arena does not reuse current-map sidecars")
equal(countDraws(shadowDraws, neighborSign), 0,
  "alternate arena does not reuse neighbor sidecars")

-- Model casters must reach the adapter once even when sprites are unlit.
-- A direct instance call bypasses its depth conversion and used to double
-- submit the model in lit scenes.
local adapterCalls, directCalls = 0, 0
local placement = {
  instance = { drawShadow = function() directCalls = directCalls + 1 end },
  modelMatrix = {},
}
StadiumModels.placements = function() return { player = placement } end
StadiumModels.drawShadow = function(value, matrix)
  equal(value, placement, "shadow adapter receives the model placement")
  equal(matrix, ShadowMap.clipVP, "shadow adapter receives the source depth matrix")
  adapterCalls = adapterCalls + 1
  return true
end
for _, unlit in ipairs({ false, true }) do
  UiBackplates.spritesUnlit = function() return unlit end
  adapterCalls, directCalls = 0, 0
  check(BattleScene.render(state, arena(nil), nil, 4), "model shadow scene renders")
  equal(adapterCalls, 1, "one model shadow submission regardless of sprite lighting")
  equal(directCalls, 0, "scene never bypasses the model shadow adapter")
end

print(("%d checks passed (BattleScene visual sidecars and model shadows)"):format(checks))
