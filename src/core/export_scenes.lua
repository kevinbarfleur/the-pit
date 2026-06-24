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

local Builders = {}

-- MENU : écran titre (indépendant du run).
function Builders.menu(host)
  return Menu.new(Palette, VW, VH, host)
end

-- BUILD : plateau peuplé + boutique (run seedé).
function Builders.build(host)
  return makeBuild(host)
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

-- RELICPICK : offre 1-parmi-3 (run seedé -> choix déterministes).
function Builders.relicpick(host)
  host.run = RunState.new(SEED)
  local choices = host.run:rollRelicChoices(3)
  -- capture le cas LEVEL-UP (midRound) : kicker doré « LEVEL-UP REWARD » -> montre la source de l'offre.
  return Relicpick.new(Palette, VW, VH, host, { choices = choices, midRound = true })
end

-- RUNOVER : écran de fin (ascension). On feed un run seedé + résultat.
function Builders.runover(host)
  host.run = RunState.new(SEED)
  return Runover.new(Palette, VW, VH, host, { result = "win", run = host.run })
end

-- GRIMOIRE : codex persistant (reliques + bestiaire). refresh() relit l'état connu/vu.
function Builders.grimoire(host)
  local s = GrimoireS.new(Palette, VW, VH, host)
  if s.refresh then s:refresh() end
  if s.setTab then s:setTab("bestiary") end -- capture l'onglet BESTIAIRE (là où se lit la RARETÉ par couleur de tier)
  if s.sort and s.sort.bestiary then s.sort.bestiary = "rank"; if s.rebuildRows then s:rebuildRows() end end -- trié par RANG -> dégradé de tier lisible
  if s.rows and #s.rows > 0 then s.sel = #s.rows; if s.maxScroll then s.scroll = s:maxScroll() end end -- bas de liste = rangs hauts (ELDER/or) -> prouve le haut de l'échelle
  return s
end

-- GALLERY : revue visuelle de tout le roster (écran [g]).
function Builders.gallery(host)
  return Gallery.new(Palette, VW, VH, host)
end

-- DESIGNSYSTEM : storybook in-engine de l'UI (require paresseux : grosse scène, évite de la charger si non demandée).
function Builders.designsystem(host)
  local DesignSystem = require("src.scenes.designsystem")
  return DesignSystem.new(Palette, VW, VH, host)
end

local M = {}

-- Liste des noms de scènes capturables (ordre stable, pour --shoot=all et les messages d'erreur).
M.names = { "menu", "build", "combat", "summary", "relicpick", "runover", "grimoire", "gallery", "designsystem" }

-- Renvoie la fabrique d'une scène nommée (ou nil si inconnue).
function M.builder(name)
  return Builders[name]
end

return M
