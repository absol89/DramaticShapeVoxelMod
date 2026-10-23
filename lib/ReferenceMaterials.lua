-- Original harbor palette. IDs form the TEST56 shader contract.
local M={}
M.order={'blue','cream','dark','flower','glass','gold','green','leaf','mortar','navy','oak','red','sage','slate','stone','terra','tile','white','wood','forestBark','forestLeaf','forestCore','forestFloor','neonRose','neonCyan','neonGold','neonBulb','waterBed'}
M.colors={
 waterBed={.30,.32,.28},
 neonRose={1.0,.095,.32},neonCyan={.075,.79,1.0},neonGold={1.0,.56,.10},neonBulb={1.0,.69,.24},
 forestFloor={.23,.30,.15},
 forestBark={.33,.255,.17},forestLeaf={.255,.445,.175},forestCore={.21,.385,.135},
 blue={.23,.39,.57},cream={.91,.84,.62},dark={.14,.14,.17},
 flower={.84,.36,.43},glass={.27,.42,.58},gold={.97,.83,.47},
 green={.18,.34,.21},leaf={.36,.52,.27},mortar={.64,.66,.63},
 navy={.13,.24,.39},oak={.59,.43,.28},red={.64,.20,.18},
 sage={.55,.61,.48},slate={.27,.32,.35},stone={.47,.50,.49},
 terra={.49,.24,.19},tile={.56,.29,.22},white={.88,.86,.76},wood={.35,.25,.18},
}
M.ids={};for i,n in ipairs(M.order)do M.ids[n]=i-1 end
-- Append-only: previously cached material numbers remain exactly the same.
for _,entry in ipairs({
 {'lvMauve',{.565,.445,.515}}, {'lvPlaster',{.70,.64,.65}},
 {'lvTimber',{.255,.195,.235}}, {'lvStone',{.49,.465,.49}},
 {'lvSlate',{.245,.255,.305}}, {'lvWalnut',{.34,.245,.205}},
})do
 local name,color=entry[1],entry[2]
 M.ids[name]=#M.order;M.order[#M.order+1]=name;M.colors[name]=color
end
-- TEST16 append-only Kanto finishes. The first 34 material IDs are unchanged.
for _,entry in ipairs({
 {'ktLime',{0.8,0.77,0.66}},
 {'ktOchre',{0.7,0.59,0.44}},
 {'ktSandstone',{0.64,0.6,0.51}},
 {'ktBasalt',{0.24,0.275,0.28}},
 {'ktPlaster',{0.81,0.82,0.75}},
 {'ktSage',{0.55,0.66,0.57}},
 {'ktCedar',{0.43,0.31,0.22}},
 {'ktCopper',{0.3,0.49,0.43}},
 {'ktTerracotta',{0.57,0.32,0.25}},
 {'ktMarine',{0.28,0.43,0.59}},
 {'ktPearl',{0.67,0.76,0.79}},
 {'ktBrick',{0.46,0.34,0.3}},
 {'ktObsidian',{0.18,0.22,0.28}},
 {'ktSteel',{0.42,0.48,0.53}},
 {'ktBronze',{0.58,0.46,0.28}},
 {'ktViolet',{0.42,0.35,0.56}},
 {'ktGlass',{0.23,0.56,0.64}},
})do
 local name,color=entry[1],entry[2]
 M.ids[name]=#M.order;M.order[#M.order+1]=name;M.colors[name]=color
