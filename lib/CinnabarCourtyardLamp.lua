-- One static courtyard feature, chosen from the authored Gym entrance and safe ground.
local V=...
local C=V and V.require('SurfaceCraft') or assert(loadfile('lib/SurfaceCraft.lua'))()
local M={}
function M.choose(map,S,isWood)
 if tostring(map.id or map.def.id or ''):upper()~='CINNABAR_ISLAND' then return nil end
 local gym
 for _,w in ipairs(map.def.warps or {})do if tostring(w.destMap or ''):upper()=='CINNABAR_GYM' then gym=w;break end end
 if not gym then return nil end
 local wx,wz=gym.x*2+.5,gym.y*2+.5
 local best,score
 for z=math.floor(wz+2),math.floor(wz+12) do
  for x=math.floor(wx-12),math.floor(wx+12) do
   local clear=true
   -- Three clear shape tiles (24 world units) around a 2.9-unit base.
   for dz=-1,1 do for dx=-1,1 do
    local tx,tz=x+dx,z+dz;local key=tx..':'..tz;local s=S.shapeAt[key]
    if not s or s.class~='ground' or S.skip[key] or isWood(tx,tz) then clear=false end
   end end
   for _,w in ipairs(map.def.warps or {})do
    local dx,dz=math.abs(x-(w.x*2+.5)),z-(w.y*2+.5)
    if (dx<2 and math.abs(dz)<2) or (dx<1.5 and dz>=0 and dz<5) then clear=false end
   end
   -- Runtime NPC positions must not change persistent mesh placement.
   local value=(x-(wx-5))^2+(z-(wz+3))^2
   if clear and (not score or value<score) then best={tx=x,tz=z,x=x*8+4,z=z*8+4};score=value end
  end
 end
 return best
end
function M.build(p,h,emit)
 local G=C.builder(p.tx*8,p.tz*8,emit);local x,z=p.x,p.z
 local function box(a,b,c,d,lo,hi,s,t)G.box(x+a,z+b,x+c,z+d,h+lo,h+hi,s,t or 1)end
 box(-1.45,-1.45,1.45,1.45,.42,.85,'stone',.93)
 box(-1.1,-1.1,1.1,1.1,.85,1.55,'stone',1)
 box(-.65,-.65,.65,.65,1.55,3.0,'iron',1.10)
 box(-.34,-.34,.34,.34,3,25,'iron',1.20)
 for _,y in ipairs({3,18.8,24.4})do box(-.48,-.48,.48,.48,y,y+.35,'iron',1.4)end
 box(-2.8,-.25,2.8,.25,24.6,25.15,'iron',1.2)
 for _,offset in ipairs({-2.55,2.55})do
  box(offset-.15,-.15,offset+.15,.15,23.6,24.6,'iron',1.15)
  box(offset-.92,-.92,offset+.92,.92,22.9,23.6,'iron',1.25)
  box(offset-.66,-.66,offset+.66,.66,20.0,22.9,'glass',1.25)
  box(offset-.87,-.87,offset+.87,.87,19.65,20,'iron',1.20)
  for _,dx in ipairs({-.8,.62})do for _,dz in ipairs({-.8,.62})do
   box(offset+dx,dz,offset+dx+.18,dz+.18,19.9,23.0,'iron',1.25)
  end end
  box(offset-.85,-.85,offset+.85,.85,21.4,21.58,'iron',1.25)
 end
end
return M
