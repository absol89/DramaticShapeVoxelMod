-- A Poke Ball as real geometry: the Legendary normal-battle capture prop.
--
-- The mod has never drawn a ball in 3D -- the one the engine tosses is a 2D
-- sprite inside the battle's move-animation layer. This is a ball that can
-- fly through the arena, hang in the air in front of the camera, hinge its
-- lid open, drink a Pokemon in, click shut, rock on the ground and burst
-- back open -- all of it depth-tested, sun-shadowed and hour-tinted like
-- everything else in the diorama, because it is a mesh in Voxel3D's own
-- format going through Voxel3D's own shader.
--
-- ------- how it is built
--
-- Two lat/long hemisphere shells that meet at the equator -- the WHITE base
-- and the coloured LID -- each carrying its half of the black band as a
-- slightly bulged latitude belt, so the two halves separate exactly where
-- the real ball separates. The button is a little cylinder standing out of
-- the base's front; the interior is sealed with two pale discs so an open
-- ball shows a shell with a floor rather than a view through to the far
-- wall's backface. Colour is a palette texture one texel per material and
-- one ROW per ball tier (POKE/GREAT/ULTRA/MASTER/SAFARI), exactly the
-- HordeGun/Pokedex scheme -- so GREAT is blue and ULTRA wears its yellow
-- band without a second mesh, just a different V coordinate.
--
-- Shade is baked per vertex from the surface normal with StadiumStage's
-- fitted constants, which is this mod's answer for anything curved: the
-- ball's sun side and belly read as a sphere under the same southeastern
-- sun the roofs are lit by.
--
-- ------- how it animates
--
-- The HordeGun way: a handful of scalar timers advanced by update(dt) and
-- consumed as matrix terms at draw time. No skeleton, no keyframes --
-- lid is a hinge matrix about the back of the equator, the wobble is a
-- decaying rotateZ about the ground contact point, the caught click is a
-- squash pulse, the stars are one shared quad drawn a few times facing the
-- eye. The ball owns its POSE only; where it IS (the throw arc, the drop)
-- is the caller's problem, which is what keeps this file a prop and not a
-- game mode.
--
-- Nothing here touches love.* until something has to be drawn, so the
-- module loads and the state machine runs headless -- the test suite
-- exercises the phases without a GPU.

-- the mod namespace (see main.lua): V.require loads a sibling module
local V = ...
local PokeballSettings = V.require("PokeballSettings")

local Mat4 = V.require("Mat4")
local Voxel3D = V.require("Voxel3D")

local Pokeball = {}
Pokeball.__index = Pokeball

-- ------- the ball's measurements, in world pixels
--
-- A map cell is 16 and a full-size mon card is 16 wide, so a 4.4-pixel ball
-- sits in the hand and against a Pokemon at about the proportion the games
-- draw: unmissable in the foreground, believable at the far cell.
Pokeball.R = 2.2

-- the black belt: half-height as a latitude angle, and how far the belt
-- bulges past the shell so it reads as a band and not a painted stripe
local BAND_LAT = 0.16
local BAND_R = 1.045

-- lid hinge: at the BACK of the equator (-Z), opening backward. 2.0 rad is
-- past upright -- the mouth gapes at the sky, which is the capture pose.
local HINGE_Z = -0.86           -- as a fraction of R
local LID_OPEN = 2.0

-- tessellation: enough that the silhouette is round at held-ball size,
-- cheap enough that six of these would not show on a phone's frame budget
local LON = 14
local LAT = 5

-- pose timing
local LID_RATE = 6.5            -- lid open/close, in lid-fractions per second
local BURST_RATE = 14           -- the breakout pop is a violent open
local WOBBLE_T = 0.70           -- TEST20: quicker, more aggressive rock
local WOBBLE_A = 0.64           -- TEST20: ~37 degrees, much more readable
local PULSE_T = 0.14            -- the caught click's squash pulse
local STAR_T = 1.55             -- TEST28: stronger successful-catch linger
local GLOW_DECAY = 2.2          -- additive glow, per second

