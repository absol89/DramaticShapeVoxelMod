-- Exact complete-palm ownership and preservation across every FACILITY map.
local root=os.getenv('ASTRA_CANDIDATE')or'.';local baseline=assert(os.getenv('ASTRA_PUBLIC_BASELINE'))
local T=dofile('tests/astra_stair_fixture.lua');local H,F=T.H,T.F
local data,w,h=H.atlas(assert(os.getenv('ASTRA_FACILITY_ATLAS')))
local before,after=F.runtime(baseline),F.runtime(root)
local n=0;local function ok(v,s)n=n+1;assert(v,s)end
local function same(a,b,s)
 ok(type(a)==type(b),s..' type')
 if type(a)~='table'then ok(a==b,s);return end
 for k,v in pairs(a)do same(v,b[k],s..'.'..tostring(k))end
 for k in pairs(b)do ok(a[k]~=nil,s..' unexpected '..tostring(k))end
end
local t=F.template(after,'FACILITY','facility_palm')
same(t.tiles,{{5,6},{21,22},{7,15},{23,31}},'only complete original palm grid')
ok(t.support==nil and t.keep==nil and t.scrub==nil,'palm does not change support or repaint source')
local wanted={POKEMON_MANSION_1F=12,POKEMON_MANSION_2F=2,POKEMON_MANSION_3F=2,POKEMON_MANSION_B1F=8,
 ROCKET_HIDEOUT_B1F=14,ROCKET_HIDEOUT_B2F=3,ROCKET_HIDEOUT_B4F=8,SILPH_CO_1F=17,SILPH_CO_2F=6,
 SILPH_CO_4F=6,SILPH_CO_5F=2,SILPH_CO_6F=4,SILPH_CO_7F=6,SILPH_CO_8F=3,SILPH_CO_9F=4,SILPH_CO_10F=1}
local ids={};for id,def in pairs(F.maps)do if def.tileset=='FACILITY'then ids[#ids+1]=id end end;table.sort(ids)
local function full(path,map,new)
 local r=T.runtime(path,data);local cv=r.module('CommunityVisuals')
 for _,s in ipairs({'customCourtyards','customPillars','customTrees','customWalls'})do cv[s]=function()return false end end
 r.module('BuildBudget').check=function()end
 local omit,claims,cabinetClaims={},{},{};local stamp=r.build.stamp
 r.build.stamp=function(S,mp,q,x,z,bw,bh,profile)
  local first=#S.objectQuads+1;stamp(S,mp,q,x,z,bw,bh,profile)
  if profile.id=='facility_palm' then claims[#claims+1]={x,z} end
  if profile.id=='facility_cabinet' then cabinetClaims[#cabinetClaims+1]={x,z} end
  if profile.id=='facility_palm' or profile.id=='facility_cabinet' then
   for i=first,#S.objectQuads do omit[i]=true end
  end
 end
 local object=r.stairs.buildObject
 r.stairs.buildObject=function(S,mp,region,cluster,...)
  local first=#S.objectQuads+1;local result=object(S,mp,region,cluster,...)
  if result and not new then
   local allPalm=true;local pool={[5]=true,[6]=true,[21]=true,[22]=true,[7]=true,[15]=true,[23]=true,[31]=true}
   for _,p in ipairs(cluster.tiles)do if not pool[mp:tileAt(p[1],p[2])]then allPalm=false end end
   if allPalm then for i=first,#S.objectQuads do omit[i]=true end end
  end;return result
 end
 -- The separately tested complete cabinets replace only these exact source
 -- banks. Omit their old bookcase quads, not every FACILITY bookcase.
 local cabinets=F.matches({tiles={{40,41},{56,57},{56,57},{25,26}}},map)
 local books=r.stairs.buildBookcases
 r.stairs.buildBookcases=function(S,...)
  local first=#S.objectQuads+1;books(S,...)
  if not new then for i=first,#S.objectQuads do local q=S.objectQuads[i]
   for _,p in ipairs(cabinets)do local inside=true
    for v=1,4 do if q[v][1]<p[1]*8 or q[v][1]>(p[1]+2)*8 or q[v][3]<p[2]*8 or q[v][3]>(p[2]+4)*8 then inside=false end end
    if inside then omit[i]=true end
   end
  end end
 end
 -- A19 public stairs have an independent regression. Keep their ownership
 -- pass live; omit only its quads from this palm-only surface comparison.
 local stairs=r.stairs.buildStairs
 r.stairs.buildStairs=function(S,...)
  local first=#S.objectQuads+1;stairs(S,...);for i=first,#S.objectQuads do omit[i]=true end
 end
 local S=r.stairs.forMap(map);local retained={}
 for i,q in ipairs(S.objectQuads)do if not omit[i]then retained[#retained+1]=q end end
 return S,retained,claims,cabinetClaims
end
if ...=='helpers' then return {full=full} end
local total=0
for _,id in ipairs(ids)do
 local map=F.Map.new(F.maps[id],F.tilesets.FACILITY);local positions=F.matches(t,map)
 same(#positions,wanted[id]or 0,id..' exact complete-palm count')
 if #positions>0 then
  total=total+#positions
  local b,bq=full(baseline,map,false);local a,aq,claims=full(root,map,true)
  same(claims,positions,id..' actual template claims')
  same(aq,bq,id..' every non-palm/non-cabinet/non-stair object quad unchanged')
  for _,p in ipairs(positions)do for z=p[2],p[2]+3 do for x=p[1],p[1]+1 do local k=F.key(x,z)
   ok(a.skip[k]and b.skip[k],id..' exactly one rendered owner')
   same(a.ground[k],b.ground[k],id..' original floor under each palm')
   same(a.tileAt[k],b.tileAt[k],id..' original source tile retained')
  end end end
  for z=0,map.heightCells-1 do for x=0,map.widthCells-1 do
   same(after.scene.groundAt(map,x,z),before.scene.groundAt(map,x,z),id..' all actor support')
  end end
  for _,o in ipairs(map.def.objects or{})do
   same(after.scene.groundAt(map,o.x,o.y),before.scene.groundAt(map,o.x,o.y),id..' event contact')
  end
 end
end
same(total,98,'exact family scope')
print(('%d FACILITY palm placement/preservation checks passed; 98 complete palms in 16 maps; other objects and support exact'):format(n))
