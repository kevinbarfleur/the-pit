-- src/scenes/grimoire.lua
-- LE GRIMOIRE — codex/COLLECTION persistant, refondu en interface TYPE POKÉDEX (2026-06) : une BARRE DE
-- FILTRES en haut + UNE grande GRILLE scrollable de cases, et la fiche détaillée au SURVOL (la MÊME carte
-- qu'en build/combat). Couvre RELIQUES + MONSTRES. Une entrée RENCONTRÉE (relique inscrite : Grimoire.isKnown ;
-- créature vue : Bestiary.isSeen) se dévoile à vie au niveau du compte (méta-progression). Les non rencontrées
-- restent voilées (silhouette « ? » assombrie façon Pokédex) — sauf MODE DEV full-unlock (read-time).
--
-- ── POURQUOI ce refactor (demande user) ──────────────────────────────────────────────────────────────
-- On remplace la liste verticale + panneau de détail persistant par : (1) une bascule primaire RELIQUES |
-- BESTIAIRE + une rangée de chips de SOUS-FILTRE (reliques : par palier band Argent/Or/Prismatique ;
-- monstres : par TYPE) ; (2) une grande grille de cases (Slot) à icône/rig centré + label ; (3) au SURVOL
-- d'une case, la FICHE flottante au curseur — relique = RelicCard, monstre = MonsterCard (le MÊME composant
-- que le build, mêmes données/visuel) -> aucun doublon, on lit la collection exactement comme en jeu.
--
-- ── RÉUTILISE (cœur de la qualité) ───────────────────────────────────────────────────────────────────
--   • cases       = atome Slot (6 états) ; visuel monstre = Critter (rendu VIVANT, comme le board/galerie),
--                   repli Rig baké (6 dédiées) ; icône relique = RelicGen.cached bakée.
--   • fiche relique = src/ui/relic_card.lua (band/fam depuis Relics + i18n) — câblage calqué sur relicpick.
--   • fiche monstre = src/render/monstercard.lua (MonsterCard.draw(view,palette,id,mx,my,t,{rig})) — câblage
--                   calqué sur build:drawTooltip (rig d'aperçu animé -> le portrait respire).
--   • filtres     = chips (Chip) + bascule (Button) ; layout des chips = wrap (idiome playground).
--   • JUICE       = Feel par case (lift/glow au survol) + bascule/chips/back.
--   • scroll      = scissor + molette + thumb + clamp (idiome designsystem/grimoire).
--
-- ── CONTRAT (inchangé : routage + scène) ─────────────────────────────────────────────────────────────
-- Couche RENDER (love.graphics) en ESPACE DESIGN 1280×720. daChrome=true. new/refresh/setTab/rebuildRows/
-- update/drawBack/drawWorld/drawOverlay + souris (mousemoved/mousepressed/wheelmoved) + keypressed.
-- [esc]/[g] -> retour menu (main). GOLDEN-NEUTRE (RENDER pur, aucune touche SIM).

local Theme = require("src.ui.theme")
local Draw = require("src.ui.draw")
local Button = require("src.ui.button")    -- bascule RELIQUES/BESTIAIRE (secondary)
local Nav = require("src.ui.nav")          -- bouton retour homogène
local Slot = require("src.ui.slot")        -- cadre de case (vignette)
local Chip = require("src.ui.chip")        -- chips de sous-filtre (band / type)
local Feel = require("src.ui.feel")        -- JUICE : survol des cases / bascule / chips / back
local Ambient = require("src.fx.ambient")
local Relics = require("src.data.relics")
local Grimoire = require("src.core.grimoire")
local Bestiary = require("src.core.bestiary")
local RelicGen = require("src.gen.relicgen")
local RelicAnim = require("src.render.relic_anim") -- rendu ANIMÉ des icônes de reliques (grille + fiche)
local Rig = require("src.core.rig")
local Creatures = require("src.data.creatures")
local Units = require("src.data.units")
local CreatureGen = require("src.gen.creaturegen")
local Critter = require("src.render.critter") -- rendu VIVANT (mêmes créatures animées que le board)
local Rarity = require("src.gen.rarity")
local RelicCard = require("src.ui.relic_card")   -- fiche relique (band/fam) — survol
local MonsterCard = require("src.render.monstercard") -- fiche monstre (MÊME carte que build) — survol
local CardGlossary = require("src.ui.card_glossary")
local MechanicsText = require("src.ui.mechanics_text")
local T = require("src.core.i18n").t

local C = Theme.c

local Screen = {}
Screen.__index = Screen

-- Emblème (FAMILLE de gemme) par relique : teinte du losange de RelicCard. Aligné sur relicpick/build
-- (clés ∈ Theme.types). Sans entrée -> "bone" (neutre).
local RELIC_FAM = {
  bloodstone = "flesh", carapace = "bone", aegis = "order",
  kings_bowl = "abyss", ember_heart = "arcane", weeping_nail = "flesh", grave_cap = "abyss",
  usurers_ledger = "order", tithe_bowl = "order", paupers_boon = "order",
  grave_robbers_cut = "bone", carrion_ledger = "bone",
  black_summons = "abyss", beggars_lantern = "order",
  blood_banner = "flesh", seers_mark = "abyss", carrion_feast = "bone", second_plague = "abyss",
  tide_caller = "order", bait_lantern = "flesh",
  echo_crown = "order", gravediggers_due = "bone", splitting_maw = "flesh",
}

-- ── MISE EN PAGE (espace design 1280×720) — collection à gauche, fiche persistante à droite. ──
local TITLE_Y = 28
local TAB_Y, TAB_W, TAB_H = 78, 220, 34   -- bascule RELIQUES | BESTIARY
local CHIP_Y = 126                         -- 1re rangée de chips de sous-filtre
local CHIP_H, CHIP_GAP, CHIP_PAD = 24, 8, 10
local GRID_X0 = 40                         -- marge latérale de la grille
local GRID_TOP_FALLBACK = 176             -- haut de la grille si une seule rangée de chips (recalculé)
local GRID_BOTTOM = 690
local COLS = 5                             -- colonne de collection à gauche ; détail fixe à droite.
local CELL_W, CELL_H = 138, 124            -- pitch d'une case (slot + label)
local TILE = 92                            -- côté de la vignette Slot dans la case
local CELL_PADX = (CELL_W - TILE) / 2
local DETAIL_X = 770
local DETAIL_W = Draw.W - DETAIL_X - 40
local DETAIL_CARD_W = 288
local RELIC_CARD_W = 300

local function ptIn(px, py, x, y, w, h) return px >= x and px <= x + w and py >= y and py <= y + h end

function Screen.new(palette, vw, vh, host)
  local self = setmetatable({
    vw = vw, vh = vh, t = 0, host = host, palette = palette,
    daChrome = true,
    titleKey = "scene.build", hintKey = "ui.empty",
    tab = "relics",
    -- SOUS-FILTRES par FACETTE (sélection unique par facette ; combinées en ET). Reliques : 1 facette (palier
    -- band). Bestiaire : 2 facettes indépendantes -> TYPE *et* TIER (l'user veut filtrer/trier par tier).
    filter = { relics = { band = "all" }, bestiary = { type = "all", tier = "all" } },
    hover = nil, scroll = 0,
    selected = { relics = nil, bestiary = nil },
    selectedLevel = 1,
    levelHover = nil,
    lastCardBox = nil,
    mx = -100, my = -100, -- souris en ESPACE DESIGN (survol cases + boutons)
    gridTop = GRID_TOP_FALLBACK,
    ambient = Ambient.new(5),
  }, Screen)
  Feel.reset() -- repart au repos en (re)entrant

  -- ENTRÉES RELIQUES (métadonnée seule ; l'icône bakée est tirée à la volée via RelicGen.cached).
  self.relicEntries = {}
  for _, id in ipairs(Relics.order) do
    self.relicEntries[#self.relicEntries + 1] = { id = id, band = Relics[id].band or "mid", tier = Relics[id].tier or 1 }
  end

  -- ENTRÉES BESTIAIRE : un rig par unité, EXACTEMENT comme le combat (6 dédiées sinon génération procédurale).
  self.beastEntries = {}
  for _, id in ipairs(Units.order) do
    local spec = Units[id] or {}
    local handmade = Creatures[id] ~= nil
    local def = handmade and Creatures[id]
      or CreatureGen.cached({ id = id, type = spec.type, family = spec.family, arch = spec.arch, effects = spec.effects, bodyplan = spec.bodyplan, rank = spec.rank })
    local char = Rig.new(def, palette); char.facing = 1
    self.beastEntries[#self.beastEntries + 1] = {
      id = id, char = char, type = spec.type or "flesh", rank = spec.rank, bodyplan = spec.bodyplan,
    }
  end

  -- FICHE monstre : rig d'aperçu ANIMÉ par unité (le portrait de MonsterCard respire, comme en build). On le
  -- réutilise pour la créature de la case ET pour la fiche au survol (1 rig animé partagé / unité).
  self.previewRigs = {}
  for _, e in ipairs(self.beastEntries) do self.previewRigs[e.id] = e.char end

  self:refresh()
  return self
end

-- (Re)lit l'état connu/vu (la persistance change entre deux ouvertures ; le toggle dev aussi) + (re)trie.
function Screen:refresh()
  self.knownRelics, self.seenBeasts = 0, 0
  for _, e in ipairs(self.relicEntries) do if Grimoire.isKnown(e.id) then self.knownRelics = self.knownRelics + 1 end end
  for _, e in ipairs(self.beastEntries) do if Bestiary.isSeen(e.id) then self.seenBeasts = self.seenBeasts + 1 end end
  self:rebuildChips()
  self:rebuildCells()
end

function Screen:ensureSelection()
  local current = self.selected and self.selected[self.tab]
  for _, cell in ipairs(self.cells or {}) do
    if cell.on and cell.e and cell.e.id == current then return end
  end
  self.selected[self.tab] = nil
  for _, cell in ipairs(self.cells or {}) do
    if cell.on and cell.e then
      self.selected[self.tab] = cell.e.id
      if self.tab == "bestiary" then self.selectedLevel = 1 end
      return
    end
  end
end

function Screen:selectedCell()
  local id = self.selected and self.selected[self.tab]
  if not id then return nil end
  for _, cell in ipairs(self.cells or {}) do
    if cell.e and cell.e.id == id then return cell end
  end
  return nil
end

-- Construit les CHIPS de sous-filtre de l'onglet courant. Chaque chip porte sa FACETTE (sélection unique PAR
-- facette ; le bestiaire en a deux -> elles se combinent en ET). Une facette = une RANGÉE précédée d'un petit
-- label-titre (gravé court). Reliques : 1 facette (band palier). Bestiaire : TYPE + TIER (rangs présents),
-- chaque chip de tier TEINTÉ de sa couleur de rareté (= Rarity.frame) -> le tier se lit AU CHIP comme au cadre.
--   chip = { facet, key, label, color }. "all" = tout passe pour cette facette.
-- Les positions (wrap) sont calculées ici (idiome playground:layoutChips) -> hit-test direct.
function Screen:rebuildChips()
  -- décrit les facettes de l'onglet : { facet, titleKey, chips={...} } ; le "ALL" de tête est ajouté par facette.
  local facets = {}
  if self.tab == "relics" then
    local BANDS = { { "low", "grimoire.band_low", C.steel },
                    { "mid", "grimoire.band_mid", C.gold },
                    { "high", "grimoire.band_high", C.rot } }
    local seen = {}
    for _, e in ipairs(self.relicEntries) do seen[e.band] = true end
    local chips = {}
    for _, b in ipairs(BANDS) do if seen[b[1]] then chips[#chips + 1] = { key = b[1], label = T(b[2]), color = b[3] } end end
    facets[#facets + 1] = { facet = "band", titleKey = "grimoire.facet_band", chips = chips }
  else
    -- FACETTE TYPE (la famille mécanique) — gardée car épurée (1 rangée).
    local TORDER = { "flesh", "order", "bone", "arcane", "abyss" }
    local seenT = {}
    for _, e in ipairs(self.beastEntries) do seenT[e.type] = true end
    local tchips = {}
    for _, ty in ipairs(TORDER) do
      if seenT[ty] then tchips[#tchips + 1] = { key = ty, label = (T("type." .. ty)):upper(), color = Theme.type(ty).color } end
    end
    facets[#facets + 1] = { facet = "type", titleKey = "grimoire.facet_type", chips = tchips }
    -- FACETTE TIER (le RANG) — l'ajout demandé : chips ascendants, TEINTÉS de la couleur de rareté (cadre).
    local seenR = {}
    for _, e in ipairs(self.beastEntries) do if e.rank then seenR[Rarity.clamp(e.rank)] = true end end
    local rchips = {}
    for r = 1, 5 do
      if seenR[r] then rchips[#rchips + 1] = { key = tostring(r), label = T(Rarity.tierNameKey(r)), color = Rarity.tierBright(r) } end
    end
    facets[#facets + 1] = { facet = "tier", titleKey = "grimoire.facet_tier", chips = rchips }
  end

  -- pose : par facette -> un label-titre court (gravé) puis [ALL][chips…] qui s'enroulent dans la largeur. Le
  -- bas de la dernière rangée = haut de grille (air conscient). Chaque chip mémorise (facet,key) -> hit-test.
  local font = Theme.label(10)
  local titleFont = Theme.ui(9)
  local maxX = GRID_X0 + COLS * CELL_W
  self.chipRects, self.chipLabels = {}, {}
  local y = CHIP_Y
  for fi, fac in ipairs(facets) do
    -- titre de facette à gauche, baseline alignée sur la rangée de chips.
    local tlab = T(fac.titleKey)
    local tw = (titleFont and titleFont:getWidth(tlab)) or (#tlab * 6)
    self.chipLabels[#self.chipLabels + 1] = { text = tlab, x = GRID_X0, y = y + (CHIP_H - 9) / 2 + 1 }
    local x = GRID_X0 + tw + 12
    local rowStart = x
    local entries = { { key = "all", label = T("grimoire.filter_all") } }
    for _, c in ipairs(fac.chips) do entries[#entries + 1] = c end
    for _, ch in ipairs(entries) do
      local w = (font and font:getWidth(ch.label) or #ch.label * 6) + CHIP_PAD * 2
      if x > rowStart and x + w > maxX then x = rowStart; y = y + CHIP_H + CHIP_GAP end
      self.chipRects[#self.chipRects + 1] = { facet = fac.facet, key = ch.key, label = ch.label, color = ch.color, x = x, y = y, w = w, h = CHIP_H }
      x = x + w + CHIP_GAP
    end
    if fi < #facets then y = y + CHIP_H + CHIP_GAP end -- rangée suivante pour la facette d'après
  end
  self.gridTop = y + CHIP_H + 18 -- la grille démarre sous la dernière rangée de chips (air conscient)
end

-- Filtre (toutes facettes en ET) + ordonne l'onglet courant -> self.cells. Inconnus regroupés EN FIN.
-- Bestiaire : tri par TIER ASCENDANT (puis ordre de data) dans chaque groupe -> le rang se lit aussi à la pile.
function Screen:rebuildCells()
  local f = self.filter[self.tab]
  local src, revealed, byTier
  if self.tab == "relics" then
    src = self.relicEntries
    revealed = function(e) return Grimoire.isKnown(e.id) end
    byTier = false
  else
    src = self.beastEntries
    revealed = function(e) return Bestiary.isSeen(e.id) end
    byTier = true -- l'user veut VOIR/trier par tier : pile ascendante
  end

  -- prédicat = chaque facette active doit matcher ("all" -> facette ignorée). Combinées en ET.
  local function keep(e)
    if self.tab == "relics" then
      return f.band == "all" or e.band == f.band
    else
      local okT = (f.type == "all") or (e.type == f.type)
      local okR = (f.tier == "all") or (Rarity.clamp(e.rank) == tonumber(f.tier))
      return okT and okR
    end
  end

  -- ORDRE : RÉVÉLÉS d'abord puis voilés (façon Pokédex). Bestiaire -> clé de tri (tier, idx) ASCENDANTE ;
  -- reliques -> ordre de data. Tri STABLE (clé composite, jamais d'égalité ambiguë).
  local known, unknown = {}, {}
  for i, e in ipairs(src) do
    if keep(e) then
      local cell = { e = e, on = revealed(e), idx = i }
      if cell.on then known[#known + 1] = cell else unknown[#unknown + 1] = cell end
    end
  end
  if byTier then
    local function cmp(a, b)
      local ra, rb = Rarity.clamp(a.e.rank), Rarity.clamp(b.e.rank)
      if ra ~= rb then return ra < rb end
      return a.idx < b.idx
    end
    table.sort(known, cmp); table.sort(unknown, cmp)
  end
  local cells = {}
  for _, cell in ipairs(known) do cells[#cells + 1] = cell end
  for _, cell in ipairs(unknown) do cells[#cells + 1] = cell end
  self.cells = cells
  self.scroll = 0
  self:ensureSelection()
end

-- Géométrie de défilement.
function Screen:rows() return math.ceil(#(self.cells or {}) / COLS) end
function Screen:gridViewH() return GRID_BOTTOM - self.gridTop end
function Screen:contentH() return self:rows() * CELL_H end
function Screen:maxScroll() return math.max(0, self:contentH() - self:gridViewH()) end

-- Coin haut-gauche de la case d'index local i (1-based), AVANT scroll. Grille centrée dans la largeur.
function Screen:cellOrigin(i)
  local c = (i - 1) % COLS
  local r = math.floor((i - 1) / COLS)
  local gridW = COLS * CELL_W
  local x0 = GRID_X0 + math.floor((COLS * CELL_W - gridW) / 2) -- (centré : ici no-op, prêt si COLS change)
  local x = x0 + c * CELL_W
  local y = self.gridTop + r * CELL_H - self.scroll
  return x, y
end

function Screen:update(frameDt)
  self.t = self.t + frameDt
  Feel.update(frameDt)
  -- survol de la bascule / chips / back (glow/lift). Les rects sont posés en draw (1re frame couverte par new).
  Feel.hover("grim.tab.relics", self._tabRects and self._tabRects.relics and ptIn(self.mx, self.my, self._tabRects.relics.x, self._tabRects.relics.y, self._tabRects.relics.w, self._tabRects.relics.h) or false)
  Feel.hover("grim.tab.bestiary", self._tabRects and self._tabRects.bestiary and ptIn(self.mx, self.my, self._tabRects.bestiary.x, self._tabRects.bestiary.y, self._tabRects.bestiary.w, self._tabRects.bestiary.h) or false)
  for _, r in ipairs(self.chipRects or {}) do
    Feel.hover("grim.chip." .. r.facet .. "." .. r.key, ptIn(self.mx, self.my, r.x, r.y, r.w, r.h))
  end
  -- JUICE des cases : la case survolée monte/glow (Feel). Une clé stable par index VISIBLE.
  for i = 1, #(self.cells or {}) do Feel.hover("grim.cell." .. i, self.hover == i) end
  self:updateLevelHover()
  for lvl = 1, 3 do Feel.hover("grim.level." .. lvl, self.levelHover == lvl) end
  -- anim idle des rigs du bestiaire (comme la galerie) — la créature de chaque case respire.
  for _, e in ipairs(self.beastEntries) do Rig.update(e.char, self.t, frameDt) end
end

function Screen:drawBack(view)
  Draw.begin(view)
  self.ambient:draw("grimoire")
  Draw.finish()
end

function Screen:drawWorld() end

function Screen:drawOverlay(view)
  Draw.begin(view)

  -- En-tête : titre gravé (Cinzel) + indice discret À DROITE du titre (même ligne, baseline basse -> aucun
  -- chevauchement avec la bascule en dessous) + retour homogène.
  local titleFont = Theme.title(34)
  Draw.text(T("grimoire.title"), GRID_X0, TITLE_Y, C.ink, titleFont)
  local titleW = (titleFont and titleFont:getWidth(T("grimoire.title"))) or 380
  Draw.text(T("grimoire.hint_select"), GRID_X0 + titleW + 20, TITLE_Y + 22, C.ink4, Theme.label(11))
  self.backRect = Nav.back(view, T("grimoire.back"), { mx = self.mx, my = self.my, id = "grim.back" })

  -- Bascule RELIQUES | BESTIARY (deux boutons secondary, l'actif forcé en survol + liseré doré) + compteur.
  self._tabRects = {}
  self:drawTab("relics", T("grimoire.tab_relics"), GRID_X0, self.knownRelics, #self.relicEntries)
  self:drawTab("bestiary", T("grimoire.tab_bestiary"), GRID_X0 + TAB_W + 14, self.seenBeasts, #self.beastEntries)

  -- Chips de SOUS-FILTRE (band / type) — sélection unique ; l'actif = liseré plein de sa couleur.
  self:drawChips()

  -- GRILLE scrollable (cases clippées).
  Draw.scissor(view, GRID_X0 - 4, self.gridTop - 4, COLS * CELL_W + 8, self:gridViewH() + 8)
  for i, cell in ipairs(self.cells) do
    local x, y = self:cellOrigin(i)
    if y + CELL_H >= self.gridTop - 2 and y <= GRID_BOTTOM + 2 then self:drawCell(view, i, cell, x, y) end
  end
  Draw.noScissor()

  -- Barre de défilement (thumb laiton).
  local maxS = self:maxScroll()
  if maxS > 0 then
    local vh = self:gridViewH()
    local thumbH = math.max(28, vh * vh / self:contentH())
    local ty = self.gridTop + (vh - thumbH) * (self.scroll / maxS)
    local sbx = GRID_X0 + COLS * CELL_W + 10
    Draw.rect(sbx, self.gridTop, 3, vh, C.stone900)
    Draw.rect(sbx, ty, 3, thumbH, C.brass)
  end

  -- FICHE persistante à DROITE : clic sur une entrée connue -> sélection, plus de carte flottante au hover.
  self:drawSelectedDetail(view)

  Draw.finish()
end

-- Bascule = bouton SECONDARY. Actif -> forcé en survol (le plus clair) + liseré doré ; le compteur n/total
-- à droite (Space Mono, gold sur l'actif).
function Screen:drawTab(id, label, x, n, total)
  local active = (self.tab == id)
  self._tabRects[id] = { x = x, y = TAB_Y, w = TAB_W, h = TAB_H }
  local fs = Feel.state("grim.tab." .. id)
  Button.draw(x, TAB_Y, TAB_W, TAB_H, "secondary", label, { hover = active or fs.hover > 0.5, feel = fs })
  if active then Draw.rect(x, TAB_Y, TAB_W, TAB_H, nil, C.brass, 1) end
  Draw.textR(n .. "/" .. total, x + TAB_W - 12, TAB_Y + (TAB_H - 12) / 2 - 1,
    active and C.gold or C.ink4, Theme.labelSmall(10))
end

-- Rangées de chips de sous-filtre (une par FACETTE, précédée d'un petit titre gravé). Actif = liseré PLEIN de
-- sa couleur (band/type/tier) + label avivé ; sinon liseré sourd + label sourd. JUICE : survol = lift léger (Feel).
function Screen:drawChips()
  -- titres de facette (gravés courts, sourds) à gauche de leur rangée.
  local titleFont = Theme.ui(9)
  for _, l in ipairs(self.chipLabels or {}) do
    Draw.text(l.text, l.x, l.y, C.ink4, titleFont)
  end
  local font = Theme.label(10)
  for _, r in ipairs(self.chipRects) do
    local active = (self.filter[self.tab][r.facet] == r.key)
    local fs = Feel.state("grim.chip." .. r.facet .. "." .. r.key)
    local lift = math.floor((fs.lift or 0) + 0.5)
    local col = r.color or C.brass
    local fill = active and C.stone700 or C.stone900
    -- BORD : actif -> couleur PLEINE (liseré 2px) ; inactif -> teinte SOURDE de SA couleur (≈40%) plutôt que
    -- l'iron neutre -> chaque chip de tier/type/palier porte SA couleur même au repos (l'user veut « teinté de
    -- sa couleur de tier comme les chips de band »). "ALL" reste neutre (pas de couleur de catégorie).
    local hasCol = r.color ~= nil
    local border = active and col
      or (hasCol and { col[1] * 0.5 + 0.06, col[2] * 0.5 + 0.06, col[3] * 0.5 + 0.06 } or C.iron)
    Draw.rect(r.x, r.y - lift, r.w, r.h, fill, border, active and 2 or 1)
    -- éclat additif au survol (le métal accroche la lumière), discret.
    if fs.glow and fs.glow > 0.02 and love.graphics and love.graphics.setBlendMode then
      love.graphics.setBlendMode("add")
      love.graphics.setColor(col[1], col[2], col[3], 0.12 * fs.glow)
      love.graphics.rectangle("line", r.x, r.y - lift, r.w, r.h)
      love.graphics.setBlendMode("alpha"); love.graphics.setColor(1, 1, 1, 1)
    end
    -- LABEL : actif -> couleur pleine ; inactif coloré -> teinte douce de sa couleur (lisible) ; sinon ink sourd.
    local labCol = active and col
      or (hasCol and { col[1] * 0.72 + 0.12, col[2] * 0.72 + 0.12, col[3] * 0.72 + 0.12 })
      or (fs.glow > 0.3 and C.ink2 or C.ink4)
    Draw.textTrackedC(r.label, r.x + r.w / 2, r.y - lift + (r.h - 11) / 2, labCol, font, 1.2)
  end
end

-- Une CASE de la grille : vignette Slot (icône relique OU rig/critter monstre) + label lisible dessous.
-- Voilée -> Slot "locked" + grand « ? » (silhouette inconnue façon Pokédex) + label « ? ? ? ». JUICE : la
-- case survolée MONTE (lift) + son Slot passe en "selected"/teinté + un halo additif -> « ça réagit ».
function Screen:drawCell(view, i, cell, x, y)
  local e, on = cell.e, cell.on
  local hov = (self.hover == i)
  local selected = on and self.selected and self.selected[self.tab] == e.id
  local fs = Feel.state("grim.cell." .. i)
  local lift = math.floor((fs.lift or 0) + 0.5)

  local tx, ty = x + CELL_PADX, y - lift
  local bestiary = (self.tab == "bestiary")
  -- TIER lu AU CADRE (comme les cartes shop) : la case bestiaire prend la COULEUR DE RARETÉ sur tout son bord,
  -- avivée au survol (calque de build:drawShop `hot and Rarity.tierBright`). Rangs hauts -> halo de rareté.
  local rich = bestiary and on and e.rank and Rarity.clamp(e.rank) >= 4
  local tierBorder = (bestiary and on and e.rank)
    and (hov and Rarity.tierBright(e.rank) or Rarity.tierColor(e.rank)) or nil
  local tierC = tierBorder -- (rétro-compat des couleurs de label plus bas)

  -- État du Slot : voilé -> "locked" ; révélé -> "empty", "selected" au survol. Bestiaire -> bord TEINTÉ par tier.
  local state = on and ((hov or selected) and "selected" or "empty") or "locked"
  Slot.draw(tx, ty, TILE, state, (on and tierBorder)
    and { tierBorder = tierBorder, tierGlow = rich } or nil)
  if selected then
    Draw.rect(tx - 3, ty - 3, TILE + 6, TILE + 6, nil, tierBorder or C.brass, 2)
  end

  -- halo additif de rareté DERRIÈRE la créature (bestiaire, rangs hauts) — « ça rayonne ».
  local cx, cy = tx + TILE / 2, ty + TILE / 2
  if on and bestiary and e.rank and love.graphics and love.graphics.setBlendMode and love.graphics.circle then
    local rar = Rarity.get(e.rank)
    if rar and rar.glow and rar.glow > 0 then
      local g = Rarity.frame(e.rank)
      love.graphics.setBlendMode("add")
      for k = 3, 1, -1 do
        love.graphics.setColor(g[1], g[2], g[3], rar.glow * 0.10 * k)
        love.graphics.circle("fill", cx, cy, TILE * 0.42 * (k / 3))
      end
      love.graphics.setBlendMode("alpha"); love.graphics.setColor(1, 1, 1, 1)
    end
  end

  -- Contenu de la case.
  if on then
    if self.tab == "relics" then
      -- icône ANIMÉE (le vrai objet maudit qui luit) — 40×40 ×2 = 80 design, centrée dans la case (TILE 92).
      -- Comme les créatures du bestiaire respirent dans leur case, la relique s'anime (déformation + overlays).
      local s = 2
      local sz = (RelicGen.SIZE or 40) * s
      RelicAnim.draw(view, e.id, math.floor(cx - sz / 2), math.floor(cy - sz / 2), s, self.t / 60)
    else
      -- créature VIVANTE (comme le board/galerie) si générée ; repli rig baké (6 dédiées). Clip à la case.
      if Critter.has(e.id) then
        -- vignette de codex : tout le monde regarde à GAUCHE (wantDir=-1) normalisé par le sens inhérent.
        Critter.draw(view, e.id, tx + 6, ty + 4, TILE - 12, TILE - 14, self.t / 60, Critter.facingFor(e.id, -1))
      else
        love.graphics.push()
        love.graphics.translate(cx, ty + TILE - 10)
        love.graphics.scale(2.0, 2.0)
        e.char.x, e.char.y, e.char.facing = 0, 0, 1
        Rig.draw(e.char)
        love.graphics.pop()
        love.graphics.setColor(1, 1, 1, 1)
      end
    end
  else
    -- silhouette inconnue : grand « ? » sourd au centre (Pokédex « non rencontré »).
    Draw.textC("?", cx, cy - 18, C.lock, Theme.display(40))
  end

  -- LABEL sous la vignette (lisible, tronqué à la largeur de case) : nom révélé OU « ? ? ? ».
  local lf = Theme.label(10)
  local labY = ty + TILE + 6
  if on then
    local nameKey = (self.tab == "relics") and ("relic." .. e.id .. ".name") or ("unit." .. e.id .. ".name")
    local name = T(nameKey)
    -- tronque proprement à la largeur de case (jamais couper mid-mot brutalement : ellipse).
    if lf and lf:getWidth(name) > CELL_W - 8 then
      while #name > 1 and lf:getWidth(name .. "…") > CELL_W - 8 do name = name:sub(1, #name - 1) end
      name = name .. "…"
    end
    local col = (tierC and C.ink) or C.ink2
    Draw.textC(name, x + CELL_W / 2, labY, (hov or selected) and C.ink or col, lf)
    -- sous-label : palier de relique OU rang de monstre (couleur de tier), petit.
    if bestiary and e.rank then
      Draw.textC(T(Rarity.tierNameKey(e.rank)), x + CELL_W / 2, labY + 13, Rarity.tierBright(e.rank), Theme.labelSmall(9))
    elseif self.tab == "relics" then
      local bandStr = (e.band == "low" and T("grimoire.band_low")) or (e.band == "high" and T("grimoire.band_high")) or T("grimoire.band_mid")
      local bandCol = RelicCard.bandAccent(e.band) or C.ink4
      Draw.textC(bandStr, x + CELL_W / 2, labY + 13, bandCol, Theme.labelSmall(9))
    end
  else
    Draw.textC(T("grimoire.unknown"), x + CELL_W / 2, labY, C.ink5, lf)
  end
end

function Screen:drawDetailEmpty()
  local f = Theme.body(13) or Theme.bodyLight(13)
  local x, y, w = DETAIL_X, self.gridTop, DETAIL_W
  Draw.divider(x + w / 2, y + 18, w - 40, C.iron, 0.6)
  Draw.textWrap(T("grimoire.detail_empty"), x + 24, y + 44, w - 48, C.ink3, f)
end

-- FICHE persistante à droite. La MÊME carte qu'en jeu, mais posée dans une colonne fixe.
function Screen:drawSelectedDetail(view)
  self.lastCardBox = nil
  local cell = self:selectedCell()
  if not (cell and cell.on) then self:drawDetailEmpty(); return end
  local e = cell.e
  local top = math.max(self.gridTop, 150)
  Draw.rect(DETAIL_X - 18, top - 16, 1, GRID_BOTTOM - top + 28, C.iron)
  if self.tab == "bestiary" then
    local level = math.max(1, math.min(3, tonumber(self.selectedLevel) or 1))
    local unit = MonsterCard.unitAtLevel(e.id, level) or Units[e.id]
    local cardX = DETAIL_X + math.floor((DETAIL_W - DETAIL_CARD_W) / 2)
    local box = MonsterCard.draw(view, self.palette, e.id, cardX, top, self.t / 60, {
      rig = self.previewRigs[e.id],
      keywordHint = true,
      x = cardX,
      y = top,
      level = level,
      unit = unit,
      levelSelector = true,
      levelHover = self.levelHover,
      levelFeelPrefix = "grim.level",
    })
    self.lastCardBox = box
    CardGlossary.drawMonster(view, box, e.id, self.t / 60, { unit = unit, force = self.forceKeywordGlossary })
  else
    -- carte de relique IDENTIFIÉE (band -> couleur de carte). L'ICÔNE ANIMÉE (id + t) remplit l'écrin.
    -- Hauteur MESURÉE -> rien ne déborde.
    local W = 300
    local opts = {
      state = "identified",
      name = T("relic." .. e.id .. ".name"),
      effect = table.concat(MechanicsText.relicLines(e.id), "\n"),
      flavor = T("relic." .. e.id .. ".flavor"),
      fam = RELIC_FAM[e.id] or "bone",
      band = e.band,
      id = e.id, t = self.t / 60,
    }
    local h = RelicCard.measure(W, opts)
    local x = DETAIL_X + math.floor((DETAIL_W - RELIC_CARD_W) / 2)
    local y = top
    if y + h > GRID_BOTTOM then y = math.max(top, GRID_BOTTOM - h) end
    local cardBox = { x = math.floor(x), y = math.floor(y), w = W, h = h }
    RelicCard.draw(cardBox.x, cardBox.y, W, h, opts)
    self.lastCardBox = cardBox
    CardGlossary.drawRelic(view, cardBox, e.id, self.t / 60, { force = self.forceKeywordGlossary })
  end
end

-- ── Entrées ──
function Screen:setTab(id)
  if self.tab == id then return end
  self.tab = id
  self.hover, self.scroll = nil, 0
  self:rebuildChips()
  self:rebuildCells()
end

-- Sélectionne une valeur pour UNE facette (les autres facettes restent inchangées -> filtres combinés en ET).
function Screen:setFilter(facet, key)
  if self.filter[self.tab][facet] == key then return end
  self.filter[self.tab][facet] = key
  self.hover = nil
  self:rebuildCells()
end

-- Index de case sous (dx,dy) en espace design (dans la grille clippée). nil hors grille / au-delà des cases.
function Screen:cellAt(dx, dy)
  if not ptIn(dx, dy, GRID_X0, self.gridTop, COLS * CELL_W, self:gridViewH()) then return nil end
  local rel = dy - self.gridTop + self.scroll
  local r = math.floor(rel / CELL_H)
  local localX = dx - GRID_X0
  local c = math.floor(localX / CELL_W)
  if c < 0 or c >= COLS then return nil end
  local i = r * COLS + c + 1
  if i >= 1 and i <= #(self.cells or {}) then
    -- hit la VIGNETTE (pas la gouttière de label) : on accepte toute la case (label inclus) pour un survol confortable.
    return i
  end
  return nil
end

function Screen:updateLevelHover()
  self.levelHover = nil
  local box = self.lastCardBox
  if not (box and box.levelRects) then return nil end
  for lvl, r in ipairs(box.levelRects) do
    if ptIn(self.mx, self.my, r.x, r.y, r.w, r.h) then
      self.levelHover = lvl
      return lvl
    end
  end
  return nil
end

function Screen:levelAt(dx, dy)
  local box = self.lastCardBox
  if not (box and box.levelRects) then return nil end
  for lvl, r in ipairs(box.levelRects) do
    if ptIn(dx, dy, r.x, r.y, r.w, r.h) then return lvl end
  end
  return nil
end

function Screen:selectCell(i)
  local cell = self.cells and self.cells[i]
  if not (cell and cell.on and cell.e) then return end
  local previous = self.selected[self.tab]
  self.selected[self.tab] = cell.e.id
  if self.tab == "bestiary" and previous ~= cell.e.id then self.selectedLevel = 1 end
end

function Screen:mousemoved(vx, vy)
  self.mx, self.my = vx * 4, vy * 4
  self.hover = self:cellAt(self.mx, self.my)
  self:updateLevelHover()
end

function Screen:mousepressed(vx, vy, button)
  if button ~= 1 then return end
  local dx, dy = vx * 4, vy * 4
  self.mx, self.my = dx, dy
  if self.backRect and ptIn(dx, dy, self.backRect.x, self.backRect.y, self.backRect.w, self.backRect.h) then
    Feel.press("grim.back", function() self.host.goto("menu") end); return -- ⭐ différé : press visible avant la bascule
  end
  local level = self:levelAt(dx, dy)
  if level then
    Feel.press("grim.level." .. level, function() self.selectedLevel = level end, { delay = 0.08 })
    return
  end
  if self._tabRects then
    for id, r in pairs(self._tabRects) do
      if ptIn(dx, dy, r.x, r.y, r.w, r.h) then
        Feel.press("grim.tab." .. id, function() self:setTab(id) end, { delay = 0.08 })
        return
      end
    end
  end
  for _, r in ipairs(self.chipRects or {}) do
    if ptIn(dx, dy, r.x, r.y, r.w, r.h) then
      Feel.press("grim.chip." .. r.facet .. "." .. r.key, function() self:setFilter(r.facet, r.key) end, { delay = 0.08 })
      return
    end
  end
  local ci = self:cellAt(dx, dy)
  if ci and self.cells and self.cells[ci] and self.cells[ci].on then
    Feel.press("grim.cell." .. ci, function() self:selectCell(ci) end, { delay = 0.08 })
  end
end

function Screen:wheelmoved(_, dy)
  self.scroll = self.scroll - (dy or 0) * 48
  local m = self:maxScroll()
  if self.scroll < 0 then self.scroll = 0 elseif self.scroll > m then self.scroll = m end
  -- met à jour le survol (le contenu sous le curseur a bougé).
  self.hover = self:cellAt(self.mx, self.my)
  self:updateLevelHover()
end

function Screen:keypressed(key)
  if key == "tab" or key == "left" or key == "right" then self:setTab(self.tab == "relics" and "bestiary" or "relics")
  elseif key == "g" or key == "escape" then self.host.goto("menu") end
  if self.tab == "bestiary" and (key == "1" or key == "2" or key == "3") then
    self.selectedLevel = tonumber(key)
  end
end

return Screen
