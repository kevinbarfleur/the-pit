-- src/data/relics.lua
-- RELIQUES (chantier 2026-06, cf. docs/research/relics-design.md). Modèle LISIBLE : l'effet est AFFICHÉ
-- clairement (plus de leurres ni d'identification ; on garde l'ambiance via nom + flavor, et la collection
-- via le Grimoire). Une relique = un buff TEAM-WIDE appliqué à la compo du joueur AU BUILD (R.apply).
--
-- PRINCIPES (garde-fous, cf. doc §1) : lisible ; AUCUN handicap persistant cross-combat (intra-combat only) ;
-- égalisateur de matchup (incline, jamais un gate 100%) ; chaque relique a un foyer ; déterministe.
--
-- DATA quasi-pure : require Units uniquement pour matérialiser un effet ajouté (copie, jamais de mutation de
-- la base). Aucun love. L'op TRANSFORME la compo du joueur au build (cf. RunState:applyRelics).
--
-- Modèle : { id, op, params, tier, band } — i18n : relic.<id>.name / .effect / .flavor.
--   tier : 1 = commune (stats plates) · 2 = ampli conditionnel · 3+ = paliers/transformatives (vagues ult.).
--     Le `tier` numérique GATE l'offre par avancée de run (RunState:maxRelicTier) — INCHANGÉ.
--   band : palier de NATURE (refonte 2026-06, plan relics-overhaul §1) — "low"/"mid"/"high" — LISIBLE d'un
--     coup d'œil, pilote SEULEMENT la couleur de carte (Argent/Or/Prismatique) et la garde de diversité de
--     trio. DÉCOUPLÉ du `tier` : carrion_ledger/usurers_ledger sont tier 3 mais band "mid" (ce sont des
--     reliques ÉCO, pas des transformatives de combat -> Or, pas Prismatique) ; hollow_choir est tier 3 mais
--     band "high" (afflictions percent les soins = règle réécrite -> seul tier 3 Prismatique).
-- ⚠️ Les CHIFFRES (inc/frac/value) sont des PLACEHOLDERS d'équilibrage (à tuner via tools/runsim.lua).

local Units = require("src.data.units")

