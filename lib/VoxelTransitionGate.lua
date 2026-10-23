-- Bounded presentation cover for voxel loads. Continue/travel arm ahead of
-- the map swap; ordinary crossings arm only when no complete frame exists.
-- This owns no input, transition callbacks or world simulation.

local V = ...

local Gate = {
  HOLD_SECONDS = 0.5,
  -- A corrupt cache record, unsupported neighbour or driver failure must never
  -- turn a presentation effect into a soft lock. Healthy builds normally clear
  -- in a fraction of this; after the ceiling the engine's 2D world is safer.
  MAX_SECONDS = 20,
  -- TEST145: the 20 s ceiling used to fire on big areas (Lavender after Fly)
  -- that were still building fine, dropping the player into 2D for most of
  -- a minute. Now the card stays while the build is visibly progressing and
  -- only gives up after STALL_SECONDS with no build work at all, or at the
  -- hard ceiling HARD_SECONDS. A genuine renderer failure still exits at once.
  STALL_SECONDS = 10,
  HARD_SECONDS = 60,
}
local progressMark, progressAt = nil, 0
local function buildProgress()
  local ok, B = pcall(V.require, "BuildBudget")
  return ok and B and B.progress or nil
end

local active = false
local map = nil
local targetId = nil
local ready = false
local elapsed = 0
local automatic = false
local suppressedMap, observedMap

local function warn(reason, destination)
  local log = V.mod and V.mod.log
  if log and log.warn then
    pcall(log.warn, log, "Legendary loading fallback: %s; map=%s",
      reason, tostring(destination and destination.id or targetId))
  end
end

function Gate.qualifies(opts, arrival)
  local via = opts and opts.via
  return via == "boot" or via == "fly"
         or arrival == "fly" or arrival == "teleport"
end

local function voxelEnabled()
  local Voxel = V.require("VoxelState")
  local Voxel3D = V.require("Voxel3D")
  return Voxel.active() and Voxel3D.available()
end

function Gate.arm(destinationOrId, cold)
  if not destinationOrId then return end
  map = type(destinationOrId) == "table" and destinationOrId or nil
  targetId = map and map.id or destinationOrId
  active = true
  ready = false
  elapsed = 0
  automatic = cold == true
  suppressedMap = nil
  progressMark, progressAt = buildProgress(), 0
end

-- Do not re-arm every frame after a timeout or a genuine renderer failure.
-- A successful frame or a different map permits the next loading episode.
function Gate.coverCold(destination)
  if not destination or active or suppressedMap == destination then return end
  Gate.arm(destination, true)
end

function Gate.fail(destination, reason)
  if suppressedMap ~= destination then
    warn(reason or "renderer failure", destination)
  end
  Gate.cancel()
  suppressedMap = destination
end

-- startWarpTo arms before the engine's fade and before the destination Map
-- object exists. Bind that object at setMap without restarting the clock.
function Gate.bind(destination)
  if not destination then return end
  if active and tostring(targetId) == tostring(destination.id) then
    map = destination
  end
end

function Gate.cancel(destination)
  if destination ~= nil and destination ~= map then return end
  active, map, targetId, ready, elapsed = false, nil, nil, false, 0
  automatic = false
end

function Gate.observe(destination, isReady)
  if isReady and suppressedMap == destination then suppressedMap = nil end
  if not active or destination ~= map then return end
  -- Cold crossings have no minimum hold: reveal the first complete frame.
  if isReady and automatic then Gate.cancel(); return end
  if isReady then
    ready = true
  else
    ready = false
  end
end

function Gate.update(dt, enabled, destination)
  if destination and observedMap ~= destination then
    observedMap = destination
    if suppressedMap ~= destination then suppressedMap = nil end
  end
  if not enabled then suppressedMap = nil end
  if not active then return end
  if not enabled then
    Gate.cancel()
    return
  end
  elapsed = elapsed + math.max(0, dt or 0)
  local mark = buildProgress()
  if mark ~= progressMark then progressMark, progressAt = mark, elapsed end
  local stalled = elapsed - progressAt >= Gate.STALL_SECONDS
  if (elapsed >= Gate.MAX_SECONDS and (stalled or mark == nil))
      or elapsed >= Gate.HARD_SECONDS then
    local timedOut = map or destination
    warn(elapsed >= Gate.HARD_SECONDS and "60-second safety timeout"
         or "build stalled", timedOut)
    Gate.cancel()
    suppressedMap = timedOut
    return
  end
  if ready and elapsed >= Gate.HOLD_SECONDS then
    Gate.cancel()
  end
end

-- Read-only presentation details; the card cannot arm or extend the gate.
function Gate.status()
  return { targetId = targetId, ready = ready, elapsed = elapsed, active = active }
end

function Gate.blocking(destination)
  -- Once a qualifying transition begins, cover whichever world the engine is
  -- currently drawing: initially the departing map, then the bound destination.
  return active
end

function Gate.install()
  local OverworldState = require("src.world.OverworldController")
  if OverworldState.dramaticShapeVoxelTransitionGate then return end

  local startWarpTo = OverworldState.startWarpTo
  function OverworldState:startWarpTo(mapId, x, y, facing, onDone, opts)
    -- startWarpTo consumes and clears arriveWarp, so inspect it before the
    -- engine call. Dig, Teleport and Escape Rope all arrive as "teleport".
    local arrival = self.arriveWarp
    if voxelEnabled() and Gate.qualifies(opts, arrival) then
      Gate.arm(mapId)
    end
    return startWarpTo(self, mapId, x, y, facing, onDone, opts)
  end

  local setMap = OverworldState.setMap
  function OverworldState:setMap(mapId, x, y, facing, opts)
    local boot = voxelEnabled() and Gate.qualifies(opts, nil)
    if boot then Gate.arm(mapId) end
    local result = setMap(self, mapId, x, y, facing, opts)
    -- A travel move was armed by startWarpTo; boot was armed just above.
    -- bind() deliberately ignores every unrelated ordinary destination.
    if voxelEnabled() then Gate.bind(self.map) end
    return result
  end

  OverworldState.dramaticShapeVoxelTransitionGate = true
end

-- Test-only state reset; harmless to expose and useful to keep the module's
-- temporal contract deterministic in the headless SDK suite.
function Gate._reset()
  Gate.cancel()
  suppressedMap, observedMap = nil, nil
end

return Gate
