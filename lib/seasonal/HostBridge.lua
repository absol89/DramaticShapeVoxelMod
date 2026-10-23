-- Access only the same exported library used by the released Casino companion.
-- No host function replacement or access to unexported runtime files.
local mod,G=...
local function checkpoint()if G then G.checkpoint()end end
local M={}
-- Waterfront deck railings (BridgeCraft, baked into Legendary terrain): every
-- Kanto timber tile beside water carries a rail along that edge, with a
-- lantern post on alternate tiles. Rebuild the same edges from the public
-- shape/tile record and group them into straight runs.
function M.docks(bridge,map,S)
 local runs={}
 if not(map and map.tileset and map.tileset.id=='OVERWORLD'and S and S.shapeAt and S.tileAt)then return runs end
 local okC,CV=pcall(bridge.V.require,'CommunityVisuals')
 if not(okC and CV and CV.customRoads)then return runs end
 local okR,roads=pcall(CV.customRoads);if not(okR and roads)then return runs end
 local function key(x,z)return(z+64)*4096+x+64 end
 local function wood(x,z)local k=key(x,z);local s=S.shapeAt[k]
  return s and s.class=='ground'and S.tileAt[k]==60 and not(S.skip and S.skip[k])end
 local function water(x,z)local s=S.shapeAt[key(x,z)];return s and s.class=='water'end
 local lines={};local n=0
 for k,s in pairs(S.shapeAt)do
  local tx,tz=k%4096-64,math.floor(k/4096)-64
  if wood(tx,tz)then
   for _,e in ipairs({{-1,0},{1,0},{0,-1},{0,1}})do
    if water(tx+e[1],tz+e[2])then
     local cross=e[1]~=0;local along=cross and tz or tx
     local ending=cross and(not wood(tx,tz-1)or not wood(tx,tz+1))or(not cross and(not wood(tx-1,tz)or not wood(tx+1,tz)))
     local post=ending or along%(map.id=='ROUTE_24'and 6 or 2)==0
     local line=cross and(e[1]<0 and tx*8+1.5 or tx*8+6.5)or(e[2]<0 and tz*8+1.5 or tz*8+6.5)
     local id=(cross and 'x'or 'z')..'|'..line..'|'..(e[1]+e[2])
     local L=lines[id];if not L then L={cross=cross,line=line,inward=-(e[1]+e[2]),tiles={}};lines[id]=L end
     L.tiles[along]={h=s.h or 0,post=post};n=n+1
    end
   end
  end
 end
 -- Contiguous tiles at one height form a run; posts sit at tile centres.
 local ids={};for id in pairs(lines)do ids[#ids+1]=id end;table.sort(ids)
 for _,id in ipairs(ids)do local L=lines[id]
  local idx={};for a in pairs(L.tiles)do idx[#idx+1]=a end;table.sort(idx)
  local run
  for _,a in ipairs(idx)do local t=L.tiles[a]
   if run and a==run.last+1 and t.h==run.h then run.last=a;run.a1=a*8+8
   else
    run={cross=L.cross,line=L.line,inward=L.inward,h=t.h,a0=a*8,a1=a*8+8,last=a,posts={}}
    runs[#runs+1]=run
   end
   if t.post then run.posts[#run.posts+1]=a*8+4 end
  end
 end
 for _,r in ipairs(runs)do r.last=nil end
 return runs
end
function M.info(bridge,map,snapshot)
 local out={buildings={},occupied={},obstacles={},doors={},lamps={}}
 if not(map and snapshot and map.id==snapshot.id)then return out end
 local ok,Structures=pcall(bridge.V.require,'Structures')
 if not(ok and Structures and Structures.forMap)then return out end
 local success,S=pcall(Structures.forMap,map)
 if not(success and S)then return out end
 -- TEST148: where is an interior's real back wall?
 --  * Battle Art's own whole-room models (Oak's lab, Red's house) place
 --    their walls freely: no wall trim is hung there.
 --  * Room-overhaul companions (Legendary Interiors) claim the original wall
 --    rows (S.skip) and stand their shell at the map's north edge, 60+ tall.
 --  * Otherwise the native wall tiles' face is the back wall.
 if snapshot.tags and snapshot.tags.interior and map.def then
  local okC,Corner=pcall(bridge.V.require,'GameCorner')
  if okC and Corner and type(Corner.owns)=='function'then
   local okO,owned=pcall(Corner.owns,map);if okO and owned then out.authoredRoom=true end
  end
  if not out.authoredRoom and S.skip then
   local tw=(map.def.width or 0)*4;local claimed=0
   for k in pairs(S.skip)do
    local x,z=k%4096-64,math.floor(k/4096)-64
    if x>=0 and x<tw and z>=0 and z<4 then claimed=claimed+1 end
   end
   if tw>0 and claimed>=tw then out.shellRoom={north=0,height=60}end
  end
 end
 -- TEST73: Cerulean's southern waterfront may reach the map boundary.
 -- Keep enclosed ponds, but also accept southern boundary water; reject
 -- northern river components. Previous edge rejection disabled the move.
 if map.id=='CERULEAN_CITY' and map.def and S.shapeAt then
  local tw,th=(map.def.width or 0)*4,(map.def.height or 0)*4
  local seen={};local function key(x,z)return(z+64)*4096+x+64 end
  local function water(x,z)
   local t=S.shapeAt[key(x,z)]
   return x>=0 and z>=0 and x<tw and z<th and t and t.class=='water'
  end
  for z=0,th-1 do checkpoint();for x=0,tw-1 do
   local k=key(x,z)
   if not seen[k] and water(x,z)then
    local q={{x,z}};seen[k]=true;local head=1
    local b={x0=x,x1=x,z0=z,z1=z,n=0,edge=false}
    while head<=#q do
     local c=q[head];head=head+1;local a,d=c[1],c[2];b.n=b.n+1
     b.x0=math.min(b.x0,a);b.x1=math.max(b.x1,a);b.z0=math.min(b.z0,d);b.z1=math.max(b.z1,d)
     if a==0 or d==0 or a==tw-1 or d==th-1 then b.edge=true end
     for _,v in ipairs({{-1,0},{1,0},{0,-1},{0,1}})do
      local nx,nz=a+v[1],d+v[2];local nk=key(nx,nz)
      if not seen[nk] and water(nx,nz)then seen[nk]=true;q[#q+1]={nx,nz}end
     end
    end
    local southern=b.z0>=th*.45 and b.x0>=6
    if b.n>=4 and (not b.edge or southern)then
     -- Prefer southern waterfront over a smaller enclosed northern pool.
     local score=b.n+(southern and tw*th or 0)
     if not out.treePond or score>out.treePondScore then out.treePond=b;out.treePondScore=score end
    end
   end
  end end
 end
 -- Legendary city furniture (garden beds, benches, lamps, bins, pond decks)
 -- and district boundary fences are baked by the terrain builder, not
 -- objectQuads: read their published plans so displays never land on them.
 for _,plan in pairs(type(S.cityStreetPlans91)=='table'and S.cityStreetPlans91 or {})do
  for _,f in ipairs(type(plan)=='table'and plan.features or {})do
   local bd=f.bounds
   if type(bd)=='table'and type(bd[1])=='number'then
    out.obstacles[#out.obstacles+1]={x0=bd[1],z0=bd[2],x1=bd[3],z1=bd[4],kind='city_'..tostring(f.kind),margin=3,street=true}
   end
   if f.kind=='lamp'and type(f.cx)=='number'then out.lamps[#out.lamps+1]={x=f.cx,z=f.cz,height=15.6,shaftHeight=11.0,radius=.20,street=true}end
  end
  break
 end
 local okP,Pillars=pcall(bridge.V.require,'GranitePillars')
 local record=okP and Pillars and Pillars.cache and Pillars.cache[map.id]
 if record and record.cells then
  for k in pairs(record.cells)do
   local cx,cz=tostring(k):match('^(-?%d+)|(-?%d+)$');cx,cz=tonumber(cx),tonumber(cz)
   if cx then out.obstacles[#out.obstacles+1]={x0=cx*16,z0=cz*16,x1=cx*16+16,z1=cz*16+16,kind='fence',margin=2,street=true}end
  end
  -- TEST162: district railings (Nugget Bridge, Cerulean's bridges, Pallet's
  -- pickets, Viridian's woodland fence...) as post-to-post segments, so the
  -- holidays can dress them with swagged garlands, lights and post toppers.
  if record.boundary then
   local st=record.boundary
   local top=st=='picket'and 7.8 or st=='mineral'and 8.3 or 9.6
   local rail=st=='picket'and 6.35 or st=='mineral'and 4.15 or 8.15
   local rails={style=st,segs={},posts={}}
   local keys={};for k in pairs(record.cells)do keys[#keys+1]=k end;table.sort(keys)
   for _,k in ipairs(keys)do
    local base=record.cells[k]
    local cx,cz=tostring(k):match('^(-?%d+)|(-?%d+)$');cx,cz=tonumber(cx),tonumber(cz)
    if cx and #rails.segs<400 then
     local x,z=cx*16+8,cz*16+8
     rails.posts[#rails.posts+1]={x=x,z=z,y=base+top,cx=cx,cz=cz}
     for _,d in ipairs({{1,0},{0,1}})do
      local nb=record.cells[(cx+d[1])..'|'..(cz+d[2])]
      if nb then rails.segs[#rails.segs+1]={x,z,x+d[1]*16,z+d[2]*16,(base+nb)*.5+rail}end
     end
    end
   end
   if #rails.segs>0 then out.railings=rails end
  end
 end
 local dockOK,docks=pcall(M.docks,bridge,map,S)
 out.docks=dockOK and docks or {}
 -- Cinnabar's baked waterfront palms (body palms only; the border row across
 -- the water is culled whenever Cinnabar is a neighbor).
 out.palms={}
 for _,p in ipairs(S.cinnabarPalms19 or {})do
  if type(p.cx)=='number'and type(p.cz)=='number'then
   out.palms[#out.palms+1]={cx=p.cx,cz=p.cz,h=p.h or 0,height=p.height or 35,angle=p.angle or 0,variant=p.variant or 1}
  end
 end
 -- Lavender lamps are drawn by StreetLights, outside Structures.objectQuads.
 local lampOK,StreetLights=pcall(bridge.V.require,'StreetLights')
 if lampOK and StreetLights and StreetLights.anchors then
  for _,l in ipairs(StreetLights.anchors(map))do out.lamps[#out.lamps+1]=l end
 end
 local w,cs=snapshot.width,snapshot.cellSize or 16
 -- Celadon's benches/trees are baked by ChunkMesher, not S.objectQuads.
 -- Ask the very same pure planner, with the same road/courtyard settings.
 if map.id=='CELADON_CITY' and S.shapeAt and S.tileAt then
  local okC,CV=pcall(bridge.V.require,'CommunityVisuals')
  local okP,Park=pcall(bridge.V.require,'CeladonPark')
  if okC and okP and Park and CV and Park.enabled and Park.plan then
   local good,P=pcall(function()
    if not Park.enabled(map.id,CV.customRoads(),map.tileset and map.tileset.id,CV.referenceBuildings())then return end
    local key=function(x,z)return(z+64)*4096+x+64 end
    local courts=CV.customCourtyards()
    return Park.plan(map,S,key,function(x,z)
     local tile=S.tileAt[key(x,z)]
     -- Other courtyard members (35/91) already belong to Park.paved.
     return Park.paved(tile,courts and(tile==16 or tile==33))
    end)
   end)
   if good and P then
    out.park=P -- Pure planner output, also used to fit winter ground/bench caps.
    for _,f in ipairs(P.features or {})do
     local b=f.bounds
     if b then out.obstacles[#out.obstacles+1]={x0=b[1],z0=b[2],x1=b[3],z1=b[4],kind=f.kind,margin=2.5}end
    end
    for _,f in ipairs(P.features or {})do
     if f.kind=='lamp' then out.lamps[#out.lamps+1]={x=f.cx,z=f.cz,height=15.6,shaftHeight=11.0,radius=.20}end
    end
    out.parkFeatures=#out.obstacles
   elseif not good then
    -- Unknown park data must not silently put another large prop in its lawns.
    out.parkError=tostring(P)
   end
  end
 end
 local bounds,buckets={},{};out.quadBounds=bounds
 local bucketSize=64
 local function bucketKey(x,z)return x..':'..z end
 local function candidates(x0,z0,x1,z1)
  local ids,seen={},{}
  for z=math.floor(z0/bucketSize),math.floor(z1/bucketSize)do
   for x=math.floor(x0/bucketSize),math.floor(x1/bucketSize)do
    for _,id in ipairs(buckets[bucketKey(x,z)]or{})do if not seen[id]then seen[id]=true;ids[#ids+1]=id end end
   end
  end
  table.sort(ids);return ids
 end
 -- Supplemental occupied floor cells include the host's physical street furniture.
 for qi,q in ipairs(S.objectQuads or {})do
  if qi%256==0 then checkpoint()end
  if q[1]and q[4]then
   local x0,z0,y0,x1,z1,y1=1e9,1e9,1e9,-1e9,-1e9,-1e9
   for j=1,4 do local v=q[j];x0=math.min(x0,v[1]);x1=math.max(x1,v[1]);y0=math.min(y0,v[2]);y1=math.max(y1,v[2]);z0=math.min(z0,v[3]);z1=math.max(z1,v[3])end
   bounds[q]={q=q,x0=x0,x1=x1,z0=z0,z1=z1,y0=y0,y1=y1}
   -- Index by midpoint; a wholly contained face necessarily has its midpoint
   -- inside the queried building. Wide roof quads never multiply buckets.
   local k=bucketKey(math.floor((x0+x1)*.5/bucketSize),math.floor((z0+z1)*.5/bucketSize))
   buckets[k]=buckets[k]or{};buckets[k][#buckets[k]+1]=qi
   if y1>3 and y0<25 then
    for z=math.max(0,math.floor((z0-.3)/cs)),math.min(snapshot.height-1,math.floor((z1+.3)/cs))do
     for x=math.max(0,math.floor((x0-.3)/cs)),math.min(w-1,math.floor((x1+.3)/cs))do out.occupied[z*w+x+1]=true end
    end
   end
  end
 end
 for _,b in ipairs(S.cityBuildings or {})do
  if not b.claimOnly and not b.bbTower and not b.legacyTower then
   local x0,x1=b.tileX+1,b.tileX+b.tileW-1
   local z0,z1=b.tileZ+1,b.tileZ+b.tileH-(b.frontEave or 0)
   local bands={};local fronts={};local maxY=0;local roof={};local surfaces={}
   for ci,qi in ipairs(candidates(x0-3,z0-4,x1+3,z1+18))do
    if ci%128==0 then checkpoint()end
    local q=S.objectQuads[qi];local surface=bounds[q]
    if surface then
    local ymin,ymax=surface.y0,surface.y1
    if surface.x0>=x0-3 and surface.x1<=x1+3 and surface.z0>=z0-4 and surface.z1<=z1+18 then
     maxY=math.max(maxY,ymax)
     surfaces[#surfaces+1]=surface
     for j=1,4 do local p,r=q[j],q[j%4+1]
      if math.abs(p[2]-r[2])<.1 and p[2]>=31 and p[2]<105 and math.abs(p[3]-z1)<18 then
       local width=math.abs(p[1]-r[1]);local y=math.floor(p[2]*2+.5)/2
       bands[y]=(bands[y]or 0)+width/(1+math.abs(y-36)*.026)
      end
     end
     local a,c,d=q[1],q[2],q[3];local ux,uy,uz=c[1]-a[1],c[2]-a[2],c[3]-a[3];local vx,vy,vz=d[1]-a[1],d[2]-a[2],d[3]-a[3]
     local nx,ny,nz=uy*vz-uz*vy,uz*vx-ux*vz,ux*vy-uy*vx;local area=math.sqrt(nx*nx+ny*ny+nz*nz)
     if area>1 and nz/area>.75 and ymin<24 and ymax>6 and ymax<70 then
      local zz=math.floor((a[3]+c[3]+d[3]+q[4][3])*.5+.5)/2
      if math.abs(zz-z1)<16 then fronts[zz]=(fronts[zz]or 0)+area end
     end
     if area>1 and ny/area>.33 and ymin>29 and #roof<900 then
      roof[#roof+1]={{q[1][1],q[1][2],q[1][3]},{q[2][1],q[2][2],q[2][3]},{q[3][1],q[3][2],q[3][3]},{q[4][1],q[4][2],q[4][3]}}
     end
    end
   end end
   local eave,score=35,0;for y,n in pairs(bands)do if n>score then eave,score=y,n end end
   local fz,fs=z1,0;for z,n in pairs(fronts)do if n>fs then fz,fs=z,n end end
   -- Measure projecting cornices/canopies independently of the broad wall.
   local canopyTop=0
   for _,s in ipairs(surfaces)do
    if s.z1>fz+3 and s.y0>=25 and s.y1<=38 and s.x1-s.x0>.5 then canopyTop=math.max(canopyTop,s.y1)end
   end
   local canopy=canopyTop>0
   if canopy then eave=canopyTop end
   local trimY=eave-.6
   local profile={}
   local n=math.max(8,math.ceil((x1-x0)/2))
   for i=0,n do
    local x=x0+(x1-x0)*i/n;local z=fz
    -- A conservative local envelope covers the full depth of branches/bows.
    for _,s in ipairs(surfaces)do
     if s.x1>=x-3.8 and s.x0<=x+3.8 and s.y1>=trimY-13 and s.y0<=trimY+2.5 then z=math.max(z,s.z1)end
    end
    -- Height of the front at this x: a stepped or monitor-roof facade is
    -- lower at its wings, and trim must not hang in the air there.
    local top=0
    for _,s2 in ipairs(surfaces)do
     if s2.x1>=x-1 and s2.x0<=x+1 and s2.z1>=fz-3 then top=math.max(top,s2.y1)end
    end
    -- TEST161: the true height of the front WALL here, read from the wall
    -- polygons themselves (a gable's bounding box says "peak" everywhere).
    local ftop=0
    for _,s2 in ipairs(surfaces)do
     local q2=s2.q
     if q2 and s2.x1>=x-.01 and s2.x0<=x+.01 and s2.z1>=fz-3 then
      local a,c,d=q2[1],q2[2],q2[3]
      local ux,uy,uz=c[1]-a[1],c[2]-a[2],c[3]-a[3];local vx,vy,vz=d[1]-a[1],d[2]-a[2],d[3]-a[3]
      local nx,ny,nz=uy*vz-uz*vy,uz*vx-ux*vz,ux*vy-uy*vx;local ar=math.sqrt(nx*nx+ny*ny+nz*nz)
      if ar>.5 and math.abs(nz)/ar>.7 then
       for j=1,4 do local p1,p2=q2[j],q2[j%4+1]
        local lo,hi=math.min(p1[1],p2[1]),math.max(p1[1],p2[1])
        if x>=lo-.01 and x<=hi+.01 then
         local yy
         if hi-lo<.05 then yy=math.max(p1[2],p2[2])else yy=p1[2]+(p2[2]-p1[2])*(x-p1[1])/(p2[1]-p1[1])end
         if yy>ftop then ftop=yy end
        end
       end
      end
     end
    end
    profile[#profile+1]={x=x,z=z,top=top,ftop=ftop>0 and ftop or nil}
   end
   -- Signs, emblems and plaques standing proud of the wall: wreaths avoid them.
   local badges={}
   for _,s2 in ipairs(surfaces)do
    if s2.z0>fz-1 and s2.z1>fz+.6 and s2.y1>trimY-16 and s2.y0<trimY+6
       and s2.x1-s2.x0<30 and s2.y1-s2.y0<22 and #badges<64 then
     badges[#badges+1]={x0=s2.x0,x1=s2.x1,y0=s2.y0,y1=s2.y1}
    end
   end
   local side0,side1=x0,x1
   for _,s in ipairs(surfaces)do
    if s.y1>=trimY-.5 and s.y0<=trimY+2 then side0=math.min(side0,s.x0);side1=math.max(side1,s.x1)end
   end
   out.buildings[#out.buildings+1]={x0=x0,x1=x1,z0=z0,z1=fz,eave=eave,roof=roof,id=b.id,maxY=maxY,
    frontProfile=profile,canopy=canopy,trimY=trimY,sideX0=side0,sideX1=side1,badges=badges}
  end
 end
 -- Only real entrance warps paired with a measured front wall qualify.
 -- Adjacent warp cells form one doorway rather than duplicate displays.
 local warps={}
 for _,d in ipairs(map.def and map.def.warps or {})do
  if type(d.x)=='number'and type(d.y)=='number'then
   warps[#warps+1]={x=d.x*16+8,z=d.y*16+8,dest=d.destMap}
  end
 end
 table.sort(warps,function(a,b)if a.z==b.z then return a.x<b.x end;return a.z<b.z end)
 local groups={}
 for _,d in ipairs(warps)do
  local last=groups[#groups]
  if last and last.z==d.z and last.dest==d.dest and d.x-last.x1<=16 then last.x1=d.x
  else groups[#groups+1]={x0=d.x,x1=d.x,z=d.z,dest=d.dest}end
 end
 for _,d in ipairs(groups)do
  local x=(d.x0+d.x1)/2;local best,dist
  for _,b in ipairs(out.buildings)do
   local dz=math.abs(d.z-b.z1)
   if x>=b.x0 and x<=b.x1 and dz<=28 and(not dist or dz<dist)then best,dist=b,dz end
  end
  if best then out.doors[#out.doors+1]={x=x,z=best.z1,width=d.x1-d.x0+16,building=best}end
 end
 if map.id=='CELADON_CITY'then
  local mart,casino
  for _,warp in ipairs(map.def and map.def.warps or {})do
   if warp.destMap=='CELADON_MART_1F'then mart=warp elseif warp.destMap=='GAME_CORNER'then casino=warp end
  end
  if mart and casino then
   out.plaza={x=(mart.x+casino.x)*8+8,z=(mart.y+casino.y)*8+56}
   if out.parkError then
    out.obstacles[#out.obstacles+1]={x0=mart.x*16-8,z0=mart.y*16+24,x1=casino.x*16-24,z1=casino.y*16+80,kind='unresolved park',margin=4}
   end
  end
 end
 return out
end
return M
