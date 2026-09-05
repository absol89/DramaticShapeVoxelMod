-- Four render-only LOBBY round tables; their blocked-cell pins remain unchanged.
local root=os.getenv('ASTRA_CANDIDATE')or'.';local baseline=assert(os.getenv('ASTRA_FULL_BASELINE'))
local H=dofile('tests/astra_fixture.lua');local F=dofile('tests/astra_scene_fixture.lua')
local before,after=F.runtime(baseline),F.runtime(root);local checks=0
-- Historical release scope; A19 live tests own the exact new public cells/models.
after.spec.tilesets=H.historicalPublicPins(after.spec.tilesets,before.spec.tilesets)
local function ok(v,msg)checks=checks+1;if not v then error('FAIL '..msg,0)end end
local function eq(a,b,msg)ok(a==b,msg..' expected '..tostring(b)..' got '..tostring(a))end
local function same(a,b,msg)
 eq(type(a),type(b),msg..' type');if type(a)~='table'then eq(a,b,msg);return end
 for k,v in pairs(a)do same(v,b[k],msg..'.'..tostring(k))end
 for k in pairs(b)do ok(a[k]~=nil,msg..' no extra '..tostring(k))end
end
local t=assert(F.template(after,'LOBBY','lobby_round_table'))
same(t.tiles,{{9,39,39,25},{54,55,55,57},{70,55,55,71},{85,86,87,55}},'exact round tabletop and pedestal source grid')
local expected={CELADON_DINER={{0,4},{0,10}},CELADON_MART_ROOF={{8,4},{16,8}}}
local data,w,h=H.atlas(assert(os.getenv('ASTRA_FULL_ATLASES'))..'/lobby.rgba')
local quads=H.building(root,t.id,data,w,h,nil,nil,'LOBBY');eq(#quads,748,'one bounded model per table')
local maps,instances,tableCells,actors,tableClaims=0,0,0,0,0
for id,def in pairs(F.maps)do if def.tileset=='LOBBY'then
 maps=maps+1;local map=F.Map.new(def,F.tilesets.LOBBY);local places=F.matches(t,map)
 same(places,expected[id]or{},'exact four table origins across all LOBBY maps')
 local tables,seats,seatCells={},{},{}
 local seatTemplate=assert(F.template(after,'LOBBY','lobby_stool'))
 for _,p in ipairs(F.matches(seatTemplate,map))do
  seatCells[(p[1]/2)..':'..(p[2]/2)]=true
  for z=0,1 do for x=0,1 do seats[F.key(p[1]+x,p[2]+z)]=true end end
 end
 for _,p in ipairs(places)do
  instances=instances+1
  for z=0,3 do for x=0,3 do local k=F.key(p[1]+x,p[2]+z);ok(not seats[k],'table never overlaps repaired seats');tables[k]=true end end
  for z=p[2]/2,p[2]/2+1 do for x=p[1]/2,p[1]/2+1 do
   tableCells=tableCells+1;ok(not map:isWalkableCell(x,z),'all actual table cells remain blocked')
   eq(after.scene.groundAt(map,x,z),before.scene.groundAt(map,x,z),'blocked table pin is deliberately preserved despite level visual top8')
   ok(not map.warpAt[z*map.widthCells+x]and not map.signAt[z*map.widthCells+x],'no warp or sign is claimed by a table')
   for _,o in ipairs(def.objects or{})do if o.x==x and o.y==z then actors=actors+1 end end
  end end
 end
 local records={};local stamp=after.build.stamp
 after.build.stamp=function(S,mp,q,x,z,bw,bh,template)
  local first=#S.objectQuads+1;stamp(S,mp,q,x,z,bw,bh,template)
  if template.id==t.id or template.id=='lobby_stool'then records[#records+1]={id=template.id,first=first,last=#S.objectQuads}end
 end
 local a,b=F.build(after,map,data,w),F.build(before,map,data,w);after.build.stamp=stamp
 local drop,n={},0
 for _,p in ipairs(records)do
  if p.id==t.id then n=n+1;eq(p.last-p.first+1,#quads,'exactly one round table shell per placement')end
  for j=p.first,p.last do drop[j]=true end
 end
 eq(n,#places,'no duplicated table or phantom full-grid matches')
 local retained={};for j,q in ipairs(a.objectQuads)do if not drop[j]then retained[#retained+1]=q end end
 same(retained,b.objectQuads,'all previously accepted object UV/geometry/shading remains exact')
 same(a.tileAt,b.tileAt,'all original source and interaction tiles retained')
 for _,field in ipairs({'shapeAt','ground','skip'})do
  for k,v in pairs(b[field])do if not tables[k]and not seats[k]then same(a[field][k],v,'all non-target '..field..' retained')end end
  for k,v in pairs(a[field])do if not tables[k]and not seats[k]then same(v,b[field][k],'no extra non-target '..field)end end
 end
 for k in pairs(tables)do tableClaims=tableClaims+1;ok(a.skip[k],'original mixed-height table art is claimed once');eq(a.shapeAt[k].class,'building','only rendering ownership changes')end
 for z=0,map.heightCells-1 do for x=0,map.widthCells-1 do
  local want=seatCells[x..':'..z]and 5 or before.scene.groundAt(map,x,z)
  eq(after.scene.groundAt(map,x,z),want,'all source support remains exact except separately approved stool5')
 end end
 if #places>0 then print(id..': '..#places..' round tables;blocked support pins retained; no actors/items/signs/warps on their footprints')end
end end
eq(maps,12,'all twelve LOBBY maps scanned');eq(instances,4,'only four intended tables');eq(tableCells,16,'sixteen actual blocked table cells');eq(actors,0,'no NPC or item stands on any table')
eq(tableClaims,64,'only64 original source tiles claimed by round tables')
print(('%d round-table placement/ownership/support checks passed;4 exact tables,64 claims; all actor support retained apart from accepted seats'):format(checks))
