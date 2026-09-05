-- Compare old/new source-art geometry by exposed unit faces, permitting AO
-- segmentation changes but requiring identical volume, winding, facade tags
-- and sampled source texels. No private image data is included in this file.
local H=dofile('tests/astra_fixture.lua')
local inspect=assert(loadfile('tests/astra_building_contact_test.lua'))('helpers')
local baseline=assert(os.getenv('ASTRA_BASELINE'),'ASTRA_BASELINE required')
local candidate=os.getenv('ASTRA_CANDIDATE') or '.'
local data,w,h=H.atlas(assert(os.getenv('ASTRA_ATLAS'),'ASTRA_ATLAS required'))
local checks=0
local function ok(v,message)
  checks=checks+1
  if not v then error('FAIL '..message,0) end
end
local function equal(a,b,message)
  ok(a==b,message..' (expected '..tostring(b)..', got '..tostring(a)..')')
end
local function faceKey(a,d,p,b,c) return a..':'..d..':'..p..':'..b..':'..c end
local function direction(q,a)
  local u,v={},{}
  for j=1,3 do u[j]=q[2][j]-q[1][j];v[j]=q[3][j]-q[1][j] end
  local n={u[2]*v[3]-u[3]*v[2],u[3]*v[1]-u[1]*v[3],u[1]*v[2]-u[2]*v[1]}
  -- Preserve the baseline's actual winding, including its Y convention.
  return n[a]>0 and 1 or -1
end
local function texels(q,a,b,c)
  local out={}
  for _,db in ipairs({.25,.75}) do for _,dc in ipairs({.25,.75}) do
    out[#out+1]=math.floor(inspect.sample(q,a,b+db,c+dc,1)*w)
    out[#out+1]=math.floor(inspect.sample(q,a,b+db,c+dc,2)*h)
  end end
  return table.concat(out,',')
end
for _,id in ipairs({'gabled_house','oaks_lab','pokemart','pokecenter','flat_commercial','pokemon_tower','museum','route_2_gate'}) do
  local before=H.building(baseline,id,data,w,h)
  local after=H.building(candidate,id,data,w,h)
  equal(after.voxels,before.voxels,id..' occupied volume')
  equal(after.shell,before.shell,id..' shell count')
  local expected,unitFaces={},0
  for _,q in ipairs(before) do
    local a,p,b0,b1,c0,c1=inspect.face(q)
    local d=direction(q,a)
    for b=b0,b1-1 do for c=c0,c1-1 do
      local k=faceKey(a,d,p,b,c)
      ok(expected[k]==nil,id..' baseline has unique face coverage')
      expected[k]={texels=texels(q,a,b,c),facade=q.facade==true}
      unitFaces=unitFaces+1
    end end
  end
  local seen,changedShade={},0
  for _,q in ipairs(after) do
    if type(q.shade)=='table' then changedShade=changedShade+1 end
    local a,p,b0,b1,c0,c1=inspect.face(q)
    local d=direction(q,a)
    for b=b0,b1-1 do for c=c0,c1-1 do
      local k=faceKey(a,d,p,b,c)
      local original=expected[k]
      ok(original~=nil,id..' face location, extent and winding retained')
      ok(not seen[k],id..' no duplicate exposed face')
      seen[k]=true
      equal(texels(q,a,b,c),original.texels,id..' quarter-face samples retain source art')
      equal(q.facade==true,original.facade,id..' facade ownership retained')
    end end
  end
  for k in pairs(expected) do ok(seen[k],id..' no lost exposed face') end
  print(('%s: %d unit faces preserved; quads %d -> %d (%+.2f%%); %d shaded quads'):format(
    id,unitFaces,#before,#after,(#after/#before-1)*100,changedShade))
end
print(('%d checks passed (Astra source-art face coverage)'):format(checks))
