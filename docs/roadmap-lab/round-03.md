# Round 03 — Synthèse (SYNTHETISEUR)

> **Rôle** : acter le round 3 du roadmap-lab. Intègre **de façon critique** les 6 critiques de
> lentille (`rounds/r03-*.md`) contre `ROADMAP-draft.md` v3 et la synthèse `round-02.md`. **Débat,
> pas addition** : j'adopte les critiques valides et sourcées, je rejette/tempère les faibles (en
> disant pourquoi), je consigne les VRAIS litiges pour le round 4. La roadmap intégrée vit dans
> `ROADMAP-draft.md` (réécrit en v4).
>
> **Garde-fous** : lecture seule du repo ; n'édite que sous `docs/roadmap-lab/`. Piliers : async
> snapshots / sim déterministe seedée / DA grimdark / pixel art procédural. 32 invariants préservés.
>
> **Inputs** : `BRIEF.md`, `ROADMAP-draft.md` (v3), `00-state.md`, `round-01.md`, `round-02.md`, les
> 6 `rounds/r03-{progression-economy, ranked-competitive, relics, retention-addiction,
> synergies-effects, units-power}.md`. **Vérifs code menées par le synthétiseur ce round** (lecture
> seule, citées §5) : `arena.lua:325-395` (ordre exact `hit()` → `damage → on_hit → dischargeShock`),
> `units.lua:72-447` (rot/bleed rang-2, v7, rang-5 stat-sticks).

---

## 0. Méta-verdict du round

**Le round 3 est un round de PROFONDEUR MÉCANISTE.** Là où le round 2 démontait des erreurs
factuelles du brouillon (« `type` déjà pris », « ladder choc déjà codé »), le round 3 attaque les
**décisions que le brouillon croyait résolues mais qui sont sous-spécifiées** — et il le fait en
descendant **plus profond dans le code** que le round 2. Trois résultats dominent :

1. **L'axe C du choc (amplificateur PoE) est mécaniquement infaisable tel que formulé — et
   *deux lentilles indépendantes* (synergies §2.1, units §2.3) le démontent par le code.** Le
   brouillon disait « axe C = réécrit `dischargeShock`, +5 lignes isolées, rebaseline golden ».
   **Faux** : `dischargeShock` est appelé par `hit()` **APRÈS** que le coup déclencheur soit déjà
   calculé et appliqué (`arena.lua:330` : `damage → on_hit → dischargeShock`, **vérifié
   synthétiseur**). Amplifier « le hit qui a déclenché la décharge » exige de **réordonner `hit()`**
   — ce qui touche l'ordre `on_attack → damage → on_hit → on_attacked → dischargeShock` dont
   dépendent plusieurs des 12 invariants de synergie (#22-32). C'est une dette cachée, pas une
   micro-édition. **La lentille synergies propose un AXE D** qui résout le problème : décharger sur
   le **premier tick de DoT** de la cible dans `tickDots` (qui s'exécute APRÈS le cycle de frappe →
   zéro conflit d'ordre), créant une **vraie synergie choc × DoT** (« charge la cible, puis le poison
   explose »). C'est le gain de design le plus fort du round.

2. **Le contenu a un PLANCHER absent, pas seulement un plafond — et un budget de puissance non
   chiffré.** La lentille units démontre par le code que la règle « ≤4 enablers/famille/rang » du
   brouillon, appliquée, **laisse rot rang-2 à 2 enablers** (`rot_hound`+`rot_grub`+`bore_worm`,
   **vérifié**) → `P(voir rot/boutique T2) ≈ 25-43 %` = famille **invisible** en early. Et l'audit
   P0.5 n'a **aucune** colonne « budget stat » : `cinder_cur`/`zeal_inquisitor` (rang-2) ont un DPS
   de base **supérieur** à `bellows_priest` (rang-3) — anomalie que l'audit qualitatif ne peut pas
   détecter. → **Double critère plafond+plancher + colonne budget = l'audit P0.5 devient
   quantitatif.**

3. **La grille ranked a un gouffre de rétention mid-core, et deux signaux de matchmaking/cold-start
   du brouillon sont défectueux.** *Trois lentilles convergent* (ranked §2.1, retention §2.4,
   implicitement progression) : la zone 0-5 victoires = **0 point toute la saison** pour le joueur
   mid-core honorable → churn documenté (Duradoni 2026). `season_wins` (un compteur **privé**) ne
   ferme pas ce vide — il manque un signal **comparatif**. La lentille ranked propose les **marques
   sub-tier** (Survivant/Forgé/Ascendant, cosmétiques, basées sur le meilleur run de saison) +
   remplace le `build_cost_proxy` **volatil** par `slot_tier_composite` (**monotone croissant** dans
   une run) + remplace le flag punitif `quality.human` par un **signal de pool pré-run transparent**.

**Litiges tranchés ce round** : **#G** orienté vers **axe D** (à confirmer par sim 4-configs, golden
rebaseliné) ; **#H** (daily) tranché vers l'**option (c) Contrainte du Jour** (la contrainte EST la
différenciation, score brut `wins×(10−lives)` — *deux lentilles* le préfèrent aux options a/b) ;
**#A2** (Dernier Souffle) tranché : **existe, à 1 vie, sous forme de relique tier-4 seedée gratuite**.
**Litiges nouveaux** : **#J** (option scalante vs gate pour les E tier-4 — relics démontre le « dead
range » de la condition-gate), **#K** (courbe XP à recourber pour un climax mid-late), **#L**
(pity-signal sans chiffre vs pity-garantie — *deux lentilles* convergent : la garantie explicite
neutralise le VRR).

---

## 1. CE QUI CHANGE DANS LA ROADMAP (et pourquoi)

### 1.1 ADOPTÉ (FORT) — L'axe choc devient l'AXE D (décharge sur le 1er tick DoT), pas l'axe C — code-vérifié, 2 lentilles

