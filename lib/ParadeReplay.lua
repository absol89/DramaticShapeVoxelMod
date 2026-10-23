-- TEST258: one-shot menu action. No Hall of Fame, rewards or credits.
-- A selection belongs to the current save AND overworld, never to a future
-- load. The persisted choice is OFF again before the first parade frame.
local V=...
local M={}
M.setting=V.require('ModSetting').new('replayParade','REPLAY PARADE',
 {'off','ride','celadon','pallet'},
 {'OFF','RIDE','CELADON ONLY','PALLET ENDING'})
local armed,session
local removers={}
local installed=false
local setIndex=M.setting.setIndex
local sync=M.setting.sync
local function gameNow()local ok,g=pcall(require,'src.core.Game');return ok and g or nil end
local function cp()return V.require('ChampionParade')end
local function log(s)
 if V.mod and V.mod.log then pcall(V.mod.log.info,V.mod.log,'[ParadeReplay] '..tostring(s))end
end
local function copy(t)local c={};for k,v in pairs(t or{})do c[k]=v end;return c end
local function restore(t,c)
 for k in pairs(t)do if c[k]==nil then t[k]=nil end end
 for k,v in pairs(c)do t[k]=v end
end
local function present(game,ow)
 if not(game and ow and game.overworld==ow and game.stack and game.stack.top)then return false end
 if game.stack:top()==ow then return true end
 for _,s in ipairs(game.stack.states or{})do if s==ow then return true end end
 return false
end
local function off(game)armed=nil;setIndex(M.setting,1,game)end
local function arm(value,game)
 armed=nil
 if value=='off'then return end
 local ow=game and game.overworld
 local P=cp()
 if not(game and game.save and present(game,ow))or P.pending or P.active()then
  off(game);return
 end
 armed={game=game,save=game.save,ow=ow,value=value}
end
function M.setting:setIndex(i,game)
 local value=setIndex(self,i,game)
 arm(value,game)
 return value
end
function M.setting:sync(value)
 -- TEST264: an old manager/saved WALK selection now means the full ride.
 -- install/save-loaded still discard stale actions rather than auto-replay.
 sync(self,value=='walk'and'ride'or value)
 arm(self:get(),gameNow())
end
function M.pending()return armed~=nil end
function M.active()return session~=nil end

-- A runner exists even when idle. Wait for the menu to leave and for the
-- actual script/movement/transition to finish, not for runner==nil.
function M.ready(game)
 local ow=game and game.overworld
 if not(game and game.save and ow and ow.map and ow.player and game.stack
  and game.stack:top()==ow)then return false end
 local p=ow.player
 if p.moving or p.inputLocked or ow.transitioning or ow._modScriptLock
  or #(ow.scriptMoves or{})>0 or #(ow.pendingScripts or{})>0 then return false end
 if ow.runner and ow.runner.isRunning and ow.runner:isRunning()then return false end
 for _,key in ipairs({'engaging','emote','teleportOut','flyAnim','flyArrive',
  'spinArrive','holeFall','holeArrive','cutAnim','healAnim','pikaHop','fishPose',
  'spinnerSliding','shipAnim','pendingEnterMapTail','cameraPan'})do
  if ow[key]then return false end
 end
 if (ow.hopLand or 0)>0 or(ow.dustAnim and ow.dustAnim.boulder)then return false end
 return true
end

-- These are the save fields setMap changes even for checkpoint warps.
-- Arrival scripts/events and forced movement are disabled on replay warps;
-- _modScriptLock keeps free input, trainer sight and step events out while
-- the real scripted walking/follower updates continue normally.
local SAVE_FIELDS={'onBike','forcedBike','safari','flashLit','poisonSteps'}
local OW_FIELDS={'strengthActive','warpEntryCell','wildEncounterGraceSteps',
 'standingOnWarp','cutBlocks'}
local function remember(game)
 local ow,p=game.overworld,game.overworld.player
 local s={game=game,save=game.save,ow=ow,map=ow.map.id,x=p.cellX,y=p.cellY,
  facing=p.facing,player=p,playerBefore=copy(p),owBefore=copy(ow),fields={},owFields={},
  visited=game.save.visited,visitedBefore=copy(game.save.visited)}
 for _,k in ipairs(SAVE_FIELDS)do s.fields[k]=game.save[k]end
 for _,k in ipairs(OW_FIELDS)do s.owFields[k]=ow[k]end
 return s
