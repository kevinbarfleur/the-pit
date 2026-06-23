-- src/ui/theme.lua
-- SOURCE UNIQUE de la direction artistique (DA) "The Pit". Porte le DESIGN SYSTEM du designer
-- (docs/pixel-art/design-system-source.html, "Reliquary · Système Visuel · v1"). Centralise : la
-- PALETTE grimdark tokenisée (hex -> floats 0..1), les COULEURS de type d'unité, et le chargement des
-- POLICES. Aucune scène ne doit coder une couleur ou charger une police en dur.
--
-- REFONTE TYPO (parti pris du designer, « la lisibilité d'abord ») : quatre voix, un rôle chacune.
--   • Jacquard 24 — CÉRÉMONIALE, rarissime : le titre du jeu + les grands mots du destin (Victory…).
--   • Cinzel      — GRAVÉE : titres, noms, grands mots ; capitales, interlettrage large.
--   • Spectral    — MANUSCRITE : la prose lisible (descriptions) + la saveur (italique de lore).
--   • Space Mono  — INSCRITE : TOUTES les valeurs + labels (chiffres tabulaires, sans ambiguïté).
-- Silkscreen (l'ancien « tout-en-pixel ») est l'AVANT qu'on corrige : conservé pour compat, plus utilisé
-- pour le contenu. Les polices vectorielles (Cinzel/Spectral/Space Mono) sont ROBUSTES au scale non-entier
-- (anti-alias gracieux), contrairement aux pixel-fonts -> meilleures à toutes les tailles de fenêtre.
--
-- PUR au require (les tables de couleurs n'ont besoin d'aucun `love`). Les polices sont chargées en LAZY
-- via Theme.font(role, px) (mémoïsé) -> headless/SIM jamais impactés. Fallback gracieux vers la police par
-- défaut si un TTF manque (le jeu ne crashe jamais pour un asset absent).

local Theme = {}

-- hex 0xRRGGBB -> {r,g,b,a} floats (arithmétique pure, portable Lua 5.1 / LuaJIT, comme palette.lua).
function Theme.hex(h, a)
  local r = math.floor(h / 0x10000) % 0x100
  local g = math.floor(h / 0x100) % 0x100
  local b = h % 0x100
  return { r / 255, g / 255, b / 255, a or 1 }
end
local H = Theme.hex

-- ───────────────────────── Palette (tokens canoniques du design system) ─────────────────────────
-- Noms repris à l'identique du .dc.html (--void, --stone-900…, --ink…, --brass…, afflictions). Les
-- valeurs sont la source de vérité ; les rôles historiques (panel/title/body/…) sont définis plus bas
-- comme ALIAS sur ces tokens (toute scène existante continue de fonctionner, sur la palette raffinée).
Theme.c = {
  -- ▚ Fonds — la pierre du puits (du plus profond au panneau)
  void     = H(0x050308), -- noir du puits (letterbox / base la plus sombre)
  stone900 = H(0x0b0910),
  stone850 = H(0x100d16),
  stone800 = H(0x16121d),
  stone700 = H(0x1d1826),
  stone600 = H(0x272031),

  -- ▚ Encres — os & parchemin (contraste relevé pour la lecture)
  ink      = H(0xece3ce), -- primaire (titres gravés, éclat)
  ink2     = H(0xc3b89e), -- corps
  ink3     = H(0x8d8270), -- sourdine
  ink4     = H(0x5d544a), -- légende
  ink5     = H(0x3a342f), -- désactivé

  -- ▚ Laiton — le cadre, terni (jamais doré-brillant)
  iron     = H(0x070506), -- contour noir net
  brassD   = H(0x2a2012),
  brass    = H(0x5f4a22),
  brassL   = H(0x90712f), -- éclairé
  brassS   = H(0xd8b65e), -- reflet rare (spéculaire)

  -- ▚ Accents — le sang, la braise, l'or sacré
  blood    = H(0xb5302a), -- action
  bloodL   = H(0xd8463b), -- survol / PV
  bloodD   = H(0x48120e), -- fond CTA
  ember    = H(0xc4663a), -- lueur / braise
  gold     = H(0xcda14c), -- valeur / sacré

  -- ▚ Afflictions — familles d'altération (teintes bien séparées + forme propre = lisible daltonien)
  burn     = H(0xe0792e), -- brûlure
  bleed    = H(0xd8475e), -- saignement
  poison   = H(0x93c12f), -- poison
  rot      = H(0xa86fc4), -- pourriture
  shock    = H(0xf2d24a), -- choc
  regen    = H(0x7fbf6a), -- soin
  shield   = H(0x6fa8e6), -- bouclier

  -- ▚ Ambiances chaudes conservées (la « bouche » du puits : braise au fond des scènes d'ambiance)
  bgWarm    = H(0x150a0e), -- fond réchauffé (mi-hauteur)
  bgEmber   = H(0x2c0e10), -- bas des scènes (proche de la braise)
  bloodEdge = H(0x241416), -- bord du CTA désactivé
  bleedDeep = H(0x6a1414), -- sang séché (flaque/fin de goutte d'affliction)
  ctaText   = H(0xf0d9a8), -- texte chaud sur bouton sang
  drop      = H(0x6bc766), -- cible de drop valide
  slotEdge  = H(0x524759), -- bord de case par défaut
  ecoBg     = H(0x1c130b), -- fond bouton REROLL/LEVEL
  ecoBgHot  = H(0x2a1c0e), -- survol éco
}

-- ── Alias de rôles (COMPAT) : les noms historiques pointent sur les tokens canoniques ci-dessus.
-- Toute scène encore non re-skinnée garde ses appels (Theme.c.panel, .title, .body…) et hérite de la
-- palette raffinée. La migration des call-sites vers les tokens canoniques se fera scène par scène.
local c = Theme.c
c.bgDeep = c.stone900; c.bgPit = c.stone850
c.panel = c.stone800; c.panelDeep = c.stone900; c.slot = c.stone800; c.slotLocked = c.stone900
c.inkBright = c.ink; c.title = c.ink; c.body = c.ink2; c.name = c.ink2
c.muted = c.ink3; c.dim = c.ink3; c.faint = c.ink4; c.fainter = c.ink4; c.ghost = c.ink5; c.lock = c.stone600
c.bloodBright = c.bloodL; c.bloodDeep = c.bloodD; c.dmg = c.bloodL
c.goldBright = c.brassS; c.heal = c.regen
c.slotEdgeLck = c.stone700; c.edgeIdle = c.stone600; c.edgeActive = c.blood
c.hair = c.brassD; c.line = c.stone700
c.ecoBorder = c.brass; c.cardHover = c.stone700

-- ─────────────────── Couleurs de type d'unité (TYPES du design system) ───────────────────
-- glyph = forme conceptuelle (dessinée en PIP procédural par ui/draw.lua, pas en glyphe Unicode :
-- les polices ne garantissent pas ▬✚◇✷●). label = clé i18n de type (type.flesh, ...).
-- « Forme + couleur, toujours doublées » : on reconnaît un type sans lire, et même sans distinguer la teinte.
Theme.types = {
  flesh  = { color = H(0xb3493a), dark = H(0x3a120e), pip = "bar" },     -- chair
  order  = { color = H(0xc4a04a), dark = H(0x4a3814), pip = "cross" },   -- ordre
  bone   = { color = H(0xb3a07e), dark = H(0x473a2c), pip = "diamond" }, -- os
  arcane = { color = H(0xa05a8c), dark = H(0x33182c), pip = "star" },    -- arcane
  abyss  = { color = H(0x8a4a64), dark = H(0x2a1220), pip = "disc" },    -- abysse
}
function Theme.type(name) return Theme.types[name] or Theme.types.bone end

-- ─────────────── États interactifs (vocabulaire UNIFIÉ hover/clic/désactivé) ───────────────
-- Un SEUL jeu de descripteurs d'état pour toute l'UI. Consommé par src/ui/frame.lua : fill = fond
-- intérieur ; text = couleur de label ; accent = liseré de laiton. glow -> lueur interne au survol ;
-- inset -> biseau inversé + label enfoncé (pressed) ; flat -> sans biseau (disabled) ; gild -> liseré
-- d'accent forcé (selected/danger = héros).
Theme.state = {
  idle     = { fill = c.panelDeep, text = c.body,      accent = c.gold },
  hover    = { fill = c.panel,     text = c.inkBright,  accent = c.goldBright, glow = 0.5 },
  pressed  = { fill = c.panelDeep, text = c.ctaText,    accent = c.goldBright, inset = true },
  disabled = { fill = c.panelDeep, text = c.ghost,      accent = c.line,       flat = true },
  selected = { fill = c.panel,     text = c.inkBright,  accent = c.goldBright, gild = true },
  danger   = { fill = c.bloodDeep, text = c.ctaText,    accent = c.gold,       gild = true },
  drop     = { fill = c.panel,     text = c.drop,       accent = c.drop,       gild = true },
}
function Theme.stateOf(name) return Theme.state[name] or Theme.state.idle end

-- TONS de bouton (variante sémantique) × interaction. Un bouton = un TON (default/eco/cta/drop) + des
-- drapeaux (enabled/hover/pressed). Theme.btnState combine les deux en un descripteur d'état pour Frame :
-- les héros (cta/drop) sont gildés (liseré doré), default/eco restent en biseau bronze (« dorures héros »).
Theme.tones = {
  default = { fill = c.panelDeep, fillHot = c.panel,    text = c.body,    textHot = c.inkBright, accent = c.gold,      gild = false },
  eco     = { fill = c.ecoBg,     fillHot = c.ecoBgHot,  text = c.title,   textHot = c.inkBright, accent = c.ecoBorder, gild = false },
  cta     = { fill = c.bloodDeep, fillHot = c.blood,     text = c.ctaText, textHot = c.ctaText,   accent = c.gold,      gild = true  },
  drop    = { fill = c.panel,     fillHot = c.panel,     text = c.drop,    textHot = c.drop,      accent = c.drop,      gild = true  },
}
-- o = { tone?, enabled?, hover?, pressed? }. enabled==false -> état désactivé (à plat). Sinon ton + hover
-- (lueur interne + fond/texte chauds) + pressed (biseau enfoncé). Retourne un descripteur d'état (table).
function Theme.btnState(o)
  o = o or {}
  if o.enabled == false then
    return { fill = c.panelDeep, text = c.ghost, accent = c.line, flat = true }
  end
  local tone = Theme.tones[o.tone or "default"] or Theme.tones.default
  local hot = o.hover and true or false
  return {
    fill   = hot and tone.fillHot or tone.fill,
    text   = hot and tone.textHot or tone.text,
    accent = tone.accent,
    gild   = tone.gild,
    glow   = hot and 0.5 or nil,
    inset  = o.pressed and true or nil,
  }
end

-- ───────────────────────────────── Polices (les quatre voix) ─────────────────────────────────
-- Échelle & rôles (Section II du design system). Tailles indicatives en design 1280×720.
--   display    Jacquard 24      cérémonial rarissime : logotype "The Pit" + grands mots (Victory/Defeat)
--   displayBig Cinzel 900       bandeaux/display gravés (48–88) quand on ne veut pas le blackletter
--   title      Cinzel 800       titres d'écran (22–30) — CAPITALES, interlettrage large
--   heading    Cinzel 700       grands mots / en-têtes de section (18–22)
--   subhead    Cinzel 600       noms d'unité, titres de carte (15–18)
--   body       Spectral 400     corps de texte / descriptions (13–15) — prose LISIBLE
--   bodyMed    Spectral 500     emphase dans la prose
--   bodyLight  Spectral 300
--   flavor     Spectral 300 it. saveur / lore (italique, pied de carte, 12–14)
--   bodyItalic Spectral 400 it. citation courante
--   label      Space Mono 700   boutons, chips, kickers, ET toutes les VALEURS (HP/DMG/CD, or, %) — 10–16
--   labelSmall Space Mono 400   micro-légendes, hex de swatch
--   ui/uiBold/read/lore/loreRoman = LEGACY (compat scènes pas encore re-skinnées ; plus pour le contenu).
Theme.FONT_FILES = {
  -- voix cérémoniale
  display    = "assets/fonts/Jacquard24-Regular.ttf",
  -- voix gravée (Cinzel)
  displayBig = "assets/fonts/Cinzel-900.ttf",
  title      = "assets/fonts/Cinzel-800.ttf",
  heading    = "assets/fonts/Cinzel-700.ttf",
  subhead    = "assets/fonts/Cinzel-600.ttf",
  -- voix manuscrite (Spectral)
  body       = "assets/fonts/Spectral-400.ttf",
  bodyMed    = "assets/fonts/Spectral-500.ttf",
  bodyLight  = "assets/fonts/Spectral-300.ttf",
  flavor     = "assets/fonts/Spectral-300italic.ttf",
  bodyItalic = "assets/fonts/Spectral-400italic.ttf",
  -- voix inscrite (Space Mono)
  label      = "assets/fonts/SpaceMono-700.ttf",
  labelSmall = "assets/fonts/SpaceMono-400.ttf",
  -- legacy (compat)
  ui         = "assets/fonts/Silkscreen-Regular.ttf",
  uiBold     = "assets/fonts/Silkscreen-Bold.ttf",
  read       = "assets/fonts/PixelOperator-Bold.ttf",
  lore       = "assets/fonts/IMFellEnglish-Italic.ttf",
  loreRoman  = "assets/fonts/IMFellEnglish-Regular.ttf",
}
-- "mono" = rendu aliasé (pixel net) pour les pixel-fonts LEGACY ; "normal" = lissé pour les vectorielles
-- (Cinzel/Spectral/Space Mono) ET le gothique/lore. Les vectorielles ne doivent JAMAIS être en nearest.
Theme.HINT = {
  display = "normal", displayBig = "normal", title = "normal", heading = "normal", subhead = "normal",
  body = "normal", bodyMed = "normal", bodyLight = "normal", flavor = "normal", bodyItalic = "normal",
  label = "normal", labelSmall = "normal",
  ui = "mono", uiBold = "mono", read = "mono", lore = "normal", loreRoman = "normal",
}

Theme._cache = {}    -- [role][px] = Font
Theme._missing = {}  -- [role] = true si le TTF a échoué (on ne réessaie pas)

local function haveGraphics()
  return love and love.graphics and love.graphics.newFont
end

-- Police mémoïsée par (role, px). newFont est LENT -> jamais en boucle de frame (toujours via ce cache).
-- Fallback : TTF absent -> police par défaut de même taille ; pas de love -> nil (le rendu se garde).
function Theme.font(role, px)
  role = role or "label"
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
function Theme.display(px)    return Theme.font("display", px) end
function Theme.displayBig(px) return Theme.font("displayBig", px) end
function Theme.title(px)      return Theme.font("title", px) end
function Theme.heading(px)    return Theme.font("heading", px) end
function Theme.subhead(px)    return Theme.font("subhead", px) end
function Theme.body(px)       return Theme.font("body", px) end
function Theme.bodyMed(px)    return Theme.font("bodyMed", px) end
function Theme.bodyLight(px)  return Theme.font("bodyLight", px) end
function Theme.flavor(px)     return Theme.font("flavor", px) end
function Theme.bodyItalic(px) return Theme.font("bodyItalic", px) end
function Theme.label(px)      return Theme.font("label", px) end
function Theme.labelSmall(px) return Theme.font("labelSmall", px) end
function Theme.value(px)      return Theme.font("label", px) end -- alias sémantique (valeurs = Space Mono 700)
-- legacy
function Theme.ui(px)        return Theme.font("ui", px) end
function Theme.uiBold(px)    return Theme.font("uiBold", px) end
function Theme.read(px)      return Theme.font("read", px) end
function Theme.lore(px)      return Theme.font("lore", px) end
function Theme.loreRoman(px) return Theme.font("loreRoman", px) end

-- Pré-chauffe les tailles courantes (évite les à-coups de première frame). Appelé 1× depuis main.love.load.
-- Idempotent et sans danger headless (no-op si love absent).
function Theme.load()
  if not haveGraphics() then return end
  -- cérémonial (Jacquard)
  Theme.display(104); Theme.display(66); Theme.display(30)
  -- gravée (Cinzel)
  Theme.displayBig(48); Theme.title(30); Theme.title(22); Theme.heading(18); Theme.heading(16)
  Theme.subhead(16); Theme.subhead(14)
  -- manuscrite (Spectral)
  for _, px in ipairs({ 13, 14, 15, 16, 17 }) do Theme.body(px) end
  Theme.bodyMed(14); Theme.flavor(12); Theme.flavor(13); Theme.flavor(14); Theme.flavor(16)
  -- inscrite (Space Mono)
  for _, px in ipairs({ 10, 11, 12, 13, 15, 16, 18 }) do Theme.label(px) end
  Theme.labelSmall(10); Theme.labelSmall(11)
  -- legacy (compat scènes non encore re-skinnées)
  for _, px in ipairs({ 8, 9, 10, 11, 12, 13, 16 }) do Theme.ui(px) end
  Theme.uiBold(11); Theme.uiBold(13)
  for _, px in ipairs({ 12, 13, 14, 15, 16, 18, 20 }) do Theme.read(px) end
  Theme.lore(14); Theme.lore(16); Theme.lore(18)
  Theme.loaded = true
end

return Theme
