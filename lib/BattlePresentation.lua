-- Public, renderer-neutral compatibility seam for battle UI replacements.
--
-- A replacement UI may claim one native presentation surface at a time by
-- wrapping SUPPRESS_HOOK and returning exactly true.  Battle Art keeps all
-- gameplay, animation, and unclaimed rendering paths intact.

local Runtime = require("src.mods.Runtime")

local BattlePresentation = {}

BattlePresentation.API_VERSION = 1
BattlePresentation.SUPPRESS_HOOK = "battle.presentation.suppress_native.v1"
BattlePresentation.SOURCE_MOD_ID = "BATTLE_ART_VOXEL_FORK"
BattlePresentation.SURFACES = {
  hud = "hud",
  text = "text",
  panels = "panels",
}

local validSurface = {
  hud = true,
  text = true,
  panels = true,
}

local function unclaimed()
  return false
end

function BattlePresentation.suppressed(surface)
  if not validSurface[surface] then return false end
  if not Runtime.wantsHook(BattlePresentation.SUPPRESS_HOOK) then return false end

  local request = {
    apiVersion = BattlePresentation.API_VERSION,
    sourceModId = BattlePresentation.SOURCE_MOD_ID,
    surface = surface,
  }
  local ok, claimed = pcall(
    Runtime.call,
    BattlePresentation.SUPPRESS_HOOK,
    unclaimed,
    request
  )
  return ok and claimed == true
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
  }
end

return BattlePresentation
