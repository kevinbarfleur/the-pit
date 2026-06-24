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
  b:placeId(5, "templar") -- rempart central (buffe ses voisins) -> aura visible
  b:placeId(4, "marauder")
  b:placeId(6, "skeleton")
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
  local left = b:buildLeftComp()
  local enc = b:pickEncounter()
  local right = b:buildRightComp(enc)
  return Combat.new(Palette, VW, VH, host, { left = left, right = right, enemyKey = enc.key, seed = 7 })
end

-- RELICPICK : offre 1-parmi-3 (run seedé -> choix déterministes).
function Builders.relicpick(host)
  host.run = RunState.new(SEED)
  local choices = host.run:rollRelicChoices(3)
  return Relicpick.new(Palette, VW, VH, host, { choices = choices })
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
M.names = { "menu", "build", "combat", "relicpick", "runover", "grimoire", "gallery", "designsystem" }

-- Renvoie la fabrique d'une scène nommée (ou nil si inconnue).
function M.builder(name)
  return Builders[name]
end

return M
