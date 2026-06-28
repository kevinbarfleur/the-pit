-- src/lab/policies.lua
-- POLITIQUES SCRIPTÉES (Pilier B) : des « joueurs-IA » déterministes qui pilotent une run via l'API
-- d'actions du rundriver (drv:buy/sell/reroll/acceptSlotGrant/declineSlotGrant/move/reshape/pickRelic).
-- Une politique = { name, act(self, drv) -> décisions, pickRelic?(self, drv, choices) -> index }
-- act() est appelée à chaque phase de build (avant fight). PUR-par-dépendance : n'appelle QUE des
-- méthodes publiques du driver ; aucun love.*, aucun math.random global (le hasard est un RNG INJECTÉ).
--
-- Modèle d'emplacements (décision 2026-06, cf. the-pit-balance-diagnosis) : les slots ne s'achètent plus,
-- ils arrivent en GRANTS timés (rounds 2-7). À chaque offre la politique tranche : ACCEPTER (+1 slot, jeu
-- « wide ») ou REFUSER (+or, jeu « tall » dense). Les politiques explorent donc les deux pôles de cet axe.
--
-- Les personas LLM du Pilier C (MCP) sont la MÊME taxonomie, version qualitative -> on garde des noms
-- parlants (greedy / econ / tall_dense / committed / random).

local Units = require("src.data.units")
local Coherence = require("src.lab.coherence")

local Policies = {}

local function wants(want, id, offer)
  return not want or want(id, offer)
end

local FOCUSED_SUPPORT_KINDS = {
  producer_amplifier = true,
  propagation_payoff = true,
  transform_payoff = true,
  command_amplifier = true,
  command_propagation = true,
  command_transform = true,
}

local function supportEdgeScore(edges, subscore)
  local focused, generic, weight = 0, 0, 0
  for _, edge in ipairs(edges or {}) do
    if edge.kind then
      if FOCUSED_SUPPORT_KINDS[edge.kind] then focused = focused + 1
      else generic = generic + 1 end
      weight = weight + (edge.weight or 0)
    end
  end
  return focused * 100 + generic * 10 + weight * 12 + (subscore or 0) * 25
end

