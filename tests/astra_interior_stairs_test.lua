-- Independent Mansion source/geometry/warp regression.
local root=os.getenv('ASTRA_CANDIDATE')or'.'
local baseline=assert(os.getenv('ASTRA_STAIRS_BASELINE'))
local T=dofile('tests/astra_stair_fixture.lua');local H,F=T.H,T.F
local before,after=F.runtime(baseline),F.runtime(root)
-- A20 traversed shelf steps have their own live geometry/support regression.
-- This historical scope retains the old49-cell datum without changing pins.
after.spec.tilesets.CAVERN.cave_steps=nil
-- Historical release scope; A19 live tests own the exact new public cells/models.
after.spec.tilesets=H.historicalPublicPins(after.spec.tilesets,before.spec.tilesets)
local Stair=assert(loadfile(root..'/lib/InteriorStairs.lua'))()
local data,w,h=H.atlas(assert(os.getenv('ASTRA_STAIRS_ATLASES'))..'/mansion.rgba')
local checks=0
local function ok(v,m)checks=checks+1;if not v then error('FAIL '..m,0)end end
local function eq(a,b,m)ok(a==b,m..' expected '..tostring(b)..' got '..tostring(a))end
local function same(a,b,m)
 eq(type(a),type(b),m..' type');if type(a)~='table'then eq(a,b,m);return end
 for k,v in pairs(a)do same(v,b[k],m..'.'..tostring(k))end
 for k in pairs(b)do ok(a[k]~=nil,m..' extra key')end
end
same(H.historicalPalletBuildings(after.spec.buildings,before.spec.buildings),before.spec.buildings,'all furniture outside the separately tested A18 Pallet targets stays exact')
same(after.spec.maps,before.spec.maps,'all map-specific support rules stay exact')
for ts,e in pairs(before.spec.tilesets)do if ts~='CAVERN'then
 for k,v in pairs(e)do same(after.spec.tilesets[ts][k],v,'retained pin '..ts..'.'..k)end
 for k in pairs(after.spec.tilesets[ts])do ok(e[k]~=nil or(ts=='MANSION'and(k=='stair_n'or k=='stair_down_n')),'only Mansion direction pins added')end
