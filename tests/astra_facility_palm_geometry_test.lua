-- The complete FACILITY palm must preserve its original source registration.
local root=os.getenv('ASTRA_CANDIDATE')or'.'
local baseline=assert(os.getenv('ASTRA_PUBLIC_BASELINE'))
local H=dofile('tests/astra_fixture.lua');local T=dofile('tests/astra_stair_fixture.lua');local F=T.F
local inspect=assert(loadfile('tests/astra_building_contact_test.lua'))('helpers')
local data,w,h=H.atlas(assert(os.getenv('ASTRA_FACILITY_ATLAS')))
local n=0;local function ok(v,s)n=n+1;assert(v,s)end
local function eq(a,b,s)ok(a==b,s..' expected '..tostring(b)..', got '..tostring(a))end
local function coord(x,y,z)return x..','..y..','..z end
local function faceIdentity(q)
 local v={};for i=1,4 do v[i]=coord(unpack(q[i]))end;table.sort(v);return table.concat(v,'|')
end
-- Reproduce the failure through the old public prop pass, not a copied model.
local old=T.runtime(baseline,data);local cv=old.module('CommunityVisuals')
for _,s in ipairs({'customCourtyards','customPillars','customTrees','customWalls'})do cv[s]=function()return false end end
old.module('BuildBudget').check=function()end
local original=old.stairs.buildObject;local oldQuads
old.stairs.buildObject=function(S,map,region,cluster,...)
 local first=#S.objectQuads+1;local result=original(S,map,region,cluster,...)
 if result and cluster.minX==26 and cluster.minY==16 then
  oldQuads={};for i=first,#S.objectQuads do oldQuads[#oldQuads+1]=S.objectQuads[i]end
 end;return result
end
old.stairs.forMap(F.Map.new(F.maps.POKEMON_MANSION_2F,F.tilesets.FACILITY))
local oldSources,oldFaces,duplicates={},{},0
for _,q in ipairs(assert(oldQuads))do
 oldSources[math.floor(q.u*w)..','..math.floor(q.v*h)]=true
 local k=faceIdentity(q);if oldFaces[k]then duplicates=duplicates+1 end;oldFaces[k]=true
end
eq(duplicates,116,'A18 two-palm source-component overlap reproduced')
if os.getenv('ASTRA_PALM_NEGATIVE')then eq(duplicates,0,'complete palm must have no coincident faces');return end
local emit,m,sp=H.building(root,'facility_palm',data,w,h,nil,true,'FACILITY')
local quads=emit(m,sp,w,h)
eq(m.W,16,'same source width');eq(m.ytop+1,31,'one source ground line retains all pot rows')
eq(m.zmin,25.5,'same old pot back');eq(m.zmax+1,30.5,'same old pot front')
local sourceSeen,count={},0
for y=0,30 do for z=25.5,29.5 do for x=0,15 do
 local i=m.at(x,y,z)
 local sx=x;local sy=30-y;local source=sp.ax[sy*16+sx]..','..sp.ay[sy*16+sx]
 eq(i~=nil,oldSources[source]==true,'exact original source silhouette')
 if i then
  count=count+1;eq(i,sy*16+sx,'every donor keeps its source row and column')
  ok(sp.inside[i],'no newly sampled floor pixel');sourceSeen[source]=true
 end
end end end
eq(count,1350,'270 original source pixels retain five-pixel depth');eq(quads.voxels,count,'emitter voxel coverage')
for s in pairs(oldSources)do ok(sourceSeen[s],'all old source colours retained')end
for _,p in ipairs({{-1,0,25.5},{16,0,25.5},{0,-1,25.5},{0,31,25.5},{0,0,25},{0,0,30}})do eq(m.at(unpack(p)),nil,'bounded model lookup')end
local axes={{2,3},{1,3},{1,2}}
local function faceKey(a,p,b,c)return a..':'..p..':'..b..':'..c end
local expected={}
for y=0,30 do for z=25.5,29.5 do for x=0,15 do local i=m.at(x,y,z)
 if i then for a=1,3 do for _,d in ipairs({-1,1})do local p={x,y,z};local nn={x,y,z};nn[a]=nn[a]+d
  if m.at(unpack(nn))==nil and not(a==2 and d==-1 and y==0)then expected[faceKey(a,p[a]+(d==1 and 1 or 0),p[axes[a][1]],p[axes[a][2]])]={i,d}end
 end end end
end end end
local seen={}
for _,q in ipairs(quads)do
 for i=1,4 do for a=1,3 do ok(q[i][a]==q[i][a]and math.abs(q[i][a])<math.huge,'finite vertex')end end
 local a,p,b0,b1,c0,c1=inspect.face(q);ok(b1>b0 and c1>c0,'positive area')
 for axis=1,3 do local lo,hi=math.huge,-math.huge
  for i=1,4 do lo=math.min(lo,q[i][axis]);hi=math.max(hi,q[i][axis])end
  ok(hi-lo<=8,'world curve span is bounded')
  ok(lo==hi or math.floor(lo/8)==math.floor((hi-1e-8)/8),'no unsplit world curve lattice crossing')
 end
 local u,v={},{};for i=1,3 do u[i]=q[2][i]-q[1][i];v[i]=q[3][i]-q[1][i]end
 local normal={u[2]*v[3]-u[3]*v[2],u[3]*v[1]-u[1]*v[3],u[1]*v[2]-u[2]*v[1]}
 for b=b0,b1-1 do for c=c0,c1-1 do local k=faceKey(a,p,b,c);local e=expected[k]
  ok(e,'every emitted unit face is exposed');ok(not seen[k],'no coincident surface');seen[k]=true
  ok(normal[a]*e[2]*(a==2 and -1 or 1)>0,'existing emitter winding')
  for _,db in ipairs({.25,.75})do for _,dc in ipairs({.25,.75})do
   eq(math.floor(inspect.sample(q,a,b+db,c+dc,1)*w),sp.ax[e[1]],'exposed source X')
   eq(math.floor(inspect.sample(q,a,b+db,c+dc,2)*h),sp.ay[e[1]],'exposed source Y')
  end end
 end end
end
for k in pairs(expected)do ok(seen[k],'every expected exposed face is emitted')end
print(('%d FACILITY palm source/shell checks passed; %d voxels, %d quads; A18 overlaps116 -> 0'):format(n,count,#quads))
