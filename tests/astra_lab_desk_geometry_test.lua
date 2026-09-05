-- One source-aware terminal, keyboard and round motif on a level LAB desk.
local root=os.getenv('ASTRA_LAB_DESK_ROOT')or os.getenv('ASTRA_CANDIDATE')or'.'
local H=dofile('tests/astra_fixture.lua')
local inspect=assert(loadfile('tests/astra_building_contact_test.lua'))('helpers')
local data,w,h=H.atlas(assert(os.getenv('ASTRA_FURNITURE_ATLASES'))..'/lab.rgba')
local emit,m,s=H.building(root,'lab_equipment_desk',data,w,h,nil,true,'LAB')
local checks=0
local function ok(v,msg)checks=checks+1;if not v then error('FAIL '..msg,0)end end
local function eq(a,b,msg)ok(a==b,msg..' expected '..tostring(b)..' got '..tostring(a))end
local function color(i)return s.col[assert(i,'expected occupied source texel')]end
local function ball(x,z)
 local radii={0,1,2,3,3,2,1,0};local r=radii[z-15]
 return r~=nil and x>=19-r and x<=19+r
end
local function post(x,z)
 return((x>=2 and x<=4)or(x>=27 and x<=29))and((z>=2 and z<=4)or(z>=27 and z<=29))
end
local function screen(x,y,z)return x>=10 and x<=13 and y>=13 and y<=14 and z==19 end
local function expected(x,y,z)
 if x<0 or x>31 or z<0 or z>31 or y<0 then return false end
 if y<=8 then return post(x,z)end
 if y<=11 then return true end
 if y==12 and x>=8 and x<=16 and z>=20 and z<=22 then return true end
 return y<=15 and x>=8 and x<=16 and z>=16 and z<=19 and not screen(x,y,z)
end
eq(m.W,32,'original source footprint width');eq(m.zmin,0,'original source footprint north edge');eq(m.zmax,31,'original source footprint south edge')
eq(m.ytop+1,16,'one four-pixel terminal sits on the original twelve-pixel plane')
local count,feet,slab,terminal,keyboard,motif=0,0,0,0,0,0
local layers={};local occupied={}
local function key(x,y,z)return x..','..y..','..z end
for y=-1,17 do for z=-1,32 do for x=-1,32 do
 local i=m.at(x,y,z);eq(i~=nil,not not expected(x,y,z),'exact level desk, four inset supports and one terminal/keyboard volume')
 if i~=nil then
  count=count+1;layers[y]=(layers[y]or 0)+1;occupied[key(x,y,z)]={x,y,z}
  ok(s.inside[i],'every material donor is inside the original desk drawing')
  local sx,sy=i%s.W,math.floor(i/s.W)
  ok(sy<=30,'the original floor row31 never becomes furniture')
  if y<=8 then
   feet=feet+1;ok(sy>=28 and sy<=30,'supports only use original drawn foot rows')
   ok((sx>=2 and sx<=4)or(sx>=27 and sx<=29),'supports only use the actual foot columns')
   ok(m.at(x,y+1,z)~=nil,'each post continuously meets the slab')
  elseif y<=11 then
   slab=slab+1
   if y==11 then
    if ball(x,z)then
     motif=motif+1;eq(i,z*32+x,'the single round motif retains its exact original source texel')
    else
     local distance=math.min(x,31-x,z,31-z)
     eq(color(i),distance==0 and 3 or(distance==1 and 0 or 1),'black outline, equal one-pixel white ring, plain gray field')
     ok(not(sy>=16 and sy<=23 and sx>=8 and sx<=23),'no extra terminal or ball source print remains on the table')
    end
   end
  elseif z>=20 then
   keyboard=keyboard+1;eq(y,12,'keyboard is a single horizontal sheet directly above the desk')
   eq(i,(z+1)*32+x,'keyboard retains only its actual original rows21-23 and gray bar')
  else
   terminal=terminal+1
   if y<15 and z<19 then
    local isDisplay=z==18 and x>=10 and x<=13 and y>=13 and y<=14
    eq(color(i),isDisplay and 2 or 0,'only the recessed front carries the display; rear and body sides use original white casing')
    if isDisplay then eq(i,(32-y)*32+x,'dark display retains its two source rows without invented indicators')end
   elseif z==19 then
    eq(i,(32-y)*32+x,'visible front frame retains the source face-on rows17-20')
   elseif y==15 then
    eq(i,16*32+x,'top retains only the source terminal top border')
   end
  end
 end
