-- Original forest sound bed plus natural recorded cricket ambience.
local V=...
local M={};local remove,beat,night=nil,-1e9,0
local tracks={{path='assets/legendary/viridian-forest.wav',volume=0},{path='assets/legendary/viridian-crickets.wav',volume=0}}
local function free(t)
 if t.source then pcall(t.source.stop,t.source);pcall(t.source.release,t.source)end
 t.source=nil;t.volume=0
end
function M.dispose()
 if remove then pcall(remove);remove=nil end
 for _,t in ipairs(tracks)do free(t);t.failed=false end
 beat=-1e9
end
function M.touch(level)
 beat=love.timer.getTime();night=math.max(0,math.min(1,level or 0))
end
local function load(t)
 if t.source or t.failed then return end
 local data,s
 local ok=pcall(function()
  data=love.filesystem.newFileData(assert(V.mod:read(t.path)),t.path)
  s=love.audio.newSource(data,'static');s:setLooping(true);s:setVolume(0)
 end)
 if data and data.release then pcall(data.release,data)end
 if ok then t.source=s else
  if s then pcall(s.release,s)end
  t.failed=true
 end
end
function M.update(game,dt)
 local map=game and game.overworld and game.overworld.map
 local active=map and map.id=='VIRIDIAN_FOREST' and love.timer.getTime()-beat<.3
 local opts=game and game.save and game.save.options
 local gain=active and math.max(0,math.min(7,tonumber(opts and opts.sfxVol)or 7))/7 or 0
 local pub=rawget(_G,'__ds_ceiling_config')
 if type(pub)=='function'then
  local ok,cfg=pcall(pub)
  if ok and type(cfg)=='table'then
   if cfg.ambience==false or cfg.ambience=='OFF'then gain=0
   elseif cfg.ambience=='LOW'then gain=gain*.55 end
  end
 end
 local duplicate=false
 local ambient=rawget(_G,'__ds_amb_state')
 local other=ambient and ambient.srcs and ambient.srcs.night
 if other then local ok,on=pcall(other.isPlaying,other);duplicate=ok and on end
 local delta=math.max(0,math.min(.1,tonumber(dt)or 0))
 for i,t in ipairs(tracks)do
  local want=gain*(i==1 and .22 or (duplicate and 0 or .24*night))
  t.volume=t.volume+math.max(-delta*.5,math.min(delta*.12,want-t.volume))
  if t.volume>.001 then load(t)end
  if t.source then
   t.source:setVolume(t.volume)
   if t.volume>.001 then if not t.source:isPlaying()then t.source:play()end
   elseif t.source:isPlaying()then t.source:stop()end
  end
 end
end
function M.install(mod)
 if remove then return end
 remove=mod.hooks:wrap('core.update',function(next,game,dt)
  local ok=pcall(M.update,game,dt)
  if not ok then for _,t in ipairs(tracks)do free(t);t.failed=true end end
  return next(game,dt)
 end)
end
return M
