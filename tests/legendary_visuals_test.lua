-- Legendary Visuals is opt-in: Battle Art remains the default, while the
-- community world styles and standing trainer can be selected independently.

package.path = "./?.lua;./?/init.lua;" .. package.path

local T = require("tests.modkit")
local Data = T.fixtures.load()
local MOD_PATH = os.getenv("DS_MOD_PATH") or "mods/BattleArtVoxelFork"
local run = T.sdk.loadMod(MOD_PATH, { data = Data })
T.eq(#run.errors, 0,
  "BATTLE_ART_VOXEL_FORK loads clean: " .. table.concat(run.errors, "; "))

local lib = run.loader.exports.BATTLE_ART_VOXEL_FORK.lib
local Community = lib.require("CommunityVisuals")
local ChunkMesher = lib.require("ChunkMesher")
local GranitePillars = lib.require("GranitePillars")
local Sky = lib.require("Sky")
local OverworldBattle = lib.require("OverworldBattle")

T.eq(#Community.settings, 7, "all seven community world rows are registered")
T.eq(Community.layout(), "default", "Battle Art pillars remain the default")
T.check(not Community.customPillars(), "the default does not replace pillars")
T.check(not Community.customTrees(), "the default does not replace trees")
T.check(not Community.customWalls(), "the default does not replace masonry")

Community.pillars:sync("top")
T.eq(Community.layout(), "top", "top-interlock pillar layout is selectable")
T.check(Community.customPillars(), "a selected pillar layout enables the replacement")
T.eq(Community.pillarColor(), "granite", "pillar material stays locked to granite")

Community.trees:sync("n64memory")
T.check(Community.customTrees(), "the Legendary S/M/L/XL tree family is selectable")
Community.walls:sync("n64memory")
Community.masonry:sync("red")
T.check(Community.customWalls(), "Legendary wall geometry is selectable")
T.eq(Community.wallColor(), "red", "red brick is a supported wall material")

T.eq(ChunkMesher.kantoSurfaceKind("OVERWORLD", "ground", 57), "path",
  "the Kanto packed-earth path swatch is classified")
T.eq(ChunkMesher.kantoSurfaceKind("OVERWORLD", "ground", 60), "wood",
  "the Kanto bridge timber swatch is classified")
T.eq(ChunkMesher.kantoSurfaceKind("FOREST", "ground", 57), nil,
  "community surfaces do not leak into another tileset")
T.check(type(GranitePillars.draw) == "function"
    and type(GranitePillars.invalidate) == "function",
  "the granite pillar renderer exposes draw and invalidation")

local skySource = Sky._source()
T.check(skySource:find("mix(c, bandAt(base + 1.0), fract(pos))", 1, true),
  "sky colors interpolate continuously between palette stops")
T.check(not skySource:find("floor(sc.y / cell)", 1, true),
  "sky color is no longer snapped into horizontal shelves")
T.check(not skySource:find("parity", 1, true),
  "the checker pattern is absent from the sky shader")

T.eq(OverworldBattle.trainerBattleSetting:get(), "stock",
  "the stock trainer remains the safe default")
OverworldBattle.trainerBattleSetting:sync("legendary")
T.check(OverworldBattle.legendaryTrainerEnabled(),
  "the standing 3D trainer bridge can be enabled")

local battleScene = assert(io.open(MOD_PATH .. "/lib/BattleScene.lua"))
local battleSource = battleScene:read("*a")
battleScene:close()
T.check(battleSource:find("RED3D_DIRECT_BATTLE_DRAW", 1, true),
  "the arena invokes the optional 3D trainer provider")
T.check(battleSource:find("pcall(direct, arena, groundY", 1, true),
  "the provider is isolated from the battle renderer")

T.finish("Legendary visuals")
