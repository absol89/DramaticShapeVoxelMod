-- Exact Red/Copycat object ownership, with original gameplay and all
-- remaining authored/generic props preserved through the public room pass.
local root=os.getenv('ASTRA_CANDIDATE')or'.'
local baseline=assert(os.getenv('ASTRA_PALLET_BASELINE'))
local H=dofile('tests/astra_fixture.lua');local F=dofile('tests/astra_scene_fixture.lua')
local T=dofile('tests/astra_stair_fixture.lua')
local data,w,h=H.atlas(assert(os.getenv('ASTRA_PALLET_ATLASES'))..'/reds_house.rgba')
local before,after=F.runtime(baseline),F.runtime(root)
local n=0
local function ok(v,msg)n=n+1;assert(v,msg)end
local function same(a,b,msg)
 ok(type(a)==type(b),msg..' type')
 if type(a)~='table'then ok(a==b,msg);return end
 for k,v in pairs(a)do same(v,b[k],msg..'.'..tostring(k))end
 for k in pairs(b)do ok(a[k]~=nil,msg..' unexpected '..tostring(k))end
end
local function copy(a)if type(a)~='table'then return a end;local b={};for k,v in pairs(a)do b[k]=copy(v)end;return b end
local targets={reds_pc={tiles={{64,65},{32,33},{66,67},{50,51}},support=12},
 reds_tv={tiles={{6,7},{22,23}}},
 reds_bed={tiles={{45,46},{61,62},{61,62},{63,47}},support=7},
 reds_short_table={tiles={{38,39,39,41},{44,42,42,43},{60,58,58,59}},support=12}}
local wanted={
 REDS_HOUSE_1F={reds_tv={6,2}},COPYCATS_HOUSE_1F={reds_tv={6,2}},
 REDS_HOUSE_2F={reds_pc={0,0},reds_tv={6,8},reds_bed={0,12},reds_short_table={2,1}},
 COPYCATS_HOUSE_2F={reds_pc={0,0},reds_tv={6,8},reds_bed={0,12},reds_short_table={2,1}}}
