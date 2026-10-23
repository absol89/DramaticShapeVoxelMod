-- TEST217.1: self-contained mobile texture reduction; no diagnostic panels.
-- Character bridge/non-Battle-Art hook context selects square >=2048px images.
-- Context is a selection heuristic, not proof of asset ownership.
-- Each eligible uncompressed color image is halved once; normalized UVs stay.
-- Original+temporary resources coexist briefly. Native crash prevention and
-- visual fidelity on the user's device remain unverified.
local V=...
local M={REVISION='texture-diet-217-merge1',shrunk=0,saved=0,failed=0}
local G=love.graphics
local orig,wrapper=nil,nil
local active,busy=false,false
local generation=0
local mobileCached

local function release(o)if o and o.release then pcall(o.release,o)end end
local function mobile()
 if mobileCached==nil then
  local os_;pcall(function()os_=love.system.getOS()end)
  if not os_ then pcall(function()os_=love._os end)end
  mobileCached=os_=='Android'or os_=='iOS'
 end
 return mobileCached
end
M.mobile=mobile
-- Preserve the previous context on returns AND errors, separately per coroutine.
-- A nested Battle Art hook overrides an enclosing other-mod context.
local mainContext={}
local contexts=setmetatable({},{__mode='k'})
local undoCR={}
local wrappedHooks=setmetatable({},{__mode='k'})
local removeU,lastSweep=nil,-1e9
local function currentContext()
 local co=coroutine.running()
 if not co then return mainContext end
 local c=contexts[co]
 if not c then c={};contexts[co]=c end
 return c
end
local function context()return currentContext().who end
local function eligible()local c=context();return c=='characters'or c=='other'end
M.eligible=eligible
local function restore(c,prev,ok,...)
 c.who=prev
 if not ok then error((...),0)end
 return ...
end
local function mark(label,f)
 local installedGeneration=generation
 return function(...)
  if not active or generation~=installedGeneration then return f(...)end
  local c=currentContext();local prev=c.who;c.who=label
  return restore(c,prev,pcall(f,...))
 end
end
local function wrapCharacters()
 local ok,CR=pcall(V.require,'CharacterRenderers')
 if not ok or not CR then return end
 for _,name in ipairs({'first','all'})do
  local original=CR[name];local old=undoCR[name]
  if type(original)=='function'and not(old and old[1]==CR and old[3]==original)then
   local wrapper=mark('characters',original)
   local assigned=pcall(function()CR[name]=wrapper end)
   if assigned and CR[name]==wrapper then undoCR[name]={CR,original,wrapper}end
  end
 end
end
local function wrapHooks()
 local ok,R=pcall(require,'src.mods.Runtime')
 local chains=ok and R and R.hooks and R.hooks.chains
 if type(chains)~='table'then return end
 for _,chain in pairs(chains)do
  if type(chain)=='table'then
   for _,e in ipairs(chain)do
    if type(e)=='table'and type(e.callback)=='function'then
     local old=wrappedHooks[e]
     if not(old and e.callback==old[2])then
      local original=e.callback
      local owner=tostring(e.owner or'?')
      local wrapper=mark(owner~='BATTLE_ART_VOXEL_FORK'and owner~='?'and'other'or'own',original)
      local assigned=pcall(function()e.callback=wrapper end)
      if assigned and e.callback==wrapper then wrappedHooks[e]={original,wrapper}end
     end
    end
   end
  end
 end
end
local function sweep()
 local ok,t=pcall(function()return love.timer.getTime()end)
 t=ok and t or 0
 if t-lastSweep>=10 then lastSweep=t;pcall(wrapCharacters);pcall(wrapHooks)end
end

local function optional(o,name,...)
 if type(o[name])~='function'then return nil end
 local ok,a,b=pcall(o[name],o,...);if ok then return a,b end
