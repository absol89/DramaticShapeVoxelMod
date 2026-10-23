-- TEST173: THE TOWN INTERIORS. Every Pokemon Center and Mart, the houses of
-- every town (each town furnished in its own way), the gyms, the gates and
-- the town's other rooms are rebuilt as authored 3D rooms.
--
-- The ROM map still owns collision, warps, trainers, scripts and items.
-- Every model stands on cells the game already blocks; walkable floor stays
-- clear and flat at y=0, and seats keep the heights the actors sit at.
-- Doors and trees that scripts restamp follow the live tiles (the room is
-- rebuilt when one changes).
--
-- This module is the frame: which maps, their layouts (InteriorLayouts,
-- generated from the ROM blocks), the live-map check, the meshes, the draw,
-- the effects hook (LeagueRoomFx draws them) and the window panes the
-- scenic views look out of. The rooms themselves are built by
-- InteriorTown (centers, marts, houses), InteriorGyms and InteriorCivic,
-- with the furniture of InteriorKit, on the League rooms' build context.
--
-- Layout legend (one character per 16-unit cell; each builder reads its own):
--   .  walkable floor      m  door mat / exit     ^ v  stairs up / down
--   W  wall band           w  window              p  picture or poster
--   V  void                X  something blocked (unlabelled)
--   B b  bookcases         T  table               s  stool (walkable seat)
--   P  potted plant        C  counter             H  healing machine
--   K  computer            I  pillar              L  Cable Club counter
--   U  couch / bed         F E  mart displays     G  shop gondola
--   R  register            O  blackboard          N  television
--   S  chair (blocked)     g  big window          Y  binoculars
--   d  north/south exit    e  east/west exit      k f t h c x r  the
--   ransacked house: cracked wall, footprints, a toppled stool, the hole in
--   the wall, cans, the broken table, rubble
local V=...
local M={REVISION='interior-rooms-247',diagnostics={}}
local RM=V.require('ReferenceMaterials')
local floor,min,max,abs,sqrt=math.floor,math.min,math.max,math.abs,math.sqrt

------------------------------------------------------------------ registry
-- set: the builder module, room: its builder, city: whose finishes;
-- kind: which setting rules it ('town' TOWN INTERIORS, 'dungeon' DUNGEON
-- INTERIORS, 'tower' DUNGEON INTERIORS and TOWER VISUALS both)
local ROOMS={}
local function reg(set,room,list,kind)
 for id,city in pairs(list)do ROOMS[id]={set=set,room=room,city=city,kind=kind or'town'}end
end
reg('InteriorTown','center',{VIRIDIAN_POKECENTER='VIRIDIAN',PEWTER_POKECENTER='PEWTER',CERULEAN_POKECENTER='CERULEAN',
 MT_MOON_POKECENTER='MTMOON',ROCK_TUNNEL_POKECENTER='ROCKTUNNEL',VERMILION_POKECENTER='VERMILION',
 LAVENDER_POKECENTER='LAVENDER',CELADON_POKECENTER='CELADON',SAFFRON_POKECENTER='SAFFRON',
 FUCHSIA_POKECENTER='FUCHSIA',CINNABAR_POKECENTER='CINNABAR'})
reg('InteriorTown','hotel',{CELADON_HOTEL='CELADON'})
reg('InteriorTown','mart',{VIRIDIAN_MART='VIRIDIAN',PEWTER_MART='PEWTER',CERULEAN_MART='CERULEAN',
 VERMILION_MART='VERMILION',LAVENDER_MART='LAVENDER',SAFFRON_MART='SAFFRON',FUCHSIA_MART='FUCHSIA',
 CINNABAR_MART='CINNABAR'})
reg('InteriorTown','house',{BLUES_HOUSE='PALLET',VIRIDIAN_NICKNAME_HOUSE='VIRIDIAN',
 PEWTER_NIDORAN_HOUSE='PEWTER',PEWTER_SPEECH_HOUSE='PEWTER',CERULEAN_TRADE_HOUSE='CERULEAN',
 CERULEAN_TRASHED_HOUSE='CERULEAN',VERMILION_PIDGEY_HOUSE='VERMILION',VERMILION_OLD_ROD_HOUSE='VERMILION',
 VERMILION_TRADE_HOUSE='VERMILION',LAVENDER_CUBONE_HOUSE='LAVENDER',MR_FUJIS_HOUSE='LAVENDER',
 NAME_RATERS_HOUSE='LAVENDER',SAFFRON_PIDGEY_HOUSE='SAFFRON',MR_PSYCHICS_HOUSE='SAFFRON',
 FUCHSIA_BILLS_GRANDPAS_HOUSE='FUCHSIA',ROUTE_2_TRADE_HOUSE='ROUTE2',DAYCARE='ROUTE5',
 ROUTE_12_SUPER_ROD_HOUSE='ROUTE12',ROUTE_16_FLY_HOUSE='ROUTE16',
 VIRIDIAN_SCHOOL_HOUSE='VIRIDIAN',CELADON_MANSION_ROOF_HOUSE='CELADON'})
