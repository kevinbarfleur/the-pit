# The Pit — Inventaire des mécaniques (état du code au 2026-06-23)

> Source primaire : lecture directe des fichiers listés. Toutes les valeurs citées sont lues
> dans le code ; les valeurs marquées **[PH]** sont explicitement indiquées `PLACEHOLDER` dans
> les commentaires de code (à tuner via `tools/sim.lua`).
>
> Sources de conception cités : `docs/research/gd-research-result.md`,
> `docs/research/combat-model-decision.md`, `docs/research/effects-dot-families.md`,
> `docs/research/relics-design.md`, `docs/research/engine-architecture.md`.

---

## 1. Roster — compte et répartition

**Total roster / pool d'achat : 83 unités** (identique : `U.order` = `U.pool`).

### 1.1 Par rang (coût = rang en boutique)

| Rang | Coût | Nb | Exemples représentatifs |
|------|------|----|------------------------|
| 1    | 1    | 12 | marauder, skeleton, bandit, demon, ash_moth, carrion_pecker, spore_tick, live_wire, husk, gnaw_rat, footman, mire_thing |
| 2    | 2    | 23 | witch, emberling, razorkin, rot_hound, stormcaller, cinder_cur, pyre_tender, gash_fiend, hookjaw, rot_grub, thunderhead, static_swarm, shieldbearer, chitin_drone, bore_worm, wailing_shade, pyre_herald, byakhee, zeal_inquisitor, coil_viper, web_recluse, siphon_jelly, ink_horror |
| 3    | 3    | 18 | templar, corruptor, plague_doctor, leech_thorn, bile_spitter, maggot_king, necro_leech, soot_acolyte, clot_mender, miasma_acolyte, decay_tender, bellows_priest, vein_splitter, acid_maw, stormlord, storm_anchor, bulwark_acolyte, siege_breaker |
| 4    | 4    | 20 | wildfire_hound, kiln_warden, bloodletter, tendon_render, plague_bearer, patient_worm, hollow_gut, blight_spreader, gravewarden, galvanizer, dynamo_priest, arc_warden, aegis_warden, oath_keeper, ward_weaver, barrier_savant, mirror_ward, surge_warden, rust_sentinel, runestone_golem |
| 5    | 5    | 10 | ash_maw, plague_pyre, slow_bleed, marrow_drinker, festering, venom_censer, pit_maw, wither_bloom, skull_colossus, deep_kraken |

Source : `src/data/units.lua`, champ `rank`.

### 1.2 Par archétype / affliction principale

| Archétype | Unités principales | Nb approx. |
|-----------|-------------------|------------|
| Brûlure (burn) | ash_moth, emberling, cinder_cur, pyre_tender, bellows_priest, wildfire_hound, kiln_warden, ash_maw, plague_pyre, soot_acolyte (aura), pyre_herald, zeal_inquisitor, skull_colossus | 13+ |
| Saignement (bleed) | razorkin, gash_fiend, hookjaw, leech_thorn, vein_splitter, bloodletter, tendon_render, slow_bleed, marrow_drinker, clot_mender (aura), wailing_shade, byakhee, gnaw_rat | 13+ |
| Poison | witch, spore_tick, corruptor, rot_grub, bile_spitter, plague_bearer, acid_maw, festering, venom_censer, miasma_acolyte (aura), chitin_drone, coil_viper, web_recluse, ink_horror, deep_kraken | 15+ |
| Pourriture (rot) | rot_hound, carrion_pecker, maggot_king, necro_leech, patient_worm, hollow_gut, blight_spreader, pit_maw, wither_bloom, decay_tender (aura), bore_worm | 11+ |
| Choc (shock) | stormcaller, live_wire, thunderhead, static_swarm, galvanizer, stormlord, dynamo_priest, arc_warden, storm_anchor, siphon_jelly, rust_sentinel | 11 |
| Bouclier (shield aura) | templar, shieldbearer, aegis_warden, oath_keeper, bulwark_acolyte, runestone_golem | 6 |
| Bouclier périodique (shield_caster) | ward_weaver (caster), barrier_savant, mirror_ward, surge_warden (renforts), siege_breaker (counter) | 5 |
| Tank / taunt | templar, gravewarden, aegis_warden, shieldbearer, plague_doctor (regen+aggro) | 5 |
| Bruiser | marauder (bonus_first), demon (lifesteal), galvanizer | 3 |
| Épines (thorns) | skeleton, leech_thorn, gravewarden, aegis_warden | 4 |
| Regen (contre-DoT) | plague_doctor | 1 |
| Stat-sticks purs | bandit, husk, footman, mire_thing | 4 |

