-- tools/scenarios/bossrush.lua
-- MODE PVE/BOSSRUSH -- teste les builds catalogues contre les abominations
-- PvE/endgame scoring : nettoyer les generaux, survivre, puis scorer sur le boss.

local Common = require("tools.scenarios.common")
local Compbuild = require("src.lab.compbuild")
local Compcost = require("src.lab.compcost")
local Coherence = require("src.lab.coherence")
local Compositions = require("src.data.compositions")
local Abominations = require("src.data.abominations")
local Bossrush = require("src.lab.bossrush")

local N = require("tools.scenarios.argn")(5)
local BASE_SEED = 2170000

local DEFAULT_COMPS = {
  "poison_diamant_perfect",
  "burn_ligne_perfect",
  "bleed_anneau_perfect",
  "rot_carre_perfect",
  "shock_arc_carre",
  "cross_venom_pyre",
  "ward_fortress_carre",
  "tank_carre",
  "bruiser_carre",
}

local function loadComps()
  local ids = Common.envCsv("PIT_BOSSRUSH_COMPS") or DEFAULT_COMPS
  local rows = {}
  for _, id in ipairs(ids) do
    local c = Common.compById(id)
    rows[#rows + 1] = c
  end
  return rows
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
    runs = 0, clears = 0, survives = 0, fullWindows = 0, kills = 0,
    clearTicks = 0, scoreDamage = 0, scoreDps = 0, bossDamage = 0,
    causes = {},
  }
end

local function addCauses(dst, src)
  for cause, value in pairs(src or {}) do dst[cause] = (dst[cause] or 0) + value end
end

local function add(a, row)
  a.runs = a.runs + 1
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
    clear_rate = (a.runs > 0) and (a.clears / a.runs) or 0,
    survival_rate = (a.runs > 0) and (a.survives / a.runs) or 0,
    full_score_window_rate = (a.runs > 0) and (a.fullWindows / a.runs) or 0,
    boss_kill_rate = (a.runs > 0) and (a.kills / a.runs) or 0,
    avg_clear_seconds = (a.clears > 0) and (a.clearTicks / a.clears / Common.FPS) or 0,
    avg_boss_damage = (a.runs > 0) and (a.bossDamage / a.runs) or 0,
    avg_score_damage = (a.runs > 0) and (a.scoreDamage / a.runs) or 0,
    avg_score_dps = (a.runs > 0) and (a.scoreDps / a.runs) or 0,
    score_damage_by_cause = a.causes,
  }
end

local comps = loadComps()
local bosses = loadBosses()
local byComp, byBoss, matrix = {}, {}, {}
local detailRows = {}

print(string.format("== PVE BOSSRUSH : %d seeds/composition/boss ==", N))

for ci, comp in ipairs(comps) do
  local left = Compbuild.toComp(comp, -1)
  local cAgg = newAgg()
  byComp[comp.id] = cAgg
  matrix[comp.id] = {}
  for bi, abom in ipairs(bosses) do
    local bAgg = byBoss[abom.key]
    if not bAgg then bAgg = newAgg(); byBoss[abom.key] = bAgg end
    local cell = newAgg()
    for run = 1, N do
      local seed = BASE_SEED + ci * 100000 + bi * 1000 + run
      local row = Bossrush.run(left, abom.key, seed)
      add(cAgg, row)
      add(bAgg, row)
      add(cell, row)
      detailRows[#detailRows + 1] = {
        comp = comp.id,
        archetype = Common.archetypeOf(comp),
        boss = abom.key,
        theme = abom.theme,
        seed = seed,
        cleared_blockers = row.cleared_blockers,
        clear_seconds = row.clear_seconds,
        survived = row.survived,
        full_score_window = row.survived_score_window,
        boss_killed = row.boss_killed,
        boss_score_damage = row.boss_score_damage,
        boss_score_dps = row.boss_score_dps,
        score_damage_by_cause = row.score_damage_by_cause,
      }
    end
    matrix[comp.id][abom.key] = finish(cell)
  end
end

local compRows, bossRows = {}, {}
for _, comp in ipairs(comps) do
  local inv = Compcost.of(comp)
  local coh = Coherence.scoreTeam(comp.units or {}, { commander = comp.commander, relics = comp.relics })
  local row = finish(byComp[comp.id])
  row.id = comp.id
  row.archetype = Common.archetypeOf(comp)
  row.gold = inv.gold
  row.cost_score = inv.score
  row.coherence = coh.coherence
  row.subscores = coh.subscores
  compRows[#compRows + 1] = row
end
table.sort(compRows, function(a, b)
  if a.avg_score_damage ~= b.avg_score_damage then return a.avg_score_damage > b.avg_score_damage end
  return a.id < b.id
end)

for _, abom in ipairs(bosses) do
  local row = finish(byBoss[abom.key])
  row.key = abom.key
  row.name = abom.name
  row.theme = abom.theme
  row.intent = abom.intent
  bossRows[#bossRows + 1] = row
end
table.sort(bossRows, function(a, b) return a.key < b.key end)

print(string.format("%-28s %7s %8s %8s %9s %9s %8s",
  "comp", "clear%", "survive%", "full%", "score", "dps", "kill%"))
for i = 1, math.min(12, #compRows) do
  local r = compRows[i]
  print(string.format("%-28s %6.1f%% %7.1f%% %7.1f%% %9.1f %9.2f %7.1f%%",
    r.id, r.clear_rate * 100, r.survival_rate * 100, r.full_score_window_rate * 100,
    r.avg_score_damage, r.avg_score_dps, r.boss_kill_rate * 100))
end

local payload = {
  mode = "bossrush",
  seeds_per_pair = N,
  config = {
    comps = Common.env("PIT_BOSSRUSH_COMPS"),
    abominations = Common.env("PIT_ABOMINATIONS"),
    score_seconds = Bossrush.DEFAULT_SCORE_TICKS / Common.FPS,
  },
  notes = {
    "Bossrush is a lab-only PvE/endgame scoring prototype.",
    "Generals and summoned adds block targeting; scoring starts once all non-boss right units are dead.",
    "The boss uses huge HP and the standard arena; no render/audio state participates in this report.",
  },
  by_comp = compRows,
  by_boss = bossRows,
  matrix = matrix,
  samples = detailRows,
}

local summary = {
  seeds_per_pair = N,
  top_comp = compRows[1],
  bosses = bossRows,
}

local path = Common.writeReport("bossrush", payload, { refSummary = summary })
print("=> ecrit " .. path .. " (+ runs/report-ref.json)")
