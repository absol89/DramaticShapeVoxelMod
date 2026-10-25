-- ROM-free FULL = BODY + RING geometry and ownership regression. Uses the
-- production mesher; synthetic tiles/props exercise overhangs and seams.
local checks = 0
local function check(v, message) checks=checks+1; assert(v, message) end
package.preload['src.render.Assets']=function() return {register=function()end} end
local Parts=assert(loadfile('lib/MeshParts.lua'))()
local modules={MeshParts=Parts}
local no=function()return false end
local inert=setmetatable({}, {__index=function()return no end})
modules.BuildBudget={tick=function()end,check=function()end}
modules.LoadTimings={wrap=function(_,f)return f end,call=function(_,f,...)return f(...)end}
modules.CommunityVisuals=setmetatable({}, {__index=function()return no end})
modules.VoxelMeshDisk={available=no}
modules.TileShape={heights=function()return {water=0}end,forMap=function()return {}end}
modules.Voxel3D={pushQuad=function(indices,n)
  local b=n*4
  for _,v in ipairs({b,b+1,b+2,b,b+2,b+3})do indices[#indices+1]=v end
end}
local allocated=0
function modules.Voxel3D.newMesh(vertices)
  if #vertices==0 then return nil end
  allocated=allocated+#vertices
  return {getVertexCount=function()return #vertices end,release=function()end}
end
local key=function(x,z)return (z+64)*4096+x+64 end
local S={shapeAt={},tileAt={},skip={},ground={},runs={},doorFold={},
  objectQuads={},roundStamps={},grassQuads={},flowerQuads={},figures={}}
modules.Structures={forMap=function()return S end}
local V={require=function(name)return modules[name] or inert end}
local Mesher=assert(loadfile('lib/ChunkMesher.lua'))(V)
local map={id='PARTITION_FIXTURE',def={width=1,height=1},
  tileset={id='TEST',imageWidth=128,imageHeight=48,tilesPerRow=16}}
function map:tileAt()return 0 end
function map:isWaterCell()return false end
function map:cellTile()return 0 end
local ground={class='ground',flat=true,h=0}
local water={class='water',flat=true,h=0}
for z=-2,5 do for x=-2,5 do
  S.shapeAt[key(x,z)]=(x==0 and z==0)and water or ground
  S.tileAt[key(x,z)]=0
end end
local function quad(x0,z0,x1,z1,own,border)
 return {{x0,5,z0},{x1,5,z0},{x1,5,z1},{x0,5,z1},
  u=.1,v=.2,shade=1,own=own,borderBounds=border}
end
-- Entirely internal, external, boundary-straddling and owned roof eaves.
S.objectQuads={quad(2,2,12,12),quad(-12,4,-2,12),quad(-4,4,4,12),
  quad(-8,8,-2,16,true),quad(34,0,42,8,false,{34,0,42,8})}
for i=1,80 do
 local x,z=(i*17)%61-15,(i*23)%61-15
 S.objectQuads[#S.objectQuads+1]=quad(x,z,x+3+i%9,z+4+i%7,i%11==0)
end
for _,reverse in ipairs({false,true})do
 local q={{0,0,4},{0,8,4},{0,8,12},{0,0,12},u=.1,v=.2,shade=1}
 if reverse then q[1],q[4],q[2],q[3]=q[4],q[1],q[3],q[2] end
 S.objectQuads[#S.objectQuads+1]=q
end
S.roundStamps={{mx=16,mz=16,r=4,quads={quad(-3,-3,3,3)}},
 {mx=-4,mz=16,r=5,quads={quad(-2,-2,2,2),quad(3,-2,6,2)}}}
modules.ForestTrees={expand=function(_,st,corners)
 for _,p in ipairs(corners)do
  p[1]=st.mx+(p[1]-st.mx)*6;p[3]=st.mz+(p[3]-st.mz)*6
 end
end}
S.roundStamps[#S.roundStamps+1]={mx=16,mz=16,r=4,forestTree=true,quads={quad(-3,-3,3,3)}}
local function bag(vertices)
 local b={}
 for i=1,#vertices,4 do
  local p={}
  for j=i,i+3 do for _,v in ipairs(vertices[j])do p[#p+1]=('%.8f'):format(math.abs(v)<1e-9 and 0 or v)end end
  local s=table.concat(p,',');b[s]=(b[s]or 0)+1
 end
 return b
end
local function parity(masks)

 local f,_,_,fw=Mesher.geometry(map,false,masks,true)
 local b,_,_,bw=Mesher.geometry(map,true,nil,true)
 local r,_,_,rw=Mesher.geometry(map,'ring',masks,true)


 local function same(full,body,ring,kind)
  local actual=bag(full);local combined=bag(body)
  for q,n in pairs(bag(ring))do combined[q]=(combined[q]or 0)+n end
  for q,n in pairs(actual)do check(combined[q]==n,kind..' missing/duplicated full quad '..q..' full='..n..' parts='..tostring(combined[q]))end
  for q,n in pairs(combined)do check(actual[q]==n,kind..' extra body/ring quad')end
 end
 same(f,b,r,'terrain');same(fw,bw,rw,'water')
 check(#b>0 and #r>0,'fixture must exercise both partitions')
end
parity(nil);parity({{-32,-32,0,64}})
local a={getVertexCount=function()return 6 end}
local b={getVertexCount=function()return 12 end}
local view=Parts.join(a,b)
check(view:getVertexCount()==18,'view count')
check(Parts.join(a,b,view)==view,'stable identity for shadow signatures')
check(Parts.join(a,false)==a,'empty ring reuses body')
check(Parts.join(false,b)==b,'empty body retains ring')
check(not view.release,'view must not own shared GPU components')
check(Parts.parts(view)[1]==a and Parts.parts(view)[2]==b,'shared mesh identity')
local full=Mesher.get(map,false,nil)
local afterFull=allocated
local body=Mesher.get(map,true,nil)
check(allocated==afterFull,'crossing must not reupload the shared body')
check(Parts.parts(full)[1]==body,'full view must reuse exact neighbor body')
local legacy,_,_,legacyWater=Mesher.geometry(map,false,nil,true)
check(full:getVertexCount()==#legacy,'published body/ring vertex parity')
check(afterFull==#legacy+#legacyWater,'GPU allocation must contain one full map, no duplicate body')
map.def.connections={east={map='NEXT'}}
check(Mesher.neighborPriority(map,'NEXT')>1.25,'direct body precedes ring')
check(Mesher.neighborPriority(map,'DISTANT')<1.25,'distant body follows ring')
-- Empty rings are common indoors and must not suppress seasonal work or
-- make title precaching wait forever for a deliberately empty stream.
S.shapeAt={[key(0,0)]=ground};S.tileAt={[key(0,0)]=0}
S.objectQuads={};S.roundStamps={}
local indoor={id='EMPTY_RING_FIXTURE',def=map.def,tileset=map.tileset,
 tileAt=map.tileAt,isWaterCell=map.isWaterCell,cellTile=map.cellTile}
local warm=Mesher.get(indoor,false,nil)
check(warm~=nil and warm==Mesher.peek(indoor,true),'empty ring must retain shared body')
check(Mesher.slotKnown(indoor,false),'empty ring settles full view')
check(Mesher.seasonalState(indoor,false),'empty ring must not suppress seasonal readiness')
print(('PASS mesh partitions: %d checks'):format(checks))
