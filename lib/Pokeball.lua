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
-- squash pulse. The ball owns its POSE only; where it IS (the throw arc, the drop)
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
local function button(verts, map, row, faceOnly)
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
  if faceOnly then
    faceDisc(0.45, R + 0.42, SLOTS.FACE)
    return
  end
  -- the wall starts inside the shell so the junction never shows a gap
  ringWall(0.75, R * 0.90, R + 0.30, SLOTS.RING)
  faceDisc(0.75, R + 0.30, SLOTS.RING)
  ringWall(0.45, R + 0.30, R + 0.42, SLOTS.RING)
end

-- Raised annulus around the button: real geometry in the shell's local space.
local function buttonRingMesh(row)
  local vertices,indices={},{}
  local u,v=uvFor(SLOTS.FACE,row)
  local inner,outer,z0,z1=.48,.77,R+.305,R+.465
  local function at(r,a,z)return {r*math.cos(a),r*math.sin(a),z,u,v,1}end
  for i=0,23 do
    local a,b=TAU*i/24,TAU*(i+1)/24
    quad(vertices,indices,at(inner,a,z1),at(outer,a,z1),at(outer,b,z1),at(inner,b,z1))
    quad(vertices,indices,at(outer,a,z0),at(outer,b,z0),at(outer,b,z1),at(outer,a,z1))
    quad(vertices,indices,at(inner,b,z0),at(inner,a,z0),at(inner,a,z1),at(inner,b,z1))
  end
  return Voxel3D.newMesh(vertices,indices)
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

    -- MASTER1: paint the Master markings onto the existing faceted lid.
    -- Clip each marking against the dome triangles and interpolate their
    -- surface positions. A tiny radial offset avoids depth flicker without
    -- raised boxes or floating spherical decals. Built once with the lid.
    if ball == "MASTER_BALL" then
      local shapes = {}
      local function shape(points, slot)
        shapes[#shapes + 1] = { points = points, slot = slot }
      end
      for _, cx in ipairs({ -0.53, 0.53 }) do
        local points = {}
        for i = 0, 19 do
          local t = TAU * i / 20
          points[#points + 1] = { cx + 0.16 * math.cos(t),
                                  0.55 + 0.17 * math.sin(t) }
        end
        shape(points, SLOTS.GLOW)
      end
      -- Four counterclockwise convex strokes make a legible white M.
      shape({{-0.28,0.25},{-0.17,0.25},{-0.17,0.69},{-0.28,0.69}}, SLOTS.FACE)
      shape({{ 0.17,0.25},{ 0.28,0.25},{ 0.28,0.69},{ 0.17,0.69}}, SLOTS.FACE)
      shape({{0,0.43},{0,0.57},{-0.17,0.69},{-0.28,0.69}}, SLOTS.FACE)
      shape({{0,0.43},{0.28,0.69},{0.17,0.69},{0,0.57}}, SLOTS.FACE)

      local function clip(poly, boundary)
        for i = 1, #boundary do
          local a, b = boundary[i], boundary[i % #boundary + 1]
          local function distance(p)
            return (b[1]-a[1])*(p[2]/R-a[2])
                 - (b[2]-a[2])*(p[1]/R-a[1])
          end
          local out = {}
          if #poly == 0 then return out end
          local prev = poly[#poly]
          local dp = distance(prev)
          for _, cur in ipairs(poly) do
            local dc = distance(cur)
            if (dp >= 0) ~= (dc >= 0) then
              local t = dp / (dp - dc)
              local p = {}
              for k = 1, 6 do p[k] = prev[k] + (cur[k]-prev[k])*t end
              out[#out + 1] = p
            end
            if dc >= 0 then out[#out + 1] = cur end
            prev, dp = cur, dc
          end
          poly = out
        end
        return poly
      end

      -- Only the coloured dome participates (exclude belt and underside).
      local domeFirst = LON * 4 + 1
      local domeLast = domeFirst + LAT * LON * 4 - 1
      for first = domeFirst, domeLast, 4 do
        for _, corners in ipairs({{0,1,2},{0,2,3}}) do
          local a,b,c = lv[first+corners[1]],lv[first+corners[2]],lv[first+corners[3]]
          if a[3]+b[3]+c[3] > 0 then
            for _, marking in ipairs(shapes) do
              local poly = clip({a,b,c}, marking.points)
              local u,v = uvFor(marking.slot,row)
              local function painted(p)
                return {p[1]*1.003,p[2]*1.003,p[3]*1.003,u,v,p[6]}
              end
              for i = 2, #poly-1 do
                local p,q,r = painted(poly[1]),painted(poly[i]),painted(poly[i+1])
                quad(lv,lm,p,q,r,p)
              end
            end
          end
        end
      end
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
    -- Rounded smoke: shaded latitude rings, shared by all puff instances.
    local function puffMesh()
      local pv, pm = {}, {}
      local u, v = uvFor(SLOTS.FACE, row)
      local function at(phi, theta)
        local x = math.cos(phi)*math.sin(theta)
        local y = math.sin(phi)
        local z = math.cos(phi)*math.cos(theta)
        return {x*0.5,y*0.5,z*0.5,u,v,shadeFor(x,y,z)}
      end
      for iy=0,3 do
        local a=-math.pi/2+math.pi*iy/4
        local b=-math.pi/2+math.pi*(iy+1)/4
        for ix=0,7 do
          local c=TAU*ix/8
          local d=TAU*(ix+1)/8
          quad(pv,pm,at(a,c),at(a,d),at(b,d),at(b,c))
        end
      end
      return Voxel3D.newMesh(pv,pm)
    end

    local fv, fm = {}, {}
    button(fv, fm, row, true)
    return { base = base, lid = lid, face = Voxel3D.newMesh(fv, fm),
             buttonRing = buttonRingMesh(row),
             glow = card(SLOTS.GLOW),
             puff = puffMesh() }
  end)
  meshes[row] = (ok and built) or false
  return meshes[row] or nil
end

-- dropped so a lost GL context (Android resume) rebuilds everything
function Pokeball.invalidate()
  meshes = {}
  palette = nil
end

-- TEST232: the tier's meshes and the palette, for a caller that poses the
-- ball with a matrix of its own -- the Pokemon Center machine's balls
-- (HealBalls3D) sit in its slots, which is no part of the capture flow
-- above. Memoised with everything else here, so asking every frame costs a
-- lookup and never a build; asking AGAIN every frame (rather than keeping
-- the answer) is what follows invalidate() to the rebuilt set. nil while
-- nothing can be built (headless, or a refused upload).
function Pokeball.shellParts(ball)
  local m, pal = meshesFor(ball or "POKE_BALL"), paletteTexture()
  if not (m and pal) then return nil end
  return m, pal
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
    visible = true,
  }, Pokeball)
end

-- ------- the verbs the capture flow speaks

function Pokeball:open()
  if self.emberAudio then
    local a=V.require("EmberLegacyAudio");a.capture("hit");a.capture("open")
  end
  self.buttonFlashT = nil
  self.capturePulseT = 0
  -- TEST62: brief visual intake hold; mechanics remain authoritative.
  self.intakeHold = 0.34
  self.impactFx = nil -- q57 owns contact energy; no legacy shard emitter.
  self.lidTarget, self.lidRate = 1, LID_RATE
  self.glow = 1
end

function Pokeball:close(rate)
  self.lidTarget, self.lidRate = 0, rate or LID_RATE
end

-- one rock on the ground; dir alternates shakes. Returns how long it takes,
-- so the caller can sequence the pauses between shakes.
function Pokeball:rock(dir)
  if self.emberAudio then
    self.emberShake=(self.emberShake or 0)+1
    V.require("EmberLegacyAudio").capture("shake",self.emberShake)
  end
  self.capturePulseT = self.capturePulseT or 0
  self.buttonFlashT = 0
  self.wobbleT = 0
  self.wobbleDir = dir or 1
  return WOBBLE_T
end

-- TEST29: 3D failed-capture breakout burst.
-- This is visual-only and is triggered by the already-established escape/open event.
function Pokeball:breakoutBurst(countOverride)
  self.breakoutFx = { t = 0, life = 0.90 }
  self.glow = math.max(self.glow or 0, 0.88)

  local puffs = {}
  local count = countOverride or 48 -- Rounded puffs need fewer overlapping instances.
  for i = 1, count do
    local th = TAU * (i - 1) / count + ((i % 3) * 0.11)
    puffs[i] = {
      t = 0, -- All puffs exist on the reveal frame, not a delayed stream.
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
  if self.emberAudio then V.require("EmberLegacyAudio").capture("success") end
  self.capturePulseT = nil
  -- Success is a pulse of the solid shell; no camera-facing celebration cards.
  self.buttonFlashT = nil
  self.catchFx, self.stars = nil, nil
  self.pulse = 0
  self.glow = 0
end

-- the breakout: the lid blown open and a hard flash
function Pokeball:burst()
  if self.emberAudio then V.require("EmberLegacyAudio").capture("breakout") end
  self.capturePulseT = nil
  -- Every breakout path owns the same smoke, including timed fallback.
  if not self.breakoutStarted then
    self.breakoutStarted = true
    self:breakoutBurst()
  end
  self.buttonFlashT = nil
  self.lidTarget, self.lidRate = 1, BURST_RATE * 1.65
  self.glow = 1
end

function Pokeball:busy()
  return self.wobbleT ~= nil or self.pulse ~= nil
      or math.abs(self.lid - self.lidTarget) > 0.02
end

function Pokeball:update(dt)
  if self.capturePulseT then self.capturePulseT=self.capturePulseT+dt end
  if self.buttonFlashT then
    self.buttonFlashT = self.buttonFlashT + dt
    if self.buttonFlashT >= WOBBLE_T then self.buttonFlashT = nil end
  end
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
      if self.lid > self.lidTarget then
        self.pulse = self.pulse or 0
        if self.emberAudio and self.lidTarget==0 then V.require("EmberLegacyAudio").capture("close") end
      end
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
  if not self.breakoutPuffs then return false end
  local m = meshesFor(self.ball)
  local pal = paletteTexture()
  if not (m and m.puff and pal) then return end

  Voxel3D.seams(false)
  Voxel3D.glass(false)
  local smokeScale = math.max(0.85, self.scale)
  local drawn = false
  for _,p in ipairs(self.breakoutPuffs) do
    if p.t and p.t >= 0 and p.t < p.life then
      local q = p.t / p.life
      local rr = (R * 0.85 + p.speed * p.t) * smokeScale
      local sx = self.pos[1] + math.sin(p.th) * rr
      local sz = self.pos[3] + math.cos(p.th) * rr
      local sy = self.pos[2] + (R * (0.25 + 0.7*math.sin(p.th*3)^2) + p.rise * p.t) * smokeScale
      local sc = p.size * (1.0 + 1.20*q) * ((1.0 - q)^0.65) * smokeScale
      local M = Mat4.mul(
        Mat4.translate(sx, sy, sz),
        Mat4.mul(
          Mat4.rotateY((p.spin or 0) * p.t),
          Mat4.mul(Mat4.rotateZ((p.spin or 0) * p.t * 0.63),
                   Mat4.scale(sc, sc, sc))
        )
      )
      Voxel3D.draw(m.puff, pal, M, (pull or 0) + 8)
      drawn = true
    end
  end
  return drawn
end

-- Shell-only draw for q57 release: no legacy smoke/trails/beam overlays.
function Pokeball:drawBreakShell(progress)
  local m,pal=meshesFor(self.ball),paletteTexture()
  if not(m and pal)then return false end
  local function ease(x)x=math.max(0,math.min(1,x));return x*x*x*(x*(x*6-15)+10)end
  local spread=ease((progress-.03)/.5)
  local shrink=1-ease((progress-.45)/.4)
  if shrink<=0 then return true end
  local base=self:matrix()
  for _,lower in ipairs({true,false})do
    local sign=lower and -1 or 1
    local part=Mat4.mul(base,Mat4.translate(sign*R*1.8*spread,
      R*(math.sin(spread*math.pi)*.8+.2*spread),-R*.4*spread))
    part=Mat4.mul(part,Mat4.rotateX(sign*1.1*spread))
    part=Mat4.mul(part,Mat4.rotateZ(sign*.7*spread))
    part=Mat4.mul(part,Mat4.scale(shrink,shrink,shrink))
    Voxel3D.draw(lower and m.base or m.lid,pal,part,0)
    if lower and m.face then Voxel3D.draw(m.face,pal,part,0)end
  end
  return true
end

function Pokeball:drawShell(pull)
  local m,pal=meshesFor(self.ball),paletteTexture()
  if not (m and pal) then return false end
  local model=self:matrix()
  Voxel3D.draw(m.base,pal,model,pull or 0)
  if m.face then Voxel3D.draw(m.face,pal,model,pull or 0) end
  local lid=lidMatrix(self.lid)
  Voxel3D.draw(m.lid,pal,lid and Mat4.mul(model,lid) or model,pull or 0)
  return true
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

  Voxel3D.seams(false)
  Voxel3D.glass(false)
  local model = self:matrix()
  Voxel3D.draw(m.base, pal, model, pull)
  if m.face then Voxel3D.draw(m.face,pal,model,pull) end
  if m.buttonRing and self.capturePulseT then
    local age=self.buttonFlashT or self.capturePulseT
    local pulse=math.sin(math.pi*(age % WOBBLE_T)/WOBBLE_T)^2
    local brightness=.22+.78*pulse
    Voxel3D.flatten({brightness,.015*brightness,.045*brightness},1)
    local ok,err=pcall(Voxel3D.draw,m.buttonRing,pal,model,pull)
    Voxel3D.flatten(nil)
    if not ok then error(err,0) end
  end
  local lidM = lidMatrix(self.lid)
  Voxel3D.draw(m.lid, pal, lidM and Mat4.mul(model, lidM) or model, pull)

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
  if m.face then shadowMap.draw(m.face, pal, model) end
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
