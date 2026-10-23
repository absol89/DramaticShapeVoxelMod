-- TEST172: THE LEAGUE'S SOUNDSCAPE. Looping beds that follow where you are
-- on Route 23 and the Indigo Plateau, and in each League room:
--
--  outdoors  WIND     over the gorge, gusting, louder by the balustrades
--            FALLS    the waterfalls' roar, rising as you near one
--            FIRE     the fire bowls crackling as you pass them
--            FOUNTAIN water splashing and babbling in the gardens
--            CROWD    the stadium's crowd, a murmur that grows toward the hall
--  rooms     LOBBY    a hushed hall: murmur and a fountain
--            ICE      Lorelei: a thin, whistling wind and crystal tinkles
--            DOJO     Bruno: a roaring fire and slow war drums
--            CRYPT    Agatha: a low, beating drone and ghostly breaths
--            STORM    Lance: wind and thunder rolling around the hall
--            CHAMPION a crowd roaring beyond the walls
--            LAVA     Lance's stadium: the lake of fire boiling (TEST197)
--            FAME     the Hall of Fame: cheering, applause and bells
--
-- Every bed is synthesised here (no files), a slice per frame, the first
-- time it is wanted, and loops seamlessly. LeagueRoad / LeagueRooms call
-- M.touch(targets) every frame they draw; beds fade toward their targets and
-- out again when nothing touches them, and a bed left silent for a minute is
-- freed. SFX volume and the ambience setting (OFF / LOW) are honoured.
local V=...
local M={REVISION='league-ambience-208'}
local SR=22050
local floor,min,max,sin,exp,pi,abs,sqrt=math.floor,math.min,math.max,math.sin,math.exp,math.pi,math.abs,math.sqrt

local function rng(seed)
 local s=floor(seed)%2147483646+1
 return function()s=(s*16807)%2147483647;return s/2147483647 end
end
local function coef(fc)return 1-exp(-2*pi*fc/SR)end
local function breathe(i)if i%5000==0 and coroutine.running()then coroutine.yield()end end
-- TEST191: the events (bubbles, pops, steps, bells) are written in their own
-- loops; this counts their samples and yields every ~5000, so no frame pays
-- for more than one slice however dense a bed is
local work=0
local function spend(m)work=work+m;if work>=5000 then work=0;if coroutine.running()then coroutine.yield()end end end
-- a smooth random walk between targets (gusts, swells)
local function wander(r,lo,hi,rate)
 local v,tv,tt=lo,lo,0
 return function(t)
  if t>=tt then tt=t+rate*(.5+r());tv=lo+(hi-lo)*r()end
  v=v+(tv-v)*(1/(rate*SR))*3
  return v
 end
end
-- make a buffer loop: the last `x` seconds are crossfaded into the first
local function loopify(buf,x)
 local n=#buf;local k=floor(x*SR)
 local out={}
 local m=n-k
 for i=1,m do breathe(i);out[i]=buf[i]end
 for i=1,k do
  breathe(i);local a=i/k
  out[i]=buf[i]*a+buf[m+i]*(1-a)
 end
 return out
end
local function normalize(buf,peak)
 local m=1e-9
 for i=1,#buf do local a=abs(buf[i]);if a>m then m=a end end
 local k=peak/m
 for i=1,#buf do buf[i]=buf[i]*k end
 return buf
end
local function bellAdd(out,i0,f,amp,len)
 local n=floor(len*SR);spend(n)
 for i=0,n-1 do
  breathe(i+1);local k=i0+i
  if k>#out then break end
  local t=i/SR
  out[k]=out[k]+(sin(2*pi*f*t)+.45*sin(2*pi*f*2.76*t)*exp(-t*3))*exp(-t*2.2)*amp*min(1,t/.003)
 end
end

------------------------------------------------------------------ the beds
-- TEST191: REBUILT. The first beds were white noise through gentle filters:
-- murmur, footsteps, the fountain, the tanks and the crackle all carried
-- most of their energy between 1 and 6 kHz, which a handheld's speaker
-- plays as TV static. Now:
--  * steady noise only where the real sound IS noise (wind, a waterfall,
--    a distant crowd), and always dark: it lives under ~1.5 kHz;
--  * the character comes from EVENTS with a pitch: bubbles and droplets
--    that rise, footsteps that thud, a clock that ticks, crackle that pops
--    through a resonance, birds, bells;
--  * every bed is levelled by its loudness (RMS), not its loudest peak, so
--    a busy bed is no louder than a quiet one at the same setting;
--  * the loops are longer (14-18 s), so no single event repeats quickly.
local S={}
local cos=math.cos
-- a two-pole low-pass (a smooth, dark filter); `set` changes its corner
local function lp2(fc)
 local a=coef(fc);local y1,y2=0,0
 return function(x,f)
  if f then a=coef(f)end
  y1=y1+a*(x-y1);y2=y2+a*(y1-y2);return y2
 end
