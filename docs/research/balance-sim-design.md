# Méthodologie d'équilibrage par simulation — The Pit

> Doc de référence du **banc d'essai** (Pilier B `tools/runsim.lua` + Pilier A Proving Ground +
> Pilier C MCP). Source de vérité du modèle d'investissement = `src/lab/compcost.lua` (ce doc le
> documente, le code l'exécute). À lire avant d'interpréter un `runs/runreport.json`.

## 1. Le principe directeur : le win% brut ne vaut rien seul

Un autobattler N'EST PAS équilibré quand toutes les compos gagnent 50%. Il l'est quand **la puissance
est proportionnelle à l'investissement** et que les **counters sont lisibles**. Trois corollaires :

1. **Une compo avancée DOIT battre une compo moins investie.** Si une build exige une gestion parfaite
   (forme de board précise, monstres rares dans le bon ordre, reliques), il est *normal* qu'elle écrase
   un adversaire moins abouti. Ce n'est pas un déséquilibre, c'est la **récompense de la maîtrise**.
2. **Les counters sont sains.** Poison/feu qui se répand qui bat un mur tank = attendu. On ne « corrige »
   pas un counter intentionnel ; on le *documente* (§4) pour ne pas le flaguer.
3. **On ne flague que l'anormal** : une compo qui gagne **SOUS son coût** (investissement ≤ celui de
   l'adversaire mais win% nettement > 50%), HORS counter intentionnel. C'est le seul signal d'alarme.

## 2. Taxonomie des archétypes

