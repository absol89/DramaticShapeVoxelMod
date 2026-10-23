-- Rocket basement enclosure; live source maze and puzzle geometry retained.
local V=...
local M={}
local cached
local palette={{.10,.12,.14},{.23,.26,.28},{.48,.34,.16},{.77,.60,.30},
 {.29,.32,.33},{.34,.37,.38},{.87,.79,.59},{.055,.065,.08},
 {.72,.12,.10},{.18,.45,.32},{.98,.12,.065},{.42,.44,.48},
 {.27,.29,.32},{.28,.30,.33},{.35,.37,.38},{.28,.13,.10}}
local function key(x,y)return (y+64)*4096+x+64 end
function M.accepts(map)
 -- TEST175: the lair InteriorRooms builds (DUNGEON INTERIORS) comes first
 do local ok,own=pcall(function()return V.require('InteriorRooms').accepts(map)end);if ok and own then return false end end
 local choice=map and map.id=="ROCKET_HIDEOUT_ELEVATOR" and "elevator" or "rocket"
 if V.require("CommunityVisuals")[choice]:get()~="n64memory" then return false end
 return map and map.tileset and ((map.tileset.id=='FACILITY'
  and tostring(map.id):match('^ROCKET_HIDEOUT_B[1-4]F$')~=nil)
  or(map.id=='ROCKET_HIDEOUT_ELEVATOR' and map.tileset.id=='LOBBY'))
