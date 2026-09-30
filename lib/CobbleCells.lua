-- TEST86: shared irregular stone outlines; no decorative or vertical geometry.
local function noise(x,z,s)
 local n=(x*73856093+z*19349663+s*83492791)%104729
 return ((n*n*37+n*17+s*101)%104729)/104729
end
local cells={};local cellCount=0
local function seed(col,row)
 return (col+.5)*4.8+(noise(col,row,1)-.5)*2.6,
        (row+.5)*4.3+(noise(col,row,2)-.5)*2.3
end
local function territory(col,row)
 local key=col..":"..row
 if cells[key] then return cells[key][1],cells[key][2],cells[key][3] end
 local cx,cz=seed(col,row)
 local p={{cx-14,cz-14},{cx+14,cz-14},{cx+14,cz+14},{cx-14,cz+14}}
 for iz=row-2,row+2 do for ix=col-2,col+2 do
  if ix~=col or iz~=row then
   local nx,nz=seed(ix,iz);local a,b=nx-cx,nz-cz;local c=(nx*nx+nz*nz-cx*cx-cz*cz)/2
   local out={};local prev=p[#p]
   if prev then
    local pd=a*prev[1]+b*prev[2]-c
    for _,q in ipairs(p)do local d=a*q[1]+b*q[2]-c
     if (d<=0)~=(pd<=0)then local t=pd/(pd-d);out[#out+1]={prev[1]+(q[1]-prev[1])*t,prev[2]+(q[2]-prev[2])*t}end
     if d<=0 then out[#out+1]=q end
     prev,pd=q,d
    end
   end
   p=out
  end
 end end
 cellCount=cellCount+1;if cellCount>4096 then cells={};cellCount=1 end
 cells[key]={p,cx,cz};return p,cx,cz
end
return {territory=territory}
