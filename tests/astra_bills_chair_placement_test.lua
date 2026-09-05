-- The integrated stool correction changes presentation in exactly the
-- original matched desk grids. Real Map and VoxelScene support stay intact.
local root=os.getenv('ASTRA_DESK_ROOT') or os.getenv('ASTRA_CANDIDATE') or '.'
local baseline=assert(os.getenv('ASTRA_DESK_BASELINE'))
local engine=assert(os.getenv('ASTRA_ENGINE'))
local generated=assert(os.getenv('ASTRA_GENERATED'))
local H=dofile('tests/astra_fixture.lua')
local data,w,h=H.atlas(assert(os.getenv('ASTRA_FURNITURE_ATLASES'))..'/interior.rgba')
package.path=engine..'/?.lua;'..engine..'/?/init.lua;'..package.path
local Map=require('src.world.Map')
local maps=dofile(generated..'/maps.lua');local tilesets=dofile(generated..'/tilesets.lua')
local checks=0
local function ok(v,msg)checks=checks+1;if not v then error('FAIL '..msg,0)end end
local function eq(a,b,msg)ok(a==b,msg..' (expected '..tostring(b)..', got '..tostring(a)..')')end
local function same(a,b,msg)
 eq(type(a),type(b),msg..' type')
 if type(a)~='table'then eq(a,b,msg);return end
 for k,v in pairs(a)do same(v,b[k],msg..'.'..tostring(k))end
 for k in pairs(b)do ok(a[k]~=nil,msg..' no extra field '..tostring(k))end
end
local function runtime(path)
 local spec=dofile(path..'/data/voxel_heights.lua')
 local modules={BuildBudget={tick=function()end},ModSetting={new=function()return{get=function()return true end}end}}
 local V={data=function()return spec end}
 function V.require(n)
  if not modules[n]then
   if n=='ComputerCase' or n=='BillMachine' or n=='BillPipe'then modules[n]=assert(loadfile(path..'/lib/'..n..'.lua'))(V)
   elseif n=='Buildings' or n=='TileShape'then modules[n]=assert(loadfile(path..'/lib/'..n..'.lua'))(V)
   else modules[n]={}end
  end
  return modules[n]
 end
 return {spec=spec,build=V.require('Buildings'),shapes=V.require('TileShape'),scene=assert(loadfile(path..'/lib/VoxelScene.lua'))(V)}
end
local before,after=runtime(baseline),runtime(root)
-- The separately tested A19 Silph warp does not alter this historical desk proof.
after.spec.tilesets=H.historicalPublicPins(after.spec.tilesets,before.spec.tilesets)
local function template(r)
 for _,t in ipairs(r.spec.buildings.INTERIOR)do if t.id=='bills_desk'then return t end end
 error('missing desk template')
end
local a,b=template(after),template(before)
for _,field in ipairs({'tiles','desk','depth','keep','scrub','support','roofRows','roofBack','roofFront','roofCycle','slab','frontEave','ledge'})do
 same(a[field],b[field],'unchanged desk profile '..field)
end
for i=1,3 do same(a.parts[i],b.parts[i],'unchanged authored desk object '..i)end
-- Only the CRT presentation opt-in is new; its original location stays fixed.
local case=a.parts[4].case;a.parts[4].case=nil
same(a.parts[4],b.parts[4],'unchanged original computer placement');a.parts[4].case=case
-- Current upstream adds opt-in saplings; retain all historical class values.
before.spec.heights.sapling=before.spec.heights.sapling or 16
same(after.spec.heights,before.spec.heights,'all original authored heights')
same(H.historicalPins(after.spec.tilesets,before.spec.tilesets),before.spec.tilesets,'all original tile and seated-character pins')
local function key(x,z)return(z+64)*4096+x+64 end
local function build(r,map)
 local S={outdoor=false,tileAt={},shapeAt={},ground={},skip={},objectQuads={}}
 local resolved=r.shapes.forMap(map)
 for z=-1,map.def.height*4 do for x=-1,map.def.width*4 do
  local tile=map:tileAt(x,z);S.tileAt[key(x,z)]=tile
  S.shapeAt[key(x,z)]=r.shapes.at(map,resolved,tile,x,z)
 end end
 r.build.build(S,map,data,w/8)
 return S
