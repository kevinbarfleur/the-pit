-- src/scenes/designsystem.lua
-- L'ÉCRAN « DESIGN SYSTEM » — un Storybook IN-ENGINE. Source de vérité VISUELLE de l'UI : chaque composant
-- (token -> atome -> molécule -> organisme, méthodo Brad Frost) y est rendu DANS TOUS SES ÉTATS, en isolation,
-- pour qu'on JUGE la cohérence d'ensemble et qu'on ITÈRE ici (et seulement ici) avant de re-câbler le jeu.
--
-- MISE EN PAGE (décision user) : SIDEBAR atomic ancrée à gauche (clic = saut vers la section) + PAGE
-- SCROLLABLE à droite, groupée par niveau, plusieurs composants visibles à la fois. Interactivité : les
-- états sont MONTRÉS côte à côte (idle/hover/pressed/disabled/danger…) ET le hover réel marche à la souris.
--
-- ARCHI : catalogue = DATA. `self.sections = { {level, entries={ {id, label, h, draw=fn(self,x,y,w)} } } }`.
-- `:layout()` aplatit en `self.items` (header de niveau / entrée) avec une ancre Y cumulée -> la page empile,
-- la sidebar saute. Couche RENDER pure (love.graphics) — hors firewall SIM, golden neutre. Calque les idiomes
-- éprouvés de grimoire.lua (liste scrollable Draw.scissor + molette + thumb) et frameforge.lua (widgets Forge).
-- daChrome=true ; [esc] -> host.goto("menu"). Headless-safe (Forge/MiniRig no-op proprement sous le mock).

local Theme = require("src.ui.theme")
local Draw = require("src.ui.draw")
local Frame = require("src.ui.frame")
local Chip = require("src.ui.chip")
local Keywords = require("src.ui.keywords")
local Forge = require("src.ui.forge")
local Ambient = require("src.fx.ambient")
local MiniRig = require("src.render.minirig")
local Units = require("src.data.units")
local T = require("src.core.i18n").t
local C = Theme.c

local Screen = {}
Screen.__index = Screen

-- ── Mise en page (ESPACE DESIGN 1280×720) ──────────────────────────────────────────────────────────
local TITLE_Y = 26
local TOP, BOTTOM = 82, 692
local SB_X, SB_W = 30, 188             -- sidebar (gauche)
local PAGE_X = 234                      -- page (droite)
local PAGE_W = 1280 - PAGE_X - 30       -- = 1016
local PAGE_PAD = 18
local CONTENT_X = PAGE_X + PAGE_PAD
local CONTENT_W = PAGE_W - 2 * PAGE_PAD -- = 980
local HEADER_H = 48                     -- bloc « titre de niveau »
local LABEL_H = 22                      -- libellé d'une entrée
local ENTRY_GAP = 22                    -- marge sous une entrée
local function pageViewH() return BOTTOM - TOP end

-- swatch de couleur (token) : pavé + nom + hex. Grille à `perRow` colonnes dans CONTENT_W.
local SWATCH_W, SWATCH_H, SW_GAP = 152, 30, 8
local GROUP_LABEL_H, GROUP_GAP = 20, 12
local function swatchPerRow() return math.max(1, math.floor((CONTENT_W + SW_GAP) / (SWATCH_W + SW_GAP))) end

local function ptIn(px, py, x, y, w, h) return px >= x and px <= x + w and py >= y and py <= y + h end

-- float {r,g,b} -> "#rrggbb" (recompose le hex du token pour l'afficher tel qu'il est défini dans theme.lua).
local function hexOf(col)
  local r = math.floor((col[1] or 0) * 255 + 0.5)
  local g = math.floor((col[2] or 0) * 255 + 0.5)
  local b = math.floor((col[3] or 0) * 255 + 0.5)
  return string.format("#%02x%02x%02x", r, g, b)
end

-- Groupes de couleurs (ordonnés, par RÔLE) — les clés réelles de Theme.c (theme.lua l.24-89).
local COLOR_GROUPS = {
  { name = "Fonds",       keys = { "void", "bgDeep", "bgPit", "bgWarm", "bgEmber", "panel", "panelDeep", "slot", "slotLocked" } },
  { name = "Encres",      keys = { "inkBright", "ctaText", "title", "body", "name", "muted", "dim", "faint", "fainter", "ghost", "lock" } },
  { name = "Sang & Or",   keys = { "blood", "bloodBright", "bloodDeep", "bloodEdge", "dmg", "gold", "goldBright" } },
  { name = "Statuts",     keys = { "heal", "shield", "drop", "ember" } },
  { name = "Afflictions", keys = { "poison", "bleed", "bleedDeep", "burn", "rot", "shock" } },
  { name = "Plateau",     keys = { "slotEdge", "slotEdgeLck", "edgeIdle", "edgeActive" } },
  { name = "Lignes",      keys = { "hair", "line" } },
  { name = "Économie",    keys = { "ecoBg", "ecoBgHot", "ecoBorder", "cardHover" } },
}

