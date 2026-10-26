-- ROM/GPU-free combined PR62 + recognized-back alpha regression.
local checks=0
local function check(v,m)checks=checks+1;assert(v,m)end
local function data(w,h)
 local D={w=w,h=h,p={}}
 for i=1,w*h do D.p[i]={1,1,1,0}end
 function D:getDimensions()return self.w,self.h end
 function D:getPixel(x,y)return unpack(self.p[y*self.w+x+1])end
 function D:setPixel(x,y,...)self.p[y*self.w+x+1]={...}end
 function D:clone()local d=data(self.w,self.h);for i,p in ipairs(self.p)do d.p[i]={unpack(p)}end;return d end
 function D:release()end
 return D
end
local hints={byFingerprint={}}
love={data={hash=function(_,s)return s end,encode=function(_,_,s)return s end}}
local V={data=function(n)check(n=='rom_back_alpha_hints','correct hints data');return hints end}
local Rom=assert(loadfile('lib/RomBackAlpha.lua'))(V)
V.require=function(n)check(n=='RomBackAlpha','correct module');return Rom end
local raw=data(32,32)
for x=1,4 do local v=(x-1)/3;raw:setPixel(x,1,v,v,v,1)end
for y=8,12 do for x=8,12 do if x==8 or x==12 or y==8 or y==12 then raw:setPixel(x,y,0,0,0,1)end end end
local fp=assert(Rom.fingerprint(raw))
local mask={width=32,height=32,crop=28,remove={{36,1}},add={{198,1},{330,1}}}
hints.byFingerprint[fp]=mask
check(Rom.identify(raw)==mask,'recognized canonical source')
local tinted=raw:clone()
for y=0,31 do for x=0,31 do local r,g,b,a=raw:getPixel(x,y);if a==1 then tinted:setPixel(x,y,.6+.3*r,.2+.5*g,.1+.2*b,a)end end end
check(Rom.identify(tinted)==mask,'monotonic palette does not change identity')
local inverted=raw:clone()
for y=0,31 do for x=0,31 do local r,g,b,a=raw:getPixel(x,y);inverted:setPixel(x,y,1-r,1-g,1-b,a)end end
check(Rom.identify(inverted)==mask,'inverted palette does not change identity')
local wrong=raw:clone();wrong:setPixel(20,20,0,0,0,1)
check(Rom.identify(wrong)==nil,'changed provider art rejected')
local tagged=raw:clone();tagged:setPixel(10,10,1,1,1,1/255)
check(Rom.identify(tagged)==nil,'PR62-tagged source is not recognized as ROM')
check(Rom.identify(data(56,56))==nil,'large authored art rejected')
local many=raw:clone();many:setPixel(20,20,.13,.17,.23,1)
check(Rom.identify(many)==nil,'extra art colors rejected')
local G={};love.graphics=G
local canvas,blend,alpha=nil,'alpha','alphamultiply'
local color={1,1,1,1};local reads,allocations=0,0
function G.newCanvas(w,h) return {d=data(w,h),newImageData=function(self)reads=reads+1;return self.d:clone()end,release=function()end}end
function G.getCanvas()return canvas end
function G.setCanvas(c)canvas=c end
function G.getBlendMode()return blend,alpha end
function G.setBlendMode(b,a)blend,alpha=b,a end
function G.getColor()return unpack(color)end
function G.setColor(...)color={...}end
function G.clear()end
function G.draw(img)canvas.d=img.d:clone()end
function G.newImage(d)allocations=allocations+1;return {d=d:clone(),getDimensions=function(self)return self.d:getDimensions()end,setFilter=function()end}end
local BP=assert(loadfile('lib/BattlePics.lua'))(V)
local image=G.newImage(raw)
local plain=BP.filled(image,true)
check(select(4,plain.d:getPixel(4,1))==1,'legacy path retains original white')
check(select(4,plain.d:getPixel(6,6))==0,'legacy path leaves unfilled background')
local fixed=BP.filled(image,true,image)
check(select(4,fixed.d:getPixel(4,1))==0,'reference clears original-white gap')
check(select(4,fixed.d:getPixel(6,6))==1,'reference restores missed body paint')
check(select(4,image.d:getPixel(4,1))==1,'source image is not mutated')
check(BP.filled(image,true)==plain,'cache separates fallback from ROM correction')
local nr=reads
check(BP.filled(image,true,image)==fixed and reads==nr,'source identity and corrected output cached')
local altered=G.newImage(wrong)
check(BP.filled(image,true,altered)==plain,'unmatched source retains original fill')
local taggedImage=G.newImage(tagged)
local tagOut=BP.filled(taggedImage,true,image)
check(select(4,tagOut.d:getPixel(10,10))==1/255,'PR62 tag wins over reference ADD')
check(select(4,tagOut.d:getPixel(4,1))==0,'reference removal still works alongside tag')
check(select(4,tagOut.d:getPixel(9,10))==1,'untagged enclosed paint is restored')
local black=raw:clone()
for _,p in ipairs(black.p)do p[1],p[2],p[3]=0,0,0 end
local blackOut=BP.filled(G.newImage(black),true,image)
local r,g,b,a=blackOut.d:getPixel(6,6)
check(r==0 and g==0 and b==0 and a==1,'black fade restores black, never white')
check(select(4,blackOut.d:getPixel(4,1))==0,'fade retains corrected silhouette')
local colorOut=BP.filled(G.newImage(tinted),true,image)
local R,Gc,B,A=colorOut.d:getPixel(6,6)
check(math.abs(R-.9)<1e-6 and math.abs(Gc-.7)<1e-6 and math.abs(B-.3)<1e-6 and A==1,'restored paint follows baked palette')
check(canvas==nil and blend=='alpha' and alpha=='alphamultiply','graphics target and blend restored')
BP.invalidate()
check(BP.filled(image,true,image)~=fixed,'invalidation drops output and identity cache')
print(('PASS combined ROM alpha + PR62: %d checks'):format(checks))
