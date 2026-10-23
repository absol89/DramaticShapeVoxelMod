-- The Pokemon Center heal machine, built (TEST232): real Poke Balls seated in
-- the machine's slots and a lit screen on its console, drawn in the voxel
-- world pass instead of composited over it.
--
-- HealOverlay put the GB's two OAM tiles -- the monitor ($7c) and the ball
-- ($7d) -- back onto the 3D machine as flat sprites after the frame. On the
-- town machines that lands them on the right surfaces, but they stay what
-- they are: flat orange-and-black pixel art on a lit 3D cabinet. On the
-- Indigo Plateau's own machine (LeagueRoomsHall.lobby) they land nowhere at
-- all: that cabinet stands 10px further back and 4px west of where the GB
-- drawing puts its machine, so the tiles hang in the air in front of it,
-- half behind the counter, with the monitor floating over its gold lid.
--
-- Here the balls are the battle's own Poke Ball meshes (Pokeball.shellParts:
-- red lid, white base, dark band, white button) and the monitor is a soft
-- emissive panel, all drawn by Voxel3D.draw from inside the world pass -- so
-- they are depth-tested against the room (the counter in front hides them
-- exactly as it hides the cabinet) and shaded through the scene shader by
-- the same light as the cabinet they sit in.
--
--   balls   one per ha.lit, in the GB's fill order, each popping in over
--           POP_FRAMES with a small overshoot and a sparkle
--   flash   FlashSprite8Times's flashed half-beats (ha.visible == false)
--           light every slot from behind its ball and brighten the ball
--           toward a warm light, where the GB swapped two palette shades
--   screen  lit while the machine runs, a blip per ball, a pulse per beat
--
-- WHERE, per machine (`profile`, resolved once per heal):
--   league  the Indigo Plateau lobby's machine, when LeagueRooms draws that
--           room: a 3x2 grid of verde panels, a sphere at each one's heart.
--           It has no console, so a light strip in the marble between the
--           two rows of panels stands in for the monitor.
--   town    a town Center's machine, when InteriorRooms draws the room:
--           HealOverlay.points' two columns, which that machine was built to
--           match (InteriorTown.center), and its console's inScreen quad
--   gb      the engine's own extruded machine: HealOverlay.points as they
--           are, and the screen inset its drawing cuts
--
-- HOW IT GETS INTO THE FRAME: DockLights.drawLate is the world pass's late
-- seam (after the cast, the grass and the water), and it is wrapped the way
-- ChampionParade wraps it. The solid balls go down before the original runs,
-- so any glow it draws tests against them; the additive light after it.
-- HealOverlay.draw -- the 2D path main.lua runs in the overlay phase -- asks
-- claimed(ha) first and composites nothing when this frame's world pass
-- already stood the machine up. Anything that stops that (no Voxel3D, no
-- Poke Ball meshes, a draw error, the seam unwrapped under us) leaves the
-- claim unmade, and today's 2D overlay draws exactly as before.
--
-- Per frame this allocates nothing of its own: the matrices and colours are
-- preallocated and rewritten in place, and everything that depends on the
-- room is resolved once per heal.
--
-- The flat and tilt renderers never reach any of this: they run neither the
-- voxel world pass nor HealOverlay, and the engine's fxHeal draws for them.

local V = ...

local M = {}

local sqrt, min, max, floor = math.sqrt, math.min, math.max, math.floor