end
-- TEST18: append-only, building-scoped detailed finishes (no atlas allocation).
for _,entry in ipairs({
 {'exktLime',{0.8,0.77,0.66}},
 {'exktOchre',{0.7,0.59,0.44}},
 {'exktSandstone',{0.64,0.6,0.51}},
 {'exktBasalt',{0.24,0.275,0.28}},
 {'exktPlaster',{0.81,0.82,0.75}},
 {'exktSage',{0.55,0.66,0.57}},
 {'exktCedar',{0.43,0.31,0.22}},
 {'exktCopper',{0.3,0.49,0.43}},
 {'exktTerracotta',{0.57,0.32,0.25}},
 {'exktMarine',{0.28,0.43,0.59}},
 {'exktPearl',{0.67,0.76,0.79}},
 {'exktBrick',{0.46,0.34,0.3}},
 {'exktObsidian',{0.18,0.22,0.28}},
 {'exktSteel',{0.42,0.48,0.53}},
 {'exktBronze',{0.58,0.46,0.28}},
 {'exktViolet',{0.42,0.35,0.56}},
 {'exktGlass',{0.23,0.56,0.64}},
 {'exlvMauve',{0.565,0.445,0.515}},
 {'exlvPlaster',{0.7,0.64,0.65}},
 {'exlvTimber',{0.255,0.195,0.235}},
 {'exlvStone',{0.49,0.465,0.49}},
 {'exlvSlate',{0.245,0.255,0.305}},
 {'exlvWalnut',{0.34,0.245,0.205}},
 {'exblue',{0.23,0.39,0.57}},
 {'excream',{0.91,0.84,0.62}},
 {'exwhite',{0.88,0.86,0.76}},
 {'exwood',{0.35,0.25,0.18}},
 {'exoak',{0.59,0.43,0.28}},
 {'exstone',{0.47,0.5,0.49}},
 {'exmortar',{0.64,0.66,0.63}},
 {'exslate',{0.27,0.32,0.35}},
 {'exterra',{0.49,0.24,0.19}},
 {'extile',{0.56,0.29,0.22}},
 {'exgreen',{0.18,0.34,0.21}},
 {'exnavy',{0.13,0.24,0.39}},
 {'exred',{0.64,0.2,0.18}},
 {'exdark',{0.14,0.14,0.17}},
 {'exgold',{0.97,0.83,0.47}},
 {'exglass',{0.27,0.42,0.58}},
 {'exruin',{0.52,0.53,0.49}},
 {'extower',{0.3,0.27,0.34}},
 {'extrim',{0.88,0.86,0.76}},
})do
 local name,color=entry[1],entry[2]
 M.ids[name]=#M.order;M.order[#M.order+1]=name;M.colors[name]=color
end
-- Atlas-colored tower finish. Geometry and user palette remain authoritative.
M.ids.exTowerAtlas=#M.order;M.order[#M.order+1]='exTowerAtlas';M.colors.exTowerAtlas={.30,.27,.34}
-- TEST23 native crowns; append-only tags preserve every existing material ID.
for _,entry in ipairs({{'worldLeaf',{.255,.445,.175}},{'worldCore',{.21,.385,.135}},{'worldBark',{.33,.255,.17}}})do
 local name,color=entry[1],entry[2]
 M.ids[name]=#M.order;M.order[#M.order+1]=name;M.colors[name]=color
end
-- TEST147: tropical foliage (Safari palms/ferns, Cinnabar palms). Drawn
-- exactly like forestLeaf/forestCore (the shader maps them back), but kept
-- evergreen: the autumn crown tint skips them.
for _,entry in ipairs({{'tropicLeaf',{.255,.445,.175}},{'tropicCore',{.21,.385,.135}}})do
 local name,color=entry[1],entry[2]
 M.ids[name]=#M.order;M.order[#M.order+1]=name;M.colors[name]=color
end
-- TEST164: League road finishes (shader ids 100..110, world-space detail).
for _,entry in ipairs({
 {'lgMarble',{.905,.885,.845}},{'lgGranite',{.64,.585,.545}},{'lgCrimson',{.50,.065,.085}},
 {'lgGold',{.95,.74,.30}},{'lgBronze',{.55,.40,.22}},{'lgPaveLight',{.865,.835,.77}},
 {'lgPaveDark',{.255,.27,.315}},{'lgLawn',{.28,.49,.16}},{'lgCarpet',{.56,.055,.075}},
 {'lgRock',{.56,.53,.495}},{'lgVerde',{.11,.17,.15}},
})do
 local name,color=entry[1],entry[2]
 M.ids[name]=#M.order;M.order[#M.order+1]=name;M.colors[name]=color
end
-- TEST165: the same League finishes as surface DETAIL (shader ids 111..122):
-- identical in the scene, but they cast no shadow. Facade relief (dentils,
-- frames, pilasters, cornices) sits a unit or two proud of a wall the sun
-- grazes; as shadow casters they printed jagged stair-steps down every facade.
for _,base in ipairs({'lgMarble','lgGranite','lgCrimson','lgGold','lgBronze','lgPaveLight',
 'lgPaveDark','lgLawn','lgCarpet','lgRock','lgVerde'})do
 local name=base..'D'
 M.ids[name]=#M.order;M.order[#M.order+1]=name;M.colors[name]=M.colors[base]
