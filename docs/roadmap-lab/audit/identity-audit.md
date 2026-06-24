# Audit d'identité du roster + cartographie `dot_family` (P0.5)

> **Rôle.** Réalise les items **2.1** (audit d'identité), **2.2** (rang-5 bloquant), **2.4** (`dot_family`)
> du `ROADMAP.md`. Tout est **vérifié ligne-à-ligne** dans `src/data/units.lua` (lecture seule). Les verdicts
> **corrigent** le roadmap là où ses étiquettes étaient inexactes (c'est le rôle de l'audit).
>
> **Méthode.** Lecture intégrale `units.lua:30-518`. Famille DoT **dérivée de l'`op`** de l'effet (le champ
> `dot_family` n'existe pas encore). DPS de frappe = `dmg/cd` (ticks). Source unique, pas de sim.

---

## 1. Faits structurels (vérifiés)

| Fait | Verdict | Détail |
|---|---|---|
| Total roster | **83** | `U.order`/`U.pool` = 83 ids uniques chacun |
| Répartition rang | **12 / 23 / 18 / 20 / 10** ✅ | correspond EXACTEMENT à l'attendu du re-tier |
| `U.pool` ≠ `U.order` ? | ❌ **RÉFUTÉ** | **strictement identiques** (`units.lua:487` « Identique au roster ») — le roadmap se trompe |
| `dot_family` en data ? | ❌ **absent partout** | champs réels : `id/type/rank/cost/hp/dmg/cd` + opt. `bodyplan/family/aggro/taunt/effects` |
| Ladder choc | **11 unités** | pas 10 (roadmap) ni 1 (CLAUDE.md, **obsolète**) |

---

## 2. Distribution par famille d'affliction (le déséquilibre, quantifié)

Famille = celle de l'`op` DoT posé (aura comptée dans sa famille mais **marquée**, car non-poseuse active).

| famille | unités | dont auras | dont rang-5 | dont rang-3 actifs |
|---|---|---|---|---|
| **poison** | **15** | 1 (miasma_acolyte) | 3 (festering, venom_censer, deep_kraken) | 3 (corruptor, bile_spitter, acid_maw) |
| **burn** | 13 | 1 (soot_acolyte) | 3 (ash_maw, plague_pyre, skull_colossus) | **1** (bellows_priest) ⚠ |
| **bleed** | 12 | 1 (clot_mender) | **1** (slow_bleed) ⚠ | 2 (leech_thorn, vein_splitter) |
| **rot** | 12 | 1 (decay_tender) | 3 (marrow_drinker, pit_maw, wither_bloom) | 2 (maggot_king, necro_leech) |
| **shock** | 11 | **0** ⚠ | **0** ⚠ | 2 (stormlord, storm_anchor) |
| **(aucune)** | 20 | — | 2 (skull/kraken*) | — |

\* `skull_colossus`/`deep_kraken` posent un DoT trivial mais sont **fonctionnellement** des stat-sticks (cf. §4).

**Lectures clés :**
- **Poison est la plus grosse famille (15)** ET l'apex désigné ET la seule à risque de saturation `inc`
  (cf. `saturation-tables.md` §2 : 0,70 @1 aura). La dominance poison du diagnostic d'équilibrage a une **racine
  structurelle** : plus d'unités + plus d'amplification. → ne PAS amplifier davantage en P1 sans correction.
- **Shock est la plus petite (11)**, **sans aura**, **sans rang-5**. Confirme « apex choc = nouvelle unité
  rang-5 » (M2) ET signale un **trou d'aura choc** (4 familles sur 5 ont une aura ; pas le choc).
- **Trous d'apex** : bleed n'a **qu'1 rang-5** (`slow_bleed`) et shock **0**. Le roadmap cible shock ; **bleed
  est le second trou d'apex** (à noter pour P1.5b/P3).
- **20 unités sans famille (24 %)** : tanks/boucliers/épines/contres/brutes. Elles **ne participent à aucune
  synergie de TYPE** (P1) — intentionnel (couche défensive/positionnelle), mais ça **réduit le pool effectif**
  d'un build mono-type. À garder en tête pour la densité d'offre de la boutique.

---

## 3. Cartographie `dot_family` — spec exécutable de M2/2.4

> **Règle multi-effets.** `dot_family` = la famille **dommageable primaire** de l'unité (l'op qui définit son
> identité). Les effets 0-dps utilitaires (slow/weaken) et les `grant_team`/auras **ne changent pas** la famille.
> Les unités sans DoT → `dot_family = nil` (ne comptent dans aucun type).

### BURN (13) → `dot_family = "burn"`
`emberling` · `cinder_cur` · `pyre_tender` · `ash_moth` · `bellows_priest` · `wildfire_hound` · `kiln_warden` ·
`ash_maw` · `plague_pyre`† · `pyre_herald` · `zeal_inquisitor` · `skull_colossus`‡ · `soot_acolyte`§(aura)

### BLEED (12) → `dot_family = "bleed"`
`razorkin` · `gash_fiend` · `hookjaw` · `leech_thorn` · `bloodletter` · `tendon_render` · `vein_splitter` ·
`slow_bleed` · `wailing_shade` · `byakhee` · `gnaw_rat` · `clot_mender`§(aura)

### POISON (15) → `dot_family = "poison"`
`witch` · `spore_tick` · `corruptor` · `bile_spitter` · `rot_grub`¶ · `plague_bearer` · `acid_maw` ·
`festering` · `venom_censer`† · `chitin_drone` · `coil_viper` · `web_recluse` · `ink_horror` · `deep_kraken`‡ ·
`miasma_acolyte`§(aura)

### ROT (12) → `dot_family = "rot"`
`rot_hound` · `carrion_pecker` · `maggot_king` · `necro_leech` · `patient_worm` · `hollow_gut` ·
`blight_spreader` · `marrow_drinker`† · `pit_maw` · `wither_bloom`† · `bore_worm` · `decay_tender`§(aura)

### SHOCK (11) → `dot_family = "shock"`
`stormcaller` · `live_wire` · `thunderhead` · `static_swarm` · `galvanizer` · `stormlord` · `dynamo_priest` ·
`arc_warden` · `storm_anchor` · `siphon_jelly` · `rust_sentinel`

### AUCUNE (20) → `dot_family = nil`
`marauder` · `templar` · `skeleton` · `bandit` · `demon` · `plague_doctor` · `gravewarden` · `shieldbearer` ·
`aegis_warden` · `oath_keeper` · `bulwark_acolyte` · `ward_weaver` · `barrier_savant` · `mirror_ward` ·
`surge_warden` · `siege_breaker` · `runestone_golem` · `husk` · `footman` · `mire_thing`

**Notes de marquage (pour le lint M2/2.4) :**
- **§ auras** (`soot_acolyte`/`clot_mender`/`miasma_acolyte`/`decay_tender`) : portent `dot_family` mais
  **n'amorcent pas** — exclues du plancher « ≥2 poseurs actifs/rang » (toutes rang-3).
- **† croisés** (`plague_pyre` burn→poison ; `venom_censer` poison→burn ; `marrow_drinker` bleed→rot ;
  `wither_bloom` rot + bleed(0)+poison(0)) : `dot_family` = famille **primaire** ; le lint doit **tolérer**
  des ops d'autres familles (ne pas crasher sur multi-op).
- **‡ stat-sticks** (`skull_colossus` burn, `deep_kraken` poison) : portent une famille mais sont des murs de
  frappe (cf. §4) — `dot_family` correct, mais leur **poids réel n'est pas dans le DoT**.
- **¶ piège de nom** : `rot_grub` est **poison** (op `poison`), pas rot — le lint doit lire l'`op`, pas le nom.

---

## 4. Rang-5 = bloquant (item 2.2, vérifié)

Les 10 unités rang-5, DPS de frappe `dmg/cd` :

| unité | type | `dmg/cd` = frappe | DoT | rôle réel |
|---|---|---|---|---|
| **deep_kraken** | abyss | **12/78 = 0,154** | poison dps 4 | **STAT-STICK** (frappe max du roster) |
| **skull_colossus** | bone | **11/84 = 0,131** | burn dps **4** | **STAT-STICK** (burn < rang-1) |
| marrow_drinker | abyss | 6/52 = 0,115 | convert→rot | transform croisé (plus haut T3) |
| plague_pyre | abyss | 6/56 = 0,107 | burn+poison | transform croisé |
| venom_censer | arcane | 6/58 = 0,103 | poison→ignite | transform croisé |
| ash_maw | abyss | 6/60 = 0,100 | burn no-decay | transform d'équipe |
| festering | arcane | 6/60 = 0,100 | poison no-cap | transform d'équipe |
| slow_bleed | bone | 5/54 = 0,093 | bleed+slow team | transform d'équipe |
| wither_bloom | abyss | 5/60 = 0,083 | rot+slow+weaken | transform croisé |
| pit_maw | bone | 5/64 = 0,078 | rot team | transform d'équipe |

**Verdict CONFIRMÉ.** `deep_kraken` (0,154) et `skull_colossus` (0,131) **dépassent tous les T3 transforms**
(max = marrow_drinker 0,115) de **+34 %** et **+14 %**, avec un **DoT trivial** (single-op). En async (zéro
counter-play hors placement), ce sont des **murs sans réponse**. De plus, `skull_colossus.burn_dps = 4` est
**inférieur** au burn d'un rang-1 (`ash_moth` = 7) → « le tank qui brûle » a la pire brûlure du jeu.

→ **Aligne la correction M2/2.2** : `skull_colossus` reste burn mais `burn_dps 4→8` (« mur qui brûle fort ») ;
`deep_kraken` doit cesser d'être un stat-stick (AoE-colonne + `grant_team`, ou croisé poison-rot) ; **apex choc
= NOUVELLE unité** rang-5 (le roster n'a aucun choc rang-5 — recycler `skull_colossus` est DA-invalide, décidé).

---

## 5. Collisions code-vérifiées (verdicts + corrections au roadmap)

### 5.1 `corruptor` vs `bile_spitter` (rang-3 poison-weaken) — **NUANCÉ** (pas dead-pick strict)
| | corruptor `:62-64` | bile_spitter `:122-124` |
|---|---|---|
| stats | hp46, dmg6, cd62 → frappe **0,097** | hp42, dmg5, cd56 → frappe **0,089** |
| poison | dps2, dur180, **weaken 0,06** | dps2, dur180, **weaken 0,10** |

**Payload poison identique** (dps2/dur180). Différence = corruptor +stats / −weaken vs bile_spitter −stats /
+weaken. **Ce n'est PAS une domination stricte** (chacun gagne un axe), mais **l'intention est inversée** :
le commentaire `:166` désigne `corruptor` comme « le T2 poison-weaken » (le premium), or son weaken (0,06) est
**plus faible** que celui du « T1.5 » bile_spitter (0,10). **Collision de niche réelle** (deux rang-3
poison-weaken quasi-jumeaux), résolution = **différencier l'axe** (ex. corruptor = weaken fort + cher ;
bile_spitter = stacks longs) plutôt que « retirer ».

### 5.2 `rust_sentinel` vs `stormcaller` (op choc identique) — **CONFIRMÉ**
`stormcaller` (r2, `:80`) et `rust_sentinel` (r4, `:427`) ont le **shock identique** : `add=1, cap=6, dur=150`.
Le rang-4 porte **exactement** la charge choc du rang-2. **Concern réel** : l'effet **ne scale pas avec le
rang** (un rang-4 devrait avoir un choc plus dense ou twisté). Pas un dead-pick (classes de stats différentes :
rust = bruiser-tank hp78/dmg9 ; stormcaller = carry hp38/dmg6), mais **viole l'esprit `cost=rank`** côté effet.

### 5.3 `byakhee` vs `vein_splitter` (inversion de frappe) — **CONFIRMÉ, étiquettes roadmap CORRIGÉES**
Le roadmap dit « byakhee **rang-4** > vein_splitter **rang-2** ». **Faux** : code = `byakhee` **rang-2** (`:402`),
`vein_splitter` **rang-3** (`:195`).

| | byakhee (r2) | vein_splitter (r3) |
|---|---|---|
| frappe `dmg/cd` | 8/50 = **0,160** | 4/44 = **0,091** |
| bleed | dps3, slow 0,10 | dps4, slow 0,15 |

L'inversion (1,76×) est **réelle et correcte** : une unité **rang-2** sur-frappe une **rang-3** de 76 %.
`byakhee` = striker rang-2 avec bleed en garniture ; `vein_splitter` = spécialiste bleed (dps/slow supérieurs).
La frappe de byakhee (0,160) est **la 2e plus haute du roster** (juste sous deep_kraken) **pour un rang-2** →
**à border** (c'est un rang-2 qui frappe comme un rang-5).

### 5.4 `deep_kraken`/`skull_colossus` — cf. §4 (stat-sticks rang-5). **CONFIRMÉ.**

---

## 6. Déserts & plancher (item 2.1)

- **Désert rang-3 burn — CONFIRMÉ** : **1 seul** poseur burn **actif** au rang 3 (`bellows_priest`), + 1 aura
  (`soot_acolyte`). La règle « ≥2 poseurs actifs/rang, ne pas compter les auras » → **burn échoue au rang 3**.
  Remède : 1 poseur burn rang-3 actif (ou re-tier d'un voisin).
- Autres rang-3 actifs OK : bleed 2 (leech_thorn, vein_splitter), poison 3 (corruptor/bile_spitter/acid_maw —
  mais 5.1 = collision), rot 2 (maggot_king, necro_leech), shock 2 (stormlord, storm_anchor). ✅
- **Trous d'apex (rang-5)** : shock **0** (M2, apex = nouvelle unité), bleed **1** (`slow_bleed` — 2e trou, à
  noter pour P1.5b).

---

## 7. Récapitulatif des verdicts

| Claim roadmap | Verdict | Note |
|---|---|---|
| roster 12/23/18/20/10 = 83 | ✅ exact | — |
| `dot_family` absent | ✅ confirmé | spec de pose en §3 (prête à appliquer) |
| `U.pool` ≠ `U.order` | ❌ **réfuté** | identiques |
| ladder choc = 10 | ⚠ corrigé | **11** unités, **0 au rang-5** |
| corruptor/bile_spitter dead-pick | ⚠ nuancé | collision de niche, pas domination stricte (intention inversée) |
| rust_sentinel = stormcaller | ✅ confirmé | shock identique add1/cap6/dur150 sur rang 2→4 |
| byakhee r4 > vein_splitter r2 | ⚠ **étiquettes corrigées** | byakhee=**r2**, vein=**r3** ; inversion 1,76× réelle |
| deep_kraken/skull stat-sticks | ✅ confirmé | frappe 0,154/0,131 > tous T3 (≤0,115) ; skull burn 4 < rang-1 |
| désert rang-3 burn | ✅ confirmé | 1 poseur actif (bellows_priest) |

## 8. Suites (ordre roadmap)

1. **M2/2.4 — poser `dot_family`** (§3 = data prête) + **lint** `tools/check.sh` (couverture : chaque unité
   à DoT déclare sa famille ; lire l'`op`, tolérer multi-op, exclure les 20 `nil`). **Golden-neutre** (champ
   non lu par la SIM). **= le premier changement code, dès la branche propre.**
2. **M2/2.1-2.2 — corrections data** : `skull_colossus` burn 4→8 ; `deep_kraken` dé-stat-stické ; border la
   frappe `byakhee` (0,160 @r2) ; différencier corruptor/bile_spitter ; 1 poseur burn rang-3 ; apex choc r5.
   (Touchent l'équilibrage → **sim** + rebaseline golden **explicite** si l'op change.)
3. **P1 — types** : lit `dot_family` ; seuils 2/4 ; précédé des tableaux de saturation (faits).
