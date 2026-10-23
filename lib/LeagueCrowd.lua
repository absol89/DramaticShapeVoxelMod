-- TEST196: THE CROWD, HEARD. The League's stadiums (LeagueStadium) had only
-- a steady murmur under the battle music. Now the crowd you see is the crowd
-- you hear, and both answer the fight:
--
--  * the opening: the house roars as the stadium appears, with the member's
--    own call (Lorelei's ice chimes, Bruno's great gong, Agatha's bell
--    tolling, Lance's dragon roaring at the gate, the Champion's air horns
--    and fanfare)
--  * a Pokemon sent out: a cheer
--  * a hit: the bigger the hit, the bigger the noise; a critical hit or a
--    super-effective one gets the roar
--  * a move about to land: now and then an "ooooh"
--  * a faint: a roar (theirs) or a gasp and applause (yours)
--  * the win: an ovation; the loss: an "awww" and applause
--  * between them: the Mexican wave is heard as it goes round, the house
--    roars when the stands do, whoops and whistles pop out of it, and every
--    so often the crowd's own chant: cowbells (Lorelei), war drums with the
--    stands shouting on the beat (Bruno), a ghostly moan (Agatha), the fire
--    columns going up (Lance), and the clapping chant with air horns (the
--    Champion).
--
-- TEST197: Lance's boiling lake is heard too: its big bubbles bursting and
-- its spurts (M.sfx, called by LeagueStadium as they happen on screen).
--
-- And the stands MOVE with it: a big moment brings every section to its
-- feet, the stands jump on the drum beats and the claps of a chant, and the
-- fires (Lance), drums and gong (Bruno), crystals (Lorelei), violet lights
-- (Agatha) and pyro (the Champion) flare with the sounds that go with them.
--
-- Every sound is synthesised here, no files: voices are a choir of pitched
-- sources through moving vowel formants (so a cheer says "yeah" and a gasp
-- says "ooh" instead of hissing), claps are clicks rung through a short
-- resonance, and nothing lives above ~3 kHz but whistles and glass, which a
-- handheld speaker plays cleanly. They are built a slice at a time while you
-- walk a stadium room (after the stadium itself), only that room's set, and
-- freed when you leave the stadium rooms behind.
--
-- LeagueStadium.draw calls M.frame(r) on every battle frame it draws (that
-- is what "live" means here); LeagueAmbience's update calls M.update(game,
-- dt, gain), which builds and plays. SFX volume and the ambience
-- setting (OFF / LOW) are honoured. Presentation only: nothing here touches
-- the battle.
local V=...
local M={REVISION='league-crowd-197'}
local SR=22050
local floor,min,max,sin,cos,exp,pi,abs,sqrt,log=math.floor,math.min,math.max,math.sin,math.cos,math.exp,math.pi,math.abs,math.sqrt,math.log
local TAU=pi*2

------------------------------------------------------------------ synthesis
-- Pure functions returning 1-based sample arrays: headless-testable.
local function rng(seed)
 local s=floor(seed)%2147483646+1
 return function()s=(s*16807)%2147483647;return s/2147483647 end
end
local function coef(fc)return 1-exp(-2*pi*fc/SR)end
-- the builder coroutine hands the frame back once its slice of time is
-- spent (checked every thousand units of work, a unit being roughly one
-- oscillator-sample); from anywhere else (the main thread, a test) it never
-- yields
local BUILDER=nil
local work=0
local deadline=math.huge
local pace=(love and love.timer and love.timer.getTime)or os.clock
-- the slice: more while you walk the room, less once the battle is on
M.BUDGET,M.BUDGET_BATTLE=.0025,.001
local function spend(m)
 work=work+m
 if work>=1000 then
  work=0
  if BUILDER and coroutine.running()==BUILDER and pace()>deadline then coroutine.yield()end
 end