Source : `src/data/units.lua`, champ `effects[].op`.

### 1.3 Visuel

Les 6 unités vanille (marauder, templar, skeleton, bandit, witch, demon) ont un rig dessiné main
(`src/data/creatures.lua`). Toutes les autres sont générées procéduralement par `src/gen/primgen.lua`
(générateur v3, 16 archetypes exclusifs, familles = palette + traitement, seed stable FNV-1a 32 bits
dérivé de l'`id`). Le mapping `unit → (famille, arch, palette, seed)` vit dans
`src/gen/creaturegen.lua:cached`.

---

## 2. Familles d'effets

Source : `src/effects/ops.lua`, `src/effects/engine.lua`, `src/combat/arena.lua`.

### 2.1 Architecture moteur

- **Un effet = donnée** : `{ trigger, op, params, condition?, target? }`. Enregistrement ouvert :
  `Effects.register(name, fn)`. Boucle de combat jamais modifiée pour un nouvel effet.
- **Triggers** : `on_attack`, `on_hit`, `on_attacked`, `on_death`, `combat_start`.
- **`ctx.arena.rng`** : RNG seedé injecté — aucun appel à `math.random` global dans la SIM.
- Couche `teamFlags` : drapeaux d'équipe posés par `grant_team` à `combat_start`, lus par les ops et
  par `tickDots`. Permet de modifier des règles d'équipe (burnNoDecay, poisonNoCap, etc.) sans
  éditer la boucle.

### 2.2 BRÛLURE (burn)

- **Modèle** : instance UNIQUE par cible ; la plus forte remplace (sauf modes `refresh` /
  `extend_if_weaker`).
- **Tick** : décroît de `decayPct` (défaut 30 %) toutes les `decayEvery` ticks (défaut 60 = 1 s).
  Peut être supprimé par le flag d'équipe `burnNoDecay` (ash_maw / relique everburn).
- **Absorption bouclier** : la brûlure lèche le bouclier avant les PV (comportement standard des DoT
  dans `arena.tickDots`).
- **Amplification** : champ `burnInc` sur la source (bakée par `soot_acolyte` à `combat_start`),
  cappée ×3 (`DOT_CAP_MULT`).
- **Twists T2** : `decayPct = 0.15` (bellows_priest), `mode = "extend_if_weaker"` (kiln_warden),
  `refresh = true` (cinder_cur).
- **Propagation** : `spread_burn_on_death` (wildfire_hound, plague_pyre) — à la mort d'une cible
  **directement** en feu, la brûlure saute à ses voisins de champ (profondeur 1, cap 14 dps). Peut
  aussi semer du poison (`alsoPoison`, plague_pyre).
- **Transform T3** : `ash_maw` pose `burnNoDecay = true` via `grant_team` ; `plague_pyre` croise
  feu→poison à la propagation de mort.

### 2.3 SAIGNEMENT (bleed)

- **Modèle** : instance UNIQUE, dps **cumulatif par source** (Σ contributions de sources distinctes,
  capé à `BLEED_DPS_CAP = 12`). Le slow de cadence ne cumule pas (binaire : on est saignant ou non).
- **Cumul** : chaque source distincte ajoute sa contribution ; un saigneur isolé ne ramp pas seul
  (anti-abus des bleeds parasites). Le cap s'étire avec `bleedInc`.
- **Tick** : dps appliqué par accumulation de fraction de tick. Le slow (`atkSlow`) est retiré à
  l'expiration.
- **Twists T2** : `aggravateMult = 2.0` (bloodletter — le bleed double quand la cible attaque),
  `slowScalesMissingHp = true` (tendon_render — le slow scale avec les PV manquants).
- **Flag d'équipe** : `bleedNoExpire` (open_wounds) — les saignements ne s'éteignent jamais.
- **Transform T3** : `slow_bleed` pose `slowEnemies` immédiat via `grant_team` ; `marrow_drinker`
  (`convert_to_rot`) — sur cible déjà saignante, convertit bleed→rot (consomme le bleed).
- Aura : `clot_mender` (`aura_grant_bleed`) — accorde un petit bleed aux voisins au build.

### 2.4 POISON

- **Modèle** : liste de stacks (cap 8, levé par `poisonNoCap`). Chaque stack porte `dps`, `remaining`,
  `weaken` (malus de valeur : réduit le lifesteal de la victime), `source`.
- **Tick** : les stacks sont parcourus en `ipairs` (ordre déterministe), chaque stack décrémente sa
  durée ; dps accumulé (accumulation fractionnaire).
- **Malus de valeur** : `weaken` (champ par stack) réduit les soins via lifesteal de la victime
  (`ops.lifesteal` lit `s.weaken`).
- **Amplification** : `poisonInc` sur la source, cappé ×3. Aura : `miasma_acolyte`.
- **Twists T2** : `spread` (plague_bearer — contagion proportionnelle au fardeau cible, cap 12 dps,
  profondeur 1), `shieldEat = 0.30` (acid_maw — dissout 30 % du bouclier à chaque pose).
- **Ignition** : `igniteAt = 5` (venom_censer) — à N stacks, déclenche une détonation burn.
- **Transform T3** : `festering` pose `poisonNoCap + poisonDurBonus = 60` via `grant_team`.

### 2.5 POURRITURE (rot)

- **Modèle** : instance UNIQUE, croît (`dps` enfle de `growth` à chaque réapplication, plafonné à
  `capDps`). Ampute les PV max à chaque tick (`maxHpFrac`).
- **Amputation de PV max** : la pourriture réduit `u.maxHp` au tick (effet persistant dans le
  combat). Les PV actuels sont ajustés si supérieurs au nouveau max. Deux pressions anti-mur
  explicitement notées dans `arena.lua`.
- **Amplification** : `rotInc` sur la source, cappé ×3. Aura : `decay_tender`.
- **Twists T2** : `passiveRamp = 1` (patient_worm — enfle sans frapper), `amputateHealsMe = 0.5`
  (hollow_gut — 50 % du plafond retiré soigne le porteur), `spread_rot` on_death (blight_spreader).
- **Transform T3** : `pit_maw` pose `rotEnemies` immédiat via `grant_team` (toute l'équipe ennemie
  infectée d'entrée) ; `wither_bloom` combine rot + bleed (0 dps = pur slow) + poison (0 dps = pur
  malus).

### 2.6 CHOC (shock)

- **Modèle** : condensateur (stacks sur la cible, cap `SHOCK_STACK_CAP = 8`). AUCUN dégât à la
  pose : la **décharge** se produit au prochain coup sur la cible (`arena:dischargeShock`) en une
  instance `cause = "shock"`, ignore le bouclier. Dégâts = stacks × `volt` (défaut 3).
- **Modificateurs** : `persist = 0.5` (storm_anchor — garde 50 % des stacks après décharge),
  `transfer = 0.5` (dynamo_priest — la moitié des stacks saute à un voisin), `chain = 2` (arc_warden
  — la décharge arque sur 2 cibles à 60 %).
- **Flag d'équipe** : `shockChain` (forked_tongue / relique forked_tongue).
- La charge non-déchargée expire à `remaining = 0` (tickDots écoule la durée, pas de dégâts).

### 2.7 REGEN (contre-DoT)

- `regen` posé à `combat_start` : soin/tick tické par `arena:tickDots`. Unique exemplaire : plague_doctor.

### 2.8 Boucliers

- **`shield_aura`** : aura **build-résolue** (graphe du sigil, `combat_start`). Valeur baked sur les
  voisins avant combat. Absorbe les dégâts avant les PV.
  - Porteurs : templar (14), shieldbearer (6), aegis_warden (10), oath_keeper (18),
    bulwark_acolyte (8), runestone_golem (12).
- **`shield_caster`** : rebouclier **périodique** en combat (op `combat_start` + timer). Exemple :
  ward_weaver (20 toutes les 240 ticks).
  - Renforts via `aura_shield` (barrier_savant : +50% valeur, CDR 25% ; mirror_ward : réflexion 40%
    + rayon 2 ; surge_warden : surcharge cap 2×).
- **Counter** : siege_breaker (`strip_shield`, frac = 0.5 — dissout 50 % du bouclier à la frappe).

### 2.9 Passifs hors-DoT

| Op | Unités | Effet |
|----|--------|-------|
| `bonus_first` | marauder, galvanizer | +dmg sur la 1re frappe (flag `firstHit`) |
| `lifesteal` | demon | soigne `frac × dealt`, réduit par weaken |
| `thorns` | skeleton, leech_thorn, gravewarden, aegis_warden | renvoie `value` dégâts à l'attaquant (ignoreShield) |
| `strip_shield` | siege_breaker | dissout `frac` du bouclier à la frappe |
| `frenzy_gain` | relique feeding_frenzy | +8% dmg par kill ennemi, cap 6 stacks |
| `regen` | plague_doctor | soin/tick |
| `convert_to_rot` | marrow_drinker | bleed→rot sur cible saignante |

---

## 3. Interactions entre familles

Source : `src/effects/ops.lua`, `src/tests/synergies.lua` (12 interactions testées).

| Interaction | Mécanisme |
|-------------|-----------|
| Poison × lifesteal | `weaken` dans le stack réduit le soin du porteur de lifesteal |
| Choc amplifie dégâts frappés | la décharge (cause=shock) ignore le bouclier ; arrive en burst sur la cible |
| Bleed aggravateMult | quand la cible saigne et attaque, le bleed éclate × 2 (bloodletter) |
| Poison contagion (plague_bearer) | spread proportionnel au Σdps des stacks de la cible (payoff ressenti) |
| Burn propagation à la mort | `spread_burn_on_death` : profondeur 1 (le flag `viaSpread` prévient les chaînes) |
| Rot propagation à la mort | `spread_rot` (blight_spreader), même principe |
| Burn + poison croisé | plague_pyre : le feu mort sème aussi du poison (`alsoPoison`) |
| Bleed → rot | marrow_drinker : `convert_to_rot`, consomme le bleed |
| Poison → burn (ignition) | venom_censer : arme `igniteAt`, déclenché par tickDots au seuil |
| HOLLOW CHOIR × DoT | `pierceHeal = 0.40` : les afflictions percent 40 % des soins ennemis |
| OPEN WOUNDS × bleed | `bleedNoExpire` : les saignements ne s'éteignent jamais |
| Rot × amputation + hollow_gut | `amputateHealsMe = 0.5` : chaque tranche de PV max retranchée soigne le porteur |

---

## 4. Moteur de combat (SIM)

Source : `src/combat/arena.lua`, `src/effects/stats.lua`.

### 4.1 Ciblage déterministe

Ordre : **colonne avant** (`depth = maxCol - cell.x`, dérivé de la forme active) → **taunt** (override
dur) → **aggro** la plus haute (standard 10, tank ~40, bruiser ~15, carry ~5) → tie-break haut→bas.
Aucun RNG dans le ciblage.

### 4.2 Boucle de combat

Pas de temps fixe (`love.run` surchargée, accumulateur). Chaque tick :
1. `tickDots` (ordre fixe : burn → bleed → poison → rot → shock → regen) pour chaque unité vivante.
2. Cooldown decrementé ; à 0 → l'unité choisit/reconfirme sa cible et frappe.
3. Frappe : hooks `on_attack` → `arena:damage` → hooks `on_hit` → `on_attacked`.
4. `dischargeShock` si applicable.
5. Mort → broadcast `on_death` différé (fin de frame).
6. Fatigue : passé `FATIGUE_START = 1020` ticks (~17 s), usure globale croissante (base 1 dps/tick,
   ramp 0.01/tick) pour garantir la conclusion. Déclenché seulement si les combats ne se concluent pas.

### 4.3 Couche de modificateurs (`src/effects/stats.lua`)

Formule PoE/Last Epoch : `(base + Σflat) × (1 + Σincreased) × Π(1 + more)`.
- `increased` est additif entre eux → commutatif → déterminisme sans tri.
- `mods = nil` → renvoie `base` → golden inchangé si aucun mod.
- Clamp + arrondi optionnels.

### 4.4 Framework payoff (amplification DoT)

```
dps_final = Stats.resolve(base, { Stats.increased(inc) }, { max = base × 3, round = "nearest" })
```
Cap global ×3 par axe (anti-snowball). L'aura (`soot_acolyte`, `miasma_acolyte`, etc.) bake le
champ `burnInc`/`poisonInc`/`bleedInc`/`rotInc` sur les voisins au build.

---

## 5. Plateau et sigils

Source : `src/board/shapes.lua`, `src/board/board.lua`.

### 5.1 Cinq sigils

| Sigil | Topologie | Arêtes | Archétype |
|-------|-----------|--------|-----------|
| carré | 3×3 plein | 12 (ortho) | polyvalent ; centre = 4 voisins |
| croix | centre + 4 bras | 8 | mono-carry extrême (1 noyau, 4 nourriciers isolés) |
| anneau | boucle fermée | 9 | propagation / chaîne rebouclée |
| diamant | 9 cases en losange | 12 | go-wide / essaim (tous à 2-3 voisins) |
| ligne | conduit 9×1 | 8 | propagation linéaire début→fin |

Tous gardent **9 slots**. Changer de sigil = échanger une topologie, jamais de la puissance brute.
Le joueur bascule avec `[s]` en phase build.

### 5.2 Ouverture de slots

Départ : 3 slots (cluster central connexe, priorité connectivité > degré > index bas). Grants timés
aux rounds 2-7 (6 offres, MAX_GRANTS = 6). Chaque offre : accepter (+1 capacité, case choisie
librement sur le plateau) ou refuser (+3 or, slot renoncé définitivement). La capacité ne bouge
jamais automatiquement.

---

## 6. Économie et progression de run

Source : `src/run/state.lua`.

### 6.1 Paramètres clés [tous PH]

| Constante | Valeur | Rôle |
|-----------|--------|------|
| `GOLD_PER_ROUND` | 10 | or frais par round (SAP : pas de banque) |
| `REROLL_COST` | 1 | coût de reroll boutique |
| `SHOP_SIZE` | 5 | offres par boutique |
| `START_LIVES` | 5 | vies initiales |
| `WIN_TARGET` | 10 | victoires pour l'ascension |
| `START_SLOTS` | 3 | cases ouvertes au départ |
| `MAX_SLOTS` | 9 | capacité max du plateau |
| `SLOT_DECLINE_GOLD` | 3 | or par slot refusé |
| `DECLINE_RELIC_GOLD` | 3 | or par relique refusée |
| `SELL_REFUND_FRAC` | 0.5 | fraction du coût rendue à la revente |
| `STREAK_CAP` | 3 | bonus d'or max par série |

### 6.2 Boucle de run

`startRound()` : or frais + bonus de streak → reroll boutique → offre de slot si round ∈ {2-7} →
XP passive (à partir du round 2).
`resolve(win)` : maj vies/wins/streaks. Pas d'or distribué ici (c'est `startRound`).
Filet anti-tilt (SAP) : au début du round 3, +1 vie si déjà perdu une vie.

