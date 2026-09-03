-- Legendary Visuals community pillar layouts for Battle Art Voxel.
-- The exact four-tile owner is published by Structures only while a custom
-- layout is selected. BATTLE ART therefore preserves the original round art.

local V = ...
local Voxel3D = V.require("Voxel3D")
local Mat4 = V.require("Mat4")
local CommunityVisuals = V.require("CommunityVisuals")

local P = { cache = {}, textures = {} }

local function mapKey(map)
  return map.id or (map.def and map.def.id) or tostring(map)
end

local function clamp(v) return math.max(0, math.min(1, v)) end
local function lerp(a, b, t) return a + (b - a) * t end

local RAMPS = {
  red = {
    { .18, .070, .045 }, { .32, .125, .080 },
    { .50, .225, .145 }, { .66, .375, .250 },
  },
  sandstone = {
    { .22, .155, .085 }, { .37, .275, .155 },
    { .56, .430, .260 }, { .72, .590, .390 },
  },
  slate = {
    { .085, .105, .145 }, { .175, .215, .285 },
    { .305, .365, .455 }, { .475, .545, .635 },
  },
}

local function rampColor(name, v)
  local ramp = RAMPS[name]
  if not ramp then return nil end
  local t = clamp((v - .24) / .50) * 3
  local i = math.min(3, math.floor(t) + 1)
  local f = t - math.floor(t)
  local a, b = ramp[i], ramp[i + 1] or ramp[i]
  return lerp(a[1], b[1], f), lerp(a[2], b[2], f),
         lerp(a[3], b[3], f)
end

local function texture()
  local color = CommunityVisuals.pillarColor()
  if P.textures[color] ~= nil then return P.textures[color] or nil end
  local ok, image = pcall(function()
    local d = love.image.newImageData(128, 128)
    local function h(x, y, k)
      local v = math.sin(x * 12.9898 + y * 78.233 + k * 23.173) * 43758.5453
      return v - math.floor(v)
    end
    for y = 0, 127 do
      for x = 0, 127 do
        local broad = h(math.floor(x / 24), math.floor(y / 20), 11) - .5
        local slab = h(math.floor((x + 7) / 13), math.floor((y + 3) / 12), 17) - .5
        local crystal = h(math.floor(x / 6), math.floor(y / 6), 23) - .5
        local grain = h(math.floor(x / 3), math.floor(y / 3), 29) - .5
        local v = .535 + broad * .13 + slab * .085 + crystal * .055
          + grain * .03 + (h(x, y, 31) - .5) * .012
          + math.sin(x * .071 + y * .049) * .02
        local r, g, b = v * .925 + slab * .018,
                        v * .965 + crystal * .012,
                        v * 1.025 + broad * .018
        local f = h(x, y, 47)
        if f > .997 then
          r, g, b = r * 1.34 + .1, g * 1.32 + .1, b * 1.27 + .1
        elseif f < .006 then
          r, g, b = r * .42, g * .44, b * .48
        elseif f < .022 then
          r, g, b = r * .72, g * .74, b * .78
        end
        local rr, gg, bb = rampColor(color, v)
        if rr then
          local detail = clamp((r + g + b) / (3 * math.max(v, .01)))
          r, g, b = rr * detail, gg * detail, bb * detail
        end
        if y >= 83 and y <= 93 and x >= 39 and x <= 89 then
          r, g, b = .145, .135, .125
        end
        if y >= 84 and y <= 92 and x >= 40 and x <= 88 then
          local edge = math.max(0, math.min(1,
            math.min(math.min(y - 84, 92 - y) / 1.5,
                     math.min(x - 41, 87 - x) / 2.5)))
          local z = .84 + edge * .095
          r, g, b = z * 1.08, z * .91, z * .58
        end
        d:setPixel(x, y, clamp(r), clamp(g), clamp(b), 1)
      end
    end
    local out = love.graphics.newImage(d)
    out:setFilter("nearest", "nearest")
    out:setWrap("repeat", "repeat")
    return out
  end)
  P.textures[color] = ok and image or false
  return P.textures[color] or nil
end

local function mask()
  if P.mask ~= nil then return P.mask or nil end
  local ok, image = pcall(function()
    local d = love.image.newImageData(128, 128)
    for y = 0, 127 do
      for x = 0, 127 do
        d:setPixel(x, y, 1, 1, 1,
          (y >= 85 and y <= 91 and x >= 41 and x <= 87) and 1 or 0)
      end
    end
    local out = love.graphics.newImage(d)
    out:setFilter("linear", "linear")
    return out
  end)
  P.mask = ok and image or false
  return P.mask or nil
end

