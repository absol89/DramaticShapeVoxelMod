local V=...;local M={}
M.roofs={CELADON_MART_ROOF={city='CELADON_CITY',dest='CELADON_MART_1F',height=86,w=10,h=4},CELADON_MANSION_ROOF={city='CELADON_CITY',dest='CELADON_MANSION_1F',height=67,w=4,h=6}}
M.gates={ROUTE_11_GATE_2F='ROUTE_11',ROUTE_12_GATE_2F='ROUTE_12',ROUTE_15_GATE_2F='ROUTE_15',ROUTE_16_GATE_2F='ROUTE_16',ROUTE_18_GATE_2F='ROUTE_18'}
function M.profile(map,defs)
 if not map or not map.def or map.def.generation==2 then return end
 local id=map.id;local r=M.roofs[id]
 if r then
  if map.def.width~=r.w or map.def.height~=r.h then return end
  return {city=r.city,dest=r.dest,height=r.height,roof=true}
 end
 if M.gates[id]then
  -- (TEST178: placed over the gate itself, between its doors, not 16 north
  -- of its first door)
  return {city=M.gates[id],dest=(id:gsub('2F','1F')),height=42,binoculars=true,windows=true,
   nearest=true,roomW=map.def.width*32,roomD=map.def.height*32}
 end
 if (id=='REDS_HOUSE_1F' or id=='REDS_HOUSE_2F')and map.def.width==4 and map.def.height==4 then
  return {city='PALLET_TOWN',dest='REDS_HOUSE_1F',height=id=='REDS_HOUSE_1F' and 0 or 24,windows=true,red=true}
 end
 if id:match('^CELADON_MART_[2-5]F$')then return {city='CELADON_CITY',dest='CELADON_MART_1F',height=(tonumber(id:match('_(%d)F'))-1)*17+12,windows=true}end
 if id:match('^CELADON_MANSION_[23]F$')then return {city='CELADON_CITY',dest='CELADON_MANSION_1F',height=(tonumber(id:match('_(%d)F'))-1)*22+12,windows=true}end
 return M.interior(map,defs)
end
-- TEST178: every room InteriorRooms builds looks out at its own town. The
-- town is the outdoor map whose door leads in (to this room, or to its
-- ground floor for an upper one); upper floors stand 18 higher each. Only
-- rooms with panes (windows, doors) ever ask ScenicViews for a view.
local found=setmetatable({},{__mode='k'})
-- the towns and routes, the Safari Zone's areas and the S.S. Anne's dock
local function outdoor(def,id)
 if not def or def.generation==2 then return false end
 local ts=def.tileset;id=id or def.id or''
 return ts=='OVERWORLD'or(ts=='FOREST'and id:match('^SAFARI_ZONE_')~=nil)or(ts=='SHIP_PORT'and id=='VERMILION_DOCK')
