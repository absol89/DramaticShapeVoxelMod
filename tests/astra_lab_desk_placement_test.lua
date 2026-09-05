-- Only the two complete LAB equipment desks gain authored rendering ownership.
local root=os.getenv('ASTRA_LAB_DESK_ROOT')or os.getenv('ASTRA_CANDIDATE')or'.'
local baseline=assert(os.getenv('ASTRA_LAB_DESK_BASELINE'))
local H=dofile('tests/astra_fixture.lua');local F=dofile('tests/astra_scene_fixture.lua')
local before,after=F.runtime(baseline),F.runtime(root)
-- Historical release scope; A19 live tests own the exact new public cells/models.
after.spec.tilesets=H.historicalPublicPins(after.spec.tilesets,before.spec.tilesets)
after.spec.buildings=H.historicalPublicBuildings(after.spec.buildings,before.spec.buildings)
local checks=0
local function ok(v,msg)checks=checks+1;if not v then error('FAIL '..msg,0)end end
local function eq(a,b,msg)ok(a==b,msg..' expected '..tostring(b)..' got '..tostring(a))end
local function same(a,b,msg)
 eq(type(a),type(b),msg..' type')
 if type(a)~='table'then eq(a,b,msg);return end
 for k,v in pairs(a)do same(v,b[k],msg..'.'..tostring(k))end
 for k in pairs(b)do ok(a[k]~=nil,msg..' no extra '..tostring(k))end
end
same(after.spec.heights,before.spec.heights,'every prior global class height remains exact')
same(H.historicalPins(after.spec.tilesets,before.spec.tilesets),before.spec.tilesets,'every prior tile pin, including LAB trim and bench stools, remains exact')
same(after.spec.maps,before.spec.maps,'every per-map override, including both A14 six-pixel seats, remains exact')
-- Later full-pass objects are independently validated; retain this A15 desk scope.
local later={['LOBBY/lobby_stool']=true,['LOBBY/lobby_round_table']=true,['MUSEUM/museum_stool']=true,['CLUB/cable_club_stool']=true}
local historic={spec={buildings=H.historicalPalletBuildings(after.spec.buildings,before.spec.buildings)}}
local added=0
for family,old in pairs(before.spec.buildings)do
 local known={};for _,t in ipairs(old)do known[t.id]=true;same(F.template(historic,family,t.id),t,'accepted '..family..'/'..t.id..' profile retained')end
 for _,t in ipairs(historic.spec.buildings[family])do if not known[t.id]and not later[family..'/'..t.id]then
  added=added+1;eq(family,'LAB','no other tileset gains a new object');eq(t.id,'lab_equipment_desk','only the exact equipment desk is added')
 end end
end
eq(added,1,'one narrowly opted-in source template')
local t=assert(F.template(after,'LAB','lab_equipment_desk'),'new exact equipment desk required')
same(t.tiles,{{64,65,65,66},{80,81,81,82},{80,72,73,82},{83,58,58,84}},'exact complete freestanding desk grid')
local wanted={FUCHSIA_MEETING_ROOM={20,4},CINNABAR_LAB_FOSSIL_ROOM={12,8}}
local data,w,h=H.atlas(assert(os.getenv('ASTRA_FURNITURE_ATLASES'))..'/lab.rgba')
local q=H.building(root,t.id,data,w,h,nil,nil,'LAB')
for _,face in ipairs(q)do for i=1,4 do
 ok(face[i][1]>=0 and face[i][1]<=32 and face[i][3]>=0 and face[i][3]<=32,'desk and equipment stay within the original claimed footprint')
