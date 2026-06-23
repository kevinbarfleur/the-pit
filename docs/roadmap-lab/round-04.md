# Round 04 — Synthèse (SYNTHETISEUR)

> **Rôle** : acter le round 4/10 du roadmap-lab. Intègre **de façon critique** les 6 critiques de
> lentille (`rounds/r04-*.md`) contre `ROADMAP-draft.md` v4 et la synthèse `round-03.md`. **Débat,
> pas addition** : j'adopte les critiques valides et sourcées, je rejette/tempère les faibles (en
> disant pourquoi), je consigne les VRAIS litiges pour le round 5. La roadmap intégrée vit dans
> `ROADMAP-draft.md` (réécrit en v5).
>
> **Garde-fous** : lecture seule du repo ; n'édite que sous `docs/roadmap-lab/`. Piliers : async
> snapshots / sim déterministe seedée / DA grimdark / pixel art procédural. 32 invariants préservés.
>
> **Inputs** : `BRIEF.md`, `ROADMAP-draft.md` (v4), `00-state.md`, `round-0{1,2,3}.md`, les 6
> `rounds/r04-{progression-economy, ranked-competitive, relics, retention-addiction,
> synergies-effects, units-power}.md`.
> **Vérifs code menées par le synthétiseur ce round** (lecture seule, citées §6) :
> `src/data/relics.lua:34-58` (famines_math, feeding_frenzy, plague_communion réels) ;
> `src/combat/arena.lua:244-265` (condition réelle de plague_communion) ;
> `src/effects/ops.lua:208-217` (frenzy_gain EXISTE, broadcast aux ennemis du mort).

---

## 0. Méta-verdict du round

**Le round 4 est le round de la VÉRIFICATION FACTUELLE QUI CORRIGE LE DÉBAT LUI-MÊME.** Trois
rounds de convergence ont produit une roadmap dense et bien sourcée — mais ce round, en relisant
le code **ligne à ligne**, met au jour que **deux décisions adoptées au round 3 reposaient sur une
mauvaise lecture du code**, et qu'une troisième critique (de ce round) reproduit la même erreur.
C'est exactement la valeur d'un débat adversarial : sans la vérif, v5 aurait gravé du faux.

**Quatre résultats dominent :**

1. **CORRECTION STRUCTURELLE #1 — `plague_communion` n'a jamais été un gate « ≥4 même affliction ».**
   Le code réel (`arena.lua:248-252`, **vérifié synthétiseur**) : la relique pose `plagueAmp = 0.25`
   et amplifie **+25 % de TOUS nos dégâts contre une cible portant ≥2 *familles* d'affliction**
   (`afflictionCount(target.dots) >= 2`). La condition porte sur **l'ampleur d'affliction de la
   CIBLE ennemie**, PAS sur la composition de TON roster. Le « dead range 60 % du run » du round 3
   (litige #J) et toute la reformulation « +5 %/allié de l'affliction majoritaire » **répondaient à
   une relique qui n'existe pas**. La vraie relique est un **payoff multi-DoT** déjà élégant (une
   seule cible mixte le déclenche), qui **récompense les compos go-wide-affliction et la
   contagion** — exactement ce qu'on veut. → **litige #J REQUALIFIÉ** (la question n'est plus
   gate-vs-scalante mais « +25 % flat est-il la bonne valeur, et la condition ≥2-familles
   est-elle la bonne fenêtre »).

2. **CORRECTION STRUCTURELLE #2 — `feeding_frenzy`/`frenzy_gain` EXISTE et récompense déjà les
   KILLS ENNEMIS.** r04-relics (Prop-D/Q3) craint un « bug silencieux » (op manquant) et propose
   de « reformuler pour récompenser les kills ennemis, pas les morts alliées ». **Les deux sont
   faux** : `ops.lua:211-217` implémente l'op, et son commentaire dit explicitement « l'arène ne
   diffuse `on_death` qu'aux ENNEMIS du mort → `ctx.source` = une de NOS unités qui survit au kill
   → chaque mort **ennemie** renforce nos frappes » (**vérifié**). La relique fait **déjà** ce que
   la critique réclamait. → **Prop-D et Q3 (relics) REJETÉES sur le fond** (la prémisse est fausse) ;
   seul survit un mini-todo : valider l'`on_death` cross-team dans `tests/relics.lua` (zone de test).

