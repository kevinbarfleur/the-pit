-- tools/scenarios/tank.lua
-- MODE P7 -- TANK ACCESS + COMBAT PACING PROBES.
--
-- This is deliberately sim-only. It tests whether the weak tank shell is caused
-- by access (no rank-1 seed), pilot behavior, mechanical payoff, or fight pace.
-- It does NOT mutate src/data/units.lua.

local Common = require("tools.scenarios.common")
local Rundriver = require("src.lab.rundriver")
local Policies = require("src.lab.policies")
local Shapes = require("src.board.shapes")

local N = require("tools.scenarios.argn")(40)
local BASE_SEED = 1260000
local COMMANDER_MODE = Common.env("PIT_COMMANDER_MODE") or "ignore"

local function isTank(id) return Policies.archetypeOf(id) == "tank" end

local function shapeMaxX(shape)
  local maxX
  for _, c in ipairs((shape and shape.cells) or {}) do
    if not maxX or c.x > maxX then maxX = c.x end
  end
  return maxX
end

local SURVIVAL_FILLER = {
  husk = true,
  skeleton = true,
  demon = true,
  marauder = true,
  footman = true,
  mire_thing = true,
}

local TANK_PAYLOAD = {
  marauder = true,
  demon = true,
  bandit = true,
  witch = true,
  stormcaller = true,
  gnaw_rat = true,
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

local function pPayloadShell()
  local want = tankOr(TANK_PAYLOAD)
  return Policies.committed_archetype_plan_with("tank", "carre", {
    name = "tank_payload_shell",
    want = want,
    commitWant = want,
    minRank = 1,
  })
end

local function frontSlots(build)
  local shape = build.board.shape or Shapes.carre
  local maxX = shapeMaxX(shape)
  local out = {}
  for slot, c in ipairs(shape.cells or {}) do
    if c.x == maxX and build.board.slots[slot] and build.board.slots[slot].unlocked then
      out[#out + 1] = slot
    end
  end
  table.sort(out)
  return out
end

local function arrangeTankPayload(drv)
  local fronts = frontSlots(drv.build)
  local frontSet = {}
  for _, slot in ipairs(fronts) do frontSet[slot] = true end

  local tankFront, tankOffFront, nonTankFront
  for i = 1, 9 do
    local sr = drv.build.slotRigs[i]
    if sr then
      if isTank(sr.id) then
        if frontSet[i] then tankFront = tankFront or i else tankOffFront = tankOffFront or i end
      elseif frontSet[i] then
        nonTankFront = nonTankFront or i
      end
    end
  end
  if tankFront or not tankOffFront then return false end
  local target = nonTankFront
  if not target then
    for _, slot in ipairs(fronts) do
      if not drv.build.slotRigs[slot] then target = slot; break end
    end
  end
  if target and target ~= tankOffFront then return drv:move(tankOffFront, target) end
  return false
end

local function withTankPayloadArrangement(factory, suffix)
  return function()
    local p = factory()
    local baseAct = p.act
    p.name = p.name .. (suffix or "_arranged")
    p.act = function(self, drv)
      local result = baseAct(self, drv) or {}
      if arrangeTankPayload(drv) then result.arrangedTankFront = true end
      return result
    end
    return p
  end
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

local DEFAULT_POLICY_VARIANTS = {
  { id = "current_plan", label = "current tank policy", policy = pCurrent, finalWant = isTank },
  { id = "survival_shell", label = "tank + survivable low-rank filler", policy = pSurvivalShell, finalWant = tankOr(SURVIVAL_FILLER) },
  { id = "payload_shell", label = "tank frontline + damage payload", policy = pPayloadShell, finalWant = tankOr(TANK_PAYLOAD) },
  { id = "payload_arranged", label = "tank payload shell + front-anchor placement", policy = withTankPayloadArrangement(pPayloadShell), finalWant = tankOr(TANK_PAYLOAD) },
  { id = "husk_seed", label = "husk treated as a rank-1 tank seed", policy = function() return pSeed("husk") end, finalWant = seedOnly("husk") },
  { id = "demon_seed", label = "demon treated as a rank-1 tank seed", policy = function() return pSeed("demon") end, finalWant = seedOnly("demon") },
  { id = "current_power_plus", label = "current tank policy + sim-only tank payoff", policy = pCurrent, finalWant = isTank, leftMutator = tankPowerMutator },
  { id = "payload_power_plus", label = "tank payload shell + sim-only tank payoff", policy = pPayloadShell, finalWant = tankOr(TANK_PAYLOAD), leftMutator = tankPowerMutator },
  { id = "payload_arranged_power_plus", label = "tank payload arranged + sim-only tank payoff", policy = withTankPayloadArrangement(pPayloadShell), finalWant = tankOr(TANK_PAYLOAD), leftMutator = tankPowerMutator },
  { id = "husk_seed_power_plus", label = "husk seed + sim-only tank payoff", policy = function() return pSeed("husk") end, finalWant = seedOnly("husk"), leftMutator = tankPowerMutator },
}

local DEFAULT_PACE_PROFILES = {
  { id = "live_hp2_cd1", label = "current pacing, hp x2, cooldown x1", hpMult = 2, cdMult = 1, fatigueStart = 1020 },
  { id = "hp2_cd15_f24", label = "hp x2, cooldown x1.5, fatigue 24s", hpMult = 2, cdMult = 1.5, fatigueStart = 1440 },
  { id = "hp2_cd2", label = "hp x2, cooldown x2", hpMult = 2, cdMult = 2, fatigueStart = 1020 },
  { id = "hp2_cd3", label = "hp x2, cooldown x3", hpMult = 2, cdMult = 3, fatigueStart = 1020 },
  { id = "hp2_cd4", label = "hp x2, cooldown x4", hpMult = 2, cdMult = 4, fatigueStart = 1020 },
  { id = "hp3_cd2", label = "hp x3, cooldown x2", hpMult = 3, cdMult = 2, fatigueStart = 1020 },
}

local POLICY_VARIANTS = Common.filteredRows(DEFAULT_POLICY_VARIANTS, Common.envCsv("PIT_TANK_VARIANTS"))
local PACE_PROFILES = Common.paceProfiles(DEFAULT_PACE_PROFILES)

local function newAgg(fatigueStart)
  return {
    runs = 0, completions = 0, wins = 0, rounds = 0,
    combatWins = 0, combatTotal = 0, undecided = 0,
    policyCommitted = 0, policyCommitRoundSum = 0,
    shellCommitted = 0, shellHits = 0, shellTotal = 0,
    actualTankCommitted = 0, actualTankHits = 0, actualTankTotal = 0,
    tankAnchor = 0, frontTankAnchor = 0,
    protectedPayload = 0, payloadHits = 0, payloadBackHits = 0,
    buys = 0, sells = 0, pairBuys = 0, mergeBuys = 0, rerolls = 0, xpBuys = 0,
    duration = Common.durationSet(fatigueStart),
  }
end

local function finalProfile(traj, want)
  local units = (traj.finalBoard and traj.finalBoard.units) or {}
  local shape = Shapes[(traj.finalBoard and traj.finalBoard.sigil) or "carre"] or Shapes.carre
  local maxX = shapeMaxX(shape)
  local total, shellHits, tankHits, frontTankHits, payloadHits, payloadBackHits = 0, 0, 0, 0, 0, 0
  for _, u in ipairs(units) do
    total = total + 1
    if want(u.id) then shellHits = shellHits + 1 end
    local cell = shape.cells and shape.cells[u.slot]
    if isTank(u.id) then
      tankHits = tankHits + 1
      if cell and maxX and cell.x == maxX then frontTankHits = frontTankHits + 1 end
    elseif TANK_PAYLOAD[u.id] then
      payloadHits = payloadHits + 1
      if cell and maxX and cell.x < maxX then payloadBackHits = payloadBackHits + 1 end
    end
  end
  local minCount = (total >= 5) and 3 or 2
  local minPayload = (total >= 5) and 2 or 1
  local shellShare = (total > 0) and (shellHits / total) or 0
  local tankShare = (total > 0) and (tankHits / total) or 0
  return {
    total = total,
    shellHits = shellHits,
    shellShare = shellShare,
    shellCommitted = shellHits >= minCount and shellShare >= 0.55,
    tankHits = tankHits,
    tankShare = tankShare,
    tankCommitted = tankHits >= minCount and tankShare >= 0.55,
    tankAnchor = tankHits >= 1,
    frontTankAnchor = frontTankHits >= 1,
    payloadHits = payloadHits,
    payloadBackHits = payloadBackHits,
    protectedPayload = frontTankHits >= 1 and payloadBackHits >= minPayload,
  }
end

local function addRun(a, traj, finalWant)
  a.runs = a.runs + 1
  a.wins = a.wins + (traj.wins or 0)
  if traj.result == "win" then a.completions = a.completions + 1 end
  if traj.archetypeCommitRound then
    a.policyCommitted = a.policyCommitted + 1
    a.policyCommitRoundSum = a.policyCommitRoundSum + traj.archetypeCommitRound
  end
  local fp = finalProfile(traj, finalWant or isTank)
  a.shellHits = a.shellHits + fp.shellHits
  a.shellTotal = a.shellTotal + fp.total
  if fp.shellCommitted then a.shellCommitted = a.shellCommitted + 1 end
  a.actualTankHits = a.actualTankHits + fp.tankHits
  a.actualTankTotal = a.actualTankTotal + fp.total
  if fp.tankCommitted then a.actualTankCommitted = a.actualTankCommitted + 1 end
  if fp.tankAnchor then a.tankAnchor = a.tankAnchor + 1 end
  if fp.frontTankAnchor then a.frontTankAnchor = a.frontTankAnchor + 1 end
  a.payloadHits = a.payloadHits + fp.payloadHits
  a.payloadBackHits = a.payloadBackHits + fp.payloadBackHits
  if fp.protectedPayload then a.protectedPayload = a.protectedPayload + 1 end
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
    Common.addRoundDuration(a.duration, rd)
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
    final_shell_commit_rate = (a.runs > 0) and (a.shellCommitted / a.runs) or 0,
    final_shell_share = (a.shellTotal > 0) and (a.shellHits / a.shellTotal) or 0,
    actual_tank_final_commit_rate = (a.runs > 0) and (a.actualTankCommitted / a.runs) or 0,
    actual_tank_final_share = (a.actualTankTotal > 0) and (a.actualTankHits / a.actualTankTotal) or 0,
    tank_anchor_rate = (a.runs > 0) and (a.tankAnchor / a.runs) or 0,
    front_tank_anchor_rate = (a.runs > 0) and (a.frontTankAnchor / a.runs) or 0,
    protected_payload_rate = (a.runs > 0) and (a.protectedPayload / a.runs) or 0,
    payload_back_share = (a.payloadHits > 0) and (a.payloadBackHits / a.payloadHits) or 0,
    buys_per_run = (a.runs > 0) and (a.buys / a.runs) or 0,
    sells_per_run = (a.runs > 0) and (a.sells / a.runs) or 0,
    pair_buys_per_run = (a.runs > 0) and (a.pairBuys / a.runs) or 0,
    merge_buys_per_run = (a.runs > 0) and (a.mergeBuys / a.runs) or 0,
    rerolls_per_run = (a.runs > 0) and (a.rerolls / a.runs) or 0,
    xp_buys_per_run = (a.runs > 0) and (a.xpBuys / a.runs) or 0,
    duration = Common.finishDurationSet(a.duration),
  }
end

local aggs = {}
for _, pv in ipairs(POLICY_VARIANTS) do
  aggs[pv.id] = {}
  for _, pace in ipairs(PACE_PROFILES) do aggs[pv.id][pace.id] = newAgg(pace.fatigueStart) end
end

print(string.format("== P7 TANK + PACING PROBES : %d runs/variant/pace ==", N))

for run = 1, N do
  for vi, pv in ipairs(POLICY_VARIANTS) do
    for pi, pace in ipairs(PACE_PROFILES) do
      local seed = BASE_SEED + run * 137 + vi * 10000 + pi * 100000
      local opts = {
        hpMult = pace.hpMult,
        commanderMode = COMMANDER_MODE,
        fatigue = Common.fatigueOptions(pace.fatigueStart, pace.fatigueBase, pace.fatigueRamp),
        compMutator = Common.cooldownMutator(pace.cdMult),
        leftMutator = pv.leftMutator,
      }
      local traj = Rundriver.run(seed, pv.policy(), opts)
      addRun(aggs[pv.id][pace.id], traj, pv.finalWant)
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
    row.fatigue_start = pace.fatigueStart
    row.fatigue_base = pace.fatigueBase
    row.fatigue_ramp = pace.fatigueRamp
    variants[pv.id].paces[pace.id] = row
    summaryVariants[pv.id].paces[pace.id] = {
      completion = row.completion,
      avg_wins = row.avg_wins,
      policy_commitment_rate = row.policy_commitment_rate,
      final_shell_commit_rate = row.final_shell_commit_rate,
      actual_tank_final_commit_rate = row.actual_tank_final_commit_rate,
      tank_anchor_rate = row.tank_anchor_rate,
      front_tank_anchor_rate = row.front_tank_anchor_rate,
      protected_payload_rate = row.protected_payload_rate,
      early_avg_seconds = row.duration.early.avg_seconds,
      early_under_5s_rate = row.duration.early.under_5s_rate,
      p50_seconds = row.duration.all.p50_seconds,
      p90_seconds = row.duration.all.p90_seconds,
      fatigue_touch_rate = row.duration.all.fatigue_touch_rate,
    }
  end
end

print(string.format("%-27s %-14s %7s %7s %7s %7s %7s %7s %7s %8s %8s %8s",
  "variant", "pace", "comp%", "wins", "plan%", "shell%", "tank%", "anchor%", "prot%", "early_s", "p50_s", "p90_s"))
for _, pv in ipairs(POLICY_VARIANTS) do
  for _, pace in ipairs(PACE_PROFILES) do
    local row = variants[pv.id].paces[pace.id]
    print(string.format("%-27s %-14s %6.1f%% %7.2f %6.1f%% %6.1f%% %6.1f%% %6.1f%% %6.1f%% %8.2f %8.2f %8.2f",
      pv.id, pace.id, row.completion * 100, row.avg_wins,
      row.policy_commitment_rate * 100, row.final_shell_commit_rate * 100,
      row.actual_tank_final_commit_rate * 100, row.front_tank_anchor_rate * 100,
      row.protected_payload_rate * 100,
      row.duration.early.avg_seconds, row.duration.all.p50_seconds, row.duration.all.p90_seconds))
  end
end

local payload = {
  mode = "tank",
  runs_per_variant_pace = N,
  config = {
    tank_variants = Common.env("PIT_TANK_VARIANTS"),
    commander_mode = COMMANDER_MODE,
    pace_ids = Common.env("PIT_PACE_IDS"),
    pace_profiles = Common.env("PIT_PACE_PROFILES"),
  },
  notes = {
    "Sim-only tank seeds and tank payoff overlays do not change src/data/units.lua.",
    "Durations assume 60 ticks per second; fatigue starts at 1020 ticks (~17s).",
    "The live baseline is explicit hp x2 / cooldown x1 to keep the report stable if Arena defaults change.",
    "shell% measures the tested final plan; tank% stays strict majority-tank; anchor% requires at least one tank on the front column.",
    "prot% requires a front-column tank plus at least one/two payload units behind it, depending on board size.",
  },
  policy_variants = variants,
}

local summary = {
  runs_per_variant_pace = N,
  policy_variants = summaryVariants,
}

local path = Common.writeReport("tank", payload, { refSummary = summary })
print("=> ecrit " .. path .. " (+ runs/report-ref.json)")
