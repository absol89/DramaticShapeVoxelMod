-- Dense voxel foliage replacing only the complete Safari hedge block.
local V=...
local M={}
local allowed={SAFARI_ZONE_CENTER=true,SAFARI_ZONE_EAST=true,SAFARI_ZONE_NORTH=true,SAFARI_ZONE_WEST=true}
local cache={};local texture
function M.placements(map)
 local out={}
 if not(map and allowed[map.id]and map.tileset.id=='FOREST')then return out end
 for y=0,map.def.height*4-2,2 do for x=0,map.def.width*4-2,2 do
  if map:tileAt(x,y)==84 and map:tileAt(x+1,y)==85 and map:tileAt(x,y+1)==86 and map:tileAt(x+1,y+1)==87 and not map:isWalkableCell(x/2,y/2)then out[#out+1]={x=x/2,z=y/2,tx=x,ty=y}end
 end end
 return out
end
local function hash(x,y,z)return (x*197+y*71+z*283+x*z*13)%997 end
function M.geometry(ps)
 local vox,owners={},{}
 local function key(x,y,z)return x..','..y..','..z end
 for _,p in ipairs(ps)do owners[p.x..','..p.z]=true end
 for _,p in ipairs(ps)do
  local ox,oz=p.x*8,p.z*8
  local shift=(hash(p.x,0,p.z)%3-1)*.4
  for x=0,7 do for z=0,7 do for y=0,9 do
   local xx,yy,zz=x+.5,y+.5,z+.5
   local function lobe(cx,cy,cz,rx,ry,rz)return ((xx-cx)/rx)^2+((yy-cy)/ry)^2+((zz-cz)/rz)^2<=1 end
   local leaf=lobe(2.6,6.5+shift,3.2,3.0,1.8,3.1)or lobe(5.2,7.8+shift,4.3,2.8,1.7,3.0)or lobe(3.8,4.0,4.8,3.0,1.6,2.6)
   -- Join neighboring bushes through their interior, preserving a scalloped edge.
   if y>=5 and y<=7 then
    if (x==0 and owners[(p.x-1)..','..p.z])or(x==7 and owners[(p.x+1)..','..p.z])then leaf=leaf or(z>=2 and z<=5)end
    if (z==0 and owners[p.x..','..(p.z-1)])or(z==7 and owners[p.x..','..(p.z+1)])then leaf=leaf or(x>=2 and x<=5)end
   end
   if leaf then
    local c=2+hash(math.floor((ox+x)/2),math.floor(y/2),math.floor((oz+z)/2))%3
    if y>=7 and hash(ox+x,y,oz+z)%3==0 then c=5 end
    vox[key(ox+x,y,oz+z)]={ox+x,y,oz+z,c}
   end
  end end end
  -- Rooted woody core, mostly sheltered by the leaf clusters.
  for y=0,5 do for x=3,4 do for z=3,4 do vox[key(ox+x,y,oz+z)]={ox+x,y,oz+z,6}end end end
  for x=1,6 do local y=4+math.floor(math.abs(x-3)/2);vox[key(ox+x,y,oz+3)]={ox+x,y,oz+3,6}end

 end
 local D=V.require('Voxel3D');local dirs={{1,0,0},{-1,0,0},{0,1,0},{0,-1,0},{0,0,1},{0,0,-1}}
 local axes={{1,2,3},{1,2,3},{2,1,3},{2,1,3},{3,1,2},{3,1,2}};local groups={}
 for _,v in pairs(vox)do for f,d in ipairs(dirs)do if not vox[key(v[1]+d[1],v[2]+d[2],v[3]+d[3])]then
  local ax=axes[f];local plane=v[ax[1]]+(f%2==1 and 1 or 0);local k=f..':'..plane..':'..v[4]
  local g=groups[k]or {f=f,plane=plane,color=v[4],cells={}};groups[k]=g;g.cells[v[ax[2]]..','..v[ax[3]]]={v[ax[2]],v[ax[3]]}
 end end end
 local verts,indices={},{};local gkeys={};for k in pairs(groups)do gkeys[#gkeys+1]=k end;table.sort(gkeys)
 for _,gk in ipairs(gkeys)do local g=groups[gk];local keys={};for k in pairs(g.cells)do keys[#keys+1]=k end;table.sort(keys)
  for _,k in ipairs(keys)do local cell=g.cells[k];if cell then
   local u,v=cell[1],cell[2];local w,h=1,1
   while g.cells[(u+w)..','..v]do w=w+1 end
   while true do local full=true;for j=0,w-1 do if not g.cells[(u+j)..','..(v+h)]then full=false;break end end;if not full then break end;h=h+1 end
   for y=v,v+h-1 do for x=u,u+w-1 do g.cells[x..','..y]=nil end end
   local ax=axes[g.f];local base,size={0,0,0},{0,0,0};base[ax[1]]=g.plane;base[ax[2]]=u;base[ax[3]]=v;size[ax[2]]=w;size[ax[3]]=h
   local b=#verts;for _,c in ipairs(D.FACE_CORNERS[g.f])do verts[#verts+1]={(base[1]+c[1]*size[1])*2,(base[2]+c[2]*size[2])*2,(base[3]+c[3]*size[3])*2,((g.color-1)*8+.5+c[ax[2]]*7)/48,(.5+c[ax[3]]*7)/8,D.FACE_SHADE[g.f]}end
   for _,i in ipairs({1,2,3,1,3,4})do indices[#indices+1]=b+i end
  end end
 end
 -- Narrow stepped grass blades, rather than trunk-sized blocks.
 for _,p in ipairs(ps)do for _,a in ipairs({{2,2},{13,4},{4,13}})do
  for j=0,2 do
   local x,z=p.x*16+a[1]+j*.55,p.z*16+a[2]
   local h=2+(hash(p.x,j,p.z)%3)*.7
   local b=#verts
   for f,corners in ipairs(D.FACE_CORNERS)do
    b=#verts;for _,c in ipairs(corners)do verts[#verts+1]={x+c[1]*.4,c[2]*h,z+c[3]*.4,4.5/6,.5,D.FACE_SHADE[f]}end
    for _,i in ipairs({1,2,3,1,3,4})do indices[#indices+1]=b+i end
   end
  end
 end end
 return verts,indices
end
local function prepare(map)
 if not(map and allowed[map.id])then return end
 if cache[map.id]then return cache[map.id]end
 local ps=M.placements(map);if #ps==0 then return end
 local ok,r=pcall(function()
  if not texture then
   local colors={{.12,.18,.065},{.24,.31,.105},{.34,.41,.14},{.43,.48,.20},{.64,.57,.29},{.29,.23,.12}}
   -- Two crisp leaf clusters per swatch, with shaded edges and a small ridge.
   -- Geometry stays unchanged; nearest filtering preserves the pixel details.
   local leafRows={
    '00110000','01221000','12221000','01210000',
    '00000110','00001221','00012221','00001210',
   }
   local data=love.image.newImageData(48,8)
   for i,c in ipairs(colors)do for y=0,7 do for x=0,7 do
    local shade=1
    if i>=2 and i<=5 then
     local d=tonumber(leafRows[y+1]:sub(x+1,x+1))
     shade=d==0 and .83 or (d==1 and .96 or 1.16)
    end
    data:setPixel((i-1)*8+x,y,math.min(1,c[1]*shade),math.min(1,c[2]*shade),math.min(1,c[3]*shade),1)
   end end end
   texture=love.graphics.newImage(data);data:release();texture:setFilter('nearest','nearest')
  end
  local verts,indices=M.geometry(ps)
  return {mesh=assert(V.require('Voxel3D').newMesh(verts,indices)),placements=ps,vertices=#verts}
 end)
 if ok then cache[map.id]=r;return r end
end
function M.build(S,map)
 local r=prepare(map);if not r then return 0 end
 for _,p in ipairs(r.placements)do for y=p.ty,p.ty+1 do for x=p.tx,p.tx+1 do
  local k=(y+64)*4096+x+64;S.skip[k]=true;S.ground[k]=48;S.shapeAt[k]={class='ground',h=0,art='flat',flat=true,authored=true}
 end end end
 return #r.placements
end
function M.draw(map,ox,oz,shadow)
 local r=prepare(map);if not r then return end
 local model=(ox~=0 or oz~=0)and V.require('Mat4').translate(ox,0,oz)or nil
 if shadow then shadow.draw(r.mesh,texture,model)else V.require('Voxel3D').draw(r.mesh,texture,model)end
end
function M.setLive(live)
 for id,r in pairs(cache)do if not live[id]then r.mesh:release();cache[id]=nil end end
 if not next(cache)and texture then texture:release();texture=nil end
end
function M.invalidate()M.setLive({})end
function M.diagnostics(map)local r=prepare(map);return r and {count=#r.placements,vertices=r.vertices}or {count=0,vertices=0}end
return M
