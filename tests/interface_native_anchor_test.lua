-- Exercise the production fitter with synthetic padded animation pixels.
local f = assert(io.open("lib/BattleArt.lua", "r"))
local source = f:read("*a"); f:close()
local body = assert(source:match("(function BattleArt.fitPreparedFrames.-)\n%-%- Animated transforms"))
local function data(w,h)
  local d = {w=w,h=h,p={}}
  function d:getDimensions() return self.w,self.h end
  function d:getPixel(x,y) return 1,0,0,self.p[y*self.w+x] or 0 end
  function d:setPixel(x,y,r,g,b,a) self.p[y*self.w+x]=a end
  function d:setFilter() end
  return d
end
local env = setmetatable({BattleArt={},metrics={},preparedData={},external={},
  fittedFrameSets=setmetatable({}, {__mode="k"}),
  love={image={newImageData=data},graphics={newImage=function(d) return d end}}},
  {__index=_G})
local chunk=assert(loadstring(body));setfenv(chunk,env);chunk()
local frames={data(80,80),data(80,80)}
for i,img in ipairs(frames) do
  for y=25+i,64+i do for x=20,49 do img:setPixel(x,y,1,0,0,1) end end
  env.metrics[img]={x0=20,x1=49,y0=25+i,y1=64+i}
  env.preparedData[img]=img
end
local native=env.BattleArt.fitPreparedFrames(frames,56,56,true)
assert(native[1].w==56 and native[1].h==56)
assert(env.metrics[native[1]].y0==0 and env.metrics[native[2]].y0==1,
  "shared crop removes top padding while retaining animation movement")
for i,img in ipairs(native) do
  local count=0
  for _,a in pairs(img.p) do if a>0 then count=count+1 end end
  assert(count==1200,"FULL preserves every visible pixel")
end
local fit=env.BattleArt.fitPreparedFrames(frames,56,56)
assert(env.metrics[fit[2]].y1==55,"FIT retains bottom alignment")
assert(fit~=native,"native and fitted caches remain independent")
assert(env.BattleArt.fitPreparedFrames(frames,56,56,true)==native)
print("Native anchor checks passed")
