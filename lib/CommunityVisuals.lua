-- Optional Legendary Visuals community systems for Battle Art Voxel.
--
-- Every ladder starts at BATTLE ART DEFAULT.  The renderer therefore keeps
-- the creator's original geometry unless a player explicitly opts in.

local V = ...
local ModSetting = V.require("ModSetting")

local CommunityVisuals = {}

CommunityVisuals.pillars = ModSetting.new(
  "communityPillars", "LEGENDARY PILLARS",
  { "default", "separate", "bottom", "top" },
  { "BATTLE ART", "SEPARATE", "BOTTOM LINK", "TOP INTERLOCK" }
)

CommunityVisuals.masonry = ModSetting.new(
  "communityMasonry", "WALL & LEDGE COLOR",
  { "granite", "red", "sandstone", "slate" },
  { "GRANITE", "RED BRICK", "SANDSTONE", "SLATE" }
)

CommunityVisuals.trees = ModSetting.new(
  "communityTrees", "TREES",
  { "default", "n64memory" }, { "BATTLE ART", "LEGENDARY VISUALS" }
)

CommunityVisuals.grass = ModSetting.new(
  "communityGrass", "GRASS",
  { "default", "n64memory" }, { "BATTLE ART", "LEGENDARY VISUALS" }
)

CommunityVisuals.roads = ModSetting.new(
  "communityRoads", "ROADS & BRIDGES",
  { "default", "n64memory" }, { "BATTLE ART", "LEGENDARY VISUALS" }
)

CommunityVisuals.walls = ModSetting.new(
  "communityWalls", "WALLS & LEDGES",
  { "default", "n64memory" }, { "BATTLE ART", "LEGENDARY VISUALS" }
)

CommunityVisuals.courtyards = ModSetting.new(
  "communityCourtyards", "FENCES & COURTS",
  { "default", "n64memory" }, { "BATTLE ART", "LEGENDARY VISUALS" }
)

CommunityVisuals.settings = {
  CommunityVisuals.pillars,
  CommunityVisuals.masonry,
  CommunityVisuals.trees,
  CommunityVisuals.grass,
  CommunityVisuals.roads,
  CommunityVisuals.walls,
  CommunityVisuals.courtyards,
}

local KEYS = {}
for _, setting in ipairs(CommunityVisuals.settings) do
  KEYS[setting.key] = true
end

function CommunityVisuals.layout()
  return CommunityVisuals.pillars:get()
end

function CommunityVisuals.customPillars()
  return CommunityVisuals.layout() ~= "default"
end

function CommunityVisuals.wallColor()
  return CommunityVisuals.masonry:get()
end

-- TEST366's community pillars are a locked granite design. Masonry color
-- belongs only to the TEST435 retaining walls and authored ledges.
function CommunityVisuals.pillarColor()
  return "granite"
end

-- Compatibility alias for older TEST2 call sites while TEST3 migrates them.
function CommunityVisuals.color()
  return CommunityVisuals.wallColor()
end

function CommunityVisuals.customTrees()
  return CommunityVisuals.trees:get() == "n64memory"
end


function CommunityVisuals.customGrass()
  return CommunityVisuals.grass:get() == "n64memory"
end


function CommunityVisuals.customRoads()
  return CommunityVisuals.roads:get() == "n64memory"
end


function CommunityVisuals.customWalls()
  return CommunityVisuals.walls:get() == "n64memory"
end


function CommunityVisuals.customCourtyards()
  return CommunityVisuals.courtyards:get() == "n64memory"
end

-- Layout changes affect both the stock round-object stamp and the replacement
-- mesh.  Drop only derived runtime geometry; map data, collision and disk
-- cache files remain untouched and rebuild through Battle Art's normal queue.
function CommunityVisuals.invalidate()
  _G.__bav_granite_pillars = nil
  _G.__bav_granite_pillar_base = nil
  _G.__ds_round_cells = nil
  _G.__ds_round_base = nil
  pcall(function() V.require("GranitePillars").invalidate() end)
  pcall(function() V.require("CommunityFlora").invalidate() end)
  pcall(function() V.require("TerrainAtlas").invalidate() end)
  pcall(function() V.require("ChunkMesher").invalidate() end)
end

-- The ordinary OPTIONS screen writes through ModSetting.  Wrap only these two
-- rows so the visible world follows the new value without a restart.
local function live(setting)
  local baseRow = setting.row
  setting.row = function(self)
    local row = baseRow(self)
    local baseStep = row.step
    row.step = function(game, dir)
      local result = baseStep(game, dir)
      CommunityVisuals.invalidate()
      return result
    end
    return row
  end
end

for _, setting in ipairs(CommunityVisuals.settings) do live(setting) end

function CommunityVisuals.changed(key)
  if KEYS[key] then CommunityVisuals.invalidate() end
end

return CommunityVisuals
