-- Focused regression for issue #30: NATURE fill routing.
local checks = 0
local function check(value, message)
  checks = checks + 1
  if not value then error("FAIL: " .. message, 0) end
end

local selected = "cyan"
local ModSetting = {
  new = function()
    return {
      get = function() return selected end,
      sync = function(_, value) selected = value end,
    }
  end,
}
local namespace = { data = function()
  return { black = {
    VIRIDIAN_FOREST = true,
    SEAFOAM_ISLANDS_B4F = true,
    MT_MOON_B2F = true,
  } }
end }
function namespace.require(name)
  return assert(({
    Voxel3D = { newMesh = function() end },
    Mat4 = {}, ModSetting = ModSetting, TerrainAtlas = { safariGroundColor = function() return nil end },
  })[name], "unexpected WorldUnderlay dependency " .. tostring(name))
end
package.loaded["src.world.Map"] = {
  isOutdoor = function(def) return def.outdoor ~= false end,
}
package.loaded["src.render.TileRenderer"] = {
  borderBlockFor = function() return false end,
}

local WorldUnderlay = assert(loadfile("lib/WorldUnderlay.lua"))(namespace)
local function resolve(id)
  return WorldUnderlay.resolve({ map = { id = id, def = { outdoor = true } } })
end

WorldUnderlay.setting:sync("nature")
local color, reason = resolve("VIRIDIAN_FOREST")
check(color == WorldUnderlay.COLORS.black and reason == "nature:black",
  "Viridian Forest uses the black NATURE underlay")
color, reason = resolve("SEAFOAM_ISLANDS_B4F")
check(color == WorldUnderlay.COLORS.black and reason == "nature:black",
  "Seafoam interiors use the black NATURE underlay")
color, reason = resolve("MT_MOON_B2F")
check(color == WorldUnderlay.COLORS.black and reason == "nature:black",
  "cave interiors keep the familiar dark NATURE underlay")
color, reason = resolve("CINNABAR_ISLAND")
check(color == WorldUnderlay.COLORS.cyan and reason == "world:cyan",
  "Cinnabar Island keeps the cyan NATURE underlay")
color, reason = resolve("PALLET_TOWN")
check(color == WorldUnderlay.COLORS.cyan and reason == "world:cyan",
  "ordinary nature maps keep the cyan fallback")

print(("%d checks passed (NATURE underlay routing)"):format(checks))
