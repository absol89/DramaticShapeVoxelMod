-- Cave warp ladders use only their original rails/rungs. The map's floor
-- remains the actor/warp datum; a raised shaft rim is visual geometry only.
local V=...
local Shape=V.require('TileShape')
local Budget=V.require('BuildBudget')
local M={}
local function key(x,z)return(z+64)*4096+x+64 end
local neighbors={{0,-1},{1,0},{0,1},{-1,0}}
function M.rim(map,cx,cy)
  local shapes=Shape.forMap(map)
  local shelf,zero
  for _,d in ipairs(neighbors)do
    local x,z=cx+d[1],cy+d[2]
    if map:inBounds(x,z) and map:isWalkableCell(x,z)then
      local tile=map:cellTile(x,z);local s=shapes[tile]
      if s and s.class=='ground' and s.h==0 then return 0,tile end
      if s and s.art=='stair' then zero=true end
      if s and s.class=='ledge' and s.h==6 then shelf=shelf or tile end
    end
  end
  if zero then return 0,32 end
  return shelf and 6 or 0,shelf or 32
end
local function bands(a,b)
  local out={}
  while a<b do local n=math.min(b,(math.floor(a/8)+1)*8);out[#out+1]={a,n};a=n end
  return out
end
function M.build(S,map,data,cx,cy,s)
  assert(s.class=='ladder_up' or s.class=='ladder_down','cave ladder class')
  local down=s.class=='ladder_down'
  local rim,donor=M.rim(map,cx,cy)
  local mx,mz=cx*16,cy*16
  local aw,ah=map.tileset.imageWidth or 128,map.tileset.imageHeight or 40
  local perRow=map.tileset.tilesPerRow or 16
  local materials={}
  local function texel(tile,x,y)
    local id=tile*64+y*8+x
    if not materials[id]then materials[id]={((tile%perRow)*8+x+.5)/aw,(math.floor(tile/perRow)*8+y+.5)/ah}end
    return id
  end
  local function source(x,y)
    local tile=assert(S.tileAt[key(cx*2+math.floor(x/8),cy*2+math.floor(y/8))])
    return texel(tile,x%8,y%8)
  end
  local black=source(3,4)
  local function point(a,b,c)return{mx+a,b,mz+c}end
  local function face(points,material,shade,role)
    local uv=assert(materials[material])
    local q={points[1],points[2],points[3],points[4],uv={uv,uv,uv,uv},shade=shade,caveLadderRole=role}
    S.objectQuads[#S.objectQuads+1]=q
    Budget.tick()
  end
  -- All plane rectangles split at the world curvature's eight-pixel grid.
  -- The winding matches Structures' existing top and side face convention.
  local function plane(axis,at,a0,a1,b0,b1,positive,material,shade,role)
    for _,aa in ipairs(bands(a0,a1))do for _,bb in ipairs(bands(b0,b1))do
      local a,b,c,d=aa[1],aa[2],bb[1],bb[2]
      local p
      if axis==1 then p={point(at,c,a),point(at,c,b),point(at,d,b),point(at,d,a)}
      elseif axis==2 then p={point(a,at,c),point(b,at,c),point(b,at,d),point(a,at,d)}
      else p={point(a,c,at),point(b,c,at),point(b,d,at),point(a,d,at)}end
      -- Default x faces west, y faces up, z faces south.
      local reverse=(axis==1 and positive)or(axis==2 and not positive)or(axis==3 and not positive)
      if reverse then p={p[2],p[1],p[4],p[3]}end
      face(p,material,shade,role)
    end end
  end
  if down then
    -- A real floor texel frames the mouth; no ladder/background pixels
    -- become floor. The center is never capped by Structures' ground fill.
    local floor=texel(donor,3,3)
    plane(2,rim,0,16,0,2,true,floor,1,'rim')
    plane(2,rim,0,16,14,16,true,floor,1,'rim')
    plane(2,rim,0,2,2,14,true,floor,1,'rim')
    plane(2,rim,14,16,2,14,true,floor,1,'rim')
    plane(1,2,2,14,-16,rim,true,black,.7,'shaft-west')
    plane(1,14,2,14,-16,rim,false,black,.7,'shaft-east')
    plane(3,2,2,14,-16,rim,true,black,.85,'shaft-north')
    plane(3,14,2,14,-16,rim,false,black,.55,'shaft-south')
    plane(2,-16,2,14,2,14,true,black,.4,'shaft-bottom')
    if rim>0 then
      plane(1,0,0,16,0,rim,false,floor,.78,'rim-outer')
      plane(1,16,0,16,0,rim,true,floor,.68,'rim-outer')
      plane(3,0,0,16,0,rim,false,floor,.68,'rim-outer')
      plane(3,16,0,16,0,rim,true,floor,.82,'rim-outer')
    end
  end
  -- Occupied one-pixel blocks describe the rails/rungs, then equal-material
  -- exposed faces merge. No internal faces or background-filled slab remains.
  local cells={};local ordered={}
  local function voxelKey(x,y,z)return x..','..y..','..z end
  local function fill(x0,x1,y0,y1,z0,z1,material,role)
    for y=y0,y1-1 do for z=z0,z1-1 do for x=x0,x1-1 do
      local k=voxelKey(x,y,z)
      if not cells[k]then ordered[#ordered+1]={x,y,z}end
      cells[k]={material=material,role=role}
    end end end
  end
  local z0=down and 3 or 6
  local bottom,top=down and -16 or 0,down and rim+2 or 16
  for y=bottom,top-1 do
    local sourceRow=down and (y< -8 and 9 or 2)or(y<4 and 11 or(y<8 and 9 or 2))
    fill(3,4,y,y+1,z0,z0+2,black,'rail')
    fill(4,5,y,y+1,z0,z0+2,source(4,sourceRow),'rail')
    fill(11,12,y,y+1,z0,z0+2,source(11,sourceRow),'rail')
    fill(12,13,y,y+1,z0,z0+2,black,'rail')
  end
  local rungs=down and {{-11,10},{-7,7},{-3,4}}or{{2,10},{6,7},{10,4},{14,1}}
  for _,r in ipairs(rungs)do for x=5,10 do fill(x,x+1,r[1],r[1]+1,z0,z0+2,source(x,r[2]),'rung')end end
  local dirs={{1,-1,.78},{1,1,.68},{2,-1,.6},{2,1,1},{3,-1,.68},{3,1,.9}}
  for _,dir in ipairs(dirs)do
    local axis,sign,shade=dir[1],dir[2],dir[3]
    local slices={};local sliceKeys={}
    for _,p in ipairs(ordered)do
      local q={p[1],p[2],p[3]};q[axis]=q[axis]+sign
      if not cells[voxelKey(q[1],q[2],q[3])]then
        local cell=cells[voxelKey(p[1],p[2],p[3])]
        local at=p[axis]+(sign>0 and 1 or 0)
        local a,b
        if axis==1 then a,b=p[3],p[2]elseif axis==2 then a,b=p[1],p[3]else a,b=p[1],p[2]end
        if not slices[at]then slices[at]={};sliceKeys[#sliceKeys+1]=at end
        slices[at][a..','..b]={a=a,b=b,material=cell.material,role=cell.role}
      end
    end
    table.sort(sliceKeys)
    for _,at in ipairs(sliceKeys)do
      local grid=slices[at]
      for b=-16,23 do for a=0,15 do
        local c=grid[a..','..b]
        if c then
          local a1=a+1
          while a1<16 do local n=grid[a1..','..b];if not n or n.material~=c.material or n.role~=c.role then break end;a1=a1+1 end
          local b1=b+1
          while b1<24 do
            local match=true
            for aa=a,a1-1 do local n=grid[aa..','..b1];if not n or n.material~=c.material or n.role~=c.role then match=false;break end end
            if not match then break end;b1=b1+1
          end
          for bb=b,b1-1 do for aa=a,a1-1 do grid[aa..','..bb]=nil end end
          plane(axis,at,a,a1,b,b1,sign>0,c.material,shade,c.role)
        end
      end end
    end
    Budget.tick()
  end
end
return M
