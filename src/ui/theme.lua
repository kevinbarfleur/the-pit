-- src/ui/theme.lua
-- SOURCE UNIQUE de la direction artistique (DA) "The Pit", portée du prototype DesignComposer
-- (docs design "The Pit.dc.html"). Centralise : la PALETTE grimdark (hex -> floats 0..1), les
-- COULEURS de type d'unité, et le chargement des 3 POLICES (Jacquard 24 gothique / Silkscreen pixel
-- / IM Fell English lore). Aucune scène ne doit coder une couleur ou charger une police en dur.
--
-- PUR au require (les tables de couleurs n'ont besoin d'aucun `love`). Les polices sont chargées en
-- LAZY via Theme.font(role, px) (mémoïsé) -> headless/SIM jamais impactés (rien de tout ça n'est
-- requis par la couche SIM ni par les tests). Fallback gracieux vers la police par défaut si un TTF
-- manque (le jeu ne crashe jamais pour un asset absent).

local Theme = {}

-- hex 0xRRGGBB -> {r,g,b,a} floats (arithmétique pure, portable Lua 5.1 / LuaJIT, comme palette.lua).
function Theme.hex(h, a)
  local r = math.floor(h / 0x10000) % 0x100
  local g = math.floor(h / 0x100) % 0x100
  local b = h % 0x100
  return { r / 255, g / 255, b / 255, a or 1 }
end
local H = Theme.hex

