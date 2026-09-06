
local Decor=assert(loadfile('lib/HouseWallDecor.lua'))()
local function key(x,y)return(y+64)*4096+x+64 end
local fixtures={
 {'HOUSE',2,{45,46,61,62}}, {'HOUSE',4,{72,73,73,75,88,89,90,91}},
 {'REDS_HOUSE_2',2,{36,37,52,53}}, {'POKECENTER',2,{92,93,94,95}},
 {'LOBBY',1,{6,22}}, {'LOBBY',2,{72,73,88,89}},
}
local count=0
for _,f in ipairs(fixtures)do
 local map={id='TEST',def={width=2,height=2},tileset={id=f[1],imageWidth=128,imageHeight=48}}
 local S={tileAt={},shapeAt={},objectQuads={}}
 for i,t in ipairs(f[3])do local k=key((i-1)%f[2],math.floor((i-1)/f[2]));S.tileAt[k]=t;S.shapeAt[k]={class='wall',h=16} end
 Decor.build(S,map,0,7,0,7);assert(#S.objectQuads==#f[3])
 for _,q in ipairs(S.objectQuads)do
  assert(q[1][3]==q[3][3] and q[1][2]<q[3][2])
  for _,uv in ipairs(q.uv)do assert(math.floor(uv[1]*128/8)+math.floor(uv[2]*48/8)*16==q.wallDecorSourceTile)end
 end
 Decor.build(S,map,0,7,0,7);assert(#S.objectQuads==#f[3],'repeated decoration')
 count=count+#f[3]
end
local Gate=assert(loadfile('lib/SafariGatehouse.lua'))({})
local map={id='SAFARI_ZONE_CENTER',tileset={id='FOREST'},def={warps={{x=14,y=25,destMap='SAFARI_ZONE_GATE',destWarp=3},{x=15,y=25,destMap='SAFARI_ZONE_GATE',destWarp=4}}}}
assert(Gate.matches(map));map.def.warps[2].destWarp=9;assert(not Gate.matches(map))
local F=assert(loadfile('lib/SafariFoliage.lua'))({require=function(n) assert(n=='Voxel3D');return {FACE_SHADE={1,1,1,1,1,1},FACE_CORNERS={{{1,0,0},{1,0,1},{1,1,1},{1,1,0}},{{0,0,1},{0,0,0},{0,1,0},{0,1,1}},{{0,1,0},{1,1,0},{1,1,1},{0,1,1}},{{0,0,1},{1,0,1},{1,0,0},{0,0,0}},{{0,0,1},{1,0,1},{1,1,1},{0,1,1}},{{1,0,0},{0,0,0},{0,1,0},{1,1,0}}},pushQuad=function(t,q)local b=q*4;for _,i in ipairs({1,2,3,1,3,4})do t[#t+1]=b+i end end}end})
local verts=F.geometry({{x=0,z=0,tx=0,ty=0}})
assert(#verts>0)
for _,v in ipairs(verts)do assert(v[1]>=0 and v[1]<=16 and v[2]>=0 and v[2]<=20 and v[3]>=0 and v[3]<=16)end
assert(#F.placements({id='VIRIDIAN_FOREST',tileset={id='FOREST'}})==0)
local Stair=assert(loadfile('lib/InteriorStairs.lua'))()
for _,class in ipairs({'stair_n','stair_down_n'})do
 local S={tileAt={},objectQuads={}}
 for i,t in ipairs({3,61,19,78})do S.tileAt[key((i-1)%2,math.floor((i-1)/2))]=t end
 Stair.build(S,{tileset={imageWidth=128,imageHeight=48}},nil,0,0,{class=class,h=16})
 for _,q in ipairs(S.objectQuads)do for _,uv in ipairs(q.uv)do
  assert(math.floor(uv[1]*128/8)+math.floor(uv[2]*48/8)*16==q.stairSourceTile,'legacy stair crossed tile')
 end end
end
print('PASS shared wall patterns, UV isolation, idempotence, gate guards, foliage bounds and legacy north stairs')

local file=assert(io.open('lib/Structures.lua','rb'));local source=file:read('*a');file:close()
local a=assert(source:find('local STAIR_STEPS =',1,true))
local b=assert(source:find('function Structures.buildStairs',a,true))
local fn=assert(loadstring('local function keyOf(x,y)return(y+64)*4096+x+64 end\n'..source:sub(a,b-1)..'\nreturn stairCell'))()
for _,class in ipairs({'stair_e','stair_w','stair_down_e','stair_down_w'})do
 local S={tileAt={},objectQuads={}}
 for i,t in ipairs({3,61,19,78})do S.tileAt[key((i-1)%2,math.floor((i-1)/2))]=t end
 fn(S,{tileset={imageWidth=128,imageHeight=48}},nil,0,0,{class=class,h=16})
 assert(#S.objectQuads>0)
 for _,q in ipairs(S.objectQuads)do for _,uv in ipairs(q.uv)do
  assert(math.floor(uv[1]*128/8)+math.floor(uv[2]*48/8)*16==q.stairSourceTile,'legacy E/W stair crossed tile')
 end end
end
print('PASS all four legacy east/west stair directions with nonadjacent source tiles')
