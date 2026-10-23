-- Fall wildlife: bounded local population, shared pose meshes, no collision edits.
local V,G,R=...
local M={};local pi=math.pi
local poses,low={},{};local residents={};local current,choice,failed
local time,poll,buildIndex=0,0,0
local STEPS=24
local function seed(id)local s=17;for i=1,#id do s=(s*31+id:byte(i))%104729 end;return s end
function M.enabled(o)return o and(o.holiday=='halloween'or o.holiday=='harvest')and o.spiders~='off'end
function M.habitat(map)
 local ts=map and((map.def and map.def.tileset)or(map.tileset and map.tileset.id))
 if ts=='CAVERN'then return 'cave'end
 if map and map.id=='VIRIDIAN_FOREST'then return 'forest'end
 if ts=='OVERWORLD'or ts=='FOREST'or ts=='PLATEAU'then return 'town'end
end
-- The moving half of each alternating tetrapod gait lifts while the other
-- half plants. Front is -Z; proximal joints remain rooted in the cephalothorax.
function M.geometry(phase,simple)
 local g=G.new();local n=simple and 8 or 16;local rings=simple and 4 or 8
 G.sphere(g,0,2.05,1.25,1.38,1.25,1.95,'spiderFur',n,rings)
 G.sphere(g,0,1.90,-1.0,1.15,.77,1.30,'spiderShell',n,rings)
 G.sphere(g,0,1.70,-2.00,.73,.46,.55,'spiderShell',n,rings)
 -- Small clustered eyes, without cartoon glow or oversized whites.
 for _,eye in ipairs({{-.30,2.08,-2.41},{.30,2.08,-2.41},{-.10,2.24,-2.38},{.10,2.24,-2.38},{-.55,1.98,-2.28},{.55,1.98,-2.28},{-.68,1.98,-2.08},{.68,1.98,-2.08}})do
  G.sphere(g,eye[1],eye[2],eye[3],.095,.095,.085,'black',6,3)
 end
 for _,side in ipairs({-1,1})do
  G.tube(g,{side*.37,1.6,-2.2},{side*.46,1.12,-2.65},.20,'spiderShell',6,.10)
  G.tube(g,{side*.46,1.12,-2.65},{side*.20,.91,-2.75},.10,'black',5,.025)
  G.tube(g,{side*.70,1.65,-1.9},{side*1.1,1.2,-2.55},.12,'spiderFur',5,.07)
  for leg=1,4 do
   local cycle=(phase+(leg%2)*.5+(side==1 and .5 or 0))%1
   local swing=cycle<.5
   local f=swing and cycle*2 or(cycle-.5)*2
   local stride=swing and(.3-.6*f)or(-.3+.6*f)
   local lift=swing and math.sin(f*pi)*.80 or 0
   local z=-2.8+(leg-1)*1.75
   local a={side*.85,1.95,-1.65+(leg-1)*.60}
   local b={side*(2.25+math.sin(leg)*.16),3.1,z*.70+stride*.35}
   local c={side*(3.4+math.sin(leg)*.3),1.4+lift*.5,z+stride*.75}
   local d={side*(4.35+math.sin(leg)*.35),.08+lift,z+stride}
   G.tube(g,a,b,.22,'spiderFur',simple and 4 or 7,.17)
   G.tube(g,b,c,.17,'spiderShell',simple and 4 or 7,.10)
   G.tube(g,c,d,.10,'spiderFur',simple and 4 or 6,.025)
   if not simple then
    G.sphere(g,b[1],b[2],b[3],.19,.19,.19,'spiderShell',6,4)
    for j=1,5 do
     local f=j/6;local p={b[1]+(c[1]-b[1])*f,b[2]+(c[2]-b[2])*f,b[3]+(c[3]-b[3])*f}
     G.tube(g,p,{p[1]+side*.19,p[2]+.24,p[3]+.07},.018,'deadwood',3,.003,nil,false)
    end
   end
  end
 end
 if not simple then
  for j=1,96 do
   local a=G.hash(j,9)*pi*2;local b=G.hash(j,13)*1.8-.3
   local x,y,z=1.37*math.cos(a)*math.cos(b),2.05+1.24*math.sin(b),1.25+1.94*math.sin(a)*math.cos(b)
   local len=.10+G.hash(j,31)*.17
   G.tube(g,{x,y,z},{x+math.cos(a)*len,y+len*.6,z+math.sin(a)*len},.012,'deadwood',3,.002,nil,false)
  end
 end
 return g
