local H=dofile('tests/astra_fixture.lua')
local baseline=assert(os.getenv('ASTRA_BASELINE'),'ASTRA_BASELINE required')
local checks=0
local function equal(a,b,label)
  checks=checks+1; assert(a==b,label..': '..tostring(a)..' vs '..tostring(b))
end
local cells={['0|0']=true,['1|0']=true,['2|0']=true,['2|1']=true,['2|2']=true,['-1|0']=true}
local levels={['0|0']=0,['1|0']=0,['2|0']=2,['2|1']=2,['2|2']=2,['-1|0']=0}
for _,layout in ipairs({'separate','bottom','top'}) do
  local old=H.pillar(baseline,layout,cells,levels)
  local new=H.pillar('.',layout,cells,levels)
  local a,oldZero=H.triangles(old); local b,newZero=H.triangles(new)
  equal(#a,#b,layout..' real triangle count')
  for i=1,#a do equal(a[i],b[i],layout..' positions/UVs/shade/winding') end
  equal(newZero,0,layout..' degenerate triangles')
  print(('%s: vertices %d -> %d; submitted triangles %d -> %d; identical visible triangles %d'):format(layout,#old.vertices,#new.vertices,#old.indices/3,#new.indices/3,#a))
end
-- Building segmentation/shading intentionally changed in Astra 2. Its
-- exact exposed coverage and source texels are checked independently by
-- astra_building_coverage_test.lua, not by equality of the old vertex list.
print(('%d checks passed (retained Astra pillar triangle parity)'):format(checks))