local R = {
  -- ── A — stats plates (communes, universelles) ── band "low" (Argent) : aucune condition, marche pour TOUTE compo.
  bloodstone = { id = "bloodstone", op = "relic_more_dmg",   params = { mult = 0.14 }, tier = 1, band = "low" }, -- 0.20->0.14 (calibrage)
  carapace   = { id = "carapace",   op = "relic_flat_hp",    params = { value = 8 },   tier = 1, band = "low" }, -- 15->8 (flat ×5 unités = trop)
  aegis      = { id = "aegis",      op = "relic_dmg_reduce", params = { frac = 0.15 }, tier = 1, band = "low" },

  -- ── B — amplis d'affliction (le cœur build-shaping : récompense le mono-archétype) ── band "mid" (Or) : transformatif PAR FAMILLE.
  -- Poison = APEX -> ampli CONSERVATEUR (0.20) ; familles faibles (burn/bleed/rot) -> ampli plus généreux (0.30).
  kings_bowl   = { id = "kings_bowl",   op = "relic_affliction_inc", params = { family = "poison", inc = 0.20 }, tier = 2, band = "mid" },
  ember_heart  = { id = "ember_heart",  op = "relic_affliction_inc", params = { family = "burn",   inc = 0.30 }, tier = 2, band = "mid" },
  weeping_nail = { id = "weeping_nail", op = "relic_affliction_inc", params = { family = "bleed",  inc = 0.18 }, tier = 2, band = "mid" }, -- 0.30->0.18 (calibrage)
  grave_cap    = { id = "grave_cap",    op = "relic_affliction_inc", params = { family = "rot",    inc = 0.18 }, tier = 2, band = "mid" }, -- 0.30->0.18 (calibrage)

  -- ── C — paliers / payoffs (récompense NON-LINÉAIRE d'un build / archétype ; cf. doc §4-C) ──
  -- FAMINE'S MATH (« tall », band "mid" : conditionnel à la taille d'équipe). HOLLOW CHOIR (anti-sustain, band
  -- "high" : afflictions percent les soins = RÈGLE réécrite). FEEDING FRENZY (band "high" : chaque kill renforce).
  famines_math = { id = "famines_math", op = "relic_few_units", band = "mid",
    params = { max = 3, dmgInc = 0.30, hpInc = 0.20 }, tier = 3 },
  hollow_choir = { id = "hollow_choir", op = "relic_add_effect", tier = 3, band = "high",
    params = { effect = { trigger = "combat_start", op = "grant_team", params = { pierceHeal = 0.40 } } } },
  feeding_frenzy = { id = "feeding_frenzy", op = "relic_add_effect", tier = 3, band = "high",
    params = { effect = { trigger = "on_death", op = "frenzy_gain", params = { per = 0.08, cap = 6 } } } },

  -- ── A (suite) cadence (band "low") · D — défensives / globales (intra-combat ; cf. doc §4-A/D) ──
  whetstone     = { id = "whetstone",     op = "relic_haste", params = { value = 0.15 }, tier = 1, band = "low" }, -- +15% cadence
  thornguard    = { id = "thornguard",    op = "relic_add_effect", tier = 2, band = "mid", -- épines d'équipe (ligne d'effet -> Or)
    params = { effect = { trigger = "on_attacked", op = "thorns", params = { value = 2 } } } }, -- 4->2 (brutal vs taunt-tank)
  sacred_shield = { id = "sacred_shield", op = "relic_add_effect", tier = 3, band = "high", -- invuln d'ouverture (franchit un seuil)
    params = { effect = { trigger = "combat_start", op = "grant_team", params = { invulnT = 30 } } } },
  second_breath = { id = "second_breath", op = "relic_second_breath", tier = 3, band = "high" }, -- survie 1× à 1 PV (mort->survie)

  -- ── E — transformatives (changent une RÈGLE intra-combat ; build-defining ; cf. doc §4-E). band "high"
  -- (Prismatique). Réutilisent toutes relic_add_effect + grant_team (flags lus par le tick/les ops). ──
  forked_tongue = { id = "forked_tongue", op = "relic_add_effect", tier = 4, band = "high", -- le choc rebondit (mono->chaîne)
    params = { effect = { trigger = "combat_start", op = "grant_team", params = { shockChain = 1 } } } },
  everburn = { id = "everburn", op = "relic_add_effect", tier = 4, band = "high", -- les feux ne décroissent jamais
    params = { effect = { trigger = "combat_start", op = "grant_team", params = { burnNoDecay = true } } } },
  open_wounds = { id = "open_wounds", op = "relic_add_effect", tier = 4, band = "high", -- les saignements ne se referment jamais
    params = { effect = { trigger = "combat_start", op = "grant_team", params = { bleedNoExpire = true } } } },
  plague_communion = { id = "plague_communion", op = "relic_add_effect", tier = 4, band = "high", -- 2+ afflictions -> +25%
    params = { effect = { trigger = "combat_start", op = "grant_team", params = { plagueAmp = 0.25 } } } },

  -- ── F — reliques de BOUTIQUE (PRD progression-economy §3.4, Lot 6, calque Batomon « ±niveau de boutique »).
  -- Elles agissent sur le RUN (RunState), PAS sur la compo de combat : champ `runOp` (dispatché au GRANT par
  -- RunState:grantRelic), JAMAIS de champ `op` -> R.apply les ignore (rien à faire sur la compo de combat,
  -- donc golden inchangé). Le runOp lit ses `params`. carrion_ledger = band "mid" (éco/run -> Or, pas Prismatique
  -- malgré tier 3, plan §1.b) ; black_summons = band "high" (rush late, carte Prismatique OK). ──
  carrion_ledger = { id = "carrion_ledger", runOp = "shop_xp",        params = { amount = 6 }, tier = 3, band = "mid" }, -- bond d'XP de boutique immédiat
  black_summons  = { id = "black_summons",  runOp = "shop_tier_up",   params = {},             tier = 4, band = "high" }, -- +1 tier de boutique (rush ; tier 4 = anti-snowball, hors early)
  beggars_lantern = { id = "beggars_lantern", runOp = "shop_tier_down", params = {},           tier = 2, band = "mid" }, -- décale les cotes 1 tier PLUS BAS (concentre les bas rangs : nourrit le build « max-doubles »)

  -- ── G — reliques d'ÉCONOMIE (A3, le levier « intérêts / bonus d'or » du créateur). Champ `eco` lu par
  -- RunState:ecoMods (au round / à la résolution / à la vente) ; PAS de champ `op` ni `runOp` -> R.apply ET
  -- grantRelic les ignorent -> GOLDEN INCHANGÉ. band "mid" (Or) : hors combat, ne réécrit aucune règle de combat
  -- (usurers_ledger reste tier 3 pour le gating, mais carte Or, plan §1.b). CHIFFRES = placeholders (tuner via tools/sim). ──
  usurers_ledger    = { id = "usurers_ledger",    eco = { carryover = true, interest = 0.20, interestCap = 5 }, tier = 3, band = "mid" }, -- report + intérêt (TFT-ish ; introduit la banque)
  tithe_bowl        = { id = "tithe_bowl",        eco = { onWin = 2 },    tier = 2, band = "mid" }, -- or sur victoire (crédité au round suivant)
  paupers_boon      = { id = "paupers_boon",      eco = { perRound = 3 }, tier = 2, band = "mid" }, -- income plat chaque round
  grave_robbers_cut = { id = "grave_robbers_cut", eco = { sellFrac = 1.0 }, tier = 2, band = "mid" }, -- la vente rembourse le coût PLEIN

  -- ── H — REFONTE 2026-06 (plan relics-overhaul §2). NOUVELLES reliques. 3 chemins d'injection (§2.0) :
  --   · relic_aura_stat   : champ build-time team/role (empower/multicast/dmgReduce/lifesteal).
  --   · relic_add_effect  : op on_hit/on_kill/on_attack (lu en combat par Effects.run) ✅ déjà câblé.
  --   · grant_team        : drapeau d'équipe (combat_start) — pas de nouvelle ici (toutes en H sont les 2 premiers).
  -- Tous les CHIFFRES = PLACEHOLDERS (à tuner via tools/relicsim.lua + runsim). Tier = gating ; band = couleur.

  -- ── H.1 — MOYEN (Or) — V2 ──
  -- BANNIÈRE DE SANG (A3 forge) : empower team plat (atkInc cappé ATK_INC_CAP=1.5 a la lecture, sur la BASE).
  blood_banner = { id = "blood_banner", op = "relic_aura_stat", tier = 3, band = "mid",
    params = { stat = "atkInc", target = "team", value = 0.10 } },
  -- MARQUE DU VOYANT (A2 marque) : on_hit -> la cible prend +12% de TOUT (~2 s). grant_vuln pose en max() (non
  -- additif), cappé VULN_INC_CAP=0.5 -> cumul avec corruptor/stormcaller = la plus forte gagne (sûr par construction).
  -- TUNING (relicsim §4) : 0.15 poussait le MIRROR bruiser à 96% (mais le mirror SUR-ESTIME, cf. note relicsim) ;
  -- les CASES asymétriques ne flaggent pas. 0.12 = compromis (incline net, marge sous le cap VULN_INC_CAP=0.5).
  seers_mark = { id = "seers_mark", op = "relic_add_effect", tier = 3, band = "mid",
    params = { effect = { trigger = "on_hit", op = "grant_vuln", params = { value = 0.12, dur = 120 } } } },
  -- FESTIN DE CHAROGNE (A10 sustain) : on_kill -> le tueur regagne 5 PV (heal_on_kill, borné maxHp).
  carrion_feast = { id = "carrion_feast", op = "relic_add_effect", tier = 3, band = "mid",
    params = { effect = { trigger = "on_kill", op = "heal_on_kill", params = { value = 5 } } } },
  -- SECONDE PESTE (A1/inoculation) : on_hit -> pose un venin LÉGER là où il n'y en a pas (grant_affliction_if_absent).
  second_plague = { id = "second_plague", op = "relic_add_effect", tier = 3, band = "mid",
    params = { effect = { trigger = "on_hit", op = "grant_affliction_if_absent", params = { family = "poison", dps = 1, dur = 120 } } } },
  -- APPEL DE LA MARÉE (A9 bouclier-périodique) : dmgReduce team plat (-4% subis ; n'agit que sur cause=attack).
  -- TUNING (relicsim §4 #5) : 0.08 poussait le mirror TANK à 100% (empilement défensif = gate) ; 0.04 -> incline.
  tide_caller = { id = "tide_caller", op = "relic_aura_stat", tier = 3, band = "mid",
    params = { stat = "dmgReduce", target = "team", value = 0.04 } },
  -- FANAL-APPÂT (A10 leurre/sustain) : lifesteal team plat (5% des dégâts en PV). stat=lifesteal -> lifestealAura.
  bait_lantern = { id = "bait_lantern", op = "relic_aura_stat", tier = 3, band = "mid",
    params = { stat = "lifesteal", target = "team", value = 0.05 } },

  -- ── H.2 — HAUT (Prismatique) — V3 ──
  -- COURONNE D'ÉCHOS (A4 écho) : l'unité la plus AVANCÉE frappe deux fois (multicast +1 sur role:front). Entier,
  -- cumul avec hookjaw borné à MULTICAST_MAX=3 à la lecture. Champ build-time -> relic_aura_stat (pas relic_add_effect).
  echo_crown = { id = "echo_crown", op = "relic_aura_stat", tier = 4, band = "high",
    params = { stat = "multicast", target = "role:front", value = 1 } },
  -- DETTE DU FOSSOYEUR (A6 exécution) : on_attack -> +40% sur tout ennemi sous 25% PV (execute, mute ctx.amount AVANT damage).
  -- TUNING (relicsim §4) : 0.50 poussait le MIRROR bruiser à 91% (le mirror sur-estime) ; les CASES asymétriques
  -- ne flaggent pas. 0.40 = finish marqué (HAUT/late) sous le seuil de gate du mirror.
  gravediggers_due = { id = "gravediggers_due", op = "relic_add_effect", tier = 4, band = "high",
    params = { effect = { trigger = "on_attack", op = "execute", params = { threshold = 0.25, bonus = 0.40 } } } },
  -- GUEULE FENDUE (A7 cleave) : on_hit -> éclabousse les voisins-champ de la cible (5% du coup ; profondeur 1,
  -- AUCUN on_hit secondaire, respecte le bouclier). Le test cleave×multicast doit être vert (plan §4 #4).
  -- TUNING (relicsim §4 #4/#7, Q3) : le cleave a un SEUIL NET contre un mur PACKÉ (≥0.10 trivialise le tank :
  -- le splash tue la rangée arrière et effondre le mur = GATE) ; 0.05 reste SOUS le seuil (le tank tient, le
  -- mirror incline ~+12 pts, la frappe-large reste un payoff). PLACEHOLDER assumé (réserve HAUT/late = garde-fou Q3).
  splitting_maw = { id = "splitting_maw", op = "relic_add_effect", tier = 4, band = "high",
    params = { effect = { trigger = "on_hit", op = "cleave", params = { frac = 0.05 } } } },
}

R.order = { "bloodstone", "carapace", "aegis", "kings_bowl", "ember_heart", "weeping_nail", "grave_cap",
  "famines_math", "hollow_choir", "feeding_frenzy",
  "whetstone", "thornguard", "sacred_shield", "second_breath",
  "forked_tongue", "everburn", "open_wounds", "plague_communion",
  "carrion_ledger", "black_summons", "beggars_lantern",
  "usurers_ledger", "tithe_bowl", "paupers_boon", "grave_robbers_cut",
  -- refonte 2026-06 (relics-overhaul) — NOUVELLES (append-only). MOYEN (V2) puis HAUT (V3).
  "blood_banner", "seers_mark", "carrion_feast", "second_plague", "tide_caller", "bait_lantern",
  "echo_crown", "gravediggers_due", "splitting_maw" }

-- ── relic_aura_stat : BAKE direct d'un CHAMP combat-time sur les specs (plan relics-overhaul §2.0). ──
-- POINT DUR : applyRelics tourne APRÈS buildComp (qui a déjà baké aura_stat -> spec.atkInc/multicast/…).
-- arena.lua lit ces champs comme champs DIRECTS du spec, et ne ré-exécute PAS aura_stat à combat_start.
-- Donc une relique empower/multicast doit baker le champ ICI (comme buildComp), pas passer par relic_add_effect
-- (qui serait INERTE : l'effet ajouté ne serait plus résolu en champ). Mapping du `stat` LOGIQUE -> champ MOTEUR
-- réellement lu par makeUnit (arena.lua:120-151) : atkInc/multicast/dmgReduce/haste -> identité ; lifesteal ->
-- `lifestealAura` (le nom que makeUnit lit ; cf. arena.lua:151). multicast = ENTIER, borné à la LECTURE (MULTICAST_MAX).
local STAT_FIELD = { atkInc = "atkInc", multicast = "multicast", dmgReduce = "dmgReduce",
  haste = "haste", lifesteal = "lifestealAura" }

-- Résout le rôle "front"/"back" sur le comp (post-buildComp : chaque spec porte depth/row/slot). Tie-break
-- IDENTIQUE à chooseTarget (arena.lua:225-226) et à buildComp:resolveExtreme (build.lua:932) : depth extrême,
-- puis row asc, puis slot asc. Renvoie LA seule unité ciblée (ou nil si comp vide). DÉTERMINISTE (ipairs).
local function resolveRoleSpec(comp, wantFront)
  local best
  for _, s in ipairs(comp) do
    local d = s.depth or 0
    if not best then best = s
    else
      local bd = best.depth or 0
      local better = wantFront and (d < bd) or (not wantFront and d > bd)
      local tie = (d == bd) and ((s.row or 0) < (best.row or 0)
        or ((s.row or 0) == (best.row or 0) and (s.slot or 0) < (best.slot or 0)))
      if better or tie then best = s end
    end
  end
  return best
end

-- Bake `value` du `stat` sur UNE spec (champ moteur résolu via STAT_FIELD ; multicast = somme entière, bornée
-- à la lecture par MULTICAST_MAX comme une aura). Inerte si le stat n'est pas mappé (jamais de crash).
local function bakeStat(spec, stat, value)
  local field = STAT_FIELD[stat]
  if not (spec and field) then return end
  spec[field] = (spec[field] or 0) + value
end

-- Applique l'effet d'une relique à une compo (liste de specs d'unités), au BUILD. Modifie en place.
-- Les amplis (poisonInc/…/dmgReduce) sont ADDITIFS (cumul avec une aura d'adjacence qui poserait le même champ).
function R.apply(comp, relic)
  local op, p = relic.op, relic.params or {}
  local n = #comp -- taille de l'équipe, pour les paliers conditionnels (ex. « ≤3 unités »)
  -- relic_aura_stat : bake HORS de la boucle par-spec (la cible dépend du target : team OU une seule unité).
  if op == "relic_aura_stat" then
    local stat, target, value = p.stat, p.target or "team", p.value or 0
    if target == "team" then
      for _, spec in ipairs(comp) do bakeStat(spec, stat, value) end
    elseif target == "role:front" or target == "role:back" then
      local s = resolveRoleSpec(comp, target == "role:front")
      if s then bakeStat(s, stat, value) end
    end
    return -- traité ; ne pas retomber dans la boucle par-spec ci-dessous
  end
  for _, spec in ipairs(comp) do
    if op == "relic_more_dmg" then
      if spec.dmg then spec.dmg = math.floor(spec.dmg * (1 + (p.mult or 0)) + 0.5) end
    elseif op == "relic_flat_hp" then
      if spec.hp then spec.hp = spec.hp + (p.value or 0) end
    elseif op == "relic_dmg_reduce" then
      spec.dmgReduce = (spec.dmgReduce or 0) + (p.frac or 0) -- lu par Arena:damage (cause="attack"), gated
    elseif op == "relic_affliction_inc" then
      local key = (p.family or "") .. "Inc" -- poisonInc/burnInc/bleedInc/rotInc : lu par ampDps à la pose du DoT
      spec[key] = (spec[key] or 0) + (p.inc or 0)
    elseif op == "relic_few_units" then -- FAMINE'S MATH : si l'équipe est petite (≤max), elle frappe/encaisse plus
      if n <= (p.max or 3) then
        if spec.dmg then spec.dmg = math.floor(spec.dmg * (1 + (p.dmgInc or 0)) + 0.5) end
        if spec.hp then spec.hp = math.floor(spec.hp * (1 + (p.hpInc or 0)) + 0.5) end
      end
    elseif op == "relic_haste" then -- WHETSTONE : cadence d'attaque (lu par le timer de l'arène, gated)
      spec.haste = (spec.haste or 0) + (p.value or 0)
    elseif op == "relic_second_breath" then -- SECOND BREATH : survie 1× à 1 PV (lu par Arena:damage)
      spec.secondBreath = true
    elseif op == "relic_add_effect" and p.effect then
      local base = spec.effects or (Units[spec.id] and Units[spec.id].effects) or {}
      local eff = {}
      for _, e in ipairs(base) do eff[#eff + 1] = e end -- copie superficielle (on n'AJOUTE que)
      eff[#eff + 1] = p.effect
      spec.effects = eff
    end
  end
end

return R
