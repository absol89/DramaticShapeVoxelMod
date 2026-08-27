-- Public engine lifecycle binding for the Voxel Companion host.

local CompanionLifecycle = {}

local unpack = table.unpack or unpack

local function pack(...)
  return { n = select("#", ...), ... }
end

function CompanionLifecycle.install(mod, companion)
  assert(type(mod) == "table" and type(mod.hooks) == "table"
      and type(mod.hooks.wrap) == "function",
    "CompanionLifecycle needs the public mod hook facade")
  assert(type(companion) == "table"
      and type(companion.updateFromGame) == "function"
      and type(companion.dispose) == "function",
    "CompanionLifecycle needs a companion adapter")

  local reportedFault = false
  local remove = mod.hooks:wrap("core.update", function(next, game, dt)
    local results = pack(next(game, dt))
    local ok, err = pcall(companion.updateFromGame, companion, dt, game)
    if not ok and not reportedFault then
      reportedFault = true
      if mod.log and type(mod.log.error) == "function" then
        mod.log:error("Voxel Companion update failed: %s", tostring(err))
      end
    end
    return unpack(results, 1, results.n)
  end)
  local hookRemoved, uninstalled = false, false
  local removed
  return function(...)
    if uninstalled then return true end
    if not hookRemoved then
      removed = pack(remove(...))
      hookRemoved = true
    end
    local called, result, disposeError = pcall(
      companion.dispose, companion, "host_uninstall")
    if not called or not result then
      local err = called and disposeError or result
      if mod.log and type(mod.log.error) == "function" then
        mod.log:error("Voxel Companion uninstall cleanup failed: %s", tostring(err))
      end
      error(err, 0)
    end
    uninstalled = true
    return unpack(removed, 1, removed.n)
  end
end

return CompanionLifecycle
