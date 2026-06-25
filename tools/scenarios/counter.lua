-- tools/scenarios/counter.lua
-- MODE P3 — MATRICE DE COUNTERS (santé des counters, balance-sim-design §5.2 / balance-psychology §2.6-4).
-- Compos PARFAITES archétype × archétype, M matchs seedés/cellule. Pour chaque cellule (att vs def) : win%
-- ligne-vs-colonne + invest (Compcost) par archétype. La table DESIGNED encode l'INTENTION (counters voulus :
-- poison/burn/rot/shock>tank, bleed>bruiser, tank>bruiser). On FLAGUE une cellule « gagne sous son coût, hors
-- counter intentionnel » -> dette d'équilibrage. Un counter VOULU n'est JAMAIS flaggé (sémantique DESIGNED).
--
-- SIM-pur, seedé, déterministe. M = matchs/cellule (>=50 stabilise, cf. §2.6). Lancement :
--   luajit tools/sim.lua counter [M]      (M défaut 50)

local Common = require("tools.scenarios.common")
local Compositions = require("src.data.compositions")
local Compbuild = require("src.lab.compbuild")

local M = require("tools.scenarios.argn")(50)
local BASE_SEED = 660000
local HPM = tonumber(os.getenv("PIT_HP_MULT"))
local WIN_HOT = 0.60

