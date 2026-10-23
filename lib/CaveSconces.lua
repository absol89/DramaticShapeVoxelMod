-- TEST100: refined living-cave flames on weathered iron-grey hardware.
--
-- The donor implementation placed one camera-facing flame card at the centre
-- of a solid map cell. TEST68 instead finds the exact open side of that cell,
-- anchors a bracket on the boundary, and projects the torch into the walkable
-- space. Fixture, handle, outer flame and hot core are all real 3D meshes.

local V = ...

local Assets = require("src.render.Assets")
local Voxel3D = V.require("Voxel3D")
local CommunityVisuals = V.require("CommunityVisuals")
local Structures = V.require("Structures")
local TowerFogSettings = V.require("TowerFogSettings")

local CaveSconces = {}

local EVERY = 9
local FLAME_FRAMES = 4
local cache = setmetatable({}, { __mode = "k" })
local whiteImg = nil

local function keyOf(tx, ty)
  return (ty + 64) * 4096 + (tx + 64)
end

local function hash01(x, z, salt)
  local n = (x * 73856093 + z * 19349663 + salt * 83492791) % 104729
  if n < 0 then n = n + 104729 end
  return n / 104729
end

local function isPokemonTower(map)
  if not map then return false end
  local tid = tostring((map.def and map.def.tileset)
              or (map.tileset and map.tileset.id) or ""):upper()
  local id = tostring(map.id or ""):upper()
  return tid == "CEMETERY" and id:match("^POKEMON_TOWER_[1-7]F$") ~= nil
end

local function white()
  if whiteImg then return whiteImg end
  local ok, img = pcall(function()
    local data = love.image.newImageData(2, 2)
    for y = 0, 1 do
      for x = 0, 1 do data:setPixel(x, y, 1, 1, 1, 1) end
    end
    local made = love.graphics.newImage(data)
    made:setFilter("nearest", "nearest")
    return made
  end)
  if ok then whiteImg = img end
  return whiteImg
end

local function group()
  return { verts = {}, indices = {}, quads = 0 }
end

