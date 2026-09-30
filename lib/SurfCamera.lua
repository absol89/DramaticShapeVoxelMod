-- Render-only camera clearance for Stadium TEST153 Surf mounts.
local M = {}
local function finite(n) return type(n)=="number" and n==n and math.abs(n)<1e7 end
local function measured(me, posed)
  if not (me and me.surfRide and finite(me.surfRide.seatY)) then return nil end
  for _,p in ipairs(posed or {}) do
    if p.surfMount and p.surfMount.playerPose==me and p.stadiumMon then
      local m=p.stadiumMatrix
      local parts=p.stadiumMon.rig and p.stadiumMon.rig.parts
      if type(m)~="table" or type(parts)~="table" then return nil end
      for i=1,12 do if not finite(m[i]) then return nil end end
      local top, radius, count = -math.huge, 0, 0
      for _,part in ipairs(parts) do
        for _,v in ipairs(part.rows or {}) do
          count=count+1
          if count>20000 or not(finite(v[1]) and finite(v[2]) and finite(v[3])) then return nil end
          local x=m[1]*v[1]+m[2]*v[2]+m[3]*v[3]+m[4]-(me.px+8)
          local y=m[5]*v[1]+m[6]*v[2]+m[7]*v[3]+m[8]
          local z=m[9]*v[1]+m[10]*v[2]+m[11]*v[3]+m[12]-(me.py+8)
          top=math.max(top,y); radius=math.max(radius,math.sqrt(x*x+z*z))
        end
      end
      if count>0 then return {radius=radius, top=top, seat=me.surfRide.seatY, distance=math.max(180,radius*2+48), minDistance=math.max(72,radius+24)} end
    end
  end
end
function M.measure(me, posed, state)
  -- Live engine lifecycle wins over reusable/stale render metadata.
  if not (state and state.player and state.player.surfing) or state.flyAnim then return nil end
  if state.player._pokepcAsPokemon or not me then return nil end
  local ground = finite(me.gh) and me.gh or 0
  local seat = me.surfRide and me.surfRide.seatY
  if not finite(seat) then seat=ground+32 end
  local ok, bounds = pcall(measured, me, posed)
  if ok and bounds then return bounds end
  -- Stadium2/unavailable vertex buffers must never silently select close view.
  return {radius=66, top=math.max(ground+64,seat+24),seat=seat,distance=180,minDistance=90}
end
-- Zoomed-in framing targets the seated trainer, not the mount's highest fin.
function M.framing(surf, zoom)
  local wide=math.max(0,math.min(1,((zoom or 1)-0.4)/0.6))
  wide=wide*wide*(3-2*wide)
  local shoulder=surf.seat+9
  local high=math.max(surf.top+8,surf.seat+13)
  return shoulder+(high-shoulder)*wide, wide
end
return M
