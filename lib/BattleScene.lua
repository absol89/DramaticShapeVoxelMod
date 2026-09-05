-- Overworld battles: one frame of the arena, as geometry.
--
-- The same world the free-roam mode draws, from a placed camera instead of
-- the orbit, at the WINDOW's own pixel resolution -- not the GB's. The
-- backdrop reaches the screen through Renderer's worldOverride, the seam a
-- render pipeline's finished world image already composites through, which
-- is drawn one canvas pixel to one screen pixel; the 160x144 battle screen
-- then blits over it in the classic letterbox. So the world is as crisp as
-- the free-roam diorama and the pics, HUDs and text box stay exactly the
-- chunky GB art they are.
--
-- Rendering the whole window rather than just the letterbox means the
-- framing has to be split in two. The RIG frames the GB's 160x144 (see
-- BattleCam, which is solved against coordinates in that frame); this
-- module widens the lens by exactly the ratio the window bears to the
-- letterbox, so the letterbox sub-rectangle of what gets rendered is
-- bit-for-bit the framing the rig asked for, and everything outside it is
-- extra picture. That is what lets the two mons be PINNED: their cells
-- project to the same GB coordinates at any window size or zoom.
--
-- Characters are deliberately absent. The overworld cast is culled for the
-- length of the battle (see OverworldBattle), so this pass has terrain,
-- grass and flowers and nothing that walks -- the arena is empty, which is
-- what makes it an arena.
--
-- Everything expensive is shared with the free-roam mode rather than
-- duplicated: the same chunk meshes out of ChunkMesher, the same palette
-- atlas out of TerrainAtlas, the same sun out of ShadowMap. A battle on a
-- map already meshed for walking around costs the frame it draws and
-- nothing else.

-- the mod namespace (see main.lua): V.require loads a sibling module
local V = ...

local Mat4 = V.require("Mat4")
local Voxel3D = V.require("Voxel3D")
local ShadowMap = V.require("ShadowMap")
local ChunkMesher = V.require("ChunkMesher")
local TerrainAtlas = V.require("TerrainAtlas")
local VoxelScene = V.require("VoxelScene")
local BattleCam = V.require("BattleCam")
local BattleBillboard = V.require("BattleBillboard")
local StadiumModels = V.require("StadiumModels")
local DayNight = V.require("DayNight")
local UiBackplates = V.require("UiBackplates")
local Gen6Backdrop = V.require("Gen6Backdrop")
local Images = V.require("BackdropImage")
local BossBackdrop = V.require("BossBackdrop")
local AntiAlias = V.require("AntiAlias")
local CommunityFlora = V.require("CommunityFlora")
local CharacterRenderers = V.require("CharacterRenderers")
local PaletteFX = require("src.render.PaletteFX")
local Map = require("src.world.Map")

local BattleScene = {}
BattleScene.capture = nil

-- ------- NORMAL BATTLE 3D POKE BALL -- TEST2
--
-- Unlike LET'S GO, a normal Gen 1 throw is driven by BattleState.ballChain.
-- TEST2 mirrors that chain with the SAME real Pokeball prop used by CatchThrow.
-- The vanilla 2D ball is intentionally left intact for this test: the goal is
-- to prove the event timing + 3D draw path before suppressing the old sprite.
local Pokeball = V.require("Pokeball")
local PokeballSettings = V.require("PokeballSettings")
-- TEST64B: this local must be declared HERE, before every function that uses it.
-- startNormalBall(), normalBallTick(), and monCards() now all close over the
-- exact same normalBall upvalue.
local normalBall = nil

function BattleScene.startNormalBall(ballId, caught, shakes, owner)
  if not PokeballSettings.active() then return false end
  -- Never compete with the dedicated LET'S GO capture renderer.
  if BattleScene.capture then return false end
  -- New throw owns the slot; clear any retained successful ball from the
  -- previous encounter/throw before creating the next prop.
  normalBall = nil
  local ok, ball = pcall(Pokeball.new, ballId or "POKE_BALL")
  if not ok or not ball then return false end
  normalBall = {
    ball = ball,
    id = ballId or "POKE_BALL",
    caught = caught and true or false,
    shakes = tonumber(shakes) or 0,
    t = 0,
    last = nil,
    shakeDone = 0,
    phase = "throw",
    finished = false,
    captureOpened = false,
    captureClosed = false,
    caughtEvent = false,
    escapeEvent = false,
    captureFxT = 0,
    hideEnemyForCapture = false,
    postCloseHideT = nil,
    owner = owner, -- TEST66: owning BattleState, shared with Stadium Battle FX
  }
  ball.spin = 5.0
  ball.tumble = 8.0
  return true
end

local function clearExternalIntake(n)
  local owner = n and n.owner
  if type(owner) == "table" then
    owner.dramaticShape3DBallIntake = nil
    owner.dramaticShape3DBallHide = nil
  end
end

function BattleScene.cancelNormalBall()
  clearExternalIntake(normalBall)
  normalBall = nil
end

function BattleScene.finishNormalBattleBall()
  clearExternalIntake(normalBall)
  normalBall = nil
end

-- TEST19: sync the real 3D prop to the engine's capture sub-animations.
function BattleScene.normalBallAnimEvent(moveId)
  local n = normalBall
  if not (n and n.ball) then return false end

  if moveId == "POOF_ANIM" or moveId == "HIDEPIC_ANIM" then
    if not n.captureOpened then
      n.captureOpened = true
      n.captureClosed = false
      n.phase = "capture_open"
      n.captureFxT = PokeballSettings.captureDuration()
      n.ball:open()
    end
    return true
  end

  if moveId == "SHAKE_ANIM" then
    -- TEST42: one SHAKE_ANIM contains every capture shake. Enter the closed,
    -- grounded state here, but do not rock yet: AnimPlayer emits one
    -- SFX_TINK event for each real shake, after any animation load frames.
    -- LegendaryPokeballs forwards those timed events below.
    n.phase = "shake_wait"
    n.captureOpened = true
    n.captureClosed = true
    n.captureFxT = 0
    n.hideEnemyForCapture = true
    n.ball:close()
    return true
  end

  if moveId == "SHOWPIC_ANIM" and not n.caught then
    n.hideEnemyForCapture = false
    n.postCloseHideT = nil
    if not n.escapeEvent then
      n.escapeEvent = true
      n.escapePendingT = 0.04
      n.phase = "escape_pending"
    end
    return true
  end

  return false
end

-- TEST42: AnimPlayer:pollEffects exposes SFX_TINK on the exact 60 Hz frame
-- that BattleState plays the native shake sound. There can be several of
-- these inside one SHAKE_ANIM, so each event owns one and only one 3D rock.
function BattleScene.normalBallTimedEvent(effect)
  local n = normalBall
  if not (n and n.ball) then return false end
  if effect ~= "SFX_TINK" or n.shakeDone >= n.shakes then return false end

  n.phase = "shake"
  n.captureOpened = true
  n.captureClosed = true
  n.captureFxT = 0
  n.hideEnemyForCapture = true
  n.ball:close()
  n.shakeDone = n.shakeDone + 1
  n.ball:rock((n.shakeDone % 2 == 1) and 1 or -1)
  return true
end

function BattleScene.normalBallCaughtEvent()
  local n = normalBall
  if not (n and n.ball and n.caught) then return false end
  if n.caughtEvent then return true end

  n.caughtEvent = true
  n.finished = true
  n.phase = "caught"
  n.ball:close()
  n.ball.spin, n.ball.tumble = 0, 0
  n.ball:catchClick()
  return true
