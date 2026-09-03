-- Event bridge for the optional Legendary normal-battle Poké Ball system.
--
-- The engine remains authoritative for item use, catch odds, shakes and the
-- final result. This module mirrors those existing events into BattleScene's
-- real 3D prop and suppresses only the old ball-bearing animation layers.

local V = ...

local Settings = V.require("PokeballSettings")
local Bridge = {}

local activeOwner = nil

-- TEST16's proven state-owned suppression set. These are the engine layers
-- that carry the legacy black/white capture ball; Legendary's beam, trails,
-- stars and breakout are rendered independently inside BattleScene.
local BALL_LAYER_ANIMS = {
  TOSS_ANIM = true,
  GREATTOSS_ANIM = true,
  ULTRATOSS_ANIM = true,
  BLOCKBALL_ANIM = true,
  POOF_ANIM = true,
  SHAKE_ANIM = true,
}

local CAPTURE_FLOW_ANIMS = {
  TOSS_ANIM = true,
  GREATTOSS_ANIM = true,
  ULTRATOSS_ANIM = true,
  BLOCKBALL_ANIM = true,
  POOF_ANIM = true,
  HIDEPIC_ANIM = true,
  SHAKE_ANIM = true,
  SHOWPIC_ANIM = true,
}

local function scene()
  local ok, value = pcall(function() return V.require("BattleScene") end)
  return ok and value or nil
end

local function staged()
  if not Settings.active() then return false end
  local ok, battles = pcall(function() return V.require("OverworldBattle") end)
  return ok and battles and battles.enabled and battles.enabled() or false
end

local function clearOwner(owner)
  if type(owner) ~= "table" then return end
  owner._legendaryBallSequence = nil
  owner._legendaryBallMove = nil
  owner._legendaryBallCaught = nil
  owner._legendaryBallCaughtFxSent = nil
  owner._dsBallSequenceActive = nil
  owner._dsBallMove = nil
  owner._dsBallCaught = nil
  owner._dsBallCaughtFxSent = nil
  owner.dramaticShape3DBallActive = nil
  owner.dramaticShape3DBallId = nil
  if owner.animPlayer then
    owner.animPlayer._ds3DBattleState = nil
    owner.animPlayer._ds3DBallSuppress2D = nil
  end
end

function Bridge.finish()
  clearOwner(activeOwner)
  activeOwner = nil
  local s = scene()
  if s and s.finishNormalBattleBall then
    pcall(s.finishNormalBattleBall)
  end
end

function Bridge.changed()
  if not staged() then Bridge.finish() end
end

function Bridge.install()
  local okState, BattleState = pcall(require, "src.battle.BattleState")
  local okAnim, AnimPlayer = pcall(require, "src.battle.AnimPlayer")
  if not (okState and okAnim and type(BattleState) == "table"
      and type(AnimPlayer) == "table") then
    return false
  end

  if type(BattleState.ballChain) == "function"
      and not BattleState.legendaryVisualsBallChain then
    local previous = BattleState.ballChain
    BattleState.ballChain = function(self, tossAnim, caught, shakes, ball, ...)
      if staged() and type(self) == "table" then
        clearOwner(activeOwner)
        activeOwner = self
        self._legendaryBallSequence = true
        self._legendaryBallMove = tossAnim
        self._legendaryBallCaught = caught and true or false
        self._legendaryBallCaughtFxSent = false
        -- These are the established TEST436 capture-owner fields. Keep the
        -- Battle Art bridge bilingual so every renderer sees the same throw.
        self._dsBallSequenceActive = true
        self._dsBallMove = tossAnim
        self._dsBallCaught = caught and true or false
        self._dsBallCaughtFxSent = false
        self.dramaticShape3DBallActive = true
        self.dramaticShape3DBallId = ball or "POKE_BALL"
        if self.animPlayer then
          self.animPlayer._ds3DBattleState = self
          self.animPlayer._ds3DBallSuppress2D = true
        end
        local s = scene()
        if s and s.startNormalBall then
          pcall(s.startNormalBall, ball or "POKE_BALL", caught, shakes, self)
        end
      else
        Bridge.finish()
      end
      return previous(self, tossAnim, caught, shakes, ball, ...)
    end
    BattleState.legendaryVisualsBallChain = true
  end

  if type(AnimPlayer.start) == "function"
      and not AnimPlayer.legendaryVisualsBallStart then
    local previous = AnimPlayer.start
    AnimPlayer.start = function(self, moveId, attackerIsPlayer, opts, ...)
      local owner = activeOwner
      if owner and owner._legendaryBallSequence then
        if not staged() then
          Bridge.finish()
        else
          owner._legendaryBallMove = moveId
          owner._dsBallMove = moveId
          if owner.animPlayer then
            owner.animPlayer._ds3DBattleState = owner
          end
          local s = scene()
          if s and s.normalBallAnimEvent then
            pcall(s.normalBallAnimEvent, moveId)
          end
          if moveId ~= nil and not CAPTURE_FLOW_ANIMS[moveId]
              and not owner._legendaryBallCaught then
            clearOwner(owner)
            activeOwner = nil
          end
        end
      end
      return previous(self, moveId, attackerIsPlayer, opts, ...)
    end
    AnimPlayer.legendaryVisualsBallStart = true
  end

  if type(BattleState.drawAnimLayer) == "function"
      and not BattleState.legendaryVisualsBallDraw then
    local previous = BattleState.drawAnimLayer
    BattleState.drawAnimLayer = function(self, colorized, ...)
      local active = staged() and self and self._legendaryBallSequence
      if active and self.lockedBall and self._legendaryBallCaught then
        if not self._legendaryBallCaughtFxSent then
          self._legendaryBallCaughtFxSent = true
          self._dsBallCaughtFxSent = true
          local s = scene()
          if s and s.normalBallCaughtEvent then
            pcall(s.normalBallCaughtEvent)
          end
        end
        -- TEST16: a successful capture's lockedBall is the persistent flat
        -- duplicate. The retained Legendary ball owns this frame instead.
        return
      end

      -- The active move is mirrored on BattleState itself. This is the exact
      -- ownership rule that made TEST16 reliable when the AnimPlayer instance
      -- used to render differed from BattleState.animPlayer.
      local move = self and (self._dsBallMove or self._legendaryBallMove)
      local sequence = self and
        (self._dsBallSequenceActive or self._legendaryBallSequence)
      if active and sequence and move and BALL_LAYER_ANIMS[move]
          and (self.animPlaying or self.lockedBall) then
        return
      end

      return previous(self, colorized, ...)
    end
    BattleState.legendaryVisualsBallDraw = true
  end

  return true
end

return Bridge
