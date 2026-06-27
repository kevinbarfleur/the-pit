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
local Board = require("src.board.board") -- Board.shapeName : sigils en PAUSE -> coût calculé sur le carré

local Compcost = {}

-- Facteur d'or par NIVEAU d'unité (duplicatas : 3 copies -> niv2, 9 -> niv3 ; coût ~ nb de copies achetées).
local LEVEL_GOLD = { 1, 3, 9 }
local DEFAULT_COST = 3
-- Pression d'accès par rang de boutique. L'or brut ne suffit pas : une unité
-- rang 4/5 peut rester "peu chère" en gemmes mais demander tier/odds/rerolls.
local RANK_ACCESS_PRESSURE = { [1] = 0.00, [2] = 0.10, [3] = 0.30, [4] = 0.65, [5] = 0.90 }
local RANK_GATE_MULT = 0.75
local LEVEL_ACCESS_PRESSURE = { [1] = 0.00, [2] = 0.30, [3] = 0.60 }
-- NB : depuis 2026-06, débloquer un slot ne coûte plus d'or (grants timés, cf. RunState) -> l'investissement
-- ne compte plus d'« or de leveling ». Il ne reste que l'or des UNITÉS (× copies) + niveau + relique + sigil +
-- agencement. La LARGEUR de board (boardLevel) reste un proxy de complexité/breadth via W_SLOTS, pas un coût d'or.

-- Poids du score composite (somme = 1). NORM_GOLD ~ or d'un plateau plein de premiums (sature le terme or).
local W_GOLD, W_LEVEL, W_SLOTS, W_RELIC, W_SIGIL, W_PLACE = 0.40, 0.25, 0.10, 0.05, 0.05, 0.15
local NORM_GOLD = 120

local function unitCost(id) local u = Units[id]; return (u and u.cost) or DEFAULT_COST end

-- Part d'unités ayant >=1 voisin de la MÊME compo via le graphe du sigil (0 = un tas non agencé ;
-- 1 = tout le monde adjacent à un allié = exige un placement). Pure adjacence (zéro Build).
function Compcost.placementSens(comp)
  local shape = Shapes[Board.shapeName(comp.sigil)] -- sigils en PAUSE -> adjacence du carré
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
  local gold, maxLevel, maxRankPressure, weightedRankPressure, totalCopies, unitCount = 0, 1, 0, 0, 0, 0
  for _, u in ipairs(comp.units) do
    unitCount = unitCount + 1
    local lvl = u.level or 1
    local copies = LEVEL_GOLD[lvl] or 1
    gold = gold + unitCost(u.id) * copies
    if lvl > maxLevel then maxLevel = lvl end
    local def = Units[u.id]
    local rankPressure = RANK_ACCESS_PRESSURE[def and def.rank] or 0
    if rankPressure > maxRankPressure then maxRankPressure = rankPressure end
    weightedRankPressure = weightedRankPressure + rankPressure * copies
    totalCopies = totalCopies + copies
  end

  -- Largeur de plateau : proxy de breadth/complexité (les slots sont gratuits désormais, pas de coût d'or ici).
  local boardLevel = comp.boardLevel or #comp.units

  local relicDep = (comp.relics and #comp.relics > 0) and 1 or 0
  local sigilDep = (Board.shapeName(comp.sigil) ~= "carre") and 1 or 0 -- sigils en PAUSE -> toujours carré (0)
  local placementSens = Compcost.placementSens(comp)
  local avgRankPressure = (totalCopies > 0) and (weightedRankPressure / totalCopies) or 0
  local rankPressure = math.max(maxRankPressure * RANK_GATE_MULT, avgRankPressure)
  local duplicateCopies = math.max(0, totalCopies - unitCount)
  local duplicateDensity = (unitCount > 0) and (duplicateCopies / math.max(1, unitCount * 2)) or 0
  local duplicatePressure = 0
  if duplicateCopies > 0 then
    duplicatePressure = math.min(0.90, math.max(LEVEL_ACCESS_PRESSURE[maxLevel] or 0, 0.20 + 0.60 * duplicateDensity))
  end

  local weightedScore =
      W_GOLD * math.min(1, gold / NORM_GOLD)
    + W_LEVEL * ((maxLevel - 1) / 2)
    + W_SLOTS * (boardLevel / 9)
    + W_RELIC * relicDep
    + W_SIGIL * sigilDep
    + W_PLACE * placementSens
  local score = math.min(1, math.max(weightedScore, rankPressure, duplicatePressure))

  return {
    gold = gold, maxLevel = maxLevel, slots = boardLevel, boardLevel = boardLevel,
    relicDep = relicDep, sigilDep = sigilDep, placementSens = placementSens,
    rankPressure = rankPressure, duplicatePressure = duplicatePressure,
    weightedScore = weightedScore, score = score,
  }
end

return Compcost
