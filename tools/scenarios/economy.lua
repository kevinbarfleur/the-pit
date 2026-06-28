-- tools/scenarios/economy.lua
-- MODE P6 -- ECONOMY VARIANTS. Runs the real policy driver under several
-- opt-in economy profiles and reports pressure, leftover, desired-offer
-- affordability, full-shop affordability, commitment, completion, and spend split.

local Common = require("tools.scenarios.common")
local Economy = require("src.run.economy")
local Rundriver = require("src.lab.rundriver")
local Policies = require("src.lab.policies")
local Compcost = require("src.lab.compcost")
local Compbuild = require("src.lab.compbuild")
local Coherence = require("src.lab.coherence")
local Match = require("src.combat.match")
local Pacing = require("src.run.pacing")
local Relics = require("src.data.relics")
local Units = require("src.data.units")

local N = require("tools.scenarios.argn")(60)
local BASE_SEED = 1060000
local HPM = Common.envNumber("PIT_HP_MULT", nil)
local ORACLE_PACING = Pacing.arenaOptions()
if HPM ~= nil then ORACLE_PACING.hpMult = HPM end
local COMMANDER_MODE = Common.env("PIT_COMMANDER_MODE") or "ignore"
local RUN_EVENTS = Common.envBool("PIT_RUN_EVENTS", false)
local RUN_EVENT_MUTATIONS = Common.envBool("PIT_RUN_EVENT_MUTATIONS", false)
local EVENT_UNIT_TARGETING = Common.env("PIT_EVENT_UNIT_TARGETING")
local EVENT_UNIT_PICK_CAP = Common.envNumber("PIT_EVENT_UNIT_PICK_CAP", nil)
local EVENT_MUTATION_PICK_CAP = Common.envNumber("PIT_EVENT_MUTATION_PICK_CAP", nil)
local EVENT_UNIT_RELIC_MARGIN = Common.envNumber("PIT_EVENT_UNIT_RELIC_MARGIN", nil)
local OPPONENT_MODE = Common.env("PIT_OPPONENT_MODE") or "static"
assert(OPPONENT_MODE == "static" or OPPONENT_MODE == "generated",
  "PIT_OPPONENT_MODE doit etre static ou generated")
local OPPONENT_PRESSURE = {
  roundBonus = Common.envNumber("PIT_OPPGEN_ROUND_BONUS", 0),
  tierBonus = Common.envNumber("PIT_OPPGEN_TIER_BONUS", 0),
  sizeBonus = Common.envNumber("PIT_OPPGEN_SIZE_BONUS", 0),
  levelMult = Common.envNumber("PIT_OPPGEN_LEVEL_MULT", 1),
}
-- Extra holding capacity beyond the real board+bench capacity used by Rundriver.
-- Cap 0 is the current gameplay model; cap 4 answers "what if the player had 4 more reserve slots?"
local BENCH_CAPS = Common.envNumberList("PIT_BENCH_CAPS", { 0, 2, 4, 6 })
-- Real bench capacity used by Rundriver. Default stays live (4); set PIT_BENCH_SIZES=4,6,8 for reserve sweeps.
local BENCH_SIZES = Common.envNumberList("PIT_BENCH_SIZES", { Rundriver.DEFAULT_BENCH_SIZE })
for _, size in ipairs(BENCH_SIZES) do
  assert(size >= 1 and size <= Rundriver.MAX_BENCH_SIZE, "PIT_BENCH_SIZES hors bornes: " .. tostring(size))
end
local ORACLE_MATCHES = Common.envNumber("PIT_PLAN_ORACLE_MATCHES", 3)
local ORACLE_ROUNDS = Common.envNumberList("PIT_PLAN_ORACLE_ROUNDS", nil)
local ECONOMY_ORDER = Common.envCsv("PIT_ECON_PROFILES") or Economy.order
for _, profileId in ipairs(ECONOMY_ORDER) do
  assert(Economy.profiles[profileId], "profil economie inconnu: " .. tostring(profileId))
end

local function benchVariantKey(profileId, benchSize)
  if #BENCH_SIZES == 1 and benchSize == Rundriver.DEFAULT_BENCH_SIZE then return profileId end
  return profileId .. "_bench" .. tostring(benchSize)
end

local VARIANTS = {}
for pi, profileId in ipairs(ECONOMY_ORDER) do
  for bi, benchSize in ipairs(BENCH_SIZES) do
    VARIANTS[#VARIANTS + 1] = {
      key = benchVariantKey(profileId, benchSize),
      profileId = profileId,
      benchSize = benchSize,
      profileIndex = pi,
      benchIndex = bi,
    }
  end
end

local DEFAULT_PLAN_TARGETS = {
  "rot_bleed_mid", "rot_bleed_rat_core", "cross_bleed_rot",
  "rot_carre_perfect", "poison_diamant_perfect", "tank_carre",
}

local function targetFromComp(id)
  local comp = Common.compByIdOrNil(id)
  if not comp then return nil end
  local target = Common.clone(comp)
  target.source = "comp"
  target.cost = Compcost.of(target)
  return target
end

local function trim(s)
  return tostring(s or ""):gsub("^%s+", ""):gsub("%s+$", "")
end