**Source** : synergies §2.1/P1 + units §2.3/P-C. **Convergence de 2 lentilles + vérif synthétiseur.**

- **Preuve code (synthétiseur, `arena.lua:325-395`)** : la séquence de `hit()` est
  `bus:emit("hit") → Effects.run(on_hit) → if target.alive then dischargeShock()`. `dischargeShock`
  fait `burst = stacks × volt`, `damage(target, burst, {ignoreShield=true, cause="shock"})`, **puis**
  consomme les stacks. Le coup déclencheur (`damage()` de la frappe) est **déjà appliqué** quand
  `dischargeShock` s'exécute. → **L'axe C (amplifier le hit déclencheur) exige de réordonner `hit()`**
  (calculer le choc AVANT le damage de la frappe), ce que le brouillon v3 §3.3 ne dit pas (« +5
  lignes isolées »). C'est faux : ça touche l'ordre des phases dont dépendent les invariants #22-32.
- **Pourquoi l'analogie PoE échoue (synergies §2.1)** : PoE Shock **ne stacke pas** (le plus fort
  s'applique, stacking en *durée*), s'applique à **TOUT** dégât reçu pendant la durée, simultanément.
  Notre choc stacke jusqu'à 8 (`SHOCK_STACK_CAP=8`) et notre ciblage est mono-cible déterministe. Un
  « amplifie le prochain hit reçu » = amplifie **une seule frappe** d'**une seule unité** → ce n'est
  PAS un amplificateur d'équipe (le « pourquoi » de PoE), c'est un burst conditionnel sur le timing.
  L'analogie est **paresseuse au niveau mécaniste** (poewiki.net/wiki/Shock, vérifié 2 lentilles).
- **L'axe D résout tout** : décharger dans `tickDots` (arena.lua:392+, **après** le cycle de frappe)
  sur le **premier tick de DoT** de la cible (ordre fixe `burn→bleed→poison→rot`) → `tick_amplifié =
  tick × (1 + stacks×N)`, puis consommer les stacks. **Zéro conflit d'ordre avec `hit()`.** Crée une
  identité lisible (« charger la cible, le DoT explose »), déterministe (le 1er tick présent est
  prédictible), et fait du choc un **amplificateur de DoT** (résout la hiérarchie : il *renforce*
  poison/burn au lieu d'en être concurrent). Précédent : StS *Vulnerable* (amplifie la prochaine
  attaque, pas toutes — slaythespire.wiki.gg/wiki/Vulnerable).
- **Décision roadmap** : le litige #G devient **A / B / D** (l'axe C est **retiré** comme infaisable
  proprement ; conservé en note comme « ce qu'on a écarté et pourquoi »). La matrice de sim passe à
  **4 configs** (ajout Config D = choc vs tank+shield, voir §1.2). `N` [PH suggéré 0.05 → +40 % à 8
  stacks]. **Rebaseline golden signalé.** Coût : sim headless + réécriture ciblée de `dischargeShock`
  **dans `tickDots`** (pas dans `hit()`).
- **Garde-fou test (synergies §2.1)** : émettre un événement bus `shock_amplify {source, magnitude,
  famille}` → le « Moment du Run » et le post-combat peuvent l'attribuer. Lint `tools/check.sh` :
  « toute unité avec un op DoT a `dot_family` non-nil » (~5 lignes luacheck, synergies §1.1).

> **Note de réconciliation** : units §2.3 pose le « problème de concentration » (l'ampli profite à la
> cible déjà la plus ciblée = un tank ennemi en front). C'est **réel pour l'axe C** (amplifie une
> frappe sur le front) mais **dissous par l'axe D** : l'ampli s'applique au **tick DoT**, qui ignore
> déjà les boucliers (bleed/poison/rot ignorent les shields — 00-state §3.1) et tape la cible quelle
> que soit l'aggro. Les deux lentilles convergent donc vers D pour des raisons complémentaires.

### 1.2 ADOPTÉ — Config D (choc vs tank+bouclier périodique) dans la sim choc P0.5

**Source** : synergies §2.4/P3 + units §P-C (Config D) + §2.3. **Convergence de 2 lentilles.**

- **Pourquoi** : la matrice 3-configs du brouillon ne teste **jamais l'adversaire le plus résistant**
  (tank à haut aggro + bouclier périodique). Or l'interaction choc-ampli × bouclier périodique est un
  **counter implicite non testé** : 5 unités `ward_weaver`/`barrier_savant` existent et reposent sur
  un trigger combat, pas une aura (synergies §2.4). Si on la découvre en P3 (après l'axe en P0.5 et
  les types en P1), on ne saura plus si la faiblesse du choc vient de l'axe ou du counter.
- **Subtilité résolue par l'axe D (synergies Q3, vérif synthétiseur)** : le burst de l'axe A/B a
  `ignoreShield=true` (**confirmé** `arena.lua:325`) → il **ignore déjà** le bouclier. Mais en axe D,
  l'ampli touche le **tick DoT**, qui ignore aussi le bouclier → **le bouclier périodique n'est PAS
  un counter du choc en axe D**. Config D mesure donc surtout : l'ampli est-elle *gaspillée* contre
  une cible qui régénère/se re-bouclier plus vite qu'elle ne meurt ? → décision « counter voulu ou
  accidentel ». Coût ~0 (même harnais, `seed=20260623`, N=50).
