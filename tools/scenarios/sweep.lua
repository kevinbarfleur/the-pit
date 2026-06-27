-- tools/scenarios/sweep.lua
-- MODE P9 -- INTEGRATED BALANCE SWEEP.
--
-- Crosses economy profiles, combat pacing profiles, and policy filters in one
-- deterministic grid. Use the narrower scenarios for deep diagnosis; use this
-- one to spot interactions between economy pressure, fight duration, reroll
-- conversion, and policy/archetype access.

local Common = require("tools.scenarios.common")
local Economy = require("src.run.economy")
local Rundriver = require("src.lab.rundriver")
local Policies = require("src.lab.policies")

local N = require("tools.scenarios.argn")(20)
local BASE_SEED = 1460000
local COMMANDER_MODE = Common.env("PIT_COMMANDER_MODE") or "ignore"

local DEFAULT_ECONOMIES = { "baseline", "sap_cost", "early_curve" }
local ECONOMY_ORDER = Common.envCsvAny({ "PIT_SWEEP_ECONOMIES", "PIT_ECON_PROFILES" }) or DEFAULT_ECONOMIES
for _, profileId in ipairs(ECONOMY_ORDER) do
  assert(Economy.profiles[profileId], "profil economie inconnu: " .. tostring(profileId))
end

local DEFAULT_PACE_PROFILES = {
  { id = "live_hp2_cd1_f17", label = "current hp x2, cd x1, fatigue 17s", hpMult = 2, cdMult = 1, fatigueStart = 1020 },
  { id = "hp2_cd15_f24", label = "hp x2, cd x1.5, fatigue 24s", hpMult = 2, cdMult = 1.5, fatigueStart = 1440 },
  { id = "hp2_cd2_f24", label = "hp x2, cd x2, fatigue 24s", hpMult = 2, cdMult = 2, fatigueStart = 1440 },
}
local PACE_PROFILES = Common.paceProfiles(DEFAULT_PACE_PROFILES, {
  specEnv = "PIT_SWEEP_PACE_PROFILES",
  fallbackSpecEnv = "PIT_PACE_PROFILES",
  filterEnv = "PIT_SWEEP_PACES",
  fallbackFilterEnv = "PIT_PACE_IDS",
})

local function makePolicies(runIndex)
  local pols = Policies.analysisSet(love.math.newRandomGenerator(23000 + runIndex))
  return Common.filteredRows(pols, Common.envCsv("PIT_POLICIES"), "name")
end

local function newAgg(fatigueStart)
  return {
    runs = 0, completions = 0, wins = 0, rounds = 0,
    combatWins = 0, combatTotal = 0, undecided = 0,
    desiredRounds = 0, desiredAffordable = 0, desiredGoldAffordable = 0, desiredSlotLimited = 0,
    leftoverSum = 0, pressureSum = 0, pressureN = 0,
    buyGold = 0, rerollGold = 0, xpGold = 0,
    buys = 0, pairBuys = 0, mergeBuys = 0, rerolls = 0, xpBuys = 0,
    commanderAccepts = 0, commanderDeclines = 0, commanderPlacements = 0, relicPicks = 0,
    archetypeRuns = 0, archetypeCommitted = 0, archetypeCommitRoundSum = 0,
    mergeLifecycle = Common.mergeLifecycleAgg(),
    duration = Common.durationSet(fatigueStart),
  }
end

local function addCommitment(a, traj)
  if not traj.archetype then return end
  a.archetypeRuns = a.archetypeRuns + 1
  if traj.archetypeCommitRound then
    a.archetypeCommitted = a.archetypeCommitted + 1
    a.archetypeCommitRoundSum = a.archetypeCommitRoundSum + traj.archetypeCommitRound
  end
end

