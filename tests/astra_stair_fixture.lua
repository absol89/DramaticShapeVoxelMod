-- Real-map public stair-pass harness; only the source image provider is injected.
local testRoot=rawget(_G,'ASTRA_STAIRS_TEST_ROOT')or os.getenv('ASTRA_CANDIDATE')or'.'
local H=dofile(testRoot..'/tests/astra_fixture.lua');local F=dofile(testRoot..'/tests/astra_scene_fixture.lua')
local T={H=H,F=F}
function T.runtime(root,data)
 local r=F.runtime(root)
 local modules={Buildings=r.build,TileShape=r.shapes,BuildBudget={tick=function()end},VoxelVisualObjects={},CommunityVisuals={customSigns=function()return false end,customCutTrees=function()return false end}}
 local V={data=function()return r.spec end}
 function V.require(n)
  if modules[n]~=nil then return modules[n]end
  assert(n=='CaveLadders'or n=='InteriorStairs'or n=='CaveSteps','unexpected stair test dependency '..n)
  modules[n]=assert(loadfile(root..'/lib/'..n..'.lua'))(V);return modules[n]
 end
 r.module=V.require
 r.stairs=assert(loadfile(root..'/lib/Structures.lua'))(V)
 -- Replace only Assets.imageData access. Shared upvalue lets all actual
 -- stair dispatch and claim logic execute unchanged with the private atlas.
 local found=false
 for i=1,100 do local name=debug.getupvalue(r.stairs.buildStairs,i);if not name then break end
  if name=='pixels'then debug.setupvalue(r.stairs.buildStairs,i,function()return data end);found=true;break end
 end
 assert(found,'public stair pass still owns its source provider')
 function r.prepare(map)
  local S={tileAt={},shapeAt={},ground={},skip={},objectQuads={}}
  local shapes=r.shapes.forMap(map)
  for z=-2,map.def.height*4+1 do for x=-2,map.def.width*4+1 do
   local k=F.key(x,z);local tile=map:tileAt(x,z);S.tileAt[k]=tile;S.shapeAt[k]=r.shapes.at(map,shapes,tile,x,z)
  end end
  return S
 end
 function r.render(map,bounds)
  local S=r.prepare(map);bounds=bounds or{0,map.def.width*4-1,0,map.def.height*4-1}
  r.stairs.buildStairs(S,map,bounds[1],bounds[2],bounds[3],bounds[4]);return S
 end
 return r
end
return T