end
-- a one-pole high-pass (takes the rumble and DC out)
local function hp1(fc)
 local a=coef(fc);local l=0
 return function(x)l=l+a*(x-l);return x-l end
end
-- a narrow resonance: noise or a click through it comes out as a pitched
-- tone (a whistle, a wooden tick, the snap in a crackle) rather than hiss
local function reson(f,bw)
 local R=exp(-pi*bw/SR);local c=2*R*cos(2*pi*f/SR);local y1,y2=0,0
 return function(x,nf)
  if nf then c=2*R*cos(2*pi*nf/SR)end
  local y=c*y1-R*R*y2+(1-R)*x;y2=y1;y1=y;return y
 end
end
-- brown noise: white noise integrated, so its energy is low -- but not
-- below what a handheld's speaker can play (cut twice at 150 Hz)
local function brown(r)
 local b=0;local h1,h2=hp1(150),hp1(150)
 return function()b=b*.985+(r()*2-1)*.08;return h2(h1(b))*2.5 end
end
local function zeros(n)local out={};for i=1,n do breathe(i);out[i]=0 end;return out end
local function mix(out,src,k)for i=1,#out do breathe(i);out[i]=out[i]+src[i]*k end;return out end
local function scale(out,k)for i=1,#out do breathe(i);out[i]=out[i]*k end;return out end

-- ROOM TONE: the air of a closed room, felt more than heard
local function roomTone(r,n,level)
 local out={};local b=brown(r);local lp=lp2(420);local sw=wander(r,.75,1.05,2.5)
 for i=1,n do breathe(i);out[i]=lp(b())*level*sw(i/SR)*3 end
 return out
end
-- one bubble/droplet: a short sine that rises in pitch as it closes
local function bubble(out,i0,f0,amp,len,rise)
 local m=floor(len*SR);local ph=0;spend(m)
 for j=0,m-1 do
  local k=i0+j;if k>#out then break end
  local t=j/SR;local f=f0*(1+(rise or 2.2)*t/len)
  ph=ph+2*pi*f/SR
  local env=min(1,t/.004)*exp(-t*(4.5/len))
  out[k]=out[k]+sin(ph)*env*amp
 end
end
-- water babbling: many bubbles of many sizes over a dark wash
local function babble(r,n,dens,fLo,fHi,bed)
 local out={};local b=brown(r);local lp=lp2(520);local sw=wander(r,.7,1.1,.5)
 for i=1,n do breathe(i);out[i]=lp(b())*(bed or .5)*sw(i/SR)*4 end
 local k=floor(SR*.01)
 while k<n do
  local f0=fLo*(fHi/fLo)^r()
  bubble(out,k,f0,.05+.11*r()^2,.018+.05*r(),1.4+2.4*r())
  k=k+1+floor(SR*(-math.log(1-r()*.999)/dens))
 end
 return out
end
-- one footstep: a soft heel thud and the faint tap of a sole
local function footstep(out,i0,amp,r)
 local m=floor(.16*SR);local ph=0;local tick=reson(900+500*r(),260);spend(m)
 for j=0,m-1 do
  local k=i0+j;if k>#out then break end
  local t=j/SR;local f=150-40*min(1,t/.05)
  ph=ph+2*pi*f/SR
  local x=(j<floor(.0015*SR))and(r()*2-1)or 0
  out[k]=out[k]+sin(ph)*exp(-t*38)*amp+tick(x)*amp*1.6
 end
end
-- wind: dark rushing air that swells with the gusts, and a soft tonal
-- whistle round the stone (a resonance, not a hiss).
-- TEST208: only where a whistle is asked for (Lorelei's ice, Lance's storm).
-- Over the gorge the narrow 560 Hz resonance sang on every gust and read as
-- a whine under the fireworks, so the outdoor wind is air alone.
function S.wind(r,n,whistleHz)
 local out={};local g=wander(r,.2,1,1.1);local w=wander(r,0,1,1.9)
 local lp=lp2(260);local hp=hp1(130);local whis=reson(whistleHz or 560,7)
 for i=1,n do
  breathe(i);local t=i/SR;local gust=g(t);local x=r()*2-1
  local air=hp(lp(x,200+380*gust))*(.35+.9*gust)*2.4
  local wh=whistleHz and whis(x,whistleHz*(.85+.3*w(t)))*gust*gust*.55 or 0
  out[i]=air+wh
 end
 return out
