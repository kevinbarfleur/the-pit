-- tools/scenarios/bossrush_run.lua
-- MODE PVE/BOSSRUSH-RUN -- connecte l'economie et les policies au scoring PvE.
-- Chaque politique construit une vraie run via Rundriver; son board final
-- supporte ensuite un bossrush avec les reliques et le commandant réellement
-- acquis. Le score par run inclut les runs qui n'entrent pas en postgame.

local Common = require("tools.scenarios.common")
local Economy = require("src.run.economy")
local Rundriver = require("src.lab.rundriver")
local Policies = require("src.lab.policies")
local Compbuild = require("src.lab.compbuild")
local Abominations = require("src.data.abominations")
local Bossrush = require("src.lab.bossrush")

local N = require("tools.scenarios.argn")(10)
local BASE_SEED = 2270000

local ECONOMY_ORDER = Common.envCsvAny({ "PIT_BOSSRUSH_RUN_ECONOMIES", "PIT_ECON_PROFILES" })
  or { "baseline", "sap_cost", "early_curve" }
for _, profileId in ipairs(ECONOMY_ORDER) do
  assert(Economy.profiles[profileId], "profil economie inconnu: " .. tostring(profileId))
end

local COMMANDER_MODE = Common.env("PIT_COMMANDER_MODE") or "auto"
local ELIGIBILITY = Common.env("PIT_BOSSRUSH_RUN_ELIGIBILITY") or "completed"
assert(ELIGIBILITY == "completed" or ELIGIBILITY == "all",
  "PIT_BOSSRUSH_RUN_ELIGIBILITY doit valoir completed ou all")

local SCORE_SECONDS = Common.envNumber("PIT_BOSSRUSH_SCORE_SECONDS", Bossrush.DEFAULT_SCORE_TICKS / Common.FPS)
local BOSS_OPTS = {
  scoreTicks = math.max(1, math.floor(SCORE_SECONDS * Common.FPS + 0.5)),
  hpMult = Common.envNumber("PIT_BOSSRUSH_HP_MULT", nil),
  cooldownMult = Common.envNumber("PIT_BOSSRUSH_CD_MULT", nil),
}
local SAMPLE_LIMIT = Common.envNumber("PIT_BOSSRUSH_RUN_SAMPLE_LIMIT", 300)

local function makePolicies(runIndex)
  local pols = Policies.analysisSet(love.math.newRandomGenerator(27000 + runIndex))
  return Common.filteredRows(pols, Common.envCsv("PIT_POLICIES"), "name")
end