- **Décision roadmap** : Config D ajoutée à §3.3 ; rapatrie le drapeau `timing-shield` de P3 **dans
  la sim choc P0.5** (évite une dette d'équilibrage post-implémentation).

### 1.3 ADOPTÉ — Audit P0.5 = grille à 6 colonnes (plafond+plancher+budget+conflit-T2)

**Source** : units §2.1/§2.2/§2.4/P-A + synergies §2.3/P2. **Convergence de 2 lentilles + vérif code.**

La grille à 4 colonnes du brouillon (niche / redondance / remède / `dot_family`) devient **6
colonnes** :
- **(5) Budget stat (NOUVEAU, units §2.2)** : `DPS base (dmg/cd)` + HP + proxy EHP×DPS, dans la
  plage `[rang-1 < rang-2 < rang-3]` attendue ? **Preuve code** : `cinder_cur` (rang-2, DPS=0.118) et
  `zeal_inquisitor` (rang-2, 0.118) **dépassent** `bellows_priest` (rang-3, 0.111) — anomalie de
  budget que `cost=rank` (décision #10) ne tolère pas si le budget réel ne suit pas le coût (source :
  GhostCrawler power-budget, askghostcrawler 2017). Seuil indicatif : DPS base rang-2 < médian
  rang-3, sinon over-statté. Coût : tableur, 0 code.
- **(6) Conflit twist-T2 (NOUVEAU, synergies §2.3/P2)** : si le palier 4 d'un type implémente le
  mécanisme clé d'un T2 de la même famille → **NICHE VIDÉE**. Le garde-fou « ≠ sous-cas d'un T3 » du
  brouillon est **insuffisant** : le vrai danger est le twist qui rend le T2 **obsolète** (ex. « poison
  4 = slow cadence » vide `chitin_drone` ; « bleed 4 = aggravate équipe » vide `razor_fiend`). Source :
  effects-synergy-tiers §3.1 (« 2 finishers même famille = meta résolue »). Coût : ~10 lignes d'audit.

**+ Règle de PLANCHER (units §2.1/P-A, vérif synthétiseur)** : la règle « ≤4/famille/rang » devient
**double critère** : **plafond ≤4 ET plancher ≥2 enablers/famille au rang-2 ET au rang-3**, pour que
`P(famille visible/boutique T2) ≥ 40 %` (hypergéométrique, analogue au critère reliques ≥2/archétype).
**Preuve code** : rot rang-2 = `rot_hound`(capDps=10) + `rot_grub`(capDps=6) + `bore_worm`(capDps=8,
v7) → **2-3 enablers distincts**, déjà sous le plafond ; bleed rang-2 ne doit pas tomber sous 2 au
nettoyage. Familles à 1 enabler rang-2 = **archétype caché**, pas chemin de build.

### 1.4 ADOPTÉ — Vague v7 = décision de COHORTE avant l'audit ligne-à-ligne ; audit rang-5 dédié

**Source** : units §2.5/P-B (cohorte v7) + §2.4/P-D (rang-5). **Convergence interne units, vérif code.**

- **Cohorte v7 (units §2.5)** : les 14 unités v7 (`units.lua:383-447`) ont été créées pour la
  **génération procédurale** (champ `family` pour `creaturegen.cached`), pas pour l'équilibre du
  pool — `units.lua:487` documente « Identique au roster pour l'instant. ». **Filtre de 1er niveau** :
  « parmi les 14 v7, lesquelles ont une niche distincte ET un budget cohérent pour le pool day-1 ? »
  Les autres → `roster-only` (restent dans `U.order` pour encounters IA/galerie/snap, retirées de
  `U.pool`). Estimation units : 4-6 des 10 v7 rang-2 à retirer du pool. Cette décision **précède**
  l'audit ligne-à-ligne.
- **Audit rang-5 (units §2.4)** : `skull_colossus` (burn dps=4 + tank aggro=40/hp=92) et `deep_kraken`
  (poison dps=4 + très haute aggro), tous deux v7, ressemblent à des **stat-sticks** (gros stats +
  effet simple), pas à des **transforms T3** (décision #10 : rang-5 = règle d'équipe). → ligne rang-5
  dédiée : transform réelle / stat-amplification à raffiner / rétrograder rang-4 (libère 2 slots
  rang-5 pour de vraies transforms). Source : Giovannetti GDC 2019 (« 1re erreur = trop de cartes qui
  font la même chose avec des chiffres différents »). Coût : doc, 0 code, **avant** les twists P1.

### 1.5 ADOPTÉ (FORT) — Option SCALANTE par défaut pour les reliques E tier-4 (pas la condition-gate)

**Source** : relics §2.1/Prop-A. **Tranche le litige #J (nouveau) immédiatement.**

- **Le « dead range » démontré (relics §2.1)** : conditionner `plague_communion` sur « ≥4 unités même
  affliction » (aligné sur le palier P1) est un **gate fonctionnel déguisé**, pas du « scope
  conditionnel StS ». La relique est offerte à 5+ wins (round 6+), où le joueur a 7-8 slots ; « ≥4 de
  même affliction » = 57 % de la compo → inerte pour toute compo mixte, et le joueur la **garde
  passivement** sans construire vers elle (≠ downside StS actif **immédiatement**, ex. Busted Crown).
  C'est du **bruit d'inventaire** sur 60 % du run.
- **La réponse : option scalante (relics §2.1, Prop-A)** : `plague_communion` → « +5 % dégâts équipe
  par allié de l'affliction majoritaire » (2 poison = +10 %, 4 = +20 %, 6 = +30 % ; **7 mots, ≤8 ✅**).
  Valeur **immédiate** + incitation à pousser = **endowed progress effect** (Nunes & Drèze 2006, déjà
  cité §5.2). Implémentation : `plagueAmp = 0.05 × count(famille majoritaire)` à `combat_start` via
  `grant_team` (pas de nouvel op).
- **Décision roadmap** : P1.5a adopte l'**option scalante pour TOUTES les E tier-4** sauf celles déjà
  build-defining sur leur seul mécanisme (`everburn`, `open_wounds` = rien). **`second_breath` n'est
  PAS conditionné** (relics §2.4, voir §1.6). `forked_tongue` : calibrer le N de rebonds sur le count
  choc (1 = 1 rebond, 3+ = 2), mais **ne pas graver avant #G** (relics Q2 : l'axe choc change le sens
  du « rebond »).

### 1.6 ADOPTÉ — `second_breath` reste universel tier-3 (NE PAS conditionner) ; F déprioritisées dès maintenant

**Source** : relics §2.4 (`second_breath`) + relics §2.2/Prop-C (déprioritisation F). **Vérif code.**

- **`second_breath` (relics §2.4, vérif `relics.lua:47` + `R.apply:97-98`)** : le brouillon voulait le
  conditionner sur « ≤4 unités OU front-row » = **deux reliques fusionnées** (tall XOR positionnement),
  trop flexible pour créer un archétype. C'est une **relique défensive universelle de tier-3** (analogue
  Akabeko/Orichalcum StS — universelles, non conditionnées). Son **tier (3, pas 4)** est déjà le
  garde-fou. Si trop forte en sim → monter tier ou réduire la survie (0.5 PV), **pas** ajouter une
  condition incohérente. **Le principe « tier-4 = build-defining » ne s'applique pas à une tier-3.**
