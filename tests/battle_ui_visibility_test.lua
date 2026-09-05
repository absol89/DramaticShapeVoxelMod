-- ROM-free visibility regression using the real settings and draw gates.
local V = { mod = { id = "BATTLE_ART_VOXEL_FORK" } }
local modules = {}
V.require = function(name) return assert(modules[name], name) end
modules.ModSetting = assert(loadfile("lib/ModSetting.lua"))(V)
local ui = assert(loadfile("lib/UiBackplates.lua"))(V)
modules.UiBackplates = ui
local claimed = false
package.loaded["src.mods.Runtime"] = {
  wantsHook = function() return claimed end,
  call = function() return true end,
}
local presentation = assert(loadfile("lib/BattlePresentation.lua"))(V)
local function read(path)
  local file = assert(io.open(path, "rb"))
  local source = file:read("*a"); file:close(); return source
end
local source = read("lib/OverworldBattle.lua")
local battles, state = {}, {}
local hudCalls, textCalls = 0, 0
local env = setmetatable({
  OverworldBattle = battles, BattleState = state,
  BattlePresentation = presentation, UiBackplates = ui,
  innerText = function() textCalls = textCalls + 1 end,
  innerHUDs = function() hudCalls = hudCalls + 1 end,
  isIOS = function() return false end,
  snapped = function() return false end,
  drawStyledTextArea = function() textCalls = textCalls + 1 end,
  BattleScene = { GB_W = 160, GB_H = 144 },
  BattleHud = { flipGlyphs = function(_, _, draw) draw() end },
}, { __index = _G })
local function loadSection(first, last)
  local a = assert(source:find(first, 1, true))
  local b = assert(source:find(last, a + #first, true))
  local chunk = assert(loadstring(source:sub(a, b - 1)))
  setfenv(chunk, env); chunk()
end
loadSection("OverworldBattle.TEXT_RECT =", "-- ------- the HUDs")
loadSection("function OverworldBattle.hudLive", "-- ------- the snapped composite")
loadSection("  function BattleState:drawTextArea()", "  local innerAnim")
loadSection("  function BattleState:drawHUDs(slide)", "  BattleState.dramaticShapeBattleHook")
local battle = setmetatable({
  dramaticShapeShot = {}, phase = "moveSelect", enemy = {}, player = {},
  growInScale = function() return false end,
}, { __index = state })
assert(ui.battleUi:get() == "BOTH")
for index, mode in ipairs({ "BOTH", "TEXTBOX", "HUD", "HIDE" }) do
  ui.battleUi:setIndex(index)
  local hud = mode == "BOTH" or mode == "HUD"
  local text = mode == "BOTH" or mode == "TEXTBOX"
  for _, palette in ipairs({ "COLOR", "INVERTED" }) do
    ui.hudColor.index = palette == "COLOR" and 1 or 2
    for fill = 1, 4 do
      ui.textboxFill.index = fill
      hudCalls, textCalls = 0, 0
      battle:drawHUDs(0); battle:drawTextArea()
      assert(hudCalls == (hud and 1 or 0), mode .. " HUD ink")
      assert(textCalls == (text and 1 or 0), mode .. " textbox ink")
      local enemy, player = battles.hudLive(battle, 0)
      assert(enemy == hud and player == hud, mode .. " HUD panels")
      assert((next(battles.textRects(battle)) ~= nil) == text, mode .. " text panel")
      local paper = battles.textPaperRects(battle, ui.textboxMode())
      assert((next(paper) ~= nil) == (text and fill ~= 4), mode .. " textbox fill")
    end
  end
end
-- The same gates apply to Stadium's native text pass in every arena mode.
for _,fill in ipairs({"OFF","WHITE","BLUE","GEN6","PNG"}) do
  for i,value in ipairs(ui.arenaFill.values) do if value==fill then ui.arenaFill.index=i end end
  for i,mode in ipairs({"BOTH","TEXTBOX","HUD","HIDE"}) do
    ui.battleUi:setIndex(i)
    battle.dramaticShapeShot=nil
    battle.stadium2ImporterGen1Shot={battleArtUI=true}
    hudCalls,textCalls=0,0
    battle:drawHUDs(0);battle:drawTextArea()
    assert(hudCalls==0, "Stadium must not redraw the composed Battle Art HUD")
    assert(textCalls==((mode=="BOTH" or mode=="TEXTBOX") and 1 or 0),fill..mode)
  end
end
battle.stadium2ImporterGen1Shot=nil
-- Visibility affects staged presentation only; ordinary engine UI still draws.
battle.dramaticShapeShot = nil
hudCalls, textCalls = 0, 0
battle:drawHUDs(0); battle:drawTextArea()
assert(hudCalls == 1 and textCalls == 1)
ui.battleUi:setIndex(1)
claimed = true
assert(presentation.suppressed("hud", battle))
assert(presentation.suppressed("text", battle))
assert(not presentation.suppressed("unknown", battle))
claimed = false
assert(not presentation.suppressed("hud", battle))
-- A cached snapped HUD canvas must clear when switching to TEXTBOX/HIDE.
local clears, draws = 0, 0
local canvas = { getWidth = function() return 160 end, getHeight = function() return 144 end }
local hud = {}
local hudEnv = setmetatable({
  BattleHud = hud, BattlePresentation = presentation,
  canvasOf = function() return canvas end,
  love = { graphics = {
    getCanvas = function() return nil end, setCanvas = function() end,
    getBlendMode = function() return "alpha" end, setBlendMode = function() end,
    setColor = function() end, clear = function() clears = clears + 1 end,
  } },
}, { __index = _G })
local hudSource = read("lib/BattleHud.lua")
local a = assert(hudSource:find("local hudLayer = nil", 1, true))
local b = assert(hudSource:find("-- The last luminance", a, true))
local chunk = assert(loadstring(hudSource:sub(a, b - 1)))
setfenv(chunk, hudEnv); chunk()
for index, mode in ipairs({ "BOTH", "TEXTBOX", "HUD", "HIDE", "BOTH" }) do
  ui.battleUi:setIndex(index == 5 and 1 or index)
  local before = draws
  assert(hud.layerTexture(160, 144, false, function() draws = draws + 1 end) == canvas)
  assert(clears == index)
  assert(draws == before + ((mode == "BOTH" or mode == "HUD") and 1 or 0))
end
-- Persisted setting is loaded by a fresh instance.
V.mod.options = { get = function(_, key) if key == "battleUi" then return "HUD" end end }
assert(assert(loadfile("lib/UiBackplates.lua"))(V).battleUi:get() == "HUD")
print("battle UI visibility: all modes, fills, palettes, fallback and persistence passed")

-- Exercise the exported compositor: no panel calls, both status bands (also
-- carrying intro party balls), and no native capture when hidden/foreign-owned.
local captures,blits,pushes=0,0,0
local g={getCanvas=function() return nil end,push=function() pushes=pushes+1 end,pop=function() pushes=pushes-1 end,
 setCanvas=function() end,setShader=function() end,setDepthMode=function() end,
 setBlendMode=function() end,setColor=function() end,scale=function() end,
 newQuad=function() return {} end,draw=function() blits=blits+1 end}
env.love={graphics=g}
env.BattleHud.layerTexture=function(_,_,_,draw,color,shadow)
 captures=captures+1;draw();assert(color==ui.hudUsesColor());return {}
end
battles.snapRects=function() return {},{enemy={x=0,y=0,scale=1},player={x=0,y=48,scale=1}} end
battles.HUD_BAND={enemy={0,0,160,48},player={0,48,160,48}}
loadSection("function OverworldBattle.drawHostedUI", "-- Lay the frosted glass")
local ctx={battle=battle,canvas={},box={scale=1,ly=0},width=160,drawHUDs=function() end}
for i,mode in ipairs({"BOTH","TEXTBOX","HUD","HIDE"}) do
 ui.battleUi:setIndex(i);captures,blits=0,0
 assert(battles.drawHostedUI(ctx))
 local visible=mode=="BOTH" or mode=="HUD"
 assert(captures==(visible and 1 or 0) and blits==(visible and 2 or 0))
 assert(pushes==0)
end
ui.battleUi:setIndex(1);ctx.statusAvailable=false;captures=0
assert(battles.drawHostedUI(ctx) and captures==0)
print("hosted UI ownership and all arena fill gates: passed")