local function loadBosses()
  local ids = Common.envCsv("PIT_ABOMINATIONS")
  if not ids then
    local rows = {}
    for _, key in ipairs(Abominations.order) do rows[#rows + 1] = Abominations.byKey[key] end
    return rows
  end
  local rows = {}
  for _, key in ipairs(ids) do
    assert(Abominations.byKey[key], "abomination inconnue: " .. tostring(key))
    rows[#rows + 1] = Abominations.byKey[key]
  end
  return rows
end

local function newAgg()
  return {
    runs = 0, completions = 0, entries = 0, bossFights = 0,
    wins = 0, rounds = 0, finalGold = 0, finalScore = 0,
    clears = 0, survives = 0, fullWindows = 0, kills = 0,
    clearTicks = 0, scoreDamage = 0, scoreDps = 0, bossDamage = 0,
    causes = {},
  }
end

local function addCauses(dst, src)
  for cause, value in pairs(src or {}) do dst[cause] = (dst[cause] or 0) + value end
end

local function addRun(a, traj, entersBossrush)
  a.runs = a.runs + 1
  if traj.result == "win" then a.completions = a.completions + 1 end
  if entersBossrush then a.entries = a.entries + 1 end
  a.wins = a.wins + (traj.wins or 0)
  a.rounds = a.rounds + #(traj.rounds or {})
  local fc = traj.finalCost or {}
  a.finalGold = a.finalGold + (fc.gold or 0)
  a.finalScore = a.finalScore + (fc.score or 0)
end

local function addBoss(a, row)
  a.bossFights = a.bossFights + 1
  if row.cleared_blockers then
    a.clears = a.clears + 1
    a.clearTicks = a.clearTicks + (row.clear_ticks or 0)
  end
  if row.survived then a.survives = a.survives + 1 end
  if row.survived_score_window then a.fullWindows = a.fullWindows + 1 end
  if row.boss_killed then a.kills = a.kills + 1 end
  a.scoreDamage = a.scoreDamage + (row.boss_score_damage or 0)
  a.scoreDps = a.scoreDps + (row.boss_score_dps or 0)
  a.bossDamage = a.bossDamage + (row.boss_damage or 0)
  addCauses(a.causes, row.score_damage_by_cause)
end

local function finish(a)
  return {
    runs = a.runs,
    completion = (a.runs > 0) and (a.completions / a.runs) or 0,
    entry_rate = (a.runs > 0) and (a.entries / a.runs) or 0,
    boss_fights = a.bossFights,
    avg_wins = (a.runs > 0) and (a.wins / a.runs) or 0,
    avg_rounds = (a.runs > 0) and (a.rounds / a.runs) or 0,
    avg_final_gold = (a.runs > 0) and (a.finalGold / a.runs) or 0,
    avg_final_score = (a.runs > 0) and (a.finalScore / a.runs) or 0,
    clear_rate = (a.bossFights > 0) and (a.clears / a.bossFights) or 0,
    survival_rate = (a.bossFights > 0) and (a.survives / a.bossFights) or 0,
    full_score_window_rate = (a.bossFights > 0) and (a.fullWindows / a.bossFights) or 0,
    boss_kill_rate = (a.bossFights > 0) and (a.kills / a.bossFights) or 0,
    avg_clear_seconds = (a.clears > 0) and (a.clearTicks / a.clears / Common.FPS) or 0,
    avg_boss_damage = (a.bossFights > 0) and (a.bossDamage / a.bossFights) or 0,
    avg_score_damage = (a.bossFights > 0) and (a.scoreDamage / a.bossFights) or 0,
    avg_score_dps = (a.bossFights > 0) and (a.scoreDps / a.bossFights) or 0,
    score_damage_per_entry = (a.entries > 0) and (a.scoreDamage / a.entries) or 0,
    score_damage_per_run = (a.runs > 0) and (a.scoreDamage / a.runs) or 0,
    score_damage_by_cause = a.causes,
  }
end

local function finishBoss(a)
  return {
    boss_fights = a.bossFights,
    clear_rate = (a.bossFights > 0) and (a.clears / a.bossFights) or 0,
    survival_rate = (a.bossFights > 0) and (a.survives / a.bossFights) or 0,
    full_score_window_rate = (a.bossFights > 0) and (a.fullWindows / a.bossFights) or 0,
    boss_kill_rate = (a.bossFights > 0) and (a.kills / a.bossFights) or 0,
    avg_clear_seconds = (a.clears > 0) and (a.clearTicks / a.clears / Common.FPS) or 0,
    avg_boss_damage = (a.bossFights > 0) and (a.bossDamage / a.bossFights) or 0,
    avg_score_damage = (a.bossFights > 0) and (a.scoreDamage / a.bossFights) or 0,
    avg_score_dps = (a.bossFights > 0) and (a.scoreDps / a.bossFights) or 0,
    score_damage_by_cause = a.causes,
  }
end

local function hasBoard(comp)
  return comp and #(comp.units or {}) > 0
end

local function eligible(traj)
  if ELIGIBILITY == "all" then return true end
  return traj.result == "win"
end

local bosses = loadBosses()
local byEconomy, byPolicy, byBoss, matrix = {}, {}, {}, {}
local policyOrder, policySeen = {}, {}
for _, econ in ipairs(ECONOMY_ORDER) do
  byEconomy[econ] = newAgg()
  matrix[econ] = {}
end
for _, abom in ipairs(bosses) do byBoss[abom.key] = newAgg() end

local samples = {}

print(string.format("== PVE BOSSRUSH-RUN : %d runs/policy/economy, eligibility=%s ==", N, ELIGIBILITY))

for run = 1, N do
  for ei, econ in ipairs(ECONOMY_ORDER) do
    local pols = makePolicies(run)
    for pi, p in ipairs(pols) do
      if not policySeen[p.name] then
        policySeen[p.name] = true
        policyOrder[#policyOrder + 1] = p.name
        byPolicy[p.name] = newAgg()
        for _, econId in ipairs(ECONOMY_ORDER) do matrix[econId][p.name] = newAgg() end
      end
      local seed = BASE_SEED + ei * 100000 + run * 173
      local traj = Rundriver.run(seed, p, {
        economy = econ,
        commanderMode = COMMANDER_MODE,
      })
      local finalBoard = traj.finalSupportedBoard or traj.finalBoard
      local enters = eligible(traj) and hasBoard(finalBoard)
      addRun(byEconomy[econ], traj, enters)
      addRun(byPolicy[p.name], traj, enters)
      addRun(matrix[econ][p.name], traj, enters)
      if enters then
        local left = Compbuild.toComp(finalBoard, -1)
        for bi, abom in ipairs(bosses) do
          local bossSeed = BASE_SEED + 5000000 + ei * 1000000 + pi * 50000 + run * 1000 + bi
          local row = Bossrush.run(left, abom.key, bossSeed, BOSS_OPTS)
          addBoss(byEconomy[econ], row)
          addBoss(byPolicy[p.name], row)
          addBoss(byBoss[abom.key], row)
          addBoss(matrix[econ][p.name], row)
          if #samples < SAMPLE_LIMIT then
            samples[#samples + 1] = {
              economy = econ,
              policy = p.name,
              run_seed = seed,
              boss_seed = bossSeed,
              boss = abom.key,
              result = traj.result,
              run_wins = traj.wins,
              relics = finalBoard.relics,
              commander = finalBoard.commander,
              cleared_blockers = row.cleared_blockers,
              survived_score_window = row.survived_score_window,
              boss_score_damage = row.boss_score_damage,
              boss_score_dps = row.boss_score_dps,
            }
          end
        end
      end
    end
  end
end

local economyRows, policyRows, bossRows = {}, {}, {}
for _, econ in ipairs(ECONOMY_ORDER) do
  local row = finish(byEconomy[econ])
  row.id = econ
  row.label = Economy.profiles[econ].label
  economyRows[#economyRows + 1] = row
end
table.sort(economyRows, function(a, b)
  if a.score_damage_per_run ~= b.score_damage_per_run then return a.score_damage_per_run > b.score_damage_per_run end
  return a.id < b.id
end)

for _, name in ipairs(policyOrder) do
  local row = finish(byPolicy[name])
  row.name = name
  policyRows[#policyRows + 1] = row
end
table.sort(policyRows, function(a, b)
  if a.score_damage_per_run ~= b.score_damage_per_run then return a.score_damage_per_run > b.score_damage_per_run end
  return a.name < b.name
end)

for _, abom in ipairs(bosses) do
  local row = finishBoss(byBoss[abom.key])
  row.key = abom.key
  row.name = abom.name
  row.theme = abom.theme
  row.intent = abom.intent
  bossRows[#bossRows + 1] = row
end
table.sort(bossRows, function(a, b) return a.key < b.key end)

local matrixOut = {}
for _, econ in ipairs(ECONOMY_ORDER) do
  matrixOut[econ] = {}
  for _, name in ipairs(policyOrder) do matrixOut[econ][name] = finish(matrix[econ][name]) end
end

local function gridRows()
  local rows = {}
  for _, econ in ipairs(ECONOMY_ORDER) do
    for _, name in ipairs(policyOrder) do
      local row = finish(matrix[econ][name])
      row.economy = econ
      row.policy = name
      rows[#rows + 1] = row
    end
  end
  table.sort(rows, function(a, b)
    if a.score_damage_per_run ~= b.score_damage_per_run then return a.score_damage_per_run > b.score_damage_per_run end
    if a.entry_rate ~= b.entry_rate then return a.entry_rate > b.entry_rate end
    if a.economy ~= b.economy then return a.economy < b.economy end
    return a.policy < b.policy
  end)
  return rows
end

local function buildRecommendations(rows, overall)
  local out = { warnings = {}, watches = {} }
  local top, second = rows[1], rows[2]
  if top then
    out.top_run_bossrush_line = {
      economy = top.economy,
      policy = top.policy,
      completion = top.completion,
      entry_rate = top.entry_rate,
      score_damage_per_run = top.score_damage_per_run,
      score_damage_per_entry = top.score_damage_per_entry,
    }
  end
  if top and second and second.score_damage_per_run > 0 then
    local gap = top.score_damage_per_run / second.score_damage_per_run
    out.top_run_bossrush_line.gap_to_second = gap
    if gap >= 1.50 then
      out.warnings[#out.warnings + 1] = {
        kind = "dominant_run_bossrush_line",
        economy = top.economy,
        policy = top.policy,
        gap_to_second = gap,
        note = "One actual run/economy line dominates postgame score; inspect access and boss counters before locking the loop.",
      }
    end
  end
  if overall.entry_rate < 0.15 then
    out.watches[#out.watches + 1] = {
      kind = "low_postgame_entry_rate",
      entry_rate = overall.entry_rate,
      completion = overall.completion,
      note = "Few simulated runs reach bossrush eligibility; conclusions are mostly about run access, not boss scoring.",
    }
  end
  if overall.boss_fights > 0 and overall.clear_rate < 0.25 then
    out.watches[#out.watches + 1] = {
      kind = "low_general_clear_rate",
      clear_rate = overall.clear_rate,
      note = "Run-built boards usually fail before the scoring phase; abomination frontlines may be too hard for current postgame entry.",
    }
  end
  return out
end

local rows = gridRows()
local overall = newAgg()
for _, econ in ipairs(ECONOMY_ORDER) do
  local a = byEconomy[econ]
  for k, v in pairs(a) do
    if type(v) == "number" then overall[k] = (overall[k] or 0) + v end
  end
  addCauses(overall.causes, a.causes)
end
overall = finish(overall)
local recommendations = buildRecommendations(rows, overall)

print(string.format("%-18s %-24s %7s %7s %8s %9s %9s %8s",
  "economy", "policy", "comp%", "entry%", "clear%", "score/run", "score/entry", "full%"))
for i = 1, math.min(12, #rows) do
  local r = rows[i]
  print(string.format("%-18s %-24s %6.1f%% %6.1f%% %7.1f%% %9.1f %11.1f %7.1f%%",
    r.economy, r.policy, r.completion * 100, r.entry_rate * 100, r.clear_rate * 100,
    r.score_damage_per_run, r.score_damage_per_entry, r.full_score_window_rate * 100))
end

local payload = {
  mode = "bossrush_run",
  runs_per_policy_economy = N,
  config = {
    economies = ECONOMY_ORDER,
    policies = Common.env("PIT_POLICIES"),
    abominations = Common.env("PIT_ABOMINATIONS"),
    commander_mode = COMMANDER_MODE,
    eligibility = ELIGIBILITY,
    score_seconds = SCORE_SECONDS,
    boss_hp_mult = BOSS_OPTS.hpMult,
    boss_cooldown_mult = BOSS_OPTS.cooldownMult,
  },
  notes = {
    "This mode runs actual policy/economy trajectories before the PvE bossrush.",
    "finalSupportedBoard includes the final board, acquired relics, and placed commander.",
    "score_damage_per_run keeps failed or ineligible runs as zero-score outcomes.",
  },
  recommendations = recommendations,
  overall = overall,
  by_economy = economyRows,
  by_policy = policyRows,
  by_boss = bossRows,
  economy_policy = matrixOut,
  ranked_lines = rows,
  samples = samples,
}

local summary = {
  runs_per_policy_economy = N,
  config = payload.config,
  overall = overall,
  recommendations = recommendations,
  top_lines = { rows[1], rows[2], rows[3] },
}

local path = Common.writeReport("bossrush_run", payload, { refSummary = summary })
print("=> ecrit " .. path .. " (+ runs/report-ref.json)")
