-- One continuous disc material for flat/VR sky and the water reflection.
local M={revision='legendary-celestial-131'}
M.surface=[[
float lunarHash(vec2 p){return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453);}
float lunarGrain(vec2 p){
 vec2 i=floor(p),f=fract(p);f=f*f*(3.0-2.0*f);
 return mix(mix(lunarHash(i),lunarHash(i+vec2(1,0)),f.x),mix(lunarHash(i+vec2(0,1)),lunarHash(i+vec2(1)),f.x),f.y);
}
float lunarCrater(vec2 q,vec2 c,float r){
 float d=length(q-c)/r;
 return -.048*exp(-d*d*3.0)+.018*exp(-pow((d-.86)*7.0,2.0));
}
vec3 celestialSurface(vec2 q,float moon,vec3 core,vec3 main,vec3 dark){
 float d=length(q),z=sqrt(max(0.0,1.0-d*d));
 if(moon<.5){return mix(main,core,.38+.62*z);}
 float maria=lunarGrain(q*4.5+8.0)*.7+lunarGrain(q*10.0+1.5)*.3;
 float cr=0.0;
 cr+=lunarCrater(q,vec2(-.40,-.20),.20);
 cr+=lunarCrater(q,vec2(.20,.45),.14);
 cr+=lunarCrater(q,vec2(.50,-.40),.11);
 cr+=lunarCrater(q,vec2(-.15,.70),.09);
 cr+=lunarCrater(q,vec2(.05,.05),.20);
 vec3 c=mix(main,core,.24+.42*z);
 c=mix(c,dark,maria*.17);
 float light=.87+.13*z+.055*q.x-.035*q.y;
 return c*light+vec3(cr+(lunarGrain(q*80.0)-.5)*.018);
}
]]
M.source=M.surface..[[
extern vec3 coreColor;extern vec3 mainColor;extern vec3 darkColor;
extern float isMoon;extern float discExtent;
extern vec2 canvasSize;
vec4 effect(vec4 color,Image tex,vec2 uv,vec2 px){
 uv=px/canvasSize;
 vec2 q=(uv-.5)*discExtent;float d=length(q);
 float edge=1.0-smoothstep(.993,1.008,d);
 float halo=exp(-max(0.0,d-1.0)*18.0)*.10*(1.0-smoothstep(1.10,1.29,d));
 vec3 c=celestialSurface(q,isMoon,coreColor,mainColor,darkColor);
 return vec4(mix(coreColor,c,edge),max(edge,halo))*color;
}
]]
local cache={};local order={};local failed=false
function M.image(moon,twilight,shades,worldDisc)
 if failed then return nil end
 local key=(moon and'm'or's')..(twilight and't'or'd')..(worldDisc and'w'or'f')
 for i=1,3 do key=key..':'..table.concat(shades[i],',')end
 if cache[key]then return cache[key]end
 local g=love.graphics;local sh,canvas,pushed
 local ok=pcall(function()
  -- TEST131: match physical fragment coordinates to canvasSize on high DPI.
  sh=g.newShader(M.source);canvas=g.newCanvas(256,256,{dpiscale=1})
  g.push('all');pushed=true;g.origin();g.setCanvas(canvas)
  g.setScissor();g.setDepthMode();g.clear(0,0,0,0)
  g.setBlendMode('replace');g.setShader(sh);g.setColor(1,1,1,1)
  local function col(i)local c=shades[i];return{c[1]/255,c[2]/255,c[3]/255}end
  sh:send('discExtent',worldDisc and(19/9)or 2.6);sh:send('canvasSize',{256,256});sh:send('coreColor',col(1));sh:send('mainColor',col(twilight and 3 or 2));sh:send('darkColor',col(3));sh:send('isMoon',moon and 1 or 0)
  g.rectangle('fill',0,0,256,256)
 end)
 if pushed then g.pop()end
 if sh and sh.release then sh:release()end
 if not ok then if canvas then canvas:release()end;failed=true;return nil end
 canvas:setFilter('linear','linear');cache[key]=canvas;order[#order+1]=key
 -- Palette transforms may change. Bound resource lifetime even under cycling.
 if #order>4 then local old=table.remove(order,1);cache[old]:release();cache[old]=nil end
 return canvas
end
function M.invalidate()
 for _,img in pairs(cache)do img:release()end;cache={};order={};failed=false
end
return M