### 6.3 Boutique — niveau et cotes

5 niveaux (tiers) de boutique. XP passive : +1/round à partir du round 2. XP achetée : 4 XP pour 4
or. Seuils de passage [PH] : T1→T2 = 2 XP, T2→T3 = 5, T3→T4 = 8, T4→T5 = 12 (cumuls : 2/7/15/27).
Intention : un joueur purement passif atteint ~T3 en fin de partie typique ; un rush XP atteint T5
vers le milieu.

Cotes par tier [PH] :

| Tier | R1 | R2 | R3 | R4 | R5 |
|------|----|----|----|----|-----|
| 1    | 100| 0  | 0  | 0  | 0  |
| 2    | 70 | 30 | 0  | 0  | 0  |
| 3    | 44 | 34 | 20 | 2  | 0  |
| 4    | 25 | 30 | 30 | 13 | 2  |
| 5    | 15 | 20 | 30 | 25 | 10 |

Chaque slot de boutique : 2 tirages RNG (rang selon cotes, puis id au hasard dans le bucket du rang).

### 6.4 Duplicatas

3 copies d'une même unité (même id + niveau) → niveau+1 (cap 3, cascade possible). Scaling
`LEVEL_MULT = { 1.0, 1.8, 3.0 }` (hp et dmg arrondis). Les auras et stats scalent. Le niveau 1 est
l'identité (golden/sim inchangés). Fusion détectée à l'achat (`build:checkMerges`). Pips dorés en UI.