local function plusList(value)
  local out = {}
  for token in tostring(value or ""):gmatch("[^+]+") do
    local v = trim(token)
    if v ~= "" then out[#out + 1] = v end
  end
  return out
end

local function parseCommanderSpec(value, spec)
  local id, level = tostring(value or ""):match("^([^:]+):?(%d*)$")
  id = trim(id)
  assert(id ~= "" and Units[id], "PIT_PLAN_TARGET_SPECS commandant inconnu dans " .. tostring(spec))
  return id, tonumber(level) or 1
end

local function targetFromSpec(spec)
  local id, body = tostring(spec or ""):match("^([^=]+)=(.+)$")
  if not id then return nil end
  local sections = {}
  for section in body:gmatch("[^;]+") do
    sections[#sections + 1] = trim(section)
  end
  local unitBody = sections[1] or ""
  local units = {}
  for token in unitBody:gmatch("[^+]+") do
    local unitId, level = token:match("^([^:]+):?(%d*)$")
    if unitId and unitId ~= "" then
      unitId = trim(unitId)
      assert(Units[unitId], "PIT_PLAN_TARGET_SPECS unite inconnue dans " .. tostring(spec) .. ": " .. tostring(unitId))
      units[#units + 1] = { id = unitId, level = tonumber(level) or 1, slot = #units + 1 }
    end
  end
  assert(#units > 0, "PIT_PLAN_TARGET_SPECS cible vide: " .. tostring(spec))
  local target = { id = id, source = "spec", sigil = "carre", boardLevel = #units, units = units }
  for i = 2, #sections do
    local key, value = sections[i]:match("^([^=]+)=(.+)$")
    key = key and trim(key):lower() or nil
    value = value and trim(value) or nil
    if key == "relics" then
      target.relics = {}
      for _, relicId in ipairs(plusList(value)) do
        assert(Relics[relicId], "PIT_PLAN_TARGET_SPECS relique inconnue dans " .. tostring(spec) .. ": " .. tostring(relicId))
        target.relics[#target.relics + 1] = relicId
      end
    elseif key == "commander" then
      target.commander, target.commanderLevel = parseCommanderSpec(value, spec)
    elseif key == "sigil" then
      target.sigil = value
    elseif key == "board" or key == "boardlevel" or key == "slots" then
      target.boardLevel = assert(tonumber(value), "PIT_PLAN_TARGET_SPECS board invalide: " .. tostring(value))
    elseif key and key ~= "" then
      error("PIT_PLAN_TARGET_SPECS option inconnue dans " .. tostring(spec) .. ": " .. tostring(key))
    end
  end
  target.cost = Compcost.of(target)
  return target
end

local function loadPlanTargets()
  local out, seen = {}, {}
  for _, id in ipairs(Common.envCsv("PIT_PLAN_TARGETS") or DEFAULT_PLAN_TARGETS) do
    local target = targetFromComp(id)
    assert(target, "PIT_PLAN_TARGETS compo inconnue: " .. tostring(id))
    if not seen[target.id] then seen[target.id] = true; out[#out + 1] = target end
  end
  for _, spec in ipairs(Common.csv(Common.env("PIT_PLAN_TARGET_SPECS") or "")) do
    local target = targetFromSpec(spec)
    if target and not seen[target.id] then seen[target.id] = true; out[#out + 1] = target end
  end
  return out
end

local PLAN_TARGETS = loadPlanTargets()

local function oracleRoundsFor(target)
  if ORACLE_ROUNDS then return ORACLE_ROUNDS end
  local size = target.boardLevel or #(target.units or {})
  if size <= 4 then return { 1, 2, 3, 4 } end
  if size <= 6 then return { 4, 6, 8, 10 } end
  return { 8, 10, 12, 14 }
end

local function oracleTierFor(round)
  return math.max(1, math.min(5, 1 + math.floor((round or 1) / 3)))
end

local function targetOracle(target)
  local rounds = oracleRoundsFor(target)
  local inv = target.cost or Compcost.of(target)
  local coherence = Coherence.scoreTeam(target.units or {}, {
    commander = target.commander,
    relics = target.relics,
  })
  local left = Compbuild.toComp(target, -1)
  local total, wins, ticks, tickN = 0, 0, 0, 0
  local byRound = {}
  for _, round in ipairs(rounds) do
    local drv = Rundriver.new(BASE_SEED + 700000 + round * 17, {
      opponentMode = OPPONENT_MODE,
      opponentPressure = OPPONENT_PRESSURE,
    })
    drv.run.round = round
    drv.run.shopTier = oracleTierFor(round)
    drv.run.slots = math.max(drv.run.slots or 3, math.min(9, target.boardLevel or #(target.units or {})))
    local rightSeed = BASE_SEED + 750000 + round * 97
    local right, enemyKey = drv:opponent(rightSeed)
    local rr = { enemy = enemyKey, fights = 0, wins = 0, ticks = 0, tickN = 0 }
    for m = 1, ORACLE_MATCHES do
      local seed = BASE_SEED + 800000 + round * 101 + m
      local res = Match.run(left, right, seed, {
        tickCap = 8000,
        hpMult = ORACLE_PACING.hpMult,
        cooldownMult = ORACLE_PACING.cooldownMult,
        fatigue = ORACLE_PACING.fatigue,
      })
      total = total + 1
      rr.fights = rr.fights + 1
      if res.win then wins = wins + 1; rr.wins = rr.wins + 1 end
      if res.ticks then
        ticks = ticks + res.ticks; tickN = tickN + 1
        rr.ticks = rr.ticks + res.ticks; rr.tickN = rr.tickN + 1
      end
    end
    byRound[tostring(round)] = {
      enemy = rr.enemy,
      fights = rr.fights,
      forced_winrate = (rr.fights > 0) and (rr.wins / rr.fights) or 0,
      avg_seconds = (rr.tickN > 0) and (rr.ticks / rr.tickN / Common.FPS) or 0,
    }
  end
  return {
    rounds = rounds,
    matches_per_round = ORACLE_MATCHES,
    relics = Common.clone(target.relics or {}),
    commander = target.commander,
    commander_level = target.commanderLevel,
    fights = total,
    forced_winrate = (total > 0) and (wins / total) or 0,
    avg_seconds = (tickN > 0) and (ticks / tickN / Common.FPS) or 0,
    gold = inv.gold or 0,
    cost_score = inv.score or 0,
    coherence = coherence.coherence,
    subscores = coherence.subscores,
    by_round = byRound,
  }
end

local PLAN_ORACLES = {}
for _, target in ipairs(PLAN_TARGETS) do PLAN_ORACLES[target.id] = targetOracle(target) end

local function hasSuffix(s, suffix)
  return s:sub(-#suffix) == suffix
end

local COHORTS = {
  { id = "legacy_all", label = "all non-prune/non-plan policies", match = function(name)
    return not name:find("_prune", 1, true) and not hasSuffix(name, "_plan")
  end },
  { id = "broad_naive", label = "greedy/econ/tall without bench pruning", match = function(name)
    return name == "greedy_stats" or name == "econ_streak" or name == "tall_dense"
  end },
  { id = "broad_prune", label = "greedy/econ/tall with bench pruning", match = function(name)
    return name == "greedy_prune" or name == "econ_prune" or name == "tall_dense_prune"
  end },
  { id = "broad_plan", label = "greedy/econ/tall with pair and board planning", match = function(name)
    return name == "greedy_plan" or name == "econ_plan" or name == "tall_dense_plan"
  end },
  { id = "committed", label = "committed archetype policies", match = function(name)
    return name:sub(1, 10) == "committed_" and not hasSuffix(name, "_plan")
  end },
  { id = "committed_plan", label = "committed archetype policies with pair and board planning", match = function(name)
    return name:sub(1, 10) == "committed_" and hasSuffix(name, "_plan")
  end },
}

local function makePolicies(runIndex)
  local brng = love.math.newRandomGenerator(17000 + runIndex)
  local pols = Policies.analysisSet(brng)
  return Common.filteredRows(pols, Common.envCsv("PIT_POLICIES"), "name")
end

local function unitRank(id)
  local u = id and Units[id]
  return u and (u.rank or 1) or 1
end

local function newFinalDuplicateAgg()
  return {
    runs = 0,
    duplicateRuns = 0,
    lowRankDuplicateRuns = 0,
    duplicateSlots = 0,
    duplicateLevelPoints = 0,
    lowRankDuplicateSlots = 0,
    lowRankDuplicateLevelPoints = 0,
    byUnit = {},
  }
end

local function addFinalDuplicate(a, traj)
  a.runs = a.runs + 1
  local byId = {}
  for _, u in ipairs((traj.finalBoard and traj.finalBoard.units) or {}) do
    if u.id then
      local rec = byId[u.id]
      if not rec then
        rec = { id = u.id, rank = unitRank(u.id), slots = 0, levelPoints = 0, maxLevel = 0 }
        byId[u.id] = rec
      end
      local level = u.level or 1
      rec.slots = rec.slots + 1
      rec.levelPoints = rec.levelPoints + level
      if level > rec.maxLevel then rec.maxLevel = level end
    end
  end

  local duplicateRun, lowRankDuplicateRun = false, false
  for id, rec in pairs(byId) do
    if rec.slots > 1 then
      duplicateRun = true
      a.duplicateSlots = a.duplicateSlots + rec.slots
      a.duplicateLevelPoints = a.duplicateLevelPoints + rec.levelPoints
      if rec.rank <= 2 then
        lowRankDuplicateRun = true
        a.lowRankDuplicateSlots = a.lowRankDuplicateSlots + rec.slots
        a.lowRankDuplicateLevelPoints = a.lowRankDuplicateLevelPoints + rec.levelPoints
      end

      local row = a.byUnit[id]
      if not row then
        row = {
          id = id,
          rank = rec.rank,
          runs = 0,
          slots = 0,
          levelPoints = 0,
          maxLevel = 0,
          wins = 0,
          completions = 0,
        }
        a.byUnit[id] = row
      end
      row.runs = row.runs + 1
      row.slots = row.slots + rec.slots
      row.levelPoints = row.levelPoints + rec.levelPoints
      if rec.maxLevel > row.maxLevel then row.maxLevel = rec.maxLevel end
      row.wins = row.wins + (traj.wins or 0)
      if traj.result == "win" then row.completions = row.completions + 1 end
    end
  end
  if duplicateRun then a.duplicateRuns = a.duplicateRuns + 1 end
  if lowRankDuplicateRun then a.lowRankDuplicateRuns = a.lowRankDuplicateRuns + 1 end
end

local function finishFinalDuplicate(a)
  local runs = a.runs or 0
  local byUnit, top = {}, {}
  for id, row in pairs(a.byUnit or {}) do
    local out = {
      rank = row.rank,
      duplicate_run_rate = (runs > 0) and (row.runs / runs) or 0,
      avg_slots_when_duplicate = (row.runs > 0) and (row.slots / row.runs) or 0,
      avg_level_points_when_duplicate = (row.runs > 0) and (row.levelPoints / row.runs) or 0,
      avg_wins_when_duplicate = (row.runs > 0) and (row.wins / row.runs) or 0,
      completion_when_duplicate = (row.runs > 0) and (row.completions / row.runs) or 0,
      max_level_seen = row.maxLevel or 0,
    }
    byUnit[id] = out
    top[#top + 1] = {
      id = id,
      rank = out.rank,
      duplicate_run_rate = out.duplicate_run_rate,
      avg_slots_when_duplicate = out.avg_slots_when_duplicate,
      avg_level_points_when_duplicate = out.avg_level_points_when_duplicate,
      avg_wins_when_duplicate = out.avg_wins_when_duplicate,
      completion_when_duplicate = out.completion_when_duplicate,
      max_level_seen = out.max_level_seen,
    }
  end
  table.sort(top, function(aRow, bRow)
    if aRow.duplicate_run_rate ~= bRow.duplicate_run_rate then
      return aRow.duplicate_run_rate > bRow.duplicate_run_rate
    end
    if aRow.avg_level_points_when_duplicate ~= bRow.avg_level_points_when_duplicate then
      return aRow.avg_level_points_when_duplicate > bRow.avg_level_points_when_duplicate
    end
    if aRow.rank ~= bRow.rank then return aRow.rank < bRow.rank end
    return aRow.id < bRow.id
  end)
  while #top > 12 do top[#top] = nil end
  return {
    runs = runs,
    duplicate_id_run_rate = (runs > 0) and (a.duplicateRuns / runs) or 0,
    low_rank_duplicate_run_rate = (runs > 0) and (a.lowRankDuplicateRuns / runs) or 0,
    duplicate_slots_per_run = (runs > 0) and (a.duplicateSlots / runs) or 0,
    duplicate_level_points_per_run = (runs > 0) and (a.duplicateLevelPoints / runs) or 0,
    low_rank_duplicate_slots_per_run = (runs > 0) and (a.lowRankDuplicateSlots / runs) or 0,
    low_rank_duplicate_level_points_per_run = (runs > 0) and (a.lowRankDuplicateLevelPoints / runs) or 0,
    by_unit = byUnit,
    top_units = top,
  }
end

local function newAgg()
  return {
    runs = 0, completions = 0, rounds = 0, wins = 0,
    combatWins = 0, combatTotal = 0,
    shopRatioSum = 0, shopRatioN = 0,
    affordFull = 0, earlyAffordFull = 0, earlyRounds = 0,
    desiredRounds = 0, desiredAffordable = 0, desiredGoldAffordable = 0, desiredSlotLimited = 0,
    desiredCostSum = 0, desiredCountSum = 0,
    leftoverSum = 0, pressureSum = 0, pressureN = 0,
    buyGold = 0, sellGold = 0, benchSellGold = 0, boardSellGold = 0, rerollGold = 0, xpGold = 0,
    buys = 0, sells = 0, benchSells = 0, boardSells = 0, pairBuys = 0, mergeBuys = 0,
    pairSupportOffers = 0, rerolls = 0, xpBuys = 0,
    boardDeploys = 0, boardSwaps = 0,
    commanderAccepts = 0, commanderDeclines = 0, commanderPlacements = 0, relicPicks = 0,
    eventPicks = 0, eventRelics = 0, eventUnits = 0, eventUnitFailures = 0,
    eventUnitSingles = 0, eventUnitPairCompleters = 0, eventUnitMergeCompleters = 0,
    eventUnitToBench = 0, eventUnitToBoard = 0,
    eventMutations = 0, eventMutationFailures = 0,
    eventGold = 0, eventShopXp = 0, eventShopTierUps = 0,
    slotDeclines = 0, slotAccepts = 0,
    xpGateBlocks = 0, xpGateObserved = 0, xpGateUnitCoverage = 0, xpGateLevelCoverage = 0,
    archetypeRuns = 0, archetypeCommitted = 0, archetypeCommitRoundSum = 0,
    virtualBench = {}, tiers = {}, archetypes = {}, unitMerge = {}, planTargets = {},
    mergeLifecycle = Common.mergeLifecycleAgg(),
    finalDuplicates = newFinalDuplicateAgg(),
  }
end

local function addUnitMergeEvent(map, ev, kind)
  if not (ev and ev.id) then return end
  local u = map[ev.id]
  if not u then
    u = { pairs = 0, merges = 0, pairRound = 0, mergeRound = 0, pairTier = 0, mergeTier = 0 }
    map[ev.id] = u
  end
  if kind == "pair" then
    u.pairs = u.pairs + 1
    u.pairRound = u.pairRound + (ev.round or 0)
    u.pairTier = u.pairTier + (ev.shopTier or 0)
  elseif kind == "merge" then
    u.merges = u.merges + 1
    u.mergeRound = u.mergeRound + (ev.round or 0)
    u.mergeTier = u.mergeTier + (ev.shopTier or 0)
  end
end

local function finishUnitMerge(map)
  local byUnit, watch = {}, {}
  for id, u in pairs(map or {}) do
    local row = {
      pairs = u.pairs,
      merges = u.merges,
      merge_per_pair = (u.pairs > 0) and (u.merges / u.pairs) or 0,
      avg_pair_round = (u.pairs > 0) and (u.pairRound / u.pairs) or 0,
      avg_merge_round = (u.merges > 0) and (u.mergeRound / u.merges) or 0,
      avg_pair_tier = (u.pairs > 0) and (u.pairTier / u.pairs) or 0,
      avg_merge_tier = (u.merges > 0) and (u.mergeTier / u.merges) or 0,
    }
    byUnit[id] = row
    if row.pairs >= 3 then
      watch[#watch + 1] = {
        id = id, pairs = row.pairs, merges = row.merges,
        merge_per_pair = row.merge_per_pair,
        avg_pair_round = row.avg_pair_round,
        avg_merge_round = row.avg_merge_round,
      }
    end
  end
  table.sort(watch, function(a, b)
    if a.merge_per_pair ~= b.merge_per_pair then return a.merge_per_pair < b.merge_per_pair end
    if a.pairs ~= b.pairs then return a.pairs > b.pairs end
    return a.id < b.id
  end)
  local top = {}
  for i = 1, math.min(12, #watch) do top[i] = watch[i] end
  return byUnit, top
end

local function addVirtualBench(map, rd)
  local desired = rd.desiredOffers or 0
  if desired <= 0 then return end
  local placable = rd.desiredPlacableOffers or 0
  local goldOk = rd.desiredGoldAffordable == true
  for _, cap in ipairs(BENCH_CAPS) do
    local key = tostring(cap)
    local v = map[key]
    if not v then
      v = { rounds = 0, buyAll = 0, goldAffordable = 0, spaceLimited = 0 }
      map[key] = v
    end
    local spaceOk = desired <= placable + cap
    v.rounds = v.rounds + 1
    if goldOk then v.goldAffordable = v.goldAffordable + 1 end
    if not spaceOk then v.spaceLimited = v.spaceLimited + 1 end
    if goldOk and spaceOk then v.buyAll = v.buyAll + 1 end
  end
end

local function finishVirtualBench(map)
  local out = {}
  for _, cap in ipairs(BENCH_CAPS) do
    local key = tostring(cap)
    local v = map[key] or { rounds = 0 }
    out[key] = {
      rounds = v.rounds or 0,
      buy_all_rate = ((v.rounds or 0) > 0) and ((v.buyAll or 0) / v.rounds) or 0,
      gold_afford_rate = ((v.rounds or 0) > 0) and ((v.goldAffordable or 0) / v.rounds) or 0,
      space_limited_rate = ((v.rounds or 0) > 0) and ((v.spaceLimited or 0) / v.rounds) or 0,
    }
  end
  return out
end

local function addTier(a, tier, rd)
  tier = tier or 1
  local t = a.tiers[tier]
  if not t then
    t = { rounds = 0, affordFull = 0, desiredRounds = 0, desiredAffordable = 0,
      desiredGoldAffordable = 0, desiredSlotLimited = 0, rerolls = 0, buyGold = 0, sellGold = 0, leftover = 0,
      buys = 0, pairBuys = 0, mergeBuys = 0, xpBuys = 0, xpGold = 0,
      virtualBench = {} }
    a.tiers[tier] = t
  end
  local e = rd.economy or {}
  t.rounds = t.rounds + 1
  if rd.couldAffordFullShop then t.affordFull = t.affordFull + 1 end
  if (rd.desiredOffers or 0) > 0 then
    t.desiredRounds = t.desiredRounds + 1
    if rd.desiredOffersAffordable then t.desiredAffordable = t.desiredAffordable + 1 end
    if rd.desiredGoldAffordable then t.desiredGoldAffordable = t.desiredGoldAffordable + 1 end
    if rd.desiredSlotLimited then t.desiredSlotLimited = t.desiredSlotLimited + 1 end
    addVirtualBench(t.virtualBench, rd)
  end
  t.rerolls = t.rerolls + (e.rerolls or 0)
  t.buyGold = t.buyGold + (e.buyGold or 0)
  t.sellGold = t.sellGold + (e.sellGold or 0)
  t.leftover = t.leftover + (rd.buildGold or 0)
  t.buys = t.buys + (e.buys or 0)
  t.pairBuys = t.pairBuys + (e.pairBuys or 0)
  t.mergeBuys = t.mergeBuys + (e.mergeBuys or 0)
  t.xpBuys = t.xpBuys + (e.xpBuys or 0)
  t.xpGold = t.xpGold + (e.xpGold or 0)
end

local function addCommitment(a, traj)
  local arch = traj.archetype
  if not arch then return end
  a.archetypeRuns = a.archetypeRuns + 1
  local ar = a.archetypes[arch]
  if not ar then
    ar = {
      runs = 0, committed = 0, uncommitted = 0, commitRoundSum = 0,
      wins = 0, completions = 0,
      committedWins = 0, uncommittedWins = 0,
      committedCompletions = 0, uncommittedCompletions = 0,
    }
    a.archetypes[arch] = ar
  end
  ar.runs = ar.runs + 1
  ar.wins = ar.wins + (traj.wins or 0)
  if traj.result == "win" then ar.completions = ar.completions + 1 end
  if traj.archetypeCommitRound then
    a.archetypeCommitted = a.archetypeCommitted + 1
    a.archetypeCommitRoundSum = a.archetypeCommitRoundSum + traj.archetypeCommitRound
    ar.committed = ar.committed + 1
    ar.commitRoundSum = ar.commitRoundSum + traj.archetypeCommitRound
    ar.committedWins = ar.committedWins + (traj.wins or 0)
    if traj.result == "win" then ar.committedCompletions = ar.committedCompletions + 1 end
  else
    ar.uncommitted = ar.uncommitted + 1
    ar.uncommittedWins = ar.uncommittedWins + (traj.wins or 0)
    if traj.result == "win" then ar.uncommittedCompletions = ar.uncommittedCompletions + 1 end
  end
end

local function unitSummary(units)
  local out = {}
  for _, u in ipairs(units or {}) do
    local rec = out[u.id]
    if not rec then rec = { count = 0, levels = 0 }; out[u.id] = rec end
    rec.count = rec.count + 1
    rec.levels = rec.levels + (u.level or 1)
  end
  return out
end

local function targetUnitSet(target)
  local set = {}
  for _, u in ipairs((target and target.units) or {}) do
    if u.id then set[u.id] = true end
  end
  return set
end

local function filterMergeEvents(list, targetIds)
  local out = {}
  for _, ev in ipairs(list or {}) do
    if ev.id and targetIds[ev.id] then out[#out + 1] = ev end
  end
  return out
end

local function targetMergeTrajectory(traj, target)
  local targetIds = targetUnitSet(target)
  return {
    pairEvents = filterMergeEvents(traj.pairEvents, targetIds),
    mergeEvents = filterMergeEvents(traj.mergeEvents, targetIds),
    exactMergeEvents = filterMergeEvents(traj.exactMergeEvents, targetIds),
    rounds = traj.rounds,
    finalCopies = traj.finalCopies,
  }
end

local function planCoverage(board, target)
  local have = unitSummary(board and board.units or {})
  local want = unitSummary(target and target.units or {})
  local targetUnits, hitUnits, targetLevels, hitLevels = 0, 0, 0, 0
  for id, need in pairs(want) do
    local got = have[id] or { count = 0, levels = 0 }
    targetUnits = targetUnits + need.count
    targetLevels = targetLevels + need.levels
    hitUnits = hitUnits + math.min(got.count, need.count)
    hitLevels = hitLevels + math.min(got.levels, need.levels)
  end
  local unitCoverage = (targetUnits > 0) and (hitUnits / targetUnits) or 0
  local levelCoverage = (targetLevels > 0) and (hitLevels / targetLevels) or 0
  return {
    unit_coverage = unitCoverage,
    level_coverage = levelCoverage,
    complete = unitCoverage >= 1 and levelCoverage >= 1,
  }
end

local function betterCoverage(a, b)
  if not a then return false end
  if not b then return true end
  if (a.level_coverage or 0) ~= (b.level_coverage or 0) then return (a.level_coverage or 0) > (b.level_coverage or 0) end
  if (a.unit_coverage or 0) ~= (b.unit_coverage or 0) then return (a.unit_coverage or 0) > (b.unit_coverage or 0) end
  return (a.round or 9999) < (b.round or 9999)
end

local THRESHOLDS = {
  { key = "25", value = 0.25 },
  { key = "50", value = 0.50 },
  { key = "75", value = 0.75 },
  { key = "100", value = 1.00 },
}

local BAND_ORDER = {
  { key = "lt25", min = 0, max = 0.25 },
  { key = "p25_49", min = 0.25, max = 0.50 },
  { key = "p50_74", min = 0.50, max = 0.75 },
  { key = "p75_99", min = 0.75, max = 1.00 },
  { key = "p100", min = 1.00, max = math.huge },
}

local function newThresholdMap()
  local out = {}
  for _, t in ipairs(THRESHOLDS) do out[t.key] = { hits = 0, round = 0 } end
  return out
end

local function newLossThresholdMap()
  local out = {}
  for _, t in ipairs(THRESHOLDS) do out[t.key] = { before = 0, at_or_after = 0 } end
  return out
end

local function newCombatBands()
  local out = {}
  for _, b in ipairs(BAND_ORDER) do out[b.key] = { total = 0, wins = 0, ticks = 0 } end
  return out
end

local function coverageBand(c)
  c = c or 0
  for _, b in ipairs(BAND_ORDER) do
    if c >= b.min and c < b.max then return b.key end
  end
  return "p100"
end

local function firstThresholdsFor(cov, round, first)
  for _, t in ipairs(THRESHOLDS) do
    if not first[t.key] and (cov.level_coverage or 0) >= t.value then first[t.key] = round end
  end
end

local function addThresholdAgg(dst, first)
  for _, t in ipairs(THRESHOLDS) do
    local round = first and first[t.key]
    if round then
      dst[t.key].hits = dst[t.key].hits + 1
      dst[t.key].round = dst[t.key].round + round
    end
  end
end

local function addLossThresholdAgg(dst, src)
  for _, t in ipairs(THRESHOLDS) do
    local s = src[t.key] or {}
    dst[t.key].before = dst[t.key].before + (s.before or 0)
    dst[t.key].at_or_after = dst[t.key].at_or_after + (s.at_or_after or 0)
  end
end

local function addCombatBands(dst, src)
  for _, b in ipairs(BAND_ORDER) do
    local s = src[b.key] or {}
    dst[b.key].total = dst[b.key].total + (s.total or 0)
    dst[b.key].wins = dst[b.key].wins + (s.wins or 0)
    dst[b.key].ticks = dst[b.key].ticks + (s.ticks or 0)
  end
end

local function finishThresholdAgg(map, runs)
  local out = {}
  for _, t in ipairs(THRESHOLDS) do
    local r = map[t.key] or {}
    out[t.key] = {
      hit_rate = (runs > 0) and ((r.hits or 0) / runs) or 0,
      avg_round_when_hit = ((r.hits or 0) > 0) and ((r.round or 0) / r.hits) or 0,
    }
  end
  return out
end

local function finishLossThresholdAgg(map, runs)
  local out = {}
  for _, t in ipairs(THRESHOLDS) do
    local r = map[t.key] or {}
    out[t.key] = {
      before_per_run = (runs > 0) and ((r.before or 0) / runs) or 0,
      at_or_after_per_run = (runs > 0) and ((r.at_or_after or 0) / runs) or 0,
    }
  end
  return out
end

local function finishCombatBands(map)
  local out = {}
  for _, b in ipairs(BAND_ORDER) do
    local r = map[b.key] or {}
    out[b.key] = {
      combats = r.total or 0,
      winrate = ((r.total or 0) > 0) and ((r.wins or 0) / r.total) or 0,
      avg_ticks = ((r.total or 0) > 0) and ((r.ticks or 0) / r.total) or 0,
    }
  end
  return out
end

local FUNNEL_KEYS = {
  "offered", "goldAffordable", "playable", "bought", "pairBuys", "mergeBuys",
  "sold", "missedGold", "missedSpace", "missedPolicy", "firstSeenHits", "firstSeenRound",
}

local function newFunnelAgg()
  local out = { byUnit = {}, targetUnits = 0 }
  for _, key in ipairs(FUNNEL_KEYS) do out[key] = 0 end
  return out
end

local function targetUnitSet(target)
  local set, order = {}, {}
  for _, u in ipairs(target.units or {}) do
    if u.id and not set[u.id] then
      set[u.id] = true
      order[#order + 1] = u.id
    end
  end
  table.sort(order)
  return set, order
end

local function funnelUnit(f, id)
  local u = f.byUnit[id]
  if not u then
    u = newFunnelAgg()
    u.byUnit = nil
    u.targetUnits = nil
    f.byUnit[id] = u
  end
  return u
end

local function addFunnelValue(f, id, key, n)
  n = n or 1
  f[key] = (f[key] or 0) + n
  if id then
    local u = funnelUnit(f, id)
    u[key] = (u[key] or 0) + n
  end
end

local function addFunnelAgg(dst, src)
  dst.targetUnits = math.max(dst.targetUnits or 0, src.targetUnits or 0)
  for _, key in ipairs(FUNNEL_KEYS) do dst[key] = (dst[key] or 0) + (src[key] or 0) end
  for id, row in pairs(src.byUnit or {}) do
    local d = funnelUnit(dst, id)
    for _, key in ipairs(FUNNEL_KEYS) do d[key] = (d[key] or 0) + (row[key] or 0) end
  end
end

local function planFunnel(traj, target)
  local wanted, order = targetUnitSet(target)
  local out = newFunnelAgg()
  out.targetUnits = #order
  local firstSeen = {}
  local function scanOffer(offer, rd, boughtRemaining)
    if not (offer and not offer.sold and wanted[offer.id]) then return end
    local id = offer.id
    addFunnelValue(out, id, "offered", 1)
    if not firstSeen[id] then
      firstSeen[id] = true
      addFunnelValue(out, id, "firstSeenHits", 1)
      addFunnelValue(out, id, "firstSeenRound", rd.round or 0)
    end
    local goldOk = (rd.startGold or 0) >= (offer.cost or 0)
    local spaceOk = offer.playable == true
    if goldOk then addFunnelValue(out, id, "goldAffordable", 1)
    else addFunnelValue(out, id, "missedGold", 1) end
    if spaceOk then addFunnelValue(out, id, "playable", 1) end
    if goldOk and not spaceOk then addFunnelValue(out, id, "missedSpace", 1) end
    if goldOk and spaceOk then
      if (boughtRemaining[id] or 0) > 0 then
        boughtRemaining[id] = boughtRemaining[id] - 1
      else
        addFunnelValue(out, id, "missedPolicy", 1)
      end
    end
  end
  for _, rd in ipairs(traj.rounds or {}) do
    local buysById = {}
    for _, ev in ipairs(rd.events or {}) do
      if wanted[ev.id] then
        if ev.type == "buy" then
          buysById[ev.id] = (buysById[ev.id] or 0) + 1
          addFunnelValue(out, ev.id, "bought", 1)
          if ev.progress == "pair" then addFunnelValue(out, ev.id, "pairBuys", 1) end
          if ev.progress == "merge" then addFunnelValue(out, ev.id, "mergeBuys", 1) end
        elseif ev.type == "sell" then
          addFunnelValue(out, ev.id, "sold", 1)
        end
      end
    end
    local boughtRemaining = {}
    for id, n in pairs(buysById) do boughtRemaining[id] = n end
    for _, offer in ipairs(rd.shop or {}) do
      scanOffer(offer, rd, boughtRemaining)
    end
    for _, ev in ipairs(rd.events or {}) do
      if ev.type == "shop_roll" then
        for _, offer in ipairs(ev.shop or {}) do scanOffer(offer, rd, boughtRemaining) end
      end
    end
  end
  return out
end

local function finishFunnelUnit(row, runs)
  local offered = row.offered or 0
  return {
    offers_per_run = (runs > 0) and (offered / runs) or 0,
    gold_afford_rate = (offered > 0) and ((row.goldAffordable or 0) / offered) or 0,
    playable_rate = (offered > 0) and ((row.playable or 0) / offered) or 0,
    buy_rate_per_offer = (offered > 0) and ((row.bought or 0) / offered) or 0,
    bought_per_run = (runs > 0) and ((row.bought or 0) / runs) or 0,
    pair_buys_per_run = (runs > 0) and ((row.pairBuys or 0) / runs) or 0,
    merge_buys_per_run = (runs > 0) and ((row.mergeBuys or 0) / runs) or 0,
    sold_per_run = (runs > 0) and ((row.sold or 0) / runs) or 0,
    missed_gold_per_run = (runs > 0) and ((row.missedGold or 0) / runs) or 0,
    missed_space_per_run = (runs > 0) and ((row.missedSpace or 0) / runs) or 0,
    missed_policy_per_run = (runs > 0) and ((row.missedPolicy or 0) / runs) or 0,
    seen_rate = (runs > 0) and ((row.firstSeenHits or 0) / runs) or 0,
    avg_first_seen_round = ((row.firstSeenHits or 0) > 0) and ((row.firstSeenRound or 0) / row.firstSeenHits) or 0,
  }
end

local function finishFunnel(row, runs)
  local out = finishFunnelUnit(row, runs)
  local targetUnits = math.max(1, row.targetUnits or 0)
  out.target_units = row.targetUnits or 0
  out.target_units_seen_per_run = out.seen_rate
  out.seen_rate = nil
  out.target_unit_seen_rate = (runs > 0) and ((row.firstSeenHits or 0) / (runs * targetUnits)) or 0
  out.by_unit = {}
  for id, u in pairs(row.byUnit or {}) do out.by_unit[id] = finishFunnelUnit(u, runs) end
  return out
end

local FOCUSED_SUPPORT_KINDS = {
  producer_amplifier = true,
  propagation_payoff = true,
  transform_payoff = true,
  command_amplifier = true,
  command_propagation = true,
  command_transform = true,
}

local function supportClassFromEdges(edges)
  local focused, generic, weight = 0, 0, 0
  for _, edge in ipairs(edges or {}) do
    if edge.kind then
      if FOCUSED_SUPPORT_KINDS[edge.kind] then focused = focused + 1
      else generic = generic + 1 end
      weight = weight + (edge.weight or 0)
    end
  end
  if focused > 0 then return "focused", focused, generic, weight end
  if generic > 0 then return "generic", focused, generic, weight end
  return nil, 0, 0, 0
end

local function betterSupport(row, best)
  if not best then return true end
  local rf, bf = row.support_class == "focused", best.support_class == "focused"
  if rf ~= bf then return rf end
  local rs, bs = row.command_score or row.relic_score or 0, best.command_score or best.relic_score or 0
  if rs ~= bs then return rs > bs end
  return (row.level or 1) > (best.level or 1)
end

local SUPPORT_CATALOGS = {}

local function supportCatalog(target)
  local key = target.id or tostring(target)
  if SUPPORT_CATALOGS[key] then return SUPPORT_CATALOGS[key] end
  local catalog = { relics = {}, commanders = {} }

  for _, relicId in ipairs(Relics.order or {}) do
    local score = Coherence.scoreTeam(target.units or {}, { relics = { relicId } })
    local class, focused, generic, weight = supportClassFromEdges(score.relicEdges)
    if class then
      catalog.relics[relicId] = {
        id = relicId,
        support_class = class,
        edge_count = #(score.relicEdges or {}),
        focused_edge_count = focused,
        generic_edge_count = generic,
        edge_weight = weight,
        relic_score = score.subscores and score.subscores.relic or 0,
      }
    end
  end

  for _, unitId in ipairs(Units.order or {}) do
    if Units[unitId] and Units[unitId].commandBonus then
      local rec = { id = unitId, by_level = {} }
      for level = 1, 3 do
        local score = Coherence.scoreTeam(target.units or {}, { commander = { id = unitId, level = level } })
        local class, focused, generic, weight = supportClassFromEdges(score.commandEdges)
        if class then
          local row = {
            id = unitId,
            level = level,
            support_class = class,
            edge_count = #(score.commandEdges or {}),
            focused_edge_count = focused,
            generic_edge_count = generic,
            edge_weight = weight,
            command_score = score.subscores and score.subscores.command or 0,
          }
          rec.by_level[level] = row
          if betterSupport(row, rec.best) then rec.best = row end
        end
      end
      if rec.best then
        rec.support_class = rec.best.support_class
        rec.best_level = rec.best.level
        rec.edge_count = rec.best.edge_count
        rec.focused_edge_count = rec.best.focused_edge_count
        rec.generic_edge_count = rec.best.generic_edge_count
        rec.edge_weight = rec.best.edge_weight
        rec.command_score = rec.best.command_score
        catalog.commanders[unitId] = rec
      end
    end
  end

  SUPPORT_CATALOGS[key] = catalog
  return catalog
end

local RELIC_SUPPORT_KEYS = {
  "offers", "picks", "offerRunHits", "pickRunHits",
  "firstOfferHits", "firstOfferRound", "firstPickHits", "firstPickRound",
}

local COMMANDER_SUPPORT_KEYS = {
  "candidates", "placements", "candidateRunHits", "placementRunHits",
  "firstCandidateHits", "firstCandidateRound", "firstPlacementHits", "firstPlacementRound",
}

local function supportBucket(map, id)
  local row = map[id]
  if not row then row = {}; map[id] = row end
  return row
end

local function noteRelicSupport(out, id, kind, round)
  local row = supportBucket(out.relics.byRelic, id)
  if kind == "offer" then
    row.offers = (row.offers or 0) + 1
    if not row.offerRunHits then
      row.offerRunHits = 1
      row.firstOfferHits = 1
      row.firstOfferRound = round or 0
    end
  elseif kind == "pick" then
    row.picks = (row.picks or 0) + 1
    if not row.pickRunHits then
      row.pickRunHits = 1
      row.firstPickHits = 1
      row.firstPickRound = round or 0
    end
  end
end

local function noteCommanderSupport(out, id, kind, round)
  local row = supportBucket(out.commanders.byCommander, id)
  if kind == "candidate" then
    row.candidates = (row.candidates or 0) + 1
    if not row.candidateRunHits then
      row.candidateRunHits = 1
      row.firstCandidateHits = 1
      row.firstCandidateRound = round or 0
    end
  elseif kind == "placement" then
    row.placements = (row.placements or 0) + 1
    if not row.placementRunHits then
      row.placementRunHits = 1
      row.firstPlacementHits = 1
      row.firstPlacementRound = round or 0
    end
  end
end

local function newSupportAccessAgg(target)
  return {
    catalog = supportCatalog(target),
    relics = {
      focusedOfferRuns = 0, focusedPickRuns = 0,
      focusedOffers = 0, focusedPicks = 0,
      missedFocusedPick = 0,
      firstFocusedOfferHits = 0, firstFocusedOfferRound = 0,
      firstFocusedPickHits = 0, firstFocusedPickRound = 0,
      byRelic = {},
    },
    commanders = {
      focusedCandidateRuns = 0, focusedPlacementRuns = 0,
      focusedCandidates = 0, focusedPlacements = 0,
      missedFocusedPlacement = 0,
      firstFocusedCandidateHits = 0, firstFocusedCandidateRound = 0,
      firstFocusedPlacementHits = 0, firstFocusedPlacementRound = 0,
      byCommander = {},
    },
    timing = {
      focusedSeenRuns = 0, focusedUsedRuns = 0,
      focusedUsedByHeld25 = 0, focusedUsedByHeld50 = 0,
      runsWithFocusedSupport = 0, winsWithFocusedSupport = 0,
      runsWithoutFocusedSupport = 0, winsWithoutFocusedSupport = 0,
    },
  }
end

local function commanderInfo(catalog, id, level)
  local rec = catalog.commanders[id]
  if not rec then return nil end
  return rec.by_level[level or 1] or rec.best
end

local function planSupportAccess(traj, target, path)
  local catalog = supportCatalog(target)
  local out = newSupportAccessAgg(target)
  local focusedRelicOffer, focusedRelicPick = false, false
  local focusedCommanderCandidate, focusedCommanderPlacement = false, false
  local firstFocusedRelicOffer, firstFocusedRelicPick
  local firstFocusedCommanderCandidate, firstFocusedCommanderPlacement

  local function noteRelicOffer(relicId, round, rowState)
    local info = catalog.relics[relicId]
    if not info then return end
    noteRelicSupport(out, relicId, "offer", round)
    if info.support_class == "focused" then
      focusedRelicOffer, rowState.offer = true, true
      out.relics.focusedOffers = out.relics.focusedOffers + 1
      if not firstFocusedRelicOffer then firstFocusedRelicOffer = round end
    end
  end

  local function noteRelicPick(relicId, round, rowState)
    local info = catalog.relics[relicId]
    if not info then return end
    noteRelicSupport(out, relicId, "pick", round)
    if info.support_class == "focused" then
      focusedRelicPick, rowState.pick = true, true
      out.relics.focusedPicks = out.relics.focusedPicks + 1
      if not firstFocusedRelicPick then firstFocusedRelicPick = round end
    end
  end

  for _, rd in ipairs(traj.rounds or {}) do
    local round = rd.round or 0
    local rowFocusedRelicOffer, rowFocusedRelicPick = false, false
    local rowFocusedCommanderCandidate, rowFocusedCommanderPlacement = false, false
    local rowRelics = { offer = false, pick = false }

    for _, ev in ipairs(rd.events or {}) do
      if ev.type == "relic_offer" then
        for _, relicId in ipairs(ev.choices or {}) do
          noteRelicOffer(relicId, round, rowRelics)
        end
      elseif ev.type == "run_event_offer" then
        for _, choice in ipairs(ev.choices or {}) do
          local reward = choice.reward or {}
          if reward.kind == "relic" then
            noteRelicOffer(reward.id, round, rowRelics)
          end
        end
      elseif ev.type == "relic_pick" then
        noteRelicPick(ev.id, round, rowRelics)
      elseif ev.type == "run_event_pick" then
        local reward = ev.reward or {}
        if reward.kind == "relic" and ev.applied ~= false then
          noteRelicPick(reward.id, round, rowRelics)
        end
      elseif ev.type == "commander_window" then
        for _, c in ipairs(ev.candidates or {}) do
          local info = commanderInfo(catalog, c.id, c.level)
          if info then
            noteCommanderSupport(out, c.id, "candidate", round)
            if info.support_class == "focused" then
              focusedCommanderCandidate, rowFocusedCommanderCandidate = true, true
              out.commanders.focusedCandidates = out.commanders.focusedCandidates + 1
              if not firstFocusedCommanderCandidate then firstFocusedCommanderCandidate = round end
            end
          end
        end
      elseif ev.type == "commander_place" then
        local info = commanderInfo(catalog, ev.id, ev.level)
        if info then
          noteCommanderSupport(out, ev.id, "placement", round)
          if info.support_class == "focused" then
            focusedCommanderPlacement, rowFocusedCommanderPlacement = true, true
            out.commanders.focusedPlacements = out.commanders.focusedPlacements + 1
            if not firstFocusedCommanderPlacement then firstFocusedCommanderPlacement = round end
          end
        end
      end
    end
    rowFocusedRelicOffer = rowRelics.offer
    rowFocusedRelicPick = rowRelics.pick

    if rowFocusedRelicOffer and not rowFocusedRelicPick then out.relics.missedFocusedPick = out.relics.missedFocusedPick + 1 end
    if rowFocusedCommanderCandidate and not rowFocusedCommanderPlacement then
      out.commanders.missedFocusedPlacement = out.commanders.missedFocusedPlacement + 1
    end
  end

  if focusedRelicOffer then out.relics.focusedOfferRuns = 1 end
  if focusedRelicPick then out.relics.focusedPickRuns = 1 end
  if firstFocusedRelicOffer then
    out.relics.firstFocusedOfferHits = 1
    out.relics.firstFocusedOfferRound = firstFocusedRelicOffer
  end
  if firstFocusedRelicPick then
    out.relics.firstFocusedPickHits = 1
    out.relics.firstFocusedPickRound = firstFocusedRelicPick
  end

  if focusedCommanderCandidate then out.commanders.focusedCandidateRuns = 1 end
  if focusedCommanderPlacement then out.commanders.focusedPlacementRuns = 1 end
  if firstFocusedCommanderCandidate then
    out.commanders.firstFocusedCandidateHits = 1
    out.commanders.firstFocusedCandidateRound = firstFocusedCommanderCandidate
  end
  if firstFocusedCommanderPlacement then
    out.commanders.firstFocusedPlacementHits = 1
    out.commanders.firstFocusedPlacementRound = firstFocusedCommanderPlacement
  end

  local firstSeen = firstFocusedRelicOffer
  if firstFocusedCommanderCandidate and (not firstSeen or firstFocusedCommanderCandidate < firstSeen) then
    firstSeen = firstFocusedCommanderCandidate
  end
  local firstUsed = firstFocusedRelicPick
  if firstFocusedCommanderPlacement and (not firstUsed or firstFocusedCommanderPlacement < firstUsed) then
    firstUsed = firstFocusedCommanderPlacement
  end
  if firstSeen then out.timing.focusedSeenRuns = 1 end
  if firstUsed then
    out.timing.focusedUsedRuns = 1
    out.timing.runsWithFocusedSupport = 1
    out.timing.winsWithFocusedSupport = traj.wins or 0
    local held25 = path.first_held and path.first_held["25"]
    local held50 = path.first_held and path.first_held["50"]
    if held25 and firstUsed <= held25 then out.timing.focusedUsedByHeld25 = 1 end
    if held50 and firstUsed <= held50 then out.timing.focusedUsedByHeld50 = 1 end
  else
    out.timing.runsWithoutFocusedSupport = 1
    out.timing.winsWithoutFocusedSupport = traj.wins or 0
  end

  return out
end

local function addKeyed(dst, src, keys)
  for _, key in ipairs(keys) do dst[key] = (dst[key] or 0) + (src[key] or 0) end
end

local function addSupportAccessAgg(dst, src)
  addKeyed(dst.relics, src.relics, {
    "focusedOfferRuns", "focusedPickRuns", "focusedOffers", "focusedPicks", "missedFocusedPick",
    "firstFocusedOfferHits", "firstFocusedOfferRound", "firstFocusedPickHits", "firstFocusedPickRound",
  })
  for id, row in pairs(src.relics.byRelic or {}) do
    local d = supportBucket(dst.relics.byRelic, id)
    addKeyed(d, row, RELIC_SUPPORT_KEYS)
  end
  addKeyed(dst.commanders, src.commanders, {
    "focusedCandidateRuns", "focusedPlacementRuns", "focusedCandidates", "focusedPlacements", "missedFocusedPlacement",
    "firstFocusedCandidateHits", "firstFocusedCandidateRound", "firstFocusedPlacementHits", "firstFocusedPlacementRound",
  })
  for id, row in pairs(src.commanders.byCommander or {}) do
    local d = supportBucket(dst.commanders.byCommander, id)
    addKeyed(d, row, COMMANDER_SUPPORT_KEYS)
  end
  addKeyed(dst.timing, src.timing, {
    "focusedSeenRuns", "focusedUsedRuns", "focusedUsedByHeld25", "focusedUsedByHeld50",
    "runsWithFocusedSupport", "winsWithFocusedSupport", "runsWithoutFocusedSupport", "winsWithoutFocusedSupport",
  })
end

local function rate(n, d)
  d = d or 0
  return (d > 0) and ((n or 0) / d) or 0
end

local function finishSupportAccess(row, runs)
  local relics, commanders, timing = row.relics, row.commanders, row.timing
  local out = {
    relics = {
      focused_offer_run_rate = rate(relics.focusedOfferRuns, runs),
      focused_pick_run_rate = rate(relics.focusedPickRuns, runs),
      focused_offers_per_run = rate(relics.focusedOffers, runs),
      focused_picks_per_run = rate(relics.focusedPicks, runs),
      missed_focused_pick_per_run = rate(relics.missedFocusedPick, runs),
      avg_first_focused_offer_round = rate(relics.firstFocusedOfferRound, relics.firstFocusedOfferHits),
      avg_first_focused_pick_round = rate(relics.firstFocusedPickRound, relics.firstFocusedPickHits),
      by_relic = {},
    },
    commanders = {
      focused_candidate_run_rate = rate(commanders.focusedCandidateRuns, runs),
      focused_placement_run_rate = rate(commanders.focusedPlacementRuns, runs),
      focused_candidates_per_run = rate(commanders.focusedCandidates, runs),
      focused_placements_per_run = rate(commanders.focusedPlacements, runs),
      missed_focused_placement_per_run = rate(commanders.missedFocusedPlacement, runs),
      avg_first_focused_candidate_round = rate(commanders.firstFocusedCandidateRound, commanders.firstFocusedCandidateHits),
      avg_first_focused_placement_round = rate(commanders.firstFocusedPlacementRound, commanders.firstFocusedPlacementHits),
      by_commander = {},
    },
    timing = {
      focused_support_seen_run_rate = rate(timing.focusedSeenRuns, runs),
      focused_support_used_run_rate = rate(timing.focusedUsedRuns, runs),
      focused_support_used_by_held_25_rate = rate(timing.focusedUsedByHeld25, runs),
      focused_support_used_by_held_50_rate = rate(timing.focusedUsedByHeld50, runs),
      avg_wins_with_focused_support = rate(timing.winsWithFocusedSupport, timing.runsWithFocusedSupport),
      avg_wins_without_focused_support = rate(timing.winsWithoutFocusedSupport, timing.runsWithoutFocusedSupport),
    },
  }

  for relicId, info in pairs(row.catalog.relics or {}) do
    local r = relics.byRelic[relicId] or {}
    out.relics.by_relic[relicId] = {
      support_class = info.support_class,
      edge_count = info.edge_count,
      focused_edge_count = info.focused_edge_count,
      generic_edge_count = info.generic_edge_count,
      relic_score = info.relic_score,
      offer_run_rate = rate(r.offerRunHits, runs),
      pick_run_rate = rate(r.pickRunHits, runs),
      offers_per_run = rate(r.offers, runs),
      picks_per_run = rate(r.picks, runs),
      avg_first_offer_round = rate(r.firstOfferRound, r.firstOfferHits),
      avg_first_pick_round = rate(r.firstPickRound, r.firstPickHits),
    }
  end

  for unitId, info in pairs(row.catalog.commanders or {}) do
    local r = commanders.byCommander[unitId] or {}
    out.commanders.by_commander[unitId] = {
      support_class = info.support_class,
      best_level = info.best_level,
      edge_count = info.edge_count,
      focused_edge_count = info.focused_edge_count,
      generic_edge_count = info.generic_edge_count,
      command_score = info.command_score,
      candidate_run_rate = rate(r.candidateRunHits, runs),
      placement_run_rate = rate(r.placementRunHits, runs),
      candidates_per_run = rate(r.candidates, runs),
      placements_per_run = rate(r.placements, runs),
      avg_first_candidate_round = rate(r.firstCandidateRound, r.firstCandidateHits),
      avg_first_placement_round = rate(r.firstPlacementRound, r.firstPlacementHits),
    }
  end
  return out
end

local function supportClassRank(class)
  if class == "focused" then return 2 end
  if class == "generic" then return 1 end
  return 0
end

local function topSupportRows(rows, kind, maxRows, focusedOnly)
  local out = {}
  for id, row in pairs(rows or {}) do
    if not focusedOnly or row.support_class == "focused" then
      if kind == "relic" then
        out[#out + 1] = {
          id = id,
          support_class = row.support_class,
          score = row.relic_score or 0,
          focused_edge_count = row.focused_edge_count or 0,
          generic_edge_count = row.generic_edge_count or 0,
          offer_run_rate = row.offer_run_rate or 0,
          pick_run_rate = row.pick_run_rate or 0,
          pick_gap = math.max(0, (row.offer_run_rate or 0) - (row.pick_run_rate or 0)),
          avg_first_offer_round = row.avg_first_offer_round or 0,
          avg_first_pick_round = row.avg_first_pick_round or 0,
        }
      else
        out[#out + 1] = {
          id = id,
          support_class = row.support_class,
          best_level = row.best_level or 1,
          score = row.command_score or 0,
          focused_edge_count = row.focused_edge_count or 0,
          generic_edge_count = row.generic_edge_count or 0,
          candidate_run_rate = row.candidate_run_rate or 0,
          placement_run_rate = row.placement_run_rate or 0,
          placement_gap = math.max(0, (row.candidate_run_rate or 0) - (row.placement_run_rate or 0)),
          avg_first_candidate_round = row.avg_first_candidate_round or 0,
          avg_first_placement_round = row.avg_first_placement_round or 0,
        }
      end
    end
  end
  table.sort(out, function(a, b)
    local ca, cb = supportClassRank(a.support_class), supportClassRank(b.support_class)
    if ca ~= cb then return ca > cb end
    local pa = kind == "relic" and (a.pick_run_rate or 0) or (a.placement_run_rate or 0)
    local pb = kind == "relic" and (b.pick_run_rate or 0) or (b.placement_run_rate or 0)
    if pa ~= pb then return pa > pb end
    local oa = kind == "relic" and (a.offer_run_rate or 0) or (a.candidate_run_rate or 0)
    local ob = kind == "relic" and (b.offer_run_rate or 0) or (b.candidate_run_rate or 0)
    if oa ~= ob then return oa > ob end
    if (a.score or 0) ~= (b.score or 0) then return (a.score or 0) > (b.score or 0) end
    return tostring(a.id) < tostring(b.id)
  end)
  maxRows = maxRows or 5
  while #out > maxRows do out[#out] = nil end
  return out
end

local function summarizeSupportAccess(access)
  if not access then return nil end
  local relics = access.relics or {}
  local commanders = access.commanders or {}
  local timing = access.timing or {}
  local seen = timing.focused_support_seen_run_rate or 0
  local used = timing.focused_support_used_run_rate or 0
  local winDeltaObserved = used > 0 and used < 1
  local winDelta = winDeltaObserved
    and ((timing.avg_wins_with_focused_support or 0) - (timing.avg_wins_without_focused_support or 0))
    or 0
  return {
    timing = {
      focused_support_seen_run_rate = seen,
      focused_support_used_run_rate = used,
      focused_support_pick_gap = math.max(0, seen - used),
      focused_support_used_by_held_25_rate = timing.focused_support_used_by_held_25_rate or 0,
      focused_support_used_by_held_50_rate = timing.focused_support_used_by_held_50_rate or 0,
      avg_wins_with_focused_support = timing.avg_wins_with_focused_support or 0,
      avg_wins_without_focused_support = timing.avg_wins_without_focused_support or 0,
      focused_support_win_delta = winDelta,
      focused_support_win_delta_observed = winDeltaObserved,
    },
    relics = {
      focused_offer_run_rate = relics.focused_offer_run_rate or 0,
      focused_pick_run_rate = relics.focused_pick_run_rate or 0,
      focused_pick_gap = math.max(0, (relics.focused_offer_run_rate or 0) - (relics.focused_pick_run_rate or 0)),
      missed_focused_pick_per_run = relics.missed_focused_pick_per_run or 0,
      avg_first_focused_offer_round = relics.avg_first_focused_offer_round or 0,
      avg_first_focused_pick_round = relics.avg_first_focused_pick_round or 0,
      top_focused_relics = topSupportRows(relics.by_relic, "relic", 5, true),
    },
    commanders = {
      focused_candidate_run_rate = commanders.focused_candidate_run_rate or 0,
      focused_placement_run_rate = commanders.focused_placement_run_rate or 0,
      focused_placement_gap = math.max(0, (commanders.focused_candidate_run_rate or 0) - (commanders.focused_placement_run_rate or 0)),
      missed_focused_placement_per_run = commanders.missed_focused_placement_per_run or 0,
      avg_first_focused_candidate_round = commanders.avg_first_focused_candidate_round or 0,
      avg_first_focused_placement_round = commanders.avg_first_focused_placement_round or 0,
      top_focused_commanders = topSupportRows(commanders.by_commander, "commander", 5, true),
    },
  }
end

local function summarizePlanSupport(planAccess)
  local rows = {}
  for id, plan in pairs(planAccess or {}) do
    local support = plan.support_summary or summarizeSupportAccess(plan.support_access)
    if support then
      rows[#rows + 1] = {
        id = id,
        source = plan.source,
        complete_rate = plan.complete_rate or 0,
        avg_level_coverage = plan.avg_level_coverage or 0,
        avg_wins = plan.avg_wins or 0,
        completion = plan.completion or 0,
        focused_support_seen_run_rate = support.timing.focused_support_seen_run_rate or 0,
        focused_support_used_run_rate = support.timing.focused_support_used_run_rate or 0,
        focused_support_pick_gap = support.timing.focused_support_pick_gap or 0,
        focused_support_win_delta = support.timing.focused_support_win_delta or 0,
        focused_support_win_delta_observed = support.timing.focused_support_win_delta_observed or false,
        focused_relic_offer_run_rate = support.relics.focused_offer_run_rate or 0,
        focused_relic_pick_run_rate = support.relics.focused_pick_run_rate or 0,
        missed_focused_relic_pick_per_run = support.relics.missed_focused_pick_per_run or 0,
        focused_commander_candidate_run_rate = support.commanders.focused_candidate_run_rate or 0,
        focused_commander_placement_run_rate = support.commanders.focused_placement_run_rate or 0,
      }
    end
  end
  table.sort(rows, function(a, b)
    if (a.focused_support_used_run_rate or 0) ~= (b.focused_support_used_run_rate or 0) then
      return (a.focused_support_used_run_rate or 0) < (b.focused_support_used_run_rate or 0)
    end
    if (a.complete_rate or 0) ~= (b.complete_rate or 0) then return (a.complete_rate or 0) < (b.complete_rate or 0) end
    return tostring(a.id) < tostring(b.id)
  end)
  return rows
end

local function planTrajectory(traj, target, finalBoardCov, finalHeldCov)
  local bestBoard, bestHeld = nil, nil
  local everBoardComplete, everHeldComplete = false, false
  local firstBoard, firstHeld = {}, {}
  local combatBands = newCombatBands()
  local lossThresholds = newLossThresholdMap()
  for i, rd in ipairs(traj.rounds or {}) do
    local round = rd.round or i
    local boardCov
    if rd.board then
      boardCov = planCoverage(rd.board, target)
      boardCov.round = round
      if boardCov.complete then everBoardComplete = true end
      firstThresholdsFor(boardCov, round, firstBoard)
      if betterCoverage(boardCov, bestBoard) then bestBoard = boardCov end
    end
    if rd.holdings or rd.board then
      local cov = planCoverage(rd.holdings or rd.board, target)
      cov.round = round
      if cov.complete then everHeldComplete = true end
      firstThresholdsFor(cov, round, firstHeld)
      if betterCoverage(cov, bestHeld) then bestHeld = cov end
    end
    if boardCov and rd.decided ~= nil then
      local band = coverageBand(boardCov.level_coverage)
      local br = combatBands[band]
      br.total = br.total + 1
      if rd.win then br.wins = br.wins + 1 end
      br.ticks = br.ticks + (rd.ticks or 0)
      if rd.win == false then
        for _, t in ipairs(THRESHOLDS) do
          if (boardCov.level_coverage or 0) < t.value then
            lossThresholds[t.key].before = lossThresholds[t.key].before + 1
          else
            lossThresholds[t.key].at_or_after = lossThresholds[t.key].at_or_after + 1
          end
        end
      end
    end
  end
  bestBoard = bestBoard or {
    unit_coverage = finalBoardCov.unit_coverage,
    level_coverage = finalBoardCov.level_coverage,
    complete = finalBoardCov.complete,
    round = 0,
  }
  bestHeld = bestHeld or {
    unit_coverage = finalHeldCov.unit_coverage,
    level_coverage = finalHeldCov.level_coverage,
    complete = finalHeldCov.complete,
    round = 0,
  }
  everBoardComplete = everBoardComplete or finalBoardCov.complete
  everHeldComplete = everHeldComplete or finalHeldCov.complete
  local heldDrop = math.max(0, (bestHeld.level_coverage or 0) - (finalHeldCov.level_coverage or 0))
  local boardDrop = math.max(0, (bestBoard.level_coverage or 0) - (finalBoardCov.level_coverage or 0))
  return {
    best_board = bestBoard,
    best_held = bestHeld,
    ever_board_complete = everBoardComplete,
    ever_held_complete = everHeldComplete,
    held_drop_from_peak = heldDrop,
    board_drop_from_peak = boardDrop,
    promising_lost = (bestHeld.level_coverage or 0) >= 0.50 and ((finalHeldCov.level_coverage or 0) + 0.20) < (bestHeld.level_coverage or 0),
    undeployed_complete = finalHeldCov.complete and not finalBoardCov.complete,
    first_board = firstBoard,
    first_held = firstHeld,
    combat_bands = combatBands,
    loss_thresholds = lossThresholds,
  }
end

local function addPlanAccess(a, traj)
  if #PLAN_TARGETS == 0 then return end
  local finalGold = (traj.finalCost and traj.finalCost.gold) or 0
  for _, target in ipairs(PLAN_TARGETS) do
    local rec = a.planTargets[target.id]
    if not rec then
      rec = {
        id = target.id,
        source = target.source,
        target_gold = (target.cost and target.cost.gold) or 0,
        runs = 0, complete = 0, heldComplete = 0,
        everBoardComplete = 0, everHeldComplete = 0,
        promisingLost = 0, undeployedComplete = 0,
        unitCoverage = 0, levelCoverage = 0,
        heldUnitCoverage = 0, heldLevelCoverage = 0,
        peakBoardUnitCoverage = 0, peakBoardLevelCoverage = 0, peakBoardRound = 0,
        peakHeldUnitCoverage = 0, peakHeldLevelCoverage = 0, peakHeldRound = 0,
        heldDropFromPeak = 0, boardDropFromPeak = 0,
        firstBoard = newThresholdMap(),
        firstHeld = newThresholdMap(),
        combatBands = newCombatBands(),
        lossThresholds = newLossThresholdMap(),
        funnel = newFunnelAgg(),
        support = newSupportAccessAgg(target),
        targetMergeLifecycle = Common.mergeLifecycleAgg(),
        finalGoldRatio = 0,
        wins = 0, completeWins = 0,
        completions = 0, completeCompletions = 0,
      }
      a.planTargets[target.id] = rec
    end
    local cov = planCoverage(traj.finalBoard, target)
    local heldCov = planCoverage(traj.finalHoldings or traj.finalBoard, target)
    local path = planTrajectory(traj, target, cov, heldCov)
    local funnel = planFunnel(traj, target)
    local support = planSupportAccess(traj, target, path)
    Common.addMergeLifecycle(rec.targetMergeLifecycle, targetMergeTrajectory(traj, target))
    rec.runs = rec.runs + 1
    rec.unitCoverage = rec.unitCoverage + cov.unit_coverage
    rec.levelCoverage = rec.levelCoverage + cov.level_coverage
    rec.heldUnitCoverage = rec.heldUnitCoverage + heldCov.unit_coverage
    rec.heldLevelCoverage = rec.heldLevelCoverage + heldCov.level_coverage
    rec.peakBoardUnitCoverage = rec.peakBoardUnitCoverage + (path.best_board.unit_coverage or 0)
    rec.peakBoardLevelCoverage = rec.peakBoardLevelCoverage + (path.best_board.level_coverage or 0)
    rec.peakBoardRound = rec.peakBoardRound + (path.best_board.round or 0)
    rec.peakHeldUnitCoverage = rec.peakHeldUnitCoverage + (path.best_held.unit_coverage or 0)
    rec.peakHeldLevelCoverage = rec.peakHeldLevelCoverage + (path.best_held.level_coverage or 0)
    rec.peakHeldRound = rec.peakHeldRound + (path.best_held.round or 0)
    rec.heldDropFromPeak = rec.heldDropFromPeak + (path.held_drop_from_peak or 0)
    rec.boardDropFromPeak = rec.boardDropFromPeak + (path.board_drop_from_peak or 0)
    addThresholdAgg(rec.firstBoard, path.first_board)
    addThresholdAgg(rec.firstHeld, path.first_held)
    addCombatBands(rec.combatBands, path.combat_bands)
    addLossThresholdAgg(rec.lossThresholds, path.loss_thresholds)
    addFunnelAgg(rec.funnel, funnel)
    addSupportAccessAgg(rec.support, support)
    rec.finalGoldRatio = rec.finalGoldRatio + ((rec.target_gold > 0) and (finalGold / rec.target_gold) or 0)
    rec.wins = rec.wins + (traj.wins or 0)
    if traj.result == "win" then rec.completions = rec.completions + 1 end
    if heldCov.complete then rec.heldComplete = rec.heldComplete + 1 end
    if path.ever_board_complete then rec.everBoardComplete = rec.everBoardComplete + 1 end
    if path.ever_held_complete then rec.everHeldComplete = rec.everHeldComplete + 1 end
    if path.promising_lost then rec.promisingLost = rec.promisingLost + 1 end
    if path.undeployed_complete then rec.undeployedComplete = rec.undeployedComplete + 1 end
    if cov.complete then
      rec.complete = rec.complete + 1
      rec.completeWins = rec.completeWins + (traj.wins or 0)
      if traj.result == "win" then rec.completeCompletions = rec.completeCompletions + 1 end
    end
  end
end

local function addRun(a, traj)
  a.runs = a.runs + 1
  a.wins = a.wins + (traj.wins or 0)
  a.relicPicks = a.relicPicks + ((traj.metrics and traj.metrics.relicPicks) or 0)
  a.eventPicks = a.eventPicks + ((traj.metrics and traj.metrics.eventPicks) or 0)
  a.eventRelics = a.eventRelics + ((traj.metrics and traj.metrics.eventRelics) or 0)
  a.eventUnits = a.eventUnits + ((traj.metrics and traj.metrics.eventUnits) or 0)
  a.eventUnitFailures = a.eventUnitFailures + ((traj.metrics and traj.metrics.eventUnitFailures) or 0)
  a.eventUnitSingles = a.eventUnitSingles + ((traj.metrics and traj.metrics.eventUnitSingles) or 0)
  a.eventUnitPairCompleters = a.eventUnitPairCompleters + ((traj.metrics and traj.metrics.eventUnitPairCompleters) or 0)
  a.eventUnitMergeCompleters = a.eventUnitMergeCompleters + ((traj.metrics and traj.metrics.eventUnitMergeCompleters) or 0)
  a.eventUnitToBench = a.eventUnitToBench + ((traj.metrics and traj.metrics.eventUnitToBench) or 0)
  a.eventUnitToBoard = a.eventUnitToBoard + ((traj.metrics and traj.metrics.eventUnitToBoard) or 0)
  a.eventMutations = a.eventMutations + ((traj.metrics and traj.metrics.eventMutations) or 0)
  a.eventMutationFailures = a.eventMutationFailures + ((traj.metrics and traj.metrics.eventMutationFailures) or 0)
  a.eventGold = a.eventGold + ((traj.metrics and traj.metrics.eventGold) or 0)
  a.eventShopXp = a.eventShopXp + ((traj.metrics and traj.metrics.eventShopXp) or 0)
  a.eventShopTierUps = a.eventShopTierUps + ((traj.metrics and traj.metrics.eventShopTierUps) or 0)
  for _, ev in ipairs(traj.pairEvents or {}) do addUnitMergeEvent(a.unitMerge, ev, "pair") end
  for _, ev in ipairs(traj.mergeEvents or {}) do addUnitMergeEvent(a.unitMerge, ev, "merge") end
  Common.addMergeLifecycle(a.mergeLifecycle, traj)
  if traj.result == "win" then a.completions = a.completions + 1 end
  addFinalDuplicate(a.finalDuplicates, traj)
  addCommitment(a, traj)
  addPlanAccess(a, traj)
  for _, rd in ipairs(traj.rounds or {}) do
    local e = rd.economy or {}
    local d = rd.decisions or {}
    a.rounds = a.rounds + 1
    if d.xpGateBlocked then a.xpGateBlocks = a.xpGateBlocks + 1 end
    if d.xpGateUnitCoverage ~= nil or d.xpGateLevelCoverage ~= nil then
      a.xpGateObserved = a.xpGateObserved + 1
      a.xpGateUnitCoverage = a.xpGateUnitCoverage + (d.xpGateUnitCoverage or 0)
      a.xpGateLevelCoverage = a.xpGateLevelCoverage + (d.xpGateLevelCoverage or 0)
    end
    if rd.decided ~= nil then
      a.combatTotal = a.combatTotal + 1
      if rd.win then a.combatWins = a.combatWins + 1 end
    end
    if (rd.startGold or 0) > 0 then
      a.shopRatioSum = a.shopRatioSum + ((rd.shopFullCost or 0) / rd.startGold)
      a.shopRatioN = a.shopRatioN + 1
    end
    if rd.couldAffordFullShop then a.affordFull = a.affordFull + 1 end
    if (rd.desiredOffers or 0) > 0 then
      a.desiredRounds = a.desiredRounds + 1
      a.desiredCostSum = a.desiredCostSum + (rd.desiredOfferCost or 0)
      a.desiredCountSum = a.desiredCountSum + (rd.desiredOffers or 0)
      if rd.desiredOffersAffordable then a.desiredAffordable = a.desiredAffordable + 1 end
      if rd.desiredGoldAffordable then a.desiredGoldAffordable = a.desiredGoldAffordable + 1 end
      if rd.desiredSlotLimited then a.desiredSlotLimited = a.desiredSlotLimited + 1 end
      addVirtualBench(a.virtualBench, rd)
    end
    if (rd.shopTier or 1) <= 2 then
      a.earlyRounds = a.earlyRounds + 1
      if rd.couldAffordFullShop then a.earlyAffordFull = a.earlyAffordFull + 1 end
    end
    local available = (rd.startGold or 0) + (e.slotDeclineGold or 0) + (e.commanderDeclineGold or 0) + (e.sellGold or 0)
    local spend = (e.buyGold or 0) + (e.rerollGold or 0) + (e.xpGold or 0)
    if available > 0 then
      local pressure = spend / available
      if pressure > 1.5 then pressure = 1.5 end
      a.pressureSum = a.pressureSum + pressure
      a.pressureN = a.pressureN + 1
    end
    a.leftoverSum = a.leftoverSum + (rd.buildGold or 0)
    a.buyGold = a.buyGold + (e.buyGold or 0)
    a.sellGold = a.sellGold + (e.sellGold or 0)
    a.benchSellGold = a.benchSellGold + (e.benchSellGold or 0)
    a.boardSellGold = a.boardSellGold + (e.boardSellGold or 0)
    a.rerollGold = a.rerollGold + (e.rerollGold or 0)
    a.xpGold = a.xpGold + (e.xpGold or 0)
    a.buys = a.buys + (e.buys or 0)
    a.sells = a.sells + (e.sells or 0)
    a.benchSells = a.benchSells + (e.benchSells or 0)
    a.boardSells = a.boardSells + (e.boardSells or 0)
    a.pairBuys = a.pairBuys + (e.pairBuys or 0)
    a.mergeBuys = a.mergeBuys + (e.mergeBuys or 0)
    a.pairSupportOffers = a.pairSupportOffers + (e.pairSupportOffers or 0)
    a.boardDeploys = a.boardDeploys + (e.boardDeploys or 0)
    a.boardSwaps = a.boardSwaps + (e.boardSwaps or 0)
    a.rerolls = a.rerolls + (e.rerolls or 0)
    a.xpBuys = a.xpBuys + (e.xpBuys or 0)
    a.commanderAccepts = a.commanderAccepts + (e.commanderAccepts or 0)
    a.commanderDeclines = a.commanderDeclines + (e.commanderDeclines or 0)
    a.commanderPlacements = a.commanderPlacements + (e.commanderPlacements or 0)
    a.slotDeclines = a.slotDeclines + (e.slotDeclines or 0)
    a.slotAccepts = a.slotAccepts + (e.slotAccepts or 0)
    addTier(a, rd.shopTier, rd)
  end
end

local function finish(a)
  local spend = a.buyGold + a.rerollGold + a.xpGold
  local byUnitMerge, unitMergeWatch = finishUnitMerge(a.unitMerge)
  local mergeLifecycle = Common.finishMergeLifecycle(a.mergeLifecycle)
  local finalDuplicate = finishFinalDuplicate(a.finalDuplicates)
  local planAccess = {}
  for id, rec in pairs(a.planTargets or {}) do
    local supportAccess = finishSupportAccess(rec.support, rec.runs)
    planAccess[id] = {
      source = rec.source,
      target_gold = rec.target_gold,
      oracle = PLAN_ORACLES[id],
      runs = rec.runs,
      complete_rate = (rec.runs > 0) and (rec.complete / rec.runs) or 0,
      avg_unit_coverage = (rec.runs > 0) and (rec.unitCoverage / rec.runs) or 0,
      avg_level_coverage = (rec.runs > 0) and (rec.levelCoverage / rec.runs) or 0,
      held_complete_rate = (rec.runs > 0) and (rec.heldComplete / rec.runs) or 0,
      ever_board_complete_rate = (rec.runs > 0) and (rec.everBoardComplete / rec.runs) or 0,
      ever_held_complete_rate = (rec.runs > 0) and (rec.everHeldComplete / rec.runs) or 0,
      avg_final_held_unit_coverage = (rec.runs > 0) and (rec.heldUnitCoverage / rec.runs) or 0,
      avg_final_held_level_coverage = (rec.runs > 0) and (rec.heldLevelCoverage / rec.runs) or 0,
      avg_peak_board_unit_coverage = (rec.runs > 0) and (rec.peakBoardUnitCoverage / rec.runs) or 0,
      avg_peak_board_level_coverage = (rec.runs > 0) and (rec.peakBoardLevelCoverage / rec.runs) or 0,
      avg_peak_board_round = (rec.runs > 0) and (rec.peakBoardRound / rec.runs) or 0,
      avg_peak_held_unit_coverage = (rec.runs > 0) and (rec.peakHeldUnitCoverage / rec.runs) or 0,
      avg_peak_held_level_coverage = (rec.runs > 0) and (rec.peakHeldLevelCoverage / rec.runs) or 0,
      avg_peak_held_round = (rec.runs > 0) and (rec.peakHeldRound / rec.runs) or 0,
      avg_held_drop_from_peak = (rec.runs > 0) and (rec.heldDropFromPeak / rec.runs) or 0,
      avg_board_drop_from_peak = (rec.runs > 0) and (rec.boardDropFromPeak / rec.runs) or 0,
      promising_lost_rate = (rec.runs > 0) and (rec.promisingLost / rec.runs) or 0,
      undeployed_complete_rate = (rec.runs > 0) and (rec.undeployedComplete / rec.runs) or 0,
      first_board_level_round = finishThresholdAgg(rec.firstBoard, rec.runs),
      first_held_level_round = finishThresholdAgg(rec.firstHeld, rec.runs),
      combat_by_board_level_band = finishCombatBands(rec.combatBands),
      losses_by_board_level_threshold = finishLossThresholdAgg(rec.lossThresholds, rec.runs),
      acquisition_funnel = finishFunnel(rec.funnel, rec.runs),
      support_access = supportAccess,
      support_summary = summarizeSupportAccess(supportAccess),
      target_merge_lifecycle = Common.finishMergeLifecycle(rec.targetMergeLifecycle),
      avg_final_gold_ratio = (rec.runs > 0) and (rec.finalGoldRatio / rec.runs) or 0,
      avg_wins = (rec.runs > 0) and (rec.wins / rec.runs) or 0,
      avg_wins_when_complete = (rec.complete > 0) and (rec.completeWins / rec.complete) or 0,
      completion = (rec.runs > 0) and (rec.completions / rec.runs) or 0,
      completion_when_complete = (rec.complete > 0) and (rec.completeCompletions / rec.complete) or 0,
    }
  end
  local tiers = {}
  for tier, t in pairs(a.tiers) do
    tiers[tostring(tier)] = {
      rounds = t.rounds,
      full_shop_afford_rate = (t.rounds > 0) and (t.affordFull / t.rounds) or 0,
      desired_buy_all_rate = (t.desiredRounds > 0) and (t.desiredAffordable / t.desiredRounds) or 0,
      desired_gold_afford_rate = (t.desiredRounds > 0) and (t.desiredGoldAffordable / t.desiredRounds) or 0,
      desired_slot_limited_rate = (t.desiredRounds > 0) and (t.desiredSlotLimited / t.desiredRounds) or 0,
      rerolls_per_round = (t.rounds > 0) and (t.rerolls / t.rounds) or 0,
      buys_per_round = (t.rounds > 0) and (t.buys / t.rounds) or 0,
      pair_buys_per_round = (t.rounds > 0) and (t.pairBuys / t.rounds) or 0,
      merge_buys_per_round = (t.rounds > 0) and (t.mergeBuys / t.rounds) or 0,
      merge_per_pair_buy = (t.pairBuys > 0) and (t.mergeBuys / t.pairBuys) or 0,
      xp_buys_per_round = (t.rounds > 0) and (t.xpBuys / t.rounds) or 0,
      xp_gold_per_round = (t.rounds > 0) and (t.xpGold / t.rounds) or 0,
      buy_gold_per_round = (t.rounds > 0) and (t.buyGold / t.rounds) or 0,
      sell_gold_per_round = (t.rounds > 0) and (t.sellGold / t.rounds) or 0,
      leftover_per_round = (t.rounds > 0) and (t.leftover / t.rounds) or 0,
      virtual_bench = finishVirtualBench(t.virtualBench),
    }
  end
  local archetypes = {}
  for arch, ar in pairs(a.archetypes) do
    archetypes[arch] = {
      runs = ar.runs,
      commitment_rate = (ar.runs > 0) and (ar.committed / ar.runs) or 0,
      avg_commit_round = (ar.committed > 0) and (ar.commitRoundSum / ar.committed) or 0,
      avg_wins = (ar.runs > 0) and (ar.wins / ar.runs) or 0,
      completion = (ar.runs > 0) and (ar.completions / ar.runs) or 0,
      plan_formed_runs = ar.committed,
      plan_unformed_runs = ar.uncommitted,
      completion_given_plan = (ar.committed > 0) and (ar.committedCompletions / ar.committed) or 0,
      completion_without_plan = (ar.uncommitted > 0) and (ar.uncommittedCompletions / ar.uncommitted) or 0,
      avg_wins_given_plan = (ar.committed > 0) and (ar.committedWins / ar.committed) or 0,
      avg_wins_without_plan = (ar.uncommitted > 0) and (ar.uncommittedWins / ar.uncommitted) or 0,
    }
  end
  local virtualBench = finishVirtualBench(a.virtualBench)
  local bench4 = virtualBench["4"] or {}
  return {
    runs = a.runs,
    completion = (a.runs > 0) and (a.completions / a.runs) or 0,
    avg_wins = (a.runs > 0) and (a.wins / a.runs) or 0,
    avg_rounds = (a.runs > 0) and (a.rounds / a.runs) or 0,
    combat_winrate = (a.combatTotal > 0) and (a.combatWins / a.combatTotal) or 0,
    avg_full_shop_ratio = (a.shopRatioN > 0) and (a.shopRatioSum / a.shopRatioN) or 0,
    full_shop_afford_rate = (a.rounds > 0) and (a.affordFull / a.rounds) or 0,
    early_full_shop_afford_rate = (a.earlyRounds > 0) and (a.earlyAffordFull / a.earlyRounds) or 0,
    desired_buy_all_rate = (a.desiredRounds > 0) and (a.desiredAffordable / a.desiredRounds) or 0,
    desired_gold_afford_rate = (a.desiredRounds > 0) and (a.desiredGoldAffordable / a.desiredRounds) or 0,
    desired_slot_limited_rate = (a.desiredRounds > 0) and (a.desiredSlotLimited / a.desiredRounds) or 0,
    desired_bench4_buy_all_rate = bench4.buy_all_rate or 0,
    desired_bench4_space_limited_rate = bench4.space_limited_rate or 0,
    avg_desired_offer_cost = (a.desiredRounds > 0) and (a.desiredCostSum / a.desiredRounds) or 0,
    avg_desired_offer_count = (a.desiredRounds > 0) and (a.desiredCountSum / a.desiredRounds) or 0,
    avg_leftover_gold = (a.rounds > 0) and (a.leftoverSum / a.rounds) or 0,
    gold_pressure = (a.pressureN > 0) and (a.pressureSum / a.pressureN) or 0,
    buys_per_run = (a.runs > 0) and (a.buys / a.runs) or 0,
    sells_per_run = (a.runs > 0) and (a.sells / a.runs) or 0,
    sell_gold_per_run = (a.runs > 0) and (a.sellGold / a.runs) or 0,
    bench_sells_per_run = (a.runs > 0) and (a.benchSells / a.runs) or 0,
    board_sells_per_run = (a.runs > 0) and (a.boardSells / a.runs) or 0,
    bench_sell_gold_per_run = (a.runs > 0) and (a.benchSellGold / a.runs) or 0,
    board_sell_gold_per_run = (a.runs > 0) and (a.boardSellGold / a.runs) or 0,
    pair_buys_per_run = (a.runs > 0) and (a.pairBuys / a.runs) or 0,
    merge_buys_per_run = (a.runs > 0) and (a.mergeBuys / a.runs) or 0,
    pair_support_offers_per_run = (a.runs > 0) and (a.pairSupportOffers / a.runs) or 0,
    board_deploys_per_run = (a.runs > 0) and (a.boardDeploys / a.runs) or 0,
    board_swaps_per_run = (a.runs > 0) and (a.boardSwaps / a.runs) or 0,
    merge_per_pair_buy = (a.pairBuys > 0) and (a.mergeBuys / a.pairBuys) or 0,
    rerolls_per_run = (a.runs > 0) and (a.rerolls / a.runs) or 0,
    xp_buys_per_run = (a.runs > 0) and (a.xpBuys / a.runs) or 0,
    xp_gate_blocks_per_run = (a.runs > 0) and (a.xpGateBlocks / a.runs) or 0,
    xp_gate_block_round_rate = (a.rounds > 0) and (a.xpGateBlocks / a.rounds) or 0,
    avg_xp_gate_unit_coverage = (a.xpGateObserved > 0) and (a.xpGateUnitCoverage / a.xpGateObserved) or 0,
    avg_xp_gate_level_coverage = (a.xpGateObserved > 0) and (a.xpGateLevelCoverage / a.xpGateObserved) or 0,
    commander_accepts_per_run = (a.runs > 0) and (a.commanderAccepts / a.runs) or 0,
    commander_declines_per_run = (a.runs > 0) and (a.commanderDeclines / a.runs) or 0,
    commander_placements_per_run = (a.runs > 0) and (a.commanderPlacements / a.runs) or 0,
    relic_picks_per_run = (a.runs > 0) and (a.relicPicks / a.runs) or 0,
    event_picks_per_run = (a.runs > 0) and (a.eventPicks / a.runs) or 0,
    event_relics_per_run = (a.runs > 0) and (a.eventRelics / a.runs) or 0,
    event_units_per_run = (a.runs > 0) and (a.eventUnits / a.runs) or 0,
    event_unit_failures_per_run = (a.runs > 0) and (a.eventUnitFailures / a.runs) or 0,
    event_unit_failure_rate = ((a.eventUnits + a.eventUnitFailures) > 0)
      and (a.eventUnitFailures / (a.eventUnits + a.eventUnitFailures)) or 0,
    event_unit_single_rate = (a.eventUnits > 0) and (a.eventUnitSingles / a.eventUnits) or 0,
    event_unit_pair_rate = (a.eventUnits > 0) and (a.eventUnitPairCompleters / a.eventUnits) or 0,
    event_unit_merge_rate = (a.eventUnits > 0) and (a.eventUnitMergeCompleters / a.eventUnits) or 0,
    event_unit_progress_rate = (a.eventUnits > 0)
      and ((a.eventUnitPairCompleters + a.eventUnitMergeCompleters) / a.eventUnits) or 0,
    event_unit_bench_rate = (a.eventUnits > 0) and (a.eventUnitToBench / a.eventUnits) or 0,
    event_unit_board_rate = (a.eventUnits > 0) and (a.eventUnitToBoard / a.eventUnits) or 0,
    event_mutations_per_run = (a.runs > 0) and (a.eventMutations / a.runs) or 0,
    event_mutation_failures_per_run = (a.runs > 0) and (a.eventMutationFailures / a.runs) or 0,
    event_gold_per_run = (a.runs > 0) and (a.eventGold / a.runs) or 0,
    event_shop_xp_per_run = (a.runs > 0) and (a.eventShopXp / a.runs) or 0,
    event_shop_tier_ups_per_run = (a.runs > 0) and (a.eventShopTierUps / a.runs) or 0,
    slot_declines_per_run = (a.runs > 0) and (a.slotDeclines / a.runs) or 0,
    slot_accepts_per_run = (a.runs > 0) and (a.slotAccepts / a.runs) or 0,
    spend_split = {
      units = (spend > 0) and (a.buyGold / spend) or 0,
      reroll = (spend > 0) and (a.rerollGold / spend) or 0,
      xp = (spend > 0) and (a.xpGold / spend) or 0,
    },
    archetype_commitment_rate = (a.archetypeRuns > 0) and (a.archetypeCommitted / a.archetypeRuns) or 0,
    avg_archetype_commit_round = (a.archetypeCommitted > 0) and (a.archetypeCommitRoundSum / a.archetypeCommitted) or 0,
    virtual_bench = virtualBench,
    by_tier = tiers,
    by_archetype = archetypes,
    by_unit_merge = byUnitMerge,
    unit_merge_watch = unitMergeWatch,
    merge_lifecycle = mergeLifecycle,
    final_duplicate_saturation = finalDuplicate,
    plan_access = planAccess,
    plan_support_watch = summarizePlanSupport(planAccess),
  }
end

local profileAgg, policyAgg, cohortAgg = {}, {}, {}
for _, variant in ipairs(VARIANTS) do
  profileAgg[variant.key] = newAgg()
  policyAgg[variant.key] = {}
  cohortAgg[variant.key] = {}
  for _, cohort in ipairs(COHORTS) do cohortAgg[variant.key][cohort.id] = newAgg() end
end

print(string.format("== P6 ECONOMY VARIANTS : %d runs/policy/profile/bench ==", N))

for run = 1, N do
  for _, variant in ipairs(VARIANTS) do
    local pols = makePolicies(run)
    for _, p in ipairs(pols) do
      -- Same world seed for every policy/profile in a bench/run pair: profile comparisons are paired,
      -- while economy changes and policy actions still diverge deterministically through buys/rerolls/fights.
      local seed = BASE_SEED + (variant.benchIndex - 1) * 10000 + run * 137
      local traj = Rundriver.run(seed, p, {
        hpMult = HPM,
        economy = variant.profileId,
        benchSize = variant.benchSize,
        commanderMode = COMMANDER_MODE,
        runEvents = RUN_EVENTS,
        runEventMutations = RUN_EVENT_MUTATIONS,
        eventUnitTargeting = EVENT_UNIT_TARGETING,
        eventUnitPickCap = EVENT_UNIT_PICK_CAP,
        eventUnitRelicMargin = EVENT_UNIT_RELIC_MARGIN,
        eventMutationPickCap = EVENT_MUTATION_PICK_CAP,
        opponentMode = OPPONENT_MODE,
        opponentPressure = OPPONENT_PRESSURE,
        recordBoards = #PLAN_TARGETS > 0,
        recordEvents = #PLAN_TARGETS > 0,
      })
      addRun(profileAgg[variant.key], traj)
      local pa = policyAgg[variant.key][p.name]
      if not pa then pa = newAgg(); policyAgg[variant.key][p.name] = pa end
      addRun(pa, traj)
      for _, cohort in ipairs(COHORTS) do
        if cohort.match(p.name) then addRun(cohortAgg[variant.key][cohort.id], traj) end
      end
    end
  end
end

local profiles, byPolicy, byCohort = {}, {}, {}
for _, variant in ipairs(VARIANTS) do
  local profileId = variant.profileId
  profiles[variant.key] = finish(profileAgg[variant.key])
  profiles[variant.key].economy = profileId
  profiles[variant.key].bench_size = variant.benchSize
  profiles[variant.key].label = Economy.profiles[profileId].label
  if variant.key ~= profileId then
    profiles[variant.key].label = profiles[variant.key].label .. " / bench " .. tostring(variant.benchSize)
  end
  byPolicy[variant.key] = {}
  for name, a in pairs(policyAgg[variant.key]) do byPolicy[variant.key][name] = finish(a) end
  byCohort[variant.key] = {}
  for _, cohort in ipairs(COHORTS) do
    byCohort[variant.key][cohort.id] = finish(cohortAgg[variant.key][cohort.id])
    byCohort[variant.key][cohort.id].label = cohort.label
  end
end

print(string.format("%-30s %8s %8s %8s %8s %8s %8s %8s %8s %8s %8s",
  "profile/bench", "comp%", "wins", "ratio", "afford", "desired", "+4buy", "+4slot", "commit", "merge", "left"))
for _, variant in ipairs(VARIANTS) do
  local p = profiles[variant.key]
  print(string.format("%-30s %7.1f%% %8.2f %8.2f %7.1f%% %7.1f%% %7.1f%% %7.1f%% %7.1f%% %7.1f%% %8.2f",
    variant.key, p.completion * 100, p.avg_wins, p.avg_full_shop_ratio,
    p.full_shop_afford_rate * 100, p.desired_buy_all_rate * 100,
    p.desired_bench4_buy_all_rate * 100, p.desired_bench4_space_limited_rate * 100,
    p.archetype_commitment_rate * 100,
    p.merge_per_pair_buy * 100,
    p.avg_leftover_gold))
end

local function limitRows(rows, limit)
  local out = {}
  for i = 1, math.min(limit or #rows, #rows) do out[i] = rows[i] end
  return out
end

local function profileSummaryRow(variant)
  local p = profiles[variant.key]
  local dup = p.final_duplicate_saturation or {}
  return {
    economy_variant = variant.key,
    economy = p.economy,
    bench_size = p.bench_size,
    label = p.label,
    completion = p.completion,
    avg_wins = p.avg_wins,
    avg_rounds = p.avg_rounds,
    combat_winrate = p.combat_winrate,
    avg_full_shop_ratio = p.avg_full_shop_ratio,
    full_shop_afford_rate = p.full_shop_afford_rate,
    early_full_shop_afford_rate = p.early_full_shop_afford_rate,
    desired_buy_all_rate = p.desired_buy_all_rate,
    desired_gold_afford_rate = p.desired_gold_afford_rate,
    desired_slot_limited_rate = p.desired_slot_limited_rate,
    desired_bench4_buy_all_rate = p.desired_bench4_buy_all_rate,
    desired_bench4_space_limited_rate = p.desired_bench4_space_limited_rate,
    archetype_commitment_rate = p.archetype_commitment_rate,
    avg_archetype_commit_round = p.avg_archetype_commit_round,
    merge_per_pair_buy = p.merge_per_pair_buy,
    pair_buys_per_run = p.pair_buys_per_run,
    merge_buys_per_run = p.merge_buys_per_run,
    gold_pressure = p.gold_pressure,
    avg_leftover_gold = p.avg_leftover_gold,
    event_unit_progress_rate = p.event_unit_progress_rate,
    event_mutations_per_run = p.event_mutations_per_run,
    final_duplicate_id_run_rate = dup.duplicate_id_run_rate or 0,
    final_low_rank_duplicate_run_rate = dup.low_rank_duplicate_run_rate or 0,
    final_low_rank_duplicate_slots_per_run = dup.low_rank_duplicate_slots_per_run or 0,
    final_low_rank_duplicate_level_points_per_run = dup.low_rank_duplicate_level_points_per_run or 0,
    final_duplicate_top_units = dup.top_units or {},
  }
end

local function policySummaryRow(economyVariant, policyName, p)
  local dup = p.final_duplicate_saturation or {}
  return {
    economy_variant = economyVariant,
    policy = policyName,
    runs = p.runs,
    completion = p.completion,
    avg_wins = p.avg_wins,
    avg_rounds = p.avg_rounds,
    combat_winrate = p.combat_winrate,
    desired_buy_all_rate = p.desired_buy_all_rate,
    desired_gold_afford_rate = p.desired_gold_afford_rate,
    desired_slot_limited_rate = p.desired_slot_limited_rate,
    archetype_commitment_rate = p.archetype_commitment_rate,
    merge_per_pair_buy = p.merge_per_pair_buy,
    gold_pressure = p.gold_pressure,
    avg_leftover_gold = p.avg_leftover_gold,
    xp_gate_blocks_per_run = p.xp_gate_blocks_per_run,
    avg_xp_gate_unit_coverage = p.avg_xp_gate_unit_coverage,
    avg_xp_gate_level_coverage = p.avg_xp_gate_level_coverage,
    event_unit_progress_rate = p.event_unit_progress_rate,
    final_duplicate_id_run_rate = dup.duplicate_id_run_rate or 0,
    final_low_rank_duplicate_run_rate = dup.low_rank_duplicate_run_rate or 0,
    final_low_rank_duplicate_slots_per_run = dup.low_rank_duplicate_slots_per_run or 0,
    final_low_rank_duplicate_level_points_per_run = dup.low_rank_duplicate_level_points_per_run or 0,
    final_duplicate_top_units = dup.top_units or {},
  }
end

local function supportSummaryLite(support)
  support = support or {}
  local relics = support.relics or {}
  local commanders = support.commanders or {}
  local timing = support.timing or {}
  return {
    relic_focused_offer_run_rate = relics.focused_offer_run_rate or 0,
    relic_focused_pick_run_rate = relics.focused_pick_run_rate or 0,
    relic_focused_pick_gap = relics.focused_pick_gap or 0,
    relic_missed_focused_pick_per_run = relics.missed_focused_pick_per_run or 0,
    commander_focused_candidate_run_rate = commanders.focused_candidate_run_rate or 0,
    commander_focused_placement_run_rate = commanders.focused_placement_run_rate or 0,
    commander_focused_placement_gap = commanders.focused_placement_gap or 0,
    commander_missed_focused_placement_per_run = commanders.missed_focused_placement_per_run or 0,
    focused_support_seen_run_rate = timing.focused_support_seen_run_rate or 0,
    focused_support_used_run_rate = timing.focused_support_used_run_rate or 0,
    focused_support_win_delta = timing.focused_support_win_delta or 0,
    focused_support_win_delta_observed = timing.focused_support_win_delta_observed == true,
  }
end

local function targetSummaryRow(economyVariant, target, p)
  local access = (p.plan_access or {})[target.id]
  if not access then return nil end
  local oracle = access.oracle or {}
  return {
    economy_variant = economyVariant,
    target = target.id,
    source = access.source,
    target_gold = access.target_gold,
    oracle_forced_winrate = oracle.forced_winrate,
    oracle_avg_seconds = oracle.avg_seconds,
    oracle_coherence = oracle.coherence,
    complete_rate = access.complete_rate,
    held_complete_rate = access.held_complete_rate,
    ever_held_complete_rate = access.ever_held_complete_rate,
    avg_final_held_level_coverage = access.avg_final_held_level_coverage,
    avg_peak_held_level_coverage = access.avg_peak_held_level_coverage,
    avg_peak_held_round = access.avg_peak_held_round,
    promising_lost_rate = access.promising_lost_rate,
    undeployed_complete_rate = access.undeployed_complete_rate,
    avg_wins = access.avg_wins,
    completion = access.completion,
    support = supportSummaryLite(access.support_summary),
  }
end

local function compactSummary()
  local profileRows, policyRows, targetRows = {}, {}, {}
  for _, variant in ipairs(VARIANTS) do
    profileRows[#profileRows + 1] = profileSummaryRow(variant)

    local names = {}
    for name in pairs(byPolicy[variant.key] or {}) do names[#names + 1] = name end
    table.sort(names)
    for _, name in ipairs(names) do
      policyRows[#policyRows + 1] = policySummaryRow(variant.key, name, byPolicy[variant.key][name])
    end

    for _, target in ipairs(PLAN_TARGETS) do
      local row = targetSummaryRow(variant.key, target, profiles[variant.key])
      if row then targetRows[#targetRows + 1] = row end
    end
  end

  table.sort(policyRows, function(a, b)
    if a.completion ~= b.completion then return a.completion > b.completion end
    if a.avg_wins ~= b.avg_wins then return a.avg_wins > b.avg_wins end
    if a.combat_winrate ~= b.combat_winrate then return a.combat_winrate > b.combat_winrate end
    if a.economy_variant ~= b.economy_variant then return a.economy_variant < b.economy_variant end
    return a.policy < b.policy
  end)
  local bottomPolicyRows = {}
  for i = #policyRows, 1, -1 do bottomPolicyRows[#bottomPolicyRows + 1] = policyRows[i] end

  table.sort(targetRows, function(a, b)
    if a.held_complete_rate ~= b.held_complete_rate then return a.held_complete_rate > b.held_complete_rate end
    if a.avg_peak_held_level_coverage ~= b.avg_peak_held_level_coverage then
      return a.avg_peak_held_level_coverage > b.avg_peak_held_level_coverage
    end
    if a.economy_variant ~= b.economy_variant then return a.economy_variant < b.economy_variant end
    return a.target < b.target
  end)

  return {
    runs_per_policy_profile = N,
    config = {
      hp_mult = HPM,
      commander_mode = COMMANDER_MODE,
      run_events = RUN_EVENTS,
      event_unit_targeting = EVENT_UNIT_TARGETING,
      event_unit_pick_cap = EVENT_UNIT_PICK_CAP,
      policies = Common.env("PIT_POLICIES"),
      economy_profiles = Common.env("PIT_ECON_PROFILES"),
      bench_sizes = Common.env("PIT_BENCH_SIZES"),
      bench_caps = Common.env("PIT_BENCH_CAPS"),
      plan_targets = Common.env("PIT_PLAN_TARGETS"),
      plan_target_specs = Common.env("PIT_PLAN_TARGET_SPECS"),
      opponent_mode = OPPONENT_MODE,
      oppgen_pressure = OPPONENT_PRESSURE,
    },
    profile_rows = profileRows,
    policy_rows_top = limitRows(policyRows, 16),
    policy_rows_bottom = limitRows(bottomPolicyRows, 16),
    target_rows = limitRows(targetRows, 24),
  }
end

local compact = compactSummary()

local payload = {
  mode = "economy",
  runs_per_policy_profile = N,
  config = {
    hp_mult = HPM,
    commander_mode = COMMANDER_MODE,
    run_events = RUN_EVENTS,
    event_unit_targeting = EVENT_UNIT_TARGETING,
    event_unit_pick_cap = EVENT_UNIT_PICK_CAP,
    policies = Common.env("PIT_POLICIES"),
    economy_profiles = Common.env("PIT_ECON_PROFILES"),
    bench_sizes = Common.env("PIT_BENCH_SIZES"),
    bench_caps = Common.env("PIT_BENCH_CAPS"),
    plan_oracle_matches = ORACLE_MATCHES,
    plan_oracle_rounds = Common.env("PIT_PLAN_ORACLE_ROUNDS"),
    plan_targets = Common.env("PIT_PLAN_TARGETS"),
    plan_target_specs = Common.env("PIT_PLAN_TARGET_SPECS"),
    opponent_mode = OPPONENT_MODE,
    oppgen_pressure = OPPONENT_PRESSURE,
  },
  profiles = profiles,
  by_cohort = byCohort,
  by_policy = byPolicy,
  summary = compact,
}

local path = Common.writeReport("economy", payload, { refSummary = compact })
print("=> ecrit " .. path .. " (+ runs/report-ref.json)")
