-- TEST171: THE FIREWORKS, HEARD. Every shell LeagueRoad fires over Route 23
-- and the Indigo Plateau now sounds:
--
--  * LAUNCH   the mortar's thump and the rocket hissing up (some whistle);
--  * BOOM     the burst, arriving a beat after the flash (sound is slower
--             than light: the further the shell, the longer the wait, the
--             quieter and duller the boom);
--  * CRACKLE  the glittering crackle as a peony or chrysanthemum burns out;
--  * SIZZLE   a willow's long fizzing fall.
--
-- Nothing ships: every sound is synthesised here, once, the first time a
-- shell goes up (one sound per frame, so there is no hitch), into small
-- 22 kHz mono buffers. Shells are cloned voices off those buffers, at most
-- ten at a time. The game's SFX volume scales everything; SFX at 0 is
-- silence. Presentation only.
--
-- LeagueRoad calls M.shell(...) for every shell it draws (the main map only,
-- never a neighbour's); the core.update hook plays what falls due.
local V=...
-- TEST208: THE FIREWORKS, RECORDED-QUALITY. The synthesised set above read
-- as TV static on a phone: the launch hiss, the crackle and the willow's
-- fizz put nearly all their energy between 3 and 11 kHz, while the booms
-- sat under 100 Hz, where a handheld speaker plays almost nothing -- so what
-- you heard of a show was hiss. The fireworks now play from ten OGG files
-- (assets/legendary/fw-*.ogg), made offline at 44.1 kHz:
--   * booms (three near, two far) with a crack, a thump driven into
--     harmonics and a body in the 150-1200 Hz range a speaker can carry,
--     then the valley's echoes and a rolling tail;
--   * launches: the mortar's thoomp and a dark whoosh falling away (no
--     hiss, no whistle -- the whistle is gone);
--   * crackle: discrete snaps rung through resonances, in clusters;
--   * the willow: a soft dark fizz under 2.5 kHz with sparse snaps.
-- The synthesised versions stay as the fallback if a file can't be read.
-- The bells, fanfare and cheer are unchanged (still made here).
local M={REVISION='league-fireworks-audio-225'}
local SR=22050
local floor,min,max,sin,exp,pi,abs,sqrt=math.floor,math.min,math.max,math.sin,math.exp,math.pi,math.abs,math.sqrt

------------------------------------------------------------------ synthesis
-- Pure functions returning sample arrays (1-based, -1..1): headless-testable.
local function rng(seed)
 local s=floor(seed)%2147483646+1
 return function()s=(s*16807)%2147483647;return s/2147483647 end
end
local function coef(fc)return 1-exp(-2*pi*fc/SR)end
-- inside the builder coroutine, hand the frame back every few thousand
-- samples; called from the main thread (tests) it does nothing
local function breathe(i)
 if i%6000==0 and coroutine.running()then coroutine.yield()end
end
local function normalize(buf,peak)
 local m=1e-9
 for i=1,#buf do local a=abs(buf[i]);if a>m then m=a end end
 local k=peak/m
 for i=1,#buf do buf[i]=buf[i]*k end
 return buf
end

-- the mortar's thump, then the rocket hissing (and maybe whistling) up
function M.synthLaunch(seed,whistle)
 local r=rng(seed);local n=floor(SR*1.35);local out={}
 local a1,a2=coef(800),coef(3600);local lp1,lp2=0,0;local ph=0
 for i=1,n do
  breathe(i)
  local t=(i-1)/SR
  -- loud as it leaves the mortar, thinning as it climbs away
  local env=min(1,t/.04)*(.35+.65*exp(-t*1.6))*(t<1.02 and 1 or exp(-(t-1.02)*11))
  local x=r()*2-1
  lp1=lp1+a1*(x-lp1);local hp=x-lp1
  lp2=lp2+a2*(hp-lp2)
  local hiss=lp2*(.45+.55*min(1,t/.35))*(1+.25*sin(t*53+seed))
  local s=hiss*1.15
  if whistle then
   local f=650+1700*min(1,t/1.08)^.75
   ph=ph+2*pi*f/SR
   s=s+sin(ph)*.30*(1+.25*sin(t*37))*min(1,t/.15)
  end
  s=s*env
  -- the mortar: a short low thump at the very start
  s=s+sin(2*pi*80*t)*exp(-t*24)*1.4+(r()*2-1)*exp(-t*60)*.55
  out[i]=s
 end
 return normalize(out,.9)
