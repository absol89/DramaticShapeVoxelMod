-- Shared interior wall artwork belongs on vertical faces, never box lids.
local M={}
local function key(x,y)return(y+64)*4096+x+64 end
local profiles={
 HOUSE={
  {w=2,tiles={45,46,61,62},under={0,0,0,0}},
  {w=2,tiles={36,36,52,52},under={0,0,0,0}},
  {w=4,tiles={72,73,73,75,88,89,90,91},under={0,0,0,0,0,0,0,0}},
 },
 REDS_HOUSE_2={{w=2,tiles={36,37,52,53},under={0,0,0,0}}},
 POKECENTER={{w=2,tiles={92,93,94,95},under={40,40,40,40}}},
 LOBBY={
  {w=1,tiles={6,22},under={1,33}},
  {w=2,tiles={72,73,88,89},under={1,1,33,33}},
 },
}
local gateGlass={[45]=true,[58]=true,[61]=true,[62]=true}
function M.build(S,map,x0,x1,y0,y1)
 local tid=map.tileset.id
 if not profiles[tid] and tid~='GATE' then return end
 local aw,ah=map.tileset.imageWidth or 128,map.tileset.imageHeight or 48
 local perRow=map.tileset.tilesPerRow or 16
 local function emit(x,y,w,h,tiles,under)
  for i,t in ipairs(tiles)do
   local dx,dy=(i-1)%w,math.floor((i-1)/w)
   -- A gate's deep source band becomes one upright window at the same height.
   local step=16/h
   local xx,yy,z=(x+dx)*8,16-dy*step,(y+h)*8+.08
   local u,v=t%perRow*8,math.floor(t/perRow)*8
   S.objectQuads[#S.objectQuads+1]={{xx,yy-step,z},{xx+8,yy-step,z},{xx+8,yy,z},{xx,yy,z},
    uv={{(u+.05)/aw,(v+7.95)/ah},{(u+7.95)/aw,(v+7.95)/ah},{(u+7.95)/aw,(v+.05)/ah},{(u+.05)/aw,(v+.05)/ah}},
    shade=1,houseWallDecor=true,wallDecorSourceTile=t}
   S.tileAt[key(x+dx,y+dy)]=under[i]
  end
 end
 for _,p in ipairs(profiles[tid] or {})do
  local h=#p.tiles/p.w
  for y=math.max(0,y0),math.min(map.def.height*4-h,y1-h+1)do
   for x=math.max(0,x0),math.min(map.def.width*4-p.w,x1-p.w+1)do
    local hit=true
    for i,t in ipairs(p.tiles)do
     local k=key(x+(i-1)%p.w,y+math.floor((i-1)/p.w))
     if S.tileAt[k]~=t or not S.shapeAt[k] or S.shapeAt[k].class~='wall' then hit=false;break end
    end
    if hit then emit(x,y,p.w,h,p.tiles,p.under)end
   end
  end
 end
 -- Only the authored four-row north window band of upstairs route gates.
 if tid=='GATE' and map.id:match('_GATE_2F$') then
  for x=0,map.def.width*4-1 do
   local tiles,under={},{}
   for y=0,3 do
    local k=key(x,y);local t=S.tileAt[k]
    if not gateGlass[t] or not S.shapeAt[k] or S.shapeAt[k].class~='wall' then break end
    tiles[#tiles+1]=t;under[#under+1]=0
   end
   if #tiles==4 then emit(x,0,1,4,tiles,under)end
  end
 end
end
return M
