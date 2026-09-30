-- One authoritative profile row for every option owned by LEGENDARY VISUALS.
--
-- CUSTOM is deliberately an overlay-free mode: the individual ModSettings keep
-- their persisted values at all times. OFF/AUTO/FULL only override what get()
-- returns, so switching back to CUSTOM restores the exact combination the
-- player had before selecting a preset.
local V = ...
local ModSetting = V.require("ModSetting")
local CommunityVisuals = V.require("CommunityVisuals")
local TowerFogSettings = V.require("TowerFogSettings")
local ForestAtmos = V.require("ForestAtmos")

local P = {}
P.setting = ModSetting.new("legendaryVisualsMode", "LEGENDARY VISUALS",
  { "off", "custom", "auto", "full" },
  { "OFF", "CUSTOM", "AUTO", "FULL" }, 1)

local profiles, members, memberKeys, rawGet = {}, {}, {}, {}
local communityMembers = {}
for _, setting in ipairs(CommunityVisuals.settings or {}) do
  communityMembers[setting] = true
end

local function hasValue(setting, wanted)
  for _, value in ipairs(setting.values or {}) do
    if value == wanted then return true end
  end
  return false
end

local function add(setting, off, auto, full)
  assert(setting and setting.key, "Legendary preset member must be a ModSetting")
  assert(hasValue(setting, off), "invalid OFF value for " .. setting.key)
  assert(hasValue(setting, auto), "invalid AUTO value for " .. setting.key)
  assert(hasValue(setting, full), "invalid FULL value for " .. setting.key)
  members[#members + 1] = setting
  memberKeys[setting.key] = setting
  profiles[setting] = { off = off, auto = auto, full = full }
end

-- World/interior families. AUTO is the complete Legendary presentation with
-- lighter detail recipes; FULL changes only actual quality tiers. Style/audio
-- choices stay independent so presets never overwrite artistic preferences.
add(CommunityVisuals.casino,      "default", "n64memory",      "n64memory")
add(CommunityVisuals.prizeRoom,   "default", "n64memory",      "n64memory")
add(CommunityVisuals.tunnels,     "default", "n64memory",      "n64memory")
add(CommunityVisuals.rocket,      "default", "n64memory",      "n64memory")
add(CommunityVisuals.elevator,    "default", "n64memory",      "n64memory")
add(CommunityVisuals.pillars,     "default", "separate",       "separate")
add(CommunityVisuals.tower,       "default", "n64memory",      "n64memory")
add(CommunityVisuals.caves,       "default", "n64memory",      "n64memory")
add(CommunityVisuals.caveDetails, "off",     "subtle",         "full")
add(CommunityVisuals.trees,       "default", "n64memory",      "n64memory")
add(CommunityVisuals.treeDetail,  "balanced","balanced",       "full")
add(CommunityVisuals.cutTrees,    "default", "n64memory",      "n64memory")
add(CommunityVisuals.signs,       "default", "n64memory",      "n64memory")
add(CommunityVisuals.cityGround,  "default", "n64memory",      "n64memory")
add(CommunityVisuals.grass,       "default", "n64memory",      "n64memory")
add(CommunityVisuals.roads,       "default", "n64memory",      "n64memory")
add(CommunityVisuals.walls,       "default", "n64memory",      "n64memory")
add(CommunityVisuals.courtyards,  "default", "n64memory",      "n64memory")
add(CommunityVisuals.sky,         "default", "n64memory",      "n64memory")
add(CommunityVisuals.forest,      "default", "n64memory",      "n64memory")
add(CommunityVisuals.safari,      "default", "n64memory",      "n64memory")
add(CommunityVisuals.kantoLife,   "off", "natural", "natural")

-- Tower atmosphere. Both Legendary presets show the intended fog; AUTO keeps
-- the restrained detail pass while FULL restores the richer living-light tier.
add(TowerFogSettings.details,   "off", "subtle", "full")
add(TowerFogSettings.enabled,   "off", "on",     "on")
add(ForestAtmos.setting,        "off", "low",    "low")

local legacyNeedsCustom = false
do
  local mod = V.mod
  local function stored(key)
    if not (mod and mod.options and type(mod.options.get) == "function") then return nil end
    local ok, value = pcall(mod.options.get, mod.options, key)
    return ok and value or nil
  end
  if stored(P.setting.key) == nil then
    local legacy = {}
    for _, setting in ipairs(CommunityVisuals.settings or {}) do
      legacy[#legacy + 1] = setting
    end
    legacy[#legacy + 1] = TowerFogSettings.details
    legacy[#legacy + 1] = TowerFogSettings.enabled
    legacy[#legacy + 1] = TowerFogSettings.thickness
    legacy[#legacy + 1] = TowerFogSettings.speed
    legacy[#legacy + 1] = ForestAtmos.setting
    for _, setting in ipairs(legacy) do
      if setting and setting.key and stored(setting.key) ~= nil then
        legacyNeedsCustom = true
        break
      end
    end
  end
end

local baseModeRead = P.setting.read
function P.setting:read()
  if self.index then return self.index end
  if legacyNeedsCustom then self.index = 2; return self.index end
  return baseModeRead(self)
end

local function effective(setting, raw)
  local mode = P.setting:get()
  if mode == "custom" then return raw end
  local profile = profiles[setting]
  if profile and profile[mode] ~= nil then return profile[mode] end
  return raw
end

local function labelFor(setting, value)
  for i, candidate in ipairs(setting.values or {}) do
    if candidate == value then return setting.labels[i] end
  end
  return tostring(value)
end

function P.mode()
  return P.setting:get()
end

function P.profileValue(setting, mode)
  local profile = profiles[setting]
  return profile and profile[mode or P.mode()] or nil
end

function P.members()
  return members
end

function P.isMember(setting)
  return profiles[setting] ~= nil
end

function P.isMemberKey(key)
  return memberKeys[key] ~= nil
end

function P.invalidate()
  CommunityVisuals.invalidate()
end

function P.migrate(game, save)
  if not legacyNeedsCustom then return false end
  local opts = (save and save.options) or (game and game.save and game.save.options)
  if type(opts) ~= "table" then return false end
  local id = (V.mod and V.mod.id) or "BATTLE_ART_VOXEL_FORK"
  opts.modOptions = opts.modOptions or {}
  opts.modOptions[id] = opts.modOptions[id] or {}
  if opts.modOptions[id][P.setting.key] == nil then
    opts.modOptions[id][P.setting.key] = "custom"
  end
  local loader = game and game.mods
  if loader then
    loader.modOptions = loader.modOptions or {}
    loader.modOptions[id] = loader.modOptions[id] or {}
    loader.modOptions[id][P.setting.key] = opts.modOptions[id][P.setting.key]
  end
  P.setting:sync(opts.modOptions[id][P.setting.key])
  legacyNeedsCustom = false
  if game and game.writeOptions then pcall(game.writeOptions, game) end
  return true
end

-- Install lightweight effective-value overlays after every module has created
-- its settings. read()/setIndex() stay raw/persistent; only get() is profiled.
for _, setting in ipairs(members) do
  rawGet[setting] = setting.get
  setting.get = function(self)
    return effective(self, rawGet[self](self))
  end

  local baseRow = setting.row
  setting.row = function(self)
    local row = baseRow(self)
    row.value = function()
      return labelFor(self, self:get())
    end
    local baseStep = row.step
    row.step = function(game, dir)
      -- A manual child edit means the player is leaving the preset. CUSTOM
      -- reveals the preserved custom values first, then this one requested
      -- step is applied to that remembered combination.
      local switched = P.setting:get() ~= "custom"
      if switched then P.setting:setIndex(2, game) end
      local result = baseStep(game, dir)
      if switched and not communityMembers[self] then P.invalidate() end
      return result
    end
    return row
  end
end

-- The profile row itself changes only the effective overlay. No child setting
-- is overwritten, which is what makes CUSTOM durable across OFF/AUTO/FULL.
do
  local baseRow = P.setting.row
  P.setting.row = function(self)
    local row = baseRow(self)
    local baseStep = row.step
    row.step = function(game, dir)
      local result = baseStep(game, dir)
      P.invalidate()
      return result
    end
    return row
  end
end

function P.changed(key)
  if key == P.setting.key then
    legacyNeedsCustom = false
    P.invalidate()
    return true
  end
  if memberKeys[key] and P.mode() ~= "custom" then return true end
  return false
end

return P
