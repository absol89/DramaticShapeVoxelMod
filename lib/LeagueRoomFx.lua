-- TEST172: what moves and glows in the League's rooms (LeagueRooms).
--   fire     braziers, sconces and hearths: warm, ice-blue or violet
--   candles  guttering on graves and chandeliers
--   snow     Lorelei's: falling through the whole palace
--   aurora   Lorelei's sky: curtains of green and violet light
--   sparkle  the crystals glinting
--   mist     creeping along the floor (Lorelei's lake, Agatha's crypt)
--   wisps    Agatha's ghost lights drifting between the graves
--   embers   sparks off the braziers; out of Lance's abyss, a storm of them
--   beams    light falling through lanterns, oculi, windows and doors
--   spots    spotlights sweeping a floor or the night sky
--   motes    dust and gold turning in the light
--   lava     Lance's molten sea breathing light; lightning in his storm
--   confetti and FIREWORKS in the Hall of Fame (with their sound), the
--            fanfare when you walk in
-- and every room's soundscape (LeagueAmbience). Presentation only.
local V=...
local Mat4=V.require("Mat4")
local Voxel3D=V.require("Voxel3D")
local M={REVISION='league-room-fx-172'}
local pi,cos,sin,floor,min,max,abs,sqrt=math.pi,math.cos,math.sin,math.floor,math.min,math.max,math.abs,math.sqrt
local function rh(a,b,s)local v=sin(a*12.9898+b*78.233+s*37.719)*43758.5453;return v-floor(v)end
local function TR(x,y,z)return Mat4.translate(x,y,z)end

------------------------------------------------------------------ streams
-- particle streams: one mesh, rewritten each frame, one draw
local streams={}
local function stream(name,n)
 name=name..':'..n
 local s=streams[name]
 if s==nil then
  local Road=V.require("LeagueRoad")
  local K=Road.fxKit()
  s=K.newStream(n) or false
  streams[name]=s
 end
 return s or nil
end
-- ribbons: vertical strips along a path (the aurora)
local strips={}
local function strip(name,n)
 name=name..':'..n
 local s=strips[name]
 if s==nil then
  s=false
  local verts={}
  for i=1,n*4 do verts[i]={0,0,0,0,0,1}end
  local ok,m=pcall(love.graphics.newMesh,Voxel3D.FORMAT,verts,"triangles","stream")
  if ok and m then
   local idx={};for q=0,n-1 do Voxel3D.pushQuad(idx,q)end
   pcall(m.setVertexMap,m,idx)
   s={mesh=m,verts=verts,n=n}
  end
  strips[name]=s
 end
 return s or nil
end

-- flames in bulk: every candle and every small or distant fire of one
-- colour is one stream (two crossed quads each), drawn in one call
local function putFlame(sm,i,x,y,z,w,h)
 local v=sm.verts;local b=i*8;local e
 e=v[b+1];e[1],e[2],e[3],e[4],e[5]=x-w,y,z,0,0
 e=v[b+2];e[1],e[2],e[3],e[4],e[5]=x+w,y,z,1,0
 e=v[b+3];e[1],e[2],e[3],e[4],e[5]=x+w,y+h,z,1,1
 e=v[b+4];e[1],e[2],e[3],e[4],e[5]=x-w,y+h,z,0,1
 e=v[b+5];e[1],e[2],e[3],e[4],e[5]=x,y,z-w,0,0
 e=v[b+6];e[1],e[2],e[3],e[4],e[5]=x,y,z+w,1,0
 e=v[b+7];e[1],e[2],e[3],e[4],e[5]=x,y+h,z+w,1,1
 e=v[b+8];e[1],e[2],e[3],e[4],e[5]=x,y+h,z-w,0,1
end
local function clearFrom(sm,i)
 local v=sm.verts
 for k=i*8+1,sm.n*8 do local e=v[k];e[1],e[2],e[3]=0,-9999,0 end
end

------------------------------------------------------------------ pieces
local PAL={
 warm=nil,
 ice={{2.5,6.4,.30,.58,1,.70},{1.75,4.9,.55,.82,1,.80},{1.0,3.2,.90,.98,1,.85}},
 violet={{2.5,6.4,.62,.25,1,.70},{1.75,4.9,.80,.50,1,.80},{1.0,3.2,.97,.85,1,.85}},
}
local GLOW={warm={1,.55,.22},ice={.35,.62,1},violet={.70,.35,1}}
local COL={warm={1,.62,.28},ice={.35,.65,1},violet={.70,.35,1},gold={1,.82,.40},white={.95,.95,1},
 green={.30,1,.55},cyan={.55,.95,1},red={1,.30,.10}}
local function flameBody(K,g,x,y,z,t,ph,s,pal)
 if not pal then return K.flameBody(g,K.flame,x,y,z,t,ph,s)end
 local fl=.86+.09*sin(t*9.3+ph)+.06*sin(t*15.1+ph*1.7)
 local sway=sin(t*2.3+ph)*.10
 for li,L in ipairs(pal)do
  local f=li==1 and fl or(.9+.1*sin(t*11+ph*2+li))
  for k=0,2 do
   local rot=k*pi/3+ph+li*.4
   local m=Mat4.mul(TR(x,y-.2*s,z),Mat4.mul(Mat4.rotateZ(sway),
    Mat4.mul(Mat4.rotateY(rot),Mat4.mul(Mat4.translate(0,L[2]*s*f*.5,0),Mat4.scale(L[1]*s,L[2]*s*f*.5,L[1]*s)))))
   g.setColor(L[3],L[4],L[5],L[6]);Voxel3D.draw(K.cross,K.flame,m)
  end
 end