-- ------- palette
--
-- One texel per material (columns), one row per ball tier. Alpha stays 1
-- everywhere: the voxel shader discards below 0.5 (Voxel3D's SHADER), so a
-- translucent texel is an invisible one.
local SLOTS = { TOP = 1, BOTTOM = 2, BAND = 3, RING = 4, FACE = 5,
                INNER = 6, GLOW = 7, STAR = 8 }
local SLOT_N = 8

local TIERS = { "POKE_BALL", "GREAT_BALL", "ULTRA_BALL", "MASTER_BALL",
                "SAFARI_BALL" }

local COLORS = {
  POKE_BALL   = { top = { 0.94, 0.18, 0.18 }, band = { 0.09, 0.09, 0.10 },
                  bottom = { 1.00, 1.00, 1.00 } },
  GREAT_BALL  = { top = { 0.30, 0.52, 0.98 }, band = { 0.09, 0.09, 0.10 },
                  bottom = { 1.00, 1.00, 1.00 } },
  ULTRA_BALL  = { top = { 0.18, 0.18, 0.21 }, band = { 0.98, 0.82, 0.20 },
                  bottom = { 1.00, 1.00, 1.00 } },
  MASTER_BALL = { top = { 0.62, 0.20, 0.88 }, band = { 0.10, 0.07, 0.15 },
                  bottom = { 1.00, 0.98, 1.00 },
                  glow = { 1.00, 0.42, 0.78 } },
  SAFARI_BALL = { top = { 0.47, 0.52, 0.26 }, band = { 0.36, 0.27, 0.16 },
                  bottom = { 0.90, 0.88, 0.80 } },
}

local SHARED = {
  ring  = { 0.28, 0.28, 0.30 },
  face  = { 0.96, 0.96, 0.97 },
  inner = { 0.72, 0.70, 0.68 },
  glow  = { 1.00, 0.92, 0.65 },
  star  = { 1.00, 0.85, 0.25 },
}

local function tierRow(ball)
  for i, id in ipairs(TIERS) do
    if id == ball then return i end
  end
  return 1                       -- an unknown ball is a plain POKE BALL
end

-- palette texel centres
local function uvFor(slot, row)
  return (slot - 0.5) / SLOT_N, (row - 0.5) / #TIERS
end

local palette = nil
local function paletteTexture()
  if palette ~= nil then return palette or nil end
  local ok, img = pcall(function()
    local data = love.image.newImageData(SLOT_N, #TIERS)
    for row, id in ipairs(TIERS) do
      local c = COLORS[id]
      local function put(slot, rgb)
        data:setPixel(slot - 1, row - 1, rgb[1], rgb[2], rgb[3], 1)
      end
      put(SLOTS.TOP, c.top)
      put(SLOTS.BOTTOM, c.bottom)
      put(SLOTS.BAND, c.band)
      put(SLOTS.RING, SHARED.ring)
      put(SLOTS.FACE, SHARED.face)
      put(SLOTS.INNER, SHARED.inner)
      put(SLOTS.GLOW, c.glow or SHARED.glow)
      put(SLOTS.STAR, SHARED.star)
    end
    local tex = love.graphics.newImage(data)
    tex:setFilter("nearest", "nearest")
    return tex
  end)
  palette = ok and img or false
  return palette or nil
end

-- ------- shade
--
-- StadiumStage's fitted form of Voxel3D.FACE_SHADE: the same southeastern
-- sun, answered for an arbitrary normal instead of one of six faces.
local function shadeFor(nx, ny, nz)
  local s = 0.7725 + nx * 0.06 + ny * 0.225 + nz * 0.11
  return math.max(0.30, math.min(1.00, s))
end

-- ------- mesh building
--
-- Everything below appends {x,y,z, u,v, shade} rows plus triangle indices.
-- Quads go through the shared corner order; the discs use a degenerate
-- fourth vertex, which the rasteriser drops as the zero-area triangle it is.
local function quad(verts, map, a, b, c, d)
  local n = #verts
  verts[n + 1], verts[n + 2], verts[n + 3], verts[n + 4] = a, b, c, d
  Voxel3D.pushQuad(map, n / 4)
end

local R = Pokeball.R
local TAU = math.pi * 2

-- a latitude zone of the sphere between phi0 and phi1 (radians from the
-- equator, north positive), at radiusK times the shell radius
local function zone(verts, map, phi0, phi1, rows, slot, row, radiusK)
  local u, v = uvFor(slot, row)
  local r = R * (radiusK or 1)
  for i = 0, rows - 1 do
    local pa = phi0 + (phi1 - phi0) * (i / rows)
    local pb = phi0 + (phi1 - phi0) * ((i + 1) / rows)
    for j = 0, LON - 1 do
      local ta = TAU * (j / LON)
      local tb = TAU * ((j + 1) / LON)
      local function corner(phi, th)
        local nx = math.cos(phi) * math.sin(th)
        local ny = math.sin(phi)
        local nz = math.cos(phi) * math.cos(th)
        return { nx * r, ny * r, nz * r, u, v, shadeFor(nx, ny, nz) }
      end
      quad(verts, map, corner(pa, ta), corner(pa, tb),
                       corner(pb, tb), corner(pb, ta))
    end
  end
end

-- a disc in a y-plane, sealed with fan quads about the centre
local function disc(verts, map, y, radius, slot, row, up)
  local u, v = uvFor(slot, row)
  local sh = shadeFor(0, up and 1 or -1, 0)
  local centre = { 0, y, 0, u, v, sh }
  for j = 0, LON - 1 do
    local ta = TAU * (j / LON)
    local tb = TAU * ((j + 1) / LON)
    local a = { radius * math.sin(ta), y, radius * math.cos(ta), u, v, sh }
    local b = { radius * math.sin(tb), y, radius * math.cos(tb), u, v, sh }
    quad(verts, map, centre, a, b, centre)
  end
end

-- the button: a ring wall and its face, standing out of the shell along +Z
local function button(verts, map, row)
  local BLON = 10
  local function ringWall(rad, z0, z1, slot)
    local u, v = uvFor(slot, row)
    for j = 0, BLON - 1 do
      local ta = TAU * (j / BLON)
      local tb = TAU * ((j + 1) / BLON)
      local function at(th, z)
        local nx, ny = math.cos(th), math.sin(th)
        return { rad * nx, rad * ny, z, u, v, shadeFor(nx, ny, 0) }
      end
      quad(verts, map, at(ta, z0), at(tb, z0), at(tb, z1), at(ta, z1))
    end
  end
  local function faceDisc(rad, z, slot)
    local u, v = uvFor(slot, row)
    local sh = shadeFor(0, 0, 1)
    local centre = { 0, 0, z, u, v, sh }
    for j = 0, BLON - 1 do
      local ta = TAU * (j / BLON)
      local tb = TAU * ((j + 1) / BLON)
      local a = { rad * math.cos(ta), rad * math.sin(ta), z, u, v, sh }
      local b = { rad * math.cos(tb), rad * math.sin(tb), z, u, v, sh }
      quad(verts, map, centre, a, b, centre)
    end
  end
  -- the wall starts inside the shell so the junction never shows a gap
  ringWall(0.75, R * 0.90, R + 0.30, SLOTS.RING)
  faceDisc(0.75, R + 0.30, SLOTS.RING)
  ringWall(0.45, R + 0.30, R + 0.42, SLOTS.RING)
  faceDisc(0.45, R + 0.42, SLOTS.FACE)
end

-- one tier's meshes, memoised: { base = , lid = , spark = }
--
-- spark is a shared unit card (x -0.5..0.5, y 0..1, z 0) wearing one texel;
-- the glow disc, the beam and every star are that card under a matrix.
local meshes = {}
local function meshesFor(ball)
  local row = tierRow(ball)
  local hit = meshes[row]
  if hit ~= nil then return hit or nil end

  local ok, built = pcall(function()
    local bv, bm = {}, {}
    -- the base: white bowl from the south pole up to the band, its half of
    -- the band, the interior floor and the button on the front
    zone(bv, bm, -math.pi / 2, -BAND_LAT, LAT, SLOTS.BOTTOM, row)
    zone(bv, bm, -BAND_LAT, 0, 1, SLOTS.BAND, row, BAND_R)
    disc(bv, bm, -0.06, R * 0.97, SLOTS.INNER, row, true)
    button(bv, bm, row)

    local lv, lm = {}, {}
    -- the lid: its half of the band up to the coloured dome, and its pale
    -- underside, which is what shows once the hinge tips it back
    zone(lv, lm, 0, BAND_LAT, 1, SLOTS.BAND, row, BAND_R)
    zone(lv, lm, BAND_LAT, math.pi / 2, LAT, SLOTS.TOP, row)
    disc(lv, lm, 0.06, R * 0.97, SLOTS.INNER, row, false)

    -- TEST45: Master Ball-specific raised geometry.
    -- The generic sphere/colors made the Master Ball read flat compared with
    -- the Pokeball. Add raised crown lobes and a chunky M badge directly to
    -- the lid mesh so they rotate/open with the shell.
    if ball == "MASTER_BALL" then
      local function boxPatch(cx, cy, cz, sx, sy, sz, slot)
        local u, v = uvFor(slot, row)
        local function P(x,y,z,sh) return {x,y,z,u,v,sh or 1.0} end
        local x0,x1=cx-sx,cx+sx
        local y0,y1=cy-sy,cy+sy
        local z0,z1=cz-sz,cz+sz
        quad(lv,lm,P(x0,y0,z1),P(x1,y0,z1),P(x1,y1,z1),P(x0,y1,z1))
        quad(lv,lm,P(x1,y0,z0),P(x0,y0,z0),P(x0,y1,z0),P(x1,y1,z0))
        quad(lv,lm,P(x0,y0,z0),P(x0,y0,z1),P(x0,y1,z1),P(x0,y1,z0))
        quad(lv,lm,P(x1,y0,z1),P(x1,y0,z0),P(x1,y1,z0),P(x1,y1,z1))
        quad(lv,lm,P(x0,y1,z1),P(x1,y1,z1),P(x1,y1,z0),P(x0,y1,z0))
      end

      -- Pink crown/ear lobes, raised above the purple dome.
      boxPatch(-R*0.52, R*0.58, R*0.64, R*0.20, R*0.18, R*0.10, SLOTS.GLOW)
      boxPatch( R*0.52, R*0.58, R*0.64, R*0.20, R*0.18, R*0.10, SLOTS.GLOW)

      -- Chunky white "M": two uprights plus the center strokes.
      boxPatch(-R*0.26, R*0.43, R*0.88, R*0.075, R*0.23, R*0.055, SLOTS.FACE)
      boxPatch( R*0.26, R*0.43, R*0.88, R*0.075, R*0.23, R*0.055, SLOTS.FACE)
      boxPatch(-R*0.10, R*0.48, R*0.91, R*0.075, R*0.16, R*0.055, SLOTS.FACE)
      boxPatch( R*0.10, R*0.48, R*0.91, R*0.075, R*0.16, R*0.055, SLOTS.FACE)
    end

    local base = Voxel3D.newMesh(bv, bm)
    local lid = Voxel3D.newMesh(lv, lm)
    if not (base and lid) then return nil end

    local function card(slot)
      local u, v = uvFor(slot, row)
      local cv, cm = {}, {}
      quad(cv, cm, { -0.5, 0, 0, u, v, 1 }, { 0.5, 0, 0, u, v, 1 },
                   { 0.5, 1, 0, u, v, 1 }, { -0.5, 1, 0, u, v, 1 })
      return Voxel3D.newMesh(cv, cm)
    end
    -- TEST34: real low-poly smoke puff mesh.
    -- Six quads make a tiny beveled-looking cube; clusters of these expanding
    -- and drifting read as chunky 3D smoke without touching love.graphics.
    local function puffMesh()
      local pv, pm = {}, {}
      local u, v = uvFor(SLOTS.FACE, row)
      local function P(x,y,z,sh) return {x,y,z,u,v,sh or 0.92} end
      local s = 0.5
      -- front/back
      quad(pv,pm,P(-s,-s, s),P( s,-s, s),P( s, s, s),P(-s, s, s))
      quad(pv,pm,P( s,-s,-s),P(-s,-s,-s),P(-s, s,-s),P( s, s,-s))
      -- left/right
      quad(pv,pm,P(-s,-s,-s),P(-s,-s, s),P(-s, s, s),P(-s, s,-s))
      quad(pv,pm,P( s,-s, s),P( s,-s,-s),P( s, s,-s),P( s, s, s))
      -- top/bottom
      quad(pv,pm,P(-s, s, s),P( s, s, s),P( s, s,-s),P(-s, s,-s))
      quad(pv,pm,P(-s,-s,-s),P( s,-s,-s),P( s,-s, s),P(-s,-s, s))
      return Voxel3D.newMesh(pv, pm)
    end

    -- TEST38: actual shell reflection patch. This is geometry sitting
    -- slightly above the sphere and using the bright FACE material, so it is
    -- visibly white regardless of additive-glow intensity.
    local function shinePatch()
      local sv, sm = {}, {}
      local u, v = uvFor(SLOTS.FACE, row)
      local rr = R * 1.025

      -- Small curved patch on the upper/front-left hemisphere.
      local phi0, phi1 = 0.28, 0.82
      local th0, th1 = -0.72, -0.04
      local rows, cols = 3, 4

      local function at(phi, th)
        local nx = math.cos(phi) * math.sin(th)
        local ny = math.sin(phi)
        local nz = math.cos(phi) * math.cos(th)
        return { nx*rr, ny*rr, nz*rr, u, v, 1.0 }
      end

      for iy = 0, rows-1 do
        local pa = phi0 + (phi1-phi0)*(iy/rows)
        local pb_ = phi0 + (phi1-phi0)*((iy+1)/rows)
        for ix = 0, cols-1 do
          local ta = th0 + (th1-th0)*(ix/cols)
          local tb = th0 + (th1-th0)*((ix+1)/cols)
          quad(sv, sm, at(pa,ta), at(pa,tb), at(pb_,tb), at(pb_,ta))
        end
      end
      return Voxel3D.newMesh(sv, sm)
    end

    return { base = base, lid = lid,
             glow = card(SLOTS.GLOW), star = card(SLOTS.STAR),
             puff = puffMesh(), shine = shinePatch() }
  end)
  meshes[row] = (ok and built) or false
  return meshes[row] or nil
end

-- dropped so a lost GL context (Android resume) rebuilds everything
function Pokeball.invalidate()
  meshes = {}
  palette = nil
end

-- ------- an instance: one ball with a pose
--
-- Loads and runs without graphics; only draw() and cast() want a GPU.
function Pokeball.new(ball)
  return setmetatable({
    ball = ball or "POKE_BALL",
    pos = { 0, 0, 0 },          -- world pixels, the ball's CENTRE
    yaw = 0,                    -- which way the button faces
    scale = PokeballSettings.scale(), -- TEST61: live menu-controlled size
    glossT = 0,                -- TEST43: animated shell reflection clock
    impactFx = nil,              -- TEST60: hit/suction burst
    trail = {},                 -- TEST54: recent airborne positions
    trailClock = 0,
    spin = 0,                   -- visual spin about the vertical, rad/s
    tumble = 0,                 -- end-over-end in flight, rad/s
    roll = 0,                   -- SCREEN-PLANE spin, rad/s: rotation about
                                -- the axis out of the ball's face, which
                                -- with the yaw at the camera reads as the
                                -- ball turning clockwise/counter-clockwise
                                -- to the viewer -- the curveball wind-up
    spinAngle = 0, tumbleAngle = 0, rollAngle = 0,
    lid = 0, lidTarget = 0, lidRate = LID_RATE,
    wobbleT = nil, wobbleDir = 1,
    pulse = nil,                -- the caught click's squash
    glow = 0,
    stars = nil,                -- caught celebration, or nil
    visible = true,
  }, Pokeball)
end

-- ------- the verbs the capture flow speaks

function Pokeball:open()
  -- TEST62: brief visual intake hold; mechanics remain authoritative.
  self.intakeHold = 0.34
  -- TEST60: contact burst starts exactly with the proven ball-open event.
  local mult = 1
  if self.ball == "GREAT_BALL" then mult = 1.25 end
  if self.ball == "ULTRA_BALL" then mult = 1.55 end
  if self.ball == "MASTER_BALL" then mult = 2.05 end
  self.impactFx = { t = 0, life = 0.72, mult = mult }
  self.lidTarget, self.lidRate = 1, LID_RATE
  self.glow = 1
end

function Pokeball:close()
  self.lidTarget, self.lidRate = 0, LID_RATE
end

-- one rock on the ground; dir alternates shakes. Returns how long it takes,
-- so the caller can sequence the pauses between shakes.
function Pokeball:rock(dir)
  self.wobbleT = 0
  self.wobbleDir = dir or 1
  return WOBBLE_T
end

-- the caught click: squash pulse, a soft flash, and the stars

-- TEST29: 3D failed-capture breakout burst.
-- This is visual-only and is triggered by the already-established escape/open event.
function Pokeball:breakoutBurst(countOverride)
  self.breakoutFx = { t = 0, life = 0.90 }
  self.glow = math.max(self.glow or 0, 0.88)

  local puffs = {}
  local count = countOverride or 96 -- TEST97: caller may reuse proven puff renderer at lower density
  for i = 1, count do
    local th = TAU * (i - 1) / count + ((i % 3) * 0.11)
    puffs[i] = {
      t = -0.012 * (i - 1),
      life = 1.05 + (i % 5) * 0.10,
      th = th,
      speed = 4.2 + (i % 8) * 0.55,
      rise = 4.0 + (i % 7) * 0.52,
      size = 1.90 + (i % 5) * 0.30,
      spin = ((i % 2)==0 and 1 or -1) * (1.2 + (i % 3)*0.35),
    }
  end
  self.breakoutPuffs = puffs
end

function Pokeball:catchClick()
  local starMult = PokeballSettings.starMult()
  -- TEST47: tiered epic captures.
  -- Standard/Great = 1x, Ultra = 2x, Master = 4x.
  local mult = 1
  if self.ball == "ULTRA_BALL" then mult = 2 end
  if self.ball == "MASTER_BALL" then mult = 4 end

  self.catchFx = {
    t = 0,
    life = 2.85 + 0.28 * (mult - 1),
    count = math.floor(42 * mult * starMult + 0.5),
    rings = math.max(0, math.floor((4 + mult) * starMult + 0.5)),
    epicMult = mult,
    masterEpic = (self.ball == "MASTER_BALL")
  }
  self.glow = math.max(self.glow or 0, 1.0 + 0.18 * mult)
end

-- the breakout: the lid blown open and a hard flash
function Pokeball:burst()
  self.lidTarget, self.lidRate = 1, BURST_RATE * 1.65
  self.glow = 1
end

function Pokeball:busy()
  return self.wobbleT ~= nil or self.pulse ~= nil
      or math.abs(self.lid - self.lidTarget) > 0.02
end

function Pokeball:update(dt)
  if self.intakeHold and self.intakeHold > 0 then
    self.intakeHold = math.max(0, self.intakeHold - dt)
  end
  -- TEST61: size is live; menu changes do not require a reload/new battle.
  self.scale = PokeballSettings.scale()
  -- TEST60: short-lived contact/suction animation clock.
  if self.impactFx then
    self.impactFx.t = self.impactFx.t + dt
    if self.impactFx.t >= self.impactFx.life then self.impactFx = nil end
  end
  -- TEST56: safe throw-only trail sampling.
  self.trailClock = (self.trailClock or 0) + dt
  if self.phase == "throw" then
    if self.trailClock >= 0.024 then
      self.trailClock = 0
      local tr = self.trail or {}
      table.insert(tr, 1, { self.pos[1], self.pos[2], self.pos[3] })
      while #tr > 9 do table.remove(tr) end
      self.trail = tr
    end
  else
    self.trail = {}
  end

  -- TEST43: continuous moving gloss. Independent from gameplay/capture timing.
  self.glossT = (self.glossT or 0) + dt

  -- TEST42: TEST41 created catchFx but never advanced its timer.
  if self.catchFx then
    self.catchFx.t = (self.catchFx.t or 0) + dt
    if self.catchFx.t >= (self.catchFx.life or 2.35) then
      self.catchFx = nil
    end
  end
  if self.breakoutPuffs then
    local live = false
    for _,p in ipairs(self.breakoutPuffs) do
      p.t = (p.t or 0) + dt
      if p.t < p.life then live = true end
    end
    if not live then self.breakoutPuffs = nil end
  end
  if self.breakoutFx then
    self.breakoutFx.t = (self.breakoutFx.t or 0) + dt
    if self.breakoutFx.t >= (self.breakoutFx.life or 0.62) then
      self.breakoutFx = nil
    end
  end
  -- lid toward its target, at whatever violence was asked for
  local d = self.lidTarget - self.lid
  if d ~= 0 then
    local step = self.lidRate * dt
    if math.abs(d) <= step then
      -- arriving CLOSED from open is the shut click: the squash pulse
      if self.lid > self.lidTarget then self.pulse = self.pulse or 0 end
      self.lid = self.lidTarget
    else
      self.lid = self.lid + (d > 0 and step or -step)
    end
  end
  if self.wobbleT then
    self.wobbleT = self.wobbleT + dt
    if self.wobbleT >= WOBBLE_T then self.wobbleT = nil end
  end
  if self.pulse then
    self.pulse = self.pulse + dt
    if self.pulse >= PULSE_T then self.pulse = nil end
  end
  if self.stars then
    local live = false
    for _, s in ipairs(self.stars) do
      s.t = s.t + dt
      if s.t < STAR_T then live = true end
    end
    if not live then self.stars = nil
  self.breakoutFx = nil end
  end
  self.glow = math.max(0, self.glow - GLOW_DECAY * dt)
  self.spinAngle = self.spinAngle + self.spin * dt
  self.tumbleAngle = self.tumbleAngle + self.tumble * dt
  self.rollAngle = self.rollAngle + self.roll * dt
end

-- ------- pose as a matrix

local function smooth(t)
  if t <= 0 then return 0 end
  if t >= 1 then return 1 end
  return t * t * (3 - 2 * t)
end

function Pokeball:matrix()
  local m = Mat4.mul(Mat4.translate(self.pos[1], self.pos[2], self.pos[3]),
                     Mat4.rotateY(self.yaw))
  if self.wobbleT then
    -- a decaying rock about the ground contact: tip, cross through centre,
    -- tip the other way, settle
    local t = self.wobbleT / WOBBLE_T
    local a = WOBBLE_A * math.sin(TAU * t) * (1 - t) * self.wobbleDir
    m = Mat4.mul(m, Mat4.mul(Mat4.translate(0, -R * self.scale, 0),
                 Mat4.mul(Mat4.rotateZ(a),
                          Mat4.translate(0, R * self.scale, 0))))
  end
  if self.spinAngle ~= 0 then m = Mat4.mul(m, Mat4.rotateY(self.spinAngle)) end
  if self.tumbleAngle ~= 0 then
    m = Mat4.mul(m, Mat4.rotateX(self.tumbleAngle))
  end
  -- the roll turns about the ball's own face axis, so with the yaw aimed
  -- at the camera it reads as clockwise/counter-clockwise on screen
  if self.rollAngle ~= 0 then
    m = Mat4.mul(m, Mat4.rotateZ(self.rollAngle))
  end
  local k = self.scale
  if self.pulse then
    -- the click: a quick squash and back, more felt than seen
    local p = math.sin((self.pulse / PULSE_T) * math.pi) * 0.14
    m = Mat4.mul(m, Mat4.scale(k * (1 + p), k * (1 - p), k * (1 + p)))
  elseif k ~= 1 then
    m = Mat4.mul(m, Mat4.scale(k, k, k))
  end
  return m
end

-- the hinge: the lid's own extra transform about the back of the equator
local function lidMatrix(open)
  if open <= 0 then return nil end
  local a = -LID_OPEN * smooth(open)
  local hz = HINGE_Z * R
  return Mat4.mul(Mat4.translate(0, 0, hz),
         Mat4.mul(Mat4.rotateX(a), Mat4.translate(0, 0, -hz)))
end

-- where the open mouth is, for aiming the capture beam
function Pokeball:mouth()
  return self.pos[1], self.pos[2] + R * 0.4 * self.scale, self.pos[3]
end

-- ------- drawing
--
-- Assumes a live Voxel3D scene (between beginScene and endScene), exactly
-- like Stadium.draw. Seams and glass are off for the duration: the ball is
-- not on the voxel grid and does not wear the tileset atlas.
local function eyeYaw(x, z)
  local eye = Voxel3D.eye
  if not eye then return 0 end
  return math.atan2(eye[1] - x, eye[3] - z)
end

-- TEST97: draw ONLY the proven true-3D smoke cloud, without drawing a ball.
-- This deliberately reuses the exact breakoutPuffs mesh/palette/render path
-- that already works during failed captures.
function Pokeball:drawSmokeOnly(pull)
  if not self.breakoutPuffs then return end
  local m = meshesFor(self.ball)
  local pal = paletteTexture()
  if not (m and m.puff and pal) then return end

  Voxel3D.seams(false)
  Voxel3D.glass(false)
  for _,p in ipairs(self.breakoutPuffs) do
    if p.t and p.t >= 0 and p.t < p.life then
      local q = p.t / p.life
      local rr = (R * 0.25 + p.speed * p.t) * self.scale
      local sx = self.pos[1] + math.sin(p.th) * rr
      local sz = self.pos[3] + math.cos(p.th) * rr
      local sy = self.pos[2] + (R * 0.15 + p.rise * p.t) * self.scale
      local sc = p.size * (1.0 + 1.20*q) * (1.0 - 0.58*q) * self.scale
      local M = Mat4.mul(
        Mat4.translate(sx, sy, sz),
        Mat4.mul(
          Mat4.rotateY((p.spin or 0) * p.t),
          Mat4.mul(Mat4.rotateZ((p.spin or 0) * p.t * 0.63),
                   Mat4.scale(sc, sc, sc))
        )
      )
      Voxel3D.draw(m.puff, pal, M, (pull or 0) + 8)
    end
  end
end

function Pokeball:draw(pull)
  if not self.visible then return end
  local m = meshesFor(self.ball)
  local pal = paletteTexture()
  if not (m and pal) then return end

  -- TEST57B TAPERED PERSONALITY TRAILS -----------------------------------
  -- Built cleanly from TEST56. Non-additive, depth-tested, throw-only.
  local streamerMult = PokeballSettings.streamerMult()
  if streamerMult > 0 and self.phase == "throw" and self.trail and #self.trail >= 2 and m.glow then
    Voxel3D.seams(false)
    Voxel3D.glass(false)

    local function segment(a,b,w,lateral,vertical,twist,bias)
      local x,y,z=b[1],b[2],b[3]
      local dx,dy,dz=a[1]-x,a[2]-y,a[3]-z
      local len=math.sqrt(dx*dx+dy*dy+dz*dz)
      if len <= 0.02 then return end
      dx,dy,dz=dx/len,dy/len,dz/len

      local ux,uy,uz=-dz,0,dx
      local ul=math.sqrt(ux*ux+uz*uz)
      if ul < 0.001 then ux,uy,uz=1,0,0 else ux,uz=ux/ul,uz/ul end

      local vx=dy*uz-dz*uy
      local vy=dz*ux-dx*uz
      local vz=dx*uy-dy*ux

      local ct,st=math.cos(twist or 0),math.sin(twist or 0)
      local rx=ux*ct+vx*st
      local ry=uy*ct+vy*st
      local rz=uz*ct+vz*st

      x=x+ux*(lateral or 0)
      y=y+(vertical or 0)
      z=z+uz*(lateral or 0)

      local M={
        rx*w,dx*len,vx,x,
        ry*w,dy*len,vy,y,
        rz*w,dz*len,vz,z,
        0,0,0,1
      }
      Voxel3D.draw(m.glow,pal,M,pull+(bias or -2))
    end

    for i=1,#self.trail-1 do
      local a,b=self.trail[i],self.trail[i+1]
      local age=(i-1)/math.max(1,#self.trail-2)
      local taper=(1-age)*(1-age)
      local w=R*(0.055+0.135*taper)*self.scale*streamerMult
      local t=self.glossT or 0

      if self.ball == "MASTER_BALL" then
        local ang=t*8+i*0.82
        local orbit=R*(0.13+0.04*taper)*self.scale*streamerMult
        local lat=math.cos(ang)*orbit
        local vert=math.sin(ang)*orbit
        segment(a,b,w*0.82, lat, vert, ang,-2)
        segment(a,b,w*0.58,-lat,-vert,-ang,-3)
      elseif self.ball == "ULTRA_BALL" then
        local sep=R*(0.11+0.03*taper)*self.scale
        segment(a,b,w*0.72, sep,0, 0.22+age*1.8,-2)
        segment(a,b,w*0.72,-sep,0,-0.22-age*1.8,-2)
      elseif self.ball == "GREAT_BALL" then
        -- TEST59: two restrained counter-twisting rails. Visually reads as
        -- the Great Ball's blue/red split without making the trail bulky.
        local sep=R*(0.070+0.018*taper)*self.scale*streamerMult
        segment(a,b,w*0.72, sep,0, 0.35+age*1.25,-2)
        segment(a,b,w*0.58,-sep,0,-0.35-age*1.25,-3)
      else
        -- TEST59: classic Pokeball gets a subtle two-strand twist instead of
        -- the old rigid single rod. Kept narrow so Master remains special.
        local ang=(self.glossT or 0)*4.4+i*0.48
        local orbit=R*(0.052+0.016*taper)*self.scale*streamerMult
        local lat=math.cos(ang)*orbit
        local vert=math.sin(ang)*orbit
        segment(a,b,w*0.76, lat, vert, ang*0.55,-2)
        segment(a,b,w*0.48,-lat,-vert,-ang*0.55,-3)
      end
    end

    Voxel3D.glass(true)
    Voxel3D.seams(true)
  end

  -- TEST60 3D IMPACT + SUCTION BURST -------------------------------------
  -- Safe non-additive geometry: a fast expanding ring impression followed by
  -- inward-moving star/energy shards. No fullscreen glow or lighting changes.
  if self.impactFx and m.glow then
    local it = self.impactFx.t
    local life = self.impactFx.life or 0.72
    local q = math.min(1, it/life)
    local im = self.impactFx.mult or 1
    Voxel3D.seams(false)
    Voxel3D.glass(false)

    -- Expanding radial spokes create a readable shock-ring in 3D.
    local spokes = math.floor(10 + 4*im)
    if it < 0.34 then
      local rq = it/0.34
      for i=1,spokes do
        local a=TAU*(i-1)/spokes
        local inner=R*(0.45+2.25*rq)*self.scale
        local seglen=R*(0.32+0.35*(1-rq))*self.scale
        local x=self.pos[1]+math.sin(a)*inner
        local y=self.pos[2]+R*(0.12+0.18*math.sin(a*2))*self.scale
        local z=self.pos[3]+math.cos(a)*inner*0.68
        local dx=math.sin(a)*seglen
        local dy=R*0.04*math.sin(a*3)*self.scale
        local dz=math.cos(a)*seglen*0.68
        local len=math.sqrt(dx*dx+dy*dy+dz*dz)
        if len>0.001 then
          dx,dy,dz=dx/len,dy/len,dz/len
          local ux,uy,uz=-dz,0,dx
          local ul=math.sqrt(ux*ux+uz*uz)
          if ul<0.001 then ux,uy,uz=1,0,0 else ux,uz=ux/ul,uz/ul end
          local vx=dy*uz-dz*uy
          local vy=dz*ux-dx*uz
          local vz=dx*uy-dy*ux
          local w=R*(0.10+0.05*im)*(1-rq)*self.scale
          local M={ux*w,dx*seglen,vx,x, uy*w,dy*seglen,vy,y, uz*w,dz*seglen,vz,z, 0,0,0,1}
          Voxel3D.draw(m.glow,pal,M,pull-1)
        end
      end
    end

    -- Inward suction shards: begin outside and collapse toward the ball.
    if m.star and it > 0.10 then
      local st=(it-0.10)/0.50
      if st>=0 and st<1 then
        local count=math.floor(8+6*im)
        for i=1,count do
          local a=TAU*(i-1)/count + i*0.31
          local rr=R*(2.8*(1-st)+0.28)*self.scale
          local sx=self.pos[1]+math.sin(a)*rr
          local sz=self.pos[3]+math.cos(a)*rr*0.66
          local sy=self.pos[2]+R*(0.25+0.85*(1-st)+0.22*math.sin(a*3))*self.scale
          local sc=R*(0.18+0.08*im)*(1-0.55*st)*self.scale
          local M=Mat4.mul(Mat4.translate(sx,sy,sz),
            Mat4.mul(Mat4.rotateY(eyeYaw(sx,sz)),
              Mat4.mul(Mat4.rotateZ(-a+it*8),Mat4.scale(sc,sc,1))))
          Voxel3D.draw(m.star,pal,M,pull+3)
        end
      end
    end

    -- Master-only inward spiral accent.
    if self.ball == "MASTER_BALL" and m.star and it>0.05 and it<0.62 then
      local st=(it-0.05)/0.57
      for i=1,16 do
        local a=i*0.72 + st*7.0
        local rr=R*(3.3*(1-st)+0.22)*self.scale
        local sx=self.pos[1]+math.sin(a)*rr
        local sz=self.pos[3]+math.cos(a)*rr*0.62
        local sy=self.pos[2]+R*(0.35+0.9*(1-st))*self.scale
        local sc=R*0.22*(1-0.45*st)*self.scale
        local M=Mat4.mul(Mat4.translate(sx,sy,sz),
          Mat4.mul(Mat4.rotateY(eyeYaw(sx,sz)),
            Mat4.mul(Mat4.rotateZ(a+it*10),Mat4.scale(sc,sc,1))))
        Voxel3D.draw(m.star,pal,M,pull+5)
      end
    end

    Voxel3D.glass(true)
    Voxel3D.seams(true)
  end

  Voxel3D.seams(false)
  Voxel3D.glass(false)
  local model = self:matrix()
  Voxel3D.draw(m.base, pal, model, pull)
  local lidM = lidMatrix(self.lid)
  Voxel3D.draw(m.lid, pal, lidM and Mat4.mul(model, lidM) or model, pull)

  -- TEST38: visible hard shell reflection.
  if m.shine then
    Voxel3D.draw(m.shine, pal, model, pull + 14)
  end

  -- TEST43: dynamic moving specular treatment.
  -- The highlights sweep over the shell as time advances, giving the ball a
  -- polished/lacquered read even when the camera or ball rotation is subtle.
  do
    local gt = self.glossT or 0

    local function gloss(dx, dy, dz, sx, sy, rot, extraPull)
      local hx = self.pos[1] + dx * self.scale
      local hy = self.pos[2] + dy * self.scale
      local hz = self.pos[3] + dz * self.scale
      local H = Mat4.mul(
        Mat4.translate(hx, hy, hz),
        Mat4.mul(
          Mat4.rotateY(eyeYaw(hx, hz)),
          Mat4.mul(
            Mat4.rotateZ(rot or 0),
            Mat4.scale(sx * self.scale, sy * self.scale, 1)
          )
        )
      )
      Voxel3D.draw(m.glow, pal, H, pull + extraPull)
    end

    -- Slow broad sweep across the upper/front shell.
    local sweep = math.sin(gt * 2.15)
    local sweep2 = math.cos(gt * 1.65 + 0.8)

    Voxel3D.blend("add")

    gloss(
      R * (-0.36 + 0.30 * sweep),
      R * ( 0.53 + 0.08 * sweep2),
      R * 0.82,
      R * 0.62, R * 0.30,
      -0.30 + sweep * 0.20,
      16
    )

    -- Tighter secondary reflection moving opposite the broad streak.
    gloss(
      R * (0.18 - 0.18 * sweep),
      R * (0.32 + 0.10 * sweep),
      R * 0.91,
      R * 0.31, R * 0.16,
      0.22 - sweep * 0.18,
      17
    )

    -- Small hot spot: quicker motion gives the impression of a hard,
    -- polished surface catching stadium light.
    local hot = math.sin(gt * 3.4 + 1.1)
    gloss(
      R * (-0.18 + 0.16 * hot),
      R * ( 0.70 + 0.05 * math.cos(gt * 3.4)),
      R * 0.89,
      R * 0.16, R * 0.10,
      gt * 0.35,
      18
    )

    Voxel3D.blend(nil)
  end

  -- the additive dressing: the open-mouth glow and the caught stars.
  -- Depth writes are off under "add" (Voxel3D.blend), so these can never
  -- punch holes for later draws.
  local anythingAdd = (self.glow > 0.05 and self.lid > 0.1) or self.stars
  if anythingAdd then
    Voxel3D.blend("add")
    if self.glow > 0.05 and self.lid > 0.1 then
      -- a pulsing octahedron of light standing in the mouth: two crossed
      -- cards read from every seat in the house
      local gx, gy, gz = self:mouth()
      local s = R * (1.1 + 0.25 * self.glow) * self.scale
      for i = 0, 1 do
        local card = Mat4.mul(Mat4.translate(gx, gy, gz),
                     Mat4.mul(Mat4.rotateY(eyeYaw(gx, gz) + i * math.pi / 2),
                              Mat4.scale(s, s, 1)))
        Voxel3D.draw(m.glow, pal, card, pull)
      end
    end
    if self.stars then
      for _, s in ipairs(self.stars) do
        if s.t > 0 and s.t < STAR_T then
          local t = s.t / STAR_T
          local rr = (R + 4.5 * t) * self.scale
          local sx = self.pos[1] + math.sin(s.th) * rr
          local sz = self.pos[3] + math.cos(s.th) * rr
          local sy = self.pos[2] + (R + 7 * t - 5 * t * t) * self.scale
          local sc = 1.1 * (1 - t)
          local card = Mat4.mul(Mat4.translate(sx, sy, sz),
                       Mat4.mul(Mat4.rotateY(eyeYaw(sx, sz)),
                       Mat4.mul(Mat4.rotateZ(TAU * t * 0.5),
                                Mat4.scale(sc, sc, 1))))
          Voxel3D.draw(m.star, pal, card, pull)
        end
      end
    end
    Voxel3D.blend(nil)
  end

  -- TEST34 TRUE VOXEL SMOKE ---------------------------------------------
  -- Opaque low-poly puffs, drawn through Voxel3D itself. They expand, rise,
  -- tumble, and shrink away. No 2D graphics API and no alpha billboard tricks.
  if self.breakoutPuffs and m.puff then
    Voxel3D.seams(false)
    Voxel3D.glass(false)
    for _,p in ipairs(self.breakoutPuffs) do
      if p.t and p.t >= 0 and p.t < p.life then
        local q = p.t / p.life
        local rr = (R * 0.25 + p.speed * p.t) * self.scale
        local sx = self.pos[1] + math.sin(p.th) * rr
        local sz = self.pos[3] + math.cos(p.th) * rr
        local sy = self.pos[2] + (R * 0.15 + p.rise * p.t) * self.scale

        -- Big at first, then dissipate by shrinking instead of transparency.
        local sc = p.size * (1.0 + 1.20*q) * (1.0 - 0.58*q) * self.scale
        local M = Mat4.mul(
          Mat4.translate(sx, sy, sz),
          Mat4.mul(
            Mat4.rotateY((p.spin or 0) * p.t),
            Mat4.mul(Mat4.rotateZ((p.spin or 0) * p.t * 0.63),
                     Mat4.scale(sc, sc, sc))
          )
        )
        Voxel3D.draw(m.puff, pal, M, pull + 8)
      end
    end
  end

  -- TEST47: UNIVERSAL TIERED EPIC CAPTURE -------------------------------
  -- Every ball gets a larger celebration. Ultra gets 2x density; Master 4x.
  if PokeballSettings.starMult() > 0 and self.catchFx and m.star then
    local et = self.catchFx.t or 0
    local em = self.catchFx.epicMult or 1
    local elife = self.catchFx.life or 2.85

    if et >= 0 and et < elife then
      Voxel3D.blend("add")

      -- Giant opening shock-stars.
      local heroCount = 10 * em
      for i = 1, heroCount do
        local delay = 0.02 + (i % (5*em)) * 0.012
        local rt = et - delay
        if rt >= 0 and rt < 1.30 then
          local q = rt / 1.30
          local a = TAU * (i-1)/heroCount + (i%3)*0.11
          local rr = R * (0.55 + (3.9 + 0.35*em)*q) * self.scale
          local sx = self.pos[1] + math.sin(a)*rr
          local sz = self.pos[3] + math.cos(a)*rr*0.76
          local sy = self.pos[2] + (R*0.52 + math.sin(a*2.3)*R*0.48 + q*R*(1.45+0.18*em))*self.scale
          local sc = R*(0.88 + 0.09*em - 0.30*q)*self.scale
          local M = Mat4.mul(
            Mat4.translate(sx,sy,sz),
            Mat4.mul(Mat4.rotateY(eyeYaw(sx,sz)),
              Mat4.mul(Mat4.rotateZ(a+rt*(3.4+0.25*em)),
                Mat4.scale(sc,sc,1)))
          )
          Voxel3D.draw(m.star,pal,M,pull+31+(i%9))
        end
      end

      -- Dense expanding sparkle storm.
      local stormCount = 36 * em
      for i = 1, stormCount do
        local delay = 0.24 + (i % (8*em)) * 0.010
        local rt = et - delay
        if rt >= 0 and rt < 2.05 then
          local q = rt/2.05
          local a = i*2.399963 + (i%7)*0.13 + rt*(0.55 + 0.10*em)
          local rr = R*(0.70 + (i%9)*0.16 + q*(2.20+0.22*em))*self.scale
          local sx = self.pos[1] + math.sin(a)*rr
          local sz = self.pos[3] + math.cos(a)*rr*0.70
          local sy = self.pos[2] + (R*(0.20+(i%8)*0.14) + q*R*(1.30+(i%5)*0.16))*self.scale
          local tw = 0.72 + 0.28*math.sin(rt*(11+em)+i)
          local sc = R*(0.26+(i%4)*0.07)*(1-0.38*q)*tw*self.scale
          local M = Mat4.mul(
            Mat4.translate(sx,sy,sz),
            Mat4.mul(Mat4.rotateY(eyeYaw(sx,sz)),
              Mat4.mul(Mat4.rotateZ(-a+rt*(4.2+0.25*em)),
                Mat4.scale(sc,sc,1)))
          )
          Voxel3D.draw(m.star,pal,M,pull+25+(i%7))
        end
      end

      -- Lingering upper crown, denser by tier.
      local crownCount = 12 * em
      if et > 0.85 then
        local rt = et-0.85
        if rt < 1.85 then
          local fade = math.max(0,1-rt/1.85)
          for i = 1,crownCount do
            local a = TAU*(i-1)/crownCount - rt*(1.05+0.12*em)
            local rr = R*(1.65+0.18*em+0.22*math.sin(i*1.7))*self.scale
            local sx = self.pos[1]+math.sin(a)*rr
            local sz = self.pos[3]+math.cos(a)*rr*0.68
            local sy = self.pos[2]+R*(2.05+0.28*math.sin(a*3))*self.scale
            local sc = R*(0.34+0.035*em)*fade*self.scale
            local M = Mat4.mul(
              Mat4.translate(sx,sy,sz),
              Mat4.mul(Mat4.rotateY(eyeYaw(sx,sz)),
                Mat4.mul(Mat4.rotateZ(rt*3.1+i),
                  Mat4.scale(sc,sc,1)))
            )
            Voxel3D.draw(m.star,pal,M,pull+30)
          end
        end
      end

      Voxel3D.blend(nil)
    end
  end

  -- TEST48: MASTER BALL ZING ---------------------------------------------
  -- Fast, aerobic, flashy motion layered on top of TEST47's 4x spectacle.
  if PokeballSettings.starMult() > 0 and self.catchFx and self.catchFx.masterEpic and m.star then
    local zt = self.catchFx.t or 0
    if zt >= 0 and zt < 3.35 then
      Voxel3D.blend("add")

      -- Rapid strobe pulses from the ball: quick visual "hits", not a slow glow.
      if zt < 1.35 and m.glow then
        local beat = math.max(0, math.sin(zt * 30.0))
        local gs = R * (1.55 + beat * 2.25) * self.scale
        local gx,gy,gz=self.pos[1],self.pos[2]+R*0.16*self.scale,self.pos[3]
        local G=Mat4.mul(Mat4.translate(gx,gy,gz),
          Mat4.mul(Mat4.rotateY(eyeYaw(gx,gz)),Mat4.scale(gs,gs,1)))
        Voxel3D.draw(m.glow,pal,G,pull+58)
      end

      -- Two counter-rotating "aerobic" star ribbons whipping around the ball.
      for arm=1,2 do
        local dir=(arm==1) and 1 or -1
        for i=1,28 do
          local delay=(i-1)*0.018
          local rt=zt-delay
          if rt>=0 and rt<1.75 then
            local q=rt/1.75
            local a=dir*(rt*7.4+i*0.38)+arm*1.4
            local rr=R*(0.72+q*3.55+(i%4)*0.10)*self.scale
            local sx=self.pos[1]+math.sin(a)*rr
            local sz=self.pos[3]+math.cos(a)*rr*0.70
            local sy=self.pos[2]+R*(0.30+q*2.65+0.42*math.sin(a*2))*self.scale
            local sc=R*(0.42+0.10*math.sin(rt*13+i))*self.scale
            local M=Mat4.mul(Mat4.translate(sx,sy,sz),
              Mat4.mul(Mat4.rotateY(eyeYaw(sx,sz)),
                Mat4.mul(Mat4.rotateZ(-a+dir*rt*8.0),Mat4.scale(sc,sc,1))))
            Voxel3D.draw(m.star,pal,M,pull+44+(i%8))
          end
        end
      end

      -- Four explosive star "firework" beats.
      local beats={0.12,0.46,0.82,1.18}
      for b,bt in ipairs(beats) do
        local rt=zt-bt
        if rt>=0 and rt<0.72 then
          local q=rt/0.72
          for i=1,16 do
            local a=TAU*(i-1)/16+b*0.43
            local rr=R*(0.35+4.65*q)*self.scale
            local sx=self.pos[1]+math.sin(a)*rr
            local sz=self.pos[3]+math.cos(a)*rr*0.62
            local sy=self.pos[2]+R*(0.45+math.sin(a*3+b)*0.65+q*1.55)*self.scale
            local sc=R*(0.72-0.30*q)*self.scale
            local M=Mat4.mul(Mat4.translate(sx,sy,sz),
              Mat4.mul(Mat4.rotateY(eyeYaw(sx,sz)),
                Mat4.mul(Mat4.rotateZ(a+rt*7.0),Mat4.scale(sc,sc,1))))
            Voxel3D.draw(m.star,pal,M,pull+50+b)
          end
        end
      end

      -- Late glitter fountain keeps energy alive after the big blast.
      if zt>1.10 then
        local rt=zt-1.10
        for i=1,44 do
          local phase=(i%11)*0.055
          local tt=rt-phase
          if tt>=0 and tt<1.85 then
            local q=tt/1.85
            local a=i*2.399963+tt*1.8
            local rr=R*(0.35+(i%8)*0.19+q*1.35)*self.scale
            local sx=self.pos[1]+math.sin(a)*rr
            local sz=self.pos[3]+math.cos(a)*rr*0.58
            local sy=self.pos[2]+R*(0.20+(i%5)*0.13+q*3.10)*self.scale
            local tw=0.58+0.42*math.max(0,math.sin(tt*17+i))
            local sc=R*(0.17+(i%3)*0.05)*tw*self.scale
            local M=Mat4.mul(Mat4.translate(sx,sy,sz),
              Mat4.mul(Mat4.rotateY(eyeYaw(sx,sz)),
                Mat4.mul(Mat4.rotateZ(tt*8+i),Mat4.scale(sc,sc,1))))
            Voxel3D.draw(m.star,pal,M,pull+41)
          end
        end
      end

      Voxel3D.blend(nil)
    end
  end

  -- TEST46: MASTER BALL EPIC CAPTURE ------------------------------------
  -- Runs in addition to TEST44's normal victory burst, only for Master Ball.
  if PokeballSettings.starMult() > 0 and self.catchFx and self.catchFx.masterEpic and m.star then
    local mt = self.catchFx.t or 0
    local mlife = self.catchFx.life or 3.35
    if mt >= 0 and mt < mlife then
      Voxel3D.blend("add")

      -- Massive opening crown burst: twelve oversized stars.
      for i = 1, 12 do
        local delay = 0.03 + (i % 4) * 0.025
        local rt = mt - delay
        if rt >= 0 and rt < 1.35 then
          local q = rt / 1.35
          local a = TAU * (i-1)/12 + 0.17
          local rr = R * (0.55 + 5.25*q) * self.scale
          local sx = self.pos[1] + math.sin(a) * rr
          local sz = self.pos[3] + math.cos(a) * rr * 0.78
          local sy = self.pos[2] + (R*0.62 + math.sin(a*2.0)*R*0.55 + q*R*2.25) * self.scale
          local sc = R * (1.28 - 0.46*q) * self.scale
          local M = Mat4.mul(
            Mat4.translate(sx, sy, sz),
            Mat4.mul(Mat4.rotateY(eyeYaw(sx, sz)),
              Mat4.mul(Mat4.rotateZ(a + rt*4.4),
                Mat4.scale(sc, sc, 1)))
          )
          Voxel3D.draw(m.star, pal, M, pull + 42 + i)
        end
      end

      -- Dense double spiral: 64 stars wrapping around and rising above ball.
      for i = 1, 48 do
        local delay = 0.20 + (i % 8) * 0.022
        local rt = mt - delay
        if rt >= 0 and rt < 2.15 then
          local q = rt / 2.15
          local arm = (i % 2 == 0) and 1 or -1
          local a = i * 0.73 + arm * rt * 3.25
          local rr = R * (1.00 + (i%9)*0.15 + q*2.55) * self.scale
          local sx = self.pos[1] + math.sin(a) * rr
          local sz = self.pos[3] + math.cos(a) * rr * 0.72
          local sy = self.pos[2] + (R*(0.22 + (i%7)*0.16) + q*R*2.20) * self.scale
          local tw = 0.78 + 0.22*math.sin(rt*14 + i)
          local sc = R * (0.32 + (i%4)*0.085) * (1.0 - 0.32*q) * tw * self.scale
          local M = Mat4.mul(
            Mat4.translate(sx, sy, sz),
            Mat4.mul(Mat4.rotateY(eyeYaw(sx, sz)),
              Mat4.mul(Mat4.rotateZ(-a + rt*5.2),
                Mat4.scale(sc, sc, 1)))
          )
          Voxel3D.draw(m.star, pal, M, pull + 34 + (i%6))
        end
      end

      -- Final celestial crown above the caught Master Ball.
      if mt > 1.15 and mt < 3.15 then
        local rt = mt - 1.15
        local fade = math.max(0, 1 - math.max(0, rt-1.25)/0.75)
        for i = 1, 18 do
          local a = TAU*(i-1)/18 - rt*1.45
          local rr = R*(2.0 + 0.30*math.sin(i*2.1 + rt*3)) * self.scale
          local sx = self.pos[1] + math.sin(a)*rr
          local sz = self.pos[3] + math.cos(a)*rr*0.70
          local sy = self.pos[2] + R*(2.55 + 0.35*math.sin(a*3))*self.scale
          local sc = R*0.46*fade*self.scale
          local M = Mat4.mul(
            Mat4.translate(sx, sy, sz),
            Mat4.mul(Mat4.rotateY(eyeYaw(sx, sz)),
              Mat4.mul(Mat4.rotateZ(rt*3.8+i),
                Mat4.scale(sc, sc, 1)))
          )
          Voxel3D.draw(m.star, pal, M, pull + 38)
        end
      end

      -- Repeated Master Ball pulse so the ball itself remains the centerpiece.
      if mt < 1.55 and m.glow then
        local pulse = 0.65 + 0.35*math.sin(mt*18)
        local gs = R*(2.15 + 0.75*pulse)*self.scale
        local gx,gy,gz = self.pos[1],self.pos[2]+R*0.12*self.scale,self.pos[3]
        local G = Mat4.mul(
          Mat4.translate(gx,gy,gz),
          Mat4.mul(Mat4.rotateY(eyeYaw(gx,gz)),
            Mat4.scale(gs,gs,1))
        )
        Voxel3D.draw(m.glow,pal,G,pull+48)
      end

      Voxel3D.blend(nil)
    end
  end

  -- TEST44: VICTORY BURST ---------------------------------------------
  -- Intentionally asymmetric choreography:
  -- flash -> giant hero stars -> medium stars -> lingering sparkle field.
  if PokeballSettings.starMult() > 0 and self.catchFx and m.star then
    local ct = self.catchFx.t or 0
    local life = self.catchFx.life or 2.55

    if ct >= 0 and ct < life then
      Voxel3D.blend("add")

      -- 1) Capture-confirmation flash/pulse from the ball itself.
      if ct < 0.42 then
        local q = ct / 0.42
        local pulse = math.sin(math.min(1, q) * math.pi)
        local ps = R * (1.10 + 2.30*q) * self.scale
        local px, py, pz = self.pos[1], self.pos[2] + R*0.20*self.scale, self.pos[3]
        local P = Mat4.mul(
          Mat4.translate(px, py, pz),
          Mat4.mul(Mat4.rotateY(eyeYaw(px, pz)),
                   Mat4.scale(ps*pulse, ps*pulse, 1))
        )
        Voxel3D.draw(m.glow, pal, P, pull + 34)
      end

      -- 2) Eight HUGE hero stars punching outward in uneven directions.
      local heroDirs = {
        {-1.00, 0.48}, {-0.62, 0.92}, {-0.18, 1.10}, {0.42, 0.94},
        { 0.98, 0.56}, { 0.78, 0.18}, {-0.78, 0.12}, {0.16, 0.46}
      }
      for i,d in ipairs(heroDirs) do
        local delay = 0.10 + (i-1)*0.035
        local rt = ct - delay
        if rt >= 0 and rt < 1.15 then
          local q = rt / 1.15
          local rr = R * (0.75 + 4.15*q) * self.scale
          local sx = self.pos[1] + d[1] * rr
          local sy = self.pos[2] + (R*0.55 + d[2]*rr + q*R*0.65) * self.scale
          local sz = self.pos[3] + math.sin(i*1.71) * R * (0.50 + 0.80*q) * self.scale
          local sc = R * (1.05 - 0.38*q) * self.scale
          local S = Mat4.mul(
            Mat4.translate(sx, sy, sz),
            Mat4.mul(Mat4.rotateY(eyeYaw(sx, sz)),
                     Mat4.mul(Mat4.rotateZ(i*0.67 + rt*3.5),
                              Mat4.scale(sc, sc, 1)))
          )
          Voxel3D.draw(m.star, pal, S, pull + 28 + i)
        end
      end

      -- 3) Medium secondary burst, deliberately offset so it doesn't form a ring.
      for i = 1, 24 do
        local delay = 0.32 + (i % 6) * 0.035
        local rt = ct - delay
        if rt >= 0 and rt < 1.35 then
          local q = rt / 1.35
          local a = i * 2.399963 + (i % 4)*0.21
          local rr = R * (0.60 + q*(2.10 + (i%5)*0.22)) * self.scale
          local sx = self.pos[1] + math.sin(a) * rr
          local sz = self.pos[3] + math.cos(a) * rr * 0.72
          local sy = self.pos[2] + (R*(0.30 + (i%5)*0.18) + q*R*(0.55 + (i%4)*0.22)) * self.scale
          local sc = R * (0.46 + (i%3)*0.10) * (1.0 - 0.42*q) * self.scale
          local S = Mat4.mul(
            Mat4.translate(sx, sy, sz),
            Mat4.mul(Mat4.rotateY(eyeYaw(sx, sz)),
                     Mat4.mul(Mat4.rotateZ(-a + rt*4.2),
                              Mat4.scale(sc, sc, 1)))
          )
          Voxel3D.draw(m.star, pal, S, pull + 22 + (i%4))
        end
      end

      -- 4) Lingering little sparkles drifting upward after the main impact.
      for i = 1, 34 do
        local delay = 0.72 + (i % 9) * 0.055
        local rt = ct - delay
        if rt >= 0 and rt < 1.65 then
          local q = rt / 1.65
          local a = i * 1.618034 * 2.0
          local rr = R * (0.55 + (i%7)*0.30 + q*0.65) * self.scale
          local sx = self.pos[1] + math.sin(a) * rr
          local sz = self.pos[3] + math.cos(a) * rr * 0.62
          local sy = self.pos[2] + (R*(0.20 + (i%6)*0.18) + q*R*1.45) * self.scale
          local twinkle = 0.72 + 0.28*math.sin(rt*12 + i)
          local sc = R * (0.18 + (i%3)*0.055) * (1.0 - 0.48*q) * twinkle * self.scale
          local S = Mat4.mul(
            Mat4.translate(sx, sy, sz),
            Mat4.mul(Mat4.rotateY(eyeYaw(sx, sz)),
                     Mat4.mul(Mat4.rotateZ(rt*5.0 + i),
                              Mat4.scale(sc, sc, 1)))
          )
          Voxel3D.draw(m.star, pal, S, pull + 20)
        end
      end

      Voxel3D.blend(nil)
    end
  end

  Voxel3D.glass(true)
  Voxel3D.seams(true)

