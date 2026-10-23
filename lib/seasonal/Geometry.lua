-- Original procedural meshes. Coordinates use Battle Art's world units.
local M={FORMAT={{'VertexPosition','float',3},{'VertexTexCoord','float',2},{'VertexShade','float',1}}}
M.materials={
 {'pine',.035,.19,.105,'pine'},{'pineLight',.075,.31,.16,'pine'},{'pineDark',.024,.10,.065,'pine'},
 {'bark',.27,.12,.065,'wood'},{'wood',.48,.25,.10,'wood'},{'gold',.96,.68,.19,'metal'},
 {'red',.64,.025,.055,'cloth'},{'ivory',.95,.90,.72,'cloth'},{'blue',.035,.27,.66,'metal'},
 {'silver',.69,.79,.88,'metal'},{'purple',.36,.10,.60,'cloth'},{'pink',.96,.40,.62,'cloth'},
 {'green',.08,.46,.22,'cloth'},{'orange',.91,.27,.035,'pumpkin'},{'hay',.76,.53,.20,'straw'},
 {'rope',.36,.22,.085,'wood'},{'black',.025,.032,.045,'plain'},{'snow',.93,.975,1,'snow'},
 {'warm',1,.72,.27,'plain'},{'white',1,1,1,'plain'},{'cyan',.23,.85,1,'plain'},
 {'mint',.32,.76,.52,'cloth'},{'lilac',.65,.44,.85,'cloth'},{'egg',.99,.86,.48,'plain'},
 {'copper',.64,.29,.10,'metal'},{'coal',.07,.055,.045,'plain'},{'glass',1,.61,.14,'plain'},
 {'crimson',.29,.015,.05,'cloth'},{'teal',.025,.48,.48,'metal'},{'cream',.91,.79,.54,'plain'},
 {'soil',.20,.115,.055,'plain'},{'web',.79,.82,.88,'plain'},
 {'snowflake',.91,.965,1,'snowflake'},
 {'packedSnow',.91,.945,.97,'packedSnow'},{'powderSnow',.96,.98,1,'powderSnow'},
 {'footprint',.27,.34,.43,'trail'},{'footprintRim',.94,.975,1,'trailRim'},
 -- TEST26 seasonal additions.
 {'stone',.47,.48,.52,'stone'},{'mossStone',.33,.38,.31,'stone'},{'ghost',.90,.93,1,'cloth'},
 {'slime',.42,.98,.30,'plain'},{'iron',.13,.13,.15,'metal'},{'candle',.97,.93,.80,'plain'},
 {'leafRed',.72,.11,.05,'leaf'},{'leafOrange',.90,.42,.06,'leaf'},{'leafGold',.93,.71,.14,'leaf'},
 {'husk',.80,.69,.42,'straw'},{'apple',.70,.05,.07,'plain'},{'gourd',.86,.80,.28,'pumpkin'},
 {'violetGlow',.70,.36,1,'plain'},{'spirit',.55,.95,1,'plain'},{'deadwood',.17,.12,.10,'wood'},
 {'frostGlow',.80,.93,1,'plain'},{'graveDirt',.40,.34,.27,'stone'},
 {'spiderFur',.115,.079,.055,'spider'},{'spiderShell',.075,.052,.038,'spider'}
}
local index={};for i,m in ipairs(M.materials)do index[m[1]]=i-1 end
local tile=64;local columns=8;local atlasW,atlasH=columns*tile,math.ceil(#M.materials/columns)*tile
-- First two tiles are exposed pine; pineDark remains green underneath.
M.snowPineRegion={2/columns,tile/atlasH}
function M.uv(mat,u,v)
 local n=assert(index[mat],mat);return ((n%columns)*tile+1+(u or .5)*(tile-2))/atlasW,(math.floor(n/columns)*tile+1+(v or .5)*(tile-2))/atlasH
end
-- One atlas for every map and neighbor. TEST25 generated a private copy per
-- loaded map (about 160k setPixel calls each); all runtimes now share it.
-- Built synchronously (no yield) so two map jobs can never race to create it;
-- it is generated once per session instead of once per loaded map.
-- LÖVE images are userdata: never store flags on them.
local shared
function M.texture()
 if not shared then shared=M.buildTexture()end
 return shared
end
function M.releaseTexture()
 local t=shared;shared=nil
 if t and t.release then pcall(t.release,t)end
end
function M.buildTexture()
 local d=love.image.newImageData(atlasW,atlasH)
 for n,m in ipairs(M.materials)do for y=0,tile-1 do for x=0,tile-1 do
  local noise=((x*53+y*97+(n*31))%101)/100-.5
  local f=1+noise*.06;local alpha=1
  if m[5]=='wood'then f=1+.10*math.sin(x*.60+math.sin(y*.13)*.65)+noise*.10
  elseif m[5]=='spider'then f=.84+.20*math.sin(y*.10+x*.025)^2+noise*.16+.10*math.cos(x*.18)*math.sin(y*.12)
  elseif m[5]=='straw'then f=.88+.19*math.sin(y*2.8+math.sin(x*.13))+.09*math.sin(y*7+x*.17)+noise*.13
  elseif m[5]=='pine'then f=.89+.15*math.sin(x*.7+y*1.9)+noise*.15
  elseif m[5]=='cloth'then f=.96+.032*((x+y)%2)+noise*.045
  elseif m[5]=='metal'then f=.91+.09*math.sin((x+y)*.049)+noise*.017
  elseif m[5]=='pumpkin'then f=.94+.065*math.cos(x*.42)+noise*.02
  elseif m[5]=='snow'then f=.94+noise*.05
  elseif m[5]=='stone'then f=.90+.10*M.hash(math.floor(x/3),math.floor(y/3),n)+noise*.06
  elseif m[5]=='leaf'then f=.86+.16*math.sin(x*.5+y*.3)+noise*.10
  elseif m[5]=='snowflake'then f=.92+.08*x/(tile-1);alpha=.64
  elseif m[5]=='trail' or m[5]=='trailRim'then f=1;alpha=(m[5]=='trail'and .48 or .24)*math.max(0,math.min(1,(x-1)/(tile-2)))
  elseif m[5]=='packedSnow' or m[5]=='powderSnow'then
   -- Quiet irregular grains. Strong repeating ripples alias into a fabric
   -- checker at the walking camera; broad variation belongs to world geometry.
   local grain=M.hash(x,y,513)-.5
   f=.98+grain*.023
   if m[5]=='packedSnow'then f=f-.014*M.hash(x,y,811)^8 end
  end
  d:setPixel(((n-1)%columns)*tile+x,math.floor((n-1)/columns)*tile+y,math.min(1,m[2]*f),math.min(1,m[3]*f),math.min(1,m[4]*f),alpha)
 end end end
 local t=love.graphics.newImage(d);d:release();t:setFilter('linear','linear');return t
end
function M.hash(a,b,c)local n=(a*73856093+b*19349663+(c or 0)*83492791)%104729;return ((n*n*37+n*17+23)%104729)/104729 end
function M.new()
 return {vertices={},lights=0,ornaments=0,props=0}
end
local function vertex(g,p,mat,u,v,shade)
 local s,t=M.uv(mat,u,v);g.vertices[#g.vertices+1]={p[1],p[2],p[3],s,t,shade}
end
M.checkpoint=function()end
function M.tri(g,a,b,c,mat,shade,uv)
 local ux,uy,uz=b[1]-a[1],b[2]-a[2],b[3]-a[3]
 local vx,vy,vz=c[1]-a[1],c[2]-a[2],c[3]-a[3]
 local nx,ny,nz=uy*vz-uz*vy,uz*vx-ux*vz,ux*vy-uy*vx
 local l=math.sqrt(nx*nx+ny*ny+nz*nz);if l<1e-8 then return end
 local light=.69+.26*math.max(0,(nx*.36+ny*.82+nz*.45)/l)
 local s=(shade and shade>64)and shade or (shade or 1)*light
 vertex(g,a,mat,uv and uv[1][1]or 0,uv and uv[1][2]or 0,s)
 vertex(g,b,mat,uv and uv[2][1]or 1,uv and uv[2][2]or 0,s)
 vertex(g,c,mat,uv and uv[3][1]or 1,uv and uv[3][2]or 1,s)
 if #g.vertices%3072==0 then M.checkpoint()end
end
function M.quad(g,a,b,c,d,mat,shade)
 M.tri(g,a,b,c,mat,shade,{{0,0},{1,0},{1,1}});M.tri(g,a,c,d,mat,shade,{{0,0},{1,1},{0,1}})
end
function M.box(g,x,y,z,w,h,d,mat,yaw)
 local co,si=math.cos(yaw or 0),math.sin(yaw or 0)
 local function p(a,b,c)return{x+a*co+c*si,y+b,z-a*si+c*co}end
 local a,b,c,e=p(-w/2,0,-d/2),p(w/2,0,-d/2),p(w/2,0,d/2),p(-w/2,0,d/2)
 local A,B,C,E=p(-w/2,h,-d/2),p(w/2,h,-d/2),p(w/2,h,d/2),p(-w/2,h,d/2)
 M.quad(g,A,E,C,B,mat);M.quad(g,e,c,C,E,mat);M.quad(g,b,a,A,B,mat);M.quad(g,a,e,E,A,mat);M.quad(g,c,b,B,C,mat);M.quad(g,a,b,c,e,mat)
end
-- Caps on thin tubes are sub-pixel at every Battle Art camera, and chained
-- tubes hide them inside the next segment. Auto mode keeps caps only on
-- visibly thick tubes; pass caps=true/false to force either way.
function M.tube(g,a,b,r,mat,n,r2,shade,caps)
 n=n or 8;r2=r2 or r
 if caps==nil then caps=math.max(r,r2)>=.45 end
 local dx,dy,dz=b[1]-a[1],b[2]-a[2],b[3]-a[3];local l=math.sqrt(dx*dx+dy*dy+dz*dz);if l<.00001 then return end
 dx,dy,dz=dx/l,dy/l,dz/l
 local ux,uy,uz=-dz,0,dx
 if math.abs(dy)>.95 then ux,uy,uz=1,0,0 end
 local ll=math.sqrt(ux*ux+uy*uy+uz*uz);ux,uy,uz=ux/ll,uy/ll,uz/ll
 local vx,vy,vz=dy*uz-dz*uy,dz*ux-dx*uz,dx*uy-dy*ux
 local function ring(p,rad,i)local co,si=math.cos(i*math.pi*2/n),math.sin(i*math.pi*2/n);return{p[1]+rad*(ux*co+vx*si),p[2]+rad*(uy*co+vy*si),p[3]+rad*(uz*co+vz*si)}end
 for i=0,n-1 do local p,q,R,S=ring(a,r,i),ring(a,r,i+1),ring(b,r2,i+1),ring(b,r2,i)
  M.quad(g,p,q,R,S,mat,shade)
  if caps then M.tri(g,a,q,p,mat,shade);M.tri(g,b,S,R,mat,shade)end
 end
end
function M.sphere(g,x,y,z,rx,ry,rz,mat,n,rings,shade,lobes)
 n=n or 12;rings=rings or 8
 local function p(i,j)
  local a,b=i*math.pi*2/n,-math.pi/2+j*math.pi/rings
  local wave=lobes and (1+.075*math.cos(a*lobes))or 1
  return{x+rx*math.cos(a)*math.cos(b)*wave,y+ry*math.sin(b),z+rz*math.sin(a)*math.cos(b)*wave}
 end
 for j=0,rings-1 do for i=0,n-1 do M.quad(g,p(i,j),p(i,j+1),p(i+1,j+1),p(i+1,j),mat,shade)end end
end
function M.disc(g,x,y,z,r,mat,n)
 for i=0,(n or 32)-1 do local a=i*math.pi*2/(n or 32);local b=(i+1)*math.pi*2/(n or 32)
  M.tri(g,{x,y,z},{x+r*math.cos(b),y,z+r*math.sin(b)},{x+r*math.cos(a),y,z+r*math.sin(a)},mat)
 end
end
function M.star(g,x,y,z,r,mat)
 for i=0,9 do local a=math.pi/2+i*math.pi/5;local b=a+math.pi/5
  local ra=i%2==0 and r or r*.44;local rb=i%2==0 and r*.44 or r
  local p={x+math.cos(a)*ra,y+math.sin(a)*ra,z};local q={x+math.cos(b)*rb,y+math.sin(b)*rb,z}
  M.tri(g,{x,y,z+r*.24},p,q,mat,65.3)
  M.tri(g,{x,y,z-r*.24},q,p,mat,65.1)
 end
end
-- Small bounded templates preserve every triangle while avoiding thousands of
-- repeated trigonometric/normal calculations. Each placement owns its rows.
local bulbs={}
function M.bulb(g,x,y,z,r,mat,twinkle)
 local key=mat..(twinkle and ':twinkle'or ':steady');local template=bulbs[key]
 if not template then
  template=M.new();M.sphere(template,0,0,0,1,1.35,1,mat,5,3,twinkle and 66 or 65.3)
  template.lights=1;bulbs[key]=template
 end
 M.instance(g,template,x,y,z,r)
end
function M.instance(out,source,x,y,z,scale)
 local vertices=out.vertices;local n=#vertices;scale=scale or 1
 for i,v in ipairs(source.vertices)do
  vertices[n+i]={x+v[1]*scale,y+v[2]*scale,z+v[3]*scale,v[4],v[5],v[6]}
  if i%2048==0 then M.checkpoint()end
 end
 out.lights=out.lights+(source.lights or 0);out.ornaments=out.ornaments+(source.ornaments or 0);out.props=out.props+(source.props or 0)
 M.checkpoint()
end
function M.transformInPlace(g,x,y,z,yaw,scale)
 local co,si=math.cos(yaw or 0),math.sin(yaw or 0);scale=scale or 1
 for i,v in ipairs(g.vertices)do
  local a,b,c=v[1],v[2],v[3]
  v[1],v[2],v[3]=x+(a*co+c*si)*scale,y+b*scale,z+(-a*si+c*co)*scale
  if i%2048==0 then M.checkpoint()end
 end
 return g
end
function M.translate(source,x,y,z,yaw,scale)
 local out=M.new();local co,si=math.cos(yaw or 0),math.sin(yaw or 0);scale=scale or 1
 for i,v in ipairs(source.vertices)do
  out.vertices[#out.vertices+1]={x+(v[1]*co+v[3]*si)*scale,y+v[2]*scale,z+(-v[1]*si+v[3]*co)*scale,v[4],v[5],v[6]}
  if i%4096==0 then M.checkpoint()end
 end
 out.lights,out.ornaments,out.props=source.lights,source.ornaments,source.props
 return out
end
function M.append(a,b)
 for i,v in ipairs(b.vertices)do a.vertices[#a.vertices+1]=v;if i%4096==0 then M.checkpoint()end end
 a.lights=a.lights+(b.lights or 0);a.ornaments=a.ornaments+(b.ornaments or 0);a.props=a.props+(b.props or 0)
end
return M
