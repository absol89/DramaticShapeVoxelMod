-- Exercise the actual queued terrain job's disk-cache decision. Only
-- storage/GPU adapters are replaced; the opt-in predicate and ShipHull
-- preparation itself are the production functions.
local root=os.getenv('ASTRA_CANDIDATE')or'.'
local T=dofile(root..'/tests/astra_ship_hull_fixture.lua');local H,F=T.H,T.F
local data=H.atlas(os.getenv('ASTRA_SHIP_PORT_ATLAS')or'../artifacts/battle-art-astra-remaining-pass/ship-exterior/private/ship_port.rgba')
local n=0;local function eq(a,b,m)n=n+1;assert(a==b,m..': '..tostring(a)..' ~= '..tostring(b))end
local function replace(fn,name,value)
 for i=1,100 do local k=debug.getupvalue(fn,i);if not k then break end
  if k==name then debug.setupvalue(fn,i,value);return end
 end
 error('missing actual mesh job dependency '..name)
end
for _,case in ipairs({{id='VERMILION_DOCK',enabled=true,rebuild=true},
                      {id='VERMILION_DOCK',enabled=false,rebuild=false},
                      {id='PALLET_TOWN',enabled=true,rebuild=false}})do
 local r=T.runtime(root)
 if not case.enabled then r.spec.tilesets.SHIP_PORT.ship_hull=nil end
 local diskReads,builds=0,0
 local disk={available=function()return false end,
  loadTerrain=function()diskReads=diskReads+1;return{terrain={},water={},spans={}}end,
  saveTerrain=function()return true end}
 local mods={VoxelMeshDisk=disk,CommunityVisuals={customCutTrees=function()return false end,customSigns=function()return false end,customTrees=function()return false end,customPillars=function()return false end}}
 local V={data=r.V.data,require=function(name)return mods[name]or r.V.require(name)end}
 local mesher=assert(loadfile(root..'/lib/ChunkMesher.lua'))(V)
 local job=H.upvalue(mesher.pump,'runJob')
 local entry={grass=false,flowers=false,figures=false}
 replace(job,'entry',function()return entry end)
 replace(job,'mapHasVisualObjects',function()return false end)
 replace(job,'newSink',function()return{finish=function()return false end,raw=function()return{}end}end)
 replace(job,'meshFromRaw',function()return false end)
 replace(job,'runGeometry',function(map)
  builds=builds+1;r.prepare(map,data)
 end)
 local d=F.maps[case.id];local map=F.Map.new(d,F.tilesets[d.tileset])
 job({map=map,id=map.id,slot='full',gen=0})
 eq(builds,case.rebuild and 1 or 0,'only enabled dock rebuilds a session hull')
 eq(diskReads,case.rebuild and 0 or 1,'ordinary disk cache remains available')
 eq(r.ship.diagnostics()~=nil,case.rebuild,'required session mesh is actually registered by public Buildings.prepare')
 eq(entry.full,false,'terrain job still completes normally')
end
print(n..' ship hull disk-session checks passed; actual queued job bypasses only enabled dock, other cache paths retained')