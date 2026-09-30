-- Small original mesh vocabulary sharing the approved material contract.
local V=...
local Budget=V and V.require('BuildBudget')
local M={}
function M.new(uv)
 local G={out={}};uv=uv or {.5/128,.5/1992}
 function G.face(a,b,c,d,mat,tone,glow)
  if Budget then Budget.tick() end
  tone=tone or 1;local shade=tone+(glow and 64 or 0)
  if not glow then shade={};for i,p in ipairs({a,b,c,d})do shade[i]=tone*(.82+.18*math.min(1,math.max(0,p[2])/7))end end
  G.out[#G.out+1]={a,b,c,d,uv={uv,uv,uv,uv},own=true,shade=shade,referenceMaterial=mat,referenceGlass=glow or nil}
 end
 function G.box(a,b,c,d,e,f,mat,t)
  if d-a<.001 or e-b<.001 or f-c<.001 then return end;t=t or 1
  G.face({a,e,c},{a,e,f},{d,e,f},{d,e,c},mat,t)
  G.face({a,b,f},{d,b,f},{d,e,f},{a,e,f},mat,t*.94)
  G.face({d,b,c},{a,b,c},{a,e,c},{d,e,c},mat,t*.80)
  G.face({a,b,c},{a,b,f},{a,e,f},{a,e,c},mat,t*.83)
  G.face({d,b,f},{d,b,c},{d,e,c},{d,e,f},mat,t*.96)
  G.face({a,b,c},{d,b,c},{d,b,f},{a,b,f},mat,t*.65)
 end
 function G.beam(a,b,w,mat,t)
  local dx,dy,dz=b[1]-a[1],b[2]-a[2],b[3]-a[3];local len=math.sqrt(dx*dx+dy*dy+dz*dz)
  if len<.001 then return end
  local u={-dy/len*w/2,dx/len*w/2,0};local v={0,0,w/2}
  if math.abs(dx)+math.abs(dy)<.001 then u={w/2,0,0};v={0,w/2,0}end
  local pts={};for i,p in ipairs({a,b})do for j,s in ipairs({{-1,-1},{1,-1},{1,1},{-1,1}})do
   pts[(i-1)*4+j]={p[1]+u[1]*s[1]+v[1]*s[2],p[2]+u[2]*s[1]+v[2]*s[2],p[3]+u[3]*s[1]+v[3]*s[2]}
  end end
  for j=1,4 do local k=j%4+1;G.face(pts[j],pts[k],pts[k+4],pts[j+4],mat,t)end
 end
 function G.disc(x,y,z,r,mat,t)
  for i=0,31 do local a,b=i*math.pi/16,(i+1)*math.pi/16
   G.face({x,y,z},{x+r*math.cos(a),y+r*math.sin(a),z},{x+r*math.cos(b),y+r*math.sin(b),z},{x+r*math.cos(b),y+r*math.sin(b),z},mat,t)
  end
 end
 local alphabet={A='010101111101101',B='110101110101110',C='111100100100111',D='110101101101110',E='111100110100111',F='111100110100100',G='111100101101111',H='101101111101101',I='111010010010111',J='001001001101111',K='101101110101101',L='100100100100111',M='101111111101101',N='101111111111101',O='111101101101111',P='110101110100100',Q='111101101111001',R='110101110101101',S='111100111001111',T='111010010010010',U='101101101101111',V='101101101101010',W='101101111111101',X='101101010101101',Y='101101010010010',Z='111001010100111',[' ']='000000000000000'}
 function G.text(str,x,y,z,scale,mat)
  local left=x-(#str*4-1)*scale/2
  for i=1,#str do local glyph=alphabet[str:sub(i,i)] or alphabet[' ']
   for row=0,4 do for col=0,2 do if glyph:sub(row*3+col+1,row*3+col+1)=='1' then
    local a,b=left+((i-1)*4+col)*scale,y+(4-row)*scale
    G.face({a,b,z},{a+scale*.86,b,z},{a+scale*.86,b+scale*.86,z},{a,b+scale*.86,z},mat or 'white',1)
   end end end
  end
 end
 return G
end
return M