end

local function normalBallTick(arena, groundY)
  local n = normalBall
  if n and not PokeballSettings.active() then
    BattleScene.cancelNormalBall()
    return
  end
  if not (n and n.ball and arena and arena.player and arena.enemy) then return end

  local now = (love and love.timer and love.timer.getTime and love.timer.getTime()) or os.clock()
  local dt = n.last and math.max(0, math.min(0.08, now - n.last)) or (1/60)
  n.last = now
  n.t = n.t + dt

  -- TEST56: Pokeball.lua can now safely know whether it is actually airborne.
  n.ball.phase = n.phase
  if n.captureFxT and n.captureFxT > 0 then
    n.captureFxT = math.max(0, n.captureFxT - dt)

    -- TEST63: the Pokemon now physically shrinks and travels into the open
    -- ball during the full intake window. Do not blink it out halfway through.
    -- Hide only when it is essentially at the ball mouth.
    if n.captureOpened and not n.captureClosed and n.captureFxT <= 0.035 then
      n.hideEnemyForCapture = true
    end

    if n.captureFxT <= 0 and n.captureOpened and not n.captureClosed then
      n.hideEnemyForCapture = true
    end
  end

  if n.postCloseHideT then
    n.postCloseHideT = n.postCloseHideT - dt
    if n.postCloseHideT <= 0 then
      n.postCloseHideT = nil
      n.hideEnemyForCapture = true
    end
  end

  n.ball:update(dt)

  -- TEST66: public visual bridge on the live BattleState.
  -- Stadium Battle FX owns the skinned 3D Pokemon, so publish the intake
  -- choreography where that independent renderer can read it without either
  -- mod requiring the other's private Lua namespace.
  if type(n.owner) == "table" then
    if n.captureOpened and not n.captureClosed and n.captureFxT and n.captureFxT > 0 then
      local remain = math.max(0, math.min(1, n.captureFxT / PokeballSettings.captureDuration()))
      local raw = 1 - remain
      local q = raw * raw * (3 - 2 * raw)
      n.owner.dramaticShape3DBallIntake = {
        active = true,
        progress = q,
        scale = math.max(0.055, 1 - 0.945*q),
        pull = q*q,
        hide = n.hideEnemyForCapture == true,
        ballX = n.ball.pos[1],
        ballY = n.ball.pos[2] + (Pokeball.R or 2.2)*0.18*(n.ball.scale or 1),
        ballZ = n.ball.pos[3],
      }
    else
      n.owner.dramaticShape3DBallIntake = nil
    end

    -- TEST70: keep the visible enemy hidden AFTER the active intake bridge
    -- clears. In TEST69 the bridge became nil on the exact close frame, so
    -- Stadium recomputed mon.visible/full scale for a frame before the
    -- engine's own capture hide caught up, causing the obvious "pop".
    --
    -- Hold the hide through shakes / successful catch. Release it only when
    -- the failed-capture escape sequence begins.
    local escaping = n.phase == "escape" or n.phase == "escape_pending"
                     or n.escapeEvent == true
    n.owner.dramaticShape3DBallHide =
      (n.hideEnemyForCapture == true and not escaping) and true or nil
  end

  -- TEST21: SHOWPIC begins slightly before the Pokemon is visibly out.
  -- Delay only the 3D breakout so those two visual moments land together.
  if n.escapePendingT then
    n.escapePendingT = n.escapePendingT - dt
    if n.escapePendingT <= 0 then
      n.escapePendingT = nil
      n.finished = true
      n.phase = "escape"
      n.ball:burst()
      if n.ball.breakoutBurst then n.ball:breakoutBurst() end
    end
  end

  local p, e = arena.player, arena.enemy
  local R = (Pokeball.R or 2.2) * ((n.ball and n.ball.scale) or 1)

  -- TEST105: normal-battle catch ball starts from the persistent 3D trainer.
  -- RED 3D PLAYER already exports the live battle hand world position every
  -- frame as RED3D_BATTLE_HAND_WORLD.  Use only X/Z from that point for the
  -- launch origin, while preserving Dramatic Shape's proven enemy target,
  -- catch timing, opening, smoke, shakes and outcome choreography.
  --
  -- If the trainer bridge is absent for any reason, fall back to the stock
  -- player battle slot so this remains safe with other character setups.
  local startX, startZ = p[1], p[2]
  local startY = groundY + R + 6.5
  local ashHand = CharacterRenderers.battleHandWorld()
                  or rawget(_G, "RED3D_BATTLE_HAND_WORLD")
  if type(ashHand) == "table"
      and tonumber(ashHand[1]) and tonumber(ashHand[3]) then
    startX = tonumber(ashHand[1])
    startZ = tonumber(ashHand[3])
    -- Keep the launch around Ash's hand height when available, but clamp it
    -- above the arena so a stale/odd skeleton sample cannot bury the ball.
    if tonumber(ashHand[2]) then
      startY = math.max(groundY + R + 4.0, tonumber(ashHand[2]))
    end
  end

  -- Same 0.72s throw arc, now from Ash to the enemy instead of from the
  -- active Pokemon slot.  The longer travel distance should make the arc
  -- read naturally with Ash standing far in the background.
  local throwT = 0.72
  -- TEST41: POOF/HIDEPIC is the engine's real contact/intake event and owns
  -- the matching native sound. If it arrives before the cosmetic 0.72s arc
  -- ends, finish the arc immediately instead of flying open; if it arrives
  -- later, hold the closed ball at contact rather than starting the visual
  -- intake ahead of the audio.
  if n.t < throwT and not n.captureOpened then
    local q = n.t / throwT
    local s = q*q*(3-2*q)
    n.ball.pos[1] = startX + (e[1]-startX) * s
    n.ball.pos[3] = startZ + (e[2]-startZ) * s
    n.ball.pos[2] = startY + ((groundY + R + 6.5)-startY) * s
                    + math.sin(math.pi*q) * 10
    n.ball.yaw = math.atan2((Voxel3D.eye and Voxel3D.eye[1] or 0)-n.ball.pos[1],
                            (Voxel3D.eye and Voxel3D.eye[3] or 1)-n.ball.pos[3])
    return
  end

  -- The cosmetic throw is complete, but contact is not guessed from this
  -- module's clock anymore. Hold at the target until the engine announces
  -- POOF/HIDEPIC through normalBallAnimEvent().
  if not n.captureOpened then
    n.ball.spin, n.ball.tumble = 0, 0
    n.ball.pos[1], n.ball.pos[3] = e[1], e[2]
    n.ball.pos[2] = groundY + R + 6.5
    n.ball.yaw = math.atan2((Voxel3D.eye and Voxel3D.eye[1] or 0)-n.ball.pos[1],
                            (Voxel3D.eye and Voxel3D.eye[3] or 1)-n.ball.pos[3])
    return
  end

  if n.phase == "capture_open" and n.captureFxT and n.captureFxT > 0 then
    n.ball.pos[1], n.ball.pos[3] = e[1], e[2]
    n.ball.pos[2] = groundY + R + 6.5
    n.ball.yaw = math.atan2((Voxel3D.eye and Voxel3D.eye[1] or 0)-n.ball.pos[1],
                            (Voxel3D.eye and Voxel3D.eye[3] or 1)-n.ball.pos[3])
    return
  end

  -- Rest under the foe after the intake beat.
  -- choreography; later builds will sync opening/beam/breakout to vanilla.
  n.ball.spin, n.ball.tumble = 0, 0
  n.ball.pos[1], n.ball.pos[3] = e[1], e[2]
  n.ball.pos[2] = groundY + R
  n.ball.yaw = math.atan2((Voxel3D.eye and Voxel3D.eye[1] or 0)-n.ball.pos[1],
                          (Voxel3D.eye and Voxel3D.eye[3] or 1)-n.ball.pos[3])

  local after = n.t - throwT
  -- TEST41: SHAKE_ANIM now drives every visible rock above. Retain only a
  -- generous renderer-failure deadline for failed captures; successful
  -- catches wait for BattleState's real locked-ball transition below.
  local endAt = 0.55 + n.shakes*1.05 + 0.35

  -- A successful catch no longer fires its flash/stars on this guessed
  -- deadline. LegendaryPokeballs forwards BattleState's lockedBall edge to
  -- normalBallCaughtEvent(), which is also where the engine confirms the
  -- catch and plays its sound.

  -- TEST19: engine events now own the visible finish. Keep a generous fallback
  -- only so an unusual backend can never strand a failed 3D ball forever.
  if not n.caught and not n.escapeEvent and after >= endAt + 1.60 then
    n.escapeEvent = true
    n.finished = true
    n.phase = "escape"
    n.ball:burst()
  end

  -- TEST4 lifecycle:
  -- A successful catch must not disappear on a guessed wall-clock timer.
  -- Keep it alive until BattleScene reset/new throw explicitly clears it.
  -- Failed throws can still self-clean shortly after breakout.
  if not n.caught and n.escapeEvent then
    local life = endAt + 2.40
    if after > life then normalBall = nil end
  end
