-- src/ui/draw.lua
-- Helpers de rendu de l'UI en ESPACE DESIGN 1280x720 (= 320x180 ×4). Le prototype DA est composé à
-- 1280x720 ; on dessine donc l'UI native dans ce repère, puis Draw.begin(view) applique la transform
-- (translate ox,oy + scale view.scale/4) pour la mapper sur la zone letterboxée. Au ×4 par défaut le
-- facteur vaut 1.0 -> texte/traits NETS ; aux échelles non-multiples de 4, léger adoucissement (toléré).
--
-- Couche RENDER uniquement (love.graphics) -> hors firewall SIM. S'appuie sur ui/theme.lua pour TOUTES
-- les couleurs et polices (aucune valeur en dur ici). setColor déballe toujours {r,g,b,a} (pas de
-- dépendance à la variante table de love.graphics.setColor).

local Theme = require("src.ui.theme")
local Frame = require("src.ui.frame")

local Draw = { W = 1280, H = 720 }

-- ─────────────────────────── Transform espace-design <-> écran ───────────────────────────
function Draw.begin(view)
  love.graphics.push()
  love.graphics.translate(view.ox or 0, view.oy or 0)
  local s = (view.scale or 4) / 4
  love.graphics.scale(s, s)
end
function Draw.finish() love.graphics.pop() end

-- CLIP (scissor) en ESPACE DESIGN : borne le rendu a un conteneur x,y,w,h (design) -> indispensable pour
-- les LISTES SCROLLABLES (aucun debordement hors du conteneur, meme si le contenu depasse la fenetre).
-- love.graphics.setScissor travaille en PIXELS ECRAN (insensible a la transform) -> on convertit via `view`.
-- A refermer avec Draw.noScissor(). Doit etre appele sous Draw.begin(view) (mais utilise `view` directement).
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
-- c = {r,g,b,a} (table Theme) ; a override l'alpha. nil -> no-op (garde l'état courant).
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

-- Filet horizontal en dégradé (transparent -> couleur -> transparent), comme la DA. cx = centre.
function Draw.divider(cx, y, w, color, alpha)
  local n = 48
  local step = w / n
  local x0 = cx - w / 2
  for i = 0, n - 1 do
    local t = i / (n - 1)
    local a = (1 - math.abs(t * 2 - 1)) * (alpha or 1) -- profil triangulaire (0 aux bords, 1 au centre)
    Draw.setColor(color, a * (color[4] or 1))
    love.graphics.rectangle("fill", x0 + i * step, y, step + 0.6, 1)
  end
end

-- ─────────────────────────────────── Texte ───────────────────────────────────
-- Toutes les variantes : (str, ..., color, font). font nil = police courante. Coordonnées plancher (net).
function Draw.text(str, x, y, color, font)
  if font then love.graphics.setFont(font) end
  Draw.setColor(color)
  love.graphics.print(str, math.floor(x + 0.5), math.floor(y + 0.5))
end

function Draw.textC(str, cx, y, color, font)
  font = font or love.graphics.getFont()
  love.graphics.setFont(font)
  Draw.setColor(color)
  local w = font:getWidth(str)
  love.graphics.print(str, math.floor(cx - w / 2 + 0.5), math.floor(y + 0.5))
end

-- Itère les CARACTÈRES UTF-8 d'une chaîne (longueur déduite de l'octet de tête) : sûr pour « · », « — » et
-- les accents. On ne découpe JAMAIS au milieu d'un caractère multi-octets -> plus d'« UTF-8 decoding error »
-- (le tracking par caractère le faisait). Pur Lua : fonctionne en LÖVE comme en headless (pas besoin du
-- module utf8, absent de LuaJIT).
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

-- Texte centré AVEC interlettrage (letter-spacing, en px design) : effet cérémonial de la DA. UTF-8-safe.
function Draw.textTrackedC(str, cx, y, color, font, spacing)
  font = font or love.graphics.getFont()
  love.graphics.setFont(font)
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
    love.graphics.print(ch, math.floor(x + 0.5), math.floor(y + 0.5))
    x = x + font:getWidth(ch) + spacing
  end
  return total
end