local function targetUnitsFromIds(unitIds, opts)
  local levels = opts and opts.targetLevels or {}
  local out = {}
  for _, id in ipairs(unitIds or {}) do out[#out + 1] = { id = id, level = levels[id] or 1 } end
  return out
end

local function relicSupportScore(targetUnits, relicId)
  if not (targetUnits and relicId) then return 0 end
  local score = Coherence.scoreTeam(targetUnits, { relics = { relicId } })
  return supportEdgeScore(score.relicEdges, score.subscores and score.subscores.relic)
end

local function commanderSupportScore(targetUnits, candidate)
  if not (targetUnits and candidate and candidate.id) then return 0 end
  local score = Coherence.scoreTeam(targetUnits, { commander = { id = candidate.id, level = candidate.level or 1 } })
  return supportEdgeScore(score.commandEdges, score.subscores and score.subscores.command)
end

-- ── Classifieur unité -> archétype (depuis effets/aggro). Réutilisé par committed + l'analyse (runsim). ──
function Policies.archetypeOf(id)
  local u = Units[id]
  if not u then return "bruiser" end
  if u.taunt or (u.aggro and u.aggro >= 40) then return "tank" end
  for _, e in ipairs(u.effects or {}) do
    local op = e.op or ""
    if op == "poison" then return "poison" end
    if op == "burn" then return "burn" end
    if op == "bleed" then return "bleed" end
    if op == "rot" or op == "convert_to_rot" then return "rot" end
    if op == "shock" then return "shock" end
    if op == "regen" then return "tank" end
    if op:find("aura_", 1, true) then
      if op:find("burn", 1, true) then return "burn" end
      if op:find("poison", 1, true) then return "poison" end
      if op:find("bleed", 1, true) then return "bleed" end
      if op:find("rot", 1, true) then return "rot" end
    end
  end
  return "bruiser"
end

function Policies.minRankForArchetype(archetype)
  local best
  for _, id in ipairs(Units.order) do
    if Policies.archetypeOf(id) == archetype then
      local r = Units[id].rank or 99
      if not best or r < best then best = r end
    end
  end
  return best
end

-- ── Helpers communs ──
local function freeSlots(drv, extra)
  local n = extra or 0
  for i = 1, 9 do
    local bs = drv.build.board.slots[i]
    if bs and bs.unlocked and not drv.build.slotRigs[i] then n = n + 1 end
  end
  for i = 1, #(drv.build.benchSlots or {}) do
    if not drv.build.bench[i] then n = n + 1 end
  end
  return n
end

local function unitRank(id)
  local u = Units[id]
  return u and (u.rank or u.cost or 1) or 1
end

local function hasEffects(id)
  local u = Units[id]
  return u and #(u.effects or {}) > 0
end

local function desiredShop(drv, want, limit, goldBudget)
  limit = limit or freeSlots(drv, 0)
  local out = {
    count = 0, cost = 0, visibleCount = 0, visibleCost = 0,
    goldBudget = goldBudget or drv.run.gold,
    indices = {},
  }
  for i, o in ipairs(drv.run.shop) do
    if o and not o.sold and wants(want, o.id, o) then
      out.visibleCount = out.visibleCount + 1
      out.visibleCost = out.visibleCost + (o.cost or 0)
      if out.count < limit then
        out.count = out.count + 1
        out.cost = out.cost + (o.cost or 0)
        out.indices[#out.indices + 1] = i
      end
    end
  end
  out.slotLimited = out.visibleCount > out.count
  return out
end

local function copyCounts(drv)
  local counts = {}
  local function add(sr)
    if not sr then return end
    local key = sr.id .. "\0" .. (sr.level or 1)
    counts[key] = (counts[key] or 0) + 1
  end
  for i = 1, 9 do add(drv.build.slotRigs[i]) end
  for i = 1, #(drv.build.benchSlots or {}) do add(drv.build.bench[i]) end
  return counts
end

local function targetCoverage(drv, targetUnits)
  local have, want = {}, {}
  local function addHave(sr)
    if not sr then return end
    local rec = have[sr.id]
    if not rec then rec = { count = 0, levels = 0 }; have[sr.id] = rec end
    rec.count = rec.count + 1
    rec.levels = rec.levels + (sr.level or 1)
  end
  for i = 1, 9 do addHave(drv.build.slotRigs[i]) end
  for i = 1, #(drv.build.benchSlots or {}) do addHave(drv.build.bench[i]) end
  for _, u in ipairs(targetUnits or {}) do
    if u.id then
      local rec = want[u.id]
      if not rec then rec = { count = 0, levels = 0 }; want[u.id] = rec end
      rec.count = rec.count + 1
      rec.levels = rec.levels + (u.level or 1)
    end
  end
  local targetUnitCount, hitUnits, targetLevels, hitLevels = 0, 0, 0, 0
  for id, need in pairs(want) do
    local got = have[id] or { count = 0, levels = 0 }
    targetUnitCount = targetUnitCount + need.count
    targetLevels = targetLevels + need.levels
    hitUnits = hitUnits + math.min(got.count, need.count)
    hitLevels = hitLevels + math.min(got.levels, need.levels)
  end
  local unitCoverage = (targetUnitCount > 0) and (hitUnits / targetUnitCount) or 1
  local levelCoverage = (targetLevels > 0) and (hitLevels / targetLevels) or 1
  return {
    targetUnits = targetUnitCount,
    hitUnits = hitUnits,
    unitCoverage = unitCoverage,
    levelCoverage = levelCoverage,
    complete = unitCoverage >= 1 and levelCoverage >= 1,
  }
end

local function xpGateAllows(drv, targetUnits, gate)
  if not gate then return true, nil end
  local cov = targetCoverage(drv, targetUnits)
  if drv.run.shopTier < (gate.holdRank or 1) then return true, cov end
  if cov.targetUnits <= 0 then return true, cov end
  local minUnit = gate.minUnitCoverage
  if minUnit == nil then minUnit = 0.5 end
  local minLevel = gate.minLevelCoverage
  if minLevel == nil then minLevel = 0.5 end
  return cov.unitCoverage >= minUnit and cov.levelCoverage >= minLevel, cov
end

local function sameLevelCount(counts, id, level)
  return counts[id .. "\0" .. (level or 1)] or 0
end

local function targetLevelMap(targetUnits)
  local out = {}
  for _, u in ipairs(targetUnits or {}) do
    if u.id then out[u.id] = math.max(out[u.id] or 0, u.level or 1) end
  end
  return out
end

local function targetPairSupportPriority(candidates, targetUnits)
  local targetLevels = targetLevelMap(targetUnits)
  local rows = {}
  for _, id in ipairs(candidates or {}) do
    local targetLevel = targetLevels[id] or 0
    local rank = unitRank(id)
    local score = rank * 10
    if targetLevel > 0 then
      score = 1000 + rank * 120 + targetLevel * 20
    end
    rows[#rows + 1] = { id = id, score = score, rank = rank, targetLevel = targetLevel }
  end
  table.sort(rows, function(a, b)
    if a.score ~= b.score then return a.score > b.score end
    if a.targetLevel ~= b.targetLevel then return a.targetLevel > b.targetLevel end
    if a.rank ~= b.rank then return a.rank > b.rank end
    return a.id < b.id
  end)
  return rows
end

local function keepBenchUnit(drv, sr, opts, counts)
  opts = opts or {}
  if not sr then return true end
  local id, level = sr.id, sr.level or 1
  local keepWant = opts.keepWant
  if keepWant == nil then keepWant = opts.want end
  if level > 1 then return true end
  if opts.protectId and id == opts.protectId then return true end
  if keepWant and opts.protectWanted ~= false and wants(keepWant, id) then return true end
  if (counts[id .. "\0" .. level] or 0) >= 2 then return true end
  local rank = Units[id] and (Units[id].rank or 1) or 1
  if opts.keepPremium and rank >= (drv.run.shopTier or 1) then return true end
  return false
end

local function unitPlanValue(drv, sr, opts, counts)
  opts = opts or {}
  if not sr then return 0 end
  local id, level = sr.id, sr.level or 1
  local u = Units[id] or {}
  local rank = unitRank(id)
  local value = rank * 10 + (level - 1) * 45
  value = value + (u.dmg or 0) * 0.35 + (u.hp or 0) * 0.05
  if hasEffects(id) then value = value + 4 end
  if u.taunt then value = value + 16
  elseif (u.aggro or 0) >= 40 then value = value + 10
  elseif (u.aggro or 0) >= 20 then value = value + 4 end
  if u.commandBonus then value = value + 3 end
  if sameLevelCount(counts, id, level) >= 2 then value = value + 42 end
  if opts.want and wants(opts.want, id) then value = value + 28 end
  if opts.coreWant and wants(opts.coreWant, id) then value = value + 18 end
  if opts.keepPremium and rank >= (drv.run.shopTier or 1) then value = value + 14 end
  return value
end

local function offerPlanValue(drv, offer, opts, counts)
  opts = opts or {}
  if not offer then return 0 end
  local id = offer.id
  local rank = unitRank(id)
  local copies = sameLevelCount(counts, id, 1)
  local value = rank * 10 + (offer.cost or rank) * 2
  if copies >= 2 then value = value + 85
  elseif copies == 1 then value = value + 35 end
  if opts.want and wants(opts.want, id, offer) then value = value + 32 end
  if opts.coreWant and wants(opts.coreWant, id, offer) then value = value + 26 end
  if opts.keepPremium and rank >= (drv.run.shopTier or 1) then value = value + 16 end
  if hasEffects(id) then value = value + 3 end
  return value
end

local function benchPruneCandidates(drv, opts)
  local counts = copyCounts(drv)
  local out = {}
  for i = 1, #(drv.build.benchSlots or {}) do
    local sr = drv.build.bench[i]
    if sr and not keepBenchUnit(drv, sr, opts, counts) then
      local rank = Units[sr.id] and (Units[sr.id].rank or 1) or 1
      out[#out + 1] = { slot = i, rank = rank, level = sr.level or 1, id = sr.id }
    end
  end
  table.sort(out, function(a, b)
    if a.level ~= b.level then return a.level < b.level end
    if a.rank ~= b.rank then return a.rank < b.rank end
    if a.id ~= b.id then return a.id < b.id end
    return a.slot < b.slot
  end)
  return out
end

local function boardPruneCandidates(drv, opts, offer)
  opts = opts or {}
  if not opts.allowBoardPrune then return {} end
  local placed = drv.build:placedCount()
  local minBoard = opts.minBoard or 4
  if placed <= minBoard then return {} end
  local counts = copyCounts(drv)
  local offerScore = offer and offerPlanValue(drv, offer, opts, counts) or nil
  local offerCopies = offer and sameLevelCount(counts, offer.id, 1) or 0
  local keepWant = opts.keepWant
  if keepWant == nil then keepWant = opts.want end
  local margin = opts.boardPruneMargin or 12
  if offerCopies >= 2 then margin = -8
  elseif offerCopies == 1 then margin = 4 end
  local out = {}
  for i = 1, 9 do
    local sr = drv.build.slotRigs[i]
    if sr then
      local id, level = sr.id, sr.level or 1
      local keep = false
      if level > 1 then keep = true end
      if offer and offerCopies > 0 and id == offer.id then keep = true end
      if sameLevelCount(counts, id, level) >= 2 then keep = true end
      if keepWant and opts.protectWanted ~= false and wants(keepWant, id) then keep = true end
      if opts.keepPremium and unitRank(id) >= (drv.run.shopTier or 1) then keep = true end
      if not keep then
        local value = unitPlanValue(drv, sr, opts, counts)
        if not offerScore or offerScore >= value + margin then
          out[#out + 1] = {
            slot = i, id = id, level = level, rank = unitRank(id),
            value = value, refund = drv.run:sellRefund(id),
          }
        end
      end
    end
  end
  table.sort(out, function(a, b)
    if a.value ~= b.value then return a.value < b.value end
    if a.rank ~= b.rank then return a.rank < b.rank end
    if a.id ~= b.id then return a.id < b.id end
    return a.slot < b.slot
  end)
  return out
end

local function targetLevelNeeds(targetUnits)
  local out = {}
  for _, u in ipairs(targetUnits or {}) do
    if u.id then out[u.id] = (out[u.id] or 0) + (u.level or 1) end
  end
  return out
end

local function boardLevelSums(drv)
  local out = {}
  for i = 1, 9 do
    local sr = drv.build.slotRigs[i]
    if sr then out[sr.id] = (out[sr.id] or 0) + (sr.level or 1) end
  end
  return out
end

local function targetBenchDeployCandidates(drv, targetUnits)
  local needs = targetLevelNeeds(targetUnits)
  local board = boardLevelSums(drv)
  local out = {}
  for i = 1, #(drv.build.benchSlots or {}) do
    local sr = drv.build.bench[i]
    local need = sr and needs[sr.id] or nil
    if need and (board[sr.id] or 0) < need then
      local level = sr.level or 1
      local gap = need - (board[sr.id] or 0)
      out[#out + 1] = {
        slot = i,
        id = sr.id,
        level = level,
        gap = gap,
        rank = unitRank(sr.id),
        score = math.min(level, gap) * 1000 + need * 100 + unitRank(sr.id) * 10 + level,
      }
    end
  end
  table.sort(out, function(a, b)
    if a.score ~= b.score then return a.score > b.score end
    if a.gap ~= b.gap then return a.gap > b.gap end
    if a.rank ~= b.rank then return a.rank > b.rank end
    if a.id ~= b.id then return a.id < b.id end
    return a.slot < b.slot
  end)
  return out
end

local function boardReplaceCandidatesForDeployment(drv, opts)
  opts = opts or {}
  local counts = copyCounts(drv)
  local out = {}
  for i = 1, 9 do
    local sr = drv.build.slotRigs[i]
    if sr then
      local id, level = sr.id, sr.level or 1
      local keep = false
      if level > 1 then keep = true end
      if sameLevelCount(counts, id, level) >= 2 then keep = true end
      if opts.keepWant and wants(opts.keepWant, id) then keep = true end
      if opts.coreWant and wants(opts.coreWant, id) then keep = true end
      if not keep then
        local value = unitPlanValue(drv, sr, opts, counts)
        out[#out + 1] = {
          slot = i,
          id = id,
          level = level,
          rank = unitRank(id),
          value = value,
        }
      end
    end
  end
  table.sort(out, function(a, b)
    if a.value ~= b.value then return a.value < b.value end
    if a.rank ~= b.rank then return a.rank < b.rank end
    if a.id ~= b.id then return a.id < b.id end
    return a.slot < b.slot
  end)
  return out
end

local function deployTargetBench(drv, targetUnits, opts)
  opts = opts or {}
  local deployed, swaps = 0, 0
  local maxMoves = opts.maxMoves or 3
  for _ = 1, maxMoves do
    local targets = targetBenchDeployCandidates(drv, targetUnits)
    if #targets == 0 then break end
    local boardSlot = drv:firstEmptySlot()
    local willSwap = false
    if not boardSlot then
      local replace = boardReplaceCandidatesForDeployment(drv, opts)[1]
      if not replace then break end
      boardSlot = replace.slot
      willSwap = true
    end
    if not drv:moveBenchToBoard(targets[1].slot, boardSlot) then break end
    deployed = deployed + 1
    if willSwap then swaps = swaps + 1 end
  end
  return deployed, swaps
end

local function benchSellPlan(drv, opts)
  local count, refund = 0, 0
  for _, c in ipairs(benchPruneCandidates(drv, opts)) do
    count = count + 1
    refund = refund + drv.run:sellRefund(c.id)
  end
  return { count = count, refund = refund }
end

local function smartDesiredShop(drv, want, opts, extra)
  local plan = benchSellPlan(drv, opts)
  return desiredShop(drv, want, freeSlots(drv, extra or 0) + plan.count, drv.run.gold + plan.refund)
end

local function pruneBenchForOffer(drv, shopIndex, opts)
  opts = opts or {}
  local offer = drv.run.shop[shopIndex]
  local pruneOpts = {}
  for k, v in pairs(opts) do pruneOpts[k] = v end
  pruneOpts.protectId = offer and offer.id or pruneOpts.protectId
  local sold = 0
  for _, c in ipairs(benchPruneCandidates(drv, pruneOpts)) do
    if drv:offerPlayable(shopIndex) then break end
    if drv:sellBench(c.slot) then sold = sold + 1 end
  end
  return sold
end

local function pruneBoardForOffer(drv, shopIndex, opts)
  local offer = drv.run.shop[shopIndex]
  if not offer or offer.sold then return 0 end
  for _, c in ipairs(boardPruneCandidates(drv, opts, offer)) do
    if drv:offerPlayable(shopIndex) then break end
    if drv.run.gold + c.refund >= (offer.cost or 0) and drv:sell(c.slot) then return 1 end
  end
  return 0
end

local function sortedDesiredOffers(drv, want, opts)
  local counts = copyCounts(drv)
  local out = {}
  for i, o in ipairs(drv.run.shop) do
    if o and not o.sold and wants(want, o.id, o) then
      out[#out + 1] = {
        index = i,
        cost = o.cost or 0,
        rank = unitRank(o.id),
        id = o.id,
        score = offerPlanValue(drv, o, opts, counts),
      }
    end
  end
  table.sort(out, function(a, b)
    if a.score ~= b.score then return a.score > b.score end
    if a.cost ~= b.cost then return a.cost < b.cost end
    if a.rank ~= b.rank then return a.rank > b.rank end
    if a.id ~= b.id then return a.id < b.id end
    return a.index < b.index
  end)
  return out
end

local function buyMatchingPlanned(drv, want, opts)
  opts = opts or {}
  opts.want = want
  local bought, sold, boardSold = 0, 0, 0
  for _, item in ipairs(sortedDesiredOffers(drv, want, opts)) do
    local i = item.index
    local o = drv.run.shop[i]
    if o and not o.sold and wants(want, o.id, o) then
      local churnMin = opts.churnMinScore
      if churnMin == nil then churnMin = 50 end
      local allowChurn = item.score >= churnMin
      if not drv:offerPlayable(i) and allowChurn then sold = sold + pruneBenchForOffer(drv, i, opts) end
      if not drv:offerPlayable(i) and opts.allowBoardPrune then
        if allowChurn then
          local s = pruneBoardForOffer(drv, i, opts)
          sold = sold + s
          boardSold = boardSold + s
        end
      end
      if drv:buy(i) then bought = bought + 1 end
    end
  end
  return bought, sold, boardSold
end

local function pruneBenchToReserve(drv, opts, reserve)
  reserve = reserve or 1
  local sold = 0
  for _, c in ipairs(benchPruneCandidates(drv, opts)) do
    if freeSlots(drv, 0) >= reserve then break end
    if drv:sellBench(c.slot) then sold = sold + 1 end
  end
  return sold
end

function Policies.commitmentFor(drv, archetype)
  return Policies.commitmentForWant(drv, archetype, function(id) return Policies.archetypeOf(id) == archetype end)
end

function Policies.commitmentForWant(drv, archetype, want)
  local total, hits = 0, 0
  for i = 1, 9 do
    local sr = drv.build.slotRigs[i]
    if sr then
      total = total + 1
      if wants(want, sr.id) then hits = hits + 1 end
    end
  end
  local share = (total > 0) and (hits / total) or 0
  local minCount = (total >= 5) and 3 or 2
  return {
    archetype = archetype,
    total = total,
    hits = hits,
    share = share,
    committed = hits >= minCount and share >= 0.55,
  }
end

-- Achète les offres affordables passant `want(id)` (ou toutes si want=nil) dans le plateau puis le banc.
local function buyMatching(drv, want)
  local n = 0
  for i = 1, #drv.run.shop do
    local o = drv.run.shop[i]
    if o and not o.sold and drv.run.gold >= o.cost and (not want or want(o.id)) then
      if drv:buy(i) then n = n + 1 end
    end
  end
  return n
end

local function buyMatchingSmart(drv, want, opts)
  local n, sold = 0, 0
  for i = 1, #drv.run.shop do
    local o = drv.run.shop[i]
    if o and not o.sold and (not want or want(o.id)) then
      if not drv:offerPlayable(i) then sold = sold + pruneBenchForOffer(drv, i, opts) end
      if drv:buy(i) then n = n + 1 end
    end
  end
  return n, sold
end

local function buyFirstMatching(drv, want)
  for i = 1, #drv.run.shop do
    local o = drv.run.shop[i]
    if o and not o.sold and drv.run.gold >= o.cost and (not want or want(o.id)) then
      if drv:buy(i) then return 1 end
    end
  end
  return 0
end

-- Filet anti-défaite : si le plateau est vide, achète n'importe quelle offre abordable.
local function ensureNonEmpty(drv)
  if drv.build:placedCount() == 0 then buyMatching(drv, nil) end
end

-- Tranche l'offre de slot en attente : `accept`=true -> +1 slot (placement central par défaut, headless) ;
-- false -> refuse pour de l'or. No-op s'il n'y a pas d'offre en attente.
local function resolveGrant(drv, accept)
  if not drv.run.pendingSlotGrant then return end
  if accept then drv:acceptSlotGrant() else drv:declineSlotGrant() end
end

-- ── 1) GREEDY STATS (WIDE) : accepte tout slot offert, remplit avec tout l'abordable (priorise les
-- premiums via l'ordre boutique). Le « bon joueur » qui va large et dépense tout chaque round. ──
Policies.greedy_stats = {
  name = "greedy_stats",
  desiredOffers = function(_, drv)
    return desiredShop(drv, nil, freeSlots(drv, drv.run.pendingSlotGrant and 1 or 0))
  end,
  act = function(_, drv)
    resolveGrant(drv, true)
    local bought = buyMatching(drv, nil)
    ensureNonEmpty(drv)
    return { slots = drv.run.slots, bought = bought }
  end,
}

Policies.greedy_prune = {
  name = "greedy_prune",
  desiredOffers = function(_, drv)
    return smartDesiredShop(drv, nil, { keepPremium = true }, drv.run.pendingSlotGrant and 1 or 0)
  end,
  act = function(_, drv)
    resolveGrant(drv, true)
    local bought, sold = buyMatchingSmart(drv, nil, { keepPremium = true })
    ensureNonEmpty(drv)
    return { slots = drv.run.slots, bought = bought, sold = sold }
  end,
}

Policies.greedy_plan = {
  name = "greedy_plan",
  desiredOffers = function(_, drv)
    return smartDesiredShop(drv, nil, { protectPairs = true }, drv.run.pendingSlotGrant and 1 or 0)
  end,
  act = function(_, drv)
    resolveGrant(drv, true)
    local bought, sold, boardSold = buyMatchingPlanned(drv, nil, {
      allowBoardPrune = true,
      minBoard = 4,
      boardPruneMargin = 12,
    })
    ensureNonEmpty(drv)
    return { slots = drv.run.slots, bought = bought, sold = sold, boardSold = boardSold }
  end,
}

-- ── 2) ECON STREAK (WIDE, frugal) : ne reroll JAMAIS (épargne), accepte les slots, REMPLIT au moins cher.
-- Le joueur « éco » qui fait grossir un board solide à bas coût et garde de l'or pour les streaks. ──
Policies.econ_streak = {
  name = "econ_streak",
  desiredOffers = function(_, drv)
    local cheap = function(id) return drv.run:unitCost(id) <= 3 end
    return desiredShop(drv, cheap, freeSlots(drv, drv.run.pendingSlotGrant and 1 or 0))
  end,
  act = function(_, drv)
    resolveGrant(drv, true)
    local cheap = function(id) return drv.run:unitCost(id) <= 3 end
    local bought = buyMatching(drv, cheap)
    ensureNonEmpty(drv)
    return { slots = drv.run.slots, bought = bought }
  end,
}

Policies.econ_prune = {
  name = "econ_prune",
  desiredOffers = function(_, drv)
    local cheap = function(id) return drv.run:unitCost(id) <= 3 end
    return smartDesiredShop(drv, cheap, {}, drv.run.pendingSlotGrant and 1 or 0)
  end,
  act = function(_, drv)
    resolveGrant(drv, true)
    local cheap = function(id) return drv.run:unitCost(id) <= 3 end
    local bought, sold = buyMatchingSmart(drv, cheap, {})
    ensureNonEmpty(drv)
    return { slots = drv.run.slots, bought = bought, sold = sold }
  end,
}

Policies.econ_plan = {
  name = "econ_plan",
  desiredOffers = function(_, drv)
    local cheap = function(id) return drv.run:unitCost(id) <= 3 end
    return smartDesiredShop(drv, cheap, { protectWanted = true }, drv.run.pendingSlotGrant and 1 or 0)
  end,
  act = function(_, drv)
    resolveGrant(drv, true)
    local cheap = function(id) return drv.run:unitCost(id) <= 3 end
    local bought, sold, boardSold = buyMatchingPlanned(drv, cheap, {
      protectWanted = false,
      allowBoardPrune = true,
      minBoard = 4,
      boardPruneMargin = 10,
    })
    ensureNonEmpty(drv)
    return { slots = drv.run.slots, bought = bought, sold = sold, boardSold = boardSold }
  end,
}

-- ── 3) FORCE LEVEL FAST : accepte les slots, garde au moins un corps sur le plateau, puis convertit
-- l'or disponible en XP de boutique avant de remplir. Teste si rusher les hauts rangs paie vraiment.
Policies.force_level_fast = {
  name = "force_level_fast",
  desiredOffers = function(_, drv)
    local slots = freeSlots(drv, drv.run.pendingSlotGrant and 1 or 0)
    if drv.build:placedCount() == 0 then slots = math.min(slots, 1) end
    return desiredShop(drv, nil, slots)
  end,
  act = function(_, drv)
    resolveGrant(drv, true)
    local bought = 0
    if drv.build:placedCount() == 0 then bought = bought + buyFirstMatching(drv, nil) end
    local xpBuys = 0
    while drv.run:canBuyXp() and xpBuys < 2 do
      if not drv:buyXp() then break end
      xpBuys = xpBuys + 1
    end
    bought = bought + buyMatching(drv, nil)
    ensureNonEmpty(drv)
    return { slots = drv.run.slots, bought = bought, xpBuys = xpBuys, shopTier = drv.run.shopTier }
  end,
}

-- ── 4) TALL DENSE (factory, le pôle TALL) : accepte les grants jusqu'à `keep` slots puis REFUSE le reste
-- pour de l'or, qu'il convertit en DENSITÉ (reroll -> duplicatas -> merges 3->niveau). Teste l'axe wide-vs-
-- tall que le système de grants introduit : peu d'unités fortes plutôt que beaucoup de faibles. ──
function Policies.tall_dense(keep)
  keep = keep or 5
  return {
    name = "tall_dense",
    keep = keep,
    desiredOffers = function(self, drv)
      local extra = (drv.run.pendingSlotGrant and drv.run.slots < self.keep) and 1 or 0
      return desiredShop(drv, nil, freeSlots(drv, extra))
    end,
    act = function(self, drv)
      resolveGrant(drv, drv.run.slots < self.keep) -- accepte tant qu'on est sous `keep`, sinon refuse
      local bought = buyMatching(drv, nil)
      ensureNonEmpty(drv)
      -- surplus d'or (gonflé par les refus) -> densité : reroll + rachat (merges via build:checkMerges).
      local rerolls = 0
      while drv.run.gold >= 3 and rerolls < 4 do
        if not drv:reroll() then break end
        rerolls = rerolls + 1
        bought = bought + buyMatching(drv, nil)
      end
      return { slots = drv.run.slots, bought = bought, rerolls = rerolls }
    end,
  }
