-- A13: only the original metal silhouette becomes a closed octagonal tube.
local root=os.getenv('ASTRA_PIPE_ROOT')or os.getenv('ASTRA_CANDIDATE')or'.'
local H=dofile('tests/astra_fixture.lua')
local data,w,h=H.atlas(assert(os.getenv('ASTRA_FURNITURE_ATLASES'))..'/interior.rgba')
local checks=0
local function ok(v,msg)checks=checks+1;if not v then error('FAIL '..msg,0)end end
local function eq(a,b,msg)ok(a==b,msg..' expected '..tostring(b)..' got '..tostring(a))end
local function near(a,b,msg)ok(type(a)=='number'and math.abs(a-b)<1e-7,msg..' expected '..tostring(b)..' got '..tostring(a))end
local function finite(v)return type(v)=='number'and v==v and math.abs(v)<1e6 end
local function key(v)return ('%.7f,%.7f,%.7f'):format(v[1],v[2],v[3])end
local cases={
 {id='bill_pipe_link',x0=-4,x1=52,collars={{4,7},{41,44}},faces=168,origin=40},
 {id='bill_pipe_left',x0=0,x1=12,collars={{1,4}},faces=72,origin=0},
 {id='bill_pipe_right',x0=-4,x1=8,collars={{4,7}},faces=72,origin=120}}