- **Déprioritisation des F sans attendre le marchand (relics §2.2)** : le brouillon laisse les 3
  reliques F (runOp) en pool 1-parmi-3 jusqu'à P1.5c (« quand le marchand est codé », différé).
  **Coût chiffré (relics §2.2, hypergéométrique)** : `P(≥1 F parmi 3 offres) = 1 − C(18,3)/C(21,3) ≈
  0.39` → 25-33 % des ~4 offres/run **contaminées** par une décision d'un type différent (économie du
  run vs build de combat) = bruit cognitif. **Remède actionnable maintenant** : dans `rollRelicChoices`,
  si un F est tiré ET ≥1 B-E disponible → remplacer le F par un B-E (tir **seedé additionnel du même
  RNG**, déterministe). Disparaît quand le marchand arrive (P1.5c). Adapter test #3 AVANT.

### 1.7 ADOPTÉ — Marques sub-tier (ranked) + `slot_tier_composite` + signal de pool pré-run

**Source** : ranked §3.1/P1 + §3.2/P2 + §3.4/P4, **renforcé par** retention §2.4. **3 lentilles.**

- **Marques sub-tier (ranked §3.1, retention §2.4)** : la grille `+4/+2/+1/0` donne **0 à toute la
  zone 0-5 victoires** → le mid-core honorable ne voit **aucune** progression notée toute la saison
  (churn documenté : Duradoni 2026, Juul « Fear of Failing »). `season_wins` (brouillon §6.8) est un
  **journal privé**, pas un signal **comparatif**. → 3 marques cosmétiques (0 rated) sur le meilleur
  run de saison : **Survivant** (5-7 wins) / **Forgé** (8-9) / **Ascendant** (≥1 ascension). La
  comparaison sociale est un moteur de grind même cosmétique (Duradoni 2026). 3 marques seulement
  (anti-complexité). Méta, IO hors SIM, 0 invariant.
- **`slot_tier_composite` remplace `build_cost_proxy` (ranked §3.2)** : le `build_cost_proxy =
  Σ(rank×LEVEL_MULT)` est **volatil** — 5 rang-3 passent de proxy=15 (niveau 1) à 45 (niveau 3) après
  merges, alors que `wins_at_capture` est identique → filtre par **état de collecte instantané**, pas
  par qualité, et **réduit le pool** (aggrave le cold-start). Remède : `slot_tier_composite = shopTier
  × slots_actifs`, **monotone croissant** dans une run (le tier et les slots ne régressent jamais) →
  stable à la capture, informatif sur le stade. Lu de `state.lua` (champs existants), champ snapshot
  entier, IO hors SIM. `wins_at_capture` reste critère secondaire.
- **Signal de pool pré-run remplace `quality.human` (ranked §2.4/P4)** : le flag `quality.human`
  (grille /2 si <80 % humains) est un **couperet non-prévisible découvert après la run** = MMR-shadow,
  exactement ce qu'on a rejeté pour les floors TFT (« double système caché = confusion #1 »). Remède :
  afficher **avant** la run l'état du pool (🟢 Pool Vivant / 🟡 Pool Mince → progression partielle
  annoncée / 🔴 Puits Silencieux → unranked auto). Le joueur **choisit** en connaissance de cause. La
  transparence avant décision ≠ pénalité après (leveluptalk : la frustration vient du « hors de
  contrôle »). `snapstore:poolStatus(tier)`, RENDER pré-run, 0 invariant.

### 1.8 ADOPTÉ — Litige #H tranché : daily = « Contrainte du Jour » (option c)

**Source** : ranked §3.3/P3 + §4.2. **Tranche #H. 2 lentilles convergent (ranked + StS-lesson).**

