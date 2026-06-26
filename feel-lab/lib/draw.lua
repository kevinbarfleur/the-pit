-- feel-lab/lib/draw.lua
-- Helpers de rendu en ESPACE DESIGN 1280x720 (= 320x180 ×4). Version LEAN portée du jeu (src/ui/draw.lua) :
-- on retire la dépendance à Frame (le bouton « runique » baké) — le lab dessine ses boutons via behaviors.
-- TOUT le reste (texte net HiDPI, scissor, formes) est identique au jeu pour une DA fidèle.
--
-- Couche RENDER pure (love.graphics), headless-safe via les gardes habituelles. S'appuie sur lib/theme.lua
-- pour les polices (texte net à toute résolution). setColor déballe {r,g,b,a}.

local Theme = require("lib.theme")

local Draw = { W = 1280, H = 720, uiScale = 1 }

-- TEXTE NET À TOUTE RÉSOLUTION : trace une police rasterisée à la taille ÉCRAN (px × uiScale) + contre-scale
-- 1/uiScale -> rendu 1:1, net (1080p/1440p/4K). uiScale<=1 -> police design directe (inchangé).
local function nativeOf(designFont)
  local s = Draw.uiScale or 1
  if s <= 1.01 or not designFont then return designFont, 1 end
  local meta = Theme._meta and Theme._meta[designFont]
  if not meta then return designFont, 1 end
  local nf = Theme.fontNative(meta.role, meta.px, s)
  if not nf then return designFont, 1 end
  return nf, 1 / s
end

-- ─────────────────────────── Transform espace-design <-> écran ───────────────────────────
function Draw.begin(view)
  love.graphics.push()
  love.graphics.translate(view.ox or 0, view.oy or 0)
  local s = (view.scale or 4) / 4
  love.graphics.scale(s, s)
  Draw.uiScale = s
  if Theme.setScale then Theme.setScale(s) end
end
function Draw.finish() love.graphics.pop() end

-- CLIP (scissor) en ESPACE DESIGN -> conteneurs scrollables sans débordement.
function Draw.scissor(view, x, y, w, h)
  local s = (view.scale or 4) / 4
  love.graphics.setScissor(
    math.floor((view.ox or 0) + x * s),
    math.floor((view.oy or 0) + y * s),
    math.ceil(w * s),
    math.ceil(h * s))
end
function Draw.noScissor() love.graphics.setScissor() end

-- ─────────────────────────────────── Couleur ───────────────────────────────────
function Draw.setColor(c, a)
  if not c then return end
  love.graphics.setColor(c[1], c[2], c[3], a or c[4] or 1)
end
function Draw.reset() love.graphics.setColor(1, 1, 1, 1) end

-- ─────────────────────────────────── Formes ───────────────────────────────────
function Draw.rect(x, y, w, h, fill, border, bw)
  if fill then Draw.setColor(fill); love.graphics.rectangle("fill", x, y, w, h) end
  if border then
    Draw.setColor(border)
    love.graphics.setLineWidth(bw or 2)
    love.graphics.rectangle("line", x, y, w, h)
    love.graphics.setLineWidth(1)
  end
end

-- Rect à coins arrondis (le lab se permet le rayon : c'est de l'UI native, pas du sprite sur grille).
function Draw.rrect(x, y, w, h, r, fill, border, bw)
  if fill then Draw.setColor(fill); love.graphics.rectangle("fill", x, y, w, h, r, r) end
  if border then
    Draw.setColor(border)
    love.graphics.setLineWidth(bw or 2)
    love.graphics.rectangle("line", x, y, w, h, r, r)
    love.graphics.setLineWidth(1)
  end
end

-- Filet horizontal en dégradé (transparent -> couleur -> transparent), comme la DA. cx = centre.
function Draw.divider(cx, y, w, color, alpha)
  local n = 48
  local step = w / n
  local x0 = cx - w / 2
  for i = 0, n - 1 do
    local t = i / (n - 1)
    local a = (1 - math.abs(t * 2 - 1)) * (alpha or 1)
    Draw.setColor(color, a * (color[4] or 1))
    love.graphics.rectangle("fill", x0 + i * step, y, step + 0.6, 1)
  end
end

