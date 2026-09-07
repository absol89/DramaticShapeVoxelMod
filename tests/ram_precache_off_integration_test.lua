package.path = "./?.lua;./?/init.lua;" .. package.path
local T = require("tests.modkit")
local root = os.getenv("DS_MOD_PATH") or "mods/BATTLE_ART_VOXEL_FORK"
local run = T.sdk.loadMod(root, { data = T.fixtures.load() })
T.eq(#run.errors, 0, "mod loads cleanly")
local V = assert(run.loader.exports.BATTLE_ART_VOXEL_FORK).lib
local Ram, Disk = V.require("RamPrecache"), V.require("VoxelMeshDisk")
local Precache, Mesher = V.require("VoxelPrecache"), V.require("ChunkMesher")
local Runtime = require("src.mods.Runtime")
Ram.setting:setIndex(10)
local binds, plans, probes, continued, newGames, screens = 0, 0, 0, 0, 0, 0
Disk.bind = function() binds = binds + 1 end
Disk.ramPlan = function() plans = plans + 1; return {}, 0 end
require("src.core.SaveData").load = function() probes = probes + 1 end
local game = { data = run.data, stack = { push = function() screens = screens + 1 end } }
local items = Runtime.call("ui.title_menu.items", function(_, value) return value end, game, {
  { label = "CONTINUE", onSelect = function() continued = continued + 1 end },
  { label = "NEW GAME", onSelect = function() newGames = newGames + 1 end },
})
items[1].onSelect()
items[2].onSelect()
T.eq(continued, 1, "OFF continues immediately")
T.eq(newGames, 1, "OFF starts a new game immediately")
T.eq(binds, 0, "OFF does not probe cache storage at title/continue/new game")
T.eq(plans, 0, "OFF does not enumerate cache files")
T.eq(probes, 0, "OFF does not read a save solely to plan preloading")
T.eq(screens, 0, "OFF does not open an eager loading screen")
T.eq(Disk.ramStats().enabled, true, "OFF still establishes session RAM")
local predictions = 0
Precache.candidates = function() predictions = predictions + 1; return {} end
Precache.update({ data = { maps = {} }, overworld = { map = { id = "ROUTE_1" } } })
T.eq(predictions, 0, "OFF never discovers or warms speculative destinations")
Mesher.request({ id = "SPECULATIVE" }, false, nil, false)
Mesher.request({ id = "VISIBLE" }, true, nil, "visible")
T.check(Mesher.cancelSpeculative("SPECULATIVE", false), "an eager job can be cancelled")
T.eq(Mesher.jobPending("SPECULATIVE", false), false, "cancelled eager job leaves the queue")
T.eq(Mesher.cancelSpeculative("VISIBLE", true), false, "live neighbour jobs cannot be cancelled")
T.eq(Mesher.jobPending("VISIBLE", true), true, "live generation remains queued")

Mesher.invalidate()
Ram.setting:setIndex(1)
Precache.candidates = function() return { { id = "DESTINATION" } } end
Precache.cacheable = function() return true end
Precache.masksFor = function() return {} end
Mesher.peek = function() return {} end
require("src.world.MapLoader").load = function(_, id) return { id = id } end
local travel = { data = { maps = {} }, overworld = { map = { id = "CURRENT" } } }
Precache.update(travel)
T.eq(Mesher.jobPending("DESTINATION", false), true, "non-OFF still queues predictive work")
Ram.setting:setIndex(10)
Precache.update(travel)
T.eq(Mesher.jobPending("DESTINATION", false), false, "switching OFF cancels the outstanding prediction")
Ram.setting:setIndex(1)
Precache.update(travel)
Mesher.request({ id = "DESTINATION" }, false, nil, true)
Ram.setting:setIndex(10)
Precache.update(travel)
T.eq(Mesher.jobPending("DESTINATION", false), true, "OFF preserves a prediction promoted to the live map")

-- The gameplay update also establishes RAM policy before any live build,
-- covering a mod enabled after CONTINUE rather than only title-menu startup.
local Pipelines = require("src.render.Pipelines")
Pipelines.install(run.data)
local voxel = V.require("VoxelState")
voxel.update = function() end
voxel.active = function() return true end
V.require("VoxelTransitionGate").update = function() end
V.require("FirstPerson").update = function() end
V.require("DayNight").update = function() end
V.require("OverworldBattle").update = function() end
local sessionCalls, liveCalls = 0, 0
local beginSession = Disk.beginSession
Disk.beginSession = function(ramOnly)
  sessionCalls = sessionCalls + 1
  T.eq(ramOnly, true, "live update selects RAM-only mode")
  return beginSession(ramOnly)
end
V.require("VoxelScene").prefetch = function()
  liveCalls = liveCalls + 1
  T.eq(sessionCalls, 1, "RAM policy is established before live generation")
end
Mesher.pump = function() end
local Game = require("src.core.Game")
Game.overworld = { map = { id = "CURRENT" }, camera = {} }
Game.stack = { top = function() return Game.overworld end }
Pipelines.get("voxel").update(1 / 60, 0)
T.eq(liveCalls, 1, "OFF still schedules live terrain")
T.eq(binds, 0, "gameplay OFF still avoids a persistent backend probe")

-- Unsupported/restricted GC must not turn generator completion into a crash.
local Screen = V.require("VoxelPrecacheScreen")
Disk.stats = function() return {} end
Disk.writePrecacheFailureLog = function() return false end
local screen = setmetatable({ failures = {} }, Screen)
local called = false
local env = getfenv(Screen.finish)
local original = env.collectgarbage
env.collectgarbage = function() called = true; error("GC unavailable") end
T.check(pcall(screen.finish, screen, "complete"), "generator completion tolerates rejected GC")
T.eq(called, true, "test exercised the guarded GC call")
env.collectgarbage = original
T.finish("RAM precache OFF live hooks")