end

-- the burst: a crack, a deep body dropping in pitch, a rolling rumble with
-- an echo or two off the valley; `far` is duller and longer
function M.synthBoom(seed,far)
 local r=rng(seed);local n=floor(SR*(far and 3.4 or 3.0));local out={}
 local aR=coef(far and 120 or 190);local aB=coef(far and 260 or 900)
 local br,lr,lb=0,0,0;local ph1,ph2=0,0
 for i=1,n do
  breathe(i)
  local t=(i-1)/SR
  local x=r()*2-1
  -- crack (near only): a hard broadband transient
  local crack=far and 0 or x*exp(-t*70)*1.7
  -- body: a deep thump sliding down
  local f1=(far and 52 or 64)-18*min(1,t/.45)
  ph1=ph1+2*pi*f1/SR;ph2=ph2+2*pi*f1*1.9/SR
  local body=sin(ph1)*exp(-t*(far and 3.6 or 5.0))+sin(ph2)*exp(-t*9)*.30
  -- rumble: brown noise through a low-pass, with valley echoes
  br=br*.996+x*.06
  lr=lr+aR*(br-lr)
  local env=(1-exp(-t*35))*exp(-t*(far and 1.15 or 1.55))
  env=env+.26*exp(-((t-.34)/.06)^2)+.15*exp(-((t-.78)/.09)^2)+.08*exp(-((t-1.30)/.12)^2)
  local s=crack+body*1.5+lr*6.0*env
  lb=lb+aB*(s-lb)                     -- the air takes the top off
  out[i]=far and lb or (lb*.55+s*.45)
 end
 return normalize(out,.95)
end

-- glitter crackle: a burst of tiny snaps, thickening then thinning out
function M.synthCrackle(seed)
 local r=rng(seed);local n=floor(SR*2.3);local out={}
 local env,lp=0,0;local aH=coef(2200);local dec=exp(-1/(.0016*SR))
 for i=1,n do
  breathe(i)
  local t=(i-1)/SR
  local rate=95*sin(pi*min(1,t/2.0))^.6
  if r()<rate/SR then env=max(env,.35+.65*r())end
  env=env*dec
  local x=r()*2-1
  lp=lp+aH*(x-lp)
  local hp=x-lp
  out[i]=hp*env+hp*.035*sin(pi*min(1,t/2.3))
 end
 return normalize(out,.85)
end

-- a willow's long fizz, with the odd snap in it
function M.synthSizzle(seed)
 local r=rng(seed);local n=floor(SR*3.0);local out={}
 local lp,lp2=0,0;local aH,aL=coef(2600),coef(7000);local env2=0;local dec=exp(-1/(.002*SR))
 for i=1,n do
  breathe(i)
  local t=(i-1)/SR
  local x=r()*2-1
  lp=lp+aH*(x-lp);local hp=x-lp
  lp2=lp2+aL*(hp-lp2)
  local env=min(1,t/.25)*exp(-t*.85)*(1+.35*sin(t*29+seed)*sin(t*7.3))
  if r()<14/SR then env2=max(env2,.4+.6*r())end
  env2=env2*dec
  out[i]=lp2*env+hp*env2*.8
 end
 return normalize(out,.8)
end

-- TEST172: a struck bell: inharmonic partials, each with its own decay
local function bell(out,t0,f,amp,dur)
 local P={{1,1,1.05},{2.0,.50,.70},{2.76,.30,.45},{5.40,.14,.24},{8.9,.06,.12}}
 local i0=floor(t0*SR)+1
 local n=floor(dur*SR)
 for i=0,n-1 do
  local t=i/SR
  local v=0
  for _,p in ipairs(P)do v=v+sin(2*pi*f*p[1]*t)*p[2]*exp(-t/p[3])end
  v=v*min(1,t/.004)*amp*min(1,(dur-t)/.35)
  local k=i0+i
  if k>=1 and k<=#out then out[k]=out[k]+v end
  breathe(i+1)
 end
end
-- a rising bell arpeggio for a badge gate: root, third, fifth, octave
function M.synthChime()
 local n=floor(SR*3.0);local out={}
 for i=1,n do out[i]=0 end
 local f=587.33       -- D5
 bell(out,0,f,1,2.6);bell(out,.13,f*1.2599,.85,2.5);bell(out,.26,f*1.4983,.85,2.4);bell(out,.42,f*2,.9,2.4)
 return normalize(out,.8)
