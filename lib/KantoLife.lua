-- One bounded native batch: shaped fluttering butterflies and night fireflies.
local V=...;local M={MAX_VERTICES=6000};local mesh,texture,lastMap,lastTick,habitat,scanAt
local H=V.require('KantoHabitat')
local function settings()return V.require('CommunityVisuals').kantoLife:get()end
function M.ownsFireflies(map)
 local p=H.profile(map);return settings()~='off'and p and not p.legacy or false
end

-- LOADING-STUTTER. The habitat scan reads the map's whole Structures analysis.
-- After a mesh-cache hit -- the normal case once an area has been seen -- that
-- analysis does not exist, and building it here, on the draw, froze the map's
-- first frame on the phone (into Route 22 2.3 s; out of the Route 22 gate onto
-- Route 23 1.5 s), and the 44-176 MB result was then kept only for the insects.
-- Now a background job on ChunkMesher's cooperative queue (sliced like
-- terrain) produces the small, exact habitat DIGEST KantoHabitat.scanDigest
-- reads (the same insects, in the same places): from memory, else from the
-- on-disk cache, else from a claims-only analysis (Structures' lightweight
-- mode: no building or League geometry, 4-17x cheaper, never kept). The
-- digest is cached on disk under the map's terrain fingerprint (the key the
-- mesh cache uses: blocks, tileset, every geometry setting), so a map is
-- analysed once, not every session. The current map goes first; then, one at
-- a time, the nearest connected map ahead of the player in view range, so the
-- next area is normally ready before you cross. Until a digest lands the
-- insects wait and fade in over APPEAR_SECONDS, and the ambience keeps the
-- last area's levels. Without the queue API the old synchronous scan runs,
-- exactly as before.
M.APPEAR_SECONDS=1.0
M.APPEAR_GRACE=.3      -- a digest that lands this soon after arrival shows at once
M.WARM_AHEAD=true
M.PERSIST=true
M.DIGEST_REV='kanto-habitat-digest-1'  -- bump when habitat placement code changes
M.PRIORITY_HERE=0.9    -- under terrain (current 2, visible bodies 1..2)
M.PRIORITY_AHEAD=0.45  -- above speculative door precache (0)
M.AHEAD_EVERY=.25      -- seconds between warm-ahead picks
M.AHEAD_LOOK=128       -- px ahead of the player (facing) the pick measures from
M.KEEP_DIGESTS=48      -- digests kept in memory (a few hundred numbers each)
M.STUCK_SECONDS=120    -- a queued flag older than this no longer blocks a pick
M.RETRY_SECONDS=30     -- a failed habitat is tried again after this (doubling, up to 8x)
M.stats={memory=0,disk=0,analysed=0,released=0,saved=0,failed=0}
local JOB='kanto-habitat'
local digests,order,queued={},{},{}
local pendingOn,pendingSince,appearAt,lastHabitat,aheadAt=nil,nil,nil,nil,-1e9
local function api()
 local okC,CM=pcall(V.require,'ChunkMesher')
 if not(okC and type(CM)=='table'and type(CM.requestWork)=='function'and type(CM.cancelWork)=='function'
  and type(CM.seasonalState)=='function')then return nil end
 local okS,S=pcall(V.require,'Structures')
 if not(okS and type(S)=='table'and type(S.forMap)=='function'and type(S.cached)=='function'
  and type(S.release)=='function')then return nil end
 if not(type(H.digest)=='function'and type(H.scanDigest)=='function'and type(H.signature)=='function')then return nil end
 return CM,S
