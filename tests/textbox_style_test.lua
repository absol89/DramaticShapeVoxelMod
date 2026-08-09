package.path = "./?.lua;./?/init.lua;" .. package.path

local TextboxStyle = require("lib.TextboxStyle")

local function eq(actual, expected, label)
  if actual ~= expected then
    error(("%s: expected %s, got %s"):format(
      label, tostring(expected), tostring(actual)), 0)
  end
end

local function graphicsStub()
  local color = { 1, 1, 1, 1 }
  local blend = { "alpha", "alphamultiply" }
  local canvas = "ui"
  local calls = {}
  local g = {}

  function g.getColor() return color[1], color[2], color[3], color[4] end
  function g.setColor(r, gr, b, a) color = { r, gr, b, a or 1 } end
  function g.getBlendMode() return blend[1], blend[2] end
  function g.setBlendMode(mode, alphaMode) blend = { mode, alphaMode } end
  function g.getCanvas() return canvas end
  function g.setCanvas(nextCanvas) canvas = nextCanvas or "screen" end
  function g.rectangle(mode, x, y, w, h)
    calls[#calls + 1] = {
      mode = mode, x = x, y = y, w = w, h = h,
      color = { color[1], color[2], color[3], color[4] },
      blend = { blend[1], blend[2] },
      canvas = canvas,
    }
  end

  return g, calls
end

-- The engine owns the textbox coordinates. Recolouring its white paper in
-- place means BATTLE SIZE FIXED and FILL transform the paper, corners and ink
-- together rather than scaling a second window-space rectangle differently.
do
  local g, calls = graphicsStub()
  local original = g.rectangle

  TextboxStyle.withFill(g, { 0, 0, 0, 0.5 }, function()
    g.setColor(1, 1, 1, 1)
    g.rectangle("fill", 0, 96, 160, 48)
    g.setColor(0.2, 0.3, 0.4, 1)
    g.rectangle("fill", 9, 10, 11, 12)
  end)

  eq(#calls, 2, "both engine rectangles survive")
  eq(calls[1].x, 0, "paper keeps the engine x")
  eq(calls[1].y, 96, "paper keeps the engine y")
  eq(calls[1].w, 160, "paper keeps the engine width")
  eq(calls[1].h, 48, "paper keeps the engine height")
  eq(calls[1].color[1], 0, "HALF paper is black")
  eq(calls[1].color[4], 0.5, "HALF matches v1.68 opacity")
  eq(calls[1].blend[1], "replace", "nested paper cannot stack darker")
  eq(calls[2].color[1], 0.2, "non-paper fills pass through")
  eq(g.rectangle, original, "rectangle hook is restored")
end

-- Black paper cannot enter the white-ink shader: the shader would recognise
-- the whole slab as ink and brighten it. The stateful engine draw must run
-- exactly once in the ink layer; white paper fills are mirrored to the UI
-- canvas and become transparent-replace clears in the ink layer. Those clears
-- preserve nested Font.drawBox and MoveSelectionMenu's two 8x8 border wipes.
do
  local g, calls = graphicsStub()
  local draws, flips = 0, 0
  local battle = { scrollPx = 8 }

  TextboxStyle.withWhiteInk(g, { 0, 0, 0, 0.5 }, function()
    draws = draws + 1
    battle.scrollPx = battle.scrollPx - 2
    g.setColor(1, 1, 1, 1)
    g.rectangle("fill", 0, 96, 160, 48)
    g.setColor(0, 0, 0, 1)
    g.rectangle("line", 0, 96, 160, 48)
    g.setColor(1, 1, 1, 1)
    g.rectangle("fill", 0, 64, 88, 40)
    g.setColor(0, 0, 0, 1)
    g.rectangle("line", 0, 64, 88, 40)
    g.setColor(1, 1, 1, 1)
    g.rectangle("fill", 32, 96, 8, 8)
    g.rectangle("fill", 80, 96, 8, 8)
    g.setColor(0, 0, 0, 1)
    g.rectangle("line", 32, 96, 8, 8)
    g.rectangle("line", 80, 96, 8, 8)
  end, function(drawInk)
    flips = flips + 1
    local destination = g.getCanvas()
    g.setCanvas("ink")
    drawInk()
    g.setCanvas(destination)
  end)

  eq(draws, 1, "stateful engine text area draws once")
  eq(battle.scrollPx, 6, "scroll advances once per frame")
  eq(flips, 1, "the single ink pass is flipped")

  local paper, clears, inkLines, uiLines = 0, 0, 0, 0
  local wipedLeft, wipedRight = false, false
  for _, call in ipairs(calls) do
    if call.canvas == "ui" and call.mode == "fill" then
      paper = paper + 1
      eq(call.color[4], 0.5, "every paper replacement keeps HALF alpha")
      eq(call.blend[1], "replace", "overlapping paper does not stack")
    elseif call.canvas == "ink" and call.mode == "fill" then
      clears = clears + 1
      eq(call.color[4], 0, "paper is a transparent clear in the ink layer")
      eq(call.blend[1], "replace", "ink paper clear replaces prior borders")
      if call.x == 32 and call.w == 8 then wipedLeft = true end
      if call.x == 80 and call.w == 8 then wipedRight = true end
    elseif call.canvas == "ink" and call.mode == "line" then
      inkLines = inkLines + 1
    elseif call.canvas == "ui" and call.mode == "line" then
      uiLines = uiLines + 1
    end
  end

  eq(paper, 4, "outer, nested and wipe paper reaches the UI canvas")
  eq(clears, 4, "every paper draw clears the same ink-layer rectangle")
  eq(inkLines, 4, "borders draw only in the ink layer")
  eq(uiLines, 0, "no black border leaks into the UI paper pass")
  eq(wipedLeft, true, "left 8x8 MoveSelectionMenu wipe is preserved")
  eq(wipedRight, true, "right 8x8 MoveSelectionMenu wipe is preserved")
end

print("textbox_style_test: PASS")