end end
local rooms={CELADON_MANSION_1F=2,CELADON_MANSION_2F=4,CELADON_MANSION_3F=4,CELADON_MANSION_ROOF=2}
local total,ups,downs=0,0,0
for id,def in pairs(F.maps)do
 local map=F.Map.new(def,F.tilesets[def.tileset]);local pins=after.shapes.forMap(map);local count=0
 for z=0,map.heightCells-1 do for x=0,map.widthCells-1 do
  eq(after.scene.groundAt(map,x,z),before.scene.groundAt(map,x,z),'every real-map actor support unchanged')
  local tile=map:tileAt(x*2,z*2);local shape=after.shapes.at(map,pins,tile,x*2,z*2)
  if shape.class=='stair_n'or shape.class=='stair_down_n'then
   eq(def.tileset,'MANSION','Mansion source only');local down=shape.class=='stair_down_n'
   local grid=down and{{10,11},{26,27}}or{{12,13},{28,29}}
   local S={tileAt={},objectQuads={}}
   for dz=0,1 do for dx=0,1 do eq(map:tileAt(x*2+dx,z*2+dz),grid[dz+1][dx+1],'exact source grid');S.tileAt[F.key(x*2+dx,z*2+dz)]=grid[dz+1][dx+1]end end
   eq(shape.h,16,'source flight height');eq(shape.art,'stair','floor-level warp convention');ok(shape.authored,'authored door-fold precedence');ok(map:isWalkableCell(x,z),'walkable warp')
   local warp=map:warpAtCell(x,z);ok(warp,'actual original warp');local dest=F.maps[warp.def.destMap];local landing=dest.warps[warp.def.destWarp]
   eq(landing.destMap,id,'reciprocal map');eq(landing.destWarp,warp.index,'reciprocal warp index');eq(after.scene.groundAt(map,x,z),0,'warp entry ground0')
   Stair.build(S,map,data,x,z,shape);local q=S.objectQuads;eq(#q,down and 32 or 40,'bounded stair shell cost');local tops=0
   for _,f in ipairs(q)do
    local a,b,c=f[1],f[2],f[3];local u={b[1]-a[1],b[2]-a[2],b[3]-a[3]};local v={c[1]-a[1],c[2]-a[2],c[3]-a[3]};local n={u[2]*v[3]-u[3]*v[2],u[3]*v[1]-u[1]*v[3],u[1]*v[2]-u[2]*v[1]}
    ok(math.abs(n[1])+math.abs(n[2])+math.abs(n[3])>0,'nondegenerate quad')
    local r=f.interiorStairRole;local axis,sign=3,1
    if r:match('tread')then axis,sign=2,-1;tops=tops+1
    elseif r=='side-west'or r=='well-east'then axis,sign=1,-1
    elseif r=='side-east'or r=='well-west'then axis,sign=1,1
    elseif r=='back-up'or r=='riser-down'then axis,sign=3,-1 end
    ok(n[axis]*sign>0,'existing side/tread winding convention')
    for ax=1,3 do
     local lo,hi=math.huge,-math.huge;for _,p in ipairs(f)do lo=math.min(lo,p[ax]);hi=math.max(hi,p[ax]);ok(p[ax]==p[ax]and math.abs(p[ax])<1e6,'finite geometry')end
     ok(hi-lo<=8,'maximum eight-pixel world-curve face');if hi>lo then eq(math.floor((lo+.000001)/8),math.floor((hi-.000001)/8),'split at world lattice')end
    end
    for j,p in ipairs(f)do
     ok(p[1]>=x*16 and p[1]<=(x+1)*16 and p[3]>=z*16 and p[3]<=(z+1)*16,'cell footprint preserved')
     ok(down and p[2]>=-16 and p[2]<=0 or not down and p[2]>=0 and p[2]<=16,'signed flight bounds')
     local uv=f.uv[j];ok(uv[1]>=0 and uv[1]<1 and uv[2]>=0 and uv[2]<1,'valid source UV')
    end
    if r:match('tread')then
     local px=(a[1]+c[1])/2-x*16;local py=(a[3]+c[3])/2-z*16
     eq(a[2],(down and-1 or 1)*(16-math.floor(py/4)*4),'rises/sinks northward')
     for wz=a[3]+.5,c[3]-.5 do for wx=a[1]+.5,c[1]-.5 do
      local px,py=math.floor(wx-x*16),math.floor(wz-z*16)
      local tile=grid[math.floor(py/8)+1][math.floor(px/8)+1];local ex=tile%16*8+px%8;local ey=math.floor(tile/16)*8+py%8
      local fx,fz=(wx-a[1])/(c[1]-a[1]),(wz-a[3])/(c[3]-a[3])
      local ax=(f.uv[1][1]+fx*(f.uv[2][1]-f.uv[1][1])+fz*(f.uv[4][1]-f.uv[1][1]))*w
      local ay=(f.uv[1][2]+fx*(f.uv[2][2]-f.uv[1][2])+fz*(f.uv[4][2]-f.uv[1][2]))*h
      local r,g,b=data:getPixel(math.floor(ax),math.floor(ay));local er,eg,eb=data:getPixel(ex,ey)
      eq(r,er,'original tread red');eq(g,eg,'original tread green');eq(b,eb,'original tread blue')
     end end
    end
   end
   eq(tops,8,'four distinct source treads split into atlas halves');count=count+1;total=total+1;if down then downs=downs+1 else ups=ups+1 end
  end
 end end
 eq(count,rooms[id]or 0,'exact room placement count')
end
-- Public Structures pass: module loading, exact claims and floor-hole rules.
local public=T.runtime(root,data);local oldPublic=T.runtime(baseline,data)
local claimTotal=0
for id,n in pairs(rooms)do
 local map=F.Map.new(F.maps[id],F.tilesets.MANSION);local S=public.render(map);local old=oldPublic.render(map)
 same(S.tileAt,old.tileAt,'public stair pass never rewrites source tiles')
 local wanted,quads={},0
 local pins=after.shapes.forMap(map)
 for z=0,map.heightCells-1 do for x=0,map.widthCells-1 do
  local t=map:tileAt(x*2,z*2);local shape=after.shapes.at(map,pins,t,x*2,z*2)
  if shape.class=='stair_n'or shape.class=='stair_down_n'then
   local down=shape.class=='stair_down_n';quads=quads+(down and 32 or 40)
   for dz=0,1 do for dx=0,1 do
    local k=F.key(x*2+dx,z*2+dz);wanted[k]=true;claimTotal=claimTotal+1
    ok(S.skip[k],'public pass claims each original stair tile')
    if down then eq(S.ground[k],nil,'pit receives no ground sheet')else eq(S.ground[k],false,'rising flight uses common ground')end
   end end
  end
 end end
 eq(#S.objectQuads,quads,'public dispatch emits only intended north stair geometry')
 for k in pairs(S.skip)do ok(wanted[k],'no unrelated tile is claimed')end
 for k in pairs(S.ground)do ok(wanted[k],'no unrelated tile receives a ground override')end
end
eq(claimTotal,48,'exactly48 original source tiles claimed across twelve stairs')
-- The side-view drawings remain byte-for-byte equivalent through dispatch.
for _,family in ipairs({{'REDS_HOUSE_1','reds_house'},{'REDS_HOUSE_2','reds_house'},{'SHIP','ship'}})do
 local image=H.atlas(assert(os.getenv('ASTRA_STAIRS_ATLASES'))..'/'..family[2]..'.rgba')
 local a,b=T.runtime(root,image),T.runtime(baseline,image)
 for id,d in pairs(F.maps)do if d.tileset==family[1]then
  local map=F.Map.new(d,F.tilesets[d.tileset]);local s,t=a.render(map),b.render(map)
  same(s.objectQuads,t.objectQuads,'original Red/Copycat/Ship E/W geometry and UV/shade unchanged')
  same(s.skip,t.skip,'original E/W claims unchanged');same(s.ground,t.ground,'original E/W floor convention unchanged')
 end end
end
eq(total,12,'twelve original stair warps');eq(ups,6,'six upward flights');eq(downs,6,'six downward pits')
print(('Mansion stairs:12 original warps;40/32 quads; all actor supports and accepted furniture exact. %d checks passed'):format(checks))
