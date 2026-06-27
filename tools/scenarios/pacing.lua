-- tools/scenarios/pacing.lua
-- MODE P8 -- GLOBAL COMBAT PACING SWEEP.
--
-- Runs the normal policy set under sim-only pacing overlays. This answers the
-- question "are fights globally too short, and what happens if cooldowns slow
-- down before we touch live roster data?"

local Common = require("tools.scenarios.common")
local Rundriver = require("src.lab.rundriver")
local Policies = require("src.lab.policies")
local Pacing = require("src.run.pacing")

local N = require("tools.scenarios.argn")(30)
local BASE_SEED = 1360000
local COMMANDER_MODE = Common.env("PIT_COMMANDER_MODE") or "ignore"

local DEFAULT_PACE_PROFILES = {
  { id = Pacing.profiles.legacy.id, label = Pacing.profiles.legacy.label,
    hpMult = Pacing.profiles.legacy.hpMult, cdMult = Pacing.profiles.legacy.cooldownMult,
    fatigueStart = Pacing.profiles.legacy.fatigue.start },
  { id = Pacing.profiles.live.id, label = Pacing.profiles.live.label,
    hpMult = Pacing.profiles.live.hpMult, cdMult = Pacing.profiles.live.cooldownMult,
    fatigueStart = Pacing.profiles.live.fatigue.start },
  { id = "hp2_cd135_f24", label = "hp x2, cd x1.35, fatigue 24s", hpMult = 2, cdMult = 1.35, fatigueStart = 1440 },
  { id = "hp2_cd15_f24", label = "hp x2, cd x1.5, fatigue 24s", hpMult = 2, cdMult = 1.5, fatigueStart = 1440 },
  { id = "hp2_cd165_f26", label = "hp x2, cd x1.65, fatigue 26s", hpMult = 2, cdMult = 1.65, fatigueStart = 1560 },
}

local PACE_PROFILES = Common.paceProfiles(DEFAULT_PACE_PROFILES)

local function makePolicies(runIndex)
  local pols = Policies.analysisSet(love.math.newRandomGenerator(19000 + runIndex))
  return Common.filteredRows(pols, Common.envCsv("PIT_POLICIES"), "name")
end

local function newAgg(fatigueStart)
  return {
    runs = 0, completions = 0, wins = 0, rounds = 0,
    combatWins = 0, combatTotal = 0, undecided = 0,
    goldSum = 0, scoreSum = 0,
    duration = Common.durationSet(fatigueStart),
  }
end

local function addRun(a, traj)
  a.runs = a.runs + 1
  a.wins = a.wins + (traj.wins or 0)
  a.rounds = a.rounds + #(traj.rounds or {})
  if traj.result == "win" then a.completions = a.completions + 1 end
  local fc = traj.finalCost or {}
  a.goldSum = a.goldSum + (fc.gold or 0)
  a.scoreSum = a.scoreSum + (fc.score or 0)
  for _, rd in ipairs(traj.rounds or {}) do
    if rd.decided ~= nil then
      a.combatTotal = a.combatTotal + 1
      if rd.win then a.combatWins = a.combatWins + 1 end
      if rd.decided == false then a.undecided = a.undecided + 1 end
    end
    Common.addRoundDuration(a.duration, rd)
  end
end

local function finish(a)
  local duration = Common.finishDurationSet(a.duration)
  local durationFit = Common.durationFit(duration)
  return {
    runs = a.runs,
    completion = (a.runs > 0) and (a.completions / a.runs) or 0,
    avg_wins = (a.runs > 0) and (a.wins / a.runs) or 0,
    avg_rounds = (a.runs > 0) and (a.rounds / a.runs) or 0,
    combat_winrate = (a.combatTotal > 0) and (a.combatWins / a.combatTotal) or 0,
    undecided_rate = (a.combatTotal > 0) and (a.undecided / a.combatTotal) or 0,
    avg_gold = (a.runs > 0) and (a.goldSum / a.runs) or 0,
    avg_score = (a.runs > 0) and (a.scoreSum / a.runs) or 0,
    duration = duration,
    duration_fit = durationFit,
    duration_fit_score = durationFit.score,
  }
end

