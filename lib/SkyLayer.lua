-- The SKY: clouds that drift, and birds that cross it.
-- payload-version: 28
--
-- Two layers over the outdoor world, both purely atmospheric and neither
-- touching anything the game can feel.
--
-- CLOUDS are a single large plane above the world wearing a tiling cloud
-- texture generated here at load -- blobby value noise quantised into
-- 4px blocks, so it reads as Game Boy cloud rather than as a photograph
-- -- scrolled slowly by wall clock.  Centred on the player like the
-- horizon, for the same reason: sky you can walk under but never reach.
--
-- BIRDS are flocks of camera-facing billboards high overhead, wearing
-- frames DERIVED on the player's own machine by this mod's asset
-- transform (transform_birds.lua) from their imported cache.  No sprite
-- ships here and the cache is never read at runtime: if a species could
-- not be derived, it simply never flies.  Gen 1 gives one frame per
-- creature, so the transform bakes a second -- the silhouette squeezed
-- about its middle -- and the two alternate as a wingbeat.
--
-- A GROUND FLOCK is the sky's counterpart down here: a scatter of small
-- birds pecking about on open ground, which hold their nerve until you
-- get close and then FLUSH -- all at once, upward and away, climbing out
-- of sight.  They only settle where there is room to (a clear patch of
-- walkable cells, checked once when the flock lands), and only now and
-- then, so coming over a rise and putting up a dozen Spearow stays an
-- event rather than scenery.
--
-- RAINBOWS belong to the moment a shower ENDS, and they belong opposite
-- the sun -- that is not decoration, it is where the light actually comes
-- back from.  DayNight.bodyAt gives the sun's angle, so the arc is hung
-- anti-solar: turn your back on the sun after the rain and it is there,
-- face the sun and it is not.  It fades up over a few seconds, holds, and
-- fades out; and it only appears by day, because a moonbow is a lovely
-- thing that almost nobody would read as intentional.
--
-- AIRCRAFT.  Two things cross the high sky, both drawn in code and both
-- deliberately rare enough to be an event.  A PLANE is a four-pixel
-- silhouette at the top of the sky laying a CONTRAIL -- a line of puffs
-- that widen and fade behind it, so you notice the trail first and go
-- looking for what made it.  A BLIMP is slower, lower and much rarer: a
-- fat ellipse with a gondola, drifting across an afternoon.  Neither
-- belongs in 1996 Kanto, strictly speaking, and both look wonderful.
--
-- STARS come out after dark: a generated field on a high plane -- sparse
-- points at four brightnesses, plus a soft nebula smear in one quadrant
-- so the sky has somewhere to look -- with a couple of dozen individual
-- TWINKLERS drawn over it that pulse on their own clocks, because a
-- static texture alone reads as wallpaper.  Once in a while a SHOOTING
-- STAR crosses: a streak stretched along its own heading, gone in under
-- a second, which is the whole appeal.
--
-- Flocks are recycled around the player: one drifts out of range, another
-- enters from the far side, so the sky is never empty and never
-- accumulates.  Mostly the common flyers; rarely -- about one flock in
-- forty -- something that should not be there at all, alone and higher
-- and slower than the rest, which is the entire point of a rare bird.

local V = ...

local Voxel3D = V.require("Voxel3D")
local Mat4 = V.require("Mat4")
-- The first-person rig, if this build has one.  absol89's battle-art fork
-- is based on Dramatic Shape 1.3.0, which predates the rig entirely --
-- and an unguarded require there would fail at load and take this whole
-- module with it.  Without a rig the blend reads as zero, which means the
-- diorama's cutaway view: exactly right for a build that has no first
-- person to be inside of.
local okFP, FirstPerson = pcall(V.require, "FirstPerson")
if not (okFP and type(FirstPerson) == "table") then
  FirstPerson = { yaw = 0, blendEased = function() return 0 end }
end
local okDN, DayNight = pcall(V.require, "DayNight")
local CommunityVisuals = V.require("CommunityVisuals")

local Sky = {}

-- ------- clouds
-- Three decks rather than one sheet.  A single plane reads as flat
-- because it IS flat; stacking thin ones at different heights, tile
-- scales and drift speeds gives parallax between them, which is what the
-- eye reads as depth and weather.  Highest is thinnest and slowest --
-- cirrus; lowest is densest and quickest -- the stuff about to rain on
-- you.
local CLOUD_DECKS = {
  { y = 210, tiles = 4,  wind = 0.011, alpha = 0.85, cut = 0.60, seed = 11 },
  { y = 300, tiles = 7,  wind = 0.006, alpha = 0.62, cut = 0.66, seed = 29 },
  { y = 410, tiles = 11, wind = 0.003, alpha = 0.38, cut = 0.72, seed = 47 },
}
-- The deck is far wider than the eye can resolve, and fades out toward
-- its rim rather than ending.  A single quad ends at an edge, and that
-- edge is a straight line across the sky -- which is exactly what it
-- looked like.  Each deck is therefore built as concentric BANDS of
-- quads, drawn with falling alpha, so the cloud thins into the blue.
local CLOUD_SPAN = 7200      -- plane size; well past anything visible
local CLOUD_BANDS = 5        -- rings from centre to rim
local CLOUD_CELLS = 24       -- grid resolution across the whole plane
local BAND_FADE = { 1.0, 0.92, 0.68, 0.36, 0.12 }
-- A FLAT deck, seen from the ground, sinks toward the horizon as it
-- recedes -- so its far rim ends up level with the skyline and you get
-- lone clouds sitting on the mountains.  Curving the deck upward with
-- distance keeps the whole sheet overhead where cloud belongs, which is
-- also what the real sky does: you never see the underside of a cloud
-- meet the horizon, the horizon hides it.
local CLOUD_LIFT = 900       -- how far the rim rises above the centre
local CLOUD_TEX = 128        -- generated texture, px
local NIGHT_CLOUD = 0.22     -- how much cloud survives the dark

-- TEST110 / CLEAN SKY LAYER ISOLATION
-- The user runs a separate weather mod for smooth clouds/rain. Dramatic Shape's
-- own SkyLayer also draws three deliberately chunky Game-Boy-style cloud decks
-- (4px-quantised cloud texture over concentric curved mesh bands). Those decks
-- are the large block/dot/ring structures visible when looking upward. Disable
-- ONLY these built-in cloud decks; keep the base Sky.lua gradient, day/night,
-- stars, birds, aircraft, rainbow and every world/battle system unchanged.
local TEST110_DISABLE_BUILTIN_CLOUD_DECKS = true

-- ------- birds
local COMMON = { "pidgey", "pidgeotto", "spearow", "fearow", "zubat",
                 "golbat", "butterfree", "venomoth", "farfetchd" }
local RARE = { "articuno", "zapdos", "moltres", "aerodactyl", "dragonite" }
local RARE_CHANCE = 0.025
local FLOCKS = 5
local BIRD_MIN_Y, BIRD_MAX_Y = 260, 470   -- higher: detail should not read
local BIRD_KEEP_OUT = 260    -- never closer than this horizontally
local RANGE = 1500           -- flock recycles beyond this from the player
local FLAP_HZ = 4.5