-- ─────────────────────────────── Palette (repris du .dc.html) ───────────────────────────────
Theme.c = {
  -- Fonds (du plus profond au panneau)
  void       = H(0x050307), -- noir du puits (letterbox / base la plus sombre)
  bgDeep     = H(0x08050b),
  bgPit      = H(0x0a0610),
  bgWarm     = H(0x150a0e), -- fond réchauffé (mi-hauteur des scènes d'ambiance)
  bgEmber    = H(0x2c0e10), -- bas des scènes (proche de la braise)
  panel      = H(0x0e080f), -- panneaux UI (boutique, etc.)
  panelDeep  = H(0x0b060a),
  slot       = H(0x100a13), -- intérieur d'une case jouable
  slotLocked = H(0x0a070d), -- case verrouillée

  -- Encres (parchemin/os : du plus clair au plus éteint)
  inkBright  = H(0xf0e2c4), -- sélection / éclat
  ctaText    = H(0xf0d9a8), -- texte sur bouton sang
  title      = H(0xc7b899), -- titres parchemin (rôle principal)
  body       = H(0xc2b39a), -- corps de texte lisible
  name       = H(0xcdbca0), -- noms d'unités
  muted      = H(0x9a8a72), -- secondaire
  dim        = H(0x8a7766), -- lore / tertiaire
  faint      = H(0x7a685c), -- légendes
  fainter    = H(0x5b4d44), -- micro-légendes
  ghost      = H(0x3f352f), -- quasi invisible (tags, build no.)
  lock       = H(0x2a232c), -- glyphe de case verrouillée

  -- Sang (accent primaire) & or (accent secondaire)
  blood      = H(0xa12924),
  bloodBright= H(0xb33833),
  bloodDeep  = H(0x5a1714), -- fond du CTA
  bloodEdge  = H(0x241416), -- bord du CTA désactivé
  dmg        = H(0xe0584c), -- nombres de dégâts
  gold       = H(0xc4a04a),
  goldBright = H(0xd9bd52), -- survol / passifs

  -- Statuts & feedback
  heal       = H(0x8fd06a), -- soin / regen
  shield     = H(0x73b3f2), -- bouclier
  drop       = H(0x6bc766), -- cible de drop valide
  ember      = H(0xc4663a), -- braises

  -- Plateau (cases & arêtes)
  slotEdge   = H(0x524759), -- bord de case par défaut
  slotEdgeLck= H(0x221c28), -- bord de case verrouillée
  edgeIdle   = H(0x322a38), -- arête de synergie au repos
  edgeActive = H(0xa12924), -- arête active (survol/voisin)

  -- Lignes & séparateurs
  hair       = H(0x2a2018), -- bordure de panneau détaillé
  line       = H(0x1c1620), -- séparateur sombre

  -- Boutons d'économie (boutique) & survol de carte
  ecoBg      = H(0x1c130b), -- fond bouton REROLL/LEVEL
  ecoBgHot   = H(0x2a1c0e), -- survol
  ecoBorder  = H(0x6a4a22), -- bord (actif)
  cardHover  = H(0x1a1118), -- survol d'une offre achetable
}

-- ─────────────────── Couleurs de type d'unité (TYPES du .dc.html) ───────────────────
-- glyph = forme conceptuelle (dessinée en PIP procédural par ui/draw.lua, pas en glyphe Unicode :
-- les polices ne garantissent pas ▬✚◇✷●). label = clé i18n de type (type.flesh, ...).
Theme.types = {
  flesh  = { color = H(0xb3493a), dark = H(0x3a120e), pip = "bar" },
  order  = { color = H(0xc4a04a), dark = H(0x4a3814), pip = "cross" },
  bone   = { color = H(0xb3a07e), dark = H(0x473a2c), pip = "diamond" },
  arcane = { color = H(0xa05a8c), dark = H(0x33182c), pip = "star" },
  abyss  = { color = H(0x8a4a64), dark = H(0x2a1220), pip = "disc" },
}
function Theme.type(name) return Theme.types[name] or Theme.types.bone end

-- ───────────────────────────────── Polices ─────────────────────────────────
-- 3 familles, 3 rôles (cf. DA) :
--   display   = Jacquard 24  -> titres gothiques (The Pit, VICTORY, sigils, noms de relique)
--   ui/uiBold = Silkscreen   -> UI pixel (stats, boutons, labels) ; hinting "mono" + nearest = net
--   lore      = IM Fell it.  -> texte d'ambiance italique (flavor, lore) ; loreRoman = variante droite
Theme.FONT_FILES = {
  display   = "assets/fonts/Jacquard24-Regular.ttf",
  ui        = "assets/fonts/Silkscreen-Regular.ttf",
  uiBold    = "assets/fonts/Silkscreen-Bold.ttf",
  lore      = "assets/fonts/IMFellEnglish-Italic.ttf",
  loreRoman = "assets/fonts/IMFellEnglish-Regular.ttf",
}
-- "mono" = rendu aliasé (pixel net) pour la police UI ; "normal" = lissé pour le gothique/lore décoratif.
Theme.HINT = { ui = "mono", uiBold = "mono", display = "normal", lore = "normal", loreRoman = "normal" }

Theme._cache = {}    -- [role][px] = Font
Theme._missing = {}  -- [role] = true si le TTF a échoué (on ne réessaie pas)

local function haveGraphics()
  return love and love.graphics and love.graphics.newFont
end

-- Police mémoïsée par (role, px). newFont est LENT -> jamais en boucle de frame (toujours via ce cache).
-- Fallback : TTF absent -> police par défaut de même taille ; pas de love -> nil (le rendu se garde).
function Theme.font(role, px)
  role = role or "ui"
  px = math.floor((px or 12) + 0.5)
  local byRole = Theme._cache[role]
  if not byRole then byRole = {}; Theme._cache[role] = byRole end
  local f = byRole[px]
  if f ~= nil then return f or nil end
  if not haveGraphics() then return nil end

  local font
  local path = Theme.FONT_FILES[role]
  if path and not Theme._missing[role] then
    local ok, res = pcall(love.graphics.newFont, path, px, Theme.HINT[role] or "normal")
    if ok and res then font = res else Theme._missing[role] = true end
  end
  if not font then -- repli : police par défaut LÖVE à la même taille
    local ok, res = pcall(love.graphics.newFont, px)
    if ok and res then font = res end
  end
  if font and Theme.HINT[role] == "mono" and font.setFilter then
    pcall(font.setFilter, font, "nearest", "nearest")
  end
  byRole[px] = font or false
  return font
end

-- Raccourcis lisibles par rôle.
function Theme.display(px)   return Theme.font("display", px) end
function Theme.ui(px)        return Theme.font("ui", px) end
function Theme.uiBold(px)    return Theme.font("uiBold", px) end
function Theme.lore(px)      return Theme.font("lore", px) end
function Theme.loreRoman(px) return Theme.font("loreRoman", px) end

-- Pré-chauffe les tailles courantes (évite les à-coups de première frame). Appelé 1× depuis main.love.load.
-- Idempotent et sans danger headless (no-op si love absent).
function Theme.load()
  if not haveGraphics() then return end
  Theme.display(128); Theme.display(54); Theme.display(30); Theme.display(26)
  for _, px in ipairs({ 8, 9, 10, 11, 12, 13, 16 }) do Theme.ui(px) end
  Theme.uiBold(11); Theme.uiBold(13)
  Theme.lore(14); Theme.lore(16); Theme.lore(18); Theme.lore(24)
  Theme.loaded = true
end

return Theme
