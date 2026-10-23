-- Underground corridors and entrance halls. Source events/collision stay authoritative.
local V=...
local M={}
local cached
local palette={{.10,.12,.14},{.23,.26,.28},{.48,.34,.16},{.77,.60,.30},
 {.29,.32,.33},{.34,.37,.38},{.87,.79,.59},{.055,.065,.08},
 {.72,.12,.10},{.18,.45,.32},{.93,.62,.24},{.42,.44,.48},
 {.25,.27,.28},{.29,.31,.32},{.35,.37,.38},{.28,.13,.10}}
local function key(x,y)return (y+64)*4096+x+64 end
local entries={UNDERGROUND_PATH_ROUTE_5=true,UNDERGROUND_PATH_ROUTE_6=true,
 UNDERGROUND_PATH_ROUTE_6_COPY=true,UNDERGROUND_PATH_ROUTE_7=true,
 UNDERGROUND_PATH_ROUTE_7_COPY=true,UNDERGROUND_PATH_ROUTE_8=true}
function M.accepts(map)
 -- TEST175: the subway InteriorRooms builds (DUNGEON INTERIORS) comes first
 do local ok,own=pcall(function()return V.require('InteriorRooms').accepts(map)end);if ok and own then return false end end
 if V.require("CommunityVisuals").tunnels:get()~="n64memory" then return false end
 return map and map.tileset and ((entries[map.id] and map.tileset.id=='GATE') or
 (map.tileset.id=='UNDERGROUND' and (map.id=='UNDERGROUND_PATH_NORTH_SOUTH' or map.id=='UNDERGROUND_PATH_WEST_EAST')))
