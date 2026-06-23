-- src/scenes/designsystem.lua
-- L'ÉCRAN « DESIGN SYSTEM » — le RELIQUAIRE, Storybook IN-ENGINE. Source de vérité VISUELLE de l'UI :
-- chaque composant (token -> atome -> molécule -> organisme, méthodo Brad Frost) y est rendu DANS TOUS SES
-- ÉTATS, en isolation, pour qu'on JUGE la cohérence d'ensemble et qu'on ITÈRE ici (et seulement ici) avant
-- de re-câbler le jeu. Reproduit fidèlement le design system du designer (docs/pixel-art/design-system-source.html,
-- « Reliquary · Système Visuel · v1 ») : Hero + manifeste + Sections numérotées (I Couleur, II Typographie,
-- III Iconographie, IV Composants…). Les quatre voix (Jacquard cérémonial / Cinzel gravée / Spectral
-- manuscrite / Space Mono inscrite) et la palette tokenisée viennent de src/ui/theme.lua.
--
-- MISE EN PAGE : SIDEBAR ancrée à gauche (clic = saut vers la section) + PAGE SCROLLABLE à droite, empilée.
-- ARCHI : catalogue = DATA. `self.sections = { {numeral, kicker, title, intro, entries={ {id,label,h,draw} }} }`.
-- `:layout()` aplatit en `self.items` (header de section / entrée) avec une ancre Y cumulée. Couche RENDER
-- pure (love.graphics) — hors firewall SIM, golden neutre. Idiomes : liste scrollable (Draw.scissor + molette
-- + thumb, calque grimoire) et widgets bakés (Forge). daChrome=true ; [esc] -> host.goto("menu"). Headless-safe.

local Theme = require("src.ui.theme")
local Draw = require("src.ui.draw")
local Frame = require("src.ui.frame")
local Chip = require("src.ui.chip")
local Keywords = require("src.ui.keywords")
local Forge = require("src.ui.forge")
local Ambient = require("src.fx.ambient")
local MiniRig = require("src.render.minirig")
local Reliquary = require("src.ui.reliquary")
local Units = require("src.data.units")
local T = require("src.core.i18n").t
local C = Theme.c

local Screen = {}
Screen.__index = Screen

