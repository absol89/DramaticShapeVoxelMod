-- TEST135: one shared answer for "is it fall?" plus the ground palette.
-- Halloween (October) and Harvest (mid-September through November) both use
-- the autumn landscape, trees and ground. OFF or other holidays leave every
-- summer material untouched. Colors are baked into existing atlases only.
local V=...
local M={}

function M.active()
 local ok,on=pcall(function()
  local h=V.require("SeasonalDecor").Settings.get("holiday")
  return h=="halloween" or h=="harvest"
 end)
 return ok and on or false
end

local function lum(r,g,b)return .2126*r+.7152*g+.0722*b end

-- Dry-grass ramp from shadowed brown roots to sunlit golden tips.
local RAMP={
 {0.00,{.34,.27,.14}},
 {0.35,{.42,.39,.19}},
 {0.65,{.52,.46,.22}},
 {1.00,{.64,.53,.25}},
}
local function ramp(t)
 t=math.max(0,math.min(1,t))
 for i=1,#RAMP-1 do
  local a,b=RAMP[i],RAMP[i+1]
  if t<=b[1] then
   local u=(t-a[1])/(b[1]-a[1])
   return a[2][1]+(b[2][1]-a[2][1])*u,a[2][2]+(b[2][2]-a[2][2])*u,a[2][3]+(b[2][3]-a[2][3])*u
  end
 end
 local c=RAMP[#RAMP][2];return c[1],c[2],c[3]
end

-- Recolor one green, keeping its brightness so texture detail survives.
-- `warmth` (0..1) picks a point on the ramp; nil derives it from brightness.
-- A little of the original green stays in, so lawns read as late-season turf
-- rather than sand.
function M.color(c,warmth)
 local r,g,b=c[1],c[2],c[3]
 local L=lum(r,g,b)
 local t=warmth or math.min(1,math.max(0,(L-.18)/.30))
 local fr,fg,fb=ramp(t)
 local s=(L*1.02)/math.max(lum(fr,fg,fb),.001)
 fr,fg,fb=fr*s,fg*s,fb*s
 local keep=.30
 return {math.min(1,fr+(r-fr)*keep),math.min(1,fg+(g-fg)*keep),math.min(1,fb+(b-fb)*keep),c[4]}
end

local WARMTH={dark=.05,shadow=.35,body=.62,light=.90,[1]=.90,[2]=.62,[3]=.35,[4]=.05}
local cache=setmetatable({},{__mode='k'})
-- Map a dark/shadow/body/light (or 1..4 brightest-first) palette.
function M.palette(p)
 if cache[p] then return cache[p] end
 local out={}
 for k,c in pairs(p)do out[k]=M.color(c,WARMTH[k]) end
 cache[p]=out
 return out
end

-- Fallen-leaf colors for litter flecks: rust, pumpkin, amber, brown.
M.LEAVES={{.56,.24,.11},{.70,.38,.13},{.74,.56,.20},{.42,.27,.14},{.62,.30,.13}}
-- Default garden flowers become marigolds; other flower themes are kept.
M.FLOWER={.90,.47,.14}
return M
