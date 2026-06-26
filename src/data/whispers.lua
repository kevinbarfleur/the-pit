-- src/data/whispers.lua
-- LES MURMURES (3e couche CACHÉE — du SPICE, jamais build-defining ; easter-egg). cf. docs/research/murmures-plan.md.
--
-- Registre DÉCLARATIF PUR : `id_unité -> { liste de murmures }`. Chaque murmure est une table LITTÉRALE
-- au format d'un effet du roster (`{trigger, op, params, condition?}`) + 4 champs propres au système :
--   kind    = "lineage" (duo : un partenaire renforce le porteur) | "solo" (conditionnel sur le porteur)
--   key     = clé i18n du phrasé cryptique (canal joueur) : `whisper.<key>.cryptic` (ZÉRO chiffre)
--   partner = id de l'allié-déclencheur (lineage) | nil (solo) ; sert au phrasé ({y}) et au scan présence
--   verb    = catégorie de phrasé (fallback du canal joueur) ; jamais affiché en clair par défaut
--
-- ⚠️ FICHIER DATA-PURE — AUCUNE logique : ni fonction, ni RNG, ni appel au framework. CE NE SONT QUE
-- DES TABLES. TOUTE la logique (résolution présence/adjacence/seuil/position, pose de l'effet BORNÉ,
-- émission de l'event `murmur`) vit dans les OPS `whisper_lineage` / `whisper_solo`
-- (src/effects/whispers_ops.lua, sous firewall SIM). Le lint CI (tools/check.sh) garantit
-- mécaniquement cette pureté en interdisant tout mot-clé de logique dans ce fichier (plan §6).
--
-- BORNES (le contrat, plan §0) : `stat_inc` ≤ 0.10 (10% en `increased` additif, K1/K2) OU 1 `oneshot`.
-- Le cumul borné (`husk`) plafonne via `capStacks`. Seul le créateur connaît les vraies valeurs.
--
-- GOLDEN-NEUTRE PAR CONSTRUCTION : aucun id du SCÉNARIO GOLDEN (templar/marauder/skeleton/witch/demon)
-- ne porte de murmure -> zéro émission dans la trace golden (cf. tests/golden.lua). DIVERGENCE assumée
-- avec le plan §3 : exemplar #1 ré-ancré du couple `demon`+`witch` (tous deux dans le golden) vers
-- `ink_horror`+`deep_kraken` (mêmes abysses, hors golden) pour respecter la contrainte W5. cf. report.
--
-- SNAPSHOT GRATUIT (plan §5) : résolus PAR `id` au combat_start (voie A, merge dans l'arène), donc un
-- GHOST (qui ne transporte que {id, level, col, row} via Snapshot.toComp) re-déclenche ses murmures
-- NON-RNG sans rien encoder de neuf — exactement comme `corruptor` déclenche son `grant_vuln`.

return {
  -- 1. THE LURE AND THE BROOD (lignée) — INK HORROR renforcé par la présence du DEEP KRAKEN. L'encre du
  -- léviathan abyssal guide la portée : appât/prédateur, pas de pacte magique (re-ancrage canon, plan §3).
  ink_horror = {
    { kind = "lineage", key = "the_lure_and_the_brood", partner = "deep_kraken",
      trigger = "combat_start", op = "whisper_lineage",
      params = { needPartner = "deep_kraken", reach = "presence",
                 effect = { kind = "stat_inc", stat = "atkInc", value = 0.10 } }, -- +10% dégâts sortants (K2)
      verb = "strikes truer" },
  },

  -- 2. THE FORGE CIRCLE (lignée, adjacence) — THE EMBER HIEROPHANT + THE KINDLING-STORK : le sermon de
  -- cendre attise le bûcher patient. ONE-SHOT : la 1re brûlure posée part plus intense (consommé 1×).
  cinder_cur = {
    { kind = "lineage", key = "the_forge_circle", partner = "pyre_tender",
      trigger = "combat_start", op = "whisper_lineage",
      params = { needPartner = "pyre_tender", reach = "adjacency",
                 effect = { kind = "oneshot", field = "burnInc", value = 0.10 } }, -- 1 ampli de feu, consommé
      verb = "burns hotter" },
  },

  -- 3. THE BROOD BELOW (lignée) — la couvée (ici CORRUPTOR) frappe avec une assurance neuve quand le
  -- DEEP KRAKEN veille. Présence du kraken -> statInc +10% (stats globales, baké comme statInc).
  corruptor = {
    { kind = "lineage", key = "the_brood_below", partner = "deep_kraken",
      trigger = "combat_start", op = "whisper_lineage",
      params = { needPartner = "deep_kraken", reach = "presence",
                 effect = { kind = "stat_inc", stat = "statInc", value = 0.10 } },
      verb = "stands surer" },
  },

  -- 4. THE THREE SKULLS (lignée, présence d'un feu) — THE THREE-HEADED PYRE partage sa fournaise : toute
  -- flamme alentour brûle plus noir. needFamily="burn" : présence d'un ALLIÉ qui pose de la brûlure.
  soot_acolyte = {
    { kind = "lineage", key = "the_three_skulls", partner = nil,
      trigger = "combat_start", op = "whisper_lineage",
      params = { needFamily = "burn", reach = "presence",
                 effect = { kind = "stat_inc", stat = "burnInc", value = 0.10 } }, -- ampli DoT existant (cappé ×3)
      verb = "burns blacker" },
  },

  -- 5. THE KINDRED MACHINES (lignée, adjacence) — WARDSTONE SENTINEL + THE STOKED HUSK : les rouages
  -- s'alignent. dmgReduce +0.08 (armure plate, K1) : -8% dégâts d'ATTAQUE subis.
  bulwark_acolyte = {
    { kind = "lineage", key = "the_kindred_machines", partner = "footman",
      trigger = "combat_start", op = "whisper_lineage",
      params = { needPartner = "footman", reach = "adjacency",
                 effect = { kind = "stat_inc", stat = "dmgReduce", value = 0.08 } },
      verb = "stands firm" },
  },

  -- 6. THE GORGING (solo, seuil PV) — HOLLOW GUT s'ouvre une bouche de plus à l'agonie et se repaît.
  -- on_low_hp (~30%) -> lifestealBonus +10% (champ additif inerte, lu par l'op lifesteal). Pas de chance.
  hollow_gut = {
    { kind = "solo", key = "the_gorging", partner = nil,
      trigger = "on_low_hp", op = "whisper_solo",
      params = { threshold = 0.30, effect = { kind = "stat_inc", stat = "lifestealBonus", value = 0.10 } },
      verb = "gorges" },
  },

  -- 7. THE HOLLOW VESSEL (solo, mort d'allié) — HUSK se gorge du défunt et se tient plus droit. Cumul
  -- BORNÉ (cap 4) : dmgInc +5% par mort alliée, ré-appliqué sur la base mémorisée (pas de dérive).
  husk = {
    { kind = "solo", key = "the_hollow_vessel", partner = nil,
      trigger = "on_ally_death", op = "whisper_solo",
      params = { effect = { kind = "stat_inc", stat = "dmgInc", value = 0.05, capStacks = 4 } },
      verb = "endures" },
  },

  -- 8. THE LONE TITAN (solo, conditionnel d'absence) — SKULL COLOSSUS, seul de son espèce (aucun autre
  -- allié `bone`), se sent plus vaste. statInc +10% si aucun voisin d'espèce os. needFamily négatif.
  skull_colossus = {
    { kind = "solo", key = "the_lone_titan", partner = nil,
      trigger = "combat_start", op = "whisper_solo",
      params = { aloneOfType = "bone", effect = { kind = "stat_inc", stat = "statInc", value = 0.10 } },
      verb = "looms larger" },
  },

  -- 9. THE PATIENT ONE (solo, durée de combat) — THE HOLLOW MARIONETTE a attendu ; après ~N s, les fils
  -- se tendent. afterT (en frames) -> statInc +10% au franchissement (edge-trigger combat_start armé).
  patient_worm = {
    { kind = "solo", key = "the_patient_one", partner = nil,
      trigger = "combat_start", op = "whisper_solo",
      params = { afterT = 480, effect = { kind = "stat_inc", stat = "statInc", value = 0.10 } }, -- ~8 s @ 60 fps
      verb = "waited" },
  },

  -- 10. THE BORROWED SHAPE (lignée) — MIMIC SPAWN se tient plus sûr quand ECHO FLESH est présent.
  -- Spice W6 : lie le nouveau lore du mimétisme sans devenir build-defining (+8% attaque, sous cap murmure).
  mimic_spawn = {
    { kind = "lineage", key = "the_borrowed_shape", partner = "echo_flesh",
      trigger = "combat_start", op = "whisper_lineage",
      params = { needPartner = "echo_flesh", reach = "presence",
                 effect = { kind = "stat_inc", stat = "atkInc", value = 0.08 } },
      verb = "borrows" },
  },

  -- 11. THE SECOND CURRENT (lignée, adjacence) — STORM CONDUCTOR et ECHO WARDEN forment une boucle de cadence.
  -- Bonus faible et borné : le conducteur frappe un peu plus juste quand il touche la garde d'écho.
  storm_conductor = {
    { kind = "lineage", key = "the_second_current", partner = "echo_warden",
      trigger = "combat_start", op = "whisper_lineage",
      params = { needPartner = "echo_warden", reach = "adjacency",
                 effect = { kind = "stat_inc", stat = "atkInc", value = 0.08 } },
      verb = "conducts" },
  },

  -- 12. THE COWARD (solo, esquive) — SUMP CLEAVER s'efface dans l'ombre. SEUL murmure RNG -> DÉSACTIVÉ en
  -- v1 (W7) tant que tests/snapshot.lua ne prouve pas la réinjection 2-camps (un roll non-réinjecté en
  -- ghost desync TOUT le combat). Laissé en data COMMENTÉE -> zéro émission, golden-safe, prêt pour W7.
  --
  -- bandit = {
  --   { kind = "solo", key = "the_coward", partner = nil,
  --     trigger = "combat_start", op = "whisper_dodge",
  --     condition = { kind = "chance", value = 0.08 }, -- roll seedé dans hit() AVANT damage (plan §5.3)
  --     params = { deepestOnly = true, effect = { kind = "dodge", value = 0.08 } },
  --     verb = "slips aside" },
  -- },
}
