-- Exact source-map rear material regression. Requires caller-owned OVERWORLD
-- atlas; no original game artwork is included in this checkout.
local root=os.getenv('ASTRA_CANDIDATE') or '.'
local base=assert(os.getenv('ASTRA_FOLLOWUP_BASELINE'),'ASTRA_FOLLOWUP_BASELINE required')
local atlas=assert(os.getenv('ASTRA_ENTRANCE_ATLASES'),'ASTRA_ENTRANCE_ATLASES required')
local H=dofile(root..'/tests/astra_fixture.lua')
local inspect=assert(loadfile(root..'/tests/astra_building_contact_test.lua'))('helpers')
local data,w,h=H.atlas(atlas..'/overworld.rgba')
local spec=dofile(root..'/data/voxel_heights.lua')
local n=0;local function ok(v,m)n=n+1;assert(v,m)end
local function eq(a,b,m)ok(a==b,m..': '..tostring(a)..' ~= '..tostring(b))end
local allowed={[11]={10,75},[12]={10,75},[27]=26,[28]=26,[47]=34,[63]=34,[66]=75,[67]=75,[68]=75,[69]=75,[74]=26}
local function donor(row,col)
 local d=allowed[row[col]]
 if type(d)~='table'then return d end
 for offset=1,#row do
  for _,c in ipairs({col-offset,col+offset})do
   for _,t in ipairs(d)do if row[c]==t then return t end end
  end
 end
 return d[1]
end
local function direction(q,a)
 local u,v={},{};for j=1,3 do u[j]=q[2][j]-q[1][j];v[j]=q[3][j]-q[1][j]end
 local normal={u[2]*v[3]-u[3]*v[2],u[3]*v[1]-u[1]*v[3],u[1]*v[2]-u[2]*v[1]}
 return normal[a]>0 and 1 or -1
end
local function key(a,d,p,b,c)return table.concat({a,d,p,b,c},':')end
local function sample(q,a,b,c)
 return math.floor(inspect.sample(q,a,b,c,1)*w),math.floor(inspect.sample(q,a,b,c,2)*h),inspect.sample(q,a,b,c)
end
local families,changedTotal,facesTotal=0,0,0
for _,t in ipairs(spec.buildings.OVERWORLD)do
 if spec.building_back_templates.OVERWORLD[t.id] then
  families=families+1
  local emit,m,s=H.building(root,t.id,data,w,h,nil,true)
  local oldEmit,om,os=H.building(base,t.id,data,w,h,nil,true)
  for _,field in ipairs({'W','ytop','zmin','zmax'})do eq(m[field],om[field],t.id..' model bounds '..field)end
  local rows={};for _,row in ipairs(t.topRows or{})do rows[#rows+1]=row end;for _,row in ipairs(t.tiles)do rows[#rows+1]=row end
  local volume,materialChanges=0,0
  for y=0,m.ytop do for z=m.zmin,m.zmax do for x=0,m.W-1 do
   local a,b=m.at(x,y,z),om.at(x,y,z)
   eq(a~=nil,b~=nil,t.id..' occupancy')
   if a then
    volume=volume+1
    local original=a%(s.W*s.H);local sy=math.floor(original/s.W);local sx=original%s.W
    local expected=donor(rows[math.floor(sy/8)+1],math.floor(sx/8)+1)
    local ax,ay=s.ax[a],s.ay[a]
    if a>=s.W*s.H then
     eq(z,0,'virtual rear donor restricted to rear voxel layer')
     ok(expected~=nil,'only named door/sign tiles may be remapped')
     eq(ax,expected%16*8+sx%8,'exact donor texel x')
     eq(ay,math.floor(expected/16)*8+sy%8,'exact donor texel y')
    end
    if ax~=os.ax[b] or ay~=os.ay[b]then
     materialChanges=materialChanges+1;eq(z,0,'all material changes at rear')
     ok(expected~=nil,'changed material comes from an allowed donor')
    end
   end
  end end end
  local q,oq=emit(m,s,w,h),oldEmit(om,os,w,h)
  eq(q.voxels,volume,t.id..' emitted volume');eq(q.voxels,oq.voxels,t.id..' baseline volume');eq(q.shell,oq.shell,t.id..' shell count')
  local expected={};local faceCount=0
  for _,face in ipairs(oq)do
   local a,p,b0,b1,c0,c1=inspect.face(face);local d=direction(face,a)
   for b=b0,b1-1 do for c=c0,c1-1 do
    local k=key(a,d,p,b,c);ok(expected[k]==nil,'unique baseline face')
    expected[k]={q=face,a=a,b=b,c=c};faceCount=faceCount+1
   end end
  end
  local changedFaces=0
  for _,face in ipairs(q)do
   local a,p,b0,b1,c0,c1=inspect.face(face);local d=direction(face,a)
   for b=b0,b1-1 do for c=c0,c1-1 do
    local k=key(a,d,p,b,c);local old=expected[k];ok(old~=nil,t.id..' exact exposed location/extent/winding, no duplicate')
    expected[k]=nil
    eq(face.facade==true,old.q.facade==true,'front ownership retained')
    local changed=false
    for _,db in ipairs({.25,.75})do for _,dc in ipairs({.25,.75})do
     local ax,ay,sh=sample(face,a,b+db,c+dc);local bx,by,osh=sample(old.q,a,b+db,c+dc)
     ok(math.abs(sh-osh)<1e-8,'all actual submitted triangle shading unchanged')
     if ax~=bx or ay~=by then
      changed=true
      -- A rear-layer texel also owns its one-pixel cap/side return. These
      -- are part of the rear wall, not a change to roof or front artwork.
      local atRear=(a==3 and d==-1 and p==0)or(a~=3 and c==0)
      ok(atRear and face.facade~=true,'changed texture only on rear wall and its one-pixel returns')
     end
    end end
    if changed then changedFaces=changedFaces+1 end
   end end
  end
  ok(next(expected)==nil,'no missing exposed faces')
  changedTotal=changedTotal+materialChanges;facesTotal=facesTotal+faceCount
  print(string.format('%s: %d voxels / %d faces identical; %d rear texels / %d rear faces updated',t.id,volume,faceCount,materialChanges,changedFaces))
 end
end
 eq(families,29,'all 29 enabled exterior templates exercised')
 ok(changedTotal>0,'new rear-material scope exercised')
print(string.format('PASS rear walls: %d checks; %d templates, %d exact exposed faces, %d rear texel changes. Real atlas; mocked model runtime.',n,families,facesTotal,changedTotal))
