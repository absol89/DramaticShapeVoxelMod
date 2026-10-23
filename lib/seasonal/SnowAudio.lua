-- Original bundled crunch samples; a fixed six-source pool, never a sound loop.
local mod,Snow=...
local M={};M.__index=M
function M.new()return setmetatable({sources={},played=0,travel=0,lastStep=-10},M)end
function M:reset()
 self.previous=nil;self.travel=0;self.lastStep=-10
 for _,s in ipairs(self.sources)do pcall(s.stop,s)end
end
function M:dispose()
 self:reset()
 for _,s in ipairs(self.sources)do if s.release then pcall(s.release,s)end end
 self.sources={};self.failed=nil
end
function M:prepare()
 if #self.sources>0 or self.failed then return end
 local ok,err=pcall(function()
  assert(love.audio and love.audio.newSource and mod.assets and mod.assets.path,'snow audio API unavailable')
  for i=1,6 do
   local s=love.audio.newSource(mod.assets:path('assets/audio/snow-'..i..'.wav'),'static')
   self.sources[#self.sources+1]=s;s:setLooping(false);s:setVolume(0)
  end
 end)
 if not ok then self:dispose();self.failed=tostring(err)end
end
function M:update(game,player,surface,time,dt,mode,enabled)
 local save=game and game.save;local options=save and save.options
 -- Same 0..7 SFX setting used by the engine's Sound.setVolumeLevel.
 local volume=math.max(0,math.min(7,tonumber(options and options.sfxVol)or 7))/7
 if not enabled or mode=='off' then
  if #self.sources>0 or self.previous or self.failed then self:dispose()end
  return
 end
 self:prepare()
 local airborne=player and (player.ledgeHop or (player.hopFrames or 0)>0 or player.spinning or player.flying or math.abs(player.lift or 0)>.5)
 local walking=player and not (player.surfing or player.biking or save and save.onBike or airborne)
 if not walking or not surface or volume==0 or self.failed then
  if self.previous then self:reset()end
  return
 end
 local x,z=(player.px or player.x or 0)+8,(player.py or player.y or 0)+8
 local prev=self.previous;self.previous={x=x,z=z}
 if not prev then return end
 local dx,dz=x-prev.x,z-prev.z;local distance=math.sqrt(dx*dx+dz*dz)
 local height=Snow.height(surface,x,z)
 if not height or math.abs(height-(player.gh or 0))>=1.8 or distance>24 or distance/math.max(.001,dt)>110 then
  self.travel=0;self.lastStep=time;return
 end
 if distance<.001 then
  if time-self.lastStep>.4 then self.travel=0 end
  return
 end
 self.travel=self.travel+distance
 local stride=time-self.lastStep>.4 and 6 or 14
 if self.travel<stride or time-self.lastStep<.26 then return end
 self.travel=self.travel%14;self.lastStep=time;self.played=self.played+1
 -- Deterministic shuffled order avoids the same sample on adjacent steps.
 local order={1,4,2,6,3,5};local index=order[(self.played-1)%6+1]
 local s=self.sources[index]
 local variation=((self.played*17)%11)/10
 s:stop();s:setPitch(.965+.07*variation)
 s:setVolume(volume*(mode=='soft'and .40 or .24)*(.92+.08*variation));s:play()
end
return M
