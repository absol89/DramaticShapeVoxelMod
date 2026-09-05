-- Shared read-only real-map harness for authored-object placement tests.
local F={}
local engine=assert(os.getenv('ASTRA_ENGINE'))
package.path=engine..'/?.lua;'..engine..'/?/init.lua;'..package.path
F.Map=require('src.world.Map')
local generated=assert(os.getenv('ASTRA_GENERATED'))
F.maps=dofile(generated..'/maps.lua');F.tilesets=dofile(generated..'/tilesets.lua')
function F.key(x,z)return(z+64)*4096+x+64 end
function F.runtime(path)
 local spec=dofile(path..'/data/voxel_heights.lua')
 -- The historical art snapshots predate upstream c3b0ae8's opt-in sapling
 -- metadata. Give only absent metadata the exact upstream defaults; never
 -- replace an existing value or alter the original raw tree/ground pins.
 if spec.heights.sapling==nil then spec.heights.sapling=16 end
 if spec.tilesets.OVERWORLD.sapling_tiles==nil then
  spec.tilesets.OVERWORLD.sapling_tiles={45,46,61,62}
 end
 local modules={BuildBudget={tick=function()end},ModSetting={new=function()return{get=function()return true end}end}}
 local V={data=function()return spec end}
 function V.require(n)
  if not modules[n]then
   if n=='ComputerCase' or n=='BillMachine' or n=='BillPipe' or n=='FacilityPalm' or n=='CaveSteps' or n=='ShipHull' or n=='BikeDisplay'then modules[n]=assert(loadfile(path..'/lib/'..n..'.lua'))(V)
   elseif n=='Buildings' or n=='TileShape'then modules[n]=assert(loadfile(path..'/lib/'..n..'.lua'))(V)
   else modules[n]={}end
  end
  return modules[n]
 end
 local shapes=V.require('TileShape');local forMap=shapes.forMap
 shapes.forMap=function(map)
  local value=forMap(map)
  if value.classes.sapling==nil then value.classes.sapling={class='sapling',h=16,art='cylinder',flat=false,authored=false}end
  if value.saplingTiles==nil then
   value.saplingTiles={}
   local entry=spec.tilesets[map.def.tileset]
   for _,tile in ipairs(entry and entry.sapling_tiles or{})do value.saplingTiles[tile]=true end
  end
  return value
 end
 return{spec=spec,build=V.require('Buildings'),shapes=shapes,scene=assert(loadfile(path..'/lib/VoxelScene.lua'))(V)}
end
function F.template(r,family,id)
 for _,t in ipairs(r.spec.buildings[family])do if t.id==id then return t end end
end
function F.matches(t,map)
 local out={}
 for z=0,map.def.height*4-#t.tiles do for x=0,map.def.width*4-#t.tiles[1]do
  local yes=true
  for dz,row in ipairs(t.tiles)do for dx,tile in ipairs(row)do if map:tileAt(x+dx-1,z+dz-1)~=tile then yes=false end end end
  if yes then out[#out+1]={x,z}end
 end end
 return out
end
function F.build(r,map,data,w)
 local S={outdoor=false,tileAt={},shapeAt={},ground={},skip={},objectQuads={}}
 local resolved=r.shapes.forMap(map)
 for z=-1,map.def.height*4 do for x=-1,map.def.width*4 do
  local tile=map:tileAt(x,z);S.tileAt[F.key(x,z)]=tile
  S.shapeAt[F.key(x,z)]=r.shapes.at(map,resolved,tile,x,z)
 end end
 r.build.build(S,map,data,w/8)
 return S
end
function F.pipeClaims(r,map)
 local wanted={bill_pipe_link=true,bill_pipe_left=true,bill_pipe_right=true}
 local out={}
 for _,t in ipairs(r.spec.buildings.INTERIOR or {})do if wanted[t.id]then
  for _,p in ipairs(F.matches(t,map))do
   for z=0,#t.tiles-1 do for x=0,#t.tiles[1]-1 do out[F.key(p[1]+x,p[2]+z)]=true end end
  end
 end end
 return out
end
return F
