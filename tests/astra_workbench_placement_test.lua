local root=os.getenv('ASTRA_CANDIDATE')or'.';local old=assert(os.getenv('ASTRA_PUBLIC_BASELINE'))
local atlas=assert(os.getenv('ASTRA_FULL_ATLASES'))
local H=dofile('tests/astra_fixture.lua');local F=dofile('tests/astra_scene_fixture.lua');local T=dofile('tests/astra_stair_fixture.lua')
local a,b=F.runtime(root),F.runtime(old);local n=0
local function ok(v,m)n=n+1;assert(v,m)end
local function eq(x,y,m)ok(type(x)==type(y),m..' type');if type(x)~='table'then ok(x==y,m);return end;for k,v in pairs(x)do eq(v,y[k],m)end;for k in pairs(y)do ok(x[k]~=nil,m..' extra')end end
local function copy(x)if type(x)~='table'then return x end;local o={};for k,v in pairs(x)do o[k]=copy(v)end;return o end
local targets={lab_workbench=true,warden_workbench=true,mansion_workbench=true}
local wanted={CINNABAR_LAB_FOSSIL_ROOM={{'lab_workbench',0,8},{'lab_workbench',4,8}},CINNABAR_LAB_METRONOME_ROOM={{'lab_workbench',0,8}},WARDENS_HOUSE={{'warden_workbench',0,4}},CELADON_MANSION_2F={{'mansion_workbench',0,10}},CELADON_MANSION_3F={{'mansion_workbench',0,6},{'mansion_workbench',6,6},{'mansion_workbench',0,12}}}
local seenMaps,instances,claimed=0,0,0
for id,def in pairs(F.maps)do if def.tileset=='LAB'or def.tileset=='MANSION'then
 local original=copy(def);local map=F.Map.new(def,F.tilesets[def.tileset]);local data,w,h=H.atlas(atlas..'/'..def.tileset:lower()..'.rgba')
 local expect={};for _,p in ipairs(wanted[id]or{})do expect[p[1]..':'..p[2]..':'..p[3]]=true end
 local claims={};for _,t in ipairs(a.spec.buildings[def.tileset])do if targets[t.id]then
  for _,p in ipairs(F.matches(t,map))do
   local tag=t.id..':'..p[1]..':'..p[2];ok(expect[tag],id..' exact whole object match');expect[tag]=nil;instances=instances+1
   for z=0,3 do for x=0,3 do local k=F.key(p[1]+x,p[2]+z);ok(not claims[k],'nonoverlap claims');claims[k]=true;claimed=claimed+1 end end
   ok(a.scene.groundAt(map,p[1]/2,p[2]/2)==12,'desktop actor support remains12')
   ok(a.scene.groundAt(map,p[1]/2,p[2]/2+1)==8,'chair actor support remains8')
  end
 end end
 ok(next(expect)==nil,'all8 documented placements found')
 local records={};local stamp=a.build.stamp;a.build.stamp=function(S,mp,q,x,z,bw,bh,t)
  local first=#S.objectQuads+1;stamp(S,mp,q,x,z,bw,bh,t);if targets[t.id]then for i=first,#S.objectQuads do records[i]=true end end
 end
 local sa,sb=F.build(a,map,data,w),F.build(b,map,data,w);a.build.stamp=stamp
 local retained={};for i,q in ipairs(sa.objectQuads)do if not records[i]then retained[#retained+1]=q end end
 eq(retained,sb.objectQuads,id..' every prior authored furniture model exact')
 eq(sa.tileAt,sb.tileAt,id..' original source grid unchanged')
 for _,field in ipairs({'shapeAt','skip','ground'})do for k,v in pairs(sa[field])do if not claims[k]then eq(v,sb[field][k],id..' outside claims '..field)end end;for k,v in pairs(sb[field])do if not claims[k]then eq(sa[field][k],v,id..' retained '..field)end end end
 for k in pairs(claims)do
  ok(sa.skip[k]and sa.shapeAt[k].class=='building','single exact claim removes old duplicate object')
  local x=(k%4096)-64;local z=math.floor(k/4096)-64
  local floor=def.tileset=='MANSION'and 17 or(((x+z)%2==0)and 1 or 38)
  ok(sa.ground[k]==floor,'original room floor phase, never the differently colored north carpet')
 end
 for z=0,map.heightCells-1 do for x=0,map.widthCells-1 do ok(a.scene.groundAt(map,x,z)==b.scene.groundAt(map,x,z),id..' all actor heights exact')end end
 -- Public Structures path: original source/floor remains exact outside ownership.
 local function full(path)
  local rt=T.runtime(path,data);local comm=rt.module('CommunityVisuals');for _,k in ipairs({'customCourtyards','customPillars','customTrees','customWalls'})do comm[k]=function()return false end end;rt.module('BuildBudget').check=function()end
  return rt.stairs.forMap(map)
 end
 local fa,fb=full(root),full(old)
 eq(fa.roundStamps,fb.roundStamps,id..' accepted rounded props unchanged')
 for z=0,def.height*4-1 do for x=0,def.width*4-1 do local k=F.key(x,z);if not claims[k]then
  for _,field in ipairs({'tileAt','shapeAt','skip','ground'})do eq(fa[field][k],fb[field][k],id..' full room outside claim '..field)end
 end end end
 eq(def,original,id..' source maps/objects/signs/warp definitions never mutated')
 if wanted[id]then seenMaps=seenMaps+1;print(id..': original support and room ownership exact')end
end end
ok(instances==8 and claimed==128 and seenMaps==5,'eight exact benches in five maps,128 source tiles')
print(n..' workbench placement/support/room preservation checks passed')