end
-- a waterfall: a deep roar, a lighter rush above it, splashes in it
function S.falls(r,n)
 local out={};local b=brown(r);local lo=lp2(420);local mid1,mid2=lp2(1300),lp2(420);local m=wander(r,.85,1.1,.6)
 for i=1,n do
  breathe(i);local t=i/SR;local x=r()*2-1
  out[i]=(lo(b())*5.5+(mid1(x)-mid2(x))*.55)*m(t)
 end
 local sp=babble(r,n,26,500,1400,0)
 return mix(out,sp,.6)
end
-- fire: a low breathing roar, and crackle: small pops and the odd snap,
-- each one rung through a short resonance so it pops instead of hissing
function S.fire(r,n)
 local out={};local b=brown(r);local lp=lp2(300);local roar=wander(r,.55,1.1,.35)
 for i=1,n do breathe(i);out[i]=lp(b())*roar(i/SR)*5 end
 local k=floor(SR*.02)
 while k<n do
  local big=r()<.12
  local rs=reson(1500+2600*r(),big and 250 or 520)
  local amp=(big and .55 or .18)*(.4+.6*r())
  local m=floor(SR*(big and .03 or .012));spend(m)
  for j=0,m-1 do
   local idx=k+j;if idx>n then break end
   local x=(j<floor(SR*.0012))and(r()*2-1)or 0
   out[idx]=out[idx]+rs(x)*amp*6
  end
  k=k+1+floor(SR*(-math.log(1-r()*.999)/14))
 end
 return out
end
-- a fountain: water babbling into a basin
function S.fountain(r,n)return babble(r,n,75,330,1250,.55)end
-- a crowd far off: a soft, dark swell (no attempt at voices)
local function crowdBed(r,n,level,swell)
 local out={};local lo1,lo2=lp2(620),lp2(170);local sw=wander(r,.55,1.15,swell or .5);local hp=hp1(60)
 for i=1,n do
  breathe(i);local t=i/SR;local x=r()*2-1
  out[i]=hp(lo1(x)-lo2(x))*sw(t)*level*2.2
 end
 return out
end
function S.crowd(r,n)return crowdBed(r,n,1,.45)end
function S.lobby(r,n)
 local out=roomTone(r,n,1)
 mix(out,crowdBed(r,n,.35,.6),1)
 return mix(out,S.fountain(r,n),.45)
end
-- Lorelei: a thin cold whistle and crystal tinkles
function S.ice(r,n)
 local out=S.wind(r,n,1150)
 scale(out,.7)
 local k=floor(SR*.4)
 while k<n do
  bellAdd(out,k,2000+1600*r(),.05+.07*r(),.9)
  k=k+floor(SR*(.5+1.3*r()))
 end
 return out
end
-- Bruno: the fire, and slow war drums
function S.dojo(r,n)
 local out=scale(S.fire(r,n),.7)
 local beat=floor(SR*1.6);local pat={0,0.8,1.05}
 local k=0
 while k<n do
  for _,o in ipairs(pat)do
   local i0=k+floor(o*SR)+1;local ph=0;spend(floor(SR*.7))
   for j=0,floor(SR*.7)-1 do
    local idx=i0+j;if idx>n then break end
    local t=j/SR;local f=120-45*min(1,t/.25)
    ph=ph+2*pi*f/SR
    out[idx]=out[idx]+(sin(ph)+.35*sin(2*ph))*exp(-t*7)*1.1
   end
  end
  k=k+beat*2
 end
 return out
end
-- Agatha: a low beating drone and slow, dark breaths
function S.crypt(r,n)
 local out={};local br=wander(r,0,1,1.8);local lp=lp2(560);local hp=hp1(170)
 for i=1,n do
  breathe(i);local t=i/SR
  local d=.5*(sin(2*pi*55*t)+sin(2*pi*57.3*t))+sin(2*pi*110*t)+sin(2*pi*114.6*t)+.5*sin(2*pi*164.8*t+sin(t*.7)*2)+.3*sin(2*pi*221.2*t)+.12*sin(2*pi*329.6*t+sin(t*.4)*3)
  out[i]=d*.22+hp(lp(r()*2-1))*br(t)^2*4.5
 end
 return out
