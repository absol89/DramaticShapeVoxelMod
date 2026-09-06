-- Optional real-map regression; callers supply their own engine/imported data.
local engine=assert(os.getenv('ASTRA_ENGINE'),'ASTRA_ENGINE required');package.path=engine..'/?.lua;'..package.path
local Map=require('src.world.Map');local gen=assert(os.getenv('ASTRA_GENERATED'),'ASTRA_GENERATED required')
local maps=dofile(gen..'/maps.lua');local ts=dofile(gen..'/tilesets.lua')
local root=os.getenv('ASTRA_CANDIDATE') or '.'
local V={data=function()return dofile(root..'/data/voxel_heights.lua')end};local modules={BuildBudget={tick=function()end},CommunityVisuals=setmetatable({customWalls=function()return true end},{__index=function()return function()return false end end})}
function V.require(n)if not modules[n]then modules[n]=assert(loadfile(root..'/lib/'..n..'.lua'))(V)end;return modules[n]end
local m=Map.new(maps.ROUTE_4,ts.OVERWORLD);local S=V.require('Structures').forMap(m)
for y=8,11 do for x=36,37 do local k=(y+64)*4096+x+64;local r=S.runs[k]or{};print(x,y,'tile',S.tileAt[k],'fold',S.doorFold[k],'skip',S.skip[k],'door',r.door,'front',r.front,'retaining',r.kantoRetaining,'height',S.shapeAt[k]and S.shapeAt[k].h)end end
local verts,indices,count=V.require('ChunkMesher').geometry(m,true)
local front,back=0,0
for _,v in ipairs(verts)do
 if v[1]>=288 and v[1]<=304 and v[2]>=0 and v[2]<=16 then
  if math.abs(v[3]-96)<.01 then front=front+1 end
  if math.abs(v[3]-90)<.01 then back=back+1 end
 end
end
print('GEOMETRY',#verts,'FRONT_VERTICES',front,'RECESSED_MOUTH_VERTICES',back)

assert(back>0,"Mt Moon recessed mouth must be emitted")

local darkBack,ceilings=0,{}
for i=1,#verts,4 do
 local q={verts[i],verts[i+1],verts[i+2],verts[i+3]};local cx,cy,cz=0,0,0
 for _,v in ipairs(q)do cx=cx+v[1]/4;cy=cy+v[2]/4;cz=cz+v[3]/4 end
 if cx>288 and cx<304 and cz>=90 and cz<=96 then
  if math.abs(cz-90)<.01 then darkBack=darkBack+1 end
  if q[1][2]==q[2][2] and q[2][2]==q[3][2] and q[3][2]==q[4][2] and cy>0 then ceilings[cy]=true end
 end
end
assert(darkBack>0,'deep tunnel back emitted');assert(ceilings[9] and ceilings[12] and ceilings[13],'stepped arch roof levels')
print('PASS deep tunnel and stepped aperture')
local cornerFaces=0
local aw=m.tileset.imageWidth or 128;local ah=m.tileset.imageHeight or 48
for i=1,#verts,4 do
 local cx,cz=0,0
 for j=0,3 do cx=cx+verts[i+j][1]/4;cz=cz+verts[i+j][3]/4 end
 local tx,ty=math.floor(cx/8),math.floor(cz/8)
 local x,z=math.floor(tx/2)*2,math.floor(ty/2)*2
 if m:tileAt(x,z)==55 and m:tileAt(x+1,z)==19 and m:tileAt(x,z+1)==19 and m:tileAt(x+1,z+1)==39 and m:tileAt(tx,ty)==19 then
  for j=0,3 do local v=verts[i+j];local tile=math.floor(v[4]*aw/8)+math.floor(v[5]*ah/8)*16
   assert(tile~=19,'raw diagonal cliff art still on corner')
  end
  cornerFaces=cornerFaces+1
 end
end
assert(cornerFaces>0,'cliff corners covered by regression');print('PASS cliff material '..cornerFaces..' faces')
