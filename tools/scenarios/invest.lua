-- tools/scenarios/invest.lua
-- MODE P1 — INVESTISSEMENT BRANCHÉ (le JUGE SUPRÊME, balance-psychology §2.5 / balance-sim-design §1).
-- Généralise le scénario C6 hardcodé de tools/sim.lua : au lieu d'UN combo testé, on balaie un CHAMP de
-- compos « joueur » (catalogue + bandes) × un champ d'adversaires, M matchs seedés/cellule. Pour chaque
-- camp on loggue l'INVEST (Compcost). Le rapport calcule le WIN-RATE CONTEXTUALISÉ : gagne-t-on SOUS son
-- coût ? On FLAGUE UNIQUEMENT ce qui gagne à invest ≤ adversaire ET win% > seuil ET HORS counter intentionnel
-- (DESIGNED : poison/burn/rot/shock>tank, bleed>bruiser, tank>bruiser). C'est le seul vrai signal de « broken ».
--
-- SIM-pur, seedé, déterministe (même N -> même rapport). N = matchs/cellule (M de la spec). Lancement :
--   luajit tools/sim.lua invest [M]      (M défaut 50, cf. §2.6 : M>=50 stabilise hors 0/100% bruités)

local Common = require("tools.scenarios.common")
local Compositions = require("src.data.compositions")
local Bands = require("src.lab.bands")
local Compbuild = require("src.lab.compbuild")

local M = require("tools.scenarios.argn")(50)
local BASE_SEED = 810000
local HPM = tonumber(os.getenv("PIT_HP_MULT"))
local WIN_HOT = 0.60 -- seuil de win% au-dessus duquel « gagner sous son coût » devient un drapeau (placeholder)

