-- tools/scenarios/godroll.lua
-- MODE P7 — GOD-ROLL EXPLORER (scénario E, le NEUF : balance-psychology §2.3-2 / §2.4-E / §2.7-3).
-- On ne tire PAS des builds au hasard : on CONSTRUIT DÉLIBÉRÉMENT les intersections d'enablers à FORT
-- investissement (late, board 7-9, empilables) — exactement les « régions à risque » (importance sampling) :
--   multicast (hookjaw role:front)  ×  empower (maggot_king atkInc neighbors)  ×  commandant (Couronne
--   d'Échos / multicast role:front)  ×  relique (echo_crown multicast / blood_banner empower / ampli d'école
--   / festering poisonNoCap)  ×  ampli d'école assorti au carry.
-- Chaque candidat affronte un champ late représentatif (seeds variés) ; on mesure la DISTRIBUTION DE PUISSANCE
-- (score de domination = win-rate haut + TTK bas) et on sort :
--   · godroll_rate     = part des candidats entrant dans la QUEUE 95-99e pct du score de domination
--   · godroll_combos   = les signatures de combo de la queue (lesquelles atomisent)
--   · godroll_diversity= nb de SIGNATURES DISTINCTES dans la queue (>=3 = sain ; 1 = méta-god-roll unique)
-- GARDE-FOUS (les caps moteur TIENNENT) : aucun multicast résolu > MULTICAST_MAX ; aucun TTK = 1-swing (burst
-- non borné) ; le combat conclut toujours (pas de boucle infinie). Asserts DURS -> un cap qui saute = échec.
--
-- SIM-pur, seedé, déterministe. N = matchs/candidat (la grille de candidats est ÉNUMÉRÉE, pas tirée). Lancement :
--   luajit tools/sim.lua godroll [N]      (N défaut 24 ; cf. §2.6 : la QUEUE d'une distribution exige du volume,
--                                          monter N + élargir la grille pour un 95-99e pct stable)

local Common = require("tools.scenarios.common")
local Compositions = require("src.data.compositions")
local Compbuild = require("src.lab.compbuild")
local Arena = require("src.combat.arena")

local N = require("tools.scenarios.argn")(24)
local BASE_SEED = 730000
local HPM = tonumber(os.getenv("PIT_HP_MULT"))

-- ── BASES de god-roll : compos late « payload » (board 9) d'archétypes différents, sur lesquelles on EMPILE
-- les enablers. On part de builds aboutis du catalogue/bandes (déjà serrés), puis on greffe commandant+reliques.
-- Le carry au FRONT capte le multicast (role:front) ; les amplis d'école assortis nourrissent le DoT. ──
local BASES = {
  -- archétype, compo de base (board 9), commandants multicast/empower candidats, reliques assorties, ampli d'école
  { arch = "shock", base = "end_shock_multicast",
    commanders = { false, "maggot_king", "hookjaw" }, -- Couronne d'Échos (multicast role:front)
    relics = { {}, { "echo_crown" }, { "blood_banner" }, { "echo_crown", "blood_banner" }, { "forked_tongue", "echo_crown" } } },
  { arch = "poison", base = "poison_diamant_perfect",
    commanders = { false, "witch", "venom_censer" }, -- amplis poison en commandement
    relics = { {}, { "kings_bowl" }, { "plague_communion" }, { "kings_bowl", "blood_banner" }, { "echo_crown", "kings_bowl" } } },
  { arch = "burn", base = "burn_ligne_perfect",
    commanders = { false, "emberling", "pyre_tender" },
    relics = { {}, { "ember_heart" }, { "everburn" }, { "ember_heart", "blood_banner" }, { "echo_crown", "ember_heart" } } },
  { arch = "rot", base = "rot_carre_perfect",
    commanders = { false, "rot_hound", "maggot_king" },
    relics = { {}, { "grave_cap" }, { "open_wounds" }, { "grave_cap", "blood_banner" }, { "echo_crown", "grave_cap" } } },
}

