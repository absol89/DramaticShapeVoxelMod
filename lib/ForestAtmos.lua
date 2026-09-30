-- The air under the canopy: fog, god rays, and what drifts through them.
--
-- Some maps have an ATMOSPHERE (data/map_atmosphere.lua -- Viridian Forest
-- today, any map that adds a line tomorrow): a ground haze the scene shader
-- folds every surface into (see Voxel3D.fog), and VOLUMETRIC light let down
-- through an INVISIBLE canopy hanging above the map's real trees, as if the
-- carved hulls on screen were only the understorey of something taller.
--
-- The rays are not placed geometry. A fullscreen pass marches every
-- pixel's eye ray through the air, stops at the frame's own depth buffer
-- (the same detach-and-read Water runs), and asks two questions of every
-- step of air on the way:
--
--   * the SUN'S question -- the shadow map. Air behind a tree hull is
--     dark air; air in a real gap glows. A trunk stands in a column of
--     its own shade, a character walks through the beams and blocks
--     them, and every shaft on screen agrees with the light already on
--     the floor, because it is read from the same map.
--
--   * the CANOPY'S question -- where this thread of sun pierced the
--     invisible leaf layer. Every step of air on one sun ray shares that
--     point, which is what makes a shaft a SHAFT, and the point samples
--     a wind-blown noise field: the dapple drifts and shivers like
--     leaves moving overhead, opening and closing the beams as it goes.
--
-- The shafts lean along the fixed noon shear, deliberately: a canopy
-- map's rig is pinned to noon (see DayNight.CANOPY), so light that
-- followed the sun's arc would part company with every shadow on the
-- floor. What follows the clock is colour and strength -- gold spears of
-- sun by day, silver moon rays after dark, dying back through the
-- twilights -- plus the crew each shift brings: pollen adrift in the
-- day's beams, fireflies once they cool. A forward-scattering phase term
-- brightens the beams for a camera looking up into the light, which is
-- most of what makes them read as light in air rather than paint on it.
--
-- Everything is deterministic: placement and the leaf field are dealt by
-- a seeded xorshift (StadiumFx's generator), motion is a pure function
-- of one `time` uniform, so a pinned ForestAtmos.time reproduces a frame
-- exactly (see tests/forest_fog_shots). Every shader compiles lazily
-- behind pcall -- nil untried, false unavailable -- and each refusal
-- subtracts only itself: no march without readable depth, no beams
-- without a shadow map, and the fog rides the scene shader whatever
-- happens here.

local V = ...

local DayNight = V.require("DayNight")
local ModSetting = V.require("ModSetting")

local floor, sqrt, min, max = math.floor, math.sqrt, math.min, math.max

local ForestAtmos = {}

-- The viewport, as both shaders here take it (see Voxel3D.cull: the field
-- is set for a headset's diorama frame and for an orbit rung's window box,
-- and nil for every other, where kind 0 means "no cut"). Read through
-- V.require rather than held as an upvalue because this file loads before
-- Voxel3D on some paths.
local function cullAt()
  local c = V.require("Voxel3D").cull
  return c and { c.x, c.y, c.z } or { 0, 0, 0 }
end

local function cullShape()
  local c = V.require("Voxel3D").cull
  return c and { c.r, c.invFade, c.kind } or { 0, 0, 0 }
end

local function cullRect()
  local c = V.require("Voxel3D").cull
  return c and { c.rx or c.r, c.rz or c.r } or { 0, 0 }
end

-- Battle Art targets the Android handheld path, so this integration locks the
-- donor atmosphere to LOW.  That keeps the approved scene-shader haze and the
-- guarded depth-aware beams, while omitting the donor's separate FULL particle
-- shader API that Battle Art does not own. TEST91 suppresses drifting leaves
-- and opens Legendary Viridian Forest to the outdoor sky.
ForestAtmos.setting = ModSetting.new(
  "atmos", "FOREST FX", { "low", "off" }, { "LOW", "OFF" }
)

-- the animation clock: ticked by main.lua's always-running update hook,
-- pinnable (frozen = true) so a screenshot driver can hold a frame still
ForestAtmos.time = 0
ForestAtmos.frozen = false

function ForestAtmos.update(dt)
  if ForestAtmos.frozen then return end
  ForestAtmos.time = ForestAtmos.time + (dt or 0)
end

-- ------- the authored table
--
-- Same shape as BattleArena's: the data file behind a pcall with a false
-- sentinel, and an overrides table a tuning driver can stage a candidate
-- through before anything is written down. `~= nil` on the override,
-- because false is meaningful -- "this map has no atmosphere, whatever
-- the file says".

local authored = nil
local overrides = {}

local function configFor(mapId)
  if not mapId then return nil end
  local forced = overrides[mapId]
  if forced ~= nil then return forced or nil end
  if authored == nil then
    local ok, list = pcall(V.data, "map_atmosphere")
    authored = (ok and type(list) == "table") and list or false
  end
  if not authored then return nil end
  return authored[mapId]
end

ForestAtmos.configFor = configFor

-- ------- caches
--
-- Particle layouts and meshes go stale with the map (map.reloaded, and
-- the pipeline's invalidate); called with no map id this also resets the
-- shader and texture sentinels, which is what a lost GL context needs.

local layoutCache = {}
local meshCache = {}
local shaders = {}            -- keyed by variant; nil untried, false refused
local leafTex = nil           -- the tiling leaf-dapple field
local rayMesh = nil           -- the fullscreen ray-fan quad, re-aimed per draw

-- Every bail here is deliberate and silent on screen -- a missing piece
-- subtracts itself, never the frame -- but "the beams are off" and "the
-- beams are off BECAUSE ..." are different debugging days. Each reason
-- is said once on the console, the way VR reports a missing runtime.
local said = {}
local function say(key, msg)
  if said[key] then return end
  said[key] = true
  msg = "atmos: " .. tostring(msg)
  if V and V.dlog then V.dlog(msg)
  elseif V and V.log then V.log:info("%s", msg)
  else print("[DRAMATIC_SHAPE] " .. msg) end
end

function ForestAtmos.invalidate(mapId)
  if mapId then
    layoutCache[mapId] = nil
    meshCache[mapId] = nil
  else
    layoutCache, meshCache = {}, {}
    shaders = {}
    leafTex = nil
    rayMesh = nil
  end
end

function ForestAtmos.setOverride(mapId, entry)
  overrides[mapId] = entry
  ForestAtmos.invalidate(mapId)
end

-- ------- the hour's answer
--
-- One ramp, authored per phase and blended with DayNight's own weights,
-- so the fog and the rays can never disagree about what hour it is. The
-- two interact three ways: the fog colour leans toward the ray colour
-- (noon warms the haze, midnight silvers it), the rays scale with the
-- fog's density (a beam IS lit fog -- less medium, less beam), and the
-- march accumulates through the same density the surfaces sink into.

ForestAtmos.RAMP = {
  day    = { fog = { 0.78, 0.86, 0.70 }, ray = { 1.00, 0.93, 0.70 },
             alpha = 0.34, density = 1.00, motes = 1.0, flies = 0.0 },
  golden = { fog = { 0.84, 0.76, 0.58 }, ray = { 1.00, 0.85, 0.55 },
             alpha = 0.26, density = 1.00, motes = 0.6, flies = 0.0 },
  dawn   = { fog = { 0.80, 0.70, 0.66 }, ray = { 1.00, 0.80, 0.62 },
             alpha = 0.15, density = 1.05, motes = 0.3, flies = 0.25 },
  dusk   = { fog = { 0.78, 0.66, 0.58 }, ray = { 1.00, 0.76, 0.55 },
             alpha = 0.15, density = 1.05, motes = 0.2, flies = 0.5 },
  violet = { fog = { 0.52, 0.50, 0.66 }, ray = { 0.82, 0.80, 1.00 },
             alpha = 0.18, density = 1.10, motes = 0.0, flies = 1.0 },
  night  = { fog = { 0.34, 0.40, 0.56 }, ray = { 0.72, 0.80, 1.00 },
             alpha = 0.24, density = 1.15, motes = 0.0, flies = 1.0 },
}

-- The frame's atmosphere for `map` at clock `t` (defaulting to now), or
-- nil -- no entry, or the row is OFF -- in which case nothing is drawn
-- and Voxel3D.fog should be left nil.
function ForestAtmos.frame(map, t)
  if ForestAtmos.setting:get() == "off" then return nil end
  local cfg = configFor(map and map.id)
  if not cfg then return nil end
  local mix = DayNight.mix(t or DayNight.time())
  local fr, fg, fb, rr, rg, rb = 0, 0, 0, 0, 0, 0
  local alpha, dens, motes, flies = 0, 0, 0, 0
  for name, w in pairs(mix) do
    local p = ForestAtmos.RAMP[name] or ForestAtmos.RAMP.day
    fr, fg, fb = fr + p.fog[1] * w, fg + p.fog[2] * w, fb + p.fog[3] * w
    rr, rg, rb = rr + p.ray[1] * w, rg + p.ray[2] * w, rb + p.ray[3] * w
    alpha = alpha + p.alpha * w
    dens = dens + p.density * w
    motes = motes + p.motes * w
    flies = flies + p.flies * w
  end
  -- the haze takes on a little of the light standing in it
  local LEAN = 0.15
  fr = fr + (rr - fr) * LEAN
  fg = fg + (rg - fg) * LEAN
  fb = fb + (rb - fb) * LEAN
  local base = cfg.fog or {}
  local rays = cfg.rays or {}
  local roam = cfg.roamFog
  return {
    -- Free-roam override; original fog still supplies battles and rays.
    roamFog = roam and { color = { fr, fg, fb },
      density = (roam.density or 0) * dens,
      start = roam.start or 0, heightK = roam.heightK or 0 } or nil,
    -- in exactly the shape Voxel3D.fog takes, so callers assign it whole
    fog = { color = { fr, fg, fb },
            density = (base.density or 0) * dens,
            start = base.start or 0,
            heightK = base.heightK or 0 },
    rayColor = { rr, rg, rb },
    -- a beam is scattered fog: less medium, less beam
    rayAlpha = alpha * (0.4 + 0.6 * min(dens, 1)),
    rayStrength = rays.strength or 12,
    rayReach = rays.reach or 380,
    moteLevel = motes,
    fireflyLevel = flies,
    cfg = cfg,
  }
end

-- ------- deterministic noise
--
-- The same written-out xorshift StadiumFx runs (see the note there on why
-- not LuaJIT's `bit`): the particle deal and the leaf field must come out
-- identical on every machine and every visit.

local function bxor32(a, b)
  local r, p = 0, 1
  for _ = 1, 32 do
    local x, y = a % 2, b % 2
    if x ~= y then r = r + p end
    a, b, p = floor(a / 2), floor(b / 2), p * 2
  end
  return r
end

local Rng = {}
Rng.__index = Rng

local function newRng(seed)
  local s = seed % 0x100000000
  if s == 0 then s = 0x9E3779B9 end
  return setmetatable({ s = s }, Rng)
end

function Rng:next()
  local x = self.s
  x = bxor32(x, (x % 0x80000) * 0x2000)               -- x ^= (x << 13)
  x = bxor32(x, floor(x / 0x20000))                   -- x ^= x >> 17
  x = bxor32(x, (x % 0x8000000) * 0x20)               -- x ^= (x << 5)
  self.s = x % 0x100000000
  return self.s
end

function Rng:unit()
  return self:next() / 0x100000000
end

-- bilinear value noise on a torus (StadiumFx's), so the leaf field tiles
local function lattice(rng, w, h)
  local g = {}
  for y = 1, h do
    local row = {}
    for x = 1, w do row[x] = rng:unit() end
    g[y] = row
  end
  return g
end

local function smoothstep01(t)
  return t * t * (3 - 2 * t)
end

local function torus(grid, w, h, x, y)
  local x0, y0 = floor(x), floor(y)
  local fx, fy = smoothstep01(x - x0), smoothstep01(y - y0)
  local x1, y1 = (x0 + 1) % w, (y0 + 1) % h
  x0, y0 = x0 % w, y0 % h
  local a = grid[y0 + 1][x0 + 1]
  local b = grid[y0 + 1][x1 + 1]
  local c = grid[y1 + 1][x0 + 1]
  local d = grid[y1 + 1][x1 + 1]
  return (a + (b - a) * fx) + ((c + (d - c) * fx) - (a + (b - a) * fx)) * fy
end

-- ------- the leaf field
--
-- One small tiling texture of three-octave value noise, generated once
-- from a fixed seed: the pattern of the unseen foliage. The shader reads
-- it at two drifting, differently-scaled offsets and thresholds the sum,
-- so the pools of light between the leaves slide, open and close -- the
-- movement is the WIND's, all in the sampling; the cloth itself never
-- changes, which is what keeps a pinned frame reproducible.

local function leafTexture()
  if leafTex ~= nil then return leafTex or nil end
  if not (love and love.image and love.image.newImageData
          and love.graphics and love.graphics.newImage) then
    leafTex = false
    return nil
  end
  local ok, tex = pcall(function()
    local N = 128
    local rng = newRng(0x1EAF)
    local g1 = lattice(rng, 8, 8)
    local g2 = lattice(rng, 16, 16)
    local g3 = lattice(rng, 32, 32)
    local img = love.image.newImageData(N, N)
    for y = 0, N - 1 do
      local v = y / N
      for x = 0, N - 1 do
        local u = x / N
        local n = torus(g1, 8, 8, u * 8, v * 8) * 0.5
                + torus(g2, 16, 16, u * 16, v * 16) * 0.3
                + torus(g3, 32, 32, u * 32, v * 32) * 0.2
        img:setPixel(x, y, n, n, n, 1)
      end
    end
    local t = love.graphics.newImage(img)
    t:setWrap("repeat", "repeat")
    t:setFilter("linear", "linear")
    return t
  end)
  leafTex = (ok and tex) or false
  return leafTex or nil
end

-- ------- placement (the particles; the light places itself)

local MARGIN = 24     -- keep off the map's edge, world px

function ForestAtmos.layout(cfg, w, h)
  local rng = newRng((cfg.seed or 0x51D))
  local canopy = cfg.canopyY or 56
  local motes = {}
  for _ = 1, (cfg.motes and cfg.motes.count) or 0 do
    motes[#motes + 1] = {
      x = MARGIN + rng:unit() * max(w - 2 * MARGIN, 1),
      y = 3 + rng:unit() * max(canopy - 11, 8),
      z = MARGIN + rng:unit() * max(h - 2 * MARGIN, 1),
      phase = rng:unit() * 6.2832,
      rate = 0.5 + rng:unit(),
    }
  end
  local flies = {}
  for _ = 1, (cfg.fireflies and cfg.fireflies.count) or 0 do
    flies[#flies + 1] = {
      x = MARGIN + rng:unit() * max(w - 2 * MARGIN, 1),
      y = 3 + rng:unit() * 12,
      z = MARGIN + rng:unit() * max(h - 2 * MARGIN, 1),
      phase = rng:unit() * 6.2832,
      rate = 0.5 + rng:unit(),
    }
  end
  return { motes = motes, flies = flies }
end

-- A map is width x height BLOCKS of 4x4 tiles of 8 pixels -- times 32
-- for world pixels (the same arithmetic Structures runs in tiles).
local function layoutFor(map)
  local hit = layoutCache[map.id]
  if hit ~= nil then return hit or nil end
  local cfg = configFor(map.id)
  if not cfg then
    layoutCache[map.id] = false
    return nil
  end
  local def = map.def or {}
  local L = ForestAtmos.layout(cfg, (def.width or 16) * 32,
                               (def.height or 16) * 32)
  layoutCache[map.id] = L
  return L
end

ForestAtmos.layoutFor = layoutFor

-- ------- the volumetric march
--
-- A fullscreen quad whose four corners carry the camera's own frustum
-- rays; the varying interpolates them into a world ray per pixel. The
-- pixel stage walks that ray to the depth buffer's surface, and every
-- step of air on the way is lit or not by the shadow map and the leaf
-- field, accumulated through the same haze the surfaces sink into.
--
-- Conventions copied from Water's march: the ray walks the FLAT world
-- (the space it is straight in) and every depth compare bends the sample
-- first, by the same displacement the vertex stage applies -- so the
-- march reads the depth buffer it actually has. The shadow lookup stays
-- flat, exactly like the scene shader's own vSun. STEPS is spliced into
-- the source rather than sent (the LOW rung is a second compile), and
-- there are no uniform arrays anywhere -- see the note in Sky about the
-- Android driver that reads them as zero.

local RAY_SHADER = [[
  varying vec3 vRay;
#ifdef VERTEX
  attribute vec3 RayDir;
  vec4 position(mat4 transform_projection, vec4 vertex_position) {
    vRay = RayDir;
    return transform_projection * vertex_position;
  }
#endif
#ifdef PIXEL
  uniform Image depthTex;    // the frame's own depth, detached to read
  uniform Image sunMap;      // the sun's answer (see ShadowMap)
  uniform Image leafTex;     // the unseen foliage, tiling
  uniform mat4 vp;
  uniform mat4 sunVP;
  uniform float sunBias;
  uniform vec3 eye;
  uniform vec3 curve;        // xy = the focus in world XZ, z = k; 0 = off
  uniform vec2 screen;       // canvas size, for the pixel's own uv
  uniform vec4 fogW;         // density, heightK, canopyY, fadeTo
  uniform vec3 shear;        // the noon shear kx, kz; z = reach
  uniform vec3 rayColor;
  uniform float strength;
  uniform vec3 sunward;      // unit, toward the unseen sun
  uniform vec2 wind;         // leaf-field drift, uv per second
  uniform float time;
  // the viewport, as the scene shader takes it (see Voxel3D): air outside
  // the model is not air, so a sample out there contributes nothing and
  // the beams end with the world they fall through
  uniform vec3 cullAt;
  uniform vec3 cullShape;
  uniform vec2 cullRect;     // the box's half-extents in x and z

  float dioramaCull(vec3 p) {
    if (cullShape.z <= 0.5) return 1.0;
    vec3 cd = p - cullAt;
    float inside;
    if (cullShape.z < 1.5) {                 // the box
      inside = min(cullRect.x - abs(cd.x), cullRect.y - abs(cd.z));
    } else if (cullShape.z < 2.5) {
      inside = cullShape.x - length(cd);     // the ball
    } else {
      inside = cullShape.x - length(cd.xz);  // the fight's pillar
    }
    return clamp(inside * cullShape.y, 0.0, 1.0);
  }

  float sunDepth(vec2 uv) {
    vec4 c = Texel(sunMap, uv);
    return c.r + c.g * (1.0 / 255.0);
  }

  vec4 effect(vec4 color, Image tex, vec2 tc, vec2 sc) {
    vec2 uv = sc / screen;
    float sceneD = Texel(depthTex, uv).r;
    vec3 dir = normalize(vRay);
    // Spend every sample where a sample can glow. Above the canopy no
    // beam exists, and below the floor there is no air at all -- so the
    // march runs from where this ray first dips under the leaves to
    // where it would pass the ground, however long or short that
    // stretch is. From the orbit camera that is the last few dozen
    // pixels of a mostly-vertical ray, and dividing the WHOLE reach by
    // the step count there starved the beams to nothing.
    float t0 = 0.0;
    if (eye.y > fogW.z) {
      if (dir.y >= -0.01) return vec4(0.0);
      t0 = (eye.y - fogW.z) / -dir.y;
    }
    float tEnd = shear.z;
    if (dir.y < -0.01) {
      tEnd = min(tEnd, (eye.y + 8.0) / -dir.y);
    }
    if (tEnd <= t0) return vec4(0.0);
    // interleaved gradient noise staggers neighbouring pixels' steps,
    // which is what turns 20-odd samples into a smooth volume instead
    // of an onion of banded slices
    float jitter = fract(52.9829189
                         * fract(dot(sc, vec2(0.06711056, 0.00583715))));
    float dt = (tEnd - t0) / float(STEPS);
    // HALF the fog's own extinction, on the way in and per step: the
    // full rate is what the surfaces sink by, and beams that obeyed it
    // too died before the orbit camera ever saw them. Half keeps the
    // depth cue and leaves the light alive.
    float trans = exp(-fogW.x * 0.5 * t0);
    float acc = 0.0;
    for (int i = 0; i < STEPS; i++) {
      float t = t0 + (float(i) + jitter) * dt;
      vec3 p = eye + dir * t;
      // stop at the surface: bend the sample the way the geometry bent
      vec2 cd = p.xz - curve.xy;
      vec4 c = vp * vec4(p.x, p.y - dot(cd, cd) * curve.z, p.z, 1.0);
      if (c.w <= 1e-6) break;
      if (c.z / c.w * 0.5 + 0.5 > sceneD) break;
      if (p.y < fogW.z) {
        // the sun's question: is this air behind a tree? Outside the
        // frustum nothing was recorded and the air counts as lit, eased
        // at the rim exactly like the scene shader's shadows
        float lit = 1.0;
        vec3 su = (sunVP * vec4(p, 1.0)).xyz;
        if (su.x > 0.0 && su.x < 1.0 && su.y > 0.0 && su.y < 1.0
            && su.z < 1.0) {
          vec2 e2 = min(su.xy, 1.0 - su.xy);
          float edge = smoothstep(0.0, 0.06, min(e2.x, e2.y));
          lit = mix(1.0, step(su.z - sunBias, sunDepth(su.xy)), edge);
        }
        // the canopy's question: where did this thread of light pierce
        // the leaves? Every step of air on one sun ray shares the
        // answer -- that shared point is what makes a shaft a shaft --
        // and the two drifting reads of the field are the wind moving
        // the foliage overhead, opening and closing the beams
        float up = fogW.z - p.y;
        vec2 gap = (p.xz - shear.xy * up) * (1.0 / 96.0);
        float n = Texel(leafTex, gap + wind * time).r * 0.65
                + Texel(leafTex, gap * 2.3 - wind * (time * 0.7)
                        + vec2(0.37, 0.61)).r * 0.35;
        float dapple = 0.08 + 0.92 * smoothstep(0.45, 0.85, n);
        // the beam fades IN below the invisible canopy, thins with
        // altitude like the haze it is made of, and kisses the floor
        float y = max(p.y, 0.0);
        float fadeIn = clamp(up / max(fogW.z - fogW.w, 1.0), 0.0, 1.0);
        float foot = 0.55 + 0.45 * clamp(y / 16.0, 0.0, 1.0);
        float dens = fogW.x * exp(-y * fogW.y);
        acc += trans * lit * dapple * fadeIn * foot * dens * dt
               * dioramaCull(p);
      }
      trans *= exp(-fogW.x * 0.5 * dt);
    }
    // forward scattering: beams bloom for a camera looking up into the
    // light, which is most of what makes them read as light IN air
    float phase = 0.35 + 0.65 * pow(max(dot(dir, sunward), 0.0), 6.0);
    return vec4(rayColor * (acc * strength * phase), 1.0) * color;
  }
#endif
]]

local function rayShaderFor(steps)
  local key = "ray" .. steps
  local s = shaders[key]
  if s ~= nil then return s or nil end
  if not (love and love.graphics and love.graphics.newShader) then
    shaders[key] = false
    return nil
  end
  local src = "#define STEPS " .. steps .. "\n" .. RAY_SHADER
  local ok, sh = pcall(love.graphics.newShader, src)
  if not ok then
    say(key, "ray shader refused -- beams off, fog stays: "
        .. tostring(sh))
  end
  shaders[key] = (ok and sh) or false
  return shaders[key] or nil
end

local RAY_FORMAT = {
  { "VertexPosition", "float", 2 },
  { "RayDir", "float", 3 },
}

-- The camera's frustum corners, from the same fields every pass sets:
-- eye, focus, fovY, and the placed camera's up when there is one (VR
-- eyes roll; the orbit never does). Interpolating a corner ray across
-- the quad IS the standard reconstruction for a perspective camera, so
-- this works identically for the orbit, first person and both eyes.
local function rayQuad(Voxel3D, w, h)
  local e, fo, fov = Voxel3D.eye, Voxel3D.focus, Voxel3D.fovY
  if not (e and fo and fov) then return nil end
  local fx, fy, fz = fo[1] - e[1], fo[2] - e[2], fo[3] - e[3]
  local fl = sqrt(fx * fx + fy * fy + fz * fz)
  if fl < 1e-6 then return nil end
  fx, fy, fz = fx / fl, fy / fl, fz / fl
  local cam = Voxel3D.camera
  local up = (cam and cam.up) or { 0, 1, 0 }
  -- right = forward x up, then a true up perpendicular to both
  local rx = fy * up[3] - fz * up[2]
  local ry = fz * up[1] - fx * up[3]
  local rz = fx * up[2] - fy * up[1]
  local rl = sqrt(rx * rx + ry * ry + rz * rz)
  if rl < 1e-6 then return nil end
  rx, ry, rz = rx / rl, ry / rl, rz / rl
  local ux = ry * fz - rz * fy
  local uy = rz * fx - rx * fz
  local uz = rx * fy - ry * fx
  local hh = math.tan(fov * 0.5)
  local hw = hh * (w / h)
  -- canvas row 0 is the TOP of the frame, which is the +up corner
  local function corner(su, sv)
    return fx + rx * hw * su + ux * hh * sv,
           fy + ry * hw * su + uy * hh * sv,
           fz + rz * hw * su + uz * hh * sv
  end
  local x0, y0, z0 = corner(-1, 1)
  local x1, y1, z1 = corner(1, 1)
  local x2, y2, z2 = corner(1, -1)
  local x3, y3, z3 = corner(-1, -1)
  local verts = {
    { 0, 0, x0, y0, z0 },
    { w, 0, x1, y1, z1 },
    { w, h, x2, y2, z2 },
    { 0, h, x3, y3, z3 },
  }
  if not rayMesh then
    local ok, mesh = pcall(love.graphics.newMesh, RAY_FORMAT, verts,
                           "fan", "stream")
    rayMesh = ok and mesh or nil
    return rayMesh
  end
  local ok = pcall(rayMesh.setVertices, rayMesh, verts)
  return ok and rayMesh or nil
end

-- ------- the particles

local PART_SHADER = [[
  varying vec2 vCorner;
  varying float vGlow;
#ifdef VERTEX
  uniform mat4 vp;
  uniform vec3 curve;
  uniform vec3 cullAt;     // the viewport (see Voxel3D.cull): a mote
  uniform vec3 cullShape;  // outside the model is not in the air
  uniform vec2 cullRect;   // the box's half-extents in x and z
  uniform vec3 axisR;      // the camera's right, world space
  uniform vec3 axisU;      // and its up: the billboard's own frame
  uniform float time;
  uniform float size;
  uniform vec2 sway;       // wander amplitude: horizontal, vertical
  uniform float blinky;    // 0 = steady motes, 1 = blinking fireflies
  attribute vec4 AtmosData;    // corner x, corner y, phase, rate
  vec4 position(mat4 transform_projection, vec4 vertex_position) {
    float ph = AtmosData.z;
    float rt = AtmosData.w;
    float t = time * (0.5 + rt);
    // bounded wander only -- three incommensurate sines, so nothing ever
    // walks off the map or needs a CPU tick to bring it home
    vec3 base = vertex_position.xyz + vec3(
      sin(t * 0.23 + ph) * sway.x,
      sin(t * 0.17 + ph * 2.7) * sway.y,
      cos(t * 0.19 + ph * 1.3) * sway.x);
    float s = 0.5 + 0.5 * sin(t * 1.6 + ph * 9.0);
    vGlow = mix(1.0, smoothstep(0.35, 0.75, s), blinky);
    // a whole mote at once: these are points, so the rim can dim them
    // rather than having to cut one in half
    if (cullShape.z > 0.5) {
      vec3 cd = base - cullAt;
      float inside;
      if (cullShape.z < 1.5) {
        inside = min(cullRect.x - abs(cd.x), cullRect.y - abs(cd.z));
      } else if (cullShape.z < 2.5) {
        inside = cullShape.x - length(cd);
      } else {
        inside = cullShape.x - length(cd.xz);
      }
      vGlow *= clamp(inside * cullShape.y, 0.0, 1.0);
    }
    vCorner = AtmosData.xy;
    vec4 w = vec4(base + axisR * (AtmosData.x * size)
                       + axisU * (AtmosData.y * size), 1.0);
    if (curve.z > 0.0) {
      vec2 cd = w.xz - curve.xy;
      w.y -= dot(cd, cd) * curve.z;
    }
    return vp * w;
  }
#endif
#ifdef PIXEL
  uniform vec3 dotColor;
  uniform float level;
  vec4 effect(vec4 color, Image tex, vec2 tc, vec2 sc) {
    float d = dot(vCorner, vCorner);
    float glow = max(0.0, 1.0 - d);
    glow *= glow;
    return vec4(dotColor, glow * level * vGlow) * color;
  }
#endif
]]

local function partShader()
  local s = shaders.part
  if s ~= nil then return s or nil end
  if not (love and love.graphics and love.graphics.newShader) then
    shaders.part = false
    return nil
  end
  local ok, sh = pcall(love.graphics.newShader, PART_SHADER)
  shaders.part = (ok and sh) or false
  return shaders.part or nil
end

local PART_FORMAT = {
  { "VertexPosition", "float", 3 },
  { "AtmosData", "float", 4 },
}

local CORNERS = { { -1, -1 }, { 1, -1 }, { 1, 1 }, { -1, 1 } }

local function pushQuad(map, n)
  local b = n * 4
  map[#map + 1] = b + 1
  map[#map + 1] = b + 2
  map[#map + 1] = b + 3
  map[#map + 1] = b + 1
  map[#map + 1] = b + 3
  map[#map + 1] = b + 4
end

local function buildPartMesh(points)
  if #points == 0 then return nil end
  local verts, indices = {}, {}
  for i = 1, #points do
    local p = points[i]
    for c = 1, 4 do
      verts[#verts + 1] = { p.x, p.y, p.z,
                            CORNERS[c][1], CORNERS[c][2], p.phase, p.rate }
    end
    pushQuad(indices, i - 1)
  end
  local ok, mesh = pcall(love.graphics.newMesh, PART_FORMAT, verts,
                         "triangles", "static")
  if not ok then return nil end
  pcall(mesh.setVertexMap, mesh, indices)
  return mesh
end

local function meshesFor(map, L)
  local hit = meshCache[map.id]
  if hit then return hit end
  local M = {
    motes = buildPartMesh(L.motes),
    flies = buildPartMesh(L.flies),
  }
  meshCache[map.id] = M
  return M
end

local MOTE_COLOR = { 1.0, 0.96, 0.78 }
local FLY_COLOR = { 0.72, 1.0, 0.45 }

-- The billboard frame: the camera's own right and up, from the same
-- fields every pass sets (per VR eye too -- drawScene runs per eye and
-- reads the eye's camera). Degenerate looks answer nil and the
-- particles sit this one out.
local function billboardAxes(Voxel3D)
  local e, fo = Voxel3D.eye, Voxel3D.focus
  if not (e and fo) then return nil end
  local lx, ly, lz = fo[1] - e[1], fo[2] - e[2], fo[3] - e[3]
  local ll = sqrt(lx * lx + ly * ly + lz * lz)
  if ll < 1e-6 then return nil end
  lx, ly, lz = lx / ll, ly / ll, lz / ll
  local rx, rz = -lz, lx
  local rl = sqrt(rx * rx + rz * rz)
  if rl < 1e-4 then return nil end
  rx, rz = rx / rl, rz / rl
  return { rx, 0, rz }, { -rz * ly, rz * lx - rx * lz, rx * ly }
end

-- ------- the draw
--
-- Inside the scene pass, in VoxelScene's prop slot. The march borrows
-- the frame's depth through Voxel3D.beginWater -- the same detach Water
-- runs -- and hand-tests every step against it, so the pass itself needs
-- no depth attachment; the particles come after, depth-tested additive
-- geometry like the Stadium flames. Anything missing -- no entry, OFF, a
-- refused shader, no readable depth, no shadow map -- subtracts only
-- itself.
function ForestAtmos.draw(map)
  local rung = ForestAtmos.setting:get()
  if rung == "off" then return end
  local f = ForestAtmos.frame(map)
  if not f then return end
  local Voxel3D = V.require("Voxel3D")
  local ShadowMap = V.require("ShadowMap")

  if f.rayAlpha > 0.01 then
    if not Voxel3D.depthReadable() then
      say("depth", "no readable depth this frame -- beams off, fog stays")
      return
    end
    -- no beams without the sun's own pass: uvVP is only the world -> map
    -- transform while a shadow map is actually standing
    local sunTex = ShadowMap.active() and ShadowMap.texture()
    if not sunTex then
      say("sun", "no shadow map standing -- beams off, fog stays")
    end
    local leaf = leafTexture()
    if not leaf then
      say("leaf", "leaf field would not build -- beams off, fog stays")
    end
    local sh = rayShaderFor(rung == "low" and 12 or 24)
    local w, h = Voxel3D.size()
    local quad = (sh and sunTex and leaf and w) and rayQuad(Voxel3D, w, h)
    if sh and sunTex and leaf and w and not quad then
      say("quad", "no camera frame for the ray fan -- beams off")
    end
    if quad then
      local _, depth = Voxel3D.beginWater(nil)
      if depth then
        say("on", "volumetric beams running")
        local kx, kz = DayNight.shearAt(DayNight.isOpenForest(map) and DayNight.time() or DayNight.T.day)
        local kl = sqrt(kx * kx + kz * kz + 1)
        love.graphics.setBlendMode("add", "alphamultiply")
        love.graphics.setShader(sh)
        pcall(sh.send, sh, "depthTex", depth)
        pcall(sh.send, sh, "sunMap", sunTex)
        pcall(sh.send, sh, "leafTex", leaf)
        pcall(sh.send, sh, "vp", "row", Voxel3D.vp)
        pcall(sh.send, sh, "sunVP", "row", ShadowMap.uvVP)
        pcall(sh.send, sh, "sunBias", ShadowMap.bias)
        pcall(sh.send, sh, "eye", Voxel3D.eye)
        pcall(sh.send, sh, "curve",
              { Voxel3D.curveX or 0, Voxel3D.curveZ or 0,
                Voxel3D.curveK or 0 })
        pcall(sh.send, sh, "cullAt", cullAt())
        pcall(sh.send, sh, "cullShape", cullShape())
        pcall(sh.send, sh, "cullRect", cullRect())
        pcall(sh.send, sh, "screen", { w, h })
        pcall(sh.send, sh, "fogW",
              { f.fog.density, f.fog.heightK,
                f.cfg.canopyY or 56, f.cfg.fadeTo or 28 })
        pcall(sh.send, sh, "shear", { kx, kz, f.rayReach })
        pcall(sh.send, sh, "rayColor", f.rayColor)
        pcall(sh.send, sh, "strength", f.rayStrength * f.rayAlpha)
        pcall(sh.send, sh, "sunward", { -kx / kl, 1 / kl, -kz / kl })
        pcall(sh.send, sh, "wind", { 0.016, 0.009 })
        pcall(sh.send, sh, "time", ForestAtmos.time)
        pcall(love.graphics.draw, quad)
        love.graphics.setShader()
        love.graphics.setBlendMode("alpha")
      end
      Voxel3D.endWater()
    end
  end

  if rung == "full" then
    local L = layoutFor(map)
    local M = L and meshesFor(map, L)
    local psh = partShader()
    local axisR, axisU = billboardAxes(Voxel3D)
    if M and psh and axisR then
      Voxel3D.blend("add")
      if Voxel3D.beginEffect(psh) then
        pcall(psh.send, psh, "vp", "row", Voxel3D.vp)
        pcall(psh.send, psh, "curve",
              { Voxel3D.curveX or 0, Voxel3D.curveZ or 0,
                Voxel3D.curveK or 0 })
        pcall(psh.send, psh, "cullAt", cullAt())
        pcall(psh.send, psh, "cullShape", cullShape())
        pcall(psh.send, psh, "cullRect", cullRect())
        pcall(psh.send, psh, "axisR", axisR)
        pcall(psh.send, psh, "axisU", axisU)
        pcall(psh.send, psh, "time", ForestAtmos.time)
        if M.motes and f.moteLevel > 0.02 then
          pcall(psh.send, psh, "size", 1.4)
          pcall(psh.send, psh, "sway", { 5, 2.5 })
          pcall(psh.send, psh, "blinky", 0)
          pcall(psh.send, psh, "dotColor", MOTE_COLOR)
          pcall(psh.send, psh, "level", f.moteLevel * 0.5)
          pcall(love.graphics.draw, M.motes)
        end
        if M.flies and f.fireflyLevel > 0.02 then
          pcall(psh.send, psh, "size", 1.6)
          pcall(psh.send, psh, "sway", { 10, 4 })
          pcall(psh.send, psh, "blinky", 1)
          pcall(psh.send, psh, "dotColor", FLY_COLOR)
          pcall(psh.send, psh, "level", f.fireflyLevel * 0.85)
          pcall(love.graphics.draw, M.flies)
        end
        Voxel3D.endEffect()
      end
      Voxel3D.blend(nil)
    end
  end
end

return ForestAtmos
