-- TEST218: VICTORY FIREWORKS. Beat an Elite Four member (or the Champion) in
-- their stadium and the sky over it goes up: the crowd's ovation (LeagueCrowd)
-- now comes with a fireworks show in that member's colours, heard through
-- the TEST209 fireworks sounds, and the camera lifts to watch it.
--
--   LORELEI   ice blue, white and silver
--   BRUNO     crimson, orange and gold
--   AGATHA    violet, ghost green and pale lilac
--   LANCE     dragon red, flame orange and gold
--   CHAMPION  every colour, a longer show and a bigger finale
--
-- THE SHOW: three volleys over about five seconds (the Champion gets a
-- fourth, the biggest): a few shells, a bigger wave, then the finale, going
-- up close together and ending in gold willows.
--
-- THE CAMERA: the battle camera is a long lens looking down on the two
-- mons, which shows the field and nothing of the sky. So on the win it
-- eases (over two seconds) down to a low seat and up to the sky over the
-- far stands, widening as it goes, and holds there while the trainer has
-- their last word. When the battle ends you're back in the room as before.
-- The owned Collection camera uses the same lift before its models
-- are projected. An unrelated external camera stays in charge and its
-- shells are placed within that camera's view.
--
-- How it runs:
--   * LeagueCrowd._ovation (the win) calls M.cheer(theme);
--   * BattleScene calls M.camera(cam,...) every battle frame, once its
--     camera is worked out (this module notes it, and returns the lifted one
--     while a show is on);
--   * LeagueRoomFx calls M.draw(...) in its additive pass every stadium
--     battle frame: the first one after the win plans the shells and hands
--     them to the League's own fireworks (LeagueRoad.salvo / fireworks),
--     which draw and sound them.
-- Presentation only: the battle, its timing and its text are untouched.
local V=...
local M={REVISION='league-victory-245'}
local pi,cos,sin,sqrt,floor,max,min,atan,tan,asin,rad=math.pi,math.cos,math.sin,math.sqrt,math.floor,math.max,math.min,math.atan,math.tan,math.asin,math.rad
local function rh(a,b,s)local v=sin(a*12.9898+b*78.233+s*37.719)*43758.5453;return v-floor(v)end
local clock=(love and love.timer and love.timer.getTime)or os.clock

M.PALETTES={
 lorelei={{.55,.82,1},{.92,.97,1},{.40,.62,1},{.72,.95,1},{.80,.86,1}},
 bruno={{1,.30,.20},{1,.68,.24},{1,.48,.14},{1,.88,.58},{.95,.22,.16}},
 agatha={{.72,.45,1},{.50,1,.62},{.86,.76,1},{.42,.95,.82},{.62,.36,.95}},
 lance={{1,.34,.14},{1,.74,.26},{1,.22,.30},{1,.94,.74},{1,.52,.18}},
 champion={{1,.30,.26},{1,.80,.28},{.36,.60,1},{.50,1,.42},{1,.42,.86},{.82,.52,1},{1,.96,.90},{.30,.95,1}},
}
local GOLD={1,.78,.36}
local ROOMS={lorelei='LORELEIS_ROOM',bruno='BRUNOS_ROOM',agatha='AGATHAS_ROOM',
 lance='LANCES_ROOM',champion='CHAMPIONS_ROOM'}
