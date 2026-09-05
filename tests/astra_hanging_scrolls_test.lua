-- Standalone geometry checks; optional real-map checks use user-generated
-- data (never included in the repository). No LOVE/GPU is required.
local root=os.getenv('ASTRA_CANDIDATE')or'.'
local M=assert(loadfile(root..'/lib/HangingScrolls.lua'))({require=function(n)
 assert(n=='BuildBudget');return{tick=function()end}end})
local n=0
local function ok(v,msg)n=n+1;assert(v,msg)end
local function key(x,z)return(z+64)*4096+x+64 end
local source={{52,67},{82,83}}
local function fake(id)
 return{id=id,def={width=1,height=1},tileset={id='DOJO',imageWidth=128,imageHeight=48,tilesPerRow=16},tileAt=function(self,x,y)
  return source[y+1]and source[y+1][x+1]or 17 end}
end
local function state()return{shapeAt={},tileAt={},ground={},skip={},objectQuads={}}end
local map=fake('OAKS_LAB');local S=state()
S.ground[key(0,0)]=17;S.tileAt[key(0,0)]=52
ok(M.build(S,map)==1,'one exact scroll pattern claimed')
ok(S.ground[key(0,0)]==17 and S.tileAt[key(0,0)]==52,'source/ground metadata preserved')
local before=#S.objectQuads;ok(M.build(S,map)==0 and #S.objectQuads==before,'idempotent claims')
local front,edges,caps=0,0,0
local seen={}
for _,q in ipairs(S.objectQuads)do
 for _,p in ipairs(q)do for axis=1,3 do ok(p[axis]==p[axis]and math.abs(p[axis])<math.huge,'finite vertex')end
  ok(p[1]>=0 and p[1]<=16 and p[2]>=0 and p[2]<=16 and p[3]>=0 and p[3]<=18,'source wall footprint plus 2px mounted relief')
 end
 local a,b,c=q[1],q[2],q[3]
 local u,v={b[1]-a[1],b[2]-a[2],b[3]-a[3]},{c[1]-a[1],c[2]-a[2],c[3]-a[3]}
 local area=(u[2]*v[3]-u[3]*v[2])^2+(u[3]*v[1]-u[1]*v[3])^2+(u[1]*v[2]-u[2]*v[1])^2
 ok(area>0,'no degenerate geometry')
 for _,uv in ipairs(q.uv)do ok(uv[1]>0 and uv[1]<1 and uv[2]>0 and uv[2]<1,'valid atlas sample')end
 if q.hangingScrollRole=='scroll-front' or q.hangingScrollRole=='wall-front'then
  front=front+1;local x,row=q[1][1],15-q[1][2]
  local at=x..':'..row;ok(not seen[at],'one front skin per original pixel');seen[at]=true
  local ax,ay=math.floor(q.uv[1][1]*128),math.floor(q.uv[1][2]*48)
  local tile=math.floor(ay/8)*16+math.floor(ax/8)
  local expected=M.depth(x,row)>0 and source[math.floor(row/8)+1][math.floor(x/8)+1]or(row<8 and 5 or 16)
  ok(tile==expected and ax%8==x%8 and ay%8==row%8,'original glyph pixels or plain wall donor')
  ok(q[1][3]==16+M.depth(x,row),'measured relief height')
 elseif q.hangingScrollRole=='scroll-edge'then edges=edges+1
 else
  caps=caps+1;ok(math.floor(q.uv[1][2]*48/8)*16+math.floor(q.uv[1][1]*128/8)==5,'no scroll artwork on wall caps or sides')
 end
end
ok(front==256 and edges>0 and caps==16,'complete backing and shallow relief shell')
ok(M.depth(7,5)==.75 and M.depth(7,1)==2 and M.depth(7,0)==1,'paper and rounded roll cross section')
ok(M.depth(7,14)==0 and M.depth(0,8)==0,'wall base and side shadows never extruded as scroll')
for y=0,1 do for x=0,1 do local k=key(x,y);ok(S.skip[k]and S.shapeAt[k].authored and S.shapeAt[k].h==16,'authored wall prevents generic duplicate')end end
ok(M.build(state(),fake('LANCES_ROOM'))==0,'other DOJO maps untouched')
local blocked=state();blocked.skip[key(1,1)]=true;ok(M.build(blocked,map)==0,'honor previous geometry ownership')
local changed=fake('OAKS_LAB');changed.tileAt=function()return 5 end
ok(M.build(state(),changed)==0,'unknown/replaced artwork retains fallback')
local engine,generated=os.getenv('ASTRA_ENGINE'),os.getenv('ASTRA_GENERATED')
if engine and generated then
 package.path=engine..'/?.lua;'..package.path
 local Map=require('src.world.Map');local maps=dofile(generated..'/maps.lua');local sets=dofile(generated..'/tilesets.lua')
 for _,id in ipairs({'OAKS_LAB','FIGHTING_DOJO'})do
  local actual=Map.new(maps[id],sets.DOJO);local st=state()
  ok(M.matches(actual,8,0) and M.matches(actual,10,0),id..' two verified north-wall cells')
  ok(M.build(st,actual)==2,id..' exactly two complete scrolls')
  for y=0,1 do for x=8,11 do ok(st.skip[key(x,y)],id..' original eight-tile claim')end end
  print(id..': '..#st.objectQuads..' quads, source tile origins (8,0)/(10,0)')
 end
else print('Real-map checks skipped: set ASTRA_ENGINE and ASTRA_GENERATED')end
print('Hanging scroll checks passed: '..n)
