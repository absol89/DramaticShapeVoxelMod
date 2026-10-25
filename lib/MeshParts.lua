-- A non-owning view of disjoint meshes. BODY is shared with neighbours;
-- the current map adds only its border RING. GPU ownership stays with the
-- mesher slots, so dropping a view must never release either component.
local M = {}
local views = setmetatable({}, {__mode = 'k'})
local methods = {}
function methods:getVertexCount()
  local n = 0
  for _, mesh in ipairs(views[self]) do n = n + mesh:getVertexCount() end
  return n
end
function M.parts(mesh) return views[mesh] end
function M.join(a, b, prior)
  if not a then return b or nil end
  if not b or a == b then return a end
  local parts = prior and views[prior]
  if parts and parts[1] == a and parts[2] == b then return prior end
  local view = setmetatable({}, {__index = methods})
  views[view] = {a, b}
  return view
end
return M
