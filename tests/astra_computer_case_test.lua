-- Live computer geometry/material regression against immutable A11.
-- The CRT keeps its authored 45-degree orientation but has real planar faces.
local root=os.getenv('ASTRA_COMPUTER_ROOT') or os.getenv('ASTRA_CANDIDATE') or '.'
local baseline=assert(os.getenv('ASTRA_COMPUTER_BASELINE'))
local atlasDir=assert(os.getenv('ASTRA_FURNITURE_ATLASES'))
local H=dofile('tests/astra_fixture.lua')
local checks=0
local function ok(v,msg)checks=checks+1;if not v then error('FAIL '..msg,0)end end
local function eq(a,b,msg)ok(a==b,msg..' (expected '..tostring(b)..', got '..tostring(a)..')')end
local function near(a,b,msg)ok(type(a)=='number'and math.abs(a-b)<1e-8,msg)end
local function same(a,b,msg)
 eq(type(a),type(b),msg..' type')
 if type(a)~='table'then eq(a,b,msg);return end
 for k,v in pairs(a)do same(v,b[k],msg..'.'..tostring(k))end
 for k in pairs(b)do ok(a[k]~=nil,msg..' no extra '..tostring(k))end
end
local spec=dofile(root..'/data/voxel_heights.lua')
local function template(family,id)
 for _,t in ipairs(spec.buildings[family])do if t.id==id then return t end end
 error('missing '..family..'/'..id)
end
local uprightModels={
 -- A18 Oak owns the changed DOJO desk and locks all its equipment against A17.
 {'GYM','lab_computers','gym',6,{1,3}},
 {'POKECENTER','center_pc','pokecenter',4,{1}}, {'MART','center_pc','pokecenter',4,{1}}}
