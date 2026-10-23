-- Native source-map views, shared async geometry and isolated render targets.
local V=...
local M={};local Profiles=V.require('ScenicProfiles');local World=V.require('ScenicWorld')
local R=V.require('Voxel3D');local Mat=V.require('Mat4');local DN=V.require('DayNight')
local Overlay=V.require('ScenicOverlay')
M.setting=V.require('ModSetting').new('scenicViews','SCENIC VIEWS',{'on','off'},{'ON','OFF'})
local cache,texture,font;local windows={};local failed=false
local function enabled()return M.setting:get()~='off'end
local function release(x)if x and x.release then pcall(x.release,x)end end
function M.invalidate()
 if cache then World.close(cache.scene)end;cache=nil
 for _,w in pairs(windows)do release(w.mesh);release(w.frame);release(w.canvas)end;windows={}
 failed=false
end
-- (asked several times a frame: only the roofs can be one)
function M.roof(map)
 if not(map and Profiles.roofs[map.id])then return false end
 local p=M.profile(map);return p and p.roof==true or false
end
function M.profile(map)
 if not enabled()then return end
 local Game=require('src.core.Game');local defs=Game.data and Game.data.maps or{}
 local p=Profiles.profile(map,defs);if not p then return end
 -- (TEST178: a town room's profile arrives placed)
 if not p.x then p.x,p.z,p.width,p.depth=Profiles.anchor(p,defs)end
 if not p.x then return end
 return p,defs
end
-- TEST178: a town room asks for its town only once it is built and has
-- panes to look out of (a room with no window or door costs nothing)
local function interiorPanes(map)
 local ok,n=pcall(function()
  local Rooms=V.require('InteriorRooms')
  if Rooms.ready(map.id)~=true then return 0 end
  return #Rooms.windowPanes(map)
 end)
 return ok and n or 0
end
local function palette()
 if texture then return texture end
 local data=love.image.newImageData(#World.colors,1)
 for i,c in ipairs(World.colors)do data:setPixel(i-1,0,c[1],c[2],c[3],1)end
 texture=love.graphics.newImage(data);data:release();texture:setFilter('nearest','nearest')
 return texture
end
function M.request(map)
 local p,defs=M.profile(map)
 if p and p.generic and not(cache and cache.map==map)and interiorPanes(map)==0 then p=nil end
 if not p then if cache then M.invalidate()end;return end
 if not cache or cache.city~=p.city or cache.defs~=defs or cache.map~=map then
  M.invalidate();cache={city=p.city,defs=defs,map=map,profile=p,scene=World.new(p,defs)}
 end
 return cache
end
function M.pump(map)
 local c=M.request(map);if not c or c.error then return c end
 local ok,ready=pcall(World.pump,c.scene)
 if ok then c.ready=ready else
  c.error=tostring(ready);c.ready=false
  if V.mod.log then V.mod.log:info('Native scenic build unavailable: '..c.error)end
 end
 return c
end
-- Called before the gameplay live-set is committed, also while binoculars
-- cover the room. Scenic jobs therefore survive ordinary update-side eviction.
function M.retain(map,live,ids)
 local ok,c=pcall(M.pump,map)
 if ok and c and not c.error then World.retain(c.scene,live,ids)end
end
local function sky()
 local pal=DN.palette();local top,low=pal[#pal],pal[1]
 return {top[1]/255,top[2]/255,top[3]/255},{low[1]/255,low[2]/255,low[3]/255}
end
function M.sky()local _,low=sky();return {low[1],low[2],low[3],1}end
-- Render before the main scene opens; restore graphics AND Voxel3D state.
function M.capture(c,w,h,eye,yaw,pitch,fov,key,projection)
 if not c or not c.ready or failed then return end
 key=key or 'view';local slot=windows[key]or{};windows[key]=slot
 local g=love.graphics;local previous={g.getCanvas()};g.push('all')
 local ok,result=pcall(function()
  World.prepare(c.scene)
  if not slot.canvas or slot.w~=w or slot.h~=h then
   release(slot.canvas);slot.canvas=nil
   local made,target=V.require('PixelCanvas').new(w,h)
   if not made then error(target)end
   slot.canvas=target;slot.w,slot.h=w,h;target:setFilter('linear','linear')
  end
  local focus={eye[1]+math.sin(yaw)*math.cos(pitch)*100,
   eye[2]+math.sin(pitch)*100,eye[3]-math.cos(yaw)*math.cos(pitch)*100}
  local vp=Mat.mul(Mat.scale(1,-1,1),Mat.mul(projection or Mat.perspective(fov,w/h,.1,7000),Mat.lookAt(eye,focus,{0,1,0})))
  local p=c.profile;local hw,hd=(p.width or 64)/2+2,(p.depth or 48)/2+2
  local hide=p.hide or {p.x-hw,p.z-hd,p.x+hw,p.z+hd}
  local sky=V.require('Sky').dress(M.sky())
  local drawn,err=R.captureScenic({canvas=slot.canvas,width=w,height=h,
   eye=eye,focus=focus,fov=fov,vp=vp,sky=sky,
   glassMask=V.require('GlassMask').texture(c.scene.state.map.tileset),
   configure=function()V.require('StreetLights').configure(c.scene.state)end,
   hide=hide},function()
    World.background(c.scene)
    World.draw(c.scene)
   end)
  if not drawn then error(err)end
  return slot.canvas
 end)
 g.pop();pcall(g.setCanvas,unpack(previous))
 if not ok then
  failed=true;c.error=tostring(result)
  if V.mod.log then V.mod.log:info('Native scenic view unavailable: '..tostring(result))end
  return nil
 end
 return result
end
function M.drawRoof(state)
 local c=cache;if not(c and c.ready and c.map==state.map and c.profile.roof)then return end
 local p=c.profile;local d=state.map.def
 -- TEST144: the store's own city model (rooftop pavilion, terrace benches,
 -- parapet) sits right under this map. Nothing of the city may rise above
 -- the roof deck inside the roof's footprint, or it pokes through.
 local hw=math.max(d.width*16,(p.width or 0)/2)+4
 local hd=math.max(d.height*16,(p.depth or 0)/2)+4
 local cx,cz=d.width*16,d.height*16
 local hide=R.setScenicHide and state.map.id=='CELADON_MART_ROOF'
 if hide then R.setScenicHide({cx-hw,cz-hd,cx+hw,cz+hd})end
 local ok,err=pcall(World.draw,c.scene,{d.width*16-p.x,-p.height,d.height*16-p.z})
 if hide then R.setScenicHide(nil)end
 if not ok then c.error=tostring(err);c.ready=false end
end
-- TEST173: a room built whole by InteriorRooms says where its own windows are
local function interior(map)
 local ok,own=pcall(function()return V.require('InteriorRooms').accepts(map)end)
 return ok and own
end
local function shellFacing(c,map,eye)
 if interior(map)then return V.require('InteriorRooms').visibleShell(map,eye)end
 return c.profile.red and V.require('RedsHouseRoom').visibleShell(eye)or nil
end
function M.panes(map)
 if interior(map)then return V.require('InteriorRooms').windowPanes(map)end
 if map.id=='REDS_HOUSE_1F' or map.id=='REDS_HOUSE_2F'then
  return V.require(map.id=='REDS_HOUSE_1F' and 'RedsHouseRoom' or 'RedsBedroomRoom').windowPanes(map)
 end
 local w=map.def.width*32
 return {{side='north',x=w/2,z=16.25,lo=19,hi=35,a=-23,b=23,yaw=0,generic=true}}
end
-- TEST144: calm windows. Each pane is rendered from ONE fixed eye standing
-- in front of the glass, looking straight out, so the view never re-renders
-- from the orbiting camera (that made the scenery lurch and jump between
-- 0.1 s refreshes). The image is captured with a little spare border and a
-- smooth, small parallax is applied every frame by sliding the picture
-- inside that border. Panes are relit every few seconds for the clock and
-- street lights; with a fixed eye that refresh is invisible.
local MARGIN=.1      -- spare image on each side, as a fraction of the canvas
local EYE_BACK=44    -- room units in front of the pane where the fixed eye stands
local REFRESH=6      -- seconds between relights of one visible pane
local PACE=.15       -- at most one pane capture per this many seconds
local function sub(a,b)return {a[1]-b[1],a[2]-b[2],a[3]-b[3]}end
local function dot(a,b)return a[1]*b[1]+a[2]*b[2]+a[3]*b[3]end
local function unit(a)local l=math.sqrt(dot(a,a));if l<1e-6 then return {0,0,0},0 end;return {a[1]/l,a[2]/l,a[3]/l},l end
local function paneCorners(win)
 if win.corners then return win.corners end
 local function pos(u,y)
  if win.side=='east'then return {win.x,y,win.z-u}end
  if win.side=='south'then return {win.x-u,y,win.z}end
  return {win.x+u,y,win.z}
 end
 return {pos(win.a,win.lo),pos(win.b,win.lo),pos(win.b,win.hi),pos(win.a,win.hi)}
end
-- Pane frame in room space: centre, right/up axes and the inward normal.
local function paneFrame(win)
 local q=paneCorners(win)
 -- (TEST179: pieces of one glass wall share the wall's centre, so they are
 -- captured from one eye and slide together)
 local c=win.center or {(q[1][1]+q[2][1]+q[3][1]+q[4][1])/4,(q[1][2]+q[2][2]+q[3][2]+q[4][2])/4,(q[1][3]+q[2][3]+q[3][3]+q[4][3])/4}
 local right=unit(sub(q[2],q[1]));local up=unit(sub(q[4],q[1]))
 local inward={-math.sin(win.yaw or 0),0,math.cos(win.yaw or 0)}
 return c,right,up,inward
end
M.paneFrame=paneFrame
-- Off-axis window projection through the actual pane, from `camera` (room
-- space). `widen` grows the frustum around its centre (spare border).
function M.windowCamera(map,p,win,camera,widen)
 local sx=(p.width or 64)/(map.def.width*32)
 local sz=(p.depth or 48)/(map.def.height*32);local sy=.5
 local function world(q)return {p.x+(q[1]-map.def.width*16)*sx,p.height+q[2]*sy,p.z+(q[3]-map.def.height*16)*sz}end
 local eye=world(camera);local a,b,d=world(win.corners[1]),world(win.corners[2]),world(win.corners[3])
 local sn,cs=math.sin(win.yaw),math.cos(win.yaw)
 local distance=(a[1]-eye[1])*sn-(a[3]-eye[3])*cs
 if distance<.15 then return end -- that shell wall is cut away
 local near,far=.1,7000
 local function lateral(q)return ((q[1]-eye[1])*cs+(q[3]-eye[3])*sn)*near/distance end
 local l,r=lateral(a),lateral(b);local lo,hi=(a[2]-eye[2])*near/distance,(d[2]-eye[2])*near/distance
 if r-l<.0001 or hi-lo<.0001 then return end
 if widen and widen~=1 then
  local mx,hx=(l+r)/2,(r-l)/2*widen;local my,hy=(lo+hi)/2,(hi-lo)/2*widen
  l,r,lo,hi=mx-hx,mx+hx,my-hy,my+hy
 end
 return eye,{2*near/(r-l),0,(r+l)/(r-l),0, 0,2*near/(hi-lo),(hi+lo)/(hi-lo),0,
  0,0,-(far+near)/(far-near),-2*far*near/(far-near), 0,0,-1,0}
end
local function fixedEye(map,p,win)
 local widen=1/(1-2*MARGIN)
 if win.corners then
  local c,_,_,inward=paneFrame(win)
  local cam={c[1]+inward[1]*EYE_BACK,c[2],c[3]+inward[3]*EYE_BACK}
  local eye,projection=M.windowCamera(map,p,win,cam,widen)
  return eye,projection,0,nil
 end
 -- Generic pane: a level view from the building's centre, a wider lens.
 local fov=2*math.atan(math.tan(math.rad(66)/2)*widen)
 return {p.x,p.height+12,p.z},nil,-.06,fov
end
local function prepareWindows(state)
 local c=M.pump(state.map)
 if not(c and c.ready)then return end
 if c.profile.roof then World.prepare(c.scene);return end
 if not c.profile.windows then return end
 local p=c.profile
 local panes=M.panes(state.map);local cursor=c.windowCursor or 0
 local visible=shellFacing(c,state.map,R.eye)
 local stamp=love.timer.getTime()
 if stamp<(c.windowNext or 0)then return end
 -- TEST178: a town room may have many panes. The ones in sight are made
 -- first, then the ones out of sight; the ones in sight are relit in turn,
 -- more slowly the more there are.
 local shown=0
 for _,win in ipairs(panes)do if not visible or visible[win.side]then shown=shown+1 end end
 local refresh=p.generic and math.max(REFRESH,shown*.6)or REFRESH
 local pick,rank
 for step=1,#panes do
  local i=(cursor+step-1)%#panes+1;local win=panes[i]
  local slot=windows['pane'..i]
  local seen=not visible or visible[win.side]
  local fresh=not(slot and slot.canvas)
  local r=(fresh and seen and 1)or(seen and not fresh and stamp-(slot.captured or 0)>refresh and 2)
   or(fresh and not p.generic and 3)or nil
  if slot and(slot.retry or 0)>stamp then r=nil end
  if r and(not rank or r<rank)then pick,rank=i,r;if r==1 then break end end
 end
 if pick then
  local i=pick;local win=panes[i]
  local key='pane'..i;local slot=windows[key]
  do
   local eye,projection,pitch,fov=fixedEye(state.map,p,win)
   if eye then
    local w=448
    local height=win.corners and 300 or math.floor(w*(win.hi-win.lo)/(win.b-win.a)+.5)
    if win.corners then
     -- (TEST178: a pane is made at its own size, 9 pixels a unit)
     local q=win.corners
     local pw=math.sqrt((q[2][1]-q[1][1])^2+(q[2][3]-q[1][3])^2);local ph=math.abs(q[4][2]-q[1][2])
     w=math.max(128,math.min(448,math.floor(pw*9+.5)))
     height=math.max(112,math.min(320,math.floor(ph*9+.5)))
    end
    local view=M.capture(c,w,height,eye,win.yaw,pitch,fov or math.rad(66),key,projection)
    c.windowCursor=i;c.windowNext=stamp+(p.generic and .25 or PACE)
    if view then
     slot=windows[key];slot.captured=stamp
     if not slot.mesh then
      local q=paneCorners(win);slot.corners=q
      slot.mesh=R.newMesh({{q[1][1],q[1][2],q[1][3],MARGIN,1-MARGIN,1},{q[2][1],q[2][2],q[2][3],1-MARGIN,1-MARGIN,1},
       {q[3][1],q[3][2],q[3][3],1-MARGIN,MARGIN,1},{q[4][1],q[4][2],q[4][3],MARGIN,MARGIN,1}},{1,2,3,1,3,4})
      slot.su,slot.sv=0,0
     end
     if win.generic and not slot.frame then
      local verts,idx={},{}
      local function bar(x0,y0,x1,y1)
       local n=#verts
       for _,pt in ipairs({{x0,y0},{x1,y0},{x1,y1},{x0,y1}})do verts[#verts+1]={win.x+pt[1],pt[2],win.z+.12,9.5/#World.colors,.5,1}end
       for _,k in ipairs({1,2,3,1,3,4})do idx[#idx+1]=n+k end
      end
      bar(win.a-1,win.lo-1,win.b+1,win.lo);bar(win.a-1,win.hi,win.b+1,win.hi+1)
      bar(win.a-1,win.lo,win.a,win.hi);bar(win.b,win.lo,win.b+1,win.hi)
      bar(-.35,win.lo,.35,win.hi)
      slot.frame=R.newMesh(verts,idx)
     end
    end
   else
    -- (no view through this pane from its fixed eye: leave it painted)
    windows[key]=windows[key]or{};windows[key].retry=stamp+REFRESH;c.windowCursor=i
   end
  end
 end
end
-- Gentle per-frame parallax: slide the captured view inside its spare border.
-- Bounded and eased, so an orbiting camera only makes the scenery drift.
local function parallax(slot,win,eye,stamp)
 if not(slot.mesh and slot.corners and slot.mesh.setVertex)then return end
 local c,right,up,inward=paneFrame(win)
 local tu,tv=0,0
 if eye then
  local rel=sub(eye,c);local depth=math.max(8,dot(rel,inward))
  tu=-MARGIN*.9*math.tanh(dot(rel,right)/depth*1.1)
  tv=MARGIN*.6*math.tanh(dot(rel,up)/depth*1.1)
 end
 local dt=math.max(0,math.min(.1,stamp-(slot.t or stamp)));slot.t=stamp
 local k=1-math.exp(-dt*4)
 slot.su=(slot.su or 0)+(tu-(slot.su or 0))*k
 slot.sv=(slot.sv or 0)+(tv-(slot.sv or 0))*k
 local u0,u1=MARGIN+slot.su,1-MARGIN+slot.su
 local v0,v1=MARGIN+slot.sv,1-MARGIN+slot.sv
 local q=slot.corners
 pcall(function()
  slot.mesh:setVertex(1,q[1][1],q[1][2],q[1][3],u0,v1,1)
  slot.mesh:setVertex(2,q[2][1],q[2][2],q[2][3],u1,v1,1)
  slot.mesh:setVertex(3,q[3][1],q[3][2],q[3][3],u1,v0,1)
  slot.mesh:setVertex(4,q[4][1],q[4][2],q[4][3],u0,v0,1)
 end)
end
function M.prepareWindows(state)
 local ok,err=pcall(prepareWindows,state)
 if not ok and cache then
  cache.error=tostring(err);cache.ready=false
  if V.mod.log then V.mod.log:info('Native scenic windows unavailable: '..tostring(err))end
 end
end
function M.drawWindows(state)
 local c=cache;if not(c and c.ready and c.map==state.map and c.profile.windows)then return end
 local visible=shellFacing(c,state.map,R.eye)
 local stamp=love.timer.getTime()
 R.glass(false);R.lighting(false)
 local ok,err=pcall(function()
  for i,win in ipairs(M.panes(state.map))do
   local slot=windows['pane'..i]
   if slot and slot.mesh and slot.canvas and(not visible or visible[win.side])then
    parallax(slot,win,R.eye,stamp)
    R.draw(slot.mesh,slot.canvas)
    if slot.frame then R.draw(slot.frame,palette())end
   end
  end
 end)
 R.lighting(true);R.glass(true)
 if not ok then error(err)end
end
local Screen={screenId='LegendaryScenicView',isOpaque=true,isFixedSpeed=true};Screen.__index=Screen
function Screen.uiSize()return 640,360 end
function Screen.new(game,state,binocular)
 if cache and cache.error then M.invalidate()end
 local p=M.profile(state.map)
 return setmetatable({game=game,state=state,binocular=binocular,yaw=0,pitch=-.18,zoom=binocular and 2 or 1,
  label=p and p.city:gsub('_',' ')or 'KANTO',fov=2*math.atan(math.tan(math.rad(64)/2)/(binocular and 2 or 1))},Screen)
end
function Screen:update(dt)
 local i=self.game.input
 if i:wasPressed('b')or i:wasPressed('start')then
  local slot=windows.observer;if slot then release(slot.canvas);windows.observer=nil end
  self.game.stack:pop();return
 end
 local function down(k)return i.isDown and i:isDown(k)or i:wasPressed(k)end
 dt=math.min(.05,math.max(0,dt or 1/60))
 self.yaw=(self.yaw+((down('right')and 1 or 0)-(down('left')and 1 or 0))*dt*.9/math.sqrt(self.zoom))%(math.pi*2)
 self.pitch=math.max(-.65,math.min(.35,self.pitch+((down('up')and 1 or 0)-(down('down')and 1 or 0))*dt*.5))
 if i:wasPressed('a')then self.zoom=self.zoom>=6 and 2 or self.zoom+2;self.fov=2*math.atan(math.tan(math.rad(64)/2)/self.zoom)end
 M.pump(self.state.map)
end
function Screen:draw()
 local g=love.graphics;local renderer=require('src.render.Renderer');local w,h=renderer:uiSize()
 local c=M.request(self.state.map);local img
 if c then local p=c.profile;img=M.capture(c,960,540,{p.x,p.height+15,p.z},self.yaw,self.pitch,self.fov,'observer')end
 g.push('all');g.setShader();g.setColor(1,1,1,1)
 g.setColor(.02,.025,.035,1);g.rectangle('fill',0,0,w,h)
 if img then g.setColor(1,1,1,1);g.draw(img,0,0,0,w/960,h/540)end
 if self.binocular then
  Overlay.draw(w,h,self,img~=nil,c and c.error~=nil)
 else
  if not font then font=g.newFont(14)end;g.setFont(font)
  g.setColor(.015,.025,.04,.85);g.rectangle('fill',0,h-32,w,32)
  g.setColor(.93,.91,.83,1)
  g.print(img and 'D-PAD: look    A: zoom    B: back' or(c and c.error and 'View unavailable. B: back'or'Preparing view... B: back'),12,h-24)
 end
 g.pop()
 local ok,fx=pcall(require,'src.render.PaletteFX');if ok and fx.markTrueColor then fx.markTrueColor(0,0,w,h)end
end
M.Screen=Screen
function M.install()
 local mod=V.mod
 if mod.events and mod.events.on then
  mod.events:on('world.block_replaced',function()M.invalidate()end)
  mod.events:on('map.reloaded',function()M.invalidate()end)
 end
 mod.hooks:wrap('ui.start_menu.items',function(next,game,items)
  local out=next(game,items);local state=game.overworld
  local p=type(out)=='table'and state and M.profile(state.map)
  -- (TEST178: a town room's windows are not a SCENIC VIEW entry)
  if p and p.menu~=false then
   out[#out+1]={label=p.binoculars and 'BINOCULARS'or 'SCENIC VIEW',onSelect=function()game.stack:push(Screen.new(game,state,p.binoculars))end}
  end
  return out
 end)
 local ok,C=pcall(require,'src.world.OverworldController')
 if ok and C.interact then local interact=C.interact
  C.interact=function(self,...)
   local game=self.game or mod.game or require('src.core.Game')
   -- Native handleInput (including FreeMove) already owns script/input gates.
   -- A ScriptRunner object may exist even while idle; its presence is not a lock.
   local p=self.player
   local npc=p and self.npcAtCell and self:npcAtCell(p.cellX,p.cellY-1)
   if enabled()and not npc and game and game.stack and game.stack:top()==self and not self.transitioning and not self.flyAnim
    and Profiles.binocularAt(self)then
    if M.profile(self.map)then game.stack:push(Screen.new(game,self,true));return true end
   end
   return interact(self,...)
  end
 end
 local okA,Assets=pcall(require,'src.render.Assets')
 if okA and Assets.register then Assets.register(function()M.invalidate();release(texture);release(font);Overlay.release();texture,font=nil,nil;failed=false end)end
end
return M
