-- tools/scenarios/economy.lua
-- MODE P6 -- ECONOMY VARIANTS. Runs the real policy driver under several
-- opt-in economy profiles and reports pressure, leftover, desired-offer
-- affordability, full-shop affordability, commitment, completion, and spend split.

local Common = require("tools.scenarios.common")
local Economy = require("src.run.economy")
local Rundriver = require("src.lab.rundriver")
local Policies = require("src.lab.policies")

local N = require("tools.scenarios.argn")(60)
local BASE_SEED = 1060000
local HPM = tonumber(os.getenv("PIT_HP_MULT"))
-- Extra holding capacity beyond the real board+bench capacity used by Rundriver.
-- Cap 0 is the current gameplay model; cap 4 answers "what if the player had 4 more reserve slots?"
local BENCH_CAPS = { 0, 2, 4, 6 }

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
  return Policies.analysisSet(brng)
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
    rerolls = 0, xpBuys = 0,
    slotDeclines = 0, slotAccepts = 0,
    archetypeRuns = 0, archetypeCommitted = 0, archetypeCommitRoundSum = 0,
    virtualBench = {}, tiers = {}, archetypes = {},
  }
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

local function addRun(a, traj)
  a.runs = a.runs + 1
  a.wins = a.wins + (traj.wins or 0)
  if traj.result == "win" then a.completions = a.completions + 1 end
  addCommitment(a, traj)
  for _, rd in ipairs(traj.rounds or {}) do
    local e = rd.economy or {}
    a.rounds = a.rounds + 1
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
    a.rerolls = a.rerolls + (e.rerolls or 0)
    a.xpBuys = a.xpBuys + (e.xpBuys or 0)
    a.slotDeclines = a.slotDeclines + (e.slotDeclines or 0)
    a.slotAccepts = a.slotAccepts + (e.slotAccepts or 0)
    addTier(a, rd.shopTier, rd)
  end
end

local function finish(a)
  local spend = a.buyGold + a.rerollGold + a.xpGold
  local tiers = {}
  for tier, t in pairs(a.tiers) do
    tiers[tostring(tier)] = {
      rounds = t.rounds,
      full_shop_afford_rate = (t.rounds > 0) and (t.affordFull / t.rounds) or 0,
      desired_buy_all_rate = (t.desiredRounds > 0) and (t.desiredAffordable / t.desiredRounds) or 0,
      desired_gold_afford_rate = (t.desiredRounds > 0) and (t.desiredGoldAffordable / t.desiredRounds) or 0,
      desired_slot_limited_rate = (t.desiredRounds > 0) and (t.desiredSlotLimited / t.desiredRounds) or 0,
      rerolls_per_round = (t.rounds > 0) and (t.rerolls / t.rounds) or 0,
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
    rerolls_per_run = (a.runs > 0) and (a.rerolls / a.runs) or 0,
    xp_buys_per_run = (a.runs > 0) and (a.xpBuys / a.runs) or 0,
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
  }
end

local profileAgg, policyAgg, cohortAgg = {}, {}, {}
for _, profileId in ipairs(Economy.order) do
  profileAgg[profileId] = newAgg()
  policyAgg[profileId] = {}
  cohortAgg[profileId] = {}
  for _, cohort in ipairs(COHORTS) do cohortAgg[profileId][cohort.id] = newAgg() end
end

print(string.format("== P6 ECONOMY VARIANTS : %d runs/policy/profile ==", N))

for run = 1, N do
  for pi, profileId in ipairs(Economy.order) do
    local pols = makePolicies(run)
    for _, p in ipairs(pols) do
      -- Same world seed for every policy in a profile/run pair: comparisons are paired,
      -- while policy actions still diverge deterministically through buys/rerolls/fights.
      local seed = BASE_SEED + pi * 100000 + run * 137
      local traj = Rundriver.run(seed, p, { hpMult = HPM, economy = profileId })
      addRun(profileAgg[profileId], traj)
      local pa = policyAgg[profileId][p.name]
      if not pa then pa = newAgg(); policyAgg[profileId][p.name] = pa end
      addRun(pa, traj)
      for _, cohort in ipairs(COHORTS) do
        if cohort.match(p.name) then addRun(cohortAgg[profileId][cohort.id], traj) end
      end
    end
  end
