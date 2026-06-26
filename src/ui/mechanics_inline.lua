-- src/ui/mechanics_inline.lua
-- Shared renderer for compact mechanical prose: keyword icons, tag-coloured
-- values, prismatic conversion text, and trigger chips. Render-only.

local Draw = require("src.ui.draw")
local Theme = require("src.ui.theme")
local Keywords = require("src.ui.keywords")
local C = Theme.c

local Inline = {}

local TRIGGERS = {
  { "^On hit:%s*(.*)$", "ON HIT" },
  { "^Enemy death:%s*(.*)$", "ENEMY DEATH" },
  { "^Burned death:%s*(.*)$", "BURNED DEATH" },
  { "^Rotted death:%s*(.*)$", "ROTTED DEATH" },
  { "^Faint:%s*(.*)$", "FAINT" },
  { "^Ally death:%s*(.*)$", "ALLY DEATH" },
  { "^On death:%s*(.*)$", "DEATH" },
  { "^On kill:%s*(.*)$", "ON KILL" },
  { "^On attack:%s*(.*)$", "ATTACK" },
  { "^When hit:%s*(.*)$", "HIT BY" },
  { "^First attack:%s*(.*)$", "FIRST" },
  { "^Combat start:%s*(.*)$", "START" },
  { "^Every [%d%.]+s:%s*(.*)$", "TIMER" },
  { "^At [^:]+ HP:%s*(.*)$", "LOW HP" },
}

local function runWidth(font, text)
  text = tostring(text or "")
  local w = font:getWidth(text)
  if text:match("^%s+$") then w = math.max(w, #text * 4) end
  return w
end
Inline.runWidth = runWidth

function Inline.tokenizeValues(line)
  local out = {}
  for word, sp in tostring(line or ""):gmatch("(%S+)(%s*)") do
    local core = word:gsub("^[%(%[%{<\"']+", "")
    local isVal = core:match("^[%+%-]?%d") ~= nil
    out[#out + 1] = { text = word, sp = sp, value = isVal }
  end
  return out
end

function Inline.extractTrigger(line)
  local s = tostring(line or "")
  for _, spec in ipairs(TRIGGERS) do
    local rest = s:match(spec[1])
    if rest then return spec[2], rest end
  end
  return nil, s
end

local function drawPrismaticText(text, x, y, font, key, t)
  local cx = x
  for i = 1, #text do
    local ch = text:sub(i, i)
    Draw.setColor(Keywords.prismaticColor(key, i, t))
    love.graphics.print(ch, math.floor(cx), math.floor(y))
    cx = cx + font:getWidth(ch)
  end
  return cx - x
end

local function triggerChipMetrics(label, bodyFont)
  local font = Theme.label(8) or bodyFont
  local fh = font and font:getHeight() or 10
  local h = math.max(12, math.floor((bodyFont and bodyFont:getHeight() or fh) * 0.82 + 0.5))
  local w = (font and font:getWidth(label) or #label * 6) + 10
  return w, h, font, fh
end

function Inline.triggerChipWidth(label, bodyFont)
  local w = triggerChipMetrics(label, bodyFont)
  return w + 7
end

local function drawTriggerChip(label, x, y, bodyFont)
  local w, h, font, fh = triggerChipMetrics(label, bodyFont)
  local yy = math.floor(y + ((bodyFont and bodyFont:getHeight() or h) - h) / 2)
  Draw.rect(x, yy, w, h, C.stone900, C.brassD, 1)
  Draw.text(label, x + 4, yy + math.floor((h - fh) / 2), C.brassS, font)
  return w + 7
end
Inline.drawTriggerChip = drawTriggerChip

function Inline.drawLine(line, x, y, font, baseCol, opts)
  opts = opts or {}
  love.graphics.setFont(font)
  local aff = opts.aff
  local affDesc = aff and Keywords.get(aff)
  local affCol = affDesc and affDesc.color or nil
  local activeTags = opts.activeTags
  local t = opts.t

  local trigger, rest = Inline.extractTrigger(line)
  local cx = x
  if trigger then
    cx = cx + drawTriggerChip(trigger, cx, y, font)
    line = rest
  end

  local currentValueColor = affCol
  for _, run in ipairs(Keywords.inlineRuns(line, baseCol, activeTags)) do
    if run.tag then
      local tagIcon = Keywords.icon(run.tag)
      if tagIcon then
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.draw(tagIcon.image, math.floor(cx), math.floor(y + font:getHeight() / 2 - tagIcon.h / 2 + 2), 0, 1, 1)
        cx = cx + tagIcon.w + 2
      end
      if Keywords.isPrismatic(run.tag) then
        cx = cx + drawPrismaticText(run.text, cx, y, font, run.tag, t)
      else
        Draw.setColor(run.color)
        love.graphics.print(run.text, math.floor(cx), math.floor(y))
        cx = cx + runWidth(font, run.text)
      end
      currentValueColor = Keywords.tagColor(run.tag)
    elseif run.text:match("^%s+$") then
      cx = cx + runWidth(font, run.text)
    else
      local lead = run.text:match("^(%s+)") or ""
      if lead ~= "" then cx = cx + runWidth(font, lead) end
      local text = lead ~= "" and run.text:sub(#lead + 1) or run.text
      for _, tok in ipairs(Inline.tokenizeValues(text)) do
        Draw.setColor((tok.value and currentValueColor) or baseCol)
        love.graphics.print(tok.text, math.floor(cx), math.floor(y))
        cx = cx + runWidth(font, tok.text)
        if tok.sp ~= "" then cx = cx + runWidth(font, tok.sp) end
      end
    end
  end
  love.graphics.setColor(1, 1, 1, 1)
end

local function splitParagraphs(text)
  local out = {}
  text = tostring(text or "")
  if text == "" then return out end
  for line in (text .. "\n"):gmatch("(.-)\n") do
    out[#out + 1] = line
  end
  return out
end

function Inline.wrappedLines(text, font, limit, activeTags)
  local out = {}
  for _, raw in ipairs(splitParagraphs(text)) do
    for _, line in ipairs(Keywords.wrapInline(raw, font, limit, activeTags)) do
      out[#out + 1] = line
    end
  end
  return out
end

function Inline.effectHeight(text, font, limit, activeTags, lineGap)
  if not text or text == "" or not font then return 0 end
  local lines = Inline.wrappedLines(text, font, limit, activeTags)
  if #lines == 0 then return 0 end
  lineGap = lineGap or 2
  return #lines * font:getHeight() + (#lines - 1) * lineGap
end

function Inline.drawBlock(text, x, y, limit, opts)
  opts = opts or {}
  local font = opts.font or Theme.body(14) or Theme.bodyLight(14) or love.graphics.getFont()
  local baseCol = opts.baseCol or C.ink2
  local activeTags = opts.activeTags
  local lineGap = opts.lineGap or 2
  local lineH = font:getHeight() + lineGap
  local cy = y
  for _, line in ipairs(Inline.wrappedLines(text, font, limit, activeTags)) do
    Inline.drawLine(line, x, cy, font, baseCol, opts)
    cy = cy + lineH
  end
  return math.max(0, cy - y - lineGap)
end

return Inline