local function neighbors(cx, cy, cells)
  local n = cells[cx .. "|" .. (cy - 1)] == true
  local s = cells[cx .. "|" .. (cy + 1)] == true
  local w = cells[(cx - 1) .. "|" .. cy] == true
  local e = cells[(cx + 1) .. "|" .. cy] == true
  return n, s, w, e
end

local function wallRole(cx, cy, cells, piers)
  local n, s, w, e = neighbors(cx, cy, cells)
  local horizontal, vertical = w or e, n or s
  local degree = (n and 1 or 0) + (s and 1 or 0)
    + (w and 1 or 0) + (e and 1 or 0)
  local structural = degree == 0 or degree == 1 or degree > 2
    or (horizontal and vertical)
  return degree > 0, structural or (piers and piers[cx .. "|" .. cy]),
         { north = n, south = s, west = w, east = e }
end

local function pierRhythm(cells)
  local anchors, piers, dirs = {}, {}, {}
  for key in pairs(cells) do
    local x, y = key:match("^(-?%d+)|(-?%d+)$")
    x, y = tonumber(x), tonumber(y)
    if x then
      local n, s, w, e = neighbors(x, y, cells)
      local horizontal, vertical = w or e, n or s
      local degree = (n and 1 or 0) + (s and 1 or 0)
        + (w and 1 or 0) + (e and 1 or 0)
      local structural = degree == 0 or degree == 1 or degree > 2
        or (horizontal and vertical)
      dirs[key] = { east = e, south = s }
      if structural then anchors[key], piers[key] = true, true end
    end
  end
  local function divide(ax, ay, dx, dy)
    local length = 0
    repeat
      length = length + 1
      local key = (ax + dx * length) .. "|" .. (ay + dy * length)
      if not cells[key] then return end
      if anchors[key] then break end
    until false
    local bays = math.ceil(length / 3)
    for divider = 1, bays - 1 do
      local step = math.floor(divider * length / bays + .5)
      piers[(ax + dx * step) .. "|" .. (ay + dy * step)] = true
    end
  end
  for key in pairs(anchors) do
    local x, y = key:match("^(-?%d+)|(-?%d+)$")
    x, y = tonumber(x), tonumber(y)
    if dirs[key].east then divide(x, y, 1, 0) end
    if dirs[key].south then divide(x, y, 0, 1) end
  end
  return piers
end

