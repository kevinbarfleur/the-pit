# OPEN-QUESTIONS — litiges non résolus après 10 rounds

> **Rôle.** Compagnon de `ROADMAP.md`. Liste les **litiges encore ouverts** à la fin du roadmap-lab,
> avec pour chacun : (a) **l'enjeu**, (b) **les options en présence**, (c) **ce qui le tranche** (sim
> nommée / playtest / décision éditoriale user / relecture code) et (d) **quand** (jalon).
>
> **Convention.** Un litige ne se clôt **que sur preuve** (sim concluante, code-vérification, ou décision
> user consciente), jamais sur consensus mou. Les litiges déjà **CLOS** (par preuve) sont rappelés en fin de
> document pour mémoire — ne pas les re-débattre. Source canonique des n° de litige : `ROADMAP-draft.md §12`
> et `round-10.md §8`.
>
> **Garde-fou transversal `#JJ` (adopté, pas un litige).** Tout payoff de build s'ancre sur une cause
> contrôlée par le joueur (compo/placement/décision), jamais sur la cible/l'exposition/l'adversaire. C'est
> devenu l'**outil de clôture** de plusieurs litiges (#HH, #II tranchés par lui). À appliquer à toute
> nouvelle relique/badge/signal/palier.

---

## A. BLOQUANTS — à trancher AVANT le chantier dépendant

### #GG — Axe de l'apex choc (avant P1)
- **Enjeu.** Sur quel axe le choc apex amplifie-t-il ? `dischargeShock` est aujourd'hui un **burst** (axe A/B) ;
  l'**axe D** (ampli du 1er tick DoT) n'est **pas implémenté** (`arena.lua` code-vérifié) → le « 0 moteur » des
  rounds antérieurs est faux si l'axe D est retenu.
- **Options.** Option 1 (les 2 axes coexistent : `shockChain` burst + axe D ampli tick) · Option 2
  (`shockAmpMult` paramétrable → cohérence axe D, moteur minimal).
- **Précisions round 10.** Le palier choc-4 (#HH = `tickCount=2`) est **découplé** de #GG (compatible avec les
  2 axes) ; l'apex = **NOUVELLE unité** rang-5 `type=arcane/abyss` (pas `skull_colossus`, DA-invalide).
- **Tranché par.** **Sim P0.5** : 4 configs + `discharge_effective_ratio` (config sans-DoT) ; si < 0,40 →
  Option A auto-DoT (CONFIG-CE2). + décision sur le moteur minimal (Option 2) vs coexistence.
- **Quand.** P0.5 (`v0.9.5`), avant P1.

### #LL — Ancre de capture du snapshot ranked (avant le code ranked P2)
- **Enjeu.** Capturer le snapshot seulement à `startCombat` laisse une faille « concede meta » (run avorté
  avant = pas de ghost = pool FIFO local biaisé ; Steam Bazaar août 2025 « kinda HAVE TO concede to win »).
- **Options.** (a) 1er achat (`shopBuys ≥ 1`) · (b) round 2 · (c) `startCombat` (actuel). **Recommandation :
  les deux premières en OR** (whichever first), exclusion du jour-0 identique.
- **Tranché par.** Décision d'implémentation (~5 lignes IO) + **mesure de densité du pool** (impacte #Y).
- **Quand.** P2 (`v0.11`), prérequis bloquant.

### Q_R9_2 / Q_R10_4 — Gate du signal de relief sur `ghost_is_human` (avant le code §1.9 / signal relief)
- **Enjeu.** En bêta, la majorité des adversaires sont des IA → un signal « tu as survécu à un build réel »
  non gaté est banal dès le round 1.
- **Options.** Gate sur `ghost_is_human == true` · pas de gate · formulation distincte IA/humain.
- **Tranché par.** **Décision éditoriale user** (consciente, pas par défaut) + précondition **CONFIG-SURVIVAL**
  (seuil PV par rôle calibré en sim : `P(hp_ratio < 0,25 | victoire | rôle)`, N≈200).
