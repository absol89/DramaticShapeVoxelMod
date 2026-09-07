-- Original Safari monster ornament rebuilt from its own atlas pixels.
-- Front details stay on the front; shaped body sides and back are solid.
local V=...
local M={}
local configs={
 FOREST={tiles={10,11,26,27},base={75,76},ownBase=true,maps={SAFARI_ZONE_CENTER=true,SAFARI_ZONE_WEST=true,SAFARI_ZONE_EAST=true,SAFARI_ZONE_NORTH=true}},
 GATE={tiles={14,15,30,31},base={50,51},ownBase=true,maps={ROUTE_22_GATE=true}},
 INTERIOR={tiles={17,18,33,34},base={91,92},height=8,tabletop=true,maps={POKEMON_FAN_CLUB=true,SILPH_CO_11F=true}},
 GYM={tiles={2,56,18,19},base={34,35,50,51},height=0,plinth=true,maps={PEWTER_GYM=true,CERULEAN_GYM=true,VERMILION_GYM=true,CELADON_GYM=true,FUCHSIA_GYM=true,VIRIDIAN_GYM=true,BRUNOS_ROOM=true,LORELEIS_ROOM=true,CHAMPIONS_ROOM=true}},
 PLATEAU={tiles={16,18,40,41},base={21,22,48,49},height=0,plinth=true,maps={INDIGO_PLATEAU=true,ROUTE_23=true}},
 FACILITY={tiles={39,47,55,63},base={61,62},ownBase=true,maps={SAFFRON_GYM=true,CINNABAR_GYM=true,POKEMON_MANSION_1F=true,POKEMON_MANSION_2F=true,POKEMON_MANSION_3F=true,POKEMON_MANSION_B1F=true}}
}
local cache,templates={},{}
local sourceData
local unit=1
function M.placements(map)
 local out={};local cfg=map and map.tileset and configs[map.tileset.id]
 if not(cfg and cfg.maps[map.id])then return out end
 for y=0,map.def.height*4-2 do for x=0,map.def.width*4-2 do
  local match=true
  for i,id in ipairs(cfg.tiles)do if map:tileAt(x+(i-1)%2,y+math.floor((i-1)/2))~=id then match=false;break end end
  local pedestal=true
  for i,id in ipairs(cfg.base)do if map:tileAt(x+(i-1)%2,y+2+math.floor((i-1)/2))~=id then pedestal=false;break end end
  local originalForest=map.tileset.id=='FOREST'and y%2==0
  if match and (pedestal or originalForest)then
   local baseTy=cfg.ownBase and (pedestal and y+1 or y)or (cfg.tabletop and y+1 or y+2)
   if not map:isWalkableCell(math.floor(x/2),math.floor(baseTy/2))then
    out[#out+1]={x=x*8,z=baseTy*8,tx=x,ty=y,rows=cfg.plinth and 4 or (cfg.ownBase and pedestal and 3 or 2),kind=map.tileset.id,height=cfg.height or 0,tabletop=cfg.tabletop,turn=map.id=='SAFARI_ZONE_CENTER'and baseTy/2>=20}
   end
  end
 end end
 return out
end
-- Occupancy union emits exposed faces only, including real backs and undersides.
function M.template(kind)
 if templates[kind]then return templates[kind]end
 local cfg=assert(configs[kind]);local lift=cfg.plinth and 16 or (cfg.ownBase and 3 or 0)
 local vox={}
 local function key(x,y,z)return x..','..y..','..z end
 local function put(x,y,z,c)
  assert(x>=-12 and x<12 and z>=-12 and z<12,'statue exceeds original footprint')
  vox[key(x,y,z)]={x,y,z,c or 2}
 end
 local function box(x,y,z,w,h,d,c)
  for a=x,x+w-1 do for b=y,y+h-1 do for e=z,z+d-1 do put(a,b,e,c)end end end
 end
 -- Read existing four tiles; no replacement sprite asset is shipped.
 local data=assert(sourceData,'original statue atlas unavailable')
 local iw,ih=data:getDimensions();local perRow=math.floor(iw/8)
 local colors,air,sourceUV={},{},{}
 for y=0,15 do for x=0,15 do
  local tile=cfg.tiles[math.floor(y/8)*2+math.floor(x/8)+1]
  local rr,gg,bb,aa=data:getPixel((tile%perRow)*8+x%8,math.floor(tile/perRow)*8+y%8)
  local c=math.floor((rr+gg+bb)/3*3+.5)
  colors[y*16+x]={c=c,alpha=aa or 1}
  sourceUV[c]=sourceUV[c]or {((tile%perRow)*8+x%8+.5)/iw,(math.floor(tile/perRow)*8+y%8+.5)/ih}
 end end
 local bg=colors[0].c
 local queue={}
 local function seed(x,y)
  if x<0 or y<0 or x>15 or y>15 then return end
  local k=y*16+x;local c=colors[k]
  if not air[k]and(c.c==bg or c.alpha<.5)then air[k]=true;queue[#queue+1]={x,y}end
 end
 for i=0,15 do seed(i,0);seed(i,15);seed(0,i);seed(15,i)end
 local i=1;while queue[i]do local a=queue[i];seed(a[1]-1,a[2]);seed(a[1]+1,a[2]);seed(a[1],a[2]-1);seed(a[1],a[2]+1);i=i+1 end
 if cfg.ownBase then box(-8,0,-8,16,2,16,4);box(-7,2,-7,14,1,14,2)end
 for y=0,15 do for x=0,15 do
  if not air[y*16+x]then
   local edge=math.abs(x-7.5)
   local front,back=12,4
   if y<=3 then front,back=11,7 end -- ears and crown
   if y>=7 and edge>5 then front,back=11,7 end -- separate arms
   if y>=11 and edge<5 then front,back=13,3 end -- rounded belly
   if y>=14 then front,back=14,4 end -- planted feet
   if y>=7 and y<=9 and edge<2 then front=14 end -- raised snout/horn
   local taper=math.max(0,math.floor((edge-3)/2))
   front,back=front-taper,back+taper
   local c=({[0]=1,[1]=2,[2]=3,[3]=5})[colors[y*16+x].c]
   for z=back,front do put(x-8,15+lift-y,z-8,z==front and c or 2)end
  end
 end end
 -- Connect the crown behind the original face, without a floating top voxel.
 box(-1,12+lift,-1,2,4,2,2)
 local paletteUV={sourceUV[0],sourceUV[1],sourceUV[2],sourceUV[0],sourceUV[3],sourceUV[1],sourceUV[1]}
 local D=V.require('Voxel3D');local out={}
 local dirs={{1,0,0},{-1,0,0},{0,1,0},{0,-1,0},{0,0,1},{0,0,-1}}
 local axes={{1,2,3},{1,2,3},{2,1,3},{2,1,3},{3,1,2},{3,1,2}}
 local groups={}
 for _,v in pairs(vox)do for f,d in ipairs(dirs)do
  if not vox[key(v[1]+d[1],v[2]+d[2],v[3]+d[3])]then
   local c=v[4]

   local ax=axes[f];local plane=v[ax[1]]+(f%2==1 and 1 or 0)
   local gk=f..':'..plane..':'..c
   local g=groups[gk]or {f=f,plane=plane,color=c,cells={}};groups[gk]=g
   g.cells[v[ax[2]]..','..v[ax[3]]]={v[ax[2]],v[ax[3]]}
  end
 end end
 -- Greedy coplanar rectangles preserve the silhouette and remove tiny flat faces.
 local gkeys={};for k in pairs(groups)do gkeys[#gkeys+1]=k end;table.sort(gkeys)
 for _,gk in ipairs(gkeys)do local g=groups[gk];local keys={}
  for k in pairs(g.cells)do keys[#keys+1]=k end;table.sort(keys)
  for _,k in ipairs(keys)do local cell=g.cells[k]
   if cell then
    local u,v=cell[1],cell[2];local w,h=1,1
    while g.cells[(u+w)..','..v]do w=w+1 end
    while true do local full=true;for j=0,w-1 do if not g.cells[(u+j)..','..(v+h)]then full=false;break end end;if not full then break end;h=h+1 end
    for y=v,v+h-1 do for x=u,u+w-1 do g.cells[x..','..y]=nil end end
    local ax=axes[g.f];local base,size={0,0,0},{0,0,0}
    base[ax[1]]=g.plane;base[ax[2]]=u;base[ax[3]]=v;size[ax[2]]=w;size[ax[3]]=h
    local q={};for _,c in ipairs(D.FACE_CORNERS[g.f])do
     q[#q+1]={(base[1]+c[1]*size[1])*unit+8,(base[2]+c[2]*size[2])*unit,(base[3]+c[3]*size[3])*unit+8,paletteUV[g.color][1],paletteUV[g.color][2],D.FACE_SHADE[g.f]}
    end
    out[#out+1]=q
   end
  end
 end
 if cfg.plinth then
  -- Keep the original 16px pedestal and front plaque, not a repeated figure.
  local function uv(tile,px,py)return {(tile%perRow*8+px+.5)/iw,(math.floor(tile/perRow)*8+py+.5)/ih}end
  local side=sourceUV[1]
  for _,tile in ipairs(cfg.base)do
   local found=false
   for yy=0,7 do for xx=0,7 do
    local rr,gg,bb=data:getPixel(tile%perRow*8+xx,math.floor(tile/perRow)*8+yy)
    if math.floor((rr+gg+bb)/3*3+.5)==1 then side=uv(tile,xx,yy);found=true;break end
   end;if found then break end end
   if found then break end
  end
  local dark=sourceUV[0]
  local function solid(x,y,z,w,h,d,tex)
   for f,corners in ipairs(D.FACE_CORNERS)do
    local q={};for _,c in ipairs(corners)do q[#q+1]={x+c[1]*w,y+c[2]*h,z+c[3]*d,tex[1],tex[2],D.FACE_SHADE[f]}end;out[#out+1]=q
   end
  end
  local function bevel(y0,y1,in0,in1,tex)
   local low={{in0,y0,in0},{16-in0,y0,in0},{16-in0,y0,16-in0},{in0,y0,16-in0}}
   local high={{in1,y1,in1},{16-in1,y1,in1},{16-in1,y1,16-in1},{in1,y1,16-in1}}
   for i=1,4 do local j=i%4+1;local q={};for _,p in ipairs({low[j],low[i],high[i],high[j]})do q[#q+1]={p[1],p[2],p[3],tex[1],tex[2],.82}end;out[#out+1]=q end
  end
  -- Full-width foot and cap retain the exact old height and footprint.
  solid(0,0,0,16,1,16,dark)
  bevel(1,2,0,1,side)
  solid(1,2,1,14,.6,14,dark)
  solid(2,2.6,2,12,10.4,12,side)
  for _,x in ipairs({1,13})do for _,z in ipairs({1,13})do solid(x,2.6,z,2,10.4,2,side)end end
  -- Dark recessed panel borders on the two sides and rear, no repeated face art.
  for _,x in ipairs({1.65,13.95})do
   solid(x,4,3.5,.4,.45,9,dark);solid(x,11.4,3.5,.4,.45,9,dark)
   solid(x,4,3.5,.4,7.8,.45,dark);solid(x,4,12,.4,7.8,.45,dark)
  end
  solid(3.5,4,1.65,9,.45,.4,dark);solid(3.5,11.4,1.65,9,.45,.4,dark)
  solid(3.5,4,1.65,.45,7.8,.4,dark);solid(12,4,1.65,.45,7.8,.4,dark)
  solid(1,13,1,14,.7,14,dark)
  bevel(13.7,15,1,0,side)
  solid(0,15,0,16,.55,16,dark)
  solid(.35,15.55,.35,15.3,.45,15.3,side)
  -- Original four-tile front is inset as one panel within the stone frame.
  for i,tile in ipairs(cfg.base)do
   local x=2+((i-1)%2)*6;local y=3+5-math.floor((i-1)/2)*5
   local u0=(tile%perRow*8)/iw;local v0=math.floor(tile/perRow)*8/ih
   local u1=u0+8/iw;local v1=v0+8/ih
   out[#out+1]={{x,y,14.02,u0,v1,.9},{x+6,y,14.02,u1,v1,.9},{x+6,y+5,14.02,u1,v0,.9},{x,y+5,14.02,u0,v0,.9}}
  end
 end
 templates[kind]=out;return out
end
local function prepare(map)
 if not(map and map.tileset and configs[map.tileset.id]and configs[map.tileset.id].maps[map.id])then return end
 if cache[map.id]then return cache[map.id]end
 local ps=M.placements(map);if #ps==0 then return end
 local ok,record=pcall(function()
  sourceData=assert(require("src.render.Assets").imageData(map.tileset.image))
  local verts,indices={},{}
  for _,p in ipairs(ps)do for _,q in ipairs(M.template(p.kind))do local b=#verts
   for _,v in ipairs(q)do verts[#verts+1]={(p.turn and 16-v[1]or v[1])+p.x,v[2]+p.height,(p.turn and 16-v[3]or v[3])+p.z,v[4],v[5],v[6]}end
   for _,i in ipairs({1,2,3,1,3,4})do indices[#indices+1]=b+i end
  end end
  local mesh=assert(V.require('Voxel3D').newMesh(verts,indices))
  return {mesh=mesh,placements=ps,vertices=#verts}
 end)
 if ok then cache[map.id]=record;return record end
 -- Leave the original tile art intact if this platform cannot create the mesh.
 return nil
end
function M.build(S,map)
 local r=prepare(map);if not r then return 0 end
 for _,p in ipairs(r.placements)do for y=p.ty,p.ty+p.rows-1 do for x=p.tx,p.tx+1 do
  local k=(y+64)*4096+x+64
  if p.tabletop then
   S.tileAt[k]=64;S.shapeAt[k]={class='counter',h=8,art='upright',authored=true}
  else S.skip[k]=true;S.ground[k]=false;S.shapeAt[k]={class='ground',h=0,art='flat',flat=true,authored=true}end
 end end end
 return #r.placements
end
function M.draw(map,ox,oz,shadow,atlas)
 local r=prepare(map);if not r then return end
 local model=(ox~=0 or oz~=0)and V.require('Mat4').translate(ox,0,oz)or nil
 local texture=atlas or (map.renderer and map.renderer.image)
 if not texture then return end
 if shadow then shadow.draw(r.mesh,texture,model)else V.require('Voxel3D').draw(r.mesh,texture,model)end
end
function M.setLive(live)
 for id,r in pairs(cache)do if not live[id]then r.mesh:release();cache[id]=nil end end
end
function M.invalidate()M.setLive({})end
function M.diagnostics(map)local r=prepare(map);return r and {count=#r.placements,vertices=r.vertices}or {count=0,vertices=0}end
return M
