-- Exact-grid and gameplay-support integration for the SHIP round stool.
-- Uses the real engine Map and VoxelScene.groundAt; rendering-only module
-- dependencies are stubbed because this test does not open a GPU window.
-- Private generated game data and image bytes are external test inputs.
local candidate=os.getenv('ASTRA_CANDIDATE') or '.'
local baseline=assert(os.getenv('ASTRA_SHIP_BASELINE'),'ASTRA_SHIP_BASELINE required')
local engine=assert(os.getenv('ASTRA_ENGINE'),'ASTRA_ENGINE required')
local generated=assert(os.getenv('ASTRA_GENERATED'),'ASTRA_GENERATED required')
local atlas=assert(os.getenv('ASTRA_SHIP_ATLAS'),'ASTRA_SHIP_ATLAS required')
package.path=engine..'/?.lua;'..engine..'/?/init.lua;'..package.path
local Map=require('src.world.Map')
local H=dofile(candidate..'/tests/astra_fixture.lua')
local pixels,aw,ah=H.atlas(atlas)
local maps=dofile(generated..'/maps.lua')
local tilesets=dofile(generated..'/tilesets.lua')
local checks=0
local function ok(v,message) checks=checks+1;if not v then error('FAIL '..message,0)end end
local function eq(a,b,message)ok(a==b,message..' (expected '..tostring(b)..', got '..tostring(a)..')')end
local function copy(t)local q={};for k,v in pairs(t)do q[k]=v end;return q end
local function load(root)
  local spec=dofile(root..'/data/voxel_heights.lua')
  local modules={BuildBudget={tick=function()end},
    ModSetting={new=function()return{get=function()return true end}end}}
  local V={data=function()return spec end}
  function V.require(n)
    if modules[n]then return modules[n]end
    if n=='Buildings' or n=='TileShape' then
      modules[n]=assert(loadfile(root..'/lib/'..n..'.lua'))(V)
    else modules[n]={}end
    return modules[n]
  end
  return {spec=spec,build=V.require('Buildings'),shapes=V.require('TileShape'),
    scene=assert(loadfile(root..'/lib/VoxelScene.lua'))(V)}
end
local before,after=load(baseline),load(candidate)
-- A20 adds nine independently tested SHIP fixtures. Keep this historical A4
-- integration oracle focused on the round stool's claims and near-miss rules.
-- The live remaining-interiors test owns all new exact fixture claims.
after.spec.buildings.SHIP=H.historicalPublicBuildings(after.spec.buildings,before.spec.buildings).SHIP
local function key(x,z)return(z+64)*4096+(x+64)end
local function build(runtime,map)
  local S={outdoor=false,shapeAt={},tileAt={},skip={},ground={},objectQuads={}}
  local resolved=runtime.shapes.forMap(map)
  for z=-1,map.def.height*4 do for x=-1,map.def.width*4 do
    local tile=map:tileAt(x,z)
    S.tileAt[key(x,z)]=tile
    S.shapeAt[key(x,z)]=runtime.shapes.at(map,resolved,tile,x,z)
  end end
  runtime.build.build(S,map,pixels,aw/8)
  return S
end
local function claims(S)local n=0;for _,v in pairs(S.skip)do if v then n=n+1 end end;return n end
local function synthetic(id,grid)
  local block={};for i=1,16 do block[i]=0 end
  for z=1,2 do for x=1,2 do block[(z-1)*4+x]=grid[z][x]end end
  local ts=copy(tilesets.SHIP);ts.blocks={block};ts.imageWidth=aw;ts.imageHeight=ah
  return Map.new({id=id,tileset='SHIP',width=1,height=1,blocks={0},borderBlock=0},ts)