end

local function normalBallSig()
  return normalBall and normalBall.ball and normalBall.ball:signature() or ""
end

-- The GB frame the battle screen is drawn in, and the frame BattleCam's rig
-- is solved against.
BattleScene.GB_W = 160
BattleScene.GB_H = 144

-- A map cell in world pixels: the overworld square a mon stands on, which is
-- both what the arena is measured in and what a mon is sized to.
BattleScene.CELL = 16

-- How far into black a shadow goes in the arena, against the free-roam
-- mode's own lighter setting.
--
-- Darker on purpose, and only here. Walking around, a shadow is scenery and
-- wants to stay out of the way of reading the map. In a battle it is doing
-- one specific job: the two mons are flat cards, and the ONLY thing telling
-- the eye they are standing on that floor rather than hanging in front of it
-- is the shadow they put on it. A faint one leaves them floating.
BattleScene.SHADOW_ALPHA = 0.68

-- Which rung of the sky ramp an indoor void is painted with. A room has no
-- sky, but it does have somewhere the geometry stops, and leaving that
-- transparent would show the letterbox clear through the gaps.
local INDOOR_SHADE = 4

-- ------- where the GB frame sits inside the window
--
-- Renderer blits worldOverride one canvas pixel to one screen pixel and then
-- blits the 160x144 UI canvas into a centred, integer-scaled letterbox. So
-- these have to agree with Renderer:endFrame exactly, or the pins land off
-- the mons by however much they disagree.
function BattleScene.letterbox()
  local Renderer = require("src.render.Renderer")
  local pw, ph = BattleScene.pixelSize()
  local s = Renderer:fitScale()
  return math.floor((pw - BattleScene.GB_W * s) / 2),
         math.floor((ph - BattleScene.GB_H * s) / 2),
         s, pw, ph
end

-- The window in FRAMEBUFFER pixels, which is what the override blit works
-- in. love.graphics.getDimensions is in LOVE units and differs from this by
-- the display density on mobile.
function BattleScene.pixelSize()
  if love.graphics.getPixelDimensions then
    local pw, ph = love.graphics.getPixelDimensions()
    if pw and ph and pw > 0 and ph > 0 then return pw, ph end
  end
  return love.graphics.getDimensions()
end

-- Widen the rig's vertical field of view from the GB frame to the whole
-- window, so the letterbox rows show exactly what the rig framed.
--
-- The horizontal falls out of it: at aspect pw/ph the window's half-width is
-- tan(fov/2) * pw/ph, and the letterbox is 160*s of those pw pixels, which
-- works back out to the GB frame's own 160/144. So one scale on the vertical
-- pins both axes.
function BattleScene.letterboxFov(fovGB, ph, s)
  local span = BattleScene.GB_H * s
  if span <= 0 then return fovGB end
  return 2 * math.atan(math.tan(fovGB / 2) * ph / span)
end

-- ------- palette
--
-- The world palette a map draws under, in the shape VoxelScene's colour
-- helpers take. Rebuilt per frame from the overworld state, which is where
-- the engine's own pipeline context gets it too (OverworldController's
-- ctx.paletteFor).
local function paletteFor(state, home)
  return function(map)
    return PaletteFX.pal(require("src.core.Game").data,
                         state:paletteNameFor(map or home))
  end
end

-- ------- the map the fight is staged on
--
-- Normally the one the player is standing on. An authored arena may name
-- another floor of the same cave or building (see BattleArena), and then the
-- scene is THAT map: its terrain, its palette, its sky. Nothing else in the
-- battle changes -- the fight, the party, the player's own position are all
-- exactly where they were.
--
-- A foreign floor is meshed alone, with no connected neighbours: connections
-- are the player's neighbourhood, and the map the camera has gone to visit is
-- not standing in it. Both maps are kept live so neither the arena's mesh nor
-- the one waiting to be walked back onto is evicted mid-battle.
local function prefetchArena(state, host)
  if host == state.map then
    local terrain, neighbors, water, neighborWater, _, visuals,
      neighborVisuals = VoxelScene.prefetch(state)
    return terrain, neighbors, water, neighborWater, visuals, neighborVisuals
  end
  local live = { [host.id] = true, [state.map.id] = true }
  for _, nb in ipairs(state.neighbors or {}) do live[nb.map.id] = true end
  ChunkMesher.setLive(live)
  TerrainAtlas.setLive(live)
  ChunkMesher.request(host, false, nil, true)
  local terrain, water, _, visuals = ChunkMesher.pair(host, false)
  if not terrain then
    terrain, water, _, visuals = ChunkMesher.pair(host, true)
  end
  return terrain, {}, water, {}, visuals, {}
end

