-- tests/scenarios.lua
-- MOTEUR DE SCÉNARIOS d'équilibrage (Phase C.0) — garde-fous :
--   1. COMMON : DESIGNED (counters intentionnels) + invest (Compcost) + résolution catalogue/bandes +
--      percentile + archetypeOf + JSON diff-able (clés triées).
--   2. SMOKE de chaque MODE (invest/policy/godroll/commander/counter/economy/tank/pacing/sweep/coherence/bossrush/bossrush_run) à N MINIMAL via le driver unifié
--      (luajit tools/sim.lua <mode> 1) : tourne sans crash, écrit son report-<mode>.json (JSON parsable),
--      et le P7 god-roll RESPECTE ses garde-fous (caps moteur : multicast bake <= cap, zéro 1-swing -> assert
--      DUR dans le mode lui-même ; si un cap sautait, le smoke échouerait avec exit!=0).
--   3. DÉTERMINISME : un mode relancé à même N produit un rapport IDENTIQUE (règle d'or).
-- Lancement : luajit tests/scenarios.lua
package.path = "./?.lua;" .. package.path
love = require("tests.mock_love")

local Common = require("tools.scenarios.common")

-- Décodeur JSON minimal pour vérifier que nos rapports sont PARSABLES (on ne dépend d'aucune lib : nos
-- rapports sont produits par tools/gamed/json, bien formés ; ce mini-parser valide la structure top-level).
local function jsonLooksObject(s)
  s = (s or ""):gsub("^%s+", "")
  return s:sub(1, 1) == "{" and s:find("}") ~= nil
end

local ok, err = pcall(function()
  -- 1) COMMON ─────────────────────────────────────────────────────────────────────────────────────────
  -- DESIGNED : counters INTENTIONNELS (poison/burn/rot/shock>tank, bleed>bruiser, tank>bruiser).
  assert(Common.isDesigned("poison", "tank"), "DESIGNED: poison>tank")
  assert(Common.isDesigned("burn", "tank"), "DESIGNED: burn>tank")
  assert(Common.isDesigned("rot", "tank"), "DESIGNED: rot>tank")
  assert(Common.isDesigned("shock", "tank"), "DESIGNED: shock>tank")
  assert(Common.isDesigned("bleed", "bruiser"), "DESIGNED: bleed>bruiser")
  assert(Common.isDesigned("tank", "bruiser"), "DESIGNED: tank>bruiser")
  assert(not Common.isDesigned("bleed", "tank"), "DESIGNED: bleed>tank N'EST PAS un counter voulu (flaguable)")
  assert(not Common.isDesigned("poison", "shield"), "DESIGNED: poison>shield N'EST PAS un counter voulu")

  -- Résolution catalogue ET bandes (le bug qui faisait disparaître les candidats shock du god-roll explorer).
  local cat = Common.compById("poison_diamant_perfect") -- catalogue
  assert(cat and #cat.units >= 1, "compById: compo de catalogue resolue")
  local band = Common.compById("end_shock_multicast")   -- BANDE (pas le catalogue)
  assert(band and #band.units >= 1, "compById: compo de bande resolue (pas seulement le catalogue)")
  local okErr = pcall(Common.compById, "id_qui_n_existe_pas_xyz")
  assert(not okErr, "compById: id inconnu -> ERREUR (anti-saut silencieux)")
  assert(Common.compByIdOrNil("id_qui_n_existe_pas_xyz") == nil, "compByIdOrNil: id inconnu -> nil")

  -- Investissement (Compcost) : descripteur complet, score borné, or > 0 sur une vraie compo.
  local inv = Common.invest(cat)
  assert(inv.score > 0 and inv.score <= 1.0001, "invest: score dans (0,1]")
  assert(inv.gold > 0, "invest: or > 0 sur une compo peuplee")

  -- archetypeOf : champ déclaré prioritaire, sinon vote des unités.
  assert(Common.archetypeOf({ archetype = "poison", units = {} }) == "poison", "archetypeOf: champ declare")
  assert(Common.archetypeOf({ units = { { id = "spore_tick" }, { id = "bile_spitter" } } }) == "poison",
    "archetypeOf: vote des unites (poison)")

  -- percentile (échantillon trié) : bornes + médiane.
  local s = { 1, 2, 3, 4, 5, 6, 7, 8, 9, 10 }
  assert(Common.percentileSorted(s, 0) == 1, "percentile: q=0 -> min")
  assert(Common.percentileSorted(s, 1.0) == 10, "percentile: q=1 -> max")
  assert(Common.percentileSorted({}, 0.5) == 0, "percentile: vide -> 0")
  assert(math.abs(Common.mean({ 2, 4, 6 }) - 4) < 1e-9, "mean: moyenne correcte")

  -- JSON diff-able : clés TRIÉES (réutilise tools/gamed/json) -> rapports stables au diff.
  assert(Common.json.encode({ b = 2, a = 1 }) == '{"a":1,"b":2}', "json: cles triees (diff-able)")
  print("  scenarios : COMMON OK (DESIGNED + invest + resolution catalogue/bandes + percentile + json trie)")

  -- 2) SMOKE de chaque MODE via le driver unifie (N minimal=1) ───────────────────────────────────────────
  -- On lance chaque mode dans un sous-process luajit (comme l'utilisateur) ; code retour 0 = pas de crash
  -- ET (pour god-roll) garde-fous tenus (le mode asserte ses caps -> exit!=0 si un cap saute). On vérifie
  -- aussi que le report-<mode>.json est produit et ressemble a un objet JSON.
  -- ⚠️ ISOLATION : on redirige la sortie vers runs/_test (PIT_SCEN_OUT) pour NE PAS écraser le golden de
  -- méta de référence (runs/report-ref.json) avec des rapports à N=1. Dossier jetable, nettoyé en fin de test.
  local OUT = "runs/_test"
  local ENV = "PIT_SCEN_OUT=" .. OUT .. " "
  os.execute("rm -rf " .. OUT .. " && mkdir -p " .. OUT)
  local MODES = { "invest", "policy", "godroll", "commander", "counter", "economy", "tank", "pacing", "sweep", "coherence", "bossrush", "bossrush_run" }
  for _, m in ipairs(MODES) do
    local extraEnv = ""
    if m == "bossrush" then
      extraEnv = "PIT_BOSSRUSH_COMPS=bruiser_carre PIT_ABOMINATIONS=leviathan "
    elseif m == "bossrush_run" then
      extraEnv = "PIT_POLICIES=greedy_stats PIT_BOSSRUSH_RUN_ECONOMIES=baseline PIT_ABOMINATIONS=leviathan PIT_BOSSRUSH_RUN_ELIGIBILITY=all "
    elseif m == "economy" then
      extraEnv = "PIT_OPPONENT_MODE=generated PIT_PLAN_TARGETS=rot_bleed_rat_core PIT_PLAN_TARGET_SPECS='spec_support=rot_hound:1;relics=grave_cap;commander=clot_mender:2;board=3' "
    end
    local code = os.execute(ENV .. extraEnv .. "luajit tools/sim.lua " .. m .. " 1 >/dev/null 2>&1")
    -- os.execute renvoie true (5.2+) ou 0 (5.1) au succes ; on accepte les deux conventions.
    assert(code == 0 or code == true, "mode " .. m .. " : driver tourne sans crash (exit 0)")
    local f = io.open(OUT .. "/report-" .. m .. ".json", "r")
    assert(f, "mode " .. m .. " : report-" .. m .. ".json produit")
    local body = f:read("*a"); f:close()
    assert(jsonLooksObject(body), "mode " .. m .. " : report-" .. m .. ".json est un objet JSON")
    if m == "coherence" then
      assert(body:find("__leveled", 1, true),
        "mode coherence : variantes levelees produites pour les compos fixes")
      assert(body:find("__filled", 1, true),
        "mode coherence : variantes remplies produites pour les noyaux sous-remplis")
      assert(body:find('"id":"marrow_drinker","level":3', 1, true),
        "mode coherence : variante levelee peut prioriser le pivot bleed->rot")
      assert(body:find('"filled_from":"cross_bleed_rot"', 1, true),
        "mode coherence : cross_bleed_rot peut etre teste avec fillers naturels")
      assert(body:find('"filled_resolutions"', 1, true),
        "mode coherence : les noyaux sous-remplis ont un diagnostic de resolution par fillers")
      assert(body:find('"foe_breakdown"', 1, true),
        "mode coherence : chaque ligne expose le diagnostic par adversaire")
      assert(body:find('"rank_pressure"', 1, true),
        "mode coherence : chaque ligne expose la pression d'acces par rang")
      assert(body:find('"duplicate_pressure"', 1, true),
        "mode coherence : chaque ligne expose la pression de copies")
    elseif m == "economy" then
      assert(body:find('"plan_access"', 1, true),
        "mode economy : accessibilite des plans cibles reportee")
      assert(body:find('"first_held_level_round"', 1, true),
        "mode economy : trajectoire d'accessibilite des plans reportee")
      assert(body:find('"combat_by_board_level_band"', 1, true),
        "mode economy : combat par bande de couverture de plan reporte")
      assert(body:find('"forced_winrate"', 1, true),
        "mode economy : oracle combat force des plans cibles reporte")
      assert(body:find('"acquisition_funnel"', 1, true),
        "mode economy : funnel acquisition des plans cibles reporte")
      assert(body:find('"support_access"', 1, true),
        "mode economy : accessibilite des supports reliques/commandants reportee")
      assert(body:find('"focused_offer_run_rate"', 1, true),
        "mode economy : offres de reliques focus reportees")
      assert(body:find('"focused_candidate_run_rate"', 1, true),
        "mode economy : candidats commandants focus reportes")
      assert(body:find('"xp_gate_blocks_per_run"', 1, true),
        "mode economy : blocages de barriere XP reportes")
      assert(body:find('"sold_before_merge_rate"', 1, true),
        "mode economy : pertes de paires par vente reportees")
      assert(body:find('"terminal_causes"', 1, true),
        "mode economy : causes terminales des paires non resolues reportees")
      assert(body:find('"third_copy_access"', 1, true),
        "mode economy : accessibilite de la troisieme copie reportee")
      assert(body:find('"pair_support_offers_per_run"', 1, true),
        "mode economy : offres support de paire reportees")
      assert(body:find('"spec_support"', 1, true)
        and body:find('"relics":["grave_cap"]', 1, true)
        and body:find('"commander":"clot_mender"', 1, true),
        "mode economy : PIT_PLAN_TARGET_SPECS accepte relics+commander dans oracle")
    elseif m == "pacing" then
      assert(body:find('"duration_fit"', 1, true),
        "mode pacing : score de fit duration reporte")
      assert(body:find('"duration_fit_score"', 1, true),
        "mode pacing : score de fit duration expose dans le resume")
    elseif m == "sweep" then
      assert(body:find('"duration_fit"', 1, true),
        "mode sweep : score de fit duration reporte")
      assert(body:find('"duration_fit_score"', 1, true),
        "mode sweep : score de fit duration expose dans le resume")
      assert(body:find('"recommendations"', 1, true),
        "mode sweep : recommandations de pacing/economie reportees")
      assert(body:find('"selection_score"', 1, true),
        "mode sweep : score de selection des recommandations reporte")
    elseif m == "bossrush" then
      assert(body:find('"boss_score_damage"', 1, true),
        "mode bossrush : score de degats boss reporte")
      assert(body:find('"cleared_blockers"', 1, true),
        "mode bossrush : nettoyage des generaux reporte")
      assert(body:find('"recommendations"', 1, true),
        "mode bossrush : recommandations/warnings reportes")
    elseif m == "bossrush_run" then
      assert(body:find('"finalSupportedBoard"', 1, true) == nil,
        "mode bossrush_run : pas de dump interne verbeux dans le rapport")
      assert(body:find('"score_damage_per_run"', 1, true),
        "mode bossrush_run : score PvE par run reporte")
      assert(body:find('"entry_rate"', 1, true),
        "mode bossrush_run : taux d'entree postgame reporte")
      assert(body:find('"economy_policy"', 1, true),
        "mode bossrush_run : matrice economie/politique reportee")
    end
  end
  print("  scenarios : SMOKE OK (12 modes tournent via le driver + ecrivent un rapport JSON ; garde-fous god-roll tenus)")

  -- Alias ergonomiques du sweep : les noms dedies doivent filtrer le grid comme les noms generiques.
  local sweepAliasCode = os.execute(ENV ..
    "PIT_SWEEP_ECONOMIES=baseline PIT_SWEEP_PACES=hp2_cd15_f24 luajit tools/sim.lua sweep 1 >/dev/null 2>&1")
  assert(sweepAliasCode == 0 or sweepAliasCode == true, "sweep aliases : driver tourne sans crash")
  local sf = io.open(OUT .. "/report-sweep.json", "r")
  assert(sf, "sweep aliases : report-sweep.json produit")
  local sweepBody = sf:read("*a"); sf:close()
  assert(sweepBody:find('"baseline"', 1, true), "sweep aliases : economie baseline incluse")
  assert(sweepBody:find('"hp2_cd15_f24"', 1, true), "sweep aliases : pace hp2_cd15_f24 incluse")
  assert(not sweepBody:find('"sap_cost"', 1, true), "sweep aliases : economies non demandees filtrees")
  assert(not sweepBody:find('"live_hp2_cd1_f17"', 1, true), "sweep aliases : paces non demandees filtrees")
  print("  scenarios : SWEEP ALIASES OK (PIT_SWEEP_ECONOMIES/PACES filtrent le grid)")

  -- 3) DÉTERMINISME : un mode relance a meme N -> rapport IDENTIQUE (regle d'or). On teste le plus rapide.
  os.execute(ENV .. "luajit tools/sim.lua godroll 1 >/dev/null 2>&1")
  local r1 = io.open(OUT .. "/report-godroll.json"):read("*a")
  os.execute(ENV .. "luajit tools/sim.lua godroll 1 >/dev/null 2>&1")
  local r2 = io.open(OUT .. "/report-godroll.json"):read("*a")
  assert(r1 == r2, "determinisme: meme mode+N -> rapport identique")
  print("  scenarios : DETERMINISME OK (godroll relance a meme N -> rapport bit-identique)")

  -- 4) GOLDEN DE META : l'agregat report-ref.json est ecrit (dans le dossier isole) et ressemble a un objet.
  local rf = io.open(OUT .. "/report-ref.json", "r")
  assert(rf, "golden de meta: report-ref.json agrege ecrit")
  local ref = rf:read("*a"); rf:close()
  assert(jsonLooksObject(ref), "golden de meta: report-ref.json est un objet JSON")
  os.execute("rm -rf " .. OUT) -- nettoie le dossier jetable (le runs/report-ref.json de reference reste intact)
  print("  scenarios : GOLDEN DE META OK (report-ref.json agrege, diff-able ; isole de la reference)")
end)

if ok then
  print("=> SCENARIOS OK : moteur de scenarios (common + 12 modes + determinisme + golden de meta).")
else
  print("=> SCENARIOS FAIL :")
  print(err)
  os.exit(1)
end
