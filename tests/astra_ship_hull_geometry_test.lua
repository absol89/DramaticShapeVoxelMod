-- A21 analytic remaster: real source/mesher, curve-safe facets, open passages,
-- hollow funnels and unchanged A20 boarding/departure/render integration.
local root=os.getenv('ASTRA_CANDIDATE')or'.'
local T=dofile(root..'/tests/astra_ship_hull_fixture.lua');local H=T.H
local r=T.runtime(root)
local data,aw,ah=H.atlas(os.getenv('ASTRA_SHIP_PORT_ATLAS')or'../artifacts/battle-art-astra-remaining-pass/ship-exterior/private/ship_port.rgba')
local n=0;local function ok(v,m)n=n+1;assert(v,m)end
local function eq(a,b,m)ok(a==b,m..': '..tostring(a)..' ~= '..tostring(b))end
local function near(a,b,m)ok(math.abs(a-b)<1e-6,m..': '..tostring(a)..' ~= '..tostring(b))end
local sp=r.read(r.template,data,aw/8)
eq(sp.W,128,'complete original source width');eq(sp.H,48,'complete original source height')
local m=r.ship.model(sp);local q=r.emit(m,sp,aw,ah)
-- Independent border flood. Nonblack wave pixels outside the original black
-- outline are background, regardless of the remaster's authored silhouette.
local outside,queue={},{}
local function add(x,z)
 if x<0 or x>=128 or z<0 or z>=48 then return end
 local i=z*128+x
 if not outside[i] and data:getPixel(sp.ax[i],sp.ay[i])~=0 then outside[i]=true;queue[#queue+1]=i end
end
for x=0,127 do add(x,0);add(x,47)end
for z=0,47 do add(0,z);add(127,z)end
local k=1
while k<=#queue do local i=queue[k];k=k+1;local x,z=i%128,math.floor(i/128);add(x-1,z);add(x+1,z);add(x,z-1);add(x,z+1)end
eq(#queue,866,'original water mask independently measured')
eq(m.W,128,'body footprint width');eq(m.zmin,0,'north body bound');eq(m.zmax,47,'south body voxel bound')
eq(q.voxels,0,'analytic shell has no overlapping voxel skin')
eq(#q,#m.surfaces,'shared emitter retains every authored facet')
ok(#q<4000 and #q<7130,'remaster has fewer faces than accepted A20 ship')
local function sub(a,b)return{a[1]-b[1],a[2]-b[2],a[3]-b[3]}end
local function cross(a,b)return{a[2]*b[3]-a[3]*b[2],a[3]*b[1]-a[1]*b[3],a[1]*b[2]-a[2]*b[1]}end
local function dot(a,b)return a[1]*b[1]+a[2]*b[2]+a[3]*b[3]end
local function normal(a,b,c)return cross(sub(b,a),sub(c,a))end
local allLo,allHi={1e9,1e9,1e9},{-1e9,-1e9,-1e9}
local roles,colors,seen,boxes={},{},{},{}
for j,s in ipairs(m.surfaces)do
 local f=q[j];local lo,hi={1e9,1e9,1e9},{-1e9,-1e9,-1e9}
 local i=s.source;ok(sp.ax[i] and sp.ay[i] and sp.col[i]~=nil,'valid original source donor')
 ok(not outside[i],'no outside-water material on hull')
 local tile=math.floor(sp.ay[i]/8)*16+math.floor(sp.ax[i]/8)
 ok(tile~=20,'never borrow water tile as metal/deck');colors[sp.col[i]]=true
 roles[s.role]=(roles[s.role]or 0)+1
 local keys={}
 for v=1,4 do
  keys[v]=string.format('%.8f,%.8f,%.8f',s[v][1],s[v][2],s[v][3])
  for a=1,3 do
   local x=s[v][a];ok(x==x and math.abs(x)<1e8,'finite surface coordinate')
   near(f[v][a],x,'actual shared emitter preserves source surface')
   lo[a]=math.min(lo[a],x);hi[a]=math.max(hi[a],x)
   allLo[a]=math.min(allLo[a],x);allHi[a]=math.max(allHi[a],x)
  end
  near(f.uv[v][1]*aw,sp.ax[i]+(({.05,.95,.95,.05})[v]),'UV stays in original material texel X')
  near(f.uv[v][2]*ah,sp.ay[i]+(({.95,.95,.05,.05})[v]),'UV stays in original material texel Y')
 end
 near(f.shade,s.shade,'authored directional shade retained');ok(f.shade>=.69-1e-6 and f.shade<=1,'bounded surface shade')
 table.sort(keys);for v=2,4 do ok(keys[v]~=keys[v-1],'four distinct quad vertices')end
 local nn=normal(s[1],s[2],s[3]);local mm=normal(s[1],s[3],s[4])
 local key=table.concat(keys,';');local previous=seen[key]
 -- Consecutive closed rail segments meet with opposite internal endcaps.
 -- They are buried at the join; overlapping outward skin is forbidden.
 if previous then ok(s.role=='rail' and previous.role=='rail' and previous.source==i and dot(previous.normal,nn)<0,'only opposite internal rail endcaps may coincide')end
 seen[key]={role=s.role,source=i,normal=nn}
 ok(dot(nn,nn)>1e-14 and dot(mm,mm)>1e-14,'both rendered triangles nondegenerate')
 ok(dot(nn,mm)>0,'both quad triangles have consistent winding')
 for a=1,3 do
  ok(hi[a]-lo[a]<=8+1e-6,'world-curve facet span at most8')
  if hi[a]-lo[a]>1e-6 then
   eq(math.floor((lo[a]+1e-6)/8),math.floor((hi[a]-1e-6)/8),'no interior world-curve lattice crossing')
  end
 end
 local cx,cz=(lo[1]+hi[1])/2,(lo[3]+hi[3])/2
 if s.role=='hull' then ok(nn[1]*(cx-64)+nn[3]*(cz-24)>0,'hull triangle physically faces outward')end
 if s.role=='cabin' then ok(nn[1]*(cx-74.5)+nn[3]*(cz-24)>0,'windowed cabin faces outward')end
 if s.role=='bridge' then ok(nn[1]*(cx-47)+nn[3]*(cz-24)>0,'bridge faces outward')end
 if s.role=='porthole'or s.role=='porthole-rim'then ok(nn[3]*(cz-24)>0,'porthole faces clear of hull')end
 if s.role=='deck'or s.role=='funnel-rim'or s.role=='funnel-floor'or s.role=='lifeboat-lid'or s.role:match('%-roof$')then ok(nn[2]>0,'horizontal top faces upward')end
 boxes[j]={lo,hi}
end
for i=0,3 do ok(colors[i],'original four-shade ship palette remains represented')end
for _,role in ipairs({'hull','deck','boarding-floor','boarding-back','boarding-jamb','boarding-soffit','rail','rail-post','cabin','bridge','funnel','funnel-rim','funnel-inside','funnel-floor','lifeboat','boat-support','porthole'})do ok(roles[role],'required mechanical feature exists: '..role)end
for a,v in ipairs({0,0,0})do near(allLo[a],v,'original lower footprint bound')end
for a,v in ipairs({128,55,48})do near(allHi[a],v,'authored remaster extent')end
-- Rays use the actual two triangles consumed by the renderer. They prove
-- open space/contact independently of any role or polygon table.
local function triangle(o,d,a,b,c)
 local e1,e2=sub(b,a),sub(c,a);local p=cross(d,e2);local det=dot(e1,p)
 if math.abs(det)<1e-9 then return end
 local inv=1/det;local t=sub(o,a);local u=dot(t,p)*inv
 if u< -1e-7 or u>1+1e-7 then return end
 local w=cross(t,e1);local v=dot(d,w)*inv
 if v< -1e-7 or u+v>1+1e-7 then return end
 local distance=dot(e2,w)*inv;if distance>=-1e-7 then return distance end
end
local function ray(o,d)
 local best,bestRole=math.huge,nil
 for j,s in ipairs(m.surfaces)do
  local b=boxes[j];local candidate=true
  for a=1,3 do if d[a]==0 and(o[a]<b[1][a]-1e-7 or o[a]>b[2][a]+1e-7)then candidate=false;break end end
  if candidate then
   for _,v in ipairs({{1,2,3},{1,3,4}})do
    local hit=triangle(o,d,s[v[1]],s[v[2]],s[v[3]])
    if hit and hit<best then best,bestRole=hit,s.role end
   end
  end
 end
 return best,bestRole
end
-- Actual portal: world x224..240, fixed gangway ends at body z48.
-- Local y2 is world ground0; all16x16 sprite samples fit through the entry.
for x=64.5,79.5 do for y=2.5,17.5 do
 local t,role=ray({x,y,-1},{0,0,1})
 -- Preserve A20's actual six-pixel boarding volume. The authored deeper
 -- recess can taper behind it where the flared hull meets the right jamb.
 ok(t>=7-1e-6,'entire original boarding volume is clear')
 ok(t<=11+1e-6,'boarding recess ends inside the hull')
 if x<79 then near(t,11,'full-width central recess reaches the back wall');eq(role,'boarding-back','center entry ends at dark hatch material')end
end end
for x=64.5,79.5 do for z=.5,9.5 do
 local t,role=ray({x,2.01,z},{0,-1,0});near(t,.01,'continuous boarding contact at world ground0');eq(role,'boarding-floor','gangway connects to threshold floor')
end end
for _,cx in ipairs({70,89})do
 for _,dx in ipairs({-.5,.13,.5})do for _,dz in ipairs({-.5,.17,.5})do
  local t,role=ray({cx+1.5+dx,56,24+dz},{0,-1,0});near(t,7,'funnel mouth is hollow six pixels below lip');eq(role,'funnel-floor','dark recessed funnel bottom')
 end end
 local t,role=ray({cx+1.5+4.3,56,24.1},{0,-1,0});near(t,1,'funnel lip is a real upper rim');eq(role,'funnel-rim','rim does not close the mouth')
end
local gap,gapRole=ray({68,23,-1},{0,0,1});near(gap,13,'open air between rail bars and posts');eq(gapRole,'cabin','rail gap exposes cabin behind')
local bar,barRole=ray({68,24.7,-1},{0,0,1});ok(bar<3,'upper railing is visible before cabin');eq(barRole,'rail','rail is physical narrow geometry')
for _,cx in ipairs({72,97})do
 for _,x in ipairs({cx-4.5,cx+4.5})do
  local floor=ray({x,20.01,40},{0,-1,0});near(floor,.01,'lifeboat cradle contacts level deck')
  local top=ray({x,24.01,40},{0,-1,0});near(top,.01,'lifeboat cradle reaches hull base')
 end
end
-- Only model generation changed; exact-map ownership, movement, cache,
-- departure, shadows and draw code must stay exact against A20 (apart from
-- Git checkout CRLF/LF conversion, which is not a runtime source change).
local baseline=os.getenv('ASTRA_BICYCLE_BASELINE')or'../artifacts/battle-art-astra-bicycles/baseline-mod'
local function integration(path)
 local f=assert(io.open(path..'/lib/ShipHull.lua','rb'));local s=f:read('*a');f:close();s=s:gsub('\r\n','\n')
 local a=assert(s:find('function M.model(sp)',1,true));local b=assert(s:find('local function meshData',a,true))
 return s:sub(1,a-1)..'<MODEL>\n'..s:sub(b)
end
eq(integration(root),integration(baseline),'all non-model ship integration unchanged from A20')
print(n..' ship remaster geometry/source checks passed; '..#q..' analytic quads; open boarding entry, hollow funnels, valid source colors and A20 integration preserved')
