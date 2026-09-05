-- The accepted closed black rim must survive seat-art centering. Compare
-- against immutable Astra 7: all occupied positions and leg texels remain
-- unchanged; the emitted shell keeps complete, correctly textured coverage.
local H=dofile('tests/astra_fixture.lua')
local inspect=assert(loadfile('tests/astra_building_contact_test.lua'))('helpers')
local root=os.getenv('ASTRA_SQUARE_ROOT') or '.'
local baseline=assert(os.getenv('ASTRA_SQUARE_BASELINE'))
local atlases=assert(os.getenv('ASTRA_FURNITURE_ATLASES'))
local checks=0
local function ok(v,msg)checks=checks+1;if not v then error('FAIL '..msg,0)end end
local function eq(a,b,msg)ok(a==b,msg..' (expected '..tostring(b)..', got '..tostring(a)..')')end
local axes={{2,3},{1,3},{1,2}}
local function faceKey(a,p,b,c)return a..':'..p..':'..b..':'..c end
local function winding(q,a)
 local u,v={},{}
 for j=1,3 do u[j]=q[2][j]-q[1][j];v[j]=q[3][j]-q[1][j]end
 local n={u[2]*v[3]-u[3]*v[2],u[3]*v[1]-u[1]*v[3],u[1]*v[2]-u[2]*v[1]}
 return n[a]>0 and 1 or -1
end
for _,f in ipairs({{'HOUSE','house_stool','house'},{'REDS_HOUSE_1','house_stool','reds_house'},{'INTERIOR','club_stool','interior'}})do
 local name=f[1]..'/'..f[2]
 local data,w,h=H.atlas(atlases..'/'..f[3]..'.rgba')
 local oldEmit,old,oldsp=H.building(baseline,f[2],data,w,h,nil,true,f[1])
 local emit,m,sp=H.building(root,f[2],data,w,h,nil,true,f[1])
 eq(m.ytop+1,5,name..' original seating height')
 eq(m.W,old.W,name..' original width');eq(m.zmin,old.zmin,name..' original rear bound');eq(m.zmax,old.zmax,name..' original front bound')
 local oldLegs=0
 for y=0,m.ytop do for z=m.zmin,m.zmax do for x=0,m.W-1 do
  local i,j=m.at(x,y,z),old.at(x,y,z)
  eq(i~=nil,j~=nil,name..' all accepted geometry retained')
  if i~=nil then
   ok(sp.inside[i],name..' material comes from original inside artwork')
   if y<4 then
    oldLegs=oldLegs+1
    eq(i,j,name..' every leg retains its exact source texel')
    eq(sp.ax[i],oldsp.ax[j],name..' original leg atlas X');eq(sp.ay[i],oldsp.ay[j],name..' original leg atlas Y')
   end
  end
 end end end
 eq(oldLegs,64,name..' all prior leg voxels checked')
 local top=0
 for z=m.zmin,m.zmax do for x=0,m.W-1 do
  local expected=x>=2 and x<=13 and z>=3 and z<=13
  eq(m.at(x,4,z)~=nil,expected,name..' continuous seat rectangle and closed perimeter')
  local i=m.at(x,4,z)
  if i~=nil then
   top=top+1
   if x==2 or x==13 or z==3 or z==13 then
    eq(sp.col[i],3,name..' entire geometric seat perimeter is source black')
   end
  end
 end end
 eq(top,132,name..' completed seat has 132 voxels')
 local before,after=oldEmit(old,oldsp,w,h),emit(m,sp,w,h)
 eq(after.voxels,196,name..' 132 seat plus 64 unchanged leg voxels')
 -- Independently derive all exposed unit faces from occupied neighbors.
 -- This detects both a hole in a new corner and stale internal faces where
 -- the new voxel meets an existing rim strip, regardless of merge choices.
 local expected,faces={},0
 for y=0,m.ytop do for z=m.zmin,m.zmax do for x=0,m.W-1 do
  local i=m.at(x,y,z)
  if i~=nil then for a=1,3 do for _,d in ipairs({-1,1})do
   local p={x,y,z};p[a]=p[a]+d
   if m.at(p[1],p[2],p[3])==nil and not(a==2 and d==-1 and y==0)then
    local o={x,y,z}
    local k=faceKey(a,o[a]+(d==1 and 1 or 0),o[axes[a][1]],o[axes[a][2]])
    ok(expected[k]==nil,name..' unique expected face')
    expected[k]={texel=i,winding=a==2 and -d or d};faces=faces+1
   end
  end end end
 end end end
 local seen={}
 for _,q in ipairs(after)do
  local a,p,b0,b1,c0,c1=inspect.face(q)
  for b=b0,b1-1 do for c=c0,c1-1 do
   local k=faceKey(a,p,b,c);local e=expected[k]
   ok(e~=nil,name..' no internal or stray face')
   ok(not seen[k],name..' no duplicate face');seen[k]=true
   eq(winding(q,a),e.winding,name..' expected face winding')
   for _,db in ipairs({.25,.75})do for _,dc in ipairs({.25,.75})do
    eq(math.floor(inspect.sample(q,a,b+db,c+dc,1)*w),sp.ax[e.texel],name..' exposed face uses original atlas X')
    eq(math.floor(inspect.sample(q,a,b+db,c+dc,2)*h),sp.ay[e.texel],name..' exposed face uses original atlas Y')
   end end
  end end
 end
 for k in pairs(expected)do ok(seen[k],name..' no missing exposed face')end
 print(('%s: closed black rim and all196 occupied positions/64 leg texels retained; %d exposed faces; %d quads'):format(name,faces,#after))
end
print(('%d retained-rim and exposed-face checks passed'):format(checks))