end
function M.cityOf(id,defs)
 local first=id:gsub('_%d+F$','_1F')
 local wants={id};if first~=id then wants[2]=first end
 for _,want in ipairs(wants)do
  for _,b in ipairs(V.require('BuildingInventory'))do
   if b.destination==want and outdoor(defs[b.map],b.map)then return b.map,want end
  end
 end
 local ids={}
 for cid,def in pairs(defs)do if outdoor(def,cid)then ids[#ids+1]=cid end end
 table.sort(ids)
 for _,want in ipairs(wants)do
  for _,cid in ipairs(ids)do
   for _,w in ipairs(defs[cid].warps or{})do if w.destMap==want then return cid,want end end
  end
 end
end
function M.interior(map,defs)
 local id=map.id
 local okR,Rooms=pcall(V.require,'InteriorRooms')
 if not(okR and Rooms.ROOMS and Rooms.ROOMS[id])then return end
 local hit=found[map]
 if not hit or hit.defs~=defs then
  hit={defs=defs}
  local city,dest=M.cityOf(id,defs)
  if id=='CELADON_MANSION_ROOF_HOUSE' then
   -- (TEST180: the penthouse on the Mansion's roof looks out from the roof)
   city,dest=M.cityOf('CELADON_MANSION_1F',defs)
   if city then hit.city,hit.dest,hit.height=city,dest,M.roofs.CELADON_MANSION_ROOF.height+2 end
  elseif city then
   hit.city,hit.dest=city,dest
   hit.height=dest~=id and((tonumber(id:match('_(%d+)F$'))or 1)-1)*18 or 0
  end
  found[map]=hit
 end
 if not hit.city then return end
 -- (the room must be ours right now: the setting, the ROM layout)
 local okA,own=pcall(Rooms.accepts,map)
 if not(okA and own)then return end
 local p={city=hit.city,dest=hit.dest,height=hit.height,windows=true,generic=true,menu=false,nearest=true,
  roomW=map.def.width*32,roomD=map.def.height*32}
 if hit.x==nil then
  hit.x,hit.z,hit.width,hit.depth=M.anchor(p,defs)
  if hit.x then
   p.x,p.z,p.width,p.depth=hit.x,hit.z,hit.width,hit.depth
   hit.hide=M.hide(p,defs)
  else hit.x=false end
 end
 if not hit.x then return end
 p.x,p.z,p.width,p.depth,p.hide=hit.x,hit.z,hit.width,hit.depth,hit.hide
 return p
end
local function doorCells(profile,defs)
 local out={};local def=defs[profile.city]
 for _,w in ipairs(def and def.warps or{})do
  if w.destMap==profile.dest then out[#out+1]={w.x*16,w.y*16,w.x*16+16,w.y*16+16}end
 end
 return out
end
function M.anchor(profile,defs)
 for _,b in ipairs(V.require('BuildingInventory'))do
  if b.map==profile.city and b.destination==profile.dest then return b.x+b.w/2,b.z+b.d/2,b.w,b.d end
 end
 local def=defs[profile.city]
 if def then
  -- TEST178: a room's own building without a name in the inventory (the
  -- Pokemon Tower): the inventory's building its door stands under
  if profile.nearest then
   local doors=doorCells(profile,defs)
   -- each door's own building (a gate with two passages has two)
   local x0,z0,x1,z1
   for _,d in ipairs(doors)do
    local best,bd
    for _,b in ipairs(V.require('BuildingInventory'))do
     -- (only a building the inventory could not name: a named one is
     -- another room's)
     if b.map==profile.city and(b.destination or'')==''then
      local gx=math.max(0,b.x-d[3],d[1]-(b.x+b.w))
      local gz=math.max(0,b.z-d[4],d[2]-(b.z+b.d))
      local cx,cz=(d[1]+d[3])/2,(d[2]+d[4])/2
      local facing=(cx>=b.x and cx<=b.x+b.w)or(cz>=b.z and cz<=b.z+b.d)
      local gap=math.max(gx,gz)
      if facing and gap<=24 and(not bd or gap<bd)then best,bd=b,gap end
     end
    end
    if best then
     x0=math.min(x0 or 1e9,best.x);z0=math.min(z0 or 1e9,best.z)
     x1=math.max(x1 or -1e9,best.x+best.w);z1=math.max(z1 or -1e9,best.z+best.d)
    end
   end
   if x0 then return (x0+x1)/2,(z0+z1)/2,x1-x0,z1-z0 end
   -- no building on record: its size from its doors. A passage (a gate)
   -- runs between its two doors; a house stands over its one door, half
   -- its room's size (as the town's buildings are).
   if #doors>0 and profile.roomW then
    local x0,z0,x1,z1=1e9,1e9,-1e9,-1e9
    for _,d in ipairs(doors)do
     x0,z0=math.min(x0,d[1]),math.min(z0,d[2]);x1,z1=math.max(x1,d[3]),math.max(z1,d[4])
    end
    local rw,rd=profile.roomW,profile.roomD
    if x1-x0>32 and x1-x0>=z1-z0 then
     local w=x1-x0-32;return (x0+x1)/2,(z0+z1)/2,w,w*rd/rw
    elseif z1-z0>32 then
     local d=z1-z0-32;return (x0+x1)/2,(z0+z1)/2,d*rw/rd,d
    end
    local w,d=rw*.5,rd*.5
    return (x0+x1)/2,z1-d/2,w,d
   end
  end
  for _,w in ipairs(def.warps or{})do if w.destMap==profile.dest then return w.x*16+8,w.y*16-16 end end
 end
 -- No fabricated location for a modified or unidentified building.
 return nil
end
-- TEST178: what a room's view leaves out of the town: the building itself
-- and the cells in front of its doors (its own door frame and steps)
function M.hide(profile,defs)
 local hw,hd=(profile.width or 64)/2+2,(profile.depth or 48)/2+2
 local r={profile.x-hw,profile.z-hd,profile.x+hw,profile.z+hd}
 -- (TEST180: a building in several inventory pieces -- the Museum and its
 -- annex -- hides all of them)
 for _,b in ipairs(V.require('BuildingInventory'))do
  if b.map==profile.city and b.destination==profile.dest and(b.destination or'')~=''then
   r[1]=math.min(r[1],b.x-2);r[2]=math.min(r[2],b.z-2);r[3]=math.max(r[3],b.x+b.w+2);r[4]=math.max(r[4],b.z+b.d+2)
  end
 end
 if profile.generic then
  local cx,cz=(r[1]+r[3])/2,(r[2]+r[4])/2
  for _,d in ipairs(doorCells(profile,defs))do
   -- only a door at the building's edge (not one across the town)
   if d[1]<=r[3]+8 and d[3]>=r[1]-8 and d[2]<=r[4]+24 and d[4]>=r[2]-8 and d[2]>=r[2] then
    r[1]=math.min(r[1],d[1]-1);r[2]=math.min(r[2],d[2]-1)
    r[3]=math.max(r[3],d[3]+1);r[4]=math.max(r[4],d[4]+1)
    -- TEST181: and the stretch OUTSIDE the door -- the town's own door
    -- leaf, porch and steps stand there (the Viridian school's closed door
    -- filled the view from inside); 24 units out from the door's side
    local dx,dz=(d[1]+d[3])/2-cx,(d[2]+d[4])/2-cz
    if math.abs(dz)>=math.abs(dx) then
     if dz>0 then r[4]=math.max(r[4],d[4]+24)else r[2]=math.min(r[2],d[2]-24)end
    else
     if dx>0 then r[3]=math.max(r[3],d[3]+24)else r[1]=math.min(r[1],d[1]-24)end
    end
   end
  end
 end
 return r
end
function M.binocularArt(map,x,y)
 return map:tileAt(x,y)==36 and map:tileAt(x+1,y)==36
  and map:tileAt(x,y+1)==52 and map:tileAt(x+1,y+1)==52
  and map:tileAt(x,y+2)==57 and map:tileAt(x+1,y+2)==57
end
function M.binocularAt(state)
 if not(state and state.map and M.gates[state.map.id]and state.player)then return false end
 local p=state.player;if p.moving or p.facing~='up'then return false end
 if type(p.cellX)~='number' or type(p.cellY)~='number' or not state.map.tileAt then return false end
 local x,y=p.cellX*2,p.cellY*2
 -- Both halves of the source pedestal are usable, including free movement
 -- at a tile boundary. Require the complete documented binocular artwork.
 for xx=x-1,x do
 for yy=y-4,y-1 do
  if yy+2>=y-2 and M.binocularArt(state.map,xx,yy)then return true end
 end
 end
 return false
end
return M
