-- tools/runsim.lua
-- BATCH de RUNS automatisées + ANALYSE INVESTISSEMENT-AWARE (Pilier B). Trois sections :
--   1. RUNS PAR POLITIQUE : N runs complètes par « joueur-IA » (escalade PvE) -> taux de complétion,
--      rounds moyens, win-rate de combat, investissement final. « Quelle STRATÉGIE réussit ? »
--   2. MATRICE DE COUNTERS : compos PARFAITES du catalogue en tête-à-tête (M matchs/cellule) ->
--      win% A-vs-B. « Quel archétype compte quel autre ? » (counters = attendus, pas des bugs).
--   3. FRAGILITÉ : perfect vs missing_clutch contre un adversaire commun -> Δwin% = valeur de la pièce clutch.
-- Le PRINCIPE (cf. l'user) : le win% brut ne vaut rien seul. On le met en regard du SCORE D'INVESTISSEMENT
-- (compcost) et on ne FLAGUE une compo que si elle gagne SOUS son coût (hors counters DESIGNÉS).
-- Déterministe : même N/M -> même rapport. Lancement : luajit tools/runsim.lua [N] [M]
package.path = "./?.lua;" .. package.path
love = require("tests.mock_love")

local Rundriver = require("src.lab.rundriver")
local Policies = require("src.lab.policies")
local Compositions = require("src.data.compositions")
local Compbuild = require("src.lab.compbuild")
local Compcost = require("src.lab.compcost")
local Match = require("src.combat.match")

local N = tonumber(arg and arg[1]) or 40 -- runs par politique
local M = tonumber(arg and arg[2]) or 30 -- matchs par cellule de matrice
local HPM = tonumber(os.getenv("PIT_HP_MULT")) -- bouton global de PV : sweep `PIT_HP_MULT=N` (sinon constante Arena.HP_MULT)
local RUN_SEED, MATRIX_SEED = 4000000, 8000000

-- Compo PARFAITE représentant chaque archétype (matrice + fragilité).
local ARCH_COMP = {
  poison = "poison_diamant_perfect", burn = "burn_ligne_perfect", bleed = "bleed_anneau_perfect",
  rot = "rot_carre_perfect", tank = "tank_carre", bruiser = "bruiser_carre", shock = "shock_storm_carre",
}
local ARCH_ORDER = { "poison", "burn", "bleed", "rot", "shock", "bruiser", "tank" }

-- COUNTERS DESIGNÉS (attaquant > défenseur = ATTENDU -> jamais flaggé). cf. docs/research/balance-sim-design.md.
local DESIGNED = {
  ["rot>tank"] = true, ["poison>tank"] = true, ["burn>tank"] = true, ["shock>tank"] = true,
  ["bleed>bruiser"] = true, ["tank>bruiser"] = true,
}

local function pct(x) return string.format("%.0f%%", x * 100) end
local function num(v) if v == math.floor(v) then return string.format("%d", v) else return string.format("%.3f", v) end end

-- ─────────────────── 1) RUNS PAR POLITIQUE ───────────────────
print(string.format("== RUN FORGE : %d runs/politique (escalade PvE) ==", N))
local prng = love.math.newRandomGenerator(1234567) -- RNG du joueur aléatoire (seedé -> reproductible)
local policies = Policies.defaultSet(prng)
local polRows = {}
for _, p in ipairs(policies) do
  local comp, rounds, cost, wins, totalCombats, combatWins = 0, 0, 0, 0, 0, 0
  for run = 1, N do
    local t = Rundriver.run(RUN_SEED + run, p, { hpMult = HPM })
    if t.result == "win" then comp = comp + 1 end
    rounds = rounds + #t.rounds
    cost = cost + (t.finalCost and t.finalCost.score or 0)
    wins = wins + t.wins
    totalCombats = totalCombats + t.wins + t.losses
    combatWins = combatWins + t.wins
  end
  polRows[#polRows + 1] = {
    name = p.name, completion = comp / N, avgRounds = rounds / N, avgCost = cost / N,
    avgWins = wins / N, combatWR = (totalCombats > 0) and combatWins / totalCombats or 0,
  }
end
table.sort(polRows, function(a, b) if a.completion ~= b.completion then return a.completion > b.completion end return a.name < b.name end)
print(string.format("%-20s %10s %8s %9s %9s %9s", "politique", "complete%", "rounds", "win/run", "combatWR", "invest"))
for _, r in ipairs(polRows) do
  print(string.format("%-20s %9s %8.1f %9.1f %9s %9.2f", r.name, pct(r.completion), r.avgRounds, r.avgWins, pct(r.combatWR), r.avgCost))
end

-- ─────────────────── 2) MATRICE DE COUNTERS (compos parfaites) ───────────────────
-- Pré-matérialise chaque archétype en compo d'arène GAUCHE et DROITE (1× ; l'arène ne mute pas).
local leftC, rightC, score = {}, {}, {}
for _, a in ipairs(ARCH_ORDER) do
  local comp = Compositions.byId[ARCH_COMP[a]]
  leftC[a] = Compbuild.toComp(comp, -1)
  rightC[a] = Compbuild.toComp(comp, 1)
  score[a] = Compcost.of(comp).score
end

local function winRate(L, R, seedBase)
  local w = 0
  for i = 1, M do if Match.run(L, R, seedBase + i, { hpMult = HPM }).win then w = w + 1 end end
  return w / M
