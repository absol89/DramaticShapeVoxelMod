local V=...
local ModSetting=V.require('ModSetting')
local M={revision=1,decorRevision=1,snowRevision=1,settings={},entries={}}
local legacy=nil
local rows = {
 {key='holiday',label='SEASONAL DECOR',choices={{'OFF','off'},{'AUTO (BY DATE)','auto'},{'CHRISTMAS','christmas'},{'HALLOWEEN','halloween'},{'HARVEST','harvest'},{'EASTER','easter'},{'JULY 4TH','july'}},default='auto',help='AUTO follows the calendar: Halloween through October, Harvest in autumn, Christmas from December to Twelfth Night, Easter around Easter Sunday and July 4th in early July (nothing in between). Or pick one celebration. OFF releases all seasonal scenery.'},
 {key='density',label='DECOR DENSITY',choices={{'GRAND','grand'},{'EXTRAVAGANT','extravagant'}},default='extravagant',help='Extravagant adds fuller street displays, more ornaments and more lights.'},
 {key='treeSize',label='TOWN TREES',choices={{'GRAND','grand'},{'TOWERING','towering'}},default='towering',help='Towering trees are the town centerpieces; available ground determines their footprint.'},
 {key='lights',label='FESTIVE LIGHTS',choices={{'STEADY','steady'},{'TWINKLE','twinkle'}},default='twinkle',help='Colored 3D bulbs with a gentle traveling glow. Halloween and Harvest lanterns flicker like candles.'},
 {key='snowfall',label='FALLING SNOW',choices={{'OFF','off'},{'FLURRIES','flurries'},{'FULL','full'}},default=legacy or 'full',help='Drifting rounded flakes. Independent of settled snow and Christmas decorations.'},
 {key='groundSnow',label='SETTLED SNOW',choices={{'OFF','off'},{'ON','full'}},default=(legacy=='off' or legacy=='flurries')and 'off'or 'full',help='Snow on ground, trees, exposed roofs, ledges, rails, benches and stone pillar caps. Independent of falling snow.'},
 {key='footprints',label='SNOW FOOTPRINTS',choices={{'OFF',false},{'ON',true}},default=true,help='Alternating walking footprints on settled snow. Up to 96 prints, fading over 60 seconds.'},
 {key='snowSteps',label='SNOW FOOTSTEPS',choices={{'OFF','off'},{'SUBTLE','subtle'},{'SOFT','soft'}},default='subtle',help='Quiet varied crunch when walking on settled snow. Respects SFX volume; independent of visible footprints and falling snow. SOFT is a little louder.'},
 {key='interiors',label='INDOOR DECOR',choices={{'OFF',false},{'ON',true}},default=true,help='Decorate eligible homes, Pokemon Centers, Marts, casino and public rooms.'},
 {key='moon',label='HALLOWEEN MOON',choices={{'OFF','off'},{'HALLOWEEN','halloween'},{'HALLOWEEN + HARVEST','both'}},default='halloween',help='A pale orange moon at night while Halloween decor is showing. HALLOWEEN + HARVEST keeps it through the autumn Harvest season too. OFF keeps the usual silver moon.'},
 {key='spiders',label='FALL SPIDERS',choices={{'OFF','off'},{'SMALL ONLY','small'},{'FULL','full'}},default='full',help='Moving spiders throughout outdoor Kanto and caves during Halloween and Harvest. FULL adds rare giant spiders, largest in caves and forests. Fast ground scurrying: up to 10 nearby in caves or 4 outdoors, with pauses and wandering. Decorative only. OFF releases their meshes.'},
 {key='effects',label='OTHER HOLIDAY EFFECTS',choices={{'OFF',false},{'ON',true}},default=true,help='Halloween embers and bats, Harvest falling leaves, Easter petals and July evening fireworks. Falling snow has its own control.'}
}
local byKey={}
local values={}
local function storageKey(key)return 'seasonal'..key:sub(1,1):upper()..key:sub(2)end
local function observe(key,value)
 local previous=values[key];values[key]=value
 if previous==nil or previous==value then return end
 M.revision=M.revision+1
 if key=='groundSnow'then M.snowRevision=M.snowRevision+1
 elseif key~='snowfall'and key~='footprints'and key~='snowSteps'and key~='effects'and key~='lights'and key~='moon'and key~='spiders'then M.decorRevision=M.decorRevision+1 end
