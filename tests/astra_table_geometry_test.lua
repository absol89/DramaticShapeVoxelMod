-- Dining-table form is checked from occupied voxels and source colors,
-- independently of the profile primitives used to author it.
local root=os.getenv('ASTRA_TABLE_ROOT') or os.getenv('ASTRA_CANDIDATE') or '.'
local baseline=assert(os.getenv('ASTRA_TABLE_BASELINE'),'ASTRA_TABLE_BASELINE required')
local atlases=assert(os.getenv('ASTRA_FURNITURE_ATLASES'),'ASTRA_FURNITURE_ATLASES required')
local H=dofile('tests/astra_fixture.lua')
local checks=0
local function ok(v,msg)checks=checks+1;if not v then error('FAIL '..msg,0)end end
local function eq(a,b,msg)ok(a==b,msg..' (expected '..tostring(b)..', got '..tostring(a)..')')end
local function key(x,y,z)return x..','..y..','..z end
local dirs={{1,0,0},{-1,0,0},{0,1,0},{0,-1,0},{0,0,1},{0,0,-1}}
local function components(m,plane)
 local cells={}
 for y=plane or 0,plane or m.ytop do for z=m.zmin,m.zmax do for x=0,m.W-1 do
  if m.at(x,y,z)~=nil then cells[key(x,y,z)]={x,y,z}end
 end end end
 local out={}
 while next(cells)do
  local k,p=next(cells);cells[k]=nil;local q={p};local head=1
  local b={minX=p[1],maxX=p[1],minZ=p[3],maxZ=p[3],n=0}
  while head<=#q do
   local v=q[head];head=head+1;b.n=b.n+1
   b.minX=math.min(b.minX,v[1]);b.maxX=math.max(b.maxX,v[1])
   b.minZ=math.min(b.minZ,v[3]);b.maxZ=math.max(b.maxZ,v[3])
   for _,d in ipairs(dirs)do
    local n=key(v[1]+d[1],v[2]+d[2],v[3]+d[3])
    if cells[n]then q[#q+1]=cells[n];cells[n]=nil end
   end
  end
  out[#out+1]=b
 end
 return out
end
local function color(data,sp,i)
 local r,g,b,a=data:getPixel(sp.ax[i],sp.ay[i]);return table.concat({r,g,b,a},',')
end
for _,f in ipairs({{'HOUSE','house_table','house'},
 {'REDS_HOUSE_1','reds_house_table','reds_house'},
 {'MANSION','mansion_long_table','mansion'}})do
 local name=f[1]..'/'..f[2]
 local data,w,h=H.atlas(atlases..'/'..f[3]..'.rgba')
 local oldEmit,old,osp=H.building(baseline,f[2],data,w,h,nil,true,f[1])
 local emit,m,sp=H.building(root,f[2],data,w,h,nil,true,f[1])
 eq(m.ytop+1,6,name..' original tabletop height')
 eq(m.W,old.W,name..' original width');eq(m.zmin,old.zmin,name..' original rear plot');eq(m.zmax,old.zmax,name..' original front plot')
 local z0,z1=m.zmin,m.zmax
 local D=z1-z0+1
 eq(D,32,name..' original two-cell footprint depth')
 local sx,sz=m.W-1,z0+z1
 local palette={}
 for i=0,osp.W*osp.H-1 do if osp.inside[i]then palette[color(data,osp,i)]=true end end
 local originalField=old.at(math.floor(sx/2),old.ytop,math.floor(sz/2))
 eq(osp.col[originalField],1,name..' original tabletop has gray source field')
 local field=color(data,osp,originalField)
 local occupied=0
 for y=0,m.ytop do for z=z0,z1 do for x=0,m.W-1 do
  local i=m.at(x,y,z)
  if i~=nil then
   occupied=occupied+1
   ok(sp.inside[i],name..' material comes from inside source drawing')
   ok(palette[color(data,sp,i)],name..' material retains original source palette')
   if y<5 then ok(m.at(x,y+1,z)~=nil,name..' support joins the slab with no exposed ledge or detached top')end
  end
  eq(i~=nil,m.at(sx-x,y,z)~=nil,name..' every layer mirrored on X')
  eq(i~=nil,m.at(x,y,sz-z)~=nil,name..' every layer mirrored on Z')
  if y>=3 then
   ok(i~=nil,name..' three slab layers retain the full rectangular tabletop')
  elseif y==2 then
   local expected=x>=2 and x<=m.W-3 and z>=z0+2 and z<=z1-2
   eq(i~=nil,expected,name..' complete apron inset evenly from all slab edges')
  end
 end end end
 eq(#components(m),1,name..' complete table connected with no floating pieces')
 for y=0,2 do
  local parts=components(m,y)
  eq(#parts,y==2 and 1 or 4,name..' apron or four separate feet at height '..y)
  local minX,maxX,minZ,maxZ=math.huge,-math.huge,math.huge,-math.huge
  local quadrants={}
  for _,b in ipairs(parts)do
   minX=math.min(minX,b.minX);maxX=math.max(maxX,b.maxX)
   minZ=math.min(minZ,b.minZ);maxZ=math.max(maxZ,b.maxZ)
   eq(b.n,(b.maxX-b.minX+1)*(b.maxZ-b.minZ+1),name..' solid rectangular support, no hollow or clipped legs')
   if y<2 then
    eq(b.maxX-b.minX+1,4,name..' compact four-pixel leg width')
    eq(b.maxZ-b.minZ+1,4,name..' compact four-pixel leg depth')
    local quadrant=((b.minX+b.maxX)<sx and 'west' or 'east')..((b.minZ+b.maxZ)<sz and 'rear' or 'front')
    ok(not quadrants[quadrant],name..' one leg in each corner');quadrants[quadrant]=true
   end
  end
  -- Measure overhang from the rendered support bounds, not a template
  -- field. Check real occupied slab cells beyond every support side.
  eq(minX,2,name..' west overhang two pixels');eq(sx-maxX,2,name..' east overhang two pixels')
  eq(minZ-z0,2,name..' rear overhang two pixels');eq(z1-maxZ,2,name..' front overhang two pixels')
  for slabY=3,5 do
   for z=minZ,maxZ do for d=1,2 do
    ok(m.at(minX-d,slabY,z)~=nil,name..' solid west overhang')
    ok(m.at(maxX+d,slabY,z)~=nil,name..' solid east overhang')
   end end
   for x=minX,maxX do for d=1,2 do
    ok(m.at(x,slabY,minZ-d)~=nil,name..' solid rear overhang')
    ok(m.at(x,slabY,maxZ+d)~=nil,name..' solid front overhang')
   end end
  end
 end
 local counts={[0]=0,[1]=0,[3]=0}
 for z=z0,z1 do for x=0,m.W-1 do
  local i=m.at(x,5,z)
  local inset=math.min(x,sx-x,z-z0,z1-z)
  local expected=inset==0 and 3 or (inset==1 and 0 or 1)
  eq(sp.col[i],expected,name..' closed black outline, one-pixel white ring, gray center')
  counts[sp.col[i]]=counts[sp.col[i]]+1
  eq(color(data,sp,i),color(data,sp,m.at(sx-x,5,z)),name..' tabletop color mirrored on X')
  eq(color(data,sp,i),color(data,sp,m.at(x,5,sz-z)),name..' tabletop color mirrored on Z')
  if inset>=2 then eq(color(data,sp,i),field,name..' interior retains its original field color')end
 end end
 eq(counts[3],2*m.W+2*D-4,name..' one-pixel black outer outline')
 eq(counts[0],2*m.W+2*D-12,name..' equal-width white ring on all four sides')
 eq(counts[1],(m.W-4)*(D-4),name..' centered uniform source field')
 local expectedVolume=3*m.W*D+(m.W-4)*(D-4)+4*4*4*2
 eq(occupied,expectedVolume,name..' exactly three slab layers, apron, and four two-high legs')
 local before,after=oldEmit(old,osp,w,h),emit(m,sp,w,h)
 eq(after.voxels,occupied,name..' emitted occupied volume')
 print(('%s: overhang2 all sides, black1/white1 rim, four4x4 feet; voxels%d -> %d, quads%d -> %d'):format(name,before.voxels,after.voxels,#before,#after))
end
print(('%d dining-table geometry and source-color checks passed'):format(checks))
