-- Exact bicycle source claims, floor phase, retained wall, and gameplay.
local root=os.getenv('ASTRA_CANDIDATE') or '.'
local baseline=assert(os.getenv('ASTRA_BICYCLE_BASELINE'))
local dir=assert(os.getenv('ASTRA_BICYCLE_ATLASES'))
local T=dofile('tests/astra_stair_fixture.lua');local H,F=T.H,T.F
local data,w,h=H.atlas(dir..'/club.rgba')
local n=0;local function ok(v,s)n=n+1;assert(v,s)end
local function eq(a,b,s)ok(a==b,s..': expected '..tostring(b)..', got '..tostring(a))end
local function same(a,b,s)
 eq(type(a),type(b),s)
 if type(a)=='table' then for k,v in pairs(a)do same(v,b[k],s..'.'..tostring(k))end;for k in pairs(b)do ok(a[k]~=nil,s..' preserves field')end else eq(a,b,s)end
end
local before,after=F.runtime(baseline),F.runtime(root)
local family={floor={{11,12,14},{27,28,9}},wall={{1,2,3},{17,18,19}}}
local wanted={floor={['0,2']=true,['5,2']=true,['1,4']=true,['5,4']=true,['1,8']=true,['1,10']=true},wall={['1,0']=true,['6,0']=true}}
local selected={}
for _,t in ipairs(after.spec.buildings.CLUB)do if t.bicycle then
 local kind=t.tiles[1][1]==11 and 'floor' or 'wall';ok(not selected[kind],'one exact template per bike drawing');selected[kind]=t
 same(t.tiles,family[kind],kind..' exact complete source grid')
end end
eq(selected.floor~=nil,true,'floor model present');eq(selected.wall~=nil,true,'wall model present')
-- The new draw path has no reason to alter tile pins, interaction support,
-- wall mounted fallback, or any map-specific override.
same(after.spec.tilesets,before.spec.tilesets,'all original tileset profiles')
same(after.spec.maps,before.spec.maps,'all original map overrides')
local function full(path,map)
 local r=T.runtime(path,data);local omit={};local records={}
 for _,name in ipairs{'customCourtyards','customPillars','customTrees','customWalls'}do r.module('CommunityVisuals')[name]=function()return false end end
 local function mark(S,first)for i=first+1,#S.objectQuads do omit[S.objectQuads[i]]=true end end
 local stamp=r.build.stamp
 function r.build.stamp(S,mp,q,tx,tz,bw,bh,t)
  local start=#S.objectQuads;local result=stamp(S,mp,q,tx,tz,bw,bh,t)
  if t.bicycle then mark(S,start);records[#records+1]={t=t,tx=tx,tz=tz,bw=bw,bh=bh}end
  return result
 end
 local build=r.stairs.buildObject
 function r.stairs.buildObject(S,mp,region,cluster,...)
  local c=cluster.tiles[1];local bike=S.shapeAt[F.key(c[1],c[2])].class=='bike';local start=#S.objectQuads
  local result=build(S,mp,region,cluster,...);if bike then mark(S,start)end;return result
 end
 local mounted=r.stairs.buildMounted
 function r.stairs.buildMounted(S,...)
  local start=#S.objectQuads;local result=mounted(S,...);mark(S,start);return result
 end
 local scene=r.stairs.forMap(map);local retained={}
 for _,q in ipairs(scene.objectQuads)do if not omit[q]then
  local copy={q[1],q[2],q[3],q[4],shade=q.shade,uv=q.uv or{{q.u,q.v},{q.u,q.v},{q.u,q.v},{q.u,q.v}}};retained[#retained+1]=copy
 end end
 return scene,records,H.triangles(H.mesh(retained))
end
local total={floor=0,wall=0};local allMaps=0
for id,def in pairs(F.maps)do if def.tileset=='CLUB'then
 allMaps=allMaps+1;local map=F.Map.new(def,F.tilesets.CLUB)
 local old,oldRecords,oldMesh=full(baseline,map);local new,records,newMesh=full(root,map)
 local claimed={}
 for _,p in ipairs(records)do
  eq(id,'BIKE_SHOP','only original Bike Shop receives exact bicycle models')
  local kind=p.t.tiles[1][1]==11 and 'floor' or 'wall';local pos=p.tx..','..p.tz
  ok(wanted[kind][pos],'only original bicycle placement '..pos);total[kind]=total[kind]+1
  eq(p.bw,3,'source drawing width remains3 tiles');eq(p.bh,2,'source drawing height remains2 tiles')
  for z=p.tz,p.tz+1 do for x=p.tx,p.tx+2 do
   local k=F.key(x,z);ok(not claimed[k],'no duplicate bicycle ownership');claimed[k]=kind
   eq(map:tileAt(x,z),family[kind][z-p.tz+1][x-p.tx+1],'source map never rewritten')
   if kind=='floor'then
    eq(new.shapeAt[k].class,'building','old floor-bike extractor suppressed');ok(new.skip[k],'old bicycle drawing removed from floor')
    eq(new.ground[k],(x+z)%2==0 and 15 or 31,'restored global checker floor phase')
   else
    eq(new.tileAt[k],6,'old mounted drawing replaced with the original plain wall panel')
    same(new.shapeAt[k],old.shapeAt[k],'same wall shape and height');eq(new.skip[k],old.skip[k],'wall mesh still present');eq(new.ground[k],old.ground[k],'wall floor state unchanged')
   end
   local cx,cz=math.floor(x/2),math.floor(z/2)
   ok(not map:isWalkableCell(cx,cz),'all bicycle drawing cells remain blocked')
   for _,o in ipairs(def.objects or {})do ok(o.x~=cx or o.y~=cz,'no actor/item lies inside bike source claim')end
   for _,warp in ipairs(def.warps or {})do ok(warp.x~=cx or warp.y~=cz,'no exit warp lies inside bike source claim')end
  end end
 end
 for z=0,map.heightCells*2-1 do for x=0,map.widthCells*2-1 do local k=F.key(x,z)
  if not claimed[k]then same(new.shapeAt[k],old.shapeAt[k],id..' unrelated shape');eq(new.skip[k],old.skip[k],id..' unrelated claim');eq(new.ground[k],old.ground[k],id..' unrelated floor');eq(new.tileAt[k],old.tileAt[k],id..' unrelated source donor')end
 end end
 for z=0,map.heightCells-1 do for x=0,map.widthCells-1 do eq(after.scene.groundAt(map,x,z),before.scene.groundAt(map,x,z),id..' every actor support unchanged')end end
 same(newMesh,oldMesh,id..' every non-bicycle emitted triangle, source UV and shade preserved')
end end
eq(allMaps,3,'all three actual CLUB maps checked');eq(total.floor,6,'six original floor bicycles');eq(total.wall,2,'two original wall bicycles')
for _,t in ipairs(before.spec.buildings.CLUB)do
 local current=F.template(after,'CLUB',t.id);same(current,t,'accepted '..t.id..' profile')
 same(H.triangles(H.mesh(H.building(root,t.id,data,w,h,nil,false,'CLUB'))),H.triangles(H.mesh(H.building(baseline,t.id,data,w,h,nil,false,'CLUB'))),'accepted '..t.id..' geometry, source and shading')
end
print(('%d bicycle placement/preservation checks passed;6 floor+2 wall,3 CLUB maps, raw support and all unrelated scene meshes preserved'):format(n))
