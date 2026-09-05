-- A22: source-based mug shells, bedding relief and unchanged room support.
local root=os.getenv('ASTRA_CANDIDATE')or'.'
local baseline=assert(os.getenv('ASTRA_CABIN_BASELINE'))
local H=dofile('tests/astra_fixture.lua');local F=dofile('tests/astra_scene_fixture.lua')
local data,w,h=H.atlas(assert(os.getenv('ASTRA_CABIN_ATLAS')))
local a,b=F.runtime(root),F.runtime(baseline);local n=0
local function ok(v,msg)n=n+1;assert(v,msg)end
local function eq(x,y,msg)ok(x==y,msg..' got '..tostring(x)..' expected '..tostring(y))end
local function same(x,y,msg)
 eq(type(x),type(y),msg)
 if type(x)~='table'then eq(x,y,msg);return end
 for k,v in pairs(x)do same(v,y[k],msg..'.'..tostring(k))end
 for k in pairs(y)do ok(x[k]~=nil,msg..' missing '..tostring(k))end
end
local targets={ship_cabin_table=true,ship_house_table=true,ship_kitchen_table=true,ship_kitchen_counter=true,ship_truncated_table=true,ship_bunk=true}
local models={};local mugs=0
for _,t in ipairs(a.spec.buildings.SHIP)do if targets[t.id]then
 local emit,m,sp=H.building(root,t.id,data,w,h,nil,true,'SHIP')
 local _,old=H.building(baseline,t.id,data,w,h,nil,true,'SHIP')
 local quads=emit(m,sp,w,h);models[#models+1]={t.id,m,sp,quads}
 same(t.tiles,F.template(b,'SHIP',t.id).tiles,'source footprint retained')
 local regions={}
 if t.id=='ship_bunk'then
  eq(m.ytop,9,'pillow and folded blanket have real relief')
  eq(t.support,nil,'bed keeps its original claim metadata')
  ok(m.at(7,9,4),'raised pillow center');eq(m.at(2,9,4),nil,'pillow has a tapered edge')
  ok(m.at(7,8,16),'raised blanket');ok(m.at(7,9,8),'turned blanket edge')
  eq(m.at(7,9,16),nil,'blanket body remains below fold')
  for y=0,6 do for z=0,23 do for x=0,15 do eq(m.at(x,y,z),old.at(x,y,z),'bed frame and drawer exact')end end end
 else
  eq(m.ytop,16,'mug is five voxels above tabletop')
  eq(t.support,nil,'mug does not lift table claim metadata')
  for z,row in ipairs(t.tiles)do for x,tile in ipairs(row)do if tile==26 then
   mugs=mugs+1;local xx,zz=(x-1)*8,(z-1)*8;regions[#regions+1]={xx,zz}
   ok(m.at(xx+2,12,zz+2),'cup has a closed bottom')
   ok(m.at(xx+2,13,zz+2),'coffee well has a recessed floor')
   eq(m.at(xx+2,16,zz+2),nil,'cup opening stays hollow')
   ok(m.at(xx+1,16,zz),'white rim has volume')
   ok(m.at(xx+7,14,zz+2),'handle outer loop')
   eq(m.at(xx+6,14,zz+2),nil,'handle opening is air')
   ok(m.at(xx+6,13,zz+2)and m.at(xx+6,15,zz+2),'handle connects at both ends')
   local donor=m.at(xx,11,zz)
   for dz=0,7 do for dx=0,7 do eq(m.at(xx+dx,11,zz+dz),donor,'printed mug completely removed from tabletop')end end
  end end end
  for y=0,10 do for z=0,t.depthPx-1 do for x=0,m.W-1 do eq(m.at(x,y,z),old.at(x,y,z),'table structure below lid exact')end end end
 end
 for y=0,m.ytop do for z=0,t.depthPx-1 do for x=0,m.W-1 do
  local i=m.at(x,y,z);if i then ok(sp.inside[i],'every material donor belongs to source object')end
 end end end
 print(t.id..': '..#quads..' quads')
end end
ok(mugs>=5,'all five mug-bearing profile families covered')
local inspect=assert(loadfile('tests/astra_building_contact_test.lua'))('helpers')
local axes={{2,3},{1,3},{1,2}}
local function fk(a,p,b,d)return a..':'..p..':'..b..':'..d end
for _,entry in ipairs(models)do local id,m,sp,q=unpack(entry);local expected={};local count=0
 for y=0,m.ytop do for z=m.zmin,m.zmax do for x=0,m.W-1 do local i=m.at(x,y,z)
  if i then count=count+1;ok(sp.inside[i],id..' donor belongs to source artwork')
   for a=1,3 do for _,d in ipairs({-1,1})do local p={x,y,z};local nn={x,y,z};nn[a]=nn[a]+d
    if m.at(unpack(nn))==nil and not(a==2 and d==-1 and y==0)then expected[fk(a,p[a]+(d==1 and 1 or 0),p[axes[a][1]],p[axes[a][2]])]={i,d}end
   end end
  end
 end end end
 eq(q.voxels,count,id..' emitted volume');local seen={}
 for _,quad in ipairs(q)do
  local a,p,b0,b1,c0,c1=inspect.face(quad);ok(b1>b0 and c1>c0,id..' positive area')
  for axis=1,3 do local lo,hi=math.huge,-math.huge
   for j=1,4 do local v=quad[j][axis];ok(v==v and math.abs(v)<math.huge,id..' finite vertices');lo=math.min(lo,v);hi=math.max(hi,v)end
   ok(hi-lo<=8,id..' bounded curved-world span');ok(lo==hi or math.floor(lo/8)==math.floor((hi-1e-8)/8),id..' lattice split')
  end
  local u,v={},{};for j=1,3 do u[j]=quad[2][j]-quad[1][j];v[j]=quad[3][j]-quad[1][j]end
  local normal={u[2]*v[3]-u[3]*v[2],u[3]*v[1]-u[1]*v[3],u[1]*v[2]-u[2]*v[1]}
  for bb=b0,b1-1 do for cc=c0,c1-1 do local k=fk(a,p,bb,cc);local e=expected[k]
   ok(e,id..' only exposed faces');ok(not seen[k],id..' no duplicate skin');seen[k]=true
   ok(normal[a]*e[2]*(a==2 and -1 or 1)>0,id..' established renderer winding')
   eq(math.floor(inspect.sample(quad,a,bb+.5,cc+.5,1)*w),sp.ax[e[1]],id..' emitted source X')
   eq(math.floor(inspect.sample(quad,a,bb+.5,cc+.5,2)*h),sp.ay[e[1]],id..' emitted source Y')
  end end
 end
 for k in pairs(expected)do ok(seen[k],id..' complete exposed shell')end
end

local maps=0
for id,def in pairs(F.maps)do if def.tileset=='SHIP'then
 maps=maps+1;local map=F.Map.new(def,F.tilesets.SHIP)
 local old,new=F.build(b,map,data,w),F.build(a,map,data,w)
 same(new.tileAt,old.tileAt,id..' original source tiles')
 same(new.skip,old.skip,id..' identical occupied footprint')
 same(new.ground,old.ground,id..' identical floor/backfill')
 same(new.shapeAt,old.shapeAt,id..' identical visual support classification')
 for z=0,map.heightCells-1 do for x=0,map.widthCells-1 do
  eq(a.scene.groundAt(map,x,z),b.scene.groundAt(map,x,z),id..' all actor and warp supports unchanged')
 end end
end end
ok(maps>=12,'all SHIP maps covered')
print(n..' cabin-detail geometry/source/support checks passed on '..maps..' SHIP maps')
