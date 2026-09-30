-- Original bounded park ambience. One depth-tested batch; no lights or shadows.
local V=...
local M={MAX_VERTICES=288}
local lastS,plan,mesh,texture,lastTick
local function release()
 if mesh then mesh:release();mesh=nil end
 if texture then texture:release();texture=nil end
 lastS,plan,lastTick=nil,nil,nil
end
M.invalidate=release
function M.vertices(P,t,night,px,pz)
 local out={};local beds=P and P.beds or {}
 if not night then return out,0 end
 local function quad(a,b,c,d,u,shade)
  for _,p in ipairs({a,b,c,a,c,d,d,c,b,d,b,a})do out[#out+1]={p[1],p[2],p[3],u,.5,shade}end
 end
 local count=0
 for i,bed in ipairs(beds)do
  if i>4 then break end
  local cx,cz=(bed.x0+bed.x1+1)*4,(bed.z0+bed.z1+1)*4
  if (cx-px)^2+(cz-pz)^2<180^2 then
   for j=1,3 do
    local phase=t*(j==1 and .32 or .19)+i*1.7+j*2.3
    local x=cx+math.sin(phase)*math.min(10,(bed.x1-bed.x0)*2)
    local z=cz+math.cos(phase*.83)*math.min(7,(bed.z1-bed.z0)*2)
    local y=2.5+math.sin(phase*1.9)*.8
    -- Only lightning bugs remain; no daytime leaves, petals or butterflies.
    local r=.09+.16*((math.sin(t*2+i*2+j)+1)/2)
    quad({x-r,y-r,z},{x+r,y-r,z},{x+r,y+r,z},{x-r,y+r,z},.9,65)
    quad({x,y-r,z-r},{x,y-r,z+r},{x,y+r,z+r},{x,y+r,z-r},.9,65)
    count=count+1
   end
  end
 end
 assert(#out<=M.MAX_VERTICES)
 return out,count
end
function M.draw(state)
 local CV=V.require('CommunityVisuals');local map=state and state.map
 if not map or map.id~='CELADON_CITY' or not CV.referenceBuildings() or not CV.customRoads() then
  if lastS or mesh then release() end
  return
 end
 local S=V.require('Structures').forMap(map)
 if S~=lastS then
  release();lastS=S
  local key=function(x,z)return (z+64)*4096+x+64 end
  plan=V.require('CeladonPark').plan(map,S,key,function(x,z)
   local tile=S.tileAt[key(x,z)]
   return V.require('CeladonPark').paved(tile,false)
  end)
 end
 if not plan or not plan.beds or #plan.beds==0 then return end
 local R=V.require('Voxel3D');local player=state.player
 local px=player and (player.px or player.x or (player.cellX and player.cellX*16)) or 0
 local pz=player and (player.py or player.y or (player.cellY and player.cellY*16)) or 0
 px,pz=(px or 0)+8,(pz or 0)+8
 local night=V.require('DayNight').windowLight()>.5
 local soundOK,sound=pcall(V.require,'CeladonParkAudio')
 if soundOK then pcall(sound.touch,plan,px,pz,night)end
 if not night then lastTick=nil;return end
 local t=love.timer.getTime();local tick=math.floor(t*30)
 if tick~=lastTick then
  local vertices=M.vertices(plan,t,night,px,pz)
  if #vertices==0 then lastTick=nil;return end
  if not mesh then
   mesh=love.graphics.newMesh(R.FORMAT,M.MAX_VERTICES,'triangles','dynamic')
   local data=love.image.newImageData(5,1)
   local palette={{.94,.74,.26},{.88,.43,.62},{.32,.50,.22},{.45,.33,.15},{.91,1,.45}}
   for i,c in ipairs(palette)do data:setPixel(i-1,0,c[1],c[2],c[3],1)end
   texture=love.graphics.newImage(data);texture:setFilter('nearest','nearest');data:release()
  end
  mesh:setVertices(vertices,1,#vertices);mesh:setDrawRange(1,#vertices);lastTick=tick
 end
 if mesh then R.draw(mesh,texture) end
end
return M
