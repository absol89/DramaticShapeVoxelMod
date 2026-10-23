-- TEST235 ENDING: JIGGLYPUFF'S ENCORE AT PALLET TOWN.
--
-- The game's ending. After the fireworks of the homecoming at Pallet Town,
-- the Jigglypuff that tried its song in Celadon's plaza (and was woken by
-- the cannons there) has followed the parade home. It bounces in through the
-- grass gate, hops up -- onto the giant Poke Ball on the float's front tier
-- when you rode, onto the roof of the PALLET TOWN sign when you walked --
-- takes out its microphone and sings Joseph's own long song, all of it
-- (assets/parade/jigglypuff_song_long.mp3, with a louder mastered level). The sun goes
-- down while everyone falls asleep, a few with each verse: the townsfolk
-- first, then your rival, Professor Oak and your Mom, then your partner, and
-- you last of all (you fight it: two nods, a sway, then over you go). Nobody
-- falls on anybody: each person turns their back to a clear stretch of
-- ground and topples over backwards onto it, face up (or, with no room, sinks
-- back against what is behind them).
--
-- When the song stops Jigglypuff opens its eyes, looks round at a town fast
-- asleep, and PUFFS UP red with anger. Then it pulls the cap off its
-- microphone -- it is a marker -- and goes from face to face drawing on
-- them, stroke by stroke, with a squeak: Professor Oak gets glasses and a
-- mustache, your rival a unibrow and swirly cheeks, your Mom cat whiskers,
-- your partner swirls, you a monocle and a curly mustache, a townsperson a
-- star or a heart. It stomps off in a huff, and the camera rises over the
-- sleeping, doodled town at dusk.
--
-- TEST243: AND THEN THE FIREWORKS. As the camera rises over the snoring
-- town, the stop's own finale salvo goes up again over Pallet (its rockets,
-- its bangs, the float's cannons). The first bang wakes everyone: they sit
-- or spring back up with a start and a stretch (the eggs' wake curves), their
-- eyes open again, the Zz stop, the crowd cheers (crowd_swell) and the
-- homecoming march comes back -- and they are all still WEARING THE DOODLES.
-- A short shot on the awake, doodled town (Professor Oak in his glasses and
-- mustache, your rival with his unibrow) under the fireworks, then the white
-- and the credits.
--
-- How it fits. A stop gag of ParadeEggs (E.STOP_GAGS.pallet): it loads under
-- Pallet's card (Jigglypuff's model, the song, the sounds, the doodles); it
-- leaves the stop's own act alone and, when the finale has run its course,
-- HOLDS THE STOP'S END (holdEnd) while it plays -- the encore -- then lets the
-- parade go on to its white and the credits, exactly as before. It reuses
-- the eggs' machinery: the song player (ParadeEggs.Song: a stream from the
-- mod's bytes, the music setting, the march ducked, the song's own clock,
-- len + 4 s cap), the poses (ParadeCast.pose: anyone tipped about their
-- feet, the player and partner included), the Zz, the icons and the sounds'
-- helpers. Its own: Jigglypuff's choreography, the fall planner, the camera
-- beats over the verses, and the doodles (lib/ParadeDoodles.lua): one mesh,
-- drawn at each face in the late pass with the depth test and a pull toward
-- the camera, a stroke at a time. The faces are found exactly: while the
-- encore plays, the draw of each sleeper is watched (CharacterRenderers.first)
-- for the matrix its body mesh is drawn with, and the Collection's models are
-- known by their vertex counts (FACES: the eyes measured offline).
--
-- Fallbacks: no long song -> the short one -> the eggs' stand-in lullaby (the
-- gag lays itself out by the length it gets); no Jigglypuff model -> its
-- picture; neither, or no song at all -> no encore: the credits come exactly
-- as before. Everything is called inside pcall by the eggs; any failure lets
-- the ending go. HOLD A/START skips it with the parade (the song stops at
-- once). Once per parade; if 3D is off there is no parade at all.
local V=...
local PE={REVISION='parade-ending-263'}
local floor,max,min,abs,sin,cos,sqrt,pi=math.floor,math.max,math.min,math.abs,math.sin,math.cos,math.sqrt,math.pi
local atan2=math.atan2 or math.atan

------------------------------------------------------------------ settings
PE.STOP='pallet'
PE.ASSETS='assets/parade/'
-- the songs, in turn: Joseph's long song, his short one, the eggs' stand-in
PE.LONG={file='jigglypuff_song_long.mp3',len=74.67,cap=95,capFade=1.5,grace=4,duck=.12,duckIn=1.2,duckOut=.8,
 -- its loudness every 0.1 s (0..9)
 env='066757675555555657544555766766655466656465665545544565354444354654233374244645645676567845665754464554656465534556666666556665566686764654645365346465'..
 '434565223221265555553676566655554656675346557766675545666555556655554456544545352556442243733455465466755677457657535555456656654345666667655577465757'..
 '776556465464653455654446551231215555564456756675565555666653465666766655466655455575546554564445353444654233465344645644666567755665664364544656465544'..
 '556666766566665566586764664656454446455434464322322165555552667576655654656675445557666675554666555556654554456544544442546442343733455455456755677556'..
 '657544655546655555445566667665667565667876647556464652454654346651231314645564446766675555545666653565666666654556666455574545554565445352545564300'}
-- the long song's breaths (its phrases end here, seconds): the cuts and the
-- falls are laid on them; any other song lays them out by its length
PE.LONG_PHRASES={7.0,16.0,23.7,32.9,40.8,49.9,57.7,66.8}
PE.SFX={squeak1='end_squeak1.ogg',squeak2='end_squeak2.ogg',squeak3='end_squeak3.ogg',pop='end_pop.ogg',
 hop='end_hop.ogg',thud='end_thud.ogg',snore1='end_snore1.ogg',snore2='end_snore2.ogg',puff='end_puff.ogg',stomp='end_stomp.ogg',
 swell='crowd_swell.ogg'}
PE.JIGGLY={species='JIGGLYPUFF',dex=39,h=7.4,maxW=8.2}
PE.SING_MOVE=47
-- seconds: its arrival before the first note; after the song: it notices,
-- puffs up, grins, pops the cap; each doodle (hop in, then scribble); the
-- stomp off; the last wide shot
PE.T={arrive=3.0,hop=.30,notice=.9,puff=1.3,grin=.35,cap=.65,beat=1.32,hopIn=.30,scribble=.58,stomp=2.4,final=2.8,
 wakeShot=3.4,awake=4.2}   -- (TEST243: the fireworks wake the town: the bang, then the awake, doodled town)
-- TEST243: the wake. The stop's finale salvo (its def: n, spacing, scale) is
-- fired `lead` s before the wake shot, its centre `back` behind the two
-- faces of the last shot (as the camera sees them) and `up` above them; the
-- first shell's bang wakes everyone, one after another `gap` s apart (the
-- family first), `fallback` s into the wake shot at the latest. The crowd's
-- cheer comes back over `cheerIn` s, a swell at `swells` s; the homecoming
-- march again (faded as the white comes, `musicFade` s). The last shot: the
-- `faces` (by role), within `maxOff` rad of the way they face, fitted from
-- `dMin`..`dMax` away (fov `fov`, the heads `pad` apart from the edge),
-- `below` under their eyes, looking up `tilt` degrees at the sky. The wide
-- before it goes on from where the last wide over the sleeping town ends,
-- starting `wideTurn` of the way toward the shells, then looking directly
-- at their centre (fov `wideFov`). TEST245 fits a complete fan of smaller
-- bursts behind the faces; their camera-facing sparks retain a bright core.
PE.WAKE={lead=.8,back=460,up=205,gap=.05,fallback=1.6,cheerIn=1.2,swells={{.35,.85},{2.6,.6}},music=true,musicFade=2.0,
 faces={'oak','rival'},maxOff=1.0,dMin=19,dMax=40,fov={50,48},pad=8,below=1.5,tilt=10,push=1.10,
 wideFov=58,wideTurn=.65,bodyClear=5.5,eyeMargin=5,roofH=52,
 -- TEST247: in Joseph's ride recording the two faces stood one behind the
 -- other as the camera saw them: Blue's head filled the bottom corner, cut
 -- off, and Oak was small behind him. Now the camera prefers the side from
 -- which they stand side by side (`depthK` off the score for every unit one
 -- is nearer than the other past `depthOK`), and the nearer face is never
 -- closer than dMin.
 depthK=2.5,depthOK=4,
 -- TEST249: and the sky behind them open. In Joseph's ride recording the
 -- reaction shot put most of the display behind Blue's roof. Each angle is
 -- now marked down `skyK` for the share of the shells (`burstR` round
 -- their centre; three lines across the fan) a roof hides: anything
 -- standing in a run of at least `skyRun` units along the line out past
 -- the faces (up to `skyReach` beyond them) is taken as a house `roofH`
 -- tall. Open sky outweighs a face standing a little behind the other: the
 -- depth mark (TEST247) is held to `depthMax`. (The bang shot before it
 -- lasts one second longer: PE.T.wakeShot.)
 skyK=80,depthMax=30,burstR=80,skyRun=16,skyReach=170,skyStep=8,
 -- TEST255: five lines across the fan (the shells spread about +-0.31 rad
 -- from the lens), each from `skyNear` out -- a house BESIDE the lens (Blue's,
 -- in the TEST253 ride) hides the shells on its side as surely as one
 -- behind the faces -- and the whole fan (its centre, pl.burst) slid up to
 -- `fanShift` rad toward the open side when that hides less
 skyFan={-.31,-.155,0,.155,.31},skyNear=6,fanShift=.15,
 -- TEST253: and nobody else big in the foreground. In Joseph's TEST251 ride
 -- (3:40-3:44) a townsperson stood beside the lens, her face filling the
 -- right edge, cut off. The old checks only looked BETWEEN the lens and the
 -- two faces. Now anyone else (townsfolk, you, your partner) inside the
 -- picture (`fgEdge` of its half-width, plus a body's breadth) and nearer
 -- than `fgNear` of the way to the faces, from either end of the camera's
 -- move, costs `fgBase` + `fgK` x how near they are.
 fgBase=40,fgK=60,fgNear=.9,fgEdge=1.08,
 -- TEST255: what counts is how big they LOOK. Each other person is three
 -- spheres -- head (`fgHead` of their height across: the Collection's people
 -- have big heads and hair; at `fgHeadY` up), chest
 -- and legs -- projected through the shot's own camera (eye, focus, fov, at
 -- both ends of its move); anyone any part of whom shows in the picture
 -- (within `fgMargin` of the edge) at more than `fgSize` of the half-height
 -- is in the foreground, and costs more the bigger they look.
 fgHead=.36,fgHeadY=.82,fgSize=.10,fgMargin=.02,
 -- TEST257: AND THEN THEY ARE MOVED. In Joseph's TEST256 ride a townswoman's
 -- face still filled the right third of the close-up: around Blue's house no
 -- angle was clear of everyone, and the planner took the least bad. Now, as
 -- the close-up starts, every townsperson who would show in it (either end of
 -- its move) bigger than `hideSize` of its half-height, nearer than the faces,
 -- is kept out of it (ParadeCast.hide: body, shadow, reflection; no sprite in
 -- their place) -- one set, fixed for the shot, back when it ends, on a skip
 -- and on cleanup. Never Oak, the rival, you or your partner: those still
 -- count in the planner at full weight; townsfolk only `hideCost` (+`hideK`
 -- the bigger), so the rooftop and side-by-side checks lead again.
 hideSize=.05,hideMargin=.04,hideCost=4,hideK=6}
