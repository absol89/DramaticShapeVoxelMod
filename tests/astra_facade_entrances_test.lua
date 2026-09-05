-- Exact-map rear entries; only presentation changes, with no fabricated warps.
local root=os.getenv('ASTRA_CANDIDATE') or '.'
local F=dofile(root..'/tests/astra_scene_fixture.lua')
local H=dofile(root..'/tests/astra_fixture.lua')
local atlas=assert(os.getenv('ASTRA_ENTRANCE_ATLASES'),'ASTRA_ENTRANCE_ATLASES directory with overworld.rgba and plateau.rgba')
local data,w=H.atlas(atlas..'/overworld.rgba')
local plate,pw=H.atlas(atlas..'/plateau.rgba')
local E=assert(loadfile(root..'/lib/FacadeEntrances.lua'))()
local spec=dofile(root..'/data/voxel_heights.lua')
local checks=0
local function ok(v,m)checks=checks+1;assert(v,m)end
local function clone(v)if type(v)~='table'then return v end;local o={};for k,x in pairs(v)do o[k]=clone(x)end;return o end
local function same(a,b,m)
 ok(type(a)==type(b),m..' type')
 if type(a)~='table'then ok(a==b,m);return end
 for k,v in pairs(a)do same(v,b[k],m..'.'..tostring(k))end
 for k in pairs(b)do ok(a[k]~=nil,m..' missing')end