3. **CORRECTION VALIDE — `famines_math` (tall) est en conflit réel avec les slot-grants gratuits.**
   Là, r04-relics (§2.3) a raison : `relic_few_units` (`relics.lua:34`) donne +30 % dmg / +20 % HP
   tant que `#comp ≤ 3` ; or les rounds 2-7 **offrent** des slots, et l'option C de slot-decline les
   rend tentants. Une relique qui rend optimal de **refuser sa propre progression de slots** frôle
   le « gate sur la progression » (pilier reliques : égalisateur, jamais gate). C'est un **vrai
   litige neuf (#O)**, non vu rounds 1-3, code-vérifié.

4. **CONVERGENCE FORTE SUR DEUX PRÉCONDITIONS DE SIM À AVANCER EN P0.5.** *Deux lentilles
   indépendantes* (synergies §2.2, retention §2.3 ; appuyées units) demandent de **mesurer la cause
   structurelle de `poison > choc` AVANT de coder les types (P1)**, pas en drapeau P3 : si poison
   est `> +1σ` **structurellement** (propagation-à-la-mort à 100 % des stacks, non bornée par le cap
   d'output), un palier type +20 % sur poison **grave une méta cassée avant le ranked**. Le levier
   est chirurgical : `--poison-frac 0.5` (50 % des stacks propagés). De même, *deux lentilles*
   (synergies §2.3, appuyée par le risque de refonte de tests) demandent de mesurer la **variance
   positionnelle** (critère du litige #D) **en P0.5**, pour décider le design du compteur type
   (global vs adjacence) **avant** d'écrire les tests P1. → **deux drapeaux promus de P3 à P0.5.**

**Plus deux lacunes-moteur-de-rétention nommées par *deux lentilles distinctes*** : (a) un **moteur
PRÉ-RUN** du « lancer une run ranked » (afficher la récompense potentielle + la distance au prochain
tier) — *post-run signals ≠ pré-run pull* (ranked §2.1) ; (b) le **plafonnement inter-saisons** sans
rotation de contenu (la P4 arrive trop tard) — solution proposée : **Contrainte Permanente de
Saison** (teamFlag seedé, async-safe). Ces deux-là sont **adoptés** (forts, sourcés, coût quasi nul).

**Litiges tranchés ce round** : **#H'** (calendrier daily) → **10+ contraintes compositionnelles**
(axes famille × sigil × éco, data-only) ; **#J** → **REQUALIFIÉ** (voir §1.1, la relique réelle est
un payoff multi-DoT, plus un gate). **Litiges nouveaux** : **#N** (signal pré-run + pool = même
écran), **#O** (`famines_math` reformuler vs retirer), **#P** (rôle temporel shaper/payoff des
reliques + courbe de valeur), **#Q** (latence VRR du choc en early ⊃ leurre choc rang-1),
**#R** (variance de durée de run brise le critère de la courbe XP), **#S** (ciblage de l'ampli
choc-D : ordre fixe vs `dot_family` du poseur). **Tempérés/rejetés** : Prop-D & Q3 relics (prémisse
fausse) ; la généralité de la critique « bleed/rot redondants » (réelle mais c'est de la **lisibilité
i18n**, pas un trou de balance) ; le « 6e type tank » reste **orienté aucun** (la dispersion de DPS
tank est un sujet d'audit budget, pas un argument pour un palier tank).

---

## 1. CE QUI CHANGE DANS LA ROADMAP (et pourquoi)

### 1.1 CORRECTION MAJEURE (litige #J REQUALIFIÉ) — `plague_communion` est un PAYOFF MULTI-AFFLICTION, pas un gate, pas un « scalante par famille majoritaire »

**Source** : vérif synthétiseur `arena.lua:248-252` + `relics.lua:57-58`. **Contredit** la prémisse
de round-03 §1.x (litige #J), r04-relics §2.1/§2.2/Prop-B, r04-synergies §2.4/P4.

- **Code réel** (`relics.lua:57-58`) : `plague_communion` pose `grant_team {plagueAmp = 0.25}` à
  `combat_start`. **Code réel de l'effet** (`arena.lua:248-252`) :
  ```lua
  -- PLAGUE COMMUNION : une cible sous 2+ familles d'affliction prend +plagueAmp de TOUS nos dégâts.
  if opts.source and self.teamFlags then
    local stf = self.teamFlags[opts.source.team]
    if stf and stf.plagueAmp and afflictionCount(target.dots) >= 2 then
      amount = math.floor(amount * (1 + stf.plagueAmp) + 0.5)   -- +25 % flat
    end
  end
  ```
- **Ce que ça signifie vraiment** : la condition est **`afflictionCount(target.dots) >= 2`** — c.-à-d.
  la **cible ennemie** porte **≥2 familles de DoT distinctes** (ex. burn+poison sur le même ennemi).
  Quand c'est le cas, **TOUS nos dégâts** (frappe ET DoT) contre cette cible prennent **+25 %**.
  **Aucune référence au nombre d'unités de TON roster.**
- **Conséquences sur le débat** :
  1. Le « dead range : ≥4 même affliction = 57 % de la compo = inerte 60 % du run » du round 3 est
     **un fantôme** : la relique réelle n'a jamais demandé 4 unités d'une même affliction. Un seul
     ennemi mixte (trivial à produire avec 2 familles ou via contagion) la déclenche.
  2. La reformulation « +5 % par allié de l'affliction majoritaire » (round 3, gravée v4 §4.2) **est
     un design DIFFÉRENT et inférieur** : elle récompense le **mono-archétype** (aller large dans UNE
     famille), alors que la relique réelle récompense le **multi-affliction + la contagion** (mettre
     **plusieurs** familles sur l'ennemi). La relique réelle est **plus intéressante** (elle crée un
     archétype « cocktail de poisons » que rien d'autre ne pousse) et **mieux alignée grimdark**
     (« Drink of many poisons at once » — flavor réel, `relicons.lua:37`).
  3. Toute l'analyse r04-relics §2.1/§2.2 (« +15 % à 3 unités ≈ bloodstone, back-loaded ») et
     r04-synergies §2.4/P4 (« avantage poison go-wide, cap min(4,count) ») **portent sur le mauvais
     mécanisme** → **écartées**, mais leur *intuition* (une relique tier-4 doit dominer les tier-1
     sur SON archétype) est **conservée** et redirigée vers la vraie relique.
- **Nouveau cadrage du litige #J** : la question n'est plus « gate vs scalante » mais :
  - (a) **+25 % flat est-il la bonne magnitude** pour une tier-4 conditionnelle ? (à sim — comparer
    à `bloodstone` +14 % inconditionnel, comme le réclamait justement r04-relics Q1) ;
  - (b) **le seuil ≥2 familles est-il la bonne fenêtre** ? (≥2 est facile à atteindre en multi-DoT
    ET via contagion adverse — vérifier qu'il ne se déclenche pas *accidentellement* trop souvent, ni
    *jamais* sur un mono-build qui devrait quand même en profiter) ;
  - (c) **option scalante sur le seuil réel** : `plagueAmp` pourrait scaler avec
    `afflictionCount(target)` (2 familles = +20 %, 3 = +30 %, 4+ = +40 %) — récompense la **largeur
    d'affliction sur la cible**, cohérente avec le mécanisme réel, sans toucher le roster-count.
  → **À trancher en P1.5a + sim. GARDE LA RELIQUE TELLE QUELLE comme défaut** (elle est saine) ;
  n'optimise que la magnitude/scaling.
- **`plagueAmp` est `more` hors-cap** (confirmé `arena.lua:252`, multiplication directe post-cap) —
  reste un drapeau de sim (litige #B), inchangé.

### 1.2 CORRECTION (Prop-D & Q3 relics REJETÉES) — `feeding_frenzy` fait DÉJÀ ce que la critique réclamait

**Source** : vérif synthétiseur `ops.lua:208-217`, `relics.lua:38-39`, `i18n/en.lua:389`.

- r04-relics §2.5/Prop-D/Q3 affirme : (i) `frenzy_gain` n'est peut-être pas implémenté (« bug
  silencieux ») ; (ii) la relique récompense les **morts alliées** (« archétype kamikaze ») ;
  (iii) il faudrait la reformuler pour récompenser les **kills ennemis**.
- **Code réel** : (i) `ops.lua:211` **implémente** `frenzy_gain` (snowball de `me.dmg` cappé à 6
  stacks) ; (ii) le commentaire `ops.lua:208-209` précise « l'arène ne diffuse `on_death` qu'aux
  **ENNEMIS** du mort → `ctx.source` = une de NOS unités qui survit au kill » ; l'i18n confirme
  « **Each enemy that dies** makes your units strike harder ». → la relique récompense **déjà** les
  kills ennemis, **pas** les morts alliées.
- **Verdict** : **Prop-D et Q3 rejetées sur le fond** (prémisse fausse, code non lu par la critique).
  **Reste valide** : la *suggestion* d'un test explicite que l'`on_death` ne profite qu'au camp
  survivant (zone de test `tests/relics.lua`). Coût ~0, à ranger dans le mini-todo de tests P1.5a.
- **Leçon de méthode (consignée)** : r04-relics dit en propre fin « `frenzy_gain` NON TROUVÉ dans
  `seed/mechanics.md` → à vérifier dans `ops.lua` directement ». La critique a **honnêtement signalé
  son incertitude** mais a quand même rédigé Prop-D/Q3 comme si l'absence était probable. **Règle
  pour les rounds 5+** : une critique qui dépend de l'existence/non-existence d'un op DOIT grep le
  code avant de proposer une refonte, sinon la proposition est spéculative.

### 1.3 ADOPTÉ (litige #O NOUVEAU, code-vérifié) — `famines_math` (tall) est anti-growth, en conflit avec les slot-grants

**Source** : r04-relics §2.3, vérif synthétiseur `relics.lua:34-35`. **Valide.**

- `famines_math` : `relic_few_units {max=3, dmgInc=0.30, hpInc=0.20}` → bonus tant que `#comp ≤ 3`.
  Les rounds 2-7 **offrent** des slots (jusqu'à 9) ; l'option C de slot-decline (+1 or +1 XP) rend le
  refus déjà tentant. Avec `famines_math`, **accepter un 4e slot SUPPRIME le bonus** → la relique
  rend optimal de **refuser sa propre progression**. C'est une **contrainte permanente sur la
  croissance**, pas un « scope conditionnel » StS (qui est une contrainte *active*, pas un blocage de
  progression). Le pilier reliques (CLAUDE §2 : « égalisateur, jamais gate ») la prend en défaut.
- **Mais nuance (synthétiseur, à ne pas sur-corriger)** : ce conflit n'existe que parce que les
  slots sont **purement positifs** dans le modèle actuel. Un archétype « tall » (peu d'unités fortes)
  est **un vrai axe de design** (SAP, StS Snecko/small-deck). Le problème n'est pas « tall existe »,
  c'est que **rien d'autre dans le jeu ne valorise le tall** → la relique est le seul signal, et il
  va contre l'éco. → la résolution doit soit (a) rendre `famines_math` **non-anti-growth** (« tes 3
  unités les plus fortes ont +30 % » — toujours applicable), soit (b) la **retirer du pool** boutique
  (garder en `U.order` pour encounters IA). **Option (a) préférée** : elle préserve un signal tall
  sans casser l'éco, et c'est de la data (`R.apply`). **Litige #O** : (a) reformuler vs (b) retirer.

### 1.4 ADOPTÉ (FORT, 2 lentilles) — Promouvoir `--poison-frac` de P3 à P0.5 : mesurer la cause structurelle de `poison>choc` AVANT les types

**Source** : synergies §2.2/P2 + retention §2.3 (densité VRR choc) ; appuyé units §2.1. **Convergence.**

- **Argument mécaniste (synergies §2.2, code-ancré)** : la propagation-à-la-mort du poison
  (`spread_*_on_death` dans `ops.lua`, avec `festering:poisonNoCap`) peut faire qu'une cible accumule
  >8 stacks, meurt, et **propage** ses stacks aux voisins → **cascade auto-amplifiante** que **ni le
  cap ×3 d'output ni l'axe choc-D ne plafonnent** (`poisonNoCap` lève le cap de *stacks*, pas la
  propagation). L'axe D résout la **lisibilité** du choc, **pas** la hiérarchie inter-familles.
- **Pourquoi AVANT P1** : si poison est `> +1σ` **structurellement**, un palier type poison +20 %
  (P1) **amplifie une méta cassée** → le `--meta-convergence` (qui arbitre #A types-vs-ranked)
  mesurerait une convergence **artificielle**. On élimine la variable de confusion en mesurant et
  corrigeant **avant** de coder les types.
- **Levier (data-only, golden-safe)** : `--poison-frac <f>` dans `tools/sim.lua` ; op `contagion` lit
  `frac = p.frac or 1.0`. Mesurer `win_rate(poison) vs pool` à `frac=1.0` puis `frac=0.5` sur N=200.
  Si delta passe de `>+1σ` à `<+0.5σ` → activer `frac=0.5`. **Golden inchangé si défaut 1.0**.
- **Sous-question conservée (Q2 synergies)** : faut-il borner la propagation **des transforms T3**
  (`festering`/`venom_censer`) séparément du cap de stacks ? La T3 garde son identité (stacks
  illimités) ; seule la **propagation** est bornée proportionnellement. → paramètre `frac` de l'op
  suffit a priori (50 % de 12 = 6 vs 50 % de 8 = 4) ; à confirmer en sim.

### 1.5 ADOPTÉ (2 lentilles) — Promouvoir `--position-variance` de P3 à P0.5 : décider global-vs-adjacence AVANT d'écrire les tests P1

**Source** : synergies §2.3/P3 + le risque concret de refonte de tests. **Valide.**

- **Le critère du litige #D** (corrigé round 3 : `variance(win%) sur permutations positionnelles >
  0.05` = causalité, pas corrélation) **a besoin d'unités placées + sigil actif** → la donnée est
  disponible **dès les builds T2-T3 de P0.5**. La mesurer là (3 permutations/build, seed fixe) décide
  le **design** du compteur type (global v0.10 vs adjacence-type) **avant** de coder.
- **Risque évité (synergies §2.3)** : si le compteur global est codé en v0.10 et que v0.12 révèle une
  variance positionnelle forte, **refondre le compteur touche les tests P1 déjà écrits**. Mesurer en
  P0.5 supprime cette dette potentielle. Coût : ~20 lignes de sim (permuter `units={{id,level,col,row}}`).
- **Statut #D** : reste un litige (le défaut **global** tient si `std_dev(win%) < 0.02` sur 3
  sigils), mais **la mesure se déplace en P0.5**.

### 1.6 ADOPTÉ (FORT, ranked §2.1) — Moteur PRÉ-RUN du ranked : afficher la récompense potentielle + la distance au prochain tier (nouveau §6.11)

**Source** : ranked §2.1/P1. **Lacune réelle, bien démontée.**

- **Argument** : les marques sub-tier + `season_wins` sont des signaux **POST-run** ; ils
  n'**initient** pas une session. Le moteur du grind ranked est l'**incertitude résoluble** pré-run
  (« vais-je monter ce run ? » — seganerds.com 2026 : « uncertainty keeps you queuing »). TFT affiche
  le LP potentiel **à la sélection de mode** précisément pour ça (immortalboost, vérifié).
- **Transfert async (validé)** : notre grille est **statique** (`+4/+2/+1/0`) → l'affichage est plus
  simple que TFT (pas de calcul MMR). RENDER pur, pré-run, 0 invariant. Le mécanisme transféré est
  l'incertitude résoluble + le goal-gradient (« il vous manque 23 pts »), pas le calcul MMR.
- **Décision** : nouveau **§6.11** — écran de sélection ranked affiche la grille concrète + la barre
  vers le prochain tier. **Litige #N** (ranked §3.1) : **même écran** que le signal de pool (§6.5)
  — une seule décision (jouer ranked ou non) = toutes les infos ; séparer seulement si le retour user
  montre une surcharge.

### 1.7 ADOPTÉ (ranked §2.2) — Contrainte Permanente de Saison : renouveau inter-saisons sans contenu (nouveau §8.0, P4-light)

**Source** : ranked §2.2/P2. **Lacune réelle (plafonnement inter-saisons), solution async-safe.**

- **Problème** : TFT/HS:BG renouvellent la **méta** à chaque saison (nouveaux sets/tribus) → le
  joueur qui plafonne a du **neuf à apprendre**. The Pit v1 ne fait que resetter le rating (−20 %) ;
  les reliques G (vraie rotation) sont en P4, **trop tard** : le plafonnement intervient avant.
- **Solution (async-safe, vérifiée §4.2 ranked)** : **1 Contrainte Permanente par saison** active en
  **ranked hors-daily** (ex. « Ce Puits Brûle : unités burn +10 % cadence »). C'est un **`teamFlag`
  injecté à `combat_start` depuis le seed de saison** (distinct du seed de run) → s'applique aux **2
  camps** du snapshot **sans modifier le snapshot** (les snapshots restent figés ; le pool est séparé
  par `season_id`, déjà encodé dans `version`). Déterministe, reproducible, **invariant #2 préservé**
  (offres + seeds de combat inchangés), golden inchangé (le golden ne tourne pas avec un `season_id`).
- **Distinction des anomalies HS:BG rejetées** : HS:BG = aléatoire **par lobby** (incompatible
  snapshots). Notre contrainte est **identique pour tous** (dérivée du seed de saison) et **choisie
  par le designer**, pas subie. ✅ pilier.
- **Place** : **P4-light** (entre P2 ranked et P4 reliques G). Plus simple qu'une relique G (pas de
  topologie). **Q ouverte (ranked §5.2)** : cumul avec la Contrainte du Jour ? → **non-cumulable** (la
  daily override la saison pour la run daily). **Dépend de** P0.5 (`dot_family`) + P1 (types) pour les
  contraintes liées aux familles.

### 1.8 ADOPTÉ (ranked §2.4) — Post-combat ranked enrichi : métadonnées du ghost adverse (famille dominante, sigil)

**Source** : ranked §2.4/P3. **Crée la vraie asymétrie ranked/unranked, coût ~0.**

- **Argument** : en ranked le joueur affronte un **ghost de son tier** (via `slot_tier_composite`) →
  son build est **informatif sur la méta du tier** (« les joueurs de mon niveau jouent 4 poison/anneau
  en ce moment »). Or rien dans v4 ne **rend visible** cet apprentissage. En unranked il affronte
  souvent une IA (froide).
- **Implémentation** : enrichir le post-combat « pourquoi » (§2.3) — **si ranked ET ghost humain** —
  avec famille dominante + sigil, **lus directement du snapshot** (`{shape, units}` déjà encodés ;
  famille dominante = compter `dot_family` sur `units[]` → **dépend de P0.5**). Relique « — » (pas
  capturée en v1). RENDER, IO hors SIM, 0 invariant.
- **Garde-fou de spoil** : métadonnées affichées **après** la résolution **uniquement** (jamais avant
  — sinon neutralise la tension). Articulé au post-combat co-prio 1 (§2.3) et au Moment du Run (§2.4).

### 1.9 ADOPTÉ (retention §2.4) — Grimoire en 3 chapitres (arc long « Dead God ») : Afflictions / Essences / Abysses

**Source** : retention §2.2/Prop-B. **Comble le plafond de connaissance par la VISIBILITÉ de l'arc.**

- **Argument (diva-portal 2026 ; Grid Sage 2025)** : un jeu à méta-progression **minimale** (TBOI,
  The Pit) retient via un **arc long à jalons visibles** (le « path to Dead God »). Le Grimoire plat
  (« 30 interactions ») n'a pas d'équivalent. Le restructurer en **3 chapitres à barre de progression**
  — **Afflictions** (12 synergies actuelles), **Essences** (~18 synergies de type, P1), **Abysses**
  (~20 synergies sigil×famille, P4) — **rend l'arc visible dès le run 1** (chapitre suivant en
  silhouette = Zeigarnik). Pas d'unlock de **puissance**, unlock d'**horizon**.
- **Cohérence** : l'arc 3-chapitres **EST** la séquence P1→P4 déjà planifiée — il ne crée pas de
  contenu, il **présente** le contenu existant comme une progression. RENDER + structure dans
  `grimoire.lua` (2-onglets déjà prévu). 0 invariant. À coder **pendant P2** (pas P4).
- **Q ouverte (retention Q_R4_2)** : seuil de déblocage du chapitre II = `synergies_base ≥ 8/12` (pas
  12/12) pour qu'il soit **visible dans la saison 1** (sinon ~36 semaines à 2 runs/sem). À régler.
- **Articulation au critère de plafond v4 §6.7** : le critère d'alarme (`season_wins ≥ 50 ET
  Grimoire ≥ 25/30` → prototyper relique G en P3) **reste** ; l'arc 3-chapitres est le **véhicule**
  qui rend ce plafond moins brutal en attendant.

### 1.10 ADOPTÉ (retention §2.4) — 3e source de VRR : la « surprise de placement » rétrospective (signal arête révélée post-défaite)

**Source** : retention §2.4/Prop-D. **Source de VRR neuve, propre au plateau-graphe, coût ~0.**

- **Argument (Boyle et al. 2024, Nature Sci Rep)** : le near-miss **sous contrôle personnel** (goal
  gradient) génère un arousal **plus constructif** que le near-miss aléatoire. Le plateau-graphe 3×3 a
  une source de VRR que ni les cascades DoT ni les reliques ne couvrent : **« si j'avais placé mon
  carry en case 4, j'activais 2 arêtes de plus et je gagnais »**. C'est du **déterminisme révélé par
  l'expérimentation** = agence maximale.
- **Implémentation** : après une **défaite** (jamais une victoire — évite le paternalisme), calculer
  (RENDER, lecture `shapes[shape].edges` + positions, déjà en mémoire) si **déplacer 1 unité** vers
  une case voisine activerait ≥1 arête de plus. Si oui, signal grimdark : **« LE [SIGIL] MURMURE — TU
  N'AS PAS ENTENDU »** + surlignage de la case. Désactivable après que le joueur a compris
  (`grimoire:hasLearnedAdjacency()`). Orthogonal aux cascades → se déclenche **même sans chaîne
  longue** (utile en early, plateau peu peuplé = beaucoup d'arêtes manquées).
- **Garde-fou DA (retention Q_R4_4)** : ne **pas** exposer le mot « arête » crûment (casse le
  cryptique). Langage de **sigil** (« le sigil murmure »), pas de reproche mécanique. **Test** : sur le
  golden (carré), le calcul retourne le bon slot.
- **Condition (retention §3.4)** : ne déclencher que si le combat **n'a impliqué que le front**
  (depth < 2) — sinon le problème est d'**exposition**, pas de placement.

### 1.11 ADOPTÉ (synergies §2.1) — Signal UI obligatoire de la famille amplifiée par l'axe choc-D (+ litige #S sur le ciblage)

**Source** : synergies §2.1/P1 + Q1 ; appuyé units Q2. **L'axe D crée une profondeur INVISIBLE sans ça.**

- **Le bug d'identité (synergies §2.1, code-ancré)** : avec l'ordre tick fixe
  `burn→bleed→poison→rot`, l'axe D amplifie **toujours la première famille présente**. Un joueur avec
  4 poison + 2 choc dont la cible reçoit un **bleed adverse** (contagion/IA) verra son choc amplifier
  **le bleed, pas le poison** — sans aucune raison de le savoir en regardant son plateau. C'est
  **exactement** la frustration Artifact (« je n'ai pas compris pourquoi mon combo a raté »).
- **Remède obligatoire** : l'événement bus `shock_amplify {source, magnitude, famille}` (déjà prévu)
  **DOIT** être rendu visible en combat (`arena_draw.lua` : couleur/icône « choc a amplifié X »), pas
  juste loggé en JSONL. **Sans ce signal, l'axe D est pire qu'une profondeur absente** (le joueur ne
  sait pas ce qu'il rate). RENDER, écoute bus, 0 SIM.
- **Litige #S (NOUVEAU, synergies Q1 + units Q2)** : faut-il que l'axe D amplifie la famille
  **`dot_family` du poseur de choc** (promesse « choc amplifie le DoT de TON build ») plutôt que la
  première de l'ordre fixe ? Ça **rompt la simplicité de l'ordre fixe** (lecture de `unit.dot_family`
  à la décharge) mais rend la promesse de design **vraie**. **À trancher AVANT la spec de l'axe D**
  (donc P0.5, dans la même fenêtre que le litige #G). Sous-question liée units Q2 : `galvanizer`
  (auto-décharge) reste-t-il viable en axe D ? → Config B de la sim.
- **Métrique additionnelle (synergies §2.5/P5)** : burn n'ignore PAS le bouclier (`arena.lua:432`),
  les autres DoT si. En Config D (choc vs tank+bouclier), mesurer séparément l'ampli sur **tick burn**
  (partiellement absorbé) vs **tick non-burn** (ignoré) → décider si le désavantage du burn-vs-shield
  est voulu ou accidentel. ~2 lignes de sim.

### 1.12 ADOPTÉ (retention §1.1) — Enrichir le « Moment du Run » avec le placement (si la cascade passe par une arête de sigil)

**Source** : retention §1.1 (Déclos 2025, Yonkers 2025). **Renforce la fierté de construction.**

- La fierté de construction (post-hoc attribution) est **plus forte quand la décision décisive est
  non-évidente** (Déclos 2025 : « secondary player » qui a *décidé des règles*). Si l'unité-source de
  la cascade est adjacente à une autre **via une arête du sigil** (placement = décision non-triviale),
  l'enrichir : **« TON [UNITÉ] PLACÉ EN VOISIN DE [AUTRE] A CONSUMÉ 5 ENNEMIS »** (vs sans adjacence :
  « TON [UNITÉ] A CONSUMÉ 5 ENNEMIS »). +1 champ lu du bus (`{source, cell.x, cell.y}`, déjà encodé).
  Coût 0. Double levier (placement = near-miss sous contrôle + cascade = post-hoc attribution) sur le
  même signal.

### 1.13 ADOPTÉ (retention §2.1) — Seuil de chaîne du Moment du Run = P75 sur seeds VARIÉES (pas la médiane sur les 250 seeds FIXES)

**Source** : retention §2.1, corrige une faiblesse de v4 §2.4. **Valide (biais d'échantillon réel).**

- v4 disait « seuil = médiane des cascades » mesurée en sim. **Mais notre sim est déterministe sur
  250 seeds FIXES** → « la médiane » est la médiane d'un **échantillon particulier**, pas de la
  distribution des possibles. Si les 250 seeds penchent tank-vs-tank (peu de DoT), la médiane est
  sous-estimée → seuil trop permissif → le Moment se déclenche sur des cascades **ordinaires** →
  **réduit l'agence** (Kao et al. 2024 CHI : « amplification unexpectedly reduced [motives]…
  impeded sense of agency »).
- **Remède** : seuil = **P75 sur 1000 seeds aléatoires** (`tools/sim.lua --chain-distribution --n
  1000 --random-seeds`) → ~25 % des combats déclenchent un Moment (cohérent avec Hopson 2001 : VRR
  résiste à l'extinction à ~20-30 % de fréquence). **À mesurer avant v0.9.**

### 1.14 ADOPTÉ (FORT, progression §2.1) — Le critère de la courbe XP doit être robuste à la VARIANCE de durée de run (litige #R NOUVEAU)

**Source** : progression §2.1/§3.1, vérif `state.lua` (WIN_TARGET=10, START_LIVES=5). **Valide, chiffré.**

- v4 (litige #K) adopte `{2,5,10,18}` avec le critère « T4 jamais passif ET rush T5 ≥25 % du budget »
  — **mesuré sur un run médian de 15 rounds**. Or la **durée réelle varie de 10 (run parfaite) à ~19
  rounds** (10 victoires + défaites + vie rendue R3). La courbe est :
  - **trop raide** sur run court (10-12 rd) : rush T5 ≈ 26 XP à acheter sur ~100 or → punit le joueur
    **compétent** (qui ascend vite) ;
  - **trop douce** sur run long (17-19 rd) : rush T5 ≈ 8-9 % du budget → décision triviale.
- **Remède (critère raffiné)** : la courbe est saine ssi (1) T4 jamais passif à 15 rd ; (2) rush T5
  **≥20 %** du budget sur **run court (10-12)** ; (3) rush T5 **≥10 %** sur **run long (17-19)**. Sim :
  3 politiques (passif / rush / option-C-refus) × 3 tranches de durée × N=100 seeds = 9 configs.
  **Le seuil T5=18 est peut-être insuffisant** (progression Q1 : à 14 rd médian, rush T5 ≈ 14-17 %
  < 25 %) → tester aussi `{2,5,10,20}`. **Précondition P3.** + **`SLOT_DECLINE_XP` à recalibrer sur la
  NOUVELLE courbe** (progression §2.2 : +6 XP valent 17 % de T5 sur `{2,5,10,18}` vs 22 % sur
  `{2,5,8,12}` → la valeur `+1 XP` n'est pas transférable, sim `{0, 0.5, 1, 1.5}`).

### 1.15 ADOPTÉ (progression §2.4 + ranked §1.5) — Filet pédagogique de la Contrainte du Jour : tooltip de run AVANT d'accepter (obligatoire dès v0.11)

**Source** : progression §2.4/§3.4. **Comble un risque churn réel pour la zone 0-5 wins.**

- La Contrainte du Jour (ex. « Jour de Brûlure ») **présuppose** que le joueur maîtrise l'archétype
  imposé — or burn = chaîne de connaissances (unités → placement → reliques → propagation). Pour un
  joueur 0-5 wins (zone churn), une daily contrainte **sans contexte** = session punitive, **à
  rebours** de la promo du post-combat co-prio 1.
- **Remède (StS présente ses modifiers AVANT le run)** : panneau de contexte **avant** d'accepter la
  daily — titre (« JOUR DE BRÛLURE ») + 1 phrase (« unités de feu qui propagent leurs flammes aux
  voisins à la mort ») + 2-3 icônes des unités burn rang-1 du jour. RENDER, 0 mécanique, ~1-2 h dev.
  **Obligatoire dès la 1re implémentation (v0.11)**, pas V2.
- **Q ouverte (progression Q3)** : ordre **pédagogique** des contraintes les 5 premières semaines
  (burn→bleed→poison→rot→choc, 1 famille/sem) = courbe d'apprentissage déguisée. À documenter dans le
  ticket daily.

### 1.16 ADOPTÉ (synergies §2.1 prolongé, retention §2.3) — Mesurer la latence VRR du choc en early + envisager un « leurre choc rang-1 » (litige #Q)

**Source** : retention §2.3/Prop-C + synergies (densité). **Valide, conditionnel à la sim.**

- L'axe D crée un VRR **conditionnel à un DoT déjà posé** → en early (3-5 slots, T1-2), la densité de
  DoT est faible → le mécanisme choc peut rester **invisible** avant d'être compris. **Mesure** : dans
  la sim 4-configs, 5e métrique = **latence médiane avant le 1er `shock_amplify`** sur un plateau
  early (3 slots, rang-1/2). Si **> 3 combats** → ajouter une unité **choc rang-1 stat-stick + 1 stack
  auto** (facilite la découverte sans casser l'axe DoT, compatible plancher ≥2/famille). **Conditionnel
  à la sim** (ne pas créer l'unité par réflexe). **Litige #Q.**

### 1.17 ADOPTÉ (calendrier daily, ranked §2.3 + progression Q3) — #H' tranché : 10+ contraintes COMPOSITIONNELLES (data-only)

**Source** : ranked §2.3/P4 (+ §3.4). **Tranche un litige laissé ouvert au round 3.**

- 5 contraintes = cycle 5 j = **entièrement prédictible** (le joueur sait 5 j à l'avance) → neutralise
  le VRR du daily (StS a des **dizaines** de modifiers). **Mécanique compositionnelle** (évite 10
  implémentations) : la seed daily combine **2 axes parmi 3** — famille `{burn,bleed,poison,rot,none}`
  × topologie `{anneau,ligne,croix,none}` × éco `{+2 or rang4+, −1 reroll, none}` → **12-15
  contraintes distinctes** avec **2 variables de code**. `dailyConstraint = seedHash % #TUPLES`.
  L'extension de 2 (prototype) à 10+ est **data + seed**, 0 code moteur. **Cible : 10 avant la fin
  P2** ; prototype 2 reste le point d'entrée.

### 1.18 TEMPÉRÉ — Lisibilité bleed/rot (et autres effets secondaires inter-familles) : réel mais c'est de l'i18n/RENDER, pas un trou de balance

**Source** : units §2.1/P-A. **Vrai constat, recadré.**

- units §2.1 montre que bleed (slow) et rot (amputation PV max) ont un **effet secondaire convergent
  perçu** (« ma cible fait moins de dégâts »), distinguable seulement après ~20 runs. **Constat
  valide** — mais ce n'est **pas** un défaut de moteur (les axes SONT distincts) ni de balance, c'est
  de la **lisibilité de tooltip**. → **Adopté comme LIGNE de l'audit P0.5** (« effet secondaire perçu
  ≤8 mots, et comment le différencier sans lire les params ») qui **pilote les textes i18n**
  (`unit.<id>.passive_desc`). Bleed = « ta cible frappe au ralenti » ; Rot = « ta cible fond de
  l'intérieur ». Coût RENDER/i18n, 0 moteur. **Ne pas en faire un sujet de rééquilibrage.**

### 1.19 ADOPTÉ (units §2.2) — Le choc est un CONDENSATEUR : la colonne budget E doit utiliser `burst_DPS_eq`, pas `dmg/cd` (anti-nerf-aveugle de `galvanizer`)

**Source** : units §2.2/P-B. **Valide, anti-erreur de mesure, code-ancré.**

- Le ladder choc viole `DPS base < médian rang+1` **par conception** (condensateur : cd long / dmg
  faible pour empiler des stacks qui déchargent en burst). Appliquer `dmg/cd` uniformément →
  `galvanizer` (rang-4, DPS frappe=0.172, l'outlier #1 du roster) apparaît « OVER » → **risque de nerf
  aveugle du meilleur candidat à l'archétype choc** en P3. **Remède** : colonne E **différenciée** —
  pour le choc, `burst_DPS_eq = (volt × stacks_moy) / cd_moy_décharge`, comparé **intra-famille choc**
  (pas cross-famille). `galvanizer` reste outlier même ainsi → **l'étiqueter « condensateur premium,
  outlier voulu, ne pas nerf aveuglément »**. **Précondition #G** (son burst change selon l'axe D).
  Doc, 0 invariant.

### 1.20 ADOPTÉ (units §2.3) — Budget tank distinct (EHP_proxy + DPS_tank ≤ 0.07×rang) ; trancher `templar` et `runestone_golem`

**Source** : units §2.3/P-C. **Valide, prolonge l'audit budget P0.5.**

- Décider « pas de 6e type tank » (litige #F, orienté **aucun** — confirmé) **ne résout pas** la
  **dispersion de DPS intra-groupe** des 11 tanks (de `shieldbearer` DPS=0.025 à `templar` DPS=0.146).
  Un tank à DPS élevé n'est plus un tank, c'est un bruiser → hiérarchie implicite non documentée. →
  colonne E **dédiée tanks** : `EHP_proxy = hp×(1 + max_shield/hp)` + règle indicative `DPS_tank ≤
  0.07×rang`. **Décisions à trancher** : `templar` (rang-3, DPS=0.146, **unité vanille dessinée
  main**) = bruiser iconique étiqueté **ou** tuner vers ≤0.095 ? ; `runestone_golem` (rang-4 v7,
  DPS=0.125 + shield_aura, déjà signalé round 3 §3.6) = roster-only **ou** tuner ≤0.08 ? **Garde-fou** :
  ne pas rétrograder `templar` sans peser la friction UI (identité visuelle iconique). Doc, 0 code.

### 1.21 ADOPTÉ (NUANCÉ, units §2.4) — Champ `pool` déclaratif dans `units.lua` : recommandé, NON-bloquant (litige résolu vers « différer sauf si v8+ »)

**Source** : units §2.4/P-D. **Valide sur le principe, priorité tempérée.**

- La cause de la cohorte v7 (`U.pool = U.order` par défaut, `units.lua:487` « Identique au roster pour
  l'instant ») est une **règle implicite non enforçable** → dette à chaque vague. Le remède propre est
  un champ **data** `pool = false` (roster-only) + reconstruction filtrée de `U.pool` + lint. **Ce
  n'est PAS de la complexité moteur** (data + 3 lignes de construction). **Mais** : tant qu'aucune
  vague v8+ n'est planifiée avant P3, la décision de cohorte **documentée + commitée** suffit. →
  **Adopté comme recommandation de P0.5** (le faire **si** on touche `U.pool` de toute façon pour la
  cohorte v7 ; sinon différer). Devient **prioritaire si v8+ planifiée**. 0 invariant.

### 1.22 ADOPTÉ (relics §2.1/Prop-A) — Colonne « rôle temporel » (shaper-early/mid/payoff-late) dans l'audit reliques (litige #P)

**Source** : relics §2.1/Prop-A (TFT augment timing). **Valide en tant que méthode d'audit, indépendant de l'erreur §1.1.**

- Même si l'analyse de `plague_communion` du round portait sur le mauvais mécanisme (§1.1),
  l'**outil** proposé reste bon : auditer chaque relique par **rôle temporel** (shaper-early oriente
  le build / shaper-mid amplifie / payoff-late récompense) et **vérifier que la fenêtre d'offre (tier
  ≤ wins) correspond au rôle**. TFT cale ses augments build-defining à 2-1/3-2/4-2, ses payoffs en
  late (Mort Sullivan, Riot GDC 2022). → colonne « rôle temporel » dans l'audit P1.5a. Mismatchs à
  signaler (ex. une relique payoff-late offerte trop tôt = faible ; un shaper offert trop tard
  = inutile). Doc, 0 code. **Litige #P.**

---

## 2. CE QUI EST REJETÉ OU FORTEMENT TEMPÉRÉ (et pourquoi)

| Proposition | Verdict | Raison (sourcée) |
|---|---|---|
| **`feeding_frenzy` = bug silencieux / récompense morts alliées → reformuler kills ennemis** (relics Prop-D, Q3) | **REJETÉ** | Prémisse fausse. `frenzy_gain` existe (`ops.lua:211`) et broadcast **aux ennemis du mort** déjà (`ctx.source` = notre survivant ; i18n « Each enemy that dies »). La relique fait déjà ce que la critique réclame. Reste : 1 test cross-team (zone test). |
| **`plague_communion` scalante +5 %/allié de la famille majoritaire** + cap min(4,count) (relics Prop-B, synergies P4) | **ÉCARTÉ (mauvais mécanisme)** | La relique réelle (`arena.lua:251`) conditionne sur `afflictionCount(CIBLE) ≥ 2`, pas sur le roster-count. Le « dead range » du round 3 n'a jamais existé. → litige #J **requalifié** (§1.1), relique gardée telle quelle par défaut. |
| **Critère courbe XP inchangé (run médian 15 rd)** (v4 §7.1) | **TEMPÉRÉ** | progression §2.1 : la durée varie 10-19 rd → critère non-robuste aux extrêmes. Adopté le critère à 3 tranches (§1.14). Pas un rejet de `{2,5,10,18}`, un raffinement du test. |
| **Seuil Moment du Run = médiane (250 seeds fixes)** (v4 §2.4) | **TEMPÉRÉ** | retention §2.1 : biais d'échantillon déterministe → P75 sur 1000 seeds variées (§1.13). |
| **6e type tank** (à cause de la dispersion DPS tank) | **REJETÉ (reste « aucun »)** | units §2.3 elle-même dit que c'est un **sujet d'audit budget**, pas un argument pour un palier. Litige #F reste orienté « aucun ». La dispersion DPS = colonne E dédiée (§1.20), pas un type. |
| **Bleed/rot = trou de balance** | **TEMPÉRÉ → lisibilité** | units §2.1 : les axes SONT distincts (slow vs amputation). Le problème est la **perception** (i18n), pas le moteur (§1.18). Pas de rééquilibrage. |
| **Axe D cible `dot_family` du poseur** (synergies Q1, units Q2) | **NON TRANCHÉ → litige #S** | Vrai trade-off (promesse de design vs simplicité de l'ordre fixe). À décider en P0.5, avec #G, pas gravé ici. |
| **Champ `pool` déclaratif = PRIORITAIRE maintenant** (units P-D) | **TEMPÉRÉ → non-bloquant** | Bonne idée data, mais la cohorte v7 documentée+commitée suffit tant qu'aucune v8+ n'est planifiée (§1.21). |
| **`black_summons`/`beggars_lantern` à traiter différemment de `carrion_ledger`** dans la déprio F (relics Q4) | **REPORTÉ (litige mineur)** | Nuance valide (les 3 F n'ont pas la même courbe de valeur) mais secondaire ; la règle « si F tiré ET B-E dispo → remplacer » tient pour les 3. À affiner quand le marchand arrive (P1.5c). |

---

## 3. LITIGES OUVERTS POUR LE ROUND 5 (consolidés)

**Tranchés/résolus ce round** : **#H'** (10+ contraintes compositionnelles) ; **#J** (REQUALIFIÉ —
relique réelle = payoff multi-affliction, à régler magnitude/scaling, pas gate-vs-scalante) ;
Prop-D/Q3 relics (rejetés, prémisse fausse).

**Litiges actifs (rang d'urgence) :**

1. **#G + #S (axe choc, P0.5)** — A/B/D + **D-ponctuel vs D-durée** + **#S : ampli sur l'ordre fixe
   vs `dot_family` du poseur**. Sim **4 configs** (+ latence VRR early #Q + métrique burn-vs-shield).
   **Signal UI famille amplifiée = obligatoire** (§1.11). Rebaseline golden. Précède P1.
2. **`--poison-frac` (P0.5, promu)** — mesurer `win_rate(poison) vs pool` à frac 1.0 puis 0.5 **AVANT
   P1**. Si `>+1σ → <+0.5σ` → activer `frac=0.5`. Borner la propagation T3 séparément ? (Q2 synergies).
3. **#D + variance positionnelle (P0.5, promu)** — `--position-variance` (3 permutations) sur sigils
   non-carré **avant d'écrire les tests P1**. `std_dev < 0.02` → global ; `> 0.05` → adjacence-type.
4. **#R (courbe XP, P3 précondition)** — critère à 3 tranches de durée (court/médian/long) ; tester
   `{2,5,10,18}` ET `{2,5,10,20}` ; recalibrer `SLOT_DECLINE_XP ∈ {0,0.5,1,1.5}` sur la nouvelle courbe.
5. **#J requalifié (P1.5a + sim)** — `plague_communion` : +25 % flat vs scalant sur
   `afflictionCount(cible)` (2=+20/3=+30/4+=+40) ? Comparer à `bloodstone` (la relique tier-4 doit
   dominer son archétype — relics Q1). Garder la relique réelle par défaut.
6. **#O (P1.5a)** — `famines_math` : (a) reformuler non-anti-growth (« tes 3 plus fortes ») vs (b)
   retirer du pool boutique. Conflit avec slot-grants code-vérifié.
7. **#P (P1.5a, doc)** — colonne « rôle temporel » des reliques ; signaler les mismatchs fenêtre/rôle.
8. **#Q (P0.5, sim)** — latence VRR du choc en early ; si médiane > 3 combats → leurre choc rang-1.
9. **#A (P3, inchangé)** — types (P1) vs ranked (P2), arbitré par `--meta-convergence` (< 8 runs pour
   ≥2 sigils → types d'abord). **Désormais conditionné à #poison-frac** (mesurer sur une méta non
   cassée).
10. **#N (P2)** — signal de récompense pré-run + signal de pool = **même écran** (position adoptée ;
    séparer seulement si surcharge UX constatée).
11. **#B (P1)** — double-comptage inc% borné par cap ×3 ; **le cap borne l'output, pas l'`increased`
    ni le `more`** → le **twist de palier 4 = `more` à borner séparément** (confirmé code §1.3 du r04-
    synergies : `3.8 × 1.30 = 4.94 > cap 6`). À spécifier AVANT P1.
12. **#L/#L' (P3)** — pity = signal sans garantie, **seuil = `max(PITY_MIN_ABS=3, 0.5 × hunt_médian)`**
    (progression §2.3 : plancher absolu pour survivre à l'audit de pool) + **progression visuelle
    implicite** (icône qui s'intensifie, pas de chiffre — ACM SIGCHI 2023 : il faut *percevoir* la
    progression vers la garantie). Compromis seedé⊗variable (Boyle 2024 : le near-miss N+1 non livré
    est plus frustrant que la non-apparition).
13. **#C (CLOS)**, **#F (orienté aucun, confirmé)**, **#I**, **#K (intégré à #R)**, **#M** — inchangés.
14. **Twists de palier 4** (P1) — règles ≤8 mots, ≠ sous-cas T3, ≠ vide-T2 (colonne F), spécifiées
    `more` bornées. Candidats orthogonaux confirmés (burn 4 = propagation **en cours-de-vie** ≠
    wildfire à-la-mort ; rot 4 = amputation HP final ≠ necro_leech ; poison 4 = axe ≠ slow).
15. **Reset ranked conditionnel** (ranked §5.3) — si `< 3 runs ranked/saison` → reset à 0 (pas −20 %)
    + message clair (« pas de perte »). Edge case simple, P2.
16. **Marques sub-tier : calibrer sur p25** de la distribution des meilleurs runs (ranked §1.2) +
    **reset par saison** (position adoptée) — au launch, hors scope lab.

---

## 4. PREUVES NOUVELLES DU ROUND (code + web)

**Code vérifié par le synthétiseur (lecture seule) :**
- `src/data/relics.lua:34-35` — `famines_math = relic_few_units {max=3, dmgInc=0.30, hpInc=0.20}` →
  **conflit anti-growth confirmé** (litige #O).
- `src/data/relics.lua:38-39` + `src/effects/ops.lua:208-217` — `feeding_frenzy → frenzy_gain` **op
  existant**, snowball `me.dmg` cappé 6, broadcast `on_death` **aux ennemis du mort** → **récompense
  les kills ennemis** (réfute relics Prop-D/Q3).
- `src/data/relics.lua:57-58` + `src/combat/arena.lua:248-252` — `plague_communion` condition réelle
  = **`afflictionCount(target.dots) >= 2`** (la **cible** porte ≥2 familles), `plagueAmp = 0.25`
  **flat**, `more` post-cap → **réfute le gate « ≥4 même affliction » et la reformulation
  « +5 %/allié majoritaire »** (litige #J requalifié).
- `src/effects/ops.lua:219-231` — `spread_*_on_death` propage les DoT aux **voisins du champ de
  bataille** (`arena:neighborsOf`), profondeur 1 (`viaSpread` bloque le chaînage), `spreadValue` cap
  14 → **confirme** que la propagation est un axe data **bornable par `frac`** (litige poison-frac).

**Web nouveau (vérifié par les lentilles, conservé) :**
- **Ranked moteur pré-run** : seganerds.com 2026 (« uncertainty keeps you queuing ») + immortalboost
  (TFT affiche le LP potentiel à la sélection) → §1.6.
- **Bazaar sept. 2025** : matching par **rang** (pas proxy de force) + **transparence du pool avant la
  run** (bazaar-builds.net/announcement) → reconfirme `slot_tier_composite` + signal de pool (§6.4-6.5).
- **Bazaar ranking** : pré-Legend = **gains seulement** (pas de perte) ; Legend = moyenne 0-1000
  (steamcommunity 1617400) → reconfirme grille sans pénalité + unité=run.
- **LoL ranked rewards 2025** (egamersworld) : désaffection si cosmétiques **trop accessibles** →
  marques sub-tier à calibrer sur **p25** (ranked §1.2).
- **Méta-progression** : Åslund 2026 + diva-portal 2026 (Hades 2 heavy « one-more-run » vs TBOI
  minimal « path to Dead God ») → arc Grimoire 3-chapitres (§1.9).
- **Spectacle = agence** : Déclos 2025 (British J. Aesthetics, « secondary player » authorship) +
  Yonkers 2025 (« pride — seeing a strategy succeed without intervention ») → fierté de construction,
  enrichissement placement (§1.12).
- **VRR / juice** : Kao et al. 2024 (CHI, « amplification… impeded sense of agency ») → seuil P75
  (§1.13) ; Boyle et al. 2024 (Nature Sci Rep, Wordle near-miss sous contrôle) → surprise de
  placement (§1.10) + compromis pity seedé⊗variable.
- **Pity** : MDPI 2025 (~55 tentatives = frontière compulsion ; soft vs hard pity) + ACM SIGCHI 2023
  (il faut *percevoir* la progression vers la garantie) → seuil `max(3, 0.5×médiane)` + progression
  visuelle implicite (#L).
- **Daily** : StS Daily (modifiers **affichés avant** le run + des **dizaines** de modifiers) → filet
  pédagogique tooltip (§1.15) + 10+ contraintes (§1.17).
- **Budget / condensateur** : GhostCrawler power-budget (cost reflète la puissance) + StS Totem/Ironclad
  (jaugé sur dégâts par éruption, pas DPS moyen) → colonne `burst_DPS_eq` (§1.19) ; metatft (HP/DPS
  inversé tank vs carry) → budget tank (§1.20).
- **Pool partagé vs local** : esportstales (TFT pool partagé 8 joueurs) vs The Pit (pool **local** à
  la run, async) → la règle ≥2/famille **n'est pas une copie TFT**, c'est notre propre math de
  visibilité (units §1.1).

---

## 5. MÉTA-LEÇON DU ROUND (pour la méthode des rounds 5-10)

**Le débat a failli graver du faux pendant 2 rounds.** La reformulation « scalante » de
`plague_communion` (round 3) et la « refonte » de `feeding_frenzy` (round 4) sont nées de **lectures
de code de seconde main** (en s'appuyant sur les commentaires de roadmap des rounds précédents plutôt
que sur le code source). **Règle adoptée pour les rounds 5+** : toute proposition qui **reformule un
mécanisme existant** (relique/op/unité) DOIT citer la **ligne de code source réelle** (`fichier:ligne`
relu **ce round**), pas une description héritée d'un round antérieur. Les rounds qui ont **honnêtement
signalé leur incertitude** (r04-relics : « `frenzy_gain` NON TROUVÉ → à vérifier ») ont raison de le
faire — mais doivent **alors** s'abstenir de proposer une refonte tant que la vérif n'est pas faite.
Le synthétiseur grep/lit le code à chaque ambiguïté ; c'est ce qui a sauvé v5 ici.

---

## 6. Index des sources

**Internes (code relu par le synthétiseur ce round, lecture seule)** : `src/data/relics.lua:34-73`
(famines_math, feeding_frenzy, plague_communion, ordre des 21) ; `src/combat/arena.lua:244-265`
(condition réelle plague_communion + flux damage) ; `src/effects/ops.lua:208-231` (frenzy_gain réel +
spread_on_death). **Ancrage** : `ROADMAP-draft.md` v4, `00-state.md` (32 invariants), `round-0{1,2,3}.md`,
`BRIEF.md`.

**Critiques du round** : `rounds/r04-{progression-economy, ranked-competitive, relics,
retention-addiction, synergies-effects, units-power}.md` (chacune cite ses propres URL web + lignes
de code ; conservées par référence). **Web nouveau consolidé §4.** **Sources rounds 1-3 conservées**
(goal-gradient Nunes & Drèze 2006 ; near-miss Clark 2009 ; PoE Shock no-stack ; StS Vulnerable ;
GhostCrawler ; Giovannetti GDC 2019 ; LocalThunk « 1 règle/Joker » ; floors/MMR immortalboost/boosteria).

---

*Synthèse du round 4 (6 lentilles) le 2026-06-23. Améliorations mesurables vs round 3 : **2 décisions
adoptées au round 3 corrigées par vérif code source** (plague_communion = payoff multi-affliction et
non gate/scalante ; feeding_frenzy récompense déjà les kills ennemis) ; **2 drapeaux de sim promus de
P3 à P0.5** (poison-frac = cause structurelle de poison>choc ; position-variance = design du compteur
type avant les tests) ; **1 litige tranché** (#H' = 10+ contraintes compositionnelles) ; **6 litiges
neufs code/recherche-ancrés** (#N, #O, #P, #Q, #R, #S) ; **3 lacunes-moteur-de-rétention comblées**
(pré-run ranked, Contrainte Permanente de Saison, Grimoire 3-chapitres + surprise de placement) ;
**1 anti-erreur de mesure** (choc = condensateur → burst_DPS_eq, anti-nerf-aveugle de galvanizer) ;
**1 méta-règle de méthode** (reformuler un mécanisme = citer la ligne de code relue ce round).
Lecture seule du repo ; n'édite que sous `docs/roadmap-lab/`. Piliers respectés.*
