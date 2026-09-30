-- Recorded regional ambience. SFX/ambience controls and existing owners win.
local V=...;local M={};local remove,beat,mapId,wants=nil,-1e9,nil,{}
local tracks={
 cricket={path='assets/legendary/viridian-crickets.wav',volume=0},
 woodland={path='assets/legendary/viridian-forest.wav',volume=0},
 water={path='assets/legendary/kanto-river.wav',volume=0},
 coast={path='assets/legendary/kanto-coast.wav',volume=0},
}
local function free(t)if t.source then pcall(t.source.stop,t.source);pcall(t.source.release,t.source)end;t.source=nil;t.volume=0 end
function M.dispose()
 if remove then pcall(remove);remove=nil end
 for _,t in pairs(tracks)do free(t);t.failed=false end
 beat,mapId,wants=-1e9,nil,{}
end
function M.touch(id,p,h,night,rain,level)
 beat=love.timer.getTime();mapId=id;local soft=level=='low'and .65 or 1
 local green=h.greenLevel*p.insects;local wet=rain and .45 or 1
 wants={cricket=p.legacy and 0 or .19*green*night*wet,
  woodland=p.legacy and 0 or (p.kind=='woodland'or p.kind=='wetland'or p.kind=='garden')and .10*green*(1-night*.7)*wet or 0,
  water=p.kind~='coast'and .15*h.water or 0,
  coast=p.kind=='coast'and .20*h.water or 0}
 for k,v in pairs(wants)do wants[k]=v*soft end
end
local function load(t)
 if t.source or t.failed then return end
 local data,source
 local ok=pcall(function()
  data=love.filesystem.newFileData(assert(V.mod:read(t.path)),t.path)
  source=love.audio.newSource(data,'static');source:setLooping(true);source:setVolume(0)
 end)
 if data and data.release then pcall(data.release,data)end
 if ok then t.source=source else if source then pcall(source.release,source)end;t.failed=true end
end
function M.update(game,dt)
 local map=game and game.overworld and game.overworld.map
 local active=map and map.id==mapId and love.timer.getTime()-beat<.3
 local opts=game and game.save and game.save.options
 local gain=active and math.max(0,math.min(7,tonumber(opts and opts.sfxVol)or 7))/7 or 0
 local pub=rawget(_G,'__ds_ceiling_config');if type(pub)=='function'then local ok,c=pcall(pub)
  if ok and type(c)=='table'then if c.ambience==false or c.ambience=='OFF'then gain=0 elseif c.ambience=='LOW'then gain=gain*.55 end end
 end
 local ambient=rawget(_G,'__ds_amb_state');local srcs=ambient and ambient.srcs or{}
 local delta=math.max(0,math.min(.1,tonumber(dt)or 0))
 for k,t in pairs(tracks)do
  local want=gain*(wants[k]or 0)
  local other=srcs[k=='cricket'and 'night'or k=='coast'and 'sea'or k=='water'and 'water'or'forest']
  if other then local ok,on=pcall(other.isPlaying,other);if ok and on then want=0 end end
  -- Mute controls are immediate; map/time transitions fade smoothly.
  if opts and tonumber(opts.sfxVol)==0 then t.volume=0 else t.volume=t.volume+math.max(-delta*.35,math.min(delta*.10,want-t.volume))end
  if t.volume>.001 then load(t);t.idle=0 else t.idle=(t.idle or 0)+delta end
  if t.source then
   t.source:setVolume(t.volume)
   if t.volume>.001 then if not t.source:isPlaying()then t.source:play()end
   elseif t.source:isPlaying()then t.source:stop()end
   if t.idle>8 then free(t)end
  end
 end
end
function M.install(mod)
 if remove then return end
 remove=mod.hooks:wrap('core.update',function(next,game,dt)
  local ok=pcall(M.update,game,dt)
  if not ok then for _,t in pairs(tracks)do free(t);t.failed=true end end
  return next(game,dt)
 end)
end
return M
