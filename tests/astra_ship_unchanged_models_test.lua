-- Full-pass additions preserve every previously accepted authored model.
-- Compare every A15 furniture/pipe template, including the LAB seats/desk, computers/transporters
-- and GYM/MART aliases, plus the SHIP round stool and eight exterior meshes.
local candidate=os.getenv('ASTRA_CANDIDATE') or '.'
local baseline=assert(os.getenv('ASTRA_PALLET_BASELINE'),'immutable A17 preservation baseline required')
local atlasDir=assert(os.getenv('ASTRA_FURNITURE_ATLASES'))
local H=dofile(candidate..'/tests/astra_fixture.lua')
local spec=dofile(baseline..'/data/voxel_heights.lua')
local checks=0
local function same(a,b,path)
  checks=checks+1
  assert(type(a)==type(b),'type changed: '..path)
  if type(a)~='table' then assert(a==b,'value changed: '..path);return end
  for k,v in pairs(a)do same(v,b[k],path..'.'..tostring(k))end
  for k in pairs(b)do assert(a[k]~=nil,'extra field: '..path..'.'..tostring(k))end
end
local families={{'HOUSE','house'},{'REDS_HOUSE_1','reds_house'},{'DOJO','gym'},
  {'INTERIOR','interior'},{'POKECENTER','pokecenter'},{'MANSION','mansion'},{'CLUB','club'},
  {'GYM','gym'},{'MART','pokecenter'},{'LAB','lab'},
  {'LOBBY','lobby'},{'MUSEUM','gate'},{'BEACH_HOUSE','beach_house'}}
local n=0
for _,f in ipairs(families)do
  local extra=f[1]=='LOBBY'or f[1]=='MUSEUM'or f[1]=='BEACH_HOUSE'
  local dir=extra and assert(os.getenv('ASTRA_FULL_ATLASES'))or atlasDir
  local data,w,h=H.atlas(dir..'/'..f[2]..'.rgba')
  for _,t in ipairs(spec.buildings[f[1]])do if not t.claimOnly and not(f[1]=='DOJO'and(t.id=='lab_table'or t.id=='lab_table_small'or t.id=='lab_computers'))then
    local name=f[1]..'/'..t.id
      same(H.building(candidate,t.id,data,w,h,nil,nil,f[1]),
        H.building(baseline,t.id,data,w,h,nil,nil,f[1]),name)
      n=n+1
  end end
end
assert(n==33,'must cover all33 unchanged A17 models and aliases outside the three newly tested Oak tables')
local ship,w,h=H.atlas(assert(os.getenv('ASTRA_SHIP_ATLAS')))
same(H.building(candidate,'ship_stool',ship,w,h,nil,nil,'SHIP'),
  H.building(baseline,'ship_stool',ship,w,h,nil,nil,'SHIP'),'accepted A10 round stool')
local data,w,h=H.atlas(assert(os.getenv('ASTRA_ATLAS')))
for _,id in ipairs({'gabled_house','oaks_lab','pokemart','pokecenter','flat_commercial','pokemon_tower','museum','route_2_gate'})do
  same(H.building(candidate,id,data,w,h),H.building(baseline,id,data,w,h),id)
end
print(('%d exact-value comparisons passed: 33 accepted A17 furniture/aliases/pipes, accepted round stool, and8 exterior meshes unchanged'):format(checks))
