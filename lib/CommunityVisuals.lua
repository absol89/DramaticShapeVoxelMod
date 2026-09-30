-- Optional Legendary Visuals community systems for Battle Art Voxel.
--
-- Every ladder starts at BATTLE ART DEFAULT.  The renderer therefore keeps
-- the creator's original geometry unless a player explicitly opts in.

local V = ...
local ModSetting = V.require("ModSetting")

local CommunityVisuals = {}

local CITY_GROUND_MAPS = {
  LAVENDER_TOWN = true,
  FUCHSIA_CITY = true,
}

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

-- The cave overhaul is intentionally opt-in, like the rest of the community
-- visual families.  Existing installs therefore retain Battle Art's authored
-- cave tiles until the player explicitly selects Legendary Visuals.
CommunityVisuals.caves = ModSetting.new(
  "communityCaves", "CAVES",
  { "default", "n64memory" }, { "BATTLE ART", "LEGENDARY VISUALS" }
)

-- New installs retain Battle Art; explicitly saved Legendary choices resume.
CommunityVisuals.tower = ModSetting.new(
  "communityTower", "TOWER VISUALS",
  { "default", "n64memory" }, { "BATTLE ART", "LEGENDARY VISUALS" }
)

-- Three full-resolution wall slabs share the same geometry and UV field.
-- The original dark material remains first so existing saves keep their look;
-- the two reference-matched white granites are opt-in finishes.
CommunityVisuals.towerWall = ModSetting.new(
  "communityTowerWall", "TOWER WALL",
  { "smoke_black", "storm_white", "pearl_white" },
  { "SMOKE BLACK", "STORM WHITE", "PEARL WHITE" }
)

-- Kanto First Person's cave atmosphere is exposed separately from its
-- ceiling/wall builder. This keeps TEST66's approved natural rock walls
-- authoritative while letting players opt into lightweight cave dressing.
CommunityVisuals.caveDetails = ModSetting.new(
  "communityCaveDetails", "CAVE DETAILS",
  { "off", "subtle", "full" }, { "OFF", "SUBTLE", "FULL" }
)

CommunityVisuals.caveSound = ModSetting.new(
  "communityCaveSound", "CAVE SOUND",
  { "off", "low", "mid" }, { "OFF", "LOW", "MID" }
)

CommunityVisuals.trees = ModSetting.new(
  "communityTrees", "TREES",
  { "default", "n64memory", "n64memory_fast" },
  { "BATTLE ART", "LEGENDARY FULL", "LEGENDARY FAST" }
)

-- Preserve old FULL/FAST saves when no independent detail choice is stored.
CommunityVisuals.treeDetail = ModSetting.new(
  "communityTreeDetail", "TREE DETAIL",
  { "full", "balanced", "handheld" },
  { "FULL", "BALANCED", "HANDHELD" }
)

if CommunityVisuals.treeDetail.read then
  local readDetail = CommunityVisuals.treeDetail.read
  function CommunityVisuals.treeDetail:read()
    if not self.index then
      -- Read the stored tree choice, not a temporary LEGENDARY VISUALS preset
      -- overlay. CUSTOM must restore the player's own remembered combination.
      local rawTree = CommunityVisuals.trees.values[CommunityVisuals.trees:read()]
      self.defaultIndex = rawTree == "n64memory" and 1 or 2
    end
    return readDetail(self)
  end
end

CommunityVisuals.cutTrees = ModSetting.new(
  "communityCutTrees", "CUT TREES",
  { "default", "n64memory" }, { "BATTLE ART", "LEGENDARY VISUALS" }
)

CommunityVisuals.signs = ModSetting.new(
  "communitySigns", "SIGNS",
  { "default", "n64memory" }, { "BATTLE ART", "LEGENDARY VISUALS" }
)

CommunityVisuals.grass = ModSetting.new(
  "communityGrass", "GRASS",
  { "default", "n64memory" }, { "BATTLE ART", "LEGENDARY VISUALS" }
)

