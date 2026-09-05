-- Only Bill's three metal pipe placements gain rendering ownership.
local root=os.getenv('ASTRA_PIPE_ROOT')or os.getenv('ASTRA_CANDIDATE')or'.'
local baseline=assert(os.getenv('ASTRA_PIPE_BASELINE'))
local H=dofile('tests/astra_fixture.lua');local F=dofile('tests/astra_scene_fixture.lua')
local before,after=F.runtime(baseline),F.runtime(root)
local checks=0
local function ok(v,msg)checks=checks+1;if not v then error('FAIL '..msg,0)end end
local function eq(a,b,msg)ok(a==b,msg..' expected '..tostring(b)..' got '..tostring(a))end
local function same(a,b,msg)
 eq(type(a),type(b),msg..' type')
 if type(a)~='table'then eq(a,b,msg);return end
 for k,v in pairs(a)do same(v,b[k],msg..'.'..tostring(k))end
 for k in pairs(b)do ok(a[k]~=nil,msg..' no extra '..tostring(k))end
end
local wanted={
 bill_pipe_link={x=5,z=2,n=168,tiles={{37,38,38,38,38,32},{53,54,54,54,54,48}}},
 bill_pipe_left={x=0,z=2,n=72,tiles={{32},{48}}},
 bill_pipe_right={x=15,z=2,n=72,tiles={{37},{53}}}}
same(after.spec.heights,before.spec.heights,'all original authored class heights')
same(H.historicalPins(after.spec.tilesets,before.spec.tilesets),before.spec.tilesets,'all original wall/actor/interaction pins')
local oldIds={}
for _,t in ipairs(before.spec.buildings.INTERIOR)do oldIds[t.id]=true;same(F.template(after,'INTERIOR',t.id),t,'every accepted A12 INTERIOR profile retained exactly')end
local additions=0
for _,t in ipairs(after.spec.buildings.INTERIOR)do if not oldIds[t.id]then
 local c=wanted[t.id];ok(c~=nil,'no unrelated authored INTERIOR model added');additions=additions+1
 same(t.tiles,c.tiles,'exact metal pipe source tile grid');eq(t.pipe,'bill_pipe','only explicit pipe templates opt in')
end end
eq(additions,3,'only the three requested metal pipe profiles added')
local data,w,h=H.atlas(assert(os.getenv('ASTRA_FURNITURE_ATLASES'))..'/interior.rgba')
local records={};local stamp=after.build.stamp
function after.build.stamp(S,map,q,x,z,bw,bh,t)
 local first=#S.objectQuads+1;stamp(S,map,q,x,z,bw,bh,t)
 if wanted[t.id]then records[#records+1]={id=t.id,x=x,z=z,first=first,last=#S.objectQuads,map=map.id}end
end
local maps,instances,wallCells=0,0,0
for id,def in pairs(F.maps)do if def.tileset=='INTERIOR'then
 local map=F.Map.new(def,F.tilesets.INTERIOR);local mask=F.pipeClaims(after,map)
 if next(mask)then
  maps=maps+1;eq(id,'BILLS_HOUSE','pipe fragments never opt unrelated rooms into tube rendering')
  records={};local a,b=F.build(after,map,data,w),F.build(before,map,data,w)
  eq(#records,3,'full connector claims its endpoints before standalone stubs, with no duplicate tube')
  local skipQuads={};local cells={};local pipeCount=0
  for _,p in ipairs(records)do
   local c=wanted[p.id];eq(p.map,id,'pipe belongs to actual Bill map');eq(p.x,c.x,'exact pipe X origin');eq(p.z,c.z,'exact pipe Z origin')
   eq(p.last-p.first+1,c.n,'each pipe adds only its approved tube/collar surfaces');instances=instances+1
   for j=p.first,p.last do skipQuads[j]=true;pipeCount=pipeCount+1 end
   for z=0,#c.tiles-1 do for x=0,#c.tiles[1]-1 do
    local k=F.key(p.x+x,p.z+z);ok(not cells[k],'no source tile claimed by two pipe instances');cells[k]=true
   end end
  end
  eq(pipeCount,312,'only312 new object surfaces')
  same(cells,mask,'actual claim order covers precisely the intended source tiles')
  local retained={};for j,q in ipairs(a.objectQuads)do if not skipQuads[j]then retained[#retained+1]=q end end
  same(retained,b.objectQuads,'every stamped A12 machine/desk/chair quad retains exact positions, UVs, winding and shades')
  same(a.tileAt,b.tileAt,'every original source map tile remains unchanged')
  for _,field in ipairs({'shapeAt','ground','skip'})do
   for k,v in pairs(b[field])do if not cells[k]then same(a[field][k],v,'all non-pipe '..field..' unchanged')end end
   for k,v in pairs(a[field])do if not cells[k]then same(v,b[field][k],'no extra non-pipe '..field)end end
  end
  local n=0
  for k in pairs(cells)do
   n=n+1;ok(a.skip[k],'the original flat pipe artwork is claimed once')
   eq(b.shapeAt[k].class,'wall','test exercises the original h16 wall extrusion')
   eq(b.shapeAt[k].h,16,'original pipe-box height reproduced')
   eq(a.shapeAt[k].class,'building','new claim affects rendering only');eq(a.shapeAt[k].h,0,'tube is not an actor support platform')
   ok(a.tileAt[k]~=16 and a.tileAt[k]~=69,'ordinary green wall tiles are never claimed as metal')
  end
  eq(n,16,'only sixteen exact original pipe tiles change rendering ownership')
  for k,tile in pairs(a.tileAt)do if tile==16 or tile==69 then
   wallCells=wallCells+1;same(a.shapeAt[k],b.shapeAt[k],'ordinary wall tile keeps its original shape/palette pin')
   same(a.skip[k],b.skip[k],'ordinary wall ownership unchanged');same(a.ground[k],b.ground[k],'ordinary wall ground unchanged')
  end end
  local oldMap=F.Map.new(def,F.tilesets.INTERIOR)
  for z=0,map.heightCells-1 do for x=0,map.widthCells-1 do
   eq(map:cellTile(x,z),oldMap:cellTile(x,z),'every original interaction/collision tile retained')
   eq(map:isWalkableCell(x,z),oldMap:isWalkableCell(x,z),'all original collision flags retained')
   eq(after.scene.groundAt(map,x,z),before.scene.groundAt(map,x,z),'all original actor support retained')
  end end
  for _,p in ipairs({{1,2},{1,3},{2,3},{3,3},{4,3},{4,4},{6,5},{6,4},{6,3},{6,2}})do
   eq(map:isWalkableCell(p[1],p[2]),p[2]~=2,'original scripted chamber endpoints and exit paths retained')
   eq(after.scene.groundAt(map,p[1],p[2]),0,'original Bill route remains at ground0')
  end
 end
end end
eq(maps,1,'only Bill room matches any source pipe');eq(instances,3,'exactly the original three metal pipe instances')
ok(wallCells>30,'ordinary neighboring wall tiles exercised')
print(('Bill pipes:3 instances,16 source tiles,312 new surfaces; all A12 stamped objects and%d ordinary wall cells retained'):format(wallCells))
print(('%d pipe source/ownership/script preservation checks passed'):format(checks))
