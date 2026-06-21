-- src/lab/compcost.lua
-- DESCRIPTEUR D'INVESTISSEMENT / COMPLEXITÉ d'une composition. PUR : lit Units.cost + Shapes.edges ;
-- aucun love, aucun RunState, aucun Build (utilisable partout, y compris en analyse headless).
--
-- RAISON D'ÊTRE (cf. l'user) : « le win% brut ne vaut rien seul ». Une compo avancée (premiums, niveau,
-- relique, sigil exigé, agencement parfait) DOIT battre une compo moins investie — ce n'est pas un
-- déséquilibre. On chiffre donc le COÛT d'assemblage pour le mettre en regard du win%. L'analyseur
-- (tools/runsim) ne flague une compo « trop forte » que si elle gagne DISPROPORTIONNÉMENT à ce coût.
--
-- Tous les facteurs/poids sont des CONSTANTES NOMMÉES (un seul endroit à tuner). Justifiés et documentés
-- dans docs/research/balance-sim-design.md (P3) — ce fichier en est la source de vérité exécutable.

local Units = require("src.data.units")
local Shapes = require("src.board.shapes")

local Compcost = {}

-- Facteur d'or par NIVEAU d'unité (duplicatas : 3 copies -> niv2, 9 -> niv3 ; coût ~ nb de copies achetées).
local LEVEL_GOLD = { 1, 3, 9 }
-- Coût de leveling DU niveau L à L+1 (miroir EXACT de src/run/state.lua : levelCostAt = 4 + level).
local function levelCostAt(level) return 4 + level end
local START_SLOTS = 3 -- miroir de RunState.START_SLOTS (le plateau démarre à 3 slots)
local DEFAULT_COST = 3

-- Poids du score composite (somme = 1). NORM_GOLD ~ or d'un plateau plein de premiums (sature le terme or).
local W_GOLD, W_LEVEL, W_SLOTS, W_RELIC, W_SIGIL, W_PLACE = 0.40, 0.25, 0.10, 0.05, 0.05, 0.15
local NORM_GOLD = 120

local function unitCost(id) local u = Units[id]; return (u and u.cost) or DEFAULT_COST end

-- Part d'unités ayant >=1 voisin de la MÊME compo via le graphe du sigil (0 = un tas non agencé ;
-- 1 = tout le monde adjacent à un allié = exige un placement). Pure adjacence (zéro Build).
function Compcost.placementSens(comp)
  local shape = Shapes[comp.sigil]
  if not shape then return 0 end
  local used = {}
  for _, u in ipairs(comp.units) do used[u.slot] = true end
  local adj = {}
  for i = 1, 9 do adj[i] = {} end
  for _, e in ipairs(shape.edges) do
    adj[e[1]][#adj[e[1]] + 1] = e[2]
    adj[e[2]][#adj[e[2]] + 1] = e[1]
  end
  local withNeighbor, total = 0, 0
  for _, u in ipairs(comp.units) do
    total = total + 1
    for _, nb in ipairs(adj[u.slot] or {}) do
      if used[nb] then withNeighbor = withNeighbor + 1; break end
    end
  end
  return (total > 0) and (withNeighbor / total) or 0
end

-- Descripteur complet d'une compo.
function Compcost.of(comp)
  local gold, maxLevel = 0, 1
  for _, u in ipairs(comp.units) do
    local lvl = u.level or 1
    gold = gold + unitCost(u.id) * (LEVEL_GOLD[lvl] or 1)
    if lvl > maxLevel then maxLevel = lvl end
  end

  -- Or de leveling implicite : monter le plateau de START_SLOTS jusqu'à boardLevel.
  local boardLevel = comp.boardLevel or #comp.units
  for L = START_SLOTS, boardLevel - 1 do gold = gold + levelCostAt(L) end

  local relicDep = (comp.relics and #comp.relics > 0) and 1 or 0
  local sigilDep = (comp.sigil and comp.sigil ~= "carre") and 1 or 0 -- un sigil non-carré = topologie exigée
  local placementSens = Compcost.placementSens(comp)

  local score =
      W_GOLD * math.min(1, gold / NORM_GOLD)
    + W_LEVEL * ((maxLevel - 1) / 2)
    + W_SLOTS * (boardLevel / 9)
    + W_RELIC * relicDep
    + W_SIGIL * sigilDep
    + W_PLACE * placementSens

  return {
    gold = gold, maxLevel = maxLevel, slots = boardLevel, boardLevel = boardLevel,
    relicDep = relicDep, sigilDep = sigilDep, placementSens = placementSens, score = score,
  }
end

return Compcost
