-- Only five full-cell LAB chairs and the two rooms' chair ride height change.
local root=os.getenv('ASTRA_LAB_ROOT')or os.getenv('ASTRA_CANDIDATE')or'.'
local baseline=assert(os.getenv('ASTRA_LAB_BASELINE'))
local H=dofile('tests/astra_fixture.lua');local F=dofile('tests/astra_scene_fixture.lua')
local before,after=F.runtime(baseline),F.runtime(root)
-- Historical release scope; A19 live tests own the exact new public cells/models.
after.spec.tilesets=H.historicalPublicPins(after.spec.tilesets,before.spec.tilesets)
after.spec.buildings=H.historicalPublicBuildings(after.spec.buildings,before.spec.buildings)
-- Keep this historical A14 ownership comparison exact. The live A15 desk
-- placement test separately validates its two approved source grids/claims.
for i=#after.spec.buildings.LAB,1,-1 do
 if after.spec.buildings.LAB[i].id=='lab_equipment_desk'then table.remove(after.spec.buildings.LAB,i)end
end
local checks=0
local function ok(v,msg)checks=checks+1;if not v then error('FAIL '..msg,0)end end
local function eq(a,b,msg)ok(a==b,msg..' expected '..tostring(b)..' got '..tostring(a))end
local function same(a,b,msg)
 eq(type(a),type(b),msg..' type')
 if type(a)~='table'then eq(a,b,msg);return end
 for k,v in pairs(a)do same(v,b[k],msg..'.'..tostring(k))end
 for k in pairs(b)do ok(a[k]~=nil,msg..' no extra '..tostring(k))end
end
local wanted={FUCHSIA_MEETING_ROOM=1,CINNABAR_LAB_TRADE_ROOM=4}
local full={[14]=true,[15]=true,[30]=true,[31]=true};local bench={[6]=true,[7]=true,[22]=true,[23]=true}
same(after.spec.heights,before.spec.heights,'global class heights remain exact')
same(H.historicalPins(after.spec.tilesets,before.spec.tilesets),before.spec.tilesets,'every tileset pin including all LAB bench stools remains exact')
for id,entry in pairs(after.spec.maps)do
 if wanted[id]then same(entry,{heights={stool=6}},'only the approved room-specific stool override')
 else same(entry,before.spec.maps[id],'all prior map-specific profiles remain exact')end