end
-- Lance: wind, and thunder rolling round the hall
function S.storm(r,n)
 local out=scale(S.wind(r,n,480),.8)
 local k=floor(SR*1.2)
 while k<n do
  local len=floor(SR*(3+2*r()));spend(len);local lo=lp2(170);local lh=hp1(60);local cr=lp2(1200);local amp=.8+.6*r()
  for j=0,len-1 do
   breathe(j+1);local idx=k+j;if idx>n then break end
   local t=j/SR;local x=r()*2-1
   local env=min(1,t/.08)*exp(-t*.9)*(1+.5*sin(t*9))
   out[idx]=out[idx]+lh(lo(x))*14*env*amp+cr(x)*exp(-t*18)*.6*amp
  end
  k=k+floor(SR*(4.5+4*r()))
 end
 return out
end
function S.champion(r,n)return crowdBed(r,n,1.25,.3)end
-- TEST197, LAVA: Lance's lake boiling: a deep heave under it, and bubbles
-- of molten rock coming up through it all the time -- big slow "blups"
-- low in the voice (where a handheld still plays them), small quick ones
-- over them -- and the faint tick of the crust as it cools
function S.lava(r,n)
 local out={};local b=brown(r);local lp=lp2(240);local heave=wander(r,.5,1.1,.9)
 for i=1,n do breathe(i);out[i]=lp(b())*heave(i/SR)*4.5 end
 local k=floor(SR*.05)
 while k<n do
  local big=r()<.30
  local f0=big and 150+90*r()or 260+260*r()
  bubble(out,k,f0,big and .30+.20*r()or .10+.10*r(),big and .10+.08*r()or .03+.04*r(),big and 1.8 or 2.6)
  k=k+1+floor(SR*(-math.log(1-r()*.999)/(big and 3.5 or 11)))
 end
 k=floor(SR*.3)
 while k<n do
  local rs=reson(1800+1600*r(),300);local amp=.05+.08*r();local m=floor(SR*.01);spend(m)
  for j=0,m-1 do
   local idx=k+j;if idx>n then break end
   local x=(j<floor(SR*.0008))and(r()*2-1)or 0
   out[idx]=out[idx]+rs(x)*amp*6
  end
  k=k+1+floor(SR*(-math.log(1-r()*.999)/4))
 end
 return out
end
-- the Hall of Fame: the crowd, applause (each clap a short ring, not a
-- burst of hiss) and bells
function S.fame(r,n)
 local out=crowdBed(r,n,1,.35)
 local k=1
 while k<n do
  local rs=reson(900+1300*r(),700);local amp=.10+.12*r();spend(floor(SR*.012))
  for j=0,floor(SR*.012)-1 do
   local idx=k+j;if idx>n then break end
   local x=(j<floor(SR*.0015))and(r()*2-1)or 0
   out[idx]=out[idx]+rs(x)*amp*7
  end
  k=k+1+floor(SR*(-math.log(1-r()*.999)/120))
 end
 local notes={523.25,659.25,783.99,1046.5}
 k=floor(SR*.8)
 while k<n do
  for q,f in ipairs(notes)do bellAdd(out,k+floor((q-1)*.14*SR),f,.22,1.6)end
  k=k+floor(SR*(4.5+2*r()))
 end
 return out
end

-- TEST173's town interiors
-- ROOM: a quiet house, and a clock ticking in it
function S.room(r,n)
 local out=roomTone(r,n,1)
 local k=floor(SR*.1);local tock=false
 while k<n do
  local rs=reson(tock and 1900 or 2500,90);spend(floor(SR*.03))
  for j=0,floor(SR*.03)-1 do
   local idx=k+j;if idx>n then break end
   local x=(j<floor(SR*.0008))and 1 or 0
   out[idx]=out[idx]+rs(x)*1.4
  end
  k=k+floor(SR*1.0);tock=not tock
 end
 return out
end
-- HALL: a public room: its air, and people crossing it now and then
function S.hall(r,n)
 local out=roomTone(r,n,1.1)
 local t=SR*(.6+r())
 while t<n do
  local steps=4+floor(r()*6);local gap=SR*(.48+.12*r());local amp=.06+.10*r()
  for s=0,steps-1 do
   local i0=floor(t+s*gap);if i0>n then break end
   footstep(out,i0,amp*(1-.25*(s%2)),r)
  end
  t=t+steps*gap+SR*(1.2+2.5*r())
 end
 return out
