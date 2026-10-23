-- TEST235: EASTER EGGS (ParadeEggs). The parade owns one Eggs: a stop's gags
-- are made as it is entered and load under its card (Celadon: a fan throws
-- a Magikarp at you in the 'alongside' shot; Jigglypuff sings Joseph's own
-- song from a rope post at the plaza and sends the crowd to sleep). While a
-- gag runs it may take the camera (its beats), hold the finale (the walk is
-- done, the finale waits for it) or a stop's end, and turn down the crowd's
-- cheer (its loop, the ticker tape, the cheering one-shots) and the march (a
-- music.volume multiplier); the finale's cannons wake everyone and bring it
-- all back exactly. People are tipped through ParadeCast's poses (a walking
-- partner's Stadium model through a WaterFooting.roaming wrap). Any failure
-- of the eggs lets them go; the parade runs on as before.
-- TEST231: TEST230's second building slice is gone (with the frame rate
-- held at 60 by vsync, "the frame has room" could not be told, and the
-- extra slice would have cost dropped frames behind the ceremony and in
-- the parade); the early start is kept. A parade that ends while you are
-- still in the Hall of Fame no longer starts the road building again.
-- TEST230: THE RIDE AND THE WAIT.
--   * RIDE: you and your partner on the float, side by side; the Pokemon
--     walking at your heels steps out of the picture while it runs (it is
--     up there with you) -- ParadeFloat.
--   * The first white card held about twenty seconds in Joseph's recordings
--     (TEST227 to 229). Celadon City now starts building as soon as the
--     Champion is beaten (Oak's speech, the walk to the Hall of Fame and
--     the room before the ceremony), not only once the ceremony starts. And
--     the card says how far along the place is and what it is waiting for,
--     with a bar that fills ("PREPARING CELADON CITY", "DECORATING THE
--     STREET", "YOUR FLOAT IS ON ITS WAY", "THE CROWD IS GATHERING"), the
--     same words as the log line.
-- REAL NPC CROWD EDIT: 48 ordinary engine actors, Collection identities,
-- no procedural block crowd, and a shorter one-second introduction hold.
-- Earlier TEST226 notes below describe the original build, superseded here.
--
-- TEST228: THE WAIT ON THE WHITE. The first title card held for about twenty
-- seconds in Joseph's recording, a still white page that looked frozen.
--   * Under the card the crowd is not drawn (nothing shows through the
--     white): each frame warms only a few of them -- one new kind of person
--     at a time, so each model loads behind the card without the whole crowd
--     being re-posed every frame -- which leaves the frame's time to the
--     build the card is waiting for. Everyone is drawn as normal from the
--     moment the picture comes up (ParadeCast).
--   * The card itself is alive while it waits: confetti drifts down the
--     white, the LIVE dot pulses, and a gold bar runs under the title.
--   * A partner from a follower mod (Followers EX, PokePC, Wilds -- not just
--     Yellow's Pikachu) is yours, not one of the crowd: the townsfolk rules
--     (stop, turn, jump about, off the road) leave it alone, and it is left
--     off the float instead of riding as well as walking (ParadeFloat).
-- TEST222: THE CHAMPION'S PARADE, LIVE. After the Hall of Fame, the new
-- Champion's parade plays on the real maps, in 3D, with YOUR trainer and
-- YOUR follower, while the camera films it like a parade.
--
-- TEST224: the white cards between places asked the voxel cache itself
-- whether the next place was ready (another mod reloads VoxelScene after
-- this one wraps it), and the next place is built AHEAD, through
-- ChunkMesher's own cooperative queue, kept out of the live-set eviction.
--
-- TEST264: the parade always rides the Champion's float, with three of your
-- team aboard, at a float's pace, on a road clear of ledges and walls.
--
-- TEST226: ONE BIG PARADE, FILMED LIKE A BROADCAST. Solo Dolo's notes on
-- TEST225: after the second change of place it felt repetitive; better one
-- more detailed parade in a big city like Celadon; the confetti should be
-- more dynamic (it came out of the people in jets); and the camera should
-- cut between angles -- from the crowd -- instead of one overworld view all
-- the way. So:
--
--   * THE CHAMPION'S PARADE, LIVE FROM CELADON CITY: one title card, then the
--     whole parade on Celadon's main street, from the Route 7 gate to the
--     plaza at the Department Store (ParadeStreet dresses it: a crowd two
--     deep behind velvet ropes, rainbow pennants, balloons, banners)
--   * the camera works like a television crew: a helicopter shot to open; a
--     camera truck rolling ahead of you; a camera at the rope among the
--     crowd; one alongside you over their heads; the long lens from down
--     the street; the rooftops; over the shoulders of the people on the
--     other pavement; the turn into the plaza; and the finale's crane up
--     over it all with fireworks, the plaza's cannons and its balloons let
--     go. Each cut comes as you reach a point on the road, walking or riding
--   * a LIVE bug in the corner and captions low on the screen, as a
--     broadcast has them (the parade's name, then yours)
--   * the confetti is ParadeConfetti: ticker tape from the buildings, the
--     float's own cannons, the plaza's; it tumbles, flutters and lands
--   * then one short shot at sunset as you arrive home in Pallet Town, where
--     your Mom, Professor Oak and your rival are waiting (no title card:
--     the white comes and goes), and the credits
--   * the light: late afternoon in Celadon, going gold; sunset at home
--   * if the frame rate drops while it plays, the parade goes LITE: half the
--     extra crowd and half the ticker tape (logged)
--   * HOLD A (or START) for a second to skip, as before
--
-- How it runs: the engine's HallOfFame screen is handed a "when done" (the
-- credits); this wraps that and replaces it. The Hall of Fame's script is
-- still paused at that moment, which keeps the player's controls locked; the
-- parade moves the player with the overworld's own scripted steps
-- (ow:scriptMove) and changes map with ow:setMap. The cheering people are
-- runtime map objects (mod.world:spawnNpc), removed again before the
-- credits; the town's own people who stand in the road are moved to the
-- pavement for the parade and put back after. The camera is placed through
-- FirstPerson.frame, the hour through DayNight.time, the effects in the late
-- world pass (DockLights.drawLate), the captions in the HUD pass.
-- If 3D is off, nothing changes: straight on to the credits.
-- Installed from LeagueFireworksAudio.install (main.lua is not touched).
local V=...
local M={REVISION='champion-parade-261'}
local floor,max,min,abs,sin,cos,sqrt,pi,rad=math.floor,math.max,math.min,math.abs,math.sin,math.cos,math.sqrt,math.pi,math.rad
local atan2=math.atan2 or math.atan

-- seconds
M.T={card=.75,firstCard=1.0,reveal=.5,establish=3.2,codaEstablish=.15,white=.55,
 finalWhite=1.6,hudOut=.7,skipHold=1.0,settle=.3,pathWait=3.0,loadLimit=24.0}
M.STEP_SCALE=2.3       -- walking down the main street: 16 frames a step become 37
M.FLOAT_STEP=3.2       -- and the float: 16 become 51
M.ASSETS='assets/parade/'
M.TITLE_FRAMES=2       -- the title is drawn this many frames before the place loads
-- TEST242: INSIDE THE CITY ONLY. While the parade is at one of these places,
-- the connected maps round it (Celadon: Route 7, Route 16, Saffron City,
-- Route 17) are neither built ahead, kept, cast nor drawn -- except the ones
-- listed for it: Celadon keeps ROUTE_7, the only one any parade camera sees
-- (the gatehouse at the far end of the main street, in the opening truck and
-- rope shots; without it 2-6% of those pictures look through the gap in the
-- town's border trees onto the bare world-fill floor). `true` instead of a
-- list keeps none. (M.INSIDE_ONLY=false: as before.)
M.INSIDE_ONLY={CELADON_CITY={ROUTE_7=true}}
-- (is this connected map left out at this parade place?)
function M.insideDrops(placeId,nbId)
 local rule=M.INSIDE_ONLY and M.INSIDE_ONLY[tostring(placeId)]
 if not rule then return false end
 if type(rule)=='table'and nbId~=nil and rule[tostring(nbId)]then return false end
 return true
end
-- TEST242: put back the camera culling a pre-TEST81 Collection switches off
-- (lib/ParadeCull.lua), while the parade runs. (false: as before.)
M.RESTORE_CULL=true
-- TEST244: free the last stop's eggs and collect garbage before the next
-- stop's map loads (false: as before)
M.FREE_BETWEEN_STOPS=true
M.LITE_FRAME=1/28      -- a smoothed frame time over this ...
M.LITE_AFTER=1.5       -- ... for this long (seconds of it) sends the parade LITE
M.LITE2_FRAME=1/20     -- and if it is still this slow, LITE 2 (the crowd near you only)
M.LITE_WAIT=5.0        -- a change of LITE waits for the next cut, this long at most
M.TICKER_RATE=90       -- ticker tape a second round the float (LITE: half)
M.TICKER_WALK=70       -- (round you, walking)
M.DRIFT_RATE=10        -- and a little all along the street
M.WARM_PER_FRAME=6     -- TEST228: people warmed a frame under the card
M.frameSerial=0        -- TEST228: counts frames (ParadeCast's warm budget)
M.CARD_WORLD_EVERY=4   -- TEST228: under the card, the world drawn 1 frame in 4
M.SHOT_PROFILE=true   -- one diagnostic log line per completed camera shot
-- TEST251 diagnostic build: recordable on Android without finding engine logs.
-- File writes happen only at shot boundaries, start and finish, never per frame.
M.PROFILE_FILE='battleart-parade-profile.log'
M.PROFILE_SCREEN=false -- debug override; the optional menu setting is OFF too
M.PROFILE_LINES=160
M.PROFILE_BUILD='TEST264'
-- One quality change for this measurement: omit far parade-crowd shadows in
-- Celadon. False restores TEST251's caster selection for a follow-up comparison.
M.CROWD_SHADOW_DISTANCE=true
local function profileScreen()
 if M.PROFILE_SCREEN then return true end
 local ok,on=pcall(function()return V.require('ParadeDiagnostics').enabled()end)
 return ok and on==true
end

------------------------------------------------------------------ Celadon
-- Celadon City, the map's own walk grid (a cell is 16 world pixels; x east,
-- z south). The main street runs east to west on rows 10 to 13 between the
-- shops and the Mansion on the north side and the Game Corner's block on the
-- south, and opens at its west end into the plaza in front of the
-- Department Store, with the park beyond. The float keeps to row 12, the
-- middle of the street, then turns south into the plaza.
local CELADON_SET={
 seed=226,
 -- Real engine actors supply the entire crowd. No procedural block people.
 strips={},areas={},
 avoid={
  {392,168,9},   -- the Mansion's door
  {664,168,9},   -- the Pokemon Center's
  {556,226,9},   -- where the camera stands at the rope
  {180,260,12},  -- and at the back of the plaza's crowd
  {230,214,6},{300,262,6},   -- the plaza's cannons
 },
 avoidBoxes={
  {236,300,196,246},   -- the float's turn into the plaza
  {264,300,196,284},   -- and where it stops
 },
 ropes={{x0=228,x1=792,z=181,step=19},{x0=420,x1=736,z=219,step=19}},
 poles={
  {256,182.6,56},{320,182.6,56},{384,182.6,56},{448,182.6,56},{512,182.6,56},{576,182.6,56},
  {640,182.6,56},{704,182.6,56},{768,182.6,56},
  {448,217.4,56},{512,217.4,56},{576,217.4,56},{640,217.4,56},{704,217.4,56},
  -- the banners' own
  {616,182.6,58},{616,217.4,58},{372,182.6,58},{372,217.4,58},
 },
 strings={},     -- (filled below: along both kerbs and across the street)
 balloons={{244,181},{340,181},{436,181},{532,181},{628,181},{724,181},
  {436,219},{532,219},{628,219},{724,219}},
 cannons={{x=230,z=214,yaw=1.05,pitch=.95},{x=300,z=262,yaw=-2.49,pitch=.95}},
 banners={
  -- (high: the float's rider and the tallest Pokemon on it pass under)
  {x=616,y=44,z=200,w=34.8,h=12,yaw=pi/2,text='CONGRATULATIONS, CHAMPION!'},
  {x=372,y=44,z=200,w=34.8,h=12,yaw=pi/2,text='HAIL TO THE CHAMPION!',key='name'},
  -- long banners on the Department Store's east face, over the plaza
  {x=225.1,y=18,z=150,w=12,h=46,yaw=pi/2,vertical=true,flat=true,text='CHAMPION',bg={.62,.07,.10}},
  {x=225.1,y=18,z=196,w=12,h=46,yaw=pi/2,vertical=true,flat=true,text='CELADON',bg={.12,.36,.20}},
 },
 release={182,252,214,262},
}
do
 local S=CELADON_SET.strings
 local north={256,320,384,448,512,576,640,704,768}
 for i=1,#north-1 do S[#S+1]={a={north[i],51,182.6},b={north[i+1],51,182.6},sag=4}end
 local south={448,512,576,640,704}
 for i=1,#south-1 do S[#S+1]={a={south[i],51,217.4},b={south[i+1],51,217.4},sag=4}end
 -- (across the street: at their lowest, still well over the float)
 for _,x in ipairs(south)do S[#S+1]={a={x,53,182.6},b={x,53,217.4},sag=5}end
 -- (over the west end the far side is the building on the south side)
 S[#S+1]={a={384,53,182.6},b={384,51,223.6},sag=5}
end
M.CELADON_SET=CELADON_SET
-- where ticker tape is thrown from: the street's frontages ({x0,x1,z,y0,y1,
-- out}: out is the way the street lies from the wall), and the Department
-- Store's east face (a frontage running north to south)
local CELADON_TICKER={
 {x0=224,x1=320,z=160,y0=26,y1=50,out=1},
 {x0=352,x1=448,z=160,y0=26,y1=52,out=1},
 {x0=448,x1=640,z=160,y0=26,y1=50,out=1},
 {x0=640,x1=704,z=160,y0=20,y1=32,out=1},
 {x0=320,x1=416,z=224,y0=26,y1=50,out=-1},
 {x0=416,x1=736,z=243,y0=30,y1=46,out=-1},
 {axis='z',z0=100,z1=222,x=224,y0=32,y1=74,out=1},
}
M.CELADON_TICKER=CELADON_TICKER
-- The camera crew. Each shot starts when you reach `at` cells along the
-- road (-1: the opening, before you move). fixed: the camera stands at `eye`
-- (world) and follows you with `aim` (an offset from you); follow: it moves
-- with you, at `eye` from you. fov in degrees, or `frame`: the long lens
-- keeps that many world pixels in the picture, top to bottom. `walk`: the
-- changes when you walk (you are smaller than the float). cannons: the
-- float's cannons fire as the shot starts. swell: the crowd roars.
local CELADON_SHOTS={
 {at=-1,kind='fixed',eye={846,140,268},drift={-6,-2,-1.5},aim={-120,0,-4},fov=46,name='aerial'},
 {at=0,kind='follow',eye={-150,36,0},aim={0,14,0},fov=34,cannons=true,name='truck',
  walk={eye={-96,28,0},aim={0,11,0},fov=30}},
 {at=5,kind='fixed',eye={556,21,225},aim={0,12,0},fov=50,shake=.45,swellAt=9.4,name='rope',
  walk={fov=36,aim={0,9,0}}},
 {at=10.5,kind='follow',eye={-34,35,40},aim={-6,14,0},fov=46,name='alongside',
  walk={eye={-24,37,36},aim={-4,10,0},fov=44}},
 {at=15,kind='fixed',eye={300,30,196},aim={0,17,2},frame=54,cannons=true,name='long lens',
  walk={frame=36,aim={0,11,2}}},
 {at=19,kind='fixed',eye={452,118,138},aim={0,6,8},fov=44,name='rooftop',walk={fov=30}},
 {at=23,kind='fixed',eye={180,31,260},aim={0,12,0},fov=40,shake=.35,name='crowd',
  walk={fov=30,aim={0,9,0}}},
 {at=26.6,kind='fixed',eye={212,62,302},aim={0,10,10},fov=46,cannons=true,swell=true,name='plaza',
  walk={fov=34,aim={0,9,6}}},
}
M.CELADON_SHOTS=CELADON_SHOTS

------------------------------------------------------------------ the stops
-- Crowd: the people the parade brings {sprite, x, y, facing}. clear: the
-- cells the road needs ({x0,x1,y0,y1}); anyone of the town's own standing
-- there is moved to the first free `parking` cell for the parade.
M.STOPS={
 {map='CELADON_CITY',key='celadon',title='Celadon City',label='LIVE FROM',show=true,tod={515,572},
  start={44,12},facing='left',path={{'left',27},{'down',3}},
  crowd={}, -- populated below with ordinary NPCs and render-only trainer identities
  clear={{14,46,11,13},{15,19,13,16}},
  parking={{32,10},{31,10},{28,10},{36,10},{39,10},{42,10},{31,14},{36,14},{40,14},{12,16},{11,15}},
  set=CELADON_SET,ticker=CELADON_TICKER,shots=CELADON_SHOTS,
  finale={dur=6.6,
   crane={from={eye={236,30,296},aim={0,14,0},fov=48},to={eye={190,136,356},focus={430,58,150},fov=54}},
   walkCrane={from={eye={246,24,292},aim={0,11,0},fov=44},to={eye={196,124,352},focus={430,58,150},fov=54}},
   salvo={at={430,186,100},n=8,spacing=.55,scale=1.05},
   drop={200,330,176,286,70,112,420}},
  lowers={{from='reveal',at=.8,dur=4.6,big="THE CHAMPION'S PARADE",small='LIVE FROM CELADON CITY'},
   {from='progress',at=11,dur=4.2,big='$NAME',small='THE NEW CHAMPION OF KANTO'}},
  place='CELADON CITY',
  crowdVol=1.0,
  float={path={{'left',27},{'down',2}}}},
 {map='PALLET_TOWN',key='pallet',title='Pallet Town',label='HOME AT LAST',home=true,coda=true,tod={588,640},
  start={8,8},facing='down',path={{'down',4}},
  banner={text='WELCOME HOME, CHAMPION!',x0=5,x1=16,y=2,bottom=36,h=22,
   bg={.10,.24,.55},fg={1,.90,.55}},
  crowd={{'SPRITE_MOM',5,12,'RIGHT'},{'SPRITE_OAK',10,12,'LEFT'},
   {'SPRITE_BLUE',11,12,'LEFT'},
   {'SPRITE_LITTLE_GIRL',12,6,'LEFT'},{'SPRITE_YOUNGSTER',6,7,'RIGHT'},
   {'SPRITE_GIRL',12,7,'LEFT'},{'SPRITE_COOLTRAINER_F',13,7,'LEFT'},
   {'SPRITE_LITTLE_BOY',4,11,'RIGHT'},
   {'SPRITE_YOUNGSTER',4,8,'RIGHT'}},
  -- the one shot: from over your Mom's shoulder as you come home, rising
  -- into the sunset as the fireworks go up (relative to where you stop)
  coda={from={eye={28,30,56},focus={-6,16,-8},fov=48},to={eye={60,120,190},focus={0,64,-130},fov=56},dur=9.4},
  finale={dur=6.2,salvo={rel={-30,170,-60},n=9,spacing=.6,scale=1.1},drop={-40,40,-40,30,60,96,260}},
  lowers={{from='reveal',at=.7,dur=3.6,big='PALLET TOWN',small='HOME AT LAST'}},
  place='PALLET TOWN',
  rain=24,crowdVol=.8,
  -- the float comes in through the grass gate and stops in the square
  -- between the two houses; your Mom, Professor Oak and your rival wait
  -- either side of its prow
  float={start={10,1},path={{'down',3}},
   crowd={{'SPRITE_MOM',8,6,'RIGHT'},{'SPRITE_OAK',12,6,'LEFT'},{'SPRITE_BLUE',13,6,'LEFT'},
    {'SPRITE_LITTLE_GIRL',14,7,'LEFT'},{'SPRITE_YOUNGSTER',6,7,'RIGHT'},
    {'SPRITE_GIRL',12,7,'LEFT'},{'SPRITE_COOLTRAINER_F',16,6,'LEFT'},
    {'SPRITE_LITTLE_BOY',4,7,'RIGHT'},{'SPRITE_YOUNGSTER',3,6,'RIGHT'}},
   coda={from={eye={-68,50,68},focus={0,16,8},fov=48},to={eye={-112,118,168},focus={8,60,-120},fov=56},dur=9.4}}},
}
-- A single cell-spaced row on each kerb, with a small plaza group. Named
-- trainers share their Collection assets; no new copies of meshes/textures.
-- Identity is ONLY supplied inside a render callback, never on a live
-- gameplay trainer definition (no sight checks, parties or battle scripts).
local PARADE_ROSTER={
 {'SPRITE_GUARD',{sprite='SPRITE_OFFICER_JENNY',name='Officer Jenny'}},
 {'SPRITE_NURSE',{name='Nurse Joy'}},
 {'SPRITE_YOUNGSTER',{trainerClass='OPP_BUG_CATCHER',name='Bug Catcher'}},
 {'SPRITE_COOLTRAINER_F',{trainerClass='OPP_LASS',name='Lass'}},
 {'SPRITE_YOUNGSTER',{trainerClass='OPP_YOUNGSTER',name='Youngster'}},
 {'SPRITE_HIKER',{trainerClass='OPP_HIKER',name='Hiker'}},
 {'SPRITE_FISHER',{trainerClass='OPP_FISHER',name='Fisherman'}},
 {'SPRITE_SAILOR',{trainerClass='OPP_SAILOR',name='Sailor'}},
 {'SPRITE_SUPER_NERD',{trainerClass='OPP_SUPER_NERD',name='Super Nerd'}},
 {'SPRITE_GENTLEMAN',{trainerClass='OPP_GENTLEMAN',name='Gentleman'}},
 {'SPRITE_BEAUTY',{trainerClass='OPP_BEAUTY',name='Beauty'}},
 {'SPRITE_COOLTRAINER_M',{trainerClass='OPP_COOLTRAINER_M',name='Ace Trainer M'}},
 {'SPRITE_COOLTRAINER_F',{trainerClass='OPP_COOLTRAINER_F',name='Ace Trainer F'}},
 {'SPRITE_COOLTRAINER_M',{trainerClass='OPP_JR_TRAINER_M',name='Camper'}},
 {'SPRITE_LITTLE_BOY',{name='Little Boy'}},
 {'SPRITE_LITTLE_GIRL',{name='Little Girl'}},
 {'SPRITE_CLERK',{name='Mart Clerk'}},
 {'SPRITE_GRANNY',{name='Townswoman'}},
}
M.PARADE_ROSTER=PARADE_ROSTER
do
 local crowd=M.STOPS[1].crowd
 local function add(n,x,y,face)
  local entry=PARADE_ROSTER[n]
  crowd[#crowd+1]={entry[1],x,y,face,entry[2]}
 end
 -- Jenny and Joy stand in the opening stretch; Bug Catchers appear on both
 -- sides of the road. Keep the doors (24,10 and 41,10), road, cameras and
 -- all original parking cells empty.
 local north={14,15,16,17,18,19,20,21,22,23,25,26,27,29,30,33,34,35,37,38,40,43,44,45,46,47,48,49}
 local cast={5,3,4,6,7,8,9,10,11,12,13,14,15,16,17,18,3,4,5,6,7,8,1,2,12,13,3,4}
 for i,x in ipairs(north)do add(cast[i],x,10,'DOWN')end
 local south={26,27,28,29,30,32,33,35,37,38,39,41,42,43,44,45}
 for i,x in ipairs(south)do add((i+1)%#PARADE_ROSTER+1,x,14,'UP')end
 add(1,13,14,'RIGHT');add(2,13,15,'RIGHT');add(3,14,16,'RIGHT');add(4,12,14,'RIGHT')
end

-- the stops as the float takes them: each stop with its `float` changes
-- laid over it (built once)
local floatStops=nil
function M.stopsFor(float)
 if not float then return M.STOPS end
 if floatStops then return floatStops end
 floatStops={}
 for i,stop in ipairs(M.STOPS)do
  local s={}
  for k,v in pairs(stop)do if k~='float'then s[k]=v end end
  for k,v in pairs(stop.float or{})do s[k]=v end
  s.isFloat=true
  floatStops[i]=s
 end
 return floatStops
end

local FW_COLS={{1,.32,.28},{1,.80,.30},{.38,.62,1},{.52,1,.44},{1,.44,.86},
 {.84,.54,1},{1,.96,.88},{.32,.95,1}}
local FW_GOLD={1,.78,.36}

local P=nil            -- the parade running now
local lastRig=nil
local modRef=nil

local function now()local ok,t=pcall(love.timer.getTime);return ok and t or 0 end
local function smooth(u)u=max(0,min(1,u));return u*u*(3-2*u)end
local function lerp(a,b,u)return a+(b-a)*u end
local function lerp3(a,b,u)return{lerp(a[1],b[1],u),lerp(a[2],b[2],u),lerp(a[3],b[3],u)}end
local function log(fmt,...)
 local args={...}
 pcall(function()local L=require('src.core.Logger');L.warn('[ChampionParade] '..fmt,unpack(args))end)
end

-- A small, bounded report independent of the engine logger. Android is NOT
-- filtered out here (CacheTrace's desktop-only cache log is not a substitute).
local function profileClean(s)
 return(tostring(s or'unknown'):gsub('[\r\n\t]',' ')):sub(1,1800)
end
local function profileCollection()
 local mod=modRef or V.mod
 if mod and type(mod.find)=='function'then
  local ok,h=pcall(mod.find,'STADIUM2_IMPORTER')
  if not(ok and type(h)=='table')then ok,h=pcall(mod.find,mod,'STADIUM2_IMPORTER')end
  if ok and type(h)=='table'then
   local c=h.exports and h.exports.collection
   return profileClean((c and c.version)or h.version or(h.manifest and h.manifest.version))
  end
 end
 return'unknown (check the mod list)'
end
local function profileReport(self)
 if self.profileReport then return self.profileReport end
 local r={lines={},collection=profileCollection(),started=now(),dirty=true,
  status='screen only',dropped=0}
 r.lines={
  '[ChampionParade] '..M.PROFILE_BUILD..' parade diagnostics; '..(self.float and'ride'or'walk'),
  '[ChampionParade] Collection: '..r.collection,
  '[ChampionParade] CPU wall time and world-frame cadence; no GPU timer. Screen readout enabled: '..tostring(profileScreen()),
  '[ChampionParade] Files saved at shot boundaries; Lite events buffered until a boundary. Latest run only.',
 }
 self.profileReport=r;M.lastProfileReport=r
 return r
end
function M.profileNote(self,line)
 if not self or not M.SHOT_PROFILE then return end
 local r=profileReport(self)
 r.lines[#r.lines+1]=profileClean(line);r.dirty=true
 while #r.lines>max(8,M.PROFILE_LINES or 160)do
  table.remove(r.lines,5);r.dropped=r.dropped+1
 end
end
function M.profileFlush(self)
 local r=self and self.profileReport
 if not r or not r.dirty or not M.PROFILE_FILE then return end
 local body=table.concat(r.lines,'\n')..'\n'
 if r.dropped>0 then body=body..('[ChampionParade] Older events omitted: %d\n'):format(r.dropped)end
 local fs=love and love.filesystem
 local mod=modRef or V.mod
 local storage=mod and mod.storage
 local err
 if fs and type(fs.write)=='function'then
  local ok,saved,why=pcall(fs.write,M.PROFILE_FILE,body)
  if ok and saved then
   r.status='file saved';r.location=M.PROFILE_FILE;r.dirty=false
   if type(fs.getSaveDirectory)=='function'then
    local good,path=pcall(fs.getSaveDirectory)
    if good and type(path)=='string'then r.location=path..'/'..M.PROFILE_FILE end
   end
   r.error=nil;return true
  end
  err=ok and why or saved
 end
 -- Sandboxed hosts may expose only the public playthrough storage API.
 if storage and type(storage.writeBytes)=='function'then
  local ok,saved,code,why=pcall(storage.writeBytes,storage,M.PROFILE_FILE,body)
  if ok and saved then
   r.status='mod storage saved';r.location=M.PROFILE_FILE;r.dirty=false;r.error=nil;return true
  end
  err=ok and(why or code)or saved
 end
 r.status='screen only';r.error=profileClean(err or'File access unavailable')
 return false
end
function M.profileStart(self)
 if not M.SHOT_PROFILE then return end
 self.profileReport=nil;self.shotProfiles={};self.profileHud=nil
 M.lastShotProfiles=self.shotProfiles
 profileReport(self)
 M.profileFlush(self)
end
function M.profileLite(self,level,fps)
 if not M.SHOT_PROFILE or not self then return end
 M.profileNote(self,('[ChampionParade] +%.3fs going LITE %d (smoothed %.1f fps)'):format(
  now()-profileReport(self).started,level,fps))
end

-- Measure the real device by camera shot. LoadTimings already measures CPU
-- work; read its cumulative counters only at shot boundaries. Cadence counts
-- rendered world frames, not core.update calls or screen-recording frames.
-- This is CPU-side wall time, not a GPU timer. No camera/effect is changed.
local profileKeys={'actor_prepare','actor_draw','shadow_actors','world_other','mesh_write','shadow_world','shadow_finish'}
local poseKeys={'refreshed','admitted','deferred','forced','extra','rebuilt','recovered','reflReplay','reflFull','calls','replays'}
local function profileCounters()
 local out={}
 local ok,T=pcall(V.require,'LoadTimings')
 if ok and type(T)=='table'and T.snapshot then
  local yes,s=pcall(T.snapshot)
  if yes and s and s.totals then
   out.timed=true
   for _,key in ipairs(profileKeys)do out[key]=tonumber(s.totals[key])or 0 end
  end
 end
 local good,C=pcall(V.require,'ParadeCull')
 if good and type(C)=='table'then
  local st=C.stats or{};local fs=C.fastStats or{}
  out.draws=st.calls or 0;out.boxes=fs.boxes or 0;out.inside=fs.inside or 0
  out.cullFast=C.FAST_CULL and not C.fastBroken and not C.broken and'on'or'off'
  out.cullRanges=C.forwards and'forwarded'or'compat/unobserved'
 end
 local okC,Cast=pcall(V.require,'ParadeCast')
 if okC and type(Cast)=='table'and type(Cast.shadowStats)=='table'then
  out.crowdShadowKept=Cast.shadowStats.kept or 0
  out.crowdShadowSkipped=Cast.shadowStats.skipped or 0
  out.crowdShadowCounted=true
 end
 -- Budget 2 totals are refresh decisions/provider calls, not GPU upload counts.
 if okC and type(Cast)=='table'and type(Cast.reposeTotals)=='table'then
  for _,k in ipairs(poseKeys)do out['pose_'..k]=tonumber(Cast.reposeTotals[k])or 0 end
  out.poseCounted=true
  local B=type(Cast.repose)=='table'and Cast.repose or nil
  out.poseBudget=B and tonumber(B.budget)or nil
  out.poseCostMs=B and tonumber(B.costMs)or nil
 end
 local okB,B=pcall(V.require,'ParadeCrowdCards')
 if okB and type(B)=='table'and type(B.stats)=='table'then
  out.crowdCards=B.stats.cards or 0;out.crowdBatches=B.stats.batches or 0
  out.crowdReflected=B.stats.reflected or 0
  out.cardFailures=B.stats.failures or 0;out.crowdCardsCounted=true
 end
 return out
end
function M.profileClose(self)
 local p=self and self.shotProfile
 if not p then return end
 self.shotProfile=nil
 if p.frames<2 then return end
 local elapsed=max(.001,now()-p.start)
 local c=profileCounters()
 local function delta(k)return max(0,(c[k]or 0)-(p.base[k]or 0))/p.frames end
 local row={map=p.map,shot=p.shot,mode=p.mode,frames=p.frames,seconds=elapsed,
  cadence=p.frames/elapsed,maxGapMs=max(p.maxGap,now()-p.last)*1000,
  actorsMs=delta('actor_prepare')+delta('actor_draw'),shadowActorsMs=delta('shadow_actors'),
  actorPrepareMs=delta('actor_prepare'),actorDrawMs=delta('actor_draw'),
  worldMs=delta('world_other'),meshWriteMs=delta('mesh_write'),
  crowdShadowKept=delta('crowdShadowKept'),crowdShadowSkipped=delta('crowdShadowSkipped'),
  crowdShadowCounted=c.crowdShadowCounted and p.base.crowdShadowCounted or false,
  crowdCards=delta('crowdCards'),crowdBatches=delta('crowdBatches'),
  crowdReflected=delta('crowdReflected'),
  cardFailures=c.cardFailures or 0,crowdCardsCounted=c.crowdCardsCounted or false,
  terrainCalls=delta('draws'),cullBoxes=delta('boxes'),insideGroups=delta('inside'),
  timed=c.timed and p.base.timed or false,liteStart=p.liteStart,liteEnd=tonumber(self.lite)or 0,
  liteFrames=p.liteFrames,cullFast=c.cullFast or'unknown',cullRanges=c.cullRanges or'unknown'}
 row.poseCounted=c.poseCounted and p.base.poseCounted or false
 if row.poseCounted then
  for _,k in ipairs(poseKeys)do row['pose_'..k]=delta('pose_'..k)end
  row.poseBudget,row.poseCostMs=c.poseBudget,c.poseCostMs
 end
 self.shotProfiles=self.shotProfiles or{};self.shotProfiles[#self.shotProfiles+1]=row
 -- Bound diagnostics even if a long-running addon changes shots repeatedly.
 if #self.shotProfiles>64 then table.remove(self.shotProfiles,1)end
 local line=('profile %s / %s / %s: %d frames, %.1f world fps, max gap %.1f ms; CPU actors %.2f ms, shadow actors %.2f ms, world %.2f ms, mesh writes %.2f ms (%s); terrain calls %.1f, cull boxes %.0f, inside groups %.0f per frame; LITE %d->%d, frames 0/1/2=%d/%d/%d; culling fast=%s ranges=%s'):format(
  row.map,row.shot,row.mode,row.frames,row.cadence,row.maxGapMs,row.actorsMs,row.shadowActorsMs,
  row.worldMs,row.meshWriteMs,row.timed and'timed'or'timings unavailable',row.terrainCalls,row.cullBoxes,row.insideGroups,
  row.liteStart,row.liteEnd,row.liteFrames[0],row.liteFrames[1],row.liteFrames[2],row.cullFast,row.cullRanges)
 line=line..('; actor prepare %.2f / draw %.2f ms; crowd shadow calls/frame kept %.1f / skipped %.1f (%s; distance filter %s)'):format(
  row.actorPrepareMs,row.actorDrawMs,row.crowdShadowKept,row.crowdShadowSkipped,
  row.crowdShadowCounted and'counted'or'unavailable',M.CROWD_SHADOW_DISTANCE and'Celadon only'or'off')
 if row.poseCounted then
  line=line..('; crowd poses/frame refreshed %.2f (picked %.2f, forced %.2f, extra %.2f), deferred %.2f, rebuilt %.3f, recovered %.3f; reflections replayed %.2f / drawn %.2f; Collection draws %.2f, replays %.2f; budget %s at %s ms a pose'):format(
   row.pose_refreshed,row.pose_admitted,row.pose_forced,row.pose_extra,row.pose_deferred,row.pose_rebuilt,row.pose_recovered,
   row.pose_reflReplay,row.pose_reflFull,row.pose_calls,row.pose_replays,tostring(row.poseBudget or'-'),
   row.poseCostMs and('%.2f'):format(row.poseCostMs)or'-')
 end
 line=line..('; distant crowd %.1f body cards + %.1f reflected in %.1f batch draws/frame; card fallback failures %d'):format(
  row.crowdCards,row.crowdReflected,row.crowdBatches,row.cardFailures)
 log('%s',line)
 M.profileNote(self,'[ChampionParade] '..line)
 M.profileFlush(self)
 self.profileHud=nil
 M.lastShotProfiles=self.shotProfiles
end
function M.profileFrame(self)
 if not self then return end
 if not M.SHOT_PROFILE or self.finished or(self.phase~='show'and self.phase~='finale'and self.phase~='reveal')then
  M.profileClose(self);return
 end
 local stop=self:stop()
 if not stop then M.profileClose(self);return end
 local name=(self.shot and self.shot.name)or self.phase
 local key=stop.map..'/'..self.phase..'/'..name
 local t=now();local p=self.shotProfile
 -- Start the next sample after boundary I/O, so writing the report is not
 -- charged to the next shot when its change is discovered here.
 if p and p.key~=key then M.profileClose(self);p=nil;t=now()end
 if not p then
  p={key=key,map=stop.map,shot=name,mode=self.float and'ride'or'walk',start=t,last=t,
   maxGap=0,frames=0,base=profileCounters(),liteStart=tonumber(self.lite)or 0,liteFrames={[0]=0,[1]=0,[2]=0}};self.shotProfile=p
 end
 local gap=t-p.last
 if gap>=0 then p.maxGap=max(p.maxGap,gap)end
 p.last=t;p.frames=p.frames+1
 local level=tonumber(self.lite)or 0
 p.liteFrames[level]=(p.liteFrames[level]or 0)+1
end

------------------------------------------------------------------ helpers
local function overworld(game)return game and game.overworld end
-- the overworld is still open: on the screen stack, with a map (a soft reset
-- pops every screen, and the overworld lets go of its map as it closes)
local function overworldUp(game)
 local ow=overworld(game)
 if not(ow and ow.map)then return false end
 local states=game.stack and game.stack.states
 if type(states)~='table'then return true end
 for i=#states,1,-1 do if states[i]==ow then return true end end
 return false
end
local function groundAt(map,cx,cy,px,py)
 local h=0
 pcall(function()h=V.require('VoxelScene').groundAt(map,cx,cy,px,py)or 0 end)
 return tonumber(h)or 0
end
-- the ground at a world point (x,z)
local function groundXZ(map,x,z)
 return groundAt(map,floor(x/16),floor(z/16),x-8,z-8)
end
local function cellWorld(map,cx,cy)
 return{cx*16+8,groundAt(map,cx,cy),cy*16+8}
end
local function sfxGain(game)
 local o=game and game.save and game.save.options
 return max(0,min(7,tonumber(o and o.sfxVol)or 7))/7
end
-- the time of day of a stop at local time u (0..1 through the stop)
local function todOf(stop,u)
 local t=stop.tod
 if type(t)=='table'then return lerp(t[1],t[2],max(0,min(1,u or 0)))end
 return t
end
-- how bright confetti looks at that hour (it is drawn unlit)
local function lightAt(tod)
 tod=tod%1200
 if tod>=675 and tod<=1125 then return .42 end
 if tod>1125 then return lerp(.42,.75,(tod-1125)/75)end
 if tod<75 then return lerp(.75,1,tod/75)end
 if tod<525 then return 1 end
 if tod<600 then return lerp(1,.82,(tod-525)/75)end
 return lerp(.82,.42,(tod-600)/75)
end
M.lightAt=lightAt
local DIRS={down={0,1},up={0,-1},left={-1,0},right={1,0}}
-- the cells a stop's road passes through, the start included
local function pathCells(stop)
 local x,y=stop.start[1],stop.start[2]
 local out={{x,y}}
 for _,m in ipairs(stop.path or{})do
  if m[1]=='hop'then
   for _=1,2 do y=y+1;out[#out+1]={x,y}end
  else
   local d=DIRS[m[1]]
   if d then for _=1,(m[2]or 1)do x,y=x+d[1],y+d[2];out[#out+1]={x,y}end end
  end
 end
 return out
end
M.pathCells=pathCells
-- the road as a line through the cells' middles, world pixels (x,z), with
-- the length up to each corner
local function roadLine(stop)
 local cells=pathCells(stop)
 local pts={{cells[1][1]*16+8,cells[1][2]*16+8}}
 local function dirOf(a,b)return b[1]-a[1],b[2]-a[2]end
 for i=2,#cells-1 do
  local ax,ay=dirOf(cells[i-1],cells[i])
  local bx,by=dirOf(cells[i],cells[i+1])
  if ax~=bx or ay~=by then pts[#pts+1]={cells[i][1]*16+8,cells[i][2]*16+8}end
 end
 local last=cells[#cells]
 if #cells>1 then pts[#pts+1]={last[1]*16+8,last[2]*16+8}end
 local L={0}
 for i=2,#pts do L[i]=L[i-1]+abs(pts[i][1]-pts[i-1][1])+abs(pts[i][2]-pts[i-1][2])end
 return pts,L
end
M.roadLine=roadLine
-- how far along the road (in cells) the point (x,z) is
local function progressOn(pts,L,x,z)
 if #pts<2 then return 0 end
 local best,bd=0,1e18
 for i=2,#pts do
  local a,b=pts[i-1],pts[i]
  local dx,dz=b[1]-a[1],b[2]-a[2]
  local len2=dx*dx+dz*dz
  local u=len2>0 and max(0,min(1,((x-a[1])*dx+(z-a[2])*dz)/len2))or 0
  local px,pz=a[1]+dx*u,a[2]+dz*u
  local d=(x-px)^2+(z-pz)^2
  if d<bd then bd=d;best=L[i-1]+u*(L[i]-L[i-1])end
 end
 return best/16
end
M.progressOn=progressOn

------------------------------------------------------------------ sound
local function loadSource(name,kind)
 local ok,bytes=pcall(function()return V.mod:read(M.ASSETS..name)end)
 if ok and type(bytes)=='string'and #bytes>0 then
  local ok2,src=pcall(function()
   return love.audio.newSource(love.filesystem.newFileData(bytes,name),kind or'static')
  end)
  if ok2 and src then return src end
 end
 local ok3,src=pcall(love.audio.newSource,(V.path or'mods/BATTLE_ART_VOXEL_FORK')..'/'..M.ASSETS..name,kind or'static')
 if ok3 and src then return src end
 return nil
end
local SFX={}
local function sfx(name)
 if SFX[name]==nil then SFX[name]=loadSource(name..'.ogg')or false end
 return SFX[name]or nil
end
local voices={}
local function playOnce(game,name,vol,pitch)
 local src=sfx(name);if not src then return end
 local g=sfxGain(game);if g<=0 then return end
 local ok,v=pcall(src.clone,src)
 if ok and v then
  pcall(v.setVolume,v,min(1,(vol or 1)*g))
  pcall(v.setPitch,v,pitch or 1)
  pcall(v.play,v)
  voices[#voices+1]=v
 end
end
local function reapVoices()
 for i=#voices,1,-1 do
  local v=voices[i];local ok,on=pcall(v.isPlaying,v)
  if not(ok and on)then pcall(v.release,v);table.remove(voices,i)end
 end
end
local function musicPlay(game,id,loop,fade)
 pcall(function()
  local Music=require('src.core.Music')
  local songs=game.data and game.data.audio and game.data.audio.songs
  if songs and songs[id]then Music.play(game.data,id,loop,{fade=fade,reason='parade'})end
 end)
end
local function musicFadeOut(n)pcall(function()require('src.core.Music').fadeOut(n or 8)end)end

------------------------------------------------------------------ fonts and cards
local fonts={}
local fontCount=0
local function dropFonts()
 for _,f in pairs(fonts)do if f then pcall(f.release,f)end end
 fonts={};fontCount=0
end
local function fontFile(name,size)
 local key=name..size
 if fonts[key]==nil then
  -- (a window that keeps changing size would keep making sizes: start over)
  if fontCount>=24 then dropFonts()end
  fontCount=fontCount+1
  local f=false
  pcall(function()
   local bytes=V.mod:read(M.ASSETS..name)
   if type(bytes)=='string'and #bytes>0 then
    f=love.graphics.newFont(love.filesystem.newFileData(bytes,name),size)
   end
  end)
  if not f then local ok,d=pcall(love.graphics.newFont,size);f=ok and d or false end
  fonts[key]=f
 end
 return fonts[key]or nil
end
local function titleFont(size)return fontFile('Caladea-Bold.ttf',max(8,floor(size)))end
local function labelFont(size)return fontFile('Poppins-Medium.ttf',max(8,floor(size)))end
local function spacedWidth(f,text,sp)
 local w=0
 for i=1,#text do w=w+f:getWidth(text:sub(i,i))+sp end
 return w-sp
end
local function printSpaced(g,f,text,x,y,sp)
 for i=1,#text do local ch=text:sub(i,i);g.print(ch,x,y);x=x+f:getWidth(ch)+sp end
end

-- a banner's cloth: drawn once into a canvas (never while the scene draws),
-- by the street's banner maker (a canvas at one pixel a pixel, its font
-- made for it and let go)
local function bannerCanvas(b)
 local ok,cv=pcall(function()
  return V.require('ParadeStreet').bannerCanvas(b.text,{w=(b.x1-b.x0)*16,h=b.h,bg=b.bg,fg=b.fg})
 end)
 if not ok then log('the banner could not be made: %s',tostring(cv))end
 return ok and cv or nil
end

-- the Champion's name, as the captions and the banner give it
local function championName(game)
 local s=game and game.save
 local n=s and s.player and s.player.name
 n=tostring(n or'RED')
 if #n==0 then n='RED'end
 return n:upper()
end

------------------------------------------------------------------ building ahead
-- The parade knows its road. While one stop plays, the next stop's map, and
-- the connected maps its road will show, are queued through ChunkMesher's
-- own cooperative queue (the way VoxelPrecache warms a door's destination),
-- a few milliseconds a frame, and kept out of the live-set eviction (a
-- ChunkMesher.setLive wrap) until the parade has been there. The first stop
-- is queued when the Hall of Fame starts.
local Warm={lists={},keep={},active=false,t0=0}
M.Warm=Warm
local function warmReset()
 Warm.lists={};Warm.keep={};Warm.active=false
end
-- what a stop needs built: its own map whole (the FULL mesh, as the
-- renderer builds the map you stand on) and the BODY of every connected map
-- that comes into view range anywhere along its road (the renderer's own
-- rule, RenderDistance.neighbor, from each cell of the road)
function M.warmTargets(game,stop)
 local data=game and game.data
 local maps=data and data.maps
 if not(maps and maps[stop.map])then return nil end
 local MapLoader=require('src.world.MapLoader')
 local host=MapLoader.load(data,stop.map)
 if not host then return nil end
 local masks=nil
 pcall(function()masks=V.require('VoxelPrecache').masksFor(data,stop.map)end)
 local list={{map=host,body=false,masks=masks,id=tostring(stop.map)}}
 -- (TEST242: a place kept to itself builds only its own map and the
 -- neighbours it keeps)
 local inside=M.INSIDE_ONLY and M.INSIDE_ONLY[tostring(stop.map)]
 if inside==true then return list end
 local okC,Controller=pcall(require,'src.world.OverworldController')
 if not(okC and Controller and Controller.computeNeighbors)then return list end
 local okR,RD=pcall(V.require,'RenderDistance')
 local cells=pathCells(stop)
 for _,n in ipairs(Controller.computeNeighbors(maps,stop.map,2)or{})do
  local def=maps[n.id]
  if def and inside and M.insideDrops(stop.map,n.id)then def=nil end
  if def then
   local probe={map={def=def},ox=n.ox,oy=n.oy}
   local need=false
   for _,c in ipairs(cells)do
    local who={cellX=c[1],cellY=c[2],px=c[1]*16,py=c[2]*16}
    local ok,near=true,true
    if okR and RD and RD.neighbor then ok,near=pcall(RD.neighbor,probe,who)end
    if ok and near then need=true;break end
   end
   if need then
    local okL,m=pcall(MapLoader.load,data,n.id)
    if okL and m then list[#list+1]={map=m,body=true,id=tostring(n.id)}end
   end
  end
 end
 return list
end
-- queue stop i (and, unless `only`, stop i+1 after it), of `stops` (the walk's
-- or the float's)
function M.warmFor(game,i,only,stops)
 stops=stops or M.STOPS
 local lists,keep={}, {}
 for k=i,only and i or i+1 do
  local stop=stops[k]
  if stop then
   local ok,list=pcall(M.warmTargets,game,stop)
   if ok and list then
    lists[#lists+1]=list
    for _,e in ipairs(list)do keep[e.id]=true end
   elseif not ok then log('cannot build %s ahead: %s',tostring(stop.map),tostring(list))end
  end
 end
 Warm.lists,Warm.keep,Warm.active,Warm.t0=lists,keep,#lists>0,now()
end
-- every frame: ask for each slot again (a built one answers at once and has
-- its trees seen to; one already queued higher is left alone)
function M.warmPump(game)
 if not Warm.active then return end
 local okC,CM=pcall(V.require,'ChunkMesher')
 if not(okC and CM and CM.request)then return end
 local ow=overworld(game)
 local here=ow and ow.map and tostring(ow.map.id)
 for li,list in ipairs(Warm.lists)do
  for _,e in ipairs(list)do
   if e.id~=here then
    local want=(li==1 and .5 or .45)-(e.body and .05 or 0)
    local have=CM.jobPriority and CM.jobPriority(e.id,e.body)
    if not(have and have>=want)then pcall(CM.request,e.map,e.body,e.masks,want)end
   end
  end
 end
end

-- Is the place the camera is about to show there? The same answer
-- VoxelScene.prefetch gives the renderer (the map's own mesh, and every
-- connected map in view range), asked of the cache itself.
local function sceneReady(ow)
 local CM=V.require('ChunkMesher')
 local map=ow and ow.map
 if not map then return false,'no map'end
 local host=CM.pair(map,false)~=nil or CM.pair(map,true)~=nil
 if not host then
  local okS,VS=pcall(V.require,'VoxelScene')
  if okS and VS and VS.authoredRoomReady then
   local ok,r=pcall(VS.authoredRoomReady,map);host=ok and r and true or false
  end
 end
 if not host then return false,tostring(map.id)end
 local okR,RD=pcall(V.require,'RenderDistance')
 for _,nb in ipairs(ow.neighbors or{})do
  local near=true
  if okR and RD and RD.neighbor then local ok,r=pcall(RD.neighbor,nb,ow.player);near=(not ok)or r end
  if near and nb.map and CM.pair(nb.map,true)==nil and CM.pair(nb.map,false)==nil
     and not CM.slotKnown(nb.map,true)then
   return false,tostring(nb.map.id)
  end
 end
 return true
end
M.sceneReady=sceneReady
-- and the rest of this stop's road (the connected maps its walk comes near)
local function roadBuilt()
 local okC,CM=pcall(V.require,'ChunkMesher')
 if not(okC and CM and CM.pair)then return true end
 for _,e in ipairs(Warm.lists[1]or{})do
  if CM.pair(e.map,e.body)==nil and CM.pair(e.map,not e.body)==nil and not CM.slotKnown(e.map,e.body)then
   return false
  end
 end
 return true
end
local FILMING={reveal=true,show=true,finale=true,outro=true,['end']=true}

-- TEST230: how far along the place is behind the card (0..1), and in what
-- it is still waiting for: the place itself and the roads round it, the
-- street's dressing, the float, then the crowd settling in
local function builtFraction(list)
 local okC,CM=pcall(V.require,'ChunkMesher')
 if not(okC and CM and CM.pair)then return 1,0,0 end
 local n,done=0,0
 for _,e in ipairs(list or{})do
  n=n+1
  if CM.pair(e.map,e.body)~=nil or CM.pair(e.map,not e.body)~=nil or CM.slotKnown(e.map,e.body)then done=done+1 end
 end
 if n==0 then return 1,0,0 end
 return done/n,done,n
end
M.builtFraction=builtFraction
function M.cardState(s,sceneLoaded,stop)
 local place=(stop and(stop.title or stop.place))or'THE CITY'
 local terrain,done,n=builtFraction(Warm.lists[1])
 if sceneLoaded then terrain=1 end
 local street=1
 if s.street then
  local st=s.street
  if st.busy and st:busy()then
   local groups=#(st.order or{})
   local k=st.step or 0
   street=k<4 and k/4*.3 or .3+.7*min(1,(st.gi or 0)/max(1,groups))
   street=min(.97,street)
  end
 end
 local float=1
 if s.float and s.float.progress then
  local ok,p=pcall(s.float.progress,s.float);float=ok and tonumber(p)or 1
 end
 local p=terrain*.70+street*.15+float*.15
 local what
 if terrain<1 then what=('PREPARING %s'):format(tostring(place):upper())..(n>1 and(' (%d/%d)'):format(done,n)or'')
 elseif street<1 then what='DECORATING THE STREET'
 elseif float<1 then what='YOUR FLOAT IS ON ITS WAY'
 else what='THE CROWD IS GATHERING' end
 return min(1,p),what
end
------------------------------------------------------------------ the card screen
-- While a map loads, a do-nothing screen sits over the overworld: the world
-- still draws under it (so its first-frame work happens behind the white),
-- the build gets the covered budget, and nothing walks.
local Card={};Card.__index=Card
Card.isOpaque=false
function Card.new()return setmetatable({},Card)end
function Card:update()end
function Card:draw()end
function Card:keypressed()end

------------------------------------------------------------------ the parade
local Parade={};Parade.__index=Parade

function Parade.new(game,onDone,options)
 local self=setmetatable({game=game,onDone=onDone,i=0,phase='start',t0=now(),
  spawned={},moved={},held=0,hintUntil=0,white=1,finished=false},Parade)
 self.replay=options and options.replay==true
 self.pSmooth=nil
 self.lite=false
 pcall(function()V.require('ParadeCast').LOD_LITE=0 end)   -- (TEST242)
 self.ema=1/60
 self.slowFor=0
 -- TEST264: fail the start cleanly if the float is unavailable. Never
 -- silently enter the retired walking mode after a loader/constructor error.
 local ok,PF=pcall(V.require,'ParadeFloat')
 local okN,f=false,nil
 if ok and PF and type(PF.new)=='function'then okN,f=pcall(PF.new,game)end
 if not okN or not f then
  log('the float could not start; parade skipped: %s',tostring(f or PF))
  return nil
 end
 self.float=f
 -- TEST229: note followers before changing maps, for the float's riders.
 pcall(f.noteWalkers,f)
 self.stops=M.stopsFor(true)
 -- TEST258: a replay owns its stop list; later Hall of Fame parades still
 -- visit both towns. Do not rewrite either the walking or float presets.
 if options and options.only then
  local selected={}
  for _,stop in ipairs(self.stops)do
   if stop.map==options.only then selected[#selected+1]=stop end
  end
  self.stops=selected
 end
 self.name=championName(game)
 -- the first place's title goes up on the white before anything loads
 self.titleI=1;self.titleFrames=0
 -- TEST235: the Easter eggs (none, if they will not start)
 local okE,EG=pcall(V.require,'ParadeEggs')
 if okE and type(EG)=='table'and EG.new then
  local okN,e=pcall(EG.new,self)
  if okN and e then self.eggs=e else log('no Easter eggs: %s',tostring(e))end
 elseif not okE then log('no Easter eggs: %s',tostring(EG))end
 M.profileStart(self)
 return self
end

function Parade:stop()return self.stops[self.i]end
-- TEST242: is the parade at a place it keeps to itself (M.INSIDE_ONLY), with
-- the overworld on that very map? (only then are its neighbours left out)
function M.insideOnly(p)
 p=p or P
 if not(p and not p.finished and M.INSIDE_ONLY)then return false end
 local stop=p.stops and p.stops[p.i]
 if not(stop and stop.map and M.INSIDE_ONLY[tostring(stop.map)])then return false end
 local ow=overworld(p.game)
 return ow~=nil and ow.map~=nil and tostring(ow.map.id)==tostring(stop.map)
end

-- TEST235: the Easter eggs, asked inside pcall; any failure lets them go
-- (everyone upright, their sounds stopped) and the parade runs on as ever
function Parade:eggsCall(name,...)
 local e=self.eggs
 if not e then return nil end
 local fn=e[name]
 if type(fn)~='function'then return nil end
 local ok,a,b,c=pcall(fn,e,...)
 if ok then return a,b,c end
 log('the Easter eggs failed (%s): %s -- let go',tostring(name),tostring(a))
 self.eggs=nil
 pcall(e.release,e)
 pcall(function()V.require('ParadeCast').clearPoses()end)
 M.musicDuck=nil
 return nil
end
-- the crowd's cheer (its loop), the march, the ticker tape (1: as ever)
function Parade:eggLevels()
 if not self.eggs then return 1,1,1 end
 local c,d,k=self:eggsCall('levels')
 return tonumber(c)or 1,tonumber(d)or 1,tonumber(k)or 1
end
-- may the crowd cheer (a one-shot swell)? not while a gag has them asleep
function Parade:cheerOK()
 return not(self.eggs and self:eggsCall('quietCrowd'))
end
-- a hold is over: the hour goes on from where it stood
function Parade:endHold(t)
 if self.holdSince then self.todShift=(self.todShift or 0)+(t-self.holdSince);self.holdSince=nil end
end
-- a gag's camera, while it has one (true: it has the shot)
function Parade:gagCamera(t)
 if not self.eggs then return false end
 local sh=self:eggsCall('shot',t)
 if type(sh)~='table'then return false end
 if sh~=self.shot then self:cutTo(sh,t)end
 return true
end

-- the people of a stop: spawned before the map loads (so it builds them)
function Parade:spawnCrowd(stop)
 local game=self.game
 local sprites=game.data and game.data.sprites or{}
 local W=modRef and modRef.world
 stop.spawnedIds={}
 stop.castById={}
 for _,c in ipairs(stop.crowd or{})do
  local spr,x,y,face=c[1],c[2],c[3],c[4]
  local occupied=false
  local mapDef=game.data and game.data.maps and game.data.maps[stop.map]
  for _,o in ipairs(mapDef and mapDef.objects or{})do
   if o.x==x and o.y==y then occupied=true;break end
  end
  if sprites[spr]and not occupied then
   local def={sprite=spr,x=x,y=y,movement='STAY',range=face}
   local ok,id=pcall(function()
    if W and W.spawnNpc then return W:spawnNpc(stop.map,def)end
    local ow=overworld(game)
    return ow and ow.addRuntimeObject and ow:addRuntimeObject(stop.map,def,'BATTLE_ART_VOXEL_FORK')
   end)
   if ok and id then
    self.spawned[#self.spawned+1]=id;stop.spawnedIds[id]=true;stop.castById[id]=c[5]
   end
  end
 end
end
-- the cheering crowd go again. After a soft reset there is no overworld to
-- ask (the world's removeNpc answers "no overworld"), but the crowd are
-- still in the map's records, and the next visit to the town would find
-- them standing there: whatever the answers, the records are checked and
-- anything of ours still in them is taken out
local OWNER='BATTLE_ART_VOXEL_FORK'
local function dropRecord(game,id,owners)
 local seen={}
 local removed=false
 local G=rawget(_G,'Game')
 for _,maps in ipairs({game and game.data and game.data.maps or false,G and G.data and G.data.maps or false})do
  if type(maps)=='table'and not seen[maps]then
   seen[maps]=true
   for mapId,def in pairs(maps)do
    local objs=type(def)=='table'and def.objects
    if type(objs)=='table'then
     for i=#objs,1,-1 do
      local o=objs[i]
      if type(o)=='table'and o.runtime and owners[o.owner or false]
         and tostring(mapId)..'_obj_'..tostring(o.index)==id then
       table.remove(objs,i)
       removed=true
      end
     end
    end
   end
  end
 end
 return removed
end
M.dropRecord=dropRecord
function Parade:removeCrowd()
 pcall(function()V.require('ParadeCast').clear()end)
 local W=modRef and modRef.world
 local ow=overworld(self.game)
 local owners={[OWNER]=true}
 if W and W.modId then owners[W.modId]=true end
 local missing=0
 for _,id in ipairs(self.spawned)do
  local done=false
  if W and W.removeNpc then
   local ok,r=pcall(W.removeNpc,W,id)
   done=ok and r==true
  end
  if not done and ow and ow.removeRuntimeObject then
   local ok,r=pcall(ow.removeRuntimeObject,ow,id,(W and W.modId)or OWNER)
   done=ok and r==true
  end
  if dropRecord(self.game,id,owners)then done=true end
  if not done then missing=missing+1 end
  if ow and ow.marchers then
   for e in pairs(ow.marchers)do if e.id==id then ow.marchers[e]=nil end end
  end
 end
 if missing>0 then log('%d of the crowd were already gone',missing)end
 self.spawned={}
end

-- (TEST228: a partner from any follower mod -- Followers EX, PokePC, Wilds --
-- is yours, not one of the crowd: it is not stopped, made to jump about, or
-- moved off the road like the townsfolk)
local function isFollower(npc)
 if type(npc)~='table'then return false end
 -- (TEST229: ParadeFloat's test, the one the float leaves walkers off by)
 local okF,PF=pcall(V.require,'ParadeFloat')
 if okF and type(PF)=='table'and type(PF.isFollower)=='function'then
  local okI,yes=pcall(PF.isFollower,npc)
  if okI and yes then return true end
 end
 return npc.pikachuFollower==true or npc.name=='PIKACHU_FOLLOWER'
  or npc.isPokemonFollower==true or npc.pokepcTrailer==true or npc.wildsFollower==true
  or npc._pokepcFollowerSpecies~=nil or npc._wildsFollowerSpecies~=nil
end
M._isFollower=isFollower
-- everyone on the map watches the Champion: the townsfolk stop wandering,
-- turn to face you, and about half of the cheering crowd jump about
function Parade:settleCrowd(stop)
 local ow=overworld(self.game);if not ow then return end
 stop.people={}
 local k=0
 for _,npc in ipairs(ow.npcs or{})do
  if not isFollower(npc)and npc.def and npc.def.sprite~='SPRITE_POKE_BALL'then
   local saved={wanders=npc.wanders,steps=npc.steps,pinnedFacing=npc.pinnedFacing,facing=npc.facing}
   npc.wanders=false
   npc.steps=false
   k=k+1
   local ours=stop.spawnedIds and stop.spawnedIds[npc.id]
   if ours and stop.castById and stop.castById[npc.id]then
    V.require('ParadeCast').bind(npc,stop.castById[npc.id])
   end
   stop.people[#stop.people+1]={npc=npc,ours=ours,march=ours and(k%2==0),phase=(k*.37)%1,saved=saved}
  end
 end
end
-- TEST226: the town's own people standing in the road step onto the
-- pavement for the parade (Celadon's fisherman and his Poliwrath stand in the
-- middle of the main street), and go back to their places after
function Parade:clearRoad(stop)
 local ow=overworld(self.game);if not(ow and stop.clear)then return end
 local function inRoad(x,y)
  for _,r in ipairs(stop.clear)do
   if x>=r[1]and x<=r[2]and y>=r[3]and y<=r[4]then return true end
  end
  return false
 end
 local function taken(x,y)
  for _,e in ipairs(ow.npcs or{})do
   if e.cellX==x and e.cellY==y then return true end
  end
  for _,c in ipairs(stop.crowd or{})do if c[2]==x and c[3]==y then return true end end
  return false
 end
 for _,npc in ipairs(ow.npcs or{})do
  if not isFollower(npc)and not(stop.spawnedIds and stop.spawnedIds[npc.id])
     and npc.cellX and inRoad(npc.cellX,npc.cellY)then
   for _,c in ipairs(stop.parking or{})do
    if not taken(c[1],c[2])then
     self.moved[#self.moved+1]={npc=npc,cellX=npc.cellX,cellY=npc.cellY,px=npc.px,py=npc.py,
      facing=npc.facing,moving=npc.moving,progress=npc.progress,targetX=npc.targetX,targetY=npc.targetY}
     npc.cellX,npc.cellY=c[1],c[2]
     npc.px,npc.py=c[1]*16,c[2]*16
     npc.moving=false;npc.progress=0;npc.targetX=nil;npc.targetY=nil
     break
    end
   end
  end
 end
end
function Parade:restoreRoad()
 for i=#self.moved,1,-1 do
  local m=self.moved[i]
  local npc=m.npc
  pcall(function()
   npc.cellX,npc.cellY,npc.px,npc.py=m.cellX,m.cellY,m.px,m.py
   npc.facing,npc.moving,npc.progress,npc.targetX,npc.targetY=m.facing,false,0,nil,nil
  end)
 end
 self.moved={}
end
function Parade:watch(stop,t)
 local ow=overworld(self.game);if not(ow and stop.people)then return end
 local p=ow.player
 ow.marchers=ow.marchers or{}
 -- (TEST235: the people a gag is using are left to it; while it has the
 -- crowd asleep, nobody marches)
 local held=self.eggs and self.eggs.held
 local cheering=self.cheering and not(self.eggs and(self.eggs.cheer or 1)<.5)
 for _,e in ipairs(stop.people)do
  local npc=e.npc
  if not(held and held[npc])then
   if not npc.moving or npc.marching then
    pcall(npc.facePlayer,npc,p)
    npc.pinnedFacing=npc.facing
   end
   -- the cheering ones march in place, in waves, while the parade is near
   if e.march then
    local on=cheering and((t*.55+e.phase)%1<.72)
    ow.marchers[npc]=on and true or nil
   end
  end
 end
end
function Parade:quietCrowd(stop)
 local ow=overworld(self.game);if not(ow and stop and stop.people)then return end
 for _,e in ipairs(stop.people)do
  if ow.marchers then ow.marchers[e.npc]=nil end
  local sv=e.saved
  if sv and not e.ours then
   e.npc.wanders,e.npc.steps,e.npc.pinnedFacing,e.npc.facing=sv.wanders,sv.steps,sv.pinnedFacing,sv.facing
  end
 end
 stop.people=nil
 pcall(function()V.require('ParadeCast').clear()end)
end

------------------------------------------------------------------ the dressing and the confetti
-- (both belong to one stop: made as it is entered, let go as it is left)
function Parade:releaseStopFx()
 if self.street then pcall(self.street.release,self.street)end
 if self.confetti then pcall(self.confetti.release,self.confetti)end
 self.street,self.confetti=nil,nil
end
function Parade:makeStopFx(stop)
 self:releaseStopFx()
 local ow=overworld(self.game)
 local map=ow and ow.map
 local function ground(x,z)return map and groundXZ(map,x,z)or 0 end
 local okC,PCm=pcall(V.require,'ParadeConfetti')
 if okC and PCm then
  local ok,sys=pcall(PCm.new,{ground=ground,cap=stop.set and PCm.CAP or 1536})
  if ok then self.confetti=sys else log('no confetti: %s',tostring(sys))end
 end
 if stop.set then
  local okS,PS=pcall(V.require,'ParadeStreet')
  if okS and PS then
   -- the crowd stands clear of everyone already there (the town's people,
   -- the parade's, the follower) and of the cameras
   local desc={}
   for k,v in pairs(stop.set)do desc[k]=v end
   local avoid={}
   for _,a in ipairs(stop.set.avoid or{})do avoid[#avoid+1]=a end
   for _,e in ipairs(ow and ow.npcs or{})do
    if e.cellX then avoid[#avoid+1]={e.cellX*16+8,e.cellY*16+8,7.5}end
   end
   for _,c in ipairs(stop.crowd or{})do avoid[#avoid+1]={c[2]*16+8,c[3]*16+8,7.5}end
   desc.avoid=avoid
   local ok,set=pcall(PS.new,desc,ground)
   if ok and set then
    self.street=set
    local okP,err=pcall(set.prepare,set,{name=self.name..', CHAMPION OF KANTO!'})
    if not okP then log('the banners would not draw: %s',tostring(err))end
    if self.lite then pcall(set.setLite,set,self.lite)end
   else log('the street would not dress: %s',tostring(set))end
  end
 end
end

------------------------------------------------------------------ stops
function Parade:enterStop(i)
 M.profileClose(self)
 local game=self.game
 local ow=overworld(game)
 local stop=self.stops[i]
 if not(ow and stop)then return self:finish()end
 local leaving=self.i>0
 if leaving then
  self:quietCrowd(self.stops[self.i])
  self:restoreRoad()
 end
 self:releaseStopFx()
 -- TEST244: the last place's Easter eggs (Celadon's Jigglypuff and
 -- Magikarp models, the song's stream, their sounds and icons) are let go
 -- BEFORE the next place loads, not after it, and the garbage left by the
 -- last place (its street, confetti, crowd) is collected under the white, so
 -- Pallet's map and the encore are not allocated on top of Celadon's.
 if leaving and M.FREE_BETWEEN_STOPS then
  if self.eggs then self:eggsCall('leaveStop')end
  pcall(function()collectgarbage('collect');collectgarbage('collect')end)
 end
 self.i=i
 self.phase='card';self.phaseT=now();self.white=1
 self.titleI=i
 self.cheering=false
 self.readySince=nil;self.ready=false;self.stopT0=nil;self.revealT=nil
 self.todShift,self.holdSince=0,nil
 self.shotI=nil;self.shot=nil
 self.fired={}
 self.walk=nil
 self.road,self.roadL=roadLine(stop)
 self.progress=0
 -- the card screen over the overworld while the map loads
 if not self.card then
  self.card=Card.new()
  pcall(function()game.stack:push(self.card)end)
 end
 -- this stop's maps stay; the next stop's start building now
 pcall(M.warmFor,game,i,false,self.stops)
 -- the music: the march from the start; the homecoming for Pallet
 if stop.home then musicFadeOut(8)
 elseif i==1 then musicPlay(game,'Music_ChampionParade',true,6)end
 M.tod=todOf(stop,0)
 self:spawnCrowd(stop)
 -- TEST229: (and again before each change of map: who walked here)
 if self.float and self.float.noteWalkers then pcall(self.float.noteWalkers,self.float)end
 local sx,sy=stop.start[1],stop.start[2]
 local ok,err=pcall(ow.setMap,ow,stop.map,sx,sy,stop.facing or'down',
  {via='warp',keepMusic=true,pikachuSpawn=2,checkpoint=self.replay or nil})
 if not ok then log('setMap %s failed: %s',stop.map,tostring(err));return self:finish()end
 pcall(function()ow.player.facing=stop.facing or'down'end)
 -- the ground the stop's heights are measured from (the start of its road)
 self.baseY=groundAt(ow.map,sx,sy)
 self.tickerLines=nil
 if stop.ticker then
  self.tickerLines={}
  for k,L in ipairs(stop.ticker)do
   local c={}
   for kk,v in pairs(L)do c[kk]=v end
   c.y0,c.y1=L.y0+self.baseY,L.y1+self.baseY
   self.tickerLines[k]=c
  end
 end
 self:settleCrowd(stop)
 self:clearRoad(stop)
 self.loadT=now()
 self.mapId=stop.map
 -- banners: their cloth is drawn now, outside the scene pass
 if stop.banner and stop.banner.canvas==nil then stop.banner.canvas=bannerCanvas(stop.banner)or false end
 -- the dressing (built under the card, a piece a frame) and the confetti
 self:makeStopFx(stop)
 -- TEST235: this stop's Easter eggs (the last stop's let go); they load
 -- under the card
 if self.eggs then self:eggsCall('enterStop',i,stop)end
 -- the first camera (it warms behind the card)
 self.pSmooth=self:playerPos()
 self:cutTo(self:firstShot(stop),now())
end

-- the scene is up when the cache has it (and nothing is covering it);
-- after a long while of trying, go on with what there is
function Parade:loaded()
 local t=now()
 local ok,ready,why=pcall(sceneReady,overworld(self.game))
 if not ok then ready,why=true,'?'end
 if ready then
  local gate=false
  pcall(function()gate=V.require('VoxelTransitionGate').status().active and true or false end)
  if gate then ready,why=false,'cover'end
 end
 self.why=why
 if ready then
  self.readySince=self.readySince or t
  if t-self.readySince<M.T.settle then return false end
  -- give the rest of the road a moment, if it is still on its way
  if t-self.readySince<M.T.pathWait and not roadBuilt()then self.why='road';return false end
  return true
 end
 self.readySince=nil
 return t-self.loadT>M.T.loadLimit
end

------------------------------------------------------------------ the camera crew
function Parade:playerPos()
 local ow=overworld(self.game)
 local p=ow and ow.player
 if not(p and ow.map)then return self.pSmooth or{0,0,0}end
 local x,z=(p.px or p.cellX*16)+8,(p.py or p.cellY*16)+8
 local y=groundAt(ow.map,p.cellX,p.cellY,p.px,p.py)
 return{x,y,z}
end
-- a shot's settings for this parade (walking changes some)
local function field(sh,walking,k)
 if walking and sh.walk and sh.walk[k]~=nil then return sh.walk[k]end
 return sh[k]
end
function Parade:walking()return self.float==nil end
-- the end of the road, in the world
function Parade:roadEnd(stop)
 local ow=overworld(self.game)
 local cells=pathCells(stop)
 local c=cells[#cells]
 return cellWorld(ow.map,c[1],c[2])
end
-- the shot a stop opens on
function Parade:firstShot(stop)
 if stop.coda then
  local cd=stop.coda
  local E=self:roadEnd(stop)
  return{kind='crane',dur=cd.dur,
   from={eye={E[1]+cd.from.eye[1],E[2]+cd.from.eye[2],E[3]+cd.from.eye[3]},
    focus={E[1]+cd.from.focus[1],E[2]+cd.from.focus[2],E[3]+cd.from.focus[3]},fov=cd.from.fov,world=true},
   to={eye={E[1]+cd.to.eye[1],E[2]+cd.to.eye[2],E[3]+cd.to.eye[3]},
    focus={E[1]+cd.to.focus[1],E[2]+cd.to.focus[2],E[3]+cd.to.focus[3]},fov=cd.to.fov,world=true},
   name='homecoming'}
 end
 return stop.shots and stop.shots[1]or{kind='follow',eye={0,60,90},aim={0,12,0},fov=46}
end
-- cut to a shot (it starts now)
function Parade:cutTo(sh,t)
 M.profileClose(self)
 -- (a change of LITE waiting for a cut: this is it)
 if self.litePending then self:applyLite()end
 self.shot=sh
 self.shotT0=t
 self.aimS=nil
 self.fovS=nil
 self.craneFrom=nil
 if sh and sh.kind=='crane'then
  -- a crane's ends, fixed as it starts: `aim` is from where you are now
  local Pp=self.pSmooth or self:playerPos()
  -- (world heights are above the stop's ground, unless `world`: the
  -- homecoming's are worked out from where you stop, ground and all)
  local by=self.baseY or 0
  local function endOf(e)
   local up=e.world and 0 or by
   local eye={e.eye[1],e.eye[2]+up,e.eye[3]}
   if e.relEye then eye={Pp[1]+e.eye[1],Pp[2]+e.eye[2],Pp[3]+e.eye[3]}end
   local focus
   if e.focus then focus={e.focus[1],e.focus[2]+up,e.focus[3]}
   else focus={Pp[1]+e.aim[1],Pp[2]+e.aim[2],Pp[3]+e.aim[3]}end
   return{eye=eye,focus=focus,fov=e.fov or 50}
  end
  self.craneFrom=endOf(sh.from)
  self.craneTo=endOf(sh.to)
 end
 -- the shot's name, for the log (what the crew did, in order)
 if sh and sh.name and t>0 then
  if self.lastShotName~=sh.name then self.shotLog=(self.shotLog and self.shotLog..' > 'or'')..sh.name end
  self.lastShotName=sh.name
 end
end
-- where the camera is this frame
function Parade:shotCamera(t,dt)
 local sh=self.shot
 if not sh then return nil end
 local Pp=self.pSmooth or self:playerPos()
 local walking=self:walking()
 local age=t-(self.shotT0 or t)
 local eye,focus,fov
 if sh.kind=='crane'then
  local u=smooth(age/max(.1,sh.dur or 5))
  local a,b=self.craneFrom,self.craneTo
  eye=lerp3(a.eye,b.eye,u);focus=lerp3(a.focus,b.focus,u);fov=rad(lerp(a.fov,b.fov,u))
 else
  local aim=field(sh,walking,'aim')or{0,12,0}
  local target={Pp[1]+aim[1],Pp[2]+aim[2],Pp[3]+aim[3]}
  if sh.kind=='follow'then
   local e=field(sh,walking,'eye')
   eye={Pp[1]+e[1],Pp[2]+e[2],Pp[3]+e[3]}
   focus=target
  else
   local e=field(sh,walking,'eye')
   local d=sh.drift
   eye={e[1]+(d and d[1]*age or 0),e[2]+(self.baseY or 0)+(d and d[2]*age or 0),e[3]+(d and d[3]*age or 0)}
   -- an operator following you: the aim eases after you
   if not self.aimS then self.aimS=target else
    local k=1-math.exp(-(dt or 1/60)/.30)
    self.aimS=lerp3(self.aimS,target,k)
   end
   focus={self.aimS[1],self.aimS[2],self.aimS[3]}
  end
  local frame=field(sh,walking,'frame')
  if frame then
   -- the long lens: as much of the picture as `frame` world pixels
   local dx,dy,dz=focus[1]-eye[1],focus[2]-eye[2],focus[3]-eye[3]
   local dist=max(8,sqrt(dx*dx+dy*dy+dz*dz))
   local want=max(rad(8),min(rad(55),2*math.atan(frame*.5/dist)))
   if not self.fovS then self.fovS=want else self.fovS=lerp(self.fovS,want,1-math.exp(-(dt or 1/60)/.4))end
   fov=self.fovS
  else
   fov=rad(field(sh,walking,'fov')or 46)
  end
 end
 -- a hand-held camera breathes and sways; the others barely move
 local a=sh.shake or .12
 eye[1]=eye[1]+sin(t*1.7)*a+sin(t*.31)*.6
 eye[2]=eye[2]+sin(t*2.3+1)*a*.6
 eye[3]=eye[3]+cos(t*1.3)*a*.5
 focus[1]=focus[1]+sin(t*2.1+.5)*a*.5
 focus[2]=focus[2]+cos(t*1.9)*a*.4
 return{eye=eye,focus=focus,fov=fov,up={0,1,0},curve=0}
end
function M.rig()
 local s=P
 if not s or s.finished or s.phase=='start'then return nil end
 return s.cam
end
-- Public, read-only view for ParadeCast. Outside Celadon's live parade there
-- is no policy; a missing/invalid rig also preserves the original renderer.
function M.crowdShadowView()
 local s=P
 if not M.CROWD_SHADOW_DISTANCE or not s or s.finished or s.mapId~='CELADON_CITY'
  or(s.phase~='reveal'and s.phase~='show'and s.phase~='finale')then return nil end
 return s.cam,s.shot
end
-- Separate from the shadow switch: detail selection is active only in a
-- live Celadon shot. A finished/aborted parade can never queue new cards.
function M.crowdDetailView(warming)
 local s=P
 if not s or s.finished or s.mapId~='CELADON_CITY'
  or(not warming and s.phase~='reveal'and s.phase~='show'and s.phase~='finale')then return nil end
 return s.cam or(warming and{}or nil),s.shot
end

------------------------------------------------------------------ fireworks
-- a salvo: n shells over a point {x,y,z} (world), one every `spacing` s
local function shellsAt(id,c,n,t0,spacing,scale)
 local list={}
 for k=1,n do
  local h=(k*7919+#id*31)%97/97
  local h2,h3=(h*3.7)%1,(h*5.3)%1
  local kind=floor(h*4)%4
  local col=kind==2 and FW_GOLD or FW_COLS[(k*3+floor(h2*8))%#FW_COLS+1]
  list[#list+1]={launchT=t0+(k-1)*spacing+h3*.25,rise=1.0+.25*h2,kind=kind,scale=scale or 1,
   bx=c[1]+(h2-.5)*240,by=c[2]+(h3-.3)*60,bz=c[3]+(h-.5)*110,
   R=(100+60*h3)*(scale or 1),col=col,bright=1}
 end
 return list
end
M.shellsAt=shellsAt
function Parade:salvo(stop,def)
 if not(def and def.n and def.n>0)then return end
 local c=def.at and{def.at[1],def.at[2]+(self.baseY or 0),def.at[3]}
 if def.rel then
  local E=self:roadEnd(stop)
  c={E[1]+def.rel[1],E[2]+def.rel[2],E[3]+def.rel[3]}
 end
 if not c then return end
 pcall(function()V.require('LeagueRoad').salvo(stop.map,shellsAt(stop.map,c,def.n,now()+.2,def.spacing or .6,def.scale))end)
end

------------------------------------------------------------------ the walk
function Parade:startWalk(stop)
 self.walk={moves=stop.path,i=0,busy=false,done=false}
 self:nextMove()
end
function Parade:nextMove()
 if self.finished then return end
 local w=self.walk
 local ow=overworld(self.game)
 if not(w and ow)then return end
 w.i=w.i+1
 local m=w.moves[w.i]
 if not m then w.done=true;w.busy=false;return end
 w.busy=true
 local p=ow.player
 if m[1]=='hop'then
  p.facing='down'
  local ok,hopped=pcall(ow.checkLedgeHop,ow,'down')
  if ok and hopped then w.polling=true
  else pcall(ow.scriptMove,ow,p,'down',2,function()self:nextMove()end)end
 else
  local ok=pcall(ow.scriptMove,ow,p,m[1],m[2],function()self:nextMove()end)
  if not ok then w.done=true;w.busy=false end
 end
end
function Parade:pollWalk()
 local w=self.walk
 local ow=overworld(self.game)
 if w and w.polling and ow then
  if #(ow.scriptMoves or{})==0 and not ow.player.moving then w.polling=false;self:nextMove()end
 end
end

------------------------------------------------------------------ the fireworks of paper
local PC=nil
local function confettiLib()
 if PC==nil then local ok,m=pcall(V.require,'ParadeConfetti');PC=ok and m or false end
 return PC or nil
end
-- the float's two cannons (or, walking, a handful from the buildings either
-- side of you): `big` for the finale
function Parade:cannonsFire(stop,big)
 local C=self.confetti;local L=confettiLib()
 if not(C and L)then return end
 local fired=false
 if self.float and self.float.cannonPoints then
  local ok,pts=pcall(self.float.cannonPoints,self.float)
  if ok and pts then
   for k,c in ipairs(pts)do
    C:burst(c.muzzle[1],c.muzzle[2],c.muzzle[3],c.dir,big and 130 or 75,big and 40 or 34,.42,L.CONFETTI,{delay=(k-1)*.08})
    fired=true
   end
  end
 end
 if not fired then
  -- walking: a cloud of it thrown down over you from either side
  local Pp=self.pSmooth or self:playerPos()
  for side=-1,1,2 do
   C:burst(Pp[1]+side*4,Pp[2]+44,Pp[3]+side*22,{0,-.2,-side*.8},big and 90 or 55,22,.6,L.CONFETTI,{over=.3})
  end
 end
 playOnce(self.game,'confetti_pop',.62,.94+.12*love.math.random())
 playOnce(self.game,'confetti_pop',.48,1.08)
end
-- the plaza's cannons and the curtain over it: the finale
function Parade:finaleFx(stop,t)
 local C=self.confetti;local L=confettiLib()
 local fin=stop.finale or{}
 if C and L then
  if self.street then
   local ok,cs=pcall(self.street.cannons,self.street)
   if ok and cs then
    for k,c in ipairs(cs)do
     C:burst(c.muzzle[1],c.muzzle[2],c.muzzle[3],c.dir,170,48,.30,L.CONFETTI,{delay=.35+k*.25,ribbon=.2})
    end
   end
  end
  local d=fin.drop
  if d then
   if stop.coda then
    local E=self:roadEnd(stop)
    C:drop(E[1]+d[1],E[1]+d[2],E[3]+d[3],E[3]+d[4],E[2]+d[5],E[2]+d[6],d[7],L.CONFETTI,{over=2.2,delay=.4})
   else
    local by=self.baseY or 0
    C:drop(d[1],d[2],d[3],d[4],d[5]+by,d[6]+by,d[7],L.CONFETTI,{over=2.6,delay=.6})
   end
  end
 end
 self:cannonsFire(stop,true)
 if self.street then pcall(self.street.letGo,self.street,t+.9)end
 self:salvo(stop,fin.salvo)
 playOnce(self.game,'crowd_swell',.85,1)
 playOnce(self.game,'confetti_pop',.7,.82)
 if self.float then pcall(self.float.cheer,self.float,t+.4)end
end

------------------------------------------------------------------ update
function Parade:skip()
 if self.phase=='end'or self.phase=='done'then return end
 -- (TEST235 ending: a skip, not the parade's own end -- the gags stop at once)
 self.skipped=true
 -- (TEST228: a card skipped past draws the world under it again)
 if self.card then self.card.isOpaque=nil end
 self.phase='end';self.phaseT=now();self.whiteFrom=self.white
 musicFadeOut(6)
end
-- the game left the overworld under the parade (a soft reset to the title):
-- clear up (the cheering people, the camera, the build-ahead) without going
-- on to the credits, and with no white over the title
function Parade:abort()
 self.onDone=nil
 if self.card then self.card.isOpaque=nil end
 self.card=nil
 self:finish()
 M.hudOut=nil
end

-- the frame rate: too slow for long enough, and the parade goes LITE (and,
-- if that is not enough, LITE 2). A single long frame (a picture made, the
-- garbage collector) is a hitch, not the pace: frames over a quarter of a
-- second are left out, and none counts for more than a fifteenth. The
-- change itself waits for the next cut (or LITE_WAIT), so that half the
-- crowd do not vanish in the middle of a shot.
function Parade:pace(dt,t)
 if not dt or dt<=0 or dt>.25 then return end
 if self.litePending then
  if t-self.litePending.t>M.LITE_WAIT then self:applyLite()end
  return
 end
 if self.lite==2 then return end
 local k=1-math.exp(-dt/.6)
 self.ema=self.ema+(min(dt,1/15)-self.ema)*k
 local filming=self.phase=='show'or self.phase=='finale'or(self.phase=='reveal'and self.revealT and t-self.revealT>1.5)
 local limit=self.lite and M.LITE2_FRAME or M.LITE_FRAME
 if filming and self.ema>limit then self.slowFor=self.slowFor+dt else self.slowFor=max(0,self.slowFor-dt*.5)end
 if self.slowFor>M.LITE_AFTER then
  self.slowFor=0
  self.litePending={level=self.lite and 2 or 1,t=t,fps=1/self.ema}
 end
end
function Parade:applyLite()
 local p=self.litePending
 if not p then return end
 self.litePending=nil
 self.lite=p.level
 log('the frame rate is low (%.0f fps): going LITE %d (%s)',p.fps,self.lite,
  self.lite==1 and'half the ticker tape'or'a third of the ticker tape')
 M.profileLite(self,self.lite,p.fps)
 if self.street then pcall(self.street.setLite,self.street,self.lite)end
 -- (TEST242: and the crowd's far people are posed less often still)
 pcall(function()V.require('ParadeCast').LOD_LITE=tonumber(self.lite)or 0 end)
end

function Parade:update(dt)
 if self.finished then return end
 local game=self.game
 local t=now()
 dt=dt or 1/60
 reapVoices()
 -- skipping: hold A or START
 local input=game.input
 if input then
  local function down(b)return(input.isDown and input:isDown(b))or false end
  local held=down('a')or down('start')
  if input.wasPressed and(input:wasPressed('a')or input:wasPressed('b')or input:wasPressed('start'))then self.hintUntil=t+3 end
  self.held=held and self.held+dt or 0
  if self.held>=M.T.skipHold then self:skip()end
 end
 local stop=self:stop()
 -- the Champion, smoothed (steps without the jolt)
 if stop and self.phase~='card'then
  local Pp=self:playerPos()
  if not self.pSmooth then self.pSmooth=Pp else
   local k=1-math.exp(-dt/.22)
   self.pSmooth=lerp3(self.pSmooth,Pp,k)
  end
  if self.road then self.progress=progressOn(self.road,self.roadL,self.pSmooth[1],self.pSmooth[3])end
 end
 if stop then self:watch(stop,t)end
 self:pollWalk()
 self:updateCrowdSound(dt)
 self:pace(dt,t)

 local ph=self.phase
 if ph=='start'or ph=='precard'then
  -- the next place's title is on the white first (TITLE_FRAMES frames of
  -- it drawn); only then does the place load, hitch and all, behind it.
  -- (The homecoming has no title: the white is enough.)
  local since=t-(ph=='start'and self.t0 or self.phaseT)
  local nextI=ph=='start'and 1 or self.i+1
  local titled=not(self.stops[nextI]and self.stops[nextI].coda)
  if((self.titleFrames>=M.TITLE_FRAMES or not titled)and since>=(ph=='start'and .3 or 0))or since>1.0 then
   self:enterStop(nextI)
  end
 elseif ph=='card'then
  -- the float's riders and the street's dressing load under the card
  -- (TEST228: and how long each of the card's waits takes, for its log line)
  local waited=self.cardWaits or{}
  self.cardWaits=waited
  local function wait(what)waited[what]=(waited[what]or 0)+dt end
  local busy=false
  if self.float then
   local okL,more=pcall(self.float.loadStep,self.float)
   busy=okL and more or false
   if not busy then local okB,b=pcall(self.float.busy,self.float);busy=okB and b or false end
   if busy then wait('float')end
  end
  if self.street then
   local okS,more=pcall(self.street.buildStep,self.street)
   if not okS then log('the street failed to build: %s',tostring(more));pcall(self.street.release,self.street);self.street=nil
   elseif more then busy=true;wait('street')end
  end
  -- TEST235: the Easter eggs' models and sounds (a thing a frame)
  if self.eggs and self:eggsCall('loadStep')then busy=true;wait('eggs')end
  if busy and t-self.phaseT>M.T.loadLimit then busy=false end
  -- Readiness settles while the dressing/riders load, rather than starting
  -- another wait after the title hold has elapsed.
  local sceneLoaded=self:loaded()
  if not sceneLoaded then wait(self.readySince and'settle'or tostring(self.why or'?'))end
  -- (TEST230: the card's bar and its words; the bar eases toward how far
  -- along the place is, and creeps on while it waits, never past the next
  -- milestone)
  do
   local okS,p,what=pcall(M.cardState,self,sceneLoaded,stop)
   if okS then
    self.cardWhat=what
    local shown=self.cardShown or 0
    if p>shown then shown=shown+(p-shown)*min(1,dt*3)end
    local cap=min(.98,p+.12)
    if shown<cap then shown=min(cap,shown+dt*.008)end
    self.cardShown=shown
    if what~=self.cardLastWhat then
     self.cardLastWhat=what
     log('%s: %s (%.0f%% after %.1fs)',tostring(stop and stop.map),what,p*100,t-self.phaseT)
    end
   end
  end
  -- TEST228: nothing of the world shows through the white, so it is drawn
  -- only one frame in CARD_WORLD_EVERY (enough for its first-frame work and
  -- the crowd's warming to happen behind the card, and for the transition
  -- cover to see the place whole); the other frames' time goes to the build
  -- the card is waiting for, which runs in the update either way. Once the
  -- place is there, every frame is drawn again, so the picture comes up
  -- without a first-frame hitch.
  if self.card then
   self.cardFrames=(self.cardFrames or 0)+1
   local world=self.readySince~=nil or self.cardFrames%M.CARD_WORLD_EVERY==0
   self.card.isOpaque=not world
  end
  if not busy and t-self.phaseT>=(self.i==1 and M.T.firstCard or M.T.card)and sceneLoaded then
   local parts={}
   for what,secs in pairs(waited)do if secs>=.05 then parts[#parts+1]={what,secs}end end
   table.sort(parts,function(a,b)return a[2]>b[2]end)
   local list={}
   for k=1,math.min(4,#parts)do list[k]=('%s %.1fs'):format(parts[k][1],parts[k][2])end
   log('%s: card up %.1fs (%s; waited on: %s)',tostring(stop.map),t-self.phaseT,
     self.readySince and'ready'or('gave up waiting for '..tostring(self.why)),#list>0 and table.concat(list,', ')or'nothing')
   self.cardWaits,self.cardFrames=nil,nil
   self.cardShown,self.cardWhat,self.cardLastWhat=nil,nil,nil
   -- the card lifts: the opening shot
   -- (TEST228: never left opaque, even if something sits on top of it)
   if self.card then
    self.card.isOpaque=nil
    pcall(function()if game.stack:top()==self.card then game.stack:pop()end end);self.card=nil
   end
   self.phase='reveal';self.phaseT=t;self.stopT0=t;self.revealT=t
   self.pSmooth=self:playerPos()
   self:cutTo(self:firstShot(stop),t)
   self.cheering=true
   if stop.home then musicPlay(game,'Music_ChampionParadeHome',false,nil)end
   self.crowdTarget=stop.crowdVol or .6
   if self:cheerOK()then playOnce(game,'crowd_swell',.55*(stop.crowdVol or .6),1)end
   if self.float then pcall(self.float.cheer,self.float,t+.7)end
   -- the air is already full of it as the picture comes up
   local C=self.confetti;local L=confettiLib()
   if C and L then
    if self.tickerLines then
     for _=1,3 do C:ticker(.5,self.tickerLines,{x0=-1e9,x1=1e9,z0=-1e9,z1=1e9},40,L.TICKER,'opening')end
    end
    if stop.rain then
     local Pp=self.pSmooth
     C:drop(Pp[1]-90,Pp[1]+90,Pp[3]-110,Pp[3]+60,50,95,70,L.CONFETTI,{over=1.2})
    end
   end
   if stop.coda then self:startWalk(stop)end
  end
 elseif ph=='reveal'then
  self.white=1-smooth((t-self.phaseT)/M.T.reveal)
  local hold=stop.coda and M.T.codaEstablish or M.T.establish
  if t-self.phaseT>=max(hold,M.T.reveal)then
   self.white=0
   self.phase='show';self.phaseT=t
   if not stop.coda then self:startWalk(stop)end
  end
 elseif ph=='show'then
  -- (TEST235: a gag's camera beats, while it has them; else the crew's cuts)
  if not self:gagCamera(t)then self:direct(stop,t)end
  self:stream(stop,dt,t)
  -- (TEST235: the finale waits while a gag's act is on)
  local holding=self.walk and self.walk.done and self.eggs and self:eggsCall('holdFinale',t)
  if holding then self.holdSince=self.holdSince or t end
  if self.walk and self.walk.done and not holding then
   self:endHold(t)
   pcall(function()overworld(game).player.facing='down'end)
   self.phase='finale';self.phaseT=t
   local fin=stop.finale or{}
   local crane=self.float and fin.crane or(fin.walkCrane or fin.crane)
   if crane then self:cutTo({kind='crane',dur=fin.dur or 6,from=crane.from,to=crane.to,name='finale'},t)end
   -- (TEST235: the cannons wake everyone: the cheering and the march are back)
   if self.eggs then self:eggsCall('wake',t)end
   self:finaleFx(stop,t)
  end
 elseif ph=='finale'then
  self:gagCamera(t)
  self:stream(stop,dt,t,true)
  local fin=stop.finale or{}
  -- (TEST235: a stop-level gag may hold the stop's end open)
  local holdingEnd=t-self.phaseT>=(fin.dur or 6)and self.eggs and self:eggsCall('holdEnd',t)
  if holdingEnd then self.holdSince=self.holdSince or t else self:endHold(t)end
  if t-self.phaseT>=(fin.dur or 6)and not holdingEnd then
   if self.i<#self.stops then
    self.phase='outro';self.phaseT=t
   else
    self.phase='end';self.phaseT=t;self.whiteFrom=self.white
   end
  end
 elseif ph=='outro'then
  self.white=smooth((t-self.phaseT)/M.T.white)
  if t-self.phaseT>=M.T.white then
   self.white=1
   self.crowdTarget=0
   self.phase='precard';self.phaseT=t;self.titleI=self.i+1;self.titleFrames=0
  end
 elseif ph=='end'then
  self.crowdTarget=0
  local d=M.T.finalWhite
  self.white=lerp(self.whiteFrom or 0,1,smooth((t-self.phaseT)/d))
  if t-self.phaseT>=d then self:finish();return end
 end
 -- TEST235: the Easter eggs (after the parade's own frame: its shot, where
 -- you are), and the march's level from them
 if self.eggs and not self.finished then
  self:eggsCall('update',dt,t)
  local _,duck=self:eggLevels()
  M.musicDuck=duck<1 and duck or nil
 elseif not self.eggs then M.musicDuck=nil end
 -- the hour moves through each stop (late afternoon going gold; sunset)
 -- (TEST235: not while a gag holds the stop's finale or its end -- the light
 -- at the finale is as it always was)
 local cur=self:stop()
 if cur and not self.finished then
  local shift=(self.todShift or 0)+(self.holdSince and(t-self.holdSince)or 0)
  local u=self.stopT0 and min(1,(t-self.stopT0-shift)/(cur.coda and 16 or 40))or 0
  M.tod=todOf(cur,u)
  -- (TEST235 ending: a gag may take the hour on -- at Pallet the sky goes
  -- down to dusk while Jigglypuff sings)
  if self.eggs then local td=self:eggsCall('tod',t,M.tod);if tonumber(td)then M.tod=td end end
 end
 -- the crowd's excitement: the float near you, everyone at the finale
 if self.street and not self.finished then
  local Pp=self.pSmooth
  local boost=self.phase=='finale'and 1 or(self.phase=='reveal'and .35 or 0)
  pcall(self.street.update,self.street,dt,t,Pp and{Pp[1],Pp[3]},boost)
 end
 -- the float, under you (it carries you once the place is on screen)
 if self.float and not self.finished then
  local ph2=self.phase
  local carrying=self.i>0 and ph2~='card'and ph2~='start'and ph2~='precard'
  local okF,err=pcall(self.float.update,self.float,dt,t,self.i,carrying)
  if not okF then log('the float failed: %s',tostring(err));pcall(self.float.release,self.float);self.float=nil end
 end
 -- the camera for this frame
 if not self.finished and self.phase~='start'then
  local okC,cam=pcall(self.shotCamera,self,t,dt)
  if okC and cam then self.cam=cam
  elseif not okC then log('the camera failed: %s',tostring(cam))end
 end
end

-- the cuts: each shot as you reach its point on the road
function Parade:direct(stop,t)
 if stop.coda or not stop.shots then return end
 local s=self.progress or 0
 local pick=nil
 for k,sh in ipairs(stop.shots)do
  if sh.at>=0 and s>=sh.at then pick=k end
 end
 if pick and pick~=self.shotI then
  self.shotI=pick
  local sh=stop.shots[pick]
  self:cutTo(sh,t)
  if sh.cannons then self:cannonsFire(stop,false)end
  if sh.swell and self:cheerOK()then playOnce(self.game,'crowd_swell',.5*(stop.crowdVol or .6),1.02)end
 end
 local sh=self.shot
 if sh and sh.swellAt and not self.fired[sh] and s>=sh.swellAt then
  self.fired[sh]=true
  if self:cheerOK()then playOnce(self.game,'crowd_swell',.6*(stop.crowdVol or .6),.98)end
 end
end

-- the paper in the air: ticker tape round you as you go (thickest where you
-- are heading), a little all along the street; Pallet's gentle fall
function Parade:stream(stop,dt,t,finale)
 local C=self.confetti;local L=confettiLib()
 if not(C and L)then return end
 local Pp=self.pSmooth
 if not Pp then return end
 local lite=self.lite==2 and .3 or(self.lite and .5 or 1)
 -- (TEST235: the ticker tape dies down while a gag has the crowd asleep)
 if self.eggs then local _,_,k=self:eggLevels();lite=lite*k end
 if self.tickerLines then
  local rate=(self.float and M.TICKER_RATE or M.TICKER_WALK)*lite*(finale and .6 or 1)
  -- (the main street runs west: the window reaches further that way)
  local win={x0=Pp[1]-120,x1=Pp[1]+70,z0=Pp[3]-120,z1=Pp[3]+120}
  C:ticker(dt,self.tickerLines,win,rate,L.TICKER,'near')
  C:ticker(dt,self.tickerLines,{x0=-1e9,x1=1e9,z0=-1e9,z1=1e9},M.DRIFT_RATE*lite,L.TICKER,'far')
 end
 if stop.rain then
  local want=(self.rainAcc or 0)+stop.rain*lite*dt
  local n=floor(want);self.rainAcc=want-n
  if n>0 then C:drop(Pp[1]-80,Pp[1]+80,Pp[3]-100,Pp[3]+50,55,90,n,L.CONFETTI,{over=dt})end
 end
end

-- the crowd under the music: a looping cheer, up while people are near
function Parade:updateCrowdSound(dt)
 local src=self.crowdSrc
 if src==nil then
  local base=sfx('crowd_loop')
  if base then
   local ok,v=pcall(base.clone,base)
   src=ok and v or false
   if src then pcall(src.setLooping,src,true);pcall(src.setVolume,src,0);pcall(src.play,src)end
  else src=false end
  self.crowdSrc=src
 end
 if not src then return end
 self.crowdVol=self.crowdVol or 0
 local target=(self.crowdTarget or 0)*.55
 -- (TEST235: the crowd falls quiet as it dozes; exactly as before once awake)
 if self.eggs then
  local cheer=self:eggLevels()
  if cheer<1 then target=target*cheer end
 end
 local k=1-math.exp(-(dt or 1/60)/.6)
 self.crowdVol=self.crowdVol+(target-self.crowdVol)*k
 pcall(src.setVolume,src,self.crowdVol*sfxGain(self.game))
end

function Parade:finish()
 M.profileClose(self)
 if self.finished then return end
 M.profileNote(self,('[ChampionParade] Run ended; completed shot records: %d'):format(#(self.shotProfiles or{})))
 M.profileFlush(self)
 self.finished=true
 local game=self.game
 pcall(function()V.require('ParadeCast').LOD_LITE=0 end)   -- (TEST242)
 -- off the float first (its riders let go, you back on your feet), so
 -- nothing below can leave you lifted
 if self.float then pcall(self.float.release,self.float)end
 -- TEST235: the Easter eggs let go (their models, the song, everyone upright)
 if self.eggs then local e=self.eggs;self.eggs=nil;pcall(e.release,e)end
 M.musicDuck=nil
 pcall(function()V.require('ParadeCast').clearPoses()end)
 local stop=self:stop()
 if stop then pcall(self.quietCrowd,self,stop)end
 pcall(self.restoreRoad,self)
 pcall(self.removeCrowd,self)
 pcall(self.releaseStopFx,self)
 M.tod=nil
 M.walking=false
 warmReset()
 pcall(function()V.require('LeagueFireworksAudio').extraLive=false end)
 if self.crowdSrc then pcall(self.crowdSrc.stop,self.crowdSrc);pcall(self.crowdSrc.release,self.crowdSrc)end
 self.crowdSrc=false
 if self.card then
  self.card.isOpaque=nil
  pcall(function()if game.stack:top()==self.card then game.stack:pop()end end)
  self.card=nil
 end
 pcall(function()local R=V.require('Voxel3D');if lastRig and R.camera==lastRig then R.camera=nil end end)
 lastRig=nil
 self.cam=nil
 if self.shotLog then log('the cameras: %s%s',self.shotLog,self.lite and' (LITE)'or'')end
 -- the white stays a moment over what comes next, then lifts
 M.hudOut={t0=now()}
 if P==self then P=nil end
 local onDone=self.onDone
 self.onDone=nil
 if onDone then onDone()end
end

------------------------------------------------------------------ the world pass
function M.drawLate(state)
 local s=P
 if not s or s.finished or s.phase=='card'or s.phase=='start'or s.phase=='precard'then return end
 local map=state and state.map
 if not(map and tostring(map.id)==s.mapId)then return end
 local okR,Road=pcall(V.require,'LeagueRoad')
 local K=okR and Road and Road.fxKit and Road.fxKit()or nil
 local R=V.require('Voxel3D')
 local g=love.graphics
 local t=now()
 local stop=s:stop()
 local light=lightAt(M.tod or 300)
 -- One bounded crowd batch, depth-tested before float, confetti and gags.
 pcall(function()
  local Cards=V.require('ParadeCrowdCards')
  local okT,T=pcall(V.require,'LoadTimings')
  if okT and T and T.call then T.call('actor_draw',Cards.flush,R,M)
  else Cards.flush(R,M)end
 end)
 -- the float, first of the late pass (solid, so what follows is depth-tested
 -- against it); lights after dark
 if s.float then
  local night=1-max(0,min(1,(light-.42)/.4))
  local okF,err=pcall(s.float.draw,s.float,K,t,night)
  if not okF then log('drawing the float failed: %s',tostring(err))end
 end
 -- the street's dressing and its crowd
 if s.street then
  local okS,err=pcall(s.street.draw,s.street,K,t)
  if not okS then log('drawing the street failed: %s',tostring(err));pcall(s.street.release,s.street);s.street=nil end
 end
 -- a banner across the road on two gold poles (Pallet's)
 local b=stop and stop.banner
 if b and b.canvas then
  if R.seams then pcall(R.seams,false)end
  pcall(function()
   local BB=V.require('BattleBillboard')
   local x0,x1=b.x0*16,b.x1*16
   local z=b.y*16+8
   local gy=groundAt(map,floor((b.x0+b.x1)/2),b.y)
   local w=x1-x0
   local bottom=b.bottom+(s.float and 8 or 0)
   g.setColor(1,1,1,1)
   R.draw(BB.mesh(),b.canvas,BB.matrix((x0+x1)/2,gy+bottom,z,w,b.h,0))
   if K and K.white and K.panel then
    g.setColor(.95,.74,.30,1)
    for _,x in ipairs({x0,x1})do
     R.draw(BB.mesh(),K.white,BB.matrix(x,gy,z+.6,2.2,bottom+b.h+4,0))
     R.draw(BB.mesh(),K.white,BB.matrix(x,gy,z-.6,2.2,bottom+b.h+4,pi/2))
    end
   end
  end)
  if R.seams then pcall(R.seams,true)end
  g.setColor(1,1,1,1)
 end
 -- the confetti (solid, after everything it can land on or fall behind)
 if s.confetti then
  local tint={light,light*.97,light*.90}
  local okC,err=pcall(s.confetti.draw,s.confetti,R,K,tint)
  if not okC then log('drawing the confetti failed: %s',tostring(err))end
 end
 -- TEST235: the Easter eggs (their Pokemon, then notes, Zz and spray over
 -- everything), and whatever is drawn at people's heads
 if s.eggs then s:eggsCall('draw',K,t)end
 local okPC,PCm=pcall(V.require,'ParadeCast')
 if okPC and type(PCm)=='table'and PCm.drawHeads then pcall(PCm.drawHeads,s.game,K,t)end
 -- fireworks fired on a map that has no show of its own
 local id=tostring(map.id)
 if id~='INDIGO_PLATEAU'and id~='ROUTE_23'and K and K.fireworks then
  pcall(R.withEffect,'add',function()
   pcall(K.fireworks,g,K.soft,nil,t,1,1,R.eye,id)
  end)
 end
 g.setColor(1,1,1,1)
end

------------------------------------------------------------------ the HUD
-- a caption low on the left: a gold bar, the big line, the small line
-- (sizes go by S, the height or, on a narrow screen, what its width allows)
local function hudSize(W,H)return min(H,W/1.6)end
M.hudSize=hudSize
local function lowerThird(g,W,H,big,small,k,S)
 if k<=0 then return end
 S=S or hudSize(W,H)
 local fB=titleFont(S*.058)
 local fS=labelFont(S*.024)
 local x=W*.055
 local y=H*.74
 local slide=(1-smooth(k*1.6))*W*.06
 local wB=fB and fB:getWidth(big)or 0
 local wS=fS and spacedWidth(fS,small,S*.006)or 0
 local w=max(wB,wS)+S*.07
 local h=(fB and fB:getHeight()or 0)+(fS and fS:getHeight()or 0)+S*.03
 g.setColor(.36,.04,.06,.86*k)
 g.rectangle('fill',x-slide,y,w,h)
 g.setColor(.98,.78,.30,k)
 g.rectangle('fill',x-slide,y,max(3,S*.008),h)
 g.rectangle('fill',x-slide,y+h,w*smooth(k*1.3),max(2,S*.004))
 if fB then
  g.setFont(fB)
  g.setColor(0,0,0,.45*k);g.print(big,x-slide+S*.034+2,y+S*.008+2)
  g.setColor(1,.98,.94,k);g.print(big,x-slide+S*.034,y+S*.008)
 end
 if fS then
  g.setFont(fS);g.setColor(.98,.80,.36,k)
  printSpaced(g,fS,small,x-slide+S*.036,y+S*.012+(fB and fB:getHeight()or 0),S*.006)
 end
end
-- the LIVE bug, top left, and where the parade is
local function liveBug(g,W,H,t,place,k,S)
 if k<=0 then return end
 S=S or hudSize(W,H)
 local f=labelFont(S*.026)
 if not f then return end
 g.setFont(f)
 local x,y=W*.035,H*.05
 local pad=S*.012
 local word='LIVE'
 local dot=S*.011
 local w1=f:getWidth(word)+dot*2+pad*3
 local h=f:getHeight()+pad*1.2
 g.setColor(.82,.07,.10,.92*k)
 g.rectangle('fill',x,y,w1,h,h*.18,h*.18)
 local on=(t%1)<.62
 g.setColor(1,1,1,(on and 1 or .35)*k)
 g.circle('fill',x+pad+dot,y+h/2,dot)
 g.setColor(1,1,1,k)
 g.print(word,x+pad*2+dot*2,y+pad*.6)
 if place then
  local w2=spacedWidth(f,place,S*.004)+pad*2
  g.setColor(0,0,0,.45*k)
  g.rectangle('fill',x+w1+S*.006,y,w2,h,h*.18,h*.18)
  g.setColor(1,1,1,.95*k)
  printSpaced(g,f,place,x+w1+S*.006+pad,y+pad*.6,S*.004)
 end
end
M.lowerThird,M.liveBug=lowerThird,liveBug
-- TEST251: the recording itself carries the diagnostics if Android hides the
-- save folder. Cached lines, refreshed twice a second; no timing snapshot
-- or filesystem access in the HUD. Completed-shot CPU values are labelled LAST.
function M.profileHudLines(self,t)
 if not profileScreen()or not M.SHOT_PROFILE or not self then return nil end
 local old=self.profileHud
 if old and t>=old.at and t-old.at<.5 then return old.lines end
 local p=self.shotProfile
 local rows=self.shotProfiles or{}
 local last=rows[#rows]
 local fps=p and p.frames>1 and p.last>p.start and(p.frames-1)/(p.last-p.start)or nil
 local short=function(x,n)return profileClean(x):sub(1,n or 25)end
 local lines={('%s | %s | %s FPS | LITE %d'):format(M.PROFILE_BUILD,
  short(p and p.shot or self.phase),fps and('%.1f'):format(fps)or'--',tonumber(self.lite)or 0)}
 if last then
  lines[2]=('LAST %s | %.1f FPS | gap %.0f ms | L%d-%d'):format(
   short(last.shot),last.cadence,last.maxGapMs,last.liteStart,last.liteEnd)
  if last.timed then
   lines[3]=('CPU ms: actors %.2f | actor shadows %.2f'):format(last.actorsMs,last.shadowActorsMs)
   lines[4]=('World %.2f | mesh %.2f | prepare %.2f / draw %.2f'):format(
    last.worldMs,last.meshWriteMs,last.actorPrepareMs or 0,last.actorDrawMs or 0)
  else
   lines[3]='CPU timings unavailable'
   lines[4]='FPS is world-frame cadence; no GPU timer'
  end
  lines[5]=last.crowdShadowCounted and('LAST crowd shadows: %.1f allowed / %.1f skipped per frame'):format(
   last.crowdShadowKept,last.crowdShadowSkipped)or'Crowd shadow counts unavailable'
  if last.poseCounted then
   lines[5]=('Shadows %.1f kept / %.1f skipped | poses %.1f (%.1f forced)'):format(
    last.crowdShadowKept or 0,last.crowdShadowSkipped or 0,last.pose_refreshed,last.pose_forced)
  end
 else
  lines[2]='Measuring the first camera shot...'
  lines[3]='LAST shows the completed shot at each cut'
  lines[4]='CPU timings in ms; no GPU timer'
  lines[5]=M.CROWD_SHADOW_DISTANCE and'Celadon: far crowd shadows omitted'or'Crowd shadow distance filter off'
 end
 local r=self.profileReport
 lines[6]=('Collection %s | %s'):format(short(r and r.collection or'unknown',30),r and r.status or'screen only')
 lines[7]=last and last.crowdCardsCounted and('Crowd cards %.0f + %.0f reflected | draws %.1f%s'):format(
  last.crowdCards or 0,last.crowdReflected or 0,last.crowdBatches or 0,(last.cardFailures or 0)>0 and' | FALLBACK'or'')
  or'Distant crowd: original trainer art, shared batch'
 -- While birds sleep, report actual eye-override coverage in the recording.
 -- Zero means unsupported artwork, not a successful eye fix.
 local ok,sleep=pcall(function()return V.require('ParadePartnerSleep').status()end)
 if ok and sleep.birds>0 then
  lines[7]=('Sleeping birds %d | closed-eye models %d/%d'):format(sleep.birds,sleep.birdEyes,sleep.birds)
 end
 self.profileHud={at=t,lines=lines}
 return lines
end
function M.drawProfileHud(self,g,W,H,S,t)
 local lines=M.profileHudLines(self,t)
 if not lines then return end
 local f=labelFont(S*.022)or(g.getFont and g.getFont())
 if not f then return end
 local width=0
 for _,line in ipairs(lines)do width=max(width,f:getWidth(line))end
 local pad=max(3,S*.009)
 local scale=min(1,max(1,W*.62-pad*2)/max(1,width))
 local step=f:getHeight()*1.18*scale
 local bw,bh=width*scale+pad*2,step*#lines+pad*2
 local x,y=W-W*.025-bw,H*.045
 g.setColor(.025,.035,.05,.84);g.rectangle('fill',x,y,bw,bh,pad,pad)
 g.setFont(f)
 for i,line in ipairs(lines)do
  if i==1 then g.setColor(1,.85,.35,1)else g.setColor(.95,.97,1,1)end
  g.print(line,x+pad,y+pad+(i-1)*step,0,scale,scale)
 end
end
function M.drawHud()
 local g=love.graphics
 local W,H=g.getDimensions()
 local S=hudSize(W,H)
 local t=now()
 g.origin();g.setShader();g.setScissor();pcall(g.setDepthMode);g.setBlendMode('alpha')
 -- after the parade: the white lifts off the credits
 if M.hudOut and not P then
  local a=1-smooth((t-M.hudOut.t0)/M.T.hudOut)
  if a<=0 then M.hudOut=nil else g.setColor(1,1,1,a);g.rectangle('fill',0,0,W,H)end
  g.setColor(1,1,1,1)
  return
 end
 local s=P
 if not s or s.finished then return end
 local stop=s:stop()
 -- the broadcast's dressing under the white: the LIVE bug, the captions
 local filming=s.phase=='reveal'or s.phase=='show'or s.phase=='finale'or s.phase=='outro'or s.phase=='end'
 if stop and filming and s.revealT then
  local bugK=smooth((t-s.revealT-.2)/.5)*(1-s.white)
  liveBug(g,W,H,t,stop.place,bugK,S)
  s.lowerSeen=s.lowerSeen or{}
  for li,lt in ipairs(stop.lowers or{})do
   local start=nil
   local key=s.i*100+li
   if lt.from=='reveal'then start=s.revealT+lt.at
   elseif lt.from=='progress'then
    if not s.lowerSeen[key]and(s.progress or 0)>=lt.at and s.phase=='show'then s.lowerSeen[key]=t end
    start=s.lowerSeen[key]
   end
   if start then
    local a=t-start
    local k=smooth(a/.45)*(1-smooth((a-lt.dur)/.45))
    if k>0 then
     local big=lt.big=='$NAME'and s.name or lt.big
     lowerThird(g,W,H,big,lt.small,k*(1-s.white),S)
    end
   end
  end
 end
 if s.white>0 then
  g.setColor(1,1,1,s.white);g.rectangle('fill',0,0,W,H)
 end
 -- TEST228: while the card waits, it is alive: confetti down the white, the
 -- LIVE dot, and a gold bar running under the title
 if s.white>.5 and(s.phase=='start'or s.phase=='precard'or s.phase=='card')then
  pcall(M.drawWaiting,g,W,H,t,S,s.white,s)
 end
 -- the title card on the white: the parade's name and where it is, from the
 -- start until the picture comes up (the homecoming has none)
 local ti,a=nil,0
 if s.phase=='start'then ti,a=1,smooth((t-s.t0)/.3)
 elseif s.phase=='precard'then ti,a=s.titleI or s.i+1,1
 elseif s.phase=='card'then ti,a=s.i,1
 elseif s.phase=='reveal'then ti,a=s.i,1-smooth((t-s.phaseT)/(M.T.reveal*.7))end
 local tstop=ti and s.stops[ti]
 if tstop and tstop.coda then tstop=nil end
 if tstop and a>0 then
  if(s.phase=='start'or s.phase=='precard')and a>=1 then s.titleFrames=(s.titleFrames or 0)+1 end
  local gold={.80,.60,.20}
  local cy=H*.58
  local fH=titleFont(S*.085)
  local fS=labelFont(S*.026)
  if fS then
   g.setFont(fS);g.setColor(gold[1],gold[2],gold[3],a)
   local msg='A HALL OF FAME CELEBRATION'
   printSpaced(g,fS,msg,(W-spacedWidth(fS,msg,S*.008))/2,H*.20,S*.008)
  end
  if fH then
   g.setFont(fH);g.setColor(.45,.06,.08,a)
   local msg="THE CHAMPION'S PARADE"
   g.print(msg,(W-fH:getWidth(msg))/2,H*.25)
  end
  local fL=labelFont(S*.03)
  local fT=titleFont(S*.065)
  if fL then
   g.setFont(fL);g.setColor(gold[1],gold[2],gold[3],a)
   printSpaced(g,fL,tstop.label,(W-spacedWidth(fL,tstop.label,S*.01))/2,cy-S*.075,S*.01)
  end
  if fT then
   g.setFont(fT);g.setColor(.16,.12,.12,a)
   local tw=fT:getWidth(tstop.title)
   g.print(tstop.title,(W-tw)/2,cy-S*.02)
   g.setColor(gold[1],gold[2],gold[3],a)
   g.rectangle('fill',(W-tw)/2,cy-S*.02+fT:getHeight()+S*.012,tw,max(2,S*.004))
  end
 end
 -- the skip hint
 if t<s.hintUntil then
  local f=labelFont(S*.024)
  if f then
   g.setFont(f)
   local msg='HOLD A TO SKIP'
   local fw=f:getWidth(msg)
   local p=s.held>0 and min(1,s.held/M.T.skipHold)or 0
   local bx,by=W-fw-S*.06,H*.90
   g.setColor(0,0,0,.5);g.rectangle('fill',bx,by,fw+S*.04,f:getHeight()+S*.02,6,6)
   g.setColor(1,1,1,.92);g.print(msg,W-fw-S*.04,by+S*.01)
   if p>0 then g.setColor(1,.85,.35,.95);g.rectangle('fill',bx,by+f:getHeight()+S*.02-3,(fw+S*.04)*p,3)end
  end
 end
 if filming and s.white<.5 then pcall(M.drawProfileHud,s,g,W,H,S,t)end
 g.setColor(1,1,1,1)
end

-- TEST228: the waiting card's life (2D, over the white; cheap: sixty little
-- quads and a bar). The pieces fall from where a hash puts them, so nothing
-- is kept between frames.
local WAIT_COLORS={{.86,.16,.18},{.95,.74,.20},{.20,.42,.86},{.30,.68,.36},{.66,.42,1}}
function M.drawWaiting(g,W,H,t,S,white,s)
 local a=min(1,white)
 local n=60
 for i=1,n do
  local h1=(sin(i*12.9898)*43758.5453)%1
  local h2=(sin(i*78.233)*12345.678)%1
  local h3=(sin(i*39.425)*24680.135)%1
  local fall=H*(.10+.10*h2)
  local y=((t*fall/H+h1)%1)*(H*1.1)-H*.05
  local x=W*h3+sin(t*(.8+h2)+i)*S*.02
  local c=WAIT_COLORS[(i%#WAIT_COLORS)+1]
  local w,h=S*(.008+.006*h2),S*(.014+.008*h1)
  local spin=t*(1.5+3*h1)+i
  g.push()
  g.translate(x,y)
  g.rotate(spin)
  g.scale(1,.35+.65*abs(sin(spin*1.7)))
  g.setColor(c[1],c[2],c[3],.85*a)
  g.rectangle('fill',-w/2,-h/2,w,h)
  g.pop()
 end
 -- the LIVE dot, top left, pulsing
 local f=labelFont(S*.024)
 if f then
  g.setFont(f)
  local pulse=.55+.45*sin(t*5)
  local x,y=S*.05,H*.06
  g.setColor(.85,.10,.12,a*pulse);g.circle('fill',x,y+f:getHeight()/2,S*.009)
  g.setColor(.45,.06,.08,a);g.print('LIVE',x+S*.02,y)
 end
 -- the gold bar under the title (TEST230: it fills as the place is made
 -- ready, a light running along what is done; the words under it say
 -- what it is waiting for)
 local bw=min(W*.36,S*.5)
 local bx,by=(W-bw)/2,H*.80
 local bh=max(2,S*.004)
 local shown=s and s.cardShown
 g.setColor(.80,.60,.20,.25*a);g.rectangle('fill',bx,by,bw,bh)
 if shown then
  local fw=bw*max(0,min(1,shown))
  g.setColor(.80,.60,.20,.9*a);g.rectangle('fill',bx,by,fw,bh)
  local run=(t*.55)%1.3-.15
  local x0=bx+fw*max(0,run);local x1=bx+fw*min(1,run+.18)
  if x1>x0 then g.setColor(1,.92,.62,.85*a);g.rectangle('fill',x0,by,x1-x0,bh)end
  local fw2=labelFont(S*.020)
  if fw2 and s.cardWhat then
   g.setFont(fw2);g.setColor(.62,.46,.18,.85*a)
   local msg=tostring(s.cardWhat)
   printSpaced(g,fw2,msg,(W-spacedWidth(fw2,msg,S*.005))/2,by+bh+S*.016,S*.005)
  end
 else
  local run=(t*.55)%1.4-.2
  local x0=bx+bw*max(0,run);local x1=bx+bw*min(1,run+.25)
  if x1>x0 then g.setColor(.80,.60,.20,.9*a);g.rectangle('fill',x0,by,x1-x0,bh)end
 end
end

------------------------------------------------------------------ the hooks
local function canRun(game,only)
 local ok,yes=pcall(function()
  local R=V.require('Voxel3D')
  if not(R.available and R.available())then return false end
  local okS,Voxel=pcall(V.require,'VoxelState')
  if okS and Voxel and Voxel.active and not Voxel.active()then return false end
  local ow=overworld(game)
  if not(ow and ow.map and ow.setMap and ow.scriptMove and ow.player)then return false end
  local found=only==nil
  for _,stop in ipairs(M.STOPS)do
   if only==nil or stop.map==only then
    found=true
    if not(game.data.maps and game.data.maps[stop.map])then return false end
   end
  end
  return found
 end)
 return ok and yes or false
end
M.canRun=canRun

-- `pending` ties Oak's announcement to a Hall of Fame that leads here.
-- TEST264: old callers may still send "walk" or ride=false; both ride now.
M.pending=false
M.ride=nil
function M.rideOffered(game)
 return M.pending==true and P==nil and canRun(game)and true or false
end
function M.choose(mode)
 M.ride='float'
 log('the Champion will ride the float')
end
function M.play(game,after,options)
 if P then return false end
 if not canRun(game,options and options.only)then return false end
 M.ride=nil;M.pending=false
 P=Parade.new(game,after,options)
 if not P then warmReset();return false end
 M.walking=true
 pcall(function()V.require('LeagueFireworksAudio').extraLive=true end)
 return true
end
function M.active()return P~=nil end
-- TEST230: the places where the parade's first stop starts building:
-- the Champion's room once he is beaten in this run, and the Hall of
-- Fame's room. "Beaten in this run": the engine's run flag (set as the
-- battle is won, cleared in the Indigo Plateau lobby for a rematch); on an
-- engine without it, the lasting flag going up while you are in the room
-- (on a rematch it was already up as you came in: that waits for the Hall
-- of Fame)
M.EARLY_WARM={CHAMPIONS_ROOM={run='EVENT_BEAT_CHAMPION_RIVAL_THIS_RUN',ever='EVENT_BEAT_CHAMPION_RIVAL'},HALL_OF_FAME=true}
function M.earlyWarm(game)
 local ow=overworld(game)
 local id=ow and ow.map and tostring(ow.map.id)
 local need=id and M.EARLY_WARM[id]
 local flags=game and game.save and game.save.flags
 -- (as you come into a room: was he already beaten, from before?)
 if id~=M.earlyRoom then
  M.earlyRoom=id
  M.earlyBefore=type(need)=='table'and type(flags)=='table'and flags[need.ever]and true or false
 end
 if not need then M.earlyWarmed=nil;return false end
 if M.earlyWarmed==id then return false end
 if type(need)=='table'then
  if type(flags)~='table'then return false end
  if not(flags[need.run]or(flags[need.ever]and not M.earlyBefore))then return false end
 end
 -- (TEST231: a parade on, or the road already building: this room has had
 -- its start -- and a parade that ends while you are still in it does not
 -- start it all again)
 if P or Warm.active then M.earlyWarmed=id;return false end
 if not canRun(game)then return false end
 M.earlyWarmed=id
 pcall(M.warmFor,game,1,true)
 log('the parade starts building ahead in the %s',id)
 return Warm.active
end
M._parade=function()return P end
-- TEST228: the white card is up (nothing of the world shows)
function M.covered()
 local s=P
 return s~=nil and not s.finished and(s.phase=='start'or s.phase=='precard'or s.phase=='card')
end

local HoF,origNew=nil,nil
local FP,origFrame=nil,nil
local DN,origTime=nil,nil
local CMod,origSetLive,origPump=nil,nil,nil
local RDmod,origNeighbor=nil,nil
local CullV3,origCulled=nil,nil   -- TEST242: Voxel3D.drawCulled, wrapped by ParadeCull
local VP,origPre=nil,nil
local DL,origDrawLate=nil,nil
local WF,origRoaming,wrappedRoaming=nil,nil,nil
local removers={}
-- TEST235: the march's multiplier while a gag sings (nil: as ever)
M.musicDuck=nil
function M.install(mod)
 if origNew then return end
 modRef=mod
 V.require('ParadeCast').install(mod)
 pcall(function()V.require('ParadeCrowdCards').install(V.require('Voxel3D'),M)end)
 local ok,mod_=pcall(require,'src.ui.HallOfFame')
 if not(ok and type(mod_)=='table'and type(mod_.new)=='function')then return end
 -- the music: the march (an intro, then a body that loops) and the homecoming
 pcall(function()
  local base=(mod.path or V.path or'mods/BATTLE_ART_VOXEL_FORK')..'/'..M.ASSETS
  mod.content.music:register('Music_ChampionParade',{file=base..'march_intro.ogg',loopFile=base..'march_loop.ogg'})
  mod.content.music:register('Music_ChampionParadeHome',{file=base..'march_home.ogg'})
 end)
 -- the float (and its hold on the trainer model's idle while it rides)
 pcall(function()V.require('ParadeFloat').install(mod)end)
 HoF,origNew=mod_,mod_.new
 HoF.new=function(game,onDone,...)
  local wrapped=onDone
  if type(onDone)=='function'then
   -- the parade's first stop starts building now, under the ceremony (its
   -- first stop is the same place walking or riding)
   if not P and canRun(game)then pcall(M.warmFor,game,1,true)end
   -- a new ceremony: Professor Oak has not asked yet
   M.pending=true;M.ride=nil
   local called=false
   wrapped=function(...)
    if called then return end
    called=true
    M.pending=false
    local args={n=select("#",...),...}
    local started=false
    pcall(function()started=M.play(game,function()onDone(unpack(args,1,args.n))end)end)
    if not started then warmReset();return onDone(...)end
   end
  end
  return origNew(game,wrapped,...)
 end
 -- the camera. (The scene's centre -- the sun's box for the shadows, the
 -- curve's focus -- goes toward where the camera looks, so the wide shots
 -- have their shadows where they are looking.)
 local okF,FirstPerson=pcall(V.require,'FirstPerson')
 if okF and FirstPerson and type(FirstPerson.frame)=='function'then
  FP,origFrame=FirstPerson,FirstPerson.frame
  FirstPerson.frame=function(...)
   -- (TEST228: once a frame, before any of its people are drawn)
   M.frameSerial=(M.frameSerial or 0)+1
   local r1,r2,r3=origFrame(...)
   local R=V.require('Voxel3D')
   local rig=M.rig()
   if rig then
    M.profileFrame(P)
    R.camera=rig;lastRig=rig
    local Pp=P and P.pSmooth
    local fx,fz=rig.focus[1],rig.focus[3]
    if Pp then
     local dx,dz=fx-Pp[1],fz-Pp[3]
     local d=sqrt(dx*dx+dz*dz)
     local k=d>140 and 140/d or 1
     return rig,Pp[1]+dx*k*.7,Pp[3]+dz*k*.7
    end
    return rig,fx,fz
   end
   if lastRig and R.camera==lastRig then R.camera=nil end
   lastRig=nil
   return r1,r2,r3
  end
 end
 -- the hour
 local okD,DayNight=pcall(V.require,'DayNight')
 if okD and DayNight and type(DayNight.time)=='function'then
  DN,origTime=DayNight,DayNight.time
  DayNight.time=function(...)
   if P and M.tod then return M.tod end
   return origTime(...)
  end
 end
 -- building ahead: keep the road's maps out of the live-set eviction; keep
 -- their builds to an ordinary slice while you are watching something else
 -- (the Hall of Fame) -- behind the parade's own white card they may take
 -- the covered one; and leave the door precacher be while the parade runs
 local okM,CM=pcall(V.require,'ChunkMesher')
 if okM and CM and type(CM.setLive)=='function'and type(CM.pump)=='function'then
  CMod,origSetLive,origPump=CM,CM.setLive,CM.pump
  CM.setLive=function(live,keepPrevious,...)
   if Warm.active and type(live)=='table'then
    local merged={}
    for k,v in pairs(live)do merged[k]=v end
    for id in pairs(Warm.keep)do merged[id]=true end
    return origSetLive(merged,keepPrevious,...)
   end
   return origSetLive(live,keepPrevious,...)
  end
  CM.pump=function(covered,...)
   if Warm.active and covered==true and not(P and P.phase=='card')then covered=false end
   return origPump(covered,...)
  end
 end
 -- while the parade films, a connected map that has not finished building is
 -- left out of view range (and asked for), rather than the renderer holding
 -- the picture still until it lands; it joins the moment it is built
 local okD2,RDm=pcall(V.require,'RenderDistance')
 if okD2 and RDm and type(RDm.neighbor)=='function'then
  RDmod,origNeighbor=RDm,RDm.neighbor
  RDm.neighbor=function(nb,player,...)
   -- (TEST242: none round a place the parade keeps inside; any doubt, as before)
   if P and M.INSIDE_ONLY then
    local okI,inside=pcall(M.insideOnly,P)
    if okI and inside then
     local okD,drop=pcall(function()
      local stop=P.stops and P.stops[P.i]
      return M.insideDrops(stop and stop.map,type(nb)=='table'and type(nb.map)=='table'and nb.map.id or nil)
     end)
     if okD and drop then return false end
    end
   end
   local near=origNeighbor(nb,player,...)
   if near and P and FILMING[P.phase]and type(nb)=='table'and nb.map then
    local okC,CM2=pcall(V.require,'ChunkMesher')
    if okC and CM2 and CM2.pair and CM2.pair(nb.map,true)==nil and CM2.pair(nb.map,false)==nil
       and not CM2.slotKnown(nb.map,true)then
     pcall(CM2.request,nb.map,true,nil,'visible')
     return false
    end
   end
   return near
  end
 end
 -- TEST242: while the parade films, only what the camera sees of the map is
 -- drawn, even under a Collection whose draw wrapper drops the visible runs
 -- (ParadeCull; any error and it steps aside for good)
 if M.RESTORE_CULL then
  local okV3,V3=pcall(V.require,'Voxel3D')
  local okPC,PCull=pcall(V.require,'ParadeCull')
  if okV3 and okPC and type(V3)=='table'and type(PCull)=='table'and type(V3.drawCulled)=='function'
     and type(PCull.wrap)=='function'and not CullV3 then
   CullV3,origCulled=V3,V3.drawCulled
   local okW,wrapped=pcall(PCull.wrap,V3,origCulled,function()return P~=nil and not P.finished end)
   if okW and type(wrapped)=='function'then V3.drawCulled=wrapped else CullV3,origCulled=nil,nil end
  end
 end
 local okP,Pre=pcall(V.require,'VoxelPrecache')
 if okP and Pre and type(Pre.update)=='function'then
  VP,origPre=Pre,Pre.update
  Pre.update=function(...)
   if P then return end
   return origPre(...)
  end
 end
 -- TEST235: someone the Collection draws as a Stadium model (your partner at
 -- your heels) is tipped, when the parade poses them, through the matrix
 -- it prepared this frame -- right after the water's footing has had it
 local okW,WFm=pcall(V.require,'WaterFooting')
 if okW and type(WFm)=='table'and type(WFm.roaming)=='function'then
  WF,origRoaming=WFm,WFm.roaming
  wrappedRoaming=function(posed,state,...)
   local r1,r2=origRoaming(posed,state,...)
   if P then
    if P.eggs and P.eggs.posePokemon then pcall(P.eggs.posePokemon,P.eggs,posed,state)end
    local okC,CPm=pcall(V.require,'ParadeCast')
    if okC and type(CPm)=='table'and CPm.poseStadium then pcall(CPm.poseStadium,posed)end
   end
   return r1,r2
  end
  WFm.roaming=wrappedRoaming
 end
 -- the late world pass
 local okL,DockLights=pcall(V.require,'DockLights')
 if okL and DockLights and type(DockLights.drawLate)=='function'then
  DL,origDrawLate=DockLights,DockLights.drawLate
  DockLights.drawLate=function(state,...)
   local r1,r2=origDrawLate(state,...)
   if P then pcall(M.drawLate,state)end
   return r1,r2
  end
 end
 if mod and mod.hooks and mod.hooks.wrap then
  removers[#removers+1]=mod.hooks:wrap('core.update',function(nxt,game,dt)
   -- A reset during Oak's question also stops pre-parade warming.
   if not overworldUp(game)then
    M.pending=false;M.ride=nil;warmReset()
   end
   if P and not overworldUp(game)then
    log('the overworld was closed under the parade (a reset?): stopping')
    pcall(P.abort,P)
    P=nil
   end
   if P then
    local okU,err=pcall(P.update,P,dt)
    if not okU then log('update failed: %s',tostring(err));pcall(P.finish,P)end
   end
   -- TEST230: and from beating the Champion on, not only the ceremony
   pcall(M.earlyWarm,game)
   -- the road ahead builds under the Hall of Fame and through the parade
   -- (never left on if the parade did not follow)
   if Warm.active then
    if not P and now()-Warm.t0>240 then warmReset()else pcall(M.warmPump,game)end
   end
   return nxt(game,dt)
  end)
  removers[#removers+1]=mod.hooks:wrap('movement.speed',function(nxt,frames,ctx)
   local f=nxt(frames,ctx)
   if P and M.walking and ctx and ctx.player and not ctx.onBike then
    return max(1,floor((tonumber(f)or 16)*(P.float and M.FLOAT_STEP or M.STEP_SCALE)+.5))
   end
   return f
  end)
  removers[#removers+1]=mod.hooks:wrap('render.hud',function(nxt,game,viewport)
   local a,b,c=nxt(game,viewport)
   if P or M.hudOut then love.graphics.push('all');pcall(M.drawHud);love.graphics.pop()end
   return a,b,c
  end)
  -- TEST235: the march steps back while Jigglypuff sings (the engine's
  -- Music.update applies this every frame while it is subscribed); with no
  -- gag singing it hands the volume on untouched
  removers[#removers+1]=mod.hooks:wrap('music.volume',function(nxt,vol,ctx)
   local v=nxt(vol,ctx)
   local d=M.musicDuck
   if P and d and d<1 and tonumber(v)then return v*max(0,d)end
   return v
  end)
 end
end
function M.dispose()
 if P then pcall(P.finish,P)end
 P=nil
 M.pending=false;M.ride=nil
 pcall(function()V.require('ParadeFloat').dispose()end)
 pcall(function()V.require('ParadeConfetti').dispose()end)
 pcall(function()V.require('ParadeStreet').dispose()end)
 pcall(function()V.require('ParadeCast').dispose()end)
 pcall(function()V.require('ParadeCrowdCards').dispose()end)
 PC=nil
 if HoF and origNew then HoF.new=origNew end
 if FP and origFrame then FP.frame=origFrame end
 if DN and origTime then DN.time=origTime end
 if CMod and origSetLive then CMod.setLive=origSetLive end
 if CMod and origPump then CMod.pump=origPump end
 if VP and origPre then VP.update=origPre end
 if RDmod and origNeighbor then RDmod.neighbor=origNeighbor end
 RDmod,origNeighbor=nil,nil
 if CullV3 and origCulled then CullV3.drawCulled=origCulled end
 CullV3,origCulled=nil,nil
 -- (TEST235: put back only if nobody has wrapped it since)
 if WF and origRoaming and WF.roaming==wrappedRoaming then WF.roaming=origRoaming end
 WF,origRoaming,wrappedRoaming=nil,nil,nil
 M.musicDuck=nil
 pcall(function()V.require('ParadeEggs').dispose()end)
 CMod,origSetLive,origPump,VP,origPre=nil,nil,nil,nil,nil
 warmReset()
 if DL and origDrawLate then DL.drawLate=origDrawLate end
 HoF,origNew,FP,origFrame,DN,origTime,DL,origDrawLate=nil,nil,nil,nil,nil,nil,nil,nil
 for _,r in ipairs(removers)do pcall(r)end
 removers={}
 for _,v in ipairs(voices)do pcall(v.stop,v);pcall(v.release,v)end
 voices={}
 for _,src in pairs(SFX)do if src then pcall(src.release,src)end end
 SFX={}
 for _,stop in ipairs(M.STOPS)do
  if stop.banner and stop.banner.canvas then pcall(stop.banner.canvas.release,stop.banner.canvas)end
  if stop.banner then stop.banner.canvas=nil end
 end
 dropFonts()
 M.hudOut=nil
 modRef=nil
end
return M
