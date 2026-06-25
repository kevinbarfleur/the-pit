# Phase C — Diagnostic d'équilibrage & plan de tuning (sim-driven)

> Méthodo : `balance-psychology-and-sim-methodology.md` (faisceau §2.5, santé §2.6, **1 levier/itération**,
> juge = win-rate contextualisé par invest). Moteur : `tools/sim.lua <mode>` (commité `4fbc227`).
> Rapports source : `runs/report-{invest,commander,counter,policy,godroll}.json`.

## 0. État du faisceau (lecture des 5 rapports réels, post-de-dup)

| Signal | Lecture | Verdict |
|---|---|---|
| **Baseline P0** | σ≈0,058, entropie≈0,999, 0 σ-flag, DoT réparti (poison 8,2/shock 6,9/burn 6,5/rot 5,6%), TTK non dégénéré | **SAIN** — on raffine, pas de feu |
| **god-roll P7** | taux 6,7% ; diversité 4 signatures **mais 1 SEUL archétype = shock** ; caps OK (multicast≤3, 0 one-swing, 0 non-conclu) | **MONOCULTURE DE QUEUE** (viole §2.6-1 : queue doit être ≥3 archétypes) |
| **counter P3** | **shock>tank = 0% (DESIGNED cassé)** ; reste respecté (poison/burn/rot>tank, bleed>bruiser, tank>bruiser) ; sustain bat shock+tank | counter cassé + shock base non-viable |
| **commander P5** | `dmgReduce` n=12 (le + représenté, ~18% du pool), delta +9,5% (dans la bande) | convergence de **prévalence**, PAS outlier de win% |
| **policy P2** | greedy_stats/econ/burn complètent ; **committed_tank/poison/rot = 0%** au niveau RUN | dette éco/scaling de run (pas du combat) |
| **invest P1** | `mid_shock` gagne 68-72% sous coût ; `rot_carre_perfect` faible (perd vs presque tout) | shock mid sur-performe ; rot pur faible |

## 1. Cause racine transversale (vérifiée dans le code)

**Shock proc PAR FRAPPE.** `Arena:dischargeShock` (arena.lua:485) est appelée par `Arena:hit` (arena.lua:473)
à chaque sous-coup. La boucle multicast (arena.lua:798-801) appelle `self:hit()` `n` fois/swing → un carry
shock multicast×3 décharge 3×/swing ; `echo_crown`/`maggot_king` ajoutent des sources de multicast,
`forked_tongue` (`shockChain`) fait arquer chaque décharge. **La fréquence (multicast/chain/double-frappe)
MULTIPLIE shock** car shock = burst par instance de frappe. Les DoT (poison/burn/rot/bleed) sont des effets
de **durée** : un multicast ne pose qu'un stack de plus (capé `DOT_CAP_MULT=3`), il ne re-tick pas la durée.
⟹ asymétrie de plafond : **shock scale super-linéairement avec les amplis de fréquence, les DoT non**.

**Même racine pour shock>tank=0%** : la décharge ignore bouclier ET armure, mais avec **un seul
condensateur** (`shock_carre` n'a qu'un stormcaller, volt 3) elle ne perce pas un mur. Shock est
**bipolaire** : plancher 0% (1 condensateur, pas de masse) / sommet 100% (multicast empile les décharges).
Shock ne tire sa valeur que de la **fréquence**, jamais de la frappe.

## 2. Plan de tuning rangé (2 leviers appliqués + 2 backlog)

> Ordre : diversité-par-le-haut AVANT le buff shock, pour que la queue soit déjà multi-archétype quand
> le volt monte. 1 levier → re-sim → garder si le faisceau s'apaise sans nouvel outlier. Golden-safe :
> aucun levier ne touche templar/marauder/demon (scénario golden).

### Levier #1 (appliqué en 1er) — `DOT_CAP_MULT 3 → 4` (`src/effects/ops.lua:22`)
Diversité god-roll **par le haut** : donne aux compos DoT fortement investies (commandant ampli + relique
ampli + aura) un plafond comparable à shock, sans rien retirer à shock. **Risque** : cap global → touche la
baseline P0 (surveiller `status_dmg_share`<70% + entropie stable). **Validation** : `godroll` (`arch_diversity`≥2,
cible 3) + P0 (DoT share<70%, entropie non régressée, 0 nouveau σ-flag).

