-- tools/scenarios/tank.lua
-- MODE P7 -- TANK ACCESS + COMBAT PACING PROBES.
--
-- This is deliberately sim-only. It tests whether the weak tank shell is caused
-- by access (no rank-1 seed), pilot behavior, mechanical payoff, or fight pace.
-- It does NOT mutate src/data/units.lua.

local Common = require("tools.scenarios.common")
local Rundriver = require("src.lab.rundriver")
local Policies = require("src.lab.policies")

local N = require("tools.scenarios.argn")(40)
local BASE_SEED = 1260000
local FPS = 60

local function isTank(id) return Policies.archetypeOf(id) == "tank" end

local SURVIVAL_FILLER = {
  husk = true,
  skeleton = true,
  demon = true,
  marauder = true,
  footman = true,
  mire_thing = true,
}

local function tankOr(set)
  return function(id) return isTank(id) or set[id] == true end
end

local function seedOnly(id)
  return function(unitId) return isTank(unitId) or unitId == id end
end

local function tankPowerMutator(comp)
  local hasTank = false
  for _, s in ipairs(comp or {}) do
    if isTank(s.id) then hasTank = true end
  end
  if not hasTank then return end
  for _, s in ipairs(comp or {}) do
    if isTank(s.id) then
      s.hp = math.floor((s.hp or 0) * 1.15 + 0.5)
      s.dmgReduce = math.min(0.60, (s.dmgReduce or 0) + 0.06)
    end
    if (s.shield or 0) > 0 then s.shield = s.shield + 8 end
    if s.shieldCaster then
      s.shieldCaster.value = math.floor((s.shieldCaster.value or 0) * 1.20 + 0.5)
    end
  end
end

local function makePacingMutator(cdMult)
  cdMult = cdMult or 1
  if cdMult == 1 then return nil end
  return function(comp)
    for _, s in ipairs(comp or {}) do
      s.cd = math.max(1, math.floor((s.cd or 1) * cdMult + 0.5))
      if s.shieldCaster and s.shieldCaster.cd then
        s.shieldCaster.cd = math.max(1, math.floor(s.shieldCaster.cd * cdMult + 0.5))
      end
    end
  end
end

local function pCurrent()
  return Policies.committed_archetype_plan("tank", "carre")
end

local function pSurvivalShell()
  local want = tankOr(SURVIVAL_FILLER)
  return Policies.committed_archetype_plan_with("tank", "carre", {
    name = "tank_survival_shell",
    want = want,
    commitWant = want,
    minRank = 1,
  })
end

local function pSeed(seedId)
  local want = seedOnly(seedId)
  return Policies.committed_archetype_plan_with("tank", "carre", {
    name = "tank_seed_" .. seedId,
    want = want,
    commitWant = want,
    minRank = 1,
  })
end

local POLICY_VARIANTS = {
  { id = "current_plan", label = "current tank policy", policy = pCurrent },
  { id = "survival_shell", label = "tank + survivable low-rank filler", policy = pSurvivalShell },
  { id = "husk_seed", label = "husk treated as a rank-1 tank seed", policy = function() return pSeed("husk") end },
  { id = "demon_seed", label = "demon treated as a rank-1 tank seed", policy = function() return pSeed("demon") end },
  { id = "current_power_plus", label = "current tank policy + sim-only tank payoff", policy = pCurrent, leftMutator = tankPowerMutator },
  { id = "husk_seed_power_plus", label = "husk seed + sim-only tank payoff", policy = function() return pSeed("husk") end, leftMutator = tankPowerMutator },
}

local PACE_PROFILES = {
  { id = "live_hp2_cd1", label = "current pacing, hp x2, cooldown x1", hpMult = 2, cdMult = 1 },
  { id = "hp2_cd2", label = "hp x2, cooldown x2", hpMult = 2, cdMult = 2 },
  { id = "hp2_cd3", label = "hp x2, cooldown x3", hpMult = 2, cdMult = 3 },
  { id = "hp2_cd4", label = "hp x2, cooldown x4", hpMult = 2, cdMult = 4 },
  { id = "hp3_cd2", label = "hp x3, cooldown x2", hpMult = 3, cdMult = 2 },
}

local function newTickBucket()
  return { n = 0, sum = 0, samples = {}, under5 = 0, fatigue = 0 }
end