| Archétype | Idée | Sigil aimé | Pièce clutch (T3) |
|---|---|---|---|
| **poison** | empile des stacks + malus, contagion, détonation | diamant (go-wide) | `festering` (ignore le cap) |
| **burn** | burst qui décroît, lèche le bouclier, propage à la mort | ligne (conduit) | `ash_maw` (no-decay d'équipe) |
| **bleed** | bas dps + slow de cadence (déni de tempo) | anneau (boucle) | `slow_bleed` (slow d'équipe) |
| **rot** | enfle, **ampute les PV max** (tueur de mur) | carré (hiérarchie) | `pit_maw` (rot sur toute l'équipe) |
| **shock** | amplifie les dégâts-pris (1 unité, ladder différée) | carré | — |
| **tank** | mur PV + taunt + boucliers + **regen (anti-DoT)** | carré | — |
| **bruiser** | stats brutes, zéro DoT (la compo TÉMOIN) | carré | — |

Le classifieur `Policies.archetypeOf(id)` dérive l'archétype des **effets** (op poison/burn/bleed/rot/shock,
regen/taunt/aggro→tank, sinon bruiser). Sert aux politiques *committed* ET à l'étiquetage d'analyse.

## 3. Modèle d'investissement (`compcost.lua`)

`Compcost.of(comp) → { gold, maxLevel, slots, relicDep, sigilDep, placementSens, rankPressure, duplicatePressure, score }`.

- **gold** = `Σ coût_unité · facteur_niveau` (facteur `{1,3,9}` : 3 copies→niv2, 9→niv3).
  Les slots de board sont désormais débloqués par le rythme de run, pas achetés en or, donc ils ne sont plus
  additionnés au coût brut.
- **placementSens** = part d'unités ayant ≥1 voisin de la compo via `shape.edges` (0 = un tas ; 1 = tout
  agencé → la compo *exige* un placement). Pure adjacence.
- **sigilDep** = 1 si sigil ≠ carré (topologie spécifique exigée). **relicDep** = 1 si reliques déclarées.
- **rankPressure** = plancher d'accessibilité dérivé du rang de boutique. Il empêche une composition avec une
  pièce rang 4/5 d'être lue comme "cheap" seulement parce que son prix brut en gemmes est faible.
- **duplicatePressure** = plancher d'accessibilite derive du nombre de copies necessaires aux niveaux 2/3.
  Il evite qu'un board avec plusieurs L2/L3 soit lu comme cheap seulement parce que le prix brut `3 copies`
  ne compte pas les rerolls, la place de banc et la variance d'acquisition.
- **score** ∈ (0,1] = mélange pondéré (poids nommés dans `compcost.lua`) :
  `0.40·norm(gold) + 0.25·(maxLevel-1)/2 + 0.10·(slots/9) + 0.05·relicDep + 0.05·sigilDep + 0.15·placementSens`.
  Le score final est le maximum entre ce mélange, `rankPressure` et `duplicatePressure`.

Les boutons à tuner : `LEVEL_GOLD = {1,3,9}`, `RANK_ACCESS_PRESSURE`, `RANK_GATE_MULT`,
`LEVEL_ACCESS_PRESSURE` et les 6 poids du score pondéré. Tout le reste est data-driven
(coûts/rangs/niveaux réels des unités + largeur/placement/reliques).

## 4. Counters INTENTIONNELS (ne jamais flaguer)

`tools/runsim.lua` porte la table `DESIGNED` = ce qu'on VEUT voir gagner (attaquant > défenseur) :

- `poison/burn/rot/shock > tank` : les DoT/altérations DOIVENT percer le mur (un mur immortel sonne faux
  en grimdark et tue l'axe d'exposition). Si la matrice montre l'INVERSE (`tank > rot` p. ex.), ce n'est
  **pas** suppressé → le drapeau tire → c'est une **dette d'équilibrage** (DoT sous-tuné vs mur).
- `bleed > bruiser` : le déni de tempo doit neutraliser les stats brutes rapides.
- `tank > bruiser` : le mur survit aux stats brutes sans altération.

**Sémantique clé** : `DESIGNED` encode l'INTENTION. Un drapeau qui tire = la réalité dévie de l'intention
(soit le counter voulu ne se produit pas, soit une domination non voulue apparaît). On cure cette table à
la main au fil des observations + du design voulu (ce n'est pas auto-généré).

## 5. Les trois lectures du `runreport.json`

1. **Runs par politique** (escalade PvE, N runs) : `completion%` (atteint 10 victoires), `avg_rounds`,
   `combat_wr`, `invest` final. Répond « quelle STRATÉGIE réussit sous contrainte d'acquisition réelle ».
   `random_baseline` est le **plancher** : toute politique sensée doit le battre.
2. **Matrice de counters** (compos parfaites, M matchs/cellule) : win% ligne-vs-colonne + `invest` par
   archétype. Lecture en regard de l'investissement (une ligne forte ET chère = sain ; forte ET pas chère
   = suspect). Les **drapeaux** listent les cellules « gagne sous son coût, hors counter intentionnel ».
3. **Fragilité** (perfect vs `missing_clutch`, tête-à-tête) : `edge` = avantage du perfect sur sa version
   amputée = **la valeur réelle de la pièce clutch**. `edge` ≈ 0 → la pièce est décorative (à buffer ou
   remplacer) ; `edge` élevé → pièce décisive (snowball à surveiller).

## 6. Politiques (Pilier B) = personas (Pilier C)

Même taxonomie, deux incarnations. Code déterministe (`src/lab/policies.lua`) :

| Politique | Stratégie | Ce qu'elle teste |
|---|---|---|
| `greedy_stats` | dépense tout, remplit, monte de niveau | la ligne de base « bon joueur » |
| `econ_streak` | remplit au moins cher puis scale (board plein → niveau) | la valeur de l'éco/streak |
| `force_level_fast` | rushe le niveau (tous les slots vite) | le scaling de board bat-il la qualité ? |
| `committed_archetype(a,sigil)` | reshape + n'achète que l'archétype `a` (reroll pour trouver) | une COMPO précise sous contrainte de shop |
| `committed_*_plan` | cible un noyau exact + supports compatibles, vend les fillers faibles pour acheter le coeur, choisit reliques/commandants par coherence | accessibilite reelle d'un endpoint sous contrainte de shop |
| `committed_*_coverage_plan` | comme `*_plan`, mais bloque l'XP au-dessus d'un rang plancher tant que la couverture cible est trop basse | timing XP/reroll : stabiliser copies avant de monter de tier |
| `committed_rot_bleed_rat_core_plan` | reroll low-rank vers `rot_bleed_rat_core` au lieu de forcer `marrow_drinker` | baseline actuelle du pivot rot/bleed sans rang 5 obligatoire |
| `random_baseline(rng)` | hasard (RNG injecté) | le plancher |

Au Pilier C (MCP), ces mêmes profils deviennent des **personas LLM** (prompts) : un agent joue une vraie
partie via les outils et rend un retour QUALITATIF (fun, frustrations, builds émergents) que le batch
quantitatif ne capte pas.

Les rapports economie exposent aussi les decisions de timing du plan :

- `xp_gate_blocks_per_run` et `xp_gate_block_round_rate` : combien de fois une
  politique a retenu l'XP parce que son coeur n'etait pas assez couvert.
- `avg_xp_gate_unit_coverage` et `avg_xp_gate_level_coverage` : niveau moyen de
  couverture au moment ou la barriere XP a ete evaluee.

## 7. Limites connues / à itérer

- **N/M faibles = bruité** (la matrice sort des 0%/100% tranchés). Monter N≥100, M≥50 pour un signal stable.
- **Adversaire = escalade PvE** par défaut (encounters par round, cf. `Build:pickEncounter`). Le verdict
  DÉPEND de ce choix ; option ghost-pool / policy-vs-policy à activer pour varier la référence.
- **Shop uniforme** (pas de raretés/cotes-par-niveau) : les archétypes à unités rares (tank) sont
  STARVÉS → un `committed_tank` sous-field. À revoir quand les raretés arrivent.
- **Compos parfaites = late-game (boardLevel 7-9)**. L'axe board-level (early/mid) s'enrichit en P5.
