-- Read the exported renderer's published cell/height record. No private globals,
-- terrain mutation or ownership claims. Profiles match Battle Art tag 1.11.1.
local M={}
function M.record(bridge,id)
 local ok,P=pcall(bridge.V.require,'GranitePillars')
 return ok and P and P.cache and P.cache[id] or nil
end
-- Published records may be replaced without any geometric change. Conversely,
-- cells may arrive inside the same record. Compare content, not table identity.
function M.signature(record)
 if not record then return 'none' end
 local keys={};for k in pairs(record.cells or {})do keys[#keys+1]=k end;table.sort(keys)
 local out={tostring(record.layout),tostring(record.boundary)}
 for _,k in ipairs(keys)do out[#out+1]=k..'='..tostring(record.cells[k])end
 return table.concat(out,';')
end
function M.append(bridge,id,face)
 local r=M.record(bridge,id)
 if not(r and r.cells and r.layout~='default')then return r,0 end
 local cells=r.cells;local anchors,piers,dirs={},{},{}
 for k in pairs(cells)do
  local x,z=k:match('^(-?%d+)|(-?%d+)$');x,z=tonumber(x),tonumber(z)
  if x then
   local d={north=cells[x..'|'..(z-1)]~=nil,south=cells[x..'|'..(z+1)]~=nil,
    west=cells[(x-1)..'|'..z]~=nil,east=cells[(x+1)..'|'..z]~=nil}
   dirs[k]=d
   local n=(d.north and 1 or 0)+(d.south and 1 or 0)+(d.east and 1 or 0)+(d.west and 1 or 0)
   if n~=2 or ((d.east or d.west)and(d.north or d.south))then anchors[k]=true;piers[k]=true end
  end
 end
 for k in pairs(anchors)do
  local x,z=k:match('^(-?%d+)|(-?%d+)$');x,z=tonumber(x),tonumber(z)
  for _,d in ipairs({{1,0,'east'},{0,1,'south'}})do if dirs[k][d[3]]then
   local length=1
   while cells[(x+d[1]*length)..'|'..(z+d[2]*length)]~=nil and not anchors[(x+d[1]*length)..'|'..(z+d[2]*length)]do length=length+1 end
   if cells[(x+d[1]*length)..'|'..(z+d[2]*length)]~=nil then
    local bays=math.ceil(length/3)
    for j=1,bays-1 do local s=math.floor(j*length/bays+.5);piers[(x+d[1]*s)..'|'..(z+d[2]*s)]=true end
   end
  end end
 end
 local count=0
 local function top(x,y,z,hx,hz,b,kind)
  b=math.min(b,math.min(hx,hz)*.18)
  local p={{x-hx+b,y,z-hz},{x+hx-b,y,z-hz},{x+hx,y,z-hz+b},{x+hx,y,z+hz-b},
   {x+hx-b,y,z+hz},{x-hx+b,y,z+hz},{x-hx,y,z+hz-b},{x-hx,y,z-hz+b}}
  for j=1,8 do local a={x,y,z};face({a,p[j],p[j%8+1],a},true,kind)end
 end
 local Boundary=r.boundary and bridge.V.require('DistrictBoundary')
 for k,base in pairs(cells)do
  local cx,cz=k:match('^(-?%d+)|(-?%d+)$');cx,cz=tonumber(cx),tonumber(cz)
  if cx then
   local x,z=cx*16+8,cz*16+8;local d=dirs[k]
   if Boundary then
    Boundary.build(id,x,z,base,d,piers[k]==true,function(q,tone,material)face(q,material~='reflector','district_rail')end)
   else
    if r.layout~='bottom'or piers[k]then
     local h,s,b=14.81,4.82,.42
     if r.layout=='top'then h,s,b=14.55,4.55*1.75,.38 end
     top(x,base+h,z,s,s,b,'pillar');count=count+1
    end
    if r.layout=='bottom'then
     if d.east then top(x+8,math.min(base,cells[(cx+1)..'|'..cz])+6.48,z,8.28,3.02,.2,'pillar_wall')end
     if d.south then top(x,math.min(base,cells[cx..'|'..(cz+1)])+6.48,z+8,3.02,8.28,.2,'pillar_wall')end
    end
   end
  end
 end
 return r,count
end
return M
