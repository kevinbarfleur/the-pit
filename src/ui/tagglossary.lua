-- src/ui/tagglossary.lua
-- Shift glossary panel for a hovered monster card. Render-only, built on the
-- same tag registry as the card: visible tags, triggers, then a compact reading
-- key for affliction numbers.

local Draw = require("src.ui.draw")
local Theme = require("src.ui.theme")
local Panel = require("src.ui.panel")
local Dividers = require("src.ui.dividers")
local Chip = require("src.ui.chip")
local Keywords = require("src.ui.keywords")
local MechanicsText = require("src.ui.mechanics_text")
local MechanicsInline = require("src.ui.mechanics_inline")
local Units = require("src.data.units")
local Relics = require("src.data.relics")
local I18n = require("src.core.i18n")

local T = I18n.t
local C = Theme.c

local TagGlossary = {}

local W = 350
local PAD = 16
local GAP = 8
local SECTION_GAP = 14
local TAG_CELL_MIN_H = 42
local TRIGGER_MIN_H = 26

local TRIGGER_BLURB = {
  ["ON HIT"] = "ui.trigger.on_hit",
  ["ENEMY DEATH"] = "ui.trigger.enemy_death",
  ["BURNED DEATH"] = "ui.trigger.burned_death",
  ["ROTTED DEATH"] = "ui.trigger.rotted_death",
  FAINT = "ui.trigger.faint",
  DEATH = "ui.trigger.death",
  ["ON KILL"] = "ui.trigger.kill",
  KILL = "ui.trigger.kill",
  ATTACK = "ui.trigger.attack",
  ["HIT BY"] = "ui.trigger.hit_by",
  FIRST = "ui.trigger.first",
  START = "ui.trigger.start",
  TIMER = "ui.trigger.timer",
  ["LOW HP"] = "ui.trigger.low_hp",
  ["ALLY DEATH"] = "ui.trigger.ally_death",
  COMMAND = "ui.trigger.command",
  PASSIVE = "ui.trigger.passive",
}

local function clamp(v, lo, hi)
  if v < lo then return lo end
  if v > hi then return hi end
  return v
end

