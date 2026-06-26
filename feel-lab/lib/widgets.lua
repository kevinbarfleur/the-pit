-- feel-lab/lib/widgets.lua
-- COMPOSANTS immediate-mode qui CONSOMMENT les behaviors (lib/behavior.lua) -> démontre « un composant
-- réutilisable = une fonction Component(id, rect, opts, input) ». Chaque widget compose hoverable/pressable/
-- (pulsable) au-dessus de Feel+Juice, applique le transform (scale/lift/tilt) et dessine la DA Wraeclast.
-- C'est l'équivalent LÖVE des composants web : zéro duplication, effets attachés par composition.
--
-- input (état souris CE frame pour le rect) = { over, down, clicked }. Construit par la room via B.hit + flags.

local Draw  = require("lib.draw")
local Theme = require("lib.theme")
local Feel  = require("lib.feel")
local Juice = require("lib.juice")
local B     = require("lib.behavior")

local Widgets = {}
local c = Theme.c
local unpack = unpack or table.unpack   -- LuaJIT (5.1) = global unpack ; filet pour 5.2+

-- tons sémantiques (repris de Theme.tones) -> { fill, fillHot, text, textHot, accent, accentHot, hero }
local TONES = {
  default = { fill = c.stone800, fillHot = c.stone700, text = c.ink2, textHot = c.ink, accent = c.brass,  accentHot = c.brassL },
  cta     = { fill = c.bloodD,   fillHot = c.blood,    text = c.ctaText, textHot = c.ctaText, accent = c.gold, accentHot = c.brassS, hero = true },
  eco     = { fill = c.ecoBg,    fillHot = c.ecoBgHot, text = c.ink2, textHot = c.ink, accent = c.brass,  accentHot = c.brassL },
  drop    = { fill = c.stone700, fillHot = c.stone600, text = c.drop, textHot = c.drop, accent = c.drop,   accentHot = c.drop },
  ghost   = { fill = nil,        fillHot = c.stone800, text = c.ink3, textHot = c.ink2, accent = c.line,   accentHot = c.brass },
}

-- transform de scale/tilt autour d'un centre (composant « punché »)
local function pushTRS(cx, cy, s, rot)
  love.graphics.push()
  love.graphics.translate(cx, cy)
  if rot and rot ~= 0 then love.graphics.rotate(rot) end
  if s and s ~= 1 then love.graphics.scale(s, s) end
  love.graphics.translate(-cx, -cy)
end

-- ── PANEL : surface stone + liseré laiton (base de toute boîte) ──────────────────────────────────────────
function Widgets.panel(x, y, w, h, opts)
  opts = opts or {}
  Draw.rrect(x, y, w, h, opts.r or 8, opts.fill or c.stone800, opts.border or c.brassD, opts.bw or 2)
  -- éclat de bord supérieur (lumière qui tombe)
  love.graphics.setColor(c.brass[1], c.brass[2], c.brass[3], 0.18)
  love.graphics.rectangle("fill", x + 3, y + 2, w - 6, 1)
  Draw.reset()
end