reg('InteriorTown','copycat',{COPYCATS_HOUSE_1F='SAFFRON',COPYCATS_HOUSE_2F='SAFFRON'})
reg('InteriorGyms','pewter',{PEWTER_GYM='PEWTER'})
reg('InteriorGyms','cerulean',{CERULEAN_GYM='CERULEAN'})
reg('InteriorGyms','vermilion',{VERMILION_GYM='VERMILION'})
reg('InteriorGyms','celadon',{CELADON_GYM='CELADON'})
reg('InteriorGyms','fuchsia',{FUCHSIA_GYM='FUCHSIA'})
reg('InteriorGyms','saffron',{SAFFRON_GYM='SAFFRON'})
reg('InteriorGyms','cinnabar',{CINNABAR_GYM='CINNABAR'})
reg('InteriorGyms','viridian',{VIRIDIAN_GYM='VIRIDIAN'})
reg('InteriorGates','gate',{ROUTE_2_GATE='ROUTE2',VIRIDIAN_FOREST_NORTH_GATE='ROUTE2',VIRIDIAN_FOREST_SOUTH_GATE='ROUTE2',
 ROUTE_5_GATE='SAFFRON',ROUTE_6_GATE='SAFFRON',ROUTE_7_GATE='SAFFRON',ROUTE_8_GATE='SAFFRON',
 ROUTE_11_GATE_1F='VERMILION',ROUTE_11_GATE_2F='VERMILION',ROUTE_12_GATE_1F='LAVENDER',ROUTE_12_GATE_2F='LAVENDER',
 ROUTE_15_GATE_1F='FUCHSIA',ROUTE_15_GATE_2F='FUCHSIA',ROUTE_16_GATE_1F='CELADON',ROUTE_16_GATE_2F='CELADON',
 ROUTE_18_GATE_1F='FUCHSIA',ROUTE_18_GATE_2F='FUCHSIA',SAFARI_ZONE_GATE='FUCHSIA',
 SAFARI_ZONE_CENTER_REST_HOUSE='FUCHSIA',SAFARI_ZONE_EAST_REST_HOUSE='FUCHSIA',
 SAFARI_ZONE_NORTH_REST_HOUSE='FUCHSIA',SAFARI_ZONE_WEST_REST_HOUSE='FUCHSIA'})
reg('InteriorCivic','museum',{MUSEUM_1F='PEWTER',MUSEUM_2F='PEWTER'})
reg('InteriorCivic','bikeShop',{BIKE_SHOP='CERULEAN'})
reg('InteriorCivic','diner',{CELADON_DINER='CELADON'})
reg('InteriorCivic','deptStore',{CELADON_MART_1F='CELADON',CELADON_MART_2F='CELADON',CELADON_MART_3F='CELADON',
 CELADON_MART_4F='CELADON',CELADON_MART_5F='CELADON'})
reg('InteriorCivic','elevator',{CELADON_MART_ELEVATOR='CELADON'})
reg('InteriorCivic','mansion',{CELADON_MANSION_1F='CELADON',CELADON_MANSION_2F='CELADON',CELADON_MANSION_3F='CELADON'})
reg('InteriorCivic','chiefHouse',{CELADON_CHIEF_HOUSE='CELADON'})
reg('InteriorCivic','lab',{CINNABAR_LAB='CINNABAR',CINNABAR_LAB_FOSSIL_ROOM='CINNABAR',CINNABAR_LAB_METRONOME_ROOM='CINNABAR',
 CINNABAR_LAB_TRADE_ROOM='CINNABAR',FUCHSIA_MEETING_ROOM='FUCHSIA',SAFARI_ZONE_SECRET_HOUSE='FUCHSIA',WARDENS_HOUSE='FUCHSIA'})
reg('InteriorCivic','dojo',{FIGHTING_DOJO='SAFFRON'})
reg('InteriorCivic','bill',{BILLS_HOUSE='CERULEAN'})
reg('InteriorCivic','fanClub',{POKEMON_FAN_CLUB='VERMILION'})
reg('InteriorCivic','shipHouse',{CERULEAN_BADGE_HOUSE='CERULEAN',FUCHSIA_GOOD_ROD_HOUSE='FUCHSIA'})
-- TEST174: the dungeons
reg('InteriorTower','tower',{POKEMON_TOWER_1F='LAVENDER',POKEMON_TOWER_2F='LAVENDER',POKEMON_TOWER_3F='LAVENDER',
 POKEMON_TOWER_4F='LAVENDER',POKEMON_TOWER_5F='LAVENDER',POKEMON_TOWER_6F='LAVENDER',POKEMON_TOWER_7F='LAVENDER'},'tower')
reg('InteriorMansion','mansion',{POKEMON_MANSION_1F='CINNABAR',POKEMON_MANSION_2F='CINNABAR',POKEMON_MANSION_3F='CINNABAR',
 POKEMON_MANSION_B1F='CINNABAR'},'dungeon')
reg('InteriorSilph','silph',{SILPH_CO_1F='SAFFRON',SILPH_CO_2F='SAFFRON',SILPH_CO_3F='SAFFRON',SILPH_CO_4F='SAFFRON',
 SILPH_CO_5F='SAFFRON',SILPH_CO_6F='SAFFRON',SILPH_CO_7F='SAFFRON',SILPH_CO_8F='SAFFRON',SILPH_CO_9F='SAFFRON',
 SILPH_CO_10F='SAFFRON'},'dungeon')
