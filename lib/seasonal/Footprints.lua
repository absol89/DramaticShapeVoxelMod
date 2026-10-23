-- Bounded cosmetic impressions on accepted snow triangles. Does not alter
-- player position, collision, terrain, NPCs or save data.
local G,Snow=...
local M={};M.__index=M;M.limit=96;M.lifetime=60
local outline={{-.48,-1.45},{.48,-1.45},{.62,-.85},{.43,-.25},{.70,.28},{.70,1.0},{.42,1.55},{-.38,1.6},{-.70,1.05},{-.70,.25},{-.43,-.25},{-.58,-.85}}
function M.new()return setmetatable({prints={},side=-1,travel=0,uploads=0},M)end
function M:clear()
 self.prints={};self.previous=nil;self.travel=0;self.tick=nil
 if self.mesh then self.mesh:release();self.mesh=nil end
 self.capacity=nil
end
function M:geometry(surface,time)
 local g=G.new()
 for _,p in ipairs(self.prints)do
  local alpha=math.max(0,1-(time-p.time)/M.lifetime)
  local centerY=Snow.height(surface,p.x,p.z)
  if alpha>0 and centerY then
   local inner,outer={},{};local valid=true
   for i,o in ipairs(outline)do
    local function point(scale,offset)
     local x=p.x+(o[1]*p.dz+o[2]*p.dx)*scale
     local z=p.z+(-o[1]*p.dx+o[2]*p.dz)*scale
     local y=Snow.height(surface,x,z)
     if not y then valid=false;return{x,0,z}end
     return{x,y+offset,z}
    end
    inner[i]=point(1,.035);outer[i]=point(1.18,.050)
   end
   if valid then
    local uv={{alpha,.5},{alpha,.5},{alpha,.5}}
    local c={p.x,centerY+.036,p.z}
    for i=1,#outline do local j=i%#outline+1
     G.tri(g,c,inner[j],inner[i],'footprint',1,uv)
     G.tri(g,inner[i],inner[j],outer[j],'footprintRim',1,uv)
     G.tri(g,inner[i],outer[j],outer[i],'footprintRim',1,uv)
    end
   end
  end
 end
 return g
end
function M:update(player,surface,time,dt,enabled)
 if not enabled or not surface or not player then
  if self.previous or #self.prints>0 or self.mesh then self:clear()end
  return
 end
 local x,z=(player.px or player.x or 0)+8,(player.py or player.y or 0)+8
 local walking=not(player.surfing or player.biking or player.flying)and math.abs(player.lift or 0)<.5
 local prev=self.previous;self.previous={x=x,z=z}
 local dirty=false
 if prev and walking then
  local dx,dz=x-prev.x,z-prev.z;local distance=math.sqrt(dx*dx+dz*dz)
  if distance>24 or distance/math.max(.001,dt)>110 then self.travel=0
  elseif distance>.001 then
   dx,dz=dx/distance,dz/distance
   local left=distance;local used=0
   while self.travel+left>=4.8 do
    local take=4.8-self.travel;used=used+take;left=left-take;self.travel=0
    self.side=-self.side
    local px,pz=prev.x+dx*used+dz*self.side*1.15,prev.z+dz*used-dx*self.side*1.15
    local y=Snow.height(surface,px,pz)
    if y and math.abs(y-(player.gh or 0))<1.8 then
     if #self.prints>=M.limit then table.remove(self.prints,1)end
     self.prints[#self.prints+1]={x=px,z=pz,dx=dx,dz=dz,side=self.side,time=time};dirty=true
    end
   end
   self.travel=self.travel+left
  end
 else self.travel=0 end
 while self.prints[1]and time-self.prints[1].time>=M.lifetime do table.remove(self.prints,1);dirty=true end
 local tick=math.floor(time*4)
 if #self.prints>0 and (dirty or self.tick~=tick)then
  local g=self:geometry(surface,time);self.tick=tick
  -- One fixed buffer; never grow allocations as the player walks.
  if #g.vertices>0 then
   if not self.mesh then
    local data={};for i=1,M.limit*#outline*9 do data[i]={0,0,0,0,0,1}end
    self.mesh=love.graphics.newMesh(G.FORMAT,data,'triangles','dynamic')
   end
   self.mesh:setVertices(g.vertices,1,#g.vertices);self.mesh:setDrawRange(1,#g.vertices)
   self.uploads=self.uploads+1
  elseif self.mesh then self.mesh:release();self.mesh=nil end
 elseif #self.prints==0 and self.mesh then self.mesh:release();self.mesh=nil end
end
function M:draw(R,texture)
 if self.mesh then R.withEffect('alpha',function()love.graphics.setColor(1,1,1,1);R.draw(self.mesh,texture)end)end
end
M.dispose=M.clear
return M