end

function Policies.tall_dense_prune(keep)
  keep = keep or 5
  return {
    name = "tall_dense_prune",
    keep = keep,
    desiredOffers = function(self, drv)
      local extra = (drv.run.pendingSlotGrant and drv.run.slots < self.keep) and 1 or 0
      return smartDesiredShop(drv, nil, { keepPremium = true }, extra)
    end,
    act = function(self, drv)
      resolveGrant(drv, drv.run.slots < self.keep)
      local bought, sold = buyMatchingSmart(drv, nil, { keepPremium = true })
      ensureNonEmpty(drv)
      local rerolls = 0
      while drv.run.gold >= 3 and rerolls < 4 do
        sold = sold + pruneBenchToReserve(drv, { keepPremium = true }, 1)
        if not drv:reroll() then break end
        rerolls = rerolls + 1
        local b, s = buyMatchingSmart(drv, nil, { keepPremium = true })
        bought = bought + b
        sold = sold + s
      end
      return { slots = drv.run.slots, bought = bought, sold = sold, rerolls = rerolls }
    end,
  }
end

function Policies.tall_dense_plan(keep)
  keep = keep or 5
  return {
    name = "tall_dense_plan",
    keep = keep,
    desiredOffers = function(self, drv)
      local extra = (drv.run.pendingSlotGrant and drv.run.slots < self.keep) and 1 or 0
      return smartDesiredShop(drv, nil, {}, extra)
    end,
    act = function(self, drv)
      resolveGrant(drv, drv.run.slots < self.keep)
      local bought, sold, boardSold = buyMatchingPlanned(drv, nil, {
        allowBoardPrune = true,
        minBoard = math.min(self.keep, 4),
        boardPruneMargin = 8,
      })
      ensureNonEmpty(drv)
      local rerolls = 0
      while drv.run.gold >= 3 and rerolls < 4 do
        sold = sold + pruneBenchToReserve(drv, {}, 1)
        if not drv:reroll() then break end
        rerolls = rerolls + 1
        local b, s, bs = buyMatchingPlanned(drv, nil, {
          allowBoardPrune = true,
          minBoard = math.min(self.keep, 4),
          boardPruneMargin = 8,
        })
        bought = bought + b
        sold = sold + s
        boardSold = boardSold + bs
      end
      return { slots = drv.run.slots, bought = bought, sold = sold, boardSold = boardSold, rerolls = rerolls }
    end,
  }
