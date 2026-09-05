-- Real-map ownership and plant preservation for the three dining tables.
-- Artwork is private generated input; no ROM pixels belong in a release.
local candidate=os.getenv('ASTRA_TABLE_ROOT') or os.getenv('ASTRA_CANDIDATE') or '.'
local baseline=assert(os.getenv('ASTRA_TABLE_BASELINE'),'ASTRA_TABLE_BASELINE required')
local engine=assert(os.getenv('ASTRA_ENGINE'),'ASTRA_ENGINE required')
local generated=assert(os.getenv('ASTRA_GENERATED'),'ASTRA_GENERATED required')
local atlases=assert(os.getenv('ASTRA_FURNITURE_ATLASES'),'ASTRA_FURNITURE_ATLASES required')
package.path=engine..'/?.lua;'..engine..'/?/init.lua;'..package.path
-- Only image loading/registration is stubbed. Plant extraction, claims,
-- authored tile pins, and game map collision all use production code.
package.loaded['src.render.Assets']={register=function()end}
local Map=require('src.world.Map')
local maps=dofile(generated..'/maps.lua')
local tilesets=dofile(generated..'/tilesets.lua')
local H=dofile('tests/astra_fixture.lua')
local checks=0
local function ok(v,msg)checks=checks+1;if not v then error('FAIL '..msg,0)end end
local function eq(a,b,msg)ok(a==b,msg..' (expected '..tostring(b)..', got '..tostring(a)..')')end
local function same(a,b,msg)
 eq(type(a),type(b),msg..' type')
 if type(a)~='table'then eq(a,b,msg);return end
 for k,v in pairs(a)do same(v,b[k],msg..'.'..tostring(k))end
 for k in pairs(b)do ok(a[k]~=nil,msg..' no extra field '..tostring(k))end
end
local function runtime(root)
 local profile=dofile(root..'/data/voxel_heights.lua')
 local modules={BuildBudget={tick=function()end},VoxelVisualObjects={},CommunityVisuals={},
  ModSetting={new=function()return{get=function()return true end}end}}
 local V={data=function()return profile end}
 function V.require(n)
  if not modules[n]then
   if n=='Buildings' or n=='TileShape' or n=='Structures'then
    modules[n]=assert(loadfile(root..'/lib/'..n..'.lua'))(V)
   else modules[n]={}end
  end
  return modules[n]
 end
 return {profile=profile,build=V.require('Buildings'),shapes=V.require('TileShape'),
  objects=V.require('Structures'),scene=assert(loadfile(root..'/lib/VoxelScene.lua'))(V)}
end
local before,after=runtime(baseline),runtime(candidate)
-- A18 household targets have separate full-runtime ownership checks.
-- Keep this historical dining-table pass focused on its original claims.
after.profile.buildings=H.historicalPalletBuildings(after.profile.buildings,before.profile.buildings)
local function template(profile,family,id)
 for _,t in ipairs(profile.buildings[family])do if t.id==id then return t end end
 error('missing template '..family..'/'..id)
end
local function key(x,z)return(z+64)*4096+x+64 end
local function build(r,map,pixels,w)
 local S={outdoor=false,shapeAt={},tileAt={},skip={},ground={},objectQuads={}}
 local resolved=r.shapes.forMap(map)
 for z=-1,map.def.height*4 do for x=-1,map.def.width*4 do
  local tile=map:tileAt(x,z)
  S.tileAt[key(x,z)]=tile;S.shapeAt[key(x,z)]=r.shapes.at(map,resolved,tile,x,z)
 end end
 r.build.build(S,map,pixels,w/8)
 return S
