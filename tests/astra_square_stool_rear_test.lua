-- Corner-leg regression: four rectangular posts sit strictly inside the
-- completed seat, with true overhang along both outward sides of every post.
-- Seat color centering has separate coverage; every accepted occupied
-- position and the complete inset-post contract remain locked to Astra 7.
local H=dofile('tests/astra_fixture.lua')
local root=os.getenv('ASTRA_SQUARE_ROOT') or '.'
local baseline=assert(os.getenv('ASTRA_SQUARE_BASELINE'))
local atlases=assert(os.getenv('ASTRA_FURNITURE_ATLASES'))
local checks=0
local function ok(v,msg)checks=checks+1;if not v then error('FAIL '..msg,0)end end
local function eq(a,b,msg)ok(a==b,msg..' (expected '..tostring(b)..', got '..tostring(a)..')')end
local function key(x,y,z)return x..','..y..','..z end
local dirs={{1,0,0},{-1,0,0},{0,1,0},{0,-1,0},{0,0,1},{0,0,-1}}
local function components(m,onlyY)
 local cells={}
 for y=onlyY or 0,onlyY or m.ytop do for z=m.zmin,m.zmax do for x=0,m.W-1 do
  if m.at(x,y,z)~=nil then cells[key(x,y,z)]={x,y,z}end
 end end end
 local result={}
 while next(cells)do
  local k,v=next(cells);cells[k]=nil;local queue={v};local head=1
  local b={minX=v[1],maxX=v[1],minZ=v[3],maxZ=v[3],n=0}
  while head<=#queue do
   local p=queue[head];head=head+1;b.n=b.n+1
   b.minX=math.min(b.minX,p[1]);b.maxX=math.max(b.maxX,p[1]);b.minZ=math.min(b.minZ,p[3]);b.maxZ=math.max(b.maxZ,p[3])
   for _,d in ipairs(dirs)do local q=key(p[1]+d[1],p[2]+d[2],p[3]+d[3])
    if cells[q]then queue[#queue+1]=cells[q];cells[q]=nil end
   end
  end
  result[#result+1]=b
 end
 return result
end
for _,f in ipairs({{'HOUSE','house_stool','house'},{'REDS_HOUSE_1','house_stool','reds_house'},{'INTERIOR','club_stool','interior'}})do
 local name=f[1]..'/'..f[2]
 local data,w,h=H.atlas(atlases..'/'..f[3]..'.rgba')
 local oldEmit,old,oldsp=H.building(baseline,f[2],data,w,h,nil,true,f[1])
 local emit,m,sp=H.building(root,f[2],data,w,h,nil,true,f[1])
 eq(m.ytop+1,5,name..' existing seating height')
 eq(m.W,old.W,name..' width');eq(m.zmin,old.zmin,name..' rear footprint');eq(m.zmax,old.zmax,name..' front footprint')
 local top=0
 local seat={minX=math.huge,maxX=-math.huge,minZ=math.huge,maxZ=-math.huge}
 for z=m.zmin,m.zmax do for x=0,m.W-1 do
  local i,j=m.at(x,4,z),old.at(x,4,z)
  eq(i~=nil,j~=nil,name..' accepted seat geometry retained')
  if i then
   top=top+1;ok(sp.inside[i],name..' seat still uses source artwork')
   seat.minX=math.min(seat.minX,x);seat.maxX=math.max(seat.maxX,x)
   seat.minZ=math.min(seat.minZ,z);seat.maxZ=math.max(seat.maxZ,z)
  end
 end end
 eq(top,132,name..' all accepted seat positions retained')
 -- The support geometry must be a complete vertical 2x2 prism at every
 -- height. A rounded-seat mask must not shave it into an L-shaped post.
 -- Check real seat pixels beside each outer face, not just the global
 -- bounding box: that distinction catches legs flush to a rounded corner.
 local centerX=(seat.minX+seat.maxX)/2
 local centerZ=(seat.minZ+seat.maxZ)/2
 for y=0,3 do
  local legs=components(m,y);eq(#legs,4,name..' four separate corner legs at height '..y)
  local quadrants,layerCells={},0
  for _,b in ipairs(legs)do
   eq(b.maxX-b.minX+1,2,name..' rectangular post width')
   eq(b.maxZ-b.minZ+1,2,name..' rectangular post depth')
   eq(b.n,4,name..' no clipped or L-shaped post cells')
   layerCells=layerCells+b.n
   local west=(b.minX+b.maxX)/2<centerX
   local rear=(b.minZ+b.maxZ)/2<centerZ
   local quadrant=(west and 'left' or 'right')..(rear and 'rear' or 'front')
   ok(not quadrants[quadrant],name..' one support per corner');quadrants[quadrant]=true
   local outwardX=west and b.minX-1 or b.maxX+1
   local outwardZ=rear and b.minZ-1 or b.maxZ+1
   for z=b.minZ,b.maxZ do
    ok(m.at(outwardX,4,z)~=nil,name..' actual seat overhang along every outer X edge')
   end
   for x=b.minX,b.maxX do
    ok(m.at(x,4,outwardZ)~=nil,name..' actual seat overhang along every outer Z edge')
    for z=b.minZ,b.maxZ do
     ok(m.at(x,y,z)~=nil,name..' complete rectangular support layer')
     ok(m.at(x,y+1,z)~=nil,name..' vertical post joins seat with no exposed top')
    end
   end
  end
  eq(layerCells,16,name..' exactly sixteen support voxels per level')
  for z=m.zmin,m.zmax do for x=0,m.W-1 do
   eq(m.at(x,y,z)~=nil,m.at(seat.minX+seat.maxX-x,y,z)~=nil,name..' support X placement mirrored')
   eq(m.at(x,y,z)~=nil,m.at(x,y,seat.minZ+seat.maxZ-z)~=nil,name..' support Z placement mirrored')
  end end
 end
 eq(#components(m),1,name..' legs join seat; no detached blocks')
 local occupied=0
 for y=0,m.ytop do for z=m.zmin,m.zmax do for x=0,m.W-1 do
  local i=m.at(x,y,z)
  if i then
   occupied=occupied+1
   ok(sp.inside[i],name..' material comes from source silhouette')
  end
  eq(m.at(x,y,z)~=nil,m.at(15-x,y,z)~=nil,name..' left/right geometry balanced')
 end end end
 local before,after=oldEmit(old,oldsp,w,h),emit(m,sp,w,h)
 eq(after.voxels,occupied,name..' emitted occupancy')
 eq(occupied,196,name..' 132 seat voxels plus sixty-four support voxels')
 eq(after.voxels,before.voxels,name..' occupied volume unchanged')
 print(('%s: four inset 2x2 posts/true seat overhang; voxels%d->%d; quads%d->%d'):format(name,before.voxels,after.voxels,#before,#after))
end
print(('%d inset-corner-leg checks passed'):format(checks))
