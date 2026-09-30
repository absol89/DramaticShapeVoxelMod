local V=...
local R=V.require('Voxel3D')
local Mat4=V.require('Mat4')
local M={}
-- LAMPS3: Mart post at tile 35,30 beside the eastern wall (tile 36),
-- clear of the door on tiles 30/31 and its straight approach.
-- LAMPS4: Center at the west lawn edge; passage lamp beside the south wall.
local points={{4,14,1},{26,14,-1},{35,30,-1},{22,31,1}}
local mesh,texture,mask
local originX,originZ=0,0
local DARK,BRONZE,GLASS=0.5/6,1.5/6,2.5/6
function M.geometry()
  local vertices,indices={},{}
  local function quad(a,b,c,d,u)
    local n=#vertices
    for _,p in ipairs({a,b,c,d}) do vertices[#vertices+1]={p[1],p[2]>25 and (25+(p[2]-25)*.75) or p[2],p[3],u,.5,1} end
    for _,i in ipairs({1,2,3,1,3,4}) do indices[#indices+1]=n+i end
  end
  for _,p in ipairs(points) do
    local x,z=p[1]*8+4,p[2]*8+4
    local function ring(y0,y1,r0,r1,u)
      for i=0,7 do
        local a,b=i*math.pi/4,(i+1)*math.pi/4
        quad({x+r0*math.cos(a),y0,z+r0*math.sin(a)},
             {x+r0*math.cos(b),y0,z+r0*math.sin(b)},
             {x+r1*math.cos(b),y1,z+r1*math.sin(b)},
             {x+r1*math.cos(a),y1,z+r1*math.sin(a)},u)
      end
    end
    local function rod(a,b,r,u)
      local dx,dy,dz=b[1]-a[1],b[2]-a[2],b[3]-a[3]
      local len=math.sqrt(dx*dx+dy*dy+dz*dz)
      dx,dy,dz=dx/len,dy/len,dz/len
      local ux,uy,uz=-dz,0,dx
      local n=math.sqrt(ux*ux+uz*uz)
      if n<.001 then ux,uy,uz=1,0,0 else ux,uz=ux/n,uz/n end
      local vx,vy,vz=dy*uz-dz*uy,dz*ux-dx*uz,dx*uy-dy*ux
      local function vertex(q,t)
        local c,sn=math.cos(t)*r,math.sin(t)*r
        return {q[1]+ux*c+vx*sn,q[2]+uy*c+vy*sn,q[3]+uz*c+vz*sn}
      end
      for i=0,3 do local t,t1=i*math.pi/2,(i+1)*math.pi/2
        quad(vertex(a,t),vertex(a,t1),vertex(b,t1),vertex(b,t),u)
      end
    end
    -- Flared octagonal foot and collared iron shaft.
    ring(0,1,2.1,2.1,DARK);ring(1,4,2.1,1.0,DARK)
    ring(4,4.7,1.15,1.15,BRONZE);ring(4.7,25,0.85,0.72,DARK)
    ring(24,24.8,1.1,1.1,DARK);ring(25,27,0.8,2.7,DARK)
    ring(27,27.6,3.25,3.25,DARK);ring(27.6,28,3.1,3.1,BRONZE)
    -- Three softly differentiated glass bands, alternating panel tint.
    for band=0,2 do
      local y0,y1=28+band*2.5,28+(band+1)*2.5
      for i=0,7 do
        local a,b=i*math.pi/4,(i+1)*math.pi/4
        local swatch=(band==1 and 3 or 2)+(i%2)
        quad({x+2.8*math.cos(a),y0,z+2.8*math.sin(a)},
             {x+2.8*math.cos(b),y0,z+2.8*math.sin(b)},
             {x+2.8*math.cos(b),y1,z+2.8*math.sin(b)},
             {x+2.8*math.cos(a),y1,z+2.8*math.sin(a)},(swatch+.5)/6)
      end
    end
    -- Corner columns and pointed-arch tracery sit outside the glass.
    for i=0,7 do
      local a,b=i*math.pi/4,(i+1)*math.pi/4
      local function at(t,y,r) return {x+math.cos(t)*r,y,z+math.sin(t)*r} end
      rod(at(a,28,3),at(a,35.7,3),.18,DARK)
      local left,right=at(a,32.7,3.02),at(b,32.7,3.02)
      local peak=at((a+b)/2,35,2.82)
      rod(left,peak,.14,DARK);rod(peak,right,.14,DARK)
      rod(at((a+b)/2,28.2,2.82),at((a+b)/2,31.6,2.82),.10,DARK)
      rod(at(a,36,3.35),at(a,37.3,3.35),.15,DARK)
    end
    ring(35.5,36.2,3.2,3.2,DARK)
    -- Layered dome silhouette with raised ribs and a pointed finial.
    local levels={{36.2,3.1},{37,2.95},{38,2.45},{39,1.55},{39.7,.65}}
    for j=1,#levels-1 do
      local a,b=levels[j],levels[j+1]
      ring(a[1],b[1],a[2],b[2],DARK)
      for i=0,7 do local t=i*math.pi/4
        rod({x+math.cos(t)*a[2],a[1],z+math.sin(t)*a[2]},
            {x+math.cos(t)*b[2],b[1],z+math.sin(t)*b[2]},.10,BRONZE)
      end
    end
    ring(39.7,40.3,.65,.85,DARK);ring(40.3,41.7,.85,0,DARK)
  end
  return vertices,indices
end
local function build()
  local d=love.image.newImageData(6,1)
  d:setPixel(0,0,.105,.105,.125,1)
  d:setPixel(1,0,.20,.18,.15,1)
  d:setPixel(2,0,.90,.75,.44,1)
  d:setPixel(3,0,.96,.83,.53,1)
  d:setPixel(4,0,1.0,.90,.65,1)
  d:setPixel(5,0,.96,.83,.53,1)
  texture=love.graphics.newImage(d);texture:setFilter('nearest','nearest')
  local md=love.image.newImageData(6,1)
  for x=0,5 do md:setPixel(x,0,1,1,1,x>=2 and 1 or 0) end
  mask=love.graphics.newImage(md);mask:setFilter('nearest','nearest')
  mesh=R.newMesh(M.geometry())
end
function M.configure(state)
  R.streetLamps=nil
  if not V.require("CommunityVisuals").customCityGround() then return end
  local map,ox,oz=state.map,0,0
  if map.id~='LAVENDER_TOWN' then
    map=nil
    for _,nb in ipairs(state.neighbors or {}) do
      if nb.map.id=='LAVENDER_TOWN' then map=nb.map;ox=nb.ox or 0;oz=nb.oy or 0;break end
    end
  end
  if not map then return end
  originX,originZ=ox,oz
  local positions={}
  for _,p in ipairs(points) do
    positions[#positions+1]={p[1]*8+4+ox,0,p[2]*8+4+oz}
  end
  R.streetLamps=positions
end
function M.draw(state)
  if not R.streetLamps then return end
  if not mesh then build() end
  local model=Mat4.translate(originX,0,originZ)
  local old=R.glassMask
  R.glassMaskNow(mask);R.glass(true)
  local ok,err=pcall(R.draw,mesh,texture,model)
  R.glass(false);R.glassMaskNow(old)
  if not ok then error(err) end
end
return M
