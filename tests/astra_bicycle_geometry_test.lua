-- Two source-led bicycle variants: actual hollow wheels and separate depth.
local root=os.getenv('ASTRA_CANDIDATE') or '.'
local H=dofile('tests/astra_fixture.lua')
local data,w,h=H.atlas(assert(os.getenv('ASTRA_BICYCLE_ATLASES'))..'/club.rgba')
local profile=dofile(root..'/data/voxel_heights.lua')
local n=0;local function ok(v,s)n=n+1;assert(v,s)end
local function eq(a,b,s)ok(a==b,s..': expected '..tostring(b)..', got '..tostring(a))end
local function near(a,b,s)ok(math.abs(a-b)<1e-7,s..': expected '..b..', got '..a)end
local function sub(a,b)return{a[1]-b[1],a[2]-b[2],a[3]-b[3]}end
local function dot(a,b)return a[1]*b[1]+a[2]*b[2]+a[3]*b[3]end
local function cross(a,b)return{a[2]*b[3]-a[3]*b[2],a[3]*b[1]-a[1]*b[3],a[1]*b[2]-a[2]*b[1]}end
local function key(p)return('%.7f,%.7f,%.7f'):format(p[1],p[2],p[3])end
local models=0
for _,t in ipairs(profile.buildings.CLUB)do if t.bicycle then
 models=models+1;local wall=t.bicycle=='wall';local zc=wall and 20 or 12
 local emit,m,sp=H.building(root,t.id,data,w,h,nil,true,'CLUB')
 local faces=assert(m.surfaces,'bicycle must use real component surfaces')
 ok(#faces>200 and #faces<2000,'bounded source-scale bicycle surface cost')
 eq(m.variant,t.bicycle,'correct source variant');eq(m.W,24,'original24px silhouette width')
 local donors=wall and {{3,8},{4,13},{4,5},{3,5}} or {{8,4},{3,8},{4,13},{12,4}}
 local allowed={};for i,p in ipairs(donors)do local k=p[2]*24+p[1];allowed[k]=true;eq(sp.col[k],4-i,'actual measured black/dark/gray/white bicycle donor');ok(sp.inside[k],'donor within original bicycle silhouette')end
 local bounds={math.huge,-math.huge,math.huge,-math.huge,math.huge,-math.huge};local touched={}
 for _,q in ipairs(faces)do
  ok(allowed[q.source],'every material comes from genuine bicycle pixels, never floor/wall source')
  ok(type(q.shade)=='number' and q.shade>=.68-1e-8 and q.shade<=1,'bounded finite material lighting')
  local distinct={};local norm
  for j=1,4 do distinct[key(q[j])]=true
   for a=1,3 do local v=q[j][a];ok(type(v)=='number' and v==v and math.abs(v)<100,'finite bounded vertex');bounds[a*2-1]=math.min(bounds[a*2-1],v);bounds[a*2]=math.max(bounds[a*2],v)end
  end
  local count=0;for _ in pairs(distinct)do count=count+1 end;eq(count,4,'four distinct submitted vertices')
  for _,tri in ipairs{{1,2,3},{1,3,4}}do local a,b,c=q[tri[1]],q[tri[2]],q[tri[3]];local v=cross(sub(b,a),sub(c,a));local area=math.sqrt(dot(v,v));ok(area>1e-8,'no degenerate triangle after curvature clipping')
   if norm then ok(dot(norm,v)>0,'coherent winding across quad diagonal')else norm=v end
  end
  near(dot(norm,sub(q[4],q[1])),0,'planar surface after clipping')
  for _,a in ipairs{1,3}do local lo,hi=math.huge,-math.huge;for j=1,4 do lo=math.min(lo,q[j][a]);hi=math.max(hi,q[j][a])end
   ok(hi-lo<=8+1e-8,'world curve face span at most8 pixels')
   if hi-lo>1e-8 then eq(math.floor((lo+1e-8)/8),math.floor((hi-1e-8)/8),'no unsplit X/Z world-curvature boundary')end
  end
 end
 near(bounds[1],0,'left tire at original source boundary');near(bounds[2],24,'right tire at original source boundary');near(bounds[3],0,'both tires meet the floor')
 ok(bounds[4]>15 and bounds[4]<=16,'handlebars retain original source height envelope')
 ok(bounds[6]-bounds[5]>5.4 and bounds[6]-bounds[5]<7,'saddle and handlebars have true width beyond the tire slab')
 ok(bounds[5]>= (wall and 16 or 8),'back of model stays outside wall or in source floor cell');ok(bounds[6]<= (wall and 24 or 16),'front stays inside the agreed display band')
 local groups={};for _,g in ipairs(m.components)do groups[g.name]=g;for j=g.first,g.last do ok(not touched[j],'each face has one component owner');touched[j]=true end end
 for j=1,#faces do ok(touched[j],'every emitted component is accounted for')end
 for _,name in ipairs{'frame','saddle','handlebars','crank_pedals','stand'}do ok(groups[name]~=nil,'separate physical '..name)end
 eq(groups.basket~=nil,wall,'basket belongs only to the original wall source')
 -- Each twelve-sided tire is a closed annulus. Its exact signed volume
 -- and every segmented edge distinguish a real hole from painted disks.
 for _,cx in ipairs{4.5,19.5}do
  local g=assert(groups['tire_'..cx]);local unique,verts,edges={}, {}, {};local volume=0
  local flux={0,0,0};local frontArea,backArea=0,0
  for j=g.first,g.last do local q=faces[j]
   for k=1,4 do local v=q[k];if not unique[key(v)]then unique[key(v)]=true;verts[#verts+1]=v end end
   for _,tri in ipairs{{1,2,3},{1,3,4}}do local a,b,c=q[tri[1]],q[tri[2]],q[tri[3]];local nn=cross(sub(b,a),sub(c,a));volume=volume+dot(a,cross(b,c))/6
    for ax=1,3 do flux[ax]=flux[ax]+nn[ax]/2 end
    local center={(a[1]+b[1]+c[1])/3,(a[2]+b[2]+c[2])/3,(a[3]+b[3]+c[3])/3}
    local radial={center[1]-cx,center[2]-4.5,0}
    local rr=math.sqrt(dot(radial,radial))
    ok(rr>=3.5*math.cos(math.pi/12)-1e-7,'no opaque wheel disk reaches through the inner aperture')
    if math.abs(nn[3])>1e-8 then
     ok(nn[3]*(center[3]-zc)>0,'annular side faces point away from wheel center plane')
     eq(q.source,donors[1][2]*24+donors[1][1],'broad tire sidewalls retain actual BLACK rubber; DARK becomes red/olive in RED++')
     if nn[3]>0 then frontArea=frontArea+nn[3]/2 else backArea=backArea-nn[3]/2 end
    elseif rr>4 then ok(dot(nn,radial)>0,'outer tire skin winds outward');eq(q.source,donors[1][2]*24+donors[1][1],'outer tire tread is source BLACK')else ok(dot(nn,radial)<0,'inner rim skin winds into the open aperture');eq(q.source,donors[3][2]*24+donors[3][1],'inner metal rim retains source GRAY')end
   end
  end
  near(volume,33.6,'closed tire volume equals exact twelve-sided annulus times1.4px width');near(frontArea,24,'one front annular cap');near(backArea,24,'one rear annular cap')
  for ax=1,3 do near(flux[ax],0,'closed tire has zero net area normal')end
  -- Clipping can split a neighbor at a triangle midpoint. Normalize all
  -- collinear edge subdivisions before checking the watertight shell.
  for j=g.first,g.last do local q=faces[j];for k=1,4 do local a,b=q[k],q[k%4+1];local ab=sub(b,a);local len=dot(ab,ab);local splits={{0,a},{1,b}}
   for _,v in ipairs(verts)do local av=sub(v,a);local t0=dot(av,ab)/len
    if t0>1e-7 and t0<1-1e-7 then local distance=sub(av,{ab[1]*t0,ab[2]*t0,ab[3]*t0});if dot(distance,distance)<1e-14 then splits[#splits+1]={t0,v}end end
   end
   table.sort(splits,function(a,b)return a[1]<b[1]end)
   for i=1,#splits-1 do local ka,kb=key(splits[i][2]),key(splits[i+1][2]);if ka~=kb then local ek=ka<kb and ka..'|'..kb or kb..'|'..ka;local e=edges[ek] or {0,0};e[1]=e[1]+1;e[2]=e[2]+(ka<kb and 1 or -1);edges[ek]=e end end
  end end
  for _,e in pairs(edges)do eq(e[1],2,'every tire edge belongs to exactly two faces');eq(e[2],0,'neighbor tire faces traverse their shared edge oppositely')end
 end
 local out=emit(m,sp,w,h);eq(#out,#faces,'standard emitter outputs every bicycle surface exactly once');eq(out.voxels,0,'no legacy solid slab/proxy beneath open wheels')
 for j,q in ipairs(out)do for k=1,4 do
  for a=1,3 do near(q[k][a],faces[j][k][a],'emitted geometry matches measured surfaces')end
  eq(math.floor(q.uv[k][1]*w),sp.ax[faces[j].source],'atlas X uses bicycle donor');eq(math.floor(q.uv[k][2]*h),sp.ay[faces[j].source],'atlas Y uses bicycle donor')
 end end
 print(('%s: %d surface quads, two watertight hollow wheels, genuine source donors, width %.3f'):format(t.id,#faces,bounds[6]-bounds[5]))
end end
eq(models,2,'exactly the floor and wall bicycle variants')
print(('%d bicycle geometry/material/shell checks passed'):format(n))
