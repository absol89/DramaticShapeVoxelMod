-- Legendary civic garden, restricted to existing visible ground. No collision/warp edits.
local V=...
local C=V.require('SurfaceCraft')
local M={}
function M.enabled(id,roads,tileset,legendary)
 return id=='CELADON_CITY' and roads and tileset=='OVERWORLD' and legendary
end
-- Match the renderer's road AND courtyard families, while retaining its
-- courtyard-context check for mixed metatiles. Never include timber or grass.
function M.paved(tile,courtyard)
 return tile==35 or tile==57 or tile==91 or courtyard==true
end
function M.plan(map,S,key,isPath)
 local P={cells={},lamps={},features={},lawns=0};local w,h=map.def.width*4,map.def.height*4
 local function shape(x,z)return S.shapeAt[key(x,z)]end
 -- Identify the photographed civic square from real destination warps.
 -- A decorative pool need not be classified as water, and a larger lake may
 -- belong to a different part of the city. Neither determines this square.
 local shops,casino={},nil
 for _,v in ipairs(map.def.warps or {})do
  if type(v.x)=='number' and type(v.y)=='number' then
   if v.destMap=='CELADON_MART_1F' then shops[#shops+1]={v.x*2+1,v.y*2+1}
   elseif v.destMap=='GAME_CORNER' then casino={v.x*2+1,v.y*2+1} end
  end
 end
 local zone
 if #shops>0 and casino then
  local sx,sz=0,0;for _,v in ipairs(shops)do sx=sx+v[1];sz=sz+v[2]end;sx,sz=sx/#shops,sz/#shops
  if casino[1]>sx+12 and math.abs(casino[2]-sz)<30 then
   zone={x0=math.floor(sx-2),x1=math.floor(casino[1]-5),z0=math.floor(sz+2),z1=math.floor(casino[2]+8)}
   P.anchor='department-store/casino'
  end
 end
 -- Pond fallback supports other map arrangements without inventing landmarks.
 local seen={};local pond
 for z=3,h-4 do for x=3,w-4 do
  local k=key(x,z);local s=shape(x,z)
  if not seen[k] and s and s.class=='water' then
   local q={{x,z}};seen[k]=true;local head=1;local b={x0=x,x1=x,z0=z,z1=z,n=0}
   while head<=#q do local p=q[head];head=head+1;b.n=b.n+1
    b.x0=math.min(b.x0,p[1]);b.x1=math.max(b.x1,p[1]);b.z0=math.min(b.z0,p[2]);b.z1=math.max(b.z1,p[2])
    for _,d in ipairs({{-1,0},{1,0},{0,-1},{0,1}})do
     local a,c=p[1]+d[1],p[2]+d[2];local kk=key(a,c);local ss=shape(a,c)
     if a>=3 and a<w-3 and c>=3 and c<h-3 and not seen[kk] and ss and ss.class=='water' then seen[kk]=true;q[#q+1]={a,c}end
    end
   end
   if b.n>=4 and (not pond or b.n>pond.n)then pond=b end
  end
 end end
 if not zone and not pond then return P end
 P.pond=pond
 zone=zone or {x0=pond.x0-12,x1=pond.x1+12,z0=pond.z0-6,z1=pond.z1+14}
 P.bounds=zone
 local function door(x,z)
  for _,o in ipairs(map.def.warps or {})do
   if math.abs(x-(o.x*2+.5))<4 and math.abs(z-(o.y*2+.5))<5 then return true end
  end
  return false
 end
 local function ground(x,z)
  local k=key(x,z);local s=shape(x,z)
  return x>=2 and x<w-2 and z>=2 and z<h-2 and s and s.class=='ground' and s.flat and not S.skip[k] and not (S.runs and S.runs[k]) and (not isPath or isPath(x,z))
 end
 local mx=(zone.x0+zone.x1+1)/2;local cross=(zone.z0+zone.z1+1)/2
 for z=math.max(2,zone.z0),math.min(h-3,zone.z1)do
  for x=math.max(2,zone.x0),math.min(w-3,zone.x1)do
   if ground(x,z) and not door(x,z) then
    local clear=true
    -- Retain a sixteen-unit walk around buildings, fences, water and signs.
    for dz=-2,2 do for dx=-2,2 do if not ground(x+dx,z+dz) or door(x+dx,z+dz) then clear=false end end end
    local outer=x>zone.x0+1 and x<zone.x1-1 and z>zone.z0+1 and z<zone.z1-1
    local lawn=clear and outer and math.abs(x+.5-mx)>1.25 and math.abs(z+.5-cross)>1.25
    P.cells[key(x,z)]={x=x,z=z,lawn=lawn}
   end
  end
 end
 -- Fit one clean rectangle in each quadrant. Door clearances therefore
 -- shorten a bed instead of carving L-shaped grass strips out of it.
 local chosen={}
 for qz=0,1 do for qx=0,1 do
  local histogram={};local best={area=0}
  for z=zone.z0,zone.z1 do
   for x=zone.x0,zone.x1 do
    local c=P.cells[key(x,z)]
    local quadrant=(qx==0 and x+.5<mx or qx==1 and x+.5>mx)
      and (qz==0 and z+.5<cross or qz==1 and z+.5>cross)
    histogram[x]=(c and c.lawn and quadrant) and (histogram[x] or 0)+1 or 0
    local minH=histogram[x]
    for left=x,zone.x0,-1 do
     minH=math.min(minH,histogram[left] or 0)
     if minH==0 then break end
     local width=x-left+1;local area=width*minH
     if width>=3 and minH>=3 and area>best.area then best={area=area,x0=left,x1=x,z0=z-minH+1,z1=z} end
    end
   end
  end
  if best.area>=12 then
   P.beds=P.beds or {};P.beds[#P.beds+1]=best
   for z=best.z0,best.z1 do for x=best.x0,best.x1 do chosen[key(x,z)]=true end end
  end
 end end
 for k,c in pairs(P.cells)do c.lawn=chosen[k] or false end
 -- Keep the original cobbles beyond a single-cell frame around the lawns.
 local remove={}
 for k,c in pairs(P.cells)do if not c.lawn then
  local near=false
  for dz=-1,1 do for dx=-1,1 do if chosen[key(c.x+dx,c.z+dz)] then near=true end end end
  if not near then remove[#remove+1]=k end
 end end
 for _,k in ipairs(remove)do P.cells[k]=nil end
 local dirs={{'w',-1,0},{'e',1,0},{'n',0,-1},{'s',0,1}}
 local function lawn(x,z)local c=P.cells[key(x,z)];return c and c.lawn end
 local function actor(x,z)
  for _,o in ipairs(map.def.objects or {})do
   if type(o.x)=='number' and type(o.y)=='number' and math.abs(x-(o.x*2+.5))<3 and math.abs(z-(o.y*2+.5))<3 then return true end
  end
  return false
 end
 -- Furnish the existing paving around complete rectangular lawns. Never carve
 -- grass to satisfy a furniture count: that created the TEST67 notches.
 local function boundsClear(a,b,c,d,onLawn,tightFootprint)
  for z=math.floor(b/8),math.floor((d-.001)/8)do
   for x=math.floor(a/8),math.floor((c-.001)/8)do
    if x<zone.x0 or x>zone.x1 or z<zone.z0 or z>zone.z1
      or not ground(x,z) or door(x,z) or (not tightFootprint and actor(x,z))
      or (onLawn and not lawn(x,z)) or (not onLawn and lawn(x,z))then return false end
   end
  end
  if tightFootprint then
   -- Bench-sized clearance, not the old 48-unit-wide exclusion square.
   for _,o in ipairs(map.def.objects or {})do
    if type(o.x)=='number' and type(o.y)=='number' then
     local px,pz=(o.x*2+.5)*8,(o.y*2+.5)*8
     local dx,dz=math.max(a-px,0,px-c),math.max(b-pz,0,pz-d)
     if dx<8 and dz<8 then return false end
    end
   end
  end
  return true
 end
 local function add(f,a,b,c,d)
  f.bounds={a,b,c,d};P.features[#P.features+1]=f
  for z=math.floor(b/8),math.floor((d-.001)/8)do
   for x=math.floor(a/8),math.floor((c-.001)/8)do
    local k=key(x,z);local cell=P.cells[k]
    if not cell then cell={x=x,z=z,lawn=false};P.cells[k]=cell end
    cell.features=cell.features or {};cell.features[#cell.features+1]=f
   end
  end
  if f.kind=='lamp' then P.lamps[#P.lamps+1]={f.cx,f.cz}end
 end
 local function bench(bed,axis,near,t)
  local edge=axis=='x' and (near and 'n' or 's') or (near and 'w' or 'e')
  local boundary=axis=='x' and (near and (bed.z1+1)*8 or bed.z0*8)
    or (near and (bed.x1+1)*8 or bed.x0*8)
  local across=boundary+(near and 1 or -1)
  local cx,cz=axis=='x' and t or across,axis=='x' and across or t
  -- A shallow bench preserves >17 units of clear walk in a 24-unit aisle.
  local back,front=across+(near and -.88 or -2.32),across+(near and 2.32 or .88)
  local a,b,c,d
  if axis=='x' then a,b,c,d=t-9,back,t+9,front else a,b,c,d=back,t-9,front,t+9 end
  if not boundsClear(a,b,c,d,false)then return end
  return {kind='bench',cx=cx,cz=cz,edge=edge,depthScale=.8},a,b,c,d
 end
 local beds=P.beds or {};local pairsToPlace={}
 for i=1,#beds do for j=i+1,#beds do
  local a,b=beds[i],beds[j]
  local axis=(a.x1-a.x0>=a.z1-a.z0 and b.x1-b.x0>=b.z1-b.z0) and 'x' or 'z'
  local along=axis=='x' and 'x' or 'z';local across=axis=='x' and 'z' or 'x'
  local first,second=a,b
  if first[across..'0']>second[across..'0']then first,second=second,first end
  local gap=second[across..'0']-first[across..'1']-1
  local lo=math.max(a[along..'0'],b[along..'0'])*8+10
  local hi=(math.min(a[along..'1'],b[along..'1'])+1)*8-10
  if gap>=3 and gap<=6 and hi>=lo then
   pairsToPlace[#pairsToPlace+1]={i=i,j=j,a=first,b=second,axis=axis,lo=lo,hi=hi,score=hi-lo-gap*8}
  end
 end end
 table.sort(pairsToPlace,function(a,b)
  if a.score~=b.score then return a.score>b.score end
  if a.i~=b.i then return a.i<b.i end;return a.j<b.j
 end)
 -- Preserve the approved TEST68 lamp anchors, including their seating clearance.
 local lampGuides={};local used={}
 for _,pair in ipairs(pairsToPlace)do if not used[pair.i] and not used[pair.j]then
  local middle=(pair.lo+pair.hi)/2
  for step=0,math.ceil((pair.hi-pair.lo)/8)do
   local offset=math.ceil(step/2)*8*(step%2==1 and 1 or -1)
   local t=middle+offset
   if t>=pair.lo and t<=pair.hi then
    local fa,a,b,c,d=bench(pair.a,pair.axis,true,t)
    local fb,e,f,g,h=bench(pair.b,pair.axis,false,t)
    -- Move BOTH seats together when an actor occupies their preferred station.
    if fa and fb then
     lampGuides[#lampGuides+1]=fa;lampGuides[#lampGuides+1]=fb
     used[pair.i],used[pair.j]=true,true;break
    end
   end
  end
 end end
 -- Four perimeter lanterns, spaced around the complete garden. Candidate
 -- feet are outside grass and may slide along an edge to avoid an NPC.
 local candidates={};local ext={x0=w*8,z0=h*8,x1=0,z1=0}
 for _,bed in ipairs(beds)do
  ext.x0=math.min(ext.x0,bed.x0*8);ext.z0=math.min(ext.z0,bed.z0*8)
  ext.x1=math.max(ext.x1,(bed.x1+1)*8);ext.z1=math.max(ext.z1,(bed.z1+1)*8)
  local horizontal=bed.x1-bed.x0>=bed.z1-bed.z0
  local outside=horizontal and ((bed.z0+bed.z1)/2<cross and bed.z0*8-4 or (bed.z1+1)*8+4)
    or ((bed.x0+bed.x1)/2<mx and bed.x0*8-4 or (bed.x1+1)*8+4)
  local start=horizontal and bed.x0 or bed.z0;local finish=horizontal and bed.x1 or bed.z1
  for _,side in ipairs({-1,1})do for inset=0,2 do
   local along=(side<0 and start+.5+inset or finish+.5-inset)*8
   local x,z=horizontal and along or outside,horizontal and outside or along
   if boundsClear(x-1.1,z-1.1,x+1.1,z+1.1,false)then candidates[#candidates+1]={x,z}end
  end end
 end
 for _,target in ipairs({{ext.x0,ext.z0},{ext.x1,ext.z0},{ext.x0,ext.z1},{ext.x1,ext.z1}})do
  local best,bestD
  for _,p in ipairs(candidates)do
   local clear=true
   for _,f in ipairs(lampGuides)do
    if (f.cx-p[1])^2+(f.cz-p[2])^2<16^2 then clear=false end
   end
   for _,f in ipairs(P.features)do
    if (f.cx-p[1])^2+(f.cz-p[2])^2<16^2 then clear=false end
   end
   local d=(p[1]-target[1])^2+(p[2]-target[2])^2
   if clear and (not bestD or d<bestD)then best,bestD=p,d end
  end
  if best then local x,z=best[1],best[2];add({kind='lamp',cx=x,cz=z},x-1.1,z-1.1,x+1.1,z+1.1)end
 end
 -- Add four inner-corner lanterns without moving the approved outer four.
 local inner={}
 for _,bed in ipairs(beds)do
  local horizontal=bed.x1-bed.x0>=bed.z1-bed.z0
  local side=horizontal and ((bed.z0+bed.z1)/2<cross) or (not horizontal and (bed.x0+bed.x1)/2<mx)
  local border=horizontal and (side and (bed.z1+1)*8+2 or bed.z0*8-2)
    or (side and (bed.x1+1)*8+2 or bed.x0*8-2)
  local start=horizontal and bed.x0 or bed.z0;local finish=horizontal and bed.x1 or bed.z1
  for _,endSide in ipairs({-1,1})do for inset=0,2 do
   local along=(endSide<0 and start+.5+inset or finish+.5-inset)*8
   local x,z=horizontal and along or border,horizontal and border or along
   if boundsClear(x-1.1,z-1.1,x+1.1,z+1.1,false)then inner[#inner+1]={x,z,side=side}end
  end end
 end
 for _,target in ipairs({{ext.x0,ext.z0,true},{ext.x1,ext.z0,true},{ext.x0,ext.z1,false},{ext.x1,ext.z1,false}})do
  local best,bestD
  for _,p in ipairs(inner)do if p.side==target[3]then
   local clear=true
   for _,lamp in ipairs(P.lamps)do if (lamp[1]-p[1])^2+(lamp[2]-p[2])^2<12^2 then clear=false end end
   local d=(p[1]-target[1])^2+(p[2]-target[2])^2
   if clear and (not bestD or d<bestD)then best,bestD=p,d end
  end end
  if best then local x,z=best[1],best[2];add({kind='lamp',cx=x,cz=z},x-1.1,z-1.1,x+1.1,z+1.1)end
 end
 local widest={x=0,z=0}
 for _,bed in ipairs(beds)do
  local axis=bed.x1-bed.x0>=bed.z1-bed.z0 and 'x' or 'z'
  local short=axis=='x' and bed.z1-bed.z0+1 or bed.x1-bed.x0+1
  widest[axis]=math.max(widest[axis],short)
 end
 -- Each lawn is its own seating court: two benches on each long side,
 -- facing across that lawn. All feet stay on the existing perimeter paving.
 P.seating={}
 local function courtBench(bed,axis,low,t)
  local edge=axis=='x' and (low and 'n' or 's') or (low and 'w' or 'e')
  local border=axis=='x' and (low and bed.z0*8 or (bed.z1+1)*8)
    or (low and bed.x0*8 or (bed.x1+1)*8)
  local across=border+(low and -2.5 or 2.5)
  local cx,cz=axis=='x' and t or across,axis=='x' and across or t
  local lo,hi=across+(low and -.88 or -2.32),across+(low and 2.32 or .88)
  local a,b,c,d
  if axis=='x' then a,b,c,d=t-9,lo,t+9,hi else a,b,c,d=lo,t-9,hi,t+9 end
  if not boundsClear(a,b,c,d,false,true)then return end
  for _,lamp in ipairs(P.lamps)do
   local dx=math.max(a-lamp[1],0,lamp[1]-c)
   local dz=math.max(b-lamp[2],0,lamp[2]-d)
   if dx*dx+dz*dz<6*6 then return end
  end
  return {kind='bench',cx=cx,cz=cz,edge=edge,depthScale=.8,bounds={a,b,c,d}}
 end
 for index,bed in ipairs(beds)do
  local axis=bed.x1-bed.x0>=bed.z1-bed.z0 and 'x' or 'z'
  local start=bed[axis..'0']*8;local finish=(bed[axis..'1']+1)*8
  local candidates={}
  for t=start+12,finish-12,2 do
   local a=courtBench(bed,axis,true,t);local b=courtBench(bed,axis,false,t)
   if a and b then candidates[#candidates+1]={station=t,a=a,b=b}end
  end
  local first,second,best
  local ideal1,ideal2=start+(finish-start)/3,start+2*(finish-start)/3
  local short=axis=='x' and bed.z1-bed.z0+1 or bed.x1-bed.x0+1
  local broad=short>=widest[axis]*.75
  local treeAtLow=(bed[axis..'0']+bed[axis..'1'])/2<(axis=='x' and mx or cross)
  if broad then
   -- Keep the tree-end pair; move the middle pair toward the opposite end.
   if treeAtLow then ideal2=finish-22 else ideal1=start+22 end
  end
  for i=1,#candidates do for j=i+1,#candidates do
   local a,b=candidates[i],candidates[j]
   local oppositeEnds=not broad or
     (treeAtLow and a.station<=start+(finish-start)*.45 and b.station>=finish-(finish-start)*.25) or
     (not treeAtLow and a.station<=start+(finish-start)*.25 and b.station>=finish-(finish-start)*.45)
   if b.station-a.station>=26 and oppositeEnds then
    local score=(a.station-ideal1)^2+(b.station-ideal2)^2
    if not best or score<best then first,second,best=a,b,score end
   end
  end end
  -- Prefer four seats; a constrained narrow lawn may keep one opposing pair.
  if not first then
   local middle=(start+finish)/2;local nearest
   for _,pair in ipairs(candidates)do
    local distance=math.abs(pair.station-middle)
    if not nearest or distance<nearest then first,nearest=pair,distance end
   end
  end
  if not broad then
   -- Two staggered seats, one on each long side of the narrow lawn.
   -- Pick them independently; a paired station would crowd its center.
   local aBest,bBest,bestScore
   for ta=start+16,finish-16,2 do
    local fa=courtBench(bed,axis,true,ta)
    if fa then for tb=start+16,finish-16,2 do
     local fb=courtBench(bed,axis,false,tb)
     if fb and tb-ta>=(finish-start)*.30 then
      local score=(ta-(start+(finish-start)*.28))^2+(tb-(start+(finish-start)*.72))^2
      if not bestScore or score<bestScore then aBest,bBest,bestScore=fa,fb,score end
     end
    end end
   end
   if aBest then
    for _,f in ipairs({aBest,bBest})do local q=f.bounds;add(f,q[1],q[2],q[3],q[4])end
    P.seating[#P.seating+1]={bed=index,axis=axis,staggered=true,a=aBest,b=bBest}
   end
  elseif first then
   local groups=second and {first,second} or {first}
   for _,pair in ipairs(groups)do
    for _,f in ipairs({pair.a,pair.b})do
     local bounds=f.bounds
     add(f,bounds[1],bounds[2],bounds[3],bounds[4])
    end
    P.seating[#P.seating+1]={bed=index,axis=axis,station=pair.station,a=pair.a,b=pair.b}
   end
  end
 end
 -- Small groups at the ends leave the middle of each lawn open. Their
 -- footprints remain inside grass, including crowns and low foliage.
 for _,bed in ipairs(beds)do
  local horizontal=bed.x1-bed.x0>=bed.z1-bed.z0
  local a=horizontal and bed.x0 or bed.z0;local b=horizontal and bed.x1 or bed.z1
  local across=horizontal and (bed.z0+bed.z1+1)*4 or (bed.x0+bed.x1+1)*4
  local low=(a+b)/2<(horizontal and mx or cross)
  local treeAt=(low and a+1.5 or b-.5)*8
  local tx,tz=horizontal and treeAt or across,horizontal and across or treeAt
  if boundsClear(tx-10.5,tz-10.5,tx+10.5,tz+10.5,true)then
   add({kind='tree',cx=tx,cz=tz},tx-10.5,tz-10.5,tx+10.5,tz+10.5)
  end

 end
 -- One low floral focus in each broad lawn; retain an open grass margin.
 for _,bed in ipairs(beds)do
  local horizontal=bed.x1-bed.x0>=bed.z1-bed.z0
  local axis=horizontal and 'x' or 'z';local short=horizontal and bed.z1-bed.z0+1 or bed.x1-bed.x0+1
  if short>=widest[axis]*.75 and short>=5 then
   local start=bed[axis..'0']*8;local finish=(bed[axis..'1']+1)*8
   local across=horizontal and (bed.z0+bed.z1+1)*4 or (bed.x0+bed.x1+1)*4
   local rx,rz=horizontal and 14 or 7,horizontal and 7 or 14
   for _,fraction in ipairs({.55,.65,.45,.72,.35})do
    local along=start+(finish-start)*fraction
    local cx,cz=horizontal and along or across,horizontal and across or along
    local clear=boundsClear(cx-rx,cz-rz,cx+rx,cz+rz,true,true)
    for _,f in ipairs(P.features)do if f.kind=='tree' then
     if math.abs(f.cx-cx)<rx+11 and math.abs(f.cz-cz)<rz+11 then clear=false end
    end end
    if clear then
     add({kind='centerpiece',cx=cx,cz=cz,rx=rx,rz=rz},cx-rx,cz-rz,cx+rx,cz+rz);break
    end
   end
  end
 end
 -- Small planting beds cap the short ends, centered within grass.
 -- Register them only after the approved centerpieces, so neither can move.
 for _,bed in ipairs(beds)do
  local horizontal=bed.x1-bed.x0>=bed.z1-bed.z0
  local axis=horizontal and 'x' or 'z'
  local start,finish=bed[axis..'0']*8,(bed[axis..'1']+1)*8
  local across=horizontal and (bed.z0+bed.z1+1)*4 or (bed.x0+bed.x1+1)*4
  local width=(horizontal and bed.z1-bed.z0+1 or bed.x1-bed.x0+1)*8
  local rx,rz=horizontal and 4.2 or math.min(11,width*.30),horizontal and math.min(11,width*.30) or 4.2
  -- Broad lawns keep a single focal bed and an open opposite end.
  local broad=width/8>=widest[axis]*.75 and width/8>=5
  for _,along in ipairs(broad and {} or {start+12,finish-12})do
   local cx,cz=horizontal and along or across,horizontal and across or along
   local clear=boundsClear(cx-rx,cz-rz,cx+rx,cz+rz,true,true)
   for _,f in ipairs(P.features)do if f.kind=='tree' or f.kind=='centerpiece' then
    local q=f.bounds
    if cx+rx+2>q[1] and cx-rx-2<q[3] and cz+rz+2>q[2] and cz-rz-2<q[4]then clear=false end
   end end
   if clear then add({kind='borderbed',cx=cx,cz=cz,rx=rx,rz=rz},cx-rx,cz-rz,cx+rx,cz+rz)end
  end
 end
 -- Small civic amenities occupy the outer long-edge paving, never lawn or
 -- the central aisle. Choose separated ends, with full feature/door clearance.
 local amenities={}
 for _,bed in ipairs(beds)do
  local horizontal=bed.x1-bed.x0>=bed.z1-bed.z0
  if horizontal then
   local outside=(bed.z0+bed.z1)/2<cross and bed.z0*8-3 or (bed.z1+1)*8+3
   for x=bed.x0*8+8,(bed.x1+1)*8-8,4 do amenities[#amenities+1]={x,outside}end
  end
 end
 local placedBins={}
 for _,kind in ipairs({'bin','bin','gardenSign','fountain'})do
  local rx,rz=kind=='gardenSign' and 5.8 or 1.7,1.7
  local best,bestScore
  for _,p in ipairs(amenities)do
   local a,b,c,d=p[1]-rx,p[2]-rz,p[1]+rx,p[2]+rz
   local clear=boundsClear(a,b,c,d,false,true);local benchDist=1e9
   for _,f in ipairs(P.features)do
    local q=f.bounds
    if a<q[3]+2.5 and c>q[1]-2.5 and b<q[4]+2.5 and d>q[2]-2.5 then clear=false end
    if f.kind=='bench' then benchDist=math.min(benchDist,(p[1]-f.cx)^2+(p[2]-f.cz)^2)end
   end
   for _,q in ipairs(placedBins)do if kind=='bin' and (p[1]-q[1])^2+(p[2]-q[2])^2<48^2 then clear=false end end
   local score=kind=='bin' and benchDist or (p[1]-ext.x0)^2+(p[2]-ext.z1)^2
   if clear and (not bestScore or score<bestScore)then best,bestScore=p,score end
  end
  if best then
   add({kind=kind,cx=best[1],cz=best[2]},best[1]-rx,best[2]-rz,best[1]+rx,best[2]+rz)
   if kind=='bin' then placedBins[#placedBins+1]=best end
  end
 end
 for _,cell in pairs(P.cells)do if not cell.lawn then
  for _,d in ipairs(dirs)do if lawn(cell.x+d[2],cell.z+d[3])then cell.gardenFrame=true;cell.brickEdges=cell.brickEdges or {};cell.brickEdges[d[1]]=true end end
  -- Complete the stone rectangle at diagonal corners too.
  for dz=-1,1 do for dx=-1,1 do if lawn(cell.x+dx,cell.z+dz)then cell.gardenFrame=true end end end
 end end
 -- Every original bed remains a full rectangle with one continuous low curb.
 for _,c in pairs(P.cells)do if c.lawn then
  P.lawns=P.lawns+1;c.edges={}
  for _,d in ipairs(dirs)do c.edges[d[1]]=not lawn(c.x+d[2],c.z+d[3])end
 end end
 return P
end
function M.build(x,z,h,cell,emit)
 local G=C.builder(x,z,emit)
 if not cell.lawn then
  -- Use the same flat world-aligned flags as the rest of the city. No pads.
  V.require('CeladonPaving').build(x,z,h,function(q,mat,tone)emit(q,mat,tone)end,cell.gardenFrame and 'stonePaving' or 'clayBrick',cell.brickEdges)
  if cell.gardenFrame and not cell.features and C.hash(x,z,7510)>.78 then
   local px,pz=x+.35,z+.35
   for j=0,2 do G.blade(px,pz,h+.02,1.2+C.hash(x,j+z,7511)*1.0,.10,.4,j*2.1,'leaf',.88)end
  end
  for _,f in ipairs(cell.features or {})do M.fixture(x,z,h,f,emit)end
  return
 end
 G.flat(x,z,x+8,z+8,h+.15,'turf',.97+C.field(x/40,z/40,6502)*.08)
 for _,e in ipairs({'w','e','n','s'})do if cell.edges[e]then
  local a,b,c,d=x,z,x+8,z+8
  if e=='w'then c=x+.45 elseif e=='e'then a=x+7.55 elseif e=='n'then d=z+.45 else b=z+7.55 end
  G.box(a,b,c,d,h+.1,h+.45,'body',1.01)
 end end
 -- Quiet grass between planted pockets, without the repetitive dotted border.
 if C.hash(x,z,6801)>.58 then
  for i=0,1 do
   local a=x+1+C.hash(x,z,6310+i)*6;local b=z+1+C.hash(x,z,6320+i)*6
   G.blade(a,b,h+.1,.5+C.hash(x,z,6330+i)*.8,.12,.22,i,'leaf',.84)
  end
 end
 for _,feature in ipairs(cell.features or {})do M.fixture(x,z,h,feature,emit)end
end
function M.fixture(x,z,h,f,emit)
 local G=C.builder(x,z,emit)
 if f.kind=='bin' or f.kind=='gardenSign' or f.kind=='fountain' then V.require('CeladonAmenities').build(x,z,h,f,emit)
 elseif f.kind=='borderbed' or f.kind=='centerpiece' then V.require('CeladonGardenDetail').build(x,z,h,f,emit)
 elseif f.kind=='bench' then V.require('HarborBench').build(x,z,h,f,emit)
 elseif f.kind=='lamp' then
  local a,b=f.cx,f.cz
  G.box(a-.75,b-.75,a+.75,b+.75,h+.1,h+.65,'body',1)
  G.box(a-.25,b-.25,a+.25,b+.25,h+.65,h+13,'shadow',.5)
  G.box(a-.9,b-.9,a+.9,b+.9,h+12,h+12.5,'shadow',.55)
  G.box(a-.65,b-.65,a+.65,b+.65,h+12.5,h+15,'glass',1)
  for _,dx in ipairs({-.8,.65})do for _,dz in ipairs({-.8,.65})do G.box(a+dx,b+dz,a+dx+.15,b+dz+.15,h+12.4,h+15.2,'shadow',.5)end end
  G.box(a-1,b-1,a+1,b+1,h+15,h+15.6,'shadow',.65)
 elseif f.kind=='tree' or f.kind=='planting' then
  local a,b=f.cx,f.cz
  local function crown(cx,cy,cz,rx,ry,rz,seed,rows,sides)
   for row=0,rows-1 do
    local lat0=-math.pi/2+row*math.pi/rows;local lat1=lat0+math.pi/rows
    for j=0,sides-1 do
     local u,v=j*math.pi*2/sides,(j+1)*math.pi*2/sides
     local function p(lat,lon)return {cx+rx*math.cos(lat)*math.cos(lon),h+cy+ry*math.sin(lat),cz+rz*math.cos(lat)*math.sin(lon)}end
     G.face({p(lat0,u),p(lat0,v),p(lat1,v),p(lat1,u)},'canopy',.88+row*.08+C.hash(j,row,seed)*.17)
    end
   end
  end
  if f.kind=='tree' then
   V.require('CeladonGardenDetail').treeBase(x,z,h,f,emit)
   G.box(a-.65,b-.65,a+.65,b+.65,h+.1,h+11,'wood',.8)
   -- Solid tapered branch forks, with smaller offshoots beneath the leaves.
   local function branch(x0,y0,z0,x1,y1,z1,r0,r1)
    for k=0,4 do
     local u,v=k*math.pi*.4,(k+1)*math.pi*.4
     G.face({{x0+math.cos(u)*r0,h+y0,z0+math.sin(u)*r0},{x0+math.cos(v)*r0,h+y0,z0+math.sin(v)*r0},{x1+math.cos(v)*r1,h+y1,z1+math.sin(v)*r1},{x1+math.cos(u)*r1,h+y1,z1+math.sin(u)*r1}},'wood',.72+k*.025)
    end
   end
   -- Continuous central leader overlaps the trunk and reaches the upper crown.
   branch(a,9.5,b,a,19,b,.59,.22)
   -- An overlapping inner crown closes the hollow middle between leaf clusters.
   crown(a,15.8,b,4.7,3.6,4.7,7900,3,7)
   -- Offset foliage masses of different sizes break the old four-blob outline.
   -- All clusters remain inside the original radius-10.5 footprint.
   for j=0,17 do
    local angle=j*2.39996
    local outer=j<11;local r=outer and (5.4+C.hash(j,0,7801)*1.3) or (1.3+C.hash(j,0,7802)*2)
    local cy=outer and (13.4+C.hash(j,0,7803)*3.8) or (17.7+C.hash(j,0,7804)*2)
    local rx=2.5+C.hash(j,0,7805)*.8
    local rz=2.4+C.hash(j,0,7806)*.9
    local cx,cz=a+math.cos(angle)*r,b+math.sin(angle)*r
    -- Each limb starts inside the leader and ends inside its own leaf cluster.
    -- Shared coordinates prevent detached crowns when the leaf layout varies.
    local joinY=outer and 10.2+(j%3)*.7 or 15.2
    branch(a,joinY,b,cx,cy,cz,outer and .32 or .24,.10)
    crown(cx,cy,cz,rx,2.1+C.hash(j,0,7807)*1.1,rz,7808+j,3,7)
   end

  else
   -- Raised foliage and flower clusters, baked into the same terrain mesh.
   crown(a-1.6,1.7,b+.6,2.9,1.6,2.7,6810,2,6)
   crown(a+1.6,2.1,b-.8,2.8,2,2.8,6811,2,6)
   for j=0,4 do
    local angle=j*2.4;local px,pz=a+math.cos(angle)*2.7,b+math.sin(angle)*2.7
    local y=h+2.1+C.hash(a+j,b,6812)*1.7
    G.blade(px,pz,h+.16,y-h,.06,0,angle,'leaf',.85)
    for k=0,4 do
     local u,v=k*math.pi*.4,(k+1)*math.pi*.4
     G.face({{px,y+.22,pz},{px+math.cos(u)*.58,y,pz+math.sin(u)*.58},{px+math.cos(v)*.58,y,pz+math.sin(v)*.58}},'petal',.88+j*.06)
    end
   end
  end
 end
end
return M
