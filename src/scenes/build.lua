-- src/scenes/build.lua
-- Phase de BUILD (le cœur de la boucle) : on compose son équipe sur le plateau-graphe en ACHETANT
-- des unités à la BOUTIQUE, puis on lance le combat. Composantes :
--   · le plateau 3×3 (sigil échangeable avec [s] ; slots débloqués en montant de NIVEAU) ;
--   · une BOUTIQUE (bas) : 5 offres aléatoires + prix ; on DRAG une offre sur une case (paie l'or) ;
--   · boutons REROLL (re-tire la boutique) et NIVEAU (débloque le slot suivant) ;
--   · réarrangement par drag case→case (déplacer/échanger) ; drag hors-plateau = VENTE (remboursement) ;
--   · une INFOBULLE au survol (stats + passif) d'une case occupée ou d'une offre ;
--   · un HUD de run (or/vies/victoires/round/niveau/streak) ;
--   · un bouton COMBAT -> assemble l'équipe (gauche) + une équipe IA (droite) et bascule vers la
--     scène de combat via host.goto("combat", payload). Le résultat revient par host.finishCombat.
--
-- La méta de RUN (host.run, src/run/state.lua) porte l'économie. SANS run (tests/sim), la scène
-- reste utilisable en « sandbox » : placeId/buildComp marchent directement, la boutique est inerte.
--
-- Souris (vérifié sur love2d.org/wiki) : coordonnées reçues déjà converties en espace virtuel par
-- main.lua. love.mousepressed/released(x,y,button) avec button==1 pour le clic gauche.
--
-- Interface scène : update / drawWorld / drawOverlay(view) / keypressed / mouse*.

local Board = require("src.board.board")
local Shapes = require("src.board.shapes")
local Rig = require("src.core.rig")
local Creatures = require("src.data.creatures")
local Units = require("src.data.units")
local CreatureGen = require("src.gen.creaturegen") -- visuel généré pour les unités sans rig dessiné main
local Encounters = require("src.data.encounters")
local Place = require("src.combat.place")
local Stats = require("src.effects.stats") -- caps du framework payoff (value bouclier ×3 à la lecture)
local Snapshot = require("src.net.snapshot")
local Snapstore = require("src.net.snapstore")
local Run = require("src.run.state")
local RelicGen = require("src.gen.relicgen") -- icones de reliques (rangee type Slay the Spire + hover)
local Bestiary = require("src.core.bestiary") -- marque les créatures vues en boutique (codex)
local Theme = require("src.ui.theme")
local Draw = require("src.ui.draw")
-- ── Kit UI PROPRE (.dc.html / design-system) : la scène n'utilise plus du tout Frame/Forge (kit legacy) ──
local Panel = require("src.ui.panel")    -- surface propre (dégradé + liseré iron) : remplace Frame/Forge.uiPlate/uiCard
local Button = require("src.ui.button")  -- boutons propres : primary (CTA + yeux) / eco (coût) / secondary
local Slot = require("src.ui.slot")      -- cases du plateau (6 états) : remplace Forge.uiSocket
local Gauge = require("src.ui.gauge")    -- jauges vies/XP : remplace l'orbe forge baké
local Badge = require("src.ui.badge")    -- coût (pièce+nombre) / pips de niveau / diamants : remplace Forge.coinAt/diamondAt/label
local Feel = require("src.ui.feel")      -- JUICE : survol (glow/lift) + press (squash/flash) + action différée
local ScreenFrame = require("src.ui.screenframe") -- ENROBAGE partagé : cadre de pierre gravée + onglet de nom
local Layout = require("src.ui.layout") -- MOTEUR de layout flex (alignement parfait, fill-to-container)
local Keywords = require("src.ui.keywords") -- registre afflictions (mini-chips de carte)
local Chip = require("src.ui.chip") -- pastilles keyword (icône d'affliction)
local Ambient = require("src.fx.ambient")
local MiniRig = require("src.render.minirig") -- mesure OPAQUE mutualisée des rigs (bounds/fit) : seule source de vérité
local MonsterCard = require("src.render.monstercard") -- FICHE de monstre (extraite de drawTooltip) : réutilisée ici + Chronique
local I18n = require("src.core.i18n")
local T = I18n.t

local Build = {}
Build.__index = Build

local SLOT_HALF = 40 -- demi-côté d'une case en espace DESIGN (80x80 ; centre = self.pos[i] ×4)

-- Rangée de RELIQUES possédées (style Slay the Spire) : icônes bakées au-dessus de la boutique, à GAUCHE
-- (bande design x22.. y512 — libre pour tous les sigils : board centré x536+ ou plat) ; survol -> infobulle.
local RELIC_ICON_SCALE = 2          -- icône 16x16 -> 32x32 design (scale entier -> net)
local RELIC_ICON_PX = 16 * RELIC_ICON_SCALE
local RELIC_CELL = 44               -- pas horizontal (icône + cadre forge + gap)
local RELIC_X0, RELIC_Y = 22, 510   -- ancrage design
local RELIC_FRAME = 4               -- débord du socle forge autour de l'icône (cadre patiné)

-- Famille forge par relique (forme + couleur de la gem d'accent) -> liseré teinté de la fiche/du socle.
-- Clés ∈ Forge.FAM (flesh/bone/order/abyss/arcane). Aligné sur src/scenes/relicpick.lua.
local RELIC_TYPE = {
  bloodstone = "flesh", carapace = "bone", aegis = "order",
  kings_bowl = "abyss", ember_heart = "arcane", weeping_nail = "flesh", grave_cap = "abyss",
}

local SPACING = 26
local BOARD_HALF_W = 96 -- demi-étendue MAX (virtuelle) des centres de cases dans la RÉGION GAUCHE (board décalé à gauche)
local BOARD_HALF_H = 40  -- (idem vertical) : un sigil étalé se resserre pour tenir dans la bande board
-- ── Régions du mockup (§B.1), espace DESIGN, le tout DANS le cadre reliquaire ──
local FRAME_FT = 8        -- épaisseur d'art de la bande gravée (×4 = ~32px de pierre)
local HUD_H = 46          -- barre HUD du haut (GOLD/LIVES/DESCENT/ROUND/STREAK/TIER)
local SIGIL_H = 34        -- en-tête de sigil (nom à gauche + contrôles de reshape à droite)
local OFFERING_H = 152    -- bas : THE OFFERING (boutique) + cluster éco (REROLL/BUY XP/FIGHT)
local INSPECTOR_W = 256   -- panneau d'INSPECTION persistant (colonne droite de la bande board)
local MAX_LEVEL = 3
local LEVEL_MULT = { 1.0, 1.8, 3.0 } -- stats par niveau : 3 copies (même id+niveau) -> 1 unité niveau+1 (façon TFT)

-- ── Courbe de difficulté (cold-start) — TUNABLES (cf. the-pit-balance-diagnosis). Le board joueur croît de
-- façon PRÉVISIBLE (grants timés 3->9). L'ennemi suit : l'index d'encounter grimpe avec le round (taille),
-- puis au-delà de la table le plus gros gagne des NIVEAUX (bump) pour suivre les merges du joueur fin de run. ──
local ENEMY_LEVEL_START = 11 -- round où l'ennemi cold-start gagne des niveaux (APRÈS la table : pit_sovereign
local ENEMY_LEVEL_EVERY = 3  -- est déjà leveled ; le bump ne sert qu'aux runs très longues, pour ne pas plateau)

function Build.new(palette, vw, vh, host)
  local self = setmetatable({
    vw = vw, vh = vh, t = 0, palette = palette, host = host,
    daChrome = true, -- la scène porte sa propre chrome DA (pas de HUD générique)
    nativeWorld = true, -- board + boutique rendus en RÉSOLUTION NATIVE (créatures nettes, cohérent avec le combat)
    titleKey = "scene.build",
    hintKey = "ui.hint_build",
    shapeIdx = 1,
    board = Board.new("carre"),
    slotRigs = {},     -- [slot] = { id, char } : unités posées
    previewRigs = {},  -- [id] = char idle (aperçu boutique)
    drag = nil,        -- { id, char, fromSlot? | fromShop? }
    mx = -100, my = -100,
    combatCount = 0,
  }, Build)
  self:computeRegions() -- régions du mockup (§B.1) : HUD / sigil / board-gauche / inspecteur / offering + cadre
  self:computeLayout()
  self:computeShop()
  for _, id in ipairs(Units.pool) do
    local c = self:newRig(id); c.x, c.y = 0, 0
    self.previewRigs[id] = c
  end
  -- self.button / rerollBtn / declineBtn + les rects du layout (orbe, cartes) sont calculés par
  -- computeShop() via le moteur Layout (déjà appelé ci-dessus) -> alignement parfait, fill-to-container.
  -- (les accents de liseré des cases sont désormais portés par les 6 ÉTATS de l'atome Slot — plus de cache forge.)
  self.ambient = Ambient.new(3) -- fond calme (mode "build" : dégradé, pas de particules d'ambiance)
  if self.host.run then self:syncSlots() end
  return self
end

function Build:newRig(id)
  -- Visuel : rig dessiné MAIN (Creatures[id], les 6 vanille) sinon créature GÉNÉRÉE procéduralement
  -- (déterministe par id) — COHÉRENT avec le rendu de combat (arena_draw). Boutique = combat.
  local def = Creatures[id]
  if not def then
    local spec = Units[id] or {}
    def = CreatureGen.cached({ id = id, type = spec.type, family = spec.family, effects = spec.effects, bodyplan = spec.bodyplan, rank = spec.rank })
  end
  local c = Rig.new(def, self.palette)
  c.facing = 1
  return c
end

-- ── FIT-TO-BOX (FIX overflow) : étendue OPAQUE RÉELLE d'un rig (pose idle) en unités VIRTUELLES relatives à
-- l'origine au sol -> { w, h, top, bot }. La mesure (canvas hors-écran + scan de pixels, mémoïsée, repli
-- headless) est désormais MUTUALISÉE dans src/render/minirig.lua (MiniRig.bounds), seule source de vérité,
-- partagée avec la fiche de monstre (MonsterCard) et La Chronique. Le build n'en garde qu'une délégation ->
-- plus de duplication de l'algo, et la mesure est DÉTERMINISTE (idlePhase figé) : le portrait ne « tremble »
-- plus d'un rechargement à l'autre. Sert à caler chaque créature dans son conteneur (case / carte / portrait).
function Build:rigBounds(id)
  return MiniRig.bounds(id, self.palette)
end

-- Échelle qui CONTIENT le rig (id) dans une boîte virtuelle (boxW × boxH), avec une marge (0..1). On prend
-- le min des deux axes -> la créature tient ENTIÈREMENT (jamais coupée). maxScale plafonne l'agrandissement
-- (défaut 1 : cases/cartes = on RÉTRÉCIT seulement ; le PORTRAIT de fiche passe ~3 pour REMPLIR un grand
-- logement avec un petit sprite, plus de vide noir).
function Build:rigFitScale(id, boxW, boxH, margin, maxScale)
  margin = margin or 0.86
  maxScale = maxScale or 1
  local bnd = self:rigBounds(id)
  local sw = (bnd.w > 0) and (boxW * margin / bnd.w) or 1
  local sh = (bnd.h > 0) and (boxH * margin / bnd.h) or 1
  return math.min(maxScale, sw, sh)
end

-- ── Régions du mockup (§B.1) en ESPACE DESIGN, le tout DANS le cadre reliquaire (inset). Calculées une fois
-- (resize -> rappeler). Empile : HUD bar -> en-tête sigil -> [ board GAUCHE | inspecteur 256 DROITE ] -> THE
-- OFFERING. Pose aussi le CENTRE du board (virtuel) pour computeLayout + les rects des boutons de reshape.
function Build:computeRegions()
  local ix, iy, iw, ih = ScreenFrame.inset({ ft = FRAME_FT, pad = 2 })
  self.inset = { x = ix, y = iy, w = iw, h = ih }
  self.hudBar = { x = ix, y = iy, w = iw, h = HUD_H }
  self.sigilBar = { x = ix, y = iy + HUD_H + 2, w = iw, h = SIGIL_H }
  local midY = self.sigilBar.y + SIGIL_H + 6
  local offY = iy + ih - OFFERING_H
  local midH = offY - midY - 6
  self.inspector = { x = ix + iw - INSPECTOR_W, y = midY, w = INSPECTOR_W, h = midH }
  self.boardRegion = { x = ix, y = midY, w = iw - INSPECTOR_W - 16, h = midH }
  self.offering = { x = ix, y = offY, w = iw, h = OFFERING_H }
  -- centre du board (virtuel = design/4) -> computeLayout y centre la forme.
  self._boardCx = (self.boardRegion.x + self.boardRegion.w / 2) / 4
  self._boardCy = (self.boardRegion.y + self.boardRegion.h / 2) / 4
  -- boutons de RESHAPE (5 glyphes, droite de l'en-tête sigil) — rects en VIRTUEL (÷4) pour hit-test cohérent.
  self._sigilBtns = {}
  local n = #Shapes.order
  local bs, gap = 24, 6
  local totalW = n * bs + (n - 1) * gap
  local bx = self.sigilBar.x + self.sigilBar.w - 12 - totalW
  local by = self.sigilBar.y + math.floor((SIGIL_H - bs) / 2)
  for i = 1, n do
    local dx = bx + (i - 1) * (bs + gap)
    self._sigilBtns[i] = { x = dx / 4, y = by / 4, w = bs / 4, h = bs / 4, dx = dx, dy = by, ds = bs, shape = Shapes.order[i] }
  end
  -- rangée de RELIQUES possédées : petite ligne au bas-gauche de la bande board (au-dessus de l'offering).
  self._relicX0 = ix + 6
  self._relicY = offY - (RELIC_ICON_PX + RELIC_FRAME * 2) - 8
end

-- Centre la forme courante dans la RÉGION BOARD (gauche). SPACING adaptatif -> toute forme tient sans déborder.
function Build:computeLayout()
  local cells = self.board.shape.cells
  local minx, maxx, miny, maxy = math.huge, -math.huge, math.huge, -math.huge
  for _, c in ipairs(cells) do
    minx = math.min(minx, c.x); maxx = math.max(maxx, c.x)
    miny = math.min(miny, c.y); maxy = math.max(maxy, c.y)
  end
  local mx, my = (minx + maxx) / 2, (miny + maxy) / 2
  local sp = SPACING
  local extX, extY = maxx - minx, maxy - miny
  if extX > 0 then sp = math.min(sp, 2 * BOARD_HALF_W / extX) end
  if extY > 0 then sp = math.min(sp, 2 * BOARD_HALF_H / extY) end
  local ox, oy = self._boardCx or (self.vw / 2), self._boardCy or 90
  self.pos = {}
  for i, c in ipairs(cells) do
    self.pos[i] = {
      x = math.floor(ox + (c.x - mx) * sp + 0.5),
      y = math.floor(oy + (c.y - my) * sp + 0.5),
    }
  end
end

-- ── THE OFFERING + ÉCO (bas de l'inset, §B.1.4) en ESPACE DESIGN ────────────────────────────────────
-- [ boutique « THE OFFERING » (flex) | cluster éco (fixe) ]. Plus d'orbe de vie (les vies vivent dans la barre
-- HUD). Boutique = header (caption + règle) + rangée de cartes ; éco = rangée [BUY XP | REROLL] + FIGHT (CTA).
-- On calcule les rects DESIGN une fois ; les hit-tests souris (VIRTUEL) sont dérivés (÷4) -> self.shopSlots etc.
function Build:computeShop()
  local cols = Layout.row(self.offering, {
    { flex = 1 },     -- boutique (THE OFFERING)
    { size = 300 },   -- cluster éco (REROLL/BUY XP + FIGHT)
  }, { gap = 16, align = "stretch" })
  local shopCol, ecoCol = cols[1], cols[2]
  self.lay = {}

  -- boutique : [ header (caption + règle) | rangée de cartes (flex, gouttières égales) ].
  local sc = Layout.column(shopCol, { { size = 18 }, { flex = 1 } }, { gap = 8, align = "stretch" })
  self.lay.shopHeader = sc[1]
  local specs = {}
  for _ = 1, Run.SHOP_SIZE do specs[#specs + 1] = { flex = 1 } end
  self.lay.cards = Layout.row(sc[2], specs, { gap = 8, align = "stretch" })

  -- éco : [ rangée [BUY XP | REROLL] (fixe) | FIGHT (flex, gros CTA sang) ]. La moitié REROLL se scinde en
  -- [ REROLL | REFUSER ] quand un grant de slot attend (on choisit à l'affichage selon run.pendingSlotGrant).
  local ec = Layout.column(ecoCol, { { size = 36 }, { flex = 1 } }, { gap = 8, align = "stretch" })
  local ecoRow = Layout.row(ec[1], { { flex = 1 }, { flex = 1 } }, { gap = 8, align = "stretch" })
  self.lay.raiseBox = ecoRow[1]                          -- BUY XP (toujours à gauche)
  self.lay.ecoRowBox = ecoRow[2]                         -- REROLL seul (pas de grant)
  local ecoSplit = Layout.row(ecoRow[2], { { flex = 1 }, { flex = 1 } }, { gap = 8, align = "stretch" })
  self.lay.rerollSplitBox = ecoSplit[1]                  -- REROLL quand un grant attend
  self.lay.declineBox = ecoSplit[2]                      -- REFUSER (visible seulement pendant un grant)
  self.lay.combatBox = ec[2]                             -- FIGHT (le SEUL bouton sang de l'écran)

  local function toV(r) return { x = r.x / 4, y = r.y / 4, w = r.w / 4, h = r.h / 4 } end
  self._toV = toV
  self.shopSlots = {}
  for i = 1, Run.SHOP_SIZE do self.shopSlots[i] = toV(self.lay.cards[i]) end
  self.button = toV(self.lay.combatBox)
  self.raiseBtn = toV(self.lay.raiseBox)
  self.declineBtn = toV(self.lay.declineBox)
  self:syncEcoRects(false)
end

-- Synchronise le rect de hit-test REROLL selon qu'un grant attend (ligne scindée) ou non (ligne pleine).
-- Appelé chaque frame avant les clics/le rendu -> le hit-test colle TOUJOURS à ce qui est dessiné.
function Build:syncEcoRects(granting)
  local box = granting and self.lay.rerollSplitBox or self.lay.ecoRowBox
  self.rerollBtn = self._toV(box)
end

-- Rect (ESPACE DESIGN) de la i-ème relique possédée (rangée au-dessus de la boutique). Inclut le cadre
-- forge (RELIC_FRAME de débord) -> le SOCLE entier est la cible de survol (hit-test = ce qui est dessiné).
function Build:relicRowRect(i)
  local s = RELIC_ICON_PX + RELIC_FRAME * 2
  return { x = (self._relicX0 or RELIC_X0) + (i - 1) * RELIC_CELL, y = self._relicY or RELIC_Y, w = s, h = s }
end

-- Index de la relique survolée (souris en VIRTUEL -> testée ×4 contre les rects design), ou nil.
function Build:relicAt(vx, vy)
  local run = self.host.run
  if not run or #run.relics == 0 then return nil end
  local dx, dy = vx * 4, vy * 4
  for i = 1, #run.relics do
    local r = self:relicRowRect(i)
    if dx >= r.x and dx <= r.x + r.w and dy >= r.y and dy <= r.y + r.h then return i end
  end
  return nil
end

-- Réconcilie l'ensemble des cases OUVERTES à la capacité de la run (ne ferme JAMAIS). Les grants ouvrent
-- des cases PRÉCISES (placement libre via openCell) ; ceci ne sert que de rattrapage si la capacité dépasse
-- l'ouvert (départ, pilotage headless). NE réinitialise PAS en préfixe -> préserve le cluster central + les
-- choix de placement du joueur (décision grants timés 2026-06, cf. the-pit-balance-diagnosis).
function Build:syncSlots()
  if self.host.run then self.board:ensureOpen(self.host.run.slots) end
end

-- ── Hit-tests (espace virtuel) ──
local function inRect(px, py, r) return px >= r.x and px <= r.x + r.w and py >= r.y and py <= r.y + r.h end

function Build:slotAt(px, py)
  local best, bestD
  for i = 1, 9 do
    if self.board.slots[i].unlocked then
      local p = self.pos[i]
      local dx, dy = px - p.x, py - p.y
      local d = dx * dx + dy * dy
      if d <= 14 * 14 and (not bestD or d < bestD) then best, bestD = i, d end
    end
  end
  return best
end

-- Case VERROUILLÉE (non ouverte) sous le curseur : cible de placement d'un grant de slot (placement libre).
function Build:lockedCellAt(px, py)
  local best, bestD
  for i = 1, 9 do
    if not self.board.slots[i].unlocked then
      local p = self.pos[i]
      local dx, dy = px - p.x, py - p.y
      local d = dx * dx + dy * dy
      if d <= 14 * 14 and (not bestD or d < bestD) then best, bestD = i, d end
    end
  end
  return best
end

-- Indice de l'offre de boutique sous le curseur (nil hors boutique / sans run).
function Build:shopAt(px, py)
  local run = self.host.run
  if not run then return nil end
  for i, r in ipairs(self.shopSlots) do
    if run.shop[i] and inRect(px, py, r) then return i end
  end
  return nil
end

function Build:placedCount()
  local n = 0
  for i = 1, 9 do if self.slotRigs[i] then n = n + 1 end end
  return n
end

-- Pose un id sur un slot (aussi appelé par les tests/sim, sans souris ni économie).
function Build:placeId(slot, id, level)
  if not (self.board.slots[slot] and self.board.slots[slot].unlocked) then return false end
  self.slotRigs[slot] = { id = id, level = level or 1, char = self:newRig(id) }
  self.board.slots[slot].unit = id
  return true
end

-- DUPLICATAS (étape gameplay #2) : 3 unités de MÊME id ET MÊME niveau fusionnent en une de niveau+1
-- (cap MAX_LEVEL). Stats + buffs d'adjacence scalent (LEVEL_MULT, appliqué dans buildComp). Cascade :
-- 3 niveau-2 -> 1 niveau-3. Appelé après un AJOUT de copie (achat). Scène (pas SIM) -> non critique au replay.
-- Renvoie `true` si AU MOINS une fusion a eu lieu (Lot 5 §5.2 : un level-up arme la récompense de relique,
-- bornée 1/round). Une CASCADE (plusieurs fusions dans un même appel) ne doit armer l'offre qu'UNE fois :
-- le drapeau de run (relicFromLevelThisRound) garde l'armement -> idempotent ; le caller déclenche l'écran.
function Build:checkMerges()
  local anyMerge = false
  local merged = true
  while merged do
    merged = false
    local groups = {} -- [id\0level] = { slots... }, en ordre de slot (1->9) pour un résultat stable
    for i = 1, 9 do
      local sr = self.slotRigs[i]
      if sr and (sr.level or 1) < MAX_LEVEL then
        local key = sr.id .. "\0" .. (sr.level or 1)
        local g = groups[key]; if not g then g = {}; groups[key] = g end
        g[#g + 1] = i
      end
    end
    for _, slots in pairs(groups) do
      if #slots >= 3 then
        local keep = slots[1]
        local id, lvl = self.slotRigs[keep].id, (self.slotRigs[keep].level or 1) + 1
        for k = 2, 3 do -- consomme 2 copies
          self.slotRigs[slots[k]] = nil
          self.board.slots[slots[k]].unit = nil
        end
        self.slotRigs[keep] = { id = id, level = lvl, char = self:newRig(id) } -- promeut la 1re
        self.board.slots[keep].unit = id
        merged = true
        anyMerge = true
        break -- re-scan (une promotion peut déclencher une nouvelle fusion)
      end
    end
  end
  -- Récompense de level-up (Lot 5 §5.2) : une fusion en phase build ouvre un choix 1-parmi-3, mais 1 SEULE
  -- fois par round. Le drapeau de run (relicFromLevelThisRound) garantit que la cascade ET les fusions
  -- ultérieures du même round n'arment l'offre qu'une fois ; le caller (mousereleased) déclenche l'écran.
  local run = self.host.run
  if anyMerge and run and not run.relicFromLevelThisRound then
    run.relicFromLevelThisRound = true
    self.pendingLevelRelic = true
  end
  return anyMerge
end

-- ── Entrées ──
function Build:keypressed(key)
  if key == "s" then -- swap de sigil (libre pour l'instant ; via reliques plus tard, cf. étape #3)
    self.shapeIdx = self.shapeIdx % #Shapes.order + 1
    self.board:setShape(Shapes.order[self.shapeIdx])
    self:computeLayout()
  end
end

function Build:mousemoved(vx, vy)
  self.mx, self.my = vx, vy
end

function Build:mousepressed(vx, vy, button)
  if button ~= 1 then return end
  self.mx, self.my = vx, vy
  local run = self.host.run
  -- rect REROLL fidèle à l'état du grant (ligne pleine / scindée) AVANT le hit-test (mousepressed peut être
  -- appelé sans update, ex. tests headless).
  self:syncEcoRects(run and run.pendingSlotGrant)
  -- Boutons de RESHAPE (en-tête sigil) : posent la forme i directement (même effet que [s], mais ciblé).
  for i, sb in ipairs(self._sigilBtns or {}) do
    if inRect(vx, vy, sb) then
      Feel.press("build.sigil." .. i)
      if self.board.shape.name ~= sb.shape then self.shapeIdx = i; self.board:setShape(sb.shape); self:computeLayout() end
      return
    end
  end
  -- COMBAT : feedback de press IMMÉDIAT (squash + flash -> les YEUX du CTA réagissent au clic) puis bascule
  -- de scène TOUT DE SUITE (l'e2e headless asserte la transition juste après le clic -> on ne diffère pas).
  if inRect(vx, vy, self.button) then Feel.press("build.combat"); self:startCombat(); return end
  if run then
    -- Grant en attente : REFUSER prioritaire (son rect cohabite avec la moitié REROLL) ; sinon ACCEPTER
    -- (clic sur une case verrouillée). Puis REROLL.
    if run.pendingSlotGrant then
      if inRect(vx, vy, self.declineBtn) then Feel.press("build.decline"); run:declineSlotGrant(); return end
      local lc = self:lockedCellAt(vx, vy)
      if lc then if run:acceptSlotGrant() then self.board:openCell(lc) end; return end
    end
    -- BUY XP : achète de l'XP de boutique si abordable (NE re-tire PAS la boutique : les nouvelles cotes
    -- s'appliquent au prochain reroll/round -> préserve l'arbitrage XP-vs-reroll-vs-unités).
    -- BUY XP / REROLL : feedback de press IMMÉDIAT (Feel.press sans action) + action TOUT DE SUITE (l'e2e
    -- headless asserte l'or débité juste après le clic -> on ne diffère PAS ces actions de boutique).
    if inRect(vx, vy, self.raiseBtn) then Feel.press("build.raise"); if run:canBuyXp() then run:buyXp() end; return end
    if inRect(vx, vy, self.rerollBtn) then Feel.press("build.reroll"); run:reroll(); return end
    local oi = self:shopAt(vx, vy)
    if oi then -- prend une offre achetable (consommée seulement au lâcher sur une case valide)
      local o = run.shop[oi]
      if o and not o.sold and run.gold >= o.cost then
        self.drag = { id = o.id, level = 1, char = self:newRig(o.id), fromShop = oi }
      end
      return
    end
  end
  local si = self:slotAt(vx, vy)
  if si and self.slotRigs[si] then -- ramasse une unité déjà posée (réarrangement / vente)
    self.drag = { id = self.slotRigs[si].id, level = self.slotRigs[si].level or 1, char = self.slotRigs[si].char, fromSlot = si }
    self.slotRigs[si] = nil
    self.board.slots[si].unit = nil
  end
end

function Build:mousereleased(vx, vy, button)
  if button ~= 1 or not self.drag then return end
  local d = self.drag
  self.drag = nil
  local run = self.host.run
  local si = self:slotAt(vx, vy)

  if d.fromShop then
    -- ACHAT : seulement sur une case débloquée et VIDE. L'or n'est débité qu'ici (placement garanti).
    if si and self.board.slots[si].unlocked and not self.slotRigs[si] then
      local id = run and run:buy(d.fromShop)
      if id then
        self.slotRigs[si] = { id = id, level = 1, char = d.char }
        self.board.slots[si].unit = id
        self:checkMerges() -- 3 copies (même id+niveau) -> fusion en niveau+1 (arme pendingLevelRelic une fois/round)
        -- Lot 5 (§5.2) : une fusion a armé la récompense de level-up -> on présente l'offre 1-parmi-3 MID-ROUND
        -- (retour au MÊME round : boutique/or/plateau préservés, AUCUN startRound). Bornée par le drapeau de run.
        if self.pendingLevelRelic then
          self.pendingLevelRelic = false
          if self.host.offerLevelUpRelic then self.host.offerLevelUpRelic() end
        end
      end
    end
    return
  end

  -- Depuis un slot (l'origine a été vidée au pickup).
  if si and self.board.slots[si].unlocked then
    local occ = self.slotRigs[si]
    if occ and d.fromSlot and si ~= d.fromSlot then -- SWAP : l'occupant repart vers l'origine
      self.slotRigs[d.fromSlot] = occ
      self.board.slots[d.fromSlot].unit = occ.id
    end
    self.slotRigs[si] = { id = d.id, level = d.level or 1, char = d.char }
    self.board.slots[si].unit = d.id
  else
    -- Lâché HORS d'un slot : VENTE (remboursement) si on a une run ; sinon l'unité disparaît (sandbox).
    if run and d.fromSlot then run:sell(d.id) end
  end
end

-- ── Lancement du combat ──
-- Escalade : l'adversaire monte en danger avec le round (IA de seed jusqu'aux snapshots, étape #4).
-- Renvoie (encounter, levelBump) pour le round courant. Pacing `floor((round-1)/2)+1` (un palier tous les 2
-- rounds = le joueur garde une avance de taille pendant qu'il investit), mais NON CAPPÉ : avec 6 encounters il
-- atteint gorge_pack(r7)/drowned_legion(r9)/pit_sovereign(r11, leveled) au lieu de plafonner à brood(5) dès r5
-- (-> late trivial). Au-delà de la table, levelBump suit le board levelé du joueur. (cold-start ; les ghosts
-- de snapshots scalent d'eux-mêmes par tier.)
function Build:pickEncounter()
  local round = (self.host.run and self.host.run.round) or (self.combatCount + 1)
  local idx = math.max(1, math.min(#Encounters, math.floor((round - 1) / 2) + 1))
  local bump = (round >= ENEMY_LEVEL_START) and (1 + math.floor((round - ENEMY_LEVEL_START) / ENEMY_LEVEL_EVERY)) or 0
  return Encounters[idx], bump
end

-- Assemble la compo posée pour un CÔTÉ (side=-1 gauche / +1 droite), auras d'adjacence résolues.
-- buildLeftComp = buildComp(-1). La sim d'équilibrage utilise les deux côtés (matchups symétriques).
function Build:buildComp(side)
  side = side or -1
  local facing = (side < 0) and 1 or -1
  local placed = {}
  for i = 1, 9 do
    if self.slotRigs[i] then
      local c = self.board.shape.cells[i]
      placed[#placed + 1] = { slot = i, id = self.slotRigs[i].id, col = c.x, row = c.y, level = self.slotRigs[i].level or 1 }
    end
  end
  if #placed == 0 then return {} end

  -- ── Auras d'adjacence résolues AVANT le combat : état DÉRIVÉ du graphe du sigil (board:neighbors),
  -- fidèle au pilier « la forme EST le graphe de synergies ». AUCUN op combat (comme shield_aura) : on
  -- lit le descripteur combat_start/aura_* (data) et on BAKE le bonus sur le voisin. Changer de sigil
  -- re-cible tout seul. shield_aura -> stat directe ; aura_* -> modifient les EFFETS du voisin (ci-dessous).
  -- NB : notre burn/poison sont en `dps` (pas en pct) -> aura_burn_dps/aura_poison_dps = +dps à plat. ──
  -- Framework PAYOFF : poison/burn AMPLIFIÉS par un `increased` baké sur le PORTEUR (lu par la pose ET le
  -- spread via Stats.resolve, cappé ×3) -> l'investissement se RESSENT partout. rot garde son `growth`
  -- (axe rampe = son identité ; son ampli passe quand même au spread via le `load`). cf. payoff-framework.md §4.
  local shield = {}
  local burnInc, poisonInc, rotGrowth, grantBleed = {}, {}, {}, {}
  for _, p in ipairs(placed) do
    local sm = LEVEL_MULT[p.level] or 1.0 -- l'aura scale avec le NIVEAU de la source (duplicatas) ; cap appliqué à la LECTURE
    for _, e in ipairs(Units[p.id].effects or {}) do
      if e.trigger == "combat_start" and e.target == "neighbors" then
        local op, pa = e.op, e.params or {}
        for _, nb in ipairs(self.board:neighbors(p.slot)) do
          if self.slotRigs[nb] then
            if op == "shield_aura" then shield[nb] = (shield[nb] or 0) + math.floor((pa.value or 0) * sm + 0.5)
            elseif op == "aura_burn_dps" then burnInc[nb] = (burnInc[nb] or 0) + (pa.inc or 0.5) * sm
            elseif op == "aura_poison_dps" then poisonInc[nb] = (poisonInc[nb] or 0) + (pa.inc or 0.5) * sm
            elseif op == "aura_rot_growth" then rotGrowth[nb] = (rotGrowth[nb] or 0) + math.floor((pa.bonus or 0) * sm + 0.5)
            elseif op == "aura_grant_bleed" then grantBleed[nb] = pa
            end
          end
        end
      end
    end
  end

  -- Matérialise les effets d'un voisin SOUS aura (rot growth + grant_bleed seulement ; poison/burn passent
  -- par poisonInc/burnInc sur l'unité). Sinon nil = base (golden-safe).
  local function auraEffects(id, slot)
    if not (rotGrowth[slot] or grantBleed[slot]) then return nil end
    local out = {}
    for _, e in ipairs(Units[id].effects or {}) do
      local pa = {}
      for k, v in pairs(e.params or {}) do pa[k] = v end
      if e.op == "rot" and rotGrowth[slot] then pa.growth = (pa.growth or 1) + rotGrowth[slot] end
      out[#out + 1] = { trigger = e.trigger, op = e.op, params = pa, target = e.target, condition = e.condition }
    end
    if grantBleed[slot] then
      local g = grantBleed[slot]
      out[#out + 1] = { trigger = "on_hit", op = "bleed",
        params = { dps = g.dps or 1, dur = g.dur or 180, slowPct = g.slowPct or 0 } }
    end
    return out
  end

  -- BOUCLIERS PÉRIODIQUES (framework payoff §3) : casters (shield_caster) + renforts (aura_shield adjacente).
  -- Renforts = 5 axes : valeur (valueInc) / cadence (cdr) / réflexion (reflect) / largeur (radius) / surcharge.
  local casters = {} -- [slot] = { value, cd, reflect, overcharge, targetSlots }
  for _, p in ipairs(placed) do
    local sm = LEVEL_MULT[p.level] or 1.0
    for _, e in ipairs(Units[p.id].effects or {}) do
      if e.trigger == "combat_start" and e.op == "shield_caster" then
        local pa = e.params or {}
        local tgt = {}
        for _, nb in ipairs(self.board:neighbors(p.slot)) do if self.slotRigs[nb] then tgt[#tgt + 1] = nb end end
        casters[p.slot] = { baseValue = (pa.value or 20) * sm, cd = pa.cd or 240, reflect = pa.reflect or 0,
          overcharge = pa.overcharge or false, valueInc = 0, cdr = 0, radius = false, targetSlots = tgt }
      end
    end
  end
  if next(casters) then
    for _, p in ipairs(placed) do -- renforts : aura_shield d'un voisin du caster
      for _, e in ipairs(Units[p.id].effects or {}) do
        if e.trigger == "combat_start" and e.op == "aura_shield" then
          local pa = e.params or {}
          for _, nb in ipairs(self.board:neighbors(p.slot)) do
            local c = casters[nb]
            if c then
              c.valueInc = c.valueInc + (pa.valueInc or 0)
              c.cdr = c.cdr + (pa.cdr or 0)
              if pa.reflect then c.reflect = math.max(c.reflect, pa.reflect) end
              if pa.overcharge then c.overcharge = true end
              if pa.radius then c.radius = true end
            end
          end
        end
      end
    end
    for slot, c in pairs(casters) do -- finalise + CAPS (value ×3 / cd plancher 2 s / reflect 0.60 / rayon 2)
      if c.radius then
        local seen = {}; for _, s in ipairs(c.targetSlots) do seen[s] = true end
        local extra = {}
        for _, s in ipairs(c.targetSlots) do
          for _, nb2 in ipairs(self.board:neighbors(s)) do
            if self.slotRigs[nb2] and nb2 ~= slot and not seen[nb2] then seen[nb2] = true; extra[#extra + 1] = nb2 end
          end
        end
        for _, s in ipairs(extra) do c.targetSlots[#c.targetSlots + 1] = s end
      end
      c.value = Stats.resolve(c.baseValue, c.valueInc > 0 and { Stats.increased(c.valueInc) } or nil,
        { max = c.baseValue * 3, round = "nearest" })
      c.cd = math.max(120, math.floor(c.cd * (1 - math.min(0.5, c.cdr))))
      c.reflect = math.min(0.6, c.reflect)
    end
  end

  local b = Place.bounds(placed)
  local comp = {}
  for _, p in ipairs(placed) do
    local u = Units[p.id]
    local x, y = Place.pos(p.col, p.row, side, b)
    -- depth (0 = front) + row dérivés de la forme -> exposition portée par le sigil (ciblage déterministe).
    local m = LEVEL_MULT[p.level] or 1.0 -- duplicatas : les stats scalent avec le niveau
    comp[#comp + 1] = { id = p.id, slot = p.slot, level = p.level,
      hp = math.floor(u.hp * m + 0.5), dmg = math.floor(u.dmg * m + 0.5), cd = u.cd,
      depth = b.maxC - p.col, row = p.row, effects = auraEffects(p.id, p.slot),
      shield = shield[p.slot] or 0, poisonInc = poisonInc[p.slot], burnInc = burnInc[p.slot],
      shieldCaster = casters[p.slot] and { value = casters[p.slot].value, cd = casters[p.slot].cd,
        reflect = casters[p.slot].reflect, overcharge = casters[p.slot].overcharge,
        targetSlots = casters[p.slot].targetSlots } or nil,
      x = x, y = y, facing = facing }
  end
  return comp
end

function Build:buildLeftComp()
  return self:buildComp(-1)
end

-- levelBump (défaut 0) : niveau d'escalade tardive ajouté à chaque unité (cf. pickEncounter). bump=0 + unités
-- sans `level` -> LEVEL_MULT[1]=1.0 = stats de base -> GOLDEN-SAFE (golden appelle buildRightComp sans bump).
function Build:buildRightComp(enc, levelBump)
  levelBump = levelBump or 0
  local b = Place.bounds(enc.units)
  local comp = {}
  for _, e in ipairs(enc.units) do
    local u = Units[e.id]
    local lvl = math.min(MAX_LEVEL, (e.level or 1) + levelBump)
    local m = LEVEL_MULT[lvl] or 1.0
    local x, y = Place.pos(e.col, e.row, 1, b)
    comp[#comp + 1] = { id = e.id, level = lvl,
      hp = math.floor(u.hp * m + 0.5), dmg = math.floor(u.dmg * m + 0.5), cd = u.cd,
      depth = b.maxC - e.col, row = e.row,
      shield = 0, x = x, y = y, facing = -1 }
  end
  return comp
end

-- Build LOGIQUE pour un SNAPSHOT (pilier #3) : {id, level, col, row} des unités posées. Position-indépendant
-- (les positions de combat sont re-dérivées par Snapshot.toComp via Place, par côté).
function Build:snapshotUnits()
  local out = {}
  for i = 1, 9 do
    local sr = self.slotRigs[i]
    if sr then
      local c = self.board.shape.cells[i]
      out[#out + 1] = { id = sr.id, level = sr.level or 1, col = c.x, row = c.y }
    end
  end
  return out
end

function Build:startCombat()
  local left = self:buildLeftComp()
  if #left == 0 then return end -- il faut au moins une unité posée
  if self.host.run then self.host.run:applyRelics(left) end -- reliques : effet RÉEL sur la compo joueur (build)
  local enc, bump = self:pickEncounter()
  self.combatCount = self.combatCount + 1
  -- Seed choisi ICI (couche scène) : il fait partie du snapshot/replay. Tiré du RNG seedé du run
  -- (rejouabilité), avec repli sur le RNG global hors-run (tests). La SIM ne lira que ce seed.
  local seed = (self.host.run and self.host.run:nextCombatSeed()) or love.math.random(1, 2147483647)
  -- SNAPSHOT ASYNC (pilier #3) : on SERT un adversaire depuis le pool (ghost d'un AUTRE build figé) ou,
  -- au cold-start, l'équipe IA (Encounter). Pick SEEDÉ par le seed de combat -> rejouable, sans consommer
  -- le RNG du run. Puis on fige NOTRE build dans le pool pour les adversaires FUTURS (jamais en direct).
  local version, tier = "0.7", (self.host.run and self.host.run.wins) or 0
  local right, oppMeta = Snapstore.serveComp(version, tier, 1,
    love.math.newRandomGenerator(seed), self:buildRightComp(enc, bump))
  Snapstore.save(Snapshot.capture(self:snapshotUnits(), Shapes.order[self.shapeIdx], seed,
    { version = version, tier = tier }))
  self.host.goto("combat",
    { left = left, right = right, enemyKey = enc.key, seed = seed, oppSource = oppMeta and oppMeta.source })
end

-- ── Update ──
function Build:update(frameDt)
  self.t = self.t + frameDt
  -- synchronise le rect REROLL (ligne pleine sans grant / scindée avec) AVANT le survol/hit-test.
  self:syncEcoRects(self.host.run and self.host.run.pendingSlotGrant)
  -- JUICE (remplace Forge.uiTick) : avance easings + fire les actions différées (le COMBAT diffère de ~120 ms
  -- pour qu'on VOIE les yeux du CTA réagir avant la bascule de scène). Survol des 4 boutons -> glow/lift animés.
  Feel.update(frameDt)
  local run0 = self.host.run
  Feel.hover("build.combat", inRect(self.mx, self.my, self.button))
  if run0 then
    Feel.hover("build.reroll", inRect(self.mx, self.my, self.rerollBtn))
    Feel.hover("build.raise", inRect(self.mx, self.my, self.raiseBtn))
    Feel.hover("build.decline", (run0.pendingSlotGrant and inRect(self.mx, self.my, self.declineBtn)) or false)
  end
  self.ambient:update(frameDt)
  if self.host.run and self.board.activeCount ~= self.host.run.slots then self:syncSlots() end
  for i, sr in pairs(self.slotRigs) do
    local p = self.pos[i]
    sr.char.x, sr.char.y = p.x, p.y + 9
    Rig.update(sr.char, self.t, frameDt)
  end
  for _, c in pairs(self.previewRigs) do Rig.update(c, self.t, frameDt) end
  if self.drag then
    self.drag.char.x, self.drag.char.y = self.mx, self.my + 9
    Rig.update(self.drag.char, self.t, frameDt)
  end
end

-- État d'interaction (survol/voisins/cible de drop/survol boutique), calculé une fois par frame et
-- partagé entre drawBack (fonds) et drawOverlay (bordures/texte). Coords souris en espace virtuel.
function Build:computeUi()
  local hover = self:slotAt(self.mx, self.my)
  local ui = { hover = hover, dropTarget = self.drag and hover or nil, nbset = {}, shopHover = self:shopAt(self.mx, self.my) }
  if hover then for _, j in ipairs(self.board:neighbors(hover)) do ui.nbset[j] = true end end
  -- Cible d'INSPECTION (panneau persistant droite) : unité survolée sur le BOARD (slot occupé) d'abord,
  -- sinon en BOUTIQUE. {id, slot?, level?} ou nil (rien sous le curseur -> niche calme).
  if hover and self.slotRigs[hover] then
    ui.inspect = { id = self.slotRigs[hover].id, slot = hover, level = self.slotRigs[hover].level or 1 }
  elseif ui.shopHover and self.host.run and self.host.run.shop[ui.shopHover] then
    ui.inspect = { id = self.host.run.shop[ui.shopHover].id }
  end
  self.uiState = ui -- champ distinct de la méthode (sinon self.uiState renverrait la méthode quand vide)
  return ui
end

-- ── Pre-pass natif (espace design) : atmosphère + arêtes + FONDS (cases / panneau / cartes) ──
-- Tout ce qui doit passer DERRIÈRE les rigs (dessinés ensuite dans le canvas virtuel). pos[i] virtuel ×4.
function Build:drawBack(view)
  self.view = view -- mémorise la vue (drawWorld en a besoin pour clipper l'aperçu dans la carte)
  local ui = self:computeUi()
  local b, run, c = self.board, self.host.run, Theme.c
  Draw.begin(view)
  self.ambient:draw("build")

  -- Arêtes du graphe de synergies (la forme EST le graphe).
  love.graphics.setLineStyle("rough")
  for _, e in ipairs(b.shape.edges) do
    local a, k = e[1], e[2]
    if b.slots[a].unlocked and b.slots[k].unlocked then
      local pa, pk = self.pos[a], self.pos[k]
      local active = (a == ui.hover or k == ui.hover or a == ui.dropTarget or k == ui.dropTarget)
      Draw.setColor(active and c.edgeActive or c.edgeIdle)
      love.graphics.setLineWidth(active and 4 or 3)
      love.graphics.line(pa.x * 4, pa.y * 4, pk.x * 4, pk.y * 4)
    end
  end
  -- Synergies d'adjacence ACTIVES (1.1) : survoler une case OCCUPÉE allume EN OR les arêtes vers
  -- ses voisins OCCUPÉS = la lecture concrète "qui buffe qui". Survol d'une case vide -> les arêtes
  -- restent rouges (active) : "si tu poses ici, tu touches ces voisins". La forme EST le graphe.
  local focus = ui.hover or ui.dropTarget
  if focus and b.slots[focus].unlocked and b.slots[focus].unit then
    for _, j in ipairs(b:neighbors(focus)) do
      if b.slots[j].unlocked and b.slots[j].unit then
        local pf, pj = self.pos[focus], self.pos[j]
        Draw.setColor(c.goldBright or c.gold)
        love.graphics.setLineWidth(5)
        love.graphics.line(pf.x * 4, pf.y * 4, pj.x * 4, pj.y * 4)
      end
    end
  end
  love.graphics.setLineWidth(1)

  -- Fonds des cases + CARTE DE RISQUE (1.2). depth = maxCol - cell.x (0 = front = exposé au ciblage
  -- de colonne). Voile de sang d'autant plus dense que la case est avancée -> rend visible le coût de
  -- placer un carry au front, convertit la frustration RNG en skill de placement (combat-model §4-6).
  -- (l'ÉTAT reste porté par la bordure en overlay, pas par le fond.)
  -- CASES = atomes Slot (6 états du design-system) dessinés ICI, DERRIÈRE le rig d'aperçu (fill opaque +
  -- hachure) : le rig de drawWorld se pose par-dessus. L'état porte tout le décor (bord pierre/voisin sang/
  -- cible verte/survol laiton/scellé) + pip de type + pips de niveau. La carte de risque (voile de sang front)
  -- se superpose ensuite (avant le rig). Priorité d'état : drop > hover > voisin > occupé > vide.
  local minCol, maxCol = math.huge, -math.huge
  for _, cell in ipairs(b.shape.cells) do
    if cell.x < minCol then minCol = cell.x end
    if cell.x > maxCol then maxCol = cell.x end
  end
  local spanCol = math.max(1, maxCol - minCol)
  local S = SLOT_HALF * 2
  for i = 1, 9 do
    local p, slot = self.pos[i], b.slots[i]
    local x, y = p.x * 4 - SLOT_HALF, p.y * 4 - SLOT_HALF
    local sr = self.slotRigs[i]
    local state
    if not slot.unlocked then state = "locked"
    elseif i == ui.dropTarget then state = "drop"
    elseif i == ui.hover then state = "hover"
    elseif ui.nbset[i] then state = "neighbor"
    elseif sr then state = "selected"
    else state = "empty" end
    Slot.draw(x, y, S, state, sr and { typePip = Units[sr.id].type, level = sr.level or 1 } or nil)
    -- carte de risque : voile de sang d'autant plus dense que la case est avancée (front exposé au ciblage).
    local cell = b.shape.cells[i]
    if slot.unlocked and cell then
      local expo = 1 - (maxCol - cell.x) / spanCol
      if expo > 0.001 then
        Draw.setColor({ c.edgeActive[1], c.edgeActive[2], c.edgeActive[3], 0.16 * expo })
        love.graphics.rectangle("fill", x, y, S, S)
      end
    end
  end

  -- THE OFFERING (bas) : fond de bande sobre + FOND de chaque carte (dégradé propre + liseré teinté), DERRIÈRE
  -- le rig d'aperçu (drawWorld) ; le contenu (pip/nom/coût/chips) est posé en overlay. Le liseré LIT le TYPE de
  -- la créature (or vif au survol, sourd hors budget) ; Panel enregistre la box -> anneau de distorsion onirique.
  if self.offering then Draw.rect(self.offering.x, self.offering.y, self.offering.w, self.offering.h, c.stone900) end
  if run then
    for i, rect in ipairs(self.shopSlots) do
      local o = run.shop[i]
      if o then
        local x, y, w, h = rect.x * 4, rect.y * 4, rect.w * 4, rect.h * 4
        if o.sold then
          Draw.rect(x, y, w, h, c.void, c.iron, 1)
        else
          local aff = run.gold >= o.cost
          local hot = (ui.shopHover == i)
          local utype = Units[o.id] and Units[o.id].type
          local border
          if not aff then border = c.iron
          elseif hot then border = c.gold
          else border = (utype and Theme.type(utype).color) or c.iron end
          Panel.draw(x, y, w, h, { fill1 = hot and c.stone700 or c.stone800, fill2 = c.stone900, border = border, hi = aff })
        end
      end
    end
  end

  Draw.finish()
end

-- ── Rendu monde (canvas virtuel, pixel-perfect) : UNIQUEMENT les rigs (unités/aperçus/drag) ──
-- Toutes les créatures sont AJUSTÉES À LEUR CONTENEUR (fit-to-box, cf. rigFitScale) -> aucune ne déborde
-- ni n'est coupée par le bord de sa case / carte. update() pose char.x,char.y ; on les SCALE à l'affichage.
function Build:drawWorld()
  local b = self.board
  -- CASE : 80 design = 20 virtuel. Zone utile (hors cadre forge) ~18 virtuel. On vise une boîte ~18×18
  -- avec marge -> la créature REMPLIT la case sans déborder ni être coupée, pieds calés au sol de la case.
  local CELL_FIT_W, CELL_FIT_H = 18, 18
  for i, sr in pairs(self.slotRigs) do
    if b.slots[i].unlocked then
      local c = sr.char
      -- maxScale 1.5 : on grossit un peu les petites créatures pour qu'elles remplissent la case (sans couper).
      local s = self:rigFitScale(sr.id, CELL_FIT_W, CELL_FIT_H, 0.94, 1.5)
      local bnd = self:rigBounds(sr.id)
      love.graphics.push()
      -- on scale AUTOUR du SOL de la case : char.y = p.y+9 ; le sol visé est ~le bas de la case (p.y + ~9).
      -- On pose les pieds (bnd.bot) au sol puis on rétrécit autour de ce point -> créature centrée et footée.
      local groundX = math.floor(c.x + 0.5)
      local groundY = math.floor(c.y + 0.5) + 1
      love.graphics.translate(groundX, groundY)
      love.graphics.scale(s, s)
      love.graphics.translate(0, -bnd.bot)
      local sx, sy = c.x, c.y
      c.x, c.y = 0, 0
      Rig.draw(c)
      c.x, c.y = sx, sy
      love.graphics.pop()
    end
  end
  local run = self.host.run
  if run then
    for i, rect in ipairs(self.shopSlots) do
      local o = run.shop[i]
      if o then Bestiary.mark(o.id) end -- BESTIAIRE : une offre vue en boutique = créature rencontrée (idempotent)
      if o and not o.sold then
        local c = self.previewRigs[o.id]
        if c then
          -- aperçu AJUSTÉ à la région créature de la carte (flex en haut, au-dessus du bloc nom/coût) ->
          -- la créature tient ENTIÈREMENT dans la carte, jamais coupée. Région ≈ carte moins l'inset (8) et
          -- les deux rangées d'info (~32 design) en bas. Pieds calés au-dessus du bloc nom/coût.
          local artH = math.max(20, rect.h - 12) -- hauteur de la région créature (virtuel)
          local artW = rect.w - 4
          -- maxScale 1.8 : on grossit les petites créatures pour qu'elles remplissent la carte (sans couper).
          local s = self:rigFitScale(o.id, artW, artH, 0.9, 1.8)
          local bnd = self:rigBounds(o.id)
          local feet = rect.y + rect.h - 14
          if self.view then Draw.scissor(self.view, rect.x * 4, rect.y * 4, rect.w * 4, rect.h * 4) end
          love.graphics.push()
          love.graphics.translate(rect.x + rect.w / 2, feet)
          love.graphics.scale(s, s)
          love.graphics.translate(0, -bnd.bot)
          c.x, c.y, c.facing = 0, 0, 1
          Rig.draw(c)
          love.graphics.pop()
          if self.view then Draw.noScissor() end
        end
      end
    end
  end
  -- INSPECTEUR : rig de l'unité survolée rendu DANS la niche du panneau (même mécanique fit-to-box que les
  -- cases/cartes). Niche = top 88px du panneau d'inspection (cohérent avec _drawInspector).
  local insp = self.uiState and self.uiState.inspect
  if insp and self.inspector then
    local rg = self.previewRigs[insp.id]
    if rg then
      local nx, ny, nw, nh = self.inspector.x, self.inspector.y, self.inspector.w, 88
      local nb = self:rigBounds(insp.id)
      local s = self:rigFitScale(insp.id, nw / 4 - 4, nh / 4 - 5, 0.84, 3)
      if self.view then Draw.scissor(self.view, nx + 1, ny + 1, nw - 2, nh - 2) end
      love.graphics.push()
      love.graphics.translate((nx + nw / 2) / 4, (ny + nh - 8) / 4)
      love.graphics.scale(s, s)
      love.graphics.translate(0, -nb.bot)
      rg.x, rg.y, rg.facing = 0, 0, 1
      Rig.draw(rg)
      love.graphics.pop()
      if self.view then Draw.noScissor() end
    end
  end
  if self.drag then Rig.draw(self.drag.char) end
  love.graphics.setColor(1, 1, 1, 1)
end

-- ── Overlay (espace design, texte net) : cadre + HUD + sigil + board + OFFERING + inspecteur (§B.1) ──
function Build:drawOverlay(view)
  local b, run, c = self.board, self.host.run, Theme.c
  local ui = self.uiState or self:computeUi()
  Draw.begin(view)

  -- 1) CADRE RELIQUAIRE partagé (ScreenFrame) : bande de pierre gravée plein écran + onglet « BUILD ».
  ScreenFrame.draw(T("scene.build"):upper(), { ft = FRAME_FT })

  -- 2) BARRE HUD (GOLD / LIVES / DESCENT / ROUND / STREAK / TIER) ou repli sandbox.
  if run then self:_drawHudBar(run)
  else Draw.textC(T("ui.placed_count", { placed = self:placedCount(), active = b.activeCount }),
    self.hudBar.x + self.hudBar.w / 2, self.hudBar.y + 16, c.faint, Theme.label(11)) end

  -- 3) EN-TÊTE DE SIGIL (nom + keyword) + boutons de RESHAPE. Prompt de grant juste en dessous.
  self:_drawSigilHeader()
  if run and run.pendingSlotGrant then
    Draw.textC(T("ui.slot_grant"), self.boardRegion.x + self.boardRegion.w / 2, self.sigilBar.y + SIGIL_H + 6,
      c.gold, Theme.label(10))
  end

  -- 4) NOMS d'unités (sous les cases) + « + » de cible (Slot dessine le reste du décor en drawBack).
  local granting = run and run.pendingSlotGrant
  local S = SLOT_HALF * 2
  for i = 1, 9 do
    local p, slot = self.pos[i], b.slots[i]
    if not slot.unlocked then
      if granting then Draw.textC("+", p.x * 4, p.y * 4 - 12, c.gold, Theme.subhead(18)) end
    else
      local sr = self.slotRigs[i]
      if sr then Draw.textC(T("unit." .. sr.id .. ".name"), p.x * 4, p.y * 4 - SLOT_HALF + S + 3, c.name, Theme.label(9)) end
    end
  end

  -- 5) THE OFFERING : caption + règle iron + cartes shop + boutons éco + FIGHT (le SEUL CTA sang de l'écran).
  local hb = self.lay.shopHeader
  if hb then
    local capF = Theme.label(9)
    local cap = T("ui.offering")
    Draw.textTrackedL(cap, hb.x, hb.y + (hb.h - capF:getHeight()) / 2, c.ink3, capF, 2)
    local cw = Draw.textWidth(cap, capF) + #cap * 2 + 50
    Draw.setColor(c.iron)
    if love.graphics then love.graphics.rectangle("fill", hb.x + cw, hb.y + hb.h / 2, math.max(0, hb.w - cw), 1) end
    Draw.reset()
  end
  if run then
    for i, rect in ipairs(self.shopSlots) do
      local o = run.shop[i]
      if o then self:drawShopCard(i, rect, o, ui.shopHover == i) end
    end
    self:drawEcoButton("build.reroll", self.rerollBtn, T("ui.reroll_label"), Run.REROLL_COST, run:canReroll())
    if run.pendingSlotGrant then
      self:drawEcoButton("build.decline", self.declineBtn, T("ui.refuse_label"), Run.SLOT_DECLINE_GOLD, true)
    end
    local atMax = run.shopTier >= run.MAX_TIER
    self:drawEcoButton("build.raise", self.raiseBtn, atMax and T("ui.tier_max") or T("ui.buyxp_label"),
      atMax and nil or run.BUY_XP_COST, (not atMax) and run:canBuyXp())
  end
  local enabled = self:placedCount() > 0
  local r = self.button
  local over = inRect(self.mx, self.my, r)
  Button.draw(r.x * 4, r.y * 4, r.w * 4, r.h * 4, "primary", enabled and T("ui.fight") or T("ui.place_unit"),
    { hover = over, disabled = not enabled, feel = Feel.state("build.combat"),
      id = "build.combat", mouse = { mx = self.mx * 4, my = self.my * 4 }, t = self.t / 60 })

  -- 6) INSPECTEUR persistant (colonne droite) : remplace la tooltip de survol (board ET boutique).
  self:_drawInspector(ui)

  -- 7) RELIQUES possédées + infobulle de relique (prioritaire au survol de la rangée).
  self:drawRelicRow()
  local relIdx = run and self:relicAt(self.mx, self.my)
  if relIdx then self:drawRelicTooltip(run.relics[relIdx].id) end

  Draw.finish()
end

-- Carte de boutique = Panel propre (fond + liseré teinté dessinés en drawBack) + contenu en COLONNE qui REMPLIT la carte :
-- [ région créature (flex, l'aperçu de drawWorld y vit) | nom | rangée coût+chips d'affliction ]. Le bas
-- ne flotte jamais : le moteur Layout colle nom/coût/chips au pied de la carte, et la région créature
-- absorbe le reste. États : achetable (or, lit au survol) / hors-budget (sombre) / vendu (SOLD).
-- rect = rect VIRTUEL de la carte ; o = l'offre {id, cost, sold} ; hot = survolée.
function Build:drawShopCard(i, rect, o, hot)
  local c = Theme.c
  local x, y, w, h = rect.x * 4, rect.y * 4, rect.w * 4, rect.h * 4
  local box = { x = x, y = y, w = w, h = h }

  if o.sold then
    Draw.textC(T("ui.sold"), x + w / 2, y + h / 2 - 6, c.ghost, Theme.label(10))
    return
  end
  local aff = (self.host.run.gold >= o.cost)
  local utype = Units[o.id].type

  -- (le FOND + le LISERÉ de la carte sont dessinés en drawBack, DERRIÈRE le rig d'aperçu ; ici = le CONTENU.)
  -- COLONNE interne : région créature (flex) au-dessus du bloc d'info (nom + coût/chips), avec un padding.
  local inner = Layout.inset(box, { l = 8, t = 8, r = 8, b = 8 })
  local rows = Layout.column(inner, { { flex = 1 }, { size = 16 }, { size = 16 } }, { gap = 3, align = "stretch" })
  local nameBox, costBox = rows[2], rows[3]

  -- PIP DE TYPE (haut-gauche), bien typé (flesh/order/bone/arcane/abyss) + halo additif au survol.
  local tcol = Theme.type(utype).color
  Draw.pip(utype, x + 14, y + 14, 6, aff and tcol or c.fainter)
  if hot and aff and love.graphics.setBlendMode and love.graphics.circle then
    love.graphics.setBlendMode("add")
    love.graphics.setColor(tcol[1], tcol[2], tcol[3], 0.32)
    love.graphics.circle("fill", x + 14, y + 14, 9)
    love.graphics.setBlendMode("alpha"); love.graphics.setColor(1, 1, 1, 1)
  end

  -- NOM (Cinzel = police de NOM du système 4-voix, lisible et centrée dans sa rangée).
  local nameCol = aff and c.name or c.dim
  Draw.textC(T("unit." .. o.id .. ".name"), nameBox.x + nameBox.w / 2, nameBox.y + 1, nameCol, Theme.subhead(12))

  -- RANGÉE BAS : chips d'affliction (gauche, ce que l'unité APPLIQUE) + coût (droite, Badge propre).
  local font = Theme.label(8)
  local affl = Keywords.applied(Units[o.id])
  local cx = costBox.x
  for _, k in ipairs(affl) do
    local cw = Chip.draw(cx, costBox.y + 1, { key = k, label = "", icon = true, font = font, h = 13 })
    cx = cx + cw + 3
    if cx > costBox.x + costBox.w - 32 then break end -- ne déborde pas sous le coût (Badge.cost à droite)
  end
  -- COÛT : Badge.cost (losange laiton + nombre Space Mono), RIGHT-aligné (on mesure sa largeur pour finir au
  -- bord droit de la rangée). Vire au sang séché si hors budget -> le prix saute aux yeux et lit le budget.
  local valFont = Theme.value(15)
  local cval = tostring(o.cost)
  local badgeW = 14 + (valFont and valFont:getWidth(cval) or #cval * 8)
  Badge.cost(costBox.x + costBox.w - badgeW, costBox.y, o.cost, aff)
end

-- ── BARRE HUD (§B.1.1) : 6 cellules séparées par des règles iron — GOLD / LIVES / DESCENT (flex) / ROUND /
-- STREAK / TIER. Consolide vies + tier (plus d'orbe de vie). Captions + valeurs en Space Mono.
function Build:_drawHudBar(run)
  local c = Theme.c
  local hb = self.hudBar
  Panel.draw(hb.x, hb.y, hb.w, hb.h, { fill1 = Theme.hex(0x1d1710), fill2 = Theme.hex(0x120d08) })
  local cap, val = Theme.label(8), Theme.value(14)
  local cells = Layout.row(hb, {
    { size = 124 }, { size = 150 }, { flex = 1 }, { size = 84 }, { size = 124 }, { size = 150 },
  }, { gap = 0, align = "stretch" })
  local vy = hb.y + hb.h - 8 - (val and val:getHeight() or 14)
  local function sep(cell) Draw.setColor(c.iron); if love.graphics then love.graphics.rectangle("fill", math.floor(cell.x), hb.y + 6, 1, hb.h - 12) end; Draw.reset() end
  local function capAt(cell, s) Draw.text(s, cell.x + 12, cell.y + 7, c.ink4, cap) end
  local g = cells[1]; capAt(g, T("ui.gold"))
  Badge.diamond(g.x + 16, vy + val:getHeight() / 2, 4, c.gold, c.brassD, c.brassS)
  Draw.text(tostring(run.gold), g.x + 26, vy, c.gold, val)
  sep(cells[2]); local lv, maxL = cells[2], Run.START_LIVES
  capAt(lv, T("ui.lives_orb", { n = run.lives, max = maxL }))
  Gauge.lives(lv.x + 12, vy + 1, run.lives, maxL, 2, 4)
  sep(cells[3]); local de = cells[3]
  local descCap = T("ui.descent") .. " "
  Draw.text(descCap, de.x + 12, de.y + 7, c.ink4, cap)
  Draw.text(run.wins .. "/" .. Run.WIN_TARGET, de.x + 12 + cap:getWidth(descCap), de.y + 7, c.gold, cap)
  Gauge.descent(de.x + 12, vy + 2, de.w - 24, 6, run.wins, Run.WIN_TARGET, 2)
  sep(cells[4]); local ro = cells[4]; capAt(ro, T("ui.round"))
  Draw.text(tostring(run.round), ro.x + 12, vy, c.ink, val)
  sep(cells[5]); local st = cells[5]; capAt(st, T("ui.streak"))
  local won = run.winStreak >= 2
  local sStr = won and T("ui.streak_win", { n = run.winStreak })
    or (run.lossStreak >= 2 and T("ui.streak_loss", { n = run.lossStreak }) or "—")
  Draw.text(sStr, st.x + 12, vy + 1, won and c.gold or (run.lossStreak >= 2 and c.bloodL or c.ink4), Theme.value(12))
  sep(cells[6]); local ti = cells[6]; capAt(ti, T("ui.tier_label") .. " " .. run.shopTier .. "/" .. Run.MAX_TIER)
  for k = 1, Run.MAX_TIER do
    local on = k <= run.shopTier
    Badge.diamond(ti.x + 16 + (k - 1) * 12, vy + val:getHeight() / 2, 4, on and c.gold or c.stone900, on and c.brassD or c.brass, on and c.brassS or nil)
  end
end

-- COMPAT (tests/ui.lua) : ancien point d'entrée HUD `drawBanner` -> délègue à la nouvelle barre HUD, en tolérant
-- un run-stub PARTIEL (le test ne passe pas lives/shopTier). hudBar peut manquer si appelé hors layout -> défaut.
function Build:drawBanner(run)
  run = run or {}
  self.hudBar = self.hudBar or { x = 0, y = 0, w = Draw.W, h = HUD_H }
  self:_drawHudBar(setmetatable({ lives = run.lives or 0, shopTier = run.shopTier or 1 }, { __index = run }))
end

-- ── Glyphe de forme de sigil (carré/croix/anneau/diamant/ligne) centré dans un bouton de reshape.
function Build:_drawShapeGlyph(shape, cx, cy, col)
  if not love.graphics then return end
  Draw.setColor(col)
  local r = 5
  if shape == "croix" then
    love.graphics.setLineWidth(2); love.graphics.line(cx - r, cy, cx + r, cy); love.graphics.line(cx, cy - r, cx, cy + r); love.graphics.setLineWidth(1)
  elseif shape == "anneau" then
    love.graphics.setLineWidth(2); love.graphics.circle("line", cx, cy, r); love.graphics.setLineWidth(1)
  elseif shape == "diamant" then
    love.graphics.push(); love.graphics.translate(cx, cy); love.graphics.rotate(math.pi / 4); love.graphics.rectangle("line", -r + 1, -r + 1, 2 * (r - 1), 2 * (r - 1)); love.graphics.pop()
  elseif shape == "ligne" then
    love.graphics.rectangle("fill", cx - r - 1, cy - 1, 2 * (r + 1), 2)
  else -- carré (défaut)
    love.graphics.rectangle("line", cx - r, cy - r, 2 * r, 2 * r)
  end
  Draw.reset()
end

-- ── EN-TÊTE DE SIGIL (§B.1.2) : GAUCHE = glyphe anneau + « <NOM> » (Cinzel) + « — <keyword> » (Spectral italic)
-- ; DROITE = label [S] RESHAPE + 5 boutons-glyphe (l'actif blood-lit). Rects des boutons posés par computeRegions.
function Build:_drawSigilHeader()
  local c = Theme.c
  local sb = self.sigilBar
  local nm = self.board.shape.name
  if love.graphics then Draw.setColor(c.blood); love.graphics.setLineWidth(2); love.graphics.circle("line", sb.x + 14, sb.y + sb.h / 2, 6); love.graphics.setLineWidth(1); Draw.reset() end
  local nameF, kwF = Theme.heading(15), Theme.flavor(13)
  local label = T("shape." .. nm .. ".label")
  local nx = sb.x + 28
  Draw.text(label, nx, sb.y + (sb.h - nameF:getHeight()) / 2, c.ink, nameF)
  nx = nx + Draw.textWidth(label, nameF) + 10
  Draw.text("— " .. T("shape." .. nm .. ".archetype"), nx, sb.y + (sb.h - kwF:getHeight()) / 2, c.ink3, kwF)
  for _, bt in ipairs(self._sigilBtns) do
    local active = (nm == bt.shape)
    local hot = inRect(self.mx, self.my, bt)
    Draw.rect(bt.dx, bt.dy, bt.ds, bt.ds, active and Theme.hex(0x1a0e10) or Theme.hex(0x100b16),
      active and c.blood or (hot and c.brass or c.iron), 1)
    self:_drawShapeGlyph(bt.shape, bt.dx + bt.ds / 2, bt.dy + bt.ds / 2, active and c.bloodL or c.ink4)
  end
  local first = self._sigilBtns[1]
  if first then
    local rsF = Theme.label(9)
    Draw.textR(T("ui.reshape"), first.dx - 10, sb.y + (sb.h - rsF:getHeight()) / 2, c.ink4, rsF)
  end
end

-- ── INSPECTEUR PERSISTANT (§B.1.3) : carte unité (niche + nom + badge type + barre HP/DMG/CD + passif) +
-- carte ADJACENCY. Montre l'unité survolée (ui.inspect : board d'abord, sinon boutique) ; rien -> niche calme.
-- Le RIG de l'unité est rendu DANS la niche par drawWorld (top 88px). (passive_name/desc = i18n existants.)
function Build:_drawInspector(ui)
  local c = Theme.c
  local ins = self.inspector
  if not ins then return end
  local insp = ui.inspect
  local nicheH, cardGap, adjH = 88, 11, 120
  local unitH = ins.h - adjH - cardGap
  Panel.draw(ins.x, ins.y, ins.w, unitH, { fill1 = Theme.hex(0x16121f), fill2 = Theme.hex(0x0c0913) })
  Panel.niche(ins.x + 1, ins.y + 1, ins.w - 2, nicheH - 1)
  local ay = ins.y + unitH + cardGap
  Panel.draw(ins.x, ay, ins.w, adjH, { fill1 = Theme.hex(0x0b0912), fill2 = Theme.hex(0x0b0912) })

  if not insp then
    Draw.textC(T("ui.inspect_empty"), ins.x + ins.w / 2, ins.y + nicheH + 26, c.ink4, Theme.flavor(12))
    Draw.textTrackedL(T("ui.adjacency"), ins.x + 12, ay + 12, c.ink3, Theme.label(8), 1.5)
    return
  end

  local id = insp.id
  local U = Units[id]
  local bodyX = ins.x + 13
  Draw.textC(T("ui.sprite") .. " · " .. id, ins.x + ins.w / 2, ins.y + nicheH - 13, c.ink4, Theme.label(8))
  local cy = ins.y + nicheH + 10
  Draw.text(T("unit." .. id .. ".name"), bodyX, cy, c.ink, Theme.heading(14))
  local typeStr = T("type." .. U.type):upper()
  local badgeF = Theme.label(8)
  local bw = badgeF:getWidth(typeStr) + 20
  local bx = ins.x + ins.w - 13 - bw
  Draw.rect(bx, cy - 1, bw, 16, Theme.hex(0x100d16), Theme.hex(0x473a2c), 1)
  Draw.pip(U.type, bx + 7, cy + 7, 3)
  Draw.text(typeStr, bx + 13, cy + 2, Theme.type(U.type).color, badgeF)
  cy = cy + 24
  Draw.rect(bodyX, cy, ins.w - 26, 22, Theme.hex(0x0a0810), c.iron, 1)
  local lf, vf = Theme.label(9), Theme.value(10)
  local sx = bodyX + 10
  local stats = { { T("ui.stat_hp"), tostring(U.hp) }, { T("ui.stat_dmg"), tostring(U.dmg) }, { T("ui.stat_cd"), string.format("%.0fs", (U.cd or 60) / 60) } }
  for _, s in ipairs(stats) do
    Draw.text(s[1], sx, cy + 6, c.ink3, lf); sx = sx + lf:getWidth(s[1]) + 4
    Draw.text(s[2], sx, cy + 6, c.ink, vf); sx = sx + vf:getWidth(s[2]) + 13
  end
  cy = cy + 30
  local pName = T("unit." .. id .. ".passive_name")
  if pName ~= ("unit." .. id .. ".passive_name") then
    Draw.text(pName, bodyX, cy, c.gold, Theme.label(9)); cy = cy + 15
    Draw.textWrap(T("unit." .. id .. ".passive_desc"), bodyX, cy, ins.w - 26, c.ink2, Theme.body(12))
  end
  self:_drawAdjacency(insp, ins.x + 12, ay + 10, ins.w - 24)
end

-- ── Contenu de la carte ADJACENCY : « ADJACENCY · N LINKS » + une puce colorée (type) par voisin OCCUPÉ.
-- (Version pragmatique : noms des voisins ; la prose par-effet du mockup — « taunt active », « venom seeps »
-- — viendra dans une passe d'enrichissement.)
function Build:_drawAdjacency(insp, x, y, w)
  local c = Theme.c
  local nbrs = {}
  if insp.slot then
    for _, j in ipairs(self.board:neighbors(insp.slot)) do
      if self.slotRigs[j] then nbrs[#nbrs + 1] = self.slotRigs[j].id end
    end
  end
  Draw.textTrackedL(T("ui.adjacency") .. " · " .. #nbrs .. " " .. T("ui.links"), x, y, c.ink3, Theme.label(8), 1.5)
  y = y + 18
  if #nbrs == 0 then
    Draw.text(insp.slot and T("ui.no_neighbours") or T("ui.in_offering"), x, y, c.ink4, Theme.flavor(12))
    return
  end
  local bf = Theme.body(11)
  for _, nid in ipairs(nbrs) do
    local col = Theme.type(Units[nid].type).color
    Draw.setColor(col); if love.graphics then love.graphics.rectangle("fill", x, y + 4, 8, 8) end; Draw.reset()
    Draw.text(T("unit." .. nid .. ".name"), x + 14, y, c.ink2, bf)
    y = y + 16
  end
end

-- Bouton d'économie (REROLL / REFUSER / BUY XP) = Button « eco » propre (+ coût en losange or via opts.cost).
-- rect en virtuel. id = clé Feel (survol/press) stable ; label = texte ; cost = or ; enabled = grise si faux.
function Build:drawEcoButton(id, rect, label, cost, enabled)
  local hot = inRect(self.mx, self.my, rect)
  Button.draw(rect.x * 4, rect.y * 4, rect.w * 4, rect.h * 4, "eco", label,
    { cost = cost, hover = hot, disabled = not enabled, feel = Feel.state(id), id = id })
end

-- ── Fiche monstre (carte propre, au survol) ────────────────────────────────────────────────────────
-- Carte MINIMALE (révision Kévin) : on garde le strict utile, on rend l'info lisible. Fond = Panel propre
-- (dégradé + liseré iron, src/render/monstercard.lua) + contenu PAR-DESSUS : header (nom Cinzel + coût Badge)
-- > portrait > identité (pip+type+famille+rareté)
-- > div > STATS en value-tags (HP/DMG/CD) > div > CAPACITÉS (chips d'affliction à valeurs + nom de passif
-- + description LISIBLE) > flavor. PAS de chip de RÔLE (le joueur déduit tank/carry de la VIE + des
-- capacités) ni de doublon d'affliction (les afflictions vivent UNIQUEMENT dans la section capacités).
-- Suit le curseur, rebond sur les bords. Survol PLATEAU et BOUTIQUE. PUR-RENDER (golden inchangé).

-- ── FICHE de monstre = src/render/monstercard.lua (extraite de l'ancien Build:drawTooltip + helpers) ──
-- Le build n'en garde qu'un MINCE wrapper : il passe le contexte (vue/palette/curseur/horloge) + son rig
-- d'aperçu ANIMÉ (portrait qui respire, comme avant). Les helpers historiques (afflValue/tokenizeValues/
-- drawDescLine) restent EXPOSÉS via Build pour la rétrocompat (tests/ui.lua), en délégation au module —
-- plus aucune duplication. C'est la réutilisation visée (même fiche pour build ET Chronique).
Build.afflValue = MonsterCard.afflValue
Build.tokenizeValues = MonsterCard.tokenizeValues
function Build:drawDescLine(line, x, y, font, baseCol, aff, maxW)
  return MonsterCard.drawDescLine(line, x, y, font, baseCol, aff, maxW)
end

-- Infobulle d'unité (survol plateau / boutique) : la FICHE de monstre, ancrée au curseur. On passe le rig
-- d'APERÇU (animé) pour que le portrait respire à l'identique de l'ancienne carte ; bake/bounds via MiniRig.
function Build:drawTooltip(id)
  MonsterCard.draw(self.view, self.palette, id, self.mx * 4, self.my * 4, self.t / 60,
    { rig = self.previewRigs[id] })
end

-- Rangée de reliques possédées : SOCLES = atome Slot (« hover » au survol, « empty » au repos) bordant
-- l'artefact baké (RelicGen.cached, qui porte sa propre couleur de famille).
function Build:drawRelicRow()
  local run = self.host.run
  if not run or #run.relics == 0 then return end
  local hov = self:relicAt(self.mx, self.my)
  for i, rel in ipairs(run.relics) do
    local r = self:relicRowRect(i)
    -- socle = atome Slot (carré) : allumé (« hover ») au survol, sobre (« empty ») sinon. L'artefact baké
    -- (RelicGen) se pose au centre ; son propre liseré porte déjà la couleur de famille de la relique.
    Slot.draw(r.x, r.y, r.w, (hov == i) and "hover" or "empty")
    local baked = RelicGen.cached(rel.id, self.palette)
    if baked and baked.image then
      love.graphics.setColor(1, 1, 1, 1)
      love.graphics.draw(baked.image, r.x + RELIC_FRAME, r.y + RELIC_FRAME, 0, RELIC_ICON_SCALE, RELIC_ICON_SCALE)
    end
  end
  Draw.reset()
end

-- Infobulle de relique (survol de la rangée) = Panel propre (même langage que src/scenes/relicpick.lua) :
-- dégradé + liseré d'accent de famille + gem (Badge.diamond) + nom (Cinzel) + effet clair (or) + flavor (Spectral).
-- Suit le curseur, rebond sur les bords. PUR-RENDER (golden inchangé).
function Build:drawRelicTooltip(id)
  local c = Theme.c
  local fam = RELIC_TYPE[id] or "bone"
  local emblem = Theme.type(fam)
  local fontE, fontF = Theme.body(13), Theme.flavor(13)
  local W, PAD = 300, 20
  local contentW = W - PAD * 2

  -- MESURE : header (gem+nom) + effet enroulé + flavor enroulé -> hauteur exacte (jamais cramé).
  local effStr, flavStr = T("relic." .. id .. ".effect"), T("relic." .. id .. ".flavor")
  local _, eLines = fontE:getWrap(effStr, contentW)
  local _, fLines = fontF:getWrap(flavStr, contentW)
  local headH, effH = 26, #eLines * (fontE:getHeight() + 2)
  local flavH = #fLines * (fontF:getHeight() + 1)
  local h = PAD + headH + 10 + effH + 10 + flavH + PAD

  -- POSITION : suit le curseur, rebond sur les bords.
  local x, y = self.mx * 4 + 18, self.my * 4 + 10
  if x + W > Draw.W then x = self.mx * 4 - W - 18 end
  if x < 4 then x = 4 end
  if y + h > Draw.H then y = Draw.H - h - 6 end
  if y < 4 then y = 4 end
  x, y = math.floor(x), math.floor(y)

  -- FOND PROPRE (Panel : dégradé sombre + liseré iron + liseré d'accent de la famille). Panel marque la box.
  Panel.draw(x, y, W, h, { fill1 = c.stone800, fill2 = c.stone900, border = c.iron, accent = emblem.color })

  -- CONTENU posé par-dessus, en colonne Layout.
  local inner = Layout.inset({ x = x, y = y, w = W, h = h }, PAD)
  local rows = Layout.column(inner, {
    { size = headH },         -- 1 gem + nom
    { size = effH + 10 },     -- 2 effet clair (or)
    { flex = 1 },             -- 3 flavor (pied)
  }, { gap = 0, align = "stretch" })
  local rHead, rEff, rFlav = rows[1], rows[2], rows[3]

  -- (1) HEADER : gem de famille (Badge.diamond) + nom (Cinzel, police de NOM du système 4-voix).
  local midH = rHead.y + rHead.h / 2
  Badge.diamond(rHead.x + 5, midH, 4, emblem.color, emblem.dark, c.brassS)
  Draw.text(T("relic." .. id .. ".name"), rHead.x + 16, rHead.y + 1, c.title, Theme.heading(15))

  -- (2) EFFET CLAIR (or vif) : le coeur du modèle lisible.
  Draw.textWrap(effStr, rEff.x, rEff.y, rEff.w, c.goldBright, fontE)

  -- (3) FLAVOR (serif d'ambiance, éteint).
  Draw.textWrap(flavStr, rFlav.x, rFlav.y, rFlav.w, c.dim, fontF)
end

return Build
