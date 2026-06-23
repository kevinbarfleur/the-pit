# Round 07 — Critique adversariale (lentille : units-power)

> **Mandat** : challenge du brouillon `ROADMAP-draft.md` (v7, intégré round 6) depuis la lentille
> **units-power** — distinction des unités, budget de puissance par rang, identité, redondance,
> trous d'archétype. Round 7/10.
>
> **Inputs lus** : `BRIEF.md`, `ROADMAP-draft.md` (v7), `00-state.md`, `round-01.md` à
> `round-06.md`, `rounds/r01-units-power.md` à `rounds/r06-units-power.md`, `competitive/*.md`
> (tous), `src/data/units.lua` (intégralité relue ce round avec calcul DPS sur 83 unités),
> `src/effects/ops.lua`, `src/board/shapes.lua`.
>
> **Méthode** : désaccord = recherche web menée ce round et citée. Analogie = teardown
> mécaniste AVANT d'accepter. Toute affirmation chiffrée cite sa source ou le fichier+ligne
> relu ce round. Désaccords avec agents précédents → recherche propre effectuée.
>
> **Garde-fou absolu** : lecture seule du repo jeu. Écriture uniquement sous
> `docs/roadmap-lab/`. Piliers respectés (async snapshots / sim déterministe seedée /
> DA grimdark / pixel art procédural).

---

## 0. TL;DR de ce round

Trois angles que six rounds de lentille units-power n'ont pas épuisés — calculés ce round sur `units.lua` relu intégralement :

1. **Le rang-5 est sémantiquement contaminé par deux stat-sticks v7 (`skull_colossus`, `deep_kraken`) qui violent la décision #10 ("rang-5 = transforms T3 / règles d'équipe") et dominent en DPS brut TOUS les T3 transforms légitimes.** Le brouillon v7 ne l'a pas signalé.

2. **La redondance des enablers rang-2 n'est pas un problème uniforme — c'est un problème STRUCTUREL PAR FAMILLE.** Burn et bleed ont chacune 2 paires quasi-identiques ; rot a 2 unités quasi-identiques. Ce n'est pas résolu par la règle P90/P10 ≤ 3× (qui passe à 2.11× pour les DoT hors tanks/condensateurs) — le spread est acceptable MAIS la NICHE par unité ne l'est pas. La règle adoptée mesure le mauvais instrument.

3. **La famille choc n'a aucun rang-5 dans `U.pool` — c'est le seul archétype complet (11 unités) sans apex de run.** Le "ladder choc" est un tronc sans cime : les joueurs montés en niveau ne peuvent jamais trouver un T3 choc. Le brouillon mentionne "ladder choc 5/3/2" mais ne quantifie pas l'impact asymétrique vs les 4 autres familles.

---

## 1. Accords avec pourquoi

### 1.1 ACCORD FORT — Règle P90/P10 ≤ 3× pour les enablers DoT (adopté round 6, §3.1 col E)

**Calcul refait ce round** sur les enablers DoT rang-2 (exclus : tanks `shieldbearer`, condensateurs `thunderhead`/`static_swarm`/`stormcaller`/`siphon_jelly`) :

```
Rang-2 DoT enablers (18 unités) — DPS calculés depuis units.lua :
  hookjaw=0.056, rot_grub=0.069, bore_worm=0.086, rot_hound=0.089,
  web_recluse=0.091, chitin_drone=0.095, pyre_tender=0.097, emberling=0.100,
  gash_fiend=0.104, razorkin=0.109, pyre_herald=0.109, ink_horror=0.111,
  wailing_shade=0.115, cinder_cur=0.118, zeal_inquisitor=0.118,
  coil_viper=0.146, byakhee=0.160, witch=0.181
  P10=0.069, P90=0.146, Ratio=2.11×
```

**P90/P10 = 2.11× sur les DoT purs — passe largement le seuil ≤ 3× adopté.** La règle tient. Pour nos contraintes async (snapshot ne capture que id+level+position), la dispersion DPS d'une unité n'affecte pas l'intégrité des snapshots — seule la valeur in-run importe. Le critère 3× est calibré sur le palier perceptif, pas sur la sim.

**MAIS (§2.2 ci-dessous)** : la règle mesure le spread global des DoT, pas la distinction entre unités de la même niche au même rang. C'est un instrument de calibrage, pas d'identité. Passer P90/P10 ≤ 3× ne garantit pas que deux enablers bleed rang-2 ont des niches différentes.

### 1.2 ACCORD — Retrait de `barrier_savant`, `mirror_ward`, `surge_warden` de `U.pool` (round 5, §3.1 col H)

Confirmé par la relecture de `units.lua:363-380` : les trois ont `op="aura_shield"` qui AMPLIFIE les boucliers de voisins — sans `ward_weaver` (shield_caster, `units.lua:363-366`) voisin, l'op est inerte (`ops.lua` : `aura_shield` lit un champ existant sur le voisin, ne le crée pas). **Dead picks confirmés** (Wayward Strategy 2018 : « dead picks for players unfamiliar with interaction » — source déjà citée r06, valide). Accord maintenu.