end
-- fluted marble (pilaster shafts), also detail
M.ids.lgFluteD=#M.order;M.order[#M.order+1]='lgFluteD';M.colors.lgFluteD=M.colors.lgMarble
-- TEST166: garden gravel, pool mosaic, marble ashlar walls, flower carpet
-- (shader materials 123..126; they cast shadows like any surface).
for _,entry in ipairs({
 {'lgGravel',{.80,.755,.675}},{'lgPool',{.15,.53,.63}},{'lgAshlar',{.905,.885,.845}},{'lgBloom',{.45,.30,.20}},
})do
 local name,color=entry[1],entry[2]
 M.ids[name]=#M.order;M.order[#M.order+1]=name;M.colors[name]=color
end
M.ids.lgFoliage=#M.order;M.order[#M.order+1]='lgFoliage';M.colors.lgFoliage={.16,.29,.10}
-- TEST169: the League's wild flora (shader materials 128..131): free-grown
-- leaf crowns (they stir in the wind; lgFoliage stays for clipped hedges),
-- conifer needles (cypress, fir), the meadow on the ledges and valley, and
-- the plated red-brown bark of the pines and broadleaf.
for _,entry in ipairs({{'lgLeaf',{.22,.40,.12}},{'lgNeedle',{.14,.27,.15}},{'lgMeadow',{.30,.46,.17}},{'lgBark',{.36,.25,.17}}})do
 local name,color=entry[1],entry[2]
 M.ids[name]=#M.order;M.order[#M.order+1]=name;M.colors[name]=color
end
-- TEST172: the League rooms' finishes (shader materials 132..142): glacial
-- ice, self-lit ice crystal, obsidian, dojo wood, self-lit lava, gothic
-- slate, silver, self-lit stained glass, the night sky, snow, plum damask.
for _,entry in ipairs({{'lgIce',{.45,.70,.85}},{'lgCrystal',{.60,.88,1.0}},{'lgObsidian',{.05,.05,.07}},
 {'lgWood',{.52,.35,.19}},{'lgLava',{1.0,.45,.10}},{'lgSlate',{.27,.27,.32}},{'lgSilver',{.75,.78,.83}},
 {'lgAmethyst',{.42,.16,.66}},{'lgNight',{.02,.03,.08}},{'lgSnow',{.88,.93,.98}},{'lgPlum',{.27,.07,.32}}})do
 local name,color=entry[1],entry[2]
 M.ids[name]=#M.order;M.order[#M.order+1]=name;M.colors[name]=color
end
-- TEST173: the town interiors' finishes (shader materials 143..171): oak,
-- walnut and pine boards, parquet, white tile, checker, terrazzo, tatami,
-- flagstone; wool pile in four colours; three wallpapers; brick; book
-- spines; shop goods; red lacquer; white enamel; leather; brushed steel;
-- and the self-lit ones: screens, lamp shades, aquarium water, shoji paper,
-- the view through a window, light panels.
for _,entry in ipairs({{'inOak',{.60,.42,.22}},{'inWalnut',{.28,.17,.09}},{'inPine',{.76,.67,.52}},
 {'inParquet',{.50,.31,.15}},{'inTile',{.90,.91,.92}},{'inChecker',{.50,.50,.50}},{'inTerrazzo',{.80,.77,.71}},
 {'inTatami',{.73,.69,.44}},{'inStone',{.54,.51,.46}},{'inRugRed',{.62,.12,.12}},{'inRugBlue',{.16,.27,.52}},
 {'inRugGreen',{.20,.40,.24}},{'inRugGold',{.76,.56,.20}},{'inPaperRose',{.93,.87,.74}},{'inPaperSage',{.56,.64,.52}},
 {'inPaperBlue',{.40,.55,.72}},{'inBrick',{.56,.27,.18}},{'inBooks',{.40,.25,.20}},{'inGoods',{.60,.40,.40}},
 {'inLacquer',{.66,.07,.08}},{'inEnamel',{.90,.90,.88}},{'inLeather',{.34,.19,.11}},{'inSteel',{.63,.66,.70}},
 {'inScreen',{.20,.60,.70}},{'inLamp',{1.0,.82,.55}},{'inAqua',{.08,.40,.50}},{'inShoji',{1.0,.92,.74}},
 {'inWindow',{.70,.82,.94}},{'inPanel',{.96,.98,1.0}}})do
 local name,color=entry[1],entry[2]
 M.ids[name]=#M.order;M.order[#M.order+1]=name;M.colors[name]=color
