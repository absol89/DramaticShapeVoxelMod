-- Rear gatehouse shell, owned by the real two-cell Safari exit.
local V=...
local M={}
function M.matches(map)
 if not(map and map.id=='SAFARI_ZONE_CENTER' and map.tileset.id=='FOREST')then return false end
 local found={}
 for _,w in ipairs(map.def.warps or {})do
  if w.y==25 and w.destMap=='SAFARI_ZONE_GATE' and ((w.x==14 and w.destWarp==3) or (w.x==15 and w.destWarp==4))then found[w.x]=true end
 end
 return found[14] and found[15] or false
end
local faces={{1,2,3,4},{5,8,7,6},{1,5,6,2},{4,3,7,8},{1,4,8,5},{2,6,7,3}}
local shades={1,.75,.6,1,.82,.9}
function M.geometry(uv)
 local q={}
 local function box(x,y,z,w,h,d,color,role)
  y,h=y*.6,h*.6
  local p={{x,y,z},{x+w,y,z},{x+w,y+h,z},{x,y+h,z},{x,y,z+d},{x+w,y,z+d},{x+w,y+h,z+d},{x,y+h,z+d}}
  for f,ids in ipairs(faces)do q[#q+1]={p[ids[1]],p[ids[2]],p[ids[3]],p[ids[4]],uv={uv[color],uv[color],uv[color],uv[color]},shade=shades[f],own=true,gateRole=role}end
 end
 -- Structural body is beyond the original map edge (z416). No walking cells claimed.
 box(192,0,416,32,44,32,'wood','wall');box(256,0,416,32,44,32,'wood','wall')
 box(224,36,416,32,8,32,'wood','lintel');box(192,0,446,96,44,2,'wood','rear')
 for _,x in ipairs({192,220,256,284})do box(x,0,415.5,4,44,3,'dark','post')end
 box(188,44,412,104,4,40,'dark','roof')
 -- Opaque backing and two inset door leaves; no view through the center seam.
 box(224,0,417,32,36,2,'dark','doorBacking')
 box(224.75,1,416,14.5,33,1,'wood','door');box(240.75,1,416,14.5,33,1,'wood','door')
 for y=6,30,6 do
  box(196,y,415.4,24,.6,.25,'middle','wallSeam');box(260,y,415.4,24,.6,.25,'middle','wallSeam')
  box(225,y,415.7,14,.35,.35,'middle','doorSeam');box(241,y,415.7,14,.35,.35,'middle','doorSeam')
 end
 box(235.5,16,414.8,2,2,1.2,'dark','handle');box(242.5,16,414.8,2,2,1.2,'dark','handle')
 return q
end
function M.build(S,map,data)
 if not M.matches(map) or not data then return 0 end
 local w,h=data:getDimensions();local uv,best={},{dark=1e9,wood=1e9,middle=1e9}
 for y=0,h-1 do for x=0,w-1 do
  local a,b,c,alpha=data:getPixel(x,y)
  if (alpha or 1)>.5 then for name,target in pairs({dark=0,wood=2/3,middle=1/3})do
   local score=math.abs((a+b+c)/3-target)
   if score<best[name]then best[name]=score;uv[name]={(x+.5)/w,(y+.5)/h}end
  end end
 end end
 if not(uv.dark and uv.wood and uv.middle)then return 0 end
 local q=M.geometry(uv);for _,face in ipairs(q)do S.objectQuads[#S.objectQuads+1]=face end
 return #q
end
return M
