-- Bill's exposed silver pipe: a low-cost octagonal shell with the source
-- drawing's two raised joint collars. The former wall boxes are claimed
-- separately; only original metal texels are sampled here.
local Pipe = {}
function Pipe.model(sp, pr, t)
  local kind = t.pipeVariant
  assert(kind == "link" or kind == "left" or kind == "right", "Bill pipe variant")
  assert(sp.H == 16 and sp.W == (kind == "link" and 48 or 8), "Bill pipe source dimensions")
  local faces, W = {}, sp.W
  local function source(x,y)
    local i=y*W+x
    assert(sp.inside[i], "pipe material belongs to its original metal silhouette")
    return i
  end
  local grey,white,dark,black
  if kind=="link" then
    grey,white,dark,black=source(8,6),source(8,7),source(8,10),source(8,5)
  else
    grey,white,dark,black=source(4,3),source(4,6),source(4,10),source(4,2)
  end
  assert(sp.col[grey]==1 and sp.col[white]==0 and sp.col[dark]==2 and sp.col[black]==3)
  -- The source tube occupies elevation rows3..11, with its collar in
  -- rows2..12: diameter9 and11, centered8.5 above ground. Put its axis at
  -- the chambers' real center depth (world32 from this pair's origin16).
  -- The4px inserts meet the narrower cylindrical body under its cap.
  local cy,cz=8.5,16
  local oct={{1,math.sqrt(2)-1},{math.sqrt(2)-1,1},{1-math.sqrt(2),1},
    {-1,math.sqrt(2)-1},{-1,1-math.sqrt(2)},{1-math.sqrt(2),-1},
    {math.sqrt(2)-1,-1},{1,1-math.sqrt(2)}}
  local function p(x,r,j)
    local v=oct[(j-1)%8+1]
    return{x,cy+r*v[1],cz+r*v[2]}
  end
  local function face(a,b,c,d,i,shade)
    faces[#faces+1]={a,b,c,d,source=i,shade=shade}
  end
  local materials={white,white,grey,dark,dark,grey,grey,grey}
  local function shell(a,b,r,band)
    for j=1,8 do
      local n=oct[j];local next=oct[j%8+1]
      local ny,nz=n[1]+next[1],n[2]+next[2]
      local length=math.sqrt(ny*ny+nz*nz);ny,nz=ny/length,nz/length
      local shade=0.68+0.27*math.max(0,ny)+0.1*math.max(0,nz)
      face(p(a,r,j),p(a,r,j+1),p(b,r,j+1),p(b,r,j),band and black or materials[j],shade)
    end
  end
  local function shoulder(x,old,new)
    for j=1,8 do
      face(p(x,old,j),p(x,old,j+1),p(x,new,j+1),p(x,new,j),black,0.75)
    end
  end
  local sections={}
  local function section(a,b,r,band)sections[#sections+1]={a,b,r,band}end
  local function collar(a,b)
    section(a,a+0.35,5.5,true)
    section(a+0.35,b-0.35,5.5)
    section(b-0.35,b,5.5,true)
  end
  if kind=="link" then
    section(-4,4,4.5);collar(4,7);section(7,41,4.5);collar(41,44);section(44,52,4.5)
  elseif kind=="left" then
    section(0,1,4.5);collar(1,4);section(4,12,4.5)
  else
    section(-4,4,4.5);collar(4,7);section(7,8,4.5)
  end
  local last
  for _,s in ipairs(sections)do
    if last and last[3]~=s[3]then shoulder(s[1],last[3],s[3])end
    -- Buildings bends the world on an8px lattice. Keep this smooth tube
    -- on the same axial segmentation, without adding visible joint ribs.
    local x=s[1]
    while x<s[2]do
      local next=math.min(s[2],(math.floor(x/8)+1)*8)
      shell(x,next,s[3],s[4]);x=next
    end
    last=s
  end
  -- Four planar quads close each octagonal end without degenerate
  -- triangles or redundant internal caps between tube/collar sections.
  for n,s in ipairs({sections[1],sections[#sections]})do
    local x=s[n==1 and 1 or 2];local center={x,cy,cz}
    for j=1,8,2 do
      if n==1 then face(center,p(x,s[3],j+2),p(x,s[3],j+1),p(x,s[3],j),dark,0.68)
      else face(center,p(x,s[3],j),p(x,s[3],j+1),p(x,s[3],j+2),grey,0.78)end
    end
  end
  -- No proxy is needed for this isolated closed shell. Empty occupancy
  -- avoids emitting a second voxel skin; the standard surface path uses
  -- the original atlas and shared shader for all faces.
  return{W=W,ytop=13,zmin=10,zmax=21,at=function()return nil end,surfaces=faces}
end
return Pipe