### 1.3 ACCORD — `burst_DPS_eq` pour les condensateurs choc (round 4, §3.1a)

Accord inchangé. Mais ce round révèle une asymétrie supplémentaire (§2.3) : la famille choc est la seule sans apex rang-5 dans `U.pool`. Les condensateurs ont une belle variance d'axes (dense/patient/transfer/chain — `units.lua:300-335` relu) mais la montée en rank s'arrête au rang-4. Sans rang-5, le `burst_DPS_eq` d'un `galvanizer` rang-4 représente le plafond accessible à un joueur — ce n'est pas un problème de métrique, c'est un problème de toit.

### 1.4 ACCORD — Singletons rang-1 pour burn et rot (`ash_moth`, `carrion_pecker`) — adopté round 6

Confirmé. La P(voir burn en T1) ≈ 42 % reste juste au-dessus du plancher. La décision à trancher (rareté voulue vs trou) est correctement formulée dans le brouillon §3.1. **Extension nécessaire** : `gnaw_rat` (bleed rang-1, `units.lua:446`) est le seul bleed rang-1 aussi. Trois familles ont un singleton rang-1 (burn, rot, bleed) — seuls poison (`spore_tick`) et choc (`live_wire`) ont un rang-1 dans le pool sans concurrence. La décision de plancher doit traiter les 5 familles uniformément, pas seulement burn/rot.

### 1.5 ACCORD PARTIEL — `skull_colossus` et `deep_kraken` signalés comme « stat-sticks rang-5 » (round 6, §3.7)