-- ------- the sun
--
-- Only has to be drawn once per battle: the arena does not move, and neither
-- does the light. So the signature is the map, the arena and the meshes --
-- not the camera, which is the one thing that IS moving and the one thing
-- the sun does not care about.
-- ------- the two mons, hung on their cells
--
-- The billboard texture is the battle screen's own 160x144 pics layer with
-- one side rendered into it (see OverworldBattle.sideTexture), so the quad is
-- that whole frame stood up on the map -- which is what carries every pic
-- effect the engine applies without any of them being reimplemented here.
--
-- Its size follows from one number: a full 7x7-tile mon covers one overworld
-- square, so a canvas pixel is FULL_W / FULL_PIC world pixels and the card is
-- the canvas at that scale. Its placement follows from the anchor the
-- texture reports -- the column the pic was centred on and the row its feet
-- were put on -- which is translated onto the cell before the card is stood
-- up, so a mon of any size in any pose has its feet on the ground.
-- `mirror` flips the card about its own anchor column. Both mons wear their
-- FRONT pic, which is drawn facing out of the screen -- so dropped into the
-- world unaltered the pair stand back to back, both looking the same way past
-- each other. Mirroring the near one turns it to face the far one, which is
-- what a fight looks like; and because it is a flip about the pic's own
-- centre the feet do not move off the tile.
--
-- The player's TRAINER pic is the exception, and it is exempted below. That
-- one is a BACK view -- the player seen from behind, already turned to face
-- up the field -- so it arrives pointing the right way and mirroring it would
-- turn it around to face the camera it is standing in front of.
local function monMatrix(tex, x, groundY, z, mirror)
  local k = BattleBillboard.FULL_W / BattleBillboard.FULL_PIC
  local tw, th = tex.canvas:getWidth(), tex.canvas:getHeight()
  local w, h = tw * k, th * k
  -- `k` is fractional (FULL_W/FULL_PIC = 16/56), so a non-zero (tw/2 - ax)
  -- or (th - ay) leaves the card hanging off the world grid by a decimal.
  -- The nearest-filtered billboard upscale then doubles or drops the edge
  -- texel in each axis -- the "one row/column smudged" on ROM/gen1 fronts and
  -- gen2 backs. Snap the anchor off its decimal so the card sits on the grid.
  local ox = math.floor((tw / 2 - tex.ax) * k + 0.5)
  local oy = math.floor(-(th - tex.ay) * k + 0.5)
  local yaw = BattleBillboard.yawToward(x, z, Voxel3D.eye)
  local card = Mat4.mul(Mat4.translate(ox, oy, 0), Mat4.scale(w, h, 1))
  if mirror then card = Mat4.mul(Mat4.scale(-1, 1, 1), card) end
  local presentationScale = tonumber(tex.presentationScale) or 1
  if presentationScale ~= 1 then
    -- Scale about the reported foot anchor. This is deliberately metadata on
    -- trainer cards, not a texture resize and not a Pokemon-wide multiplier.
    card = Mat4.mul(Mat4.scale(presentationScale, presentationScale, 1), card)
  end
  return Mat4.mul(Mat4.mul(Mat4.translate(x, groundY, z), Mat4.rotateY(yaw)),
                  card)
end

-- Every mon that has something to show this frame, as (texture, matrix).
local function monCards(arena, groundY, textures)
  local out = {}
  if not textures then return out end
  for _, side in ipairs({ "enemy", "player" }) do
    local tex = textures[side]
    local cell = (side == "player") and arena.player or arena.enemy
    if tex and tex.suppressCard then tex = nil end
    if side == "enemy" and normalBall and normalBall.hideEnemyForCapture then
      tex = nil
    end
    if tex and tex.canvas and cell then
      local mirror = (side == "player") and not tex.trainer
                     and not tex.noMirror
      local model = monMatrix(tex, cell[1], groundY, cell[2], mirror)
      -- Shrink the opponent about its chest and pull it into the actual 3D
      -- ball mouth during the intake window. This affects only the rendered
      -- card; the battle's authoritative Pokemon object is untouched.
      if side == "enemy" and normalBall and normalBall.captureOpened
          and not normalBall.captureClosed
          and normalBall.captureFxT and normalBall.captureFxT > 0
          and normalBall.ball then
        local duration = math.max(0.001, PokeballSettings.captureDuration())
        local raw = 1 - math.max(0, math.min(1,
          normalBall.captureFxT / duration))
        local q = raw * raw * (3 - 2 * raw)
        local k = math.max(0.06, 1 - 0.94 * q)
        local ax, ay, az = cell[1], groundY + 8, cell[2]
        local bx = normalBall.ball.pos[1]
        local by = normalBall.ball.pos[2]
          + (Pokeball.R or 2.2) * 0.18 * (normalBall.ball.scale or 1)
        local bz = normalBall.ball.pos[3]
        local pullQ = q * q
        local shrink = Mat4.mul(Mat4.translate(ax, ay, az),
          Mat4.mul(Mat4.scale(k, k, k), Mat4.translate(-ax, -ay, -az)))
        model = Mat4.mul(Mat4.translate((bx - ax) * pullQ,
                                       (by - ay) * pullQ,
                                       (bz - az) * pullQ),
                         Mat4.mul(shrink, model))
      end
      out[#out + 1] = { tex = tex.canvas,
                        side = side,
                        noDayTint = tex.noDayTint,
                        model = model }
    end
  end
  return out
end

BattleScene.monCards = monCards

