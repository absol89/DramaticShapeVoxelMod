-- Battle Art ARENA FILL provider for Stadium 2 Importer's owned battle scene.
-- The importer retains its camera, platforms, opponent and HUD. In LEGENDARY
-- sprite mode this bridge also owns the player battler slot so Battle Art can
-- plant that existing 2D sprite in the arena instead of on the moving UI.

local V = ...

local UiBackplates = V.require("UiBackplates")
local Gen6Backdrop = V.require("Gen6Backdrop")
local BossBackdrop = V.require("BossBackdrop")
local Images = V.require("BackdropImage")
local Mat4 = V.require("Mat4")
local Voxel3D = V.require("Voxel3D")
local OverworldBattle = V.require("OverworldBattle")

local StadiumBackground = {}
local installed = false
local hostedBattle
local providerPlayerReady = false
local catcherMesh
local catcherShader

-- Stadium's ROM-authored field camera is only about ten Battle Art world
-- pixels above its target after the N64 arena scale is applied. That works
-- over Stadium's flat platform, but a CAVERN arena has real maze walls: the
-- approved inner walls are 30px tall, so the same camera begins a fight from
-- inside the masonry and the scene becomes one giant close-up brick.
--
-- TEST40 lifted that live Stadium eye in place. It cleared the wall, but a
-- short or reversed host-camera cut then became a steep overhead view with
-- the player on the enemy side of the frame. TEST44 gives cave battles one
-- stable over-the-shoulder bearing instead. The eye remains above the wall
-- line, is pulled back far enough to keep a moderate pitch, and always looks
-- from the player's south/east side toward the enemy. The hook still runs
-- before Stadium draws models, shadows and Battle Art terrain, so every layer
-- receives the same corrected projection.
StadiumBackground.CAVE_BATTLE_MIN_LIFT = 48
StadiumBackground.CAVE_BATTLE_ELEVATION = math.rad(24)
StadiumBackground.CAVE_BATTLE_BEARING = math.rad(28.5)
StadiumBackground.CAVE_BATTLE_FOV = math.rad(46)
StadiumBackground.CAVE_NARROW_FOV = math.rad(52)

local CATCHER_SHADER = [[
varying vec3 vSun;
#ifdef VERTEX
uniform mat4 mvp;
uniform mat4 sunVP;
vec4 position(mat4 transform_projection, vec4 vertex_position) {
  vSun = (sunVP * vertex_position).xyz;
  return mvp * vertex_position;
}
#endif
#ifdef PIXEL
uniform Image sunMap;
uniform float sunDark;
uniform float sunBias;
uniform vec2 sunTexel;
float depthAt(vec2 uv) {
  vec4 c = Texel(sunMap, uv);
  return c.r + c.g / 255.0;
}
vec4 effect(vec4 color, Image tex, vec2 tc, vec2 sc) {
  if (vSun.x < 0.0 || vSun.x > 1.0 || vSun.y < 0.0 || vSun.y > 1.0
      || vSun.z > 1.0) discard;
  float z = vSun.z - sunBias;
  float lit = step(z, depthAt(vSun.xy + sunTexel * vec2(-1.5, -0.5)))
            + step(z, depthAt(vSun.xy + sunTexel * vec2( 0.5, -1.5)))
            + step(z, depthAt(vSun.xy + sunTexel * vec2( 1.5,  0.5)))
            + step(z, depthAt(vSun.xy + sunTexel * vec2(-0.5,  1.5)));
  float alpha = sunDark * (1.0 - lit * 0.25);
  if (alpha <= 0.005) discard;
  return vec4(0.015, 0.018, 0.025, alpha);
}
#endif
]]

local function shadowCatcherAssets(g)
  if catcherMesh == false or catcherShader == false then return nil end
  if not catcherMesh then
    local format = {
      { "VertexPosition", "float", 3 },
      { "VertexTexCoord", "float", 2 },
    }
    local vertices = {
      { -64, -0.08, -64, 0, 0 }, { 64, -0.08, -64, 1, 0 },
      { 64, -0.08, 64, 1, 1 }, { -64, -0.08, 64, 0, 1 },
    }
    local ok, mesh = pcall(g.newMesh, format, vertices, "fan", "static")
    catcherMesh = ok and mesh or false
  end
  if not catcherShader then
    local ok, shader = pcall(g.newShader, CATCHER_SHADER)
    catcherShader = ok and shader or false
  end
  return catcherMesh and catcherShader and true or nil
end

