-- TEST223: THE DRAGON'S DEN. The journey to Lance, made an event:
--
--   * the walk in (the game walks you from the stair to the gate on its own)
--     is filmed: the temple revealed across the lava sea under a lightning
--     strike; a tracking shot over the abyss; the corridor of fire columns,
--     each one roaring up as you pass; then in through the LANCE gate, which
--     slams shut behind you
--   * then the dragons wake: pair by pair, from the gate to Lance, their
--     eyes ignite and they breathe fire over the road, the great dragon over
--     the far gate last -- "ELITE FOUR / LANCE / THE DRAGON MASTER"
--   * the last stretch is yours: the fire columns and the dragons' eyes
--     burn, and each pair breathes an arch of fire over you as you pass;
--     the dragon seal before Lance ignites as you step near
--   * when Lance sees you: thunder, the seal blazing, and the camera films
--     the face-off for as long as he talks
--   * letterbox bars while the camera is filmed; HOLD A to skip the film
--     (the effects stay); after Lance is beaten none of it plays again
--
-- TEST224, from Joseph's recordings:
--   * The FIRE is new. TEST223's breath was a chain of small crossed sprites
--     (it read as dotted streaks) under big orange glows (the whole wake went
--     orange). Now each breath is a cone of real flame: hundreds of
--     camera-facing puffs from one fire texture (assets/lance/fire_atlas.png)
--     that swell, slow, rise and cool from white-hot through gold and orange
--     to red as they fly, with dark smoke rolling off the end and sparks
--     thrown out of it; the glows are much smaller and dimmer.
--   * The FACE-OFF holds through Lance's whole speech: it was capped at 7
--     seconds, so a speech read at your own pace went back to the walking
--     camera. It now ends only when the battle comes (or the speech closes
--     without one), and cuts between four shots while he talks: over his
--     shoulder at you, Lance from below with the blazing gate behind him,
--     over your shoulder at him, and a wide shot of the two of you in the
--     hall of fire. The bars are thinner while a text box is up.
--   * As the battle starts, every dragon breathes at once, with a roar.
--   * The HAND-BACK after the wake no longer cuts to wherever your camera
--     last pointed (in the recording it faced the shut gate): the camera now
--     turns to look up the hall toward Lance and glides from the film into
--     your own camera.
--
-- TEST225: THE HAND-BACK, AGAIN. Where the wake ends you stand just inside
-- the gate, the shut gate at your back, so a third-person camera has no
-- room behind you: it was pressed into your head, and the glide into it
-- went in through your hat (and your partner's face filled the screen).
-- Now, in third person, the film hands over to a view from just over your
-- head, looking up the hall to Lance (it follows you), and once you have
-- walked out far enough for your own camera to stand behind you, it glides
-- into that. In first person the glide goes straight to your eyes, over
-- you rather than through you. Your camera's tilt is levelled too.
--
-- TEST229: THE WALK, FILMED THROUGH. From Joseph's recording: the camera
-- went through pillars and a statue on the way in (the glides between the
-- legs' cameras, and two cameras set too low), after the title you were out
-- of the picture for seconds (the view over your head) and then behind your
-- partner, and two face-off shots had your head in the way. Now:
--   * each leg of the walk in is a cut, not a glide; the abyss is filmed
--     from higher, the corridor from ahead of you on the hall side (from
--     over the lava its fire columns stood between you and the lens)
--   * after the wake a crane takes you up the hall to Lance (SHOT.follow):
--     high just inside the gate, then down behind you as you walk, you, the
--     dragons' fire and Lance always in the picture; it holds until Lance
--     sees you, your own camera kept facing up the hall meanwhile
--   * the face-off's over-the-shoulder and wide shots are placed so that
--     you are never in front of Lance and your head is never at the lens
--   * the woken dragons' eyes light the floor beneath them a little
-- Every placement was checked against the room's own geometry (dumped from
-- LeagueRooms) at every step: you seen, the lens clear of every surface,
-- nothing big right in front of it.
--
-- TEST231: YOUR PARTNER, WHOLLY IN THE PICTURE OR WHOLLY OUT OF IT. In
-- Joseph's recording your partner's head bobbed half-cut along the bottom
-- edge all the way up the hall (the crane), it was cut by the bottom edge
-- through the dens, and in the face-off it stood sliced at the edge of the
-- wide shot (a dragon statue across the other side) while the
-- over-your-shoulder shot cut your own head. Now your partner counts as a
-- solid figure (10 tall, 7 across) wherever it can stand -- a step behind
-- you, or beside you after a sidestep -- and the bars are counted as edges:
--   * the crane rides higher and further back (from 100 over the gate down
--     to 44 high, 56 behind you; was 88 -> 34 high, 46 behind), wider
--     (64 -> 56 degrees), with you lower in the picture (place .30 -> .20)
--   * the dens are filmed from further back (80, was 64) and aimed lower
--   * each face-off shot (over Lance's shoulder, Lance from below, over
--     yours, the wide shot, the send-off) has a short list of checked
--     places; once, as it comes up, the first that shows your partner
--     wholly (not huge, hiding nobody, not more than a third of it behind
--     you or Lance) or leaves it wholly out -- from anywhere the hand-held
--     lens wanders while it holds -- is taken (Room:pickEye; the log says
--     which). If none does, or nobody is with you, its first place, as before.
--
-- TEST232: EVERY SCREEN SHAPE. TEST231's places were checked on a 16:9
-- picture only. On a phone (18:9 to 21:9) Lance's close-up sliced your
-- partner at its left edge when it stood west of you, and the wide shot
-- opened with a dragon statue's flank down its left side; on a narrow window
-- (4:3, 10:9) the over-your-shoulder shot cut your own head. And the wide
-- place taken when your partner stands west of you crept into the west
-- statue at any shape. Now:
--   * the pick measures the picture the 3D pass really draws (its view
--     size, from FirstPerson.frame), not the window
--   * a place can carry the screen shapes it was checked for (amin/amax,
--     width over height) and its own creep (k); each place was checked
--     against the room (lens clear, no statue across the foreground, your
--     head wholly in or out over your shoulder) over the WHOLE creep, at
--     every shape from 10:9 to 2.4:1
--   * new places, so that at every shape some place frames each partner cell
--     (or leaves it wholly out): Lance from the south-west, two
--     over-your-shoulder places that keep your head in at 4:3 and 10:9, the
--     wide shot from higher and further back with a short creep (it replaces
--     {56,50,70}), a send-off place for the widest phones, and over his
--     shoulder at 10:9
--   * at 16:9 every pick is TEST231's, except the wide shot with your partner
--     west of you (the statue)
--   * if no place frames your partner, one that does not slice it at an
--     edge is preferred; the log names the follower that failed
--
-- How it fits: Lance's room script (data/scripts/story4.lua) walks you in
-- with ow:scriptMove and locks the gate with EVENT_LANCES_ROOM_LOCK_DOOR;
-- this watches those (it never moves you itself, only paces the walk a
-- little slower through 'movement.speed'). The camera is placed through
-- FirstPerson.frame (as the 3D Hall of Fame does), the effects drawn after
-- the room's own (a LeagueRoomFx.draw wrap), the bars and title in the HUD
-- pass. Installed from LeagueFireworksAudio.install.
local V=...
local M={REVISION='lance-approach-232'}
local floor,max,min,abs,sin,cos,sqrt,pi,rad,exp=math.floor,math.max,math.min,math.abs,math.sin,math.cos,math.sqrt,math.pi,math.rad,math.exp

M.ROOM='LANCES_ROOM'
M.ASSETS='assets/lance/'
M.WALK_SCALE=1.35         -- the walk in, a stately pace (16 -> 22 frames a step)
M.T={wave=4.8,waveGap=.42,breath=2.1,flare=1.6,title=1.3,titleHold=2.6,
 letterIn=.6,letterOut=.7,skipHold=1.0,s1=3.0,blend=1.2,handback=1.4,
 faceoffMax=180,quiet=.7,sendoff=2.2,followBlend=0}
M.BARS_FOLLOW=.5          -- (TEST229) the bars while the crane follows you: half
-- the face-off's shots while Lance talks: the first plays once, then the
-- other three take turns
M.FACEOFF={{'faceoffYou',3.6},{'faceoffLance',4.8},{'faceoffOver',4.6},{'faceoffWide',4.6}}
M.HALL_X=96               -- the hall's axis
M.SEAL={96,40}            -- the dragon seal before Lance
M.LANCE={104,24}          -- where he stands (cell 6,1)
M.GATE={96,200}           -- the lock gate's arch
M.BARS=.11                -- the film's bars (a fraction of the screen each)
M.BARS_TALK=.055          -- thinner while a text box is up

local active=nil          -- the room's state while you are in it
local lastRig=nil
local modRef=nil

local function now()local ok,t=pcall(love.timer.getTime);return ok and t or 0 end
local function smooth(u)u=max(0,min(1,u));return u*u*(3-2*u)end
local function lerp(a,b,u)return a+(b-a)*u end
local function lerp3(a,b,u)return{lerp(a[1],b[1],u),lerp(a[2],b[2],u),lerp(a[3],b[3],u)}end
local function rh(a,b,s)local v=sin(a*12.9898+b*78.233+s*37.719)*43758.5453;return v-floor(v)end
local function log(fmt,...)
 local args={...}
 pcall(function()require('src.core.Logger').warn('[LanceApproach] '..fmt,unpack(args))end)
end

------------------------------------------------------------------ sound
local SFX={}
local function loadSource(name)
 local ok,bytes=pcall(function()return V.mod:read(M.ASSETS..name)end)
 if ok and type(bytes)=='string'and #bytes>0 then
  local ok2,src=pcall(function()return love.audio.newSource(love.filesystem.newFileData(bytes,name),'static')end)
  if ok2 and src then return src end
 end
 local ok3,src=pcall(love.audio.newSource,(V.path or'mods/BATTLE_ART_VOXEL_FORK')..'/'..M.ASSETS..name,'static')
 return ok3 and src or nil
end
local function sfx(name)
 if SFX[name]==nil then SFX[name]=loadSource(name..'.ogg')or false end
 return SFX[name]or nil
end
local voices={}
local function sfxGain(game)
 local o=game and game.save and game.save.options
 return max(0,min(7,tonumber(o and o.sfxVol)or 7))/7
end
local queue={}
-- play a sound now, or `delay` seconds from now
local function play(game,name,vol,pitch,delay)
 queue[#queue+1]={t=now()+(delay or 0),name=name,vol=vol or 1,pitch=pitch or 1,game=game}
end
local function pumpSound()
 local t=now()
 for i=#voices,1,-1 do
  local v=voices[i];local ok,on=pcall(v.isPlaying,v)
  if not(ok and on)then pcall(v.release,v);table.remove(voices,i)end
 end
 local keep={}
 for _,e in ipairs(queue)do
  if e.t<=t then
   local src=sfx(e.name)
   local g=sfxGain(e.game)
   if src and g>0 and #voices<14 then
    local ok,v=pcall(src.clone,src)
    if ok and v then
     pcall(v.setVolume,v,min(1,e.vol*g));pcall(v.setPitch,v,e.pitch);pcall(v.play,v)
     voices[#voices+1]=v
    end
   end
  else keep[#keep+1]=e end
 end
 queue=keep
end

------------------------------------------------------------------ fonts
local fonts={}
local function fontFile(name,size)
 local key=name..size
 if fonts[key]==nil then
  local f=false
  pcall(function()
   for _,dir in ipairs({M.ASSETS,'assets/parade/'})do
    if not f then
     local bytes=V.mod:read(dir..name)
     if type(bytes)=='string'and #bytes>0 then f=love.graphics.newFont(love.filesystem.newFileData(bytes,name),size)end
    end
   end
  end)
  if not f then local ok,d=pcall(love.graphics.newFont,size);f=ok and d or false end
  fonts[key]=f
 end
 return fonts[key]or nil
end
local function bigFont(s)return fontFile('Caladea-Bold.ttf',max(8,floor(s)))end
local function smallFont(s)return fontFile('Poppins-Medium.ttf',max(8,floor(s)))end
local function spacedWidth(f,text,sp)local w=0;for i=1,#text do w=w+f:getWidth(text:sub(i,i))+sp end;return w-sp end
local function printSpaced(g,f,text,x,y,sp)for i=1,#text do local c=text:sub(i,i);g.print(c,x,y);x=x+f:getWidth(c)+sp end end

------------------------------------------------------------------ the room's features
-- the statues (from the room's own eye glows), the fire columns, in order
local function features(map)
 local okR,Rooms=pcall(V.require,'LeagueRooms')
 if not okR then return nil end
 local fx=Rooms.fx(map)
 if not fx then return nil end
 local dragons,columns={},{}
 for _,g in ipairs(fx.glows or{})do
  -- the eyes are the small red glows; the statues in the hall and at the
  -- gate (the lost shrine's, far east, take no part)
  if g.col=='red'and(g.r or 99)<6 and g.x<250 then
   local face=(g.x<M.HALL_X)and 1 or-1
   local isHead=g.z<5 and abs(g.x-M.HALL_X)<4   -- the great head over the far gate
   dragons[#dragons+1]={x=g.x,y=g.y,z=g.z,face=face,big=(g.r or 0)>5,head=isHead}
  end
 end
 for _,f in ipairs(fx.fires or{})do
  if abs((f.s or 0)-1.1)<.01 and not f.batch then columns[#columns+1]={x=f.x,y=f.y,z=f.z}end
 end
 table.sort(dragons,function(a,b)return a.z>b.z end)
 return{dragons=dragons,columns=columns,fx=fx}
end

------------------------------------------------------------------ the fire
-- One texture, assets/lance/fire_atlas.png: 8 x 4 cells of 64 px. Rows 0-2
-- are puffs of flame, white-hot to gold to red (their colour is in the
-- texture, so one draw holds every heat); row 3 holds smoke (cells 24-28),
-- a spark (29), a glow (30) and an ember streak (31).
local ATLAS_W,ATLAS_H=512,256
local CELL_SMOKE,CELL_SPARK,CELL_GLOW,CELL_STREAK=24,29,30,31
local atlasImg=nil
-- a plainer stand-in, drawn here, if the picture cannot be read
local function builtAtlas()
 local d=love.image.newImageData(ATLAS_W,ATLAS_H)
 local hot={{1,.97,.88},{1,.80,.40},{.95,.45,.12}}
 local rim={{1,.82,.45},{1,.50,.14},{.62,.13,.04}}
 d:mapPixel(function(x,y)
  local col,row=floor(x/64),floor(y/64)
  local u,v=(x%64+.5)/32-1,(y%64+.5)/32-1
  local r=sqrt(u*u+v*v)
  if row<3 then
   local k=max(0,1-r/.95)^(1.1+.3*row)*(.85+.15*sin(col*3.1+u*5+v*4))
   local h,c=hot[row+1],rim[row+1]
   local m=k^.7
   return c[1]+(h[1]-c[1])*m,c[2]+(h[2]-c[2])*m,c[3]+(h[3]-c[3])*m,min(1,k*1.1)
  end
  if col<5 then local k=max(0,1-r)^1.3*.8;return .14,.12,.11,k end
  if col==5 then local k=max(0,1-r/.18)+exp(-(r/.38)^2)*.5;return 1,.85,.6,min(1,k)end
  if col==6 then local k=exp(-(r/.55)^2);return 1,.75,.45,k end
  local k=exp(-(u/.1)^2)*max(0,1-abs(v)/.92)^1.5;return 1,.85,.55,k
 end)
 return d
end
local function atlas()
 if atlasImg==nil then
  local img=false
  pcall(function()
   local bytes=V.mod:read(M.ASSETS..'fire_atlas.png')
   if type(bytes)=='string'and #bytes>0 then
    local data=love.image.newImageData(love.filesystem.newFileData(bytes,'fire_atlas.png'))
    img=love.graphics.newImage(data,{mipmaps=false})
   end
  end)
  if not img then pcall(function()img=love.graphics.newImage(builtAtlas(),{mipmaps=false})end)end
  if img then pcall(img.setFilter,img,'linear','linear');pcall(img.setWrap,img,'clamp','clamp')end
  atlasImg=img
 end
 return atlasImg or nil
end
M.atlas=atlas

-- The particle buffers, one mesh each, rewritten each frame, one draw each:
--   smoke  dark, laid over (two strengths)
--   body   the flame itself, laid over: gold to orange to red, so a crowd of
--          puffs builds a solid flame instead of adding up to white (four
--          strengths, by age)
--   core   the young flame's heat, adding light: white-gold, smaller (two)
--   spark  sparks and embers, adding light
M.SMOKE={.55,.28}
M.BODY={.66,.48,.30,.13}
M.CORE={.50,.26}
M.SPARK={1.0}
local CAPS={smoke={200,160},body={560,300,260,260},core={420,200},spark={260}}
local bufs=nil
local function newBuffer(n)
 local R=V.require('Voxel3D')
 local verts={}
 for i=1,n*4 do verts[i]={0,-9999,0,0,0,1}end
 local ok,m=pcall(love.graphics.newMesh,R.FORMAT,verts,'triangles','stream')
 if not(ok and m)then return nil end
 local idx={};for q=0,n-1 do R.pushQuad(idx,q)end
 pcall(m.setVertexMap,m,idx)
 return{mesh=m,verts=verts,n=n,used=0,prev=0}
end
local function buffers()
 if bufs==nil then
  bufs={}
  for name,caps in pairs(CAPS)do
   bufs[name]={}
   for i,n in ipairs(caps)do bufs[name][i]=newBuffer(n)or false end
  end
 end
 return bufs
end
-- the camera's own right and up, so every puff faces the lens
local RX,RY,RZ,UX,UY,UZ=1,0,0,0,1,0
local function basis(eye,focus)
 local fx,fy,fz=focus[1]-eye[1],focus[2]-eye[2],focus[3]-eye[3]
 local l=sqrt(fx*fx+fy*fy+fz*fz);if l<1e-6 then return end
 fx,fy,fz=fx/l,fy/l,fz/l
 -- right = forward x up(0,1,0); up = right x forward
 local rx,ry,rz=-fz,0,fx
 local rl=sqrt(rx*rx+rz*rz);if rl<1e-6 then rx,ry,rz,rl=1,0,0,1 end
 rx,rz=rx/rl,rz/rl
 RX,RY,RZ=rx,ry,rz
 UX,UY,UZ=ry*fz-rz*fy,rz*fx-rx*fz,rx*fy-ry*fx
end
M._basis=function()return RX,RY,RZ,UX,UY,UZ end
local IU,IV=.5/ATLAS_W,.5/ATLAS_H
-- one puff: centre, half-size, spin, atlas cell
local function put(b,x,y,z,s,rot,cell)
 if not b then return end
 local i=b.used
 if i>=b.n then return end
 b.used=i+1
 local c,sn=cos(rot),sin(rot)
 local ax,ay,az=(RX*c+UX*sn)*s,(RY*c+UY*sn)*s,(RZ*c+UZ*sn)*s
 local bx,by,bz=(UX*c-RX*sn)*s,(UY*c-RY*sn)*s,(UZ*c-RZ*sn)*s
 local col=cell%8;local row=(cell-col)/8
 local u0,v0=col/8+IU,row/4+IV
 local u1,v1=(col+1)/8-IU,(row+1)/4-IV
 local v=b.verts;local k=i*4
 local e=v[k+1];e[1],e[2],e[3],e[4],e[5]=x-ax-bx,y-ay-by,z-az-bz,u0,v1
 e=v[k+2];e[1],e[2],e[3],e[4],e[5]=x+ax-bx,y+ay-by,z+az-bz,u1,v1
 e=v[k+3];e[1],e[2],e[3],e[4],e[5]=x+ax+bx,y+ay+by,z+az+bz,u1,v0
 e=v[k+4];e[1],e[2],e[3],e[4],e[5]=x-ax+bx,y-ay+by,z-az+bz,u0,v0
end
M._put=put
-- after filling: hide what this frame did not use, hand the mesh its verts
local function finish(b)
 if not b then return false end
 local v=b.verts
 for i=b.used,b.prev-1 do
  local k=i*4
  for j=1,4 do local e=v[k+j];e[1],e[2],e[3]=0,-9999,0 end
 end
 local touched=b.used>0 or b.prev>0
 b.prev=b.used
 if touched then pcall(b.mesh.setVertices,b.mesh,v)end
 return b.used>0
end

------------------------------------------------------------------ emitters
-- Particles are worked out from their emitter and their index (no state
-- per particle). An emitter is a breath (a cone of fire from a mouth, or a
-- column's flare straight up), the seal's ring, or the slam's sparks and dust.
local function newEmitters()return{}end
local function emit(list,e)
 -- two directions square to the jet's own, for its spread
 if e.dx then
  local ax,ay,az=0,1,0
  if abs(e.dy or 0)>.9 then ax,ay,az=1,0,0 end
  local dx,dy,dz=e.dx,e.dy,e.dz
  local p1x,p1y,p1z=dy*az-dz*ay,dz*ax-dx*az,dx*ay-dy*ax
  local l=sqrt(p1x*p1x+p1y*p1y+p1z*p1z);p1x,p1y,p1z=p1x/l,p1y/l,p1z/l
  local p2x,p2y,p2z=dy*p1z-dz*p1y,dz*p1x-dx*p1z,dx*p1y-dy*p1x
  e.p1={p1x,p1y,p1z};e.p2={p2x,p2y,p2z}
 end
 list[#list+1]=e
 return e
end
-- how strongly a puff is drawn, by its age
local function strength(u,a)
 if a<.05 then return 2 end
 if u<.55 then return 1 elseif u<.72 then return 2 elseif u<.86 then return 3 end
 return 4
end
-- a puff of flame: its body, laid over; while it is young, its heat added
local function flame(B,x,y,z,s,rot,u,a,j,hot,mid,variant)
 local row=u<mid+j and 1 or 2
 put(B.body[strength(u,a)],x,y,z,s,rot,row*8+variant)
 if u<mid*.8 then
  local hotRow=u<hot+j and 0 or 1
  put(B.core[u<hot and 1 or 2],x,y,z,s*.62,rot+1.3,hotRow*8+(variant+3)%8)
 end
end
-- a cone of flame: born at the mouth, flung along its direction and slowed
-- (drag), lifted by its own heat, swelling and cooling, curling; smoke off
-- its end; sparks thrown out of it
local function jet(e,age,B)
 local S=B.smoke
 local reach=e.speed*e.tau
 local n0=max(0,floor((age-e.life)*e.rate))
 local n1=floor(min(age,e.dur)*e.rate)
 local d1,d2=e.p1,e.p2
 for k=n0,n1 do
  local a=age-k/e.rate
  if a>=0 and a<e.life then
   local u=a/e.life
   local h1,h2,h3,h4,h5=rh(k,e.seed,1),rh(k,e.seed,2),rh(k,e.seed,3),rh(k,e.seed,4),rh(k,e.seed,5)
   local dist=reach*(1-exp(-a/e.tau))
   -- a disc of spread, wider as it goes
   local ang=h1*6.2832;local rr=sqrt(h2)*e.spread*dist
   local l1,l2=cos(ang)*rr,sin(ang)*rr
   local tb=e.turb*u
   local x=e.x+e.dx*dist+d1[1]*l1+d2[1]*l2+sin(a*9.1+k*1.7)*tb
   local y=e.y+e.dy*dist+d1[2]*l1+d2[2]*l2+e.lift*a*a+sin(a*11.3+k)*tb*.5
   local z=e.z+e.dz*dist+d1[3]*l1+d2[3]*l2+cos(a*8.3+k*2.3)*tb
   local s=(e.size0+(e.size1-e.size0)*u^.65)*(.8+.4*h3)
   flame(B,x,y,z,s,h5*6.2832+a*(h3-.5)*3,u,a,(h4-.5)*.12,e.hot,e.mid,floor(h4*7.99))
  end
 end
 -- smoke rolling off the end and climbing
 if e.smoke and e.smoke>0 then
  local life=1.7
  local s0=max(0,floor((age-life)*e.smoke))
  local s1=floor(min(age,e.dur+.2)*e.smoke)
  for k=s0,s1 do
   local a=age-k/e.smoke
   if a>=0 and a<life then
    local u=a/life
    local h1,h2,h3=rh(k,e.seed,11),rh(k,e.seed,12),rh(k,e.seed,13)
    local dist=reach*(.65+.3*h1)
    local x=e.x+e.dx*dist+(h2-.5)*10+sin(a*1.3+k)*3*u
    local y=e.y+e.dy*dist+6+a*14+a*a*3
    local z=e.z+e.dz*dist+(h3-.5)*10+cos(a*1.1+k)*3*u
    local s=(e.size1*.55+e.size1*.9*u)*(.85+.3*h3)
    local fade=u<.15 and 2 or(u<.6 and 1 or 2)
    put(S[fade],x,y,z,s,h1*6.28+a*.4,CELL_SMOKE+floor(h2*4.99))
   end
  end
 end
 -- sparks thrown out of it
 if e.sparks and e.sparks>0 then
  local life=1.25
  local s0=max(0,floor((age-life)*e.sparks))
  local s1=floor(min(age,e.dur)*e.sparks)
  for k=s0,s1 do
   local a=age-k/e.sparks
   if a>=0 and a<life then
    local u=a/life
    local h1,h2,h3,h4=rh(k,e.seed,21),rh(k,e.seed,22),rh(k,e.seed,23),rh(k,e.seed,24)
    local dist=reach*(.25+.6*h1)
    local ang=h2*6.2832
    local out=12+18*h3
    local x=e.x+e.dx*dist+(d1[1]*cos(ang)+d2[1]*sin(ang))*out*a
    local y=e.y+e.dy*dist+(d1[2]*cos(ang)+d2[2]*sin(ang))*out*a+16*a-14*a*a
    local z=e.z+e.dz*dist+(d1[3]*cos(ang)+d2[3]*sin(ang))*out*a
    put(B.spark[1],x,y,z,(.55+.45*h4)*(1-.5*u),h1*6.28,CELL_SPARK)
   end
  end
 end
end
local function ring(e,age,B)
 local n0=max(0,floor((age-e.life)*e.rate))
 local n1=floor(min(age,e.dur)*e.rate)
 for k=n0,n1 do
  local a=age-k/e.rate
  if a>=0 and a<e.life then
   local u=a/e.life
   local h1,h2,h3,h4=rh(k,e.seed,1),rh(k,e.seed,2),rh(k,e.seed,3),rh(k,e.seed,4)
   local ang=(k*2.39996+e.seed)%(pi*2)
   local r=e.r*(.92+.16*h1)
   local x=e.x+cos(ang)*r+sin(a*7+k)*1.2*u
   local z=e.z+sin(ang)*r+cos(a*6+k)*1.2*u
   local y=e.y+a*e.speed+a*a*8
   local s=(e.size0+(e.size1-e.size0)*u^.7)*(.8+.4*h2)
   flame(B,x,y,z,s,h3*6.28+a,u,a,(h4-.5)*.1,.2,.55,floor(h4*7.99))
  end
 end
end
local function burst(e,age,B)
 local S=B.smoke
 local n=floor(e.count)
 local a=age
 if a<0 or a>=e.life then return end
 local u=a/e.life
 for k=0,n-1 do
  local h1,h2,h3=rh(k,e.seed,1),rh(k,e.seed,2),rh(k,e.seed,3)
  local ang=h1*6.2832
  local sp=e.speed*(.4+.9*h2)
  local x=e.x+cos(ang)*sp*a*(1-.35*u)
  local z=e.z+sin(ang)*sp*a*(1-.35*u)*.6
  if k%3==0 then
   -- dust, low and spreading
   put(S[u<.5 and 1 or 2],x,e.y+2+a*6,z,(3+9*u)*(.8+.4*h3),h3*6.28,CELL_SMOKE+k%5)
  else
   local y=e.y+(10+22*h3)*a-26*a*a
   if y>0 then put(B.spark[1],x,y,z,(.6+.5*h3)*(1-.5*u),h1*6.28,CELL_SPARK)end
  end
 end
end
local KINDS={jet=jet,ring=ring,burst=burst}
-- fill this frame's buffers from every emitter still burning
local ORDER={'smoke','body','core','spark'}
local function fillFire(list,t,eye,focus)
 local B=buffers()
 if not B then return nil end
 for _,name in ipairs(ORDER)do for _,b in ipairs(B[name])do if b then b.used=0 end end end
 if eye and focus then basis(eye,focus)end
 local keep={}
 for _,e in ipairs(list)do
  local age=t-e.t0
  local tail=e.kind=='jet'and 1.9 or 0
  if age<e.dur+e.life+tail then
   keep[#keep+1]=e
   if age>=0 then
    local f=KINDS[e.kind]
    if f then f(e,age,B)end
   end
  end
 end
 for i=#list,1,-1 do list[i]=nil end
 for i,e in ipairs(keep)do list[i]=e end
 for _,name in ipairs(ORDER)do for _,b in ipairs(B[name])do finish(b)end end
 return B
end
M._fill=fillFire

------------------------------------------------------------------ the room state
local Room={};Room.__index=Room
function Room.new(game,map)
 local F=features(map)
 local self=setmetatable({game=game,mapId=tostring(map.id),F=F,em=newEmitters(),
  eyes={},flared={},breathed={},glowT={},strikes={},shakes={},t0=now(),hintUntil=0,held=0},Room)
 self.locked=game.save and game.save.flags and game.save.flags.EVENT_LANCES_ROOM_LOCK_DOOR and true or false
 self.beaten=game.save and game.save.flags and game.save.flags.EVENT_BEAT_LANCE and true or false
 return self
end
function Room:ow()return self.game and self.game.overworld end
function Room:playerPos()
 local ow=self:ow();local p=ow and ow.player
 if not p then return{0,0,0}end
 return{(p.px or p.cellX*16)+8,0,(p.py or p.cellY*16)+8}
end

-- a dragon wakes: its eyes ignite; it breathes fire over the road
function Room:wake(i,t,roar)
 local d=self.F and self.F.dragons[i]
 if not d then return end
 self.eyes[i]=self.eyes[i]or t
 self:breathe(i,t,roar)
end
function Room:breathe(i,t,roar,dur)
 local d=self.F.dragons[i]
 self.breathed[i]=t
 local scale=d.big and 1.4 or 1.0
 if d.head then
  -- the great head over the far gate: a torrent of fire up into the sky
  emit(self.em,{kind='jet',t0=t,dur=(dur or M.T.breath)*1.15,life=1.15,rate=64,seed=i*7,
   x=d.x,y=d.y-4,z=d.z+7,dx=0,dy=.80,dz=.60,speed=150,tau=.48,spread=.20,turb=2.2,lift=10,
   size0=3.6,size1=14,hot=.20,mid=.52,smoke=14,sparks=22})
 else
  -- from the mouth, across and up: the two of a pair meet over the road
  local mx,my,mz=d.x+d.face*3.6*scale,d.y-2.4*scale,d.z
  emit(self.em,{kind='jet',t0=t,dur=dur or M.T.breath,life=.90,rate=58,seed=i*7,
   x=mx,y=my,z=mz,dx=d.face*.87,dy=.49,dz=0,speed=98*scale,tau=.40,spread=.16,turb=1.6,lift=8,
   size0=2.2*scale,size1=9.5*scale,hot=.18,mid=.50,smoke=9,sparks=14})
 end
 self.glowT[i]=t
 play(self.game,'fire_breath',d.head and .75 or .45,.92+.16*rh(i,1,1),max(0,t-now()))
 if roar then play(self.game,'dragon_roar',d.head and .95 or .7,(d.big or d.head)and .82 or(.95+.12*rh(i,2,2)),max(0,t-now())+.05)end
end
-- a fire column roars up as you pass it
function Room:flare(i,t)
 local c=self.F.columns[i]
 self.flared[i]=t
 emit(self.em,{kind='jet',t0=t,dur=.55,life=1.0,rate=60,seed=i*13+500,
  x=c.x,y=c.y-1,z=c.z,dx=0,dy=1,dz=0,speed=78,tau=.42,spread=.10,turb=1.2,lift=6,
  size0=2.6,size1=9.5,hot=.20,mid=.55,smoke=7,sparks=10})
 play(self.game,'fire_breath',.32,1.25+.1*rh(i,3,3))
end
function Room:ignite(t)
 if self.sealT then return end
 self.sealT=t
 emit(self.em,{kind='ring',t0=t,dur=2.8,life=.95,rate=70,seed=5,x=M.SEAL[1],y=.6,z=M.SEAL[2],r=21,speed=20,size0=2.2,size1=6.5})
 play(self.game,'fire_breath',.6,.8)
end
-- after the burst the seal burns on, low, in lengths (never one endless emitter)
function Room:sealBurn(t)
 if not self.sealT or self.beaten or t<self.sealT+2.4 then return end
 if self.sealNext and t<self.sealNext then return end
 self.sealNext=t+3
 emit(self.em,{kind='ring',t0=t,dur=3.05,life=.85,rate=26,seed=floor(t*7)%97+11,x=M.SEAL[1],y=.6,z=M.SEAL[2],r=21,speed=14,size0=1.6,size1=4.4})
end
function Room:slam(t)
 self.slamT=t
 emit(self.em,{kind='burst',t0=t,dur=.01,life=1.4,count=150,seed=3,x=M.GATE[1],y=6,z=M.GATE[2],speed=34})
 self:shake(t,.6,3.2)
 play(self.game,'gate_slam',.9,1)
end
function Room:shake(t,dur,amp)self.shakes[#self.shakes+1]={t=t,dur=dur,amp=amp}end
function Room:strike(t,x,z,sound)
 self.strikes[#self.strikes+1]={t=t,x=x,z=z,seed=#self.strikes+1}
 if sound~=false then play(self.game,'thunder',.85,.95+.1*rh(t,1,1),max(0,t-now())+.25)end
end
function Room:shakeAt(t)
 local ox,oy=0,0
 for i=#self.shakes,1,-1 do
  local s=self.shakes[i];local a=t-s.t
  if a>s.dur then table.remove(self.shakes,i)
  elseif a>=0 then
   local k=s.amp*(1-a/s.dur)^2
   ox=ox+sin(a*61)*k;oy=oy+sin(a*47+1)*k*.7
  end
 end
 return ox,oy
end

------------------------------------------------------------------ the film
-- Shots, by where the walk in has got to. P: the Champion (smoothed).
local SHOT={}
function SHOT.reveal(P,u)
 u=smooth(u)
 return{eye=lerp3({640,230,580},{470,72,330},u),focus=lerp3({150,30,140},{P[1],P[2]+12,P[3]},u),fov=rad(lerp(50,46,u))}
end
-- (TEST229: the abyss is filmed from higher -- 42 over the floor, not 30 --
-- so no pillar passes between the lens and you; in Joseph's recording a
-- column hid you, and a black pillar swept across half the picture. Each
-- placement here is checked against the room's geometry every few pixels of
-- its leg: you seen, the lens clear, nothing big right in front of it)
function SHOT.abyss(P)return{eye={P[1]-70,P[2]+42,P[3]+50},focus={P[1],P[2]+13,P[3]+10},fov=rad(46)}end
-- (the corridor from ahead of you on the hall side: from out over the lava
-- the fire columns stood between the lens and you -- they rise 70 over the
-- floor -- so now you walk toward the lens, the columns roaring up behind you)
function SHOT.corridor(P)return{eye={P[1]-80,P[2]+42,P[3]-12},focus={P[1]-12,P[2]+14,P[3]},fov=rad(46)}end
-- (TEST231: further back and aimed lower, so your partner, a step behind
-- you, walks wholly inside the picture, above the bars: it was cut by the
-- bottom edge the whole length of the dens)
function SHOT.den(P)return{eye={P[1]-12,P[2]+24,P[3]+80},focus={96,8,160},fov=rad(50)}end
function SHOT.gate(P)return{eye={96,36,150},focus={P[1],P[2]+14,P[3]},fov=rad(46)}end
function SHOT.wake(P,u)
 u=smooth(u)
 return{eye=lerp3({96,96,214},{96,82,116},u),focus=lerp3({96,26,140},{98,40,14},u),fov=rad(lerp(52,46,u))}
end
-- TEST229: THE LAST STRETCH IS FILMED TOO. After the wake the film went to
-- a view from over your head up the hall (TEST225), which left you out of
-- the picture until you had walked far enough for your own camera to stand
-- behind you -- in Joseph's recording nearly five seconds of an empty hall,
-- then the camera pressed into your head and your partner filling the
-- screen. Now a crane takes you up the hall to Lance: high just inside the
-- gate, looking down on you as the dragons' fire arches over the road,
-- settling in behind you as there is room, the hall and Lance ahead. It holds until
-- Lance sees you (the face-off). Your own camera stays facing up the hall,
-- so pushing up walks you toward him. (A skipped film still hands back to
-- your own camera; the view it holds while there is no room behind you is
-- this one, so you are always in the picture.)
-- At the gate the crane is high (100; the arch is 51 tall) over the arch,
-- looking down on you; as you walk in it comes down behind you to 44, 56
-- back: by 75 in, it is there. It always aims so that you are a little
-- below the middle of the picture (PLACE of the way to its bottom edge) --
-- steeply down at first, levelling out up the hall to Lance as it comes down.
-- k: how far in you are, 0..1 (the crane backs off by k^KPOW).
-- (TEST231: higher and further back than 229 -- 34 high, 46 back -- so that
-- your partner, a step behind you, walks wholly inside the picture: in
-- Joseph's recording its head bobbed half-cut along the bottom edge all the
-- way up the hall. Checked against the room with your partner as a solid
-- figure a cell behind you or beside you, on three lanes, the bars' edges
-- counted: you seen and a fifth below the middle, your partner wholly in
-- the picture, Lance coming into it from the top as the crane settles, the
-- lens clear and nothing big in front of it.)
M.FOLLOW={gateZ=192,depth=75,
 eye0={0,100,18},eye1={.5,44,56},      -- (toward the hall's axis, height, behind you)
 ahead=60,lean=.6,aimY=9,place0=.30,place1=.20,fov0=64,fov1=56,kpow=1}
local function atan2(y,x)if math.atan2 then return math.atan2(y,x)end return math.atan(y,x)end
function SHOT.follow(P)
 local F=M.FOLLOW
 local k=smooth((F.gateZ-P[3])/F.depth)
 local y=P[2]or 0
 local ax=lerp(1,F.eye1[1],k)      -- (1: on the axis at the gate)
 -- (it backs off behind you only as it comes down, so it stays inside the
 -- hall, clear of the arch behind it)
 local ex=lerp(P[1],M.HALL_X,ax)
 local ey=y+lerp(F.eye0[2],F.eye1[2],k)
 local ez=P[3]+lerp(F.eye0[3],F.eye1[3],k^(F.kpow or 2))
 local fov=rad(lerp(F.fov0,F.fov1,k))
 -- up the hall, leaning a little toward your side of it
 local hx,hz=(P[1]-ex)*F.lean,-F.ahead
 local hl=sqrt(hx*hx+hz*hz);hx,hz=hx/hl,hz/hl
 -- tilted so that you sit PLACE of the way below the middle
 local dx,dy,dz=P[1]-ex,y+F.aimY-ey,P[3]-ez
 local pitch=atan2(dy,sqrt(dx*dx+dz*dz))+fov*.5*lerp(F.place0,F.place1,k)
 local c=cos(pitch)
 return{eye={ex,ey,ez},focus={ex+hx*c*F.ahead,ey+sin(pitch)*F.ahead,ez+hz*c*F.ahead},fov=fov}
end

-- The face-off. Where you stop when Lance sees you is one of two cells
-- (in front of him, or beside him); each has its four shots placed and
-- checked against the room's own geometry (dumped from LeagueRooms: every
-- line of sight clear, every eye clear of the statues by a margin). If you
-- are somewhere else, the wide shot from down the hall holds instead. Each
-- shot creeps a little toward its subject while it holds.
-- TEST229: the over-your-shoulder and wide shots moved. In Joseph's
-- recording the first had your cap filling a corner of the picture (the lens
-- was 21 from your head) and the second, from down the hall, had you
-- standing right in front of Lance. Now: over your right shoulder from 36
-- away, and the two of you side by side on the seal from the west; each
-- checked with both of you as solid figures (you never in front of him,
-- your head never at the lens).
-- TEST231: YOUR PARTNER IN THE FACE-OFF. When Lance sees you, your partner
-- stops in the cell you came from: behind you, or beside you if your last
-- step was a sidestep. A shot placed for you and Lance alone sliced it at
-- the picture's edge -- in Joseph's recording Pikachu stood cut at the right
-- edge of the wide shot, and a dragon statue filled its left -- and your own
-- head was cut by the left edge of the over-your-shoulder shot. So each shot
-- now has a few places (you/lance/over/wide/send: lists), each checked
-- against the room with you and Lance (lens clear by 3.5 even as the lens
-- wanders, nobody hidden, your head wholly in or out of the picture, no
-- statue across the foreground) and with your partner in each cell it can
-- stop in (in front of him: behind you or either side; beside him: only
-- below you -- west of you is a statue, north the exit); as each shot comes
-- up the first place that shows your partner wholly or leaves it wholly out
-- of the picture is taken (Room:pickEye). (Pikachu peeking out from behind
-- Lance's head, or standing at the lens of his close-up, counts as a cut.)
-- TEST232: and for every screen shape. A place may carry amin/amax, the
-- shapes (picture width over height) it was checked for against the room --
-- outside them it is passed over -- and k, its own creep (else the shot's).
-- Every place below was checked over the whole creep at every shape from
-- 10:9 to 2.4:1 (amin/amax where it holds only part of that), and for each
-- cell your partner can stop in, at every shape, some place in the list
-- frames it (or leaves it wholly out). The first places are TEST231's (at
-- 16:9 the picks are TEST231's); the wide shot's second place replaces
-- {56,50,70}, which crept into the west statue.
--   you:   10:9 to 4:3 with your partner beside you: {84,38,-4} (west),
--          {86,36,18} (east); TEST231's first place has the room in its
--          foreground past 2.22, its third past 1.88
--   lance: {92,16,52}, from the south-west: your partner west of you at 1.9
--          and wider (TEST231's two sliced it at the left edge)
--   over:  {120,38,58} (behind you or east) and {88,38,58} (west) keep your
--          head in at any shape; TEST231's two cut it below 1.42 (4:3)
--   wide:  TEST231's first opens on the west statue's flank past 2.16; the
--          second, from higher and further back on a short creep, is clear
--          at every shape for every cell
--   send:  {76,40,96} for the widest phones (the first has the room in its
--          foreground past 2.23)
--   (beside him) over: {76,50,42} at 10:9 and past 2.37
M.FACEOFF_CASES={
 {P={104,40},
  you={{87.3,18,11.2,amax=2.225},{88,38,16},{88,38,0,amax=1.88},{104,38,20},{84,38,-4,amax=1.46},{86,36,18}},
  lance={{124,10,48},{121,14,49},{92,16,52}},lanceFov=40,
  over={{128,30,54,amin=1.42},{80,30,54,amin=1.42},{120,38,58},{88,38,58}},
  wide={{56,32,64,amax=2.16},{72,64,64,k=.05}},
  send={{72,40,96,amax=2.23},{86.9,36,95.8},{76,40,96}}},
 {P={88,24},you={{116.8,18,40.7},{132,22,60}},lance={{110.2,9,47.2}},
  over={{72,34,46,amin=1.31,amax=2.37},{72,38,42,amin=1.21,amax=2.02},{76,50,42}},wide={{92,32,94}},send={{96,36,90}}},
}
local function faceCase(P)
 local best,bd=nil,1e9
 for _,c in ipairs(M.FACEOFF_CASES)do
  local d=(c.P[1]-P[1])^2+(c.P[2]-P[3])^2
  if d<bd then best,bd=c,d end
 end
 return bd<=144 and best or nil
end
M.faceCase=faceCase
-- (a shot's first place, whether it has a list of them or just the one)
local function firstEye(e)
 if type(e)=='table'and type(e[1])=='table'then return e[1]end
 return e
end
-- (a place's own creep, e.k, before the shot's)
local function creep(e,f,u,k)
 local s=smooth(u)*(e.k or k or .07)
 return{e[1]+(f[1]-e[1])*s,e[2]+(f[2]-e[2])*s,e[3]+(f[3]-e[3])*s}
end
-- (each face-off shot below takes the place Room:pickEye chose, `pick`, if
-- there is one; else its first)
-- the two of you, small, at the end of the hall of fire, from down the hall
function SHOT.faceoffWide(P,u,pick)
 local L=M.LANCE
 local mx,mz=(L[1]+P[1])/2,(L[2]+P[3])/2
 local f={mx,12,mz}
 local c=faceCase(P)
 return{eye=creep(pick or(c and firstEye(c.wide))or{M.HALL_X+8,38,mz+70},f,u,.09),focus=f,fov=rad(50)}
end
-- the battle comes: from down the hall, tilting up into the canopy of fire
-- (TEST229: from where TEST224 placed and checked it -- `send`, the old wide
-- shot's place -- now that the wide shot itself has moved)
function SHOT.sendoff(P,u,pick)
 local L=M.LANCE
 local mx,mz=(L[1]+P[1])/2,(L[2]+P[3])/2
 local c=faceCase(P)
 local e=pick or(c and firstEye(c.send or c.wide))or{M.HALL_X+8,38,mz+70}
 local k=smooth(u)
 return{eye={e[1],e[2]-2*k,e[3]+4*k},focus={mx,lerp(14,40,k),mz-6*k},fov=rad(lerp(50,58,k))}
end
-- over Lance's shoulder, at you
function SHOT.faceoffYou(P,u,pick)
 local c=faceCase(P);if not c then return SHOT.faceoffWide(P,u)end
 local f={P[1],11,P[3]}
 return{eye=creep(pick or firstEye(c.you),f,u),focus=f,fov=rad(44)}
end
-- Lance, from below, the blazing gate behind him
function SHOT.faceoffLance(P,u,pick)
 local c=faceCase(P);if not c then return SHOT.faceoffWide(P,u)end
 local L=M.LANCE
 local f={L[1],17.5,L[2]}
 return{eye=creep(pick or firstEye(c.lance),f,u),focus=f,fov=rad(c.lanceFov or 44)}
end
-- over your shoulder, at him
function SHOT.faceoffOver(P,u,pick)
 local c=faceCase(P);if not c then return SHOT.faceoffWide(P,u)end
 local L=M.LANCE
 local f={L[1],15,L[2]}
 return{eye=creep(pick or firstEye(c.over),f,u),focus=f,fov=rad(46)}
end

-- TEST231: your partner and the picture. Your partner as a solid figure
-- (H tall, R round); MARGIN of the picture's half-width it must keep inside,
-- YMARGIN of its half-height (the bars, while he talks, hide the rest);
-- never more than MAXSIZE of the picture's height, nor nearer the lens than
-- NEAR; never more than HIDE of it behind you or Lance (a sliver of your
-- partner peeking out from behind a head reads as a cut too).
M.PARTNER={h=10,r=3.5,margin=.93,ymargin=.87,maxSize=.45,near=16,hide=.35}
M.PEOPLE={r=3.5,h=21}       -- (you and Lance, as screens in front of it)
local PICK_KEY={faceoffYou='you',faceoffLance='lance',faceoffOver='over',faceoffWide='wide',sendoff='send'}
M.PICK_KEY=PICK_KEY
local function isPartner(e)
 if type(e)~='table'then return false end
 if e.pikachuFollower==true or e.isPokemonFollower==true or e.pokepcTrailer==true or e.wildsFollower==true
  or e._pokepcFollowerSpecies~=nil or e._wildsFollowerSpecies~=nil or e.pokepcMon~=nil then return true end
 local d=type(e.def)=='table'and e.def or{}
 return tostring(e.name or d.name or''):find('FOLLOWER',1,true)~=nil
end
M.isPartner=isPartner
-- a camera's own frame: forward, right, up, and the picture's half-extents
local function frameOf(cam,aspect)
 local e,f=cam.eye,cam.focus
 local fx,fy,fz=f[1]-e[1],f[2]-e[2],f[3]-e[3]
 local l=sqrt(fx*fx+fy*fy+fz*fz);if l<1e-6 then return nil end
 fx,fy,fz=fx/l,fy/l,fz/l
 local rx,rz=-fz,fx
 local rl=sqrt(rx*rx+rz*rz);if rl<1e-6 then rx,rz,rl=1,0,1 end
 rx,rz=rx/rl,rz/rl
 local t=math.tan((cam.fov or rad(50))/2)
 return{e=e,fx=fx,fy=fy,fz=fz,rx=rx,rz=rz,ux=-rz*fy,uy=rz*fx-rx*fz,uz=rx*fy,tx=t*aspect,ty=t}
end
local function project(F,x,y,z)
 local dx,dy,dz=x-F.e[1],y-F.e[2],z-F.e[3]
 local d=dx*F.fx+dy*F.fy+dz*F.fz
 if d<=.3 then return nil end
 return(dx*F.rx+dz*F.rz)/d/F.tx,(dx*F.ux+dy*F.uy+dz*F.uz)/d/F.ty
end
M._frameOf,M._project=frameOf,project
-- your partner at p={x,z}: 'in' the picture, 'out' of it, or 'cut' by its edge
-- (and how much of the picture's height it fills)
local function partnerState(F,p,PA)
 local n,inside,vis,behind=0,0,0,false
 local x0,x1,y0,y1=9,-9,9,-9
 for _,yy in ipairs({0,PA.h})do
  for k=0,7 do
   local a=k/8*pi*2
   local x,y=project(F,p[1]+cos(a)*PA.r,yy,p[2]+sin(a)*PA.r)
   n=n+1
   if x then
    vis=vis+1
    if abs(x)<=PA.margin and abs(y)<=PA.ymargin then inside=inside+1 end
    x0,x1,y0,y1=min(x0,x),max(x1,x),min(y0,y),max(y1,y)
   else behind=true end
  end
 end
 if vis==0 then return'out',0 end
 local size=(y1-y0)/2
 if inside==n then return'in',size end
 local yvis=min(1,PA.ymargin+(1-PA.margin)+.02)
 if not behind and(x1<-1 or x0>1 or y1<-yvis or y0>yvis)then return'out',size end
 if behind and inside==0 then return'out',size end
 return'cut',size
end
M._partnerState=partnerState
-- does the line from the lens to `t` pass through your partner?
local function through(e,t,p,PA)
 local dx,dy,dz=t[1]-e[1],t[2]-e[2],t[3]-e[3]
 local ln=sqrt(dx*dx+dy*dy+dz*dz)
 for i=0,40 do
  local s=i/40
  if ln*s>ln-2 then break end
  local x,y,z=e[1]+dx*s,e[2]+dy*s,e[3]+dz*s
  if y>=0 and y<=PA.h and(x-p[1])^2+(z-p[2])^2<PA.r*PA.r then return true end
 end
 return false
end
-- does the line from the lens to `q` pass behind one of `people` ({x,z})?
local function behindPeople(e,q,people)
 local H=M.PEOPLE
 local dx,dy,dz=q[1]-e[1],q[2]-e[2],q[3]-e[3]
 local ln=sqrt(dx*dx+dy*dy+dz*dz)
 for i=1,79 do
  local s=i/80
  if ln*s>ln-1.5 then break end
  local x,y,z=e[1]+dx*s,e[2]+dy*s,e[3]+dz*s
  if y>=0 and y<=H.h then
   for _,c in ipairs(people)do
    if(x-c[1])^2+(z-c[2])^2<H.r*H.r then return true end
   end
  end
 end
 return false
end
-- how much of your partner at p, as the lens sees it, is behind them
-- (15 points across it: 3 heights, 5 across, square to the line of sight)
local function hiddenFrac(e,p,people,PA)
 local vx,vz=p[1]-e[1],p[2]-e[3]
 local vl=sqrt(vx*vx+vz*vz);if vl<1e-6 then return 0 end
 local sx,sz=-vz/vl,vx/vl
 local n,hid=0,0
 for _,fy in ipairs({.15,.5,.85})do
  for _,s in ipairs({-.85,-.45,0,.45,.85})do
   n=n+1
   if behindPeople(e,{p[1]+sx*s*PA.r,fy*PA.h,p[2]+sz*s*PA.r},people)then hid=hid+1 end
  end
 end
 return hid/n
end
M._hiddenFrac=hiddenFrac
-- (TEST232: and why not: 'cut' by an edge, 'huge', 'near' the lens, 'hides'
-- you or Lance, 'hidden' behind you or Lance)
local function partnerOk(cam,p,P,PA,aspect)
 local F=frameOf(cam,aspect)
 if not F then return true end
 local st,size=partnerState(F,p,PA)
 if st=='out'then return true end
 if st=='cut'then return false,'cut'end
 local dx,dy,dz=cam.eye[1]-p[1],cam.eye[2]-PA.h/2,cam.eye[3]-p[2]
 if size>PA.maxSize then return false,'huge'end
 if sqrt(dx*dx+dy*dy+dz*dz)<PA.near then return false,'near'end
 local L=M.LANCE
 if through(cam.eye,{P[1],9,P[3]},p,PA)and through(cam.eye,{P[1],15,P[3]},p,PA)then return false,'hides'end
 if through(cam.eye,{L[1],10,L[2]},p,PA)and through(cam.eye,{L[1],17,L[2]},p,PA)then return false,'hides'end
 if hiddenFrac(cam.eye,p,{{P[1],P[3]},{L[1],L[2]}},PA)>(PA.hide or .35)then return false,'hidden'end
 return true
end
M._partnerOk=partnerOk
M.SHOT=SHOT

-- (TEST229: while the film follows you, your own camera faces up the hall,
-- level, so pushing up walks you toward Lance -- the walk goes the way your
-- own camera faces -- and is ready for when you get it back)
local function holdYaw()
 pcall(function()
  local FP=V.require('FirstPerson')
  if FP.engaged and FP.engaged()then FP.yaw=pi end
  if FP.PITCH_DEFAULT then FP.pitch=FP.PITCH_DEFAULT end
 end)
end
M.holdYaw=holdYaw
local Film={};Film.__index=Film
function Film.new(room,kind)
 return setmetatable({room=room,kind=kind,t0=now(),seg=0,shot=nil,from=nil,blendT=0,blendDur=0,
  letter=0,phase='walk'},Film)
end
-- which leg of the walk in the Champion is on (by cell, so Yellow's longer
-- last leg works too)
local function segOf(p)
 if p.cellY<=16 and p.cellX>18 then return 1 end
 if p.cellX>=18 and p.cellY<23 then return 2 end
 if p.cellY>=23 and p.cellX>6 then return 3 end
 if p.cellX<=6 and p.cellY>17 then return 4 end
 return 5
end
local SEG_SHOT={'reveal','abyss','corridor','den','gate'}
function Film:setShot(name,dur)
 self.from=self.cam and{eye=self.cam.eye,focus=self.cam.focus,fov=self.cam.fov}or nil
 self.shot=name;self.shotT=now()
 -- (TEST231: each face-off shot takes the place that frames your partner)
 if self.kind=='faceoff'and PICK_KEY[name]and self.room and self.room.pickEye then
  self.pick=self.pick or{}
  local P=self.fP or self.room:playerPos()
  local ok,eye=pcall(self.room.pickEye,self.room,name,P)
  self.pick[name]=ok and eye or nil
 end
 self.blendT=now();self.blendDur=self.from and(dur or M.T.blend)or 0
 if dur==0 then self.from=nil end
end
function Film:camera(P,t)
 local name=self.shot
 if not name then return nil end
 local u=0
 if name=='reveal'then u=(t-self.shotT)/M.T.s1
 elseif name=='wake'then u=(t-self.shotT)/M.T.wave
 elseif name:sub(1,7)=='faceoff'or name=='sendoff'then u=(t-self.shotT)/(self.shotLen or 4)end
 local to=SHOT[name](self.fP or P,max(0,min(1,u)),self.pick and self.pick[name])
 local cam
 if self.from and self.blendDur>0 then
  local b=smooth((t-self.blendT)/self.blendDur)
  cam={eye=lerp3(self.from.eye,to.eye,b),focus=lerp3(self.from.focus,to.focus,b),fov=lerp(self.from.fov,to.fov,b)}
 else cam=to end
 self.cam={eye={cam.eye[1],cam.eye[2],cam.eye[3]},focus={cam.focus[1],cam.focus[2],cam.focus[3]},fov=cam.fov}
 -- a hand-held breath, and the shakes
 local ox,oy=self.room:shakeAt(t)
 local e={cam.eye[1]+sin(t*.31)*1.2+ox,cam.eye[2]+sin(t*.23+1)*.6+oy,cam.eye[3]}
 local f={cam.focus[1]+ox*.4,cam.focus[2]+oy*.4,cam.focus[3]}
 return{eye=e,focus=f,fov=cam.fov,up={0,1,0},curve=0}
end

------------------------------------------------------------------ the freeze
-- while the dragons wake the walk is over but the film is not: a do-nothing
-- screen holds the overworld still (it still draws under it)
local Hold={};Hold.__index=Hold
Hold.isOpaque=false
function Hold:update()end
function Hold:draw()end
function Hold:keypressed()end

------------------------------------------------------------------ update
-- something is up over the overworld (a text box, most likely)
function Room:talking()
 local stack=self.game and self.game.stack
 local top=stack and stack.top and stack:top()
 return top~=nil and top~=self:ow()and top~=self.hold
end
function Room:update(dt)
 local game=self.game
 local ow=self:ow()
 if not(ow and ow.map and tostring(ow.map.id)==self.mapId)then return false end
 local t=now()
 local p=ow.player
 local P=self:playerPos()
 if not self.P then self.P=P else
  local k=1-exp(-(dt or 1/60)/.18)
  self.P=lerp3(self.P,P,k)
 end
 local flags=game.save and game.save.flags or{}
 if flags.EVENT_BEAT_LANCE then
  self.beaten=true
  if self.film and self.film.kind~='faceoff'then self:endFilm(t)end
 end
 -- the start: the game's walk in from the stair
 if not self.started then
  self.started=true
  if not self.beaten and p.cellX==24 and p.cellY==16 and #(ow.scriptMoves or{})>0 then
   self.film=Film.new(self,'walkin')
   self.film:setShot('reveal')
   M.pacing=true
   self:strike(t+.5,-140,-180)
   play(game,'dragon_roar',.55,.7,1.2)
  end
 end
 -- skipping the walk-in film: hold A (or START). (Not the face-off: there
 -- A turns Lance's pages.) TEST229: the crane up the hall too: your own
 -- camera back, with a glide into it
 local input=game.input
 if input and self.film and(self.film.kind=='walkin'or self.film.kind=='follow')then
  local function down(b)return(input.isDown and input:isDown(b))or false end
  local held=down('a')or down('start')
  if input.wasPressed and(input:wasPressed('a')or input:wasPressed('b')or input:wasPressed('start'))then self.hintUntil=t+3 end
  self.held=held and self.held+(dt or 1/60)or 0
  if self.held>=M.T.skipHold then
   self.held=0
   if self.film.kind=='walkin'then self.skipped=true end
   self:endFilm(t)
  end
 end
 -- the gate shuts behind you
 if not self.locked and flags.EVENT_LANCES_ROOM_LOCK_DOOR then
  self.locked=true
  self:slam(t)
  -- the film was skipped: the dragons still wake (their eyes, at once)
  if self.skipped and not self.awake then
   self.awake=true
   for i,d in ipairs(self.F and self.F.dragons or{})do self.eyes[i]=t+.2+(d.head and .3 or 0)end
  end
 end
 if not self.beaten then
  -- the fire columns roar up as you come near
  for i,c in ipairs(self.F and self.F.columns or{})do
   if not self.flared[i]then
    local rx=(abs(c.x-M.HALL_X)>70 and c.z<200)and 100 or 60
    local dx,dz=(c.x-P[1])/rx,(c.z-P[3])/48
    if dx*dx+dz*dz<1 then self:flare(i,t+.05)end
   end
  end
  -- once the dragons are awake, each pair breathes as you pass beneath
  if self.awake then
   for i,d in ipairs(self.F.dragons)do
    if not d.head and(self.passed or{})[i]==nil and P[3]<d.z+10 and P[3]>d.z-30 and t-(self.breathed[i]or-99)>2.5 then
     self.passed=self.passed or{}
     self.passed[i]=true
     self:breathe(i,t,(i%2==0))
    end
   end
  end
  -- the seal
  if self.locked and P[3]<76 and not self.sealT then self:ignite(t)end
  self:sealBurn(t)
  -- while Lance talks the dragons are restless: now and then a pair breathes
  local F=self.film
  if F and F.kind=='faceoff'and self.F and t>=(self.restless or 0)then
   local D=self.F.dragons
   self.restless=t+3.6+2.2*rh(t,4,4)
   local i=1+floor(rh(t,5,5)*#D)%#D
   local d=D[i]
   if d and not d.head then
    self:breathe(i,t,false,1.3)
    -- its partner across the road, a beat later
    for j,e in ipairs(D)do
     if j~=i and not e.head and abs(e.z-d.z)<6 and e.face~=d.face then self:breathe(j,t+.25,false,1.2)end
    end
   end
  end
 end
 self:pendingWakes(t)
 -- the film's shots
 local F=self.film
 if F then
  if F.kind=='walkin'then
   if F.phase=='walk'then
    local s=segOf(p)
    local want=SEG_SHOT[min(5,s)]
    -- the reveal holds its time whatever the walk does
    if F.shot=='reveal'and t-F.shotT<M.T.s1 then want='reveal'end
    -- (TEST229: a cut from leg to leg, not a glide: the glides between these
    -- far-apart cameras went through statues and pillars on the way -- in
    -- the recording a dragon's wing filled half the picture going into the
    -- gate shot)
    if want~=F.shot then F:setShot(want,0)end
    -- the walk in is done (and the gate has shut): the dragons wake. (If
    -- the gate never shut on the way -- another version's route -- they
    -- wake anyway, a moment after the walk ends.)
    local still=#(ow.scriptMoves or{})==0 and not p.moving
    if still then self.stillT=self.stillT or t else self.stillT=nil end
    if still and(self.locked or t-self.stillT>.8)then
     -- a cut on the slam, up over the gate
     F.phase='wake';F:setShot('wake',0)
     M.pacing=false
     self.hold=setmetatable({},Hold)
     pcall(function()game.stack:push(self.hold)end)
     self:startWave(t)
    end
   elseif F.phase=='wake'then
    if t-F.shotT>=M.T.wave then self:endFilm(t)end
   end
  elseif F.kind=='follow'then
   holdYaw()
  elseif F.kind=='faceoff'then
   -- the shots take turns while he talks (cuts, not moves: the way between
   -- them runs through Lance or you)
   if not self.sentOff and t-F.shotT>=(F.shotLen or 4)then
    local n=#M.FACEOFF
    F.turn=(F.turn or 1)+1
    if F.turn>n then F.turn=2 end
    local s=M.FACEOFF[F.turn]
    F.shotLen=s[2];F:setShot(s[1],0)
   end
   -- it ends with the battle (onPushed), or when the speech has closed
   -- without one, or after a long while
   if self:talking()then self.quietT=nil else self.quietT=self.quietT or t end
   if(self.quietT and t-self.quietT>M.T.quiet and t-F.t0>1.5)or t-F.t0>M.T.faceoffMax then
    self:endFilm(t)
   end
  end
 end
 -- the bars of the film
 local wantL=(self.film and not self.film.ending)and(self.film.kind=='follow'and M.BARS_FOLLOW or 1)or 0
 self.letter=self.letter or 0
 local rate=(dt or 1/60)/(wantL>self.letter and M.T.letterIn or M.T.letterOut)
 if wantL>self.letter then self.letter=min(wantL,self.letter+rate)else self.letter=max(wantL,self.letter-rate)end
 local wantT=(self.film and self.film.kind=='faceoff'and self:talking())and 1 or 0
 self.talkBars=(self.talkBars or 0)+(wantT-(self.talkBars or 0))*min(1,(dt or 1/60)*6)
 pumpSound()
 return true
end
-- the wave: the dragons wake from the gate to Lance; the title; the sting
function Room:startWave(t)
 self.awake=true
 self.waveT=t
 local D=self.F and self.F.dragons or{}
 -- pairs by row (sorted south to north); the gate's pair first
 local k=0
 local lastZ=nil
 for i,d in ipairs(D)do
  if not d.head then
   if lastZ==nil or abs(d.z-lastZ)>4 then k=k+1;lastZ=d.z end
   local when=t+.35+(k-1)*M.T.waveGap
   self.pending=self.pending or{}
   self.pending[#self.pending+1]={t=when,i=i,roar=(k==1 or k==4 or d.big)and d.face>0}
  end
 end
 for i,d in ipairs(D)do
  if d.head then
   self.pending=self.pending or{}
   self.pending[#self.pending+1]={t=t+.35+k*M.T.waveGap+.2,i=i,roar=true}
  end
 end
 self.titleT=t+M.T.title
 play(self.game,'sting',.85,1,M.T.title-.15)
 self:strike(t+M.T.title+.9,96,-260)
 self:shake(t+.35+k*M.T.waveGap+.2,.8,1.6)
end
function Room:pendingWakes(t)
 if not self.pending then return end
 local keep={}
 for _,w in ipairs(self.pending)do
  if w.t<=t then self:wake(w.i,w.t,w.roar)else keep[#keep+1]=w end
 end
 self.pending=keep
end
function Room:endFilm(t,gone)
 local F=self.film
 if not F then return end
 self.film=nil
 M.pacing=false
 if self.hold then
  local hold=self.hold;self.hold=nil
  pcall(function()if self.game.stack:top()==hold then self.game.stack:pop()end end)
 end
 -- (`gone`: the room itself was closed, by a soft reset: no hand-back)
 if gone then return end
 -- a skipped walk in still leaves the dragons awake for the last stretch
 if F.kind=='walkin'and not self.awake and self.locked then self.awake=true end
 -- TEST229: the film goes on up the hall with you (not after a skip)
 if F.kind=='walkin'and not self.skipped and not self.beaten then
  self:follow(t,F)
  return
 end
 -- the hand-back: your own camera turns to look up the hall toward Lance,
 -- and the film glides into it rather than cutting
 if F.kind=='walkin'then
  pcall(function()
   local FP=V.require('FirstPerson')
   if FP.engaged and FP.engaged()then FP.yaw=pi end
   -- (TEST225: and level, not wherever it last tilted)
   if FP.PITCH_DEFAULT then FP.pitch=FP.PITCH_DEFAULT end
  end)
 end
 if F.cam and not self.beaten then
  self.handback={t0=t,dur=M.T.handback,from={eye=F.cam.eye,focus=F.cam.focus,fov=F.cam.fov}}
 end
end
-- TEST229: the crane up the hall (from the wake's last frame)
function Room:follow(t,from)
 local f=Film.new(self,'follow')
 f.phase='follow'
 f.cam=from and from.cam or nil
 -- (a cut, from Lance at the end of the hall to you at its start: a glide
 -- from the wake's last frame -- inside the hall, you behind it -- left you
 -- out of the picture for its length)
 f:setShot('follow',from and from.cam and M.T.followBlend>0 and M.T.followBlend or 0)
 self.film=f
 self.handback=nil
 holdYaw()
end
-- TEST231: where your partner(s) will stand (an NPC mid-step: where its step
-- ends), as {x,z} on the room's floor
function Room:partners()
 local ow=self:ow()
 local out,seen={},{}
 if not ow then return out end
 for _,list in ipairs({ow.npcs or{},ow.entities or{}})do
  for _,e in ipairs(list)do
   if e~=ow.player and not seen[e]and isPartner(e)then
    seen[e]=true
    local x,z
    if e.moving and tonumber(e.targetX)and tonumber(e.targetY)then
     x,z=e.targetX*16+8,e.targetY*16+8
    else
     x=(tonumber(e.px)or(tonumber(e.cellX)or 0)*16)+8
     z=(tonumber(e.py)or(tonumber(e.cellY)or 0)*16)+8
    end
    out[#out+1]={x,z}
   end
  end
 end
 return out
end
-- the first of a shot's places that frames your partner(s) well, the whole
-- length of the shot (it creeps); the first if none does (or nobody is with you).
-- (The send-off tilts up into the fire: the floor -- you, Lance and your
-- partner on it -- leaves the bottom of the picture together; only how it
-- starts is asked of it.)
local PICK_AT={faceoffYou={0,.5,1},faceoffLance={0,.5,1},faceoffOver={0,.5,1},faceoffWide={0,.5,1},sendoff={0}}
-- (and from anywhere the lens wanders while the shot holds: the hand-held
-- breath, 1.2 sideways and .6 up or down; in the first shot the jolt as he
-- sees you on top; the send-off's own jolt comes as it tilts away)
local WANDER={faceoffYou={2.4,1.44},sendoff={1.4,.7}}
M.WANDER=WANDER
-- TEST232: the picture's shape (width over height) as the 3D pass draws it:
-- the view size FirstPerson.frame was last handed -- the very size the scene
-- is projected with -- else the window's (16:9 if neither is known)
local function viewAspect()
 local w,h=M.viewW,M.viewH
 if type(w)=='number'and type(h)=='number'and w>0 and h>0 and w<1e6 and h<1e6 then return w/h end
 local aspect=16/9
 pcall(function()local W,H=love.graphics.getDimensions();if W and H and W>0 and H>0 then aspect=W/H end end)
 return aspect
end
M.viewAspect=viewAspect
-- (a place checked for this shape of picture: amin/amax, if it has them)
local function usable(eye,aspect)return aspect>=(eye.amin or 0)and aspect<=(eye.amax or 1e9)end
M._usable=usable
local function cellAt(p)return('%.0f,%.0f'):format(p[1],p[2])end
function Room:pickEye(name,P)
 local key=PICK_KEY[name]
 local c=key and faceCase(P)
 local list=c and c[key]
 if type(list)~='table'then return nil end
 if type(list[1])~='table'then return list end
 local aspect=viewAspect()
 local parts=self:partners()
 if #parts==0 then
  for i,eye in ipairs(list)do
   if usable(eye,aspect)then log('%s: place %d of %d (nobody with you)',name,i,#list);return eye end
  end
  log('%s: place 1 of %d (nobody with you)',name,#list)
  return list[1]
 end
 local w=WANDER[name]or{1.2,.6}
 -- (if none frames your partner: the first that does not cut it at an edge,
 -- else the first checked for this shape; and the follower that failed)
 local failed,uncut,uncutI,first,firstI=nil,nil,nil,nil,nil
 for i,eye in ipairs(list)do
  if usable(eye,aspect)then
   first,firstI=first or eye,firstI or i
   local bad,cut=nil,false
   for _,u in ipairs(PICK_AT[name]or{0,.5,1})do
    local cam=SHOT[name](P,u,eye)
    for _,ox in ipairs({0,w[1],-w[1]})do
     for _,oy in ipairs({0,w[2],-w[2]})do
      local at={eye={cam.eye[1]+ox,cam.eye[2]+oy,cam.eye[3]},focus=cam.focus,fov=cam.fov}
      for _,p in ipairs(parts)do
       if bad then
        -- (this place has failed: all that is left to learn is whether it
        -- cuts a follower at an edge, and that is cheap to ask)
        local F=frameOf(at,aspect)
        if F and partnerState(F,p,M.PARTNER)=='cut'then cut=true;break end
       else
        local ok,why=partnerOk(at,p,P,M.PARTNER,aspect)
        if not ok then bad=p;if why=='cut'then cut=true;break end end
       end
      end
      if cut then break end
     end
     if cut then break end
    end
    if cut then break end
   end
   if not bad then
    if #parts==1 then
     log('%s: place %d of %d, for your partner at %.0f,%.0f',name,i,#list,parts[1][1],parts[1][2])
    else
     local at={};for k,p in ipairs(parts)do at[k]=cellAt(p)end
     log('%s: place %d of %d, for your partners at %s',name,i,#list,table.concat(at,' and '))
    end
    return eye
   end
   failed=failed or bad
   if not cut and not uncut then uncut,uncutI=eye,i end
  end
 end
 failed=failed or parts[1]
 if uncut then
  log('%s: no place frames your partner at %s; place %d of %d, which does not cut it',name,cellAt(failed),uncutI,#list)
  return uncut
 end
 log('%s: no place frames your partner at %s; place %d of %d',name,cellAt(failed),firstI or 1,#list)
 return first or list[1]
end
-- Lance sees you
function Room:faceoff(t)
 if self.beaten or(self.film and self.film.kind=='faceoff')then return end
 if self.film then self:endFilm(t)end
 self.handback=nil
 self.quietT=nil
 self.film=Film.new(self,'faceoff')
 self.film.phase='faceoff'
 -- the two of you as you are now (he does not move; you are stopped)
 local here=self:playerPos()
 self.film.fP={here[1],0,here[3]}
 local first=M.FACEOFF[1]
 self.film.turn=1;self.film.shotLen=first[2]
 self.film:setShot(first[1],0)
 self:strike(t+.1,140,-220)
 self:ignite(t)
 for i,d in ipairs(self.F and self.F.dragons or{})do
  if d.big or d.head then self:breathe(i,t+.3+(d.head and .5 or 0),d.head)end
 end
 self:shake(t+.3,.5,1.2)
 self.restless=t+4.5
end
-- the battle comes: every dragon breathes at once
function Room:sendoff(t)
 if self.sentOff then return end
 self.sentOff=t
 local F=self.film
 if F and F.kind=='faceoff'then F.turn=#M.FACEOFF;F.shotLen=1.1;F:setShot('sendoff',0)end
 for i,d in ipairs(self.F and self.F.dragons or{})do
  self.eyes[i]=self.eyes[i]or t
  self:breathe(i,t+.05*(i%4),false,M.T.sendoff)
 end
 self:shake(t+.1,.9,2.2)
 play(self.game,'dragon_roar',1.0,.78,.05)
end

------------------------------------------------------------------ drawing in the room
local function drawBolt(K,R,Mat4,g,s,t)
 local age=t-s.t
 if age<0 or age>.6 then return end
 local flick=(age<.08 or(age>.18 and age<.26)or(age>.34 and age<.40))and 1 or .25
 g.setColor(.78,.72,1,.5*flick)
 R.draw(K.cross,K.soft,Mat4.mul(Mat4.translate(s.x,380,s.z),Mat4.scale(560,260,560)))
 if not M.boltStream then M.boltStream=K.newStream and K.newStream(24)or false end
 local sm=M.boltStream
 if sm then
  local x,z=s.x,s.z
  for i=0,23 do
   local u=i/23
   local y=460-(460-40)*u
   x=x+(rh(s.seed,i,5)-.5)*36;z=z+(rh(s.seed,i,7)-.5)*36
   K.streamPut(sm,i,x,y,z,6*(1-u*.5),false)
  end
  pcall(sm.mesh.setVertices,sm.mesh,sm.verts)
  g.setColor(.94,.92,1,.95*flick)
  R.draw(sm.mesh,K.soft,Mat4.translate(0,0,0))
 end
end
-- the fire is worked out once a frame (a reflection pass draws it again)
local filledAt=nil
function M.drawWorld(state)
 local s=active
 if not s or state.battle then return end
 local map=state.map
 if not(map and tostring(map.id)==s.mapId)then return end
 local okR,Road=pcall(V.require,'LeagueRoad')
 if not(okR and Road and Road.fxKit)then return end
 local K=Road.fxKit()
 if not(K.soft and K.cross and K.streamPut)then return end
 local R=V.require('Voxel3D')
 local Mat4=V.require('Mat4')
 local g=love.graphics
 local t=now()
 local D=s.F and s.F.dragons or{}
 local B=nil
 if filledAt~=t then
  filledAt=t
  B=fillFire(s.em,t,R.eye,R.focus)
 else B=bufs end
 local tex=atlas()
 -- the smoke and the flame's body, laid over what is behind them
 if B and tex then
  pcall(R.withEffect,'alpha',function()
   local id=Mat4.translate(0,0,0)
   for i,b in ipairs(B.smoke)do
    if b and b.used>0 then g.setColor(1,1,1,M.SMOKE[i]);R.draw(b.mesh,tex,id)end
   end
   for i,b in ipairs(B.body)do
    if b and b.used>0 then g.setColor(1,1,1,M.BODY[i]);R.draw(b.mesh,tex,id)end
   end
  end)
 end
 pcall(R.withEffect,'add',function()
  -- the eyes of the woken: a burning glow that flares as they breathe
  for i,d in ipairs(D)do
   local e=s.eyes[i]
   if e and t>=e then
    local since=t-(s.glowT[i]or e)
    local flare=since<M.T.breath and(1-since/M.T.breath)or 0
    local k=min(1,(t-e)/.25)
    local sz=(d.big and 5.5 or(d.head and 6 or 3.8))*(1+.5*flare)*(.9+.1*sin(t*9+i))
    g.setColor(1,.38,.10,(.45+.30*flare)*k)
    R.draw(K.cross,K.soft,Mat4.mul(Mat4.translate(d.x,d.y,d.z),Mat4.scale(sz,sz*.8,sz)))
    g.setColor(1,.90,.62,(.45+.35*flare)*k)
    R.draw(K.cross,K.soft,Mat4.mul(Mat4.translate(d.x,d.y,d.z),Mat4.scale(sz*.35,sz*.28,sz*.35)))
   end
  end
  -- TEST229: the woken dragons' eyes cast a little warm light on the floor
  -- beneath them (the hall was black between the fires), more as they breathe
  for i,d in ipairs(D)do
   local e=s.eyes[i]
   if e and t>=e and not d.head then
    local since=t-(s.glowT[i]or e)
    local flare=since<M.T.breath and(1-since/M.T.breath)or 0
    local k=min(1,(t-e)/.6)
    g.setColor(1,.40,.12,(.06+.10*flare)*k*(.9+.1*sin(t*5+i)))
    R.draw(K.cross,K.soft,Mat4.mul(Mat4.translate(d.x+d.face*12,1.5,d.z),Mat4.scale(22,2.5,18)))
   end
  end
  -- a little of the light a breath throws, a flare's bloom, the seal
  for i,d in ipairs(D)do
   local b=s.breathed[i]
   if b and t>=b and t-b<M.T.breath+.6 then
    local a=t-b;local k=min(1,a/.2)*(1-max(0,a-M.T.breath)/.6)
    local cx=d.head and d.x or(d.x+d.face*22)
    local cy=d.head and d.y+28 or d.y+12
    local cz=d.head and d.z+18 or d.z
    g.setColor(1,.50,.18,.05*k)
    R.draw(K.cross,K.soft,Mat4.mul(Mat4.translate(cx,cy,cz),Mat4.scale(30,22,30)))
   end
  end
  for i,c in ipairs(s.F and s.F.columns or{})do
   local f=s.flared[i]
   if f and t>=f and t-f<M.T.flare then
    local a=t-f;local k=(1-a/M.T.flare)*min(1,a/.15)
    g.setColor(1,.55,.20,.16*k)
    R.draw(K.cross,K.soft,Mat4.mul(Mat4.translate(c.x,c.y+16,c.z),Mat4.scale(20,30,20)))
   end
  end
  if s.sealT and t>=s.sealT then
   local a=t-s.sealT
   local k=min(1,a/.3)*(.75+.25*sin(t*3.1))
   g.setColor(1,.42,.12,.14*k)
   R.draw(K.cross,K.soft,Mat4.mul(Mat4.translate(M.SEAL[1],2,M.SEAL[2]),Mat4.scale(30,5,30)))
  end
  if s.slamT and t-s.slamT<.9 then
   local a=t-s.slamT
   g.setColor(1,.62,.25,.45*(1-a/.9))
   R.draw(K.cross,K.soft,Mat4.mul(Mat4.translate(M.GATE[1],3,M.GATE[2]),Mat4.scale(18+a*90,3,18+a*60)))
  end
  -- the flame's heat, and the sparks
  if B and tex then
   local id=Mat4.translate(0,0,0)
   for i,b in ipairs(B.core)do
    if b and b.used>0 then g.setColor(1,1,1,M.CORE[i]);R.draw(b.mesh,tex,id)end
   end
   for i,b in ipairs(B.spark)do
    if b and b.used>0 then g.setColor(1,1,1,M.SPARK[i]);R.draw(b.mesh,tex,id)end
   end
  end
  -- lightning on cue
  for i=#s.strikes,1,-1 do
   local b=s.strikes[i]
   if t-b.t>.7 then table.remove(s.strikes,i)else drawBolt(K,R,Mat4,g,b,t)end
  end
 end)
 g.setColor(1,1,1,1)
end

------------------------------------------------------------------ the HUD
function M.drawHud()
 local s=active
 if not s then return end
 local g=love.graphics
 local W,H=g.getDimensions()
 local t=now()
 g.origin();g.setShader();g.setScissor();pcall(g.setDepthMode);g.setBlendMode('alpha')
 -- the film's bars (thinner while a text box is up, clear of it)
 local L=smooth(s.letter or 0)
 if L>0 then
  local frac=lerp(M.BARS,M.BARS_TALK,smooth(s.talkBars or 0))
  local bh=H*frac*L
  g.setColor(0,0,0,1);g.rectangle('fill',0,0,W,bh);g.rectangle('fill',0,H-bh,W,bh)
 end
 -- the title
 if s.titleT and t>=s.titleT and t<s.titleT+M.T.titleHold+.8 then
  local a=t-s.titleT
  local k=min(1,a/.45)*(1-max(0,a-M.T.titleHold)/.8)
  local fS=smallFont(H*.028)
  local fB=bigFont(H*.13)
  local x=W*.07
  local y=H*.55
  if fS then
   g.setFont(fS);g.setColor(.98,.76,.32,k)
   printSpaced(g,fS,'ELITE FOUR',x,y,H*.012)
  end
  if fB then
   g.setFont(fB)
   g.setColor(.55,.05,.03,.6*k);g.print('LANCE',x+3,y+H*.035+3)
   g.setColor(1,.96,.90,k);g.print('LANCE',x,y+H*.035)
  end
  if fS and fB then
   local yy=y+H*.035+fB:getHeight()+H*.004
   g.setColor(.98,.76,.32,k);g.rectangle('fill',x,yy,spacedWidth(fS,'THE DRAGON MASTER',H*.012),max(2,H*.003))
   g.setFont(fS);g.setColor(1,.92,.80,k)
   printSpaced(g,fS,'THE DRAGON MASTER',x,yy+H*.012,H*.012)
  end
 end
 -- the skip hint
 if s.film and(s.film.kind=='walkin'or s.film.kind=='follow')and t<s.hintUntil then
  local f=smallFont(H*.024)
  if f then
   g.setFont(f)
   local msg='HOLD A TO SKIP'
   local fw=f:getWidth(msg)
   local p=s.held>0 and min(1,s.held/M.T.skipHold)or 0
   g.setColor(1,1,1,.85);g.print(msg,W-fw-H*.04,H-(H*M.BARS*L)-f:getHeight()-H*.02)
   if p>0 then g.setColor(1,.85,.35,.95);g.rectangle('fill',W-fw-H*.04,H-(H*M.BARS*L)-H*.012,fw*p,3)end
  end
 end
 g.setColor(1,1,1,1)
end

------------------------------------------------------------------ the camera
function M.rig(state)
 local s=active
 if not(s and s.film)then return nil end
 if state and state.battle then return nil end
 local ok,cam=pcall(s.film.camera,s.film,s.P or s:playerPos(),now())
 return ok and cam or nil
end
-- the glide from the film's last frame into your own camera.
-- TEST225: where the wake ends you stand just inside the gate, with the
-- shut gate at your back: a third-person camera has no room behind you, so
-- it is pressed into your head (the glide went in through your hat, and
-- your partner's face filled the screen). So in third person, while there
-- is no room, the film hands over to a view of its own from just over your
-- head, up the hall to Lance (it follows you); once you have walked out far
-- enough for your camera to stand behind you, it glides into that. In first
-- person the glide goes straight to your eyes, arcing over you on the way.
M.OVERHEAD={up=40,back=-2,look=18,ahead=86,fov=55}
M.T.recover=1.0
local function overHead(P)
 local O=M.OVERHEAD
 return{eye={P[1],(P[2]or 0)+O.up,P[3]+O.back},focus={P[1],(P[2]or 0)+O.look,P[3]-O.ahead},fov=rad(O.fov)}
end
M.overHead=overHead
local function mix(a,b,k)
 return{eye=lerp3(a.eye,b.eye,k),focus=lerp3(a.focus,b.focus,k),
  fov=lerp(tonumber(a.fov)or rad(55),tonumber(b.fov)or tonumber(a.fov)or rad(55),k)}
end
-- is your own third-person camera pressed into your head?
local function boomPressed()
 local ok,TP=pcall(V.require,'ThirdPerson')
 if not(ok and type(TP)=='table'and TP.selected)then return false,false end
 local okS,third=pcall(TP.selected)
 if not(okS and third)then return false,false end
 return(tonumber(TP.len)or 0)<(tonumber(TP.SHOW_AT)or 28),true
end
M.boomPressed=boomPressed
function M.handback(state,r1)
 local s=active
 local hb=s and s.handback
 if not hb then return nil end
 if state and state.battle then return nil end
 if not(type(r1)=='table'and r1.eye and r1.focus)then s.handback=nil;return nil end
 local t=now()
 local u=(t-hb.t0)/hb.dur
 local k=smooth(min(1,u))
 local pressed,third=boomPressed()
 local P=s.P or s:playerPos()
 -- where the glide is going: your camera, or (no room behind you) the view
 -- over your head until there is, then a glide from it into yours
 local target=r1
 if third and pressed and not hb.recoverT then
  -- (pressed in only now, part way through the glide -- the gate shut
  -- just after a skip, or third person chosen mid-glide: the glide starts
  -- again from where the camera is, so it does not jump)
  if not hb.over and hb.last then
   hb.from=hb.last;hb.t0=t;u=0;k=0
  end
  hb.over=true;hb.room=0
 elseif hb.over and not hb.recoverT then
  -- (room for a few frames running, not a flicker)
  hb.room=(hb.room or 0)+1
  if hb.room>=4 or not third then hb.recoverT=t end
 end
 if hb.over then
  -- (TEST229: the crane's view, you in it, rather than one from over your head)
  local o=SHOT.follow(P)
  if hb.recoverT then
   local v=smooth((t-hb.recoverT)/M.T.recover)
   if v>=1 and u>=1 then s.handback=nil;return nil end
   target=mix(o,r1,v)
  else
   target=o
  end
 elseif u>=1 then s.handback=nil;return nil end
 local f=hb.from
 local cam=mix(f,target,k)
 -- (first person: an arc over you and your partner on the way in)
 if not hb.over then cam.eye[2]=cam.eye[2]+12*sin(pi*k)end
 hb.last={eye={cam.eye[1],cam.eye[2],cam.eye[3]},focus={cam.focus[1],cam.focus[2],cam.focus[3]},fov=cam.fov}
 return{eye=cam.eye,focus=cam.focus,fov=cam.fov,up={0,1,0},curve=(tonumber(r1.curve)or 0)*k}
end

------------------------------------------------------------------ hooks
local function inRoom(game)
 local ow=game and game.overworld
 return ow and ow.map and tostring(ow.map.id)==M.ROOM
end
-- TEST227: standing still under a text box. A step that lands on a script's
-- trigger (Lance's own, beside him; Oak's at the edge of Pallet's grass; a
-- rival's) opens its text in the same frame, and the engine's `stepLanded`
-- -- meant to last for the one draw after the step -- then stays set until
-- the overworld runs again, which it does not while the box is up. The
-- engine's own sprite already stands still under a box (Player:walkPhase);
-- a 3D player model that reads stepLanded as walking ran on the spot through
-- the whole speech. So, as walkPhase does: under a box, a player who is not
-- in the middle of a step has landed, and is not pushing against a wall.
function M.settleUnderText(game)
 local ow=game and game.overworld
 local p=ow and ow.player
 if type(p)~='table'or p.moving then return false end
 if not(p.stepLanded or(tonumber(p.bumpFrames)or 0)>0)then return false end
 local stack=game.stack
 local top=stack and stack.top and stack:top()
 if top==nil or top==ow or(type(top)=='table'and top.isOverworld)then return false end
 p.stepLanded=false
 p.bumpFrames=nil
 return true
end
function M.update(game,dt)
 pcall(M.settleUnderText,game)
 if inRoom(game)then
  if not active or active.game~=game then
   local ok3d=false
   pcall(function()
    local R=V.require('Voxel3D');ok3d=R.available and R.available()and true or false
    local okS,Voxel=pcall(V.require,'VoxelState')
    if okS and Voxel and Voxel.active and not Voxel.active()then ok3d=false end
   end)
   if ok3d then
    local okN,r=pcall(Room.new,game,game.overworld.map)
    if okN and r and r.F then active=r end
   end
  end
  if active then
   local ok,err=pcall(active.update,active,dt)
   if not ok then log('update failed: %s',tostring(err));pcall(active.endFilm,active,now());active=nil;M.pacing=false end
  end
 elseif active then
  -- out of the room (only a soft reset can do that mid-film): let it all go
  pcall(active.endFilm,active,now(),true)
  if active then active.handback=nil end
  active=nil
  M.pacing=false
 end
end
function M.onEngaged(payload)
 local s=active
 local npc=payload and payload.npc
 if not(s and npc and npc.def)then return end
 if npc.def.name=='LANCESROOM_LANCE'or npc.def.sprite=='SPRITE_LANCE'then
  pcall(s.faceoff,s,now())
 end
end
-- the battle coming up ends the face-off; its first wipe gets the dragons'
-- send-off. (Text boxes, and anything else that is not the battle, leave it.)
local function isBattle(st)
 local okB,BS=pcall(require,'src.battle.BattleState')
 if okB and BS and getmetatable(st)==BS then return true end
 return type(st)=='table'and(st.battle==true or st.isBattle==true)
end
local function isWipe(st)
 local okT,BT=pcall(require,'src.render.BattleTransition')
 return okT and BT and getmetatable(st)==BT
end
M.isBattle,M.isWipe=isBattle,isWipe
function M.onPushed(payload)
 local s=active
 if not(s and s.film and s.film.kind=='faceoff')then return end
 local st=payload and payload.state
 if st==nil or st==s.hold then return end
 if isWipe(st)then pcall(s.sendoff,s,now());return end
 if isBattle(st)then pcall(s.endFilm,s,now());s.handback=nil end
end
function M.active()return active~=nil end
M._room=function()return active end

local FP,origFrame=nil,nil
local Fx,origFxDraw=nil,nil
local removers={}
function M.install(mod)
 if origFrame or origFxDraw then return end
 modRef=mod
 local okF,FirstPerson=pcall(V.require,'FirstPerson')
 if okF and FirstPerson and type(FirstPerson.frame)=='function'then
  FP,origFrame=FirstPerson,FirstPerson.frame
  FirstPerson.frame=function(me,cx,cy,vw,vh,posed,state,...)
   -- (TEST232: the view the 3D pass projects -- its shape is the picture's
   -- -- kept for Room:pickEye; two numbers, nothing made)
   if type(vw)=='number'and type(vh)=='number'and vw>0 and vh>0 then M.viewW,M.viewH=vw,vh end
   local r1,r2,r3=origFrame(me,cx,cy,vw,vh,posed,state,...)
   local R=V.require('Voxel3D')
   local rig=M.rig(state)
   if rig then
    R.camera=rig;lastRig=rig
    local P=active and active.P
    if P then return rig,P[1],P[3]end
    return rig,rig.focus[1],rig.focus[3]
   end
   local hb=M.handback(state,r1)
   if hb then
    R.camera=hb;lastRig=hb
    return hb,r2,r3
   end
   if lastRig and R.camera==lastRig then R.camera=nil end
   lastRig=nil
   return r1,r2,r3
  end
 end
 local okX,RoomFx=pcall(V.require,'LeagueRoomFx')
 if okX and RoomFx and type(RoomFx.draw)=='function'then
  Fx,origFxDraw=RoomFx,RoomFx.draw
  RoomFx.draw=function(state,...)
   local r=origFxDraw(state,...)
   if active and state and state.map and tostring(state.map.id)==M.ROOM then pcall(M.drawWorld,state)end
   return r
  end
 end
 if mod and mod.hooks and mod.hooks.wrap then
  removers[#removers+1]=mod.hooks:wrap('core.update',function(nxt,game,dt)
   pcall(M.update,game,dt)
   return nxt(game,dt)
  end)
  removers[#removers+1]=mod.hooks:wrap('movement.speed',function(nxt,frames,ctx)
   local f=nxt(frames,ctx)
   if M.pacing and ctx and ctx.player and not ctx.onBike then return max(1,floor((tonumber(f)or 16)*M.WALK_SCALE+.5))end
   return f
  end)
  removers[#removers+1]=mod.hooks:wrap('render.hud',function(nxt,game,viewport)
   local a,b,c=nxt(game,viewport)
   if active then love.graphics.push('all');pcall(M.drawHud);love.graphics.pop()end
   return a,b,c
  end)
  -- the room's music steps back while the film plays
  removers[#removers+1]=mod.hooks:wrap('music.volume',function(nxt,vol,ctx)
   local v=nxt(vol,ctx)
   local s=active
   if s and s.film and s.film.kind=='walkin'and tonumber(v)then
    local duck=.6
    if s.titleT then
     local a=now()-s.titleT
     if a>-.3 and a<M.T.titleHold then duck=.35 end
    end
    return v*duck
   end
   return v
  end)
 end
 if mod and mod.events and mod.events.on then
  local ok1,u1=pcall(mod.events.on,mod.events,'world.trainer_engaged',function(p)pcall(M.onEngaged,p)end)
  if ok1 and type(u1)=='function'then removers[#removers+1]=u1 end
  local ok2,u2=pcall(mod.events.on,mod.events,'screen.pushed',function(p)pcall(M.onPushed,p)end)
  if ok2 and type(u2)=='function'then removers[#removers+1]=u2 end
 end
end
function M.dispose()
 if active then pcall(active.endFilm,active,now());active.handback=nil end
 active=nil;M.pacing=false
 if FP and origFrame then FP.frame=origFrame end
 if Fx and origFxDraw then Fx.draw=origFxDraw end
 FP,origFrame,Fx,origFxDraw=nil,nil,nil,nil
 for _,r in ipairs(removers)do pcall(r)end
 removers={}
 pcall(function()local R=V.require('Voxel3D');if lastRig and R.camera==lastRig then R.camera=nil end end)
 lastRig=nil
 for _,v in ipairs(voices)do pcall(v.stop,v);pcall(v.release,v)end
 voices={};queue={}
 for _,src in pairs(SFX)do if src then pcall(src.release,src)end end
 SFX={}
 if bufs then
  for _,list in pairs(bufs)do for _,b in ipairs(list)do if b and b.mesh then pcall(b.mesh.release,b.mesh)end end end
 end
 bufs=nil
 if atlasImg then pcall(atlasImg.release,atlasImg)end
 atlasImg=nil
 filledAt=nil
 if M.boltStream and M.boltStream.mesh then pcall(M.boltStream.mesh.release,M.boltStream.mesh)end
 M.boltStream=nil
 M.viewW,M.viewH=nil,nil
 modRef=nil
end
return M