Source : `src/net/snapshot.lua` (LEVEL_MULT), `src/scenes/build.lua` (checkMerges).

---

## 7. Reliques — 21 entrées

Source : `src/data/relics.lua`, `src/run/state.lua`.

### 7.1 Modèle

Relique LISIBLE (révision 2026-06) : effet affiché clairement, pas de leurres ni d'identification.
Collection via le **Grimoire** (`src/core/grimoire.lua`, persistant cross-run). Offre 1-parmi-3 tous
les 3 combats (victoire OU défaite). Tier de l'offre gatée par avancée : early (0-1 win) → tier ≤ 2 ;
mid (2-4) → ≤ 3 ; late (5+) → ≤ 4. Fallback : si moins de 3 disponibles dans le tier, le pool s'élargit.

Tirage : Fisher-Yates seedé (`rollRelicChoices`). Refus → +3 or. Pas de doublon possible (anti
double-grant). Application via `Relics.apply(comp, relic)` au build (avant chaque combat).

### 7.2 Table des 21 reliques

#### A — Stats plates (universelles, tier 1)

| ID | Op | Params | Effet réel |
|----|----|--------|-----------|
| `bloodstone` | `relic_more_dmg` | `mult = 0.14` | +14% dmg (more) à toute l'équipe [PH] |
| `carapace` | `relic_flat_hp` | `value = 8` | +8 PV à toute l'équipe [PH] |
| `aegis` | `relic_dmg_reduce` | `frac = 0.15` | −15% dégâts reçus (cause=attack) |
| `whetstone` | `relic_haste` | `value = 0.15` | +15% cadence (réduit le cooldown effectif) |

