-- Real settings/preset modules: OFF must restore buildings and suppress every
-- seasonal effect without erasing the player's CUSTOM choices.
local modules, stored, checks = {}, {}, 0
local V = {mod={id='BATTLE_ART_VOXEL_FORK',options={get=function(_,k)return stored[k]end}}}
V.require=function(name)return assert(modules[name],name)end
local function load(name)
  modules[name]=assert(loadfile('lib/'..name..'.lua'))(V)
  return modules[name]
end
local function check(ok, message)checks=checks+1;assert(ok,message)end
local Setting=load('ModSetting')
local C=load('CommunityVisuals')
load('ItemPokeballs');load('TowerFogSettings')
modules.ForestAtmos={setting=Setting.new('forestFx','FOREST FX',{'off','low'})}
local P=load('LegendaryVisualsPreset')
local S=assert(loadfile('lib/seasonal/Settings.lua'))(V)
modules.SeasonalDecor={Settings=S}
S.clock=function()return{year=2026,month=10,day=23}end
-- This is the same late registration performed after SeasonalDecor loads.
if P.registerSeasonal then P.registerSeasonal(S.settings)end
local byKey={}
for _,s in ipairs(S.settings)do byKey[s.key]=s end
local function mode(value)P.setting:sync(value);P.changed(P.setting.key);S.tick()end
check(P.mode()=='off','fresh master should be OFF')
check(not C.referenceBuildings(),'OFF still replaces Viridian/Pallet buildings')
check(C.buildings:get()=='installed','OFF must select installed building geometry')
check(S.all().holiday=='off','OFF still resolves October to Halloween')
for _,key in ipairs({'snowfall','groundSnow','snowSteps','moon','spiders'})do
  check(S.get(key)=='off','OFF left seasonal '..key..' active')
end
for _,key in ipairs({'footprints','interiors','effects'})do
  check(S.get(key)==false,'OFF left seasonal '..key..' active')
end
check(byKey.seasonalHoliday:row().value()=='OFF','seasonal menu hides effective OFF')
check(C.buildings:row().value()=='INSTALLED','building menu hides effective OFF')
local holiday=byKey.seasonalHoliday
holiday:sync('christmas');C.buildings:sync('installed')
for _,choice in ipairs({'auto','full'})do
  mode(choice)
  check(C.referenceBuildings(),choice..' must enable Legendary buildings')
  check(S.all().holiday=='christmas',choice..' erased selected season')
  holiday:sync('off');S.tick()
  check(S.all().holiday=='off',choice..' overrode explicit seasonal OFF')
  holiday:sync('auto');S.tick()
  check(S.all().holiday=='halloween',choice..' lost calendar season')
  holiday:sync('christmas')
end
mode('off');mode('custom')
check(not C.referenceBuildings(),'CUSTOM lost installed building choice')
check(S.all().holiday=='christmas','CUSTOM lost chosen holiday')
C.buildings:sync('reference');mode('off');mode('custom')
check(C.referenceBuildings(),'CUSTOM lost Legendary building choice')
check(holiday.values[holiday:read()]=='christmas','profile overwrote raw holiday')
-- A child edit must leave OFF and edit the remembered value, not stay hidden.
mode('off');holiday:row().step(nil,1);S.tick()
check(P.mode()=='custom' and S.all().holiday=='halloween','seasonal child edit did not enter CUSTOM')
mode('off');C.buildings:row().step(nil,1)
check(P.mode()=='custom' and not C.referenceBuildings(),'building child edit did not enter CUSTOM')
-- Boolean OFF overlays must remain observable through the profile API.
check(P.profileValue(byKey.seasonalEffects,'off')==false,'false profile value was lost')
local count=#P.members();P.registerSeasonal(S.settings)
check(#P.members()==count,'late registration installed duplicate overlays')
print(checks..' checks passed (Legendary world OFF, CUSTOM restoration, seasonal controls)')