-- City turf is intentionally separate from route/encounter grass. Lavender
-- and Fuchsia have strong authored palette/ground identities, so opting into
-- Legendary grass elsewhere must not silently replace their tileset ground.
CommunityVisuals.cityGround = ModSetting.new(
  "communityCityGround", "CITY GROUND",
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

CommunityVisuals.sky = ModSetting.new(
  "communitySky", "SKY & BACKGROUND",
  { "default", "n64memory" }, { "BATTLE ART", "LEGENDARY VISUALS" }
)

CommunityVisuals.forest = ModSetting.new(
  "communityForest", "VIRIDIAN FOREST",
  { "default", "n64memory" }, { "BATTLE ART", "LEGENDARY VISUALS" }
)

-- Independent Safari presentation; existing artistic choices are never rewritten.
CommunityVisuals.safari = ModSetting.new(
  "communitySafari", "SAFARI ZONE",
  { "default", "n64memory" }, { "BATTLE ART", "LEGENDARY VISUALS" }, 2
)
function CommunityVisuals.customSafari()
  return CommunityVisuals.safari:get() == "n64memory"
end

-- Regional nature is independently adjustable; existing choices are preserved.
CommunityVisuals.kantoLife = ModSetting.new(
  "communityKantoLife", "KANTO AMBIENCE",
  { "off", "low", "natural" }, { "OFF", "LOW", "NATURAL" }, 3
)

-- Keep Battle Art on first use; saved Legendary choices remain authoritative.
CommunityVisuals.casino = ModSetting.new("communityCasino", "CASINO",
  { "default", "n64memory" }, { "BATTLE ART", "LEGENDARY VISUALS" }, 1)
CommunityVisuals.prizeRoom = ModSetting.new("communityPrizeRoom", "PRIZE ROOM",
  { "default", "n64memory" }, { "BATTLE ART", "LEGENDARY VISUALS" }, 1)
CommunityVisuals.tunnels = ModSetting.new("communityTunnels", "TUNNELS",
  { "default", "n64memory" }, { "BATTLE ART", "LEGENDARY VISUALS" }, 1)
CommunityVisuals.rocket = ModSetting.new("communityRocket", "ROCKET HIDEOUT",
  { "default", "n64memory" }, { "BATTLE ART", "LEGENDARY VISUALS" }, 1)
CommunityVisuals.elevator = ModSetting.new("communityElevator", "ROCKET ELEVATOR",
  { "default", "n64memory" }, { "BATTLE ART", "LEGENDARY VISUALS" }, 1)

-- Independent of the Legendary preset. This release enables Legendary by
-- default; Installed restores the exact upstream building meshes.
CommunityVisuals.buildings = ModSetting.new(
  "vermilionBuildings", "BUILDING STYLE",
  { "installed", "reference" }, { "INSTALLED", "LEGENDARY" }, 2
)
function CommunityVisuals.referenceBuildings()
  return CommunityVisuals.buildings:get() == "reference"
end

CommunityVisuals.settings = {
  CommunityVisuals.buildings,
  CommunityVisuals.casino,
  CommunityVisuals.prizeRoom,
  CommunityVisuals.tunnels,
  CommunityVisuals.rocket,
  CommunityVisuals.elevator,

  CommunityVisuals.pillars,
  CommunityVisuals.masonry,
  CommunityVisuals.tower,
  CommunityVisuals.towerWall,
  CommunityVisuals.caves,
  CommunityVisuals.caveDetails,
  CommunityVisuals.caveSound,
  CommunityVisuals.trees,
  CommunityVisuals.treeDetail,
  CommunityVisuals.cutTrees,
  CommunityVisuals.signs,
  CommunityVisuals.cityGround,
  CommunityVisuals.grass,
  CommunityVisuals.roads,
  CommunityVisuals.walls,
  CommunityVisuals.courtyards,
  CommunityVisuals.sky,
  CommunityVisuals.forest,
  CommunityVisuals.safari,
  CommunityVisuals.kantoLife,
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

function CommunityVisuals.customCaves()
  return CommunityVisuals.caves:get() == "n64memory"
end

function CommunityVisuals.customTower()
  return CommunityVisuals.tower:get() == "n64memory"
end

function CommunityVisuals.towerWallStyle()
  local style = CommunityVisuals.towerWall:get()
  if style == "storm_white" or style == "pearl_white" then return style end
  return "smoke_black"
end

function CommunityVisuals.caveDetailLevel()
  return CommunityVisuals.caveDetails:get()
end

function CommunityVisuals.caveSoundLevel()
  return CommunityVisuals.caveSound:get()
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
  return CommunityVisuals.trees:get() ~= "default"
end

-- Preserve the existing saved Legendary selection as the approved full mode.
-- Players can still select the untouched maximum-detail tree recipe for an
-- immediate visual/performance comparison.
function CommunityVisuals.treeDetailLevel()
  return CommunityVisuals.treeDetail:get()
end
function CommunityVisuals.fullTreeDetail()
  return CommunityVisuals.treeDetailLevel() == "full"
end

function CommunityVisuals.customCutTrees()
  return CommunityVisuals.cutTrees:get() == "n64memory"
end

function CommunityVisuals.customSigns()
  return CommunityVisuals.signs:get() == "n64memory"
end


function CommunityVisuals.customGrass()
  return CommunityVisuals.grass:get() == "n64memory"
end

function CommunityVisuals.customCityGround()
  return CommunityVisuals.cityGround:get() == "n64memory"
end

function CommunityVisuals.isCityGroundMap(map)
  return map and map.tileset and map.tileset.id == "OVERWORLD"
    and CITY_GROUND_MAPS[tostring(map.id or ""):upper()] == true
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

function CommunityVisuals.customSky()
  return CommunityVisuals.sky:get() == "n64memory"
end

function CommunityVisuals.customForest()
  return CommunityVisuals.forest:get() == "n64memory"
end

-- Layout changes affect both the stock round-object stamp and the replacement
-- mesh.  Drop only derived runtime geometry; map data, collision and disk
-- cache files remain untouched and rebuild through Battle Art's normal queue.
function CommunityVisuals.invalidate()
  pcall(function() V.require("KantoLife").invalidate() end)
  pcall(function() V.require("SafariStatues").invalidate() end)
  pcall(function() V.require("SafariMaterials").invalidate() end)
  pcall(function() V.require("GameCorner").invalidate() end)
  _G.__bav_granite_pillars = nil
  _G.__bav_granite_pillar_base = nil
  _G.__ds_round_cells = nil
  _G.__ds_round_base = nil
  _G.__ds_sapling_cells = nil
  pcall(function() V.require("GranitePillars").invalidate() end)
  pcall(function() V.require("CommunityFlora").invalidate() end)
  pcall(function() V.require("ForestDressing").invalidate() end)
  pcall(function() V.require("SafariFoliage").invalidate() end)
  pcall(function() V.require("CaveSconces").invalidate() end)
  pcall(function() V.require("CaveAtmosphere3D").invalidate() end)
  pcall(function() V.require("TowerGraveMist").invalidate() end)
  pcall(function() V.require("TowerLobbyDetails").invalidate() end)
  pcall(function() V.require("LegendaryTowerExterior").invalidate() end)
  pcall(function() V.require("Backdrop").invalidate() end)
  pcall(function() V.require("SkyLayer").invalidate() end)
  pcall(function() V.require("ForestAtmos").invalidate() end)
  pcall(function() V.require("TileShape").invalidate() end)
  pcall(function() V.require("TerrainAtlas").invalidate() end)
  pcall(function() V.require("ChunkMesher").invalidate() end)
end

-- The ordinary OPTIONS screen writes through ModSetting. Wrap each community
-- row so the visible world follows the new value without a restart.
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
