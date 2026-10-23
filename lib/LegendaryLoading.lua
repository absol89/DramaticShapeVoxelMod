-- TEST143: playful Pokemon loading cards. Presentation only: no map loads,
-- gameplay hooks or shaders. Everything moves on the veil's clock.
--
--   * Bright, type-coloured backdrop with sliding stripes and a big turning
--     Poke Ball watermark, a red "NOW ENTERING" banner and a bouncy title.
--   * "WHO'S THAT POKEMON?": an area Pokemon as a black silhouette on a
--     spinning burst, then the reveal ("It's GASTLY!"), cycling.
--   * Your party parades and hops along the bottom.
--   * A "DID YOU KNOW?" bubble with area facts.
--   * A Poke Ball that wobbles while the area loads (shake, shake, shake) and
--     clicks shut with stars when it is ready. It is an activity indicator,
--     not a measured progress bar.
-- Sprites come from the player's own installed battle art (selected
-- generation), then the game's built-in front sprite, else they are skipped.
local V=...
local M={}
local fonts={}
local pi,sin,cos,floor,min,max,abs=math.pi,math.sin,math.cos,math.floor,math.min,math.max,math.abs
local city={
 PALLET_TOWN={'Pallet Town','Where every journey begins.','village'},
 VIRIDIAN_CITY={'Viridian City','A green gateway to the wider world.','forest'},
 PEWTER_CITY={'Pewter City','Stone, history, and the road ahead.','stone'},
 CERULEAN_CITY={'Cerulean City','Follow the water. Find your next adventure.','water'},
 VERMILION_CITY={'Vermilion City','Salt air and a horizon full of possibility.','coast'},
 LAVENDER_TOWN={'Lavender Town','A quiet town with stories to remember.','lavender'},
 CELADON_CITY={'Celadon City','Gardens, bright lights, and hidden corners.','city'},
 SAFFRON_CITY={'Saffron City','At the crossroads of Kanto.','psychic'},
 FUCHSIA_CITY={'Fuchsia City','A little closer to the wild.','forest'},
 CINNABAR_ISLAND={'Cinnabar Island','An island shaped by fire and sea.','island'},
 INDIGO_PLATEAU={'Indigo Plateau','One last climb. A new legend.','stone'},
 OAKS_LAB={"Oak's Laboratory",'Every great discovery starts with curiosity.','village'},
 REDS_HOUSE_1F={"Red's Home",'There is always a place to come back to.','village'},
 REDS_HOUSE_2F={"Red's Bedroom",'The beginning of something legendary.','village'},
}
local tips={
 forest='Take a moment to look up through the canopy.',
 cave='CAVE DETAILS changes the mist, crystals, and light shafts.',
 coast='Explore the waterfront when the town lights come on.',
 island='Follow the palms along the waterfront.',
 city='Rooftops and upstairs windows offer a different view of Kanto.',
 psychic='Rooftops and upstairs windows offer a different view of Kanto.',
 lavender='Come back after sunset to see the town lights.',
 water='Watch the water from the bridges and banks.',
 stone='Look for the details in each town\'s architecture.',
 village='Halloween and Harvest bring autumn colors to the scenery.',
}
-- Area Pokemon for the quiz and the backup parade (engine species keys).
local POOL={
 village={'PIDGEY','RATTATA','BULBASAUR','CHARMANDER','SQUIRTLE'},
 forest={'CATERPIE','WEEDLE','PIKACHU','METAPOD','ODDISH','BELLSPROUT'},
 stone={'GEODUDE','ONIX','KABUTO','OMANYTE','SANDSHREW'},
 water={'PSYDUCK','GOLDEEN','SLOWPOKE','STARYU','POLIWAG'},
 coast={'KRABBY','TENTACOOL','SHELLDER','MAGIKARP','SEEL'},
 lavender={'GASTLY','HAUNTER','CUBONE','GENGAR'},
 city={'EEVEE','ODDISH','MEOWTH','PORYGON','VULPIX'},
 psychic={'ABRA','KADABRA','DROWZEE','JYNX'},
 island={'GROWLITHE','PONYTA','VULPIX','MAGMAR','KOFFING'},
 cave={'ZUBAT','GEODUDE','CLEFAIRY','PARAS','ONIX','DIGLETT'},
}
-- Background type colours: {top, bottom, stripe, burst A, burst B}.
local THEME={
 village={{1,.62,.36},{.93,.36,.25},{1,1,1},{1,.86,.30},{1,.64,.18}},
 forest={{.56,.86,.42},{.22,.62,.34},{1,1,1},{.96,.92,.36},{.70,.90,.30}},
 stone={{.86,.74,.52},{.62,.48,.32},{1,1,1},{1,.86,.46},{.92,.66,.30}},
 water={{.50,.80,1},{.20,.48,.92},{1,1,1},{1,.92,.40},{.40,.86,1}},
 coast={{.44,.86,.96},{.16,.52,.80},{1,1,1},{1,.90,.42},{.56,.94,1}},
 lavender={{.72,.56,.94},{.36,.22,.58},{1,1,1},{.86,.70,1},{.58,.40,.90}},
 city={{1,.90,.40},{.96,.60,.20},{1,1,1},{1,1,.60},{1,.78,.26}},
 psychic={{1,.62,.80},{.78,.30,.62},{1,1,1},{1,.84,.92},{1,.56,.80}},
 island={{1,.66,.36},{.86,.24,.18},{1,1,1},{1,.88,.36},{1,.52,.20}},
 cave={{.66,.54,.46},{.30,.22,.20},{1,1,1},{.86,.72,1},{.62,.50,.90}},
}
local FACTS={
 PALLET_TOWN={'Pallet Town is where Professor Oak hands out first partners.','Your mom keeps the house ready for when you come home.'},
 VIRIDIAN_CITY={'Viridian City\'s Gym stays locked for a long time...','The forest north of town is full of Bug-type Pokemon.'},
 PEWTER_CITY={'Pewter City\'s museum keeps fossils of ancient Pokemon.','Brock\'s Gym is all about rock-solid defense.'},
 CERULEAN_CITY={'Misty\'s Gym in Cerulean City specializes in Water types.','A bridge north of town is famous for its trainers.'},
 VERMILION_CITY={'The S.S. Anne docks at Vermilion City\'s harbor.','Lt. Surge\'s Gym is guarded by a trash-can puzzle!'},
 LAVENDER_TOWN={'Pokemon Tower is home to many Ghost-type Pokemon.','A Silph Scope reveals what hides in the tower\'s fog.'},
 CELADON_CITY={'Celadon\'s department store has a rooftop with vending machines.','The Game Corner hides a secret beneath its floor...'},
 SAFFRON_CITY={'Silph Co. builds Poke Balls in Saffron City.','Saffron has two Gyms, but only one is official.'},
 FUCHSIA_CITY={'The Safari Zone lets you catch Pokemon with bait and rocks.','Koga\'s Gym is full of invisible walls.'},
 CINNABAR_ISLAND={'Cinnabar Island\'s lab can revive fossils.','Blaine\'s Gym quiz rewards the right answers.'},
 INDIGO_PLATEAU={'The Elite Four wait at the top of Indigo Plateau.','Only trainers with eight badges may enter.'},
}
local KIND_FACTS={
 cave={'Zubat have no eyes. They find their way with sound!','Clefairy are said to gather under the full moon.','Geodude love to sit still and blend in with the rocks.'},
 forest={'Caterpie evolve faster than almost any Pokemon.','Pikachu that live together charge each other up.'},
 water={'Psyduck always seem to have a headache.','Goldeen are known as the queens of the water.'},
 coast={'Magikarp may be weak, but they never give up.','Krabby can regrow a lost claw.'},
 village={'Pidgey are gentle and avoid fights when they can.','Every trainer starts with just one Pokemon.'},
 lavender={'Gastly are made almost entirely of gas.','Cubone wear a skull to hide their face.'},
 city={'Eevee can evolve in many different ways.','Meowth love shiny coins.'},
 psychic={'Abra sleep up to eighteen hours a day.','Kadabra\'s spoon makes its powers stronger.'},
 island={'Growlithe are loyal and brave.','Ponyta\'s mane is made of flames.'},
 stone={'Onix can tunnel at amazing speeds.','Fossils hold the secrets of ancient Pokemon.'},
}
function M.describe(value)
 local id=type(value)=='table'and value.id or value
 id=tostring(id or 'KANTO'):upper()
 local row=city[id]
 if row then return {id=id,title=row[1],line=row[2],kind=row[3],tip=tips[row[3]]}end
 local kind='village'
 if id:find('FOREST')or id:find('SAFARI')then kind='forest'
 elseif id:find('CAVE')or id:find('TUNNEL')or id:find('MT_MOON')or id:find('SEAFOAM')or id:find('VICTORY_ROAD')then kind='cave'
 elseif id:find('SS_ANNE')or id:find('SEA_ROUTE')then kind='coast'
 elseif id:find('ROUTE')then kind='forest'
 elseif id:find('TOWER')then kind='lavender'
 elseif id:find('SILPH')or id:find('SAFFRON')then kind='psychic'
 elseif id:find('MART')or id:find('GAME_CORNER')or id:find('CELADON')then kind='city'end
 local title=id:gsub('_',' '):lower():gsub('(%a)([%w]*)',function(a,b)return a:upper()..b end)
 title=title:gsub('(%d)f','%1F'):gsub('Ss Anne','S.S. Anne'):gsub('Mt Moon','Mt. Moon')
 return {id=id,title=title,line=kind=='cave'and'A little deeper into the unknown.'or'Another corner of Kanto. Another story to discover.',kind=kind,tip=tips[kind]}
