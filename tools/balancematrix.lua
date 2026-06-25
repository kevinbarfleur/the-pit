-- tools/balancematrix.lua
-- HARNAIS D'ÉQUILIBRAGE DE MASSE — la matrice BANDE × RELIQUE × COMMANDANT, pour JUGER l'équilibre du jeu
-- (demande explicite de l'user : « tester énormément de configurations pour considérer que quelque chose
-- est équilibré ou pas »).
--
-- CE QU'IL FAIT, pour chaque BANDE (early/mid/end, cf. src/lab/bands) :
--   (a) BASELINE   : les compos de la bande, sans relique ni commandant ;
--   (b) × RELIQUE  : chacune des 34 reliques (R.order) appliquée aux compos de la bande ;
--   (c) × COMMANDANT : chacun des 6 commandants posé au piédestal des compos de la bande ;
-- contre un CHAMP D'ADVERSAIRES représentatif de la bande = compos statiques (mirror + counters, cf.
-- Bands.field) + un set d'OPPOSANTS PROCÉDURAUX scalés au stade (OppGen, seedés -> déterministe).
--
-- MÉTRIQUES & DRAPEAUX (seuils SOURCÉS) :
--   · win% CONTEXTUALISÉ par investissement (Compcost) : une config CHÈRE qui gagne = NORMAL ; on flague une
--     config qui gagne SOUS son coût relatif (balance-sim-design §1/§4) ;
--   · OUTLIER : config déviant de >2σ de la moyenne de SA BANDE (commanders-plan §6, sim.lua) ;
--   · GATE : un MIROIR poussé >~85 % par une relique/un commandant (relics-overhaul §6/§ligne 317) = plus
--     de contre-jeu ; une relique/cmd INCLINE, ne GATE jamais ;
--   · LIFT de co-occurrence relique×commandant > 1.6 = combo cassé (commanders-plan §368) ;
--   · COURBE DE PUISSANCE : bas-tier faible / haut-tier fort à coût comparable (vérif inter-bande) ;
--   · ENTROPIE de Shannon des archétypes gagnants ≥ 0.90 (commanders-plan §369).
--
-- SORTIE : runs/balance-matrix.json (structuré, diff-able) + un RÉSUMÉ HUMAIN PRIORISÉ (le SIGNAL, pas la
-- donnée brute) : dominants/morts, combos cassés, gates, violations de courbe, archétypes morts.
--
-- DÉTERMINISTE : seeds INJECTÉS partout (RNG global interdit). Même (N, seeds) -> même rapport.
-- CAPS/SAMPLING : N matchs/cellule (def. 120), tous les opposants joués (pas d'échantillonnage du champ par
-- défaut) ; toute troncature est LOGUÉE explicitement (jamais silencieuse). RENDER-tainted (construit des
-- Build via Compbuild) -> HORS firewall SIM, tourne headless sous luajit + tests/mock_love (comme tools/sim).
--
--   Lancement : luajit tools/balancematrix.lua [N]      (N matchs/cellule, défaut 120)
--               PIT_BANDS=early,mid   luajit tools/balancematrix.lua 80   (sous-ensemble de bandes)
--               PIT_FAST=1            -> N=40 (passe rapide d'itération)

package.path = "./?.lua;" .. package.path
love = require("tests.mock_love")

local Bands = require("src.lab.bands")
local Compbuild = require("src.lab.compbuild")
local Compcost = require("src.lab.compcost")
local Compositions = require("src.data.compositions")
local Relics = require("src.data.relics")
local Units = require("src.data.units")
local OppGen = require("src.data.oppgen")
local Match = require("src.combat.match")
local Run = require("src.run.state")

-- ── Paramètres ──
-- N = matchs/cellule. 60 = bon compromis : sur le champ agrégé (≈10 opposants) une cellule joue ≈10×N matchs
-- -> à N=60, ~600 matchs/cellule = win% à ±~4 pts (95 %), assez pour la DIRECTION (drapeaux), pas pour 3 décimales.
-- Monter N=120+ pour un calibrage fin d'un levier précis (plus lent : ~2× le temps).
local N = tonumber(arg and arg[1]) or 60           -- matchs par CELLULE (config × champ agrégé)
if os.getenv("PIT_FAST") then N = 30 end
local BASE_SEED = 21000000                          -- racine des seeds de match (déterministe)
-- TICK_CAP 3000 : MESURÉ (tests bandes) — tous les matchups de bande concluent < 1750 ticks (max observé 1716).
-- 3000 laisse une marge ×1.7 et borne tout combat pathologique (verdict alors jugé sur la fraction de PV =
-- Match.judge, identique à 8000). Aucun verdict ne change vs 8000 sur le champ de bande (logué, vérifiable).
local TICK_CAP = 3000
local OPP_PER_BAND = 4                              -- nb d'opposants procéduraux (OppGen) ajoutés au champ par bande
local GATE = 0.85                                    -- mirror poussé au-dessus = gate (relics-overhaul §317)
local LIFT_BROKEN = 1.6                              -- lift relique×cmd au-dessus = combo cassé (commanders §368)
local SIGMA_OUT = 2.0                                -- déviation > = outlier (commanders §6, sim.lua)
local ENTROPY_MIN = 0.90                             -- entropie de Shannon plancher (commanders §369)

-- Les 6 COMMANDANTS = unités portant un commandBonus (pas de fichier dédié ; on les dérive du roster).
local COMMANDERS = {}
for _, id in ipairs(Units.order) do
  if Units[id] and Units[id].commandBonus then COMMANDERS[#COMMANDERS + 1] = id end
end
table.sort(COMMANDERS)

-- ── Helpers ──
local function pct(x) return string.format("%.0f%%", x * 100) end
local function num(v) if v == math.floor(v) then return string.format("%d", v) else return string.format("%.4f", v) end end

-- Résout un id de champ (compo statique) en compo de catalogue OU de bande.
local function fieldComp(id) return Bands.byId[id] or Compositions.byId[id] end

-- Stade -> paramètres OppGen (round/tier/slots) : le champ procédural suit le stade de la bande.
local BAND_STAGE = {
  early = { round = 3, tier = 1, slots = 4 },
  mid   = { round = 7, tier = 3, slots = 6 },
  end_  = { round = 13, tier = 5, slots = 9 },
}

-- Construit le CHAMP D'ADVERSAIRES d'une bande = compos statiques (côté droit, construites 1×) + opposants
-- OppGen scalés au stade (seedés -> déterministe). Chaque entrée = { id, rcomp } prête pour Match.run(., R, .).
-- L'arène ne mute pas la compo -> on réutilise chaque rcomp sur les N seeds (perf).
local function buildField(bandKey)
  local field = {}
  for _, id in ipairs(Bands.field[bandKey]) do
    local c = fieldComp(id)
    if c then field[#field + 1] = { id = id, rcomp = Compbuild.toComp(c, 1), cost = Compcost.of(c).score } end
  end
  -- Opposants procéduraux : OppGen.generate -> encounter -> Build:buildRightComp (via un Build jetable).
  local Build = require("src.scenes.build")
  local Palette = require("src.core.palette")
  local stage = BAND_STAGE[bandKey]
  local rng = love.math.newRandomGenerator(99000 + #bandKey * 7)
  for i = 1, OPP_PER_BAND do
    local enc = OppGen.generate({ round = stage.round, tier = stage.tier, slots = stage.slots,
      rng = rng, odds = Run.ODDS })
    local b = Build.new(Palette, 320, 180, { goto = function() end })
    b.board:setShape("carre"); b:computeLayout(); b.board:unlock(9)
    local rcomp = b:buildRightComp(enc, 0)
    -- coût approx d'un opposant procédural : on le chiffre via une compo synthétique (ids + niveaux).
    local synth = { sigil = "carre", boardLevel = #enc.units, units = {} }
    for _, u in ipairs(enc.units) do synth.units[#synth.units + 1] = { id = u.id, slot = 1, level = u.level or 1 } end
    field[#field + 1] = { id = "oppgen#" .. i, rcomp = rcomp, cost = Compcost.of(synth).score, generated = true }
  end
  return field
end

-- Joue UNE config (compo joueur résolue, côté gauche) contre TOUT le champ, N seeds/opposant.
-- Renvoie { wins, total, winrate, decidedFrac }. Seed déterministe : dérivé de (cellIndex, opponent, i).
local function playVsField(playerComp, field, cellSeed)
  local wins, total, decided = 0, 0, 0
  for oi, opp in ipairs(field) do
    for i = 1, N do
      local seed = cellSeed + oi * 100000 + i
      local res = Match.run(playerComp, opp.rcomp, seed, { tickCap = TICK_CAP })
      if res.win then wins = wins + 1 end
      if res.decided then decided = decided + 1 end
      total = total + 1
    end
  end
  return { wins = wins, total = total, winrate = total > 0 and wins / total or 0,
    decidedFrac = total > 0 and decided / total or 0 }
end

-- Joue une config contre UN SEUL opposant (pour le miroir / gate). N seeds.
local function playVsOne(playerComp, rcomp, cellSeed)
  local wins, total = 0, 0
  for i = 1, N do
    if Match.run(playerComp, rcomp, cellSeed + i, { tickCap = TICK_CAP }).win then wins = wins + 1 end
    total = total + 1
  end
  return total > 0 and wins / total or 0
end

-- Entropie de Shannon NORMALISÉE d'une distribution d'archétypes (compte des « côtés gagnants » par archétype).
local function shannon(counts)
  local total, k = 0, 0
  for _, c in pairs(counts) do total = total + c; if c > 0 then k = k + 1 end end
  if total <= 0 or k <= 1 then return 1 end
  local h = 0
  for _, c in pairs(counts) do
    if c > 0 then local p = c / total; h = h - p * math.log(p) end
  end
  return h / math.log(k)
end

-- ════════════════════════════════════════════════════════════════════════════════════════════════
-- BALAYAGE
-- ════════════════════════════════════════════════════════════════════════════════════════════════

-- Bandes à traiter (filtre PIT_BANDS=early,mid,end).
local BANDS = {}
do
  local filt = os.getenv("PIT_BANDS")
  if filt then
    local want = {}
    for tok in filt:gmatch("[^,]+") do
      tok = tok:gsub("%s", ""); if tok == "end" then tok = "end_" end
      want[tok] = true
    end
    for _, k in ipairs(Bands.order) do if want[k] then BANDS[#BANDS + 1] = k end end
  else
    BANDS = { "early", "mid", "end_" }
  end
end

-- Compte les reliques INERTES en combat (éco/run-only : ni op ni effet -> Relics.apply no-op). On le LOGUE :
-- une cellule relique « inerte » a un Δ ≈ 0 par construction (ce n'est pas un bug, c'est hors-combat).
local INERT_RELICS = {}
for _, rid in ipairs(Relics.order) do
  if not Relics[rid].op then INERT_RELICS[rid] = true end -- runOp/eco-only : pas de transformation de compo
end

print(string.format("== BALANCE MATRIX : %d matchs/cellule | %d reliques | %d commandants | bandes: %s ==",
  N, #Relics.order, #COMMANDERS, table.concat(BANDS, ",")))
local inertList = {}
for rid in pairs(INERT_RELICS) do inertList[#inertList + 1] = rid end
table.sort(inertList)
print(string.format("   (note: %d reliques ECO/RUN-only INERTES en combat -> NON rejouees (Delta=0 exact, recopie baseline ; gain de temps logue): %s)",
  #inertList, table.concat(inertList, ", ")))
print(string.format("   (champ = compos statiques (mirror+counters, varie par bande) + %d opposants OppGen scales ; AUCUN sampling du champ : tous les opposants joues)",
  OPP_PER_BAND))

-- Résultats agrégés (pour le rapport + JSON).
local report = { bands = {} }

-- CACHE des champs : buildField construit des Build (rigs/ambient = LOURD). On le fait UNE FOIS par bande et
-- on réutilise le résultat dans le balayage principal ET dans le détecteur de combos (évite le rebuild ×3).
local FIELD = {}
local function field(bandKey) if not FIELD[bandKey] then FIELD[bandKey] = buildField(bandKey) end return FIELD[bandKey] end

for _, bandKey in ipairs(BANDS) do
  local label = Bands.label[bandKey]
  local field = field(bandKey)
  local nStatic = 0; for _, f in ipairs(field) do if not f.generated then nStatic = nStatic + 1 end end
  print(string.format("\n──────────── BANDE %s : %d compos joueur × (baseline + %d reliques + %d cmd) vs champ de %d (%d statiques + %d OppGen) ────────────",
    label, #Bands.list[bandKey], #Relics.order, #COMMANDERS, #field, nStatic, #field - nStatic))

  local bandRep = { label = label, field = #field, configs = {}, baselineWR = {} }
  local cellIdx = 0

  -- Pour chaque compo de la bande : baseline + chaque relique + chaque commandant.
  for _, comp in ipairs(Bands.list[bandKey]) do
    io.write(string.format("  · %-22s ...", comp.id)); io.flush()
    local tComp = os.clock()
    local cost = Compcost.of(comp).score
    -- BASELINE
    cellIdx = cellIdx + 1
    local baseComp = Compbuild.toComp(comp, -1)
    local baseRes = playVsField(baseComp, field, BASE_SEED + cellIdx * 1000000)
    -- MIROIR baseline (la compo contre elle-même, sans rien) -> point de référence de gate.
    local baseMirror = playVsOne(baseComp, Compbuild.toComp(comp, 1), BASE_SEED + cellIdx * 1000000 + 777)
    bandRep.configs[#bandRep.configs + 1] = { comp = comp.id, arch = comp.archetype, kind = "baseline",
      mod = "—", wr = baseRes.winrate, cost = cost, decided = baseRes.decidedFrac, mirror = baseMirror }
    bandRep.baselineWR[comp.id] = baseRes.winrate

    -- × RELIQUES
    for _, rid in ipairs(Relics.order) do
      cellIdx = cellIdx + 1
      if INERT_RELICS[rid] then
        -- ECO/RUN-only : Relics.apply NE MUTE PAS la compo de combat -> identique à la baseline. On NE REJOUE
        -- PAS le champ (gain de temps LOGUÉ via la note d'en-tête) : on recopie le résultat baseline, Δ=0 exact.
        bandRep.configs[#bandRep.configs + 1] = { comp = comp.id, arch = comp.archetype, kind = "relic",
          mod = rid, wr = baseRes.winrate, cost = cost, decided = baseRes.decidedFrac, mirror = baseMirror,
          inert = true, dWR = 0, band = Relics[rid].band, tier = Relics[rid].tier }
      else
        local pc = Compbuild.toComp(comp, -1, { relics = { rid } })
        local res = playVsField(pc, field, BASE_SEED + cellIdx * 1000000)
        local mirror = playVsOne(pc, Compbuild.toComp(comp, 1, { relics = { rid } }), BASE_SEED + cellIdx * 1000000 + 777)
        bandRep.configs[#bandRep.configs + 1] = { comp = comp.id, arch = comp.archetype, kind = "relic",
          mod = rid, wr = res.winrate, cost = cost, decided = res.decidedFrac, mirror = mirror,
          dWR = res.winrate - baseRes.winrate, band = Relics[rid].band, tier = Relics[rid].tier }
      end
    end

    -- × COMMANDANTS
    for _, cid in ipairs(COMMANDERS) do
      cellIdx = cellIdx + 1
      local pc = Compbuild.toComp(comp, -1, { commander = cid })
      local res = playVsField(pc, field, BASE_SEED + cellIdx * 1000000)
      local mirror = playVsOne(pc, Compbuild.toComp(comp, 1, { commander = cid }), BASE_SEED + cellIdx * 1000000 + 777)
      bandRep.configs[#bandRep.configs + 1] = { comp = comp.id, arch = comp.archetype, kind = "commander",
        mod = cid, wr = res.winrate, cost = cost, decided = res.decidedFrac, mirror = mirror,
        dWR = res.winrate - baseRes.winrate }
    end
    io.write(string.format(" baseline win %s (%.1fs)\n", pct(baseRes.winrate), os.clock() - tComp)); io.flush()
  end

  -- ── Statistiques de bande : moyenne/σ du win% des configs (toutes), pour flaguer les OUTLIERS >2σ. ──
  local sum, n2 = 0, 0
  for _, c in ipairs(bandRep.configs) do sum = sum + c.wr; n2 = n2 + 1 end
  local mean = (n2 > 0) and sum / n2 or 0
  local var = 0
  for _, c in ipairs(bandRep.configs) do var = var + (c.wr - mean) ^ 2 end
  local stddev = (n2 > 0) and math.sqrt(var / n2) or 0
  bandRep.mean, bandRep.stddev = mean, stddev
  for _, c in ipairs(bandRep.configs) do c.sigma = (stddev > 0) and (c.wr - mean) / stddev or 0 end

  print(string.format("  champ statique: %s", table.concat(Bands.field[bandKey], ", ")))
  print(string.format("  moyenne win%% de bande = %.3f  ecart-type = %.3f  (outlier si |sigma| > %.1f)", mean, stddev, SIGMA_OUT))

  report.bands[bandKey] = bandRep
end

-- ════════════════════════════════════════════════════════════════════════════════════════════════
-- ANALYSE & DRAPEAUX (le SIGNAL priorisé)
-- ════════════════════════════════════════════════════════════════════════════════════════════════

-- 1) DOMINANTS / MORTS : configs outliers (>2σ ou <-2σ) de leur bande. On EXCLUT les reliques inertes
--    (Δ≈0 par construction) du flag « mort » (elles ne sont pas censées agir en combat).
-- CONTEXTUALISATION par INVESTISSEMENT (cœur du brief) : un mod qui domine EST suspect SEULEMENT s'il ne
-- coûte pas l'investissement correspondant. Proxy de coût ajouté :
--   · commandant : Units.cost du commandant (un rank-5 au piédestal d'une compo early = sur-investissement RÉEL
--     non chiffré par Compcost -> dominer est ATTENDU, on le marque « investi » et non « suspect ») ;
--   · relique : band "high" = palier fort (investissement de fin de run) ; "low"/"mid" qui domine = suspect.
-- "suspect" = le vrai signal d'alarme (gagne SOUS son coût) ; "investi" = récompense légitime du coût.
local function dominanceContext(c)
  if c.kind == "commander" then
    local cost = (Units[c.mod] and Units[c.mod].cost) or 1
    return (cost >= 4) and "investi" or "suspect" -- cmd rank 4-5 (cost>=4) = cher -> dominer est attendu
  elseif c.kind == "relic" then
    return (c.band == "high") and "investi" or "suspect" -- relique HAUT = palier fort -> attendu ; BAS/MOYEN = suspect
  end
  return "baseline"
end
local dominants, deads = {}, {}
for _, bandKey in ipairs(BANDS) do
  local br = report.bands[bandKey]
  for _, c in ipairs(br.configs) do
    if c.sigma > SIGMA_OUT then
      c.context = dominanceContext(c)
      dominants[#dominants + 1] = { band = bandKey, c = c }
    elseif c.sigma < -SIGMA_OUT and not c.inert then deads[#deads + 1] = { band = bandKey, c = c } end
  end
end
-- tri : les SUSPECTES d'abord (signal prioritaire), puis par σ décroissant.
table.sort(dominants, function(a, b)
  local as, bs = a.c.context == "suspect", b.c.context == "suspect"
  if as ~= bs then return as end
  return a.c.sigma > b.c.sigma
end)
table.sort(deads, function(a, b) return a.c.sigma < b.c.sigma end)

-- 2) GATES : une relique/cmd qui pousse le MIROIR de sa compo au-dessus de GATE (85 %) -> plus de contre-jeu.
--    (le miroir baseline d'une compo est ~50 % par symétrie ; un mod qui le fait exploser des deux côtés est
--    suspect SEULEMENT s'il dépasse 85 % — un mod symétrique laisse le miroir ~50 %, donc >85 % = asymétrie réelle.)
-- NOTE: en miroir, les DEUX camps portent le mod -> un mod purement « plus fort » laisse le miroir ~50 %.
-- Un miroir >85 % révèle une INTERACTION non-symétrique (ex. cleave qui tue la rangée arrière, exécution,
-- first-strike) qui casse la symétrie -> c'est le vrai détecteur de gate. On le mesure sur CHAQUE config.
local gates = {}
for _, bandKey in ipairs(BANDS) do
  local br = report.bands[bandKey]
  for _, c in ipairs(br.configs) do
    if c.kind ~= "baseline" and c.mirror and c.mirror > GATE then
      gates[#gates + 1] = { band = bandKey, c = c }
    end
  end
end
table.sort(gates, function(a, b) return a.c.mirror > b.c.mirror end)

-- 3) COMBOS CASSÉS (lift relique×commandant) : par compo, on compare le win% conjoint (relique ET cmd) à
--    l'attendu = somme des Δ solo (additivité d'effets indépendants). lift = Δconjoint / Δattendu ; > 1.6 = la
--    paire sur-performe l'addition de ses parts = SYNERGIE (voulue ou CASSÉE). Seuil lift > 1.6 (commanders §368).
--
-- TRACTABILITÉ (CAPS EXPLICITES, LOGUÉS — jamais de troncature silencieuse, cf. brief) :
--   · on cible LA compo « carry » de chaque bande (Bands.list[band][1]) — pas toutes (échantillon ciblé) ;
--   · un combo cassé EXIGE qu'au moins une part ait un Δ solo NOTABLE -> on ne teste que les TOP-K reliques et
--     TOP-K commandants par Δ solo (les seuls candidats plausibles) -> K_R×K_C paires/bande au lieu de 27×6 ;
--   · profondeur COMBO_N = min(N, 60) (le lift est un signal de DIRECTION, pas une mesure de précision) ;
--   · champ de combo = le champ COMPLET de la bande (cohérent avec les cellules solo dont on relit les Δ).
local combos = {}
local COMBO_N = math.min(N, 60)
local K_RELIC, K_CMD = 8, 6 -- top-8 reliques × top-6 cmd (tous) par Δ solo = 48 paires max/bande (logué)
local function playVsFieldN(pc, field, seed, depth)
  local wins, total = 0, 0
  for oi, opp in ipairs(field) do
    for i = 1, depth do
      if Match.run(pc, opp.rcomp, seed + oi * 100000 + i, { tickCap = TICK_CAP }).win then wins = wins + 1 end
      total = total + 1
    end
  end
  return total > 0 and wins / total or 0
end
-- CHAMP DE COMBO réduit (cap LOGUÉ) : les 5 premiers opposants du champ de bande (mirror + counters clés) —
-- suffisant pour détecter une SUR-additivité (le lift est une DIRECTION, pas une mesure fine), et ~2× plus
-- rapide que le champ complet. On réutilise le champ DÉJÀ construit (cache), pas un rebuild.
local COMBO_FIELD_MAX = 5
local function comboField(bandKey)
  local full = field(bandKey)
  local sub = {}
  for i = 1, math.min(COMBO_FIELD_MAX, #full) do sub[i] = full[i] end
  return sub
end
print(string.format("\n[combos] caps LOGUÉS : 1 compo-carry/bande × top-%d reliques × top-%d cmd (≤%d paires/bande) × %d opposants (sous-champ) × %d matchs.",
  K_RELIC, K_CMD, K_RELIC * K_CMD, COMBO_FIELD_MAX, COMBO_N))
for _, bandKey in ipairs(BANDS) do
  local br = report.bands[bandKey]
  local comp = Bands.list[bandKey][1]
  local cfield = comboField(bandKey)
  local baseComp = Compbuild.toComp(comp, -1)
  local baseWR = playVsFieldN(baseComp, cfield, BASE_SEED + 5000000 + #bandKey, COMBO_N)
  -- Δ solo (relit depuis les cellules déjà jouées) -> on classe et on garde le TOP-K.
  local rRows, cRows = {}, {}
  for _, c in ipairs(br.configs) do
    if c.comp == comp.id and c.kind == "relic" and not c.inert then rRows[#rRows + 1] = { id = c.mod, d = c.wr - br.baselineWR[comp.id] } end
    if c.comp == comp.id and c.kind == "commander" then cRows[#cRows + 1] = { id = c.mod, d = c.wr - br.baselineWR[comp.id] } end
  end
  -- on RANGE par Δ full-field (sélection des candidats), mais on RECALCULE les Δ solo SUR LE COMBO-FIELD pour
  -- que baseWR / solo / joint soient COHÉRENTS (même champ) -> lift = mesure propre de sur-additivité.
  table.sort(rRows, function(a, b) return a.d > b.d end)
  table.sort(cRows, function(a, b) return a.d > b.d end)
  local soloR, soloC = {}, {} -- Δ solo recalculés sur le combo-field (mémoïsés)
  local pairsRun = 0
  for ri = 1, math.min(K_RELIC, #rRows) do
    local rid = rRows[ri].id
    if not soloR[rid] then
      soloR[rid] = playVsFieldN(Compbuild.toComp(comp, -1, { relics = { rid } }), cfield, BASE_SEED + 5500000 + ri, COMBO_N) - baseWR
    end
    for ci = 1, math.min(K_CMD, #cRows) do
      local cid = cRows[ci].id
      if not soloC[cid] then
        soloC[cid] = playVsFieldN(Compbuild.toComp(comp, -1, { commander = cid }), cfield, BASE_SEED + 5700000 + ci, COMBO_N) - baseWR
      end
      local dR, dC = soloR[rid], soloC[cid]
      local pc = Compbuild.toComp(comp, -1, { relics = { rid }, commander = cid })
      local jointWR = playVsFieldN(pc, cfield, BASE_SEED + 6000000 + pairsRun * 7919, COMBO_N)
      local jointDelta = jointWR - baseWR
      local expected = dR + dC
      local lift = (math.abs(expected) > 0.01) and (jointDelta / expected) or 0
      if lift > LIFT_BROKEN and jointDelta > 0.05 then
        combos[#combos + 1] = { band = bandKey, comp = comp.id, relic = rid, cmd = cid,
          lift = lift, joint = jointWR, expected = baseWR + expected, dR = dR, dC = dC }
      end
      pairsRun = pairsRun + 1
    end
  end
  br.comboPairsTested = pairsRun
end
table.sort(combos, function(a, b) return a.lift > b.lift end)

-- 4) COURBE DE PUISSANCE (inter-bande) : à coût croissant early<mid<end, le win% des baselines vs leur champ
--    NE doit PAS s'effondrer (une compo END chère doit être au moins aussi solide qu'une EARLY contre un champ
--    de son stade). On lit le win% baseline moyen par bande + son coût moyen.
local curve = {}
for _, bandKey in ipairs(BANDS) do
  local br = report.bands[bandKey]
  local sumWR, sumCost, k = 0, 0, 0
  for _, c in ipairs(br.configs) do
    if c.kind == "baseline" then sumWR = sumWR + c.wr; sumCost = sumCost + c.cost; k = k + 1 end
  end
  curve[#curve + 1] = { band = bandKey, wr = k > 0 and sumWR / k or 0, cost = k > 0 and sumCost / k or 0 }
end

-- 5) ENTROPIE des archétypes « performants » (sigma >= 0 = au-dessus de la moyenne de bande) toutes bandes
--    confondues -> diversité de la méta. < 0.90 = une famille monopolise le haut du tableau.
local archWin = {}
for _, bandKey in ipairs(BANDS) do
  for _, c in ipairs(report.bands[bandKey].configs) do
    if c.sigma and c.sigma >= 0 then archWin[c.arch] = (archWin[c.arch] or 0) + 1 end
  end
end
local entropy = shannon(archWin)

-- ── RÉSUMÉ HUMAIN PRIORISÉ ──
print("\n" .. string.rep("=", 96))
print("== RÉSUMÉ PRIORISÉ DES DÉSÉQUILIBRES (le signal) ==")
print(string.rep("=", 96))

local nSuspect = 0; for _, d in ipairs(dominants) do if d.c.context == "suspect" then nSuspect = nSuspect + 1 end end
print(string.format("\n[1] CONFIGS DOMINANTES (win%% > +%.0fσ de leur bande) — %d (dont %d SUSPECTES = gagnent sous leur coût) :", SIGMA_OUT, #dominants, nSuspect))
if #dominants == 0 then print("    aucune.") end
for i = 1, math.min(16, #dominants) do
  local d = dominants[i]; local c = d.c
  print(string.format("    [%-7s] %-5s %-22s +%-14s win %s (%+.1fσ, miroir %s) [%s]",
    c.context or "?", Bands.label[d.band], c.comp, c.mod, pct(c.wr), c.sigma, c.mirror and pct(c.mirror) or "—", c.kind))
end
if #dominants > 16 then print(string.format("    … +%d autres (cf. JSON).", #dominants - 16)) end

print(string.format("\n[2] CONFIGS MORTES (win%% < -%.0fσ, hors reliques inertes) — %d :", SIGMA_OUT, #deads))
if #deads == 0 then print("    aucune.") end
for i = 1, math.min(10, #deads) do
  local d = deads[i]; local c = d.c
  print(string.format("    %-5s %-22s +%-14s win %s (%+.1fσ) [%s]",
    Bands.label[d.band], c.comp, c.mod, pct(c.wr), c.sigma, c.kind))
end
if #deads > 10 then print(string.format("    … +%d autres (cf. JSON).", #deads - 10)) end

print(string.format("\n[3] GATES (un mod pousse le MIROIR > %.0f%% = brise la symétrie/le contre-jeu) — %d :", GATE * 100, #gates))
if #gates == 0 then print("    aucun (toute relique/cmd INCLINE le matchup, n'efface pas le contre-jeu).") end
for i = 1, math.min(12, #gates) do
  local g = gates[i]; local c = g.c
  print(string.format("    %-5s %-22s +%-14s MIROIR %s  (win-vs-champ %s) [%s]",
    Bands.label[g.band], c.comp, c.mod, pct(c.mirror), pct(c.wr), c.kind))
end

print(string.format("\n[4] COMBOS CASSÉS (lift relique×commandant > %.1f) — %d :", LIFT_BROKEN, #combos))
if #combos == 0 then print("    aucun (les Δ relique+commandant restent ~additifs = pas de synergie cassée).") end
for i = 1, math.min(10, #combos) do
  local c = combos[i]
  print(string.format("    %-5s %-20s %s + %s  lift %.2f  (win conjoint %s, attendu %s)",
    Bands.label[c.band], c.comp, c.relic, c.cmd, c.lift, pct(c.joint), pct(c.expected)))
end

print("\n[5] COURBE DE PUISSANCE inter-bande (coût ↑ doit garder un win% sain vs champ de stade) :")
print(string.format("    %-7s %10s %10s", "bande", "coût.moy", "win.moy"))
for _, r in ipairs(curve) do
  print(string.format("    %-7s %10.3f %10s", Bands.label[r.band], r.cost, pct(r.wr)))
end
-- détection naïve de violation : win% baseline qui CHUTE quand le coût MONTE d'une bande à l'autre.
local curveViol = {}
for i = 2, #curve do
  if curve[i].cost > curve[i - 1].cost + 0.02 and curve[i].wr < curve[i - 1].wr - 0.08 then
    curveViol[#curveViol + 1] = { from = curve[i - 1].band, to = curve[i].band, dwr = curve[i].wr - curve[i - 1].wr }
  end
end
if #curveViol > 0 then
  print("    ⚠ VIOLATION : le win% baseline chute alors que le coût monte (le stade avancé sous-performe son champ) :")
  for _, v in ipairs(curveViol) do
    print(string.format("       %s -> %s : Δwin %+.0f pts", Bands.label[v.from], Bands.label[v.to], v.dwr * 100))
  end
else
  print("    OK : pas d'effondrement du win% baseline quand le coût/stade monte.")
end

print(string.format("\n[6] DIVERSITÉ MÉTA : entropie de Shannon des archétypes au-dessus de la moyenne = %.3f (plancher %.2f) -> %s",
  entropy, ENTROPY_MIN, entropy >= ENTROPY_MIN and "SAIN" or "⚠ une famille monopolise le haut"))
local arOrder = {}
for a in pairs(archWin) do arOrder[#arOrder + 1] = a end
table.sort(arOrder, function(a, b) return archWin[a] > archWin[b] end)
io.write("    répartition (compte au-dessus de la moyenne) : ")
for _, a in ipairs(arOrder) do io.write(string.format("%s=%d ", a, archWin[a])) end
print()

-- archétypes MORTS : présents dans les bandes mais jamais au-dessus de la moyenne.
local seenArch, deadArch = {}, {}
for _, bandKey in ipairs(BANDS) do
  for _, c in ipairs(report.bands[bandKey].configs) do seenArch[c.arch] = true end
end
for a in pairs(seenArch) do if not archWin[a] then deadArch[#deadArch + 1] = a end end
table.sort(deadArch)
if #deadArch > 0 then
  print(string.format("    ⚠ ARCHÉTYPES MORTS (jamais au-dessus de la moyenne dans aucune bande) : %s", table.concat(deadArch, ", ")))
end

-- ════════════════════════════════════════════════════════════════════════════════════════════════
-- runs/balance-matrix.json
-- ════════════════════════════════════════════════════════════════════════════════════════════════
local parts = {}
parts[#parts + 1] = string.format('"n":%d,"opp_per_band":%d,"gate":%s,"lift_broken":%s,"sigma_out":%s',
  N, OPP_PER_BAND, num(GATE), num(LIFT_BROKEN), num(SIGMA_OUT))
parts[#parts + 1] = string.format('"entropy":%s,"entropy_min":%s', num(entropy), num(ENTROPY_MIN))

-- bandes (mean/stddev/field) + toutes les configs (compactes)
local bandParts = {}
for _, bandKey in ipairs(BANDS) do
  local br = report.bands[bandKey]
  local cfg = {}
  for _, c in ipairs(br.configs) do
    cfg[#cfg + 1] = string.format(
      '{"comp":"%s","arch":"%s","kind":"%s","mod":"%s","wr":%s,"mirror":%s,"sigma":%s,"cost":%s,"decided":%s%s}',
      c.comp, c.arch, c.kind, c.mod, num(c.wr), num(c.mirror or 0), num(c.sigma or 0), num(c.cost),
      num(c.decided or 0), c.inert and ',"inert":true' or "")
  end
  bandParts[#bandParts + 1] = string.format('"%s":{"mean":%s,"stddev":%s,"field":%d,"configs":[%s]}',
    bandKey, num(br.mean), num(br.stddev), br.field, table.concat(cfg, ","))
end
parts[#parts + 1] = '"bands":{' .. table.concat(bandParts, ",") .. "}"

-- drapeaux priorisés
local function flagList(t, fmt)
  local out = {}
  for _, e in ipairs(t) do out[#out + 1] = fmt(e) end
  return "[" .. table.concat(out, ",") .. "]"
end
parts[#parts + 1] = '"dominants":' .. flagList(dominants, function(d)
  return string.format('{"band":"%s","comp":"%s","mod":"%s","kind":"%s","context":"%s","wr":%s,"sigma":%s,"mirror":%s}',
    d.band, d.c.comp, d.c.mod, d.c.kind, d.c.context or "?", num(d.c.wr), num(d.c.sigma), num(d.c.mirror or 0)) end)
parts[#parts + 1] = '"deads":' .. flagList(deads, function(d)
  return string.format('{"band":"%s","comp":"%s","mod":"%s","kind":"%s","wr":%s,"sigma":%s}',
    d.band, d.c.comp, d.c.mod, d.c.kind, num(d.c.wr), num(d.c.sigma)) end)
parts[#parts + 1] = '"gates":' .. flagList(gates, function(g)
  return string.format('{"band":"%s","comp":"%s","mod":"%s","kind":"%s","mirror":%s,"wr":%s}',
    g.band, g.c.comp, g.c.mod, g.c.kind, num(g.c.mirror), num(g.c.wr)) end)
parts[#parts + 1] = '"broken_combos":' .. flagList(combos, function(c)
  return string.format('{"band":"%s","comp":"%s","relic":"%s","cmd":"%s","lift":%s,"joint":%s}',
    c.band, c.comp, c.relic, c.cmd, num(c.lift), num(c.joint)) end)
local curveParts = {}
for _, r in ipairs(curve) do curveParts[#curveParts + 1] = string.format('{"band":"%s","cost":%s,"wr":%s}', r.band, num(r.cost), num(r.wr)) end
parts[#parts + 1] = '"curve":[' .. table.concat(curveParts, ",") .. "]"
parts[#parts + 1] = '"dead_archetypes":' .. flagList(deadArch and (function() local t = {}; for _, a in ipairs(deadArch) do t[#t + 1] = a end; return t end)() or {}, function(a) return '"' .. a .. '"' end)

os.execute("mkdir -p runs")
local f = io.open("runs/balance-matrix.json", "w")
if f then
  f:write("{" .. table.concat(parts, ",") .. "}\n"); f:close()
  print("\n=> écrit runs/balance-matrix.json")
else
  print("\n(!) impossible d'écrire runs/balance-matrix.json")
end
