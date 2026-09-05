-- Complete FACILITY cabinets own the original base without changing gameplay.
local root=os.getenv('ASTRA_CANDIDATE')or'.';local baseline=assert(os.getenv('ASTRA_PUBLIC_BASELINE'))
local T=dofile('tests/astra_stair_fixture.lua');local H,F=T.H,T.F
local helper=assert(loadfile('tests/astra_facility_palm_placement_test.lua'))('helpers')
local before,after=F.runtime(baseline),F.runtime(root)
local n=0;local function ok(v,s)n=n+1;assert(v,s)end
local function same(a,b,s)
 ok(type(a)==type(b),s..' type');if type(a)~='table'then ok(a==b,s);return end
 for k,v in pairs(a)do same(v,b[k],s..'.'..tostring(k))end
 for k in pairs(b)do ok(a[k]~=nil,s..' unexpected '..tostring(k))end
end
local t=F.template(after,'FACILITY','facility_cabinet')
same(t.tiles,{{40,41},{56,57},{56,57},{25,26}},'complete cabinet source grid')
ok(t.support==nil and t.scrub==nil and t.keep==nil,'no new actor support or source repaint')
local wanted={POKEMON_MANSION_1F=3,POKEMON_MANSION_2F=2,POKEMON_MANSION_B1F=3,SILPH_CO_3F=2,SILPH_CO_8F=2,SILPH_CO_9F=5}
local total=0
for id,def in pairs(F.maps)do if def.tileset=='FACILITY'then
 local map=F.Map.new(def,F.tilesets.FACILITY);local matches=F.matches(t,map)
 same(#matches,wanted[id]or 0,id..' exact cabinet count')
 if #matches>0 then
  total=total+#matches
  local a,aq,_,claims=helper.full(root,map,true);local b,bq=helper.full(baseline,map,false)
  same(claims,matches,id..' actual full-cabinet claims')
  same(aq,bq,id..' other object quads exact except separately tested palms/stairs')
  local touched={}
  for _,p in ipairs(matches)do for z=p[2],p[2]+3 do for x=p[1],p[1]+1 do
   local k=F.key(x,z);touched[k]=true
   ok(a.skip[k]and a.shapeAt[k].class=='building',id..' one owner includes former front plinth')
   same(a.tileAt[k],map:tileAt(x,z),id..' original source tile retained')
   same(a.ground[k],1,id..' real neighboring floor continues beneath the cabinet')
   if b.ground[k]then ok(b.ground[k]==1 or b.ground[k]==17,id..' only documented legacy bookcase backfill differs')end
  end end
   same(before.scene.groundAt(map,p[1]/2,p[2]/2+1),16,id..' original base support16')
   same(after.scene.groundAt(map,p[1]/2,p[2]/2+1),16,id..' unchanged base support16')
  end
  -- Other accepted palm claims and public stair ownership may differ in this
  -- release; all remaining tile, floor and wall cells stay byte-identical.
  local other=F.matches(F.template(after,'FACILITY','facility_palm'),map)
  for _,p in ipairs(other)do for z=p[2],p[2]+3 do for x=p[1],p[1]+1 do touched[F.key(x,z)]=true end end end
  local oldShapes=before.shapes.forMap(map)
  for z=0,map.def.height*4-1 do for x=0,map.def.width*4-1 do local k=F.key(x,z);local sh=oldShapes[map:tileAt(x,z)]
   if not touched[k]and not(sh and sh.art=='stair')then
    for _,field in ipairs({'tileAt','shapeAt','ground','skip'})do same(a[field][k],b[field][k],id..' unchanged room '..field)end
   end
  end end
  for z=0,map.heightCells-1 do for x=0,map.widthCells-1 do
   same(after.scene.groundAt(map,x,z),before.scene.groundAt(map,x,z),id..' all actor support exact')
  end end
 end
end end
same(total,17,'eight Mansion and nine Silph cabinets')
print(('%d FACILITY cabinet placement/preservation checks passed;17 exact cabinets across6 maps'):format(n))
