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
local Critter = require("src.render.critter") -- rendu VIVANT (cadre natif : taille relative + mouvement par-pixel/famille)
local Encounters = require("src.data.encounters")
local OppGen = require("src.data.oppgen") -- A4 : générateur d'adversaire procédural scalé au stade (déterministe)
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
local Dividers = require("src.ui.dividers") -- séparateurs laiton/sang propres
local Feel = require("src.ui.feel")      -- JUICE : survol (glow/lift) + press (squash/flash) + action différée
local Layout = require("src.ui.layout") -- MOTEUR de layout flex (alignement parfait, fill-to-container)
local Keywords = require("src.ui.keywords") -- registre afflictions (mini-chips de carte)
local Chip = require("src.ui.chip") -- pastilles keyword (icône d'affliction)
local Ambient = require("src.fx.ambient")
local Rarity = require("src.gen.rarity") -- rang -> couleur de cadre + glow (accent de rareté de la fiche)
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
local BOARD_OY = 76 -- centre du plateau (virtuel) : ×4 = 304 design, REMONTÉ pour dégager le BANC sous le plateau
local BOARD_HALF_W = 128 -- demi-étendue MAX (virtuelle) des CENTRES de cases -> board centré, jamais hors zone
local BOARD_HALF_H = 30  -- (idem vertical) : RESSERRÉ pour qu'un sigil étalé ne morde pas sur le banc
local BENCH_SIZE = 7 -- BANC (réserve hors-combat) : rangée de slots sous le plateau pour STOCKER/FUSIONNER (n'entre jamais en combat)
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
    slotRigs = {},     -- [slot] = { id, char } : unités posées (PLATEAU = combat)
    bench = {},        -- [i] = { id, level, char } : RÉSERVE hors-combat (stock/fusion ; n'entre PAS en combat)
    previewRigs = {},  -- [id] = char idle (aperçu boutique)
    drag = nil,        -- { id, char, fromSlot? | fromShop? }
    mx = -100, my = -100,
    combatCount = 0,
  }, Build)
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

-- Centre la forme courante dans la moitié haute du canvas.
function Build:computeLayout()
  local cells = self.board.shape.cells
  local minx, maxx, miny, maxy = math.huge, -math.huge, math.huge, -math.huge
  for _, c in ipairs(cells) do
    minx = math.min(minx, c.x); maxx = math.max(maxx, c.x)
    miny = math.min(miny, c.y); maxy = math.max(maxy, c.y)
  end
  local mx, my = (minx + maxx) / 2, (miny + maxy) / 2
  -- SPACING ADAPTATIF : on resserre pour que TOUTE forme (3×3, croix/diamant 4×4, anneau, ligne 8×0) tienne
  -- dans la zone du board, centrée -> plus de débordement. Plafonné à SPACING (les petites ne gonflent pas).
  local sp = SPACING
  local extX, extY = maxx - minx, maxy - miny
  if extX > 0 then sp = math.min(sp, 2 * BOARD_HALF_W / extX) end
  if extY > 0 then sp = math.min(sp, 2 * BOARD_HALF_H / extY) end
  local ox, oy = self.vw / 2, BOARD_OY
  self.pos = {}
  for i, c in ipairs(cells) do
    self.pos[i] = {
      x = math.floor(ox + (c.x - mx) * sp + 0.5),
      y = math.floor(oy + (c.y - my) * sp + 0.5),
    }
  end
end

-- ── BARRE DU BAS = une RANGÉE flex (moteur Layout) en ESPACE DESIGN ────────────────────────────────
-- [ colonne ORBE DE VIE (gauche) | rangée OFFRES (flex, remplit le milieu) | colonne BOUTONS (droite) ].
-- TOUT est aligné/snappé, sans trou : la rangée des offres ABSORBE l'espace restant (flex) et chaque carte
-- a la MÊME taille avec des gouttières ÉGALES ; l'orbe REMPLIT la hauteur de sa colonne (pas un petit orbe
-- flottant dans une grande boîte). Les widgets forge sont BAKÉS À LA TAILLE CALCULÉE (fill réel). On
-- calcule les rects DESIGN une fois ; les hit-tests souris (en VIRTUEL) sont dérivés (÷4) -> self.shopSlots.
local STRIP = { x = 16, y = 564, w = 1280 - 32, h = 720 - 564 - 12 } -- bandeau du bas (design), marges propres
local STRIP_GAP = 18