same(after.spec.heights,before.spec.heights,'all original class heights')
same(H.historicalPublicPins(after.spec.tilesets,before.spec.tilesets),before.spec.tilesets,'all actual tile pools and actor support pins')
same(after.spec.maps,before.spec.maps,'all actual map rules')
local function full(path,map,isNew)
 local r=T.runtime(path,data)
 local community=r.module('CommunityVisuals')
 for _,name in ipairs({'customCourtyards','customPillars','customTrees','customWalls'})do community[name]=function()return false end end
 r.module('BuildBudget').check=function()end
 local omit={}
 local stamp=r.build.stamp
 r.build.stamp=function(S,mp,quads,x,z,bw,bh,t)
  local first=#S.objectQuads+1
  stamp(S,mp,quads,x,z,bw,bh,t)
  if isNew and targets[t.id]then for i=first,#S.objectQuads do omit[i]=true end end
 end
 local buildObject=r.stairs.buildObject
 r.stairs.buildObject=function(S,mp,region,cluster,...)
  local first=#S.objectQuads+1
  local result=buildObject(S,mp,region,cluster,...)
  if result and not isNew then
   local room=wanted[map.id]
   for _,id in ipairs({'reds_tv','reds_pc'})do
    local p=room[id]
    if p and cluster.minX==p[1]and cluster.minY==p[2]
       and cluster.maxX==p[1]+1 and cluster.maxY==p[2]+1 then
      for i=first,#S.objectQuads do omit[i]=true end
    end
   end
  end
  return result
 end
 local S=r.stairs.forMap(map)
 local retained={}
 for i,q in ipairs(S.objectQuads)do if not omit[i]then retained[#retained+1]=q end end
 return S,retained
end
local maps,instances,tiles=0,0,0
for id,def in pairs(F.maps)do if def.tileset=='REDS_HOUSE_1'or def.tileset=='REDS_HOUSE_2'then
 maps=maps+1;ok(wanted[id]~=nil,'only the four existing Red/Copycat rooms use this family')
 local original=copy(def)
 local map=F.Map.new(def,F.tilesets[def.tileset])
 local claims,expected={},{ }
 for name,c in pairs(targets)do
  local t=F.template(after,def.tileset,name)
  if t then
   same(t.tiles,c.tiles,name..' exact source-grid identity')
   same(t.support,c.support,name..' authored object support')
   local pos=F.matches(t,map);local want=wanted[id][name]
   ok(#pos==(want and 1 or 0),id..' exact '..name..' occurrence')
   if want then
    instances=instances+1;same(pos[1],want,id..' source origin')
    expected[name]=true
    for z=0,#t.tiles-1 do for x=0,#t.tiles[1]-1 do
     local k=F.key(want[1]+x,want[2]+z);ok(not claims[k],id..' no overlapping template claims')
     claims[k]=name;tiles=tiles+1
    end end
   end
  else ok(wanted[id][name]==nil,'required source template exists')end
 end
 local records={};local stamp=after.build.stamp
 after.build.stamp=function(S,mp,q,x,z,bw,bh,t)
  local first=#S.objectQuads+1;stamp(S,mp,q,x,z,bw,bh,t)
  if targets[t.id]then records[#records+1]={id=t.id,x=x,z=z,first=first,last=#S.objectQuads}end
 end
 local a,b=F.build(after,map,data,w),F.build(before,map,data,w);after.build.stamp=stamp
 local omitted={}
 for _,rec in ipairs(records)do
  ok(expected[rec.id],id..' one normal-pass stamp per fixture');expected[rec.id]=nil
  same({rec.x,rec.z},wanted[id][rec.id],id..' actual stamp origin')
  for i=rec.first,rec.last do omitted[i]=true end
 end
 ok(next(expected)==nil,id..' all intended models are actually emitted')
 local kept={};for i,q in ipairs(a.objectQuads)do if not omitted[i]then kept[#kept+1]=q end end
 same(kept,b.objectQuads,id..' old authored chair/table/bookcase geometry UV and shade')
 same(a.tileAt,b.tileAt,id..' original source grid')
 for _,field in ipairs({'shapeAt','ground','skip'})do
  for k,v in pairs(a[field])do if not claims[k]then same(v,b[field][k],id..' unchanged outside claims '..field)end end
  for k,v in pairs(b[field])do if not claims[k]then same(a[field][k],v,id..' retained outside claims '..field)end end
 end
 for k,name in pairs(claims)do
  ok(a.skip[k]and a.shapeAt[k].class=='building',id..' no generic second copy inside '..name)
  ok(a.shapeAt[k].h==(targets[name].support or 0),id..' explicit model support')
 end
 for z=0,map.heightCells-1 do for x=0,map.widthCells-1 do
  ok(after.scene.groundAt(map,x,z)==before.scene.groundAt(map,x,z),id..' every actor height retained')
  local tile=map:cellTile(x,z)
  local sa=after.shapes.forMap(map)[tile];local sb=before.shapes.forMap(map)[tile]
  same(sa,sb,id..' original collision-cell pin')
 end end
 local af,ar=full(root,map,true);local bf,br=full(baseline,map,false)
 same(ar,br,id..' all retained public-pass prop/console/palm/stair/plant quads')
 same(af.roundStamps,bf.roundStamps,id..' original rounded scenery stamps')
 for z=0,def.height*4-1 do for x=0,def.width*4-1 do
  local k=F.key(x,z)
  if not claims[k]then
   same(af.tileAt[k],bf.tileAt[k],id..' full-pass source outside new ownership')
   same(af.shapeAt[k],bf.shapeAt[k],id..' full-pass shape outside new ownership')
   same(af.skip[k],bf.skip[k],id..' full-pass skip outside new ownership')
   same(af.ground[k],bf.ground[k],id..' full-pass floor outside new ownership')
  end
 end end
 same(def,original,id..' source map, objects, signs and warp definitions never mutated')
 print(id..': exact fixture claims; original actors/interactions and all other prop meshes preserved')
end end
ok(maps==4,'exact four shared rooms reviewed')
ok(instances==10,'four TVs, two PCs, two beds and two short tables')
ok(tiles==72,'only72 original source tiles gain complete model ownership')
print(n..' Red/Copycat placement and preservation checks passed;10 models/72 claimed tiles, all gameplay/support and remaining meshes exact')
