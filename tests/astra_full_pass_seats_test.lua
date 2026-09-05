-- Source-aware LOBBY/MUSEUM seats and their exact actual ride-height changes.
local root=os.getenv('ASTRA_CANDIDATE')or'.'
local baseline=assert(os.getenv('ASTRA_FULL_BASELINE'))
local atlasDir=assert(os.getenv('ASTRA_FULL_ATLASES'))
local H=dofile('tests/astra_fixture.lua');local F=dofile('tests/astra_scene_fixture.lua')
local before,after=F.runtime(baseline),F.runtime(root)
-- A19 public stair cells have a separate live exact-warp/source regression.
after.spec.tilesets=H.historicalPublicPins(after.spec.tilesets,before.spec.tilesets)
local checks=0
local function ok(v,msg)checks=checks+1;if not v then error('FAIL '..msg,0)end end
local function eq(a,b,msg)ok(a==b,msg..' expected '..tostring(b)..' got '..tostring(a))end
local function same(a,b,msg)
 eq(type(a),type(b),msg..' type')
 if type(a)~='table'then eq(a,b,msg);return end
 for k,v in pairs(a)do same(v,b[k],msg..'.'..tostring(k))end
 for k in pairs(b)do ok(a[k]~=nil,msg..' no extra '..tostring(k))end
end
local cases={
 {family='LOBBY',id='lobby_stool',atlas='lobby',tiles={{7,8},{23,24}},top=4,bottom=14,quads=204,n=59,maps={CELADON_DINER=11,CELADON_MART_1F=4,CELADON_MART_ROOF=8,GAME_CORNER=36}},
 {family='MUSEUM',id='museum_stool',atlas='gate',tiles={{2,3},{18,19}},top=5,bottom=15,quads=196,n=2,maps={MUSEUM_1F=2}},
}
local expectedTable={CELADON_DINER={{0,4},{0,10}},CELADON_MART_ROOF={{8,4},{16,8}}}
local function copy(v)
 if type(v)~='table'then return v end
 local o={};for k,x in pairs(v)do o[k]=copy(x)end;return o
end
same(after.spec.heights,before.spec.heights,'all global class heights retained')
same(after.spec.maps,before.spec.maps,'all prior map-specific overrides retained')
-- A17 stair changes have their own exact source/placement regressions.
local historicalStairs=H.historicalStairPins(after.spec.tilesets,before.spec.tilesets)
for family,old in pairs(before.spec.tilesets)do
 local allowed=copy(old)
 if family=='LOBBY'or family=='MUSEUM'then allowed.heights=allowed.heights or{};allowed.heights.stool=5 end
 if family=='CLUB'then allowed.heights=allowed.heights or{};allowed.heights.stool=6 end
 same(historicalStairs[family],allowed,'complete tileset profile permits only the three approved seat-height fields: '..family)
end
for family in pairs(after.spec.tilesets)do ok(before.spec.tilesets[family]~=nil or family=='BEACH_HOUSE','only separately tested BeachHouse may add a new tileset profile')end

local additions={['LOBBY/lobby_stool']=true,['LOBBY/lobby_round_table']=true,['MUSEUM/museum_stool']=true,['CLUB/cable_club_stool']=true,['BEACH_HOUSE/beach_stool']=true,['BEACH_HOUSE/beach_table']=true,['BEACH_HOUSE/beach_pc']=true}
local added=0
for family,list in pairs(H.historicalPalletBuildings(after.spec.buildings,before.spec.buildings))do
 local old={};for _,t in ipairs(before.spec.buildings[family]or{})do old[t.id]=t end
 for _,t in ipairs(list)do
  if old[t.id]then same(t,old[t.id],'every previously accepted authored profile retained exactly: '..family..'/'..t.id);old[t.id]=nil
  else ok(additions[family..'/'..t.id],'only seven explicitly tested full-pass models may be added');added=added+1 end
 end
 eq(next(old),nil,'no previous authored model is deleted')
end
for family in pairs(before.spec.buildings)do ok(after.spec.buildings[family]~=nil,'no existing authored family is deleted')end
eq(added,7,'exact seven new source-grid templates')