-- (each face's beat: hop in .30, scribble .58, then it hops back to admire
-- its work for the rest, .44: the finished drawing clear to see before the
-- next cut)
PE.ADMIRE_BACK=2.8         -- how far it hops back from the face
PE.DOODLE_MAX=14           -- include the whole available crowd, not just two townsfolk
PE.HOLD_PAD=12             -- (safety) the most the encore may run past its plan
-- the hour: sunset when it starts, dusk as the song ends, a little later at the end
PE.TOD={song=662,final=668}
-- falling over: the angle lying down, the time it takes; leaning back
-- (nothing behind them has room): at most LEAN, at least LEAN_MIN
PE.FALL_A,PE.FALL_DUR,PE.LEAN,PE.LEAN_MIN=1.48,1.15,.62,.30
PE.BODY_R=2.6              -- half a body's thickness (clearances)
-- Full recline for any selected player model; slide its rendered feet
-- forward as it falls so the head stays clear of the float's sunburst.
PE.RIDE_LEAN=PE.FALL_A
PE.PLAYER_FALLS={0,.6,-.6,1.15,-1.15}   -- ways to fall, off straight back
-- Fallback for a follower without its own authored sleep context.
PE.PARTNER_DROOP=PE.FALL_A
-- the doodles: ink, how far toward the camera they are pulled (a depth bias)
PE.INK={.06,.05,.08}
PE.PULL=.55
-- where Jigglypuff stands to draw: beside the head, this far from the
-- face's middle (lying down; standing or leaning) -- clear of the face
PE.SPOT_LYING,PE.SPOT_UPRIGHT=7.4,7.0
-- TEST242: the doodle close-ups are laid out from Jigglypuff's REAL size
-- (its fitted model's extents, read from the model's bounds() at load: the
-- eggs' loadActor md.ex/ey/ez), not the stand-in's. It stands beside the
-- head, off by the head's half-width (headR face units) + a gap + its own
-- half-width; it draws turned `turn` of the way from the face toward the
-- camera (three-quarter view), admires its work turned `admireTurn`; the
-- camera is FITTED: the head and Jigglypuff (where it draws, and where it
-- admires) inside `fill` of the picture at the end of the crane (fov fovTo),
-- centred between them, never nearer than `near` beyond its body; it hops
-- in from `hopFrom` outside, on its own side (never across the lens).
PE.CLOSE={headR=3.3,gap=.9,turn=.55,admireTurn=.80,fill=.80,dMin=14,dMax=48,near=6,aspect=16/9,
 fovFrom=40,fovTo=38,crane=.9,lyingTilt=42,uprightTilt=16,hopFrom=9,hopArc=2.6,partnerPad=3}

------------------------------------------------------------------ helpers
local EMPTY={}
local function now()local ok,t=pcall(love.timer.getTime);return ok and t or 0 end
local function clamp01(u)return max(0,min(1,u))end
local function smooth(u)u=clamp01(u);return u*u*(3-2*u)end
local function lerp(a,b,u)return a+(b-a)*u end
local function hash(a,b)local x=sin(a*127.1+b*311.7)*43758.5453;return x-floor(x)end
local function log(fmt,...)
 local args={...}
 pcall(function()require('src.core.Logger').warn('[ParadeEnding] '..fmt,unpack(args))end)
end
PE._log=log
local function EG()return V.require('ParadeEggs')end
local function CP()local ok,m=pcall(V.require,'ParadeCast');return ok and type(m)=='table'and m or nil end
local function HF()return V.require('HallOfFame3D')end
local YAW={down=0,up=pi,right=pi/2,left=-pi/2}
local DIRS={{'down',0,1},{'up',0,-1},{'right',1,0},{'left',-1,0}}
local function facingToward(dx,dz)
 if abs(dx)>abs(dz)then return dx>0 and'right'or'left'end
 return dz>0 and'down'or'up'
end
local function groundAt(map,x,z)
 if not map then return 0 end
 local okS,VS=pcall(V.require,'VoxelScene')
 if not(okS and type(VS)=='table'and VS.groundAt)then return 0 end
 local ok,h=pcall(VS.groundAt,map,floor(x/16),floor(z/16),x-8,z-8)
 return ok and tonumber(h)or 0
end
local function mat()return{1,0,0,0, 0,1,0,0, 0,0,1,0, 0,0,0,1}end
PE.mat=mat
-- a card facing the camera squarely (BattleBillboard's unit quad: x -.5..5,
-- y 0..1, facing +z), w x h, centred on (x,y,z), rolled in the screen
local CAMR,CAMU={1,0,0},{0,1,0}
local function camBasis()
 local R=V.require('Voxel3D')
 local e,f=R.eye,R.focus
 if not(e and f)then CAMR[1],CAMR[2],CAMR[3],CAMU[1],CAMU[2],CAMU[3]=1,0,0,0,1,0;return end
 local fx,fy,fz=f[1]-e[1],f[2]-e[2],f[3]-e[3]
 local l=sqrt(fx*fx+fy*fy+fz*fz);if l<1e-6 then l=1 end
 fx,fy,fz=fx/l,fy/l,fz/l
 local rx,rz=-fz,fx
 local rl=sqrt(rx*rx+rz*rz);if rl<1e-6 then rx,rz,rl=1,0,1 end
 rx,rz=rx/rl,rz/rl
 -- up = right x forward
 local ux,uy,uz=-rz*fy, rz*fx-rx*fz, rx*fy
 CAMR[1],CAMR[2],CAMR[3]=rx,0,rz
 CAMU[1],CAMU[2],CAMU[3]=ux,uy,uz
end
PE._camBasis=camBasis
local function fillFacing(m,x,y,z,w,h,roll)
 local c,s=cos(roll or 0),sin(roll or 0)
 -- the card's x along (r c + u s), its y along (-r s + u c)
 local ax,ay,az=(CAMR[1]*c+CAMU[1]*s)*w,(CAMR[2]*c+CAMU[2]*s)*w,(CAMR[3]*c+CAMU[3]*s)*w
 local bx,by,bz=(-CAMR[1]*s+CAMU[1]*c)*h,(-CAMR[2]*s+CAMU[2]*c)*h,(-CAMR[3]*s+CAMU[3]*c)*h
 -- normal: r x u
 local nx=CAMR[2]*CAMU[3]-CAMR[3]*CAMU[2]
 local ny=CAMR[3]*CAMU[1]-CAMR[1]*CAMU[3]
 local nz=CAMR[1]*CAMU[2]-CAMR[2]*CAMU[1]
 m[1],m[2],m[3],m[4]=ax,bx,nx,x-bx*.5
 m[5],m[6],m[7],m[8]=ay,by,ny,y-by*.5
 m[9],m[10],m[11],m[12]=az,bz,nz,z-bz*.5
 m[13],m[14],m[15],m[16]=0,0,0,1
 return m
end
PE._fillFacing=fillFacing

------------------------------------------------------------------ the faces
-- The Collection's people, known by their meshes' vertex counts: the point
-- between the eyes (mesh units: x, y), half the distance between the eyes,
-- and the face's surface there (z). Measured offline from the models
-- (work/models/calib.py); the mesh is drawn with the person's own matrix.
PE.FACES={
 [4138]={'adult_woman',8.01,19.79,1.03,2.17},
 [4266]={'middle_man',7.97,20.60,1.05,2.34},
 [4305]={'adult_man',8.00,19.87,1.18,2.10},
 [4394]={'young_boy',8.00,18.22,1.01,1.86},
 [4800]={'juvenile_girl',8.00,16.02,1.22,2.21},
 [4835]={'kid_boy',7.99,12.77,1.07,2.06},
 [5016]={'blue',8.00,18.30,0.98,1.61},
 [5022]={'young_girl',8.00,18.29,1.15,2.74},
 [5036]={'juvenile_boy',7.99,15.64,0.95,2.35},
 [5258]={'middle_woman',8.00,20.01,1.24,2.34},
 [5428]={'kid_girl',7.99,12.86,0.91,2.21},
 [5461]={'players_mother',8.00,19.64,1.03,1.60},
 [5689]={'professor_oak',8.00,20.33,1.02,2.16},
}
-- (anyone else: their mesh is read once, a slice a frame -- its top, the
-- front of its head -- and the eyes put where these models have them)
PE.SCAN_SLICE=1200         -- vertices read a frame
PE.SCAN_BINS=50            -- the top half, in hundredths of the height
PE.NECK_FROM=14            -- (a chin is never higher than this)
PE.NECK_DROP=.035          -- the front falls back this much (of the height)...
PE.NECK_HOLD=.02           -- ...and stays back
PE.EYE_OF_NECK=.66         -- the eyes, as far down as the chin
PE.EYE_FROM_TOP=.175       -- (no chin found: of the height)
PE.HALF_OF_H=.044

-- The watch: while the encore plays, the main draw of each sleeper is
-- watched for its biggest mesh and the matrix it is drawn with (tipped and
-- all: the poses' own swap passes it on). Installed when the encore starts
-- (outermost of the CharacterRenderers.first wraps), taken away after.
local watched={}           -- actor (or 'player') -> its record {M=,n=,mesh=,serial=}
local obsRec,obsDraw=nil,nil
local frameSerial=0
local function observer(mesh,tex,model,pull,sun,ranges)
 local rec=obsRec
 -- Record a real successful submission, not merely a provider claiming the
 -- actor (the near-body guard is allowed to claim it without any mesh).
 local drawn=obsDraw(mesh,tex,model,pull,sun,ranges)
 if drawn~=false and rec and type(model)=='table'and mesh then
  local okN,n=pcall(mesh.getVertexCount,mesh)
  n=okN and tonumber(n)or 0
  if n>(rec.best or 0)then
   rec.best=n;rec.mesh=mesh;rec.n=n
   -- Audit the small eye-UV list before anyone starts falling asleep.
   pcall(function()V.require('ParadeSleepEyes').prepare(mesh)end)
   local M=rec.M;for i=1,16 do M[i]=model[i]end
   rec.serial=frameSerial;rec.hidden=false
  end
 end
 return drawn
end
local function actorOf(ctx)
 if type(ctx)~='table'then return nil end
 if ctx.isPlayer==true or ctx.role=='player'then return'player'end
 return ctx.actor or ctx.entity or(type(ctx.pose)=='table'and ctx.pose.entity)
end
-- (each wrapper keeps the original it wrapped, and its own on/off: taken off
-- while another mod has wrapped over it, it stays in that chain as a plain
-- pass-through to its original -- never with nothing to call, as
-- ParadeFloat.dispose does with its own)
local function makeWatch(orig)
 local w={on=true,orig=orig}
 w.fn=function(method,ctx,...)
  if not w.on or method~='drawEntity'or obsRec then return orig(method,ctx,...)end
  local key=actorOf(ctx)
  local rec=key and watched[key]
  if not rec then return orig(method,ctx,...)end
  local R=V.require('Voxel3D')
  local d0=R.draw
  rec.best=0;rec.hidden=true;rec.attemptSerial=frameSerial
  obsRec,obsDraw=rec,d0
  R.draw=observer
  local okC,res=pcall(orig,method,ctx,...)
  R.draw=d0
  obsRec,obsDraw=nil,nil
  if not okC or res~=true then rec.hidden=true end
  if not okC then error(res,0)end
  return res
 end
 return w
end
local live=nil   -- the watch now on: {CR=, w=}
local function watchInstall()
 if live then return true end
 local ok,CR=pcall(V.require,'CharacterRenderers')
 if not(ok and type(CR)=='table'and type(CR.first)=='function')then return false end
 local w=makeWatch(CR.first)
 CR.first=w.fn
 live={CR=CR,w=w}
 return true
end
local function watchRemove()
 obsRec,obsDraw=nil,nil
 for k in pairs(watched)do watched[k]=nil end
 if live then
  local CR,w=live.CR,live.w
  w.on=false
  if CR.first==w.fn then CR.first=w.orig end
  live=nil
 end
end
PE._watched=watched
PE._watchInstall,PE._watchRemove=watchInstall,watchRemove
function PE._watching()return live~=nil end

------------------------------------------------------------------ the ending of one parade
local End={};End.__index=End
PE.End=End

function PE.make(eggs,stop)
 local self=setmetatable({eggs=eggs,P=eggs and eggs.P,game=eggs and eggs.game,kind='ending',state='wait',
  stop=stop,loadQ={'jiggly','song','sounds','icons','doodles','cries'},snd={},voices={},
  sleepers={},targets={},notes={},dust={},mats={},clock=0},End)
 for i=1,12 do self.notes[i]={on=false}end
 -- (a beat's one-off things: true the first time it is asked)
 local doneK={}
 self.onceFn=function(k)if doneK[k]then return false end;doneK[k]=true;return true end
 for i=1,8 do self.dust[i]={on=false}end
 for i=1,6 do self.mats[i]=mat()end
 self.cap={on=false}
 return self
end
PE.STOP_GAG=PE.make

------------------------------------------------------------------ loading (a thing a call, under the card)
function End:loadNext()
 local q=self.loadQ
 if not q or #q==0 or self.state=='off'then self.loadQ=nil;return false end
 local step=table.remove(q,1)
 local eg=EG()
 if step=='jiggly'then
  local act=nil
  pcall(function()act=eg._loadActor(self.game,{species=PE.JIGGLY.species,dex=PE.JIGGLY.dex,want=PE.JIGGLY.h,maxW=PE.JIGGLY.maxW})end)
  self.actor=act
  if not act then
   -- (nothing to show: nothing more is loaded, and Pallet is as it was)
   log('the encore: no Jigglypuff (no model, no picture) -- Pallet as it was')
   self.state='off';self.loadQ=nil
  end
 elseif step=='song'then
  -- Joseph's long song; else his short one; else the stand-in lullaby
  local song=eg.Song.new(PE.LONG)
  local ok=song:load()
  if not ok then
   log('the encore: the long song would not load -- the short one instead')
   local o={}
   for k,v in pairs(eg.SONG)do o[k]=v end
   o.cap,o.duck,o.duckIn,o.duckOut=95,PE.LONG.duck,PE.LONG.duckIn,PE.LONG.duckOut
   song=eg.Song.new(o)
   ok=song:load()
  end
  if ok then self.song=song
  else
   self.song=nil;log('the encore: no song at all -- Pallet as it was')
   if self.actor then pcall(eg._releaseActor,self.actor);self.actor=nil end
   self.state='off';self.loadQ=nil
  end
 elseif step=='sounds'then
  for k,f in pairs(PE.SFX)do self.snd[k]=eg.loadSource(f)or false end
 elseif step=='icons'then
  -- (its own three, beside the eggs' notes, Zz, microphone and anger mark:
  -- the eggs keep them, and let them go with the stop)
  PE.installIcons(eg)
  local inst=self.eggs
  inst.tex=inst.tex or{}
  for _,n in ipairs({'cap','marker','spark'})do
   if inst.tex[n]==nil and eg.ICONS[n]then
    local ok,img=pcall(eg.makeIcon,n)
    inst.tex[n]=ok and img or false
   end
  end
 elseif step=='doodles'then
  local okD,DD=pcall(V.require,'ParadeDoodles')
  if okD and DD then
   local verts,map,runs=DD.build()
   local R=V.require('Voxel3D')
   local okM,mesh=pcall(R.newMesh,verts,map)
   if okM and mesh then self.dmesh,self.druns,self.DD=mesh,runs,DD
   else log('the doodles would not build: %s',tostring(mesh))end
  end
 elseif step=='cries'then
  pcall(function()
   local S=require('src.core.Sound')
   if S.prewarmCry then S.prewarmCry(self.game.data,PE.JIGGLY.species)end
  end)
 end
 return true
end
-- can it play? (Jigglypuff and a song)
function End:ready()
 return self.actor~=nil and self.song~=nil and self.state~='off'
end

------------------------------------------------------------------ sound
function End:play(name,vol,pitch)
 local base=self.snd[name]
 if not base then return nil end
 local o=self.game and self.game.save and self.game.save.options
 local g=max(0,min(7,tonumber(o and o.sfxVol)or 7))/7
 if g<=0 then return nil end
 local ok,v=pcall(base.clone,base)
 if not(ok and v)then return nil end
 pcall(v.setVolume,v,min(1,(vol or 1)*g))
 pcall(v.setPitch,v,pitch or 1)
 pcall(v.play,v)
 self.voices[#self.voices+1]=v
 return v
end
function End:cry(pitch)
 local src=nil
 pcall(function()src=require('src.core.Sound').playCry(self.game.data,PE.JIGGLY.species)end)
 if src then pcall(src.setPitch,src,pitch or 1)end
 self.cryT=now()
 return src
end
function End:reap()
 local v=self.voices
 for i=#v,1,-1 do
  local s=v[i];local ok,on=pcall(s.isPlaying,s)
  if not(ok and on)then pcall(s.release,s);table.remove(v,i)end
 end
end
function End:silence()
 for _,s in ipairs(self.voices)do pcall(s.stop,s);pcall(s.release,s)end
 self.voices={}
end

------------------------------------------------------------------ the people
local function personAt(npc)
 return(tonumber(npc.px)or(tonumber(npc.cellX)or 0)*16)+8,(tonumber(npc.py)or(tonumber(npc.cellY)or 0)*16)+8
end
local function isFollower(e)
 local okF,PF=pcall(V.require,'ParadeFloat')
 if okF and type(PF)=='table'and type(PF.isFollower)=='function'then
  local ok,yes=pcall(PF.isFollower,e)
  if ok and yes then return true end
 end
 return false
end
-- a standing person's height (for the planner: the tallest of what they can be)
local HEIGHT={SPRITE_OAK=25.2,SPRITE_LITTLE_GIRL=19.8,SPRITE_LITTLE_BOY=19.8}
local function heightOf(spr)return HEIGHT[spr]or 21.8 end
-- the fall's order: the townsfolk, your rival, Professor Oak, your Mom, your
-- partner, you
local ROLE={SPRITE_BLUE='rival',SPRITE_OAK='oak',SPRITE_MOM='mom'}
PE.ROLE=ROLE

-- Is this stretch of ground clear for a body lying from (x,z) along (dx,dz)
-- for `len`? Returns how far it is clear.
function End:freeRun(x,z,dx,dz,len,skip)
 local map=self.map
 local R=PE.BODY_R
 local free=0
 local s=.5
 while s<=len+1e-6 do
  local px,pz=x+dx*s,z+dz*s
  for k=-1,1 do
   local qx,qz=px+dz*R*k,pz-dx*R*k
   local cx,cz=floor(qx/16),floor(qz/16)
   if map then
    local okW,w=pcall(map.isWalkableCell,map,cx,cz)
    if okW and w==false then return free end
    local okI,inb=pcall(map.inBounds,map,cx,cz)
    if okI and inb==false then return free end
    local okWa,wat=pcall(map.isWaterCell,map,cx,cz)
    if okWa and wat==true then return free end
    -- (a door is the house's own wall)
    if map.isDoorTileCell then local okD,door=pcall(map.isDoorTileCell,map,cx,cz);if okD and door==true then return free end end
   end
   if self:inFloat(qx,qz,1.0)then return free end
  end
  for _,b in ipairs(self.blockers)do
   if b~=skip then
    if b.ax then
     -- a body lying on the ground: a segment
     local ex,ez=b.bx-b.ax,b.bz-b.az
     local l2=ex*ex+ez*ez
     local u=l2>0 and max(0,min(1,((px-b.ax)*ex+(pz-b.az)*ez)/l2))or 0
     local qx,qz=b.ax+ex*u-px,b.az+ez*u-pz
     if qx*qx+qz*qz<(2*R+.6)^2 then return free end
    else
     local qx,qz=b.x-px,b.z-pz
     if qx*qx+qz*qz<(R+3.0)^2 then return free end
    end
   end
  end
  free=s
  s=s+.5
 end
 return free
end
function End:inFloat(x,z,m)
 local fl=self.P and self.P.float
 if not(fl and fl.x and not fl.released)then return false end
 local c,s=cos(fl.yaw or 0),sin(fl.yaw or 0)
 local dx,dz=x-fl.x,z-fl.z
 local lx,lz=c*dx-s*dz,s*dx+c*dz
 local okF,PF=pcall(V.require,'ParadeFloat')
 local W=(okF and PF.HALF_W or 8.5)+m
 local rear=(fl.rear or(okF and PF.REAR)or-9)-m
 local nose=(okF and PF.NOSE or 38.5)+m
 return abs(lx)<=W and lz>=rear and lz<=nose
end

-- who sleeps, and how: everyone on the stop (the parade's people and the
-- town's own), then you and your partner; each turns to Jigglypuff and is
-- given the way to fall: their back to clear ground (the four ways the
-- people of this world face; toward Jigglypuff first), full length; else the
-- most room there is, leaning back. Your selected player model reclines on
-- the float; the current follower uses its sleep context or a full fall.
function End:planSleepers()
 local P=self.P
 local stop=P:stop()
 local ow=self.game.overworld
 self.map=ow and ow.map
 local J=self.perch
 local people={}
 for _,e in ipairs(stop and stop.people or EMPTY)do
  local npc=e.npc
  if type(npc)=='table'and not isFollower(npc)and npc~=(ow and ow.player)then
   local spr=tostring(npc.def and npc.def.sprite or'')
   local x,z=personAt(npc)
   people[#people+1]={key=npc,npc=npc,sprite=spr,role=ROLE[spr]or'town',ours=e.ours,x=x,z=z,H=heightOf(spr)}
  end
 end
 -- the townsfolk: farthest from Jigglypuff first (the far ones first, as the
 -- wide shot opens on them); then rival, Oak, Mom
 local rank={town=1,rival=2,oak=3,mom=4}
 table.sort(people,function(a,b)
  local ra,rb=rank[a.role],rank[b.role]
  if ra~=rb then return ra<rb end
  local da=(a.x-J[1])^2+(a.z-J[3])^2
  local db=(b.x-J[1])^2+(b.z-J[3])^2
  if abs(da-db)>1 then return da>db end
  return tostring(a.npc.id)<tostring(b.npc.id)
 end)
 -- standing people (blockers until they lie down), the float's poles
 self.blockers={}
 for _,p in ipairs(people)do self.blockers[#self.blockers+1]=p end
 local pl=ow and ow.player
 local px,pz
 if pl then px,pz=personAt(pl);self.playerBlock={x=px,z=pz};self.blockers[#self.blockers+1]=self.playerBlock end
 local fol=nil
 pcall(function()fol=V.require('ParadeCast')._followerOf(self.game)end)
 if fol and not self.ride then local fx,fz=personAt(fol);self.blockers[#self.blockers+1]={x=fx,z=fz}end
 local b=stop and stop.banner
 if b then
  local bz=b.y*16+8
  self.blockers[#self.blockers+1]={x=b.x0*16,z=bz};self.blockers[#self.blockers+1]={x=b.x1*16,z=bz}
 end
 -- the plan, in the order they fall
 for _,p in ipairs(people)do self:planFall(p)end
 self.people=people
 log('the sleepers: %d people (%d fall flat)',#people,(function()local n=0;for _,p in ipairs(people)do if p.how=='fall'then n=n+1 end end;return n end)())
end
function End:planFall(p)
 local J=self.perch
 local want=facingToward(J[1]-p.x,J[3]-p.z)
 local order={want}
 for _,d in ipairs(DIRS)do if d[1]~=want then order[#order+1]=d[1]end end
 -- (after the one facing Jigglypuff: the sideways ones, then away)
 local best=nil
 local L=p.H*.96
 for i,f in ipairs(order)do
  local yw=YAW[f]
  local dx,dz=-sin(yw),-cos(yw)
  local free=self:freeRun(p.x,p.z,dx,dz,L,p)
  local full=free>=L-.6
  local score=(full and 100 or 0)+free-(i-1)*.5
  if not best or score>best.score then best={score=score,f=f,dx=dx,dz=dz,free=free,full=full}end
 end
 p.facing=best.f
 p.dx,p.dz=best.dx,best.dz
 if best.full or p.restBird then p.A=PE.FALL_A;p.how='fall'
 else
  local a=(best.free-1)/p.H
  p.A=a>=1 and PE.FALL_A or max(PE.LEAN_MIN,min(PE.LEAN,math.asin(max(0,min(1,a)))))
  p.how='lean'
 end
 -- it lies there now: a segment for those who fall after
 local reach=p.H*sin(p.A)
 for i,bk in ipairs(self.blockers)do if bk==p or bk.owner==p then table.remove(self.blockers,i)break end end
 self.blockers[#self.blockers+1]={ax=p.x,az=p.z,bx=p.x+p.dx*reach,bz=p.z+p.dz*reach,owner=p}
end

-- TEST261: Wilds/other overworld mods can add Pokemon AFTER settleCrowd
-- captured ow.npcs, or keep them only in ow.entities. Enrol the actual
-- Collection model owners, including late arrivals, before poseStadium runs.
-- They then use the same sleep, native animation hold and wake as the town.
-- No guessed sprite/species mapping and no extra Pokemon models or draws.
function End:posePokemon(posed,state)
 if self.released or self.wokeT or not self.people or not self.perch
     or(self.state~='arrive'and self.state~='sing'and self.state~='after'and self.state~='final')
     or not(state and state.map==self.map)then return end
 local known=self.pokemonSeen
 if not known then
  known={};self.pokemonSeen=known
  for _,p in ipairs(self.people)do known[p.npc]=p end
 end
 local added=0
 for _,v in ipairs(posed or EMPTY)do
  local npc=v.entity
  if type(npc)=='table'and not v.isPlayer and npc~=state.player
      and type(v.stadiumMon)=='table'and v.stadiumMatrix and not v.surfMount and not v.flyTravel
      and not npc._stadiumSkyRideMount and not npc._stadiumSkyRideLift
      and(not v.mapId or v.mapId==self.map.id)and not isFollower(npc)then
   local p=known[npc]
   local Sleep=V.require('ParadePartnerSleep')
   local bird=Sleep.isRestBird(v.stadiumMon)
   if p and bird and not p.restBird then
    p.restBird=true
    local h=tonumber(v.stadiumBodyHeight)
    if h and h==h and h>0 and h<128 then p.H=h end
    -- Use Pokemon height, not the human default; remove its old footprint
    -- before finding the clearest direction for the full resting pose.
    for j=#self.blockers,1,-1 do
     if self.blockers[j].owner==p then table.remove(self.blockers,j)end
    end
    self:planFall(p)
    npc.facing=p.facing;npc.pinnedFacing=p.facing
   end
   if not p then
    local x,z=personAt(npc)
    local h=tonumber(v.stadiumBodyHeight)
    if not(h and h==h and h>0 and h<128)then h=14 end
    p={key=npc,npc=npc,role='town',x=x,z=z,H=h,seed=hash(x,z)*6,restBird=bird,
     sprite=tostring(npc.def and npc.def.sprite or''),
     extraSaved={wanders=npc.wanders,steps=npc.steps,pinnedFacing=npc.pinnedFacing,facing=npc.facing}}
    self:planFall(p)
    -- Join the last townsfolk's wave. A Pokemon arriving during the song
    -- gets a fresh fall, instead of snapping to a pose timed before it existed.
    local at=self.songKind=='long'and 30.6 or(self.L or 75)*.41
    p.at=max(at,(self.S or 0)+.15)
    self.people[#self.people+1]=p
    known[npc]=p
    npc.wanders=false;npc.steps=false
    npc.facing=p.facing;npc.pinnedFacing=p.facing
    self.eggs:hold(npc,'sleep')
    added=added+1
   end
  end
 end
 if added>0 then
  self:updateSleepers(self.lastT or 0)
  log('the encore: %d additional overworld Pokemon joined the sleepers',added)
 end
end

-- the wave: when each of them goes (song seconds; L its length). The
-- townsfolk over the first two verses: one each side in the wide shot, the
-- rest of the west side in its shot, then the east side in its shot (the
-- far ones, out of the pictures, last); then your rival, Professor Oak and
-- your Mom; your partner; you
function End:schedule(L)
 local long=self.songKind=='long'
 local function at(longT,u)return long and longT or u*L end
 local J=self.perch
 local W,E,far={},{},{}
 for _,p in ipairs(self.people)do
  if p.role=='town'then
   if abs(p.z-J[3])>70 then far[#far+1]=p
   elseif p.x<J[1]-8 then W[#W+1]=p else E[#E+1]=p end
  end
 end
 local function byDist(a,b)return(a.x-J[1])^2+(a.z-J[3])^2>(b.x-J[1])^2+(b.z-J[3])^2 end
 table.sort(W,byDist);table.sort(E,byDist)
 -- the wide shot: the farthest of each side
 local first={}
 if W[1]then first[#first+1]=table.remove(W,1)end
 if E[1]then first[#first+1]=table.remove(E,1)end
 for i,p in ipairs(first)do p.at=at(10.2+(i-1)*3.0,.137+(i-1)*.04)end
 local function spread(list,t0,t1,u0,u1)
  local n=#list
  for i,p in ipairs(list)do
   local k=n>1 and(i-1)/(n-1)or 0
   p.at=at(t0+(t1-t0)*k,u0+(u1-u0)*k)
  end
 end
 spread(W,16.8,21.8,.225,.292)
 spread(E,24.6,29.8,.33,.40)
 spread(far,30.6,31.6,.41,.425)
 for _,p in ipairs(self.people)do
  if p.role=='rival'then p.at=at(36.6,.49);p.nods={at(33.9,.455),at(35.0,.47)}
  elseif p.role=='oak'then p.at=at(43.6,.585)
  elseif p.role=='mom'then p.at=at(47.2,.63)end
 end
 self.partnerAt=at(52.6,.705)
 -- TEST249: you right after your partner (you used to stand, eyes open,
 -- until 69.4 s -- seventeen seconds after Pikachu and thirty-eight after
 -- the town: it read as a fault, not a fight). Three nods, the eyes
 -- closing a little more each time, and over you go at about a minute; the
 -- song plays on over the two of you asleep, then on Jigglypuff, still
 -- singing happily to nobody (PE.SONG_BEATS).
 self.playerNods={at(54.2,.726),at(55.9,.749),at(57.6,.771)}
 self.playerAt=at(59.6,.798)
 -- (a short song: everyone asleep before its last few seconds)
 for _,p in ipairs(self.people)do p.at=min(p.at or 0,L*.9)end
 self.playerAt=min(self.playerAt,max(0,L-1.6))
end

-- the sleepers in the doodle round, and their drawings
function End:pickTargets()
 local DD=self.DD
 if not(DD and self.dmesh)then self.targets={};return end
 local cap=(self.P and self.P.lite)and 10 or PE.DOODLE_MAX
 local list={}
 local spares=0
 -- the family first (rival, Oak, Mom), then the townsfolk nearest the
 -- middle, then your partner and you (last: the grand finale)
 for _,role in ipairs({'mom','oak','rival'})do
  for _,p in ipairs(self.people)do if p.role==role then list[#list+1]={sl=p,design=DD.pick(p.sprite)}end end
 end
 local towns={}
 for _,p in ipairs(self.people)do if p.role=='town'then towns[#towns+1]=p end end
 local J=self.perch
 table.sort(towns,function(a,b)return(a.x-J[1])^2+(a.z-J[3])^2<(b.x-J[1])^2+(b.z-J[3])^2 end)
 local reserved=(self.partner and 1 or 0)+(self.player and 1 or 0)
 for i=1,#towns do
  if #list>=cap-reserved then break end
  list[#list+1]={sl=towns[i],design=DD.pick('town',spares)};spares=spares+1
 end
 if self.partner then list[#list+1]={sl=self.partner,design=DD.pick('PARTNER')}end
 if self.player then list[#list+1]={sl=self.player,design=DD.pick('PLAYER')}end
 while #list>cap do table.remove(list,#list-2)end
 for i,tg in ipairs(list)do
  local run=self.druns[tg.design]
  tg.run=run
  tg.ranges={run.first,0}
  tg.drawn=0
  tg.i=i
 end
 self.targets=list
end

-- (as the song ends) only faces it can find for certain are drawn on: a
-- person drawn some other way (no mesh it knows, nothing to read) gives way
-- to another of the townsfolk, or is let off. You remain the last word;
-- native curled-up followers without face anchors are left sleeping.
local function faceKnown(sl)
 local rec=sl.watch
 return rec~=nil and rec.serial~=nil and rec.n~=nil and type(rec.M)=='table'
  and(PE.FACES[rec.n]~=nil or rec.face~=nil)
end
function End:refineTargets()
 local list=self.targets or EMPTY
 local used={}
 for _,tg in ipairs(list)do used[tg.sl]=true end
 local spare={}
 for _,p in ipairs(self.people or EMPTY)do
  if p.role=='town'and not used[p]then spare[#spare+1]=p end
 end
 local out={}
 for _,tg in ipairs(list)do
  local keep=faceKnown(tg.sl)
  -- Every ink target needs an observed body and a measured face. A nominal
  -- head height (including a missing/curling follower) is not a face anchor.
  if not keep then
   while #spare>0 do
    local p=table.remove(spare,1)
    if faceKnown(p)then
     tg={sl=p,design=tg.design,run=tg.run,ranges={tg.run.first,0},drawn=0}
     keep=true;break
    end
   end
  end
  if keep then out[#out+1]=tg end
 end
 for i,tg in ipairs(out)do tg.i=i end
 if #out~=#list then log('the doodles: %d observed faces (of %d)',#out,#list)end
 self.targets=out;self.pb=nil
end

------------------------------------------------------------------ starting the encore
function End:start(t)
 local P=self.P
 local ow=self.game.overworld
 self.t0=t;self.lastT=t;self.clock=0
 self.state='arrive'
 self.map=ow and ow.map
 self.ride=P.float~=nil and P.float.x~=nil and not P.float.released
 local stop=P:stop()
 local E_=P:roadEnd(stop)
 self.E={E_[1],E_[2],E_[3]}
 -- the perch: the float's giant Poke Ball; else the PALLET TOWN sign's roof
 -- (the Legendary signs: 16.2 high) or the ground before it
 local fl=P.float
 if self.ride then
  local okF,PF=pcall(V.require,'ParadeFloat')
  local top=6.9+.7+3.3*2
  local bz=30
  if okF and PF.SLOTS and PF.BALL then top=PF.SLOTS[1].y+PF.BALL.stand+PF.BALL.r*2;bz=PF.BALL.z end
  local c,s=cos(fl.yaw or 0),sin(fl.yaw or 0)
  self.perch={fl.x+s*bz,fl.y+top,fl.z+c*bz}
  self.perchKind='ball'
 else
  local custom=false
  pcall(function()custom=V.require('CommunityVisuals').customSigns()and true or false end)
  local sx,sz=7*16+8,9*16+12-1.625
  local gy=groundAt(self.map,sx,sz+8)
  if custom then self.perch={sx,gy+16.2,sz};self.perchKind='sign'
  else self.perch={sx+2,gy,sz+14};self.perchKind='ground'end
 end
 -- the way in: from the grass gate to the foot of the perch
 self:makePath()
 -- the sleepers
 self:planSleepers()
 local L=self.song.len or PE.LONG.len
 self.songKind=(self.song.kind=='song'and self.song.o and self.song.o.file==PE.LONG.file)and'long'or(self.song.kind=='synth'and'synth'or'short')
 self.L=L
 self:schedule(L)
 local CPm=CP()
 for _,p in ipairs(self.people)do
  -- they turn to Jigglypuff (their backs to their clear ground)
  self.eggs:hold(p.npc,'sleep')
  p.npc.facing=p.facing;p.npc.pinnedFacing=p.facing
  p.npc.moving=false
  watched[p.npc]=watched[p.npc]or{M=mat(),best=0}
  p.watch=watched[p.npc]
  self.scanQ=self.scanQ or{}
  self.scanQ[#self.scanQ+1]=p
  p.seed=hash(p.x,p.z)*6
 end
 -- you, and your partner
 local pl=ow and ow.player
 if pl then
  local x,z=personAt(pl)
  local s={key='player',role='player',x=x,z=z,H=23,seed=2.3}
  -- the way you really face: a player-model mod keeps its own heading (the
  -- Player Model Loader: pmlVisualBodyYaw); else your facing; riding, the
  -- float's way. You keep looking where you look.
  local by=tonumber(pl.pmlVisualBodyYaw)
  if not by then by=self.ride and(P.float.yaw or 0)or YAW[pl.facing]or 0 end
  s.yaw=by
  if self.ride then
   s.dx,s.dz=-sin(by),-cos(by);s.A=PE.RIDE_LEAN;s.how='fall'
  else
   -- on your back (or a little to one side) onto clear ground; else you
   -- lean back as far as there is room
   local best=nil
   for i,off in ipairs(PE.PLAYER_FALLS)do
    local dx,dz=-sin(by+off),-cos(by+off)
    local free=self:freeRun(x,z,dx,dz,23*.96,self.playerBlock)
    local full=free>=23*.96-.6
    local score=(full and 100 or 0)+free-(i-1)*.5
    if not best or score>best.score then best={score=score,dx=dx,dz=dz,free=free,full=full}end
   end
   if best.full then s.dx,s.dz=best.dx,best.dz;s.A=PE.FALL_A;s.how='fall'
   else
    local dx,dz=-sin(by),-cos(by)
    local free=self:freeRun(x,z,dx,dz,23*.96,self.playerBlock)
    s.dx,s.dz=dx,dz
    s.A=max(PE.LEAN_MIN,min(PE.LEAN,math.asin(clamp01((free-1)/23))));s.how='lean'
   end
   local reach=23*sin(s.A)
   for i,bk in ipairs(self.blockers)do if bk==self.playerBlock then table.remove(self.blockers,i)break end end
   self.blockers[#self.blockers+1]={ax=x,az=z,bx=x+s.dx*reach,bz=z+s.dz*reach}
  end
  watched.player=watched.player or{M=mat(),best=0}
  s.watch=watched.player
  self.player=s
  -- (your face read first: you are the last word)
  self.scanQ=self.scanQ or{}
  table.insert(self.scanQ,1,s)
 end
 local hasPartner=false
 if self.ride then hasPartner=P.float.partner~=nil and(P.float.partner.model or P.float.partner.art)and true or false
 else pcall(function()hasPartner=V.require('ParadeCast')._followerOf(self.game)~=nil end)end
 if hasPartner then
  self.partner={key='partner',role='partner',seed=4.1,A=PE.PARTNER_DROOP,how='fall'}
 end
 self:pickTargets()
 watchInstall()
 -- the crowd stops cheering and turns to look; the confetti stops
 P.cheering=false
 log('the encore: Jigglypuff on the %s at %.0f,%.0f,%.0f; the %s song (%.1f s); %d asleep by its end; %d to doodle (%s)',
  self.perchKind,self.perch[1],self.perch[2],self.perch[3],self.songKind,L,#self.people+(self.player and 1 or 0)+(self.partner and 1 or 0),
  #self.targets,self.ride and'riding'or'walking')
end
-- its hops in from the grass gate (the gate is at the top of the town)
function End:makePath()
 local J=self.perch
 local pts
 if self.ride then
  -- down the west side of the float, then up onto its ball
  pts={{176,4},{160,26},{152,48},{150,70},{150,90}}
 else
  pts={{176,4},{160,30},{148,58},{142,88},{140,116},{136,140}}
 end
 local path={}
 for i,p in ipairs(pts)do path[i]={p[1],groundAt(self.map,p[1],p[2]),p[2]}end
 path[#path+1]={J[1],J[2],J[3],last=true}
 self.path=path
end

------------------------------------------------------------------ every frame
-- the eggs' hooks
function End:holdFinale()return false end
function End:holdEnd(t)
 if self.state=='done'or self.state=='off'then return false end
 if self.state=='wait'then
  if not self:ready()then self.state='off';return false end
  local ok,err=pcall(self.start,self,t)
  if not ok then log('the encore would not start: %s',tostring(err));self:quietNow();self.state='off';return false end
 end
 -- (safety: never longer than its song's cap, the after-song and a margin,
 -- on its own clock -- the parade can never get stuck here)
 local limit=PE.T.arrive+((self.song and self.song.o and self.song.o.cap)or 95)+((self.song and self.song.o and self.song.o.grace)or 4)
  +self:postLen()+PE.HOLD_PAD
 if(self.clock or 0)>limit then
  log('the encore ran over (%.1f s): let go',self.clock or 0)
  self.state='done'
  return false
 end
 return true
end
function End:quiet()return self.state~='wait'and self.state~='off'and not self.wokeT end
-- (at the parade's own end the sleeping, doodled town stays under the white)
function End:keepAtEnd()return self.state=='done'end
function End:wake()end
function End:levels(t)
 if self.state=='wait'or self.state=='off'then return 1,1,1 end
 -- (TEST243: the fireworks have woken them: the cheer, the march and the
 -- ticker tape come back)
 if self.wokeT then
  local u=smooth(((t or self.wokeT)-self.wokeT-.2)/PE.WAKE.cheerIn)
  local duck=self.song and self.song.duckLevel and self.song:duckLevel(t)or 1
  return u,duck,u
 end
 local cheer=0
 if self.state=='arrive'then cheer=1-.6*smooth(self.clock/PE.T.arrive)
 elseif self.state=='sing'then cheer=.4*(1-(self.asleepFrac or 0))*(1-smooth((self.S or 0)/8))end
 local duck=self.song and self.song.duckLevel and self.song:duckLevel(t)or 1
 return cheer,duck,0
end
-- the hour (ChampionParade asks: sunset going on to dusk)
function End:tod(t,cur)
 local st=self.state
 -- (skipped part way: the sky stays where the song left it under the white)
 if st=='off'then return self.lastTod end
 if st=='wait'or st=='arrive'then return nil end
 -- (from the stop's own hour as the song starts, on toward dusk)
 if not self.todFrom then self.todFrom=tonumber(cur)or 640 end
 local from=self.todFrom
 local v
 if st=='sing'then v=lerp(from,PE.TOD.song,smooth(clamp01((self.S or 0)/max(1,self.L or 1))))
 else v=lerp(PE.TOD.song,PE.TOD.final,smooth(clamp01((self.post or 0)/12)))end
 self.lastTod=v
 return v
end

-- someone drawn with a mesh the table does not know (your trainer from a
-- player-model mod, anyone else): read the mesh once, a slice a frame, while
-- they stand -- its top, the front of its head -- and keep where the eyes are
-- in the mesh's own space (the way it faces and up, too)
local function inv3(M)
 local a,b,c,d,e,f,g,h,i=M[1],M[2],M[3],M[5],M[6],M[7],M[9],M[10],M[11]
 local A,B,C=e*i-f*h,-(d*i-f*g),d*h-e*g
 local det=a*A+b*B+c*C
 if abs(det)<1e-12 then return nil end
 local k=1/det
 return{A*k,-(b*i-c*h)*k,(b*f-c*e)*k, B*k,(a*i-c*g)*k,-(a*f-c*d)*k, C*k,-(a*h-b*g)*k,(a*e-b*d)*k}
end
PE._inv3=inv3
function End:scanStep()
 local job=self.scan
 if not job then
  for _,s in ipairs(self.scanQ or EMPTY)do
   local rec=s.watch
   if rec and rec.n and not PE.FACES[rec.n]and not rec.face and not rec.scanned and rec.mesh and rec.serial then
    rec.scanned=true
    local M={};for k=1,16 do M[k]=rec.M[k]end
    local yaw=s.yaw
    if not yaw then
     local CPm=CP()
     pcall(function()local _;_,_,_,yaw=CPm.feetOf(s.key or s.npc,self.game)end)
    end
    yaw=tonumber(yaw)or 0
    local F={};for b=1,PE.SCAN_BINS do F[b]=-1e9 end
    job={rec=rec,mesh=rec.mesh,n=rec.n,M=M,i=1,pass=1,minY=1e9,maxY=-1e9,
     fx=sin(yaw),fz=cos(yaw),lx=cos(yaw),lz=-sin(yaw),latS=0,latN=0,F=F,Fm={}}
    self.scan=job
    break
   end
  end
  job=self.scan
  if not job then return end
 end
 local M,F=job.M,job.F
 local fx,fz,lx,lz=job.fx,job.fz,job.lx,job.lz
 local mesh=job.mesh
 local i0,last=job.i,min(job.n,job.i+PE.SCAN_SLICE-1)
 local pass=job.pass
 local H=job.maxY-job.minY
 local top=job.maxY
 local latC,strip=job.latC or 0,.05*H
 local NB=PE.SCAN_BINS
 local ok=pcall(function()
  for i=i0,last do
   local x,y,z=mesh:getVertex(i)
   x,y,z=x or 0,y or 0,z or 0
   local wy=M[5]*x+M[6]*y+M[7]*z+M[8]
   if pass==1 then
    if wy<job.minY then job.minY=wy end
    if wy>job.maxY then job.maxY=wy end
   else
    local u=(top-wy)/H
    if u>=0 and u<NB*.01 then
     local wx=M[1]*x+M[2]*y+M[3]*z+M[4]
     local wz=M[9]*x+M[10]*y+M[11]*z+M[12]
     local lat=wx*lx+wz*lz
     if pass==2 then
      if u<.25 then job.latS,job.latN=job.latS+lat,job.latN+1 end
     elseif abs(lat-latC)<strip then
      local b=floor(u*100)+1
      local f=wx*fx+wz*fz
      if f>F[b]then F[b]=f end
     end
    end
   end
  end
 end)
 if not ok then self.scan=nil;job.rec.scanFailed=true;return end
 job.i=last+1
 if job.i<=job.n then return end
 job.i=1
 if pass==1 then
  job.rec.height=job.maxY-job.minY
  job.pass=2
  if job.maxY-job.minY<2 then self.scan=nil;job.rec.scanFailed=true end
  return
 elseif pass==2 then
  if job.latN<8 then self.scan=nil;job.rec.scanFailed=true;return end
  job.latC=job.latS/job.latN;job.pass=3
  return
 end
 -- done: where the chin ends (the front of the face falls back to the neck),
 -- the eyes two thirds of the way up from there; how far out the face is
 self.scan=nil
 local rec=job.rec
 local Fm=job.Fm
 for b=1,NB do if F[b]<-1e8 then F[b]=b>1 and F[b-1]or 0 end end
 local function med3(a,b,c)
  if a>b then a,b=b,a end
  if b>c then b=c end
  return a>b and a or b
 end
 Fm[1]=F[1];Fm[NB]=F[NB]
 for b=2,NB-1 do Fm[b]=med3(F[b-1],F[b],F[b+1])end
 local T1,T2=PE.NECK_DROP*H,PE.NECK_HOLD*H
 local neck=nil
 local win=job.win or{}
 for b=PE.NECK_FROM+1,NB-2 do
  -- (the middle of the eight above)
  local k=0
  for j=max(1,b-8),b-1 do k=k+1;win[k]=Fm[j]end
  for j=k+1,#win do win[j]=nil end
  table.sort(win)
  local ref=k%2==1 and win[(k+1)/2]or .5*(win[k/2]+win[k/2+1])
  if Fm[b]<=ref-T1 and Fm[b+1]<=ref-T2 then neck=(b-1)*.01;break end
 end
 local eyeU=neck and max(.11,min(.27,PE.EYE_OF_NECK*neck))or PE.EYE_FROM_TOP
 local half=H*(neck and(.022+.085*neck)or PE.HALF_OF_H)
 local eb=floor(eyeU*100)+1
 local front=-1e9
 for b=max(1,eb-1),min(NB,eb+1)do if F[b]>front then front=F[b]end end
 if front<-1e8 then rec.scanFailed=true;return end
 local fwd=front-.1*half
 local lat=job.latC
 local wx,wy,wz=lat*lx+fwd*fx,top-eyeU*H,lat*lz+fwd*fz
 local I=inv3(M)
 if not I then rec.scanFailed=true;return end
 local function toLocal(vx,vy,vz)return I[1]*vx+I[2]*vy+I[3]*vz,I[4]*vx+I[5]*vy+I[6]*vz,I[7]*vx+I[8]*vy+I[9]*vz end
 local cx,cy,cz=toLocal(wx-M[4],wy-M[8],wz-M[12])
 local nx,ny,nz=toLocal(fx,0,fz)
 local ux,uy,uz=toLocal(0,1,0)
 rec.face={cx,cy,cz,nx,ny,nz,ux,uy,uz,half}
 log('a face found on a mesh of %d vertices: %.1f tall, the chin %s, the eyes %.2f down, half their width %.2f',
  job.n,H,neck and string.format('%.2f down',neck)or'not found',eyeU,half)
end

function End:update(dt,t)
 local st=self.state
 if st=='wait'or st=='off'or st=='done'then return end
 pcall(self.scanStep,self)
 local P=self.P
 if not P or P.finished then return end
 frameSerial=frameSerial+1
 self:reap()
 -- (the parade skipped: quiet now)
 if P.phase=='end'and st~='final'then self:quietNow();self.state='done';return end
 -- the encore's own clock: real time, a frame counting a tenth of a second
 -- at most (an app sent to the background comes back where it was)
 local step=min(.1,max(0,t-(self.lastT or t)))
 self.lastT=t
 self.clock=self.clock+step
 local song=self.song
 if st=='arrive'then
  if self.clock>=PE.T.arrive then
   self.state='sing';self.songT0=t
   song:play(self.game,t)
   self:singAnim()
   log('the encore\'s song begins (%s, %.1f s)',self.songKind,self.L or 0)
  end
 elseif st=='sing'then
  song:update(dt,t,self.game)
  local pos=song:phase()
  self.S=pos
  if song:ended()then
   self.state='after';self.post=0
   self.songEndT=t
   pcall(self.refineTargets,self)
   log('the encore\'s song is over (%s, after %.1f s): everyone is asleep',tostring(song.why),self.S or 0)
  end
 elseif st=='after'or st=='final'then
  self.post=(self.post or 0)+step
 end
 -- (the song over for the gag: its last tenth plays out, then it is stopped
 -- and let go -- not kept to the credits)
 if self.state~='sing'and song and song.state=='ending'then song:update(dt,t,self.game)end
 if self.state=='after'or self.state=='final'then
  -- (when its beats began, for the record)
  local b=self:postBeats()
  if not self.doodleT0 and self.post>=b.doodle then self.doodleT0=t end
  if not self.stompT and self.post>=b.stomp then self.stompT=t end
  -- the town snores on: as it looks round, as it starts drawing, at the last
  local once=self.onceFn
  if self.post>=.15 and once('snoreA')then self:play('snore1',.42,1)end
  if self.post>=b.doodle-.2 and once('snoreB')then self:play('snore2',.32,.92)end
  if self.post>=b.final+.3 and once('snoreC')then self:play('snore1',.38,1.08)end
  -- TEST243: the fireworks go up; their first bang wakes the town
  if self.post>=b.wake-PE.WAKE.lead and once('salvo')then
   local okF,err=pcall(self.fireworks,self,t)
   if not okF then log('the wake\'s fireworks failed: %s',tostring(err))end
  end
  if not self.wokeT and((self.bangT and t>=self.bangT)or self.post>=b.wake+PE.WAKE.fallback)then
   local okW,err=pcall(self.wakeUp,self,t)
   if not okW then log('the wake failed: %s',tostring(err));self.wokeT=self.wokeT or t end
  end
  for _,sw in ipairs(self.swellQ or EMPTY)do
   if not sw.done and t>=sw.t then sw.done=true;self:play('swell',sw.v,1)end
  end
 end
 self:updateJiggly(dt,t)
 self:updateSleepers(t)
 self:updateNotes(t)
 if(self.state=='after'or self.state=='final')and self.post>=self:postLen()then
  self.state='done';self.doneT=t
  -- (TEST243: the homecoming march, back for the wake, fades with the white)
  if self.musicBack then pcall(function()require('src.core.Music').fadeOut(PE.WAKE.musicFade)end)end
  log('the encore is over: the white, and the credits')
 end
end
function End:postLen()
 local T=PE.T
 return T.notice+T.puff+T.grin+T.cap+#self.targets*T.beat+T.stomp+T.final+T.wakeShot+T.awake
end
-- the beats after the song (their starts)
function End:postBeats()
 local T=PE.T
 local b=self.pb
 if b then return b end
 b={}
 local k=0
 b.notice=k;k=k+T.notice
 b.puff=k;k=k+T.puff
 b.grin=k;k=k+T.grin
 b.cap=k;k=k+T.cap
 b.doodle=k;k=k+#self.targets*T.beat
 b.stomp=k;k=k+T.stomp
 b.final=k;k=k+T.final
 -- (TEST243) the bang and the town waking up; the awake, doodled town
 b.wake=k;k=k+T.wakeShot
 b.awake=k;k=k+T.awake
 b.done=k
 self.pb=b
 return b
end

------------------------------------------------------------------ the sleepers, every frame
-- (TEST249) the eyes over a nod: closing as the head goes down (`peak` of
-- the way: heavier each time), snapping open at the catch
local function nodEyes(s,at,peak)
 local u=s-at
 if u<0 or u>1.1 then return 0 end
 if u<.82 then return peak*smooth(u/.34)end
 return peak*(1-smooth((u-.82)/.16))
end
PE.NOD_EYES={.6,.8,.95}
-- a nod: down, held, then up with a start
local function nodAngle(s,at)
 local u=s-at
 if u<0 or u>1.1 then return 0,0 end
 if u<.38 then return .26*smooth(u/.38),0 end
 if u<.82 then return .26,0 end
 local v=(u-.82)/.28
 return .26*(1-smooth(v*1.6))-.06*sin(pi*clamp01(v)),.5*sin(pi*clamp01(v))
end
function End:angleOf(s,S,clock)
 -- swaying to the song while awake (a little more as they tire)
 local sway=0
 if self.state=='sing'or self.state=='arrive'then
  sway=.022*sin(clock*1.6+(s.seed or 0))*smooth((S or 0)/6)
 end
 local a,y,fwd=0,0,false
 if s.nods then
  for _,n in ipairs(s.nods)do
   local na,ny=nodAngle(S,n)
   if na~=0 or ny~=0 then a,y,fwd=na,ny,true end
  end
 end
 if s.at and S>=s.at then
  local tau=S-s.at
  if s.how=='droop'then
   a=EG().dozeAngle(clamp01(tau/1.6),s.A,clock,s.seed);fwd=true
  else
   a=EG().fallAngle(tau,s.A,PE.FALL_DUR);fwd=false
   if not s.restBird and tau>PE.FALL_DUR*.75 then a=a+.012*sin(clock*1.3+(s.seed or 0))end
  end
  return a,y,fwd
 end
 if a==0 and sway~=0 then return abs(sway),0,sway>0 end
 return a,y,fwd
end
function End:updateSleepers(t)
 local CPm=CP()
 if not CPm then return end
 -- (TEST243: woken by the fireworks)
 if self.wokeT then return self:updateWaking(t,CPm)end
 local S=self.S or 0
 if self.state=='after'or self.state=='final'or self.state=='done'then S=1e6 end
 local clock=self.clock
 local asleep,n=0,0
 local list=self.people or EMPTY
 for i=1,#list do
  local p=list[i]
  local a,y,fwd=self:angleOf(p,S,clock)
  local yw=YAW[p.facing]or 0
  local fx,fz=sin(yw),cos(yw)
  if a~=0 or y~=0 then
   local o=p.opts or{};p.opts=o
   o.y=y
   -- Authored half/closed-eye frames, held through the doodles and cleared
   -- with the pose on skip, stop change or release.
   o.eyes=p.at and smooth((S-p.at+.12)/.38)or 0
   -- Town Pokemon need the sleep animation, not just a tilted body.
   o.sleep=p.at~=nil and S>=p.at
   if fwd then CPm.pose(p.npc,a,fx,fz,o)else CPm.pose(p.npc,a,p.dx,p.dz,o)end
  else CPm.pose(p.npc,nil)end
  self:fellCheck(p,S,t)
  n=n+1;if p.at and S>=p.at+.6 then asleep=asleep+1 end
 end
 local pl=self.player
 if pl then
  pl.at=self.playerAt;pl.nods=self.playerNods
  local a,y,fwd=self:angleOf(pl,S,clock)
  local yw=pl.yaw or 0
  local fx,fz=sin(yw),cos(yw)
  if a~=0 or y~=0 then
   local o=pl.opts or{};pl.opts=o
   o.y,o.yaw=y,yw
   o.eyes=pl.at and smooth((S-pl.at+.12)/.38)or 0
   -- (TEST249: the eyes close over each nod -- he is fighting it)
   for k,n in ipairs(pl.nods or EMPTY)do
    o.eyes=max(o.eyes,nodEyes(S,n,PE.NOD_EYES[k]or 1))
   end
   if pl.watch and pl.watch.height and pl.watch.height>2 then o.head=pl.watch.height*.82 end
   o.x,o.z=0,0
   if self.ride then
    local h=pl.watch and pl.watch.height or pl.H
    local rear=self.P.float.rear or -9
    local slide=max(0,h*sin(pl.A)+rear+3)*smooth((S-pl.at)/PE.FALL_DUR)
    o.x,o.z=sin(yw)*slide,cos(yw)*slide
    o.lift=2.4
   end
   if fwd then CPm.pose('player',a,fx,fz,o)else CPm.pose('player',a,pl.dx,pl.dz,o)end
  else CPm.pose('player',nil)end
  self:fellCheck(pl,S,t)
  n=n+1;if S>=(pl.at or 1e9)+.6 then asleep=asleep+1 end
 end
 local pa=self.partner
 if pa then
  pa.at=self.partnerAt
  if S>=pa.at then
   local a=EG().fallAngle(S-pa.at,pa.A,PE.FALL_DUR)
   local okF,x,_,_,yw,h=pcall(CPm.feetOf,'partner',self.game)
   if not(okF and tonumber(yw))then yw=0 end
   local o=pa.opts or{};pa.opts=o
   o.sleep=true;o.x,o.z=0,0
   if self.ride then
    local fl=self.P.float
    local height=fl.partner and fl.partner.model and fl.partner.model.top or (h or 7)/.72
    local pz=fl.layout and fl.layout.pz or 0
    local slide=max(0,height*sin(pa.A)+(fl.rear or -9)-pz+2)*smooth((S-pa.at)/PE.FALL_DUR)
    o.x,o.z=sin(yw)*slide,cos(yw)*slide
   end
   CPm.pose('partner',a,-sin(yw),-cos(yw),o)
   if not pa.slept then
    pa.slept=true
    -- The render path chooses the current follower's native sleep context;
    -- this full fall also covers missing clips and sprite-card fallbacks.
    if self.eggs.zz then self.eggs.zz:add('partner',t,7)end
   end
  end
  n=n+1;if S>=(pa.at or 1e9)+.6 then asleep=asleep+1 end
 end
 self.asleepFrac=n>0 and asleep/n or 0
end
------------------------------------------------------------------ TEST243: the fireworks wake the town
-- How someone gets up (w s since their wake began; aw the angle they lay at,
-- along the way they lie): anyone lying springs up (the eggs' wake curve for
-- a fall) and then, upright, either starts (a jerk back and a hop) or
-- stretches (a lean back and a rise); anyone leaning or drooping wakes with
-- the eggs' own start or stretch. Returns the angle (along the way they lay),
-- the hop, and true when done.
function PE.wakePose(w,aw,how,style)
 local EGm=EG()
 if how=='fall'or(aw or 0)>.9 then
  if w<.6 then local a,y=EGm.wakeCurve(w,aw,'start','fall');return a,y,false end
  local a,y,done=EGm.wakeCurve(w-.6,0,style or'stretch','droop')
  return-a,y,done
 end
 return EGm.wakeCurve(w,aw or 0,style or'start','droop')
end
-- the last shot's two faces (by role: Professor Oak and your rival; else two
-- of the doodled), where they stand and the way they look once up again
function End:wakeFaces()
 local pick,used={},{}
 for _,role in ipairs(PE.WAKE.faces)do
  for _,p in ipairs(self.people or EMPTY)do if p.role==role and not used[p]then pick[#pick+1]=p;used[p]=true;break end end
 end
 for _,tg in ipairs(self.targets or EMPTY)do
  local sl=tg.sl
  if #pick<2 and sl.npc and sl.x and not used[sl]then pick[#pick+1]=sl;used[sl]=true end
 end
 local out={}
 for _,p in ipairs(pick)do
  local yw=YAW[p.facing]or 0
  local gy=groundAt(self.map,p.x,p.z)
  out[#out+1]={p=p,x=p.x,y=gy+(p.H or 21.8)*.84,z=p.z,gy=gy,nx=sin(yw),nz=cos(yw)}
 end
 return out
end
-- is a camera at x,z (eye height y) clear: no wall cell, not in the float,
-- not in anybody standing there
function End:eyeClear(x,z)
 if self:wallAt(x,z,true)then return false end
 if self:inFloat(x,z,1.5)then return false end
 -- (a margin round the lens: a house's eaves overhang its wall)
 local m=PE.WAKE.eyeMargin
 for _,o in ipairs({{m,0},{-m,0},{0,m},{0,-m},{m*.7,m*.7},{-m*.7,m*.7},{m*.7,-m*.7},{-m*.7,-m*.7}})do
  if self:wallAt(x+o[1],z+o[2],false)then return false end
 end
 local R=PE.WAKE.bodyClear
 for _,p in ipairs(self.people or EMPTY)do
  if p.x and(p.x-x)^2+(p.z-z)^2<R*R then return false end
 end
 local pl=self.player
 if pl and pl.x and(pl.x-x)^2+(pl.z-z)^2<R*R then return false end
 return true
end
-- the plan of the wake's two shots (worked out as the fireworks go up). Up
-- again, the two faces turn to the camera -- the TV crew's, the parade is
-- LIVE -- one of the four ways the people of this world face (the one with
-- the clearest view: no wall, the float or anybody between, the pair side by
-- side across the picture); the camera that far in front of them, a little
-- off to one side if that shows them better; the shells burst behind them
-- as the camera sees them, high up
local PLAN_DL={0,.25,-.25,.45,-.45,.65,-.65}
-- (the walls between the lens and a face: a fence or a sign -- one cell of
-- them, low -- the camera sees over; anything thicker is a house)
function End:rayClear(ax,az,bx,bz,ay,by)
 local L=sqrt((bx-ax)^2+(bz-az)^2)
 local n=max(1,floor(L/4))
 local run=0
 for k=1,n-1 do
  local u=k/n
  -- (from up high -- ay, by: the heights at the ends -- a ray over the roofs
  -- is clear; houses here are about PE.WAKE.roofH tall to the ridge)
  local high=ay and by and(ay+(by-ay)*u)>PE.WAKE.roofH
  if not high and self:wallAt(ax+(bx-ax)*u,az+(bz-az)*u,false)then
   run=run+L/n
   if run>23 then return false end
  else run=0 end
 end
 return true
end
-- (TEST249) the share (0..1) of the shells hidden behind roofs, from a lens
-- D in front of the faces' centre (cx,cz; ground gy) the way (dx,dz), its
-- eye at height ey
function End:skyHidden(cx,cz,gy,dx,dz,D,ey,shift)
 local W=PE.WAKE
 local ex,ez=cx+dx*D,cz+dz*D
 local dist=W.back+D
 local cEl=atan2(gy+W.up-ey,dist)
 local rEl=atan2(W.burstR,dist)
 local total=0
 local fan=W.skyFan
 for _,off0 in ipairs(fan)do
  local off=off0+(shift or 0)
  local c,s_=cos(off),sin(off)
  local bx,bz=-dx*c-dz*s_,dx*s_-dz*c
  local sky,run=-1e9,0
  -- (TEST255: from beside the lens, not only past the faces)
  local r=W.skyNear or(D+W.skyStep)
  while r<=D+W.skyReach do
   if self:wallAt(ex+bx*r,ez+bz*r,false)then
    run=run+W.skyStep
    if run>=W.skyRun then sky=max(sky,atan2(gy+W.roofH-ey,r))end
   else run=0 end
   r=r+W.skyStep
  end
  total=total+clamp01((sky-(cEl-rEl))/(2*rEl))
 end
 return total/#fan
end
-- (TEST253) what anyone else standing big in the picture costs, from a lens
-- at (ex,ez) looking at the faces' centre (cx,cz) D away; `mine`: the faces
-- (TEST257) everyone who could stand in the close-up: the stop's people and
-- any other townsperson about (not you, not your partner); `fixed`: those who
-- may not be moved out of the shot (Oak, the rival, you, your partner)
function End:extras()
 local list,seen={},{}
 local ow=self.game and self.game.overworld
 local player=ow and ow.player
 for _,p in ipairs(self.people or EMPTY)do
  if p.npc then seen[p.npc]=true end
  list[#list+1]={npc=p.npc,p=p,x=p.x,z=p.z,H=p.H,fixed=(p.role=='oak'or p.role=='rival')}
 end
 for _,group in ipairs({ow and ow.npcs or EMPTY,ow and ow.entities or EMPTY})do
  for _,e in ipairs(group)do
   if type(e)=='table'and not seen[e]and e~=player and type(e.def)=='table'and e.def.sprite
    and(e.px or e.cellX)and not isFollower(e)then
    seen[e]=true
    local spr=tostring(e.def.sprite)
    local x,z=personAt(e)
    list[#list+1]={npc=e,x=x,z=z,H=heightOf(spr),fixed=(ROLE[spr]=='oak'or ROLE[spr]=='rival')}
   end
  end
 end
 local pl=self.player
 if pl and pl.x then list[#list+1]={p=pl,x=pl.x,z=pl.z,H=pl.watch and pl.watch.height or pl.H,fixed=true}end
 local pa=self.partner
 if pa and pa.x then list[#list+1]={p=pa,x=pa.x,z=pa.z,H=pa.H or 9,fixed=true}end
 return list
end
-- (TEST257) who of `list` shows in a camera's picture (eye, focus, fov
-- degrees vertical), nearer than `far` x fgNear and bigger than `minSize` of
-- its half-height (any of head, chest, legs, within `margin` of the edge);
-- `mine`: the faces (left out). Returns {item, how big} pairs.
function End:intruders(list,eye,focus,fov,far,mine,minSize,margin)
 local W=PE.WAKE
 local out={}
 local fx,fy,fz=focus[1]-eye[1],focus[2]-eye[2],focus[3]-eye[3]
 local fl=sqrt(fx*fx+fy*fy+fz*fz)
 if fl<1e-3 then return out end
 fx,fy,fz=fx/fl,fy/fl,fz/fl
 local rx,rz=fz,-fx
 local rl=sqrt(rx*rx+rz*rz)
 if rl<1e-6 then return out end
 rx,rz=rx/rl,rz/rl
 local ux,uy,uz=-rz*fy,rz*fx-rx*fz,rx*fy
 local th=math.tan(math.rad(fov)*.5)
 local asp=PE.CLOSE.aspect or 16/9
 local edge=1+(margin or 0)
 for _,it in ipairs(list)do
  if not(it.p and mine[it.p])and it.x and it.z then
   local H=tonumber(it.H)or 21.8
   local gy=groundAt(self.map,it.x,it.z)
   local big=0
   for k=1,3 do
    local y,r
    if k==1 then y,r=gy+H*W.fgHeadY,H*W.fgHead*.5
    elseif k==2 then y,r=gy+H*.55,H*.20
    else y,r=gy+H*.25,H*.14 end
    local px,py,pz=it.x-eye[1],y-eye[2],it.z-eye[3]
    local d=px*fx+py*fy+pz*fz
    if d+r>.5 and d<far*W.fgNear then
     d=max(d,.5)
     local sx=(px*rx+pz*rz)/d/(th*asp)
     local sy=(px*ux+py*uy+pz*uz)/d/th
     local rr=r/d/th
     if abs(sx)-rr/asp<edge and abs(sy)-rr<edge and rr>minSize then big=max(big,rr)end
    end
   end
   if big>0 then out[#out+1]={it,big}end
  end
 end
 return out
end
-- what the foreground costs a camera: anyone who cannot be moved (you, your
-- partner) at full weight; townsfolk, who will be moved, a little
function End:foreground(eye,focus,fov,far,mine,list)
 local W=PE.WAKE
 local cost,n=0,0
 for _,hit in ipairs(self:intruders(list or self:extras(),eye,focus,fov,far,mine,W.fgSize,W.fgMargin))do
  local it,big=hit[1],hit[2]
  n=n+1
  if it.fixed then cost=cost+W.fgBase+W.fgK*min(1,big/.35)
  else cost=cost+W.hideCost+W.hideK*min(1,big/.35)end
 end
 return cost,n
end
-- (TEST257) as the close-up starts: keep out of it every townsperson who would
-- show big in its foreground at either end of its move. One set, fixed for
-- the shot; put back by unhideForeground.
function End:hideForeground(sh)
 self:unhideForeground()
 local CPm=CP()
 if not(CPm and CPm.hide and type(sh)=='table'and sh.from and sh.to)then return 0 end
 local W=PE.WAKE
 local mine={}
 local F=self.wakePlan and self.wakePlan.faces
 for _,f in ipairs(F or EMPTY)do mine[f.p]=true end
 local list=self:extras()
 local set={}
 for _,cam in ipairs({sh.from,sh.to})do
  if cam.eye and cam.focus and cam.fov then
   local far=sqrt((cam.focus[1]-cam.eye[1])^2+(cam.focus[3]-cam.eye[3])^2)
   for _,hit in ipairs(self:intruders(list,cam.eye,cam.focus,cam.fov,far,mine,W.hideSize,W.hideMargin))do
    local it=hit[1]
    if not it.fixed and it.npc then set[it.npc]=true end
   end
  end
 end
 local hid={}
 for npc in pairs(set)do if CPm.hide(npc)then hid[#hid+1]=npc end end
 self.hiddenSet=hid
 if #hid>0 then log('the awake close-up: %d townsperson(s) kept out of the foreground',#hid)end
 return #hid
end
function End:unhideForeground()
 local hid=self.hiddenSet
 if not hid then return end
 self.hiddenSet=nil
 local CPm=CP()
 if CPm and CPm.hide then for _,npc in ipairs(hid)do pcall(CPm.hide,npc,false)end end
end
local function segNear(ax,az,bx,bz,px,pz)
 local ex,ez=bx-ax,bz-az
 local l2=ex*ex+ez*ez
 local u=l2>0 and max(0,min(1,((px-ax)*ex+(pz-az)*ez)/l2))or 0
 local qx,qz=ax+ex*u-px,az+ez*u-pz
 return sqrt(qx*qx+qz*qz),u
end
function End:planWake()
 local W=PE.WAKE
 local F=self:wakeFaces()
 if #F==0 then return nil end
 local cx,cy,cz,gy=0,0,0,0
 for _,f in ipairs(F)do cx,cy,cz,gy=cx+f.x,cy+f.y,cz+f.z,gy+f.gy end
 cx,cy,cz,gy=cx/#F,cy/#F,cz/#F,gy/#F
 local mine={}
 for _,f in ipairs(F)do mine[f.p]=true end
 local extras=self:extras()
 local tH=math.tan(math.rad(W.fov[2])*.5)*(PE.CLOSE.aspect or 16/9)
 local best=nil
 for fi,fc in ipairs({'down','left','right','up'})do
  local yw=YAW[fc]
  local fx,fz=sin(yw),cos(yw)
  for _,dl in ipairs(PLAN_DL)do
   local c,s_=cos(dl),sin(dl)
   local dx,dz=fx*c+fz*s_,-fx*s_+fz*c
   local sep,dep=0,0
   if #F>1 then
    sep=abs((F[2].x-F[1].x)*dz-(F[2].z-F[1].z)*dx)
    dep=abs((F[2].x-F[1].x)*dx+(F[2].z-F[1].z)*dz)   -- (TEST247: one nearer than the other)
   end
   local D0=max(W.dMin,min(W.dMax,(.5*sep+W.pad)/tH+3))
   -- (TEST247: the nearer face no closer than dMin)
   D0=min(W.dMax,max(D0,W.dMin+.5*dep))
   -- (a step or two further back if the spot itself is taken: a fence, a sign)
   for _,more in ipairs({0,5,10})do
    local D=min(W.dMax,D0+more)
    local ex,ez=cx+dx*D,cz+dz*D
    local clear=self:eyeClear(ex,ez)and self:eyeClear(cx+dx*D*W.push,cz+dz*D*W.push)
    for _,f in ipairs(F)do if clear and not self:rayClear(ex,ez,f.x,f.z)then clear=false end end
    -- nobody (and nothing) between the lens and either face
    local blocked=false
    for _,f in ipairs(F)do
     for _,p in ipairs(self.people or EMPTY)do
      if not mine[p]and p.x then
       local d,u=segNear(ex,ez,f.x,f.z,p.x,p.z)
       if d<6.0 and u<.97 then blocked=true end
      end
     end
     local pl=self.player
     if pl and pl.x then local d,u=segNear(ex,ez,f.x,f.z,pl.x,pl.z);if d<6.0 and u<.97 then blocked=true end end
     for k=1,7 do
      local u=k/8
      if self:inFloat(ex+(f.x-ex)*u,ez+(f.z-ez)*u,.5)then blocked=true end
     end
     -- (and one face not right behind the other)
     for _,g_ in ipairs(F)do
      if g_~=f then local d,u=segNear(ex,ez,f.x,f.z,g_.x,g_.z);if d<3.5 and u<.97 then blocked=true end end
     end
    end
    local hid=self:skyHidden(cx,cz,gy,dx,dz,D,cy-W.below)
    -- (TEST253: nobody else big in the picture, at either end of the move)
    -- (the shot's own cameras, as wakeShot makes them)
    local ey_=cy-W.below
    local foc={cx,cy+D*math.tan(math.rad(W.tilt)),cz}
    local fg1,n1=self:foreground({ex,ey_,ez},foc,W.fov[2],D,mine,extras)
    local fg2,n2=self:foreground({cx+dx*D*W.push,ey_,cz+dz*D*W.push},foc,W.fov[1],D*W.push,mine,extras)
    local fg,fgN=max(fg1,fg2),max(n1,n2)
    local score=(#F>1 and min(sep,22)or 0)-9*abs(dl)-(fi-1)*1.5-.3*more+(clear and 0 or-1000)+(blocked and-200 or 0)-fg
     -min(W.depthMax or 1e9,(W.depthK or 0)*max(0,dep-(W.depthOK or 0)))-(W.skyK or 0)*hid
    if PE.DEBUG_PLAN then PE.DEBUG_PLAN[#PE.DEBUG_PLAN+1]=('%s %.2f D%.1f sep%.1f clear %s blocked %s score %.1f'):format(fc,dl,D,sep,tostring(clear),tostring(blocked),score)end
    if not best or score>best.score then best={score=score,dx=dx,dz=dz,D=D,clear=clear,blocked=blocked,sep=sep,dep=dep,dl=dl,facing=fc,hid=hid,fgN=fgN}end
    if clear then break end
   end
  end
 end
 if not best.clear then return nil end
 local pl={faces=F,cx=cx,cy=cy,cz=cz,dx=best.dx,dz=best.dz,D=best.D,sep=best.sep,dep=best.dep,dl=best.dl,facing=best.facing,blocked=best.blocked,skyHidden=best.hid,foregroundN=best.fgN}
 pl.burst={cx-best.dx*W.back,gy+W.up,cz-best.dz*W.back}
 -- (TEST255: the fan slid toward the open side, if that hides less)
 do
  local bestS,bestH=0,best.hid or 0
  local m=W.fanShift or 0
  if m>0 and bestH>0 then
   for _,sh in ipairs({-m,-m/2,m/2,m})do
    local h=self:skyHidden(cx,cz,gy,best.dx,best.dz,best.D,cy-W.below,sh)
    if h<bestH-.02 then bestS,bestH=sh,h end
   end
  end
  if bestS~=0 then
   local lat=bestS*(W.back+best.D)
   pl.burst[1]=pl.burst[1]-best.dz*lat
   pl.burst[3]=pl.burst[3]+best.dx*lat
  end
  pl.fanShift=bestS;pl.skyHidden=bestH
 end
 self.wakePlan=pl
 log('the wake\'s shots: the faces turn %s, the camera %.0f away (%.2f rad off; %.0f apart across, %.0f in depth; %.0f%% of the shells behind roofs; %d others near the lens; %s)',best.facing,best.D,best.dl,best.sep or 0,best.dep or 0,(best.hid or 0)*100,best.fgN or 0,best.blocked and'partly blocked'or'a clear view')
 return pl
end
-- the stop's finale salvo again, over the plan's spot (else where the stop
-- fires it); when its first shell bursts
function End:fireworks(t)
 local P=self.P
 local stop=P:stop()
 local def=stop and stop.finale and stop.finale.salvo
 local okP,plan=pcall(self.planWake,self)
 if not okP then log('the wake\'s shots could not be fitted: %s',tostring(plan));plan=nil end
 if not(def and def.n and def.n>0)then log('the wake: no salvo at this stop');return end
 local fired=false
 pcall(function()
  local c=plan and plan.burst
  if not c then
   local E_=P:roadEnd(stop)
   local r=def.rel or{0,170,0}
   c={E_[1]+r[1],E_[2]+r[2],E_[3]+r[3]}
  end
  self.burstAt=c
  local CPm=V.require('ChampionParade')
  local t0=now()+.2
  local list=CPm.shellsAt(stop.map,c,def.n,t0,def.spacing or .6,def.scale)
  if plan then
   -- TEST245: fit the actual final camera. The old 100-160 radius bursts
   -- just 110 behind the faces mostly opened above its narrow lens. Put a
   -- fan of complete bursts in the sky behind the pair, with visible sparks
   -- and a gentle fall; retain the stop's shell count and bang/wake timing.
   local distance=PE.WAKE.back+plan.D
   for i,s in ipairs(list)do
    local across=#list>1 and (i-1)/(#list-1)*2-1 or 0
    local side=across*distance*.32
    s.bx=c[1]+plan.dz*side;s.bz=c[3]-plan.dx*side
    s.by=c[2]+(s.by-c[2])*.35
    s.R=70+(s.R-100)*.24
    s.lx=s.bx;s.ly=s.by-100;s.lz=s.bz
    s.sparkScale=1.5;s.gravityScale=.24;s.bright=1.35
   end
  end
  V.require('LeagueRoad').salvo(stop.map,list)
  local first=1e9
  for _,sh in ipairs(list)do first=min(first,(sh.launchT or t0)+(sh.rise or 1.15))end
  self.bangT=t+(first-now())
  self.salvoN=#list
  fired=true
 end)
 if not fired then
  pcall(P.salvo,P,stop,def)
  self.bangT=t+1.4
 end
 log('the wake: the fireworks go up over Pallet (%s; the first bang in %.2f s)',plan and'over the last shot'or'the stop\'s own spot',(self.bangT or t)-t)
end
-- the first bang: everyone wakes (the family first, then your partner and
-- you, then the townsfolk), the Zz stop, the cannons, the cheer and the march
function End:wakeUp(t)
 if self.wokeT then return end
 self.wokeT=t
 local W=PE.WAKE
 local order={}
 local rank={rival=1,oak=2,mom=3}
 local fam,town={},{}
 for _,p in ipairs(self.people or EMPTY)do if rank[p.role]then fam[#fam+1]=p else town[#town+1]=p end end
 table.sort(fam,function(a,b)return rank[a.role]<rank[b.role]end)
 for _,p in ipairs(fam)do order[#order+1]=p end
 if self.partner then order[#order+1]=self.partner end
 if self.player then order[#order+1]=self.player end
 for _,p in ipairs(town)do order[#order+1]=p end
 local CPm=CP()
 for k,s_ in ipairs(order)do
  s_.wt0=t+W.gap*(k-1)
  local rec=CPm and CPm.poseOf and CPm.poseOf(s_.key=='player'and'player'or(s_.key=='partner'and'partner'or s_.npc))
  local a=rec and tonumber(rec.a)or s_.A or 0
  s_.aw=max(0,a)
  s_.style=(k%2==1)and'start'or'stretch'
  s_.up=false
  if self.eggs.zz then self.eggs.zz:remove(s_.key,t)end
 end
 self.waking=order
 -- (the last shot's two faces turn to the camera as they get up)
 local pl=self.wakePlan
 if pl then for _,f in ipairs(pl.faces)do f.p.turnTo=pl.facing end end
 -- (the snores stop; Jigglypuff is long gone)
 self:silence()
 -- the float's cannons (riding) or the confetti thrown down (walking)
 local P=self.P
 pcall(function()P:cannonsFire(P:stop(),true)end)
 P.cheering=true
 if self.song then pcall(self.song.unduck,self.song,t)end
 self.swellQ={}
 for _,sw in ipairs(W.swells)do self.swellQ[#self.swellQ+1]={t=t+sw[1],v=sw[2]}end
 -- your partner cheers on the float once it is up
 if self.ride and P.float then pcall(P.float.cheer,P.float,t+W.gap*#order+1.3)end
 -- the homecoming march, again
 if W.music then
  pcall(function()
   local Music=require('src.core.Music')
   local songs=self.game.data and self.game.data.audio and self.game.data.audio.songs
   if songs and songs.Music_ChampionParadeHome then
    Music.play(self.game.data,'Music_ChampionParadeHome',false,{reason='parade'})
    self.musicBack=true
   end
  end)
 end
 log('the wake: the first bang -- %d wake up (doodles and all)',#order)
end
-- every frame once woken: up they get, eyes open, and then upright as ever
function End:updateWaking(t,CPm)
 local list=self.waking or EMPTY
 local up=0
 for _,s_ in ipairs(list)do
  if s_.up then up=up+1
  else
   local w=t-(s_.wt0 or t)
   local key=s_.key=='player'and'player'or(s_.key=='partner'and'partner'or s_.npc)
   if w>=0 then
    local a,y,done=PE.wakePose(w,s_.aw,s_.how,s_.style)
    -- (up off the ground -- or done -- they turn to the camera, if asked)
    if s_.turnTo and not s_.turned and s_.npc and(done or((s_.how=='fall'or(s_.aw or 0)>.9)and w>=.6))then
     s_.turned=true
     local f=s_.turnTo
     s_.npc.facing=f;s_.npc.pinnedFacing=f;s_.turnedTo=f
     local yw=YAW[f]or 0
     s_.wdx,s_.wdz=-sin(yw),-cos(yw)
    end
    if done then
     s_.up=true;up=up+1
     CPm.pose(key,nil)
     if CPm.lodReset then pcall(CPm.lodReset,key)end
    else
     local o=s_.opts or{};s_.opts=o
     o.y=y;o.eyes=0;o.sleep=false
     -- (riding, the slide back along the dais goes back as they sit up)
     if o.x and o.z and(s_.aw or 0)>1e-3 then
      local k=clamp01(a/s_.aw)
      s_.slideX=s_.slideX or o.x;s_.slideZ=s_.slideZ or o.z
      o.x,o.z=s_.slideX*k,s_.slideZ*k
     end
     local dx,dz=s_.wdx or s_.dx,s_.wdz or s_.dz
     if key=='partner'then
      local okF,_,_,_,yw=pcall(CPm.feetOf,'partner',self.game)
      if not(okF and tonumber(yw))then yw=0 end
      dx,dz=-sin(yw),-cos(yw)
     end
     CPm.pose(key,a,dx,dz,o)
    end
   end
  end
 end
 self.asleepFrac=0
 if up==#list and not self.allUpT then self.allUpT=t;log('the wake: everyone is up')end
end
-- the wake's two shots: the bang (going on from the end of the last wide
-- over the sleeping town, turning up to the shells as they burst) and the
-- awake town (close on the two faces, looking up a little at the sky)
function End:wakeShot(key)
 local W=PE.WAKE
 local pl=self.wakePlan
 if key=='wakeup'then
  local mode=self.ride and'ride'or'walk'
  local c=PE.CAM[mode].final
  local a=self:camEnd(c.to,c.to.J)
  local B=pl and pl.burst or self.burstAt
  if not B then return nil end
  local f=a.focus
  local u=W.wideTurn
  local f1={f[1]+(B[1]-f[1])*u,f[2]+(B[2]-f[2])*u,f[3]+(B[3]-f[3])*u}
  return{kind='crane',dur=PE.T.wakeShot+.3,from={eye=a.eye,focus=f1,fov=c.fov[2],world=true},
   to={eye={a.eye[1],a.eye[2]+4,a.eye[3]},focus=B,fov=W.wideFov,world=true},name='encore wakeup',shake=.10}
 end
 if not pl then return nil end
 local cx,cy,cz,dx,dz=pl.cx,pl.cy,pl.cz,pl.dx,pl.dz
 local D=pl.D
 local ey=cy-W.below
 local lift=D*math.tan(math.rad(W.tilt))
 local f={cx,cy+lift,cz}
 local D0=D*W.push
 return{kind='crane',dur=PE.T.awake+1.6,from={eye={cx+dx*D0,ey,cz+dz*D0},focus=f,fov=W.fov[1],world=true},
  to={eye={cx+dx*D,ey,cz+dz*D},focus=f,fov=W.fov[2],world=true},name='encore awake',shake=.05}
end
-- someone has just landed: a soft thud, a puff of dust; Zz once asleep
function End:fellCheck(s,S,t)
 if not s.at then return end
 if not s.thud and S>=s.at+PE.FALL_DUR*.75 then
  s.thud=true
  if s.how~='droop'then self:play('thud',s.how=='fall'and .55 or .35,.9+.2*hash(s.seed or 1,3))end
  if s.how=='fall'and s.x then
   local gy=groundAt(self.map,s.x,s.z)
   self:puffDust(s.x+s.dx*s.H*.55,gy+.5,s.z+s.dz*s.H*.55,t,2)
  end
 end
 if not s.zz and S>=s.at+PE.FALL_DUR+.4 then
  s.zz=true
  if self.eggs.zz then self.eggs.zz:add(s.key,t,s.seed)end
 end
end

------------------------------------------------------------------ Jigglypuff
function End:singAnim()
 local md=self.actor and self.actor.md
 if not md then return end
 local ok=false
 pcall(function()ok=md.inst:playMove(PE.SING_MOVE,true)and true or false end)
 if ok then md.context='move';md.once=nil;md.tick=nil else pcall(HF().playTeamModel,md,'idle',false)end
end
-- where the marker draws on a target now (world), and the face
-- a direction through a matrix, made unit
local function mdir(M,a,b,c)
 local vx,vy,vz=M[1]*a+M[2]*b+M[3]*c,M[5]*a+M[6]*b+M[7]*c,M[9]*a+M[10]*b+M[11]*c
 local l=sqrt(vx*vx+vy*vy+vz*vz);if l<1e-9 then l=1 end
 return vx/l,vy/l,vz/l
end
function End:faceFrame(tg,use)
 local sl=tg.sl
 local rec=sl.watch
 tg.exact=false
 if not faceKnown(sl)then return nil end
 -- Camera acquisition may aim at the last observed face. Ink must have a
 -- body submitted in THIS world pass; animation can use the preceding one.
 if use~='aim'then
  local age=frameSerial-rec.serial
  if rec.hidden or age<0 or age>(use=='ink'and 0 or 1)then return nil end
 end
 local m=tg.m or mat()
 tg.m=m
 local F=rec and rec.n and PE.FACES[rec.n]
 local Fs=rec and rec.face
 if Fs and not F then
  local M=rec.M
  local x,y,z=Fs[1],Fs[2],Fs[3]
  local cx=M[1]*x+M[2]*y+M[3]*z+M[4]
  local cy=M[5]*x+M[6]*y+M[7]*z+M[8]
  local cz=M[9]*x+M[10]*y+M[11]*z+M[12]
  local nx,ny,nz=mdir(M,Fs[4],Fs[5],Fs[6])
  local ux,uy,uz=mdir(M,Fs[7],Fs[8],Fs[9])
  local rx,ry,rz=uy*nz-uz*ny,uz*nx-ux*nz,ux*ny-uy*nx
  local u=Fs[10]
  m[1],m[2],m[3],m[4]=rx*u,ux*u,nx*u,cx
  m[5],m[6],m[7],m[8]=ry*u,uy*u,ny*u,cy
  m[9],m[10],m[11],m[12]=rz*u,uz*u,nz*u,cz
  m[13],m[14],m[15],m[16]=0,0,0,1
  tg.exact=true
  local C,N,U=tg.c or{},tg.n or{},tg.u or{}
  C[1],C[2],C[3],N[1],N[2],N[3],U[1],U[2],U[3]=cx,cy,cz,nx,ny,nz,ux,uy,uz
  tg.c,tg.n,tg.u,tg.unit=C,N,U,u
  return m
 end
 if F then
  local M=rec.M
  local x,y,z=F[2],F[3],F[5]
  local cx=M[1]*x+M[2]*y+M[3]*z+M[4]
  local cy=M[5]*x+M[6]*y+M[7]*z+M[8]
  local cz=M[9]*x+M[10]*y+M[11]*z+M[12]
  local sx=sqrt(M[1]*M[1]+M[5]*M[5]+M[9]*M[9])
  local u=F[4]*sx
  -- axes: the mesh's own x (to the viewer's right), y (up the face), z (out)
  local rx,ry,rz=mdir(M,1,0,0)
  local ux,uy,uz=mdir(M,0,1,0)
  local nx,ny,nz=mdir(M,0,0,1)
  m[1],m[2],m[3],m[4]=rx*u,ux*u,nx*u,cx
  m[5],m[6],m[7],m[8]=ry*u,uy*u,ny*u,cy
  m[9],m[10],m[11],m[12]=rz*u,uz*u,nz*u,cz
  m[13],m[14],m[15],m[16]=0,0,0,1
  tg.exact=true
  local C,N,U=tg.c or{},tg.n or{},tg.u or{}
  C[1],C[2],C[3],N[1],N[2],N[3],U[1],U[2],U[3]=cx,cy,cz,nx,ny,nz,ux,uy,uz
  tg.c,tg.n,tg.u,tg.unit=C,N,U,u
  return m
 end
 return nil
end
-- the drawing's pen point in the world (face units -> world)
local function facePoint(m,x,y,z)
 return m[1]*x+m[2]*y+m[3]*z+m[4],m[5]*x+m[6]*y+m[7]*z+m[8],m[9]*x+m[10]*y+m[11]*z+m[12]
end
PE._facePoint=facePoint

function End:updateJiggly(dt,t)
 local st=self.state
 local J=self.perch
 local T=PE.T
 self.scale,self.sq,self.red,self.mic,self.anger,self.pitch,self.roll,self.look=1,1,0,0,0,0,0,0
 self.vanish=0
 self.marker=0
 local md=self.actor and self.actor.md
 if md then pcall(HF().stepTeamModel,md,t,30)end
 -- facing the camera (turning toward it; a cut turns it at once)
 local P=self.P
 local cam=P.cam
 local wantYaw=self.yaw or 0
 local x0,z0=self.x or J[1],self.z or J[3]
 local ce=cam and cam.eye
 -- (TEST242: at a cut P.cam is still last frame's camera: turn to the new
 -- shot's own first eye, not to the old one and then round)
 local sh=P.shot
 if sh~=self.shotSeen and type(sh)=='table'and sh.from and sh.from.world and type(sh.from.eye)=='table'then ce=sh.from.eye end
 if ce and ce[1]and ce[3]then wantYaw=atan2(ce[1]-x0,ce[3]-z0)end
 if st=='arrive'then
  -- hop by hop from the gate, then up onto the perch
  local path=self.path
  local n=#path
  local hopT=T.hop
  local total=(n-1)*hopT
  local u=self.clock/(T.arrive-.55)
  local k=min(n-1,floor(u*(n-1)))
  local v=clamp01(u*(n-1)-k)
  local a,b=path[k+1],path[min(n,k+2)]
  if u>=1 then
   self.x,self.y,self.z=J[1],J[2],J[3]
   if not self.landed then
    self.landed=true;self:cry(1);self:play('hop',.5,1.15)
    if md then pcall(HF().playTeamModel,md,'entrance',true)end
   end
   local w=self.clock-(T.arrive-.55)
   self.sq=1-.22*sin(clamp01(w/.3)*pi)*(1-clamp01(w/.3))
   self.mic=EG()._backOut and EG()._backOut(clamp01((w-.25)/.3))or clamp01((w-.25)/.3)
  else
   local big=b.last and 9 or 5.5
   self.x=lerp(a[1],b[1],v);self.z=lerp(a[3],b[3],v)
   self.y=lerp(a[2],b[2],v)+big*4*v*(1-v)
   self.hopK=self.hopK or-1
   if k~=self.hopK then
    self.hopK=k
    if k>0 then self:play('hop',.28,1.0+.06*hash(k,2))end
   end
   wantYaw=atan2(b[1]-a[1],b[3]-a[3])
   if b.last then wantYaw=atan2((cam and cam.eye and cam.eye[1]or J[1])-J[1],(cam and cam.eye and cam.eye[3]or J[3]+1)-J[3])end
  end
 elseif st=='sing'then
  self.x,self.z=J[1],J[3]
  local S=self.S or 0
  local lvl=self.song.level and self.song:level()or .6
  self.y=J[2]+.45*abs(sin(S*4.8))*(.4+.6*lvl)
  self.look=.22*sin(S*1.2)
  self.roll=.08*sin(S*2.4+.6)
  self.mic=1
  self.sq=1+.04*lvl*sin(S*9.6)
 else
  self:updateAfter(t,wantYaw)
  wantYaw=self.wantYaw or wantYaw
 end
 if not self.yaw or P.shot~=self.shotSeen then self.yaw=wantYaw;self.shotSeen=P.shot
 else
  local d=(wantYaw-self.yaw+pi)%(2*pi)-pi
  self.yaw=self.yaw+d*min(1,(dt or 1/60)*5)
 end
 -- the dust
 for _,d in ipairs(self.dust)do if d.on and t-d.t0>.45 then d.on=false end end
end
-- after the song: notice, puff up, the cap, the doodles, the stomp
local STOMPS,STOMP_KEYS={.6,.9},{'stomp1','stomp2'}
function End:updateAfter(t,camYaw)
 local b=self:postBeats()
 local p=self.post or 0
 local T=PE.T
 local J=self.perch
 local md=self.actor and self.actor.md
 self.wantYaw=camYaw
 self.mic=1
 local once=self.onceFn
 if p<b.puff then
  -- it stops, opens its eyes, looks round
  if once('notice')and md then pcall(HF().playTeamModel,md,'idle',false)end
  self.x,self.y,self.z=J[1],J[2],J[3]
  local u=p/T.notice
  self.look=.7*sin(u*2*pi)*(1-u*.3)
  return
 end
 if p<b.cap then
  -- PUFF: up it swells, red with anger; two stomps
  self.x,self.y,self.z=J[1],J[2],J[3]
  local u=(p-b.puff)/T.puff
  if once('puff')then
   self:play('puff',.85,1)
   -- (TEST242: no 'hit' clip here -- in the Stadium packs that slot is the
   -- default ATTACK, which tumbles Jigglypuff round to its back: it puffs
   -- up facing the camera, in its idle)
  end
  if p>=b.puff+.2 and once('angry')then self:cry(1.12)end
  self.red=smooth(u*2.5)
  self.anger=smooth((p-b.puff-.15)/.3)
  local back=EG()._backOut or smooth
  self.scale=1+.5*back(u*2.4)+.035*sin(p*9)
  for k,s in ipairs(STOMPS)do
   local v=(p-b.puff-s)/.16
   if v>=0 and v<1 then self.y=J[2]+1.4*sin(v*pi)end
   if v>=1 and once(STOMP_KEYS[k])then self:play('stomp',.5,.9);self:puffDust(J[1],J[2],J[3],t,2)end
  end
  if p>=b.grin then
   -- a sly grin: it settles a little smaller
   local g=(p-b.grin)/T.grin
   self.scale=1.5-.22*smooth(g)
  end
  return
 end
 self.red=max(0,.7-.7*smooth((p-b.cap)/1.2))
 self.anger=max(0,1-smooth((p-b.cap)/.6))
 if p<b.doodle then
  -- the CAP: off it pops (it is a marker)
  self.x,self.y,self.z=J[1],J[2],J[3]
  self.scale=1.28
  if once('cap')then
   self:play('pop',.8,1)
   local mx,my,mz=self:micPoint()
   local c=self.cap
   c.on=true;c.t0=t;c.x,c.y,c.z=mx,my+1.2,mz
   local a=(self.yaw or 0)+1.1
   c.vx,c.vz=sin(a)*9,cos(a)*9;c.vy=19
   c.gy=groundAt(self.map,mx,mz)
  end
  self.mic=0;self.marker=1
  local u=(p-b.cap)/T.cap
  self.y=J[2]+1.2*sin(clamp01(u*1.4)*pi)
  return
 end
 -- (back to its own size as it hops to the first face: it has work to do)
 self.mic=0;self.marker=1;self.scale=1+.28*(1-smooth((p-b.doodle)/T.hopIn))
 if p<b.stomp then
  -- THE DOODLES: hop in beside each face, scribble
  local i=floor((p-b.doodle)/T.beat)+1
  local tg=self.targets[i]
  if not tg then return end
  local q=(p-b.doodle)-(i-1)*T.beat
  self:doodleBeat(tg,q,t,i)
  return
 end
 -- the STOMP off: back the way it came, to the gate, in a huff
 self.scale=1.25;self.red=.55
 local q=p-b.stomp
 if once('huff')then
  self:cry(1.05)
  local hp={{self.x or J[1],self.y or J[2],self.z or J[3]}}
  local path=self.path
  for k=#path-1,1,-1 do hp[#hp+1]={path[k][1],path[k][2],path[k][3]}end
  self.huffPath=hp
 end
 local hp=self.huffPath
 local hopT=(T.stomp-.4)/max(1,#hp-1)
 local k=floor(q/hopT)
 if k>=#hp-1 then
  local e=hp[#hp]
  self.x,self.y,self.z=e[1],e[2],e[3]
  self.vanish=1
 else
  local v=(q-k*hopT)/hopT
  local a,bb=hp[k+1],hp[k+2]
  self.x,self.z=lerp(a[1],bb[1],v),lerp(a[3],bb[3],v)
  self.y=lerp(a[2],bb[2],v)+6*4*v*(1-v)
  self.wantYaw=atan2(bb[1]-a[1],bb[3]-a[3])
  self.hopKey=self.hopKey or-1
  if k~=self.hopKey then
   self.hopKey=k
   if k>0 then self:play('stomp',.42,.85+.05*k);self:puffDust(a[1],a[2],a[3],t,2)end
  end
  self.vanish=smooth((q-(T.stomp-.9))/.5)
 end
 if q>=T.stomp and self.state=='after'then self.state='final'end
end
-- where Jigglypuff stands to draw on a face: beside the head on the ground
-- (someone lying down), or floating beside the face (someone upright); on
-- the side with room (and away from the next sleeper)
local SIDES={1,-1}
-- a wall (a cell nobody walks on) at x,z? (no map, or it cannot say: no);
-- with `float`, the float's own body counts as one too
function End:wallAt(x,z,float)
 if float and self:inFloat(x,z,.5)then return true end
 local map=self.map
 if not(map and map.isWalkableCell)then return false end
 local okW,w=pcall(map.isWalkableCell,map,floor(x/16),floor(z/16))
 return okW and w==false
end
-- Jigglypuff's real size (world units, at scale 1): its fitted model's
-- extents (md.ey tall, md.ex x md.ez across), else its picture's card, else
-- the stand-in's. h: height, w: the wider of its two widths, r: half of it.
function End:jSize()
 local z=self.jsz
 if z then return z end
 local h,w=PE.JIGGLY.h,PE.JIGGLY.h
 local act=self.actor
 pcall(function()
  local md=act and act.md
  if md then
   h=tonumber(md.ey)or tonumber(md.top)or h
   w=max(tonumber(md.ex)or 0,tonumber(md.ez)or 0)
   if not(w>0)then w=tonumber(md.width)or h end
  elseif act and act.art then
   local k=PE.JIGGLY.h*1.2/21
   h=(tonumber(act.art.h)or 20)*k;w=(tonumber(act.art.w)or 20)*k
  end
 end)
 if not(h>.5 and h<80)then h=PE.JIGGLY.h end
 if not(w>.5 and w<80)then w=h end
 z={h=h,w=w,r=.5*w}
 if act then self.jsz=z end
 return z
end
function End:spotFor(tg)
 local c,n,u=tg.c,tg.n,tg.u
 local rx,rz=u[2]*n[3]-u[3]*n[2],u[1]*n[2]-u[2]*n[1]
 local rl=sqrt(rx*rx+rz*rz);if rl<1e-6 then rx,rz,rl=1,0,1 end
 rx,rz=rx/rl,rz/rl
 local lying=n[2]>.6
 -- (off to the side by the head's half-width, a gap and its own half-width)
 local js=self:jSize()
 local off=PE.CLOSE.headR*(tonumber(tg.unit)or 1)+PE.CLOSE.gap+js.r
 -- (the float is in the way of anyone but you riding it)
 local flt=not(self.ride and tg.sl.key=='player')
 tg.flt=flt
 local bestS,bx,by,bz,bside,badm=nil,nil,nil,nil,nil,PE.ADMIRE_BACK
 for _,side in ipairs(SIDES)do
  local sx,sy,sz
  if lying then
   sx,sz=c[1]+rx*side*off+u[1]*1.2,c[3]+rz*side*off+u[3]*1.2
   sy=groundAt(self.map,sx,sz)
  else
   sx,sz=c[1]+rx*side*off+n[1]*1.0,c[3]+rz*side*off+n[3]*1.0
   sy=c[2]-.35*js.h
  end
  local score=0
  for _,bk in ipairs(self.blockers or EMPTY)do
   local d
   if bk.ax then
    local ex,ez=bk.bx-bk.ax,bk.bz-bk.az
    local l2=ex*ex+ez*ez
    local w=l2>0 and max(0,min(1,((sx-bk.ax)*ex+(sz-bk.az)*ez)/l2))or 0
    d=sqrt((bk.ax+ex*w-sx)^2+(bk.az+ez*w-sz)^2)
   else d=sqrt((bk.x-sx)^2+(bk.z-sz)^2)end
   if d<4.5 then score=score-(4.5-d)end
  end
  if lying and self.map then
   local okW,w=pcall(self.map.isWalkableCell,self.map,floor(sx/16),floor(sz/16))
   if okW and w==false then score=score-10 end
  end
  if lying and self:inFloat(sx,sz,0)then score=score-10 end
  -- (TEST242: its whole body clear of walls, not only its middle -- and room
  -- to hop back and admire; else a shorter hop, or none)
  local ox,oz=rx*side,rz*side
  local rr=js.r*.85
  if not lying and self:wallAt(sx,sz,flt)then score=score-10 end
  for _,d in ipairs({{ox*rr,oz*rr},{u[1]*rr,u[3]*rr},{-u[1]*rr,-u[3]*rr}})do
   if self:wallAt(sx+d[1],sz+d[2],flt)then score=score-4 end
  end
  local adm=0
  for _,a in ipairs({PE.ADMIRE_BACK,PE.ADMIRE_BACK*.5})do
   if not self:wallAt(sx+ox*(a+rr),sz+oz*(a+rr),flt)and not self:wallAt(sx+ox*a,sz+oz*a,flt)then adm=a;break end
  end
  if adm<=0 then score=score-2 end
  if bestS==nil or score>bestS+1e-6 then bestS,bx,by,bz,bside,badm=score,sx,sy,sz,side,adm end
 end
 if self.ride and tg.sl.key=='player'then by=max(by,c[2]-.35*js.h)end
 local sp=tg.spot or{}
 -- (sp[5],sp[6]: outward, away from the face, level; sp[7]: how far it may
 -- hop back to admire)
 sp[1],sp[2],sp[3],sp[4],sp[5],sp[6],sp[7]=bx,by,bz,bside,rx*bside,rz*bside,badm
 tg.spot=sp
 tg.lying=lying
 return sp
end
-- one face: hop in beside it, then scribble the drawing on, stroke by
-- stroke, a squeak a stroke (its Zz stops while it draws)
function End:doodleBeat(tg,q,t,i)
 local T=PE.T
 local m=self:faceFrame(tg)
 if not m then
  self.marker=0
  -- Allow the first close-up to render during the hop-in. If this actor
  -- still cannot draw, remove its beat and move on; never scribble in air.
  if q>=T.hopIn then
   table.remove(self.targets,i)
   for k=i,#self.targets do self.targets[k].i=k end
   self.post=max(0,(self.post or 0)-q)
   self.pb=nil;self.shotKey=nil
  end
  return
 end
 local c=tg.c
 if not tg.spot then
  self:spotFor(tg)
  if self.eggs.zz then self.eggs.zz:remove(tg.sl.key,t)end
 end
 local sx,sy,sz=tg.spot[1],tg.spot[2],tg.spot[3]
 local hopIn=T.hopIn
 local CL=PE.CLOSE
 -- (three-quarter view: turned from the face part of the way to the lens)
 local yawFace=atan2(c[1]-sx,c[3]-sz)
 local yawDraw,yawAdmire=yawFace,yawFace
 local ce=tg.camEye or(self.P and self.P.cam and self.P.cam.eye)
 if ce then
  local d=(atan2(ce[1]-sx,ce[3]-sz)-yawFace+pi)%(2*pi)-pi
  yawDraw,yawAdmire=yawFace+d*CL.turn,yawFace+d*CL.admireTurn
 end
 if q<hopIn then
  local v=q/hopIn
  if not tg.from then
   tg.from=true
   -- in from outside the shot on its own side, away from the face: never
   -- between the face and the lens (the shots cut: no need to come from
   -- where it was)
   local ox,oz=tg.spot[5]or 0,tg.spot[6]or 0
   if self:wallAt(sx+ox*CL.hopFrom,sz+oz*CL.hopFrom,tg.flt)then
    -- (a wall that way: in from beyond the top of the head instead)
    local u=tg.u
    local hx,hz=u and u[1]or 0,u and u[3]or 0
    local hl=sqrt(hx*hx+hz*hz)
    if hl>1e-3 then ox,oz=hx/hl,hz/hl end
   end
   tg.fromX,tg.fromY,tg.fromZ=sx+ox*CL.hopFrom,sy,sz+oz*CL.hopFrom
   self:play('hop',.38,1.1)
  end
  self.x,self.z=lerp(tg.fromX,sx,v),lerp(tg.fromZ,sz,v)
  self.y=lerp(tg.fromY,sy,v)+CL.hopArc*4*v*(1-v)
  self.wantYaw=yawDraw
  return
 end
 self.wantYaw=yawDraw
 if tg.done then
  -- DONE: it hops back from the face to admire its work, the marker lifted
  -- -- the drawing clear to see until the cut
  local ax,az=sx-c[1],sz-c[3]
  local al=sqrt(ax*ax+az*az);if al<1e-6 then ax,az,al=1,0,1 end
  ax,az=ax/al,az/al
  local u=clamp01((q-tg.doneQ)/.22)
  local v=smooth(u)
  local back=tonumber(tg.spot[7])or PE.ADMIRE_BACK
  self.x,self.z=sx+ax*back*v,sz+az*back*v
  self.y=sy+2.2*sin(pi*u)
  self.pitch=-.10*v
  self.wantYaw=yawDraw+((yawAdmire-yawDraw+pi)%(2*pi)-pi)*v
  return
 end
 self.x,self.y,self.z=sx,sy,sz
 -- the scribble: a stroke at a time (the pen point is the marker's tip)
 local w=clamp01((q-hopIn)/T.scribble)
 local DD=self.DD
 local count,px,py,stroke=DD.progress(tg.run,w)
 tg.ranges[2]=count
 tg.drawn=count
 local pen=tg.pen or{0,0,0}
 pen[1],pen[2],pen[3]=facePoint(m,px,py,DD.wrapZ(px,py))
 tg.pen=pen
 local localPen=tg.penLocal or{};tg.penLocal=localPen
 localPen[1],localPen[2],localPen[3]=px,py,DD.wrapZ(px,py)
 if stroke~=tg.lastStroke then
  tg.lastStroke=stroke
  self:play(stroke%3==1 and'squeak1'or(stroke%3==2 and'squeak2'or'squeak3'),.55,.94+.14*hash(i,stroke))
 end
 self.pitch=.16+.06*sin(q*18)
 if not tg.lying then self.y=sy+.35*sin(q*7)end
 if w>=1 then
  tg.done=true;tg.doneQ=q
  -- (its Zz back once the camera has moved on)
  if self.eggs.zz then self.eggs.zz:add(tg.sl.key,t+max(0,T.beat-q)+.05,tg.sl.seed or i)end
 end
end
function End:micPoint()
 local s=self.scale or 1
 local js=self:jSize()
 local h=js.h*s
 local yw=(self.yaw or 0)+(self.look or 0)
 local fx,fz=sin(yw),cos(yw)
 local rx,rz=fz,-fx
 local f,sd=js.r*s,.31*js.h*s
 return(self.x or 0)+fx*f-rx*sd,(self.y or 0)+h*.46,(self.z or 0)+fz*f-rz*sd
end
-- a point by its head toward the camera, clear of its body (the anger mark):
-- up `up` and to the camera's right `side` (in heights), then out toward the eye
function End:headPoint(up,side,out)
 local s=self.scale or 1
 local h=self:jSize().h*s
 local cx,cy,cz=self.x or 0,(self.y or 0)+h*.5,self.z or 0
 local R=V.require('Voxel3D')
 local ex,ey,ez=0,0,1
 local e=R.eye
 if e then
  ex,ey,ez=e[1]-cx,e[2]-cy,e[3]-cz
  local l=sqrt(ex*ex+ey*ey+ez*ez);if l>1e-6 then ex,ey,ez=ex/l,ey/l,ez/l end
 end
 local sx,sz=-ez,ex
 local l=sqrt(sx*sx+sz*sz);if l>1e-6 then sx,sz=sx/l,sz/l end
 return cx+sx*side*h+ex*out*h,cy+up*h+ey*out*h,cz+sz*side*h+ez*out*h
end
function End:puffDust(x,y,z,t,n)
 for k=1,n do
  for _,d in ipairs(self.dust)do
   if not d.on then
    d.on=true;d.t0=t;d.x=x+(hash(k,t)-.5)*3;d.y=y+.4;d.z=z+(hash(t,k)-.5)*3;d.s=1.4+hash(k+2,t)
    break
   end
  end
 end
end
-- the notes it sings (more as the song swells)
function End:updateNotes(t)
 if self.state~='sing'then return end
 self.nextNote=self.nextNote or t
 if t<self.nextNote then return end
 local lvl=self.song.level and self.song:level()or .6
 self.nextNote=t+.30+.25*(1-lvl)
 for i,n in ipairs(self.notes)do
  if not n.on then
   local h=hash(i,t)
   n.on=true;n.t0=t
   n.x,n.y,n.z=self:micPoint()
   -- (to the camera's left or right, a little away from it)
   local cam=self.P and self.P.cam
   local rx,rz,bx,bz=1,0,0,-1
   if cam and cam.eye and cam.focus then
    local fx,fz=cam.focus[1]-cam.eye[1],cam.focus[3]-cam.eye[3]
    local l=sqrt(fx*fx+fz*fz);if l<1e-6 then l=1 end
    bx,bz=fx/l,fz/l;rx,rz=-bz,bx
   end
   local side=(i%2==0)and 1 or-1
   local k=.55+.45*h
   n.dx,n.dz=rx*side*k+bx*.35,rz*side*k+bz*.35
   n.icon=(h>.5)and'note2'or'note1'
   n.col=floor(hash(t,i)*4)%4+1
   return
  end
 end
end

------------------------------------------------------------------ the camera
-- Each beat a slow move (the parade's 'crane' shot, world points), from the
-- road's end E (where you stopped) or the perch J. Riding, Oak's lab stands
-- south of the float: the southern shots come from the south-WEST (over the
-- square before Red's house) or from high; walking, from the south.
PE.CAM={
 ride={
  arrive={from={eye={-56,18,66},focus={-8,8,-32}},to={eye={-52,19,62},focus={-2,13,26}},fov={46,40}},
  sing1={from={eye={-20,6.8,28},focus={0,3.5,0},J=true},to={eye={-16,5.8,22},focus={0,3.5,0},J=true},fov={36,32}},
  wide1={from={eye={-72,46,118},focus={2,8,33}},to={eye={-76,50,124},focus={2,8,33}},fov={50,50}},
  townW={from={eye={-68,24,104},focus={-96,6,44}},to={eye={-72,24,100},focus={-96,6,44}},fov={44,42}},
  townE={from={eye={132,24,64},focus={58,6,40}},to={eye={128,24,60},focus={58,6,40}},fov={44,42}},
  rival={from={eye={20,18,52},focus={50,12,32}},to={eye={22,17,48},focus={50,12,32}},fov={38,34}},
  family={from={eye={-50,30,68},focus={0,12,32}},to={eye={-46,32,64},focus={0,12,32}},fov={50,48}},
  partner={from={eye={18,24,32},focus={3,17,1}},to={eye={16,23,28},focus={3,17,1}},fov={38,34}},
  player={from={eye={-18,26,26},focus={-2,22,0}},to={eye={-16,25,22},focus={-2,22,0}},fov={36,32}},
  wide2={from={eye={-78,60,118},focus={0,8,28}},to={eye={-84,66,124},focus={0,8,28}},fov={50,52}},
  -- (TEST249: back on Jigglypuff, from a little wider -- the sleepers about
  -- it -- in to its happy face, as the song ends)
  sing2={from={eye={-27,10,38},focus={0,4,0},J=true},to={eye={-19,7,27},focus={0,3.8,0},J=true},fov={42,34}},
  notice={from={eye={-22,7.8,30},focus={0,4,0},J=true},to={eye={-18,6.8,24},focus={0,4,0},J=true},fov={38,34}},
  stomp={from={eye={-48,34,78},focus={-3,8,-12}},to={eye={-52,38,84},focus={-3,8,-12}},fov={50,50}},
  final={from={eye={-68,40,108},focus={0,10,28}},to={eye={-108,110,158},focus={0,14,18}},fov={50,56}},
  -- (TEST243: only if the wake's own shots cannot be fitted)
  wakeup={from={eye={-84,52,124},focus={0,40,-20}},to={eye={-88,56,130},focus={0,42,-20}},fov={54,56}},
  awake={from={eye={-44,16,62},focus={0,24,20}},to={eye={-40,16,58},focus={0,24,20}},fov={46,44}},
 },
 walk={
  arrive={from={eye={14,22,62},focus={14,10,-110}},to={eye={12,22,58},focus={-6,12,-50}},fov={46,42}},
  sing1={from={eye={-18,8,28},focus={0,3.5,0},J=true},to={eye={-14,7,22},focus={0,3.5,0},J=true},fov={36,32}},
  wide1={from={eye={44,50,70},focus={-6,8,-40}},to={eye={48,54,76},focus={-6,8,-40}},fov={50,50}},
  townW={from={eye={-24,24,8},focus={-60,6,-60}},to={eye={-28,24,4},focus={-60,6,-60}},fov={44,42}},
  townE={from={eye={14,24,-82},focus={72,6,-86}},to={eye={18,24,-86},focus={72,6,-86}},fov={42,40}},
  rival={from={eye={24,20,28},focus={48,13,2}},to={eye={26,19,24},focus={48,13,2}},fov={38,34}},
  family={from={eye={-8,30,62},focus={-8,10,-4}},to={eye={-6,32,68},focus={-8,10,-4}},fov={52,50}},
  partner={from={eye={30,18,30},focus={0,6,-14}},to={eye={26,17,26},focus={0,6,-14}},fov={38,34}},
  player={from={eye={10,24,36},focus={0,18,0}},to={eye={8,23,30},focus={0,18,0}},fov={36,32}},
  wide2={from={eye={14,64,80},focus={-6,8,-30}},to={eye={18,70,86},focus={-6,8,-30}},fov={50,52}},
  sing2={from={eye={-25,11,38},focus={0,4,0},J=true},to={eye={-17,8,27},focus={0,3.8,0},J=true},fov={42,34}},
  notice={from={eye={-20,9,30},focus={0,4,0},J=true},to={eye={-16,8,24},focus={0,4,0},J=true},fov={38,34}},
  stomp={from={eye={4,34,50},focus={4,8,-50}},to={eye={8,38,56},focus={4,8,-50}},fov={50,50}},
  final={from={eye={14,40,70},focus={-6,8,-50}},to={eye={34,110,130},focus={-6,8,-50}},fov={50,56}},
  wakeup={from={eye={14,52,96},focus={-6,40,-60}},to={eye={16,56,102},focus={-6,42,-60}},fov={54,56}},
  awake={from={eye={10,16,40},focus={20,24,-10}},to={eye={8,16,36},focus={20,24,-10}},fov={46,44}},
 },
}
-- the beats over the song: [long song: seconds], else fractions of it
PE.SONG_BEATS={
 {'sing1',0},{'wide1',7.0},{'townW',16.0},{'townE',23.7},{'rival',32.9},{'family',40.8},
 {'partner',49.9},{'player',53.6},{'pair',61.6},{'sing2',66.0},
}
-- TEST249: the song's last minute. `player` (your nods and your fall at
-- 59.6 s), then `pair`: you and your partner asleep side by side, fitted to
-- where the two of you really lie (PE.PAIR), and `sing2`: back on
-- Jigglypuff to the song's end, singing away to an audience fast asleep.
-- (TEST243's `wide2` over the sleeping town is no longer cut to in the
-- song; its preset stays for anything that asks for it.)
PE.PAIR={fov=42,pad=9,dMin=24,dMax=60,down=.50,push=1.10,turns={0,.3,-.3,.6,-.6,.9,-.9}}
-- TEST249: you and your partner asleep, fitted to where the two of you
-- really lie (your feet, the way you fell, your height; on the float, the
-- slide), seen from the side the player shot was on, looking down `down`
-- (tan), far enough back for both (`pad` round them, fov), the lens clear of
-- walls, the float and people (else turned a little, else nil)
function End:pairShot(dur)
 local CPm=CP()
 if not CPm then return nil end
 local Pp=PE.PAIR
 local pts={}
 for _,k in ipairs({'player','partner'})do
  local ok,x,y,z,yw,h=pcall(CPm.feetOf,k,self.game)
  if ok and tonumber(x)and tonumber(z)then
   local sl=k=='player'and self.player or self.partner
   local o=sl and sl.opts
   local dx,dz
   if k=='player'then dx,dz=(sl and sl.dx)or 0,(sl and sl.dz)or 0
   else dx,dz=-sin(tonumber(yw)or 0),-cos(tonumber(yw)or 0)end
   local H=k=='player'and((sl and sl.watch and sl.watch.height)or(sl and sl.H)or 20)or(tonumber(h)or 7)
   local reach=H*sin((sl and sl.A)or PE.FALL_A)*.5
   pts[#pts+1]={x+((o and o.x)or 0)+dx*reach,(tonumber(y)or 0)+((o and o.lift)or 0)+2.5,z+((o and o.z)or 0)+dz*reach,H}
  end
 end
 if #pts==0 then return nil end
 local cx,cy,cz=0,0,0
 for _,q in ipairs(pts)do cx,cy,cz=cx+q[1]/#pts,cy+q[2]/#pts,cz+q[3]/#pts end
 local spread=0
 for _,q in ipairs(pts)do spread=max(spread,sqrt((q[1]-cx)^2+(q[3]-cz)^2)+.35*q[4])end
 local mode=self.ride and'ride'or'walk'
 local pc=PE.CAM[mode].player
 local a=self:camEnd(pc.to,pc.to.J)
 local vx,vz=a.eye[1]-a.focus[1],a.eye[3]-a.focus[3]
 local vl=sqrt(vx*vx+vz*vz)
 if vl<1e-3 then vx,vz,vl=0,1,1 end
 vx,vz=vx/vl,vz/vl
 local tH=math.tan(math.rad(Pp.fov)*.5)
 local D=max(Pp.dMin,min(Pp.dMax,(spread+Pp.pad)/tH))
 for _,turn in ipairs(Pp.turns)do
  local c,s_=cos(turn),sin(turn)
  local dx,dz=vx*c+vz*s_,-vx*s_+vz*c
  local ex,ez=cx+dx*D,cz+dz*D
  if self:eyeClear(ex,ez)and self:rayClear(ex,ez,cx,cz,cy+D*Pp.down,cy)then
   local ey=cy+D*Pp.down
   local k=Pp.push
   self.pairPlan={cx=cx,cy=cy,cz=cz,D=D,turn=turn,spread=spread,n=#pts}
   return{kind='crane',dur=dur,from={eye={cx+dx*D*k,cy+D*Pp.down*k,cz+dz*D*k},focus={cx,cy,cz},fov=Pp.fov+4,world=true},
    to={eye={ex,ey,ez},focus={cx,cy,cz},fov=Pp.fov,world=true},name='encore pair',shake=.05}
  end
 end
 return nil
end
function End:camEnd(e,J)
 local O=J and self.perch or self.E
 -- (TEST242: the shots on Jigglypuff were set for one PE.JIGGLY.h tall:
 -- their offsets follow its real size -- the same shots at the usual fit)
 local k=1
 if J then local js=self:jSize();k=max(.7,min(1.6,max(js.h,.9*js.w)/PE.JIGGLY.h))end
 return{eye={O[1]+e.eye[1]*k,O[2]+e.eye[2]*k,O[3]+e.eye[3]*k},focus={O[1]+e.focus[1]*k,O[2]+e.focus[2]*k,O[3]+e.focus[3]*k},world=true}
end
function End:camShot(name,dur)
 local mode=self.ride and'ride'or'walk'
 local c=PE.CAM[mode][name]
 if not c then return nil end
 local a=self:camEnd(c.from,c.from.J)
 local b=self:camEnd(c.to,c.to.J)
 a.fov,b.fov=c.fov[1],c.fov[2]
 return{kind='crane',dur=max(.5,dur or 5),from=a,to=b,name='encore '..name,shake=.08}
end
-- a doodle's close-up: over the face from the feet's side (someone lying
-- down: the face upright in the picture), or from in front a little above
-- (someone upright). TEST242: FITTED to the head and to Jigglypuff at its
-- real size -- where it draws and where it hops back to admire -- both
-- inside the picture with a margin, the camera centred between them (the
-- face on one side, Jigglypuff beside it on the other, never in front of it)
-- and never closer than PE.CLOSE.near beyond Jigglypuff's body.
function End:faceShot(tg,dur)
 local m=self:faceFrame(tg,'aim')
 if not m then return nil end
 local c,n,u=tg.c,tg.n,tg.u
 local sp=tg.spot or self:spotFor(tg)
 local CL=PE.CLOSE
 local lying=n[2]>.6
 local js=self:jSize()
 local unit=tonumber(tg.unit)or 1
 local ox,oz=sp[5]or 0,sp[6]or 0
 -- what must be seen: the head (and its drawing), Jigglypuff drawing, and
 -- Jigglypuff admiring (hopped back, at the top of its little hop)
 local jr=.5*max(js.h,js.w)*1.08
 local S={{c[1],c[2],c[3],(CL.headR+.6)*unit},
  {sp[1],sp[2]+.5*js.h,sp[3],jr},
  {sp[1]+ox*(tonumber(sp[7])or PE.ADMIRE_BACK),sp[2]+.5*js.h+1.1,sp[3]+oz*(tonumber(sp[7])or PE.ADMIRE_BACK),jr}}
 -- the way to the eye (unit)
 local dx,dy,dz
 if lying then
  local e=math.rad(CL.lyingTilt)
  local ce,se=cos(e),sin(e)
  dx,dy,dz=n[1]*ce-u[1]*se,n[2]*ce-u[2]*se,n[3]*ce-u[3]*se
 else
  -- (along the way the face looks, level, and a little above it)
  local hx,hz=n[1],n[3]
  local hl=sqrt(hx*hx+hz*hz);if hl<1e-6 then hx,hz,hl=0,1,1 end
  hx,hz=hx/hl,hz/hl
  local e=math.rad(CL.uprightTilt)
  dx,dy,dz=hx*cos(e),sin(e),hz*cos(e)
 end
 local dl=sqrt(dx*dx+dy*dy+dz*dz);if dl<1e-6 then dx,dy,dz,dl=0,.6,.8,1 end
 dx,dy,dz=dx/dl,dy/dl,dz/dl
 -- the picture's axes (lookAt with world up): forward, right, up
 local fwx,fwy,fwz=-dx,-dy,-dz
 local rx,ry,rz=-fwz,0,fwx
 local rl=sqrt(rx*rx+rz*rz);if rl<1e-6 then rx,rz,rl=1,0,1 end
 rx,rz=rx/rl,rz/rl
 local ux,uy,uz=ry*fwz-rz*fwy,rz*fwx-rx*fwz,rx*fwy-ry*fwx
 local tV=math.tan(math.rad(CL.fovTo)*.5)*CL.fill
 local tH=tV*CL.aspect
 -- the middle of it all, on the picture (a first look from the head)
 local fx,fy,fz=c[1],c[2],c[3]
 local D=CL.dMin
 for pass=1,2 do
  local x0,x1,y0,y1=1e9,-1e9,1e9,-1e9
  for _,q in ipairs(S)do
   local px,py,pz=q[1]-fx,q[2]-fy,q[3]-fz
   local x=px*rx+py*ry+pz*rz
   local y=px*ux+py*uy+pz*uz
   local k=D/max(1,D+px*fwx+py*fwy+pz*fwz)   -- (nearer looks bigger)
   x0,x1=min(x0,(x-q[4])*k),max(x1,(x+q[4])*k)
   y0,y1=min(y0,(y-q[4])*k),max(y1,(y+q[4])*k)
  end
  local mx,my=(x0+x1)*.5,(y0+y1)*.5
  fx,fy,fz=fx+rx*mx+ux*my,fy+ry*mx+uy*my,fz+rz*mx+uz*my
  -- how far back so every one fits (and stays clear of the lens)
  D=CL.dMin
  for _,q in ipairs(S)do
   local px,py,pz=q[1]-fx,q[2]-fy,q[3]-fz
   local x=abs(px*rx+py*ry+pz*rz)
   local y=abs(px*ux+py*uy+pz*uz)
   local z=px*fwx+py*fwy+pz*fwz
   D=max(D,(x+q[4])/tH-z,(y+q[4])/tV-z,CL.near+q[4]-z)
  end
 end
 if tg.sl.key=='partner'then D=D+CL.partnerPad end
 D=min(CL.dMax,D)
 -- the crane ends at D (fovTo); it starts a little further back, wider
 local D0=D/CL.crane
 local f={fx,fy,fz}
 local ex,ey,ez=fx+dx*D0,fy+dy*D0,fz+dz*D0
 local e1={fx+dx*D,fy+dy*D,fz+dz*D}
 tg.camEye=e1
 tg.camD=D
 return{kind='crane',dur=dur,from={eye={ex,ey,ez},focus=f,fov=CL.fovFrom,world=true},
  to={eye=e1,focus=f,fov=CL.fovTo,world=true},name='encore doodle '..tg.i,shake=.04}
end
function End:shot(t)
 local st=self.state
 if st=='wait'or st=='off'or st=='done'then return nil end
 local key,dur
 if st=='arrive'then key,dur='arrive',PE.T.arrive
 elseif st=='sing'then
  local S=self.S or 0
  local L=self.L or PE.LONG.len
  local long=self.songKind=='long'
  local idx=1
  for i,b in ipairs(PE.SONG_BEATS)do
   local at=long and b[2]or b[2]/PE.LONG.len*L
   if S>=at then idx=i end
  end
  -- (a short song: fewer cuts -- a beat shorter than 2.5 s is skipped)
  local b=PE.SONG_BEATS[idx]
  local nxt=PE.SONG_BEATS[idx+1]
  local a0=long and b[2]or b[2]/PE.LONG.len*L
  local a1=nxt and(long and nxt[2]or nxt[2]/PE.LONG.len*L)or L
  if not long and a1-a0<2.5 and idx>1 then
   b=PE.SONG_BEATS[idx-1]
  end
  key,dur='song:'..b[1],a1-a0
  if self.shotKey~=key then
   self.shotKey=key
   local sh=nil
   if b[1]=='pair'then
    local okP,res=pcall(self.pairShot,self,dur+1)
    if okP then sh=res else log('the pair shot failed: %s',tostring(res))end
   end
   -- (no fit for the pair: the player's own shot goes on, a little longer)
   self.shotNow=sh or self:camShot(b[1]=='pair'and'player'or b[1],dur+1)
  end
  return self.shotNow
 else
  local bt=self:postBeats()
  local p=self.post or 0
  if p<bt.doodle then key,dur='notice',bt.doodle
  elseif p<bt.stomp then
   local i=floor((p-bt.doodle)/PE.T.beat)+1
   key='doodle'..i
   if self.shotKey~=key then
    local tg=self.targets[i]
    if tg and not tg.spot and self:faceFrame(tg,'aim')then self:spotFor(tg)end
    local sh=tg and self:faceShot(tg,PE.T.beat)
    if sh then self.shotKey=key;self.shotNow=sh end
   end
   return self.shotNow
  elseif p<bt.final then key,dur='stomp',PE.T.stomp
  elseif p<bt.wake then key,dur='final',PE.T.final   -- (TEST243: it ends where the wake's wide goes on)
  else
   -- TEST243: the bang (wide), then the awake town (close on two faces)
   key=p<bt.awake and'wakeup'or'awake'
   if self.shotKey~=key then
    local sh=nil
    local okS,res=pcall(self.wakeShot,self,key)
    if okS then sh=res else log('the wake\'s camera failed: %s',tostring(res))end
    self.shotKey=key
    self.shotNow=sh or self:camShot(key,key=='wakeup'and PE.T.wakeShot+.3 or PE.T.awake+1.6)
    -- (TEST257: the close-up's foreground cleared before its first frame)
    if key=='awake'then
     local okH,err=pcall(self.hideForeground,self,self.shotNow)
     if not okH then log('the close-up could not clear its foreground: %s',tostring(err));self:unhideForeground()end
    else self:unhideForeground()end
   end
   return self.shotNow
  end
 end
 if self.shotKey~=key then
  self.shotKey=key
  self.shotNow=self:camShot(key,dur)
  self:unhideForeground()   -- (TEST257: any other shot: everyone back)
 end
 return self.shotNow
end

------------------------------------------------------------------ drawing
local LIGHT={direction={-.30,.80,.52},ambient={.50,.47,.44},diffuse={.56,.51,.43}}
local TINT={1,.97,.92,1}
local TINTX={1,1,1,1}
local RED={1,.58,.56,1}
local FLASH_RED={1,.20,.14}
local OPTS={camera={},flipWinding=true,disableCulling=true,depthWrite=true}
local VIEW,MM,CARD=mat(),mat(),mat()
local viewKey=nil
local NOTE_COLS={{1,.55,.80},{.55,.78,1},{1,.88,.35},{.80,.65,1}}
local function drawModel(md,px,py,pz,yaw,pitch,roll,s,sy,oy,tint,flash,flashCol)
 local R=V.require('Voxel3D')
 if R.reflectionPlane or not(R.vp and R.eye and R.focus)then return true end
 local eg=EG()
 if viewKey~=R.vp then viewKey=R.vp;eg.lookAtInto(VIEW,R.eye,R.focus)end
 local k=tonumber(md.scale)or 1
 eg.fillTRS(MM,px,py,pz,yaw,pitch,roll,0,k*s,k*sy,k*s,md.cx or 0,oy,md.cz or 0)
 local g=love.graphics
 local okD,_,w=pcall(g.getDepthMode)
 OPTS.modelMatrix=MM
 OPTS.camera.view=VIEW;OPTS.camera.viewProjection=R.vp
 local hf=HF()
 OPTS.light=hf.LIGHT or LIGHT
 OPTS.tint=tint or hf.TINT or TINT
 OPTS.flashAmount=flash or 0
 OPTS.flashColor=flashCol or hf.FLASH
 OPTS.depthWrite=not okD or w==true
 g.push('all')
 local ok,drawn=pcall(md.inst.draw,md.inst,OPTS)
 g.pop()
 g.setColor(1,1,1,1)
 return ok and drawn~=false
end
function End:drawModel(eg,K,t)
 local st=self.state
 if st=='wait'or st=='off'then return end
 if not self.x or(self.vanish or 0)>=.99 then return end
 local act=self.actor
 if not act then return end
 local s=(self.scale or 1)*(1-(self.vanish or 0))
 local red=self.red or 0
 for i=1,4 do TINTX[i]=lerp(TINT[i],RED[i],red)end
 if act.md then
  local md=act.md
  local yaw=(self.yaw or 0)+(self.look or 0)
  local pivot=md.ground or 0
  if not drawModel(md,self.x,self.y,self.z,yaw,self.pitch or 0,self.roll or 0,s,s*(self.sq or 1),pivot,TINTX,.24*red,FLASH_RED)then
   pcall(EG()._releaseActor,act);self.actor=nil
   log('the encore: Jigglypuff would not draw -- it leaves')
  else eg.drawn=(eg.drawn or 0)+1 end
 elseif act.art then
  local R=V.require('Voxel3D')
  local BB=V.require('BattleBillboard')
  local art=act.art
  local img=art.frames[art.frame or 1]or art.frames[1]
  if img then
   local k=PE.JIGGLY.h*1.2*s/21
   local w,h=(art.w or 20)*k,(art.h or 20)*k
   R.lighting(false)
   if R.seams then R.seams(false)end
   love.graphics.setColor(TINTX[1],TINTX[2],TINTX[3],1)
   EG().fillCard(CARD,self.x,self.y+h*.5-(art.foot or 0)*k,self.z,w,h,BB.yawToward(self.x,self.z,R.eye),self.roll or 0)
   pcall(R.draw,BB.mesh(),img,CARD,BB.PULL)
   love.graphics.setColor(1,1,1,1)
   if R.seams then R.seams(true)end
   R.lighting(true)
  end
 end
end
-- an icon facing the camera squarely
function End:icon(eg,name,x,y,z,size,roll,r,g,b,a,pull)
 local tex=eg.tex and eg.tex[name]
 if not tex or a<=.01 then return end
 local R=V.require('Voxel3D')
 local BB=V.require('BattleBillboard')
 fillFacing(CARD,x,y,z,size,size,roll or 0)
 love.graphics.setColor(r,g,b,a)
 R.draw(BB.mesh(),tex,CARD,pull or 0)
 eg.drawn=(eg.drawn or 0)+1
end
function End:drawFx(eg,t)
 local st=self.state
 if st=='wait'or st=='off'then return end
 local R=V.require('Voxel3D')
 camBasis()
 -- the doodles (ink, on the faces: depth-tested, pulled a little toward us)
 local mesh=self.dmesh
 if mesh and(st=='after'or st=='final'or st=='done')then
  local K_=eg.K
  local tex=K_ and K_.white
  love.graphics.setColor(PE.INK[1],PE.INK[2],PE.INK[3],1)
  local CPh=CP()
  for _,tg in ipairs(self.targets)do
   if(tg.drawn or 0)>0 and not(CPh and CPh.isHidden and tg.sl and CPh.isHidden(tg.sl.npc))then
    local m=self:faceFrame(tg,'ink')
    -- Never draw the ink without the target body in this world pass.
    if m then
     -- (its design and how far it is drawn: a range set on the mesh itself
     -- round a plain draw -- another mod's Voxel3D.draw may hand on only
     -- its first five arguments; with none, it draws what the mesh is set to)
     local rg=tg.ranges
     if pcall(mesh.setDrawRange,mesh,rg[1],rg[2])then
      local okD,err=pcall(R.draw,mesh,tex,m,PE.PULL)
      pcall(mesh.setDrawRange,mesh)
      if not okD then error(err,0)end
      eg.drawn=(eg.drawn or 0)+1
     else pcall(mesh.setDrawRange,mesh)end
    end
   end
  end
 end
 if not self.x then return end
 local s=(self.scale or 1)*(1-(self.vanish or 0))
 -- its shadow, while it is in the air
 if st=='arrive'or(st=='after'and(self.vanish or 0)<1)then
  local gy=groundAt(self.map,self.x,self.z)
  local hgt=max(0,self.y-gy)
  if hgt>.5 then eg:blob(self.x,gy+.06,self.z,3.4*s/(1+hgt*.03),.30*(1-(self.vanish or 0))/(1+hgt*.04))end
 end
 -- the notes
 for _,n in ipairs(self.notes)do
  if n.on then
   local a_=t-n.t0
   if a_>1.8 then n.on=false
   else
    local u=a_/1.8
    local col=NOTE_COLS[n.col]or NOTE_COLS[1]
    local x=n.x+n.dx*u*10+sin(a_*5+n.t0)*.8
    local z=n.z+n.dz*u*10+cos(a_*4+n.t0)*.8
    self:icon(eg,n.icon,x,n.y+u*9,z,2.2+u*.9,.35*sin(a_*4+n.t0),col[1],col[2],col[3],smooth(a_/.15)*(1-smooth((u-.7)/.3)))
   end
  end
 end
 -- the microphone, then the marker (its tip on the pen point as it draws)
 if(self.mic or 0)>.02 and(self.vanish or 0)<.5 then
  local x,y,z=self:micPoint()
  self:icon(eg,'mic',x,y,z,2.6*s*(self.mic or 0),-.35+.12*sin(t*3),1,1,1,1,.8)
 end
 if(self.marker or 0)>.02 and(self.vanish or 0)<.5 then
  local x,y,z=self:micPoint()
  local pen=nil
  local markerVisible=true
  local b=self.pb
  local p=self.post or 0
  if b and p>=b.doodle and p<b.stomp then
   local i=floor((p-b.doodle)/PE.T.beat)+1
   local tg=self.targets[i]
   local m=tg and self:faceFrame(tg,'ink')
   markerVisible=m~=nil
   if m and tg.pen and(tg.drawn or 0)>0 and not tg.done then
    pen=tg.pen
    local lp=tg.penLocal
    if lp then pen[1],pen[2],pen[3]=facePoint(m,lp[1],lp[2],lp[3])end
   end
  end
  local roll=-.35
  if pen then
   -- from its hand to the pen point, on the screen
   local dx,dy,dz=pen[1]-x,pen[2]-y,pen[3]-z
   local sx=dx*CAMR[1]+dy*CAMR[2]+dz*CAMR[3]
   local sy=dx*CAMU[1]+dy*CAMU[2]+dz*CAMU[3]
   roll=atan2(-sx,-sy)
   -- the card's middle half its length back from the tip
   local L=2.9*s
   local l=sqrt(sx*sx+sy*sy);if l<1e-6 then l=1 end
   x,y,z=pen[1]-(CAMR[1]*sx+CAMU[1]*sy)/l*L*.5,pen[2]-(CAMR[2]*sx+CAMU[2]*sy)/l*L*.5,pen[3]-(CAMR[3]*sx+CAMU[3]*sy)/l*L*.5
  end
  if markerVisible then self:icon(eg,'marker',x,y,z,2.9*s,roll,1,1,1,1,1.2)end
 end
 -- the cap, flying off
 local c=self.cap
 if c.on then
  local a_=t-c.t0
  local y=c.y+c.vy*a_-34*a_*a_
  if y<(c.gy or 0)+.5 and a_>.3 then y=(c.gy or 0)+.5 end
  if a_>2.4 then c.on=false
  else self:icon(eg,'cap',c.x+c.vx*min(a_,.8),y,c.z+c.vz*min(a_,.8),1.6,a_*14,1,1,1,1-smooth((a_-1.8)/.6),.6)end
 end
 -- the anger mark at its brow
 if(self.anger or 0)>.02 and(self.vanish or 0)<.6 then
  local x,y,z=self:headPoint(.36,.30,.42)
  local p=1+.12*sin(t*11)
  self:icon(eg,'anger',x,y,z,2.9*(self.anger or 0)*p*(.6+.4*s),0,1,1,1,1,1.2)
 end
 -- the dust of its hops and stomps, and of a sleeper landing
 local K_=eg.K
 for _,d in ipairs(self.dust)do
  if d.on and K_ and K_.soft then
   local a_=t-d.t0
   local r=d.s*(1+a_*3)
   fillFacing(CARD,d.x,d.y+a_*2,d.z,r*2,r*2,0)
   love.graphics.setColor(1,.97,.92,.45*(1-a_/.45))
   R.draw(V.require('BattleBillboard').mesh(),K_.soft,CARD)
   eg.drawn=(eg.drawn or 0)+1
  end
 end
 love.graphics.setColor(1,1,1,1)
end

------------------------------------------------------------------ quiet, let go
-- skipped (or the parade aborted): the song stops at once, everyone upright.
-- (At its own end -- 'done' -- the town stays asleep and doodled under the
-- white: only the sounds stop; release() puts everyone back.)
function End:quietNow()
 if self.song then pcall(self.song.release,self.song)end
 self:silence()
 if self.state=='done'and not self.released then return end
 self:unhideForeground()
 local CPm=CP()
 if CPm then
  for _,p in ipairs(self.people or EMPTY)do pcall(CPm.pose,p.npc,nil)end
  pcall(CPm.pose,'player',nil);pcall(CPm.pose,'partner',nil)
 end
 for _,p in ipairs(self.people or EMPTY)do
  local sv=p.extraSaved
  if sv then
   p.npc.wanders,p.npc.steps,p.npc.pinnedFacing,p.npc.facing=sv.wanders,sv.steps,sv.pinnedFacing,sv.facing
   self.eggs:unhold(p.npc);p.extraSaved=nil
  end
 end
 self.pokemonSeen=nil
 watchRemove()
 -- (nothing more of it is drawn: Jigglypuff, the doodles, the notes)
 if self.state~='done'then self.state='off'end
end
function End:release()
 if self.released then return end
 self.released=true
 self:quietNow()
 if self.actor then pcall(EG()._releaseActor,self.actor);self.actor=nil end
 if self.dmesh then pcall(self.dmesh.release,self.dmesh);self.dmesh=nil end
 pcall(function()V.require('ParadeSleepEyes').clear()end)
 for k,s in pairs(self.snd)do if s then pcall(s.stop,s);pcall(s.release,s)end;self.snd[k]=nil end
 self.loadQ=nil
 if self.state~='done'then self.state='off'end
end

------------------------------------------------------------------ the icons it needs (added to the eggs' set)
-- the cap of the marker-microphone (its round head), the marker with its
-- black felt tip, and a little spark
function PE.installIcons(eg)
 local ICONS=eg and eg.ICONS
 if type(ICONS)~='table'or ICONS.marker then return end
 local function circD(px,py,cx,cy,r)return sqrt((px-cx)^2+(py-cy)^2)-r end
 local function segD(px,py,ax,ay,bx,by)
  local dx,dy=bx-ax,by-ay
  local l2=dx*dx+dy*dy
  local u=l2>0 and max(0,min(1,((px-ax)*dx+(py-ay)*dy)/l2))or 0
  local qx,qy=ax+dx*u-px,ay+dy*u-py
  return sqrt(qx*qx+qy*qy)
 end
 ICONS.cap={rim={.10,.10,.13},f=function(x,y)
  local h=circD(x,y,24,22,12)
  local hl=circD(x,y,20,18,3.6)
  local grid=((floor(x/3)+floor(y/3))%2==0)and .06 or 0
  return h,hl<0 and{1,1,1}or{.80-grid,.82-grid,.86-grid}
 end}
 -- (pointing down: the tip at the bottom of the picture)
 ICONS.marker={rim={.10,.10,.13},f=function(x,y)
  local body=segD(x,y,24,4,24,34)-3.4
  local tip=segD(x,y,24,34,24,43)-max(.6,2.4-(y-34)*.2)
  if tip<body then return tip,{.08,.07,.10}end
  local band=abs(y-12)<1.6
  return body,band and{.86,.20,.40}or{.18,.18,.22}
 end}
 ICONS.spark={tint=true,f=function(x,y)
  local d=1e9
  for k=0,3 do local a=k*pi/4;d=min(d,segD(x,y,24-cos(a)*14,24-sin(a)*14,24+cos(a)*14,24+sin(a)*14)-1.6)end
  return d
 end}
end

function PE.dispose()
 viewKey=nil
 watchRemove()
 -- (TEST257: nobody left out of the picture)
 pcall(function()local C=V.require('ParadeCast');if C.hideClear then C.hideClear()end end)
end
return PE