end
function M.layout(map)
 if not M.accepts(map)then return end
 if map.id=='ROCKET_HIDEOUT_ELEVATOR'then
  if map.def.width~=3 or map.def.height~=4 then return end
  local r={elevator=true,floor={},walls={},stairs={},plants={},paving={},arrows={},counters={},counterAt={},thresholds={},claim={},minX=16,minZ=16,maxX=80,maxZ=112}
  for y=0,15 do for x=0,11 do r.claim[key(x,y)]={x,y}end end
  for z=16,104,8 do for x=16,72,8 do r.floor[#r.floor+1]={x=x,z=z}end end
  for z=16,96,16 do for x=16,64,16 do r.paving[#r.paving+1]={x=x,z=z,size=16}end end
  for x=16,72,8 do
   r.walls[#r.walls+1]={x=x,z=8,side='north'}
   r.walls[#r.walls+1]={x=x,z=112,side='south'}
  end
  for z=16,104,8 do
   r.walls[#r.walls+1]={x=8,z=z,side='west'}
   r.walls[#r.walls+1]={x=80,z=z,side='east'}
  end
  return r
 end
 local r={floor={},walls={},stairs={},plants={},paving={},arrows={},counters={},counterAt={},thresholds={},claim={},minX=1e9,minZ=1e9,maxX=-1e9,maxZ=-1e9}
 local taken={}
 local function tile(x,y)
  if x<0 or y<0 or x>=map.def.width*4 or y>=map.def.height*4 then return nil end
  return map:tileAt(x,y)
 end
 local plant={5,6,21,22,7,15,23,31}
 for y=0,map.def.height*4-4 do for x=0,map.def.width*4-2 do
  if tile(x,y)==5 then
   local hit=true
   for i,t in ipairs(plant)do if tile(x+(i-1)%2,y+math.floor((i-1)/2))~=t then hit=false;break end end
   if hit then
    r.plants[#r.plants+1]={x=x*8+8,z=y*8+24}
    for dy=0,3 do for dx=0,1 do r.claim[key(x+dx,y+dy)]={x+dx,y+dy};taken[key(x+dx,y+dy)]=true end end
   end
  end
 end end
 -- Complete 4x2 Facility lift sill, with edge/end tiles on both rows.
 for y=0,map.def.height*4-2 do for x=0,map.def.width*4-4 do
  local hit=true
  for dy=0,1 do for dx=0,3 do
   if tile(x+dx,y+dy)~=((dx==0 or dx==3)and 66 or 82)then hit=false end
  end end
  if hit then
   for dx=0,3 do r.thresholds[#r.thresholds+1]={x=(x+dx)*8,z=y*8}
    for dy=0,1 do local k=key(x+dx,y+dy);r.claim[k]={x+dx,y+dy};taken[k]=true end
   end
  end
 end end
 -- Source 16px cells encode one direction with four 8px quadrants.
 -- Match entire patterns; leave source movement/collision data untouched.
 local directions={['33,33,32,32']='left',['49,49,48,48']='right',
  ['33,49,33,49']='up',['32,48,32,48']='down',['94,94,94,94']='stop'}
 for y=0,map.def.height*4-2,2 do for x=0,map.def.width*4-2,2 do
  local pattern=table.concat({tile(x,y),tile(x+1,y),tile(x,y+1),tile(x+1,y+1)},',')
  local direction=directions[pattern]
  if direction then
   r.arrows[#r.arrows+1]={x=x*8,z=y*8,direction=direction}
   for dy=0,1 do for dx=0,1 do
    local k=key(x+dx,y+dy);r.claim[k]={x+dx,y+dy};taken[k]=true
   end end
  end
 end end
 -- Only the solid maze partition family is replaced. Door/gate tiles,
 -- machinery, stairs and puzzle arrows retain their own renderers.
 local wallTiles={[42]=true,[43]=true,[44]=true,[45]=true,[46]=true,[58]=true,[59]=true,[60]=true}
 local function counter(x,y)
  local k=key(x,y)
  if r.counterAt[k]then return end
  r.counterAt[k]=true;r.counters[#r.counters+1]={x=x,z=y}
  r.claim[k]={x,y};taken[k]=true
 end
 for y=0,map.def.height*4-1 do for x=0,map.def.width*4-1 do
  if wallTiles[tile(x,y)]then counter(x,y)end
  -- The four-tile terminal drawing is the B2F/B3F maze block.
  -- Match the complete drawing so shared cabinet bases stay intact.
  if tile(x,y)==9 and tile(x+1,y)==10 and tile(x,y+1)==25 and tile(x+1,y+1)==26 then
   counter(x,y);counter(x+1,y);counter(x,y+1);counter(x+1,y+1)
  end
 end end
 for y=0,map.def.height*4-1 do for x=0,map.def.width*4-1 do
  if tile(x,y)==1 and not taken[key(x,y)] then
   local size=1
   if x%2==0 and y%2==0 and tile(x+1,y)==1 and tile(x,y+1)==1 and tile(x+1,y+1)==1 then size=2 end
   r.paving[#r.paving+1]={x=x*8,z=y*8,size=size*8}
   for dy=0,size-1 do for dx=0,size-1 do
    local k=key(x+dx,y+dy);taken[k]=true;r.claim[k]={x+dx,y+dy}
   end end
  end
 end end
 -- Only ordinary floor determines the room envelope. Arrows, brakes,
 -- elevators, doors and stair cells remain entirely source-owned.
 for y=0,map.def.height*4-1 do for x=0,map.def.width*4-1 do
  if map:tileAt(x,y)==1 then
   r.minX=math.min(r.minX,x*8);r.maxX=math.max(r.maxX,x*8+8)
   r.minZ=math.min(r.minZ,y*8);r.maxZ=math.max(r.maxZ,y*8+8)
  end
 end end
 if r.minX>r.maxX then return end
 -- Enclose outside the playable floor; never put a shell across a maze lane.
 r.minX=r.minX-8;r.minZ=r.minZ-8;r.maxX=r.maxX+8;r.maxZ=r.maxZ+8
 for z=r.minZ,r.maxZ-8,8 do for x=r.minX,r.maxX-8,8 do
  r.floor[#r.floor+1]={x=x,z=z}
 end end
 for x=r.minX,r.maxX-8,8 do
  r.walls[#r.walls+1]={x=x,z=r.minZ-8,side='north'}
  r.walls[#r.walls+1]={x=x,z=r.maxZ,side='south'}
 end
 for z=r.minZ,r.maxZ-8,8 do
  r.walls[#r.walls+1]={x=r.minX-8,z=z,side='west'}
  r.walls[#r.walls+1]={x=r.maxX,z=z,side='east'}
 end
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
  for _,p in ipairs(r.paving)do
   local x,z,d=p.x,p.z,p.size
   quad({x,.025,z+d},{x+d,.025,z+d},{x+d,.025,z},{x,.025,z},2)
   local c=((math.floor(x/16)*7+math.floor(z/16)*3)%5==0)and 14 or 13
   quad({x+.07,.045,z+d-.07},{x+d-.07,.045,z+d-.07},{x+d-.07,.045,z+.07},{x+.07,.045,z+.07},c)
  end
  for _,p in ipairs(r.thresholds)do
   local x,z=p.x,p.z
   quad({x,.05,z+16},{x+8,.05,z+16},{x+8,.05,z},{x,.05,z},2)
   for _,dz in ipairs({1,3,13,15})do
    quad({x,.075,z+dz+.2},{x+8,.075,z+dz+.2},{x+8,.075,z+dz-.2},{x,.075,z+dz-.2},12)
   end
   quad({x,.08,z+8.2},{x+8,.08,z+8.2},{x+8,.08,z+7.8},{x,.08,z+7.8},9)
  end
  for _,p in ipairs(r.arrows)do
   local x,z=p.x,p.z
   -- Flush inset steel plate; feet and puzzle movement stay at source height.
   quad({x,.026,z+16},{x+16,.026,z+16},{x+16,.026,z},{x,.026,z},8)
   quad({x+.25,.045,z+15.75},{x+15.75,.045,z+15.75},{x+15.75,.045,z+.25},{x+.25,.045,z+.25},5)
   quad({x+.55,.06,z+15.45},{x+15.45,.06,z+15.45},{x+15.45,.06,z+.55},{x+.55,.06,z+.55},1)
   for _,dx in ipairs({1.5,14.5})do for _,dz in ipairs({1.5,14.5})do
    quad({x+dx-.2,.08,z+dz+.2},{x+dx+.2,.08,z+dz+.2},
     {x+dx+.2,.08,z+dz-.2},{x+dx-.2,.08,z+dz-.2},12)
   end end
   ox,oz=x+8,z+8
   turn=p.direction=='right'and -1 or(p.direction=='left'and 1 or(p.direction=='down'and 2 or 0))
   if p.direction=='stop'then
    -- Amber octagonal brake pad, visually distinct from red direction marks.
    for i=0,7 do
     local a,b=i*math.pi/4,(i+1)*math.pi/4
     quad({math.cos(a)*4.4,.085,math.sin(a)*4.4},{math.cos(a)*3.5,.085,math.sin(a)*3.5},
      {math.cos(b)*3.5,.085,math.sin(b)*3.5},{math.cos(b)*4.4,.085,math.sin(b)*4.4},4)
    end
    quad({-2,.09,1},{2,.09,1},{2,.09,-1},{-2,.09,-1},4)
   else
    for _,offset in ipairs({-2,2})do
     quad({-4,.085,3+offset},{0,.085,-1+offset},{0,.085,-3+offset},{-4,.085,1+offset},9)
     quad({0,.085,-1+offset},{4,.085,3+offset},{4,.085,1+offset},{0,.085,-3+offset},9)
    end
   end
   ox,oz,turn=0,0,0
  end
  -- A joined worktop follows the exact source footprint. Only exposed
  -- edges receive bevels and panel detail: no checker seams at tile joins.
  for _,p in ipairs(r.counters)do
   local x,z=p.x*8,p.z*8
   local north=not r.counterAt[key(p.x,p.z-1)]
   local south=not r.counterAt[key(p.x,p.z+1)]
   local west=not r.counterAt[key(p.x-1,p.z)]
   local east=not r.counterAt[key(p.x+1,p.z)]
   local l,h=west and .45 or 0,east and .45 or 0
   local n,b=north and .45 or 0,south and .45 or 0
   quad({x+l,16,z+8-b},{x+8-h,16,z+8-b},{x+8-h,16,z+n},{x+l,16,z+n},1)
   if north then quad({x,15.35,z},{x+l,16,z+n},{x+8-h,16,z+n},{x+8,15.35,z},5)end
   if south then quad({x+8,15.35,z+8},{x+8-h,16,z+8-b},{x+l,16,z+8-b},{x,15.35,z+8},5)end
   if west then quad({x,15.35,z+8},{x+l,16,z+8-b},{x+l,16,z+n},{x,15.35,z},5)end
   if east then quad({x+8,15.35,z},{x+8-h,16,z+n},{x+8-h,16,z+8-b},{x+8,15.35,z+8},5)end
   for _,side in ipairs({'north','south','west','east'})do
    if (side=='north'and north)or(side=='south'and south)or(side=='west'and west)or(side=='east'and east)then
     ox,oz,turn=x+4,z+4,0
     if side=='north'then turn=2 elseif side=='west'then turn=-1 elseif side=='east'then turn=1 end
     local along=(side=='north'or side=='south')and x or z
     -- Shadowed plinth, framed inset, and narrow satin-metal top lip.
     front(-4,0,3.7,8,1.8,8)
     front(-4,1.8,3.95,8,11.9,1)
     local left=along%16==0 and .35 or 0
     local right=along%16==8 and .35 or 0
     front(-4+left,3,3.98,8-left-right,9.25,2)
     front(-4,13.7,3.97,8,1.65,8)
     front(-4,15.03,4,8,.32,5)
     -- Red accent is solid pigment, not another bright light source.
     front(-4,13.85,3.995,8,.22,9)
     if along%32==0 then
      front(-2.8,9.2,3.999,2.4,.45,6)
      for v=0,2 do front(-2.8,4+v*.8,3.999,2.4,.22,8)end
     end
     ox,oz,turn=0,0,0
    end
   end
  end
  for _,p in ipairs(r.plants)do
   local x,z=p.x,p.z
   cylinder(0,1,4.2,4.2,1,x,z)
   cylinder(1,6,4,4.6,2,x,z)
   cylinder(7,.7,4.7,4.7,12,x,z)
   cylinder(7.7,.2,4.1,4.1,16,x,z)
   cylinder(7.8,11,.5,.3,10,x,z)
   for tier=0,2 do for n=0,4 do
    local a=n*math.pi*2/5+tier*.65
    local dx,dz=math.cos(a),math.sin(a);local y=12+tier*3
    local reach=6-tier*.9;local tipY=y+4
    local center={x+dx*reach*.55,y+3,z+dz*reach*.55}
    local root={x,y,z};local tip={x+dx*reach,tipY,z+dz*reach}
    local left={center[1]-dz*1.5,center[2]-1,center[3]+dx*1.5}
    local right={center[1]+dz*1.5,center[2]-1,center[3]-dx*1.5}
    quad(root,left,tip,center,10,.9);quad(root,center,tip,right,10,1.08)
    quad(center,tip,left,root,10,.75);quad(right,tip,center,root,10,.8)
   end end
  end
 elseif part=='ceiling' then
  for _,p in ipairs(r.floor)do
   quad({p.x,56,p.z},{p.x+8,56,p.z},{p.x+8,56,p.z+8},{p.x,56,p.z+8},1)
   if (r.maxZ-r.minZ)>(r.maxX-r.minX) then
    if p.z%32==0 then box(p.x,53.5,p.z,8,2.5,3,8)end
   else
    if p.x%32==0 then box(p.x,53.5,p.z,3,2.5,8,8)end
   end
  end
 else
  -- Close the perpendicular wall junctions; ownership follows wall cutaway.
  if part=='north' or part=='south' then
   local z=part=='north' and r.minZ or r.maxZ
   for _,x in ipairs({r.minX,r.maxX})do box(x-1,0,z-1,2,56,2,2)end
  end
  for _,p in ipairs(r.walls)do if p.side==part then
   ox,oz,turn=p.x+4,p.z+4,0
   if part=='south'then turn=2 elseif part=='west'then turn=1 elseif part=='east'then turn=-1 end
   local along=(part=='north' or part=='south')and p.x or p.z
   local edge=along%32
   -- Broad steel plates span four source tiles, bounded by structural ribs.
   box(-4,0,-3,8,56,6,1)
   front(-4,3,3.15,8,22,2);front(-4,26,3.15,8,25,2)
   box(-4,.1,3.2,8,2,.65,8)
   box(-4,25,3.2,8,.8,.45,8)
   if edge==0 and not(r.elevator and part=='north' and p.x>=32 and p.x<64)then
    box(-4,2,3.3,1.3,51,.9,12)
    for _,y in ipairs({5,22,29,48})do box(-3.7,y,4.22,.65,.65,.15,6)end
   end
   -- Two continuous hexagonal service pipes, raised above eye level.
   for _,y in ipairs({44,49})do
    for n=0,5 do
     local a,b=n*math.pi/3,(n+1)*math.pi/3
     local ya,za=y+math.cos(a)*.85,4.7+math.sin(a)*.85
     local yb,zb=y+math.cos(b)*.85,4.7+math.sin(b)*.85
     quad({-4,ya,za},{4,ya,za},{4,yb,zb},{-4,yb,zb},12,.8+.15*math.cos(a))
    end
    if edge==0 then box(-3.5,y-1.1,3.7,1,2.2,2,8)end
   end
   if r.elevator then
    if part=='west' or part=='east' or part=='south'then
     box(-4,19,3.6,8,.9,1.4,12)
     if edge==0 then box(-3.6,17.8,3.4,.8,2,1.6,8)end
    end
    if part=='north' then
     -- Door face is behind the source warp cells; no blocker across entry.
     if p.x>=32 and p.x<64 then
      box(-4,0,3.3,8,36,.45,8)
      front(-3.75,.7,3.8,7.5,34.5,6)
      if p.x==40 or p.x==48 then box(p.x==40 and 3.5 or -4,0,3.85,.5,36,.15,8)end
      box(-4,36,3.7,8,1.2,.5,12)
      box(-4,38,3.6,8,4,.35,8)
      front(-3,39.2,4,6,.65,9)
     elseif p.x==24 then
      box(-4,14,3.4,7,17,.6,8)
      front(-3.4,14.6,4.05,5.8,15.8,12)
      front(-2.8,26,4.1,4.6,3.5,8)
      for j=0,2 do
       box(-2.5,17+j*2.6,4.15,1.2,1.2,.25,j==0 and 11 or 6)
       front(-.5,17.3+j*2.6,4.17,2,.45,8)
      end
     end
    end
   end
   if along%64==0 and not(r.elevator and part=='north')then
    -- Caged red emergency lamp, distinct from the tunnel's amber sconces.
    box(-1.7,32,3.4,3.4,7,1,8)
    box(-1.15,33,4.45,2.3,5,.6,11)
    for _,y in ipairs({33,35.4,37.8})do box(-1.6,y,5.08,3.2,.25,.2,12)end
   end
   if along%96==48 and not(r.elevator and part=='north')then
    box(-7.5,22,3.4,15,18,.5,8)
    -- Solid geometric R insignia; correct winding keeps it readable indoors.
    local glyph={'11110','10001','10001','11110','10100','10010','10001'}
    for row,line in ipairs(glyph)do for col=1,5 do
     if line:sub(col,col)=='1' then front(-4.5+(col-1)*1.8,36-(row-1)*1.8,4.02,1.8,1.8,9)end
    end end
    box(-6,23,4.02,12,.45,.15,9)
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
 local mesh=#vertices>0 and R.newMesh(vertices,indices) or nil
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
  S.skip[k]=true;S.ground[k]=1
  S.tileAt[k]=1
  -- Retire source plant art before the authored-object passes run.
  S.shapeAt[k]={class='ground',h=0,flat=true,art='flat',authored=true}
 end
end
function M.draw(map,shadow)
 local r=prepare(map);if not r then return end
 if shadow then
  -- Plants cast grounded shadows; keep the enclosing roof out of this pass.
  if r.mesh then shadow.draw(r.mesh,r.texture)end
  return
 else
  local R=V.require('Voxel3D');local old=R.glassMask
  R.glassMaskNow(r.mask);R.glass(true)
  local ok,err=pcall(function()
   if r.mesh then R.draw(r.mesh,r.texture)end
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
 return {north=eye[3]>b.minZ,south=eye[3]<b.maxZ,west=eye[1]>b.minX,east=eye[1]<b.maxX,ceiling=eye[2]<54}
end
function M.invalidate()
 if cached then for _,mesh in pairs(cached.shell or {})do mesh:release()end;if cached.mesh then cached.mesh:release()end;cached.texture:release();cached.mask:release();cached=nil end
end
function M.setLive(live)if cached and not live[cached.id] then M.invalidate()end end
return M
