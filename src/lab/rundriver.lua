-- src/lab/rundriver.lua
-- PILOTE DE RUN headless — la COLONNE VERTÉBRALE du banc d'essai (Piliers B et C).
-- Combine l'ÉTAT DE RUN réel (src/run/state, économie SIM-pure) + un vrai Build (plateau/placement/fusion/
-- buildComp aura-résolu) + le runner de match. Il REJOUE la méta-boucle du host (resolve -> observe ->
-- offre de relique -> startRound) SANS aucune IO Grimoire. Expose une API D'ACTIONS JOUEUR sérialisable :
--   state / buy / sell / reroll / acceptSlotGrant / declineSlotGrant / move / reshape / pickRelic / pickRunEvent / fight
-- que consomment AUSSI BIEN les politiques scriptées (Pilier B, tools/runsim) que les outils MCP (Pilier C).
--
-- ⚠️ RENDER-tainted (construit un Build = scène). HORS firewall SIM ; ne jamais le require depuis
-- src/combat|board|effects|run. Tout est SEEDÉ (RunState + nextCombatSeed) : (seed + suite d'actions)
-- -> partie 100% REJOUABLE. Tourne headless sous luajit + tests/mock_love (comme tools/sim.lua).

local Run = require("src.run.state")
local Build = require("src.scenes.build")
local Shapes = require("src.board.shapes")
local Match = require("src.combat.match")
local Compcost = require("src.lab.compcost")
local Palette = require("src.core.palette")
local Units = require("src.data.units")
local Pacing = require("src.run.pacing")
local Mutations = require("src.run.mutations")
local EventRewards = require("src.run.event_rewards")
local OppGen = require("src.data.oppgen")

local Rundriver = {}
Rundriver.__index = Rundriver
Rundriver.DEFAULT_BENCH_SIZE = Build.DEFAULT_BENCH_SIZE
Rundriver.MAX_BENCH_SIZE = Build.MAX_BENCH_SIZE

local STUB_GOTO = function() end

function Rundriver.new(seed, opts)
  opts = opts or {}
  local pacing = Pacing.arenaOptions(opts.pacingProfile)
  local run = Run.new(seed or 0, { economy = opts.economy })
  local host = { goto = STUB_GOTO, run = run } -- le Build lit host.run (slots, pickEncounter)
  local build = Build.new(opts.palette or Palette, 320, 180, host, { benchSize = opts.benchSize })
  if opts.sigil then build.board:setShape(opts.sigil); build:computeLayout() end
  local self = setmetatable({
    run = run, build = build, host = host, opts = opts,
    tickCap = opts.tickCap or 8000,
    hpMult = (opts.hpMult ~= nil) and opts.hpMult or pacing.hpMult, -- live by default; scenario opts may override
    cooldownMult = (opts.cooldownMult ~= nil) and opts.cooldownMult or pacing.cooldownMult,
    fatigue = (opts.fatigue ~= nil) and opts.fatigue or pacing.fatigue,
    commanderMode = opts.commanderMode or "ignore", -- lab-only policy: ignore | decline | auto
    runEvents = opts.runEvents == true, -- lab-only experiment: replace merchant relics with thematic run events
    runEventMutations = opts.runEventMutations == true, -- lab-only: materialize mutation lanes with exact copy targets
    eventUnitTargeting = opts.eventUnitTargeting, -- nil | "policy" | "space" | "missing_copy" | combinations; lab-only event unit materialization experiment
    eventUnitPickCap = opts.eventUnitPickCap, -- lab-only: max successful event unit rewards per run before preferring relics
    eventMutationPickCap = opts.eventMutationPickCap, -- lab-only: max successful mutation rewards per run before preferring relics
    eventUnitRelicMargin = opts.eventUnitRelicMargin, -- lab-only: unit rewards must beat an offered relic by this much
    compMutator = opts.compMutator, -- lab-only overlay appliqué aux deux camps avant Match.run (pacing, probes)
    leftMutator = opts.leftMutator, -- lab-only overlay appliqué au joueur seulement (candidate balance)
    rightMutator = opts.rightMutator, -- lab-only overlay appliqué à l'adversaire seulement
    opponentMode = opts.opponentMode or "static", -- static | generated ; generated mirrors Build:startCombat cold-start IA
    opponentPressure = opts.opponentPressure or {}, -- lab-only knobs for generated opponent pressure
    recordBoards = opts.recordBoards == true, -- lab-only: snapshots légers board+bench par round pour diagnostics
    recordEvents = opts.recordEvents == true, -- lab-only: achats/ventes/reliques par round pour funnels de plan
    relicsKnown = opts.relicsKnown or false, -- reliques pré-connues au Grimoire ? (le driver n'a pas d'IO)
    opponentFn = opts.opponent,              -- (driver) -> compo droite ; défaut PvE escaladante
    over = nil, pendingRelics = nil, pendingRunEvent = nil, lastResult = nil, events = {},
    pairEvents = {}, mergeEvents = {},
    exactMergeEvents = {}, nextCopyId = 1,
    metrics = {
      buys = 0, buyGold = 0,
      sells = 0, sellGold = 0,
      benchSells = 0, benchSellGold = 0,
      boardSells = 0, boardSellGold = 0,
      pairBuys = 0, mergeBuys = 0,
      pairSupportOffers = 0,
      rerolls = 0, rerollGold = 0,
      xpBuys = 0, xpGold = 0,
      slotAccepts = 0, slotDeclines = 0, slotDeclineGold = 0,
      commanderAccepts = 0, commanderDeclines = 0, commanderDeclineGold = 0,
      commanderPlacements = 0,
      boardDeploys = 0, boardSwaps = 0,
      relicPicks = 0,
      eventPicks = 0, eventRelics = 0, eventUnits = 0, eventUnitFailures = 0,
      eventUnitSingles = 0, eventUnitPairCompleters = 0, eventUnitMergeCompleters = 0,
      eventUnitToBench = 0, eventUnitToBoard = 0,
      eventMutations = 0, eventMutationFailures = 0,
      eventGold = 0, eventShopXp = 0, eventShopTierUps = 0,
    },
  }, Rundriver)
  build.mergeObserver = function(ev) self:_recordExactMerge(ev) end
  return self
end

local METRIC_KEYS = {
  "buys", "buyGold", "sells", "sellGold",
  "benchSells", "benchSellGold", "boardSells", "boardSellGold",
  "pairBuys", "mergeBuys", "pairSupportOffers",
  "rerolls", "rerollGold", "xpBuys", "xpGold",
  "slotAccepts", "slotDeclines", "slotDeclineGold",
  "commanderAccepts", "commanderDeclines", "commanderDeclineGold", "commanderPlacements",
  "boardDeploys", "boardSwaps",
  "relicPicks",
  "eventPicks", "eventRelics", "eventUnits", "eventUnitFailures",
  "eventUnitSingles", "eventUnitPairCompleters", "eventUnitMergeCompleters",
  "eventUnitToBench", "eventUnitToBoard",
  "eventMutations", "eventMutationFailures",
  "eventGold", "eventShopXp", "eventShopTierUps",
}

function Rundriver:_metric(key, n)
  self.metrics[key] = (self.metrics[key] or 0) + (n or 1)
end

function Rundriver:_event(ev)
  if not self.recordEvents then return end
  ev = ev or {}
  ev.round = ev.round or self.run.round
  ev.shopTier = ev.shopTier or self.run.shopTier
  self.events[#self.events + 1] = ev
end

function Rundriver:_newCopyId()
  local id = self.nextCopyId or 1
  self.nextCopyId = id + 1
  return id
end

function Rundriver:_ensureCopyId(sr)
  if not sr then return nil end
  if not sr.copyId then sr.copyId = self:_newCopyId() end
  return sr.copyId
end

function Rundriver:_ensureCopyIds()
  for i = 1, 9 do self:_ensureCopyId(self.build.slotRigs[i]) end
  for i = 1, #(self.build.benchSlots or {}) do self:_ensureCopyId(self.build.bench[i]) end
end

function Rundriver:copyRefs(id, level)
  self:_ensureCopyIds()
  local out = {}
  level = level or 1
  for i = 1, 9 do
    local sr = self.build.slotRigs[i]
    if sr and sr.id == id and (sr.level or 1) == level then
      out[#out + 1] = { where = "board", slot = i, copyId = self:_ensureCopyId(sr), id = id, level = level }
    end
  end
  for i = 1, #(self.build.benchSlots or {}) do
    local sr = self.build.bench[i]
    if sr and sr.id == id and (sr.level or 1) == level then
      out[#out + 1] = { where = "bench", slot = i, copyId = self:_ensureCopyId(sr), id = id, level = level }
    end
  end
  return out
end

local function copyIdsFromRefs(refs, limit, extra)
  local out = {}
  for i = 1, math.min(limit or #refs, #refs) do out[#out + 1] = refs[i].copyId end
  if extra then out[#out + 1] = extra end
  return out
end

local function mergeConsumedCopyIds(ev)
  local out = {}
  if ev and ev.keep and ev.keep.copyId then out[#out + 1] = ev.keep.copyId end
  for _, c in ipairs((ev and ev.consumed) or {}) do
    if c.copyId then out[#out + 1] = c.copyId end
  end
  return out
end

function Rundriver:_recordExactMerge(ev)
  ev = ev or {}
  local row = {
    id = ev.id,
    level = ev.fromLevel or 1,
    toLevel = ev.toLevel,
    round = self.run.round,
    shopTier = self.run.shopTier,
    source = ev.source,
    copyIds = mergeConsumedCopyIds(ev),
    keepCopyId = ev.keep and ev.keep.copyId or nil,
    resultCopyId = ev.result and ev.result.copyId or nil,
  }
  self.exactMergeEvents[#self.exactMergeEvents + 1] = row
  self:_event({
    type = "merge_resolve", id = row.id, level = row.level, toLevel = row.toLevel,
    source = row.source, copyIds = row.copyIds, keepCopyId = row.keepCopyId,
    resultCopyId = row.resultCopyId,
  })
end

local function copyList(list)
  local out = {}
  for i, v in ipairs(list or {}) do out[i] = v end
  return out
end

local function relicIds(run)
  local out = {}
  for _, r in ipairs((run and run.relics) or {}) do
    out[#out + 1] = type(r) == "table" and r.id or r
  end
  return out
end

function Rundriver:metricSnapshot()
  local out = {}
  for _, k in ipairs(METRIC_KEYS) do out[k] = self.metrics[k] or 0 end
  return out
end

local function metricDelta(after, before)
  local out = {}
  for _, k in ipairs(METRIC_KEYS) do out[k] = (after[k] or 0) - (before[k] or 0) end
  return out
end

function Rundriver:shopSnapshot()
  local shop = {}
  for i, o in ipairs(self.run.shop) do
    shop[i] = {
      id = o.id, cost = o.cost, sold = o.sold, playable = self:offerPlayable(i),
      support = o.support, replacedId = o.replacedId,
    }
  end
  return shop
end

function Rundriver.shopFullCost(shop)
  local cost = 0
  for _, o in ipairs(shop or {}) do
    if o and not o.sold then cost = cost + (o.cost or 0) end
  end
  return cost
end

-- ── Lecture : état sérialisable (sert au log de trajectoire ET au get_state du MCP) ──
function Rundriver:state()
  local board = {}
  for i = 1, 9 do
    local sr = self.build.slotRigs[i]
    board[i] = { slot = i, unlocked = self.build.board.slots[i].unlocked,
      id = sr and sr.id or nil, level = sr and (sr.level or 1) or nil }
  end
  local bench = {}
  local benchUsed = 0
  for i = 1, #(self.build.benchSlots or {}) do
    local sr = self.build.bench[i]
    if sr then benchUsed = benchUsed + 1 end
    bench[i] = { slot = i, id = sr and sr.id or nil, level = sr and (sr.level or 1) or nil }
  end
  local shop = self:shopSnapshot()
  return {
    round = self.run.round, gold = self.run.gold, lives = self.run.lives,
    wins = self.run.wins, losses = self.run.losses, slots = self.run.slots,
    shopTier = self.run.shopTier, shopXp = self.run.shopXp, xpToNext = self.run:xpToNext(),
    economy = self.run.economy and self.run.economy.id or "baseline",
    rerollCost = self.run:currentRerollCost(), buyXpCost = self.run:currentBuyXpCost(),
    buyXpAmount = self.run:currentBuyXpAmount(),
    pendingSlotGrant = self.run.pendingSlotGrant, slotGrantsResolved = self.run.slotGrantsResolved,
    pendingCommanderGrant = self.run.pendingCommanderGrant, commanderUnlocked = self.run.commanderUnlocked,
    commander = self.build.commanderSlot and self.build.commanderSlot.id or nil,
    commanderLevel = self.build.commanderSlot and (self.build.commanderSlot.level or 1) or nil,
    sigil = self.build.board.shape.name, winStreak = self.run.winStreak, lossStreak = self.run.lossStreak,
    shop = shop, board = board, relics = #self.run.relics, placed = self.build:placedCount(),
    benchSize = #(self.build.benchSlots or {}),
    bench = bench, benchUsed = benchUsed, benchFree = #(self.build.benchSlots or {}) - benchUsed,
    pendingRelics = self.pendingRelics, pendingRunEvent = self.pendingRunEvent, over = self.over,
  }
end

function Rundriver:firstEmptySlot()
  for i = 1, 9 do
    if self.build.board.slots[i].unlocked and not self.build.slotRigs[i] then return i end
  end
  return nil
end

function Rundriver:firstEmptyBench()
  for i = 1, #(self.build.benchSlots or {}) do
    if not self.build.bench[i] then return i end
  end
  return nil
end

function Rundriver:hasBuySpace()
  return self:firstEmptySlot() ~= nil or self:firstEmptyBench() ~= nil
end

function Rundriver:offerPlayable(shopIndex)
  return self.build:offerPlayable(self.run.shop[shopIndex])
end

function Rundriver:copyCount(id, level)
  if not id then return 0 end
  level = level or 1
  local n = 0
  for i = 1, 9 do
    local sr = self.build.slotRigs[i]
    if sr and sr.id == id and (sr.level or 1) == level then n = n + 1 end
  end
  for i = 1, #(self.build.benchSlots or {}) do
    local sr = self.build.bench[i]
    if sr and sr.id == id and (sr.level or 1) == level then n = n + 1 end
  end
  return n
end

local function pairSupportConfig(economy)
  local cfg = economy and economy.pairCompletionSupport
  if cfg == true then return {} end
  if type(cfg) == "table" then return cfg end
  return nil
end

local function unitRank(id)
  local u = Units[id]
  return u and (u.rank or 1) or 1
end

function Rundriver:_pairCompletionCandidates()
  self:_ensureCopyIds()
  local counts = {}
  for i = 1, 9 do
    local sr = self.build.slotRigs[i]
    if sr and (sr.level or 1) == 1 then counts[sr.id] = (counts[sr.id] or 0) + 1 end
  end
  for i = 1, #(self.build.benchSlots or {}) do
    local sr = self.build.bench[i]
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

local function prioritizedPairSupportCandidates(policy, drv, candidates, source)
  if policy and policy.prioritizePairSupport then
    local candidateSet = {}
    for _, id in ipairs(candidates or {}) do candidateSet[id] = true end
    local rows = policy:prioritizePairSupport(drv, copyList(candidates), source)
    local out, seen = {}, {}
    if type(rows) == "table" then
      for _, row in ipairs(rows) do
        local id = type(row) == "table" and row.id or row
        if candidateSet[id] and not seen[id] then
          seen[id] = true
          out[#out + 1] = id
        end
      end
    end
    for _, id in ipairs(candidates or {}) do
      if not seen[id] then out[#out + 1] = id end
    end
    return out
  end
  return candidates
end

function Rundriver:_pairSupportCountForRound()
  local round = self.run.round or 0
  if self.pairSupportRound ~= round then
    self.pairSupportRound = round
    self.pairSupportCount = 0
  end
  return self.pairSupportCount or 0
end

function Rundriver:applyShopSupport(source)
  local cfg = pairSupportConfig(self.run.economy)
  if not cfg then return false end
  if (self.run.round or 0) < (cfg.minRound or 1) then return false end
  if self:_pairSupportCountForRound() >= (cfg.maxPerRound or 1) then return false end
  local candidates = prioritizedPairSupportCandidates(self.policy, self, self:_pairCompletionCandidates(), source)
  if #candidates == 0 then return false end
  local candidateSet, offered = {}, {}
  for _, id in ipairs(candidates) do candidateSet[id] = true end
  for _, offer in ipairs(self.run.shop or {}) do
    if offer and not offer.sold and candidateSet[offer.id] then offered[offer.id] = true end
  end
  self.pairSupportMisses = self.pairSupportMisses or {}
  for id in pairs(self.pairSupportMisses) do
    if not candidateSet[id] then self.pairSupportMisses[id] = nil end
  end
  local id
  local minMissed = cfg.minMissedWindows or 0
  for _, candidate in ipairs(candidates) do
    if offered[candidate] then
      self.pairSupportMisses[candidate] = 0
    else
      self.pairSupportMisses[candidate] = (self.pairSupportMisses[candidate] or 0) + 1
      if not id and self.pairSupportMisses[candidate] >= minMissed then id = candidate end
    end
  end
  if not id then return false end
  local slot
  for i = #(self.run.shop or {}), 1, -1 do
    local offer = self.run.shop[i]
    if offer and not offer.sold and not offer.frozen then slot = i; break end
  end
  if not slot then return false end
  local old = self.run.shop[slot]
  self.run.shop[slot] = {
    id = id,
    cost = self.run:unitCost(id),
    sold = false,
    support = "pair_completion",
    replacedId = old and old.id or nil,
  }
  self.pairSupportCount = (self.pairSupportCount or 0) + 1
  self:_metric("pairSupportOffers", 1)
  self:_event({
    type = "shop_support", support = "pair_completion", source = source,
    id = id, slot = slot, replacedId = old and old.id or nil,
  })
  return true
end

function Rundriver:_recordBuyProgress(id, sameLevelCopies, level, existingRefs, newCopyId)
  existingRefs = existingRefs or {}
  if sameLevelCopies >= 2 then
    self:_metric("mergeBuys", 1)
    self.mergeEvents[#self.mergeEvents + 1] = {
      id = id, level = level or 1, round = self.run.round, shopTier = self.run.shopTier,
      copyIds = copyIdsFromRefs(existingRefs, 2, newCopyId),
    }
    return "merge"
  elseif sameLevelCopies == 1 then
    self:_metric("pairBuys", 1)
    self.pairEvents[#self.pairEvents + 1] = {
      id = id, level = level or 1, round = self.run.round, shopTier = self.run.shopTier,
      copyIds = copyIdsFromRefs(existingRefs, 1, newCopyId),
    }
    return "pair"
  end
  return "single"
end

-- ── Actions joueur (toutes renvoient un résultat exploitable ; refus = false/nil, jamais d'exception) ──

-- Achète l'offre i. Sans `slot`, utilise le chemin joueur Build:autoBuy : 1re case board vide, sinon banc,
-- sinon fusion si tout est plein. Avec `slot`, force une pose plateau précise pour les tests/actions ciblées.
-- Dans tous les cas, l'or n'est débité que si le placement/fusion est garanti.
function Rundriver:buy(shopIndex, slot)
  local offer = self.run.shop[shopIndex]
  local cost = offer and offer.cost or 0
  if not offer or offer.sold then return false end
  self:_ensureCopyIds()
  local existingRefs = self:copyRefs(offer.id, 1)
  local newCopyId = self:_newCopyId()
  local sameLevelCopies = self:copyCount(offer.id, 1)
  if slot == nil then
    local id = offer.id
    if not self.build:autoBuy(shopIndex, { copyId = newCopyId }) then return false end
    self:_metric("buys", 1)
    self:_metric("buyGold", cost)
    local progress = self:_recordBuyProgress(id, sameLevelCopies, 1, existingRefs, newCopyId)
    self:_event({ type = "buy", id = id, cost = cost, progress = progress, copyId = newCopyId })
    return id
  end
  slot = slot or self:firstEmptySlot()
  if not slot then return false end
  local bs = self.build.board.slots[slot]
  if not (bs and bs.unlocked) or self.build.slotRigs[slot] then return false end
  local id = self.run:buy(shopIndex)
  if not id then return false end
  self:_metric("buys", 1)
  self:_metric("buyGold", cost)
  local progress = self:_recordBuyProgress(id, sameLevelCopies, 1, existingRefs, newCopyId)
  self:_event({ type = "buy", id = id, cost = cost, progress = progress, slot = slot, copyId = newCopyId })
  self.build:placeId(slot, id, 1, { copyId = newCopyId })
  self.build:checkMerges() -- 3 copies (même id+niveau) -> niveau+1 (cascade)
  return id
end

-- Vend l'unité d'un slot (remboursement) et vide la case.
function Rundriver:sell(slot)
  local sr = self.build.slotRigs[slot]
  if not sr then return false end
  local before = self.run.gold
  self.run:sell(sr.id)
  self:_metric("sells", 1)
  self:_metric("sellGold", self.run.gold - before)
  self:_metric("boardSells", 1)
  self:_metric("boardSellGold", self.run.gold - before)
  self:_event({
    type = "sell", id = sr.id, level = sr.level or 1,
    where = "board", slot = slot, gold = self.run.gold - before,
    copyId = sr.copyId,
  })
  self.build.slotRigs[slot] = nil
  self.build.board.slots[slot].unit = nil
  return true
end

function Rundriver:sellBench(slot)
  local sr = self.build.bench[slot]
  if not sr then return false end
  local before = self.run.gold
  self.run:sell(sr.id)
  self:_metric("sells", 1)
  self:_metric("sellGold", self.run.gold - before)
  self:_metric("benchSells", 1)
  self:_metric("benchSellGold", self.run.gold - before)
  self:_event({
    type = "sell", id = sr.id, level = sr.level or 1,
    where = "bench", slot = slot, gold = self.run.gold - before,
    copyId = sr.copyId,
  })
  self.build.bench[slot] = nil
  return true
end

function Rundriver:reroll()
  local cost = self.run:currentRerollCost()
  local ok = self.run:reroll()
  if ok then
    self:applyShopSupport("reroll")
    self:_metric("rerolls", 1)
    self:_metric("rerollGold", cost)
    self:_event({ type = "shop_roll", cost = cost, shop = self:shopSnapshot() })
  end
  return ok
end

function Rundriver:buyXp()
  local cost = self.run:currentBuyXpCost()
  local ok = self.run:buyXp()
  if ok then
    self:_metric("xpBuys", 1)
    self:_metric("xpGold", cost)
  end
  return ok
end

-- ── Grant d'emplacement timé (remplace l'ancien levelUp payant). À une offre en attente (run.pendingSlotGrant) :
--   acceptSlotGrant(cell) : +1 capacité + OUVRE une case (la `cell` choisie, ou la meilleure case vide = cluster
--                           central connexe). Renvoie l'index ouvert (placement libre côté UI/politique/MCP).
--   declineSlotGrant()    : refuse -> +or (jeu « tall »), capacité inchangée. ──
function Rundriver:acceptSlotGrant(cell)
  if not self.run:acceptSlotGrant() then return false end
  self:_metric("slotAccepts", 1)
  if not (cell and self.build.board:openCell(cell)) then
    self.build.board:ensureOpen(self.run.slots) -- défaut : ouvre la meilleure case vide (cluster central)
  end
  return true
end

function Rundriver:declineSlotGrant()
  local before = self.run.gold
  local ok = self.run:declineSlotGrant()
  if ok then
    self:_metric("slotDeclines", 1)
    self:_metric("slotDeclineGold", self.run.gold - before)
  end
  return ok
end

function Rundriver:acceptCommanderGrant()
  local ok = self.run:acceptCommanderGrant()
  if ok then self:_metric("commanderAccepts", 1) end
  return ok
end

function Rundriver:declineCommanderGrant()
  local before = self.run.gold
  local ok = self.run:declineCommanderGrant()
  if ok then
    self:_metric("commanderDeclines", 1)
    self:_metric("commanderDeclineGold", self.run.gold - before)
  end
  return ok
end

local function canCommand(id)
  local u = id and Units[id]
  return u and u.commandBonus ~= nil
end

local function commanderCandidateScore(c)
  local u = Units[c.id] or {}
  local score = (c.level or 1) * 100 + (u.rank or 1) * 10 + (u.cost or 1)
  if c.where == "bench" then score = score + 40 end
  return score
end

function Rundriver:commanderCandidates()
  local out = {}
  for i = 1, #(self.build.benchSlots or {}) do
    local sr = self.build.bench[i]
    if sr and canCommand(sr.id) then
      out[#out + 1] = { where = "bench", slot = i, id = sr.id, level = sr.level or 1 }
    end
  end
  for i = 1, 9 do
    local sr = self.build.slotRigs[i]
    if sr and canCommand(sr.id) then
      out[#out + 1] = { where = "board", slot = i, id = sr.id, level = sr.level or 1 }
    end
  end
  table.sort(out, function(a, b)
    local sa, sb = commanderCandidateScore(a), commanderCandidateScore(b)
    if sa ~= sb then return sa > sb end
    if a.where ~= b.where then return a.where < b.where end
    if a.id ~= b.id then return a.id < b.id end
    return a.slot < b.slot
  end)
  return out
end

function Rundriver:placeCommander(candidate)
  if not candidate or self.build.commanderSlot or not self.run.commanderUnlocked then return false end
  local sr
  if candidate.where == "bench" then
    sr = self.build.bench[candidate.slot]
    if not (sr and sr.id == candidate.id and canCommand(sr.id)) then return false end
    self.build.bench[candidate.slot] = nil
  elseif candidate.where == "board" then
    sr = self.build.slotRigs[candidate.slot]
    if not (sr and sr.id == candidate.id and canCommand(sr.id)) then return false end
    self.build.slotRigs[candidate.slot] = nil
    self.build.board.slots[candidate.slot].unit = nil
  else
    return false
  end
  self.build.commanderSlot = self.build:cloneOcc(sr)
  self:_metric("commanderPlacements", 1)
  self:_event({
    type = "commander_place",
    id = sr.id,
    level = sr.level or 1,
    from = candidate.where,
    slot = candidate.slot,
  })
  return true
end

local function chooseCommanderCandidate(policy, drv, candidates)
  if policy and policy.chooseCommanderCandidate then
    local choice = policy:chooseCommanderCandidate(drv, candidates)
    if type(choice) == "number" then return candidates[choice] end
    if type(choice) == "table" then return choice end
  end
  return candidates and candidates[1] or nil
end

function Rundriver:resolveCommanderMode(policy)
  local mode = self.commanderMode or "ignore"
  if mode == "ignore" then return nil end
  if self.run.pendingCommanderGrant then
    local candidates = self:commanderCandidates()
    self:_event({
      type = "commander_window",
      pending = true,
      unlocked = self.run.commanderUnlocked,
      candidates = candidates,
    })
    if mode == "decline" then
      if self:declineCommanderGrant() then return { mode = mode, action = "decline" } end
      return { mode = mode, action = "decline_failed" }
    end
    if #candidates == 0 then
      if self:declineCommanderGrant() then return { mode = mode, action = "decline_no_candidate" } end
      return { mode = mode, action = "decline_failed" }
    end
    if self:acceptCommanderGrant() then
      local c = chooseCommanderCandidate(policy, self, candidates)
      local placed = self:placeCommander(c)
      return { mode = mode, action = placed and "accept_place" or "accept_place_failed", id = c.id, from = c.where }
    end
    return { mode = mode, action = "accept_failed" }
  elseif self.run.commanderUnlocked and not self.build.commanderSlot then
    local candidates = self:commanderCandidates()
    self:_event({
      type = "commander_window",
      pending = false,
      unlocked = true,
      candidates = candidates,
    })
    if #candidates > 0 then
      local c = chooseCommanderCandidate(policy, self, candidates)
      local placed = self:placeCommander(c)
      return { mode = mode, action = placed and "place" or "place_failed", id = c.id, from = c.where }
    end
  end
  return nil
end

-- Déplace/échange une unité de `from` vers `to` (mirroir du drag case->case de build.lua).
function Rundriver:move(from, to)
  local d = self.build.slotRigs[from]
  if not d then return false end
  local bs = self.build.board.slots[to]
  if not (bs and bs.unlocked) then return false end
  local occ = self.build.slotRigs[to]
  self.build.slotRigs[to] = d; self.build.board.slots[to].unit = d.id
  if occ and from ~= to then
    self.build.slotRigs[from] = occ; self.build.board.slots[from].unit = occ.id
  elseif from ~= to then
    self.build.slotRigs[from] = nil; self.build.board.slots[from].unit = nil
  end
  return true
end

function Rundriver:moveBenchToBoard(benchSlot, boardSlot)
  local sr = self.build.bench[benchSlot]
  if not sr then return false end
  local bs = self.build.board.slots[boardSlot]
  if not (bs and bs.unlocked) then return false end
  local occ = self.build.slotRigs[boardSlot]
  self.build.slotRigs[boardSlot] = sr
  self.build.board.slots[boardSlot].unit = sr.id
  self.build.bench[benchSlot] = occ
  self:_metric("boardDeploys", 1)
  if occ then self:_metric("boardSwaps", 1) end
  self:_event({
    type = "move",
    from = "bench",
    fromSlot = benchSlot,
    to = "board",
    toSlot = boardSlot,
    id = sr.id,
    level = sr.level or 1,
    copyId = sr.copyId,
    replacedId = occ and occ.id or nil,
    replacedLevel = occ and (occ.level or 1) or nil,
    replacedCopyId = occ and occ.copyId or nil,
  })
  return true
end

function Rundriver:moveBoardToBench(boardSlot, benchSlot)
  local sr = self.build.slotRigs[boardSlot]
  if not sr then return false end
  local bs = self.build.board.slots[boardSlot]
  if not (bs and bs.unlocked) then return false end
  if benchSlot < 1 or benchSlot > #(self.build.benchSlots or {}) then return false end
  local occ = self.build.bench[benchSlot]
  self.build.bench[benchSlot] = sr
  self.build.slotRigs[boardSlot] = occ
  self.build.board.slots[boardSlot].unit = occ and occ.id or nil
  self:_metric("boardDeploys", 1)
  if occ then self:_metric("boardSwaps", 1) end
  self:_event({
    type = "move",
    from = "board",
    fromSlot = boardSlot,
    to = "bench",
    toSlot = benchSlot,
    id = sr.id,
    level = sr.level or 1,
    copyId = sr.copyId,
    replacedId = occ and occ.id or nil,
    replacedLevel = occ and (occ.level or 1) or nil,
    replacedCopyId = occ and occ.copyId or nil,
  })
  return true
end

-- Reshape le plateau vers un sigil (la topologie/adjacence change ; les unités restent dans leurs slots).
function Rundriver:reshape(sigil)
  if require("src.board.board").SIGILS_PAUSED then return false end -- sigils en PAUSE -> action indisponible
  if not Shapes[sigil] then return false end
  self.build.board:setShape(sigil)
  self.build:computeLayout()
  return true
end

-- ── Adversaire : PvE escaladante (encounters par round) par défaut ; pluggable via opts.opponent ──
function Rundriver:opponent(seed)
  if self.opponentFn then return self.opponentFn(self, seed) end
  if self.opponentMode == "generated" then
    local enc = OppGen.generate({
      round = self.run.round,
      tier = self.run.shopTier,
      slots = self.run.slots,
      rng = love.math.newRandomGenerator(seed or (self.run.seed or 0)),
      odds = self.run.ODDS,
      roundBonus = self.opponentPressure.roundBonus,
      tierBonus = self.opponentPressure.tierBonus,
      sizeBonus = self.opponentPressure.sizeBonus,
      levelMult = self.opponentPressure.levelMult,
    })
    enc.key = self.build:encounterKeyFor(#enc.units)
    return self.build:buildRightComp(enc, 0), enc.key
  end
  local enc, bump = self.build:pickEncounter()
  return self.build:buildRightComp(enc, bump), enc.key
end

function Rundriver:_mutateComp(comp, side)
  if self.compMutator then self.compMutator(comp, side, self) end
  if side == "left" and self.leftMutator then self.leftMutator(comp, self) end
  if side == "right" and self.rightMutator then self.rightMutator(comp, self) end
end

function Rundriver:_startRound(source)
  self.run:startRound()
  self:applyShopSupport(source or "start_round")
end

function Rundriver:runEventRollOptions()
  local mode = self.eventUnitTargeting
  if not mode and not self.runEventMutations then return nil end
  local policy = self.policy
  local opts = {}
  local function modeHas(part)
    return type(mode) == "string" and mode:find(part, 1, true) ~= nil
  end
  if modeHas("missing_copy") then
    opts.unitFilter = function(id, rewardSpec)
      local level = math.max(1, math.min(2, (rewardSpec and rewardSpec.level) or 1))
      return self:copyCount(id, level) > 0
    end
  end
  if modeHas("space") then
    local previousFilter = opts.unitFilter
    opts.unitFilter = function(id, rewardSpec)
      if previousFilter and not previousFilter(id, rewardSpec) then return false end
      local level = math.max(1, math.min(2, (rewardSpec and rewardSpec.level) or 1))
      return EventRewards.canGrantUnit(self.build, id, level)
    end
  end
  if (mode == "policy" or modeHas("policy")) and policy and policy.runEventUnitPriority then
    opts.unitPriority = function(id, rewardSpec)
      return policy:runEventUnitPriority(self, id, rewardSpec)
    end
  end
  if self.runEventMutations then
    opts.mutationTarget = function(rewardSpec)
      return self:bestMutationTarget(rewardSpec)
    end
  end
  if not opts.unitFilter and not opts.unitPriority and not opts.mutationTarget then return nil end
  return opts
end

function Rundriver:bestMutationTarget(spec)
  if not self.runEventMutations then return nil end
  self:_ensureCopyIds()
  spec = spec or {}
  local minRank = math.max(1, math.min(5, spec.rank or spec.rankMin or 1))
  local maxRank = math.max(minRank, math.min(5, spec.rank or spec.rankMax or 5))
  local best, bestScore
  local function consider(where, slot, sr)
    if not sr or (sr.mutations and #sr.mutations > 0) then return end
    local u = Units[sr.id]
    local rank = u and (u.rank or 1) or 1
    if rank < minRank or rank > maxRank then return end
    local level = sr.level or 1
    local score = ((where == "board") and 1000 or 0) + level * 120 + rank * 12 + (u and (u.dmg or 0) or 0)
    if not bestScore or score > bestScore or (score == bestScore and slot < best.slot) then
      bestScore = score
      best = { copyId = sr.copyId, where = where, slot = slot, id = sr.id, level = level }
    end
  end
  for i = 1, 9 do consider("board", i, self.build.slotRigs[i]) end
  for i = 1, #(self.build.benchSlots or {}) do consider("bench", i, self.build.bench[i]) end
  return best
end

function Rundriver:grantUnitReward(reward)
  reward = reward or {}
  local id = reward.id
  if not Units[id] then
    self:_metric("eventUnitFailures", 1)
    return false
  end
  self:_ensureCopyIds()
  local copyId = self:_newCopyId()
  local occ = self.build:makeOcc(id, math.max(1, math.min(2, reward.level or 1)), {
    copyId = copyId,
    mutations = reward.mutations,
  })
  local sameLevelCopies = self:copyCount(id, occ.level)
  if not self.build:stowUnit(occ) then
    self:_metric("eventUnitFailures", 1)
    self:_event({ type = "run_event_reward_failed", reason = "no_space", kind = "unit", id = id, level = occ.level })
    return false
  end
  local loc = self:copyLocation(copyId)
  local progress = "single"
  if sameLevelCopies >= 2 then
    progress = "merge"
    self:_metric("eventUnitMergeCompleters", 1)
  elseif sameLevelCopies == 1 then
    progress = "pair"
    self:_metric("eventUnitPairCompleters", 1)
  else
    self:_metric("eventUnitSingles", 1)
  end
  if loc and loc.where == "bench" then self:_metric("eventUnitToBench", 1) end
  if loc and loc.where == "board" then self:_metric("eventUnitToBoard", 1) end
  self:_metric("eventUnits", 1)
  self:_event({
    type = "unit_reward", id = id, level = occ.level, copyId = copyId,
    progress = progress, where = loc and loc.where or nil, slot = loc and loc.slot or nil,
  })
  self.build:checkMerges()
  return true
end

function Rundriver:grantMutationReward(reward)
  reward = reward or {}
  local mutationId = reward.id or reward.mutation
  if not Mutations.byId[mutationId] then
    self:_metric("eventMutationFailures", 1)
    return false
  end
  local target = reward.target or {}
  local loc = target.copyId and self:copyLocation(target.copyId) or nil
  if not loc and target.where and target.slot then loc = { where = target.where, slot = target.slot } end
  local sr
  if loc and loc.where == "board" then sr = self.build.slotRigs[loc.slot]
  elseif loc and loc.where == "bench" then sr = self.build.bench[loc.slot] end
  if not sr or (target.copyId and sr.copyId ~= target.copyId) or (sr.mutations and #sr.mutations > 0) then
    self:_metric("eventMutationFailures", 1)
    self:_event({ type = "run_event_reward_failed", reason = "bad_mutation_target", kind = "mutation", id = mutationId })
    return false
  end
  sr.mutations = Mutations.clone({ mutationId })
  self:_metric("eventMutations", 1)
  self:_event({
    type = "mutation_reward",
    id = mutationId,
    targetId = sr.id,
    level = sr.level or 1,
    copyId = sr.copyId,
    where = loc and loc.where or nil,
    slot = loc and loc.slot or nil,
  })
  return true
end

function Rundriver:applyRunEventReward(reward)
  reward = reward or {}
  if reward.kind == "unit" then return self:grantUnitReward(reward) end
  if reward.kind == "mutation" then return self:grantMutationReward(reward) end
  local beforeGold, beforeXp, beforeTier, beforeRelics = self.run.gold, self.run.shopXp, self.run.shopTier, #self.run.relics
  local ok = self.run:applyRunEventReward(reward)
  if not ok then
    self:_event({ type = "run_event_reward_failed", reason = "unsupported", kind = reward.kind })
    return false
  end
  if reward.kind == "relic" then
    self:_metric("eventRelics", 1)
  elseif reward.kind == "gold" then
    self:_metric("eventGold", self.run.gold - beforeGold)
  elseif reward.kind == "shop_xp" then
    self:_metric("eventShopXp", math.max(0, (reward.amount or 0)))
  elseif reward.kind == "shop_tier_up" then
    self:_metric("eventShopTierUps", self.run.shopTier - beforeTier)
  end
  self:_event({
    type = "run_event_reward", kind = reward.kind, id = reward.id, amount = reward.amount,
    goldDelta = self.run.gold - beforeGold,
    shopXpDelta = self.run.shopXp - beforeXp,
    shopTierDelta = self.run.shopTier - beforeTier,
    relicDelta = #self.run.relics - beforeRelics,
  })
  return true
end

-- ── Combat + avancement de la méta-boucle (mirroir de host.finishCombat, SANS IO Grimoire) ──
-- Renvoie { result, over?, relicChoices? }. Si relicChoices : le round N'EST PAS avancé -> il FAUT
-- appeler pickRelic ensuite (l'agent/la politique choisit). Sinon le round suivant est ouvert (startRound).
function Rundriver:fight()
  local left = self.build:buildLeftComp()
  if #left == 0 then return { error = "empty_board" } end
  self.run:applyRelics(left) -- reliques : effet RÉEL sur la compo joueur (comme au build)
  self:_mutateComp(left, "left")
  local seed = self.run:nextCombatSeed()
  local right, enemyKey = self:opponent(seed)
  self:_mutateComp(right, "right")
  local res = Match.run(left, right, seed, {
    tickCap = self.tickCap,
    hpMult = self.hpMult,
    cooldownMult = self.cooldownMult,
    fatigue = self.fatigue,
  })
  res.enemyKey = enemyKey
  self.lastResult = res

  self.run:resolve(res.win)
  self.over = self.run:isOver()
  if self.over then return { result = res, over = self.over } end

  -- Canal 3 live : jalons victoire 3/6 = relique garantie a plancher mid.
  if res.win and (self.run.wins == 3 or self.run.wins == 6) then
    local choices = self.run:rollRelicChoices(3, { minTier = "mid" })
    if #choices > 0 then
      self.pendingRelics = choices
      self:_event({
        type = "relic_offer", channel = "milestone", choices = copyList(choices),
        reward_round = self.run.round, wins = self.run.wins,
      })
      return { result = res, relicChoices = choices }
    end
  end

  -- Canal marchand : tous les 3 COMBATS, comme le host live. Par defaut, le
  -- lab garde l'offre de relique pour comparer les anciens rapports. En mode
  -- opt-in `runEvents=true`, ce meme creneau devient une rencontre thematique
  -- avec recompenses explicites (relique, unite, or, XP/tier boutique).
  local combats = self.run.wins + self.run.losses
  if combats % 3 == 0 then
    if self.runEvents then
      local event = self.run:rollRunEvent(self:runEventRollOptions())
      if event and #(event.choices or {}) > 0 then
        self.pendingRunEvent = event
        self:_event({
          type = "run_event_offer", id = event.id, choices = event.choices,
          reward_round = self.run.round, wins = self.run.wins, losses = self.run.losses,
        })
        return { result = res, runEvent = event }
      end
    else
      local choices = self.run:rollRelicChoices(3)
      if #choices > 0 then
        self.pendingRelics = choices
        self:_event({
          type = "relic_offer", channel = "merchant", choices = copyList(choices),
          reward_round = self.run.round, wins = self.run.wins, losses = self.run.losses,
        })
        return { result = res, relicChoices = choices }
      end
    end
  end
  self:_startRound("combat")
  return { result = res }
end

-- Choisit une relique parmi l'offre en attente (index 1..n), l'octroie, puis ouvre le round suivant.
function Rundriver:pickRelic(choiceIndex)
  if not self.pendingRelics then return false end
  local id = self.pendingRelics[choiceIndex or 1]
  if id then self.run:grantRelic(id) end
  self.pendingRelics = nil
  self:_startRound("relic")
  if id then self:_metric("relicPicks", 1) end
  if id then self:_event({ type = "relic_pick", id = id, choice = choiceIndex or 1 }) end
  return id or false
end

function Rundriver:pickRunEvent(choiceIndex)
  local event = self.pendingRunEvent
  if not event then return false end
  choiceIndex = choiceIndex or 1
  local choice = event.choices and event.choices[choiceIndex]
  if not choice then return false end
  local applied = self:applyRunEventReward(choice.reward)
  self.pendingRunEvent = nil
  self:_metric("eventPicks", 1)
  self:_event({
    type = "run_event_pick", id = event.id, choice = choice.id, choiceIndex = choiceIndex,
    reward = choice.reward, applied = applied and true or false,
  })
  self:_startRound("run_event")
  return choice
end

-- ── Coût d'investissement du board courant (réutilise Compcost, comme une compo de catalogue) ──
function Rundriver:boardComp()
  local units = {}
  for i = 1, 9 do
    local sr = self.build.slotRigs[i]
    if sr then units[#units + 1] = { id = sr.id, slot = i, level = sr.level or 1 } end
  end
  return { sigil = self.build.board.shape.name, boardLevel = self.run.slots, units = units }
end

function Rundriver:boardCost() return Compcost.of(self:boardComp()) end

function Rundriver:supportedBoardComp()
  local comp = self:boardComp()
  local commander = self.build.commanderSlot
  if commander then
    comp.commander = commander.id
    comp.commanderLevel = commander.level or 1
  end
  comp.relics = relicIds(self.run)
  return comp
end

function Rundriver:copyState()
  self:_ensureCopyIds()
  local out = {}
  for i = 1, 9 do
    local sr = self.build.slotRigs[i]
    if sr then
      out[#out + 1] = {
        copyId = sr.copyId, id = sr.id, level = sr.level or 1,
        where = "board", slot = i, mutations = sr.mutations,
      }
    end
  end
  for i = 1, #(self.build.benchSlots or {}) do
    local sr = self.build.bench[i]
    if sr then
      out[#out + 1] = {
        copyId = sr.copyId, id = sr.id, level = sr.level or 1,
        where = "bench", slot = i, mutations = sr.mutations,
      }
    end
  end
  return out
end

function Rundriver:copyLocation(copyId)
  if not copyId then return nil end
  for i = 1, 9 do
    local sr = self.build.slotRigs[i]
    if sr and sr.copyId == copyId then return { where = "board", slot = i } end
  end
  for i = 1, #(self.build.benchSlots or {}) do
    local sr = self.build.bench[i]
    if sr and sr.copyId == copyId then return { where = "bench", slot = i } end
  end
  return nil
end

function Rundriver:heldComp()
  local units = {}
  for i = 1, 9 do
    local sr = self.build.slotRigs[i]
    if sr then units[#units + 1] = { id = sr.id, slot = i, level = sr.level or 1, where = "board" } end
  end
  for i = 1, #(self.build.benchSlots or {}) do
    local sr = self.build.bench[i]
    if sr then units[#units + 1] = { id = sr.id, slot = 9 + i, level = sr.level or 1, where = "bench" } end
  end
  return { sigil = self.build.board.shape.name, boardLevel = self.run.slots, units = units }
end

-- ── Run COMPLÈTE pilotée par une politique -> trajectoire (rounds + décisions + issue + investissement) ──
-- policy = { name, act(self, drv) -> décisions, pickRelic?(self, drv, choices) -> index }.
function Rundriver.run(seed, policy, opts)
  local drv = Rundriver.new(seed, opts)
  drv.policy = policy
  local traj = { seed = seed, policy = policy.name, archetype = policy.archetype, rounds = {} }
  local guard = 0
  while not drv.over and guard < 300 do
    guard = guard + 1
    local before = drv:state()
    local shopFullCost = Rundriver.shopFullCost(before.shop)
    local desired = policy.desiredOffers and policy:desiredOffers(drv) or nil
    local desiredGoldBudget = desired and (desired.goldBudget or before.gold) or nil
    local metricBefore = drv:metricSnapshot()
    local eventBefore = #drv.events
    local commanderDecision = drv:resolveCommanderMode(policy)
    local decisions = policy:act(drv) -- la politique achète/place/reroll/level/reshape via l'API d'actions
    if commanderDecision then
      decisions = decisions or {}
      decisions.commander = commanderDecision
    end
    local afterBuild = drv:state()
    local commitment = policy.commitment and policy:commitment(drv) or nil
    if commitment and commitment.committed and not traj.archetypeCommitRound then
      traj.archetypeCommitRound = before.round
      traj.archetypeCommitment = commitment
    end
    local metricAfter = drv:metricSnapshot()
    local econ = metricDelta(metricAfter, metricBefore)
    if drv.build:placedCount() == 0 then traj.aborted = "empty_board"; break end
    local snap = drv:state()
    local boardAfterBuild, holdingsAfterBuild
    if drv.recordBoards then
      boardAfterBuild = drv:boardComp()
      holdingsAfterBuild = drv:heldComp()
    end
    local fr = drv:fight()
    if fr.error then traj.aborted = fr.error; break end
    if fr.relicChoices then
      local pick = (policy.pickRelic and policy:pickRelic(drv, fr.relicChoices)) or 1
      drv:pickRelic(pick)
    elseif fr.runEvent then
      local pick = (policy.pickRunEvent and policy:pickRunEvent(drv, fr.runEvent)) or 1
      drv:pickRunEvent(pick)
    end
    local row = {
      round = snap.round, gold = snap.gold, startGold = before.gold, buildGold = afterBuild.gold,
      shopTier = before.shopTier, shopFullCost = shopFullCost,
      couldAffordFullShop = before.gold >= shopFullCost,
      desiredOffers = desired and desired.visibleCount or nil,
      desiredOfferCost = desired and desired.visibleCost or nil,
      desiredPlacableOffers = desired and desired.count or nil,
      desiredPlacableCost = desired and desired.cost or nil,
      desiredGoldBudget = desiredGoldBudget,
      desiredSlotLimited = desired and desired.slotLimited or nil,
      desiredGoldAffordable = desired and ((desired.visibleCount or 0) == 0 or desiredGoldBudget >= (desired.visibleCost or 0)) or nil,
      desiredOffersAffordable = desired and ((desired.visibleCount or 0) == 0 or (desiredGoldBudget >= (desired.visibleCost or 0) and not desired.slotLimited)) or nil,
      slots = snap.slots, sigil = snap.sigil, benchSize = snap.benchSize,
      placed = snap.placed, decisions = decisions,
      economy = econ, commitment = commitment,
      win = fr.result and fr.result.win, decided = fr.result and fr.result.decided,
      ticks = fr.result and fr.result.ticks, enemyKey = fr.result and fr.result.enemyKey,
    }
    if drv.recordBoards then
      row.board = boardAfterBuild
      row.holdings = holdingsAfterBuild
    end
    if drv.recordEvents then
      row.shop = before.shop
      row.events = {}
      for i = eventBefore + 1, #drv.events do row.events[#row.events + 1] = drv.events[i] end
    end
    traj.rounds[#traj.rounds + 1] = row
  end
  traj.result = drv.run:isOver() or "incomplete"
  traj.wins, traj.losses, traj.slots = drv.run.wins, drv.run.losses, drv.run.slots
  traj.benchSize = #(drv.build.benchSlots or {})
  traj.finalBoard = drv:boardComp()
  traj.finalSupportedBoard = drv:supportedBoardComp()
  traj.finalCopies = drv:copyState()
  if drv.recordBoards then traj.finalHoldings = drv:heldComp() end
  traj.finalCost = drv:boardCost()
  traj.metrics = drv:metricSnapshot()
  traj.pairEvents = drv.pairEvents
  traj.mergeEvents = drv.mergeEvents
  traj.exactMergeEvents = drv.exactMergeEvents
  traj.economy = drv.run.economy and drv.run.economy.id or "baseline"
  if policy.commitment then traj.finalCommitment = policy:commitment(drv) end
  return traj
end

return Rundriver
