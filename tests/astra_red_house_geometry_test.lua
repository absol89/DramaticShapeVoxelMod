-- Original Red/Copycat household source bands become separate surfaces.
local root=os.getenv('ASTRA_CANDIDATE') or '.'
local H=dofile('tests/astra_fixture.lua')
local inspect=assert(loadfile('tests/astra_building_contact_test.lua'))('helpers')
local data,w,h=H.atlas(assert(os.getenv('ASTRA_PALLET_ATLASES'))..'/reds_house.rgba')
local checks=0
local function ok(v,msg)checks=checks+1;if not v then error('FAIL '..msg,0)end end
local function eq(a,b,msg)ok(a==b,msg..' expected '..tostring(b)..' got '..tostring(a))end
local function post(x,z)return((x>=2 and x<=4)or(x>=27 and x<=29))and((z>=2 and z<=4)or(z>=19 and z<=21))end
local cases={{id='reds_pc',n=5840,h=23,q=588},{id='reds_tv',n=1700,h=11},{id='reds_bed',n=3584,h=7,q=204},{id='reds_short_table',n=3152,h=12,q=588}}
for _,c in ipairs(cases)do
 local emit,m,s=H.building(root,c.id,data,w,h,nil,true,'REDS_HOUSE_2')
 eq(m.ytop+1,c.h,c.id..' source-derived/compatible height')
 local count,keys=0,0
 local function expected(x,y,z)
  if x<0 or x>=m.W or y<0 or z<0 or z>m.zmax then return false end
  if c.id=='reds_pc'then
   local wall=y<=15 and z<=7
   local cabinet=y<=11 and z>=16 and not((y==0 or y==8)and(x==0 or x==15))
   local terminal=y>=12 and y<=22 and x>=2 and x<=13 and z>=18 and z<=23
   local recess=y>=16 and y<=21 and x>=4 and x<=11 and z==23
   local keyboard=y==12 and x>=3 and x<=12 and z>=24 and z<=27
   return wall or cabinet or(terminal and not recess)or keyboard
  elseif c.id=='reds_tv'then
   return y<=10 and z>=3 and z<=12 and not(y>=3 and y<=8 and x>=3 and x<=12 and z==12)
  elseif c.id=='reds_bed'then return y<=6
  else
   return(y<=7 and post(x,z))or(y==8 and x>=2 and x<=29 and z>=2 and z<=21)or(y>=9 and y<=11)
  end
 end
 for y=-1,c.h do for z=-1,m.zmax+1 do for x=-1,m.W do
  local i=m.at(x,y,z);eq(i~=nil,not not expected(x,y,z),c.id..' exact shell/recess/overhang occupancy')
  if i then
   count=count+1;local sx,sy=i%s.W,math.floor(i/s.W)
   if c.id=='reds_pc'and z<=7 then
    eq(i,(3-y%4)*16,'only the original background stripe builds the retained back wall')
   else ok(s.inside[i],c.id..' only original furniture donors, never surrounding floor')end
   if c.id=='reds_pc'then
    if z>=24 and y==12 then keys=keys+1;eq(i,(z-7)*16+x,'original keyboard rows17..20 laid flat exactly once')end
    if z>=18 and z<=22 and y>=12 and y<=21 then
     local display=z==22 and x>=4 and x<=11 and y>=16 and y<=21
     eq(i,display and(26-y)*16+x or 19,'only recessed screen wears front art; back/sides use original white casing')
    end
    if y<11 and z>=16 then ok(sy>=20,'cabinet elevation retains its own base/fascia rows')elseif y==11 and z>=16 then ok(s.col[i]==0 or s.col[i]==3,'cabinet lid is plain white with a black boundary, never a repeated screen image')end
   elseif c.id=='reds_tv'then
    if y<=9 and z<=11 then
     local display=z==11 and x>=3 and x<=12 and y>=3 and y<=8
     eq(i,display and(15-y)*16+x or 229,'one source picture, clean dark case on the other sides')
    elseif z==12 then eq(i,(15-y)*16+x,'front frame and original two controls retained')end
   elseif c.id=='reds_bed'then
    if y==6 then
     local row=z==31 and 28 or math.min(math.floor(z*28/31),27)
     eq(i,row*16+x,'only the top-view bed band lies on the lid; front begins at row28')
    else
     ok(sy>=29,'pillows/blanket never repeat onto bed sides')
     if z<31 or y<=2 then eq(s.col[i],2,'original dark frame continues around the bed shell')end
    end
   elseif c.id=='reds_short_table'then
    if y<=7 then eq(i,21*32+3,'four taller posts retain original foot material')end
    if y==8 then eq(i,19*32+15,'thin original apron lies behind the overhang')end
    if y>=9 then
     if y<11 then eq(s.col[i],3,'clean black slab underside and edge')else
      local d=math.min(x,31-x,z,23-z);eq(s.col[i],d==0 and 3 or(d==1 and 0 or 1),'continuous one-pixel white border around the original gray field')
      eq(s.col[i],s.col[m.at(31-x,y,z)],'centered X palette')
      eq(s.col[i],s.col[m.at(x,y,23-z)],'centered Z palette')
     end
    end
    ok(sy<23,'source floor row23 stays floor')
   end
  end
 end end end
 eq(count,c.n,c.id..' bounded voxel count')
 if c.id=='reds_pc'then eq(keys,40,'one forty-pixel horizontal keyboard');eq(m.at(5,20,22),6*16+5,'original PC cursor pixel remains in its original display position')end
 if c.id=='reds_tv'then
  eq(m.at(4,7,11),8*16+4,'original TV picture highlight retained inside front screen')
  local _,a,b=H.building(root,c.id,data,w,h,nil,true,'REDS_HOUSE_1')
  for y=0,10 do for z=0,15 do for x=0,15 do eq(a.at(x,y,z),m.at(x,y,z),'both household tileset copies have exactly identical TV source geometry')end end end
 end
 -- Inspect emitted shell coverage/source after greedy merging and 8px splitting.
 local q=emit(m,s,w,h);eq(q.voxels,count,c.id..' emitted occupancy')
 if c.q then eq(#q,c.q,c.id..' measured renderer cost')end
 local axes={{2,3},{1,3},{1,2}};local faces,seen={},{}
 local function fk(a,p,b,cc)return a..':'..p..':'..b..':'..cc end
 for y=0,c.h-1 do for z=0,m.zmax do for x=0,m.W-1 do local i=m.at(x,y,z)
  if i then for a=1,3 do for _,d in ipairs({-1,1})do local n={x,y,z};n[a]=n[a]+d
   if m.at(unpack(n))==nil and not(a==2 and d==-1 and y==0)then local p={x,y,z};faces[fk(a,p[a]+(d==1 and 1 or 0),p[axes[a][1]],p[axes[a][2]])]={i,d}end
  end end end
 end end end
 for _,face in ipairs(q)do
  for n=1,4 do for a=1,3 do local v=face[n][a];ok(type(v)=='number'and v==v and math.abs(v)<1e6,'finite furniture geometry')end end
  local a,p,b0,b1,c0,c1=inspect.face(face);ok(b1>b0 and c1>c0,'nonzero shell area')
  local u,v={},{};for n=1,3 do u[n]=face[2][n]-face[1][n];v[n]=face[3][n]-face[1][n]end
  local normal={u[2]*v[3]-u[3]*v[2],u[3]*v[1]-u[1]*v[3],u[1]*v[2]-u[2]*v[1]}
  for b=b0,b1-1 do for cc=c0,c1-1 do local k=fk(a,p,b,cc);local e=faces[k]
   ok(e~=nil,'emitted face belongs to exposed source-backed shell');ok(not seen[k],'no duplicate shell face');seen[k]=true
   ok(normal[a]*e[2]*(a==2 and -1 or 1)>0,'shared winding convention retained')
   for _,d in ipairs({.25,.75})do eq(math.floor(inspect.sample(face,a,b+d,cc+d,1)*w),s.ax[e[1]],'exact emitted source U');eq(math.floor(inspect.sample(face,a,b+d,cc+d,2)*h),s.ay[e[1]],'exact emitted source V')end
  end end
 end
 for k in pairs(faces)do ok(seen[k],'no missing exposed shell face')end
 print(c.id..': '..count..' voxels, '..#q..' quads, height '..c.h)
end
print(checks..' Red household geometry/source/exposed-shell checks passed')
