-- src/ui/influence_panel.lua
-- Shared sidecar for board/combat influences. Render-only, drawn in design space
-- while the caller already has Draw.begin(view) active.

local Draw = require("src.ui.draw")
local Theme = require("src.ui.theme")
local Panel = require("src.ui.panel")
local Dividers = require("src.ui.dividers")
local Keywords = require("src.ui.keywords")
local I18n = require("src.core.i18n")

local T = I18n.t
local C = Theme.c

local InfluencePanel = {}

local W = 254
local GAP = 8
local PAD = 12
local MAX_H = 432
local ROW_GAP = 7

local KIND_NAME = {
  poison = "Poison",
  burn = "Burn",
  bleed = "Bleed",
  rot = "Rot",
  shock = "Shock",
  shield = "Shield",
  guard = "Guard",
  armor = "Guard",
  haste = "Haste",
  empower = "Damage",
  growth = "Growth",
  regen = "Regen",
  heal = "Lifesteal",
  echo = "Multicast",
  mimicry = "Aura",
  multicast = "Multicast",
  slow = "Slow",
  state = "State",
  whisper = "Murmur",
}

local function clamp(v, lo, hi)
  if v < lo then return lo end
  if v > hi then return hi end
  return v
end

local function color(kind)
  local k = kind or "state"
  if Keywords and Keywords.tagColor then
    local ok, col = pcall(Keywords.tagColor, k)
    if ok and col then return col end
  end
  return C[k] or C.ink3
end

local function trim(s)
  s = tostring(s or "")
  return (s:gsub("^%s+", ""):gsub("%s+$", ""))
end

