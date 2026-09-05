-- The SHIP stool separates its round cushion, pedestal and foot instead
-- of flattening the source's shaft/fascia markings onto horizontal surfaces.
local root=os.getenv('ASTRA_ROUND_ROOT') or os.getenv('ASTRA_CANDIDATE') or '.'
local baseline=assert(os.getenv('ASTRA_ROUND_BASELINE'),'ASTRA_ROUND_BASELINE required')
local H=dofile('tests/astra_fixture.lua')
local data,w,h=H.atlas(assert(os.getenv('ASTRA_SHIP_ATLAS'),'ASTRA_SHIP_ATLAS required'))
local checks=0
local function ok(v,msg)checks=checks+1;if not v then error('FAIL '..msg,0)end end
local function eq(a,b,msg)ok(a==b,msg..' (expected '..tostring(b)..', got '..tostring(a)..')')end
local function color(sp,i)
 local r,g,b,a=data:getPixel(sp.ax[i],sp.ay[i]);return table.concat({r,g,b,a},',')
end
local emit,m,sp=H.building(root,'ship_stool',data,w,h,nil,true,'SHIP')
local oldEmit,old,osp=H.building(baseline,'ship_stool',data,w,h,nil,true,'SHIP')
eq(m.ytop+1,8,'original round-seat height')
eq(m.W,old.W,'unchanged source grid width');eq(m.zmin,old.zmin,'unchanged source grid rear');eq(m.zmax,old.zmax,'unchanged source grid front')
local donors={[7]=true,[8]=true,[23]=true,[24]=true}
local occupied,grayTop=0,0
local layers={}
for y=0,m.ytop do
 local bounds={minX=math.huge,maxX=-math.huge,minZ=math.huge,maxZ=-math.huge,n=0,colors={[0]=0,[1]=0,[2]=0,[3]=0}}
 layers[y]=bounds
 for z=m.zmin,m.zmax do for x=0,m.W-1 do
  local i=m.at(x,y,z)
  local reflections={m.at(15-x,y,z),m.at(x,y,15-z),m.at(15-z,y,x)}
  for k=1,3 do
   local j=reflections[k]
   eq(i~=nil,j~=nil,'layer '..y..' occupied plan symmetric under transform '..k..' at '..x..','..z)
   if i~=nil then eq(color(sp,i),color(sp,j),'layer '..y..' source colors symmetric under transform '..k..' at '..x..','..z)end
  end
  if i~=nil then
   occupied=occupied+1;bounds.n=bounds.n+1
   bounds.colors[sp.col[i]]=bounds.colors[sp.col[i]]+1
   bounds.minX=math.min(bounds.minX,x);bounds.maxX=math.max(bounds.maxX,x)
   bounds.minZ=math.min(bounds.minZ,z);bounds.maxZ=math.max(bounds.maxZ,z)
   ok(sp.inside[i],'every material donor belongs inside the chair drawing')
   local tile=math.floor(sp.ay[i]/8)*(w/8)+math.floor(sp.ax[i]/8)
   ok(donors[tile],'no floor tile or unrelated atlas donor')
   if y==0 then
    -- The projected shaft's gray/pink and dark/red markings are not the
    -- pedestal foot. It has an uninterrupted pale face and dark outline.
    local edge=m.at(x-1,0,z)==nil or m.at(x+1,0,z)==nil
      or m.at(x,0,z-1)==nil or m.at(x,0,z+1)==nil
    eq(sp.col[i],edge and 3 or 0,'foot has only its black outline and clean white interior at '..x..','..z)
   elseif y>=1 and y<=4 then
    ok(x>=7 and x<=8 and z>=7 and z<=8,'open space around the centered pedestal')
    local prior=old.at(x,y,z)
    eq(i,prior,'accepted shaft source texel unchanged')
    eq(sp.ax[i],osp.ax[prior],'accepted shaft atlas X unchanged')
    eq(sp.ay[i],osp.ay[prior],'accepted shaft atlas Y unchanged')
   elseif y==5 then
    eq(sp.col[i],3,'lower cushion is its original black underside')
   elseif y==6 then
    eq(sp.col[i],2,'vertical cushion fascia uses its original dark band')
   elseif y==7 then
    local function edge(tx,tz)
     return m.at(tx,7,tz)~=nil and (m.at(tx-1,7,tz)==nil or m.at(tx+1,7,tz)==nil
       or m.at(tx,7,tz-1)==nil or m.at(tx,7,tz+1)==nil)
    end
    local outside=edge(x,z)
    local inner=not outside and (edge(x-1,z) or edge(x+1,z) or edge(x,z-1) or edge(x,z+1))
    eq(sp.col[i],outside and 3 or (inner and 2 or 1),'cushion has even black outline/dark inset/gray field')
    if sp.col[i]==1 then grayTop=grayTop+1 end
   end
  end
 end end
end
for _,entry in ipairs({{0,10},{7,12}})do
 local b=layers[entry[1]]
 eq(b.maxX-b.minX+1,entry[2],'round part original width at y'..entry[1])
 eq(b.maxZ-b.minZ+1,entry[2],'round part equal depth at y'..entry[1])
 eq(b.minX+b.maxX,15,'round part centered on X')
 eq(b.minZ+b.maxZ,15,'round part centered on Z')
end
for y=1,4 do eq(layers[y].n,4,'four occupied central-pedestal cells at each height')end
for _,entry in ipairs({{0,88},{5,52},{6,88},{7,132}})do
 eq(layers[entry[1]].n,entry[2],'symmetric source-sized part volume at y'..entry[1])
end
eq(layers[0].colors[0],60,'clean sixty-pixel white foot field')
eq(layers[0].colors[3],28,'complete twenty-eight-pixel black foot outline')
eq(layers[7].colors[3],36,'complete black cushion outline')
eq(layers[7].colors[2],32,'even dark cushion inset')
eq(layers[7].colors[1],64,'centered original-gray cushion field')
ok(grayTop>40,'broad cushion field remains on the horizontal seat')
local before,after=oldEmit(old,osp,w,h),emit(m,sp,w,h)
eq(after.voxels,occupied,'emitted occupancy agrees with corrected model')
print(('SHIP stool: symmetric X/Z/quarter turns, clean source-white foot, centered2x2 pedestal, height8; foot%d seat%d voxels, total%d -> %d, quads%d -> %d'):format(
 layers[0].n,layers[7].n,before.voxels,after.voxels,#before,#after))
print(('%d round-stool symmetry and material checks passed'):format(checks))
