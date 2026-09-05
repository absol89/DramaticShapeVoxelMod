-- Voxel world mode: resolve every tile of a tileset to an extrusion shape.
--
-- Reads the hand-authored groups in data/voxel_heights.lua and fills the
-- gaps from data the ROM extractor already emits. Resolution happens at two
-- granularities, and the order matters:
--
--   per tile   1. a group named in data/voxel_heights.lua  (hand-authored)
--   per CELL   2. the cell is water                        -> "water"
--              3. the cell is walkable                     -> "ground"
--   per tile   4. tile-level fallback: the map's water set -> "water",
--                 its walkable set -> "ground", else       -> "wall"
--
-- The cell steps (TileShape.at) are the load-bearing part. Collision in
-- this engine -- like the GB original -- is defined per 16x16 CELL, judged
-- by the cell's bottom-left 8x8 tile alone. The other three tiles of a
-- cell carry no collision meaning, and treating their walkable-list
-- membership as one (which is what a pure per-tile lookup does) misfiles
-- every decorative tile: flowers become 16px pillars, the gap tiles of a
-- fence row become wall, grass tufts extrude. A tile in a walkable cell is
-- ground the player is standing on, whatever the walkable list says about
-- it; hand-authoring (rule 1) is the only thing that overrides that.
--
-- Rule 4 covers positions whose cell IS blocked: there, walkable-listed
-- tiles (the gaps between fence posts) stay ground and the rest rise.
--
-- Every class also carries an ART mode, which is what the mesher renders:
--
--   flat     ground/water/void: a single quad, no box.
--   top      ledge/roof: a box with its art on the TOP face -- things
--            whose 2D art depicts a surface seen from above.
--   upright  wall/tree/fence/sign: a box whose SOUTH face reconstructs
--            the 2D artwork standing up (the mesher's fold-up rule) --
--            things whose 2D art depicts a surface seen face-on, which is
--            most of Gen 1: interior walls, furniture, tree canopies,
--            building facades.
--
-- Purely presentational: a shape decides how a tile DRAWS in voxel mode
-- and nothing else. Collision still reads the same walkable list it
-- always did.

-- the mod namespace (see main.lua): V.data loads a shipped data file
local V = ...

local TileShape = {}

-- class -> height fallbacks, used when data/voxel_heights.lua is missing
-- or omits a class. Same numbers the shipped file carries; a cell is 16x16.
local FALLBACK_HEIGHTS = {
  ground = 0,
  water = -2,
  void = 0,
  ledge = 6,
  fence = 10,
  sign = 12,
  wall = 16,
  tree = 16,
  -- masonry drawn TWO courses tall: the Indigo Plateau's rim and the
  -- badge-check gates down Route 23 are drawn 32px, the same height as a
  -- statue on its plinth, and read as a step in the terrain rather than a
  -- room's wall.  Same fold as `wall`, twice the height -- and its own
  -- class because `wall` is 16px for every interior in the game.
  cliff = 32,
  roof = 28,
  cylinder = 16,
  -- big round scenery: a 2x2-CELL drawing carved as ONE 32px voxel hull
  -- (Viridian Forest's trees). The class pins only the drawing's
  -- top-left corner tile; the other cells stay `cylinder` and are
  -- claimed by the group build (see Structures.buildCylinders)
  canopy = 32,
  -- a cylinder hull whose drawn top is a CUT FACE (tree stumps): the
  -- body builds from the bark rows and the drawn ellipse projects onto
  -- the hull's round top
  stump = 16,
  -- the same hull cut at both ends, hollowed and tapered: an OPEN bin
  -- standing on a floor (the Vermilion Gym trash cans).  The drawn mouth
  -- ellipse projects onto the round top and down the well, the drawn base
  -- ellipse is ground contact rather than body, and the plan narrows toward
  -- the floor.  Height is AUTHORED (the profile's can_height, which this
  -- pin must be kept equal to so anything riding a can lands on its rim) --
  -- the drawing's own straight run is only a couple of rows, because a GB
  -- cell spends most of itself on the opening
  can = 9,
  -- A cuttable overworld tree becomes this round ownership class only while
  -- the Legendary cut-tree option is active. Battle Art's default keeps the
  -- original authored prop class and therefore remains byte-for-byte in look.
  sapling = 16,
  -- round scenery drawn ONE cell wide and TWO cells TALL, standing on one
  -- cell of plot: the Pokemon Centers' potted plants. Carved as one
  -- 16x32x16 hull in the SOUTH (pot) cell -- the drawing's upper cell is
  -- the object's height, not its depth. BOTH cells take the class; the
  -- group build anchors on the north one (Structures.buildCylinders)
  planter = 32,
  billboard = 16,
  signpost = 16,
  post = 16,
  grass = 0,
  flower = 0,
  -- interior furniture: face-on drawings the detector would otherwise
  -- raise to wall height (or merge into the wall).  A bed is drawn from
  -- above and lies low; tables and desks are boxes at their real height;
  -- stairs become stepped geometry rising toward the named side.
  bed = 7,
  stool = 8,
  counter = 8,
  -- the raised back band of low seating: the Center couch's west strip
  -- is drawn from above like the rest of the couch, but depicts the
  -- back and arm rising over the 8px seat
  backrest = 12,
  table = 12,
  desk = 24,
  prop = 16,
  cutout = 16,
  -- a vehicle drawn SIDE-ON: the showroom bicycles.  Standee height like
  -- every other cutout pool -- what differs is the thickness (see
  -- Structures' PINNED_DEPTH)
  bike = 16,
  console = 16,
  relief = 3,
  bookcase = 32,
  stair_e = 16,
  stair_w = 16,
  stair_down_e = 16,
  stair_down_w = 16,
  stair_n = 16,
  stair_down_n = 16,
  ladder_up = 16,
  ladder_down = 16,
  -- Legacy standee vocabulary retained for third-party/custom profiles.
  -- Authored cave warps now use ladder_up/down and the open shaft builder.
  ladder = 16,
}

-- class -> how the mesher draws it (see the header). The last three are
-- profile archetypes Structures.lua builds special geometry for:
--   cylinder   round-drawn cells (tree canopies) become voxel hulls cut
--              from the art's darkest-pixel outline, round in depth
--   billboard  signs, props: the art stands as a thin per-pixel voxel
--              slab, transparency respected
--   post       fence posts: the same thin per-pixel slab, but every CELL
--              stands alone in its own depth band -- a north-south fence
--              line is a march of separate posts, not one tall drawing
--              (which is what a shared cluster would make of it)
--   grass      tall grass: flat ground PLUS two thin standing rows of
--              tufts per tile (the art's top and bottom halves), each at
--              its drawn depth -- the player walks between them
local ART = {
  ground = "flat",
  water = "flat",
  void = "flat",
  ledge = "top",
  roof = "top",
  wall = "upright",
  cliff = "upright",
  tree = "upright",
  fence = "upright",
  sign = "upright",
  cylinder = "cylinder",
  canopy = "canopy",
  stump = "cylinder",
  can = "cylinder",
  sapling = "cylinder",
  planter = "planter",
  billboard = "billboard",
  -- signposts share the billboard treatment but as their own pool at a
  -- 2-voxel depth: a sign is a thin plate on a stick, and the standard
  -- 10px standee body reads as a chunk of furniture outdoors
  signpost = "billboard",
  post = "post",
  grass = "grass",
  -- animated flowers: flat synthesized ground PLUS a standing cutout of
  -- the drawing's darkest tones, one voxel deep (see Structures'
  -- buildFlowers). Height 0 so a build with no pixel access degrades to
  -- the flat tile it always drew, not a box
  flower = "flower",
  -- furniture: a bed's art depicts its top surface; tables and desks are
  -- boxes whose fronts fold up (the mesher's authored-fold rule).
  -- Stools, `prop` and `cutout` are standee pools alongside `billboard`
  -- -- same per-pixel cutout, different thickness (see Structures'
  -- PINNED_DEPTH), and separate pools cluster separately so touching
  -- drawings never stack; a stool keeps its 8px height so a character
  -- standing on its (walkable) cell sits at seat height.  Stairs are a
  -- profile archetype Structures builds real steps for -- rising flights
  -- for stairs leading up, sunken stairwells for stairs leading down
  bed = "top",
  -- a backrest's art is the couch seen from above, so like the bed it
  -- rides the top face of its taller box
  backrest = "top",
  stool = "billboard",
  -- half-cell furniture: a service counter, a low couch.  One 8px band,
  -- so exactly the drawing's bottom row stands up as the front and
  -- every row above it rides the top face in drawn order -- which is
  -- also the only way to place a figure drawn INTO the furniture (the
  -- Center's seated man) without repeating him, since a taller box
  -- folds two rows upright and then repeats its north row across the
  -- top.  Reads as something you lean on rather than a wall stub
  counter = "upright",
  table = "upright",
  desk = "upright",
  prop = "billboard",
  cutout = "billboard",
  -- a bicycle is a LINE drawing seen side-on, and its negative space --
  -- the air inside the frame, between the wheel and the fork -- is what
  -- makes it read as a bicycle at all.  Its own pool at two voxels: any
  -- thicker and the side faces of neighbouring strokes close those gaps
  -- from every angle but dead-on, and six of them in a showroom come out
  -- as one dark lump (which is what the 5px `prop` pool gave)
  bike = "billboard",
  -- a machine standing on furniture: the billboard treatment with
  -- body, plus the one-object contract `cutout` has -- the drawing is
  -- ringed by the furniture it sits on, and those edges must not be
  -- extruded along with it (see Structures' component filter)
  console = "billboard",
  relief = "relief",
  -- free-standing shelves: the drawing is TALL, not deep -- Structures
  -- collapses each drawn rank onto a one-cell-deep box at full height
  bookcase = "bookcase",
  stair_e = "stair",
  stair_w = "stair",
  stair_down_e = "stair",
  stair_down_w = "stair",
  stair_n = "stair",
  stair_down_n = "stair",
  ladder_up = "stair",
  ladder_down = "stair",
  ladder = "billboard",
}

local spec = nil          -- the loaded data file, or false when absent
local cache = {}          -- tileset id -> resolved shape list
local figCache = {}       -- tileset id -> parsed figure masks, or false
local mntCache = {}       -- tileset id -> parsed mounted masks, or false
local bgCache = {}        -- tileset id -> prop background shades, or false

local communityVisuals
local function customCutTrees()
  if communityVisuals == nil then
    local ok, value = pcall(V.require, "CommunityVisuals")
    communityVisuals = ok and value or false
  end
  return communityVisuals and communityVisuals.customCutTrees
         and communityVisuals.customCutTrees() or false
end

-- The shape profile ships with the mod (data/voxel_heights.lua) and is read
-- through the mod's own file loader rather than package.path: a mod's
-- directory is not on it, and may live inside a mounted .love archive that
-- plain require cannot reach either.  Absent or broken degrades to the
-- derived defaults, which is a rougher-looking world rather than no world.
local function load()
  if spec == nil then
    local ok, s = pcall(V.data, "voxel_heights")
    spec = (ok and type(s) == "table") and s or false
  end
  return spec or nil
end

function TileShape.heights()
  local s = load()
  local out = {}
  for class, h in pairs(FALLBACK_HEIGHTS) do out[class] = h end
  for class, h in pairs(s and s.heights or {}) do
    if type(h) == "number" and FALLBACK_HEIGHTS[class] then out[class] = h end
  end
  return out
end

-- tile id -> class, from the hand-authored groups for one tileset. Unknown
-- class names are dropped rather than trusted: a typo in the data file
-- should degrade to the derived default, not invent a zero-height class.
local function authoredGroups(entry, heights)
  local out = {}
  if not entry then return out end
  for class, tiles in pairs(entry) do
    if heights[class] and type(tiles) == "table" then
      for _, t in ipairs(tiles) do out[t] = class end
    end
  end
  return out
end

-- Conditional pins: tile id -> list of { above = {tile ids}, class }.
--
-- A pin is per TILE ID, and one graphic can mean two things. The route
-- gates' $32/$33 is the case that forced this: the artist reuses it for
-- the wall's dark base course AND for every service counter's front, and
-- it is the bottom row of its cell either way. Pinned `wall` the counter
-- stands a full 16px; pinned `counter` the wall bank corrugates 16/8 for
-- sixteen rows. Neither is right, and no per-tile pin can be, because
-- forMap resolves an id to ONE shape.
--
-- What separates the two uses is what is drawn ABOVE: the wall's upper
-- course over a wall base, the counter's top over a counter front. So a
-- profile entry may carry `when_above = { [tile] = { { above = {...},
-- class = "..." } } }`, evaluated per POSITION in TileShape.at, where
-- the map and coordinates are in hand. First match wins; no match keeps
-- the tile's ordinary pin.
-- `when_below` is the mirror, and it exists because ABOVE is not always the
-- side that tells the two uses apart.  The Plateau's $0D is the case: it is
-- the gate wall's top band AND the base course under a column of rock face,
-- and scanned over both maps the tile above is $03 for 64 of the first and
-- 140 of the second -- no rule on `above` can split them.  What is BELOW
-- does, exactly: the wall's own face $0F sits under the top band and under
-- nothing else (336 vs 352, clean).
local function authoredConditions(entry, heights)
  if type(entry) ~= "table" then return nil end
  local out, any = {}, false

  local function collect(spec, side)
    if type(spec) ~= "table" then return end
    for tile, rules in pairs(spec) do
      if type(tile) == "number" and type(rules) == "table" then
        local list = out[tile] or {}
        for _, rule in ipairs(rules) do
          if type(rule) == "table" and heights[rule.class]
             and type(rule[side]) == "table" then
            local set = {}
            for _, t in ipairs(rule[side]) do set[t] = true end
            list[#list + 1] = { side = side, set = set, class = rule.class }
          end
        end
        if #list > 0 then
          out[tile] = list
          any = true
        end
      end
    end
  end

  collect(entry.when_above, "above")
  collect(entry.when_below, "below")
  return any and out or nil
end

local function shapeFor(class, heights, authored)
  return { class = class, h = heights[class] or 0,
           art = ART[class] or "upright",
           -- grass and flowers draw a flat ground base like any walkable
           -- tile; the standing tufts and cutouts are additive geometry
           -- from Structures
           flat = ART[class] == "flat" or class == "grass"
                  or class == "flower",
           authored = authored or false }
end

-- A few public stair drawings are also ordinary doorway/counter art.
-- A warp_stairs rule therefore requires BOTH a complete 2x2 source cell
-- and an actual engine warp. Resolve all four tiles together, before the
-- generic door fold, without changing tile pins or actor ride heights.
-- Malformed rules are ignored; non-warp aliases keep their original shape.
local function authoredWarpStairs(map, entry, heights)
  local rules = type(entry) == "table" and entry.warp_stairs
  if type(rules) ~= "table" then return nil end
  local out, any = {}, false
  for _, warp in ipairs(map.def and map.def.warps or {}) do
    local cx, cy = warp.x, warp.y
    if type(cx) == "number" and type(cy) == "number" then
      for _, rule in ipairs(rules) do
        local grid = type(rule) == "table" and rule.tiles
        local valid = type(grid) == "table" and #grid == 2
          and type(grid[1]) == "table" and #grid[1] == 2
          and type(grid[2]) == "table" and #grid[2] == 2
          and ART[rule.class] == "stair" and heights[rule.class]
        if valid then
          for dz = 0, 1 do for dx = 0, 1 do
            local tile = grid[dz + 1][dx + 1]
            if type(tile) ~= "number" or tile < 0 or tile ~= math.floor(tile) then valid = false end
          end end
        end
        if valid then
          out[cy] = out[cy] or {}
          out[cy][cx] = out[cy][cx] or {}
          local shape = shapeFor(rule.class, heights, true)
          shape.warpStair = true
          out[cy][cx][#out[cy][cx] + 1] = { tiles = grid, shape = shape }
          any = true
        end
      end
    end
  end
  return any and out or nil
end

-- Resolved TILE-LEVEL shapes for the tileset `map` uses: a list indexed by
-- tile id holding { class, h, art, flat, authored }, plus `classes`, one
-- canonical shape per class for the cell-level overrides in TileShape.at.
-- Cached per tileset id -- this table depends only on the tileset record
-- and the data file, both constant for a given id. Profiles with explicit
-- warp rules cache per map; other positional resolution stays in at().
function TileShape.forMap(map)
  local tileset = map.tileset
  local id = tileset.id
  local profile = load()
  local base = profile and profile.tilesets and profile.tilesets[id]
  local perMap = profile and profile.maps and profile.maps[map.id]
  local positionRules = (perMap and perMap.warp_stairs) or (base and base.warp_stairs)
  local cacheKey = (perMap or positionRules) and (tostring(id) .. ":" .. tostring(map.id)) or id
  if cache[cacheKey] then return cache[cacheKey] end

  local heights = TileShape.heights()
  local entry = base
  if type(perMap) == "table" then
    entry = {}
    for k, v in pairs(type(base) == "table" and base or {}) do entry[k] = v end
    for k, v in pairs(perMap) do entry[k] = v end
  end
  -- Per-tileset height overrides (a tileset entry's `heights`): the class
  -- vocabulary is global but the drawings are not -- the DOJO lab tables
  -- are drawn 6px tall where the default `table` is 12 -- and the height
  -- a sprite RIDES at (VoxelScene.groundAt) must be the height the art
  -- actually stands, or the starter balls float over their own table.
  -- Same gate as the global list: known classes, numbers only.
  do
    local over = entry and entry.heights
    if type(over) == "table" then
      for class, h in pairs(over) do
        if type(h) == "number" and FALLBACK_HEIGHTS[class] then
          heights[class] = h
        end
      end
    end
  end
  local authored = authoredGroups(entry, heights)
  local count = math.floor((tileset.imageWidth or 128) / 8)
                * math.floor((tileset.imageHeight or 48) / 8)

  -- derived pin: a tile the tileset animates by FRAME REWRITE (the
  -- overworld's flower) is already named by its animation spec, so like
  -- tall grass it needs no profile entry anywhere. Hand-authoring still
  -- wins -- a mod animating a wall tile this way keeps its wall by
  -- listing it. Guarded because the spec seam is engine data a stub map
  -- may not carry.
  local flowerTiles = {}
  do
    local ok, declared = pcall(function()
      if tileset.animatedTiles then return tileset.animatedTiles end
      local TileRenderer = require("src.render.TileRenderer")
      return TileRenderer.defaultAnimatedTiles(tileset)
    end)
    if ok then
      for _, spec in ipairs(type(declared) == "table" and declared or {}) do
        if spec.kind == "frames" and spec.tile then
          flowerTiles[spec.tile] = true
        end
      end
    end
  end

  local shapes = { classes = {}, cond = authoredConditions(entry, heights),
                   saplingTiles = {}, warpStairs = authoredWarpStairs(map, entry, heights) }
  for _, tile in ipairs(type(entry) == "table"
      and type(entry.sapling_tiles) == "table" and entry.sapling_tiles or {}) do
    shapes.saplingTiles[tile] = true
  end
  for class in pairs(FALLBACK_HEIGHTS) do
    shapes.classes[class] = shapeFor(class, heights)
  end
  -- a conditional pin's own AUTHORED shape per class it can resolve to,
  -- kept apart from the shared canonical ones above (see TileShape.at)
  if shapes.cond then
    shapes.condShape = {}
    for _, rules in pairs(shapes.cond) do
      for _, rule in ipairs(rules) do
        shapes.condShape[rule.class] = shapes.condShape[rule.class]
          or shapeFor(rule.class, heights, true)
      end
    end
  end
  for t = 0, count - 1 do
    local class = authored[t]
    if class then
      shapes[t] = shapeFor(class, heights, true)
      local topTile = entry and entry.top_tiles and entry.top_tiles[t]
      if type(topTile) == "number" then shapes[t].topTile = topTile end
    elseif t == tileset.grassTile then
      -- derived pin: every tileset already names its tall-grass tile, so
      -- the standing-tuft treatment needs no profile entry anywhere
      shapes[t] = shapeFor("grass", heights, true)
    elseif flowerTiles[t] then
      shapes[t] = shapeFor("flower", heights, true)
    elseif map.waterTiles and map.waterTiles[t] then
      shapes[t] = shapes.classes.water
    elseif map.walkable and map.walkable[t] then
      shapes[t] = shapes.classes.ground
    else
      shapes[t] = shapes.classes.wall
    end
  end
  shapes.count = count
  cache[cacheKey] = shapes
  return shapes
end

-- The shape of the tile at TILE coordinates (tx, ty) -- the full
-- resolution including the cell-granularity steps (see the header).
-- `shapes` is the table forMap returned for this map; `tile` is
-- map:tileAt(tx, ty), passed in because every caller already has it.
function TileShape.at(map, shapes, tile, tx, ty)
  local cx, cy = math.floor(tx / 2), math.floor(ty / 2)
  local row = shapes.warpStairs and shapes.warpStairs[cy]
  local candidates = row and row[cx]
  -- Cache immutable warp/rule candidates, not the current block drawing:
  -- the Game Corner poster reveals its stair source in place at runtime.
  if candidates then
    for _, rule in ipairs(candidates) do
      local matches = true
      for dz = 0, 1 do for dx = 0, 1 do
        if map:tileAt(cx * 2 + dx, cy * 2 + dz) ~= rule.tiles[dz + 1][dx + 1] then matches = false end
      end end
      if matches then return rule.shape end
    end
  end
  local s = shapes[tile]
  -- The source Battle Art profile pins these four graphics as its original
  -- thin prop. Reclassify them only for the opt-in Legendary renderer; this
  -- lets one install keep a true Battle Art A/B path while still feeding the
  -- proven TEST455 round-tree handoff when requested.
  if shapes.saplingTiles and shapes.saplingTiles[tile]
      and customCutTrees() then
    return shapes.classes.sapling
  end
  -- conditional pins first: they are authored answers that need the
  -- POSITION to resolve, so they outrank both the flat pin on the same
  -- tile and the cell rules below (see authoredConditions)
  local rules = shapes.cond and shapes.cond[tile]
  if rules then
    for _, rule in ipairs(rules) do
      -- NOTE map:tileAt border-EXTENDS: one row off an edge answers the
      -- map's borderBlock, never nil.  A rule listing whatever that block
      -- draws will fire along that whole edge (it did, on the Marts).
      local n = map:tileAt(tx, rule.side == "above" and ty - 1 or ty + 1)
      if n and rule.set[n] then
        -- shapes.condShape, NOT shapes.classes: the canonical class
        -- shapes are SHARED, and `wall` in particular is the very object
        -- rule 4 hands every unauthored solid tile. Marking that one
        -- authored (which the first cut did) made every one of them skip
        -- the cell rules below, so walkable floors stopped flattening and
        -- whole rooms rose into a checkerboard of blocks.
        return shapes.condShape[rule.class]
      end
    end
  end
  if not s or s.authored then return s end
  local cx = math.floor(tx / 2)
  local cy = math.floor(ty / 2)
  if map:isWaterCell(cx, cy) then return shapes.classes.water end
  if map:isWalkableCell(cx, cy) then return shapes.classes.ground end
  return s
end

-- Hand-authored FIGURES for one tileset: a drawing painted INTO furniture,
-- cut out by an explicit pixel mask and stood up on top of it.
--
-- Every other route in this file resolves a whole 8x8 TILE, which is
-- exactly why none of them can reach a figure that shares its tiles with
-- the thing it sits on -- and the detector's segmentation cannot either
-- when the drawing has no background margin to flood from and wears the
-- same shades as its furniture.  So the profile authors the silhouette
-- pixel by pixel (see data/voxel_heights.lua):
--
--   figures = { { w      = <tiles across>,
--                 depth  = <voxels of body; ABSENT for a person>,
--                 thin   = { rows = <top rows>, depth = <voxels> },
--                 flat   = { x = { <lx0>, <lx1> }, rows = { <r0>, <r1> } },
--                 tiles  = { ...w*h tile ids, row-major... },
--                 under  = { ...w*h ids: what each tile wears once the
--                            figure is lifted off it... },
--                 pixels = { ...h*8 strings of w*8 chars, "." = not the
--                            figure... } } }
--
-- No class -- what the entry carries instead is a `depth`, or does not:
--
--   WITHOUT one it is a flat sprite card, drawn the way SpriteBillboards
--   draws a character.  That is the right reading for a PERSON: a Gen 1
--   figure is a face-on 2D icon, and extruding one reconstructs a body
--   nobody drew (see Structures.buildFigures).
--   WITH one it is an OBJECT and gets the standee treatment every other
--   solid here gets -- a per-pixel slab in world space, standing on the
--   same furniture the card would have stood on.  The Marts' cash
--   register is the case: a machine on a counter is a box, not an icon.
--
-- Two fields say which parts of such a drawing are NOT the extrusion,
-- because a solid drawn in one 16x16 GB cell still packs more than one
-- facing:
--
--   `thin` caps the thickness over the mask's top rows, for the part of
--   the drawing that is not the machine (the register's receipt curl).
--   `flat` names a rect of the mask that is a TOP-VIEW surface rather
--   than a face -- the register's keypad, whose keys lie ON its deck.
--   The rect lays horizontal one voxel proud of whatever the extrusion
--   leaves below it, at the elevation its BOTTOM row would have had,
--   with drawn row = depth row 1:1 (the mapping the lab tabletop is
--   drawn with).  So a drawing whose front elevation is an L reads as
--   one: body up the side and along the base, keys lying in the notch.
--
-- Returned normalized: `mask` as a set keyed by ly * (w * 8) + lx, so
-- Structures can read it as a bitmap without re-parsing per position.
-- A malformed entry is dropped rather than half-applied -- a typo in a
-- mask should leave the couch alone, not carve a hole in it.
--
-- `mounted` (below) carries the same four fields, so the parse is shared,
-- and so are the optional ones that give an authored mask a BODY: `depth`,
-- `thin` and `flat` above.  `depth` is left nil when unstated, because
-- absence is meaningful on a figure: no depth means the flat sprite card a
-- person is drawn as.
local function authoredMasks(list)
  local out = {}
  if type(list) ~= "table" then return out end
  for _, f in ipairs(list) do
    local ok = type(f) == "table" and type(f.w) == "number"
               and type(f.tiles) == "table" and type(f.under) == "table"
               and type(f.pixels) == "table"
    local w = ok and math.floor(f.w) or 0
    local h = (w >= 1) and (#f.tiles / w) or 0
    ok = ok and w >= 1 and h >= 1 and h == math.floor(h)
         and #f.under == #f.tiles and #f.pixels == h * 8
    if ok then
      for i = 1, h * 8 do
        local row = f.pixels[i]
        if type(row) ~= "string" or #row ~= w * 8 then
          ok = false
          break
        end
      end
    end
    if ok then
      local mask, n = {}, 0
      for ly = 0, h * 8 - 1 do
        local row = f.pixels[ly + 1]
        for lx = 0, w * 8 - 1 do
          if row:sub(lx + 1, lx + 1) ~= "." then
            mask[ly * (w * 8) + lx] = true
            n = n + 1
          end
        end
      end
      local depth = tonumber(f.depth)
      local thin = nil
      if type(f.thin) == "table" and tonumber(f.thin.rows)
         and tonumber(f.thin.depth) then
        thin = { rows = math.floor(tonumber(f.thin.rows)),
                 depth = math.floor(tonumber(f.thin.depth)) }
      end
      local flat = nil
      if type(f.flat) == "table" and type(f.flat.x) == "table"
         and type(f.flat.rows) == "table" then
        flat = { x0 = math.floor(f.flat.x[1]), x1 = math.floor(f.flat.x[2]),
                 r0 = math.floor(f.flat.rows[1]),
                 r1 = math.floor(f.flat.rows[2]) }
      end
      if n > 0 then
        out[#out + 1] = { w = w, h = h, n = n, mask = mask,
                          tiles = f.tiles, under = f.under,
                          depth = depth and math.floor(depth) or nil,
                          thin = thin, flat = flat }
      end
    end
  end
  return out
end

function TileShape.figures(tilesetId)
  local hit = figCache[tilesetId]
  if hit ~= nil then return hit or nil end

  local s = load()
  local entry = s and s.tilesets and s.tilesets[tilesetId]
  local out = authoredMasks(entry and entry.figures)

  figCache[tilesetId] = (#out > 0) and out or false
  return figCache[tilesetId] or nil
end

-- Hand-authored MOUNTED objects for one tileset: a thing drawn INTO the
-- wall band it hangs on, cut out by an explicit pixel mask and stood
-- proud of the wall's face.
--
-- Same authoring problem as `figures` and the same answer -- a class pin
-- resolves a whole 8x8 tile, and the detector cannot segment a drawing
-- that has no background margin to flood from.  The Bike Shop's two wall
-- bicycles are the case: the shop's striped wall panel runs BEHIND them,
-- and its #555 stripes are a flood boundary, so a silhouette flood comes
-- back with the stripes attached to the bike.
--
-- Two things differ from a figure, and both follow from the object being
-- an object rather than a character:
--
--   it keeps its DRAWN ELEVATION.  A figure stands on its own feet; a
--   mounted thing sits where the wall band draws it, so a bicycle hung
--   clear of the floor stays hung.
--   it has THICKNESS (`depth`, default 2), and it is built in world
--   space as a per-pixel slab jutting south of the band -- not as a
--   camera-facing sprite card.  A bicycle drawn side-on is a plane
--   parallel to the wall, not a face-on icon.
--
--   mounted = { { w      = <tiles across>,
--                 depth  = <voxels it juts into the room>,
--                 tiles  = { ...w*h tile ids, row-major... },
--                 under  = { ...w*h ids: what each tile wears once the
--                            object is lifted off it (the plain panel)... },
--                 pixels = { ...h*8 strings of w*8 chars, "." = wall... } } }
function TileShape.mounted(tilesetId)
  local hit = mntCache[tilesetId]
  if hit ~= nil then return hit or nil end

  local s = load()
  local entry = s and s.tilesets and s.tilesets[tilesetId]
  local out = authoredMasks(entry and entry.mounted)

  mntCache[tilesetId] = (#out > 0) and out or false
  return mntCache[tilesetId] or nil
end

-- Which GB shades count as BACKGROUND for a pinned per-pixel prop, per tile
-- (a tileset entry's prop_bg). Returns tile id -> set of shade names, or nil.
--
-- Structures normally votes on this by reading the shades that touch the
-- drawing's own bounding box, which is right whenever the drawing has a
-- margin of floor around it and wrong when it does not: a prop whose body
-- reaches its own edge votes itself out. Naming the shades is the override,
-- and it is keyed by TILE because the answer is per drawing rather than per
-- tileset -- two props in one atlas can want opposite calls on the same
-- shade (see the POKECENTER entry).
--
--   prop_bg = { { tiles = { ...ids... }, shades = { "light", "white" } } }
--
-- Only the four GB shade names exist; anything else is dropped, so a typo
-- degrades to the ordinary vote rather than emptying the background.
local SHADES = { black = true, dark = true, light = true, white = true }

function TileShape.propBg(tilesetId)
  local hit = bgCache[tilesetId]
  if hit ~= nil then return hit or nil end

  local s = load()
  local entry = s and s.tilesets and s.tilesets[tilesetId]
  local list = entry and entry.prop_bg
  local out, any = {}, false
  if type(list) == "table" then
    for _, rule in ipairs(list) do
      if type(rule) == "table" and type(rule.tiles) == "table"
         and type(rule.shades) == "table" then
        local set, n = {}, 0
        for _, name in ipairs(rule.shades) do
          if SHADES[name] then
            set[name] = true
            n = n + 1
          end
        end
        if n > 0 then
          for _, t in ipairs(rule.tiles) do
            if type(t) == "number" then
              out[t] = set
              any = true
            end
          end
        end
      end
    end
  end

  bgCache[tilesetId] = any and out or false
  return bgCache[tilesetId] or nil
end

-- What a bookcase rank does with the rows it VACATES -- the ones behind the
-- one-cell-deep box it collapses onto (a tileset entry's
-- bookcase_backfill).  Returns the mode name, or nil for the default.
--
--   "above"   hand them the cell immediately above the run: its shape and
--             its art.  A wall set INTO a terrace wants this -- the ground
--             behind it is more terrace, not a trench.
--   nil       skip them and paint the map's commonest ground underneath,
--             which is right for a free-standing shelf against a wall.
--
-- Per tileset because it is a statement about what the drawing depicts, and
-- the answer differs: the Mart's racks and Red's shelves stand in a room,
-- the Plateau's gate walls are cut into a hillside.
function TileShape.bookcaseBackfill(tilesetId)
  local s = load()
  local entry = s and s.tilesets and s.tilesets[tilesetId]
  local mode = entry and entry.bookcase_backfill
  return mode == "above" and mode or nil
end

--- Does this tileset's `bookcase` run carry the measured pane RELIEF on
--- its front (a tileset entry's bookcase_relief)?  Default yes: the class
--- almost always collapses a shelf, a rack or a display case, and every
--- one of those seals its contents behind a frame that should stand proud
--- of them.
---
--- A tileset says `bookcase_relief = false` when it borrows the collapse
--- for something that is NOT a shelf -- the League's gate walls and
--- pilasters, Bill's transporter drums -- where the drawing's light
--- regions are the masonry and the barrel, not panes, and sinking them
--- carves the surface instead of describing it.
function TileShape.bookcaseRelief(tilesetId)
  local s = load()
  local entry = s and s.tilesets and s.tilesets[tilesetId]
  return not (entry and entry.bookcase_relief == false)
end

-- Drop the cache: a mod that shadows data/voxel_heights.lua or a tileset
-- record needs the next lookup to re-resolve (hot reload, mod toggle).
function TileShape.invalidate()
  spec = nil
  cache = {}
  figCache = {}
  mntCache = {}
  bgCache = {}
end

return TileShape
