-- Complete FACILITY palm, retaining the original five-pixel standee depth.
-- The source pot has disconnected contour bands. They share one ground line;
-- anchoring each component separately collapses the bands onto one another.
local V = ...
local Budget = V.require("BuildBudget")
local M = {}

function M.model(sp, pr, t)
  local W, H = sp.W, sp.H
  assert(W == 16 and H == 32, "FACILITY palm requires its complete 16x32 drawing")
  -- Match the original prop's outline flood. All three nonblack shades touch
  -- this drawing's boundary; only their boundary-connected pixels are floor.
  -- Keep enclosed leaf colours and each original pot contour unchanged.
  local outside, queue = {}, {}
  local function seed(x, y)
    local i = y * W + x
    if not outside[i] and sp.col[i] ~= 3 then
      outside[i] = true
      queue[#queue + 1] = i
    end
  end
  for x = 0, W - 1 do seed(x, 0); seed(x, H - 1) end
  for y = 0, H - 1 do seed(0, y); seed(W - 1, y) end
  while #queue > 0 do
    Budget.tick()
    local i = table.remove(queue)
    local x, y = i % W, math.floor(i / W)
    if x > 0 then seed(x - 1, y) end
    if x + 1 < W then seed(x + 1, y) end
    if y > 0 then seed(x, y - 1) end
    if y + 1 < H then seed(x, y + 1) end
  end
  local last = -1
  for y = 0, H - 1 do
    Budget.tick()
    for x = 0, W - 1 do
      if not outside[y * W + x] then last = y end
    end
  end
  assert(last >= 0, "FACILITY palm source has no visible silhouette")
  -- Same depth band as the original component whose foot is in the last tile:
  -- floor(last/8)*8 + (8-5)/2. Half-pixel boundaries keep its original centre.
  local zmin = math.floor(last / 8) * 8 + 1.5
  local zmax = zmin + 4
  return {
    W = W, ytop = last, zmin = zmin, zmax = zmax,
    at = function(x, y, z)
      if x < 0 or x >= W or x % 1 ~= 0 or y < 0 or y > last
          or y % 1 ~= 0 or z < zmin or z > zmax or (z - zmin) % 1 ~= 0 then
        return nil
      end
      local i = (last - y) * W + x
      if not outside[i] then return i end
    end,
  }
end

return M
