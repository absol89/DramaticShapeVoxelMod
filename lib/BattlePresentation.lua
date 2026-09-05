-- Compatibility contract for mods that replace Battle Art's native UI.
--
-- A consumer may wrap SUPPRESS_HOOK and claim one complete presentation
-- surface for the current draw. Claims affect rendering only: Battle Art
-- still owns battle state, animation, camera, sprites and the voxel arena.

local V = ...
local Runtime = require("src.mods.Runtime")
local UiBackplates = V.require("UiBackplates")

local BattlePresentation = {}

BattlePresentation.API_VERSION = 1
BattlePresentation.SUPPRESS_HOOK = "battle.presentation.suppress_native.v1"
BattlePresentation.SOURCE_MOD_ID = "BATTLE_ART_VOXEL_FORK"
BattlePresentation.SURFACES = {
  hud = "hud",
  text = "text",
  panels = "panels",
}

local validSurface = { hud = true, text = true, panels = true }

local function unclaimed()
  return false
end

local function activeMod(id)
  if not (V and V.mod and type(V.mod.find) == "function") then return nil end
  local ok, handle = pcall(V.mod.find, id)
  return ok and handle or nil
end

-- gen3_battle_ui v0.1 predates this contract. Its compatibility adapter looks
-- only for the old DRAMATIC_SHAPE id, while this fork exports
-- BATTLE_ART_VOXEL_FORK. Recognise its documented option without executing
-- any of its draw callbacks. A missing saved value means its schema default:
-- revampedBattleUI=true.
local function savedOption(modId, key)
  local ok, Game = pcall(require, "src.core.Game")
  if not ok or not Game then return nil end
  local options = Game.save and Game.save.options
  local bucket = options and options.modOptions
                 and options.modOptions[modId]
  if bucket then return bucket[key] end
  return nil
end

local function gen3BattleUiEnabled()
  if not activeMod("gen3_battle_ui") then return false end
  local value = savedOption("gen3_battle_ui", "revampedBattleUI")
  return value == nil or value ~= false
end

-- The older Gen 1 Modern UI patch used this exact opt-in flag. Do not assume
-- its WIP renderer is active merely because the mod is installed: unlike Gen
-- 3 UI's default-on option, absence here means off.
local function modernBattleUiEnabled()
  return activeMod("gen1_modern_ui") ~= nil
         and savedOption("gen1_modern_ui", "battleUiWip") == true
end

local function legacyClaim(surface, battle)
  if modernBattleUiEnabled() then return true end
  if not gen3BattleUiEnabled() then return false end
  if surface == "hud" or surface == "panels" then return true end
  if surface ~= "text" or not battle then return false end

  -- Match exactly the phases gen3_battle_ui v0.1 replaces. Mimic, Safari and
  -- the scripted demo deliberately retain the native presentation.
  if battle.phase == "messages" or battle.phase == "moveSelect" then
    return true
  end
  return battle.phase == "menu" and not battle.safari and not battle.demo
end

function BattlePresentation.suppressed(surface, battle)
  if not validSurface[surface] then return false end
  if UiBackplates.uiHidden(surface) then return true end

  if Runtime.wantsHook(BattlePresentation.SUPPRESS_HOOK) then
    local request = {
      apiVersion = BattlePresentation.API_VERSION,
      sourceModId = BattlePresentation.SOURCE_MOD_ID,
      surface = surface,
      battle = battle,
    }
    local ok, claimed = pcall(Runtime.call,
      BattlePresentation.SUPPRESS_HOOK, unclaimed, request)
    if ok and claimed == true then return true end
  end

  return legacyClaim(surface, battle)
end

function BattlePresentation.export()
  return {
    apiVersion = BattlePresentation.API_VERSION,
    suppressHook = BattlePresentation.SUPPRESS_HOOK,
    sourceModId = BattlePresentation.SOURCE_MOD_ID,
    surfaces = {
      hud = BattlePresentation.SURFACES.hud,
      text = BattlePresentation.SURFACES.text,
      panels = BattlePresentation.SURFACES.panels,
    },
    legacyAdapters = { "gen3_battle_ui", "gen1_modern_ui" },
  }
end

return BattlePresentation