local total,changedSupport,seatedActors=0,0,0
for _,c in ipairs(cases)do
 local t=assert(F.template(after,c.family,c.id),'exact full-pass seat required')
 same(t.tiles,c.tiles,c.family..' exact original seat source grid')
 same(after.spec.tilesets[c.family].stool,before.spec.tilesets[c.family].stool,c.family..' stool tile pool stays exact')
 eq(after.spec.tilesets[c.family].heights.stool,5,c.family..' only full-seat ride height becomes five')
 local data,w,h=H.atlas(atlasDir..'/'..c.atlas..'.rgba')
 local emit,m,s=H.building(root,c.id,data,w,h,nil,true,c.family)
 eq(m.ytop+1,5,'physical cushion agrees with the new ride height')
 local count,seat,legs=0,0,0
 for y=-1,7 do for z=-1,16 do for x=-1,16 do
  local support=y>=0 and y<=3 and((x>=3 and x<=4)or(x>=11 and x<=12))and((z>=5 and z<=6)or(z>=10 and z<=11))
  local lid=y==4 and x>=2 and x<=13 and z>=3 and z<=13
  local i=m.at(x,y,z);eq(i~=nil,not not(support or lid),'only one level seat and four inset posts occupy the source cell')
  if i~=nil then
   count=count+1;ok(s.inside[i],'donor belongs to original furniture silhouette')
   local sx,sy=i%16,math.floor(i/16)
   ok(sx>=2 and sx<=13 and sy>=c.top and sy<=c.bottom,'no floor dither or neighboring fixture becomes material')
   if lid then
    seat=seat+1;local d=math.min(x-2,13-x,z-3,13-z);eq(s.col[i],d==0 and 3 or(d<=2 and 0 or 1),'black rim1, equal white padding2, centered gray6x5')
    eq(s.col[i],s.col[m.at(15-x,y,z)],'top X palette symmetry');eq(s.col[i],s.col[m.at(x,y,16-z)],'top Z palette symmetry')
   else legs=legs+1;eq(sy,c.bottom-y,'support uses its original elevation row');ok(m.at(x,y+1,z)~=nil,'each support remains connected to the seat')end
  end
 end end end
 eq(count,196,'one closed132-cell cushion and64 support voxels');eq(seat,132,'complete top');eq(legs,64,'four2x2 posts through four layers')
 local q=emit(m,s,w,h);eq(q.voxels,count,'emitter agrees with exact tested occupancy');eq(#q,c.quads,'bounded source-specific seat render cost')
 local _,zero=H.triangles(H.mesh(q));eq(zero,0,'no degenerate submitted seat triangles')
 local n=0
 for id,def in pairs(F.maps)do if def.tileset==c.family then
  local map=F.Map.new(def,F.tilesets[c.family]);local pos=F.matches(t,map);eq(#pos,c.maps[id]or 0,'exact seat count in '..id)
  local chairTiles,chairCells,otherTiles={},{},{}
  for _,p in ipairs(pos)do
   n=n+1;total=total+1;chairCells[(p[1]/2)..':'..(p[2]/2)]=true
   for z=0,1 do for x=0,1 do chairTiles[F.key(p[1]+x,p[2]+z)]=true end end
  end
  local tableTemplate=F.template(after,c.family,'lobby_round_table')
  if tableTemplate then
   local tp=F.matches(tableTemplate,map);same(tp,expectedTable[id]or{},'only separately approved round tables can add other claims')
   for _,p in ipairs(tp)do for z=0,3 do for x=0,3 do otherTiles[F.key(p[1]+x,p[2]+z)]=true end end end
  end
  local oldShapes,newShapes=before.shapes.forMap(map),after.shapes.forMap(map)
  for z=0,def.height*4-1 do for x=0,def.width*4-1 do local tile=map:tileAt(x,z)
   if chairTiles[F.key(x,z)]then eq(newShapes[tile].h,5,'every matched seat tile has ride height5')
   else same(after.shapes.at(map,newShapes,tile,x,z),before.shapes.at(map,oldShapes,tile,x,z),'all other actual source shapes remain exact')end
  end end
  local records={};local stamp=after.build.stamp
  after.build.stamp=function(S,mp,faces,x,z,bw,bh,template)
   local first=#S.objectQuads+1;stamp(S,mp,faces,x,z,bw,bh,template)
   if template.id==c.id or template.id=='lobby_round_table'then records[#records+1]={id=template.id,first=first,last=#S.objectQuads}end
  end
  local a,b=F.build(after,map,data,w),F.build(before,map,data,w);after.build.stamp=stamp
  local skip,actualSeats={},0
  for _,r in ipairs(records)do
   if r.id==c.id then actualSeats=actualSeats+1;eq(r.last-r.first+1,c.quads,'one authored seat per source grid')end
   for j=r.first,r.last do skip[j]=true end
  end
  eq(actualSeats,#pos,'all source chairs stamp exactly once')
  local retained={};for j,v in ipairs(a.objectQuads)do if not skip[j]then retained[#retained+1]=v end end
  same(retained,b.objectQuads,'all previously accepted object geometry/UV/shade stays exact')
  same(a.tileAt,b.tileAt,'no source map art changes')
  for _,field in ipairs({'shapeAt','ground','skip'})do
   for k,v in pairs(b[field])do if not chairTiles[k]and not otherTiles[k]then same(a[field][k],v,'all non-approved '..field..' remains exact')end end
   for k,v in pairs(a[field])do if not chairTiles[k]and not otherTiles[k]then same(v,b[field][k],'no extra non-approved '..field)end end
  end
  for k in pairs(chairTiles)do ok(a.skip[k],'new model claims all old upright seat art');eq(a.shapeAt[k].class,'building','only seat cells change ownership')end
  for z=0,map.heightCells-1 do for x=0,map.widthCells-1 do
   local oldH,newH=before.scene.groundAt(map,x,z),after.scene.groundAt(map,x,z)
   if chairCells[x..':'..z]then changedSupport=changedSupport+1;eq(oldH,8,'original seat ride8 reproduced');eq(newH,5,'rider meets physical seat5')
   else eq(newH,oldH,'every other actor support remains exact, including blocked round-table cells')end
  end end
  for _,o in ipairs(def.objects or{})do if chairCells[o.x..':'..o.y]then seatedActors=seatedActors+1;eq(after.scene.groundAt(map,o.x,o.y),5,'real seated actor meets new cushion')end end
 end end
 eq(n,c.n,'all intended family placements exercised')
 print(c.family..'/'..c.id..': '..n..' exact seats;196 voxels/'..c.quads..' quads; support8 -> physical/pinned5; source-only symmetrical top')
end
eq(total,61,'exactly61 selected seats');eq(changedSupport,61,'only61 actual seat support cells change');ok(seatedActors>0,'real seated NPCs exercised')
print(('%d full-pass seat checks passed;61 seats; %d seated NPCs; all other support preserved'):format(checks,seatedActors))