local function addRun(a, traj)
  a.runs = a.runs + 1
  a.wins = a.wins + (traj.wins or 0)
  a.relicPicks = a.relicPicks + ((traj.metrics and traj.metrics.relicPicks) or 0)
  Common.addMergeLifecycle(a.mergeLifecycle, traj)
  if traj.result == "win" then a.completions = a.completions + 1 end
  addCommitment(a, traj)
  for _, rd in ipairs(traj.rounds or {}) do
    local e = rd.economy or {}
    a.rounds = a.rounds + 1
    if rd.decided ~= nil then
      a.combatTotal = a.combatTotal + 1
      if rd.win then a.combatWins = a.combatWins + 1 end
      if rd.decided == false then a.undecided = a.undecided + 1 end
    end
    if (rd.desiredOffers or 0) > 0 then
      a.desiredRounds = a.desiredRounds + 1
      if rd.desiredOffersAffordable then a.desiredAffordable = a.desiredAffordable + 1 end
      if rd.desiredGoldAffordable then a.desiredGoldAffordable = a.desiredGoldAffordable + 1 end
      if rd.desiredSlotLimited then a.desiredSlotLimited = a.desiredSlotLimited + 1 end
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
    a.rerollGold = a.rerollGold + (e.rerollGold or 0)
    a.xpGold = a.xpGold + (e.xpGold or 0)
    a.buys = a.buys + (e.buys or 0)
    a.pairBuys = a.pairBuys + (e.pairBuys or 0)
    a.mergeBuys = a.mergeBuys + (e.mergeBuys or 0)
    a.rerolls = a.rerolls + (e.rerolls or 0)
    a.xpBuys = a.xpBuys + (e.xpBuys or 0)
    a.commanderAccepts = a.commanderAccepts + (e.commanderAccepts or 0)
    a.commanderDeclines = a.commanderDeclines + (e.commanderDeclines or 0)
    a.commanderPlacements = a.commanderPlacements + (e.commanderPlacements or 0)
    Common.addRoundDuration(a.duration, rd)
  end
end

local function finish(a)
  local spend = a.buyGold + a.rerollGold + a.xpGold
  local mergeLifecycle = Common.finishMergeLifecycle(a.mergeLifecycle)
  local duration = Common.finishDurationSet(a.duration)
  local durationFit = Common.durationFit(duration)
  return {
    runs = a.runs,
    completion = (a.runs > 0) and (a.completions / a.runs) or 0,
    avg_wins = (a.runs > 0) and (a.wins / a.runs) or 0,
    avg_rounds = (a.runs > 0) and (a.rounds / a.runs) or 0,
    combat_winrate = (a.combatTotal > 0) and (a.combatWins / a.combatTotal) or 0,
    undecided_rate = (a.combatTotal > 0) and (a.undecided / a.combatTotal) or 0,
    desired_buy_all_rate = (a.desiredRounds > 0) and (a.desiredAffordable / a.desiredRounds) or 0,
    desired_gold_afford_rate = (a.desiredRounds > 0) and (a.desiredGoldAffordable / a.desiredRounds) or 0,
    desired_slot_limited_rate = (a.desiredRounds > 0) and (a.desiredSlotLimited / a.desiredRounds) or 0,
    avg_leftover_gold = (a.rounds > 0) and (a.leftoverSum / a.rounds) or 0,
    gold_pressure = (a.pressureN > 0) and (a.pressureSum / a.pressureN) or 0,
    buys_per_run = (a.runs > 0) and (a.buys / a.runs) or 0,
    pair_buys_per_run = (a.runs > 0) and (a.pairBuys / a.runs) or 0,
    merge_buys_per_run = (a.runs > 0) and (a.mergeBuys / a.runs) or 0,
    merge_per_pair_buy = (a.pairBuys > 0) and (a.mergeBuys / a.pairBuys) or 0,
    pair_resolve_rate = mergeLifecycle.resolve_rate,
    avg_pair_rounds_to_merge = mergeLifecycle.avg_rounds_to_merge,
    unresolved_pairs_per_run = (a.runs > 0) and (mergeLifecycle.unresolved / a.runs) or 0,
    rerolls_per_run = (a.runs > 0) and (a.rerolls / a.runs) or 0,
    xp_buys_per_run = (a.runs > 0) and (a.xpBuys / a.runs) or 0,
    commander_accepts_per_run = (a.runs > 0) and (a.commanderAccepts / a.runs) or 0,
    commander_declines_per_run = (a.runs > 0) and (a.commanderDeclines / a.runs) or 0,
    commander_placements_per_run = (a.runs > 0) and (a.commanderPlacements / a.runs) or 0,
    relic_picks_per_run = (a.runs > 0) and (a.relicPicks / a.runs) or 0,
    spend_split = {
      units = (spend > 0) and (a.buyGold / spend) or 0,
      reroll = (spend > 0) and (a.rerollGold / spend) or 0,
      xp = (spend > 0) and (a.xpGold / spend) or 0,
    },
    archetype_commitment_rate = (a.archetypeRuns > 0) and (a.archetypeCommitted / a.archetypeRuns) or 0,
    avg_archetype_commit_round = (a.archetypeCommitted > 0) and (a.archetypeCommitRoundSum / a.archetypeCommitted) or 0,
    merge_lifecycle = mergeLifecycle,
    duration = duration,
    duration_fit = durationFit,
    duration_fit_score = durationFit.score,
  }
end

local grid, policyGrid = {}, {}
for _, econ in ipairs(ECONOMY_ORDER) do
  grid[econ] = {}
  policyGrid[econ] = {}
  for _, pace in ipairs(PACE_PROFILES) do
    grid[econ][pace.id] = newAgg(pace.fatigueStart)
    policyGrid[econ][pace.id] = {}
  end