end
function M.layout(map)
 if not M.accepts(map)then return end
 if entries[map.id] then
  -- The four entrances share this exact 4x4-block plan, including warp cells.
  if map.def.width~=4 or map.def.height~=4 then return end
  local r={entry=true,floor={},walls={},stairs={},claim={},minX=0,minZ=0,maxX=128,maxZ=128}
  local hole={[10]=true,[11]=true,[26]=true,[27]=true}
  for y=0,15 do for x=0,15 do
   local t=map:tileAt(x,y)
   if not hole[t] then
    r.floor[#r.floor+1]={x=x*8,z=y*8}
    -- Keep original exterior warp tiles visible and supported.
    if t~=4 and t~=20 then r.claim[key(x,y)]={x,y}end
   end
  end end
  for n=0,15 do
   r.walls[#r.walls+1]={x=n*8,z=-8,side='north'}
   r.walls[#r.walls+1]={x=-8,z=n*8,side='west'}
   r.walls[#r.walls+1]={x=128,z=n*8,side='east'}
   if n<6 or n>9 then r.walls[#r.walls+1]={x=n*8,z=128,side='south'}end
  end
  return r
 end
 local r={floor={},walls={},stairs={},claim={},minX=1e9,minZ=1e9,maxX=-1e9,maxZ=-1e9}
 local floors={[11]=true,[12]=true,[21]=true,[24]=true}
 local sides={[2]='south',[6]='north',[9]='north',[22]='west',[23]='east'}
 for y=0,map.def.height*4-1 do for x=0,map.def.width*4-1 do
  local t=map:tileAt(x,y)
  if t==3 and map:tileAt(x+1,y)==4 and map:tileAt(x,y+1)==19 and map:tileAt(x+1,y+1)==20 then
   local ns=map.id=='UNDERGROUND_PATH_NORTH_SOUTH'
   local turn=ns and (y<map.def.height*2 and 0 or 2) or (x<map.def.width*2 and 1 or -1)
   r.stairs[#r.stairs+1]={x=x*8+8,z=y*8+8,turn=turn}
   for dy=0,1 do for dx=0,1 do r.claim[key(x+dx,y+dy)]={x+dx,y+dy,stair=true}end end
  end
  if floors[t] or sides[t] then
   r.claim[key(x,y)]={x,y}
   if floors[t] then
    r.floor[#r.floor+1]={x=x*8,z=y*8}
    r.minX=math.min(r.minX,x*8);r.maxX=math.max(r.maxX,x*8+8)
    r.minZ=math.min(r.minZ,y*8);r.maxZ=math.max(r.maxZ,y*8+8)
   else r.walls[#r.walls+1]={x=x*8,z=y*8,side=sides[t]}end
  end
 end end
 if #r.floor==0 then return end
 return r
end
function M.geometry(r,part)
 local vs,ix={},{}
 local ox,oz,turn=0,0,0
 local function point(p)
  if turn==1 then return {ox+p[3],p[2],oz-p[1]}end
  if turn==-1 then return {ox-p[3],p[2],oz+p[1]}end
  if turn==2 then return {ox-p[1],p[2],oz-p[3]}end
  return {ox+p[1],p[2],oz+p[3]}
 end
 local function quad(a,b,c,d,col,shade)
  local n=#vs
  for _,p in ipairs({a,b,c,d})do p=point(p);vs[#vs+1]={p[1],p[2],p[3],(col-.5)/16,.5,shade or 1}end
  for _,i in ipairs({1,2,3,1,3,4})do ix[#ix+1]=n+i end
 end
 local function box(x,y,z,w,h,d,col)
  local X,Y,Z=x+w,y+h,z+d
  quad({x,y,Z},{X,y,Z},{X,Y,Z},{x,Y,Z},col,.95)
  quad({X,y,z},{x,y,z},{x,Y,z},{X,Y,z},col,.76)
  quad({x,y,z},{x,y,Z},{x,Y,Z},{x,Y,z},col,.82)
  quad({X,y,Z},{X,y,z},{X,Y,z},{X,Y,Z},col,.88)
  quad({x,Y,Z},{X,Y,Z},{X,Y,z},{x,Y,z},col,1)
  quad({x,y,z},{X,y,z},{X,y,Z},{x,y,Z},col,.7)
 end
 local function cylinder(y,h,r0,r1,col,x,z)
  x,z=x or 0,z or 0
  for i=0,11 do
   local a,b=i*math.pi/6,(i+1)*math.pi/6
   local ca,sa,cb,sb=math.cos(a),math.sin(a),math.cos(b),math.sin(b)
   quad({x+r0*ca,y,z+r0*sa},{x+r1*ca,y+h,z+r1*sa},
    {x+r1*cb,y+h,z+r1*sb},{x+r0*cb,y,z+r0*sb},col,.85+.10*ca)
   quad({x,y+h,z},{x+r1*cb,y+h,z+r1*sb},{x+r1*ca,y+h,z+r1*sa},{x,y+h,z},col)
  end
 end

 local function front(x,y,z,w,h,col)quad({x,y,z},{x+w,y,z},{x+w,y+h,z},{x,y+h,z},col)end
 if not part then
  for _,p in ipairs(r.stairs)do
   ox,oz,turn=p.x,p.z,p.turn
   -- Low tread faces the corridor; rise toward the end wall / original warp.
   for n=0,7 do
    box(-8,0,6-n*2,16,(n+1)*1.5,2,5)
    box(-7.8,(n+1)*1.5,6-n*2,15.6,.10,.35,4)
   end
  end
  ox,oz,turn=0,0,0
  -- Cover source-material slivers between wall faces and floor borders.
  for _,p in ipairs(r.walls)do box(p.x,.01,p.z,8,.04,8,13)end
  if r.entry then
   -- Benches occupy the original blocked counter strips, clear of NPC paths.
   for _,x in ipairs({17,97})do
    box(x,0,41,12,6,46,1);box(x,6,41,12,1.8,46,3)
    for z=42,84,7 do box(x+.3,7.8,z,11.4,.3,6.5,4)end
    local back=x==17 and x or x+10
    box(back,7,41,2,11,46,2);box(back,17.5,41,2,.8,46,3)
   end
   for _,x in ipairs({8,120})do for _,z in ipairs({8,120})do
    cylinder(0,2,5.8,5.8,1,x,z);cylinder(2,8,5.5,4.5,2,x,z)
    cylinder(9.5,1,4.7,4.7,3,x,z)
    for n=0,6 do
     local a=n*math.pi*2/7;local dx,dz=math.cos(a),math.sin(a)
     quad({x,10,z},{x+dx*5-dz,18,z+dz*5+dx},{x+dx*6,24+n%3,z+dz*6},{x+dx*5+dz,18,z+dz*5-dx},10)
     quad({x,10,z},{x+dx*5+dz,18,z+dz*5-dx},{x+dx*6,24+n%3,z+dz*6},{x+dx*5-dz,18,z+dz*5+dx},10)
    end
   end end
   -- Over-door lintel and gold-lined entrance, no geometry in the exit cells.
   box(48,36,128,32,12,3,1);box(48,35.5,128,32,.6,3,4)
  end
  for _,p in ipairs(r.floor)do
   quad({p.x,.035,p.z+8},{p.x+8,.035,p.z+8},{p.x+8,.035,p.z},{p.x,.035,p.z},1)
   quad({p.x+.12,.055,p.z+7.88},{p.x+7.88,.055,p.z+7.88},{p.x+7.88,.055,p.z+.12},{p.x+.12,.055,p.z+.12},13+((p.x/8+p.z/8)%2))
  end
 elseif part=='ceiling' then
  for _,p in ipairs(r.floor)do
   quad({p.x,48,p.z},{p.x+8,48,p.z},{p.x+8,48,p.z+8},{p.x,48,p.z+8},1)
   if (r.maxZ-r.minZ)>(r.maxX-r.minX) then
    if p.z%32==0 then box(p.x,46.8,p.z,8,1.2,1.5,2)end
   else
    if p.x%32==0 then box(p.x,46.8,p.z,1.5,1.2,8,2)end
   end
  end
 else
  -- Close the perpendicular wall junctions; ownership follows wall cutaway.
  if part=='north' or part=='south' then
   local z=part=='north' and r.minZ or r.maxZ
   for _,x in ipairs({r.minX,r.maxX})do box(x-1,0,z-1,2,48,2,2)end
  end
  for _,p in ipairs(r.walls)do if p.side==part then
   ox,oz,turn=p.x+4,p.z+4,0
   if part=='south'then turn=2 elseif part=='west'then turn=1 elseif part=='east'then turn=-1 end
   box(-4,0,-3,8,48,6,2)
   box(-4,.2,3,8,2,.5,1);box(-4,14,3,8,.5,.5,1)
   front(-3.8,3,3.2,7.6,10,5)
   for y=17,41,8 do front(-3.8,y,3.2,7.6,7.7,5)end
   box(-4,45,3,8,1,.7,1)
   local along=(part=='north' or part=='south')and p.x or p.z
   if along%48==0 then
    box(-1.8,28,3.3,3.6,7,1,1)
    box(-1.3,29,4.4,2.6,5,.6,11)
    box(-2,28,4,4,.6,1.2,3);box(-2,34.6,4,4,.6,1.2,3)
   end
  end end
 end
 return vs,ix
end
local function prepare(map)
 if not M.accepts(map)then return end
 if cached and cached.id~=map.id then M.invalidate() end
 if cached then return cached end
 local layout=M.layout(map);if not layout then return end
 local R=V.require('Voxel3D')
 local vertices,indices=M.geometry(layout)
 local mesh=R.newMesh(vertices,indices);if not mesh then return end
 local d=love.image.newImageData(16,1)
 for i,c in ipairs(palette)do d:setPixel(i-1,0,c[1],c[2],c[3],1)end
 local texture=love.graphics.newImage(d);texture:setFilter('nearest','nearest');d:release()
 local md=love.image.newImageData(16,1)
 for i=1,16 do md:setPixel(i-1,0,1,1,1,(i==11 and .5 or (i==7 and .16 or 0)))end
 local mask=love.graphics.newImage(md);mask:setFilter('nearest','nearest');md:release()
 local shell={}
 for _,part in ipairs({'north','south','east','west','ceiling'})do
  local vv,ii=M.geometry(layout,part);shell[part]=R.newMesh(vv,ii)
 end
 cached={id=map.id,mesh=mesh,texture=texture,mask=mask,layout=layout,shell=shell};return cached
end
function M.build(S,map)
 local r=prepare(map);if not r then return end
 for k,cell in pairs(r.layout.claim)do
  S.skip[k]=true;S.ground[k]=false
  -- Suppress the later Structures.buildStairs pass too. Player support
  -- reads the original TileShape separately, so warp behavior is unchanged.
  S.shapeAt[k]={class='ground',h=0,flat=true,art='flat',authored=true}
 end
end
function M.draw(map,shadow)
 local r=prepare(map);if not r then return end
 if shadow then shadow.draw(r.mesh,r.texture)else
  local R=V.require('Voxel3D');local old=R.glassMask
  R.glassMaskNow(r.mask);R.glass(true)
  local ok,err=pcall(function()
   R.draw(r.mesh,r.texture)
   local visible=M.visibleShell(R.eye)
   for _,part in ipairs({'north','south','east','west','ceiling'})do
    if visible[part] and r.shell[part]then R.draw(r.shell[part],r.texture)end
   end
  end)
  R.glass(false);R.glassMaskNow(old)
  if not ok then error(err)end
 end
end
-- Keep the far walls and remove boundaries that obscure an exterior camera.
function M.visibleShell(eye)
 local b=cached and cached.layout
 if not b then return {} end
 eye=eye or {(b.minX+b.maxX)/2,24,(b.minZ+b.maxZ)/2}
 return {north=eye[3]>b.minZ,south=eye[3]<b.maxZ,west=eye[1]>b.minX,east=eye[1]<b.maxX,ceiling=eye[2]<46}
end
function M.invalidate()
 if cached then for _,mesh in pairs(cached.shell or {})do mesh:release()end;cached.mesh:release();cached.texture:release();cached.mask:release();cached=nil end
end
function M.setLive(live)if cached and not live[cached.id] then M.invalidate()end end
return M