function Build:computeShop()
  -- 1) découpe principale : orbe (largeur fixe) | offres (flex) | boutons (largeur fixe).
  local cols = Layout.row(STRIP, {
    { size = 116 },  -- colonne orbe de vie
    { flex = 1 },    -- rangée des offres (remplit le milieu)
    { size = 360 },  -- colonne des boutons (COMBAT large + REROLL)
  }, { gap = STRIP_GAP, align = "stretch" })
  self.lay = { orbCol = cols[1], shopBox = cols[2], btnCol = cols[3] }

  -- 2) ORBE DE VIE : colonne [ compteur (fixe) | orbe (flex -> remplit la hauteur restante) ].
  local oc = Layout.column(cols[1], { { size = 16 }, { flex = 1 } }, { gap = 4, align = "stretch" })
  self.lay.lifeLabel = oc[1]
  self.lay.lifeOrbBox = oc[2]

  -- 3) OFFRES : N cartes de MÊME taille avec gouttières ÉGALES qui REMPLISSENT la largeur (flex chacune).
  local specs = {}
  for _ = 1, Run.SHOP_SIZE do specs[#specs + 1] = { flex = 1 } end
  self.lay.cards = Layout.row(cols[2], specs, { gap = 8, align = "stretch" })

  -- 4) BOUTONS : COMBAT (gros, en haut) au-dessus d'une LIGNE éco. COMBAT reste DOMINANT (flex 3) ; la
  -- ligne éco (flex 2) tient les petits boutons. BUY XP (achat d'XP de boutique) occupe TOUJOURS la moitié
  -- gauche. À droite : REROLL seul (pas de grant) OU [ REROLL | REFUSER ] (un grant attend). On calcule
  -- les DEUX dispositions et on choisit à l'affichage selon run.pendingSlotGrant -> jamais de poche vide.
  local bc = Layout.column(cols[3], { { flex = 3 }, { size = 8 }, { flex = 2 } }, { gap = 0, align = "stretch" })
  self.lay.combatBox = bc[1]
  -- la ligne éco se scinde en [ BUY XP | reste ]. BUY XP = moitié gauche, fixe quel que soit le grant.
  local ecoRow = Layout.row(bc[3], { { flex = 1 }, { flex = 1 } }, { gap = 10, align = "stretch" })
  self.lay.raiseBox = ecoRow[1]                           -- BUY XP = achat d'XP de boutique (toujours à gauche)
  self.lay.ecoRowBox = ecoRow[2]                          -- moitié droite : REROLL seul (pas de grant)
  local ecoSplit = Layout.row(ecoRow[2], { { flex = 1 }, { flex = 1 } }, { gap = 10, align = "stretch" })
  self.lay.rerollSplitBox = ecoSplit[1]                  -- REROLL quand un grant attend (1/4 droite gauche)
  self.lay.declineBox = ecoSplit[2]                      -- REFUSER (visible seulement pendant un grant)

  -- 5) hit-tests souris en VIRTUEL (÷4) — dérivés des rects DESIGN du layout (toujours synchrones).
  -- Les rects REROLL/REFUSER sont (re)synchronisés à chaque frame par syncEcoRects(grant) (cf. drawOverlay).
  local function toV(r) return { x = r.x / 4, y = r.y / 4, w = r.w / 4, h = r.h / 4 } end
  self._toV = toV
  self.shopSlots = {}
  for i = 1, Run.SHOP_SIZE do self.shopSlots[i] = toV(self.lay.cards[i]) end
  self.button = toV(self.lay.combatBox)
  self.raiseBtn = toV(self.lay.raiseBox)                  -- BUY XP (achat d'XP de boutique)
  self.declineBtn = toV(self.lay.declineBox)
  self:syncEcoRects(false)
  self:computeBench()
end

-- BANC (réserve) : rangée de BENCH_SIZE slots centrée, juste au-dessus du bandeau boutique. Rects en VIRTUEL
-- (÷4) comme shopSlots -> hit-tests directs, ×4 au rendu. La réserve sert à STOCKER/FUSIONNER, elle ne combat jamais.
function Build:computeBench()
  local SLOT, GAP, Y = 60, 10, 478 -- taille/gouttière/haut de bande (design)
  local total = BENCH_SIZE * SLOT + (BENCH_SIZE - 1) * GAP
  local x0 = math.floor(640 - total / 2 + 0.5) -- centré sur la largeur design (1280)
  self.benchSlots = {}
  for i = 1, BENCH_SIZE do
    local dx = x0 + (i - 1) * (SLOT + GAP)
    self.benchSlots[i] = { x = dx / 4, y = Y / 4, w = SLOT / 4, h = SLOT / 4 } -- VIRTUEL (÷4)
  end
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
  return { x = RELIC_X0 + (i - 1) * RELIC_CELL, y = RELIC_Y, w = s, h = s }
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

-- Indice du slot de BANC sous le curseur (espace virtuel), ou nil.
function Build:benchAt(px, py)
  if not self.benchSlots then return nil end
  for i, r in ipairs(self.benchSlots) do
    if inRect(px, py, r) then return i end
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
    -- Positions UNIFIÉES : plateau (1..9) PUIS banc (1..N), ordre stable -> on garde la 1re copie (plateau prioritaire).
    local order, groups = {}, {} -- groups[key] = liste de { kind="board"|"bench", i } ; order = clés en ordre d'insertion
    local function scan(kind, i, sr)
      if sr and (sr.level or 1) < MAX_LEVEL then
        local key = sr.id .. "\0" .. (sr.level or 1)
        local g = groups[key]; if not g then g = {}; groups[key] = g; order[#order + 1] = key end
        g[#g + 1] = { kind = kind, i = i }
      end
    end
    for i = 1, 9 do scan("board", i, self.slotRigs[i]) end
    for i = 1, BENCH_SIZE do scan("bench", i, self.bench[i]) end
    for _, key in ipairs(order) do -- ipairs (DÉTERMINISTE), jamais pairs
      local g = groups[key]
      if #g >= 3 then
        local keep = g[1]
        local kr = (keep.kind == "board") and self.slotRigs[keep.i] or self.bench[keep.i]
        local id, lvl = kr.id, (kr.level or 1) + 1
        for k = 2, 3 do -- consomme 2 copies (plateau ou banc)
          local p = g[k]
          if p.kind == "board" then self.slotRigs[p.i] = nil; self.board.slots[p.i].unit = nil
          else self.bench[p.i] = nil end
        end
        local promoted = { id = id, level = lvl, char = self:newRig(id) } -- promeut la 1re copie
        if keep.kind == "board" then self.slotRigs[keep.i] = promoted; self.board.slots[keep.i].unit = id
        else self.bench[keep.i] = promoted end
        merged = true
        anyMerge = true
        break -- re-scan (une promotion peut déclencher une cascade)
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
  -- COMBAT : ⭐ ACTION DIFFÉRÉE (Feel) -> les YEUX du CTA réagissent au clic (squash + flash) AVANT la bascule
  -- de scène (~160 ms), pour qu'on SENTE le clic. Le test e2e mûrit l'action via Build:update avant d'asserter.
  if inRect(vx, vy, self.button) then Feel.press("build.combat", function() self:startCombat() end); return end
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
  if si and self.slotRigs[si] then -- ramasse une unité du PLATEAU (réarrangement / vente / vers banc)
    self.drag = { id = self.slotRigs[si].id, level = self.slotRigs[si].level or 1, char = self.slotRigs[si].char, fromSlot = si }
    self.slotRigs[si] = nil
    self.board.slots[si].unit = nil
    return
  end
  local bi = self:benchAt(vx, vy)
  if bi and self.bench[bi] then -- ramasse une unité du BANC (réarrangement / vente / vers plateau)
    self.drag = { id = self.bench[bi].id, level = self.bench[bi].level or 1, char = self.bench[bi].char, fromBench = bi }
    self.bench[bi] = nil
  end
end

function Build:mousereleased(vx, vy, button)
  if button ~= 1 or not self.drag then return end
  local d = self.drag
  self.drag = nil
  local run = self.host.run
  local si = self:slotAt(vx, vy)    -- case PLATEAU sous le curseur
  local bi = self:benchAt(vx, vy)   -- slot BANC sous le curseur

  if d.fromShop then
    -- ACHAT : sur une case plateau débloquée et VIDE, OU un slot de banc VIDE. L'or n'est débité qu'ICI
    -- (placement garanti). Le BANC découple l'achat du placement -> on peut STOCKER des copies pour fusionner.
    local toBoard = si and self.board.slots[si].unlocked and not self.slotRigs[si]
    local toBench = (not toBoard) and bi and not self.bench[bi]
    if toBoard or toBench then
      local id = run and run:buy(d.fromShop)
      if id then
        if toBoard then self.slotRigs[si] = { id = id, level = 1, char = d.char }; self.board.slots[si].unit = id
        else self.bench[bi] = { id = id, level = 1, char = d.char } end
        self:checkMerges() -- 3 copies (même id+niveau, plateau OU banc) -> fusion niveau+1 (arme pendingLevelRelic 1×/round)
        -- Lot 5 (§5.2) : une fusion a armé la récompense de level-up -> offre 1-parmi-3 MID-ROUND (round préservé).
        if self.pendingLevelRelic then
          self.pendingLevelRelic = false
          if self.host.offerLevelUpRelic then self.host.offerLevelUpRelic() end
        end
      end
    end
    return
  end

  -- Déplacement d'une unité EXISTANTE (plateau OU banc ; l'origine a été vidée au pickup).
  if si and self.board.slots[si].unlocked then
    -- -> CASE PLATEAU : place / swap (l'occupant repart vers l'ORIGINE du drag : plateau ou banc).
    local occ = self.slotRigs[si]
    if occ then self:returnDragOrigin(d, occ) end
    self.slotRigs[si] = { id = d.id, level = d.level or 1, char = d.char }
    self.board.slots[si].unit = d.id
  elseif bi then
    -- -> SLOT BANC : place / swap.
    local occ = self.bench[bi]
    if occ then self:returnDragOrigin(d, occ) end
    self.bench[bi] = { id = d.id, level = d.level or 1, char = d.char }
  else
    -- Lâché HORS plateau ET banc : VENTE (remboursement) si run ; sinon l'unité disparaît (sandbox).
    if run and (d.fromSlot or d.fromBench) then run:sell(d.id) end
  end
end

-- Renvoie l'occupant déplacé (occ) vers l'ORIGINE du drag (case plateau ou slot banc) -> swap propre quel que
-- soit le couple source/destination (plateau<->plateau, plateau<->banc, banc<->banc). Appelé UNIQUEMENT pour
-- des drags d'unités existantes (fromSlot/fromBench) ; fromShop est géré plus haut (return).
function Build:returnDragOrigin(d, occ)
  if d.fromSlot then
    self.slotRigs[d.fromSlot] = occ
    self.board.slots[d.fromSlot].unit = occ.id
  elseif d.fromBench then
    self.bench[d.fromBench] = occ
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
  local run = self.host.run
  if run then run:applyRelics(left) end -- reliques : effet RÉEL sur la compo joueur (build)
  self.combatCount = self.combatCount + 1
  -- Seed choisi ICI (couche scène) : il fait partie du snapshot/replay. Tiré du RNG seedé du run
  -- (rejouabilité), avec repli sur le RNG global hors-run (tests). La SIM ne lira que ce seed.
  local seed = (run and run:nextCombatSeed()) or love.math.random(1, 2147483647)
  -- ADVERSAIRE COLD-START (A4) : GÉNÉRÉ et scalé au stade (round/tier/slots), DÉTERMINISTE (rng seedé tiré du
  -- seed de combat). Avec un run -> OppGen ; sans run (sandbox/tests) -> repli sur les encounters pré-construits.
  local enc
  if run then
    enc = OppGen.generate({ round = run.round, tier = run.shopTier, slots = run.slots,
      rng = love.math.newRandomGenerator(seed), odds = run.ODDS })
    enc.key = self:encounterKeyFor(#enc.units) -- nom d'affichage (réutilise les noms pré-construits par taille)
  else
    enc = (self:pickEncounter())
  end
  local aiComp = self:buildRightComp(enc, 0) -- niveaux déjà bakés dans enc.units -> pas de bump
  -- SNAPSHOT ASYNC (pilier #3) : on SERT un adversaire du pool (ghost d'un AUTRE build figé) ou, au cold-start,
  -- l'équipe IA GÉNÉRÉE. Pick SEEDÉ (générateur séparé) -> rejouable. Puis on fige NOTRE build pour les futurs.
  local version, tier = "0.7", (run and run.wins) or 0
  local right, oppMeta = Snapstore.serveComp(version, tier, 1,
    love.math.newRandomGenerator(seed), aiComp)
  Snapstore.save(Snapshot.capture(self:snapshotUnits(), Shapes.order[self.shapeIdx], seed,
    { version = version, tier = tier }))
  self.host.goto("combat",
    { left = left, right = right, enemyKey = enc.key, seed = seed, oppSource = oppMeta and oppMeta.source })
end

-- Nom d'affichage d'un adversaire GÉNÉRÉ : réutilise une clé d'encounter pré-construite par TAILLE (noms déjà
-- traduits) en attendant des noms dédiés. Petit -> patrouille ; plein -> souverain.
function Build:encounterKeyFor(size)
  local idx = math.max(1, math.min(#Encounters, size - 2))
  return Encounters[idx] and Encounters[idx].key or "fallen_patrol"
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
  for i = 1, BENCH_SIZE do -- anime les rigs du BANC (réserve)
    local sr = self.bench[i]
    if sr then Rig.update(sr.char, self.t, frameDt) end
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
  local ui = { hover = hover, dropTarget = self.drag and hover or nil, nbset = {}, shopHover = self:shopAt(self.mx, self.my), benchHover = self:benchAt(self.mx, self.my) }
  if hover then for _, j in ipairs(self.board:neighbors(hover)) do ui.nbset[j] = true end end
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

  -- BANC (réserve, rangée sous le plateau) : même atome Slot (drop/hover/selected/empty) + pip type/niveau si occupé.
  for i = 1, BENCH_SIZE do
    local r = self.benchSlots[i]
    local bx, by, bw = r.x * 4, r.y * 4, r.w * 4
    local sr = self.bench[i]
    local hovering = (ui.benchHover == i)
    local bstate = (self.drag and hovering and "drop") or (hovering and "hover") or (sr and "selected") or "empty"
    Slot.draw(bx, by, bw, bstate, sr and { typePip = Units[sr.id].type, level = sr.level or 1 } or nil)
  end

  -- Bandeau boutique (bas) + FOND de chaque carte = PANNEAUX propres (dégradé sombre + liseré teinté), dessinés
  -- DERRIÈRE le rig d'aperçu (drawWorld) ; le contenu (pip/nom/coût/chips) est posé en overlay. Le liseré LIT le
  -- TYPE de la créature (or vif au survol, sourd hors budget) ; Panel enregistre la box -> anneau de distorsion.
  Draw.rect(0, 556, Draw.W, 164, c.panel)
  Draw.setColor(c.line); love.graphics.setLineWidth(2); love.graphics.line(0, 557, Draw.W, 557); love.graphics.setLineWidth(1)
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
  -- Échelles du rendu VIVANT (cadre natif 64) par surface — placeholders à affiner au screenshot.
  local SLOT_SCALE, SHOP_SCALE, DRAG_SCALE = 0.36, 0.5, 0.36
  for i, sr in pairs(self.slotRigs) do
    if b.slots[i].unlocked then
      local c = sr.char
      -- on cale les pieds au SOL de la case : char.y = p.y+9 ; le sol visé est ~le bas de la case (p.y + ~9).
      local groundX = math.floor(c.x + 0.5)
      local groundY = math.floor(c.y + 0.5) + 1
      if Critter.has(sr.id) then
        -- RENDU VIVANT : cadre natif (taille relative + mouvement par famille), pieds calés au sol.
        Critter.drawAt(nil, sr.id, groundX, groundY, SLOT_SCALE, self.t / 60, c.facing or 1)
      else
        -- fallback rig baké (créatures dessinées-main) : fit-silhouette historique, pieds (bnd.bot) au sol.
        local s = self:rigFitScale(sr.id, CELL_FIT_W, CELL_FIT_H, 0.94, 1.5)
        local bnd = self:rigBounds(sr.id)
        love.graphics.push()
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
  end
  -- RIGS du BANC (réserve) : créatures stockées, rendu vivant à échelle réduite, pieds calés au bas du slot.
  local BENCH_SCALE = 0.3
  for i = 1, BENCH_SIZE do
    local sr = self.bench[i]
    if sr then
      local r = self.benchSlots[i]
      local gx = math.floor(r.x * 4 + r.w * 2 + 0.5)     -- centre X du slot (r.w*4/2 = r.w*2)
      local gy = math.floor(r.y * 4 + r.h * 4 - 4 + 0.5) -- pieds vers le bas du slot
      if Critter.has(sr.id) then
        Critter.drawAt(nil, sr.id, gx, gy, BENCH_SCALE, self.t / 60, 1)
      else
        local s = self:rigFitScale(sr.id, 13, 13, 0.9, 1.4)
        local bnd = self:rigBounds(sr.id)
        love.graphics.push(); love.graphics.translate(gx, gy); love.graphics.scale(s, s); love.graphics.translate(0, -bnd.bot)
        sr.char.x, sr.char.y, sr.char.facing = 0, 0, 1
        Rig.draw(sr.char)
        love.graphics.pop()
      end
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
          -- aperçu calé au-dessus du bloc nom/coût (pieds = bas de la région créature), clippé à la carte.
          local feet = rect.y + rect.h - 14
          if self.view then Draw.scissor(self.view, rect.x * 4, rect.y * 4, rect.w * 4, rect.h * 4) end
          if Critter.has(o.id) then
            -- RENDU VIVANT : cadre natif (taille relative + mouvement par famille).
            Critter.drawAt(nil, o.id, rect.x + rect.w / 2, feet, SHOP_SCALE, self.t / 60, 1)
          else
            -- fallback rig baké : fit-silhouette à la région créature (flex au-dessus du bloc nom/coût).
            local artH = math.max(20, rect.h - 12)
            local artW = rect.w - 4
            local s = self:rigFitScale(o.id, artW, artH, 0.9, 1.8)
            local bnd = self:rigBounds(o.id)
            love.graphics.push()
            love.graphics.translate(rect.x + rect.w / 2, feet)
            love.graphics.scale(s, s)
            love.graphics.translate(0, -bnd.bot)
            c.x, c.y, c.facing = 0, 0, 1
            Rig.draw(c)
            love.graphics.pop()
          end
          if self.view then Draw.noScissor() end
        end
      end
    end
  end
  if self.drag then
    if Critter.has(self.drag.id) then
      Critter.drawAt(nil, self.drag.id, self.drag.char.x, self.drag.char.y, DRAG_SCALE, self.t / 60, self.drag.char.facing or 1)
    else
      Rig.draw(self.drag.char)
    end
  end
  love.graphics.setColor(1, 1, 1, 1)
end

-- ── Overlay (espace design, texte net) : chrome + bordures de case + boutique + boutons + infobulle ──
function Build:drawOverlay(view)
  local b, run, c = self.board, self.host.run, Theme.c
  local ui = self.uiState or self:computeUi()
  Draw.begin(view)

  -- Chrome debug (haut-gauche) : court pour ne pas chevaucher la bannière centrée.
  Draw.text(T("ui.title") .. "  -  " .. T("scene.build"):upper(), 16, 14, c.faint, Theme.ui(11))
  Draw.text(T("ui.controls_build"), 16, 32, c.ghost, Theme.ui(9))

  -- Bannière de run (haut-centre) ou repli sandbox.
  if run then self:drawBanner(run)
  else Draw.textC(T("ui.placed_count", { placed = self:placedCount(), active = b.activeCount }), Draw.W / 2, 22, c.faint, Theme.ui(12)) end

  -- Sigil : gothique en CASSE DE TITRE (les capitales blackletter sont illisibles) + archétype.
  local nm = b.shape.name
  Draw.textC(T("shape." .. nm .. ".label"), Draw.W / 2, 70, c.title, Theme.display(36))
  Draw.textC(T("shape." .. nm .. ".archetype"):upper() .. "    " .. T("ui.reshape"), Draw.W / 2, 118, c.faint, Theme.ui(11))
  -- Prompt de grant d'emplacement (event timé) : pose un slot sur une case libre, ou refuse pour de l'or.
  if run and run.pendingSlotGrant then
    Draw.textC(T("ui.slot_grant"), Draw.W / 2, 134, c.gold, Theme.ui(12))
  end

  -- Décor d'overlay des cases : le SOCKET (atome Slot, 6 états) + pip de type + pips de niveau sont dessinés
  -- en drawBack (DERRIÈRE le rig d'aperçu, fill opaque). Ici on ne pose que ce qui doit passer DEVANT le rig :
  -- le NOM de l'unité (sous la case) et le « + » de cible quand un grant de slot attend (case scellée à remplir
  -- ; sinon la case scellée porte déjà son glyphe de cadenas via Slot « locked »).
  local granting = run and run.pendingSlotGrant
  local S = SLOT_HALF * 2
  for i = 1, 9 do
    local p, slot = self.pos[i], b.slots[i]
    if not slot.unlocked then
      if granting then Draw.textC("+", p.x * 4, p.y * 4 - 12, c.gold, Theme.subhead(18)) end
    else
      local sr = self.slotRigs[i]
      if sr then
        Draw.textC(T("unit." .. sr.id .. ".name"), p.x * 4, p.y * 4 - SLOT_HALF + S + 3, c.name, Theme.label(9))
      end
    end
  end

  -- Boutique : chaque carte = PLAQUE FORGE pleine (fond baké en drawBack) + cadre forge patiné + contenu
  -- mis en page par Layout.column REMPLISSANT la carte (créature / nom / coût+chips d'affliction) -> aucune
  -- poche vide. drawShopCard fait tout le contenu d'overlay.
  if run then
    for i, rect in ipairs(self.shopSlots) do
      local o = run.shop[i]
      if o then self:drawShopCard(i, rect, o, ui.shopHover == i) end
    end
    self:drawEcoButton("build.reroll", self.rerollBtn, T("ui.reroll_label"), Run.REROLL_COST, run:canReroll())
    -- Bouton REFUSER : visible seulement quand un grant de slot attend (sinon les slots ne s'achètent plus).
    if run.pendingSlotGrant then
      self:drawEcoButton("build.decline", self.declineBtn, T("ui.refuse_label"), Run.SLOT_DECLINE_GOLD, true)
    end
    -- BOUTON BUY XP (moitié gauche de la ligne éco) : achète de l'XP de boutique (coût FIXE en diamant).
    -- Au tier MAX, plus rien à acheter -> état « MAX » désactivé (label MAX, AUCUN diamant via cost=nil).
    -- La barre d'XP + la lecture du TIER courant (« TIER n/5 ») sont sous l'orbe de vie (cf. drawLifeOrb).
    local atMax = run.shopTier >= run.MAX_TIER
    self:drawEcoButton("build.raise",
      self.raiseBtn,
      atMax and T("ui.tier_max") or T("ui.buyxp_label"),
      atMax and nil or run.BUY_XP_COST,
      (not atMax) and run:canBuyXp())
  end

  -- ORBE DE VIE (extrême gauche de la barre du bas) : fluide = vies/START_LIVES, compteur au-dessus.
  if run then self:drawLifeOrb(run) end

  -- Bouton COMBAT = le CTA propre (variant "primary") : sang + YEUX cauchemardesques qui s'ouvrent au survol
  -- (glow) et réagissent au clic (flash), regard qui suit le curseur (opts.mouse en espace design). Le juice
  -- (lift/squash/flash/glow) vient de Feel.state ; l'action est différée côté mousepressed. Button marque la box.
  local enabled = self:placedCount() > 0
  local r = self.button
  local over = inRect(self.mx, self.my, r)
  Button.draw(r.x * 4, r.y * 4, r.w * 4, r.h * 4, "primary",
    enabled and T("ui.fight") or T("ui.place_unit"),
    { hover = over, disabled = not enabled, feel = Feel.state("build.combat"),
      id = "build.combat", mouse = { mx = self.mx * 4, my = self.my * 4 }, t = self.t / 60 })

  -- Rangée de reliques possédées (au-dessus de la boutique) + infobulles (relique prioritaire sur unité).
  self:drawRelicRow()
  local relIdx = run and self:relicAt(self.mx, self.my)
  if relIdx then
    self:drawRelicTooltip(run.relics[relIdx].id)
  elseif run and self.xpBarRect and inRect(self.mx, self.my, self.xpBarRect) then
    -- Survol de la barre d'XP -> cotes par rang du tier courant (enseigne « à quoi sert monter »).
    self:drawOddsTooltip(run)
  else
    local id
    local oi = self:shopAt(self.mx, self.my)
    if oi then id = run.shop[oi].id
    else
      local si = self:slotAt(self.mx, self.my)
      if si and self.slotRigs[si] then id = self.slotRigs[si].id
      else
        local bi = self:benchAt(self.mx, self.my)
        if bi and self.bench[bi] then id = self.bench[bi].id end
      end
    end
    if id then self:drawTooltip(id) end
  end

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

-- Bannière de run (HUD haut) : 4 stats [symbole · LABEL · VALEUR], symbole par stat (pièce/diamant/pip/case),
-- LABEL et VALEUR en Space Mono (Theme.label / Theme.value), distingués par la couleur. Aligné/espacé
-- proprement dans un Panel propre. Symboles dessinés en primitives nettes (Badge.diamond + cercles/carrés).
local HUD_SYMW = 12 -- largeur réservée au symbole (icône + petit gap)
function Build:drawBanner(run)
  local c = Theme.c
  local fontL = Theme.label(10)  -- LABELS (Space Mono, petites capitales nettes)
  local fontV = Theme.value(15)  -- VALEURS (Space Mono, prominentes)
  -- VIES retirées du HUD : elles vivent désormais dans le module de vie (bas-gauche) -> pas de doublon.
  local seg = {
    { sym = "coin",    label = T("ui.gold"),  value = tostring(run.gold) },
    { sym = "diamond", label = T("ui.wins"),  value = run.wins .. "/" .. Run.WIN_TARGET },
    { sym = "pip",     label = T("ui.round"), value = tostring(run.round) },
    { sym = "slot",    label = T("ui.slots"), value = run.slots .. "/" .. Run.MAX_SLOTS },
  }
  -- mesure : symbole + label + petit gap + valeur, par segment ; gouttière fixe entre segments.
  local segGap, lblGap = 26, 5
  local total = 0
  for _, s in ipairs(seg) do
    total = total + HUD_SYMW + fontL:getWidth(s.label) + lblGap + fontV:getWidth(s.value)
  end
  total = total + segGap * (#seg - 1)
  local x = Draw.W / 2 - total / 2
  -- Plaque PROPRE (Panel : dégradé sombre + liseré iron + éclat) intégrant le HUD au lieu d'un texte flottant.
  Panel.draw(x - 20, 12, total + 40, 32, { fill1 = c.stone800, fill2 = c.stone900 })
  local midY = 28 -- centre vertical de la plaque
  local lblY, valY = midY - fontL:getHeight() / 2, midY - fontV:getHeight() / 2
  for _, s in ipairs(seg) do
    -- symbole (centré sur midY) en primitives propres (pièce/diamant/pip/case).
    if s.sym == "coin" then
      Draw.setColor(c.gold); love.graphics.circle("fill", x + 4, midY, 4)
      Draw.setColor(c.brassS); love.graphics.circle("fill", x + 3, midY - 1, 1); Draw.reset()
    elseif s.sym == "diamond" then
      Badge.diamond(x + 4, midY, 4, c.gold, c.brassD, c.brassS)
    elseif s.sym == "pip" then
      Draw.setColor(c.gold); love.graphics.circle("fill", x + 4, midY, 3); Draw.reset()
    else -- slot : petite case
      Draw.setColor(c.gold); love.graphics.rectangle("fill", x + 1, midY - 3, 7, 7)
      Draw.setColor(c.stone900); love.graphics.rectangle("fill", x + 3, midY - 1, 3, 3); Draw.reset()
    end
    x = x + HUD_SYMW
    -- LABEL (éteint) puis VALEUR (claire), centrés verticalement sur midY.
    Draw.text(s.label, x, lblY, c.fainter, fontL)
    x = x + fontL:getWidth(s.label) + lblGap
    Draw.text(s.value, x, valY, c.title, fontV)
    x = x + fontV:getWidth(s.value) + segGap
  end
  if run.winStreak >= 2 or run.lossStreak >= 2 then
    local won = run.winStreak >= 2
    Draw.textC(won and T("ui.win_streak", { n = run.winStreak }) or T("ui.loss_streak", { n = run.lossStreak }),
      Draw.W / 2, 46, won and c.gold or c.blood, Theme.label(11))
  end
end

-- MODULE DE VIE (extrême gauche de la barre du bas) : [ libellé « LIVES n/5 » | rangée de CŒURS (Gauge.lives,
-- n pleins sur START_LIVES) | « TIER n/5 » + barre d'XP de boutique ]. Tout propre (plus aucun orbe forge baké) ;
-- libellés Space Mono ; remplit la colonne (self.lay.lifeOrbBox / lifeLabel) sans flotter dans le vide.
function Build:drawLifeOrb(run)
  local c = Theme.c
  local box = self.lay.lifeOrbBox
  local lab = self.lay.lifeLabel
  local maxL = Run.START_LIVES
  -- Module de vie (bas-gauche), TOUT PROPRE — plus aucun orbe forge baké :
  --   [ libellé « LIVES n/5 » | rangée de CŒURS (Gauge.lives) | « TIER n/5 » + barre d'XP de boutique ].
  -- 1) LIBELLÉ (Space Mono) centré au-dessus. Sang si vies basses.
  local low = run.lives <= 1
  Draw.textC(T("ui.lives_orb", { n = run.lives, max = maxL }), lab.x + lab.w / 2, lab.y + 1,
    low and c.blood or c.gold, Theme.label(11))
  -- 3) NIVEAU + BARRE D'XP (TFT-style), en bas de la colonne : « TIER n/5 » + barre remplie à shopXp/xpToNext()
  -- (au tier MAX : pleine, libellé MAX). Survol de la barre -> infobulle des cotes par rang (drawOddsTooltip).
  local capFont = Theme.label(9)
  local atMax = run.shopTier >= Run.MAX_TIER
  local tierStr = T("ui.tier_label") .. " " .. run.shopTier .. "/" .. Run.MAX_TIER
  local labY = box.y + box.h - capFont:getHeight() - 7
  Draw.textC(tierStr, box.x + box.w / 2, labY, atMax and c.gold or c.faint, capFont)
  local barW = math.max(60, box.w - 16)
  local barH, barX = 5, box.x + math.floor((box.w - math.max(60, box.w - 16)) / 2)
  local barY = box.y + box.h - barH - 2
  local toNext = run:xpToNext()
  local pct = atMax and 1 or (toNext and toNext > 0 and math.min(1, run.shopXp / toNext) or 0)
  Draw.bar(barX, barY, barW, barH, pct, atMax and c.gold or c.goldBright, c.stone900, c.hair)
  self.xpBarRect = { x = barX / 4, y = labY / 4, w = barW / 4, h = (barY + barH - labY) / 4 }
  -- 2) CŒURS (Gauge.lives) centrés horizontalement, verticalement entre le libellé et le bloc TIER.
  local hscale, hgap = 2, 3
  local heartsW = maxL * (7 * hscale + hgap) - hgap
  local hx = box.x + math.floor((box.w - heartsW) / 2)
  local hy = box.y + math.max(6, math.floor(((labY - box.y) - 6 * hscale) / 2))
  Gauge.lives(hx, hy, run.lives, maxL, hscale, hgap)
end

-- INFOBULLE DES COTES (survol de la barre d'XP) : « SHOP ODDS · TIER n/5 » + une ligne par rang NON-NUL
-- du tier courant (« R1  44% »), avec la couleur de rareté du rang. Enseigne ce que monter de tier débloque.
-- Petit panneau Frame gildé qui suit le curseur (rebond sur les bords). PUR-RENDER (golden inchangé).
function Build:drawOddsTooltip(run)
  local c = Theme.c
  local odds = run.ODDS[run.shopTier]
  if not odds then return end
  -- lignes { rank, pct } pour les rangs > 0 % (skip les 0 %).
  local rows = {}
  for rank = 1, Run.MAX_TIER do
    if (odds[rank] or 0) > 0 then rows[#rows + 1] = { rank = rank, pct = odds[rank] } end
  end
  local headFont = Theme.label(10)
  local rowFont = Theme.label(11)
  local PAD = 10
  local ROW_H = rowFont:getHeight() + 3
  local headStr = T("ui.tier_odds") .. "  ·  " .. T("ui.tier_label") .. " " .. run.shopTier .. "/" .. Run.MAX_TIER
  -- largeur : max(en-tête, lignes) + marge.
  local W = headFont:getWidth(headStr)
  for _, r in ipairs(rows) do
    W = math.max(W, rowFont:getWidth("R" .. r.rank) + 44)
  end
  W = W + PAD * 2
  local H = PAD + headFont:getHeight() + 6 + #rows * ROW_H + PAD
  -- position : suit le curseur, rebond sur les bords (jamais hors écran).
  local x, y = self.mx * 4 + 16, self.my * 4 + 12
  if x + W > Draw.W then x = self.mx * 4 - W - 16 end
  if x < 4 then x = 4 end
  if y + H > Draw.H then y = Draw.H - H - 6 end
  if y < 4 then y = 4 end
  x, y = math.floor(x), math.floor(y)
  local ix, iy, iw = Panel.draw(x, y, W, H, { fill1 = c.stone800, fill2 = c.stone900, border = c.brass })
  local cx = ix + PAD
  local cy = iy + (PAD - 4)
  Draw.text(headStr, cx, cy, c.gold, headFont)
  cy = cy + headFont:getHeight() + 4
  Draw.divider(ix + iw / 2, cy + 1, iw - 8, c.hair, 1)
  cy = cy + 5
  for _, r in ipairs(rows) do
    local col = Rarity.frame(r.rank)
    Draw.text("R" .. r.rank, cx, cy, col, rowFont)
    Draw.textR(r.pct .. "%", ix + iw - PAD, cy, c.body, rowFont)
    cy = cy + ROW_H
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
