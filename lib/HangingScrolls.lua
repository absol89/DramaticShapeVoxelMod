-- Two source-authored scrolls hang on the north wall of Oak's Lab / Dojo.
-- Their paper and rolled ends are shallow relief, never floor-colored slabs.
-- This follows Structures' mounted-object contract: up to two pixels proud
-- of the wall, with the original 2x2 source claim and engine collision intact.
local V=...
local Budget=V.require('BuildBudget')
local M={}
local targets={OAKS_LAB=true,FIGHTING_DOJO=true}
local tiles={{52,67},{82,83}}
local function key(x,z)return(z+64)*4096+x+64 end
function M.matches(map,tx,ty)
  if not targets[map.id] or map.tileset.id~='DOJO' then return false end
  for y=0,1 do for x=0,1 do
    if map:tileAt(tx+x,ty+y)~=tiles[y+1][x+1] then return false end
  end end
  return true
end
-- Mask measured from the original four tiles. Rows14/15 are wall trim,
-- and the gray pixels beside the lower roll are wall decoration/shadow.
function M.depth(x,row)
  if x<1 or x>14 or row<0 or row>13 then return 0 end
  if row<=2 then return row==1 and 2 or 1 end
  if row>=11 then return row==12 and 2 or 1 end
  return x>=2 and x<=13 and .75 or 0
end
local function buildAt(S,map,tx,ty)
  local W,H=map.tileset.imageWidth or 128,map.tileset.imageHeight or 48
  local per=map.tileset.tilesPerRow or 16
  local mx,mz=tx*8,ty*8
  local function uv(tile,x,y)
    return {((tile%per)*8+x+.5)/W,(math.floor(tile/per)*8+y+.5)/H}
  end
  local function source(x,row)
    if M.depth(x,row)>0 then return uv(tiles[math.floor(row/8)+1][math.floor(x/8)+1],x%8,row%8) end
    return uv(row<8 and 5 or 16,x%8,row%8)
  end
  local function face(axis,at,a0,a1,b0,b1,positive,tex,shade,role)
    local function p(x,y,z)return{mx+x,y,mz+z}end
    local q
    if axis==1 then q={p(at,b0,a0),p(at,b0,a1),p(at,b1,a1),p(at,b1,a0)}
    elseif axis==2 then q={p(a0,at,b0),p(a1,at,b0),p(a1,at,b1),p(a0,at,b1)}
    else q={p(a0,b0,at),p(a1,b0,at),p(a1,b1,at),p(a0,b1,at)}end
    if (axis==1 and positive)or(axis==2 and not positive)or(axis==3 and not positive)then q={q[2],q[1],q[4],q[3]}end
    q.uv={tex,tex,tex,tex};q.shade=shade;q.hangingScrollRole=role
    S.objectQuads[#S.objectQuads+1]=q;Budget.tick()
  end
  -- Complete backing, split at the existing 8px curvature lattice. No
  -- scroll texel can reach a rear, side or top face of this wall block.
  for a=0,8,8 do for b=0,8,8 do
    face(2,16,a,a+8,b,b+8,true,uv(5,3,3),.95,'wall-cap')
    face(3,0,a,a+8,b,b+8,false,uv(5,3,3),.68,'wall-back')
    face(1,0,a,a+8,b,b+8,false,uv(5,3,3),.78,'wall-side')
    face(1,16,a,a+8,b,b+8,true,uv(5,3,3),.68,'wall-side')
  end end
  for row=0,15 do for x=0,15 do
    local dep=M.depth(x,row);local tex=source(x,row)
    local y=15-row
    face(3,16+dep,x,x+1,y,y+1,true,tex,1,dep>0 and 'scroll-front' or 'wall-front')
    if dep>0 then
      for _,d in ipairs({{-1,0},{1,0},{0,-1},{0,1}})do
        local other=M.depth(x+d[1],row+d[2])
        if other<dep then
          if d[1]~=0 then face(1,x+(d[1]>0 and 1 or 0),16+other,16+dep,y,y+1,d[1]>0,tex,.78,'scroll-edge')
          else face(2,y+(d[2]<0 and 1 or 0),x,x+1,16+other,16+dep,d[2]<0,tex,d[2]<0 and .95 or .68,'scroll-edge')end
        end
      end
    end
  end end
  for y=0,1 do for x=0,1 do local k=key(tx+x,ty+y)
    -- Claim the same art cells as Buildings does. A fresh authored shape
    -- prevents Dojo's unauthored-region pass from redetecting the scroll.
    S.shapeAt[k]={class='wall',h=16,art='upright',flat=false,authored=true}
    S.skip[k]=true
  end end
end
function M.build(S,map)
  if not targets[map.id] or map.tileset.id~='DOJO' then return 0 end
  local count=0
  for ty=0,map.def.height*4-2 do for tx=0,map.def.width*4-2 do
    local claimed=false
    for y=0,1 do for x=0,1 do if S.skip[key(tx+x,ty+y)]then claimed=true end end end
    if not claimed and M.matches(map,tx,ty) then
      buildAt(S,map,tx,ty);count=count+1
    end
  end end
  return count
end
return M
