-- Read-only compatibility contract for mods that compose effects with Battle
-- Art's staged battle. Consumers receive copies of projection coordinates and
-- ownership metadata; no setting or live Battle Art table is exposed.

local BattleStage = {}

BattleStage.API_VERSION = 1
BattleStage.SOURCE_MOD_ID = "BATTLE_ART_VOXEL_FORK"

local OWNERSHIP = {
  arena = true,
  battlers = true,
  trainers = true,
  camera = true,
  hud = true,
  transition = true,
  animationProjection = true,
}

local function copyPoint(value, fallback)
  if type(value) == "table" and type(value[1]) == "number"
      and type(value[2]) == "number" then
    return { value[1], value[2] }
  end
  return { fallback[1], fallback[2] }
end

local function copyOwnership()
  local out = {}
  for name, claimed in pairs(OWNERSHIP) do out[name] = claimed end
  return out
end

local function call(object, name, ...)
  local fn = object and object[name]
  if type(fn) ~= "function" then return nil end
  local ok, value = pcall(fn, ...)
  return ok and value or nil
end

function BattleStage.export(battles)
  local anchors = battles and battles.ANCHOR or {}
  local authoredPlayer = copyPoint(anchors.player, { 26, 96 })
  local authoredEnemy = copyPoint(anchors.enemy, { 124, 56 })

  local function state(expectedBattle)
    local battle = call(battles, "battle")
    if battle == nil or (expectedBattle ~= nil and battle ~= expectedBattle) then
      return nil
    end

    local out = {
      apiVersion = BattleStage.API_VERSION,
      sourceModId = BattleStage.SOURCE_MOD_ID,
      battle = battle,
      staged = true,
      ready = false,
      ownership = copyOwnership(),
      surfaceOwned = true,
      externalCamera = true,
      layerOwnsProjection = true,
    }

    local shot = call(battles, "stageShot") or call(battles, "shot")
    if type(shot) ~= "table" then return out end

    local player = copyPoint(shot.player, authoredPlayer)
    local enemy = copyPoint(shot.enemy, authoredEnemy)
    local backPinned = shot.backPinned
    if backPinned == nil then backPinned = call(battles, "backPinned") == true end
    if backPinned then player = copyPoint(authoredPlayer, authoredPlayer) end

    local scale = tonumber(shot.animationScale) or tonumber(call(battles, "animScale", shot,
      player[1], player[2])) or 1
    if not (scale > 0) or scale ~= scale then scale = 1 end

    local authoredCenter = {
      (authoredPlayer[1] + authoredEnemy[1]) / 2,
      (authoredPlayer[2] + authoredEnemy[2]) / 2,
    }
    local projectedCenter = {
      (player[1] + enemy[1]) / 2,
      (player[2] + enemy[2]) / 2,
    }

    out.ready = true
    out.backPinned = backPinned
    out.animationScale = scale
    out.authoredAnchors = {
      player = copyPoint(authoredPlayer, authoredPlayer),
      enemy = copyPoint(authoredEnemy, authoredEnemy),
    }
    out.projectedAnchors = { player = player, enemy = enemy }
    out.layerTransform = {
      authoredCenter = authoredCenter,
      projectedCenter = projectedCenter,
      scale = scale,
    }
    return out
  end

  return {
    apiVersion = BattleStage.API_VERSION,
    sourceModId = BattleStage.SOURCE_MOD_ID,
    ownership = copyOwnership(),
    enabled = function() return call(battles, "enabled") == true end,
    state = state,
  }
end

return BattleStage
