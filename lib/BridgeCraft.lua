-- TEST6: a complete cached waterfront edge. No ground-facing rails.
local M={}
function M.build(x,z,h,dx,dz,post,emit,lamp)
 local function box(a,b,c,d,lo,hi,mat)
  a,b,c,d=math.max(x,a),math.max(z,b),math.min(x+8,c),math.min(z+8,d)
  if c<=a or d<=b then return end
  local sides={{{a,lo,b},{c,lo,b},{c,hi,b},{a,hi,b}},{{c,lo,d},{a,lo,d},{a,hi,d},{c,hi,d}},{{a,lo,d},{a,lo,b},{a,hi,b},{a,hi,d}},{{c,lo,b},{c,lo,d},{c,hi,d},{c,hi,b}}}
  for i,q in ipairs(sides)do emit(q,mat,.78+i*.055)end
  emit({{a,hi,b},{c,hi,b},{c,hi,d},{a,hi,d}},mat=='wood' and hi-lo>math.max(c-a,d-b) and 'woodEnd' or mat,1.06)
 end
 local cross=dx~=0
 local axis0=cross and z or x
 local edge= cross and (dx<0 and x+1.5 or x+6.5) or (dz<0 and z+1.5 or z+6.5)
 local function beam(a,b,lo,hi,width,mat)
  if cross then box(edge-width/2,a,edge+width/2,b,h+lo,h+hi,mat)
  else box(a,edge-width/2,b,edge+width/2,h+lo,h+hi,mat)end
 end
 beam(axis0,axis0+8,-2.5,.10,1.25,'wood')
 beam(axis0,axis0+8,3.2,4.15,.8,'wood')
 beam(axis0,axis0+8,6.25,7.25,1.0,'wood')
 if not post then return end
 local center=axis0+4
 beam(center-1.15,center+1.15,-5.6,7.75,2.3,'wood')
 beam(center-1.46,center+1.46,-5.6,-4.75,2.92,'stone')
 beam(center-1.32,center+1.32,-4.75,-4.35,2.64,'stone')
 -- Overhanging two-step white coping, deliberately wider than the post.
 beam(center-1.48,center+1.48,7.75,8.3,2.96,'stone')
 beam(center-1.28,center+1.28,8.3,8.62,2.56,'stone')
 if lamp==nil or lamp then
 beam(center-1.04,center+1.04,8.62,8.93,2.08,'iron')
 beam(center-.79,center+.79,8.93,11.65,1.58,'glass')
 -- Four opaque frame pillars and the horizontal glass divider.
 local px,pz=cross and edge or center,cross and center or edge
 for _,a in ipairs({-1.01,.76})do for _,b in ipairs({-1.01,.76})do
  box(px+a,pz+b,px+a+.25,pz+b+.25,h+8.85,h+11.75,'iron')
 end end
 beam(center-1.04,center+1.04,10.15,10.32,2.08,'iron')
 beam(center-1.24,center+1.24,11.65,12.05,2.48,'iron')
 beam(center-.96,center+.96,12.05,12.38,1.92,'iron')
 beam(center-.51,center+.51,12.38,12.65,1.02,'iron')
 end
 -- Stepped diagonal braces, visible below the deck at exposed edges.
 for side=-1,1,2 do for k=0,3 do
  local along=center+side*(1.3+k*.52)
  beam(along-.36,along+.36,-4.25+k*.56,-3.40+k*.56,.82,'wood')
 end end
 -- Iron fastening collars at the timber joints.
 beam(center-1.17,center+1.17,.5,.78,2.34,'iron')
 beam(center-1.17,center+1.17,5.4,5.66,2.34,'iron')
end
return M
