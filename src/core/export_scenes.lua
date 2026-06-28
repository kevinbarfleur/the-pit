-- src/core/export_scenes.lua
-- FABRIQUES DE SCÈNES pour les captures (--shoot=<name>). DEV / RENDER pur — chargé UNIQUEMENT par la
-- branche dev-gated de main.lua (jamais en headless, jamais par la SIM).
--
-- Chaque fabrique reproduit le câblage de main.lua/host + tests/headless.lua mais sous un VRAI `love`
-- (pixels réellement rasterisés). Pour build/combat on monte un RunState seedé + un plateau peuplé (mêmes
-- gestes que headless) afin que la capture montre un écran « tel que joué », pas un écran vide.
--
-- Convention : fabrique(host) -> scène prête à update/draw. `host` est le host minimal fourni par Export.shoot.

local Palette  = require("src.core.palette")
local RunState = require("src.run.state")
local RunEvents = require("src.data.run_events")
local OppGen   = require("src.data.oppgen") -- A4 : adversaire généré scalé (capture combat)

local Build     = require("src.scenes.build")
local Combat    = require("src.scenes.combat")
local Runover   = require("src.scenes.runover")
local Relicpick = require("src.scenes.relicpick")
local Menu      = require("src.scenes.menu")
local Gallery   = require("src.scenes.gallery")
local GrimoireS = require("src.scenes.grimoire")
local SystemMenu = require("src.ui.system_menu")
local Draw      = require("src.ui.draw")
local MonsterCard = require("src.render.monstercard")
local CardGlossary = require("src.ui.card_glossary")
local RelicCard = require("src.ui.relic_card")
local MechanicsText = require("src.ui.mechanics_text")
local I18n = require("src.core.i18n")

local VW, VH = 320, 180
local SEED = 13 -- seed FIXE -> capture reproductible (même build/boutique/adversaire à chaque export)

-- Monte une scène BUILD jouable : run seedé + 3 unités posées au centre (comme headless). Renvoie aussi le run.
local function makeBuild(host)
  host.run = RunState.new(SEED)
  local b = Build.new(Palette, VW, VH, host)
  b.board:setShape("carre"); b:computeLayout(); b.board:unlock(9)
  b:placeId(5, "templar") -- rempart central (shield_aura -> buffe ses voisins) : arêtes/chips d'aura visibles
  b:placeId(4, "marauder")
  b:placeId(6, "skeleton")
  -- BANC (réserve, 4 slots) peuplé pour la capture : une PAIRE (witch×2, pré-fusion lisible) + 2 variés.
  for i, id in ipairs({ "witch", "witch", "demon", "spore_tick" }) do
    b.bench[i] = { id = id, level = 1, char = b:newRig(id) }
  end
  if b.syncSlots then b:syncSlots() end
  host.build = b
  return b
end

-- C4 — BUILD avec PIÉDESTAL pour juger le rendu du commandant (états vide/rempli/offre/survol portée). `mode`
-- pilote l'état du socle ; `hoverPed`/`hoverUnit` simulent un survol (curseur posé) ; `dragNonChief` simule un
-- drag de refus. Réutilise makeBuild (board peuplé) -> on voit le board ET le socle dans la même capture.
local function makeCommanderBuild(host, mode, opts)
  opts = opts or {}
  local b = makeBuild(host)
  local run = host.run
  if mode == "offer" then
    run.pendingCommanderGrant = true -- offre en attente (socle pulse en or, CTA « clique pour accepter »)
  else
    run.commanderUnlocked = true     -- piédestal débloqué (vide ou rempli)
    if mode == "filled" or mode == "hover" then
      -- galvanizer (Le Roi des Rats : commandBonus tier:1) -> sa portée éclaire les unités RANG-1 du board.
      b.commanderSlot = { id = "galvanizer", level = 1, char = b:newRig("galvanizer") }
    end
  end
  -- survol simulé : pose le curseur sur la NICHE (commanderRect, VIRTUEL). Le warm-up animera la pulsation.
  if mode == "hover" or mode == "offer" then
    local r = b.commanderRect
    b.mx, b.my = r.x + r.w / 2, r.y + r.h / 2
  end
  if opts.dragNonChief then
    -- drag d'un NON-chef survolant la case -> refus visuel (liseré sang + voile + shake). Depuis le rollout
    -- « commandement à tout le roster », PLUS AUCUNE unité réelle n'est sans commandBonus -> on injecte un non-chef
    -- SYNTHÉTIQUE (comme tests/headless.lua) pour que la capture montre VRAIMENT l'état de refus (sinon canCommand
    -- renvoie true partout et on verrait un drop VALIDE/vert). L'id se rend via le fallback newRig (CreatureGen).
    local Units = require("src.data.units")
    Units.__noncmd_shot = { id = "__noncmd_shot", type = "bone", family = "mortvivant", rank = 1, hp = 40, dmg = 6, cd = 44, effects = {} } -- SANS commandBonus
    b.drag = { id = "__noncmd_shot", level = 1, char = b:newRig("__noncmd_shot") }
    local r = b.commanderRect
    b.mx, b.my = r.x + r.w / 2, r.y + r.h / 2
    b.drag.char.x, b.drag.char.y = b.mx, b.my
    -- cmdShake décroît de ~1/60 par tick de warm (20 ticks ≈ 0.33) -> on part HAUT pour que l'état de refus
    -- (liseré sang + voile) soit encore actif au moment du shot (sinon il serait déjà retombé à 0).
    b.cmdShake = 0.90
  end
  return b