end
local heights={}
local function floorAt(map,x,z)
 local key=math.floor(x/16)..":"..math.floor(z/16)
 if heights[key]~=nil then return heights[key]end
 local ok,y=pcall(function()return V.require('VoxelScene').groundAt(map,math.floor(x/16),math.floor(z/16),x-8,z-8)end)
 local h=ok and tonumber(y)or 0;heights[key]=h;return h
end
local function clear(map,x,z,foot,y)
 if not map.isWalkableCell then return false end
 local def=map.def or {};local w,h=map.widthCells or(def.width or 0)*2,map.heightCells or(def.height or 0)*2
 for cy=math.floor((z-foot)/16),math.floor((z+foot)/16)do for cx=math.floor((x-foot)/16),math.floor((x+foot)/16)do
  if cx<0 or cy<0 or cx>=w or cy>=h then return false end
  local ok,on=pcall(map.isWalkableCell,map,cx,cy);if not ok or not on then return false end
  if map.isWaterCell then local good,wet=pcall(map.isWaterCell,map,cx,cy);if not good or wet then return false end end
  if math.abs(floorAt(map,cx*16+8,cy*16+8)-y)>.20 then return false end
 end end
 for _,list in ipairs({def.warps or{},def.objects or{}})do for _,p in ipairs(list)do
  if p.x and p.y and math.abs(p.x*16+8-x)<foot+18 and math.abs(p.y*16+8-z)<foot+18 then return false end
 end end
 return true
end
local function route(map,x,z,scale,h)
 local foot=scale*4.9+4;local y=floorAt(map,x,z)
 if not clear(map,x,z,foot,y)then return end
 local dx,dz=h<.5 and 1 or 0,h<.5 and 0 or 1
 local function reach(sign)
  local dist=0
  for d=4,40,4 do
   if not clear(map,x+dx*d*sign,z+dz*d*sign,foot,y)then break end
   dist=d
  end
  return dist
 end
 local a,b=reach(-1),reach(1)
 -- Try the other axis before rejecting a narrow corridor.
 if a+b<12 then dx,dz=dz,dx;a,b=reach(-1),reach(1)end
 if a+b<12 then return end
 return{x0=x-dx*a,z0=z-dz*a,x1=x+dx*b,z1=z+dz*b,y=y+.20,length=a+b,dx=dx,dz=dz}