end end end
eq(count,3559,'3396 desk voxels plus136 terminal and27 keyboard voxels')
eq(feet,324,'four3x3 posts through nine layers');eq(slab,3072,'three complete32x32 slab layers')
eq(terminal,136,'one9x4x4 terminal with eight recessed front pixels');eq(keyboard,27,'one9x3 keyboard');eq(motif,32,'one source diamond with all surrounding old frame pixels removed')
for y=0,8 do eq(layers[y],36,'no broad rails or solid body beneath the slab')end
for y=9,11 do eq(layers[y],1024,'every slab layer stays complete and level')end
-- Every outward support edge is inset by two cells on each side of all slab layers.
for _,p in ipairs({{2,4,2,4},{27,29,2,4},{2,4,27,29},{27,29,27,29}})do
 for y=9,11 do
  for z=p[3],p[4]do for d=1,2 do ok(m.at(p[1]<16 and p[1]-d or p[2]+d,y,z)~=nil,'equal two-pixel X overhang')end end
  for x=p[1],p[2]do for d=1,2 do ok(m.at(x,y,p[3]<16 and p[3]-d or p[4]+d)~=nil,'equal two-pixel Z overhang')end end
 end
end
local _,seed=next(occupied);local queue={seed};occupied[key(unpack(seed))]=nil;local head=1
local directions={{1,0,0},{-1,0,0},{0,1,0},{0,-1,0},{0,0,1},{0,0,-1}}
while head<=#queue do
 local p=queue[head];head=head+1
 for _,d in ipairs(directions)do local k=key(p[1]+d[1],p[2]+d[2],p[3]+d[3]);if occupied[k]then queue[#queue+1]=occupied[k];occupied[k]=nil end end
end
eq(#queue,count,'feet, slab, terminal and keyboard are one connected structure')
-- Check the actual greedy shell, including the recessed screen and its UVs.
local q=emit(m,s,w,h);eq(q.voxels,count,'emitted occupancy agrees with the independently checked volume');eq(#q,846,'bounded complete desk render cost')
local axes={{2,3},{1,3},{1,2}}
local function faceKey(a,p,b,c)return a..':'..p..':'..b..':'..c end
local faces={}
for y=0,15 do for z=0,31 do for x=0,31 do local i=m.at(x,y,z)
 if i then for a=1,3 do for _,d in ipairs({-1,1})do
  local n={x,y,z};n[a]=n[a]+d
  if m.at(unpack(n))==nil and not(a==2 and d==-1 and y==0)then
   local p={x,y,z};faces[faceKey(a,p[a]+(d==1 and 1 or 0),p[axes[a][1]],p[axes[a][2]])]={i,d}
  end
 end end end
end end end
local seen={}
for _,face in ipairs(q)do
 for n=1,4 do for a=1,3 do local v=face[n][a];ok(type(v)=='number'and v==v and math.abs(v)<1e6,'finite geometry')end end
 local a,p,b0,b1,c0,c1=inspect.face(face);ok(b1>b0 and c1>c0,'positive exposed face area')
 local u,v={},{};for n=1,3 do u[n]=face[2][n]-face[1][n];v[n]=face[3][n]-face[1][n]end
 local normal={u[2]*v[3]-u[3]*v[2],u[3]*v[1]-u[1]*v[3],u[1]*v[2]-u[2]*v[1]}
 for b=b0,b1-1 do for c=c0,c1-1 do
  local k=faceKey(a,p,b,c);local expectedFace=faces[k];ok(expectedFace~=nil,'every emitted unit face belongs to the exposed desk shell')
  ok(not seen[k],'no duplicate shell face');seen[k]=true
  ok(normal[a]*expectedFace[2]*(a==2 and -1 or 1)>0,'shared voxel winding convention retained')
  for _,d in ipairs({.25,.75})do
   eq(math.floor(inspect.sample(face,a,b+d,c+d,1)*w),s.ax[expectedFace[1]],'visible source atlas X retained after merging')
   eq(math.floor(inspect.sample(face,a,b+d,c+d,2)*h),s.ay[expectedFace[1]],'visible source atlas Y retained after merging')
  end
 end end
end
for k in pairs(faces)do ok(seen[k],'no omitted exposed desk face')end
print(('LAB equipment desk:3559 voxels,846 quads; level support12, one recessed terminal, keyboard and source diamond; %d geometry/source checks passed'):format(checks))
