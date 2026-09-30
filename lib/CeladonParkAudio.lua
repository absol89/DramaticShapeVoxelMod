-- Approved recorded cricket bed, active near the visible Celadon park at night.
local V=...
local M={}
local source,failed,beat,target,volume,remove=nil,false,-1e9,0,0,nil
local function free(s)
 if s then pcall(s.stop,s);pcall(s.release,s)end
end
function M.clear()
 free(source);source=nil;beat=-1e9;target=0;volume=0;failed=false
end
function M.dispose()
 if remove then pcall(remove);remove=nil end
 M.clear()
end
function M.touch(P,px,pz,night)
 beat=love.timer.getTime();target=0
 if not night then return end
 for _,bed in ipairs(P and P.beds or {})do
  local dx=math.max(bed.x0*8-px,0,px-(bed.x1+1)*8)
  local dz=math.max(bed.z0*8-pz,0,pz-(bed.z1+1)*8)
  target=math.max(target,math.max(0,1-math.sqrt(dx*dx+dz*dz)/90)*.18)
 end
end
local function loadSource()
 if source or failed then return source end
 if not (love and love.audio and love.filesystem)then failed=true;return end
 local data,made
 local ok=pcall(function()
  local bytes=assert(V.mod:read('assets/legendary/viridian-crickets.wav'))
  data=love.filesystem.newFileData(bytes,'viridian-crickets.wav')
  made=love.audio.newSource(data,'static')
  made:setLooping(true);made:setVolume(0)
 end)
 if data and data.release then pcall(data.release,data)end
 if not ok then free(made);failed=true;return end
 source=made;return source
end
function M.update(game,dt)
 local want=target
 local map=game and game.overworld and game.overworld.map
 if not map or map.id~='CELADON_CITY' or love.timer.getTime()-beat>.25 then want=0 end
 local opts=game and game.save and game.save.options
 want=want*math.max(0,math.min(7,tonumber(opts and opts.sfxVol) or 7))/7
 local pub=rawget(_G,'__ds_ceiling_config')
 if type(pub)=='function' then
  local ok,cfg=pcall(pub)
  if ok and type(cfg)=='table' then
   if cfg.ambience==false or cfg.ambience=='OFF' then want=0
   elseif cfg.ambience=='LOW' then want=want*.55 end
  end
 end
 -- Avoid doubling an existing companion's cricket ambience.
 local ambient=rawget(_G,'__ds_amb_state')
 local other=ambient and ambient.srcs and ambient.srcs.night
 if other then
  local ok,playing=pcall(other.isPlaying,other)
  if ok and playing then want=0 end
 end
 local delta=math.max(0,math.min(.1,tonumber(dt) or 0))
 volume=volume+math.max(-delta*.35,math.min(delta*.15,want-volume))
 if volume>.001 and not source then loadSource()end
 if source then
  source:setVolume(volume)
  if volume>.001 then if not source:isPlaying()then source:play()end
  elseif source:isPlaying()then source:stop()end
 end
end
function M.install(mod)
 if remove then return end
 remove=mod.hooks:wrap('core.update',function(next,game,dt)
  -- Update before forwarding; preserve every return value of the engine hook.
  local ok=pcall(M.update,game,dt)
  if not ok then M.clear();failed=true end
  return next(game,dt)
 end)
end
return M