end
-- SHOP: the refrigerated cases' hum and the room
function S.shop(r,n)
 local out=roomTone(r,n,.9)
 for i=1,n do
  breathe(i);local t=i/SR
  out[i]=out[i]+(sin(2*pi*120*t)*.03+sin(2*pi*240.5*t)*.018+sin(2*pi*360*t)*.006)*(.9+.1*sin(t*.7))
 end
 return out
end
-- AQUA: the tanks and the pool: a low gurgle, rising bubbles, the pump
function S.aqua(r,n)
 local out=babble(r,n,9,220,700,.7)
 for i=1,n do breathe(i);local t=i/SR;out[i]=out[i]+sin(2*pi*236*t)*.006 end
 -- now and then a rising string of bubbles
 local k=floor(SR*.7)
 while k<n do
  local f=260+200*r()
  for q=0,4+floor(r()*5)do bubble(out,k+floor(q*SR*(.05+.03*r())),f*(1+q*.07),.09,.05,2.5)end
  k=k+floor(SR*(1.8+2.6*r()))
 end
 return out
end
-- HUM: a steady electric hum (no crackle)
function S.hum(r,n)
 local out=roomTone(r,n,.6)
 for i=1,n do
  breathe(i);local t=i/SR
  out[i]=out[i]+(sin(2*pi*60*t)*.05+sin(2*pi*120.3*t)*.13+sin(2*pi*180*t)*.07+sin(2*pi*240*t)*.03)*(.92+.08*sin(t*1.3))
 end
 return out
end
-- POWER (TEST191, the Vermilion Gym): the station's hum and, now and then,
-- an arc: a low thump with a burst of snaps, each a click rung through a
-- resonance (a crack, not a hiss); sometimes the charge whines up first
function S.power(r,n)
 local out=scale(S.hum(r,n),.85)
 local k=floor(SR*.9)
 while k<n do
  if r()<.4 and k>SR*1.2 then
   local m=floor(SR*1.0);local ph=0;spend(m)
   for j=0,m-1 do
    local idx=k-m+j
    local u=j/m;ph=ph+2*pi*(300+520*u*u)/SR
    out[idx]=out[idx]+sin(ph)*.035*u*u*(1-u*.2)
   end
  end
  local th=floor(SR*.09);local ph=0;spend(th)
  for j=0,th-1 do
   local idx=k+j;if idx>n then break end
   local tt=j/SR;ph=ph+2*pi*(150-60*min(1,tt/.06))/SR
   out[idx]=out[idx]+sin(ph)*exp(-tt*36)*.5
  end
  for c=0,2+floor(r()*5)do
   local i0=k+floor(SR*(.011*c+.018*r()))
   local rs=reson(1300+1500*r(),420);local amp=.24+.30*r()
   local len=floor(SR*.02);spend(len)
   for j=0,len-1 do
    local idx=i0+j;if idx>n then break end
    local x=(j<floor(SR*.001))and(r()*2-1)or 0
    out[idx]=out[idx]+rs(x)*amp*7
   end
  end
  k=k+floor(SR*(1.3+2.6*r()))
 end
 return out
end
-- GARDEN: birdsong over a trickle (the greenhouse)
function S.garden(r,n)
 local out=scale(babble(r,n,30,420,1300,.25),.6)
 local k=floor(SR*.5)
 while k<n do
  local f0=2300+1500*r();local notes=2+floor(r()*4)
  for q=0,notes-1 do
   local len=floor(SR*(.06+.05*r()));local st=k+q*floor(SR*.11)
   local fq=f0*(1+.15*(r()-.5));local ph=0;spend(len)
   for j=0,len-1 do local idx=st+j;if idx>n then break end
    local t=j/SR;ph=ph+2*pi*(fq+fq*.22*sin(t*55))/SR
    out[idx]=out[idx]+sin(ph)*sin(pi*j/len)^2*.16 end
  end
  k=k+floor(SR*(1.4+2.8*r()))
 end
 return out
