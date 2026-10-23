-- Pure scene planning: no mutation of collision, maps, actors or warps.
-- TEST26: decorations are cosmetic and never collide, so they must not stand
-- where people walk. The planner traces the real walking routes between
-- doors, exits and signs, keeps every display off them, backs street props
-- against walls and fences facing the open street, spreads them evenly, and
-- keeps the tall centerpiece from hiding the routes behind it.
local M={}
M.towns={
 PALLET_TOWN={palette='classic',name='Pallet Christmas Green',height=91},
 VIRIDIAN_CITY={palette='woodland',name='Viridian Woodland Festival',height=105},
 PEWTER_CITY={palette='royal',name='Pewter Golden Christmas',height=102},
 CERULEAN_CITY={palette='frost',name='Cerulean Winter Lights',height=105},
 VERMILION_CITY={palette='electric',name='Vermilion Harbor Celebration',height=110},
 LAVENDER_TOWN={palette='lavender',name='Lavender Starlight',height=91},
 CELADON_CITY={palette='royal',name='Celadon Grand Christmas',height=123},
 FUCHSIA_CITY={palette='woodland',name='Fuchsia Festive Gardens',height=105},
 SAFFRON_CITY={palette='royal',name='Saffron Festival of Lights',height=125},
 CINNABAR_ISLAND={palette='classic',name='Cinnabar Coastal Christmas',height=101},
 INDIGO_PLATEAU={palette='frost',name='Indigo Championship Christmas',height=120}
}
-- Street display rotations. Small lists serve routes and interiors.
M.variants={
 christmas={big={'snowman','reindeer','candy','minitree','gifts','wreathpost'},small={'candy','minitree','gifts','wreathpost'},indoor={'gifts','minitree','candy'}},
 halloween={big={'hay','graves','cauldron','ghost','totem','scarecrow'},small={'pumpkins','hay','graves','totem'},indoor={'pumpkins','candles'}},
 spectral={big={'graves','ghost','cauldron','graves','totem','ghost'},small={'graves','pumpkins','ghost'},indoor={'candles','pumpkins'}},
 harvest={big={'corn','apples','leaves','hayharvest','corn','wheel'},small={'corn','leaves','apples','hayharvest'},indoor={'apples','gourds'}},
 easter={big={'eggs','flowers','eggs','basket'},small={'eggs','flowers'},indoor={'flowers','eggs'}},
 july={big={'flagpost','flagpair','flagpost','drums'},small={'flagpost','flagpair'},indoor={'flagpair'}},
}
-- TEST147: each town's Halloween street displays fit its character instead
-- of one shared rotation (Lavender keeps its spectral set).
M.cityHalloween={
 PALLET_TOWN={'scarecrow','hay','totem','pumpkins','scarecrow','hay'},       -- farm-town harvest porch
 VIRIDIAN_CITY={'scarecrow','totem','hay','graves','scarecrow','totem'},     -- forest edge
 PEWTER_CITY={'graves','totem','graves','cauldron','hay','graves'},          -- old stone and fossils
 CERULEAN_CITY={'ghost','cauldron','hay','ghost','totem','graves'},          -- misty cape and water
 VERMILION_CITY={'ghost','cauldron','totem','ghost','hay','graves'},         -- foggy harbor
 CELADON_CITY={'totem','cauldron','scarecrow','ghost','hay','graves'},       -- big-city festival
 FUCHSIA_CITY={'scarecrow','hay','totem','cauldron','scarecrow','graves'},   -- Safari country
 SAFFRON_CITY={'ghost','cauldron','ghost','totem','graves','hay'},           -- psychic city
 CINNABAR_ISLAND={'cauldron','graves','cauldron','ghost','totem','graves'},  -- volcano lab island
 INDIGO_PLATEAU={'totem','graves','cauldron','ghost','totem','hay'},
}
-- TEST150: a pumpkin patch (with a hayride wagon where it fits). Footprints
-- in 16-unit cells; the planner finds a clear, off-route lawn at runtime.
M.patches={
 VIRIDIAN_CITY={cw=6,cd=3,wagon=true},
 PALLET_TOWN={cw=3,cd=2,mini=true},
}
local function allowedInterior(id)
 return id:find('POKECENTER',1,true)or id:find('MART',1,true)or id:find('HOUSE',1,true)
  or id:find('HOTEL',1,true)or id:find('DINER',1,true)or id:find('MUSEUM',1,true)
  or id:find('GYM',1,true)or id:find('LAB',1,true)or id=='GAME_CORNER'
  or id=='GAME_CORNER_PRIZE_ROOM'or id=='INDIGO_PLATEAU_LOBBY'or id=='SAFARI_ZONE_GATE'
end
local function textHash(s)local h=7;for i=1,#s do h=(h*31+s:byte(i))%1000003 end;return h end
-- Project the authored roof triangles. No eave-height guesses and no snow lift.
function M.roofHeight(b,x,z)
 local best
 for _,q in ipairs(b.roof or {})do
  for tri=1,2 do
   local a,c,d=q[1],q[tri+1],q[tri+2]
   local den=(c[3]-d[3])*(a[1]-d[1])+(d[1]-c[1])*(a[3]-d[3])
   if math.abs(den)>.00001 then
    local u=((c[3]-d[3])*(x-d[1])+(d[1]-c[1])*(z-d[3]))/den
    local v=((d[3]-a[3])*(x-d[1])+(a[1]-d[1])*(z-d[3]))/den
    if u>=-.00001 and v>=-.00001 and u+v<=1.00001 then
     local y=u*a[2]+v*c[2]+(1-u-v)*d[2]
     if not best or y>best then best=y end
    end
   end
  end
 end
 return best
