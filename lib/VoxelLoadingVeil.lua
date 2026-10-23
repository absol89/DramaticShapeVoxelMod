-- Bounded loading presentation. Reuses one display-sized canvas, never a
-- supersampled target; no scene generation, input handling or loading gates.
local V=...
local PixelCanvas=V.require('PixelCanvas')
local Cards=V.require('LegendaryLoading')
local Veil={}
local target,waitingMap,started
local clock,idle=0,0
local lastPaint=-1
local lastKey
local shownId,shownAt
local function releaseTarget()
 if target and target.canvas and target.canvas.release then pcall(target.canvas.release,target.canvas)end
 target=nil;lastKey=nil;lastPaint=-1;shownId,shownAt=nil,nil
end
function Veil.update(dt)
 dt=math.max(0,tonumber(dt)or 0);clock=clock+dt;idle=idle+dt
 if idle>2 and target then releaseTarget();Cards.invalidate()end
end
function Veil.observe(map,waiting)
 if not waiting then waitingMap,started=nil,nil
 elseif waitingMap~=map then waitingMap,started=map,clock end
end
local function ensure(w,h)
 if not(love and love.graphics and w and h and w>0 and h>0)then return nil end
 idle=0
 if not(target and target.w==w and target.h==h)then
  releaseTarget()
  local ok,c=PixelCanvas.new(w,h);if not(ok and c)then return nil end
  pcall(c.setFilter,c,'linear','linear')
  target={canvas=c,w=w,h=h}
 end
 return target.canvas
end
local function infoFor(map,status)
 local info=Cards.describe(status and status.targetId or map)
 info.ready=status and status.ready or false
 -- TEST142: how long this destination's card has been up (title intro,
 -- journey track). Resets when the destination changes.
 if shownId~=info.id then shownId,shownAt=info.id,clock end
 info.elapsed=clock-(shownAt or clock)
 local ok,holiday=pcall(function()return V.require('SeasonalDecor').Settings.get('holiday')end)
 info.season=ok and holiday or 'off'
 return info
end
local function paint(canvas,w,h,info,background)
 local g=love.graphics;local previous=g.getCanvas()
 local pushed=false
 local ok,err=pcall(function()
  g.push('all');pushed=true
  g.setCanvas(canvas);g.origin();g.setShader();g.setScissor();g.setDepthMode()
  g.setBlendMode('alpha');g.clear(.022,.038,.05,1)
  if background then
   local bw,bh=background:getDimensions()
   g.setColor(1,1,1,1);g.draw(background,0,0,0,w/bw,h/bh)
  end
  Cards.paint(g,w,h,info,clock,background~=nil)
 end)
 if pushed then pcall(g.pop)end
 pcall(g.setCanvas,previous)
 if not ok and not Veil.warned and V.mod and V.mod.log then
  Veil.warned=true;pcall(V.mod.log.error,V.mod.log,'Legendary loading card: %s',tostring(err))
 end
 return ok
end
function Veil.get(w,h,map,status)
 local canvas=ensure(w,h);if not canvas then return nil end
 local info=infoFor(map,status)
 local key=info.id..':'..tostring(info.ready)..':'..tostring(info.season)
 -- TEST142: fifteen updates per second keep the slow parallax smooth while
 -- leaving almost all frame time to the area build behind the card.
 if lastKey~=key or clock-lastPaint>=1/15 then
  if not paint(canvas,w,h,info)then
   local g=love.graphics;local prev=g.getCanvas()
   pcall(function()g.setCanvas(canvas);g.clear(0,0,0,1)end)
   pcall(g.setCanvas,prev)
  end
  lastKey=key;lastPaint=clock
 end
 return canvas
end
function Veil.decorate(background,w,h,map)
 -- Fast cached seams never flash a card. Ordinary streaming never acquires
 -- a modal gate: this is only a caption over the host's held frame.
 if not background or waitingMap~=map or not started or clock-started<.3 then return background end
 local canvas=ensure(w,h);if not canvas or canvas==background then return background end
 lastKey=nil
 local info=Cards.describe(map)
 return paint(canvas,w,h,info,background)and canvas or background
end
function Veil.invalidate()
 releaseTarget();if Cards.release then Cards.release()else Cards.invalidate()end;waitingMap,started=nil,nil;idle=0;shownId,shownAt=nil,nil
end
return Veil
