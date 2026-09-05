-- Actual dock ownership and engine snapshot/departure drawing contract.
local root=os.getenv('ASTRA_CANDIDATE')or'.'
local baseline=os.getenv('ASTRA_REMAINING_BASELINE')or'../artifacts/battle-art-astra-remaining-pass/baseline-mod'
local T=dofile(root..'/tests/astra_ship_hull_fixture.lua');local H,F=T.H,T.F
local r=T.runtime(root);local before=F.runtime(baseline)
local data,aw,ah=H.atlas(os.getenv('ASTRA_SHIP_PORT_ATLAS')or'../artifacts/battle-art-astra-remaining-pass/ship-exterior/private/ship_port.rgba')
local n=0;local function ok(v,m)n=n+1;assert(v,m)end
local function eq(a,b,m)ok(a==b,m..': '..tostring(a)..' ~= '..tostring(b))end
local function same(a,b,m)
 eq(type(a),type(b),m)
 if type(a)~='table'then eq(a,b,m);return end
 for k,v in pairs(a)do same(v,b[k],m..'.'..tostring(k))end
 for k in pairs(b)do ok(a[k]~=nil,m..' unexpected '..tostring(k))end
end
local function copy(v)if type(v)~='table'then return v end;local o={};for k,x in pairs(v)do o[k]=copy(x)end;return o end
local map=F.Map.new(F.maps.VERMILION_DOCK,F.tilesets.SHIP_PORT)
local snapshot=copy(map.def)
local shapeBefore=before.shapes.forMap(map);local shapeAfter=r.shapes.forMap(map)
same(shapeAfter,shapeBefore,'all dock pins/support remain exact')
local old={tileAt={},shapeAt={},skip={},ground={},objectQuads={}}
for z=-2,map.def.height*4+1 do for x=-2,map.def.width*4+1 do
 local k=F.key(x,z);local tile=map:tileAt(x,z);old.tileAt[k]=tile;old.shapeAt[k]=before.shapes.at(map,shapeBefore,tile,x,z)
end end
local walk={}
for z=0,map.heightCells-1 do for x=0,map.widthCells-1 do walk[z*map.widthCells+x]={map:isWalkableCell(x,z),map:isWaterCell(x,z),map:warpAtCell(x,z)}end end
local S=r.prepare(map,data);local changed=0
for k,tile in pairs(old.tileAt)do
 local z=math.floor(k/4096)-64;local x=k%4096-64
 local target=x>=20 and x<=35 and z>=6 and z<=11
 if target then
  changed=changed+1;eq(S.tileAt[k],20,'independent hull reveals original sea tile')
  same(S.shapeAt[k],{class='water',h=-2,art='flat',flat=true,authored=true},'only private terrain receives sea datum')
  eq(S.skip[k],nil,'water belongs to terrain pass');eq(S.ground[k],nil,'no additional ground duplicate')
 else
  eq(S.tileAt[k],tile,'source outside vessel retained')
  same(S.shapeAt[k],old.shapeAt[k],'all other private terrain shapes exact')
 end
