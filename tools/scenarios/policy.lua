-- tools/scenarios/policy.lua
-- MODE P2 — PROGRESSIONS PAR POLITIQUE (scénario B, balance-psychology §2.4-B). Remplace le randomBuild()
-- de tools/sim.lua par un SÉLECTEUR DE POLITIQUE (src/lab/policies) : chaque run = (politique, seed) pilotée
-- de bout en bout par le rundriver (escalade PvE réelle, économie de run seedée). On rapporte par politique :
--   completion% (atteint 10 victoires)  ·  avg_rounds  ·  combat win-rate  ·  invest final (Compcost) moyen.
-- Le tout EN REGARD de random_baseline (le plancher : toute politique sensée doit le battre).
--
-- SANTÉ (§2.6 diversité) : PLUSIEURS politiques complètent (méta non monoculture), AUCUNE ne domine TOUT.
-- SIM-pur, seedé, déterministe (même N + mêmes seeds -> même rapport). N = runs/politique. Lancement :
--   luajit tools/sim.lua policy [N]      (N défaut 100, cf. §4 P2 : >=100 runs/politique)

local Common = require("tools.scenarios.common")
local Rundriver = require("src.lab.rundriver")
local Policies = require("src.lab.policies")

local N = require("tools.scenarios.argn")(100)
local BASE_SEED = 920000
local HPM = tonumber(os.getenv("PIT_HP_MULT"))

-- ── Jeu de politiques évalué. On déplie defaultSet (wide/tall + 4 DoT committed + baseline) ; le random
-- baseline reçoit un RNG SEEDÉ DÉDIÉ (re-seedé par run pour la reproductibilité — sinon son état dériverait
-- d'un run à l'autre). Les politiques scriptées sont pures (déterministes par (seed du run)). ──
local function makePolicies(runIndex)
  -- RNG du baseline DÉRIVÉ du run (seed stable) -> chaque run du baseline est rejouable indépendamment.
  local brng = love.math.newRandomGenerator(7000 + runIndex)
  return Policies.analysisSet(brng)
end

-- agrégat par NOM de politique
local agg = {}          -- [name] = { runs, wins, completions, roundsSum, combatWins, combatTotal, goldSum, scoreSum }
local order = {}        -- ordre stable d'apparition
local function A(name)
  local a = agg[name]
  if not a then
    a = { runs = 0, completions = 0, roundsSum = 0, combatWins = 0, combatTotal = 0, goldSum = 0, scoreSum = 0, winsSum = 0 }
    agg[name] = a; order[#order + 1] = name
  end
  return a
end

print(string.format("== P2 PROGRESSIONS PAR POLITIQUE : %d runs/politique ==", N))

for run = 1, N do
  local pols = makePolicies(run)
  for _, p in ipairs(pols) do
    -- Seed apparié par run : toutes les politiques démarrent du même monde, puis divergent par leurs actions.
    local seed = BASE_SEED + run * 131
    local traj = Rundriver.run(seed, p, { hpMult = HPM })
    local a = A(p.name)
    a.runs = a.runs + 1
    a.roundsSum = a.roundsSum + #traj.rounds
    a.winsSum = a.winsSum + (traj.wins or 0)
    if traj.result == "win" then a.completions = a.completions + 1 end
    for _, rd in ipairs(traj.rounds) do
      if rd.decided ~= nil then a.combatTotal = a.combatTotal + 1; if rd.win then a.combatWins = a.combatWins + 1 end end
    end
    local fc = traj.finalCost or { gold = 0, score = 0 }
    a.goldSum = a.goldSum + (fc.gold or 0)
    a.scoreSum = a.scoreSum + (fc.score or 0)
  end
end

-- lignes triées par completion% décroissant (la stratégie qui réussit le mieux en haut)
local rows = {}
for _, name in ipairs(order) do
  local a = agg[name]
  rows[#rows + 1] = {
    name = name, runs = a.runs,
    completion = (a.runs > 0) and (a.completions / a.runs) or 0,
    avg_rounds = (a.runs > 0) and (a.roundsSum / a.runs) or 0,
    avg_wins = (a.runs > 0) and (a.winsSum / a.runs) or 0,
    combat_wr = (a.combatTotal > 0) and (a.combatWins / a.combatTotal) or 0,
    avg_gold = (a.runs > 0) and (a.goldSum / a.runs) or 0,
    avg_score = (a.runs > 0) and (a.scoreSum / a.runs) or 0,
  }
end
table.sort(rows, function(x, y)
  if x.completion ~= y.completion then return x.completion > y.completion end
  return x.name < y.name
end)

print(string.format("%-20s %6s %11s %10s %9s %8s %8s", "politique", "runs", "completion%", "avg_round", "combat%", "or_fin", "score"))
for _, r in ipairs(rows) do
  print(string.format("%-20s %6d %10.1f%% %10.1f %8.1f%% %8.1f %8.3f",
    r.name, r.runs, r.completion * 100, r.avg_rounds, r.combat_wr * 100, r.avg_gold, r.avg_score))
end

-- VERDICT diversité : combien battent le baseline (completion stricte > baseline) + combien complètent du tout.
local baseComp = rows[#rows] and 0 or 0
for _, r in ipairs(rows) do if r.name == "random_baseline" then baseComp = r.completion end end
local beatBaseline, anyComplete, dominators = 0, 0, 0
for _, r in ipairs(rows) do
  if r.name ~= "random_baseline" and r.completion > baseComp then beatBaseline = beatBaseline + 1 end
  if r.completion > 0 then anyComplete = anyComplete + 1 end
  if r.completion >= 0.99 then dominators = dominators + 1 end -- complète quasi-toujours = candidat « domine »
end
print(string.format("baseline (random) completion = %.1f%% | politiques qui le battent : %d/%d | qui completent : %d",
  baseComp * 100, beatBaseline, #rows - 1, anyComplete))
if dominators >= 1 then
  print(string.format("  (note : %d politique(s) completent >=99%% -> surveiller la DOMINATION ; sain si l'adversaire PvE doit monter)", dominators))
end
if beatBaseline == 0 then
  print("  ALERTE : aucune politique scriptee ne bat le plancher aleatoire -> les strategies ne paient pas (a investiguer).")
end

-- ── Rapport diff-able. policy_completion : par politique, completion% + avg_rounds + invest final. ──
local pc = {}
for _, r in ipairs(rows) do
  pc[r.name] = { runs = r.runs, completion = r.completion, avg_rounds = r.avg_rounds,
    avg_wins = r.avg_wins, combat_winrate = r.combat_wr, avg_gold = r.avg_gold, avg_score = r.avg_score }
end
local payload = { mode = "policy", runs_per_policy = N, baseline_completion = baseComp,
  beat_baseline = beatBaseline, any_complete = anyComplete, policy_completion = pc }
-- résumé de méta : completion par politique (compact, diff stable).
local refComp = {}
for _, r in ipairs(rows) do refComp[r.name] = r.completion end
local summary = { runs_per_policy = N, baseline_completion = baseComp, beat_baseline = beatBaseline,
  any_complete = anyComplete, completion = refComp }
local path = Common.writeReport("policy", payload, { refSummary = summary })
print("=> ecrit " .. path .. " (+ runs/report-ref.json)")