end
local function collision(map)
 local out={}
 for z=0,map.heightCells-1 do for x=0,map.widthCells-1 do out[#out+1]=tostring(map:cellTile(x,z))..':'..tostring(map:isWalkableCell(x,z))end end
 return table.concat(out,';')
end
local _,model=H.building(root,'bills_desk',data,w,h,nil,true,'INTERIOR')
local physical=-1
for y=0,model.ytop do for z=16,31 do for x=0,15 do if model.at(x,y,z)~=nil then physical=math.max(physical,y+1)end end end end
local total,affected=0,0
local ids={};for id,def in pairs(maps)do if def.tileset=='INTERIOR'then ids[#ids+1]=id end end;table.sort(ids)
for _,id in ipairs(ids)do
 local map=Map.new(maps[id],tilesets.INTERIOR)
 local places={}
 for z=0,map.def.height*4-#a.tiles do for x=0,map.def.width*4-#a.tiles[1]do
  local match=true
  for dz,row in ipairs(a.tiles)do for dx,tile in ipairs(row)do if map:tileAt(x+dx-1,z+dz-1)~=tile then match=false end end end
  if match then places[#places+1]={x,z}end
 end end
 if #places>0 then
  affected=affected+1;total=total+#places
  ok(id=='BILLS_HOUSE' or id=='SILPH_CO_11F','only the two original integrated desks match')
  local priorCollision=collision(map)
  local old,new=build(before,map),build(after,map)
  -- The newly authored transporters own only their exact original grids;
  -- their40 cells and actual scripted clearance have a dedicated live test.
  local machineClaims={}
  for _,mt in ipairs(after.spec.buildings.INTERIOR)do if mt.machine=='bill_transporter' or mt.id=='bill_pipe_link' or mt.id=='bill_pipe_left' or mt.id=='bill_pipe_right'then
   for tz=0,map.def.height*4-#mt.tiles do for tx=0,map.def.width*4-#mt.tiles[1]do
    local match=true
    for dz,row in ipairs(mt.tiles)do for dx,tile in ipairs(row)do if map:tileAt(tx+dx-1,tz+dz-1)~=tile then match=false end end end
    if match then for dz=0,#mt.tiles-1 do for dx=0,#mt.tiles[1]-1 do machineClaims[key(tx+dx,tz+dz)]=true end end end
   end end
  end end
  same(new.tileAt,old.tileAt,id..' complete original tileAt')
  for _,field in ipairs({'shapeAt','ground','skip'})do
   for k,v in pairs(old[field])do if not machineClaims[k]then same(new[field][k],v,id..' original non-machine '..field)end end
   for k,v in pairs(new[field])do if not machineClaims[k]then same(v,old[field][k],id..' no extra non-machine '..field)end end
  end
  eq(collision(map),priorCollision,id..' all collision/interaction tiles unchanged')
  for z=0,map.heightCells-1 do for x=0,map.widthCells-1 do
   eq(after.scene.groundAt(map,x,z),before.scene.groundAt(map,x,z),id..' original actor support')
  end end
  for _,p in ipairs(places)do
   for dz=0,3 do for dx=0,3 do ok(new.skip[key(p[1]+dx,p[2]+dz)],id..' all16 original desk cells claimed')end end
   local cx,cz=p[1]/2,(p[2]+2)/2
   ok(map:isWalkableCell(cx,cz),id..' chair cell remains walkable')
   eq(after.scene.groundAt(map,cx,cz),5,id..' authored seat pin remains five')
   eq(physical,after.scene.groundAt(map,cx,cz),id..' rendered seat now agrees with engine support')
   print(('%s: desk origin(%d,%d), chair cell(%g,%g), physical/pinned height5, all original claims retained'):format(id,p[1],p[2],cx,cz))
  end
 end
end
eq(affected,2,'both original desk maps covered');eq(total,2,'exactly two original desk placements')
print(('%d integrated-chair real-map ownership/support checks passed'):format(checks))