end

------------------------------------------------------------------ helpers
local function font(g,n)
 n=floor(n+.5)
 if not fonts[n]then fonts[n]=g.newFont(n)end
 g.setFont(fonts[n]);return fonts[n]
end
local function color(g,c,a)g.setColor(c[1],c[2],c[3],a or 1)end
local INK={.12,.12,.18}
local WHITE={1,1,1}
local RED={.89,.20,.20}
local YELLOW={1,.84,.18}
local BLUE={.18,.36,.78}
-- Chunky outlined text: dark outline then the fill, like a game logo.
local function bold(g,s,x,y,n,fill,outline,ow,scale,a)
 local f=font(g,n);scale=scale or 1;ow=ow or max(2,n/14);a=a or 1
 color(g,outline or INK,a)
 for i=0,7 do local ang=i*pi/4
  g.print(s,x+cos(ang)*ow,y+sin(ang)*ow,0,scale,scale)
 end
 color(g,fill or WHITE,a);g.print(s,x,y,0,scale,scale)
 return f:getWidth(s)*scale
end
local function fit(g,s,n,maxW)local f=font(g,n);return min(1,maxW/max(1,f:getWidth(s)))end
local function pokeball(g,x,y,r,rot,closed)
 g.push();g.translate(x,y);g.rotate(rot or 0)
 color(g,INK);g.circle('fill',0,0,r+max(2,r*.09))
 color(g,RED);g.arc('fill',0,0,r,pi,2*pi)
 color(g,WHITE);g.arc('fill',0,0,r,0,pi)
 color(g,{1,.55,.55},.55);g.arc('fill',-r*.25,-r*.35,r*.35,pi*1.15,pi*1.6)   -- shine
 color(g,INK);g.rectangle('fill',-r,-r*.09,r*2,r*.18)
 g.circle('fill',0,0,r*.33)
 color(g,WHITE);g.circle('fill',0,0,r*.22)
 if closed then color(g,YELLOW,.8);g.circle('fill',0,0,r*.12)end
 g.pop()