#### B — Amplificateurs d'affliction (tier 2, build-shaping)

| ID | Famille | `inc` | Note |
|----|---------|-------|------|
| `kings_bowl` | poison | 0.20 | conservateur car poison = APEX [PH] |
| `ember_heart` | burn | 0.30 | [PH] |
| `weeping_nail` | bleed | 0.18 | recalibré de 0.30 [PH] |
| `grave_cap` | rot | 0.18 | recalibré de 0.30 [PH] |

L'`inc` s'accumule avec les auras d'adjacence déjà bakées (additif). Cappé ×3 dans `ampDps`.

#### C — Paliers / payoffs (tier 3)

| ID | Op / params | Effet réel |
|----|-------------|-----------|
| `famines_math` | `relic_few_units` ; max=3, dmgInc=0.30, hpInc=0.20 | Si l'équipe a ≤ 3 unités : +30% dmg, +20% PV [PH] — axe « tall » |
| `hollow_choir` | `relic_add_effect` → `grant_team { pierceHeal = 0.40 }` | Les afflictions percent 40% des soins ennemis [PH] |
| `feeding_frenzy` | `relic_add_effect` → `on_death / frenzy_gain { per=0.08, cap=6 }` | +8% dmg par kill ennemi (cap 6 stacks), résolu par survivants [PH] |

