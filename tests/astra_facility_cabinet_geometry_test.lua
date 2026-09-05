-- Full FACILITY cabinet: its base must not stand in front of its own panel.
local root=os.getenv('ASTRA_CANDIDATE')or'.';local baseline=assert(os.getenv('ASTRA_PUBLIC_BASELINE'))
local T=dofile('tests/astra_stair_fixture.lua');local H,F=T.H,T.F
local inspect=assert(loadfile('tests/astra_building_contact_test.lua'))('helpers')
local data,w,h=H.atlas(assert(os.getenv('ASTRA_FACILITY_ATLAS')))
local n=0;local function ok(v,s)n=n+1;assert(v,s)end
local function eq(a,b,s)ok(a==b,s..' expected '..tostring(b)..', got '..tostring(a))end
local b=T.runtime(baseline,data);local cv=b.module('CommunityVisuals')
for _,s in ipairs({'customCourtyards','customPillars','customTrees','customWalls'})do cv[s]=function()return false end end;b.module('BuildBudget').check=function()end
local old=b.stairs.forMap(F.Map.new(F.maps.POKEMON_MANSION_1F,F.tilesets.FACILITY))
local k=F.key(8,15)
eq(old.shapeAt[k].class,'wall','A18 source base becomes separate front wall')
eq(old.shapeAt[k].h,16,'A18 front wall hides the lower panel');ok(not old.skip[k],'A18 base is rendered independently')
if os.getenv('ASTRA_CABINET_NEGATIVE')then ok(old.skip[k],'complete cabinet must claim its own base');return end
local emit,m,sp=H.building(root,'facility_cabinet',data,w,h,nil,true,'FACILITY');local q=emit(m,sp,w,h)
eq(m.ytop+1,28,'physical height from facade rows4..31');eq(m.W,16,'original cabinet width')
local count=0
for y=0,27 do for z=0,31 do for x=0,15 do
 local i=m.at(x,y,z);local sourceRow=31-y
 local recessed=x>=2 and x<=13 and sourceRow>=8 and sourceRow<=24
 local expected=z>=16 and not(z==31 and recessed)
 eq(i~=nil,expected,'one solid cabinet with only original panel recess')
 if i then
  count=count+1;ok(sp.inside[i],'cabinet samples only its own enclosed drawing')
  if y<27 and z<31 and not(z==30 and recessed)then eq(i,4*16+1,'rear and sides carry plain original case material')end
 end
end end end
eq(count,6964,'full cabinet body and204 original recessed panel pixels');eq(q.voxels,count,'emitter volume')
-- Every original face row and column remains visible from the front. The old
-- detached plinth no longer covers source rows below the upper shelf.
for sy=4,31 do for x=0,15 do
 local recessed=x>=2 and x<=13 and sy>=8 and sy<=24;local z=recessed and 30 or 31
 eq(m.at(x,31-sy,z),sy*16+x,'front source texel registration')
 eq(m.at(x,31-sy,z+1),nil,'front texel is unobstructed')
end end
for z=16,30 do for x=0,15 do
 eq(m.at(x,27,z),(z==16 and 0 or 16)+x,'top retains source cap and plain lid')
end end
local axes={{2,3},{1,3},{1,2}}
local function fk(a,p,b,c)return a..':'..p..':'..b..':'..c end
local expected={}
for y=0,27 do for z=16,31 do for x=0,15 do local i=m.at(x,y,z)
 if i then for a=1,3 do for _,d in ipairs({-1,1})do local p={x,y,z};local nn={x,y,z};nn[a]=nn[a]+d
  if m.at(unpack(nn))==nil and not(a==2 and d==-1 and y==0)then expected[fk(a,p[a]+(d==1 and 1 or 0),p[axes[a][1]],p[axes[a][2]])]={i,d}end
 end end end
end end end
local seen={}
for _,quad in ipairs(q)do
 local a,p,b0,b1,c0,c1=inspect.face(quad);ok(b1>b0 and c1>c0,'positive face area')
 for axis=1,3 do local lo,hi=math.huge,-math.huge
  for i=1,4 do local v=quad[i][axis];ok(v==v and math.abs(v)<math.huge,'finite vertex');lo=math.min(lo,v);hi=math.max(hi,v)end
  ok(hi-lo<=8,'bounded curve span');ok(lo==hi or math.floor(lo/8)==math.floor((hi-1e-8)/8),'curve lattice boundary')
 end
 local u,v={},{};for i=1,3 do u[i]=quad[2][i]-quad[1][i];v[i]=quad[3][i]-quad[1][i]end
 local normal={u[2]*v[3]-u[3]*v[2],u[3]*v[1]-u[1]*v[3],u[1]*v[2]-u[2]*v[1]}
 for bb=b0,b1-1 do for cc=c0,c1-1 do local key=fk(a,p,bb,cc);local e=expected[key]
  ok(e,'only exposed shell faces');ok(not seen[key],'no duplicate face');seen[key]=true
  ok(normal[a]*e[2]*(a==2 and -1 or 1)>0,'established emitter winding')
  for _,db in ipairs({.25,.75})do for _,dc in ipairs({.25,.75})do
   eq(math.floor(inspect.sample(quad,a,bb+db,cc+dc,1)*w),sp.ax[e[1]],'shell source X')
   eq(math.floor(inspect.sample(quad,a,bb+db,cc+dc,2)*h),sp.ay[e[1]],'shell source Y')
  end end
 end end
end
for key in pairs(expected)do ok(seen[key],'complete exposed cabinet shell')end
print(('%d FACILITY cabinet geometry/source checks passed; %dvoxels, %dquads,28px high; full front unobstructed'):format(n,count,#q))
