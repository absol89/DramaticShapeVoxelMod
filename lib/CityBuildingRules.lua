-- Explicit identity before regional appearance. No position-hash landmarks.
local M={}
M.regions={
 PALLET_TOWN={wall='cream',roof='terra',accent='blue'},
 VIRIDIAN_CITY={wall='white',roof='green',accent='sage'},
 PEWTER_CITY={wall='mortar',roof='slate',accent='stone'},
 CERULEAN_CITY={wall='white',roof='blue',accent='navy'},
 LAVENDER_TOWN={wall='mortar',roof='dark',accent='slate'},
 VERMILION_CITY={wall='cream',roof='terra',accent='blue'},
 CELADON_CITY={wall='white',roof='green',accent='gold'},
 FUCHSIA_CITY={wall='cream',roof='slate',accent='wood'},
 SAFFRON_CITY={wall='white',roof='slate',accent='gold'},
 CINNABAR_ISLAND={wall='white',roof='terra',accent='red'},
 INDIGO_PLATEAU={wall='mortar',roof='navy',accent='gold'},
}
M.gyms={PEWTER_CITY='rock',CERULEAN_CITY='water',VERMILION_CITY='electric',CELADON_CITY='grass',FUCHSIA_CITY='poison',SAFFRON_CITY='psychic',CINNABAR_ISLAND='fire',VIRIDIAN_CITY='ground'}
function M.classify(map,dest,id)
 dest=tostring(dest or ''):upper();id=tostring(id or ''):lower()
 -- Reused native templates describe shapes, not identities. Real destinations win.
 if dest~='' and not id:find('museum_wing',1,true) then id='' end
 if id:find('tower_top',1,true) then return 'tower_claim' end
 if dest:find('POKEMON_TOWER') or id:find('pokemon_tower',1,true) then return 'tower' end
 if dest:find('SILPH') or id:find('silph',1,true) then return 'office_tower' end
 if dest=='CELADON_MART_1F' or id:find('department',1,true) or id=='celadon_mart' then return 'department_store' end
 if dest=='CELADON_MART_5F' then return 'store_annex' end
 if dest:find('POKECENTER') or dest=='INDIGO_PLATEAU_LOBBY' or id=='pokecenter' then return dest=='INDIGO_PLATEAU_LOBBY' and 'league' or 'center' end
 if dest:find('MART') or id=='pokemart' then return 'mart' end
 if dest:find('GYM') or id:find('gym',1,true) then return 'gym' end
 if dest:find('MUSEUM') or id:find('museum',1,true) then return id:find('wing',1,true) and 'museum_wing' or 'museum' end
 if dest=='OAKS_LAB' or id:find('oaks_lab',1,true) then return 'oak_lab' end
 if dest=='CINNABAR_LAB' then return 'research_lab' end
 if dest:find('POWER_PLANT') or id=='power_plant' then return 'power_station' end
 if dest:find('POKEMON_MANSION') then return 'ruined_mansion' end
 if dest:find('CELADON_MANSION') or id=='celadon_mansion' then return 'mansion' end
 if dest=='GAME_CORNER' or id=='game_corner' then return 'arcade' end
 if dest=='GAME_CORNER_PRIZE_ROOM' then return 'prize_shop' end
 if dest=='FIGHTING_DOJO' then return 'dojo' end
 if dest=='BIKE_SHOP' then return 'bike_shop' end
 if dest:find('HOTEL') then return 'hotel' end
 if dest:find('DINER') then return 'diner' end
 if dest=='DAYCARE' or id=='daycare' then return 'daycare' end
 if dest=='BILLS_HOUSE' then return 'bill_house' end
 if dest:find('FAN_CLUB') then return 'club' end
 if dest:find('SCHOOL') then return 'school' end
 if dest:find('MEETING_ROOM') then return 'meeting_hall' end
 if dest:find('UNDERGROUND_PATH') then return 'underground_gate' end
 if dest:find('GATE') or id:find('gate',1,true) then return dest=='SAFARI_ZONE_GATE' and 'safari_gate' or 'gate' end
 if dest:find('SAFARI_ZONE') or id=='safari_rest_house' then return 'rest_house' end
 if dest=='REDS_HOUSE_1F' then return 'player_house' end
 if dest=='BLUES_HOUSE' then return 'rival_house' end
 if dest=='' and (map=='SAFFRON_CITY' or map=='CELADON_CITY') then return 'apartments' end
 if dest~='' then return 'house' end
 return 'scenery_house'
end
function M.region(map)return M.regions[map] or {wall='cream',roof='slate',accent='wood'}end
return M