-- The sun has to see the mons too, or they stand on the ground without
-- putting anything on it. They are the one thing in this scene that MOVES,
-- so `token` -- a counter the caller bumps whenever a pic could have changed
-- -- goes in the signature; the terrain half of the answer would otherwise
-- keep a stale pass alive and freeze the shadows in whatever pose they were
-- first drawn in.
local function shadowSignature(state, arena, terrain, nbMesh, visuals,
                               nbVisuals, token, neighborCount)
  local host = arena.map or state.map
  local parts = { "battle", host.id, arena.x, arena.y, arena.shape,
                  tostring(terrain), tostring(token or 0),
                  -- UNLIT removes the cards from the caster pass. Carry that
                  -- decision so switching SPRITE LIGHT or ARENA FILL cannot
                  -- reuse a map that still contains their old silhouettes.
                  tostring(UiBackplates.spritesUnlit()),
                  -- the cycle keeps running through a fight, and an arena lit
                  -- from somewhere new must be re-cast from there
                  math.floor(ShadowMap.KX * 128),
                  math.floor(ShadowMap.KZ * 128) }
  if normalBall and normalBall.ball then
    parts[#parts + 1] = "legendaryBall:" .. normalBallSig()
  end
  for _, visual in ipairs(visuals or {}) do
    parts[#parts + 1] = tostring(visual.mesh)
  end
  for i = 1, neighborCount or #nbMesh do
    parts[#parts + 1] = tostring(nbMesh[i])
    for _, visual in ipairs((nbVisuals and nbVisuals[i]) or {}) do
      parts[#parts + 1] = tostring(visual.mesh)
    end
  end
  return table.concat(parts, ",")
end

local function castShadows(state, arena, terrain, nbMesh, cx, cy, vw, vh,
                           atlasFor, cards, models, token, host, neighbors,
                           water, nbWater, visuals, nbVisuals)
  if not ShadowMap.available() then return end
  local sig = shadowSignature(state, arena, terrain, nbMesh, visuals,
                              nbVisuals, token, #neighbors)
  sig = sig .. "|community-tree:"
    .. CommunityFlora.shadowSignature(state, arena.mid[1], arena.mid[2])
  if not ShadowMap.stale(sig) then return end
  if not ShadowMap.begin(cx, cy, vw, vh) then return end

  ShadowMap.draw(terrain, atlasFor(host), nil)
  for i, nb in ipairs(neighbors) do
    ShadowMap.draw(nbMesh[i], atlasFor(nb.map), Mat4.translate(nb.ox, 0, nb.oy))
  end
  -- Visual-object claims belong only to the overworld companion pass. A
  -- companion has no staged-battle renderer, so every original sign sidecar
  -- remains both a caster here and visible in the color pass below.
  for _, visual in ipairs(visuals or {}) do
    ShadowMap.draw(visual.mesh, atlasFor(host), nil)
  end
  for i, nb in ipairs(neighbors) do
    for _, visual in ipairs((nbVisuals and nbVisuals[i]) or {}) do
      ShadowMap.draw(visual.mesh, atlasFor(nb.map),
                     Mat4.translate(nb.ox, 0, nb.oy))
    end
  end
  -- the water surface is its own reflective pass now (see Water) and so is
  -- no longer inside the terrain mesh; the sun still has to see it, or the
  -- light's map has a hole at every lake
  ShadowMap.draw(water, atlasFor(host), nil)
  for i, nb in ipairs(neighbors) do
    ShadowMap.draw(nbWater and nbWater[i], atlasFor(nb.map),
                   Mat4.translate(nb.ox, 0, nb.oy))
  end
  -- thin cards are snugged toward the sun (ShadowMap.snug) so their shadows
  -- keep contact with their bases instead of starting a bias-width away
  ShadowMap.draw(ChunkMesher.flowers(host), atlasFor(host),
                 ShadowMap.snug(nil))
  for _, nb in ipairs(neighbors) do
    ShadowMap.draw(ChunkMesher.flowers(nb.map), atlasFor(nb.map),
                   ShadowMap.snug(Mat4.translate(nb.ox, 0, nb.oy)))
  end
  pcall(CommunityFlora.castShadows, state, ShadowMap, Mat4,
        arena.mid[1], arena.mid[2])

  -- the mons themselves, as the same cards the camera will see. Their alpha
  -- is the silhouette, so what lands on the ground is the shape of the
  -- Pokemon rather than a blob standing in for one.
  -- marked as the CAST, so a fight staged at the water's edge does not lay a
  -- cut-out of a Pokemon across the lake (see ShadowMap.sprites); the arena's
  -- own floor still takes them, which is the shadow that matters here
  --
  -- UNLIT cards are absent from this pass as well as bypassing it when they
  -- are drawn below. That makes the contract symmetric: they neither receive
  -- somebody else's shadow nor cast/self-cast one of their own, independent
  -- of the selected arena fill.

  -- Model casters are independent of sprite lighting. Route every model
  -- through the adapter exactly once: it converts the depth matrix to the
  -- provider's clip convention and reports failures for the card fallback.
  ShadowMap.sprites(true)
  local modelShadows = {}
  for side, placement in pairs(models or {}) do
    modelShadows[side] = StadiumModels.drawShadow(placement, ShadowMap.clipVP)
  end

  if not UiBackplates.spritesUnlit() then
    for _, card in ipairs(cards or {}) do
      -- Model/shadow failure is local to one side; its retained card casts
      -- for this pass rather than leaving that battler without a silhouette.
      if not modelShadows[card.side] then
        ShadowMap.draw(BattleBillboard.mesh(), card.tex,
                       ShadowMap.snug(card.model))
      end
    end
  end
  ShadowMap.sprites(false)

  if normalBall and normalBall.ball then
    pcall(normalBall.ball.cast, normalBall.ball, ShadowMap)
  end

  ShadowMap.finish(sig)
end

-- The height of the arena floor: the ground the two mons stand on. Both
-- cells are open, so they are normally the same; take the player's, which is
-- the one nearer the camera and therefore the one a mismatch would show up
-- against.
function BattleScene.groundY(map, arena)
  local ok, h = pcall(VoxelScene.groundAt, map,
                      arena.playerCell[1], arena.playerCell[2])
  return (ok and h) or 0
end

-- Where a world point lands in GB frame coordinates under `vp`, or nil when
-- it is behind the camera. This is the function the pins are built on: it
-- takes the window-resolution clip position and divides the letterbox back
-- out of it, so the answer is in the same 160x144 space the battle screen
-- draws its pics in.
function BattleScene.toGB(vp, wx, wy, wz, lx, ly, s, pw, ph)
  local cx = vp[1] * wx + vp[2] * wy + vp[3] * wz + vp[4]
  local cy = vp[5] * wx + vp[6] * wy + vp[7] * wz + vp[8]
  local cw = vp[13] * wx + vp[14] * wy + vp[15] * wz + vp[16]
  if cw <= 1e-6 then return nil end
  -- viewProjection already flipped clip Y into LOVE's Y-down convention
  local px = (cx / cw * 0.5 + 0.5) * pw
  local py = (cy / cw * 0.5 + 0.5) * ph
  return (px - lx) / s, (py - ly) / s
end

-- Render the arena and hand back { canvas, player = {x,y}, enemy = {x,y} },
-- the two marks in GB coordinates -- or nil when there is nothing to draw
-- yet (the terrain mesh is still building, the driver has no depth support).
-- nil is not a failure: the caller simply leaves the battle screen as the
-- engine drew it for that frame.
-- White, for the hit flash, and how far toward it the card goes.
--
-- The shader replaces the card's colour rather than multiplying it, so at
-- full strength this is the sprite turned into a solid white silhouette --
-- which is what the effect is on a flat GB screen and far too much on a
-- sprite standing in a lit world. Held well short of 1, the mon's own
-- shading still reads through the flash: it looks struck rather than
-- deleted.
BattleScene.FLASH_COLOR = { 1, 1, 1 }
BattleScene.FLASH_STRENGTH = 0.5

-- ------- the tile clock, while the overworld is not the one drawing
--
-- Water and flowers animate off TileRenderer's 60Hz counter, and the ENGINE
-- only advances it from OverworldState:drawWorld -- which runs under dialogs
-- and menus, but not under a battle, because a battle draws instead of the
-- overworld rather than over it. So for the length of a staged fight the
-- counter stood still: the water tiles stopped rotating their pixels and the
-- wave field, which is driven off the same number so the two cannot drift
-- (see Water), stopped with them. A lake in the background of a battle was a
-- photograph.
--
-- Ticked HERE rather than from the mod's update hook, because here is the
-- one place that means "a staged battle is drawing this frame, and the
-- overworld is not". From the update hook the condition would have to be
-- guessed at, and a frame where both ran would double the rate.
local function tickTiles()
  local Game = require("src.core.Game")
  local ow = Game and Game.overworld
  local top = Game and Game.stack and Game.stack:top()
  -- during the wipe INTO a battle the overworld can still be the one
  -- drawing, and it is ticking the clock itself; two ticks in a frame would
  -- run the water at double speed
  if top and ow and top == ow then return end
  pcall(require("src.render.TileRenderer").tick)
end

function BattleScene.render(state, arena, textures, token, battle, drawActors,
                            externalCamera, externalModelShadow)
  if not (state and state.map and arena) then return nil end
  if not Voxel3D.available() then return nil end
  tickTiles()

  -- the floor the fight is staged on: normally the player's own, sometimes
  -- another floor of the same cave or building (see BattleArena)
  local host = arena.map or state.map
  local neighbors = (host == state.map) and (state.neighbors or {}) or {}
  local whiteFill = UiBackplates.arenaWhite()
  local gen6Fill = UiBackplates.arenaGen6()
  local pngFill = UiBackplates.arenaPng()
  local gen6Image = gen6Fill and Gen6Backdrop.image(state.map, battle) or nil
  local pngImage = pngFill and Images.load("bosses", "arena.png") or nil
  -- Boss art is an encounter override, not an ARENA FILL collection.  It may
  -- therefore sit above GEN6 now and GEN4/OPENART later, while OFF/WHITE keep
  -- their established meanings. Use the actual battle map for identity even
  -- when BattleArena stages the camera on an adjacent host floor.
  local bossImage = UiBackplates.arenaArt()
                    and UiBackplates.bossEnabled()
                    and BossBackdrop.image(state.map, battle) or nil
  local artImage = bossImage or pngImage or gen6Image
  -- A missing/corrupt optional plate fails open to the ordinary voxel arena,
  -- never to an opaque black battle.
  local flatFill = whiteFill or artImage ~= nil

  -- the hour's light reaches the arena exactly as it reaches free-roam: the
  -- shared rig follows the clock on an outdoor floor and stays at noon on an
  -- indoor one, and the same tint multiplies the staged shot -- with the
  -- same window glass on whatever buildings stand in the background
  local outdoor = host.def and Map.isOutdoor(host.def) or false
  DayNight.applyRig(outdoor)
  -- a canopy floor (Viridian Forest) fights under the hour's tint too,
  -- with the rig and the void exactly as they were
  Voxel3D.tint = DayNight.tint(outdoor or DayNight.isCanopy(host))
  local GlassMask = V.require("GlassMask")
  Voxel3D.glassMask = outdoor and GlassMask.texture(host.tileset) or nil
  Voxel3D.glassNight = outdoor and DayNight.windowLight() or 0
  -- no glint in the arena: the drift is the shot breathing, not the player
  -- moving, and a shimmer on background windows would fight the mons
  Voxel3D.glassGlint = 0

  -- A flat plate does not wait for or touch voxel meshes. The world arena
  -- still shares free-roam's request/evict bookkeeping and warms nothing
  -- extra; illustrated plates can therefore enter immediately on a cold map.
  local terrain, nbMesh, water, nbWater, visuals, nbVisuals
  if not flatFill then
    terrain, nbMesh, water, nbWater, visuals, nbVisuals =
      prefetchArena(state, host)
    if not terrain then return nil end
  end

  local lx, ly, s, pw, ph = BattleScene.letterbox()
  if not (pw > 0 and ph > 0 and s > 0) then return nil end

  local palette = paletteFor(state, host)
  local function atlasFor(map)
    return TerrainAtlas.forMap(map, VoxelScene._modeColors(palette, map))
  end

  local groundY = BattleScene.groundY(host, arena)
  normalBallTick(arena, groundY)
  local cam, pitch
  local externalEye = externalCamera and externalCamera.eye
  local externalFocus = externalCamera and externalCamera.focus
  local externalProjection = externalCamera and externalCamera.projection
  local externalF = type(externalProjection) == "table"
    and tonumber(externalProjection[6]) or nil
  if type(externalEye) == "table" and type(externalFocus) == "table"
      and externalF and math.abs(externalF) > 1e-6 then
    -- Stadium's actor slots are (0,0,+24) and (0,0,-24). BattleArena uses
    -- the same 48-unit separation, translated to the selected map patch, so
    -- translating Stadium's live camera by the arena midpoint and ground
    -- height makes its models and this terrain share one projection exactly.
    cam = {
      eye = { externalEye[1] + arena.mid[1],
              externalEye[2] + groundY,
              externalEye[3] + arena.mid[2] },
      focus = { externalFocus[1] + arena.mid[1],
                externalFocus[2] + groundY,
                externalFocus[3] + arena.mid[2] },
      fov = 2 * math.atan(1 / math.abs(externalF)),
      curve = 0,
    }
    local dx = cam.eye[1] - cam.focus[1]
    local dy = cam.eye[2] - cam.focus[2]
    local dz = cam.eye[3] - cam.focus[3]
    pitch = math.atan2(math.sqrt(dx * dx + dz * dz),
                       math.max(1e-3, dy))
  else
    cam, pitch = BattleCam.rig(arena, groundY)
    cam.fov = BattleScene.letterboxFov(cam.fov, ph, s)
  end

  local cx, cy = arena.mid[1], arena.mid[2]
  -- the world extents the sun frustum is fitted to; the camera itself is
  -- framed by cam.fov, so these only have to describe the ground in shot
  local vh = BattleCam.frameH(arena) * ph / (BattleScene.GB_H * s)
  local vw = vh * pw / ph

  -- the cards need the camera's eye to face it, so the rig has to be live
  -- before they are built; Voxel3D.eye is set by viewProjection, which
  -- beginScene calls -- so a provisional one is taken here for the sun pass
  -- and the real one is rebuilt inside the scene below.
  Voxel3D.camera = cam
  Voxel3D.viewProjection(cx, cy, vw, vh)
  -- A Battle Presentation host supplies its independently selected actor
  -- renderer here. In that mode native cards ordinarily stay out of both the
  -- shadow map and colour pass. A sprite-only provider can opt selected sides
  -- back in through drawActors.cards; providerRender has already filtered the
  -- texture table to those sides, so there is no duplicate host battler.
  local hostedActors = drawActors and true or false
  local drawActorPass = type(drawActors) == "table" and drawActors.draw
    or (type(drawActors) == "function" and drawActors or nil)
  local hostedCards = type(drawActors) == "table"
                      and type(drawActors.cards) == "table"
  local cards = (not hostedActors or hostedCards)
                and monCards(arena, groundY, textures) or {}
  local stadium = hostedActors and {}
    or StadiumModels.placements(arena, groundY, textures, battle)
  Voxel3D.camera = nil
  if flatFill then
    -- WHITE is a genuinely flat stage: there is no visible world receiver,
    -- and its cards must neither cast nor receive. Do not merely omit the
    -- cards from a newly built map; discard any map left by the preceding
    -- overworld/battle too, so beginScene binds the blank sampler.
    ShadowMap.discard()
  else
    castShadows(state, arena, terrain, nbMesh, cx, cy, vw, vh, atlasFor,
                cards, stadium, token, host, neighbors, water, nbWater,
                visuals, nbVisuals)
  end

  -- An opaque void either way. Outdoors the camera is low enough that the
  -- horizon is genuinely in frame, so it is sky; indoors it is the dark end
  -- of the same ramp, which is a room's "past the wall". Transparent -- the
  -- free-roam default -- would let the letterbox clear through wherever the
  -- geometry stops.
  local sky = VoxelScene.skyColor(host, 1)
             or VoxelScene.skyShade(INDOOR_SHADE, 1)

  Voxel3D.camera = cam
  -- the sun is turned up for the arena and put back afterwards, so the
  -- free-roam world it shares this module with keeps its own weight -- and
  -- the hour still has the last word: a sunset fades the arena's shadows
  -- out and the moon presses more softly, exactly as it does outside
  local sunWas = Voxel3D.SHADOW_ALPHA
  Voxel3D.SHADOW_ALPHA = BattleScene.SHADOW_ALPHA
                         * DayNight.shadowScale(outdoor)
  -- The same V-GRID row owns the wireframe here and in free roam. OFF means
  -- no seams anywhere; ON keeps the constructed look on both the overworld
  -- and this staged battle shot. Reading the setting through Voxel3D leaves
  -- the player's choice untouched.
  local out = nil
  local ok, err = pcall(function()
    -- its own canvas slot: this renders at the window's pixel size and the
    -- free-roam pass does too, but the two are alive at different moments
    -- and a shared slot would reallocate on every battle entry and exit
    --
    -- AA, if the row asks for it, renders it larger still and folds it back
    -- to pw x ph below (see AntiAlias). The framing is untouched by that:
    -- the lens was widened by the window's RATIO to the letterbox and the
    -- rig solved in the GB's own frame, so a bigger canvas is more samples
    -- of the identical shot -- which is why the pins below still measure in
    -- pw and ph, and why the HUDs and the depth of field, drawn onto the
    -- folded canvas afterwards, stay the chunky GB art they are.
    local rw, rh = AntiAlias.expand(pw, ph)
    -- ARENA FILL: WHITE covers the whole voxel world with a solid field and
    -- keeps only the mons (drawn below) above it -- the step between the OG
    -- battle and the full 3D one. Implemented by clearing the scene to white
    -- and skipping the terrain/water/grass/flower draws; the 2D attack
    -- animations and the menus composite on top afterwards, so they stay
    -- above the white too. Requires sprite light UNLIT (see UiBackplates).
    local skyFill = whiteFill and { 1, 1, 1 }
                    or (artImage and { 0, 0, 0 } or sky)
    local modelShadow = type(externalModelShadow) == "table"
        and externalModelShadow.map and externalModelShadow.sunVP and {
          map = externalModelShadow.map,
          sunVP = externalModelShadow.sunVP,
          sunDark = externalModelShadow.sunDark,
          sunBias = externalModelShadow.sunBias,
          sunTexel = externalModelShadow.sunTexel,
          origin = { arena.mid[1], groundY, arena.mid[2] },
        } or nil
    if not Voxel3D.beginScene(rw, rh, cx, cy, vw, vh, skyFill, "battle",
        modelShadow) then
      return
    end
    if artImage then
      Voxel3D.backdrop(artImage, UiBackplates.backdropOffsetPixels())
    end
    if not flatFill then
    Voxel3D.draw(terrain, atlasFor(host), nil)
    for i, nb in ipairs(neighbors) do
      Voxel3D.draw(nbMesh[i], atlasFor(nb.map),
                   Mat4.translate(nb.ox, 0, nb.oy))
    end
    for _, visual in ipairs(visuals or {}) do
      Voxel3D.draw(visual.mesh, atlasFor(host), nil)
    end
    for i, nb in ipairs(neighbors) do
      for _, visual in ipairs((nbVisuals and nbVisuals[i]) or {}) do
        Voxel3D.draw(visual.mesh, atlasFor(nb.map),
                     Mat4.translate(nb.ox, 0, nb.oy))
      end
    end
    -- and the water over it -- PLAIN, always: the flat animated tiles, never
    -- the reflective pass, whatever the WATER row says. The reflection is
    -- tuned for the overworld's ladder of cameras; this shot's is PLACED --
    -- low, tilted and framed like a picture -- and under it the pass reads
    -- wrong: Fresnel opens all the way up, the leaned sky lands on bands the
    -- framing never shows, and a lake-sized arena comes out as murk wearing
    -- the tile art. The battle is a stage set, and stage water is painted.
    -- (No mirror also means the mons need no second draw into one -- they
    -- just composite over the water below, like everything else on the set.)
    if water then Voxel3D.draw(water, atlasFor(host)) end
    for i, nb in ipairs(neighbors) do
      if nbWater and nbWater[i] then
        Voxel3D.draw(nbWater[i], atlasFor(nb.map),
                     Mat4.translate(nb.ox, 0, nb.oy))
      end
    end
    Voxel3D.glass(false)
    pcall(CommunityFlora.battleProps, host, neighbors, arena)
    Voxel3D.glass(true)
    end
    -- The mons, standing on their tiles. Depth-tested like everything else,
    -- so a ledge or a tree between the camera and a Pokemon really is in
    -- front of it, and the alpha discard cuts the sprite's own outline out of
    -- the card. A small camera-ward pull keeps a card rooted to the ground
    -- plane from z-fighting the tile it is standing on.
    -- The engine's hit flash is a full-screen white rectangle, which on a
    -- white battle field is a flash and over a world is a whiteout of the
    -- map, the HUD and the text box alike. It is dropped on the way past
    -- (see OverworldBattle) and put back HERE, on the two things it was ever
    -- about: the mons themselves go solid white for those frames.
    local flashing = textures and textures.flash
    if flashing then
      Voxel3D.flatten(BattleScene.FLASH_COLOR, BattleScene.FLASH_STRENGTH)
    end
    -- and no voxel wireframe on the pair. Everything else in this frame is
    -- built a unit per voxel and wears the seams that fall out of that; a
    -- mon's card is one quad wearing the battle screen (see
    -- BattleBillboard), so it is off the grid and has no seams to draw.
    Voxel3D.seams(false)
    -- and no glass either: the cards wear the battle screen, not the
    -- tileset atlas, so the mask's coordinates mean nothing on them
    Voxel3D.glass(false)
    local function drawCard(card)
      -- Static front illustrations retain their authored brightness instead
      -- of being dimmed or colour-cast by the clock. Only the hour tint is
      -- neutral here; depth and alpha-shaped lighting/shadows stay active.
      if card.noDayTint then Voxel3D.dayTint({ 1, 1, 1 }) end
      -- SPRITE LIGHT: UNLIT draws the card flat and full bright -- no cast
      -- shadow (nil snug) AND no hour/day tint, so a cave or night tint does
      -- not dim it. Most visible on the white arena fill, where a darkened
      -- card would read wrong; but it is flat/full-bright everywhere. SHADED
      -- (the default) keeps the tints and its own shadow, as intended.
      local unlit = UiBackplates.spritesUnlit()
      local savedTint = Voxel3D.tint
      if unlit then
        Voxel3D.tint = { 1, 1, 1 }
        Voxel3D.dayTint({ 1, 1, 1 })
        -- dayTint alone is not enough: the shared scene shader also samples
        -- the sun map. The old ternary-like `unlit and nil or snug` expression
        -- selected snug even when unlit (nil falls through `or`), so the card
        -- still received scene shadows and could darken on a white arena.
        -- Bypass the complete equation and restore it immediately afterward.
        Voxel3D.lighting(false)
      end
      local sunModel = not unlit and ShadowMap.snug(card.model) or nil
      Voxel3D.draw(BattleBillboard.mesh(), card.tex, card.model,
                   BattleBillboard.PULL, sunModel)
      if unlit then
        Voxel3D.lighting(true)
        Voxel3D.tint = savedTint
        Voxel3D.dayTint()
      end
      if card.noDayTint then Voxel3D.dayTint() end
    end

    -- Trainers, disabled integration and unavailable sides retain the exact
    -- established card path. Each available model replaces only its own side.
    for _, card in ipairs(cards) do
      if not StadiumModels.uses(stadium, card.side) then drawCard(card) end
    end

    local failedModels = {}
    local shadowActive = ShadowMap.active()
    local drawContext = {
      viewProjection = Voxel3D.vp,
      view = Mat4.lookAt(Voxel3D.eye, Voxel3D.focus,
        (cam and cam.up) or { 0, 1, 0 }),
      tint = Voxel3D.tint,
      light = {
        direction = { 0.35, 0.7, 0.62 },
        ambient = { 0.46, 0.46, 0.46 },
        diffuse = { 0.72, 0.72, 0.72 },
      },
      flashing = flashing,
      shadowMap = shadowActive and ShadowMap.texture() or nil,
      shadowVP = shadowActive and ShadowMap.uvVP or nil,
      shadowDark = Voxel3D.SHADOW_ALPHA,
      shadowBias = ShadowMap.bias,
      shadowTexel = shadowActive and ShadowMap.res > 0
        and { 1 / ShadowMap.res, 1 / ShadowMap.res } or nil,
    }
    for _, pass in ipairs({ "opaque", "additive" }) do
      for side, placement in pairs(stadium) do
        if not failedModels[side]
            and not StadiumModels.draw(placement, drawContext, pass) then
          failedModels[side] = true
        end
      end
    end
    -- A provider failure cannot strand a missing battler for the frame.
    for _, card in ipairs(cards) do
      if failedModels[card.side] then drawCard(card) end
    end

    -- Legendary standing-trainer bridge. The companion 3D-player mod exports
    -- this callback from the same live voxel renderer, while OverworldBattle
    -- publishes the normal-battle lifetime above. Calling it here keeps the
    -- selected character depth-tested in the arena without changing Pokemon
    -- placement, combat state, the camera, or Legendary Pokeball ownership.
    local providerTrainer = false
    if CharacterRenderers.battleActive() then
      providerTrainer = CharacterRenderers.first("drawBattleTrainer", {
        state = state, battle = battle, arena = arena, groundY = groundY,
        host = { Voxel3D = Voxel3D, Mat4 = Mat4,
                 ShadowMap = ShadowMap },
        setHandWorld = function(value)
          CharacterRenderers.setBattleHand(value)
        end,
      })
    end
    if not providerTrainer
        and rawget(_G, "RED3D_TRAINER_INTRO_ACTIVE") == true then
      local direct = rawget(_G, "RED3D_DIRECT_BATTLE_DRAW")
      if type(direct) == "function" then
        _G.RED3D_BATTLE_ART_DIRECT_CALLS =
          (tonumber(_G.RED3D_BATTLE_ART_DIRECT_CALLS) or 0) + 1
        local okDirect, didDraw = pcall(direct, arena, groundY,
                                         Voxel3D, Mat4)
        _G.RED3D_BATTLE_ART_DIRECT_RESULT = okDirect
          and (didDraw and "DRAW OK" or "NO DRAW") or "CALL ERROR"
      end
    elseif not providerTrainer
        and rawget(_G, "RED3D_DIRECT_BATTLE_STATUS") == "DRAW OK" then
      _G.RED3D_DIRECT_BATTLE_STATUS = "BATTLE DONE"
    end

    -- The Legendary capture prop shares this scene's depth buffer, camera,
    -- lighting and shadows. Its intake beam follows the opponent's moving
    -- chest so there is no flat duplicate ball or detached overlay.
    if normalBall and normalBall.ball then
      pcall(normalBall.ball.draw, normalBall.ball, BattleBillboard.PULL)
      if normalBall.captureFxT and normalBall.captureFxT > 0
          and arena and arena.enemy then
        local duration = math.max(0.001, PokeballSettings.captureDuration())
        local remain = math.max(0, math.min(1,
          normalBall.captureFxT / duration))
        local raw = 1 - remain
        local q = raw * raw * (3 - 2 * raw)
        local ax, ay, az = arena.enemy[1], groundY + 8, arena.enemy[2]
        local bx = normalBall.ball.pos[1]
        local by = normalBall.ball.pos[2]
          + (Pokeball.R or 2.2) * 0.18 * (normalBall.ball.scale or 1)
        local bz = normalBall.ball.pos[3]
        local pullQ = q * q
        pcall(normalBall.ball.drawBeam, normalBall.ball,
          ax + (bx - ax) * pullQ,
          ay + (by - ay) * pullQ,
          az + (bz - az) * pullQ,
          5.20 - 3.10 * q, 1.00 - 0.62 * q,
          BattleBillboard.PULL)
      end
    end
    Voxel3D.glass(true)
    Voxel3D.seams(true)
    if flashing then Voxel3D.flatten(nil) end
    -- grass and flowers ride the same camera-ward pull the free-roam pass
    -- gives them, measured against THIS camera's pitch rather than the
    -- orbit's -- there is no character here for them to overdraw, but the
    -- pull is also what keeps a tuft from z-fighting the floor it stands on
    if not flatFill then
    local pull = VoxelScene.pull(math.max(pitch, 0.05))
    Voxel3D.draw(ChunkMesher.grass(host), atlasFor(host), nil, pull)
    for _, nb in ipairs(neighbors) do
      Voxel3D.draw(ChunkMesher.grass(nb.map), atlasFor(nb.map),
                   Mat4.translate(nb.ox, 0, nb.oy), pull)
    end
    local fpull = math.max(0, pull - 8 * math.sin(math.max(pitch, 0.05)))
    Voxel3D.draw(ChunkMesher.flowers(host), atlasFor(host), nil, fpull,
                 ShadowMap.snug(nil))
    for _, nb in ipairs(neighbors) do
      Voxel3D.draw(ChunkMesher.flowers(nb.map), atlasFor(nb.map),
                   Mat4.translate(nb.ox, 0, nb.oy), fpull,
                   ShadowMap.snug(Mat4.translate(nb.ox, 0, nb.oy)))
    end
    end
    if drawActorPass then
      -- Enter the selected model provider while this arena's depth target and
      -- camera are live. The host owns actor shader/state cleanup. Logical
      -- dimensions describe the resolved surface, so projected attachments
      -- remain correct when this pass is supersampled.
      drawActorPass({
        vp = Voxel3D.vp,
        view = Mat4.lookAt(Voxel3D.eye, Voxel3D.focus, cam.up or { 0, 1, 0 }),
        eye = Voxel3D.eye,
        origin = { arena.mid[1], groundY, arena.mid[2] },
        groundY = groundY,
        width = pw,
        height = ph,
      })
    end
    local canvas = AntiAlias.resolve(Voxel3D.endScene(), pw, ph, "battle")
    if not canvas then return end

    local vp = Voxel3D.vp
    local pmx, pmy = BattleScene.toGB(vp, arena.player[1], groundY,
                                      arena.player[2], lx, ly, s, pw, ph)
    local emx, emy = BattleScene.toGB(vp, arena.enemy[1], groundY,
                                      arena.enemy[2], lx, ly, s, pw, ph)
    if not (pmx and emx) then return end
    -- How wide one overworld square is on screen where each mon stands, in
    -- GB pixels. This is what the pics are scaled to: a mon covers its own
    -- square and no more, at whatever the drift has done to the distance.
    local half = BattleScene.CELL / 2
    local pl = BattleScene.toGB(vp, arena.player[1] - half, groundY,
                                arena.player[2], lx, ly, s, pw, ph)
    local pr = BattleScene.toGB(vp, arena.player[1] + half, groundY,
                                arena.player[2], lx, ly, s, pw, ph)
    local el = BattleScene.toGB(vp, arena.enemy[1] - half, groundY,
                                arena.enemy[2], lx, ly, s, pw, ph)
    local er = BattleScene.toGB(vp, arena.enemy[1] + half, groundY,
                                arena.enemy[2], lx, ly, s, pw, ph)
    if not (pl and pr and el and er) then return end
    out = {
      canvas = canvas,
      trainerDrawn = providerTrainer,
      player = { pmx, pmy },
      enemy = { emx, emy },
      playerSpan = math.abs(pr - pl),
      enemySpan = math.abs(er - el),
      -- the letterbox, so the depth-of-field pass can put its sharp band on
      -- the two marks rather than on a fraction of the window
      lx = lx, ly = ly, scale = s, pw = pw, ph = ph,
      -- and the hour's light, for anything drawn over this shot that is NOT
      -- geometry and so never went past the shader that applied it -- the back
      -- pic pinned to the menu (see OverworldBattle.backPinned). Neutral
      -- indoors, which is what DayNight.tint answers for a room.
      tint = Voxel3D.tint,
    }
  end)
  -- the placed camera is ours for exactly this pass; anything else that
  -- renders (the free-roam pipeline, next frame) must find the orbit back
  Voxel3D.camera = nil
  Voxel3D.SHADOW_ALPHA = sunWas
  if not ok then
    -- endScene never ran, so the canvas is still bound and the shader still
    -- set; put the frame back the way it was found before rethrowing
    pcall(love.graphics.setShader)
    pcall(love.graphics.setDepthMode)
    pcall(love.graphics.setCanvas)
    error(err, 0)
  end
  return out
end

return BattleScene