-- Texte ALIGNÉ À GAUCHE avec interlettrage (kickers / petites capitales) : UTF-8-safe. Renvoie la largeur.
function Draw.textTrackedL(str, x, y, color, font, spacing)
  font = font or love.graphics.getFont()
  love.graphics.setFont(font)
  Draw.setColor(color)
  spacing = spacing or 0
  local cx = x
  for ch in utf8chars(str) do
    love.graphics.print(ch, math.floor(cx + 0.5), math.floor(y + 0.5))
    cx = cx + font:getWidth(ch) + spacing
  end
  return cx - x
end

-- Aligné à droite : le texte se termine à rx.
function Draw.textR(str, rx, y, color, font)
  font = font or love.graphics.getFont()
  love.graphics.setFont(font)
  Draw.setColor(color)
  local w = font:getWidth(str)
  love.graphics.print(str, math.floor(rx - w + 0.5), math.floor(y + 0.5))
end

-- Bloc multi-ligne avec retour à la ligne + alignement (lore). Renvoie la hauteur dessinée.
function Draw.textWrap(str, x, y, limit, color, font, align)
  if font then love.graphics.setFont(font) else font = love.graphics.getFont() end
  Draw.setColor(color)
  love.graphics.printf(str, math.floor(x + 0.5), math.floor(y + 0.5), limit, align or "left")
  local _, lines = font:getWrap(str, limit)
  return #lines * font:getHeight()
end

function Draw.textWidth(str, font)
  font = font or love.graphics.getFont()
  return font:getWidth(str)
end

-- ─────────────────────────────────── Widgets ───────────────────────────────────
-- Bouton. Deux modes :
--   * MODERNE (recommandé) : opts.state -> encadré « runique » Frame (biseau bronze + dorures héros +
--     hover/clic/désactivé). Construire l'état via Theme.btnState{ tone, enabled, hover }.
--   * LEGACY : opts = {fill, border, text, bw} -> rect bordé plat (rétrocompat, appels non encore migrés).
-- font = police du label.
function Draw.button(x, y, w, h, label, font, opts)
  opts = opts or {}
  if opts.state then
    return Frame.button(x, y, w, h, label,
      { state = opts.state, level = opts.level, font = font, text = opts.text, accent = opts.accent, px = opts.px })
  end
  Draw.rect(x, y, w, h, opts.fill, opts.border, opts.bw or 2)
  if label then
    font = font or love.graphics.getFont()
    Draw.textC(label, x + w / 2, y + (h - font:getHeight()) / 2, opts.text, font)
  end
end

-- Barre de valeur (PV/bouclier) : fond + remplissage proportionnel. pct dans [0,1].
function Draw.bar(x, y, w, h, pct, fill, bg, border)
  if bg then Draw.rect(x, y, w, h, bg) end
  local fw = math.max(0, math.min(1, pct)) * w
  if fill and fw > 0 then Draw.setColor(fill); love.graphics.rectangle("fill", x, y, fw, h) end
  if border then Draw.rect(x, y, w, h, nil, border, 1) end
end

-- PIP de type procédural (remplace le glyphe Unicode non garanti par les polices). cx,cy = centre.
-- Formes : flesh=barre, order=croix, bone=diamant, arcane=étoile, abyss=disque.
function Draw.pip(typeName, cx, cy, r, colorOverride)
  local t = Theme.type(typeName)
  Draw.setColor(colorOverride or t.color)
  local shape = t.pip
  if shape == "bar" then
    love.graphics.rectangle("fill", cx - r, cy - r * 0.34, r * 2, r * 0.68)
  elseif shape == "cross" then
    local a = r * 0.34
    love.graphics.rectangle("fill", cx - a, cy - r, a * 2, r * 2)
    love.graphics.rectangle("fill", cx - r, cy - a, r * 2, a * 2)
  elseif shape == "diamond" then
    love.graphics.polygon("fill", cx, cy - r, cx + r, cy, cx, cy + r, cx - r, cy)
  elseif shape == "star" then
    love.graphics.setLineWidth(math.max(1, r * 0.34))
    love.graphics.line(cx - r, cy, cx + r, cy)
    love.graphics.line(cx, cy - r, cx, cy + r)
    local d = r * 0.7
    love.graphics.line(cx - d, cy - d, cx + d, cy + d)
    love.graphics.line(cx - d, cy + d, cx + d, cy - d)
    love.graphics.setLineWidth(1)
  else -- disc
    love.graphics.circle("fill", cx, cy, r)
  end
end

return Draw