### Levier #2 (appliqué en 2e) — `VOLT_PER_STACK 3 → 4` (`src/combat/arena.lua:33`)
Répare le counter DESIGNED `shock>tank` (décharge anti-armure plus mordante) + dé-bipolarise shock base
(moins dépendant du god-roll stack). Appliqué APRÈS #1 pour que la légère poussée du god-roll shock soit
absorbée par une queue déjà diversifiée. **Validation** : `counter` (shock>tank respecté, borné ≤0,75 pour
ne pas créer un counter écrasant) + `godroll` (one_swing==0, arch_diversity ne régresse pas) + `invest`
(shock_carre sort de 0%).

### Backlog #3 — dmgReduce convergence : **LAISSER** (argumenté)
Pas un outlier de win% (delta +9,5% dans la bande) ; convergence = prévalence/diversité-de-commandants, pas
puissance. Toucher ~5 auras = 5 leviers (viole 1-levier). Garde future : re-thématiser **1** aura
`dmgReduce 0.06` générique → catégorie sous-représentée (empower/lifesteal/haste), validé P5.

### Backlog #4 — rot/tank faibles au niveau RUN : **éco, pas combat**
`committed_*` complètent 0% alors que poison/rot gagnent en combat ⟹ courbe d'investissement run (payoff trop
tard), pas puissance de combat. Levier isolé futur : `LEVEL_GOLD` (cadence de déblocage des slots,
`src/run/state.lua`), validé en P2-policy uniquement. Ne pas mêler à l'équilibrage combat.

## 3. Garde-fous
Caps intacts (MULTICAST_MAX=3, SHOCK_STACK_CAP=8, WEAKEN/poison 8, HASTE_CAP=0.40, DMG_REDUCE_CAP=0.60,
ATK_INC_CAP=1.5, VULN_INC_CAP=0.5, HIT_DMG_CAP_MULT=7). Les leviers montent des valeurs de RENFORT, pas des
caps de sécurité anti-boucle (`one_swing==0` reste l'assert-barrière P7). Golden : re-baseline NON requise
(gating prouvé) — confirmer `sh tools/check.sh` après chaque levier ; si l'empreinte bouge = bug de gating.

## 4. Résultat VALIDÉ en sim (discipline 1-levier)

**RETENU — `DOT_CAP_MULT 3 → 4` (`src/effects/ops.lua:22`).** Validé : golden `1176281181` intact ;
**baseline P0 INCHANGÉE** (DoT share 30,6%, σ 0,058, entropie 0,999, 0 σ-flag — le cap n'est atteint qu'en
god-roll haut-invest, jamais en jeu aléatoire ⟹ effet « gated » naturel, zéro impact baseline) ; **god-roll :
le poison passe de ~60% à 100% win** au sommet (dom 0,77, win 100% — `poison_diamant_perfect` + venom_censer/
witch + plague_communion/kings_bowl). ⟹ **diversité substantielle gagnée** : un build poison fortement investi
peut désormais atomiser l'ennemi (le fantasme, la vision user), là où il plafonnait avant. (Nuance : la queue
TOP-4 formelle reste shock car son pic dom 0,80 > poison 0,77 — artefact de seuil TTK ; `arch_diversity`=1
mais le poison est au club des 100%-win. DOT=5 testé : n'améliore pas le formel, déviation inutile → rejeté.)

**REJETÉ — `VOLT_PER_STACK 3 → 4` (`arena.lua:33`), REVERTÉ.** Test isolé : (a) **n'a PAS réparé shock>tank**
(toujours 0% — `shock_carre` n'a qu'UN condensateur ; il faut de la DENSITÉ/pénétration, pas du volt) ; (b) a
**RE-MONOPOLISÉ** le god-roll sur shock (pic dom 0,80→0,81 → repousse le seuil → le poison RESSORT de la queue,
annulant le gain DOT) ; (c) mid_shock sur-performe encore plus sous coût (73,7%). Net négatif → reverté à 3.

**BACKLOG (reproductible via le moteur)** : (1) **shock>tank=0%** (dette pré-existante) — fix = densité de
condensateurs dans `shock_carre` OU pénétration d'armure dédiée de la décharge, PAS le volt global. (2)
**arch_diversity formel** — pour faire entrer poison/burn dans la queue TOP-4, soit une **relique tier-4
`dotUncap` gated** (zéro impact baseline, plus propre que monter le cap global), soit baisser légèrement le pic
shock. (3) **dmgReduce convergence** (laisser, re-thématiser 1 aura si la diversité commandant devient un
objectif). (4) **rot/tank faibles au RUN** = dette éco (`LEVEL_GOLD`), pas combat, valider en P2-policy.
