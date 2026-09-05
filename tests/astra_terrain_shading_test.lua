-- Detailed Legendary materials keep one continuous ambient-light field.
-- ROM/GPU-free: luajit tests/astra_terrain_shading_test.lua
-- Optional ASTRA_BASELINE proves positions, UVs and indices are unchanged.
local root = os.getenv('ASTRA_MOD_ROOT') or '.'
local checks, failures = 0, 0
local function check(ok, name)
  checks = checks + 1
  if not ok then failures = failures + 1; print('FAIL ' .. name) end
end
local function near(a, b) return math.abs(a - b) < 1e-9 end
local function key(x, z) return (z + 64) * 4096 + x + 64 end
local analysis
local enabled = true
package.loaded['src.render.Assets'] = { register = function() end }
local directionShade = { [1]=.84, [2]=.72, [3]=1, [4]=.55, [5]=.9, [6]=.68 }
local modules = {
  Structures = { forMap = function() return analysis end },
  TileShape = {}, BuildBudget = { tick = function() end }, VoxelMeshDisk = {},
  Voxel3D = {
    FACE_SHADE = directionShade,
    pushQuad = function(indices, n)
      for _, i in ipairs({1, 2, 3, 1, 3, 4}) do indices[#indices + 1] = n * 4 + i end
    end,
  },
  CommunityVisuals = {
    customWalls=function() return enabled end,
    customRoads=function() return enabled end,
    customCourtyards=function() return enabled end,
    customGrass=function() return enabled end,
  },
}
local function loadMesher(path)
  return assert(loadfile(path .. '/lib/ChunkMesher.lua'))({
    require=function(n) return assert(modules[n], n) end,
  })
end
local C = loadMesher(root)
local baselineRoot = os.getenv('ASTRA_BASELINE')
local baseline = baselineRoot and loadMesher(baselineRoot)
local map = {
  id='ASTRA_TERRAIN_SHADE', def={width=1, height=1},
  tileset={id='OVERWORLD', tilesPerRow=16, imageWidth=128, imageHeight=48},
  tileAt=function(_,x,z) return analysis.tileAt[key(x,z)] or 90 end,
}
local function reset()
  analysis={shapeAt={},tileAt={},runs={},skip={},ground={},doorFold={},
            objectQuads={},roundStamps={}}
end
local function cell(x,z,h,class,tile)
  analysis.shapeAt[key(x,z)]={h=h,class=class,art='top',flat=h==0}
  analysis.tileAt[key(x,z)]=tile
end
local function geometry(label)
  local verts, indices, quads = C.geometry(map, true)
  if baseline then
    local bv, bi, bq = baseline.geometry(map, true)
    local same = #verts==#bv and #indices==#bi and quads==bq
    for i,v in ipairs(verts) do
      for j=1,5 do if not bv[i] or v[j]~=bv[i][j] then same=false end end
      if not enabled and (not bv[i] or v[6]~=bv[i][6]) then same=false end
    end
    for i,v in ipairs(indices) do if v~=bi[i] then same=false end end
    check(same,label .. ': positions, UVs, topology and default shades preserved')
  end
  return verts
end
-- Access the actual production helper without adding a public test API.
local function upvalue(fn, name)
  for i=1,100 do
    local n,v = debug.getupvalue(fn,i)
    if not n then break end
    if n==name then return v end
  end
end
local runGeometry = assert(upvalue(C.geometry,'runGeometry'))
local shadeRect = upvalue(runGeometry,'shadeRect')
check(type(shadeRect)=='function','production subface sampler is reachable')
if shadeRect then
  local shade={.2,.6,1,.8}
  local whole={{8,0,16},{16,0,16},{16,0,24},{8,0,24}}
  local a=shadeRect(whole,shade,1,8,16,3,16,24,1)
  local exact=true
  for i=1,4 do exact=exact and near(a[i],shade[i]) end
  check(exact,'a whole face retains all four parent corner shades')
  local child={{10,0,18},{14,0,18},{14,0,22},{10,0,22}}
  local b=shadeRect(child,shade,1,8,16,3,16,24,1)
  local expected={.4375,.6125,.8375,.7125}
  exact=true
  for i=1,4 do exact=exact and near(b[i],expected[i]) end
  check(exact,'a cropped face samples the parent bilinear field')
  check(shadeRect(child,.73,1,8,16,3,16,24,.8)==.73*.8,
        'uniform light retains the scalar allocation-free path')
  local side={{8,2,0},{16,2,0},{16,6,0},{8,6,0}}
  local north=shadeRect(side,{.2,.6,1,.8},1,16,8,2,0,8,1)
  check(near(north[1],.7) and near(north[2],.35)
      and near(north[3],.65) and near(north[4],.9),
      'north-side light follows its reversed physical axis')
  for _,v in ipairs(side) do v[3],v[1]=v[1],0 end
  local east=shadeRect(side,{.2,.6,1,.8},3,16,8,2,0,8,1)
  exact=true
  for i=1,4 do exact=exact and near(east[i],north[i]) end
  check(exact,'east-side light follows its reversed physical axis')
end
-- Expected light at a physical point, expressed as independent corner weights.
local function expected(shades,u,v)
  return shades[1]*(1-u)*(1-v)+shades[2]*u*(1-v)
       + shades[3]*u*v+shades[4]*(1-u)*v
end
local function checkField(q, field)
  local tone=q[1][6]/field(q[1])
  for i=2,4 do if not near(q[i][6],field(q[i])*tone) then return false end end
  return true
end
-- A north-west corner crowds the tile. Every stone/board should inherit
-- light at its own location; distant rows must not restart the dark seam.
for _,spec in ipairs({
  {'ledge',6,'ledge',13,.12},
  {'retaining',16,'wall',17,.12},
  {'courtyard',0,'ground',91,.025},
  {'timber',0,'ground',60,.06},
}) do
  reset()
  local label,h,class,tile,lift=unpack(spec)
  cell(1,1,h,class,tile)
  cell(0,1,32,'wall',90)
  cell(1,0,32,'wall',90)
  local verts=geometry(label .. ' top')
  -- AO counts west+north at NW, north at NE, none at SE, west at SW.
  local parent={.568,.784,1,.784}
  local count,correct=0,true
  for i=1,#verts,4 do
    local q={verts[i],verts[i+1],verts[i+2],verts[i+3]}
    local inside=true
    for _,v in ipairs(q) do
      inside=inside and v[1]>=8 and v[1]<=16 and v[3]>=8 and v[3]<=16
        and (near(v[2],h+lift) or (label=='timber' and near(v[2],h+.065)))
    end
    if inside then
      count=count+1
      correct=correct and checkField(q,function(v)
        return expected(parent,(v[1]-8)/8,(v[3]-8)/8)
      end)
    end
  end
  check(count>1,label .. ': fixture includes multiple detail faces')
  check(correct,label .. ': detail faces share the full-tile AO field')
end
-- Side seams use a single high lateral neighbour. Front faces and bevels
-- must all sample the same field, including north/east's reverse order.
local lateral={ [1]={0,1}, [2]={0,-1}, [5]={-1,0}, [6]={1,0} }
for _,class in ipairs({'ledge','wall'}) do
  for _,d in ipairs({1,2,5,6}) do
    reset()
    local h=class=='ledge' and 6 or 16
    local depth=class=='ledge' and .30 or .28
    cell(1,1,h,class,class=='ledge' and 13 or 17)
    local lat=lateral[d]
    cell(1+lat[1],1+lat[2],32,'wall',90)
    local verts=geometry(class .. ' side ' .. d)
    local bandTop=math.min(8,h)
    local parent={.664*.664,.664,1,.664}
    local tangent=(d==5 or d==6) and 1 or 3
    local normal=tangent==1 and 3 or 1
    local plane=(d==1 or d==5) and 16 or 8
    local sign=(d==1 or d==5) and 1 or -1
    local count,correct=0,true
    for i=1,#verts,4 do
      local q={verts[i],verts[i+1],verts[i+2],verts[i+3]}
      local inside,center=true,0
      for _,v in ipairs(q) do
        local out=(v[normal]-plane)*sign
        inside=inside and out>=-1e-9 and out<=depth+1e-9
          and v[tangent]>=8 and v[tangent]<=16
          and v[2]>=0 and v[2]<=bandTop
        center=center+v[tangent]/4
      end
      if inside and center>8 and center<16 then
        count=count+1
        correct=correct and checkField(q,function(v)
          local u=(v[tangent]-8)/8
          if d==1 or d==6 then u=1-u end
          return expected(parent,u,v[2]/bandTop)
        end)
      end
    end
    check(count>4,class .. ': detailed side fixture ' .. d)
    check(correct,class .. ': side/bevel field and corner order ' .. d)
  end
end
-- Disabled Legendary styles retain the original terrain data exactly.
enabled=false
geometry('default Battle Art')
-- Prebuilt building/prop corner shades compose with contact light. The
-- negative facade marker and caller-owned shade tables must survive both
-- the multiply and later reuse of the mesher's scratch corner array.
reset()
local sourceShades={-.9,-.6,-.4,-.8}
analysis.objectQuads={
  {{8,0,16},{16,0,16},{16,6,16},{8,6,16},u=.5,v=.5,shade=sourceShades,own=true},
  {{20,3,16},{28,3,16},{28,6,16},{20,6,16},u=.5,v=.5,shade={.7,.8,.9,1},own=true},
}
local composed=C.geometry(map,true)
check(#composed==8,'composition fixture emits both prop quads')
check(near(composed[1][6],-.9*.712) and near(composed[2][6],-.6*.712)
    and near(composed[3][6],-.4) and near(composed[4][6],-.8),
    'contact shade composes per corner and preserves negative facade markers')
check(near(composed[5][6],.7*.856) and near(composed[6][6],.8*.856)
    and near(composed[7][6],.9) and near(composed[8][6],1),
    'the next scratch shade field cannot overwrite earlier vertices')
check(sourceShades[1]==-.9 and sourceShades[2]==-.6
    and sourceShades[3]==-.4 and sourceShades[4]==-.8,
    'caller-owned per-corner model shades remain immutable')
print(('Astra terrain shading: %d checks, %d failures'):format(checks,failures))
if failures>0 then os.exit(1) end