end

local Builders = {}

-- MENU : écran titre (indépendant du run).
function Builders.menu(host)
  return Menu.new(Palette, VW, VH, host)
end

-- BUILD : plateau peuplé + boutique (run seedé).
function Builders.build(host)
  return makeBuild(host)
end

-- BUILD_FREEZE : variante de capture avec Frost Seal actif pour inspecter la pastille FRZ et l'état gelé.
function Builders.build_freeze(host)
  local b = makeBuild(host)
  host.run:grantRelic("frost_seal")
  host.run:freezeOffer(2)
  return b
end

-- C4 — captures dédiées du PIÉDESTAL (revue visuelle ui-artisan) : vide / rempli / survol portée / refus drag.
function Builders.commander_empty(host)  return makeCommanderBuild(host, "empty") end
function Builders.commander_filled(host) return makeCommanderBuild(host, "filled") end
function Builders.commander_hover(host)  return makeCommanderBuild(host, "hover") end
function Builders.commander_offer(host)  return makeCommanderBuild(host, "offer") end
function Builders.commander_refuse(host) return makeCommanderBuild(host, "empty", { dragNonChief = true }) end

function Builders.commander_spore_keywords(host)
  local b = makeBuild(host)
  host.run.commanderUnlocked = true
  b.commanderSlot = { id = "spore_tick", level = 1, char = b:newRig("spore_tick") }
  b.forceKeywordGlossary = true
  local r = b.commanderRect
  b.mx, b.my = r.x + r.w / 2, r.y + r.h / 2
  return b
end

local function monsterCardStress(id, opts)
  opts = opts or {}
  return {
    daChrome = true,
    t = 0,
    update = function(self, dt) self.t = (self.t or 0) + (dt or 0) / 60 end,
    drawBack = function() end,
    drawWorld = function() end,
    drawOverlay = function(self, view)
      Draw.begin(view)
      Draw.rect(0, 0, Draw.W, Draw.H, { 0.02, 0.012, 0.03, 1 })
      local box = MonsterCard.draw(view, Palette, id, 120, 24, self.t, { keywordHint = true })
      if opts.glossary then
        CardGlossary.drawMonster(view, box, id, self.t, { force = true, tagOpts = opts.tagOpts })
      end
      Draw.finish()
    end,
  }
end

function Builders.card_ember_sac(host) return monsterCardStress("venom_censer") end
function Builders.card_wither_bloom(host) return monsterCardStress("wither_bloom") end
function Builders.card_wither_bloom_glossary(host) return monsterCardStress("wither_bloom", { glossary = true }) end
function Builders.card_plague_pyre(host) return monsterCardStress("plague_pyre") end
function Builders.card_plague_pyre_glossary(host) return monsterCardStress("plague_pyre", { glossary = true }) end

