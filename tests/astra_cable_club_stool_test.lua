-- Exact cable-club pedestal seats; unchanged bike shop and all other support.
local root=os.getenv('ASTRA_CANDIDATE')or'.';local baseline=assert(os.getenv('ASTRA_FULL_BASELINE'))
local H=dofile('tests/astra_fixture.lua');local F=dofile('tests/astra_scene_fixture.lua')
local before,after=F.runtime(baseline),F.runtime(root);local checks=0
local function ok(v,msg)checks=checks+1;if not v then error('FAIL '..msg,0)end end
local function eq(a,b,msg)ok(a==b,msg..' expected '..tostring(b)..' got '..tostring(a))end
local function same(a,b,msg)
 eq(type(a),type(b),msg..' type');if type(a)~='table'then eq(a,b,msg);return end
 for k,v in pairs(a)do same(v,b[k],msg..'.'..tostring(k))end
 for k in pairs(b)do ok(a[k]~=nil,msg..' no extra '..tostring(k))end
end

local data,w,h=H.atlas(assert(os.getenv('ASTRA_FULL_ATLASES'))..'/club.rgba')
local t=assert(F.template(after,'CLUB','cable_club_stool'))
same(t.tiles,{{42,43},{38,39}},'only exact cable-club cushion drawing')
same(after.spec.tilesets.CLUB.stool,before.spec.tilesets.CLUB.stool,'stool source pool retained')
eq(after.spec.tilesets.CLUB.heights.stool,6,'support pin matches six source elevations')
local emit,m,s=H.building(root,t.id,data,w,h,nil,true,'CLUB');eq(m.ytop+1,6,'physical seat height6')
local layers={52,52,52,88,120,120};local colors={{0,0,0,52},{0,32,0,20},{0,32,0,20},{0,0,0,88},{0,0,120,0},{28,60,0,32}}
local total=0
for y=-1,6 do local n=0;local col={0,0,0,0}
 for z=-1,16 do for x=-1,16 do local i=m.at(x,y,z)
  local mx,mz,rot=m.at(15-x,y,z),m.at(x,y,15-z),m.at(15-z,y,x)
  eq(i~=nil,mx~=nil,'X centered geometry');eq(i~=nil,mz~=nil,'Z centered geometry');eq(i~=nil,rot~=nil,'quarter-turn centered geometry')
  if i then n=n+1;total=total+1;col[s.col[i]+1]=col[s.col[i]+1]+1
   ok(s.inside[i]and math.floor(i/16)>=4 and math.floor(i/16)<=15,'all material comes from actual cushion/pedestal, never floor margin')
   eq(s.col[i],s.col[mx],'X material symmetry');eq(s.col[i],s.col[mz],'Z material symmetry');eq(s.col[i],s.col[rot],'quarter-turn material symmetry')
   ok(y>=0 and y<=5 and x>=2 and x<=13 and z>=2 and z<=13,'seat remains inside its original cell')
   if y<=2 then ok(x>=4 and x<=11 and z>=4 and z<=11,'pedestal is inset equally beneath cushion')end
   if y<5 then ok(m.at(x,y+1,z)~=nil,'every base and fascia column reaches the seat')end
  end
 end end
 eq(n,layers[y+1]or 0,'source-aware layer occupancy');if y>=0 and y<=5 then same(col,colors[y+1],'layer palette roles retained')end
end
eq(total,484,'one complete padded cushion and compact pedestal');local q=emit(m,s,w,h);eq(q.voxels,total,'emitted voxel count');eq(#q,292,'bounded model cost')
local _,zero=H.triangles(H.mesh(q));eq(zero,0,'valid nondegenerate triangles')
-- A21 bikes have live source/placement tests; retain this earlier seat-only contract.
after.spec.buildings.CLUB=H.historicalPublicBuildings(after.spec.buildings,before.spec.buildings).CLUB
local count=0
for id,def in pairs(F.maps)do if def.tileset=='CLUB'then
 local map=F.Map.new(def,F.tilesets.CLUB);local pos=F.matches(t,map)
 local expected=(id=='COLOSSEUM'or id=='TRADE_CENTER')and{{6,8},{12,8}}or{}
 same(pos,expected,'exact four communication-room stools; bike shop unaffected')
 local claims,cells={},{}
 for _,p in ipairs(pos)do count=count+1;cells[(p[1]/2)..':'..(p[2]/2)]=true;for z=0,1 do for x=0,1 do claims[F.key(p[1]+x,p[2]+z)]=true end end end
 local rec={};local stamp=after.build.stamp
 after.build.stamp=function(S,mp,qs,x,z,bw,bh,tt)local first=#S.objectQuads+1;stamp(S,mp,qs,x,z,bw,bh,tt);if tt.id==t.id then rec[#rec+1]={first,#S.objectQuads}end end
 local a,b=F.build(after,map,data,w),F.build(before,map,data,w);after.build.stamp=stamp;eq(#rec,#pos,'each source stool claimed once')
 local drop={};for _,r in ipairs(rec)do eq(r[2]-r[1]+1,#q,'one mesh per stool');for j=r[1],r[2]do drop[j]=true end end
 local kept={};for j,v in ipairs(a.objectQuads)do if not drop[j]then kept[#kept+1]=v end end;same(kept,b.objectQuads,'all accepted bike-shop/other furniture remains exact')
 same(a.tileAt,b.tileAt,'original map source and interaction grid retained')
 for _,field in ipairs({'shapeAt','ground','skip'})do
  for k,v in pairs(b[field])do if not claims[k]then same(a[field][k],v,'all non-target '..field..' exact')end end
  for k,v in pairs(a[field])do if not claims[k]then same(v,b[field][k],'no new non-target '..field)end end
 end
 for k in pairs(claims)do ok(a.skip[k]and a.shapeAt[k].class=='building','only authored stool source art claimed')end
 for z=0,map.heightCells-1 do for x=0,map.widthCells-1 do local bh=before.scene.groundAt(map,x,z)
  if cells[x..':'..z]then eq(bh,8,'old floating support reproduced');eq(after.scene.groundAt(map,x,z),6,'stool cell support equals actual cushion')
  else eq(after.scene.groundAt(map,x,z),bh,'all other gameplay support retained')end
 end end
 for _,o in ipairs(def.objects or{})do eq(after.scene.groundAt(map,o.x,o.y),before.scene.groundAt(map,o.x,o.y),'existing NPC support unchanged')end
end end
eq(count,4,'only four intended communication seats')
print(('%d cable-club checks passed;4 exact seats,484 voxels/292 quads; symmetric source-only cushion; support8 -> 6'):format(checks))