end

-- ── 5) COMMITTED ARCHETYPE (factory, WIDE themed) : reshape vers `sigil` une fois, accepte les slots,
-- n'achète QUE des unités de `archetype` (reroll jusqu'à 2× pour en trouver), filet anti-défaite sinon. ──
function Policies.committed_archetype(archetype, sigil)
  return {
    name = "committed_" .. archetype,
    archetype = archetype, sigil = sigil,
    desiredOffers = function(self, drv)
      local want = function(id) return Policies.archetypeOf(id) == self.archetype end
      return desiredShop(drv, want, freeSlots(drv, drv.run.pendingSlotGrant and 1 or 0))
    end,
    commitment = function(self, drv)
      return Policies.commitmentFor(drv, self.archetype)
    end,
    act = function(self, drv)
      if sigil and drv.build.board.shape.name ~= sigil then drv:reshape(sigil) end
      resolveGrant(drv, true)
      local want = function(id) return Policies.archetypeOf(id) == self.archetype end
      local xpBuys = 0
      local minRank = Policies.minRankForArchetype(self.archetype) or 1
      while drv.run.shopTier < minRank and drv.run:canBuyXp() and xpBuys < 2 do
        if not drv:buyXp() then break end
        xpBuys = xpBuys + 1
      end
      -- REMPLIR du bon type d'abord (reroll jusqu'à 2× pour trouver des cases vides à combler).
      local bought = buyMatching(drv, want)
      local rerolls = 0
      while drv:hasBuySpace() and drv.run:canReroll() and rerolls < 2 do
        drv:reroll(); rerolls = rerolls + 1; bought = bought + buyMatching(drv, want)
      end
      ensureNonEmpty(drv) -- jamais perdre faute d'unité du bon type
      return { archetype = self.archetype, bought = bought, rerolls = rerolls, xpBuys = xpBuys }
    end,
  }