local function drawShadowCatcher(ctx)
  local g = ctx and ctx.graphics
  local camera = ctx and ctx.camera
  local shadow = ctx and ctx.shadow
  local vp = camera and (camera.vp or camera.viewProjection)
  if not (g and g.newMesh and g.newShader and vp and shadow and shadow.map
      and shadow.sunVP and shadowCatcherAssets(g)) then return false end
  if g.setShader then g.setShader(catcherShader) end
  if g.setMeshCullMode then g.setMeshCullMode("none") end
  if g.setDepthMode then g.setDepthMode("lequal", false) end
  if g.setBlendMode then g.setBlendMode("alpha", "alphamultiply") end
  if g.setColor then g.setColor(1, 1, 1, 1) end
  pcall(catcherShader.send, catcherShader, "mvp", "row", vp)
  pcall(catcherShader.send, catcherShader, "sunVP", "row", shadow.sunVP)
  pcall(catcherShader.send, catcherShader, "sunMap", shadow.map)
  pcall(catcherShader.send, catcherShader, "sunDark",
    tonumber(shadow.sunDark) or 0.55)
  pcall(catcherShader.send, catcherShader, "sunBias",
    tonumber(shadow.sunBias) or 0.003)
  pcall(catcherShader.send, catcherShader, "sunTexel",
    shadow.sunTexel or { 1 / 1024, 1 / 1024 })
  local ok = pcall(g.draw, catcherMesh)
  if g.setShader then g.setShader() end
  if g.setDepthMode then g.setDepthMode() end
  if g.setBlendMode then g.setBlendMode("alpha", "alphamultiply") end
  if g.setColor then g.setColor(1, 1, 1, 1) end
  return ok
end

local function findMod(id)
  local finder = V.mod and V.mod.find
  if type(finder) ~= "function" then return nil end
  local ok, handle = pcall(finder, id)
  if ok and handle then return handle end
  ok, handle = pcall(finder, V.mod, id)
  return ok and handle or nil
end

local function battleMap(ctx)
  local map = OverworldBattle.map and OverworldBattle.map() or nil
  if map then return map end
  local game = ctx and ctx.scene and ctx.scene.game
  return game and game.overworld and game.overworld.map or nil
end

local function copyArray(source)
  local out = {}
  for i = 1, #source do out[i] = source[i] end
  return out
end

local function cavernBattle(ctx)
  if UiBackplates.arenaFill:get() ~= "OFF" then return false end
  local map = battleMap(ctx)
  return map and map.tileset and map.tileset.id == "CAVERN"
end

local function projectionAtFov(projection, fov)
  local out = copyArray(projection)
  local oldY = tonumber(out[6])
  if not oldY or math.abs(oldY) <= 1e-6 then return out end
  local newY = 1 / math.tan(fov / 2)
  local ratio = newY / math.abs(oldY)
  out[1] = (tonumber(out[1]) or 0) * ratio
  out[6] = oldY < 0 and -newY or newY
  return out
end

-- Cave-only stable composition for Stadium/Colosseum-hosted battles.
-- Ordinary Battle Art owns its own BattleCam and never enters this hook;
-- non-cave Stadium scenes immediately return the importer's original frame.
function StadiumBackground.camera(next, ctx)
  local frame = next(ctx)
  if not cavernBattle(ctx) or type(frame) ~= "table" then return frame end

  local eye, focus, projection = frame.eye, frame.focus, frame.projection
  if not (type(eye) == "table" and type(focus) == "table"
      and type(projection) == "table") then return frame end

  local ex, ey, ez = tonumber(eye[1]), tonumber(eye[2]), tonumber(eye[3])
  local fx, fy, fz = tonumber(focus[1]), tonumber(focus[2]), tonumber(focus[3])
  if not (ex and ey and ez and fx and fy and fz) then return frame end

  local arena = OverworldBattle.arena and OverworldBattle.arena() or nil
  local lift = math.max(StadiumBackground.CAVE_BATTLE_MIN_LIFT, ey - fy)
  -- Pull back with the lift instead of simply raising a short Stadium cut.
  -- At 24 degrees the wall-clearing seat still reads as a battle camera, not
  -- as the overhead diorama visible in TEST43.
  local run = lift / math.tan(StadiumBackground.CAVE_BATTLE_ELEVATION)
  local bearing = StadiumBackground.CAVE_BATTLE_BEARING
  local correctedEye = {
    fx + math.sin(bearing) * run,
    fy + lift,
    fz + math.cos(bearing) * run,
  }
  local fov = arena and arena.shape == "narrow"
    and StadiumBackground.CAVE_NARROW_FOV
    or StadiumBackground.CAVE_BATTLE_FOV
  local correctedProjection = projectionAtFov(projection, fov)

  local correctedView = Mat4.lookAt(correctedEye, { fx, fy, fz }, { 0, 1, 0 })
  local correctedVp = Mat4.mul(correctedProjection, correctedView)
  local out = {}
  for key, value in pairs(frame) do out[key] = value end
  out.eye = correctedEye
  out.focus = { fx, fy, fz }
  out.view = correctedView
  out.projection = correctedProjection
  out.vp = correctedVp
  out.viewProjection = correctedVp
  return out