end
local function restoreSave(s)
 for _,k in ipairs(SAVE_FIELDS)do s.save[k]=s.fields[k]end
 if type(s.visited)=='table'then restore(s.visited,s.visitedBefore)end
 s.save.visited=s.visited
end
local function sameWorld(s)
 return s.game.save==s.save and present(s.game,s.ow)
end
local function releaseLock(s)
 if s.ow._modScriptLock==s.lock then s.ow._modScriptLock=nil end
end
local function returnHome(s)
 if session~=s then return end
 session=nil
 -- A reset/load owns its new state. Never warp an old character into it.
 if not sameWorld(s)then releaseLock(s);return end
 local ow,p=s.ow,s.player
 -- Retire callbacks before setMap. Otherwise a skipped walk can enqueue
 -- its next leg on the origin map in the same engine update.
 ow.scriptMoves={}
 p.moving=false;p.targetX=nil;p.targetY=nil;p.progress=0
 restoreSave(s)
 p.surfing=s.playerBefore.surfing;p.onBike=s.playerBefore.onBike
 local ok,err=pcall(ow.setMap,ow,s.map,s.x,s.y,s.facing,
  {via='warp',checkpoint=true,keepMusic=true,pikachuSpawn=2})
 if not ok then
  -- The origin was already loaded and is kept alive by owBefore. A failed
  -- reload must not strand the player in a partially loaded parade map.
  restore(ow,s.owBefore)
  log('Origin reload failed; restored the retained overworld: '..tostring(err))
 end
 restoreSave(s)
 restore(p,s.playerBefore)
 ow.player=p
 ow.scriptMoves={}
 for _,k in ipairs(OW_FIELDS)do ow[k]=s.owFields[k]end
 releaseLock(s)
 -- setMap follows the camera and rebuilds the follower for the saved surf
 -- state. The retained-state fallback needs its camera snapped explicitly.
 pcall(function()ow.camera:follow(p.px,p.py,s.game.renderer:worldViewSize())end)
 pcall(function()
  local Music=require('src.core.Music')
  Music.stop()
  Music.playMap(s.game.data,s.map,s.save.onBike,p.surfing,Music.MAP_FADE)
 end)
 log('Returned to '..s.map)
end

function M.update(game)
 if session then
  local s=session
  if not sameWorld(s)then
   session=nil;releaseLock(s)
   local running=cp()._parade()
   if running and running.game==s.game then pcall(running.abort,running)end
  elseif not cp().active()then returnHome(s)end -- abort/failed start fallback
  return
 end
 local a=armed
 if not a then return end
 if game~=a.game or game.save~=a.save or not present(game,a.ow)then off(game);return end
 local P=cp()
 if P.pending or P.active()then off(game);return end
 if not M.ready(game)then return end
 local only=a.value=='celadon'and'CELADON_CITY'or a.value=='pallet'and'PALLET_TOWN'or nil
 off(game)
 if not P.canRun(game,only)then log('Replay needs the 3D overworld and parade maps');return end
 local s=remember(game);session=s
 s.lock={isRunning=function()return true end}
 s.ow._modScriptLock=s.lock
 -- Keep cut terrain intact across the temporary map visits, and restore
 -- bike/surf state only when home. Parade motion itself is always on foot.
 s.ow.cutBlocks={}
 s.save.onBike=false;s.save.forcedBike=nil
 s.player.onBike=false;s.player.surfing=false
 local ok,started=pcall(P.play,game,function()returnHome(s)end,
  {replay=true,ride=true,only=only})
 if not ok or not started then
  local running=P._parade()
  if running and running.replay then pcall(running.finish,running)end
  returnHome(s)
  log('Replay could not start: '..tostring(started))
 end
end

function M.install(mod)
 if installed then return end
 installed=true
 off(gameNow())
 removers[#removers+1]=mod.hooks:wrap('core.update',function(next,game,dt)
  M.update(game)
  return next(game,dt)
 end)
 for _,event in ipairs({'save.loaded','save.created'})do
  removers[#removers+1]=mod.events:on(event,function()off(gameNow())end)
 end
end
function M.dispose()
 armed=nil
 if session then
  local s=session;local running=cp()._parade()
  if running and running.replay then pcall(running.finish,running)end
  returnHome(s)
 end
 for _,remove in ipairs(removers)do if type(remove)=='function'then pcall(remove)end end
 removers={};installed=false
end
return M