end

function Policies.committed_archetype_plan_with(archetype, sigil, opts)
  opts = opts or {}
  local targetUnits = opts.targetUnits or {}
  local function scheduledMinRank(drv, base)
    local rank = base or 1
    for _, step in ipairs(opts.rankSchedule or {}) do
      if drv.run.round >= (step.round or 0) then rank = math.max(rank, step.rank or rank) end
    end
    return rank
  end
  local function planOpts()
    return {
      protectWanted = true,
      keepWant = opts.keepWant,
      coreWant = opts.coreWant,
      allowBoardPrune = true,
      minBoard = 3,
      boardPruneMargin = opts.boardPruneMargin or 4,
      churnMinScore = 0,
    }
  end
  local function currentWant(self, drv)
    local base = opts.want or function(id) return Policies.archetypeOf(id) == self.archetype end
    if opts.wantForDriver then return opts.wantForDriver(drv, self, base) end
    return base
  end
  return {
    name = opts.name or ("committed_" .. archetype .. "_plan"),
    archetype = archetype, sigil = sigil,
    desiredOffers = function(self, drv)
      local want = currentWant(self, drv)
      return smartDesiredShop(drv, want, {
        want = want,
        keepWant = opts.keepWant,
        coreWant = opts.coreWant,
        protectWanted = true,
      }, drv.run.pendingSlotGrant and 1 or 0)
    end,
    commitment = function(self, drv)
      local want = opts.commitWant or opts.want or function(id) return Policies.archetypeOf(id) == self.archetype end
      return Policies.commitmentForWant(drv, self.archetype, want)
    end,
    act = function(self, drv)
      if sigil and drv.build.board.shape.name ~= sigil then drv:reshape(sigil) end
      resolveGrant(drv, true)
      local want = currentWant(self, drv)
      local bought = 0
      if drv.build:placedCount() == 0 then
        bought = bought + buyFirstMatching(drv, want)
        ensureNonEmpty(drv)
      end
      local xpBuys = 0
      local xpGateBlocked = false
      local xpGateCoverage
      local minRank = scheduledMinRank(drv, opts.minRank or Policies.minRankForArchetype(self.archetype) or 1)
      local maxXpBuys = opts.maxXpBuysPerRound or 2
      while drv.run.shopTier < minRank and drv.run:canBuyXp() and xpBuys < maxXpBuys do
        local allowXp, cov = xpGateAllows(drv, targetUnits, opts.xpCoverageGate)
        xpGateCoverage = cov or xpGateCoverage
        if not allowXp then xpGateBlocked = true; break end
        if not drv:buyXp() then break end
        xpBuys = xpBuys + 1
      end
      if opts.xpCoverageGate and not xpGateCoverage then xpGateCoverage = targetCoverage(drv, targetUnits) end
      local plannedBought, sold, boardSold = buyMatchingPlanned(drv, want, planOpts())
      bought = bought + plannedBought
      local rerolls = 0
      local reserveOpts = planOpts()
      reserveOpts.want = want
      local maxRerolls = opts.maxRerollsPerRound or 2
      while (drv:hasBuySpace() or #benchPruneCandidates(drv, reserveOpts) > 0) and drv.run:canReroll() and rerolls < maxRerolls do
        sold = sold + pruneBenchToReserve(drv, reserveOpts, 1)
        if not drv:reroll() then break end
        rerolls = rerolls + 1
        local b, s, bs = buyMatchingPlanned(drv, want, planOpts())
        bought = bought + b
        sold = sold + s
        boardSold = boardSold + bs
      end
      local deployed, boardSwaps = deployTargetBench(drv, targetUnits, {
        keepWant = opts.keepWant,
        coreWant = opts.coreWant,
        maxMoves = opts.maxDeployMovesPerRound or 3,
      })
      ensureNonEmpty(drv)
      return {
        archetype = self.archetype, bought = bought, sold = sold, boardSold = boardSold,
        rerolls = rerolls, xpBuys = xpBuys,
        deployed = (deployed > 0) and deployed or nil,
        boardSwaps = (boardSwaps > 0) and boardSwaps or nil,
        xpGateBlocked = xpGateBlocked or nil,
        xpGateUnitCoverage = xpGateCoverage and xpGateCoverage.unitCoverage or nil,
        xpGateLevelCoverage = xpGateCoverage and xpGateCoverage.levelCoverage or nil,
      }
    end,
    pickRelic = function(_, _, choices)
      local bestIndex, bestScore = 1, -math.huge
      for i, relicId in ipairs(choices or {}) do
        local score = relicSupportScore(targetUnits, relicId)
        if score > bestScore then
          bestIndex, bestScore = i, score
        end
      end
      return bestIndex
    end,
    chooseCommanderCandidate = function(_, _, candidates)
      local best, bestScore
      for _, c in ipairs(candidates or {}) do
        local score = commanderSupportScore(targetUnits, c)
        if not best or score > bestScore then
          best, bestScore = c, score
        end
      end
      return best
    end,
    prioritizePairSupport = function(_, _, candidates)
      return targetPairSupportPriority(candidates, targetUnits)
    end,
  }
end

function Policies.committed_archetype_plan(archetype, sigil)
  return Policies.committed_archetype_plan_with(archetype, sigil)
end

function Policies.committed_unit_set_plan(name, archetype, sigil, unitIds, opts)
  opts = opts or {}
  local wanted = {}
  local maxRank = 1
  for _, id in ipairs(unitIds or {}) do
    wanted[id] = true
    maxRank = math.max(maxRank, unitRank(id))
  end
  local supports = opts.supportArchetypes or {}
  local want = function(id)
    return wanted[id] == true or supports[Policies.archetypeOf(id)] == true
  end
  local commitWant = function(id) return wanted[id] == true end
  local targetUnits = opts.targetUnits or targetUnitsFromIds(unitIds, opts)
  local wantForDriver
  if opts.supportUntilLevelCoverage then
    wantForDriver = function(drv)
      local cov = targetCoverage(drv, targetUnits)
      local allowSupport = (cov.levelCoverage or 0) < opts.supportUntilLevelCoverage
        or drv.build:placedCount() < (opts.supportMinBoard or 4)
      local counts = opts.supportPairsAfterGate and copyCounts(drv) or nil
      return function(id, offer)
        if wanted[id] == true then return true end
        if supports[Policies.archetypeOf(id)] ~= true then return false end
        if allowSupport then return true end
        if counts and sameLevelCount(counts, id, 1) >= 1 then return true end
        return false
      end
    end
  end
  return Policies.committed_archetype_plan_with(archetype, sigil, {
    name = name,
    want = want,
    wantForDriver = wantForDriver,
    keepWant = opts.keepWant or commitWant,
    coreWant = commitWant,
    commitWant = commitWant,
    minRank = opts.minRank or math.min(maxRank, 3),
    targetUnits = targetUnits,
    boardPruneMargin = opts.boardPruneMargin,
    maxXpBuysPerRound = opts.maxXpBuysPerRound,
    maxRerollsPerRound = opts.maxRerollsPerRound,
    rankSchedule = opts.rankSchedule,
    xpCoverageGate = opts.xpCoverageGate,
  })
end

-- ── 6) RANDOM BASELINE (factory, RNG INJECTÉ -> déterministe) : accepte/refuse, reroll, achats au hasard.
-- Le plancher de référence (toute politique sensée doit le battre). ──
function Policies.random_baseline(rng)
  return {
    name = "random_baseline",
    act = function(_, drv)
      if drv.run.pendingSlotGrant then resolveGrant(drv, rng:random(1, 2) == 1) end
      if rng:random() < 0.3 and drv.run:canReroll() then drv:reroll() end
      -- achète chaque offre abordable avec proba 0.7, dans une case vide
      for i = 1, #drv.run.shop do
        local o = drv.run.shop[i]
        if o and not o.sold and drv.run.gold >= o.cost and rng:random() < 0.7 then drv:buy(i) end
      end
      ensureNonEmpty(drv)
      return {}
    end,
  }