#### D — Défensives (tier 2–3)

| ID | Tier | Effet réel |
|----|------|-----------|
| `thornguard` | 2 | Épines d'équipe : renvoie 2 dmg à l'attaquant (ignoré bouclier) [PH, recalibré de 4] |
| `sacred_shield` | 3 | 0,5 s d'invulnérabilité d'ouverture (t < 30 ticks ≈ 0.5 s) |
| `second_breath` | 3 | Chaque unité survit 1× à mort à 1 PV (`secondBreath = true`) |

#### E — Transformatives (règles intra-combat, tier 4)

| ID | Flag posé par grant_team | Effet réel |
|----|--------------------------|-----------|
| `forked_tongue` | `shockChain = 1` | Le choc rebondit sur 1 ennemi supplémentaire à la décharge |
| `everburn` | `burnNoDecay = true` | Les feux de l'équipe ne décroissent jamais (réutilise le flag d'ash_maw) |
| `open_wounds` | `bleedNoExpire = true` | Les saignements ne s'éteignent jamais |
| `plague_communion` | `plagueAmp = 0.25` | Si 2+ afflictions actives : +25% de tous les dégâts de l'équipe [PH] |

#### F — Reliques de boutique (agissent sur le run, `runOp`)

| ID | Tier | `runOp` | Effet run |
|----|------|---------|-----------|
| `carrion_ledger` | 3 | `shop_xp` (+6) | Bond d'XP de boutique immédiat [PH] |
| `black_summons` | 4 | `shop_tier_up` | +1 tier de boutique instantané (rush, anti-snowball tier 4) |
| `beggars_lantern` | 2 | `shop_tier_down` (shopOddsShift −1) | Décale les cotes 1 tier plus bas (concentre les bas rangs ; nourrit les builds max-doubles) |