end
function M.roofSeat(b)
 local best,bestScore
 -- Look for an actual outer edge on each side. A gable's low side eave wins
 -- over its high front rake; hips sit across a contour, legs face downhill.
 for _,side in ipairs({{0,1},{1,0},{-1,0},{0,-1}})do
  local dx,dz=side[1],side[2];local axis=dx==0 and 1 or 3
  local lo=axis==1 and b.x0 or b.z0;local hi=axis==1 and b.x1 or b.z1
  for _,fraction in ipairs({.70,.30,.82,.18,.55,.45})do
   local at=lo+(hi-lo)*fraction;local edge
   for _,q in ipairs(b.roof or {})do
    for i=1,4 do
     local a,c=q[i],q[i%4+1];local span=c[axis]-a[axis]
     if math.abs(span)>.001 and at>=math.min(a[axis],c[axis]) and at<=math.max(a[axis],c[axis])then
      local t=(at-a[axis])/span
      local x,z=a[1]+t*(c[1]-a[1]),a[3]+t*(c[3]-a[3])
      local y=a[2]+t*(c[2]-a[2]);local extent=x*dx+z*dz
      if y>=29 and(not edge or extent>edge.extent)then edge={x=x,z=z,y=y,extent=extent}end
     end
    end
   end
   if edge then
    local x,z=edge.x-dx*1.25,edge.z-dz*1.25
    local y=M.roofHeight(b,x,z)
    -- At 1.05 model scale the two hip bottoms are +/-0.89 from the seat.
    local left=M.roofHeight(b,x-dz*.90,z+dx*.90)
    local right=M.roofHeight(b,x+dz*.90,z-dx*.90)
    local knee=M.roofHeight(b,x+dx*3.045,z+dz*3.045)
    local foot=M.roofHeight(b,x+dx*3.465,z+dz*3.465)
    local back=M.roofHeight(b,x-dx*.7,z-dz*.7)
    if y and left and right and back and math.abs(left-right)<.34
       and math.abs(left-y)<.34 and math.abs(right-y)<.34
       and (not knee or knee<=y-.6) and(not foot or foot<y-5.2)
       and back<=y+2 then
     -- Check the complete seated envelope, including projecting signs and
     -- fascia between the hip, knee and foot centerlines.
     local clear=true
     for forward=0,4.5,.75 do
      for across=-3,3,1 do
       local surface=M.roofHeight(b,x+dx*forward+dz*across,z+dz*forward-dx*across)
       if surface and surface>(forward>=2.25 and y-5.4 or y+.25)then clear=false;break end
      end
      if not clear then break end
     end
     local score=y+(dz<0 and 4 or 0)+(dx~=0 and .35 or 0)
     if clear and(not bestScore or score<bestScore)then
      bestScore=score
      best={x=x,z=z,y=math.max(y,left,right),yaw=math.atan2(dx,dz),outX=dx,outZ=dz,
       edgeX=edge.x,edgeZ=edge.z,leftSupport=left,rightSupport=right}
     end
    end
   end
  end
 end
 return best