end
local function flameGlow(K,g,x,y,z,t,ph,s,col)
 if not col or col=='warm'then return K.flameGlow(g,K.soft,x,y,z,t,ph,s,.6)end
 local c=GLOW[col]or GLOW.warm
 local fl=.85+.10*sin(t*7.7+ph)
 g.setColor(c[1],c[2],c[3],.40*fl)
 Voxel3D.draw(K.cross,K.soft,Mat4.mul(TR(x,y+2.4*s,z),Mat4.scale(9*s,9*s,9*s)))
 g.setColor(c[1],c[2],c[3],.40*fl)
 Voxel3D.draw(K.quad,K.soft,Mat4.mul(TR(x,y+.3,z),Mat4.scale(4.2*s,1,4.2*s)))
 for i=0,3 do
  local life=(t*1.7+i*.25+ph*.13)%1
  local a=i*1.9+ph
  local r=(1-life)*.9*s
  local sz=(1-life)*1.3*s+.25
  g.setColor(min(1,c[1]+.3),min(1,c[2]+.3),min(1,c[3]+.2),(1-life)*.7)
  Voxel3D.draw(K.cross,K.soft,Mat4.mul(TR(x+cos(a+t*2)*r,y+(3.5+life*6)*s,z+sin(a+t*2)*r),Mat4.scale(sz,sz*1.4,sz)))
 end
end
-- a cone from (x,y,z) to (tx,ty,tz): coneMesh opens along +Y
local function cone(ox,oy,oz,tx,ty,tz,rad)
 local dx,dy,dz=tx-ox,ty-oy,tz-oz
 local len=sqrt(dx*dx+dy*dy+dz*dz);if len<1e-3 then return nil end
 dx,dy,dz=dx/len,dy/len,dz/len
 local ux,uy,uz=dz,0,-dx
 local ul=sqrt(ux*ux+uz*uz);if ul<1e-4 then ux,uy,uz,ul=1,0,0,1 end
 ux,uz=ux/ul,uz/ul
 local wx,wy,wz=uy*dz-uz*dy,uz*dx-ux*dz,ux*dy-uy*dx
 return {ux*rad,dx*len,wx*rad,ox, uy*rad,dy*len,wy*rad,oy, uz*rad,dz*len,wz*rad,oz, 0,0,0,1}
end

