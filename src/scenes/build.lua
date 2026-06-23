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
local Frame = require("src.ui.frame") -- encadré runique réutilisable (cases / cartes shop / plaque HUD)
local Forge = require("src.ui.forge") -- KIT « nightmare forge » : bouton-œil CTA + boutons éco + orbe de vie
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
local BOARD_OY = 90 -- centre du plateau (virtuel) : ×4 = ~360 design, sous l'en-tête, au-dessus de la boutique
local BOARD_HALF_W = 128 -- demi-étendue MAX (virtuelle) des CENTRES de cases -> board centré, jamais hors zone
local BOARD_HALF_H = 44  -- (idem vertical) : un sigil étalé (croix/anneau/ligne) se resserre pour tenir ici
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
  self:computeLayout()
  self:computeShop()
  for _, id in ipairs(Units.pool) do
    local c = self:newRig(id); c.x, c.y = 0, 0
    self.previewRigs[id] = c
  end
  -- self.button / rerollBtn / declineBtn + les rects du layout (orbe, cartes) sont calculés par
  -- computeShop() via le moteur Layout (déjà appelé ci-dessus) -> alignement parfait, fill-to-container.
  -- ACCENTS de liseré des SOCKETS de case (construits une fois) : or(survol/grant) / vert(drop) / sang(voisin).
  local c0 = Theme.c
  self._cellAccents = { gold = Forge.accentFrom(c0.goldBright), drop = Forge.accentFrom(c0.drop), blood = Forge.accentFrom(c0.blood) }
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
  if inRect(vx, vy, self.button) then self:startCombat(); return end
  if run then
    -- Grant en attente : REFUSER prioritaire (son rect cohabite avec la moitié REROLL) ; sinon ACCEPTER
    -- (clic sur une case verrouillée). Puis REROLL.
    if run.pendingSlotGrant then
      if inRect(vx, vy, self.declineBtn) then run:declineSlotGrant(); return end
      local lc = self:lockedCellAt(vx, vy)
      if lc then if run:acceptSlotGrant() then self.board:openCell(lc) end; return end
    end
    -- BUY XP : achète de l'XP de boutique si abordable (NE re-tire PAS la boutique : les nouvelles cotes
    -- s'appliquent au prochain reroll/round -> préserve l'arbitrage XP-vs-reroll-vs-unités).
    if inRect(vx, vy, self.raiseBtn) then if run:canBuyXp() then run:buyXp() end; return end
    if inRect(vx, vy, self.rerollBtn) then run:reroll(); return end
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
  Forge.uiTick(frameDt / 60) -- horloge des boutons forge (en SECONDES ; frameDt ~1.0/tick au 1/60)
  -- synchronise le rect REROLL avec l'état du grant (ligne pleine sans grant / scindée avec) -> hit-test
  -- toujours fidèle à ce qui est dessiné (mousepressed s'exécute après update).
  self:syncEcoRects(self.host.run and self.host.run.pendingSlotGrant)
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
  local minCol, maxCol = math.huge, -math.huge
  for _, cell in ipairs(b.shape.cells) do
    if cell.x < minCol then minCol = cell.x end
    if cell.x > maxCol then maxCol = cell.x end
  end
  local spanCol = math.max(1, maxCol - minCol)
  for i = 1, 9 do
    local p = self.pos[i]
    Draw.rect(p.x * 4 - SLOT_HALF, p.y * 4 - SLOT_HALF, SLOT_HALF * 2, SLOT_HALF * 2,
      b.slots[i].unlocked and c.slot or c.slotLocked)
    local cell = b.shape.cells[i]
    if b.slots[i].unlocked and cell then
      local expo = 1 - (maxCol - cell.x) / spanCol -- 1 = front exposé, 0 = arrière protégé
      if expo > 0.001 then
        Draw.setColor({ c.edgeActive[1], c.edgeActive[2], c.edgeActive[3], 0.16 * expo })
        love.graphics.rectangle("fill", p.x * 4 - SLOT_HALF, p.y * 4 - SLOT_HALF, SLOT_HALF * 2, SLOT_HALF * 2)
      end
    end
  end

  -- Panneau boutique + FONDS de carte = PLAQUES FORGE PLEINES (matière patinée, derrière les rigs d'aperçu)
  -- -> chaque offre lit comme une dalle dense remplie (≠ cadre creux sur un grand vide). Vendu = void mat.
  Draw.rect(0, 556, Draw.W, 164, c.panel)
  Draw.setColor(c.line); love.graphics.setLineWidth(2); love.graphics.line(0, 557, Draw.W, 557); love.graphics.setLineWidth(1)
  if run then
    for i, rect in ipairs(self.shopSlots) do
      local o = run.shop[i]
      if o then
        local x, y, w, h = rect.x * 4, rect.y * 4, rect.w * 4, rect.h * 4
        if o.sold then
          Draw.rect(x, y, w, h, c.void)
        else
          local aff = run.gold >= o.cost
          -- FOND de carte LAVÉ vers la rareté de l'offre (chaque dalle « lit » sa rareté). Au SURVOL le
          -- lavage MONTE nettement (0.30) -> le fond s'éclaire visiblement, pas seulement le liseré.
          local rk = (Units[o.id] and Units[o.id].rank) or 1
          local hot = (ui.shopHover == i)
          local amt = hot and 0.30 or 0.15
          Forge.uiPlate("build.card." .. i, x, y, w, h,
            { px = 2, disabled = not aff, tint = Forge.tintFrom(Rarity.frame(rk), amt) })
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
  if self.drag then Rig.draw(self.drag.char) end
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

  -- Cases = SOCKETS FORGE (métal patiné, fond transparent -> le rig de drawWorld transparaît). L'ÉTAT est
  -- porté par l'ACCENT du liseré : sobre (vide) / or (survol, cible de grant) / vert (drop) / sang (voisin
  -- d'adjacence) / sombre (scellé). On GARDE le placement sigil-graphe (self.pos[i], pas de grille). Décor
  -- par-dessus : pip de type, pips de niveau (diamants forge), nom de l'unité. PX=2 (densité forge).
  local granting = run and run.pendingSlotGrant
  local S = SLOT_HALF * 2
  local A = self._cellAccents
  for i = 1, 9 do
    local p, slot = self.pos[i], b.slots[i]
    local x, y = p.x * 4 - SLOT_HALF, p.y * 4 - SLOT_HALF
    if not slot.unlocked then
      -- scellée : socket sombre (accent or seulement si c'est une cible de grant).
      Forge.uiSocket("build.cell." .. i, x, y, S, S,
        { px = 2, seed = 30 + i, accentCol = granting and A.gold or nil, weather = not granting })
      Draw.textC("+", p.x * 4, p.y * 4 - 12, granting and c.gold or c.lock, Theme.ui(18))
    else
      local acc
      if i == ui.dropTarget then acc = A.drop
      elseif i == ui.hover then acc = A.gold
      elseif ui.nbset[i] then acc = A.blood
      else acc = nil end -- vide/repos : socket sobre
      Forge.uiSocket("build.cell." .. i, x, y, S, S, { px = 2, seed = 30 + i, accentCol = acc })
      local sr = self.slotRigs[i]
      if sr then
        Draw.pip(Units[sr.id].type, x + 13, y + 13, 5)
        -- pips de niveau = DIAMANTS forge (dorés) en haut-droite, alignés.
        local lvl = sr.level or 1
        for k = 1, (lvl > 1 and lvl or 0) do
          local px2 = x + S - 12 - (lvl - k) * 11
          Forge.diamondAt(px2 + 3, y + 10, 3, c.goldBright)
        end
        Draw.textC(T("unit." .. sr.id .. ".name"), p.x * 4, y + S + 3, c.name, Theme.ui(9))
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

  -- Bouton COMBAT = le GROS BOUTON-ŒIL forge (nuée d'yeux qui s'ouvrent et suivent le curseur au survol).
  local enabled = self:placedCount() > 0
  local r = self.button
  local over = inRect(self.mx, self.my, r)
  Forge.uiButton("build.combat", r.x * 4, r.y * 4, r.w * 4, r.h * 4,
    enabled and T("ui.fight") or T("ui.place_unit"),
    { tone = "cta", hover = over, active = over and love.mouse and love.mouse.isDown and love.mouse.isDown(1),
      disabled = not enabled, mouse = { mx = self.mx * 4, my = self.my * 4 },
      fontSz = 9, eyeR = 7 })

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
      if si and self.slotRigs[si] then id = self.slotRigs[si].id end
    end
    if id then self:drawTooltip(id) end
  end

  Draw.finish()
end

-- Carte de boutique = PLAQUE FORGE remplie + cadre patiné + contenu en COLONNE qui REMPLIT la carte :
-- [ région créature (flex, l'aperçu de drawWorld y vit) | nom | rangée coût+chips d'affliction ]. Le bas
-- ne flotte jamais : le moteur Layout colle nom/coût/chips au pied de la carte, et la région créature
-- absorbe le reste. États : achetable (or, lit au survol) / hors-budget (sombre) / vendu (SOLD).
-- rect = rect VIRTUEL de la carte ; o = l'offre {id, cost, sold} ; hot = survolée.
function Build:drawShopCard(i, rect, o, hot)
  local c = Theme.c
  local x, y, w, h = rect.x * 4, rect.y * 4, rect.w * 4, rect.h * 4
  local box = { x = x, y = y, w = w, h = h }

  if o.sold then
    Draw.rect(x, y, w, h, nil, c.line, 2)
    Draw.textC(T("ui.sold"), x + w / 2, y + h / 2 - 6, c.ghost, Theme.ui(10))
    return
  end
  local aff = (self.host.run.gold >= o.cost)
  local utype = Units[o.id].type

  -- CADRE forge patiné (fond transparent : la plaque bakée de drawBack + la créature transparaissent).
  -- accent du LISERÉ : teinté par le TYPE de la créature (flesh/order/bone/arcane/abyss) -> on lit le type
  -- DÈS le coup d'œil, même sur le cadre. Au SURVOL : liseré OR vif (le cadre s'allume nettement, en plus
  -- du fond qui s'éclaire). Hors-budget : sobre (nil).
  local acc
  if not aff then acc = nil
  elseif hot then acc = self._cellAccents.gold
  else acc = Forge.accentFrom(Theme.type(utype).color) end
  Forge.uiSocket("build.cardframe." .. i, x, y, w, h, { px = 2, seed = 70 + i, accentCol = acc })

  -- COLONNE interne : région créature (flex) au-dessus du bloc d'info (nom + coût/chips), avec un padding.
  local inner = Layout.inset(box, { l = 8, t = 8, r = 8, b = 8 })
  local rows = Layout.column(inner, { { flex = 1 }, { size = 16 }, { size = 16 } }, { gap = 3, align = "stretch" })
  local nameBox, costBox = rows[2], rows[3]

  -- PIP DE TYPE (haut-gauche) GROS et bien TYPÉ (révision Kévin : l'ancien pip était trop discret) -> on
  -- voit instantanément flesh/order/bone/arcane/abyss. Halo additif au survol (la rune « s'illumine »).
  local tcol = Theme.type(utype).color
  Draw.pip(utype, x + 14, y + 14, 6, aff and tcol or c.fainter)
  if hot and aff and love.graphics.setBlendMode and love.graphics.circle then
    love.graphics.setBlendMode("add")
    love.graphics.setColor(tcol[1], tcol[2], tcol[3], 0.32)
    love.graphics.circle("fill", x + 14, y + 14, 9)
    love.graphics.setBlendMode("alpha"); love.graphics.setColor(1, 1, 1, 1)
  end

  -- NOM (centré dans sa rangée).
  local nameCol = aff and c.name or c.dim
  Draw.textC(T("unit." .. o.id .. ".name"), nameBox.x + nameBox.w / 2, nameBox.y + 2, nameCol, Theme.ui(9))

  -- RANGÉE BAS : chips d'affliction (gauche) + coût (droite). Les chips = ce que l'unité APPLIQUE.
  local font = Theme.ui(8)
  love.graphics.setFont(font)
  local affl = Keywords.applied(Units[o.id])
  local cx = costBox.x
  for _, k in ipairs(affl) do
    -- mini-chip ICÔNE SEULE (pas de label : la place est rare) -> reconnaissable par sa couleur+forme.
    local cw = Chip.draw(cx, costBox.y + 1, { key = k, label = "", icon = true, font = font, h = 13 })
    cx = cx + cw + 3
    if cx > costBox.x + costBox.w - 34 then break end -- ne déborde pas sous le coût (pièce + valeur read)
  end
  -- COÛT : PIÈCE d'or + valeur en POLICE READ (lisible, grande), callé à droite -> le prix saute aux yeux.
  -- L'or change de teinte selon le budget (or vif si achetable, éteint sinon). La valeur est sans « g » (la
  -- pièce DIT déjà l'or) -> chiffre net et gros.
  local cd = aff and c.goldBright or c.fainter
  local costStr = tostring(o.cost)
  local fontCost = Theme.read(16)
  local cw = fontCost:getWidth(costStr)
  local valX = costBox.x + costBox.w           -- bord droit (valeur right-aligned)
  local midY = costBox.y + 8
  Forge.label(costStr, valX, midY, 16, { cd[1], cd[2], cd[3] }, { read = true, right = true, shadow = true })
  Forge.coinAt(valX - cw - 7, midY, 4, aff and c.goldBright or c.fainter, not aff)
end

-- Bannière de run (HUD haut) : 4 stats [symbole · LABEL · VALEUR], symbole par stat (pièce/diamant/pip/case),
-- LABEL en Silkscreen (petites capitales, ce que cette police fait de mieux), VALEUR en POLICE READ (lisible,
-- claire). Aligné/espacé proprement dans une plaque runique. Symboles dessinés en primitives forge.
local HUD_SYMW = 12 -- largeur réservée au symbole (icône + petit gap)
function Build:drawBanner(run)
  local c = Theme.c
  local fontL = Theme.ui(11)   -- LABELS (capitales courtes : Silkscreen reste idéal)
  local fontV = Theme.read(16) -- VALEURS (lisibles, prominentes)
  -- VIES retirées du HUD : elles vivent désormais dans l'ORBE DE VIE (bas-gauche) -> pas de doublon.
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
  -- Plaque runique : intègre le HUD (biseau bronze) au lieu d'un texte qui flotte sur le fond.
  Frame.draw(x - 20, 12, total + 40, 32, { level = "bevel", fill = c.panel })
  local midY = 28 -- centre vertical de la plaque
  for _, s in ipairs(seg) do
    -- symbole (centré sur midY).
    if s.sym == "coin" then
      Forge.coinAt(x + 4, midY, 4, c.goldBright)
    elseif s.sym == "diamond" then
      Forge.diamondAt(x + 4, midY, 4, c.goldBright, c.gold)
    elseif s.sym == "pip" then
      Draw.setColor(c.gold); love.graphics.circle("fill", x + 4, midY, 3); Draw.reset()
    else -- slot : petite case
      Draw.setColor(c.gold); love.graphics.rectangle("fill", x + 1, midY - 3, 7, 7)
      Draw.setColor(c.panelDeep); love.graphics.rectangle("fill", x + 3, midY - 1, 3, 3); Draw.reset()
    end
    x = x + HUD_SYMW
    -- LABEL (éteint) puis VALEUR (claire, read), centrés verticalement sur midY.
    Draw.text(s.label, x, midY - fontL:getHeight() / 2, c.fainter, fontL)
    x = x + fontL:getWidth(s.label) + lblGap
    Forge.label(s.value, x, midY, 16, { c.title[1], c.title[2], c.title[3] }, { read = true, left = true, shadow = true })
    x = x + fontV:getWidth(s.value) + segGap
  end
  if run.winStreak >= 2 or run.lossStreak >= 2 then
    local won = run.winStreak >= 2
    Draw.textC(won and T("ui.win_streak", { n = run.winStreak }) or T("ui.loss_streak", { n = run.lossStreak }),
      Draw.W / 2, 46, won and c.gold or c.blood, Theme.ui(11))
  end
end

-- ORBE DE VIE (extrême gauche de la barre du bas) : un orbe forge rempli de SANG dont le niveau de fluide
-- suit les vies (lives / START_LIVES). Compteur Silkscreen AU-DESSUS. L'orbe REMPLIT la hauteur de sa
-- colonne (boîte de layout self.lay.lifeOrbBox) -> baké à la TAILLE CALCULÉE (pas un petit orbe flottant
-- dans une grande boîte). Animé (vagues + nageuse) -> re-rendu chaque frame (1 seul widget).
function Build:drawLifeOrb(run)
  local c = Theme.c
  local box = self.lay.lifeOrbBox
  local px = 2
  -- L'orbe est CARRÉ ; on prend min(largeur,hauteur) de la boîte pour qu'il tienne, divisé par px -> art.
  local side = math.min(box.w, box.h)
  local art = math.max(8, math.floor(side / px))
  local diam = art * px
  -- centré dans la boîte (la boîte fait toute la hauteur de la colonne ; l'orbe la remplit au max).
  local ox = box.x + math.floor((box.w - diam) / 2)
  local oy = box.y + math.floor((box.h - diam) / 2)
  if not self.lifeOrbWidget or self.lifeOrbWidget.aw ~= art then
    self.lifeOrbWidget = Forge.newWidget(art, art) -- (RE)BAKE à la taille calculée par le layout
  end
  local maxL = Run.START_LIVES
  local level = maxL > 0 and (math.max(0, math.min(maxL, run.lives)) / maxL) or 0
  local img = Forge.render(self.lifeOrbWidget,
    function(b, W, H, t) Forge.drawOrb(b, W, H, level, Forge.LIQ.blood, 101, t) end, self.t / 60)
  Forge.blit(img, ox, oy, px)
  -- compteur centré dans sa boîte (self.lay.lifeLabel), au-dessus de l'orbe. Sang si vies basses.
  local lab = self.lay.lifeLabel
  local low = run.lives <= 1
  Draw.textC(T("ui.lives_orb", { n = run.lives, max = maxL }), lab.x + lab.w / 2, lab.y + 2,
    low and c.blood or c.gold, Theme.uiBold(12))
  -- NIVEAU + BARRE D'XP DE BOUTIQUE (TFT-style) : sous l'orbe, « TIER n/5 » et une barre fine remplie à
  -- shopXp/xpToNext() (au tier MAX : barre pleine, libellé MAX). Le bouton BUY XP la fait monter ; la passive
  -- aussi (1/round). Survol de la barre -> infobulle des cotes par rang (cf. drawOddsTooltip). PUR-RENDER.
  local capFont = Theme.ui(9)
  local atMax = run.shopTier >= Run.MAX_TIER
  local tierStr = T("ui.tier_label") .. " " .. run.shopTier .. "/" .. Run.MAX_TIER
  local labY = box.y + box.h - capFont:getHeight() - 6
  Draw.textC(tierStr, ox + diam / 2, labY, atMax and c.gold or c.faint, capFont)
  -- barre fine sous le libellé, centrée sur l'orbe ; remplissage = progression vers le tier suivant.
  local barW = math.max(36, diam)
  local barH = 4
  local barX = ox + math.floor((diam - barW) / 2)
  local barY = box.y + box.h - barH - 1
  local toNext = run:xpToNext()
  local pct = atMax and 1 or (toNext and toNext > 0 and math.min(1, run.shopXp / toNext) or 0)
  Draw.bar(barX, barY, barW, barH, pct, atMax and c.gold or c.goldBright, c.panelDeep, c.hair)
  -- hit-test de la barre (espace VIRTUEL) pour le survol -> infobulle des cotes. On élargit un peu en
  -- hauteur (englobe le libellé TIER) pour faciliter le survol de cette petite zone.
  self.xpBarRect = { x = barX / 4, y = labY / 4, w = barW / 4, h = (barY + barH - labY) / 4 }
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
  local headFont = Theme.uiBold(10)
  local rowFont = Theme.ui(11)
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
  local ix, iy, iw = Frame.draw(x, y, W, H, { level = "gilded", state = "idle", px = 2 })
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

-- Bouton d'économie (REROLL / REFUSER) = ÉCO FORGE (métal patiné + diamant de coût). rect en virtuel.
-- id = clé de cache stable ; label = texte ; cost = valeur du diamant (or) ; enabled = grise si faux.
function Build:drawEcoButton(id, rect, label, cost, enabled)
  local hot = inRect(self.mx, self.my, rect)
  Forge.uiButton(id, rect.x * 4, rect.y * 4, rect.w * 4, rect.h * 4, label,
    { tone = "eco", cost = cost, hover = hot,
      active = hot and love.mouse and love.mouse.isDown and love.mouse.isDown(1),
      disabled = not enabled })
end

-- ── Fiche monstre (carte TCG forge, au survol) ────────────────────────────────────────────────────
-- Carte MINIMALE (révision Kévin) : on garde le strict utile, on encadre les VALEURS importantes en
-- value-tags runiques (forge.valueTag) et on rend l'info lisible. Fond = plaque forge qui respire
-- (Forge.uiCard) + contenu PAR-DESSUS : header (nom+coût) > portrait > identité (pip+type+famille+rareté)
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

-- Rangée de reliques possédées : SOCLES forge patinés (Forge.uiSocket, fond transparent) bordant
-- l'artefact baké (RelicGen.cached). Liseré teinté de la famille de la relique ; ALLUMÉ (or vif) au survol.
function Build:drawRelicRow()
  local run, c = self.host.run, Theme.c
  if not run or #run.relics == 0 then return end
  local hov = self:relicAt(self.mx, self.my)
  for i, rel in ipairs(run.relics) do
    local r = self:relicRowRect(i)
    local on = (hov == i)
    local fam = RELIC_TYPE[rel.id] or "bone"
    -- accent : or vif au survol, sinon teinte sobre de la famille (le socle ne s'éteint jamais complètement).
    local acc = on and Forge.accentFrom(c.goldBright) or Forge.accentFrom(Theme.type(fam).color)
    Forge.uiSocket("build.relic." .. i, r.x, r.y, r.w, r.h,
      { px = 2, seed = 90 + i, frameTh = 3, accentCol = acc })
    -- artefact baké centré DANS le socle (le cadre borde sans masquer).
    local baked = RelicGen.cached(rel.id, self.palette)
    if baked and baked.image then
      love.graphics.setColor(1, 1, 1, 1)
      love.graphics.draw(baked.image, r.x + RELIC_FRAME, r.y + RELIC_FRAME, 0, RELIC_ICON_SCALE, RELIC_ICON_SCALE)
    end
  end
  Draw.reset()
end

-- Infobulle de relique (survol de la rangée) = CARTE forge (même langage que src/scenes/relicpick.lua) :
-- plaque qui respire (Forge.uiCard) + artefact baké en cœur + gem de famille + nom (or) + effet clair + flavor.
-- Suit le curseur, rebond sur les bords. PUR-RENDER (golden inchangé).
function Build:drawRelicTooltip(id)
  local c = Theme.c
  local fam = RELIC_TYPE[id] or "bone"
  local emblem = Theme.type(fam)
  local fontE, fontF = Theme.ui(12), Theme.loreRoman(13)
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

  -- FOND forge (plaque qui respire + cadre patiné, accent de la famille).
  Forge.uiCard("build.reliccard." .. id, x, y, W, h,
    { px = 2, seed = 60 + (#id), accentCol = Forge.accentFrom(emblem.color), rich = false, t = self.t / 60 })

  -- CONTENU posé par-dessus, en colonne Layout.
  local inner = Layout.inset({ x = x, y = y, w = W, h = h }, PAD)
  local rows = Layout.column(inner, {
    { size = headH },         -- 1 gem + nom
    { size = effH + 10 },     -- 2 effet clair (or)
    { flex = 1 },             -- 3 flavor (pied)
  }, { gap = 0, align = "stretch" })
  local rHead, rEff, rFlav = rows[1], rows[2], rows[3]

  -- (1) HEADER : gem de famille (diamant forge) + nom (or).
  local midH = rHead.y + rHead.h / 2
  Forge.diamondAt(rHead.x + 5, midH, 4, emblem.color, emblem.dark)
  Draw.text(T("relic." .. id .. ".name"), rHead.x + 16, rHead.y + 2, c.title, Theme.uiBold(14))

  -- (2) EFFET CLAIR (or vif) : le coeur du modèle lisible.
  Draw.textWrap(effStr, rEff.x, rEff.y, rEff.w, c.goldBright, fontE)

  -- (3) FLAVOR (serif d'ambiance, éteint).
  Draw.textWrap(flavStr, rFlav.x, rFlav.y, rFlav.w, c.dim, fontF)
end

return Build
