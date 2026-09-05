-- Voxel world mode: characters as flat forward-facing sprite billboards.
--
-- Every character -- the player, NPCs, the ghosts standing on a neighbour
-- map -- is its CURRENT 2D sprite frame on a single flat quad. The sheets
-- carry real alpha and the shader discards it, so the quad cuts the
-- sprite's exact silhouette out of itself; no geometry is built from the
-- pixels and nothing about a sprite is voxelized.
--
-- That is deliberate. A sprite is a DRAWING, not an object seen from one
-- side: Gen 1's overworld figures are 16x16 icons with a fixed front-on
-- reading, and turning one into a solid -- whether a contoured slab or a
-- carved visual hull -- reconstructs a body the artist never drew and the
-- game never implied. It also had the mod ship a description of the ROM
-- art. One quad wearing the real frame is both more faithful and cheaper:
-- it needs no pixel access at all, only the sheet's dimensions.
--
-- Vanilla figures all read that dimension as a fixed 16, but a mod's
-- registered sprite (furniture, decor placed as an overworld entity) can
-- carry its own frameWidth/frameHeight the 2D path already honours -- see
-- buildCard below. The card stays a flat drawing either way; only its
-- size changes.
--
-- The card always faces SOUTH -- the direction the 2D game implies -- and
-- only LEANS BACK, pivoting at its feet, by exactly the camera's pitch
-- (VoxelScene's billboardMatrix), so at every tilt level it reads face-on
-- like the flat game. Right-facing and the alternating walk step are
-- matrix mirrors, not extra meshes. UVs point into the live sheet image,
-- so RED++ OBP bakes, SGB palette bakes and sprite-replacing mods all
-- texture it with no rebuild.

-- the mod namespace (see main.lua): V.require loads a sibling module
local V = ...

local Assets = require("src.render.Assets")
local Voxel3D = V.require("Voxel3D")

local SpriteBillboards = {}

local meshes = {}
local tableAnchors = {}

-- Oak's original item card has two transparent rows below its visible ball.
-- Measure the source before offering a per-pose 3D anchor; replacement art,
-- explicit anchors and every ordinary sprite retain their own placement.
function SpriteBillboards.tableAnchor(def)
  if def.id ~= "SPRITE_POKE_BALL"
      or def.image ~= "assets/generated/sprites/poke_ball.png"
      or (def.frames or 1) ~= 1 or def.walker or def.trueColor
      or (def.frameWidth or 16) ~= 16 or (def.frameHeight or 16) ~= 16
      or def.anchorX ~= nil or def.anchorY ~= nil then return nil end
  local path = def.image
  if tableAnchors[path] == nil then
    local ok, data = pcall(Assets.imageData, path)
    local anchor = false
    if ok and data and data.getPixel and data.getDimensions then
      local w, h = data:getDimensions()
      if w == 16 and h == 16 then
        local x0, y0, x1, y1 = w, h, -1, -1
        local grayscale = true
        for y = 0, h - 1 do for x = 0, w - 1 do
          local r, g, b, a = data:getPixel(x, y)
          if math.abs(r - g) > 0.001 or math.abs(r - b) > 0.001 then
            grayscale = false
          end
          -- Same OBJ color-0 key as SpriteRenderer.getObpImage.
          if a >= 0.5 and r <= 0.83 then
            x0, y0 = math.min(x0, x), math.min(y0, y)
            x1, y1 = math.max(x1, x), math.max(y1, y)
          end
        end end
        if grayscale and x0 == 2 and y0 == 2 and x1 == 13 and y1 == 13 then
          anchor = y1 + 1
        end
      end
      if data.release then data:release() end
    end
    tableAnchors[path] = anchor
  end
  return tableAnchors[path] or nil
end

-- One flat quad -- 16x16 for every vanilla figure, or the def's own
-- frameWidth x frameHeight for a mod sprite registered bigger than that --
-- UV-mapped to a whole frame. A hair of inset keeps the sampler inside
-- this frame rather than picking up the neighbouring one along the shared
-- edge.
--
-- Mat4.billboard and Mat4.caster both place the finished card by the
-- closed form World = R * (Local - (8,0,0)) + (px+8, y, py+8): a fixed
-- local shift of 8 (half the vanilla 16px width) pulls the card's own
-- origin to its centre before the lean/yaw rotation R is applied, so it
-- pivots there instead of at its left edge, and only then is it placed at
-- the entity's tile centre. That local shift is fixed and shared by every
-- entity, so a wider card bakes its OWN half-width in here
-- (x0 = 8 - fw / 2) rather than asking the shared matrices to know each
-- sprite's size -- for fw == 16 that is x0 = 0, the original quad. Custom
-- anchors use the same convention as SpriteRenderer: anchorX measures from
-- the frame's left edge and anchorY measures down from its top edge.
local function buildCard(def, frame, visualAnchorY)
  local ok, img = pcall(Assets.image, def.image)
  if not (ok and img) then return nil end
  local iw, ih = img:getDimensions()
  local fw = def.frameWidth or 16
  local fh = def.frameHeight or 16
  local anchorX = def.anchorX or fw / 2
  local anchorY = def.anchorY or visualAnchorY or fh
  local fy = frame * fh
  if fy + fh > ih then fy = 0 end
  local u0, u1 = 0.02 / iw, (fw - 0.02) / iw
  local v0, v1 = (fy + 0.05) / ih, (fy + fh - 0.05) / ih
  local x0, x1 = 8 - anchorX, 8 - anchorX + fw
  local y0, y1 = anchorY - fh, anchorY
  local verts = {
    { x0, y0, 0, u0, v1, 1 }, { x1, y0, 0, u1, v1, 1 },
    { x1, y1, 0, u1, v0, 1 }, { x0, y1, 0, u0, v0, 1 },
  }
  local indices = {}
  Voxel3D.pushQuad(indices, 0)
  return Voxel3D.newMesh(verts, indices)
end

-- The card for one (sprite def, frame index), or nil (headless / no
-- image), cached like every other derived GPU object.
--
-- The solid draw, the sun pass and the player's occlusion silhouette all
-- take THIS mesh. That the three agree is load-bearing, not tidiness: the
-- silhouette is drawn with the depth test INVERTED, so any self-overlap in
-- the mesh would read as "behind something" and repaint the figure on open
-- ground whether or not anything hides it; and the sun must see the same
-- outline the camera does, or a shadow stops matching what casts it.
function SpriteBillboards.mesh(def, frame, visualAnchorY)
  -- Geometry-affecting sprite metadata is part of the key too: two defs can
  -- point at the same sheet with different sizes or anchors and must not
  -- alias the first mesh built for that image/frame pair.
  local key = def.image .. "#" .. frame .. "#"
              .. (def.frameWidth or 16) .. "x" .. (def.frameHeight or 16)
              .. "@" .. (def.anchorX or "default")
              .. "," .. (def.anchorY or visualAnchorY or "default")
  if meshes[key] == nil then
    local ok, m = pcall(buildCard, def, frame, visualAnchorY)
    meshes[key] = (ok and m) or false
  end
  return meshes[key] or nil
end

-- Kept as its own name because the shadow and ghost passes read as their
-- own thing at the call sites; it once carried a different mesh from the
-- solid draw, and now deliberately does not.
SpriteBillboards.shadowQuad = SpriteBillboards.mesh

function SpriteBillboards.invalidate()
  meshes = {}
  tableAnchors = {}
end

Assets.register(SpriteBillboards.invalidate)

return SpriteBillboards