end
local function halve(img,create)
 local canvas,data,small
 local pushed,filterChanged=false,false
 local fmin,fmag,anis=img:getFilter()
 local wu,wv=img:getWrap()
 local w,h=img:getPixelDimensions()
 local nw,nh=math.floor(w/2),math.floor(h/2)
 local dpi=optional(img,'getDPIScale')or 1
 local linear=optional(img,'isFormatLinear')==true
 local mips=(optional(img,'getMipmapCount')or 1)>1
 local mipMode,mipSharp=optional(img,'getMipmapFilter')
 local ok,err=pcall(function()
  canvas=G.newCanvas(nw,nh,{dpiscale=1,format=linear and 'rgba8'or 'normal'})
  G.push('all');pushed=true
  G.setCanvas(canvas);G.origin();G.setShader();G.setScissor()
  G.setDepthMode();G.setStencilTest()
  if G.setColorMask then G.setColorMask(true,true,true,true)end
  if G.setWireframe then G.setWireframe(false)end
  if G.setMeshCullMode then G.setMeshCullMode('none')end
  G.clear(0,0,0,0);G.setBlendMode('replace','premultiplied');G.setColor(1,1,1,1)
  filterChanged=true;img:setFilter('linear','linear')
  G.draw(img,0,0,0,nw*dpi/w,nh*dpi/h)
  -- Detach before readback; pop restores the entire previous draw state,
  -- including the depth/render targets used by the surrounding shadow pass.
  G.setCanvas();G.pop();pushed=false
  img:setFilter(fmin,fmag,anis);filterChanged=false
  data=canvas:newImageData()
  small=create(data,{mipmaps=mips,linear=linear,dpiscale=dpi})
  small:setFilter(fmin,fmag,anis);small:setWrap(wu,wv)
  if mips and mipMode and small.setMipmapFilter then small:setMipmapFilter(mipMode,mipSharp)end
 end)
 if pushed then pcall(G.setCanvas);pcall(G.pop)end
 if filterChanged then pcall(img.setFilter,img,fmin,fmag,anis)end
 release(data);release(canvas)
 if not ok then release(small);return nil,err end
 return small,nil,(w*h-nw*nh)*4*(mips and 4/3 or 1)
end

function M.install(mod)
 if orig or not mobile()or type(G.newImage)~='function'then return end
 local create=G.newImage
 generation=generation+1;local installedGeneration=generation
 local candidate=function(...)
  local img=create(...)
  if not active or installedGeneration~=generation or busy or not img then return img end
  local ok,selected=pcall(function()
   local w,h=img:getPixelDimensions()
   if type(w)~='number'or w<2048 or w~=h or not eligible()then return false end
   -- Expanding a compressed GPU format to RGBA8 can increase memory use.
   if optional(img,'isCompressed')then return false end
   local format=optional(img,'getFormat')
   return not format or format=='rgba8'or format=='srgba8'or format=='normal'
  end)
  if not ok or not selected then return img end
  busy=true
  local okH,small,err,saved=pcall(halve,img,create)
  busy=false
  if okH and small then
   M.shrunk=M.shrunk+1;M.saved=M.saved+(saved or 0)
   release(img);return small
  end
  M.failed=M.failed+1;M.lastError=tostring(okH and err or small):sub(1,160)
  return img
 end
 local ok=pcall(function()G.newImage=candidate end)
 if ok and G.newImage==candidate then
  orig=create;wrapper=candidate;active=true
  M.shrunk=0;M.saved=0;M.failed=0;M.lastError=nil
  if mod and mod.hooks and type(mod.hooks.wrap)=='function'then
   local okU,rem=pcall(mod.hooks.wrap,mod.hooks,'core.update',function(nxt,game,dt)
    if active and generation==installedGeneration then sweep()end
    return nxt(game,dt)
   end)
   if okU and type(rem)=='function'then removeU=rem end
  end
  sweep()
 end
end
function M.dispose()
 active=false
 if removeU then pcall(removeU);removeU=nil end
 for name,r in pairs(undoCR)do
  if r[1][name]==r[3]then pcall(function()r[1][name]=r[2]end)end
 end
 for e,r in pairs(wrappedHooks)do
  if e.callback==r[2]then pcall(function()e.callback=r[1]end)end
 end
 if orig and G.newImage==wrapper then pcall(function()G.newImage=orig end)end
 orig=nil;wrapper=nil;busy=false
 undoCR={};wrappedHooks=setmetatable({},{__mode='k'})
 mainContext={};contexts=setmetatable({},{__mode='k'});lastSweep=-1e9
end
return M
