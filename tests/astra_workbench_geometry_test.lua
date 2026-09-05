-- Whole workbench source ownership, centered stool and established heights.
local root=os.getenv('ASTRA_CANDIDATE')or'.'
local baseline=assert(os.getenv('ASTRA_PUBLIC_BASELINE'))
local atlas=assert(os.getenv('ASTRA_FULL_ATLASES'))
local H=dofile('tests/astra_fixture.lua');local F=dofile('tests/astra_scene_fixture.lua')
local n=0
local function ok(v,m)n=n+1;assert(v,m)end
local function same(a,b,m)
 ok(type(a)==type(b),m..' type');if type(a)~='table'then ok(a==b,m);return end
 for k,v in pairs(a)do same(v,b[k],m)end;for k in pairs(b)do ok(a[k]~=nil,m..' extra key')end
end
local function stool(x,y,z)
 local top=y>=6 and y<=7 and x>=2 and x<=13 and z>=18 and z<=29
 local legs=y>=0 and y<=5 and((x>=3 and x<=4)or(x>=11 and x<=12))and((z>=19 and z<=20)or(z>=27 and z<=28))
 return top or legs
end
local function desk(x,y,z)
 if z<0 or z>15 or x<0 or x>31 or y<0 or y>11 then return false end
 return y>=9 or(y==8 and x>=2 and x<=29 and z>=2 and z<=13)
 or(x>=19 and x<=29 and z>=2 and z<=13)
 or(x>=2 and x<=4 and((z>=2 and z<=4)or(z>=11 and z<=13)))
end
local cases={{'LAB','lab_workbench',4101,19},{'LAB','warden_workbench',3619,16},{'MANSION','mansion_workbench',4101,19}}
for _,c in ipairs(cases)do
 local data,w,h=H.atlas(atlas..'/'..c[1]:lower()..'.rgba')
 local emit,m,s=H.building(root,c[2],data,w,h,nil,true,c[1])
 ok(m.ytop+1==c[4],'source equipment height');local count=0
 for y=0,m.ytop do for z=0,31 do for x=0,31 do
  local i=m.at(x,y,z)
  if y<=11 then ok((i~=nil)==not not(desk(x,y,z)or stool(x,y,z)),'exact occupied desk/seat bounds; open knee and foot spaces')end
  if i then
   count=count+1;ok(s.inside[i],'every material belongs to the original furniture')
   local sx,sy=i%32,math.floor(i/32)
   ok(sy<22 or(sx>=4 and sx<=15 and sy>=24),'surrounding floor and source apron/chair overlap never become body materials')
   if z>=16 then
    ok(stool(x,y,z),'separate centered seat is the only forward object')
    ok(sx>=4 and sx<=15 and sy>=24,'seat uses only original chair materials')
    same(s.col[i],s.col[m.at(15-x,y,z)],'seat exact X material symmetry')
    same(s.col[i],s.col[m.at(x,y,47-z)],'seat exact Z material symmetry')
    if y==7 then local d=math.min(x-2,13-x,z-18,29-z);ok(s.col[i]==(d==0 and 3 or(d<3 and 0 or 1)),'even black rim, white margins and centered cushion')end
   elseif y==11 then
    local isRound=c[2]=='warden_workbench'and sy>=8 and sy<=15 and sx>=16 and sx<=22
    if not isRound then
     local d=math.min(x,31-x,z,15-z);ok(s.col[i]==(d==0 and 3 or(d==1 and 0 or 1)),'even desk border and plain source field')
    end
   end
  end
 end end end
 ok(count==c[3],'bounded model cost')
 local quads=emit(m,s,w,h);ok(quads.voxels==count,'actual emitter consumes the model')
 for _,q in ipairs(quads)do for j=1,4 do for a=1,3 do ok(q[j][a]==q[j][a]and math.abs(q[j][a])<100,'finite bounded emitted geometry')end end end
 if c[2]~='warden_workbench'then
  ok(#m.surfaces==220,'complete accepted planar CRT shell')
  for _,q in ipairs(m.surfaces)do for j=1,4 do ok(q[j][2]>=12 and q[j][2]<=19,'CRT stands on12px desktop')end end
  ok(m.at(24,11,9)~=nil and m.at(24,12,9)~=nil,'CRT support and shell meet')
 end
 print(c[2]..': '..count..' voxels; '..#quads..' quads; complete separate desk and stool')
end
-- The rise option must leave every accepted complete model unchanged.
for family,file in pairs({LAB='lab',MANSION='mansion',INTERIOR='interior',DOJO='gym',REDS_HOUSE_1='reds_house',REDS_HOUSE_2='reds_house'})do
 local data,w,h=H.atlas(assert(os.getenv('ASTRA_FURNITURE_ATLASES'),'set ASTRA_FURNITURE_ATLASES')..'/'..file..'.rgba')
 local spec=dofile(baseline..'/data/voxel_heights.lua')
 for _,t in ipairs(spec.buildings[family]or{})do
  local ae,am,as=H.building(root,t.id,data,w,h,nil,true,family)
  local be,bm,bs=H.building(baseline,t.id,data,w,h,nil,true,family)
  same(ae(am,as,w,h),be(bm,bs,w,h),'existing '..family..' '..t.id..' emitted quads/source/shading exact')
 end
end
print(n..' workbench geometry/source and accepted-model preservation checks passed')