-- ── Mise en page (ESPACE DESIGN 1280×720, CEINTE par la bande gravée du reliquaire) ─────────────────
-- Tout le contenu vit À L'INTÉRIEUR du cadre de pierre (Reliquary). IX/IY = coin intérieur (band ~32px
-- + un peu d'air) ; les ancres en dérivent. Hit-test headless préservé : SB_X+10=58, w=168 -> 58..226 ⊃ 70.
local FRAME_FT = 8                       -- épaisseur de la bande (px d'art) -> 32px design + air
local IX, IY = 40, 40                    -- coin intérieur du reliquaire
local IW, IH = 1280 - 2 * IX, 720 - 2 * IY -- = 1200 × 640
local TITLE_Y = IY + 10                   -- = 50
local TOP, BOTTOM = IY + 44, IY + IH - 8  -- = 84 .. 672
local SB_X, SB_W = IX + 8, 188            -- = 48
local PAGE_X = SB_X + SB_W + 16           -- = 252
local PAGE_W = (IX + IW) - PAGE_X - 8     -- = 980
local PAGE_PAD = 18
local CONTENT_X = PAGE_X + PAGE_PAD       -- = 270
local CONTENT_W = PAGE_W - 2 * PAGE_PAD   -- = 944
local HEADER_H = 80                       -- bloc « en-tête de section » (numéro + kicker + titre + intro)
local LABEL_H = 26                        -- libellé d'une entrée
local ENTRY_GAP = 30                      -- marge sous une entrée (espacement 8pt : plus d'air entre groupes)
local function pageViewH() return BOTTOM - TOP end

-- swatch de couleur (token) : carte bande-couleur + nom + hex. Grille à `perRow` colonnes dans CONTENT_W.
local SWATCH_W, SWATCH_BAND, SWATCH_CARD_H, SW_GAP = 152, 28, 54, 10
local GROUP_LABEL_H, GROUP_GAP = 24, 16
local function swatchPerRow() return math.max(1, math.floor((CONTENT_W + SW_GAP) / (SWATCH_W + SW_GAP))) end

local function ptIn(px, py, x, y, w, h) return px >= x and px <= x + w and py >= y and py <= y + h end

-- float {r,g,b} -> "#rrggbb" (recompose le hex du token pour l'afficher tel qu'il est défini dans theme.lua).
local function hexOf(col)
  local r = math.floor((col[1] or 0) * 255 + 0.5)
  local g = math.floor((col[2] or 0) * 255 + 0.5)
  local b = math.floor((col[3] or 0) * 255 + 0.5)
  return string.format("#%02x%02x%02x", r, g, b)
end

-- Texte tracké ALIGNÉ À GAUCHE (kickers/petites capitales) -> délègue au helper UTF-8-safe de Draw
-- (l'ancienne version locale découpait en octets et crashait sur « · »/« — »/accents en vrai LÖVE).
local function trackL(str, x, y, color, font, sp)
  return Draw.textTrackedL(str, x, y, color, font, sp or 2)
end

-- Petit « tick » de laiton + libellé de groupe tracké (le « ▚ Fonds » du design, sans dépendre d'un glyphe).
local function groupLabel(str, x, y)
  Draw.rect(x, y + 1, 10, 9, C.brass)
  Draw.rect(x + 1, y + 2, 8, 1, C.brassS)
  trackL(str:upper(), x + 18, y, C.ink2, Theme.label(11), 2)
end

-- Carte de fond (pierre + liseré fer + éclat de laiton sur le bord supérieur si `lit`).
local function card(x, y, w, h, lit)
  Draw.rect(x, y, w, h, C.stone850, C.iron, 1)
  if lit then
    Draw.setColor(C.brassS, 0.07)
    love.graphics.rectangle("fill", math.floor(x + 1), math.floor(y + 1), math.floor(w - 2), 1)
    Draw.reset()
  end
end

-- ── COULEUR : groupes de tokens (clés réelles de Theme.c, palette du designer) ──
local COLOR_GROUPS = {
  { name = "Fonds — la pierre du puits", keys = {
    { "void", "base" }, { "stone900" }, { "stone850" }, { "stone800" }, { "stone700" }, { "stone600" } } },
  { name = "Encres — os & parchemin", keys = {
    { "ink", "primaire" }, { "ink2", "corps" }, { "ink3", "sourdine" }, { "ink4", "légende" }, { "ink5", "désactivé" } } },
  { name = "Laiton — le cadre, terni", keys = {
    { "iron", "contour" }, { "brassD" }, { "brass" }, { "brassL", "éclairé" }, { "brassS", "reflet" } } },
  { name = "Accents — sang, braise, or", keys = {
    { "blood", "action" }, { "bloodL", "survol/PV" }, { "bloodD", "fond CTA" }, { "ember", "lueur" }, { "gold", "valeur" } } },
  { name = "Afflictions — familles d'altération", keys = {
    { "burn" }, { "bleed" }, { "poison" }, { "rot" }, { "shock" }, { "regen", "soin" }, { "shield" } } },
}

-- ── TYPOGRAPHIE : les quatre voix (kicker, fonte, échantillon, rôle) ──
local STATE_NAMES = { "idle", "hover", "pressed", "disabled", "selected", "danger", "drop" }
local AFFL_KEYS = { "poison", "bleed", "burn", "rot", "shock" }
local ICONO_AFFL = { "burn", "bleed", "poison", "rot", "shock", "regen", "shield" }
local TYPE_NAMES = { "flesh", "order", "bone", "arcane", "abyss" }

-- Échelle & rôles (Section II du design). Chaque ligne : rôle, fonte+taille, échantillon, note d'usage.
local TYPE_SCALE = {
  { tag = "DISPLAY · 48–88", fn = Theme.displayBig, px = 30, s = "VICTORY",                                  note = "Cinzel 900 · bandeaux, logo" },
  { tag = "TITLE · 22–30",   fn = Theme.title,      px = 24, s = "THE GRIMOIRE",                             note = "Cinzel 800 · titres d'écran" },
  { tag = "HEADING · 15–18", fn = Theme.heading,    px = 17, s = "GRAVEWARDEN",                              note = "Cinzel 700 · grands mots" },
  { tag = "SUBHEAD · 15–18", fn = Theme.subhead,    px = 16, s = "Ash-Maw",                                 note = "Cinzel 600 · noms, cartes" },
  { tag = "BODY · 13–15",    fn = Theme.body,       px = 15, s = "Returns 4 damage to each attacker.",      note = "Spectral 400 · prose" },
  { tag = "FLAVOR · 12–14",  fn = Theme.flavor,     px = 15, s = "Worn by saints who wished suffering shared.", note = "Spectral italic · lore" },
  { tag = "LABEL · 10–12",   fn = Theme.label,      px = 13, s = "ENTER THE PIT",                           note = "Space Mono 700 · boutons, chips" },
  { tag = "VALUE · 11–16",   fn = Theme.value,      px = 15, s = "HP 70  DMG 6  CD 6.0s",                   note = "Space Mono · chiffres tabulaires" },
}

function Screen.new(palette, vw, vh, host)
  local self = setmetatable({
    palette = palette, vw = vw, vh = vh, host = host, t = 0,
    daChrome = true, titleKey = "designsystem.title", hintKey = "ui.empty",
    scroll = 0, mx = -1, my = -1, hoverNav = nil,
    ambient = Ambient.new(9),
    navRects = {},
  }, Screen)
  self.rigIds = {}
  for _, i in ipairs({ 1, 6, 12, 20 }) do
    if Units.order[i] then self.rigIds[#self.rigIds + 1] = Units.order[i] end
  end
  self:buildSections()
  self:layout()
  return self
end

-- ── Construction du CATALOGUE (sections numérotées, façon « Reliquaire ») ───────────────────────────
function Screen:buildSections()
  self.sections = {
    { id = "reliquary", hero = true, navLabel = "RELIQUARY", entries = {
      { id = "hero", h = 392, draw = Screen.drawHero },
    } },
    { id = "couleur", numeral = "I", kicker = "Foundations · Atomes", title = "Couleur",
      intro = "Désaturée, oppressante. Un seul accent chaud : le sang. L'information n'est jamais portée par la couleur seule.",
      navLabel = "I · COULEUR", entries = {
        { id = "colors", label = "Palette (Theme.c)", h = self:colorsHeight(), draw = Screen.drawColors },
      } },
    { id = "typo", numeral = "II", kicker = "Foundations · le cœur de la refonte", title = "Typographie",
      intro = "Trois voix fonctionnelles + une cérémoniale, très rare. Un rôle chacune — on ne mélange jamais les emplois.",
      navLabel = "II · TYPOGRAPHIE", entries = {
        { id = "voices", label = "Les quatre voix", h = 348, draw = Screen.drawVoices },
        { id = "scale", label = "Échelle & rôles", h = #TYPE_SCALE * 34 + 6, draw = Screen.drawScale },
      } },
    { id = "icono", numeral = "III", kicker = "Foundations · Atomes", title = "Iconographie",
      intro = "Forme + couleur, toujours doublées. On reconnaît un type ou une affliction sans lire, et même sans distinguer la teinte.",
      navLabel = "III · ICONOGRAPHIE", entries = {
        { id = "typepips", label = "Types d'unité (une forme par faction)", h = 96, draw = Screen.drawTypePips },
        { id = "afflicons", label = "Afflictions (une forme par famille)", h = 104, draw = Screen.drawAffl },
      } },
    { id = "composants", numeral = "IV", kicker = "Molécules · re-skin en cours", title = "Composants",
      intro = "Le kit métal porté depuis la référence du designer : pierre gravée, biseau de laiton, runes qui s'éveillent.",
      navLabel = "IV · COMPOSANTS", entries = {
        { id = "buttons", label = "Boutons (Forge.uiButton)", h = 232, draw = Screen.drawButtons },
        { id = "states", label = "États interactifs (Frame)", h = 64, draw = Screen.drawStates },
        { id = "frames", label = "Cadres (Frame.draw)", h = 150, draw = Screen.drawFrames },
        { id = "chips", label = "Chips (Chip.draw)", h = 64, draw = Screen.drawChips },
        { id = "status", label = "Statut + chips (Keywords)", h = 78, draw = Screen.drawStatus },
        { id = "marks", label = "Pips · diamants · pièces", h = 70, draw = Screen.drawMarks },
        { id = "plates", label = "Plaques & sockets (Forge)", h = 110, draw = Screen.drawPlates },
        { id = "values", label = "Value-tags · barres · dividers", h = 96, draw = Screen.drawValues },
        { id = "rigs", label = "Mini-rigs (MiniRig.draw)", h = 84, draw = Screen.drawRigs },
      } },
  }
end

-- Hauteur du nuancier (mêmes maths que drawColors -> layout & rendu cohérents).
function Screen:colorsHeight()
  local perRow = swatchPerRow()
  local h = 0
  for gi, grp in ipairs(COLOR_GROUPS) do
    local rows = math.ceil(#grp.keys / perRow)
    h = h + GROUP_LABEL_H + rows * (SWATCH_CARD_H + SW_GAP)
    if gi < #COLOR_GROUPS then h = h + GROUP_GAP end
  end
  return h
end

-- Aplatit sections -> self.items {kind, sec?/entry?, y (ancre dans le contenu), h} + self.nav (sidebar).
function Screen:layout()
  self.items, self.nav = {}, {}
  local y = 0
  for _, sec in ipairs(self.sections) do
    local hh = sec.hero and 0 or HEADER_H
    if hh > 0 then
      self.items[#self.items + 1] = { kind = "header", sec = sec, y = y, h = hh }
    end
    self.nav[#self.nav + 1] = { label = sec.navLabel, y = y, header = true }
    y = y + hh
    for _, e in ipairs(sec.entries) do
      local total = (e.label and LABEL_H or 0) + e.h + ENTRY_GAP
      self.items[#self.items + 1] = { kind = "entry", entry = e, y = y, h = total, showLabel = e.label ~= nil }
      if e.label then self.nav[#self.nav + 1] = { label = e.label, y = y, header = false } end
      y = y + total
    end
  end
  self.contentH = y
end

function Screen:maxScroll() return math.max(0, self.contentH - pageViewH()) end
function Screen:clampScroll()
  local m = self:maxScroll()
  if self.scroll < 0 then self.scroll = 0 elseif self.scroll > m then self.scroll = m end
end

function Screen:update(frameDt)
  self.t = self.t + (frameDt or 1) / 60 -- horloge en SECONDES (respiration des widgets forge ; cf. frameforge)
  self.ambient:update(frameDt)
  Forge.uiTick((frameDt or 1) / 60)
end

function Screen:drawBack(view)
  Draw.begin(view)
  self.ambient:draw("grimoire")
  Draw.finish()
end

function Screen:drawWorld() end

function Screen:drawOverlay(view)
  self._view = view -- les render fns (mini-rig) en ont besoin pour clipper
  Draw.begin(view)

  -- La BANDE GRAVÉE du reliquaire ceint tout l'écran (le contenu vit dans l'inset IX/IY).
  Reliquary.draw(0, 0, Draw.W, Draw.H, { ft = FRAME_FT })

  -- En-tête d'écran (à l'intérieur du cadre).
  Draw.text(T("designsystem.title"), SB_X, TITLE_Y, C.ink, Theme.title(30))
  Draw.textR(T("designsystem.back"), IX + IW - 8, TITLE_Y + 12, C.ink4, Theme.labelSmall(11))
  Draw.divider(IX + IW / 2, TOP - 10, IW - 40, C.brass, 0.45)

  self:drawSidebar()
  self:drawPage(view)

  Draw.finish()
end

-- ── SIDEBAR (navigation : sections + entrées, clic = saut) ───────────────────────────────────────────
function Screen:drawSidebar()
  Draw.rect(SB_X, TOP, SB_W, pageViewH(), C.stone900, C.iron, 1)
  -- quelle ancre est « en haut » (surlignée) : la dernière dont l'ancre <= scroll.
  local activeY = nil
  for _, n in ipairs(self.nav) do if n.y <= self.scroll + 2 then activeY = n.y end end
  self.navRects = {}
  local y = TOP + 14
  local font = Theme.labelSmall(11)
  for i, n in ipairs(self.nav) do
    local r = { x = SB_X + 10, y = y, w = SB_W - 20, h = n.header and 18 or 16 }
    self.navRects[i] = r
    local hov = (self.hoverNav == i)
    local active = (n.y == activeY)
    if n.header then
      if i > 1 then y = y + 8 end; r.y = y
      trackL(n.label, r.x, y, active and C.gold or C.ink3, Theme.label(11), 1.5)
      y = y + 18
    else
      local col = active and C.ink or (hov and C.ink2 or C.ink4)
      Draw.text((active and "› " or "  ") .. n.label, r.x + 6, y, col, font)
      y = y + 16
    end
  end
end

-- ── PAGE scrollable (empile les sections ; clip + molette + thumb, idiome grimoire) ──────────────────
function Screen:drawPage(view)
  Draw.scissor(view, PAGE_X, TOP, PAGE_W, pageViewH())
  for _, it in ipairs(self.items) do
    local y = TOP + it.y - self.scroll
    if y + it.h >= TOP - 2 and y <= BOTTOM + 2 then
      if it.kind == "header" then
        self:drawSectionHeader(CONTENT_X, y + 10, CONTENT_W, it.sec)
      else
        local e = it.entry
        local ey = y
        if it.showLabel then
          groupLabel(e.label, CONTENT_X, y + 2)
          ey = y + LABEL_H
        end
        e.draw(self, CONTENT_X, ey, CONTENT_W)
      end
    end
  end
  Draw.noScissor()

  -- barre de défilement.
  local maxS = self:maxScroll()
  if maxS > 0 then
    local vh = pageViewH()
    local thumbH = math.max(28, vh * vh / self.contentH)
    local ty = TOP + (vh - thumbH) * (self.scroll / maxS)
    Draw.rect(PAGE_X + PAGE_W - 4, TOP, 3, vh, C.stone900)
    Draw.rect(PAGE_X + PAGE_W - 4, ty, 3, thumbH, C.brass)
  end
end

-- En-tête de section « gravé » : grand chiffre romain (laiton) + kicker tracké + titre Cinzel + intro à droite.
function Screen:drawSectionHeader(x, y, w, sec)
  local numF = Theme.title(44)
  Draw.text(sec.numeral, x, y - 8, C.brass, numF)
  local nx = x + Draw.textWidth(sec.numeral, numF) + 22
  trackL(sec.kicker:upper(), nx, y, C.ink3, Theme.labelSmall(10), 2)
  Draw.text(sec.title:upper(), nx, y + 16, C.ink, Theme.title(28))
  -- intro à droite (italique Spectral, alignée à droite, repliée).
  local iw = 320
  Draw.textWrap(sec.intro, x + w - iw, y + 2, iw, C.ink3, Theme.flavor(13), "right")
  -- filet bas (fer + soupçon d'or).
  Draw.divider(x + w / 2, y + 58, w, C.iron, 1)
  Draw.divider(x + w / 2, y + 59, w, C.gold, 0.08)
end

-- ═══════════════════════════ HERO + MANIFESTE ═══════════════════════════

function Screen:drawHero(x, y, w)
  local cx = x + w / 2
  -- kicker
  local k = "RELIQUARY     SYSTÈME VISUEL     V1"
  Draw.textTrackedC(k, cx, y, C.ink3, Theme.labelSmall(11), 4)
  -- titre cérémonial (Jacquard) avec ombre.
  local tf = Theme.display(104)
  Draw.textC("The Pit", cx, y + 20 + 2, C.void, tf)
  Draw.textC("The Pit", cx, y + 20, C.ink, tf)
  -- filet à losange de sang.
  local dy = y + 150
  Draw.divider(cx, dy, 560, C.brass, 0.5)
  Forge.diamondAt(cx, dy, 4, C.blood, C.bloodD)
  -- accroche (Spectral italique, centrée).
  Draw.textWrap("Une refonte du langage visuel. Crasse, sang, et une géométrie qui ment — mais où chaque mot se lit. On descend Le Puits, on ne devine plus l'interface.",
    cx - 320, y + 168, 640, C.ink2, Theme.flavor(15), "center")
  -- manifeste : 3 partis pris.
  self:drawManifesto(x, y + 230, w)
  return 392
end

function Screen:drawManifesto(x, y, w)
  local cols = {
    { n = "01", h = "La lisibilité d'abord", b = "Trois voix fonctionnelles, plus une quatrième cérémoniale et rare. Le gothique pour le titre et les grands mots du destin — jamais pour dire « 6 dégâts »." },
    { n = "02", h = "Un seul cadre, pas mille", b = "L'or encadre le jeu, pas chaque bouton. Un reliquaire ceint tout l'écran ; à l'intérieur, les surfaces sont calmes et le texte respire." },
    { n = "03", h = "Le grimdark par la matière", b = "Pierre noire, laiton terni, os, et le sang comme unique accent chaud. L'ambiance vient des matériaux et de la lumière — pas du bruit." },
  }
  local gap = 14
  local colW = math.floor((w - 2 * gap) / 3)
  local ch = 150
  for i, col in ipairs(cols) do
    local cxx = x + (i - 1) * (colW + gap)
    card(cxx, y, colW, ch, true)
    local px = cxx + 18
    Draw.text(col.n, px, y + 18, C.bloodL, Theme.label(11))
    Draw.text(col.h:upper(), px, y + 34, C.ink, Theme.heading(14))
    Draw.textWrap(col.b, px, y + 58, colW - 36, C.ink3, Theme.body(13), "left")
  end
  return ch
end

-- ═══════════════════════════ I · COULEUR ═══════════════════════════

function Screen:drawColors(x, y, w)
  local perRow = swatchPerRow()
  local cy = y
  for _, grp in ipairs(COLOR_GROUPS) do
    groupLabel(grp.name, x, cy)
    cy = cy + GROUP_LABEL_H
    for i, item in ipairs(grp.keys) do
      local key = item[1]
      local note = item[2]
      local col = C[key]
      local cidx = (i - 1) % perRow
      local row = math.floor((i - 1) / perRow)
      local sx = x + cidx * (SWATCH_W + SW_GAP)
      local sy = cy + row * (SWATCH_CARD_H + SW_GAP)
      Draw.rect(sx, sy, SWATCH_W, SWATCH_BAND, col, C.iron, 1)
      Draw.text(key, sx, sy + SWATCH_BAND + 5, C.ink, Theme.label(10))
      Draw.text(hexOf(col) .. (note and ("  " .. note) or ""), sx, sy + SWATCH_BAND + 18, C.ink4, Theme.labelSmall(9))
    end
    cy = cy + math.ceil(#grp.keys / perRow) * (SWATCH_CARD_H + SW_GAP) + GROUP_GAP
  end
  return cy - y
end

-- ═══════════════════════════ II · TYPOGRAPHIE ═══════════════════════════

-- Une carte de « voix » : kicker, grand échantillon dans la fonte, filet, rôle (prose).
local function voiceCard(x, y, w, h, kicker, big, bigFn, bigPx, role)
  card(x, y, w, h, true)
  local px = x + 18
  trackL(kicker:upper(), px, y + 16, C.bloodL, Theme.labelSmall(10), 1.5)
  local bf = bigFn(bigPx)
  if bf then Draw.text(big, px, y + 30, C.ink, bf) end
  Draw.divider(x + w / 2, y + h - 56, w - 36, C.brass, 0.4)
  Draw.textWrap(role, px, y + h - 48, w - 36, C.ink3, Theme.body(12.5), "left")
end

function Screen:drawVoices(x, y, w)
  -- bandeau cérémonial (Jacquard) — la voix la plus rare.
  local bh = 110
  card(x, y, w, bh, true)
  trackL("VOIX CÉRÉMONIALE · LA PLUS RARE", x + 20, y + 16, C.bloodL, Theme.labelSmall(10), 1.5)
  local jf = Theme.display(58)
  if jf then Draw.text("The Pit", x + 20, y + 30, C.ink, jf) end
  Draw.textWrap("Le titre du jeu et les grands mots du destin — Victory, Defeat, Ascension. Quelques mots par partie, pas un de plus. Jamais un libellé, une valeur ou une phrase.",
    x + w - 360, y + 24, 340, C.ink3, Theme.body(13), "right")

  -- trois voix fonctionnelles (Cinzel / Spectral / Space Mono).
  local cy = y + bh + 14
  local gap = 14
  local colW = math.floor((w - 2 * gap) / 3)
  local ch = 196
  voiceCard(x + 0 * (colW + gap), cy, colW, ch, "Voix gravée", "Cinzel", Theme.title, 40,
    "Titres, logotype, noms, grands mots de résultat. Capitales, interlettrage large.")
  voiceCard(x + 1 * (colW + gap), cy, colW, ch, "Voix manuscrite", "Spectral", Theme.body, 40,
    "La prose lisible : descriptions, lore, saveur (en italique). Le texte qui respire.")
  voiceCard(x + 2 * (colW + gap), cy, colW, ch, "Voix inscrite", "Space Mono", Theme.value, 30,
    "Libellés & toutes les valeurs : chiffres tabulaires, sans ambiguïté.")
  return bh + 14 + ch
end

function Screen:drawScale(x, y, w)
  card(x, y, w, #TYPE_SCALE * 34 + 4, false)
  local cy = y + 2
  for i, r in ipairs(TYPE_SCALE) do
    if i > 1 then Draw.divider(x + w / 2, cy, w - 4, C.iron, 0.7) end
    Draw.text(r.tag, x + 14, cy + 11, C.ink3, Theme.labelSmall(10))
    local f = r.fn(r.px)
    if f then Draw.text(r.s, x + 150, cy + 8, C.ink, f) end
    Draw.textR(r.note, x + w - 14, cy + 12, C.ink4, Theme.flavor(12))
    cy = cy + 34
  end
  return #TYPE_SCALE * 34 + 6
end

-- ═══════════════════════════ III · ICONOGRAPHIE ═══════════════════════════

function Screen:drawTypePips(x, y, w)
  local n = #TYPE_NAMES
  local gap = 12
  local cw = math.floor((w - (n - 1) * gap) / n)
  local ch = 88
  for i, name in ipairs(TYPE_NAMES) do
    local cxx = x + (i - 1) * (cw + gap)
    card(cxx, y, cw, ch, false)
    Draw.pip(name, cxx + cw / 2, y + 30, 12)
    Draw.textTrackedC(T("type." .. name):upper(), cxx + cw / 2, y + 52, C.ink, Theme.label(11), 1)
    Draw.textC(Theme.type(name).pip, cxx + cw / 2, y + 68, C.ink4, Theme.flavor(11))
  end
  return ch
end

function Screen:drawAffl(x, y, w)
  self.afflWidgets = self.afflWidgets or {} -- une silhouette bakée par famille (allouée 1×, re-rendue chaque frame)
  local n = #ICONO_AFFL
  local gap = 12
  local cw = math.floor((w - (n - 1) * gap) / n)
  local ch = 92
  local aw = 22 -- taille d'art de l'icône (blit ×2 -> 44px design)
  for i, key in ipairs(ICONO_AFFL) do
    local cxx = x + (i - 1) * (cw + gap)
    card(cxx, y, cw, ch, false)
    -- silhouette d'affliction PAR FORME (Forge.afflShape : les 7 du design system, teintées Theme.c[key]).
    local wdg = self.afflWidgets[key]
    if not wdg then wdg = Forge.newWidget(aw, aw); self.afflWidgets[key] = wdg end
    if wdg then
      Forge.render(wdg, function(buf, W, H, tt) Forge.afflShape(buf, W, H, key, tt) end, self.t)
      if wdg.image then Forge.blit(wdg.image, cxx + cw / 2 - aw, y + 12, 2) end
    end
    Draw.textTrackedC(key:upper(), cxx + cw / 2, y + 64, C[key] or C.ink, Theme.label(10), 1)
    Draw.textC(hexOf(C[key]), cxx + cw / 2, y + 78, C.ink4, Theme.labelSmall(9))
  end
  return ch
end

-- ═══════════════════════════ IV · COMPOSANTS ═══════════════════════════

-- Une rangée de boutons d'un ton, montrant ses états figés + (cta) un bouton LIVE qui suit la souris.
function Screen:_btnRow(x, y, tone, label, bw, bh, opts)
  opts = opts or {}
  local gap = 16
  local cx = x
  local states = { { "idle" }, { "hover", hover = true }, { "pressed", active = true }, { "disabled", disabled = true } }
  for _, s in ipairs(states) do
    Forge.uiButton("ds.btn." .. tone .. "." .. s[1], cx, y, bw, bh, label,
      { tone = tone, hover = s.hover, active = s.active, disabled = s.disabled, cost = opts.cost,
        fontSz = opts.fontSz or 8, eyeR = 7, t = self.t })
    Draw.textC(s[1], cx + bw / 2, y + bh + 4, C.ink4, Theme.labelSmall(8))
    cx = cx + bw + gap
  end
  if tone == "cta" then
    local hov = ptIn(self.mx, self.my, cx, y, bw, bh)
    Forge.uiButton("ds.btn.cta.live", cx, y, bw, bh, label,
      { tone = tone, hover = hov, active = hov and self._down, mouse = { mx = self.mx, my = self.my },
        fontSz = opts.fontSz or 8, eyeR = 7, t = self.t })
    Draw.textC("LIVE", cx + bw / 2, y + bh + 4, C.gold, Theme.labelSmall(8))
  end
  return bh + 18
end

function Screen:drawButtons(x, y, w)
  local cy = y
  cy = cy + self:_btnRow(x, cy, "cta", "ENTER", 132, 34, { fontSz = 9 })
  cy = cy + 8
  cy = cy + self:_btnRow(x, cy, "eco", "REROLL", 120, 30, { cost = 2 })
  cy = cy + 8
  local kinds = { "sigil", "left", "right", "gear" }
  local ix = x
  for _, k in ipairs(kinds) do
    Forge.uiButton("ds.btn.icon." .. k, ix, cy, 36, 36, "", { tone = "icon", cost = k, t = self.t })
    Draw.textC(k, ix + 18, cy + 40, C.ink4, Theme.labelSmall(8))
    ix = ix + 70
  end
  return (cy - y) + 56
end

function Screen:drawStates(x, y, w)
  local bw, bh, gap = 124, 30, 10
  local font = Theme.label(11)
  for i, name in ipairs(STATE_NAMES) do
    local bx = x + (i - 1) * (bw + gap)
    Frame.button(bx, y, bw, bh, name:upper(), { state = name, font = font, level = "bevel" })
  end
  return bh + 8
end

function Screen:drawFrames(x, y, w)
  local levels = { "plain", "bevel", "gilded" }
  local cols = { "idle", "hover", "pressed", "disabled", "selected", "danger" }
  local bw, bh, gx, gy = 132, 34, 12, 12
  local font = Theme.label(10)
  for ci, st in ipairs(cols) do
    Draw.text(st, x + 70 + (ci - 1) * (bw + gx), y, C.ink4, Theme.labelSmall(8))
  end
  for li, lv in ipairs(levels) do
    local ry = y + 14 + (li - 1) * (bh + gy)
    Draw.text(lv, x, ry + bh / 2 - 5, C.ink3, Theme.label(10))
    for ci, st in ipairs(cols) do
      local bx = x + 70 + (ci - 1) * (bw + gx)
      Frame.button(bx, ry, bw, bh, lv:upper(), { level = lv, state = st, font = font })
    end
  end
  return 14 + #levels * (bh + gy)
end

function Screen:drawChips(x, y, w)
  Chip.row(x, y, {
    { key = "poison", value = "6dps", font = Theme.label(9), h = 18 },
    { key = "bleed", value = "4dps-3s", font = Theme.label(9), h = 18 },
    { key = "burn", font = Theme.label(9), h = 18 },
    { key = "rot", label = "AMPUTE", icon = false, color = C.rot, font = Theme.label(9), h = 18 },
    { key = "shock", value = "+15%", font = Theme.label(9), h = 18 },
  }, { gap = 8 })
  Draw.text("clé -> icône+couleur+nom ; value à droite ; icon=false pour un tag pur", x, y + 30, C.ink4, Theme.flavor(12))
  return 48
end

function Screen:drawStatus(x, y, w)
  local step = 116
  for i, key in ipairs(AFFL_KEYS) do
    local cx = x + (i - 1) * step
    local ic = Keywords.icon(key)
    if ic then
      love.graphics.setColor(1, 1, 1, 1)
      love.graphics.draw(ic.image, math.floor(cx), math.floor(y + 4), 0, 2, 2)
    end
    local kw = Keywords.get(key)
    Draw.text(Keywords.name(key), cx + 24, y + 6, kw and kw.color or C.ink3, Theme.label(10))
    Chip.draw(cx, y + 30, { key = key, value = "6dps", font = Theme.label(9), h = 18 })
  end
  local sx = x + #AFFL_KEYS * step
  Draw.setColor(C.shield)
  love.graphics.rectangle("fill", sx + 6, y + 4, 12, 4)
  love.graphics.rectangle("fill", sx + 10, y, 4, 12)
  Draw.text("shield", sx + 24, y + 6, C.shield, Theme.label(10))
  Draw.reset()
  return 56
end

function Screen:drawMarks(x, y, w)
  for i, n in ipairs(TYPE_NAMES) do Draw.pip(n, x + 12 + (i - 1) * 34, y + 14, 9) end
  Draw.text("Draw.pip", x, y + 32, C.ink4, Theme.flavor(12))
  local dx = x + 220
  Forge.diamondAt(dx, y + 14, 4, C.gold); Forge.diamondAt(dx + 24, y + 14, 6, C.goldBright)
  Forge.diamondAt(dx + 52, y + 14, 8, C.blood, C.bloodDeep)
  Draw.text("Forge.diamondAt", dx - 4, y + 32, C.ink4, Theme.flavor(12))
  local cx = x + 420
  Forge.coinAt(cx, y + 14, 6, C.gold); Forge.coinAt(cx + 26, y + 14, 6, C.gold, true)
  Draw.text("Forge.coinAt (plein / dim)", cx - 6, y + 32, C.ink4, Theme.flavor(12))
  Forge.label("LABEL", x + 660, y + 14, 16, C.ctaText, { bold = true })
  Draw.text("Forge.label", x + 624, y + 32, C.ink4, Theme.flavor(12))
  return 52
end

function Screen:drawPlates(x, y, w)
  local bw, bh = 150, 72
  Forge.uiPlate("ds.plate", x, y, bw, bh, {})
  Draw.textC("uiPlate", x + bw / 2, y + bh + 4, C.ink4, Theme.labelSmall(8))
  Forge.uiSocket("ds.socket", x + bw + 24, y, bw, bh, { accentCol = Forge.accentFrom(C.gold) })
  Draw.textC("uiSocket", x + bw + 24 + bw / 2, y + bh + 4, C.ink4, Theme.labelSmall(8))
  Forge.uiCard("ds.card", x + 2 * (bw + 24), y, bw, bh, { seed = 40, t = self.t })
  Draw.textC("uiCard (respire)", x + 2 * (bw + 24) + bw / 2, y + bh + 4, C.ink4, Theme.labelSmall(8))
  return bh + 16
end

function Screen:drawValues(x, y, w)
  local specs = { { "HP", 70, C.body }, { "DMG", 6, C.dmg }, { "CD", "6s", C.ink3 } }
  for i, s in ipairs(specs) do
    Forge.valueTag("ds.vt." .. s[1], x + (i - 1) * 80, y, 70, 40, s[1], s[2],
      { valueColor = s[3], accentCol = Forge.accentFrom(C.gold) })
  end
  local bx = x + 280
  Draw.bar(bx, y + 6, 160, 12, 0.8, C.heal, C.stone900, C.iron)
  Draw.bar(bx, y + 24, 160, 12, 0.35, C.blood, C.stone900, C.iron)
  Draw.text("Draw.bar (pct)", bx, y + 42, C.ink4, Theme.flavor(12))
  local dx = x + 480
  Draw.divider(dx + 120, y + 16, 240, C.gold, 1)
  Draw.text("Draw.divider", dx + 60, y + 42, C.ink4, Theme.flavor(12))
  return 64
end

function Screen:drawRigs(x, y, w)
  local box = 64
  for i, id in ipairs(self.rigIds) do
    local bx = x + (i - 1) * (box + 24)
    Draw.rect(bx, y, box, box, C.stone900, C.iron, 1)
    MiniRig.draw(self._view, id, self.palette, bx, y, box, box, 1)
    Draw.textC(id, bx + box / 2, y + box + 4, C.ink4, Theme.labelSmall(8))
  end
  return box + 16
end

-- ── Entrées (souris / molette / clavier) ────────────────────────────────────────────────────────────
function Screen:navAt(dx, dy)
  for i, r in ipairs(self.navRects) do
    if ptIn(dx, dy, r.x, r.y, r.w, r.h) then return i end
  end
  return nil
end

function Screen:mousemoved(vx, vy)
  self.mx, self.my = vx * 4, vy * 4
  self.hoverNav = self:navAt(self.mx, self.my)
end

function Screen:mousepressed(vx, vy, button)
  if button ~= 1 then return end
  local dx, dy = vx * 4, vy * 4
  self._down = true
  local i = self:navAt(dx, dy)
  if i then
    self.scroll = self.nav[i].y
    self:clampScroll()
  end
end

function Screen:mousereleased(vx, vy, button)
  if button == 1 then self._down = false end
end

function Screen:wheelmoved(_, dy)
  self.scroll = self.scroll - (dy or 0) * 48
  self:clampScroll()
end

function Screen:keypressed(key)
  if key == "escape" or key == "m" then
    self.host.goto("menu")
  elseif key == "down" then
    self.scroll = self.scroll + 48; self:clampScroll()
  elseif key == "up" then
    self.scroll = self.scroll - 48; self:clampScroll()
  elseif key == "pagedown" or key == "space" then
    self.scroll = self.scroll + pageViewH() * 0.9; self:clampScroll()
  elseif key == "pageup" then
    self.scroll = self.scroll - pageViewH() * 0.9; self:clampScroll()
  end
end

return Screen