end
-- the arrival fanfare: two bell arpeggios rising into a held chord
function M.synthFanfare()
 local n=floor(SR*5.0);local out={}
 for i=1,n do out[i]=0 end
 local f=392.0        -- G4
 local seq={{0,1},{.15,1.2599},{.30,1.4983},{.48,2},{.90,1.3348},{1.05,1.6818},{1.20,2},{1.40,2.6697},
  {1.80,1},{1.80,1.2599},{1.80,1.4983},{1.80,2},{1.80,2.5198}}
 for _,q in ipairs(seq)do bell(out,q[1],f*q[2],q[1]>=1.8 and .7 or 1,3.0)end
 return normalize(out,.85)
end
-- the crowd: a roar of voices swelling and falling under thick applause
function M.synthCheer(seed)
 local r=rng(seed or 91);local n=floor(SR*6.5);local out={}
 local a1,a2,a3,a4=coef(280),coef(1300),coef(950),coef(3300)
 local lo1,lo2,hi1,hi2=0,0,0,0
 local c1,c2,c3,c4=0,0,0,0
 local fin,fin2=0,0;local aF=coef(3600)
 local clap=0;local dec=exp(-1/(.0022*SR))
 -- slow random swells (the "yeahs"), smooth
 local sw,swT,swV=0,0,0
 for i=1,n do
  breathe(i)
  local t=(i-1)/SR
  local env=min(1,t/.8)*(t<4.3 and 1 or exp(-(t-4.3)*1.3))
  if t>=swT then swT=t+.18+r()*.35;swV=.55+.9*r()end
  sw=sw+(swV-sw)*.0009
  local x=r()*2-1
  -- voices: noise through a two-stage band (about 280-1300 Hz)
  lo1=lo1+a1*(x-lo1);lo2=lo2+a1*(lo1-lo2)
  hi1=hi1+a2*(x-hi1);hi2=hi2+a2*(hi1-hi2)
  local roar=(hi2-lo2)*sw*2.4
  -- applause: dense claps, each a burst of band-limited noise
  if r()<(620*env)/SR then clap=max(clap,.45+.55*r())end
  clap=clap*dec
  c1=c1+a3*(x-c1);c2=c2+a3*(c1-c2)
  c3=c3+a4*(x-c3);c4=c4+a4*(c3-c4)
  local claps=(c4-c2)*clap*2.6
  local v=(roar*.75+claps)*env
  fin=fin+aF*(v-fin);fin2=fin2+aF*(fin-fin2)
  out[i]=fin2
 end
 return normalize(out,.85)
end

------------------------------------------------------------------ runtime
-- each entry: a file (TEST208) and/or a synthesiser (the fallback, and the
-- bells, fanfare and cheer, which have no file)
local BUILD={
 {'boom1',file='fw-boom1.ogg',synth=function()return M.synthBoom(37,false)end},
 {'launch1',file='fw-launch1.ogg',synth=function()return M.synthLaunch(11,false)end},
 {'far1',file='fw-far1.ogg',synth=function()return M.synthBoom(53,true)end},
 {'crackle1',file='fw-crackle1.ogg',synth=function()return M.synthCrackle(61)end},
 {'boom2',file='fw-boom2.ogg'},
 {'launch2',file='fw-launch2.ogg'},
 {'sizzle1',file='fw-sizzle1.ogg'},
 {'chime',synth=function()return M.synthChime()end},
 {'boom3',file='fw-boom3.ogg'},
 {'crackle2',file='fw-crackle2.ogg'},
 {'far2',file='fw-far2.ogg'},
 {'fanfare',synth=function()return M.synthFanfare()end},
 {'cheer',synth=function()return M.synthCheer(91)end},
}
-- read one of the mod's own sound files (through the mounted mod first, as
-- CommunityFlora's cave ambience does; then the unpacked folder)
local function loadFile(file)
 local ok,bytes=pcall(function()return V.mod:read("assets/legendary/"..file)end)
 if ok and type(bytes)=="string"and #bytes>0 then
  local ok2,src=pcall(function()
   return love.audio.newSource(love.filesystem.newFileData(bytes,file),'static')
  end)
  if ok2 and src then return src end
 end
 local ok3,src=pcall(love.audio.newSource,(V.path or"mods/BATTLE_ART_VOXEL_FORK").."/assets/legendary/"..file,'static')
 if ok3 and src then return src end
 return nil
