-- Settled winter snow. Independent meshes; never edits host terrain/collision.
local G,PillarSnow=...
local M={}
local floor,min,max,abs=math.floor,math.min,math.max,math.abs
local function key(x,z)return(z+64)*4096+x+64 end
local function smooth(v)v=max(0,min(1,v));return v*v*(3-2*v)end
local function field(x,z,seed)
 local a,b=floor(x),floor(z);local u,v=smooth(x-a),smooth(z-b)
 return (G.hash(a,b,seed)*(1-u)+G.hash(a+1,b,seed)*u)*(1-v)
       +(G.hash(a,b+1,seed)*(1-u)+G.hash(a+1,b+1,seed)*u)*v
end
function M.enabled(snapshot,options)
 return options.holiday=='christmas' and options.groundSnow=='full'
  and snapshot.tags and snapshot.tags.outdoor==true
end

-- Read the final shell after companion replacements, and the real 8-unit floor.
function M.sources(bridge,map,snapshot,info)
 local out={tiles={},faces={},doors={},fixtures=0}
 local ok,Structures=pcall(bridge.V.require,'Structures')
 if not(ok and Structures and Structures.forMap)then return out end
 local good,S=pcall(Structures.forMap,map)
 if not(good and S)then return out end
 local cs=snapshot.cellSize or 16;local grid={}
 for _,c in ipairs(snapshot.cells or {})do
  grid[key(c.x,c.z)]=c
  if c.tags and c.tags.door then out.doors[#out.doors+1]={x=(c.x+.5)*cs,z=(c.z+.5)*cs}end
 end
 local buildings=S.cityBuildings or {}
 local function insideBuilding(x,z)
  for _,b in ipairs(buildings)do
   if b.tileX and b.tileW and x>b.tileX and x<b.tileX+b.tileW
    and z>b.tileZ and z<b.tileZ+b.tileH-(b.frontEave or 0) then return true end
  end
  return false
 end
 local park=info.park
 local function face(q,eligible,kind)
  if not(q[1]and q[4])then return end
  -- Vertical faces cannot shelter/support snow. Reject before copying.
  local a,b,c=q[1],q[2],q[3]
  if abs((b[3]-a[3])*(c[1]-a[1])-(b[1]-a[1])*(c[3]-a[3]))<1e-7 then return end
  local p={eligible=eligible,kind=kind}
  for j=1,4 do p[j]={q[j][1],q[j][2],q[j][3]}end
  out.faces[#out.faces+1]=p
 end
 for i,q in ipairs(S.objectQuads or {})do
  local a,b,c=q[1],q[2],q[3]
  if a and q[4]and abs((b[3]-a[3])*(c[1]-a[1])-(b[1]-a[1])*(c[3]-a[3]))>=1e-7 then
  local eligible=q.kantoFence==true
  local bounds=info.quadBounds and info.quadBounds[q]
  if not eligible then
   for _,b in ipairs(info.buildings or {})do
    local inside=true
    if bounds then inside=bounds.x0>=b.x0-4 and bounds.x1<=b.x1+4 and bounds.z0>=b.z0-4 and bounds.z1<=b.z1+18
    else for j=1,4 do local p=q[j]
     if p[1]<b.x0-4 or p[1]>b.x1+4 or p[3]<b.z0-4 or p[3]>b.z1+18 then inside=false;break end
    end end
    if inside then eligible=true;break end
   end
  end
  -- Glass does not support an opaque cap, but can still shelter the floor.
  face(q,eligible and not q.referenceGlass,q.kantoFence and 'rail' or 'building')
  end
  if i%256==0 then G.checkpoint()end
 end
 if PillarSnow then
  out.pillarRecord,out.pillars=PillarSnow.append(bridge,map.id,face)
  out.pillarSignature=PillarSnow.signature(out.pillarRecord)
 end
 local tw,th=snapshot.width*cs/8,snapshot.height*cs/8
 for z=0,th-1 do for x=0,tw-1 do
  local k=key(x,z);local s=S.shapeAt and S.shapeAt[k]
  local run=S.runs and S.runs[k];local skipped=S.skip and S.skip[k]
  local c=grid[key(floor(x*8/cs),floor(z*8/cs))];local tags=c and c.tags or {}
  local pk=park and park.cells[k]
  local valid,height
  if S.shapeAt then
   valid=s and ((s.class=='ground' and s.flat and not run and not skipped)
     or(skipped and S.ground and type(S.ground[k])=='number'))
   height=skipped and 0 or (s and s.h or 0)
  else
   -- Some hosts/fixtures expose only snapshot floor facts. Never infer slopes.
   height=c and(c.worldY or c.height or 0)or 0
   valid=c and c.walkable and height<=.5 and not tags.tree and not tags.signpost
  end
  if valid and not tags.water and not tags.grass and not tags.door
   and not insideBuilding(x*8+4,z*8+4)then
   local tile=S.tileAt and S.tileAt[k]
   out.tiles[k]={x=x,z=z,y=height,lawn=(pk and pk.lawn)or tile==44 or(s and s.art=='grass')or false}
  end
  -- Outdoor terrain ledges are top surfaces, distinct from walkable ground.
  if s and s.class=='ledge' and not skipped and not(run and (run.rise or 0)>0)then
   local h=run and run.h or s.h
   if h and h>.65 then face({{x*8,h,z*8},{x*8+8,h,z*8},{x*8+8,h,z*8+8},{x*8,h,z*8+8}},true,'ledge')end
  end
  if pk then
   for _,f in ipairs(pk.features or {})do
    if f.kind=='bench' or f.kind=='lamp' or f.kind=='bin' or f.kind=='gardenSign' then
     local worked,err=pcall(function()
      local Park=bridge.V.require('CeladonPark')
      Park.fixture(x*8,z*8,height or 0,f,function(q,swatch)
       face(q,swatch~='glass','park_'..f.kind)
      end)
     end)
     if not worked then out.warning=tostring(err)end
     out.fixtures=out.fixtures+1
    end
   end
  end
 end;G.checkpoint()end
 return out
end

-- Projected triangle index: topmost support wins, irrespective of inconsistent
-- winding in host builders. This rejects undersides and sheltered lower rails.
function M.index(faces)
 local data={buckets={},triangles={}}
 local function add(a,b,c,owner)
  local ux,uy,uz=b[1]-a[1],b[2]-a[2],b[3]-a[3]
  local vx,vy,vz=c[1]-a[1],c[2]-a[2],c[3]-a[3]
  local nx,ny,nz=uy*vz-uz*vy,uz*vx-ux*vz,ux*vy-uy*vx
  if abs(ny)<1e-7 then return end
  local t={a=a,b=b,c=c,nx=nx,ny=ny,nz=nz,owner=owner,
   eligible=owner.eligible and abs(ny)/math.sqrt(nx*nx+ny*ny+nz*nz)>.60
    and min(a[2],b[2],c[2])>.65}
  t.maxY=max(a[2],b[2],c[2])
  t.x0=min(a[1],b[1],c[1]);t.x1=max(a[1],b[1],c[1]);t.z0=min(a[3],b[3],c[3]);t.z1=max(a[3],b[3],c[3])
  data.triangles[#data.triangles+1]=t
  for z=floor(t.z0/8),floor(t.z1/8)do for x=floor(t.x0/8),floor(t.x1/8)do
   local k=key(x,z);data.buckets[k]=data.buckets[k]or{};local list=data.buckets[k];list[#list+1]=t
  end end
 end
 for i,q in ipairs(faces)do add(q[1],q[2],q[3],q);add(q[1],q[3],q[4],q);if i%256==0 then G.checkpoint()end end
 for _,bucket in pairs(data.buckets)do table.sort(bucket,function(a,b)return a.maxY>b.maxY end)end
 function data:top(x,z)
  local best,owner=-1e9,nil
  for _,t in ipairs(self.buckets[key(floor(x/8),floor(z/8))]or{})do
   if t.maxY<best then break end
   if x>=t.x0-1e-5 and x<=t.x1+1e-5 and z>=t.z0-1e-5 and z<=t.z1+1e-5 then
    local a,b,c=t.a,t.b,t.c
    local e1=(b[1]-a[1])*(z-a[3])-(b[3]-a[3])*(x-a[1])
    local e2=(c[1]-b[1])*(z-b[3])-(c[3]-b[3])*(x-b[1])
    local e3=(a[1]-c[1])*(z-c[3])-(a[3]-c[3])*(x-c[1])
    if(min(e1,e2,e3)>=-1e-5 or max(e1,e2,e3)<=1e-5)then
     local y=a[2]-(t.nx*(x-a[1])+t.nz*(z-a[3]))/t.ny
     if y>best then best,owner=y,t end
    end
   end
  end
  return best,owner
 end
 return data
end

local function uptri(g,a,b,c,mat,shade,uv)
 if (b[3]-a[3])*(c[1]-a[1])-(b[1]-a[1])*(c[3]-a[3])<0 then
  b,c=c,b;if uv then uv={uv[1],uv[3],uv[2]}end
 end
 G.tri(g,a,b,c,mat,shade,uv)
end
local function mid(a,b)return{(a[1]+b[1])*.5,(a[2]+b[2])*.5,(a[3]+b[3])*.5}end
local function distance(a,b)return(a[1]-b[1])^2+(a[3]-b[3])^2 end
local function pillarFace(q)return q.kind=='pillar'or q.kind=='pillar_wall'or q.kind=='district_rail'end
function M.withoutPillars(source)
 local out={tiles=source.tiles,doors=source.doors,faces={},fixtures=source.fixtures,warning=source.warning}
 for _,q in ipairs(source.faces)do if not pillarFace(q)then out.faces[#out.faces+1]=q end end
 return out
end

function M.refreshPillars(bridge,id,previous)
 local source={tiles={},doors={},faces={},capsOnly=true}
 -- Reuse the town shell for occlusion. Only changing pillar caps are emitted;
 -- ground, roofs, railings and footprint surfaces remain untouched.
 for _,q in ipairs(previous.faces)do if not pillarFace(q)then source.faces[#source.faces+1]=q end end
 source.pillarRecord,source.pillars=PillarSnow.append(bridge,id,function(q,eligible,kind)
  local face={q[1],q[2],q[3],q[4],eligible=eligible,kind=kind}
  source.faces[#source.faces+1]=face
 end)
 source.pillarSignature=PillarSnow.signature(source.pillarRecord)
 return source
end

function M.build(source,emit)
 local surfaces={}
 local stats={surface=surfaces,pillarRecord=source.pillarRecord,pillarSignature=source.pillarSignature,pillars=source.pillars or 0,groundTiles=0,groundTriangles=0,capTriangles=0,vertices=0,fixtures=source.fixtures,warning=source.warning}
 local index=M.index(source.faces);local g=G.new();local phase='ground'
 local function flush(force)
  if #g.vertices>=45000 or(force and #g.vertices>0)then stats.vertices=stats.vertices+#g.vertices;g.snowKind=phase;emit(g);g=G.new();G.checkpoint()end
 end
 local tiles=source.tiles
 local function tileAt(x,z)return tiles[key(floor(x/8),floor(z/8))]end
 local function floorBlend(x,z)
  local fx,fz=x/8-.5,z/8-.5;local a,b=floor(fx),floor(fz)
  local u,v=smooth(fx-a),smooth(fz-b);local lawn,coverage=0,0
  for dz=0,1 do for dx=0,1 do
   local weight=(dx==0 and 1-u or u)*(dz==0 and 1-v or v)
   local t=tiles[key(a+dx,b+dz)]
   if t then coverage=coverage+weight;if t.lawn then lawn=lawn+weight end end
  end end
  return lawn,coverage
 end
 -- Door influence ends at 18 units. Index only those neighborhoods instead
 -- of scanning every door in town for every snow vertex.
 local doorBuckets={}
 for _,d in ipairs(source.doors)do
  for z=floor((d.z-18)/32),floor((d.z+18)/32)do for x=floor((d.x-18)/32),floor((d.x+18)/32)do
   local k=key(x,z);doorBuckets[k]=doorBuckets[k]or{};table.insert(doorBuckets[k],d)
  end end
 end
 local empty={}
 local function doorsAt(x,z)return doorBuckets[key(floor(x/32),floor(z/32))]or empty end
 local function depth(x,z,t)
  -- Blend material/depth across tile joins. Foot traffic packs the street low;
  -- undisturbed lawns and sheltered edges hold a much deeper blanket.
  local powder,coverage=floorBlend(x,z)
  local h=.27+.65*powder+.68*(1-coverage)+.19*field(x/12,z/12,887)
  h=h+.20*field(x/4,z/4,889)*powder
  for _,d in ipairs(doorsAt(x,z))do
   local dist=math.sqrt((x-d.x)^2+(z-d.z)^2)
   h=h*(.10+.90*smooth((dist-6)/12))
  end
  return h,powder
 end
 local pointCache={}
 local function groundPoint(x,z,t)
  local k=key(floor(x/4),floor(z/4));local entry=pointCache[k]
  if not entry then local h,p=depth(x,z,t);entry={h=h,p=p};pointCache[k]=entry end
  return{x,t.y+.08+entry.h,z},entry.p
 end
 -- Four-unit shared sampling preserves real depth with one quarter as many
 -- ground triangles. Footprints sample the exact accepted triangles below.
 local ordered={};for _,t in pairs(tiles)do ordered[#ordered+1]=t end
 table.sort(ordered,function(a,b)return a.z==b.z and a.x<b.x or a.z<b.z end)
 for _,t in ipairs(ordered)do
  stats.groundTiles=stats.groundTiles+1
  for dz=0,4,4 do for dx=0,4,4 do
   local x,z=t.x*8+dx,t.z*8+dz;local cx,cz=x+2,z+2
   local sheltered=index:top(cx,cz)>t.y+1.8
   local cleared=false
   for _,d in ipairs(doorsAt(cx,cz))do if (cx-d.x)^2+(cz-d.z)^2<36 then cleared=true;break end end
   if not sheltered and not cleared then
    local a,p=groundPoint(x,z,t);local b=groundPoint(x+4,z,t);local c=groundPoint(x+4,z+4,t);local d=groundPoint(x,z+4,t)
    local material='packedSnow'
    local u,v=(x%8)/8,(z%8)/8
    local shade=.94+.055*p+.025*field(cx/18,cz/18,900)
    local cell={a=a,b=b,c=c,d=d}
    surfaces[key(floor(x/4),floor(z/4))]=cell
    local function top(A,B,C,uv,which)
     -- Sample the corners too: a narrow rail or curved canopy can cross a
     -- subcell without covering its center. Do not paint beneath that shelter.
     for _,p in ipairs({A,B,C})do if index:top(p[1],p[3])>t.y+1.8 then return end end
     if index:top((A[1]+B[1]+C[1])/3,(A[3]+B[3]+C[3])/3)>t.y+1.8 then return end
     uptri(g,A,B,C,material,shade,uv);stats.groundTriangles=stats.groundTriangles+1;cell[which]=true
    end
    top(a,b,c,{{u,v},{u+.5,v},{u+.5,v+.5}},1)
    top(a,c,d,{{u,v},{u+.5,v+.5},{u,v+.5}},2)
    -- A short visible lip joins exposed boundaries down to their real floor.
    local points={a,b,c,d}
    for j=1,4 do local A,B=points[j],points[j%4+1]
     local mx,mz=(A[1]+B[1])*.5,(A[3]+B[3])*.5
     local ox,oz=(mx-cx)*1.04,(mz-cz)*1.04
     if not tileAt(cx+ox,cz+oz)then
      G.quad(g,{A[1],t.y+.02,A[3]},A,B,{B[1],t.y+.02,B[3]},material,.94)
     end
    end
   end
  end end
  flush();G.checkpoint()
 end
 flush(true)
 phase='caps'
 local capCache={};local emitted={}
 local function capPoint(p)
  local k=string.format('%.4f,%.4f,%.4f',p[1],p[2],p[3])
  if capCache[k]then return capCache[k]end
  local support=0
  for _,d in ipairs({{.5,0},{-.5,0},{0,.5},{0,-.5}})do
   if abs(index:top(p[1]+d[1],p[3]+d[2])-p[2])<.65 then support=support+1 end
  end
  local thickness=.16+.43*support/4+.17*field(p[1]/7,p[3]/7,917)
  local v={p[1],p[2]+thickness,p[3]};capCache[k]=v;return v
 end
 local function visible(p)return index:top(p[1],p[3])<=p[2]+.035 end
 local calls=0;local limit=16
 local function cap(a,b,c,level)
  calls=calls+1;if calls%64==0 then G.checkpoint()end
  -- A single upper triangle enclosing this entire triangle can reject an
  -- underside before subdivision. Partial coverage still gets refined.
  if level==0 then
   local _,t=index:top((a[1]+b[1]+c[1])/3,(a[3]+b[3]+c[3])/3)
   if t then
    local covered=true
    for _,p in ipairs({a,b,c})do
     local A,B,C=t.a,t.b,t.c
     local e1=(B[1]-A[1])*(p[3]-A[3])-(B[3]-A[3])*(p[1]-A[1])
     local e2=(C[1]-B[1])*(p[3]-B[3])-(C[3]-B[3])*(p[1]-B[1])
     local e3=(A[1]-C[1])*(p[3]-C[3])-(A[3]-C[3])*(p[1]-C[1])
     local y=A[2]-(t.nx*(p[1]-A[1])+t.nz*(p[3]-A[3]))/t.ny
     if not((min(e1,e2,e3)>=-1e-5 or max(e1,e2,e3)<=1e-5)and y>p[2]+.035)then covered=false;break end
    end
    if covered then return end
   end
  end
  local ab,bc,ca=distance(a,b),distance(b,c),distance(c,a)
  if max(ab,bc,ca)>limit and level<12 then
   if ab>=bc and ab>=ca then local p=mid(a,b);cap(a,p,c,level+1);cap(p,b,c,level+1)
   elseif bc>=ca then local p=mid(b,c);cap(a,b,p,level+1);cap(a,p,c,level+1)
   else local p=mid(c,a);cap(a,b,p,level+1);cap(p,b,c,level+1)end
   return
  end
  local p={(a[1]+b[1]+c[1])/3,(a[2]+b[2]+c[2])/3,(a[3]+b[3]+c[3])/3}
  if not visible(p)then return end
  -- If a boundary passes beneath a taller surface, refine before accepting.
  local function third(u,v,w)return{(u[1]+v[1]+w[1])/3,(u[2]+v[2]+w[2])/3,(u[3]+v[3]+w[3])/3}end
  if not(visible(a)and visible(b)and visible(c)and visible(mid(a,b))and visible(mid(b,c))and visible(mid(c,a))
   and visible(third(a,b,p))and visible(third(b,c,p))and visible(third(c,a,p)))then
   if level<14 and max(ab,bc,ca)>1 then
    local d,e,f=mid(a,b),mid(b,c),mid(c,a)
    cap(a,d,f,level+1);cap(d,b,e,level+1);cap(f,e,c,level+1);cap(d,e,f,level+1)
   end
   return
  end
  local k=string.format('%.4f,%.4f,%.4f',p[1],p[2],p[3]);if emitted[k]then return end;emitted[k]=true
  local A,B,C,P=capPoint(a),capPoint(b),capPoint(c),capPoint(p)
  -- Interior sample rounds even a thin rail or small post cap upward.
  uptri(g,A,B,P,'powderSnow');uptri(g,B,C,P,'powderSnow');uptri(g,C,A,P,'powderSnow')
  stats.capTriangles=stats.capTriangles+3
  local ps={a,b,c};local tops={A,B,C}
  for j=1,3 do local n=j%3+1;local u,v=ps[j],ps[n];local d=math.sqrt(distance(u,v))
   if d>.02 then
    local m=mid(u,v);local ox,oz=-(v[3]-u[3])*.07/d,(v[1]-u[1])*.07/d
    local left=index:top(m[1]+ox,m[3]+oz);local right=index:top(m[1]-ox,m[3]-oz)
    if min(left,right)<m[2]-.65 then
     G.quad(g,{u[1],u[2]+.025,u[3]},tops[j],tops[n],{v[1],v[2]+.025,v[3]},'powderSnow',.93)
    end
   end
  end
  flush()
 end
 for pass=1,2 do
  flush(true);phase=pass==2 and 'pillars'or 'caps'
  for i,t in ipairs(index.triangles)do
   local isPillar=pillarFace(t.owner)
   if t.eligible and (isPillar and pass==2 or not isPillar and pass==1 and not source.capsOnly)then
    limit=t.owner.kind=='building'and 64 or 16;cap(t.a,t.b,t.c,0)
   end
   if i%128==0 then G.checkpoint()end
  end
 end
 flush(true)
 return stats
end
-- Height on the emitted ground, never on water, hidden floor or missing snow.
function M.height(surface,x,z)
 local c=surface and surface[key(floor(x/4),floor(z/4))]
 if not c then return end
 local u,v=(x-c.a[1])/4,(z-c.a[3])/4
 if u>=v then
  if c[1]then return c.a[2]*(1-u)+c.b[2]*(u-v)+c.c[2]*v end
 elseif c[2]then return c.a[2]*(1-v)+c.c[2]*u+c.d[2]*(v-u)end
end
return M