end
local function snapshotCollision(map)
  local out={}
  for z=0,map.heightCells-1 do for x=0,map.widthCells-1 do
    out[#out+1]=tostring(map:cellTile(x,z))..':'..tostring(map:isWalkableCell(x,z))
  end end
  return table.concat(out,';')
end
local normal={{7,8},{23,24}}
local map=synthetic('ASTRA_SHIP_MATCH',normal)
local collision=snapshotCollision(map)
local old,new=build(before,map),build(after,map)
eq(claims(old),0,'Astra 3 uses the old unclaimed standee path')
eq(claims(new),4,'exact round-stool grid claims only four tiles')
ok(#new.objectQuads>0,'exact grid emits its new model')
for z=0,1 do for x=0,1 do
  eq(new.shapeAt[key(x,z)].class,'building','claimed source tile uses authored model')
end end
eq(snapshotCollision(map),collision,'model construction never changes collision')
eq(before.scene.groundAt(map,0,0),8,'original round stool seats characters at eight')
eq(after.scene.groundAt(map,0,0),8,'new round stool preserves character seating height')
-- Shared lower tiles must not turn the captain's different chair into the
-- new round stool. Nor may matching three of four tiles claim a different
-- piece of furniture. Every one-tile mutation is a separate case.
local cases={{'captain',{{66,67},{23,24}}},
  {'table',{{9,12},{25,28}}}}
for z=1,2 do for x=1,2 do
  local grid={{7,8},{23,24}};grid[z][x]=grid[z][x]+100
  cases[#cases+1]={'near_miss_'..x..'_'..z,grid}
end end
for _,entry in ipairs(cases)do
  local m=synthetic('ASTRA_SHIP_'..entry[1],entry[2])
  local oldS,newS=build(before,m),build(after,m)
  eq(claims(newS),claims(oldS),entry[1]..' retains the old ownership route')
  eq(#newS.objectQuads,#oldS.objectQuads,entry[1]..' gains no stool model')
  eq(after.scene.groundAt(m,0,0),before.scene.groundAt(m,0,0),
    entry[1]..' retains its original actor elevation')
end
-- Pins drive both the unmodified captain chair and the neighboring table.
for _,tile in ipairs({7,8,23,24,66,67,9,12,25,28})do
  local a,b=after.shapes.forMap(map)[tile],before.shapes.forMap(map)[tile]
  eq(a.class,b.class,'tile '..tile..' class remains unchanged')
  eq(a.art,b.art,'tile '..tile..' rendering pin remains unchanged')
  eq(a.h,b.h,'tile '..tile..' support height remains unchanged')
end
local ids={};for id,def in pairs(maps)do if def.tileset=='SHIP'then ids[#ids+1]=id end end
table.sort(ids)
local total,affected,npcs=0,0,0
for _,id in ipairs(ids)do
  local m=Map.new(maps[id],tilesets.SHIP)
  local expected,positions={},{}
  for z=0,m.def.height*4-2 do for x=0,m.def.width*4-2 do
    if m:tileAt(x,z)==7 and m:tileAt(x+1,z)==8
       and m:tileAt(x,z+1)==23 and m:tileAt(x+1,z+1)==24 then
      positions[#positions+1]={x,z}
      for dz=0,1 do for dx=0,1 do expected[key(x+dx,z+dz)]=true end end
    end
  end end
  local originalCollision=snapshotCollision(m)
  local oldS,newS=build(before,m),build(after,m)
  local count=0;for _ in pairs(expected)do count=count+1 end
  eq(claims(newS)-claims(oldS),count,id..' claims exactly its matched stool tiles')
  for k in pairs(expected)do ok(newS.skip[k],id..' claims matched tile')end
  for k in pairs(newS.skip)do ok(oldS.skip[k]or expected[k],id..' leaves unrelated tiles untouched')end
  eq(snapshotCollision(m),originalCollision,id..' collision data unchanged')
  for _,p in ipairs(positions)do
    local x,z=p[1]/2,p[2]/2
    eq(after.scene.groundAt(m,x,z),8,id..' modeled stool still supports at eight')
    eq(after.scene.groundAt(m,x,z),before.scene.groundAt(m,x,z),id..' original seated height retained')
    for _,obj in ipairs(m.def.objects or {})do if obj.x==x and obj.y==z then
      npcs=npcs+1
      eq(after.scene.groundAt(m,obj.x,obj.y),8,id..' existing seated NPC remains on its seat')
    end end
  end
  if #positions>0 then
    affected=affected+1;total=total+#positions
    local cells={};for _,p in ipairs(positions)do cells[#cells+1]=('(%g,%g)'):format(p[1]/2,p[2]/2)end
    print(id..': '..#positions..' stool(s), cells '..table.concat(cells,' '))
  end
end
-- These figures describe the verified Yellow input. The exact ownership
-- checks above remain the central assertions if other game data is used.
print(('%d exact stools in %d affected maps; %d SHIP maps scanned; %d seated NPC(s) checked'):format(
 total,affected,#ids,npcs))
ok(total>0,'real generated map data exercised the new template')
local badge=Map.new(maps.CERULEAN_BADGE_HOUSE,tilesets.SHIP)
eq(after.scene.groundAt(badge,5,3),8,'reported Cerulean stool keeps its seated NPC at eight')
print(('%d integration checks passed (ship stool ownership and character support)'):format(checks))
