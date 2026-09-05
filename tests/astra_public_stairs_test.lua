-- Exact source-grid + actual-warp public stair regression. All other pins stay intact.
local root=os.getenv('ASTRA_CANDIDATE')or'.'
local baseline=assert(os.getenv('ASTRA_PUBLIC_BASELINE'))
local atlas=assert(os.getenv('ASTRA_PUBLIC_ATLASES'))
local T=dofile('tests/astra_stair_fixture.lua');local H,F=T.H,T.F
local before,after=F.runtime(baseline),F.runtime(root)
-- A20 cave steps, GATE seats and the dock hull have separate live regressions.
-- Normalize only their exact new profiles for this historical public-stair oracle.
after.spec.tilesets=H.historicalRemainingPins(after.spec.tilesets,before.spec.tilesets)
local checks=0
local function ok(v,m)checks=checks+1;if not v then error('FAIL '..m,0)end end
local function eq(a,b,m)ok(a==b,m..' expected '..tostring(b)..' got '..tostring(a))end
local function same(a,b,m)
 eq(type(a),type(b),m..' type');if type(a)~='table'then eq(a,b,m);return end
 for k,v in pairs(a)do same(v,b[k],m..'.'..tostring(k))end
 for k in pairs(b)do ok(a[k]~=nil,m..' extra key')end
