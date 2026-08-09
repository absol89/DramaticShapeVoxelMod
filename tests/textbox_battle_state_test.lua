package.path = "./?.lua;./?/init.lua;" .. package.path

require("tests.modkit")

local BattleState = require("src.battle.BattleState")
local modPath = os.getenv("DS_MOD_PATH") or "mods/BATTLE_ART_VOXEL_FORK"
local TextboxStyle = assert(loadfile(modPath .. "/lib/TextboxStyle.lua"))()

local function eq(actual, expected, label)
  if actual ~= expected then
    error(("%s: expected %s, got %s"):format(
      label, tostring(expected), tostring(actual)), 0)
  end
end

local graphics = love.graphics
local originalRectangle = graphics.rectangle

local function drawStyled(state)
  local calls = {}
  graphics.rectangle = function(mode, x, y, w, h)
    local r, g, b, a = graphics.getColor()
    local blend = graphics.getBlendMode()
    calls[#calls + 1] = {
      mode = mode, x = x, y = y, w = w, h = h,
      color = { r, g, b, a }, blend = blend,
      canvas = graphics.getCanvas(),
    }
  end

  graphics.setCanvas("ui")
  graphics.setColor(0, 0, 0, 1)
  TextboxStyle.withWhiteInk(graphics, { 0, 0, 0, 0.5 }, function()
    BattleState.drawTextArea(state)
  end, function(drawInk)
    local destination = graphics.getCanvas()
    graphics.setCanvas("ink")
    drawInk()
    graphics.setCanvas(destination)
  end)

  graphics.rectangle = originalRectangle
  return calls
end

-- BattleState:drawTextArea mutates scrollPx. The styling wrapper must never
-- call it twice just to separate paper from ink.
local messages = {
  phase = "messages", current = true, scrollPx = 8,
  shown = {}, frame = 0,
}
drawStyled(messages)
eq(messages.scrollPx, 6, "real BattleState scroll advances once")

-- The real move menu has three overlapping boxes plus two 8x8 white tile
-- wipes. Every white fill must both paint the UI paper and clear the same
-- rectangle from the ink layer so old border fragments cannot survive.
local moveSelect = {
  phase = "moveSelect", moveIndex = 1,
  player = { curMoves = {} }, data = { moves = {} },
}
local calls = drawStyled(moveSelect)
local paper, clears = 0, 0
local wipedLeft, wipedRight = false, false
for _, call in ipairs(calls) do
  if call.mode == "fill" and call.canvas == "ui" then
    paper = paper + 1
    eq(call.color[4], 0.5, "real move-menu paper keeps HALF alpha")
    eq(call.blend, "replace", "real overlapping paper uses replace blend")
  elseif call.mode == "fill" and call.canvas == "ink" then
    clears = clears + 1
    eq(call.color[4], 0, "real move-menu paper clears the ink layer")
    eq(call.blend, "replace", "real ink clear uses replace blend")
    if call.x == 32 and call.y == 96 and call.w == 8 and call.h == 8 then
      wipedLeft = true
    elseif call.x == 80 and call.y == 96 and call.w == 8 and call.h == 8 then
      wipedRight = true
    end
  end
end

eq(paper, 5, "all real move-menu paper fills reach the UI canvas")
eq(clears, 5, "all real move-menu paper fills clear the ink canvas")
eq(wipedLeft, true, "real left 8x8 move-menu wipe is preserved")
eq(wipedRight, true, "real right 8x8 move-menu wipe is preserved")

print("textbox_battle_state_test: PASS")
