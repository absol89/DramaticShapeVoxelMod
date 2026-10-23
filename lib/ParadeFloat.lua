-- TEST235: POSES ON THE FLOAT (ParadeCast's poses). You and your partner
-- can be tipped about your feet like anyone in the parade -- a sway, a nod
-- while Jigglypuff sings, a full fall-over for the game's ending: your
-- trainer model through the character renderers' first (riding or walking:
-- the 'player' pose), your partner on the dais through its own draw (the
-- 'partner' pose; a partner walking at your heels is ParadeCast's). And
-- riderFeet: where each of you stands on the dais (for the Zz, a doodle).
-- TEST231: your partner turns toward the crowd on its own side (TEST230
-- turned it toward you); with no model drawing you (the engine's card in
-- the dais's middle) it stands clear of your card; and a partner taken as a
-- guess (someone was following you, of a kind not told yet) is checked
-- until the kind is told, then swapped if it is another.
-- TEST230: YOU AND YOUR PARTNER. Joseph: "should it just be your character
-- and your following pokemon? ... Right now the following pokemon trailing
-- the float looks silly." So the float carries the two of you, side by
-- side on the dais: your partner -- the Pokemon walking at your heels (by
-- the kind it is drawn as, TEST229's rules), else your first Pokemon --
-- stands at your right, you a step to the left; a broad partner stands a
-- little behind you (a big one looms over your shoulder), and the float is
-- made longer behind for it. Nobody else of your team rides: the tiers in
-- front carry a giant Poke Ball (on the front one) and beds of flowers.
-- While the float runs, the Pokemon walking at your heels steps out of the
-- picture (the Collection's models read overworld.legendaryHideFollowers;
-- a follower drawn as a card is held back by the float's renderer), so it
-- no longer trails behind. If someone else turns out to be walking with you
-- once the picture is up, it takes the place beside you.
--
-- TEST225: THE CHAMPION'S FLOAT. In the Hall of Fame, Professor Oak asks
-- whether you will WALK in the parade or RIDE; this is the ride.
--
--   * a parade float in the Champion's colours: a pleated red skirt under a
--     gold band, swags of leaves and flowers along both flanks, a flower
--     border round the deck, a blue crest with a gold star on the prow, two
--     gold poles with bunting, and a red-and-gold sunburst behind you
--   * three of your team ride on it, on tiers that rise toward you (the
--     smallest in front, so nobody hides anybody): their 3D models from the
--     Collection, the same ones the Hall of Fame shows (their pictures when
--     the models are off). Your partner walking at your heels (a follower)
--     is not put on the float as well: it walks behind
--   * you ride at the back on a raised dais, standing. Your trainer model
--     holds its idle while the float carries it (a model mod would otherwise
--     walk on the spot, seeing you move)
--   * no ledge hops: each stop has a float road of its own (ChampionParade),
--     straight down the street, its whole length clear of walls
--   * at night (the Plateau) a string of lights runs round the deck
--
-- How it fits: drawn in the parade's world pass (DockLights.drawLate, after
-- the people); you are lifted onto the dais through your own pose (the lift
-- VoxelScene already turns a ledge hop into), and the trainer model's idle
-- comes from a wrap of CharacterRenderers.first that hands the model a pose
-- held still at the float's start and moves its drawing to where you are.
-- Everything is undone when the parade ends (or a reset ends it).
--
-- TEST228: the partner at your heels is left off the float whichever mod
-- brings it (Yellow's Pikachu, Followers EX, PokePC, Wilds...), so it does
-- not ride as well as walk: a Charizard following you put a second Charizard
-- on the top tier.
--
-- TEST226: two confetti cannons on the prow, either side of the crest (gold
-- tubes with red bands): the parade fires them on the camera's big moments
-- (cannonPoints gives their muzzles and the way they point, in the world).
-- And the float takes corners: it turns about you (the back of the float,
-- where you stand), as a long float swings round a street corner.
local V=...
local F={REVISION='parade-float-242'}
local floor,max,min,abs,sin,cos,sqrt,pi=math.floor,math.max,math.min,math.abs,math.sin,math.cos,math.sqrt,math.pi

-- the float, in world units (a cell is 16): you stand at its origin, it runs
-- forward (the way you travel) from REAR to NOSE, HALF_W either side
F.HALF_W=8.5           -- one cell wide, and a little: it fits any road you can walk
F.REAR=-9
F.DECK_END=36          -- where the deck ends and the prow slopes to the road
F.NOSE=38.5
F.LIFT=11.9            -- the top of your dais
-- the three riding with you: how far ahead of you each stands, and the top
-- of its tier (front to back: lowest to highest)
F.SLOTS={{z=29.8,y=6.9},{z=19.8,y=8.7},{z=9.6,y=10.5}}
-- their size: MODEL_H for a Pokemon 1.5 m tall, the rest by the fourth root
-- of their POKeDEX heights, between MIN and MAX, no wider than MODEL_W
F.MODEL_H,F.MODEL_MIN,F.MODEL_MAX,F.MODEL_W=12,8,14.5,13
F.PICK_FRAMES=2        -- card frames before the riders are chosen (TEST229: 10 -> 2)
-- TEST230: you and your partner on the dais. You stand YOU_X across it (a
-- step to the left), your partner PARTNER_X (to the right); its size: base
-- PARTNER_H for a Pokemon 1.5 m tall, by its POKeDEX height to the power
-- PARTNER_EXP (nearer life size beside you than the Hall of Fame's), within
-- MIN..MAX, no wider than PARTNER_W. A broad partner stands further back.
F.YOU_X=-2.4
F.PARTNER_X=3.6
F.PARTNER_XMAX=5.2
F.DAIS_W=8.6
F.PARTNER_H,F.PARTNER_EXP,F.PARTNER_MIN,F.PARTNER_MAX,F.PARTNER_W=10,.4,5.5,14,13
-- the giant Poke Ball on the front tier (its radius, and where it stands)
F.BALL={r=3.3,z=30.0,stand=.7}
-- (TEST231) how long a frame of your trainer model counts as "your model
-- is drawing", and how far back your partner stands beside the engine's
-- card when it is not
F.YOU_MODEL_FRESH=.5
F.CARD_STEP_BACK=3
F.PICTURE_H=21         -- (the Hall of Fame's size for a picture's body)
F.LIGHT={direction={-.30,.80,.52},ambient={.52,.49,.46},diffuse={.56,.51,.43}}
-- TEST226: the confetti cannons' muzzles (on the prow, either side of the crest)
F.CANNONS={{x=-7.0,y=9.2,z=37.3},{x=7.0,y=9.2,z=37.3}}

local current=nil      -- the float on the road now

local function now()local ok,t=pcall(love.timer.getTime);return ok and t or 0 end
local function log(fmt,...)
 local args={...}
 pcall(function()require('src.core.Logger').warn('[ParadeFloat] '..fmt,unpack(args))end)
end

------------------------------------------------------------------ the colours
-- one small picture holds every colour the float is painted with; each face
-- samples the middle of its colour's pixel
local PAL_ORDER={'red','redDark','gold','cream','marble','blue','green','greenDark',
 'pink','yellow','white','dark','star','pRed','pBlue','pYellow'}
local PAL={red={.80,.12,.16},redDark={.55,.06,.10},gold={.98,.77,.27},cream={.97,.94,.86},
 marble={.94,.92,.89},blue={.16,.30,.76},green={.20,.55,.25},greenDark={.12,.38,.17},
 pink={1,.56,.76},yellow={1,.88,.32},white={1,1,1},dark={.15,.12,.12},
 star={1,.90,.44},pRed={.93,.18,.18},pBlue={.22,.42,.96},pYellow={1,.84,.20}}
F.PAL,F.PAL_ORDER=PAL,PAL_ORDER
local PAL_INDEX={}
for i,n in ipairs(PAL_ORDER)do PAL_INDEX[n]=i-1 end
local function uvOf(name)
 local i=PAL_INDEX[name]or 0
 return((i%4)+.5)/4,(floor(i/4)+.5)/4
end
F.uvOf=uvOf

------------------------------------------------------------------ the shape
-- every quad of the float (four corners and a shade each), in its own frame;
-- kept apart from the mesh so it can be checked and previewed headless
local function shapeQuads(L)
 L=type(L)=='table'and L or{}
 local Q={}
 local function quad(a,b,c,d,col,shade)Q[#Q+1]={a,b,c,d,col,shade or 1}end
 local function tri(a,b,c,col,shade)Q[#Q+1]={a,b,c,c,col,shade or 1}end
 local function box(x0,x1,y0,y1,z0,z1,col,top)
  quad({x1,y0,z0},{x1,y0,z1},{x1,y1,z1},{x1,y1,z0},col,.84)
  quad({x0,y0,z1},{x0,y0,z0},{x0,y1,z0},{x0,y1,z1},col,.72)
  quad({x0,y1,z0},{x1,y1,z0},{x1,y1,z1},{x0,y1,z1},top or col,1)
  quad({x0,y0,z1},{x1,y0,z1},{x1,y0,z0},{x0,y0,z0},col,.55)
  quad({x0,y0,z1},{x1,y0,z1},{x1,y1,z1},{x0,y1,z1},col,.90)
  quad({x1,y0,z0},{x0,y0,z0},{x0,y1,z0},{x1,y1,z0},col,.68)
 end
 local function cube(x,y,z,s,col)local h=s/2;box(x-h,x+h,y-h,y+h,z-h,z+h,col)end
 local W,R0,N,NOSE=F.HALF_W,L.rear or F.REAR,F.DECK_END,F.NOSE
 -- the skirt, pleated on its flanks and its tail
 box(-W,W,.3,4.4,R0,N,'red')
 for z=R0+1.5,N-1.5,3 do
  quad({W+.06,.3,z},{W+.06,.3,z+1},{W+.06,4.4,z+1},{W+.06,4.4,z},'redDark',.84)
  quad({-W-.06,.3,z+1},{-W-.06,.3,z},{-W-.06,4.4,z},{-W-.06,4.4,z+1},'redDark',.72)
 end
 for x=-W+1.5,W-2.5,3 do
  quad({x+1,.3,R0-.06},{x,.3,R0-.06},{x,4.4,R0-.06},{x+1,4.4,R0-.06},'redDark',.68)
 end
 -- the prow: from the deck's edge down toward the road
 quad({-W,.3,NOSE},{W,.3,NOSE},{W,4.4,N},{-W,4.4,N},'red',.95)
 tri({W,.3,N},{W,.3,NOSE},{W,4.4,N},'red',.84)
 tri({-W,.3,NOSE},{-W,.3,N},{-W,4.4,N},'red',.72)
 -- the gold band round the deck, and the deck
 box(-W-.3,W+.3,4.4,5.0,R0-.3,N+.3,'gold')
 box(-W,W,5.0,5.3,R0,N,'cream')
 -- the tiers (marble, gold-edged) and your dais (royal blue)
 local function tier(x,z0,z1,top,col)
  box(-x,x,5.3,top-.3,z0,z1,col)
  box(-x-.25,x+.25,top-.3,top,z0-.25,z1+.25,'gold')
 end
 tier(6.8,25.2,34.8,F.SLOTS[1].y,'marble')
 tier(7.0,14.6,25.2,F.SLOTS[2].y,'marble')
 tier(7.0,4.4,14.6,F.SLOTS[3].y,'marble')
 -- (TEST230: the dais is wider: you and your partner side by side)
 tier(L.daisW or 7.2,R0+.4,4.4,F.LIFT,'blue')
 -- TEST230: the tiers in front carry no riders now: beds of flowers on the
 -- two nearest you (low, nobody is hidden), and a giant Poke Ball on the
 -- front one, red over white, its band and its button facing the way the
 -- float goes
 do
  local BED={'pink','yellow','white','pRed','pBlue','yellow','pink'}
  local function bed(z0,z1,y,w,h,seed)
   box(-w,w,y,y+h,z0,z1,'greenDark')
   local k=seed
   for z=z0+.8,z1-.8,1.45 do
    for x=-w+.8,w-.8,1.45 do
     k=k+1
     local jx,jz=((k*37)%7-3)*.09,((k*53)%7-3)*.09
     local tall=.25+((k*29)%5)*.08
     cube(x+jx,y+h+tall,z+jz,.80,(k%6==0)and'green'or BED[k%#BED+1])
    end
   end
  end
  bed(15.6,24.2,F.SLOTS[2].y,6.0,.55,10)
  bed(5.4,13.6,F.SLOTS[3].y,6.0,.40,40)
  local B=F.BALL
  local y0=F.SLOTS[1].y
  local cy,cz,r=y0+B.stand+B.r,B.z,B.r
  -- its stand: a gold ring
  local n=14
  for k=0,n-1 do
   local a0,a1=k/n*pi*2,(k+1)/n*pi*2
   local p0={sin(a0)*2.2,y0,cz+cos(a0)*2.2}
   local p1={sin(a1)*2.2,y0,cz+cos(a1)*2.2}
   quad(p0,p1,{p1[1],y0+B.stand+.35,p1[3]},{p0[1],y0+B.stand+.35,p0[3]},'gold',.88)
  end
  -- the ball
  local NL,NA=12,18
  local Ld=F.LIGHT.direction
  local ll=sqrt(Ld[1]*Ld[1]+Ld[2]*Ld[2]+Ld[3]*Ld[3])
  local function P(i,j)
   local th=i/NL*pi;local ph=j/NA*pi*2
   return {sin(th)*sin(ph)*r,cy+cos(th)*r,cz+sin(th)*cos(ph)*r},sin(th)*sin(ph),cos(th),sin(th)*cos(ph)
  end
  for i=0,NL-1 do for j=0,NA-1 do
   local a,nx,ny,nz=P(i+.5,j+.5)
   local col=(i<NL/2)and'pRed'or'white'
   local shade=.70+.30*max(0,(nx*Ld[1]+ny*Ld[2]+nz*Ld[3])/ll)
   quad((P(i,j)),(P(i,j+1)),(P(i+1,j+1)),(P(i+1,j)),col,shade)
  end end
  -- the band round its middle, a hair proud of it
  for j=0,NA-1 do
   local a0,a1=j/NA*pi*2,(j+1)/NA*pi*2
   local rr=r*1.012
   quad({sin(a0)*rr,cy-.26,cz+cos(a0)*rr},{sin(a1)*rr,cy-.26,cz+cos(a1)*rr},
    {sin(a1)*rr,cy+.26,cz+cos(a1)*rr},{sin(a0)*rr,cy+.26,cz+cos(a0)*rr},'dark',.9)
  end
  -- the button, facing forward: a dark ring, a white centre
  local bz=cz+r*1.012+.04
  for k=0,13 do
   local a0,a1=k/14*pi*2,(k+1)/14*pi*2
   quad({sin(a0)*1.12,cy+cos(a0)*1.12,bz},{sin(a1)*1.12,cy+cos(a1)*1.12,bz},
    {sin(a1)*.78,cy+cos(a1)*.78,bz+.06},{sin(a0)*.78,cy+cos(a0)*.78,bz+.06},'dark',.9)
   tri({0,cy,bz+.14},{sin(a0)*.78,cy+cos(a0)*.78,bz+.06},{sin(a1)*.78,cy+cos(a1)*.78,bz+.06},'white',1)
  end
 end
 -- the crest on the prow: a blue shield in a gold rim, a gold star on it
 do
  local cy,cz,r=8.9,36.5,4.3
  local n=16
  for k=0,n-1 do
   local a0,a1=k/n*pi*2,(k+1)/n*pi*2
   local x0,y0,x1,y1=sin(a0),cos(a0),sin(a1),cos(a1)
   tri({0,cy,cz},{x0*r,cy+y0*r,cz},{x1*r,cy+y1*r,cz},'blue',.92)
   quad({x0*r,cy+y0*r,cz-.02},{x1*r,cy+y1*r,cz-.02},{x1*(r+.7),cy+y1*(r+.7),cz-.02},{x0*(r+.7),cy+y0*(r+.7),cz-.02},'gold',.95)
  end
  -- (its back, so it is not a paper cut-out from behind)
  for k=0,n-1 do
   local a0,a1=k/n*pi*2,(k+1)/n*pi*2
   tri({0,cy,cz-.35},{sin(a1)*(r+.7),cy+cos(a1)*(r+.7),cz-.35},{sin(a0)*(r+.7),cy+cos(a0)*(r+.7),cz-.35},'gold',.68)
  end
  -- the star, standing a hair proud of the shield
  local sr,si=3.1,1.25
  for k=0,4 do
   local a=k/5*pi*2
   local ap,an=a-pi/5,a+pi/5
   local tip={sin(a)*sr,cy+cos(a)*sr,cz+.12}
   local l={sin(ap)*si,cy+cos(ap)*si,cz+.12}
   local rr={sin(an)*si,cy+cos(an)*si,cz+.12}
   tri({0,cy,cz+.12},l,tip,'star',1)
   tri({0,cy,cz+.12},tip,rr,'star',.93)
  end
 end
 -- the sunburst behind you: red and gold rays in a half ellipse, gold-rimmed
 do
  local fz,cy,rx,ry=R0+.15,F.LIFT,10,18
  local n=12
  for k=0,n-1 do
   local a0,a1=-pi/2+k/n*pi,-pi/2+(k+1)/n*pi
   tri({0,cy,fz},{sin(a0)*rx,cy+cos(a0)*ry,fz},{sin(a1)*rx,cy+cos(a1)*ry,fz},k%2==0 and'red'or'gold',.9)
   quad({sin(a0)*rx,cy+cos(a0)*ry,fz-.02},{sin(a1)*rx,cy+cos(a1)*ry,fz-.02},
    {sin(a1)*(rx+.8),cy+cos(a1)*(ry+.8),fz-.02},{sin(a0)*(rx+.8),cy+cos(a0)*(ry+.8),fz-.02},'gold',.95)
  end
  -- the sunburst's back: plain gold
  for k=0,n-1 do
   local a0,a1=-pi/2+k/n*pi,-pi/2+(k+1)/n*pi
   tri({0,cy,fz-.3},{sin(a1)*(rx+.8),cy+cos(a1)*(ry+.8),fz-.3},{sin(a0)*(rx+.8),cy+cos(a0)*(ry+.8),fz-.3},'gold',.68)
  end
  -- a gold disc at its heart, behind you
  for k=0,7 do
   local a0,a1=k/8*pi*2,(k+1)/8*pi*2
   tri({0,cy+2,fz+.05},{sin(a0)*3.2,cy+2+cos(a0)*3.2,fz+.05},{sin(a1)*3.2,cy+2+cos(a1)*3.2,fz+.05},'star',1)
  end
 end
 -- garlands: five swags of leaves and flowers along each flank, gold rosettes
 -- where they meet
 local FLOWERS={'pink','yellow','white'}
 for side=-1,1,2 do
  local x=side*(W+.4)
  local span=(N-R0-1.6)/5
  for s=0,4 do
   local z0=R0+.8+s*span
   for k=0,9 do
    local u=k/9
    local col=(k%3==1)and FLOWERS[(s+k)%3+1]or((k%2==0)and'green'or'greenDark')
    cube(x,4.0-1.9*sin(u*pi),z0+span*u,.95,col)
   end
   cube(x,4.25,z0,1.25,'gold')
  end
  cube(x,4.25,R0+.8+5*span,1.25,'gold')
 end
 -- a border of flowers round the deck, between the tiers and its edge
 local k=0
 for z=R0+1,N-1,1.7 do
  for side=-1,1,2 do
   k=k+1
   local col=FLOWERS[k%3+1]
   if k%4==0 then col='green'end
   cube(side*7.95,5.75,z,.9,col)
  end
 end
 for x=-6.8,6.8,1.7 do
  k=k+1
  cube(x,5.75,N-.5,.9,k%4==0 and'green'or FLOWERS[k%3+1])
 end
 -- two gold poles at the prow, and bunting from them back to the sunburst
 local PENN={'pRed','pYellow','pBlue'}
 for side=-1,1,2 do
  local x=side*7.9
  box(x-.35,x+.35,5.3,19.5,34.9,35.6,'gold')
  box(x-.65,x+.65,19.5,20.6,34.6,35.9,'star')
  local ax,ay,az=x,19.3,35.2
  local bx,by,bz=side*9.6,F.LIFT+12.5,R0+.2
  for j=1,12 do
   local u=j/13
   local px=ax+(bx-ax)*u
   local py=ay+(by-ay)*u-4.5*sin(u*pi)
   local pz=az+(bz-az)*u
   tri({px,py,pz-.95},{px,py,pz+.95},{px,py-2.0,pz},PENN[j%3+1],side>0 and .84 or .72)
  end
 end
 -- TEST226: the confetti cannons on the prow's slope, either side of the crest
 for _,c in ipairs(F.CANNONS)do
  local x=c.x
  box(x-.7,x+.7,2.0,9.0,36.6,38.0,'gold')
  box(x-.85,x+.85,4.4,5.2,36.45,38.15,'red')
  box(x-.85,x+.85,7.0,7.6,36.45,38.15,'red')
  quad({x-.5,9.02,36.8},{x+.5,9.02,36.8},{x+.5,9.02,37.8},{x-.5,9.02,37.8},'dark',.6)
 end
 return Q
end
F.shapeQuads=shapeQuads

-- the mesh, built once for each layout (TEST230: how long the float is
-- behind you depends on your partner)
local meshes={}
local function floatMesh(L)
 L=type(L)=='table'and L or{}
 local key=L.key or'default'
 if meshes[key]==nil then
  meshes[key]=false
  local ok,err=pcall(function()
   local R=V.require('Voxel3D')
   local verts,idx={},{}
   for i,q in ipairs(shapeQuads(L))do
    local u,v=uvOf(q[5])
    for c=1,4 do local p=q[c];verts[#verts+1]={p[1],p[2],p[3],u,v,q[6]}end
    R.pushQuad(idx,i-1)
   end
   meshes[key]=R.newMesh(verts,idx)or false
  end)
  if not ok then log('the float would not build: %s',tostring(err));meshes[key]=false end
 end
 return meshes[key]or nil
end
local paletteTex=nil
local function palette()
 if paletteTex==nil then
  paletteTex=false
  pcall(function()
   local d=love.image.newImageData(4,4)
   for i,n in ipairs(PAL_ORDER)do
    local c=PAL[n];local k=i-1
    d:setPixel(k%4,floor(k/4),c[1],c[2],c[3],1)
   end
   local img=love.graphics.newImage(d)
   pcall(img.setFilter,img,'nearest','nearest')
   paletteTex=img
  end)
 end
 return paletteTex or nil
end

------------------------------------------------------------------ the float
local Float={};Float.__index=Float
function F.new(game)
 local self=setmetatable({game=game,slots={},picked=false,yaw=nil,stop=nil,
  anchorX=nil,anchorZ=nil,carrying=false,released=false},Float)
 current=self
 return self
end
local function HF()return V.require('HallOfFame3D')end

-- who rides: your first three, leaving out the one walking at your heels
-- (TEST228: a follower from any of the follower mods, as the Collection's
-- FieldFlyTravel.isFollower knows them; in the map's people or its entities)
local function isFollower(e)
 if type(e)~='table'then return false end
 if e.pikachuFollower==true or e.isPokemonFollower==true or e.pokepcTrailer==true
    or e.wildsFollower==true or e._pokepcFollowerSpecies~=nil or e._wildsFollowerSpecies~=nil
    or e.pokepcMon~=nil then
  return true
 end
 local d=type(e.def)=='table'and e.def or{}
 if tostring(e.name or d.name or''):find('FOLLOWER',1,true)~=nil then return true end
 -- (TEST229: as the Collection's own follower test knows a PokePC trailer)
 if tostring(e.id or''):lower():find('pokepc',1,true)~=nil then return true end
 local sd=type(e.sprite)=='table'and type(e.sprite.def)=='table'and e.sprite.def or nil
 local sid=tostring(e.spriteId or(sd and sd.id)or''):upper()
 return sid:find('POKEPC',1,true)~=nil
end
F.isFollower=isFollower
-- TEST242: the same answer for a person all frame. The character bridge asks
-- it of everyone drawn (twice per pass since TEST239), and it builds strings
-- (tostring, lower, upper) each time. Remembered for the current frame only.
local folMemo,folSerial,folT=setmetatable({},{__mode='k'}),nil,0
local function isFollowerFrame(e)
 if type(e)~='table'then return false end
 local okS,CP=pcall(V.require,'ChampionParade')
 local serial=okS and type(CP)=='table'and tonumber(CP.frameSerial)or nil
 if not serial then return isFollower(e)end
 local okT,t=pcall(love.timer.getTime);t=okT and t or 0
 -- (a new frame, or the frame count standing still for a tenth of a second)
 if serial~=folSerial or abs(t-folT)>.1 then folSerial,folT=serial,t;folMemo=setmetatable({},{__mode='k'})end
 local v=folMemo[e]
 if v==nil then v=isFollower(e)==true;folMemo[e]=v end
 return v
end
F._isFollowerFrame=isFollowerFrame

-- TEST229: WHO WALKS WITH YOU, AND AS WHAT.
-- Under the parade's white card nothing of the overworld runs (the card is
-- the top state, and only the top state updates). A follower mod that brings
-- your partner onto a map from its own update -- Followers EX builds its
-- followers there -- has nobody on the new map until the card lifts; TEST228
-- looked for them there, found nobody, and your Pikachu rode the float as
-- well as walking behind it. So:
--   * who walks is noted before the parade leaves each place, while they are
--     still there (Float:noteWalkers, from ChampionParade before each change
--     of map), and added to whoever is on the new map when the riders are
--     chosen;
--   * a walker is known by the Pokemon it is drawn as: the Collection's
--     overworld models say which (they draw the engine's own trailing partner
--     as your first Pokemon, whatever its sprite); with no Collection, by the
--     species the follower carries, or its sprite;
--   * once the picture is up, the float looks again (every frame for the
--     first second of each place, then twice a second): a rider whose kind is
--     walking after all steps down, and the spare loaded under the card takes
--     its place.
local modRef=nil
local function findMod(id)
 for i=1,2 do
  local m=i==1 and modRef or V.mod
  local find=type(m)=='table'and m.find
  if type(find)=='function'then
   local ok,h=pcall(find,id)
   if not(ok and type(h)=='table')then ok,h=pcall(find,m,id)end
   if ok and type(h)=='table'then return h end
  end
 end
 return nil
end
F._findMod=findMod
local function dexOf(game,species)
 local ok,d=pcall(function()return HF().dexOf(game,species)end)
 return ok and d or nil
end
-- the Collection's overworld models: inside the Collection (mod
-- STADIUM2_IMPORTER, its components), or installed on their own
local function overworldModels()
 local h=findMod('LEGENDARY_STADIUM_OVERWORLD_MODELS')
 local ex=h and h.exports
 local ow=type(ex)=='table'and ex.overworld or nil
 if type(ow)=='table'and type(ow.dexFor)=='function'then return ow end
 local c=findMod('STADIUM2_IMPORTER')
 local col=c and type(c.exports)=='table'and c.exports.collection or nil
 local comps=type(col)=='table'and col.components or nil
 local m=type(comps)=='table'and comps.LEGENDARY_STADIUM_OVERWORLD_MODELS or nil
 ex=type(m)=='table'and m.exports or nil
 ow=type(ex)=='table'and ex.overworld or nil
 if type(ow)=='table'and type(ow.dexFor)=='function'then return ow end
 return nil
end
F._overworldModels=overworldModels
-- the Pokemon the Collection draws this walker as (a National Dex number):
-- only when it can draw it (its model is in your pack). When it cannot, the
-- walker is drawn as its own sprite, which the rest of walkerKind reads.
local function collectionDex(e)
 local ow=overworldModels()
 if not ow then return nil end
 local ok,d
 if type(ow.canRenderEntity)=='function'then
  local okC,can,dex=pcall(ow.canRenderEntity,e)
  if not(okC and can)then return nil end
  ok,d=true,dex
 end
 if d==nil then ok,d=pcall(ow.dexFor,{entity=e,isPlayer=false})end
 d=ok and tonumber(d)or nil
 if not d or d~=d then return nil end
 d=floor(d)
 return d>=1 and d<=251 and d or nil
end
local function walkerKind(game,e)
 local d=collectionDex(e)
 if d then return d end
 local def=type(e.def)=='table'and e.def or{}
 local mon=type(e.pokepcMon)=='table'and e.pokepcMon or(type(e.mon)=='table'and e.mon)or{}
 for _,sp in ipairs({mon.species or false,mon.pokemonSpecies or false,e._pokepcFollowerSpecies or false,
   e.pokepcFollowerSpecies or false,e._wildsFollowerSpecies or false,e.followerSpecies or false,
   e.pokemonSpecies or false,e.stadiumSpecies or false,e.species or false,def.species or false})do
  if type(sp)=='table'then sp=sp.species or sp.id or sp.name end
  if sp then
   local k=dexOf(game,type(sp)=='string'and sp:upper()or sp)
   if k then return k end
  end
 end
 -- (the engine's own trailing partner is Yellow's Pikachu)
 if e.pikachuFollower==true then return dexOf(game,'PIKACHU')end
 -- by its picture: the engine's sprite name (an NPC's `sprite` is its
 -- renderer, the name is in its definition), or a follower mod's sheet
 -- (follower_<SPECIES>.png, pokepc_<SPECIES>.png)
 local names={}
 if type(e.sprite)=='string'then names[#names+1]=e.sprite end
 if type(def.sprite)=='string'then names[#names+1]=def.sprite end
 if type(e.spriteId)=='string'then names[#names+1]=e.spriteId end
 local sd=type(e.sprite)=='table'and type(e.sprite.def)=='table'and e.sprite.def or nil
 if sd and type(sd.id)=='string'then names[#names+1]=sd.id end
 if sd and type(sd.image)=='string'then
  local base=(sd.image:gsub('\\','/'):match('([^/]+)$')or sd.image):gsub('%.[^%.]+$','')
  base=base:gsub('^[Ff][Oo][Ll][Ll][Oo][Ww][Ee][Rr][_%-]',''):gsub('^[Pp][Oo][Kk][Ee][Pp][Cc][_%-]','')
  names[#names+1]='SPRITE_'..base
 end
 for _,n in ipairs(names)do
  local guess=n:upper():match('^SPRITE_(.+)$')
  local k=guess and dexOf(game,guess)
  if k then return k end
 end
 return nil
end
F._walkerKind=walkerKind
-- a follower that is surely a Pokemon (a follower mod's trainer trailers
-- are followers too, but nobody's partner on the float)
local function pokemonMarked(e)
 return e.pikachuFollower==true or e.isPokemonFollower==true or e.wildsFollower==true
  or e.pokepcMon~=nil or e._pokepcFollowerSpecies~=nil or e._wildsFollowerSpecies~=nil
end
-- every Pokemon following you on this map (each once, never you), by kind:
-- a dex number, or true for one marked as a Pokemon whose kind cannot be told
local function walkersIn(game,ow)
 local found,seen={},{}
 for _,list in ipairs({ow and ow.npcs or{},ow and ow.entities or{}})do
  for _,e in ipairs(list)do
   if e~=(ow and ow.player)and not seen[e]and isFollower(e)then
    seen[e]=true
    local k=walkerKind(game,e)
    if k then found[#found+1]=k
    elseif pokemonMarked(e)then found[#found+1]=true end
   end
  end
 end
 return found
end
F._walkersIn=walkersIn
local function tally(list)
 local by,unknown={},0
 for _,k in ipairs(list or{})do
  if k==true then unknown=unknown+1 else by[k]=(by[k]or 0)+1 end
 end
 return by,unknown
end
-- Two looks at who walks with you (before the map changed, and now): the
-- most of each kind either saw, and as many untold walkers as it takes to
-- make up the larger look -- an untold walker on one look may be one the
-- other look told (a follower a frame before its mod gives it its Pokemon),
-- so it is not counted again on top.
local function merged(a,b)
 local A=tally(a)
 local B=tally(b)
 local kinds,out={},{}
 for k in pairs(A)do kinds[#kinds+1]=k end
 for k in pairs(B)do if not A[k]then kinds[#kinds+1]=k end end
 table.sort(kinds)
 local known=0
 for _,k in ipairs(kinds)do
  local n=max(A[k]or 0,B[k]or 0)
  known=known+n
  for _=1,n do out[#out+1]=k end
 end
 for _=1,max(0,max(#(a or{}),#(b or{}))-known)do out[#out+1]=true end
 return out
end
F._merged=merged
-- your team in its order, less one of each kind walking (and, for each
-- walker whose kind cannot be told, the first not yet left out): the first
-- three ride, the next is the spare
local function choose(game,walkers)
 local party=game and game.save and game.save.party or{}
 local by,unknown=tally(walkers)
 local chosen,spare={},nil
 for _,mon in ipairs(party)do
  if type(mon)=='table'and mon.species then
   local k=dexOf(game,mon.species)
   local leave=false
   if k and(by[k]or 0)>0 then leave=true;by[k]=by[k]-1
   elseif unknown>0 then leave=true;unknown=unknown-1 end
   if not leave then
    if #chosen<#F.SLOTS then chosen[#chosen+1]=mon
    elseif not spare then spare=mon end
   end
  end
 end
 return chosen,spare
end
F._choose=choose
-- TEST230: the species name of a National Dex number (for a partner who is
-- not in your team: a follower mod's Pokemon from the PC)
local function speciesOfDex(game,k)
 local defs=game and game.data and game.data.pokemon
 if type(defs)~='table'then return nil end
 local best=nil
 for name,def in pairs(defs)do
  if type(def)=='table'and tonumber(def.dex or def.index)==k then
   if not best or tostring(name)<best then best=tostring(name)end
  end
 end
 return best
end
-- who rides with you: the one walking at your heels (the first of your team
-- whose kind walks; one of another kind that walks), else your first
-- Pokemon. why: 'walking' (it is the one following you), 'guess' (someone
-- is following you, of a kind not told yet: your first, until it is told),
-- 'lead' (nobody was seen walking: your first) or 'none'
local function choosePartner(game,walkers)
 local party=game and game.save and game.save.party or{}
 local by,unknown=tally(walkers)
 for _,mon in ipairs(party)do
  if type(mon)=='table'and mon.species then
   local k=dexOf(game,mon.species)
   if k and(by[k]or 0)>0 then return mon,'walking'end
  end
 end
 local kinds={}
 for k in pairs(by)do kinds[#kinds+1]=k end
 table.sort(kinds)
 for _,k in ipairs(kinds)do
  local sp=speciesOfDex(game,k)
  if sp then return{species=sp},'walking'end
 end
 for _,mon in ipairs(party)do
  if type(mon)=='table'and mon.species then return mon,unknown>0 and'guess'or'lead'end
 end
 return nil,'none'
end
F._choosePartner=choosePartner
-- how tall it stands beside you
local function partnerSize(game,mon)
 local m=nil
 pcall(function()m=HF().dexMetres(game,mon and mon.species)end)
 m=tonumber(m)
 if not(m and m>0)then return F.PARTNER_H end
 return max(F.PARTNER_MIN,min(F.PARTNER_MAX,F.PARTNER_H*(m/1.5)^F.PARTNER_EXP))
end
F._partnerSize=partnerSize
-- where it stands (x across the dais, z along it) from how broad it is,
-- and the float's layout for it: a broad partner a little behind you, the
-- float made longer behind for it
local function layoutFor(width)
 local w=tonumber(width)or 6
 -- clear of your right side (YOU_X+3.1) by a little; at most PARTNER_XMAX
 -- across; what would still overlap you stands back
 local need=F.YOU_X+3.1+.3+w/2
 local x=min(F.PARTNER_XMAX,max(F.PARTNER_X,need))
 local z=min(.8,max(-5.5,.8-max(0,need-x)*1.5-max(0,w-6.2)*.35))
 local rear=min(F.REAR,floor((z-w/2-1.2)*2)/2)
 return{rear=rear,daisW=F.DAIS_W,px=x,pz=z,width=w,key=string.format('r%.1f',rear)}
end
F._layoutFor=layoutFor
local function names(list)
 local out={}
 for _,x in ipairs(list or{})do
  local mon=type(x)=='table'and(x.mon or x)or x
  if type(mon)=='table'then out[#out+1]=tostring(mon.species)
  elseif type(mon)=='number'then out[#out+1]='#'..mon
  else out[#out+1]='a partner of unknown kind'end
 end
 return #out>0 and table.concat(out,', ')or'nobody'
end
-- (the smallest in front, the largest nearest you)
local function bySize(a,b)return(a.want or 0)<(b.want or 0)end
function Float:noteWalkers()
 local game=self.game
 self.walkers=merged(self.walkers,walkersIn(game,game and game.overworld))
 return self.walkers
end
-- TEST230: one rider, your partner, beside you (self.slots holds it, so
-- the cheering and the letting go are as before)
function Float:pick()
 self.picked=true
 local game=self.game
 local ow=game and game.overworld
 local walkers=merged(self.walkers,walkersIn(game,ow))
 self.walkers=walkers
 local mon,why=choosePartner(game,walkers)
 self.slots={}
 self.partner=nil
 if mon then
  self.partner={mon=mon,want=partnerSize(game,mon),model=nil,art=nil,why=why}
  self.slots[1]=self.partner
 end
 log('riding with you: %s (%s); walking: %s',self.partner and names({self.partner})or'nobody',why,names(walkers))
end
local function loadPartner(game,s)
 local ok,md=pcall(function()return HF().newTeamModel(game,s.mon,s.want,F.PARTNER_W)end)
 s.model=ok and md or false
 if not s.model then
  local okA,a=pcall(function()return HF().newTeamArt(game,s.mon)end)
  s.art=okA and a or false
 end
end
local function partnerWidth(s)
 if not s then return nil end
 if s.model and tonumber(s.model.width)then return s.model.width end
 return(s.want or F.PARTNER_H)*.8
end
-- one a frame, under the white card: a model, or failing that the picture
function Float:loadStep()
 if self.released then return false end
 -- (the float itself is built here too, under the card, not on its first frame)
 -- (TEST229: waiting a few frames for a follower mod to put your partner on
 -- the new map does not help -- nothing of the map runs under the card -- so
 -- the riders are chosen from who was walking before the map changed, and
 -- whoever is on it already)
 if not self.picked then
  self.pickWait=(self.pickWait or 0)+1
  if self.pickWait<=F.PICK_FRAMES then return true end
  self:pick();pcall(palette);return true
 end
 -- your partner's model, a frame; then the float made for it
 local s=self.partner
 if s and s.model==nil then loadPartner(self.game,s);return true end
 if not self.layout then
  self.layout=layoutFor(partnerWidth(s))
  self.rear=self.layout.rear
  pcall(floatMesh,self.layout)
  return true
 end
 return false
end
function Float:busy()
 if not self.picked then return true end
 if self.partner and self.partner.model==nil then return true end
 return self.layout==nil
end
-- (TEST230) the load the card waits on, 0..1
function Float:progress()
 if self.released then return 1 end
 if not self.picked then return 0 end
 local k=.35
 if not(self.partner and self.partner.model==nil)then k=.85 end
 if self.layout then k=1 end
 return k
end
-- TEST229: once the picture is up, anyone walking with you who rides as
-- well steps down (and the spare, when it should ride, steps up). Every
-- frame for the first second of each place's picture (a follower mod puts
-- your partner on the map in the first frames after the card lifts, while
-- the white is still fading), then twice a second.
F.RECHECK_FAST,F.RECHECK_GAP=1.2,.5
-- TEST230: (once the picture is up) when the partner beside you was your
-- first Pokemon only because nobody had been seen walking, and someone of
-- another kind turns out to be walking with you, it takes the place.
-- (TEST231: and when it was your first only as a guess -- someone was
-- following you, of a kind not yet told -- it is checked until it is told)
function Float:recheck(t)
 if self.released or not self.picked then return false end
 if t<(self.recheckAt or 0)then return false end
 local since=t-(self.shownAt or t)
 self.recheckAt=t+(since<F.RECHECK_FAST and 0 or F.RECHECK_GAP)
 local p=self.partner
 if p and p.why=='walking'then return false end
 local game=self.game
 local live=walkersIn(game,game and game.overworld)
 if #live==0 then return false end
 local walkers=merged(self.walkers,live)
 self.walkers=walkers
 local mon,why=choosePartner(game,walkers)
 if not mon or why~='walking'then return false end
 local k=dexOf(game,mon.species)
 if p and k and k==dexOf(game,p.mon and p.mon.species)then p.why='walking';return false end
 local hf=HF()
 if p and p.model then pcall(hf.releaseTeamModel,p.model)end
 local s={mon=mon,want=partnerSize(game,mon),model=nil,art=nil,why='walking',cheerAt=p and p.cheerAt}
 loadPartner(game,s)
 self.partner=s;self.slots={s}
 local L=layoutFor(partnerWidth(s))
 if not self.layout or L.key~=self.layout.key then pcall(floatMesh,L)end
 self.layout=L;self.rear=L.rear
 log('%s is the one walking with you: beside you instead of %s',names({s}),p and names({p})or'nobody')
 return true
end
-- TEST230: while the float runs, the Pokemon walking at your heels steps
-- out of the picture: it rides beside you instead (the Collection's models
-- read this; a follower drawn as a card is held back by the float's
-- renderer). Renewed every frame, so it lapses half a second after.
function Float:hideFollowers()
 if self.released then return end
 local ow=self.game and self.game.overworld
 if type(ow)=='table'then ow.legendaryHideFollowers=now()end
end
-- they all cheer, one after another from the front
function Float:cheer(t,gap)
 for k,s in ipairs(self.slots)do s.cheerAt=(t or now())+(k-1)*(gap or .22)end
end

------------------------------------------------------------------ you, on the dais
-- your own pose, lifted: VoxelScene (and a model mod) turn the gap between
-- your place and your pose into height, as they do for a ledge hop; you
-- stand (the first frame, facing the way the float goes)
function Float:lift(ow)
 local p=ow and ow.player
 if not p or self.lifted==p then return end
 self:unlift()
 local inst=rawget(p,'pose')
 local base=p.pose
 if type(base)~='function'then return end
 local me=self
 local fn=function(e,...)
  local sprite,px,py,facing,phase,flip,hop=base(e,...)
  if current~=me or not me.carrying then return sprite,px,py,facing,phase,flip,hop end
  return sprite,px,(tonumber(e.py)or tonumber(py)or 0)-F.LIFT,'down',0,false,false
 end
 rawset(p,'pose',fn)
 self.lifted,self.liftInst,self.liftFn=p,inst,fn
end
function Float:unlift()
 local p=self.lifted
 if p and rawget(p,'pose')==self.liftFn then rawset(p,'pose',self.liftInst)end
 self.lifted,self.liftInst,self.liftFn=nil,nil,nil
end

------------------------------------------------------------------ every frame
local YAW={down=0,up=pi,right=pi/2,left=-pi/2}
function Float:update(dt,t,stopIndex,carrying)
 if self.released then return end
 self:hideFollowers()
 local game=self.game
 local ow=game and game.overworld
 local p=ow and ow.player
 self.carrying=carrying and p and true or false
 if p then self:lift(ow)end
 if not p then return end
 -- TEST229: the picture is up: is anyone riding who walks as well?
 if self.carrying then
  if self.shownStop~=stopIndex then self.shownStop=stopIndex;self.shownAt=t;self.recheckAt=nil end
  self:recheck(t)
 end
 -- where it is: under you, its heading the way you go (snapped at a new stop)
 local x,z=(tonumber(p.px)or(p.cellX or 0)*16)+8,(tonumber(p.py)or(p.cellY or 0)*16)+8
 local y=0
 pcall(function()y=V.require('VoxelScene').groundAt(ow.map,p.cellX,p.cellY,p.px,p.py)or 0 end)
 self.x,self.y,self.z=x,tonumber(y)or 0,z
 local want=YAW[p.facing]or 0
 if self.stop~=stopIndex then
  self.stop=stopIndex
  self.yaw=want
  -- the trainer model's still point for this stop
  self.anchorX,self.anchorZ=tonumber(p.px)or 0,tonumber(p.py)or 0
 else
  local d=(want-(self.yaw or want)+pi)%(2*pi)-pi
  self.yaw=(self.yaw or want)+d*min(1,(dt or 1/60)*2.5)
 end
 -- your partner (TEST230: the only rider)
 local hf=HF()
 for k,s in ipairs(self.slots)do
  local md=s.model
  if md then
   local rec=V.require('ParadeCast').poseOf('partner')
   V.require('ParadePartnerSleep').float(md,rec)
   if rec and rec.sleep then s.cheerAt=nil
   elseif s.cheerAt and t>=s.cheerAt then s.cheerAt=nil;hf.playTeamModel(md,'entrance',true)end
   if not hf.stepTeamModel(md,t,30)then
    V.require('ParadePartnerSleep').release(md)
    hf.releaseTeamModel(md);s.model=false
    s.art=hf.newTeamArt(game,s.mon)or false
   end
  elseif s.art then
   pcall(hf.advanceTeamArt,s.art,dt or 1/60)
  end
 end
end

------------------------------------------------------------------ drawing
local function toWorld(self,lx,ly,lz)
 local c,s=cos(self.yaw or 0),sin(self.yaw or 0)
 return self.x+c*lx+s*lz,self.y+ly,self.z-s*lx+c*lz
end
F._toWorld=toWorld
-- (TEST235) the pose ParadeCast holds for you or your partner, when it
-- tips you (nil: upright, as ever)
F.PLAYER_KEY,F.PARTNER_KEY='player','partner'
local function posed(key)
 local okC,CP=pcall(V.require,'ParadeCast')
 if not(okC and type(CP)=='table'and CP.poseOf)then return nil end
 local rec=CP.poseOf(key)
 if rec and CP.tipped(rec)then return rec end
 return nil
end
F._posed=posed
-- a picture's card through Voxel3D.draw as it is at the call (tipped while
-- ParadeCast swaps it)
local function drawCard(R,mesh,img,m,pull)return R.draw(mesh,img,m,pull)end
-- (TEST231) where your partner stands on the dais this frame (x across,
-- z along) and how far it is turned from the way the float goes: toward
-- its own side, +x (a model faces (sin yaw, cos yaw)), and back. With no
-- model drawing you -- the engine's card then stands at the dais's middle,
-- a whole cell wide -- it stands at the far side and a step back, not
-- inside your card.
local function partnerPlace(self,t)
 local L=self.layout or layoutFor(nil)
 local px,pz=L.px,L.pz
 if not(self.youModelAt and now()-self.youModelAt<F.YOU_MODEL_FRESH)then
  px=max(px,F.PARTNER_XMAX)
  pz=max(L.pz-F.CARD_STEP_BACK,(self.rear or F.REAR)+(L.width or 6)/2+.6)
 end
 return px,pz,.18+.16*sin((tonumber(t)or 0)*.5+1.3)
end
F._partnerPlace=partnerPlace
-- TEST235: where you ('player') or your partner ('partner') stand on the
-- dais: your feet (world), the way you face, the middle of your head above
-- your feet (nil: nobody there)
function Float:riderFeet(which)
 if self.released or not self.x then return nil end
 if which==F.PARTNER_KEY then
  local s=self.partner
  if not(s and(s.model or s.art))then return nil end
  local px,pz,turn=partnerPlace(self,now())
  local x,y,z=toWorld(self,px,F.LIFT,pz)
  return x,y,z,(self.yaw or 0)+turn,(s.want or F.PARTNER_H)*.72
 end
 -- (your model stands a step to the left; the engine's card, in the middle)
 local modelOn=self.youModelAt and now()-self.youModelAt<F.YOU_MODEL_FRESH
 local x,y,z=toWorld(self,modelOn and F.YOU_X or 0,F.LIFT,0)
 return x,y,z,self.yaw or 0,13
end
function Float:draw(K,t,night)
 if self.released or not self.x then return end
 local R=V.require('Voxel3D')
 local Mat4=V.require('Mat4')
 local g=love.graphics
 local m,tex=floatMesh(self.layout),palette()
 local world=Mat4.mul(Mat4.translate(self.x,self.y,self.z),Mat4.rotateY(self.yaw or 0))
 local rear=self.rear or F.REAR
 -- its shadow on the road
 if K and K.quad and K.soft then
  pcall(R.withEffect,'alpha',function()
   local cx,cy,cz=toWorld(self,0,.08,(rear+F.NOSE)/2)
   g.setColor(0,0,0,.40)
   R.draw(K.quad,K.soft,Mat4.mul(Mat4.translate(cx,cy,cz),Mat4.mul(Mat4.rotateY(self.yaw or 0),
    Mat4.scale(F.HALF_W+3,1,(F.NOSE-rear)/2+3))))
  end)
  g.setColor(1,1,1,1)
 end
 -- the float (lit; both faces, whichever way a quad winds; no voxel seams,
 -- no window lamplight)
 if m and tex then
  local cull=nil
  pcall(function()cull=g.getMeshCullMode();g.setMeshCullMode('none')end)
  if R.seams then R.seams(false)end
  if R.glass then R.glass(false)end
  g.setColor(1,1,1,1)
  pcall(R.draw,m,tex,world)
  if R.glass then R.glass(true)end
  if R.seams then R.seams(true)end
  if cull then pcall(g.setMeshCullMode,cull)end
 end
 -- your partner beside you: its model (in its own saved state: a model
 -- draws with its own shader), or its picture. (TEST230: it turns a little
 -- toward the crowd on its side, and back, as it rides. TEST231: toward its
 -- own side, +x -- a model faces (sin yaw, cos yaw), so that is +yaw;
 -- TEST230 turned it toward you)
 local hf=HF()
 local px,pz,turn=partnerPlace(self,t)
 local function spot()return toWorld(self,px,F.LIFT,pz)end
 -- (TEST235: tipped, when the parade has posed your partner)
 local pose=posed(F.PARTNER_KEY)
 for k,s in ipairs(self.slots)do
  if s.model then
   local x,y,z=spot()
   local yaw=(self.yaw or 0)+turn
   g.push('all')
   local ok,drawn
   if pose then ok,drawn=pcall(V.require('ParadeCast').drawStadium,s.model,x,y,z,yaw,pose,1)
   else ok,drawn=pcall(hf.drawTeamModel,s.model,x,y,z,yaw,1,0)end
   g.pop()
   if not(ok and drawn)then hf.releaseTeamModel(s.model);s.model=false;s.art=hf.newTeamArt(self.game,s.mon)or false end
  end
 end
 local pics=false
 for _,s in ipairs(self.slots)do if not s.model and s.art then pics=true end end
 if pics then
  local okB,BB=pcall(V.require,'BattleBillboard')
  if okB and BB then
   R.lighting(false)
   if R.seams then R.seams(false)end
   for k,s in ipairs(self.slots)do
    local a=s.art
    if a and not s.model then
     local scale=(s.want or F.PARTNER_H)/F.PICTURE_H
     local px,py,pz=spot()
     local yaw=BB.yawToward(px,pz,R.eye)
     local w,h=a.w*scale,a.h*scale
     local x=px-cos(yaw)*a.cx*scale
     local z=pz+sin(yaw)*a.cx*scale
     g.setColor(1,1,1,1)
     if pose then
      V.require('ParadeCast').withPose(pose,px,py,pz,'drawEntity',drawCard,R,BB.mesh(),a.frames[a.frame]or a.frames[1],
       BB.matrix(x,py-a.foot*scale,z,w,h,yaw),BB.PULL)
     else
      pcall(R.draw,BB.mesh(),a.frames[a.frame]or a.frames[1],BB.matrix(x,py-a.foot*scale,z,w,h,yaw),BB.PULL)
     end
    end
   end
   if R.seams then R.seams(true)end
   R.lighting(true)
  end
 end
 -- after dark, a string of lights round the deck
 if night and night>0 and K and K.cross and K.soft then
  pcall(R.withEffect,'add',function()
   local tw=t*2.2
   for side=-1,1,2 do
    for z=rear+1,F.DECK_END-1,3.5 do
     local x,y,zz=toWorld(self,side*(F.HALF_W+.5),4.7,z)
     local f=.75+.25*sin(tw+z*.7+side)
     g.setColor(1,.84,.50,.55*night*f)
     R.draw(K.cross,K.soft,Mat4.mul(Mat4.translate(x,y,zz),Mat4.scale(1.6,1.6,1.6)))
    end
   end
   -- and a glow on the star
   local x,y,z=toWorld(self,0,8.9,36.9)
   g.setColor(1,.86,.45,.35*night)
   R.draw(K.cross,K.soft,Mat4.mul(Mat4.translate(x,y,z),Mat4.scale(6,6,6)))
  end)
  g.setColor(1,1,1,1)
 end
end

-- TEST226: where the cannons fire from, and which way (up, forward, out)
function Float:cannonPoints()
 if self.released or not self.x then return nil end
 local out={}
 for _,c in ipairs(F.CANNONS)do
  local side=c.x>0 and 1 or-1
  local x,y,z=toWorld(self,c.x,c.y,c.z)
  local ax,ay,az=toWorld(self,c.x+side*.30,c.y+1,c.z+.50)
  out[#out+1]={muzzle={x,y,z},dir={ax-x,ay-y,az-z}}
 end
 return out
end

function Float:release()
 if self.released then return end
 self.released=true
 self.carrying=false
 local hf=nil;pcall(function()hf=HF()end)
 local list={}
 for _,s in ipairs(self.slots)do list[#list+1]=s end
 if self.spare then list[#list+1]=self.spare;self.spare=nil end
 for _,s in ipairs(list)do
  if s.model and hf then
   pcall(function()V.require('ParadePartnerSleep').release(s.model)end)
   pcall(hf.releaseTeamModel,s.model)
  end
  s.model=false;s.art=nil
 end
 -- (your partner walks at your heels again half a second later)
 self:unlift()
 if current==self then current=nil end
end
F.Float=Float

------------------------------------------------------------------ the trainer model's idle
-- A trainer model mod (the Collection's player models) animates its walk
-- from your movement: the moving flag, the cell you are stepping to, and the
-- distance you travel between frames. On the float you are carried, not
-- walking: so while the float carries you, the model is handed your pose
-- held still at where the float started this stop, with the step flags put
-- aside for the length of its draw; and its drawing is moved, by a wrapped
-- Voxel3D.draw in the services it is given, to where you really are. The
-- engine's own card needs none of this (the lifted pose stands it still).
-- (Its shadow too: a model mod's shadow pass runs first, and reads the same
-- movement; and the way the model faces is set from that movement as well,
-- so it is held to the float's heading while it rides.)
local CR,origFirst=nil,nil
local DRAWS={drawEntity=true,drawReflection=true,drawShadow=true}
local function carried(method,ctx)
 local f=current
 if not(f and f.carrying and not f.released and f.anchorX and DRAWS[method])then return nil end
 if type(ctx)~='table'or not(ctx.isPlayer==true or ctx.role=='player')then return nil end
 if type(ctx.pose)~='table'then return nil end
 return f
end
-- TEST230: a Pokemon following you, while the float runs (it rides beside
-- you instead): its card, shadow and reflection are held back
local function followerOnFloat(method,ctx)
 local f=current
 if not(f and not f.released and DRAWS[method])then return false end
 if type(ctx)~='table'or ctx.isPlayer==true or ctx.role=='player'then return false end
 local e=ctx.actor or ctx.entity or(type(ctx.pose)=='table'and ctx.pose.entity)
 if type(e)~='table'then return false end
 local ow=f.game and f.game.overworld
 if ow and e==ow.player then return false end
 return isFollowerFrame(e)
end
F._followerOnFloat=followerOnFloat
-- TEST235: your trainer tipped by the parade (the 'player' pose), walking
-- or riding: nil when you stand as ever
local function playerPose(method,ctx)
 if not(method=='drawEntity'or method=='drawShadow')then return nil end
 if type(ctx)~='table'or not(ctx.isPlayer==true or ctx.role=='player')then return nil end
 return posed(F.PLAYER_KEY)
end
F._playerPose=playerPose
-- Called only after every registered model provider declined. This also
-- covers follower species with no 3D model: their engine sprite falls with
-- the same pose. The Collection's Stadium draw runs before this chain.
local function modelOrCard(method,ctx,...)
 local claimed=origFirst(method,ctx,...)
 if claimed then return claimed end
 local p=ctx.pose
 if not(p and p.sprite)then return false end
 local Scene=V.require('VoxelScene')
 local draw=method=='drawShadow'and Scene.drawEntityShadow or Scene.drawEntity
 if type(draw)~='function'then return false end
 return draw(p.sprite,p.px,p.py,ctx.facing or p.facing,p.phase,p.flip,p.gh,p.colors,p.lift,p.visualAnchorY)
end
local function wrappedFirst(method,ctx,...)
 if followerOnFloat(method,ctx)then return true end
 local f=carried(method,ctx)
 if not f then
  local rec=playerPose(method,ctx)
  if not rec and(method=='drawEntity'or method=='drawShadow')and type(ctx)=='table'then
   local e=ctx.actor or ctx.entity or(type(ctx.pose)=='table'and ctx.pose.entity)
   if isFollowerFrame(e)then rec=posed(F.PARTNER_KEY)end
  end
  if rec then
   local ok,res=V.require('ParadeCast').withPose(rec,(tonumber(ctx.px)or 0)+8,
    (tonumber(ctx.groundHeight)or 0)+(tonumber(ctx.lift)or 0),(tonumber(ctx.py)or 0)+8,method,modelOrCard,method,ctx,...)
   if ok then return res end
   log('your trainer, tipped: %s',tostring(res))
   return false
  end
  return origFirst(method,ctx,...)
 end
 local p=ctx.pose
 local actor=ctx.actor or ctx.entity or ctx.player
 local dx=(tonumber(p.px)or f.anchorX)-f.anchorX
 local dz=(tonumber(p.py)or f.anchorZ)-f.anchorZ
 local R=V.require('Voxel3D')
 local Mat4=V.require('Mat4')
 -- (TEST230: and a step to the left on the dais, your partner at your right)
 local c0,s0=cos(f.yaw or 0),sin(f.yaw or 0)
 local T=Mat4.translate(dx+c0*F.YOU_X,0,dz-s0*F.YOU_X)
 local moved=setmetatable({draw=function(m,tex,model,pull,sun,...)
  return R.draw(m,tex,Mat4.mul(T,model or Mat4.identity()),pull,sun and Mat4.mul(T,sun)or nil,...)
 end},{__index=R})
 local host={}
 for k,v in pairs(type(ctx.host)=='table'and ctx.host or{})do host[k]=v end
 host.Voxel3D=moved
 -- the shadow pass draws through the host's ShadowMap: moved the same way
 -- (ShadowMap.snug, a nudge toward the sun, is a translation too)
 local SM=host.ShadowMap
 if type(SM)~='table'then local okS,S=pcall(V.require,'ShadowMap');SM=okS and S or nil end
 if type(SM)=='table'then
  host.ShadowMap=setmetatable({draw=function(m,tex,model,...)
   return SM.draw(m,tex,Mat4.mul(T,model or Mat4.identity()),...)
  end},{__index=SM})
 end
 local pose={}
 for k,v in pairs(p)do pose[k]=v end
 pose.px,pose.py=f.anchorX,f.anchorZ
 local c={}
 for k,v in pairs(ctx)do c[k]=v end
 c.pose,c.px,c.py,c.host=pose,f.anchorX,f.anchorZ,host
 local saved=nil
 if type(actor)=='table'then
  saved={actor.moving,actor.targetX,actor.targetY,actor.stepLanded,actor.bumpFrames}
  actor.moving=false;actor.targetX=nil;actor.targetY=nil;actor.stepLanded=nil;actor.bumpFrames=nil
  -- the way the body faces: the way the float goes (a model mod keeps the
  -- heading of your last real movement otherwise -- which, on the float, is
  -- wherever you last walked before it, not where it is going)
  actor.pmlFreeBodyYaw=f.yaw or 0
 end
 local ok,res
 -- (TEST235: tipped about your feet on the dais, when the parade poses you)
 local rec=playerPose(method,ctx)
 if rec then
  local fx,fy,fz=toWorld(f,F.YOU_X,F.LIFT,0)
  ok,res=V.require('ParadeCast').withPose(rec,fx,fy,fz,method,origFirst,method,c,...)
 else
  ok,res=pcall(origFirst,method,c,...)
 end
 -- (TEST231: your model drew you: the partner stands where it was placed)
 if ok and res==true and method=='drawEntity'then f.youModelAt=now()end
 if saved then
  actor.moving,actor.targetX,actor.targetY,actor.stepLanded,actor.bumpFrames=saved[1],saved[2],saved[3],saved[4],saved[5]
 end
 -- (a failure here leaves the engine's own card to stand in, this frame)
 if not ok then log('the trainer model on the float: %s',tostring(res));return false end
 return res
end
function F.install(mod)
 if type(mod)=='table'then modRef=mod end
 if origFirst then return end
 local ok,mod=pcall(V.require,'CharacterRenderers')
 if ok and type(mod)=='table'and type(mod.first)=='function'then
  CR,origFirst=mod,mod.first
  mod.first=function(method,ctx,...)return wrappedFirst(method,ctx,...)end
  F._wrapped=mod.first
 end
end
function F.dispose()
 if current then pcall(current.release,current)end
 current=nil
 modRef=nil
 -- (only let go of the original if it was put back: if another mod has
 -- wrapped over this one since, the wrap stays in its chain as a plain
 -- pass-through -- with no float it hands every call straight on)
 if CR and origFirst and CR.first==F._wrapped then
  CR.first=origFirst
  CR,origFirst,F._wrapped=nil,nil,nil
 end
 for k,m in pairs(meshes)do if m then pcall(m.release,m)end;meshes[k]=nil end
 if paletteTex then pcall(paletteTex.release,paletteTex)end
 paletteTex=nil
end
F._current=function()return current end
return F
