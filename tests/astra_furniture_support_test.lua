-- Cumulative source-art regression for dining tables and four-leg square stools.
-- The three dining tables now have approved inset aprons/feet and uniform
-- source-colored tops; their exact form is covered by astra_table_geometry_test.lua.
-- The accepted stools retain a one-layer seat and open space below it; the
-- rear center support and solid middle apron from Astra 3 are intentionally gone.
-- Private atlas inputs are read only and never belong in a release archive.
-- ASTRA_FURNITURE_ATLASES: directory of user-generated *.rgba atlases.
-- ASTRA_FURNITURE_BASELINE: unmodified Astra 2 mod (same contact lighting).
-- Run from the candidate mod root, or set ASTRA_CANDIDATE explicitly.
local candidate=os.getenv('ASTRA_CANDIDATE') or '.'
local baseline=assert(os.getenv('ASTRA_FURNITURE_BASELINE'),
  'ASTRA_FURNITURE_BASELINE required')
local atlasDir=assert(os.getenv('ASTRA_FURNITURE_ATLASES'),
  'ASTRA_FURNITURE_ATLASES required')
local H=dofile(candidate..'/tests/astra_fixture.lua')
local spec=dofile(candidate..'/data/voxel_heights.lua')
local oldSpec=dofile(baseline..'/data/voxel_heights.lua')
-- Preserve the legacy computer path exactly; live A12 case surfaces have their own tests.
H.legacyComputers(spec)
local checks=0
local function ok(v,message)
  checks=checks+1
  if not v then error('FAIL '..message,0) end
end
local function equal(a,b,message)
  ok(a==b,message..' (expected '..tostring(b)..', got '..tostring(a)..')')
end
local function same(a,b,message)
  equal(type(a),type(b),message..' type')
  if type(a)~='table' then equal(a,b,message);return end
  for k,v in pairs(a) do same(v,b[k],message..'.'..tostring(k)) end
  for k in pairs(b) do ok(a[k]~=nil,message..' keeps '..tostring(k)) end
end
local changed={
  ['HOUSE/house_stool']={legs=4,stool=true},
  ['REDS_HOUSE_1/house_stool']={legs=4,stool=true},
  ['INTERIOR/club_stool']={legs=4,stool=true},
  ['HOUSE/house_table']={legs=4},
  ['REDS_HOUSE_1/reds_house_table']={legs=4},
  ['MANSION/mansion_long_table']={legs=4},
}
local families={{'HOUSE','house'},{'REDS_HOUSE_1','reds_house'},
  {'DOJO','gym'},{'INTERIOR','interior'},{'POKECENTER','pokecenter'},
  {'MANSION','mansion'},{'CLUB','club'}}