end
local targets={
 {'CERULEAN_CITY','gabled_house_wide',16,20,12,4,{{9,9}}},
 {'CERULEAN_CITY','gabled_house_wide',52,20,12,4,{{27,9}}},
 {'CELADON_CITY','celadon_mansion',44,8,12,12,{{24,3},{25,3}}},
 {'ROUTE_5','route_5_gate',12,60,16,8,{{9,29},{10,29}}},
 {'ROUTE_6','celadon_mansion',16,4,12,12,{{9,1},{10,1}}},
 {'ROUTE_12','celadon_mansion',16,32,12,12,{{10,15},{11,15}}},
 {'FUCHSIA_CITY','gabled_house',60,50,8,6,{{31,24}}},
}
local count=0
local function state()return {outdoor=true,objectQuads={},ground={sentinel=7},skip={sentinel=true}}end
local function inspect(S,cells,z,d,width)
 local minx=cells[1][1]*16;local maxx=(cells[#cells][1]+1)*16
 local fronts={};local n=0
 for _,q in ipairs(S.objectQuads)do
  ok(q.own==true,'own geometry survives map seams')
  ok(q.shade>0 and q.shade<=1,'valid directional shade')
  for i,v in ipairs(q)do
   ok(v[1]>=minx and v[1]<=maxx,'aligned x span')
   ok(v[2]>=0 and v[2]<=16,'source16px height')
   ok(v[3]<z and v[3]>=z-1.12,'shallow relief outside exact rear wall')
   ok(q.uv[i][1]>0 and q.uv[i][1]<1 and q.uv[i][2]>0 and q.uv[i][2]<1,'valid donor UV')
  end
  if q.shade==.68 then
   local ax,ay=q[2][1]-q[1][1],q[2][2]-q[1][2]
   local bx,by=q[3][1]-q[1][1],q[3][2]-q[1][2]
   ok(ax*by-ay*bx<0,'north face winds outward')
   ok(q[1][1]-q[2][1]<=8,'curved-world8px run cap')
   for x=q[2][1],q[1][1]-1 do
    local sy=15-q[1][2];local sx=(x-minx)%16
    local key=x..':'..sy;ok(not fronts[key],'no overlapping front texel');fronts[key]=true;n=n+1
    local u=q.uv[2][1]+(q.uv[1][1]-q.uv[2][1])*(x+.5-q[2][1])/(q[1][1]-q[2][1])
    local vv=(q.uv[2][2]+q.uv[3][2])*.5
    local aw,ah=d:getDimensions();local dx,dy=math.floor(u*aw),math.floor(vv*ah)
    local tile=(sy<8 and 11 or 27)+math.floor(sx/8)
    ok(dx==(tile%(width/8))*8+sx%8 and dy==math.floor(tile/(width/8))*8+sy%8,'exact source texel on north face')
   end
  end
 end
 ok(n==#cells*256,'all source door texels once')
 same(S.ground,{sentinel=7},'ground unchanged');same(S.skip,{sentinel=true},'claims unchanged')
 ok(#S.objectQuads<#cells*300,'bounded relief cost')
end
for _,v in ipairs(targets)do
 local def=clone(F.maps[v[1]]);local before=clone(def);local map=F.Map.new(def,F.tilesets[def.tileset])
 local t;for _,q in ipairs(spec.buildings.OVERWORLD)do if q.id==v[2]then t=q end end;ok(t~=nil,'template exists')
 for dy,row in ipairs(t.tiles)do for dx,tile in ipairs(row)do ok(map:tileAt(v[3]+dx-1,v[4]+dy-1)==tile,'real building footprint')end end
 local function stamp(S,m,tx)return E.stamp(S,m,data,w/8,tx or v[3],v[4],v[5],v[6],t)end
 local S=state();S.outdoor=F.Map.isOutdoor(def);local added=stamp(S,map);ok(added>0 and added==#S.objectQuads,'rear entry added')
 inspect(S,v[7],v[4]*8,data,w);count=count+added
 ok(stamp(S,map)==0,'duplicate hook cannot duplicate doors')
 same(def,before,'engine source data unchanged')
 ok(stamp(state(),map,v[3]+2)==0,'wrong placement no-op')
 local indoor=state();indoor.outdoor=false;ok(stamp(indoor,map)==0,'indoor fallback no-op')
 local changed=clone(def)
 for _,warp in ipairs(changed.warps)do if warp.x==v[7][1][1] and warp.y==v[7][1][2]then warp.destWarp=99 end end
 ok(stamp(state(),F.Map.new(changed,F.tilesets[def.tileset]))==0,'changed destination disables entire doorway group')
 local missing=clone(def)
 for i=#missing.warps,1,-1 do if missing.warps[i].x==v[7][1][1] and missing.warps[i].y==v[7][1][2]then table.remove(missing.warps,i)end end
 ok(stamp(state(),F.Map.new(missing,F.tilesets[def.tileset]))==0,'missing warp disables entire doorway group')
 ok(E.stamp(state(),map,nil,w/8,v[3],v[4],v[5],v[6],t)==0,'missing atlas no-op')
end
for _,v in ipairs({{'FUCHSIA_CITY','gabled_house',52,50,8,6},{'CELADON_CITY','celadon_mart',12,12,16,16},{'ROUTE_7','flat_block_6x4',24,16,12,8},{'ROUTE_8','flat_block_6x4',4,16,12,8}})do
 local def=F.maps[v[1]];local map=F.Map.new(def,F.tilesets[def.tileset]);local S=state()
 ok(E.stamp(S,map,data,w/8,v[3],v[4],v[5],v[6],{id=v[2]})==0,'no invented rear or duplicate existing side door '..v[1]);ok(#S.objectQuads==0,'negative unchanged')
end
local pd=clone(F.maps.ROUTE_23);local old=clone(pd);local pm=F.Map.new(pd,F.tilesets.PLATEAU);local S=state()
S.outdoor=F.Map.isOutdoor(pd);ok(S.outdoor==false,'actual PLATEAU outdoor/SFX classification')
local pn=E.build(S,pm,plate,pw/8);ok(pn>0,'real Route23 gate rear');inspect(S,{{7,139},{8,139}},2240,plate,pw)
same(pd,old,'plateau warps/collision blocks unchanged');ok(E.build(S,pm,plate,pw/8)==0,'plateau duplicate no-op')
local wrong=F.Map.new(clone(pd),F.tilesets.PLATEAU);wrong.def.warps[2].destMap='WRONG';ok(E.build(state(),wrong,plate,pw/8)==0,'plateau destination guard')
local badroof=F.Map.new(clone(pd),F.tilesets.PLATEAU);local tileAt=badroof.tileAt
badroof.tileAt=function(self,x,y)if x==14 and y==280 then return 0 end;return tileAt(self,x,y)end
ok(E.build(state(),badroof,plate,pw/8)==0,'roof frontage guard')
print('Facade entrances: '..checks..' checks; '..count..' rear-house quads + '..pn..' Route23 quads; real-map mocked geometry, not native gameplay.')
