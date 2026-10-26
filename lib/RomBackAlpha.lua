-- Reference corrections for recognized ROM backs only. Identification uses
-- the original (pre-fade) picture; corrections use the current baked palette.
local V = ...
local M = {}
local hints = V.data('rom_back_alpha_hints').byFingerprint

function M.fingerprint(data)
  local w,h = data:getDimensions()
  if w~=32 or h~=32 then return nil end
  local colors, pixels, count = {}, {}, 0
  for y=0,h-1 do for x=0,w-1 do
    local r,g,b,a = data:getPixel(x,y)
    -- Reject authored soft edges and PR62 tags rather than treating them as ROM.
    if a>.001 and a<.999 then return nil end
    if a<.001 then pixels[#pixels+1]=false else
      r,g,b=math.floor(r*255+.5),math.floor(g*255+.5),math.floor(b*255+.5)
      local key=r*65536+g*256+b
      if not colors[key] then count=count+1;colors[key]=count end
      pixels[#pixels+1]=colors[key]
    end
  end end
  if count<2 or count>4 then return nil end
  -- First-appearance color classes survive any distinct palette permutation,
  -- including inversion; color brightness is not part of ROM identity.
  local bytes={};for i=1,#pixels do bytes[i]=string.char(pixels[i] or 0)end
  local digest=love.data.hash('sha256','32x32:'..table.concat(bytes))
  return love.data.encode('string','hex',digest)
end

function M.identify(data)
  local key=M.fingerprint(data)
  return key and hints[key] or nil
end

function M.apply(data,mask,r,g,b)
  local w,h=data:getDimensions()
  if not mask or w~=mask.width or h~=mask.height then return false end
  local changed=false
  for _,run in ipairs(mask.remove)do for k=run[1],run[1]+run[2]-1 do
    local x,y=k%w,math.floor(k/w)
    local R,G,B,a=data:getPixel(x,y)
    if a>.5 then data:setPixel(x,y,R,G,B,0);changed=true end
  end end
  for _,run in ipairs(mask.add)do for k=run[1],run[1]+run[2]-1 do
    local x,y=k%w,math.floor(k/w)
    local _,_,_,a=data:getPixel(x,y)
    -- A provider's explicit GAP tag still wins even in a recognized context.
    if a==0 or (a>.02 and a<=.5) then
      data:setPixel(x,y,r,g,b,1);changed=true
    end
  end end
  return changed
end
return M