-- ─────────────────────────────────── Texte ───────────────────────────────────
function Draw.text(str, x, y, color, font)
  local nf, inv = nativeOf(font or love.graphics.getFont())
  love.graphics.setFont(nf)
  Draw.setColor(color)
  love.graphics.print(str, math.floor(x + 0.5), math.floor(y + 0.5), 0, inv, inv)
end

function Draw.textC(str, cx, y, color, font)
  font = font or love.graphics.getFont()
  local w = font:getWidth(str)
  local nf, inv = nativeOf(font)
  love.graphics.setFont(nf)
  Draw.setColor(color)
  love.graphics.print(str, math.floor(cx - w / 2 + 0.5), math.floor(y + 0.5), 0, inv, inv)
end

-- Itère les CARACTÈRES UTF-8 (sûr pour « · », « — », accents). Pur Lua (pas de module utf8).
local function utf8chars(str)
  local i, n = 1, #str
  return function()
    if i > n then return nil end
    local b = string.byte(str, i) or 0
    local len = (b >= 0xF0 and 4) or (b >= 0xE0 and 3) or (b >= 0xC0 and 2) or 1
    local ch = string.sub(str, i, i + len - 1)
    i = i + len
    return ch
  end
end

-- Texte centré AVEC interlettrage (cérémonial). UTF-8-safe. Renvoie la largeur totale.
function Draw.textTrackedC(str, cx, y, color, font, spacing)
  font = font or love.graphics.getFont()
  local nf, inv = nativeOf(font)
  love.graphics.setFont(nf)
  Draw.setColor(color)
  spacing = spacing or 0
  local total, first = 0, true
  for ch in utf8chars(str) do
    if not first then total = total + spacing end
    total = total + font:getWidth(ch)
    first = false
  end
  local x = cx - total / 2
  for ch in utf8chars(str) do
    love.graphics.print(ch, math.floor(x + 0.5), math.floor(y + 0.5), 0, inv, inv)
    x = x + font:getWidth(ch) + spacing
  end
  return total
end

function Draw.textTrackedL(str, x, y, color, font, spacing)
  font = font or love.graphics.getFont()
  local nf, inv = nativeOf(font)
  love.graphics.setFont(nf)
  Draw.setColor(color)
  spacing = spacing or 0
  local cx = x
  for ch in utf8chars(str) do
    love.graphics.print(ch, math.floor(cx + 0.5), math.floor(y + 0.5), 0, inv, inv)
    cx = cx + font:getWidth(ch) + spacing
  end
  return cx - x
end

function Draw.textR(str, rx, y, color, font)
  font = font or love.graphics.getFont()
  local w = font:getWidth(str)
  local nf, inv = nativeOf(font)
  love.graphics.setFont(nf)
  Draw.setColor(color)
  love.graphics.print(str, math.floor(rx - w + 0.5), math.floor(y + 0.5), 0, inv, inv)
end

function Draw.textWrap(str, x, y, limit, color, font, align)
  font = font or love.graphics.getFont()
  align = align or "left"
  local _, lines = font:getWrap(str, limit)
  local nf, inv = nativeOf(font)
  Draw.setColor(color)
  if inv == 1 then
    love.graphics.setFont(nf)
    love.graphics.printf(str, math.floor(x + 0.5), math.floor(y + 0.5), limit, align)
  else
    love.graphics.setFont(nf)
    local lh = font:getHeight()
    for i, line in ipairs(lines) do
      local lw = font:getWidth(line)
      local lx = x
      if align == "center" then lx = x + (limit - lw) / 2
      elseif align == "right" then lx = x + (limit - lw) end
      love.graphics.print(line, math.floor(lx + 0.5), math.floor(y + (i - 1) * lh + 0.5), 0, inv, inv)
    end
  end
  return #lines * font:getHeight()
end

function Draw.textWidth(str, font)
  font = font or love.graphics.getFont()
  return font:getWidth(str)
end

-- Barre de valeur (PV/bouclier) : fond + remplissage proportionnel. pct dans [0,1].
function Draw.bar(x, y, w, h, pct, fill, bg, border)
  if bg then Draw.rect(x, y, w, h, bg) end
  local fw = math.max(0, math.min(1, pct)) * w
  if fill and fw > 0 then Draw.setColor(fill); love.graphics.rectangle("fill", x, y, fw, h) end
  if border then Draw.rect(x, y, w, h, nil, border, 1) end
end

return Draw
