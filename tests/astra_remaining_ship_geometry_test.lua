-- Complete ship drawings: source tops once, original fronts, clean casework.
local root=os.getenv('ASTRA_CANDIDATE') or '.'
local baseline=assert(os.getenv('ASTRA_REMAINING_BASELINE'))
local dir=assert(os.getenv('ASTRA_REMAINING_ATLASES'))
local H=dofile('tests/astra_fixture.lua')
local prototype=os.getenv('ASTRA_SHIP_PROFILES')
if prototype then
 local profiles=assert(loadfile(prototype))();local build=H.building
 H.building=function(path,id,data,aw,ah,budget,prepare,family)
  return build(path,id,data,aw,ah,budget,prepare,family,function(spec)
   if path==root then for _,t in ipairs(profiles)do spec.buildings.SHIP[#spec.buildings.SHIP+1]=t end end
  end)
 end
end
local inspect=assert(loadfile('tests/astra_building_contact_test.lua'))('helpers')
local data,w,h=H.atlas(dir..'/ship.rgba')
local n=0
local function ok(v,s)n=n+1;assert(v,s)end
local function eq(a,b,s)ok(a==b,s..' expected '..tostring(b)..', got '..tostring(a))end
local function get(id)
 -- A22 appends mug/bedding layers. Retain this test's exact A20 base-form
 -- assertions on the CURRENT prefix, not a substituted historical model.
 -- astra_cabin_details_test tests the full final mesh and unchanged supports.
 local prefix={ship_cabin_table=9,ship_house_table=10,ship_kitchen_table=10,
   ship_kitchen_counter=2,ship_truncated_table=54,ship_bunk=1}
 local emit,m,sp=H.building(root,id,data,w,h,nil,true,'SHIP',function(spec)
  for _,t in ipairs(spec.buildings.SHIP)do if t.id==id and prefix[id]then
   while #t.parts>prefix[id]do table.remove(t.parts)end
  end end
 end)
 return m,sp,emit(m,sp,w,h)
end
local models={}
local tables={ship_cabin_table={32,24,17},ship_house_table={32,32,25},ship_captain_desk={48,32,25},ship_kitchen_table={32,96,89},ship_truncated_table={32,24,17}}
for id,s in pairs(tables)do
 local m,sp,q=get(id);models[#models+1]={id,m,sp,q};local W,SH,D=unpack(s)
 eq(m.ytop+1,12,id..' retains table support height')
 local count=0
 for z=0,D-1 do for x=0,W-1 do
  local src=z*W+x
  if id=='ship_truncated_table'then src=(z==16 and 0 or z+8)*W+x end
  if z==0 and(x==0 or x==W-1)then src=(id=='ship_truncated_table' and 8 or 0)*W+1 end
  eq(m.at(x,11,z),src,id..' top source occurs once in original position')
 end end
 for y=0,3 do for z=0,D-1 do for x=0,W-1 do
  local foot=(x>=2 and x<=5 or x>=W-6 and x<=W-3)and(z>=2 and z<=5 or z>=D-6 and z<=D-3)
  eq(m.at(x,y,z)~=nil,foot,id..' four complete inset4x4 supports')
 end end end
 -- No motif or cropped floor row may migrate from the top onto a support.
 for y=0,10 do for z=0,D-1 do for x=0,W-1 do local i=m.at(x,y,z)
  if i then
   local sy=math.floor(i/W)
   if id=='ship_truncated_table'then ok(sy<=2,'cropped apron never uses gray source floor rows3..7')
   elseif id=='ship_cabin_table'then ok(sy>=16 and sy<=18,'cabin base never uses floor19..23 or cup art')
   else ok(sy>=SH-8,'drawer and apron never copy tabletop art')end
  end
 end end end
 -- All original drawer rows retain one unblocked front-facing occurrence.
 local spec=dofile(root..'/data/voxel_heights.lua');local t
 for _,v in ipairs(spec.buildings.SHIP)do if v.id==id then t=v end end
 if not t and prototype then for _,v in ipairs(assert(loadfile(prototype))())do if v.id==id then t=v end end end
 for k,tile in ipairs(t.tiles[#t.tiles])do if tile==59 then
  for sy=SH-8,SH-1 do for x=(k-1)*8,(k-1)*8+15 do
   local i=sy*W+x
   if sp.inside[i]then eq(m.at(x,4+SH-1-sy,D-1),i,id..' original drawer face visible')end
  end end
 end end
end
local b,bs,bq=get('ship_bunk');models[#models+1]={'ship_bunk',b,bs,bq}
eq(b.ytop+1,8,'bunk preserves full8-row drawer height')
for sy=24,31 do for x=0,15 do
 local i=sy*16+x;eq(b.at(x,31-sy,23),bs.inside[i]and i or nil,'bunk source drawer visible below mattress')
end end
for z=0,23 do for x=0,15 do
 local expected=(z==23 and 24 or z)*16+x
 if x==0 and z==0 then expected=16;ok(not bs.inside[0],'single missing source corner closes from its own outline')end
 eq(b.at(x,7,z),expected,'bunk pillow and mattress remain horizontal')
end end
for y=0,6 do for z=0,22 do for x=0,15 do local i=b.at(x,y,z)
 if i then eq(i,27*16+1,'bunk side uses plain original dark frame')end
end end end
for _,id in ipairs({'ship_kitchen_counter','ship_kitchen_hob'})do
 local m,sp,q=get(id);models[#models+1]={id,m,sp,q};eq(m.ytop+1,12,id..' retains counter height')
 for y=0,11 do for z=0,31 do for x=0,31 do
  eq(m.at(x,y,z),y==11 and z*32+x or 8*32+2,id..' source art only on horizontal counter')
 end end end
end
local c,cs,cq=get('ship_captain_chair');models[#models+1]={'ship_captain_chair',c,cs,cq}
eq(c.ytop+1,19,'captain original high back is distinct')
for y=0,15 do for z=0,15 do for x=0,15 do
 eq(c.at(x,y,z),z==15 and(15-y)*16 or 0,'wall background uses only unmarked source left edge')
end end end
local chairCount=0
for y=0,18 do for z=16,31 do for x=0,15 do local i=c.at(x,y,z)
 if i then chairCount=chairCount+1;local sy=math.floor(i/16)
  ok(sy>=8,'chair does not sample unrelated upper wall pixels')
  if y<=7 then ok(sy>=19,'seat and foot use their own source bands')end
 end
end end end
eq(chairCount,592,'376-pixel round seat/pedestal plus216-pixel high back')
for sy=9,18 do for x=3,12 do eq(c.at(x,26-sy,19),sy*16+x,'captain back face preserves its original texels')end end
for y=0,7 do for z=18,29 do for x=2,13 do
 local i=c.at(x,y,z);local reflected=c.at(15-x,y,47-z)
 eq(i~=nil,reflected~=nil,'round seat and pedestal remain symmetric')
 if i then eq(cs.col[i],cs.col[reflected],'round seat/pedestal palette symmetry')end
end end end
-- Expanded unit-face coverage catches hidden duplicate skins, holes, wrong
-- UVs and overlong curved-world quads independently of profile structure.
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
local old=H.triangles(H.mesh(H.building(baseline,'ship_stool',data,w,h,nil,false,'SHIP')))
local new=H.triangles(H.mesh(H.building(root,'ship_stool',data,w,h,nil,false,'SHIP')))
eq(#old,#new,'accepted ordinary stool triangle count')
for i,v in ipairs(old)do eq(new[i],v,'accepted ordinary stool exact position UV shade')end
print(('%d remaining ship geometry/source checks passed;9 exact source families; accepted round stool unchanged'):format(n))
