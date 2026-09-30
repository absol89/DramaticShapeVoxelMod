-- Uses the caller's engine tile key, never an invented coordinate string.
local M={}
function M.plan(map,S,keyOf,isPath,isWood)
 local P={cells={},plaza=nil};local w,h=map.def.width*4,map.def.height*4
 local dirs={{'w',-1,0},{'e',1,0},{'n',0,-1},{'s',0,1}}
 local function blockedDoor(x,z)
  for _,v in ipairs(map.def.warps or {})do
   if math.abs(x-(v.x*2+.5))<2.5 and math.abs(z-(v.y*2+.5))<3.5 then return true end
  end
  return false
 end
 local squares={};local best=0
 for z=0,h-1 do for x=0,w-1 do
  local k=keyOf(x,z)
  if isPath(x,z) and not S.skip[k] and not (S.runs and S.runs[k]) then
   local c={x=x,z=z,edges={},water={},garden={},door=blockedDoor(x,z)};P.cells[k]=c
   local nearBoundary=false;local nearDock=false
   for _,d in ipairs(dirs)do
    local nk=keyOf(x+d[2],z+d[3]);local s=S.shapeAt[nk]
    if not isPath(x+d[2],z+d[3]) or S.skip[nk] then
     nearBoundary=true;c.edges[d[1]]=true
     c.water[d[1]]=s and s.class=='water' or false
     c.garden[d[1]]=s and (s.class=='building' or s.class=='fence' or s.class=='tree') or false
    end
   end
   for dz=-1,1 do for dx=-1,1 do if isWood(x+dx,z+dz)then nearDock=true end end end
   local waterfront=false
   for _,d in ipairs(dirs)do for n=1,2 do
    local near=S.shapeAt[keyOf(x+d[2]*n,z+d[3]*n)]
    if near and near.class=='water' then waterfront=true end
   end end
   local open=true
   for dz=-1,1 do for dx=-1,1 do if not isPath(x+dx,z+dz) or S.skip[keyOf(x+dx,z+dz)] then open=false end end end
   c.open=open
   c.dock=nearDock;c.stone=nearBoundary or waterfront or c.door or nearDock
   -- Place the centerpiece only on contiguous visible path, clear of entrances.
   if not c.door and not nearDock then
    local n=1+math.min(squares[keyOf(x-1,z)] or 0,squares[keyOf(x,z-1)] or 0,squares[keyOf(x-1,z-1)] or 0)
    squares[k]=n
    if n>best then best=n;P.plaza={minX=x-n+1,minZ=z-n+1,maxX=x,maxZ=z,size=n}end
   end
  end
 end end
 if P.plaza and best>=4 then
  local a=P.plaza;a.cx=(a.minX+a.maxX+1)*4;a.cz=(a.minZ+a.maxZ+1)*4
  a.radius=math.min(19,best*4-2)
  -- A compact central terrace, not the entire largest square.
  for _,c in pairs(P.cells)do
   local dx,dz=c.x*8+4-a.cx,c.z*8+4-a.cz
   if math.abs(dx)<a.radius+5 and math.abs(dz)<a.radius+5 then c.stone=true end
  end
 else P.plaza=nil end
 -- Set material joins only after the complete plan exists.
 for k,c in pairs(P.cells)do
  c.join={}
  for _,d in ipairs(dirs)do
   local other=P.cells[keyOf(c.x+d[2],c.z+d[3])]
   if c.stone and other and not other.stone then c.join[d[1]]=true end
  end
  if not c.door and not c.dock then
   for _,d in ipairs(dirs)do
    local along=(d[2]==0 and c.x or c.z)
    if c.garden[d[1]] and along%3==1 then c.bed=d[1];break end
   end
  end
 end
 -- Deterministic waterfront fixtures, using the same visible path cells.
 P.lamps={}
 for z=0,h-1 do for x=0,w-1 do
  local c=P.cells[keyOf(x,z)]
  if c and not c.door and not c.dock then
   local count=0;for _,d in ipairs(dirs)do if c.water[d[1]] then count=count+1 end end
   for _,d in ipairs(dirs)do if c.water[d[1]] then
    local along=d[2]==0 and x or z
    local px,pz=x*8+4+d[2]*2,z*8+4+d[3]*2
    if along%4==0 or count>=2 then
     local clear=true
     for _,l in ipairs(P.lamps)do if (l[1]-px)^2+(l[2]-pz)^2<18^2 then clear=false;break end end
     if clear then c.lamp={x=px,z=pz};c.bed=nil;P.lamps[#P.lamps+1]={px,pz};break end
    elseif not c.bed and along%4==2 then c.bed=d[1];c.coastalBed=true
    end
   end end
  end
 end end
 -- Long benches reserve three adjacent shoreline cells so clipping cannot shorten them.
 P.benches={}
 for z=0,h-1 do for x=0,w-1 do
  local c=P.cells[keyOf(x,z)]
  if c and not c.door and not c.dock and not c.lamp then
   for _,d in ipairs(dirs)do
    local along=d[2]==0 and x or z
    if c.water[d[1]] and along%8==6 then
     local ax,az=d[2]==0 and 1 or 0,d[2]==0 and 0 or 1
     local cells={};local clear=true
     for n=-1,1 do
      local q=P.cells[keyOf(x+ax*n,z+az*n)]
      if not q or q.door or q.dock or q.lamp or q.bench or not q.water[d[1]] then clear=false end
      cells[#cells+1]=q
     end
     if clear then
      local f={edge=d[1],cx=x*8+4+d[2]*2.3,cz=z*8+4+d[3]*2.3}
      P.benches[#P.benches+1]=f
      for _,q in ipairs(cells)do q.bed=nil;q.bench=f end
      break
     end
    end
   end
  end
 end end
 -- Tall planted vessels alternate with low beds, never with furniture or entrances.
 P.vases={}
 for z=0,h-1 do for x=0,w-1 do
  local c=P.cells[keyOf(x,z)]
  if c and not c.door and not c.dock and not c.lamp and not c.bench then
   for _,d in ipairs(dirs)do
    local along=d[2]==0 and x or z
    if (c.garden[d[1]] and along%12==1) or (c.water[d[1]] and along%12==3) then
     local clear=true
     -- Require a two-tile clear paved approach inward from the boundary.
     for n=1,2 do
      local q=P.cells[keyOf(x-d[2]*n,z-d[3]*n)]
      if not q or q.door or q.dock or q.bench or q.lamp then clear=false end
     end
     local cx,cz=x*8+4,z*8+4
     if P.plaza and (cx-P.plaza.cx)^2+(cz-P.plaza.cz)^2<(P.plaza.radius+8)^2 then clear=false end
     for _,v in ipairs(P.vases)do if (cx-v.x)^2+(cz-v.z)^2<64^2 then clear=false end end
     for _,l in ipairs(P.lamps)do if (cx-l[1])^2+(cz-l[2])^2<10^2 then clear=false end end
     if clear and #P.vases<6 then
      c.vase={x=cx,z=cz,seed=x*31+z};c.bed=nil
      P.vases[#P.vases+1]=c.vase;break
     end
    end
   end
  end
 end end
 -- Larger continuous flower beds replace isolated trays where three edge cells fit.
 P.flowerbeds={}
 for z=0,h-1 do for x=0,w-1 do
  local c=P.cells[keyOf(x,z)]
  if c and c.bed and not c.flowerbed then
   local e=c.bed
   for _,d in ipairs(dirs)do if d[1]==e then
    local ax,az=d[2]==0 and 1 or 0,d[2]==0 and 0 or 1
    local cells={};local clear=true
    for n=-1,1 do
     local q=P.cells[keyOf(x+ax*n,z+az*n)]
     local inward=P.cells[keyOf(x+ax*n-d[2],z+az*n-d[3])]
     if not q or q.door or q.dock or q.lamp or q.bench or q.vase or q.flowerbed or not (q.garden[e] or q.water[e]) then clear=false end
     if not inward or inward.door or inward.dock or inward.bench or inward.vase or inward.flowerbed then clear=false end
     if q then cells[#cells+1]=q end
    end
    if clear and #P.flowerbeds<18 then
     local f={edge=e,cx=x*8+4,cz=z*8+4,seed=x*41+z}
     P.flowerbeds[#P.flowerbeds+1]=f
     for _,q in ipairs(cells)do q.bed=nil;q.flowerbed=f end
    end
   end end
  end
 end end
 -- Locate the fenced court from authored fence tiles, independently of the compass plaza.
 local function fence(x,z)
  local k=keyOf(x,z);local t=S.tileAt and S.tileAt[k];local a=S.shapeAt[k]
  return t==0x0E or t==0x55 or (a and a.class=='fence')
 end
 local bestCourt,bestScore=nil,0
 for z=0,h-1 do for x=0,w-1 do
  local c=P.cells[keyOf(x,z)]
  if c and c.open and not c.door and not c.dock then
   local hits={};local fences=0
   for _,d in ipairs(dirs)do
    for n=1,20 do
     local xx,zz=x+d[2]*n,z+d[3]*n
     if fence(xx,zz) then hits[d[1]]=n;fences=fences+1;break end
     local a=S.shapeAt[keyOf(xx,zz)]
     if a and a.class=='building' then hits[d[1]]=n;break end
     if not a or a.class=='water' then break end
    end
   end
   if fences>=3 and hits.w and hits.e and hits.n and hits.s then
    local cw,ch=hits.w+hits.e-1,hits.n+hits.s-1
    local score=fences*100-math.abs(cw-ch)-math.abs(hits.w-hits.e)-math.abs(hits.n-hits.s)
    if cw>=7 and ch>=7 and score>bestScore then
     bestScore=score;bestCourt={x0=x-hits.w+1,x1=x+hits.e-1,z0=z-hits.n+1,z1=z+hits.s-1}
    end
   end
  end
 end end
 P.court=bestCourt
 if P.court then
  local a=P.court;a.cx=(a.x0+a.x1+1)*4;a.cz=(a.z0+a.z1+1)*4
  -- Bring alternate flat floor tiles into the same visual court plan.
  for z=a.z0,a.z1 do for x=a.x0,a.x1 do
   local k=keyOf(x,z);local shape=S.shapeAt[k]
   if not P.cells[k] and shape and shape.class=='ground' and shape.flat and not S.skip[k] and not (S.runs and S.runs[k]) and not isWood(x,z) then
    P.cells[k]={x=x,z=z,edges={},water={},garden={},join={},stone=true,door=blockedDoor(x,z)}
   end
  end end
  for z=a.z0,a.z1 do for x=a.x0,a.x1 do
   local c=P.cells[keyOf(x,z)]
   if c then c.inCourt=true end
   if c and not c.door and not c.dock and not c.lamp and not c.bench and not c.vase and not c.flowerbed then
    local px,pz=x*8+4,z*8+4
    -- Paved perimeter and broad cross remain available for NPCs and traversal.
    local interior=x>a.x0 and x<a.x1 and z>a.z0 and z<a.z1
    local qx=px<a.cx and (a.x0*8+8+a.cx-10)/2 or (a.cx+10+(a.x1+1)*8-8)/2
    local qz=pz<a.cz and (a.z0*8+8+a.cz-10)/2 or (a.cz+10+(a.z1+1)*8-8)/2
    local rx=math.max(1,(a.cx-a.x0*8-18)/2);local rz=math.max(1,(a.cz-a.z0*8-18)/2)
    local rounded=((px-qx)/rx)^4+((pz-qz)/rz)^4<1.35
    if interior and rounded and math.abs(px-a.cx)>9 and math.abs(pz-a.cz)>9 then
     c.courtGarden=true;c.bed=nil
    else c.courtPaving=true;c.stone=true end
   end
  end end
 end
 local function nearActor(x,z)
  for _,o in ipairs(map.def.objects or {})do
   if not o.runtime and type(o.x)=='number' and type(o.y)=='number' and math.abs(x-(o.x*2+.5))<3 and math.abs(z-(o.y*2+.5))<3 then return true end
  end
  return false
 end
 -- Finish the court with a small seating pair and warm corner lights.
 if P.court then
  local a=P.court;local mid=math.floor((a.x0+a.x1)/2)
  for _,row in ipairs({{a.z0,'n'},{a.z1,'s'}})do
   local cells={};local clear=true
   for n=-1,1 do
    local c=P.cells[keyOf(mid+n,row[1])]
    if not c or c.door or c.dock or c.bench or c.lamp or c.vase or c.flowerbed or nearActor(mid+n,row[1]) then clear=false end
    if c then cells[#cells+1]=c end
   end
   if clear then
    local b={cx=mid*8+4,cz=row[1]*8+4,edge=row[2]}
    P.benches[#P.benches+1]=b
    for _,c in ipairs(cells)do c.bench=b;c.bed=nil;c.courtGarden=nil end
   end
  end
  for _,pos in ipairs({{a.x0,a.z0},{a.x1,a.z0},{a.x0,a.z1},{a.x1,a.z1}})do
   local c=P.cells[keyOf(pos[1],pos[2])]
   if c and not c.door and not c.dock and not c.bench and not c.vase and not c.flowerbed and not c.lamp and not nearActor(c.x,c.z) then
    local px,pz=c.x*8+4,c.z*8+4;local clear=true
    for _,l in ipairs(P.lamps)do if (px-l[1])^2+(pz-l[2])^2<18^2 then clear=false end end
    if clear then c.lamp={x=px,z=pz};c.bed=nil;P.lamps[#P.lamps+1]={px,pz} end
   end
  end
  for _,c in pairs(P.cells)do if c.courtGarden then
   c.gardenEdges={}
   for _,d in ipairs(dirs)do local q=P.cells[keyOf(c.x+d[2],c.z+d[3])];if not q or not q.courtGarden then c.gardenEdges[d[1]]=true end end
  end end
 end
 -- Attach bins to bench ends; a lamp in the same tile is fine if meshes are separated.
 P.bins={}
 local seats={};for _,b in ipairs(P.benches)do seats[#seats+1]=b end
 if P.plaza then table.sort(seats,function(a,b)
  local da=(a.cx-P.plaza.cx)^2+(a.cz-P.plaza.cz)^2
  local db=(b.cx-P.plaza.cx)^2+(b.cz-P.plaza.cz)^2
  if da==db then if a.cz==b.cz then return a.cx<b.cx end;return a.cz<b.cz end
  return da<db
 end)end
 for _,b in ipairs(seats)do
  for _,side in ipairs({-1,1})do
   local px,pz
   if b.edge=='n' then px,pz=b.cx+side*14,b.cz+3.8
   elseif b.edge=='s' then px,pz=b.cx+side*14,b.cz-3.8
   elseif b.edge=='w' then px,pz=b.cx+3.8,b.cz+side*14
   else px,pz=b.cx-3.8,b.cz+side*14 end
   local x,z=math.floor(px/8),math.floor(pz/8);local c=P.cells[keyOf(x,z)]
   local clear=c and not c.door and not c.dock and not c.bench and not c.vase and not c.flowerbed and not c.courtGarden and not c.bin and not nearActor(x,z)
   local u,v=px-x*8,pz-z*8
   if u<1.5 or u>6.5 or v<1.5 or v>6.5 then clear=false end
   for _,l in ipairs(P.lamps)do if (px-l[1])^2+(pz-l[2])^2<3.8^2 then clear=false end end
   for _,q in ipairs(P.bins)do if (px-q.x)^2+(pz-q.z)^2<24^2 then clear=false end end
   if clear and #P.bins<8 then
    c.bin={x=px,z=pz};c.bed=nil;P.bins[#P.bins+1]=c.bin;break
   end
  end
 end
 -- Rebuild joins after court materials change; stale pre-court joins made grey rectangles.
 for _,c in pairs(P.cells)do
  c.join={}
  for _,d in ipairs(dirs)do local q=P.cells[keyOf(c.x+d[2],c.z+d[3])]
   if not c.inCourt and c.stone and q and not q.stone then c.join[d[1]]=true end
  end
 end
 P.dockDetails={}
 for z=0,h-1 do for x=0,w-1 do
  local c=P.cells[keyOf(x,z)]
  if c and c.dock and not c.door and not c.lamp and not c.bench and not c.vase and not c.flowerbed and not nearActor(x,z) then
   for _,d in ipairs(dirs)do if c.water[d[1]] then
    local px,pz=x*8+4+d[2]*1.4,z*8+4+d[3]*1.4;local clear=true
    for _,q in ipairs(P.dockDetails)do if (px-q.x)^2+(pz-q.z)^2<24^2 then clear=false end end
    if clear and #P.dockDetails<12 then
     c.dockDetail={x=px,z=pz,sign=#P.dockDetails%4==0};c.bed=nil;P.dockDetails[#P.dockDetails+1]=c.dockDetail;break
    end
   end end
  end
 end end
 -- One low nautical sculpture beside the court, away from its occupied crossing.
 if P.court then
  local a=P.court
  for z=a.z0+2,a.z1-2 do for _,x in ipairs({a.x0,a.x1})do
   local c=P.cells[keyOf(x,z)]
   if not P.focal and c and not c.courtGarden and not c.door and not c.dock and not c.lamp and not c.bench and not c.vase and not c.flowerbed and not c.bin and not nearActor(x,z) then
    c.focal={x=x*8+4,z=z*8+4};c.bed=nil;P.focal=c.focal
   end
  end end
 end
 return P
end
return M