end

local function selectedImage(map, battle)
  local boss = UiBackplates.arenaArt() and UiBackplates.bossEnabled()
    and BossBackdrop.image(map, battle) or nil
  if boss then return boss end
  if UiBackplates.arenaPng() then return Images.load("bosses", "arena.png") end
  if UiBackplates.arenaGen6() then return Gen6Backdrop.image(map, battle) end
  return nil
end

local function drawImage(g, image, width, height)
  if not (g and image and image.getDimensions and width and height) then
    return false
  end
  local ok, iw, ih = pcall(image.getDimensions, image)
  if not ok then return false end
  local x, y, scale = Voxel3D.coverRect(iw, ih, width, height,
    UiBackplates.backdropOffsetPixels())
  if not scale then return false end

  local blur = Voxel3D.backdropShader()
  if g.setShader then g.setShader(blur) end
  if blur then
    pcall(blur.send, blur, "texel", { 1 / iw, 1 / ih })
    pcall(blur.send, blur, "radius", Voxel3D.BACKDROP_BLUR_RADIUS)
  end
  if g.setDepthMode then g.setDepthMode("always", false) end
  if g.setBlendMode then g.setBlendMode("alpha", "alphamultiply") end
  if g.setColor then g.setColor(1, 1, 1, 1) end
  local dx, dy, sx, sy = Voxel3D.backdropTransform(iw, ih, x, y, scale,
    Voxel3D.metalRenderer())
  g.draw(image, dx, dy, 0, sx, sy)
  return true
end

function StadiumBackground.draw(next, ctx)
  local mode = UiBackplates.arenaFill:get()
  if mode == "OFF" or mode == "BLUE" then return next(ctx) end

  local g = ctx and ctx.graphics
  local target = ctx and ctx.target
  if not (g and target) then return next(ctx) end
  if mode == "WHITE" then
    g.clear(1, 1, 1, 1, true, true)
    return true
  end

  local battle = ctx.scene and ctx.scene.battle or OverworldBattle.battle()
  local image = selectedImage(battleMap(ctx), battle)
  if not image then return next(ctx) end
  g.clear(0, 0, 0, 1, true, true)
  if drawImage(g, image, target.width, target.height) then return true end
  return next(ctx)
end

local function releaseVoxelHost()
  providerPlayerReady = false
  if not hostedBattle then return end
  OverworldBattle.providerFinish()
  hostedBattle = nil
end

local function bindTarget(g, target)
  if not (g and g.setCanvas and target and target.color) then return true end
  local binding = target.depth
    and { target.color, depthstencil = target.depth }
    or { target.color, depth = true }
  return pcall(g.setCanvas, binding)
end

local function drawCanvas(g, canvas, target)
  if not (canvas and canvas.getDimensions and g and g.draw) then return false end
  local ok, cw, ch = pcall(canvas.getDimensions, canvas)
  if not ok or not (cw and ch and cw > 0 and ch > 0) then return false end
  if not bindTarget(g, target) then return false end
  if g.setShader then g.setShader() end
  if g.setDepthMode then g.setDepthMode("always", false) end
  if g.setBlendMode then g.setBlendMode("alpha", "alphamultiply") end
  if g.setColor then g.setColor(1, 1, 1, 1) end
  g.draw(canvas, 0, 0, 0, target.width / cw, target.height / ch)
  return true
end

local function drawCircleStage(next, ctx)
  local scale = UiBackplates.stadiumCircleScale()
  if scale <= 0 then return ctx and ctx.marks or next(ctx) end
  if scale >= 1 then return next(ctx) end

  -- Scene API v1 exposes the concrete host. Current Stadium importers publish
  -- their Stage helper on that host; scope the radius override to this one
  -- synchronous fallback call and restore it even if drawing fails.
  local host = ctx and ctx.scene and ctx.scene.host
  local stage = host and host.Stage
  local radius = stage and stage.radius
  if type(radius) ~= "function" then return next(ctx) end
  stage.radius = function(actor) return radius(actor) * scale end
  local ok, a, b = pcall(next, ctx)
  stage.radius = radius
  if not ok then error(a, 0) end
  return a, b
end

