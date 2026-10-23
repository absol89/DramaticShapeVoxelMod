-- Hold an authored closed-eye tile on the sleeping instance. A skeleton's
-- sleep selector can share the ordinary blink stream, which reopens its eyes.
-- Read only declared texture-animation alternatives; never alter pack bytes,
-- shared materials, or other instances of the same species.
local M={REVISION='parade-pokemon-sleep-eyes-262'}
local cache=setmetatable({},{__mode='k'})
local held=setmetatable({},{__mode='k'})
local legacy=setmetatable({},{__mode='k'})
local abs,min,max=math.abs,math.min,math.max
local function measure(t)
 if not(type(t)=='table'and type(t.rgba)=='string')then return end
 local w,h=tonumber(t.w),tonumber(t.h)
 if not(w and h and w>=4 and h>=4 and w<=128 and h<=128 and #t.rgba==w*h*4)then return end
 -- The border's modal color identifies the skin/transparent backdrop.
 local modes={};local best,n=nil,0
 local function edge(x,y)
  local r,g,b,a=t.rgba:byte((y*w+x)*4+1,(y*w+x)*4+4)
  local key=a<32 and 'transparent'or math.floor(r/16)..':'..math.floor(g/16)..':'..math.floor(b/16)
  local s=modes[key]or{r=0,g=0,b=0,a=0,n=0};modes[key]=s
  s.r=s.r+r;s.g=s.g+g;s.b=s.b+b;s.a=s.a+a;s.n=s.n+1
  if s.n>n then best=s;n=s.n end
 end
 for x=0,w-1 do edge(x,0);edge(x,h-1)end
 for y=1,h-2 do edge(0,y);edge(w-1,y)end
 local bg={best.r/n,best.g/n,best.b/n,best.a/n}
 local x0,y0,x1,y1,count=w,h,-1,-1,0
 for y=0,h-1 do for x=0,w-1 do
  local r,g,b,a=t.rgba:byte((y*w+x)*4+1,(y*w+x)*4+4)
  local contrast=abs(r-bg[1])+abs(g-bg[2])+abs(b-bg[3])
  if a>=128 and(bg[4]<32 or contrast>=100)then
   x0=min(x0,x);x1=max(x1,x);y0=min(y0,y);y1=max(y1,y);count=count+1
  end
 end end
 if count<3 then return end -- an empty tile is not a closed eye
 return{w=w,h=h,bg=bg,x0=x0,x1=x1,y0=y0,y1=y1,spanX=x1-x0+1,spanY=y1-y0+1,count=count}
end
local function sameBackground(a,b)
 if a.w~=b.w or a.h~=b.h then return false end
 if a.bg[4]<32 or b.bg[4]<32 then return a.bg[4]<32 and b.bg[4]<32 end
 return abs(a.bg[1]-b.bg[1])+abs(a.bg[2]-b.bg[2])+abs(a.bg[3]-b.bg[3])<55
end
-- A Pidgey-family face includes the dark cheek/eye mask: its bounding box
-- does not become a thin line when the eye shuts. Recognise the CLOSED
-- member of an authored open/half/closed/half/open blink instead. Require
-- the white of the eye to disappear; a mouth/tail/material cycle is not an
-- eye. Only inspect this primitive's own declared alternatives and streams.
local function birdBlink(model,p)
 local species=tonumber(model.species)
 if not(species and species>=16 and species<=18)then return end
 local open=model.textures and model.textures[p.tex]
 if not(open and type(open.rgba)=='string'and open.w and open.h
     and #open.rgba==open.w*open.h*4)then return end
 local function white(t,at)
  local r,g,b,a=t.rgba:byte(at,at+3)
  return a>=128 and min(r,g,b)>=160 and max(r,g,b)-min(r,g,b)<=65
 end
 local function closed(index)
  local t=model.textures[index]
  if not(t and t.w==open.w and t.h==open.h and type(t.rgba)=='string'
      and #t.rgba==#open.rgba)then return false end
  local lost,gained,changed=0,0,0
  for at=1,#open.rgba,4 do
   if open.rgba:sub(at,at+3)~=t.rgba:sub(at,at+3)then
    changed=changed+1
    if white(open,at)and not white(t,at)then lost=lost+1 end
    if white(t,at)and not white(open,at)then gained=gained+1 end
    -- Transparent/missing tiles must never count as closed eyes.
    if open.rgba:byte(at+3)>=128 and t.rgba:byte(at+3)<128 then return false end
   end
  end
  return lost>=4 and gained<=lost*.1 and changed<=open.w*open.h*.65
 end
 local best
 for _,aux in ipairs(model.auxAnims or{})do
  local stream=aux.channels and aux.channels[p.texAnim+1]
  local run={}
  for _,v in ipairs(stream or{})do
   local index=p.texMap[v]
   if index and index~=run[#run]then run[#run+1]=index end
  end
  for i=1,#run-2 do
   if run[i]==p.tex then
    local index
    if run[i+2]==p.tex then index=run[i+1]
    elseif run[i+4]==p.tex and run[i+1]==run[i+3]then index=run[i+2]end
    if index and index~=p.tex and closed(index)then
     -- Prefer the deeper, five-step blink over a half-blink.
     local depth=run[i+2]==p.tex and 1 or 2
     if not best or depth>best.depth then best={index=index,depth=depth}end
    end
   end
  end
 end
 return best and best.index
end
function M.plan(model)
 if type(model)~='table'then return{}end
 if cache[model]then return cache[model]end
 local out,stats={},{}
 local function stat(i)
  if stats[i]==nil then stats[i]=measure(model.textures and model.textures[i])or false end
  return stats[i]or nil
 end
 for _,p in ipairs(model.prims or{})do
  if type(p.texMap)=='table'and tonumber(p.texAnim)and p.texAnim>=0 then
   local candidates,seen={},{}
   for _,i in pairs(p.texMap)do
    if type(i)=='number'and not seen[i]then
     seen[i]=true;local s=stat(i);if s then candidates[#candidates+1]={i=i,s=s}end
    end
   end
   local open
   for _,c in ipairs(candidates)do if not open or c.s.spanY>open.s.spanY then open=c end end
   if open and open.s.spanY>=6 and open.s.spanX>=4 then
    local best
    for _,c in ipairs(candidates)do
     local a,b=c.s,open.s
     -- A closed eye is a narrow lid spanning the same eye, not a missing
     -- tile, a tiny highlight, a differently-sized atlas or a round pupil.
     if c.i~=open.i and sameBackground(a,b)and a.spanY<=b.spanY*.55
       and a.spanX>=b.spanX*.65 and a.spanX<=b.spanX*1.4
       and a.spanX>=a.spanY*1.5 and a.count<b.count*.75
       and abs((a.x0+a.x1)-(b.x0+b.x1))<=b.spanX*.6 then
      if not best or a.spanY<best.s.spanY or(a.spanY==best.s.spanY and c.i<best.i)then best=c end
     end
    end
    if best then out[p]=best.i end
   end
   out[p]=birdBlink(model,p)or out[p]
  end
 end
 cache[model]=out;return out
end
function M.hold(inst)
 if held[inst]then return held[inst].count end
 local ok,model=pcall(function()return inst:model()end)
 local good,renderer=pcall(function()return inst:renderer()end)
 if not(ok and good and type(model)=='table'and type(renderer)=='table'and type(renderer.currentTexture)=='function')then return end
 local planned,plan=pcall(M.plan,model);if not planned or next(plan)==nil then return end
 local count=0;for _ in pairs(plan)do count=count+1 end
 local r={renderer=renderer,original=renderer.currentTexture,own=rawget(renderer,'currentTexture'),count=count}
 r.wrapper=function(self,prim,...)
  if self==renderer and held[inst]==r and plan[prim]then return plan[prim]end
  return r.original(self,prim,...)
 end
 held[inst]=r;renderer.currentTexture=r.wrapper
 return count
end
-- Stadium 1 resolves textures into each rig's parts, without currentTexture.
-- Own the small decoded lid images here; never write shared model materials.
function M.holdLegacy(rig,aux)
 if legacy[rig]then return legacy[rig].count end
 if not(type(rig)=='table'and type(rig.textures)=='function'and type(rig.model)=='table')then return end
 local ok,plan=pcall(M.plan,rig.model);if not ok or not next(plan)then return end
 local r={original=rig.textures,own=rawget(rig,'textures'),images={},count=0,aux=aux}
 for prim,index in pairs(plan)do
  if r.images[index]==nil then
   local slot=rig.model.textures[index]
   local good,img=pcall(function()
    local data=love.image.newImageData(slot.w,slot.h,'rgba8',slot.rgba)
    local made,image=pcall(love.graphics.newImage,data)
    if data.release then data:release()end
    if not made then error(image)end
    image:setFilter('nearest','nearest');return image
   end)
   r.images[index]=good and img or false
  end
 end
 for _,part in ipairs(rig.parts or{})do if r.images[plan[part.prim]]then r.count=r.count+1 end end
 if r.count==0 then
  for _,img in pairs(r.images)do if img and img.release then img:release()end end
  return
 end
 r.wrapper=function(self,value,...)
  local result=r.original(self,value,...)
  if self==rig and legacy[rig]==r then
   r.aux=value
   for _,part in ipairs(self.parts or{})do
    local img=r.images[plan[part.prim]]
    if img then part.texture=img end
   end
  end
  return result
 end
 legacy[rig]=r;rig.textures=r.wrapper
 local applied=pcall(r.wrapper,rig,aux)
 if not applied then M.releaseLegacy(rig);return end
 return r.count
end
function M.releaseLegacy(rig)
 local r=legacy[rig];if not r then return end
 if rig.textures==r.wrapper then rig.textures=r.own end
 legacy[rig]=nil
 -- Rebind ordinary textures before releasing the parade-owned images.
 pcall(r.original,rig,r.aux)
 for _,part in ipairs(rig.parts or{})do
  for _,img in pairs(r.images)do if img and part.texture==img then part.texture=nil end end
 end
 for _,img in pairs(r.images)do if img and img.release then pcall(img.release,img)end end
end
function M.release(inst)
 local r=held[inst];if not r then return end
 if r.renderer.currentTexture==r.wrapper then r.renderer.currentTexture=r.own end
 held[inst]=nil
end
function M.clear()
 for inst in pairs(held)do M.release(inst)end
 for rig in pairs(legacy)do M.releaseLegacy(rig)end
 cache=setmetatable({},{__mode='k'})
end
return M