end

local profiles, byPolicy, byCohort = {}, {}, {}
for _, profileId in ipairs(Economy.order) do
  profiles[profileId] = finish(profileAgg[profileId])
  profiles[profileId].label = Economy.profiles[profileId].label
  byPolicy[profileId] = {}
  for name, a in pairs(policyAgg[profileId]) do byPolicy[profileId][name] = finish(a) end
  byCohort[profileId] = {}
  for _, cohort in ipairs(COHORTS) do
    byCohort[profileId][cohort.id] = finish(cohortAgg[profileId][cohort.id])
    byCohort[profileId][cohort.id].label = cohort.label
  end
end

print(string.format("%-24s %8s %8s %8s %8s %8s %8s %8s %8s %8s",
  "profile", "comp%", "wins", "ratio", "afford", "desired", "+4buy", "+4slot", "commit", "left"))
for _, profileId in ipairs(Economy.order) do
  local p = profiles[profileId]
  print(string.format("%-24s %7.1f%% %8.2f %8.2f %7.1f%% %7.1f%% %7.1f%% %7.1f%% %7.1f%% %8.2f",
    profileId, p.completion * 100, p.avg_wins, p.avg_full_shop_ratio,
    p.full_shop_afford_rate * 100, p.desired_buy_all_rate * 100,
    p.desired_bench4_buy_all_rate * 100, p.desired_bench4_space_limited_rate * 100,
    p.archetype_commitment_rate * 100,
    p.avg_leftover_gold))
end

local payload = {
  mode = "economy",
  runs_per_policy_profile = N,
  profiles = profiles,
  by_cohort = byCohort,
  by_policy = byPolicy,
}

local summary = { runs_per_policy_profile = N, profiles = {} }
for _, profileId in ipairs(Economy.order) do
  local p = profiles[profileId]
  summary.profiles[profileId] = {
    completion = p.completion,
    avg_wins = p.avg_wins,
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
    avg_leftover_gold = p.avg_leftover_gold,
    gold_pressure = p.gold_pressure,
    sells_per_run = p.sells_per_run,
    sell_gold_per_run = p.sell_gold_per_run,
    bench_sells_per_run = p.bench_sells_per_run,
    board_sells_per_run = p.board_sells_per_run,
    pair_buys_per_run = p.pair_buys_per_run,
    merge_buys_per_run = p.merge_buys_per_run,
    cohorts = {
      broad_naive = byCohort[profileId].broad_naive and {
        avg_wins = byCohort[profileId].broad_naive.avg_wins,
        desired_buy_all_rate = byCohort[profileId].broad_naive.desired_buy_all_rate,
        desired_slot_limited_rate = byCohort[profileId].broad_naive.desired_slot_limited_rate,
      } or nil,
      broad_prune = byCohort[profileId].broad_prune and {
        avg_wins = byCohort[profileId].broad_prune.avg_wins,
        desired_buy_all_rate = byCohort[profileId].broad_prune.desired_buy_all_rate,
        desired_slot_limited_rate = byCohort[profileId].broad_prune.desired_slot_limited_rate,
        sells_per_run = byCohort[profileId].broad_prune.sells_per_run,
      } or nil,
      broad_plan = byCohort[profileId].broad_plan and {
        avg_wins = byCohort[profileId].broad_plan.avg_wins,
        desired_buy_all_rate = byCohort[profileId].broad_plan.desired_buy_all_rate,
        desired_slot_limited_rate = byCohort[profileId].broad_plan.desired_slot_limited_rate,
        sells_per_run = byCohort[profileId].broad_plan.sells_per_run,
        board_sells_per_run = byCohort[profileId].broad_plan.board_sells_per_run,
        pair_buys_per_run = byCohort[profileId].broad_plan.pair_buys_per_run,
        merge_buys_per_run = byCohort[profileId].broad_plan.merge_buys_per_run,
      } or nil,
    },
  }
end

local path = Common.writeReport("economy", payload, { refSummary = summary })
print("=> ecrit " .. path .. " (+ runs/report-ref.json)")