end
-- Walking routes: shortest paths between every pair of entrances, map exits
-- and sign-reading spots. Returns per-cell traffic, solid sides and corridors.
function M.analyze(s,checkpoint,blocked)
 checkpoint=checkpoint or function()end;blocked=blocked or {}
 local w,h=s.width,s.height;local grid={}
 for _,c in ipairs(s.cells or {})do grid[c.z*w+c.x]=c end
 local function cell(x,z)if x<0 or z<0 or x>=w or z>=h then return nil end;return grid[z*w+x]end
 local function walk(x,z)local c=cell(x,z);return c and c.walkable==true and not(c.tags and c.tags.water)and not blocked[z*w+x]end
 local portals={};local seenPortal={}
 local function portal(x,z)
  if walk(x,z)and not seenPortal[z*w+x]then seenPortal[z*w+x]=true;portals[#portals+1]=z*w+x end
 end
 for _,c in ipairs(s.cells or {})do
  local t=c.tags or {}
  if t.door then portal(c.x,c.z);portal(c.x,c.z+1)end
  if t.signpost then portal(c.x,c.z+1)end
 end
 -- Group each edge's walkable runs into one exit portal (its middle cell).
 local function edgeRuns(list)
  local run={}
  local function flush()if #run>0 then local m=run[math.floor((#run+1)/2)];portal(m[1],m[2]);run={}end end
  for _,p in ipairs(list)do if walk(p[1],p[2])then run[#run+1]=p else flush()end end
  flush()
 end
 if s.tags and s.tags.outdoor then
  local top,bottom,left,right={},{},{},{}
  for x=0,w-1 do top[#top+1]={x,0};bottom[#bottom+1]={x,h-1}end
  for z=0,h-1 do left[#left+1]={0,z};right[#right+1]={w-1,z}end
  edgeRuns(top);edgeRuns(bottom);edgeRuns(left);edgeRuns(right)
 end
 local traffic={}
 local dirs={{1,0},{-1,0},{0,1},{0,-1}}
 local lawnCost={}
 for _,c in ipairs(s.cells or {})do
  local t=c.metadata and c.metadata.tile
  if t==44 or t==48 or c.kind=='flower' or(c.tags and c.tags.flower)then lawnCost[c.z*w+c.x]=6 end
 end
 if #portals<=64 then
  for i=1,#portals-1 do
   -- TEST159: weighted search (Dial's buckets). People keep to paving:
   -- lawn and flower cells cost more, so traced routes stop cutting across
   -- open lawns and those lawns stay free for the big festive displays.
   checkpoint();local start=portals[i];local parent={[start]=start};local dist={[start]=0}
   local buckets={[0]={start}};local b=0;local maxB=0;local done={}
   while b<=maxB do
    local list=buckets[b]
    if list then
     local idx=1
     while idx<=#list do
      local k=list[idx];idx=idx+1
      if not done[k]and dist[k]==b then
       done[k]=true;local x,z=k%w,math.floor(k/w)
       for _,d in ipairs(dirs)do local nx,nz=x+d[1],z+d[2];local nk=nz*w+nx
        if nx>=0 and nz>=0 and nx<w and nz<h and not done[nk]and walk(nx,nz)then
         local nd=b+(lawnCost[nk]or 1)
         if not dist[nk]or nd<dist[nk]then
          dist[nk]=nd;parent[nk]=k
          buckets[nd]=buckets[nd]or{};local bl=buckets[nd];bl[#bl+1]=nk
          if nd>maxB then maxB=nd end
         end
        end
       end
      end
     end
     buckets[b]=nil
    end
    b=b+1
   end
   for j=i+1,#portals do local k=portals[j]
    if parent[k]then
     local guard=0
     while k~=start and guard<w*h do traffic[k]=(traffic[k]or 0)+1;k=parent[k];guard=guard+1 end
     traffic[start]=(traffic[start]or 0)+1
    end
   end
  end
 end
 -- Lane width: contiguous walkable run through each cell in x and in z.
 -- A 2-3 tile wide lane is still a lane even where the traced route uses
 -- only one of its tiles.
 local runX,runZ={},{}
 for z=0,h-1 do local x=0
  while x<w do
   if walk(x,z)then local x0=x;while x<w and walk(x,z)do x=x+1 end
    for xx=x0,x-1 do runX[z*w+xx]=x-x0 end
   else x=x+1 end
  end
 end
 for x=0,w-1 do local z=0
  while z<h do
   if walk(x,z)then local z0=z;while z<h and walk(x,z)do z=z+1 end
    for zz=z0,z-1 do runZ[zz*w+x]=z-z0 end
   else z=z+1 end
  end
 end
 local sides,corridor={},{}
 for z=0,h-1 do for x=0,w-1 do if walk(x,z)then
  local k=z*w+x;local list={}
  for _,d in ipairs(dirs)do local nx,nz=x+d[1],z+d[2]
   local c=cell(nx,nz)
   if c and not walk(nx,nz)then list[#list+1]=d end
  end
  sides[k]=list
  local wSolid=cell(x-1,z)and not walk(x-1,z);local eSolid=cell(x+1,z)and not walk(x+1,z)
  local nSolid=cell(x,z-1)and not walk(x,z-1);local sSolid=cell(x,z+1)and not walk(x,z+1)
  corridor[k]=(wSolid and eSolid)or(nSolid and sSolid)or math.min(runX[k]or 0,runZ[k]or 0)<=3
  -- Beside a traced route in a lane up to 5 wide also counts as the lane.
  if not corridor[k]and math.min(runX[k]or 0,runZ[k]or 0)<=5 then
   for _,d in ipairs(dirs)do local nk=(z+d[2])*w+x+d[1]
    if traffic[nk]and x+d[1]>=0 and x+d[1]<w then corridor[k]=true;break end
   end
  end
 end end end
 -- Pairwise walking distance between portals, optionally around a footprint.
 local function distances(extra)
  local out={}
  for i=1,#portals do
   checkpoint();local start=portals[i];local dist={[start]=0};local queue={start};local head=1
   if not extra[start]then
    while head<=#queue do
     local k=queue[head];head=head+1;local x,z=k%w,math.floor(k/w)
     for _,d in ipairs(dirs)do local nx,nz=x+d[1],z+d[2];local nk=nz*w+nx
      if nx>=0 and nz>=0 and nx<w and nz<h and not dist[nk]and not extra[nk]and walk(nx,nz)then dist[nk]=dist[k]+1;queue[#queue+1]=nk end
     end
    end
   end
   out[i]={}
   for j=1,#portals do out[i][j]=dist[portals[j]]end
  end
  return out
 end
 return {traffic=traffic,sides=sides,corridor=corridor,portals=#portals,portalCells=portals,walk=walk,distances=distances}
end
function M.plan(s,info,o,checkpoint)
 checkpoint=checkpoint or function()end
 local out={items={},id=s.id,holiday=o.holiday,buildings=0,skipped=0,coverage='none',routeCells=0}
 if o.holiday=='off'or not o.holiday then return out end
 local holiday=o.holiday;local halloween=holiday=='halloween'
 local outside=s.tags and s.tags.outdoor
 local town=M.towns[s.id];local interior=not outside and s.tags and s.tags.interior and o.interiors and allowedInterior(s.id)
 -- These authored floors are occupied by furniture and narrow aisles.
 -- Its ROM walkability cannot identify a safe freestanding display footprint.
 local floorDisplays=not interior
 -- TEST149: no loose floor piles indoors. Rooms are furnished by Battle Art
 -- and the interior overhaul; this planner cannot see tables, shelves or
 -- sills, so a pumpkin cluster could only ever land as clutter on the floor
 -- (and Joseph's screenshots showed exactly that in every room). Interiors
 -- keep the wall-mounted banner, webs and lantern string only.
 local route=outside and (s.id:match('^ROUTE_')or s.id:find('FOREST',1,true)or s.id:find('SAFARI_ZONE',1,true))
 if not town and not interior and not route then return out end
 local spectral=halloween and(s.id:find('LAVENDER',1,true)~=nil)
 if holiday=='christmas'then out.palette=town and town.palette or(s.id:find('GAME_CORNER',1,true)and 'royal'or 'classic')
 elseif halloween then out.palette=spectral and 'spectral'or 'spooky'
 elseif holiday=='harvest'then out.palette='harvest'
 elseif holiday=='easter'then out.palette='pastel'
 else out.palette='patriot'end
 out.coverage=town and 'town'or interior and 'interior'or 'route'
 out.name=town and town.name or s.id
 local cs=s.cellSize or 16;local w,h=s.width,s.height;local grid={}
 for _,c in ipairs(s.cells or {})do grid[c.z*w+c.x+1]=c end
 local A=M.analyze(s,checkpoint);out.portals=A.portals
 for _ in pairs(A.traffic)do out.routeCells=out.routeCells+1 end
 local occupied=info and info.occupied or {};local used={};local denied={}
 local function cell(x,z)if x<0 or z<0 or x>=w or z>=h then return nil end;return grid[z*w+x+1]end
 for _,c in ipairs(s.cells or {})do if c.tags and c.tags.door then denied[#denied+1]={x=(c.x+.5)*cs,z=(c.z+.5)*cs,r=cs*2.0,door=true}end end
 for _,a in ipairs(s.actors or {})do if a.pose then denied[#denied+1]={x=a.pose.x,z=a.pose.z,r=cs*1.25,actor=true}end end
 for _,b in ipairs(info and info.buildings or {})do
  denied[#denied+1]={x=(b.x0+b.x1)/2,z=(b.z0+b.z1)/2,box=b}
 end
 for _,b in ipairs(info and info.obstacles or {})do
  denied[#denied+1]={x=(b.x0+b.x1)/2,z=(b.z0+b.z1)/2,fixture=b,street=b.street}
 end
 for _,l in ipairs(info and info.lamps or {})do denied[#denied+1]={x=l.x,z=l.z,r=3,lamp=true,street=l.street}end
 -- Legendary wayfinder signs are wider than their cell: keep displays off them.
 for _,c in ipairs(s.cells or {})do if c.tags and c.tags.signpost then denied[#denied+1]={x=(c.x+.5)*cs,z=(c.z+.5)*cs,r=cs*1.35}end end
 -- Deck railings and palm trunks are solid to the eye even on walkable tiles.
 for _,r in ipairs(info and info.docks or {})do
  local b=r.cross and{x0=r.line-1,x1=r.line+1,z0=r.a0,z1=r.a1,margin=7}or{x0=r.a0,x1=r.a1,z0=r.line-1,z1=r.line+1,margin=7}
  denied[#denied+1]={x=(b.x0+b.x1)/2,z=(b.z0+b.z1)/2,fixture=b}
 end
 for _,p in ipairs(info and info.palms or {})do denied[#denied+1]={x=p.cx,z=p.cz,r=8}end
 local function clear(x,z,r,doorstep,skipLamps,classic,lawn)
  if x-r<cs*.5 or x+r>(w-.5)*cs or z-r<cs*.5 or z+r>(h-.5)*cs then return false end
  for _,d in ipairs(denied)do
   -- TEST160: wandering wildlife/NPC positions at snapshot time are not
   -- furniture; big lawn displays ignore them (they walk around them).
   if lawn and d.actor then
   else
   -- classic: the automatic town centerpiece keeps its PATCH5 spot; the city
   -- furniture/fence data added in PATCH7 only steers street props.
   if classic and d.street then
   elseif d.door then
    if doorstep then
     -- Keep the entire entrance cell and a straight approach lane open.
     if math.abs(x-d.x)<cs*.5+r+1 and math.abs(z-d.z)<cs*1.5+r then return false end
    elseif (x-d.x)^2+(z-d.z)^2<(r+d.r)^2 then return false end
   elseif d.fixture then
    local b=d.fixture;local dx=math.max(b.x0-x,0,x-b.x1);local dz=math.max(b.z0-z,0,z-b.z1)
    if dx*dx+dz*dz<(r+(b.margin or 2.5))^2 then return false end
   elseif d.box then local b=d.box
    if x+r>b.x0-3 and x-r<b.x1+3 and z+r>b.z0-3 and z-r<b.z1+3 then return false end
   elseif d.lamp then if not skipLamps and(x-d.x)^2+(z-d.z)^2<(r+d.r)^2 then return false end
   elseif (x-d.x)^2+(z-d.z)^2<(r+d.r)^2 then return false end
   end
  end
  for _,u in ipairs(used)do if(x-u.x)^2+(z-u.z)^2<(r+u.r+cs*.3)^2 then return false end end
  for zz=math.floor((z-r)/cs),math.floor((z+r)/cs)do for xx=math.floor((x-r)/cs),math.floor((x+r)/cs)do
   local c=cell(xx,zz);local tags=c and c.tags or {}
   if not c or c.walkable~=true or tags.water or tags.grass or tags.door or tags.signpost or tags.tree or (c.height or 0)>3 then return false end
   if occupied[zz*w+xx+1]and not doorstep then return false end
  end end
  if doorstep then
   -- Coarse occupied cells include the adjacent wall. Test actual solid faces
   -- at pumpkin height instead, so planters/counters still exclude a placement.
   for _,b in pairs(info and info.quadBounds or {})do
    if b.y1>.5 and b.y0<8 and x+r>b.x0-1 and x-r<b.x1+1 and z+r>b.z0-1 and z-r<b.z1+1 then return false end
   end
  end
  return true
 end
 local function add(kind,x,z,r,extra)
  local p={kind=kind,x=x,y=.30,z=z,r=r,palette=out.palette,seed=#out.items+1,spectral=spectral or nil}
  for k,v in pairs(extra or {})do p[k]=v end
  out.items[#out.items+1]=p
  if r and r>0 then used[#used+1]={x=x,z=z,r=r}end
  return p
 end
 -- Traffic under a disc footprint, and on the ground a tall display hides.
 local function routeCost(x,z,r,height)
  local cover,shadow=0,0
  for zz=math.floor((z-r)/cs),math.floor((z+r)/cs)do for xx=math.floor((x-r)/cs),math.floor((x+r)/cs)do
   local cx,cz=(xx+.5)*cs,(zz+.5)*cs
   if (cx-x)^2+(cz-z)^2<=(r+cs*.35)^2 and A.traffic[zz*w+xx]then cover=cover+1 end
  end end
  if height and height>0 then
   -- The camera looks north from the south: a tall display hides the
   -- walkable ground just north of it, where the player would vanish.
   local reach=height*.5
   for zz=math.floor((z-r-reach)/cs),math.floor((z-r)/cs)do for xx=math.floor((x-r)/cs),math.floor((x+r)/cs)do
    if A.traffic[zz*w+xx]then shadow=shadow+1 end
   end end
  end
  return cover,shadow
 end
 local candidates={}
 for _,c in ipairs(s.cells or {})do
  local t=c.tags or {}
  if c.walkable and not(t.grass or t.water or t.door or t.flower)then
   local k=c.z*w+c.x
   candidates[#candidates+1]={x=(c.x+.5)*cs,z=(c.z+.5)*cs,k=k,traffic=A.traffic[k]or 0,sides=A.sides[k]or {},corridor=A.corridor[k]}
  end
 end
 -- Centerpiece: a town square stands in open ground people walk around, not on
 -- the only way through. Score the nearest clear footprints by the extra
 -- steps they add between entrances/exits, and by the routes they hide.
 if town or (interior and floorDisplays) then
  local tx,tz=w*cs*.5,h*cs*.55
  if info and info.plaza then tx,tz=info.plaza.x,info.plaza.z end
  if interior then tx,tz=cs*1.8,cs*1.8 end
  -- A spot the player chose (TOWN TREE SPOT) wins over every automatic rule.
  local anchor=not interior and o.treeSpots and o.treeSpots[s.id]
  -- TEST72: move both seasonal trees north from the shop-side end of
  -- Cerulean's pond to the open plaza alongside its western railing.
  -- Pond coordinates are 8-unit terrain tiles. Restrict the entire search
  -- to this plaza, keeping the south-end passage out of fallback choices.
  local pond=info and info.treePond
  local pondTree=not anchor and s.id=='CERULEAN_CITY' and (holiday=='christmas' or halloween) and pond
  local treeArea
  if pondTree then
   local west=pond.x0*8
   local middle=(pond.z0+pond.z1+1)*4
   treeArea={x0=west-104,x1=west-40,z0=middle-24,z1=middle+24}
   anchor={x=west-72,z=middle}
  end
  if anchor then tx,tz=anchor.x,anchor.z end
  local radii=interior and {12,10,8} or {30,25,20,15,11}
  local base=(not interior and #A.portalCells>1 and #A.portalCells<=40)and A.distances({})or nil
  local function footprint(x,z,r)
   local set={}
   for zz=math.floor((z-r)/cs),math.floor((z+r)/cs)do for xx=math.floor((x-r)/cs),math.floor((x+r)/cs)do
    local cx,cz=(xx+.5)*cs,(zz+.5)*cs
    if (cx-x)^2+(cz-z)^2<=(r*.92)^2 then set[zz*w+xx]=true end
   end end
   return set
  end
  local function detour(x,z,r)
   if not base then return 0,false end
   local d=A.distances(footprint(x,z,r));local extra,cut=0,false
   for i=1,#base do for j=i+1,#base do
    if base[i][j]then
     if not d[i][j]then cut=true else extra=extra+(d[i][j]-base[i][j])end
    end
   end end
   return extra,cut
  end
  -- TEST147: indoors there is no detour check, so a display could land in
  -- the only aisle (Safari gate: pumpkins between the counters). It must
  -- touch no traced route or narrow lane, and stand against a wall/counter.
  local function indoorSpot(x,z,r)
   local backed=false
   for zz=math.floor((z-r-cs*.6)/cs),math.floor((z+r+cs*.6)/cs)do for xx=math.floor((x-r-cs*.6)/cs),math.floor((x+r+cs*.6)/cs)do
    local cx,cz=(xx+.5)*cs,(zz+.5)*cs;local k=zz*w+xx
    local inside=math.abs(cx-x)<=r+cs*.5 and math.abs(cz-z)<=r+cs*.5
    if inside and xx>=0 and zz>=0 and xx<w and zz<h then
     if A.traffic[k]or A.corridor[k]then return false end
    end
    local c=cell(xx,zz)
    if not c or c.walkable~=true then backed=true end
   end end
   return backed
  end
  local pick,rad,fallback
  for _,r in ipairs(radii)do
   local height=interior and 0 or math.min((town and town.height or 105),r*4.5)
   local list={}
   for z2=1,h*2-1 do checkpoint();for x2=1,w*2-1 do
    local x,z=x2*cs*.5,z2*cs*.5
    local inArea=not treeArea or (x>=treeArea.x0 and x<=treeArea.x1 and z>=treeArea.z0 and z<=treeArea.z1)
    local onRoute=false
    if treeArea then
     for zz=math.floor((z-r-4)/cs),math.floor((z+r+4)/cs)do
      for xx=math.floor((x-r-4)/cs),math.floor((x+r+4)/cs)do
       if A.traffic[zz*w+xx]then onRoute=true end
      end
     end
    end
    if inArea and not onRoute and clear(x,z,r+(interior and 0 or 4),nil,nil,not anchor)and(not interior or indoorSpot(x,z,r))then
     local _,shadow=routeCost(x,z,r,height)
     local d=math.sqrt((x-tx)^2+(z-tz)^2)
     if interior then d=d+math.min(x,w*cs-x,z,h*cs-z)*4 end
     if anchor then list[#list+1]={x=x,z=z,pre=d,dist=d}
     else list[#list+1]={x=x,z=z,pre=d*.6+shadow*140}end
    end
   end end
   table.sort(list,function(a,b)return a.pre<b.pre end)
   local best
   if anchor then
    -- Nearest fit to the chosen spot; shrink rather than wander away.
    if list[1]and list[1].dist<=40 then pick,rad=list[1],r;break end
    if list[1]and(not fallback or list[1].dist<fallback.dist)then fallback=list[1];fallback.r=r;fallback.score=list[1].dist end
   end
   for i=1,(anchor and 0 or math.min(#list,interior and 1 or 36))do local c=list[i]
    local extra,cut=detour(c.x,c.z,r)
    if not cut then
     c.score=c.pre+extra*45;c.extra=extra
     if not best or c.score<best.score then best=c end
    end
   end
   -- A detour of about one step per affected route is a square people walk
   -- around; more than that means it stands in a street.
   local limit=base and math.max(3,#base*1.2)or 0
   -- Largest size that fits a square people walk around (PATCH5 behaviour).
   if best and(best.extra or 0)<=limit then pick,rad=best,r;break end
   if best and(not fallback or best.score<fallback.score)and r<=20 then fallback=best;fallback.r=r end
  end
  if not pick and fallback then pick,rad=fallback,fallback.r;out.centerpieceDetour=fallback.extra end
  if pick then
   out.centerpieceDetour=pick.extra or 0
   if interior then
    add('centerpiece',pick.x,pick.z,rad,{radius=rad*.66,height=34,indoor=true})
   else
    local htree=(town.height or 105)*(o.treeSize=='grand'and .78 or 1)
    htree=math.min(htree,rad*4.5)
    add('centerpiece',pick.x,pick.z,rad+4,{radius=rad,height=htree})
    -- Re-trace routes around it so street props avoid the new detours.
    A=M.analyze(s,checkpoint,footprint(pick.x,pick.z,rad))
   end
  else out.skipped=out.skipped+1 end
 end
 for _,b in ipairs(info and info.buildings or {})do
  if not b.claimOnly and b.x1-b.x0>=24 then
   add('facade',(b.x0+b.x1)/2,b.z1,0,{building=b});out.buildings=out.buildings+1
  end
 end
 if interior then
  -- Locate the real rear walkable band. Displays are wall-mounted above actors.
  local minz,maxx,minx=h*cs,0,w*cs
  for _,p in ipairs(candidates)do minz=math.min(minz,p.z);minx=math.min(minx,p.x);maxx=math.max(maxx,p.x)end
  -- TEST148: the banner follows the room's real back wall (see HostBridge)
  -- and is split around rear doorways so it never strings across an exit.
  local shell=info and info.shellRoom
  if maxx-minx>20 and not(info and info.authoredRoom)then
   local wallZ,y,x0,x1
   if shell then wallZ,y,x0,x1=(shell.north or 0)+.25,math.min(44,(shell.height or 60)-16),cs*.5,(w-.5)*cs
   else wallZ,y,x0,x1=minz-cs*.5+.25,30,minx-cs*.5+2,maxx+cs*.5-2 end
   local gaps={}
   for _,c in ipairs(s.cells or {})do
    if c.tags and c.tags.door and(c.z+.5)*cs<minz then gaps[#gaps+1]={c.x*cs-3,(c.x+1)*cs+3}end
   end
   table.sort(gaps,function(a,b)return a[1]<b[1]end)
   local spans,at={},x0
   for _,g in ipairs(gaps)do
    if g[1]>at then spans[#spans+1]={at,math.min(g[1],x1)}end
    at=math.max(at,g[2])
   end
   if at<x1 then spans[#spans+1]={at,x1}end
   local cx=(x0+x1)/2;local local_={}
   for _,sp in ipairs(spans)do if sp[2]-sp[1]>=20 then local_[#local_+1]={sp[1]-cx,sp[2]-cx,y}end end
   if #local_>0 then add('indoor_trim',cx,wallZ,0,{width=x1-x0,ceiling=y,spans=local_})end
  end
 end
 -- Doorsteps: a matched pair of small displays beside every real entrance.
 if town or route then
  for _,d in ipairs(info and info.doors or {})do
   for _,side in ipairs({-1,1})do
    local x=d.x+side*(d.width*.5+5.5);local z=d.z+8
    if x-4>d.building.x0 and x+4<d.building.x1 and clear(x,z,4,true)then
     add(halloween and 'door_pumpkins'or 'door_decor',x,z,4,{side=side,doorX=d.x,doorZ=d.z})
    else out.skipped=out.skipped+1 end
   end
  end
 end
 -- TEST150: pumpkin patch + hayride (Halloween and Harvest).
 -- Open-lawn footprint tests shared by the patch, wagon and festive fields.
 local function cellOk(xx,zz)
  local c=cell(xx,zz);if not c then return false end
  local t=c.tags or {}
  if c.walkable~=true or t.water or t.grass or t.door or t.signpost or t.tree or(c.height or 0)>3 then return false end
  if A.traffic[zz*w+xx]then return false end
  -- a lawn cell only needs its middle clear: fences and kerbs at its edge are fine
  return clear((xx+.5)*cs,(zz+.5)*cs,cs*.34,nil,nil,nil,true)
 end
 local function rectOk(x0,z0,cw,cd)
  if x0<1 or z0<1 or x0+cw>w-1 or z0+cd>h-1 then return false end
  for zz=z0,z0+cd-1 do for xx=x0,x0+cw-1 do if not cellOk(xx,zz)then return false end end end
  return true
 end
 local patch=town and(halloween or holiday=='harvest')and M.patches[s.id]
 if patch then
  local tx,tz=w*.5,h*.55
  local best,bestScore
  for z0=1,h-patch.cd-1 do checkpoint();for x0=1,w-patch.cw-1 do
   if rectOk(x0,z0,patch.cw,patch.cd)then
    local ring,lane=0,0
    for zz=z0-1,z0+patch.cd do for xx=x0-1,x0+patch.cw do
     if A.traffic[zz*w+xx]then ring=ring+1 end
     if A.corridor[zz*w+xx]then lane=lane+1 end
    end end
    local cx,cz=x0+patch.cw/2,z0+patch.cd/2
    local score=ring*20+lane*4+math.sqrt((cx-tx)^2+(cz-tz)^2)*.5
    if patch.wagon then
     -- Prefer a lawn with room for the wagon beside it (east/west first).
     local mid=math.floor((patch.cd-2)/2);local extra=60
     for i,o in ipairs({{patch.cw,mid},{-4,mid},{1,-2},{1,patch.cd}})do
      if extra>0 and rectOk(x0+o[1],z0+o[2],4,2)then extra=i<=2 and 0 or 10 end
     end
     score=score+extra
    end
    if not bestScore or score<bestScore then best,bestScore={x0=x0,z0=z0},score end
   end
  end end
  if best then
   local W,D=patch.cw*cs,patch.cd*cs
   local px,pz=(best.x0+patch.cw/2)*cs,(best.z0+patch.cd/2)*cs
   -- Choose the wagon's spot before reserving the patch (whose keep-clear
   -- disc would otherwise cover the lawn right beside it).
   -- TEST152: real towns crowd the patch with fences and walls, so the
   -- wagon searches every spot within 4 cells, side-on (4x2) or end-on (2x4),
   -- and takes the nearest clear one (side-on wins ties: its sign faces the
   -- street camera).
   local wagonAt
   if patch.wagon then
    local bestD
    for _,shape in ipairs({{4,2,0},{2,4,math.pi/2}})do
     local ww,dd=shape[1],shape[2]
     for z0=best.z0-dd-4,best.z0+patch.cd+4 do for x0=best.x0-ww-4,best.x0+patch.cw+4 do
      -- outside the patch rectangle (touching is fine)
      local apart=x0+ww<=best.x0 or x0>=best.x0+patch.cw or z0+dd<=best.z0 or z0>=best.z0+patch.cd
      if apart then
       local gx=math.max(best.x0-(x0+ww),0,x0-(best.x0+patch.cw))
       local gz=math.max(best.z0-(z0+dd),0,z0-(best.z0+patch.cd))
       local dist=gx+gz+(shape[3]~=0 and .5 or 0)
       if(not bestD or dist<bestD)and rectOk(x0,z0,ww,dd)then
        bestD=dist;wagonAt={x=x0,z=z0,w=ww,d=dd,yaw=shape[3]}
       end
      end
     end end
    end
   end
   add('pumpkin_patch',px,pz,math.sqrt(W*W+D*D)/2-2,{w=W,d=D,mini=patch.mini})
   out.patch={x=best.x0,z=best.z0}
   if wagonAt then
    if wagonAt.yaw==0 then
     add('hayride',(wagonAt.x+2)*cs-4,(wagonAt.z+1)*cs,30)
    else
     -- end-on: the wagon's long axis runs along z (model x maps to -z)
     add('hayride',(wagonAt.x+1)*cs,(wagonAt.z+2)*cs+4,30,{yaw=wagonAt.yaw})
    end
    out.hayride=wagonAt
   end
  end
 end
 -- TEST154: festive field pieces fill each town's big empty lawns.
 -- Christmas: Santa's sleigh and reindeer team, plus glowing inflatables.
 -- Halloween: inflatable jack-o'-lantern, ghost and black cat groups.
 local pieces={}
 if town and holiday=='christmas'then
  pieces[#pieces+1]={kind='sleigh',cw=6,cd=3,pairs=3,alt={cw=4,cd=3,pairs=2}}
  for i=1,(o.density=='extravagant'and 2 or 1)do pieces[#pieces+1]={kind='inflatables',cw=4,cd=3,alt={kind='inflatable',cw=2,cd=2}}end
 elseif town and halloween then
  for i=1,(o.density=='extravagant'and 2 or 1)+(patch and 0 or 1)do pieces[#pieces+1]={kind='inflatables',cw=4,cd=3,alt={kind='inflatable',cw=2,cd=2}}end
 end
 -- Small lawns in tight towns still get a couple of single inflatables.
 if town and(holiday=='christmas'or halloween)then
  for i=1,2 do pieces[#pieces+1]={kind='inflatable',cw=2,cd=2}end
 end
 local placedPieces={}
 for _,it in ipairs(out.items)do
  if it.kind=='centerpiece'or it.kind=='pumpkin_patch'or it.kind=='hayride'then placedPieces[#placedPieces+1]={x=it.x/cs,z=it.z/cs}end
 end
 out.fields=0
 local function search(piece)
  local best,bestScore
  for z0=1,h-piece.cd-1 do checkpoint();for x0=1,w-piece.cw-1 do
   if rectOk(x0,z0,piece.cw,piece.cd)then
    local ring,lane=0,0
    for zz=z0-1,z0+piece.cd do for xx=x0-1,x0+piece.cw do
     if A.traffic[zz*w+xx]then ring=ring+1 end
     if A.corridor[zz*w+xx]then lane=lane+1 end
    end end
    local cx,cz=x0+piece.cw/2,z0+piece.cd/2;local near=20
    for _,q in ipairs(placedPieces)do near=math.min(near,math.sqrt((cx-q.x)^2+(cz-q.z)^2))end
    local score=ring*20+lane*4-near*3
    if not bestScore or score<bestScore then best,bestScore={x0=x0,z0=z0},score end
   end
  end end
  return best
 end
 for _,piece in ipairs(pieces)do
  local best=search(piece)
  -- A smaller version where the full piece cannot fit.
  if not best and piece.alt then
   local alt={kind=piece.alt.kind or piece.kind,cw=piece.alt.cw,cd=piece.alt.cd,pairs=piece.alt.pairs}
   best=search(alt);if best then piece=alt end
  end
  if best then
   local W,D=piece.cw*cs,piece.cd*cs
   local px,pz=(best.x0+piece.cw/2)*cs,(best.z0+piece.cd/2)*cs
   add(piece.kind,px,pz,math.max(W,D)*.5,{w=W,d=D,holiday=holiday,pairs=piece.pairs})
   placedPieces[#placedPieces+1]={x=px/cs,z=pz/cs};out.fields=out.fields+1
  end
 end
 -- TEST157: fill pass. Every remaining open lawn of 4x3 cells or more gets a
 -- display sized to it: a second pumpkin patch first at Halloween/Harvest,
 -- then full front-yard displays (giant inflatables, reindeer, candy canes;
 -- or pumpkins and tombstones). Biggest shape that fits wins.
 if town and(holiday=='christmas'or halloween or holiday=='harvest')then
  local fills=o.density=='extravagant'and 8 or 4
  local shapes={{7,4},{6,4},{5,4},{6,3},{5,3},{4,4},{4,3},{3,3},{3,2}}
  local secondPatch=(halloween or holiday=='harvest')
  for _=1,fills do
   local best,shape
   for _,sh in ipairs(shapes)do
    best=search({cw=sh[1],cd=sh[2]})
    if best then shape=sh;break end
   end
   if not best then break end
   local cw,cd=shape[1],shape[2]
   local W,D=cw*cs,cd*cs
   local px,pz=(best.x0+cw/2)*cs,(best.z0+cd/2)*cs
   if cw<4 then
    -- a tight lawn still gets a compact trio of inflatables
    if holiday=='harvest'then break end
    add('inflatables',px,pz,math.max(W,D)*.5,{w=W,d=D,holiday=holiday,scale=.70})
   elseif secondPatch then
    secondPatch=false
    add('pumpkin_patch',px,pz,math.sqrt(W*W+D*D)/2-2,{w=W,d=D,mini=cw<5})
   elseif holiday=='harvest'then
    break
   elseif holiday=='christmas'and out.fields%2==1 then
    -- TEST161: alternate yards with a parade of nutcracker guards
    add('nutcrackers',px,pz,math.max(W,D)*.5,{w=W,d=D,holiday=holiday})
   else
    add('yard',px,pz,math.max(W,D)*.5,{w=W,d=D,holiday=holiday})
   end
   placedPieces[#placedPieces+1]={x=px/cs,z=pz/cs};out.fields=out.fields+1
  end
 end
 if halloween then
  for bi,b in ipairs(info and info.buildings or {})do
   if not b.claimOnly and b.x1-b.x0>=40 and b.eave>=30 and (o.density=='extravagant'or bi%2==1)then
    local x=b.x0+(b.x1-b.x0)*.30;local z=b.z1
    for _,p in ipairs(b.frontProfile or {})do if math.abs(p.x-x)<8 then z=math.max(z,p.z)end end
    add('wall_skeleton',x,z+2.6,0,{y=b.eave-19,anchorY=b.eave,scale=.82})
    local seat=M.roofSeat(b)
    if seat then
     local scale=1.05
     add('roof_skeleton',seat.x,seat.z,0,{y=seat.y-6.76*scale,scale=scale,anchorY=seat.y,yaw=seat.yaw})
    end
   end
  end
 end
 -- Waterfront railings: one wrapped garland/light string per straight run.
 if town or route then
  local budget=2400
  for _,r in ipairs(info and info.docks or {})do
   local len=r.a1-r.a0
   if len>=8 and budget>=len then budget=budget-len;add('dock_garland',0,0,0,{run=r,y=0})end
  end
 end
 -- TEST162: district railings get swagged garlands / light strings and
 -- toppers on their posts, in chunks so each mesh stays small.
 if(town or route)and info and info.railings then
  local R=info.railings;local chunk=60
  for i=1,#R.segs,chunk do
   local segs={}
   for j=i,math.min(#R.segs,i+chunk-1)do segs[#segs+1]=R.segs[j]end
   local posts={}
   if i==1 then posts=R.posts end
   add('rail_garland',0,0,0,{segs=segs,posts=posts,style=R.style,y=0})
  end
 end
 -- Vegas-style lights wrapped up each palm trunk and along its fronds.
 if town or route then
  for _,p in ipairs(info and info.palms or {})do add('palm_lights',0,0,0,{palm=p,y=0})end
 end
 for i,l in ipairs(info and info.lamps or {})do
  if i<=24 then
   if halloween then
    local scale=math.min(.95,math.max(.52,(l.shaftHeight or l.height*.70)/25))
    add('lamp_skeleton',l.x,l.z,0,{y=(l.shaftHeight or 11)>18 and 5.0 or 1.4,scale=scale,anchorHeight=l.height,poleRadius=l.radius or .20,yaw=(i%2==0 and .45 or -.45)})
   else
    add('lamp_decor',l.x,l.z,0,{y=0,height=l.shaftHeight or l.height*.7,poleRadius=l.radius or .20})
   end
  end
 end
 -- Street displays: off every route, out of one-cell corridors, backed
 -- against a wall where possible and spread evenly across the map.
 local list=M.variants[spectral and 'spectral'or holiday]or M.variants.christmas
 local variants=interior and list.indoor or route and list.small or list.big
 if halloween and not spectral and town and not interior and M.cityHalloween[s.id]then variants=M.cityHalloween[s.id]end
 local target=interior and (o.density=='extravagant'and 4 or 2)or route and (o.density=='extravagant'and 7 or 4)or(o.density=='extravagant'and 16 or 10)
 if not floorDisplays then target=0 end
 local openLimit=math.max(1,math.floor(target/3));local openUsed=0
 local radius=interior and 5.5 or route and 6 or 6.5
 local offset=textHash(s.id)
 local anchors={}
 for _,it in ipairs(out.items)do if it.kind=='centerpiece'then anchors[#anchors+1]={x=it.x,z=it.z,pad=it.r}end end
 for _,d in ipairs(info and info.doors or {})do anchors[#anchors+1]={x=d.x,z=d.z+cs,pad=cs*.5}end
 local placed=0
 for n=1,target do
  local best,bestScore;checkpoint()
  for _,p in ipairs(candidates)do
   local sides=A.sides[p.k]or {}
   if not A.traffic[p.k]and not A.corridor[p.k]and not p.taken and(#sides>0 or openUsed<openLimit)then
    local sx,sz=0,0;for _,d in ipairs(sides)do sx=sx+d[1];sz=sz+d[2]end
    local backed=#sides>0
    -- Tuck toward the supporting side, without crossing into it.
    local len=math.sqrt(sx*sx+sz*sz);local ox,oz=0,0
    if len>0 then ox,oz=sx/len*(cs*.5-radius-.3),sz/len*(cs*.5-radius-.3)end
    -- Small deterministic jitter breaks up the cell lattice on open ground.
    local jx,jz=0,0
    if not backed then jx=((p.k*37)%7-3)*.9;jz=((p.k*53)%7-3)*.9 end
    local x,z=p.x+ox+jx,p.z+oz+jz
    local spread=cs*8
    for _,a in ipairs(anchors)do
     local d=math.sqrt((x-a.x)^2+(z-a.z)^2)-a.pad;if d<spread then spread=d end
    end
    -- Corners of a building's front read best; open lawns least.
    local score=math.max(0,spread)+(backed and cs*2.2 or 0)+(#sides>=2 and cs*.6 or 0)
    if spread>cs*1.4 and(not bestScore or score>bestScore)and clear(x,z,radius)then
     best={x=x,z=z,p=p,sx=sx,sz=sz,backed=backed};bestScore=score
    end
   end
  end
  if not best then out.skipped=out.skipped+(target-n+1);break end
  best.p.taken=true;if not best.backed then openUsed=openUsed+1 end
  -- Face away from the support, toward the street; never turn fully away
  -- from the camera, which always looks north from the south.
  local fx,fz=-best.sx,-best.sz
  if fx==0 and fz==0 then fx,fz=0,1 end
  if fz<0 then fz=0;if fx==0 then fx=1 end end
  local variant=variants[(n+offset)%#variants+1]
  add('street',best.x,best.z,radius,{small=interior or route or nil,variant=variant,yaw=math.atan2(fx,fz),indoor=interior or nil})
  anchors[#anchors+1]={x=best.x,z=best.z,pad=radius}
  placed=placed+1
 end
 out.streetPlaced=placed
 return out
end
return M
