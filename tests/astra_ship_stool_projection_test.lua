-- The SHIP stool's cushion must be horizontal, not a vertical sprite slab.
-- Uses a private generated atlas; no game pixels belong in this test source.
-- ASTRA_SHIP_ATLAS: raw ship atlas (width height LF, then RGBA bytes).
-- ASTRA_STOOL_ROOT defaults to the candidate. Set it to Astra3 to reproduce.
local root=os.getenv('ASTRA_STOOL_ROOT') or '.'
local H=dofile('tests/astra_fixture.lua')
local inspect=assert(loadfile('tests/astra_building_contact_test.lua'))('helpers')
local data,w,h=H.atlas(assert(os.getenv('ASTRA_SHIP_ATLAS'),'ASTRA_SHIP_ATLAS required'))
local spec=dofile(root..'/data/voxel_heights.lua')
local check=0
local function ok(v,msg)check=check+1;if not v then error('FAIL '..msg,0)end end
local function eq(a,b,msg)ok(a==b,msg..' (expected '..tostring(b)..', got '..tostring(a)..')')end
local function key(x,y,z)return x..','..y..','..z end
local B=assert(loadfile(root..'/lib/Buildings.lua'))({
  require=function()return{tick=function()end}end,data=function()return spec end})
local tileGrid={{7,8},{23,24}}
local sp=H.upvalue(B.build,'read')({tiles=tileGrid},data,w/8)
local template
for _,t in ipairs(spec.buildings.SHIP or {})do if t.id=='ship_stool' then template=t end end
local quads,model
if template then
  local emit,m,s=H.building(root,'ship_stool',data,w,h,nil,true,'SHIP')
  model,sp=m,s;quads=emit(m,s,w,h)
else
  -- Exercise the real old standee emitter with the source mask rather than
  -- failing simply because the new profile does not exist in the baseline.
  package.loaded['src.render.Assets']={register=function()end}
  package.loaded['src.world.Map']={}
  local St=assert(loadfile(root..'/lib/Structures.lua'))({require=function(n)
    return n=='BuildBudget' and {tick=function()end} or {}
  end})
  local function tk(x,z)return(z+64)*4096+x+64 end
  local S={shapeAt={},tileAt={},skip={},ground={},objectQuads={}}
  for z=-1,2 do for x=-1,2 do
    S.shapeAt[tk(x,z)]={class='ground',flat=true,h=0};S.tileAt[tk(x,z)]=13
  end end
  for z,row in ipairs(tileGrid)do for x,t in ipairs(row)do
    S.shapeAt[tk(x-1,z-1)]={class='stool',h=8,authored=true}
    S.tileAt[tk(x-1,z-1)]=t
  end end
  local state,srcU,srcV={},{},{}
  for y=0,15 do for x=0,15 do
    local dst=(y+1)*16+x+1;local src=y*16+x
    state[dst]=sp.inside[src] and 'solid' or 'air'
    srcU[dst],srcV[dst]=sp.ax[src],sp.ay[src]
  end end
  local cluster={minX=0,minY=0,maxX=1,maxY=1,tiles={{0,0},{1,0},{0,1},{1,1}}}
  assert(St.buildObject(S,{tileset={imageWidth=w,imageHeight=h},isWalkableCell=function()return true end},
    cluster,cluster,state,{},srcU,srcV,16,true))
  quads=S.objectQuads
end
local maxY=-math.huge
for _,q in ipairs(quads)do for i=1,4 do maxY=math.max(maxY,q[i][2])end end
print(("Emitted stool: %d quads, height%g"):format(#quads,maxY))
-- The old actual emitter fails here at height14, while seating is pinned8.
eq(maxY,8,'round stool geometry must end at its existing seating height')
ok(model~=nil,'horizontal furniture model selected')
eq(model.ytop+1,8,'modeled seat height')
local occupied,grayTop={},0
local count=0
for y=0,model.ytop do for z=model.zmin,model.zmax do for x=0,model.W-1 do
  local i=model.at(x,y,z)
  if i~=nil then
    count=count+1;occupied[key(x,y,z)]={x,y,z}
    ok(sp.inside[i],'every voxel samples inside the source silhouette')
    ok(sp.ax[i]>=0 and sp.ax[i]<w and sp.ay[i]>=0 and sp.ay[i]<h,'source UV inside atlas')
    local sy=math.floor(i/16)
    if y==7 then
      ok(sy>=2 and sy<=10,'top face uses cushion art rather than base art')
    end
    if y==7 and sp.col[i]==1 then grayTop=grayTop+1 end
    if y>=1 and y<=4 then
      ok(x>=7 and x<=8 and z>=7 and z<=8,'open space surrounds the central pedestal')
    end
  end
end end end
ok(grayTop>40,'broad horizontal cushion field survives')
-- Source fascia and shaft rows are intentionally reinterpreted: retaining
-- every projected texel would restore the uneven lid and pink foot blotch.
-- The focused symmetry test checks the corrected part materials; source
-- ownership and the exact emitted shell/UV checks below remain mandatory.
eq(quads.voxels,count,'emitted volume matches model')
-- A single 6-connected component rules out floating cushions/feet.
local _,seed=next(occupied);local queue={seed};occupied[key(unpack(seed))]=nil
local head=1
local dirs={{1,0,0},{-1,0,0},{0,1,0},{0,-1,0},{0,0,1},{0,0,-1}}
while head<=#queue do
  local p=queue[head];head=head+1
  for _,d in ipairs(dirs)do local k=key(p[1]+d[1],p[2]+d[2],p[3]+d[3])
    if occupied[k]then queue[#queue+1]=occupied[k];occupied[k]=nil end
  end
end
eq(#queue,count,'seat, pedestal and foot form one connected object')
-- Verify the actual visible unit shell and source-UV interpolation, allowing
-- merged quads but neither missing/duplicate faces nor a printed sprite slab.
local axes={{2,3},{1,3},{1,2}}
local function faceKey(a,p,b,c)return a..':'..p..':'..b..':'..c end
local expected={}
for y=0,model.ytop do for z=model.zmin,model.zmax do for x=0,model.W-1 do
  local i=model.at(x,y,z)
  if i~=nil then for a=1,3 do for _,d in ipairs({-1,1})do
    local n={x,y,z};n[a]=n[a]+d
    if model.at(unpack(n))==nil and not(a==2 and d==-1 and y==0) then
      local p={x,y,z}
      expected[faceKey(a,p[a]+(d==1 and 1 or 0),p[axes[a][1]],p[axes[a][2]])]=i
    end
  end end end
end end end
local seen={}
for _,q in ipairs(quads)do
  local a,p,b0,b1,c0,c1=inspect.face(q)
  ok(b1>b0 and c1>c0,'positive face area')
  for b=b0,b1-1 do for c=c0,c1-1 do
    local k=faceKey(a,p,b,c);local i=expected[k]
    ok(i~=nil,'emitted face belongs to exposed shell')
    ok(not seen[k],'no duplicate shell face');seen[k]=true
    for _,db in ipairs({.25,.75})do for _,dc in ipairs({.25,.75})do
      eq(math.floor(inspect.sample(q,a,b+db,c+dc,1)*w),sp.ax[i],'source atlas X on visible face')
      eq(math.floor(inspect.sample(q,a,b+db,c+dc,2)*h),sp.ay[i],'source atlas Y on visible face')
    end end
  end end
end
for k in pairs(expected)do ok(seen[k],'no missing shell face')end
print(('%d checks passed: horizontal round stool; %d voxels; %d quads; height8'):format(check,count,#quads))