Le brouillon §3.7 les cite : « `skull_colossus` et `deep_kraken`, tous deux v7, stat-sticks pas transforms T3 (décision #10) ». **C'est exact mais insuffisant** — le brouillon le signale comme « décision : transform réelle / stat-amplification à raffiner / rétrograder rang-4 (libère 2 slots rang-5) » sans prioriser ni chiffrer. Ce round révèle que ces deux unités ont non seulement un problème sémantique mais un problème budgétaire SÉVÈRE (§2.1 ci-dessous).

---

## 2. Désaccords avec recherche sourcée

### 2.1 DÉSACCORD FORT — `skull_colossus` et `deep_kraken` ne sont pas seulement « sémantiquement incorrects au rang-5 » : ils dominent le DPS de TOUS les T3 transforms légitimes et brisent la progression de puissance perçue

**Ce que le brouillon dit** (§3.7) : les deux unités v7 rang-5 sont des « stat-sticks » à transformer ou rétrograder. Traité comme une question de classification, pas d'urgence.

**Ce qui est réellement calculé ce round** (depuis `units.lua` relu) :

```
Rang-5 DPS comparé (dmg/cd calculé) :
  T3 transforms légitimes :
    pit_maw       : 5/64  = 0.078  [rot-T3 : grant_team rotEnemies]
    wither_bloom  : 5/60  = 0.083  [rot-T3 : placeholder multi-affliction]
    slow_bleed    : 5/54  = 0.093  [bleed-T3 : grant_team wide-slow]
    ash_maw       : 6/60  = 0.100  [burn-T3 : grant_team burnNoDecay]
    festering     : 6/60  = 0.100  [poison-T3 : grant_team poisonNoCap]
    venom_censer  : 6/58  = 0.103  [poison-T3 : igniteAt=5 detonation]
    plague_pyre   : 6/56  = 0.107  [burn-T3 : spread_burn+alsoPoison]
    marrow_drinker: 6/52  = 0.115  [bleed-T3 : convert_to_rot]

  v7 stat-sticks "rang-5" :
    skull_colossus: 11/84 = 0.131  ← burn on_hit ONLY, aucune règle d'équipe
    deep_kraken   : 12/78 = 0.154  ← poison on_hit ONLY, aucune règle d'équipe
```

**`deep_kraken` DPS=0.154 dépasse TOUS les T3 transforms de 33 % (vs `marrow_drinker`=0.115, le plus haut T3 légitime). `skull_colossus` DPS=0.131 dépasse 7 des 8 T3 transforms.**

**Problème psychologique** : la décision #10 (`cost=rank = complexité croissante`) établit un **contrat d'apprentissage** avec le joueur — les unités rang-5 sont des « règles d'équipe / transforms ». Un joueur qui découvre `deep_kraken` au rang-5 voit une unité avec le DPS de frappe le plus élevé du roster ET un poison simple. La complexité perçue est inférieure à un rang-3 avec un twist conditionnel (`acid_maw` shieldEat, `bellows_priest` lente-extinguish). **Ce n'est pas de la profondeur émergente — c'est de la puissance brute sans identité.**

**Source** : [GDC 2019 Giovannetti / MegaCrit](https://www.gdcvault.com/play/1025731/-Slay-the-Spire-Metrics) : « the power of a card must match its complexity — a rare that does nothing complex is worse than a common with a twist, because it breaks the expectation of value-for-complexity ». Le rang-5 (coût = 5, le maximum) exige soit une règle nouvelle soit une mécanique croisée. Un stat-stick à rang-5 n'est pas juste un trou sémantique — c'est une déception de pick économique (le joueur paye 5 or pour « plus de dmg/cd »).

**Pour nos contraintes async** : les snapshots capturent `{id, level, col, row}` — un `deep_kraken` niveau 3 (×3.0 stats) a DPS=0.462 de frappe. Un ghost tier-4/5 avec `deep_kraken × 3` est un mur de DPS brut sans lecture de counter-play (pas de trigger conditionnel, pas d'axe à exploiter). **Dans une méta async où les builds adverses sont figés, un stat-stick apex amplifie les matchups ennuyeux** (les décisions de placement ne comptent pas face à un mur de DPS pur).

**Proposition** (§P-A) : `skull_colossus` et `deep_kraken` sont **bloquants pour le rang-5**, pas une décision différable. Deux options :
- **(a) Rétrograder rang-4** (libère 2 slots rang-5, les stats restent dans leur budget rang-4 : skull_colossus HP=92/dmg=11/cd=84 → DPS=0.131 est _élevé_ pour rang-4 mais gérable si aggro=40 justifie le rôle tank-burn) ;
- **(b) Ajouter une règle d'équipe** à chacun (`skull_colossus` : `grant_team {burnNoDecay}` à la mort OU AoE splash burn — crée un finisher tank-burn grimdark cohérent ; `deep_kraken` : `grant_team {poisonNoCap}` **en doublon de `festering`** = problème de niche — donc option (a) préférable).

**Décision avant P3** (l'équilibrage auto ne doit pas normaliser des unités dans le mauvais rang).

---

### 2.2 DÉSACCORD — La règle P90/P10 ≤ 3× est un bon garde-fou de SPREAD mais ne résout pas la REDONDANCE DE NICHE. Burn et bleed rang-2 ont des paires quasi-identiques qui passent le test de spread mais violent l'axiome « 1 unité = 1 niche »

**Ce que le brouillon dit** (§3.1 col B, round 6) : règle P90/P10 ≤ 3× + catégorie NICHE/POOL/Sain dans la colonne B. Brouillon ajoute catégorie « DOUBLE-VALEUR ». Ce n'est pas contesté — mais c'est insuffisant.

**Ce qui est calculé ce round** (données vérifiées depuis `units.lua`) :

**BURN rang-2 (5 enablers dans `U.pool`)** :
```
  emberling     : burn dps=6, dur=150, decay      DPS_frappe=0.100
  pyre_herald   : burn dps=6, dur=170 (v7)        DPS_frappe=0.109  ← ≈ emberling (dps+10%)
  cinder_cur    : burn dps=4, dur=120, refresh     DPS_frappe=0.118
  zeal_inquisitor: burn dps=5, dur=180 (v7)       DPS_frappe=0.118  ← ≈ cinder_cur (dps+25%)
  pyre_tender   : burn dps=10, dur=180             DPS_frappe=0.097  ← seul à dps=10 burn
```

`emberling` et `pyre_herald` sont quasi-identiques sur l'axe burn (même dps=6, dur proche) — leur seul différentiel est le DPS de frappe (0.100 vs 0.109). `cinder_cur` et `zeal_inquisitor` partagent un DPS de frappe identique (0.118) avec des burn-dps proches (4 vs 5). **Seul `pyre_tender` (burn dps=10) a une niche distinctive (brûlure intense courte — archétype « brûleur lourd »).**

**BLEED rang-2 (5 enablers dans `U.pool`)** :
```
  hookjaw       : bleed dps=1, dur=300, slow=30%  DPS_frappe=0.056  ← slow-specialist distinct
  razorkin      : bleed dps=2, dur=240, slow=20%  DPS_frappe=0.109
  gash_fiend    : bleed dps=3, dur=240, slow=20%  DPS_frappe=0.104  ← ≈ razorkin (dps+50%, slow=même)
  wailing_shade : bleed dps=2, dur=200, slow=15% (v7) DPS_frappe=0.115 ← ≈ razorkin (dps=même)
  byakhee       : bleed dps=3, dur=180, slow=10% (v7) DPS_frappe=0.160 ← ≈ gash_fiend (dps=même, slow-10%)
```

`razorkin`, `gash_fiend`, `wailing_shade` : trois unités bleed rang-2 avec des paramètres à ≤20 % d'écart sur la dimension principale (bleed-dps=2-3, slow=15-20%). La règle d'audit (colonne B : « params ≤20 % = NICHE ») les signale toutes — mais le brouillon n'identifie pas que **c'est une triple redondance**, pas un cas isolé.

**Source psychologique** : [SAP design analysis (a327ex.com)](https://a327ex.com/posts/super_auto_pets_mechanics) : « Chaque pet doit avoir un espace de décision propre — si deux pets font la même chose dans la même tranche économique, l'un d'eux est invisible ». Dans notre pool LOCAL (pas un pool partagé entre joueurs), deux enablers quasi-identiques au même rang apparaissent souvent en boutique simultanément → le joueur prend le premier qu'il voit → **l'autre n'existe pas pour lui** → la profondeur de collection imaginée (83 unités) ne se manifeste pas dans le jeu vécu (15-20 niches distinctes perçues).

**Vérification du seuil critique** : sur une boutique T2 (SHOP_SIZE=5, pool rang-2), la probabilité que deux enablers quasi-identiques co-apparaissent est non-négligeable. Avec 5 paires (burn: 2 paires, bleed: 1 paire forte + 1 paire moyenne) sur 23 unités rang-2, P(voir une paire dans une boutique T2) ≈ 30-40 % (calcul hypergéométrique) — **une paire quasi-identique toutes les 2-3 boutiques**.

**Différence avec la règle P90/P10 adoptée** : la règle mesure si les extrêmes DPS sont trop écartés (signal de lisibilité de rang). Elle ne mesure pas si deux unités adjacentes dans la distribution ont des niches distinctes. Les deux instruments sont nécessaires ; la règle P90/P10 seule est insuffisante.

**Proposition** (§P-B) : pour chaque famille et chaque rang, l'audit doit identifier non seulement les outliers DPS (colonne E, P90/P10) mais aussi les **paires de niche** (deux unités dont les paramètres d'effet sont à ≤20 % d'écart sur leur axe principal). Pour les paires identifiées :
- Décision editoriale avant P3 : différencier l'axe OU retirer une des deux de `U.pool`.
- Priorité candidates : `pyre_herald` (doublon d'`emberling`), `wailing_shade` (doublon de `razorkin`), `byakhee` (doublon de `gash_fiend`). La décision de cohorte v7 (§3.2 ROADMAP) doit explicitement adresser ces trois unités.

---

### 2.3 DÉSACCORD NOUVEAU — La famille choc est la seule avec 11 unités dans `U.pool` et AUCUN rang-5 : elle est structurellement tronquée et les 4 rang-2 choc créent une densité early non justifiée par un apex late

**Ce que le brouillon dit** (§3.7) : « ladder choc 5/3/2 — cf. CLAUDE.md §3 ». `skull_colossus` et `deep_kraken` (rang-5 v7) sont signalés comme stat-sticks. Le ladder choc est mentionné comme « différé ».

**Ce qui est lu dans `units.lua` ce round** :

```
Choc dans U.pool :
  Rang-1 : live_wire (1 unité)
  Rang-2 : stormcaller, thunderhead, static_swarm, siphon_jelly (4 unités)
  Rang-3 : stormlord, storm_anchor (2 unités)
  Rang-4 : galvanizer, dynamo_priest, arc_warden, rust_sentinel (4 unités)
  Rang-5 : AUCUN
  Total  : 11 unités — densité égale aux autres familles DoT (burn=13, bleed=13, poison=15)
           MAIS sans apex T3/rang-5
```

**Asymétrie avec les 4 autres familles** :
```
  burn   : rang-5 = ash_maw (T3-transform) + plague_pyre (croisé)         ← apex OK
  bleed  : rang-5 = slow_bleed (T3-transform) + marrow_drinker (croisé)   ← apex OK
  poison : rang-5 = festering (T3-transform) + venom_censer (detonation)  ← apex OK
  rot    : rang-5 = pit_maw (T3-transform) + wither_bloom (placeholder)    ← apex partiel
  choc   : rang-5 = AUCUN                                                  ← MANQUANT
```

**Problème mécanique** : un joueur qui monte un build choc jusqu'au shopTier 5 (cotes rang-5 = 10 %) cherche naturellement un apex T3 pour son archétype. Il n'en existe pas. L'absence d'apex n'est pas documentée pour le joueur — il pensera que le pool ne lui propose pas de rang-5 choc par malchance, pas par absence de design. **Pour un jeu où la boucle de rétention est le « qu'est-ce que la boutique va me proposer ? »** (VRR boutique, §2.9 ROADMAP), une famille sans surprise apex est une boucle tronquée.

**Le problème des 4 rang-2 choc** : avec 4 enablers rang-2 choc (stormcaller/thunderhead/static_swarm/siphon_jelly) dans un pool où le rang-2 est fortement représenté (~30 % des offres en T2), le joueur voit fréquemment du choc en early — mais ne peut jamais closing un build choc avec un T3 en late. **La représentation early/late est inversée** : abondance en T1-T2, désert en T5.

**Comparaison cross-famille** : rot a `wither_bloom` (rang-5 placeholder) et `pit_maw` (rang-5 T3) — deux apexes, même si `wither_bloom` est un placeholder. Bleed a deux T3 solides. Choc n'a rien. **Ce n'est pas une lacune mineure à combler « quand le contenu l'exige » — c'est un archétype entier sans conclusion de run.**

**Source design** : [Slay the Spire card design (Giovannetti GDC 2019)](https://www.gdcvault.com/play/1025731/-Slay-the-Spire-Metrics) : « every archetype must have a closing move — a card that says 'this is what your deck was building toward.' Without a closing move, the archetype feels incomplete no matter how good the early cards are. » L'analogie ne transfère pas si le « closing move » est un mécanisme alien à notre système — mais dans notre contexte, un rang-5 choc avec `grant_team {shockChain}` ou un `dischargeAll` d'équipe est exactement l'équivalent. L'axiome psychologique transfere : un archétype sans apex = joueur qui sent que son build « n'est pas complet ».

**Pour nos contraintes async** : un ghost choc (snapshot tier-4+) sans rang-5 est structurellement moins menaçant qu'un ghost poison ou burn avec T3. La méta async favorise donc automatiquement les familles avec apex. `--meta-convergence` (§7.1, #A) mesurerait une convergence artificielle vers les familles DoT avec apex — pas une préférence joueur.

**Proposition** (§P-C) : le ladder choc est une priorité de CONTENU, pas seulement un « quand le contenu l'exige ». Deux options :
- **(a) Réorienter `skull_colossus`** (rang-5 v7 burn, HP=92 + aggro=40) en **apex choc** en changeant son effet : `grant_team {shockChain}` ou `grant_team {shockCleave}` (cleave aux voisins de la cible lors d'une décharge) — sa morphologie tank-massif est grimdark-cohérente pour un « conducteur d'éclairs ». La mutation de famille (burn→choc) est une décision data, 0 moteur.
- **(b) Créer un rang-5 choc dédié** comme 12e unité choc : transform logique = `grant_team {shockChain}` (les décharges se propagent à un voisin de la cible). Coût = 1 ligne data.

Dans les deux cas, `skull_colossus` sort du rang-5 burn (où `ash_maw` + `plague_pyre` suffisent) et comble le trou choc. Cela résout simultanément §2.1 (stat-stick inapproprié rang-5 burn) et §2.3 (apex choc manquant).

---

### 2.4 DÉSACCORD MODÉRÉ — La cross-rank DPS cohérence est rompue pour bleed : `byakhee` rang-2 (DPS_frappe=0.160) domine `vein_splitter` rang-3 (DPS_frappe=0.091). Cette inversion n'est pas documentée

**Ce que le brouillon dit** : §3.1 col E impose « DPS base rang-2 < médian rang-3 ». L'anomalie `cinder_cur`/`zeal_inquisitor` (rang-2 DPS=0.118) > `bellows_priest` (rang-3 DPS=0.086) est signalée.

**Ce qui est non signalé** (données calculées ce round) :
```
  byakhee (rang-2, bleed v7) : 8/50 = 0.160 DPS_frappe
  vein_splitter (rang-3, bleed T2) : 4/44 = 0.091 DPS_frappe
  Ratio byakhee/vein_splitter = 1.76×
```

`byakhee` (rang-2, 2 or) a un DPS de frappe 76 % supérieur à `vein_splitter` (rang-3, 3 or). Le contrat `cost=rank` est brisé ici, et plus sévèrement que l'anomalie `cinder_cur`/`bellows_priest` (ratio 0.118/0.086 = 1.37×).

La cause est que `byakhee` est une unité v7 ajoutée pour les familles visuelles (« vague v7 : familles visuelles peuplées », commentaire `units.lua:480`) sans calibrage cross-rank. Son bleed-dps=3/slow=10% n'est pas absurde pour un rang-2, mais son DPS_frappe=8/50 est emprunté au profil d'un rang-3 carry.

**Source** : décision #10 (`cost=rank = contrat d'apprentissage avec le joueur`) — un joueur rationnel qui voit `byakhee` à 2 or ET `vein_splitter` à 3 or dans la même boutique T3 n'achète pas `vein_splitter`. L'inversion cross-rank est le cas le plus grave de signal `cost=rank` cassé (pire qu'une anomalie intra-rang, parce qu'elle concerne deux tiers différents).

**Proposition** (§P-D) : dans l'audit P0.5, ajouter à la colonne E la règle cross-rank : « Pour les enablers DoT, DPS_frappe rang-(n) < médian DPS_frappe rang-(n+1) » (déjà partiellement définie dans le brouillon, mais `byakhee` vs `vein_splitter` en est une violation non citée). `byakhee` doit soit :
- Réduire dmg de 8 à 5-6 (DPS frappe 0.100-0.120, dans le budget rang-2 burn) ;
- Ou rétrograder en rang-3 (avec stats rang-3 complètes = refonte significative).

---

## 3. Propositions priorisées

### P-A — `skull_colossus` et `deep_kraken` rang-5 : décompression BLOQUANTE avant P3 (budget cassé ET sémantique incorrecte)

**Quoi** : deux stat-sticks v7 rang-5 dominent en DPS brut tous les T3 transforms légitimes. `deep_kraken` DPS=0.154 dépasse `marrow_drinker` (meilleur T3) de 34 %. **Décision binaire** :
- Option (a) RECOMMANDÉE : rétrograder `skull_colossus` en rang-4 (aggro=40, HP=92, burn simple → profile bruiser-tank rank-4 cohérent ; si aggro=40 + burn passif = double-valeur, réduire un paramètre) + réorienter `skull_colossus` comme candidat apex choc via un `grant_team` burn-decay-on-death (grimdark : le colosse brûlant qui en mourant embrase ses alliés d'éclairs). `deep_kraken` → rang-4 OU rang-3 (HP=84 est trop haut pour rang-3, rang-4 semble correct). Les deux quittent rang-5 = rang-5 burn = ash_maw+plague_pyre (propre), rang-5 poison = festering+venom_censer (propre).
- Option (b) : ajouter une règle d'équipe à chacun pour justifier le rang-5. Mais `deep_kraken` avec `grant_team {poisonNoCap}` duplique `festering` → option (a) supérieure.

**Coût** : décision data, 1-2 lignes `units.lua`. Si rang-5 choc manque toujours → voir P-C.
**Priorité** : haute (bloquant P3 — l'équilibrage auto doit traiter des rangs corrects).

---

### P-B — Audit des paires de niche intra-famille-rang (complète la règle P90/P10) — AVANT P1

**Quoi** : pour chaque famille × rang dans `U.pool`, identifier les paires d'unités dont les paramètres de l'effet principal sont à ≤20 % d'écart. Décision pour chaque paire :
- Différencier l'axe (ex : transformer un doublon `bleed dps=2 slow=20%` en `bleed dps=2 + épines` ou `bleed dps=2 + ramp-on-miss`) ;
- OU retirer la plus faible de `U.pool` (garder en `U.order` pour encounters IA).

**Candidats prioritaires** (calculés ce round) :
- `pyre_herald` vs `emberling` (burn dps=6, rang-2) → `pyre_herald` sans niche distincte du pool (différentiel = 9% DPS frappe + durée légèrement longue) ;
- `wailing_shade` vs `razorkin` (bleed dps=2 slow=15-20%, rang-2) → différentiel = 4% DPS frappe ;
- `byakhee` vs `gash_fiend` (bleed dps=3 slow=10-20%, rang-2) → doublon quasi-parfait avec DPS frappe 54% supérieur (c'est aussi une violation cross-rank, §P-D).

**Coût** : audit tableur + 1-3 décisions editoriales. 0 moteur, 0 invariant. Si une unité retire implique une famille sous le plancher ≥2 → vérifier avant de retirer (rot rang-2 a seulement 2 enablers, ne pas en retirer un).
**Priorité** : haute (la règle P90/P10 seule est insuffisante ; l'audit colonne B requiert ce complément pour être actionnable).

---

### P-C — Créer ou récupérer un apex rang-5 pour le choc (NÉCESSAIRE avant P1 — les types choc doivent avoir un apex)

**Quoi** : la famille choc est la seule sans rang-5 dans `U.pool`. Le déplacement de `skull_colossus` (§P-A) libère un slot rang-5 burn mais ne résout pas le trou choc.

**Option recommandée** : si `skull_colossus` (aggro=40, HP=92) est réorienté choc → sa morphologie tank-massif est cohérente avec un apex « conducteur-terminateur » (le tank qui amplifie les décharges de l'équipe). Effect suggéré : `grant_team {shockChain}` (les décharges sautent à un voisin de la cible au rang-5) — c'est un `teamFlag` qui s'insère dans le moteur existant (`ops.lua`, `teamFlags` posés par `grant_team`, relu). Budget stat : réduire dmg/cd pour DPS=0.100-0.110 (rang-5 T3 pur, pattern cohérent avec `ash_maw` 0.100 / `festering` 0.100).

**Si option (a) P-A non retenue** : créer une unité rang-5 choc dédiée (1 ligne data + effet `grant_team {shockChain}`). Coût minimal.

**Pourquoi avant P1 (types)** : le compteur de type choc (palier 2/4) sera défini avec `dot_family="choc"`. Si le ladder choc n'a pas d'apex, le palier-4 type choc est accessible mais sans conclusion de run — le joueur commit sur 4 unités choc et ne trouve jamais de T3. La déception de palier sans apex = mort de l'archétype ranked.

**Coût** : data + optionnellement 1 entrée `U.pool`. 0 moteur si `shockChain` est déjà un `teamFlag` enregistrable (le moteur supporte les `teamFlags` sans modification, cf. `arena.lua` `teamFlags` lu à `combat_start`).
**Priorité** : haute (bloquant sur l'expérience de l'archétype choc en ranked et sur la cohérence du lot P1 types).

---

### P-D — Règle cross-rank DPS explicite + `byakhee` (violation rang-2>rang-3) dans l'audit P0.5

**Quoi** : ajouter à la colonne E de l'audit une vérification cross-rank : « DPS_frappe rang-2 < médian DPS_frappe rang-3 » par famille. Documenter `byakhee` (rang-2, DPS=0.160) > `vein_splitter` (rang-3, DPS=0.091) comme violation bleed — la plus sévère cross-rank après les anomalies burn déjà signalées.

**Décision `byakhee`** : réduire dmg de 8 à 5-6 (DPS frappe 0.100-0.120, budget rang-2) ou rétrograder. La question est tranchée en même temps que la décision de cohorte v7 (§3.2 ROADMAP).

**Coût** : audit + 1 param `units.lua`. 0 moteur.
**Priorité** : moyenne (couverte partiellement par la décision de cohorte v7 ; le sig est moins fort que §P-A/§P-B/§P-C, mais doit être documenté pour que l'audit soit complet).

---

## 4. Questions ouvertes

**Q1 — `wither_bloom` (rang-5, rot-T3 placeholder) : quel est son `afflictionCount` réel après le fix C2 (§3.8 ROADMAP) ?**

`wither_bloom` (`units.lua:280-287`) pose rot(base=2) + bleed(dps=0) + poison(dps=0). Après le fix C2 (`afflictionCount` ne compte que les dps réels), `wither_bloom` comptabilise 1 famille active (rot dps>0) — soit `afflictionCount=1` ≠ 3 (le bug pré-C2). Cela signifie que `wither_bloom` seul **ne déclenche pas `plague_communion`** après C2. Sa valeur dans un build multi-affliction chute : il pose 3 familles mais seulement 1 a du dps réel. Est-ce que son rôle de « multi-affliction proxy » survit à C2, ou doit-il être reconçu avec des dps non-nuls sur bleed et poison (slow=15%+weaken=10% seraient alors des effets secondaires, pas les axes principaux) ?

**Q2 — La famille rot a 2 enablers rang-2 (rot_hound, bore_worm) quasi-identiques : est-ce un trou (manque d'un 3e distinct) ou une représentation saine ?**

Les deux unités partagent le même op rot (base=1, growth=1) avec des paramètres proches (dur=240 vs 210, cap=10 vs 8, maxHp=15% vs 12%). Niche quasi-identique → colonne B = NICHE (une doit se différencier). Options : bore_worm avec un twist conditionnel (rot qui accélère si cible a un autre DoT) ou différentiation de capDps. Mais rot rang-2 = 2 unités seulement — en retirer une sans plancher alternatif = rot sous le seuil ≥2. **La décision de cohorte v7 doit peser ce trade-off.**

**Q3 — Le rang-3 choc (`stormlord`, `storm_anchor`) a-t-il une niche distincte du rang-4 (`galvanizer`, `dynamo_priest`, `arc_warden`) ?**

`stormlord` (rang-3, add=2, volt=4, cap=8) vs `galvanizer` (rang-4, add=2, bonus_first=6, auto-discharge). Le différentiel est le mécanisme de décharge : `stormlord` empile pour les alliés, `galvanizer` se décharge automatiquement. Ces axes sont distincts — OK. Mais `storm_anchor` (rang-3, add=2, persist=0.5) vs `arc_warden` (rang-4, chain=2) : les deux ont un comportement de décharge avancé. Le `burst_DPS_eq` de `storm_anchor` (rang-3) vs `arc_warden` (rang-4) n'a jamais été calculé. Si `storm_anchor` a un `burst_DPS_eq` > `arc_warden`, le contrat `cost=rank` est brisé dans la famille choc.

**Q4 — Quel est le plancher de BLEED rang-1 ?**

`gnaw_rat` (`units.lua:446`) : bleed dps=1, slow=8%, rang-1. C'est le seul bleed rang-1 (singleton, comme burn rang-1 `ash_moth` et rot rang-1 `carrion_pecker`). Soit 3 familles avec singleton rang-1 sur 5. Le brouillon documente burn et rot mais **ne mentionne pas `gnaw_rat` bleed rang-1** (§3.1 col plancher). La décision de plancher doit traiter les 5 familles uniformément.

---

## 5. Synthèse pour le round suivant

Par ordre de priorité pour rounds 8-10 :

1. **`skull_colossus` et `deep_kraken` rang-5 = stat-sticks qui dominent les T3 transforms en DPS brut** (§2.1/P-A) : `deep_kraken` DPS=0.154 > tous les T3. Bloquant avant P3. Décision : rétrograder rang-4 + récupérer un candidat pour l'apex choc.

2. **Apex choc manquant dans `U.pool`** (§2.3/P-C) : seule famille sans rang-5. Build choc sans conclusion de run. Bloquant sur l'expérience archétype avant P1 (types). Option économique : réorienter `skull_colossus` rétrograté en apex choc.

3. **Paires de niche quasi-identiques rang-2** (§2.2/P-B) : la règle P90/P10 passe (2.11×) mais masque 5 paires problématiques (`pyre_herald`/`emberling`, `wailing_shade`/`razorkin`, `byakhee`/`gash_fiend` entre autres). Décision de cohorte v7 doit les adresser.

4. **`byakhee` rang-2 DPS=0.160 > `vein_splitter` rang-3 DPS=0.091 = violation cross-rank sévère** (§2.4/P-D) : à corriger dans la décision de cohorte v7.

5. **Singleton bleed rang-1 (`gnaw_rat`) non documenté** (Q4) : 3 familles sur 5 ont un singleton rang-1, mais seuls burn/rot sont cités dans le brouillon. Audit à compléter.

---

## 6. Index des sources

**Internes (lecture seule, ce round)** :
- `src/data/units.lua` — intégralité relue, DPS calculé sur 83 unités (calculés en Python sur les params lus)
  - `skull_colossus` : ligne 421-424 (burn on_hit ONLY, rang-5, DPS=0.131)
  - `deep_kraken` : ligne 437-440 (poison on_hit ONLY, rang-5, DPS=0.154)
  - `byakhee` : ligne 401-404 (bleed rang-2 v7, DPS=0.160)
  - `vein_splitter` : ligne 195-197 (bleed rang-3, DPS=0.091)
  - `pyre_herald` : ligne 397-400 (burn rang-2 v7, DPS=0.109)
  - `emberling` : ligne 67-69 (burn rang-2, DPS=0.100)
  - `wailing_shade` : ligne 393-396 (bleed rang-2 v7, DPS=0.115)
  - `razorkin` : ligne 71-73 (bleed rang-2, DPS=0.109)
  - `gnaw_rat` : ligne 446-448 (bleed rang-1 singleton)
  - `wither_bloom` : ligne 280-287 (rot-T3 placeholder, 3 familles dont 2 à dps=0)
  - `storm_anchor` : ligne 331-334 (choc rang-3, persist=0.5)
  - `arc_warden` : ligne 327-330 (choc rang-4, chain=2)
  - `stormlord` : ligne 318-320 (choc rang-3, volt=4)
  - `galvanizer` : ligne 311-316 (choc rang-4, auto-discharge)
- `src/effects/ops.lua` (lu : `teamFlags`, `grant_team`, `shockChain` non encore enregistré mais architecture existante)
- `src/run/state.lua` (SHOP_SIZE=5, relu)
- `docs/roadmap-lab/00-state.md` (§2.1 roster, §3.1 familles, décision #10)
- `docs/roadmap-lab/ROADMAP-draft.md` (v7, §3.1 audit, §3.2 cohorte v7, §3.7 rang-5)
- `docs/roadmap-lab/rounds/r06-units-power.md` (P-A à P-E adoptées/en attente)
- `docs/roadmap-lab/round-06.md` (§1.17 plague_communion, §1.20 colonnes A-J)

**Sources web vérifiées ce round** :

- [GDC 2019 Giovannetti / MegaCrit — « Slay the Spire: Metrics Driven Design »](https://www.gdcvault.com/play/1025731/-Slay-the-Spire-Metrics) :
  « the power of a card must match its complexity » + « 18 million simulated runs per balance patch ». Fonde §2.1 (stat-stick rang-5 = déception valeur-complexité) et §P-C (apex archétype = closing move nécessaire).

- [SAP design analysis — a327ex.com](https://a327ex.com/posts/super_auto_pets_mechanics) :
  « 1 trigger = 1 valeur » + « Early tiers = introduction à chaque mécanique ». Fonde §2.2 (paires quasi-identiques = unité invisible) et §1.4 (3 singletons rang-1 non tous documentés).

- [TFT Roles Revamped — teamfighttactics.leagueoflegends.com](https://teamfighttactics.leagueoflegends.com/en-us/news/game-updates/roles-revamped-and-item-changes/) :
  « every unit is now rewarded with mana for doing what they're supposed to be doing » — chaque unité a un rôle lisible distinct par son comportement, pas seulement ses stats. Corrobore §2.2 (différentiel de DPS frappe ≠ différentiel de niche ; la niche se lit dans l'effet, pas dans le dmg/cd).

- [Ariely, Loewenstein & Prelec 2003 — Coherent Arbitrariness (QJE)](https://academic.oup.com/qje/article/118/1/73/1917051) :
  Ancrage par comparaison simultanée. Déjà cité r06 §2.1 — repris en r07 pour §2.1 (deep_kraken DPS=0.154 en boutique T5 ancre la perception des T3 transforms) et §2.4 (byakhee rang-2 visible au même tier que vein_splitter rang-3).

- [Entalto Studios — « 5 Essential Tips to Make Your Roguelite Game Work »](https://entaltostudios.com/5-essential-tips-to-make-your-roguelite-game-work/) :
  « Build identity must be clear within 2 minutes of a run. » Fonde §2.3 : un archétype choc sans apex ne peut pas former une identité de run late — la clarté de build (« je joue choc ») ne survit pas au tier 5 si aucune unité rang-5 n'est disponible.

---

*Round 07 rédigé le 2026-06-23. Lecture seule du repo jeu. Écriture uniquement sous `docs/roadmap-lab/`. Piliers respectés : async snapshots / sim déterministe seedée / DA grimdark / pixel art procédural. DPS calculés ce round par calcul direct (dmg/cd) sur params lus dans units.lua (83 unités).*
