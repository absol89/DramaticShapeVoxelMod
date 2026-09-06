local root=arg[1] or '.'
local M=assert(loadfile(root..'/lib/MuseumFossils.lua'))({})
local pattern={{39,40,40,40,40,40,40,25},{48,70,71,58,58,70,71,44},{49,60,83,63,60,60,60,44},{50,51,50,51,50,51,50,51}}
local map={id='MUSEUM_1F',tileset={id='MUSEUM'}}
function map:tileAt(x,y)
 for _,start in ipairs({4,10})do if x>=2 and x<=9 and y>=start and y<start+4 then return pattern[y-start+1][x-1]end end
 return 0
end
local ps=M.placements(map);assert(#ps==2,'two exhibits expected')
assert(#M.placements({id='OAKS_LAB',tileset={id='LAB'}})==0)
local uv={dark={0,0},light={1,1},middle={.5,.5}}
for _,p in ipairs(ps)do
 local q=M.geometry(p,uv);local roles={}
 for _,f in ipairs(q)do roles[f.fossilRole]=(roles[f.fossilRole]or 0)+1
  for i=1,4 do local v=f[i];assert(v[1]>=p.x and v[1]<=p.x+64);assert(v[2]>=0 and v[2]<=32);assert(v[3]>=p.z and v[3]<=p.z+16.5)end
 end
 assert(roles.bone>0 and roles.frame>0 and roles.plaque==6)
 print(p.kind,#q..' quads',roles.bone..' bone quads')
end
print('PASS exact museum placements, unrelated map excluded, bounded geometry, case and skeleton present')
local snap={};for y=0,15 do for x=0,39 do snap[x..','..y]=map:tileAt(x,y)end end
local S={skip={},ground={},shapeAt={},objectQuads={}}
local fake={getDimensions=function()return 2,1 end,getPixel=function(_,x)return x,x,x,1 end}
local count=M.build(S,map,fake,16);assert(count>0)
local n=0;for k in pairs(S.skip)do n=n+1 end;assert(n==64,'exact 64 source tiles replaced')
for key,t in pairs(snap)do local x,y=key:match('^(%d+),(%d+)$');assert(map:tileAt(tonumber(x),tonumber(y))==t,'map mutated')end
print('PASS 64 exhibit tiles replaced; source map unchanged')


local original=map.tileAt;map.tileAt=function(self,x,y)if x==2 and y==4 then return 0 end;return original(self,x,y)end;assert(#M.placements(map)==1,'changed source exhibit must fall back');print('PASS modified exhibit fallback')