-- ── Champ « joueur » : compos COHÉRENTES (vrais builds, pas du bruit aléatoire). On prend les compos
-- featured du catalogue (perfect/wall/baseline/amp) + les bandes MID/END (builds de stade typés). ──
local PLAYERS = {}
do
  local seen = {}
  local function add(c) if c and not seen[c.id] then seen[c.id] = true; PLAYERS[#PLAYERS + 1] = c end end
  for _, c in ipairs(Compositions.list) do
    -- on garde les builds « aboutis » (pas les variantes amputées missing_*, qui servent au scénario reliques)
    if c.variant == "perfect" or c.variant == "wall" or c.variant == "baseline" or c.variant == "amp" then add(c) end
  end
  for _, band in ipairs({ "mid", "end_" }) do
    for _, c in ipairs(Bands.list[band]) do add(c) end
  end
end

-- ── Champ « adversaire » : mirror + un set représentatif (murs, bruiser témoin, DoT croisé, end-builds). ──
local FOE_IDS = {
  "tank_carre", "bruiser_carre", "sustain_carre", "cross_venom_pyre",
  "poison_diamant_perfect", "burn_ligne_perfect", "rot_carre_perfect", "bleed_anneau_perfect",
  "fortress_thorns_carre", "shock_carre",
}
local FOES = {}
for _, id in ipairs(FOE_IDS) do
  local c = Compositions.byId[id]
  if c then FOES[#FOES + 1] = c end
end

-- Cache des compos d'arène (Compbuild est LOURD : 1 build/compo, réutilisé sur tous les seeds — cf. compbuild.lua).
local leftCache, rightCache = {}, {}
local function leftOf(c) local v = leftCache[c.id]; if not v then v = Compbuild.toComp(c, -1); leftCache[c.id] = v end; return v end
local function rightOf(c) local v = rightCache[c.id]; if not v then v = Compbuild.toComp(c, 1); rightCache[c.id] = v end; return v end

-- Investissement (mémoïsé par id : pur, ne dépend pas du seed).
local invCache = {}
local function investOf(c) local v = invCache[c.id]; if not v then v = Common.invest(c); invCache[c.id] = v end; return v end

print(string.format("== P1 INVESTISSEMENT : %d compos joueur x %d adversaires x %d matchs ==", #PLAYERS, #FOES, M))

local rows = {}        -- par compo joueur : agrégat
local flags = {}       -- compos qui gagnent SOUS leur coût hors DESIGNED
local seedCounter = 0

for _, pc in ipairs(PLAYERS) do
  local pInv = investOf(pc)
  local pArch = Common.archetypeOf(pc)
  local L = leftOf(pc)
  local wins, total = 0, 0
  -- sous-agrégat : combats où le joueur GAGNE alors qu'il a investi MOINS OU AUTANT (le « sous son coût »)
  local underWins, underTotal = 0, 0
  local underHotCells = {} -- cellules suspectes (gagne sous coût, hors DESIGNED, win-cell chaud)
  for _, fc in ipairs(FOES) do
    if fc.id ~= pc.id then -- pas de mirror trivial (même build des 2 côtés = 50% par construction)
      local fInv = investOf(fc)
      local fArch = Common.archetypeOf(fc)
      local R = rightOf(fc)
      local cw, ct = 0, 0
      for k = 1, M do
        seedCounter = seedCounter + 1
        local res = Common.fight(L, R, BASE_SEED + seedCounter, HPM)
        ct = ct + 1; total = total + 1
        if res.win then cw = cw + 1; wins = wins + 1 end
      end
      local cellWr = (ct > 0) and (cw / ct) or 0
      -- contexte d'invest : le joueur a-t-il investi <= l'adversaire ? (score composite, le « coût » de la spec)
      local under = pInv.score <= fInv.score + 1e-9
      if under then
        underTotal = underTotal + ct
        underWins = underWins + cw
        -- DRAPEAU : gagne sous son coût, win-cell chaud, et CE n'est PAS un counter intentionnel.
        if cellWr > WIN_HOT and not Common.isDesigned(pArch, fArch) then
          underHotCells[#underHotCells + 1] = { foe = fc.id, foe_arch = fArch, winrate = cellWr,
            p_score = pInv.score, foe_score = fInv.score }
        end
      end
    end
  end
  local wr = (total > 0) and (wins / total) or 0
  local underWr = (underTotal > 0) and (underWins / underTotal) or 0
  rows[#rows + 1] = {
    id = pc.id, archetype = pArch, winrate = wr, gold = pInv.gold, score = pInv.score,
    under_winrate = underWr, under_n = underTotal, hot = underHotCells,
  }
  -- promeut au niveau « flag » si au moins une cellule chaude sous coût hors DESIGNED
  if #underHotCells > 0 then
    flags[#flags + 1] = { id = pc.id, archetype = pArch, under_winrate = underWr, cells = underHotCells }
  end
end

-- tri d'affichage : win-rate sous-coût décroissant (les plus suspects en haut), puis id
table.sort(rows, function(a, b)
  if a.under_winrate ~= b.under_winrate then return a.under_winrate > b.under_winrate end
  return a.id < b.id
end)

print(string.format("%-26s %-8s %6s %7s %8s %10s", "compo", "arch", "win%", "or", "score", "sous-cout%"))
for _, r in ipairs(rows) do
  print(string.format("%-26s %-8s %5.1f%% %7d %8.3f %9.1f%% (n=%d)",
    r.id, r.archetype, r.winrate * 100, r.gold, r.score, r.under_winrate * 100, r.under_n))
end

if #flags > 0 then
  print(string.format("DRAPEAUX (gagne SOUS son coût, win-cell > %.0f%%, HORS counter intentionnel) :", WIN_HOT * 100))
  for _, fl in ipairs(flags) do
    print(string.format("  [%-8s] %-24s sous-cout %.1f%%", fl.archetype, fl.id, fl.under_winrate * 100))
    for _, c in ipairs(fl.cells) do
      print(string.format("       vs %-22s (%-7s) win %.1f%%  [score %.3f <= %.3f]",
        c.foe, c.foe_arch, c.winrate * 100, c.p_score, c.foe_score))
    end
  end
else
  print("DRAPEAUX : aucun (aucune compo ne gagne sous son coût hors counter intentionnel). Sain.")
end

-- ── Rapport diff-able. invest_context : par compo, win-rate brut + sous-coût + or/score. flags = le verdict. ──
local unitCtx = {}
for _, r in ipairs(rows) do
  unitCtx[r.id] = { archetype = r.archetype, winrate = r.winrate, under_winrate = r.under_winrate,
    under_n = r.under_n, gold = r.gold, score = r.score, hot_cells = #r.hot }
end
local flagOut = {}
for _, fl in ipairs(flags) do
  local cells = {}
  for _, c in ipairs(fl.cells) do
    cells[#cells + 1] = { foe = c.foe, foe_arch = c.foe_arch, winrate = c.winrate }
  end
  flagOut[#flagOut + 1] = { id = fl.id, archetype = fl.archetype, under_winrate = fl.under_winrate, cells = cells }
end

local payload = {
  mode = "invest", matchs_per_cell = M, players = #PLAYERS, foes = #FOES,
  win_hot = WIN_HOT, invest_context = unitCtx, flags = flagOut,
}
-- résumé de méta (golden ref) : compact -> diff stable patch-sur-patch (compte de drapeaux + ids triés).
local flaggedIds = {}
for _, fl in ipairs(flags) do flaggedIds[#flaggedIds + 1] = fl.id end
table.sort(flaggedIds)
local summary = { matchs_per_cell = M, players = #PLAYERS, foes = #FOES, flag_count = #flags, flagged = flaggedIds }
local path = Common.writeReport("invest", payload, { refSummary = summary })
print("=> ecrit " .. path .. " (+ runs/report-ref.json)")
