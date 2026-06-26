-- src/ui/chip.lua
-- PASTILLE keyword (« tag-chip » façon mot-clé TCG) : [icône 8x8][LABEL][valeur], liseré coloré par la
-- famille, fond sombre. La brique de LISIBILITÉ — partout où une affliction/un tag est mentionné, on le
-- voit sous cette forme reconnaissable (carte monstre, codex, reliques). Couche RENDER (love.graphics),
-- dessinée en ESPACE DESIGN (sous Draw.begin). Légère par design (les chips sont nombreux) : pas de biseau
-- complet, juste un liseré 1px + l'icône bakée du registre.
--
-- opts = { key?, label?, value?, color?, valueColor?, font?, icon?, iconScale?, h? }
--   key        : clé d'affliction (poison/bleed/burn/rot/shock) -> icône + couleur + nom par défaut.
--   label      : texte (défaut = nom i18n du keyword). "" pour masquer.
--   value      : nombre/chaîne à droite (ex. 6, "6dps", "2dps·3s"). nil = absent.
--   color      : couleur du liseré + label (défaut = couleur du keyword).
--   icon=false : masque l'icône même si key est fourni (chip de tag pur : rôle, bodyplan...).

local Theme = require("src.ui.theme")
local Draw = require("src.ui.draw")
local Keywords = require("src.ui.keywords")
local C = Theme.c

local Chip = {}

local PAD = 4 -- marge intérieure gauche/droite
local GAP = 3 -- espace icône/label/valeur

local function resolveLabel(opts)
  if opts.label ~= nil then return opts.label end
  if opts.key then return Keywords.name(opts.key) end
  return ""
end

local function resolveColor(opts)
  if opts.color then return opts.color end
  local a = opts.key and Keywords.get(opts.key)
  return a and a.color or C.muted
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

-- Largeur d'un chip SANS le dessiner (mise en page d'une rangée).
function Chip.width(opts)
  local font = opts.font or love.graphics.getFont()
  local label = resolveLabel(opts)
  local w = PAD * 2
  if opts.key and opts.icon ~= false then
    local ic = Keywords.icon(opts.key)
    if ic then w = w + ic.w * (opts.iconScale or 1) + GAP end
  end
  if label ~= "" then w = w + font:getWidth(label) end
  if opts.value ~= nil then w = w + GAP + font:getWidth(tostring(opts.value)) end
  return w
end

-- Dessine le chip à (x, y). Retourne (w, h).
function Chip.draw(x, y, opts)
  opts = opts or {}
  local font = opts.font or love.graphics.getFont()
  if font then love.graphics.setFont(font) end
  local fh = font and font:getHeight() or 12
  local h = opts.h or (fh + PAD)
  local label = resolveLabel(opts)
  local color = resolveColor(opts)
  local prismatic = opts.key and Keywords.isPrismatic(opts.key)
  local w = Chip.width(opts)

  -- Fond sombre + liseré coloré (1px) : le chip emprunte la teinte de son mot-clé.
  Draw.rect(x, y, w, h, C.panelDeep, prismatic and C.ink or color, 1)
  if prismatic and love.graphics and love.graphics.rectangle then
    local pal = Keywords.PRISMATIC_PALETTE
    local stripeW = math.max(1, math.floor((w - 2) / #pal))
    for i, col in ipairs(pal) do
      Draw.setColor(col)
      love.graphics.rectangle("fill", math.floor(x + 1 + (i - 1) * stripeW), y + 1, stripeW, 1)
    end
  end

  local cx = x + PAD
  local midY = y + h / 2

  if opts.key and opts.icon ~= false then
    local ic = Keywords.icon(opts.key)
    if ic then
      local s = opts.iconScale or 1
      love.graphics.setColor(1, 1, 1, 1)
      love.graphics.draw(ic.image, math.floor(cx), math.floor(midY - ic.h * s / 2 + 1), 0, s, s)
      cx = cx + ic.w * s + GAP
    end
  end

  if label ~= "" then
    if prismatic then
      drawPrismaticText(label, cx, midY - fh / 2, font, opts.key, opts.t)
    else
      Draw.setColor(color)
      love.graphics.print(label, math.floor(cx), math.floor(midY - fh / 2))
    end
    cx = cx + font:getWidth(label)
  end

  if opts.value ~= nil then
    cx = cx + GAP
    Draw.setColor(opts.valueColor or C.inkBright)
    love.graphics.print(tostring(opts.value), math.floor(cx), math.floor(midY - fh / 2))
  end

  love.graphics.setColor(1, 1, 1, 1)
  return w, h
end

-- Rangée de chips (specs gauche->droite). opts = { font?, gap? }. Renvoie la largeur totale occupée.
function Chip.row(x, y, chips, opts)
  opts = opts or {}
  if opts.font then love.graphics.setFont(opts.font) end
  local gap = opts.gap or 4
  local cx = x
  for _, spec in ipairs(chips) do
    local w = Chip.draw(cx, y, spec)
    cx = cx + w + gap
  end
  return #chips > 0 and (cx - x - gap) or 0
end

return Chip