-- Échantillons de typographie : rôle, fonte, taille de démo, échantillon, note d'usage.
local TYPE_SAMPLES = {
  { role = "display",   fn = Theme.display,   px = 30, sample = "The Pit",                     note = "Logotype + grands mots de résultat UNIQUEMENT" },
  { role = "ui",        fn = Theme.ui,        px = 13, sample = "REROLL   LEVEL   COMBAT",     note = "Labels/boutons courts en CAPITALES (Silkscreen)" },
  { role = "uiBold",    fn = Theme.uiBold,    px = 13, sample = "GRIMOIRE   BESTIARY",         note = "Labels en gras" },
  { role = "read",      fn = Theme.read,      px = 16, sample = "Poison 6 dps - 3s : +5% (up to 5).", note = "VALEURS + prose mécanique (lisible, Pixel Operator)" },
  { role = "loreRoman", fn = Theme.loreRoman, px = 18, sample = "You descend.",                note = "Kickers / citations (serif d'ambiance)" },
  { role = "lore",      fn = Theme.lore,      px = 18, sample = '"It drinks first."',          note = "Flavor / phrase philosophique (italique)" },
}

local STATE_NAMES = { "idle", "hover", "pressed", "disabled", "selected", "danger", "drop" }
local AFFL_KEYS = { "poison", "bleed", "burn", "rot", "shock" }