local function quad(g, a, b, c, d, shade)
  local s = shade or 1
  g.verts[#g.verts + 1] = { a[1], a[2], a[3], 0, 0, s }
  g.verts[#g.verts + 1] = { b[1], b[2], b[3], 1, 0, s }
  g.verts[#g.verts + 1] = { c[1], c[2], c[3], 1, 1, s }
  g.verts[#g.verts + 1] = { d[1], d[2], d[3], 0, 1, s }
  Voxel3D.pushQuad(g.indices, g.quads)
  g.quads = g.quads + 1
end

local function box(g, x0, y0, z0, x1, y1, z1)
  quad(g, { x1,y0,z0 }, { x1,y0,z1 }, { x1,y1,z1 }, { x1,y1,z0 }, 0.88)
  quad(g, { x0,y0,z1 }, { x0,y0,z0 }, { x0,y1,z0 }, { x0,y1,z1 }, 0.68)
  quad(g, { x0,y1,z0 }, { x1,y1,z0 }, { x1,y1,z1 }, { x0,y1,z1 }, 1.06)
  quad(g, { x0,y0,z1 }, { x1,y0,z1 }, { x1,y0,z0 }, { x0,y0,z0 }, 0.58)
  quad(g, { x0,y0,z1 }, { x1,y0,z1 }, { x1,y1,z1 }, { x0,y1,z1 }, 0.94)
  quad(g, { x1,y0,z0 }, { x0,y0,z0 }, { x0,y1,z0 }, { x1,y1,z0 }, 0.74)
end

-- Three nested, low-poly disks are drawn additively beneath each flame. They
-- brighten the existing dirt rather than replacing it, and stay horizontal so
-- angled cameras cannot produce the doubled wall silhouettes seen in TEST83.
local function floorGlow(g, x, y, z, dx, dz, tangentRadius, forwardRadius,
                         sides, seed)
  local tx, tz = -dz, dx
  for i = 0, sides - 1 do
    local a0 = i / sides * math.pi * 2
    local a1 = (i + 1) / sides * math.pi * 2
    local w0 = 0.90 + hash01(seed, i, 367) * 0.18
    local w1 = 0.90 + hash01(seed, i + 1, 367) * 0.18
    local function rim(a, w)
      return {
        x + tx * math.cos(a) * tangentRadius * w
          + dx * math.sin(a) * forwardRadius * w,
        y,
        z + tz * math.cos(a) * tangentRadius * w
          + dz * math.sin(a) * forwardRadius * w,
      }
    end
    quad(g, {x,y,z}, rim(a0,w0), rim(a1,w1), {x,y,z}, 1)
  end
end

-- A vertical companion to floorGlow. Tower flames are mounted high on a tall
-- chamber wall, so their quiet reflected light belongs behind the fixture,
-- not as a disconnected orange pool far below it. The glow plane sits safely
-- in front of TEST119's flat wall and never participates in wall lighting or
-- geometry, keeping it stable while the camera moves.
local function wallGlow(g, x, y, z, dx, dz, tangentRadius, verticalRadius,
                        sides, seed)
  local tx, tz = -dz, dx
  for i = 0, sides - 1 do
    local a0 = i / sides * math.pi * 2
    local a1 = (i + 1) / sides * math.pi * 2
    local w0 = 0.92 + hash01(seed, i, 401) * 0.14
    local w1 = 0.92 + hash01(seed, i + 1, 401) * 0.14
    local function rim(a, w)
      return {
        x + tx * math.cos(a) * tangentRadius * w,
        y + math.sin(a) * verticalRadius * w,
        z + tz * math.cos(a) * tangentRadius * w,
      }
    end
    quad(g, {x,y,z}, rim(a0,w0), rim(a1,w1), {x,y,z}, 1)
  end
end

local function flame(g, x, z, scale, y0, y1, leanX, leanZ)
  local sides = 6
  local baseR, bellyR, neckR = 1.18 * scale, 2.25 * scale, 0.82 * scale
  -- A low belly and crooked narrow neck break up the old symmetric diamond
  -- silhouette while retaining the approved TEST80 height.
  local ym = y0 + (y1 - y0) * 0.31
  local yn = y0 + (y1 - y0) * 0.69
  local neckX = x + leanX * 0.34
  local neckZ = z + leanZ * 0.34
  for i = 0, sides - 1 do
    local a0 = (i / sides) * math.pi * 2
    local a1 = ((i + 1) / sides) * math.pi * 2
    local b0 = { x + math.cos(a0) * baseR, y0,
                 z + math.sin(a0) * baseR }
    local b1 = { x + math.cos(a1) * baseR, y0,
                 z + math.sin(a1) * baseR }
    local m0 = { x + math.cos(a0) * bellyR, ym,
                 z + math.sin(a0) * bellyR }
    local m1 = { x + math.cos(a1) * bellyR, ym,
                 z + math.sin(a1) * bellyR }
    local n0 = { neckX + math.cos(a0) * neckR, yn,
                 neckZ + math.sin(a0) * neckR }
    local n1 = { neckX + math.cos(a1) * neckR, yn,
                 neckZ + math.sin(a1) * neckR }
    local tip = { x + leanX, y1, z + leanZ }
    local shade = 0.78 + 0.22 * math.cos(a0 - 0.65)
    quad(g, b0, b1, m1, m0, shade)
    quad(g, m0, m1, n1, n0, math.min(1.06, shade + 0.06))
    quad(g, n0, n1, tip, tip, math.min(1.10, shade + 0.10))
  end
end

local function build(map)
  local tower = isPokemonTower(map)
  local every = tower and 7 or EVERY
  -- TEST125 turns the Tower's oversized purple wall bar into a compact
  -- blackened-bronze sconce: short backplate, projecting arm and shallow cup.
  -- Its flame keeps the approved high placement on the 64px wall.
  local plateY0, plateY1 = tower and 44.0 or 12.0, tower and 50.4 or 20.0
  local armY0, armY1 = tower and 47.0 or 14.0, tower and 48.25 or 15.5
  local shaftY0, shaftY1 = tower and 47.1 or 13.2, tower and 52.15 or 19.6
  local rimY0, rimY1 = tower and 51.35 or 18.7, tower and 53.05 or 20.2
  local flameY0 = tower and 52.25 or 19.15
  local outerTopBase, outerTopPulse = tower and 58.95 or 23.55,
                                       tower and 0.32 or 0.65
  local coreY0 = tower and 52.55 or 19.22
  local coreTopBase, coreTopPulse = tower and 57.85 or 22.65,
                                     tower and 0.22 or 0.38
  -- TEST191: Victory Road's walls stand at their source 16 (CaveRubble),
  -- so its torches hang six lower, and never on the loose rocks
  local Rubble = V.require("CaveRubble")
  local rubble = not tower and Rubble.shelfWalls(map)   -- TEST203: + Cerulean
  -- TEST206: Cerulean's walls stand at 22, so its torches drop only 2
  local drop = rubble and (Rubble.applies(map) and 6 or 2) or 0
  plateY0, plateY1 = plateY0 - drop, plateY1 - drop
  armY0, armY1 = armY0 - drop, armY1 - drop
  shaftY0, shaftY1 = shaftY0 - drop, shaftY1 - drop
  rimY0, rimY1 = rimY0 - drop, rimY1 - drop
  flameY0, coreY0 = flameY0 - drop, coreY0 - drop
  outerTopBase, coreTopBase = outerTopBase - drop, coreTopBase - drop
  local wc, hc = map.widthCells or 0, map.heightCells or 0
  -- TEST101 splits the ironwork into separately shaded pieces. The geometry
  -- and placement stay identical to TEST100; only the material hierarchy
  -- changes so the support reads as assembled gunmetal instead of flat grey.
  local fixturePlate, fixtureArm, fixtureShaft, fixtureRim =
    group(), group(), group(), group()
  local floorWide, floorMid, floorCore, floorDapple =
    group(), group(), group(), group()
  -- Tower sconces are split into three deterministic timing groups. This is
  -- enough variation for neighbouring lights to breathe independently without
  -- turning every fixture into a separate mobile draw call. Caves use group 1
  -- only and retain their approved presentation.
  local wallWide, wallMid, wallCore = {}, {}, {}
  local outerFrames, coreFrames, emberFrames = {}, {}, {}
  for phase = 1, 3 do
    wallWide[phase], wallMid[phase], wallCore[phase] = group(), group(), group()
    outerFrames[phase], coreFrames[phase], emberFrames[phase] = {}, {}, {}
    for i = 1, FLAME_FRAMES do
      outerFrames[phase][i], coreFrames[phase][i], emberFrames[phase][i] =
        group(), group(), group()
    end
  end
  local list = {}
  local reserved = {}
  -- Use the mesher's fully resolved map analysis rather than collision alone.
  -- It knows which blocked cells are true wall, low ledge, ladder, prop or
  -- detected black void—the distinctions collision deliberately does not.
  local S = Structures.forMap(map)

  local function walk(cx, cy)
    if cx < 0 or cy < 0 or cx >= wc or cy >= hc then return false end
    local ok, result = pcall(function() return map:isWalkableCell(cx, cy) end)
    return ok and result or false
  end

  local function floorAt(cx, cy)
    local ok, h = pcall(V.require("VoxelScene").groundAt,
                        map, cx, cy, cx * 16, cy * 16)
    return (ok and tonumber(h)) or 0
  end

  local function wallFace(cx, cy, dx, dz)
    local samples
    if dx > 0 then
      samples = { { cx * 2 + 1, cy * 2 }, { cx * 2 + 1, cy * 2 + 1 } }
    elseif dx < 0 then
      samples = { { cx * 2, cy * 2 }, { cx * 2, cy * 2 + 1 } }
    elseif dz > 0 then
      samples = { { cx * 2, cy * 2 + 1 }, { cx * 2 + 1, cy * 2 + 1 } }
    else
      samples = { { cx * 2, cy * 2 }, { cx * 2 + 1, cy * 2 } }
    end
    for _, p in ipairs(samples) do
      local k = keyOf(p[1], p[2])
      local s = S and S.shapeAt and S.shapeAt[k]
      if not s or s.class ~= "wall" or (S.skip and S.skip[k]) then
        return false
      end
      if rubble and Rubble.isLow(map, S.tileAt and S.tileAt[k]) then
        return false
      end
    end
    return true
  end

  local function supportedWallFace(cx, cy, dx, dz)
    if not wallFace(cx, cy, dx, dz) then return false end
    -- A wall-mounted light needs an actual wall run, not an isolated boulder
    -- or one-cell column. At least one lateral neighbour must continue the
    -- same full-height face behind the bracket.
    local lx, lz = -dz, dx
    return wallFace(cx + lx, cy + lz, dx, dz)
        or wallFace(cx - lx, cy - lz, dx, dz)
  end

  for cy = 0, hc - 1 do
    for cx = 0, wc - 1 do
      if not walk(cx, cy) then
        local sides = {}
        if walk(cx, cy + 1) and supportedWallFace(cx, cy, 0, 1) then
          sides[#sides + 1] = { 0, 1 }
        end
        if walk(cx, cy - 1) and supportedWallFace(cx, cy, 0, -1) then
          sides[#sides + 1] = { 0, -1 }
        end
        if walk(cx + 1, cy) and supportedWallFace(cx, cy, 1, 0) then
          sides[#sides + 1] = { 1, 0 }
        end
        if walk(cx - 1, cy) and supportedWallFace(cx, cy, -1, 0) then
          sides[#sides + 1] = { -1, 0 }
        end
        if #sides > 0 and math.floor(hash01(cx, cy, 317) * every) == 0 then
          local pick = 1 + math.floor(hash01(cx, cy, 331) * #sides)
          if pick > #sides then pick = #sides end
          local dx, dz = sides[pick][1], sides[pick][2]

          -- sx/sz is the real solid/open boundary. The plate starts just in
          -- front of it and the handle sits six pixels into the open cell.
          local sx = cx * 16 + 8 + dx * 8
          local sz = cy * 16 + 8 + dz * 8
          local plateX, plateZ = sx + dx * 1.8, sz + dz * 1.8
          local torchX, torchZ = sx + dx * 6.0, sz + dz * 6.0
          local floorY = floorAt(cx + dx, cy + dz)
          local phaseGroup = tower
            and (1 + math.floor(hash01(cx, cy, 409) * 3)) or 1
          if phaseGroup > 3 then phaseGroup = 3 end

          if tower then
            -- The Tower's high fixture illuminates the stone directly behind
            -- it. These three stable nested ellipses replace the old floor
            -- pool; the animated flame remains the only flickering element.
            local wallX, wallZ = sx + dx * 0.42, sz + dz * 0.42
            wallGlow(wallWide[phaseGroup], wallX, 52.0, wallZ, dx, dz,
                     6.6, 7.4, 24, cx * 211 + cy)
            wallGlow(wallMid[phaseGroup], wallX + dx * 0.015, 52.0,
                     wallZ + dz * 0.015, dx, dz,
                     4.2, 4.9, 22, cx * 223 + cy)
            wallGlow(wallCore[phaseGroup], wallX + dx * 0.030, 52.7,
                     wallZ + dz * 0.030, dx, dz,
                     1.9, 2.6, 20, cx * 227 + cy)
          else
            -- Cave torches keep their approved low dirt falloff unchanged.
            local lightX, lightZ = torchX + dx * 4.3, torchZ + dz * 4.3
            floorGlow(floorWide, lightX, floorY + 0.34, lightZ, dx, dz,
                      11.2, 15.0, 16, cx * 211 + cy)
            floorGlow(floorMid, lightX, floorY + 0.37, lightZ, dx, dz,
                      7.4, 10.3, 14, cx * 223 + cy)
            floorGlow(floorCore, lightX, floorY + 0.40, lightZ, dx, dz,
                      3.8, 5.8, 12, cx * 227 + cy)

            -- Small broken highlights interrupt the concentric silhouette of
            -- the three broad pools. Their positions are deterministic, stay
            -- close to the burner, and read as light catching uneven dirt.
            local tx, tz = -dz, dx
            for fleck = 1, 3 do
              local side = (hash01(cx + fleck*7, cy, 229)-0.5)*8.2
              local ahead = 2.0+hash01(cx, cy + fleck*11, 233)*8.2
              local fx = lightX+tx*side+dx*ahead
              local fz = lightZ+tz*side+dz*ahead
              local fr = 1.0+hash01(cx+fleck,cy,239)*1.15
              floorGlow(floorDapple, fx, floorY+0.43, fz, dx, dz,
                        fr, fr*(1.18+hash01(cx,cy+fleck,241)*0.36), 7,
                        cx*251+cy*13+fleck)
            end
          end

          if dx ~= 0 then
              box(fixturePlate, plateX - 0.60, plateY0, plateZ - 1.85,
                         plateX + 0.60, plateY1, plateZ + 1.85)
            box(fixtureArm, math.min(plateX, torchX) - 0.65, armY0, plateZ - 0.65,
                         math.max(plateX, torchX) + 0.65, armY1, plateZ + 0.65)
          else
              box(fixturePlate, plateX - 1.85, plateY0, plateZ - 0.60,
                         plateX + 1.85, plateY1, plateZ + 0.60)
            box(fixtureArm, plateX - 0.65, armY0, math.min(plateZ, torchZ) - 0.65,
                         plateX + 0.65, armY1, math.max(plateZ, torchZ) + 0.65)
          end
          box(fixtureShaft, torchX - 0.85, shaftY0, torchZ - 0.85,
                       torchX + 0.85, shaftY1, torchZ + 0.85)
          box(fixtureRim, torchX - 1.20, rimY0, torchZ - 1.20,
                       torchX + 1.20, rimY1, torchZ + 1.20)

          local lean = (hash01(cx, cy, 347) - 0.5) * 1.4
          -- Four cached silhouettes give the fire genuine motion without
          -- rebuilding meshes per frame. Each sconce receives deterministic
          -- per-frame width, height and lean changes, while every possible
          -- tip remains beneath the wall crown for reliable occlusion.
          for f = 1, FLAME_FRAMES do
            local pulse = hash01(cx+f*13, cy-f*7, 349)-0.5
            local twitch = hash01(cx-f*11, cy+f*17, 353)-0.5
            local outerScale = 0.67+pulse*0.13
            local outerTop = outerTopBase+pulse*outerTopPulse
            flame(outerFrames[phaseGroup][f], torchX, torchZ,
                  outerScale, flameY0, outerTop,
                  dx*(0.40+pulse*0.22)+dz*(lean*0.5+twitch*1.05),
                  dz*(0.40+pulse*0.22)-dx*(lean*0.5+twitch*1.05))

            local coreScale = 0.38-pulse*0.045
            local coreTop = coreTopBase-pulse*coreTopPulse
            flame(coreFrames[phaseGroup][f], torchX, torchZ,
                  coreScale, coreY0, coreTop,
                  dx*(0.22-pulse*0.08)+dz*twitch*0.36,
                  dz*(0.22-pulse*0.08)-dx*twitch*0.36)

            -- Tiny rising embers make the light volume feel alive. They stay
            -- close to the burner and below the wall crown, and FULL alone
            -- draws them so SUBTLE retains its original budget.
            for spark = 1, tower and 1 or 2 do
              local side = (hash01(cx+f, cy+spark, 379)-0.5)*2.0
              local lift = (tower and 58.2 or 21.0 - drop)
                + hash01(cx+spark, cy+f, 383) * (tower and 2.5 or 2.35)
              local push = hash01(cx+spark*3, cy-f, 389)*1.05
              local ex = torchX-dz*side+dx*push
              local ez = torchZ+dx*side+dz*push
              local r = 0.10+hash01(cx+f,cy+spark,397)*0.13
              box(emberFrames[phaseGroup][f], ex-r, lift-r, ez-r,
                                  ex+r, lift+r, ez+r)
            end
          end
          -- Reserve this wall segment and one continuing segment on either
          -- side. CaveAtmosphere3D reads the same table, so rock, water and
          -- overhang passes cannot independently grow through the fixture.
          local lx, lz = -dz, dx
          for offset = -1, 1 do
            reserved[keyOf(cx+lx*offset, cy+lz*offset)] = true
          end
          list[#list + 1] = {
            torchX, torchZ,
            x = torchX, z = torchZ,
            dx = dx, dz = dz,
          }
        end
      end
    end
  end

  local result = {
    fixturePlate = Voxel3D.newMesh(fixturePlate.verts, fixturePlate.indices),
    fixtureArm = Voxel3D.newMesh(fixtureArm.verts, fixtureArm.indices),
    fixtureShaft = Voxel3D.newMesh(fixtureShaft.verts, fixtureShaft.indices),
    fixtureRim = Voxel3D.newMesh(fixtureRim.verts, fixtureRim.indices),
    floorWide = Voxel3D.newMesh(floorWide.verts, floorWide.indices),
    floorMid = Voxel3D.newMesh(floorMid.verts, floorMid.indices),
    floorCore = Voxel3D.newMesh(floorCore.verts, floorCore.indices),
    floorDapple = Voxel3D.newMesh(floorDapple.verts, floorDapple.indices),
    wallWide = {}, wallMid = {}, wallCore = {},
    outerFrames = {}, coreFrames = {}, emberFrames = {},
    list = list, reserved = reserved,
  }
  for phase = 1, 3 do
    result.wallWide[phase] = Voxel3D.newMesh(
      wallWide[phase].verts, wallWide[phase].indices)
    result.wallMid[phase] = Voxel3D.newMesh(
      wallMid[phase].verts, wallMid[phase].indices)
    result.wallCore[phase] = Voxel3D.newMesh(
      wallCore[phase].verts, wallCore[phase].indices)
    result.outerFrames[phase], result.coreFrames[phase],
      result.emberFrames[phase] = {}, {}, {}
    for i = 1, FLAME_FRAMES do
      result.outerFrames[phase][i] = Voxel3D.newMesh(
        outerFrames[phase][i].verts, outerFrames[phase][i].indices)
      result.coreFrames[phase][i] = Voxel3D.newMesh(
        coreFrames[phase][i].verts, coreFrames[phase][i].indices)
      result.emberFrames[phase][i] = Voxel3D.newMesh(
        emberFrames[phase][i].verts, emberFrames[phase][i].indices)
    end
  end
  return result
end

local function drawMap(map)
  local tower = isPokemonTower(map)
  local towerDetails = tower and TowerFogSettings.detailsLevel() or nil
  if towerDetails == "off" then return false end
  if not tower and CommunityVisuals.caveDetailLevel() == "off" then return false end
  if not tower and not CommunityVisuals.customCaves() then return false end
  local tid = map and tostring((map.def and map.def.tileset)
              or (map.tileset and map.tileset.id) or "") or ""
  if not tower and tid ~= "CAVERN" then return false end

  local slot = cache[map]
  if not slot then
    slot = build(map)
    cache[map] = slot
  end
  if not (slot and slot.fixturePlate) then return false end

  local img = white()
  if not img then return false end
  local t = 0
  pcall(function() t = love.timer.getTime() end)
  local towerFull = towerDetails == "full"
  local flicker = 0.86 + 0.09*math.sin(t*8.7)
                         + 0.05*math.sin(t*17.9+1.3)
  local full = not tower and CommunityVisuals.caveDetailLevel() == "full"

  local g = love and love.graphics
  local pushed = g and g.push and pcall(g.push, "all")
  pcall(function()
    love.graphics.setDepthMode("lequal", true)
    love.graphics.setBlendMode("alpha")
    -- Layered gunmetal separates the assembled parts while existing per-face
    -- shading retains the worn low-poly facets. The rim alone carries a very
    -- slight warm stain from the flame; none of the support reads as wood.
    love.graphics.setColor(tower and 0.095 or 0.12,
                           tower and 0.082 or 0.115,
                           tower and 0.064 or 0.11, 1)
    Voxel3D.draw(slot.fixturePlate, img)
    love.graphics.setColor(tower and 0.18 or 0.20,
                           tower and 0.135 or 0.195,
                           tower and 0.075 or 0.185, 1)
    Voxel3D.draw(slot.fixtureArm, img)
    love.graphics.setColor(tower and 0.12 or 0.145,
                           tower and 0.095 or 0.14,
                           tower and 0.065 or 0.135, 1)
    Voxel3D.draw(slot.fixtureShaft, img)
    love.graphics.setColor(tower and 0.30 or 0.24,
                           tower and 0.205 or 0.18,
                           tower and 0.075 or 0.12, 1)
    Voxel3D.draw(slot.fixtureRim, img)

    love.graphics.setDepthMode("lequal", false)
    Voxel3D.lighting(false)
    -- The Tower reflection now follows three independent, slow timing groups.
    -- Its narrow amplitude is intentionally much calmer than the flame: the
    -- wall feels illuminated and alive without reviving the old rapid shimmer.
    if tower then
      love.graphics.setBlendMode("alpha")
      for phase = 1, 3 do
        local pt = t + (phase - 1) * 1.73
        local wallPulse = towerFull
          and (.96 + .055 * math.sin(pt * 2.13)
            + .025 * math.sin(pt * 5.37 + phase)) or 1
        love.graphics.setColor(0.95, 0.48, 0.12, 0.047 * wallPulse)
        Voxel3D.draw(slot.wallWide[phase], img)
        love.graphics.setColor(1.00, 0.58, 0.14, 0.079 * wallPulse)
        Voxel3D.draw(slot.wallMid[phase], img)
        love.graphics.setColor(1.00, 0.68, 0.20, 0.122 * wallPulse)
        Voxel3D.draw(slot.wallCore[phase], img)
      end
    end
    -- Normal-alpha ground pools are more reliable across the supported LOVE
    -- renderers than additive decals.  They sit at the sampled walkable-floor
    -- height and never touch the irregular wall mesh, eliminating TEST88's
    -- shelf-shaped intersections while retaining a broad flickering falloff.
    love.graphics.setBlendMode("alpha")
    love.graphics.setColor(0.62, 0.19, 0.015, 0.045*flicker)
    if slot.floorWide then Voxel3D.draw(slot.floorWide, img) end
    love.graphics.setColor(0.78, 0.27, 0.022, 0.075*flicker)
    if slot.floorMid then Voxel3D.draw(slot.floorMid, img) end
    love.graphics.setColor(0.95, 0.40, 0.040, 0.105*flicker)
    if slot.floorCore then Voxel3D.draw(slot.floorCore, img) end
    love.graphics.setColor(1.00, 0.50, 0.070, 0.055*flicker)
    if slot.floorDapple then Voxel3D.draw(slot.floorDapple, img) end

    local phaseCount = tower and 3 or 1
    for phase = 1, phaseCount do
      local pt = t + (phase - 1) * .71
      local phaseBeat = pt*10.7 + math.sin(pt*4.9)*0.72
        + math.sin(pt*13.3)*0.21
      local phaseFrame = (tower and not towerFull) and 1
        or (1 + (math.floor(phaseBeat) % FLAME_FRAMES))
      local phaseFlicker = (tower and not towerFull) and 1
        or (0.86 + 0.09*math.sin(pt*8.7)
          + 0.05*math.sin(pt*17.9+1.3+phase))
      love.graphics.setColor(1.0, 0.30 + 0.16 * phaseFlicker, 0.025, 0.95)
      Voxel3D.draw(slot.outerFrames[phase][phaseFrame], img)
      love.graphics.setColor(1.0, 0.76 + 0.18 * phaseFlicker, 0.16, 1)
      Voxel3D.draw(slot.coreFrames[phase][phaseFrame], img)
      if (towerFull or full) and slot.emberFrames[phase][phaseFrame] then
        love.graphics.setColor(1.0, 0.48+0.22*phaseFlicker, 0.055, 0.82)
        Voxel3D.draw(slot.emberFrames[phase][phaseFrame], img)
      end
    end
    Voxel3D.lighting(true)
  end)
  -- Restore the shader even if a draw above faulted after switching it.
  pcall(Voxel3D.lighting, true)
  if pushed then pcall(g.pop) end
  return true
end

-- Atmosphere geometry is built separately, but it must obey the exact torch
-- decisions made above. Exposing a read-only query avoids duplicating the
-- placement hash and lets both free roam and battle share one clearance map.
function CaveSconces.reserved(map, cx, cy)
  if not map then return false end
  if isPokemonTower(map) and TowerFogSettings.detailsLevel() == "off" then
    return false
  end
  local slot = cache[map]
  if not slot then slot = build(map); cache[map] = slot end
  return slot and slot.reserved and slot.reserved[keyOf(cx, cy)] or false
end

-- Cave dressing uses these cached source points only to choose which nearby
-- solid rocks receive a warmer material.  Returning the table avoids a second
-- placement pass and keeps the highlight locked to the actual torch.
function CaveSconces.sources(map)
  if not map then return {} end
  if isPokemonTower(map) and TowerFogSettings.detailsLevel() == "off" then
    return {}
  end
  local slot = cache[map]
  if not slot then slot = build(map); cache[map] = slot end
  return (slot and slot.list) or {}
end

function CaveSconces.draw(state)
  return drawMap(state and state.map)
end

-- BattleScene owns the host map directly rather than a VoxelScene state.
-- Reuse the exact same cached fixture/flame meshes so battle and free roam
-- cannot drift into two different torch designs or placements.
function CaveSconces.drawBattle(map)
  return drawMap(map)
end

function CaveSconces.invalidate()
  for _, slot in pairs(cache) do
    for _, name in ipairs({"fixturePlate", "fixtureArm", "fixtureShaft",
                           "fixtureRim", "floorWide", "floorMid", "floorCore",
                           "floorDapple"}) do
      local mesh = slot and slot[name]
      if mesh and mesh.release then pcall(mesh.release, mesh) end
    end
    for _, grouped in ipairs({slot and slot.wallWide, slot and slot.wallMid,
                              slot and slot.wallCore}) do
      for _, mesh in ipairs(grouped or {}) do
        if mesh and mesh.release then pcall(mesh.release, mesh) end
      end
    end
    for _, phaseGroups in ipairs({slot and slot.outerFrames,
                                  slot and slot.coreFrames,
                                  slot and slot.emberFrames}) do
      for _, frames in ipairs(phaseGroups or {}) do
        for _, mesh in ipairs(frames or {}) do
          if mesh and mesh.release then pcall(mesh.release, mesh) end
        end
      end
    end
  end
  cache = setmetatable({}, { __mode = "k" })
  if whiteImg and whiteImg.release then pcall(whiteImg.release, whiteImg) end
  whiteImg = nil
end

Assets.register(CaveSconces.invalidate)

return CaveSconces
