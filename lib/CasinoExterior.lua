-- Coordinated Celadon casino and subordinate prize pavilion.
local V=...
local M={}
function M.detail(G,s,H)
 if s.map=='CELADON_CITY' and (s.kind=='arcade' or s.kind=='prize_shop') then
  return V.require('CasinoFacade').detail(G,s,H)
 end
 local box,face,beam=G.box,G.face,G.beam
 local x0,x1,z0,z1=s.x0,s.x1,s.z0,s.z1
 local W=x1-x0;local cx=(x0+x1)/2;local casino=s.kind=='arcade'
 local function pane(a,b,c,d,z,mat,glow)
  face({a,b,z},{c,b,z},{c,d,z},{a,d,z},mat,1,glow)
 end
 local function bulb(x,y,z,r)
  G.disc(x,y,z,r,'gold')
  -- Only the small lamp face is emissive, using the existing warm glass contract.
  pane(x-r*.48,y-r*.48,x+r*.48,y+r*.48,z+.025,'glass',true)
 end
 -- Shared red fascia with thin brass moldings; the casino has the deeper marquee.
 local depth=casino and 4.2 or 2.6
 box(x0+1,23.8,z1+.2,x1-1,28.4,z1+depth,'red',1)
 for _,y in ipairs({23.8,28.1})do box(x0+.7,y,z1+depth,x1-.7,y+.35,z1+depth+.35,'gold',1)end
 for x=x0+3,x1-2,casino and 3 or 5 do bulb(x,25.9,z1+depth+.38,.38)end
 -- Brass and burgundy corner pilasters frame the shopfront without moving doors.
 for _,x in ipairs({x0+1.8,x1-1.8})do
  box(x-.9,0,z1+.6,x+.9,H+4,z1+1.8,'red',1)
  for _,dx in ipairs({-.9,.7})do box(x+dx,1,z1+1.81,x+dx+.2,H+3,z1+2,'gold',1)end
  for _,y in ipairs({3,21,H+2})do box(x-1.2,y,z1+.4,x+1.2,y+.7,z1+2.1,'gold',1)end
 end
 -- Side cornices repeat the palette so the pair reads as one establishment.
 for _,x in ipairs({x0-.1,x1-.5})do
  box(x,H-3,z0,x+.6,H+1,z1,'red',1)
  box(x-.1,H+.7,z0,x+.7,H+1.1,z1,'gold',1)
 end
 local half=math.min(W*.39,casino and 35 or 24)
 local bottom=H+1;local top=H+(casino and 14 or 10)
 box(cx-half,bottom,z1-3,cx+half,top,z1+.8,'gold',1)
 box(cx-half+.6,bottom+.6,z1+.81,cx+half-.6,top-.6,z1+1.4,'red',1)
 box(cx-half+1.8,bottom+1.8,z1+1.41,cx+half-1.8,top-1.8,z1+1.9,'navy',1)
 local title=casino and 'CASINO' or 'PRIZES'
 local scale=math.min(casino and 1.6 or 1.05,(half*2-7)/(#title*4-1))
 G.text(title,cx,(bottom+top)/2-2.5*scale,z1+2,scale,'gold')
 for x=cx-half+1,cx+half-1,3 do
  bulb(x,bottom+.9,z1+1.5,.3);bulb(x,top-.9,z1+1.5,.3)
 end
 if casino then
  -- Three large seven reels and an Art Deco crown establish a casino silhouette.
  local cy=top+7
  box(cx-17,top-1,z1-5,cx+17,top+15,z1-1,'navy',1)
  for i=-1,1 do
   local x=cx+i*10
   box(x-4.7,cy-5.5,z1-.9,x+4.7,cy+5.5,z1+.3,'gold',1)
   pane(x-4.1,cy-4.9,x+4.1,cy+4.9,z1+.35,'white')
   beam({x-2.4,cy+3,z1+.5},{x+2.4,cy+3,z1+.5},1,'red')
   beam({x+2.4,cy+3,z1+.5},{x-1.6,cy-3,z1+.5},1,'red')
  end
  for i=-2,2 do
   local height=4+(2-math.abs(i))*2
   box(cx+i*5-1,top+15,z1-4,cx+i*5+1,top+15+height,z1-2,'gold',1)
  end
  -- Small gold diamonds repeat across the fascia below the marquee.
  for _,x in ipairs({x0+W*.15,x0+W*.85})do
   face({x-2,30,z1+1},{x,32,z1+1},{x+2,30,z1+1},{x,28,z1+1},'gold',1)
  end
 else
  -- A single trophy is deliberately quieter than the casino's triple reel crown.
  local y=top+3;local z=z1+.2
  box(cx-2.6,y,z-.4,cx+2.6,y+1,z+.4,'gold',1)
  box(cx-.5,y+1,z-.2,cx+.5,y+3,z+.3,'gold',1)
  face({cx-1,y+3,z+.5},{cx+1,y+3,z+.5},{cx+3,y+7,z+.5},{cx-3,y+7,z+.5},'gold',1)
  for _,sg in ipairs({-1,1})do
   beam({cx+sg*2.5,y+6,z+.4},{cx+sg*4,y+6,z+.4},.5,'gold')
   beam({cx+sg*4,y+6,z+.4},{cx+sg*3,y+3.7,z+.4},.5,'gold')
   beam({cx+sg*3,y+3.7,z+.4},{cx+sg*1.5,y+3.7,z+.4},.5,'gold')
  end
 end
end
return M
