-- Bill's two authored transporters replace presentation only. Real script
-- entrance/exit cells, walking route, support, and unrelated claims stay exact.
local root=os.getenv('ASTRA_COMPUTER_ROOT') or os.getenv('ASTRA_CANDIDATE')or'.'
local baseline=assert(os.getenv('ASTRA_COMPUTER_BASELINE'))
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
local t=assert(F.template(after,'INTERIOR','bill_transporter'),'authored machine required')
same(t.tiles,{{7,8,9,10},{23,24,25,26},{39,40,41,42},{55,56,57,58},{80,1,2,15}},'exact original transporter tile grid')
same(after.spec.heights,before.spec.heights,'all class heights unchanged')
same(H.historicalPins(after.spec.tilesets,before.spec.tilesets),before.spec.tilesets,'all source tile and actor support pins unchanged')
local data,w,h=H.atlas(assert(os.getenv('ASTRA_FURNITURE_ATLASES'))..'/interior.rgba')
local _,model=H.building(root,t.id,data,w,h,nil,true,'INTERIOR')
local count=0
for id,def in pairs(F.maps)do if def.tileset=='INTERIOR'then
 local map=F.Map.new(def,F.tilesets.INTERIOR);local places=F.matches(t,map)
 if #places>0 then
  eq(id,'BILLS_HOUSE','no other map accidentally matches transporter art');eq(#places,2,'exact two original machines')
  local claimed={}
  for _,p in ipairs(places)do
   ok((p[1]==1 or p[1]==11)and p[2]==1,'original west/east source placement');count=count+1
   for z=0,4 do for x=0,3 do claimed[F.key(p[1]+x,p[2]+z)]=true end end
  end
  local a,b=F.build(after,map,data,w),F.build(before,map,data,w)
  local pipeClaims=F.pipeClaims(after,map) -- separately tested A13 rendering-only claims
  same(a.tileAt,b.tileAt,'every original map tile retained')
  for _,field in ipairs({'shapeAt','skip','ground'})do
   for k,v in pairs(b[field])do if not claimed[k]and not pipeClaims[k]then same(a[field][k],v,'all non-machine '..field..' retained')end end
   for k,v in pairs(a[field])do if not claimed[k]and not pipeClaims[k]then same(v,b[field][k],'no extra non-machine '..field)end end
  end
  local n=0
  for k in pairs(claimed)do
   n=n+1;ok(a.skip[k],'each transporter source tile claimed exactly once')
   eq(a.shapeAt[k].class,'building','machine receives only authored rendering ownership')
   eq(a.shapeAt[k].h,0,'transporters do not create actor or object support platforms')
  end
  eq(n,40,'only two original4x5 grids newly claimed')
  local oldMap=F.Map.new(def,F.tilesets.INTERIOR)
  for z=0,map.heightCells-1 do for x=0,map.widthCells-1 do
   eq(after.scene.groundAt(map,x,z),before.scene.groundAt(map,x,z),'all actor support unchanged')
   eq(map:cellTile(x,z),oldMap:cellTile(x,z),'all original interaction tiles unchanged')
   eq(map:isWalkableCell(x,z),oldMap:isWalkableCell(x,z),'all original collision retained')
  end end
  -- OverworldController:billsHousePC puts human Bill at(1,2), then walks
  -- down1/right3/down1; the Pokemon walks up3 from(6,5) into the east drum.
  for _,p in ipairs({{1,2},{1,3},{2,3},{3,3},{4,3},{4,4},{6,5},{6,4},{6,3},{6,2}})do
   -- Both original chamber endpoints are collision tile1; scripted movement
   -- deliberately bypasses that flag. All steps outside the chamber are walkable.
   eq(map:isWalkableCell(p[1],p[2]),p[2]~=2,'original blocked chamber endpoint and walkable exit route retained')
   eq(after.scene.groundAt(map,p[1],p[2]),0,'Bill stays at original ground-level support throughout cutscene')
  end
  -- Physical clearance is checked at the actual sprite center and across
  -- its16px width, not inferred from unchanged collision metadata.
  for _,p in ipairs(places)do
   local cx=p[1]==1 and 1 or 6
   local localX=cx*16+8-p[1]*8;local localZ=2*16+8-p[2]*8
   eq(localX,16,'scripted actor centered in original chamber');eq(localZ,32,'scripted actor starts in front entry')
   for z=localZ,model.zmax do for y=0,17 do for x=localX-8,localX+7 do
    eq(model.at(x,y,z),nil,'16px actor has clear head/feet path through the chamber opening and plinth')
   end end end
  end
  print('BILLS_HOUSE: exactly40 original machine tiles claimed; both scripted actor routes and18px doorway clearance preserved')
 end
end end
eq(count,2,'all and only original transporter instances exercised')
print(('%d transporter ownership/collision/scripted-clearance checks passed'):format(checks))