end

-- Jeu de politiques « batch » par défaut (pour tools/runsim). Couvre wide/tall/XP + 4 familles DoT.
function Policies.defaultSet(rng)
  return {
    Policies.greedy_stats,
    Policies.econ_streak,
    Policies.force_level_fast,
    Policies.tall_dense(5),
    Policies.committed_archetype("poison", "diamant"),
    Policies.committed_archetype("burn", "ligne"),
    Policies.committed_archetype("rot", "carre"),
    Policies.committed_archetype("tank", "carre"),
    Policies.random_baseline(rng),
  }
end

function Policies.analysisSet(rng)
  local out = Policies.defaultSet(rng)
  out[#out + 1] = Policies.greedy_prune
  out[#out + 1] = Policies.econ_prune
  out[#out + 1] = Policies.tall_dense_prune(5)
  out[#out + 1] = Policies.greedy_plan
  out[#out + 1] = Policies.econ_plan
  out[#out + 1] = Policies.tall_dense_plan(5)
  out[#out + 1] = Policies.committed_archetype_plan("poison", "diamant")
  out[#out + 1] = Policies.committed_archetype_plan("burn", "ligne")
  out[#out + 1] = Policies.committed_archetype_plan("rot", "carre")
  out[#out + 1] = Policies.committed_archetype_plan("tank", "carre")
  out[#out + 1] = Policies.committed_unit_set_plan("committed_cross_bleed_rot_plan", "rot", "carre", {
    "pit_maw", "razorkin", "gash_fiend", "clot_mender",
    "marrow_drinker", "wither_bloom", "blight_spreader", "hookjaw",
  }, { supportArchetypes = { rot = true, bleed = true } })
  out[#out + 1] = Policies.committed_unit_set_plan("committed_cross_bleed_rot_late_plan", "rot", "carre", {
    "pit_maw", "razorkin", "gash_fiend", "clot_mender",
    "marrow_drinker", "wither_bloom", "blight_spreader", "hookjaw",
  }, {
    supportArchetypes = { rot = true, bleed = true },
    minRank = 5,
    maxXpBuysPerRound = 3,
    targetLevels = {
      razorkin = 2, gash_fiend = 2, clot_mender = 2,
      marrow_drinker = 2, rot_hound = 3, carrion_pecker = 3, necro_leech = 2,
    },
  })
  out[#out + 1] = Policies.committed_unit_set_plan("committed_cross_bleed_rot_staged_plan", "rot", "carre", {
    "pit_maw", "razorkin", "gash_fiend", "clot_mender",
    "marrow_drinker", "wither_bloom", "blight_spreader", "hookjaw",
  }, {
    supportArchetypes = { rot = true, bleed = true },
    minRank = 3,
    maxXpBuysPerRound = 2,
    rankSchedule = {
      { round = 7, rank = 4 },
      { round = 10, rank = 5 },
    },
    targetLevels = {
      razorkin = 2, gash_fiend = 2, clot_mender = 2,
      marrow_drinker = 2, rot_hound = 3, carrion_pecker = 3, necro_leech = 2,
    },
  })
  out[#out + 1] = Policies.committed_unit_set_plan("committed_cross_bleed_rot_coverage_plan", "rot", "carre", {
    "pit_maw", "razorkin", "gash_fiend", "clot_mender",
    "marrow_drinker", "wither_bloom", "blight_spreader", "hookjaw",
  }, {
    supportArchetypes = { rot = true, bleed = true },
    minRank = 3,
    maxXpBuysPerRound = 2,
    rankSchedule = {
      { round = 7, rank = 4 },
      { round = 10, rank = 5 },
    },
    xpCoverageGate = { holdRank = 3, minUnitCoverage = 0.5, minLevelCoverage = 0.5 },
    targetLevels = {
      razorkin = 2, gash_fiend = 2, clot_mender = 2,
      marrow_drinker = 2, rot_hound = 3, carrion_pecker = 3, necro_leech = 2,
    },
  })
  out[#out + 1] = Policies.committed_unit_set_plan("committed_rot_bleed_rat_core_plan", "rot", "carre", {
    "clot_mender", "razorkin", "gash_fiend",
    "rot_hound", "carrion_pecker", "gnaw_rat",
  }, {
    supportArchetypes = { rot = true, bleed = true },
    minRank = 3,
    maxXpBuysPerRound = 2,
    xpCoverageGate = { holdRank = 3, minUnitCoverage = 0.5, minLevelCoverage = 0.5 },
    targetLevels = {
      clot_mender = 2, razorkin = 2, gash_fiend = 2,
      rot_hound = 3, carrion_pecker = 3, gnaw_rat = 3,
    },
  })
  out[#out + 1] = Policies.committed_unit_set_plan("committed_rot_bleed_rat_core_gated_plan", "rot", "carre", {
    "clot_mender", "razorkin", "gash_fiend",
    "rot_hound", "carrion_pecker", "gnaw_rat",
  }, {
    supportArchetypes = { rot = true, bleed = true },
    supportUntilLevelCoverage = 0.50,
    supportMinBoard = 4,
    minRank = 3,
    maxXpBuysPerRound = 2,
    xpCoverageGate = { holdRank = 3, minUnitCoverage = 0.5, minLevelCoverage = 0.5 },
    targetLevels = {
      clot_mender = 2, razorkin = 2, gash_fiend = 2,
      rot_hound = 3, carrion_pecker = 3, gnaw_rat = 3,
    },
  })
  out[#out + 1] = Policies.committed_unit_set_plan("committed_rot_bleed_rat_core_no_xp_plan", "rot", "carre", {
    "clot_mender", "razorkin", "gash_fiend",
    "rot_hound", "carrion_pecker", "gnaw_rat",
  }, {
    supportArchetypes = { rot = true, bleed = true },
    supportUntilLevelCoverage = 0.60,
    supportMinBoard = 4,
    minRank = 3,
    maxXpBuysPerRound = 0,
    maxRerollsPerRound = 2,
    targetLevels = {
      clot_mender = 2, razorkin = 2, gash_fiend = 2,
      rot_hound = 3, carrion_pecker = 3, gnaw_rat = 3,
    },
  })
  out[#out + 1] = Policies.committed_unit_set_plan("committed_rot_bleed_rat_core_deep_reroll_plan", "rot", "carre", {
    "clot_mender", "razorkin", "gash_fiend",
    "rot_hound", "carrion_pecker", "gnaw_rat",
  }, {
    supportArchetypes = { rot = true, bleed = true },
    supportUntilLevelCoverage = 0.60,
    supportMinBoard = 4,
    minRank = 3,
    maxXpBuysPerRound = 0,
    maxRerollsPerRound = 5,
    targetLevels = {
      clot_mender = 2, razorkin = 2, gash_fiend = 2,
      rot_hound = 3, carrion_pecker = 3, gnaw_rat = 3,
    },
  })
  return out
end

return Policies
