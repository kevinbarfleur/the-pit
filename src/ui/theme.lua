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

  -- Afflictions (DoT) — couleurs DISTINCTES (teinte bien séparée) pour la lecture de la barre de vie
  -- segmentée ET les icônes de statut. Chaque DoT « réserve » une portion de la vie courante, colorée
  -- par sa famille (réf hack&slash/ARPG). Le choc amplifie (pas de segment) -> icône seule.
  poison     = H(0x8fbf2e), -- poison : vert toxique/acide (≠ heal, plus saturé)
  bleed      = H(0xd0405a), -- saignement : cramoisi rosé (≠ sang HP, plus vif)
  bleedDeep  = H(0x6a1414), -- sang séché (flaque/fin de goutte du feedback corporel d'affliction)
  burn       = H(0xe0792e), -- brûlure : braise vive (≠ ember, plus lumineux)
  rot        = H(0xa86fc4), -- pourriture : violet nécrotique
  shock      = H(0xf2d24a), -- choc : jaune électrique

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

-- ─────────────── États interactifs (vocabulaire UNIFIÉ hover/clic/désactivé) ───────────────
-- Un SEUL jeu de descripteurs d'état pour toute l'UI (fin des hover gold/eco/blood divergents par scène).
-- Consommé par src/ui/frame.lua : fill = fond intérieur ; text = couleur de label ; accent = studs dorés.
-- glow -> lueur interne au survol ; inset -> biseau inversé + label enfoncé (pressed) ; flat -> sans biseau
-- (disabled) ; gild -> studs dorés forcés même en niveau "bevel" (selected/danger = héros).
local c = Theme.c
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
-- les héros (cta/drop) sont GILDÉS (studs dorés), default/eco restent en biseau bronze (« dorures héros »).
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

-- ───────────────────────────────── Polices ─────────────────────────────────
-- 3 familles. RÈGLE DE LISIBILITÉ (retour user) : le FONCTIONNEL passe en Silkscreen ; le gothique et
-- l'italique sont réservés à de courtes touches.
--   display   = Jacquard 24  -> UNIQUEMENT le logotype "The Pit" + grands mots de résultat (VICTORY...).
--                               Jamais en label fonctionnel ; en casse de TITRE (capitales blackletter = illisibles).
--   ui/uiBold = Silkscreen   -> LABELS/BOUTONS courts en capitales (items de menu, libellés de boutons,
--                               petites étiquettes). Silkscreen est CHUNKY/tout-capitales : superbe en label,
--                               mais TROP lourd et illisible pour des VALEURS et de la PROSE mécanique.
--   read      = Pixel Operator Bold -> POLICE LISIBLE (retour user) : VALEURS (HP/DMG/CD, dps, coût, HUD) +
--                               TEXTE MÉCANIQUE/description. Vraie pixel-font CC0 avec MINUSCULES, x-height
--                               ample ET trait LOURD -> bien plus lisible que Silkscreen en petit, et surtout
--                               ROBUSTE au léger adoucissement non-entier (l'UI dessine en design 1280×720 puis
--                               scale ×(view.scale/4) ; à view.scale=3 le facteur 0.75 floute les traits FINS).
--                               Jersey 15 (essayé puis REJETÉ) « mushait » à 0.75 (traits trop fins) ; un trait
--                               GRAS survit. hinting "mono" + nearest. On voit la valeur, on lit la phrase.
--   loreRoman = IM Fell rom. -> SAVEUR courte (kickers, citations de relique) : serif d'ambiance LISIBLE.
--   lore      = IM Fell ital -> FLAVOR / phrase philosophique (italique d'ambiance, en pied de carte).
Theme.FONT_FILES = {
  display   = "assets/fonts/Jacquard24-Regular.ttf",
  ui        = "assets/fonts/Silkscreen-Regular.ttf",
  uiBold    = "assets/fonts/Silkscreen-Bold.ttf",
  read      = "assets/fonts/PixelOperator-Bold.ttf",
  lore      = "assets/fonts/IMFellEnglish-Italic.ttf",
  loreRoman = "assets/fonts/IMFellEnglish-Regular.ttf",
}
-- "mono" = rendu aliasé (pixel net) pour les polices pixel (UI + read) ; "normal" = lissé pour le gothique/lore.
Theme.HINT = { ui = "mono", uiBold = "mono", read = "mono", display = "normal", lore = "normal", loreRoman = "normal" }

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
function Theme.read(px)      return Theme.font("read", px) end
function Theme.lore(px)      return Theme.font("lore", px) end
function Theme.loreRoman(px) return Theme.font("loreRoman", px) end

-- Pré-chauffe les tailles courantes (évite les à-coups de première frame). Appelé 1× depuis main.love.load.
-- Idempotent et sans danger headless (no-op si love absent).
function Theme.load()
  if not haveGraphics() then return end
  Theme.display(128); Theme.display(54); Theme.display(30); Theme.display(26)
  for _, px in ipairs({ 8, 9, 10, 11, 12, 13, 16 }) do Theme.ui(px) end
  Theme.uiBold(11); Theme.uiBold(13)
  -- POLICE LISIBLE (valeurs + prose mécanique) : tailles courantes de la fiche/du HUD/des cartes. Pixel
  -- Operator a une grille NATIVE 16px -> on privilégie 16 (et proches) pour rester crisp avant le scale jeu.
  for _, px in ipairs({ 12, 13, 14, 15, 16, 18, 20 }) do Theme.read(px) end
  Theme.lore(14); Theme.lore(16); Theme.lore(18); Theme.lore(24)
  Theme.loaded = true
end

return Theme