end
-- {seconds, loudness (RMS)}: the beds are levelled by loudness
local BEDS={
 wind={16,.11},falls={14,.12},fire={14,.10},fountain={14,.09},crowd={16,.09},
 lobby={16,.07},ice={16,.08},dojo={16,.11},crypt={18,.10},storm={18,.12},champion={16,.11},fame={18,.11},
 room={16,.035},hall={18,.05},shop={14,.05},aqua={16,.07},hum={12,.06},garden={18,.07},power={16,.06},
 lava={16,.10},
}
local function level(buf,rms)
 local s=0
 for i=1,#buf do breathe(i);s=s+buf[i]*buf[i]end
 local cur=math.sqrt(s/math.max(1,#buf))
 local k=rms/math.max(1e-6,cur)
 local peak=0
 for i=1,#buf do breathe(i);local a=abs(buf[i]*k);if a>peak then peak=a end end
 if peak>.92 then k=k*.92/peak end
 for i=1,#buf do breathe(i);buf[i]=buf[i]*k end
 return buf
end
M.BEDS=BEDS
function M.synth(name,seed)
 local spec=BEDS[name];if not spec then return nil end
 local r=rng(seed or 17)
 local n=floor(SR*(spec[1]+1.0))
 local buf=S[name](r,n)
 return level(loopify(buf,1.0),spec[2])
end

------------------------------------------------------------------ runtime
local tracks={}      -- name -> {source,volume,target,state}
local building=nil   -- {name,co}
local beat,remove=-1e9,nil
local wants={}

-- targets: {name=0..1, ...}; anything not named fades out
function M.touch(targets)
 beat=love.timer.getTime()
 wants=targets or{}
end

local function startBuild(name)
 local co=coroutine.create(function()
  local buf=M.synth(name,#name*31+7)
  local sd=love.sound.newSoundData(#buf,SR,16,1)
  for i=1,#buf do
   sd:setSample(i-1,buf[i])
   if i%8000==0 then coroutine.yield()end
  end
  local src=love.audio.newSource(sd,'static')
  src:setLooping(true);src:setVolume(0)
  return src
 end)
 building={name=name,co=co}
end

local function gainOf(game)
 local opts=game and game.save and game.save.options
 local g=max(0,min(7,tonumber(opts and opts.sfxVol)or 7))/7
 local pub=rawget(_G,'__ds_ceiling_config')
 if type(pub)=='function'then
  local ok,c=pcall(pub)
  if ok and type(c)=='table'then
   if c.ambience==false or c.ambience=='OFF'then g=0 elseif c.ambience=='LOW'then g=g*.55 end
  end
 end
 return g,opts
end

function M.update(game,dt)
 local now=love.timer.getTime()
 local live=now-beat<.5
 local g,opts=gainOf(game)
 local delta=max(0,min(.1,tonumber(dt)or 0))
 -- build the next wanted bed, a slice a frame
 if building then
  local ok,res=coroutine.resume(building.co)
  if not ok then tracks[building.name]={failed=true};building=nil
  elseif coroutine.status(building.co)=='dead'then
   tracks[building.name]={source=res,volume=0}
   building=nil
  end
 elseif live then
  for name,w in pairs(wants)do
   if w>.001 and not tracks[name]and BEDS[name]then startBuild(name);break end
  end
 end
 for name,tr in pairs(tracks)do
  if tr.source then
   local want=live and(wants[name]or 0)*g or 0
   if opts and tonumber(opts.sfxVol)==0 then tr.volume=0
   else tr.volume=tr.volume+max(-delta*.5,min(delta*.35,want-tr.volume))end
   pcall(tr.source.setVolume,tr.source,max(0,min(1,tr.volume)))
   local ok,on=pcall(tr.source.isPlaying,tr.source)
   if tr.volume>.002 then
    tr.idle=0
    if not(ok and on)then pcall(tr.source.play,tr.source)end
   else
    if ok and on then pcall(tr.source.stop,tr.source)end
    tr.idle=(tr.idle or 0)+delta
    if tr.idle>60 then pcall(tr.source.release,tr.source);tracks[name]=nil end
   end
  end
 end
 -- TEST196: the stadium crowd's own sounds (cheers, roars, the wave, the
 -- chants) ride this update, at the same gain (SFX volume, ambience setting)
 local okC,Crowd=pcall(V.require,'LeagueCrowd')
 if okC and type(Crowd)=='table'and Crowd.update then pcall(Crowd.update,game,delta,g)end
end

function M.dispose()
 if remove then pcall(remove);remove=nil end
 pcall(function()V.require('LeagueCrowd').dispose()end)
 for _,tr in pairs(tracks)do if tr.source then pcall(tr.source.stop,tr.source);pcall(tr.source.release,tr.source)end end
 tracks,building,wants={},nil,{}
end

function M.install(mod)
 if remove then return end
 remove=mod.hooks:wrap('core.update',function(nxt,game,dt)
  local ok=pcall(M.update,game,dt)
  if not ok then wants={} end
  return nxt(game,dt)
 end)
end
return M
