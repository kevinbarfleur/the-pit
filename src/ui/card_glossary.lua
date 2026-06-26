-- src/ui/card_glossary.lua
-- Shared Shift-to-glossary behavior for any hovered monster card.

local TagGlossary = require("src.ui.tagglossary")

local CardGlossary = {}

function CardGlossary.shouldShow(opts)
  opts = opts or {}
  if opts.showKeywords ~= nil then return opts.showKeywords == true end
  if opts.force then return true end
  return love and love.keyboard and love.keyboard.isDown
    and love.keyboard.isDown("lshift", "rshift")
end

function CardGlossary.drawMonster(view, cardBox, unitId, t, opts)
  opts = opts or {}
  if not cardBox or not CardGlossary.shouldShow(opts) then return nil end
  return TagGlossary.draw(view, cardBox, unitId, t,
    { scroll = opts.scroll or 0, tagOpts = opts.tagOpts, unit = opts.unit })
end

function CardGlossary.drawRelic(view, cardBox, relicId, t, opts)
  opts = opts or {}
  if not cardBox or not CardGlossary.shouldShow(opts) then return nil end
  return TagGlossary.drawRelic(view, cardBox, relicId, t,
    { scroll = opts.scroll or 0, tagOpts = opts.tagOpts })
end

return CardGlossary
