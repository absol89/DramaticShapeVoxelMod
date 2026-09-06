-- Exact first-floor museum exhibits. Render geometry only; no map mutations.
local V=...
local M={}
local pattern={{39,40,40,40,40,40,40,25},{48,70,71,58,58,70,71,44},{49,60,83,63,60,60,60,44},{50,51,50,51,50,51,50,51}}
function M.placements(map)
 local out={};if not(map and map.id=='MUSEUM_1F' and map.tileset.id=='MUSEUM')then return out end
 for _,y in ipairs({4,10})do
  local match=true
  for z,row in ipairs(pattern)do for x,t in ipairs(row)do if map:tileAt(x+1,y+z-1)~=t then match=false end end end
  if match then out[#out+1]={x=16,z=(y+2)*8,kind=y==4 and 'kabutops' or 'aerodactyl',tileY=y} end
 end
 return out
end
local faces={{1,2,3,4},{5,8,7,6},{1,5,6,2},{4,3,7,8},{1,4,8,5},{2,6,7,3}}
local shades={.72,.86,.55,1,.78,.88}
local function box(out,x,y,z,w,h,d,uv,role)
 local p={{x,y,z},{x+w,y,z},{x+w,y+h,z},{x,y+h,z},{x,y,z+d},{x+w,y,z+d},{x+w,y+h,z+d},{x,y+h,z+d}}
 for f,ix in ipairs(faces)do out[#out+1]={p[ix[1]],p[ix[2]],p[ix[3]],p[ix[4]],uv={uv,uv,uv,uv},shade=shades[f],fossilRole=role}end
end
local function segment(out,a,b,r,uv)
 local n=math.max(1,math.ceil(math.max(math.abs(b[1]-a[1]),math.abs(b[2]-a[2]),math.abs(b[3]-a[3]))/1.2))
 for i=0,n do local t=i/n;box(out,a[1]+(b[1]-a[1])*t-r/2,a[2]+(b[2]-a[2])*t-r/2,a[3]+(b[3]-a[3])*t-r/2,r,r,r,uv,'bone')end
end
function M.geometry(p,uv)
 local out={};local x,z=p.x,p.z
 box(out,x,0,z,64,3,16,uv.dark,'base');box(out,x+1,3,z+1,62,1,14,uv.light,'bed')
 box(out,x,1,z+15.8,64,.6,.25,uv.middle,'trim');box(out,x+28,1,z+16.1,8,1.7,.3,uv.light,'plaque')
 for _,xx in ipairs({x,x+63})do for _,zz in ipairs({z,z+15})do box(out,xx,4,zz,1,28,1,uv.dark,'frame')end end
 for _,yy in ipairs({4,31})do
  box(out,x,yy,z,64,1,1,uv.dark,'frame');box(out,x,yy,z+15,64,1,1,uv.dark,'frame')
  box(out,x,yy,z,1,1,16,uv.dark,'frame');box(out,x+63,yy,z,1,1,16,uv.dark,'frame')
 end
 local cx,cz=x+32,z+8
 local function bone(a,b,r)
  segment(out,{cx+a[1],a[2],cz+a[3]},{cx+b[1],b[2],cz+b[3]},r or 1.1,uv.light)
 end
 local function rib(y,w)
  for _,s in ipairs({-1,1})do bone({0,y,-1},{s*w,y-1,1},.8);bone({s*w,y-1,1},{s*(w-1),y-2,3},.8)end
 end
 -- A discreet support keeps each articulated skeleton physically mounted.
 box(out,cx-.45,4,cz-2,.9,12,.9,uv.dark,'support')
 if p.kind=='kabutops' then
  bone({0,12,-1},{0,22,0},1.5)
  for y=15,21,2 do rib(y,4)end
  bone({-3,12,0},{3,12,0},1.5)
  for _,s in ipairs({-1,1})do
   bone({s*2,12,0},{s*5,8,1},1.6);bone({s*5,8,1},{s*4,5,3},1.3);bone({s*4,5,3},{s*7,5,5},1)
   bone({s*3,20,0},{s*8,18,1},1.3);bone({s*8,18,1},{s*11,15,2},1.2)
   -- Long curved scythe, narrowing toward its hooked tip.
   bone({s*11,15,2},{s*16,12,3},2);bone({s*16,12,3},{s*18,8,4},1.6);bone({s*18,8,4},{s*16,6,5},.8)
   bone({0,26,0},{s*7,25,0},2);bone({s*7,25,0},{s*10,27,-1},1.8)
   bone({s*7,25,0},{s*5,22,3},1.5);bone({s*5,22,3},{0,21,4},1.3)
  end
  bone({-4,24,3},{4,24,3},1.3);bone({0,23,3},{0,21,4},1.1)
  bone({0,12,-1},{7,10,-4},1.3);bone({7,10,-4},{13,7,-5},1)
 else
  bone({0,11,-1},{0,21,0},1.4)
  for y=13,19,2 do rib(y,3)end
  bone({0,21,0},{-2,25,0},1.2)
  -- Long toothed skull, jaw gap, rear horns.
  bone({-2,25,0},{-9,24,1},2);bone({-2,22.5,0},{-9,22,1},1)
  bone({-2,26,0},{-6,25.5,1},1.6)
  for xx=-8,-3,1.5 do bone({xx,24,1},{xx,23.2,1},.6)end
  for _,s in ipairs({-1,1})do
   bone({-1,25,s},{3,28,s*2},1)
   bone({s*2,19,0},{s*8,24,-1},1.3);bone({s*8,24,-1},{s*17,27,0},1.2);bone({s*17,27,0},{s*26,29,0},.8)
   for j=1,3 do bone({s*8,24,-1},{s*(12+j*4),19-j*3,1},.85)end
   bone({s*2,12,0},{s*5,9,1},1.1);bone({s*5,9,1},{s*4,6,3},1)
   for j=-1,1 do bone({s*4,6,3},{s*4+j*1.3,5,5},.7)end
  end
  bone({0,11,-1},{5,8,-4},1);bone({5,8,-4},{10,5,-5},.7)
 end
 return out
end
local function colors(data,perRow)
 local w,h=data:getDimensions();local lo,hi,mid=1e9,-1e9,nil;local dark,light
 for y=0,h-1 do for x=0,w-1 do local a,b,c=data:getPixel(x,y);local v=a+b+c
  if v<lo then lo=v;dark={(x+.5)/w,(y+.5)/h}end
  if v>hi then hi=v;light={(x+.5)/w,(y+.5)/h}end
  if not mid and v>1 and v<2 then mid={(x+.5)/w,(y+.5)/h}end
 end end
 return{dark=dark,light=light,middle=mid or light}
end
function M.build(S,map,data,perRow)
 local ps=M.placements(map);if #ps==0 or not data then return 0 end
 local uv=colors(data,perRow);local n=0
 for _,p in ipairs(ps)do
  for y=p.tileY,p.tileY+3 do for x=2,9 do local k=(y+64)*4096+x+64;S.skip[k]=true;S.ground[k]=false;S.shapeAt[k]={class='ground',h=0,art='flat',flat=true,authored=true}end end
  for _,q in ipairs(M.geometry(p,uv))do S.objectQuads[#S.objectQuads+1]=q;n=n+1 end
 end
 return n
end
local glassMesh,glassTexture
function M.drawGlass(map)
 local ps=M.placements(map);if #ps==0 then return end
 local g=love.graphics;local D=V.require('Voxel3D')
 if not glassMesh then
  local v,ix={},{}
  for _,p in ipairs(ps)do
   local x,z=p.x,p.z;local qs={{{x+1,5,z+.5},{x+63,5,z+.5},{x+63,31,z+.5},{x+1,31,z+.5}},{{x+1,5,z+15.5},{x+63,5,z+15.5},{x+63,31,z+15.5},{x+1,31,z+15.5}},{{x+.5,5,z+1},{x+.5,5,z+15},{x+.5,31,z+15},{x+.5,31,z+1}},{{x+63.5,5,z+1},{x+63.5,5,z+15},{x+63.5,31,z+15},{x+63.5,31,z+1}},{{x+1,31.5,z+1},{x+63,31.5,z+1},{x+63,31.5,z+15},{x+1,31.5,z+15}}}
   for _,q in ipairs(qs)do local b=#v;for _,c in ipairs(q)do v[#v+1]={c[1],c[2],c[3],.5,.5,1}end;for _,j in ipairs({1,2,3,1,3,4})do ix[#ix+1]=b+j end end
  end
  glassMesh=D.newMesh(v,ix);local data=love.image.newImageData(1,1);data:setPixel(0,0,1,1,1,1);glassTexture=g.newImage(data);data:release()
 end
 g.push('all');g.setBlendMode('alpha','alphamultiply');g.setDepthMode('lequal',false);g.setColor(.7,.85,1,.07);D.draw(glassMesh,glassTexture);g.pop()
end
return M