local function stadiumActorPasses()
  -- Stadium draws its models after this environment canvas. Their completed
  -- shadow map is supplied separately as the voxel receiver's second sun.
  -- LEGENDARY's player remains the game's existing 2D sprite; opt that one
  -- side into Battle Art's camera-facing arena-card pass while Stadium keeps
  -- ownership of the opposing battler and the UI.
  local passes = { draw = function() return true end }
  if OverworldBattle.legendaryTrainerEnabled() then
    passes.cards = { player = true }
  end
  return passes
end

-- Stadium asks extensions to select battler ownership before drawing the
-- environment, then asks which selected provider sides were actually drawn.
-- Reserve only the player side while the LEGENDARY Battle Art environment is
-- active. environment() plants the 2D player sprite in that world render and
-- marks the provider ready; reporting it here prevents Stadium from reopening
-- the native, menu-attached copy. A failed world render reports false and
-- Stadium safely falls back to its ordinary host/native path.
function StadiumBackground.battlers(next, ctx)
  local legendarySprites = OverworldBattle.legendaryTrainerEnabled()
    and UiBackplates.arenaFill:get() == "OFF"
  if not legendarySprites then return next(ctx) end

  if ctx and ctx.battlerPhase == "prepare" then
    providerPlayerReady = false
    local base = next(ctx)
    local source = type(base) == "table" and (base.sides or base) or {}
    return { sides = {
      enemy = source.enemy or "host",
      player = "provider",
    } }
  end

  if ctx and ctx.battlerPhase == "draw" then
    local base = next(ctx)
    local source = type(base) == "table"
      and (base.drawn or base.sides or base) or {}
    return { drawn = {
      enemy = source.enemy == true,
      player = providerPlayerReady,
    } }
  end

  return next(ctx)
end

-- OFF means the real Battle Art level, not Stadium's generic platforms. The
-- existing BattleStage hosting seam renders terrain without sprite cards; the
-- importer then draws its own models and HUD over that completed environment.
function StadiumBackground.environment(next, ctx)
  local mode = UiBackplates.arenaFill:get()
  if mode ~= "OFF" then
    releaseVoxelHost()
    local result = drawCircleStage(next, ctx)
    -- A flat plate has no geometry to receive the already-completed Stadium
    -- model shadow map. When its visible circle is hidden or reduced, draw
    -- only those shadow texels onto an invisible arena-local ground plane.
    -- The catcher sits just below the real platform and does not write depth,
    -- so HALF keeps the platform's normal shadow inside its edge while the
    -- catcher supplies only the otherwise-clipped continuation beyond it.
    if UiBackplates.stadiumCircleScale() < 1 then drawShadowCatcher(ctx) end
    return result
  end
  local battle = ctx and ctx.scene and ctx.scene.battle
  local g, target = ctx and ctx.graphics, ctx and ctx.target
  if not (battle and g and target) then return drawCircleStage(next, ctx) end
  if hostedBattle ~= battle then
    releaseVoxelHost()
    if not OverworldBattle.providerBegin(battle) then
      return drawCircleStage(next, ctx)
    end
    hostedBattle = battle
  end
  local canvas = OverworldBattle.providerRender(battle,
    stadiumActorPasses(ctx), ctx.camera, ctx.shadow)
  if not drawCanvas(g, canvas, target) then
    releaseVoxelHost()
    return drawCircleStage(next, ctx)
  end
  providerPlayerReady = true
  -- The optional platform is drawn after the opaque voxel canvas, so ON/HALF
  -- stays visible while OFF leaves only the terrain and its model shadows.
  return drawCircleStage(next, ctx)
end

function StadiumBackground.install()
  if installed then return true end
  local handle = findMod("STADIUM2_IMPORTER")
  local scene = handle and handle.exports and handle.exports.scene
  if not (scene and tonumber(scene.VERSION or scene.apiVersion) == 1
      and type(scene.register) == "function") then return false end
  local okBackground = pcall(scene.register, V.mod, "background",
    StadiumBackground.draw, 100)
  local okCamera = pcall(scene.register, V.mod, "camera",
    StadiumBackground.camera, 100)
  local okEnvironment = pcall(scene.register, V.mod, "environment",
    StadiumBackground.environment, 100)
  local okBattlers = pcall(scene.register, V.mod, "battlers",
    StadiumBackground.battlers, 1000)
  installed = okBackground and okCamera and okEnvironment and okBattlers
  if installed and V.mod.events and type(V.mod.events.on) == "function" then
    V.mod.events:on("battle.ended", releaseVoxelHost)
  end
  return installed
end

function StadiumBackground.installed()
  return installed
end

return StadiumBackground