------------------------------------------------------------------ the draw
local entered={}   -- room id -> time we walked in (the Hall of Fame's fanfare)
local lastId=nil
local kit=nil      -- LeagueRoad's effect kit (textures, unit meshes)
local full={}      -- this frame's near, big fires
local batch={warm={},violet={},ice={}}
local batchN={warm=0,violet=0,ice=0}
local BODY={warm={1,.82,.42},violet={.78,.55,1},ice={.55,.80,1}}
local HALO={warm={1,.64,.28},violet={.70,.40,1},ice={.40,.65,1}}
function M.draw(state,Rooms)
 local map=state and state.map
 if not map then return false end
 -- TEST173: the town interiors (InteriorRooms) hand in their own rooms
 Rooms=Rooms or V.require("LeagueRooms")
 local fx,r=Rooms.fx(map,Voxel3D.eye)
 if not fx then return false end
 local id=tostring(map.id)
 local g=love.graphics
 local Road=V.require("LeagueRoad")
 if not(kit and kit.soft and kit.cross)then kit=Road.fxKit()end
 local K=kit
 if not(K.white and K.soft and K.cross and K.quad)then kit=nil;return false end
 local t=0;pcall(function()t=love.timer.getTime()end)
 local eye=Voxel3D.eye or {r.W/2,30,r.D}
 local above=(eye[2]or 0)>=(r.H or 90)
 local p=state.player
 local px,pz=(p and p.px or 0)+8,(p and p.py or 0)+8
 -- a new room (not a pause or a menu) is a new entrance
 if id~=lastId then entered[id]=t;lastId=id;fx._played=nil end
 if not state.battle then
  Rooms.player={px,pz}
  -- build the next room in line, a slice a frame
  pcall(Rooms.step,id)
 end
 local since=t-(entered[id]or t)

 ---------------------------------------------------------------- sound
 local okA,Amb=pcall(V.require,"LeagueAmbience")
 if okA and Amb and fx.ambience then
  if state.battle then
   -- under the battle music, the room is only a breath of itself
   local q={};for k,v in pairs(fx.ambience)do q[k]=v*.45 end
   -- (TEST196: a stadium's murmur rises and falls with its stands)
   if q.crowd and Rooms.crowdBed then
    local okB,kb=pcall(Rooms.crowdBed)
    if okB and tonumber(kb)then q.crowd=q.crowd*kb end
   end
   pcall(Amb.touch,q)
  else pcall(Amb.touch,fx.ambience)end
 end

 -- sort the flames: near, big fires get the full treatment; candles,
 -- small fires and far ones are batched by colour (reused tables: this
 -- runs every frame)
 local nfull=0
 for k in pairs(batchN)do batchN[k]=0 end
 local function add(col,x,y,z,s,ph,fire)
  local key=batch[col]and col or'warm'
  local n=batchN[key]+1;batchN[key]=n
  local e=batch[key][n]
  if not e then e={};batch[key][n]=e end
  e[1],e[2],e[3],e[4],e[5],e[6]=x,y,z,s,ph,fire
 end
 local ex,ey,ez=eye[1]or 0,eye[2]or 0,eye[3]or 0
 for _,f in ipairs(fx.fires or{})do
  local dx,dy,dz=f.x-ex,f.y-ey,f.z-ez
  local d2=dx*dx+dy*dy+dz*dz
  -- (TEST195: a fire may ask to be batched whatever its size: the flames
  -- on Lance's lake of fire, dozens of them, one draw)
  if (f.s or 1)>=.8 and not f.batch and d2<170*170 then nfull=nfull+1;full[nfull]=f
  else add(f.col or'warm',f.x,f.y,f.z,(f.s or 1)*1.35,f.phase or 0,true)end
 end
 for i=#full,nfull+1,-1 do full[i]=nil end
 for _,c in ipairs(fx.candles or{})do
  if not(above and c.ceil)then add(c.col or'warm',c.x,c.y,c.z,c.s,c.phase or 0,false)end
 end

 ---------------------------------------------------------------- alpha
 pcall(Voxel3D.withEffect,"alpha",function()
  for _,f in ipairs(full)do flameBody(K,g,f.x,f.y,f.z,t,f.phase or 0,f.s or 1,PAL[f.col or'warm'])end
  for col,list in pairs(batch)do
   local cnt=batchN[col]
   if cnt>0 then
    local sm=stream('flames-'..col,cnt<=48 and 48 or(cnt<=160 and 160 or 400))
    if sm then
     local n=min(cnt,sm.n)
     for i=1,n do
      local c=list[i]
      local fl=.86+.14*sin(t*12.7+c[5])
      if c[6]then
       putFlame(sm,i-1,c[1],c[2]-.2,c[3],1.3*c[4],4.6*c[4]*fl)
      else
       putFlame(sm,i-1,c[1],c[2],c[3],.42*c[4],2.1*c[4]*fl)
      end
     end
     clearFrom(sm,n)
     pcall(sm.mesh.setVertices,sm.mesh,sm.verts)
     local bc=BODY[col];g.setColor(bc[1],bc[2],bc[3],.95)
     Voxel3D.draw(sm.mesh,K.flame,TR(0,0,0))
    end
   end
  end
  -- mist: soft sheets drifting low over the floor
  local MI=fx.mist or{}
  if #MI>0 then
   local sm=stream('mist',32)
   if sm then
    local n=0
    for _,m in ipairs(MI)do
     if n<31 then
      local d=m.drift or 10
      local x=m.x+sin(t*.07+m.phase)*d;local z=m.z+cos(t*.05+m.phase*1.3)*d
      local k=.85+.15*sin(t*.3+m.phase)
      K.streamPut(sm,n,x,m.y,z,m.r*k,true);n=n+1
      K.streamPut(sm,n,x+m.r*.4,m.y+1.4,z-m.r*.3,m.r*.7*k,true);n=n+1
     end
    end
    clearFrom(sm,n)
    pcall(sm.mesh.setVertices,sm.mesh,sm.verts)
    local c=MI[1].col or{1,1,1}
    g.setColor(c[1],c[2],c[3],MI[1].a or .1)
    Voxel3D.draw(sm.mesh,K.soft,TR(0,0,0))
   end
  end
  -- TEST174: incense smoke: thin curls climbing from a stick or a burner,
  -- swelling and thinning as they go
  local SMK=fx.smoke or{}
  if #SMK>0 then
   local per=5
   local cnt=min(#SMK*per,200)
   local sm=stream('smoke',cnt<=60 and 60 or 200)
   if sm then
    local n=0
    for si,s in ipairs(SMK)do
     for k=0,per-1 do
      if n<sm.n then
       local life=(t*(s.speed or .20)+k/per+rh(si,k,4))%1
       local y=s.y+life*(s.h or 22)
       local sw=1+life*3
       local fade=life<.8 and 1 or (1-life)/.2
       K.streamPut(sm,n,s.x+sin(t*1.1+si+life*5)*sw,y,s.z+cos(t*.9+si*1.3+life*4)*sw*.7,(s.s or 1)*(.5+life*1.6)*fade,false);n=n+1
      end
     end
    end
    clearFrom(sm,n)
    pcall(sm.mesh.setVertices,sm.mesh,sm.verts)
    local c=SMK[1].col or{.86,.82,.95}
    g.setColor(c[1],c[2],c[3],SMK[1].a or .16)
    Voxel3D.draw(sm.mesh,K.soft,TR(0,0,0))
   end
  end
  -- snow
  local S=fx.snow
  if S then
   local sm=stream('snow',S.n)
   if sm then
    local H=S.y1-S.y0
    for i=0,S.n-1 do
     local sp=6+rh(i,1,3)*7
     local y=S.y1-((t*sp+rh(i,2,5)*H)%H)
     local x=S.x0+rh(i,3,7)*(S.x1-S.x0)+sin(t*.8+i)*3.2
     local z=S.z0+rh(i,4,9)*(S.z1-S.z0)+cos(t*.6+i*1.3)*3.2
     K.streamPut(sm,i,x,y,z,.55+rh(i,5,11)*.45,false)
    end
    pcall(sm.mesh.setVertices,sm.mesh,sm.verts)
    g.setColor(.95,.97,1,.85)
    Voxel3D.draw(sm.mesh,K.soft,TR(0,0,0))
   end
  end
  -- TEST173: aquarium fish, darting and turning in their tanks
  for ti,tk in ipairs(fx.fish or{})do
   for k=0,(tk.n or 4)-1 do
    local ph=rh(ti,k,3)*6.283
    local sp=.35+rh(ti,k,5)*.4
    local u=sin(t*sp+ph)
    local x=tk.x+u*tk.w*.42
    local y=tk.y+sin(t*.7+ph*2)*tk.h*.25+(rh(ti,k,7)-.5)*tk.h*.4
    local z=tk.z+(rh(ti,k,9)-.5)*tk.d*.6
    if tk.axis=='z'then x,z=tk.x+(rh(ti,k,9)-.5)*tk.d*.6,tk.z+u*tk.w*.42 end
    local dir=cos(t*sp+ph)>=0 and 1 or -1
    local c=({{1,.55,.15},{1,.85,.25},{.35,.65,1},{1,1,1},{1,.35,.45}})[(ti+k)%5+1]
    local s=(tk.s or 1)*(.8+rh(ti,k,11)*.5)
    g.setColor(c[1],c[2],c[3],.95)
    Voxel3D.draw(K.cross,K.soft,Mat4.mul(TR(x,y,z),Mat4.scale(2.2*s,.9*s,.9*s)))
    g.setColor(c[1],c[2],c[3],.8)
    if tk.axis=='z'then Voxel3D.draw(K.cross,K.soft,Mat4.mul(TR(x,y,z-dir*1.9*s),Mat4.scale(.5*s,.9*s,.8*s)))
    else Voxel3D.draw(K.cross,K.soft,Mat4.mul(TR(x-dir*1.9*s,y,z),Mat4.scale(.8*s,.9*s,.5*s)))end
   end
   -- a rising string of bubbles
   for k=0,5 do
    local life=(t*.45+k/6+ti*.3)%1
    g.setColor(.85,.95,1,.55*(1-life))
    local bx,bz=tk.x+tk.w*.3+sin(t*2+k)*.6,tk.z
    if tk.axis=='z'then bx,bz=tk.x,tk.z+tk.w*.3+sin(t*2+k)*.6 end
    Voxel3D.draw(K.cross,K.soft,Mat4.mul(TR(bx,tk.y-tk.h*.45+life*tk.h*.9,bz),Mat4.scale(.45,.45,.45)))
   end
  end
  -- TEST173: a pool's surface: clear teal over the mosaic, light sliding
  -- across it
  local WA=fx.water
  if WA and #WA>0 then
   local sm=stream('water',WA.n2 or(#WA<=64 and 64 or 256))
   if sm then
    local n=min(#WA,sm.n)
    for i=1,n do local w=WA[i];K.streamPut(sm,i-1,w.x,w.y,w.z,w.r,true)end
    clearFrom(sm,n)
    pcall(sm.mesh.setVertices,sm.mesh,sm.verts)
    g.setColor(.10,.42,.52,.50)
    Voxel3D.draw(sm.mesh,K.white,TR(0,0,0))
   end
   local sh=stream('watershine',32)
   if sh then
    local n=0
    for i=1,#WA,max(1,floor(#WA/16))do
     if n<31 then
      local w=WA[i]
      K.streamPut(sh,n,w.x+sin(t*.5+i)*5,w.y+.05,w.z+cos(t*.43+i*1.3)*5,w.r*.9,true);n=n+1
     end
    end
    clearFrom(sh,n)
    pcall(sh.mesh.setVertices,sh.mesh,sh.verts)
    g.setColor(.75,.95,1,.10)
    Voxel3D.draw(sh.mesh,K.soft,TR(0,0,0))
   end
  end
  -- TEST179: roof glass (the greenhouse): a faint pane over the sky, a
  -- streak of light across each. Follow the roof's overhead cutaway.
  if K.quad and not above then
   for _,gl in ipairs(fx.roofGlass or{})do
    local w,d=gl.x1-gl.x0,gl.z1-gl.z0
    g.setColor(.82,.92,1,.07)
    Voxel3D.draw(K.quad,K.white,Mat4.mul(TR((gl.x0+gl.x1)/2,gl.y,(gl.z0+gl.z1)/2),Mat4.scale(w/2,1,d/2)))
    g.setColor(1,1,1,.09)
    Voxel3D.draw(K.quad,K.white,Mat4.mul(TR(gl.x0+w*.3,gl.y-.05,(gl.z0+gl.z1)/2),Mat4.scale(w*.04,1,d/2)))
   end
  end
  -- TEST173: display glass, a soft sheen with a highlight running down it
  if K.panel then
   for _,gl in ipairs(fx.glass or{})do
    g.setColor(.80,.92,1,.10)
    Voxel3D.draw(K.panel,K.white,Mat4.mul(TR(gl.x0,gl.y0,gl.z),Mat4.scale(gl.x1-gl.x0,gl.y1-gl.y0,1)))
    local w=gl.x1-gl.x0
    for k=0,1 do
     g.setColor(1,1,1,.16-.06*k)
     Voxel3D.draw(K.panel,K.white,Mat4.mul(TR(gl.x0+w*(.18+k*.08),gl.y0,gl.z+.05),Mat4.scale(w*(.06-k*.03),gl.y1-gl.y0,1)))
    end
   end
  end
  -- confetti: tumbling paper in five colours
  local Cf=fx.confetti
  if Cf then
   local cols={{1,.22,.25},{1,.84,.25},{.30,.55,1},{.35,.90,.45},{1,1,1}}
   local per=floor(Cf.n/#cols)
   local H=Cf.y1-Cf.y0
   for ci,c in ipairs(cols)do
    local sm=stream('confetti'..ci,per)
    if sm then
     for i=0,per-1 do
      local k=i*7+ci
      local sp=7+rh(k,1,3)*6
      local y=Cf.y1-((t*sp+rh(k,2,5)*H)%H)
      local x=Cf.x0+rh(k,3,7)*(Cf.x1-Cf.x0)+sin(t*1.3+k)*4
      local z=Cf.z0+rh(k,4,9)*(Cf.z1-Cf.z0)+cos(t*1.1+k*.7)*4
      local flat=(floor(t*3+k)%2)==0
      K.streamPut(sm,i,x,y,z,.7,flat)
     end
     pcall(sm.mesh.setVertices,sm.mesh,sm.verts)
     g.setColor(c[1],c[2],c[3],.95)
     Voxel3D.draw(sm.mesh,K.white,TR(0,0,0))
    end
   end
  end
 end)

 ---------------------------------------------------------------- additive
 pcall(Voxel3D.withEffect,"add",function()
  for _,f in ipairs(full)do flameGlow(K,g,f.x,f.y,f.z,t,f.phase or 0,f.s or 1,f.col)end
  for col,list in pairs(batch)do
   local cnt=batchN[col]
   if cnt>0 then
    local sm=stream('halos-'..col,cnt<=48 and 48 or(cnt<=160 and 160 or 400))
    if sm then
     local n=min(cnt,sm.n)
     for i=1,n do
      local c=list[i]
      local r=(c[6]and 7 or 3.4)*c[4]*(.94+.06*sin(t*8.3+c[5]))
      K.streamPut(sm,i-1,c[1],c[2]+(c[6]and 2 or .9)*c[4],c[3],r,false)
     end
     clearFrom(sm,n)
     pcall(sm.mesh.setVertices,sm.mesh,sm.verts)
     local hc=HALO[col];g.setColor(hc[1],hc[2],hc[3],col=='violet'and .36 or .30)
     Voxel3D.draw(sm.mesh,K.soft,TR(0,0,0))
    end
   end
  end
  for _,q in ipairs(fx.pools or{})do
   if not(above and q.ceil)then
    local c=q.col or{1,.74,.42}
    g.setColor(c[1],c[2],c[3],(q.a or .08)*(.9+.1*sin(t*1.3+q.x*.1)))
    Voxel3D.draw(K.quad,K.soft,Mat4.mul(TR(q.x,q.y,q.z),Mat4.scale(q.r,1,q.r)))
   end
  end
  for _,w in ipairs(fx.glows or{})do
   -- (TEST174: a glow up in a vault shows only from under it; TEST196: a
   -- glow that is out -- a stadium's, waiting for its moment -- costs no draw)
   if not(w.below and(eye[2]or 0)>=w.below)and(w.a or .3)>.003 then
    local c=COL[w.col or'warm']or COL.warm
    g.setColor(c[1],c[2],c[3],(w.a or .3)*(.85+.15*sin(t*1.7+w.x*.05+w.z*.03)))
    Voxel3D.draw(K.cross,K.soft,Mat4.mul(TR(w.x,w.y,w.z),Mat4.scale(w.r,w.r,w.r)))
   end
  end
  -- TEST173: electric sparks crackling round coils and the gate
  for si,sp in ipairs(fx.sparks or{})do
   local q=floor(t*14)
   for k=0,2 do
    if rh(q,si,k)>.45 then
     local a=rh(q,si,k+3)*6.283;local r=(sp.r or 6)*rh(q,si,k+7)
     local x,y,z=sp.x+cos(a)*r,sp.y+(rh(q,si,k+9)-.5)*(sp.r or 6),sp.z+sin(a)*r
     local c=sp.col or{.6,.9,1}
     g.setColor(c[1],c[2],c[3],.9)
     Voxel3D.draw(K.cross,K.soft,Mat4.mul(TR(x,y,z),Mat4.scale(.6,2.4,.6)))
     Voxel3D.draw(K.cross,K.soft,Mat4.mul(TR(x,y,z),Mat4.scale(2.4,.6,2.4)))
    end
   end
  end
  -- TEST191: arcs leaping between two coils. A jagged path through a few
  -- knots, redrawn sixteen times a second and there most of the time: a
  -- white-hot core and a wide coloured glow round it, and a flash where it
  -- lands. Two streams, two draws for every arc in the room.
  local AR=fx.arcs
  if AR and #AR>0 then
   local PER,KN=24,7
   local cap=#AR*PER<=48 and 48 or 192
   local sm,sg=stream('arcCore',cap),stream('arcGlow',cap)
   if sm and sg then
    local q=floor(t*16);local n=0
    for ai,a in ipairs(AR)do
     local on=rh(q,ai,1)>(a.rest or .3)
     if on and n+PER<=cap then
      local ax,ay,az,bx,by,bz=a.a[1],a.a[2],a.a[3],a.b[1],a.b[2],a.b[3]
      local dx,dy,dz=bx-ax,by-ay,bz-az
      local len=sqrt(dx*dx+dy*dy+dz*dz)
      if len>.5 then
       local hl=sqrt(dx*dx+dz*dz)
       local sx,sz=1,0
       if hl>.01 then sx,sz=-dz/hl,dx/hl end
       local amp=len*(a.jag or .14)
       local kx,ky,kz={},{},{}
       for k=0,KN do
        local u=k/KN;local env=sin(u*pi)
        local j1=(rh(q,ai*31+k,3)-.5)*2*amp*env
        local j2=(rh(q,ai*17+k,5)-.5)*2*amp*env
        kx[k]=ax+dx*u+sx*j1;ky[k]=ay+dy*u+env*len*(a.bow or .14)+j2;kz[k]=az+dz*u+sz*j1
       end
       local w=a.w or 1.1
       for i=0,PER-1 do
        local u=i/(PER-1)*KN;local k=min(KN-1,floor(u));local f=u-k
        local x=kx[k]+(kx[k+1]-kx[k])*f
        local y=ky[k]+(ky[k+1]-ky[k])*f
        local z=kz[k]+(kz[k+1]-kz[k])*f
        K.streamPut(sm,n,x,y,z,w,false)
        K.streamPut(sg,n,x,y,z,w*3.4,false)
        n=n+1
       end
      end
     end
    end
    clearFrom(sm,n);clearFrom(sg,n)
    if n>0 then
     pcall(sm.mesh.setVertices,sm.mesh,sm.verts);pcall(sg.mesh.setVertices,sg.mesh,sg.verts)
     local c=AR[1].col or{.55,.85,1}
     g.setColor(c[1],c[2],c[3],.30);Voxel3D.draw(sg.mesh,K.soft,TR(0,0,0))
     g.setColor(.90,.97,1,.95);Voxel3D.draw(sm.mesh,K.soft,TR(0,0,0))
     -- where each live arc lands, the coil flares
     for ai,a in ipairs(AR)do
      if rh(q,ai,1)>(a.rest or .3)then
       local fl=.6+.4*rh(q,ai,9)
       g.setColor(c[1],c[2],c[3],.34*fl)
       Voxel3D.draw(K.cross,K.soft,Mat4.mul(TR(a.a[1],a.a[2],a.a[3]),Mat4.scale(9,9,9)))
       Voxel3D.draw(K.cross,K.soft,Mat4.mul(TR(a.b[1],a.b[2],a.b[3]),Mat4.scale(9,9,9)))
      end
     end
    end
   end
  end
  -- TEST191: power running through the floor: pulses of light travelling
  -- the conduits, flat on the floor, evenly spaced, each with a short tail
  local FL=fx.flows
  if FL and #FL>0 then
   local total=0
   for _,f in ipairs(FL)do
    if not f.len then
     f.len={0}
     for i=2,#f.pts do
      local a,b=f.pts[i-1],f.pts[i]
      f.len[i]=f.len[i-1]+sqrt((b[1]-a[1])^2+(b[2]-a[2])^2)
     end
    end
    total=total+floor(f.len[#f.pts]/(f.gap or 24)+1)*3
   end
   local cap=total<=64 and 64 or(total<=200 and 200 or 600)
   local sm=stream('flows',cap)
   if sm then
    local n=0
    for fi,f in ipairs(FL)do
     local L=f.len[#f.pts];local gap=f.gap or 24
     local head=(t*(f.speed or 36)+fi*7.3)%gap
     local s=head
     while s<=L and n+3<=cap do
      for tail=0,2 do
       local d=s-tail*2.2
       if d>=0 then
        local i=2
        while i<#f.pts and f.len[i]<d do i=i+1 end
        local a,b=f.pts[i-1],f.pts[i]
        local seg=max(.001,f.len[i]-f.len[i-1])
        local u=min(1,max(0,(d-f.len[i-1])/seg))
        K.streamPut(sm,n,a[1]+(b[1]-a[1])*u,f.y or .35,a[2]+(b[2]-a[2])*u,(f.r or 2.6)*(1-tail*.28),true)
        n=n+1
       end
      end
      s=s+gap
     end
    end
    clearFrom(sm,n)
    if n>0 then
     pcall(sm.mesh.setVertices,sm.mesh,sm.verts)
     local c=FL[1].col or{.45,.95,1}
     g.setColor(c[1],c[2],c[3],.85)
     Voxel3D.draw(sm.mesh,K.soft,TR(0,0,0))
    end
   end
  end
  -- crystal glints: a slow pulse and, now and then, a star
  local SP=fx.sparkles or{}
  if #SP>0 then
   local sm=stream('sparkles',#SP<=64 and 64 or 200)
   if sm then
    local n=min(#SP,sm.n)
    for i=1,n do
     local sp=SP[i]
     local ph=(t*.35+sp.phase*.37)%1
     local tw=ph<.12 and sin(ph/.12*pi)or 0
     K.streamPut(sm,i-1,sp.x,sp.y,sp.z,(sp.soft and 9 or 3.2)*sp.s*(1+.6*tw),false)
    end
    clearFrom(sm,n)
    pcall(sm.mesh.setVertices,sm.mesh,sm.verts)
    g.setColor(.60,.92,1,.26)
    Voxel3D.draw(sm.mesh,K.soft,TR(0,0,0))
   end
  end
  for _,sp in ipairs(SP)do
   local ph=(t*.35+sp.phase*.37)%1
   local tw=ph<.12 and sin(ph/.12*pi)or 0
   if tw>0 and not sp.soft then
    g.setColor(1,1,1,.8*tw)
    Voxel3D.draw(K.cross,K.soft,Mat4.mul(TR(sp.x,sp.y,sp.z),Mat4.scale(.5*sp.s,6*sp.s*tw,.5*sp.s)))
    Voxel3D.draw(K.cross,K.soft,Mat4.mul(TR(sp.x,sp.y,sp.z),Mat4.scale(6*sp.s*tw,.5*sp.s,6*sp.s*tw)))
   end
  end
  -- wisps: ghost lights on slow figure-eights, each trailing its tail
  for _,w in ipairs(fx.wisps or{})do
   local c=w.code==6 and COL.cyan or COL.violet
   for k=0,3 do
    local tt=t-k*.18
    local x=w.x+sin(tt*.31+w.phase)*(w.range or 16)
    local z=w.z+sin(tt*.62+w.phase*1.7)*(w.range or 16)*.6
    local y=w.y+sin(tt*.9+w.phase)*3
    local s=(w.s or 1)*(k==0 and 4.2 or 2.6-k*.5)
    g.setColor(c[1],c[2],c[3],(k==0 and .55 or .30-k*.06)*(.8+.2*sin(t*5+w.phase)))
    Voxel3D.draw(K.cross,K.soft,Mat4.mul(TR(x,y,z),Mat4.scale(s,s,s)))
   end
   local x=w.x+sin(t*.31+w.phase)*(w.range or 16)
   local z=w.z+sin(t*.62+w.phase*1.7)*(w.range or 16)*.6
   g.setColor(c[1],c[2],c[3],.08)
   Voxel3D.draw(K.quad,K.soft,Mat4.mul(TR(x,.4,z),Mat4.scale(14,1,14)))
  end
  -- beams of light
  if K.cone then
   for _,b in ipairs(fx.beams or{})do
    local m=cone(b.x,b.y,b.z,b.tx,b.ty,b.tz,b.r1 or 10)
    if m then
     local c=b.col or{1,1,1}
     g.setColor(c[1],c[2],c[3],(b.a or .06)*(.85+.15*sin(t*.7+b.x*.03)))
     Voxel3D.draw(K.cone,K.soft,m)
    end
   end
   for _,s in ipairs(fx.spots or{})do
    local tx,ty,tz
    if s.sky then
     tx=s.x+sin(t*.31+s.phase)*160;ty=s.y+420;tz=s.z+cos(t*.23+s.phase*1.7)*160-60
    else
     local sw=s.sweep or 20
     tx=s.tx+sin(t*.4+s.phase)*sw;ty=0;tz=s.tz+cos(t*.33+s.phase*1.3)*sw
    end
    local m=cone(s.x,s.y,s.z,tx,ty,tz,s.sky and 26 or(s.r or 6)*2.2)
    if m then
     local c=s.col or{1,1,1}
     g.setColor(c[1],c[2],c[3],s.a or .07)
     Voxel3D.draw(K.cone,K.soft,m)
     if not s.sky then
      g.setColor(c[1],c[2],c[3],(s.a or .07)*1.5)
      Voxel3D.draw(K.quad,K.soft,Mat4.mul(TR(tx,.5,tz),Mat4.scale(14,1,14)))
     end
    end
   end
   -- TEST191: warning beacons: a cone of amber light turning round its
   -- lamp, the patch it throws sweeping the floor, the lamp throbbing
   for bi,b in ipairs(fx.beacons or{})do
    local a=t*(b.spin or 2.6)+bi*1.9
    local R=b.reach or 34
    local tx,tz=b.x+cos(a)*R,b.z+sin(a)*R
    local c=b.col or{1,.62,.18}
    local m=cone(b.x,b.y,b.z,tx,0,tz,b.r or 6)
    if m then
     g.setColor(c[1],c[2],c[3],b.a or .07)
     Voxel3D.draw(K.cone,K.soft,m)
     g.setColor(c[1],c[2],c[3],(b.a or .07)*1.4)
     Voxel3D.draw(K.quad,K.soft,Mat4.mul(TR(tx,.5,tz),Mat4.scale(12,1,12)))
    end
    g.setColor(c[1],c[2],c[3],.28+.12*sin(t*8+bi))
    Voxel3D.draw(K.cross,K.soft,Mat4.mul(TR(b.x,b.y,b.z),Mat4.scale(5.5,5.5,5.5)))
   end
  end
  -- motes turning in the light
  local Mo=fx.motes
  if Mo then
   local sm=stream('motes',Mo.n)
   if sm then
    for i=0,Mo.n-1 do
     local life=(t*.04+rh(i,1,1))%1
     local a=i*2.39996+t*.05
     local rr=Mo.r*sqrt(rh(i,2,2))
     K.streamPut(sm,i,Mo.x+cos(a)*rr,Mo.y0+life*(Mo.y1-Mo.y0),Mo.z+sin(a)*rr,.35+.25*rh(i,3,3),false)
    end
    pcall(sm.mesh.setVertices,sm.mesh,sm.verts)
    local c=Mo.col or{1,.9,.6}
    g.setColor(c[1],c[2],c[3],.55)
    Voxel3D.draw(sm.mesh,K.soft,TR(0,0,0))
   end
  end
  -- embers rising off braziers and out of the abyss
  for ei,e in ipairs(fx.embers or{})do
   local sm=stream('embers'..ei,e.n)
   if sm then
    local rise=e.rise or 30
    for i=0,e.n-1 do
     local life=(t*(e.abyss and .05 or .45)+rh(i,ei,1))%1
     local a=rh(i,ei,2)*pi*2+life*2
     local rr=e.r*(e.abyss and sqrt(rh(i,ei,3))or rh(i,ei,3))
     local x=e.x+cos(a)*rr+sin(t*.9+i)*2*life
     local z=e.z+sin(a)*rr+cos(t*.7+i)*2*life
     K.streamPut(sm,i,x,e.y+life*rise,z,(e.abyss and 1.4 or .45)*(1-life*.6),false)
    end
    pcall(sm.mesh.setVertices,sm.mesh,sm.verts)
    -- (TEST196: embers may have their own colour: Agatha's spirits)
    local ec=e.col
    if ec then g.setColor(ec[1],ec[2],ec[3],.85)else g.setColor(1,.55,.20,.85)end
    Voxel3D.draw(sm.mesh,K.soft,TR(0,0,0))
   end
  end
  -- Lance's lava: pools of light breathing on the molten sea
  if fx.lava and #fx.lava>0 then
   local y=(fx.lavaLevel or -170)+1.5
   for _,l in ipairs(fx.lava)do
    local b=.5+.5*sin(t*.6+l.phase)
    g.setColor(1,.40,.08,.10+.12*b)
    Voxel3D.draw(K.quad,K.soft,Mat4.mul(TR(l.x,y,l.z),Mat4.scale(l.r,1,l.r)))
   end
   for _,f in ipairs(fx.lavafalls or{})do
    g.setColor(1,.45,.10,.30)
    Voxel3D.draw(K.cross,K.soft,Mat4.mul(TR(f.x,y+20,f.z),Mat4.scale(40,40,40)))
   end
  end
  -- lightning in the storm: a bolt every few seconds, the sky flaring
  local Lg=fx.lightning
  if Lg then
   local per=7.3
   local cyc=floor(t/per);local age=t-cyc*per-rh(cyc,1,1)*3
   if age>=0 and age<.55 then
    local a=rh(cyc,2,2)*pi*2
    local bx,bz=Lg.x+cos(a)*Lg.r*(.6+.4*rh(cyc,3,3)),Lg.z+sin(a)*Lg.r*(.6+.4*rh(cyc,3,3))
    local flick=(age<.08 or(age>.18 and age<.26)or(age>.34 and age<.40))and 1 or .25
    g.setColor(.75,.70,1,.55*flick)
    Voxel3D.draw(K.cross,K.soft,Mat4.mul(TR(bx,Lg.y,bz),Mat4.scale(520,240,520)))
    local sm=stream('bolt',24)
    if sm then
     local x,y,z=bx,Lg.y+40,bz
     local n=0
     for i=0,23 do
      local u=i/23
      local ny=Lg.y+40-(Lg.y+40-120)*u
      x=x+(rh(cyc,i,5)-.5)*34;z=z+(rh(cyc,i,7)-.5)*34
      K.streamPut(sm,i,x,ny,z,5.5*(1-u*.5),false)
     end
     pcall(sm.mesh.setVertices,sm.mesh,sm.verts)
     g.setColor(.92,.90,1,.95*flick)
     Voxel3D.draw(sm.mesh,K.soft,TR(0,0,0))
    end
   end
  end
  -- the aurora: curtains of light over Lorelei's palace
  for ai,A in ipairs(fx.aurora or{})do
   local n=36
   local st=strip('aurora'..ai,n)
   if st then
    local v=st.verts
    local dx,dz=A.x1-A.x0,A.z1-A.z0
    local L=sqrt(dx*dx+dz*dz);local nx,nz=-dz/L,dx/L
    for i=0,n-1 do
     local function P(u)
      local w=sin(u*7+t*.21+A.phase)*28+sin(u*17-t*.37+A.phase*2)*10
      local x,z=A.x0+dx*u+nx*w,A.z0+dz*u+nz*w
      local h=A.h*(.65+.35*sin(u*11+t*.5+A.phase))
      return x,z,h
     end
     local u0,u1=i/n,(i+1)/n
     local x0,z0,h0=P(u0);local x1,z1,h1=P(u1)
     local b=i*4
     local function put(k,x,y,z,uu,vv)local e=v[b+k];e[1],e[2],e[3],e[4],e[5]=x,y,z,uu,vv end
     put(1,x0,A.y,z0,u0*6,0);put(2,x1,A.y,z1,u1*6,0);put(3,x1,A.y+h1,z1,u1*6,1);put(4,x0,A.y+h0,z0,u0*6,1)
    end
    pcall(st.mesh.setVertices,st.mesh,v)
    local pulse=.75+.25*sin(t*.4+A.phase)
    g.setColor(.25,1,.55,.30*pulse)
    Voxel3D.draw(st.mesh,K.streak,TR(0,0,0))
    g.setColor(.65,.35,1,.18*pulse)
    Voxel3D.draw(st.mesh,K.streak,Mat4.mul(TR(0,A.h*.35,0),Mat4.scale(1,1.15,1)))
   end
  end
  -- a portal's light, breathing
  if fx.portal then
   local P=fx.portal
   local c=COL[P.col or'cyan']or COL.cyan
   g.setColor(c[1],c[2],c[3],.18+.08*sin(t*1.3))
   Voxel3D.draw(K.cross,K.soft,Mat4.mul(TR(P.x,P.y,P.z),Mat4.scale(P.w*.8,P.h*.6,P.w*.8)))
  end
  -- the Hall of Fame: fireworks, without end
  if fx.fireworks and K.fireworks then
   local F=fx.fireworks
   pcall(K.fireworks,g,K.soft,{x=F.x,y=F.y,z=F.z},t,1,F.scale or 1,{px,12,pz},id)
  end
  -- TEST218: an Elite Four / Champion win: the victory fireworks over the
  -- stadium, heard from where the battle camera stands
  if state.battle then
   local okVF,VF=pcall(V.require,"LeagueVictory")
   if okVF and VF and VF.draw then
    local e=Voxel3D.eye
    pcall(VF.draw,g,K,id,t,e and{e[1],e[2],e[3]}or{px,12,pz})
   end
  end
 end)

 ---------------------------------------------------------------- TEST220
 -- the 3D Hall of Fame induction: the podiums and the team on them
 if id=="HALL_OF_FAME" and not state.battle then
  local okH,HF=pcall(V.require,"HallOfFame3D")
  if okH and HF and HF.drawWorld then pcall(HF.drawWorld,K,t)end
 end
 ---------------------------------------------------------------- the fanfare
 if fx.fanfare and since<1 and not fx._played and not state.battle then
  fx._played=true
  local okF,FA=pcall(V.require,"LeagueFireworksAudio")
  if okF and FA and FA.fanfare then pcall(FA.fanfare)end
  -- and a salvo to greet you
  local list={}
  for k=0,11 do
   local kind=floor(rh(k,3,19)*4)
   list[#list+1]={launchT=t+.4+k*.35,rise=1.0,kind=kind,scale=.85,
    bx=fx.fireworks.x+(rh(k,5,11)-.5)*260,by=fx.fireworks.y+(rh(k,6,17)-.3)*60,bz=fx.fireworks.z+(rh(k,7,13)-.5)*100,
    R=(90+60*rh(k,8,23)),col=({{1,.30,.26},{1,.80,.28},{.36,.60,1},{.50,1,.42},{1,.42,.86},{1,.96,.90}})[k%6+1]}
  end
  pcall(Road.salvo,id,list)
 end
 pcall(g.setColor,1,1,1,1)
 return true
end

-- TEST173: the town interiors' fires, candles, glows, fish and glass
function M.drawInterior(state)
 local map=state and state.map
 if not map then return false end
 local okI,IR=pcall(V.require,"InteriorRooms")
 if not(okI and IR and IR.ROOMS and IR.ROOMS[tostring(map.id)]and IR.accepts(map))then return false end
 return M.draw(state,IR)
end
function M.drawInteriorBattle(map,arena)
 local mid=arena and arena.mid
 return M.drawInterior({map=map,player={px=(mid and mid[1]or 0)-8,py=(mid and mid[2]or 0)-8},battle=true})
end
-- in battle: the same light and weather round the arena (no fanfare)
function M.drawBattle(map,arena)
 local Rooms=V.require("LeagueRooms")
 if not(map and Rooms.LAYOUT[tostring(map.id)]and Rooms.accepts(map))then return false end
 local mid=arena and arena.mid
 local state={map=map,player={px=(mid and mid[1]or 0)-8,py=(mid and mid[2]or 0)-8},battle=true}
 -- TEST194: the stadium's own fires, lights, snow and storm in its place
 local okS,St=pcall(V.require,"LeagueStadium")
 if okS and St and St.drawing(map)then return M.draw(state,St)end
 return M.draw(state)
end
function M.invalidate()
 kit=nil
 for _,s in pairs(streams)do if s and s.mesh then pcall(s.mesh.release,s.mesh)end end
 for _,s in pairs(strips)do if s and s.mesh then pcall(s.mesh.release,s.mesh)end end
 streams,strips={}, {}
end
return M