local function startsWith(s, p)
  return s:sub(1, #p) == p
end

function InfluencePanel.kindName(kind)
  return KIND_NAME[kind] or (kind and tostring(kind):gsub("^%l", string.upper)) or T("ui.influence_effect")
end

function InfluencePanel.formatValue(kind, raw)
  raw = trim(raw)
  if raw == "" then return InfluencePanel.kindName(kind) end
  local name = InfluencePanel.kindName(kind)
  if startsWith(raw, name) then return raw end
  if kind == "shield" then return "Shield " .. raw
  elseif kind == "state" then return raw
  elseif kind == "guard" or kind == "armor" then return "Guard " .. raw .. " damage taken"
  elseif kind == "haste" then return "Haste " .. raw .. " attack speed"
  elseif kind == "empower" then return "Damage " .. raw
  elseif kind == "growth" then return "Growth " .. raw
  elseif kind == "regen" then return "Regen " .. raw
  elseif kind == "heal" then return "Lifesteal " .. raw
  elseif kind == "echo" or kind == "multicast" then return "Multicast " .. raw
  elseif kind == "mimicry" then return "Aura " .. raw
  elseif kind == "slow" then return "Slow " .. raw .. " attack speed"
  elseif kind == "whisper" then return raw
  elseif kind == "burn" and raw == "∞" then return "Burn no decay"
  elseif kind == "poison" or kind == "burn" or kind == "bleed" or kind == "rot" or kind == "shock" then
    if raw:find("dps", 1, true) or raw:find("/s", 1, true) or raw:find("stack", 1, true) then
      return name .. " " .. raw
    end
    return name .. " " .. raw .. " damage"
  end
  return name .. " " .. raw
end

function InfluencePanel.union(a, b)
  if not a then return b end
  if not b then return a end
  local x1 = math.min(a.x, b.x)
  local y1 = math.min(a.y, b.y)
  local x2 = math.max(a.x + a.w, b.x + b.w)
  local y2 = math.max(a.y + a.h, b.y + b.h)
  return { x = x1, y = y1, w = x2 - x1, h = y2 - y1 }
end

function InfluencePanel.anchor(cardBox, h, opts)
  opts = opts or {}
  local w = opts.w or W
  local gap = opts.gap or GAP
  local spaceR = Draw.W - (cardBox.x + cardBox.w) - gap - 4
  local spaceL = cardBox.x - gap - 4
  local right = spaceR >= w or spaceR >= spaceL
  local x = right and (cardBox.x + cardBox.w + gap) or (cardBox.x - w - gap)
  if x + w > Draw.W - 4 then x = Draw.W - w - 4 end
  if x < 4 then x = 4 end
  local y = clamp(cardBox.y, 4, Draw.H - h - 4)
  return math.floor(x + 0.5), math.floor(y + 0.5), w
end

local function wrapHeight(font, text, w)
  if not text or text == "" then return 0 end
  local _, lines = font:getWrap(text, math.max(20, w))
  return #lines * (font:getHeight() + 1)
end

local function rowHeight(row, fonts, innerW)
  local detailW = innerW - 20
  local h = fonts.value:getHeight()
  if row.source and row.source ~= "" then h = h + fonts.small:getHeight() + 1 end
  if row.detail and row.detail ~= "" then h = h + wrapHeight(fonts.body, row.detail, detailW) + 2 end
  return math.max(28, h + 8)
end

local function measure(data, fonts, innerW)
  local h = PAD + fonts.head:getHeight() + 8
  local any = false
  for _, sec in ipairs(data.sections or {}) do
    if sec.rows and #sec.rows > 0 then
      any = true
      h = h + 11 + fonts.section:getHeight() + 7
      for _, row in ipairs(sec.rows) do h = h + rowHeight(row, fonts, innerW) + ROW_GAP end
    end
  end
  if not any then h = h + fonts.body:getHeight() + 10 end
  return math.min(MAX_H, h + PAD), h + PAD
end

local function drawKindIcon(kind, x, y, col)
  local ic = kind and Keywords.icon(kind)
  if ic and love and love.graphics then
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.draw(ic.image, math.floor(x), math.floor(y), 0, 1, 1)
    return math.max(12, ic.w or 10)
  end
  Draw.setColor(col)
  if love and love.graphics then
    love.graphics.push()
    love.graphics.translate(x + 5, y + 6)
    love.graphics.rotate(0.785398)
    love.graphics.rectangle("fill", -4, -4, 8, 8)
    love.graphics.pop()
  end
  Draw.reset()
  return 12
end

local function drawRow(x, y, w, row, fonts)
  local col = color(row.kind)
  local h = rowHeight(row, fonts, w)
  Draw.rect(x, y, w, h, { 0x0c / 255, 0x09 / 255, 0x12 / 255, 0.76 }, C.iron, 1)
  Draw.setColor(col, 0.75)
  if love and love.graphics then love.graphics.rectangle("fill", x + 1, y + 1, 2, h - 2) end
  Draw.reset()
  local ix = x + 9
  local iw = drawKindIcon(row.kind, ix, y + 8, col)
  local tx = ix + iw + 6
  local rightX = x + w - 8
  if row.badge and row.badge ~= "" then
    local bw = fonts.small:getWidth(row.badge) + 10
    Draw.rect(rightX - bw, y + 7, bw, fonts.small:getHeight() + 4, { 0x12 / 255, 0x0d / 255, 0x08 / 255, 0.95 }, C.brassD, 1)
    Draw.textC(row.badge, rightX - bw / 2, y + 9, C.gold, fonts.small)
    rightX = rightX - bw - 6
  end
  local value = row.valueText or InfluencePanel.formatValue(row.kind, row.value)
  Draw.text(value, tx, y + 6, col, fonts.value)
  local cy = y + 6 + fonts.value:getHeight() + 1
  if row.source and row.source ~= "" then
    Draw.text(row.source, tx, cy, C.ink3, fonts.small)
    cy = cy + fonts.small:getHeight() + 1
  end
  if row.detail and row.detail ~= "" then
    Draw.textWrap(row.detail, tx, cy + 1, math.max(24, w - (tx - x) - 8), C.ink2, fonts.body)
  end
  return h
end

function InfluencePanel.draw(view, cardBox, data, opts)
  if not (view and cardBox and data) then return nil end
  local fonts = {
    head = Theme.label(9),
    section = Theme.label(8),
    value = Theme.value(11),
    small = Theme.label(8),
    body = Theme.body(11),
  }
  local w = (opts and opts.w) or W
  local innerW = w - PAD * 2
  local h, contentH = measure(data, fonts, innerW)
  local x, y = InfluencePanel.anchor(cardBox, h, { w = w })
  Panel.draw(x, y, w, h, { fill1 = C.stone800, fill2 = C.stone900, border = C.iron, solid = true })
  local cx = x + PAD
  local cy = y + PAD
  local title = data.title or T("ui.influence_title")
  Draw.text(title, cx, cy, C.gold, fonts.head)
  local subtitle = data.subtitle or data.unitName
  if subtitle then Draw.textR(subtitle, x + w - PAD, cy, C.ink4, fonts.small) end
  cy = cy + fonts.head:getHeight() + 8

  local old = love.graphics.getScissor and { love.graphics.getScissor() } or nil
  Draw.scissor(view, x + 2, cy, w - 4, h - (cy - y) - PAD)
  local any = false
  for _, sec in ipairs(data.sections or {}) do
    if sec.rows and #sec.rows > 0 then
      any = true
      cy = cy + 4
      Dividers.text(x + w / 2, cy, innerW, sec.title or "")
      cy = cy + fonts.section:getHeight() + 7
      for _, row in ipairs(sec.rows) do
        local rh = drawRow(cx, cy, innerW, row, fonts)
        cy = cy + rh + ROW_GAP
      end
    end
  end
  if not any then
    Draw.textWrap(T("ui.influence_none"), cx, cy, innerW, C.ink4, fonts.body)
  end
  if old and old[1] then love.graphics.setScissor(old[1], old[2], old[3], old[4]) else love.graphics.setScissor() end
  if contentH > h then
    local barH = math.max(18, math.floor((h - PAD * 2) * (h / contentH)))
    Draw.rect(x + w - 5, y + PAD + 20, 2, barH, C.brassD)
  end
  return { x = x, y = y, w = w, h = h }
end

return InfluencePanel
