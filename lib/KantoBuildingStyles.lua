-- Architectural families, explicit resident identities and stable scenery variants.
-- All selection is local to a building. No global random state or settings writes.
local M={REVISION='legendary-kanto-architecture-16'}
M.maps={PALLET_TOWN=true,VIRIDIAN_CITY=true,PEWTER_CITY=true,CERULEAN_CITY=true,
 VERMILION_CITY=true,CELADON_CITY=true,FUCHSIA_CITY=true,SAFFRON_CITY=true,CINNABAR_ISLAND=true,
 ROUTE_2=true,ROUTE_4=true,ROUTE_5=true,ROUTE_10=true,ROUTE_12=true,ROUTE_16=true,ROUTE_25=true}
local families={
 PALLET_TOWN={name='village',wall='ktLime',trim='ktCedar',base='ktSandstone',roof='ktTerracotta',roofKind='gable',shape='round',shutters='sage',rise=20},
 VIRIDIAN_CITY={name='woodland',wall='ktSage',trim='ktCedar',base='ktSandstone',roof='green',roofKind='gable',shape='segment',shutters='wood',rise=22},
 PEWTER_CITY={name='quarry',wall='ktSandstone',trim='ktBasalt',base='ktBasalt',roof='lvSlate',roofKind='hip',shape='segment',shutters=false,rise=15},
 CERULEAN_CITY={name='waterfront',wall='ktPlaster',trim='ktMarine',base='ktPearl',roof='ktMarine',roofKind='hip',shape='round',shutters='white',rise=18},
 CELADON_CITY={name='garden',wall='ktSage',trim='ktLime',base='ktSandstone',roof='ktCopper',roofKind='mansard',shape='round',shutters=false,rise=14,floors=2},
 FUCHSIA_CITY={name='reserve',wall='ktLime',trim='ktCedar',base='ktBasalt',roof='lvSlate',roofKind='flared',shape='rect',shutters=false,rise=16},
 SAFFRON_CITY={name='metropolitan',wall='ktPlaster',trim='ktBronze',base='ktObsidian',roof='ktSteel',roofKind='flat',shape='rect',shutters=false,rise=5,floors=2},
 CINNABAR_ISLAND={name='volcanic',wall='ktPlaster',trim='ktBasalt',base='ktBasalt',roof='ktTerracotta',roofKind='hip',shape='segment',shutters='ktMarine',rise=14},
}
local route={ROUTE_2='VIRIDIAN_CITY',ROUTE_4='PEWTER_CITY',ROUTE_5='PALLET_TOWN',ROUTE_10='PEWTER_CITY',ROUTE_12='CERULEAN_CITY',ROUTE_16='CELADON_CITY',ROUTE_25='CERULEAN_CITY'}
local homes={house=true,scenery_house=true,player_house=true,rival_house=true,school=true,apartments=true,hotel=true,diner=true,daycare=true,bill_house=true,meeting_hall=true}
local names={REDS_HOUSE_1F='RED',BLUES_HOUSE='BLUE',VIRIDIAN_SCHOOL_HOUSE='SCHOOL',WARDENS_HOUSE='WARDEN',COPYCATS_HOUSE_1F='COPYCAT',MR_PSYCHICS_HOUSE='PSYCHIC',DAYCARE='DAY CARE',BILLS_HOUSE='BILL',CELADON_HOTEL='HOTEL',CELADON_DINER='DINER'}
local function hash(s)local n=0;for i=1,#s do n=(n*31+s:byte(i))%65521 end;return n end
function M.resolve(s)
 local f=families[s.map]or families[route[s.map]]
 if not f or not(homes[s.kind]or s.kind=='center'or s.kind=='mart'or s.kind=='oak_lab'or s.kind=='research_lab')then return nil end
 local c={};for k,v in pairs(f)do c[k]=v end
 local dest=s.destination or '';local variant=dest~=''and hash(dest)%4 or (math.floor((s.x0-1)/64)+math.floor((s.z0-1)/32)*3)%4
 c.variant=variant;c.floors=c.floors or 1;c.label=names[dest];c.kind=s.kind
 c.height=c.floors==2 and 53 or 34;c.windowWidth=c.name=='reserve'and 15 or 12
 if variant==1 and c.name~='quarry'and c.name~='reserve'then c.wall=c.name=='woodland'and 'ktLime'or c.name=='metropolitan'and 'ktSandstone'or 'ktPlaster' end
 if c.name=='village'and (variant==1 or dest=='BLUES_HOUSE')then c.roofKind='hip';c.roof=dest=='BLUES_HOUSE'and 'ktMarine'or 'ktTerracotta' end
 if c.name=='quarry'and variant%2==1 then c.roofKind='gable';c.rise=17 end
 if c.name=='waterfront'and variant%2==1 then c.roofKind='mansard';c.rise=16 end
 if c.name=='garden'and variant==2 then c.roofKind='hip';c.wall='ktLime' end
 if c.name=='garden'and variant==3 then c.roofKind='gable';c.rise=19;c.wall='ktSage' end
 if c.name=='metropolitan'then c.windowWidth=({11,9,13,10})[variant+1]end
 if dest=='REDS_HOUSE_1F'then c.roofKind='gable';c.wall='ktLime';c.shutters='red' end
 if dest=='BLUES_HOUSE'then c.wall='ktPlaster';c.shutters='ktMarine' end
 if dest=='VIRIDIAN_SCHOOL_HOUSE'then c.label='SCHOOL';c.cupola=true;c.roofKind='hip' end
 if dest=='WARDENS_HOUSE'then c.roof='ktCopper';c.wall='ktOchre';c.label='WARDEN' end
 if dest=='FUCHSIA_GOOD_ROD_HOUSE'then c.shutters='ktCedar';c.wall='ktPlaster';c.fishing=true end
 if dest=='FUCHSIA_BILLS_GRANDPAS_HOUSE'then c.wall='ktSage';c.rise=20 end
 if dest=='PEWTER_NIDORAN_HOUSE'then c.wall='ktSandstone';c.roofKind='gable' end
 if dest=='PEWTER_SPEECH_HOUSE'then c.wall='ktLime';c.roofKind='hip';c.rise=13 end
 if dest=='CERULEAN_BADGE_HOUSE'then c.badge=true;c.wall='ktPlaster' end
 if dest=='CERULEAN_TRASHED_HOUSE'then c.wall='ktPearl';c.shutters='ktMarine';c.roofKind='gable' end
 if dest=='CERULEAN_TRADE_HOUSE'then c.roof='ktCopper';c.wall='ktPlaster';c.roofKind='hip' end
 if dest=='COPYCATS_HOUSE_1F'then c.roofKind='mansard';c.roof='ktMarine';c.wall='ktPlaster' end
 if dest=='MR_PSYCHICS_HOUSE'then c.wall='ktSandstone';c.trim='ktBronze';c.oculus=true end
 if s.kind=='apartments'then c.label=nil;c.height=variant%2==0 and 53 or 57 end
 if s.kind=='hotel'then c.height=57;c.roofKind='mansard';c.wall='ktLime';c.trim='ktBronze' end
 if s.kind=='diner'then c.height=34;c.floors=1;c.roofKind='mansard';c.shutters=false;c.windowWidth=17;c.shop=true end
 if s.kind=='daycare'then c.label='DAY CARE';c.roofKind='hip';c.wall='ktLime';c.shutters='green';c.cupola=true end
 if s.kind=='bill_house'then c.label='BILL';c.roofKind='monitor';c.roof='ktMarine';c.lab=true;c.shutters=false end
 if s.kind=='meeting_hall'then c.label='HALL';c.roofKind='flared';c.height=38 end
 if s.kind=='center'or s.kind=='mart'then
  c.floors=1;c.height=34;c.label=s.kind=='center'and 'CENTER'or 'MART';c.shutters=false;c.clinic=s.kind=='center';c.shop=s.kind=='mart'
  c.roofKind=c.name=='reserve'and 'flared'or c.name=='metropolitan'and 'flat'or 'hip'
  c.wall=c.clinic and 'ktPlaster'or c.wall;c.rise=13;c.windowWidth=c.shop and 18 or 13
 end
 if s.kind=='oak_lab'or s.kind=='research_lab'then
  c.floors=1;c.height=37;c.roofKind='monitor';c.roof=s.kind=='oak_lab'and 'ktCopper'or 'ktSteel';c.label=s.kind=='oak_lab'and 'OAK LAB'or 'LAB';c.lab=true;c.windowWidth=19;c.shutters=false;c.rise=12
 end
 return c
end
M.families=families
return M