function Screen.new(palette, vw, vh, host)
  local self = setmetatable({
    palette = palette, vw = vw, vh = vh, host = host, t = 0,
    daChrome = true, titleKey = "designsystem.title", hintKey = "ui.empty",
    scroll = 0, mx = -1, my = -1, hoverNav = nil,
    ambient = Ambient.new(9),
    navRects = {},
  }, Screen)
  -- quelques ids d'unités pour les mini-rigs (variété ; gardé si le roster change).
  self.rigIds = {}
  for _, i in ipairs({ 1, 6, 12, 20 }) do
    if Units.order[i] then self.rigIds[#self.rigIds + 1] = Units.order[i] end
  end
  self:buildSections()
  self:layout()
  return self
end

-- ── Construction du CATALOGUE (data + render fns) ───────────────────────────────────────────────────
function Screen:buildSections()
  self.sections = {
    { level = "TOKENS", entries = {
      { id = "colors", label = "Couleurs (Theme.c)", h = self:colorsHeight(), draw = Screen.drawColors },
      { id = "type",   label = "Typographie",        h = #TYPE_SAMPLES * 40 + 6, draw = Screen.drawType },
      { id = "states", label = "États interactifs (Theme.state)", h = 64, draw = Screen.drawStates },
      { id = "types",  label = "Types d'unité (pips)", h = 56, draw = Screen.drawTypes },
    } },
    { level = "ATOMS", entries = {
      { id = "buttons", label = "Boutons (Forge.uiButton)", h = 232, draw = Screen.drawButtons },
      { id = "status",  label = "Icônes de statut (Keywords)", h = 78, draw = Screen.drawStatus },
      { id = "chips",   label = "Chips (Chip.draw)", h = 64, draw = Screen.drawChips },
      { id = "marks",   label = "Pips · diamants · pièces", h = 70, draw = Screen.drawMarks },
      { id = "frames",  label = "Cadres (Frame.draw)", h = 150, draw = Screen.drawFrames },
      { id = "plates",  label = "Plaques & sockets (Forge)", h = 110, draw = Screen.drawPlates },
      { id = "values",  label = "Value-tags · barres · dividers", h = 96, draw = Screen.drawValues },
      { id = "rigs",    label = "Mini-rigs (MiniRig.draw)", h = 84, draw = Screen.drawRigs },
    } },
  }
end

-- Hauteur du nuancier (mêmes maths que drawColors -> layout & rendu cohérents).
function Screen:colorsHeight()
  local perRow = swatchPerRow()
  local h = 0
  for gi, grp in ipairs(COLOR_GROUPS) do
    local rows = math.ceil(#grp.keys / perRow)
    h = h + GROUP_LABEL_H + rows * (SWATCH_H + SW_GAP)
    if gi < #COLOR_GROUPS then h = h + GROUP_GAP end
  end
  return h
end

-- Aplatit sections -> self.items {kind, level?/entry?, y (ancre dans le contenu), h} + self.nav (sidebar).
function Screen:layout()
  self.items, self.nav = {}, {}
  local y = 0
  for _, sec in ipairs(self.sections) do
    self.items[#self.items + 1] = { kind = "header", level = sec.level, y = y, h = HEADER_H }
    self.nav[#self.nav + 1] = { label = sec.level, y = y, header = true }
    y = y + HEADER_H
    for _, e in ipairs(sec.entries) do
      local total = LABEL_H + e.h + ENTRY_GAP
      self.items[#self.items + 1] = { kind = "entry", entry = e, y = y, h = total }
      self.nav[#self.nav + 1] = { label = e.label, y = y, header = false }
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
  Forge.uiTick((frameDt or 1) / 60) -- horloge interne des widgets forge (en SECONDES)
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

  -- En-tête.
  Draw.text(T("designsystem.title"), SB_X, TITLE_Y, C.title, Theme.display(34))
  Draw.textR(T("designsystem.back"), Draw.W - 30, TITLE_Y + 14, C.ghost, Theme.ui(11))
  Draw.divider(Draw.W / 2, TOP - 10, Draw.W - 80, C.gold, 0.5)

  self:drawSidebar()
  self:drawPage(view)

  Draw.finish()
end

-- ── SIDEBAR (navigation atomic : headers de niveau + entrées, clic = saut) ───────────────────────────
function Screen:drawSidebar()
  Draw.rect(SB_X, TOP, SB_W, pageViewH(), C.panelDeep, C.hair, 1)
  -- quel item de page est « en haut » (surligné dans la sidebar) : le dernier dont l'ancre <= scroll.
  local activeY = nil
  for _, n in ipairs(self.nav) do if n.y <= self.scroll + 2 then activeY = n.y end end
  self.navRects = {}
  local y = TOP + 12
  local font = Theme.ui(11)
  for i, n in ipairs(self.nav) do
    local r = { x = SB_X + 10, y = y, w = SB_W - 20, h = n.header and 18 or 16 }
    self.navRects[i] = r
    local hov = (self.hoverNav == i)
    local active = (n.y == activeY)
    if n.header then
      if i > 1 then y = y + 6 end; r.y = y
      Draw.text(n.label, r.x, y, active and C.gold or C.muted, Theme.uiBold(11))
      y = y + 18
    else
      local col = active and C.inkBright or (hov and C.body or C.faint)
      Draw.text((active and "> " or "  ") .. n.label, r.x + 6, y, col, font)
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
        Draw.text(it.level, CONTENT_X, y + 6, C.title, Theme.display(28))
        Draw.divider(PAGE_X + PAGE_W / 2, y + 40, PAGE_W - 40, C.gold, 0.6)
      else
        local e = it.entry
        Draw.text(e.label, CONTENT_X, y + 2, C.goldBright, Theme.uiBold(13))
        e.draw(self, CONTENT_X, y + LABEL_H, CONTENT_W)
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
    Draw.rect(PAGE_X + PAGE_W - 4, TOP, 3, vh, C.panelDeep)
    Draw.rect(PAGE_X + PAGE_W - 4, ty, 3, thumbH, C.ecoBorder)
  end
end

-- ═══════════════════════════ RENDER FNS — TOKENS ═══════════════════════════

function Screen:drawColors(x, y, w)
  local perRow = swatchPerRow()
  local cy = y
  for _, grp in ipairs(COLOR_GROUPS) do
    Draw.text(grp.name, x, cy, C.muted, Theme.ui(10))
    cy = cy + GROUP_LABEL_H
    for i, key in ipairs(grp.keys) do
      local col = C[key]
      local col2 = (i - 1) % perRow
      local row = math.floor((i - 1) / perRow)
      local sx = x + col2 * (SWATCH_W + SW_GAP)
      local sy = cy + row * (SWATCH_H + SW_GAP)
      Draw.rect(sx, sy, 26, 26, col, C.line, 1)
      Draw.text(key, sx + 32, sy + 1, C.body, Theme.ui(9))
      Draw.text(hexOf(col), sx + 32, sy + 14, C.faint, Theme.read(11))
    end
    cy = cy + math.ceil(#grp.keys / perRow) * (SWATCH_H + SW_GAP) + GROUP_GAP
  end
  return cy - y
end

function Screen:drawType(x, y, w)
  local cy = y
  for _, s in ipairs(TYPE_SAMPLES) do
    Draw.text(s.role, x, cy + 8, C.muted, Theme.ui(9))
    local font = s.fn(s.px)
    if font then Draw.text(s.sample, x + 96, cy + 4, C.body, font) end
    Draw.textR(s.note, x + w, cy + 12, C.fainter, Theme.ui(9))
    cy = cy + 40
  end
  return cy - y
end

function Screen:drawStates(x, y, w)
  local bw, bh, gap = 124, 30, 10
  local font = Theme.uiBold(12)
  for i, name in ipairs(STATE_NAMES) do
    local bx = x + (i - 1) * (bw + gap)
    Frame.button(bx, y, bw, bh, name:upper(), { state = name, font = font, level = "bevel" })
  end
  return bh + 8
end

function Screen:drawTypes(x, y, w)
  local names = { "flesh", "order", "bone", "arcane", "abyss" }
  local step = 150
  for i, name in ipairs(names) do
    local cx = x + (i - 1) * step + 16
    Draw.pip(name, cx, y + 18, 12)
    Draw.text(T("type." .. name):upper(), cx + 22, y + 4, Theme.type(name).color, Theme.ui(10))
    Draw.text(hexOf(Theme.type(name).color), cx + 22, y + 18, C.faint, Theme.read(11))
  end
  return 48
end

-- ═══════════════════════════ RENDER FNS — ATOMS ═══════════════════════════

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
    Draw.textC(s[1], cx + bw / 2, y + bh + 4, C.fainter, Theme.ui(8))
    cx = cx + bw + gap
  end
  -- bouton LIVE (hover réel) seulement pour le CTA (le bouton-œil signature).
  if tone == "cta" then
    local hov = ptIn(self.mx, self.my, cx, y, bw, bh)
    Forge.uiButton("ds.btn.cta.live", cx, y, bw, bh, label,
      { tone = tone, hover = hov, active = hov and self._down, mouse = { mx = self.mx, my = self.my },
        fontSz = opts.fontSz or 8, eyeR = 7, t = self.t })
    Draw.textC("LIVE", cx + bw / 2, y + bh + 4, C.gold, Theme.ui(8))
  end
  return bh + 18
end

function Screen:drawButtons(x, y, w)
  local cy = y
  cy = cy + self:_btnRow(x, cy, "cta", "ENTER", 132, 34, { fontSz = 9 })
  cy = cy + 8
  cy = cy + self:_btnRow(x, cy, "eco", "REROLL", 120, 30, { cost = 2 })
  cy = cy + 8
  -- ton ICON : opts.cost = kind du glyphe.
  local kinds = { "sigil", "left", "right", "gear" }
  local ix = x
  for _, k in ipairs(kinds) do
    Forge.uiButton("ds.btn.icon." .. k, ix, cy, 36, 36, "", { tone = "icon", cost = k, t = self.t })
    Draw.textC(k, ix + 18, cy + 40, C.fainter, Theme.ui(8))
    ix = ix + 70
  end
  return (cy - y) + 56
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
    Draw.text(Keywords.name(key), cx + 24, y + 6, kw and kw.color or C.muted, Theme.ui(10))
    Chip.draw(cx, y + 30, { key = key, value = "6dps", font = Theme.ui(9), h = 18 })
  end
  -- bouclier : croix dessinée (pas une affliction -> hors Keywords) + chip neutre.
  local sx = x + #AFFL_KEYS * step
  Draw.setColor(C.shield)
  love.graphics.rectangle("fill", sx + 6, y + 4, 12, 4)
  love.graphics.rectangle("fill", sx + 10, y, 4, 12)
  Draw.text("shield", sx + 24, y + 6, C.shield, Theme.ui(10))
  Draw.reset()
  return 56
end

function Screen:drawChips(x, y, w)
  Chip.row(x, y, {
    { key = "poison", value = "6dps", font = Theme.ui(9), h = 18 },
    { key = "bleed", value = "4dps-3s", font = Theme.ui(9), h = 18 },
    { key = "burn", font = Theme.ui(9), h = 18 },
    { key = "rot", label = "AMPUTE", icon = false, color = C.rot, font = Theme.ui(9), h = 18 },
    { key = "shock", value = "+15%", font = Theme.ui(9), h = 18 },
  }, { gap = 8 })
  Draw.text("clé -> icône+couleur+nom ; value à droite ; icon=false pour un tag pur", x, y + 30, C.fainter, Theme.ui(9))
  return 48
end

function Screen:drawMarks(x, y, w)
  -- pips de type (5 formes).
  local names = { "flesh", "order", "bone", "arcane", "abyss" }
  for i, n in ipairs(names) do Draw.pip(n, x + 12 + (i - 1) * 34, y + 14, 9) end
  Draw.text("Draw.pip", x, y + 32, C.fainter, Theme.ui(9))
  -- diamants (Forge.diamondAt) à plusieurs tailles/teintes.
  local dx = x + 220
  Forge.diamondAt(dx, y + 14, 4, C.gold); Forge.diamondAt(dx + 24, y + 14, 6, C.goldBright)
  Forge.diamondAt(dx + 52, y + 14, 8, C.blood, C.bloodDeep)
  Draw.text("Forge.diamondAt", dx - 4, y + 32, C.fainter, Theme.ui(9))
  -- pièces (Forge.coinAt) : pleine + éteinte.
  local cx = x + 420
  Forge.coinAt(cx, y + 14, 6, C.gold); Forge.coinAt(cx + 26, y + 14, 6, C.gold, true)
  Draw.text("Forge.coinAt (plein / dim)", cx - 6, y + 32, C.fainter, Theme.ui(9))
  -- label forge (overlay vivant).
  Forge.label("LABEL", x + 660, y + 14, 16, C.ctaText, { bold = true })
  Draw.text("Forge.label", x + 624, y + 32, C.fainter, Theme.ui(9))
  return 52
end

function Screen:drawFrames(x, y, w)
  local levels = { "plain", "bevel", "gilded" }
  local cols = { "idle", "hover", "pressed", "disabled", "selected", "danger" }
  local bw, bh, gx, gy = 132, 34, 12, 12
  local font = Theme.ui(10)
  -- en-têtes de colonne (états).
  for ci, st in ipairs(cols) do
    Draw.text(st, x + 70 + (ci - 1) * (bw + gx), y, C.fainter, Theme.ui(8))
  end
  for li, lv in ipairs(levels) do
    local ry = y + 14 + (li - 1) * (bh + gy)
    Draw.text(lv, x, ry + bh / 2 - 5, C.muted, Theme.uiBold(10))
    for ci, st in ipairs(cols) do
      local bx = x + 70 + (ci - 1) * (bw + gx)
      Frame.button(bx, ry, bw, bh, lv:upper(), { level = lv, state = st, font = font })
    end
  end
  return 14 + #levels * (bh + gy)
end

function Screen:drawPlates(x, y, w)
  local bw, bh = 150, 72
  Forge.uiPlate("ds.plate", x, y, bw, bh, {})
  Draw.textC("uiPlate", x + bw / 2, y + bh + 4, C.fainter, Theme.ui(8))
  Forge.uiSocket("ds.socket", x + bw + 24, y, bw, bh, { accentCol = Forge.accentFrom(C.gold) })
  Draw.textC("uiSocket", x + bw + 24 + bw / 2, y + bh + 4, C.fainter, Theme.ui(8))
  Forge.uiCard("ds.card", x + 2 * (bw + 24), y, bw, bh, { seed = 40, t = self.t })
  Draw.textC("uiCard (respire)", x + 2 * (bw + 24) + bw / 2, y + bh + 4, C.fainter, Theme.ui(8))
  return bh + 16
end

function Screen:drawValues(x, y, w)
  -- value-tags (HP/DMG/CD).
  local specs = { { "HP", 70, C.body }, { "DMG", 6, C.dmg }, { "CD", "6s", C.muted } }
  for i, s in ipairs(specs) do
    Forge.valueTag("ds.vt." .. s[1], x + (i - 1) * 80, y, 70, 40, s[1], s[2],
      { valueColor = s[3], accentCol = Forge.accentFrom(C.gold) })
  end
  -- barres (Draw.bar) à divers pct.
  local bx = x + 280
  Draw.bar(bx, y + 6, 160, 12, 0.8, C.heal, C.panelDeep, C.hair)
  Draw.bar(bx, y + 24, 160, 12, 0.35, C.blood, C.panelDeep, C.hair)
  Draw.text("Draw.bar (pct)", bx, y + 42, C.fainter, Theme.ui(9))
  -- divider (Draw.divider).
  local dx = x + 480
  Draw.divider(dx + 120, y + 16, 240, C.gold, 1)
  Draw.text("Draw.divider", dx + 60, y + 42, C.fainter, Theme.ui(9))
  return 64
end

function Screen:drawRigs(x, y, w)
  local box = 64
  for i, id in ipairs(self.rigIds) do
    local bx = x + (i - 1) * (box + 24)
    Draw.rect(bx, y, box, box, C.panelDeep, C.line, 1)
    MiniRig.draw(self._view, id, self.palette, bx, y, box, box, 1)
    Draw.textC(id, bx + box / 2, y + box + 4, C.fainter, Theme.ui(8))
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
  if i then -- saut vers la section/entrée
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
