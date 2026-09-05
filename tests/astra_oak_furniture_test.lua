-- Oak's tables: exact source materials, symmetric supports, and unchanged
-- equipment/actor semantics tested through the normal Buildings pipeline.
local H=dofile('tests/astra_fixture.lua')
local F=dofile('tests/astra_scene_fixture.lua')
local root=os.getenv('ASTRA_CANDIDATE')or'.'
local baseline=assert(os.getenv('ASTRA_PALLET_BASELINE'))
local atlas=assert(os.getenv('ASTRA_FURNITURE_ATLASES'))..'/gym.rgba'
local data,aw,ah=H.atlas(atlas)
local n=0
local function check(v,msg)n=n+1;assert(v,msg)end
local function equal(a,b,path)
 if type(a)~='table'then check(a==b,path);return end
 check(type(b)=='table',path..' table')
 for k,v in pairs(a)do equal(v,b[k],path..'.'..tostring(k))end
 for k in pairs(b)do check(a[k]~=nil,path..' added '..tostring(k))end
end
local changed={lab_table=true,lab_table_small=true,lab_computers=true}
local now,old=F.runtime(root),F.runtime(baseline)
equal(H.historicalPublicPins(now.spec.tilesets,old.spec.tilesets).DOJO,old.spec.tilesets.DOJO,'DOJO support pins')
equal(now.spec.maps.OAKS_LAB,old.spec.maps.OAKS_LAB,'Oak map rules')
for _,id in ipairs({'lab_table','lab_table_small','lab_computers'})do
 local _,m,sp=H.building(root,id,data,aw,ah,nil,true,'DOJO')
 local _,before,bsp=H.building(baseline,id,data,aw,ah,nil,true,'DOJO')
 local w=id=='lab_table'and 48 or 32
 check(m.W==w and m.zmin==0 and m.zmax==15,id..' footprint')
 check(m.ytop==(id=='lab_computers'and 13 or 5),id..' elevation')
 local function color(x,y,z)local i=m.at(x,y,z);if i then check(sp.inside[i],id..' donor outside drawing');return sp.col[i]end end
 for y=0,5 do for z=0,15 do for x=0,w-1 do
  local c=color(x,y,z)
  check(c==color(w-1-x,y,z),id..' horizontal symmetry')
  check(c==color(x,y,15-z),id..' depth symmetry')
  local foot=(x>=2 and x<=5 or x>=w-6 and x<=w-3)and(z>=2 and z<=5 or z>=10 and z<=13)
  local apron=x>=2 and x<=w-3 and z>=2 and z<=13
  check((c~=nil)==(y>=3 or(y==2 and apron)or(y<2 and foot)),id..' four feet/equal overhang')
  if y==5 then
   local expect=(x==0 or x==w-1 or z==0 or z==15)and 3 or ((x==1 or x==w-2 or z==1 or z==14)and 0 or 1)
   check(c==expect,id..' closed black/white/field rings')
  end
 end end end
 if id=='lab_computers'then
  -- The original front, rear, caps, recesses, keys and paper are exact.
  for y=6,math.max(before.ytop,m.ytop)do for z=0,15 do for x=0,w-1 do
   check(m.at(x,y,z)==before.at(x,y,z),'computer equipment or donor changed')
  end end end
 else
  for z=0,15 do for x=0,w-1 do check(m.at(x,6,z)==nil,id..' above tabletop')end end
 end
 local quads=H.building(root,id,data,aw,ah,nil,false,'DOJO')
 for _,q in ipairs(quads)do
  for axis=1,3 do
   local lo,hi=math.huge,-math.huge
   for i=1,4 do local v=q[i][axis];check(v==v and math.abs(v)<1000,'finite surface');lo=math.min(lo,v);hi=math.max(hi,v)end
   check(hi-lo<=8.000001,'eight-pixel surface split')
  end
 end
 local _,zero=H.triangles(H.mesh(quads));check(zero==0,'degenerate quads')
 print(id..': '..#quads..' quads; even overhang/four feet, complete white rim, source-only material')
end
local placements,maps=0,0
for _,def in pairs(F.maps)do if def.tileset=='DOJO'then
 maps=maps+1;local map=F.Map.new(def,F.tilesets.DOJO)
 local a,b=F.build(now,map,data,aw),F.build(old,map,data,aw)
 equal(a.skip,b.skip,map.id..' claims');equal(a.ground,b.ground,map.id..' ground')
 for z=0,map.heightCells-1 do for x=0,map.widthCells-1 do
  check(now.scene.groundAt(map,x,z)==old.scene.groundAt(map,x,z),map.id..' actor support')
 end end
 for _,t in ipairs(now.spec.buildings.DOJO)do if changed[t.id]then
  for _,pos in ipairs(F.matches(t,map))do placements=placements+1;check(map.id=='OAKS_LAB','unexpected table placement')end
 end end
end end
check(placements==3,'exact three Oak tables');check(maps==3,'three shared DOJO maps checked')
print(n..' Oak table geometry/source/placement checks passed;3 exact placements, all shared actor rules and above-desk equipment preserved')