end
local function collision(map)
 local out={}
 for z=0,map.heightCells-1 do for x=0,map.widthCells-1 do
  out[#out+1]=tostring(map:cellTile(x,z))..':'..tostring(map:isWalkableCell(x,z))
 end end
 return table.concat(out,';')
end
-- Current upstream adds opt-in saplings; retain all historical class values.
before.profile.heights.sapling=before.profile.heights.sapling or 16
same(after.profile.heights,before.profile.heights,'all authored class heights')
same(H.historicalPins(after.profile.tilesets,before.profile.tilesets),before.profile.tilesets,'all fallback and seated-character pins')
local total,affected,plants=0,0,0
for _,f in ipairs({{'HOUSE','house_table','house'},
 {'REDS_HOUSE_1','reds_house_table','reds_house'},
 {'MANSION','mansion_long_table','mansion'}})do
 local t=template(after.profile,f[1],f[2])
 local oldt=template(before.profile,f[1],f[2])
 for _,field in ipairs({'tiles','keep','scrub','support'})do same(t[field],oldt[field],f[2]..' original '..field)end
 local data,w,h=H.atlas(atlases..'/'..f[3]..'.rgba')
 local ids={};for id,d in pairs(maps)do if d.tileset==f[1]then ids[#ids+1]=id end end;table.sort(ids)
 for _,id in ipairs(ids)do
  local map=Map.new(maps[id],tilesets[f[1]])
  local positions={}
  for z=0,map.def.height*4-#t.tiles do for x=0,map.def.width*4-#t.tiles[1]do
   local match=true
   for dz,row in ipairs(t.tiles)do for dx,tile in ipairs(row)do
    if map:tileAt(x+dx-1,z+dz-1)~=tile then match=false end
   end end
   if match then positions[#positions+1]={x,z}end
  end end
  if #positions>0 then
   total=total+#positions;affected=affected+1
   local oldCollision=collision(map)
   local old,new=build(before,map,data,w),build(after,map,data,w)
   for _,field in ipairs({'skip','shapeAt','ground','tileAt'})do same(new[field],old[field],id..' complete '..field)end
   eq(collision(map),oldCollision,id..' original collision and tile data')
   for z=0,map.heightCells-1 do for x=0,map.widthCells-1 do
    eq(after.scene.groundAt(map,x,z),before.scene.groundAt(map,x,z),id..' actor support unchanged')
   end end
   for _,p in ipairs(positions)do
    local kept={};for _,tile in ipairs(t.keep or {})do kept[tile]=true end
    local reg={minX=math.huge,maxX=-math.huge,minY=math.huge,maxY=-math.huge,tiles={}}
    local claimed=0
    for dz,row in ipairs(t.tiles)do for dx,tile in ipairs(row)do
     local x,z=p[1]+dx-1,p[2]+dz-1
     if kept[tile]then
      ok(not new.skip[key(x,z)],id..' kept plant tile remains unclaimed')
      eq(new.shapeAt[key(x,z)].class,'cutout',id..' plant cutout pin survives')
      reg.tiles[#reg.tiles+1]={x,z}
      reg.minX=math.min(reg.minX,x);reg.maxX=math.max(reg.maxX,x)
      reg.minY=math.min(reg.minY,z);reg.maxY=math.max(reg.maxY,z)
     else
      claimed=claimed+1
      ok(new.skip[key(x,z)],id..' exact table tile claimed')
      eq(new.shapeAt[key(x,z)].class,'building',id..' table pin replaced by authored model')
     end
    end end
    eq(claimed,#t.tiles*#t.tiles[1]-#reg.tiles,id..' no extra ownership changes')
    if #reg.tiles>0 then
     plants=plants+1;eq(#reg.tiles,5,id..' five original plant tiles')
     local bs=new.shapeAt[key(reg.minX,reg.maxY+1)]
     eq(bs.class,'building',id..' plant rests on the authored table claim')
     eq(bs.h,6,id..' plant support remains at six')
     old.objectQuads={};new.objectQuads={}
     local oldLeft=before.objects.extractObjects(old,map,reg,data,w/8,true)
     local newLeft=after.objects.extractObjects(new,map,reg,data,w/8,true)
     eq(#newLeft,0,id..' all plant tiles stay standees, with no duplicate volume')
     same(newLeft,oldLeft,id..' unchanged plant leftovers')
     same(new.objectQuads,old.objectQuads,id..' exact plant vertices/UVs/shades')
     for _,field in ipairs({'skip','shapeAt','ground'})do same(new[field],old[field],id..' post-plant '..field)end
     local lo,hi=math.huge,-math.huge
     for _,q in ipairs(new.objectQuads)do for i=1,4 do lo=math.min(lo,q[i][2]);hi=math.max(hi,q[i][2])end end
     eq(lo,6,id..' plant base meets tabletop');eq(hi,17,id..' original plant height')
     eq(#new.objectQuads,216,id..' original plant geometry retained')
     print(id..': five kept plant tiles, support6, all216 plant quads unchanged')
    end
   end
  end
 end
end
ok(total>0,'actual generated table instances exercised')
eq(plants,2,'Red and Copycat plant paths exercised')
print(('%d table placements in %d real maps; %d plant stands; %d ownership/support checks passed'):format(total,affected,plants,checks))
