-- A small angled CRT case. Source pixels supply every material; planar
-- faces keep the authored 45-degree display from becoming vertical fins.
-- The occupancy proxy participates in ordinary culling/contact shading.
local ComputerCase = {}
function ComputerCase.build(sp, p, plane, put)
  local c, W = p.case, sp.W
  local n = math.floor((p.x[2] - p.x[1] + 1) / 2)
  local h = p.rows[2] - 2 * math.floor(n / 2) - p.rows[1] + 1
  local faces = {}
  local function tex(point)
    local i = point[2] * W + point[1]
    assert(sp.inside[i], "computer material must belong to its source art")
    return i
  end
  local shell, lid, bezel = tex(c.shell), tex(c.lid), tex(c.bezel)
  local black, cursor = tex(c.screen), tex(c.cursor)
  local function point(u, y, v)
    return { p.x[1] + u + v, plane + y, p.z + u - v }
  end
  local function face(a,b,d,e,i,shade)
    faces[#faces+1] = { point(unpack(a)), point(unpack(b)),
      point(unpack(d)), point(unpack(e)), source=i, shade=shade }
  end
  -- A conservative cell-centre proxy stays wholly inside the same diamond.
  for x=p.x[1],p.x[2] do for z=p.z-n,p.z+n-1 do
    local u=((x+0.5-p.x[1])+(z+0.5-p.z))/2
    local v=((x+0.5-p.x[1])-(z+0.5-p.z))/2
    if u>=0.5 and u<=n-0.5 and v>=0.5 and v<=n-0.5 then
      for y=0,h-1 do put(x,plane+y,z,shell) end
    end
  end end
  local function display(u,y)return u>=1 and u<n-1 and y>=2 and y<h-1 end
  local recess=0.3
  for u=0,n-1 do for y=0,h-1 do
    local screen=display(u,y)
    local v=screen and recess or 0
    local i=screen and black or (y==0 and black or bezel)
    if screen and u==n-2 and y==h-3 then i=cursor end
    face({u,y,v},{u+1,y,v},{u+1,y+1,v},{u,y+1,v},i,0.9)
    if screen then
      if not display(u-1,y)then face({u,y,0},{u,y,recess},{u,y+1,recess},{u,y+1,0},bezel,0.78)end
      if not display(u+1,y)then face({u+1,y,recess},{u+1,y,0},{u+1,y+1,0},{u+1,y+1,recess},bezel,0.78)end
      if not display(u,y-1)then face({u,y,0},{u+1,y,0},{u+1,y,recess},{u,y,recess},bezel,0.95)end
      if not display(u,y+1)then face({u,y+1,recess},{u+1,y+1,recess},{u+1,y+1,0},{u,y+1,0},bezel,0.68)end
    end
    face({u+1,y,n},{u,y,n},{u,y+1,n},{u+1,y+1,n},shell,0.68)
  end end
  for v=0,n-1 do for y=0,h-1 do
    face({0,y,v+1},{0,y,v},{0,y+1,v},{0,y+1,v+1},shell,0.68)
    face({n,y,v},{n,y,v+1},{n,y+1,v+1},{n,y+1,v},shell,0.78)
  end end
  for u=0,n-1 do for v=0,n-1 do
    face({u,h,v},{u+1,h,v},{u+1,h,v+1},{u,h,v+1},lid,0.95)
  end end
  return faces,plane+h-1
end
return ComputerCase
