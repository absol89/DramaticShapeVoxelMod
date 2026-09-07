-- Run from the engine root with DS_MOD_PATH=dev/DramaticShapeVoxelMod.
-- Exercise the registered pipeline and Map hook, not just helper arithmetic.
package.path = "./?.lua;./?/init.lua;" .. package.path
local T = require("tests.modkit")
local root = os.getenv("DS_MOD_PATH") or "mods/BATTLE_ART_VOXEL_FORK"
local run = T.sdk.loadMod(root, { data = T.fixtures.load() })
T.eq(#run.errors, 0, "mod loads: " .. table.concat(run.errors, "; "))
local V = assert(run.loader.exports.BATTLE_ART_VOXEL_FORK).lib
local Pipelines = require("src.render.Pipelines")
Pipelines.install(run.data)
local pipeline = assert(Pipelines.get("voxel"))
local Scene, Vox = V.require("VoxelScene"), V.require("Voxel3D")
local Heal, AA = V.require("HealOverlay"), V.require("AntiAlias")
local Gate = V.require("VoxelTransitionGate")
local canvas = {}
Scene.render = function() return canvas end
Vox.beginOverlay = function() return true end
Vox.endOverlay = function() end
Vox.project = function(x, y, z) return x, z, 1, .5 end
AA.expand = function(w, h) return w, h end
AA.factor = function() return 1 end
AA.resolve = function(c) return c end
Gate.observe = function() end
Gate.blocking = function() return false end
local animation = { visible = true }
local state = { map = { id = "TEST" }, camera = {}, player = {}, healAnim = animation }
local healCalls = 0
Heal.draw = function(ha, project, scale, ctx)
  healCalls = healCalls + 1
  T.eq(ha, animation, "machine overlay gets the live animation")
  T.eq(ctx.state.healAnim, animation, "animation restored before the overlay")
end
local ctx = { state = state, width = 160, height = 144, vw = 160, vh = 144, scale = 1 }
ctx.drawFx = function()
  T.eq(state.healAnim, nil, "flat FX cannot draw the misplaced heal overlay")
end
T.eq(pipeline.drawWorld(ctx), canvas, "voxel frame completes")
T.eq(healCalls, 1, "active pipeline draws the machine overlay")
T.eq(state.healAnim, animation, "heal script retains its animation")
ctx.drawFx = function() error("intentional FX failure") end
T.eq(pcall(pipeline.drawWorld, ctx), false, "field FX errors propagate")
T.eq(state.healAnim, animation, "FX failure cannot strand the heal script")

local Mesher = V.require("ChunkMesher")
local seen
Mesher.refresh = function(...) seen = { ... } end
local Map = require("src.world.Map")
local map = setmetatable({ id = "CUT", def = { width = 1, height = 1, blocks = { 1 } } }, Map)
map:setBlock(0, 0, 2)
T.check(seen ~= nil, "live block hook calls the mesher")
T.eq(seen and seen[1], "CUT", "only the edited map is refreshed")
T.eq(seen and seen[2], 0, "block x reaches the cut fast path")
T.eq(seen and seen[3], 0, "block y reaches the cut fast path")
T.eq(seen and seen[4], map, "new block data reaches the cut fast path")
T.eq(seen and seen[5], 1, "old block id limits removal to changed cells")
seen = nil
map:setBlock(0, 0, 2)
T.eq(seen, nil, "an unchanged block does not schedule another rebuild")

-- Drive the real water pass and the real character transform together.
local Water, Mat4 = V.require("Water"), V.require("Mat4")
local First = V.require("FirstPerson")
First.cardBlend = function() return 0 end
V.require("VoxelState").angle = math.pi / 2
V.require("SpriteBillboards").mesh = function() return {} end
V.require("ShadowMap").snug = function(m) return m end
local models, reflectedTexture, waterContext = {}, {}, nil
Vox.draw = function(_, _, model) models[#models + 1] = model end
Vox.depthReadable = function() return true end
Vox.beginCast = function() return reflectedTexture end
Vox.endCast = function() end
Vox.beginWater = function() return {}, {} end
Vox.endWater = function() end
Vox.size = function() return 160, 144 end
Water.enabled = function() return true end
Water.begin = function(c) waterContext = c; return true end
Water.finish = function() end
local sprite = { def = { frames = 1 }, resolveImage = function() return {} end }
local function drawPlayer()
  Scene.drawEntity(sprite, 32, 48, "down", 0, false, 0)
end
Scene.drawWater({}, drawPlayer)
T.eq(waterContext.cast, reflectedTexture, "live water shader receives the cast canvas")
local plane = V.require("TileShape").heights().water
T.same(models[1], Mat4.mul(Mat4.billboard(32, 48, 2 * plane + Water.CAST_RAISE,
  0, 0, false), Mat4.scale(1, -1, 1)), "player is mirrored about shipped water height")
models = {}
drawPlayer()
T.same(models[1], Mat4.billboard(32, 48, 0, 0, 0, false),
  "ordinary player remains upright after reflection")
Scene.drawWater({}, function() error("intentional reflection failure") end)
models = {}
drawPlayer()
T.same(models[1], Mat4.billboard(32, 48, 0, 0, 0, false),
  "reflection errors cannot leave the player flipped")
T.finish("restored world feature hooks")
