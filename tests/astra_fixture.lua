local H = {}
function H.upvalue(fn, wanted)
  for i=1,100 do local name,value=debug.getupvalue(fn,i)
    if not name then break end
    if name==wanted then return value end
  end
  error('missing upvalue '..wanted)
end
function H.pillar(root, layout, cells, levels)
  local captured
  local M={
    CommunityVisuals={layout=function() return layout end,
      pillarColor=function() return 'granite' end,
      customPillars=function() return layout~='default' end},
    Mat4={translate=function() return {} end},
    Voxel3D={
      newMesh=function(vertices,indices)
        return {vertices=vertices,indices=indices,release=function() end}
      end,
      pushQuad=function(indices,n)
        for _,i in ipairs({1,2,3,1,3,4}) do indices[#indices+1]=n*4+i end
      end,
      draw=function(mesh,texture) captured=mesh; mesh.texture=texture end,
      glass=function() end,glassMaskNow=function() end,
    },
  }
  local P=assert(loadfile(root..'/lib/GranitePillars.lua'))({require=function(n) return M[n] end})
  if not (love and love.graphics) then P.textures.granite,P.mask=false,false end
  local map={id='ASTRA_VISUAL_FIXTURE'}
  local bases={}
  for key,height in pairs(levels) do
    local x,z=key:match('^(-?%d+)|(-?%d+)$')
    bases[map.id..':'..(tonumber(x)*16+8)..'|'..(tonumber(z)*16+8)]=height
  end
  _G.__bav_granite_pillars={[map.id]=cells}
  _G.__bav_granite_pillar_base=bases
  P.draw(map,0,0)
  return captured,P
end
function H.atlas(path)
  local f=assert(io.open(path,'rb')); local w,h=f:read('*l'):match('(%d+) (%d+)')
  local raw=f:read('*a'); f:close(); w,h=tonumber(w),tonumber(h)
  return { getPixel=function(_,x,y)
      local r,g,b,a=raw:byte((y*w+x)*4+1,(y*w+x)*4+4)
      return r/255,g/255,b/255,a/255
    end,getDimensions=function() return w,h end },w,h
end
-- Historical regressions can opt out of only the explicitly upgraded
-- computers in memory. Live computer tests cover the enabled profiles.
function H.legacyComputers(spec)
  for _,family in pairs(spec.buildings or {}) do for _,t in ipairs(family) do
    if t.id=='bills_desk' or t.id=='lab_computers' or t.id=='center_pc' then
      for _,p in ipairs(t.parts or {}) do p.case=nil end
    end
  end end
end
-- A19 adds only exact-grid, actual-warp public stair rules. Historical
-- profile guards remove them only when the complete approved rules match;
-- the live public stair test owns all24 warps and every negative alias.
function H.historicalPublicPins(actual,baseline)
  local function copy(v)if type(v)~='table'then return v end;local o={};for k,x in pairs(v)do o[k]=copy(x)end;return o end
  local function equal(a,b)
    if type(a)~=type(b)then return false end;if type(a)~='table'then return a==b end
    for k,v in pairs(a)do if not equal(v,b[k])then return false end end
    for k in pairs(b)do if a[k]==nil then return false end end;return true
  end
  local rules={
    DOJO={{tiles={{72,73},{74,75}},class='stair_e'}},
    MART={{tiles={{92,93},{94,95}},class='stair_down_n'}},
    LOBBY={{tiles={{12,13},{28,29}},class='stair_n'},{tiles={{10,11},{26,27}},class='stair_down_n'}},
    INTERIOR={{tiles={{5,6},{21,22}},class='stair_down_e'}},
    FACILITY={{tiles={{90,91},{67,52}},class='stair_n'}},
  }
  local out=copy(actual)
  for family,want in pairs(rules)do
    if out[family]and baseline[family]and baseline[family].warp_stairs==nil and equal(out[family].warp_stairs,want)then out[family].warp_stairs=nil end
  end
  return H.historicalRemainingPins(out,baseline)
end
-- A20 has separate live cave/ship/gate geometry and placement tests.
-- Normalize only these exact approved additions in historical COPY profiles.
function H.historicalRemainingPins(actual,baseline)
  local function copy(v)if type(v)~='table'then return v end;local o={};for k,x in pairs(v)do o[k]=copy(x)end;return o end
  local function equal(a,b)
    if type(a)~=type(b)then return false end;if type(a)~='table'then return a==b end
    for k,v in pairs(a)do if not equal(v,b[k])then return false end end
    for k in pairs(b)do if a[k]==nil then return false end end;return true
  end
  local out=copy(actual)
  if out.CAVERN and baseline.CAVERN and baseline.CAVERN.cave_steps==nil
      and equal(out.CAVERN.cave_steps,{tiles={{21,22},{21,22}},rise=6})then out.CAVERN.cave_steps=nil end
  local a,b=out.GATE,baseline.GATE
  if a and b and b.stool==nil and equal(a.stool,{2,3,18,19})and a.heights and a.heights.stool==5 then
    local wanted={};for _,tile in ipairs(b.billboard or{})do if tile~=2 and tile~=3 and tile~=18 and tile~=19 then wanted[#wanted+1]=tile end end
    if equal(a.billboard,wanted)then
      a.stool=nil;a.billboard=copy(b.billboard);a.heights.stool=b.heights and b.heights.stool
      if next(a.heights)==nil and b.heights==nil then a.heights=nil end
    end
  end
  local hull={anchor={20,6},roofRows=0,roofCycle={0,0},depthPx=48,slab=0,panes=false,tiles={
    {20,20,2,3,4,5,6,7,9,9,11,11,12,13,14,15},
    {16,17,18,19,0,21,22,23,24,25,24,25,28,29,30,31},
    {32,33,34,35,36,37,38,39,40,41,40,41,44,45,46,47},
    {48,33,34,51,52,53,54,55,56,57,56,57,62,61,62,47},
    {64,65,66,67,68,69,69,69,69,69,69,69,69,77,78,79},
    {20,81,82,83,85,85,85,85,85,85,85,85,85,93,90,91}}}
  if out.SHIP_PORT and baseline.SHIP_PORT and baseline.SHIP_PORT.ship_hull==nil
      and equal(out.SHIP_PORT.ship_hull,hull)then out.SHIP_PORT.ship_hull=nil end
  return out
end
-- New source-complete workbenches/palm have dedicated A19 geometry/map tests.
-- Omit only the named A19/A20/A21 additions from older copies when absent there.
function H.historicalPublicBuildings(actual,baseline)
  local function copy(v)if type(v)~='table'then return v end;local o={};for k,x in pairs(v)do o[k]=copy(x)end;return o end
  local out=copy(actual)
  for family,ids in pairs({LAB={lab_workbench=true,warden_workbench=true},MANSION={mansion_workbench=true},FACILITY={facility_palm=true,facility_cabinet=true},GATE={gate_stool=true},CLUB={bike_display_floor=true,bike_display_wall=true},SHIP={ship_cabin_table=true,ship_house_table=true,ship_captain_desk=true,ship_kitchen_table=true,ship_bunk=true,ship_kitchen_counter=true,ship_kitchen_hob=true,ship_captain_chair=true,ship_truncated_table=true}})do
    local old={};for _,t in ipairs(baseline[family]or{})do old[t.id]=true end
    local list={};for _,t in ipairs(out[family]or{})do if not ids[t.id]or old[t.id]then list[#list+1]=t end end
    out[family]=(#list>0 or baseline[family])and list or nil
  end
  return out
end
-- Historical releases predate the explicit cave ladders and Mansion
-- north-facing stairs. Restore ONLY the exact approved pin lists in a copy.
-- Live stair tests check the actual profiles, all89 warps and source meshes.
function H.historicalStairPins(actual,baseline)
  local function copy(v)
    if type(v)~="table"then return v end
    local out={};for k,x in pairs(v)do out[k]=copy(x)end;return out
  end
  local function list(a,b)
    if type(a)~="table"or#a~=#b then return false end
    for i,v in ipairs(b)do if a[i]~=v then return false end end
    for k in pairs(a)do if type(k)~="number"or k<1 or k>#b then return false end end
    return true
  end
  local out=H.historicalPublicPins(actual,baseline)
  local a,b=out.MANSION,baseline.MANSION
  if a and b then
    for name,tiles in pairs({stair_n={12,13,28,29},stair_down_n={10,11,26,27}})do
      if b[name]==nil and list(a[name],tiles)then a[name]=nil end
    end
  end
  a,b=out.CAVERN,baseline.CAVERN
  if a and b then
    for _,change in ipairs({{"stair_e","ladder_up",{10,11,26,27}},
                             {"stair_down_e","ladder_down",{8,9,24,25}}})do
      local old,new,tiles=change[1],change[2],change[3]
      if b[new]==nil and a[old]==nil and list(a[new],tiles)and list(b[old],tiles)then
        a[new]=nil;a[old]=copy(b[old])
      end
    end
  end
  return out
end
-- Historical global-pin comparisons predate the full-pass room/seat work.
-- Restore only its three explicitly approved stool-height fields in a COPY,
-- and omit the newly introduced BeachHouse tileset when it did not exist.
-- Live full-pass tests independently lock the complete new profiles/placements.
-- Actual runtime profiles and geometry are never changed by this helper.
function H.historicalPins(actual,baseline)
  local function copy(v)
    if type(v)~="table" then return v end
    local out={};for k,x in pairs(v)do out[k]=copy(x)end;return out
  end
  local out=copy(actual)
  for family,height in pairs({LOBBY=5,MUSEUM=5,CLUB=6})do
    local a,b=out[family],baseline[family]
    if a and a.heights and a.heights.stool==height and b then
      a.heights.stool=b.heights and b.heights.stool or nil
      if next(a.heights)==nil and b.heights==nil then a.heights=nil end
    end
  end
  if baseline.BEACH_HOUSE==nil then out.BEACH_HOUSE=nil end
  if baseline.OVERWORLD and not baseline.OVERWORLD.sapling_tiles and out.OVERWORLD then
    local t=out.OVERWORLD.sapling_tiles
    assert(t and #t==4 and t[1]==45 and t[2]==46 and t[3]==61 and t[4]==62,
      'current upstream sapling source tiles retained')
    out.OVERWORLD.sapling_tiles=nil
  end
  return H.historicalStairPins(out,baseline)
end
-- A18 replaces only three DOJO table profiles and adds four Red household
-- models (the TV occurs in two family lists). Historical tests compare all
-- other entries exactly; new Pallet geometry/map tests own these targets.
-- This adapter modifies comparison copies, never a live runtime profile.
function H.historicalPalletBuildings(actual,baseline)
  local function copy(v)if type(v)~="table"then return v end;local o={};for k,x in pairs(v)do o[k]=copy(x)end;return o end
  local out=copy(actual)
  for family,ids in pairs({DOJO={lab_table=true,lab_table_small=true,lab_computers=true},
    REDS_HOUSE_1={reds_tv=true},REDS_HOUSE_2={reds_tv=true,reds_pc=true,reds_bed=true,reds_short_table=true}})do
    local old={};for _,t in ipairs(baseline[family]or{})do old[t.id]=t end
    local list={};for _,t in ipairs(out[family]or{})do
      if not ids[t.id]then list[#list+1]=t
      elseif old[t.id]then list[#list+1]=copy(old[t.id])end
    end
    out[family]=(#list>0 or baseline[family])and list or nil
  end
  return H.historicalPublicBuildings(out,baseline)
end
function H.building(root,id,data,aw,ah,budget,prepareOnly,tileset,editProfile)
  local spec=assert(loadfile(root..'/data/voxel_heights.lua'))()
  if editProfile then editProfile(spec) end
  local V
  V={require=function(n)
      if n=='BuildBudget' then return budget or {tick=function() end} end
      if n=='ComputerCase' or n=='BillMachine' or n=='BillPipe' or n=='FacilityPalm' or n=='ShipHull' or n=='BikeDisplay' then
        return assert(loadfile(root..'/lib/'..n..'.lua'))(V)
      end
      error('unexpected fixture module '..tostring(n))
    end,
    data=function() return spec end,
  }
  local B=assert(loadfile(root..'/lib/Buildings.lua'))(V)
  local t
  tileset=tileset or 'OVERWORLD'
  for _,v in ipairs(spec.buildings[tileset] or {}) do if v.id==id then t=v; break end end
  assert(t,id)
  local rear=(spec.building_back_templates or {})[tileset]
  local back=rear and rear[id] and (spec.building_back_tiles or {})[tileset] or nil
  local sp=H.upvalue(B.build,'read')(t,data,aw/8,back)
  local pr=H.upvalue(B.build,'measure')(sp,t)
  local model=H.upvalue(B.build,'model')(sp,pr,t)
  local emit=H.upvalue(B.build,'emit')
  if prepareOnly then return emit,model,sp end
  local q=emit(model,sp,aw,ah)
  return q
end
function H.mesh(quads)
  local mesh={vertices={},indices={}}
  for _,q in ipairs(quads) do
    local base=#mesh.vertices
    for i=1,4 do mesh.vertices[#mesh.vertices+1]={q[i][1],q[i][2],q[i][3],q.uv[i][1],q.uv[i][2],type(q.shade)=="table" and q.shade[i] or q.shade} end
    for _,i in ipairs({1,2,3,1,3,4}) do mesh.indices[#mesh.indices+1]=base+i end
  end
  return mesh
end
function H.triangles(mesh)
  local out,zero={},0
  for i=1,#mesh.indices,3 do
    local a,b,c=mesh.vertices[mesh.indices[i]],mesh.vertices[mesh.indices[i+1]],mesh.vertices[mesh.indices[i+2]]
    assert(a and b and c,'invalid mesh index')
    local ux,uy,uz=b[1]-a[1],b[2]-a[2],b[3]-a[3]
    local vx,vy,vz=c[1]-a[1],c[2]-a[2],c[3]-a[3]
    if (uy*vz-uz*vy)^2+(uz*vx-ux*vz)^2+(ux*vy-uy*vx)^2<=1e-16 then zero=zero+1 else
      local fields={}
      for _,v in ipairs({a,b,c}) do for j=1,6 do fields[#fields+1]=('%.17g'):format(v[j]) end end
      out[#out+1]=table.concat(fields,',')
    end
  end
  table.sort(out)
  return out,zero
end
return H