-- ------- aircraft
-- Sizes are angular, not absolute.  A 26-unit sprite at 620 up and 2200
-- away subtends about half a degree -- one pixel -- which is why the
-- planes were "missing": they were being drawn, and were too small to
-- see.  These are picked so a plane reads as a small but unmistakable
-- shape and the blimp as a proper object in the sky.
local PLANE_CHANCE = 0.02    -- per second: roughly one a minute
local PLANE_Y = 470
local PLANE_DIST = 1400
local PLANE_SIZE = 95
local BLIMP_CHANCE = 0.0022  -- per second: genuinely rare
local BLIMP_Y = 300
local BLIMP_DIST = 950
local BLIMP_SIZE = 230
local TRAIL_EVERY = 0.16     -- seconds between contrail puffs
local TRAIL_LIFE = 16

-- ------- night sky
local STAR_Y = 520
-- TEST392: keep the same texel-to-world scale as TEST391 while doubling the
-- plane in both axes. The former half-span (1700) put its far edge at nearly
-- the same apparent elevation as Backdrop's mountain crown, exposing a ruler-
-- straight star cutoff. A 3400 half-span places the edge well below/behind the
-- 760-unit panorama without another mesh, draw call or larger texture.
local STAR_SPAN = 6800
local STAR_TEX = 256
local STAR_TILES = 6
local TWINKLERS = 24
local TWINKLE_R = 700        -- dome radius for the animated stars
local SHOOT_CHANCE = 0.05    -- per second, after dark
local FADE_TIME = 2.5        -- seconds to fade the field in or out

local starMesh, starImg, starDot = nil, nil, nil
local planeImg, blimpImg, puffImg = nil, nil, nil
local planes, blimps, trails = nil, nil, nil

-- ------- the ground flock
local FLOCK_CHANCE = 0.006    -- per second, when there is none about
local FLOCK_MIN, FLOCK_MAX = 5, 11
local FLOCK_CLEAR = 2         -- cells of clear ground needed each way
local FLOCK_NEAR, FLOCK_FAR = 90, 260   -- where a flock may settle
local FLUSH_DIST = 58         -- how close you get before they go up
local FLOCK_LIFE = 90
local ground = nil            -- { birds = {...}, flushed = bool }


-- ------- rainbows
-- It hangs about for two and a half minutes rather than one: showers are
-- four to fifteen minutes apart, so a short-lived bow is one most people
-- will simply never be looking the right way for.
local RAINBOW_LIFE = 150     -- seconds it hangs about after the rain
local RAINBOW_FADE = 4       -- seconds to come up and to go
local RAINBOW_DIST = 1500    -- far enough to sit behind everything
-- The bow's art is a half-disc springing from the BOTTOM edge of its
-- texture, but a quad is positioned by its CENTRE -- so translating to
-- the height of the arc's feet buried five hundred units of it below the
-- ground and left the bow invisible.  The centre must sit half the
-- quad's height above the feet.
-- FEET well below ground: the legs continue down BEHIND the terrain and
-- the depth test crops them, instead of the arc stopping in mid-air at
-- the texture's bottom edge.
local RAINBOW_FEET = -160
-- The bow is ABSOLUTE: bent around a partial cylinder so that, with its
-- position and facing fixed once when the shower ends, some part of it
-- still faces you from most directions. A flat quad cannot do this -- it
-- either swivels to track the player or foreshortens to a sliver.
local RAINBOW_CURVE = 0.9
local rainbowMesh = nil
local RAINBOW_SIZE = 2200    -- a bow should span the sky, not sit in it

