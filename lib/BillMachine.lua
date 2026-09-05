-- Bill's cell separator: an opt-in model of its original cylindrical
-- chamber drawing. This module only supplies voxel/source-texel geometry;
-- the existing Buildings emitter owns meshing, shading and atlas sampling.
local V = ...
local Budget = V.require("BuildBudget")
local Machine = {}

function Machine.model(sp, pr, t)
  assert(sp.W == 32 and sp.H == 40, "Bill chamber source must be 32x40")
  local W, D, center = 32, 40, 15.5
  local vox = {}
  local function key(x,y,z) return (y * D + z) * W + x end
  local function pixel(x,y) return y * W + x end
  local function put(x,y,z,i) vox[key(x,y,z)] = i end
  local function round(v) return math.floor(v + 0.5) end
  -- Donors are deliberately inside the original machine, never the room
  -- stripes above it or the white floor outside its lower curve.
  local grey, dark, black = pixel(7,21), pixel(2,16), pixel(0,16)
  assert(sp.col[grey] == 1 and sp.col[dark] == 2 and sp.col[black] == 3)
  local function disk(x,z,r)
    return (x-center)^2 + (z-center)^2 <= r*r
  end
  local function edge(x,z,r)
    return not disk(x-1,z,r) or not disk(x+1,z,r)
        or not disk(x,z-1,r) or not disk(x,z+1,r)
  end
  -- The first 21 source rows describe the top ellipse. Its closing arc
  -- runs inside the body drawing, so the whole-sprite flood cannot find
  -- it. These bounds follow that explicitly drawn arc, including its
  -- asymmetric raster steps, before lifting it into a circular plan.
  local cap = {
    {12,19},{9,22},{6,25},{4,27},{3,28},{2,29},{1,30},
    {1,30},{0,31},{0,31},{0,31},{0,31},{0,31},{1,30},
    {1,30},{2,29},{3,28},{5,26},{7,24},{9,22},{12,19},
  }
  local function capPixel(x,z)
    local sy = round(z * 20 / 31)
    -- Resolve a raster mismatch toward the ellipse interior, without
    -- copying pipe/background pixels onto the physical lid's corners.
    while x < cap[sy+1][1] or x > cap[sy+1][2] do
      sy = sy < 10 and sy+1 or sy-1
    end
    return pixel(x,sy)
  end
  local bodyFirst, bodyLast = {}, {}
  local baseArc = { {0,31},{1,30},{1,30},{2,29},{3,28},
                    {4,27},{6,25},{9,22},{12,19} }
  for sx=0,31 do
    for sy=0,20 do
      if sx>=cap[sy+1][1] and sx<=cap[sy+1][2] then bodyFirst[sx]=sy+1 end
    end
    for n,span in ipairs(baseArc) do
      if sx>=span[1] and sx<=span[2] then bodyLast[sx]=30+n end
    end
  end
  local function bodyRow(sx,y)
    -- The top ellipse must never reappear on the vertical barrel. Every
    -- source column begins BELOW its closing cap arc and ends at its own
    -- lower silhouette; only this vertical body band is rescaled.
    return round(bodyFirst[sx] + (bodyLast[sx]-bodyFirst[sx])*(29-y)/26)
  end
  local function bodyPixel(x,y,z)
    if z < center then
      -- The back is hidden in the source; continue its own clean metal
      -- field instead of repeating the front latch on the rear shell.
      return (y == 3 or y == 29) and dark or grey
    end
    local sx = math.max(0,math.min(31,round((x-2)*31/27)))
    local sy = bodyRow(sx,y)
    return pixel(sx,sy)
  end
  -- The source's lower ellipse describes a foot in plan, not a tall
  -- taper. A shallow dark plinth and a smaller barrel leave a two-pixel
  -- mounting lip; the original drawing's full 32px plot and height stay.
  for z=0,31 do
    Budget.tick()
    for x=0,31 do
      if disk(x,z,16) then
        for y=0,2 do
          put(x,y,z+8,(y==0 or edge(x,z,16)) and black or dark)
        end
      end
      if disk(x,z,14) then
        for y=3,29 do put(x,y,z+8,bodyPixel(x,y,z)) end
      end
      if disk(x,z,16) then
        local rim=edge(x,z,16)
        local i=rim and black or capPixel(x,z)
        put(x,30,z+8,i)
        local hatch=(x-center)^2+(z-12)^2 <= 25
        if (x-center)^2+(z-center)^2 >= 14*14 or hatch then
          put(x,31,z+8,i)
        end
      end
    end
  end
  -- The source's front control/latch occupies rows21..29 and columns
  -- 11..20. Give its framed silhouette two pixels of mechanical relief,
  -- clipped inside the original plinth footprint and away from the exit.
  local panel = { [21]={13,18},[22]={12,19},[23]={11,20},
    [24]={11,20},[25]={11,20},[26]={11,20},[27]={11,20},
    [28]={12,19},[29]={13,18} }
  for x=2,29 do
    local front
    for z=0,31 do if disk(x,z,14) then front=z end end
    if front then
      local sx=math.max(0,math.min(31,round((x-2)*31/27)))
      for y=3,29 do
        local sy=bodyRow(sx,y)
        local span=panel[sy]
        if span and sx>=span[1] and sx<=span[2] then
          for dz=1,2 do
            local z=front+dz
            if z<=31 and disk(x,z,16) then put(x,y,z+8,pixel(sx,sy)) end
          end
        end
      end
    end
  end
  -- The original dark lower hatch implies front access; its unseen
  -- depth is authored as a recess. Keep the existing 16px Bill sprite
  -- visible at scripted local (16,32) and let him walk onto flat ground.
  -- This is visual clearance only: map collision and scripts stay intact.
  for x=8,23 do
    for y=0,17 do
      for z=31,39 do vox[key(x,y,z)] = nil end
      put(x,y,30,dark)
    end
  end
  return { at=function(x,y,z)
      if x<0 or x>=W or y<0 or y>31 or z<0 or z>=D then return nil end
      return vox[key(x,y,z)]
    end, W=W, ytop=31, zmin=0, zmax=D-1 }
end
return Machine