end
-- (the long loops below count their own work every 1024 samples, so no
-- single loop, however long its sound, can overrun a slice)
local function zeros(n)local out={};for i=1,n do out[i]=0;if i%1024==0 then spend(128)end end;return out end
local function mixInto(out,src,k)
 for i=1,min(#out,#src)do out[i]=out[i]+src[i]*k;if i%1024==0 then spend(170)end end
 return out
end
local function rmsOf(buf)
 local s=0;for i=1,#buf do s=s+buf[i]*buf[i];if i%1024==0 then spend(128)end end
 return sqrt(s/max(1,#buf))
end
local function peakOf(buf)
 local m=0;for i=1,#buf do local a=abs(buf[i]);if a>m then m=a end;if i%1024==0 then spend(128)end end
 return m
end
local function scale(buf,k)for i=1,#buf do buf[i]=buf[i]*k;if i%1024==0 then spend(128)end end;return buf end
-- level a part by its loudness, so parts mix by intent, not by accident
local function toRms(buf,target)
 local r=rmsOf(buf);if r<1e-9 then return buf end
 return scale(buf,target/r)
end
-- the finished sound: levelled by loudness; peaks over .62 rounded off by
-- a soft knee (claps in unison are tall, thin peaks: shaving them keeps the
-- sound as loud as it should be) and never past .92; short fades so
-- nothing clicks
local function finish(buf,rms)
 local r=rmsOf(buf)
 local k=r>1e-9 and rms/r or 1
 local p=peakOf(buf)*k
 -- no more than half the loudness may come from the knee
 if p>2.4 then k=k*2.4/p end
 local n=#buf
 local fi,fo=floor(SR*.004),floor(SR*.03)
 local tanh=math.tanh or function(x)local e=exp(2*x);return(e-1)/(e+1)end
 for i=1,n do
  local g=k
  if i<=fi then g=g*(i/fi)end
  if i>n-fo then g=g*((n-i)/fo)end
  local x=buf[i]*g
  local a=abs(x)
  if a>.62 then a=.62+.30*tanh((a-.62)/.30);x=x<0 and -a or a end
  buf[i]=x
  if i%1024==0 then spend(256)end
 end
 return buf
end

-- the vowels: the first three formants (Hz)
local VOW={
 i={290,2250,2900},e={480,1850,2500},a={740,1150,2450},ah={660,1250,2450},
 o={540,860,2400},u={320,850,2250},uh={630,1180,2400},aw={600,920,2400},
}
-- a vowel path: {{u,'a'},{u,'o'},...} -> function(u) giving F1,F2,F3
local function path(pts,k)
 k=k or 1
 return function(u)
  local A,B=pts[1],pts[#pts]
  for i=1,#pts-1 do if u>=pts[i][1]and u<=pts[i+1][1]then A,B=pts[i],pts[i+1];break end end
  local va,vb=VOW[A[2]],VOW[B[2]]
  local w=(B[1]>A[1])and min(1,max(0,(u-A[1])/(B[1]-A[1])))or 0
  w=w*w*(3-2*w)
  return(va[1]+(vb[1]-va[1])*w)*k,(va[2]+(vb[2]-va[2])*w)*k,(va[3]+(vb[3]-va[3])*w)*k
 end
end

-- THE CHOIR: `o.n` voices, each a sawtooth at its own pitch with its own
-- onset, length, vibrato and glide, summed and rolled off like a throat,
-- then sung through three shared resonators that follow the vowel path. A
-- breath of noise goes through the same vowel. Parameters update every 64
-- samples; the inner loop is an add, a wrap and a multiply per voice.
--   o.n, o.lo, o.hi        voices, pitch range (Hz)
--   o.onset(v,r)           seconds; default r()*o.spread
--   o.dmin, o.dmax         each voice's length (s)
--   o.att, o.rel           each voice's attack and release (s)
--   o.glide(u,p,g)         pitch factor (u: the whole sound 0..1, p: this
--                          voice 0..1, g: the voice's own 0..1 seed)
--   o.vowel(u)             F1,F2,F3
--   o.env(u)               the sound's amplitude
--   o.vib, o.breath        vibrato depth, breath amount
local function choir(n,o,r)
 local out=zeros(n)
 local NV=o.n
 local ON,OFF,F,PH,AMP,VP,VR,GL={},{},{},{},{},{},{},{}
 for v=1,NV do
  local on=floor((o.onset and o.onset(v,r)or r()*(o.spread or .2))*SR)
  local dur=floor(((o.dmin or .8)+r()*((o.dmax or 1.6)-(o.dmin or .8)))*SR)
  ON[v]=on;OFF[v]=min(n,on+dur)
  F[v]=o.lo*(o.hi/o.lo)^r();PH[v]=r();AMP[v]=.55+.45*r();VP[v]=r()*TAU;VR[v]=4.2+2.4*r();GL[v]=r()
 end
 local INC,G,ACT={},{},{}
 local att,rel=max(.005,o.att or .05)*SR,max(.005,o.rel or .3)*SR
 local bw1,bw2,bw3=o.bw1 or 110,o.bw2 or 150,o.bw3 or 230
 local R1,R2,R3=exp(-pi*bw1/SR),exp(-pi*bw2/SR),exp(-pi*bw3/SR)
 local Q1,Q2,Q3=R1*R1,R2*R2,R3*R3
 -- band-pass resonators (a zero at DC and one at Nyquist): the vowel and
 -- nothing of the rumble under it
 local g1,g2,g3=(1-Q1)*.5,(1-Q2)*.5*(o.f2 or .62),(1-Q3)*.5*(o.f3 or .22)
 local y11,y12,y21,y22,y31,y32=0,0,0,0,0,0
 local x1,x2=0,0
 local direct=o.direct or .10
 local tilt,tl=coef(o.tilt or 1500),0
 local tilt2,tl2=coef(o.tilt or 1500),0
 local breath=o.breath or .3
 local nlp,na=0,coef(2400)
 local vib=o.vib or .012
 local B=64
 for b0=0,n-1,B do
  local u=b0/n
  local F1,F2,F3=o.vowel(u)
  local k1,k2,k3=2*R1*cos(TAU*F1/SR),2*R2*cos(TAU*F2/SR),2*R3*cos(TAU*F3/SR)
  local env=o.env and o.env(u)or 1
  local na_=0
  local ts=b0/SR
  for v=1,NV do
   if b0+B>ON[v]and b0<OFF[v]then
    local e=min(1,(b0-ON[v])/att,(OFF[v]-b0)/rel)
    if e>0 then
     local p=(b0-ON[v])/max(1,OFF[v]-ON[v])
     local gl=o.glide and o.glide(u,p,GL[v])or 1
     na_=na_+1;ACT[na_]=v
     INC[v]=F[v]*gl*(1+vib*sin(VP[v]+VR[v]*ts*TAU))/SR
     G[v]=e*AMP[v]
    end
   end
  end
  local bend=min(n-1,b0+B-1)
  spend((bend-b0+1)*(na_+5))
  -- the breath follows how many are singing
  local bk=breath*sqrt(na_)*.35
  for j=b0,bend do
   local s=0
   for a=1,na_ do
    local v=ACT[a]
    local ph=PH[v]+INC[v]
    if ph>=1 then ph=ph-1 end
    PH[v]=ph
    s=s+(ph+ph-1)*G[v]
   end
   tl=tl+tilt*(s-tl);tl2=tl2+tilt2*(tl-tl2)
   local x=tl2
   if bk>0 then nlp=nlp+na*((r()*2-1)-nlp);x=x+nlp*bk end
   local dx=x-x2;x2=x1;x1=x
   local y1=k1*y11-Q1*y12+g1*dx;y12=y11;y11=y1
   local y2=k2*y21-Q2*y22+g2*dx;y22=y21;y21=y2
   local y3=k3*y31-Q3*y32+g3*dx;y32=y31;y31=y3
   out[j+1]=(y1+y2+y3+tl2*direct)*env
  end
 end
 return out
end

-- CLAPS: each a click rung through a short resonance (a clap, not hiss);
-- dens(u) is claps per second at that point of the sound
local function claps(n,dens,r,lo,hi)
 local out=zeros(n)
 lo,hi=lo or 900,hi or 2200
 -- the busiest the clapping gets; claps are drawn at that rate and kept in
 -- proportion to how busy it is at that moment (so a sparse start is a
 -- sparse start, not one long silence)
 local top=1
 for q=0,64 do top=max(top,dens(q/64))end
 local R=exp(-pi*700/SR)
 local m=floor(SR*.014);local m0=floor(SR*.0015)
 local k=1+floor(SR*(-log(1-r()*.999)/top))
 while k<n do
  if r()*top<=dens(k/n)then
   local f=lo+(hi-lo)*r()
   local c=2*R*cos(TAU*f/SR);local y1,y2=0,0
   local amp=.5+.5*r()
   spend(m+8)
   for j=0,m-1 do
    local idx=k+j;if idx>n then break end
    local x=(j<m0)and(r()*2-1)or 0
    local y=c*y1-R*R*y2+(1-R)*x;y2=y1;y1=y
    out[idx]=out[idx]+y*amp
   end
  end
  k=k+1+floor(SR*(-log(1-r()*.999)/top))
 end
 return out
end
-- unison claps: a whole crowd clapping on one beat (t in seconds)
local function clapAt(out,t,r,count,spread)
 local n=#out
 for c=1,count do
  local k=floor((t+(r()-.5)*(spread or .03))*SR)+1
  if k>=1 then
   local f=900+1300*r()
   local R=exp(-pi*700/SR);local cc=2*R*cos(TAU*f/SR);local y1,y2=0,0
   local amp=.5+.5*r()
   local m=floor(SR*.014);spend(m+8)
   for j=0,m-1 do
    local idx=k+j;if idx>n then break end
    local x=(j<floor(SR*.0015))and(r()*2-1)or 0
    local y=cc*y1-R*R*y2+(1-R)*x;y2=y1;y1=y
    out[idx]=out[idx]+y*amp
   end
  end
 end
end
-- a two-finger whistle: a rising sine with a breath round it
local function whistle(out,t0,len,f0,f1,f2,amp,r)
 local n=#out;local i0=floor(t0*SR)+1;local m=floor(len*SR)
 local ph=0;local nl=0;local a=coef(3200)
 for j=0,m-1 do
  local k=i0+j;if k>n then break end
  if j%1024==0 then spend(2048)end
  local u=j/m
  local f=u<.18 and f0+(f1-f0)*(u/.18)^.7 or f1+(f2-f1)*((u-.18)/.82)^1.6
  f=f*(1+.012*sin(j/SR*TAU*6))
  ph=ph+f/SR;if ph>=1 then ph=ph-1 end
  local env=min(1,u/.05)*min(1,(1-u)/.12)
  nl=nl+a*((r()*2-1)-nl)
  out[k]=out[k]+(sin(ph*TAU)+nl*.12)*env*amp
 end
end
-- band-limited noise: the mass of a crowd under its voices
local function crowdNoise(n,env,r,lo,hi)
 local out=zeros(n)
 local a1,a2=coef(hi or 1100),coef(lo or 260)
 local l1,l2,l3,l4=0,0,0,0
 local sw,swT,swV=1,0,1
 for i=1,n do
  if i%1024==0 then spend(2048)end
  local t=i/SR
  if t>=swT then swT=t+.12+r()*.3;swV=.6+.8*r()end
  sw=sw+(swV-sw)*.0012
  local x=r()*2-1
  l1=l1+a1*(x-l1);l2=l2+a1*(l1-l2)
  l3=l3+a2*(x-l3);l4=l4+a2*(l3-l4)
  out[i]=(l2-l4)*env(i/n)*sw
 end
 return out
end
-- a struck partial set: {ratio, amp, decay tau (s)[, bloom (s)]}. Each
-- partial is a recursive oscillator (a multiply and a subtract a sample, no
-- sine), dying away by its own tau and, if it blooms, swelling first.
local function partials(out,t0,f,amp,P,len,r,detune)
 local n=#out;local i0=floor(t0*SR)+1;local m=floor(len*SR)
 local ramp=floor(SR*.002)
 for _,p in ipairs(P)do
  local fr=f*p[1]*(1+(detune or 0)*(r and(r()-.5)or 0))
  if fr<SR*.45 then
   local w=TAU*fr/SR
   local ph=r and r()*TAU or 0
   local c=2*cos(w)
   local y1,y2=sin(ph),sin(ph-w)
   local d=exp(-1/(p[3]*SR))
   local e=amp*p[2]
   local q,qd=1,p[4]and exp(-1/(p[4]*SR))or 0
   local last=min(m-1,n-i0)
   for j=0,last do
    if j%1024==0 then spend(512)end
    local y=c*y1-y2;y2=y1;y1=y
    local a=e
    if qd>0 then a=a*(1-q);q=q*qd end
    if j<ramp then a=a*j/ramp end
    local k=i0+j
    out[k]=out[k]+y*a
    e=e*d
   end
  end
 end
end
-- a drum: a skin dropping in pitch, its overtones, and the slap of the hit
-- (a handheld's speaker hardly plays the body under ~200 Hz: the skin's
-- slap, the overtones and the stick carry the hit there)
local function drum(out,t0,f0,amp,r,len)
 local n=#out;local i0=floor(t0*SR)+1;local m=floor((len or .9)*SR)
 local ph,ph2=0,0;local lp,lp2=0,0;local a=coef(800)
 local Rs=exp(-pi*600/SR);local cs=2*Rs*cos(TAU*1150/SR);local s1,s2=0,0
 for j=0,m-1 do
  local k=i0+j;if k>n then break end
  if j%1024==0 then spend(3072)end
  local t=j/SR
  local f=f0*(1+.55*exp(-t*28))
  ph=ph+f/SR;if ph>=1 then ph=ph-1 end
  ph2=ph2+f*2.32/SR;if ph2>=1 then ph2=ph2-1 end
  local x=r()*2-1
  lp=lp+a*(x-lp);lp2=lp2+a*(lp-lp2)
  local body=sin(ph*TAU)*exp(-t*5.5)+.55*sin(ph2*TAU)*exp(-t*9)
  local skin=lp2*exp(-t*18)*8
  local tone=sin(ph*TAU*3)*exp(-t*12)*.35+sin(ph*TAU*4.1)*exp(-t*16)*.18
  local st=(j<floor(SR*.0012))and x or 0
  local sy=cs*s1-Rs*Rs*s2+(1-Rs)*st;s2=s1;s1=sy
  out[k]=out[k]+(body+skin+tone+sy*5)*amp*min(1,t/.002)
 end
end
-- a low thud: a stamp of feet
local function thud(out,t0,amp)
 local n=#out;local i0=floor(t0*SR)+1;local m=floor(.18*SR);local ph=0;spend(m+8)
 for j=0,m-1 do
  local k=i0+j;if k>n then break end
  local t=j/SR;ph=ph+(140-60*min(1,t/.06))/SR
  out[k]=out[k]+sin(ph*TAU)*exp(-t*30)*amp
 end
end

local S={}
-- envelopes
local function swell(a,b,c)return function(u)if u<a then return(u/a)^.8 elseif u<b then return 1 else return max(0,1-(u-b)/(c-b))^1.4 end end end

-- A CHEER: "yeah!" from a section, some higher voices "woo!", claps, a
-- whistle or two
local function cheer(seed,wooK,len)
 local r=rng(seed);len=len or 2.9
 local n=floor(len*SR)
 local V1=choir(n,{n=22,lo=110,hi=330,onset=function(v,r)return r()^1.5*.35 end,dmin=1.1,dmax=2.1,att=.05,rel=.40,
  glide=function(u,p)return .94+.2*sin(pi*min(1,p*1.3))*(1-.45*p)end,
  vowel=path({{0,'i'},{.06,'e'},{.22,'a'},{1,'ah'}}),env=swell(.04,.50,1),breath=.35,vib=.016},r)
 toRms(V1,.20)
 local V2=choir(n,{n=7,lo=250,hi=480,onset=function(v,r)return .08+r()*.6 end,dmin=.6,dmax=1.1,att=.04,rel=.25,
  glide=function(u,p)return 1+.45*min(1,p*1.6)end,vowel=path({{0,'u'},{.6,'o'},{1,'o'}}),env=swell(.05,.6,1),breath=.3},r)
 toRms(V2,.20*(wooK or .5))
 local Cl=claps(n,function(u)return u<.14 and 260*u/.14 or(u<.62 and 260 or 260*max(0,1-(u-.62)/.38))end,r)
 toRms(Cl,.09)
 mixInto(V1,V2,1);mixInto(V1,Cl,1)
 local W=zeros(n)
 for k=1,(wooK or .5)>.6 and 2 or 1 do whistle(W,.25+r()*.9,.8+r()*.4,1500+r()*300,2300+r()*400,1900+r()*400,1,r)end
 toRms(W,.035);mixInto(V1,W,1)
 return V1
end
function S.cheer()return cheer(101,.5)end
function S.cheer2()return cheer(211,.9,2.6)end
-- THE ROAR: the whole house, swelling and holding, applause all through it
function S.roar()
 local r=rng(307);local len=4.8;local n=floor(len*SR)
 local env=swell(.08,.62,1)
 local V1=choir(n,{n=28,lo=105,hi=340,onset=function(v,r)return r()^2*.6 end,dmin=2.6,dmax=4.3,att=.25,rel=.9,
  glide=function(u,p,g)return .95+.15*sin(pi*p)+.03*sin(TAU*(p*2+g))end,
  vowel=path({{0,'a'},{.45,'uh'},{.8,'o'},{1,'o'}}),env=env,breath=.55,vib=.02},r)
 toRms(V1,.20)
 local N=crowdNoise(n,env,r,260,1100);toRms(N,.08);mixInto(V1,N,1)
 local Cl=claps(n,function(u)return u<.12 and 420*u/.12 or(u<.68 and 420 or 420*max(0,1-(u-.68)/.32))end,r)
 toRms(Cl,.09);mixInto(V1,Cl,1)
 local W=zeros(n)
 for k=1,3 do whistle(W,.5+r()*2.8,.8+r()*.5,1450+r()*300,2250+r()*450,1850+r()*400,1,r)end
 toRms(W,.03);mixInto(V1,W,1)
 return V1
end
-- "OOOOH": a gasp of anticipation, rising
function S.ooh()
 local r=rng(401);local n=floor(2.0*SR)
 return choir(n,{n=26,lo=110,hi=300,onset=function(v,r)return r()*.12 end,dmin=1.4,dmax=1.9,att=.12,rel=.5,
  glide=function(u,p)return .9+.36*min(1,p*1.1)^.8 end,vowel=path({{0,'u'},{.35,'o'},{1,'o'}}),env=swell(.06,.55,1),breath=.3,vib=.02},r)
end
-- "AWWW": the groan, falling
function S.aww()
 local r=rng(503);local n=floor(2.4*SR)
 local V1=choir(n,{n=26,lo=110,hi=300,onset=function(v,r)return r()*.10 end,dmin=1.6,dmax=2.2,att=.08,rel=.5,
  glide=function(u,p)return 1.15-.43*min(1,p)^.7 end,vowel=path({{0,'a'},{.3,'aw'},{1,'o'}}),env=swell(.05,.55,1),breath=.3,vib=.02},r)
 toRms(V1,.20)
 local Cl=claps(n,function(u)return u<.5 and 0 or 90 end,r);toRms(Cl,.04);mixInto(V1,Cl,1)
 return V1
end
-- THE WAVE: voices joining as it reaches them, loudest as it passes your
-- side of the bowl, rolling on round the far side, dying away
function S.wave()
 local r=rng(601);local len=9.0;local n=floor(len*SR)
 local function env(u)
  local t=u*len
  if t<2.25 then return .35+.65*(t/2.25)^1.5
  elseif t<4 then return 1-.42*(t-2.25)/1.75
  elseif t<7.2 then return .58
  else return .58*max(0,1-(t-7.2)/1.8)end
 end
 local V1=choir(n,{n=44,lo=105,hi=340,onset=function(v,r)return(v/44)*6.6+r()*.5 end,dmin=1.3,dmax=2.2,att=.12,rel=.6,
  glide=function(u,p)return .95+.3*min(1,p*1.4)^.8-.1*p end,
  vowel=function(u)local w=.5+.5*sin(u*len*TAU/1.1);local a,o=VOW.a,VOW.o
   return o[1]+(a[1]-o[1])*w,o[2]+(a[2]-o[2])*w,o[3]+(a[3]-o[3])*w end,
  env=env,breath=.45,vib=.02},r)
 toRms(V1,.20)
 local Cl=claps(n,function(u)return 120*env(u)end,r);toRms(Cl,.05);mixInto(V1,Cl,1)
 return V1
end
-- APPLAUSE, with a whoop or two in it
function S.applause()
 local r=rng(701);local len=3.6;local n=floor(len*SR)
 local Cl=claps(n,function(u)return u<.07 and 720*u/.07 or(u<.55 and 720 or 720*max(0,1-(u-.55)/.45)^1.2)end,r)
 toRms(Cl,.16)
 local V2=choir(n,{n=5,lo=230,hi=420,onset=function(v,r)return .1+r()*1.2 end,dmin=.6,dmax=1.0,att=.04,rel=.25,
  glide=function(u,p)return 1+.5*min(1,p*1.6)end,vowel=path({{0,'u'},{1,'o'}}),breath=.3},r)
 toRms(V2,.05);mixInto(Cl,V2,1)
 local W=zeros(n);whistle(W,.4+r()*.8,.9,1550,2400,2000,1,r);toRms(W,.025);mixInto(Cl,W,1)
 return Cl
end
-- one fan's "WOOO!"
function S.whoop()
 local r=rng(809);local n=floor(1.0*SR)
 return choir(n,{n=2,lo=230,hi=260,onset=function()return 0 end,dmin=.85,dmax=.9,att=.03,rel=.25,
  glide=function(u,p)return 1+.6*min(1,p*1.5)^.7 end,vowel=path({{0,'u'},{.5,'o'},{1,'o'}}),breath=.45,vib=.025},r)
end
function S.whistle()
 local r=rng(907);local W=zeros(floor(1.15*SR))
 whistle(W,.02,1.05,1600,2550,2150,1,r)
 return W
end

-- LORELEI: cowbells, rung all round the bowl like a ski race's crowd
function S.bells()
 local r=rng(1103);local len=3.3;local n=floor(len*SR)
 local out=zeros(n)
 local P={{1,1,.07},{1.48,.75,.05},{2.42,.25,.03},{3.6,.10,.02}}
 for b=1,7 do
  local f=540+r()*330
  local t=r()*.5;local stop=2.2+r()*.9
  local rate=7+r()*4
  while t<stop do
   partials(out,t,f,.45+.55*r(),P,.25,r,.004)
   t=t+(1/rate)*(.75+.5*r())
  end
 end
 return out
end
-- LORELEI: ice chimes, a cascade of glass down a cold scale
function S.chimes()
 local r=rng(1201);local len=3.2;local n=floor(len*SR)
 local out=zeros(n)
 local notes={2637,2349,1976,1760,1568,1319,1175,988}
 local P={{1,1,1.3},{2.76,.32,.45},{5.40,.10,.22}}
 for k=0,15 do
  local i=min(#notes,1+floor(k/2+r()*1.6))
  partials(out,k*.085+r()*.03,notes[i],.5+.5*r(),P,1.9,r)
 end
 for k=0,25 do partials(out,.05+r()*1.8,2600+r()*900,.10+.10*r(),{{1,1,.25}},.6,r)end
 return out
end
-- BRUNO: the war drums, and the stands shouting "HUH!" on the accents
M.BEATS={taiko={0,.5,1.0,1.25,1.5,2.3,2.8,3.3,3.55,3.8},
 chant={0,.42,1.05,1.26,1.47,2.4,2.82,3.45,3.66,3.87}}
function S.taiko()
 local r=rng(1301);local len=4.7;local n=floor(len*SR)
 local out=zeros(n)
 for i,t in ipairs(M.BEATS.taiko)do
  local acc=(i==5 or i==10)
  drum(out,t,acc and 78 or 88,acc and 1.0 or .7,r)
  if not acc then drum(out,t+.25,180,.18,r,.25)end   -- the rim between
 end
 toRms(out,.20)
 for _,t in ipairs({1.5,3.8})do
  local m=floor(.5*SR)
  local sh=choir(m,{n=22,lo=95,hi=200,onset=function(v,r)return r()*.04 end,dmin=.26,dmax=.34,att=.02,rel=.12,
   glide=function(u,p)return 1.08-.16*p end,vowel=path({{0,'uh'},{1,'a'}}),breath=.5},r)
  toRms(sh,.22)
  local i0=floor(t*SR)
  for j=1,m do if i0+j<=n then out[i0+j]=out[i0+j]+sh[j]end end;spend(m/6)
 end
 return out
end
-- BRUNO: the great gong over the gate: a strike, then the tone blooming
function S.gong()
 local r=rng(1409);local len=5.6;local n=floor(len*SR)
 local out=zeros(n)
 local P={}
 -- the low tone, and the shimmer that blooms out of it after the strike
 local ratios={1,1.47,1.98,2.43,2.81,3.27,3.73,4.21,4.90,5.62,6.4,7.3,8.3,9.6,11.1}
 for k,q in ipairs(ratios)do
  local a=(k==1 and .55 or 1/k^.35)
  P[#P+1]={q,a,max(.9,4.8-k*.30),k>3 and .04+.05*k or nil}
  P[#P+1]={q*1.004,a*.6,max(.8,4.4-k*.28),k>3 and .04+.05*k or nil}
 end
 partials(out,0,196,.35,P,len,r,.002)
 drum(out,0,70,.5,r,.6)
 return out
end
-- AGATHA: the crowd's ghostly moan, wavering up and down
function S.moan()
 local r=rng(1511);local len=5.0;local n=floor(len*SR)
 local V1=choir(n,{n=20,lo=120,hi=270,onset=function(v,r)return r()*.8 end,dmin=3.2,dmax=4.2,att=.9,rel=1.2,
  glide=function(u,p,g)return 1+.08*sin(TAU*(p*1.3+g))+.10*sin(pi*u)end,
  vowel=path({{0,'u'},{.45,'o'},{.7,'u'},{1,'u'}}),env=function(u)return sin(pi*u)^.7 end,breath=.25,vib=.03},r)
 toRms(V1,.20)
 local V2=choir(n,{n=6,lo=380,hi=520,onset=function(v,r)return .6+r()*1.2 end,dmin=2.0,dmax=3.0,att=.8,rel=1.0,
  glide=function(u,p,g)return 1+.06*sin(TAU*(p*1.7+g))end,vowel=path({{0,'i'},{1,'u'}}),breath=.2,vib=.035},r)
 toRms(V2,.07);mixInto(V1,V2,1)
 return V1
end
-- AGATHA: a deep bell tolling, its echo coming back off the stone
function S.toll()
 local r=rng(1607);local len=5.6;local n=floor(len*SR)
 local out=zeros(n)
 local P={{.5,.45,4.8},{1,.70,3.2},{1.19,.80,2.6},{1.5,.35,2.1},{2,1.0,2.3},{2.51,.22,1.4},{3,.28,1.2},{4,.14,.8}}
 partials(out,0,220,.5,P,len,r)
 partials(out,.38,220,.12,P,len-.4,r)
 drum(out,0,90,.25,r,.3)
 return out
end
-- LANCE: the fire columns going up: a WHOOMPH, the roar of the flame,
-- crackle in its tail
function S.pyro()
 local r=rng(1709);local len=2.3;local n=floor(len*SR)
 local out=zeros(n)
 local l1,l2=0,0;local ph=0
 for i=1,n do
  if i%1024==0 then spend(3072)end
  local t=i/SR
  local fc=t<.08 and 150+1300*(t/.08)or 350+1100*exp(-(t-.08)*2.6)
  local a=coef(fc)
  local x=r()*2-1
  l1=l1+a*(x-l1);l2=l2+a*(l1-l2)
  local env=min(1,t/.02)*exp(-t*1.9)
  ph=ph+(62-22*min(1,t/.25))/SR
  out[i]=l2*env*7+sin(ph*TAU)*exp(-t*9)*.9
 end
 toRms(out,.20)
 local k=floor(.15*SR)
 while k<n do
  local f=1200+1800*r();local R=exp(-pi*500/SR);local c=2*R*cos(TAU*f/SR);local y1,y2=0,0
  local amp=(.3+.7*r())*exp(-(k/SR)*1.4)*.9
  local m=floor(SR*.012);spend(m+8)
  for j=0,m-1 do
   local idx=k+j;if idx>n then break end
   local x=(j<floor(SR*.0012))and(r()*2-1)or 0
   local y=c*y1-R*R*y2+(1-R)*x;y2=y1;y1=y
   out[idx]=out[idx]+y*amp*6
  end
  k=k+1+floor(SR*(-log(1-r()*.999)/38))
 end
 return out
end
-- LANCE: a dragon roaring at the gate
function S.dragon()
 local r=rng(1801);local len=3.0;local n=floor(len*SR)
 local rough,rt,rv=1,0,1
 local function contour(u)local t=u*len;return t<.5 and .85+.55*(t/.5)or(t<1.9 and 1.4-.25*(t-.5)/1.4 or 1.15-.45*(t-1.9)/1.1)end
 local V1=choir(n,{n=3,lo=70,hi=76,onset=function()return 0 end,dmin=2.95,dmax=3.0,att=.22,rel=.9,
  glide=function(u,p,g)return contour(u)*(g<.34 and .5 or 1)end,
  vowel=path({{0,'a'},{.4,'a'},{.75,'o'},{1,'u'}},.78),env=swell(.06,.6,1),breath=1.4,bw1=170,bw2=210,bw3=280,vib=.03,tilt=1100},r)
 -- roughness: the roar's throat rattling
 local a=coef(34)
 for i=1,n do
  if i%1024==0 then spend(1024)end
  rv=rv+a*((r()*2-1)-rv)
  V1[i]=V1[i]*(1+2.2*rv)
 end
 return V1
end
-- TEST197, LANCE'S LAKE: a big blister bursting. A bubble's own "blop" (a
-- tone whose pitch shoots up as it closes, the sound a bubble makes), the
-- thud of it giving way, and the spatter of the droplets falling back
function S.gloop()
 local r=rng(2203);local len=1.0;local n=floor(len*SR)
 local out=zeros(n)
 local ph=0
 for i=1,floor(.16*SR)do
  if i%1024==0 then spend(1024)end
  local t=i/SR
  local f=150+430*(t/.16)^1.6
  ph=ph+f/SR;if ph>=1 then ph=ph-1 end
  out[i]=out[i]+sin(ph*TAU)*min(1,t/.006)*exp(-t*14)*1.0
 end
 thud(out,0,.8)
 -- a second, smaller blop just after (the crust sucking back)
 ph=0
 local i0=floor(.09*SR)
 for i=1,floor(.10*SR)do
  local t=i/SR;local f=240+520*(t/.10)^1.5
  ph=ph+f/SR;if ph>=1 then ph=ph-1 end
  out[i0+i]=out[i0+i]+sin(ph*TAU)*min(1,t/.005)*exp(-t*20)*.45
 end
 -- the spatter: drops landing, each a short click rung low
 local k=floor(.18*SR)
 while k<n do
  local f=600+900*r();local R=exp(-pi*380/SR);local c=2*R*cos(TAU*f/SR);local y1,y2=0,0
  local amp=(.4+.6*r())*exp(-(k/SR)*2.2)
  local m=floor(SR*.018);spend(m+8)
  for j=0,m-1 do
   local idx=k+j;if idx>n then break end
   local x=(j<floor(SR*.0012))and(r()*2-1)or 0
   local y=c*y1-R*R*y2+(1-R)*x;y2=y1;y1=y
   out[idx]=out[idx]+y*amp*5
  end
  k=k+1+floor(SR*(-log(1-r()*.999)/26))
 end
 return out
end
-- TEST197, LANCE'S LAKE: a spurt: the lava heaving up with a thick gurgle
-- (a rush through a throat that opens and closes, blops bubbling in it),
-- then raining back into the lake
function S.spurt()
 local r=rng(2309);local len=2.6;local n=floor(len*SR)
 local out=zeros(n)
 local l1,l2=0,0;local gate=0
 for i=1,n do
  if i%1024==0 then spend(3072)end
  local t=i/SR
  local fc=t<.25 and 220+700*(t/.25)or 380+540*exp(-(t-.25)*1.8)
  local a=coef(fc)
  local x=r()*2-1
  l1=l1+a*(x-l1);l2=l2+a*(l1-l2)
  local env=min(1,t/.05)*(t<1.0 and 1 or exp(-(t-1.0)*2.4))
  -- the gurgle: the throat opening and closing, ten or so times a second
  gate=.55+.45*sin(t*TAU*(9+3*sin(t*2.3)))
  out[i]=l2*env*gate*7
 end
 toRms(out,.16)
 local Bl=zeros(n)
 local t=.03
 while t<1.1 do
  local f0=170+260*r();local m=floor((.05+.06*r())*SR);local ph=0;local i0=floor(t*SR)
  spend(m)
  for j=1,m do
   local tt=j/SR;local f=f0*(1+2.2*tt/(m/SR))
   ph=ph+f/SR;if ph>=1 then ph=ph-1 end
   if i0+j<=n then Bl[i0+j]=Bl[i0+j]+sin(ph*TAU)*min(1,tt/.004)*exp(-tt*(4.5/(m/SR)))end
  end
  t=t+.04+r()*.07
 end
 toRms(Bl,.10);mixInto(out,Bl,1)
 -- falling back: a heavy rain of drops
 local k=floor(.9*SR)
 while k<n do
  local f=500+1000*r();local R=exp(-pi*420/SR);local c=2*R*cos(TAU*f/SR);local y1,y2=0,0
  local amp=(.3+.7*r())*min(1,(k/SR-.9)/.3)*exp(-max(0,k/SR-1.6)*2.5)
  local m=floor(SR*.016);spend(m+8)
  for j=0,m-1 do
   local idx=k+j;if idx>n then break end
   local x=(j<floor(SR*.0012))and(r()*2-1)or 0
   local y=c*y1-R*R*y2+(1-R)*x;y2=y1;y1=y
   out[idx]=out[idx]+y*amp*6
  end
  k=k+1+floor(SR*(-log(1-r()*.999)/60))
 end
 return out
end
-- THE CHAMPION: air horns, three blasts
function S.horn()
 local r=rng(1907);local len=2.3;local n=floor(len*SR)
 local out=zeros(n)
 local blasts={{0,.30},{.42,.30},{.84,1.25}}
 local fs={415,419,523}
 local l1,l2=0,0;local a=coef(2600)
 local ph={0,0,0}
 for i=1,n do
  if i%1024==0 then spend(4096)end
  local t=i/SR
  local amp=0
  for _,b in ipairs(blasts)do
   local u=t-b[1]
   if u>=0 and u<b[2]then amp=min(1,u/.012,(b[2]-u)/.04)end
  end
  local s=0
  if amp>0 then
   for k=1,3 do
    ph[k]=ph[k]+fs[k]*(1+.02*exp(-t*12))/SR;if ph[k]>=1 then ph[k]=ph[k]-1 end
    s=s+(ph[k]*2-1)
   end
  end
  s=s*amp*.6
  s=s/(1+abs(s))
  l1=l1+a*(s-l1);l2=l2+a*(l1-l2)
  out[i]=l2
 end
 return out
end
-- THE CHAMPION: the stadium's chant: clap clap, clap-clap-clap, "HEY!"
function S.chant()
 local r=rng(2003);local len=5.2;local n=floor(len*SR)
 local out=zeros(n)
 for _,t in ipairs(M.BEATS.chant)do clapAt(out,t,r,46,.035)end
 toRms(out,.17)
 local St=zeros(n)
 for _,t in ipairs({0,1.05,2.4,3.45})do thud(St,t,1)end
 toRms(St,.05);mixInto(out,St,1)
 for _,t in ipairs({1.85,4.27})do
  local m=floor(.55*SR)
  local sh=choir(m,{n=26,lo=110,hi=320,onset=function(v,r)return r()*.05 end,dmin=.28,dmax=.38,att=.02,rel=.14,
   glide=function(u,p)return 1.06-.12*p end,vowel=path({{0,'e'},{.5,'e'},{1,'i'}}),breath=.45},r)
  toRms(sh,.24)
  local i0=floor(t*SR)
  for j=1,m do if i0+j<=n then out[i0+j]=out[i0+j]+sh[j]end end;spend(m/6)
 end
 return out
end
-- THE CHAMPION: a brass fanfare, a timpani under the last chord
function S.fanfare()
 local r=rng(2111);local len=3.3;local n=floor(len*SR)
 local out=zeros(n)
 local notes={{0,392,.16,1},{.18,523.25,.16,1},{.36,659.25,.16,1},{.54,784,.42,1},{.98,659.25,.16,1},
  {1.16,784,1.95,1},{1.16,523.25,1.95,.55},{1.16,392,1.95,.5},{1.16,261.63,1.95,.45}}
 for _,nt in ipairs(notes)do
  local i0=floor(nt[1]*SR)+1;local m=floor(nt[3]*SR)
  local p1,p2,p3=r(),r(),r()
  local l1,l2=0,0
  for j=0,m-1 do
   local k=i0+j;if k>n then break end
   if j%1024==0 then spend(5120)end
   local t=j/SR
   local env=min(1,t/.025)*(1+.15*min(1,t/.3))*min(1,(nt[3]-t)/.08)
   local f=nt[2]*(1+.004*sin(t*TAU*5.5)*min(1,t/.3))
   p1=p1+f/SR;if p1>=1 then p1=p1-1 end
   p2=p2+f*1.004/SR;if p2>=1 then p2=p2-1 end
   p3=p3+f*.996/SR;if p3>=1 then p3=p3-1 end
   local s=(p1+p2+p3)*2-3
   local a=coef(300+2300*env^1.5)
   l1=l1+a*(s-l1);l2=l2+a*(l1-l2)
   out[k]=out[k]+l2*env*nt[4]*.3
  end
 end
 drum(out,1.16,98,.9,r,1.2)
 return out
end

-- {loudness (RMS)}: every sound levelled by how loud it IS, not its peak
M.LEVEL={cheer=.16,cheer2=.15,roar=.18,ooh=.14,aww=.14,wave=.14,applause=.13,whoop=.12,whistle=.10,
 bells=.12,chimes=.10,taiko=.18,gong=.15,moan=.13,toll=.15,pyro=.18,dragon=.17,horn=.15,chant=.16,fanfare=.16,
 gloop=.13,spurt=.15}
function M.synth(name)
 local f=S[name];if not f then return nil end
 return finish(f(),M.LEVEL[name]or .14)
end
M.S=S

------------------------------------------------------------------ the plan
-- which sounds a stadium needs, in the order they are built (the opening
-- call and the roar first, as the battle may well start before the rest)
local THEME={
 lorelei={start={'chimes','bells'},accent='chimes',chant='bells',finale={'bells','chimes'}},
 bruno={start={'gong'},accent='gong',chant='taiko',finale={'gong','taiko'}},
 agatha={start={'toll','moan'},accent='toll',chant='moan',finale={'toll','moan'}},
 lance={start={'dragon','pyro'},accent='pyro',chant='pyro',finale={'pyro','dragon'},extra={'gloop','spurt'}},
 champion={start={'horn','fanfare'},accent='horn',chant='chant',finale={'fanfare','horn','chant'}},
}
M.THEME=THEME
function M.plan(theme)
 local T=THEME[theme];if not T then return{}end
 local list,seen={},{}
 local function add(n)if n and not seen[n]then seen[n]=true;list[#list+1]=n end end
 add(T.start[1]);add('roar');add('cheer');add(T.start[2])
 -- (TEST197: the sounds of the stage itself: Lance's boiling lake)
 for _,n in ipairs(T.extra or{})do add(n)end
 add('applause');add(T.accent);add('ooh')
 add('whoop');add('wave');add(T.chant);add('whistle');add('cheer2')
 for _,n in ipairs(T.finale)do add(n)end
 add('aww')
 return list
end

------------------------------------------------------------------ runtime
local clock=(love and love.timer and love.timer.getTime)or os.clock
local sources={}       -- name -> Source
local built={}         -- name -> true | false (failed)
local builder=nil      -- {name,co}
local setTheme=nil     -- the theme whose set is (being) built
local complete=false   -- ...and it is all built
local queue={}         -- {t,name,vol,pitch,prio,fx}
local voices={}        -- {src,vol}
local lastFrame=-1e9   -- the last battle frame a stadium drew
local liveTheme=nil
local away=0           -- seconds since we were last in a stadium room
local remove=nil
-- what the stands see: excitement, flares, the beats of a chant
local ex,exT,exLen=0,-1e9,0
local fl,flT=0,-1e9
local beats={}         -- absolute times the whole house jumps
-- the battle being watched
local B={}
local marks=setmetatable({},{__mode='k'})
local subscribed=false
local busyUntil=0      -- a big sound is playing (the wave, a chant, a roar)
local nextWhoop,nextChant,lastCyc,lastRoar=0,0,nil,0

local function excite(level,len)
 local now=clock()
 local cur=M.excite(now)
 if level>=cur then ex,exT,exLen=level,now,len or 2 end
end
function M.excite(t)
 local age=t-exT
 if age<exLen then return ex end
 return max(0,ex*exp(-(age-exLen)*1.6))
end
local function flare(level)
 local now=clock()
 if level>=M.flare(now)then fl,flT=level,now end
end
function M.flare(t)
 local age=t-flT
 if age<0 then return 0 end
 return fl*exp(-age*1.5)
end
-- is the whole house up on a beat right now?
function M.onBeat(t)
 for i=#beats,1,-1 do
  local b=beats[i]
  if t>=b and t<b+.24 then return true end
  if t>b+1 then table.remove(beats,i)end
 end
 return false
end

-- the cue: a sound at now+delay; `fx` runs when it plays (or would have:
-- the stands still move if the sound is not built yet)
local BEAT_SOUNDS={taiko=M.BEATS.taiko,chant=M.BEATS.chant}
local FLARES={pyro=1,gong=1,toll=.9,chimes=.8,horn=.7,dragon=.8,fanfare=.6,bells=.5}
local function cue(name,delay,vol,pitch,prio)
 queue[#queue+1]={t=clock()+(delay or 0),name=name,vol=vol,pitch=pitch or 1,prio=prio}
end
local later={}         -- flares a sound schedules as it starts
local function fire(e,now)
 local bl=BEAT_SOUNDS[e.name]
 if bl then
  for _,b in ipairs(bl)do beats[#beats+1]=now+b/(e.pitch or 1)end
  if e.name=='taiko'then
   -- the drums flare on their own beats
   for _,b in ipairs(bl)do later[#later+1]={t=now+b,name='_flare',vol=.7}end
  end
 end
 if FLARES[e.name]then flare(FLARES[e.name])end
 if e.name=='_flare'then flare(e.vol)end
end

-- what the battle did, seen as the player sees it
local function theme()return liveTheme and THEME[liveTheme]end
local function event(kind,side,a,b)
 local T=theme();if not T then return end
 local now=clock()
 if kind=='start'then
  cue(T.start[1],.35,.50,1,true)
  if T.start[2]then cue(T.start[2],liveTheme=='champion'and 1.0 or 1.4,.42,1,true)end
  cue('roar',.6,.42,1,true)
  excite(1,4.5);busyUntil=now+6
  nextChant=now+14+math.random()*8
 elseif kind=='sendout'then
  if side=='enemy'then cue('cheer',0,.36,.96+.08*math.random(),true);excite(.75,2.4)
  else cue('cheer2',0,.28,1+.06*math.random(),true);excite(.5,1.6)end
 elseif kind=='move'then
  if math.random()<.35 then cue('ooh',.1,.22,.95+.1*math.random());excite(.25,1)end
 elseif kind=='hit'then
  local loss=a or .2;local m=b
  local big=loss>=.40 or(m and(m.crit or m.super))
  if big then
   cue('roar',0,.38,.97+.06*math.random(),true);cue(T.accent,.05,.30,1,true)
   excite(1,2.6);busyUntil=max(busyUntil,now+4)
  elseif loss>=.15 then
   cue('cheer',0,.32,.95+.1*math.random(),true);excite(.65,1.8)
  else
   cue('cheer2',0,.22,1+.08*math.random());excite(.4,1.2)
  end
 elseif kind=='heal'then
  cue('applause',0,.20,1);excite(.3,1.2)
 elseif kind=='faint'then
  if side=='enemy'then
   if B.pendingWin then
    B.pendingWin=nil;M._ovation()
   else
    cue('roar',0,.46,1,true);cue(T.accent,.1,.36,1,true);cue('applause',2.2,.26,1)
    excite(1,4);busyUntil=max(busyUntil,now+6)
   end
  else
   if B.pendingLose then B.pendingLose=nil;cue('aww',0,.40,1,true);cue('applause',1.6,.24,1);excite(.4,2)
   else cue('ooh',0,.34,.92,true);cue('applause',1.3,.24,1);excite(.5,2)end
  end
 end
end
function M._ovation()
 local T=theme();if not T then return end
 local now=clock()
 -- TEST218: and the sky goes up over the stadium (LeagueVictory)
 pcall(function()V.require('LeagueVictory').cheer(liveTheme)end)
 cue('roar',0,.52,1,true);cue('applause',.9,.40,1,true)
 cue(T.finale[1],.2,.46,1,true)
 if T.finale[2]then cue(T.finale[2],2.0,.40,1,true)end
 if T.finale[3]then cue(T.finale[3],4.2,.36,1,true)end
 cue('whistle',1.1,.16,1.05);cue('whoop',1.6,.18,1.1);cue('roar',4.6,.40,1.03,true)
 excite(1,9);busyUntil=now+10
end

local SIDES={'player','enemy'}
local function poll(now)
 local okO,OB=pcall(V.require,'OverworldBattle')
 local b=okO and OB and OB.battle and OB.battle()
 if type(b)~='table'then return end
 if B.battle~=b then
  B={battle=b,sides={},result=b.result,anim=b.animPlaying and true or false}
  event('start')
 end
 for _,side in ipairs(SIDES)do
  local bt=b[side]
  if type(bt)=='table'then
   local s=B.sides[side]
   if not s or s.ref~=bt then
    s={ref=bt,shown=tonumber(bt.shownHP),fainted=bt.fainted and true or false,grow=false};B.sides[side]=s
   end
   -- sent out: the pic starts growing in
   local grow=false
   if type(b.growInScale)=='function'then local okG,gv=pcall(b.growInScale,b,bt);grow=okG and gv~=nil and gv~=false end
   if grow and not s.grow then event('sendout',side)end
   s.grow=grow
   -- hit: the HP bar starts to fall (the moment the player sees it)
   local shown=tonumber(bt.shownHP)
   local mon=type(bt.mon)=='table'and bt.mon or nil
   local hp=mon and tonumber(mon.hp)
   local mx=mon and type(mon.stats)=='table'and tonumber(mon.stats.hp)
   if shown and s.shown then
    if shown<s.shown and not s.drain then
     s.drain=true
     local loss=(mx and mx>0 and hp)and max(0,s.shown-hp)/mx or .2
     local m=marks[bt]
     if m and now-m.t>8 then m=nil end
     marks[bt]=nil
     event('hit',side,loss,m)
    elseif shown>s.shown and not s.heal then
     s.heal=true;event('heal',side)
    end
   end
   if hp and shown==hp then s.drain=false;s.heal=false end
   s.shown=shown
   local fainted=bt.fainted and true or false
   if fainted and not s.fainted then event('faint',side)end
   s.fainted=fainted
  end
 end
 -- the result is decided before its faint is shown: hold it for the faint
 if b.result~=B.result then
  B.result=b.result
  if b.result=='win'then
   local s=B.sides.enemy
   if s and s.fainted then M._ovation()else B.pendingWin=now end
  elseif b.result=='lose'then
   local s=B.sides.player
   if s and s.fainted then cue('aww',0,.40,1,true)else B.pendingLose=now end
  end
 end
 if B.pendingWin and now-B.pendingWin>8 then B.pendingWin=nil;M._ovation()end
 if B.pendingLose and now-B.pendingLose>8 then B.pendingLose=nil;cue('aww',0,.40,1,true)end
 local anim=b.animPlaying and true or false
 if anim and not B.anim then event('move',b.animAttackerIsPlayer and'player'or'enemy')end
 B.anim=anim
end

-- critical and super-effective hits are only told as they are worked out;
-- they are kept for the moment the bar starts to fall
local function subscribe()
 if subscribed then return end
 subscribed=true
 local mod=V and V.mod
 local ev=mod and mod.events
 if not(ev and ev.on)then return end
 pcall(ev.on,ev,'battle.damage_dealt',function(e)
  pcall(function()
   if type(e)~='table'or type(e.target)~='table'then return end
   local mult=tonumber(e.typeMult)or 10
   if e.crit or mult>10 then marks[e.target]={t=clock(),crit=e.crit and true or false,super=mult>10}end
  end)
 end)
end

-- the stands between the big moments: the wave, the house roaring, a
-- whoop, the chant
local function ambient(now,t)
 local T=theme();if not T then return end
 local cyc=t%30
 if lastCyc and cyc<lastCyc and now>=busyUntil-3 then
  cue('wave',0,.26,1);busyUntil=max(busyUntil,now+8)
 end
 lastCyc=cyc
 local roar=max(0,sin(t*.37)*sin(t*.23+1.3))
 if roar>.62 and now>busyUntil and now-lastRoar>14 then
  lastRoar=now;cue('roar',0,.28,.98+.05*math.random());busyUntil=now+4.5
 end
 if now>nextWhoop then
  nextWhoop=now+1.8+math.random()*3.2
  if math.random()<.62 then cue('whoop',0,.07+.07*math.random(),.80+.5*math.random())
  else cue('whistle',0,.05+.05*math.random(),.9+.25*math.random())end
 end
 if nextChant==0 then nextChant=now+12+math.random()*8 end
 if now>nextChant and now>busyUntil and cyc<24 then
  nextChant=now+22+math.random()*14
  cue(T.chant,0,liveTheme=='lance'and .30 or .28,1)
  if T.chant=='chant'and math.random()<.6 then cue('horn',4.6,.22,1)end
  if T.chant=='moan'or T.chant=='bells'then excite(.45,3)end
  busyUntil=now+6
 end
end

-- every battle frame a stadium draws (LeagueStadium.draw, the colour pass)
function M.frame(r)
 local now=clock()
 local themeName=r and r.theme
 if not THEME[themeName or'']then return end
 if now-lastFrame>2 then
  -- a new stretch of battle frames: nothing carried over
  queue={};beats={};busyUntil=now+1;lastCyc=nil;nextWhoop=now+2;nextChant=0
 end
 lastFrame=now;liveTheme=themeName
 subscribe()
 local t=now
 pcall(poll,now)
 pcall(ambient,now,t)
end
function M.live()return clock()-lastFrame<.5 end
-- TEST197: a sound of the stage itself, now (LeagueStadium: Lance's lake
-- bursting and spurting); only while a stadium battle is being drawn
function M.sfx(name,vol,pitch)
 if M.live()and S[name]then cue(name,0,vol,pitch)end
end
-- the crowd bed rises and falls with the stands (LeagueRoomFx's ambience)
function M.bed(t)
 t=t or clock()
 local roar=max(0,sin(t*.37)*sin(t*.23+1.3))
 return .80+.45*roar+.35*M.excite(t)
end

-- building: one slice a frame, in our own coroutine
local function nextToBuild(themeName)
 for _,name in ipairs(M.plan(themeName))do
  if built[name]==nil then return name end
 end
 return nil
end
local function release()
 if builder and builder.data then pcall(builder.data.release,builder.data);builder.data=nil end
 for _,v in ipairs(voices)do pcall(v.src.stop,v.src);pcall(v.src.release,v.src)end
 for _,s in pairs(sources)do pcall(s.release,s)end
 sources,built,voices,queue,builder,setTheme,BUILDER={},{},{},{},nil,nil,nil
 complete=false
end
local function buildSlice(themeName)
 if setTheme~=themeName then release();setTheme=themeName end
 if complete then return false end
 if not builder then
  local name=nextToBuild(themeName);if not name then complete=true;return false end
  local co
  co=coroutine.create(function()
   local buf=M.synth(name)
   local sd=love.sound.newSoundData(#buf,SR,16,1)
   builder.data=sd -- owned across yields, failures and cancellation
   for i=1,#buf do
    sd:setSample(i-1,buf[i])
    if i%1000==0 and pace()>deadline then coroutine.yield()end
   end
   local src=love.audio.newSource(sd,'static')
   pcall(sd.release,sd);builder.data=nil
   return src
  end)
  builder={name=name,co=co}
 end
 BUILDER=builder.co;work=0;deadline=pace()+(M.live()and M.BUDGET_BATTLE or M.BUDGET)
 local ok,res=coroutine.resume(builder.co)
 BUILDER=nil;deadline=math.huge
 if not ok then
  if builder.data then pcall(builder.data.release,builder.data);builder.data=nil end
  built[builder.name]=false;builder=nil;return true
 end
 if coroutine.status(builder.co)=='dead'then
  sources[builder.name]=res;built[builder.name]=true;builder=nil
 end
 return true
end

-- (the same rooms as LeagueStadium.ROOMS: checked here first, so nothing
-- is required anywhere else in the game)
local ROOMS={LORELEIS_ROOM='lorelei',BRUNOS_ROOM='bruno',AGATHAS_ROOM='agatha',LANCES_ROOM='lance',CHAMPIONS_ROOM='champion'}
M.ROOMS=ROOMS
local function stadiumRoom(game)
 local map=game and game.overworld and game.overworld.map
 local id=map and map.id
 local th=id and ROOMS[tostring(id)]
 if not th then return nil end
 local okS,St=pcall(V.require,'LeagueStadium')
 if not(okS and type(St)=='table')then return nil end
 -- after the stadium itself has been built (or while its battle is on)
 local ready=St.ready and St.ready(tostring(id))
 if ready==false then return nil end
 if ready==nil and not M.live()then return nil end
 return th
end

-- every frame (LeagueAmbience's update): build, then play what falls due
function M.update(game,dt,gain,busy)
 local now=clock()
 local live=now-lastFrame<.5
 local th=stadiumRoom(game)or(live and liveTheme)or nil
 if th then
  away=0
  buildSlice(th)
 else
  away=away+max(0,min(.1,tonumber(dt)or 0))
  if away>20 and(next(sources)or builder)then release()end
 end
 -- voices that finished go back; out of battle, they fade
 for i=#voices,1,-1 do
  local v=voices[i];local ok,on=pcall(v.src.isPlaying,v.src)
  if not(ok and on)then pcall(v.src.release,v.src);table.remove(voices,i)
  elseif not live then
   v.vol=v.vol-max(0,min(.1,tonumber(dt)or 0))*1.6
   if v.vol<=0 then pcall(v.src.stop,v.src);pcall(v.src.release,v.src);table.remove(voices,i)
   else pcall(v.src.setVolume,v.src,v.vol)end
  end
 end
 if not live then if #queue>0 then queue={}end;return end
 local g=max(0,min(1,tonumber(gain)or 1))
 local keep={}
 for _,e in ipairs(queue)do
  if e.t<=now then
   if e.name=='_flare'then fire(e,now)
   else
    local src=sources[e.name]
    -- an important cue waits a moment for its sound to finish building
    if not src and built[e.name]==nil and e.prio and now-e.t<2.5 then keep[#keep+1]=e
    else
     fire(e,now)
     if src and g>0 and now-e.t<(e.prio and 2.5 or .4)then
      if #voices>=7 and not e.prio then
       -- full: drop the small stuff
      else
       if #voices>=7 then local v=table.remove(voices,1);pcall(v.src.stop,v.src);pcall(v.src.release,v.src)end
       local ok,v=pcall(src.clone,src)
       if ok and v then
        local vol=min(1,e.vol*g)
        pcall(v.setVolume,v,vol);pcall(v.setPitch,v,e.pitch or 1);pcall(v.play,v)
        voices[#voices+1]={src=v,vol=vol}
       end
      end
     end
    end
   end
  else keep[#keep+1]=e end
 end
 for i=1,#later do keep[#keep+1]=later[i];later[i]=nil end
 queue=keep
end

-- (tests) is the current set built?
function M._done()return setTheme~=nil and builder==nil and nextToBuild(setTheme)==nil end
M._complete=function()return complete end
function M.dispose()
 release()
 lastFrame,liveTheme=-1e9,nil
 B={}
end
return M
