-- TEST132: four detailed 90-degree sectors in one 4096x1024 atlas.
-- Same pixel budget and one horizon draw; raw source assets stay unmodified.
local V=...
local M={revision='legendary-landscape-134',panoramaStatus='atlas not attempted'}
local panorama,meadow
local tried={}
local WIDTH,HEIGHT,PAD=4096,1024,4
-- Inset every sector into its own padded tile. Do not sample across atlas rows.
function M.uv(sector,u,v)
 local col,row=sector%2,math.floor(sector/2)
 return (col*2048+PAD+u*(2048-2*PAD))/WIDTH,
        (row*512+PAD+v*(512-2*PAD))/HEIGHT
end
M.source=[[
extern number artwork;
extern Image artworkTexture;
extern Image meadowTexture;
extern Image horizon1;extern Image horizon2;extern Image horizon3;
extern vec2 canvasSize;
vec4 sectorTex(float s,vec2 uv){
 if(s<.5)return Texel(artworkTexture,uv);
 if(s<1.5)return Texel(horizon1,uv);
 if(s<2.5)return Texel(horizon2,uv);
 return Texel(horizon3,uv);
}
vec2 edgeHeights(float sector){
 // Authored edge silhouette heights in the cropped sector; source PNGs exact.
 if(sector<.5)return vec2(.44364337,.63526805);
 if(sector<1.5)return vec2(.34081112,.47134357);
 if(sector<2.5)return vec2(.43112136,.42960355);
 return vec2(.54192217,.44743792);
}
vec4 horizon(float sector,vec2 uv){
 // Join different ridge heights with a local vertical warp, anchored at ground.
 // A pure alpha crossfade would leave a vertical step when the scene clips it.
 vec2 edges=edgeHeights(sector);
 vec2 join=.5*(edges+vec2(edgeHeights(mod(sector+3.0,4.0)).y,
                         edgeHeights(mod(sector+1.0,4.0)).x));
 vec2 influence=1.0-smoothstep(vec2(0.0),vec2(.14),vec2(uv.x,1.0-uv.x));
 float shift=dot((edges-join)/(1.0-join),influence);
 uv.y+=shift*(1.0-uv.y);
 // Preserve complete peaks; per-sector framing uses the full authored height.
 vec4 c=sectorTex(sector,vec2(uv.x,.04+uv.y*.91));
 bool blue=c.b>.75&&c.r<.12&&c.g<.20;
 bool red=c.r>.65&&c.g<.16&&c.b<.16;
 bool green=c.g>.65&&c.r<.18&&c.b<.18;
 if(blue||red||green)c.a=0.0;
 return c;
}
// TEST134: a continuous meadow material for the floor and the lower painting.
// Periodic, low-contrast patches survive distant filtering without square beds.
vec3 meadowColor(vec2 uv){
 uv=fract(uv);
 vec2 other=vec2(1.0)-uv;
 float ex=(1.0-smoothstep(0.0,.025,min(uv.x,1.0-uv.x)))*.5;
 float ey=(1.0-smoothstep(0.0,.025,min(uv.y,1.0-uv.y)))*.5;
 vec3 a=mix(Texel(meadowTexture,uv).rgb,Texel(meadowTexture,vec2(other.x,uv.y)).rgb,ex);
 vec3 b=mix(Texel(meadowTexture,vec2(uv.x,other.y)).rgb,Texel(meadowTexture,other).rgb,ex);
 vec3 grass=mix(mix(a,b,ey),vec3(.28,.37,.20),.28);
 vec2 phase=uv*6.28318530718;
 float patches=.55*sin(phase.x+.72*sin(phase.y))
              +.30*cos(phase.y*2.0+.6*cos(phase.x))
              +.15*sin(phase.x*2.0-phase.y);
 return grass+vec3(.025,.032,.018)*patches;
}
vec4 effect(vec4 color,Image tex,vec2 unused,vec2 px){
 vec2 uv=px/canvasSize;
 if(artwork>.5){
  return vec4(meadowColor(uv),1.0);
 }
 vec2 tile=floor(uv*2.0);
 float sector=tile.x+tile.y*2.0;
 vec2 tileSize=canvasSize*.5;
 uv=clamp((px-tile*tileSize-vec2(4.0))/(tileSize-vec2(8.0)),0.0,1.0);
 vec4 c=horizon(sector,uv);
 // Average a narrow band with the adjacent sector at each join. Both sides
 // approach the same color and silhouette; premultiplication avoids fringes.
 float nearLeft=1.0-step(.5,uv.x);
 float seam=(1.0-smoothstep(0.0,.035,min(uv.x,1.0-uv.x)))*.5;
 float neighbor=mod(sector+mix(1.0,3.0,nearLeft),4.0);
 vec4 opposite=horizon(neighbor,vec2(1.0-uv.x,uv.y));
 float alpha=mix(c.a,opposite.a,seam);
 vec3 rgb=mix(c.rgb*c.a,opposite.rgb*opposite.a,seam)/max(alpha,.0001);
 // Keep mountains, tree crowns and their alpha silhouette exactly as approved.
 // Work only in the lower meadow. An irregular leading edge removes the ruler-
 // straight color band; scale increases toward the ground for readable depth.
 float angle=(sector+uv.x)*1.57079632679;
 float edge=.835+.012*sin(angle*7.0)+.007*cos(angle*11.0);
 vec2 groundUV=vec2(cos(angle),sin(angle))*(760.0+(1.0-uv.y)*420.0)/128.0;
 vec3 grass=meadowColor(groundUV);
 // The last few texels meet the floor's average tone, so the regional yaw
 // cannot expose a hard texture cut at the cylinder's foot.
 grass=mix(grass,vec3(.252,.379,.166),smoothstep(.982,1.0,uv.y));
 rgb=mix(rgb,grass,smoothstep(edge,.995,uv.y));
 return vec4(rgb,alpha);
}
]]
local function bake(width,height,kind)
 local g=love.graphics
 local sh,canvas,pushed
 local sources={}
 local ok,err=pcall(function()
  sh=g.newShader(M.source)
  local base=(V.path or 'mods/BATTLE_ART_VOXEL_FORK')..'/assets/legendary/'
  local names=kind==1 and{'meadow-130.png'}or{
   'horizon-132-west.png','horizon-132-town-west.png',
   'horizon-132-town-east.png','horizon-132-east.png'}
  for i,name in ipairs(names)do
   local img=g.newImage(base..name);sources[i]=img;img:setFilter('linear','linear')
  end
  if kind~=1 then
   local img=g.newImage(base..'meadow-130.png');sources[5]=img
   img:setFilter('linear','linear')
  end
  sh:send('meadowTexture',sources[5]or sources[1])
  for i,name in ipairs({'artworkTexture','horizon1','horizon2','horizon3'})do
   sh:send(name,sources[i]or sources[1])
  end
  -- Keep TEST131's physical-pixel rule on every allocation route.
  if kind==1 then
   local made,c=pcall(g.newCanvas,width,height,{mipmaps='auto',dpiscale=1})
   canvas=made and c or g.newCanvas(width,height,{dpiscale=1})
  else
   -- A directional atlas must not blur unrelated sectors together in mipmaps.
   canvas=g.newCanvas(width,height,{dpiscale=1})
  end
  g.push('all');pushed=true;g.origin();g.setCanvas(canvas)
  g.setDepthMode();g.setScissor();g.clear(0,0,0,0)
  g.setBlendMode('replace');g.setShader(sh);g.setColor(1,1,1,1)
  sh:send('canvasSize',{width,height});sh:send('artwork',kind)
  g.rectangle('fill',0,0,width,height)
 end)
 if pushed then g.pop()end
 if sh and sh.release then sh:release()end
 for _,source in ipairs(sources)do if source.release then source:release()end end
 if not ok then if canvas and canvas.release then canvas:release()end;return nil,err end
 canvas:setFilter('linear','linear')
 if kind==1 then
  -- Preserve grass detail at grazing angles without changing global filtering.
  -- Older/limited renderers retain the working linear-filtered material.
  pcall(canvas.setFilter,canvas,'linear','linear',4)
  pcall(canvas.setMipmapFilter,canvas,'linear');canvas:setWrap('repeat','repeat')
 else canvas:setWrap('clamp','clamp')end
 return canvas
end
function M.panorama()
 if tried.panorama then return panorama end
 tried.panorama=true
 local err
 panorama,err=M.bake(WIDTH,HEIGHT,0)
 M.panoramaStatus=panorama and 'four-sector atlas 4096x1024; TEST134 meadow (TEST132 peaks)'
   or ('atlas unavailable: '..tostring(err))
 return panorama
end
function M.meadow()
 if not tried.meadow then tried.meadow=true;meadow=M.bake(1024,1024,1)end
 return meadow
end
function M.invalidate()
 for _,t in pairs({panorama,meadow})do if t and t.release then t:release()end end
 panorama,meadow=nil,nil;tried={};M.panoramaStatus="atlas not attempted"
end
M.bake=bake
return M