end
local function star(g,x,y,r,c,a,rot)
 local pts={}
 for i=0,9 do local rr=i%2==0 and r or r*.45;local ang=(rot or 0)+i*pi/5-pi/2
  pts[#pts+1]=x+cos(ang)*rr;pts[#pts+1]=y+sin(ang)*rr
 end
 color(g,c,a)
 -- fill as a fan of triangles from the centre (star is concave)
 for i=1,#pts-2,2 do local j=i+2>#pts and 1 or i+2
  g.polygon('fill',x,y,pts[i],pts[i+1],pts[j],pts[j+1])
 end
 g.polygon('fill',x,y,pts[#pts-1],pts[#pts],pts[1],pts[2])
end

------------------------------------------------------------------ sprites
local sprites={}
local loadsThisPaint=0
local function party()
 local out={}
 local ok,Game=pcall(require,'src.core.Game')
 local save=ok and Game and Game.save
 local list=save and(save.party or(save.player and save.player.party))
 if type(list)=='table'then
  for _,mon in ipairs(list)do
   local sp=type(mon)=='table'and(mon.species or mon.id or mon.name)or mon
   if type(sp)=='string'then out[#out+1]=sp:upper()end
   if #out>=6 then break end
  end
 end
 return out
end
local function loadSprite(species)
 local rec=sprites[species]
 if rec~=nil then return rec or nil end
 if loadsThisPaint>=1 then return nil end   -- spread decoding over frames
 loadsThisPaint=loadsThisPaint+1
 local frames,durations
 -- TEST146: colour first. Gen 1 art (animated atlas and the engine sprite)
 -- is the original greyscale Red/Blue art; battles tint it with a palette,
 -- this card has none. So: the chosen generation unless it is Gen 1, then
 -- the colour static front (the art the party menu shows), then colour
 -- animated generations, and greyscale Gen 1 only as a last resort.
 local okB,BattleArt=pcall(V.require,'BattleArt')
 local okA,Anim=pcall(V.require,'AnimatedBattleArt')
 if not okB then BattleArt=nil end;if not okA then Anim=nil end
 local display
 pcall(function()display=BattleArt.displayMode and BattleArt.displayMode()end)
 local function animated(gen)
  if frames and frames[1] or not(Anim and Anim.interfaceFront and gen)then return end
  pcall(function()frames,durations=Anim.interfaceFront(species,gen,display)end)
  if not(frames and frames[1])then frames,durations=nil,nil end
 end
 local mode,chosen
 pcall(function()mode=BattleArt.setting:get();chosen=BattleArt.frontAnimationSetting:get()end)
 if mode=='animated' and chosen~='gen1' then animated(chosen)end
 if not(frames and frames[1])and BattleArt and BattleArt.interfaceStaticFrontImage then
  pcall(function()
   local img=BattleArt.interfaceStaticFrontImage(species,display)
   if img then frames,durations={img},nil end
  end)
 end
 for _,gen in ipairs({'gen5','gen3','gen4','gen2'})do animated(gen)end
 animated('gen1')
 if not(frames and frames[1])then
  pcall(function()
   -- the game's own built-in front sprite
   local Game=require('src.core.Game')
   local def=Game.data and Game.data.pokemon and Game.data.pokemon[species]
   local path=def and def.spriteFront
   local Assets=require('src.render.Assets')
   local data=path and Assets.imageData and Assets.imageData(path)
   local img=data and BattleArt.prepareData(data,display)
   if img then frames={img}end
  end)
 end
 if frames and frames[1]then
  rec={frames=frames,durations=durations or {}}
  local total=0
  for i=1,#frames do total=total+(tonumber(rec.durations[i])or 100)end
  rec.total=total
  sprites[species]=rec
  return rec
 end
 sprites[species]=false
 return nil
end
local function frameAt(rec,t)
 if #rec.frames==1 then return rec.frames[1]end
 local ms=(t*1000)%rec.total
 for i=1,#rec.frames do
  ms=ms-(tonumber(rec.durations[i])or 100)
  if ms<0 then return rec.frames[i]end
 end
 return rec.frames[#rec.frames]
end
-- Draw a sprite standing on (x,y), fitted to `size` pixels tall at most.
local function drawSprite(g,rec,t,x,y,size,tint,flip)
 local img=frameAt(rec,t)
 local w,h=img:getDimensions()
 local s=size/max(w,h)
 color(g,tint or WHITE)
 g.draw(img,x-(flip and -1 or 1)*w*s/2,y-h*s,0,(flip and -1 or 1)*s,s)
 return w*s,h*s
end

------------------------------------------------------------------ scene
local function backdrop(g,W,H,th,t)
 for i=0,31 do local k=i/31
  g.setColor(th[1][1]+(th[2][1]-th[1][1])*k,th[1][2]+(th[2][2]-th[1][2])*k,th[1][3]+(th[2][3]-th[1][3])*k,1)
  g.rectangle('fill',0,H*i/32,W,H/32+1)
 end
 -- sliding diagonal stripes
 local off=(t*40)%80
 color(g,th[3],.10)
 for x=-H-80+off,W+80,80 do g.polygon('fill',x,H,x+40,H,x+40+H,0,x+H,0)end
 -- big turning Poke Ball watermark
 g.push();g.translate(W*.80,H*.58);g.rotate(t*.25)
 local r=H*.52
 g.setLineWidth(r*.08);color(g,WHITE,.10)
 g.circle('line',0,0,r);g.line(-r,0,-r*.3,0);g.line(r*.3,0,r,0)
 g.circle('line',0,0,r*.3)
 g.pop()
 -- floating dots
 for i=1,26 do local x=(i*173+t*(10+i%5*6))%(W+40)-20;local y=(i*97)%H
  color(g,WHITE,.10+.08*sin(t*2+i));g.circle('fill',x,y,2+i%4)
 end
end
local function banner(g,W,info,t)
 color(g,RED);g.rectangle('fill',0,0,W,64)
 color(g,{.70,.10,.12});g.rectangle('fill',0,58,W,8)
 color(g,INK);g.rectangle('fill',0,66,W,4)
 pokeball(g,40,32,18,t*1.5)
 bold(g,'NOW ENTERING',70,16,26,WHITE,INK,2)
 local f=font(g,13);color(g,WHITE,.9)
 local tag='LEGENDARY  BATTLE  ART'
 g.print(tag,W-f:getWidth(tag)-28,24)
end
-- Title letters drop in one by one with a little bounce.
local function title(g,info,W,e)
 local s=info.title;local n=72
 local k=fit(g,s,n,W*.56)
 local f=font(g,n)
 local x,y=44,96
 for i=1,#s do
  local ch=s:sub(i,i)
  local d=e-.05*(i-1)
  local p=max(0,min(1,d/.35))
  local bounce=(1-p)*-60+sin(p*pi)*-10
  if p>0 then bold(g,ch,x,y+bounce,n,YELLOW,BLUE,4,k,min(1,p*2))end
  x=x+f:getWidth(ch)*k
 end
 -- tagline pill
 local line=info.line;local lk=fit(g,line,20,W*.52)
 local lw=font(g,20):getWidth(line)*lk
 color(g,WHITE,.92);g.rectangle('fill',40,96+n*k+14,lw+28,34,17,17)
 color(g,INK);g.print(line,54,96+n*k+21,0,lk,lk)
end
-- The mystery Pokemon for round `ahead` rounds from now (6 s rounds).
local function mystery(info,e,ahead)
 local pool=POOL[info.kind]or POOL.village
 local n=floor(e/6)+(ahead or 0)
 local seed=0;for i=1,#info.id do seed=seed+info.id:byte(i)end
 return pool[(seed+n)%#pool+1]
end
local trySnap,snapPending,drawShot
local function whosThat(g,W,H,info,e,t)
 local cycle=6;local k=(e%cycle)/cycle
 local species=mystery(info,e)
 local th=THEME[info.kind]or THEME.village
 local cx,cy,R=W*.76,H*.47,H*.30
 -- spinning burst
 g.push();g.translate(cx,cy);g.rotate(t*.4)
 for i=0,15 do local a0,a1=i*pi/8,(i+.5)*pi/8
  color(g,i%2==0 and th[4]or th[5])
  g.polygon('fill',0,0,cos(a0)*R*1.5,sin(a0)*R*1.5,cos(a1)*R*1.5,sin(a1)*R*1.5)
 end
 g.pop()
 color(g,WHITE,.35);g.circle('fill',cx,cy,R*.78)
 color(g,WHITE,.55);g.circle('fill',cx,cy,R*.62)
 local revealed=k>.66
 local hop=revealed and abs(sin(t*6))*10 or 0
 -- TEST148: the mystery Pokemon is a 3D snapshot too - darkened for the
 -- silhouette, full colour once revealed. Until its picture is ready the
 -- mystery ball shows (never a sprite flash); without a model, the sprite.
 local shot=trySnap and trySnap(species)
 local rec=not shot and not(snapPending and snapPending(species))and loadSprite(species)
 if shot then
  drawShot(g,shot,cx,cy+R*.52-hop,R*1.15,R*1.5,revealed and WHITE or INK)
 elseif rec then
  drawSprite(g,rec,t,cx,cy+R*.52-hop,R*1.15,revealed and WHITE or INK)
 else
  -- no sprite available: a mystery ball
  pokeball(g,cx,cy-hop,R*.4,sin(t*3)*.3,revealed)
 end
 -- heading
 local hk=fit(g,"WHO'S THAT POKEMON?",30,W*.42)
 local hw=font(g,30):getWidth("WHO'S THAT POKEMON?")*hk
 bold(g,"WHO'S THAT POKEMON?",cx-hw/2,cy-R-40+sin(t*3)*3,30,YELLOW,BLUE,3,hk)
 if revealed then
  local name="It's "..species:sub(1,1)..species:sub(2):lower():gsub('_',' ').."!"
  local p=min(1,(k-.66)/.08)
  local nk=fit(g,name,40,W*.40)*(.6+.4*p)
  local nw=font(g,40):getWidth(name)*nk
  bold(g,name,cx-nw/2,cy+R*.62,40,WHITE,RED,3,nk)
  for i=0,5 do local a=t*2+i*pi/3
   star(g,cx+cos(a)*R*.95,cy+sin(a)*R*.7,8+4*sin(t*5+i),YELLOW,.9,t*2)
  end
 else
  local q='?';local qa=.6+.4*sin(t*5)
  bold(g,q,cx+R*.62,cy-R*.65,64,WHITE,BLUE,4,1,qa)
 end
end
local function factBubble(g,W,H,info,e)
 local list={}
 for _,f in ipairs(FACTS[info.id]or {})do list[#list+1]=f end
 for _,f in ipairs(KIND_FACTS[info.kind]or KIND_FACTS.village)do list[#list+1]=f end
 if info.tip then list[#list+1]=info.tip end
 local slot=6;local i=floor(e/slot)%#list+1;local k=(e%slot)/slot
 local a=min(1,k*8,(1-k)*8)
 local x,y,w,h=40,H*.60,W*.50,92
 color(g,INK,.25);g.rectangle('fill',x+5,y+6,w,h,18,18)
 color(g,WHITE);g.rectangle('fill',x,y,w,h,18,18)
 g.polygon('fill',x+40,y+h-2,x+62,y+h-2,x+34,y+h+20)
 color(g,BLUE);g.rectangle('fill',x+16,y-14,150,28,14,14)
 bold(g,'DID YOU KNOW?',x+28,y-10,16,WHITE,BLUE,1)
 local text=list[i]
 local f=font(g,20);color(g,INK,a)
 g.printf(text,x+18,y+22,(w-36),'left')
end
local function catchMeter(g,W,H,info,e,t)
 local x,y=W*.53,H*.84
 local ready=info.ready
 local shake=0
 if not ready then
  -- three wobbles, a pause, repeat (like a catch attempt)
  local c=e%2.4;local idx=floor(c/.6)
  if idx<3 then local p=(c%.6)/.6;shake=sin(p*pi*2)*.42*(1-p*.3)end
 end
 color(g,INK,.25);g.ellipse('fill',x,y+28,34,8)
 pokeball(g,x+shake*8,y,28,shake,ready)
 local label=ready and 'Gotcha! Area ready!' or 'Catching the area'..string.rep('.',floor(t*3)%4)
 bold(g,label,x+48,y-14,24,WHITE,INK,2)
 -- three shake dots
 for i=0,2 do
  local filled=ready or e%2.4>i*.6+.3
  color(g,INK);g.circle('fill',x+60+i*22,y+26,7)
  color(g,filled and YELLOW or{.55,.55,.6});g.circle('fill',x+60+i*22,y+26,5)
 end
 if ready then
  for i=0,7 do local a=i*pi/4+t;local r=40+8*sin(t*6)
   star(g,x+cos(a)*r,y+sin(a)*r,7,YELLOW,.95,t*3)
  end
 end
end
-- TEST147: the parade shows each party Pokemon as a snapshot of its 3D
-- Stadium model (lib/LoadingSnapshots.lua) - taken once, at most one per
-- repaint and only after the card has been up half a second, then reused.
-- No model is ever live on the card. Without the importer or a model, that
-- Pokemon keeps its sprite exactly as before.
local Snap
local function snapshots()
 if Snap==nil then local ok,v=pcall(V.require,'LoadingSnapshots');Snap=ok and v or false end
 return Snap or nil
end
M.SNAP_DELAY=.5
M.SNAP_HEIGHT,M.SNAP_WIDTH=60,84
-- One new snapshot per repaint, shared by the mystery Pokemon (first) and
-- the parade; none in the card's first half second.
local snapAllow=false
trySnap=function(species)
 local snap=snapshots();if not snap then return nil end
 local ok,v,tried=pcall(snap.get,species,snapAllow)
 if not ok or tried then snapAllow=false end
 return ok and v or nil
end
snapPending=function(species)
 local snap=snapshots();if not snap then return false end
 local ok,v=pcall(snap.pending,species);return ok and v or false
end
drawShot=function(g,shot,x,y,maxH,maxW,tint)
 local s=min((maxH or M.SNAP_HEIGHT)/shot.h,(maxW or M.SNAP_WIDTH)/shot.w)
 local c=tint or WHITE
 g.push('all')
 g.setColor(c[1],c[2],c[3],1);g.setBlendMode('alpha','premultiplied')
 g.draw(shot.image,shot.quad,x-shot.w*s/2,y-shot.h*s,0,s,s)
 g.pop()
end
local function parade(g,W,H,t,e)
 local list=party()
 if #list==0 then return end
 local ground=H-26
 color(g,INK,.18);g.rectangle('fill',0,ground,W,26)
 for i,sp in ipairs(list)do
  local x=(t*70-i*86)%(W+240)-120
  local hop=abs(sin(t*7+i))*12
  local shot=trySnap(sp)
  if shot then
   color(g,INK,.25);g.ellipse('fill',x,ground+2,22,5)
   drawShot(g,shot,x,ground-hop)
  else
   local rec=loadSprite(sp)
   if rec then
    color(g,INK,.25);g.ellipse('fill',x,ground+2,22,5)
    drawSprite(g,rec,t,x,ground-hop,64,WHITE,true)
   end
  end
 end
end

function M.paint(g,w,h,info,t,compact)
 info=info or M.describe(nil);t=t or 0;loadsThisPaint=0
 local s=math.min(w/960,h/640);local W,H=w/s,h/s
 g.scale(s,s)
 if compact then
  local cw=math.min(380,W-48);local x,y=W-cw-24,H-86
  color(g,RED);g.rectangle('fill',x,y,cw,62,14,14)
  color(g,INK);g.setLineWidth(3);g.rectangle('line',x,y,cw,62,14,14)
  pokeball(g,x+32,y+31,16,t*3)
  bold(g,'NOW ENTERING',x+58,y+8,13,YELLOW,INK,1)
  local k=fit(g,info.title,20,cw-80)
  bold(g,info.title,x+58,y+28,20,WHITE,INK,2,k)
  return
 end
 local e=info.elapsed or t
 snapAllow=e>=M.SNAP_DELAY
 local snap=snapshots()
 if snap then
  local keep=party();keep[#keep+1]=mystery(info,e);keep[#keep+1]=mystery(info,e,1)
  pcall(snap.keep,keep)
 end
 local th=THEME[info.kind]or THEME.village
 backdrop(g,W,H,th,t)
 whosThat(g,W,H,info,e,t)
 banner(g,W,info,t)
 title(g,info,W,e)
 factBubble(g,W,H,info,e)
 catchMeter(g,W,H,info,e,t)
 parade(g,W,H,t,e)
 -- TEST148: with time left in this repaint, ready the next mystery Pokemon.
 if snap and snapAllow then trySnap(mystery(info,e,1))end
end
function M.invalidate()
 for _,f in pairs(fonts)do if f.release then pcall(f.release,f)end end
 fonts={};sprites={}
end
-- TEST147: snapshots survive the card's after-load invalidate (so they are
-- not retaken every load); this releases them too.
function M.release()
 M.invalidate()
 local snap=snapshots();if snap then pcall(snap.release)end
end
return M