end
for id,entry in pairs(before.spec.maps)do same(after.spec.maps[id],entry,'no original map override removed or changed')end
local t=assert(F.template(after,'LAB','lab_stool'),'exact authored LAB chair required')
same(t.tiles,{{14,15},{30,31}},'only the full-cell chair source grid')
eq(#after.spec.buildings.LAB,1,'no unrelated LAB furniture is newly authored')
local data,w,h=H.atlas(assert(os.getenv('ASTRA_FURNITURE_ATLASES'))..'/lab.rgba')
local _,model=H.building(root,t.id,data,w,h,nil,true,'LAB');eq(model.ytop+1,6,'physical seat matches intended pin6')
local maps,places,changedCells,benchCells,actors=0,0,0,0,0
for id,def in pairs(F.maps)do if def.tileset=='LAB'then
 maps=maps+1;local map=F.Map.new(def,F.tilesets.LAB);local oldMap=F.Map.new(def,F.tilesets.LAB)
 local positions=F.matches(t,map);eq(#positions,wanted[id]or 0,'exact chair occurrence count in '..id);places=places+#positions
 local mask,chairCells={},{}
 for _,p in ipairs(positions)do
  chairCells[(p[1]/2)..':'..(p[2]/2)]=true
  for z=0,1 do for x=0,1 do mask[F.key(p[1]+x,p[2]+z)]=true end end
 end
 local oldShapes,newShapes=before.shapes.forMap(map),after.shapes.forMap(map)
 for z=0,map.def.height*4-1 do for x=0,map.def.width*4-1 do
  local tile=map:tileAt(x,z)
  if wanted[id]then ok(not bench[tile],'target room has no under-bench stools affected by its class override')end
  if bench[tile]then benchCells=benchCells+1;eq(newShapes[tile].h,8,'all actual bench-stool pins remain8')end
  if mask[F.key(x,z)]then
   eq(oldShapes[tile].h,8,'original chair ride height reproduced');eq(newShapes[tile].h,6,'only these chair tiles use pin6')
   eq(newShapes[tile].class,'stool','fallback chair class retained')
  else
   same(after.shapes.at(map,newShapes,tile,x,z),before.shapes.at(map,oldShapes,tile,x,z),'all other actual LAB tile shapes unchanged')
  end
 end end
 local a,b=F.build(after,map,data,w),F.build(before,map,data,w)
 same(a.tileAt,b.tileAt,id..' all original source tiles retained')
 for _,field in ipairs({'shapeAt','ground','skip'})do
  for k,v in pairs(b[field])do if not mask[k]then same(a[field][k],v,id..' original non-chair '..field)end end
  for k,v in pairs(a[field])do if not mask[k]then same(v,b[field][k],id..' no extra non-chair '..field)end end
 end
 for k in pairs(mask)do ok(a.skip[k],'chair source cells are claimed once');eq(a.shapeAt[k].class,'building','new chair receives rendering ownership only');eq(a.shapeAt[k].h,0,'claim itself does not raise unrelated objects')end
 eq(#a.objectQuads-#b.objectQuads,#positions*220,'only matched chairs add authored quads')
 for z=0,map.heightCells-1 do for x=0,map.widthCells-1 do
  local key=x..':'..z;local oldH,newH=before.scene.groundAt(map,x,z),after.scene.groundAt(map,x,z)
  if chairCells[key]then changedCells=changedCells+1;eq(oldH,8,'original seated support8');eq(newH,6,'seated support agrees with physical seat6');ok(map:isWalkableCell(x,z),'original chair cells remain walkable')
  else eq(newH,oldH,'every other actual actor support retained')end
  eq(map:cellTile(x,z),oldMap:cellTile(x,z),'all interaction tiles unchanged');eq(map:isWalkableCell(x,z),oldMap:isWalkableCell(x,z),'all original collision unchanged')
 end end
 for _,npc in ipairs(def.objects or {})do
  if chairCells[npc.x..':'..npc.y]then actors=actors+1;eq(after.scene.groundAt(map,npc.x,npc.y),model.ytop+1,'each seated NPC meets the physical cushion')end
  if npc.name=='FUCHSIAMEETINGROOM_SAFARI_ZONE_WORKER3'then
   eq(npc.x,10,'identified speech-problem speaker X');eq(npc.y,1,'identified speech-problem speaker Y')
   eq(after.scene.groundAt(map,npc.x,npc.y),6,'identified worker now sits on the six-pixel cushion')
  end
 end
 if #positions>0 then print(id..': '..#positions..' exact chairs, original pin8 -> physical/pinned seat6; all other support/ownership retained')end
end end
eq(maps,7,'all seven LAB maps audited');eq(places,5,'only five intended chair instances');eq(changedCells,5,'only five actual actor support cells change')
ok(benchCells>0,'unaffected bench stools in other LAB rooms are exercised');ok(actors>=1,'real seated NPC support is exercised')
-- Exercise the per-map cache in alternating order to catch a6px override
-- leaking into other rooms on the same LAB tileset.
for _,id in ipairs({'FUCHSIA_MEETING_ROOM','WARDENS_HOUSE','CINNABAR_LAB_TRADE_ROOM','WARDENS_HOUSE','FUCHSIA_MEETING_ROOM'})do
 local map=F.Map.new(F.maps[id],F.tilesets.LAB);eq(after.shapes.forMap(map)[30].h,wanted[id]and 6 or 8,'per-map height cache remains isolated')
end
print(('%d LAB source/ownership/support checks passed; five chairs, two overrides, %d unaffected bench tiles, %d seated NPCs'):format(checks,benchCells,actors))
