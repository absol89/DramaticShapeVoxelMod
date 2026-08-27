-- Regression for delayed overworld readiness through the public core hook.

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

local Lifecycle = assert(loadfile("lib/CompanionLifecycle.lua"))()

local wrappedName, wrapped
local messages = {}
local mod = {
  hooks = {
    wrap = function(_, name, callback)
      wrappedName, wrapped = name, callback
      return function() return true end
    end,
  },
  log = {
    error = function(_, format, value)
      messages[#messages + 1] = tostring(format):format(value)
    end,
  },
}

local calls = {}
local companion = {
  updateFromGame = function(_, dt, game)
    calls[#calls + 1] = { dt = dt, game = game, ready = game.overworld ~= nil }
  end,
  dispose = function(_, reason)
    calls.disposed = (calls.disposed or 0) + 1
    calls.disposeReason = reason
    return true
  end,
}

local uninstall = Lifecycle.install(mod, companion)
check(type(uninstall) == "function",
  "install returns the public hook removal handle")
equal(wrappedName, "core.update", "lifecycle binds only to public core.update")

local game = {}
local order = {}
local first, second = wrapped(function(actualGame, dt)
  order[#order + 1] = "engine"
  equal(actualGame, game, "the engine receives the public game object")
  equal(dt, 0.016, "the engine receives the original delta")
  return "engine-result", nil
end, game, 0.016)
order[#order + 1] = "returned"

equal(first, "engine-result", "the hook preserves the engine return value")
equal(second, nil, "the hook preserves trailing nil return values")
equal(calls[1].game, game, "the adapter receives the same public game object")
equal(calls[1].ready, false, "startup can run before an overworld exists")
equal(order[1], "engine", "the engine update runs before companion observation")

game.overworld = { map = { id = "PALLET_TOWN" } }
wrapped(function() order[#order + 1] = "engine-ready" end, game, 0.016)
equal(calls[2].ready, true,
  "a later core update exposes the ready overworld to the adapter")

companion.updateFromGame = function() error("synthetic lifecycle fault", 0) end
wrapped(function() end, game, 0.016)
wrapped(function() end, game, 0.016)
equal(#messages, 1, "a repeated lifecycle fault is logged once")

check(uninstall(), "uninstall removes the public hook")
equal(calls.disposed, 1, "uninstall disposes the companion exactly once")
equal(calls.disposeReason, "host_uninstall",
  "uninstall uses the canonical cleanup reason")
check(uninstall(), "repeated uninstall is safe")
equal(calls.disposed, 1, "repeated uninstall does not dispose twice")

local removeAttempts, disposeAttempts = 0, 0
local retryMod = {
  hooks = {
    wrap = function()
      return function()
        removeAttempts = removeAttempts + 1
        return true
      end
    end,
  },
  log = { error = function() end },
}
local failDispose = true
local retryCompanion = {
  updateFromGame = function() end,
  dispose = function()
    disposeAttempts = disposeAttempts + 1
    if failDispose then return nil, "synthetic cleanup refusal" end
    return true
  end,
}
local retryUninstall = Lifecycle.install(retryMod, retryCompanion)
local firstCleanup = pcall(retryUninstall)
equal(firstCleanup, false, "failed uninstall cleanup is reported")
equal(removeAttempts, 1, "failed cleanup removes the hook once")
equal(disposeAttempts, 1, "failed cleanup attempts disposal once")
failDispose = false
check(retryUninstall(), "uninstall cleanup can resume after a failure")
equal(removeAttempts, 1, "cleanup retry does not remove the hook twice")
equal(disposeAttempts, 2, "cleanup retry runs disposal again")

io.write(('%d checks passed (Voxel Companion core lifecycle)\n'):format(checks))