local function splitTags(unitOrId, tagOpts)
  local afflictions, mechanics = {}, {}
  for _, id in ipairs(Keywords.tagsForUnit(unitOrId, tagOpts)) do
    local d = Keywords.tag(id)
    if d and d.category ~= "type" then
      if d.category == "affliction" then
        afflictions[#afflictions + 1] = id
      else
        mechanics[#mechanics + 1] = id
      end
    end
  end
  return afflictions, mechanics
end

local function splitRelicTags(relicId, tagOpts)
  local afflictions, mechanics = {}, {}
  for _, id in ipairs(Keywords.tagsForRelic(relicId, tagOpts)) do
    local d = Keywords.tag(id)
    if d and d.category ~= "type" then
      if d.category == "affliction" then
        afflictions[#afflictions + 1] = id
      else
        mechanics[#mechanics + 1] = id
      end
    elseif d and d.category == "type" then
      mechanics[#mechanics + 1] = id
    end
  end
  return afflictions, mechanics
end

local function triggerRows(unitOrId, tagOpts)
  local commandContext = tagOpts and tagOpts.context == "commander"
  local blocks = {}
  if commandContext then
    local cmd = MechanicsText.commandBlock(unitOrId)
    if cmd then blocks[1] = cmd end
  else
    blocks = MechanicsText.unitBlocks(unitOrId)
  end
  local seen, out = {}, {}
  for _, block in ipairs(blocks or {}) do
    local label = block and block.trigger or "PASSIVE"
    if not seen[label] then
      seen[label] = true
      out[#out + 1] = label
    end
  end
  return out
end

local function relicTriggerRows(relicId)
  local seen, out = {}, {}
  for _, line in ipairs(MechanicsText.relicLines(relicId)) do
    local label = MechanicsText.extractTrigger(line)
    label = label or "PASSIVE"
    if not seen[label] then
      seen[label] = true
      out[#out + 1] = label
    end
  end
  return out
end

local function wrapCount(font, text, w)
  if not font or not text or text == "" then return 1 end
  local _, lines = font:getWrap(text, math.max(8, w))
  return math.max(1, #lines)
end

local function tagCellHeight(id, w, fonts)
  local blurbW = math.max(24, w - 38)
  local lines = wrapCount(fonts.small, Keywords.tagBlurb(id), blurbW)
  local lineH = fonts.small:getHeight() + 1
  return math.max(TAG_CELL_MIN_H, 24 + lines * lineH + 6)
end

local function tagGridHeight(ids, w, fonts)
  if #ids == 0 then return fonts.body:getHeight() end
  local rows = math.ceil(#ids / 2)
  local colGap = GAP
  local colW = math.floor((w - colGap) / 2)
  local h = 0
  for row = 1, rows do
    local i1 = (row - 1) * 2 + 1
    local i2 = i1 + 1
    local rowH
    if i1 == #ids and #ids % 2 == 1 then
      rowH = tagCellHeight(ids[i1], w, fonts)
    else
      rowH = math.max(tagCellHeight(ids[i1], colW, fonts), ids[i2] and tagCellHeight(ids[i2], colW, fonts) or 0)
    end
    h = h + rowH
    if row < rows then h = h + GAP end
  end
  return h
end

local function triggerRowHeight(label, w, fonts)
  local chipW = MechanicsInline.triggerChipWidth(label, fonts.body)
  local textW = math.max(32, w - chipW - 20)
  local key = TRIGGER_BLURB[label] or "ui.trigger.passive"
  local lines = wrapCount(fonts.body, T(key), textW)
  return math.max(TRIGGER_MIN_H, 8 + lines * fonts.body:getHeight() + 8)
end

local function triggerHeight(rows, fonts, w)
  if #rows == 0 then return fonts.body:getHeight() end
  local h = 0
  for i, label in ipairs(rows) do
    h = h + triggerRowHeight(label, w, fonts)
    if i < #rows then h = h + 6 end
  end
  return h
end

local function measureContent(data, fonts, innerW)
  local sectionH = fonts.section:getHeight() + GAP
  local h = 0
  h = h + sectionH + tagGridHeight(data.afflictions, innerW, fonts)
  if #data.mechanics > 0 then h = h + SECTION_GAP + sectionH + tagGridHeight(data.mechanics, innerW, fonts) end
  h = h + SECTION_GAP + sectionH + triggerHeight(data.triggers, fonts, innerW)
  h = h + SECTION_GAP + sectionH + 34 + fonts.small:getHeight() + 4
  h = h + SECTION_GAP + fonts.small:getHeight() * 2
  return h
end

local function anchor(cardBox, h)
  local x = cardBox.x + cardBox.w + GAP
  if x + W > Draw.W - 4 then x = cardBox.x - W - GAP end
  if x < 4 then x = clamp(cardBox.x, 4, Draw.W - W - 4) end
  local y = clamp(cardBox.y, 4, Draw.H - h - 4)
  return math.floor(x + 0.5), math.floor(y + 0.5)
end

local function restoreScissor(old)
  if old and old[1] then love.graphics.setScissor(old[1], old[2], old[3], old[4]) else love.graphics.setScissor() end
end

function TagGlossary.clampScroll(scroll, contentH, panelH)
  local maxScroll = math.max(0, contentH - (panelH - PAD * 2))
  return clamp(scroll or 0, 0, maxScroll)
end

local function drawSection(cx, y, w, label, fonts)
  Dividers.text(cx, y, w, label, 2)
  return y + fonts.section:getHeight() + GAP
end

local function drawTagCell(id, x, y, w, h, fonts)
  local col = Keywords.tagColor(id)
  Draw.rect(x, y, w, h, C.stone800, C.iron, 1)
  Draw.setColor(col, 0.65)
  love.graphics.rectangle("fill", x + 1, y + 1, 2, h - 2)
  local ic = Keywords.icon(id)
  local tx = x + 30
  if ic then
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.draw(ic.image, math.floor(x + 9), math.floor(y + 8), 0, 1, 1)
  end
  Draw.text(Keywords.tagName(id), tx, y + 6, col, fonts.chip)
  Draw.textWrap(Keywords.tagBlurb(id), tx, y + 22, w - 38, C.ink3, fonts.small)
end

local function drawTagGrid(ids, x, y, w, fonts)
  if #ids == 0 then
    Draw.text(T("ui.keyword_unit_empty"), x, y, C.ink3, fonts.body)
    return fonts.body:getHeight()
  end
  local colGap = GAP
  local colW = math.floor((w - colGap) / 2)
  local rowY = y
  for i, id in ipairs(ids) do
    local col = (i - 1) % 2
    local singleLast = (#ids % 2 == 1 and i == #ids)
    if col == 0 then
      if i > 1 then
        local p1, p2 = ids[i - 2], ids[i - 1]
        rowY = rowY + math.max(tagCellHeight(p1, colW, fonts), p2 and tagCellHeight(p2, colW, fonts) or 0) + GAP
      end
    end
    local cw = singleLast and w or colW
    local ch
    if singleLast then
      ch = tagCellHeight(id, w, fonts)
    else
      local mate = (col == 0) and ids[i + 1] or ids[i - 1]
      ch = math.max(tagCellHeight(id, colW, fonts), mate and tagCellHeight(mate, colW, fonts) or 0)
    end
    drawTagCell(id, x + col * (colW + colGap), rowY, cw, ch, fonts)
  end
  return tagGridHeight(ids, w, fonts)
end

local function drawTriggers(rows, x, y, w, fonts)
  if #rows == 0 then
    Draw.text(T("ui.keyword_no_triggers"), x, y, C.ink3, fonts.body)
    return fonts.body:getHeight()
  end
  local cy = y
  for _, label in ipairs(rows) do
    local rowH = triggerRowHeight(label, w, fonts)
    Draw.rect(x, cy, w, rowH, C.stone900, C.brassD, 1)
    local chipW = MechanicsInline.drawTriggerChip(label, x + 8, cy + 8, fonts.body)
    local key = TRIGGER_BLURB[label] or "ui.trigger.passive"
    Draw.textWrap(T(key), x + 8 + chipW + 2, cy + 8, w - chipW - 20, C.ink2, fonts.body)
    cy = cy + rowH + 6
  end
  return triggerHeight(rows, fonts, w)
end

local function drawAnatomy(sample, x, y, w, fonts, t, afflictionSample)
  Draw.rect(x, y, w, 34, C.stone900, C.iron, 1)
  if sample then
    local col = Keywords.tagColor(sample)
    Draw.setColor(col, 0.7)
    love.graphics.rectangle("fill", x + 1, y + 1, 3, 32)
    Chip.draw(x + 10, y + 8, { key = sample, font = fonts.chip, h = 18, t = t })
  end
  Draw.textR(afflictionSample and "3/s" or "+12%", x + w - 78, y + 10, C.ink2, fonts.chip)
  Draw.textR("4s", x + w - 42, y + 10, C.ink2, fonts.chip)
  Draw.textR("x12", x + w - 8, y + 10, C.ink2, fonts.chip)
  return 34
end

function TagGlossary.draw(view, cardBox, unitId, t, opts)
  opts = opts or {}
  local unit = opts.unit or Units[unitId]
  if not cardBox or not unit then return nil end
  local resolvedId = unit.id or unitId
  local afflictions, mechanics = splitTags(unit, opts.tagOpts)
  local data = {
    afflictions = afflictions,
    mechanics = mechanics,
    triggers = triggerRows(unit, opts.tagOpts),
    name = T("unit." .. resolvedId .. ".name"),
  }
  return TagGlossary.drawData(view, cardBox, data, t, opts)
end

function TagGlossary.drawRelic(view, cardBox, relicId, t, opts)
  opts = opts or {}
  if not cardBox or not Relics[relicId] then return nil end
  local fonts = TagGlossary.fonts()
  local afflictions, mechanics = splitRelicTags(relicId, opts.tagOpts)
  local data = {
    afflictions = afflictions,
    mechanics = mechanics,
    triggers = relicTriggerRows(relicId),
    name = T("relic." .. relicId .. ".name"),
  }
  return TagGlossary.drawData(view, cardBox, data, t, opts, fonts)
end

function TagGlossary.fonts()
  return {
    title = Theme.subhead(14) or Theme.heading(14) or love.graphics.getFont(),
    section = Theme.label(9) or love.graphics.getFont(),
    chip = Theme.label(8) or love.graphics.getFont(),
    body = Theme.body(11) or Theme.bodyLight(11) or love.graphics.getFont(),
    small = Theme.bodyItalic(10) or Theme.body(10) or love.graphics.getFont(),
  }
end

function TagGlossary.drawData(view, cardBox, data, t, opts, fonts)
  opts = opts or {}
  fonts = fonts or TagGlossary.fonts()
  local title = T("ui.keyword_system_title", { name = tostring(data.name or ""):upper() })
  local titleH = fonts.title:getHeight()
  local innerW = W - PAD * 2
  local contentH = measureContent(data, fonts, innerW)
  local maxH = Draw.H - 8
  local panelH = math.min(maxH, PAD + titleH + GAP + contentH + PAD)
  local x, y = anchor(cardBox, panelH)
  local clipY = y + PAD + titleH + GAP
  local clipH = panelH - PAD - titleH - GAP - PAD
  local scroll = clamp(opts.scroll or 0, 0, math.max(0, contentH - clipH))

  Panel.draw(x, y, W, panelH, { fill1 = C.stone850, fill2 = C.stone900, accent = C.brassD, solid = true })
  Draw.text(title, x + PAD, y + PAD, C.ink, fonts.title)

  local old
  if love.graphics.getScissor then
    local sx, sy, sw, sh = love.graphics.getScissor()
    old = { sx, sy, sw, sh }
  end
  if view then Draw.scissor(view, x + 1, clipY, W - 2, clipH) end

  local cy = clipY - scroll
  cy = drawSection(x + W / 2, cy, innerW, T("ui.keyword_section_afflictions"), fonts)
  cy = cy + drawTagGrid(data.afflictions, x + PAD, cy, innerW, fonts)

  if #data.mechanics > 0 then
    cy = cy + SECTION_GAP
    cy = drawSection(x + W / 2, cy, innerW, T("ui.keyword_section_mechanics"), fonts)
    cy = cy + drawTagGrid(data.mechanics, x + PAD, cy, innerW, fonts)
  end

  cy = cy + SECTION_GAP
  cy = drawSection(x + W / 2, cy, innerW, T("ui.keyword_section_triggers"), fonts)
  cy = cy + drawTriggers(data.triggers, x + PAD, cy, innerW, fonts)

  cy = cy + SECTION_GAP
  cy = drawSection(x + W / 2, cy, innerW, T("ui.keyword_section_readline"), fonts)
  local sample = data.afflictions[1] or data.mechanics[1]
  local sampleAffliction = data.afflictions[1] ~= nil
  cy = cy + drawAnatomy(sample, x + PAD, cy, innerW, fonts, t, sampleAffliction)
  cy = cy + 4
  Draw.text(T(sampleAffliction and "ui.keyword_metric_dps" or "ui.keyword_metric_value"), x + PAD + 2, cy, C.ink3, fonts.small)
  Draw.textR(T("ui.keyword_metric_duration"), x + PAD + innerW - 2, cy, C.ink3, fonts.small)
  cy = cy + fonts.small:getHeight() + 4
  Draw.text(T("ui.keyword_metric_cap"), x + PAD + 2, cy, C.ink3, fonts.small)

  cy = cy + SECTION_GAP
  Draw.textWrap(T("ui.keyword_rule"), x + PAD, cy, innerW, C.ink4, fonts.small)

  if view then restoreScissor(old) end

  local overflow = contentH > clipH + 0.5
  if overflow then
    local trackH = clipH
    local maxScroll = math.max(1, contentH - clipH)
    local thumbH = math.max(18, trackH * (clipH / contentH))
    local thumbY = clipY + (trackH - thumbH) * (scroll / maxScroll)
    Draw.rect(x + W - 6, clipY, 2, trackH, C.stone700)
    Draw.rect(x + W - 7, thumbY, 4, thumbH, C.brass)
  end

  Draw.reset()
  return { x = x, y = y, w = W, h = panelH, contentH = contentH, scroll = scroll }
end

return TagGlossary