for _,c in ipairs(uprightModels)do
 local data,w,h=H.atlas(atlasDir..'/'..c[3]..'.rgba')
 local emit,m,s=H.building(root,c[2],data,w,h,nil,true,c[1])
 local oe,old,os=H.building(baseline,c[2],data,w,h,nil,true,c[1])
 local t=template(c[1],c[2]);local regions={};local changed,rear,front=0,0,0
 for _,j in ipairs(c[5])do
  local p=t.parts[j]
  -- This independently measured top-strip donor also lets A11 fail on
  -- its actual copied rear material, not merely on an absent opt-in flag.
  local donor=s.W+p.x[1]+1
  ok(s.inside[donor],'casing comes from inside original object art');eq(s.col[donor],0,'case matches the original white lid material')
  regions[#regions+1]={p=p,donor=donor,y0=c[4]+(p.rise or 0),y1=c[4]+(p.rise or 0)+p.facade[2]-p.facade[1]-1}
 end
 eq(m.W,old.W,'upright width unchanged');eq(m.ytop,old.ytop,'upright height unchanged')
 eq(m.zmin,old.zmin,'upright back unchanged');eq(m.zmax,old.zmax,'upright front unchanged')
 for y=0,m.ytop do for z=m.zmin,m.zmax do for x=0,m.W-1 do
  local a,b=m.at(x,y,z),old.at(x,y,z);eq(a~=nil,b~=nil,'upright casing preserves every occupied position')
  local r
  for _,v in ipairs(regions)do local p=v.p
   if x>=p.x[1]and x<=p.x[2]and y>=v.y0 and y<=v.y1 and z>=(p.z or 0)and z<(p.z or 0)+p.depth then r=v;break end
  end
  if r and a~=nil then
   local p=r.p;local far=(p.z or 0)+p.depth-1
   local sy=r.y0+p.facade[2]-y
   local source=sy*s.W+x
   local inset=z==far-1 and old.at(x,y,far)==nil
   if z==far or inset then
    eq(a,source,'front panel and actual inset preserve the original source pixel');front=front+1
   else
    eq(a,r.donor,'hidden body and exposed sides use original casing rather than copied screen/drive art')
    if z==(p.z or 0)then rear=rear+1 end
   end
   if a~=b then changed=changed+1 end
  else
   eq(a,b,'all lid, keyboard, paper, cable and desk source indices remain exact')
   if a~=nil then eq(s.ax[a],os.ax[b],'unchanged original atlas X');eq(s.ay[a],os.ay[b],'unchanged original atlas Y')end
  end
 end end end
 ok(changed>50,'actual atlas exercises substantial duplicated-front cleanup')
 ok(rear>=120,'actual exposed rear bodies exercised');ok(front>50,'original readable fronts retained')
 local q,oq=emit(m,s,w,h),oe(old,os,w,h)
 eq(q.voxels,oq.voxels,'upright occupancy count unchanged')
 print(('%s/%s: original front retained; %d rear case cells; %d material changes; quads %d -> %d'):format(c[1],c[2],rear,changed,#oq,#q))
end
local data,w,h=H.atlas(atlasDir..'/interior.rgba')
local emit,m,s=H.building(root,'bills_desk',data,w,h,nil,true,'INTERIOR')
local oe,old,os=H.building(baseline,'bills_desk',data,w,h,nil,true,'INTERIOR')
local t=template('INTERIOR','bills_desk');local p=t.parts[4]
ok(p.kind=='iso'and p.case,'Bill CRT explicitly opts into angled planar surfaces')
local n=(p.x[2]-p.x[1]+1)/2
local base=8;local height=7
local function localPoint(v)return (v[1]-p.x[1]+v[3]-p.z)/2,v[2]-base,(v[1]-p.x[1]-v[3]+p.z)/2 end
local function inComputer(x,y,z)return x>=19 and x<=30 and y>=8 and y<=14 and z>=3 and z<=15 end
local unchanged,chair,proxy=0,0,0
for y=0,math.max(m.ytop,old.ytop)do for z=m.zmin,m.zmax do for x=0,m.W-1 do
 local a,b=m.at(x,y,z),old.at(x,y,z)
 if not inComputer(x,y,z)then
  eq(a,b,'every voxel/source outside the explicitly upgraded CRT stays exact')
  if a~=nil then
   unchanged=unchanged+1;eq(s.ax[a],os.ax[b],'unchanged non-CRT atlas X');eq(s.ay[a],os.ay[b],'unchanged non-CRT atlas Y')
   if x<16 and z>=16 then chair=chair+1 end
  end
 end
 if m.detail and m.detail(x,y,z)then
  proxy=proxy+1;ok(a~=nil,'proxy mask never claims an empty cell')
  for _,dx in ipairs({0,1})do for _,dz in ipairs({0,1})do
   local u,yy,v=localPoint({x+dx,y,z+dz})
   ok(u>=-1e-8 and u<=n+1e-8 and v>=-1e-8 and v<=n+1e-8,'all four proxy cell corners lie inside the real case; no exposed desk slivers are culled')
   ok(yy>=0 and yy<height,'proxy stays inside case height')
  end end
 end
end end end
eq(chair,196,'all accepted integrated chair voxels and source colors unchanged');ok(unchanged>4000,'desk/keyboard/notes/cable preservation is exercised')
ok(proxy>100,'actual angled CRT has a culling proxy')
local faces=assert(m.surfaces,'planar case surfaces required');ok(#faces>0,'actual display has planar faces')
local allowed={};for _,xy in pairs(p.case)do if type(xy)=='table'then local i=xy[2]*s.W+xy[1];allowed[i]=true;ok(s.inside[i],'all case donors come from original computer art')end end
local function solid(u,y,v)
 return u>0 and u<n and v>0 and v<n and y>0 and y<height
  and not(u>1 and u<n-1 and y>2 and y<height-1 and v<.3)
end
local function k(v)return ('%.7f,%.7f,%.7f'):format(v[1],v[2],v[3])end
local edges={};local screens=0
for _,q in ipairs(faces)do
 ok(allowed[q.source],'planar surfaces use only approved original computer donors')
 local centroid={0,0,0}
 for j=1,4 do for a=1,3 do local v=q[j][a];ok(type(v)=='number'and v==v and math.abs(v)<1e6,'finite case corner');centroid[a]=centroid[a]+v/4 end end
 local a,b,c=q[1],q[2],q[3]
 local ab={b[1]-a[1],b[2]-a[2],b[3]-a[3]};local ac={c[1]-a[1],c[2]-a[2],c[3]-a[3]}
 local normal={ab[2]*ac[3]-ab[3]*ac[2],ab[3]*ac[1]-ab[1]*ac[3],ab[1]*ac[2]-ab[2]*ac[1]}
 local length=math.sqrt(normal[1]^2+normal[2]^2+normal[3]^2);ok(length>1e-8,'no degenerate case triangle')
 local dot=0;for a=1,3 do dot=dot+normal[a]*(q[4][a]-q[1][a])end;near(dot,0,'all four corners remain planar')
 local ahead,behind={},{}
 for a=1,3 do ahead[a]=centroid[a]+normal[a]/length*.001;behind[a]=centroid[a]-normal[a]/length*.001 end
 ok(not solid(localPoint(ahead)),'front winding points out of the case, including into the display recess '..k(centroid)..' normal '..k(normal))
 ok(solid(localPoint(behind)),'back winding points into solid casing, not into the room')
 local u,y,v=localPoint(centroid)
 if u>1 and u<n-1 and y>2 and y<height-1 and v<.5 then
  if math.abs(v-.3)<1e-8 then screens=screens+1 end
 end
 for j=1,4 do
  local a,b=q[j],q[j%4+1];local ka,kb=k(a),k(b);local edge=ka<kb and ka..'|'..kb or kb..'|'..ka
  local e=edges[edge]or{n=0,balance=0,a=a,b=b};e.n=e.n+1;e.balance=e.balance+(ka<kb and 1 or -1);edges[edge]=e
 end
end
ok(screens>=8,'readable screen uses one common plane instead of vertical voxel ribs')
for _,e in pairs(edges)do
 if e.n==1 then near(e.a[2],base,'only underside boundary may be open');near(e.b[2],base,'open boundary sits flush on solid desk')
 else eq(e.n,2,'case/recess shell has no duplicated or nonmanifold edge');eq(e.balance,0,'adjacent faces have opposite edge winding')end
end
local q=emit(m,s,w,h)
local oldQ=oe(old,os,w,h)
-- Casing may change AO beside its new proxy. Beyond that one-cell
-- neighborhood, compare actual emitted source pixels and interpolated
-- corner shades, independent of harmless greedy-merge boundaries.
local inspect=assert(loadfile('tests/astra_building_contact_test.lua'))('helpers')
local function farFaces(quads,planarCount)
 local out={}
 for j=1,#quads-(planarCount or 0)do
  local f=quads[j];local axis,plane,b0,b1,c0,c1=inspect.face(f)
  local other=({{2,3},{1,3},{1,2}})[axis]
  for b=b0,b1-1 do for c=c0,c1-1 do
   local center={0,0,0};center[axis]=plane;center[other[1]]=b+.5;center[other[2]]=c+.5
   if center[1]<17 or center[2]<6 or center[3]>17 then
    local values={math.floor(inspect.sample(f,axis,b+.5,c+.5,1)*w),math.floor(inspect.sample(f,axis,b+.5,c+.5,2)*h)}
    for _,db in ipairs({0,1})do for _,dc in ipairs({0,1})do values[#values+1]=inspect.sample(f,axis,b+db,c+dc)end end
    local key=axis..':'..plane..':'..b..':'..c
    ok(out[key]==nil,'no duplicate unaffected desk face');out[key]=values
   end
  end end
 end
 return out
end
local prior,current=farFaces(oldQ,0),farFaces(q,#faces);local retainedFaces=0
for key,values in pairs(prior)do
 local now=current[key];ok(now~=nil,'every emitted face away from the computer remains present')
 for i,v in ipairs(values)do near(now[i],v,'unaffected emitted source pixel and corner contact shade remain exact')end
 retainedFaces=retainedFaces+1
end
for key in pairs(current)do ok(prior[key]~=nil,'no extra emitted face away from the computer')end
ok(retainedFaces>1000,'original desk and chair face/shading preservation is exercised')
local mesh=H.mesh(q);local _,zero=H.triangles(mesh);eq(zero,0,'complete emitted desk has no degenerate triangle')
for _,v in ipairs(mesh.vertices)do for _,a in ipairs(v)do ok(type(a)=='number'and a==a and math.abs(a)<1e6,'complete emitted position/UV/shade is finite')end end
-- Supporting tabletop must remain visible everywhere outside the actual
-- diagonal case. Test several points per edge cell to catch triangular gaps
-- caused by an overly broad cell-center proxy.
local tops={}
for _,f in ipairs(q)do
 if f[1][2]==base and f[2][2]==base and f[3][2]==base and f[4][2]==base then
  local x0,x1,z0,z1=math.huge,-math.huge,math.huge,-math.huge
  for j=1,4 do x0=math.min(x0,f[j][1]);x1=math.max(x1,f[j][1]);z0=math.min(z0,f[j][3]);z1=math.max(z1,f[j][3])end
  tops[#tops+1]={x0,x1,z0,z1}
 end
end
local probes=0
for x=19,30 do for z=3,14 do
 if m.at(x,base-1,z)~=nil and (m.at(x,base,z)==nil or m.detail(x,base,z))then
  for _,dx in ipairs({.125,.5,.875})do for _,dz in ipairs({.125,.5,.875})do
   local u,_,v=localPoint({x+dx,base,z+dz})
   if u<0 or u>n or v<0 or v>n then
    local covered=false;for _,r in ipairs(tops)do if x+dx>=r[1]and x+dx<=r[2]and z+dz>=r[3]and z+dz<=r[4]then covered=true;break end end
    ok(covered,'no supporting desk hole outside the true diagonal case');probes=probes+1
   end
  end end
 end
end end
ok(probes>100,'subpixel desk perimeter probes exercise diagonal edges')
print(('Bill CRT: %d planar faces, %d contained proxy voxels, %d unchanged non-CRT voxels, %d desk-edge probes; complete desk quads %d -> %d'):format(#faces,proxy,unchanged,probes,#oldQ,#q))
print(('%d live computer material/geometry/preservation checks passed'):format(checks))