local total=0
for _,c in ipairs(cases)do
 local emit,m,s=H.building(root,c.id,data,w,h,nil,true,'INTERIOR')
 local faces=assert(m.surfaces,'tube must have real surfaces')
 eq(#faces,c.faces,c.id..' bounded segmented shell cost')
 local function metal(i)
  local x,y=i%s.W,math.floor(i/s.W)
  if y>=3 and y<=11 then return true end
  if y==2 or y==12 then
   local stub=x<8 and x or(x>=s.W-8 and x-(s.W-8)or nil)
   return stub~=nil and stub>=1 and stub<=6
  end
  return false
 end
 local function radius(x)
  for _,r in ipairs(c.collars)do if x>r[1]and x<r[2]then return 5.5 end end
  return 4.5
 end
 local function solid(v)
  local x,y,z=v[1],math.abs(v[2]-8.5),math.abs(v[3]-16)
  local r=radius(x)
  return x>c.x0 and x<c.x1 and y<r and z<r and y+z<math.sqrt(2)*r
 end
 local bounds={math.huge,-math.huge,math.huge,-math.huge,math.huge,-math.huge}
 local edges={};local colors={};local capArea={left=0,right=0};local axial=0
 for _,q in ipairs(faces)do
  ok(s.inside[q.source]and metal(q.source),c.id..' surface donor belongs only to outlined metal, never background/corner dots')
  colors[s.col[q.source]]=true
  local center={0,0,0};local distinct={};local lo,hi=math.huge,-math.huge
  for j=1,4 do
   distinct[key(q[j])]=true
   for a=1,3 do local v=q[j][a];ok(finite(v),'finite tube vertex');center[a]=center[a]+v/4;bounds[a*2-1]=math.min(bounds[a*2-1],v);bounds[a*2]=math.max(bounds[a*2],v)end
   lo=math.min(lo,q[j][1]);hi=math.max(hi,q[j][1])
  end
  local n=0;for _ in pairs(distinct)do n=n+1 end;eq(n,4,'every submitted quad has four distinct vertices')
  ok(hi-lo<=8+1e-8,'every face respects the8px world-curvature axial span')
  if hi-lo>1e-8 then
   eq(math.floor((lo+1e-8)/8),math.floor((hi-1e-8)/8),'no face crosses an internal world X lattice without subdivision');axial=axial+1
  end
  local normal
  for _,tri in ipairs({{1,2,3},{1,3,4}})do
   local a,b,d=q[tri[1]],q[tri[2]],q[tri[3]]
   local u={b[1]-a[1],b[2]-a[2],b[3]-a[3]};local v={d[1]-a[1],d[2]-a[2],d[3]-a[3]}
   local nn={u[2]*v[3]-u[3]*v[2],u[3]*v[1]-u[1]*v[3],u[1]*v[2]-u[2]*v[1]}
   local length=math.sqrt(nn[1]^2+nn[2]^2+nn[3]^2);ok(length>1e-8,'no degenerate tube/collar/endcap triangle')
   if normal then
    ok(nn[1]*normal[1]+nn[2]*normal[2]+nn[3]*normal[3]>0,'both submitted triangles have coherent winding')
   else normal={nn[1]/length,nn[2]/length,nn[3]/length}end
   if lo==hi then
    if math.abs(lo-c.x0)<1e-8 then capArea.left=capArea.left+length/2 end
    if math.abs(lo-c.x1)<1e-8 then capArea.right=capArea.right+length/2 end
   end
  end
  local ahead,behind={},{}
  for a=1,3 do ahead[a]=center[a]+normal[a]*.001;behind[a]=center[a]-normal[a]*.001 end
  ok(not solid(ahead),'face winding points out of the physical tube, collar or endcap')
  ok(solid(behind),'face winding points into solid metal, not across an inverted shoulder')
  local dot=0;for a=1,3 do dot=dot+normal[a]*(q[4][a]-q[1][a])end;near(dot,0,'all four corners are planar')
  ok(finite(q.shade)and q.shade>=.5 and q.shade<=1,'tube shading is finite and bounded')
  for j=1,4 do
   local ka,kb=key(q[j]),key(q[j%4+1]);local k=ka<kb and ka..'|'..kb or kb..'|'..ka
   local e=edges[k]or{0,0};e[1]=e[1]+1;e[2]=e[2]+(ka<kb and 1 or -1);edges[k]=e
  end
 end
 for _,e in pairs(edges)do eq(e[1],2,'closed manifold tube joins/endcaps: every edge shared exactly twice');eq(e[2],0,'neighboring surfaces traverse each shared edge in opposite directions')end
 local wantArea=8*(math.sqrt(2)-1)*4.5^2
 near(capArea.left,wantArea,'left endcap closes the entire octagon exactly once')
 near(capArea.right,wantArea,'right endcap closes the entire octagon exactly once')
 for a,v in ipairs({c.x0,c.x1,3,14,10.5,21.5})do near(bounds[a],v,c.id..' intended physical bounds')end
 for _,i in ipairs({0,1,2,3})do ok(colors[i],c.id..' original metal palette retained')end
 ok(axial>40,'curvature segmentation exercises the actual tube faces')
 for y=0,m.ytop do for z=m.zmin,m.zmax do for x=0,m.W-1 do eq(m.at(x,y,z),nil,'no old wall box or duplicate voxel skin behind the metal')end end end
 local quads=emit(m,s,w,h);eq(#quads,#faces,'standard emitter includes each tube surface once');eq(quads.voxels,0,'surface-only tube introduces no giant wall-volume proxy')
 for j,q in ipairs(quads)do
  for k=1,4 do
   for a=1,3 do near(q[k][a],faces[j][k][a],'standard emitter preserves exact tube coordinates')end
   eq(math.floor(q.uv[k][1]*w),s.ax[faces[j].source],'emitted tube atlas X stays inside original metal donor')
   eq(math.floor(q.uv[k][2]*h),s.ay[faces[j].source],'emitted tube atlas Y stays inside original metal donor')
  end
 end
 -- Front entries start at worldZ39. Every pipe point is behind that
 -- region, even after the deliberate4px X inserts into each chamber.
 ok(bounds[6]+16<39,'tube and collars cannot enter either scripted actor doorway')
 total=total+#quads
 print(('%s: %d closed outward-facing quads, metal-only donors, X[%g,%g], Y[3,14], worldZ[26.5,37.5]'):format(c.id,#quads,c.x0+c.origin,c.x1+c.origin))
end
eq(total,312,'three pipes remain within approved312-quad cost')
print(('%d pipe geometry/material/curvature checks passed'):format(checks))