end
local targets={
  { 'CELADON_MART_4F', 12, 1, 'stair_down_n', {10,11,26,27} },
  { 'CELADON_MART_4F', 16, 1, 'stair_n', {12,13,28,29} },
  { 'CELADON_MART_ROOF', 15, 2, 'stair_down_n', {10,11,26,27} },
  { 'LANCES_ROOM', 24, 16, 'stair_e', {72,73,74,75} },
  { 'SILPH_CO_4F', 26, 0, 'stair_n', {90,91,67,52} },
  { 'SILPH_CO_7F', 16, 0, 'stair_n', {90,91,67,52} },
  { 'SILPH_CO_2F', 26, 0, 'stair_n', {90,91,67,52} },
  { 'SILPH_CO_8F', 16, 0, 'stair_n', {90,91,67,52} },
  { 'SILPH_CO_3F', 24, 0, 'stair_n', {90,91,67,52} },
  { 'CELADON_MART_1F', 12, 1, 'stair_n', {12,13,28,29} },
  { 'GAME_CORNER', 17, 4, 'stair_down_n', {10,11,26,27} },
  { 'CELADON_MART_5F', 12, 1, 'stair_n', {12,13,28,29} },
  { 'CELADON_MART_5F', 16, 1, 'stair_down_n', {10,11,26,27} },
  { 'SILPH_CO_9F', 14, 0, 'stair_n', {90,91,67,52} },
  { 'SILPH_CO_6F', 16, 0, 'stair_n', {90,91,67,52} },
  { 'SILPH_CO_5F', 24, 0, 'stair_n', {90,91,67,52} },
  { 'SILPH_CO_1F', 26, 0, 'stair_n', {90,91,67,52} },
  { 'SILPH_CO_11F', 9, 0, 'stair_down_e', {5,6,21,22} },
  { 'SILPH_CO_10F', 10, 0, 'stair_n', {90,91,67,52} },
  { 'INDIGO_PLATEAU_LOBBY', 8, 0, 'stair_down_n', {92,93,94,95} },
  { 'CELADON_MART_2F', 12, 1, 'stair_down_n', {10,11,26,27} },
  { 'CELADON_MART_2F', 16, 1, 'stair_n', {12,13,28,29} },
  { 'CELADON_MART_3F', 12, 1, 'stair_n', {12,13,28,29} },
  { 'CELADON_MART_3F', 16, 1, 'stair_down_n', {10,11,26,27} },
}
eq(#targets,24,'audited twenty-four placements')
local wanted={};for _,t in ipairs(targets)do wanted[t[1]]=wanted[t[1]]or{};wanted[t[1]][t[3]*4096+t[2]]=t end
local changed=0
for id,def in pairs(F.maps)do
 local map=F.Map.new(def,F.tilesets[def.tileset]);local a,b=after.shapes.forMap(map),before.shapes.forMap(map)
 for tile=0,b.count-1 do same(a[tile],b[tile],id..' original tile-level pin')end
 for z=0,map.heightCells-1 do for x=0,map.widthCells-1 do
  eq(after.scene.groundAt(map,x,z),before.scene.groundAt(map,x,z),id..' original actor ride height')
  local t=wanted[id]and wanted[id][z*4096+x]
  for dz=0,1 do for dx=0,1 do
   local tx,tz=x*2+dx,z*2+dz;local tile=map:tileAt(tx,tz)
   local sa,sb=after.shapes.at(map,a,tile,tx,tz),before.shapes.at(map,b,tile,tx,tz)
   if t then
    eq(tile,t[5][dz*2+dx+1],'complete original source pattern');eq(sa.class,t[4],'source flight direction')
    ok(sa.authored and sa.warpStair,'authored exact-warp shape precedes door fold');eq(sa.h,16,'flight rise16');changed=changed+1
   else same(sa,sb,id..' every non-target tile shape unchanged')end
  end end
 end end
end
eq(changed,96,'only 96 source tiles resolved differently')
-- Explicit negative aliases: two complete Indigo door patterns and Prize counter halves.
for _,v in ipairs({{'INDIGO_PLATEAU_LOBBY',12,4},{'INDIGO_PLATEAU_LOBBY',14,4},{'GAME_CORNER_PRIZE_ROOM',2,1},{'GAME_CORNER_PRIZE_ROOM',4,1},{'GAME_CORNER_PRIZE_ROOM',6,1}})do
 local d=F.maps[v[1]];local map=F.Map.new(d,F.tilesets[d.tileset]);ok(not map:warpAtCell(v[2],v[3]),'negative alias has no warp')
 local s=after.shapes.forMap(map);for dz=0,1 do for dx=0,1 do local x,z=v[2]*2+dx,v[3]*2+dz;ok(not after.shapes.at(map,s,map:tileAt(x,z),x,z).warpStair,'door/counter alias never becomes a stair')end end
end
local files={LOBBY='lobby',DOJO='gym',MART='pokecenter',INTERIOR='interior',FACILITY='facility'}
local totals={};local worlds={}
for _,t in ipairs(targets)do
 local def=F.maps[t[1]];local map=F.Map.new(def,F.tilesets[def.tileset]);local x,z=t[2],t[3]
 local data,w,h=H.atlas(atlas..'/'..files[def.tileset]..'.rgba')
 local r=T.runtime(root,data);local S=r.render(map,{x*2,x*2+1,z*2,z*2+1})
 local down=t[4]:match('down')~=nil;local north=t[4]:match('_n$')~=nil
 local warp=map:warpAtCell(x,z);ok(warp and F.maps[warp.def.destMap].warps[warp.def.destWarp],'unchanged actual warp and destination')
 eq(after.scene.groundAt(map,x,z),0,'warp support remains floor-level')
 eq(map:isWalkableCell(x,z),true,'original collision allows entry')
 local n=0;for k in pairs(S.skip)do n=n+1 end;eq(n,4,'only exact cell claimed')
 for dz=0,1 do for dx=0,1 do local k=F.key(x*2+dx,z*2+dz);ok(S.skip[k],'every source quadrant owned');if down then eq(S.ground[k],nil,'no sheet across pit')else eq(S.ground[k],false,'common ground under rise')end end end
 local source={};for _,tile in ipairs(t[5])do source[tile]=true end
 local tops=0
 for _,q in ipairs(S.objectQuads)do
  local a,b,c=q[1],q[2],q[3];local u={b[1]-a[1],b[2]-a[2],b[3]-a[3]};local v={c[1]-a[1],c[2]-a[2],c[3]-a[3]};local normal={u[2]*v[3]-u[3]*v[2],u[3]*v[1]-u[1]*v[3],u[1]*v[2]-u[2]*v[1]}
  ok(math.abs(normal[1])+math.abs(normal[2])+math.abs(normal[3])>0,'finite nondegenerate stair face')
  local tile
  for j,p in ipairs(q)do
   for ax=1,3 do ok(p[ax]==p[ax]and math.abs(p[ax])<1e6,'finite coordinate')end
   ok(p[1]>=x*16 and p[1]<=(x+1)*16 and p[3]>=z*16 and p[3]<=(z+1)*16,'unchanged16x16 footprint')
   ok(down and p[2]>=-16 and p[2]<=0 or not down and p[2]>=0 and p[2]<=16,'signed source rise')
   local uv=q.uv[j];local ax,ay=uv[1]*w,uv[2]*h
   local st=math.floor(ay/8)*16+math.floor(ax/8);ok(source[st],'own stair source tile, no floor/wall aliases')
   tile=tile or st;eq(st,tile,'every face stays inside one real source atlas tile')
  end
  for ax=1,3 do
   local lo,hi=math.huge,-math.huge;for _,p in ipairs(q)do lo=math.min(lo,p[ax]);hi=math.max(hi,p[ax])end
   ok(hi-lo<=8.000001,'maximum8px world face');if hi>lo+.000001 then eq(math.floor((lo+.000001)/8),math.floor((hi-.000001)/8),'face split at8px lattice')end
  end
  if normal[2]~=0 then
   ok(normal[2]<0,'existing horizontal winding convention');tops=tops+1
   local px,pz=(a[1]+c[1])/2-x*16,(a[3]+c[3])/2-z*16
   local rise=north and(16-math.floor(pz/4)*4)or(math.floor(px/4)+1)*4
   eq(a[2],(down and-1 or 1)*rise,'correct flight direction and slope')
   if north then
    for wz=a[3]+.5,c[3]-.5 do for wx=a[1]+.5,c[1]-.5 do
     local sx,sy=math.floor(wx-x*16),math.floor(wz-z*16)
     local ti=t[5][math.floor(sy/8)*2+math.floor(sx/8)+1];local ex,ey=ti%16*8+sx%8,math.floor(ti/16)*8+sy%8
     local fx,fz=(wx-a[1])/(c[1]-a[1]),(wz-a[3])/(c[3]-a[3])
     local ax=(q.uv[1][1]+fx*(q.uv[2][1]-q.uv[1][1])+fz*(q.uv[4][1]-q.uv[1][1]))*w
     local ay=(q.uv[1][2]+fx*(q.uv[2][2]-q.uv[1][2])+fz*(q.uv[4][2]-q.uv[1][2]))*h
     eq(math.floor(ax),ex,'exact original tread source column');eq(math.floor(ay),ey,'exact original tread source row')
    end end
   end
  end
 end
 eq(tops,8,'four treads split only at source/world midline')
 totals[t[4]]=totals[t[4]]or{0,0};totals[t[4]][1]=totals[t[4]][1]+1;totals[t[4]][2]=totals[t[4]][2]+#S.objectQuads
 -- Run the actual complete Structures pipeline, including its earlier door fold.
 if not worlds[t[1]]then
  for _,name in ipairs({'customCourtyards','customWalls','customPillars','customTrees'})do r.module('CommunityVisuals')[name]=function()return false end end
  worlds[t[1]]=r.stairs.forMap(map)
  local oldRuntime=T.runtime(baseline,data)
  for _,name in ipairs({'customCourtyards','customWalls','customPillars','customTrees'})do oldRuntime.module('CommunityVisuals')[name]=function()return false end end
  local original=oldRuntime.stairs.forMap(map);local current=worlds[t[1]];local excluded={}
  for _,stair in pairs(wanted[t[1]])do for dz=0,1 do for dx=0,1 do excluded[F.key(stair[2]*2+dx,stair[3]*2+dz)]=true end end end
  -- The palm addition has its own full-map/source regression. Exclude
  -- only their complete eight-tile drawings, never a neighborhood or wall band.
  for _,profile in ipairs(after.spec.buildings[def.tileset]or{})do if profile.id=='facility_palm'or profile.id=='facility_cabinet'then
   for _,pos in ipairs(F.matches(profile,map))do for dz=0,3 do for dx=0,1 do excluded[F.key(pos[1]+dx,pos[2]+dz)]=true end end end
  end end
  for tz=0,def.height*4-1 do for tx=0,def.width*4-1 do local k=F.key(tx,tz)
   if not excluded[k]then for _,field in ipairs({'tileAt','shapeAt','skip','ground','doorFold'})do
    same(current[field]and current[field][k],original[field]and original[field][k],t[1]..' full renderer preserves neighboring wall/door/floor '..field)
   end end
  end end
 end
 local full=worlds[t[1]]
 for dz=0,1 do for dx=0,1 do local k=F.key(x*2+dx,z*2+dz);ok(full.skip[k],'full pass owns stair tile');ok(not full.doorFold[k],'generic door fold cannot swallow an authored stair');eq(full.shapeAt[k].class,t[4],'full pass retains precise stair shape')end end
end
-- Remove only the new optional rules: fallback behavior remains byte-for-byte A18.
local fallback=F.runtime(root)
fallback.spec.tilesets=H.historicalRemainingPins(fallback.spec.tilesets,before.spec.tilesets)
for _,e in pairs(fallback.spec.tilesets)do e.warp_stairs=nil end
for id,def in pairs(F.maps)do
 local map=F.Map.new(def,F.tilesets[def.tileset]);local a,b=fallback.shapes.forMap(map),before.shapes.forMap(map)
 for z=0,map.heightCells-1 do for x=0,map.widthCells-1 do
  local tx,tz=x*2,z*2;local tile=map:tileAt(tx,tz)
  same(fallback.shapes.at(map,a,tile,tx,tz),before.shapes.at(map,b,tile,tx,tz),'no-rule default geometry classification exact')
 end end
end
-- Game Corner is a live block mutation, not a different map/tileset.
-- Exercise the actual setBlock + renderer invalidation route with one cached
-- TileShape table. A cached open pit must neither persist when hidden nor
-- prevent a closed-first visit from acquiring its steps after the reveal.
local function clone(v)if type(v)~='table'then return v end;local o={};for k,x in pairs(v)do o[k]=clone(x)end;return o end
local field=dofile(assert(os.getenv('ASTRA_GENERATED'))..'/field.lua').gameCornerPoster
local game=F.Map.new(clone(F.maps.GAME_CORNER),F.tilesets.LOBBY)
game:setBlock(field.x,field.y,field.closedBlock)
local gd=H.atlas(atlas..'/lobby.rgba');local live=T.runtime(root,gd)
for _,name in ipairs({'customCourtyards','customWalls','customPillars','customTrees'})do live.module('CommunityVisuals')[name]=function()return false end end
local cached=live.shapes.forMap(game)
for _,state in ipairs({false,true,false,true})do
 game:setBlock(field.x,field.y,state and field.openBlock or field.closedBlock)
 eq(live.shapes.forMap(game),cached,'poster transition reuses the exact cached rule table')
 local shell=live.render(game,{34,35,8,9});eq(#shell.objectQuads,state and 32 or 0,'closed/open source dynamically controls the actual stair pass')
 for dz=0,1 do for dx=0,1 do
  local tx,tz=34+dx,8+dz;local shape=live.shapes.at(game,cached,game:tileAt(tx,tz),tx,tz)
  eq(not not shape.warpStair,state,'no stale hidden/revealed stair classification')
 end end
 eq(live.scene.groundAt(game,17,4),before.scene.groundAt(game,17,4),'poster transition preserves original support')
 live.stairs.invalidate(game.id)
 local full=live.stairs.forMap(game);local count=0
 for _,q in ipairs(full.objectQuads)do if q.interiorStairRole then count=count+1 end end
 eq(count,state and 32 or 0,'complete rebuilt scene follows ordinary poster reveal')
end
local revisited=F.Map.new(clone(F.maps.GAME_CORNER),F.tilesets.LOBBY)
revisited:setBlock(field.x,field.y,field.closedBlock)
eq(live.shapes.forMap(revisited),cached,'same-map revisit uses cached immutable candidates')
eq(#live.render(revisited,{34,35,8,9}).objectQuads,0,'prior open cache cannot reveal a closed revisit')
print('Game Corner closed/open/closed/open and closed revisit: real setBlock, same cached shapes, full renderer rebuild PASS')
for class,v in pairs(totals)do print(class,v[1]..' instances',v[2]..' quads')end
print(('Public stairs:24 exact warps/96tiles; all source treads, aliases and actor support preserved. %d checks passed'):format(checks))