local function voxelKey(x,y,z) return x..':'..y..':'..z end
local neighbours={{-1,0,0},{1,0,0},{0,-1,0},{0,1,0},{0,0,-1},{0,0,1}}
-- Count actual connected supports at floor height, independently of the
-- profile's chosen support-zone representation. Also use the same flood in
-- 3D to catch detached feet and hovering seat pieces.
local function components(m,plane)
  local remaining={}
  for y=plane or 0,plane or m.ytop do
    for z=m.zmin,m.zmax do for x=0,m.W-1 do
      if m.at(x,y,z)~=nil then remaining[voxelKey(x,y,z)]={x,y,z} end
    end end
  end
  local parts={}
  while next(remaining) do
    local seed,p=next(remaining);remaining[seed]=nil
    local queue={p};local head=1
    local part={n=0,x0=p[1],x1=p[1],y0=p[2],y1=p[2],z0=p[3],z1=p[3]}
    while head<=#queue do
      local v=queue[head];head=head+1;part.n=part.n+1
      part.x0=math.min(part.x0,v[1]);part.x1=math.max(part.x1,v[1])
      part.y0=math.min(part.y0,v[2]);part.y1=math.max(part.y1,v[2])
      part.z0=math.min(part.z0,v[3]);part.z1=math.max(part.z1,v[3])
      for _,d in ipairs(neighbours) do
        local k=voxelKey(v[1]+d[1],v[2]+d[2],v[3]+d[3])
        if remaining[k] then queue[#queue+1]=remaining[k];remaining[k]=nil end
      end
    end
    parts[#parts+1]=part
  end
  return parts
end
local function template(profile,family,id)
  for _,t in ipairs(profile.buildings[family]) do if t.id==id then return t end end
  error('missing template '..family..'/'..id)
end
local function stamp(root,profile,t,q)
  local B=assert(loadfile(root..'/lib/Buildings.lua'))({
    require=function()return{tick=function()end}end,data=function()return profile end})
  local S={outdoor=false,shapeAt={},skip={},ground={},objectQuads={},tileAt={}}
  local function key(x,z)return(z+64)*4096+(x+64)end
  for z=-1,#t.tiles do for x=-1,#t.tiles[1] do
    S.tileAt[key(x,z)]=0;S.shapeAt[key(x,z)]={class='ground',flat=true,h=0}
  end end
  for z,row in ipairs(t.tiles)do for x,tile in ipairs(row)do
    S.tileAt[key(x-1,z-1)]=tile
  end end
  B.stamp(S,{},q,0,0,#t.tiles[1],#t.tiles,t)
  S.objectQuads=nil -- Their visible geometry is intentionally corrected.
  return S
end
-- Current upstream adds opt-in saplings; retain all historical class values.
oldSpec.heights.sapling=oldSpec.heights.sapling or 16
same(spec.heights,oldSpec.heights,'all class heights retained')
same(H.historicalPins(spec.tilesets,oldSpec.tilesets),oldSpec.tilesets,'all placement and seated-character pins retained')
local fixed,unchanged,integratedDesk=0,0,0
for _,entry in ipairs(families) do
  local family,file=entry[1],entry[2]
  local data,w,h=H.atlas(atlasDir..'/'..file..'.rgba')
  for _,t in ipairs(H.historicalPublicBuildings(spec.buildings,oldSpec.buildings)[family]) do if not t.claimOnly and t.machine~='bill_transporter' and t.pipe~='bill_pipe' and not(family=='CLUB'and t.id=='cable_club_stool') and not(family=='REDS_HOUSE_1'and t.id=='reds_tv') and not(family=='DOJO'and(t.id=='lab_table'or t.id=='lab_table_small'or t.id=='lab_computers'))then
    local name=family..'/'..t.id
    local oe,om,osp=H.building(baseline,t.id,data,w,h,nil,true,family)
    local ne,nm,nsp=H.building(candidate,t.id,data,w,h,nil,true,family,H.legacyComputers)
    local oldQ,newQ=oe(om,osp,w,h),ne(nm,nsp,w,h)
    local cfg=changed[name]
    if name=='INTERIOR/bills_desk' then
      -- Its integrated chair is corrected separately. Keep cumulative
      -- guarantees for the original desk, contents and complete claims.
      integratedDesk=integratedDesk+1
      local ot=template(oldSpec,family,t.id)
      equal(nm.W,om.W,name..' original width');equal(nm.ytop,om.ytop,name..' original computer height')
      equal(nm.zmin,om.zmin,name..' original rear plot');equal(nm.zmax,om.zmax,name..' original front plot')
      same(t.tiles,ot.tiles,name..' original source grid');same(t.desk,ot.desk,name..' original desk body')
      for i=1,4 do same(t.parts[i],ot.parts[i],name..' original desk object '..i)end
      for y=0,om.ytop do for z=om.zmin,om.zmax do for x=0,om.W-1 do
        if z<16 or x>=16 then
          local a,b=om.at(x,y,z),nm.at(x,y,z)
          equal(b,a,name..' original non-chair voxel/source')
          if b~=nil then
            equal(nsp.ax[b],osp.ax[a],name..' original non-chair atlas X')
            equal(nsp.ay[b],osp.ay[a],name..' original non-chair atlas Y')
          end
        end
      end end end
      same(stamp(candidate,spec,t,newQ),stamp(baseline,oldSpec,ot,oldQ),name..' original complete tile claims')
      print(name..': original desk voxels/source/claims retained; integrated-chair form covered separately')
    elseif not cfg then
      -- Exact vertex/UV/shade quad data: changing the shared builder must
      -- leave every other modeled interior object untouched.
      same(newQ,oldQ,name..' emitted quads')
      unchanged=unchanged+1
      print(name..': all emitted geometry, UVs and shades unchanged')
    else
      fixed=fixed+1
      equal(nm.W,om.W,name..' width')
      equal(nm.zmin,om.zmin,name..' rear bound')
      equal(nm.zmax,om.zmax,name..' front bound')
      equal(nm.ytop,om.ytop,name..' top height')
      equal(nm.ytop+1,cfg.stool and 5 or 6,name..' expected seat/table height')
      local feet=components(nm,0)
      equal(#feet,cfg.legs,name..' separate floor supports')
      for _,p in ipairs(feet) do
        ok(p.z1-p.z0+1<=(cfg.stool and 2 or 5),name..' no full-depth rail')
        ok(p.x1-p.x0+1<=(cfg.stool and 2 or 5),name..' no broad foot wall')
      end
      equal(#components(nm),1,name..' every support joins the seat')
      local removed,upperRemoved,seatSamples,tableSamples=0,0,0,0
      for y=0,om.ytop do for z=om.zmin,om.zmax do for x=0,om.W-1 do
        local a,b=om.at(x,y,z),nm.at(x,y,z)
        if b~=nil then
          if cfg.stool and y==4 then
            seatSamples=seatSamples+1
            ok(a~=nil,name..' accepted top position retained')
            ok(nsp.inside[b],name..' centered seat material is original inside artwork')
            local c=nsp.col[b]
            ok(c==0 or c==1 or c==3,name..' centered seat keeps its own white/gray/black palette')
          elseif not cfg.stool then
            -- Only the three explicitly revised dining-table profiles may
            -- change body/top occupancy and remap their original colors.
            tableSamples=tableSamples+1
            ok(nsp.inside[b],name..' revised table samples its own inside artwork')
            local c=nsp.col[b]
            ok(c==0 or c==1 or c==2 or c==3,name..' revised table keeps its source palette')
          else
            equal(b,a,name..' every stool support keeps its original source texel')
            equal(nsp.ax[b],osp.ax[a],name..' source atlas X retained')
            equal(nsp.ay[b],osp.ay[a],name..' source atlas Y retained')
          end
        elseif a~=nil then
          removed=removed+1
          if cfg.stool and y>=4 then upperRemoved=upperRemoved+1 end
        end
        if y<=(cfg.stool and 3 or 1) then
          local inMiddle=cfg.stool and (x>=5 and x<=10 or z>=7 and z<=9)
            or not cfg.stool and (x>=6 and x<=nm.W-7 or z>=6 and z<=25)
          if inMiddle then ok(b==nil,name..' open floor between front and rear feet') end
        end
      end end end
      equal(upperRemoved,0,name..' retained accepted stool top; revised tables covered separately')
      equal(seatSamples,cfg.stool and 132 or 0,name..' only authorized seat materials may change')
      equal(tableSamples,cfg.stool and 0 or newQ.voxels,name..' only three authorized table models may remap body texels')
      ok(removed>0,name..' removes extruded support rails')
      ok(newQ.voxels<oldQ.voxels,name..' occupancy reduced')
      local ot=template(oldSpec,family,t.id)
      same(t.tiles,ot.tiles,name..' exact tile grid retained')
      same(t.scrub,ot.scrub,name..' plant scrub rectangle retained')
      same(t.keep,ot.keep,name..' plant keep tiles retained')
      same(t.support,ot.support,name..' supported object height retained')
      same(stamp(candidate,spec,t,newQ),stamp(baseline,oldSpec,ot,oldQ),
        name..' tile claims and support behavior unchanged')
      print(('%s: %d connected feet; voxels %d -> %d; quads %d -> %d'):format(
        name,#feet,oldQ.voxels,newQ.voxels,#oldQ,#newQ))
    end
  end end
end
equal(fixed,6,'six authored furniture corrections covered')
equal(unchanged,9,'nine retained models; three Oak table bodies have their own A18 regression')
equal(integratedDesk,1,'one integrated desk retained outside its corrected chair')
print(('%d checks passed (six furniture supports; nine unchanged models plus separately tested Oak tables; original integrated desk retained)'):format(checks))
