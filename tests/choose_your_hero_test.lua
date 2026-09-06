local file=assert(io.open('lib/BattleArt.lua','rb'))
local source=file:read('*a'); file:close()
local first=assert(source:find('local function currentGameSave()',1,true))
local last=assert(source:find('-- The normal player trainer intro',first,true))
local player, rival, animated, art = 'red','blue','red','gen3'
local game={save={modData={}}}
local handle={save={get=function(_,key) return key=='player' and player or rival end}}
local assets, requested={},{}
local api={
  setting={get=function() return 'gen3' end},
  trainerSetting={get=function() return 'gen3' end},
  playerAnimationSetting={get=function() return animated end},
  playerArtSetting={get=function() return art end},
}
local env=setmetatable({
  BattleArt=api,
  V={mod={find=function() return handle end,
    assets={path=function(_,path) return path end}}},
  require=function(name) assert(name=='src.core.Game'); return game end,
  displayMode=function() return 'color' end,
  prepare=function(path) requested[#requested+1]=path; return assets[path] end,
},{__index=_G})
local chunk=assert(loadstring(source:sub(first,last-1)))
setfenv(chunk,env); chunk()
assert(api.effectivePlayerAnimationSet()=='red')
player='green'; rival='yellow'
assert(api.effectivePlayerAnimationSet()=='green')
art='red'; assert(api.effectivePlayerArtSet()=='green')
player='red'; assert(api.effectivePlayerArtSet()=='red')
art='gen3'
assert(api.chooseYourHeroRival()=='yellow')
animated='ash'; assert(api.effectivePlayerAnimationSet()=='ash')
animated='rom'; assert(api.effectivePlayerAnimationSet()=='rom')
animated='green'; assert(api.effectivePlayerAnimationSet()=='green')
assert(api.effectivePlayerArtSet()=='gen3', 'explicit player art overridden')
for _,name in ipairs({'rival','rival1','rival2','rival3'}) do
  local alt=name=='rival' and 'rival1f' or name..'f'
  local path='assets/battle/front-static/gen3/'..alt..'.png'
  assets[path]=alt
  assert(api.trainerImage(name)==alt)
  assets[path]=nil
  assets['assets/battle/front-static/gen3/'..name..'.png']=name
  assert(api.trainerImage(name)==nil, 'missing rival art overrides companion portrait')
end
assets['assets/battle/front-static/gen3/youngster.png']='youngster'
assert(api.trainerImage('youngster')=='youngster')
rival='blue'; assert(api.trainerImage('rival2')=='rival2')
handle.save.get=function() error('optional save unavailable') end
game.save.modData.choose_your_hero={player='green',rival='yellow'}
assert(api.chooseYourHeroPlayer()=='green' and api.chooseYourHeroRival()=='yellow')
handle=nil
game.save.modData={choose_something_else={player='green',rival='yellow'}}
assert(api.chooseYourHeroPlayer()=='red' and api.chooseYourHeroRival()=='blue')
local sets=assert(loadfile('data/animated_player_trainers.lua'))()
assert(sets.green and sets.red)
local animFile=assert(io.open('lib/AnimatedBattleArt.lua','rb'))
local anim=animFile:read('*a'); animFile:close()
assert(anim:find('BattleArt.effectivePlayerAnimationSet()',1,true))
print('Choose Your Hero selection, rival art and optional-save fallback: ok')

for _,gen in ipairs({'gen1','gen2','gen3'}) do
 api.trainerSetting.get=function() return gen end
 local dotted='assets/battle/front-static/'..gen..'/prof.oak.png'
 local legacy='assets/battle/front-static/'..gen..'/prof-oak.png'
 assets[dotted],assets[legacy]='custom-oak','legacy-oak'
  assert(api.trainerImage('prof-oak')=='legacy-oak')
  assert(api.trainerImage('prof.oak')=='custom-oak')
  assert(api.introOakImage()=='custom-oak')
  assets[dotted]=nil; assert(api.trainerImage('prof.oak')==nil)
  assert(api.trainerImage('prof-oak')=='legacy-oak')
  assets[legacy]=nil; assert(api.trainerImage('prof-oak')==nil)
end
local f=assert(io.open('main.lua','rb')); local main=f:read('*a');f:close()
local a=assert(main:find('mod.hooks:wrap("intro.oak_speech.build"',1,true))
local b=assert(main:find('mod.hooks:wrap("pokemon.sprite"',a,true))
local hook
local fn=assert(loadstring(main:sub(a,b-1)))
setfenv(fn,{mod={hooks={wrap=function(_,name,callback) hook=callback end}},BattleArt=api});fn()
local steps,speech={}, {oakPic='rom',oakTrueColor=false}
local function next(s)assert(s==steps);return s end
assert(hook(next,steps,speech)==steps and speech.oakPic=='rom')
assets['assets/battle/front-static/gen3/prof.oak.png']='new-oak'
hook(next,steps,speech);assert(speech.oakPic=='new-oak' and speech.oakTrueColor)
assert(speech.oakPicOffsetY==8,"custom Oak intro moves below the top clip")
api.setting.get=function()return 'rom' end
speech={oakPic='rom',oakTrueColor=false};hook(next,steps,speech)
assert(speech.oakPic=='rom' and not speech.oakTrueColor)
print('Oak generation routing, legacy fallback, intro hook and ROM mode: ok')
