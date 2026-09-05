-- Seat artwork must be centered on both axes with a uniform one-cell black
-- rim. Source-specific white padding stays two cells for HOUSE/REDS and one
-- for CLUB; positions, height, and all accepted leg rendering stay intact.
local H=dofile('tests/astra_fixture.lua')
local root=os.getenv('ASTRA_SQUARE_ROOT') or '.'
local baseline=assert(os.getenv('ASTRA_SQUARE_BASELINE'))
local atlases=assert(os.getenv('ASTRA_FURNITURE_ATLASES'))
local checks=0
local function ok(v,msg)checks=checks+1;if not v then error('FAIL '..msg,0)end end
local function eq(a,b,msg)ok(a==b,msg..' (expected '..tostring(b)..', got '..tostring(a)..')')end
local function same(a,b,msg)
 eq(type(a),type(b),msg..' type')
 if type(a)~='table'then eq(a,b,msg);return end
 for k,v in pairs(a)do same(v,b[k],msg..'.'..tostring(k))end
 for k in pairs(b)do ok(a[k]~=nil,msg..' no extra field '..tostring(k))end
end
local function color(data,sp,i)
 local r,g,b,a=data:getPixel(sp.ax[i],sp.ay[i])
 return table.concat({r,g,b,a},',')
end
local function legFaces(quads)
 local out={}
 for _,q in ipairs(quads)do
  local lo,hi=math.huge,-math.huge
  for i=1,4 do lo=math.min(lo,q[i][2]);hi=math.max(hi,q[i][2])end
  -- A seat underside lies wholly at y4. The faces strictly below that
  -- plane are the accepted posts, including their four-pixel-tall sides.
  if lo<4 and hi<=4 then out[#out+1]=q end
 end
 return out
end
for _,f in ipairs({{'HOUSE','house_stool','house',2,22},
 {'REDS_HOUSE_1','house_stool','reds_house',2,22},
 {'INTERIOR','club_stool','interior',1,26}})do
 local name=f[1]..'/'..f[2]
 local data,w,h=H.atlas(atlases..'/'..f[3]..'.rgba')
 local oldEmit,old,osp=H.building(baseline,f[2],data,w,h,nil,true,f[1])
 local emit,m,sp=H.building(root,f[2],data,w,h,nil,true,f[1])
 eq(m.ytop+1,5,name..' unchanged seating height')
 eq(m.W,old.W,name..' model width');eq(m.zmin,old.zmin,name..' model rear bound');eq(m.zmax,old.zmax,name..' model front bound')
 local palette={}
 for i=0,osp.W*osp.H-1 do if osp.inside[i]then palette[color(data,osp,i)]=true end end
 local occupied,legs,changed=0,0,0
 local seat={minX=math.huge,maxX=-math.huge,minZ=math.huge,maxZ=-math.huge}
 local gray={minX=math.huge,maxX=-math.huge,minZ=math.huge,maxZ=-math.huge,n=0}
 local counts={[0]=0,[1]=0,[3]=0}
 for y=0,m.ytop do for z=m.zmin,m.zmax do for x=0,m.W-1 do
  local i,j=m.at(x,y,z),old.at(x,y,z)
  eq(i~=nil,j~=nil,name..' every occupied position unchanged')
  if i~=nil then
   occupied=occupied+1
   if y<4 then
    legs=legs+1;eq(i,j,name..' leg source texel unchanged')
    eq(sp.ax[i],osp.ax[j],name..' leg atlas X');eq(sp.ay[i],osp.ay[j],name..' leg atlas Y')
   else
    local c=sp.col[i]
    ok(c==0 or c==1 or c==3,name..' seat uses original white/grey/black palette')
    ok(sp.inside[i] and palette[color(data,sp,i)],name..' seat color comes from its original inside artwork')
    counts[c]=counts[c]+1
    seat.minX=math.min(seat.minX,x);seat.maxX=math.max(seat.maxX,x)
    seat.minZ=math.min(seat.minZ,z);seat.maxZ=math.max(seat.maxZ,z)
    if c==1 then
     gray.n=gray.n+1;gray.minX=math.min(gray.minX,x);gray.maxX=math.max(gray.maxX,x)
     gray.minZ=math.min(gray.minZ,z);gray.maxZ=math.max(gray.maxZ,z)
    end
    if color(data,sp,i)==color(data,osp,j)then
     eq(i,j,name..' unchanged colors keep their existing UV source')
     eq(sp.ax[i],osp.ax[j],name..' unchanged-color atlas X');eq(sp.ay[i],osp.ay[j],name..' unchanged-color atlas Y')
    else changed=changed+1 end
   end
  end
 end end end
 eq(occupied,196,name..' same total occupied volume')
 eq(legs,64,name..' all accepted leg voxels checked')
 eq(changed,f[5],name..' only necessary source-color remaps')
 eq(seat.minX,2,name..' original seat west bound');eq(seat.maxX,13,name..' original seat east bound')
 eq(seat.minZ,3,name..' original seat rear bound');eq(seat.maxZ,13,name..' original seat front bound')
 local sx,sz=seat.minX+seat.maxX,seat.minZ+seat.maxZ
 for z=seat.minZ,seat.maxZ do for x=seat.minX,seat.maxX do
  local i=m.at(x,4,z)
  ok(i~=nil,name..' full closed seat surface')
  eq(color(data,sp,i),color(data,sp,m.at(sx-x,4,z)),name..' exact palette symmetry on X')
  eq(color(data,sp,i),color(data,sp,m.at(x,4,sz-z)),name..' exact palette symmetry on Z')
  local perimeter=x==seat.minX or x==seat.maxX or z==seat.minZ or z==seat.maxZ
  eq(sp.col[i]==3,perimeter,name..' black rim exactly one cell wide on every edge')
  if not perimeter then
   local inGray=x>=gray.minX and x<=gray.maxX and z>=gray.minZ and z<=gray.maxZ
   eq(sp.col[i],inGray and 1 or 0,name..' solid gray rectangle surrounded by white padding')
  end
 end end
 eq(gray.minX+gray.maxX,sx,name..' gray field centered on X')
 eq(gray.minZ+gray.maxZ,sz,name..' gray field centered on Z')
 local pad=f[4]
 eq(gray.minX-seat.minX-1,pad,name..' west white margin')
 eq(seat.maxX-gray.maxX-1,pad,name..' east white margin')
 eq(gray.minZ-seat.minZ-1,pad,name..' rear white margin')
 eq(seat.maxZ-gray.maxZ-1,pad,name..' front white margin')
 eq(gray.n,(gray.maxX-gray.minX+1)*(gray.maxZ-gray.minZ+1),name..' gray center has no holes')
 eq(counts[3],42,name..' uniform black border cell count')
 eq(counts[1],pad==2 and 30 or 56,name..' centered gray area')
 eq(counts[0],pad==2 and 60 or 34,name..' even white padding area')
 local a,b=emit(m,sp,w,h),oldEmit(old,osp,w,h)
 same(legFaces(a),legFaces(b),name..' every emitted leg corner/UV/shade unchanged')
 print(('%s: black rim1, white margin%d, centered grey%d×%d; %d source colors remapped; all64 legs unchanged; quads%d→%d'):format(
  name,pad,gray.maxX-gray.minX+1,gray.maxZ-gray.minZ+1,changed,#b,#a))
end
print(('%d centered-seat checks passed'):format(checks))
