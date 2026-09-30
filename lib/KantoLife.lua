-- One bounded native batch: shaped fluttering butterflies and night fireflies.
local V=...;local M={MAX_VERTICES=6000};local mesh,texture,lastMap,lastTick,habitat,scanAt
local H=V.require('KantoHabitat')
local function settings()return V.require('CommunityVisuals').kantoLife:get()end
function M.ownsFireflies(map)
 local p=H.profile(map);return settings()~='off'and p and not p.legacy or false
end
function M.invalidate()
 if mesh then mesh:release()end;if texture then texture:release()end
 mesh,texture,lastMap,lastTick,habitat,scanAt=nil,nil,nil,nil,nil,nil
end
function M.vertices(anchors,t,night,profile,px,pz,level,raining)
 local out={};local butterflies,flies=0,0
 local function tri(a,b,c,u,shade)
  for _,p in ipairs({a,b,c,c,b,a})do out[#out+1]={p[1],p[2],p[3],u,.5,shade}end
 end
 local daytime=math.max(0,1-night*2.5)*(raining and 0 or 1)
 local nocturnal=math.max(0,(night-.22)/.78)*(raining and .3 or 1)
 local cap=level=='low'and 9 or 18
 for i,a in ipairs(anchors)do
  if i>cap then break end
  local seed=a.seed;local phase=seed*.17
  local fade=math.max(0,math.min(1,(96-math.sqrt((a.x-px)^2+(a.z-pz)^2))/24))
  local density=(seed%17)/17
  if fade>0 and density<profile.insects then
   local x=a.x+math.sin(t*.42+phase)*3;local z=a.z+math.cos(t*.31+phase)*3
   if daytime>.03 then
    local y=a.y+3.8+math.sin(t*.83+phase)*1.6
    local yaw=phase+math.sin(t*.37+phase)*.9;local ca,sa=math.cos(yaw),math.sin(yaw)
    local flap=.18+math.abs(math.sin(t*(8+seed%4)+phase))*1.22
    local size=fade*daytime*(.50+(seed%5)*.055)
    local function p(wx,wy,wz)return{x+size*(wx*ca-wz*sa),y+size*wy,z+size*(wx*sa+wz*ca)}end
    -- Broad upper wings, scalloped lower wings, dark body and paired antennae.
    local contour={{.10,-.08},{.48,-1.18},{1.13,-1.53},{1.52,-1.22},{1.65,-.60},{1.43,-.10},{1.12,.17},{1.40,.60},{1.13,1.09},{.60,1.22},{.20,.73}}
    for _,side in ipairs({-1,1})do
     local ring={};for k,c in ipairs(contour)do ring[k]=p(side*c[1]*math.cos(flap),c[1]*math.sin(flap),c[2])end
     local center=p(side*.48*math.cos(flap),.48*math.sin(flap),0)
     local u=((seed%3)+.5)/5
     for k=1,#ring do tri(center,ring[k],ring[k%#ring+1],u,.92+(k%3)*.04)end
     for _,zz in ipairs({-.8,.5})do tri(p(side*.55*math.cos(flap),.55*math.sin(flap)+.015,zz-.13),p(side*.91*math.cos(flap),.91*math.sin(flap)+.015,zz),p(side*.60*math.cos(flap),.60*math.sin(flap)+.015,zz+.16),.7,.85)end
    end
    tri(p(-.09,.04,-.85),p(.09,.04,-.85),p(0,.04,1),.7,.82)
    for _,side in ipairs({-1,1})do tri(p(0,.04,-.66),p(side*.30,.20,-1.18),p(side*.24,.20,-1.2),.7,.86)end
    butterflies=butterflies+1
   end
   if nocturnal>.03 and not profile.legacy then
    for j=1,2 do
     local yy=a.y+3+j*1.4+math.sin(t*.7+phase+j)*1.3
     local fx,fz=x+math.sin(phase+j+t*.2)*3,z+math.cos(phase+j+t*.3)*3
     local r=(.07+.17*math.max(0,math.sin(t*(1.3+j*.2)+phase+j*2))^3)*fade*nocturnal
     tri({fx-r,yy-r,fz},{fx+r,yy-r,fz},{fx,yy+r,fz},.9,65)
     tri({fx,yy-r,fz-r},{fx,yy-r,fz+r},{fx,yy+r,fz},.9,65)
     flies=flies+1
    end
   end
  end
 end
 assert(#out<=M.MAX_VERTICES,'Kanto life budget')
 return out,butterflies,flies
end
function M.draw(state)
 local map=state and state.map;local profile=H.profile(map);local level=settings()
 if level=='off'or not profile then if lastMap then M.invalidate()end;return end
 if lastMap~=map then M.invalidate();lastMap=map end
 local p=state.player or{};local px=(p.px or p.x or(p.cellX and p.cellX*16)or 0)+8
 local pz=(p.py or p.y or(p.cellY and p.cellY*16)or 0)+8
 local now=love.timer.getTime();local tick=math.floor(now*30)
 if not scanAt or now-scanAt>.25 then habitat=H.scan(map,V.require('Structures').forMap(map),px,pz);scanAt=now end
 local night=V.require('DayNight').windowLight();local weather=rawget(_G,'__ds_weather')or{}
 V.require('KantoLifeAudio').touch(map.id,profile,habitat,night,weather.raining,level)
 if tick~=lastTick then
  local verts=M.vertices(habitat.green,now,night,profile,px,pz,level,weather.raining)
  if #verts==0 then lastTick=nil;return end
  if not mesh then
   mesh=love.graphics.newMesh(V.require('Voxel3D').FORMAT,M.MAX_VERTICES,'triangles','dynamic')
   local data=love.image.newImageData(5,1)
   for i,c in ipairs({{.88,.62,.23},{.67,.80,.90},{.82,.71,.91},{.16,.13,.12},{.82,1,.37}})do data:setPixel(i-1,0,c[1],c[2],c[3],1)end
   texture=love.graphics.newImage(data);texture:setFilter('nearest','nearest');data:release()
  end
  mesh:setVertices(verts,1,#verts);mesh:setDrawRange(1,#verts);lastTick=tick
 end
 if mesh then V.require('Voxel3D').draw(mesh,texture)end
end
return M