end
-- TEST174: the dungeons' finishes (shader materials 172..178): the Tower's
-- stone in its three finishes and its vault, charred timber, office carpet,
-- rusted iron.
for _,entry in ipairs({{'dnTower',{.20,.15,.26}},{'dnTowerPale',{.65,.61,.73}},{'dnTowerPearl',{.84,.80,.90}},
 {'dnVault',{.20,.11,.28}},{'dnChar',{.10,.08,.06}},{'dnCarpet',{.32,.35,.42}},{'dnRust',{.36,.20,.12}},
 {'dnGranite',{.50,.50,.54}},{'dnGraniteDark',{.12,.12,.14}},
 -- (181..183: the Power Plant's tread plate, hazard stripes, painted block)
 {'dnPlate',{.34,.36,.38}},{'dnHazard',{.50,.40,.10}},{'dnBlock',{.54,.60,.56}},
 -- (TEST175, 184..186: neon and bulbs (self-lit), the Rocket lair's floor and
 -- its gunmetal panelling)
 {'dnNeon',{1.0,.30,.30}},{'dnLair',{.10,.10,.12}},{'dnGunmetal',{.21,.22,.25}}})do
 local name,color=entry[1],entry[2]
 M.ids[name]=#M.order;M.order[#M.order+1]=name;M.colors[name]=color
end
-- TEST176: the routes' own ground (shader materials 187..197), their grass
-- (198..215: an atlas tint per country, a lawn id then a blade id) and the
-- cave mouths' natural rock (216..222). APPEND-ONLY.
for _,entry in ipairs({{'rtLane',{.60,.49,.34}},{'rtLoam',{.28,.20,.13}},{'rtScree',{.53,.52,.49}},
 {'rtRedEarth',{.62,.36,.23}},{'rtFlag',{.75,.65,.50}},{'rtSlate',{.36,.38,.43}},{'rtSand',{.83,.75,.57}},
 {'rtBoardX',{.58,.55,.50}},{'rtBoardZ',{.58,.55,.50}},{'rtPrairie',{.75,.65,.44}},{'rtShell',{.87,.85,.80}},
 {'tgMeadow',{.30,.54,.17}},{'tgMeadowBlade',{.30,.54,.17}},{'tgLush',{.22,.49,.20}},{'tgLushBlade',{.22,.49,.20}},
 {'tgDry',{.40,.56,.14}},{'tgDryBlade',{.40,.56,.14}},{'tgPark',{.25,.52,.18}},{'tgParkBlade',{.25,.52,.18}},
 {'tgHighland',{.28,.45,.21}},{'tgHighlandBlade',{.28,.45,.21}},{'tgCoast',{.31,.55,.19}},{'tgCoastBlade',{.31,.55,.19}},
 {'tgPrairie',{.36,.56,.15}},{'tgPrairieBlade',{.36,.56,.15}},{'tgCape',{.28,.56,.19}},{'tgCapeBlade',{.28,.56,.19}},
 {'tgWild',{.26,.48,.16}},{'tgWildBlade',{.26,.48,.16}},
 {'rkMoon',{.50,.50,.52}},{'rkRed',{.64,.36,.23}},{'rkBlue',{.19,.23,.34}},{'rkIce',{.70,.81,.90}},
 {'rkEarth',{.50,.37,.23}},{'rkMoss',{.27,.40,.15}},{'rkCrystal',{.55,.85,1.0}}})do
 local name,color=entry[1],entry[2]
 M.ids[name]=#M.order;M.order[#M.order+1]=name;M.colors[name]=color
end
-- TEST96: append-only Cerulean ceiling and submerged pool lining.
for _,entry in ipairs({{'inCeiling',{.84,.88,.90}},{'inPoolBed',{.19,.38,.40}}})do
 local name,color=entry[1],entry[2]
 M.ids[name]=#M.order;M.order[#M.order+1]=name;M.colors[name]=color
end
function M.encode(name,shade)
 local tag=4096+assert(M.ids[name])*128
 if name=='exTowerAtlas'then
  local function tagged(n)return n<0 and -(tag+math.abs(n))or tag+n end
  if type(shade)=='table'then return{tagged(shade[1]),tagged(shade[2]),tagged(shade[3]),tagged(shade[4])}end
  return tagged(shade)
 end
 if type(shade)=='table' then return {tag+shade[1],tag+shade[2],tag+shade[3],tag+shade[4]} end
 return tag+shade
end
return M