reg('InteriorSilph','office',{SILPH_CO_11F='SAFFRON'},'dungeon')
reg('InteriorCivic','elevator',{SILPH_CO_ELEVATOR='SAFFRON'},'dungeon')
reg('InteriorShip','ship',{SS_ANNE_1F='VERMILION',SS_ANNE_2F='VERMILION',SS_ANNE_3F='VERMILION',SS_ANNE_B1F='VERMILION',
 SS_ANNE_1F_ROOMS='VERMILION',SS_ANNE_2F_ROOMS='VERMILION',SS_ANNE_B1F_ROOMS='VERMILION',SS_ANNE_KITCHEN='VERMILION',
 SS_ANNE_CAPTAINS_ROOM='VERMILION'},'dungeon')
reg('InteriorShip','bow',{SS_ANNE_BOW='VERMILION'},'dungeon')
reg('InteriorPlant','plant',{POWER_PLANT='ROUTE10'},'dungeon')
-- TEST175
reg('InteriorRocket','hideout',{ROCKET_HIDEOUT_B1F='CELADON',ROCKET_HIDEOUT_B2F='CELADON',ROCKET_HIDEOUT_B3F='CELADON',
 ROCKET_HIDEOUT_B4F='CELADON'},'dungeon')
reg('InteriorRocket','lift',{ROCKET_HIDEOUT_ELEVATOR='CELADON'},'dungeon')
reg('InteriorUnderground','tunnel',{UNDERGROUND_PATH_NORTH_SOUTH='SAFFRON',UNDERGROUND_PATH_WEST_EAST='SAFFRON'},'dungeon')
reg('InteriorExtras','roof',{CELADON_MANSION_ROOF='CELADON'})
reg('InteriorExtras','club',{TRADE_CENTER='CELADON',COLOSSEUM='CELADON'})
reg('InteriorUnderground','hall',{UNDERGROUND_PATH_ROUTE_5='SAFFRON',UNDERGROUND_PATH_ROUTE_6='SAFFRON',
 UNDERGROUND_PATH_ROUTE_7='SAFFRON',UNDERGROUND_PATH_ROUTE_8='SAFFRON'},'dungeon')