local function build(map)
  local layout = CommunityVisuals.layout()
  if layout == "default" then return false end
  local id = mapKey(map)
  local cells = (rawget(_G, "__bav_granite_pillars") or {})[id] or {}
  local bases = rawget(_G, "__bav_granite_pillar_base") or {}
  local vertices, indices, quads = {}, {}, 0

  local function box(mx, mz, base, hx, hz, y0, y1, v0, v1, shade, bevel)
    bevel = math.min(bevel or 0, math.min(hx, hz) * .18)
    local c = {
      { mx-hx+bevel,mz-hz }, { mx+hx-bevel,mz-hz },
      { mx+hx,mz-hz+bevel }, { mx+hx,mz+hz-bevel },
      { mx+hx-bevel,mz+hz }, { mx-hx+bevel,mz+hz },
      { mx-hx,mz+hz-bevel }, { mx-hx,mz-hz+bevel },
    }
    for i = 1, 8 do
      local a, b = c[i], c[i % 8 + 1]
      local diagonal = math.abs(b[1]-a[1]) > .001
        and math.abs(b[2]-a[2]) > .001
      local face = ((i <= 2 or i >= 7) and 1 or .84) * shade
        * (diagonal and .94 or 1)
      local u0, u1 = diagonal and .02 or 0, diagonal and .08 or 1
      vertices[#vertices+1] = { b[1],base+y1,b[2],u1,v0,face }
      vertices[#vertices+1] = { a[1],base+y1,a[2],u0,v0,face }
      vertices[#vertices+1] = { a[1],base+y0,a[2],u0,v1,face*.96 }
      vertices[#vertices+1] = { b[1],base+y0,b[2],u1,v1,face*.96 }
      Voxel3D.pushQuad(indices, quads); quads = quads + 1
    end
    -- Upward faces must never reuse the vertical strip that contains the
    -- recessed lantern. TEST4 let v0/v1 from the shaft flow across this fan;
    -- interpolation crossed the emissive mask and produced the glowing rings
    -- visible on every cap. Map the cap into a clean granite-only square.
    local capU0, capV0, capSpan = .08, .08, .30
    local function capUV(p)
      return capU0 + ((p[1] - (mx - hx)) / (hx * 2)) * capSpan,
             capV0 + ((p[2] - (mz - hz)) / (hz * 2)) * capSpan
    end
    local centerU, centerV = capU0 + capSpan * .5, capV0 + capSpan * .5
    for i = 1, 8 do
      local a, b = c[i], c[i % 8 + 1]
      local au, av = capUV(a)
      local bu, bv = capUV(b)
      vertices[#vertices+1] = { mx,base+y1,mz,centerU,centerV,shade*1.05 }
      vertices[#vertices+1] = { a[1],base+y1,a[2],au,av,shade*1.05 }
      vertices[#vertices+1] = { b[1],base+y1,b[2],bu,bv,shade*1.05 }
      vertices[#vertices+1] = { b[1],base+y1,b[2],bu,bv,shade*1.05 }
      Voxel3D.pushQuad(indices, quads); quads = quads + 1
    end
  end

  local function baseAt(cx, cy)
    return bases[id .. ":" .. (cx * 16 + 8) .. "|" .. (cy * 16 + 8)] or 0
  end

  local function pillar(cx, cy, scale, skipTop)
    scale = scale or 1.0
    local x, z, base = cx * 16 + 8, cy * 16 + 8, baseAt(cx, cy)
    box(x,z,base,4.25*scale,4.25*scale,.10,.26,.955,.98,.90,.25)
    box(x,z,base,4.31*scale,4.31*scale,.26,7.55,.08,.43,.98,.35)
    box(x,z,base,4.07*scale,4.07*scale,7.48,7.60,.43,.46,.86,.26)
    box(x,z,base,3.88*scale,3.88*scale,7.60,8.46,.47,.52,.64,.24)
    box(x,z,base,4.07*scale,4.07*scale,8.46,8.58,.53,.56,.86,.26)
    box(x,z,base,4.49*scale,4.49*scale,8.58,8.78,.58,.61,.93,.31)
    box(x,z,base,4.55*scale,4.55*scale,8.78,14.55,.62,.94,1.02,.38)
    if not skipTop then
      box(x,z,base,4.82*scale,4.82*scale,14.55,14.81,.94,.99,1.045,.42)
    end
  end

  local piers = layout == "bottom" and pierRhythm(cells) or nil
  local topScale = layout == "top" and 1.75 or 1.0
  for key in pairs(cells) do
    local cx, cy = key:match("^(-?%d+)|(-?%d+)$")
    cx, cy = tonumber(cx), tonumber(cy)
    if cx then
      local _, drawPier, d = wallRole(cx, cy, cells, piers)
      if layout ~= "bottom" or drawPier then pillar(cx, cy, topScale, layout == "top") end
      local base = baseAt(cx, cy)
      if layout == "bottom" then
        if d.east then
          local b = math.min(base, baseAt(cx + 1, cy))
          box(cx*16+16,cy*16+8,b,8.15,2.72,.10,6.10,.08,.43,.94,.18)
          box(cx*16+16,cy*16+8,b,8.28,3.02,6.10,6.48,.43,.46,1.02,.20)
        end
        if d.south then
          local b = math.min(base, baseAt(cx, cy + 1))
          box(cx*16+8,cy*16+16,b,2.72,8.15,.10,6.10,.08,.43,.94,.18)
          box(cx*16+8,cy*16+16,b,3.02,8.28,6.10,6.48,.43,.46,1.02,.20)
        end
      end
    end
  end
  if #vertices == 0 then return false end
  return Voxel3D.newMesh(vertices, indices)
end

function P.draw(map, ox, oz)
  if not map or not CommunityVisuals.customPillars() then return end
  local id = mapKey(map)
  local cells = (rawget(_G, "__bav_granite_pillars") or {})[id]
  if not cells then return end
  local count = 0
  for _ in pairs(cells) do count = count + 1 end
  local signature = table.concat({ count, CommunityVisuals.layout(),
                                   CommunityVisuals.pillarColor() }, "|")
  local record = P.cache[id]
  if not record or record.signature ~= signature then
    record = { signature = signature, mesh = build(map) }
    P.cache[id] = record
  end
  if not record.mesh then return end
  local oldMask = Voxel3D.glassMask
  Voxel3D.glassMaskNow(mask())
  Voxel3D.glass(true)
  Voxel3D.draw(record.mesh, texture(),
    (ox ~= 0 or oz ~= 0) and Mat4.translate(ox, 0, oz) or nil)
  Voxel3D.glass(false)
  Voxel3D.glassMaskNow(oldMask)
end

function P.invalidate()
  for _, record in pairs(P.cache) do
    if record.mesh and record.mesh.release then pcall(record.mesh.release, record.mesh) end
  end
  P.cache = {}
end

return P