local function addTick(bucket, ticks)
  if not ticks then return end
  bucket.n = bucket.n + 1
  bucket.sum = bucket.sum + ticks
  bucket.samples[#bucket.samples + 1] = ticks
  if ticks < 5 * FPS then bucket.under5 = bucket.under5 + 1 end
  if ticks >= 1020 then bucket.fatigue = bucket.fatigue + 1 end
end

local function finishTickBucket(bucket)
  table.sort(bucket.samples)
  local p10 = Common.percentileSorted(bucket.samples, 0.10)
  local p50 = Common.percentileSorted(bucket.samples, 0.50)
  local p90 = Common.percentileSorted(bucket.samples, 0.90)
  return {
    samples = bucket.n,
    avg_ticks = (bucket.n > 0) and (bucket.sum / bucket.n) or 0,
    avg_seconds = (bucket.n > 0) and (bucket.sum / bucket.n / FPS) or 0,
    p10_seconds = p10 / FPS,
    p50_seconds = p50 / FPS,
    p90_seconds = p90 / FPS,
    under_5s_rate = (bucket.n > 0) and (bucket.under5 / bucket.n) or 0,
    fatigue_touch_rate = (bucket.n > 0) and (bucket.fatigue / bucket.n) or 0,
  }
end

local function newAgg()
  return {
    runs = 0, completions = 0, wins = 0, rounds = 0,
    combatWins = 0, combatTotal = 0, undecided = 0,
    policyCommitted = 0, policyCommitRoundSum = 0,
    actualTankCommitted = 0, actualTankHits = 0, actualTankTotal = 0,
    buys = 0, sells = 0, pairBuys = 0, mergeBuys = 0, rerolls = 0, xpBuys = 0,
    all = newTickBucket(), early = newTickBucket(), mid = newTickBucket(), late = newTickBucket(),
  }
end

local function finalCommitment(traj, want)
  local units = (traj.finalBoard and traj.finalBoard.units) or {}
  local total, hits = 0, 0
  for _, u in ipairs(units) do
    total = total + 1
    if want(u.id) then hits = hits + 1 end
  end
  local share = (total > 0) and (hits / total) or 0
  local minCount = (total >= 5) and 3 or 2
  return { total = total, hits = hits, share = share, committed = hits >= minCount and share >= 0.55 }
end

local function addRun(a, traj)
  a.runs = a.runs + 1
  a.wins = a.wins + (traj.wins or 0)
  if traj.result == "win" then a.completions = a.completions + 1 end
  if traj.archetypeCommitRound then
    a.policyCommitted = a.policyCommitted + 1
    a.policyCommitRoundSum = a.policyCommitRoundSum + traj.archetypeCommitRound
  end
  local tc = finalCommitment(traj, isTank)
  a.actualTankHits = a.actualTankHits + tc.hits
  a.actualTankTotal = a.actualTankTotal + tc.total
  if tc.committed then a.actualTankCommitted = a.actualTankCommitted + 1 end
  local m = traj.metrics or {}
  a.buys = a.buys + (m.buys or 0)
  a.sells = a.sells + (m.sells or 0)
  a.pairBuys = a.pairBuys + (m.pairBuys or 0)
  a.mergeBuys = a.mergeBuys + (m.mergeBuys or 0)
  a.rerolls = a.rerolls + (m.rerolls or 0)
  a.xpBuys = a.xpBuys + (m.xpBuys or 0)
  for _, rd in ipairs(traj.rounds or {}) do
    a.rounds = a.rounds + 1
    if rd.decided ~= nil then
      a.combatTotal = a.combatTotal + 1
      if rd.win then a.combatWins = a.combatWins + 1 end
      if rd.decided == false then a.undecided = a.undecided + 1 end
    end
    addTick(a.all, rd.ticks)
    if (rd.round or 0) <= 3 then addTick(a.early, rd.ticks)
    elseif (rd.round or 0) <= 8 then addTick(a.mid, rd.ticks)
    else addTick(a.late, rd.ticks) end
  end
end

local function finish(a)
  return {
    runs = a.runs,
    completion = (a.runs > 0) and (a.completions / a.runs) or 0,
    avg_wins = (a.runs > 0) and (a.wins / a.runs) or 0,
    avg_rounds = (a.runs > 0) and (a.rounds / a.runs) or 0,
    combat_winrate = (a.combatTotal > 0) and (a.combatWins / a.combatTotal) or 0,
    undecided_rate = (a.combatTotal > 0) and (a.undecided / a.combatTotal) or 0,
    policy_commitment_rate = (a.runs > 0) and (a.policyCommitted / a.runs) or 0,
    avg_policy_commit_round = (a.policyCommitted > 0) and (a.policyCommitRoundSum / a.policyCommitted) or 0,
    actual_tank_final_commit_rate = (a.runs > 0) and (a.actualTankCommitted / a.runs) or 0,
    actual_tank_final_share = (a.actualTankTotal > 0) and (a.actualTankHits / a.actualTankTotal) or 0,
    buys_per_run = (a.runs > 0) and (a.buys / a.runs) or 0,
    sells_per_run = (a.runs > 0) and (a.sells / a.runs) or 0,
    pair_buys_per_run = (a.runs > 0) and (a.pairBuys / a.runs) or 0,
    merge_buys_per_run = (a.runs > 0) and (a.mergeBuys / a.runs) or 0,
    rerolls_per_run = (a.runs > 0) and (a.rerolls / a.runs) or 0,
    xp_buys_per_run = (a.runs > 0) and (a.xpBuys / a.runs) or 0,
    duration = {
      all = finishTickBucket(a.all),
      early = finishTickBucket(a.early),
      mid = finishTickBucket(a.mid),
      late = finishTickBucket(a.late),
    },
  }
end

local aggs = {}
for _, pv in ipairs(POLICY_VARIANTS) do
  aggs[pv.id] = {}
  for _, pace in ipairs(PACE_PROFILES) do aggs[pv.id][pace.id] = newAgg() end
end

print(string.format("== P7 TANK + PACING PROBES : %d runs/variant/pace ==", N))

for run = 1, N do
  for vi, pv in ipairs(POLICY_VARIANTS) do
    for pi, pace in ipairs(PACE_PROFILES) do
      local seed = BASE_SEED + run * 137 + vi * 10000 + pi * 100000
      local opts = {
        hpMult = pace.hpMult,
        compMutator = makePacingMutator(pace.cdMult),
        leftMutator = pv.leftMutator,
      }
      local traj = Rundriver.run(seed, pv.policy(), opts)
      addRun(aggs[pv.id][pace.id], traj)
    end
  end
end

local variants, summaryVariants = {}, {}
for _, pv in ipairs(POLICY_VARIANTS) do
  variants[pv.id] = { label = pv.label, paces = {} }
  summaryVariants[pv.id] = { label = pv.label, paces = {} }
  for _, pace in ipairs(PACE_PROFILES) do
    local row = finish(aggs[pv.id][pace.id])
    row.label = pace.label
    row.hp_mult = pace.hpMult
    row.cooldown_mult = pace.cdMult
    variants[pv.id].paces[pace.id] = row
    summaryVariants[pv.id].paces[pace.id] = {
      completion = row.completion,
      avg_wins = row.avg_wins,
      policy_commitment_rate = row.policy_commitment_rate,
      actual_tank_final_commit_rate = row.actual_tank_final_commit_rate,
      early_avg_seconds = row.duration.early.avg_seconds,
      early_under_5s_rate = row.duration.early.under_5s_rate,
      p50_seconds = row.duration.all.p50_seconds,
      p90_seconds = row.duration.all.p90_seconds,
      fatigue_touch_rate = row.duration.all.fatigue_touch_rate,
    }
  end
end

print(string.format("%-22s %-14s %7s %7s %7s %7s %8s %8s %8s",
  "variant", "pace", "comp%", "wins", "plan%", "tank%", "early_s", "p50_s", "p90_s"))
for _, pv in ipairs(POLICY_VARIANTS) do
  for _, pace in ipairs(PACE_PROFILES) do
    local row = variants[pv.id].paces[pace.id]
    print(string.format("%-22s %-14s %6.1f%% %7.2f %6.1f%% %6.1f%% %8.2f %8.2f %8.2f",
      pv.id, pace.id, row.completion * 100, row.avg_wins,
      row.policy_commitment_rate * 100, row.actual_tank_final_commit_rate * 100,
      row.duration.early.avg_seconds, row.duration.all.p50_seconds, row.duration.all.p90_seconds))
  end
end

local payload = {
  mode = "tank",
  runs_per_variant_pace = N,
  notes = {
    "Sim-only tank seeds and tank payoff overlays do not change src/data/units.lua.",
    "Durations assume 60 ticks per second; fatigue starts at 1020 ticks (~17s).",
    "The live baseline is explicit hp x2 / cooldown x1 to keep the report stable if Arena defaults change.",
  },
  policy_variants = variants,
}

local summary = {
  runs_per_variant_pace = N,
  policy_variants = summaryVariants,
}

local path = Common.writeReport("tank", payload, { refSummary = summary })
print("=> ecrit " .. path .. " (+ runs/report-ref.json)")