local byPace, byPolicy = {}, {}
for _, pace in ipairs(PACE_PROFILES) do
  byPace[pace.id] = newAgg(pace.fatigueStart)
  byPolicy[pace.id] = {}
end

print(string.format("== P8 GLOBAL PACING SWEEP : %d runs/policy/pace ==", N))

for run = 1, N do
  for pi, pace in ipairs(PACE_PROFILES) do
    local pols = makePolicies(run)
    for _, p in ipairs(pols) do
      local seed = BASE_SEED + run * 149 + pi * 100000
      local traj = Rundriver.run(seed, p, {
        hpMult = pace.hpMult,
        cooldownMult = pace.cdMult,
        commanderMode = COMMANDER_MODE,
        fatigue = Common.fatigueOptions(pace.fatigueStart, pace.fatigueBase, pace.fatigueRamp),
      })
      addRun(byPace[pace.id], traj)
      local pa = byPolicy[pace.id][p.name]
      if not pa then pa = newAgg(pace.fatigueStart); byPolicy[pace.id][p.name] = pa end
      addRun(pa, traj)
    end
  end
end

local paces, policies, summaryPaces = {}, {}, {}
for _, pace in ipairs(PACE_PROFILES) do
  local row = finish(byPace[pace.id])
  row.label = pace.label
  row.hp_mult = pace.hpMult
  row.cooldown_mult = pace.cdMult
  row.fatigue_start = pace.fatigueStart
  row.fatigue_base = pace.fatigueBase
  row.fatigue_ramp = pace.fatigueRamp
  paces[pace.id] = row
  summaryPaces[pace.id] = {
    completion = row.completion,
    avg_wins = row.avg_wins,
    combat_winrate = row.combat_winrate,
    early_avg_seconds = row.duration.early.avg_seconds,
    early_under_5s_rate = row.duration.early.under_5s_rate,
    p50_seconds = row.duration.all.p50_seconds,
    p90_seconds = row.duration.all.p90_seconds,
    fatigue_touch_rate = row.duration.all.fatigue_touch_rate,
    duration_fit_score = row.duration_fit.score,
  }
  policies[pace.id] = {}
  for name, a in pairs(byPolicy[pace.id]) do
    local pr = finish(a)
    policies[pace.id][name] = {
      completion = pr.completion,
      avg_wins = pr.avg_wins,
      combat_winrate = pr.combat_winrate,
      early_avg_seconds = pr.duration.early.avg_seconds,
      early_under_5s_rate = pr.duration.early.under_5s_rate,
      fatigue_touch_rate = pr.duration.all.fatigue_touch_rate,
      duration_fit_score = pr.duration_fit.score,
    }
  end
end

print(string.format("%-16s %7s %7s %8s %7s %9s %8s %8s %8s %8s",
  "pace", "comp%", "wins", "combat%", "fit", "early_s", "<5s%", "p50_s", "p90_s", "fatigue"))
for _, pace in ipairs(PACE_PROFILES) do
  local row = paces[pace.id]
  print(string.format("%-16s %6.1f%% %7.2f %7.1f%% %7.3f %9.2f %7.1f%% %8.2f %8.2f %7.1f%%",
    pace.id, row.completion * 100, row.avg_wins, row.combat_winrate * 100,
    row.duration_fit.score,
    row.duration.early.avg_seconds, row.duration.early.under_5s_rate * 100,
    row.duration.all.p50_seconds, row.duration.all.p90_seconds,
    row.duration.all.fatigue_touch_rate * 100))
end

local payload = {
  mode = "pacing",
  runs_per_policy_pace = N,
  config = {
    policies = Common.env("PIT_POLICIES"),
    commander_mode = COMMANDER_MODE,
    pace_ids = Common.env("PIT_PACE_IDS"),
    pace_profiles = Common.env("PIT_PACE_PROFILES"),
  },
  notes = {
    "All profiles are sim-only overlays: they do not mutate src/data/units.lua.",
    "Durations assume 60 ticks per second.",
    "Fatigue touch rate is measured against each profile's fatigueStart.",
  },
  paces = paces,
  by_policy = policies,
}

local summary = {
  runs_per_policy_pace = N,
  paces = summaryPaces,
}

local path = Common.writeReport("pacing", payload, { refSummary = summary })
print("=> ecrit " .. path .. " (+ runs/report-ref.json)")