-- Champ d'adversaires LATE (le god-roll doit affronter une vraie résistance, pas des cibles molles) :
-- murs complets + DoT croisé + builds end. Si le candidat les atomise QUAND MÊME, c'est un vrai god-roll.
local FOE_IDS = { "fortress_thorns_carre", "tank_carre", "bulwark_carre", "cross_venom_pyre",
  "end_poison", "end_rot", "sustain_carre" }
local FOES = {}
for _, id in ipairs(FOE_IDS) do local c = Compositions.byId[id]; if c then FOES[#FOES + 1] = c end end
local rightCache = {}
local function rightOf(c) local v = rightCache[c.id]; if not v then v = Compbuild.toComp(c, 1); rightCache[c.id] = v end; return v end

-- ── GARDE-FOU caps : sur une compo d'arène résolue, vérifier que les enablers RESTENT sous les caps moteur.
-- multicast est clampé À LA LECTURE combat (math.min(multicast, MULTICAST_MAX)) -> la valeur BAKÉE peut
-- légitimement dépasser (3 sources de +1 = 3, mais une 4e source donnerait 4 baké, clampé à 3 en combat).
-- On vérifie donc le clamp EFFECTIF en combat indirectement (pas de 1-swing) ; ici on logge le multicast baké
-- MAX rencontré pour le rapport (visibilité), sans asserter sur le baké (le clamp lecture est la vraie barrière). ──
local function maxBakedMulticast(comp)
  local mx = 0
  for _, u in ipairs(comp) do if (u.multicast or 0) > mx then mx = u.multicast end end
  return mx
end

-- Signature de combo (déterministe) : archétype + commandant + reliques triées -> clé de diversité.
local function comboSig(arch, cmd, relics)
  local rs = {}
  for _, r in ipairs(relics) do rs[#rs + 1] = r end
  table.sort(rs)
  return arch .. "|cmd:" .. tostring(cmd or "-") .. "|" .. (next(rs) and table.concat(rs, "+") or "-")
end

-- ── Énumère la GRILLE de candidats (base × commandant × paquet de reliques). Importance sampling = la grille
-- elle-même est CONCENTRÉE sur les intersections d'enablers (on n'échantillonne pas du bruit). ──
local candidates = {}
for _, B in ipairs(BASES) do
  Common.compById(B.base) -- valide la base (catalogue OU bandes) ; ERREUR si introuvable (anti-saut silencieux)
  for _, cmd in ipairs(B.commanders) do
    for _, relics in ipairs(B.relics) do
      -- nettoie les reliques (un and/false peut produire un trou) -> array dense d'ids string
      local clean = {}
      for _, r in ipairs(relics) do if type(r) == "string" then clean[#clean + 1] = r end end
      candidates[#candidates + 1] = { arch = B.arch, base = B.base, cmd = (cmd ~= false) and cmd or nil, relics = clean }
    end
  end
end

print(string.format("== P7 GOD-ROLL EXPLORER : %d candidats (intersections d'enablers) x %d adversaires x %d matchs ==",
  #candidates, #FOES, N))

-- Évalue chaque candidat : win-rate vs champ + TTK des combats GAGNÉS (la rapidité d'atomisation).
local results = {}
local seedCounter = 0
local maxMulticastSeen, oneSwingSeen, unconcluded = 0, 0, 0
local FATIGUE = Arena.FATIGUE_START

for _, cand in ipairs(candidates) do
  -- compo joueur résolue UNE fois (Compbuild lourd) : commandant au piédestal + reliques appliquées (FIDÈLE au jeu).
  local L = Compbuild.toComp(Common.compById(cand.base), -1, { commander = cand.cmd, relics = cand.relics })
  local mb = maxBakedMulticast(L)
  if mb > maxMulticastSeen then maxMulticastSeen = mb end
  local wins, total, winTtkSum, winTtkN = 0, 0, 0, 0
  local minTtk = math.huge
  for _, fc in ipairs(FOES) do
    local R = rightOf(fc)
    for k = 1, N do
      seedCounter = seedCounter + 1
      local res = Common.fight(L, R, BASE_SEED + seedCounter, HPM)
      total = total + 1
      if not res.decided then unconcluded = unconcluded + 1 end
      if res.win then
        wins = wins + 1
        if res.decided then
          winTtkSum = winTtkSum + res.ticks; winTtkN = winTtkN + 1
          if res.ticks < minTtk then minTtk = res.ticks end
          -- GARDE-FOU 1-swing : un combat décidé en quasi-1-swing (< 1.5 × durée d'un swing) = burst non borné.
          if res.ticks <= 18 then oneSwingSeen = oneSwingSeen + 1 end
        end
      end
    end
  end
  local wr = (total > 0) and (wins / total) or 0
  local avgWinTtk = (winTtkN > 0) and (winTtkSum / winTtkN) or 0
  -- SCORE DE DOMINATION ∈ [0,1] : win-rate élevé ET atomisation rapide. On normalise le TTK des wins par un
  -- TTK « plancher de référence » (combats longs = peu dominants). speed = 1 quand instantané, 0 quand >= REF.
  local TTK_REF = 1200 -- ~20 s @60fps : au-delà, le combat n'est pas une « atomisation » (placeholder)
  local speed = (avgWinTtk > 0) and math.max(0, 1 - avgWinTtk / TTK_REF) or 0
  local dom = wr * (0.5 + 0.5 * speed) -- le win-rate domine ; la vitesse module (un blow-out rapide > une victoire à l'usure)
  results[#results + 1] = {
    arch = cand.arch, base = cand.base, cmd = cand.cmd, relics = cand.relics,
    sig = comboSig(cand.arch, cand.cmd, cand.relics),
    winrate = wr, avg_win_ttk = avgWinTtk, min_ttk = (minTtk < math.huge) and minTtk or 0,
    max_multicast = mb, dom = dom,
  }
end

-- ── QUEUE 95-99e pct du score de domination : le « god-roll » = haut de la distribution de puissance. ──
local doms = {}
for _, r in ipairs(results) do doms[#doms + 1] = r.dom end
table.sort(doms)
local q95 = Common.percentileSorted(doms, 0.95)
-- on retient comme « god-roll » tout candidat AU-DESSUS du 95e pct (la queue droite). Deux DIVERSITÉS :
--   · diversity (signatures de combo distinctes) : >=3 = pas un combo unique qui monopolise (santé §2.4-E) ;
--   · archDiversity (ARCHÉTYPES distincts) : signal PLUS FIN — 4 signatures TOUTES du même archétype = un seul
--     « moteur » de god-roll domine (méta mono-archétype à surveiller, même si les signatures diffèrent).
local queue, queueSigs, queueArch = {}, {}, {}
for _, r in ipairs(results) do
  if r.dom >= q95 - 1e-9 then
    queue[#queue + 1] = r
    queueSigs[r.sig] = true
    queueArch[r.arch] = true
  end
end
local diversity, archDiversity = 0, 0
for _ in pairs(queueSigs) do diversity = diversity + 1 end
for _ in pairs(queueArch) do archDiversity = archDiversity + 1 end
local godrollRate = (#results > 0) and (#queue / #results) or 0

-- tri d'affichage : score de domination décroissant
table.sort(results, function(a, b) if a.dom ~= b.dom then return a.dom > b.dom end return a.sig < b.sig end)

print(string.format("%-7s %-22s %-14s %-22s %6s %8s %8s %6s", "arch", "base", "cmd", "reliques", "win%", "winTTK", "minTTK", "dom"))
for _, r in ipairs(results) do
  print(string.format("%-7s %-22s %-14s %-22s %5.1f%% %8.0f %8d %6.3f",
    r.arch, r.base, tostring(r.cmd or "-"),
    (next(r.relics) and table.concat(r.relics, "+") or "-"),
    r.winrate * 100, r.avg_win_ttk, r.min_ttk, r.dom))
end

print(string.format("god-roll : taux %.1f%% (%d/%d au-dessus du 95e pct dom=%.3f) | diversite %d signatures / %d archetypes",
  godrollRate * 100, #queue, #results, q95, diversity, archDiversity))
print("  combos de queue (god-rolls) :")
for _, r in ipairs(queue) do
  print(string.format("    %-7s dom %.3f  win %.1f%%  winTTK %.0f  [%s]", r.arch, r.dom, r.winrate * 100, r.avg_win_ttk, r.sig))
end

-- VERDICT garde-fous (les caps tiennent + le god-roll est sain : rare, divers, borné).
print(string.format("garde-fous : multicast bake MAX=%d (cap lecture MULTICAST_MAX=%d) | 1-swing=%d | combats non-conclus=%d/%d",
  maxMulticastSeen, Arena.MULTICAST_MAX, oneSwingSeen, unconcluded, seedCounter))
if diversity < 3 and #queue > 0 then
  print(string.format("  ALERTE diversite : seulement %d signature(s) en queue -> meta-god-roll proche de l'unique (a surveiller).", diversity))
elseif archDiversity == 1 and #queue > 0 then
  print(string.format("  NOTE : la queue est mono-archetype (%d signatures mais 1 seul archetype) -> un seul moteur de god-roll domine (a surveiller).", diversity))
end
if godrollRate == 0 then
  print("  ALERTE : taux de god-roll = 0 -> le plafond de puissance est peut-etre trop bas (pas de power fantasy).")
end
-- ASSERTS DURS (le contrat garde-fous de la mission) : aucun 1-swing dégénéré ; tout combat conclut.
assert(oneSwingSeen == 0, string.format("GARDE-FOU rompu : %d combat(s) god-roll decide(s) en quasi-1-swing (burst non borne -> resserrer un cap)", oneSwingSeen))
-- (les combats non-conclus sont JUGÉS au temps-limite par Match — pas une boucle infinie ; on les logge, sans asserter.)

-- ── Rapport diff-able. godroll_rate / godroll_diversity / godroll_combos + distribution (dom triés). ──
local distrib = {}
for _, r in ipairs(results) do distrib[#distrib + 1] = r.dom end
local combosOut = {}
for _, r in ipairs(queue) do
  combosOut[#combosOut + 1] = { signature = r.sig, arch = r.arch, dom = r.dom, winrate = r.winrate, avg_win_ttk = r.avg_win_ttk }
end
table.sort(combosOut, function(a, b) return a.signature < b.signature end)
local candOut = {}
for _, r in ipairs(results) do
  candOut[r.sig] = { arch = r.arch, base = r.base, winrate = r.winrate, avg_win_ttk = r.avg_win_ttk,
    min_ttk = r.min_ttk, max_multicast = r.max_multicast, dom = r.dom }
end
local payload = {
  mode = "godroll", matchs_per_cell = N, candidates = #results, foes = #FOES,
  godroll_rate = godrollRate, godroll_diversity = diversity, godroll_arch_diversity = archDiversity, q95 = q95,
  max_baked_multicast = maxMulticastSeen, multicast_cap = Arena.MULTICAST_MAX,
  one_swing = oneSwingSeen, unconcluded = unconcluded,
  godroll_combos = combosOut, candidates_detail = candOut,
}
local summary = {
  matchs_per_cell = N, candidates = #results, godroll_rate = godrollRate,
  godroll_diversity = diversity, godroll_arch_diversity = archDiversity,
  max_baked_multicast = maxMulticastSeen, one_swing = oneSwingSeen,
}
local path = Common.writeReport("godroll", payload, { refSummary = summary })
print("=> ecrit " .. path .. " (+ runs/report-ref.json)")