end
function M.limit(map)return M.habitat(map)=='cave'and 10 or 4 end
function M.plan(map,px,pz,mode)
 heights={}
 local habitat=M.habitat(map);if not habitat then return{}end
 local list,giants={},{};local s=seed(map.id or'');local spacing=habitat=='cave'and 32 or 48
 local gx,gz=math.floor(px/spacing),math.floor(pz/spacing);local range=math.ceil(176/spacing)
 for z=gz-range,gz+range do for x=gx-range,gx+range do
  local h=G.hash(x,z,s)
  if h<(habitat=='cave'and .60 or .40)then
   local wx,wz=x*spacing+8,z*spacing+8
   local d=(wx-px)^2+(wz-pz)^2
   if d<176^2 then
    local tiny=.22+G.hash(x,z,s+3)*.23
    local giant=mode~='small'and h<(habitat=='town'and .025 or .085)
    local scale=giant and((habitat=='town'and 4.5 or 6)+G.hash(x,z,s+4)*2.5)or tiny
    local path=route(map,wx,wz,scale,G.hash(x,z,s+7))
    if not path and giant then giant=false;scale=tiny;path=route(map,wx,wz,scale,G.hash(x,z,s+7))end
    if path then
     path.x,path.z,path.scale,path.seed,path.d=wx,wz,scale,G.hash(x,z,s+5),d
     path.giant=giant;path.speed=giant and(12+path.seed*8)or(18+path.seed*16)
     if giant then giants[#giants+1]=path else list[#list+1]=path end
    end
   end
  end
 end end
 local function nearer(a,b)return a.d<b.d end
 table.sort(list,nearer);table.sort(giants,nearer)
 local limit=M.limit(map)
 while #list>limit-(#giants>0 and 1 or 0)do table.remove(list)end
 if #giants>0 then list[#list+1]=giants[1]end
 return list
end
-- Persistent wandering state. Probe ahead, slow to a stop, then take an
-- open oblique direction. Never mirror velocity on contact with a wall.
local function delta(a,b)return(b-a+pi)%(2*pi)-pi end
function M.advance(a,map,dt)
 local st=a.state
 if not st then st={x=a.x,z=a.z,angle=a.seed*2*pi,target=a.seed*2*pi,wait=.2+a.seed,run=0,phase=0,turn=0};a.state=st end
 local foot=a.scale*4.9+4
 local function valid(x,z)
  return(x-a.x)^2+(z-a.z)^2<64^2 and clear(map,x,z,foot,a.y-.20)
 end
 local function open(angle,dist)
  for d=2,dist,2 do if not valid(st.x-math.sin(angle)*d,st.z-math.cos(angle)*d)then return false end end
  return true
 end
 if st.wait>0 then st.wait=math.max(0,st.wait-dt);return end
 if st.run<=0 then
  st.turn=st.turn+1
  local flip=G.hash(st.turn,7,math.floor(a.seed*10000))<.5 and -1 or 1
  local found
  for _,offset in ipairs({.45*flip,-.65*flip,1.05*flip,-1.3*flip,1.9*flip,-2.3*flip,pi})do
   local angle=st.angle+offset
   if open(angle,14)then found=angle;break end
  end
  if not found then st.wait=.6+a.seed;return end
  st.target=found;st.run=.6+G.hash(st.turn,11,math.floor(a.seed*10000))*1.6
 end
 local difference=delta(st.angle,st.target)
 local turn=math.min(math.abs(difference),dt*(a.giant and 1.6 or 3.8))
 st.angle=st.angle+(difference<0 and -turn or turn)
 -- Face the clear direction before stepping, so turns cannot cut corners.
 if math.abs(difference)>.15 then return end
 if not open(st.angle,12)then st.run=0;st.wait=.25+a.seed*.65;return end
 local step=a.speed*dt
 local x,z=st.x-math.sin(st.angle)*step,st.z-math.cos(st.angle)*step
 if valid(x,z)then
  st.x,st.z=x,z;st.run=st.run-dt
  st.phase=(st.phase+dt*math.min(10,a.speed/(a.scale*1.2)))%1
  if st.run<=0 then st.wait=.25+G.hash(st.turn,19,math.floor(a.seed*10000))*1.6 end
 else st.run=0;st.wait=.4 end
end
function M.motion(a)
 local s=a.state
 if not s then return a.x,a.y,a.z,a.seed*2*pi,0 end
 return s.x,a.y,s.z,s.angle,s.phase
end
function M.dispose()
 for _,set in ipairs({poses,low})do for _,m in pairs(set)do if m and m.release then m:release()end end end
 poses,low,residents={},{},{};current,choice=nil,nil;buildIndex=0;poll=0;failed=false
end
function M.update(state,dt,o)
 if not M.enabled(o)or not(state and M.habitat(state.map))then if current or buildIndex>0 then M.dispose()end;return end
 time=time+math.min(.1,math.max(0,dt or 0));poll=poll-(dt or 0)
 if current~=state.map or choice~=o.spiders then current=state.map;choice=o.spiders;residents={};poll=0;failed=false end
 local p=state.player;local px,pz=(p and p.px or 0)+8,(p and p.py or 0)+8
 if poll<=0 then
  local old={};for _,a in ipairs(residents)do old[a.x..':'..a.z]=a end
  local fresh=M.plan(current,px,pz,choice)
  for _,a in ipairs(fresh)do local prior=old[a.x..':'..a.z];if prior and prior.scale==a.scale then a.state=prior.state end end
  residents=fresh;poll=1.5
 end
 for _,a in ipairs(residents)do M.advance(a,current,math.min(.05,math.max(0,dt or 0)))end
 if not failed and #residents>0 and buildIndex<STEPS+8 then
  local i=buildIndex;local simple=i>=STEPS;local k=simple and i-STEPS or i
  local g=M.geometry(k/(simple and 8 or STEPS),simple)
  local mesh=R.newMesh(g.vertices);if mesh then (simple and low or poses)[k+1]=mesh;buildIndex=i+1 else failed=true end
 end
end
function M.draw(state,o)
 if not M.enabled(o)or not state or state.map~=current or not poses[1]then return end
 local texture=G.texture();local p=state.player;local px,pz=(p and p.px or 0)+8,(p and p.py or 0)+8
 love.graphics.setColor(1,1,1,1);R.glass(false)
 for _,a in ipairs(residents)do
  local d=(a.x-px)^2+(a.z-pz)^2
  if d<176^2 then
   local x,y,z,angle,phase=M.motion(a,time)
   -- Small scurriers use the light mesh even nearby. Giants keep the bristles.
   local simple=(not a.giant or d>128^2)and low[8];local set=simple and low or poses;local count=simple and 8 or STEPS
   local mesh=set[math.floor(phase*count)+1]or poses[1]
   local c,s=math.cos(angle)*a.scale,math.sin(angle)*a.scale
   R.draw(mesh,texture,{c,0,s,x,0,a.scale,0,y,-s,0,c,z,0,0,0,1})
  end
 end
 R.glass(true)
end
M.stats=function()return{residents=#residents,poseMeshes=buildIndex,limit=M.limit(current)}end
return M
