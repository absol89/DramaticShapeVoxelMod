-- Rear entrances are placement-specific scenery over existing engine warps.
-- No map cells, collision, warp records or south-facing building faces change.
local Entrances = {}
local records = {
  { map='CERULEAN_CITY', id='gabled_house_wide', tx=16,ty=20,bw=12,bh=4, dest='CERULEAN_BADGE_HOUSE', cells={{9,9,1}} },
  { map='CERULEAN_CITY', id='gabled_house_wide', tx=52,ty=20,bw=12,bh=4, dest='CERULEAN_TRASHED_HOUSE', cells={{27,9,3}} },
  { map='CELADON_CITY', id='celadon_mansion', tx=44,ty=8,bw=12,bh=12, dest='CELADON_MANSION_1F', cells={{24,3,3},{25,3,3}} },
  { map='ROUTE_5', id='route_5_gate', tx=12,ty=60,bw=16,bh=8, dest='ROUTE_5_GATE', cells={{9,29,3},{10,29,3}} },
  { map='ROUTE_6', id='celadon_mansion', tx=16,ty=4,bw=12,bh=12, dest='ROUTE_6_GATE', cells={{9,1,3},{10,1,3}} },
  { map='ROUTE_12', id='celadon_mansion', tx=16,ty=32,bw=12,bh=12, dest='ROUTE_12_GATE_1F', cells={{10,15,1},{11,15,1}} },
  { map='FUCHSIA_CITY', id='gabled_house', tx=60,ty=50,bw=8,bh=6, dest='FUCHSIA_GOOD_ROD_HOUSE', cells={{31,24,1}} },
}
local plateau = { map='ROUTE_23', dest='ROUTE_22_GATE', cells={{7,139,3},{8,139,4}} }

local function matches(map,r)
  local def=map and map.def
  if not def or (def.id or map.id)~=r.map then return false end
  for _,c in ipairs(r.cells) do
    local found=false
    for _,w in ipairs(def.warps or {}) do
      if w.x==c[1] and w.y==c[2] then
        if w.destMap~=r.dest or w.destWarp~=c[3] then return false end
        found=true
      end
    end
    if not found then return false end
  end
  return true
end

local function artwork(data,perRow)
  if not data or type(data.getDimensions)~='function' or type(data.getPixel)~='function'
      or type(perRow)~='number' or perRow<13 then return nil end
  local w,h=data:getDimensions()
  local pixels={}
  for y=0,15 do for x=0,15 do
    local tile=(y<8 and 11 or 27)+math.floor(x/8)
    local ax=(tile%perRow)*8+x%8
    local ay=math.floor(tile/perRow)*8+y%8
    if ax>=w or ay>=h then return nil end
    local _,_,_,alpha=data:getPixel(ax,ay)
    if alpha and alpha<.5 then return nil end
    -- The donor's own dark border and bright adjacent bevel form a shallow
    -- frame. Keep the window/panel recessed relative to it, with no invented
    -- colors and no texture stretching. Every face samples this same atlas.
    local frame=(x>=2 and x<=13 and (y==1 or y==14))
        or (y>=1 and y<=14 and (x==2 or x==13))
    local bevel=(x>=3 and x<=12 and (y==2 or y==13))
        or (y>=2 and y<=13 and (x==3 or x==12))
    pixels[y*16+x]={ax=ax,ay=ay,d=frame and 1.1 or bevel and .7 or .15}
  end end
  return pixels,w,h
end

