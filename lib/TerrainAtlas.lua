-- Voxel world mode: the texture terrain samples.
--
-- Voxel terrain is textured from the tileset atlas, so a map's colors have
-- to live IN that atlas. Two of the three color paths already do:
--
--   RED++      TileRenderer.new bakes a fully recolored per-map atlas
--              (getGbcAtlas) and hands it over as renderer.image -- nothing
--              to do here, true GBC terrain color comes through untouched.
--   trueColor  a mod's full-color atlas is already its own colors.
--
-- The SGB modes are the gap. There the atlas is raw 4-shade grayscale and
-- the color normally arrives as a screen-space shade-remap pass over
-- rectangular zones (PaletteFX) -- which has no meaning once the ground is
-- geometry rather than a rectangle. So bake instead: one atlas copy per
-- (atlas, palette), remapped through the same cutoffs the shader uses.
--
-- A map has exactly one world palette, so this is a handful of 128x48
-- images for a whole session, built once and cached.
--
-- ANIMATED TILES (water, flowers) are the other thing this file owns. The
-- 2D path animates them by OVERDRAWING the animated cells on top of the
-- static tile layer each frame, which a single static mesh has no
-- equivalent of -- the geometry samples one texture and that is that. So
-- animate the texture: rewrite the animated tile's slot in a private copy
-- of the atlas whenever the step advances, and every instance of that tile
-- across the whole mesh moves at once. Which is what the Game Boy does in
-- the first place (home/vcopy.asm rewrites the tile's VRAM bytes); the 2D
-- overdraw is the port's workaround, not the original.

-- the mod namespace (see main.lua): V.require loads a sibling module
local V = ...

local Assets = require("src.render.Assets")
local TileRenderer = require("src.render.TileRenderer")
local PaletteFX = require("src.render.PaletteFX")
local CommunityVisuals = V.require("CommunityVisuals")

-- TEST125 appends five independent high-resolution materials to Pokemon
-- Tower's otherwise tiny 8px tile atlas. The new 2048px reference granite
-- belongs only to walls and architectural ribs; TEST123's approved 1024px
-- black granite is preserved exclusively for the counter; a separate 2048px
-- honed slab belongs to the floor.
-- Keeping the original atlas at (0, 0) preserves every authored tile and
-- animation coordinate; all three extensions are Tower-only.
local TOWER_WALL_SIZE = 2048
local TOWER_COUNTER_SIZE = 1024
local TOWER_FLOOR_SIZE = 2048
local TOWER_DETAIL_SIZE = 1024
local MOD_PATH = V.path or "mods/BATTLE_ART_VOXEL_FORK"
local TOWER_WALL_PATHS = {
  smoke_black = MOD_PATH .. "/assets/legendary/tower_reference_wall.png",
  storm_white = MOD_PATH .. "/assets/legendary/tower_wall_storm_white.png",
  pearl_white = MOD_PATH .. "/assets/legendary/tower_wall_pearl_white.png",
}
local TOWER_COUNTER_PATH = (V.path or "mods/BATTLE_ART_VOXEL_FORK")
  .. "/assets/legendary/tower_luxury_granite.png"
local TOWER_COUNTER_TOP_PATH = (V.path or "mods/BATTLE_ART_VOXEL_FORK")
  .. "/assets/legendary/tower_counter_top_pearl.png"
local TOWER_FLOOR_PATH = (V.path or "mods/BATTLE_ART_VOXEL_FORK")
  .. "/assets/legendary/tower_honed_floor.png"
local TOWER_STAIR_PATH = (V.path or "mods/BATTLE_ART_VOXEL_FORK")
  .. "/assets/legendary/tower_aged_wood.png"
local TOWER_GRAVE_PATH = (V.path or "mods/BATTLE_ART_VOXEL_FORK")
  .. "/assets/legendary/tower_grave_stone.png"

local TerrainAtlas = {}

local cache = {}
local cacheData = {}    -- the pixels behind the atlases we baked ourselves
local community = {}    -- TEST435 material variants, keyed by live options
local animated = {}     -- key -> cached immutable prebuilt animation entry
                        -- false = given up on; nil = not built (or retrying)
local attempts = {}     -- key -> consecutive failures, for the retry budget

-- A failure that might not repeat -- a driver refusing one readback, an
-- asset briefly unreadable, a patch that threw once mid-reload -- must not
-- cost the animation for the rest of the session. It used to: the key was
-- condemned to `false` on the first miss and nothing ever rebuilt it, so
-- water stopped moving and stayed stopped until a hot reload.
--
-- Retry a few times, then give up for good so a genuinely broken atlas is
-- not rebuilt on every frame forever.
local MAX_ATTEMPTS = 3

local function attemptFailed(key)
  local n = (attempts[key] or 0) + 1
  attempts[key] = n
  if n >= MAX_ATTEMPTS then return false end   -- condemn it
  return nil                                    -- rebuild next frame
end

local function paletteKey(colors)
  local parts = {}
  for i = 1, 4 do
    local c = colors[i]
    parts[i] = c and (c[1] .. "," .. c[2] .. "," .. c[3]) or "-"
  end
  return table.concat(parts, ";")
end

-- The atlas image `map`'s terrain should sample, given the 4-color world
-- palette it sits under (nil to leave the atlas as-is). Falls back to the
-- renderer's own image whenever a bake is impossible -- headless, or no
-- pixel access -- which just means grayscale terrain rather than no
-- terrain.
-- The static atlas for `map` under `colors`: the answer this file gave
-- before animation existed, and the base every animated frame is patched
-- over. Returns the image and, when we baked it ourselves, its pixels.
local function staticAtlas(map, colors)
  local renderer = map.renderer
  local base = renderer and renderer.image
  if not base then return nil end
  -- already true color: RED++'s baked per-map atlas, or a mod's own art
  if not colors or renderer.gbcAtlas or map.tileset.trueColor then
    return base, false
  end
  if not (love.image and love.image.newImageData) then return base, false end

  local path = map.tileset.image
  local key = path .. "#" .. paletteKey(colors)
  if cache[key] ~= nil then return cache[key] or base, cacheData[key] end

  local data
  local ok, img = pcall(function()
    local src = Assets.imageData(path)
    local w, h = src:getDimensions()
    local out = love.image.newImageData(w, h)
    for y = 0, h - 1 do
      for x = 0, w - 1 do
        local r, g, b, a = src:getPixel(x, y)
        r, g, b, a = TileRenderer.recolorSample(r, g, b, a, colors)
        out:setPixel(x, y, r, g, b, a)
      end
    end
    local image = love.graphics.newImage(out)
    image:setFilter("nearest", "nearest")
    data = out
    return image
  end)
  cache[key] = ok and img or false
  cacheData[key] = (ok and data) or false
  return cache[key] or base, cacheData[key]
end

-- ------------------------------------------------------------ animation --

-- The four GB shades as the ORIGINAL art carries them, by the same cutoffs
-- TileRenderer.recolorSample splits on -- so a shade learned here and a
-- shade recolored there are the same shade.
local function shadeOf(r)
  if r > 0.83 then return 1 end
  if r > 0.5 then return 2 end
  if r > 0.17 then return 3 end
  return 4
end

-- How this atlas recolored one tile, learned by reading the tile's slot in
-- the raw art and in the finished atlas side by side: shade -> the colour
-- it became.
--
-- Learned rather than recomputed because the two recolour paths do not
-- share a rule -- SGB bakes one world palette over everything, RED++ picks
-- a palette group per tile GRAPHIC -- and a flower frame arrives as its own
-- little grayscale file that never went through either. Asking "what
-- happened to the tile I am replacing" gets the right answer from both
-- without this file knowing which one ran.
local function learnShades(raw, baked, tile, perRow)
  local sx, sy = (tile % perRow) * 8, math.floor(tile / perRow) * 8
  local map = {}
  for y = 0, 7 do
    for x = 0, 7 do
      local k = shadeOf(raw:getPixel(sx + x, sy + y))
      if not map[k] then
        local r, g, b, a = baked:getPixel(sx + x, sy + y)
        map[k] = { r, g, b, a }
      end
    end
  end
  return map
end

local DIRS4 = { { 1, 0 }, { -1, 0 }, { 0, 1 }, { 0, -1 } }

-- One animated entry's tile slot, written into `out` at step `step`.
local function patch(out, entry, spec, step)
  local perRow, tile = entry.perRow, spec.tile
  local dx, dy = (tile % perRow) * 8, math.floor(tile / perRow) * 8
  if spec.kind == "hshift" then
    -- the water rotate (the asm's rrca/rlca run): the tile's own pixels,
    -- rolled sideways. Read from the UNANIMATED base, or each step would
    -- compound on the last one's shift.
    local o = spec.offsets[step % #spec.offsets + 1]
    for y = 0, 7 do
      for x = 0, 7 do
        local r, g, b, a = entry.base:getPixel(dx + x, dy + y)
        out:setPixel(dx + (x + o) % 8, dy + y, r, g, b, a)
      end
    end
  elseif spec.kind == "frames" then
    local path = spec.images[spec.sequence[step % #spec.sequence + 1]]
    if not path then return end
    local ok, frame = pcall(Assets.imageData, path)
    if not ok or not frame then return end
    local shades = entry.shades and entry.shades[tile]
    -- a `cut` tile is the flower billboard's slot (Structures'
    -- buildFlowers): only the frame's darkest tones AND what they
    -- enclose stay opaque -- the round-scenery hull's rule, flooding
    -- the frame border through every non-dark pixel so the pale petal
    -- insides survive with the outline. The true background is keyed
    -- to alpha; nothing else samples this slot (the ground under a
    -- flower is synthesized), and the shader's discard is what lets
    -- the billboard's silhouette change per frame under geometry that
    -- never moves.
    local mask = nil
    if entry.cut and entry.cut[tile] then
      local dark, reach, stack = {}, {}, {}
      for y = 0, 7 do
        for x = 0, 7 do
          local r, _, _, a = frame:getPixel(x, y)
          if a > 0 and shadeOf(r) >= 3 then dark[y * 8 + x] = true end
        end
      end
      for i = 0, 7 do
        for _, s in ipairs({ i, 56 + i, i * 8, i * 8 + 7 }) do
          if not dark[s] and not reach[s] then
            reach[s] = true
            stack[#stack + 1] = s
          end
        end
      end
      while #stack > 0 do
        local p = table.remove(stack)
        local px, py = p % 8, math.floor(p / 8)
        for _, d in ipairs(DIRS4) do
          local nx, ny = px + d[1], py + d[2]
          if nx >= 0 and nx < 8 and ny >= 0 and ny < 8 then
            local ni = ny * 8 + nx
            if not dark[ni] and not reach[ni] then
              reach[ni] = true
              stack[#stack + 1] = ni
            end
          end
        end
      end
      mask = {}
      for i = 0, 63 do mask[i] = dark[i] or not reach[i] end
    end
    for y = 0, 7 do
      for x = 0, 7 do
        local r, g, b, a = frame:getPixel(x, y)
        if mask and not mask[y * 8 + x] then
          out:setPixel(dx + x, dy + y, 0, 0, 0, 0)
        else
          local col = shades and shades[shadeOf(r)]
          if col and a > 0 then r, g, b = col[1], col[2], col[3] end
          out:setPixel(dx + x, dy + y, r, g, b, a)
        end
      end
    end
  end
end

-- The animation specs this file can serve: the two that rewrite a tile's
-- pixels. "toggle" (the spinner-puzzle blur) is a whole-atlas swap gated on
-- a gameplay state, and is left to the 2D path -- voxel mode does not draw
-- the spinner rooms' tile layer any differently for it.
local function specsFor(tileset)
  local declared = tileset.animatedTiles
                   or TileRenderer.defaultAnimatedTiles(tileset)
  local out = nil
  for _, spec in ipairs(declared or {}) do
    local usable = spec.tile
      and ((spec.kind == "hshift" and spec.offsets and #spec.offsets > 0)
           or (spec.kind == "frames" and spec.images and spec.sequence
               and #spec.sequence > 0))
    if usable then
      out = out or {}
      out[#out + 1] = spec
    end
  end
  return out
end

-- Pixels back off a texture the engine built on the GPU and kept no copy
-- of. LOVE 11 hands out no ImageData for an Image, so the only route is a
-- round trip: draw it 1:1 into a canvas and read that back.
--
-- This runs inside the world pass, with the pipeline's own canvas bound, so
-- the previous target is captured and put back rather than unbound -- the
-- usual setCanvas() would drop the rest of the frame on the floor. One
-- readback per map, cached with the entry it feeds; the atlas is a couple
-- of hundred pixels square, so the GPU sync costs far less than the mesh
-- build it happens alongside. Every step is guarded: a driver that refuses
-- canvas readback costs the animation and nothing else.
local function readback(image)
  if not (image and love.graphics and love.graphics.newCanvas
          and love.graphics.getCanvas) then
    return nil
  end
  local prev = love.graphics.getCanvas()
  local ok, data = pcall(function()
    local w, h = image:getDimensions()
    -- dpiscale = 1, or this is not a copy. On a highdpi surface (Android,
    -- iOS -- see conf.lua) newCanvas takes the surface's scale by default,
    -- so the atlas would be drawn into a texture 2.75x its size and read
    -- back magnified -- and every tile coordinate below, which counts in
    -- eights from the top-left, would land somewhere between two tiles.
    local canvas = love.graphics.newCanvas(w, h, { dpiscale = 1 })
    love.graphics.setCanvas(canvas)
    love.graphics.clear(0, 0, 0, 0)
    -- straight copy: no blending against the cleared target, no tint from
    -- whatever colour the pass left set, or the atlas comes back wrong
    love.graphics.setBlendMode("replace", "premultiplied")
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.draw(image, 0, 0)
    love.graphics.setBlendMode("alpha", "alphamultiply")
    -- LOVE refuses newImageData on the currently-active canvas, so the
    -- previous target has to come back BEFORE the read, not just after
    love.graphics.setCanvas(prev)
    local out = canvas:newImageData()
    if canvas.release then canvas:release() end
    return out
  end)
  pcall(love.graphics.setCanvas, prev)
  return ok and data or nil
end

-- RED++'s per-map atlas, rebuilt on the CPU.
--
-- This is the case that has no pixels anywhere: `getGbcAtlas` bakes one
-- ImageData per map, hands the texture to the renderer and drops the
-- pixels on the floor. Without them the animated tiles cannot be patched,
-- which is why water and flowers stood still under RED++ and nowhere else.
--
-- The readback below can recover them from the texture, but it is at the
-- mercy of whether the driver will read a canvas back, and it costs a GPU
-- sync mid-frame. Everything the engine baked FROM is public, so bake it
-- again instead: the raw art, the per-tile palette group, the group's
-- colours, and the same recolorSample cutoffs. Deterministic, no driver
-- involved, and it can be tested without a GPU.
--
-- It does mirror engine logic and could drift from getGbcAtlas if that
-- changes -- the readback stays behind it as the exact-but-fragile route.
local function gbcPixels(map)
  local renderer, tileset = map.renderer, map.tileset
  local data = renderer and renderer.data
  if not (data and tileset and love.image and love.image.newImageData) then
    return nil
  end
  local ok, out = pcall(function()
    local groupColors = PaletteFX.worldGroupColors(data, tileset.id, map.id, nil)
    if not groupColors then return nil end
    local src = Assets.imageData(tileset.image)
    local iw, ih = src:getDimensions()
    local perRow = tileset.tilesPerRow or 16
    local total = (iw / 8) * (ih / 8)
    local dst = love.image.newImageData(iw, ih)

    local function bake(from, to, colors)
      local sxo, syo = (from % perRow) * 8, math.floor(from / perRow) * 8
      local dxo, dyo = (to % perRow) * 8, math.floor(to / perRow) * 8
      for py = 0, 7 do
        for px = 0, 7 do
          local r, g, b, a = src:getPixel(sxo + px, syo + py)
          r, g, b, a = TileRenderer.recolorSample(r, g, b, a, colors)
          dst:setPixel(dxo + px, dyo + py, r, g, b, a)
        end
      end
    end

    local tileColors = {}
    for t = 0, total - 1 do
      local colors = tileColors[t]
      if colors == nil then
        local group = PaletteFX.worldGroupAt(tileset.id, map.id, t)
        colors = (group and groupColors[group + 1]) or false
        tileColors[t] = colors
      end
      bake(t, t, colors)
    end
    -- duplicate-tile aliases: the same graphic baked into a spare slot
    -- under a second palette group, so cells drawing the alias colour apart
    for _, al in ipairs(PaletteFX.TILE_ALIASES
                        and PaletteFX.TILE_ALIASES[map.id] or {}) do
      if al.alias < total then
        bake(al.tile, al.alias, groupColors[al.group + 1])
      end
    end
    return dst
  end)
  return ok and out or nil
end

-- The pixels behind the atlas texture the engine is drawing with, for the
-- frames where we did not bake one ourselves (staticAtlas returns `false`
-- for its own bake whenever the palette is absent, RED++ already baked, or
-- the tileset is trueColor).
--
-- TileRenderer.atlasImageData is the engine's own accessor for exactly this
-- and is preferred wherever the build offers it -- but like the sibling
-- clock TileRenderer.animFrame it is an OPTIONAL seam, and a build without
-- it has to cost us the animation, not the whole render pipeline. Reading
-- it unguarded is what took the pass down for the session.
--
-- Without the seam the pixels are still recoverable, by two different
-- routes. An atlas neither we nor RED++ replaced is the tileset art itself,
-- so the art on disk IS what it was built from. RED++'s per-map bake exists
-- only on the GPU -- getGbcAtlas throws its ImageData away once the texture
-- is made -- so that one has to come back off the texture (readback below).
local function rendererPixels(map)
  local renderer = map.renderer
  if not renderer then return nil end
  if TileRenderer.atlasImageData then
    local ok, data = pcall(TileRenderer.atlasImageData, renderer)
    if ok and data then return data end
  end
  if renderer.gbcAtlas then
    return gbcPixels(map) or readback(renderer.image)
  end
  local ok, data = pcall(Assets.imageData, map.tileset.image)
  return ok and data or nil
end

-- TEST435's approved material family, isolated behind Battle Art-native
-- settings. Every edit stays inside the existing cached atlas: no per-frame
-- uploads, extra material or draw call.
local MATERIAL = {
  granite = {
    dark={.13,.13,.12,1}, shadow={.25,.24,.22,1},
    body={.43,.41,.37,1}, light={.60,.57,.51,1},
  },
  red = {
    dark={.18,.070,.045,1}, shadow={.32,.125,.080,1},
    body={.50,.225,.145,1}, light={.66,.375,.250,1},
  },
  sandstone = {
    dark={.22,.155,.085,1}, shadow={.37,.275,.155,1},
    body={.56,.430,.260,1}, light={.72,.590,.390,1},
  },
  slate = {
    dark={.085,.105,.145,1}, shadow={.175,.215,.285,1},
    body={.305,.365,.455,1}, light={.475,.545,.635,1},
  },
}

local ROCK_ART = {
  "DSBLDSBL", "DBBBBLLD", "DBLBBBBD", "DDBBBDDD",
  "BBBDDDBB", "BLBDBBBB", "BBBDBLBB", "DDDDDBDD",
}
local PATH_ART = {
  "BSBBLBSB", "SBLBBSBL", "BBSBLBBS", "LBBSBSBB",
  "BSLBBLBS", "SBBLSBBB", "BLBSBBLB", "SBBBLBBS",
}
local WOOD_ART = {
  "DSBLDSBL", "BBBBLLBB", "BBLBBBBD", "SBBBBBBS",
  "BBBSBBBB", "BLBBBBLB", "BBBBLBBB", "SBBBBBBS",
}
local GRASS_ART = {
  "BBSSBBLB", "BSLLSBBB", "SSBLLBBS", "BLBSSSBB",
  "BBSSBLBB", "SBBLSSLB", "BLSBBBSS", "SSBBLSBB",
}
-- TEST115 Pokemon Tower. ChunkMesher now supplies continuous world-space
-- granite, so this donor is deliberately quiet and cannot announce the 8px
-- source grid if a fallback face ever samples the whole tile.
local TOWER_FLOOR_ART = {
  "BBBBBBBB", "BBBBBBBB", "BBBBBBBB", "BBBBBBBB",
  "BBBBBBBB", "BBBBBBBB", "BBBBBBBB", "BBBBBBBB",
}
-- TEST96 Viridian floor: broad clustered moss and sparse brown leaf litter,
-- not the evenly spaced dark-dot grid of the source tile. Four related
-- variants plus ChunkMesher's coordinate rotation keep an 8px donor from
-- announcing itself as wallpaper across the forest.
local FOREST_GROUND_ART = {
  {
    "BBBBBBBB", "BBSSSBBB", "BSSSSBBB", "BBSSBBBB",
    "BBBBBBDB", "BBBBBDDB", "BLBBBBBB", "BBBBBBBB",
  },
  {
    "BBBBLBBB", "BBBBBBBB", "BSSBBBBB", "SSSBBBBB",
    "BSSBBBBB", "BBBBBDBB", "BBBBBDDB", "BBBBBBBB",
  },
  {
    "BBBBBBBB", "BDBBBBBB", "BDDBBLBB", "BBBBBBBB",
    "BBBSSSBB", "BBSSSSBB", "BBBSSBBB", "BBBBBBBB",
  },
  {
    "BBBBBBBB", "BBBBBSSB", "BBBBSSSS", "BBBBBSSB",
    "BDBBBBBB", "BDDBBBBB", "BBBBLBBB", "BBBBBBBB",
  },
}
local COURT_ART = {
  "DDDDDDDD", "DBBBBBBD", "DBBLBBBD", "DBBBBBBD",
  "DBBBLBDD", "DBBBBBBD", "DBLBBBBD", "DDDDDDDD",
}

-- TEST36 warm brick / quiet cap atlas. TEST62 deliberately gives only the
-- walkable earth donors dense, low-contrast soil grain; shelf and wall donors
-- remain solid because their detail comes from real geological geometry.
-- Tile 2 retains four cave-only colour swatches for raised wall geometry.
local CAVE_BEDROCK_ART = {
  "BBBBBBBB", "BBBBBBBB", "BBBBBBBB", "BBBBBBBB",
  "BBBBBBBB", "BBBBBBBB", "BBBBBBBB", "BBBBBBBB",
}
local CAVE_FLOOR_ART = {
  {
    "BSBBSDBS", "BBDSBBBL", "SBBBSBBD", "BLSBBDBB",
    "BBBSBSBB", "DBBBSBBS", "BBLBBDBB", "SBBDBBSB",
  },
  {
    "BDBBSBBS", "SBBBLBDB", "BBSSBBBL", "BDBBBSBB",
    "BBLBDBBS", "SBBSBBDB", "BBDBSBBL", "LBBSDBBB",
  },
  {
    "BBLBSBBD", "SBBDBBSB", "BBSBBLBB", "DBBSBBBS",
    "BBBSDBBL", "SBLBBBSB", "BBDBSBBS", "BSBBLDBB",
  },
}
local CAVE_LEDGE_ART = {
  CAVE_BEDROCK_ART, CAVE_BEDROCK_ART, CAVE_BEDROCK_ART,
}
local CAVE_WALL_ART = {
  {
    -- Tile 2 is an atlas-only four-colour swatch for raised wall geometry.
    "DSBLBBBB", "BBBBBBBB", "BBBBBBBB", "BBBBBBBB",
    "BBBBBBBB", "BBBBBBBB", "BBBBBBBB", "BBBBBBBB",
  },
  CAVE_BEDROCK_ART,
  CAVE_BEDROCK_ART,
}
local CAVE_FLOOR_VARIANT = { [32]=1, [33]=2, [42]=3 }
local CAVE_LEDGE_VARIANT = { [5]=1, [41]=2 }
local CAVE_WALL_VARIANT = { [2]=1, [3]=2, [12]=3 }
local CAVE_WATER_ART = {
  "SSSSSSSS", "SSBSSSSS", "SSSSSLSS", "SSSSSSSS",
  "SLSSSSSS", "SSSSBSSS", "SSSSSSSS", "SSSBSSLS",
}

local CAVE_EARTH = {
  dark={.090,.048,.026,1}, shadow={.135,.075,.038,1},
  body={.190,.115,.060,1}, light={.250,.165,.085,1},
}
local CAVE_SHELF = {
  dark={.080,.048,.038,1}, shadow={.155,.088,.064,1},
  body={.270,.170,.125,1}, light={.390,.270,.190,1},
}
local CAVE_ROCK = {
  dark={.060,.035,.032,1}, shadow={.135,.073,.060,1},
  body={.235,.140,.108,1}, light={.355,.235,.170,1},
}
local CAVE_WATER = {
  dark={.055,.085,.120,1}, shadow={.080,.135,.185,1},
  body={.115,.190,.245,1}, light={.180,.285,.345,1},
}
local CAVE_HOLE = {
  [1]={.365,.285,.230,1}, [2]={.255,.185,.150,1},
  [3]={.140,.095,.085,1}, [4]={.025,.020,.024,1},
}

local PATH = {
  dark={.626,.566,.456,1}, shadow={.638,.578,.468,1},
  body={.650,.590,.480,1}, light={.662,.602,.492,1},
}
local WOOD = {
  dark={.16,.085,.035,1}, shadow={.29,.16,.070,1},
  body={.48,.29,.13,1}, light={.66,.43,.22,1},
}
local GRASS = {
  dark={.17,.35,.12,1}, shadow={.22,.43,.16,1},
  body={.27,.50,.20,1}, light={.33,.57,.26,1},
}
local ROUTE10_GRASS = {
  dark={.23,.46,.13,1}, shadow={.30,.57,.18,1},
  body={.38,.68,.24,1}, light={.47,.77,.32,1},
}
local LAVENDER_PATH = {
  dark={.300,.305,.385,1}, shadow={.395,.400,.480,1},
  body={.515,.520,.600,1}, light={.635,.640,.710,1},
}
local TOWER_FLOOR = {
  dark={.135,.135,.150,1}, shadow={.205,.205,.220,1},
  body={.305,.305,.320,1}, light={.410,.405,.420,1},
}
-- `recolor` palettes follow the source Game Boy shade order: brightest first.
-- TEST115 moves the Tower away from black brick toward the reference's broad,
-- cloudy grey granite. A restrained violet cast remains only in the shadows.
local TOWER_STONE = {
  [1]={.690,.690,.705,1}, [2]={.505,.505,.525,1},
  [3]={.315,.315,.340,1}, [4]={.115,.112,.145,1},
}
local TOWER_MASONRY = {
  dark={.115,.115,.130,1}, shadow={.245,.245,.260,1},
  body={.455,.455,.465,1}, light={.720,.720,.730,1},
}
local TOWER_COUNTER = {
  [1]={.650,.645,.660,1}, [2]={.485,.480,.500,1},
  [3]={.305,.300,.325,1}, [4]={.110,.105,.135,1},
}
local TOWER_GRAVE = {
  [1]={.615,.610,.635,1}, [2]={.440,.435,.465,1},
  [3]={.260,.255,.290,1}, [4]={.095,.090,.130,1},
}
local TOWER_FIXTURE = {
  [1]={.420,.350,.250,1}, [2]={.285,.225,.180,1},
  [3]={.155,.120,.125,1}, [4]={.055,.045,.075,1},
}
local FOREST_GROUND = {
  -- D is intentionally warm: the rare D flecks become fallen leaves rather
  -- than more green confetti. S/B/L remain one restrained moss family.
  dark={.18,.135,.055,1}, shadow={.090,.245,.075,1},
  body={.175,.365,.105,1}, light={.285,.475,.165,1},
}
local FOREST_TALL_GRASS = {
  [1]={.285,.475,.165}, [2]={.205,.405,.120},
  [3]={.125,.300,.080}, [4]={.070,.205,.055},
}
-- Only non-green pixels of the authored large-tree tiles are folded into this
-- foliage family. Existing green palette work and near-black outline pixels
-- pass through untouched; pale sparkle and tan fallback blocks do not.
local FOREST_FOLIAGE = {
  [1]={.315,.515,.180}, [2]={.205,.405,.115},
  [3]={.115,.285,.070}, [4]={.040,.115,.040},
}
-- Safety palette for a partial stump drawing that cannot be handed to the
-- boulder mesh. It preserves the source pixel silhouette while making the
-- fallback damp stone rather than white-and-orange timber.
local FOREST_STONE = {
  [1]={.390,.385,.315}, [2]={.285,.300,.230},
  [3]={.170,.205,.145}, [4]={.070,.095,.070},
}
local COURT = {
  dark={.38,.34,.27,1}, shadow={.50,.46,.37,1},
  body={.64,.59,.48,1}, light={.74,.69,.57,1},
}
local TALL_GRASS = {
  [1]={.34,.58,.26}, [2]={.28,.51,.20},
  [3]={.21,.41,.14}, [4]={.15,.32,.10},
}

local function communityKey()
  return table.concat({
    CommunityVisuals.rocket:get(), CommunityVisuals.cityGround:get(), CommunityVisuals.grass:get(),
    CommunityVisuals.roads:get(),
    CommunityVisuals.walls:get(), CommunityVisuals.courtyards:get(),
    CommunityVisuals.wallColor(), CommunityVisuals.caves:get(),
    CommunityVisuals.forest:get(), CommunityVisuals.tower:get(),
    CommunityVisuals.towerWallStyle(),
  }, ":")
end

-- LuaJIT 5.1 has a hard per-function upvalue ceiling. Keep the heavy atlas
-- builder below that production limit by moving material-specific work into
-- small helpers instead of capturing every art/palette constant in the large
-- protected-build closure.
local function applyCaveCommunityMaterials(map, total, paint, recolor)
  local shapes = V.require("TileShape").forMap(map)
  local okRaw, raw = pcall(Assets.imageData, map.tileset.image)
  if not okRaw then raw = nil end
  for tile = 0, total - 1 do
    local shape = shapes[tile]
    local class = shape and shape.class
    if class == "wall" then
      local variant = CAVE_WALL_VARIANT[tile]
        or ((tile % #CAVE_WALL_ART) + 1)
      paint(tile, CAVE_WALL_ART[variant], CAVE_ROCK)
    elseif class == "ledge" then
      if tile == 21 or tile == 22 then
        -- These are the drawn north/south stair plates. Preserve their
        -- tread lines instead of replacing the whole tile with earth.
        recolor(tile, CAVE_HOLE, raw)
      else
        local variant = CAVE_LEDGE_VARIANT[tile]
          or ((tile % #CAVE_LEDGE_ART) + 1)
        paint(tile, CAVE_LEDGE_ART[variant], CAVE_SHELF)
      end
    elseif class == "ground" then
      if tile == 20 then
        paint(tile, CAVE_WATER_ART, CAVE_WATER)
      elseif tile == 47 or tile == 34 then
        recolor(tile, CAVE_HOLE, raw)
      else
        local variant = CAVE_FLOOR_VARIANT[tile]
          or ((tile % #CAVE_FLOOR_ART) + 1)
        paint(tile, CAVE_FLOOR_ART[variant], CAVE_EARTH)
      end
    elseif class == "stair_e" or class == "stair_down_e"
        or class == "relief" then
      -- Preserve authored rung, stair and switch-plate silhouettes.
      recolor(tile, CAVE_HOLE, raw)
    end
  end
  -- Stable donor and four swatches used by cave side/perimeter meshes.
  paint(2, CAVE_WALL_ART[1], CAVE_ROCK)
end

local function applyLavenderCommunityMaterials(paint, legendary)
  if not legendary then
    -- Absol's 1.10.7 Battle Art lawn/path palette stays separate.
    paint(35, PATH_ART, LAVENDER_PATH)
    paint(44, GRASS_ART, ROUTE10_GRASS)
    paint(57, PATH_ART, LAVENDER_PATH)
    return
  end
  -- Legendary-only street swatches; Battle Art's branch above stays intact.
  local style=CommunityVisuals.towerWallStyle()
  local palette
  if style=="pearl_white" then
    palette={dark={.36,.35,.38,1},shadow={.56,.54,.57,1},
      body={.78,.76,.75,1},light={.84,.82,.80,1}}
  elseif style=="storm_white" then
    palette={dark={.25,.27,.32,1},shadow={.40,.43,.49,1},
      body={.63,.66,.71,1},light={.70,.73,.77,1}}
  else
    palette={dark={.15,.14,.19,1},shadow={.25,.23,.30,1},
      body={.40,.37,.46,1},light={.47,.44,.53,1}}
  end
  paint(35,PATH_ART,LAVENDER_PATH)
  paint(44,GRASS_ART,GRASS)
  paint(48,{"DSBLBBBB","BBBBBBBB","BBBBBBBB","BBBBBBBB",
    "BBBBBBBB","BBBBBBBB","BBBBBBBB","BBBBBBBB"},palette)
  paint(57,GRASS_ART,GRASS)
end

local function communityAtlas(map, colors, base, baked)
  local tilesetId = map.tileset and map.tileset.id
  local mapId = tostring(map.id or ""):upper()
  local rocket = CommunityVisuals.rocket:get()=="n64memory" and tilesetId == "FACILITY" and mapId:match("^ROCKET_HIDEOUT_B[1-4]F$") ~= nil
  local cave = tilesetId == "CAVERN"
  local cityGroundMap = CommunityVisuals.isCityGroundMap(map)
  local legendaryCityGround = cityGroundMap and CommunityVisuals.customCityGround()
  local lavenderGround = cityGroundMap and mapId == "LAVENDER_TOWN"
  local fuchsiaGround = legendaryCityGround and mapId == "FUCHSIA_CITY"
  -- GRASS remains the broad route/Overworld control. The two city maps use
  -- CITY GROUND instead, so choosing Legendary grass cannot force their turf.
  local grassEnabled = (not cityGroundMap and CommunityVisuals.customGrass())
    or fuchsiaGround
  local towerInterior = tilesetId == "CEMETERY"
    and mapId:match("^POKEMON_TOWER_[1-7]F$") ~= nil
    and CommunityVisuals.customTower()
  local overworldEnabled = (mapId=="ROUTE_10" and V.require("TowerGarden").enabled())
    or grassEnabled or lavenderGround
    or CommunityVisuals.customRoads() or CommunityVisuals.customWalls()
    or CommunityVisuals.customCourtyards()
  local forestEnabled = tilesetId == "FOREST"
    and tostring(map.id or "") == "VIRIDIAN_FOREST"
    and CommunityVisuals.customForest()
  -- Cave materials used to bypass every community-visual switch. Keep the
  -- original atlas untouched unless the dedicated CAVES row is opted in.
  if cave and not CommunityVisuals.customCaves() then return base, baked end
  if not cave and tilesetId == "OVERWORLD" and not overworldEnabled then
    return base, baked
  end
  if not cave and tilesetId ~= "OVERWORLD"
      and not forestEnabled and not towerInterior and not rocket then
    return base, baked
  end
  if not (love.image and love.image.newImageData and love.graphics
          and love.graphics.newImage) then return base, baked end

  -- CITY GROUND changes shared OVERWORLD donors per map. Keep both city maps
  -- isolated even on BATTLE ART: another Legendary Overworld atlas must never
  -- leak its grass donor into a city whose own row is disabled.
  local perMap = (V.require("CityStreets").enabled(mapId,CommunityVisuals.customRoads(),tilesetId) or rocket or cityGroundMap or mapId == "ROUTE_10" or towerInterior
      or (map.renderer and map.renderer.gbcAtlas))
    and tostring(map.id or "") or ""
  local key = map.tileset.image .. "#ember107-rocket2-materials#" .. communityKey()
    .. "#" .. paletteKey(colors or {}) .. perMap
  local held = community[key]
  if held then return held.image, held.data end
  local src = baked or rendererPixels(map)
  if not src then return base, baked end

  local ok, entry = pcall(function()
    local w, h = src:getDimensions()
    -- Pack wall + counter across the first row and floor beneath the wall.
    -- A horizontal 2048+1024+2048 row would exceed the conservative 4096px
    -- texture edge supported by some Android GPUs; this layout is 3200x4096
    -- with the normal 128px Cemetery source atlas.
    local outW = towerInterior and
      (w + TOWER_WALL_SIZE + TOWER_COUNTER_SIZE) or w
    local outH = towerInterior and
      math.max(h, TOWER_WALL_SIZE + TOWER_FLOOR_SIZE) or h
    local data = love.image.newImageData(outW, outH)
    data:paste(src, 0, 0, 0, 0, w, h)
    local perRow = map.tileset.tilesPerRow or 16
    local total = (w / 8) * (h / 8)

    local function paint(tile, art, palette)
      if type(tile) ~= "number" or tile < 0 or tile >= total then return end
      local ox, oy = (tile % perRow) * 8, math.floor(tile / perRow) * 8
      for py = 0, 7 do
        local row = art[py + 1]
        for px = 0, 7 do
          local mark = row:sub(px + 1, px + 1)
          local c = mark == "D" and palette.dark
            or mark == "S" and palette.shadow
            or mark == "L" and palette.light or palette.body
          local _, _, _, alpha = data:getPixel(ox + px, oy + py)
          data:setPixel(ox + px, oy + py, c[1], c[2], c[3], alpha)
        end
      end
    end

    local function recolor(tile, palette, raw)
      if type(tile) ~= "number" or tile < 0 or tile >= total then return end
      if not raw then return end
      local ox, oy = (tile % perRow) * 8, math.floor(tile / perRow) * 8
      for py = 0, 7 do
        for px = 0, 7 do
          local shade = shadeOf(raw:getPixel(ox + px, oy + py))
          local c = palette[shade]
          local _, _, _, alpha = data:getPixel(ox + px, oy + py)
          data:setPixel(ox + px, oy + py, c[1], c[2], c[3], alpha)
        end
      end
    end

    if rocket then
      local steel={{.44,.46,.48},{.36,.38,.40},{.27,.29,.31},{.18,.20,.22}}
      local raw=Assets.imageData(map.tileset.image)
      for _,tile in ipairs({2,3,4,8,9,10,11,12,13,14,18,19,24,25,26,27,28,29,30,36,37,40,41,42,43,44,45,46,52,53,56,57,58,59,60,64,65,67,68,69,74,75,76,77,78,80,81,86,87,88,89})do
        recolor(tile,steel,raw)
      end
      paint(1,{"BBBBBBBB","BBBBBBBB","BBBBBBBB","BBBBBBBB",
        "BBBBBBBB","BBBBBBBB","BBBBBBBB","BBBBBBBB"},
        {dark={.105,.12,.14},body={.25,.27,.30},light={.30,.32,.35},shadow={.18,.20,.23}})
      -- Spin arrows / stop pads (32/33/48/49/94) retain their original art.
    end
    if cave then applyCaveCommunityMaterials(map, total, paint, recolor) end

    if tilesetId == "OVERWORLD" and CommunityVisuals.customWalls() then
      local shapes = V.require("TileShape").forMap(map)
      local masonry = MATERIAL[CommunityVisuals.wallColor()] or MATERIAL.granite
      for tile = 0, total - 1 do
        local shape = shapes[tile]
        if shape and shape.class == "ledge" then paint(tile, ROCK_ART, masonry) end
      end
      -- Safe swatch used by the community retaining/pillar material family.
      paint(13, ROCK_ART, masonry)
      -- WALL2: the actual cliff source family. In the original OVERWORLD
      -- blockset tile 1 caps the speckled tile-17 mass; tile 30 is the
      -- northwest diagonal in block $3E. Other builders can draw those
      -- source UVs directly, bypassing ChunkMesher's wall classification.
      -- Remap the display copy only: structural analysis still sees the
      -- original source pixels, and DEFAULT keeps the original atlas.
      local cliffMasonry = {
        "DDDDDDDD", "DLLLLLLL", "DBBBBBBB", "DSSSSSSS",
        "DDDDDDDD", "LLLLDLLL", "BBBBDBBB", "SSSSDSSS",
      }
      paint(1, cliffMasonry, masonry)
      paint(17, cliffMasonry, masonry)
      paint(30, cliffMasonry, masonry)
      -- WALL3: the two inward cliff turns. Original blocks $2A and $2B
      -- use 19 and 53 respectively; neither occurs outside those cliff
      -- blocks. Cover both orientations in direct source-UV draws too.
      paint(19, cliffMasonry, masonry)
      paint(53, cliffMasonry, masonry)
    end

    if tilesetId == "OVERWORLD" and CommunityVisuals.customRoads() then
      paint(57, PATH_ART, PATH)
      paint(60, WOOD_ART, WOOD)
    end

    if tilesetId == "OVERWORLD" and CommunityVisuals.customCourtyards() then
      -- The connected fence samples the same full TEST435 timber tile as the
      -- bridge. Keep that material available even when ROADS & BRIDGES stays
      -- on Battle Art; TEST2's four flat swatches produced the plain tan fence.
      paint(60, WOOD_ART, WOOD)
      -- $5B is exclusive to Overworld block $55 and is therefore a stable
      -- courtyard material identity rather than a coordinate-specific fix.
      paint(91, COURT_ART, COURT)
    end

    if tilesetId == "OVERWORLD" and grassEnabled then
      if not cityGroundMap then paint(48, GRASS_ART, GRASS) end
      paint(44, GRASS_ART, mapId == "ROUTE_10" and ROUTE10_GRASS or GRASS)
      local tall = map.tileset.grassTile
      if type(tall) == "number" then tall = math.floor(tall) end
      if type(tall) == "number" and tall >= 0 and tall < total and tall ~= 44 then
        pcall(function()
          local raw = Assets.imageData(map.tileset.image)
          local rw, rh = raw:getDimensions()
          local ox, oy = (tall % perRow) * 8, math.floor(tall / perRow) * 8
          if ox + 7 >= rw or oy + 7 >= rh then return end
          for py = 0, 7 do
            for px = 0, 7 do
              local sourceR = raw:getPixel(ox + px, oy + py)
              local _, _, _, alpha = data:getPixel(ox + px, oy + py)
              local shade = shadeOf(sourceR)
              local c = mapId == "ROUTE_10" and (
                shade == 1 and ROUTE10_GRASS.light
                or shade == 2 and ROUTE10_GRASS.body
                or shade == 3 and ROUTE10_GRASS.shadow
                or ROUTE10_GRASS.dark) or TALL_GRASS[shade]
              data:setPixel(ox + px, oy + py, c[1], c[2], c[3], alpha)
            end
          end
        end)
      end
    end

    if mapId=="ROUTE_10" and V.require("TowerGarden").enabled() then
      paint(48,GRASS_ART,GRASS)
      -- Match the exit apron and garden donor even when GRASS is Battle Art.
      if CommunityVisuals.customCityGround() then paint(44,GRASS_ART,GRASS) end
    end
    if lavenderGround then applyLavenderCommunityMaterials(paint, legendaryCityGround) end

    if towerInterior then
      local okRaw, raw = pcall(Assets.imageData, map.tileset.image)
      if not okRaw then raw = nil end

      -- All full materials live beside the original tiles, never over them.
      -- Walls match the new smoky slab reference, the approved TEST123 black
      -- granite remains isolated on the counter, and the floor stays a quiet
      -- materially distinct honed stone at double resolution.
      local wallStyle = CommunityVisuals.towerWallStyle()
      local wallPath = TOWER_WALL_PATHS[wallStyle]
        or TOWER_WALL_PATHS.smoke_black
      local wall = Assets.imageData(wallPath)
      local ww, wh = wall:getDimensions()
      if ww ~= TOWER_WALL_SIZE or wh ~= TOWER_WALL_SIZE then
        error("Pokemon Tower wall texture must be 2048x2048")
      end
      data:paste(wall, w, 0, 0, 0, TOWER_WALL_SIZE, TOWER_WALL_SIZE)

      local counter = Assets.imageData(TOWER_COUNTER_PATH)
      local cw, ch = counter:getDimensions()
      if cw ~= TOWER_COUNTER_SIZE or ch ~= TOWER_COUNTER_SIZE then
        error("Pokemon Tower counter texture must be 1024x1024")
      end
      data:paste(counter, w + TOWER_WALL_SIZE, 0, 0, 0,
                 TOWER_COUNTER_SIZE, TOWER_COUNTER_SIZE)

      local counterTop = Assets.imageData(TOWER_COUNTER_TOP_PATH)
      local ctw, cth = counterTop:getDimensions()
      if ctw ~= TOWER_COUNTER_SIZE or cth ~= TOWER_COUNTER_SIZE then
        error("Pokemon Tower counter-top texture must be 1024x1024")
      end
      -- The last 1024px slot in the mobile-safe atlas column was unused.
      -- Keep the approved dark granite on the counter body and reserve this
      -- separate pearl quartz sheet for the upward-facing slab only.
      data:paste(counterTop, w + TOWER_WALL_SIZE, 3072,
                 0, 0, TOWER_COUNTER_SIZE, TOWER_COUNTER_SIZE)

      local floor = Assets.imageData(TOWER_FLOOR_PATH)
      local fw, fh = floor:getDimensions()
      if fw ~= TOWER_FLOOR_SIZE or fh ~= TOWER_FLOOR_SIZE then
        error("Pokemon Tower floor texture must be 2048x2048")
      end
      data:paste(floor, w, TOWER_WALL_SIZE,
                 0, 0, TOWER_FLOOR_SIZE, TOWER_FLOOR_SIZE)

      -- The counter occupies the top of the final 1024px atlas column. Reuse
      -- its otherwise empty lower bands for full-resolution stair and grave
      -- materials without increasing the 3200x4096 mobile-safe atlas edge.
      local stair = Assets.imageData(TOWER_STAIR_PATH)
      local sw, sh = stair:getDimensions()
      if sw ~= TOWER_DETAIL_SIZE or sh ~= TOWER_DETAIL_SIZE then
        error("Pokemon Tower stair texture must be 1024x1024")
      end
      data:paste(stair, w + TOWER_WALL_SIZE, TOWER_COUNTER_SIZE,
                 0, 0, TOWER_DETAIL_SIZE, TOWER_DETAIL_SIZE)

      local grave = Assets.imageData(TOWER_GRAVE_PATH)
      local gw, gh = grave:getDimensions()
      if gw ~= TOWER_DETAIL_SIZE or gh ~= TOWER_DETAIL_SIZE then
        error("Pokemon Tower grave texture must be 1024x1024")
      end
      data:paste(grave, w + TOWER_WALL_SIZE, TOWER_WALL_SIZE,
                 0, 0, TOWER_DETAIL_SIZE, TOWER_DETAIL_SIZE)

      -- Main walkable floor donor. ChunkMesher also routes the 5F healing
      -- zone ($22) through this material with a lighter stone tone, retaining
      -- the landmark without leaking the original vivid-blue tile in battle.
      paint(1, TOWER_FLOOR_ART, TOWER_FLOOR)

      -- Chamber ring and solid backing: preserve every arch, trim line and
      -- doorway pixel while translating the palette into cool grey granite.
      for _, tile in ipairs({9, 10, 25, 26, 32, 48}) do
        recolor(tile, TOWER_STONE, raw)
      end
      -- Tile $11 is the wall mass and TEST115's atlas-safe granite swatch.
      -- Its first row contains the exact dark/shadow/body/light samples used
      -- by ChunkMesher's raised stones, piers and cap courses.
      paint(17, ROCK_ART, TOWER_MASONRY)

      -- Existing per-cell 3D headstones keep their silhouettes and spacing;
      -- the cooler stone palette separates them from the warmer wall ring.
      for _, tile in ipairs({5, 6, 21, 22}) do
        recolor(tile, TOWER_GRAVE, raw)
      end

      -- The reception counter is stone in the supplied room reference. Its
      -- live voxel surfaces use ChunkMesher's continuous granite field; this
      -- matching atlas palette also covers any fallback face.
      for _, tile in ipairs({2, 18, 29, 30}) do
        recolor(tile, TOWER_COUNTER, raw)
      end

      -- Both stair drawings retain their restrained aged metal/wood tones.
      for _, tile in ipairs({3, 4, 19, 20, 11, 12, 27, 28}) do
        recolor(tile, TOWER_FIXTURE, raw)
      end
    end

    local function forestize(tile, raw)
      if type(tile) ~= "number" or tile < 0 or tile >= total or not raw then
        return
      end
      local ox, oy = (tile % perRow) * 8, math.floor(tile / perRow) * 8
      for py = 0, 7 do
        for px = 0, 7 do
          local r, g, b, alpha = data:getPixel(ox + px, oy + py)
          local brightest = math.max(r, g, b)
          local alreadyGreen = g >= r * 1.08 and g >= b * 1.12
          if alpha > 0 and brightest > .14 and not alreadyGreen then
            local shade = shadeOf(raw:getPixel(ox + px, oy + py))
            local c = FOREST_FOLIAGE[shade]
            data:setPixel(ox + px, oy + py, c[1], c[2], c[3], alpha)
          end
        end
      end
    end

    if forestEnabled then
      local shapes = V.require("TileShape").forMap(map)
      local okRaw, raw = pcall(Assets.imageData, map.tileset.image)
      if not okRaw then raw = nil end
      for tile = 0, total - 1 do
        local shape = shapes[tile]
        if shape and shape.class == "ground" then
          local variant = (tile % #FOREST_GROUND_ART) + 1
          paint(tile, FOREST_GROUND_ART[variant], FOREST_GROUND)
        elseif shape and (shape.class == "canopy"
                           or shape.class == "cylinder") then
          -- TEST97: retain the accepted tree palette, but neutralize the
          -- pale/tan source pixels that became suspended checker cubes when
          -- the same group was viewed from underneath or across the map edge.
          forestize(tile, raw)
        elseif shape and shape.class == "stump" then
          recolor(tile, FOREST_STONE, raw)
        end
      end
      -- Preserve the authored standing-grass silhouette used by both the
      -- terrain and Structures' blades; only fold it into the quieter forest
      -- palette so encounter patches no longer sit on neon checkerboards.
      local tall = map.tileset.grassTile
      if type(tall) == "number" then tall = math.floor(tall) end
      if type(tall) == "number" and tall >= 0 and tall < total then
        if raw then recolor(tall, FOREST_TALL_GRASS, raw) end
      end
    end

    local image = love.graphics.newImage(data)
    image:setFilter("nearest", "nearest")
    return { image=image, data=data, mapId=perMap ~= "" and perMap or nil }
  end)
  if not ok or not entry then return base, baked end
  community[key] = entry
  return entry.image, entry.data
end

-- The engine's tile-animation clock: TileRenderer's 60Hz counter, by
-- whatever route this build offers.
--
-- It matters that this is the ENGINE's number and not one of our own. The
-- 2D tile layer and this texture animate the same water off the same
-- counter, so toggling voxel mode mid-cycle continues the animation instead
-- of restarting or jumping it. A clock of our own would free-run against
-- the one the flat path is drawing from.
--
--   1. TileRenderer.animFrame(), where the build exports it.
--   2. else the counter itself, off tick()'s upvalues. It is a plain local
--      in that module, so this is exact and live -- the same number, not an
--      approximation of it. Reading engine internals is what this mod's
--      "engine_internals" permission is declared for, and this one is
--      read-only and entirely optional.
--   3. else wall time in 60Hz steps. Free-running, but the water moves,
--      which beats a frozen pond. Derived from absolute time rather than
--      accumulated deltas because animate() is called once per map in the
--      neighbourhood, so a per-call accumulator would run several times
--      too fast.
local clockUpvalue = nil        -- nil = not looked for yet, false = absent

local function findClockUpvalue()
  if not (debug and debug.getupvalue) then return false end
  if type(TileRenderer.tick) ~= "function" then return false end
  for i = 1, 32 do
    local ok, name, value = pcall(debug.getupvalue, TileRenderer.tick, i)
    if not (ok and name) then break end
    if name == "animFrame" and type(value) == "number" then return i end
  end
  return false
end

local function animFrame()
  if TileRenderer.animFrame then
    local ok, f = pcall(TileRenderer.animFrame)
    if ok and type(f) == "number" then return f end
  end
  if clockUpvalue == nil then clockUpvalue = findClockUpvalue() end
  if clockUpvalue then
    local ok, _, value = pcall(debug.getupvalue, TileRenderer.tick, clockUpvalue)
    if ok and type(value) == "number" then return value end
  end
  if love.timer and love.timer.getTime then
    return math.floor(love.timer.getTime() * 60)
  end
  return 0
end

TerrainAtlas._animFrame = animFrame   -- named for the suite

-- Greatest-common-divisor / least-common-multiple for one animation cycle.
local function gcd(a, b)
  while b ~= 0 do a, b = b, a % b end
  return a
end

local function lcm(a, b)
  if a == 0 or b == 0 then return 0 end
  return math.floor(a / gcd(a, b) * b)
end

-- A collision-free key for all animated specs at one engine animation frame.
local function stateKey(entry, frame)
  local parts = {}
  for i, spec in ipairs(entry.specs) do
    local n = spec.kind == "hshift" and #spec.offsets or #spec.sequence
    parts[i] = tostring(math.floor(frame / (spec.period or 20)) % n)
  end
  return table.concat(parts, ":")
end

-- Prebuild immutable whole-atlas textures for every distinct state in the
-- combined cycle. The vanilla water+flower cycle is only eight states
-- (160 logic frames / period 20), so this is tiny compared with the voxel
-- render targets and, crucially, performs ZERO GPU texture mutation while
-- the player is moving around.
local MAX_CYCLE_FRAMES = 4096
local MAX_PREBUILT_STATES = 64

local function releaseFrameImages(entry)
  local released = {}
  for _, image in pairs((entry and entry.frames) or {}) do
    if image and not released[image] and image.release then
      released[image] = true
      pcall(image.release, image)
    end
  end
end

local function buildAnimationFrames(entry)
  local cycle = 1
  for _, spec in ipairs(entry.specs) do
    local n = spec.kind == "hshift" and #spec.offsets or #spec.sequence
    cycle = lcm(cycle, (spec.period or 20) * n)
    if cycle > MAX_CYCLE_FRAMES then return false end
  end

  local representative = {}
  local stateCount = 0
  for frame = 0, cycle - 1 do
    local key = stateKey(entry, frame)
    if representative[key] == nil then
      representative[key] = frame
      stateCount = stateCount + 1
      if stateCount > MAX_PREBUILT_STATES then return false end
    end
  end

  local ok = pcall(function()
    for key, frame in pairs(representative) do
      local data = love.image.newImageData(entry.width, entry.height)
      data:paste(entry.base, 0, 0, 0, 0, entry.width, entry.height)

      for _, spec in ipairs(entry.specs) do
        local n = spec.kind == "hshift" and #spec.offsets or #spec.sequence
        patch(data, entry, spec,
              math.floor(frame / (spec.period or 20)) % n)
      end

      local image = love.graphics.newImage(data)
      image:setFilter("nearest", "nearest")
      entry.frames[key] = image
    end
  end)
  if not ok then
    -- A context loss or allocation failure can arrive halfway through the
    -- cycle. Do not leak the states that were already made while animate()
    -- retries the transient failure on a later frame.
    releaseFrameImages(entry)
    entry.frames = {}
    return nil
  end

  entry.frameCount = stateCount
  entry.cycleFrames = cycle
  return stateCount > 0
end

-- false = this can never work and asking again is waste; nil = it did not
-- work THIS time and might next. The caller latches the first and retries
-- the second (see attemptFailed).
local function newEntry(map, base, baked)
  local tileset = map.tileset
  local specs = specsFor(tileset)
  if not specs then return false end        -- nothing on this tileset animates
  if not (love.image and love.image.newImageData
          and love.graphics and love.graphics.newImage) then
    return false                            -- no pixel/texture access on this machine
  end
  -- the pixels the atlas texture was built from: our own SGB bake when we
  -- made one, else whatever the engine's renderer is drawing with. A
  -- readback can fail for one frame and work the next, so this is a
  -- retryable miss rather than a verdict.
  local src = baked or rendererPixels(map)
  if not src then return nil end

  local ok, entry = pcall(function()
    local w, h = src:getDimensions()
    -- A PRIVATE copy, always. The base may be the engine's own atlas, and
    -- the 2D path draws the static tile from it and overdraws the animated
    -- cell on top -- rewriting the slot underneath would animate the tile
    -- twice over there and corrupt every still frame of it.
    local data = love.image.newImageData(w, h)
    data:paste(src, 0, 0, 0, 0, w, h)
    -- v1.7.8 deliberately does NOT create a mutable texture here.
    -- Profiling showed that even tiny replacePixels uploads landed in the
    -- exact ~3 Hz frames where the game stalled for ~50 ms. Instead we keep
    -- the CPU base and prebuild every animation state as an immutable texture
    -- once. Runtime animation becomes pointer selection only.
    local e = {
      base = src,
      specs = specs, perRow = tileset.tilesPerRow or 16,
      frames = {}, frameCount = 0, step = nil, image = nil,
      width = w, height = h,
    }
    -- the frame files are raw grayscale; learn what the atlas did to the
    -- tile each one stands in for, so they land on the same colours
    local recolored = baked or (map.renderer and map.renderer.gbcAtlas)
    if recolored and not tileset.trueColor then
      local raw = Assets.imageData(tileset.image)
      e.shades = {}
      for _, spec in ipairs(specs) do
        if spec.kind == "frames" then
          e.shades[spec.tile] = learnShades(raw, src, spec.tile, e.perRow)
        end
      end
    end
    -- a frame-animated tile that resolved to the `flower` class stands as
    -- a 1px billboard (Structures.buildFlowers), and its slot in THIS
    -- copy carries only each frame's dark tones with the rest keyed to
    -- alpha -- see patch(). Gated on the resolved shape so a profile that
    -- pins the tile to something solid keeps a fully opaque slot, and on
    -- the tileset art being readable: without pixels Structures cannot
    -- have stood the billboard up (or synthesized the ground), and an
    -- alpha-keyed slot under an ordinary flat quad is a hole in the world.
    for _, spec in ipairs(specs) do
      if spec.kind == "frames" then
        local okCut, isFlower = pcall(function()
          local okA, art = pcall(Assets.imageData, tileset.image)
          if not (okA and art and art.getPixel) then return false end
          local sh = V.require("TileShape").forMap(map)[spec.tile]
          return sh ~= nil and sh.class == "flower"
        end)
        if okCut and isFlower then
          e.cut = e.cut or {}
          e.cut[spec.tile] = true
        end
      end
    end

    local built = buildAnimationFrames(e)
    if built ~= true then return built end
    -- Start on the engine's current animation state; animate() will refresh
    -- this pointer each call without touching GPU pixels.
    e.image = e.frames[stateKey(e, animFrame())]
    return e
  end)
  -- An exception during pixel decoding or texture creation can be a context
  -- transition and is retryable. The permanent `false` verdicts were already
  -- returned before the protected build (no animation or no GPU API).
  if not ok then return nil end
  return entry
end

-- Runtime animation is pointer-only from here on.

local function releaseAnimatedEntry(entry)
  if not entry then return end
  releaseFrameImages(entry)
end

-- The atlas for this frame: the static one when nothing animates (or a
-- prebuild is impossible), otherwise one immutable prebuilt animation frame.
-- No replacePixels / texture upload happens here.
function TerrainAtlas.animate(map, colors, base, baked)
  -- RED++ bakes a per-MAP atlas, so its animated copy is per map too and
  -- has to be evicted with the meshes (setLive below). CITY GROUND now has
  -- the same requirement: Lavender and Fuchsia share the OVERWORLD source
  -- atlas but can deliberately bake different ground into it, so their
  -- immutable animation frames must never be shared by visit order.
  local perMap = ((map.renderer and map.renderer.gbcAtlas)
      or CommunityVisuals.isCityGroundMap(map)
      or tostring(map.id or ""):upper() == "ROUTE_10") and map.id or nil
  local caveMaterial = map.tileset and map.tileset.id == "CAVERN"
    and CommunityVisuals.customCaves()
    and "#legendary-natural-cave" or ""
  local key = map.tileset.image .. "#a#" .. paletteKey(colors or {})
    .. "#community#" .. communityKey() .. caveMaterial .. (perMap or "") .. ((map.id or ""):match("^SAFARI_ZONE_") and ("#safari#"..map.id..":"..tostring(V.require("SafariReserve").enabled(map))) or "")
  local entry = animated[key]
  if entry == nil then
    entry = newEntry(map, base, baked)
    if entry then
      entry.mapId = perMap
      animated[key] = entry
    else
      -- false from newEntry is a verdict (nothing animates on this tileset,
      -- no pixel access at all); nil is a miss that may not repeat
      animated[key] = (entry == false) and false or attemptFailed(key)
    end
  end
  if not entry then return nil end

  local frame = animFrame()
  local step = stateKey(entry, frame)
  if step ~= entry.step then
    entry.step = step
    entry.image = entry.frames[step]
    if not entry.image then
      -- A custom animation exceeded/escaped the prebuilt cycle. Prefer the
      -- static atlas to a runtime upload hitch.
      return nil
    end
  end
  -- Only a frame that got all the way here counts as healthy. A partial or
  -- failed prebuild keeps its retry budget until an immutable state can
  -- actually be selected.
  if attempts[key] then attempts[key] = nil end
  return entry.image
end

-- Safari owns a local grass/dry-earth treatment, never a global palette swap.
local safariMaps={SAFARI_ZONE_CENTER=true,SAFARI_ZONE_EAST=true,SAFARI_ZONE_NORTH=true,SAFARI_ZONE_WEST=true}
-- Shared with the distant floor so it uses this terrain treatment too.
function TerrainAtlas.safariGroundColor(map)
 if map and safariMaps[map.id] and map.tileset and map.tileset.id=='FOREST' then
  if V.require("SafariReserve").enabled(map)then return {.23,.30,.15,1}end
  return {.48,.50,.265,1}
 end
end
local safariAtlases={}
local function releaseSafari(entry)
 if entry then entry.image:release();entry.data:release()end
end
local function safariGround(map,base,baked)
 if not(safariMaps[map.id]and map.tileset.id=='FOREST')then return base,baked end
 local legendary=V.require("SafariReserve").enabled(map)
 local old=safariAtlases[map.id]
 if old and old.base==base and old.legendary==legendary then return old.image,old.data end
 local ok,entry=pcall(function()
  local raw=baked
  if not raw then
   love.graphics.push('all');love.graphics.setShader();love.graphics.setDepthMode()
   raw=readback(base)
   love.graphics.pop()
  end
  if not raw then return nil end
  local w,h=raw:getDimensions();local data=love.image.newImageData(w,h);data:paste(raw,0,0,0,0,w,h)
  if not baked then raw:release()end
  local perRow=map.tileset.tilesPerRow or 16
  -- The shared FOREST canopy uses the drawing anchored at 4 and edge tile 35.
  -- Recolor its green pixels only in this Safari-owned atlas; retain bark,
  -- source pixel detail and the original tree palette on every other map.
  -- Hedge/edge variants retain their dark detail; tile 94 is flat grass.
  for _,tile in ipairs({0,48,32,52,55,57,72,73,74,80,81,82,83,95,
    4,5,6,7,20,21,22,23,35,36,37,38,39,53,54,
    13,79,84,85,86,87,88,89,90,91,92,93,94})do
   local sx,sy=tile%perRow*8,math.floor(tile/perRow)*8
   for y=0,7 do for x=0,7 do
    local rr,gg,bb,aa=data:getPixel(sx+x,sy+y)
    if tile==0 or tile==48 or tile==94 then
     local hsh=(x*37+y*61+x*y*11)%97
     local c={.48,.50,.265}
     if hsh<12 then c={.53,.46,.29}elseif hsh>88 then c={.61,.57,.34}elseif hsh<23 then c={.40,.44,.235}end
     data:setPixel(sx+x,sy+y,c[1],c[2],c[3],aa)
    elseif gg>rr*1.08 and gg>bb*1.3 then
     local v=math.max(rr,gg,bb)
     data:setPixel(sx+x,sy+y,.19+v*.33,.25+v*.31,.095+v*.19,aa)
    end
   end end
  end
  if legendary then
   -- Calm water retains the native animation/reflection route. The source
   -- atlas and every other FOREST map remain unchanged.
   local sx,sy=20%perRow*8,math.floor(20/perRow)*8
   for y=0,7 do for x=0,7 do
    local v=math.sin(x*.7+y*.9)*.012+math.cos(y*1.4-x*.3)*.007
    data:setPixel(sx+x,sy+y,.16+v,.29+v,.34+v,1)
   end end
  end
  local image=love.graphics.newImage(data);image:setFilter('nearest','nearest')
  return {base=base,image=image,data=data,legendary=legendary}
 end)
 if ok and entry then releaseSafari(old);safariAtlases[map.id]=entry;return entry.image,entry.data end
 return base,baked
end

function TerrainAtlas.forMap(map, colors)
  local base, baked = staticAtlas(map, colors)
  if not base then return nil end
  base, baked = communityAtlas(map, colors, base, baked)
  base, baked = safariGround(map, base, baked)
  local animatedBase=TerrainAtlas.animate(map, colors, base, baked) or base
  if V.require("SafariReserve").enabled(map)then return V.require("SafariMaterials").apply(map,animatedBase)end
  return V.require("DecorAtlas").apply(map,animatedBase)
end

-- Representative colour of one 4x4 border metatile AFTER the map's palette
-- bake.  This is used by the distant indoor underlay: the engine's void is a
-- border BLOCK, not a separately exposed RGB value, so the only faithful
-- colour source is the same finished atlas the terrain itself samples.
--
-- The most frequent opaque texel is intentionally used rather than an average:
-- an interior void block is mostly one background shade with a few edge/detail
-- pixels.  Averaging those details would invent a colour that does not exist in
-- the art and would leave a visible seam once the scene light multiplies it.
local borderColorCache = setmetatable({}, { __mode = "k" })
function TerrainAtlas.borderBlockColor(map, colors, blockId)
  if not (map and map.tileset and blockId ~= nil) then return nil end
  if blockId == false then return { 0, 0, 0, 1 } end

  local atlas, baked = staticAtlas(map, colors)
  if not atlas then return nil end
  local perImage = borderColorCache[atlas]
  if not perImage then
    perImage = {}
    borderColorCache[atlas] = perImage
  end
  if perImage[blockId] then return perImage[blockId] end

  local block = map.tileset.blocks and map.tileset.blocks[blockId + 1]
  if not block then return nil end
  local data = baked or readback(atlas)
  if not (data and data.getPixel) then return nil end

  local perRow = map.tileset.tilesPerRow or 16
  local counts, bestKey, bestCount, bestLum = {}, nil, -1, math.huge
  for _, tile in ipairs(block) do
    local sx, sy = (tile % perRow) * 8, math.floor(tile / perRow) * 8
    for y = 0, 7 do
      for x = 0, 7 do
        local r, g, b, a = data:getPixel(sx + x, sy + y)
        if a > 0 then
          local R = math.floor(r * 255 + 0.5)
          local G = math.floor(g * 255 + 0.5)
          local B = math.floor(b * 255 + 0.5)
          local key = R * 65536 + G * 256 + B
          local n = (counts[key] or 0) + 1
          counts[key] = n
          local lum = R * 0.299 + G * 0.587 + B * 0.114
          if n > bestCount or (n == bestCount and lum < bestLum) then
            bestKey, bestCount, bestLum = key, n, lum
          end
        end
      end
    end
  end
  if not bestKey then return nil end

  local R = math.floor(bestKey / 65536)
  local G = math.floor(bestKey / 256) % 256
  local B = bestKey % 256
  local out = { R / 255, G / 255, B / 255, 1 }
  perImage[blockId] = out
  return out
end

-- The image a character model should texture from under an SGB palette.
--
-- In the 2D SGB modes, sprites are colorized by the screen-space
-- shade-remap shader at blit time -- the sheet itself stays grayscale. The
-- voxel canvas composites 1:1 with no shader pass, so a model textured
-- straight from the sheet renders in raw DMG grays (a black-and-gray
-- character standing in a colored room). Bake instead, exactly like the
-- terrain above: one recolored sheet per (sheet, palette), remapped
-- through the same cutoffs the shader uses, alpha preserved so OBJ color
-- 0 stays transparent. Falls back to nil (caller keeps its texture) when
-- pixels are unreachable.
function TerrainAtlas.forSprite(path, colors)
  if not (colors and love.image and love.image.newImageData) then
    return nil
  end
  local key = "spr:" .. path .. "#" .. paletteKey(colors)
  if cache[key] ~= nil then return cache[key] or nil end

  local ok, img = pcall(function()
    local src = Assets.imageData(path)
    local w, h = src:getDimensions()
    local out = love.image.newImageData(w, h)
    for y = 0, h - 1 do
      for x = 0, w - 1 do
        local r, g, b, a = src:getPixel(x, y)
        r, g, b, a = TileRenderer.recolorSample(r, g, b, a, colors)
        out:setPixel(x, y, r, g, b, a)
      end
    end
    local image = love.graphics.newImage(out)
    image:setFilter("nearest", "nearest")
    return image
  end)
  cache[key] = ok and img or false
  return cache[key] or nil
end

-- Release the animated copies of maps outside `live` (a set of map ids),
-- the same neighbourhood ChunkMesher bounds its meshes to and called from
-- the same place. Per-map RED++ and CITY GROUND copies are held this way;
-- the rest are keyed by tileset and palette, of which a session sees a handful.
-- Without this a cross-region trek accumulates one atlas and one texture
-- per map ever entered, and each pins the engine's own baked ImageData
-- alive behind it.
function TerrainAtlas.setLive(live)
  V.require("DecorAtlas").setLive(live)
  V.require("SafariMaterials").setLive(live)
  for id,entry in pairs(safariAtlases)do if not live[id]then releaseSafari(entry);safariAtlases[id]=nil end end
  for key, entry in pairs(animated) do
    if entry and entry.mapId and not live[entry.mapId] then
      releaseAnimatedEntry(entry)
      animated[key] = nil
    end
  end
  for key, entry in pairs(community) do
    if entry and entry.mapId and not live[entry.mapId] then
      community[key] = nil
    end
  end
end

function TerrainAtlas.invalidate()
  V.require("SafariMaterials").invalidate()
  for _,entry in pairs(safariAtlases)do releaseSafari(entry)end
  safariAtlases={}
  cache = {}
  cacheData = {}
  community = {}
  attempts = {}
  borderColorCache = setmetatable({}, { __mode = "k" })
  for _, entry in pairs(animated) do
    releaseAnimatedEntry(entry)
  end
  animated = {}
end

Assets.register(TerrainAtlas.invalidate)

return TerrainAtlas