end

print(string.format("== P9 INTEGRATED SWEEP : %d runs/policy/economy/pace ==", N))

for run = 1, N do
  local pols = makePolicies(run)
  for ei, econ in ipairs(ECONOMY_ORDER) do
    for pi, pace in ipairs(PACE_PROFILES) do
      for _, p in ipairs(pols) do
        local seed = BASE_SEED + run * 151 + ei * 100000 + pi * 1000000
        local traj = Rundriver.run(seed, p, {
          economy = econ,
          commanderMode = COMMANDER_MODE,
          hpMult = pace.hpMult,
          fatigue = Common.fatigueOptions(pace.fatigueStart, pace.fatigueBase, pace.fatigueRamp),
          compMutator = Common.cooldownMutator(pace.cdMult),
        })
        addRun(grid[econ][pace.id], traj)
        local pa = policyGrid[econ][pace.id][p.name]
        if not pa then pa = newAgg(pace.fatigueStart); policyGrid[econ][pace.id][p.name] = pa end
        addRun(pa, traj)
      end
    end
  end
end

local cells, byPolicy, summaryCells = {}, {}, {}
for _, econ in ipairs(ECONOMY_ORDER) do
  cells[econ] = {}
  byPolicy[econ] = {}
  summaryCells[econ] = {}
  for _, pace in ipairs(PACE_PROFILES) do
    local row = finish(grid[econ][pace.id])
    row.economy_label = Economy.profiles[econ].label
    row.pace_label = pace.label
    row.hp_mult = pace.hpMult
    row.cooldown_mult = pace.cdMult
    row.fatigue_start = pace.fatigueStart
    cells[econ][pace.id] = row
    summaryCells[econ][pace.id] = {
      completion = row.completion,
      avg_wins = row.avg_wins,
      combat_winrate = row.combat_winrate,
      desired_buy_all_rate = row.desired_buy_all_rate,
      desired_slot_limited_rate = row.desired_slot_limited_rate,
      gold_pressure = row.gold_pressure,
      merge_per_pair_buy = row.merge_per_pair_buy,
      pair_resolve_rate = row.pair_resolve_rate,
      unresolved_pairs_per_run = row.unresolved_pairs_per_run,
      commander_placements_per_run = row.commander_placements_per_run,
      relic_picks_per_run = row.relic_picks_per_run,
      early_avg_seconds = row.duration.early.avg_seconds,
      early_under_5s_rate = row.duration.early.under_5s_rate,
      p50_seconds = row.duration.all.p50_seconds,
      p90_seconds = row.duration.all.p90_seconds,
      fatigue_touch_rate = row.duration.all.fatigue_touch_rate,
      duration_fit_score = row.duration_fit.score,
    }
    byPolicy[econ][pace.id] = {}
    for name, a in pairs(policyGrid[econ][pace.id]) do byPolicy[econ][pace.id][name] = finish(a) end
  end
end

local function clamp(v, lo, hi)
  if v < lo then return lo end
  if v > hi then return hi end
  return v
end

local function recommendationRow(econ, paceId, row, live)
  local winsDelta = live and (row.avg_wins - live.avg_wins) or 0
  local completionDelta = live and (row.completion - live.completion) or 0
  local selectionScore = row.duration_fit_score
    + clamp(winsDelta * 0.04, -0.05, 0.05)
    + clamp(completionDelta * 0.25, -0.025, 0.025)
  return {
    economy = econ,
    pace = paceId,
    selection_score = selectionScore,
    duration_fit_score = row.duration_fit_score,
    avg_wins = row.avg_wins,
    completion = row.completion,
    wins_delta_vs_live = winsDelta,
    completion_delta_vs_live = completionDelta,
    early_avg_seconds = row.duration.early.avg_seconds,
    p50_seconds = row.duration.all.p50_seconds,
    p90_seconds = row.duration.all.p90_seconds,
    fatigue_touch_rate = row.duration.all.fatigue_touch_rate,
    desired_buy_all_rate = row.desired_buy_all_rate,
    merge_per_pair_buy = row.merge_per_pair_buy,
  }
end

local function sortRecommendationRows(rows)
  table.sort(rows, function(a, b)
    if a.selection_score ~= b.selection_score then return a.selection_score > b.selection_score end
    if a.duration_fit_score ~= b.duration_fit_score then return a.duration_fit_score > b.duration_fit_score end
    if a.avg_wins ~= b.avg_wins then return a.avg_wins > b.avg_wins end
    if a.economy ~= b.economy then return a.economy < b.economy end
    return a.pace < b.pace
  end)
end