end
for _,r in ipairs(rows)do
 local choices,labels,index={},{},1
 for i,c in ipairs(r.choices)do choices[i]=c[2];labels[i]=c[1];if c[2]==r.default then index=i end end
 local setting=ModSetting.new(storageKey(r.key),r.label,choices,labels,index)
 M.settings[#M.settings+1]=setting
 M.entries[#M.entries+1]={setting,r.help,full=true}
 function setting:schema(help) local out=ModSetting.schema(self,help);out.default=self.values[self.defaultIndex];return out end
 r.setting=setting;byKey[r.key]=r
end
-- Calendar for AUTO. Easter uses the Gregorian computus.
local function easterDay(y)
 local a,b,c=y%19,math.floor(y/100),y%100
 local d,e=math.floor(b/4),b%4
 local f=math.floor((b+8)/25);local g=math.floor((b-f+1)/3)
 local h=(19*a+b-d-g+15)%30
 local i,k=math.floor(c/4),c%4
 local l=(32+2*e+2*i-h-k)%7
 local m=math.floor((a+11*h+22*l)/451)
 local month=math.floor((h+l-7*m+114)/31);local day=(h+l-7*m+114)%31+1
 return month,day
end
M.easterDay=easterDay
function M.forDate(t)
 local y,mo,d=t.year,t.month,t.day
 local function stamp(m2,d2,y2)return os.time({year=y2 or y,month=m2,day=d2,hour=12})end
 local now=stamp(mo,d)
 if mo==10 or(mo==11 and d<=1)then return 'halloween'end
 if mo==11 or(mo==9 and d>=15)then return 'harvest'end
 if mo==12 or(mo==1 and d<=6)then return 'christmas'end
 local em,ed=easterDay(y);local easter=stamp(em,ed)
 if now>=easter-21*86400 and now<=easter+7*86400 then return 'easter'end
 if (mo==6 and d>=24)or(mo==7 and d<=8)then return 'july'end
 return 'off'
end
M.clock=function()local ok,t=pcall(os.date,'*t');return ok and type(t)=='table'and t or nil end
local autoDay,autoValue
local function resolve(choice)
 if choice~='auto'then return choice end
 local t=M.clock();if not t then return 'christmas'end
 local day=t.year*400+t.month*32+t.day
 if day~=autoDay then autoDay=day;autoValue=M.forDate(t)end
 return autoValue
end
local frame,cache=0,nil
-- Player-chosen town tree spots, one per map: "MAP:x:z;MAP:x:z". Stored in the
-- save's own Battle Art options table (like seasonalIntegrated), never in the
-- disk cache, so it survives Android's blocked mod file writes.
local gameRef,spotText,spotTable
local function modId()return V.mod and V.mod.id or 'BATTLE_ART_VOXEL_FORK'end
function M.bindGame(game)gameRef=game end
local function readSpots()
 local text
 local g=gameRef
 local o=g and g.save and g.save.options and g.save.options.modOptions and g.save.options.modOptions[modId()]
 if o and type(o.seasonalTreeSpots)=='string'then text=o.seasonalTreeSpots end
 if not text then
  local l=g and g.mods and g.mods.modOptions and g.mods.modOptions[modId()]
  if l and type(l.seasonalTreeSpots)=='string'then text=l.seasonalTreeSpots end
 end
 text=text or ''
 if text~=spotText or not spotTable then
  spotText=text;spotTable={}
  for id,x,z in text:gmatch('([%w_]+):(%-?[%d%.]+):(%-?[%d%.]+)')do spotTable[id]={x=tonumber(x),z=tonumber(z)}end
 end
 return spotTable,spotText
end
function M.treeSpot(mapId)local t=readSpots();return t[mapId]end
function M.setTreeSpot(game,mapId,x,z)
 gameRef=game or gameRef
 local t=readSpots();local copy={}
 for id,v in pairs(t)do copy[id]=v end
 copy[mapId]=x and{x=math.floor(x+.5),z=math.floor(z+.5)}or nil
 local ids={};for id in pairs(copy)do ids[#ids+1]=id end;table.sort(ids)
 local parts={};for _,id in ipairs(ids)do parts[#parts+1]=id..':'..copy[id].x..':'..copy[id].z end
 local text=table.concat(parts,';');local id=modId()
 local opts=game and game.save and game.save.options
 if opts then opts.modOptions=opts.modOptions or {};opts.modOptions[id]=opts.modOptions[id]or {};opts.modOptions[id].seasonalTreeSpots=text end
 local loader=game and game.mods
 if loader then loader.modOptions=loader.modOptions or {};loader.modOptions[id]=loader.modOptions[id]or {};loader.modOptions[id].seasonalTreeSpots=text end
 if game and game.writeOptions then pcall(game.writeOptions,game)end
 cache=nil
end
-- Called once per update: settings are read once per frame, not per draw.
function M.tick()frame=frame+1;cache=nil end
function M.get(key)
 if key=='holiday'then return M.all().holiday end
 local r=byKey[key];if not r then return nil end
 if cache then return cache[key]end
 local v=r.setting:get();observe(key,v);return v
end
function M.all()
 if cache then return cache end
 local out={}
 for _,r in ipairs(rows)do local v=r.setting:get();observe(r.key,v);out[r.key]=v end
 out.holidayChoice=out.holiday
 out.holiday=resolve(out.holiday)
 local spots,text=readSpots();out.treeSpots=spots
 -- Moving a tree rebuilds that map's displays like any decor choice.
 observe('treeSpots',text)
 -- A date change under AUTO (midnight, a new month) rebuilds like a choice.
 observe('resolvedHoliday',out.holiday)
 cache=out;return out
end
function M.changed(key,value)
 for _,r in ipairs(rows)do if key==r.key or key==r.setting.key then
  r.setting:sync(value);cache=nil;observe(r.key,r.setting:get());return true
 end end
 return false
end
function M.migrate(game)
 local opts=game and game.save and game.save.options
 if not opts then return end
 opts.modOptions=opts.modOptions or {}
 local target=opts.modOptions.BATTLE_ART_VOXEL_FORK or {};opts.modOptions.BATTLE_ART_VOXEL_FORK=target
 if target.seasonalIntegrated then return end
 local old=opts.modOptions.LEGENDARY_SEASONAL_DECOR or {}
 for _,r in ipairs(rows)do
  if target[r.setting.key]==nil and old[r.key]~=nil then
   for i,v in ipairs(r.setting.values)do if v==old[r.key]then target[r.setting.key]=v;break end end
  end
  r.setting.index=nil
 end
 target.seasonalIntegrated=true;cache=nil
 if game.mods then
  game.mods.modOptions=game.mods.modOptions or {}
  local loaded=game.mods.modOptions.BATTLE_ART_VOXEL_FORK or {};game.mods.modOptions.BATTLE_ART_VOXEL_FORK=loaded
  for k,v in pairs(target)do if k:match('^seasonal')then loaded[k]=v end end
 end
 if game.writeOptions then pcall(game.writeOptions,game)end
end
return M