- **Pourquoi a et b échouent (ranked §2.3)** : (a) efficience-vitesse et (b) ghosts thématiques
  mesurent **deux variantes du même comportement** (jouer une run, plus ou moins vite/contre des
  thèmes) — alors que le brouillon avait *raison* d'exiger que la daily mesure quelque chose de
  **différent** du ranked (c'est pourquoi `×(1+xp)` a été rejeté). Ni a ni b n'y parviennent.
- **Option (c) Contrainte du Jour** : la seed daily impose une **restriction mécanique** active toute
  la run — Jour de Brûlure (seules les unités `dot_family=burn` en boutique) / Jour du Puits (sigil
  `anneau` imposé, `[s]` verrouillé) / Jour de l'Abîme (reliques défensives D seulement) / Jour de
  Sacrifice (rang-4+ coûte +2 or). **La contrainte EST la différenciation** ; le score reste **brut**
  `daily = wins × (10−lives)` (SAP). Modèle StS Daily (modifiers imposés, force l'adaptation —
  slay-the-spire.fandom.com/wiki/Daily_Challenge). **Le joueur lui-même est contraint**, il ne peut
  pas « juste mieux jouer son build habituel ».
- **Transférabilité (ranked §3.3)** : la contrainte dérive de la **seed** (déterministe, #2), ne
  touche **pas la SIM** (filtre `U.pool` ou lock sigil = RENDER/data), leaderboard éphémère garde son
  sens (tout le monde joue la même contrainte). **Résout aussi la sous-question 8-9 wins** : sans
  `speed_mult`, une chute à 8 wins/0 vie = `8×5=40`, une ascension = `10×10=100` — distingués sans
  punir les quasi-ascensions à 0. **Implémentation minimale** : 2 contraintes (burn + sigil) pour
  valider, puis étendre. Litige résiduel #H' (calendrier éditorial : 5 vs 10-15 contraintes pour
  éviter la répétition — ranked §5.2).

### 1.9 ADOPTÉ — Litige #A2 tranché : Dernier Souffle EXISTE, à 1 vie, relique tier-4 seedée gratuite

**Source** : ranked §4.3. **Tranche #A2.**

- **À 1 vie, pas 0 (ranked §4.3)** : à 0 vie, la prochaine défaite = game over → trop **rare** pour un
  impact de rétention (combien de runs finissent à 0 vie ET remontent ?). À 1 vie (sur 5), le joueur
  est **sous tension haute mais pas désespéré** → le near-miss « je risque tout » est plus fort (Clark
  2009). La perte d'1 vie sur 5 ≠ la perte de prestige sur 0 du Bazaar (échelles différentes).
- **Forme** : une relique tier-4 **gratuite** (1-parmi-3 déjà seedé/équitable), catégorie E
  (transformative, **pas** runOp → ne touche pas #20), habillée « Le Puits vous donne une dernière
  chance ». **0 nouvelle mécanique.** Déterministe (seedée), ne modifie pas le snapshot. Test à
  ajouter : déclenchement exact à `lives == 1` avec le bon tirage. Articuler avec le « Moment du Run »
  (mention spéciale de fin si remontée — ranked §5.1).

### 1.10 ADOPTÉ — « Moment du Run » ancré à l'UNITÉ-SOURCE + post-combat « pourquoi » en CO-PRIORITÉ 1

**Source** : retention §2.1/Prop-A (attribution) + §2.4/Prop-D (priorité post-combat). **1 lentille, fort.**

- **Attribution causale (retention §2.1)** : en autobattler **full-spectateur**, la cascade se produit
  **sans input** du joueur → le VRR standard (action → récompense) est affaibli par le découplage
  temporel. Le signal doit être un mécanisme de **post-hoc attribution** : nommer **quelle unité du
  build** a déclenché la chaîne (« TON [NOM_UNITÉ] A PROPAGÉ SON AFFLICTION À TRAVERS 5 ENNEMIS »),
  lu du `source` du 1er événement de la chaîne max (le bus encode déjà `{source, cause, target,
  tick}`). +1 ligne de lecture. Renforce « *mon* unité a fait ça », pas « le jeu m'a donné un moment ».
- **Seuil de chaîne (retention §2.1)** : remplacer « chaîne ≤2 = pas de moment » (arbitraire) par
  **≥ médiane des cascades** mesurée en sim (si médiane=3 liens → seuil 4) → le signal ne se déclenche
  que pour les cascades au-dessus du commun. À mesurer `tools/sim.lua --chain-distribution` avant v0.9.
- **Post-combat « pourquoi » co-priorité 1 (retention §2.4)** : le brouillon le classe Priorité 2
  derrière la carte de risque. Mais la carte de risque est **prospective** (combats futurs) tandis que
  le post-combat est **rétrospectif** (combats perdus) — et pour la zone 0-5 victoires (la plus à
  risque de churn), convertir la défaite en compréhension est **plus urgent** que célébrer les
  victoires. → §2.4 passe **co-priorité 1 avec la carte de risque**. Coût identique (RENDER + bus).

### 1.11 ADOPTÉ — Courbe XP recourbée (climax mid-late) ; pity = SIGNAL sans garantie ; slot-decline option C

**Source** : progression §2.1/§3.1 (#K) + retention §2.3 + progression §2.4 (#L) + progression §2.3/§3.3.

- **Courbe XP (progression §2.1, NOUVEAU litige #K — fort)** : les seuils linéaires `{2,5,8,12}` +
  passive 1/round produisent une tension **plate** : T4 jamais atteint passif (intention OK) mais
  **aucun climax** mid-late (seuils et passive croissent au même rythme linéaire). Proposition [PH] :
  `XP_TO_LEVEL = {2,5,10,18}` (cumulé T5=35 vs 27) → coût marginal croissant sur les tiers tardifs
  (rush T5 = ~9 achats = ≥25 % du budget de run = décision **vraiment coûteuse**). **Démonte
  l'anti-analogie TFT** : TFT a des seuils *exponentiels* (T9 = 100 XP cumulées) + passive 2/round sur
  25+ rounds → le « 4g=4XP » TFT est tendu par le contexte, pas par le ratio ; chez nous le ratio 1:1
  est **neutre**, la tension vient du seul coût d'opportunité (4 or = 4 rerolls). Source : lolchess.gg/
  guide/exp. **C'est un correctif de calibration distinct de P3** (passe AVANT de figer les cotes).
- **Pity = signal sans garantie (NOUVEAU litige #L, retention §2.3 + progression §2.4 convergent)** :
  *deux lentilles* arrivent à la même conclusion par des chemins opposés. retention §2.3 : un pity
  **explicite avec garantie** (« +5 %/reroll, cappé ×2, garanti dans N ») **neutralise le VRR** et
  l'affect positif à la découverte (ScienceDirect 2025, Harbin ; MDPI 2025). progression §2.4 : le
  pity résout un problème **psychologique distinct** de la dilution de pool (signal d'escalation), donc
  il est **complémentaire** à l'audit, **pas secondaire**. → Synthèse : pity **complémentaire** (ne pas
  l'enterrer derrière l'audit) MAIS sous forme de **signal grimdark sans chiffre** (« L'ombre de cette
  créature est proche »), cote interne +5 %/reroll **cappée ×1.5** (pas ×2), déclenchée à **50-60 % du
  hunt médian** (~6-7 rerolls vs ~12 médian rang-3 T3). Garde-fou déontologique (progression §2.4) :
  or in-game ≠ monnaie réelle → pity sain ici. **Litige résiduel #L'** : le pity seedé (déterminisme
  #2) est-il compatible avec le near-miss *variable* ? (retention Q3 — compromis : seuil seedé,
  rencontre variable dans la distribution seedée). À spécifier avant P3.
- **Slot-decline option C (progression §2.3)** : 3e remède **non exploré** au slot-decline — décliner
  un slot = `+1 or` (au lieu de +3) **+ `+1 XP passive`**. Encode le trade « largeur vs **profondeur
  de catalogue** » (tall = boutique plus avancée), thématiquement cohérent (« descendre = profondeur »),
  et **découple l'or** du levier de casse. À sim vs option A/B (« tout refuser vs tout accepter »).

### 1.12 ADOPTÉ (DOC) — Drapeaux P3 ajoutés : inc des reliques B post-rééquilibrage ; entropie poison ; bleed/rot mid-game

**Source** : relics §2.5/Prop-D + synergies §2.5/P4 + relics Q3.

- **Dépendance circulaire des reliques B (relics §2.5)** : les inc des 4 reliques B
  (`kings_bowl=0.20` poison-apex / `ember_heart=0.30` burn-faible / `weeping_nail`/`grave_cap=0.18`)
  sont calibrés sur la hiérarchie **actuelle** (poison>...>choc) — qui est **le problème à résoudre**.
  → drapeau P3 : ré-évaluer les inc des B **après** le rééquilibrage des familles (le principe « forte
  → inc faible » tient ; les valeurs changent).
- **Cause structurelle de poison>choc (synergies §2.5)** : poison a **3 axes orthogonaux**
  auto-suffisants (stacks + weaken + propagation-mort) ; le choc, même en axe D, n'en a que **2
  séquentiels** (condensateur → ampli, qui dépend d'un tick qui suit). → tuner le choc seul = illusion
  si poison est sur-puissant **structurellement**. drapeau P3 (**précondition**) : mesurer
  `win_rate(poison) vs pool moyen` AVANT tout tuning ; si `> +1σ` persistant → levier = `contagion`
  propage **50 %** des stacks du mort (pas 100 % — paramètre data, synergies Q4/P4).
- **bleed/rot mid-game (relics Q3)** : le critère ≥2/archétype est à la limite pour bleed/rot (≈24 %)
  ET les 2 reliques sont souvent **toutes deux late** (open_wounds tier-4) → vérifier qu'**≥1 relique
  bleed/rot est accessible dès mid-game** dans le gating de `rollRelicChoices`.

---

## 2. CE QUE JE REJETTE OU TEMPÈRE (et pourquoi)

### 2.1 TEMPÉRÉ — `swarm_logic` reformulée en relique d'adjacence : bonne idée, mais NE PAS empiéter sur P4

**Source critiquée** : relics §2.3/Prop-B.

La critique est juste sur un point : `swarm_logic` formulée « ≥6 unités → bonus » est une relique de
**quantité** avec un dead range (inerte jusqu'au slot 6). La reformulation « chaque arête active au
build donne +X % aux deux unités » est élégante et cohérente avec le pilier « la forme EST le graphe ».
**MAIS** : (a) relics §2.3 reconnaît elle-même que ça « empiète sur le territoire conceptuel des
reliques G (P4) » ; (b) une relique d'adjacence calculée sur `shapes[shape].edges` est exactement le
**genre de mécanique réservé aux reliques G** (topologie). → **Tempéré** : `swarm_logic` reste l'archétype
**wide** requis par la nécessité statistique (P(aucune)=100 % aujourd'hui), mais formulée **sans dead
range** via l'option **scalante** (cohérente avec §1.5) : « +X % à l'équipe **par unité au-delà de 4** »
(immédiat dès la 5e unité, pas un gate ≥6). La version « par arête » est **notée pour P4** (relique G
candidate), pas P1.5b. Ça évite de pré-cuire P4 et garde wide ≠ topologie distincts. **Litige résiduel
#M** : wide = quantité (P1.5b) vs adjacence (P4) — à trancher quand les reliques G sont spécifiées.

### 2.2 TEMPÉRÉ — Asymétrie de coût BUY_XP variable (progression §3.2) : garder OPTIONNEL, après sim des seuils

**Source** : progression §3.2 (l'auteur lui-même le classe OPTIONNEL).

Le coût d'achat XP croissant (3/4/5 or par tier) ou la quantité décroissante (4/3/2 XP) ajouterait de
la tension — mais c'est une **innovation non testée** (ni SAP ni TFT ne l'ont) sur un levier déjà
sous-documenté dans l'UI. La lentille progression le reconnaît : **ne pas activer avant d'avoir mesuré
l'effet des seuils recourbés seuls (§1.11/#K)**. → conservé en « à l'étude », **subordonné** à la sim
de la nouvelle courbe. Si la courbe `{2,5,10,18}` suffit à créer le climax → **ne pas ajouter** ce
mécanisme (lisibilité > complexité).

### 2.3 REJETÉ (pour P1) — Axe C du choc tel que formulé : retiré comme infaisable proprement

**Source critiquée** : brouillon v3 §3.3 (axe C), confirmé infaisable par synergies §2.1 + units §2.3.

L'axe C (amplifier le hit déclencheur, fidèle à PoE) est **retiré de la matrice de décision** : (a)
mécaniquement il exige de réordonner `hit()` (vérif synthétiseur), touchant les invariants #22-32 ; (b)
l'analogie PoE est fausse (PoE ne stacke pas, ampli toutes sources sur la durée ; nous stackons,
mono-cible). Il survit uniquement comme **note historique** (« écarté, voici pourquoi »). L'axe D le
remplace (§1.1). **La variante C-durée** (synergies/units : amplifier *tous* les ticks sur N ticks)
est **fusionnée dans l'axe D** comme paramètre `duration` du litige #G (D-ponctuel = 1 tick ; D-durée
= N ticks) — à trancher en sim.

### 2.4 TEMPÉRÉ — Escalade de la passive XP (+2 en round 8+, progression Q2) : à mesurer, pas à acter

C'est une **question ouverte**, pas une proposition. Une passive qui escalade renforcerait la narration
« la boutique s'enrichit en descendant » mais risque de rendre T5 accessible passivement (XP achetée
inutile). → reste une **question pour la sim de la courbe** (#K), pas un livrable. Ne pas empiler deux
changements de courbe non mesurés.

### 2.5 REJETÉ (faible) — `season_wins` perd son sens passé 200 (retention Q5) : vrai mais hors-horizon

retention Q5 note qu'un compteur qui monte toujours « n'est pas une progression, c'est une accumulation ».
Juste en principe — mais (a) c'est exactement pourquoi les **marques sub-tier** (§1.7) sont adoptées
**en plus** de `season_wins` (le signal comparatif borné que la critique réclame existe déjà dans la
roadmap intégrée) ; (b) « passé 200 victoires en saison 3 » est un problème de joueur ultra-engagé que
la rotation de saison (reset) + les reliques G traitent. → pas un litige actif ; `season_wins` reste un
**affichage** secondaire, les marques sont le signal de progression.

---

## 3. CONSENSUS STABILISÉ (ne pas re-litiger sans preuve nouvelle)

Reconfirmés ce round par ≥1 lentille, sans contestation :
- **Unité de compétition = le RUN** (ranked §1.1, 3e confirmation : Bazaar S2 par wins de run).
- **Grille ranked SANS pénalité** (ranked §1.2/§2.1 ; renforcée par recherche tilt/anxiété).
- **Pools séparés ranked/unranked + ghost replacement** (ranked §1.3).
- **`dot_family` champ dédié orthogonal à `type`/`family`** + règle « 1er DoT non-aura »
  (synergies §1.1, units §1.2) **+ lint check.sh** (nouveau garde-fou).
- **Cap ×3 anti-snowball** borne l'output, **pas** le `increased` total ni le `more` (synergies §1.2,
  relics §1.5) → **le twist de palier 4 doit être spécifié comme `more` borné séparément, ou hors
  `Stats.resolve`** (sinon il échappe au cap — litige #B précisé).
- **Seuils de palier 2/4** (pas 2/4/6) = optimum de diversité sous 9 slots (synergies §1.4).
- **Or fixe + streaks + cost=rank + refund 0.5×** (progression §1.1-1.3, verrouillés).
- **Garantie de pertinence sur B-E seulement** + **migration F→marchand en P1.5c** + **critère
  ≥2 reliques/archétype P<25 %** (relics §1.1-1.4).
- **Litige #C CLOS** (rating global unique) — 3e confirmation Backpack (ranked §4.4).
- **Moment du Run + Codex bootstrappé + Grimoire=connaissance** (retention §1.1-1.5).

---

## 4. LITIGES OUVERTS POUR LE ROUND 4 (consignés)

| # | Litige | Position round 3 | Critère de résolution |
|---|---|---|---|
| **#A** | P1 (types) vs P2 (ranked) en premier | types d'abord (2 args round 2) | `--meta-convergence` < 8 runs / ≥2 sigils (§7.1 roadmap) |
| **#B** | Double-comptage inc% ; **nature stats du twist** | borné par cap ×3 ; twist = `more` **à borner séparément** | spécifier la nature AVANT P1 ; lift de co-occurrence en sim |
| **#D** | Compteur type **global** vs **adjacence-type** | global v0.10 | **critère corrigé (synergies §2.2)** : variance win% sur **permutations positionnelles** > 0.05 → adjacence enrichit (mesure causalité, pas corrélation) |
| **#E** | Hunt 3e copie : pity vs freeze vs deux | pity = **signal sans garantie** (§1.11/#L) **complémentaire** à l'audit | hunt médian APRÈS nettoyage pool ; sim Pop A (garantie) vs Pop B (signal) sur `session_length_post_acquisition` |
| **#F** | 6e type non-DoT | « aucun » (shield/tank = enablers transversaux) | confirmer en P1 ; **dépend de #G** (axe D ne réduit pas les 4 DoT-dégât) |
| **#G** | Axe choc : ~~C~~ retiré → **A / B / D** | **D (décharge sur 1er tick DoT)** | sim **4 configs** + sous-question **D-ponctuel vs D-durée** ; rebaseline golden |
| **#H** | Format daily | **(c) Contrainte du Jour** (score brut) | prototype 2 contraintes ; **#H'** calendrier (5 vs 10-15) |
| **#I** | Grille ranked + hauteur paliers + écrémage | grille `+4/+2/+1/0` + ~35 pts + **marques sub-tier** + écrémage explicite | `tools/ladder_sim.lua` : médiane monte ~1 tier/saison |
| **#J** (NOUVEAU) | E tier-4 : **gate vs scalante** | **scalante** (dead range démontré) | tranché §1.5 ; sim valeurs [PH] |
| **#K** (NOUVEAU) | Courbe XP linéaire vs recourbée | **recourbée `{2,5,10,18}`** (climax mid-late) | sim politiques passif/rush : T4 jamais passif ET rush T5 ≥25 % budget |
| **#L** (NOUVEAU) | Pity garantie vs signal ; seedé vs variable | **signal sans chiffre, cappé ×1.5** ; **#L'** seedé⊗variable | sim Pop A/B ; spécifier compromis seed-position/rencontre-variable |
| **#M** (NOUVEAU) | Relique wide : **quantité** (P1.5b) vs **adjacence** (P4) | quantité scalante en P1.5b ; adjacence = relique G candidate | spécifier quand les reliques G sont définies |
| **#A2** | Dernier Souffle | **tranché** : existe, à 1 vie, relique tier-4 seedée gratuite (§1.9) | test `lives==1` ; mention de fin (#5.1 ranked) |
| **#H'** (NOUVEAU) | Calendrier éditorial daily | — | 5 contraintes = cycle 5j ; 10-15 pour éviter répétition ? |

**Questions de fond reportées** (modélisation, pas tranchage) :
- **Plafond de connaissance avant fin P3 (retention §2.2/Prop-B)** : calcul ~72 runs pour tout
  connaître ; **joueur très actif (5 runs/sem) = plafond DANS la saison 1** → critère d'alarme
  `season_wins ≥ 50 ET Grimoire.synergies ≥ 25` → prototype relique G **pendant** P3 (`tools/sim.lua
  --knowledge-ceiling`). **Non tranché** (cadence exacte = sim).
- **Risque circulaire garantie-pertinence early (progression Q4)** : mesurer sur 200 seeds la
  distribution des familles au round 3 (si >70 % ont une famille dominante 3-5 unités → mitigation
  réelle ; <40 % → inutile).

---

## 5. Index des sources (round 3)

**Vérifs code synthétiseur (lecture seule, citées)** :
- `src/combat/arena.lua:325-395` — **ordre `hit()`** : `bus:emit("hit") → Effects.run(on_hit) → if
  target.alive then dischargeShock()` ; `dischargeShock` : `burst = stacks×volt`, `damage(target,
  burst, {ignoreShield=true, cause="shock"})` puis consomme. **Prouve que l'axe C exige de réordonner
  `hit()`** (le hit déclencheur est déjà appliqué) → valide l'axe D (décharge dans `tickDots`, après
  le cycle de frappe). Modificateurs `chain`/`transfer`/`persist` confirmés.
- `src/data/units.lua:72-447` — **rot rang-2** = `rot_hound`(capDps=10) + `rot_grub`(capDps=6) +
  `bore_worm`(v7, capDps=8) ; **bleed rang-2** ≥4 ; **rang-5 v7** `skull_colossus`/`deep_kraken` =
  profils stat-stick. Confirme le plancher rot (§1.3) et l'audit rang-5 (§1.4).

**Critiques round 3 (lentilles)** : `rounds/r03-{units-power, synergies-effects, relics,
progression-economy, ranked-competitive, retention-addiction}.md`.

**Sources web nouvelles citées par les lentilles ce round** (validées comme pertinentes) :
- PoE Shock = Non-Damaging Ailment, cap 50 %, **no-stack en intensité**, ampli sur la **durée** :
  poewiki.net/wiki/Shock ; mobalytics.gg/poe-2/guides/shock — **fonde le rejet de l'analogie axe C**.
- StS *Vulnerable* (ampli séquentiel prochaine attaque) : slaythespire.wiki.gg/wiki/Vulnerable —
  fonde l'axe D.
- StS Daily Challenge (modifiers imposés = format core) : slay-the-spire.fandom.com/wiki/Daily_Challenge ;
  StS2 : bossdown.com/guides/slay-the-spire-2-daily-climb-guide/ — fonde l'option (c) daily.
- GhostCrawler power-budget : askghostcrawler.tumblr.com (2017) — fonde la colonne budget P0.5.
- Giovannetti GDC 2019 (« trop de cartes pareilles ») : gamedeveloper.com — fonde l'audit rang-5.
- TFT pool/XP : lolchess.gg/guide/exp (XP cumulées exponentielles) ; esportstales.com (pools) —
  fonde le litige #K (courbe XP) et le calcul de plancher.
- Duradoni et al. 2026 (rang = anxiété/frustration) : onlinelibrary.wiley.com/doi/10.1155/ijcg/8961143 ;
  tilt : tandfonline.com/doi/full/10.1080/10413200.2025.2483688 — fonde le gouffre mid-core + marques.
- Bazaar Legendary = rating moyenne 0-1000 : steamcommunity.com/app/1617400/... ; grille S2 sans
  pénalité : screenrant.com/bazaar-how-to-play-ranked-ccg/ — reconfirme unité=run.
- Pity : ScienceDirect 2025 (Harbin) sciencedirect.com/.../S1875952125001247 ; MDPI 2025
  mdpi.com/2078-2498/16/10/890 ; Frontiers Psychiatry 2024 — fondent #L (signal vs garantie).
- Endowed progress (Nunes & Drèze 2006) : conservé — fonde l'option scalante (§1.5).
- VRR (Skinner/Hopson) : explorepsychology.com ; Kammonen 2023 theseus.fi (plafond de connaissance) ;
  Juul « Fear of Failing » jesperjuul.net ; Grid Sage Games 2025 (mastery) — fondent §1.10.
- leveluptalk.com (frustration = hors contrôle) — fonde le signal pré-run (§1.7).

**Sources rounds 1-2 conservées** : voir `round-01.md` §index, `round-02.md` §index (non répétées).

---

*Round 03 acté le 2026-06-23 par le SYNTHETISEUR. Intégration critique des 6 lentilles : adoptions
sourcées, rejets/tempéraments motivés (axe C retiré, swarm_logic tempérée, BUY_XP variable subordonné).
Vérifs code menées (ordre `hit()`/`dischargeShock`, rot rang-2, rang-5 v7). Roadmap réécrite en v4.
Lecture seule du repo ; n'édite que sous `docs/roadmap-lab/`. Piliers respectés. 32 invariants
préservés (toute modif choc/snapshot signalée : axe D = rebaseline golden ; `slot_tier_composite`,
marques, Contrainte du Jour = IO/RENDER hors SIM). Améliorations mesurables vs v3 : §1 de la roadmap v4.*
