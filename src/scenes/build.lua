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
local UnitResolver = require("src.core.unit_resolver")
local CreatureGen = require("src.gen.creaturegen") -- visuel généré pour les unités sans rig dessiné main
local Critter = require("src.render.critter") -- rendu VIVANT (cadre natif : taille relative + mouvement par-pixel/famille)
local Encounters = require("src.data.encounters")
local OppGen = require("src.data.oppgen") -- A4 : générateur d'adversaire procédural scalé au stade (déterministe)
local Place = require("src.combat.place")
local Stats = require("src.effects.stats") -- caps du framework payoff (value bouclier ×3 à la lecture)
local Snapshot = require("src.net.snapshot")
local Snapstore = require("src.net.snapstore")
local Run = require("src.run.state")
local Mutations = require("src.run.mutations")
local RelicGen = require("src.gen.relicgen") -- icones de reliques (rangee type Slay the Spire + hover)
local Rarity = require("src.gen.rarity") -- TIER (rang 1..5) -> couleur + nom de caste (source unique de rareté UI)
local Bestiary = require("src.core.bestiary") -- marque les créatures vues en boutique (codex)
local Theme = require("src.ui.theme")
local Draw = require("src.ui.draw")
-- ── Kit UI PROPRE (.dc.html / design-system) : la scène n'utilise plus du tout Frame/Forge (kit legacy) ──
local Panel = require("src.ui.panel")    -- surface propre (dégradé + liseré iron) : remplace Frame/Forge.uiPlate/uiCard
local Button = require("src.ui.button")  -- boutons propres : primary (CTA + yeux) / eco (coût) / secondary
local Slot = require("src.ui.slot")      -- cases du plateau (6 états) : remplace Forge.uiSocket
local CommanderCell = require("src.ui.commandercell") -- C4 : CASE SIMPLE du commandant (refonte 2026-06 : header + case, hors-graphe)
local Gauge = require("src.ui.gauge")    -- jauges vies/XP : remplace l'orbe forge baké
local LifeOrb = require("src.render.lifeorb") -- GLOBE DE VIE nightmare-forge (pixel net + nageur + shader cosmardesque)
local Badge = require("src.ui.badge")    -- coût (pièce+nombre) / pips de niveau / diamants : remplace Forge.coinAt/diamondAt/label
local Dividers = require("src.ui.dividers") -- séparateurs laiton/sang propres
local Feel = require("src.ui.feel")      -- JUICE : survol (glow/lift) + press (squash/flash) + action différée
local Juice = require("src.ui.juice")    -- MOUVEMENT « candy » : number-roll de l'or (scale-punch + valeur lissée)
local P = require("src.ui.particles")    -- PARTICULES PIXEL (transplant Feel Lab) : explosion de level-up/fusion en SPRITES bakés
local Drag = require("src.ui.drag")      -- RESSORT de drag « Balatro » (lab) : pièce traînée glisse+s'incline ; pose/swap glissés
local Layout = require("src.ui.layout") -- MOTEUR de layout flex (alignement parfait, fill-to-container)
local Keywords = require("src.ui.keywords") -- registre afflictions (mini-chips de carte)
local Chip = require("src.ui.chip") -- pastilles keyword (icône d'affliction)
local Ambient = require("src.fx.ambient")
local NightmareBG = require("src.fx.nightmare_bg") -- champ cauchemardesque réutilisé derrière la zone de formation
local Rarity = require("src.gen.rarity") -- rang -> couleur de cadre + glow (accent de rareté de la fiche)
local MiniRig = require("src.render.minirig") -- mesure OPAQUE mutualisée des rigs (bounds/fit) : seule source de vérité
local MonsterCard = require("src.render.monstercard") -- FICHE de monstre (extraite de drawTooltip) : réutilisée ici + Chronique
local CardGlossary = require("src.ui.card_glossary") -- glossaire Shift des mots-cles mecaniques de la fiche
local InfluencePanel = require("src.ui.influence_panel") -- sidecar d'auras/influences ancre aux cartes
local RelicCard = require("src.ui.relic_card") -- FICHE de relique au survol (icône ANIMÉE + band + fam) : pop-up HUD
local RelicsData = require("src.data.relics") -- band/palier de la relique (couleur de carte Argent/Or/Prismatique)
local MechanicsText = require("src.ui.mechanics_text")
local I18n = require("src.core.i18n")
local T = I18n.t
local SFX = require("src.audio.sfx") -- SON (Oniric grave) : cues SÉMANTIQUES des évènements de build (achat/vente/drag/fusion). No-op headless.

local Build = {}
Build.__index = Build

local SLOT_HALF = 40 -- demi-côté d'une case en espace DESIGN (80x80 ; centre = self.pos[i] ×4)

-- ── TOP CHROME (refonte « Build Screen.dc.html ») : bandeau de run riche (haut) + barre sigil/archétype ──
-- Hauteurs design : le bandeau (HUD complet) puis la barre sigil ; le board vit sous les deux (TOPCHROME_H).
local BANNER_H = 54   -- bandeau de run (reliques/or/vies/descente/round/slots/streak/tier)
local SIGIL_H = 38    -- barre sigil/archétype (nom + flavor + archétype + boutons de forme)
-- Sigils EN PAUSE -> pas de barre sigil : le top chrome se limite au bandeau (l'espace de la barre est rendu).
local TOPCHROME_H = BANNER_H + (Board.SIGILS_PAUSED and 0 or SIGIL_H)

-- RELIQUES possédées : désormais dans le SEGMENT « RELICS » du bandeau (haut-gauche). Socle 24×24 + icône
-- bakée centrée ; survol -> infobulle (relicAt teste ces rects en espace design). Géométrie déterministe
-- (pas de cache de layout) -> hit-tests sûrs même hors frame de rendu.
local RELIC_B_S = 24                  -- côté du socle de relique (design)
local RELIC_B_CELL = 30               -- pas horizontal (socle + gouttière)
local RELIC_B_X0, RELIC_B_Y = 16, 23  -- ancrage dans le segment RELICS (sous le label « RELICS »)

-- Famille forge par relique (forme + couleur de la gem d'accent) -> liseré teinté de la fiche/du socle.
-- Clés ∈ Forge.FAM (flesh/bone/order/abyss/arcane). Aligné sur src/scenes/relicpick.lua.
local RELIC_TYPE = {
  bloodstone = "flesh", carapace = "bone", aegis = "order",
  kings_bowl = "abyss", ember_heart = "arcane", weeping_nail = "flesh", grave_cap = "abyss",
  -- vague 5 : reliques d'économie / boutique (teinte = nature du foyer ; or=order, mort=bone, Puits=abyss)
  usurers_ledger = "order", tithe_bowl = "order", paupers_boon = "order",
  grave_robbers_cut = "bone", carrion_ledger = "bone",
  black_summons = "abyss", beggars_lantern = "order",
}

local SPACING = 26
local BOARD_OY = 72 -- centre du plateau (virtuel) : ×4 = 288 design ; laisse un vrai souffle avant le banc
local BOARD_HALF_W = 128 -- demi-étendue MAX (virtuelle) des CENTRES de cases -> board centré, jamais hors zone
local BOARD_HALF_H = 30  -- (idem vertical) : RESSERRÉ pour qu'un sigil étalé ne morde pas sur le banc
local DEFAULT_BENCH_SIZE = 4 -- BANC live : 4 slots gardent un vrai arbitrage de placement (retour user 2026-06).
local MAX_BENCH_SIZE = 12 -- lab-only : permet de tester des réserves plus larges sans changer le live.
local MAX_LEVEL = 3
local LEVEL_MULT = UnitResolver.STAT_LEVEL_MULT -- stats par niveau : source unique (duplicatas / cartes / snapshots)

local function normalizeBenchSize(n)
  n = math.floor(tonumber(n) or DEFAULT_BENCH_SIZE)
  if n < 1 then return 1 end
  if n > MAX_BENCH_SIZE then return MAX_BENCH_SIZE end
  return n
end

-- ── COMMANDANTS (K4) — placeholders d'équilibrage (cf. docs/research/commanders-plan.md §1.4/§6.1).
-- STAT_INC_CAP : plafond cumulé du buff `statInc` (commandant : +% PV ET dmg). Plus serré qu'ATK_INC_CAP
-- car il touche DEUX stats à la fois. COMMANDER_CD_MULT : ralentit la cadence du commandant au piédestal
-- (voie A : il attaque, mais lentement -> il dirige, il ne combat pas comme un troupier). Bornes [1.0, 2.5].
local STAT_INC_CAP = 1.0
local COMMANDER_CD_MULT = 1.5

-- ── W1 (axe Type-identité, plan §AXE 2) — RAINBOW (`aura_per_unique_type`). Le porteur (Prismagon/Spectre)
-- se renforce de +dmg/+hp par TYPE DISTINCT du board (5 types max : flesh/bone/arcane/abyss/order). On compte
-- au BUILD (Q4 : sur le plateau, déterministe, snapshot-gratuit comme les auras), jamais en combat. Le `count`
-- est borné à RAINBOW_TYPE_CAP -> la magnitude reste lisible et plafonnée (discipline de cap §6.1). Flat
-- additif sur hp/dmg (même couche que statInc, mais en plat) -> sous les caps relatifs existants par construction.
local RAINBOW_TYPE_CAP = 5 -- nb de types distincts comptés (le jeu n'en a que 5 ; borne dure anti-extension)

-- ── W3 (axe Mimétisme/amplification, plan §AXE 4) — `repeat_ability` (le pattern « Tiger » SAP). Une unité
-- MIMIC re-rejoue les effets `on_hit` d'UN voisin, AU NIVEAU du mimic. BUILD-RÉSOLU (comme aura_stat) : on COPIE
-- les descripteurs on_hit du voisin DANS la liste d'effets du mimic (jamais un appel à hit() en combat -> zéro
-- ré-entrance/aliasing ctx). ANTI-BOUCLE DUR (plan Q3) : (1) on ne copie QUE des on_hit (jamais combat_start ->
-- repeat_ability ne se copie JAMAIS lui-même : pas de repeat-of-repeat) ; (2) PROFONDEUR 1 = on saute tout
-- descripteur déjà marqué `viaCopy` (un effet copié ne peut pas être recopié par un 2e mimic) ; (3) le copié
-- porte `viaCopy=true` -> il est inerte aux yeux d'un mimic voisin. Déterministe (ipairs, tie-break slot asc),
-- zéro RNG. `who` = "ahead" (l'allié droit DEVANT, axe X=depth) | "neighbors" (le PLUS FORT voisin du graphe).
local REPEAT_DEPTH_MAX = 1 -- garde-fou lisible (§6.4) : un seul niveau de copie (Tiger SAP), jamais de chaîne

-- ── Courbe de difficulté (cold-start) — TUNABLES (cf. the-pit-balance-diagnosis). Le board joueur croît de
-- façon PRÉVISIBLE (grants timés 3->9). L'ennemi suit : l'index d'encounter grimpe avec le round (taille),
-- puis au-delà de la table le plus gros gagne des NIVEAUX (bump) pour suivre les merges du joueur fin de run. ──
local ENEMY_LEVEL_START = 11 -- round où l'ennemi cold-start gagne des niveaux (APRÈS la table : pit_sovereign
local ENEMY_LEVEL_EVERY = 3  -- est déjà leveled ; le bump ne sert qu'aux runs très longues, pour ne pas plateau)

-- Hit-test (espace virtuel), défini en TÊTE de module : utilisé par computeLayout/commanderAt/les hit-tests.
local function inRect(px, py, r) return px >= r.x and px <= r.x + r.w and py >= r.y and py <= r.y + r.h end
local function ctrlHeld()
  return love and love.keyboard and love.keyboard.isDown and love.keyboard.isDown("lctrl", "rctrl")
end

function Build.new(palette, vw, vh, host, opts)
  opts = opts or {}
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
    benchSize = normalizeBenchSize(opts.benchSize),
    commanderSlot = nil, -- C3 : { id, level, char } au PIÉDESTAL (1 slot logique HORS graphe de sigil, sans voisins)
    cmdCadence = 0,      -- C4 : phase 0..1 de la barre de cadence LENTE du commandant (cosmétique, dt-piloté)
    cmdShake = 0,        -- C4 : timer de SECOUSSE de refus (drop d'un non-chef) ; >0 = le socle tremble + sang
    fx = {},           -- GAME FEEL : effets ÉPHÉMÈRES (achat/vente/level-up) — { kind, x, y, t, dur, ... } (design)
    -- LEVEL-UP : on DIFFÈRE l'ouverture de la pop-up de relique à la FIN de l'anim de fusion (retour user : ne plus
    -- la cacher en plein « TAAA »). pendingLevelRelic (déjà existant) = l'offre est armée ; levelRelicCountdown =
    -- buffer mural restant APRÈS la fin du FX (re-armé tant qu'un FX levelup/merge_fly vit -> couvre la cascade).
    -- updating = le RENDER-loop a déjà tourné au moins une frame (vrai jeu) ; faux en headless (tests pilotés sans
    -- update) -> FALLBACK synchrone (l'offre s'ouvre tout de suite, cf. armLevelRelic) pour ne pas casser l'e2e.
    levelRelicCountdown = nil, updating = false,
    previewRigs = {},  -- [id] = char idle (aperçu boutique)
    drag = nil,        -- { id, char, fromSlot? | fromShop? }
    mx = -100, my = -100,
    combatCount = 0,
    goldShown = nil,  -- NUMBER-ROLL de l'or (RENDER-local) : valeur AFFICHÉE qui roule vers run.gold ; punché à chaque
                      -- delta (Juice "build.gold"). nil = pas encore initialisée (1re frame -> snap sur la vraie valeur).
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
  self.ambient = Ambient.new(3) -- fond calme (repli + hors zone de formation)
  self.nightmareBg = NightmareBG.new(17) -- fosse animée derrière le plateau/banc ; RENDER pur, headless-safe
  if self.host.run then self:syncSlots() end
  return self
end

Build.DEFAULT_BENCH_SIZE = DEFAULT_BENCH_SIZE
Build.MAX_BENCH_SIZE = MAX_BENCH_SIZE

function Build:benchCapacity()
  return self.benchSize or DEFAULT_BENCH_SIZE
end

local function unitRank(id)
  local u = Units[id]
  return u and (u.rank or 1) or 1
end

function Build:pairCompletionCandidates()
  local counts = {}
  for i = 1, 9 do
    local sr = self.slotRigs[i]
    if sr and (sr.level or 1) == 1 then counts[sr.id] = (counts[sr.id] or 0) + 1 end
  end
  for i = 1, self:benchCapacity() do
    local sr = self.bench[i]
    if sr and (sr.level or 1) == 1 then counts[sr.id] = (counts[sr.id] or 0) + 1 end
  end
  local candidates = {}
  for id, n in pairs(counts) do
    if n == 2 then candidates[#candidates + 1] = id end
  end
  table.sort(candidates, function(a, b)
    local ar, br = unitRank(a), unitRank(b)
    if ar ~= br then return ar < br end
    return a < b
  end)
  return candidates
end

function Build:applyShopSupport(source)
  local run = self.host and self.host.run
  if not (run and run.applyPairCompletionSupport) then return false end
  return run:applyPairCompletionSupport(self:pairCompletionCandidates(), source)
end

function Build:newRig(id)
  -- Visuel : rig dessiné MAIN (Creatures[id], les 6 vanille) sinon créature GÉNÉRÉE procéduralement
  -- (déterministe par id) — COHÉRENT avec le rendu de combat (arena_draw). Boutique = combat.
  local def = Creatures[id]
  if not def then
    local spec = Units[id] or {}
    def = CreatureGen.cached({ id = id, type = spec.type, family = spec.family, arch = spec.arch, effects = spec.effects, bodyplan = spec.bodyplan, rank = spec.rank })
  end
  local c = Rig.new(def, self.palette)
  c.facing = 1
  return c
end

function Build:makeOcc(id, level, opts)
  opts = opts or {}
  return {
    id = id,
    level = level or 1,
    char = opts.char or self:newRig(id),
    copyId = opts.copyId,
    mutations = Mutations.clone(opts.mutations),
    d = opts.d,
    bounce = opts.bounce,
    pop = opts.pop,
  }
end

function Build:cloneOcc(sr, opts)
  opts = opts or {}
  if not sr then return nil end
  return self:makeOcc(opts.id or sr.id, opts.level or sr.level or 1, {
    char = (opts.char ~= nil) and opts.char or sr.char,
    copyId = (opts.copyId ~= nil) and opts.copyId or sr.copyId,
    mutations = (opts.mutations ~= nil) and opts.mutations or sr.mutations,
    d = (opts.d ~= nil) and opts.d or sr.d,
    bounce = opts.bounce,
    pop = opts.pop,
  })
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
  -- C4 — CASE DU COMMANDANT (refonte 2026-06, retour user : l'ancien trône carvé était jugé « horrible / contours
  -- chelou ») : 1 emplacement DISTINCT du graphe 3×3 (lisibilité « pas d'adjacence » : AUCUNE arête vers le board).
  -- Une CASE SIMPLE (src/ui/commandercell.lua) — même langage que les cases du plateau — surmontée d'un header
  -- texte « COMMANDER ». CENTRÉE dans la grande MARGE LIBRE à GAUCHE du board (le board occupe le centre de l'écran)
  -- — « le chef se tient à côté de sa formation ». Le rect VIRTUEL (hit-test souris) = la case elle-même ; le header
  -- (au-dessus) déborde du hit-test (cosmétique, non cliquable).
  -- Géométrie : case un cran plus large qu'une case du board (le chef est un peu plus imposant que la piétaille),
  -- mais carrée et SOBRE -> lisible d'un bloc, zéro fioriture.
  local PED_W, PED_H = 38, 38            -- case VIRTUELLE (carrée) ; ×4 = 152×152 design
  -- Bord GAUCHE du board (centre de la case la plus à gauche - demi-case) en virtuel : on centre la case dans la
  -- bande libre [marge écran .. bord board], avec un VRAI air des deux côtés (jamais collée au board, fix « cramped »).
  local boardLeftV = ox - BOARD_HALF_W / 4 - (SLOT_HALF / 4) -- = 160 - 32 - 10 = 118 (left-edge de la case gauche)
  local pedCenterX = math.max(PED_W / 2 + 8, boardLeftV / 2) -- milieu de [0 .. boardLeft], borné pour ne pas sortir
  local pedX = math.floor(pedCenterX - PED_W / 2 + 0.5)
  local pedY = math.floor(oy - PED_H / 2 + 0.5) -- case centrée verticalement à hauteur du centre du board
  -- self.pedRect = la CASE (design ×4) passée à CommanderCell.draw. self.commanderRect = la MÊME case (hit-test
  -- souris, VIRTUEL) : la case EST la zone droppable (le header au-dessus ne l'est pas). Plus de niche imbriquée.
  self.pedRect = { x = pedX, y = pedY, w = PED_W, h = PED_H }
  self.commanderRect = { x = pedX, y = pedY, w = PED_W, h = PED_H }
end

-- La case de commandant est toujours affichée/droppable : le commandement est
-- une affordance de base, pas un unlock de run.
function Build:commanderCellShown()
  return self.commanderRect ~= nil
end

-- La case du commandant sous le curseur (espace virtuel) -> true si la drop-zone est touchée.
function Build:commanderAt(px, py)
  if not self:commanderCellShown() then return false end
  return self.commanderRect and inRect(px, py, self.commanderRect)
end

-- Le commandant est toujours débloqué ; on garde la fonction comme point
-- d'entrée unique pour les vieux appels build/lab.
function Build:commanderUnlocked()
  return true
end

-- Une unité peut-elle COMMANDER ? (porte un `commandBonus`). Sert au refus visuel (drop d'un non-chef).
local function canCommand(id)
  local u = Units[id]
  return u and u.commandBonus ~= nil
end

-- ── C4 — PORTÉE DU COMMANDANT (survol du piédestal -> éclaire les unités du board affectées + étiquette). ──
-- Résout le `target` du commandBonus EN unités POSÉES sur le board (mêmes règles que buildComp:resolveTargets,
-- mais lues ICI pour le RENDU, pas pour le bake). `neighbors` -> vide (le commandant n'a aucun voisin, hors
-- graphe). Renvoie (set, labelKey, labelVars) : set[slot]=true pour chaque case touchée ; l'étiquette résume
-- la portée en clair (« COMMANDS the whole pack / level-1 beasts / the vanguard »). PUR (lecture data).
function Build:commandRange()
  local cmd = self.commanderSlot
  if not cmd then return {}, nil, nil end
  local cb = UnitResolver.commandBonusFor(cmd.id, cmd.level or 1)
  if not cb then return {}, nil, nil end
  -- portée + étiquette dérivées du `target` (les rôles se résolvent comme le ciblage de combat).
  local target = cb.target or (cb.params and cb.params.target) or "neighbors"
  local set = {}
  local labelKey, labelVars
  if target == "team" then
    for i = 1, 9 do if self.slotRigs[i] then set[i] = true end end
    labelKey = "ui.command_pack"
  elseif target:sub(1, 5) == "role:" then
    -- role:front/back = extrême d'exposition (depth = maxCol - col) ; role:center = nœud de degré 4 du sigil.
    local role = target:sub(6)
    local pick = self:resolveRoleSlot(role)
    if pick then set[pick] = true end
    labelKey = (role == "front" and "ui.command_front") or (role == "back" and "ui.command_back")
      or (role == "center" and "ui.command_center") or "ui.command_front"
  elseif target:sub(1, 5) == "tier:" then
    local n = tonumber(target:sub(6))
    for i = 1, 9 do local sr = self.slotRigs[i]; if sr and (Units[sr.id].rank or 0) == n then set[i] = true end end
    labelKey, labelVars = "ui.command_tier", { n = n }
  elseif target:sub(1, 6) == "level:" then
    local n = tonumber(target:sub(7))
    for i = 1, 9 do local sr = self.slotRigs[i]; if sr and (sr.level or 1) == n then set[i] = true end end
    labelKey, labelVars = "ui.command_level", { n = n }
  elseif target:sub(1, 5) == "type:" then
    local ty = target:sub(6)
    for i = 1, 9 do
      local sr = self.slotRigs[i]
      if sr and Units[sr.id] and Units[sr.id].type == ty then set[i] = true end
    end
    labelKey, labelVars = "ui.command_type", { type = T("type." .. ty) }
  else -- grant_team (Bris-Siège, stripEnemyShield) : pas de cible AMIE -> étiquette « toute la meute » (effet d'équipe)
    for i = 1, 9 do if self.slotRigs[i] then set[i] = true end end
    labelKey = "ui.command_pack"
  end
  return set, labelKey, labelVars
end

-- Résout le SLOT d'un rôle (front/back/center) sur les unités POSÉES, MIROIR de buildComp (depth + degré du
-- sigil + tie-break row asc puis slot asc). Réutilisé par commandRange ET (potentiellement) ailleurs. nil si vide.
function Build:resolveRoleSlot(role)
  local placed = {}
  for i = 1, 9 do
    if self.slotRigs[i] then
      local c = self.board.shape.cells[i]
      placed[#placed + 1] = { slot = i, col = c.x, row = c.y }
    end
  end
  if #placed == 0 then return nil end
  local maxC = -math.huge
  for _, p in ipairs(placed) do if p.col > maxC then maxC = p.col end end
  local function tieLess(a, b) if a.row ~= b.row then return a.row < b.row end return a.slot < b.slot end
  if role == "center" then
    local best, bestDeg
    for _, p in ipairs(placed) do
      local deg = self.board:degreeOf(p.slot)
      if not bestDeg or deg > bestDeg or (deg == bestDeg and p.slot < best.slot) then best, bestDeg = p, deg end
    end
    if best and bestDeg and bestDeg >= 4 then return best.slot end
    role = "front" -- fallback déterministe (sigil sans nœud de degré 4)
  end
  local wantMin = (role ~= "back")
  local best
  for _, p in ipairs(placed) do
    local d = maxC - p.col
    if not best then best = p
    else
      local bd = maxC - best.col
      if (wantMin and d < bd) or (not wantMin and d > bd) or (d == bd and tieLess(p, best)) then best = p end
    end
  end
  return best and best.slot or nil
end

-- ── BARRE DU BAS = une RANGÉE flex (moteur Layout) en ESPACE DESIGN ────────────────────────────────
-- [ colonne ORBE DE VIE (gauche) | rangée OFFRES (flex, remplit le milieu) | colonne BOUTONS (droite) ].
-- TOUT est aligné/snappé, sans trou : la rangée des offres ABSORBE l'espace restant (flex) et chaque carte
-- a la MÊME taille avec des gouttières ÉGALES ; l'orbe REMPLIT la hauteur de sa colonne (pas un petit orbe
-- flottant dans une grande boîte). Les widgets forge sont BAKÉS À LA TAILLE CALCULÉE (fill réel). On
-- calcule les rects DESIGN une fois ; les hit-tests souris (en VIRTUEL) sont dérivés (÷4) -> self.shopSlots.
-- ── BARRE DU BAS = handoff designer « Bottom Bar.dc.html » : un PANNEAU ENCADRÉ (bord iron + dégradé + filet
-- laiton gravé en haut) découpé en 3 colonnes séparées par des filets iron :
--   [ LIFE VESSEL 168 (LIVES n/5 + orbe 108) | THE OFFERING (header + 5 cartes + rail de tier 5 crans) | ACTIONS 318 (FIGHT + éco) ].
-- Les `--vars` CSS du designer == nos tokens Theme.c (même palette). On calcule les rects DESIGN une fois ;
-- les hit-tests souris (VIRTUEL) sont dérivés (÷4).
local BAR = { x = 16, y = 524, w = 1280 - 32, h = 720 - 524 - 12 } -- panneau encadré du bas (design), h ~184
local BAR_RULE = 2     -- filet laiton gravé en haut du panneau
local ORB_D = 108      -- diamètre de l'orbe de vie (life vessel)
local CARD_ART_H = 74  -- zone d'art de la carte miniature (le reste = pied nom/coût)
local CARD_FOOT_H = 28 -- pied de carte (nom + coût)

function Build:computeShop()
  -- contenu sous le filet laiton ; marges du panneau (≈ design : padding 16/4).
  local inner = Layout.inset(BAR, { l = 4, t = BAR_RULE + 14, r = 4, b = 16 })
  -- 3 colonnes séparées par des filets iron (1px), sans gouttière.
  local cols = Layout.row(inner, {
    { size = 150 }, { size = 1 }, { flex = 1 }, { size = 1 }, { size = 290 },
  }, { gap = 0, align = "stretch" })
  self.lay = { lifeCol = cols[1], div1 = cols[2], offerCol = cols[3], div2 = cols[4], actCol = cols[5] }

  -- LIFE VESSEL : [ LIVES n/5 ] au-dessus de l'orbe 108 ; le groupe centré verticalement dans la colonne.
  local lc = cols[1]
  local groupH = 14 + 11 + ORB_D
  local gy = lc.y + math.floor((lc.h - groupH) / 2)
  self.lay.lifeLabel = { x = lc.x, y = gy, w = lc.w, h = 14 }
  self.lay.lifeOrbBox = { x = lc.x + math.floor((lc.w - ORB_D) / 2), y = gy + 25, w = ORB_D, h = ORB_D }

  -- THE OFFERING : header (14) + marge (11) + bloc [ cartes (haut) … rail de tier (bas, poussé en bas) ].
  local oin = Layout.inset(cols[3], { l = 18, t = 0, r = 18, b = 0 })
  local orows = Layout.column(oin, { { size = 14 }, { size = 11 }, { flex = 1 } }, { gap = 0, align = "stretch" })
  self.lay.offerHeader = orows[1]
  local block = Layout.column(orows[3], { { size = CARD_ART_H + CARD_FOOT_H }, { flex = 1 }, { size = 20 } }, { gap = 0, align = "stretch" })
  self.lay.cardsRow = block[1]
  self.lay.tierRail = block[3]
  local specs = {}
  for _ = 1, Run.SHOP_SIZE do specs[#specs + 1] = { flex = 1 } end
  self.lay.cards = Layout.row(self.lay.cardsRow, specs, { gap = 10, align = "stretch" })

  -- ACTIONS : spacer (= header+marge, aligne FIGHT au haut des cartes) + FIGHT (flex) + cluster éco (bas).
  local ain = Layout.inset(cols[5], { l = 16, t = 0, r = 16, b = 0 })
  local arows = Layout.column(ain, { { size = 25 }, { flex = 1 }, { size = 9 }, { size = 34 } }, { gap = 0, align = "stretch" })
  self.lay.combatBox = arows[2] -- FIGHT remplit jusqu'au bas des cartes
  self.lay.ecoRow = arows[4]    -- cluster éco sur la ligne du rail de tier
  -- éco : 2 boutons (BUY XP | REROLL) hors grant ; 3 (… | REFUSER) pendant un grant. On calcule les deux.
  local eco2 = Layout.row(arows[4], { { flex = 1 }, { flex = 1 } }, { gap = 7, align = "stretch" })
  local eco3 = Layout.row(arows[4], { { flex = 1 }, { flex = 1 }, { flex = 1 } }, { gap = 7, align = "stretch" })
  self.lay.buyXp2, self.lay.reroll2 = eco2[1], eco2[2]
  self.lay.buyXp3, self.lay.reroll3, self.lay.refuse3 = eco3[1], eco3[2], eco3[3]

  -- hit-tests souris (VIRTUEL ÷4).
  local function toV(r) return { x = r.x / 4, y = r.y / 4, w = r.w / 4, h = r.h / 4 } end
  self._toV = toV
  self.shopSlots = {}
  for i = 1, Run.SHOP_SIZE do self.shopSlots[i] = toV(self.lay.cards[i]) end
  self.button = toV(self.lay.combatBox)
  self:syncEcoRects(false)
  self.xpBarRect = toV(self.lay.tierRail) -- survol du rail de tier -> infobulle des cotes (drawOddsTooltip)
  self:computeBench()
end

-- BANC (réserve) : rangée de slots centrée, juste au-dessus du bandeau boutique. Rects en VIRTUEL
-- (÷4) comme shopSlots -> hit-tests directs, ×4 au rendu. La réserve sert à STOCKER/FUSIONNER, elle ne combat jamais.
function Build:computeBench()
  local SLOT, GAP, Y = 60, 10, 452 -- taille/gouttière/haut de bande (design) ; remonté : la barre du bas est plus haute (handoff)
  local n = self:benchCapacity()
  local total = n * SLOT + (n - 1) * GAP
  local x0 = math.floor(640 - total / 2 + 0.5) -- centré sur la largeur design (1280)
  self.benchSlots = {}
  for i = 1, n do
    local dx = x0 + (i - 1) * (SLOT + GAP)
    self.benchSlots[i] = { x = dx / 4, y = Y / 4, w = SLOT / 4, h = SLOT / 4 } -- VIRTUEL (÷4)
  end
end

-- ── GAME FEEL : effets ÉPHÉMÈRES (achat / vente / level-up) ─────────────────────────────────────────
-- Petit système d'effets transitoires : data { kind, x, y, t, dur, ... } en ESPACE DESIGN, avancés par
-- update, dessinés en overlay PAR-DESSUS tout. Le SPAWN est PUR (data) -> sans danger headless ; le DRAW
-- vit en overlay (love.graphics). Render-only -> golden inchangé.
--
-- CHORÉGRAPHIE DE FUSION (transplantée de feel-lab/lib/levelup.lua, source de vérité du « ta-ta-ta-TAAA ») :
-- anticipation -> convergence STAGGERÉE des âmes (en ARC + traînée) -> impacts RYTHMÉS (chaque arrivée = un
-- micro-shake + le degré de `ladder` déjà joué) -> CLIMAX (flash + onde de choc + squash-stretch + trauma² +
-- hitstop, synchro <50 ms avec le `success`) -> settle. Le MOUVEMENT est posé ici ; le SON (ladder/success)
-- est déjà câblé (increment 2). 100% RENDER, dt MURAL, ne touche JAMAIS la SIM (firewall) ; headless-safe.
local MERGE_FLY_DUR = 0.34   -- durée de VOL d'UNE âme vers le survivant (convergence)
local MERGE_ANTICIP = 0.12   -- creux d'anticipation du survivant avant la 1re arrivée (le lab pose ANTICIP=0.12)
local MERGE_STAGGER = 0.13   -- espacement des DÉPARTS des âmes -> arrivées rythmées (« ta. ta. »)
local MERGE_CLIMAX  = 0.50   -- fenêtre de climax (burst + onde) après la DERNIÈRE arrivée
local MERGE_SETTLE  = 0.30   -- détente finale (overshoot doux du ressort)
local MERGE_RELIC_BUFFER = 0.30 -- BUFFER (s murales) après la fin de l'anim de fusion avant d'ouvrir la pop-up de
                                -- relique de level-up : on s'assure que l'user a VU l'explosion entière (couvre la
                                -- DERNIÈRE fusion d'une cascade, pas la première). Cf. Build:levelUpActive/armLevelRelic.

-- ── POP DE POSE (retour user) : petite VIBRATION LOCALE du monstre quand il APPARAÎT sur une case (achat/pose).
-- Pas de screen-shake / pas de trauma (trop pour une simple pose) : c'est le RIG qui frémit en place. Réutilise
-- la même mécanique de champ d'anim que la fusion (`.pop` sur le rig, avancé dans update, lu au DRAW) mais en
-- VARIANTE LÉGÈRE et INDÉPENDANTE de `bounce` (la fusion n'est PAS touchée). Punchy, bref, settle rapide.
-- Leviers : POP_DUR (durée), POP_SCALE (amplitude squash-stretch), POP_SHAKE (amplitude du frémissement px virtuels).
local POP_DUR   = 0.30   -- durée totale de la vibration de pose (s) — brève
local POP_SCALE = 0.18   -- amplitude du squash-stretch initial (pic à t=0, puis settle amorti)
local POP_SHAKE = 1.4    -- amplitude du frémissement HORIZONTAL (px VIRTUELS) — petit tremblement qui se résorbe
local function newPopAnim() return { t = 0, dur = POP_DUR } end

-- Bézier quadratique scalaire (p0 -> contrôle c -> p1 ; e ∈ 0..1) — arc des âmes de fusion (cf. Feel Lab).
local function bez2(p0, cc, p1, e)
  local u = 1 - e
  return u * u * p0 + 2 * u * e * cc + e * e * p1
end

function Build:spawnFx(kind, x, y, opts)
  opts = opts or {}
  self.fx[#self.fx + 1] = { kind = kind, x = x, y = y, t = 0, dur = opts.dur or 0.55,
    gold = opts.gold, level = opts.level, fromX = opts.fromX, fromY = opts.fromY, delay = opts.delay or 0,
    sfxClimax = opts.sfxClimax, idx = opts.idx, n = opts.n, big = opts.big, cx = opts.cx, cy = opts.cy }
end

-- POSE D'UNE UNITÉ (retour user) : quand un monstre APPARAÎT sur une case (achat au clic auto-placé OU lâcher du
-- drag sur une case), il FRÉMIT en place (vibration locale du rig) + le son « place » sonne. PAS de particule
-- d'achat (retirées : « c'est laid »), PAS de screen-shake (trop pour une pose). On pose juste `.pop` sur le rig
-- (lu par mergeScale/popShakeX au DRAW, avancé dans update) et on joue la cue. SFX.play est no-op headless / sur
-- cue inconnue -> golden-safe, pas de crash si la cue « place » arrive après. RENDER pur.
function Build:popPlaced(rig)
  if rig then rig.pop = newPopAnim() end
  SFX.play("place") -- cue d'APPARITION sur la case (créée en parallèle par le sound-designer ; id = "place")
end

-- DÉBLOCAGE D'UNE CASE (retour user) : quand on clique pour ouvrir une case verrouillée (grant accepté), une
-- PETITE EXPLOSION façon level-up — MÊME chemin particules pixel que la fusion (P.burst/P.ring), mais VERSION
-- RÉDUITE (un déblocage < un rank-up) : moins de particules, onde plus petite, pas de shards énormes. + un
-- PETIT punch LOCAL (trauma² modeste + micro-hitstop, one-shot, très en-dessous du climax de fusion) + le son
-- « unlock ». 100% RENDER/cosmétique (P.* no-op hors love.graphics ; SFX.play no-op headless/cue absente) ->
-- golden-safe, ne touche jamais la SIM. `slotIndex` = la case ouverte ; ancre = son centre design (pos×4).
-- Leviers : counts/r1 ci-dessous (taille explosion) ; UNLOCK_TRAUMA/UNLOCK_FREEZE (punch).
local UNLOCK_TRAUMA = 0.20  -- secousse du déblocage (one-shot, modeste : < climax fusion 0.55/0.85)
local UNLOCK_FREEZE = 0.04  -- micro-hitstop bref
function Build:unlockFx(slotIndex)
  local p = self.pos[slotIndex]
  if not p then return end
  local x, y = p.x * 4, p.y * 4
  local c = Theme.c
  Juice.addTrauma(UNLOCK_TRAUMA)
  Juice.freeze(UNLOCK_FREEZE)
  SFX.play("unlock") -- cue de DÉBLOCAGE de case (créée en parallèle par le sound-designer ; id = "unlock")
  -- onde de choc dithérée (pixel) + éclats — RÉDUITS vs le climax de fusion (90px ring / shard 20 → ici ~50 / 8).
  P.ring(x, y, { color = c.gold, r0 = 6, r1 = 50, life = 0.40 })
  P.burst(x, y, { type = "shard", count = 8, speed = { 80, 180 }, life = { 0.35, 0.6 }, gravity = 200, drag = 1.7, spin = 12 })
  P.burst(x, y, { type = "ember", count = 8, dir = -math.pi / 2, spread = math.pi * 0.8, speed = { 40, 110 }, life = { 0.45, 0.8 }, gravity = -45, drag = 2.2 })
  P.burst(x, y, { type = "mote",  count = 6, speed = { 50, 150 }, life = { 0.28, 0.5 }, drag = 2.5 })
end

-- Centre (espace DESIGN) d'une position de jeu {kind, i} (case board ou slot banc) -> ancre des FX de fusion.
function Build:fxCenterOf(kind, i)
  if kind == "board" then return self.pos[i].x * 4, self.pos[i].y * 4 end
  local br = self.benchSlots[i]; return br.x * 4 + br.w * 2, br.y * 4 + br.h * 2
end

-- ── ANCRES DE DESSIN (espace VIRTUEL 320×180) du SPRITE d'une pièce, par lieu logique ──────────────────────
-- = le point « pieds au sol » où drawWorld cale la créature (board / banc / piédestal). Le RESSORT de drag
-- (src/ui/drag.lua) fait GLISSER le sprite vers cette ancre au lieu de l'y téléporter : c'est purement VISUEL
-- (la pièce est DÉJÀ logiquement dans sa case). Source unique partagée par update (cible du ressort) et
-- drawWorld (position de secours si pas de ressort). Renvoie (x, y) en VIRTUEL.
function Build:boardAnchor(i) local p = self.pos[i]; return p.x, p.y + 10 end
function Build:benchAnchor(i) local r = self.benchSlots[i]; return r.x + r.w / 2, r.y + r.h - 1 end
function Build:commanderAnchor()
  local r = self.commanderRect
  return r.x + r.w / 2, r.y + r.h - 1
end

-- Cible de REPOS (ancre de dessin VIRTUEL) d'une pièce selon son lieu logique courant. nil si introuvable.
function Build:pieceRestTarget(where, i)
  if where == "board" then return self:boardAnchor(i)
  elseif where == "bench" then return self:benchAnchor(i)
  elseif where == "commander" then return self:commanderAnchor() end
end

-- Garantit (lazy) le ressort de drag `.d` d'une pièce, posé AU REPOS sur sa cible (pas de glisse au montage/
-- au premier passage). `seedX,seedY` = ancre courante. Centralisé -> aucun site de création de pièce à toucher.
function Build:ensureSpring(sr, seedX, seedY)
  if not sr.d then sr.d = {}; Drag.snap(sr.d, seedX, seedY) end
  return sr.d
end

-- PICKUP : initialise le ressort du jeton qu'on SAISIT. On REPREND le ressort de la pièce d'origine (`srcD`)
-- s'il existe -> la pièce se SOULÈVE depuis où elle est (pas de saut sous le curseur) ; le GRAB est l'écart
-- souris↔sprite courant (la pièce suit le curseur en gardant ce décalage). Convention d'ANCRE = pieds au sol
-- (my + 9, comme le repos board/banc et mousemoved) -> cohérence parfaite begin/move. RENDER pur : aucune
-- mutation logique. Si pas de ressort source, on amorce sous le curseur (lift immédiat, sans glisse parasite).
function Build:beginDrag(srcD)
  local d = srcD or {}
  local ay = self.my + 9
  if d.px == nil then d.px, d.py = self.mx, ay end
  Drag.begin(d, self.mx, ay, self.mx - d.px, ay - d.py)
  self.drag.d = d
end

-- RESSORT de drag (dt en SECONDES murales) : chaque pièce AU REPOS (board/banc/piédestal) voit sa cible logique
-- = l'ancre de dessin de sa case et GLISSE vers elle (pose/swap fluides) ; la pièce TRAÎNÉE suit la souris (sa
-- cible posée par Drag.move/beginDrag). 100% VISUEL : on n'écrit JAMAIS l'état logique (qui-est-où) — seul px,py
-- bouge. Les pièces in-containers sont toutes au repos (la traînée est sortie de son container au pickup).
function Build:updateSprings(dtSec)
  for i, sr in pairs(self.slotRigs) do
    if self.board.slots[i].unlocked then
      local ax, ay = self:boardAnchor(i)
      self:ensureSpring(sr, ax, ay); Drag.setTarget(sr.d, ax, ay); Drag.apply(sr.d, dtSec)
    end
  end
  for i = 1, self:benchCapacity() do
    local sr = self.bench[i]
    if sr then
      local ax, ay = self:benchAnchor(i)
      self:ensureSpring(sr, ax, ay); Drag.setTarget(sr.d, ax, ay); Drag.apply(sr.d, dtSec)
    end
  end
  if self.commanderSlot and self.commanderRect then
    local sr = self.commanderSlot
    local ax, ay = self:commanderAnchor()
    self:ensureSpring(sr, ax, ay); Drag.setTarget(sr.d, ax, ay); Drag.apply(sr.d, dtSec)
  end
  if self.drag and self.drag.d then Drag.apply(self.drag.d, dtSec) end -- la traînée : cible = souris (Drag.move)
end

-- ANIM DE FUSION — chorégraphie multi-étapes du Feel Lab (le « ta-ta-ta-TAAA »). Les ÂMES des copies consommées
-- FILENT en ARC (Bézier, décalées dans le temps = stagger) vers le survivant (froms = liste {x,y} en design),
-- chaque ARRIVÉE étant un impact rythmé (micro-shake + un degré de `ladder`) ; puis le CLIMAX (burst + onde de
-- choc + squash-stretch + trauma² + hitstop) tombe à la DERNIÈRE arrivée, et le rig se DÉTEND (bounce/ressort).
-- `lvl == MAX_LEVEL` (niveau 3 / fin de cascade) -> climax PLEINE PUISSANCE (big), façon rank-up TFT.
function Build:spawnMergeFx(sx, sy, froms, lvl)
  local n = #froms
  local big = (lvl or 2) >= MAX_LEVEL
  -- SON (fusion) : « ta-ta-ta-TAAA ». Échelle montante (ladder) RÉINITIALISÉE au début de la convergence, puis
  -- 1 degré qui monte par âme qui file vers le survivant ; le CLIMAX (success) est joué à l'IMPACT (dernière âme
  -- arrivée) -> on le porte par le FX `levelup` (flag sfxClimax, déclenché dans updateFx au franchissement du
  -- délai, EXACTEMENT à la pose de son burst visuel). RENDER pur (SFX.play est no-op headless) -> golden-safe.
  SFX.ladder(true) -- reset de l'échelle (premier degré ne sonne pas : la 1re âme jouera le degré 2, etc.)
  -- une âme par copie consommée, DÉPART décalé (stagger) -> ARRIVÉES rythmées (le ladder par-âme suit le départ).
  for i, f in ipairs(froms) do
    -- point de contrôle de l'ARC : milieu décalé PERPENDICULAIREMENT (alterné gauche/droite) + soulevé vers le haut.
    local mx, my = (f[1] + sx) / 2, (f[2] + sy) / 2
    local dx, dy = sx - f[1], sy - f[2]
    local len = math.max(1, math.sqrt(dx * dx + dy * dy))
    local side = (i % 2 == 0) and 1 or -1
    local cx = mx + (-dy / len) * len * 0.18 * side
    local cy = my + (dx / len) * len * 0.18 * side - len * 0.10
    local depart = MERGE_ANTICIP + (i - 1) * MERGE_STAGGER
    self:spawnFx("merge_fly", sx, sy, { fromX = f[1], fromY = f[2], cx = cx, cy = cy,
      delay = depart, dur = depart + MERGE_FLY_DUR, idx = i, n = n, big = big })
    SFX.ladder() -- un cran plus haut par âme (1, 2, … -> tension qui grimpe pendant la convergence)
  end
  -- CLIMAX différé : posé à la DERNIÈRE arrivée (depart de la dernière âme + son vol) -> le « TAAA » coïncide
  -- exactement avec l'impact final. dur englobe la fenêtre de climax (burst/onde) + la détente (settle).
  local climaxAt = MERGE_ANTICIP + (n - 1) * MERGE_STAGGER + MERGE_FLY_DUR
  self:spawnFx("levelup", sx, sy, { level = lvl, big = big, sfxClimax = true,
    delay = climaxAt, dur = climaxAt + MERGE_CLIMAX + MERGE_SETTLE })
end

-- ── CHORÉGRAPHIE DE FUSION côté SURVIVANT (squash-stretch + lift + glow) ──────────────────────────────────
-- Le rig promu porte `bounce` = état de l'animation. `t` court depuis la pose (négatif au sens de l'horloge de
-- l'ancien bounce : on garde le nom de champ pour ne PAS toucher la logique de fusion). `climaxAt` = instant de
-- la DERNIÈRE arrivée d'âme (= le « TAAA »). Avant : ANTICIPATION (léger creux + glow qui monte). Au climax :
-- punch de scale (squash-stretch) + lift + glow plein. Après : SETTLE (overshoot doux qui revient au repos).
-- Transplante le ressort de la cible du Feel Lab (lib/levelup.lua tspring/_pulse) en formule fermée, dt-mural.
-- `t`/`dur` avancés dans update() (frameDt/60) ; lus au DRAW. Tout est COSMÉTIQUE (golden-safe).
local function newMergeAnim(n, big)
  -- climaxAt = MERGE_ANTICIP + (n-1)*MERGE_STAGGER + MERGE_FLY_DUR (cf. spawnMergeFx) ; dur englobe le settle.
  n = math.max(1, n or 1)
  local climaxAt = MERGE_ANTICIP + (n - 1) * MERGE_STAGGER + MERGE_FLY_DUR
  -- INSTANTS D'ARRIVÉE de chaque âme (alignés EXACTEMENT sur spawnMergeFx : depart_i + MERGE_FLY_DUR). Le rig
  -- doit RÉAGIR à CHACUN (throb « ta ») -> on les stocke pour que mergeEnv somme un pulse amorti par arrivée
  -- (la choré multi-étapes du lab : tspring + _pulse par beat). La DERNIÈRE arrivée == climaxAt (« TAAA »).
  local arrivals = {}
  for i = 1, n do arrivals[i] = MERGE_ANTICIP + (i - 1) * MERGE_STAGGER + MERGE_FLY_DUR end
  return { t = 0, climaxAt = climaxAt, dur = climaxAt + MERGE_CLIMAX + MERGE_SETTLE, big = big or false, arrivals = arrivals }
end

-- Enveloppe de la chorégraphie MULTI-ÉTAPES (transplant FIDÈLE de feel-lab/lib/levelup.lua : tspring + _pulse).
-- -> (lift px VIRTUELS vers le haut, facteur de scale autour de 1, glow 0..1). Au lieu d'une simple bosse au
-- climax, le rig est un RESSORT amorti recevant des IMPULSIONS DISCRÈTES — reproduites en forme fermée par une
-- SUPERPOSITION de pulses amortis (golden-safe, déterministe, dt-mural) :
--   1) ANTICIPATION : un CREUX de charge net au tout début (le rig « inspire »).
--   2) ARRIVÉE de CHAQUE âme (« ta ») : un THROB de scale + un bump de glow -> le rig PULSE à chaque beat
--      (la DERNIÈRE arrivée == climax). C'est ça, le « ta-ta-ta » visible ABSENT de l'ancienne version.
--   3) CLIMAX (« TAAA ») : gros pulse de scale + saut (lift) + glow plein, puis SETTLE en oscillant.
-- Le ressort du lab (k=360, d=22) est sous-amorti : ζ≈0.58 -> chaque pulse décroît en ~0.09 s en oscillant à
-- ~15.5 rad/s. On modélise un pulse par A·exp(-(t-ti)/TAU)·cos((t-ti)·OMEGA), sommé sur tous les beats franchis.
local MERGE_TAU   = 0.10   -- décroissance d'un pulse (s) — sous-amorti, « vivant »
local MERGE_OMEGA = 15.5   -- pulsation du ressort (rad/s) — overshoot organique
-- amplitudes (calibrées sur _pulse(amt) du lab : peak ≈ amt·1.4) :
local A_ANTICIP   = -0.14  -- creux d'anticipation (lab _pulse(-0.10))  ; big -> plus profond
local A_BEAT      = 0.075  -- throb par arrivée d'âme (lab _pulse(0.05))
local A_CLIMAX    = 0.34   -- gros pulse au climax (lab _pulse(0.24))    ; big -> 0.48

-- contribution d'un pulse posé à `ti`, lue à `t` (0 si pas encore déclenché). Décroissance × oscillation.
local function springPulse(t, ti, amp)
  if t < ti then return 0 end
  local a = t - ti
  return amp * math.exp(-a / MERGE_TAU) * math.cos(a * MERGE_OMEGA)
end

local function mergeEnv(b)
  if not b then return 0, 1, 0 end
  local t = b.t or 0
  local big = b.big
  local arrivals = b.arrivals
  local ca = b.climaxAt or MERGE_FLY_DUR
  local nA = arrivals and #arrivals or 1

  -- SCALE = 1 + somme des pulses (anticipation + chaque arrivée + climax). Le climax = la DERNIÈRE arrivée :
  -- on remplace son throb léger par le GROS pulse du « TAAA » (sinon double-compte).
  local sc = 0
  sc = sc + springPulse(t, 0.0, big and (A_ANTICIP * 1.35) or A_ANTICIP) -- 1) creux de charge (dès t=0)
  if arrivals then
    for i = 1, nA do
      local ti = arrivals[i]
      if i == nA then
        sc = sc + springPulse(t, ti, big and 0.48 or A_CLIMAX)            -- 3) CLIMAX (dernière arrivée = « TAAA »)
      else
        sc = sc + springPulse(t, ti, A_BEAT)                              -- 2) THROB par arrivée d'âme (« ta »)
      end
    end
  else
    sc = sc + springPulse(t, ca, big and 0.48 or A_CLIMAX)
  end

  -- GLOW : rampe douce pendant la convergence + bump à chaque arrivée, plein au climax, puis décroît au settle.
  local glow
  if t < ca then
    glow = math.max(0, math.min(1, (t / math.max(0.001, ca)) * 0.55)) -- rampe de base
    if arrivals then
      for i = 1, nA - 1 do if t >= arrivals[i] then glow = math.min(1, glow + 0.28 * math.exp(-(t - arrivals[i]) / 0.35)) end end
    end
  else
    glow = math.exp(-(t - ca) / 0.16) -- plein (1) au climax puis settle
  end

  -- LIFT (saut) : seulement au CLIMAX (le rig « bondit » sur le TAAA), amorti. 0 avant.
  local lift = 0
  if t >= ca then
    local a = t - ca
    lift = math.sin(math.min(1, a / 0.42) * math.pi) * (big and 4 or 3) * math.exp(-a / 0.16)
  end

  return lift, 1 + sc, glow
end

-- Enveloppe du pop -> (scaleMul autour de 1, shakeX en px virtuels). No-op (1, 0) hors animation.
-- Squash-stretch : pic de stretch à t=0 puis ressort amorti ; frémissement : sinus rapide × décroissance.
local function popEnv(p)
  if not p then return 1, 0 end
  local e = math.max(0, math.min(1, (p.t or 0) / math.max(0.001, p.dur or POP_DUR)))
  local decay = math.exp(-e * 4.0)                       -- amortissement rapide (≈ settle en ~1 dur)
  local sc = 1 + POP_SCALE * decay * math.cos(e * 22)    -- stretch puis oscillation qui s'éteint
  local shake = POP_SHAKE * decay * math.sin(e * 38)     -- frémissement horizontal bref
  return sc, shake
end

-- Décalage vertical (px VIRTUELS, vers le HAUT) du saut de fusion. 0 hors animation. (Compat : nom historique.)
local function bounceLift(sr)
  local lift = mergeEnv(sr.bounce)
  return lift
end
-- Facteur de scale (squash-stretch) total du rig : fusion (mergeEnv) × pop de pose (popEnv). 1 au repos.
local function mergeScale(sr) local _, sc = mergeEnv(sr.bounce); local pc = popEnv(sr.pop); return sc * pc end
-- Lueur 0..1 du survivant pendant la fusion (halo additif au climax). Le pop de pose n'a PAS de glow (sobre).
local function mergeGlow(sr) local _, _, g = mergeEnv(sr.bounce); return g end
-- Frémissement HORIZONTAL (px virtuels) du pop de pose. 0 hors animation.
local function popShakeX(sr) local _, sx = popEnv(sr.pop); return sx end

function Build:updateFx(frameDt)
  local dt = frameDt / 60 -- frames -> secondes
  -- PARTICULES PIXEL (transplant Feel Lab) : avancées au MÊME dt que les FX. main.lua passe déjà frameDt
  -- multiplié par Juice.timeScale() -> dt = 0 pendant un hitstop, donc les particules SE FIGENT au gel
  -- exactement comme dans le lab (rooms/levelup.lua : P.update(dt*ts)). RENDER pur, headless-safe (P.update
  -- est no-op si dt<=0 ; P.draw garde love.graphics). Le golden ne voit JAMAIS ces appels (drawFx/updateFx
  -- ne tournent pas en headless).
  P.update(dt)
  local c = Theme.c
  local n, w = #self.fx, 0
  for i = 1, n do
    local f = self.fx[i]
    local was = f.t
    f.t = f.t + dt
    -- IMPACT RYTHMÉ d'une âme (« ta ») : au franchissement de SON arrivée (delay+vol = f.dur pour merge_fly),
    -- micro screen-shake (trauma²) + petit punch-glow local. Le degré de `ladder` correspondant est DÉJÀ joué
    -- (spawnMergeFx) ; ici on apporte le MOUVEMENT apparié. Juice = RENDER pur (dt mural) -> firewall respecté.
    if f.kind == "merge_fly" and was < f.dur and f.t >= f.dur then
      Juice.addTrauma(0.10)
      -- « ta » : petite gerbe d'étincelles + motes dorées (sprites pixel), à l'IMPACT de l'âme sur le survivant
      -- (= centre de la fusion f.x,f.y). Recette autoritaire de feel-lab/lib/levelup.lua (beats rythmiques).
      P.burst(f.x, f.y, { type = "mote", count = 5, speed = { 50, 140 }, life = { 0.2, 0.4 }, drag = 3 })
      P.burst(f.x, f.y, { type = "spark", count = 3, speed = { 80, 170 }, life = { 0.15, 0.3 }, drag = 3 })
    end
    -- CLIMAX (« TAAA ») : à l'IMPACT final (franchissement du delay du burst `levelup`), une seule fois —
    -- trauma² PLEIN + hitstop (gel bref) + SON success/thud, synchro <50 ms avec le burst/onde visuels (drawFx).
    if f.kind == "levelup" and was < f.delay and f.t >= f.delay then
      local big = f.big
      Juice.addTrauma(big and 0.85 or 0.55)
      Juice.freeze(big and 0.12 or 0.08)
      if f.sfxClimax then SFX.play("success"); SFX.play("thud", { vol = 0.8 }) end
      -- EXPLOSION PIXEL (le gros de l'effet) — recette autoritaire de feel-lab/lib/levelup.lua, émise EN UNE
      -- frame (synchro <50 ms avec le flash/le shake/le hitstop). On émet ICI (updateFx) plutôt que dans drawFx
      -- pour ne tirer la salve QU'UNE fois (drawFx tourne sans état). big = climax PLEINE PUISSANCE (niveau 3/cascade).
      local GOLD, EMBER = c.gold, c.ember
      P.ring(f.x, f.y, { color = GOLD, r0 = 8, r1 = big and 150 or 90, life = big and 0.55 or 0.42 })
      if big then P.ring(f.x, f.y, { color = EMBER, r0 = 4, r1 = 120, life = 0.5 }) end
      -- éclats dorés (matière) qui jaillissent et retombent
      P.burst(f.x, f.y, { type = "shard", count = big and 30 or 20, speed = { 90, big and 300 or 220 },
        life = { 0.45, big and 0.9 or 0.7 }, gravity = 220, drag = 1.6, spin = 12 })
      -- braises montantes (signature grimdark) — fan vers le haut, gravité négative
      P.burst(f.x, f.y, { type = "ember", count = big and 22 or 14, dir = -math.pi / 2, spread = math.pi * 0.8,
        speed = { 40, 130 }, life = { 0.5, big and 1.0 or 0.8 }, gravity = -50, drag = 2.2 })
      -- cendres qui dérivent puis retombent
      P.burst(f.x, f.y, { type = "ash", count = big and 16 or 10, speed = { 30, 110 }, life = { 0.6, 1.1 }, gravity = 120, drag = 1.8 })
      -- motes dorées (éclat)
      P.burst(f.x, f.y, { type = "mote", count = big and 14 or 8, speed = { 60, 180 }, life = { 0.3, 0.6 }, drag = 2.5 })
    end
    if f.t < f.dur then w = w + 1; self.fx[w] = f end
  end
  for i = w + 1, n do self.fx[i] = nil end

  -- POP-UP DE RELIQUE DIFFÉRÉE (retour user) : on ouvre l'offre 1-parmi-3 SEULEMENT une fois l'anim de fusion
  -- TERMINÉE + un buffer (MERGE_RELIC_BUFFER), pour ne pas la flasher en plein « TAAA ». Tant qu'un FX
  -- levelup/merge_fly vit (y compris la DERNIÈRE fusion d'une CASCADE), on RE-arme le buffer à plein -> il ne
  -- décompte qu'après la toute dernière explosion. dt MURAL (gelé pendant le hitstop comme le reste des FX,
  -- donc le buffer ne grignote pas pendant le gel). RENDER pur (firewall : ne lit/écrit jamais la SIM).
  if self.levelRelicCountdown ~= nil then
    local animLive = false
    for i = 1, #self.fx do
      local k = self.fx[i].kind
      if k == "levelup" or k == "merge_fly" then animLive = true; break end
    end
    if animLive then
      self.levelRelicCountdown = MERGE_RELIC_BUFFER -- anim encore en cours (ou cascade) -> on repousse l'ouverture
    else
      self.levelRelicCountdown = self.levelRelicCountdown - dt
      if self.levelRelicCountdown <= 0 then self:flushLevelRelicNow() end
    end
  end
end

function Build:drawFx()
  if #self.fx == 0 then return end
  local c = Theme.c
  for _, f in ipairs(self.fx) do
    local p = math.min(1, f.t / f.dur) -- 0..1
    local a = 1 - p
    if f.kind == "sell" then
      -- VENTE : « +N » d'or qui monte et s'estompe. (L'ancien FX « buy » a été RETIRÉ : la pose est désormais une
      -- vibration LOCALE du rig — Build:popPlaced — pas un effet d'écran. Plus aucun `spawnFx("buy", …)`.)
      Draw.textC("+" .. tostring(f.gold or 0), f.x, f.y - p * 26, { c.gold[1], c.gold[2], c.gold[3], a }, Theme.value(16))
    elseif f.kind == "merge_fly" then
      -- ÂME qui FILE en ARC (Bézier quadratique) de la copie consommée vers le survivant, DÉCALÉE dans le temps
      -- (delay = départ staggeré). Convergence en ease-IN (accélère en arrivant) + TRAÎNÉE additive multi-échantillon
      -- + noyau braise / halo or / étincelle blanche (look du Feel Lab). Invisible tant qu'elle n'est pas partie.
      if f.t >= f.delay then
        local fx0, fy0 = f.fromX or f.x, f.fromY or f.y
        local cx, cy = f.cx or ((fx0 + f.x) / 2), f.cy or ((fy0 + f.y) / 2)
        local lp = math.min(1, (f.t - f.delay) / math.max(0.001, f.dur - f.delay)) -- 0..1 LOCAL à cette âme
        local e = lp * lp -- ease-in
        local mx, my = bez2(fx0, cx, f.x, e), bez2(fy0, cy, f.y, e)
        local r = 4.5 * (1 - lp) + 1.5
        -- TRAÎNÉE : 4 échantillons en arrière sur l'arc, additifs, fondant (look « comète » du lab).
        love.graphics.setBlendMode("add")
        for s = 1, 4 do
          local ee = math.max(0, e - s * 0.06)
          local px, py = bez2(fx0, cx, f.x, ee), bez2(fy0, cy, f.y, ee)
          Draw.setColor({ c.gold[1], c.gold[2], c.gold[3], 0.18 * (1 - s / 5) * (1 - lp * 0.5) })
          love.graphics.circle("fill", px, py, (r - s * 0.6) * 0.9)
        end
        love.graphics.setBlendMode("alpha")
        Draw.setColor({ c.ember and c.ember[1] or c.blood[1], c.ember and c.ember[2] or c.blood[2], c.ember and c.ember[3] or c.blood[3], 0.5 * (1 - lp * 0.4) }) -- noyau braise
        love.graphics.circle("fill", mx, my, r * 1.4)
        Draw.setColor({ c.gold[1], c.gold[2], c.gold[3], 0.95 - 0.25 * lp }) -- coeur d'or
        love.graphics.circle("fill", mx, my, r)
        Draw.setColor({ 1, 1, 1, 0.7 * (1 - lp) }) -- étincelle blanche
        love.graphics.circle("fill", mx, my, r * 0.45)
        Draw.reset()
      end
    elseif f.kind == "levelup" then
      -- CLIMAX (« TAAA ») : burst DIFFÉRÉ (à la DERNIÈRE arrivée d'âme, cf. spawnMergeFx). L'ONDE DE CHOC + LES
      -- ÉCLATS sont désormais en PARTICULES PIXEL bakées (P.ring/P.burst, émises dans updateFx, dessinées par
      -- P.draw() plus bas) -> rendu PIXEL net comme le Feel Lab, fini les cercles lisses anti-aliasés « cheap ».
      -- Ici on ne garde QUE le FLASH BREF (disque additif local, comme self.flash du lab) + le « LVL n » qui pop
      -- (texte UI net). Le rig fait son squash-stretch (mergeEnv) au même instant (drawWorld) + le shake/hitstop
      -- (updateFx). big = climax PLEINE PUISSANCE (niveau 3/cascade).
      if f.t >= f.delay then
        local big = f.big
        local lp = math.min(1, (f.t - f.delay) / math.max(0.01, f.dur - f.delay))
        local la = 1 - lp
        local R = big and 1.5 or 1.0
        -- FLASH local au climax (disque additif blanc-or qui s'estompe vite ; transplant de LU:draw self.flash)
        love.graphics.setBlendMode("add")
        Draw.setColor({ 1, 0.95, 0.78, 0.7 * (1 - math.min(1, lp * 3.5)) })
        love.graphics.circle("fill", f.x, f.y, (8 + lp * 14) * R)
        love.graphics.setBlendMode("alpha")
        Draw.reset()
        Draw.textC("LVL " .. tostring(f.level or 2), f.x, f.y - 30 - lp * 14, { c.gold[1], c.gold[2], c.gold[3], la }, Theme.value(big and 17 or 15))
      end
    end
  end
  -- PARTICULES PIXEL par-dessus les transitoires (ember/shard/ash/spark/mote + onde dithérée). SOUS le même
  -- contexte Draw que le reste de drawFx (drawFx est appelé entre Draw.begin/Draw.finish dans drawOverlay) :
  -- coords en espace DESIGN, PX=4 = la grille-monde -> snap pixel net. RENDER pur (guard love.graphics).
  P.draw()
end

-- Synchronise le rect de hit-test REROLL selon qu'un grant attend (ligne scindée) ou non (ligne pleine).
-- Appelé chaque frame avant les clics/le rendu -> le hit-test colle TOUJOURS à ce qui est dessiné.
function Build:syncEcoRects(granting)
  -- cluster éco : [ BUY XP | REROLL ] hors grant ; [ BUY XP | REROLL | REFUSER ] pendant un grant.
  if granting then
    self.raiseBtn = self._toV(self.lay.buyXp3)
    self.rerollBtn = self._toV(self.lay.reroll3)
  else
    self.raiseBtn = self._toV(self.lay.buyXp2)
    self.rerollBtn = self._toV(self.lay.reroll2)
  end
  -- declineBtn TOUJOURS valide (jamais nil) : dessiné/hit-testé uniquement pendant un grant, mais on évite
  -- toute course (grant qui s'allume entre deux syncs) -> plus de crash inRect(nil) (retour user 2026-06).
  self.declineBtn = self._toV(self.lay.refuse3)
end

-- Rect (ESPACE DESIGN) du i-ème socle de relique dans le SEGMENT « RELICS » du bandeau de run (haut-gauche).
-- Le socle entier est la cible de survol (hit-test = ce qui est dessiné en drawRunBanner).
function Build:relicRowRect(i)
  return { x = RELIC_B_X0 + (i - 1) * RELIC_B_CELL, y = RELIC_B_Y, w = RELIC_B_S, h = RELIC_B_S }
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

-- ── Hit-tests (espace virtuel) — `inRect` est défini en tête de module (avant les méthodes qui l'utilisent). ──
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

function Build:shopFreezeRect(i)
  local r = self.shopSlots and self.shopSlots[i]
  if not r then return nil end
  return { x = r.x + r.w - 7, y = r.y + 7, w = 6, h = 5 }
end

function Build:shopFreezeAt(px, py)
  local run = self.host.run
  if not run or not run.freezeSlots or run.freezeSlots <= 0 then return nil end
  for i = 1, Run.SHOP_SIZE do
    local fr = self:shopFreezeRect(i)
    if fr and run.shop[i] and inRect(px, py, fr) then return i end
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
function Build:placeId(slot, id, level, opts)
  if not (self.board.slots[slot] and self.board.slots[slot].unlocked) then return false end
  opts = opts or {}
  self.slotRigs[slot] = self:makeOcc(id, level or 1, opts)
  self.board.slots[slot].unit = id
  return true
end

function Build:emitMergeEvent(ev)
  if self.mergeObserver then self.mergeObserver(ev) end
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
    for i = 1, self:benchCapacity() do scan("bench", i, self.bench[i]) end
    for _, key in ipairs(order) do -- ipairs (DÉTERMINISTE), jamais pairs
      local g = groups[key]
      if #g >= 3 then
        local keep = g[1]
        local kr = (keep.kind == "board") and self.slotRigs[keep.i] or self.bench[keep.i]
        local id, fromLevel, lvl = kr.id, kr.level or 1, (kr.level or 1) + 1
        local keepInfo = { kind = keep.kind, i = keep.i, id = id, level = fromLevel, copyId = kr.copyId }
        -- positions (design) AVANT mutation : survivant + 2 copies consommées (anim C3 : âmes qui filent vers lui).
        local sx, sy = self:fxCenterOf(keep.kind, keep.i)
        local froms = {}
        for k = 2, 3 do local p = g[k]; local fxx, fyy = self:fxCenterOf(p.kind, p.i); froms[#froms + 1] = { fxx, fyy } end
        local consumed = {}
        for k = 2, 3 do -- consomme 2 copies (plateau ou banc)
          local p = g[k]
          local sr = (p.kind == "board") and self.slotRigs[p.i] or self.bench[p.i]
          consumed[#consumed + 1] = {
            kind = p.kind, i = p.i, id = sr and sr.id or id,
            level = sr and (sr.level or fromLevel) or fromLevel,
            copyId = sr and sr.copyId or nil,
            mutations = sr and Mutations.clone(sr.mutations) or nil,
          }
          if p.kind == "board" then self.slotRigs[p.i] = nil; self.board.slots[p.i].unit = nil
          else self.bench[p.i] = nil end
        end
        -- promeut la 1re copie + lui pose un `bounce` = état de chorégraphie (anticipation -> climax -> settle),
        -- timé sur la DERNIÈRE arrivée d'âme (#froms copies, 2 ici) ; lu par mergeLift/mergeScale/mergeGlow au DRAW.
        local mutationLists = { kr.mutations }
        for _, entry in ipairs(consumed) do
          if entry.mutations then mutationLists[#mutationLists + 1] = entry.mutations end
        end
        local promoted = self:makeOcc(id, lvl, {
          bounce = newMergeAnim(#froms, lvl >= MAX_LEVEL),
          copyId = kr.copyId,
          mutations = Mutations.merge(mutationLists),
        })
        if keep.kind == "board" then self.slotRigs[keep.i] = promoted; self.board.slots[keep.i].unit = id
        else self.bench[keep.i] = promoted end
        self:emitMergeEvent({
          type = "merge", source = "checkMerges", id = id,
          fromLevel = fromLevel, toLevel = lvl,
          keep = keepInfo, consumed = consumed,
          result = { kind = keep.kind, i = keep.i, id = id, level = lvl, copyId = promoted.copyId },
        })
        self:spawnMergeFx(sx, sy, froms, lvl) -- âmes -> burst -> sautillement (« clean & polish », retour user)
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

-- ── PREVIEW de fusion (LECTURE PURE, zéro mutation) — pour le badge « LVL n » de la boutique. ──────────────
-- Simule l'AJOUT d'1 copie de `offer.id` au NIVEAU 1 (ce que fait autoBuy/buyMergeWhenFull) et reproduit
-- FIDÈLEMENT le groupage en cascade de checkMerges : 3 copies de MÊME id + MÊME niveau -> niveau+1, cap
-- MAX_LEVEL, re-scan après chaque promotion (une promotion peut en armer une autre). On ne suit QUE la
-- famille de `offer.id` : une fusion d'un AUTRE id ne peut jamais entrer dans un groupe de `offer.id` (clé
-- = id+level) et ne change donc pas le niveau atteint par cette offre. On compte les copies de offer.id par
-- niveau (board PUIS bench, comme checkMerges), on ajoute +1 au niveau 1, puis on applique la règle de trois
-- jusqu'à stabilité. Renvoie le NIVEAU FINAL atteint (>=2) SI au moins une fusion a lieu, sinon nil.
-- Invariant respecté : seuls les niveaux < MAX_LEVEL fusionnent (checkMerges:870 -> `scan` ignore le cap).
function Build:previewMergeLevel(offer)
  if not offer or not offer.id then return nil end
  local id = offer.id
  -- comptes[lvl] = nombre de copies de `id` à ce niveau (1..MAX_LEVEL). Lecture seule du board+banc.
  local count = {}
  for lvl = 1, MAX_LEVEL do count[lvl] = 0 end
  for i = 1, 9 do
    local sr = self.slotRigs[i]
    if sr and sr.id == id then local lv = sr.level or 1; if count[lv] then count[lv] = count[lv] + 1 end end
  end
  for i = 1, self:benchCapacity() do
    local sr = self.bench[i]
    if sr and sr.id == id then local lv = sr.level or 1; if count[lv] then count[lv] = count[lv] + 1 end end
  end
  count[1] = count[1] + 1 -- l'achat ajoute UNE copie de niveau 1

  -- Règle de trois en cascade (comme checkMerges, mais sur des compteurs) : du plus bas au plus haut niveau
  -- pouvant fusionner (< MAX_LEVEL), tant qu'un niveau a >=3 copies, on en consomme 3 et on promeut +1.
  local merged, top = false, 1
  local progressed = true
  while progressed do
    progressed = false
    for lvl = 1, MAX_LEVEL - 1 do
      while count[lvl] >= 3 do
        count[lvl] = count[lvl] - 3
        count[lvl + 1] = count[lvl + 1] + 1
        if (lvl + 1) > top then top = lvl + 1 end
        merged = true
        progressed = true
      end
    end
  end
  return merged and top or nil
end

-- LECTURE PURE : possède-t-on DÉJÀ au moins 1 exemplaire de `id` (plateau OU banc, niveau quelconque) ?
-- Sert à la brillance « déjà possédé » des cartes de boutique (indicateur passif). Zéro mutation.
function Build:ownsAnyCopy(id)
  if not id then return false end
  for i = 1, 9 do local sr = self.slotRigs[i]; if sr and sr.id == id then return true end end
  for i = 1, self:benchCapacity() do local sr = self.bench[i]; if sr and sr.id == id then return true end end
  return false
end

-- L'ANIM de level-up tourne-t-elle ? = un FX `levelup` OU `merge_fly` est encore vivant (âmes qui filent /
-- explosion en cours), OU le buffer post-anim (levelRelicCountdown) court encore. Source de vérité UNIQUE,
-- lue par le verrou d'input (COMBAT grisé) ET par le déclenchement différé de la pop-up de relique. RENDER pur.
function Build:levelUpActive()
  if self.levelRelicCountdown ~= nil then return true end
  for _, f in ipairs(self.fx) do
    if f.kind == "levelup" or f.kind == "merge_fly" then return true end
  end
  return false
end

-- Si une fusion en build a armé la récompense de level-up (checkMerges pose pendingLevelRelic), on DIFFÈRE
-- l'ouverture de l'offre 1-parmi-3 à la FIN de l'anim de fusion + un buffer (retour user : ne plus la cacher
-- en plein « TAAA »). On ARME juste le buffer ici ; updateFx ouvre la pop-up une fois l'anim finie. FALLBACK
-- HEADLESS : si le RENDER-loop n'a jamais tourné (tests pilotés sans update -> self.updating == false), il n'y
-- a PAS d'animation à attendre -> on ouvre TOUT DE SUITE (l'e2e Lot 5 asserte la route synchrone après l'achat).
-- Partagé par le drag-drop ET l'achat au clic. Le drapeau de run (relicFromLevelThisRound) reste inchangé.
function Build:flushLevelRelic()
  if not self.pendingLevelRelic then return end
  if self.updating then
    self.levelRelicCountdown = MERGE_RELIC_BUFFER -- diffère : updateFx ouvrira à la fin de l'anim (re-armé tant qu'un FX vit)
  else
    self:flushLevelRelicNow() -- headless / hors render-loop : aucune anim à attendre -> ouvre synchroniquement
  end
end

-- Ouvre RÉELLEMENT l'offre (consomme pendingLevelRelic + le buffer). Le host gère l'unicité 1/round.
function Build:flushLevelRelicNow()
  self.pendingLevelRelic = false
  self.levelRelicCountdown = nil
  if self.host.offerLevelUpRelic then self.host.offerLevelUpRelic() end
end

-- Une offre est JOUABLE (retour user 2026-06) si l'achat aboutit à QUELQUE CHOSE : assez d'or ET (une case
-- board/banc libre OU un trio à compléter -> level-up à l'achat). Sinon la carte est GRISÉE/désactivée et le
-- clic/pickup est inerte (rien à créer). Sert au rendu (dim) ET à la souris (pas de drag sur une offre morte).
function Build:offerPlayable(o)
  if not o or o.sold then return false end
  local run = self.host.run
  if not run then return true end -- sandbox (sans éco) : la boutique est inerte, on ne grise pas
  if run.gold < o.cost then return false end -- pas assez d'or
  for i = 1, 9 do if self.board.slots[i].unlocked and not self.slotRigs[i] then return true end end -- case libre
  for i = 1, self:benchCapacity() do if not self.bench[i] then return true end end                  -- slot banc libre
  -- PLEIN : jouable seulement si l'achat complète un trio (>=2 copies du même id au NIVEAU 1 -> fusion).
  local copies = 0
  for i = 1, 9 do local sr = self.slotRigs[i]; if sr and sr.id == o.id and (sr.level or 1) == 1 then copies = copies + 1 end end
  for i = 1, self:benchCapacity() do local sr = self.bench[i]; if sr and sr.id == o.id and (sr.level or 1) == 1 then copies = copies + 1 end end
  return copies >= 2
end

-- ACHAT AU CLIC (retour user 2026-06) : un clic sur une offre (ou un lâcher hors d'une case précise) ACHÈTE et
-- PLACE automatiquement -> 1re case board déverrouillée VIDE, sinon 1er slot de BANC vide ; checkMerges gère un
-- éventuel trio. Si TOUT est plein mais l'achat complète un trio -> fusion directe (buyMergeWhenFull). Sinon
-- refus (aucun or dépensé). Renvoie true si l'achat a eu lieu.
function Build:autoBuy(offerIndex, opts)
  opts = opts or {}
  local run = self.host.run
  if not run then return false end
  local o = run.shop[offerIndex]
  if not o or o.sold or run.gold < o.cost then return false end
  local bslot
  for i = 1, 9 do if self.board.slots[i].unlocked and not self.slotRigs[i] then bslot = i; break end end
  local benchSlot
  if not bslot then for i = 1, self:benchCapacity() do if not self.bench[i] then benchSlot = i; break end end end
  if bslot or benchSlot then
    local id = run:buy(offerIndex)
    if not id then return false end
    SFX.play("coin") -- ACHAT : pièce qui tombe (cloche grave Oniric)
    if bslot then
      self.slotRigs[bslot] = self:makeOcc(id, 1, opts); self.board.slots[bslot].unit = id
      self:popPlaced(self.slotRigs[bslot]) -- APPARITION : le monstre frémit sur sa case + son « place »
    else
      self.bench[benchSlot] = self:makeOcc(id, 1, opts)
      self:popPlaced(self.bench[benchSlot]) -- APPARITION (banc) : frémissement + « place »
    end
    self:checkMerges()
    self:flushLevelRelic()
    return true
  end
  return self:buyMergeWhenFull(offerIndex, opts)
end

-- Board ET banc PLEINS, mais l'achat complète un trio (>=2 copies du même id au NIVEAU 1) : la copie achetée
-- est le CATALYSEUR (jamais posée) -> on retire 1 copie existante et on promeut l'autre sur place (niveau 2),
-- puis checkMerges gère une cascade éventuelle. Arme aussi la récompense de level-up (1×/round). Renvoie true
-- si géré (sinon le caller ne dépense pas d'or : pas de trio -> refus).
function Build:buyMergeWhenFull(offerIndex, opts)
  opts = opts or {}
  local run = self.host.run
  local o = run.shop[offerIndex]
  local copies = {}
  for i = 1, 9 do local sr = self.slotRigs[i]; if sr and sr.id == o.id and (sr.level or 1) == 1 then copies[#copies + 1] = { kind = "board", i = i } end end
  for i = 1, self:benchCapacity() do local sr = self.bench[i]; if sr and sr.id == o.id and (sr.level or 1) == 1 then copies[#copies + 1] = { kind = "bench", i = i } end end
  if #copies < 2 then return false end
  local id = run:buy(offerIndex)
  if not id then return false end
  SFX.play("coin") -- ACHAT (catalyseur de fusion) : la pièce de l'achat (le « ta-ta-ta-TAAA » suit via spawnMergeFx)
  local keep, drop = copies[1], copies[2]
  local keepSr = (keep.kind == "board") and self.slotRigs[keep.i] or self.bench[keep.i]
  local dropSr = (drop.kind == "board") and self.slotRigs[drop.i] or self.bench[drop.i]
  local sx, sy = self:fxCenterOf(keep.kind, keep.i)        -- survivant
  local dxp, dyp = self:fxCenterOf(drop.kind, drop.i)      -- copie retirée (âme qui file)
  if drop.kind == "board" then self.slotRigs[drop.i] = nil; self.board.slots[drop.i].unit = nil else self.bench[drop.i] = nil end
  local mutationLists = {}
  if keepSr and keepSr.mutations then mutationLists[#mutationLists + 1] = keepSr.mutations end
  if dropSr and dropSr.mutations then mutationLists[#mutationLists + 1] = dropSr.mutations end
  if opts.mutations then mutationLists[#mutationLists + 1] = opts.mutations end
  local promoted = self:makeOcc(id, 2, {
    bounce = newMergeAnim(2),
    copyId = keepSr and keepSr.copyId or nil,
    mutations = Mutations.merge(mutationLists),
  })
  if keep.kind == "board" then self.slotRigs[keep.i] = promoted; self.board.slots[keep.i].unit = id
  else self.bench[keep.i] = promoted end
  self:emitMergeEvent({
    type = "merge", source = "buyMergeWhenFull", id = id,
    fromLevel = 1, toLevel = 2,
    keep = { kind = keep.kind, i = keep.i, id = id, level = 1, copyId = keepSr and keepSr.copyId or nil },
    consumed = {
      { kind = drop.kind, i = drop.i, id = id, level = 1, copyId = dropSr and dropSr.copyId or nil },
      { kind = "shop", id = id, level = 1, copyId = opts.copyId },
    },
    result = { kind = keep.kind, i = keep.i, id = id, level = 2, copyId = promoted.copyId },
  })
  -- 1 âme de la copie retirée + 1 « achetée » qui tombe d'en haut sur le survivant (le catalyseur, jamais posé).
  self:spawnMergeFx(sx, sy, { { dxp, dyp }, { sx, sy - 34 } }, 2)
  self:checkMerges()
  if not run.relicFromLevelThisRound then run.relicFromLevelThisRound = true; self.pendingLevelRelic = true end
  self:flushLevelRelic()
  return true
end

-- ── Entrées ──
function Build:keypressed(key)
  if self.locked then return end -- inspection figée : pas de reshape clavier
  if key == "s" and not Board.SIGILS_PAUSED then -- swap de sigil (EN PAUSE : on ne joue que le carré)
    self.shapeIdx = self.shapeIdx % #Shapes.order + 1
    self.board:setShape(Shapes.order[self.shapeIdx])
    self:computeLayout()
  end
end

-- ENTRÉE de scène (appelé par host.goto quand on (re)vient sur build) : repointe le curseur HORS écran pour
-- repartir au repos. Sinon, après un combat, self.mx/self.my gardent la position du clic COMBAT -> le bouton
-- reste « survolé » tant que la souris ne bouge pas (bug de hover collé, retour user 2026-06). Le 1er mousemoved
-- réel restaure la position. Pas de Feel.reset global (évite d'effacer la respiration des autres ids).
function Build:onEnter()
  self.mx, self.my = -1e4, -1e4
end

-- ── MODE VERROUILLÉ (inspection Proving Ground) ──────────────────────────────────────────────────────
-- Configure la scène build en INSPECTEUR FIGÉ d'une composition : pose les unités de la compo sur son sigil ;
-- tout le SURVOL (fiche + AURAS + EXPOSURE) reste actif, mais AUCUNE mutation (boutique/drag/vente/reshape/
-- grant). FIGHT lance le combat fourni (payload.fight) puis onFinish rend la main au playground. host.run est
-- nil (host wrapper) -> la scène est déjà en sandbox (ni bannière ni boutique ni orbe).
function Build:setupLocked(payload)
  self.locked = true
  self.lockedFight = payload.fight -- { left, right, seed, enemyKey, onFinish }
  local comp = payload.composition  -- compo brute { sigil, units = { {id, slot, level?} } }
  if comp then
    for k, name in ipairs(Shapes.order) do if name == comp.sigil then self.shapeIdx = k end end
    self.board:setShape(comp.sigil or "carre")
    self:computeLayout()
    self.board:unlock(9) -- toutes les cases ouvertes (lecture ; le placement libre n'est pas requis ici)
    for _, u in ipairs(comp.units or {}) do self:placeId(u.slot, u.id, u.level or 1) end
  end
end

function Build:mousemoved(vx, vy)
  self.mx, self.my = vx, vy
  -- RESSORT de drag : la cible suit la souris (la pièce GLISSE vers ce point, avec son décalage de grab).
  -- L'ancre de dessin = pieds au sol (my + 9, comme le repos board/banc) -> le sprite ne « monte » pas d'un cran.
  if self.drag and self.drag.d then Drag.move(self.drag.d, vx, vy + 9) end
end

function Build:wheelmoved(_, dy)
  if self.forceNetworkInspect or ctrlHeld() then return end
  local si = self:slotAt(self.mx, self.my)
  if not (si and self.slotRigs[si]) then return end
  self.influenceScroll = self.influenceScroll or {}
  self.influenceScroll[si] = math.max(0, (self.influenceScroll[si] or 0) - (dy or 0) * 36)
  return true
end

function Build:mousepressed(vx, vy, button)
  if button ~= 1 then return end
  self.mx, self.my = vx, vy
  if self.locked then
    -- INSPECTION FIGÉE : seul FIGHT agit (lance le combat fourni) ; aucune mutation (boutique/drag/reshape/grant).
    if inRect(vx, vy, self.button) and self.lockedFight then
      local f = self.lockedFight
      Feel.press("build.combat", function()
        self.host.goto("combat", { left = f.left, right = f.right, seed = f.seed, enemyKey = f.enemyKey or "exhibition", onFinish = f.onFinish })
      end, { delay = Feel.CTA_DELAY })
    end
    return
  end
  -- VERROU D'ANIM DE LEVEL-UP (retour user) : pendant la chorégraphie de fusion (« ta-ta-ta-TAAA » + buffer),
  -- on GÈLE toute interaction de mutation — surtout COMBAT (changement de scène destructif) — pour que l'user
  -- VOIE l'explosion entière sans la couper ni enchaîner une 2e fusion qui compliquerait le différé de la pop-up.
  -- Court (~1-1,5 s). Le bouton COMBAT est aussi grisé visuellement (drawOverlay : disabled). RENDER pur.
  if self:levelUpActive() then
    if inRect(vx, vy, self.button) then SFX.play("error") end
    return
  end
  local run = self.host.run
  -- rect REROLL fidèle à l'état du grant (ligne pleine / scindée) AVANT le hit-test (mousepressed peut être
  -- appelé sans update, ex. tests headless).
  self:syncEcoRects(run and run.pendingSlotGrant)
  -- Boutons de forme (barre sigil) — EN PAUSE (sigils désactivés : on ne joue que le carré).
  if not Board.SIGILS_PAUSED then
    local sk = self:shapeBtnAt(vx, vy)
    if sk then
      Feel.press("build.shape." .. sk)
      self.shapeIdx = sk; self.board:setShape(Shapes.order[sk]); self:computeLayout()
      SFX.play("pop")
      return
    end
  end
  -- COMBAT : ⭐ ACTION DIFFÉRÉE (Feel) -> les YEUX du CTA réagissent au clic (squash + flash) AVANT la bascule
  -- de scène (~160 ms), pour qu'on SENTE le clic. Le test e2e mûrit l'action via Build:update avant d'asserter.
  if inRect(vx, vy, self.button) then Feel.press("build.combat", function() self:startCombat() end, { delay = Feel.CTA_DELAY }); return end
  if run then
    -- Grant en attente : REFUSER prioritaire (son rect cohabite avec la moitié REROLL) ; sinon ACCEPTER
    -- (clic sur une case verrouillée). Puis REROLL.
    if run.pendingSlotGrant then
      if inRect(vx, vy, self.declineBtn) then
        Feel.press("build.decline")
        if run:declineSlotGrant() then SFX.play("coin") else SFX.play("error") end
        return
      end
      local lc = self:lockedCellAt(vx, vy)
      if lc then
        if run:acceptSlotGrant() then
          self.board:openCell(lc)
          self:unlockFx(lc) -- ACHAT/DÉBLOCAGE : petite explosion pixel + punch + son « unlock »
        else
          SFX.play("error")
        end
        return
      end
    end
    -- Compat legacy : l'ancien flux pouvait laisser une offre de piédestal en attente.
    -- En live, RunState ne crée plus cette offre ; le slot est visible dès le round 1.
    if run.pendingCommanderGrant then
      if self.declineBtn and inRect(vx, vy, self.declineBtn) then
        Feel.press("build.decline")
        if run:declineCommanderGrant() then SFX.play("coin") else SFX.play("error") end
        return
      end
      if self.commanderRect and inRect(vx, vy, self.commanderRect) then
        Feel.press("build.commander.accept")
        if run:acceptCommanderGrant() then SFX.play("unlock") else SFX.play("error") end
        return
      end
    end
    -- BUY XP : achète de l'XP de boutique si abordable (NE re-tire PAS la boutique : les nouvelles cotes
    -- s'appliquent au prochain reroll/round -> préserve l'arbitrage XP-vs-reroll-vs-unités).
    -- BUY XP / REROLL : feedback de press IMMÉDIAT (Feel.press sans action) + action TOUT DE SUITE (l'e2e
    -- headless asserte l'or débité juste après le clic -> on ne diffère PAS ces actions de boutique).
    if inRect(vx, vy, self.raiseBtn) then
      Feel.press("build.raise")
      if run:canBuyXp() and run:buyXp() then SFX.play("coin") else SFX.play("error") end
      return
    end -- LEVEL/XP : pièce (achat d'XP)
    if inRect(vx, vy, self.rerollBtn) then
      Feel.press("build.reroll")
      if run:reroll() then
        self:applyShopSupport("reroll")
        SFX.play("pop")
      else
        SFX.play("error")
      end
      return
    end -- REROLL : « pop » (les offres se re-tirent)
    local fi = self:shopFreezeAt(vx, vy)
    if fi then
      Feel.press("build.freeze." .. fi)
      if run:freezeOffer(fi) then SFX.play("pop") else SFX.play("error") end
      return
    end
    local oi = self:shopAt(vx, vy)
    if oi then -- prend une offre JOUABLE (achat consommé au lâcher sur une case, ou au CLIC via autoBuy) ; une
      local o = run.shop[oi] -- carte désactivée (pas d'or / plein sans level-up) est INERTE -> pas de pickup.
      if o and self:offerPlayable(o) then
        self.drag = self:makeOcc(o.id, 1, { char = self:newRig(o.id) })
        self.drag.fromShop, self.drag.pressX, self.drag.pressY = oi, vx, vy
        self:beginDrag(nil) -- offre neuve : pas de ressort source -> démarre sous le curseur (lift immédiat)
        SFX.play("pickup") -- DRAG : on saisit une offre (achat confirmé au lâcher -> coin)
      else
        SFX.play("error")
      end
      return
    end
  end
  -- C3 : ramasse le COMMANDANT du piédestal (le rétrograde -> il repartira vers board/banc ou sera vendu).
  if self:commanderAt(vx, vy) and self.commanderSlot then
    local c = self.commanderSlot
    self.drag = self:cloneOcc(c)
    self.drag.fromCommander = true
    self:beginDrag(c.d) -- reprend son ressort -> il se soulève du piédestal, pas de saut
    self.commanderSlot = nil
    SFX.play("pickup") -- DRAG : on retire le commandant du piédestal
    return
  end
  local si = self:slotAt(vx, vy)
  if si and self.slotRigs[si] then -- ramasse une unité du PLATEAU (réarrangement / vente / vers banc)
    self.drag = self:cloneOcc(self.slotRigs[si])
    self.drag.fromSlot = si
    self:beginDrag(self.slotRigs[si].d) -- reprend son ressort -> elle se soulève de sa case
    self.slotRigs[si] = nil
    self.board.slots[si].unit = nil
    SFX.play("pickup") -- DRAG : on soulève une unité du plateau
    return
  end
  local bi = self:benchAt(vx, vy)
  if bi and self.bench[bi] then -- ramasse une unité du BANC (réarrangement / vente / vers plateau)
    self.drag = self:cloneOcc(self.bench[bi])
    self.drag.fromBench = bi
    self:beginDrag(self.bench[bi].d) -- reprend son ressort -> elle se soulève du banc
    self.bench[bi] = nil
    SFX.play("pickup") -- DRAG : on soulève une unité du banc
  end
end

function Build:mousereleased(vx, vy, button)
  if button ~= 1 or not self.drag then return end
  local d = self.drag
  self.drag = nil
  if d.d then Drag.stop(d.d) end -- relâche le ressort : le sprite GLISSE désormais vers sa case finale (tilt -> plat)
  local run = self.host.run
  local si = self:slotAt(vx, vy)    -- case PLATEAU sous le curseur
  local bi = self:benchAt(vx, vy)   -- slot BANC sous le curseur
  local onPed = self:commanderAt(vx, vy) -- drop sur le PIÉDESTAL toujours disponible

  -- ── C3 — DROP SUR LA CASE DU COMMANDANT (promotion en commandant) ─────────────────────────────────
  -- Une seule unité au commandant ; seuls les porteurs de `commandBonus` y sont admis (refus propre sinon).
  if onPed then
    if not canCommand(d.id) then -- refus : l'unité non-chef RETOURNE à son origine (jamais de crash/perte).
      self.cmdShake = 0.32 -- C4 : SECOUSSE de refus (la case clignote sang) ; décroît dans update.
      Feel.press("build.commander.refuse") -- petit feedback de press (squash/flash) au point de refus
      SFX.play("error")
      self:returnDrag(d)
      return
    end
    -- Compat legacy : si une ancienne run a encore pendingCommanderGrant, le drop la consomme avant de placer.
    if run and run.pendingCommanderGrant and not run.commanderUnlocked then
      run:acceptCommanderGrant()
    end
    if d.fromShop then -- ACHAT puis promotion directe au piédestal (l'or n'est débité qu'ICI).
      local id = run and run:buy(d.fromShop)
      if id then
        SFX.play("coin") -- ACHAT (promotion directe au piédestal)
        local occ = self.commanderSlot
        self.commanderSlot = self:makeOcc(id, 1, { char = d.char, d = d.d, copyId = d.copyId, mutations = d.mutations }) -- ressort repris -> glisse au piédestal
        if occ then -- piédestal occupé : l'ancien commandant repart au banc (sinon disparaît en sandbox).
          self:stowUnit(occ)
        end
        self:popPlaced(self.commanderSlot) -- APPARITION au piédestal : frémissement + « place »
      else
        self:returnDrag(d) -- achat refusé (pas d'or) -> retour origine (rien pour fromShop, juste no-op propre)
      end
      return
    end
    -- Unité EXISTANTE (board/banc/piédestal) -> piédestal. L'occupant repart vers l'ORIGINE du drag (swap propre).
    local occ = self.commanderSlot
    if occ then self:returnDragOrigin(d, occ) end
    self.commanderSlot = self:cloneOcc(d, { d = d.d }) -- ressort repris -> glisse au piédestal
    return
  end

  if d.fromShop then
    -- ACHAT : sur une case plateau débloquée et VIDE, OU un slot de banc VIDE. L'or n'est débité qu'ICI
    -- (placement garanti). Le BANC découple l'achat du placement -> on peut STOCKER des copies pour fusionner.
    local toBoard = si and self.board.slots[si].unlocked and not self.slotRigs[si]
    local toBench = (not toBoard) and bi and not self.bench[bi]
    if toBoard or toBench then
      local id = run and run:buy(d.fromShop)
      if id then
        SFX.play("coin") -- ACHAT par drag sur une case/banc
        if toBoard then
          self.slotRigs[si] = self:makeOcc(id, 1, { char = d.char, d = d.d, copyId = d.copyId, mutations = d.mutations }); self.board.slots[si].unit = id -- ressort repris -> glisse dans la case
          self:popPlaced(self.slotRigs[si]) -- APPARITION sur la case (lâcher du drag) : frémissement + « place »
        else
          self.bench[bi] = self:makeOcc(id, 1, { char = d.char, d = d.d, copyId = d.copyId, mutations = d.mutations }) -- ressort repris -> glisse au banc
          self:popPlaced(self.bench[bi]) -- APPARITION au banc (lâcher du drag) : frémissement + « place »
        end
        self:checkMerges() -- 3 copies (même id+niveau, plateau OU banc) -> fusion niveau+1 (arme pendingLevelRelic 1×/round)
        self:flushLevelRelic() -- Lot 5 (§5.2) : une fusion arme l'offre 1-parmi-3 MID-ROUND (round préservé).
      end
    else
      -- CLIC sur l'offre (presse+relâche quasi au même point, PAS un drag) : ACHAT AUTO -> place tout seul, ou
      -- level-up auto si tout est plein (retour user 2026-06). Un DRAG raté (lâché loin, ex. case verrouillée/
      -- occupée) ne fait RIEN (comportement historique préservé -> le test « pas d'achat sur case verrouillée »).
      local moved = d.pressX and ((vx - d.pressX) * (vx - d.pressX) + (vy - d.pressY) * (vy - d.pressY)) or 1e9
      if moved <= 36 then
        if not self:autoBuy(d.fromShop) then SFX.play("error") end
      else
        SFX.play("error")
      end
    end
    return
  end

  -- Déplacement d'une unité EXISTANTE (plateau OU banc ; l'origine a été vidée au pickup).
  if si and self.board.slots[si].unlocked then
    -- -> CASE PLATEAU : place / swap (l'occupant repart vers l'ORIGINE du drag : plateau ou banc).
    local occ = self.slotRigs[si]
    if occ then self:returnDragOrigin(d, occ) end
    self.slotRigs[si] = self:cloneOcc(d, { d = d.d }) -- ressort repris -> glisse dans la case
    self.board.slots[si].unit = d.id
    SFX.play("drop") -- DROP : on POSE l'unité sur une case (doux, grave, aucun bruit)
  elseif bi then
    -- -> SLOT BANC : place / swap.
    local occ = self.bench[bi]
    if occ then self:returnDragOrigin(d, occ) end
    self.bench[bi] = self:cloneOcc(d, { d = d.d }) -- ressort repris -> glisse au banc
    SFX.play("drop") -- DROP : on range l'unité au banc
  else
    -- Lâché HORS plateau ET banc : VENTE (remboursement) si run ; sinon l'unité disparaît (sandbox).
    if run and (d.fromSlot or d.fromBench or d.fromCommander) then
      local before = run.gold
      run:sell(d.id)
      SFX.play("back") -- VENTE : reflux grave (l'unité quitte le plateau, l'or revient)
      self:spawnFx("sell", self.mx * 4, self.my * 4, { gold = run.gold - before })
    end
  end
end

-- Renvoie l'occupant déplacé (occ) vers l'ORIGINE du drag (case plateau / slot banc / PIÉDESTAL) -> swap propre
-- quel que soit le couple source/destination. Appelé pour des drags d'unités existantes (fromSlot/fromBench/
-- fromCommander) ; fromShop est géré plus haut (return).
function Build:returnDragOrigin(d, occ)
  if d.fromSlot then
    self.slotRigs[d.fromSlot] = occ
    self.board.slots[d.fromSlot].unit = occ.id
  elseif d.fromBench then
    self.bench[d.fromBench] = occ
  elseif d.fromCommander then
    self.commanderSlot = occ -- swap : l'occupant reprend le piédestal (occ porte forcément un commandBonus)
  end
end

-- Repose un drag à SON origine SANS swap (refus de drop : non-chef sur le piédestal). Reconstruit l'entrée.
function Build:returnDrag(d)
  local u = self:cloneOcc(d, { d = d.d }) -- ressort repris -> glisse de retour à l'origine
  if d.fromSlot then
    self.slotRigs[d.fromSlot] = u; self.board.slots[d.fromSlot].unit = d.id
  elseif d.fromBench then
    self.bench[d.fromBench] = u
  elseif d.fromCommander then
    self.commanderSlot = u
  end
  -- fromShop : rien à reposer (l'or n'a pas été débité), le drag est simplement abandonné.
end

-- Range une unité (occ) dans le 1er slot de banc libre, sinon la 1re case plateau débloquée vide ; sinon elle
-- disparaît (sandbox / tout plein). Sert quand un achat-promotion évince l'ancien commandant du piédestal.
function Build:stowUnit(occ)
  for i = 1, self:benchCapacity() do
    if not self.bench[i] then self.bench[i] = occ; return true end
  end
  for i = 1, 9 do
    if self.board.slots[i].unlocked and not self.slotRigs[i] then
      self.slotRigs[i] = occ; self.board.slots[i].unit = occ.id; return true
    end
  end
  return false
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

-- C4 — POSITION DE COMBAT DU COMMANDANT (RENDER pur : x/y cosmétiques, jamais lus par la SIM -> golden-safe).
-- Le commandant SUPERVISE depuis l'ARRIÈRE de SA formation : on se cale en VIRTUEL (espace u.x,u.y de l'arène,
-- canvas 320×180) sur la convention de src/combat/place.lua (centre 160,96 ; front d'équipe à FRONT_GAP du
-- centre ; les rangs reculent vers l'extérieur). On part du combattant le plus EN ARRIÈRE déjà placé dans `comp`
-- (x le plus loin du centre, du bon côté) et on recule de COMMANDER_BACK px + un léger lift vertical -> le chef
-- est nettement derrière la troupe, surélevé, sans chevaucher personne. Compo vide -> retrait depuis le front.
local CMD_CENTER_X, CMD_CENTER_Y = 160, 96 -- = place.lua CENTER_X/Y (le commandant partage l'espace virtuel)
local CMD_FRONT_GAP = 22                    -- = place.lua FRONT_GAP (front de chaque camp vs centre)
local COMMANDER_BACK = 26                   -- recul DERRIÈRE la dernière ligne de troupe (px virtuels)
local COMMANDER_LIFT = 16                   -- léger surélèvement (au-dessus du centre du champ) -> « il domine »
function Build:commanderCombatPos(side, comp)
  side = side or -1
  -- x du combattant le plus en ARRIÈRE de ce camp = le plus éloigné du centre dans le sens -side (côté de retraite).
  -- (side=-1 : équipe gauche, l'arrière est le x le plus PETIT ; side=+1 : équipe droite, le x le plus GRAND.)
  local rearX = nil
  for _, u in ipairs(comp or {}) do
    if u.x then
      if rearX == nil then rearX = u.x
      elseif side < 0 then rearX = math.min(rearX, u.x)
      else rearX = math.max(rearX, u.x) end
    end
  end
  -- repli : aucune troupe placée -> on recule depuis le front théorique de ce camp.
  rearX = rearX or (CMD_CENTER_X + side * CMD_FRONT_GAP)
  local x = rearX + side * COMMANDER_BACK          -- side*back : recule vers le bord (loin du centre)
  -- borne dans la moitié d'écran (jamais hors-canvas) : on garde une marge de 12px au bord.
  if side < 0 then x = math.max(12, x) else x = math.min(308, x) end
  local y = CMD_CENTER_Y + COMMANDER_LIFT          -- légèrement BAS du centre -> ses pieds posent au sol de fosse
  return math.floor(x + 0.5), math.floor(y + 0.5)
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
      placed[#placed + 1] = { slot = i, id = self.slotRigs[i].id, col = c.x, row = c.y,
        level = self.slotRigs[i].level or 1, mutations = Mutations.clone(self.slotRigs[i].mutations) }
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
  -- TROU #1 (rollout § command-auras) : `bleedInc`/`rotInc` n'avaient PAS de buffer ici (l'adjacence
  -- bleed/rot passe par grantBleed/rotGrowth, pas par un *Inc). Pour qu'un commandant « ampli d'école »
  -- (aura_stat bleedInc/rotInc team/role) puisse les poser, on ouvre leurs buffers — sommés comme burnInc/
  -- poisonInc et lus par la pose de DoT (arena.lua:130-131, ampDps, cappé DOT_CAP_MULT=3). nil = inerte.
  local bleedInc, rotInc = {}, {}
  -- W1 — RAINBOW : [slot] = { dmg=, hp= } (flat baké par aura_per_unique_type sur le PORTEUR). nil = inerte.
  local rainbowFlat = {}
  -- Nombre de TYPES DISTINCTS du board, calculé UNE fois (déterministe : set d'unicité, ipairs). Borné au cap.
  -- Lazy : seul un porteur de l'op le lit -> aucune unité golden ne le déclenche -> nombre jamais consommé -> golden inchangé.
  local function uniqueTypeCount()
    local seen, n = {}, 0
    for _, q in ipairs(placed) do
      local ty = Units[q.id].type
      if ty and not seen[ty] then seen[ty] = true; n = n + 1 end
    end
    return math.min(RAINBOW_TYPE_CAP, n)
  end
  for _, p in ipairs(placed) do
    for _, e in ipairs(UnitResolver.effectsFor(p.id, p.level)) do
      local sm = UnitResolver.legacyEffectLevelMult(e, p.level) -- authored level effects already carry final values
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

  -- ── W3 — MIMÉTISME (`repeat_ability`, plan §AXE 4) : un MIMIC copie les effets `on_hit` d'UN voisin DANS sa
  -- propre liste d'effets (re-joue au niveau du mimic en combat, via Effects.run sur le mimic). BUILD-RÉSOLU.
  -- mimicCopies[slot] = liste de descripteurs on_hit copiés (chacun `viaCopy=true`). nil = pas un mimic -> base.
  -- Lookup (col,row) -> slot pour résoudre "ahead" (l'allié droit DEVANT = même row, col+1 vers le front, car
  -- depth = b.maxC - col -> front = col MAX). Déterministe (construit en ipairs).
  local byColRow = {}
  for _, p in ipairs(placed) do byColRow[p.col .. ":" .. p.row] = p.slot end
  -- Collecte les descripteurs on_hit COPIABLES de l'unité `srcId` (PROFONDEUR 1 : on saute tout effet déjà
  -- `viaCopy` -> un effet copié ne se re-copie jamais ; et on ne copie QUE on_hit -> un repeat_ability/aura
  -- combat_start n'est JAMAIS copié = pas de repeat-of-repeat, pas de copie d'aura/summon). Copie PROFONDE des
  -- params (le mimic ne partage aucune table avec la source). `viaCopy` marque la copie (inerte pour un 2e mimic).
  local function copyableOnHit(srcId, srcLevel)
    local out = {}
    for _, e in ipairs(UnitResolver.effectsFor(srcId, srcLevel or 1)) do
      if e.trigger == "on_hit" and not e.viaCopy then
        local pa = {}
        for k, v in pairs(e.params or {}) do pa[k] = v end
        out[#out + 1] = { trigger = "on_hit", op = e.op, params = pa, condition = e.condition, viaCopy = true }
      end
    end
    return out
  end
  local mimicCopies = {}
  for _, p in ipairs(placed) do
    for _, e in ipairs(UnitResolver.effectsFor(p.id, p.level)) do
      if e.trigger == "combat_start" and e.op == "repeat_ability" then
        local who = (e.params and e.params.who) or "ahead"
        local srcSlot
        if who == "ahead" then
          srcSlot = byColRow[(p.col + 1) .. ":" .. p.row] -- l'allié DEVANT (vers le front), même rangée
        elseif who == "neighbors" then
          -- copie le PLUS FORT voisin du GRAPHE qui porte un on_hit (heuristique de force = dmg ; tie-break slot asc,
          -- déterministe). « le plus fort » = on copie le carry qu'on jouxte, pas un buff au hasard.
          local best, bestDmg
          for _, nb in ipairs(self.board:neighbors(p.slot)) do
            if self.slotRigs[nb] then
              local nid = self.slotRigs[nb].id
              local nlevel = self.slotRigs[nb].level or 1
              local hasHit = false
              for _, ne in ipairs(UnitResolver.effectsFor(nid, nlevel)) do if ne.trigger == "on_hit" and not ne.viaCopy then hasHit = true; break end end
              if hasHit then
                local d = Units[nid].dmg or 0
                if not best or d > bestDmg or (d == bestDmg and nb < best) then best, bestDmg = nb, d end
              end
            end
          end
          srcSlot = best
        end
        if srcSlot and srcSlot ~= p.slot and self.slotRigs[srcSlot] then
          local src = self.slotRigs[srcSlot]
          local copies = copyableOnHit(src.id, src.level or 1)
          if #copies > 0 then
            local dst = mimicCopies[p.slot]; if not dst then dst = {}; mimicCopies[p.slot] = dst end
            for _, c in ipairs(copies) do dst[#dst + 1] = c end -- PROFONDEUR 1 (REPEAT_DEPTH_MAX) : append direct, jamais récursif
          end
        end
      end
    end
  end

  -- Matérialise les effets d'un voisin SOUS aura (rot growth + grant_bleed seulement ; poison/burn passent
  -- par poisonInc/burnInc sur l'unité) + les copies de MIMÉTISME (W3). Sinon nil = base (golden-safe).
  local function auraEffects(id, slot)
    local mc = mimicCopies[slot]
    local level = (self.slotRigs[slot] and self.slotRigs[slot].level) or 1
    local needsLevelEffects = level > 1
    if not (rotGrowth[slot] or grantBleed[slot] or mc or needsLevelEffects) then return nil end
    local out = {}
    for _, e in ipairs(UnitResolver.effectsFor(id, level)) do
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
    if mc then -- W3 : les on_hit COPIÉS s'ajoutent en FIN -> Effects.run(mimic, "on_hit") les rejoue au niveau du mimic
      for _, c in ipairs(mc) do out[#out + 1] = c end
    end
    return out
  end

  -- BOUCLIERS PÉRIODIQUES (framework payoff §3) : casters (shield_caster) + renforts (aura_shield adjacente).
  -- Renforts = 5 axes : valeur (valueInc) / cadence (cdr) / réflexion (reflect) / largeur (radius) / surcharge.
  local casters = {} -- [slot] = { value, cd, reflect, overcharge, targetSlots }
  for _, p in ipairs(placed) do
    for _, e in ipairs(UnitResolver.effectsFor(p.id, p.level)) do
      local sm = UnitResolver.legacyEffectLevelMult(e, p.level)
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
      for _, e in ipairs(UnitResolver.effectsFor(p.id, p.level)) do
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

  -- ── K1 — `aura_stat` générique (foyer unique des auras agnostiques ET des commandants, spec §8.1/§6.2.1).
  -- Un handler qui BAKE {stat, target, value} en CHAMPS combat-time sur le voisin/rôle/sous-ensemble, comme
  -- shield_aura. Écritures ADDITIVES (`+=`), par-slot INDÉPENDANTES (itère `placed` en ipairs -> commutatif,
  -- déterministe). Rôles AGNOSTIQUES À LA FORME (lit board.shape) -> re-marchent si les sigils reviennent
  -- (testés sur le CARRÉ, seule forme vivante : centre=4 voisins, bords=3, coins=2). Gated : zéro `aura_stat`
  -- dans le roster -> aucun champ posé -> empreinte golden inchangée. ──
  -- Index slot -> entrée de `placed` (pour résoudre les rôles, le depth est cohérent avec `b.maxC - col`).
  local byCell = {}
  for _, p in ipairs(placed) do byCell[p.slot] = p end
  -- Tie-break IDENTIQUE à chooseTarget (arena.lua:201-202) : row asc PUIS slot asc. Sinon le commandant
  -- viserait une cible d'aura différente du ciblage de combat (non-déterminisme silencieux). Compare deux
  -- entrées de `placed` (la "meilleure" = la plus petite par (row, slot)).
  local function tieLess(a, c) -- a est-il AVANT c (row asc, slot asc) ?
    if a.row ~= c.row then return a.row < c.row end
    return a.slot < c.slot
  end
  -- role:front = min(depth) ; role:back = max(depth) ; même tie-break. depth = b.maxC - col (cohérent comp).
  local function resolveExtreme(wantMin)
    local best
    for _, p in ipairs(placed) do
      local d = b.maxC - p.col
      if not best then best = p
      else
        local bd = b.maxC - best.col
        if (wantMin and d < bd) or (not wantMin and d > bd)
          or (d == bd and tieLess(p, best)) then best = p end
      end
    end
    return best and best.slot or nil
  end
  -- role:center = nœud à 4 voisins du GRAPHE du sigil (board:degreeOf, PAS le depth) ; parmi les slots
  -- occupés, le degré le plus haut atteignant 4, tie-break slot asc ; fallback déterministe role:front
  -- (sigil ligne/anneau : aucun nœud à 4 voisins). cf. §6.2.1.
  local function resolveCenter()
    local best, bestDeg
    for _, p in ipairs(placed) do
      local deg = self.board:degreeOf(p.slot)
      if not bestDeg or deg > bestDeg or (deg == bestDeg and p.slot < best.slot) then
        best, bestDeg = p, deg
      end
    end
    if best and bestDeg and bestDeg >= 4 then return best.slot end
    return resolveExtreme(true) -- fallback front
  end
  local function resolveRole(role)
    if role == "role:front" then return resolveExtreme(true)
    elseif role == "role:back" then return resolveExtreme(false)
    elseif role == "role:center" then return resolveCenter()
    end
    return nil
  end
  -- Stats numériques additives bakées par aura_stat. focusWith = cas à part (ci-dessous). Les amplis d'école
  -- (poisonInc/burnInc/bleedInc/rotInc, TROU #1) sont dans la whitelist MAIS ne vont PAS dans statBuf : ils
  -- sont ROUTÉS vers leurs buffers dédiés (déjà lus par la pose de DoT), via addStat (mapping ci-dessous).
  local DOT_INC = { poisonInc = poisonInc, burnInc = burnInc, bleedInc = bleedInc, rotInc = rotInc }
  local STAT_FIELDS = { haste = true, atkInc = true, dmgReduce = true, regen = true,
    multicast = true, lifesteal = true, statInc = true,
    poisonInc = true, burnInc = true, bleedInc = true, rotInc = true } -- TROU #1 : amplis d'école accessibles en aura_stat
  local statBuf = {}    -- [slot] = { haste=…, atkInc=…, … } (sommes additives ; HORS amplis d'école)
  local focusWith = {}  -- [slot] = slot de l'allié dont on copie la cible (effet faible, tie-break)
  local function addStat(slot, stat, value)
    if not (slot and byCell[slot]) then return end -- cible vide -> aura inerte (jamais de crash)
    local dot = DOT_INC[stat]
    if dot then dot[slot] = (dot[slot] or 0) + value; return end -- ampli d'école -> buffer dédié (additif avec l'adjacence)
    local sb = statBuf[slot]; if not sb then sb = {}; statBuf[slot] = sb end
    sb[stat] = (sb[stat] or 0) + value
  end
  -- Résout les SLOTS-cibles du board selon `target` (neighbors/team/role:*/tier:N/level:N/type:X + directions).
  -- `srcSlot` = la
  -- source (pour neighbors) ; un commandant HORS graphe passe srcSlot=nil -> neighbors vide (pas de voisins).
  local function resolveTargets(target, srcSlot)
    local targets = {}
    if target == "neighbors" then
      if srcSlot then
        for _, nb in ipairs(self.board:neighbors(srcSlot)) do if byCell[nb] then targets[#targets + 1] = nb end end
      end
    elseif target == "ahead" or target == "behind" or target == "above" or target == "below" then
      -- W5 (polarité directionnelle) : cible RELATIVE au porteur, pas au graphe. ahead/behind utilisent
      -- l'axe X (exposition), above/below l'axe Y (rangée). Slot absent -> effet nul, jamais de crash.
      local src = srcSlot and byCell[srcSlot]
      if src then
        local dc = (target == "ahead" and 1) or (target == "behind" and -1) or 0
        local dr = (target == "below" and 1) or (target == "above" and -1) or 0
        local slot = byColRow[(src.col + dc) .. ":" .. (src.row + dr)]
        if slot and byCell[slot] then targets[1] = slot end
      end
    elseif target == "team" then
      for _, q in ipairs(placed) do targets[#targets + 1] = q.slot end
    elseif target:sub(1, 5) == "role:" then
      local r = resolveRole(target); if r then targets[1] = r end
    elseif target:sub(1, 5) == "tier:" then
      local n = tonumber(target:sub(6))
      for _, q in ipairs(placed) do if (Units[q.id].rank or 0) == n then targets[#targets + 1] = q.slot end end
    elseif target:sub(1, 6) == "level:" then
      local n = tonumber(target:sub(7))
      for _, q in ipairs(placed) do if (q.level or 1) == n then targets[#targets + 1] = q.slot end end
    elseif target:sub(1, 5) == "type:" then
      -- W1 (axe Type-identité, plan §AXE 2) : cible les alliés du board dont le `type` data == X (mono-type).
      -- ≈ branche tier:N (itère `placed`, compare un champ data de Units). Déterministe (ipairs), zéro RNG.
      -- INERTE tant qu'aucun spec ne cible `type:` -> golden inchangé (les 83 types sont cosmétiques jusqu'ici).
      local ty = target:sub(6)
      for _, q in ipairs(placed) do if Units[q.id].type == ty then targets[#targets + 1] = q.slot end end
    end
    return targets
  end
  -- Bake d'un descripteur aura_stat `e` (porté par une unité du board OU le commandant) dans statBuf/focusWith.
  -- `target` peut être sur l'EFFET (data réelle units.lua : `e.target`) OU dans les params (auras synthétiques
  -- des tests : `e.params.target`) ; défaut "neighbors". Cette double-lecture conserve EXACTEMENT l'ancien
  -- comportement (les auras du roster sont toutes `neighbors`) tout en gérant les portées du commandant.
  local function bakeAuraStat(e, sm, srcSlot)
    local pa = e.params or {}
    local stat, target, value = pa.stat, e.target or pa.target or "neighbors", (pa.value or 0)
    -- multicast = entier (PAS scalé par le niveau : changer une bascule scalée serait un double-snowball).
    local scaled = (stat == "multicast") and value or (value * sm)
    local targets = resolveTargets(target, srcSlot)
    if stat == "focusWith" then
      for _, t in ipairs(targets) do if byCell[t] then focusWith[t] = srcSlot end end
    elseif stat and STAT_FIELDS[stat] then
      for _, t in ipairs(targets) do addStat(t, stat, scaled) end
    end
  end
  for _, p in ipairs(placed) do
    for _, e in ipairs(UnitResolver.effectsFor(p.id, p.level)) do
      local sm = UnitResolver.legacyEffectLevelMult(e, p.level) -- authored level effects already carry final values
      if e.trigger == "combat_start" and e.op == "aura_stat" then
        bakeAuraStat(e, sm, p.slot)
      elseif e.trigger == "combat_start" and e.op == "aura_per_unique_type" then
        -- W1 — RAINBOW : le porteur se renforce de +flat par type distinct du board (SELF-aura, Prismagon).
        -- dmg/hp scalent avec le NIVEAU (sm, duplicatas) comme les stats. count borné (uniqueTypeCount).
        local pa = e.params or {}
        local count = uniqueTypeCount()
        local rf = rainbowFlat[p.slot]; if not rf then rf = { dmg = 0, hp = 0 }; rainbowFlat[p.slot] = rf end
        rf.dmg = rf.dmg + math.floor((pa.dmgPerType or 0) * count * sm + 0.5)
        rf.hp  = rf.hp  + math.floor((pa.hpPerType  or 0) * count * sm + 0.5)
      end
    end
  end

  -- ── C3 — AURA DU COMMANDANT (piédestal) : son `commandBonus` (aura_stat) est BUILD-RÉSOLU sur les cibles du
  -- BOARD (jamais sur lui-même : il n'est pas dans `placed`/`byCell`). neighbors -> vide (hors graphe). Le
  -- `grant_team` (Bris-Siège) n'est PAS baké ici : il reste dans les effects du commandant -> exécuté par
  -- l'arène à combat_start (firewall intact). L'aura est ajoutée AVANT le bake du comp -> statInc absorbé. ──
  local cmd = self.commanderSlot
  if cmd and self:commanderUnlocked() then
    local cb = UnitResolver.commandBonusFor(cmd.id, cmd.level or 1)
    if cb and cb.op == "aura_stat" then
      local sm = UnitResolver.legacyEffectLevelMult(cb, cmd.level or 1)
      bakeAuraStat(cb, sm, nil) -- srcSlot=nil : pas de voisins, jamais self-ciblé (hors board)
    end
  end

  -- ── W3 — MÉTA-MULTIPLICATEUR (`amplify_auras`, plan §AXE 4) : le « Zenith-Stone » incarné en unité
  -- (hollow_crown). APRÈS que TOUTES les auras du board (unités + rainbow + amplis d'école + commandant) sont
  -- bakées, le porteur MULTIPLIE par (1+frac) les SORTIES d'aura déjà posées sur l'équipe. CAPS PRÉSERVÉS : on
  -- amplifie la valeur BRUTE bakée ; le clamp final reste à la LECTURE en combat (ATK_INC_CAP 1.5 / HASTE 0.40 /
  -- DMG_REDUCE 0.60 / DOT_CAP_MULT ×4 ...) -> un Zénith « +20% d'aura » ne franchit JAMAIS un cap. On amplifie les
  -- stats CONTINUES (atkInc/haste/dmgReduce/regen/lifesteal) + les amplis d'école (poisonInc/...) + rainbowFlat +
  -- shield. On N'amplifie PAS `multicast` (bascule ENTIÈRE : amplifier un seuil = double-snowball interdit, cf.
  -- bakeAuraStat). frac CUMULÉ (plusieurs Zénith s'additionnent) puis BORNÉ (AMPLIFY_FRAC_CAP) -> magnitude lisible.
  -- Build-résolu, déterministe (ipairs), zéro RNG. Gated : aucune unité golden ne porte amplify_auras.
  local AMPLIFY_FRAC_CAP = 0.50 -- borne dure du gain d'aura cumulé (anti-empilage de méta-multiplicateurs)
  local AMP_STATS = { atkInc = true, haste = true, dmgReduce = true, regen = true, lifesteal = true }
  local ampFrac = 0
  for _, p in ipairs(placed) do
    for _, e in ipairs(UnitResolver.effectsFor(p.id, p.level)) do
      if e.trigger == "combat_start" and e.op == "amplify_auras" then
        ampFrac = ampFrac + ((e.params and e.params.frac) or 0)
      end
    end
  end
  if ampFrac > 0 then
    local f = 1 + math.min(AMPLIFY_FRAC_CAP, ampFrac)
    for _, sb in pairs(statBuf) do
      for stat in pairs(AMP_STATS) do if sb[stat] then sb[stat] = sb[stat] * f end end
    end
    for _, buf in ipairs({ poisonInc, burnInc, bleedInc, rotInc }) do
      for slot, v in pairs(buf) do buf[slot] = v * f end
    end
    for slot, v in pairs(shield) do shield[slot] = math.floor(v * f + 0.5) end
    for _, rf in pairs(rainbowFlat) do
      rf.dmg = math.floor(rf.dmg * f + 0.5); rf.hp = math.floor(rf.hp * f + 0.5)
    end
  end

  local comp = {}
  for _, p in ipairs(placed) do
    local x, y = Place.pos(p.col, p.row, side, b)
    -- depth (0 = front) + row dérivés de la forme -> exposition portée par le sigil (ciblage déterministe).
    local stats = UnitResolver.statsFor(p.id, p.level) -- duplicatas : les stats scalent avec le niveau
    local sb = statBuf[p.slot] -- champs combat-time bakés par K1 (nil = inerte, golden-safe)
    -- COMMANDANT (C0) : `statInc` (aura `aura_stat`) est CONSOMMÉ ICI, pas transmis inerte à l'arène. C'est un
    -- `increased` additif sur la base (même couche qu'atkInc), cappé STAT_INC_CAP. Il touche hp ET dmg (les
    -- stats « globales » au sens du commandant). nil/0 -> hp/dmg inchangés -> golden-safe. Baké au build comme
    -- les duplicatas (déterministe, zéro couplage arène : le firewall SIM reste intact). cf. plan §1.3.
    local si = (sb and sb.statInc) or 0
    local sf = (si > 0) and (1 + math.min(STAT_INC_CAP, si)) or 1
    -- W1 — RAINBOW : bonus PLAT (déjà borné par le count cappé + déjà scalé par le niveau au bake), ajouté
    -- APRÈS la couche multiplicative (comme un relic_flat_hp). nil = inerte -> hp/dmg base -> golden-safe.
    local rf = rainbowFlat[p.slot]
    local spec = { id = p.id, slot = p.slot, level = p.level,
      hp = math.floor(stats.hp * sf + 0.5) + (rf and rf.hp or 0),
      dmg = math.floor(stats.dmg * sf + 0.5) + (rf and rf.dmg or 0), cd = stats.cd,
      depth = b.maxC - p.col, col = p.col, row = p.row, effects = auraEffects(p.id, p.slot),
      shield = shield[p.slot] or 0, poisonInc = poisonInc[p.slot], burnInc = burnInc[p.slot],
      bleedInc = bleedInc[p.slot], rotInc = rotInc[p.slot], -- TROU #1 : amplis bleed/rot (aura_stat team/role), lus par la pose de DoT

      -- K1 : auras agnostiques bakées (haste/atkInc/dmgReduce/regen/multicast/lifesteal) + focusWith.
      -- `statInc` n'est PLUS transmis (absorbé dans hp/dmg ci-dessus) : il ne sert plus rien en combat.
      haste = sb and sb.haste, atkInc = sb and sb.atkInc, dmgReduce = sb and sb.dmgReduce,
      regenAura = sb and sb.regen, multicast = sb and sb.multicast,
      lifestealAura = sb and sb.lifesteal,
      focusWith = focusWith[p.slot],
      shieldCaster = casters[p.slot] and { value = casters[p.slot].value, cd = casters[p.slot].cd,
        reflect = casters[p.slot].reflect, overcharge = casters[p.slot].overcharge,
        targetSlots = casters[p.slot].targetSlots } or nil,
      x = x, y = y, facing = facing }
    comp[#comp + 1] = Mutations.applyToSpec(spec, p.mutations)
  end

  -- ── C3 — LE COMMANDANT au comp (K4) : ajouté APRÈS le board, AVEC ses flags d'intouchabilité. L'arène le
  -- traite comme un spec `isCommander` ordinaire (chooseTarget l'exclut, damage()=0, décompte filtré, cdMult).
  -- Voie A : il GARDE ses effects de board (kit complet) et attaque, mais LENTEMENT (cdMult). Son aura est déjà
  -- build-résolue sur le board (ci-dessus) -> son `commandBonus aura_stat` n'est PAS dans ses effects (évite la
  -- double-pose). Si le commandBonus est un `grant_team` (Bris-Siège), on l'AJOUTE aux effects -> l'arène pose le
  -- drapeau d'équipe à combat_start. Position de rendu HORS grille (depth/row cosmétiques). ──
  if cmd and self:commanderUnlocked() then
    local cb = UnitResolver.commandBonusFor(cmd.id, cmd.level or 1)
    local stats = UnitResolver.statsFor(cmd.id, cmd.level or 1)
    -- effects du commandant = ses effects de BOARD (copie) + le grant_team éventuel (jamais l'aura_stat, déjà bakée).
    local cEff = {}
    for _, e in ipairs(UnitResolver.effectsFor(cmd.id, cmd.level or 1)) do cEff[#cEff + 1] = e end
    if cb and cb.op == "grant_team" then cEff[#cEff + 1] = cb end
    -- depth volontairement HORS de la grille ennemie : le commandant n'a pas de colonne (il est intouchable).
    -- POSITION DE RENDU (cosmétique : la SIM cible via depth/row, jamais x/y -> golden-safe) : le commandant
    -- SUPERVISE sa formation depuis l'ARRIÈRE, en VIRTUEL (u.x,u.y), du côté JOUEUR. On le pose en retrait de la
    -- dernière ligne de troupe (le combattant le plus en arrière de SON camp = x le plus loin du centre) +
    -- COMMANDER_BACK px supplémentaires, et légèrement SURÉLEVÉ (au-dessus du centre du champ) -> il se lit
    -- « le chef qui regarde de loin », distinct des combattants, jamais sur eux. (Ancien bug : commanderRect.x*4
    -- = coord DESIGN passée comme VIRTUEL -> ré-×4 par arena_draw -> hors écran.)
    local cmdX, cmdY = self:commanderCombatPos(side, comp)
    local cmdSpec = { id = cmd.id, slot = nil, level = cmd.level or 1,
      hp = stats.hp, dmg = stats.dmg, cd = stats.cd,
      depth = -1, row = 0, effects = #cEff > 0 and cEff or nil,
      isCommander = true, untargetable = true, cdMult = COMMANDER_CD_MULT,
      x = cmdX, y = cmdY,
      facing = facing }
    comp[#comp + 1] = Mutations.applyToSpec(cmdSpec, cmd.mutations)
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
    local lvl = math.min(MAX_LEVEL, (e.level or 1) + levelBump)
    local stats = UnitResolver.statsFor(e.id, lvl)
    local x, y = Place.pos(e.col, e.row, 1, b)
    local effects = (lvl > 1) and UnitResolver.effectsFor(e.id, lvl) or nil
    comp[#comp + 1] = { id = e.id, level = lvl,
      hp = stats.hp, dmg = stats.dmg, cd = stats.cd,
      depth = b.maxC - e.col, row = e.row,
      shield = 0, effects = effects, x = x, y = y, facing = -1 }
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
      out[#out + 1] = { id = sr.id, level = sr.level or 1, col = c.x, row = c.y,
        mutations = Mutations.clone(sr.mutations) }
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
  P.clear() -- on quitte vers le combat : purge les particules de fusion encore vivantes (singleton partagé inter-scènes)
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
  self.updating = true -- le RENDER-loop tourne (vrai jeu) -> flushLevelRelic peut DIFFÉRER l'offre via le buffer/anim
                       -- (en headless, update n'est jamais appelé -> updating reste false -> fallback synchrone).
  -- synchronise le rect REROLL (ligne pleine sans grant / scindée avec) AVANT le survol/hit-test.
  self:syncEcoRects(self.host.run and self.host.run.pendingSlotGrant)
  -- JUICE (remplace Forge.uiTick) : avance easings + fire les actions différées (le COMBAT diffère de ~120 ms
  -- pour qu'on VOIE les yeux du CTA réagir avant la bascule de scène). Survol des 4 boutons -> glow/lift animés.
  Feel.update(frameDt)
  local run0 = self.host.run
  -- COMBAT : pas de survol (yeux/glow) quand il est VERROUILLÉ par l'anim de level-up -> bouton vraiment inerte.
  Feel.hover("build.combat", inRect(self.mx, self.my, self.button) and not self:levelUpActive())
  if run0 then
    Feel.hover("build.reroll", inRect(self.mx, self.my, self.rerollBtn))
    Feel.hover("build.raise", inRect(self.mx, self.my, self.raiseBtn))
    Feel.hover("build.decline", (run0.pendingSlotGrant and inRect(self.mx, self.my, self.declineBtn)) or false)
  end
  -- NUMBER-ROLL de l'OR (game feel, comme le score punché de la démo) : la valeur AFFICHÉE roule vers run.gold
  -- au lieu de sauter. À chaque CHANGEMENT de cible (achat/vente/reroll/budget de round), un petit PUNCH de scale
  -- (Juice "build.gold") + on relance le roulement. RENDER pur : on ne lit que run.gold (jamais écrit) ; le SON
  -- « coin » est déjà câblé ailleurs -> ici on apporte le MOUVEMENT apparié. frameDt en frames@60 -> /60 = s.
  if self.nightmareBg then self.nightmareBg:update(frameDt / 60) end
  if run0 then
    local target = run0.gold or 0
    if self.goldShown == nil then
      self.goldShown, self._goldTarget = target, target -- 1re frame : snap (pas de roulement au montage)
    else
      if target ~= self._goldTarget then
        self._goldTarget = target
        Juice.juice_up("build.gold", 0.18) -- PUNCH au moindre changement d'or (gain OU dépense)
      end
      -- lissage framerate-correct vers la cible (tau ~0,12 s -> roule vite mais visiblement) ; snap fin pour
      -- finir pile sur l'entier (sinon le rendu arrondi « colle » à ±1 indéfiniment).
      local k = 1 - math.exp(-(frameDt / 60) / 0.12)
      self.goldShown = self.goldShown + (target - self.goldShown) * k
      if math.abs(target - self.goldShown) < 0.5 then self.goldShown = target end
    end
  end
  self.ambient:update(frameDt)
  -- C4 — CADENCE LENTE du commandant : la phase 0..1 boucle au rythme cd × cdMult de l'unité au piédestal,
  -- VISIBLEMENT plus lente que les troupiers (cdMult 1.5 + cd long). Cosmétique (dt mural), pas la SIM.
  if self.commanderSlot then
    local cu = Units[self.commanderSlot.id]
    local cd = ((cu and cu.cd) or 90) * COMMANDER_CD_MULT -- frames @60 ; ×cdMult -> « il dirige, lentement »
    self.cmdCadence = (self.cmdCadence + frameDt / math.max(1, cd)) % 1
  else
    self.cmdCadence = 0
  end
  if self.cmdShake > 0 then self.cmdShake = math.max(0, self.cmdShake - frameDt / 60) end -- décroît la secousse de refus
  if self.host.run and self.board.activeCount ~= self.host.run.slots then self:syncSlots() end
  self:updateSprings(frameDt / 60) -- RESSORT de drag : pièces au repos GLISSENT vers leur case ; la traînée suit la souris
  for i, sr in pairs(self.slotRigs) do
    local p = self.pos[i]
    sr.char.x, sr.char.y = p.x, p.y + 9
    Rig.update(sr.char, self.t, frameDt)
    if sr.bounce then sr.bounce.t = sr.bounce.t + frameDt / 60; if sr.bounce.t > sr.bounce.dur then sr.bounce = nil end end
    if sr.pop then sr.pop.t = sr.pop.t + frameDt / 60; if sr.pop.t > sr.pop.dur then sr.pop = nil end end -- POSE : vibration d'apparition
  end
  for i = 1, self:benchCapacity() do -- anime les rigs du BANC (réserve)
    local sr = self.bench[i]
    if sr then
      Rig.update(sr.char, self.t, frameDt)
      if sr.bounce then sr.bounce.t = sr.bounce.t + frameDt / 60; if sr.bounce.t > sr.bounce.dur then sr.bounce = nil end end
      if sr.pop then sr.pop.t = sr.pop.t + frameDt / 60; if sr.pop.t > sr.pop.dur then sr.pop = nil end end -- POSE : vibration d'apparition
    end
  end
  -- COMMANDANT (piédestal) : avance aussi sa vibration de pose si présente (apparition au piédestal).
  if self.commanderSlot and self.commanderSlot.pop then
    local cp = self.commanderSlot.pop
    cp.t = cp.t + frameDt / 60; if cp.t > cp.dur then self.commanderSlot.pop = nil end
  end
  for _, c in pairs(self.previewRigs) do Rig.update(c, self.t, frameDt) end
  self:updateFx(frameDt)
  if self.drag then
    -- POSITION du sprite traîné = le RESSORT (drag.d.px/py), pas un snap dur sous le curseur (updateSprings l'a
    -- ciblé sur la souris + intégré ce frame) ; on RÉPERCUTE sur char.x/y pour le fallback rig (Rig.draw lit char).
    local d = self.drag.d
    if d then self.drag.char.x, self.drag.char.y = d.px or self.mx, d.py or (self.my + 9)
    else self.drag.char.x, self.drag.char.y = self.mx, self.my + 9 end
    Rig.update(self.drag.char, self.t, frameDt)
  end
end

-- dps de BASE d'une affliction (poison/burn/…) chez une unité = somme des dps de ses effets qui la posent.
-- Sert à afficher le bonus CONCRET (valeur plate) d'une aura amplificatrice sur un voisin donné, au lieu d'un
-- pourcentage abstrait (le moteur applique bien un multiplicateur `increased`, mais le JOUEUR lit une valeur
-- réelle, cohérente avec le texte des cartes « +N dmg/s », retour user 2026-06).
local function baseAfflDps(id, kind, level)
  local sum = 0
  for _, e in ipairs(UnitResolver.effectsFor(id, level or 1)) do
    if e.op == kind then sum = sum + ((e.params and (e.params.dps or e.params.base)) or 0) end
  end
  return sum
end

local function auraPercent(value, signed)
  local n = math.floor((value or 0) * 100 + 0.5)
  return (signed and n >= 0 and "+" or "") .. tostring(n) .. "%"
end

local function auraAdd(value)
  local n = math.floor((value or 0) + 0.5)
  return (n >= 0 and "+" or "") .. tostring(n)
end

local function auraKindColor(kind)
  local c = Theme.c
  if kind == "shield" or kind == "guard" or kind == "armor" then return c.armor or c.steel or c.ink3 end
  if kind == "multicast" then return c.echo or c.bloodL end
  if kind == "mimicry" then return Theme.type("arcane").color end
  if kind == "heal" or kind == "lifesteal" then return c.heal or c.regen or c.gold end
  if kind == "growth" or kind == "stat" then return c.gold end
  return c[kind] or c.gold
end

function Build:auraColor(kind)
  return auraKindColor(kind)
end

function Build:auraPoint(ref)
  if ref == "commander" and self.commanderRect then
    local r = self.commanderRect
    return { x = r.x + r.w / 2, y = r.y + r.h / 2 }
  end
  return type(ref) == "number" and self.pos[ref] or nil
end

local function auraUpperAscii(s)
  return tostring(s or ""):gsub("[a-z]", string.upper)
end

function Build:auraSourceName(lk)
  if lk.sourceKind == "commander" or lk.from == "commander" then
    local cmd = self.commanderSlot
    return cmd and auraUpperAscii(T("unit." .. cmd.id .. ".name")) or T("ui.command_word")
  elseif lk.sourceKind == "relic" then
    return lk.sourceId and auraUpperAscii(T("relic." .. lk.sourceId .. ".name")) or T("ui.relics")
  elseif type(lk.from) == "number" and self.slotRigs[lk.from] then
    return auraUpperAscii(T("unit." .. self.slotRigs[lk.from].id .. ".name"))
  end
  return "?"
end

function Build:auraTargetName(slot)
  local sr = self.slotRigs[slot]
  return sr and auraUpperAscii(T("unit." .. sr.id .. ".name")) or "?"
end

local function statAuraVisual(stat, value, targetId, targetLevel)
  local v = value or 0
  if stat == "dmgReduce" then return "armor", "-" .. math.floor(v * 100 + 0.5) .. "%"
  elseif stat == "atkInc" then return "empower", auraPercent(v, true)
  elseif stat == "haste" then return "haste", auraPercent(v, true)
  elseif stat == "multicast" then return "multicast", "x" .. (1 + math.floor(v))
  elseif stat == "regen" then return "regen", auraAdd(v)
  elseif stat == "lifesteal" then return "heal", auraPercent(v, false)
  elseif stat == "statInc" then return "growth", auraPercent(v, true)
  elseif stat == "focusWith" then return "empower", "FOCUS"
  elseif stat == "poisonInc" or stat == "burnInc" or stat == "bleedInc" or stat == "rotInc" then
    local kind = stat:gsub("Inc$", "")
    local add = targetId and math.floor(baseAfflDps(targetId, kind, targetLevel or 1) * v + 0.5) or 0
    if add > 0 then return kind, "+" .. add end
    return nil, nil
  end
  return nil, nil
end

local function auraValueText(kind, label)
  return InfluencePanel.formatValue(kind, label)
end

local function grantTeamVisual(params)
  params = params or {}
  if params.burnNoDecay then return "burn", "∞" end
  if params.bleedNoExpire then return "bleed", "∞" end
  if params.poisonNoCap then return "poison", "CAP" end
  if params.shockChain then return "shock", "+" .. tostring(params.shockChain) end
  if params.plagueAmp then return "empower", auraPercent(params.plagueAmp, true) end
  if params.markEnemiesVuln then return "empower", auraPercent(params.markEnemiesVuln, true) end
  if params.stripEnemyShield then return "guard", "-" .. math.floor(params.stripEnemyShield * 100 + 0.5) .. "%" end
  if params.rotEnemies then return "rot", "+" .. tostring(params.rotEnemies.base or 1) end
  if params.slowEnemies then return "haste", "-" .. math.floor(params.slowEnemies * 100 + 0.5) .. "%" end
  if params.pierceHeal then return "heal", "-" .. math.floor(params.pierceHeal * 100 + 0.5) .. "%" end
  if params.invulnT then return "guard", "START" end
  if params.teamExecute then return "empower", "EXEC" end
  return "empower", "TEAM"
end

-- ── LIENS D'AURA pour l'AFFICHAGE (refonte « Build Screen » : « les interactions visibles en temps réel ») ──
-- Collecte tous les bonus directs lisibles en build : auras de créatures, commandant et effets team type
-- grant_team. Les reliques sont ajoutées dans l'inspecteur de hover pour éviter un réseau permanent illisible.
function Build:resolveAuraLinks()
  local links = {}
  local byCell, byColRow = {}, {}
  for i = 1, 9 do
    local sr = self.slotRigs[i]
    if sr and self.board.slots[i].unlocked then
      local cell = self.board.shape.cells[i]
      byCell[i] = { slot = i, id = sr.id, level = sr.level or 1, col = cell.x, row = cell.y }
      byColRow[cell.x .. ":" .. cell.y] = i
    end
  end

  local function addTarget(out, slot, seen)
    if slot and byCell[slot] and not seen[slot] then seen[slot] = true; out[#out + 1] = slot end
  end
  local function resolveTargets(target, srcSlot)
    target = target or "neighbors"
    local out, seen = {}, {}
    if target == "neighbors" then
      if srcSlot then
        for _, nb in ipairs(self.board:neighbors(srcSlot)) do addTarget(out, nb, seen) end
      end
    elseif target == "ahead" or target == "behind" or target == "above" or target == "below" then
      local src = srcSlot and byCell[srcSlot]
      if src then
        local dc = (target == "ahead" and 1) or (target == "behind" and -1) or 0
        local dr = (target == "below" and 1) or (target == "above" and -1) or 0
        addTarget(out, byColRow[(src.col + dc) .. ":" .. (src.row + dr)], seen)
      end
    elseif target == "team" then
      for i = 1, 9 do addTarget(out, i, seen) end
    elseif type(target) == "string" and target:sub(1, 5) == "role:" then
      addTarget(out, self:resolveRoleSlot(target:sub(6)), seen)
    elseif type(target) == "string" and target:sub(1, 5) == "tier:" then
      local n = tonumber(target:sub(6))
      for i, q in pairs(byCell) do if (Units[q.id].rank or 0) == n then addTarget(out, i, seen) end end
    elseif type(target) == "string" and target:sub(1, 6) == "level:" then
      local n = tonumber(target:sub(7))
      for i, q in pairs(byCell) do if (q.level or 1) == n then addTarget(out, i, seen) end end
    elseif type(target) == "string" and target:sub(1, 5) == "type:" then
      local ty = target:sub(6)
      for i, q in pairs(byCell) do if Units[q.id] and Units[q.id].type == ty then addTarget(out, i, seen) end end
    end
    table.sort(out)
    return out
  end

  local function addLink(from, to, kind, label, sourceKind, sourceId)
    if to and kind and label then
      links[#links + 1] = { from = from, to = to, kind = kind, label = label,
        valueText = auraValueText(kind, label), sourceKind = sourceKind or "unit", sourceId = sourceId }
    end
  end

  local function addEffectLinks(e, from, id, level, sourceKind)
    if not e or e.trigger ~= "combat_start" then return end
    local pa = e.params or {}
    local sm = UnitResolver.legacyEffectLevelMult(e, level or 1)
    local target = e.target or pa.target or "neighbors"
    if e.op == "shield_aura" then
      for _, to in ipairs(resolveTargets(target, from)) do
        addLink(from, to, "shield", auraAdd((pa.value or 0) * sm), sourceKind, id)
      end
    elseif e.op == "aura_poison_dps" or e.op == "aura_burn_dps" then
      local kind = (e.op == "aura_poison_dps") and "poison" or "burn"
      local inc = (pa.inc or 0.5) * sm
      for _, to in ipairs(resolveTargets(target, from)) do
        local dst = byCell[to]
        local add = dst and math.floor(baseAfflDps(dst.id, kind, dst.level) * inc + 0.5) or 0
        if add > 0 then addLink(from, to, kind, "+" .. add, sourceKind, id) end
      end
    elseif e.op == "aura_rot_growth" then
      for _, to in ipairs(resolveTargets(target, from)) do
        addLink(from, to, "rot", auraAdd((pa.bonus or 0) * sm), sourceKind, id)
      end
    elseif e.op == "aura_grant_bleed" then
      for _, to in ipairs(resolveTargets(target, from)) do
        addLink(from, to, "bleed", auraAdd((pa.dps or 1) * sm), sourceKind, id)
      end
    elseif e.op == "aura_stat" then
      local value = (pa.stat == "multicast") and (pa.value or 0) or ((pa.value or 0) * sm)
      for _, to in ipairs(resolveTargets(target, from)) do
        local dst = byCell[to]
        local kind, label = statAuraVisual(pa.stat, value, dst and dst.id, dst and dst.level)
        addLink(from, to, kind, label, sourceKind, id)
      end
    elseif e.op == "aura_shield" then
      local label = pa.cdr and ("-" .. math.floor(pa.cdr * 100 + 0.5) .. "% CD")
        or (pa.valueInc and auraPercent(pa.valueInc, true)) or "SH"
      for _, to in ipairs(resolveTargets(target, from)) do addLink(from, to, "shield", label, sourceKind, id) end
    elseif e.op == "repeat_ability" then
      local who = pa.who or "ahead"
      local targets = resolveTargets(who == "neighbors" and "neighbors" or "ahead", from)
      for _, to in ipairs(targets) do
        local dst = byCell[to]
        local hasHit = false
        for _, ne in ipairs(UnitResolver.effectsFor(dst.id, dst.level)) do
          if ne.trigger == "on_hit" and not ne.viaCopy then hasHit = true; break end
        end
        if hasHit then addLink(from, to, "mimicry", "COPY", sourceKind, id) end
      end
    elseif e.op == "amplify_auras" then
      for _, to in ipairs(resolveTargets(pa.target or "team", from)) do
        addLink(from, to, "mimicry", auraPercent(pa.frac or 0, true), sourceKind, id)
      end
    elseif e.op == "aura_per_unique_type" then
      addLink(from, from, "growth", "+TYPE", sourceKind, id)
    end
  end

  for i, q in pairs(byCell) do
    for _, e in ipairs(UnitResolver.effectsFor(q.id, q.level)) do
      addEffectLinks(e, i, q.id, q.level, "unit")
    end
  end

  local cmd = self.commanderSlot
  if cmd and self:commanderUnlocked() then
    local cb = UnitResolver.commandBonusFor(cmd.id, cmd.level or 1)
    if cb then
      if cb.op == "aura_stat" then
        addEffectLinks(cb, "commander", cmd.id, cmd.level or 1, "commander")
      elseif cb.op == "grant_team" then
        local kind, label = grantTeamVisual(cb.params)
        for _, to in ipairs(resolveTargets("team", nil)) do addLink("commander", to, kind, label, "commander", cmd.id) end
      end
    end
  end
  return links
end

-- État d'interaction (survol/voisins/cible de drop/survol boutique), calculé une fois par frame et
-- partagé entre drawBack (fonds) et drawOverlay (bordures/texte). Coords souris en espace virtuel.
function Build:computeUi()
  local hover = self:slotAt(self.mx, self.my)
  local ui = { hover = hover, dropTarget = self.drag and hover or nil, nbset = {}, shopHover = self:shopAt(self.mx, self.my), benchHover = self:benchAt(self.mx, self.my),
    commanderHover = self:commanderAt(self.mx, self.my) }
  if hover then for _, j in ipairs(self.board:neighbors(hover)) do ui.nbset[j] = true end end
  -- C4 — PORTÉE DU COMMANDANT : survoler le piédestal (rempli) éclaire les unités du board que son aura touche
  -- + une étiquette de portée (« COMMANDS … »). cmdRange[slot]=true ; cmdRangeLabel = clé i18n (+ vars).
  if ui.commanderHover and self.commanderSlot then
    ui.cmdRange, ui.cmdRangeLabel, ui.cmdRangeVars = self:commandRange()
  end
  ui.auraLinks = self:resolveAuraLinks() -- « qui buffe qui » : arêtes colorées (drawBack) + chips (drawOverlay)
  ui.networkInspect = self.forceNetworkInspect or ctrlHeld()
  local hoverUnit = ui.hover and self.slotRigs[ui.hover] and ui.hover or nil
  local dropUnit = ui.dropTarget and self.slotRigs[ui.dropTarget] and ui.dropTarget or nil
  local commanderUnit = ui.commanderHover and self.commanderSlot and "commander" or nil
  ui.networkFocus = ui.networkInspect and (hoverUnit or dropUnit or commanderUnit) or nil
  ui.networkShowAll = ui.networkInspect and not ui.networkFocus
  self.uiState = ui -- champ distinct de la méthode (sinon self.uiState renverrait la méthode quand vide)
  return ui
end

function Build:auraLinkActive(lk, ui)
  if not (lk and ui) then return false end
  if not ui.networkInspect then return false end
  if ui.networkShowAll then return true end
  local focus = ui.networkFocus
  if not focus then return false end
  if focus == "commander" then return lk.from == "commander" or lk.sourceKind == "commander" end
  if lk.from == focus or lk.to == focus then return true end
  return false
end

-- ── Pre-pass natif (espace design) : atmosphère + arêtes + FONDS (cases / panneau / cartes) ──
-- Tout ce qui doit passer DERRIÈRE les rigs (dessinés ensuite dans le canvas virtuel). pos[i] virtuel ×4.
function Build:drawBack(view)
  self.view = view -- mémorise la vue (drawWorld en a besoin pour clipper l'aperçu dans la carte)
  local ui = self:computeUi()
  local b, run, c = self.board, self.host.run, Theme.c
  Draw.begin(view)
  self.ambient:draw("build")
  if self.nightmareBg then
    local y0 = TOPCHROME_H
    self.nightmareBg:drawField(0, y0, Draw.W, math.max(1, BAR.y - y0))
    -- Voile central pour garder les sockets lisibles tout en laissant vivre le champ.
    Draw.rect(0, y0, Draw.W, BAR.y - y0, { c.void[1], c.void[2], c.void[3], 0.16 })
  end

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
  -- Mode inspection réseau (Ctrl) : les liens d'aura ne polluent plus le hover normal des cartes.
  -- Ctrl + unité = liens liés à cette unité ; Ctrl sans unité = stress view de tout le réseau.
  if ui.networkInspect then
    for _, lk in ipairs(ui.auraLinks or {}) do
      if self:auraLinkActive(lk, ui) then
        local pf, pt = self:auraPoint(lk.from), self:auraPoint(lk.to)
        if pf and pt and (pf.x ~= pt.x or pf.y ~= pt.y) then
          local col = self:auraColor(lk.kind)
          local allMode = ui.networkShowAll
          if love.graphics.setBlendMode then
            love.graphics.setBlendMode("add"); Draw.setColor({ col[1], col[2], col[3], allMode and 0.10 or 0.20 })
            love.graphics.setLineWidth(allMode and 6 or 8); love.graphics.line(pf.x * 4, pf.y * 4, pt.x * 4, pt.y * 4)
            love.graphics.setBlendMode("alpha")
          end
          Draw.setColor({ col[1], col[2], col[3], allMode and 0.46 or 0.88 })
          love.graphics.setLineWidth(allMode and 2 or 3)
          love.graphics.line(pf.x * 4, pf.y * 4, pt.x * 4, pt.y * 4)
        end
      end
    end
  end
  love.graphics.setLineWidth(1); Draw.reset()

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
  -- DÉBLOCABLE AU SURVOL (retour user) : pendant un grant de slot, la case VERROUILLÉE sous le curseur est
  -- CLIQUABLE pour l'ouvrir -> on signale l'invitation. lockedCellAt = exactement la cible du clic (mousepressed),
  -- donc l'état « déblocable » est STRICT : nil hors grant, et seulement la case verrouillée pointée (jamais une
  -- case déjà ouverte/occupée ni une verrouillée non-survolée). RENDER pur.
  local unlockHover = (run and run.pendingSlotGrant) and self:lockedCellAt(self.mx, self.my) or nil
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
    Slot.draw(x, y, S, state, sr and { tierCol = Rarity.tierColor(Units[sr.id].rank), level = sr.level or 1 } or nil)
    -- INVITATION DE DÉBLOCAGE : la case verrouillée SURVOLÉE pendant un grant RESPIRE en OR (voile additif +
    -- liseré qui pulse) -> « clique pour ouvrir ». Même langage que la portée du commandant (additif respirant,
    -- PAS un disque de fond). Gate STRICT : i == unlockHover (déblocable + survolée). Subtil mais lisible.
    if i == unlockHover and love.graphics.setBlendMode then
      local pulse = 0.5 + 0.5 * math.sin(self.t / 60 * 5.0)
      local gcol = c.gold
      love.graphics.setBlendMode("add")
      love.graphics.setColor(gcol[1], gcol[2], gcol[3], 0.10 + 0.16 * pulse)
      love.graphics.rectangle("fill", x, y, S, S)
      love.graphics.setColor(gcol[1], gcol[2], gcol[3], 0.40 + 0.35 * pulse)
      love.graphics.setLineWidth(2)
      love.graphics.rectangle("line", x - 1, y - 1, S + 2, S + 2)
      love.graphics.setLineWidth(1)
      love.graphics.setBlendMode("alpha"); love.graphics.setColor(1, 1, 1, 1)
    end
    -- carte de risque : voile de sang d'autant plus dense que la case est avancée (front exposé au ciblage).
    local cell = b.shape.cells[i]
    if slot.unlocked and cell then
      local expo = 1 - (maxCol - cell.x) / spanCol
      if expo > 0.001 then
        Draw.setColor({ c.edgeActive[1], c.edgeActive[2], c.edgeActive[3], 0.16 * expo })
        love.graphics.rectangle("fill", x, y, S, S)
      end
    end
    -- C4 — PORTÉE DU COMMANDANT (survol du piédestal) : la case affectée par l'aura du chef PULSE en OR
    -- (liseré + voile additif qui respire) -> on VOIT qui le commandant commande. Réutilise le langage de
    -- surlignage (additif respirant) déjà employé pour les voisins/cibles. Seulement sur les cases TOUCHÉES.
    if ui.cmdRange and ui.cmdRange[i] and sr and love.graphics.setBlendMode then
      local pulse = 0.5 + 0.5 * math.sin(self.t / 60 * 4.2)
      local gcol = c.gold
      love.graphics.setBlendMode("add")
      love.graphics.setColor(gcol[1], gcol[2], gcol[3], 0.12 + 0.14 * pulse)
      love.graphics.rectangle("fill", x, y, S, S)
      love.graphics.setColor(gcol[1], gcol[2], gcol[3], 0.45 + 0.30 * pulse)
      love.graphics.setLineWidth(2)
      love.graphics.rectangle("line", x - 1, y - 1, S + 2, S + 2)
      love.graphics.setLineWidth(1)
      love.graphics.setBlendMode("alpha"); love.graphics.setColor(1, 1, 1, 1)
    end
  end

  -- BANC (réserve, rangée sous le plateau) : même atome Slot (drop/hover/selected/empty) + pip type/niveau si
  -- occupé. MASQUÉ en inspection figée (pas de réserve à manipuler).
  if not self.locked then
    for i = 1, self:benchCapacity() do
      local r = self.benchSlots[i]
      local bx, by, bw = r.x * 4, r.y * 4, r.w * 4
      local sr = self.bench[i]
      local hovering = (ui.benchHover == i)
      local bstate = (self.drag and hovering and "drop") or (hovering and "hover") or (sr and "selected") or "empty"
      Slot.draw(bx, by, bw, bstate, sr and { tierCol = Rarity.tierColor(Units[sr.id].rank), level = sr.level or 1 } or nil)
    end
  end

  -- C4 — CASE DU COMMANDANT (case SIMPLE, src/ui/commandercell.lua) : DISTINCTE du graphe, AUCUNE arête vers le
  -- board. Visible dès le début de la run. Le FOND de la case + le header « COMMANDER » se dessinent ICI, DERRIÈRE le rig du commandant
  -- (rendu dans la case par drawWorld) ; le hint « vide » et l'étiquette de portée au drag vivent en overlay.
  local pedOffer = run and run.pendingCommanderGrant
  if not self.locked and self.pedRect and self:commanderCellShown() then
    local r = self.pedRect
    local sr = self.commanderSlot
    local hovering = ui.commanderHover or (pedOffer and inRect(self.mx, self.my, self.commanderRect))
    local validDrop = self.drag and canCommand(self.drag.id) and hovering -- drop valide = porteur de commandBonus survolant
    -- SECOUSSE de refus : décale la case horizontalement (sinusoïde amortie) tant que cmdShake > 0.
    local shakeX = 0
    if self.cmdShake > 0 then shakeX = math.sin(self.cmdShake * 60) * 3 * (self.cmdShake / 0.32) end
    CommanderCell.draw(r.x * 4 + shakeX, r.y * 4, r.w * 4, r.h * 4, {
      filled = sr ~= nil, hover = hovering, validDrop = validDrop,
      danger = self.cmdShake > 0, t = self.t / 60 })
  end

  -- ── BARRE DU BAS (handoff « Bottom Bar ») : panneau ENCADRÉ + filet laiton gravé + filets iron + fonds de carte ──
  -- panneau : dégradé sombre (#15111c -> #0a0710) + bord iron + filet laiton gravé (2px) en haut.
  Panel.vgrad(BAR.x, BAR.y, BAR.w, BAR.h, { 0x15 / 255, 0x11 / 255, 0x1c / 255, 1 }, { 0x0a / 255, 0x07 / 255, 0x10 / 255, 1 })
  Draw.rect(BAR.x, BAR.y, BAR.w, BAR.h, nil, c.iron, 1)
  Draw.rect(BAR.x + 1, BAR.y + 1, BAR.w - 2, BAR_RULE, c.brass) -- filet laiton (≈ dégradé transparent->brass->brassL->brass)
  Draw.rect(math.floor(BAR.x + 1 + (BAR.w - 2) * 0.12), BAR.y + 1, math.floor((BAR.w - 2) * 0.76), 1, c.brassL)
  Draw.setColor(c.brassS, 0.12); if love.graphics then love.graphics.rectangle("fill", BAR.x + 1, BAR.y + BAR_RULE + 1, BAR.w - 2, 1) end; Draw.reset()
  -- filets iron entre les 3 colonnes.
  Draw.rect(self.lay.div1.x, self.lay.div1.y, 1, self.lay.div1.h, c.iron)
  Draw.rect(self.lay.div2.x, self.lay.div2.y, 1, self.lay.div2.h, c.iron)

  -- FONDS DE CARTE : dégradé sombre + bord iron (laiton vif au survol, sourd hors budget) + zone d'art à
  -- HACHURE diagonale (placeholder de sprite ; la créature de drawWorld se pose par-dessus) + bord bas iron.
  if run then
    for i, rect in ipairs(self.shopSlots) do
      local o = run.shop[i]
      if o then
        local x, y, w, h = rect.x * 4, rect.y * 4, rect.w * 4, rect.h * 4
        if o.sold then
          Draw.rect(x, y, w, h, c.void, c.iron, 1)
        else
          local playable = self:offerPlayable(o)
          local hot = (ui.shopHover == i) and playable
          -- fond carte (dégradé), assombri hors budget.
          Panel.vgrad(x, y, w, h, playable and { 0x15 / 255, 0x11 / 255, 0x1d / 255, 1 } or { 0x0f / 255, 0x0c / 255, 0x14 / 255, 1 }, { 0x0d / 255, 0x0a / 255, 0x13 / 255, 1 })
          -- zone d'art : base stone-900 + HACHURE diagonale stone-800 (clippée à la zone), puis bord bas iron.
          local ah = CARD_ART_H
          Draw.rect(x + 1, y + 1, w - 2, ah - 1, c.stone900)
          if love.graphics then
            if self.view then Draw.scissor(self.view, x + 1, y + 1, w - 2, ah - 1) end
            Draw.setColor(c.stone800, 0.9); love.graphics.setLineWidth(3)
            for d = -ah, w, 12 do love.graphics.line(x + d, y + ah, x + d + ah, y) end
            love.graphics.setLineWidth(1); Draw.reset()
            if self.view then Draw.noScissor() end
          end
          Draw.rect(x, y + ah, w, 1, c.iron) -- bord bas de la zone d'art
          Draw.setColor(c.brassS, 0.06); if love.graphics then love.graphics.rectangle("fill", x + 1, y + 1, w - 2, 1) end; Draw.reset()
          -- bord de carte = COULEUR DE RARETÉ (gris DREGS -> vert -> bleu -> violet -> or) : la rareté se lit
          -- d'un coup d'œil (retour user 2026-06 : le bord iron du mockup masquait le tier). Avivé + halo au
          -- survol (tierBright) ; sourd (iron) si hors budget.
          local rank = (Units[o.id] and Units[o.id].rank) or 1
          local border = (not playable) and c.iron or (hot and Rarity.tierBright(rank) or Rarity.tierColor(rank))
          Draw.rect(x, y, w, h, nil, border, 1)
          -- INDICATEUR A — « déjà possédé » (passif) : on détient ≥1 exemplaire de ce monstre sur le plateau OU
          -- le banc -> un liseré laiton/or DORMANT respire doucement sur le bord (DA pierre-rune : la gravure
          -- s'éveille). Discret (alpha bas, additif), sous le halo de survol et le badge LVL. RENDER pur.
          local owned = self:ownsAnyCopy(o.id)
          if owned and love.graphics and love.graphics.setBlendMode then
            local pulse = 0.5 + 0.5 * math.sin(self.t / 60 * 1.9) -- respiration lente (~0,3 Hz)
            local oa = (0.10 + 0.07 * pulse) * (playable and 1 or 0.55) -- sourd si hors budget (cohérent au dim)
            love.graphics.setBlendMode("add"); love.graphics.setColor(c.brassS[1], c.brassS[2], c.brassS[3], oa)
            love.graphics.rectangle("line", x + 1, y + 1, w - 2, h - 2)
            love.graphics.setBlendMode("alpha"); love.graphics.setColor(1, 1, 1, 1)
          end
          if hot and love.graphics and love.graphics.setBlendMode then
            local glow = Rarity.tierBright(rank)
            love.graphics.setBlendMode("add"); love.graphics.setColor(glow[1], glow[2], glow[3], 0.18)
            love.graphics.rectangle("line", x, y, w, h); love.graphics.setBlendMode("alpha"); love.graphics.setColor(1, 1, 1, 1)
          end
        end
      end
    end
  end

  Draw.finish()
end

-- LIFT du sprite traîné en VIRTUEL (≈ 3px, échelle du sautillement de fusion bounceLift) : le lab travaille en
-- design ~11px, le board en virtuel 320×180 -> on passe ~3px à Drag.fx pour une amplitude juste sur un sprite ~18px.
local DRAG_LIFT_V = 3

-- Position de DESSIN (pieds au sol, VIRTUEL) d'une pièce = son RESSORT s'il existe, sinon l'ancre fournie en
-- secours (1re frame avant ensureSpring). Renvoie (x, y) ENTIERS (pixel-perfect).
local function springGround(d, fbx, fby)
  local px = (d and d.px) or fbx
  local py = (d and d.py) or fby
  return math.floor(px + 0.5), math.floor(py + 0.5)
end

-- Enrobe un dessin de pièce du JUS de drag (lift + scale + tilt autour de l'ancre + OMBRE portée au pickup).
-- fx = Drag.fx(d, DRAG_LIFT_V) ; au repos c'est un no-op (dy=0, scale=1, rot=0, shadow=false). `body(gx, gy)`
-- dessine la créature à l'ancre transformée. shadowW = côté approx de l'ombre (virtuel). RENDER pur.
local function withDragFx(d, gx, gy, shadowW, body)
  local fx = d and Drag.fx(d, DRAG_LIFT_V) or nil
  if fx and fx.shadow then
    -- ombre portée (le sprite est SOULEVÉ -> son ombre reste au sol, un peu décalée) : galette sombre douce.
    love.graphics.setColor(0, 0, 0, 0.30)
    love.graphics.ellipse("fill", gx, gy + 1, shadowW * 0.5, shadowW * 0.22)
    love.graphics.setColor(1, 1, 1, 1)
  end
  local dy = fx and fx.dy or 0
  local ay = gy + dy
  if fx and (fx.scale ~= 1 or (fx.rot or 0) ~= 0 or dy ~= 0) then
    love.graphics.push()
    love.graphics.translate(gx, ay)
    love.graphics.rotate(fx.rot or 0)
    love.graphics.scale(fx.scale or 1, fx.scale or 1)
    love.graphics.translate(-gx, -ay)
    body(gx, ay)
    love.graphics.pop()
  else
    body(gx, gy)
  end
end

-- SQUASH-STRETCH du survivant pendant la fusion (mergeEnv) : SCALE autour des PIEDS (pivot = gx,gy = sol),
-- pour que la pièce « se charge » à l'anticipation puis « éclate » au climax (cf. Feel Lab targetScale). No-op
-- (scale==1) hors animation -> aucun coût ni transform parasite. RENDER pur.
local function withMergeScale(sr, gx, gy, body)
  local s = mergeScale(sr)
  if math.abs(s - 1) < 0.002 then return body() end
  love.graphics.push()
  love.graphics.translate(gx, gy)
  love.graphics.scale(s, s)
  love.graphics.translate(-gx, -gy)
  body()
  love.graphics.pop()
end

-- (RÈGLE DA : AUCUN halo/disque de fond « pour mettre en valeur » = banni.) L'ancien `mergeHalo` (disque doré
-- additif derrière le rig au climax) est RETIRÉ. L'« illumination » du level-up est portée par l'EXPLOSION de
-- particules pixel (onde + shards + braises + motes) + le punch de scale du rig, jamais par un backing rond.
-- No-op conservé (call-sites inchangés) pour ne pas toucher la structure de drawWorld. `mergeGlow` reste lu par
-- d'éventuels usages futurs, mais ne dessine plus rien ici.
local function mergeHalo() end

-- ── Rendu monde (canvas virtuel, pixel-perfect) : UNIQUEMENT les rigs (unités/aperçus/drag) ──
-- Toutes les créatures sont AJUSTÉES À LEUR CONTENEUR (fit-to-box, cf. rigFitScale) -> aucune ne déborde
-- ni n'est coupée par le bord de sa case / carte. update() pose char.x,char.y ; on les SCALE à l'affichage.
function Build:drawWorld()
  local b = self.board
  -- CASE : 80 design = 20 virtuel. Zone utile (hors cadre forge) ~18 virtuel. On vise une boîte ~18×18
  -- avec marge -> la créature REMPLIT la case sans déborder ni être coupée, pieds calés au sol de la case.
  local CELL_FIT_W, CELL_FIT_H = 18, 18
  -- Échelles du rendu VIVANT (cadre natif 64) par surface — placeholders à affiner au screenshot.
  -- (la boutique n'a plus d'échelle fixe : la créature est calée à la ZONE D'ART de la carte via Critter.draw.)
  local SLOT_SCALE, DRAG_SCALE = 0.36, 0.36
  for i, sr in pairs(self.slotRigs) do
    if b.slots[i].unlocked then
      local c = sr.char
      -- POSITION = le RESSORT de drag (sr.d.px/py) : la pièce GLISSE dans sa case (pose/swap fluides) au lieu de
      -- s'y téléporter ; au repos px,py == l'ancre de la case (aucun changement visuel). Pieds calés au sol.
      local ax, ay = self:boardAnchor(i)
      local groundX, groundY = springGround(sr.d, ax, ay)
      groundY = groundY - math.floor(bounceLift(sr) + 0.5) -- C3 : saut de fusion (chorégraphie)
      groundX = groundX + popShakeX(sr) -- POSE : frémissement horizontal d'apparition (se résorbe en ~0,3 s)
      mergeHalo(sr, groundX, groundY, 11) -- lueur additive du survivant au climax (DERRIÈRE le sprite)
      withDragFx(sr.d, groundX, groundY, 16, function(gx, gy)
        withMergeScale(sr, gx, gy, function() -- squash-stretch du survivant pendant la fusion (pivot = pieds)
        if Critter.has(sr.id) then
          -- RENDU VIVANT : cadre natif (taille relative + mouvement par famille), pieds calés au sol.
          -- plateau de build = formation de combat : regarde à DROITE / vers l'adversaire (wantDir=1), comme en combat.
          Critter.drawAt(nil, sr.id, gx, gy, SLOT_SCALE, self.t / 60, Critter.facingFor(sr.id, 1))
        else
          -- fallback rig baké (créatures dessinées-main) : fit-silhouette historique, pieds (bnd.bot) au sol.
          local s = self:rigFitScale(sr.id, CELL_FIT_W, CELL_FIT_H, 0.94, 1.5)
          local bnd = self:rigBounds(sr.id)
          love.graphics.push()
          love.graphics.translate(gx, gy)
          love.graphics.scale(s, s)
          love.graphics.translate(0, -bnd.bot)
          local sx, sy = c.x, c.y
          c.x, c.y = 0, 0
          Rig.draw(c)
          c.x, c.y = sx, sy
          love.graphics.pop()
        end
        end) -- /withMergeScale
      end)
    end
  end
  -- RIGS du BANC (réserve) : créatures stockées, rendu vivant à échelle réduite, pieds calés au bas du slot.
  local BENCH_SCALE = 0.3
  for i = 1, self:benchCapacity() do
    local sr = self.bench[i]
    if sr then
      -- ⚠ drawWorld dessine sur le canvas VIRTUEL (320×180) : les coords sont en VIRTUEL. POSITION = le RESSORT
      -- de drag (sr.d.px/py) -> la pièce GLISSE dans le slot de banc (pose/swap fluides) ; au repos = l'ancre.
      local ax, ay = self:benchAnchor(i)
      local gx0, gy0 = springGround(sr.d, ax, ay)
      gy0 = gy0 - math.floor(bounceLift(sr) + 0.5) -- -saut de fusion (chorégraphie)
      gx0 = gx0 + popShakeX(sr) -- POSE : frémissement horizontal d'apparition (banc)
      mergeHalo(sr, gx0, gy0, 8) -- lueur additive du survivant au climax (banc)
      withDragFx(sr.d, gx0, gy0, 13, function(gx, gy)
        withMergeScale(sr, gx, gy, function() -- squash-stretch du survivant pendant la fusion (pivot = pieds)
        if Critter.has(sr.id) then
          Critter.drawAt(nil, sr.id, gx, gy, BENCH_SCALE, self.t / 60, Critter.facingFor(sr.id, -1)) -- banc : à gauche

        else
          local s = self:rigFitScale(sr.id, 13, 13, 0.9, 1.4)
          local bnd = self:rigBounds(sr.id)
          love.graphics.push(); love.graphics.translate(gx, gy); love.graphics.scale(s, s); love.graphics.translate(0, -bnd.bot)
          sr.char.x, sr.char.y, sr.char.facing = 0, 0, 1
          Rig.draw(sr.char)
          love.graphics.pop()
        end
        end) -- /withMergeScale
      end)
    end
  end
  -- C4 — RIG DU COMMANDANT dans la case : box-fit dans la case simple (un cran plus grand qu'un troupier ->
  -- le chef est un peu plus imposant), pieds calés au bas, AVEC une légère respiration (lift). Visible seulement
  -- si la case est remplie (commanderSlot existe). Le décor (case + header) = drawBack.
  if self.commanderSlot and self.commanderRect and self:commanderUnlocked() then
    local sr = self.commanderSlot
    local r = self.commanderRect
    local lift = math.sin(self.t / 60 * 1.7) * 0.5 -- respiration douce (le chef « règne »), virtuel
    -- CALÉ À LA CASE (box-fit) : le commandant REMPLIT la case (fill 0.88) quelle que soit la silhouette native,
    -- pieds ancrés au bas, avec une petite marge sous le liseré. -lift = il « respire ».
    local boxX, boxY = r.x + 2, r.y + 2 - lift
    local boxW, boxH = r.w - 4, r.h - 5
    -- RESSORT de drag : le commandant GLISSE en place (delta px,py vs son ancre de repos) quand on l'amène/swap
    -- dans la case ; au repos le delta est nul (box-fit inchangé). dx/dy translatent toute la case.
    local ax, ay = self:commanderAnchor()
    local sdx = sr.d and (sr.d.px - ax) or 0
    local sdy = sr.d and (sr.d.py - ay) or 0
    boxX, boxY = boxX + sdx + popShakeX(sr), boxY + sdy -- + frémissement horizontal d'apparition (pose au piédestal)
    if Critter.has(sr.id) then
      -- commandant au piédestal = ta formation : regarde à DROITE / vers l'adversaire (wantDir=1), comme en combat.
      Critter.drawFit(nil, sr.id, boxX, boxY, boxW, boxH, self.t / 60, Critter.facingFor(sr.id, 1), 0.88, 2.4)
    elseif sr.char then
      local s = self:rigFitScale(sr.id, boxW, boxH, 0.92, 2.0)
      local bnd = self:rigBounds(sr.id)
      local gx = math.floor(boxX + boxW / 2 + 0.5)
      local gy = math.floor(boxY + boxH - 1 + 0.5)
      love.graphics.push(); love.graphics.translate(gx, gy); love.graphics.scale(s, s); love.graphics.translate(0, -bnd.bot)
      sr.char.x, sr.char.y, sr.char.facing = 0, 0, 1
      Rig.draw(sr.char)
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
          -- CARTE ART-FORWARD (handoff « Bottom Bar ») : la créature est calée à la ZONE D'ART (haut CARD_ART_H)
          -- via Critter.draw (échelle = hauteur de boîte) -> taille RELATIVE conservée, JAMAIS de débordement
          -- (clip à la zone d'art en sus) ; les pieds tombent au bas de la zone, au-dessus du pied nom/coût.
          local artHv = CARD_ART_H / 4
          local artX, artY, artW, artH = rect.x + 1, rect.y, rect.w - 2, artHv
          if self.view then Draw.scissor(self.view, artX * 4, artY * 4, artW * 4, artH * 4) end
          if Critter.has(o.id) then
            -- carte de boutique (portrait) : regarde à GAUCHE (wantDir=-1) normalisé par le sens inhérent.
            Critter.draw(nil, o.id, artX, artY, artW, artH, self.t / 60, Critter.facingFor(o.id, -1), 0.92)
          else
            -- fallback rig baké (6 créatures dessinées-main) : fit-silhouette dans la zone d'art.
            local s = self:rigFitScale(o.id, artW, artH * 0.9, 0.9, 2.2)
            local bnd = self:rigBounds(o.id)
            love.graphics.push()
            love.graphics.translate(artX + artW / 2, artY + artH - 1)
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
    -- PIÈCE TRAÎNÉE (dessinée EN DERNIER = au-dessus de tout) : position = le RESSORT (suit la souris en glissant),
    -- + le JUS de pickup (lift + scale + tilt par vélocité + OMBRE portée). Au lâcher, la pièce a déjà filé dans
    -- son container -> ce bloc ne dessine que pendant le drag actif.
    local d = self.drag.d
    local gx, gy = springGround(d, self.mx, self.my + 9)
    withDragFx(d, gx, gy, 16, function(bx, by)
      if Critter.has(self.drag.id) then
        -- pièce traînée vers le plateau : regarde à DROITE / vers l'adversaire (wantDir=1), évite le flip au lâcher.
        Critter.drawAt(nil, self.drag.id, bx, by, DRAG_SCALE, self.t / 60, Critter.facingFor(self.drag.id, 1))
      else
        local c = self.drag.char
        local sx, sy = c.x, c.y
        c.x, c.y = bx, by
        Rig.draw(c)
        c.x, c.y = sx, sy
      end
    end)
  end
  love.graphics.setColor(1, 1, 1, 1)
end

-- Retire le DERNIER CODEPOINT UTF-8 (pas le dernier octet) : recule sur les octets de continuation (0x80..0xBF)
-- jusqu'au début de la séquence, puis coupe. Tronquer octet-par-octet casse un caractère multi-octets (le
-- « · » U+00B7, « … », un accent) -> UTF-8 invalide -> love `font:getWidth` lève « Invalid UTF-8 » (crash
-- réel : survol d'une fiche dont le readout d'aura « gives A · B · C » dépasse, retour user 2026-06).
local function dropLastCodepoint(s)
  local i = #s
  while i > 1 do
    local b = s:byte(i)
    if b and b >= 0x80 and b < 0xC0 then i = i - 1 else break end
  end
  return s:sub(1, i - 1)
end

-- MAJUSCULES SÛRES : n'affecte que [a-z] ASCII. string.upper (Lua 5.1/LuaJIT) mappe octet par octet et peut
-- corrompre une séquence UTF-8 multi-octets (nom accentué) -> on protège les noms d'unité passés en capitales.
local function upperAscii(s) return (s:gsub("[a-z]", string.upper)) end

-- Ajuste un libellé à une largeur max : descend la taille de police (base..floorSz) tant que ça déborde ; si
-- toujours trop long au plancher, tronque avec une ellipse (par CODEPOINT). Évite que les noms longs (4 mots)
-- mordent sur le voisin (board) ou débordent de la carte (shop). fontFn = Theme.label / Theme.subhead.
local function fitText(text, maxW, fontFn, base, floorSz)
  floorSz = floorSz or 7
  for sz = base, floorSz, -1 do
    local f = fontFn(sz)
    if not f or f:getWidth(text) <= maxW then return text, f end
  end
  local f = fontFn(floorSz)
  if f and f:getWidth(text) > maxW then
    while #text > 1 and f:getWidth(text .. "…") > maxW do text = dropLastCodepoint(text) end
    text = text .. "…"
  end
  return text, f
end

-- ── Overlay (espace design, texte net) : chrome + bordures de case + boutique + boutons + infobulle ──
function Build:drawOverlay(view)
  local b, run, c = self.board, self.host.run, Theme.c
  local ui = self.uiState or self:computeUi()
  Draw.begin(view)

  -- TOP CHROME (refonte « Build Screen ») : bandeau de run riche + barre sigil/archétype, PLEINE LARGEUR.
  if run then self:drawRunBanner(run)
  else
    Panel.vgrad(0, 0, Draw.W, BANNER_H, { 0x1d / 255, 0x17 / 255, 0x10 / 255, 1 }, { 0x12 / 255, 0x0d / 255, 0x08 / 255, 1 })
    Draw.textC(T("ui.placed_count", { placed = self:placedCount(), active = b.activeCount }), Draw.W / 2, 20, c.faint, Theme.label(12))
  end
  if not Board.SIGILS_PAUSED then self:drawSigilBar() end -- barre sigil EN PAUSE (on ne joue que le carré)
  -- Prompt de grant d'emplacement (event timé), juste sous le top chrome.
  if run and run.pendingSlotGrant then
    Draw.textC(T("ui.slot_grant"), Draw.W / 2, TOPCHROME_H + 8, c.gold, Theme.label(12))
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
        local cx, top = p.x * 4, p.y * 4 - SLOT_HALF
        local bottom = top + S
        -- Bandeau sombre en bas de case (dégradé transparent->void) : lisibilité du NOM + barre de vie posés
        -- PAR-DESSUS la créature (refonte « Build Screen » : nom DANS la case, comme le mockup).
        if love.graphics and love.graphics.setColor then
          for k = 1, 6 do
            love.graphics.setColor(c.void[1], c.void[2], c.void[3], 0.13 * k)
            love.graphics.rectangle("fill", cx - SLOT_HALF + 2, bottom - 4 - k * 3, S - 4, 3)
          end
          love.graphics.setColor(1, 1, 1, 1)
        end
        -- NOM : DANS la case (bas-centre, au-dessus de la barre de vie), ajusté/ellipsé au budget de case.
        local nm, nf = fitText(T("unit." .. sr.id .. ".name"), S - 8, Theme.label, 8, 7)
        Draw.textC(nm, cx, bottom - 19, c.ink2, nf)
        -- BARRE DE VIE (fiole de sang : dégradé + ménisque vif) : unité « vivante » prête au combat. Pleine en build.
        local hbw, hbh = S - 16, 5
        local hbx, hby = math.floor(cx - hbw / 2), bottom - 8
        Draw.rect(hbx - 1, hby - 1, hbw + 2, hbh + 2, nil, c.bloodD, 1)
        Panel.vgrad(hbx, hby, hbw, hbh, { 0x7a / 255, 0x14 / 255, 0x10 / 255, 1 }, { 0x3a / 255, 0x0a / 255, 0x08 / 255, 1 })
        Draw.rect(hbx, hby, hbw, 1, c.bloodL)
        -- BADGE TAUNT (unités à `taunt`, ex. gravewarden) : plaque laiton sur le buste -> override de ciblage lisible.
        if Units[sr.id] and Units[sr.id].taunt then
          local tf = Theme.label(7)
          local txt = T("ui.taunt")
          local bw = tf:getWidth(txt) + 12
          local bx, by = math.floor(cx - bw / 2), top + math.floor(S * 0.40)
          Draw.rect(bx, by, bw, 13, { 0x0c / 255, 0x09 / 255, 0x12 / 255, 0.92 }, c.brass, 1)
          Draw.text(txt, bx + 6, by + math.floor((13 - tf:getHeight()) / 2), c.brassS, tf)
        end
      end
    end
  end
  if run or self.uiState then self:drawAuraChips(ui) end -- chips chiffrés sur les arêtes d'aura (par-dessus rigs)
  if not self.locked then self:drawPedestalOverlay(ui, run) end -- C4 : CTA piédestal + étiquette de portée (DEVANT le rig)

  -- THE OFFERING (handoff « Bottom Bar ») : en-tête + 5 cartes ÉPURÉES (drawShopCard pose le contenu : tag de
  -- tier + nom + coût ; fond/zone d'art en drawBack, créature en drawWorld) + rail de tier à 5 crans au pied.
  if run then
    -- rects éco fidèles à l'état du grant AVANT le dessin (le grant peut s'allumer au frame de transition,
    -- AVANT que update n'ait re-synchronisé -> sinon declineBtn périmé/nil -> crash inRect, retour user 2026-06).
    self:syncEcoRects(run.pendingSlotGrant)
    self:drawOfferingHeader()
    for i, rect in ipairs(self.shopSlots) do
      local o = run.shop[i]
      if o then self:drawShopCard(i, rect, o, ui.shopHover == i) end
    end
    self:drawShopXpBar(run) -- rail de tier (5 crans) au pied de la colonne THE OFFERING
    self:drawEcoButton("build.reroll", self.rerollBtn, T("ui.reroll_label"), run:currentRerollCost(), run:canReroll())
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
      atMax and nil or run:currentBuyXpCost(),
      (not atMax) and run:canBuyXp())
  end

  -- ORBE DE VIE (extrême gauche de la barre du bas) : fluide = vies/START_LIVES, compteur au-dessus.
  if run then self:drawLifeOrb(run) end

  -- Bouton COMBAT = le CTA propre (variant "primary") : sang + YEUX cauchemardesques qui s'ouvrent au survol
  -- (glow) et réagissent au clic (flash), regard qui suit le curseur (opts.mouse en espace design). Le juice
  -- (lift/squash/flash/glow) vient de Feel.state ; l'action est différée côté mousepressed. Button marque la box.
  -- COMBAT VERROUILLÉ pendant l'anim de level-up (retour user) : grisé/inerte (pas un no-op silencieux) tant que
  -- la chorégraphie de fusion tourne -> l'user ne peut pas couper l'explosion en lançant le combat. mousepressed
  -- swallow le clic en miroir (levelUpActive). On garde le label « FIGHT » (l'intention reste), juste désactivé.
  local hasUnits = self:placedCount() > 0
  local enabled = hasUnits and not self:levelUpActive()
  local r = self.button
  local over = inRect(self.mx, self.my, r)
  Button.draw(r.x * 4, r.y * 4, r.w * 4, r.h * 4, "primary",
    hasUnits and T("ui.fight") or T("ui.place_unit"), -- label « FIGHT » dès qu'il y a une unité (même verrouillé)
    { hover = over and enabled, disabled = not enabled, feel = Feel.state("build.combat"),
      id = "build.combat", mouse = { mx = self.mx * 4, my = self.my * 4 }, t = self.t / 60 })

  -- En mode Ctrl réseau, on masque les cartes/sidecars : le curseur devient un outil de lecture des liens.
  if not (ui and ui.networkInspect) then
    -- Reliques rendues dans le bandeau de run (haut) ; ici on ne gère que l'infobulle au survol (prioritaire sur unité).
    local relIdx = run and self:relicAt(self.mx, self.my)
    if relIdx then
      self:drawRelicTooltip(run.relics[relIdx].id)
    elseif run and self.xpBarRect and inRect(self.mx, self.my, self.xpBarRect) then
      -- Survol de la barre d'XP -> cotes par rang du tier courant (enseigne « à quoi sert monter »).
      self:drawOddsTooltip(run)
    elseif self:commanderAt(self.mx, self.my) and self.commanderSlot and not self.drag then
      -- C4 — SURVOL DU PIÉDESTAL (rempli) : la MÊME fiche de monstre qu'une unité du board (MonsterCard), qui
      -- contient déjà le bandeau « AT COMMAND » détaillant l'aura -> on COMPREND ce que fait le commandant (fix du
      -- retour user : « le hover ne marche pas dessus »). Les cases commandées pulsent en or en parallèle (drawBack).
      self:drawTooltip(self.commanderSlot.id, nil, { context = "commander", occ = self.commanderSlot })
    else
      local id, boardSlot, occ
      local oi = self:shopAt(self.mx, self.my)
      if oi then id = run.shop[oi].id
      else
        local si = self:slotAt(self.mx, self.my)
        if si and self.slotRigs[si] then id = self.slotRigs[si].id; boardSlot = si; occ = self.slotRigs[si]
        else
          local bi = self:benchAt(self.mx, self.my)
          if bi and self.bench[bi] then id = self.bench[bi].id; occ = self.bench[bi] end
        end
      end
      if id then self:drawTooltip(id, boardSlot, { occ = occ }) end
    end
  end

  self:drawFx() -- GAME FEEL : bursts achat/vente/level-up PAR-DESSUS tout (transitoires)
  Draw.finish()
end

-- ── C4 — OVERLAY DE LA CASE DU COMMANDANT (texte net DEVANT le rig) : ÉTIQUETTE DE PORTÉE au drag (spec §4.2 :
-- « COMMANDS the whole pack / level-1 beasts / the vanguard »). La case + le header + le hint « vide » sont dessinés
-- en drawBack (CommanderCell) ; ici on ne pose que le cartouche de portée au DRAG. PUR-RENDER. ──
function Build:drawPedestalOverlay(ui, run)
  if not self.pedRect then return end
  if not self:commanderCellShown() then return end
  local c = Theme.c
  local r = self.pedRect
  local cx = r.x * 4 + r.w * 2
  local sr = self.commanderSlot

  -- SURVOL (rempli) : ÉTIQUETTE DE PORTÉE — un petit cartouche laiton ancré sous la case, « COMMANDS … ». C'est la
  -- portée VISIBLE en mots (les cases touchées pulsent déjà en or en drawBack). Mesuré -> jamais coupé. N'apparaît
  -- QUE pendant un DRAG par-dessus la case : au survol simple, la FICHE complète (MonsterCard) est affichée (elle
  -- porte déjà le bandeau « AT COMMAND ») -> on évite de doubler l'info (cartouche + fiche).
  if ui and ui.commanderHover and sr and ui.cmdRangeLabel and self.drag then
    local f = Theme.label(8)
    local prefix = T("ui.command_word") .. " "
    local scope = T(ui.cmdRangeLabel, ui.cmdRangeVars)
    -- portée vide (aucune unité posée touchée) -> « none in range » (honnête, grisé).
    local hasAny = false
    if ui.cmdRange then for _ in pairs(ui.cmdRange) do hasAny = true; break end end
    if not hasAny then scope = T("ui.command_none_short") end
    local full = prefix .. scope
    local tw = (f and f:getWidth(full)) or (#full * 5)
    local pad, hgt = 7, 15
    local pw = tw + pad * 2
    local px = math.floor(cx - pw / 2)
    -- ancré sous la case ; rebond si ça sort du bas de l'écran -> au-dessus du header.
    local py = (r.y + r.h) * 4 + 6
    if py + hgt > Draw.H - 4 then py = r.y * 4 - CommanderCell.HEADER_H - hgt - 4 end
    if px < 2 then px = 2 end
    if px + pw > Draw.W - 2 then px = Draw.W - 2 - pw end
    -- cartouche : panneau sombre + liseré laiton + le mot « COMMANDS » sourd, la PORTÉE en doré (hiérarchie).
    Draw.rect(px, py, pw, hgt, { 0x12 / 255, 0x0d / 255, 0x08 / 255, 0.96 }, c.brass, 1)
    local tx = px + pad
    local ty = py + math.floor((hgt - (f and f:getHeight() or 9)) / 2)
    Draw.text(prefix, tx, ty, c.ink4, f)
    Draw.text(scope, tx + (f and f:getWidth(prefix) or 0), ty, hasAny and c.gold or c.ink4, f)
  end
end

-- Carte de boutique ÉPURÉE (handoff « Bottom Bar » : de l'info a été retirée de la mini-carte). Le FOND
-- (dégradé + zone d'art hachurée + bord) est dessiné en drawBack ; la CRÉATURE en drawWorld (calée à la zone
-- d'art) ; ICI = le CONTENU par-dessus : tag de tier (haut-gauche) + pied [ NOM (Cinzel, ellipsé) | COÛT (gem) ].
-- Plus de chips d'affliction ni de cadre rareté (épuré). rect = rect VIRTUEL ; o = offre {id,cost,sold} ; hot = survolée.
-- BADGE « LVL n » BRILLANT (haut-droite de la zone d'art) — indicateur B : acheter cette offre déclenche une
-- FUSION (3 copies -> niveau+1), et on annonce le NIVEAU EXACT atteint (preview = previewMergeLevel, fidèle à
-- checkMerges). Cartouche sombre + liseré + chiffre en Space Mono, nimbé d'un SHIMMER additif qui pulse (dt
-- mural via self.t -> framerate-correct). LVL 2 = brillance dorée standard ; LVL 3 = climax PLEINE PUISSANCE
-- (sang clair sur or, glow plus intense = rank-up). Mesuré (getWidth) + clampé -> jamais coupé ni débordé.
-- RENDER pur, headless-safe (love.graphics gardé par Draw/Badge ; ici on garde setBlendMode).
function Build:drawMergeBadge(x, y, w, lvl)
  if not lvl or lvl < 2 then return end
  local c = Theme.c
  local cap = (lvl >= MAX_LEVEL)
  local f = Theme.value(11)
  local label = T("ui.merge_to_lvl", { n = lvl })
  local tw = (f and f:getWidth(label)) or (#label * 7)
  local th = (f and f:getHeight()) or 11
  local padX, padY = 5, 2
  local bw, bh = tw + padX * 2, th + padY * 2
  -- ancré haut-droite de la zone d'art, à 6px des bords ; clampé pour rester dans la carte.
  local bx = x + w - 6 - bw
  local by = y + 6
  if bx < x + 2 then bx = x + 2 end
  -- teintes : LVL 3 = or vif + accent sang (rank-up) ; LVL 2 = or sourd + accent laiton.
  local accent = cap and c.gold or c.brassL
  local textCol = cap and c.ctaText or c.gold
  local pulse = 0.5 + 0.5 * math.sin(self.t / 60 * (cap and 4.6 or 3.4)) -- LVL 3 scintille plus vite
  -- HALO additif derrière le cartouche (le « shimmer » qui respire) — sous le cartouche pour rester lisible.
  if love.graphics and love.graphics.setBlendMode then
    local ga = (cap and 0.22 or 0.13) + (cap and 0.16 or 0.10) * pulse
    local gcol = cap and c.gold or c.brassS
    love.graphics.setBlendMode("add"); love.graphics.setColor(gcol[1], gcol[2], gcol[3], ga)
    love.graphics.rectangle("fill", bx - 2, by - 2, bw + 4, bh + 4)
    love.graphics.setBlendMode("alpha"); love.graphics.setColor(1, 1, 1, 1)
  end
  -- cartouche opaque (le chiffre RESSORT) : fond sombre + liseré d'accent.
  Draw.rect(bx, by, bw, bh, { 0x12 / 255, 0x0d / 255, 0x08 / 255, 0.96 }, accent, 1)
  -- liseré additif qui s'avive avec le pulse (la gravure « s'illumine »).
  if love.graphics and love.graphics.setBlendMode then
    love.graphics.setBlendMode("add"); love.graphics.setColor(accent[1], accent[2], accent[3], 0.12 + 0.18 * pulse)
    love.graphics.rectangle("line", bx, by, bw, bh)
    love.graphics.setBlendMode("alpha"); love.graphics.setColor(1, 1, 1, 1)
  end
  Draw.text(label, bx + padX, by + padY, textCol, f)
end

function Build:drawShopCard(i, rect, o, hot)
  local c = Theme.c
  local x, y, w, h = rect.x * 4, rect.y * 4, rect.w * 4, rect.h * 4

  if o.sold then
    Draw.textC(T("ui.sold"), x + w / 2, y + h / 2 - 6, c.ghost, Theme.label(10))
    return
  end
  local aff = (self.host.run.gold >= o.cost)
  local playable = self:offerPlayable(o) -- jouable = or + (place OU trio à compléter). Sinon carte grisée.
  local rank = Units[o.id].rank or 1

  -- TAG DE TIER (haut-gauche, sur la zone d'art) : petit losange (couleur de RARETÉ) + nom de caste (DREGS..ELDER)
  -- en Space Mono. C'est le SEUL rappel de tier sur la carte (le reste de l'info a été retiré -> carte épurée).
  Badge.diamond(x + 12, y + 12, 3, playable and Rarity.tierColor(rank) or c.stone600, c.brassD, c.brassS)
  Draw.text(T(Rarity.tierNameKey(rank)), x + 18, y + 8, playable and c.faint or c.fainter, Theme.label(8))

  -- BADGE « LVL n » (haut-droite) : si l'achat aboutit à une fusion, on annonce le niveau atteint, en brillance.
  -- N'apparaît QUE quand previewMergeLevel renvoie un niveau (fusion réelle) -> le badge ne ment jamais.
  self:drawMergeBadge(x, y, w, self:previewMergeLevel(o))

  -- FREEZE (relique frost_seal) : petite pastille cliquable, hors chemin d'achat. Clic sur la pastille =
  -- verrouille/deverrouille cette offre au prochain reroll/round. Le RunState reste source de verite.
  local run = self.host.run
  if run and run.freezeSlots and run.freezeSlots > 0 then
    local fr = self:shopFreezeRect(i)
    local fx, fy, fw, fh = fr.x * 4, fr.y * 4, fr.w * 4, fr.h * 4
    local frozen = o.frozen == true
    local canFreeze = run:canFreezeOffer(i)
    local edge = frozen and c.shield or (canFreeze and c.brass or c.ink5)
    local fill = frozen and { c.shield[1], c.shield[2], c.shield[3], 0.18 } or { c.stone900[1], c.stone900[2], c.stone900[3], 0.88 }
    Draw.rect(fx, fy, fw, fh, fill, edge, 1)
    Draw.textC(T("ui.freeze_short"), fx + fw / 2, fy + math.floor((fh - 8) / 2), frozen and c.shield or (canFreeze and c.ink3 or c.ink5), Theme.label(7))
    if frozen then Draw.rect(x + 2, y + 2, w - 4, h - 4, nil, c.shield, 1) end
  end

  -- PIED (sous la zone d'art) : NOM (Cinzel 600, gauche, ajusté/ellipsé) + COÛT (gem or + nombre, droite).
  local fy = y + h - CARD_FOOT_H
  local valFont = Theme.value(13)
  local cval = tostring(o.cost)
  local badgeW = 13 + (valFont and valFont:getWidth(cval) or #cval * 8)
  local navail = w - 20 - badgeW
  local snm, snf = fitText(T("unit." .. o.id .. ".name"), navail, Theme.subhead, 10, 8)
  Draw.text(snm, x + 10, fy + math.floor((CARD_FOOT_H - 10) / 2), playable and c.name or c.dim, snf)
  Badge.cost(x + w - 10 - badgeW, fy + math.floor((CARD_FOOT_H - 13) / 2), o.cost, aff)
end

-- ── BANDEAU DE RUN (refonte « Build Screen.dc.html ») : HUD haut PLEINE LARGEUR. Cluster GAUCHE packé
-- [RELICS · GOLD · LIVES · DESCENT] + cluster DROITE aligné à droite [ROUND · SLOTS · STREAK · TIER],
-- filets iron entre segments. Tout en primitives nettes (Space Mono labels/valeurs ; gouttes/losanges pour
-- les pips). Données 100% lues du run. PUR-RENDER (golden neutre). ──

-- Goutte de sang (pip de vie du bandeau) : pointe + disque, lueur additive si pleine.
local function lifeDrop(cx, cy, on)
  local C = Theme.c
  if on and love.graphics and love.graphics.setBlendMode then
    love.graphics.setBlendMode("add"); Draw.setColor({ C.bloodL[1], C.bloodL[2], C.bloodL[3], 0.45 })
    love.graphics.circle("fill", cx, cy + 1, 5.5); love.graphics.setBlendMode("alpha"); Draw.reset()
  end
  Draw.setColor(on and C.blood or C.stone700)
  if love.graphics then
    love.graphics.polygon("fill", cx, cy - 6, cx - 4, cy + 1.5, cx + 4, cy + 1.5)
    love.graphics.circle("fill", cx, cy + 1.5, 4)
  end
  Draw.reset()
end

function Build:drawRunBanner(run)
  local C = Theme.c
  local H = BANNER_H
  -- fond (dégradé chaud) + éclat haut + bordure bas iron.
  Panel.vgrad(0, 0, Draw.W, H, { 0x1d / 255, 0x17 / 255, 0x10 / 255, 1 }, { 0x12 / 255, 0x0d / 255, 0x08 / 255, 1 })
  Draw.setColor(C.brassS, 0.18); if love.graphics then love.graphics.rectangle("fill", 0, 0, Draw.W, 1) end; Draw.reset()
  Draw.rect(0, H - 1, Draw.W, 1, C.iron)

  local fL = Theme.label(8)    -- labels (Space Mono 8, sourds)
  local fBig = Theme.value(17) -- grandes valeurs (or/round)
  local fSm = Theme.value(12)  -- valeurs secondaires (slots /9, streak)
  local labelY, midY, pad = 8, 33, 16

  -- valeurs lisibles.
  local goldStr, roundStr, slotsStr = tostring(run.gold), tostring(run.round), tostring(run.slots)
  local winStr = run.wins .. "/" .. Run.WIN_TARGET
  local streakWin = (run.winStreak or 0) >= 1
  local streakLoss = (run.lossStreak or 0) >= 1
  -- série courante : WIN×n (sang) / LOSS×n (sourd) / « — » si aucune série (départ de run, après reset).
  local streakStr = streakWin and T("ui.streak_win", { n = run.winStreak })
    or (streakLoss and T("ui.streak_loss", { n = run.lossStreak }) or "—")
  local tierStr = run.shopTier .. "/" .. Run.MAX_TIER
  local relCount = (run.relics and #run.relics) or 0
  local relRowW = (relCount + 1) * RELIC_B_CELL - (RELIC_B_CELL - RELIC_B_S)

  -- DESSIN d'un segment dans [sx .. sx+w] (closure : capte fontes/valeurs/run).
  local function drawSeg(s, sx)
    local function label(str) Draw.text(str, sx + pad, labelY, C.ink4, fL) end
    if s.k == "relics" then
      label(T("ui.relics")); self:drawBannerRelics(run)
    elseif s.k == "gold" then
      label(T("ui.gold"))
      -- NUMBER-ROLL : on AFFICHE la valeur lissée (self.goldShown, posée en update) arrondie -> elle roule vers
      -- run.gold. Un PUNCH de scale (Juice "build.gold") autour du diamant+nombre à chaque changement. Le pivot
      -- du scale = le diamant (sx+pad+6, midY) -> le groupe « gonfle » depuis la pièce. La LARGEUR de segment est
      -- mesurée sur la VRAIE valeur (goldStr, plus haut) -> layout STABLE pendant que le nombre roule (pas de jitter).
      local shown = math.floor((self.goldShown or run.gold) + 0.5)
      local js = Juice.scale("build.gold")
      local pivx, pivy = sx + pad + 6, midY
      if love and love.graphics and love.graphics.push and js ~= 1 then
        love.graphics.push()
        love.graphics.translate(pivx, pivy); love.graphics.scale(js, js); love.graphics.translate(-pivx, -pivy)
        Badge.diamond(pivx, midY, 6, C.gold, C.iron, C.brassS)
        Draw.text(tostring(shown), sx + pad + 16, midY - fBig:getHeight() / 2, C.gold, fBig)
        love.graphics.pop()
      else
        Badge.diamond(pivx, midY, 6, C.gold, C.iron, C.brassS)
        Draw.text(tostring(shown), sx + pad + 16, midY - fBig:getHeight() / 2, C.gold, fBig)
      end
    elseif s.k == "lives" then
      Draw.text(T("ui.lives"), sx + pad, labelY, C.ink4, fL)
      Draw.text("  " .. run.lives .. "/" .. Run.START_LIVES, sx + pad + fL:getWidth(T("ui.lives")), labelY, C.ink3, fL)
      for k = 1, Run.START_LIVES do lifeDrop(sx + pad + 5 + (k - 1) * 12, midY, k <= run.lives) end
    elseif s.k == "descent" then
      Draw.text(T("ui.descent"), sx + pad, labelY, C.ink4, fL)
      local lw = fL:getWidth(T("ui.descent"))
      Draw.text(" " .. winStr, sx + pad + lw, labelY, C.gold, fL)
      Draw.text("  " .. T("ui.to_ascension"), sx + pad + lw + fL:getWidth(" " .. winStr), labelY, C.ink5, fL)
      local n, gap = Run.WIN_TARGET, 2
      local barW = s.w - pad * 2
      local pw = (barW - gap * (n - 1)) / n
      for k = 1, n do
        local px = sx + pad + (k - 1) * (pw + gap)
        if k <= run.wins then
          Panel.vgrad(px, midY - 4, pw, 8, { 0xca / 255, 0xa6 / 255, 0x4a / 255, 1 }, { 0x7a / 255, 0x5e / 255, 0x24 / 255, 1 })
        else
          Draw.rect(px, midY - 4, pw, 8, { 0x0a / 255, 0x08 / 255, 0x10 / 255, 1 }, C.stone700, 1)
        end
      end
    elseif s.k == "round" then
      label(T("ui.round")); Draw.text(roundStr, sx + pad, midY - fBig:getHeight() / 2, C.ink, fBig)
    elseif s.k == "slots" then
      label(T("ui.slots"))
      Draw.text(slotsStr, sx + pad, midY - fBig:getHeight() / 2, C.ink2, fBig)
      Draw.text("/" .. Run.MAX_SLOTS, sx + pad + fBig:getWidth(slotsStr), midY - fSm:getHeight() / 2 + 3, C.ink4, fSm)
    elseif s.k == "streak" then
      label(T("ui.streak"))
      Badge.diamond(sx + pad + 4, midY, 4, streakWin and C.blood or C.ink4, C.iron, C.bloodL)
      Draw.text(streakStr, sx + pad + 12, midY - fSm:getHeight() / 2,
        streakWin and C.bloodL or (streakLoss and C.ink3 or C.ink4), fSm)
    elseif s.k == "tier" then
      Draw.text(T("ui.tier_label") .. " " .. tierStr, sx + pad, labelY, C.ink4, fL)
      for k = 1, Run.MAX_TIER do
        local on = k <= run.shopTier
        Badge.diamond(sx + pad + 5 + (k - 1) * 12, midY, 4.5,
          on and C.gold or { 0x0a / 255, 0x08 / 255, 0x10 / 255, 1 }, on and C.brassD or C.brass, on and C.brassS or C.brass)
      end
    end
  end

  -- largeurs de segment (mesurées).
  local left = {
    { k = "relics",  w = pad + math.max(fL:getWidth(T("ui.relics")), relRowW) + 12 },
    { k = "gold",    w = pad + math.max(fL:getWidth(T("ui.gold")), 18 + fBig:getWidth(goldStr)) + pad },
    { k = "lives",   w = pad + math.max(fL:getWidth(T("ui.lives") .. "  9/9"), Run.START_LIVES * 12) + pad },
    { k = "descent", w = pad + math.max(fL:getWidth(T("ui.descent") .. " " .. winStr .. "  " .. T("ui.to_ascension")), 200) + pad },
  }
  local right = {
    { k = "round",  w = pad + math.max(fL:getWidth(T("ui.round")), fBig:getWidth(roundStr)) + pad },
    { k = "slots",  w = pad + math.max(fL:getWidth(T("ui.slots")), fBig:getWidth(slotsStr) + fSm:getWidth("/" .. Run.MAX_SLOTS)) + pad },
    { k = "streak", w = pad + math.max(fL:getWidth(T("ui.streak")), 12 + fSm:getWidth(streakStr)) + pad },
    { k = "tier",   w = pad + math.max(fL:getWidth(T("ui.tier_label") .. " " .. tierStr), Run.MAX_TIER * 12) + pad },
  }
  local systemReserve = 52

  -- cluster GAUCHE packé depuis x=0 (filets iron entre segments, pas après le dernier).
  local x = 0
  for i, s in ipairs(left) do
    drawSeg(s, x); x = x + s.w
    if i < #left then Draw.rect(x, 6, 1, H - 12, C.iron); x = x + 1 end
  end
  -- cluster DROITE aligné à droite (filets internes seulement).
  local rTot = #right - 1
  for _, s in ipairs(right) do rTot = rTot + s.w end
  local rx = Draw.W - systemReserve - rTot
  for i, s in ipairs(right) do
    drawSeg(s, rx); rx = rx + s.w
    if i < #right then Draw.rect(rx, 6, 1, H - 12, C.iron); rx = rx + 1 end
  end
  Draw.rect(Draw.W - systemReserve, 6, 1, H - 12, C.iron)
end

-- RELIQUES possédées dans le segment « RELICS » du bandeau : socle (dégradé brun + bord laiton, vif au survol)
-- + icône bakée centrée, aligné sur relicRowRect (= hit-test du survol). Emplacement vide « + » en queue.
function Build:drawBannerRelics(run)
  local C = Theme.c
  local hov = self:relicAt(self.mx, self.my)
  local n = (run.relics and #run.relics) or 0
  for i = 1, n do
    local r = self:relicRowRect(i)
    Panel.vgrad(r.x, r.y, r.w, r.h, { 0x1c / 255, 0x13 / 255, 0x0b / 255, 1 }, { 0x12 / 255, 0x0c / 255, 0x07 / 255, 1 })
    Draw.rect(r.x, r.y, r.w, r.h, nil, (hov == i) and C.brassL or C.brass, 1)
    local baked = RelicGen.cached(run.relics[i].id, self.palette)
    if baked and baked.image and love.graphics then
      local iw = baked.image:getWidth()
      local sc = (r.w - 8) / iw
      love.graphics.setColor(1, 1, 1, 1)
      love.graphics.draw(baked.image, r.x + r.w / 2 - iw * sc / 2, r.y + r.h / 2 - iw * sc / 2, 0, sc, sc)
    end
  end
  local e = self:relicRowRect(n + 1)
  Draw.rect(e.x, e.y, e.w, e.h, { 0x0c / 255, 0x09 / 255, 0x12 / 255, 1 }, C.ink5, 1)
  Draw.textC("+", e.x + e.w / 2, e.y + e.h / 2 - 6, C.ink5, Theme.label(11))
  Draw.reset()
end

-- Glyphe schématique d'un sigil (forme), centré (cx,cy), rayon r, couleur col. Sert à la pastille de la
-- barre sigil ET aux boutons de forme.
function Build:drawSigilGlyph(name, cx, cy, r, col)
  if not love.graphics then return end
  Draw.setColor(col); love.graphics.setLineWidth(1.5)
  if name == "anneau" then love.graphics.circle("line", cx, cy, r)
  elseif name == "carre" then love.graphics.rectangle("line", cx - r, cy - r, r * 2, r * 2)
  elseif name == "diamant" then love.graphics.polygon("line", cx, cy - r, cx + r, cy, cx, cy + r, cx - r, cy)
  elseif name == "croix" then
    love.graphics.rectangle("fill", cx - 1.5, cy - r, 3, r * 2); love.graphics.rectangle("fill", cx - r, cy - 1.5, r * 2, 3)
  elseif name == "ligne" then love.graphics.rectangle("fill", cx - r, cy - 1.5, r * 2, 3)
  else love.graphics.circle("line", cx, cy, r) end
  love.graphics.setLineWidth(1); Draw.reset()
end

-- Rect (DESIGN) du k-ième bouton de forme (cluster aligné à droite de la barre sigil).
function Build:shapeBtnRect(k)
  local n = #Shapes.order
  local bs, gap = 25, 4
  local clusterW = n * bs + (n - 1) * gap
  local x1 = Draw.W - 22 - clusterW
  local y = BANNER_H + math.floor((SIGIL_H - bs) / 2)
  return { x = x1 + (k - 1) * (bs + gap), y = y, w = bs, h = bs }
end

-- Bouton de forme sous le curseur (souris VIRTUELLE -> design ×4), ou nil.
function Build:shapeBtnAt(vx, vy)
  local dx, dy = vx * 4, vy * 4
  for k = 1, #Shapes.order do
    local r = self:shapeBtnRect(k)
    if dx >= r.x and dx <= r.x + r.w and dy >= r.y and dy <= r.y + r.h then return k end
  end
  return nil
end

-- ── BARRE SIGIL/ARCHÉTYPE (refonte « Build Screen ») : pastille de forme + nom (Cinzel) + flavor (Spectral
-- it.) + badge archétype (laiton) à GAUCHE ; « [S] RESHAPE » + boutons de forme cliquables à DROITE. ──
function Build:drawSigilBar()
  local C, b = Theme.c, self.board
  local y0, H = BANNER_H, SIGIL_H
  Panel.vgrad(0, y0, Draw.W, H, { 0x16 / 255, 0x12 / 255, 0x1d / 255, 1 }, { 0x0b / 255, 0x09 / 255, 0x10 / 255, 1 })
  Draw.rect(0, y0 + H - 1, Draw.W, 1, C.iron)
  local nm = b.shape.name
  local midY = y0 + math.floor(H / 2)
  local x = 22
  -- pastille du sigil : lueur sang + glyphe.
  if love.graphics and love.graphics.setBlendMode then
    love.graphics.setBlendMode("add"); Draw.setColor({ C.blood[1], C.blood[2], C.blood[3], 0.3 })
    love.graphics.circle("fill", x + 7, midY, 11); love.graphics.setBlendMode("alpha"); Draw.reset()
  end
  self:drawSigilGlyph(nm, x + 7, midY, 7, C.bloodL)
  x = x + 15 + 11
  local fName = Theme.heading(16)
  local nameStr = T("shape." .. nm .. ".label"):upper()
  Draw.text(nameStr, x, midY - fName:getHeight() / 2, C.ink, fName)
  x = x + fName:getWidth(nameStr) + 11
  local fFlav = Theme.flavor(14)
  local flavStr = "— " .. T("shape." .. nm .. ".flavor")
  Draw.text(flavStr, x, midY - fFlav:getHeight() / 2, C.ink3, fFlav)
  x = x + fFlav:getWidth(flavStr) + 14
  local fA = Theme.label(8)
  local aStr = T("ui.archetype") .. " · " .. T("shape." .. nm .. ".archetype"):upper()
  local aw = fA:getWidth(aStr) + 16
  Draw.rect(x, midY - 9, aw, 18, nil, C.brassD, 1)
  Draw.text(aStr, x + 8, midY - fA:getHeight() / 2, C.gold, fA)
  -- DROITE : « [S] RESHAPE » + boutons de forme (MASQUÉS en inspection figée : la forme est verrouillée).
  if not self.locked then
    local r1 = self:shapeBtnRect(1)
    local fR = Theme.label(9)
    Draw.textR(T("ui.reshape_label"), r1.x - 10, midY - fR:getHeight() / 2, C.ink4, fR)
    local hotK = self:shapeBtnAt(self.mx, self.my)
    for k, sname in ipairs(Shapes.order) do
      local r = self:shapeBtnRect(k)
      local active = (sname == nm)
      if active then
        Panel.vgrad(r.x, r.y, r.w, r.h, { 0x1a / 255, 0x0e / 255, 0x10 / 255, 1 }, { 0x12 / 255, 0x0a / 255, 0x0c / 255, 1 })
        Draw.rect(r.x, r.y, r.w, r.h, nil, C.blood, 1)
      else
        Draw.rect(r.x, r.y, r.w, r.h, { 0x10 / 255, 0x0b / 255, 0x16 / 255, 1 }, (hotK == k) and C.brass or C.iron, 1)
      end
      self:drawSigilGlyph(sname, r.x + r.w / 2, r.y + r.h / 2, 5.5, active and C.bloodL or ((hotK == k) and C.ink2 or C.ink4))
    end
  else
    -- inspection : on indique juste « FIGHT to watch » à droite de la barre sigil.
    local fR = Theme.label(9)
    Draw.textR(T("ui.inspect_hint"), Draw.W - 22, midY - fR:getHeight() / 2, C.ink4, fR)
  end
end

-- MODULE DE VIE (extrême gauche de la barre du bas) : [ libellé « LIVES n/5 » | GLOBE DE VIE « à la Diablo » ].
-- Le globe (Gauge.lifeOrb) = verre + liquide sang dont le niveau = vies/5 + un POISSON qui nage dedans + anneau
-- de laiton (retour user 2026-06 : retour de l'ancien orbe à nageur). La barre d'XP/tier a quitté ce module pour
-- une longue barre SOUS les monstres (drawShopXpBar) -> la colonne respire et le globe REMPLIT sa boîte.
function Build:drawLifeOrb(run)
  local c = Theme.c
  local box = self.lay.lifeOrbBox
  local lab = self.lay.lifeLabel
  local maxL = Run.START_LIVES
  -- LIBELLÉ « LIVES n/5 » (Space Mono) centré au-dessus du globe. Sang si vies basses.
  local low = run.lives <= 1
  Draw.textC(T("ui.lives_orb", { n = run.lives, max = maxL }), lab.x + lab.w / 2, lab.y + 1,
    low and c.blood or c.gold, Theme.label(11))
  -- GLOBE DE VIE « nightmare-forge » (= D2 « Resource orb » du handoff designer) : rendu PIXEL NET (canvas
  -- basse-réso ×4) + liquide sang (niveau = vies/5) + NAGEUR serpent qui traverse + anneau de laiton, le tout
  -- passé par un SHADER cosmardesque (gauchissement d'UV + dérive chromatique + halo violet qui respire).
  LifeOrb.draw(box.x, box.y, box.w, box.h, run.lives, maxL, self.t / 60)
end

-- BARRE XP (handoff « Build Screen », au pied de la colonne THE OFFERING) : « XP cur/next » à gauche + une
-- barre de progression DANS le tier courant + « → TIER n » à droite (ou « MAX »). Le TIER courant (n/5) vit
-- désormais dans le bandeau du haut (5 losanges) -> ici on ne montre QUE la montée vers le tier SUIVANT (plus
-- de doublon). Survol -> infobulle des cotes par rang (drawOddsTooltip, hit-test self.xpBarRect). Golden neutre.
function Build:drawShopXpBar(run)
  local c = Theme.c
  local box = self.lay.tierRail
  if not box then return end
  local atMax = run.shopTier >= Run.MAX_TIER
  local hot = self.xpBarRect and inRect(self.mx, self.my, self.xpBarRect)
  local capFont = Theme.label(9)
  local cy = box.y + math.floor(box.h / 2)
  local ty = cy - math.floor(capFont:getHeight() / 2)
  -- gauche : « XP cur/next » (XP sourd, valeur or) ; « MAX » au plafond.
  local toNext = run:xpToNext()
  local within = atMax and 1 or (toNext and toNext > 0 and math.min(1, run.shopXp / toNext) or 0)
  local pre = T("ui.xp_label") .. " "
  local num = atMax and T("ui.tier_max") or (run.shopXp .. "/" .. (toNext or 0))
  Draw.text(pre, box.x, ty, c.fainter, capFont)
  Draw.text(num, box.x + capFont:getWidth(pre), ty, c.gold, capFont)
  local leftW = capFont:getWidth(pre .. num)
  -- droite : « ► TIER n » (triangle en primitive -> indépendant des glyphes de police ; rien au max).
  local rightStr = atMax and "" or T("ui.to_tier", { n = run.shopTier + 1 })
  local rightW = 0
  if rightStr ~= "" then
    local txw = capFont:getWidth(rightStr)
    Draw.textR(rightStr, box.x + box.w, ty, c.fainter, capFont)
    local tcx = box.x + box.w - txw - 8
    Draw.setColor(c.fainter)
    if love.graphics and love.graphics.polygon then love.graphics.polygon("fill", tcx, cy - 3, tcx + 5, cy, tcx, cy + 3) end
    Draw.reset()
    rightW = txw + 14
  end
  -- barre : entre le libellé gauche et le libellé droit.
  local barX = box.x + leftW + 12
  local barW = (box.x + box.w) - barX - ((rightW > 0) and (rightW + 12) or 0)
  local barH, barY = 7, cy - 3
  if barW > 20 then
    Draw.rect(barX, barY, barW, barH, { 0x0a / 255, 0x08 / 255, 0x10 / 255, 1 }, c.iron, 1)
    local fillW = math.floor((barW - 2) * within)
    if fillW > 0 then
      Panel.vgrad(barX + 1, barY + 1, fillW, barH - 2, { 0xca / 255, 0xa6 / 255, 0x4a / 255, 1 }, { 0x7a / 255, 0x5e / 255, 0x24 / 255, 1 })
    end
    if hot then Draw.rect(barX, barY, barW, barH, nil, c.brass, 1) end
  end
end

-- EN-TÊTE de la colonne THE OFFERING (handoff) : « THE OFFERING » (Space Mono, gauche) + filet + saveur
-- (« dregs of the first terrace », Spectral italique, droite). Render-only -> golden neutre.
function Build:drawOfferingHeader()
  local c = Theme.c
  local box = self.lay.offerHeader
  if not box then return end
  local cy = box.y + math.floor(box.h / 2)
  local f = Theme.label(9)
  local title = T("ui.offering")
  Draw.text(title, box.x, cy - math.floor(f:getHeight() / 2), c.faint, f)
  local ff = Theme.flavor(11)
  -- saveur TIER-AWARE : descendre dans le Puits change la terrasse (1re terrasse -> abysse).
  local tier = math.max(1, math.min(Run.MAX_TIER, (self.host.run and self.host.run.shopTier) or 1))
  local flav = T("ui.terrace_" .. tier)
  local fw = ff:getWidth(flav)
  Draw.text(flav, box.x + box.w - fw, cy - math.floor(ff:getHeight() / 2), c.fainter, ff)
  local dx1, dx2 = box.x + f:getWidth(title) + 10, box.x + box.w - fw - 10
  if dx2 > dx1 then Draw.rect(dx1, cy, dx2 - dx1, 1, c.iron) end
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

-- ── CHIPS D'AURA (refonte « Build Screen ») : pastille chiffrée posée sur une arête d'aura. Icône d'affliction
-- (Keywords) + valeur ; bord = couleur du type d'aura + lueur additive. Le bouclier (hors registre afflictions)
-- -> petit écusson primitif. PUR-RENDER (golden neutre). ──
-- Chip d'aura sur le BOARD : pastille COMPACTE (valeur seule, texte centré, bord coloré par type) -> tient
-- dans le gap entre deux cases avec la ligne visible de chaque côté. L'ICÔNE d'affliction n'y est PAS (le type
-- est déjà porté par la COULEUR de l'arête + du bord + de la lueur) ; elle vit dans le readout de la fiche.
function Build:drawAuraChip(cx, cy, kind, label)
  local col = self:auraColor(kind)
  local f = Theme.value(10)
  local tw = (f and f:getWidth(label)) or (#label * 6)
  local padX, h = 5, 15
  local w = padX * 2 + tw
  local x, y = math.floor(cx - w / 2), math.floor(cy - h / 2)
  if love.graphics and love.graphics.setBlendMode then
    love.graphics.setBlendMode("add"); Draw.setColor({ col[1], col[2], col[3], 0.18 })
    love.graphics.rectangle("fill", x - 1, y - 1, w + 2, h + 2); love.graphics.setBlendMode("alpha"); Draw.reset()
  end
  Draw.rect(x, y, w, h, { 0x0c / 255, 0x09 / 255, 0x12 / 255, 0.96 }, col, 1)
  local bright = { math.min(1, col[1] * 1.25 + 0.25), math.min(1, col[2] * 1.25 + 0.25), math.min(1, col[3] * 1.25 + 0.25), 1 }
  Draw.textC(label, math.floor(cx), cy - (f and f:getHeight() / 2 or 5), bright, f)
  Draw.reset()
end

-- Pose un chip sur CHAQUE lien d'aura, CENTRÉ au MILIEU EXACT de l'arête (équidistant des deux cases, en H
-- comme en V) -> jamais plus sur une case que l'autre, la ligne reste visible de part et d'autre. Cas
-- BIDIRECTIONNEL (2 liens sur la même arête, ex. bouclier<->bouclier) : chacun légèrement vers SA source.
function Build:drawAuraChips(ui)
  if not (ui and ui.auraLinks and ui.networkInspect) then return end
  local function linkKey(a, b)
    local sa, sb = tostring(a), tostring(b)
    if sa < sb then return sa .. ">" .. sb end
    return sb .. ">" .. sa
  end
  local count = {}
  for _, lk in ipairs(ui.auraLinks) do
    local a, b = lk.from, lk.to
    if a ~= b then
      local k = linkKey(a, b)
      count[k] = (count[k] or 0) + 1
    end
  end
  for _, lk in ipairs(ui.auraLinks) do
    if self:auraLinkActive(lk, ui) then
      local pf, pt = self:auraPoint(lk.from), self:auraPoint(lk.to)
      if pf and pt and (pf.x ~= pt.x or pf.y ~= pt.y) then
        local a, b = lk.from, lk.to
        local t = ((count[linkKey(a, b)] or 0) >= 2) and 0.37 or 0.5
        local mx, my = (pf.x + (pt.x - pf.x) * t) * 4, (pf.y + (pt.y - pf.y) * t) * 4
        local dx, dy = (pt.x - pf.x), (pt.y - pf.y)
        local len = math.sqrt(dx * dx + dy * dy)
        if len > 0 then
          local px, py = -dy / len, dx / len
          mx, my = mx + px * 14, my + py * 14
        end
        mx = math.max(28, math.min(Draw.W - 28, mx))
        my = math.max(TOPCHROME_H + 12, math.min(BAR.y * 4 - 12, my))
        self:drawAuraChip(mx, my, lk.kind, lk.valueText or auraValueText(lk.kind, lk.label))
      end
    end
  end
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
function Build:drawDescLine(line, x, y, font, baseCol, aff, maxW, activeTags)
  return MonsterCard.drawDescLine(line, x, y, font, baseCol, aff, maxW, activeTags)
end

-- Infobulle d'unité (survol plateau / boutique) : la FICHE de monstre, ancrée au curseur. On passe le rig
-- d'APERÇU (animé) pour que le portrait respire à l'identique de l'ancienne carte ; bake/bounds via MiniRig.
-- boardSlot (optionnel) : si l'unité est POSÉE, on attache sous la fiche l'inspecteur d'adjacence (AURAS +
-- EXPOSURE) — l'inspecteur du design, mais ANCRÉ AU CURSEUR (décision user : pas de panneau fixe à droite).
function Build:drawTooltip(id, boardSlot, opts)
  opts = opts or {}
  local occ = opts.occ or (boardSlot and self.slotRigs[boardSlot]) or nil
  local level = opts.level or (occ and occ.level) or 1
  local unit = opts.unit or UnitResolver.unitForLevel(id, level)
  local tagOpts = opts.tagOpts or (opts.context and { context = opts.context }) or nil
  local networkHint = opts.networkHint
  if networkHint == nil then networkHint = boardSlot ~= nil or opts.context == "commander" end
  local box = MonsterCard.draw(self.view, self.palette, id, self.mx * 4, self.my * 4, self.t / 60,
    { rig = self.previewRigs[id], keywordHint = true, networkHint = networkHint, tagOpts = tagOpts, unit = unit, level = level })
  local sidecar
  if box and boardSlot and self.slotRigs[boardSlot] then
    sidecar = self:drawBoardInspectorExtra(box, boardSlot)
  end
  local showKeywords = opts.showKeywords or self.forceKeywordGlossary
    or (love and love.keyboard and love.keyboard.isDown and love.keyboard.isDown("lshift", "rshift"))
  if box and showKeywords then
    CardGlossary.drawMonster(self.view, InfluencePanel.union(box, sidecar), id, self.t / 60,
      { showKeywords = true, scroll = self.tagGlossaryScroll or 0, tagOpts = tagOpts, unit = unit })
  end
end

function Build:slotMatchesRelicTarget(slot, target)
  local sr = self.slotRigs[slot]
  if not sr then return false end
  target = target or "team"
  if target == "team" then return true end
  if target == "role:front" then return self:resolveRoleSlot("front") == slot end
  if target == "role:back" then return self:resolveRoleSlot("back") == slot end
  if target == "role:center" then return self:resolveRoleSlot("center") == slot end
  if type(target) == "string" and target:sub(1, 5) == "type:" then
    return Units[sr.id] and Units[sr.id].type == target:sub(6)
  end
  if target == "ahead" or target == "behind" or target == "above" or target == "below" then
    local cells = self.board.shape.cells
    local byKey = {}
    for i = 1, 9 do
      if self.slotRigs[i] then
        local c = cells[i]
        byKey[c.x .. ":" .. c.y] = i
      end
    end
    local dc = (target == "ahead" and 1) or (target == "behind" and -1) or 0
    local dr = (target == "below" and 1) or (target == "above" and -1) or 0
    for i = 1, 9 do
      if self.slotRigs[i] then
        local c = cells[i]
        if byKey[(c.x + dc) .. ":" .. (c.y + dr)] == slot then return true end
      end
    end
  end
  return false
end

function Build:relicAuraRowsForSlot(slot)
  local run = self.host and self.host.run
  if not (run and run.relics and self.slotRigs[slot]) then return {} end
  local sr = self.slotRigs[slot]
  local rows = {}
  local placed = self:placedCount()
  local function add(id, kind, value)
    if kind and value then
      rows[#rows + 1] = {
        kind = kind,
        text = T("ui.aura_takes", { name = auraUpperAscii(T("relic." .. id .. ".name")) }),
        value = value,
        valueText = auraValueText(kind, value),
        sourceKind = "relic",
        sourceId = id,
      }
    end
  end
  local function addIfTarget(id, target, kind, value)
    if self:slotMatchesRelicTarget(slot, target) then add(id, kind, value) end
  end
  for _, rr in ipairs(run.relics) do
    local id = rr.id or rr
    local relic = RelicsData[id]
    local p = relic and (relic.params or {})
    if relic and relic.op == "relic_aura_stat" then
      if self:slotMatchesRelicTarget(slot, p.target or "team") then
        local kind, label = statAuraVisual(p.stat, p.value or 0, sr.id, sr.level or 1)
        add(id, kind, label)
      end
    elseif relic and relic.op == "relic_affliction_inc" then
      local kind = p.family
      local addDps = kind and math.floor(baseAfflDps(sr.id, kind, sr.level or 1) * (p.inc or 0) + 0.5) or 0
      if addDps > 0 then add(id, kind, "+" .. addDps) end
    elseif relic and relic.op == "relic_more_dmg" then
      add(id, "empower", auraPercent(p.mult or 0, true))
    elseif relic and relic.op == "relic_flat_hp" then
      add(id, "growth", auraAdd(p.value or 0))
    elseif relic and relic.op == "relic_dmg_reduce" then
      add(id, "guard", "-" .. math.floor((p.frac or 0) * 100 + 0.5) .. "%")
    elseif relic and relic.op == "relic_haste" then
      add(id, "haste", auraPercent(p.value or 0, true))
    elseif relic and relic.op == "relic_few_units" and placed <= (p.max or 3) then
      add(id, "growth", auraPercent(math.max(p.dmgInc or 0, p.hpInc or 0), true))
    elseif relic and relic.op == "relic_rainbow" then
      add(id, "growth", "TYPE")
    elseif relic and relic.op == "relic_second_breath" then
      add(id, "guard", "1 HP")
    elseif relic and relic.op == "relic_amplify_auras" then
      addIfTarget(id, p.target or "team", "mimicry", auraPercent(p.frac or 0, true))
    end
  end
  return rows
end

-- ── INSPECTEUR DE BOARD (refonte « Build Screen ») : sous la fiche d'une unité POSÉE, un panneau
-- AURAS (« qui je buffe / qui me buffe », chiffré + icône, lu des liens d'aura) + EXPOSURE (rang
-- d'exposition au ciblage de colonne, dérivé de la forme). Ancré à la fiche (cardBox) : dessous si la
-- place le permet, sinon dessus. PUR-RENDER (golden neutre). ──
function Build:influenceDataForSlot(slot)
  local links = (self.uiState and self.uiState.auraLinks) or {}
  local gives, receives, position = {}, {}, {}
  for _, lk in ipairs(links) do
    if lk.from == slot and self.slotRigs[lk.to] then
      gives[#gives + 1] = {
        kind = lk.kind,
        value = lk.label,
        valueText = lk.valueText or auraValueText(lk.kind, lk.label),
        source = T("ui.influence_to", { name = self:auraTargetName(lk.to) }),
        detail = T("ui.influence_direct_link"),
        badge = T("ui.influence_aura"),
      }
    end
  end
  for _, lk in ipairs(links) do
    if lk.to == slot and lk.from ~= slot then
      receives[#receives + 1] = {
        kind = lk.kind,
        value = lk.label,
        valueText = lk.valueText or auraValueText(lk.kind, lk.label),
        source = T("ui.influence_from", { name = self:auraSourceName(lk) }),
        detail = (lk.sourceKind == "commander") and T("ui.influence_commander_source") or T("ui.influence_direct_link"),
        badge = (lk.sourceKind == "commander") and T("ui.influence_commander") or T("ui.influence_aura"),
      }
    end
  end
  for _, r in ipairs(self:relicAuraRowsForSlot(slot)) do
    receives[#receives + 1] = {
      kind = r.kind,
      value = r.value,
      valueText = r.valueText or auraValueText(r.kind, r.value),
      source = T("ui.influence_from", { name = self:auraSourceName({ sourceKind = "relic", sourceId = r.sourceId }) }),
      detail = T("ui.influence_relic_source"),
      badge = T("ui.influence_relic"),
    }
  end

  local cell = self.board.shape.cells[slot]
  local minC, maxC = math.huge, -math.huge
  for i = 1, 9 do
    if self.slotRigs[i] then
      local cc = self.board.shape.cells[i]
      if cc.x < minC then minC = cc.x end
      if cc.x > maxC then maxC = cc.x end
    end
  end
  local expoFrac = cell and (1 - (maxC - cell.x) / math.max(1, maxC - minC)) or 0
  local expoLab = (expoFrac >= 0.66) and T("ui.expo_front") or ((expoFrac >= 0.33) and T("ui.expo_mid") or T("ui.expo_back"))
  position[#position + 1] = {
    kind = "state",
    valueText = T("ui.exposure"),
    source = T("ui.influence_position", { name = expoLab }),
    detail = T("ui.influence_links_summary", { out = #gives, inc = #receives }),
    badge = T("ui.influence_position_badge"),
  }

  local sr = self.slotRigs[slot]
  return {
    title = T("ui.influence_title"),
    subtitle = sr and T("unit." .. sr.id .. ".name") or nil,
    sections = {
      { title = T("ui.influence_receives"), rows = receives },
      { title = T("ui.influence_gives"), rows = gives },
      { title = T("ui.influence_position_title"), rows = position },
    },
  }
end

function Build:drawBoardInspectorExtra(cardBox, slot)
  self.influenceScroll = self.influenceScroll or {}
  local box = InfluencePanel.draw(self.view, cardBox, self:influenceDataForSlot(slot),
    { scroll = self.influenceScroll[slot] or 0 })
  if box then self.influenceScroll[slot] = box.scroll or 0 end
  return box
end

-- Infobulle de relique (survol de la rangée) = Panel propre (même langage que src/scenes/relicpick.lua) :
-- dégradé + liseré d'accent de famille + gem (Badge.diamond) + nom (Cinzel) + effet clair (or) + flavor (Spectral).
-- Suit le curseur, rebond sur les bords. PUR-RENDER (golden inchangé).
-- Pop-up de survol d'une relique du HUD : la MÊME carte qu'au Grimoire / choix (RelicCard), avec l'ICÔNE
-- ANIMÉE (id + t en secondes) en cœur d'écrin. Placement au curseur + rebond sur les bords (calque exact
-- de grimoire:drawHoverCard). Hauteur MESURÉE -> aucun texte ne déborde. (Remplace l'ancienne tooltip
-- main-roulée -> on lit la relique du bandeau exactement comme partout ailleurs : zéro doublon de DA.)
function Build:drawRelicTooltip(id)
  local opts = {
    state = "identified",
    name = T("relic." .. id .. ".name"),
    effect = table.concat(MechanicsText.relicLines(id), "\n"),
    flavor = T("relic." .. id .. ".flavor"),
    fam = RELIC_TYPE[id] or "bone",
    band = RelicsData[id] and RelicsData[id].band,
    id = id, t = self.t / 60,
  }
  local W = 300
  local h = RelicCard.measure(W, opts)
  local x, y = self.mx * 4 + 18, self.my * 4 + 10
  if x + W > Draw.W then x = self.mx * 4 - W - 18 end
  if x < 4 then x = 4 end
  if y + h > Draw.H then y = Draw.H - h - 6 end
  if y < 4 then y = 4 end
  local cardBox = { x = math.floor(x), y = math.floor(y), w = W, h = h }
  RelicCard.draw(cardBox.x, cardBox.y, W, h, opts)
  CardGlossary.drawRelic(self.view, cardBox, id, self.t / 60,
    { scroll = self.tagGlossaryScroll or 0 })
end

return Build
