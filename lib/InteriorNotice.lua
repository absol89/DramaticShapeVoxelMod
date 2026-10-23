-- TEST179: a notice on screen when a room InteriorRooms knows is NOT ours
-- (the setting, a layout mismatch, a failed build), so a phone can report
-- the reason without a log. It shows for a few seconds on entering the room
-- and never appears while every room builds.
local V=...
local M={SECONDS=12}
local font;local lastId;local since
local function reasonFor(map)
 local ok,Rooms=pcall(V.require,'InteriorRooms')
 if not(ok and Rooms and map and map.id and Rooms.ROOMS and Rooms.ROOMS[map.id])then return nil end
 -- (asking is what records the reason)
 local okA,own=pcall(Rooms.accepts,map)
 if okA and own then
  -- accepted: a failed build is reported by its cache state
  local ready=Rooms.ready(map.id)
  if ready==false then return Rooms.reasons[map.id]or'build failed'end
  return nil
 end
 return Rooms.reasons[map.id]or'not accepted'
end
local function draw(g,map)
 local id=map.id
 local now=love.timer.getTime()
 if id~=lastId then lastId=id;since=now end
 if now-since>M.SECONDS then return end
 local reason=reasonFor(map);if not reason then return end
 if not font then font=g.newFont(14)end
 local w,h=g.getDimensions()
 g.origin();g.setShader();g.setScissor();g.setDepthMode();g.setBlendMode('alpha')
 g.setFont(font)
 local text='LEGENDARY ROOM OFF  '..tostring(id)..'\n'..tostring(reason):sub(1,220)
 local tw=math.min(w-24,620)
 local _,lines=font:getWrap(text,tw-16)
 local th=#lines*font:getHeight()+14
 local a=math.min(1,(M.SECONDS-(now-since))/1.5)
 g.setColor(.03,.04,.06,.85*a);g.rectangle('fill',12,h-th-12,tw,th,6,6)
 g.setColor(1,.85,.4,a);g.printf(text,20,h-th-5,tw-16,'left')
end
function M.install()
 local mod=V.mod
 if not(mod and mod.hooks and mod.hooks.wrap)then return end
 mod.hooks:wrap('render.hud',function(next,game,viewport)
  local r1,r2,r3=next(game,viewport)
  local map=game and game.overworld and game.overworld.map
  if map and love and love.graphics and love.graphics.push then
   local g=love.graphics
   g.push('all');pcall(draw,g,map);g.pop()
  end
  return r1,r2,r3
 end)
end
return M
