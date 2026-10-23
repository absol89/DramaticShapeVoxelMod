-- TEST235: TWO EASTER EGGS IN THE CHAMPION'S PARADE (Celadon City).
--
--   * MAGIKARP. As the camera rides alongside you (the 'alongside' shot), a
--     fan across the street throws a Magikarp at you. Riding, it lands on
--     the float's dais with a wet slap, between you and your partner, and
--     flops about there (bouncing, flipping from side to side, a little
--     spray at every landing); walking, it lands on the street just ahead of
--     you and flops along ahead of you. Just before the next cut it flops
--     off, back across the street, into a fan's arms.
--   * JIGGLYPUFF'S FIRST TRY. As the float (or you) comes to the plaza (the
--     'crowd' shot), a fan on the north pavement tosses a Jigglypuff up onto
--     a brass post of the velvet rope. It takes out its microphone and SINGS
--     -- Joseph's own recording (assets/parade/jigglypuff_song.mp3, played
--     as it is). The march steps back; music notes float over the crowd; the
--     people round it doze off one after another, nearest first (the
--     cheering stops, heads droop, "Zz" float up), and the crowd's cheer and
--     the ticker tape die down. You and your partner sway and nod, but stay
--     awake. The camera takes its time: close on Jigglypuff, along the
--     dozing kerb, the float, and back on Jigglypuff near the end of the
--     song. TEST244: then, mid-song, the plaza's cannons and fireworks go off:
--     the BANG cuts the song short, everyone wakes with a start or a stretch,
--     the cheering and the march come back, and Jigglypuff -- startled, then
--     looking round at a crowd wide awake -- PUFFS UP red with anger and
--     stomps off along the rope, post to post. (E.INTERRUPT=nil: the old
--     order -- the song to its end, the stomp-off, then the cannons.)
--
-- Once each, in Celadon only. The song is timed by the song itself (its
-- Source's own clock, tell()), not by the game's clock, which can run slower
-- than the music on a slow phone; a game-time fallback (and a cap of its
-- length + 4 s of game time) keeps the parade from ever waiting on it. Its
-- length comes from the Source (or SONG_LEN): a longer song lays its camera
-- beats out longer, and one past 75 s fades out at 75 s. If the recording is
-- missing or will not decode, a short lullaby of our own (egg_lullaby.ogg,
-- original music) stands in, on the earlier timings.
--
-- The two Pokemon are the Stadium models the float and the Hall of Fame use
-- (HallOfFame3D's model path), loaded under Celadon's white card with the
-- song's Source, and let go when the parade leaves Celadon; without a model,
-- the battle picture stands in; with neither, that gag is skipped. Any
-- failure lets the eggs go and the parade runs on exactly as before
-- (ChampionParade calls everything here inside pcall).
--
-- MADE TO BE USED AGAIN (the game's ending, at Pallet, builds on this):
--   * Song: one song player -- load (stream, else static; through the mod,
--     else the path; else the stand-in), play at the music setting, the
--     march ducked, its own clock, the end, let go -- for any asset name and
--     fallback length;
--   * Sleep: anyone (ParadeCast keys: a person, 'player', 'partner') nods
--     off ('droop') or falls over ('fall', about 85 degrees, a bounce), in a
--     wave on any clock, and wakes with a start or a stretch;
--   * Zz: the one "Zz" over sleeping heads (ParadeCast.headOf);
--   * a stop's gags: E.STOP_GAGS[stop key] lists what to make there; each
--     gag may load under the card, hold the finale ('show' -> 'finale') or
--     the stop's end ('finale' -> 'outro'/'end'), take the camera, set the
--     crowd's cheer and the march, wake people as the finale starts, draw.
local V=...
local E={REVISION='parade-eggs-261'}
local floor,max,min,abs,sin,cos,sqrt,pi=math.floor,math.max,math.min,math.abs,math.sin,math.cos,math.sqrt,math.pi
local atan2=math.atan2 or math.atan

------------------------------------------------------------------ settings
E.ASSETS='assets/parade/'
E.STOP='celadon'          -- the stop both gags play in (its key)
-- JOSEPH'S SONG: his own recording, played as it is (never re-encoded,
-- trimmed or changed). SONG_LEN: its length, when the Source cannot say.
E.SONG_FILE='jigglypuff_song.mp3'
E.SONG_LEN=20.35
-- its loudness every 0.1 s (0..9), for the notes and the bob to follow
E.SONG_ENV='05777777774787666566656776767675467668878755676667766746877773556556553444425312145777768763688666556647678766257745887885666567776677677777766653444553655542567767665675597776665553566766657887538875776'
-- the song player's settings: file, len (its fallback length), env, the
-- stand-in (synth, synthLen), CAP (longer: faded out over CAP_FADE at CAP),
-- GRACE (game seconds past its length before it counts as over whatever its
-- Source says), the march while it sings (DUCK, reached in DUCK_IN; back in
-- DUCK_OUT)
E.SONG={file=E.SONG_FILE,len=E.SONG_LEN,env=E.SONG_ENV,synth='egg_lullaby.ogg',synthLen=4.45,
 cap=75,capFade=1.5,grace=4,duck=.18,duckIn=.6,duckOut=.45}
-- (TEST235 review) the most a frame adds to a song's game-time clock: the first
-- frame back from the background carries the whole time away, while the
-- song's own audio clock stood still
E.SONG_STEP=.1
E.SOUND_FILES={slap='egg_slap.ogg',flop='egg_flop.ogg',puff='egg_puff.ogg',boing='egg_boing.ogg',whoosh='egg_whoosh.ogg'}
-- MAGIKARP: in the 'alongside' shot, CUE cells after its cut; FLY seconds in
-- the air (walking: WALK_FLY); flops of HOP s in the air and REST s lying
-- there; it leaves -- from wherever it is -- EXIT_FLY (walking: WALK_EXIT_FLY)
-- + EXIT_SPARE seconds (at the float's or your pace) before the next cut, or
-- after MAX_FLOP s
E.KARP={species='MAGIKARP',dex=129,len=8.4,shot='alongside',cue=.10,
 fly=.78,walkFly=.55,arc=11,hop=.46,rest=.16,hopH=4.4,exitFly=.72,walkExitFly=.55,exitSpare=.15,exitArc=15,maxFlop=6.0,
 -- (riding) where it lies on the dais: float-local x (across), z (along), y (top)
 spots={{.7,3.6,11.9},{-.8,3.4,11.9},{1.9,3.3,11.9},{.3,6.8,11.3},{1.3,3.9,11.9},{-.4,3.7,11.9}},
 lead=13,side=6,      -- (walking) how far ahead of you, and toward the far pavement
 drops=5}             -- spray at a landing
-- JIGGLYPUFF: in the 'crowd' shot; on the north rope's POST-th post (the
-- fourth, x 285: the first the 'crowd' camera sees past the Department
-- Store's corner); the parade's people within SLEEP_R of it (SLEEP_MAX of
-- them) doze off
E.PUFF={species='JIGGLYPUFF',dex=39,h=7.4,maxW=8.2,shot='crowd',cue=.05,post=4,
 postTop=9.8,         -- (ParadeStreet: a rope post's cap is 9.8 high)
 sleepR=100,sleepMax=10,huffPosts=3}
E.SING_MOVE=47            -- SING: its Stadium animation, when the model has one
-- its beats (seconds): before the song (toss, land, mic) and after it
-- (notice: its eyes open, it looks round; puff; huff: off along the rope)
E.PT={toss=.8,land=.3,mic=.35,notice=.25,puff=1.0,huff=1.6}
E.PT_SYNTH={toss=.85,land=.45,mic=.45,notice=.9,puff=1.1,huff=1.6}   -- (the stand-in: the earlier timings)
-- the crowd dozes off in a wave, nearest first: onsets from DOZE0 to DOZE1
-- of the song, each nodding off over DOZE_IN of it (DOZE_MAX s at most): all
-- asleep by about three quarters of the way
E.DOZE0,E.DOZE1,E.DOZE_IN,E.DOZE_MAX=.06,.62,.08,1.4
-- TEST253: THEIR EYES. Joseph: the city's people kept their eyes wide open
-- through the song. The sleepers here never set an eye value (Pallet's did),
-- so ParadeSleepEyes (the Collection's authored half-shut and shut eye
-- tiles: under .20 open, under .65 half, else shut) was never asked. Now
-- each sleeper is drowsy first -- for `drowsy` s before they nod off, two
-- heavy blinks (half-shut, `blinks`: centre, peak, width in that stretch)
-- with a slight dip of the head (`dip` of their nod) -- then, as they nod
-- off, the eyes close with the head going down, SNAP OPEN at the catch and
-- close for good; shut while they sleep; open the moment they wake.
-- (E.EYES=false: as before.)
E.EYES={drowsy=3.2,minDrowsy=.8,blinks={{.30,.45,.22},{.74,.60,.26}},dip=.10}
E.TICKER_LOW=.25          -- the ticker tape with everyone asleep (the crowd's loop goes to 0)
E.WAKE_GAP=.06            -- one after another as they wake
E.HOLD_PAD=10             -- (safety) the finale waits no more than the song's cap and this
-- TEST244: THE FIREWORKS INTERRUPT THE SONG. The finale no longer waits for
-- the song to end and Jigglypuff to stomp off: once the plaza is asleep and
-- the song is `u` of the way through, the finale goes (its cannons and
-- rockets), the BANG wakes everyone, the song is cut off (a `fade` s tape
-- stop down to `pitchTo`), Jigglypuff jumps (`startle` s), looks round at the
-- crowd waking for the rest of `watch` s -- while the finale's own crane
-- shows the rockets -- then the camera comes back to it as it PUFFS UP and
-- stomps off along the rope. The camera's last beat on it before the bang
-- starts `backLead` s before it. The bang waits for the plaza to be at least
-- `minSleep` asleep, or `late` s past the mark at most. (E.INTERRUPT=nil: the
-- old order, the song to its end first.)
-- TEST245: NOT RUSHED. TEST244 had the bang at 80% of the song, which pulled
-- the close/kerb/float beats in by a fifth (the same camera moves in less
-- time), gave the plaza two seconds asleep, the last close-up 2.4 s, and the
-- angry shot the whole 'back' move in 3.2 s: Joseph: "Celadon looks sped
-- up". Now the bang is at `u`=88% (never later than `endGap` s before the
-- song's end), the beats keep nine-tenths of their TEST243 length, the
-- finale's crane holds `watch` s so the shells are seen bursting, and after
-- the bang Jigglypuff takes `puff` and `huff` s (TEST243: 1.0 and 1.6) under
-- a gentler, wider camera (`angry`: its two ends, from the foot of the post),
-- the stop's end waiting `hold` s after it has gone.
E.INTERRUPT={u=.88,endGap=1.5,backLead=2.8,startle=.6,watch=3.4,fade=.35,pitchTo=.55,minSleep=.85,late=1.2,
 puff=1.4,huff=2.4,hold=1.0,
 angry={{eye={36,19,40},focus={4,13.5,0},fov=40},{eye={42,20.5,44.5},focus={16,13,0},fov=45}}}
-- the camera's beats over the song (fractions of it): from BEAT_U0 (or 3 s
-- in, if sooner) close on Jigglypuff, along the dozing kerb, the float --
-- round those again for each BEAT_CYCLE s of song (a longer song has more
-- beats, not longer ones) -- and from BEAT_U1 (or the last BACK_S s, if
-- later) back on Jigglypuff to the end. A beat shorter than BEAT_MIN s is
-- left out (its time goes to the next).
E.BEAT_U0,E.BEAT_U1,E.BEAT_MIN,E.BEAT_CYCLE,E.BACK_S=.15,.82,1.5,18,5.5
E.BEAT_W={.23,.24,.20}
-- each beat: a slow move from [1] to [2]: eye and focus from the foot of
-- Jigglypuff's post (x, ground, z), or (road) from the end of your road
E.CAM={
 close={{eye={16,15.8,26},focus={0,14.3,0},fov=38},{eye={11,14.8,19},focus={0,14.3,0},fov=32},shake=.06},
 close2={{eye={-15,15.5,25},focus={0,14.3,0},fov=38},{eye={-10,14.6,19},focus={0,14.3,0},fov=32},shake=.06},
 kerb={{eye={86,22,33},focus={64,13,-11},fov=40},{eye={-4,22,33},focus={-26,13,-11},fov=40},shake=.08},
 kerb2={{eye={-4,22,33},focus={-26,13,-11},fov=40},{eye={86,22,33},focus={64,13,-11},fov=40},shake=.08},
 float={{eye={32,30,44},focus={1,20,1},fov=40},{eye={24,27,34},focus={1,20,1},fov=36},road=true,shake=.08,
  walk={{eye={-16,20,42},focus={0,10,-6},fov=40},{eye={-12,18,34},focus={0,10,-6},fov=36}}},
 float2={{eye={-30,29,42},focus={-1,20,1},fov=40},{eye={-22,26,33},focus={-1,20,1},fov=36},road=true,shake=.08,
  walk={{eye={-32,28,34},focus={0,9,-6},fov=40},{eye={-25,25,28},focus={0,9,-6},fov=36}}},
 back={{eye={30,17,33},focus={0,13.5,0},fov=36},{eye={40,19,39},focus={22,13,0},fov=46},shake=.08},
}

------------------------------------------------------------------ helpers
local function now()local ok,t=pcall(love.timer.getTime);return ok and t or 0 end
local function clamp01(u)return max(0,min(1,u))end
local function smooth(u)u=clamp01(u);return u*u*(3-2*u)end
local function backOut(u)u=clamp01(u);local s=1.7;u=u-1;return u*u*((s+1)*u+s)+1 end
local function lerp(a,b,u)return a+(b-a)*u end
local function hash(a,b)local x=sin(a*127.1+b*311.7)*43758.5453;return x-floor(x)end
local function log(fmt,...)
 local args={...}
 pcall(function()require('src.core.Logger').warn('[ParadeEggs] '..fmt,unpack(args))end)
end
E._log=log
local function cast()
 local ok,CP=pcall(V.require,'ParadeCast')
 return ok and type(CP)=='table'and CP or nil
end
-- the ground at a world point (as ChampionParade's groundXZ; no closures)
local function groundAt(map,x,z)
 if not map then return 0 end
 local okS,VS=pcall(V.require,'VoxelScene')
 if not(okS and type(VS)=='table'and VS.groundAt)then return 0 end
 local ok,h=pcall(VS.groundAt,map,floor(x/16),floor(z/16),x-8,z-8)
 return ok and tonumber(h)or 0
end
local EMPTY={}
-- (TEST253) the eyes over a nod-off (u: 0..1 through it) and over the
-- drowsy stretch before it (v: 0..1): see E.EYES
function E.dozeEyes(u)
 if u<=0 then return 0 end
 if u>=1 then return 1 end
 if u<.38 then return .95*smooth(u/.30)end
 if u<.55 then return .95*(1-smooth((u-.38)/.08))end
 return smooth((u-.60)/.35)
end
function E.drowsyEyes(v)
 local e=0
 for _,b in ipairs(E.EYES and E.EYES.blinks or EMPTY)do
  local d=abs(v-b[1])/b[3]
  if d<1 then e=max(e,b[2]*(1-d*d)*(1-d*d))end
 end
 return e
end
local function sfxGain(game)
 local o=game and game.save and game.save.options
 return max(0,min(7,tonumber(o and o.sfxVol)or 7))/7
end
-- the music setting (0..1): the song plays at 1.0 x it (the engine's own
-- songs play at 0.7 x it); nothing when the game's audio is set to others' only
local MusicMod=nil
local function musicGain(game)
 local o=game and game.save and game.save.options
 local v=max(0,min(7,tonumber(o and o.musicVol)or 7))/7
 if MusicMod==nil then local ok,m=pcall(require,'src.core.Music');MusicMod=ok and type(m)=='table'and m or false end
 if MusicMod and MusicMod.audioMode then
  local ok,mode=pcall(MusicMod.audioMode)
  if ok and mode=='external_only'then v=0 end
 end
 return v
end
E._musicGain=musicGain
E._smooth,E._backOut=smooth,backOut

------------------------------------------------------------------ matrices (filled in place)
local function mat()return{1,0,0,0, 0,1,0,0, 0,0,1,0, 0,0,0,1}end
E.mat=mat
-- m = T(px,py,pz) * Ry(yaw) * Rx(pitch) * Rz(roll) * Ry(pre) * S(sx,sy,sz) * T(-ox,-oy,-oz)
local function fillTRS(m,px,py,pz,yaw,pitch,roll,pre,sx,sy,sz,ox,oy,oz)
 local cy,sy_=cos(yaw),sin(yaw)
 local cx,sx_=cos(pitch),sin(pitch)
 local cz,sz_=cos(roll),sin(roll)
 -- B = Ry*Rx*Rz
 local b00,b01,b02=cy*cz+sy_*sx_*sz_,-cy*sz_+sy_*sx_*cz,sy_*cx
 local b10,b11,b12=cx*sz_,cx*cz,-sx_
 local b20,b21,b22=-sy_*cz+cy*sx_*sz_,sy_*sz_+cy*sx_*cz,cy*cx
 if pre and pre~=0 then
  local cp,sp=cos(pre),sin(pre)
  b00,b02=b00*cp-b02*sp,b00*sp+b02*cp
  b10,b12=b10*cp-b12*sp,b10*sp+b12*cp
  b20,b22=b20*cp-b22*sp,b20*sp+b22*cp
 end
 b00,b10,b20=b00*sx,b10*sx,b20*sx
 b01,b11,b21=b01*sy,b11*sy,b21*sy
 b02,b12,b22=b02*sz,b12*sz,b22*sz
 m[1],m[2],m[3],m[4]=b00,b01,b02,px-(b00*ox+b01*oy+b02*oz)
 m[5],m[6],m[7],m[8]=b10,b11,b12,py-(b10*ox+b11*oy+b12*oz)
 m[9],m[10],m[11],m[12]=b20,b21,b22,pz-(b20*ox+b21*oy+b22*oz)
 m[13],m[14],m[15],m[16]=0,0,0,1
 return m
end
E.fillTRS=fillTRS
-- a card (BattleBillboard's unit quad: x -.5..5, y 0..1, facing +z) w x h,
-- centred on (x,y,z), turned to yaw, rolled in its own plane
local function fillCard(m,x,y,z,w,h,yaw,roll)
 local c,s=cos(yaw),sin(yaw)
 local cr,sr=cos(roll or 0),sin(roll or 0)
 local a00,a01,a02=c*cr*w,-c*sr*h,s
 local a10,a11,a12=sr*w,cr*h,0
 local a20,a21,a22=-s*cr*w,s*sr*h,c
 m[1],m[2],m[3],m[4]=a00,a01,a02,x-a01*.5
 m[5],m[6],m[7],m[8]=a10,a11,a12,y-a11*.5
 m[9],m[10],m[11],m[12]=a20,a21,a22,z-a21*.5
 m[13],m[14],m[15],m[16]=0,0,0,1
 return m
end
E.fillCard=fillCard
-- a card lying on someone's face (for the game's ending: Jigglypuff's
-- doodles): from ParadeCast.headOf's head middle c, the way the face looks
-- n and the way the head is up u; w x h, `out` along n from the middle
-- (about the head's half depth, 1.7 for a grown-up). BattleBillboard's unit
-- quad, its +z along n; draw it with culling off (seen from the front only
-- as it should be).
function E.fillFaceCard(m,cx,cy,cz,nx,ny,nz,ux,uy,uz,w,h,out)
 local rx,ry,rz=uy*nz-uz*ny,uz*nx-ux*nz,ux*ny-uy*nx
 local l=sqrt(rx*rx+ry*ry+rz*rz)
 if l<1e-6 then rx,ry,rz=1,0,0 else rx,ry,rz=rx/l,ry/l,rz/l end
 out=out or 0
 local ox,oy,oz=cx+nx*out-ux*h*.5,cy+ny*out-uy*h*.5,cz+nz*out-uz*h*.5
 m[1],m[2],m[3],m[4]=rx*w,ux*h,nx,ox
 m[5],m[6],m[7],m[8]=ry*w,uy*h,ny,oy
 m[9],m[10],m[11],m[12]=rz*w,uz*h,nz,oz
 m[13],m[14],m[15],m[16]=0,0,0,1
 return m
end
-- a flat card on the ground (LeagueRoad's unit quad: -1..1 in x and z)
local function fillFlat(m,x,y,z,rx,rz)
 m[1],m[2],m[3],m[4]=rx,0,0,x
 m[5],m[6],m[7],m[8]=0,1,0,y
 m[9],m[10],m[11],m[12]=0,0,rz,z
 m[13],m[14],m[15],m[16]=0,0,0,1
 return m
end
-- Mat4.lookAt, in place
local function lookAtInto(m,eye,tg)
 local fx,fy,fz=tg[1]-eye[1],tg[2]-eye[2],tg[3]-eye[3]
 local l=sqrt(fx*fx+fy*fy+fz*fz);if l==0 then l=1 end
 fx,fy,fz=fx/l,fy/l,fz/l
 local sx,sy,sz=-fz,0,fx                -- f x (0,1,0)
 l=sqrt(sx*sx+sz*sz);if l==0 then l=1 end
 sx,sz=sx/l,sz/l
 local ux,uy,uz=sy*fz-sz*fy,sz*fx-sx*fz,sx*fy-sy*fx
 m[1],m[2],m[3],m[4]=sx,sy,sz,-(sx*eye[1]+sy*eye[2]+sz*eye[3])
 m[5],m[6],m[7],m[8]=ux,uy,uz,-(ux*eye[1]+uy*eye[2]+uz*eye[3])
 m[9],m[10],m[11],m[12]=-fx,-fy,-fz,fx*eye[1]+fy*eye[2]+fz*eye[3]
 m[13],m[14],m[15],m[16]=0,0,0,1
 return m
end
E.lookAtInto=lookAtInto

------------------------------------------------------------------ the little pictures
-- Drawn once, as signed distances (pure, so they can be checked and
-- previewed headless): music notes, a "Z", the microphone, the anger mark, a
-- drop of water. Tinted ones are white with a darker rim (the colour comes
-- from setColor); the others carry their own colours.
E.ICON_N=48
local function segD(px,py,ax,ay,bx,by)
 local dx,dy=bx-ax,by-ay
 local l2=dx*dx+dy*dy
 local u=l2>0 and max(0,min(1,((px-ax)*dx+(py-ay)*dy)/l2))or 0
 local qx,qy=ax+dx*u-px,ay+dy*u-py
 return sqrt(qx*qx+qy*qy)
end
local function lineD(px,py,P)
 local d=1e9
 for i=1,#P-3,2 do d=min(d,segD(px,py,P[i],P[i+1],P[i+2],P[i+3]))end
 return d
end
local function ellD(px,py,cx,cy,rx,ry,rot)
 local c,s=cos(rot or 0),sin(rot or 0)
 local dx,dy=px-cx,py-cy
 local qx,qy=(dx*c+dy*s)/rx,(-dx*s+dy*c)/ry
 return(sqrt(qx*qx+qy*qy)-1)*min(rx,ry)
end
local function circD(px,py,cx,cy,r)return sqrt((px-cx)^2+(py-cy)^2)-r end
local ZPATH={11,11,37,11,11,37,37,37}
local FLAG={23.5,8,31,13,35,20,32,28}
local ANGER={}
do -- four quarter circles, their bulges toward the middle
 for q=0,3 do
  local sx,sy=(q%2==0)and-1 or 1,(q<2)and-1 or 1
  local cx,cy=24+sx*10,24+sy*10
  local P={}
  for k=0,6 do
   local a=k/6*pi/2
   P[#P+1]=cx-sx*8*cos(a);P[#P+1]=cy-sy*8*sin(a)
  end
  ANGER[q+1]=P
 end
end
local WHITE,RIM={1,1,1},{.32,.30,.38}
local ICONS={
 note1={tint=true,f=function(x,y)
  return min(ellD(x,y,16,36,8.5,6.2,-.35),segD(x,y,23.5,34,23.5,8)-2,lineD(x,y,FLAG)-2)end},
 note2={tint=true,f=function(x,y)
  return min(ellD(x,y,12,38,7.5,5.5,-.35),ellD(x,y,34,34,7.5,5.5,-.35),segD(x,y,18.5,36,18.5,11)-1.9,
   segD(x,y,40.5,32,40.5,7)-1.9,segD(x,y,18.5,11,40.5,7)-3)end},
 z={tint=true,f=function(x,y)return lineD(x,y,ZPATH)-3.6 end},
 mic={rim={.10,.10,.13},f=function(x,y)
  local h=circD(x,y,24,15,10)
  local s=segD(x,y,24,25,24,44)-3.2
  if h<s then
   local hl=circD(x,y,20.5,11.5,3.2)
   local grid=((floor(x/3)+floor(y/3))%2==0)and .06 or 0
   return h,hl<0 and{1,1,1}or{.80-grid,.82-grid,.86-grid}
  end
  local band=abs(y-27)<1.6
  return s,band and{.86,.20,.40}or{.18,.18,.22}
 end},
 anger={rim={.42,.02,.05},f=function(x,y)
  local d=1e9
  for q=1,4 do d=min(d,lineD(x,y,ANGER[q])-2.4)end
  return d,{.95,.14,.16}
 end},
 drop={rim={.18,.40,.74},f=function(x,y)
  local d=1e9
  for k=0,8 do local u=k/8;d=min(d,circD(x,y,24,8+23*u,1.6+9.4*u^1.15))end
  local hl=circD(x,y,19.5,29,3.4)
  return d,hl<0 and{1,1,1}or{.66,.86,1}
 end},
}
E.ICONS=ICONS
-- the colour and alpha of one pixel (x,y in 0..N-1, y down)
function E.iconPixel(name,x,y)
 local ic=ICONS[name]
 local d,col=ic.f(x+.5,y+.5)
 col=col or WHITE
 local rim=ic.rim or RIM
 local R=2.0
 local a=clamp01(R+.6-d)
 if a<=0 then return 0,0,0,0 end
 local k=clamp01(.5-d)           -- core (1) to rim (0)
 return lerp(rim[1],col[1],k),lerp(rim[2],col[2],k),lerp(rim[3],col[3],k),a
end
local function makeIcon(name)
 local N=E.ICON_N
 local d=love.image.newImageData(N,N)
 for y=0,N-1 do for x=0,N-1 do
  local r,g,b,a=E.iconPixel(name,x,y)
  d:setPixel(x,y,r,g,b,a)
 end end
 local img=love.graphics.newImage(d)
 pcall(img.setFilter,img,'linear','linear')
 pcall(d.release,d)
 return img
end
E.makeIcon=makeIcon

------------------------------------------------------------------ the Pokemon
local function HF()return V.require('HallOfFame3D')end
local function monFor(game,species,dex)
 local defs=game and game.data and game.data.pokemon
 if type(defs)=='table'and defs[species]then return{species=species}end
 return{species=dex}
end
-- its model (HallOfFame3D: the Collection's Stadium model, fitted), else its
-- picture, else nothing. A model's own extents are kept (the fish's length,
-- height and thickness, for its flops)
local function loadActor(game,a)
 local hf=HF()
 local mon=monFor(game,a.species,a.dex)
 local okM,md=pcall(hf.newTeamModel,game,mon,a.want,a.maxW)
 if okM and type(md)=='table'and md.inst then
  local s=tonumber(md.scale)or 1
  local okB,b=pcall(md.inst.bounds,md.inst)
  local ex,ey,ez=nil,nil,nil
  if okB and type(b)=='table'and tonumber(b.minX)and tonumber(b.maxX)and tonumber(b.minY)and tonumber(b.maxY)and tonumber(b.minZ)and tonumber(b.maxZ)then
   ex,ey,ez=(b.maxX-b.minX)*s,(b.maxY-b.minY)*s,(b.maxZ-b.minZ)*s
   md.midY=(b.minY+b.maxY)/2
  end
  md.ex,md.ey,md.ez=ex or md.width or a.want,ey or md.top or a.want,ez or md.width or a.want
  md.midY=md.midY or((md.ground or 0)+(tonumber(md.mid)or 0)/s)
  return{md=md,kind='model'}
 end
 local okA,art=pcall(hf.newTeamArt,game,{species=a.species})
 if okA and type(art)=='table'and art.frames and art.frames[1]then return{art=art,kind='art'}end
 return nil
end
local function releaseActor(act)
 if act and act.md then pcall(HF().releaseTeamModel,act.md);act.md=nil end
 if act then act.art=nil end
end
-- its animation on (MODEL_HZ frames a second, as HallOfFame3D steps them;
-- a once-only one goes back to the idle); a model that fails to step is let
-- go and its picture (if any) stands in
E.MODEL_HZ=20
local function stepActor(act,t,game)
 local md=act and act.md
 if not md then return end
 local ok,good=pcall(HF().stepTeamModel,md,t,E.MODEL_HZ)
 if not(ok and good)then
  pcall(HF().releaseTeamModel,md);act.md=nil
  local okA,art=pcall(HF().newTeamArt,game,{species=md.species})
  if okA and type(art)=='table'and art.frames then act.art=art end
 end
end
E._loadActor,E._releaseActor=loadActor,releaseActor

------------------------------------------------------------------ sound
local STREAM_FIRST,STATIC_FIRST={'stream','static'},{'static','stream'}
-- a Source for one of the parade's files: its bytes through the mod (a
-- packaged install has no folder to read), then its path; `kinds` in turn
function E.loadSource(name,kinds)
 kinds=kinds or STATIC_FIRST
 local ok,bytes=pcall(function()return V.mod:read(E.ASSETS..name)end)
 if ok and type(bytes)=='string'and #bytes>0 then
  for _,k in ipairs(kinds)do
   local ok2,src=pcall(function()return love.audio.newSource(love.filesystem.newFileData(bytes,name),k)end)
   if ok2 and src then return src,k end
  end
 end
 for _,k in ipairs(kinds)do
  local ok3,src=pcall(love.audio.newSource,(V.path or'mods/BATTLE_ART_VOXEL_FORK')..'/'..E.ASSETS..name,k)
  if ok3 and src then return src,k end
 end
 return nil
end

------------------------------------------------------------------ the song player
-- One song, start to end, on its own clock. Song.new(opts) with opts as
-- E.SONG (file, len, env, synth, synthLen, cap, capFade, grace, duck,
-- duckIn, duckOut); load() under the card (false: neither the file nor the
-- stand-in would load); play(game,t); update(dt,t,game) every frame; then
-- pos/len/u (phase()), level() (its loudness now), ended(), duckLevel(t)
-- (the march's multiplier: down as it starts, up again after unduck(t)),
-- release() (stopped and let go; safe to call again).
local Song={};Song.__index=Song
E.Song=Song
function Song.new(opts)
 return setmetatable({o=opts or E.SONG,state='idle',pos=0,gameT=0,started=false,vol=-1},Song)
end
function Song:load()
 if self.src then return true end
 if self.state~='idle'then return false end
 local o=self.o
 local src,how=E.loadSource(o.file,STREAM_FIRST)
 local kind='song'
 if not src and o.synth then
  log('%s would not load: the stand-in lullaby plays instead',tostring(o.file))
  src,how=E.loadSource(o.synth,STATIC_FIRST);kind='synth'
 end
 if not src then self.state='none';return false end
 self.src,self.kind,self.how=src,kind,how
 pcall(src.setLooping,src,false)
 local okD,d=pcall(src.getDuration,src,'seconds')
 d=okD and tonumber(d)or nil
 if not(d and d>0 and d<1e5)then d=kind=='song'and o.len or o.synthLen end
 self.rawLen=d
 self.capped=d>o.cap
 self.len=self.capped and(o.cap+o.capFade)or d
 self.env=kind=='song'and o.env or nil
 self.state='ready'
 return true
end
function Song:play(game,t)
 if self.state~='ready'then return false end
 local src=self.src
 self.game=game
 self.base=musicGain(game)
 self.vol=self.base
 pcall(src.setVolume,src,self.base)
 local ok=pcall(src.play,src)
 self.state='playing';self.t0=t;self.gameT=0;self.pos=0;self.started=false
 self.unduckT=nil;self.checkT=t
 self.plays=(self.plays or 0)+1
 return ok
end
function Song:update(dt,t,game)
 if self.state=='ending'then return self:drain(t)end
 if self.state~='playing'then return end
 local o=self.o
 self.gameT=self.gameT+min(E.SONG_STEP,max(0,tonumber(dt)or 0))
 local src=self.src
 local on,tell=false,nil
 if src then
  local okP,p=pcall(src.isPlaying,src);on=okP and p==true
  local okT,v=pcall(src.tell,src,'seconds');tell=okT and tonumber(v)or nil
 end
 if on then
  self.started=true;self.paused=false
  if tell then self.pos=tell;self.clock='audio'else self.pos=self.gameT;self.clock='game'end
 elseif not self.started then
  -- (it never sounded -- no device, no free voice: the gag runs on game time)
  self.pos=self.gameT;self.clock='game'
 elseif tell and tell>.05 and tell<(self.rawLen or self.len)-.3 then
  -- stopped part way, where it stands (the app in the background, its
  -- audio paused): the gag waits with it
  self.paused=true;self.pos=tell
 else
  return self:finish('end',t)
 end
 -- (over for the gag at its length less a tenth; the last of it plays out)
 if self.pos>=self.len-.1 then return self:finish('end',t,true)end
 if self.gameT>=self.len+o.grace then return self:finish('cap',t)end
 -- the music setting (looked at twice a second), and a long one's fade
 if t-(self.checkT or t)>=.5 then self.checkT=t;self.base=musicGain(game or self.game)end
 local v=self.base or 1
 if self.capped and self.pos>o.cap then v=v*max(0,1-(self.pos-o.cap)/o.capFade)end
 if abs(v-self.vol)>1e-3 and src then self.vol=v;pcall(src.setVolume,src,v)end
end
-- over (for the gag): `drain` lets the last of it play out, then it is let
-- go (drain()); else it is stopped and let go now
function Song:finish(why,t,drain)
 if self.state~='playing'then return end
 self.why=why
 self.pos=self.len
 self.endT=t
 if drain and self.src then self.state='ending'return end
 self.state='ended'
 self:drop()
end
-- (TEST244) cut off part way: a quick tape stop (`fade` s, the pitch down
-- to `pitchTo`), then let go
function Song:cut(t,fade,pitchTo)
 if self.state~='playing'then return end
 self.cutFade=max(.01,fade or .2);self.cutPitch=pitchTo or 1
 self:finish('interrupted',t,true)
end
function Song:drop()
 local s=self.src
 if s then pcall(s.stop,s);pcall(s.release,s)end
 self.src=nil
 if self.state=='ending'then self.state='ended'end
end
-- the last tenth of a second playing out (a long one's fade going on to its
-- end); let go once it stops, or 0.6 s on at most
function Song:drain(t)
 local src=self.src
 if not src then self.state='ended';return end
 if self.cutFade then
  local u=clamp01((t-(self.endT or t))/self.cutFade)
  pcall(src.setVolume,src,(self.base or 1)*(1-u)*(1-u))
  pcall(src.setPitch,src,1-(1-(self.cutPitch or 1))*u)
  if u>=1 then self:drop()end
  return
 end
 local okP,p=pcall(src.isPlaying,src)
 local on=okP and p==true
 if on and self.capped then
  local okT,v=pcall(src.tell,src,'seconds')
  local pos=okT and tonumber(v)
  if pos then
   local o=self.o
   local vol=(self.base or 1)*max(0,1-(pos-o.cap)/o.capFade)
   if abs(vol-self.vol)>1e-3 then self.vol=vol;pcall(src.setVolume,src,vol)end
   if pos>=o.cap+o.capFade then on=false end
  end
 end
 if not on or t-(self.endT or t)>.6 then self:drop()end
end
function Song:ended()return self.state=='ended'or self.state=='ending'end
function Song:phase()
 local L=self.len or self.o.len
 return self.pos,L,(L and L>0)and min(1,self.pos/L)or 1
end
-- its loudness now (0..1): from its envelope, else a gentle swell
function Song:level()
 local env=self.env
 if self.state~='playing'then return 0 end
 if env then
  local c=env:byte(floor(self.pos*10)+1)
  return c and(c-48)/9 or 0
 end
 return .62+.25*sin(self.pos*2.1)
end
function Song:duckLevel(t)
 local o=self.o
 if not self.t0 then return 1 end
 local d=1-(1-o.duck)*smooth((t-self.t0)/o.duckIn)
 if self.unduckT then
  local u=(t-self.unduckT)/o.duckOut
  if u>=1 then return 1 end
  d=d+(1-d)*smooth(u)
 end
 return d
end
function Song:unduck(t)if self.t0 and not self.unduckT then self.unduckT=t end end
function Song:release()
 local s=self.src
 if s then pcall(s.stop,s);pcall(s.release,s)end
 self.src=nil
 if self.state=='playing'or self.state=='ending'then self.state='ended';self.why=self.why or'released'
 elseif self.state=='ready'or self.state=='idle'then self.state='released'end
end

------------------------------------------------------------------ sleep
-- How someone nods off: 'droop' (asleep on their feet, A radians: a nod
-- down, a catch, then down for good, and breathing) or 'fall' (a wobble,
-- then over they go, faster and faster, to A -- about 85 degrees -- and a
-- little bounce as they land). u: 0..1 through the nodding off; tau: seconds
-- since it began.
function E.dozeAngle(u,A,clock,seed)
 if u<=0 then return 0 end
 local breathe=.035*sin(clock*1.5+(seed or 0)*1.7)
 if u>=1 then return A+breathe end
 local a
 if u<.38 then a=.62*A*smooth(u/.38)
 elseif u<.55 then a=.62*A-.37*A*smooth((u-.38)/.17)
 else a=.25*A+.75*A*smooth((u-.55)/.45)end
 return a+breathe*smooth((u-.8)/.2)
end
function E.fallAngle(tau,A,dur)
 dur=dur or 1.2
 if tau<=0 then return 0 end
 local w=.3*dur
 if tau<w then return .08*sin(tau/w*pi*2)*smooth(tau/(.4*w))end
 local u=(tau-w)/(.45*dur)
 if u<1 then return A*u*u end
 local b=tau-w-.45*dur
 return A-.16*abs(sin(b*pi/.18))*math.exp(-b*6)
end
-- waking (w s since): with a 'start' (a jerk back and a hop) or a
-- 'stretch' (up, then a lean back and a rise); someone lying down springs
-- up. Returns the angle, a hop, and true when done.
function E.wakeCurve(w,aw,style,kind)
 if kind=='fall'or aw>.9 then
  if w>=.6 then return 0,0,true end
  return aw*(1-smooth(w/.35)),2.4*sin(pi*clamp01(w/.45)),false
 end
 if style=='stretch'then
  if w>=1.05 then return 0,0,true end
  if w<.35 then return aw*(1-smooth(w/.35)),0,false end
  local v=clamp01((w-.35)/.7)
  return-.17*sin(pi*v),.25*sin(pi*v),false
 end
 if w>=.5 then return 0,0,true end
 local a
 if w<.15 then a=lerp(aw,-.14,smooth(w/.15))else a=-.14*(1-smooth((w-.15)/.35))end
 return a,1.3*sin(pi*clamp01(w/.3)),false
end
-- A set of sleepers. add(key,at,dur,kind,A,dx,dz,opts): key as
-- ParadeCast.pose takes it (a person, 'player', 'partner'); `at` on the
-- clock update() is given (when they start to nod off), over `dur`; (dx,dz)
-- the way their head goes, or opts.rel={forward,side} (from the way they
-- face when they nod off); opts.head (the middle of their head), opts.zz
-- (false: no Zz), opts.wake ('start'|'stretch'). update(clock,t) every
-- frame; wake(t) wakes them all; fraction() 0..1 how asleep they are;
-- clear() puts everyone upright at once.
local Sleep={};Sleep.__index=Sleep
E.Sleep=Sleep
function Sleep.new(eggs)return setmetatable({eggs=eggs,list={}},Sleep)end
function Sleep:add(key,at,dur,kind,A,dx,dz,opts)
 local m={key=key,at=at,dur=max(.05,dur or 1),kind=kind or'droop',A=A or .32,dx=dx,dz=dz,
  rel=opts and opts.rel,head=opts and opts.head,zz=not(opts and opts.zz==false),style=opts and opts.wake,
  seed=#self.list+1,state='awake',a=0,y=0,level=0}
 self.list[#self.list+1]=m
 return m
end
local POSE_OPTS={y=0}
function Sleep:update(clock,t)
 local CP=cast()
 local eg=self.eggs
 for i=1,#self.list do
  local m=self.list[i]
  local a,y=0,0
  if m.state=='awake'and clock>=m.at and not self.woke then
   m.state='dozing'
   if not(m.dx and m.dz)then
    local yaw=0
    if CP then local x,_,_,yw=CP.feetOf(m.key,eg.game);if x then yaw=yw or 0 end end
    local fx,fz=sin(yaw),cos(yaw)
    local r=m.rel or EMPTY
    local f,s=r[1]or 1,r[2]or 0
    m.dx,m.dz=fx*f+fz*s,fz*f-fx*s
    if abs(m.dx)+abs(m.dz)<1e-6 then m.dx,m.dz=fx,fz end
   end
   if type(m.key)=='table'then eg:hold(m.key,'sleep')end
  end
  local st=m.state
  local eyes=0
  -- (TEST253: drowsy -- heavy blinks before they nod off)
  local EY=E.EYES
  if EY and st=='awake'and not self.woke then
   local ws=max(0,m.at-EY.drowsy)
   local span=m.at-ws
   if span>=EY.minDrowsy and clock>=ws and clock<m.at then
    eyes=E.drowsyEyes((clock-ws)/span)
    if eyes>.01 then a=EY.dip*m.A*eyes/.6 end
    m.drowsy=eyes>.01
   else m.drowsy=false end
  end
  if st=='dozing'or st=='asleep'then
   local tau=clock-m.at
   local u=tau/m.dur
   if m.kind=='fall'then a=E.fallAngle(tau,m.A,m.dur)else a=E.dozeAngle(u,m.A,clock,m.seed)end
   if EY then eyes=E.dozeEyes(u)end
   m.level=clamp01(u)
   if st=='dozing'and u>=1 then m.state='asleep'end
   if m.zz and not m.zzOn and u>=.6 then m.zzOn=true;eg.zz:add(m.key,t,m.seed)end
  elseif st=='waking'then
   local w=t-m.wt0
   m.level=0
   if w<0 then a=m.aw;if EY then eyes=1 end
   else
    local done
    a,y,done=E.wakeCurve(w,m.aw,m.style,m.kind)
    if done then m.state='up';a,y=0,0 end
   end
  end
  m.a,m.y,m.eyes=a,y,eyes
  if CP then
   local s2=m.state
   if s2=='dozing'or s2=='asleep'or s2=='waking'or m.drowsy then
    POSE_OPTS.y=y;POSE_OPTS.head=m.head;POSE_OPTS.eyes=eyes
    -- (drowsy: the way their head dips, settled as it is when they nod off)
    local dx,dz=m.dx,m.dz
    if not(dx and dz)then
     local yaw=0
     if CP.feetOf then local x,_,_,yw=CP.feetOf(m.key,eg.game);if x then yaw=yw or 0 end end
     dx,dz=sin(yaw),cos(yaw)
    end
    CP.pose(m.key,a,dx,dz,POSE_OPTS)
    m.posed=true
   elseif m.posed then
    m.posed=false;CP.pose(m.key,nil)
    -- (TEST243: up again -- posed afresh by the crowd's detail levels)
    if CP.lodReset then pcall(CP.lodReset,m.key)end
    if type(m.key)=='table'then eg:unhold(m.key)end
   end
  end
 end
end
function Sleep:wake(t)
 if self.woke then return end
 self.woke=t
 local k=0
 for _,m in ipairs(self.list)do
  if m.state=='dozing'or m.state=='asleep'then
   k=k+1
   m.state='waking';m.wt0=t+E.WAKE_GAP*(k-1);m.aw=m.a
   m.style=m.style or((k%2==1)and'start'or'stretch')
   if m.zzOn then m.zzOn=false;self.eggs.zz:remove(m.key,t)end
  elseif m.state=='awake'then m.state='up'end
 end
end
function Sleep:fraction()
 local n=#self.list
 if n==0 then return 0 end
 local s=0
 for i=1,n do s=s+(self.list[i].level or 0)end
 return s/n
end
function Sleep:count(state)
 local n=0
 for _,m in ipairs(self.list)do if m.state==state then n=n+1 end end
 return n
end
function Sleep:allUp()
 for _,m in ipairs(self.list)do if m.state~='up'and m.state~='awake'then return false end end
 return true
end
function Sleep:clear()
 local CP=cast()
 for _,m in ipairs(self.list)do
  if m.posed and CP then CP.pose(m.key,nil)end
  m.posed=false
  if type(m.key)=='table'then self.eggs:unhold(m.key)end
  if m.zzOn then m.zzOn=false;self.eggs.zz:remove(m.key)end
  m.state='up'
 end
 self.list={}
end

------------------------------------------------------------------ Zz
-- The one "Zz" over sleeping heads: two letters to a head, rising and
-- growing, drifting to the camera's right. add(key,t,seed), remove(key,t),
-- clear(); draw(eggs,t,cap) in the effect pass.
local Zz={};Zz.__index=Zz
E.Zz=Zz
function Zz.new()return setmetatable({list={}},Zz)end
function Zz:add(key,t,seed)
 for _,z in ipairs(self.list)do
  if z.key==key then z.t0=t;z.t1=nil;return z end
 end
 local z={key=key,t0=t,t1=nil,seed=seed or #self.list+1}
 self.list[#self.list+1]=z
 return z
end
function Zz:remove(key,t)
 for _,z in ipairs(self.list)do if z.key==key and not z.t1 then z.t1=t or-1e9 end end
end
function Zz:clear()self.list={}end
function Zz:count()return #self.list end
function Zz:draw(eggs,t,cap)
 local list=self.list
 for i=#list,1,-1 do local z=list[i];if z.t1 and t-z.t1>.35 then table.remove(list,i)end end
 if #list==0 then return end
 local CP=cast()
 if not CP then return end
 local R=V.require('Voxel3D')
 local rx,rz=1,0
 local ex,ey,ez,vx,vy,vz=nil,0,0,0,0,1
 if R.eye and R.focus then
  ex,ey,ez=R.eye[1],R.eye[2],R.eye[3]
  vx,vy,vz=R.focus[1]-ex,R.focus[2]-ey,R.focus[3]-ez
  local l3=sqrt(vx*vx+vy*vy+vz*vz)
  if l3>1e-6 then vx,vy,vz=vx/l3,vy/l3,vz/l3 end
  local l=sqrt(vx*vx+vz*vz)
  if l>1e-6 then rx,rz=-vz/l,vx/l end
 end
 local n=0
 for i=1,#list do
  if cap and n>=cap then break end
  local z=list[i]
  local hx,hy,hz=CP.headOf(z.key,eggs.game)
  -- (only heads the camera is looking toward: the rest cost nothing)
  if hx and ex then
   local dx,dy,dz=hx-ex,hy-ey,hz-ez
   local d=sqrt(dx*dx+dy*dy+dz*dz)
   if d>1e-6 and(dx*vx+dy*vy+dz*vz)/d<.55 then hx=nil end
  end
  if hx then
   n=n+1
   local fade=smooth((t-z.t0)/.4)*(z.t1 and(1-smooth((t-z.t1)/.3))or 1)
   for j=0,1 do
    local u=((t-z.t0)*.62+z.seed*.37+j*.5)%1
    local s=.6+u*2.2
    eggs:icon('z',hx+rx*s,hy+2.2+u*5.2,hz+rz*s,1.5+u*1.7,.25-.3*u,.86,.92,1,fade*sin(u*pi)*.95)
   end
  end
 end
end

------------------------------------------------------------------ the eggs of one parade
local Eggs={};Eggs.__index=Eggs
E.Eggs=Eggs
local Karp,Puff={},{}
Karp.__index,Puff.__index=Karp,Puff
E.Karp,E.Puff=Karp,Puff
-- what each stop plays (filled at the end of the file): a list of makers,
-- each made with the Eggs when the stop begins (under its card)
E.STOP_GAGS={}

function E.new(parade)
 local self=setmetatable({P=parade,game=parade and parade.game,held={},gags={},voices={},cries={},
  active=false,stopKey=nil,loadQ=nil,tex=nil,snd=nil,drawn=0,cheer=1,duck=1,ticker=1},Eggs)
 self.zz=Zz.new()
 -- the effect pass (made once: a frame makes no closures)
 self.fxFn=function()self:drawFx()end
 return self
end

-- a stop begins (under its card): its gags are made; leaving it lets
-- everything of theirs go
function Eggs:enterStop(i,stop)
 if self.active or #self.gags>0 then self:leaveStop()end
 self.stopKey=stop and stop.key
 self.gags={}
 self.karp,self.puff=nil,nil
 self.played=self.played or{}
 local list=stop and E.STOP_GAGS[stop.key]
 if list and not self.played[stop.key]then
  for _,make in ipairs(list)do
   local ok,g=pcall(make,self,stop)
   if ok and g then self.gags[#self.gags+1]=g else log('a gag would not start: %s',tostring(g))end
  end
 end
 self.active=#self.gags>0
 self.quieted=nil
 if self.active then
  self.played[stop.key]=true
  self.loadQ={'icons','icons2','sounds','cries'}
  self.gi=1
  for _,g in ipairs(self.gags)do
   if g.kind=='karp'then self.karp=g elseif g.kind=='puff'then self.puff=g end
  end
 end
end
-- one thing a frame under the card (true: it did something; false: all done)
function Eggs:loadStep()
 if not self.active then return false end
 while self.gi and self.gi<=#self.gags do
  local g=self.gags[self.gi]
  if g.loadNext then
   local ok,did=pcall(g.loadNext,g)
   if not ok then log('a gag failed to load: %s',tostring(did));pcall(g.release,g);g.state='off'
   elseif did then return true end
  end
  self.gi=self.gi+1
 end
 local q=self.loadQ
 if not q or #q==0 then self.loadQ=nil;return false end
 local step=table.remove(q,1)
 local game=self.game
 if step=='icons'or step=='icons2'then
  self.tex=self.tex or{}
  local list=step=='icons'and{'note1','note2','z'}or{'mic','anger','drop'}
  for _,n in ipairs(list)do
   local ok,img=pcall(makeIcon,n)
   self.tex[n]=ok and img or false
  end
 elseif step=='sounds'then
  self.snd={}
  for k,f in pairs(E.SOUND_FILES)do self.snd[k]=E.loadSource(f)or false end
 elseif step=='cries'then
  pcall(function()
   local S=require('src.core.Sound')
   if S.prewarmCry then
    S.prewarmCry(game.data,E.PUFF.species)
    S.prewarmCry(game.data,E.KARP.species)
   end
  end)
 end
 return true
end
function Eggs:busy()
 if not self.active then return false end
 return self.loadQ~=nil or(self.gi~=nil and self.gi<=#self.gags)
end

------------------------------------------------------------------ sound
function Eggs:play(name,vol,pitch)
 local base=self.snd and self.snd[name]
 if not base then return nil end
 local g=sfxGain(self.game)
 if g<=0 then return nil end
 local ok,v=pcall(base.clone,base)
 if not(ok and v)then return nil end
 pcall(v.setVolume,v,min(1,(vol or 1)*g))
 pcall(v.setPitch,v,pitch or 1)
 pcall(v.play,v)
 self.voices[#self.voices+1]=v
 return v
end
function Eggs:cry(species,pitch)
 local src=nil
 pcall(function()src=require('src.core.Sound').playCry(self.game.data,species)end)
 if src then
  if pitch then pcall(src.setPitch,src,pitch)end
  self.cries[#self.cries+1]=src
 end
 return src
end
function Eggs:reap()
 local v=self.voices
 for i=#v,1,-1 do
  local s=v[i];local ok,on=pcall(s.isPlaying,s)
  if not(ok and on)then pcall(s.release,s);table.remove(v,i)end
 end
 local c=self.cries
 for i=#c,1,-1 do
  local s=c[i];local ok,on=pcall(s.isPlaying,s)
  if not(ok and on)then table.remove(c,i)end
 end
end
function Eggs:silence()
 for _,s in ipairs(self.voices)do pcall(s.stop,s);pcall(s.release,s)end
 self.voices={}
 for _,s in ipairs(self.cries)do pcall(s.stop,s)end
 self.cries={}
end

------------------------------------------------------------------ the crowd
-- the parade's own people (its stop's people), their places
local function personAt(e)
 local n=e and e.npc
 if type(n)~='table'then return nil end
 return(tonumber(n.px)or(tonumber(n.cellX)or 0)*16)+8,(tonumber(n.py)or(tonumber(n.cellY)or 0)*16)+8
end
E._personAt=personAt
local YAW={down=0,up=pi,right=pi/2,left=-pi/2}
-- across the street from the camera, nearest `want` cells ahead (fwd: the
-- way you go; away: across, away from the camera)
function Eggs:fanAcross(Px,Pz,fx,fz,ax,az,want)
 local stop=self.P and self.P:stop()
 local best,bd=nil,1e9
 for _,e in ipairs(stop and stop.people or EMPTY)do
  if e.ours and not self.held[e.npc]then
   local x,z=personAt(e)
   if x then
    local dx,dz=x-Px,z-Pz
    local along,across=dx*fx+dz*fz,dx*ax+dz*az
    if across>12 and across<70 and along>-40 and along<80 then
     local d=abs(along-want)+abs(across-32)*.3
     if d<bd then best,bd=e,d end
    end
   end
  end
 end
 return best
end
-- a person held for a gag: the crowd's watch leaves them be; `hop`: they
-- march on the spot for that long (a fan's throw or catch)
function Eggs:hold(npc,why,untilT)
 if type(npc)~='table'then return end
 self.held[npc]=why or true
 local ow=self.game and self.game.overworld
 if ow then
  ow.marchers=ow.marchers or{}
  ow.marchers[npc]=(why=='hop')and true or nil
 end
 if why=='hop'then self.hops=self.hops or{};self.hops[npc]=untilT
 elseif self.hops then self.hops[npc]=nil end
end
function Eggs:unhold(npc)
 if self.held[npc]==nil then return end
 self.held[npc]=nil
 local ow=self.game and self.game.overworld
 if ow and ow.marchers then ow.marchers[npc]=nil end
 if self.hops then self.hops[npc]=nil end
end
function Eggs:unholdAll()
 local list={}
 for npc in pairs(self.held)do list[#list+1]=npc end
 for _,npc in ipairs(list)do self:unhold(npc)end
 self.held={}
 self.hops=nil
end

------------------------------------------------------------------ every frame
function Eggs:update(dt,t)
 if not self.active then return end
 local P=self.P
 if not P or P.finished then return end
 pcall(function()V.require('ParadePartnerSleep').pinTick()end)
 self:reap()
 -- (the parade skipped to its end: quiet now -- the song stopped and let
 -- go, everyone upright)
 if P.phase=='end'then
  -- (TEST235 ending: a skip quiets everything at once; at the parade's own
  -- end a gag may keep its scene under the last white -- the sleeping,
  -- doodled town -- and it is let go with the parade)
  if not self.quieted and(P.skipped or not self:keepAtEnd())then self.quieted=true;self:quiet()end
  return
 end
 if P.phase~='show'and P.phase~='finale'and P.phase~='reveal'then return end
 -- the fans' hops end
 if self.hops then
  for npc,u in pairs(self.hops)do
   if t>=u then
    if self.held[npc]=='hop'then self:unhold(npc)else self.hops[npc]=nil end
    break
   end
  end
 end
 local cheer,duck,ticker=1,1,1
 for i=1,#self.gags do
  local g=self.gags[i]
  if g.update then g:update(dt,t)end
  if g.levels then
   local c,d,k=g:levels(t)
   cheer,duck,ticker=min(cheer,c or 1),min(duck,d or 1),min(ticker,k or 1)
  end
 end
 self.cheer,self.duck,self.ticker=cheer,duck,ticker
end
-- (TEST235 ending) does a gag keep its scene under the parade's last white?
function Eggs:keepAtEnd()
 for i=1,#self.gags do local g=self.gags[i];if g.keepAtEnd and g:keepAtEnd()then return true end end
 return false
end
-- (TEST235 ending) the hour, when a gag takes it on (nil: the stop's own)
function Eggs:tod(t,cur)
 if not self.active then return nil end
 for i=1,#self.gags do
  local g=self.gags[i]
  if g.tod then local v=g:tod(t,cur);if tonumber(v)then return v end end
 end
 return nil
end
-- the crowd's cheer (its loop), the march, the ticker tape: 1 = as ever
function Eggs:levels()
 if not self.active then return 1,1,1 end
 return self.cheer or 1,self.duck or 1,self.ticker or 1
end
-- true while a gag has the crowd asleep: no cheering one-shots
function Eggs:quietCrowd()
 for i=1,#self.gags do local g=self.gags[i];if g.quiet and g:quiet()then return true end end
 return false
end
-- the walk is done: the finale waits (true) while a gag's act is on
function Eggs:holdFinale(t)
 if not self.active then return false end
 for i=1,#self.gags do local g=self.gags[i];if g.holdFinale and g:holdFinale(t)then return true end end
 return false
end
-- the finale has run its course: the stop's end waits (true) for a gag
function Eggs:holdEnd(t)
 if not self.active then return false end
 for i=1,#self.gags do local g=self.gags[i];if g.holdEnd and g:holdEnd(t)then return true end end
 return false
end
-- TEST261: render-list Pokemon can appear after the stop's initial NPC list.
function Eggs:posePokemon(posed,state)
 if not self.active then return end
 for _,g in ipairs(self.gags)do if g.posePokemon then g:posePokemon(posed,state)end end
end
-- a gag's camera (a shot, as the parade's own are), when one has it
function Eggs:shot(t)
 if not self.active then return nil end
 for i=1,#self.gags do
  local g=self.gags[i]
  if g.shot then local sh=g:shot(t);if sh then return sh end end
 end
 return nil
end
-- the finale begins (its cannons): everyone up, the cheering and the march back
function Eggs:wake(t)
 if not self.active then return end
 for i=1,#self.gags do local g=self.gags[i];if g.wake then g:wake(t)end end
end
-- (skipped to the end) everything stops at once
function Eggs:quiet()
 for i=1,#self.gags do local g=self.gags[i];if g.quietNow then pcall(g.quietNow,g)end end
 self:silence()
 self.zz:clear()
 self:unholdAll()
 self.cheer,self.duck,self.ticker=1,1,1
end
-- leaving the stop (or the end): everyone awake, everything let go
function Eggs:leaveStop()
 for i=1,#self.gags do local g=self.gags[i];if g.release then pcall(g.release,g)end end
 self.zz:clear()
 self:unholdAll()
 self:silence()
 self.cheer,self.duck,self.ticker=1,1,1
 self.active=false
 if self.tex then for _,img in pairs(self.tex)do if img then pcall(img.release,img)end end end
 self.tex=nil
 if self.snd then for _,s in pairs(self.snd)do if s then pcall(s.stop,s);pcall(s.release,s)end end end
 self.snd=nil
 self.loadQ=nil;self.gi=nil
 -- (TEST244: the gags are gone with the stop; a second leave does nothing)
 self.gags={};self.karp,self.puff=nil,nil
end
function Eggs:release()
 if self.released then return end
 self.released=true
 self:leaveStop()
 self.gags={}
end

------------------------------------------------------------------ MAGIKARP
local K=E.KARP
function Karp.new(eggs)return setmetatable({eggs=eggs,kind='karp',state='wait'},Karp)end
function Karp:loadNext()
 if self.loaded or self.state=='off'then return false end
 self.loaded=true
 self.actor=loadActor(self.eggs.game,{species=K.species,dex=K.dex,want=99,maxW=K.len})
 if not self.actor then self.state='off';log('no Magikarp to throw (no model or picture): skipped')end
 return true
end
function Karp:release()
 if self.actor then releaseActor(self.actor);self.actor=nil end
 if self.state~='off'and self.state~='wait'then self.state='done'end
 if self.state=='wait'then self.state='off'end
end
function Karp:quietNow()self:release()end
function Karp:cue(t)
 local eg=self.eggs;local P=eg.P
 local stop=P:stop()
 local Pp=P.pSmooth
 if not(Pp and stop)then return end
 local ow=eg.game and eg.game.overworld
 local face=ow and ow.player and ow.player.facing
 local yw=YAW[face]or-pi/2
 local fx,fz=sin(yw),cos(yw)
 -- across, away from the camera
 local ax,az=-fz,fx
 local cam=P.cam
 if cam and cam.eye and((cam.eye[1]-Pp[1])*ax+(cam.eye[3]-Pp[3])*az)>0 then ax,az=-ax,-az end
 self.fx,self.fz,self.ax,self.az=fx,fz,ax,az
 self.ride=P.float~=nil and P.float.x~=nil
 -- when to leave: before the next cut
 local nextAt=nil
 for k,sh in ipairs(stop.shots or EMPTY)do
  if sh==P.shot then nextAt=stop.shots[k+1]and stop.shots[k+1].at end
 end
 -- (the pace: a cell every 16 x STEP frames of 1/60 s; slower in real time
 -- on a slow phone, which only leaves it more room)
 local okC,CPm=pcall(V.require,'ChampionParade')
 local step=self.ride and(okC and tonumber(CPm.FLOAT_STEP)or 3.2)or(okC and tonumber(CPm.STEP_SCALE)or 2.3)
 local pace=60/(16*step)
 self.exitAt=(nextAt or((P.progress or 0)+4.5))-((self.ride and K.exitFly or K.walkExitFly)+K.exitSpare)*pace
 self.map=ow and ow.map
 -- the thrower: a fan across the street, a little ahead
 local fan=eg:fanAcross(Pp[1],Pp[3],fx,fz,ax,az,18)
 local sx,sz
 if fan then sx,sz=personAt(fan);self.thrower=fan.npc;eg:hold(fan.npc,'hop',t+.6)
 else sx,sz=Pp[1]+fx*18+ax*34,Pp[3]+fz*18+az*34 end
 self.sx,self.sy,self.sz=sx,groundAt(self.map,sx,sz)+15,sz
 self.t0=t;self.ts=t;self.state='fly'
 self.spot=1;self.next=1;self.side=1;self.flipYaw=0
 self.flop0=nil;self.hops=0
 self.x,self.y,self.z=self.sx,self.sy,self.sz
 self.roll,self.pitch,self.vanish=0,0,0
 self.drops=self.drops or{}
 for i=1,16 do self.drops[i]=self.drops[i]or{on=false}end
 self.ring=nil
 self.rx,self.ry,self.rz=nil,nil,nil
 eg:play('whoosh',.55,1.05)
 log('Magikarp thrown (%s), from %s',self.ride and'onto the float'or'onto the street',fan and tostring(fan.npc.id)or'behind the crowd')
end
-- a float-local point in the world (the float's own toWorld)
local function onFloat(fl,lx,ly,lz)
 local c,s=cos(fl.yaw or 0),sin(fl.yaw or 0)
 return fl.x+c*lx+s*lz,fl.y+ly,fl.z-s*lx+c*lz
end
E._onFloat=onFloat
-- where it is headed for its i-th rest: riding, a spot on the dais (it
-- moves with the float); walking, the street a little ahead of you and
-- toward the far pavement (it moves with you until it lands there)
function Karp:target(i)
 local P=self.eggs.P
 if self.ride then
  local fl=P.float
  if not(fl and fl.x)then return nil end
  local s=K.spots[(i-1)%#K.spots+1]
  return onFloat(fl,s[1],s[3],s[2])
 end
 local Pp=P.pSmooth
 if not Pp then return nil end
 local lead=K.lead+((i%2==0)and 3 or 0)
 local side=K.side+((i%3==0)and 2 or 0)
 local x,z=Pp[1]+self.fx*lead+self.ax*side,Pp[3]+self.fz*lead+self.az*side
 return x,groundAt(self.map,x,z),z
end
-- where it lies now: riding, its spot on the float; walking, where it landed
function Karp:rest()
 if self.ride then return self:target(self.spot)end
 return self.rx,self.ry,self.rz
end
function Karp:land(x,y,z)
 if not self.ride then self.rx,self.ry,self.rz=x,y,z end
end
-- the fish's size: its length, height, thickness (and the turn that puts
-- its length along its own z)
function Karp:dims()
 local act=self.actor
 local md=act and act.md
 if md then
  if md.ez>=md.ex then return md.ez,md.ey,md.ex,0 end
  return md.ex,md.ey,md.ez,-pi/2
 end
 return K.len,K.len*.62,K.len*.32,0
end
-- the height of its middle above what it lies on, at that roll
function Karp:restH(roll)
 local _,h,th=self:dims()
 return abs(cos(roll))*h*.5+abs(sin(roll))*th*.5
end
function Karp:splash(x,y,z,n,t,big)
 for k=1,n do
  local d=nil
  for _,q in ipairs(self.drops)do if not q.on then d=q;break end end
  if not d then break end
  local h1,h2,h3=hash(k,t),hash(t,k+3),hash(k+7,t*1.3)
  local a=h1*pi*2
  local sp=(big and 13 or 9)*(.5+.6*h2)
  d.on=true;d.t0=t;d.x,d.y,d.z=x,y+.4,z
  d.vx,d.vz=cos(a)*sp,sin(a)*sp
  d.vy=(big and 20 or 15)*(.6+.5*h3)
  d.s=.55+.5*h2
 end
 local r=self.ring or{}
 r.t0,r.x,r.y,r.z,r.big=t,x,y+.08,z,big
 self.ring=r
end
-- which way it lies: across the float (its length along the float's own
-- x), or across the street ahead of you; plus a wiggle
function Karp:lieYaw(w)
 local P=self.eggs.P
 local base
 if self.ride and P.float then base=(P.float.yaw or 0)+pi/2
 else base=atan2(self.ax,self.az)end
 return base+(self.flipYaw or 0)+(w or 0)
end
function Karp:hopFrom(t0)
 self.hopT0=t0
 local n=self.spot%#K.spots+1
 self.next=n
 self.rollFrom=self.roll or pi/2
 self.side=-(self.side or 1)
 self.rollTo=self.rollFrom+pi*self.side
 self.hopH=K.hopH*(.8+.45*hash(self.hops or 0,1.7))
 self.wig=(hash(self.hops or 0,9.1)-.5)*.9
 if hash(self.hops or 0,4.4)>.72 then self.flipYaw=((self.flipYaw or 0)+pi)%(2*pi)end
end
function Karp:toExit(t0,fast)
 local eg=self.eggs;local P=eg.P
 self.state='exit';self.ts=t0;self.fast=fast
 self.ex,self.ey,self.ez=self.x or self.sx,self.y or self.sy,self.z or self.sz
 self.exRoll=self.roll or pi/2
 local Pp=P.pSmooth or{self.ex,self.ey,self.ez}
 local fan=eg:fanAcross(Pp[1],Pp[3],self.fx or-1,self.fz or 0,self.ax or 0,self.az or-1,26)
 if fan then
  self.catcher=fan.npc
  local x,z=personAt(fan)
  self.cx,self.cy,self.cz=x,groundAt(self.map,x,z)+13,z
 else
  self.catcher=nil
  self.cx=Pp[1]+(self.fx or-1)*26+(self.ax or 0)*40
  self.cz=Pp[3]+(self.fz or 0)*26+(self.az or-1)*40
  self.cy=groundAt(self.map,self.cx,self.cz)+12
 end
end
function Karp:update(dt,t)
 local st=self.state
 if st=='off'or st=='done'then return end
 local eg=self.eggs;local P=eg.P
 if st=='wait'then
  if not self.actor then if self.loaded then self.state='off'end;return end
  local sh=P.shot
  if P.phase=='show'and sh and sh.name==K.shot and(P.progress or 0)>=(sh.at or 0)+K.cue then
   self:cue(t)
  end
  return
 end
 -- a cut before it could leave: away at once
 if P.shot and P.shot.name~=K.shot and(st=='fly'or st=='flop')then
  self:toExit(t,true);st='exit'
 end
 -- the spray
 for _,d in ipairs(self.drops)do if d.on and t-d.t0>.55 then d.on=false end end
 if st=='fly'or st=='flop'or st=='exit'then stepActor(self.actor,t,eg.game)end
 if st=='fly'then
  local dur=self.ride and K.fly or K.walkFly
  local u=clamp01((t-self.ts)/dur)
  local tx,ty,tz=self:target(self.spot)
  if not tx then self:toExit(t,true);return end
  self.x=lerp(self.sx,tx,u);self.z=lerp(self.sz,tz,u)
  self.roll=pi/2*smooth((u-.7)/.3)
  self.y=lerp(self.sy,ty+self:restH(self.roll),u)+K.arc*4*u*(1-u)
  self.pitch=u*4*pi
  self.yaw=self:lieYaw(0)
  if u>=1 then
   self.state='flop';self.ts=t;self.flop0=t
   self.pitch=0;self.roll=pi/2;self.side=1
   self:land(tx,ty,tz)
   self:splash(tx,ty,tz,K.drops+2,t,true)
   eg:play('slap',.9,1)
   self.cryAt=t+.22
   self:hopFrom(t+K.rest+.12)
  end
  return
 end
 if self.cryAt and t>=self.cryAt then self.cryAt=nil;eg:cry(K.species)end
 if st=='flop'then
  -- time to go? (before the next cut: off at once, from wherever it is)
  if(P.progress or 0)>=self.exitAt or t-self.flop0>=K.maxFlop then self:toExit(t,false);return end
  local ax_,ay_,az_=self:rest()
  if not ax_ then self:toExit(t,true);return end
  if t<self.hopT0 then
   -- lying there: a wiggle of the tail
   self.x,self.z=ax_,az_
   self.y=ay_+self:restH(self.roll)
   self.yaw=self:lieYaw(.12*sin((t-self.ts)*21))
   return
  end
  local u=clamp01((t-self.hopT0)/K.hop)
  local bx,by,bz=self:target(self.next)
  if not bx then self:toExit(t,true);return end
  local e=smooth(u)
  self.x=lerp(ax_,bx,e);self.z=lerp(az_,bz,e)
  self.roll=self.rollFrom+(self.rollTo-self.rollFrom)*e
  self.y=lerp(ay_,by,u)+self:restH(self.roll)+self.hopH*4*u*(1-u)
  self.yaw=self:lieYaw(self.wig*sin(u*pi))
  if u>=1 then
   self.spot=self.next;self.hops=self.hops+1;self.roll=self.rollTo
   self:land(bx,by,bz)
   self:splash(bx,by,bz,K.drops,t,false)
   eg:play('flop',.55,.92+.22*hash(self.hops,3))
   if self.hops==3 then eg:cry(K.species)end
   self.ts=t
   self:hopFrom(t+K.rest)
  end
  return
 end
 if st=='exit'then
  if t<self.ts then
   local x,y,z=self:rest()
   if x then self.x,self.z=x,z;self.y=y+self:restH(self.roll)end
   self.ex,self.ey,self.ez=self.x,self.y,self.z
   return
  end
  local dur=self.fast and .42 or(self.ride and K.exitFly or K.walkExitFly)
  local u=clamp01((t-self.ts)/dur)
  local tx,ty,tz=self.cx,self.cy,self.cz
  if self.catcher then
   local x,z=personAt({npc=self.catcher})
   if x then tx,tz=x,z end
  end
  self.x=lerp(self.ex,tx,u);self.z=lerp(self.ez,tz,u)
  self.y=lerp(self.ey,ty,u)+K.exitArc*4*u*(1-u)
  self.pitch=-u*3*pi
  self.roll=(self.exRoll or pi/2)*(1-u)
  self.yaw=self:lieYaw(0)
  self.vanish=smooth((u-.82)/.18)
  if u>=1 then
   self.state='gone';self.ts=t
   self:splash(tx,ty,tz,K.drops,t,false)
   if self.catcher then eg:hold(self.catcher,'hop',t+.8)end
   eg:play('flop',.45,1.25)
   log('Magikarp flopped back to the crowd after %d flops',self.hops or 0)
  end
  return
 end
 if st=='gone'then
  local busy=self.ring and t-self.ring.t0<.5
  for _,d in ipairs(self.drops)do if d.on then busy=true end end
  if not busy then self.state='done';eg.karpDone=true end
 end
end

------------------------------------------------------------------ JIGGLYPUFF
local PU=E.PUFF
local STOMPS={.55,.80}
local STOMP_KEYS={'stomp1','stomp2'}
local HOP_KEYS={'hop1','hop2','hop3','hop4','hop5','hop6'}
function Puff.new(eggs)
 local self=setmetatable({eggs=eggs,kind='puff',state='wait'},Puff)
 self.song=Song.new(E.SONG)
 self.sleep=Sleep.new(eggs)
 self.pt=E.PT
 return self
end
-- under the card: its model, then the song's Source
function Puff:loadNext()
 if self.state=='off'then return false end
 if not self.modelTried then
  self.modelTried=true
  self.actor=loadActor(self.eggs.game,{species=PU.species,dex=PU.dex,want=PU.h,maxW=PU.maxW})
  if not self.actor then self:skip('no Jigglypuff to sing (no model or picture)')end
  return true
 end
 if not self.songTried then
  self.songTried=true
  if not self.song:load()then self:skip('no song to sing (neither the recording nor the lullaby would load)');return true end
  self.pt=self.song.kind=='synth'and E.PT_SYNTH or E.PT
  log('Jigglypuff will sing %s: %.2f s%s (%s)',self.song.kind=='synth'and'the stand-in lullaby'or"Joseph's song",
   self.song.len,self.song.capped and', faded out at the cap'or'',tostring(self.song.how))
  return true
 end
 return false
end
function Puff:skip(why)
 self.state='off'
 log('%s: the Jigglypuff gag is skipped',why)
 self.song:release()
 self.sleep:clear()
 if self.actor then releaseActor(self.actor);self.actor=nil end
end
function Puff:cue(t)
 local eg=self.eggs;local P=eg.P
 local stop=P:stop()
 local set=stop and stop.set
 local rope=set and set.ropes and set.ropes[1]
 if not rope then self:skip('no rope post to stand on');return end
 local ow=eg.game and eg.game.overworld
 self.map=ow and ow.map
 local x=rope.x0+(PU.post-1)*(rope.step or 20)
 self.rope=rope
 self.post=PU.post
 self.gx,self.gz=x,rope.z
 self.gy=groundAt(self.map,x,rope.z)
 self.top=self.gy+PU.postTop
 -- the end of your road (the float shot's mark)
 local okE,Ep=pcall(P.roadEnd,P,stop)
 self.roadEnd=okE and Ep or{x,self.gy,rope.z+50}
 -- the fan behind the post tosses it up
 local fan,bd=nil,1e9
 for _,e in ipairs(stop.people or EMPTY)do
  if e.ours then
   local px,pz=personAt(e)
   if px then local d=(px-x)^2+(pz-(rope.z-13))^2;if d<bd then fan,bd=e,d end end
  end
 end
 local pt=self.pt
 if fan then
  local px,pz=personAt(fan)
  self.fromX,self.fromZ=px,pz
  eg:hold(fan.npc,'hop',t+pt.toss+pt.land)
 else self.fromX,self.fromZ=x,rope.z-14 end
 self.fromY=groundAt(self.map,self.fromX,self.fromZ)+14
 -- who will fall asleep: the parade's own people round the post, nearest
 -- first, in a wave over the song (the way their heads go is settled as
 -- they nod off: mostly forward, some to a side, now and then back)
 local list={}
 for _,e in ipairs(stop.people or EMPTY)do
  if e.ours and e.npc~=(fan and fan.npc)then
   local px,pz=personAt(e)
   if px then
    local d=sqrt((px-x)^2+(pz-rope.z)^2)
    if d<=PU.sleepR then list[#list+1]={e=e,d=d}end
   end
  end
 end
 table.sort(list,function(a,b)return a.d<b.d end)
 if fan then table.insert(list,min(#list+1,3),{e=fan,d=0})end
 local n=min(#list,PU.sleepMax)
 local L=self.song.len or E.SONG_LEN
 local dur=min(E.DOZE_MAX,E.DOZE_IN*L)
 for k=1,n do
  local npc=list[k].e.npc
  local h=hash(k,5.5)
  local r=k%5
  local rel={1,0}
  if r==2 then rel={.35,1}elseif r==4 then rel={.35,-1}elseif r==3 and h>.5 then rel={-1,0}end
  local at=L*(E.DOZE0+(E.DOZE1-E.DOZE0)*(n>1 and(k-1)/(n-1)or 0))
  self.sleep:add(npc,at,dur,'droop',.28+.12*h,nil,nil,{rel=rel})
 end
 self.t0=t;self.state='act';self.ph='toss'
 self.gameT=0
 self.notes=self.notes or{}
 for i=1,8 do self.notes[i]=self.notes[i]or{on=false}end
 self.dust=self.dust or{}
 for i=1,6 do self.dust[i]=self.dust[i]or{on=false}end
 self.nextNote=0
 self.yaw=nil
 self.played={}
 self.beatI,self.beatShot=nil,nil
 self.x,self.y,self.z=self.fromX,self.fromY,self.fromZ
 log('Jigglypuff on the rope post at %.0f,%.0f; %d of the crowd within earshot',x,rope.z,n)
end
-- the post k posts along the rope from its own (its huff goes east)
function Puff:postAt(k)
 local r=self.rope
 local x=r.x0+(self.post-1+k)*(r.step or 20)
 return x,groundAt(self.map,x,r.z)+PU.postTop,r.z
end
-- once a beat: do something
function Puff:once(key)
 if self.played[key]then return false end
 self.played[key]=true
 return true
end
-- the doze clock: the song's own (then on past its end)
function Puff:clock(t)
 local s=self.song
 if s.state=='playing'then return s.pos end
 if s:ended()then return(s.len or 0)+(t-(self.endT or t))end
 return 0
end
function Puff:startSong(t)
 local eg=self.eggs
 self.song:play(eg.game,t)
 -- (a song that cannot start is over at once: the gag goes on)
 if self.song.state~='playing'then self.song.state='ended';self.song.why='unplayable'end
 self.singT=t
 self:planBeats()
 local md=self.actor and self.actor.md
 if md then
  local ok=false
  pcall(function()ok=md.inst:playMove(E.SING_MOVE,true)and true or false end)
  if ok then md.context='move';md.once=nil;md.tick=nil else pcall(HF().playTeamModel,md,'idle',false)end
 end
 log('Jigglypuff sings (%s, %.2f s)',self.song.kind=='synth'and'the stand-in'or"Joseph's song",self.song.len or 0)
end
-- the camera's beats for this song's length (song fractions)
function Puff:planBeats()
 local L=max(.5,self.song.len or E.SONG_LEN)
 local u0=min(E.BEAT_U0,3/L)
 local ub=max(E.BEAT_U1,1-E.BACK_S/L)
 -- (TEST244: back on Jigglypuff a little before the fireworks interrupt it)
 local INT=E.INTERRUPT
 if INT then ub=min(ub,max(u0+.05,(min(INT.u*L,L-(INT.endGap or 1.5))-INT.backLead)/L))end
 local span=ub-u0
 local n=max(1,floor(span*L/E.BEAT_CYCLE+.5))
 local W=E.BEAT_W
 local wsum=W[1]+W[2]+W[3]
 local names={{'close','kerb','float'},{'close2','kerb2','float2'}}
 local seq={}
 local u=u0
 for c=1,n do
  local nm=names[(c-1)%2+1]
  for j=1,3 do
   local du=W[j]/wsum*span/n
   seq[#seq+1]={name=nm[j],u0=u,u1=u+du}
   u=u+du
  end
 end
 seq[#seq+1]={name='back',u0=ub}
 local out={}
 for k,b in ipairs(seq)do
  if b.u1 and(b.u1-b.u0)*L<E.BEAT_MIN then
   if seq[k+1]then seq[k+1].u0=b.u0 end
  else out[#out+1]=b end
 end
 self.beats=out
end
-- the beat for song fraction u (nil: none yet)
function Puff:beatFor(u)
 local pick=nil
 for i,b in ipairs(self.beats or EMPTY)do if u>=b.u0 then pick=i end end
 return pick
end
function Puff:makeShot(i,t)
 local b=self.beats[i]
 local cam=E.CAM[b.name]
 local P=self.eggs.P
 local ends=cam
 if cam.road and cam.walk and P:walking()then ends=cam.walk end
 local ox,oy,oz
 if cam.road then local R_=self.roadEnd;ox,oy,oz=R_[1],R_[2],R_[3]else ox,oy,oz=self.gx,self.gy,self.gz end
 local L=self.song.len or E.SONG_LEN
 local pos=self:clock(t)
 local pt=self.pt
 local dur
 if b.u1 then dur=max(.5,b.u1*L-pos)
 else dur=max(.5,L-min(pos,L))+pt.notice+pt.puff+pt.huff end
 local function endOf(e)
  return{eye={ox+e.eye[1],oy+e.eye[2],oz+e.eye[3]},focus={ox+e.focus[1],oy+e.focus[2],oz+e.focus[3]},fov=e.fov,world=true}
 end
 return{kind='crane',dur=dur,from=endOf(ends[1]),to=endOf(ends[2]),name='jigglypuff '..b.name,shake=cam.shake}
end
-- (TEST244) back on it after the bang: the 'back' beat's move, as long as
-- its puff and huff take
function Puff:angryShotFor(t)
 local INT=E.INTERRUPT
 local cam=INT.angry or E.CAM.back
 local ox,oy,oz=self.gx,self.gy,self.gz
 local function endOf(e)
  return{eye={ox+e.eye[1],oy+e.eye[2],oz+e.eye[3]},focus={ox+e.focus[1],oy+e.focus[2],oz+e.focus[3]},fov=e.fov,world=true}
 end
 local pt=self.pt
 return{kind='crane',dur=pt.puff+pt.huff+INT.hold,from=endOf(cam[1]),to=endOf(cam[2]),name='jigglypuff angry',shake=E.CAM.back.shake}
end
-- (TEST245) where in the song the fireworks go (seconds)
function Puff:interruptMark(L)
 local INT=E.INTERRUPT
 return min(INT.u*L,max(0,L-(INT.endGap or 1.5)))
end
-- (TEST244) may the fireworks go now? It sings, the song is far enough
-- along, and the plaza is asleep (or it is late enough not to wait)
function Puff:interruptReady()
 local INT=E.INTERRUPT
 if not INT or self.ph~='sing'or self.song.state~='playing'then return false end
 local pos,L=self.song:phase()
 if not(L and L>0)then return false end
 local mark=self:interruptMark(L)
 if pos<mark then return false end
 return self.sleep:fraction()>=INT.minSleep or pos>=min(mark+INT.late,L-.4)
end
-- its camera: once the walk is done and it sings, the beats
function Puff:shot(t)
 if self.state~='act'or not self.t0 then return nil end
 -- (TEST244: interrupted -- the finale's own crane on the rockets and the
 -- waking crowd first, then back on Jigglypuff, puffing up and stomping off)
 if self.interruptT then
  if t-self.interruptT<E.INTERRUPT.watch then return nil end
  if not self.angryShot then
   local ok,sh=pcall(self.angryShotFor,self,t)
   self.angryShot=ok and sh or false
   if not ok then log('the angry shot failed: %s',tostring(sh))end
  end
  return self.angryShot or nil
 end
 local P=self.eggs.P
 if not(P.walk and P.walk.done)then return nil end
 local ph=self.ph
 if ph=='toss'or ph=='land'or ph=='mic'then return nil end
 local u=ph=='sing'and select(3,self.song:phase())or 1
 local i=self:beatFor(u)
 if not i then return nil end
 if i~=self.beatI then
  self.beatI=i
  local ok,sh=pcall(self.makeShot,self,i,t)
  self.beatShot=ok and sh or nil
  if not ok then log('a camera beat failed: %s',tostring(sh))end
 end
 return self.beatShot
end
function Puff:levels(t)
 if not self.t0 then return 1,1,1 end
 local f=self.woke and 0 or self.sleep:fraction()
 return 1-f,self.song:duckLevel(t),1-(1-E.TICKER_LOW)*f
end
function Puff:quiet()
 return self.t0~=nil and not self.woke and self.sleep:fraction()>.02
end
function Puff:holdFinale(t)
 if self.state~='act'then return false end
 -- (TEST244: the fireworks interrupt it: the finale goes mid-song)
 if self.interruptT or self:interruptReady()then return false end
 -- (safety: never past the song's own cap and a little more, in game time)
 if(self.gameT or 0)>(self.song.len or E.SONG_LEN)+self.song.o.grace+E.HOLD_PAD then return false end
 return true
end
-- (TEST244, safety) the stop's end waits while it is still stomping off
-- after the bang (8 s at most)
function Puff:holdEnd(t)
 if self.interruptT==nil then return false end
 if self.state=='act'then return t-self.interruptT<12 end
 return self.goneT~=nil and t-self.goneT<E.INTERRUPT.hold
end
-- the finale's cannons: everyone up, the march and the cheer back
function Puff:wake(t)
 if not self.t0 or self.woke then return end
 self.woke=t
 self.sleep:wake(t)
 self.song:unduck(t)
 self:ridersUp()
 if self.state=='act'and self.ph=='sing'and E.INTERRUPT then
  -- (TEST244: the BANG mid-song: cut off, it jumps, sees them all awake,
  -- then puffs up and stomps off -- it stays for that)
  local INT=E.INTERRUPT
  self.song:cut(t,INT.fade,INT.pitchTo)
  self.interruptT=t;self.endT=t
  -- (TEST245: its own, unhurried puff and huff)
  local pt={}
  for k,v in pairs(self.pt or E.PT)do pt[k]=v end
  pt.puff,pt.huff=INT.puff or pt.puff,INT.huff or pt.huff
  self.pt=pt
  self.ph='startle'
  local md=self.actor and self.actor.md
  if md then pcall(HF().playTeamModel,md,'hit',true)end
  self.eggs:play('boing',.5,1.6)
  log('the fireworks: the song is cut off, the crowd wakes up, Jigglypuff is furious')
  return
 end
 if self.state=='act'then
  -- (the finale came first: it leaves now)
  self.song:release()
  self.state='gone';self.ph='gone';self.vanish=1
 end
 log('the cannons: the crowd wakes up')
end
function Puff:ridersUp()
 if self.ridersPosed then
  local CP=cast()
  if CP then CP.pose('player',nil);CP.pose('partner',nil)end
  self.ridersPosed=false
 end
end
-- you and your partner: a sway and a nod now and then while it sings --
-- drowsy, but awake (ParadeCast's 'player' and 'partner' poses)
function Puff:riders(t)
 local CP=cast()
 if not CP then return end
 local s=self.song
 if not(self.ph=='sing'and s.state=='playing')then self:ridersUp();return end
 local pos,L=s.pos,s.len or E.SONG_LEN
 local amp=smooth(pos/(.2*L))*(1-smooth((pos-(L-.7))/.5))
 local game=self.eggs.game
 for i=1,2 do
  local key=i==1 and'player'or'partner'
  local x,_,_,yaw=CP.feetOf(key,game)
  if x then
   local fx,fz=sin(yaw or 0),cos(yaw or 0)
   local sx,sz=fz,-fx
   local off=(i==1)and 0 or 2.7
   local sway=.045*sin((pos+off)*1.9)
   local p=(pos+off)%5.5
   local nod=p<2.2 and .15*smooth(p/2.2)or(p<2.38 and .15*(1-smooth((p-2.2)/.18))or 0)
   local vx,vz=(fx*nod+sx*sway)*amp,(fz*nod+sz*sway)*amp
   local a=sqrt(vx*vx+vz*vz)
   if a>1e-4 then CP.pose(key,a,vx,vz)else CP.pose(key,nil)end
   self.ridersPosed=true
  end
 end
end
function Puff:update(dt,t)
 local st=self.state
 if st=='off'or st=='done'then return end
 local eg=self.eggs;local P=eg.P
 if st=='wait'then
  if not(self.actor and self.song.state=='ready')then return end
  local sh=P.shot
  if P.phase=='show'and sh and sh.name==PU.shot and(P.progress or 0)>=(sh.at or 0)+PU.cue then self:cue(t)end
  return
 end
 self.gameT=(self.gameT or 0)+min(E.SONG_STEP,max(0,tonumber(dt)or 0))
 self.song:update(dt,t,eg.game)
 self.sleep:update(self:clock(t),t)
 self:riders(t)
 -- the dust
 for _,d in ipairs(self.dust)do if d.on and t-d.t0>.45 then d.on=false end end
 if st=='gone'then
  if self.woke and self.sleep:allUp()then self.state='done';self.sleep:clear();log('everyone is up')end
  return
 end
 local pt=self.pt
 local c=t-self.t0
 -- its beats
 local ph=self.ph
 if ph=='toss'and c>=pt.toss then ph='land'end
 if ph=='land'and c>=pt.toss+pt.land then ph='mic'end
 if ph=='mic'and c>=pt.toss+pt.land+pt.mic then ph='sing';self:startSong(t)end
 if ph=='startle'and t-self.endT>=E.INTERRUPT.startle then ph='notice';self.noticeT=t end
 if ph=='sing'and self.song:ended()then
  ph='notice';self.endT=t
  log('the song is over (%s, at %.2f s on its own clock): Jigglypuff opens its eyes',tostring(self.song.why),self.song.len or 0)
 end
 if ph=='notice'then
  local due=self.interruptT and self.interruptT+E.INTERRUPT.watch or self.endT+pt.notice
  if t>=due then ph='puff';self.puffT=t end
 end
 if ph=='puff'and t-self.puffT>=pt.puff then ph='huff';self.huffT=t end
 if ph=='huff'and t-self.huffT>=pt.huff then
  ph='gone';self.state='gone';self.goneT=t
  log('Jigglypuff stomped off')
 end
 -- (safety: a song that never ends, in game time)
 if ph=='sing'and self.gameT>(self.song.len or E.SONG_LEN)+self.song.o.grace+E.HOLD_PAD then
  self.song:release();ph='notice';self.endT=t
 end
 self.ph=ph
 stepActor(self.actor,t,eg.game)
 -- facing the camera (turning toward it; a cut turns it at once)
 local cam=P.cam
 local want=self.yaw or 0
 if cam and cam.eye then want=atan2(cam.eye[1]-(self.x or self.gx),cam.eye[3]-(self.z or self.gz))end
 if not self.yaw or P.shot~=self.shotSeen then self.yaw=want;self.shotSeen=P.shot
 else
  local d=(want-self.yaw+pi)%(2*pi)-pi
  self.yaw=self.yaw+d*min(1,(dt or 1/60)*4)
 end
 self.look,self.roll,self.pitch=0,0,0
 self.scale,self.sq,self.red,self.anger,self.vanish=1,1,0,0,0
 local md=self.actor and self.actor.md
 -- TOSS: up from the fan onto the post
 if ph=='toss'then
  local u=c/pt.toss
  if self:once('toss')then eg:play('boing',.6,1.25)end
  self.x=lerp(self.fromX,self.gx,u);self.z=lerp(self.fromZ,self.gz,u)
  self.y=lerp(self.fromY,self.top,u)+11*4*u*(1-u)
  self.pitch=u*2*pi
  self.scale=.8+.2*u
  self.mic=0
 elseif ph~='huff'and ph~='gone'then
  self.x,self.y,self.z=self.gx,self.top,self.gz
 end
 -- LAND: a squash, its cry
 if ph=='land'then
  if self:once('land')then
   eg:cry(PU.species);eg:play('boing',.35,1.5)
   if md then pcall(HF().playTeamModel,md,'entrance',true)end
  end
  local u=(c-pt.toss)/pt.land
  self.sq=1-.22*sin(clamp01(u)*pi)*(1-u*.5)
  self.mic=0
 end
 -- MIC: out it comes
 if ph=='mic'then
  local u=(c-pt.toss-pt.land)/pt.mic
  self.mic=backOut(u)
  self.y=self.top+1.6*sin(clamp01(u)*pi)
 elseif ph~='toss'and ph~='land'then self.mic=1 end
 -- SING (on the song's clock; the notes and the bob follow its loudness)
 if ph=='sing'then
  local pos=self.song.pos
  local lv=self.song:level()
  self.look=.22*sin(pos*2.4)
  self.roll=.08*sin(pos*2.4+.6)
  self.y=self.top+(.12+.3*lv)*abs(sin(pos*4.8))
  if t>=self.nextNote then
   if lv>.22 then self:emitNote(t)end
   self.nextNote=t+.58-.3*lv
  end
 end
 -- (TEST244) STARTLE: the bang -- it jumps, the microphone up, a shiver
 if ph=='startle'then
  local u=clamp01((t-self.endT)/E.INTERRUPT.startle)
  self.y=self.top+4.2*sin(u*pi)
  self.sq=1+.18*sin(u*pi)
  self.pitch=-.35*sin(u*pi)
  self.roll=.10*sin(t*38)*(1-u)
  if u>.7 and self:once('startleLand')then eg:play('boing',.4,1.1);self:puffDust(self.x,self.top,self.z,t,2)end
 end
 -- NOTICE: its eyes open; it looks round (TEST244: after the bang, at a
 -- crowd waking up, until the camera comes back to it)
 if ph=='notice'then
  if self:once('notice')and md then pcall(HF().playTeamModel,md,'idle',false)end
  local t0=self.noticeT or self.endT
  local dur=self.interruptT and max(.2,E.INTERRUPT.watch-E.INTERRUPT.startle)or pt.notice
  local u=(t-t0)/dur
  self.look=.6*sin(clamp01(u)*2*pi)
  if self.interruptT then self.red=.35*smooth(u)end
 end
 -- PUFF: up it swells, red with anger; two stomps
 if ph=='puff'or ph=='huff'then
  local a=t-self.puffT
  if self:once('puff')then
   eg:play('puff',.85,1)
   if md then pcall(HF().playTeamModel,md,'hit',true)end
  end
  if a>=.18 and self:once('angry')then eg:cry(PU.species,1.12)end
  local u=a/pt.puff
  self.red=smooth(u*2.5)
  self.anger=backOut((a-.15)/.3)
  self.scale=1+.55*backOut(u*2.6)+.035*sin(t*9)
  if ph=='puff'then
   for k=1,#STOMPS do
    local v=(a-STOMPS[k]*pt.puff/1.1)/.16
    if v>=0 and v<1 then self.y=self.top+1.4*sin(v*pi)end
    if v>=1 and self:once(STOMP_KEYS[k])then eg:play('boing',.45,.7);self:puffDust(self.x,self.top,self.z,t,2)end
   end
  end
 end
 -- HUFF: off along the rope, post to post, then away
 if ph=='huff'then
  local hopT=.42*pt.huff/1.6
  local u=t-self.huffT
  local k=floor(u/hopT)
  self.scale=1.42+.04*sin(t*9)
  self.red=1;self.anger=1
  if k<PU.huffPosts then
   local v=(u-k*hopT)/hopT
   local ax,ay,az=self:postAt(k)
   local bx,by,bz=self:postAt(k+1)
   if k==0 then ax,ay,az=self.gx,self.top,self.gz end
   self.x=lerp(ax,bx,v);self.z=lerp(az,bz,v)
   self.y=lerp(ay,by,v)+6.5*4*v*(1-v)
   self.huffYaw=atan2(bx-ax,bz-az)
   if v>.92 and self:once(HOP_KEYS[k+1])then eg:play('boing',.42,.78+.06*k);self:puffDust(bx,by,bz,t,2)end
  else
   local v=clamp01((u-PU.huffPosts*hopT)/(pt.huff-PU.huffPosts*hopT))
   local ax,ay,az=self:postAt(PU.huffPosts)
   self.x=lerp(ax,ax+30,v);self.z=lerp(az,az-26,v)
   self.y=ay+14*sin(v*pi*.75)+8*v
   self.vanish=smooth((v-.35)/.65)
   self.huffYaw=atan2(30,-26)
   if v>.85 and self:once('poof')then self:puffDust(self.x,self.y,self.z,t,3)end
  end
 end
end
function Puff:emitNote(t)
 for i,n in ipairs(self.notes)do
  if not n.on then
   local h=hash(i,t)
   n.on=true;n.t0=t
   n.x,n.y,n.z=self:micPoint()
   local a=(self.yaw or 0)+(h-.5)*2.6
   n.dx,n.dz=sin(a),cos(a)
   n.icon=(h>.5)and'note2'or'note1'
   n.col=floor(hash(t,i)*4)%4+1
   return
  end
 end
end
-- where its microphone is: in front of its mouth, to one side, just clear
-- of its round body
function Puff:micPoint()
 local s=self.scale or 1
 local h=PU.h*s
 local yw=(self.yaw or 0)+(self.look or 0)
 local fx,fz=sin(yw),cos(yw)
 local rx,rz=fz,-fx
 return(self.x or self.gx)+fx*3.7*s-rx*2.3*s,(self.y or self.top)+h*.46,(self.z or self.gz)+fz*3.7*s-rz*2.3*s
end
-- a point by its head toward the camera, clear of its body (the anger
-- mark): up `up` and to the side `side` (in heights), then out toward the eye
function Puff:headPoint(up,side,out)
 local s=self.scale or 1
 local h=PU.h*s
 local cx,cy,cz=self.x or self.gx,(self.y or self.top)+h*.5,self.z or self.gz
 local R_=V.require('Voxel3D')
 local ex,ey,ez=0,0,1
 if R_.eye then
  ex,ey,ez=R_.eye[1]-cx,R_.eye[2]-cy,R_.eye[3]-cz
  local l=sqrt(ex*ex+ey*ey+ez*ez);if l>1e-6 then ex,ey,ez=ex/l,ey/l,ez/l end
 end
 -- (side: the camera's right)
 local sx,sz=-ez,ex
 local l=sqrt(sx*sx+sz*sz);if l>1e-6 then sx,sz=sx/l,sz/l end
 return cx+sx*side*h+ex*out*h,cy+up*h+ey*out*h,cz+sz*side*h+ez*out*h
end
function Puff:puffDust(x,y,z,t,n)
 for k=1,n do
  for _,d in ipairs(self.dust)do
   if not d.on then
    d.on=true;d.t0=t;d.x=x+(hash(k,t)-.5)*3;d.y=y+.4;d.z=z+(hash(t,k)-.5)*3;d.s=1.4+hash(k+2,t)
    break
   end
  end
 end
end
function Puff:release()
 self.song:release()
 self.sleep:clear()
 self:ridersUp()
 if self.actor then releaseActor(self.actor);self.actor=nil end
 if self.state~='off'then self.state='done'end
end
function Puff:quietNow()
 self.song:release()
 self.sleep:clear()
 self:ridersUp()
 if self.state=='act'or self.state=='gone'or self.state=='wait'then self.state='done'end
end

------------------------------------------------------------------ drawing
local LIGHT={direction={-.30,.80,.52},ambient={.50,.47,.44},diffuse={.56,.51,.43}}
local TINT={1,.97,.92,1}
local TINTX={1,1,1,1}
local RED={1,.58,.56,1}
local FLASH_RED={1,.20,.14}
local OPTS={camera={},flipWinding=true,disableCulling=true,depthWrite=true}
local VIEW=mat()
local MM=mat()
local CARD=mat()
local viewKey=nil
local NOTE_COLS={{1,.55,.80},{.55,.78,1},{1,.88,.35},{.80,.65,1}}
-- a Stadium model, its pivot (model space ox,oy,oz) at the world point
local function drawModel(md,px,py,pz,yaw,pitch,roll,pre,sx,sy,sz,oy,tint,flash,flashCol)
 local R=V.require('Voxel3D')
 if R.reflectionPlane or not(R.vp and R.eye and R.focus)then return true end
 if viewKey~=R.vp then viewKey=R.vp;lookAtInto(VIEW,R.eye,R.focus)end
 local k=tonumber(md.scale)or 1
 fillTRS(MM,px,py,pz,yaw,pitch,roll,pre,k*sx,k*sy,k*sz,md.cx or 0,oy,md.cz or 0)
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
-- a picture (when there is no model): a card turned to the camera
local function drawArt(art,x,y,z,s,roll,col)
 local R=V.require('Voxel3D')
 local BB=V.require('BattleBillboard')
 local img=art.frames[art.frame or 1]or art.frames[1]
 if not img then return end
 local k=s/21
 local w,h=(art.w or 20)*k,(art.h or 20)*k
 local yaw=BB.yawToward(x,z,R.eye)
 R.lighting(false)
 if R.seams then R.seams(false)end
 love.graphics.setColor(col[1],col[2],col[3],1)
 fillCard(CARD,x,y+h*.5-(art.foot or 0)*k,z,w,h,yaw,roll or 0)
 pcall(R.draw,BB.mesh(),img,CARD,BB.PULL)
 love.graphics.setColor(1,1,1,1)
 if R.seams then R.seams(true)end
 R.lighting(true)
end
function Eggs:draw(K_,t)
 if not self.active then return end
 local P=self.P
 local ph=P and P.phase
 if not P or P.finished or(ph~='show'and ph~='finale'and ph~='reveal'and ph~='end'and ph~='outro')then return end
 self.K=K_
 self.t=t
 self.drawn=0
 for i=1,#self.gags do
  local g=self.gags[i]
  if g.drawModel then
   local ok,err=pcall(g.drawModel,g,self,K_,t)
   if not ok then log('drawing a gag failed: %s',tostring(err));pcall(g.release,g);g.state='off'end
  end
 end
 -- the effects: shadows, the spray, notes, Zz, the microphone, the anger mark
 local R=V.require('Voxel3D')
 if K_ and R.withEffect and not self.fxOff then
  local ok,err=pcall(R.withEffect,'alpha',self.fxFn)
  if not ok then log('the effects failed: %s',tostring(err));self.fxOff=true end
 end
 love.graphics.setColor(1,1,1,1)
end
-- one icon card, turned to the camera
function Eggs:icon(name,x,y,z,size,roll,r,g,b,a,pull)
 local tex=self.tex and self.tex[name]
 if not tex or a<=.01 then return end
 local R=V.require('Voxel3D')
 local BB=V.require('BattleBillboard')
 local eye=R.eye
 local yaw=eye and atan2(eye[1]-x,eye[3]-z)or 0
 fillCard(CARD,x,y,z,size,size,yaw,roll or 0)
 love.graphics.setColor(r,g,b,a)
 R.draw(BB.mesh(),tex,CARD,pull or 0)
 self.drawn=self.drawn+1
end
function Eggs:blob(x,y,z,r,a)
 local K_=self.K
 if not(K_ and K_.quad and K_.soft)or a<=.01 then return end
 local R=V.require('Voxel3D')
 fillFlat(CARD,x,y,z,r,r)
 love.graphics.setColor(0,0,0,a)
 R.draw(K_.quad,K_.soft,CARD)
 self.drawn=self.drawn+1
end
function Eggs:drawFx()
 local R=V.require('Voxel3D')
 local t=self.t or now()
 if R.seams then R.seams(false)end
 for i=1,#self.gags do
  local g=self.gags[i]
  if g.drawFx then g:drawFx(self,t)end
 end
 self.zz:draw(self,t,(self.P and self.P.lite==2)and 6 or nil)
 if R.seams then R.seams(true)end
 love.graphics.setColor(1,1,1,1)
end
-- MAGIKARP: the fish
function Karp:drawModel(eg,K_,t)
 local st=self.state
 if not(st=='fly'or st=='flop'or st=='exit')then return end
 local act=self.actor
 local vis=1-(self.vanish or 0)
 if not(act and vis>.01 and self.x)then return end
 if act.md then
  local _,_,_,pre=self:dims()
  local md=act.md
  if not drawModel(md,self.x,self.y,self.z,self.yaw or 0,self.pitch or 0,self.roll or 0,pre,vis,vis,vis,md.midY or md.ground or 0)then
   releaseActor(act);self.actor=nil;self.state='done'
  else eg.drawn=eg.drawn+1 end
 elseif act.art then
  drawArt(act.art,self.x,self.y-self:restH(0),self.z,7*vis,self.roll or 0,TINT)
  eg.drawn=eg.drawn+1
 end
end
-- MAGIKARP: its shadow, the spray, the splash ring
function Karp:drawFx(eg,t)
 local R=V.require('Voxel3D')
 local K_=eg.K
 local st=self.state
 if(st=='fly'or st=='flop'or st=='exit')and self.x then
  local gy
  if self.ride and eg.P.float and eg.P.float.x and st~='exit'then
   local _,y=self:target(self.spot);gy=y
  else gy=groundAt(self.map,self.x,self.z)end
  if gy then
   local hgt=max(0,self.y-gy)
   eg:blob(self.x,gy+.06,self.z,3.2/(1+hgt*.04),.34*(1-(self.vanish or 0))/(1+hgt*.05))
  end
 end
 if self.drops then
  for _,d in ipairs(self.drops)do
   if d.on then
    local a_=t-d.t0
    local x,y,z=d.x+d.vx*a_,d.y+d.vy*a_-32*a_*a_,d.z+d.vz*a_
    eg:icon('drop',x,y,z,d.s*(1-a_*.6),0,1,1,1,.95*(1-smooth((a_-.3)/.25)),.3)
   end
  end
 end
 if self.ring and K_ and K_.quad and K_.ring then
  local a_=t-self.ring.t0
  if a_<.45 then
   local r=(self.ring.big and 2 or 1.4)+a_*(self.ring.big and 13 or 9)
   fillFlat(CARD,self.ring.x,self.ring.y,self.ring.z,r,r)
   love.graphics.setColor(.80,.92,1,.55*(1-a_/.45))
   R.draw(K_.quad,K_.ring,CARD)
   eg.drawn=eg.drawn+1
  end
 end
end
-- JIGGLYPUFF: on its post (red as it puffs up)
function Puff:drawModel(eg,K_,t)
 if self.state~='act'or not self.x or(self.vanish or 0)>=.99 then return end
 local act=self.actor
 local s=(self.scale or 1)*(1-(self.vanish or 0))
 local red=self.red or 0
 for i=1,4 do TINTX[i]=lerp(TINT[i],RED[i],red)end
 if act and act.md then
  local md=act.md
  local yaw=((self.ph=='huff')and self.huffYaw or self.yaw or 0)+(self.look or 0)
  local mid=md.midY or md.ground or 0
  local pivot=self.pitch~=0 and mid or(md.ground or 0)
  local lift=self.pitch~=0 and(PU.h*.5*s)or 0
  if not drawModel(md,self.x,self.y+lift,self.z,yaw,self.pitch or 0,self.roll or 0,0,s,s*(self.sq or 1),s,pivot,TINTX,.24*red,FLASH_RED)then
   releaseActor(act);self.actor=nil
   log('Jigglypuff would not draw: it leaves')
   self.vanish=1
  else eg.drawn=eg.drawn+1 end
 elseif act and act.art then
  drawArt(act.art,self.x,self.y,self.z,PU.h*1.2*s,self.roll or 0,TINTX)
  eg.drawn=eg.drawn+1
 end
end
-- JIGGLYPUFF: its shadow, the notes, the microphone, the anger mark, dust
function Puff:drawFx(eg,t)
 if self.state~='act'or not self.x then return end
 local R=V.require('Voxel3D')
 local K_=eg.K
 local c=t-self.t0
 local s=(self.scale or 1)*(1-(self.vanish or 0))
 local ph=self.ph
 -- its shadow on the ground while it is in the air
 if ph=='toss'or ph=='huff'then
  local gy=groundAt(self.map,self.x,self.z)
  local hgt=max(0,self.y-gy)
  eg:blob(self.x,gy+.06,self.z,3.4*s/(1+hgt*.03),.30*(1-(self.vanish or 0))/(1+hgt*.04))
 end
 -- the notes
 for _,n in ipairs(self.notes or EMPTY)do
  if n.on then
   local a_=t-n.t0
   if a_>1.8 then n.on=false
   else
    local u=a_/1.8
    local col=NOTE_COLS[n.col]or NOTE_COLS[1]
    local x=n.x+n.dx*u*10+sin(a_*5+n.t0)*.8
    local z=n.z+n.dz*u*10+cos(a_*4+n.t0)*.8
    eg:icon(n.icon,x,n.y+u*9,z,2.2+u*.9,.35*sin(a_*4+n.t0),col[1],col[2],col[3],smooth(a_/.15)*(1-smooth((u-.7)/.3)))
   end
  end
 end
 -- the microphone, in its hand
 if(self.mic or 0)>.02 and(self.vanish or 0)<.5 then
  local x,y,z=self:micPoint()
  eg:icon('mic',x,y,z,2.6*s*(self.mic or 0),-.35+.12*sin(c*3),1,1,1,1,.8)
 end
 -- the anger mark at its brow
 if(self.anger or 0)>.02 and(self.vanish or 0)<.6 then
  local x,y,z=self:headPoint(.36,.30,.42)
  local p=1+.12*sin(c*11)
  eg:icon('anger',x,y,z,2.9*(self.anger or 0)*p*(.6+.4*s),0,1,1,1,1,1.2)
 end
 -- the dust of its stomps
 for _,d in ipairs(self.dust or EMPTY)do
  if d.on and K_ and K_.soft then
   local a_=t-d.t0
   local r=d.s*(1+a_*3)
   fillCard(CARD,d.x,d.y+a_*2,d.z,r*2,r*2,R.eye and atan2(R.eye[1]-d.x,R.eye[3]-d.z)or 0,0)
   love.graphics.setColor(1,.97,.92,.45*(1-a_/.45))
   R.draw(V.require('BattleBillboard').mesh(),K_.soft,CARD)
   eg.drawn=eg.drawn+1
  end
 end
end

------------------------------------------------------------------ what plays where
E.STOP_GAGS[E.STOP]={function(eggs)return Karp.new(eggs)end,function(eggs)return Puff.new(eggs)end}
-- (TEST235 ending) Pallet: Jigglypuff's encore (ParadeEnding; if it will not
-- load, Pallet is as it was)
pcall(function()
 local PE=V.require('ParadeEnding')
 if type(PE)=='table'and type(PE.make)=='function'and PE.STOP then E.STOP_GAGS[PE.STOP]={PE.make}end
end)

------------------------------------------------------------------ the module
function E.dispose()
 viewKey=nil
 MusicMod=nil
end
return E
