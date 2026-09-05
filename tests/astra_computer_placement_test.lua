-- All fourteen upright-computer placements, including GYM/MART aliases.
-- Bill's two CRT placements and stool pins retain their dedicated live test.
local root=os.getenv('ASTRA_COMPUTER_ROOT') or os.getenv('ASTRA_CANDIDATE')or'.'
local baseline=assert(os.getenv('ASTRA_COMPUTER_BASELINE'))
local H=dofile('tests/astra_fixture.lua');local F=dofile('tests/astra_scene_fixture.lua')
local before,after=F.runtime(baseline),F.runtime(root)
-- A19 stairs are tested live separately; preserve this historical computer scene.
after.spec.tilesets=H.historicalPublicPins(after.spec.tilesets,before.spec.tilesets)
local checks=0
local function ok(v,msg)checks=checks+1;if not v then error('FAIL '..msg,0)end end
local function eq(a,b,msg)ok(a==b,msg..' expected '..tostring(b)..' got '..tostring(a))end
local function same(a,b,msg)
 eq(type(a),type(b),msg..' type')
 if type(a)~='table'then eq(a,b,msg);return end
 for k,v in pairs(a)do same(v,b[k],msg..'.'..tostring(k))end
 for k in pairs(b)do ok(a[k]~=nil,msg..' no extra '..tostring(k))end
end
same(after.spec.heights,before.spec.heights,'all original class heights')
same(H.historicalPins(after.spec.tilesets,before.spec.tilesets),before.spec.tilesets,'all actor and equipment support pins')
local n=0
for _,c in ipairs({{'GYM','lab_computers','gym',1},
 {'POKECENTER','center_pc','pokecenter',11},{'MART','center_pc','pokecenter',1}})do
 local t,ot=F.template(after,c[1],c[2]),F.template(before,c[1],c[2])
 for k,v in pairs(ot)do if k~='parts'then same(t[k],v,'original '..c[1]..'/'..c[2]..' profile '..k)end end
 eq(#t.parts,#ot.parts,'same separate authored desk objects')
 for j,p in ipairs(t.parts)do local case=p.case;p.case=nil;same(p,ot.parts[j],'unchanged original part placement/source bands');p.case=case end
 local data,w=H.atlas(assert(os.getenv('ASTRA_FURNITURE_ATLASES'))..'/'..c[3]..'.rgba')
 local places=0
 for id,def in pairs(F.maps)do if def.tileset==c[1]then
  local map=F.Map.new(def,F.tilesets[c[1]]);local matches=F.matches(t,map)
  if #matches>0 then
   places=places+#matches;n=n+#matches
   local a,b=F.build(after,map,data,w),F.build(before,map,data,w)
   for _,field in ipairs({'tileAt','shapeAt','ground','skip'})do same(a[field],b[field],id..' exact '..field)end
   for z=0,map.heightCells-1 do for x=0,map.widthCells-1 do
    local tile,walk=map:cellTile(x,z),map:isWalkableCell(x,z)
    eq(after.scene.groundAt(map,x,z),before.scene.groundAt(map,x,z),id..' original support')
    eq(map:cellTile(x,z),tile,id..' original interaction tile');eq(map:isWalkableCell(x,z),walk,id..' original collision')
   end end
   for _,p in ipairs(matches)do for dz=0,#t.tiles-1 do for dx=0,#t.tiles[1]-1 do
    ok(a.skip[F.key(p[1]+dx,p[2]+dz)],id..' each original computer tile remains claimed')
   end end end
   print(id..': original computer grid, claims, support and collision retained')
  end
 end end
 eq(places,c[4],c[1]..' original computer placements')
end
eq(n,13,'thirteen retained placements; the separately tested Oak table owns the fourteenth')
print(('%d computer real-map placement/support checks passed'):format(checks))
