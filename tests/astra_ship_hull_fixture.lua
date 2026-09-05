local T={}
local root=os.getenv('ASTRA_CANDIDATE')or'.'
T.H=dofile(root..'/tests/astra_fixture.lua')
T.F=dofile(root..'/tests/astra_scene_fixture.lua')
function T.runtime(path)
 local r={spec=dofile(path..'/data/voxel_heights.lua'),draws={},shadows={},ticks=0}
 local modules={BuildBudget={tick=function()r.ticks=r.ticks+1 end},
  ModSetting={new=function()return{get=function()return true end}end},
  Mat4=assert(loadfile(path..'/lib/Mat4.lua'))(),
  Voxel3D={
   newMesh=function(vertices,indices)return{vertices=vertices,indices=indices}end,
   pushQuad=function(indices,n)for _,i in ipairs({1,2,3,1,3,4})do indices[#indices+1]=n*4+i end end,
   draw=function(mesh,tex,matrix)r.draws[#r.draws+1]={mesh=mesh,tex=tex,matrix=matrix}end},
  ShadowMap={draw=function(mesh,tex,matrix)r.shadows[#r.shadows+1]={mesh=mesh,tex=tex,matrix=matrix}end},
 }
 local V={data=function()return r.spec end}
 function V.require(n)
  if modules[n]then return modules[n]end
  if n=='ShipHull'or n=='ShipExterior'or n=='Buildings'or n=='TileShape'or n=='CaveSteps' then
   modules[n]=assert(loadfile(path..'/lib/'..n..'.lua'))(V);return modules[n]
  end
  return{}
 end
 r.V=V;r.ship=V.require('ShipHull');r.build=V.require('Buildings');r.shapes=V.require('TileShape')
 r.scene=assert(loadfile(path..'/lib/VoxelScene.lua'))(V)
 r.read=T.H.upvalue(r.build.build,'read');r.emit=T.H.upvalue(r.build.build,'emit')
 r.template=r.spec.tilesets.SHIP_PORT.ship_hull
 function r.prepare(map,data)
  local S={tileAt={},shapeAt={},skip={},ground={},objectQuads={}}
  local shapes=r.shapes.forMap(map)
  for z=-2,map.def.height*4+1 do for x=-2,map.def.width*4+1 do
   local k=T.F.key(x,z);local tile=map:tileAt(x,z);S.tileAt[k]=tile;S.shapeAt[k]=r.shapes.at(map,shapes,tile,x,z)
  end end
  r.build.build(S,map,data,map.tileset.tilesPerRow or 16)
  return S
 end
 return r
end
return T