end end
local records={};local stamp=after.build.stamp
function after.build.stamp(S,map,quads,x,z,bw,bh,template)
 local first=#S.objectQuads+1;stamp(S,map,quads,x,z,bw,bh,template)
 if template.id==t.id then records[#records+1]={x=x,z=z,first=first,last=#S.objectQuads}end
end
local maps,instances,claims,tableCells,artPairs=0,0,0,0,0
for id,def in pairs(F.maps)do if def.tileset=='LAB'then
 maps=maps+1;local map=F.Map.new(def,F.tilesets.LAB);local oldMap=F.Map.new(def,F.tilesets.LAB)
 local positions=F.matches(t,map);eq(#positions,wanted[id]and 1 or 0,'only the two complete source grids match in '..id)
 local cells={}
 for _,p in ipairs(positions)do
  same(p,wanted[id],'original desk source origin');instances=instances+1
  for z=0,3 do for x=0,3 do cells[F.key(p[1]+x,p[2]+z)]=true end end
  for z=p[2]/2,p[2]/2+1 do for x=p[1]/2,p[1]/2+1 do
   tableCells=tableCells+1;ok(not map:isWalkableCell(x,z),'original table cells stay blocked');eq(after.scene.groundAt(map,x,z),12,'table support stays at its original twelve-pixel plane')
  end end
 end
 records={};local a,b=F.build(after,map,data,w),F.build(before,map,data,w)
 eq(#records,#positions,'each exact desk stamps once, with no independent second terminal')
 local skip={}
 for _,p in ipairs(records)do
  eq(p.x,wanted[id][1],'actual stamp X');eq(p.z,wanted[id][2],'actual stamp Z');eq(p.last-p.first+1,#q,'only one complete model per desk')
  for j=p.first,p.last do skip[j]=true end
 end
 local retained={};for j,v in ipairs(a.objectQuads)do if not skip[j]then retained[#retained+1]=v end end
 same(retained,b.objectQuads,id..' all accepted A14 chair/object positions, UVs and shades remain exact')
 same(a.tileAt,b.tileAt,id..' every original source tile remains exact')
 for _,field in ipairs({'shapeAt','ground','skip'})do
  for k,v in pairs(b[field])do if not cells[k]then same(a[field][k],v,id..' original non-desk '..field)end end
  for k,v in pairs(a[field])do if not cells[k]then same(v,b[field][k],id..' no additional non-desk '..field)end end
 end
 for k in pairs(cells)do
  claims=claims+1;ok(not b.skip[k],'baseline generic table ownership reproduced');ok(a.skip[k],'all original desk art is claimed to prevent duplicate generic prints')
  eq(a.shapeAt[k].class,'building','rendering ownership is restricted to the exact desk')
 end
 for z=0,map.heightCells-1 do for x=0,map.widthCells-1 do
  eq(map:cellTile(x,z),oldMap:cellTile(x,z),'original interaction tiles retained')
  eq(map:isWalkableCell(x,z),oldMap:isWalkableCell(x,z),'original collision retained')
  eq(after.scene.groundAt(map,x,z),before.scene.groundAt(map,x,z),'every actor support height remains exact')
 end end
 for z=0,def.height*4-1 do for x=0,def.width*4-1 do if map:tileAt(x,z)==72 then artPairs=artPairs+1 end end end
 if id=='FUCHSIA_MEETING_ROOM'then
  eq(after.scene.groundAt(map,10,1),6,'speech-problem worker remains on accepted A14 chair')
  for z=2,3 do for x=20,21 do ok(not cells[F.key(x,z)],'equipment claim never includes the adjacent north stool')end end
 elseif id=='CINNABAR_LAB_FOSSIL_ROOM'then
  eq(after.scene.groundAt(map,7,6),0,'south-facing desk neighbor scientist retains ground support')
 elseif id=='WARDENS_HOUSE'then
  same(a,b,'entire Warden bench scene remains exact')
  eq(map:tileAt(1,5),72,'the unmodified Warden terminal variant is exercised')
  eq(map:tileAt(0,6),6,'Warden bench-apron stool tiles remain present')
  eq(after.scene.groundAt(map,0,3),8,'Warden under-bench stool retains its separate eight-pixel support')
 end
 if #positions>0 then print(id..': exact equipment desk at '..positions[1][1]..','..positions[1][2]..';16 claims, support12; all neighboring objects/support unchanged')end
end end
eq(maps,7,'all seven LAB maps scanned');eq(instances,2,'exactly two intended complete desks');eq(claims,32,'only thirty-two original tile claims')
eq(tableCells,8,'eight original blocked table support cells');eq(artPairs,3,'all monitor/ball pairs accounted for, including excluded Warden bench')
print(('%d LAB equipment source/ownership/support checks passed;2 desks,32 claims; Warden bench and A14 chairs retained'):format(checks))
