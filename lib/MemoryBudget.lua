-- TEST217.1: voxel RAM budget, collector tuning and graphics-pressure assist.
-- Budget logic is preserved from the delivered TEST213/216 merge. Recent
-- records are protected for 30 seconds, so this is a soft budget. Graphics
-- pressure is estimated, not a measurement of total process memory. These
-- changes target memory pressure; the native crash cause is not established.
-- Installed from LeagueFireworksAudio without modifying main.lua.
local V=...
local M={REVISION='memory-budget-217-merge1'}
local MB=1048576

M.PHONE_CAP=768*MB        -- the most the mirror holds on a phone
M.PHONE_LIVE_CAP=384*MB   -- OFF / LIVE CACHE: generated records only
M.DESK_LIVE_CAP=768*MB
M.PROTECT=30              -- seconds a used record is always kept
M.EVERY=2                 -- seconds between budget checks
M.GC_PHONE={pause=120,stepmul=400}
M.GC_DESK={pause=150,stepmul=300}

M.freedBytes,M.freedFiles=0,0
local mobileCached=nil
local function mobile()
 if mobileCached==nil then
  local os_;pcall(function()os_=love.system.getOS()end)
  if not os_ then pcall(function()os_=love._os end)end
  mobileCached=os_=='Android'or os_=='iOS'
 end
 return mobileCached
end
M.mobile=mobile

-- the cap in bytes, or nil for none
function M.cap()
 local ok,R=pcall(V.require,'RamPrecache')
 if not(ok and R and R.bytes)then return nil end
 local okB,b=pcall(R.bytes)
 if not okB then return nil end
 if b==nil then return mobile()and M.PHONE_CAP or nil end            -- FULL
 if b==0 then return mobile()and M.PHONE_LIVE_CAP or M.DESK_LIVE_CAP end -- OFF / LIVE CACHE
 if mobile()then return math.min(b,M.PHONE_CAP)end
 return b
end

local gcSet=nil
local priorGc={}
local function tuneGc()
 local g=mobile()and M.GC_PHONE or M.GC_DESK
 local applied={}
 for _,key in ipairs({'pause','stepmul'})do
  local ok,old=pcall(collectgarbage,'set'..key,g[key])
  if ok then
   if priorGc[key]==nil and type(old)=='number'then priorGc[key]=old end
   applied[key]=g[key]
  end
 end
 gcSet=applied
end
function M.gc()return gcSet end

-- TEST217: retain the former recorder's graphics-pressure collector assist,
-- without tracking objects, saving logs or drawing panels. Byte counts and
-- heap-drop resets are estimates. A GC step can still cause a frame hitch.
M.ASSIST_AT=96*MB
M.assistCycles=0
local G=love.graphics
local active,generation=false,0
local orig,wrappers={},{}
local sinceCycle,peakCount,gcDenied=0,0,false
local function meshBytes(m)
 local n=m:getVertexCount()or 0
 local per=0
 for _,f in ipairs(m:getVertexFormat()or{})do
  local dt=tostring(f[2]or'float')
  per=per+(f[3]or 1)*((dt=='byte'or dt:find('8'))and 1 or(dt:find('16')and 2 or 4))
 end
 return n*(per>0 and per or 24)
end
local function texBytes(t)
 local w,h=t:getPixelDimensions()
 local mip,layers=1,1
 pcall(function()if(t:getMipmapCount()or 1)>1 then mip=4/3 end end)
 pcall(function()layers=t:getLayerCount()or 1 end)
 return(w or 0)*(h or 0)*4*mip*math.max(1,layers)
end
local function wrapCtor(name,sizer)
 local f=G[name]
 if type(f)~='function'or orig[name]then return end
 local installedGeneration=generation
 local wrapper=function(...)
  local o=f(...)
  if active and generation==installedGeneration and o~=nil then
   local ok,b=pcall(sizer,o)
   if ok and type(b)=='number'and b>0 then sinceCycle=sinceCycle+b end
  end
  return o
 end
 local ok=pcall(function()G[name]=wrapper end)
 if ok and G[name]==wrapper then orig[name]=f;wrappers[name]=wrapper end
end
local function gcAssist()
 if gcDenied then return end
 local c=collectgarbage('count')
 -- A >12% heap drop is only a reset heuristic, not proof of a full cycle.
 if c<peakCount*.88 then sinceCycle=0;peakCount=c end
 if c>peakCount then peakCount=c end
 if sinceCycle>=M.ASSIST_AT then
  for _=1,2 do
   local ok,done=pcall(collectgarbage,'step',1024)
   if not ok then gcDenied=true;break end
   if done then
    M.assistCycles=M.assistCycles+1;sinceCycle=0;peakCount=collectgarbage('count')
    break
   end
  end
 end
end

local last,lastGc=-1e9,-1e9
local function now()local ok,t=pcall(love.timer.getTime);return ok and t or 0 end
function M.update()
 if not active then return end
 local t=now()
 pcall(gcAssist)
 -- re-asserted now and then: an import or another mod may set its own
 if t-lastGc>=10 then lastGc=t;tuneGc()end
 if t-last<M.EVERY then return end
 last=t
 local ok,Disk=pcall(V.require,'VoxelMeshDisk')
 if not(ok and Disk and Disk.enforceRamBudget)then return end
 local cap=M.cap()
 if not cap then return end
 local okE,freed,files=pcall(Disk.enforceRamBudget,cap,M.PROTECT)
 if okE and(files or 0)>0 then
  M.freedBytes=M.freedBytes+freed;M.freedFiles=M.freedFiles+files
 end
end

local remove
function M.install(mod)
 if active or not(mod and mod.hooks and mod.hooks.wrap)then return end
 generation=generation+1;local installedGeneration=generation
 local ok,rem=pcall(mod.hooks.wrap,mod.hooks,'core.update',function(nxt,game,dt)
  if active and generation==installedGeneration then pcall(M.update)end
  return nxt(game,dt)
 end)
 if not ok then return end
 if type(rem)=='function'then remove=rem end
 active=true
 tuneGc()
 wrapCtor('newMesh',meshBytes)
 wrapCtor('newImage',texBytes)
 wrapCtor('newCanvas',texBytes)
 wrapCtor('newArrayImage',texBytes)
end
function M.dispose()
 active=false
 if remove then pcall(remove);remove=nil end
 for name,f in pairs(orig)do
  if G[name]==wrappers[name]then pcall(function()G[name]=f end)end
 end
 orig={};wrappers={}
 sinceCycle,peakCount,gcDenied=0,0,false
 M.assistCycles=0
 -- Restore the actual engine settings, not assumed Lua defaults.
 for _,key in ipairs({'pause','stepmul'})do
  if priorGc[key]~=nil then pcall(collectgarbage,'set'..key,priorGc[key])end
 end
 priorGc={};gcSet=nil
 last,lastGc=-1e9,-1e9
end
return M