-- volleys: {start (s after the win), shells, gap between shells, scale}
M.SHOWS={
 member={{.9,4,.30,.85},{2.6,5,.22,.95},{4.5,8,.12,1.05}},
 champion={{.9,5,.28,.90},{2.6,6,.20,1.0},{4.5,8,.14,1.05},{6.6,12,.08,1.15}},
}
-- the lifted camera: how low the seat, how far up it looks, how wide
M.LIFT={ease=2.0,seatY=18,back=0,look=rad(24),fov=rad(60),aim=520}
-- TEST244: every burst goes off ABOVE AND BEYOND the stands: past the
-- stadium's rim (LeagueStadium.rim: its outer edge and its highest point,
-- the Champion's roof included) by `beyond` plus the burst's own size, and
-- with the whole burst (a willow's drip `drip` times its radius) above the
-- line from the eye over the rim, `clear` units above it, and `pad`
-- radians more. TEST245 fits the camera to the actual roof and checks
-- off-axis burst bounds in camera space. M.RIM=false disables rim clearance.
M.RIM={clear=14,beyond=40,drip=1.7,pad=rad(2),maxD=1600}

local pending=nil      -- {theme, at}: the win, waiting for the next stadium frame
local fired={}         -- map id -> the win already shown there
local show=nil         -- {map, t0, untilT, lifted, base}: the show on now
local lastCam=nil      -- the latest battle camera, before any lift
local lastMap=nil
local lastExternal=false
-- The importer copies selected frame fields into its extension context, so
-- a flag on the frame alone is lost. Its eye array retains identity. Weak
-- keys mark the shared frame without retaining every rendered camera.
local sharedEyes=setmetatable({},{__mode='k'})
function M.sharedEye(eye,mark)
 if type(eye)~='table'then return false end
 if mark then sharedEyes[eye]=true end
 return sharedEyes[eye]==true
end

function M.cheer(theme)
 if not M.PALETTES[theme or'']then return end
 pending={theme=theme,at=clock()}
end
function M.active(t)return show~=nil and(t or clock())<show.untilT end

local function smooth(u)u=max(0,min(1,u));return u*u*(3-2*u)end
local function lerp(a,b,u)return a+(b-a)*u end
local function copy(v)return{v[1],v[2],v[3]}end

-- the camera the show is watched from: a low seat, looking up over the far
-- stands, wider
local function liftedOf(cam,groundY,rim)
 local L=M.LIFT
 local e,f=cam.eye,cam.focus
 local dx,dz=f[1]-e[1],f[3]-e[3]
 local flat=sqrt(dx*dx+dz*dz)
 if flat<1e-3 then return nil end
 local hx,hz=dx/flat,dz/flat
 local seat={e[1]-hx*flat*L.back,(groundY or 0)+L.seatY,e[3]-hz*flat*L.back}
 local look=L.look
 if rim and M.RIM then
  -- The Champion's roof is much higher than the other rooms. Aim from the
  -- actual seat over that roof, including the sides of the fireworks fan.
  for _,yaw in ipairs({-rad(30),0,rad(30)})do
   local x,z=hx*cos(yaw)-hz*sin(yaw),hz*cos(yaw)+hx*sin(yaw)
   local d=M._toRim(rim,seat[1],seat[3],x,z)
   if d then look=max(look,atan((rim.y+M.RIM.clear-seat[2])/d)+rad(24))end
  end
 end
 look=min(look,rad(64))
 local aim={seat[1]+hx*L.aim,seat[2]+L.aim*tan(look),seat[3]+hz*L.aim}
 return{eye=seat,focus=aim,fov=max(cam.fov or 0,L.fov)}
end
M.liftedOf=liftedOf

-- BattleScene, every battle frame
function M.camera(cam,host,groundY,external)
 if type(cam)~='table'or type(cam.eye)~='table'or type(cam.focus)~='table'then return nil end
 lastCam={eye=copy(cam.eye),focus=copy(cam.focus),fov=cam.fov,aspect=cam.aspect,groundY=groundY or 0}
 lastMap=tostring(host and host.id)
 lastExternal=external and true or false
 if external or not show or not show.lifted then return nil end
 local now=clock()
 if now>=show.untilT or tostring(host and host.id)~=show.map then return nil end
 local u=smooth((now-show.t0)/M.LIFT.ease)
 local L=show.lifted
 local out={}
 for k,v in pairs(cam)do out[k]=v end
 out.eye={lerp(cam.eye[1],L.eye[1],u),lerp(cam.eye[2],L.eye[2],u),lerp(cam.eye[3],L.eye[3],u)}
 out.focus={lerp(cam.focus[1],L.focus[1],u),lerp(cam.focus[2],L.focus[2],u),lerp(cam.focus[3],L.focus[3],u)}
 out.fov=lerp(cam.fov or L.fov,L.fov,u)
 return out
end

-- a view as an eye, the horizontal direction it looks, its pitch and fov
local function viewOf(c)
 local e,f=c.eye,c.focus
 local dx,dy,dz=f[1]-e[1],f[2]-e[2],f[3]-e[3]
 local len=sqrt(dx*dx+dy*dy+dz*dz)
 local flat=sqrt(dx*dx+dz*dz)
 if len<1e-3 or flat<1e-3 then return nil end
 return{eye=e,fx=dx/flat,fz=dz/flat,pitch=asin(dy/len),fovY=tonumber(c.fov)or(pi/3),aspect=c.aspect,groundY=c.groundY or 0}
end

-- (TEST244) how far from (ex,ez), heading (hx,hz), to the rim's ellipse
local function toRim(rim,ex,ez,hx,hz)
 local ax,az=(ex-rim.cx)/rim.rx,(ez-rim.cz)/rim.rz
 local bx,bz=hx/rim.rx,hz/rim.rz
 local A=bx*bx+bz*bz
 local B=2*(ax*bx+az*bz)
 local Cc=ax*ax+az*az-1
 local disc=B*B-4*A*Cc
 if A<1e-12 or disc<0 then return nil end
 local t=(-B+sqrt(disc))/(2*A)
 return t>0 and t or nil
end
M._toRim=toRim
-- the shells of one show, in world coordinates, launched from time t0
-- (TEST244: `rim`, when known, keeps every burst above and beyond the stands)
function M.plan(theme,v,t0,rim)
 local pal=M.PALETTES[theme]
 local sh=theme=='champion'and M.SHOWS.champion or M.SHOWS.member
 local hHalf=atan(tan(v.fovY/2)*min(v.aspect or 4/3,16/9))
 local rx,rz=-v.fz,v.fx                    -- to the right of the view
 local list={}
 local n=0
 for w,vol in ipairs(sh)do
  local start,count,gap,sc=vol[1],vol[2],vol[3],vol[4]
  for i=0,count-1 do
   n=n+1
   -- across the picture, a little jitter, in its upper part
   local across=count>1 and(i/(count-1))*2-1 or 0
   local yaw=(across*.58+(rh(n,w,3)-.5)*.16)*hHalf
   local elev=v.pitch+v.fovY*(.04+.30*rh(n,w,5))
   local D=420+220*rh(n,w,7)
   local cy,sy=cos(yaw),sin(yaw)
   local hx,hz=v.fx*cy+rx*sy,v.fz*cy+rz*sy
   local kind=floor(rh(n,w,11)*4)
   if w==#sh and i>=count-3 then kind=2 end    -- the finale ends in gold willows
   -- the burst sized to the distance, so it fills about the same share of
   -- the picture wherever it lands (k: its radius per unit of distance)
   local k=(.21+.05*rh(n,w,13))*tan(v.fovY/2)*sc
   if kind==2 then k=k*.9 elseif kind==3 then k=k*1.1 end
   -- TEST244: above and beyond the stands
   local RM=M.RIM
   local tR=(RM and rim)and toRim(rim,v.eye[1],v.eye[3],hx,hz)or nil
   if tR then
    local rimA=atan((rim.y+RM.clear-v.eye[2])/tR)
    local lo,hi
    for fit=1,16 do
     -- Sphere bounds, including spark jitter; the upper edge is solved in
     -- camera space, where off-axis bursts reach higher than their elevation.
     local ar=asin(min(.95,k*1.2))
     lo=rimA+asin(min(.95,k*RM.drip))+RM.pad
     local ceiling=min(rad(85),v.pitch+v.fovY/2-ar-RM.pad)
     hi=atan(cos(yaw)*tan(ceiling))
     if hi>lo then break end
     k=k*.85
    end
    elev=hi>lo and lo+(hi-lo)*(.05+.50*rh(n,w,5))or lo
    local ce_,se_=cos(elev),sin(elev)
    -- past the rim by `beyond` and its own radius
    if ce_-k*1.2>1e-3 then D=max(D,(tR+RM.beyond)/(ce_-k*1.2))end
    -- and wholly above the highest thing on it, whatever the distance
    local need=rim.y+RM.clear-v.eye[2]
    if se_-k*RM.drip>1e-3 then D=max(D,need/(se_-k*RM.drip))end
    D=min(D,RM.maxD)
   end
   local ce,se=cos(elev),sin(elev)
   local bx,by,bz=v.eye[1]+D*ce*hx,v.eye[2]+D*se,v.eye[3]+D*ce*hz
   by=max(by,v.groundY+60)                  -- never down among the mons
   local col=pal[(n-1)%#pal+1]
   if kind==2 then col=GOLD end
   local R=k*D
   list[#list+1]={launchT=t0+start+i*gap,rise=.95+.25*rh(n,w,17),kind=kind,scale=sc,
    bx=bx,by=by,bz=bz,lx=bx+(rh(n,w,19)-.5)*40,ly=by-R*1.6,lz=bz+(rh(n,w,23)-.5)*40,
    R=R,col=col,bright=1.35,sparkScale=max(1.35,D/420),gravityScale=.65}
  end
 end
 return list
end
function M.showLength(theme)
 local sh=theme=='champion'and M.SHOWS.champion or M.SHOWS.member
 local last=sh[#sh]
 return last[1]+last[2]*last[3]+1.3+5   -- the last shell's rise and burn
end

-- every stadium battle frame (LeagueRoomFx, inside its additive pass)
function M.draw(g,K,mapId,t,listen)
 mapId=tostring(mapId)
 if pending then
  -- a win only counts for the stadium on screen, and only while fresh
  if clock()-pending.at<4 and fired[mapId]~=pending.at and lastCam
    and ROOMS[pending.theme]==mapId and lastMap==mapId then
   -- (TEST244: the stadium's rim, when it is built)
   local rim=nil
   pcall(function()local LS=V.require('LeagueStadium');if LS.rim then rim=LS.rim(mapId)end end)
   local lifted=(not lastExternal)and liftedOf(lastCam,lastCam.groundY,rim)or nil
   local watch=lifted and{eye=lifted.eye,focus=lifted.focus,fov=lifted.fov,aspect=lastCam.aspect,groundY=lastCam.groundY}or lastCam
   local v=viewOf(watch)
   local okR,Road=pcall(V.require,'LeagueRoad')
   -- A third-party camera which does not use the shared hook still owns its
   -- framing. Do not force its shells into sky that its lens cannot see.
   if lastExternal then rim=nil end
   if v and okR and Road and Road.salvo then
    local okFire=pcall(Road.salvo,mapId,M.plan(pending.theme,v,t,rim))
    if okFire then
     fired[mapId]=pending.at
     local now=clock()
     show={map=mapId,t0=now,untilT=now+M.showLength(pending.theme),lifted=lifted}
    end
   end
  end
  pending=nil
 end
 if show and show.map==mapId and t<show.untilT and K and K.fireworks then
  -- no standing show (sky nil): only the salvos fired on this map
  pcall(K.fireworks,g,K.soft,nil,t,1,1,listen,mapId)
 end
end
return M