local function relicCardStress(id, opts)
  opts = opts or {}
  return {
    daChrome = true,
    t = 0,
    update = function(self, dt) self.t = (self.t or 0) + (dt or 0) / 60 end,
    drawBack = function() end,
    drawWorld = function() end,
    drawOverlay = function(self, view)
      Draw.begin(view)
      Draw.rect(0, 0, Draw.W, Draw.H, { 0.02, 0.012, 0.03, 1 })
      local W = 300
      local rc = require("src.data.relics")[id]
      local cardOpts = {
        state = "identified",
        name = I18n.t("relic." .. id .. ".name"),
        effect = table.concat(MechanicsText.relicLines(id), "\n"),
        flavor = I18n.t("relic." .. id .. ".flavor"),
        band = rc and rc.band,
        id = id,
        t = self.t,
      }
      local h = RelicCard.measure(W, cardOpts)
      local box = { x = 120, y = 38, w = W, h = h }
      RelicCard.draw(box.x, box.y, box.w, box.h, cardOpts)
      if opts.glossary then CardGlossary.drawRelic(view, box, id, self.t, { force = true }) end
      Draw.finish()
    end,
  }
end

function Builders.card_relic_aegis(host) return relicCardStress("aegis") end
function Builders.card_relic_aegis_glossary(host) return relicCardStress("aegis", { glossary = true }) end

-- FICHE « At command » : survol d'une unité-chef du BOARD -> la fiche montre la ligne « AT COMMAND : <aura> ».
-- On pose un galvanizer (porte commandBonus) en case 4 et le curseur dessus.
function Builders.commander_fiche(host)
  local b = makeBuild(host)
  host.run.commanderUnlocked = true
  b:placeId(4, "galvanizer") -- chef sur le board -> sa fiche au survol porte « AT COMMAND »
  local p = b.pos[4]
  b.mx, b.my = p.x, p.y -- curseur sur la case 4
  return b
end

-- FICHE « Cannot command » : survol d'une unité SANS commandBonus -> la fiche montre « Cannot command » (grisé).
function Builders.commander_fiche_none(host)
  local b = makeBuild(host)
  host.run.commanderUnlocked = true
  local p = b.pos[5] -- templar (pas de commandBonus dans makeBuild) en case 5
  b.mx, b.my = p.x, p.y
  return b
end