-- ------- tunables (world pixels; frames are the engine's 60/s ha.timer)

M.TILT = math.rad(10)       -- the buttons tip up toward the usual camera
M.PROUD = 0.55              -- a centre stands this many radii off its slot face
M.POP_FRAMES = 9            -- a new ball's scale-in
M.POP_BACK = 1.70158        -- ease-out-back constant: ~10% overshoot
M.GLINT_FRAMES = 14         -- and its sparkle dies away over this
M.GLINT_SIZE = 1.25         -- the sparkle card's half-size, in ball radii
M.GLINT_GAIN = 0.7
M.HALO_SIZE = 1.7           -- a slot's backlight, flat on its face, in radii
                            -- (the League's top row stops short of the lid)
M.HALO_GAIN = 1.15
M.BRIGHT = 0.30             -- how far a flashed ball goes toward LIGHT
M.SCREEN_ON = 0.55          -- the screen's glow while the machine runs
M.SCREEN_BLIP = 0.35        -- what a new ball adds to it
M.SCREEN_BEAT = 0.70        -- and what a flashed half-beat adds
M.SCREEN_RAMP = 6           -- frames for the screen to come on
M.EFFECT_PULL = 0.45        -- additive cards win the tie with their face
M.HALO_PULL = 0.15          -- a backlight wins it too, but not a lid's lip
M.MAX_FAILS = 3             -- failed frames in a row before 2D for good
M.MAX_INSTALLS = 4          -- re-wraps of the seam per session, at most

local LIGHT = { 1.00, 0.95, 0.84 }   -- what a flashed ball brightens toward
local GLINT = { 1.00, 0.93, 0.78 }
local SCREEN = { 0.55, 0.95, 1.00 }

-- The League lobby's machine, as LeagueRoomsHall.lobby builds it:
--   L.box(76,0,66,108,20,80,'lgMarble')              the cabinet, face z=80
--   for k=0,5: bx=80+(k%3)*9, by=k<3 and 15 or 9
--     L.box(bx,by,80,bx+6,by+4,80.4,'lgVerde')       a panel
--     L.sphere(bx+3,by+2,80.9,1.5,1.5,1.0, ...)      the sphere at its heart
-- A ball of r 1.75 stood PROUD off the panel swallows that sphere whole.
-- tests/heal_balls3d_test.lua holds these against the room's own quads.
M.LEAGUE = { x = 83, dx = 9, top = 17, bottom = 11, face = 80.4, r = 1.75,
             strip = { x0 = 80, x1 = 104, y0 = 13.4, y1 = 14.6, z = 80.02, gain = 0.5 } }

-- A town Center's machine, as InteriorTown.center builds it: the slot panel
-- at z 26..26.3 (HealOverlay's FRONT_Z plane), dark discs at 26.35 inside
-- steel rings r 2.0..2.5 at 26.4; the console's inScreen quad x +-6.2,
-- y 20..27.8, at 24.25 (0.25 off HealOverlay's CONSOLE_Z plane).
M.TOWN = { face = 0.4, r = 2.0, hw = 6.0, y0 = 20.2, y1 = 27.6, z = 0.25 }

-- The engine's extruded machine: the cabinet face IS the FRONT_Z plane, and
-- the screen is the inset drawn rows 6..8 cut into the console, heights
-- 22..25 and the monitor tile's six lit columns wide.
M.GB = { face = 0.0, r = 2.0, hw = 3.0, y0 = 22, y1 = 25, z = 0.0 }

-- ------- per-heal state, preallocated

local NSLOT = 6
local slots = {}
for i = 1, NSLOT do slots[i] = { 0, 0, 0, 0, 0 } end   -- centre x, y, z; radius; face z
local screen = { on = false, x = 0, y = 0, z = 0, hw = 0, hh = 0, gain = 1 }
local cur = { ha = nil, map = nil, kind = nil }
M.slots, M.screen, M.current = slots, screen, cur

-- this frame's pose of each ball, and of the machine
local scaleOf, glintOf, haloOf, brightOf = {}, {}, {}, {}
for i = 1, NSLOT do scaleOf[i], glintOf[i], haloOf[i], brightOf[i] = 0, 0, 0, 0 end
local frame = { n = 0, beat = 0, screen = 0 }
M.scaleOf, M.glintOf, M.haloOf, M.brightOf, M.frame = scaleOf, glintOf, haloOf, brightOf, frame

local logged = {}
local function log(key, fmt, ...)
  if logged[key] then return end
  logged[key] = true
  local L = V.mod and V.mod.log
  if L and L.info then pcall(L.info, L, "heal machine 3D: " .. fmt, ...) end
end

-- ------- which machine this is

-- whether a room module is what draws this map: it claims it, and its mesh
-- is built (a failed build leaves the engine's extruded room in place)
local function roomLive(name, map)
  local ok, R = pcall(V.require, name)
  if not (ok and type(R) == "table" and R.accepts and R.ready) then return false end
  local okA, yes = pcall(R.accepts, map)
  if not (okA and yes) then return false end
  local okR, ready = pcall(R.ready, map.id)
  return okR and ready == true
end

function M.resolve(state, ha)
  local map = state and state.map
  if cur.ha == ha and cur.map == map and cur.kind then return cur.kind end
  cur.ha, cur.map, cur.kind = ha, map, nil
  local id = map and map.id
  if id == "INDIGO_PLATEAU_LOBBY" and roomLive("LeagueRooms", map) then
    local L = M.LEAGUE
    for k = 0, NSLOT - 1 do
      local s = slots[k + 1]
      s[1] = L.x + (k % 3) * L.dx
      s[2] = k < 3 and L.top or L.bottom
      s[3] = L.face + M.PROUD * L.r
      s[4], s[5] = L.r, L.face
    end
    local st = L.strip
    screen.on, screen.gain = true, st.gain or 1
    screen.x, screen.y, screen.z = (st.x0 + st.x1) / 2, (st.y0 + st.y1) / 2, st.z
    screen.hw, screen.hh = (st.x1 - st.x0) / 2, (st.y1 - st.y0) / 2
    cur.kind = "league"
    return cur.kind
  end
  -- the GB's own placement, read off the drawing the OAM lands on, which the
  -- town machine was built to match: every slot, whatever is lit yet
  local town = type(id) == "string" and id:find("_POKECENTER", 1, true) ~= nil
               and roomLive("InteriorRooms", map)
  local P = town and M.TOWN or M.GB
  local HO = V.require("HealOverlay")
  local n = 0
  for _, p in ipairs(HO.points({ px = ha.px, py = ha.py, lit = NSLOT })) do
    if p.kind == "monitor" then
      screen.on, screen.gain = true, 1
      screen.x, screen.z = p.x, p.z + P.z
      screen.y, screen.hh = (P.y0 + P.y1) / 2, (P.y1 - P.y0) / 2
      screen.hw = P.hw
    elseif n < NSLOT then
      n = n + 1
      local s = slots[n]
      s[1], s[2], s[3], s[4], s[5] = p.x, p.h, p.z + P.face + M.PROUD * P.r, P.r, p.z + P.face
    end
  end
  cur.kind = town and "town" or "gb"
  return cur.kind
end

-- ------- the animation, from the engine's own record

local function easeBack(u)
  if u >= 1 then return 1 end
  if u <= 0 then return 0 end
  local k, v = M.POP_BACK, u - 1
  return 1 + (k + 1) * v * v * v + k * v * v
end
M.easeBack = easeBack

-- 0..1: the flashed half-beat, with a short tail as each one ends
local function beatOf(ha, phase, t)
  if phase ~= "flash" then return 0 end
  if ha.visible == false then return 1 - 0.3 * min(1, t / 10) end
  -- the first half of the jingle is unflashed: no tail to fall from
  if (tonumber(ha.flashes) or 0) < 2 then return 0 end
  local tail = 1 - t / 3
  return tail > 0 and 0.45 * tail or 0
end

-- Fills this frame's scale, sparkle, backlight and brightness for every lit
-- ball, and the screen's level. Pure (no GPU): the tests drive it per frame.
function M.animate(ha)
  local lit = floor(tonumber(ha.lit) or 0)
  lit = max(0, min(NSLOT, lit))
  local phase = ha.phase or "balls"
  local t = max(0, tonumber(ha.timer) or 0)
  local beat = beatOf(ha, phase, t)
  local newest = 0
  for i = 1, lit do
    if phase ~= "flash" and i == lit then
      local g = 1 - t / M.GLINT_FRAMES
      g = g > 0 and g * g or 0
      scaleOf[i] = easeBack((t + 1) / M.POP_FRAMES)
      glintOf[i], haloOf[i], brightOf[i] = g, 0.5 * g, 0.4 * g
      newest = g
    else
      scaleOf[i], glintOf[i], haloOf[i], brightOf[i] = 1, 0, beat, beat
    end
  end
  frame.n, frame.beat = lit, beat
  local run = phase == "flash" and M.SCREEN_RAMP or ((lit - 1) * 30 + t + 1)
  local on = min(1, max(0, run / M.SCREEN_RAMP))
  frame.screen = on * (M.SCREEN_ON + M.SCREEN_BLIP * newest + M.SCREEN_BEAT * beat)
                * screen.gain
  return lit
end

-- ------- matrices, rewritten in place (row-major, like Mat4)

local BALL = { 1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1 }
local CARD = { 1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1 }
M.BALL_MATRIX, M.CARD_MATRIX = BALL, CARD

-- T(centre) * Rx(-TILT) * S(k r / Pokeball.R): the button (+Z) out of the
-- machine and tipped up by TILT
local function poseBall(s, k, ballR, c, sn)
  local sc = k * s[4] / ballR
  BALL[1], BALL[2], BALL[3], BALL[4] = sc, 0, 0, s[1]
  BALL[5], BALL[6], BALL[7], BALL[8] = 0, c * sc, sn * sc, s[2]
  BALL[9], BALL[10], BALL[11], BALL[12] = 0, -sn * sc, c * sc, s[3]
end

-- a unit card (x, y in -1..1) turned to face `eye`, standing `ahead` in
-- front of (x, y, z) along the ray to the eye, half-size `size`
local function poseCard(x, y, z, ahead, size, eye)
  local fx, fy, fz = 0, 0, 1
  if eye then
    fx, fy, fz = eye[1] - x, eye[2] - y, eye[3] - z
    local l = sqrt(fx * fx + fy * fy + fz * fz)
    if l > 1e-4 then fx, fy, fz = fx / l, fy / l, fz / l else fx, fy, fz = 0, 0, 1 end
  end
  local rx, rz = fz, -fx                     -- world up x f
  local rl = sqrt(rx * rx + rz * rz)
  if rl > 1e-4 then rx, rz = rx / rl, rz / rl else rx, rz = 1, 0 end
  local ux, uy, uz = fy * rz, fz * rx - fx * rz, -fy * rx   -- f x right
  CARD[1], CARD[2], CARD[3], CARD[4] = rx * size, ux * size, fx, x + fx * ahead
  CARD[5], CARD[6], CARD[7], CARD[8] = 0, uy * size, fy, y + fy * ahead
  CARD[9], CARD[10], CARD[11], CARD[12] = rz * size, uz * size, fz, z + fz * ahead
end

-- the unit card laid flat on a face that looks down +Z (the machine's
-- front): the screen, or a slot's backlight
local function poseFlat(x, y, z, hw, hh)
  CARD[1], CARD[2], CARD[3], CARD[4] = hw, 0, 0, x
  CARD[5], CARD[6], CARD[7], CARD[8] = 0, hh, 0, y
  CARD[9], CARD[10], CARD[11], CARD[12] = 0, 0, 1, z
end

-- ------- the little GPU kit: one card mesh and two soft textures

local quadMesh, glowTex, screenTex   -- false once refused

local function softTexture(w, h, alpha)
  local ok, img = pcall(function()
    local d = love.image.newImageData(w, h)
    for y = 0, h - 1 do
      for x = 0, w - 1 do d:setPixel(x, y, 1, 1, 1, alpha(x, y, w, h)) end
    end
    local t = love.graphics.newImage(d)
    t:setFilter("linear", "linear")
    pcall(d.release, d)
    return t
  end)
  return ok and img or false
end

-- a round glint: full at the heart, gone at the rim
local function glintAlpha(x, y, w, h)
  local u, v = (x + 0.5) / w * 2 - 1, (y + 0.5) / h * 2 - 1
  local r = sqrt(u * u + v * v)
  if r >= 1 then return 0 end
  return min(1, (1 - r) ^ 1.8 * 1.25)
end

-- a lit screen: soft edges, brighter toward the top, faint scan lines
local function screenAlpha(x, y, w, h)
  local ex = min(x + 0.5, w - x - 0.5) / 3
  local ey = min(y + 0.5, h - y - 0.5) / 3
  local edge = min(1, ex) * min(1, ey)
  edge = edge * edge * (3 - 2 * edge)
  local scan = (floor(y / 2) % 2 == 0) and 1 or 0.8
  local fall = 1 - 0.25 * (y / h)
  return max(0, min(1, edge * scan * fall))
end

local function kit(R)
  if quadMesh == nil then
    local verts = { { -1, -1, 0, 0, 1, 1 }, { 1, -1, 0, 1, 1, 1 },
                    { 1, 1, 0, 1, 0, 1 }, { -1, 1, 0, 0, 0, 1 } }
    local okM, mesh = pcall(R.newMesh, verts, { 1, 2, 3, 1, 3, 4 })
    quadMesh = okM and mesh or false
  end
  if glowTex == nil then glowTex = softTexture(32, 32, glintAlpha) end
  if screenTex == nil then screenTex = softTexture(48, 24, screenAlpha) end
  return quadMesh or nil
end

function M.invalidate()
  for _, o in ipairs({ quadMesh, glowTex, screenTex }) do
    if o and o.release then pcall(o.release, o) end
  end
  quadMesh, glowTex, screenTex = nil, nil, nil
  cur.ha, cur.map, cur.kind = nil, nil, nil
end

-- ------- drawing, in the world pass

local GR            -- Voxel3D, for the glow pass below
local glowsOff = false

-- The balls, solid. Returns true when the machine stood in this frame.
local function solids(state)
  local ha = state and state.healAnim
  if not ha or M.disabled then return false end
  local okR, R = pcall(V.require, "Voxel3D")
  if not (okR and type(R) == "table" and R.draw and R.vp) then return false end
  -- the scene's own shader is bound for the length of the pass; with none
  -- there is no pass to draw into, and the 2D overlay is the answer
  if not (love.graphics.getShader and love.graphics.getShader()) then return false end
  local okP, PB = pcall(V.require, "Pokeball")
  if not (okP and type(PB) == "table" and PB.shellParts) then return false end
  local parts, pal = PB.shellParts("POKE_BALL")
  if not (parts and parts.base and parts.lid) then return false end
  M.resolve(state, ha)
  local n = M.animate(ha)
  GR = R
  local ballR = PB.R or 2.2
  local c, sn = math.cos(M.TILT), math.sin(M.TILT)
  R.blend(nil)            -- the world's own state: depth tested and written
  R.seams(false)          -- not on the voxel grid
  R.glass(false)          -- and not textured from the atlas
  for i = 1, n do
    local k = scaleOf[i]
    if k > 0.001 then
      poseBall(slots[i], k, ballR, c, sn)
      local b = brightOf[i] * M.BRIGHT
      if b > 0.004 then R.flatten(LIGHT, b) end
      R.draw(parts.base, pal, BALL, 0)
      if parts.face then R.draw(parts.face, pal, BALL, 0) end
      R.draw(parts.lid, pal, BALL, 0)
      if b > 0.004 then R.flatten(nil) end
    end
  end
  R.seams(true)
  R.glass(true)
  return true
end

-- The light: the screen and the glints, additive, depth-tested, writing no
-- depth. Runs inside Voxel3D.withEffect, which owns and restores the state.
local function glowDraw()
  local R, g = GR, love.graphics
  local quad = kit(R)
  if not quad then return end
  if screen.on and screenTex and frame.screen > 0.004 then
    local k = frame.screen
    poseFlat(screen.x, screen.y, screen.z, screen.hw, screen.hh)
    g.setColor(SCREEN[1] * k, SCREEN[2] * k, SCREEN[3] * k, 1)
    R.draw(quad, screenTex, CARD, M.EFFECT_PULL)
  end
  if glowTex then
    local eye = R.eye
    for i = 1, frame.n do
      local s = slots[i]
      -- the slot lit from behind its ball: the ball itself hides the heart
      -- of it, so what shows is a ring of light round the ball
      local k = haloOf[i] * M.HALO_GAIN
      if k > 0.004 then
        local h = s[4] * M.HALO_SIZE
        poseFlat(s[1], s[2], s[5] + 0.03, h, h)
        g.setColor(GLINT[1] * k, GLINT[2] * k, GLINT[3] * k, 1)
        R.draw(quad, glowTex, CARD, M.HALO_PULL)
      end
      -- and a new ball's sparkle, in front of it, turned to the eye
      k = glintOf[i] * M.GLINT_GAIN
      if k > 0.004 and scaleOf[i] > 0.001 then
        local r = s[4] * scaleOf[i]
        poseCard(s[1], s[2], s[3], r + 0.2, r * M.GLINT_SIZE, eye)
        g.setColor(GLINT[1] * k, GLINT[2] * k, GLINT[3] * k, 1)
        R.draw(quad, glowTex, CARD, M.EFFECT_PULL)
      end
    end
  end
  g.setColor(1, 1, 1, 1)
end

local function glows()
  if glowsOff or not GR or not GR.withEffect then return end
  local need = frame.screen > 0.004 and screen.on
  if not need then
    for i = 1, frame.n do
      if glintOf[i] > 0.004 or haloOf[i] > 0.004 then need = true; break end
    end
  end
  if need then GR.withEffect("add", glowDraw) end
end

-- whatever a failed draw left behind, put back
local function recover()
  local okR, R = pcall(V.require, "Voxel3D")
  if okR and type(R) == "table" then
    if R.flatten then pcall(R.flatten, nil) end
    if R.blend then pcall(R.blend, nil) end
    if R.seams then pcall(R.seams, true) end
    if R.glass then pcall(R.glass, true) end
  end
  pcall(love.graphics.setColor, 1, 1, 1, 1)
end

-- ------- the claim: this frame's world pass drew the machine for this heal

local ranVp, drawnVp, drewHa = nil, nil, nil
local fails = 0
M.disabled = false

-- One pass through the late seam. `orig` is whatever we wrapped. A frame's
-- view-projection table is new every frame (Voxel3D.beginScene), so it keys
-- "this frame": a seam wrapped twice still draws the machine once.
local function late(orig, state, ...)
  local okR, R = pcall(V.require, "Voxel3D")
  local vp = okR and type(R) == "table" and R.vp or nil
  local mine = vp ~= nil and vp ~= ranVp
  if mine then
    ranVp, drawnVp, drewHa = vp, nil, nil
    local ok, drew = pcall(solids, state)
    if ok and drew then
      drawnVp, drewHa, fails = vp, state.healAnim, 0
    elseif not ok then
      fails = fails + 1
      log("solid", "the balls failed (%s); the 2D overlay stands in", tostring(drew))
      recover()
      if fails >= M.MAX_FAILS then
        M.disabled = true
        log("off", "off for this session after %d failed frames", fails)
      end
    end
  end
  local ok, a, b = pcall(orig, state, ...)
  if mine and drawnVp == vp then
    local okG, err = pcall(glows)
    if not okG then
      glowsOff = true
      log("glow", "the glow failed (%s); balls only", tostring(err))
      recover()
    end
  end
  if not ok then error(a, 0) end
  return a, b
end

local wrappers = setmetatable({}, { __mode = "k" })
local installs = 0

-- Wrap DockLights.drawLate. Called when HealOverlay loads (main.lua requires
-- it early, ahead of ChampionParade's own wrap, whose dispose then restores
-- ours), and again by claimed() if the seam was unwrapped under us.
function M.install()
  local ok, DL = pcall(V.require, "DockLights")
  if not (ok and type(DL) == "table" and type(DL.drawLate) == "function") then
    return false
  end
  if wrappers[DL.drawLate] then return true end
  if installs >= M.MAX_INSTALLS then return false end
  installs = installs + 1
  local orig = DL.drawLate
  local w = function(state, ...) return late(orig, state, ...) end
  wrappers[w] = true
  DL.drawLate = w
  return true
end

-- HealOverlay.draw asks this, in the overlay phase of the same frame: true
-- when the world pass stood this heal's machine up, so nothing is left to
-- composite. False in every other case -- and if the late seam never reached
-- us this frame at all, it is wrapped again for the next one.
function M.claimed(ha)
  if ha == nil or M.disabled then return false end
  local okR, R = pcall(V.require, "Voxel3D")
  local vp = okR and type(R) == "table" and R.vp or nil
  if vp ~= nil and drawnVp == vp and drewHa == ha then return true end
  if vp ~= nil and ranVp ~= vp then M.install() end
  return false
end

pcall(function() require("src.render.Assets").register(M.invalidate) end)

return M
