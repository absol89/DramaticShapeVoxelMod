-- Exact source grids and actual engine support for remaining interiors.
local root=os.getenv('ASTRA_CANDIDATE') or '.'
local baseline=assert(os.getenv('ASTRA_REMAINING_BASELINE'))
local dir=assert(os.getenv('ASTRA_REMAINING_ATLASES'))
local H=dofile('tests/astra_fixture.lua');local F=dofile('tests/astra_scene_fixture.lua')
local n=0;local function ok(v,s)n=n+1;assert(v,s)end
local function eq(a,b,s)ok(a==b,s..' expected '..tostring(b)..', got '..tostring(a))end
local function same(a,b,s)
 eq(type(a),type(b),s)
 if type(a)=='table'then for k,v in pairs(a)do same(v,b[k],s..'.'..tostring(k))end;for k in pairs(b)do ok(a[k]~=nil,s..' no removed field')end
 else eq(a,b,s)end
end
local before,after=F.runtime(baseline),F.runtime(root)
local prototype=os.getenv('ASTRA_SHIP_PROFILES')
if prototype then for _,t in ipairs(assert(loadfile(prototype))())do after.spec.buildings.SHIP[#after.spec.buildings.SHIP+1]=t end end
local expected={ship_cabin_table=12,ship_house_table=2,ship_captain_desk=1,ship_kitchen_table=3,ship_bunk=12,ship_kitchen_counter=4,ship_kitchen_hob=3,ship_captain_chair=1,ship_truncated_table=6,gate_stool=36}
local counts,ledger={},{};local currentMap,records
local original=after.build.stamp
function after.build.stamp(S,map,q,tx,tz,bw,bh,t)
 if expected[t.id]then
  counts[t.id]=(counts[t.id] or 0)+1;records[#records+1]={id=t.id,tx=tx,tz=tz,bw=bw,bh=bh}
  ledger[#ledger+1]={map=map.id,id=t.id,tx=tx,tz=tz}
 end
 return original(S,map,q,tx,tz,bw,bh,t)
end
local atlases={};for _,a in ipairs({'ship','gate','mansion'})do atlases[a]={H.atlas(dir..'/'..a..'.rgba')}end
local seated,celadon,bunks=0,0,0
for id,def in pairs(F.maps)do
 if def.tileset=='SHIP' or def.tileset=='GATE' or def.tileset=='FOREST_GATE' or id=='CELADON_MANSION_2F' or id=='CELADON_MANSION_3F'then
  local map=F.Map.new(def,F.tilesets[def.tileset]);local a=atlases[def.tileset=='SHIP' and 'ship' or def.tileset=='MANSION' and 'mansion' or 'gate']
  local data,w=a[1],a[2];records={};local old=F.build(before,map,data,w);local new=F.build(after,map,data,w)
  local claims={};local gateCells={}
  for _,p in ipairs(records)do
   local t=F.template(after,def.tileset,p.id)
   for dz,row in ipairs(t.tiles)do for dx,tile in ipairs(row)do
    local x,z=p.tx+dx-1,p.tz+dz-1;local k=F.key(x,z)
    eq(map:tileAt(x,z),tile,id..' exact complete source grid');ok(not claims[k],id..' no overlapping authored claims');claims[k]=p.id
    ok(new.skip[k],id..' claimed source cell');eq(new.shapeAt[k].class,'building',id..' generic source standee suppressed')
    if def.tileset=='SHIP'then eq(new.ground[k],(x+z)%2==0 and 13 or 29,id..' newly exposed floor retains original global checker phase')end
   end end
   if p.id=='gate_stool'then gateCells[(p.tz/2)..':'..(p.tx/2)]=true end
   if p.id=='ship_truncated_table'then
    eq(id,'SS_ANNE_1F_ROOMS','short pattern only claims cropped first-floor drawings')
    -- Its one-pixel front rim extends into the source's omitted lower
    -- band, which is outside the walkable cabin and has no event cell.
    ok(not map:isWalkableCell(p.tx/2,(p.tz+2)/2),'truncated rim does not enter a walkable cell')
   end
   if p.id=='ship_bunk'then
    bunks=bunks+1
    for z=p.tz/2,(p.tz+p.bh-1)/2 do for x=p.tx/2,(p.tx+p.bw-1)/2 do
     ok(not map:isWalkableCell(x,z),'bunk and drawer cells are blocked')
     for _,o in ipairs(def.objects or {})do ok(o.x~=x or o.y~=z,'no actor/item rests on7/12 raw bunk pins')end
     for _,warp in ipairs(def.warps or {})do ok(warp.x~=x or warp.y~=z,'no bunk warp')end
    end end
   end
  end
  for z=0,map.heightCells*2-1 do for x=0,map.widthCells*2-1 do local k=F.key(x,z)
   if not claims[k]then
    same(new.shapeAt[k],old.shapeAt[k],id..' unrelated tile shape unchanged')
    eq(new.skip[k],old.skip[k],id..' unrelated claim unchanged');eq(new.ground[k],old.ground[k],id..' unrelated floor unchanged')
   end
  end end
  for z=0,map.heightCells-1 do for x=0,map.widthCells-1 do
   local was=before.scene.groundAt(map,x,z);local now=after.scene.groundAt(map,x,z)
   if gateCells[z..':'..x]then eq(was,16,'old gate standee actor datum');eq(now,5,'gate source seat height5')
   else eq(now,was,id..' every other actor support unchanged')end
  end end
  for _,o in ipairs(def.objects or {})do
   if gateCells[o.y..':'..o.x]then seated=seated+1;eq(after.scene.groundAt(map,o.x,o.y),5,id..' seated Safari NPC meets source seat')end
  end
  if def.tileset=='GATE'then
   local resolved=after.shapes.forMap(map)
   for _,tile in ipairs({36,52,57})do
    eq(resolved[tile].class,'billboard','binocular component class unchanged');eq(resolved[tile].h,16,'binocular support unchanged')
   end
  end
  if id=='CELADON_MANSION_2F' or id=='CELADON_MANSION_3F'then
   local t=F.template(after,'MANSION','mansion_workbench');same(t,F.template(before,'MANSION','mansion_workbench'),'accepted Celadon workbench profile')
   local matches=F.matches(t,map);eq(#matches,id=='CELADON_MANSION_3F' and 3 or 1,'all four actual Celadon console drawings already covered');celadon=celadon+#matches
   local oq=H.triangles(H.mesh(old.objectQuads));local nq=H.triangles(H.mesh(new.objectQuads));same(nq,oq,id..' exact accepted authored mesh UV shading')
  end
 end
end
for id,count in pairs(expected)do eq(counts[id],count,id..' exact intended real-map placement count')end
eq(seated,3,'all three occupied Safari seats');eq(celadon,4,'all four accepted Celadon consoles');eq(bunks,12,'all twelve actual passenger bunks')
-- GATE's drawing is byte-identical to the accepted MUSEUM stool source.
local gd,gw,gh=unpack(atlases.gate)
local old=H.triangles(H.mesh(H.building(baseline,'museum_stool',gd,gw,gh,nil,false,'MUSEUM')))
local new=H.triangles(H.mesh(H.building(root,'gate_stool',gd,gw,gh,nil,false,'GATE')))
same(new,old,'identical source uses the accepted5px stool geometry/material')
if os.getenv('ASTRA_REMAINING_LEDGER')then
 local f=assert(io.open(os.getenv('ASTRA_REMAINING_LEDGER'),'w'));f:write('model\tmap\ttile_x\ttile_z\n')
 table.sort(ledger,function(a,b)return a.map..a.id..a.tx..a.tz<b.map..b.id..b.tx..b.tz end)
 for _,p in ipairs(ledger)do f:write(p.id,'\t',p.map,'\t',p.tx,'\t',p.tz,'\n')end;f:close()
end
print(('%d remaining-interior placement/support checks passed;44 ship fixtures,36 gate stools,3 corrected NPC contacts,4 accepted Celadon consoles exact'):format(n))
