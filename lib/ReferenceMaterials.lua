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
function M.encode(name,shade)
 local tag=4096+assert(M.ids[name])*128
 if type(shade)=='table' then return {tag+shade[1],tag+shade[2],tag+shade[3],tag+shade[4]} end
 return tag+shade
end
return M