local function panel(out,p,w,h,x0,z0)
  local bias=.01
  local function uv(v,n)
    local u0,u1=(v.ax+.05)/w,(v.ax+(n or 1)-.05)/w
    local v0,v1=(v.ay+.05)/h,(v.ay+.95)/h
    return {{u1,v1},{u0,v1},{u0,v0},{u1,v0}}
  end
  local function flatUV(v)
    local u,vv=(v.ax+.5)/w,(v.ay+.5)/h
    return {{u,vv},{u,vv},{u,vv},{u,vv}}
  end
  local function put(a,b,c,d,tex,shade)
    out[#out+1]={a,b,c,d,uv=tex,shade=shade,own=true}
  end
  local start=#out
  for sy=0,15 do
    local x=0;local y=15-sy
    while x<16 do
      local v=p[sy*16+x];local n=1
      -- At most one 8px tile run, preserving the world's curved lattice.
      while x+n<16 and (x+n)%8~=0 do
        local q=p[sy*16+x+n]
        if q.d~=v.d or q.ay~=v.ay or q.ax~=v.ax+n then break end
        n=n+1
      end
      local a,b,z=x0+x,x0+x+n,z0-v.d-bias
      put({b,y,z},{a,y,z},{a,y+1,z},{b,y+1,z},uv(v,n),.68)
      x=x+n
    end
    for sx=0,15 do
      local v=p[sy*16+sx];local a,b=x0+sx,x0+sx+1
      local z=z0-v.d-bias
      local function depth(x,row)
        if x<0 or x>15 or row<0 or row>15 then return 0 end
        return p[row*16+x].d
      end
      local left,right,up,down=depth(sx-1,sy),depth(sx+1,sy),depth(sx,sy-1),depth(sx,sy+1)
      local tex=flatUV(v)
      if v.d>left then
        local far=z0-left-bias
        put({a,y,z},{a,y,far},{a,y+1,far},{a,y+1,z},tex,.78)
      end
      if v.d>right then
        local far=z0-right-bias
        put({b,y,far},{b,y,z},{b,y+1,z},{b,y+1,far},tex,.78)
      end
      if v.d>up then
        local far=z0-up-bias
        put({a,y+1,far},{b,y+1,far},{b,y+1,z},{a,y+1,z},tex,.95)
      end
      if sy<15 and v.d>down then
        local far=z0-down-bias
        put({a,y,z},{b,y,z},{b,y,far},{a,y,far},tex,.5)
      end
    end
  end
  return #out-start
end

local function emit(S,r,data,perRow,z)
  local p,w,h=artwork(data,perRow)
  if not p then return 0 end
  S.facadeEntranceKeys=S.facadeEntranceKeys or {}
  local key=r.map..':'..z..':'..r.cells[1][1]
  if S.facadeEntranceKeys[key] then return 0 end
  S.facadeEntranceKeys[key]=true
  S.objectQuads=S.objectQuads or {}
  local n=0
  -- As on the existing side entrances, adjacent warp cells each retain
  -- one complete 16px source door. Their outside spans meet exactly.
  for _,c in ipairs(r.cells) do n=n+panel(S.objectQuads,p,w,h,c[1]*16,z) end
  return n
end

-- Call after Buildings.stamp for a matched, translated building placement.
function Entrances.stamp(S,map,data,perRow,tx,ty,bw,bh,t)
  if not S or not S.outdoor or not t or not map or not map.def
      or map.def.tileset~='OVERWORLD' then return 0 end
  for _,r in ipairs(records) do
    if r.id==t.id and r.tx==tx and r.ty==ty and r.bw==bw and r.bh==bh
        and matches(map,r) then return emit(S,r,data,perRow,ty*8) end
  end
  return 0
end

-- Route23's back of the badge gate is PLATEAU roof scenery, not a
-- Buildings template. The exact roof boundary and two real warps guard it.
function Entrances.build(S,map,data,perRow)
  -- Map.isOutdoor deliberately excludes PLATEAU for door-SFX behavior;
  -- this visual uses exact map/tileset/warp/roof guards instead.
  if not S or not map or not map.def
      or map.def.tileset~='PLATEAU' or not matches(map,plateau)
      or type(map.tileAt)~='function' then return 0 end
  for x=14,17 do
    if map:tileAt(x,280)~=62 or map:tileAt(x,281)~=61 then return 0 end
  end
  return emit(S,plateau,data,perRow,2240)
end
return Entrances