- **Quand.** Avant le code du signal relief (P0, mais le signal est bloqué jusqu'à CONFIG-SURVIVAL).

### #U — Cible de la Contrainte de Saison (avant la S1 livrée en P2)
- **Enjeu.** Quelle famille/axe la Contrainte de Saison amplifie-t-elle ? Le débat « plus bas win-rate vs plus
  sous-représentée » était mal posé (symptômes).
- **Vrai critère (round 9).** « **axe RÉSOLU** dans `seed/decisions.md` + plus grand écart [potentiel théorique
  sim] − [win-rate réel] ». **Prérequis :** choc gelé tant que #GG ouvert ; burn gelé tant que désert rang-3
  non résolu. S1 candidate = `bleedSlow2x` ; **fallback absolu = modificateur de sigil pur** (`lineSlow2x`).
- **Tranché par.** Sim post-P0.5/P3 (écart potentiel/réel) + état de #GG.
- **Quand.** P2 (`v0.11`), choix précis après P0.5.

---

## B. CONTENU — sim ou critère à documenter avant gravure

### #A — Priorité P1 (types) vs P2 (ranked)
- **Enjeu.** Si les types convergent vite vers une compo dominante, les livrer avant le ranked remplit un pool
  ranked sain ; sinon le ranked pourrait passer d'abord.
- **Tranché par.** **`--meta-convergence`** : `rang_convergence < 8 runs` pour **≥2 sigils** → types d'abord.
  **À mesurer sur une méta saine** (après `--poison-frac` ET `--no-weaken`) et sur **runs unranked libres
  uniquement** (exclure runs ranked teamFlag + Daily à contrainte familiale → biais de sélection vers le méta
  dominant = convergence artificielle).
- **Quand.** P3 (la roadmap pose P1 avant P2 par défaut ; ce critère peut inverser).

### #B — Saturation `inc` + saturation des ARÊTES (avant P1)
- **Enjeu.** Le cap ×3 borne l'**output**, mais pas le `increased`/`more` → un twist de palier 4 `more` doit
  être borné séparément ; et la profondeur **positionnelle** (la signature) n'a jamais été mesurée.
- **Tranché par.** **2 tableaux combinatoires** (0 sim) : (1) saturation `inc` par famille (poison à 0,90 d'inc
  naturel = `[SATURATION_RISK]`) ; (2) saturation des arêtes par (sigil × famille × slots), alarme < 0,3 à 7
  slots. `#FF` et `resonance_stone` y **entrent** avant gravure.
- **Quand.** P0.5/P1 (`v0.9.5`→`v0.10`).

### #CC — `wither_bloom` après la correction `afflictionCount` (C2)
- **Enjeu.** Avec C2, `afflictionCount(wither_bloom) = 1` → son rôle multi-affliction s'effondre.
- **Options.** Reconcevoir (dps non nuls sur rot/bleed/poison) · accepter (rot + slow + weaken cosmétiques).
- **Tranché par.** **Critère documenté AVANT P1** (§3.8 draft) ; code en P1.5b. Lié à l'op `apply_status` (C1).
- **Quand.** critère en P0.5, code en P1.5b.

### #FF / #II — Interactions inter-familles MID (directionnalité)
- **Enjeu.** Récompenser la **diversification** (aggravation croisée + contagion au kill) sans dépasser la
  saturation ni rendre l'effet invisible.
- **Options.** #II : **Option B symétrique** (les 2 familles co-présentes du BUILD s'amplifient = condition
  FORTE #JJ — **recommandée**) vs Option A directionnelle (condition partielle).
- **Tranché par.** **Décision user** (Option B = rebaseline golden potentielle = garde-fou explicite) +
  **précondition `combat_effect_legibility`** (avg/max events/tick, batching si > 4) + tableau de saturation
  (#B). **SPEC À PROUVER en sim, pas gravé.**
- **Quand.** P1.5b (`v0.10.5`), après saturation.

### #M — Relique « go-wide »
- **Enjeu.** Récompenser l'essaim par quantité scalante (P1.5b) ou par adjacence-par-arête (relique G, P4) ?
- **Tranché par.** Décision liée aux **reliques positionnelles** (M7/§6.1) et à l'arc reliques G.
- **Quand.** P1.5b vs P4.

### #X — Relique de contre-jeu méta (« le Puits subi vs appris »)
- **Enjeu.** Une relique qui lit le log post-combat pour renforcer contre les afflictions subies est-elle
  compatible DA (le Puits **appris** vs **subi**) ?
- **État.** `hollow_choir → pierceShield` est un candidat **light** (counter-bouclier, 0 SIM lourde) décidé pour
  P1.5b ; la version « lit le combat précédent » (`war_scar`) touche la SIM (`previousCombatAfflictions`) →
  **subordonnée** à la Q DA + après équilibrage P3.
- **Tranché par.** Décision DA user + colonne (I) de l'audit (révèle si un counter-bouclier comble un trou réel).
- **Quand.** light en P1.5b ; lourd en P3+.

### #E / #L — Hunt de la 3e copie (pity)
- **Enjeu.** Garantir une 3e copie sans neutraliser le VRR.
- **Tranché par.** **Sim Pop A/B + hunt médian** (après nettoyage du pool) ; pity = **SIGNAL sans garantie**,
  seuil `max(3, 0,5×médiane)` (plancher absolu) + progression visuelle implicite, cappé ×1,5. #L' : seuil seedé
  ⊗ rencontre variable.
- **Quand.** P3 (`v0.12`).

---

## C. ÉCONOMIE — intention à déclarer puis sim

### #R (ex-#K) — Recourbe de la courbe XP
- **Enjeu.** La courbe doit être robuste à la **variance de durée de run** (10-19 rd) + intégrer les **streaks**
  dans le budget réel + **co-calibrer** `shopTier`/`slots`.
- **Tranché par.** **Sim P3** : tester `{2,5,10,18}` ET `{2,5,10,20}` ; **table du plafond passif** (prédit
  `--xp-climax` sans le lancer) ; recalibrer `SLOT_DECLINE_XP` ; **dépend de `REROLL_COST`** ; co-calibration
  rush_XP + option_C (archétype viable ou gaspillage ?). Hiérarchie de remèdes condition 4 : R1 communication >
  R2 data (`BUY_XP_COST` T1→5g) > R3 exclusion, **ordre strict**.
- **Quand.** P3 (`v0.12`), précédée du tableau d'intention §7.0.

### `REROLL_COST` — statique / scalant / soft-cap (intention à déclarer)
- **Enjeu.** `cost=rank` fait dériver le coût relatif du reroll de 1:1 (T1) à 1:5 (T5) — SAP (prix uniformes,
  1:3 constant) ne partage pas cette dynamique. La valeur **n'est pas neutre**.
- **Tranché par.** **Documenter l'INTENTION** (statique/scalant/soft-cap) dans le tableau §7.0 **AVANT** la sim,
  puis sim `--reroll-cost-scaling` (2 métriques T1-vs-T3) — **pas par décret**. `P(doublon T1) ≈ 62 %` justifie
  partiellement garder = 1.
- **Quand.** intention en P3 (précondition), valeur en P3.
- **Q ouverte associée.** La dérive 1:5 est-elle **perçue** par le joueur ? → playtest.

### Rôle de la passive XP : [A] levier vs [B] rituel
- **Enjeu.** La passive (1/round) est-elle un **levier** d'équilibrage (`passive_vs_bought_ratio` 20-50 %) ou un
  **rituel** perçu comme un don ?
- **Tranché par.** **Décision user** (à déclarer dans §7.0) ; si [B], précondition de **framing** (« LE PUITS
  T'ACCORDE SA MARQUE », Endowed Progress Effect — Amabile & Kramer retirée car « travail signifiant » ≠ jeu).
- **Quand.** P3 (déclaration), avant `--xp-climax`.

---

## D. RANKED & MÉTA — à mesurer en P2

### #Y — FIFO ranked au reset de saison (ré-ouvert round 10)
- **Enjeu.** Au reset, vider le pool ou le filtrer ?
- **Options.** **Persistance filtrée** (`wins_at_capture ≥ 3` + `slot_tier_composite`, double critère ;
  n'exige pas `sv` ; défaut §6.3) vs **vidage complet** (exige `snapshot_schema_version`/#V).
- **Tranché par.** **Mesure de densité du pool** avec la nouvelle règle de capture #LL (qui remplit la grâce 7 j
  plus vite) → l'argument filtrée vs vidage change.
- **Quand.** P2 (`v0.11`), avant la spec FIFO de saison.

### #KK — Profondeur du Puits (per-run vs record-saison)
- **Enjeu.** Afficher le round max atteint comme 2e dimension orthogonale au LP.
- **État.** Recommandation = **les deux** (per-run au score-screen + record-saison au pré-run).
- **Prérequis (round 10).** **1 grep sur `encounters.lua`** AVANT le code du signal : si l'escalade IA est plate,
  la Profondeur mesure un plafond d'éco (or), pas de skill → reformuler ou résoudre la dette de contenu d'abord.
- **Quand.** P2 (`v0.11`).

### #V — `snapshot_schema_version` (`sv`)
- **Enjeu.** Versionner le schéma du snapshot.
- **État.** **Différé** (`dot_family` déduit dynamiquement → pas de `nil` dans le cas courant ; `toComp` ignore
  les ids inconnus). **Requis seulement si #Y choisit le vidage complet** du FIFO de saison, ou au 1er champ
  persisté (reliques v2).
- **Tranché par.** Re-lié à #Y → ré-évaluer en P0.5/P2 quand on tranche #Y.
- **Quand.** v1.0 ou plus tôt si #Y = vidage.

### #AA — Seuil + DA du signal VRR de boutique
- **Enjeu.** Cadence et formulation du « le Puits résiste à ta faiblesse ».
- **État.** Cible ~30 % des rerolls (Hopson) ; formulation « résistance » ; **jamais au 1er shop du round** ;
  Phase 2 = 3e facteur (distance-3e-copie) ; **pondération hédonique** (borne ≤ ~50-60 events pondérés/run,
  couper poids=1 d'abord). **ASSUME l'affichage séquentiel** (M7/§5.1) en place.
- **Tranché par.** **Calibration P3** + playtest de saillance.
- **Quand.** réglage en P3 ; structure en P0.

---

## E. PLAYTEST / DÉCISION USER (non tranchables en sim)

| Question | Ce qui la tranche |
|---|---|
| **Cadence exacte de l'animation séquentielle** du Moment du Run (80 ms ? 120 ms ? courbe d'accélération) | **Playtest** (ressenti, pas sim) ; Q_R10_1 |
| **FOMO de famille** dans le Grimoire (sections non jouées) | **Résolu doc** : sections réduites, compteur discret, pas de silhouettes → l'Ovsiankina se déclenche sur la section active |
| **Reliques vues en boutique** affichées au Grimoire ou seulement acquises ? | **Recommandation** : VUE = silhouette + nom ; ACQUISE = + effet (modèle StS) ; Q_R10_2 — confirmer en playtest |
| **Reliques G** : sous-ensemble minimal v0.13 (1-2 formes) + tests d'exposition AVANT le code ? | **Décision user** + tests d'exposition par sigil |
| **Quand le backend ?** Ranked local + Daily local suffisent-ils à prouver la boucle ? | **Décision user** après mesure d'engagement du ranked local |
| **Reset ranked conditionnel** : `< 3 runs/saison` → reset à 0 (pas −20 %) + message ? | **Décision user** (UX) |
| **Cosmétiques de saison** : modal vs log Grimoire + message menu ? | **Tranché** vers log + message ; modal réservé si le retour user montre un manque de saillance |
| **Vue Grimoire II PAR ARCHÉTYPE** (en plus de par famille) | **Subsumée** par le Nom de Build ; à intégrer **seulement si** la 1re segmentation (par famille) est validée |

---

## F. Litiges DÉJÀ CLOS (mémoire — ne pas re-débattre)

> Clos **par preuve** au cours des rounds. Rappelés pour éviter la régression de débat.

| # | Résolution | Round |
|---|------------|-------|
| **#C** | Rating global unique (5 ratings = ranked inexploitable) | clos |
| **#D** | Compteur de type **GLOBAL PUR** (seuils 2/4, sans adjacence ; dead-zone TFT Galaxies) ; `--position-variance` repositionné = calibrer les auras | 6 |
| **#S** | Ampli choc-D sur la **`dot_family` du poseur** (l'ordre fixe pur trahit la famille du build) | 5 |
| **#T** | `RANKED_MIN_POOL` SOFT=3 / HARD=5 progressif | 6 |
| **#O** | `famines_math` = option (a) « 3 plus coûteuses », spec `R.apply` (tri stable par `id`) + test | 6 |
| **#W** | burn-vuln-bouclier **intentionnel** ; twist burn-4 = `burnIgnoreShield` | 6 |
| **#Q2-relics** | `forked_tongue` non silencieuse (`shockChain` consommé `ops.lua:187`) | 7 |
| **#Z** | IA formulée distinctement (gate bloquant de « spectre affronté ») — décision DA finale user | 8 (recommandé) |
| **#DD** | `--pool-repr` AVANT `--poison-frac` (ORDRE STRICT ; retirer `corruptor` change la repr rang-3) | 8 |
| **#BB** | Daily UNRANKED + leaderboard journalier, **conditionnel au SEED PARTAGÉ** ; scope combat seul | 8 |
| **#EE** | Seuil Nom de Build **progressif** (≥2 / ≥3 / ≥4) | 8 |
| **#EE-ranked** | Scope du seed daily = **combat seul** (shop libre) | 9 |
| **#J** | `plague_communion` → ancrage **compo du joueur** (`dot_family_count ≥ 2`), +25 % flat (#JJ) | 9 (re-tranché) |
| **#A2** | Dernier Souffle : à 1 vie, relique tier-4 seedée gratuite | tranché |
| **#HH** | Palier choc-4 = **Option B** (`tickCount=2`) via #JJ → **découple #GG** | 10 |
| **#II** | Directionnalité #FF = **Option B symétrique** via #JJ (recommandé à décision user) | 10 |
| **`skull_colossus` apex choc** | **RETIRÉ** (DA-invalide `type=bone` + électricité) → apex = nouvelle unité `type=arcane/abyss` | 10 |
| **Cadence saison 3 sem.** | **CORRIGÉ → 5 sem. S1-S2** (Milkman démontée ; Bazaar mensuel = pool mondial ≠ FIFO local) | 10 |

---

*Compagnon de `ROADMAP.md`, état après round 10 (FINAL). Lecture seule du repo ; écriture uniquement sous
`docs/roadmap-lab/`. Un litige ne se clôt que sur preuve (sim concluante, code-vérification, ou décision user
consciente). Détail round par round : `round-0{1..10}.md` ; n° de litige : `ROADMAP-draft.md §12` + `round-10.md §8`.*
