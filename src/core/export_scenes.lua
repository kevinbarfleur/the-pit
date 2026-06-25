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
local OppGen   = require("src.data.oppgen") -- A4 : adversaire généré scalé (capture combat)

local Build     = require("src.scenes.build")
local Combat    = require("src.scenes.combat")
local Runover   = require("src.scenes.runover")
local Relicpick = require("src.scenes.relicpick")
local Menu      = require("src.scenes.menu")
local Gallery   = require("src.scenes.gallery")
local GrimoireS = require("src.scenes.grimoire")

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
    -- drag d'un NON-chef survolant le piédestal -> refus visuel (le caller mousepressed/released le déclenche,
    -- mais pour une CAPTURE statique on pose juste cmdShake + un drag par-dessus la niche).
    b.drag = { id = "skeleton", level = 1, char = b:newRig("skeleton") }
    local r = b.commanderRect
    b.mx, b.my = r.x + r.w / 2, r.y + r.h / 2
    b.drag.char.x, b.drag.char.y = b.mx, b.my
    b.cmdShake = 0.30
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

-- C4 — captures dédiées du PIÉDESTAL (revue visuelle ui-artisan) : vide / rempli / survol portée / refus drag.
function Builders.commander_empty(host)  return makeCommanderBuild(host, "empty") end
function Builders.commander_filled(host) return makeCommanderBuild(host, "filled") end
function Builders.commander_hover(host)  return makeCommanderBuild(host, "hover") end
function Builders.commander_offer(host)  return makeCommanderBuild(host, "offer") end
function Builders.commander_refuse(host) return makeCommanderBuild(host, "empty", { dragNonChief = true }) end

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

-- RUNOVER : écran de fin (ascension). On feed un run seedé + résultat.
function Builders.runover(host)
  host.run = RunState.new(SEED)
  return Runover.new(Palette, VW, VH, host, { result = "win", run = host.run })
end

-- GRIMOIRE : codex persistant POKÉDEX (grille + filtres + fiche au survol). refresh() relit l'état connu/vu.
-- Pour la capture : onglet BESTIAIRE -> on voit (1) les chips de filtre TYPE *et* TIER, (2) le bord de chaque
-- case TEINTÉ par le tier (comme les cartes shop), (3) la FICHE au survol. On POSE LE CURSEUR sur une case du
-- TIER LE PLUS HAUT révélé (bord violet/or + halo) pour PROUVER le color-codage le plus vif dans le png.
function Builders.grimoire(host)
  local s = GrimoireS.new(Palette, VW, VH, host)
  if s.refresh then s:refresh() end
  if s.setTab then s:setTab("bestiary") end -- onglet BESTIAIRE (là où se lit la RARETÉ par couleur de tier)
  -- pose le curseur (espace DESIGN) au centre d'une case révélée de RANG ÉLEVÉ et VISIBLE (sous le pli de scroll)
  -- pour déclencher la fiche ET montrer un bord de tier saturé. La grille est triée par tier ascendant.
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
    -- le harness ne passe pas par mousemoved ; on pose mx/my en design directement (la fiche lit mx/my design).
  end
  return s
end

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

local M = {}

-- Liste des noms de scènes capturables (ordre stable, pour --shoot=all et les messages d'erreur).
M.names = { "menu", "build", "combat", "summary", "relicpick", "runover", "grimoire", "grimoire_relics",
  "gallery", "designsystem", "build_relic_hover",
  "anim_attack", "anim_death", "anim_hurt",
  "commander_empty", "commander_filled", "commander_hover", "commander_offer", "commander_refuse",
  "commander_fiche", "commander_fiche_none" }

-- Renvoie la fabrique d'une scène nommée (ou nil si inconnue).
function M.builder(name)
  return Builders[name]
end

return M