-- TEST202: gen1recomp's shared upstairs (the union room's floor, one map
-- for every Center). Not a ROM map: no tile check (engine=true); the city
-- is the Center you came up from (LeagueRooms tracks it; the Plateau's
-- lobby makes it the League's, which LeagueRooms claims first).
ROOMS.POKECENTER_2F={set='InteriorTown',room='upstairs',city='VIRIDIAN',kind='town',engine=true}
M.ROOMS=ROOMS
-- more rooms register themselves (InteriorGyms, InteriorCivic)
function M.register(set,room,list,kind)reg(set,room,list,kind)end

local layouts
-- TEST202: the engine's upstairs (UnionCenters.build2F): its doors in the
-- back wall at cells 6 and 10 (cut by the builder), the counter with its
-- closed gates (L), the flight down at (13,1), planters in the corners
local ENGINE={
 POKECENTER_2F={w=7,h=4,ts='POKECENTER',engine=true,rows={
  "WWWWWWWWWWWWWW",
  "............Wv",
  "CCCCCCLCCCLCC.",
  "..............",
  "..............",
  "..............",
  "PP..........PP",
  "PP..........PP"}},
}
local function L()
 if layouts==nil then
  local ok,t=pcall(V.require,'InteriorLayouts')
  layouts=ok and type(t)=='table' and t or false
  if layouts then for id,Lt in pairs(ENGINE)do if layouts[id]==nil then layouts[id]=Lt end end end
 end
 return layouts or ENGINE
end
M.layouts=L

------------------------------------------------------------------ setting
local function settingOn(R)
 local ok,CV=pcall(V.require,'CommunityVisuals')
 if not(ok and CV)then return true end
 local kind=R and R.kind or'town'
 local s=kind=='town'and CV.interiors or CV.dungeons
 if s then
  local okG,v=pcall(s.get,s)
  if okG and v=='default'then return false end
 end
 -- the Tower is ours only with the Legendary tower (its fog and finishes)
 if kind=='tower'and CV.customTower then
  local okT,on=pcall(CV.customTower)
  if okT and not on then return false end
 end
 return true
end
M.settingOn=settingOn

------------------------------------------------------------------ live check
-- The ROM layout must be the map that is loaded: the top-left tile of each
-- cell is compared (a hack or another mod's map stays with the engine). A
-- few cells may differ (a script's door, a cut tree).
local logged={}
local function log(fmt,...)
 if V.mod and V.mod.log and V.mod.log.info then pcall(V.mod.log.info,V.mod.log,fmt,...)end
end
-- TEST179/97: retain a useful device-visible reason, including GPU failures.
local reasons={}
M.reasons=reasons
local function why(id,text)
 if reasons[id]~=text then
  reasons[id]=text
  if text then log('Interior %s: %s',tostring(id),text)end
 end
end
M.why=why
local verified=setmetatable({},{__mode='k'})
-- The generated layouts use Red's decorative tile IDs. Yellow's standard
-- Center has four different samples (the poster and Cable Club frontage).
-- Compare both complete known layouts, so those decorations do not consume
-- the whole four-cell allowance intended for live scripted changes.
local CENTER_YELLOW='10283b4c2810283b28285c285c2810484d360110484d010101010101043808080804080808085a015a085a360101010101010101010101422439010101010101010101010109263601010101010101010101010120200101010120200101010120202222010c0c012222010101012222'
-- TEST95: collision is determined by the bottom-left tile of every cell.
-- Check complete known 14x8 Center footprints even where the
-- posters/healing artwork differ (each ROM has its own signature). Exact equality only: no extra tolerance.
local CENTER_FOOTPRINT_RED='10284b281310284b28285e285e281048161a1110481611111111111114181818181418181818191119181111111111111111111111111152343c1111111111111111111111112a1a11111111111111111111111130301111111130301111111130303232111c1c113232111111113232'
local CENTER_FOOTPRINT_YELLOW='10284b5a2810284b28285e285e281048161a111048161111111111111418181818141818181819111918191a111111111111111111111152343c1111111111111111111111112a1a11111111111111111111111130301111111130301111111130303232111c1c113232111111113232'
local rejectedAt=setmetatable({},{__mode='k'})
local function centerFootprint(map,Lt,R)
 if R.room~='center'or Lt.w~=7 or Lt.h~=4 then return false end
 local red,yellow=true,true
 for cy=0,7 do for cx=0,13 do
  local i=(cy*14+cx)*2
  local ok,t=pcall(map.tileAt,map,cx*2,cy*2+1)
  if not ok or t~=tonumber(CENTER_FOOTPRINT_RED:sub(i+1,i+2),16)then red=false end
  if not ok or t~=tonumber(CENTER_FOOTPRINT_YELLOW:sub(i+1,i+2),16)then yellow=false end
  if not(red or yellow)then return false end
 end end
 return red or yellow
end
local function report(map,accepted,reason)
 local id=map.id;local old=M.diagnostics[id]
 why(id,not accepted and reason or nil)
 if old and old.accepted==accepted and old.reason==reason then return end
 M.diagnostics[id]={accepted=accepted,reason=reason}
 local logger=V.mod and V.mod.log
 if logger and logger.info then pcall(logger.info,logger,'Interior %s layout: %s',tostring(id),reason)end
end
local function verify(map,Lt,R)
 local v=verified[map]
 if v then return true end
 local now=(love and love.timer and love.timer.getTime and love.timer.getTime())or os.clock()
 if v==false and now<(rejectedAt[map]or 0)then return false end
 v=false
 if map.tileAt and Lt.check then
  local cw,ch=Lt.w*2,Lt.h*2
  local alternate=R.room=='center'and Lt.w==7 and Lt.h==4 and CENTER_YELLOW or nil
  local bad,altBad,unionBad,n,missing=0,0,0,0,0
  local union=Lt.union and Lt.union.check
  local examples={}
  for cy=0,ch-1 do for cx=0,cw-1 do
   local i=(cy*cw+cx)*2
   local want=tonumber(Lt.check:sub(i+1,i+2),16)
   -- (TEST175: 'zz' marks a cell the ROM does not define -- the
   -- north-south tunnel's blocks stop a row short of its map)
   if want~=nil then
    local ok,t=pcall(map.tileAt,map,cx*2,cy*2)
    n=n+1
    if not ok or type(t)~='number'or t<0 then missing=missing+1 end
    if not ok or t~=want then
     bad=bad+1
     if #examples<6 then examples[#examples+1]=cx..','..cy..'='..tostring(t)end
    end
    if alternate and(not ok or t~=tonumber(alternate:sub(i+1,i+2),16))then altBad=altBad+1 end
    if union and(not ok or t~=tonumber(union:sub(i+1,i+2),16))then unionBad=unionBad+1 end
   end
  end end
  local best=alternate and min(bad,altBad)or bad
  local limit=max(2,floor(n*.04))
  -- Select the closest known layout, rather than letting ROM tolerance
  -- swallow an engine-added staircase. Missing tiles never earn ownership.
  if missing==0 and n>0 then
   if union and unionBad<best and unionBad<=limit then v='union'
   elseif best<=limit then v='rom' end
  end
  local footprint=not v and missing==0 and centerFootprint(map,Lt,R)
  if footprint then v='rom' end
  report(map,v and true or false,(v and('accepted '..v)or'rejected')..' samples='..n..' differences='..best..' missing='..missing
   ..(union and(' union='..unionBad)or'')..(footprint and' exact Center footprint'or'')..(alternate and(' red='..bad..' yellow='..altBad)or'')..(not v and(' cells '..table.concat(examples,';'))or''))
  -- An incomplete map is not a permanent layout verdict.
  if missing>0 then return false end
 else
  report(map,false,'waiting for source tile data')
  return false
 end
 verified[map]=v
 rejectedAt[map]=not v and now+.5 or nil
 return v and true or false
end
-- TEST202: which town's Center the shared upstairs belongs to right now
-- (nil: the League's, or no town room for it)
local function upstairsCity()
 local okL,LR=pcall(V.require,'LeagueRooms')
 if not(okL and LR and LR.upstairsOrigin)then return 'VIRIDIAN' end
 local okO,origin,league=pcall(LR.upstairsOrigin)
 if not okO then return 'VIRIDIAN' end
 if league then return nil end
 local O=origin and ROOMS[origin]
 if O and O.room=='center'then return O.city end
 return 'VIRIDIAN'
end
M.upstairsCity=upstairsCity
function M.accepts(map)
 local id=map and map.id
 local R=id and ROOMS[id]
 if not R then return false end
 local Lt=L()[id]
 if not(Lt and map.def and map.def.width==Lt.w and map.def.height==Lt.h)then
  report(map,false,'unmatched dimensions '..tostring(map.def and map.def.width)..'x'..tostring(map.def and map.def.height));return false
 end
 if map.tileset and map.tileset.id and map.tileset.id~=Lt.ts then report(map,false,'unmatched tileset '..tostring(map.tileset.id));return false end
 if not settingOn(R)then report(map,false,'interior setting disabled');return false end
 if R.engine then
  local city=upstairsCity()
  if not city then report(map,false,'the League dresses this floor');return false end
  R.city=city
  report(map,true,'engine floor, dressed as '..city)
  return true
 end
 return verify(map,Lt,R)
end
-- the layout the live map is (the ROM's, or the engine's variant of it)
local variants={}
local function layoutFor(map)
 local id=map and map.id;local Lt=L()[id]
 if not Lt then return nil end
 if verified[map]=='union' and Lt.union then
  local u=variants[id]
  if not u then
   u={}
   for k,val in pairs(Lt)do u[k]=val end
   for k,val in pairs(Lt.union)do u[k]=val end
   u.variant='union';u.union=nil
   variants[id]=u
  end
  return u
 end
 return Lt
end
M.layoutFor=layoutFor
function M.owns(map)return M.accepts(map)end

------------------------------------------------------------------ stairs
-- TEST247: THE STAIRS WHERE THE GAME'S STAIRS ARE. Joseph walked up to the
-- staircase drawn on the Department Store's back wall and nothing happened;
-- two steps to the left, at a sign, the floor changed. The generated
-- layouts had read the floor sign every floor has at x=14 (tile 2E) as the
-- way up, and the real way up (tile 0C, x=12 or x=16 by floor) as a sign.
-- For the rooms listed here the stairs are put where the map's own warps to
-- the building's other floors are -- up ('^') to a higher floor or the
-- roof, down ('v') to a lower one -- and a staircase the layout draws where
-- there is no such warp becomes what the value says (here 'p', the sign).
-- The ROM still owns the warps and collision; this only moves the model.
M.STAIRS_FROM_WARPS={CELADON_MART_1F='p',CELADON_MART_2F='p',CELADON_MART_3F='p',CELADON_MART_4F='p',CELADON_MART_5F='p'}
local function floorOf(id)
 id=tostring(id or'')
 local b=id:match('^(.-)_ROOF$');if b then return 99,b end
 local bb,bn=id:match('^(.-)_B(%d+)F$');if bb then return -tonumber(bn),bb end
 local p,n=id:match('^(.-)_(%d+)F$');if p then return tonumber(n),p end
 return nil
end
M._floorOf=floorOf
local stairsLogged={}
local function stairsFromWarps(Lt,map,id)
 local other=M.STAIRS_FROM_WARPS and M.STAIRS_FROM_WARPS[id]
 if not(other and Lt and Lt.rows)then return Lt end
 local warps=map and map.def and map.def.warps
 if type(warps)~='table'then return Lt end
 local here,base=floorOf(id)
 if not here then return Lt end
 local want={}
 for _,w in ipairs(warps)do
  local f,b=floorOf(w.destMap)
  if f and b==base and f~=here and type(w.x)=='number'and type(w.y)=='number'then
   want[w.y*1000+w.x]={x=w.x,y=w.y,ch=f>here and'^'or'v'}
  end
 end
 if not next(want)then return Lt end
 local rows={}
 for i,r in ipairs(Lt.rows)do rows[i]=r end
 local function set(x,y,c)
  local r=rows[y+1]
  if r and x>=0 and x<#r then rows[y+1]=r:sub(1,x)..c..r:sub(x+2)end
 end
 local changed={}
 for y=0,#rows-1 do
  local r=rows[y+1]
  for x=0,#r-1 do
   local c=r:sub(x+1,x+1)
   local w=want[y*1000+x]
   if(c=='^'or c=='v')and not(w and w.ch==c)then
    set(x,y,y<=1 and other or'.');changed[#changed+1]=('%s at %d,%d -> %s'):format(c,x,y,y<=1 and other or'.')
   end
  end
 end
 for _,w in pairs(want)do
  local r=rows[w.y+1]
  if r and r:sub(w.x+1,w.x+1)~=w.ch then set(w.x,w.y,w.ch);changed[#changed+1]=('%s at %d,%d'):format(w.ch,w.x,w.y)end
 end
 if #changed==0 then return Lt end
 local out={}
 for k,v in pairs(Lt)do out[k]=v end
 out.rows=rows
 if not stairsLogged[id]then
  stairsLogged[id]=true
  table.sort(changed)
  log('Interior %s: stairs placed on the map\'s warps (%s)',tostring(id),table.concat(changed,'; '))
 end
 return out
end
M._stairsFromWarps=stairsFromWarps

------------------------------------------------------------------ geometry
-- Every part as quads, the effects and the window panes. Pure: no LOVE.
function M.geometry(id,map)
 local Lt=(map and layoutFor(map))or L()[id];local R=ROOMS[id]
 -- (TEST247: the stairs on the game's own warps)
 if map and Lt then Lt=stairsFromWarps(Lt,map,id)end
 assert(Lt and R,'no interior '..tostring(id))
 local Rooms=V.require('LeagueRooms')
 local C=Rooms.newContextFor(Lt,id)
 C.R=R;C.city=R.city;C.map=map;C.panes={};C.H=56;C.variant=Lt.variant
 C.cellsRaw=Lt.cells
 function C.raw(cx,cy)
  local r=Lt.cells[cy+1];if not r or cx<0 or cx>=#r then return -1 end
  return r:byte(cx+1)-48
 end
 -- a live tile (scripted doors, cut trees); nil off the map or offline
 function C.tile(tx,ty)
  if not(map and map.tileAt)then return nil end
  local ok,t=pcall(map.tileAt,map,tx,ty)
  return ok and t or nil
 end
 local set=V.require(R.set)
 local fn=set[R.room];assert(fn,'no interior room '..tostring(R.room))
 fn(C)
 return C
end

------------------------------------------------------------------ runtime
local cached={}   -- id -> {parts,fx,...} or false after a failure
local current=nil
local white
local function texture()
 if not white then
  local d=love.image.newImageData(2,2);for y=0,1 do for x=0,1 do d:setPixel(x,y,1,1,1,1)end end
  white=love.graphics.newImage(d);white:setFilter('nearest','nearest');d:release()
 end
 return white
end
local function toMesh(quads)
 local vs,ix={},{}
 for _,q in ipairs(quads)do
  local sh=RM.encode(q.referenceMaterial,q.shade)
  local n=#vs
  for i=1,4 do local p=q[i];vs[n+i]={p[1],p[2],p[3],.5,.5,type(sh)=='table'and sh[i]or sh}end
  local k=#ix
  ix[k+1],ix[k+2],ix[k+3],ix[k+4],ix[k+5],ix[k+6]=n+1,n+2,n+3,n+1,n+3,n+4
 end
 return vs,ix
end
local function release(r)
 if r then for _,p in ipairs(r.parts)do pcall(p.mesh.release,p.mesh)end end
end
-- the live tiles a room's look depends on (scripted doors, trees)
local function signature(map,C)
 local w=C and C.watch or nil
 if not w or #w==0 then return 0 end
 local h=7
 for i=1,#w do
  local t=w[i]
  local ok,v=pcall(map.tileAt,map,t[1],t[2])
  h=(h*31+(ok and(v or 0)or 997)+i)%2147483647
 end
 return h
end
local function upload(id,C,map)
 local R=V.require('Voxel3D')
 -- a room with scripted tiles watches the top-left tile of every cell
 if C.watchAll and not C.watch then
  C.watch={}
  for cy=0,C.ch-1 do for cx=0,C.cw-1 do C.watch[#C.watch+1]={cx*2,cy*2}end end
 end
 local parts={};local count=0
 -- TEST174: a big room (a dungeon floor) is cut into chunks of 8x8 cells,
 -- each with its bounds, so the draw skips what is off screen
 local big=(C.cw or 0)>24 or(C.ch or 0)>24
 local function add(name,quads,vis,shadow)
  local vs,ix=toMesh(quads)
  local box
  if big then
   local x0,y0,z0,x1,y1,z1=1e9,1e9,1e9,-1e9,-1e9,-1e9
   for _,q in ipairs(quads)do for i=1,4 do local p=q[i]
    if p[1]<x0 then x0=p[1]end;if p[1]>x1 then x1=p[1]end
    if p[2]<y0 then y0=p[2]end;if p[2]>y1 then y1=p[2]end
    if p[3]<z0 then z0=p[3]end;if p[3]>z1 then z1=p[3]end
   end end
   box={x0,y0,z0,x1,y1,z1}
  end
  local mesh,err=R.newMesh(vs,ix)
  if not mesh then error('mesh upload '..tostring(name)..': '..tostring(err or 'no mesh returned'),0)end
  parts[#parts+1]={name=name,mesh=mesh,vis=vis,shadow=shadow,box=box};count=count+#vs
 end
 -- TEST93: no room is published until EVERY required mesh exists. A nil
 -- GPU allocation is a failure too; release any earlier parts on all errors.
 local ok,result=pcall(function()
 for _,p in ipairs(C.parts)do
  if #p.quads>0 then
   if big and #p.quads>48 then
    local chunks,order={},{}
    for _,q in ipairs(p.quads)do
     local cx=(q[1][1]+q[2][1]+q[3][1]+q[4][1])*.25
     local cz=(q[1][3]+q[2][3]+q[3][3]+q[4][3])*.25
     local k=floor(cx/128)*1000+floor(cz/128)
     local c=chunks[k];if not c then c={};chunks[k]=c;order[#order+1]=k end
     c[#c+1]=q
    end
    for _,k in ipairs(order)do add(p.name..'#'..k,chunks[k],p.vis,p.shadow)end
   else
    add(p.name,p.quads,p.vis,p.shadow)
   end
   p.quads={}
  end
 end
 if #parts==0 then error('room contains no meshes',0)end
 return {parts=parts,fx=C.fx,vertices=count,H=C.H or 56,W=C.W,D=C.D,panes=C.panes,
  watch=C.watch,sig=map and signature(map,C)or 0,shell=C.shell,id=id,next=0,
  openSky=C.openSky or false,variant=C.variant,city=C.city}
 end)
 if not ok then release({parts=parts});error(result,0)end
 return result
end
local NOBUDGET={tick=function()end,check=function()end}
local function build(id,map)
 -- Every entry point (including a lazy prepare after a variant change)
 -- uses the same protected, non-yielding upload transaction.
 pcall(function()V.require('LeagueRooms').useBudget(NOBUDGET)end)
 local ok,res=pcall(function()return upload(id,M.geometry(id,map),map)end)
 local okB,B=pcall(V.require,'BuildBudget')
 if okB then pcall(function()V.require('LeagueRooms').useBudget(B)end)end
 if ok and res then cached[id]=res;why(id,nil);return res end
 cached[id]=false
 why(id,'build failed: '..tostring(res))
 if not logged[id]then logged[id]=true;log('Interior %s failed: %s',tostring(id),tostring(res))end
 return nil
end
local function prepare(map)
 if not M.accepts(map)then return nil end
 local id=map.id
 local r=cached[id]
 if r==false then return nil end
 -- A different ROM/engine layout under the same map ID must not reuse
 -- a room built for the other footprint.
 if r and r.variant~=layoutFor(map).variant then release(r);cached[id]=nil;r=nil end
 if r then
  -- a scripted door or a cut tree changed the room: build it again
  -- (checked four times a second)
  if r.watch and #r.watch>0 then
   local now=(love and love.timer and love.timer.getTime and love.timer.getTime())or os.clock()
   if now>=r.next then
    r.next=now+.25
    if signature(map,r)~=r.sig then release(r);cached[id]=nil;r=nil end
   end
  end
  -- TEST202: the shared upstairs, climbed to from another town's Center
  if r and ROOMS[id].engine and r.city~=ROOMS[id].city then release(r);cached[id]=nil;r=nil end
  if r then return r end
 end
 return build(id,map)
end
M.prepare=prepare
function M.ready(id)local r=cached[id];if r==nil then return nil end;return r and true or false end
-- The tile-art people and things the engine lifts into standees (the man
-- on the Center couch, the Mart's till) are ours to model: repaint their
-- tiles in this build's grid the way the engine does once it has lifted
-- them, so no pass finds the pattern (the tiles are claimed, never drawn).
function M.neutralize(S,map)
 local okT,TS=pcall(V.require,'TileShape')
 if not(okT and TS and S.tileAt and map.tileset)then return end
 local tid=map.tileset.id
 local function key(x,y)return(y+64)*4096+x+64 end
 for _,get in ipairs({TS.figures,TS.mounted})do
  local okL,list=pcall(get,tid)
  for _,f in ipairs(okL and list or{})do
   local w=f.w;local h=#f.tiles/w
   for ty=0,map.def.height*4-h do for tx=0,map.def.width*4-w do
    local hit=true
    for i=1,#f.tiles do
     if S.tileAt[key(tx+(i-1)%w,ty+floor((i-1)/w))]~=f.tiles[i]then hit=false;break end
    end
    if hit then for i=1,#f.tiles do S.tileAt[key(tx+(i-1)%w,ty+floor((i-1)/w))]=f.under[i]end end
   end end
  end
 end
end
-- TEST177: the room is built FIRST, in one piece, and the map is claimed
-- only once it exists. Before, the map was claimed and then the room built
-- with the scene build's budget pausing it from inside the protected call;
-- a room that failed (or could not be resumed there) left a map with no
-- floor at all, which the renderer reads as a broken mesh and hands to the
-- 2D game (the Viridian school and Mart did exactly that). Now a room that
-- fails leaves the engine's own 3D room in place, and the failure is
-- logged once. A builder may keep cells for the engine (set.keep: the
-- Cerulean Gym's pool is the engine's own water, swimmers and all).
function M.build(S,map)
 if not M.accepts(map)then return end
 local id=map.id
 local r=cached[id]
 if r then release(r);cached[id]=nil end
 local built=build(id,map)
 if not built then return end
 M.neutralize(S,map)
 local keep
 do
  local R=ROOMS[id];local okS,set=pcall(V.require,R.set)
  if okS and set and set.keep then keep=set.keep end
 end
 local Lt=layoutFor(map)
 local tw,th=map.def.width*4,map.def.height*4
 -- the map and the engine's border ring round it: the room is all there is
 for ty=-12,th+11 do for tx=-12,tw+11 do
  local claim=true
  if keep and tx>=0 and ty>=0 and tx<tw and ty<th then
   local row=Lt.rows[floor(ty/2)+1]
   local ch=row and row:sub(floor(tx/2)+1,floor(tx/2)+1)
   if ch and ch~='' then
    local okK,kept=pcall(keep,id,ch)
    if okK and kept then claim=false end
   end
  end
  if claim then
   local k=(ty+64)*4096+tx+64
   S.skip[k]=true;S.ground[k]=nil
   S.shapeAt[k]={class='ground',h=0,flat=true,art='flat',authored=true}
   -- TEST191: remembered, so the mesher can refuse anything a LATER pass
   -- puts back here (the figure pass re-floors a gym statue's drawn cell)
   S.roomClaim=S.roomClaim or{};S.roomClaim[k]=true
  end
 end end
 S.interiorRoom=id
end
-- where the player stands (LeagueRoomFx reports it each frame)
M.player=nil
function M.step()end
function M.fx(map,eye)
 local r=prepare(map);if not r then return nil end
 return r.fx,r
end
-- TEST174: is a chunk's box (grown by a margin, and down for the world's
-- curve) inside the camera's view? All eight corners past one clip plane:
-- no.
local function onScreen(b,vp)
 if not(b and vp)then return true end
 local m=16
 local xs={b[1]-m,b[4]+m};local ys={b[2]-64,b[5]+m};local zs={b[3]-m,b[6]+m}
 local l,r,d,u,n=0,0,0,0,0
 for i=1,2 do for j=1,2 do for k=1,2 do
  local x,y,z=xs[i],ys[j],zs[k]
  local cx=vp[1]*x+vp[2]*y+vp[3]*z+vp[4]
  local cy=vp[5]*x+vp[6]*y+vp[7]*z+vp[8]
  local cw=vp[13]*x+vp[14]*y+vp[15]*z+vp[16]
  if cx<-cw then l=l+1 end;if cx>cw then r=r+1 end
  if cy<-cw then d=d+1 end;if cy>cw then u=u+1 end
  if cw<.05 then n=n+1 end
 end end end
 return not(l==8 or r==8 or d==8 or u==8 or n==8)
end
M.onScreen=onScreen
local function visible(vis,eye)
 if not vis then return true end
 if not V.require('LeagueRooms').visible(vis,eye,false,M.player)then return false end
 -- a partition standing between the eye and the player is cut away
 if vis.sep and M.player and vis.axis then
  local e=vis.axis=='x'and eye[1]or eye[3]
  local p=vis.axis=='x'and M.player[1]or M.player[2]
  if (e-vis.c)*(p-vis.c)<0 then return false end
 end
 return true
end
function M.draw(map,shadow)
 local r=prepare(map);if not r then return end
 current=map.id
 local tex=texture()
 if shadow then
  for _,p in ipairs(r.parts)do if p.shadow then pcall(shadow.draw,p.mesh,tex)end end
  return
 end
 local R=V.require('Voxel3D')
 R.glass(false)
 local ok,err=pcall(function()
  if R.seams then R.seams(false)end
  local eye=R.eye or {r.W/2,90,r.D+80}
  local vp=R.vp
  for _,p in ipairs(r.parts)do
   if visible(p.vis,eye)and(not p.box or onScreen(p.box,vp))then R.draw(p.mesh,tex)end
  end
 end)
 -- Optional imported actors have their own error boundary. Their failure
 -- must never drop an otherwise ready room or its native pool.
 if ok and r.fx and r.fx.aquarium then
  local okA,A=pcall(V.require,'InteriorAquarium')
  if okA and A then pcall(A.draw,map,r.fx)end
 end
 if R.seams then R.seams(true)end
 R.glass(true)
 if not ok then
  -- never take the whole 3D view down with a room: drop the room instead
  release(r);cached[map.id]=false
  why(map.id,'draw failed: '..tostring(err))
  if not logged[map.id]then logged[map.id]=true;log('Interior %s draw failed: %s',tostring(map.id),tostring(err))end
 end
end
function M.invalidate()
 local okA,A=pcall(V.require,'InteriorAquarium');if okA and A then pcall(A.invalidate)end
 for _,r in pairs(cached)do release(r)end
 cached={}
 verified=setmetatable({},{__mode='k'})
end
-- keep the rooms that are live (and the one drawn last); free the rest
function M.setLive(live)
 local okA,A=pcall(V.require,'InteriorAquarium');if okA and A then pcall(A.setLive,live)end
 if current and not(live and live[current])then current=nil end
 for id,r in pairs(cached)do
  if not(live and live[id])then release(r);cached[id]=nil end
 end
end

------------------------------------------------------------------ support
-- The height an actor stands at on a cell (a seat, an item on a table):
-- GameCorner.support asks. Read off the layout, no build needed; 0 for any
-- other cell of a room we draw (its floor is flat).
function M.support(map,cx,cy)
 if not M.accepts(map)then return nil end
 local id=map.id;local R=ROOMS[id];local Lt=layoutFor(map)
 local row=Lt.rows[cy+1];if not row then return 0 end
 local ch=row:sub(cx+1,cx+1)
 local ok,set=pcall(V.require,R.set)
 if ok and set and set.support then
  local okS,h=pcall(set.support,id,ch,cx,cy)
  if okS and h then return h end
 end
 return 0
end

-- TEST174: the Tower's graves (cell centres, world units) for the grave
-- mist (TowerGraveMist), which would otherwise read them off the tiles
-- this room has claimed
function M.graves(map)
 if not M.accepts(map)then return nil end
 local Lt=layoutFor(map);local out={}
 for cy,row in ipairs(Lt.rows)do
  for cx=1,#row do if row:sub(cx,cx)=='G'then out[#out+1]={(cx-1)*16+8,(cy-1)*16+8}end end
 end
 return out
end

------------------------------------------------------------------ windows
-- The panes ScenicViews looks out of (Celadon's upstairs windows, the gates'
-- upper floors), in its corner format; and which shell walls face the eye.
function M.windowPanes(map)
 local r=prepare(map)
 return r and r.panes or {}
end
-- Only a successfully uploaded, enabled room may open the sky. Sky queries
-- must never start geometry work outside the protected no-yield build path.
function M.openSky(map)
 if not(map and map.id and ROOMS[map.id])then return false end
 local r=cached[map.id]
 return r and r.openSky and M.accepts(map) or false
end
function M.visibleShell(map,eye)
 local r=prepare(map)
 eye=eye or {0,90,9999}
 local s=r and r.shell or {n=16,s=(r and r.D)or 128,w=0,e=(r and r.W)or 128}
 return {north=eye[3]>s.n,south=eye[3]<s.s,west=eye[1]>s.w,east=eye[1]<s.e}
end
return M