-- COMBAT : on construit les compos gauche/droite depuis un build peuplé, puis on lance l'arène (seedée).
-- Quelques ticks de warm (gérés par Export.shoot) laissent la bataille s'engager visuellement.
function Builders.combat(host)
  local b = makeBuild(host)
  -- mi-partie pour montrer l'adversaire GÉNÉRÉ scalé (A4) : round 7, tier 3, 7 slots.
  host.run.round, host.run.shopTier, host.run.slots = 7, 3, 7
  local left = b:buildLeftComp()
  local enc = OppGen.generate({ round = host.run.round, tier = host.run.shopTier, slots = host.run.slots,
    rng = love.math.newRandomGenerator(7), odds = host.run.ODDS })
  local right = b:buildRightComp(enc)
  return Combat.new(Palette, VW, VH, host, { left = left, right = right, enemyKey = b:encounterKeyFor(#enc.units), seed = 7 })
end

-- C4 — COMBAT AVEC COMMANDANT (revue : le chef VISIBLE en retrait + AUCUNE barre de vie). Identique à
-- Builders.combat, mais on couronne un galvanizer côté JOUEUR avant le bake -> le commandant entre au comp
-- (isCommander/untargetable) et arena_draw le replace en VIRTUEL derrière la formation (commanderCombatPos).
function Builders.combat_commander(host)
  local b = makeBuild(host)
  host.run.round, host.run.shopTier, host.run.slots = 7, 3, 7
  host.run.commanderUnlocked = true
  b.commanderSlot = { id = "galvanizer", level = 1, char = b:newRig("galvanizer") } -- Le Roi des Rats : commandant
  local left = b:buildLeftComp()
  local enc = OppGen.generate({ round = host.run.round, tier = host.run.shopTier, slots = host.run.slots,
    rng = love.math.newRandomGenerator(7), odds = host.run.ODDS })
  local right = b:buildRightComp(enc)
  return Combat.new(Palette, VW, VH, host, { left = left, right = right, enemyKey = b:encounterKeyFor(#enc.units), seed = 7 })
end

-- COMBAT_REACT (B.1b) : prouve au SCREENSHOT le rendu combat MID-RÉACTION des créatures vivantes (critter)
-- ancrées dans l'arène (cartes/barres/ombres). On engage la bataille quelques ticks (placement réel), puis on
-- ÉPINGLE 3 unités vivantes en atk/hurt/death à leur PHASE de pic via renderer.anim[u] (age = ph×DUR), et on
-- GÈLE la scène (update -> no-op) pour que Export.shoot ne fasse plus avancer les phases ni re-commuter le bus.
local function makeCombatReact(host)
  local b = makeBuild(host)
  host.run.round, host.run.shopTier, host.run.slots = 7, 3, 7
  local left = b:buildLeftComp()
  local enc = OppGen.generate({ round = host.run.round, tier = host.run.shopTier, slots = host.run.slots,
    rng = love.math.newRandomGenerator(7), odds = host.run.ODDS })
  local right = b:buildRightComp(enc)
  local cs = Combat.new(Palette, VW, VH, host, { left = left, right = right,
    enemyKey = b:encounterKeyFor(#enc.units), seed = 7 })
  -- engage le combat un court instant (les unités s'animent / se font face), sans laisser personne mourir.
  for _ = 1, 18 do cs:update(1.0); if cs.arena.over then break end end
  -- ÉPINGLE des états réactifs sur les unités VIVANTES (tout le roster est généré -> Critter.has partout). On
  -- alterne atk(frappe)/hurt(recul)/death(désagrégation) à leur phase de PIC pour couvrir les 3 couches dans une
  -- même image, sur les DEUX camps (montre le miroir facing). atk en majorité (état le plus fréquent en combat).
  local Arena = require("src.render.arena_draw")
  local DUR = Arena.CR_DUR
  local cycle = { { st = "atk", ph = 0.42 }, { st = "hurt", ph = 0.10 }, { st = "atk", ph = 0.42 },
    { st = "death", ph = 0.5 } }
  local i = 0
  for _, u in ipairs(cs.arena.units) do
    if u.alive then
      i = i + 1
      local p = cycle[(i - 1) % #cycle + 1]
      cs.renderer.anim[u] = { state = p.st, age = p.ph * (DUR[p.st] or 60) }
    end
  end
  cs.update = function() end -- GEL : phases figées au pic pour la capture (RENDER-only ; jamais en jeu)
  return cs
end

-- COMBAT_REACT (B.1b) : capture du rendu combat avec 3 unités épinglées en atk/hurt/death (revue mid-réaction).
function Builders.combat_react(host)
  return makeCombatReact(host)
end

-- SUMMARY : combat joué JUSQU'À CONCLUSION (+ overAge dépassé) -> capture l'écran de RÉSUMÉ post-combat
-- (verdict + ruban de stats + DAMAGE BY CAUSE + THE LEDGER + actions). Réutilise le câblage de Builders.combat.
function Builders.summary(host)
  local b = makeBuild(host)
  host.run.round, host.run.shopTier, host.run.slots = 7, 3, 7
  local left = b:buildLeftComp()
  local enc = OppGen.generate({ round = host.run.round, tier = host.run.shopTier, slots = host.run.slots,
    rng = love.math.newRandomGenerator(7), odds = host.run.ODDS })
  local right = b:buildRightComp(enc)
  local cs = Combat.new(Palette, VW, VH, host, { left = left, right = right, enemyKey = b:encounterKeyFor(#enc.units), seed = 7 })
  for _ = 1, 6000 do cs:update(1.0); if cs.arena.over then break end end
  for _ = 1, 30 do cs:update(1.0) end -- dépasse overAge (>=20) -> l'écran de résumé s'affiche
  return cs
end

-- RELICPICK : offre 1-parmi-3 (run seedé -> choix déterministes). Les 3 cartes portent l'ICÔNE ANIMÉE
-- (RelicAnim via RelicCard) : le warm-up d'Export.shoot fait avancer t -> les icônes sont déformées au shot.
function Builders.relicpick(host)
  host.run = RunState.new(SEED)
  local choices = host.run:rollRelicChoices(3)
  -- capture le cas LEVEL-UP (midRound) : kicker doré « LEVEL-UP REWARD » -> montre la source de l'offre.
  return Relicpick.new(Palette, VW, VH, host, { choices = choices, midRound = true })
end

-- RUNEVENT : remplace le marchand post-combat par une rencontre thematique a rewards explicites.
function Builders.runevent(host)
  host.run = RunState.new(SEED)
  host.run.wins, host.run.losses = 2, 1
  local exclude = {}
  for _, id in ipairs(RunEvents.order) do if id ~= "hollow_carcass" then exclude[id] = true end end
  local event = host.run:rollRunEvent({ exclude = exclude })
  return Relicpick.new(Palette, VW, VH, host, { event = event })
end

-- BUILD_RELIC_HOVER : board peuplé + 3 reliques au HUD + curseur posé sur une miniature -> POP-UP de la
-- carte de relique ANIMÉE (RelicCard avec icône RelicAnim). Prouve au screenshot la pop-up de survol HUD.
-- On choisit 3 reliques de PALIERS variés (Argent/Or/Prismatique) pour montrer la couleur de carte, et on
-- survole la 2e (au centre de son socle, en VIRTUEL : relicAt teste mx*4/my*4 contre les rects design).
function Builders.build_relic_hover(host)
  local b = makeBuild(host)
  -- trois reliques de bandes différentes (low=bloodstone, mid=kings_bowl, high=splitting_maw) -> liserés variés.
  for _, id in ipairs({ "bloodstone", "kings_bowl", "splitting_maw" }) do host.run:grantRelic(id) end
  -- socle de la relique #2 (design) : RELIC_B_X0=16, RELIC_B_Y=23, pas 30, côté 24 -> centre ≈ (58, 35).
  -- curseur en VIRTUEL = design/4 (relicAt multiplie par 4) : (14.5, 8.75) tombe au centre du 2e socle.
  b.mx, b.my = 58 / 4, 35 / 4
  return b
end

local function makeSystemShot(host, mode)
  local b = makeBuild(host)
  host.name = "build"
  host.canResumeRun = function() return true end
  host.suspendToMenu = function() end
  host.abandonRun = function() end
  host.musicEnabled = true
  host.toggleMusic = function() host.musicEnabled = not host.musicEnabled; return host.musicEnabled end
  host.postfxReady = function() return true end
  host.postfxEnabled = function() return true end
  host.togglePostFx = function() return true end
  local ov = SystemMenu.new(host, { mode = mode or "pause" })
  host.overlay = ov
  return {
    daChrome = true, nativeWorld = b.nativeWorld,
    update = function(_, dt) ov:update(dt) end,
    drawBack = function(_, view) b:drawBack(view) end,
    drawWorld = function() b:drawWorld() end,
    drawOverlay = function(_, view) b:drawOverlay(view); ov:draw(view) end,
  }
end

function Builders.system(host) return makeSystemShot(host, "pause") end
function Builders.settings(host) return makeSystemShot(host, "settings") end

-- RUNOVER : écran de fin (ascension). On feed un run seedé + résultat.
function Builders.runover(host)
  host.run = RunState.new(SEED)
  return Runover.new(Palette, VW, VH, host, { result = "win", run = host.run })
end

-- GRIMOIRE : codex persistant en deux colonnes. Pour la capture : onglet BESTIAIRE, entrée de haut tier
-- sélectionnée, fiche fixe à droite au niveau III. Full-unlock DEV pour ne pas dépendre de la sauvegarde.
local function makePinnedGrimoire(host, opts)
  opts = opts or {}
  local Dev = require("src.core.dev")
  Dev._fullUnlock = true
  local s = GrimoireS.new(Palette, VW, VH, host)
  if s.refresh then s:refresh() end
  if s.setTab then s:setTab("bestiary") end -- onglet BESTIAIRE (là où se lit la RARETÉ par couleur de tier)
  if s.cells and #s.cells > 0 then
    local target, bestRank = nil, -1
    for i = 1, #s.cells do
      local c = s.cells[i]
      local _, cy = s:cellOrigin(i)
      local onscreen = cy >= s.gridTop and (cy + 92) <= 690 -- entièrement dans la fenêtre clippée
      if c.on and onscreen then
        local rk = (c.e and c.e.rank) or 0
        if rk >= bestRank then target, bestRank = i, rk end -- >= : préfère un index plus à droite/bas à rang égal
      end
    end
    target = target or 1
    local x, y = s:cellOrigin(target)
    s.hover = target
    s.mx, s.my = x + 138 / 2, y + 92 / 2 -- centre de la vignette (espace design)
    s:selectCell(target)
    s.selectedLevel = opts.level or 3
  end
  s.forceKeywordGlossary = opts.glossary == true
  return s
end

function Builders.grimoire(host) return makePinnedGrimoire(host) end
function Builders.grimoire_glossary(host) return makePinnedGrimoire(host, { glossary = true, level = 3 }) end

-- GRIMOIRE_RELICS : même codex, onglet RELIQUES -> grille d'ICÔNES ANIMÉES (RelicAnim) + fiche de relique
-- ANIMÉE au survol. Force le full-unlock (toutes révélées) pour juger TOUTES les icônes 40×40 dans la grille.
-- On pose le curseur sur une case relique révélée -> fiche RelicCard animée au curseur.
function Builders.grimoire_relics(host)
  local Dev = require("src.core.dev")
  Dev._fullUnlock = true -- read-time full-unlock (révèle toutes les reliques pour la revue visuelle)
  local s = GrimoireS.new(Palette, VW, VH, host)
  if s.setTab then s:setTab("relics") end
  if s.refresh then s:refresh() end
  -- survole la 1re case révélée (espace design) -> fiche relique animée au curseur.
  if s.cells and #s.cells > 0 then
    for i = 1, #s.cells do
      local c = s.cells[i]
      local _, cy = s:cellOrigin(i)
      if c.on and cy >= s.gridTop and (cy + 92) <= 690 then
        local x, y = s:cellOrigin(i)
        s.hover = i
        s.mx, s.my = x + 138 / 2, y + 92 / 2
        break
      end
    end
  end
  return s
end

-- GALLERY : revue visuelle de tout le roster (écran [g]).
function Builders.gallery(host)
  return Gallery.new(Palette, VW, VH, host)
end

-- ANIM SHEETS (B.1) : planches de contact des réactions sur critter.lua, figées à la phase de PIC. Servent à
-- juger AU SCREENSHOT chaque kind d'attaque/mort/dégât. Require paresseux (scène DEV, hors jeu/headless).
function Builders.anim_attack(host)
  local AnimSheet = require("src.scenes.animsheet")
  return AnimSheet.new(Palette, VW, VH, host, { mode = "attack", phase = 0.42 }) -- frappe au pic
end
function Builders.anim_death(host)
  local AnimSheet = require("src.scenes.animsheet")
  return AnimSheet.new(Palette, VW, VH, host, { mode = "death", phase = 0.5 }) -- fragmentation
end
function Builders.anim_hurt(host)
  local AnimSheet = require("src.scenes.animsheet")
  return AnimSheet.new(Palette, VW, VH, host, { mode = "hurt", phase = 0.10 }) -- secousse fraîche
end

-- DESIGNSYSTEM : storybook in-engine de l'UI (require paresseux : grosse scène, évite de la charger si non demandée).
function Builders.designsystem(host)
  local DesignSystem = require("src.scenes.designsystem")
  return DesignSystem.new(Palette, VW, VH, host)
end

-- GRIMOIRE_BESTIARY (B.2) : planche-bestiaire COMPLÈTE — tout le roster groupé par famille (jumeaux adjacents)
-- à l'échelle ~combat + bande RÉSERVE des ELDER non mécanisées. Idéale pour repérer les doublons visuels au shot.
function Builders.grimoire_bestiary(host)
  local BestiaryBoard = require("src.scenes.bestiary_board")
  return BestiaryBoard.new(Palette, VW, VH, host)
end

local M = {}

-- Liste des noms de scènes capturables (ordre stable, pour --shoot=all et les messages d'erreur).
M.names = { "menu", "build", "combat", "combat_react", "summary", "relicpick", "runevent", "runover", "grimoire", "grimoire_glossary", "grimoire_relics",
  "grimoire_bestiary",
  "gallery", "designsystem", "build_relic_hover", "build_freeze", "system", "settings",
  "anim_attack", "anim_death", "anim_hurt",
  "combat_commander",
  "commander_empty", "commander_filled", "commander_hover", "commander_offer", "commander_refuse",
  "commander_spore_keywords", "commander_fiche", "commander_fiche_none",
  "card_ember_sac", "card_wither_bloom", "card_wither_bloom_glossary",
  "card_plague_pyre", "card_plague_pyre_glossary",
  "card_relic_aegis", "card_relic_aegis_glossary" }

-- Renvoie la fabrique d'une scène nommée (ou nil si inconnue).
function M.builder(name)
  return Builders[name]
end

return M