local function bowShell()
  if rainbowMesh ~= nil then return rainbowMesh or nil end
  local ok, mesh = pcall(function()
    local SLATS = 14
    -- radius chosen so the arc's CHORD spans the bow's width
    local R = (RAINBOW_SIZE / 2) / math.sin(RAINBOW_CURVE / 2)
    local h = RAINBOW_SIZE * 0.52 - RAINBOW_FEET
    local verts, idx, quads = {}, {}, 0
    for side = 0, 1 do
      for i = 0, SLATS - 1 do
        local a0 = (-0.5 + i / SLATS) * RAINBOW_CURVE
        local a1 = (-0.5 + (i + 1) / SLATS) * RAINBOW_CURVE
        local u0, u1 = i / SLATS, (i + 1) / SLATS
        if side == 1 then a0, a1 = a1, a0; u0, u1 = u1, u0 end
        local x0, z0 = math.sin(a0) * R, -math.cos(a0) * R + R
        local x1, z1 = math.sin(a1) * R, -math.cos(a1) * R + R
        verts[#verts + 1] = { x0, h, z0, u0, 0, 1 }
        verts[#verts + 1] = { x1, h, z1, u1, 0, 1 }
        verts[#verts + 1] = { x1, 0, z1, u1, 1, 1 }
        verts[#verts + 1] = { x0, 0, z0, u0, 1, 1 }
        Voxel3D.pushQuad(idx, quads)
        quads = quads + 1
      end
    end
    return Voxel3D.newMesh(verts, idx)
  end)
  rainbowMesh = (ok and mesh) or false
  return rainbowMesh or nil
end
local rainbowImg = nil
local bowAnchor = nil
local twinkles, shooters = nil, nil
local nightAmt = 0

local decks = nil            -- { { mesh, img }, ... }
local birdMesh, pics, flocks = nil, nil, nil
local lastT = nil

local function status(s) _G.__ds_sky_status = s end
status("loaded; awaiting the first outdoor frame")


-- Draw blocks run inside this rather than a bare pcall.  Every one of
-- them changes graphics state -- colour, alpha, depth mode -- and a bare
-- pcall that throws midway leaves that state set for the REST OF THE
-- FRAME.  Anything drawn after us then inherits it: a stray alpha makes
-- another mod's sprites invisible, a stray depth mode makes them sort
-- wrongly, and the fault looks like theirs.  push("all")/pop() restores
-- the lot whatever happens inside.
local function guarded(fn)
  -- headless, or a driver without a graphics stack: just run it
  local g = love and love.graphics
  if not (g and g.push and g.pop) then return pcall(fn) end
  local pushed = pcall(g.push, "all")
  pcall(fn)
  if pushed then pcall(g.pop) end
end

local OPEN_AIR_TILESETS = {
  OVERWORLD = true, FOREST = true, PLATEAU = true, SHIP_PORT = true,
}

local function config()
  return {
    clouds = true,
    stars = true,
    birds = false,
    aircraft = false,
    rainbows = false,
    groundflock = false,
  }
end

-- The voxel shader DISCARDS any texel under half alpha and draws the rest
-- fully opaque (see Voxel3D: "if (p.a < 0.5) discard"), so this renderer
-- cannot express a soft edge at all -- every gradient sprite becomes a
-- hard blob, which is why the glows looked like cut-out squares.  The
-- answer is the one the hardware this game came from used: ORDERED
-- DITHER.  Partial coverage becomes a stipple of fully-on and fully-off
-- texels, which survives the discard and looks like Game Boy art rather
-- than like a mistake.
local BAYER = {
  {  0,  8,  2, 10 },
  { 12,  4, 14,  6 },
  {  3, 11,  1,  9 },
  { 15,  7, 13,  5 },
}
local function dither(x, y, a)
  if a >= 0.999 then return 1 end
  if a <= 0.001 then return 0 end
  local threshold = (BAYER[(y % 4) + 1][(x % 4) + 1] + 0.5) / 16
  return (a > threshold) and 1 or 0
end

local function isNight()
  -- Dramatic Shape has no isNight(); what it has is bodyAt(t), whose
  -- third return says whether the body in the sky is the MOON.  That is
  -- the honest answer to "is it night", and it follows whichever mode the
  -- player is in -- pinned, cycling, or synced to their own clock.
  if okDN and DayNight and DayNight.bodyAt then
    local ok, moon = pcall(function()
      local t = DayNight.time and DayNight.time() or 0
      local _, _, isMoon = DayNight.bodyAt(t)
      return isMoon
    end)
    if ok and moon ~= nil then return moon and true or false end
  end
  -- without the module at all, fall back to the wall clock
  local okD, h = pcall(function() return tonumber(os.date("%H")) end)
  if okD and h then return (h < 6 or h >= 20) end
  return false
end

local function isOutdoor(map)
  local def = map and map.def
  if not def then return false end
  if okDN and DayNight and DayNight.isCanopy then
    local okC, canopy = pcall(DayNight.isCanopy, map)
    if okC and canopy then return false end
  end
  local tid = def.tileset or (map.tileset and map.tileset.id)
  if tid and OPEN_AIR_TILESETS[tid] then return true end
  local ok, outdoor = pcall(function()
    local Map = require("src.world.Map")
    return Map.isOutdoor and Map.isOutdoor(def)
  end)
  if ok and outdoor ~= nil then return outdoor end
  local conns = def.connections
  return (conns and next(conns) ~= nil) and true or false
end

local function now()
  local ok, t = pcall(function() return love.timer.getTime() end)
  return ok and t or 0
end

-- ------- the cloud sheet, generated once.
-- Value noise summed over three octaves, then hard-thresholded: soft
-- gradients would read as fog, and this world has no fog in its sky.

local function makeClouds(cut, seed)
  local okGen, img = pcall(function()
    math.randomseed(seed)
    local data = love.image.newImageData(CLOUD_TEX, CLOUD_TEX)
    local seed = {}
    local G = 16                      -- noise lattice
    for i = 0, G * G - 1 do seed[i] = math.random() end
    local function lat(x, y)
      return seed[((y % G) * G + (x % G))] or 0
    end
    local function smooth(x, y, freq)
      local fx, fy = x * freq, y * freq
      local x0, y0 = math.floor(fx), math.floor(fy)
      local tx, ty = fx - x0, fy - y0
      tx = tx * tx * (3 - 2 * tx)
      ty = ty * ty * (3 - 2 * ty)
      local a = lat(x0, y0) + (lat(x0 + 1, y0) - lat(x0, y0)) * tx
      local b = lat(x0, y0 + 1) + (lat(x0 + 1, y0 + 1) - lat(x0, y0 + 1)) * tx
      return a + (b - a) * ty
    end
    for y = 0, CLOUD_TEX - 1 do
      for x = 0, CLOUD_TEX - 1 do
        -- sample on a 4px grid: chunky pixels, not smooth cloud
        local sx, sy = math.floor(x / 4) * 4, math.floor(y / 4) * 4
        local n = smooth(sx, sy, 0.10) * 0.6
                + smooth(sx, sy, 0.21) * 0.3
                + smooth(sx, sy, 0.43) * 0.1
        local a, shade = 0, 1
        if n > cut then a, shade = 0.92, 1                 -- body
        elseif n > cut - 0.07 then a, shade = 0.72, 0.88   -- edge
        elseif n > cut - 0.12 then a, shade = 0.35, 0.80   -- wisp
        end
        data:setPixel(x, y, shade, shade, shade, dither(x, y, a))
      end
    end
    local i = love.graphics.newImage(data)
    i:setWrap("repeat", "repeat")
    i:setFilter("nearest", "nearest")
    return i
  end)
  return okGen and img or nil
end

-- The star field: points at four brightnesses so the sky has depth, and
-- a nebula smear built from the same value noise as the clouds but tinted
-- and kept faint -- it should be something you notice on the second look.
local function makeStars()
  local ok, img = pcall(function()
    local data = love.image.newImageData(STAR_TEX, STAR_TEX)
    -- TEST111 / CLEAN NIGHT SKY
    -- Keep the individual stars but remove the chunky generated nebula smear.
    -- The nebula sampled noise on a 4px grid and dithered its alpha, producing
    -- the large dotted rectangular islands still visible after cloud decks were
    -- disabled in TEST110. Start transparent; sparse stars are added below.
    for y = 0, STAR_TEX - 1 do
      for x = 0, STAR_TEX - 1 do
        data:setPixel(x, y, 0, 0, 0, 0)
      end
    end
    -- stars: sparse, four brightnesses, never adjacent
    -- TEST393: retain a rich sky but give the gradient more breathing room.
    -- 210 -> 240 is a restrained 12.5% population reduction, not a sparse-
    -- sky rewrite. The procedural texture size and six-repeat world scale stay
    -- locked, so this changes density only.
    local count = math.floor(STAR_TEX * STAR_TEX / 240)
    for _ = 1, count do
      local x = math.random(0, STAR_TEX - 1)
      local y = math.random(0, STAR_TEX - 1)
      local roll = math.random()
      -- Half as many maximum-brightness cross stars. Mid/faint stars remain
      -- close to TEST392's distribution, preserving depth without the handful
      -- of oversized marks dominating the frame.
      local v = (roll > 0.985 and 1.0) or (roll > 0.88 and 0.82)
             or (roll > 0.58 and 0.62) or 0.44
      data:setPixel(x, y, v, v, v * 0.96, dither(x, y, v))
      -- the brightest get a single-pixel cross, which is what makes a
      -- pixel-art star read as a star rather than as dust
      if roll > 0.985 then
        for _, d in ipairs({ { 1, 0 }, { -1, 0 }, { 0, 1 }, { 0, -1 } }) do
          local nx, ny = (x + d[1]) % STAR_TEX, (y + d[2]) % STAR_TEX
          data:setPixel(nx, ny, v * 0.5, v * 0.5, v * 0.5,
                        dither(nx, ny, v * 0.45))
        end
      end
    end
    local i = love.graphics.newImage(data)
    i:setWrap("repeat", "repeat")
    i:setFilter("nearest", "nearest")
    return i
  end)
  return ok and img or nil
end

-- a single star: a bright centre with a faint cross, which is what makes
-- a handful of pixels read as a star instead of a smudge
-- The bow itself: a broad arc of seven bands, brightest in the middle of
-- the band and soft at both rims, drawn once into a texture.  The bands
-- run red on the OUTSIDE, as they do in the sky.
-- Where the sun is, for anything that needs to point at or away from it.
-- Two traps, both of which this mod fell into: bodyAt speaks DEGREES, and
-- its elevation is the TRUE one, while Dramatic Shape hangs the visible
-- disc on a squashed arc (ELEV_SQUASH) because the real noon sun would
-- sit far above any frame.  The shadow code settles the bearing: shearAt
-- casts along (-cos, -sin), so the light is at (+cos, +sin).
local function sunAngle()
  if not (okDN and DayNight and DayNight.bodyAt) then return 0, 0.15, false end
  local ok, az, el, moon = pcall(function()
    local th, e, m = DayNight.bodyAt(DayNight.time and DayNight.time() or 0)
    return th, e, m
  end)
  if not ok or type(az) ~= "number" then return 0, 0.15, false end
  local squash = DayNight.ELEV_SQUASH or 0.14
  return math.rad(az), math.rad((el or 35) * squash), moon and true or false
end

local function makeRainbow()
  local ok, img = pcall(function()
    -- Bigger and softer than a drawn arch: the bands BLEED into one
    -- another instead of stepping, the whole thing peaks at less than
    -- half opacity, and both rims dissolve over several pixels -- which
    -- is what makes a bow look like light hanging in the air rather than
    -- a painted rainbow.
    local W, H = 256, 128
    local data = love.image.newImageData(W, H)
    local BANDS = {
      { 0.92, 0.42, 0.40 }, { 0.94, 0.66, 0.40 }, { 0.92, 0.88, 0.50 },
      { 0.52, 0.84, 0.56 }, { 0.48, 0.72, 0.94 }, { 0.52, 0.54, 0.90 },
      { 0.70, 0.52, 0.88 },
    }
    local cx, cy = (W - 1) / 2, H - 1
    local outer, inner = H - 3, H - 40    -- a far broader band
    for y = 0, H - 1 do
      for x = 0, W - 1 do
        local dx = (x - cx) / cx * outer
        local dy = (cy - y)
        local r = math.sqrt(dx * dx + dy * dy)
        local a, cr, cg, cb = 0, 0, 0, 0
        if r <= outer and r >= inner then
          local f = (outer - r) / (outer - inner)   -- 0 outside, 1 inside
          -- blend between neighbouring bands rather than stepping
          local pos = f * (#BANDS - 1) + 1
          local i0 = math.max(1, math.min(#BANDS - 1, math.floor(pos)))
          local mix = pos - i0
          local c0, c1 = BANDS[i0], BANDS[i0 + 1]
          cr = c0[1] + (c1[1] - c0[1]) * mix
          cg = c0[2] + (c1[2] - c0[2]) * mix
          cb = c0[3] + (c1[3] - c0[3]) * mix
          -- A smooth bell across the band: nothing at either rim, and
          -- never fully opaque even at its heart.  This used to peak at
          -- 0.42 and then be DRAWN at 0.42 as well -- the two multiplied
          -- to about a sixth, which is not ethereal, it is absent.
          local edge = math.sin(f * math.pi)
          a = 0.85 * edge * edge
        end
        data:setPixel(x, y, cr, cg, cb, a)
      end
    end
    local i = love.graphics.newImage(data)
    i:setFilter("nearest", "nearest")
    return i
  end)
  return ok and img or nil
end

local function makeStarDot()
  local ok, img = pcall(function()
    local S = 8
    local data = love.image.newImageData(S, S)
    for y = 0, S - 1 do
      for x = 0, S - 1 do
        local dx, dy = math.abs(x - 3.5), math.abs(y - 3.5)
        local a = 0
        if dx < 1.5 and dy < 1.5 then a = 1
        elseif (dx < 0.6 and dy < 3.2) or (dy < 0.6 and dx < 3.2) then
          a = 0.5
        end
        data:setPixel(x, y, 1, 1, 0.95, dither(x, y, a))
      end
    end
    local i = love.graphics.newImage(data)
    i:setFilter("nearest", "nearest")
    return i
  end)
  return ok and img or nil
end

-- a plane: a stub-winged silhouette, dark against the sky
local function makePlane()
  local ok, img = pcall(function()
    local S = 16
    local data = love.image.newImageData(S, S)
    local function put(x, y, a)
      if x >= 0 and y >= 0 and x < S and y < S then
        data:setPixel(x, y, 0.16, 0.17, 0.21, a or 1)
      end
    end
    for x = 3, 12 do put(x, 8) end          -- fuselage
    put(13, 8); put(2, 7); put(2, 9)        -- nose and tailplane
    for x = 6, 9 do put(x, 6); put(x, 10) end   -- wings
    put(5, 7); put(5, 9)
    put(3, 6); put(3, 5)                    -- fin
    local i = love.graphics.newImage(data)
    i:setFilter("nearest", "nearest")
    return i
  end)
  return ok and img or nil
end

-- a blimp: envelope, fins and a little gondola slung beneath
local function makeBlimp()
  local ok, img = pcall(function()
    local S = 16
    local data = love.image.newImageData(S, S)
    local SKIN = { 0.86, 0.84, 0.78 }
    local DARK = { 0.34, 0.33, 0.36 }
    local TRIM = { 0.74, 0.28, 0.30 }
    local function put(x, y, c, a)
      if x >= 0 and y >= 0 and x < S and y < S then
        data:setPixel(x, y, c[1], c[2], c[3], a or 1)
      end
    end
    for x = 2, 13 do
      local dx = (x - 7.5) / 6
      local half = math.floor(3 * math.sqrt(math.max(0, 1 - dx * dx)) + 0.5)
      for y = 7 - half, 7 + half do
        put(x, y, (y == 7 - half or y == 7 + half) and DARK or SKIN)
      end
    end
    for y = 5, 9 do put(1, y, DARK) end        -- tail fins
    put(0, 7, DARK)
    for x = 6, 9 do put(x, 7, TRIM) end        -- a stripe along the flank
    for x = 6, 9 do put(x, 11, DARK) end       -- gondola
    put(6, 10, DARK); put(9, 10, DARK)
    local i = love.graphics.newImage(data)
    i:setFilter("nearest", "nearest")
    return i
  end)
  return ok and img or nil
end

-- a contrail puff: soft, white, and nothing but alpha
local function makePuff()
  local ok, img = pcall(function()
    local S = 8
    local data = love.image.newImageData(S, S)
    for y = 0, S - 1 do
      for x = 0, S - 1 do
        local dx, dy = (x - 3.5) / 3.5, (y - 3.5) / 3.5
        local d = math.sqrt(dx * dx + dy * dy)
        local a = (d < 0.45 and 0.85) or (d < 0.75 and 0.45)
               or (d < 1.0 and 0.18) or 0
        data:setPixel(x, y, 1, 1, 1, dither(x, y, a))
      end
    end
    local i = love.graphics.newImage(data)
    i:setFilter("nearest", "nearest")
    return i
  end)
  return ok and img or nil
end

local function makeStarMesh()
  local h, s = STAR_Y, STAR_SPAN * 0.5
  local u = STAR_TILES
  local verts = {
    { -s, h, -s, 0, 0, 1 }, {  s, h, -s, u, 0, 1 },
    {  s, h,  s, u, u, 1 }, { -s, h,  s, 0, u, 1 },
  }
  local indexMap = {}
  Voxel3D.pushQuad(indexMap, 0)
  return Voxel3D.newMesh(verts, indexMap)
end

-- fixed points on a dome: the same stars twinkle in the same places
local function makeTwinkles()
  local out = {}
  for i = 1, TWINKLERS do
    local a = (i / TWINKLERS) * math.pi * 2 + (i % 3) * 0.4
    local elev = 0.25 + ((i * 37) % 100) / 100 * 0.55
    out[i] = {
      x = math.cos(a) * TWINKLE_R * (1 - elev * 0.4),
      z = math.sin(a) * TWINKLE_R * (1 - elev * 0.4),
      y = STAR_Y * (0.45 + elev * 0.5),
      size = 6 + ((i * 13) % 7),
      rate = 0.7 + ((i * 29) % 100) / 100 * 2.2,
      phase = ((i * 71) % 100) / 100 * 6.28,
    }
  end
  return out
end

-- One mesh per band: a ring of grid cells at a given distance from the
-- centre, with UVs continuous across the whole plane so the cloud pattern
-- does not break at a band edge.
local function makeCloudMesh(h, u)
  local half = CLOUD_SPAN * 0.5
  local step = CLOUD_SPAN / CLOUD_CELLS
  local bands = {}
  for b = 1, CLOUD_BANDS do bands[b] = { verts = {}, idx = {}, n = 0 } end
  for gz = 0, CLOUD_CELLS - 1 do
    for gx = 0, CLOUD_CELLS - 1 do
      local x0 = -half + gx * step
      local z0 = -half + gz * step
      local x1, z1 = x0 + step, z0 + step
      -- how far this cell sits from the middle, 0 at the centre and 1 at
      -- the rim of the inscribed circle
      local mx = (x0 + x1) * 0.5 / half
      local mz = (z0 + z1) * 0.5 / half
      local d = math.sqrt(mx * mx + mz * mz)
      if d <= 1.02 then
        local b = math.min(CLOUD_BANDS,
                           math.max(1, math.floor(d * CLOUD_BANDS) + 1))
        local B = bands[b]
        local function uv(x, z)
          return (x + half) / CLOUD_SPAN * u, (z + half) / CLOUD_SPAN * u
        end
        -- each corner lifted by its own distance, so the sheet curves
        -- rather than tilting
        local function lift(x, z)
          local rx, rz = x / half, z / half
          local rr = math.min(1.2, math.sqrt(rx * rx + rz * rz))
          return h + rr * rr * CLOUD_LIFT
        end
        local u0, v0 = uv(x0, z0)
        local u1, v1 = uv(x1, z1)
        B.verts[#B.verts + 1] = { x0, lift(x0, z1), z1, u0, v1, 1 }
        B.verts[#B.verts + 1] = { x1, lift(x1, z1), z1, u1, v1, 1 }
        B.verts[#B.verts + 1] = { x1, lift(x1, z0), z0, u1, v0, 1 }
        B.verts[#B.verts + 1] = { x0, lift(x0, z0), z0, u0, v0, 1 }
        Voxel3D.pushQuad(B.idx, B.n)
        B.n = B.n + 1
      end
    end
  end
  local out = {}
  for b = 1, CLOUD_BANDS do
    local B = bands[b]
    if B.n > 0 then
      local m = Voxel3D.newMesh(B.verts, B.idx)
      if m then out[#out + 1] = { mesh = m, fade = BAND_FADE[b] or 0.1 } end
    end
  end
  return (#out > 0) and out or nil
end

-- ------- birds: a unit quad, drawn once per bird with its own matrix
local function makeBirdMesh()
  local verts = {
    { -0.5, 0.5, 0, 0, 0, 1 }, { 0.5, 0.5, 0, 1, 0, 1 },
    { 0.5, -0.5, 0, 1, 1, 1 }, { -0.5, -0.5, 0, 0, 1, 1 },
  }
  local indexMap = {}
  Voxel3D.pushQuad(indexMap, 0)
  return Voxel3D.newMesh(verts, indexMap)
end

-- The frames this machine derived.  Probed once: whatever the transform
-- managed to build from the player's own cache is what flies over them.
local DERIVED = "save/mod-derived/ds_fp_ceiling/birds/"

local function loadPics()
  local out = { common = {}, rare = {} }
  local function frame(name, suffix)
    local ok, img = pcall(function()
      local i = love.graphics.newImage(DERIVED .. name .. suffix .. ".png")
      i:setFilter("nearest", "nearest")
      return i
    end)
    return ok and img or nil
  end
  local function try(list, into)
    for _, name in ipairs(list) do
      local a = frame(name, "_a")
      if a then
        into[#into + 1] = { a = a, b = frame(name, "_b") or a, name = name }
      end
    end
  end
  try(COMMON, out.common)
  try(RARE, out.rare)
  return out
end

local function newFlock(px, pz, ahead)
  if not pics or (#pics.common == 0 and #pics.rare == 0) then return nil end
  local rare = #pics.rare > 0 and math.random() < RARE_CHANCE
  local pool = rare and pics.rare or pics.common
  if #pool == 0 then pool = #pics.common > 0 and pics.common or pics.rare end
  if not pool or #pool == 0 then return nil end
  local pick = pool[math.random(#pool)]
  local heading = math.random() * math.pi * 2
  -- enter from the far side of the player, crossing rather than fleeing
  local entry = heading + math.pi + (math.random() - 0.5)
  local dist = ahead and (RANGE * 0.85) or (math.random() * RANGE)
  return {
    pic = pick,
    rare = rare,
    x = px + math.cos(entry) * dist,
    z = pz + math.sin(entry) * dist,
    y = rare and (BIRD_MAX_Y + 60)
        or (BIRD_MIN_Y + math.random() * (BIRD_MAX_Y - BIRD_MIN_Y)),
    heading = heading,
    speed = rare and 22 or (34 + math.random() * 26),
    -- smaller as well as further: a distant bird is a silhouette, and
    -- the less of the sprite that reads, the better it sits in the sky
    size = rare and 34 or (13 + math.random() * 7),
    count = rare and 1 or math.random(2, 5),
    phase = math.random() * 10,
    spread = 26 + math.random() * 40,
  }
end

-- Somewhere with room to land: a patch of walkable cells with nothing in
-- it, so a flock never settles inside a hedge or on a rooftop.
local function clearSpot(map, cx, cy)
  for dy = -FLOCK_CLEAR, FLOCK_CLEAR do
    for dx = -FLOCK_CLEAR, FLOCK_CLEAR do
      local ok, walk = pcall(function()
        return map:isWalkableCell(cx + dx, cy + dy)
      end)
      if not (ok and walk) then return false end
    end
  end
  return true
end

local function drawGroundFlock(state, cfg, px, pz, t, dt, pics, mesh, yaw)
  if cfg.groundflock == false then return "" end
  if not (pics and mesh and #pics.common > 0) then return "" end
  local map = state and state.map
  if not map then return "" end

  -- settle a new flock now and then, out of sight of the player's feet
  if not ground and math.random() < FLOCK_CHANCE * dt then
    local a = math.random() * math.pi * 2
    local r = FLOCK_NEAR + math.random() * (FLOCK_FAR - FLOCK_NEAR)
    local gx, gz = px + math.cos(a) * r, pz + math.sin(a) * r
    local cx, cy = math.floor(gx / 16), math.floor(gz / 16)
    if clearSpot(map, cx, cy) then
      local pick = pics.common[math.random(#pics.common)]
      local birds = {}
      for i = 1, math.random(FLOCK_MIN, FLOCK_MAX) do
        birds[i] = {
          x = gx + (math.random() - 0.5) * 46,
          z = gz + (math.random() - 0.5) * 46,
          y = 3,
          peck = math.random() * 6.28,
          rate = 1.4 + math.random() * 1.6,
          vx = 0, vy = 0, vz = 0,
        }
      end
      ground = { birds = birds, pic = pick, flushed = false,
                 born = t, heading = math.random() * math.pi * 2 }
    end
  end
  if not ground then return "" end

  -- they go up together: one bird's nerve breaking takes the whole flock
  if not ground.flushed then
    for _, b in ipairs(ground.birds) do
      local dx, dz = b.x - px, b.z - pz
      if (dx * dx + dz * dz) < FLUSH_DIST * FLUSH_DIST then
        ground.flushed = true
        ground.flushAt = t
        break
      end
    end
  end

  local rx, rz = math.cos(yaw), -math.sin(yaw)
  local alive = 0
  guarded(function()
    love.graphics.setDepthMode("lequal", false)
    for i, b in ipairs(ground.birds) do
      if ground.flushed then
        -- away from the player, and climbing: each on its own angle so
        -- they burst apart rather than leaving as a block
        if b.vy == 0 then
          local ang = math.atan2(b.z - pz, b.x - px)
                      + (math.random() - 0.5) * 1.1
          b.vx = math.cos(ang) * (70 + math.random() * 40)
          b.vz = math.sin(ang) * (70 + math.random() * 40)
          b.vy = 46 + math.random() * 30
        end
        b.x = b.x + b.vx * dt
        b.z = b.z + b.vz * dt
        b.y = b.y + b.vy * dt
        b.vy = b.vy + 6 * dt          -- still climbing, and faster
      else
        -- pecking: a dip of the head, and a shuffle between dips
        local p = math.sin(t * b.rate + b.peck)
        b.y = 3 + math.max(0, p) * 2
        if p > 0.98 then
          b.x = b.x + (math.random() - 0.5) * 0.6
          b.z = b.z + (math.random() - 0.5) * 0.6
        end
      end
      if b.y < 400 then
        alive = alive + 1
        local beat = (t + b.peck) * 7
        local up = (math.floor(beat) % 2) == 0
        local img = (ground.flushed and up) and ground.pic.a
                    or (ground.flushed and ground.pic.b) or ground.pic.a
        local size = 11
        local heading = math.atan2(b.vz, b.vx)
        local facing = (math.cos(heading) * rx
                        + math.sin(heading) * rz) < 0 and -1 or 1
        Voxel3D.draw(mesh, img,
                     Mat4.mul(Mat4.mul(Mat4.translate(b.x, b.y, b.z),
                                       Mat4.rotateY(-yaw)),
                              Mat4.scale(size * facing, size, 1)))
      end
    end
  end)

  if alive == 0 or (t - ground.born) > FLOCK_LIFE then ground = nil end
  return alive > 0
    and (", flock %d%s"):format(alive, ground and ground.flushed
                                       and " FLUSHED" or "")
    or ""
end

-- Lifted out of Sky.draw, which had reached LuaJIT's 60-upvalue ceiling
-- for a single function; it also reads better on its own.
local function drawRainbow(cfg, px, pz, t)
  -- ---- the rainbow, when a shower has just passed
  local bowNote = ""
  if cfg.rainbows ~= false then
    local w = rawget(_G, "__ds_weather") or {}
    local since = w.stoppedAt and (t - w.stoppedAt) or nil
    if since and not w.raining and since < RAINBOW_LIFE and not isNight() then
      rainbowImg = rainbowImg or makeRainbow()
      birdMesh = birdMesh or makeBirdMesh()
      if rainbowImg and birdMesh then
        -- fade up, hold, fade out
        local a = math.min(since / RAINBOW_FADE,
                           (RAINBOW_LIFE - since) / RAINBOW_FADE, 1)
        -- anti-solar: opposite whichever way the sun is (in RADIANS --
        -- bodyAt speaks degrees)
        local az = sunAngle()
        local anti = az + math.pi
        -- ANCHORED. The bow used to be placed relative to the player, so
        -- it travelled with them -- walk a hundred units and it walked
        -- too. It is pinned once, where the shower left it, and stays
        -- there: walk toward it and you approach it, as you would.
        if not bowAnchor or bowAnchor.at ~= w.stoppedAt then
          -- placed ONCE, where the shower ended: position AND facing are
          -- fixed from this moment; the curve does the rest
          bowAnchor = {
            at = w.stoppedAt,
            x = px + math.cos(anti) * RAINBOW_DIST,
            z = pz + math.sin(anti) * RAINBOW_DIST,
            face = math.atan2(px - (px + math.cos(anti) * RAINBOW_DIST),
                              pz - (pz + math.sin(anti) * RAINBOW_DIST)),
          }
        end
        local bx, bz = bowAnchor.x, bowAnchor.z
        guarded(function()
          love.graphics.setDepthMode("lequal", false)
          -- ethereal: barely there, so it reads as light in the air
          -- rather than as a painted arch
          -- solid enough to be a rainbow, sheer enough to be light
          love.graphics.setColor(1, 1, 1, a * 0.80)
          -- faces the player like the horizon does, and never approaches
          -- the shell is built at world size, so it takes no scale:
          -- translate to the anchor, turn to the anchor-time facing, and
          -- that is the whole transform, forever
          local shell = bowShell()
          if shell then
            Voxel3D.draw(shell, rainbowImg,
                         Mat4.mul(Mat4.translate(bx, RAINBOW_FEET, bz),
                                  Mat4.rotateY(bowAnchor.face or 0)))
          else
            Voxel3D.draw(birdMesh, rainbowImg,
                         Mat4.mul(Mat4.mul(
                           Mat4.translate(bx, RAINBOW_FEET
                                          + RAINBOW_SIZE * 0.52 * 0.5, bz),
                           Mat4.rotateY(bowAnchor.face or 0)),
                           Mat4.scale(RAINBOW_SIZE, RAINBOW_SIZE * 0.52,
                                      1)))
          end
        end)
        bowNote = (", rainbow %.0f%%"):format(a * 100)
      end
    end
  end
  return bowNote
end

-- Aircraft, lifted out of Sky.draw: that function sits at LuaJIT's
-- 60-upvalue ceiling, so each new feature moves into its own function.
local function drawAircraft(cfg, px, pz, t, dt, yaw, mesh)
  local airNote = ""
  birdMesh = mesh or birdMesh
  -- ---- aircraft: planes with contrails, and the rare blimp
  if cfg.aircraft ~= false then
    planeImg = planeImg or makePlane()
    blimpImg = blimpImg or makeBlimp()
    puffImg = puffImg or makePuff()
    birdMesh = birdMesh or makeBirdMesh()
    planes, blimps, trails = planes or {}, blimps or {}, trails or {}
    local yaw = (FirstPerson and FirstPerson.yaw) or 0
    local rx, rz = math.cos(yaw), -math.sin(yaw)

    if planeImg and math.random() < PLANE_CHANCE * dt and #planes < 2 then
      local a = math.random() * math.pi * 2
      planes[#planes + 1] = {
        x = px + math.cos(a) * PLANE_DIST,
        z = pz + math.sin(a) * PLANE_DIST,
        head = a + math.pi + (math.random() - 0.5) * 0.5,
        speed = 110 + math.random() * 50, life = 46, puffAt = 0,
      }
    end
    if blimpImg and math.random() < BLIMP_CHANCE * dt and #blimps == 0 then
      local a = math.random() * math.pi * 2
      blimps[1] = {
        x = px + math.cos(a) * BLIMP_DIST,
        z = pz + math.sin(a) * BLIMP_DIST,
        head = a + math.pi + (math.random() - 0.5) * 0.7,
        speed = 22 + math.random() * 9, life = 170,
      }
    end

    guarded(function()
      love.graphics.setDepthMode("lequal", false)
      -- contrail first, so the aircraft sits in front of its own trail
      for i = #trails, 1, -1 do
        local p = trails[i]
        p.life = p.life - dt
        if p.life <= 0 then
          table.remove(trails, i)
        else
          local age = 1 - p.life / TRAIL_LIFE
          -- a trail widens and thins as it ages, like the real thing
          local sz = 16 + age * 52
          love.graphics.setColor(1, 1, 1, (1 - age) * 0.55)
          Voxel3D.draw(birdMesh, puffImg,
                       Mat4.mul(Mat4.mul(Mat4.translate(p.x, p.y, p.z),
                                         Mat4.rotateY(-yaw)),
                                Mat4.scale(sz, sz, 1)))
        end
      end
      love.graphics.setColor(1, 1, 1, 1)

      for i = #planes, 1, -1 do
        local pl = planes[i]
        pl.life = pl.life - dt
        pl.x = pl.x + math.cos(pl.head) * pl.speed * dt
        pl.z = pl.z + math.sin(pl.head) * pl.speed * dt
        if pl.life <= 0 then
          table.remove(planes, i)
        else
          pl.puffAt = pl.puffAt - dt
          if pl.puffAt <= 0 and #trails < 90 then
            pl.puffAt = TRAIL_EVERY
            trails[#trails + 1] = { x = pl.x, y = PLANE_Y, z = pl.z,
                                    life = TRAIL_LIFE }
          end
          local facing = (math.cos(pl.head) * rx
                          + math.sin(pl.head) * rz) < 0 and -1 or 1
          Voxel3D.draw(birdMesh, planeImg,
                       Mat4.mul(Mat4.mul(Mat4.translate(pl.x, PLANE_Y, pl.z),
                                         Mat4.rotateY(-yaw)),
                                Mat4.scale(PLANE_SIZE * facing,
                                           PLANE_SIZE, 1)))
          airNote = ", plane"
        end
      end

      for i = #blimps, 1, -1 do
        local bl = blimps[i]
        bl.life = bl.life - dt
        bl.x = bl.x + math.cos(bl.head) * bl.speed * dt
        bl.z = bl.z + math.sin(bl.head) * bl.speed * dt
        if bl.life <= 0 then
          table.remove(blimps, i)
        else
          local facing = (math.cos(bl.head) * rx
                          + math.sin(bl.head) * rz) < 0 and -1 or 1
          Voxel3D.draw(birdMesh, blimpImg,
                       Mat4.mul(Mat4.mul(Mat4.translate(bl.x, BLIMP_Y, bl.z),
                                         Mat4.rotateY(-yaw)),
                                Mat4.scale(BLIMP_SIZE * facing,
                                           BLIMP_SIZE, 1)))
          airNote = airNote .. ", BLIMP"
        end
      end
      love.graphics.setDepthMode("lequal", true)
    end)
  end
  return airNote
end

-- If the companion mod has been deleted, its config bridge is gone and
-- this module is an orphan: draw nothing. The ceiling module does the
-- actual clean-up; this just keeps quiet in the meantime.
local function abandoned()
  return not CommunityVisuals.customSky()
end

-- TEST133: celestial light belongs behind the painted horizon. Keep the
-- foreground birds/weather on their established side of the mountains.
local starT, lastStarNote = nil, ""
function Sky.drawStars(state)
  if abandoned() then return end
  local map = state and state.map
  if not map or not isOutdoor(map) then return end
  local cfg = config()
  local p = state.player
  local px, pz = (p and p.px) or 0, (p and p.py) or 0
  local t = now()
  local dt = starT and math.max(0, math.min(0.1, t - starT)) or 0
  starT = t
  -- ---- the night sky: field, twinklers, and the occasional streak
  local starNote = ""
  if cfg.stars ~= false then
    local target = isNight() and 1 or 0
    if dt > 0 then
      local step = dt / FADE_TIME
      nightAmt = nightAmt + math.max(-step, math.min(step, target - nightAmt))
    end
    if nightAmt > 0.01 then
      if not starImg then starImg = makeStars() end
      if starImg and not starMesh then starMesh = makeStarMesh() end
      birdMesh = birdMesh or makeBirdMesh()
      starDot = starDot or makeStarDot()
      twinkles = twinkles or makeTwinkles()
      shooters = shooters or {}
      if starImg and starMesh then
        guarded(function()
          love.graphics.setDepthMode("lequal", false)
          -- TEST391 / EMISSIVE STAR COMPOSITION
          -- Stars emit light; they must never alpha-paint a dim terrain-shaded
          -- texel over a brighter sky. Keep the complete generated field and
          -- its four brightness levels, but bypass surface lighting and use
          -- additive composition so every star can only brighten the frame.
          -- TEST133: this whole celestial pass runs BEFORE Backdrop. Its
          -- opaque mountain/woodland pixels cover stars; transparent skyline
          -- pixels retain them. No depth writes or artificial horizon band.
          -- TEST56: Battle Art exposes the required unlit path as
          -- lighting(false), not the donor renderer's emissive() alias.
          -- Calling the host API lets the star pass actually reach the draw.
          Voxel3D.lighting(false)
          Voxel3D.blend("add")
          -- the field: fades in at dusk rather than snapping on
          love.graphics.setColor(1, 1, 1, nightAmt)
          Voxel3D.draw(starMesh, starImg, Mat4.translate(px, 0, pz))

          -- twinklers over it, each on its own clock
          local yaw = (FirstPerson and FirstPerson.yaw) or 0
          for _, w in ipairs(twinkles) do
            local pulse = 0.45 + 0.55
              * math.abs(math.sin(t * w.rate + w.phase))
            love.graphics.setColor(1, 1, 1, nightAmt * pulse)
            local sz = w.size * (0.7 + 0.5 * pulse)
            Voxel3D.draw(birdMesh, starDot or starImg,
                         Mat4.mul(Mat4.mul(
                           Mat4.translate(px + w.x, w.y, pz + w.z),
                           Mat4.rotateY(-yaw)), Mat4.scale(sz, sz, 1)))
          end

          -- shooting stars: rare, quick, and stretched along their travel
          if math.random() < SHOOT_CHANCE * dt * nightAmt then
            local a = math.random() * math.pi * 2
            local head = a + math.pi + (math.random() - 0.5) * 1.2
            shooters[#shooters + 1] = {
              x = math.cos(a) * TWINKLE_R * 1.2,
              z = math.sin(a) * TWINKLE_R * 1.2,
              y = STAR_Y * (0.55 + math.random() * 0.4),
              head = head,
              speed = 900 + math.random() * 500,
              fall = 80 + math.random() * 120,
              life = 0.55 + math.random() * 0.35,
              max = 0.9,
            }
          end
          for i = #shooters, 1, -1 do
            local sh = shooters[i]
            sh.life = sh.life - dt
            if sh.life <= 0 then
              table.remove(shooters, i)
            else
              sh.x = sh.x + math.cos(sh.head) * sh.speed * dt
              sh.z = sh.z + math.sin(sh.head) * sh.speed * dt
              sh.y = sh.y - sh.fall * dt
              local fade = math.min(1, sh.life / (sh.max * 0.5))
              love.graphics.setColor(1, 1, 1, nightAmt * fade)
              -- the streak: wide along its heading, thin across it
              Voxel3D.draw(birdMesh, starDot or starImg,
                           Mat4.mul(Mat4.mul(
                             Mat4.translate(px + sh.x, sh.y, pz + sh.z),
                             Mat4.rotateY(-sh.head)),
                             Mat4.scale(150 * fade, 5, 1)))
            end
          end
          Voxel3D.lighting(true)
          Voxel3D.blend("alpha")
          love.graphics.setColor(1, 1, 1, 1)
          love.graphics.setDepthMode("lequal", true)
        end)
        -- Shader uniforms are not part of LOVE's pushed graphics state. Repeat
        -- these two restores outside the guarded callback so even an unexpected
        -- star-draw error cannot leak emissive/additive state into clouds,
        -- terrain details or another mod later in the frame.
        Voxel3D.lighting(true)
        Voxel3D.blend("alpha")
        starNote = (", stars %.0f%%%s"):format(nightAmt * 100,
          (#shooters > 0) and " (SHOOTING)" or "")
      end
    end
  end

  lastStarNote = starNote
end

function Sky.drawForeground(state)
  if abandoned() then return end
  local cfg = config()
  local map = state and state.map
  if not map then return end
  if not isOutdoor(map) then
    status("indoors -- no sky here")
    return
  end

  local p = state.player
  local px = (p and p.px) or 0
  local pz = (p and p.py) or 0
  local t = now()
  local dt = lastT and math.min(0.1, t - lastT) or 0
  lastT = t

  local drewClouds, birdCount = false, 0
  local starNote = lastStarNote

  -- ---- clouds
  if (not TEST110_DISABLE_BUILTIN_CLOUD_DECKS) and cfg.clouds ~= false then
    if not decks then
      decks = {}
      for i, d in ipairs(CLOUD_DECKS) do
        local img = makeClouds(d.cut, d.seed)
        local mesh = img and makeCloudMesh(d.y, d.tiles) or nil
        decks[i] = { img = img, mesh = mesh, def = d }
      end
    end
    -- clouds thin out after dark: a night sky wants its stars, and a full
    -- overcast would hide the one thing worth looking up for
    local dayAmt = 1 - nightAmt * (1 - NIGHT_CLOUD)
    -- a storm turns the decks into thunderheads: heavier and much darker
    local w = rawget(_G, "__ds_weather") or {}
    local gloom = w.storm and 0.34 or (w.raining and 0.68 or 1)
    guarded(function()
      love.graphics.setDepthMode("lequal", false)
      for _, deck in ipairs(decks) do
        if deck.img and deck.mesh then
          -- each deck drifts at its own speed: the parallax between them
          -- is what stops the sky reading as a single painted sheet.
          -- NB: named windSpeed, not w -- `w` is the weather table above,
          -- and shadowing it here made `w.storm` index a number, which
          -- threw inside the guard and silently stopped the clouds.
          local windSpeed = deck.def.wind
          local ox = (px * 0.5 + t * windSpeed * 1000) / CLOUD_TEX
          local oz = (pz * 0.5 + t * windSpeed * 340) / CLOUD_TEX
          local base = math.min(1, deck.def.alpha * dayAmt
                                * (w.storm and 1.5 or 1))
          local model = Mat4.mul(Mat4.translate(px, 0, pz),
                                 Mat4.translate(-ox % 1 * 40, 0,
                                                -oz % 1 * 40))
          -- inner bands solid, outer bands thinning into the blue
          for _, band in ipairs(deck.mesh) do
            love.graphics.setColor(gloom, gloom, gloom, base * band.fade)
            Voxel3D.draw(band.mesh, deck.img, model)
          end
          drewClouds = true
        end
      end
      love.graphics.setColor(1, 1, 1, 1)
      love.graphics.setDepthMode("lequal", true)
    end)
  end

  local bowNote = drawRainbow(cfg, px, pz, t)
  birdMesh = birdMesh or makeBirdMesh()
  if not pics then pics = loadPics() end
  birdMesh = birdMesh or makeBirdMesh()
  local flockNote = drawGroundFlock(state, cfg, px, pz, t, dt, pics, birdMesh,
                                    (FirstPerson and FirstPerson.yaw) or 0)

  -- ---- birds
  birdMesh = birdMesh or makeBirdMesh()
  if cfg.birds ~= false then
    if not pics then pics = loadPics() end
    if not birdMesh then birdMesh = makeBirdMesh() end
    if pics and birdMesh and (#pics.common > 0 or #pics.rare > 0) then
      if not flocks then
        flocks = {}
        for _ = 1, FLOCKS do
          local f = newFlock(px, pz, false)
          if f then flocks[#flocks + 1] = f end
        end
      end
      local yaw = (FirstPerson and FirstPerson.yaw) or 0
      -- Which way is screen-right for the camera.  A billboard always
      -- faces the viewer, but the sprite inside it faces one fixed way,
      -- so a bird crossing right-to-left flies tail-first unless the
      -- quad is mirrored.  Dotting the flock's heading against the
      -- camera's right vector says which case we are in.
      local rx, rz = math.cos(yaw), -math.sin(yaw)
      guarded(function()
        love.graphics.setDepthMode("lequal", false)
        for i, f in ipairs(flocks) do
          f.x = f.x + math.cos(f.heading) * f.speed * dt
          f.z = f.z + math.sin(f.heading) * f.speed * dt
          local dx, dz = f.x - px, f.z - pz
          if (dx * dx + dz * dz) > RANGE * RANGE then
            flocks[i] = newFlock(px, pz, true) or f
          else
            for b = 1, f.count do
              -- a loose echelon: each bird trails and offsets from the lead
              local back = (b - 1) * f.spread
              local side = ((b % 2 == 0) and 1 or -1)
                           * math.ceil((b - 1) / 2) * f.spread * 0.7
              local bx = f.x - math.cos(f.heading) * back
                         - math.sin(f.heading) * side
              local bz = f.z - math.sin(f.heading) * back
                         + math.cos(f.heading) * side
              local beat = (t + f.phase + b * 0.3) * FLAP_HZ
              local up = (math.floor(beat) % 2) == 0
              local flap = math.sin(beat * math.pi * 2)
              local sy = f.size
              local by = f.y + flap * 2
              local facing = (math.cos(f.heading) * rx
                              + math.sin(f.heading) * rz) < 0 and -1 or 1
              Voxel3D.draw(birdMesh, up and f.pic.a or f.pic.b,
                           Mat4.mul(Mat4.mul(Mat4.translate(bx, by, bz),
                                             Mat4.rotateY(-yaw)),
                                    Mat4.scale(f.size * facing, sy, 1)))
              birdCount = birdCount + 1
            end
          end
        end
        love.graphics.setDepthMode("lequal", true)
      end)
    end
  end

  local airNote = drawAircraft(cfg, px, pz, t, dt,
                               (FirstPerson and FirstPerson.yaw) or 0,
                               birdMesh or makeBirdMesh())

  local haveRare = false
  for _, f in ipairs(flocks or {}) do if f.rare then haveRare = true end end
  status(("%s, %d birds%s%s"):format(drewClouds and "clouds" or "no clouds",
         birdCount, haveRare and " (RARE aloft)" or "",
         starNote .. airNote .. bowNote .. (flockNote or "")))
end

-- Compatibility for older external callers. Host scenes explicitly sandwich
-- Backdrop between the two passes; calling draw alone retains both effects.
function Sky.draw(state)
  Sky.drawStars(state)
  Sky.drawForeground(state)
end

function Sky.invalidate()
  for _, d in ipairs(decks or {}) do
    for _, band in ipairs(d.mesh or {}) do
      pcall(band.mesh.release, band.mesh)
    end
  end
  decks = nil
  if birdMesh then pcall(birdMesh.release, birdMesh) end
  if starMesh then pcall(starMesh.release, starMesh) end
  birdMesh, starMesh = nil, nil
  flocks, twinkles, shooters, nightAmt = nil, nil, nil, 0
  planes, blimps, trails = nil, nil, nil
  ground = nil
  lastT, starT, lastStarNote = nil, nil, ""
end

-- live registration: the installer hot-swaps refreshed modules
-- into the running session through this table, killing the
-- boot-twice ritual (see main.lua, hotSwap)
_G.__ds_live = rawget(_G, "__ds_live") or {}
_G.__ds_live.SkyLayer = Sky
_G.__ds_live.V = _G.__ds_live.V or V

return Sky
