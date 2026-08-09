-- Battle textbox paper replacement.
--
-- The engine draws every battle box into its 160x144 UI canvas with an
-- opaque-white rectangle followed by border and text glyphs. Recolouring that
-- exact rectangle keeps the paper and its corners in one coordinate space;
-- Renderer can then present the whole canvas with either BATTLE SIZE FIXED's
-- integer scale or FILL's fractional scale without the two drifting apart.

local TextboxStyle = {}

local unpackValues = table.unpack or unpack

local function pack(...)
  return { n = select("#", ...), ... }
end

local function setBlend(graphics, mode, alphaMode)
  if alphaMode ~= nil then
    graphics.setBlendMode(mode, alphaMode)
  else
    graphics.setBlendMode(mode)
  end
end

local function setCanvas(graphics, canvas)
  if canvas ~= nil then
    graphics.setCanvas(canvas)
  else
    graphics.setCanvas()
  end
end

local function restoreState(graphics, color, blend)
  graphics.setColor(color[1], color[2], color[3], color[4])
  setBlend(graphics, blend[1], blend[2])
end

-- Run draw while replacing only opaque-white fill rectangles.
--
-- style = { r, g, b, a } draws the engine-owned rectangle with that colour.
-- style = nil suppresses the paper while leaving borders, text and coloured
-- effects alone.
--
-- Styled fills use replace blending. Font.drawBox can issue overlapping boxes
-- for the action menu and TYPE/PP panel; normal alpha blending would stack two
-- HALF fills into a darker seam, while replace leaves every covered pixel at
-- the requested opacity.
function TextboxStyle.withFill(graphics, style, draw, ...)
  local rectangle = graphics.rectangle
  local initialColor = pack(graphics.getColor())
  local initialBlend = pack(graphics.getBlendMode())
  local args = pack(...)

  graphics.rectangle = function(mode, x, y, w, h, ...)
    if mode == "fill" then
      local r, g, b, a = graphics.getColor()
      if r > 0.99 and g > 0.99 and b > 0.99 and a > 0.99 then
        if style == nil then return end

        local color = pack(r, g, b, a)
        local blend = pack(graphics.getBlendMode())
        setBlend(graphics, "replace")
        graphics.setColor(style[1], style[2], style[3], style[4])
        local result = pack(pcall(rectangle, mode, x, y, w, h, ...))
        restoreState(graphics, color, blend)
        if not result[1] then error(result[2], 0) end
        return unpackValues(result, 2, result.n)
      end
    end
    return rectangle(mode, x, y, w, h, ...)
  end

  local result = pack(pcall(draw, unpackValues(args, 1, args.n)))
  graphics.rectangle = rectangle
  if not result[1] then
    restoreState(graphics, initialColor, initialBlend)
    error(result[2], 0)
  end
  return unpackValues(result, 2, result.n)
end

-- Draw the stateful engine text area once, into the glyph-flip scratch layer.
-- Opaque-white paper fills are mirrored to the destination canvas with the
-- selected style, then replaced by transparency in the scratch layer. The
-- transparent replacement matters for overlapping Font.drawBox calls and the
-- move menu's 8x8 tile wipes: those fills intentionally erase border pixels
-- drawn earlier in the same pass.
function TextboxStyle.withWhiteInk(graphics, style, draw, flipInk)
  local rectangle = graphics.rectangle
  local destination = graphics.getCanvas()
  local initialColor = pack(graphics.getColor())
  local initialBlend = pack(graphics.getBlendMode())
  local initialCanvas = destination

  local function drawInk()
    graphics.rectangle = function(mode, x, y, w, h, ...)
      if mode == "fill" then
        local r, g, b, a = graphics.getColor()
        if r > 0.99 and g > 0.99 and b > 0.99 and a > 0.99 then
          local inkCanvas = graphics.getCanvas()

          -- flipGlyphs runs its callback directly when its shader or scratch
          -- canvas is unavailable. Keep the engine's safe opaque-white box in
          -- that fallback instead of producing unreadable dark-on-dark ink.
          if inkCanvas == destination then
            return rectangle(mode, x, y, w, h, ...)
          end

          local color = pack(r, g, b, a)
          local blend = pack(graphics.getBlendMode())
          local rectangleArgs = pack(...)
          local result = pack(pcall(function()
            if style ~= nil then
              setCanvas(graphics, destination)
              setBlend(graphics, "replace")
              graphics.setColor(style[1], style[2], style[3], style[4])
              rectangle(mode, x, y, w, h,
                        unpackValues(rectangleArgs, 1, rectangleArgs.n))
            end

            setCanvas(graphics, inkCanvas)
            setBlend(graphics, "replace")
            graphics.setColor(0, 0, 0, 0)
            return rectangle(mode, x, y, w, h,
                             unpackValues(rectangleArgs, 1, rectangleArgs.n))
          end))

          -- Restore the ink target and draw state even if either rectangle
          -- failed, so the caller can safely unwind its own scratch pass.
          setCanvas(graphics, inkCanvas)
          restoreState(graphics, color, blend)
          if not result[1] then error(result[2], 0) end
          return unpackValues(result, 2, result.n)
        end
      end
      return rectangle(mode, x, y, w, h, ...)
    end

    return draw()
  end

  local result = pack(pcall(flipInk, drawInk))
  graphics.rectangle = rectangle
  if not result[1] then
    setCanvas(graphics, initialCanvas)
    restoreState(graphics, initialColor, initialBlend)
    error(result[2], 0)
  end
  return unpackValues(result, 2, result.n)
end

return TextboxStyle