end
eq(changed,96,'only complete16x6 body is replaced in private terrain')
same(S.shipHull,{x=160,z=48},'body original world origin')
eq(#S.objectQuads,0,'body has one session mesh, no duplicated static hull mesh')
same(map.def,snapshot,'building preparation never mutates actual map source/events')
for z=0,map.heightCells-1 do for x=0,map.widthCells-1 do
 local w=walk[z*map.widthCells+x]
 eq(map:isWalkableCell(x,z),w[1],'original walking collision');eq(map:isWaterCell(x,z),w[2],'original surf eligibility');eq(map:warpAtCell(x,z),w[3],'original warp identity')
 eq(r.scene.groundAt(map,x,z),before.scene.groundAt(map,x,z),'all dock actor support unchanged')
end end
local warp=map:warpAtCell(14,2);ok(warp and warp.def.destMap=='SS_ANNE_1F','actual boarding warp retained')
eq(r.scene.groundAt(map,14,2),0,'boarding warp floor remains0')
-- Fresh public build declines any single-tile near miss. Caching source
-- material still permits a departure begun after the map erased its ship.
local read=map.tileAt
map.tileAt=function(self,x,z)if x==20 and z==7 then return 20 end;return read(self,x,z)end
local nope=r.prepare(map,data);eq(nope.shipHull,nil,'one changed body tile declines exact ownership')
eq(nope.tileAt[F.key(21,7)],17,'near miss retains neighboring source art')
map.tileAt=read
-- Preserve all data outside independently tested cave/gate/interior additions.
local actual=copy(r.spec)
actual.tilesets.SHIP_PORT.ship_hull=nil
actual.tilesets.CAVERN.cave_steps=nil
local gate,oldGate=actual.tilesets.GATE,before.spec.tilesets.GATE
if gate.stool then
 same(gate.stool,{2,3,18,19},'only four approved GATE source pins')
 local keep={};for _,t in ipairs(oldGate.billboard)do if t~=2 and t~=3 and t~=18 and t~=19 then keep[#keep+1]=t end end
 same(gate.billboard,keep,'other GATE billboards remain exact')
 eq(gate.heights.stool,5,'separately tested source-height5 gate stool')
 gate.stool=copy(oldGate.stool);gate.billboard=copy(oldGate.billboard);gate.heights.stool=oldGate.heights and oldGate.heights.stool
 if not next(gate.heights)then gate.heights=nil end
end
local selected={ship_cabin_table=true,ship_house_table=true,ship_captain_desk=true,ship_kitchen_table=true,ship_bunk=true,ship_kitchen_counter=true,ship_kitchen_hob=true,ship_captain_chair=true,ship_truncated_table=true,gate_stool=true}
for _,family in ipairs({'SHIP','GATE'})do
 local list={};for _,t in ipairs(actual.buildings[family]or{})do if not selected[t.id]then list[#list+1]=t end end
 actual.buildings[family]=#list>0 and list or nil
end
-- A21 bicycles are independently tested; every existing model stays in this comparison.
actual.buildings=H.historicalPublicBuildings(actual.buildings,before.spec.buildings)
same(actual,before.spec,'all other profiles/templates/map overrides preserved')
-- Real0.2.27 snapshot: first two rows remain fixed gangway, last six move.
local tiles={}
for z=0,7 do local row={};tiles[z+1]=row;for x=0,15 do row[x+1]=map:tileAt(20+x,4+z)end end
local state={map=map}
same(r.ship.pose(state),{x=160,y=-2,z=48,gone=false},'moored original source position')
local originalTiles=copy(tiles)
local cached=r.ship.diagnostics();ok(cached and cached.model and #cached.quads>0,'publicprepare creates session hull')
eq(#cached.verts,#cached.quads*4,'all body vertices prepared before first draw')
eq(#cached.indices,#cached.quads*6,'all body indices prepared before first draw')
ok(r.ticks>=#cached.quads,'body assembly cooperates with the build budget')
local previous
for off=0,128 do
 state.shipAnim={px=160,py=32,tiles=tiles,off=off,gone=false}
 local p=r.ship.pose(state)
 same(p,{x=160-off,y=-2,z=48,gone=false,gangway={x=224,z=32}},'engine offset moves only body')
 r.draws={};r.shadows={};r.ship.draw(state,'ship-atlas',false);r.ship.draw(state,'ship-atlas',true)
 eq(#r.draws,2,'one body and one fixed gangway');eq(#r.shadows,2,'same sunlight geometry')
 eq(cached.verts,nil,'successful upload releases cached CPU vertices')
 eq(cached.indices,nil,'successful upload releases cached CPU indices')
 for i=1,2 do
  eq(r.draws[i].mesh,r.shadows[i].mesh,'opaque/shadow share cached mesh')
  same(r.draws[i].matrix,r.shadows[i].matrix,'opaque/shadow share exact position')
 end
 eq(r.draws[1].matrix[4],160-off,'body follows every engine offset')
 eq(r.draws[1].matrix[8],-2,'hull waterline datum')
 eq(r.draws[1].matrix[12],48,'departure never drifts north/south')
 eq(r.draws[2].matrix[4],224,'gangway never slides with body')
 eq(r.draws[2].matrix[8],0,'fixed gangway remains at actor floor')
 eq(r.draws[2].matrix[12],32,'fixed gangway source origin')
 local sig=r.ship.signature(state);if previous then ok(sig~=previous,'shadow cache invalidates every departure offset')end;previous=sig
 eq(r.ship.diagnostics(),cached,'one source/model cache across motion')
end
state.shipAnim.gone=true
r.draws={};r.ship.draw(state,'atlas',false)
eq(#r.draws,1,'departed body disappears; gangway retained')
eq(r.draws[1].matrix[4],224,'only fixed gangway remains')
ok(r.ship.signature(state)~=previous,'gone state invalidates sunlight cache')
same(tiles,originalTiles,'departure never mutates engine snapshot')
same(map.def,snapshot,'departure never mutates map source/collision/events')
-- Engine erases body tiles before playing the cached snapshot. A fresh
-- session prepares the body from the original profile and follows that snapshot.
local departed=F.Map.new(F.maps.VERMILION_DOCK,F.tilesets.SHIP_PORT)
local nativeRead=departed.tileAt
departed.tileAt=function(self,x,z)if x>=20 and x<=35 and z>=4 and z<=11 then return 20 end;return nativeRead(self,x,z)end
local fresh=T.runtime(root);local erased=fresh.prepare(departed,data)
eq(erased.shipHull,nil,'erased dock source never recreates a static hull')
ok(fresh.ship.diagnostics()~=nil,'fresh session caches original drawing despite erased map')
local active={map=departed,shipAnim={px=160,py=32,tiles=copy(tiles),off=64,gone=false}}
fresh.ship.draw(active,'atlas',false);eq(#fresh.draws,2,'departure survives a fresh terrain/session rebuild')
eq(fresh.draws[1].matrix[4],96,'fresh cached body follows native snapshot offset')
active.shipAnim.gone=true;fresh.draws={};fresh.ship.draw(active,'atlas',false);eq(#fresh.draws,1,'fresh gone state shows no body')
active.shipAnim=nil;fresh.draws={};fresh.ship.draw(active,'atlas',false);eq(#fresh.draws,0,'departed revisit has no leftover body or synthetic gangway')
for _,bad in ipairs({-1,129,0/0,math.huge,-math.huge,'64'})do
 state.shipAnim={px=160,py=32,tiles=tiles,off=bad}
 eq(r.ship.pose(state),nil,'invalid offset cannot emit geometry')
end
state.shipAnim={px=160,py=32,tiles=copy(tiles),off=0}
state.shipAnim.tiles[3][1]=99;eq(r.ship.pose(state),nil,'foreign source snapshot declines')
for id,d in pairs(F.maps)do if id~='VERMILION_DOCK'then
 local elsewhere={map=F.Map.new(d,F.tilesets[d.tileset]),shipAnim={px=160,py=32,tiles=tiles,off=0}}
 eq(r.ship.pose(elsewhere),nil,'other map cannot acquire vessel');eq(r.ship.signature(elsewhere),'','other map shadow key unchanged')
 r.draws={};r.ship.draw(elsewhere,'atlas',false);eq(#r.draws,0,'other map render is no-op')
end end
print(n..' ship hull placement/departure checks passed;96 private water tiles, all dock support/warps exact,129 offsets, fixed gangway, gone/rebuild/revisit and other maps no-op')