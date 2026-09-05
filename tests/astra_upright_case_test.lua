-- ROM-free regression: casing is opt-in and never erases a recessed display.
local root=os.getenv('ASTRA_COMPUTER_ROOT') or os.getenv('ASTRA_CANDIDATE') or '.'
local baseline=assert(os.getenv('ASTRA_COMPUTER_BASELINE'))
local H=dofile('tests/astra_fixture.lua')
local checks=0
local function ok(v,msg)checks=checks+1;if not v then error('FAIL '..msg,0)end end
local function eq(a,b,msg)ok(a==b,msg..' (expected '..tostring(b)..', got '..tostring(a)..')')end
local function same(a,b,msg)
 eq(type(a),type(b),msg..' type')
 if type(a)~='table'then eq(a,b,msg);return end
 for k,v in pairs(a)do same(v,b[k],msg..'.'..tostring(k))end
 for k in pairs(b)do ok(a[k]~=nil,msg..' no extra '..tostring(k))end
end
local function builder(path)
 local B=assert(loadfile(path..'/lib/Buildings.lua'))({
  require=function(n)
   if n=='BuildBudget'then return{tick=function()end}end
   return assert(loadfile(path..'/lib/'..n..'.lua'))()
  end,data=function()return{}end})
 return H.upvalue(B.build,'model'),H.upvalue(B.build,'emit')
end
local make,emit=builder(root);local oldMake,oldEmit=builder(baseline)
local W,D=8,8
local sp={W=W,H=16,col={},inside={},ax={},ay={}}
for y=0,15 do for x=0,W-1 do
 local i=y*W+x;sp.col[i]=(x+y)%4;sp.inside[i]=true;sp.ax[i]=x;sp.ay[i]=y
end end
-- A narrowed row exercises exposed sides inside the nominal part bounds.
sp.inside[6*W+1]=nil;sp.inside[6*W+6]=nil
local pr={D=D,ground=16,shadeTexel={[0]=0,[1]=1,[2]=2,[3]=3},recess={[4*W+3]=true,[4*W+4]=true}}
local function profile(casing)
 return{desk={fascia={14,14},base={15,15}},parts={
  {kind='upright',x={1,6},top={0,1},facade={2,7},z=1,depth=4,
   inset={x={2,2},rows={5,5}},case=casing and{sample={2,0}}or nil},
  {kind='flat',x={7,7},rows={8,10},z=4}}}
end
local old=oldMake(sp,pr,profile(false));local plain=make(sp,pr,profile(false))
same(emit(plain,sp,8,16),oldEmit(old,sp,8,16),'no opt-in preserves complete legacy quads/UVs/shades')
local m=make(sp,pr,profile(true));local changes=0
for y=0,math.max(m.ytop,old.ytop)do for z=0,D-1 do for x=0,W-1 do
 local a,b=m.at(x,y,z),old.at(x,y,z)
 eq(a~=nil,b~=nil,'casing cannot alter occupancy')
 local body=x>=1 and x<=6 and y>=2 and y<=6 and z>=1 and z<=4
 if body and a~=nil then
  local sy=9-y
  local recessed=(sy==4 and(x==3 or x==4))or(sy==5 and x==2)
  local want=(z==4 or(z==3 and recessed))and(sy*W+x)or 2
  eq(a,want,'only front and actual recess surfaces keep facade texels')
  if a~=b then changes=changes+1 end
 else eq(a,b,'lid, desk, keyboard and unrelated source cells stay exact')end
end end end
ok(changes>50,'fixture actually exercises material replacement')
eq(m.at(3,5,4),nil,'automatic display recess remains empty in front')
eq(m.at(3,5,3),4*W+3,'automatic display retains its source one layer back')
eq(m.at(2,4,4),nil,'manual inset remains empty in front')
eq(m.at(2,4,3),5*W+2,'manual inset retains its source one layer back')
eq(m.at(2,3,3),2,'narrowed row penultimate side does not repeat source markings')
local q=emit(m,sp,8,16)
eq(q.voxels,oldEmit(old,sp,8,16).voxels,'casing leaves mesh occupancy unchanged')
print(('%d upright casing checks passed; legacy output exact, recess donors retained, %d body source substitutions'):format(checks,changes))