end
local function generation(CM,map)local _,g=CM.seasonalState(map,true);return g end
local function remember(id,D)
 digests[id]=D
 for i=#order,1,-1 do if order[i]==id then table.remove(order,i)end end
 order[#order+1]=id
 while #order>M.KEEP_DIGESTS do digests[table.remove(order,1)]=nil end
end
-- What the digest depends on: the terrain fingerprint (map blocks incl. live
-- edits, tileset, geometry settings, cache revision), the settings scan()
-- reads, and DIGEST_REV. nil when it cannot be computed (then nothing is
-- shared or stored: the digest lives for this block-layer generation only).
local function contentKey(map,sig)
 local okD,Disk=pcall(V.require,'VoxelMeshDisk')
 if not(okD and Disk and type(Disk.fingerprint)=='function'and love.data and love.data.hash)then return nil end
 local ok,key=pcall(function()
  local fp=Disk.fingerprint(map,'body',nil,'terrain')
  return(love.data.hash('sha256',M.DIGEST_REV..'|'..sig..'|'..fp):gsub('.',function(c)return string.format('%02x',c:byte())end))
 end)
 return ok and key or nil
end
local function diskCache()
 if not M.PERSIST then return nil end
 local okD,Disk=pcall(V.require,'VoxelMeshDisk')
 if not(okD and Disk and type(Disk.seasonalCache)=='function')then return nil end
 local ok,c=pcall(Disk.seasonalCache)
 return ok and c or nil
end
-- the map's digest when it was made (or re-checked) for the block layer the
-- mesher has now (ChunkMesher's generation, moved by a Cut, an eviction or a
-- cache drop) under today's settings; else nil. The second result is true when
-- the last attempt for this layer threw.
local function digestFor(CM,map)
 local D=digests[map.id]
 if not D or D.gen~=generation(CM,map)then return nil,false end
 if D.failed then
  local wait=M.RETRY_SECONDS*2^math.min(3,(D.tries or 1)-1)
  return nil,love.timer.getTime()-(D.at or 0)<wait
 end
 if D.sig~=H.signature()then return nil,false end
 return D,false
end
function M.queueDigest(map,priority)
 local CM,Structures=api()
 if not CM then return false end
 local id=map.id
 local q=queued[id]
 if q and q.priority>=priority then return true end
 local ok=pcall(CM.requestWork,map,JOB,'digest',priority,function()
  local g0=generation(CM,map)
  -- the League planning loops of a claims-only Route 23 / Plateau analysis
  -- yield in this job only (LeagueArchitecture's scoped budget)
  local okL,LA=pcall(V.require,'LeagueArchitecture')
  if okL and type(LA)=='table'and LA.sliceJob then pcall(LA.sliceJob)end
  local okW,D=pcall(function()
   local sig=H.signature()
   local key=contentKey(map,sig)
   -- 1. the same content seen earlier this session (an eviction or a
   --    re-entry moved the generation, not the map)
   local known=digests[id]
   if key and known and not known.failed and known.key==key then M.stats.memory=M.stats.memory+1;return known end
   -- 2. the on-disk cache
   local cache=key and diskCache()
   local slot=key and('kanto-life-'..key:sub(1,40))
   if cache then
    local okR,bytes=pcall(cache.read,cache,slot)
    local d=okR and H.decode(bytes,key)
    if d then d.sig,d.key=sig,key;M.stats.disk=M.stats.disk+1;return d end
   end
   -- 3. analyse once, claims only (Structures' lightweight mode: no building
   --    or League geometry, never cached; the claims, shapes and plans the
   --    digest reads come out exactly as in a full analysis). A full analysis
   --    already cached is used as it is. Should a Structures without that
   --    mode hand back a full one this job built, it is let go again: only
   --    the digest was wanted (anyone who asks later gets a fresh one).
   local had=Structures.cached(map)
   local S=Structures.forMap(map,true)
   local d=H.digest(map,S)
   M.stats.analysed=M.stats.analysed+1
   if not had and not S.lightweight and Structures.release(map,S)then M.stats.released=M.stats.released+1 end
   d.sig,d.key=sig,key
   if cache then
    local okE,bytes=pcall(H.encode,d,key)
    local okC,wrote=false,false
    if okE then okC,wrote=pcall(cache.write,cache,slot,bytes)end
    if okC and wrote then M.stats.saved=M.stats.saved+1 end
   end
   return d
  end)
  queued[id]=nil
  if generation(CM,map)~=g0 then return end  -- invalidated meanwhile: asked again on the next draw
  if okW and type(D)=='table'then D.gen=g0;remember(id,D)
  else
   M.stats.failed=M.stats.failed+1
   local prior=digests[id]
   local tries=(prior and prior.failed and prior.gen==g0 and prior.tries or 0)+1
   remember(id,{gen=g0,failed=true,at=love.timer.getTime(),tries=tries})
   print('[warn] Kanto life habitat for '..tostring(id)..' failed: '..tostring(D))
  end
 end,function()queued[id]=nil end)
 if ok then queued[id]={priority=math.max(priority,q and q.priority or 0),at=love.timer.getTime()}end
 return ok
end
-- A new current map that still needs its digest: a job left at the old map's
-- priority would run first (equal priority runs first-queued-first), so it
-- goes; warm-ahead work for maps that are not next to the new one goes too.
local function settle(CM,map,state)
 local near={[map.id]=true}
 for _,nb in ipairs(state.neighbors or{})do if nb.map and nb.map.id~=nil then near[nb.map.id]=true end end
 local needs=not digestFor(CM,map)
 for id,q in pairs(queued)do
  if id~=map.id and((needs and q.priority>=M.PRIORITY_HERE)or not near[id])then
   pcall(CM.cancelWork,id,JOB);queued[id]=nil
  end
 end
end
local function warmAhead(CM,state,now)
 if now-aheadAt<M.AHEAD_EVERY then return end
 aheadAt=now
 -- one job at a time: one analysis in the making is what bounds the memory
 for id,q in pairs(queued)do
  if now-q.at<M.STUCK_SECONDS then return end
  queued[id]=nil
 end
 local okR,RD=pcall(V.require,'RenderDistance')
 local p=state.player or{}
 local px=(p.px or p.x or(p.cellX and p.cellX*16)or 0)+8
 local pz=(p.py or p.y or(p.cellY and p.cellY*16)or 0)+8
 local f=({up={0,-1},down={0,1},left={-1,0},right={1,0}})[p.facing or'']
 if f then px,pz=px+f[1]*M.AHEAD_LOOK,pz+f[2]*M.AHEAD_LOOK end
 local best,bestD
 for _,nb in ipairs(state.neighbors or{})do
  local m=nb.map
  if m and m.id~=nil and m.def and H.profile(m)then
   local D,failed=digestFor(CM,m)
   local near=not D and not failed
   if near and okR and RD and RD.neighbor then local ok,v=pcall(RD.neighbor,nb,state.player);near=(not ok)or v and true or false end
   if near then
    local x0,z0=tonumber(nb.ox)or 0,tonumber(nb.oy)or 0
    local x1,z1=x0+(tonumber(m.def.width)or 0)*32,z0+(tonumber(m.def.height)or 0)*32
    local dx=px<x0 and x0-px or(px>x1 and px-x1 or 0)
    local dz=pz<z0 and z0-pz or(pz>z1 and pz-z1 or 0)
    local d=dx*dx+dz*dz
    if not bestD or d<bestD then best,bestD=m,d end
   end
  end
 end
 if best then M.queueDigest(best,M.PRIORITY_AHEAD)end
end
local function resetDraw()
 if mesh then mesh:release()end;if texture then texture:release()end
 mesh,texture,lastMap,lastTick,habitat,scanAt=nil,nil,nil,nil,nil,nil
 pendingOn,pendingSince,appearAt=nil,nil,nil
end
-- (digests survive: they are keyed to the block layer and the settings)
function M.invalidate()resetDraw()end
function M.vertices(anchors,t,night,profile,px,pz,level,raining,appear)
 local out={};local butterflies,flies=0,0
 local function tri(a,b,c,u,shade)
  for _,p in ipairs({a,b,c,c,b,a})do out[#out+1]={p[1],p[2],p[3],u,.5,shade}end
 end
 local daytime=math.max(0,1-night*2.5)*(raining and 0 or 1)
 local nocturnal=math.max(0,(night-.22)/.78)*(raining and .3 or 1)
 local cap=level=='low'and 9 or 18
 for i,a in ipairs(anchors)do
  if i>cap then break end
  local seed=a.seed;local phase=seed*.17
  local fade=math.max(0,math.min(1,(96-math.sqrt((a.x-px)^2+(a.z-pz)^2))/24))*(appear or 1)
  local density=(seed%17)/17
  if fade>0 and density<profile.insects then
   local x=a.x+math.sin(t*.42+phase)*3;local z=a.z+math.cos(t*.31+phase)*3
   if daytime>.03 then
    local y=a.y+3.8+math.sin(t*.83+phase)*1.6
    local yaw=phase+math.sin(t*.37+phase)*.9;local ca,sa=math.cos(yaw),math.sin(yaw)
    local flap=.18+math.abs(math.sin(t*(8+seed%4)+phase))*1.22
    local size=fade*daytime*(.50+(seed%5)*.055)
    local function p(wx,wy,wz)return{x+size*(wx*ca-wz*sa),y+size*wy,z+size*(wx*sa+wz*ca)}end
    -- Broad upper wings, scalloped lower wings, dark body and paired antennae.
    local contour={{.10,-.08},{.48,-1.18},{1.13,-1.53},{1.52,-1.22},{1.65,-.60},{1.43,-.10},{1.12,.17},{1.40,.60},{1.13,1.09},{.60,1.22},{.20,.73}}
    for _,side in ipairs({-1,1})do
     local ring={};for k,c in ipairs(contour)do ring[k]=p(side*c[1]*math.cos(flap),c[1]*math.sin(flap),c[2])end
     local center=p(side*.48*math.cos(flap),.48*math.sin(flap),0)
     local u=((seed%3)+.5)/5
     for k=1,#ring do tri(center,ring[k],ring[k%#ring+1],u,.92+(k%3)*.04)end
     for _,zz in ipairs({-.8,.5})do tri(p(side*.55*math.cos(flap),.55*math.sin(flap)+.015,zz-.13),p(side*.91*math.cos(flap),.91*math.sin(flap)+.015,zz),p(side*.60*math.cos(flap),.60*math.sin(flap)+.015,zz+.16),.7,.85)end
    end
    tri(p(-.09,.04,-.85),p(.09,.04,-.85),p(0,.04,1),.7,.82)
    for _,side in ipairs({-1,1})do tri(p(0,.04,-.66),p(side*.30,.20,-1.18),p(side*.24,.20,-1.2),.7,.86)end
    butterflies=butterflies+1
   end
   if nocturnal>.03 and not profile.legacy then
    for j=1,2 do
     local yy=a.y+3+j*1.4+math.sin(t*.7+phase+j)*1.3
     local fx,fz=x+math.sin(phase+j+t*.2)*3,z+math.cos(phase+j+t*.3)*3
     local r=(.07+.17*math.max(0,math.sin(t*(1.3+j*.2)+phase+j*2))^3)*fade*nocturnal
     tri({fx-r,yy-r,fz},{fx+r,yy-r,fz},{fx,yy+r,fz},.9,65)
     tri({fx,yy-r,fz-r},{fx,yy-r,fz+r},{fx,yy+r,fz},.9,65)
     flies=flies+1
    end
   end
  end
 end
 assert(#out<=M.MAX_VERTICES,'Kanto life budget')
 return out,butterflies,flies
end
function M.draw(state)
 local map=state and state.map;local profile=H.profile(map);local level=settings()
 if level=='off'or not profile then if lastMap then resetDraw()end;return end
 local now=love.timer.getTime()
 local CM=api()
 if lastMap~=map then
  resetDraw();lastMap=map
  if CM then pcall(settle,CM,map,state)end
 end
 local p=state.player or{};local px=(p.px or p.x or(p.cellX and p.cellX*16)or 0)+8
 local pz=(p.py or p.y or(p.cellY and p.cellY*16)or 0)+8
 local tick=math.floor(now*30)
 local failed=false
 if not scanAt or now-scanAt>.25 then
  local D
  if CM then D,failed=digestFor(CM,map)end
  if D then
   -- it landed after we arrived: fade in, unless that was at once -- and
   -- never when a habitat was already showing (a block edit re-checks the
   -- digest while the insects keep flying; they must not blink)
   if pendingOn==map and not habitat and now-(pendingSince or now)>M.APPEAR_GRACE then appearAt=now end
   pendingOn,pendingSince=nil,nil
   habitat=H.scanDigest(map,D,px,pz);scanAt=now
  elseif failed then
   -- no habitat here until the retry (the original raised in draw: no
   -- insects, no ambience) -- and this area stops waiting
   habitat=nil;scanAt=now;pendingOn,pendingSince=nil,nil
  elseif CM and M.queueDigest(map,M.PRIORITY_HERE)then
   if pendingOn~=map then pendingOn,pendingSince=map,now end
  else
   habitat=H.scan(map,V.require('Structures').forMap(map),px,pz);scanAt=now  -- no queue: as before
  end
 end
 if M.WARM_AHEAD and CM and not pendingOn then pcall(warmAhead,CM,state,now)end
 if not habitat then
  -- keep the last area's ambience levels until this area's habitat lands
  if lastHabitat and pendingOn==map then
   local night=V.require('DayNight').windowLight();local weather=rawget(_G,'__ds_weather')or{}
   V.require('KantoLifeAudio').touch(map.id,profile,lastHabitat,night,weather.raining,level)
  end
  return
 end
 lastHabitat=habitat
 local night=V.require('DayNight').windowLight();local weather=rawget(_G,'__ds_weather')or{}
 V.require('KantoLifeAudio').touch(map.id,profile,habitat,night,weather.raining,level)
 local appear=1
 if appearAt then
  appear=math.min(1,math.max(0,(now-appearAt)/M.APPEAR_SECONDS))
  if appear>=1 then appearAt=nil end
 end
 if tick~=lastTick then
  local verts=M.vertices(habitat.green,now,night,profile,px,pz,level,weather.raining,appear)
  if #verts==0 then lastTick=nil;return end
  if not mesh then
   mesh=love.graphics.newMesh(V.require('Voxel3D').FORMAT,M.MAX_VERTICES,'triangles','dynamic')
   local data=love.image.newImageData(5,1)
   for i,c in ipairs({{.88,.62,.23},{.67,.80,.90},{.82,.71,.91},{.16,.13,.12},{.82,1,.37}})do data:setPixel(i-1,0,c[1],c[2],c[3],1)end
   texture=love.graphics.newImage(data);texture:setFilter('nearest','nearest');data:release()
  end
  mesh:setVertices(verts,1,#verts);mesh:setDrawRange(1,#verts);lastTick=tick
 end
 if mesh then V.require('Voxel3D').draw(mesh,texture)end
end
return M