local function buildRecommendations(cells)
  local byEconomy, globalAgg = {}, {}
  for _, econ in ipairs(ECONOMY_ORDER) do
    local live = cells[econ].live or cells[econ].live_hp2_cd1_f17
    local rows = {}
    for _, pace in ipairs(PACE_PROFILES) do
      local row = recommendationRow(econ, pace.id, cells[econ][pace.id], live)
      rows[#rows + 1] = row
      local g = globalAgg[pace.id]
      if not g then
        g = {
          pace = pace.id, economies = 0, selection_score = 0, duration_fit_score = 0,
          avg_wins = 0, completion = 0, wins_delta_vs_live = 0, completion_delta_vs_live = 0,
          early_avg_seconds = 0, p50_seconds = 0, p90_seconds = 0, fatigue_touch_rate = 0,
        }
        globalAgg[pace.id] = g
      end
      g.economies = g.economies + 1
      g.selection_score = g.selection_score + row.selection_score
      g.duration_fit_score = g.duration_fit_score + row.duration_fit_score
      g.avg_wins = g.avg_wins + row.avg_wins
      g.completion = g.completion + row.completion
      g.wins_delta_vs_live = g.wins_delta_vs_live + row.wins_delta_vs_live
      g.completion_delta_vs_live = g.completion_delta_vs_live + row.completion_delta_vs_live
      g.early_avg_seconds = g.early_avg_seconds + row.early_avg_seconds
      g.p50_seconds = g.p50_seconds + row.p50_seconds
      g.p90_seconds = g.p90_seconds + row.p90_seconds
      g.fatigue_touch_rate = g.fatigue_touch_rate + row.fatigue_touch_rate
    end
    sortRecommendationRows(rows)
    byEconomy[econ] = rows
  end

  local global = {}
  for _, g in pairs(globalAgg) do
    local n = g.economies
    global[#global + 1] = {
      pace = g.pace,
      economies = n,
      selection_score = g.selection_score / n,
      duration_fit_score = g.duration_fit_score / n,
      avg_wins = g.avg_wins / n,
      completion = g.completion / n,
      wins_delta_vs_live = g.wins_delta_vs_live / n,
      completion_delta_vs_live = g.completion_delta_vs_live / n,
      early_avg_seconds = g.early_avg_seconds / n,
      p50_seconds = g.p50_seconds / n,
      p90_seconds = g.p90_seconds / n,
      fatigue_touch_rate = g.fatigue_touch_rate / n,
    }
  end
  sortRecommendationRows(global)

  return {
    scoring = "selection_score = duration_fit_score + clamp(wins_delta_vs_live*0.04,-0.05,0.05) + clamp(completion_delta_vs_live*0.25,-0.025,0.025)",
    baseline = "live profile in the same economy when present",
    by_economy = byEconomy,
    global = global,
  }
end

local recommendations = buildRecommendations(cells)

print(string.format("%-24s %-16s %7s %7s %8s %7s %8s %8s %8s %8s %8s",
  "economy", "pace", "comp%", "wins", "combat%", "fit", "early_s", "p50_s", "fatigue", "desired", "merge"))
for _, econ in ipairs(ECONOMY_ORDER) do
  for _, pace in ipairs(PACE_PROFILES) do
    local r = cells[econ][pace.id]
    print(string.format("%-24s %-16s %6.1f%% %7.2f %7.1f%% %7.3f %8.2f %8.2f %7.1f%% %7.1f%% %7.1f%%",
      econ, pace.id, r.completion * 100, r.avg_wins, r.combat_winrate * 100,
      r.duration_fit.score,
      r.duration.early.avg_seconds, r.duration.all.p50_seconds,
      r.duration.all.fatigue_touch_rate * 100,
      r.desired_buy_all_rate * 100, r.merge_per_pair_buy * 100))
  end
end

local payload = {
  mode = "sweep",
  runs_per_policy_economy_pace = N,
  config = {
    policies = Common.env("PIT_POLICIES"),
    commander_mode = COMMANDER_MODE,
    economy_profiles = Common.envAny({ "PIT_SWEEP_ECONOMIES", "PIT_ECON_PROFILES" }),
    pace_ids = Common.envAny({ "PIT_SWEEP_PACES", "PIT_PACE_IDS" }),
    pace_profiles = Common.envAny({ "PIT_SWEEP_PACE_PROFILES", "PIT_PACE_PROFILES" }),
  },
  cells = cells,
  by_policy = byPolicy,
  recommendations = recommendations,
}

local summary = {
  runs_per_policy_economy_pace = N,
  cells = summaryCells,
  recommendations = {
    scoring = recommendations.scoring,
    global = recommendations.global,
  },
}

local path = Common.writeReport("sweep", payload, { refSummary = summary })
print("=> ecrit " .. path .. " (+ runs/report-ref.json)")
