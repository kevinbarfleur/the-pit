-- src/scenes/frameforge.lua
-- FRAME FORGE (écran-showcase dev) — reproduit EN JEU le kit « nightmare forge » (src/ui/forge.lua, port
-- de docs/pixel-art/forge-px.js), pour que Kévin juge le feel en lançant `love .`. Pas d'intégration dans
-- Frame.draw ici : on valide d'abord le LOOK. Calqué sur les sections du prototype .dc.html :
--   01 LES BOUTONS-YEUX  : DESCEND repos/survol/clic + SEALED(désactivé) + un « ENTER THE PIT » LIVE dont
--                          les yeux SUIVENT le curseur ; rangée ECO (REROLL/LEVEL +coût) ; rangée ICON live.
--   02 RESSOURCES        : 3 orbes (Vitae/Mana/Essence) glissables à la verticale ; jauges saine/affligée/critique.
--   03 CADRES & CARTES    : panneau 9-slice (GRIMOIRE, respire+œil), infobulle, cartes de relique repos/sélection,
--                          divider, bannières VICTORY/DEFEAT.
--   04 ATOMES            : gemme inerte/éveillée/live-clic, anneau-œil (sceau), 5 pips de type, pips de niveau 1-3.
-- [tab] cycle l'accent (gold/blood/bile/violet) ; [m] ou clic BACK -> menu.
--
-- Chaque cellule = un WIDGET Forge (Image+ImageData alloués UNE FOIS, cache par taille) re-rendu chaque
-- frame (le tampon FFI est réécrit, jamais de newImage/frame). Dessiné en ESPACE DESIGN à scale ENTIER
-- PX=4. Souris VIRTUELLE (0..320) -> design (×4) -> art-space (÷PX) pour le hit-test ET le gaze des yeux.
-- daChrome=true. Headless : Forge no-op proprement -> construct/update/draw sans crash.

local Theme = require("src.ui.theme")
local Draw = require("src.ui.draw")
local Forge = require("src.ui.forge")
local Ambient = require("src.fx.ambient")
local T = require("src.core.i18n").t

local Frameforge = {}
Frameforge.__index = Frameforge

