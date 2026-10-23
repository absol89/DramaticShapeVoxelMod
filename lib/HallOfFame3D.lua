-- TEST220: THE HALL OF FAME, IN 3D. The game's own induction (the black and
-- white screen after Professor Oak walks you to the record) now happens in
-- the 3D Hall of Fame room itself:
--
--   * the camera eases from where you stand to a wide shot of the hall
--     under its fireworks; the Hall of Fame music starts
--   * one by one, each Pokemon on your team appears on a marble-and-gold
--     podium in an arc before the record: the camera moves to the podium,
--     a beam of light falls, the Pokemon rises into it with a burst of
--     sparks and its cry, and a red-and-gold panel shows its name, level
--     and type, then HALL OF FAME
--   * the inducted stay on their podiums; after the last, the camera pulls
--     back to the team shot (your trainer at the record behind them) with
--     your name, play time and money, and the game's own POKeDEX lines
--   * then a fade to white, and on to the parade and the credits
--
-- TEST224: THE TEAM IN 3D, AND A FINALE.
--   * Each Pokemon is now its 3D model: the Stadium models you imported
--     through the Collection (the same ones your party, your battles and the
--     Game Corner prizes use; a shiny is shown shiny). It appears in a white
--     flash, grows onto its podium and plays its entrance -- the send-out
--     pose -- with its cry, then stands in its idle on the podium, turned to
--     the hall. Nothing is extracted or made here: if the models are off,
--     not imported yet, or one won't load, that Pokemon is its picture as
--     before -- and the ROM picture is now in its own colours rather than
--     black and white.
--   * The camera meets each one from the front, a little below its eye
--     line, and eases in while its panel is up (the panel gives its POKeDEX
--     number too).
--   * The team shot is lower, the six in a row with you at the record behind
--     them; together they play their entrance again, a burst of light round
--     every podium.
--   * The POKeDEX lines are a panel of their own (the counts roll up, then
--     the game's own rating), not the old text boxes; meanwhile the camera
--     cranes up past HALL OF FAME into the sky, and a salvo of fireworks
--     bursts over the hall before the fade to white.
--
-- TEST225: SIZES, AND PROFESSOR OAK'S QUESTION.
--   * Each Pokemon now stands at a size from its POKeDEX height (a fourth
--     root of it, so Pikachu is small and Snorlax big without either being
--     silly); TEST224 read the model's own height, which is not in the units
--     it assumed, and every Pokemon came out at the largest size.
--   * After the team shot, Oak introduces the parade in the game's own
--     text box. TEST264 always sends you aboard the Champion's float.
--     The team turns to watch, then the crane and fireworks continue.
--
-- How it fits: the engine's HallOfFame screen is built through
-- HallOfFame.new; this hands back its own screen in its place, with the same
-- "when done". The camera is placed through FirstPerson.frame, the one place
-- the overworld asks for a placed camera; the podiums and Pokemon are drawn
-- in the room's own effects pass (LeagueRoomFx); the panels at full
-- resolution from the HUD pass. The models come from the Collection's model
-- interface (STADIUM2_IMPORTER's exports.models, the same seam its prize
-- showcase uses), drawn into the room's own depth buffer with the room's
-- camera. Installed from LeagueFireworksAudio.install.
-- TEST228: YOUR PARTNER STEPS ASIDE. The Pokemon walking at your heels stood
-- in the middle of the hall through the whole induction -- in Joseph's
-- recording his Charizard filled most of the screen from the first line to
-- Professor Oak's question, the cameras passing through its wings. It stands
-- on its podium with the rest of the team anyway, so while the ceremony runs
-- it is not drawn (nor its shadow): the overworld state carries the ask,
-- overworld.legendaryHideFollowers = love.timer time, renewed every frame,
-- which the Collection's overworld Pokemon honour; a partner drawn as a flat
-- card here is claimed through CharacterRenderers. It is back for the parade.
local V=...
local M={REVISION='hall-of-fame-3d-228'}
local floor,max,min,abs,sin,cos,sqrt,pi,rad=math.floor,math.max,math.min,math.abs,math.sin,math.cos,math.sqrt,math.pi,math.rad
local atan2=math.atan2 or math.atan

-- the timings, in seconds
M.T={intro=2.8,loadWait=1.6,music=1.0,move=1.3,grow=.55,flash=.75,info=2.4,banner=1.5,
 team=2.4,stats=1.0,cheer=1.1,crane=7.0,dex=7.6,dexCount=1.2,dexRating=1.9,out=1.1,creep=5.0,
 oakMove=1.8,oakTurn=.6,oakText=.35,oakAfter=.35}
-- Professor Oak's announcement (the game's own text markers:
-- \n the second line, \v scroll a line, \f a new page; # is POKe)
-- (TEST226: the parade is in Celadon City now, then home)
M.OAK_ASK="Your parade is in\nCELADON CITY, and\vthe whole town is\vthere to cheer!\fYour #MON are\nwaiting aboard\vthe CHAMPION's\vfloat! Off you go!"
M.ROOM='HALL_OF_FAME'
M.CENTRE_X=80          -- the hall's axis (it is 160 wide)
-- TEST224: the podiums stand further apart (17, not 13: a model has width
-- and depth that a picture did not) in a shallow V, the outer ones nearer
-- the camera, so neighbours never stand inside one another
M.LINE_Z=70            -- the inner pair's line, south of the record
M.SLOTS={-48,-31,-14,14,31,48}
M.SWEEP=.35            -- how far south each step out comes
M.PODIUM_Y=5           -- the top of a podium
M.MON_H=21             -- how tall a Pokemon's picture stands (its drawn body)
M.MON_W=28             -- and no wider than this
-- the models: a Pokemon 1.5 m tall stands MODEL_H on its podium; taller and
-- shorter ones keep some of the difference (by the fourth root of their
-- POKeDEX heights), between MODEL_MIN and MODEL_MAX. (TEST225: TEST224 read
-- the model's own height, which is not in the units it assumed: every
-- Pokemon came out at the largest size, Pikachu as tall as Snorlax.)
M.MODEL_H=17
M.MODEL_MIN,M.MODEL_MAX=11,22
M.MODEL_W=20           -- and no wider than this
M.EYE_Z=124            -- no camera further south than this (the south wall)
M.LIGHT={direction={-.30,.80,.52},ambient={.50,.47,.44},diffuse={.56,.51,.43}}
M.TINT={1,.97,.92,1}
M.FLASH={1,.95,.80}
M.AUDIENCE={80,140}    -- where the inducted look while the camera is elsewhere

local active=nil       -- the screen running now
local lastRig=nil      -- the camera this module last placed
local modRef=nil       -- this mod (to find the Collection)

local function now()local ok,t=pcall(love.timer.getTime);return ok and t or 0 end
local function smooth(u)u=max(0,min(1,u));return u*u*(3-2*u)end
local function backOut(u)u=max(0,min(1,u));local s=1.7;u=u-1;return u*u*((s+1)*u+s)+1 end
local function lerp(a,b,u)return a+(b-a)*u end
local function lerp3(a,b,u)return{lerp(a[1],b[1],u),lerp(a[2],b[2],u),lerp(a[3],b[3],u)}end
local function hash(a,b)local x=sin(a*127.1+b*311.7)*43758.5453;return x-floor(x)end

------------------------------------------------------------------ where
-- the podium of the k-th of n Pokemon: the slots nearest the axis first,
-- shared out left and right, then sorted left to right
function M.slots(n)
 local order={3,4,2,5,1,6}
 local pick={}
 for i=1,min(n,6)do pick[#pick+1]=M.SLOTS[order[i]]end
 table.sort(pick)
 local out={}
 for k,dx in ipairs(pick)do
  local inner=abs(M.SLOTS[3])
  out[k]={x=M.CENTRE_X+dx,y=M.PODIUM_Y,z=M.LINE_Z+(abs(dx)-inner)*M.SWEEP}
 end
 return out
end
-- the shots: a wide view, one per podium, the team, and the crane to the sky
-- (all checked against the room's own geometry, at 16:9)
function M.shotWide()
 return{eye={M.CENTRE_X,62,M.EYE_Z+2},focus={M.CENTRE_X,4,54},fov=rad(58)}
end
-- straight in front of the podium and a little below the Pokemon's middle,
-- far enough back for its height `h`; the camera sits a little to the left
-- so the Pokemon stands right of centre, leaving the left for its panel.
-- (Where that would put the camera in the south wall, it stands closer and
-- widens instead.)
function M.shotMon(p,h)
 h=tonumber(h)or 20
 local k=max(.8,min(1.35,h/20))
 local D=34*k
 local fov=rad(44)
 local room=M.EYE_Z-p.z
 if D>room and room>8 then
  fov=2*math.atan(math.tan(fov/2)*D/room)
  D=room
 end
 local d=.155*D
 return{eye={p.x-d,p.y+h*.42,p.z+D},focus={p.x-d,p.y+h*.55,p.z},fov=fov,creep=.07}
end
function M.shotTeam()
 return{eye={M.CENTRE_X,44,M.EYE_Z+2},focus={M.CENTRE_X,14,60},fov=rad(64)}
end
function M.shotCrane()
 return{eye={M.CENTRE_X,30,122},focus={M.CENTRE_X,60,-10},fov=rad(62)}
end
-- you and Professor Oak at the record, from over the team (`mid` is the
-- point between you), near your eye line: your faces in the upper half of
-- the frame, clear of the text box, and the two of you a little left of
-- centre, clear of the choice box that opens at its right end
function M.shotOak(mid)
 local x,z=mid and mid[1]or M.CENTRE_X,mid and mid[2]or 40
 return{eye={x+6,36,z+44},focus={x+6,17,z},fov=rad(46),creep=.05}
end

------------------------------------------------------------------ the models
-- the Collection's model interface, when its models are on and imported
local function modelsApi()
 local find=modRef and modRef.find
 if type(find)~='function'then return nil end
 local ok,h=pcall(find,'STADIUM2_IMPORTER')
 if not(ok and type(h)=='table')then ok,h=pcall(find,modRef,'STADIUM2_IMPORTER')end
 local e=ok and type(h)=='table'and h.exports
 local api=type(e)=='table'and e.models
 if not(type(api)=='table'and(tonumber(api.apiVersion)or 0)>=2 and type(api.newInstance)=='function')then return nil end
 if type(e.modelsEnabled)=='function'then
  local okE,on=pcall(e.modelsEnabled)
  if okE and not on then return nil end
 end
 if type(e.status)=='function'then
  local okS,st=pcall(e.status)
  if not(okS and type(st)=='table'and st.state=='ready')then return nil end
 end
 return api
end
M.modelsApi=modelsApi

local function dexOf(game,species)
 if type(species)=='number'then
  local n=floor(species)
  return n>=1 and n<=251 and n or nil
 end
 local def=game and game.data and game.data.pokemon and game.data.pokemon[species]
 local d=def and tonumber(def.dex or def.index)
 d=d and floor(d)
 return d and d>=1 and d<=251 and d or nil
end
M.dexOf=dexOf

-- a species' height in metres, from its own POKeDEX entry (nil: unknown)
local function dexMetres(game,species)
 local def=game and game.data and game.data.pokemon and game.data.pokemon[species]
 local e=def and def.dexEntry
 if type(e)~='table'then return nil end
 if tonumber(e.heightM)then return tonumber(e.heightM)end
 local ft=tonumber(e.heightFt)
 if ft then return(ft*12+(tonumber(e.heightIn)or 0))*.0254 end
 return nil
end
M.dexMetres=dexMetres
-- how tall a Pokemon stands: `base` for one 1.5 m tall, the rest by the
-- fourth root of their height, within lo..hi
local function sizeFor(game,mon,base,lo,hi)
 local m=dexMetres(game,mon and mon.species)
 if not(m and m>0)then return base end
 return max(lo,min(hi,base*(m/1.5)^.25))
end
M.sizeFor=sizeFor

local function boxOk(b)
 return type(b)=='table'and tonumber(b.minY)and tonumber(b.maxY)and b.maxY>b.minY
end
-- size and seat a fresh instance from its idle pose: `want` tall and no
-- wider than `maxW`, its feet at its own ground (a floating Pokemon keeps a
-- little of its float), centred, ready to be turned by yaw
local function fitModel(inst,want,maxW)
 inst:playContext('idle',true)
 inst:update(0,{context='idle'})
 local met=inst:metrics()or{}
 local b=inst:bounds()
 if not boxOk(b)then b=met.bounds end
 if not boxOk(b)then return nil end
 local h=b.maxY-b.minY
 local w=max((tonumber(b.maxX)or 0)-(tonumber(b.minX)or 0),(tonumber(b.maxZ)or 0)-(tonumber(b.minZ)or 0),h*.3)
 local s=want/h
 if w*s>maxW then s=maxW/w end
 if not(s>0 and s<1e6)then return nil end
 local ground=b.minY<0 and b.minY or max(0,b.minY-h*.35)
 local cx=(tonumber(b.minX)and tonumber(b.maxX))and(b.minX+b.maxX)/2 or tonumber(b.cx)or 0
 local cz=(tonumber(b.minZ)and tonumber(b.maxZ))and(b.minZ+b.maxZ)/2 or tonumber(b.cz)or 0
 return{inst=inst,scale=s,cx=cx,cz=cz,ground=ground,
  top=(b.maxY-ground)*s,mid=((b.minY+b.maxY)/2-ground)*s,
  footR=max(4,min(7,w*s*.42)),width=w*s,context='idle'}
end
local function loadModel(game,api,mon,want,maxW)
 local dex=dexOf(game,mon and mon.species)
 if not dex then return nil end
 want=want or sizeFor(game,mon,M.MODEL_H,M.MODEL_MIN,M.MODEL_MAX)
 maxW=maxW or M.MODEL_W
 local opts={textureFilter='nearest',anisotropy=4,flipY=false,anchorTravel=true}
 local shiny=false
 pcall(function()shiny=V.require('BattleArt').isShiny(mon)and true or false end)
 local inst
 if shiny then local ok,i=pcall(api.newInstance,dex,'shiny',opts);if ok then inst=i end end
 if type(inst)~='table'then local ok,i=pcall(api.newInstance,dex,'normal',opts);if ok then inst=i end end
 if type(inst)~='table'then return nil end
 local ok,fit=pcall(fitModel,inst,want,maxW)
 if ok and fit then fit.dex=dex;return fit end
 pcall(inst.release,inst)
 return nil
end
local function releaseModel(m)
 local md=m and m.model
 if md and md.inst then pcall(md.inst.release,md.inst)end
 if m then m.model=false end
end
-- play a context (`once`: then back to the idle), or the idle if it has none
local function play(md,ctx,once)
 if not(md and md.inst)then return false end
 local ok,res=pcall(md.inst.playContext,md.inst,ctx,not once)
 if ok and res~=false and res~=nil then
  md.context=ctx;md.once=once and now()or nil;md.tick=nil
  return true
 end
 if ctx~='idle'then return play(md,'idle',false)end
 return false
end
-- advance a model's animation at `hz` frames a second (false: it failed)
local function stepModel(md,t,hz)
 local tick=floor(t*(hz or 30))
 if tick==md.tick then return true end
 local step=md.lastT and min(.1,max(0,t-md.lastT))or 0
 md.lastT=t;md.tick=tick
 if not pcall(md.inst.update,md.inst,step,{context=md.context or'idle'})then return false end
 if md.once then
  local okF,fin=pcall(md.inst.isFinished,md.inst)
  if(okF and fin)or t-md.once>8 then play(md,'idle',false)end
 end
 return true
end
-- draw one into the scene being drawn, with the scene's own camera: its
-- feet at (x,y,z), turned to `yaw`, grown by `grow`, in a white `flash`
-- (false: it could not draw)
local function drawModel(md,x,y,z,yaw,grow,flash)
 local R=V.require('Voxel3D')
 if R.reflectionPlane or not(R.vp and R.eye and R.focus)then return true end
 local Mat4=V.require('Mat4')
 local okV,view=pcall(Mat4.lookAt,R.eye,R.focus,{0,1,0})
 if not(okV and view)then return true end
 local g=love.graphics
 local write=true
 pcall(function()local _,w=g.getDepthMode();write=w==true end)
 local k=md.scale*(grow or 1)
 local matrix=Mat4.mul(Mat4.translate(x,y,z),Mat4.mul(Mat4.rotateY(yaw or 0),
  Mat4.mul(Mat4.scale(k,k,k),Mat4.translate(-md.cx,-md.ground,-md.cz))))
 local f=flash or 0
 local ok,drawn=pcall(md.inst.draw,md.inst,{modelMatrix=matrix,camera={view=view,viewProjection=R.vp},
  light=M.LIGHT,tint=M.TINT,flashAmount=f*f,flashColor=M.FLASH,
  flipWinding=true,disableCulling=true,depthWrite=write})
 g.setColor(1,1,1,1)
 return ok and drawn~=false
end
-- TEST225: the same models for anyone else in the mod (the parade's float)
function M.newTeamModel(game,mon,want,maxW)
 local api=modelsApi()
 if not api then return nil end
 return loadModel(game,api,mon,want,maxW)
end
M.playTeamModel=play
M.stepTeamModel=stepModel
M.drawTeamModel=drawModel
function M.releaseTeamModel(md)
 if md and md.inst then pcall(md.inst.release,md.inst);md.inst=nil end
end

------------------------------------------------------------------ pictures
-- (when a Pokemon has no model) this mod's own battle art, else the ROM
-- picture in the species' own colours
local function clearBackdrop(id)
 local w,h=id:getDimensions()
 local _,_,_,a0=id:getPixel(0,0)
 if a0==0 then return end          -- already cut out
 local seen,todo={},{}
 local function visit(x,y)
  if x<0 or y<0 or x>=w or y>=h then return end
  local k=y*w+x
  if seen[k]then return end
  seen[k]=true
  local r,g,b,a=id:getPixel(x,y)
  if a>0 and r>.83 and g>.83 and b>.83 then id:setPixel(x,y,r,g,b,0);todo[#todo+1]=k end
 end
 for x=0,w-1 do visit(x,0);visit(x,h-1)end
 for y=0,h-1 do visit(0,y);visit(w-1,y)end
 while #todo>0 do
  local k=table.remove(todo)
  local x,y=k%w,floor(k/w)
  visit(x+1,y);visit(x-1,y);visit(x,y+1);visit(x,y-1)
 end
end
local function romPicture(game,species,mon)
 local Sprites=require('src.pokemon.Sprites')
 local Assets=require('src.render.Assets')
 local path,trueColor=Sprites.path(game.data,species,'front',{kind='hof',mon=mon})
 if not path then return nil end
 local id=Assets.imageData(path)
 local pal=nil
 pcall(function()
  local PFX=require('src.render.PaletteFX')
  if not(trueColor and PFX.honorsTrueColor and PFX.honorsTrueColor())then pal=PFX.monPal(game.data,species)end
 end)
 if not trueColor then pcall(clearBackdrop,id)end
 if type(pal)=='table'and pal[1]and pal[4]then
  id:mapPixel(function(_,_,r,g,b,a)
   if a==0 then return r,g,b,a end
   local c=r>.83 and pal[1]or r>.5 and pal[2]or r>.17 and pal[3]or pal[4]
   return(c[1]or 0)/255,(c[2]or 0)/255,(c[3]or 0)/255,a
  end)
 end
 local img=love.graphics.newImage(id)
 img:setFilter('nearest','nearest')
 return img,id
end
-- the opaque extent of a picture's pixels
local function opaqueBounds(data)
 local w,h=data:getDimensions()
 local x0,y0,x1,y1=w,h,-1,-1
 for y=0,h-1 do for x=0,w-1 do
  local _,_,_,a=data:getPixel(x,y)
  if a>.05 then
   if x<x0 then x0=x end;if x>x1 then x1=x end
   if y<y0 then y0=y end;if y>y1 then y1=y end
  end
 end end
 if x1<0 then return nil end
 return{x0=x0,x1=x1,y0=y0,y1=y1,padBottom=h-1-y1}
end
-- the stock black-and-white picture (every opaque pixel a grey)
local function grayscale(data)
 local w,h=data:getDimensions()
 local step=max(1,floor(min(w,h)/48))
 local n=0
 for y=0,h-1,step do for x=0,w-1,step do
  local r,g,b,a=data:getPixel(x,y)
  if a>.5 then
   n=n+1
   if abs(r-g)>.04 or abs(g-b)>.04 then return false end
  end
 end end
 return n>0
end
local function artFor(game,mon)
 local species=mon and mon.species
 if not species then return nil end
 local frames,durations,data
 pcall(function()
  local BA=V.require('BattleArt')
  local mode=BA.setting:get()
  local display=BA.displayMode and BA.displayMode()or nil
  if mode=='animated'then
   local Anim=V.require('AnimatedBattleArt')
   frames,durations=Anim.interfaceFront(species,BA.frontAnimationSetting:get(),display,nil,mon)
  elseif mode=='static'then
   local img=BA.interfaceStaticFrontImage(species,display,mon)
   frames=img and{img}or nil
  end
  if not(frames and frames[1])then
   local img=BA.image(species,'front',mon)
   frames=img and{img}or nil
  end
 end)
 if frames and frames[1]then
  pcall(function()data=V.require('BattleArt').imageData(frames[#frames])end)
  -- TEST224: the stock picture in black and white (what TEST220 showed):
  -- the ROM picture in the species' own colours instead
  if data then
   local okG,gray=pcall(grayscale,data)
   if okG and gray then frames,durations,data=nil,nil,nil end
  end
 end
 if not(frames and frames[1])then
  local ok,img,id=pcall(romPicture,game,species,mon)
  if ok and img then frames,data={img},id else frames=nil end
 end
 if not(frames and frames[1])then return nil end
 -- the body's extent, from the neutral (last) frame: measured from its own
 -- pixels where they are at hand, else from Battle Art's measure (brought
 -- to this picture's size), else the whole picture
 local neutral=frames[#frames]
 local w,h=neutral:getDimensions()
 local m
 if data then
  local dw,dh=data:getDimensions()
  if dw==w and dh==h then local ok,b=pcall(opaqueBounds,data);if ok then m=b end end
 end
 if not m then
  pcall(function()
   local bm=V.require('BattleArt').metrics(neutral)
   if bm and tonumber(bm.x0)and tonumber(bm.y1)then
    local sx=(tonumber(bm.w)and bm.w>0)and w/bm.w or 1
    local sy=(tonumber(bm.h)and bm.h>0)and h/bm.h or 1
    m={x0=bm.x0*sx,x1=(bm.x1+1)*sx-1,y0=bm.y0*sy,y1=(bm.y1+1)*sy-1,
     padBottom=(tonumber(bm.padBottom)or(h/sy-1-bm.y1))*sy}
   end
  end)
 end
 if not m then m={x0=0,x1=w-1,y0=0,y1=h-1,padBottom=0}end
 local bodyH=max(1,m.y1-m.y0+1);local bodyW=max(1,m.x1-m.x0+1)
 if bodyH<h*.15 or bodyW<w*.15 then
  m={x0=0,x1=w-1,y0=0,y1=h-1,padBottom=0};bodyH,bodyW=h,w
 end
 -- the body MON_H tall (no wider than MON_W), and the whole picture never
 -- more than twice that
 local k=min(M.MON_H/bodyH,M.MON_W/bodyW,M.MON_H*2/h,M.MON_W*2/w)
 return{frames=frames,durations=durations or{},w=w*k,h=h*k,
  foot=(m.padBottom or(h-1-m.y1))*k,cx=((m.x0+m.x1+1)/2-w/2)*k,frame=1,elapsed=0}
end
local function advanceArt(a,dt)
 if not(a and #a.frames>1)then return end
 a.elapsed=a.elapsed+dt
 local d=max(1,tonumber(a.durations[a.frame])or 100)/1000
 while a.elapsed>=d do
  a.elapsed=a.elapsed-d
  a.frame=a.frame%#a.frames+1
  d=max(1,tonumber(a.durations[a.frame])or 100)/1000
 end
end
-- TEST225: the picture too, for the parade's float when there is no model
-- (sized for a podium: MON_H tall; the float scales it)
M.newTeamArt=function(game,mon)local ok,a=pcall(artFor,game,mon);return ok and a or nil end
M.advanceTeamArt=advanceArt
-- how tall a Pokemon stands above its podium (for the camera)
local function heightOf(m)
 if m.model then return m.model.top end
 local a=m.art
 if a then return max(8,a.h-a.foot)end
 return 20
end

------------------------------------------------------------------ the text
-- the game's own strings, as plain text for the panels
local function plain(s)
 s=tostring(s or'')
 s=s:gsub('<PK><MN>','POK\195\169MON'):gsub('<PK>','PK'):gsub('<MN>','MN')
 s=s:gsub('{COLON}',':'):gsub('{[^}]*}','')
 s=s:gsub('#','POK\195\169')
 s=s:gsub('[\n\v\f\r]',' '):gsub('@',''):gsub('%s+',' ')
 s=s:gsub('^%s+',''):gsub('%s+$','')
 return s
end
M.plain=plain
local function dexRatingKey(owned)
 if owned>=150 then return'_DexRatingText_Own150To151'end
 local lo=floor(owned/10)*10
 return('_DexRatingText_Own%dTo%d'):format(lo,lo+9)
end

------------------------------------------------------------------ the screen
local Screen={};Screen.__index=Screen
Screen.isOpaque=false   -- the 3D room shows through
function Screen.new(game,onDone)
 local t=now()
 local self=setmetatable({game=game,onDone=onDone,phase='intro',t0=t,created=t,
  index=0,mons={},finished=false,loading=true},Screen)
 local party=game.save and game.save.party or{}
 local slots=M.slots(#party)
 for i,mon in ipairs(party)do
  if i>6 then break end
  self.mons[i]={mon=mon,podium=slots[i],model=nil,art=nil,shown=nil}
 end
 self.api=modelsApi()
 -- where the camera starts: wherever the overworld last had it
 local R=V.require('Voxel3D')
 local e,f=R.eye,R.focus
 self.from={eye=e and{e[1],e[2],e[3]}or M.shotWide().eye,
  focus=f and{f[1],f[2],f[3]}or M.shotWide().focus,
  fov=tonumber(R.fovY)or rad(50)}
 self.shotFrom=self.from
 self.shotTo=M.shotWide()
 self.shotT=t
 self.shotDur=M.T.intro*.85
 pcall(function()require('src.core.Music').fadeOut(10)end)
 return self
end
-- one Pokemon a frame: its model, or (failing that) its picture
function Screen:loadStep()
 for _,m in ipairs(self.mons)do
  if m.model==nil then
   m.model=self.api and loadModel(self.game,self.api,m.mon)or false
   if not m.model then m.art=artFor(self.game,m.mon)end
   return true
  end
  if m.model==false and not m.art and not m.noArt then
   m.art=artFor(self.game,m.mon);m.noArt=not m.art
   return true
  end
 end
 return false
end
function Screen:moveTo(shot,dur)
 self.shotFrom=self:camera()
 self.shotTo=shot
 self.shotT=now()
 self.shotDur=dur
end
-- the camera now: the eased move, a slow push in once it has arrived (a
-- shot's `creep`), with a slow breath on top
function Screen:camera()
 local t=now()
 local e=t-self.shotT
 local u=smooth(e/max(.01,self.shotDur))
 local a,b=self.shotFrom,self.shotTo
 local eye=lerp3(a.eye,b.eye,u)
 local focus=lerp3(a.focus,b.focus,u)
 if b.creep and e>self.shotDur then
  local c=smooth((e-self.shotDur)/M.T.creep)*b.creep
  eye=lerp3(eye,focus,c)
 end
 eye[1]=eye[1]+sin(t*.31)*1.6*u;eye[2]=eye[2]+sin(t*.23+1)*.8*u
 return{eye=eye,focus=focus,fov=lerp(a.fov,b.fov,u),up={0,1,0},curve=0}
end
function Screen:current()return self.mons[self.index]end
function Screen:startMon(i)
 self.index=i
 local m=self.mons[i]
 self.phase='move'
 self.phaseT=now()
 self:moveTo(M.shotMon(m.podium,heightOf(m)),M.T.move)
end
-- where each Pokemon looks: the one being inducted, just past the camera
-- (a three-quarter view, toward its panel); the rest, out over the hall;
-- the team, at the camera
function Screen:faceTarget(i,m,cam)
 local p=m.podium
 local look=(self.phase=='team'or self.phase=='dex'or self.phase=='out')
 if self.index==i and(self.phase=='move'or self.phase=='info'or self.phase=='banner')then
  return atan2(cam.eye[1]-p.x,cam.eye[3]-p.z)-.35
 end
 if look then return atan2(cam.eye[1]-p.x,cam.eye[3]-p.z)end
 -- while Professor Oak talks to you, the team turns to watch the two of you
 if self.phase=='oak'then
  local mid=self.oakMid or{M.CENTRE_X,40}
  return atan2(mid[1]-p.x,mid[2]-p.z)
 end
 return atan2(M.AUDIENCE[1]-p.x,M.AUDIENCE[2]-p.z)
end
-- the team's animation runs from here, once per frame whoever calls it:
-- update (while the ceremony is the top screen) and the room's draw (while
-- Professor Oak's text box is on top of it, and the ceremony is not updated)
function Screen:tick(t)
 local dt=t-(self.animT or t)
 self.animT=t
 if dt>0 then self:animate(min(dt,.1),t)end
end
function Screen:animate(dt,t)
 local cam=self:camera()
 for i,m in ipairs(self.mons)do
  if m.shown then
   advanceArt(m.art,dt)
   local want=self:faceTarget(i,m,cam)
   if m.yaw==nil then m.yaw=want else
    local d=(want-m.yaw+pi)%(2*pi)-pi
    m.yaw=m.yaw+d*min(1,dt*3)
   end
   local md=m.model
   if md then
    -- the animation, at 30 a second for the one on show, 20 for the rest
    local hz=(i==self.index or md.once)and 30 or 20
    if not stepModel(md,t,hz)then releaseModel(m)end
   end
  end
  -- the team cheer, one after another along the row
  if m.cheerAt and t>=m.cheerAt then
   m.cheerAt=nil;m.burst=t
   if m.model then play(m.model,'entrance',true)end
  end
 end
end
function Screen:update(dt)
 if self.finished then return end
 dt=tonumber(dt)or 1/60
 local t=now()
 local busy=self:loadStep()
 if self.loading then
  if not busy then self.loading=false
  elseif self.phase=='intro'and t-self.created<M.T.loadWait then
   -- hold the camera still while the team loads (a hitch then is unseen)
   self.t0=t;self.shotT=t
   return
  end
 end
 self:tick(t)
 local input=self.game and self.game.input
 local pressed=input and(input:wasPressed('a')or input:wasPressed('b'))
 if self.phase=='intro'then
  if not self.musicOn and t-self.t0>=M.T.music then
   self.musicOn=true
   local data=self.game.data
   if data.audio and data.audio.songs and data.audio.songs.Music_HallOfFame then
    pcall(function()require('src.core.Music').play(data,'Music_HallOfFame')end)
   end
  end
  if t-self.t0>=M.T.intro then
   if #self.mons>0 then self:startMon(1)else self:startTeam()end
  end
 elseif self.phase=='move'then
  if t-self.phaseT>=M.T.move then
   local m=self:current()
   m.shown=t;m.burst=t;m.yaw=nil
   if m.model then play(m.model,'entrance',true)end
   self.phase='info';self.phaseT=t
   pcall(function()require('src.core.Sound').playCry(self.game.data,m.mon.species)end)
  end
 elseif self.phase=='info'then
  -- A hurries a hold along, once the cry has had a moment
  if t-self.phaseT>=M.T.info or(pressed and t-self.phaseT>1.0)then
   self.phase='banner';self.phaseT=t
  end
 elseif self.phase=='banner'then
  if t-self.phaseT>=M.T.banner or(pressed and t-self.phaseT>.6)then
   if self.index<#self.mons then self:startMon(self.index+1)else self:startTeam()end
  end
 elseif self.phase=='team'then
  if t-self.phaseT>=M.T.team+M.T.stats then
   if self:rideOffered()then self:startOak()else self:startDex()end
  end
 elseif self.phase=='oak'then
  local e=t-self.phaseT
  if not self.oakTurned and e>=M.T.oakTurn then self.oakTurned=true;self:faceOak()end
  if not self.oakAsked and e>=M.T.oakMove+M.T.oakText then self.oakAsked=t;self:askOak()end
  if self.oakDone and t-self.oakDone>=M.T.oakAfter then self:startDex()end
 elseif self.phase=='dex'then
  if t-self.phaseT>=M.T.dex or(pressed and t-self.phaseT>2.5)then
   self.phase='out';self.phaseT=t
  end
 elseif self.phase=='out'then
  if t-self.phaseT>=M.T.out then self:close()end
 end
end
function Screen:startTeam()
 local t=now()
 self.phase='team';self.phaseT=t;self.index=#self.mons+1
 self:moveTo(M.shotTeam(),M.T.team)
 for k,m in ipairs(self.mons)do
  if m.shown then m.cheerAt=t+M.T.cheer+(k-1)*.16 end
 end
end
------------------------------------------------------------------ Professor Oak's question
-- the engine's strings catalogue (a translation can cover these too)
local function say(s)
 local ok,r=pcall(function()return require('src.core.Strings')(s)end)
 return ok and type(r)=='string'and r or s
end
-- asked only when the parade will follow this ceremony (ChampionParade
-- knows: the Hall of Fame's "when done" leads to it, and 3D is on)
function Screen:rideOffered()
 local ok,yes=pcall(function()
  local CP=V.require('ChampionParade')
  return CP and CP.rideOffered and CP.rideOffered(self.game)
 end)
 return ok and yes and true or false
end
-- you, and Professor Oak at the record (his own character in the hall)
function Screen:oakPeople()
 local ow=self.game and self.game.overworld
 local me=ow and ow.player
 local oak=nil
 for _,npc in ipairs(ow and ow.npcs or{})do
  local d=npc.def
  if d and d.sprite=='SPRITE_OAK'then oak=npc;break end
 end
 return me,oak
end
local function groundXZ(e)
 if not e then return nil end
 local x=tonumber(e.px)or(tonumber(e.cellX)or 0)*16
 local z=tonumber(e.py)or(tonumber(e.cellY)or 0)*16
 return{x+8,z+8}
end
function Screen:startOak()
 local t=now()
 self.phase='oak';self.phaseT=t
 local me,oak=self:oakPeople()
 local a,b=groundXZ(me),groundXZ(oak)
 local mid
 if a and b then mid={(a[1]+b[1])/2,(a[2]+b[2])/2}
 elseif a then mid={a[1]+8,a[2]}
 else mid={M.CENTRE_X,40}end
 -- (inside the hall, whatever the positions say)
 mid[1]=max(40,min(120,mid[1]));mid[2]=max(16,min(60,mid[2]))
 self.oakMid=mid
 self:moveTo(M.shotOak(mid),M.T.oakMove)
end
-- the two of you turn to the camera as it arrives
function Screen:faceOak()
 local me,oak=self:oakPeople()
 -- (a trainer model mod turns your body by your last movement, not by your
 -- facing: its own heading is turned to the camera as well)
 if me then pcall(function()me.facing='down';if me.pmlFreeBodyYaw~=nil then me.pmlFreeBodyYaw=0 end end)end
 if oak then pcall(function()oak.facing='down';if oak.pinnedFacing then oak.pinnedFacing='down'end end)end
end
-- TEST264: one announcement, acknowledged with the normal text controls.
-- No travel-mode choice remains, including when the text box cannot load.
function Screen:askOak()
 local game=self.game
 self.oakChoice='float'
 pcall(function()local CP=V.require('ChampionParade');if CP.choose then CP.choose('float')end end)
 local ok=pcall(function()
  local TextBox=require('src.render.TextBox')
  game.stack:push(TextBox.new(game,say(M.OAK_ASK),function()
   if not self.finished then self.oakDone=now()end
  end))
 end)
 if not ok then self.oakDone=now()end
end

-- a salvo over the hall, bursting in the sky the crane rises into
local SALVO_COLS={{1,.30,.26},{1,.80,.28},{.36,.60,1},{.50,1,.42},{1,.42,.86},{1,.96,.90}}
function Screen:salvo(at)
 local list={}
 for k,dt in ipairs(at)do
  local r1,r2,r3=hash(k,1),hash(k,2),hash(k,3)
  list[#list+1]={launchT=now()+dt,rise=1.05,kind=(k*3)%4,scale=.8,
   bx=M.CENTRE_X+(r1-.5)*150,by=155+r2*35,bz=-45-r3*40,
   R=80+30*r1,col=SALVO_COLS[(k*5)%#SALVO_COLS+1]}
 end
 pcall(function()V.require('LeagueRoad').salvo(M.ROOM,list)end)
end
-- the game's POKeDEX lines, in a panel of their own; the camera cranes up
-- to the sky over HALL OF FAME, and the fireworks go up
function Screen:dexInfo()
 if self.dexCache then return self.dexCache end
 local game=self.game
 local seen,owned=0,0
 pcall(function()
  local dex=game.save.pokedex or{seen={},owned={}}
  for _ in pairs(dex.seen or{})do seen=seen+1 end
  for _ in pairs(dex.owned or{})do owned=owned+1 end
 end)
 local text=game.data and game.data.text or{}
 local header=plain(text._DexRatingText or'POK\195\169DEX Rating:')
 local rating=plain(text[dexRatingKey(owned)]or'Keep it up!')
 self.dexCache={seen=seen,owned=owned,header=header,rating=rating}
 return self.dexCache
end
function Screen:startDex()
 self.phase='dex';self.phaseT=now();self.dexT=self.phaseT
 self:dexInfo()
 self:moveTo(M.shotCrane(),M.T.crane)
 self:salvo({2.0,2.6,3.2,3.7,4.3,4.9,5.5})
end
function Screen:close()
 if self.finished then return end
 self.finished=true
 if active==self then active=nil end
 for _,m in ipairs(self.mons)do releaseModel(m)end
 pcall(function()self.game.stack:pop()end)
 if self.onDone then self.onDone()end
end
-- popped by anything else (a soft reset back to the title): let go of the
-- camera, the panels and the models, without going on to the credits
function Screen:exit()
 self.finished=true
 if active==self then active=nil end
 for _,m in ipairs(self.mons)do releaseModel(m)end
end
function Screen:draw()end   -- the room is the picture; panels come from the HUD
M.Screen=Screen

------------------------------------------------------------------ the camera
-- FirstPerson.frame's stand-in while the induction runs
function M.rig()
 local s=active
 if not s or s.finished then return nil end
 return s:camera()
end

------------------------------------------------------------------ the room
local podiumMesh,trimMesh=nil,nil
local function prism(R,h,y0,sides)
 local Voxel3D=V.require('Voxel3D')
 local verts,idx={},{}
 local q=0
 local function quad(a,b,c,d,shade)
  for _,p in ipairs({a,b,c,d})do verts[#verts+1]={p[1],p[2],p[3],.5,.5,shade}end
  Voxel3D.pushQuad(idx,q);q=q+1
 end
 for i=0,sides-1 do
  local a0,a1=i/sides*pi*2,(i+1)/sides*pi*2
  local x0,z0,x1,z1=cos(a0)*R,sin(a0)*R,cos(a1)*R,sin(a1)*R
  quad({x0,y0,z0},{x1,y0,z1},{x1,y0+h,z1},{x0,y0+h,z0},.78+.18*abs(cos((a0+a1)/2)))
  quad({0,y0+h,0},{x1,y0+h,z1},{x0,y0+h,z0},{0,y0+h,0},1)
 end
 return Voxel3D.newMesh(verts,idx)
end
local function meshes()
 if podiumMesh==nil then
  local ok,a=pcall(prism,7,M.PODIUM_Y-.8,0,8);podiumMesh=ok and a or false
  local ok2,b=pcall(prism,7.6,.8,M.PODIUM_Y-.8,8);trimMesh=ok2 and b or false
 end
 return podiumMesh or nil,trimMesh or nil
end
-- the models, drawn into the room's own depth buffer with the room's camera
local function drawModels(s,t)
 for i,m in ipairs(s.mons)do
  local md=m.model
  if md and m.shown then
   local grow=backOut((t-m.shown)/M.T.grow)
   if grow>.01 then
    local p=m.podium
    local yaw=(m.yaw or 0)+.10*sin(t*.5+i*1.3)
    local f=max(0,1-(t-m.shown)/M.T.flash)
    -- one that will not draw goes back to its picture
    if not drawModel(md,p.x,p.y,p.z,yaw,grow,f)then releaseModel(m)end
   end
  end
 end
end
-- every frame of the Hall of Fame room (LeagueRoomFx, after its own effects)
function M.drawWorld(K,t)
 local s=active
 if not s or s.finished then return end
 -- (the team keeps moving while a text box is over the ceremony)
 pcall(s.tick,s,t)
 local Voxel3D=V.require('Voxel3D')
 local Mat4=V.require('Mat4')
 local BB=V.require('BattleBillboard')
 local g=love.graphics
 local body,trim=meshes()
 local white=K and K.white
 if not white then return end
 -- the podiums (lit, solid; both faces, whichever way they wind)
 local cull=nil
 pcall(function()cull=g.getMeshCullMode();g.setMeshCullMode('none')end)
 for i,m in ipairs(s.mons)do
  local p=m.podium
  local M4=Mat4.translate(p.x,0,p.z)
  if body then g.setColor(.93,.91,.86,1);Voxel3D.draw(body,white,M4)end
  if trim then g.setColor(.95,.74,.30,1);Voxel3D.draw(trim,white,M4)end
 end
 if cull then pcall(g.setMeshCullMode,cull)end
 -- a soft shadow under each model on its podium
 if K.quad and K.soft then
  pcall(Voxel3D.withEffect,'alpha',function()
   for _,m in ipairs(s.mons)do
    local md=m.model
    if md and m.shown then
     local grow=smooth((t-m.shown)/M.T.grow)
     local p=m.podium
     local r=md.footR*(.4+.6*grow)
     g.setColor(0,0,0,.42*grow)
     Voxel3D.draw(K.quad,K.soft,Mat4.mul(Mat4.translate(p.x,p.y+.06,p.z),Mat4.scale(r,1,r*.9)))
    end
   end
  end)
  g.setColor(1,1,1,1)
 end
 -- the models
 pcall(drawModels,s,t)
 -- the pictures (unlit: their own colours, cut out by their alpha)
 Voxel3D.lighting(false)
 if Voxel3D.seams then Voxel3D.seams(false)end
 for i,m in ipairs(s.mons)do
  local a=m.art
  if m.shown and a and not m.model then
   local grow=backOut((t-m.shown)/M.T.grow)
   if grow>0 then
    local p=m.podium
    local w,h=a.w*grow,a.h*grow
    local yaw=BB.yawToward(p.x,p.z,Voxel3D.eye)
    local x=p.x-cos(yaw)*a.cx*grow
    local z=p.z+sin(yaw)*a.cx*grow
    local y=p.y-a.foot*grow
    g.setColor(1,1,1,1)
    Voxel3D.draw(BB.mesh(),a.frames[a.frame]or a.frames[1],BB.matrix(x,y,z,w,h,yaw),BB.PULL)
   end
  end
 end
 if Voxel3D.seams then Voxel3D.seams(true)end
 Voxel3D.lighting(true)
 -- the light: a beam on the podium being inducted, a glow round each one
 -- inducted, the flash and ring as it appears, and the burst of sparks
 pcall(Voxel3D.withEffect,'add',function()
  for i,m in ipairs(s.mons)do
   local p=m.podium
   local cur=(i==s.index)and(s.phase=='move'or s.phase=='info'or s.phase=='banner')
   if cur and K.cross and K.soft then
    local u=s.phase=='move'and smooth((t-s.phaseT)/M.T.move)or 1
    g.setColor(1,.90,.62,.16*u)
    Voxel3D.draw(K.cross,K.soft,Mat4.mul(Mat4.translate(p.x,p.y+36,p.z),Mat4.scale(9,72,9)))
    g.setColor(1,.85,.5,.22*u)
    Voxel3D.draw(K.cross,K.soft,Mat4.mul(Mat4.translate(p.x,p.y+.2,p.z),Mat4.scale(16,2,16)))
   end
   if m.shown and K.cross and K.soft then
    local age=t-m.shown
    local hh=heightOf(m)
    local pulse=.75+.25*sin(t*1.7+i)
    -- the whole team lights up together when they cheer
    local cheer=m.burst and m.burst>m.shown and max(0,1-(t-m.burst)/1.2)or 0
    g.setColor(1,.80,.40,.13*pulse+.20*cheer)
    Voxel3D.draw(K.cross,K.soft,Mat4.mul(Mat4.translate(p.x,p.y+hh*.4,p.z),Mat4.scale(14,hh*.8,14)))
    if age<.6 then
     -- the white flash it appears in
     local f=1-age/.6
     g.setColor(1,.96,.86,.55*f)
     local q=10+hh*.6
     Voxel3D.draw(K.cross,K.soft,Mat4.mul(Mat4.translate(p.x,p.y+hh*.5,p.z),Mat4.scale(q,q,q)))
    end
    if age<.9 and K.quad and K.ring then
     -- a ring of light running out across the podium and the floor
     local u=age/.9
     local r=3+u*20
     g.setColor(1,.86,.50,.6*(1-u))
     Voxel3D.draw(K.quad,K.ring,Mat4.mul(Mat4.translate(p.x,p.y+.12,p.z),Mat4.scale(r,1,r)))
    end
    local b=t-(m.burst or m.shown)
    if b<1.4 then
     for k=0,23 do
      local a=k*2.39996
      local r=(4+b*26)*(.6+.4*((k*7)%5)/5)
      local up=b*(14+(k%4)*5)-b*b*8
      local f=1-b/1.4
      g.setColor(1,.88,.45,.9*f)
      local sz=1.1*f+.3
      Voxel3D.draw(K.cross,K.soft,Mat4.mul(Mat4.translate(p.x+cos(a)*r,p.y+6+up,p.z+sin(a)*r),Mat4.scale(sz,sz,sz)))
     end
    end
   end
  end
 end)
 g.setColor(1,1,1,1)
end

------------------------------------------------------------------ the panels
local fonts={}
local function font(size)
 size=max(8,floor(size))
 if fonts[size]==nil then local ok,f=pcall(love.graphics.newFont,size);fonts[size]=ok and f or false end
 return fonts[size]or nil
end
local TYPE_COL={NORMAL={.66,.66,.48},FIRE={.94,.50,.19},WATER={.41,.56,.94},ELECTRIC={.97,.82,.19},
 GRASS={.47,.78,.31},ICE={.59,.85,.85},FIGHTING={.75,.19,.16},POISON={.63,.25,.63},GROUND={.88,.75,.41},
 FLYING={.66,.56,.94},PSYCHIC={.97,.34,.53},BUG={.66,.72,.13},ROCK={.72,.63,.22},GHOST={.44,.35,.60},
 DRAGON={.44,.22,.97},DARK={.44,.35,.28},STEEL={.72,.72,.81},FAIRY={.93,.60,.68}}
local function panel(g,x,y,w,h,a)
 a=a or 1
 g.setColor(.08,.02,.03,.80*a);g.rectangle('fill',x,y,w,h,6,6)
 g.setColor(.62,.08,.10,.85*a);g.rectangle('fill',x,y,w,h*.08,6,6)
 g.setColor(.95,.76,.32,a);g.setLineWidth(2);g.rectangle('line',x,y,w,h,6,6)
end
local function drawDex(s,g,W,H,t)
 local d=s:dexInfo()
 local e=t-(s.dexT or t)
 local u=smooth(e/.5)
 if s.phase=='out'then u=u*(1-smooth((t-s.phaseT)/.5))end
 if u<=0 then return end
 local pw,ph=W*.34,H*.40
 local x,y=W*.62+(1-u)*pw*.25,H*.26
 panel(g,x,y,pw,ph,u)
 local fT,fN,fS=font(H*.030),font(H*.058),font(H*.032)
 if fT then
  g.setFont(fT);g.setColor(.98,.82,.40,u);g.print('POK\195\169DEX',x+pw*.06,y+ph*.06)
  g.setColor(.95,.92,.85,.85*u)
  g.print('SEEN',x+pw*.06,y+ph*.19);g.print('OWNED',x+pw*.52,y+ph*.19)
 end
 if fN then
  -- the counts roll up
  local c=smooth((e-.3)/M.T.dexCount)
  g.setFont(fN);g.setColor(1,1,1,u)
  g.print(tostring(floor(d.seen*c+.5)),x+pw*.06,y+ph*.27)
  g.print(tostring(floor(d.owned*c+.5)),x+pw*.52,y+ph*.27)
 end
 local r=smooth((e-M.T.dexRating)/.6)*u
 if r>0 then
  g.setColor(.95,.76,.32,r);g.rectangle('fill',x+pw*.06,y+ph*.49,pw*.88*r,2)
  if fT then g.setFont(fT);g.setColor(.98,.82,.40,r);g.print(d.header,x+pw*.06,y+ph*.53)end
  if fS then
   g.setFont(fS);g.setColor(1,1,1,r)
   if g.printf then g.printf(d.rating,x+pw*.06,y+ph*.64,pw*.88,'left')
   else g.print(d.rating,x+pw*.06,y+ph*.64)end
  end
 end
end
function M.drawHud()
 local s=active
 if not s or s.finished then return end
 local g=love.graphics
 local W,H=g.getDimensions()
 local t=now()
 g.origin();g.setShader();g.setScissor();pcall(g.setDepthMode);g.setBlendMode('alpha')
 local game=s.game
 -- the induction panel
 local m=s:current()
 if m and(s.phase=='info'or s.phase=='banner')then
  local mon=m.mon
  local def=game.data.pokemon and game.data.pokemon[mon.species]
  local name=tostring(mon.nickname or(def and def.name)or mon.species)
  local u=smooth((t-(m.shown or t))/.45)
  local pw,ph=W*.36,H*.25
  local x=W*.05-(1-u)*pw*.4;local y=H*.60
  panel(g,x,y,pw,ph,u)
  local fT,fN,fS=font(H*.032),font(H*.062),font(H*.036)
  if fT then g.setFont(fT);g.setColor(.98,.82,.40,u)
   g.print(('HALL OF FAME  %d/%d'):format(s.index,#s.mons),x+pw*.05,y+ph*.12)
   local dex=m.model and m.model.dex or dexOf(game,mon.species)
   if dex then
    local label=('No.%03d'):format(dex)
    g.setColor(.95,.92,.85,.8*u);g.print(label,x+pw*.95-fT:getWidth(label),y+ph*.12)
   end
  end
  if fN then g.setFont(fN);g.setColor(1,1,1,u);g.print(name,x+pw*.05,y+ph*.28)end
  if fS then
   g.setFont(fS);g.setColor(.95,.92,.85,u)
   g.print(('Lv. %s'):format(tostring(mon.level or'?')),x+pw*.05,y+ph*.66)
   local types=def and def.types or{}
   local tx=x+pw*.40
   local TC=nil;pcall(function()TC=require('src.battle.TypeChart')end)
   for k=1,min(2,#types)do
    local ty=types[k]
    if k==2 and ty==types[1]then break end
    local label=tostring(ty)
    if TC and TC.displayName then local ok,n=pcall(TC.displayName,ty,game.data);if ok and n then label=tostring(n)end end
    local c=TYPE_COL[tostring(ty):upper()]or{.6,.6,.6}
    local tw=fS:getWidth(label)+H*.03
    g.setColor(c[1],c[2],c[3],.95*u);g.rectangle('fill',tx,y+ph*.64,tw,fS:getHeight()*1.1,8,8)
    g.setColor(1,1,1,u);g.print(label,tx+H*.015,y+ph*.66)
    tx=tx+tw+H*.015
   end
  end
  -- HALL OF FAME, sweeping in under it
  if s.phase=='banner'then
   local b=smooth((t-s.phaseT)/.5)
   local fB=font(H*.07)
   if fB then
    local msg='HALL OF FAME'
    local bw=fB:getWidth(msg)
    local bx,by=W/2-bw/2,H*.87
    g.setColor(.08,.02,.03,.70*b);g.rectangle('fill',0,by-H*.015,W,fB:getHeight()+H*.03)
    g.setColor(.95,.76,.32,b);g.rectangle('fill',W/2-(bw/2+H*.05)*b,by-H*.015,(bw+H*.1)*b,2)
    g.rectangle('fill',W/2-(bw/2+H*.05)*b,by+fB:getHeight()+H*.013,(bw+H*.1)*b,2)
    g.setFont(fB);g.setColor(1,.86,.45,b);g.print(msg,bx,by)
   end
  end
 end
 -- the team: you, your time and your money
 if s.phase=='team'or s.phase=='dex'or s.phase=='out'or s.phase=='oak'then
  local u=smooth((t-s.phaseT-(s.phase=='team'and M.T.team*.6 or-9))/.5)
  -- (it steps aside while Professor Oak talks, and comes back with the dex)
  if s.phase=='oak'then u=1-smooth((t-s.phaseT)/.45)
  elseif s.phase=='dex'and s.oakAsked then u=smooth((t-s.phaseT-.3)/.6)end
  local save=game.save or{}
  local pw,ph=W*.30,H*.22
  local x,y=W*.04,H*.06
  panel(g,x,y,pw,ph,u)
  local fT,fN,fS=font(H*.030),font(H*.052),font(H*.034)
  if fT then g.setFont(fT);g.setColor(.98,.82,.40,u);g.print('CHAMPION',x+pw*.06,y+ph*.12)end
  if fN then g.setFont(fN);g.setColor(1,1,1,u);g.print(tostring(save.player and save.player.name or'RED'),x+pw*.06,y+ph*.28)end
  if fS then
   g.setFont(fS);g.setColor(.95,.92,.85,u)
   local tt=floor(save.playTime or 0)
   g.print(('PLAY TIME  %d:%02d'):format(floor(tt/3600),floor(tt/60)%60),x+pw*.06,y+ph*.60)
   g.print(('MONEY  \194\165%d'):format(save.money or 0),x+pw*.06,y+ph*.78)
  end
 end
 -- the POKeDEX
 if s.phase=='dex'or(s.phase=='out'and s.dexT)then drawDex(s,g,W,H,t)end
 -- the fade to white at the end
 if s.phase=='out'then
  local w=smooth((t-s.phaseT)/M.T.out)
  g.setColor(1,1,1,w);g.rectangle('fill',0,0,W,H)
 end
 g.setColor(1,1,1,1)
end

------------------------------------------------------------------ the hooks
-- the 3D induction only where it makes sense: 3D on, in the 3D hall
local function canRun(game)
 local ok,yes=pcall(function()
  local R=V.require('Voxel3D')
  if not(R.available and R.available())then return false end
  local okS,Voxel=pcall(V.require,'VoxelState')
  if okS and Voxel and Voxel.active and not Voxel.active()then return false end
  local map=game and game.overworld and game.overworld.map
  if not(map and tostring(map.id)==M.ROOM)then return false end
  local Rooms=V.require('LeagueRooms')
  return Rooms.accepts and Rooms.accepts(map)and true or false
 end)
 return ok and yes or false
end
M.canRun=canRun

local HoF,origNew=nil,nil
local FP,origFrame=nil,nil
local removeH
local partnerHandle
function M.install(mod)
 if origNew then return end
 modRef=mod
 local ok,mod_=pcall(require,'src.ui.HallOfFame')
 if not(ok and type(mod_)=='table'and type(mod_.new)=='function')then return end
 HoF,origNew=mod_,mod_.new
 HoF.new=function(game,onDone,...)
  -- (a screen left over from an interrupted ceremony lets go first)
  if active then pcall(active.exit,active)end
  if canRun(game)then
   local okS,s=pcall(Screen.new,game,onDone)
   if okS and s then active=s;return s end
  end
  return origNew(game,onDone,...)
 end
 -- the camera
 local okF,FirstPerson=pcall(V.require,'FirstPerson')
 if okF and FirstPerson and type(FirstPerson.frame)=='function'then
  FP,origFrame=FirstPerson,FirstPerson.frame
  FirstPerson.frame=function(...)
   local r1,r2,r3=origFrame(...)
   local R=V.require('Voxel3D')
   local rig=M.rig()
   if rig then
    R.camera=rig;lastRig=rig
    -- (TEST228: the partner steps out of the ceremony; renewed every frame)
    pcall(function()
     local ow=active and active.game and active.game.overworld
     if ow then ow.legendaryHideFollowers=now()end
    end)
    return rig,rig.focus[1],rig.focus[3]
   end
   if lastRig and R.camera==lastRig then R.camera=nil end
   lastRig=nil
   return r1,r2,r3
  end
 end
 -- (TEST228: a partner drawn as a card steps out too)
 pcall(function()
  local CR=V.require('CharacterRenderers')
  local function hidden(ctx)
   -- (the follower test first: it is cheap, and most callers are not one;
   -- only then whether the ceremony's camera is up)
   if type(ctx)~='table'or ctx.isPlayer or ctx.role=='player'then return false end
   local e=ctx.actor or ctx.entity or(ctx.pose and ctx.pose.entity)
   if type(e)~='table'then return false end
   if not(e.pikachuFollower==true or e.isPokemonFollower==true or e.pokepcTrailer==true
     or e.wildsFollower==true or e._pokepcFollowerSpecies~=nil or e._wildsFollowerSpecies~=nil
     or e.name=='PIKACHU_FOLLOWER')then return false end
   return active~=nil and M.rig()~=nil
  end
  partnerHandle=CR.register({apiVersion=1,id='battle_art.hall_of_fame.partner',priority=1000,
   name='Hall of Fame: the partner steps aside',
   drawEntity=hidden,drawShadow=hidden,drawReflection=hidden})
 end)
 if mod and mod.hooks and mod.hooks.wrap then
  removeH=mod.hooks:wrap('render.hud',function(nxt,game,viewport)
   local a,b,c=nxt(game,viewport)
   if active then love.graphics.push('all');pcall(M.drawHud);love.graphics.pop()end
   return a,b,c
  end)
 end
end
function M.dispose()
 if partnerHandle then pcall(partnerHandle.release,partnerHandle);partnerHandle=nil end
 if HoF and origNew then HoF.new=origNew end
 if FP and origFrame then FP.frame=origFrame end
 HoF,origNew,FP,origFrame=nil,nil,nil,nil
 if removeH then pcall(removeH);removeH=nil end
 if active then for _,m in ipairs(active.mons)do releaseModel(m)end end
 active=nil
 pcall(function()local R=V.require('Voxel3D');if lastRig and R.camera==lastRig then R.camera=nil end end)
 lastRig=nil
 if podiumMesh then pcall(podiumMesh.release,podiumMesh)end
 if trimMesh then pcall(trimMesh.release,trimMesh)end
 podiumMesh,trimMesh=nil,nil
 modRef=nil
end
function M.active()return active~=nil end
M._active=function()return active end
return M