-- ── BUTTON : ton + juice complet (hover lift/glow/scale + press squash/flash + action différée + son) ──────
-- opts = { label, tone, font, hero, delay, sound, enabled } ; renvoie fx (pour debug/compo).
function Widgets.button(id, r, opts, input)
  opts = opts or {}
  local tone = TONES[opts.tone or "default"] or TONES.default
  local enabled = opts.enabled ~= false
  input = input or { over = false, down = false, clicked = false }
  if not enabled then input = { over = false, down = false, clicked = false } end

  -- composition de behaviors (LA démonstration : effets attachés, pas codés en dur dans le widget)
  local chain = { B.hoverable }
  if tone.hero then chain[#chain + 1] = { B.pulsable, 1.0 } end
  chain[#chain + 1] = { B.pressable, function()
    if opts.onClick then opts.onClick() end
  end, { delay = opts.delay or (tone.hero and Feel.CTA_DELAY or 0.14) } }
  local fx = B.compose(unpack(chain))(id, r, input)

  local hot = input.over
  local fill = enabled and (hot and tone.fillHot or tone.fill) or c.stone900
  local accent = enabled and (hot and tone.accentHot or tone.accent) or c.line
  local text = enabled and (hot and tone.textHot or tone.text) or c.ghost

  local cx, cy = r.x + r.w / 2, r.y + r.h / 2
  pushTRS(cx, cy + fx.dy, fx.scale, fx.rot)
  love.graphics.translate(0, fx.dy)
  -- ombre douce (le bouton « décolle » au survol)
  if enabled and fx.dy < -0.4 then
    love.graphics.setColor(0, 0, 0, 0.28)
    love.graphics.rectangle("fill", r.x + 2, r.y - fx.dy + 3, r.w, r.h, 8, 8)
  end
  if fill then Draw.rrect(r.x, r.y, r.w, r.h, 8, fill, accent, tone.hero and 2.5 or 2)
  else Draw.rrect(r.x, r.y, r.w, r.h, 8, nil, accent, 2) end
  -- glow interne de survol
  if fx.glow and fx.glow > 0.01 then
    love.graphics.setColor(accent[1], accent[2], accent[3], 0.16 * fx.glow)
    love.graphics.rectangle("fill", r.x + 2, r.y + 2, r.w - 4, r.h - 4, 7, 7)
  end
  -- flash de press (braise, jamais blanc pur)
  if fx.flash and fx.flash > 0.01 then
    love.graphics.setColor(c.ember[1], c.ember[2], c.ember[3], 0.5 * fx.flash)
    love.graphics.rectangle("fill", r.x + 2, r.y + 2, r.w - 4, r.h - 4, 7, 7)
  end
  local font = opts.font or Theme.title(16)
  Draw.textTrackedC((opts.label or ""):upper(), cx, cy - font:getHeight() / 2, text, font, 2)
  love.graphics.pop()
  Draw.reset()
  return fx
end

-- ── TOGGLE : interrupteur on/off (chip) ─────────────────────────────────────────────────────────────────
function Widgets.toggle(id, r, opts, input)
  opts = opts or {}
  input = input or {}
  local fx = B.compose(B.hoverable, { B.pressable, function() if opts.onClick then opts.onClick() end end, { delay = 0.05 } })(id, r, input)
  local on = opts.on
  local cx, cy = r.x + r.w / 2, r.y + r.h / 2
  pushTRS(cx, cy, fx.scale, 0)
  love.graphics.translate(0, fx.dy)
  local accent = on and c.regen or c.line
  Draw.rrect(r.x, r.y, r.w, r.h, r.h / 2, on and c.stone700 or c.stone850, accent, 2)
  local knobR = r.h / 2 - 3
  local kx = on and (r.x + r.w - knobR - 4) or (r.x + knobR + 4)
  love.graphics.setColor(accent[1], accent[2], accent[3], 1)
  love.graphics.circle("fill", kx, cy, knobR)
  love.graphics.pop()
  if opts.label then
    Draw.textR(opts.label:upper(), r.x - 12, cy - Theme.label(12):getHeight() / 2, on and c.ink2 or c.ink4, Theme.label(12))
  end
  Draw.reset()
  return fx
end

-- ── CARD : carte hoverable (titre + corps) — démontre lift/glow/scale sur un élément non-bouton ───────────
function Widgets.card(id, r, opts, input)
  opts = opts or {}
  input = input or {}
  local fx = B.compose(B.hoverable, B.shakeable)(id, r, input)
  local cx, cy = r.x + r.w / 2, r.y + r.h / 2
  pushTRS(cx, cy, fx.scale, fx.rot)
  love.graphics.translate(fx.dx, fx.dy)
  -- ombre projetée (grandit avec le lift)
  local lift = -fx.dy
  if lift > 0.3 then
    love.graphics.setColor(0, 0, 0, 0.30)
    love.graphics.rectangle("fill", r.x + 3, r.y + lift + 5, r.w, r.h, 9, 9)
  end
  local accent = opts.accent or c.brass
  Widgets.panel(r.x, r.y, r.w, r.h, { r = 9, fill = input.over and c.stone700 or c.stone800, border = input.over and accent or c.brassD })
  if fx.glow and fx.glow > 0.01 then
    love.graphics.setColor(accent[1], accent[2], accent[3], 0.14 * fx.glow)
    love.graphics.rectangle("fill", r.x + 3, r.y + 3, r.w - 6, r.h - 6, 7, 7)
  end
  if opts.title then
    Draw.textTrackedC(opts.title:upper(), cx, r.y + 14, c.ink, Theme.subhead(15), 1)
    Draw.divider(cx, r.y + 38, r.w * 0.7, accent, 0.6)
  end
  if opts.body then
    Draw.textWrap(opts.body, r.x + 14, r.y + 48, r.w - 28, c.ink2, Theme.body(13), "center")
  end
  love.graphics.pop()
  Draw.reset()
  return fx
end

return Widgets