local C = Theme.c
-- PX par défaut des widgets de DÉMO non-héros (orbe/jauge/panneau/carte… authorés à leur taille d'art) :
-- on les garde à 4 pour conserver leur empreinte écran. SEULS les BOUTONS-HÉROS utilisent le PX TUNABLE
-- (défaut 2 = densité créatures) -> c'est sur eux que la finesse de pixel se juge (acceptance test).
local PX = 4

-- Données de démo (port des constantes du .dc.html).
local RELICS = {
  { name = "Bloodstone", fam = "flesh", effect = "+15% lifesteal", flavor = '"It drinks first."' },
  { name = "Drowned Coin", fam = "abyss", effect = "steal 2 gold/kill", flavor = '"Wrong change."' },
}
local TOOLTIP_LINES = {
  { txt = "ASH-MAW", gold = true, gap = 11, size = 9 },
  { txt = "HP70 DMG6 CD6s", color = { 154, 138, 114 }, gap = 11, size = 8 },
  { txt = "Each hit ignites.", color = { 138, 125, 102 }, size = 8 },
}
local GAUGE_SEGS_AFFL = {
  { frac = 0.22, color = Forge.AFFL.poison.c, bmp = Forge.AFFL.poison.bmp },
  { frac = 0.12, color = Forge.AFFL.burn.c, bmp = Forge.AFFL.burn.bmp },
}
local GAUGE_SEGS_CRIT = { { frac = 0, color = Forge.AFFL.bleed.c, bmp = Forge.AFFL.bleed.bmp } }

local ACCENT_CYCLE = { "gold", "blood", "bile", "violet" }

-- ── Cellule : { x, y, aw, ah, cap, widget, drawFn(buf,aw,ah,t), interactive?, st? }. ──
-- x,y = coin haut-gauche en ESPACE DESIGN ; la cellule occupe aw*PX × ah*PX design px.
local function newCell(x, y, aw, ah, cap)
  return { x = x, y = y, aw = aw, ah = ah, cap = cap, widget = Forge.newWidget(aw, ah) }
end

-- ── TUNER DE TAILLE (banc d'essai vivant) — l'état vit DANS la scène, jamais dans forge.lua (le kit
-- reçoit juste des tailles en paramètres). Kévin cycle le paramètre sélectionné et l'augmente/diminue en
-- direct ; les boutons-héros LIVES se re-bakent (l'Image cachée est ré-allouée car la taille change ses
-- dimensions). DÉPART MODÉRÉ (entre « trop serré » et « trop gros ») : il affine, puis nous envoie les
-- chiffres finaux à figer comme défauts de prod.
-- PX (densité écran) est AUSSI tunable : 2 = fin (densité créatures, DÉFAUT), 3, 4 = gros. Les autres
-- params sont en ART-PIXELS (à PX=2 un bouton de 80 art = 160 px écran -> petit, lisible, détaillé).
local TUNE_PARAMS = {
  { key = "px",     label = "PX",    min = 2,  max = 4,   step = 1 },
  { key = "bw",     label = "BTN-W", min = 48, max = 160, step = 4 },
  { key = "bh",     label = "BTN-H", min = 16, max = 48,  step = 2 },
  { key = "fontSz", label = "FONT",  min = 6,  max = 12,  step = 1 },
  { key = "pad",    label = "PAD",   min = 0,  max = 12,  step = 1 },
  { key = "eyeR",   label = "EYE",   min = 3,  max = 14,  step = 1 },
}

function Frameforge.new(palette, vw, vh, host)
  local self = setmetatable({
    palette = palette, vw = vw, vh = vh, host = host, t = 0,
    daChrome = true,
    titleKey = "menu.frameforge",
    hintKey = "ui.empty",
    ambient = Ambient.new(11),
    cells = {},
    tuned = {}, -- cellules-héros pilotées par le tuner (re-bakées à chaque changement de taille)
    -- DÉFAUTS « small-first, dense » : PX=2 (granularité créatures) ; bouton 108×30 art = 216×60 px écran
    -- (petit CTA, gouttières assez larges pour de GROS yeux) ; font 8 ; padding 5 ; œil de référence 8 art
    -- (≈16 px écran) -> une NUÉE de gros yeux blancs/ronds, éparpillés, qui s'ouvrent et regardent au survol.
    tune = { px = 2, bw = 108, bh = 30, fontSz = 8, pad = 5, eyeR = 8 },
    tuneSel = 1, -- index du paramètre sélectionné (TUNE_PARAMS)
    accentIdx = 1,
    page = 1, pages = 2,
    backRect = { x = 1280 - 150, y = 24, w = 122, h = 34 },
    backHover = false,
    mx = 640, my = 360,
  }, Frameforge)
  Forge.setAccent(ACCENT_CYCLE[self.accentIdx])
  self:build()
  return self
end

-- Le kit rendu à PX=4 occupe BEAUCOUP de place (une carte de relique = 46×56 art -> 184×224 design).
-- 1280×720 ne tient pas 4 sections empilées sans chevauchement -> on étale sur 2 PAGES (cf. self.page,
-- bascule [space]). Chaque page = 2 sections aérées. Le titre/aide/BACK sont communs aux 2 pages.
function Frameforge:build()
  local cells = self.cells
  -- add(page, cell) : marque la cellule sur sa page.
  local function add(page, c) c.page = page; cells[#cells + 1] = c; return c end
  -- curseur design -> art-space d'une cellule (pour le gaze des yeux).
  -- gaze en coords ART de la cellule : on divise par le PX D'AFFICHAGE de CETTE cellule (c.px), car les
  -- boutons-héros peuvent être blités à un PX tuné différent du PX par défaut des autres widgets.
  local function gazeOf(c) local p = c.px or PX; return { (self.mx - c.x) / p, (self.my - c.y) / p } end

  -- ════════════════ PAGE 1 — 01 EYE-BUTTONS (tunable) + 02 RESOURCES ════════════════
  -- Les CTA-héros LISENT self.tune (BW/BH/FONT/PAD/EYE) et se RE-BAKENT quand une valeur change (cf.
  -- rebuildTuned). Cadre FIN (frameTh=2) pour laisser respirer label + yeux. REPOS : œil fermé (plaque
  -- nette) ; SURVOL : œil s'ouvre + pupille qui suit le curseur. RAPPEL : 1 px art = PX=4 px design.
  local BFTH = 2
  local TY = 156      -- ligne des DESCEND
  local TY2 = TY + 132 -- ligne de ENTER THE PIT

  -- Fabrique un bouton-œil TUNABLE : registre dans self.tuned avec un rebuild() qui ré-alloue le widget
  -- à la taille courante (la taille change les dimensions de l'ImageData -> on NE peut PAS réutiliser
  -- l'ancien tampon) et régénère les yeux. layout(i) -> (x, w) recalcule la position selon BW courant.
  local function tunedButton(slot, label, seed, disabled, cap)
    local cell = add(1, { x = 96, y = TY, aw = 1, ah = 1, cap = cap, page = 1 })
    if not disabled then
      cell.interactive = true
      cell.st = { hover = 0, active = 0, glow = 0, press = 0, eyeOpen = 0 }
      cell.ease = Forge.easeBtn
    end
    cell.rebuild = function()
      local tn = self.tune
      local w, h, sz = tn.bw, tn.bh, tn.fontSz
      -- "ENTER THE PIT" (slot 0) est plus LARGE (label long) et occupe sa propre ligne.
      if slot == 0 then w = math.max(tn.bw + 44, 120); h = tn.bh + 4 end
      cell.aw, cell.ah, cell.px = w, h, tn.px
      cell.widget = Forge.newWidget(w, h) -- RÉ-ALLOCATION (taille changée -> nouvelle ImageData/Image)
      local eyes = Forge.genEyes(w, h - Forge.DROP, seed, label, sz,
        { frameTh = BFTH, pad = tn.pad, eyeR = tn.eyeR })
      -- position : DESCEND/SEALED en rangée (slots 1..3) ; ENTER THE PIT (slot 0) en dessous, à gauche.
      if slot == 0 then
        cell.x, cell.y = 96, TY2
      else
        local step = w * tn.px + 24
        cell.x, cell.y = 96 + (slot - 1) * step, TY
      end
      if disabled then
        cell.drawFn = function(buf, aw, ah, t)
          Forge.drawButton(buf, aw, ah, 0, 0, 0, 99, "SEALED", true, nil, nil, sz, t, { frameTh = BFTH })
        end
      else
        cell.drawFn = function(buf, aw, ah, t)
          local gz = (cell.st.eyeOpen > 0.05) and gazeOf(cell) or nil
          Forge.drawButton(buf, aw, ah, cell.st.press, cell.st.eyeOpen, cell.st.glow, seed,
            label, false, eyes, gz, sz, t, { frameTh = BFTH })
        end
      end
    end
    self.tuned[#self.tuned + 1] = cell
    cell.rebuild()
    return cell
  end

  -- 01 : 2 CTA « DESCEND » LIVE (hover-moi) + un SEALED (désactivé) + ENTER THE PIT (large) — tous tunables.
  tunedButton(1, "DESCEND", 12, false, "hover me -> eyes open & watch (live tuner below)")
  tunedButton(2, "DESCEND", 13, false, "live CTA")
  tunedButton(3, "SEALED", 99, true, "SEALED (disabled)")
  tunedButton(0, "ENTER THE PIT", 77, false, "LIVE - hover & move (eye tracks cursor)")

  local y = 152

  -- ECO row : REROLL/LEVEL — petites dalles UI à PX=2 (densité fine, cohérentes avec les CTA). Art 64×26
  -- -> 128×52 px écran. Placée À DROITE de ENTER THE PIT, calée pour tenir dans 1280.
  local ecoStates = { { "rest", 0, 0 }, { "hover", 0.55, 0 }, { "pressed", 0.95, 1 } }
  local EW, EPX = 64, 2
  local ecoStep = EW * EPX + 16
  local ecoX = 514
  for i, s in ipairs(ecoStates) do
    local cell = add(1, newCell(ecoX + (i - 1) * ecoStep, y + 120, EW, 26, s[1])); cell.px = EPX
    cell.drawFn = function(buf, aw, ah, t) Forge.drawEcoBtn(buf, aw, ah, s[3], s[2], 30 + i, "REROLL", 1, false, t) end
  end
  do
    local cell = add(1, newCell(ecoX + 3 * ecoStep, y + 120, EW, 26, "disabled")); cell.px = EPX
    cell.drawFn = function(buf, aw, ah, t) Forge.drawEcoBtn(buf, aw, ah, 0, 0, 40, "LEVEL", 8, true, t) end
  end
  -- ICON row (LIVE) — sous la rangée ECO, à PX=2. Art 22×22 -> 44×44 px écran (carré, lisible).
  local icons = { { "sigil", "sigil" }, { "left", "< prev" }, { "right", "next >" }, { "gear", "settings" } }
  for i, k in ipairs(icons) do
    local cell = add(1, newCell(ecoX + (i - 1) * 70, y + 200, 22, 22, k[2])); cell.px = 2
    cell.interactive = true
    cell.st = { hover = 0, active = 0, glow = 0, press = 0 }
    cell.ease = Forge.easeSmall
    cell.drawFn = function(buf, aw, ah, t) Forge.drawIconBtn(buf, aw, ah, cell.st.press, cell.st.glow, 50 + i, k[1], t) end
  end
  -- 02 RESSOURCES : orbes (drag) + jauges.
  y = 470
  local orbs = { { "Vitae", Forge.LIQ.blood, 101, 0.78 }, { "Mana", Forge.LIQ.mana, 102, 0.54 }, { "Essence", Forge.LIQ.essence, 103, 0.40 } }
  for i, p in ipairs(orbs) do
    local cell = add(1, newCell(96 + (i - 1) * 150, y, 30, 30, p[1]:lower() .. " - drag up/down"))
    cell.interactive = true; cell.drag = true; cell.st = { val = p[4] }
    cell.drawFn = function(buf, aw, ah, t) Forge.drawOrb(buf, aw, ah, cell.st.val, p[2], p[3], t) end
  end
  local gauges = { { "healthy", 0.82, nil }, { "afflicted", 0.6, GAUGE_SEGS_AFFL }, { "critical < 25%", 0.16, GAUGE_SEGS_CRIT } }
  for i, p in ipairs(gauges) do
    local cell = add(1, newCell(700, y + (i - 1) * 56, 60, 16, p[1]))
    cell.drawFn = function(buf, aw, ah, t) Forge.drawGauge(buf, aw, ah, p[2], p[3] or {}, t) end
  end

  -- ════════════════ PAGE 2 — 03 FRAMES & CARDS + 04 ATOMS ════════════════
  -- 03 : panneau + infobulle (gauche), 2 cartes de relique LARGES (texte lisible, ne clippe plus),
  --      divider + bannières (droite). Dalles élargies -> le texte respire à l'intérieur des cadres.
  y = 162
  add(2, newCell(96, y, 64, 40, "9-slice - breathes & watches")).drawFn =
    function(buf, aw, ah, t) Forge.drawPanel(buf, aw, ah, t, "GRIMOIRE") end
  add(2, newCell(96, y + 184, 62, 34, "hover sheet")).drawFn =
    function(buf, aw, ah, t) Forge.drawTooltip(buf, aw, ah, t, TOOLTIP_LINES) end
  do
    -- cartes ÉLARGIES (72×66 art -> 288×264 design) : nom/effet/flavor tiennent TOUS sans clip.
    local relicStates = { { "rest", 1 }, { "selected", 2 } }
    for i, p in ipairs(relicStates) do
      local cell = add(2, newCell(380 + (i - 1) * 320, y, 72, 66, p[1] .. " relic card"))
      cell.drawFn = function(buf, aw, ah, t) Forge.drawRelicCard(buf, aw, ah, p[1], RELICS[p[2]], t) end
    end
  end
  add(2, newCell(96, y + 290, 90, 6, "divider - pulse")).drawFn =
    function(buf, aw, ah, t) Forge.drawDivider(buf, aw, ah, t) end
  do
    local banners = { { "VICTORY", "win" }, { "DEFEAT", "defeat" } }
    for i, p in ipairs(banners) do
      add(2, newCell(440 + (i - 1) * 380, y + 290, 78, 24, p[2])).drawFn =
        function(buf, aw, ah, t) Forge.drawBanner(buf, aw, ah, p[1], p[2], t) end
    end
  end
  -- 04 ATOMES : gemmes / sceau / pips de type / pips de niveau.
  y = 470
  add(2, newCell(96, y, 14, 14, "gem inert")).drawFn = function(buf, aw, ah, t) Forge.drawGem(buf, aw, ah, false, t) end
  add(2, newCell(96 + 80, y, 14, 14, "gem awake")).drawFn = function(buf, aw, ah, t) Forge.drawGem(buf, aw, ah, true, t) end
  do
    local cell = add(2, newCell(96 + 160, y, 14, 14, "LIVE - click to toggle"))
    cell.interactive = true; cell.gemToggle = true; cell.st = { on = false }
    cell.drawFn = function(buf, aw, ah, t) Forge.drawGem(buf, aw, ah, cell.st.on, t) end
  end
  add(2, newCell(96 + 280, y - 2, 18, 18, "eye-ring seal")).drawFn =
    function(buf, aw, ah, t) Forge.drawEyeRing(buf, aw, ah, 0.9, 0.7, t, 3) end
  local fams = { "flesh", "order", "bone", "arcane", "abyss" }
  for i, f in ipairs(fams) do
    add(2, newCell(96 + (i - 1) * 60, y + 120, 12, 12, f)).drawFn =
      function(buf, aw, ah, t) Forge.drawTypePip(buf, aw, ah, f, t) end
  end
  for n = 1, 3 do
    add(2, newCell(500 + (n - 1) * 90, y + 120, 3 + n * 5, 8, "level " .. n)).drawFn =
      function(buf, aw, ah, t) Forge.drawLevelPips(buf, aw, ah, n, t) end
  end
end

-- Re-bake TOUS les boutons-héros tunables à la taille courante (self.tune). Appelé à chaque changement
-- de valeur du tuner : la taille change les dimensions de l'ImageData -> on ré-alloue le widget (pas de
-- réutilisation d'un tampon de mauvaise taille = pas d'image périmée). No-op headless (newWidget no-op).
function Frameforge:rebuildTuned()
  for _, c in ipairs(self.tuned) do
    if c.rebuild then c.rebuild() end
  end
end

-- Ajuste le paramètre de tuner sélectionné de `dir` pas (clampé), puis re-bake les boutons.
function Frameforge:adjustTune(dir)
  local p = TUNE_PARAMS[self.tuneSel]
  if not p then return end
  local v = (self.tune[p.key] or p.min) + dir * p.step
  if v < p.min then v = p.min elseif v > p.max then v = p.max end
  self.tune[p.key] = v
  self:rebuildTuned()
end

function Frameforge:update(frameDt)
  self.t = self.t + frameDt / 60 -- dt en SECONDES (le kit est restless, animé chaque frame).
  self.ambient:update(frameDt)
  for _, c in ipairs(self.cells) do
    if c.page == self.page and c.interactive and c.ease then c.ease(c.st) end
  end
end

function Frameforge:drawBack(view)
  Draw.begin(view)
  self.ambient:draw("grimoire")
  Draw.finish()
end

function Frameforge:drawWorld() end

-- Lecture du TUNER (page 1) : une ligne « libellé valeur » par paramètre ; le param SÉLECTIONNÉ est doré
-- (avec des chevrons). Sous la rangée des boutons-héros (zone libre). Texte Silkscreen net.
function Frameforge:drawTuner()
  local tn = self.tune
  -- panneau encadré en BAS-DROITE de la page 1 (zone libre, sous le titre, à droite des ressources).
  local px, py, pw, ph = 980, 470, 290, 150
  Draw.rect(px, py, pw, ph, C.panelDeep, C.gold, 1)
  local x, ty = px + 14, py + 14
  Draw.text("LIVE TUNER", x, ty, C.title, Theme.uiBold(13))
  Draw.text("tune the hero CTA, then send the numbers", x, ty + 18, C.faint, Theme.ui(9))
  local font = Theme.ui(12)
  ty = ty + 40
  for i, p in ipairs(TUNE_PARAMS) do
    local hot = (i == self.tuneSel)
    local rowY = ty + (i - 1) * 16
    local lab = (hot and "> " or "  ") .. p.label
    Draw.text(lab, x, rowY, hot and C.goldBright or C.body, font)
    Draw.textR(tostring(tn[p.key]), px + pw - 14, rowY, hot and C.goldBright or C.body, font)
  end
  Draw.text("[t] param   up/down (+/-) adjust", x, ty + #TUNE_PARAMS * 16 + 4, C.muted, Theme.ui(9))
end

function Frameforge:drawOverlay(view)
  Draw.begin(view)

  Draw.textC(T("menu.frameforge"), Draw.W / 2, 28, C.title, Theme.display(28))
  Draw.textC("nightmare forge UI kit -- hard brass bevels + a body-horror layer (port of forge-px.js)",
    Draw.W / 2, 66, C.faint, Theme.ui(11))
  Draw.textC("[tab] accent: " .. string.upper(ACCENT_CYCLE[self.accentIdx])
    .. "    [space] page " .. self.page .. "/" .. self.pages
    .. "    hover/click the live widgets    [m] / BACK to return",
    Draw.W / 2, 82, C.dim, Theme.ui(11))

  -- Entêtes de section (par page).
  if self.page == 1 then
    Draw.text("01  EYE-BUTTONS", 96, 142, C.muted, Theme.uiBold(11))
    Draw.text("02  RESOURCES", 96, 444, C.muted, Theme.uiBold(11))
  else
    Draw.text("03  FRAMES & CARDS", 96, 142, C.muted, Theme.uiBold(11))
    Draw.text("04  ATOMS", 96, 444, C.muted, Theme.uiBold(11))
  end

  for _, c in ipairs(self.cells) do
    if c.page == self.page then
      local p = c.px or PX
      local img = Forge.render(c.widget, c.drawFn, self.t)
      Forge.blit(img, c.x, c.y, p) -- blit au PX de la cellule (héros tunés) ou au PX par défaut
      if c.cap then Draw.text(c.cap, c.x, c.y + c.ah * p + 2, C.ghost, Theme.ui(8)) end
    end
  end

  -- ── TUNER (page 1) : lecture des valeurs + paramètre sélectionné surligné + aide des touches. ──
  if self.page == 1 then self:drawTuner() end

  local b = self.backRect
  Draw.rect(b.x, b.y, b.w, b.h, C.panelDeep, self.backHover and C.gold or C.hair, 1)
  Draw.textC("< BACK [m]", b.x + b.w / 2, b.y + (b.h - 11) / 2,
    self.backHover and C.inkBright or C.body, Theme.uiBold(12))

  Draw.finish()
end

local function inCell(c, dx, dy)
  local p = c.px or PX
  return dx >= c.x and dx <= c.x + c.aw * p and dy >= c.y and dy <= c.y + c.ah * p
end

function Frameforge:mousemoved(vx, vy)
  local dx, dy = vx * 4, vy * 4
  self.mx, self.my = dx, dy
  for _, c in ipairs(self.cells) do
    if c.page == self.page and c.interactive and c.st then
      local inside = inCell(c, dx, dy)
      if c.st.hover ~= nil then c.st.hover = inside and 1 or 0; if not inside then c.st.active = 0 end end
      if c.drag and inside and love.mouse and love.mouse.isDown and love.mouse.isDown(1) then
        c.st.val = Forge.clamp(1 - (dy - c.y) / (c.ah * (c.px or PX)))
      end
    end
  end
  local b = self.backRect
  self.backHover = dx >= b.x and dx <= b.x + b.w and dy >= b.y and dy <= b.y + b.h
end

function Frameforge:mousepressed(vx, vy, button)
  if button ~= 1 then return end
  local dx, dy = vx * 4, vy * 4
  local b = self.backRect
  if dx >= b.x and dx <= b.x + b.w and dy >= b.y and dy <= b.y + b.h then self:back(); return end
  for _, c in ipairs(self.cells) do
    if c.page == self.page and c.interactive and inCell(c, dx, dy) then
      if c.st.active ~= nil then c.st.active = 1 end
      if c.gemToggle then c.st.on = not c.st.on end
      if c.drag then c.st.val = Forge.clamp(1 - (dy - c.y) / (c.ah * (c.px or PX))) end
    end
  end
end

function Frameforge:mousereleased()
  for _, c in ipairs(self.cells) do
    if c.interactive and c.st and c.st.active ~= nil then c.st.active = 0 end
  end
end

function Frameforge:keypressed(key)
  if key == "m" then
    self:back()
  elseif key == "tab" then
    self.accentIdx = (self.accentIdx % #ACCENT_CYCLE) + 1
    Forge.setAccent(ACCENT_CYCLE[self.accentIdx])
  elseif key == "space" then
    self.page = (self.page % self.pages) + 1
  -- ── TUNER (page 1) : [t] cycle le paramètre, up/down ou +/- l'ajuste (re-bake live). ──
  elseif key == "t" then
    self.tuneSel = (self.tuneSel % #TUNE_PARAMS) + 1
  elseif key == "up" or key == "=" or key == "+" or key == "kp+" then
    self:adjustTune(1)
  elseif key == "down" or key == "-" or key == "kp-" then
    self:adjustTune(-1)
  elseif key == "right" then
    self:adjustTune(1)
  elseif key == "left" then
    self:adjustTune(-1)
  end
end

function Frameforge:back()
  if not self.host then return end
  self.host.scene = self.host.menu or self.host.scene
  self.host.name = "menu"
end

return Frameforge
