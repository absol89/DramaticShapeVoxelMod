-- Keep the historical computer path in memory for exact cumulative desk checks;
-- astra_computer_case_test.lua covers the live upgraded CRT and retained chair.
-- Bill's integrated chair uses the same lower sprite tiles as the ordinary
-- stool. Its gray field is a horizontal seat at pin height5, not a backrest.
local root=os.getenv('ASTRA_DESK_ROOT') or os.getenv('ASTRA_CANDIDATE') or '.'
local baseline=assert(os.getenv('ASTRA_DESK_BASELINE'),'ASTRA_DESK_BASELINE required')
local H=dofile('tests/astra_fixture.lua')
local data,w,h=H.atlas(assert(os.getenv('ASTRA_FURNITURE_ATLASES'))..'/interior.rgba')
local checks=0
local function ok(v,msg)checks=checks+1;if not v then error('FAIL '..msg,0)end end
local function eq(a,b,msg)ok(a==b,msg..' (expected '..tostring(b)..', got '..tostring(a)..')')end
local function same(a,b,msg)
 eq(type(a),type(b),msg..' type')
 if type(a)~='table'then eq(a,b,msg);return end
 for k,v in pairs(a)do same(v,b[k],msg..'.'..tostring(k))end
 for k in pairs(b)do ok(a[k]~=nil,msg..' no extra field '..tostring(k))end
end
local function chair(x,z)return x>=0 and x<16 and z>=16 and z<32 end
local function color(sp,i)
 local r,g,b,a=data:getPixel(sp.ax[i],sp.ay[i]);return table.concat({r,g,b,a},',')
end
local emit,m,sp=H.building(root,'bills_desk',data,w,h,nil,true,'INTERIOR',H.legacyComputers)
local oldEmit,old,osp=H.building(baseline,'bills_desk',data,w,h,nil,true,'INTERIOR')
eq(m.W,old.W,'unchanged complete desk width');eq(m.zmin,old.zmin,'unchanged rear plot');eq(m.zmax,old.zmax,'unchanged front plot')
eq(m.ytop,old.ytop,'unchanged computer height')
local oldTop,newTop=-1,-1
for y=0,math.max(m.ytop,old.ytop)do for z=16,31 do for x=0,15 do
 if old.at(x,y,z)~=nil then oldTop=math.max(oldTop,y)end
 if m.at(x,y,z)~=nil then newTop=math.max(newTop,y)end
end end end
print(('Integrated chair height: %d -> %d'):format(oldTop+1,newTop+1))
eq(newTop+1,5,'modeled chair seat meets its original five-pixel support pin')
local sourceSeatSamples,chairVoxels,otherVoxels=0,0,0
local seatColors={[0]=0,[1]=0,[3]=0}
for y=0,m.ytop do for z=m.zmin,m.zmax do for x=0,m.W-1 do
 local i,j=m.at(x,y,z),old.at(x,y,z)
 if not chair(x,z)then
  eq(i,j,'every voxel outside the chair keeps its exact source index')
  if i~=nil then
   otherVoxels=otherVoxels+1
   eq(sp.ax[i],osp.ax[j],'original desk/notes/keyboard/cable/computer atlas X')
   eq(sp.ay[i],osp.ay[j],'original desk/notes/keyboard/cable/computer atlas Y')
  end
 elseif i~=nil then
  chairVoxels=chairVoxels+1
  ok(sp.inside[i],'chair material belongs to original source artwork')
  local sourceX,sourceY=i%sp.W,math.floor(i/sp.W)
  ok(sourceX>=2 and sourceX<=13 and sourceY>=20 and sourceY<=31,'chair uses its own source region, not desk or floor donors')
  if sourceY<=26 and (sp.col[i]==0 or sp.col[i]==1)then
   sourceSeatSamples=sourceSeatSamples+1
   eq(y,4,'drawn white/gray cushion field appears only on the horizontal seat')
  end
  if y==4 then
   local d=math.min(x-2,13-x,z-20,30-z)
   local expected=d==0 and 3 or (d==1 and 0 or 1)
   eq(sp.col[i],expected,'even black rim, white margin and centered gray cushion')
   seatColors[sp.col[i]]=seatColors[sp.col[i]]+1
   eq(color(sp,i),color(sp,m.at(15-x,4,z)),'seat colors mirror on X')
   eq(color(sp,i),color(sp,m.at(x,4,50-z)),'seat colors mirror on Z')
  else
   ok(y>=0 and y<=3,'all supports remain below the seat')
   ok(m.at(x,y+1,z)~=nil,'each leg rises continuously to the seat')
  end
 end
 if chair(x,z)then
  local west=x>=3 and x<=4
  local east=x>=11 and x<=12
  local rear=z>=22 and z<=23
  local front=z>=27 and z<=28
  local expected=y==4 and x>=2 and x<=13 and z>=20 and z<=30
    or y<=3 and (west or east) and (rear or front)
  eq(i~=nil,not not expected,'closed seat and four complete inset2x2 posts')
 end
end end end
eq(chairVoxels,196,'132 seat voxels plus64 inset leg voxels')
eq(otherVoxels,4851,'all accepted desk and computer voxels retained')
ok(sourceSeatSamples>70,'broad original cushion field is exercised horizontally')
eq(seatColors[3],42,'one-cell closed black outline')
eq(seatColors[0],34,'one-cell even white padding')
eq(seatColors[1],56,'centered8x7 gray cushion')
for _,foot in ipairs({{3,4,22,23},{11,12,22,23},{3,4,27,28},{11,12,27,28}})do
 local ox=foot[1]<8 and foot[1]-1 or foot[2]+1
 local oz=foot[3]<25 and foot[3]-1 or foot[4]+1
 for z=foot[3],foot[4]do ok(m.at(ox,4,z)~=nil,'seat really overhangs each outward leg X edge')end
 for x=foot[1],foot[2]do ok(m.at(x,4,oz)~=nil,'seat really overhangs each outward leg Z edge')end
end
local before,after=oldEmit(old,osp,w,h),emit(m,sp,w,h)
local function deskFaces(quads)
 local out={}
 for _,q in ipairs(quads)do
  local minX,maxZ=math.huge,-math.huge
  for i=1,4 do minX=math.min(minX,q[i][1]);maxZ=math.max(maxZ,q[i][3])end
  if maxZ<=16 or minX>=16 then out[#out+1]=q end
 end
 return out
end
-- The final seat starts at z20; the desk ends at z16. That four-pixel
-- gap exceeds the local AO stencil. Its complete original quads therefore
-- retain identical corners, UVs, winding and per-corner light values.
same(deskFaces(after),deskFaces(before),'complete unaffected desk rendering')
eq(after.voxels,otherVoxels+chairVoxels,'emitted model occupancy')
print(('Bill desk: all4851 original desk voxels and complete desk quads unchanged; chair196 voxels at height5; total%d -> %d, quads%d -> %d'):format(before.voxels,after.voxels,#before,#after))
print(('%d integrated-chair geometry/source/preservation checks passed'):format(checks))