---

## 8. Snapshots async (pilier #3)

Source : `src/net/snapshot.lua`, `src/net/snapstore.lua`.

### 8.1 Modèle de snapshot

```lua
{ version, tier, seed, shape, units = { { id, level, col, row }, ... } }
```

Encodage sûr (format tabulé, jamais `load()` d'une string externe).
`Snapshot.toComp(s, side)` reconstruit une compo jouable : stats scalées par `LEVEL_MULT`,
positions re-dérivées par `Place.pos` (miroir gauche/droite), `depth` calculé depuis `b.maxC -
p.col`. Les ids inconnus (snapshot d'une version étrangère) sont ignorés silencieusement.

### 8.2 Store (snapstore.lua)

- Pool local de 200 snapshots max (FIFO), persisté dans `snapshots.txt` via `love.filesystem`.
- `Store.save(snap)` : le build du joueur devient un ghost servable après chaque combat.
- `Store.serve(version, tier, rng)` : même version + tier ≤ demandé ; pioche seedée.
- `Store.serveComp(...)` : cold-start garanti — si aucun snapshot ne correspond, retombe sur
  `aiComp` (Encounter IA seedé). Toujours un adversaire jouable.
- Aucun netcode temps réel. Un backend distant remplacerait `load/save/serve` sans toucher au reste.

### 8.3 Déterminisme

Le seed de combat est tiré du RNG du run (`RunState:nextCombatSeed()`). Même run + mêmes actions →
même seed de combat → même combat (replay). `Snapshot.toComp` est pur (pas de RNG). Snapshots
sérialisables = adversaires cross-session.

---

## 9. Génération procédurale (primgen v3)

Source : `src/gen/primgen.lua`, `src/gen/creaturegen.lua`.

- **16 archetypes exclusifs** par famille (aucun partage de corps entre familles).
- **Vrais squelettes** : `skull`, `spineRibs`, `boneLimb` (vs masses génériques).
- **Ancrage sémantique** : chaque archetype déclare son anatomie `A = { head, faceDir, spine, limbs,
  belly, mass, tailBase, flesh }`. Les `treat()` posent dégâts/yeux/cornes aux bons ancrages.
- **Familles** : 5 actives (palette + passe `treat`) + 6e famille « Ordre » en attente.
- **Seed stable** : FNV-1a 32 bits sur l'id string. `love.math.newRandomGenerator(seed)` → même unité
  = même créature partout (déterminisme snapshot async).
- **Bake** : `love.image.newImageData / ImageData:setPixel` une fois, filtre `nearest`,
  jamais de draw pixel par pixel par frame.

---

## 10. Récapitulatif des dettes connues

*(Lues dans les commentaires de code et CLAUDE.md §7 — état observé, non-interprété.)*

1. Profils d'exposition des sigils non réglés (l'anneau donne une exposition en file).
2. Toutes les valeurs numériques marquées [PH] sont des placeholders à tuner via `tools/sim.lua`.
3. Boutique sans raretés/cotes-par-niveau (pool uniforme par rang, pas de pondération par unité).
4. Ladder choc non étendu (5 T1/T2 codés, pas de T3 choc dans l'order — `stormcaller` reste le seul
   T1 vanilla).
5. Quelques T3 simplifiés (ash_maw sans spread-on-death d'équipe ; pit_maw sans « tous les DoT
   amputent » ; wither_bloom avec 0-dps bleeds/poison comme proxies de slow+malus).
6. UI reliques : infobulle 3 candidats et écran Grimoire non implémentés.
7. Effets d'aura/relique non capturés dans le snapshot (v1 = effets de base uniquement).
8. Passifs de ligne (façade = armure / arrière = attaque) et contres de taunt (AoE-colonne / strip /
   furtivité) différés.
9. 6e famille « Ordre » dans le générateur procédural (archetypes déclarés mais non activés).