end
local sources,built,failed,builder={},0,false,nil
local queue,seen,voices={},{},{}
local FALLBACK={boom2='boom1',boom3='boom1',far1='boom1',far2='far1',launch2='launch1',
 crackle2='crackle1',sizzle1='crackle1'}
local beat,remove=-1e9,nil
local LIVE={ROUTE_23=true,INDIGO_PLATEAU=true,HALL_OF_FAME=true,LORELEIS_ROOM=true,
 BRUNOS_ROOM=true,AGATHAS_ROOM=true,LANCES_ROOM=true,CHAMPIONS_ROOM=true}
local LEAGUE={ROUTE_23=true,INDIGO_PLATEAU=true,ROUTE_22_GATE=true,INDIGO_PLATEAU_LOBBY=true,LORELEIS_ROOM=true,
 BRUNOS_ROOM=true,AGATHAS_ROOM=true,LANCES_ROOM=true,CHAMPIONS_ROOM=true,HALL_OF_FAME=true}

-- one slice of synthesis per frame, in a coroutine, so building the sounds
-- never stalls a frame
local function buildNext()
 if failed or built>=#BUILD then return end
 if not builder then
  local entry=BUILD[built+1]
  -- TEST208: a file loads in one go (a few ms of decoding)
  if entry.file then
   local src=loadFile(entry.file)
   if src then sources[entry[1]]=src;built=built+1;return end
  end
  if not entry.synth then built=built+1;return end
  builder=coroutine.create(function()
   local buf=entry.synth()
   local sd=love.sound.newSoundData(#buf,SR,16,1)
   for i=1,#buf do
    sd:setSample(i-1,buf[i])
    if i%8000==0 then coroutine.yield()end
   end
   sources[entry[1]]=love.audio.newSource(sd,'static')
  end)
 end
 local ok=coroutine.resume(builder)
 if not ok then failed=true;builder=nil;return end
 if coroutine.status(builder)=='dead'then builder=nil;built=built+1 end
end

local function at(when,name,vol,pitch,prio)
 queue[#queue+1]={t=when,name=name,vol=vol,pitch=pitch or 1,prio=prio}
end
-- TEST172: a badge gate's bells (n: the badge's place, 1..8, each a step
-- higher) and the arrival's fanfare with the crowd
function M.chime(n)
 local now=love.timer.getTime()
 at(now+.05,'chime',.55,2^(((n or 1)-1)*2/12),true)
end
function M.fanfare()
 local now=love.timer.getTime()
 at(now+.35,'fanfare',.60,1,true)
 at(now+.80,'cheer',.42,1,true)
end

-- One call per drawn shell per frame. id: unique per shell and cycle;
-- launchT/burstT: absolute love.timer times; kind 0 peony, 1 chrysanthemum,
-- 2 willow, 3 ring; (bx,by,bz) the burst; (lx,ly,lz) the listener.
function M.shell(id,launchT,burstT,kind,bx,by,bz,lx,ly,lz)
 local now=love.timer.getTime()
 beat=now
 if seen[id]then return end
 seen[id]=burstT+12
 local dx,dy,dz=bx-lx,by-ly,bz-lz
 local d=sqrt(dx*dx+dy*dy+dz*dz)
 local near=max(.45,min(1,360/max(d,1)))
 local delay=d/1100
 local h=(id*7919)%97/97
 local h2,h3=(h*3.7)%1,(h*5.3)%1
 -- TEST208: the recorded set (no whistle any more)
 if now<launchT+.15 then at(launchT,h<.5 and'launch1'or'launch2',.36*near,.94+.12*h2)end
 local bn=d>760 and(h3<.5 and'far1'or'far2')or({'boom1','boom2','boom3'})[1+floor(h*3)%3]
 at(burstT+delay,bn,.95*near,.90+.18*h2)
 local cn=h3<.5 and'crackle1'or'crackle2'
 if kind==2 then at(burstT+delay+.30,'sizzle1',.40*near,.96+.08*h)
 elseif kind==3 then at(burstT+delay+.15,cn,.26*near,1.08)
 else at(burstT+delay+(kind==1 and 1.9 or 2.35),cn,.40*near,.92+.16*h2)end
end

local function gain(game)
 local opts=game and game.save and game.save.options
 return max(0,min(7,tonumber(opts and opts.sfxVol)or 7))/7
end

function M.update(game,dt)
 local now=love.timer.getTime()
 local map=game and game.overworld and game.overworld.map
 local id=map and tostring(map.id)
 -- TEST218: and the Elite Four / Champion rooms, for the victory fireworks
 -- TEST222: and on the parade's road (ChampionParade sets extraLive)
 local live=(LIVE[id or'']or M.extraLive)and now-beat<.6
 -- TEST172: the sounds are built anywhere in the League (the road, the
 -- lobby, the rooms), so the Hall of Fame's fanfare is ready when you are
 if LEAGUE[id or'']and not live then buildNext()end
 -- finished voices go back
 for i=#voices,1,-1 do
  local v=voices[i];local ok,on=pcall(v.isPlaying,v)
  if not(ok and on)then pcall(v.release,v);table.remove(voices,i)end
 end
 if not live then
  queue={}
  if next(seen)then for k,exp_ in pairs(seen)do if exp_<now then seen[k]=nil end end end
  return
 end
 buildNext()
 local g=gain(game)
 local keep={}
 for _,e in ipairs(queue)do
  if e.t<=now then
   local src=sources[e.name]or sources[FALLBACK[e.name]or'']
   -- a cue (bells, fanfare) waits a few seconds for its sound to be built
   if not src and e.prio and now-e.t<4 then keep[#keep+1]=e;e.wait=true
   elseif src and g>0 and now-e.t<(e.prio and(e.wait and 4.5 or 1.5)or .4)and(#voices<12 or e.prio)then
    local ok,v=pcall(src.clone,src)
    if ok and v then
     pcall(v.setVolume,v,min(1,e.vol*g))
     pcall(v.setPitch,v,e.pitch)
     pcall(v.play,v)
     voices[#voices+1]=v
    end
   end
  else keep[#keep+1]=e end
 end
 queue=keep
 for k,exp_ in pairs(seen)do if exp_<now then seen[k]=nil end end
end

function M.dispose()
 pcall(function()V.require('MemoryBudget').dispose()end)
 pcall(function()V.require('TextureDiet').dispose()end)
 pcall(function()V.require('LanceApproach').dispose()end)
 pcall(function()V.require('ChampionParade').dispose()end)
 pcall(function()V.require('HallOfFame3D').dispose()end)
 if remove then pcall(remove);remove=nil end
 for _,v in ipairs(voices)do pcall(v.stop,v);pcall(v.release,v)end
 for _,s in pairs(sources)do pcall(s.release,s)end
 sources,built,failed,queue,seen,voices={},0,false,{},{},{}
end

function M.install(mod)
 -- TEST217: the crash fixes ride on this install (main.lua untouched):
 -- the texture diet (TEST216, phones) and the memory budget (TEST213, now
 -- with TEST215's collector assist). The diagnostic panels (MemWatch,
 -- MemCensus, BlackBox) are no longer started.
 pcall(function()V.require('TextureDiet').install(mod)end)
 pcall(function()V.require('MemoryBudget').install(mod)end)
 -- TEST220: the Hall of Fame in 3D (before the parade: the parade wraps it)
 -- (TEST224: the team as their imported 3D models, through the Collection)
 pcall(function()V.require('HallOfFame3D').install(mod)end)
 -- TEST222: the Champion's parade, live in 3D (it replaces TEST219/221's
 -- film player, ParadeCutscene, which is no longer installed)
 -- (TEST225: walk it or ride the float -- Professor Oak asks in the Hall of
 -- Fame; the float, ParadeFloat, is installed by the parade itself)
 pcall(function()V.require('ChampionParade').install(mod)end)
 -- TEST223: the journey to Lance (his room's walk in, filmed; the dragons)
 -- (TEST224: the face-off held through his words, the new fire)
 -- (TEST225: the hand-back over your head while the gate leaves no room)
 pcall(function()V.require('LanceApproach').install(mod)end)
 if remove then return end
 remove=mod.hooks:wrap('core.update',function(nxt,game,dt)
  local ok=pcall(M.update,game,dt)
  if not ok then queue={} end
  return nxt(game,dt)
 end)
end
return M