end

-- the capture beam: a crossed pair of additive cards stretched from the
-- ball's mouth to the mon it is drinking in. Separate from draw() because
-- the caller owns the far end and the fade.
function Pokeball:drawBeam(tx, ty, tz, width, strength, pull)
  if not self.visible then return end
  local beamMult = PokeballSettings.beamMult()
  if beamMult <= 0 then return end
  local fxScale = PokeballSettings.fxScaleMult()
  width = (width or R) * beamMult * fxScale
  strength = math.min(1.65, (strength or 1) * (0.72 + 0.28*beamMult))
  local m = meshesFor(self.ball)
  local pal = paletteTexture()
  if not (m and pal) then return end
  local x, y, z = self:mouth()
  local dx, dy, dz = tx - x, ty - y, tz - z
  local len = math.sqrt(dx * dx + dy * dy + dz * dz)
  if len < 0.5 then return end
  dx, dy, dz = dx / len, dy / len, dz / len
  -- two perpendiculars to the beam axis
  local ux, uy, uz
  if math.abs(dy) < 0.94 then
    ux, uy, uz = -dz, 0, dx                 -- cross(d, worldUp), unnormalised
    local l = math.sqrt(ux * ux + uz * uz)
    ux, uz = ux / l, uz / l
  else
    ux, uy, uz = 1, 0, 0
  end
  local vx = dy * uz - dz * uy
  local vy = dz * ux - dx * uz
  local vz = dx * uy - dy * ux
  local w = width * strength
  Voxel3D.seams(false)
  Voxel3D.glass(false)
  Voxel3D.blend("add")
  -- the unit card is x -0.5..0.5, y 0..1: columns map its x to a
  -- perpendicular and its y to the full run of the axis
  local a = { ux * w, dx * len, vx, x,
              uy * w, dy * len, vy, y,
              uz * w, dz * len, vz, z,
              0, 0, 0, 1 }
  local b = { vx * w, dx * len, ux, x,
              vy * w, dy * len, uy, y,
              vz * w, dz * len, uz, z,
              0, 0, 0, 1 }
  Voxel3D.draw(m.glow, pal, a, pull)
  Voxel3D.draw(m.glow, pal, b, pull)

  -- TEST71: bright inner capture filament. The existing crossed cards are
  -- the soft outer cone; these narrower nested cards give the eye a clear
  -- ball -> Pokemon energy connection during the shrink.
  local coreW = w * 0.34
  local ca = { ux * coreW, dx * len, vx, x,
               uy * coreW, dy * len, vy, y,
               uz * coreW, dz * len, vz, z,
               0, 0, 0, 1 }
  local cb = { vx * coreW, dx * len, ux, x,
               vy * coreW, dy * len, uy, y,
               vz * coreW, dz * len, uz, z,
               0, 0, 0, 1 }
  Voxel3D.draw(m.glow, pal, ca, pull + 2)
  Voxel3D.draw(m.glow, pal, cb, pull + 2)

  -- TEST72 BOLD TRACTOR BEAM ---------------------------------------------
  -- TEST71's long crossed cards were technically present but visually too
  -- subtle against bright grass/flowers. Build the beam out of overlapping
  -- luminous billboards along the ENTIRE ball->Pokemon line instead.
  --
  -- The overlap makes a continuous white energy column rather than a few
  -- streaks, and every element still inherits Pokeball.scale.
  local beamTime = self.glossT or 0
  local beamScale = self.scale or 1
  local beads = 22
  for i=0,beads do
    local u=i/beads
    local px=x + dx*len*u
    local py=y + dy*len*u
    local pz=z + dz*len*u

    -- Wider around the Pokemon, tighter at the ball mouth: obvious suction cone.
    local cone = 0.34 + 0.92*u
    local pulse = 1 + 0.12*math.sin(beamTime*18 - u*10)
    local sc = math.max(1.15, w*0.62*cone) * pulse * beamScale

    local M=Mat4.mul(
      Mat4.translate(px,py,pz),
      Mat4.mul(
        Mat4.rotateY(eyeYaw(px,pz)),
        Mat4.scale(sc,sc,1)
      )
    )
    Voxel3D.draw(m.glow,pal,M,pull+5)
  end

  -- Moving bright "packets" race from the Pokemon back into the ball.
  -- These create unmistakable direction even if the white column is nearly
  -- stationary relative to the camera.
  for j=1,5 do
    local u=(1 - ((beamTime*2.6 + j*0.19) % 1))
    local px=x + dx*len*u
    local py=y + dy*len*u
    local pz=z + dz*len*u
    local sc=(2.2 + 0.5*math.sin(beamTime*14+j))*beamScale
    local P=Mat4.mul(
      Mat4.translate(px,py,pz),
      Mat4.mul(Mat4.rotateY(eyeYaw(px,pz)),Mat4.scale(sc,sc,1))
    )
    Voxel3D.draw(m.glow,pal,P,pull+7)
  end

  -- Bright collars at both endpoints make the visual relationship explicit:
  -- OPEN BALL <==== ENERGY COLUMN ====> SHRINKING POKEMON.
  for endpoint=0,1 do
    local px = endpoint==0 and x or tx
    local py = endpoint==0 and y or ty
    local pz = endpoint==0 and z or tz
    for ring=1,3 do
      local sc=(2.4 + ring*1.05)*beamScale
      local C=Mat4.mul(
        Mat4.translate(px,py,pz),
        Mat4.mul(Mat4.rotateY(eyeYaw(px,pz)),Mat4.scale(sc,sc,1))
      )
      Voxel3D.draw(m.glow,pal,C,pull+6+ring)
    end
  end

  -- TEST74: independently tunable Pokemon capture aura.
  local pokemonGlow = PokeballSettings.pokemonGlowMult()
  if pokemonGlow > 0 and m.glow then
    local gt=self.glossT or 0
    for i=1,6 do
      local a=TAU*(i-1)/6 + gt*2.8
      local rr=R*(1.00+0.16*math.sin(gt*5+i))*self.scale*fxScale
      local gx=tx+math.cos(a)*rr
      local gy=ty+math.sin(a)*rr*0.75
      local gz=tz+math.sin(a)*rr*0.35
      local gs=R*(0.38+0.18*pokemonGlow)*self.scale*fxScale
      local G=Mat4.mul(Mat4.translate(gx,gy,gz),
        Mat4.mul(Mat4.rotateY(eyeYaw(gx,gz)),Mat4.scale(gs,gs,1)))
      Voxel3D.draw(m.glow,pal,G,pull+5)
    end
  end

  -- TEST62 EPIC SUCTION INTAKE -------------------------------------------
  -- Directional choreography: bright ball core -> funnel -> contracting aura
  -- -> inward spiral. Uses only localized, depth-tested cards.
  if PokeballSettings.suctionEnabled() and m.glow then
    local particleMult = PokeballSettings.suctionParticleMult()
    local st = math.max(0, math.min(1, strength or 1))
    local time = self.glossT or 0

    -- Vector from Pokemon target to the open ball.
    local bx,by,bz = self.pos[1],self.pos[2],self.pos[3]
    local vx,vy,vz = bx-tx,by-ty,bz-tz
    local dist = math.sqrt(vx*vx+vy*vy+vz*vz)
    if dist < 0.001 then dist=0.001 end
    local nx,ny,nz=vx/dist,vy/dist,vz/dist

    -- BALL CORE: several tiny nested cards make the open ball read as a
    -- concentrated white energy source without lighting the whole scene.
    local corePulse = 1 + 0.18*math.sin(time*18)
    for j=1,4 do
      local cs=(1.8+j*0.75)*corePulse*self.scale
      local C=Mat4.mul(Mat4.translate(bx,by+R*0.10*self.scale,bz),
        Mat4.mul(Mat4.rotateY(eyeYaw(bx,bz)),Mat4.scale(cs,cs,1)))
      Voxel3D.draw(m.glow,pal,C,pull+4+j)
    end

    if particleMult > 0 then
    -- SUCTION FUNNEL: rings travel from Pokemon toward the ball and shrink.
    -- This creates visible direction instead of a static halo.
    local rings=math.max(1, math.floor(7*particleMult+0.5))
    for r=1,rings do
      local u=(r-1)/(rings-1)
      local travel=(u + time*2.1) % 1
      local px=tx+vx*travel
      local py=ty+vy*travel
      local pz=tz+vz*travel
      local radius=(7.5*(1-travel)+1.6)*self.scale
      local cards=math.max(1, math.floor(6*particleMult+0.5))
      for i=1,cards do
        local a=TAU*(i-1)/cards + time*5.2 + travel*3.2
        local hx=px+math.cos(a)*radius
        local hy=py+math.sin(a)*radius*0.62
        local hz=pz+math.sin(a)*radius*0.35
        local sc=(1.15+1.35*(1-travel))*self.scale
        local H=Mat4.mul(Mat4.translate(hx,hy,hz),
          Mat4.mul(Mat4.rotateY(eyeYaw(hx,hz)),
            Mat4.mul(Mat4.rotateZ(a+time*4),Mat4.scale(sc,sc,1))))
        Voxel3D.draw(m.glow,pal,H,pull+3)
      end
    end

    -- POKEMON AURA: larger at first, then visibly contracts around the target.
    local contract=0.35+0.65*st
    local outer=math.max(1, math.floor(12*particleMult+0.5))
    for i=1,outer do
      local a=TAU*(i-1)/outer + time*3.4
      local radius=(5.0+15.0*contract)*self.scale
      local hx=tx+math.cos(a)*radius
      local hy=ty+math.sin(a*1.45)*radius*0.72
      local hz=tz+math.sin(a)*radius*0.40
      local sc=(1.8+2.2*contract)*self.scale
      local H=Mat4.mul(Mat4.translate(hx,hy,hz),
        Mat4.mul(Mat4.rotateY(eyeYaw(hx,hz)),
          Mat4.mul(Mat4.rotateZ(-a+time*5),Mat4.scale(sc,sc,1))))
      Voxel3D.draw(m.glow,pal,H,pull+2)
    end

    -- INWARD SPIRAL STRANDS: visually peel energy off the Pokemon and
    -- corkscrew it toward the ball.
    local strandsBase = self.ball=="MASTER_BALL" and 4 or
                    self.ball=="ULTRA_BALL" and 3 or 2
    local strands = math.max(1, math.floor(strandsBase*particleMult+0.5))
    for strand=1,strands do
      local phase=TAU*(strand-1)/strands
      for k=1,8 do
        local u=k/9
        local px=tx+vx*u
        local py=ty+vy*u
        local pz=tz+vz*u
        local a=phase + u*TAU*1.65 + time*6.5
        local rr=(7.0*(1-u)+0.8)*self.scale
        local hx=px+math.cos(a)*rr
        local hy=py+math.sin(a)*rr*0.55
        local hz=pz+math.sin(a)*rr*0.35
        local sc=(1.45-0.55*u)*self.scale
        local H=Mat4.mul(Mat4.translate(hx,hy,hz),
          Mat4.mul(Mat4.rotateY(eyeYaw(hx,hz)),
            Mat4.mul(Mat4.rotateZ(a),Mat4.scale(sc,sc,1))))
        Voxel3D.draw(m.glow,pal,H,pull+4)
      end
    end

    end -- TEST74 particle-heavy funnel/spirals

    -- TEST63: final intake snap. During the last quarter of the suction,
    -- a tight collar collapses directly into the ball mouth.
    if st < 0.28 then
      local snap = 1 - st/0.28
      for i=1,10 do
        local a=TAU*(i-1)/10 + time*9.0
        local rr=R*(0.75*(1-snap)+0.08)*self.scale
        local hx=bx+math.cos(a)*rr
        local hy=by+R*0.10*self.scale+math.sin(a)*rr*0.55
        local hz=bz+math.sin(a)*rr*0.35
        local sc=R*(0.13+0.10*(1-snap))*self.scale
        local H=Mat4.mul(Mat4.translate(hx,hy,hz),
          Mat4.mul(Mat4.rotateY(eyeYaw(hx,hz)),
            Mat4.mul(Mat4.rotateZ(a-time*12),Mat4.scale(sc,sc,1))))
        Voxel3D.draw(m.glow,pal,H,pull+8)
      end
    end

    -- MASTER BALL: extra compact vortex at the mouth of the ball.
    if self.ball=="MASTER_BALL" and m.star then
      for i=1,12 do
        local a=TAU*(i-1)/12-time*8.5
        local rr=R*(0.32+0.20*math.sin(time*5+i))*self.scale
        local hx=bx+math.cos(a)*rr
        local hy=by+R*0.10*self.scale+math.sin(a)*rr
        local hz=bz+math.sin(a)*rr*0.45
        local sc=R*0.12*self.scale
        local M=Mat4.mul(Mat4.translate(hx,hy,hz),
          Mat4.mul(Mat4.rotateY(eyeYaw(hx,hz)),
            Mat4.mul(Mat4.rotateZ(a+time*9),Mat4.scale(sc,sc,1))))
        Voxel3D.draw(m.star,pal,M,pull+7)
      end
    end
  end
  Voxel3D.blend(nil)
  Voxel3D.glass(true)
  Voxel3D.seams(true)
end

-- ------- the sun's view
--
-- The same two shells under the same matrix, so the shadow on the ground is
-- the pose the camera sees. The caller folds a term into the shadow
-- signature while a ball is live (the sun pass is cached -- see
-- BattleScene.shadowSignature) or this freezes on its first frame.
function Pokeball:cast(shadowMap)
  if not self.visible then return end
  local m = meshesFor(self.ball)
  local pal = paletteTexture()
  if not (m and pal) then return end
  local model = self:matrix()
  shadowMap.draw(m.base, pal, model)
  local lidM = lidMatrix(self.lid)
  shadowMap.draw(m.lid, pal, lidM and Mat4.mul(model, lidM) or model)
end

-- a term for the arena's cached shadow signature: quantised, so the cache
-- only re-renders when the ball has visibly moved
function Pokeball:signature()
  if not self.visible then return "" end
  return table.concat({ math.floor(self.pos[1] * 4), math.floor(self.pos[2] * 4),
                        math.floor(self.pos[3] * 4), math.floor(self.lid * 8),
                        self.wobbleT and math.floor(self.wobbleT * 30) or -1 },
                      ",")
end

return Pokeball
