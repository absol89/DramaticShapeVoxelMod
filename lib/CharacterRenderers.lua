-- Sandbox-safe character renderer bridge.
--
-- Gen1Recomp 0.2.53 gives every mod a private _G and no debug upvalue API.
-- Character mods therefore register callbacks through this exported surface
-- instead of reaching into VoxelScene or exchanging process globals.

local V = ...

local CharacterRenderers = {
  API_VERSION = 1,
  entries = {},
  byId = {},
  serial = 0,
  generation = 0,
  battle = { active = false, state = nil, handWorld = nil },
}

local CALLBACKS = {
  drawEntity = true,
  drawShadow = true,
  suppressGhost = true,
  afterActors = true,
  drawBattleTrainer = true,
}

local function logError(entry, method, err)
  entry.failed = entry.failed or {}
  if entry.failed[method] then return end
  entry.failed[method] = true
  local log = V.mod and V.mod.log
  if log and log.error then
    log:error("character renderer %s %s failed: %s", entry.id, method,
              tostring(err))
  end
end

local function sortEntries()
  table.sort(CharacterRenderers.entries, function(a, b)
    if a.priority ~= b.priority then return a.priority > b.priority end
    return a.serial < b.serial
  end)
end

local function remove(entry)
  if not entry or entry.removed then return false end
  entry.removed = true
  CharacterRenderers.byId[entry.id] = nil
  for i, candidate in ipairs(CharacterRenderers.entries) do
    if candidate == entry then
      table.remove(CharacterRenderers.entries, i)
      break
    end
  end
  CharacterRenderers.generation = CharacterRenderers.generation + 1
  local ok, ShadowMap = pcall(V.require, "ShadowMap")
  if ok and ShadowMap and ShadowMap.invalidate then pcall(ShadowMap.invalidate) end
  return true
end

function CharacterRenderers.register(spec)
  if type(spec) ~= "table" then return nil, "renderer spec must be a table" end
  if spec.apiVersion ~= nil
      and tonumber(spec.apiVersion) ~= CharacterRenderers.API_VERSION then
    return nil, "unsupported character renderer API version"
  end
  local id = tostring(spec.id or "")
  if id == "" or #id > 128 then return nil, "renderer id is required" end
  if CharacterRenderers.byId[id] then
    return nil, ("character renderer %s is already registered"):format(id)
  end
  local hasCallback = false
  for name in pairs(CALLBACKS) do
    if type(spec[name]) == "function" then hasCallback = true end
  end
  if not hasCallback then return nil, "renderer has no supported callbacks" end

  CharacterRenderers.serial = CharacterRenderers.serial + 1
  local entry = {
    id = id,
    name = tostring(spec.name or id),
    priority = tonumber(spec.priority) or 0,
    serial = CharacterRenderers.serial,
    spec = spec,
    failed = {},
  }
  CharacterRenderers.byId[id] = entry
  CharacterRenderers.entries[#CharacterRenderers.entries + 1] = entry
  sortEntries()
  CharacterRenderers.generation = CharacterRenderers.generation + 1

  local handle = {}
  function handle:release() return remove(entry) end
  function handle:status()
    return { id = entry.id, active = not entry.removed, failed = entry.failed }
  end
  return handle
end

-- Consumers normally register during their own entry chunk. A launcher-side
-- reload can nevertheless publish the consumer only after Battle Art's first
-- registration attempt. Recover from that harmless ordering window by also
-- discovering the renderer specs the two companion mods export. This lookup
-- is data/API-only: Battle Art never reads either mod's files.
local DISCOVERY_IDS = {
  "gen1_true_3d_characters",
  "red_3d_player",
}

local discovering = false
local function discoverExports()
  if discovering or not (V.mod and type(V.mod.find) == "function") then return end
  discovering = true
  for _, modId in ipairs(DISCOVERY_IDS) do
    local okFind, other = pcall(V.mod.find, modId)
    local exports = okFind and other and other.exports or nil
    local spec = exports and exports.characterRenderer or nil
    local id = type(spec) == "table" and tostring(spec.id or "") or ""
    if id ~= "" and not CharacterRenderers.byId[id] then
      local handle, err = CharacterRenderers.register(spec)
      if handle then
        local log = V.mod.log
        if log and log.info then
          log:info("discovered character renderer %s from %s", id, modId)
        end
      elseif err then
        local log = V.mod.log
        if log and log.warn then
          log:warn("character renderer discovery from %s failed: %s",
                   modId, tostring(err))
        end
      end
    end
  end
  discovering = false
end

function CharacterRenderers.has(method)
  discoverExports()
  if not CALLBACKS[method] then return false end
  for _, entry in ipairs(CharacterRenderers.entries) do
    if not entry.removed and type(entry.spec[method]) == "function" then
      return true
    end
  end
  return false
end

-- First callback returning exactly true owns this object/pass.
function CharacterRenderers.first(method, context)
  discoverExports()
  if not CALLBACKS[method] then return false end
  for _, entry in ipairs(CharacterRenderers.entries) do
    local fn = not entry.removed and entry.spec[method] or nil
    if type(fn) == "function" then
      local ok, claimed = pcall(fn, context)
      if not ok then logError(entry, method, claimed)
      elseif claimed == true then return true end
    end
  end
  return false
end

function CharacterRenderers.all(method, context)
  discoverExports()
  if not CALLBACKS[method] then return end
  for _, entry in ipairs(CharacterRenderers.entries) do
    local fn = not entry.removed and entry.spec[method] or nil
    if type(fn) == "function" then
      local ok, err = pcall(fn, context)
      if not ok then logError(entry, method, err) end
    end
  end
end

function CharacterRenderers.revision()
  discoverExports()
  return CharacterRenderers.generation
end

function CharacterRenderers.setBattle(active, state)
  CharacterRenderers.battle.active = active and true or false
  CharacterRenderers.battle.state = active and state or nil
  if not active then CharacterRenderers.battle.handWorld = nil end
end

function CharacterRenderers.battleActive()
  return CharacterRenderers.battle.active
end

function CharacterRenderers.battleState()
  return CharacterRenderers.battle.state
end

function CharacterRenderers.setBattleHand(value)
  if type(value) == "table" then
    CharacterRenderers.battle.handWorld = {
      tonumber(value[1]) or 0,
      tonumber(value[2]) or 0,
      tonumber(value[3]) or 0,
    }
  else
    CharacterRenderers.battle.handWorld = nil
  end
end

function CharacterRenderers.battleHandWorld()
  return CharacterRenderers.battle.handWorld
end

function CharacterRenderers.export()
  return {
    apiVersion = CharacterRenderers.API_VERSION,
    source = "BATTLE_ART_VOXEL_FORK",
    register = function(spec) return CharacterRenderers.register(spec) end,
    refresh = function() discoverExports(); return CharacterRenderers.generation end,
  }
end

return CharacterRenderers