-- ── Une compo « parfaite » REPRÉSENTATIVE par archétype (le build abouti de cet archétype). On prend la
-- variante `perfect`/`wall`/`amp`/`baseline` du catalogue. Archétypes sans compo featured -> ignorés. ──
local ARCH_COMP = {
  poison = "poison_diamant_perfect",
  burn   = "burn_ligne_perfect",
  bleed  = "bleed_anneau_perfect",
  rot    = "rot_carre_perfect",
  tank   = "tank_carre",
  bruiser = "bruiser_carre",
  shock  = "shock_carre",
  shield = "fortress_thorns_carre",
  sustain = "sustain_carre",
}
local ARCHES = {}
for _, a in ipairs(Compositions.archetypes) do
  if ARCH_COMP[a] and Compositions.byId[ARCH_COMP[a]] then ARCHES[#ARCHES + 1] = a end
end

-- compos d'arène (gauche/droite) + invest mémoïsés par archétype.
local leftCache, rightCache, invCache = {}, {}, {}
local function compOf(a) return Compositions.byId[ARCH_COMP[a]] end
local function leftOf(a) local v = leftCache[a]; if not v then v = Compbuild.toComp(compOf(a), -1); leftCache[a] = v end; return v end
local function rightOf(a) local v = rightCache[a]; if not v then v = Compbuild.toComp(compOf(a), 1); rightCache[a] = v end; return v end
local function investOf(a) local v = invCache[a]; if not v then v = Common.invest(compOf(a)); invCache[a] = v end; return v end

print(string.format("== P3 MATRICE DE COUNTERS : %d archetypes x %d matchs/cellule ==", #ARCHES, M))

-- matrice[att][def] = win% de att (gauche) vs def (droite)
local matrix = {}
local flags = {}
local seedCursor = 0
for _, att in ipairs(ARCHES) do
  matrix[att] = {}
  local L = leftOf(att)
  local aInv = investOf(att)
  for _, def in ipairs(ARCHES) do
    if att == def then
      matrix[att][def] = 0.5 -- mirror : 50% par construction (même build des 2 côtés), non joué
    else
      local R = rightOf(def)
      local dInv = investOf(def)
      local wins = 0
      for _ = 1, M do
        seedCursor = seedCursor + 1
        local res = Common.fight(L, R, BASE_SEED + seedCursor, HPM)
        if res.win then wins = wins + 1 end
      end
      local wr = wins / M
      matrix[att][def] = wr
      -- DRAPEAU : att gagne SOUS son coût (score <= def), win chaud, et CE n'est PAS un counter intentionnel.
      if aInv.score <= dInv.score + 1e-9 and wr > WIN_HOT and not Common.isDesigned(att, def) then
        flags[#flags + 1] = { att = att, def = def, winrate = wr, att_score = aInv.score, def_score = dInv.score }
      end
    end
  end
end

-- ── Affichage matrice (lignes = attaquant, colonnes = défenseur) ──
local hdr = string.format("%-9s", "att\\def")
for _, def in ipairs(ARCHES) do hdr = hdr .. string.format("%8.7s", def) end
print(hdr)
for _, att in ipairs(ARCHES) do
  local line = string.format("%-9s", att)
  for _, def in ipairs(ARCHES) do
    line = line .. string.format("%7.0f%%", matrix[att][def] * 100)
  end
  print(line)
end

-- invest par archétype (le contexte de lecture de la matrice : forte ET chère = sain ; forte ET pas chère = suspect)
print("investissement par archetype (score / or) :")
for _, a in ipairs(ARCHES) do
  local i = investOf(a)
  print(string.format("  %-9s score %.3f  or %d", a, i.score, i.gold))
end

-- ── VÉRIFICATION DESIGNED : les counters VOULUS se produisent-ils ? (att > def attendu). On signale les
-- counters intentionnels NON RESPECTÉS (l'attaquant voulu NE bat PAS le défenseur) = dette (DoT sous-tuné). ──
print("counters INTENTIONNELS (DESIGNED) — respectes ?")
local designedRows = {}
for att, row in pairs(Common.DESIGNED) do
  for def in pairs(row) do
    if matrix[att] and matrix[att][def] ~= nil then
      designedRows[#designedRows + 1] = { att = att, def = def, wr = matrix[att][def] }
    end
  end
end
table.sort(designedRows, function(a, b) if a.att ~= b.att then return a.att < b.att end return a.def < b.def end)
for _, d in ipairs(designedRows) do
  local ok = d.wr > 0.5
  print(string.format("  %-7s > %-7s : win %.0f%%  %s", d.att, d.def, d.wr * 100,
    ok and "OK (counter voulu se produit)" or "ALERTE (counter voulu ABSENT -> attaquant sous-tune)"))
end

if #flags > 0 then
  print(string.format("DRAPEAUX (gagne sous son cout, win > %.0f%%, HORS counter intentionnel) :", WIN_HOT * 100))
  table.sort(flags, function(a, b) return a.winrate > b.winrate end)
  for _, f in ipairs(flags) do
    print(string.format("  %-7s bat %-7s win %.0f%%  [score %.3f <= %.3f]",
      f.att, f.def, f.winrate * 100, f.att_score, f.def_score))
  end
else
  print("DRAPEAUX : aucun (aucun archetype ne gagne sous son cout hors counter intentionnel).")
end

-- ── Rapport diff-able : matrice (att -> {def -> win%}) + invest par archétype + flags + verdict DESIGNED. ──
local matOut = {}
for att, row in pairs(matrix) do
  matOut[att] = {}
  for def, wr in pairs(row) do matOut[att][def] = wr end
end
local invOut = {}
for _, a in ipairs(ARCHES) do local i = investOf(a); invOut[a] = { score = i.score, gold = i.gold } end
local designedOut = {}
for _, d in ipairs(designedRows) do designedOut[d.att .. ">" .. d.def] = { winrate = d.wr, respected = d.wr > 0.5 } end
local flagOut = {}
for _, f in ipairs(flags) do flagOut[#flagOut + 1] = { att = f.att, def = f.def, winrate = f.winrate } end
local payload = { mode = "counter", matchs_per_cell = M, archetypes = #ARCHES, win_hot = WIN_HOT,
  matrix = matOut, invest = invOut, designed = designedOut, flags = flagOut }
local flaggedPairs = {}
for _, f in ipairs(flags) do flaggedPairs[#flaggedPairs + 1] = f.att .. ">" .. f.def end
table.sort(flaggedPairs)
local designedBroken = {}
for _, d in ipairs(designedRows) do if d.wr <= 0.5 then designedBroken[#designedBroken + 1] = d.att .. ">" .. d.def end end
table.sort(designedBroken)
local summary = { matchs_per_cell = M, archetypes = #ARCHES, flag_count = #flags, flagged = flaggedPairs,
  designed_broken = designedBroken }
local path = Common.writeReport("counter", payload, { refSummary = summary })
print("=> ecrit " .. path .. " (+ runs/report-ref.json)")