end

local matrix = {}
local si = 0
for _, a in ipairs(ARCH_ORDER) do
  matrix[a] = {}
  for _, b in ipairs(ARCH_ORDER) do
    si = si + 1
    matrix[a][b] = (a == b) and 0.5 or winRate(leftC[a], rightC[b], MATRIX_SEED + si * 1000)
  end
end

print("")
print(string.format("== MATRICE DE COUNTERS : win%% de LIGNE vs COLONNE (compos parfaites, %d matchs/cellule) ==", M))
io.write(string.format("%-9s", "A\\B"))
for _, b in ipairs(ARCH_ORDER) do io.write(string.format("%7s", b:sub(1, 6))) end
io.write(string.format("%8s\n", "invest"))
for _, a in ipairs(ARCH_ORDER) do
  io.write(string.format("%-9s", a:sub(1, 8)))
  for _, b in ipairs(ARCH_ORDER) do io.write(string.format("%7s", pct(matrix[a][b]))) end
  io.write(string.format("%8.2f\n", score[a]))
end

-- FLAGS : A gagne nettement (>60%) SOUS son coût (score[A] <= score[B]) ET ce n'est PAS un counter designé.
local flags = {}
for _, a in ipairs(ARCH_ORDER) do
  for _, b in ipairs(ARCH_ORDER) do
    if a ~= b and matrix[a][b] > 0.60 and score[a] <= score[b] + 0.001 and not DESIGNED[a .. ">" .. b] then
      flags[#flags + 1] = { a = a, b = b, wr = matrix[a][b], da = score[a], db = score[b] }
    end
  end
end
print("")
if #flags > 0 then
  print("DRAPEAUX (gagne SOUS son investissement, hors counters designes) :")
  for _, f in ipairs(flags) do
    print(string.format("  [%s] bat [%s] a %s  (invest %.2f <= %.2f) -> a inspecter", f.a, f.b, pct(f.wr), f.da, f.db))
  end
else
  print("DRAPEAUX : aucun (toute domination est soit designee, soit payee par l'investissement).")
end

-- ─────────────────── 3) FRAGILITÉ : perfect vs missing_clutch en TÊTE-À-TÊTE (le miroir isole la pièce) ───────────────────
-- A_perfect (gauche) vs A_missing_clutch (droite) : win% > 50% = ce que la pièce CLUTCH apporte vraiment.
local fragRows = {}
for _, a in ipairs({ "poison", "burn", "rot" }) do
  local perfId = ARCH_COMP[a]
  local clutch = Compositions.byId[perfId:gsub("perfect", "missing_clutch")]
  if clutch then
    local wr = winRate(leftC[a], Compbuild.toComp(clutch, 1), MATRIX_SEED + 777000)
    fragRows[#fragRows + 1] = { a = a, wr = wr, edge = wr - 0.5 }
  end
end
print("")
print("== FRAGILITE : perfect vs sa version SANS la piece clutch (tete-a-tete) ==")
for _, r in ipairs(fragRows) do
  print(string.format("  %-8s perfect gagne %s du miroir   (avantage %+.0f pts = la valeur de la piece clutch)",
    r.a, pct(r.wr), r.edge * 100))
end

-- ─────────────────── runreport.json (diff-able) ───────────────────
local parts = {}
parts[#parts + 1] = string.format('"n":%d,"m":%d', N, M)
local pol = {}
for _, r in ipairs(polRows) do
  pol[#pol + 1] = string.format('"%s":{"completion":%s,"avg_rounds":%s,"avg_wins":%s,"combat_wr":%s,"invest":%s}',
    r.name, num(r.completion), num(r.avgRounds), num(r.avgWins), num(r.combatWR), num(r.avgCost))
end
table.sort(pol)
parts[#parts + 1] = '"policies":{' .. table.concat(pol, ",") .. "}"
local mrows = {}
for _, a in ipairs(ARCH_ORDER) do
  local cells = {}
  for _, b in ipairs(ARCH_ORDER) do cells[#cells + 1] = string.format('"%s":%s', b, num(matrix[a][b])) end
  mrows[#mrows + 1] = string.format('"%s":{%s}', a, table.concat(cells, ","))
end
parts[#parts + 1] = '"counter_matrix":{' .. table.concat(mrows, ",") .. "}"
local scs = {}
for _, a in ipairs(ARCH_ORDER) do scs[#scs + 1] = string.format('"%s":%s', a, num(score[a])) end
parts[#parts + 1] = '"investment":{' .. table.concat(scs, ",") .. "}"
local fl = {}
for _, f in ipairs(flags) do fl[#fl + 1] = string.format('{"a":"%s","b":"%s","wr":%s}', f.a, f.b, num(f.wr)) end
parts[#parts + 1] = '"flags":[' .. table.concat(fl, ",") .. "]"
local fr = {}
for _, r in ipairs(fragRows) do fr[#fr + 1] = string.format('{"arch":"%s","mirror_wr":%s,"edge":%s}', r.a, num(r.wr), num(r.edge)) end
parts[#parts + 1] = '"fragility":[' .. table.concat(fr, ",") .. "]"

os.execute("mkdir -p runs")
local f = io.open("runs/runreport.json", "w")
if f then f:write("{" .. table.concat(parts, ",") .. "}\n"); f:close(); print("\n=> ecrit runs/runreport.json") end
