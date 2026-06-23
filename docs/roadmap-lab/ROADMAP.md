# ROADMAP — The Pit (finale, après 10 rounds adversariaux)

> **Statut** : version finale du roadmap-lab. Synthèse exécutable de `BRIEF.md`, `00-state.md`,
> des 10 teardowns `competitive/*.md`, des 60 critiques `rounds/r0{1..10}-*.md`, des 10 synthèses
> `round-0{1..10}.md` et du brouillon intégré `ROADMAP-draft.md`. **Priorisée, séquencée en jalons,
> chiffrée où possible.** Orientée **fun + addictif + ranked compétitif** (enchaîner les runs pour grimper).
>
> **Règles de lecture.** Chaque reco majeure porte (a) son **POURQUOI + source** (URL de jeu/article/
> recherche, ou `fichier:ligne` du repo) et (b) une **note de transférabilité** à nos contraintes. Les
> valeurs **[PH]** sont des placeholders d'équilibrage à valider via `tools/sim.lua`. Les litiges restants
> vivent dans `OPEN-QUESTIONS.md`.
>
> **Garde-fous (non négociables, hérités de `00-state.md`).** 4 piliers : **async par snapshots** ·
> **sim déterministe seedée** · **DA grimdark** · **pixel art 100 % procédural**. 10 décisions définitives.
> 32 invariants de test. Toute proposition qui touche un invariant le **signale** et exige le changement de
> test **avant** le code. **Aucune modification du code ni des tests par ce lab** ; il n'édite que sous
> `docs/roadmap-lab/`. Boussole : *simplicité de gestion → profondeur émergente* (réf SAP/Batomon) ;
> reliques **lisibles** (StS) ; **égalisateurs, pas de gates** ; petits nombres.

---

## RÉSUMÉ EXÉCUTIF — les 8 mouvements majeurs

> **Diagnostic central (révisé rounds 4-10).** *Le jeu a un moteur solide ; il lui manque LA RAISON DE
> RÉENCHAÎNER — et son contenu a des trous, des collisions et des bugs latents que seule la relecture du
> code révèle.* La relecture ligne-à-ligne (rounds 4-10) a débusqué : des reliques décrites mais
> inexistantes, `afflictionCount` qui compte la présence (faux signal `plague_communion`), des renforts de
> bouclier dead-pick, l'absence de séparation ranked/unranked dans le snapshot, des paires d'unités en
> dominance stricte, une faille d'intégrité « concede meta », et — fil rouge du round 10 — **la signature
> du jeu (le plateau-graphe) sous-spécifiée** (aucune relique positionnelle, saturation des arêtes jamais
> mesurée, high-roll spécifié comme probabilité au lieu de feedback séquentiel visible). **Leçon de méthode :
> vérifier ce que le code fait vraiment avant d'empiler du design.**

**M1 — Rendre le jeu LISIBLE et MÉMORABLE avant tout le reste (P0).** Surlignage des arêtes d'adjacence,
carte de risque (exposition front/back), écran post-combat « pourquoi », **Moment du Run** et **Nom de Build**
nommés, **barre XP de boutique** visible, **VRR de boutique** (la boutique « résiste » → moteur du *one-more-run*),
et **signal de relief « contre la mort »** (le seul VRR de valence négative-puis-positive). *Pourquoi :*
multiplicateur de fun à coût quasi nul, et **précondition** de l'attribution causale dont dépend le ranked et la
rétention (Backpack §4.4 lisibilité ; Balatro §8.2 *juice* = attribution causale, GMTK 2024 ; Artifact
postmortem = mort par opacité). *Transfert :* tout est **RENDER**, lu du bus d'événements JSONL qui porte déjà
`source/cause/tick` — **zéro touche SIM, zéro invariant**. **C'est le multiplicateur de toute la roadmap.**

**M2 — Assainir le CONTENU avant de bâtir dessus (P0.5).** Audit d'identité quantitatif (grille 10 colonnes
A-J : plancher + plafond de puissance par rang), tranchage de l'**axe du choc** (condensateur → décharge sur le
1er tick DoT, « axe D »), correction de **3 unités rang-5 bloquantes** (`deep_kraken`/`skull_colossus` =
stat-sticks DPS > tous les T3 ; **apex choc = NOUVELLE unité** `type=arcane/abyss`, pas le recyclage DA-invalide
d'un crâne osseux), correction du faux signal `afflictionCount`, et pose du champ **`dot_family`** (prérequis des
types). *Pourquoi :* on ne doit pas amplifier une méta cassée — le diagnostic d'équilibrage existant montre une
hiérarchie **poison > tank > … > choc** et une courbe inversée (the-pit-balance-diagnosis ; GDC 2019 MegaCrit :
« la puissance doit suivre la complexité », 18 M runs/patch). *Transfert :* l'essentiel est **data/doc + sim** ;
seules ~2 réécritures SIM ciblées (choc + `afflictionCount`) + data rang-5 — golden rebaselné **explicitement**
si concerné, jamais en silence.

**M3 — Compléter les RELIQUES en data pure (P1.5a, en parallèle de P0).** Garantir qu'une offre touche
toujours un archétype **shaper-mid** ET un **payoff-late**, déprioriser les reliques F (boutique) vers le
marchand, donner à chaque relique un **rôle temporel** explicite, et **re-tier `carrion_ledger` (3→2)** (sa
valeur est maximale en early). *Pourquoi :* les reliques E sont des **amplificateurs**, pas des créateurs
d'archétype (pas de downside ≠ boss-relics StS qui forcent le theming) — donc une offre qui ne touche pas le
build joué est un round mort (StS, Giovannetti GDC 2018 ; keithburgun.net « pick-1-of-3 »). *Transfert :* 100 %
**data + doc**, sans dépendance → ne pas retarder (sinon les offres restent diluées pendant P0/P0.5).

**M4 — Donner de la profondeur de BUILD via les synergies par TYPE (P1).** Les **5 familles DoT sont les
types** (lues depuis `dot_family`) ; bonus **build-résolus, compteur GLOBAL PUR** (seuils 2/4), un **twist de
palier** par famille (`burnIgnoreShield`, `bleedPierceShield`, choc-4 `tickCount=2`, poison-4 `poisonWeakenDeep`),
via `grant_team` → golden-safe. *Pourquoi :* c'est le seul TODO de profondeur explicitement attendu
(00-state §7 ; TFT traits §7, « transférable et même attendu »), et il enrichit chaque run **avant** d'en
demander 100. *Transfert :* `grant_team`/`teamFlags` déjà câblés. **Préconditions strictes** (sinon on amplifie
le déséquilibre) : `dot_family` posé (M2), poison non structurellement dominant, apex choc existant, **tableau de
saturation `inc` + tableau de saturation des ARÊTES** (la signature) calculés d'abord. **Garde-fou anti-piège :**
PAS de compteur hybride global+adjacence (dead-zone TFT Galaxies) — les auras d'adjacence SONT déjà l'axe positionnel.

**M5 — Le moteur du « grimper » : RANKED v1 LOCAL + Daily + Contrainte de Saison (P2).** L'unité de
compétition est **le RUN** (pas le combat) ; grille de score **sans pénalité** + marques de sub-tier ; **pool
ranked séparé** de l'unranked (intégrité async) ; **moteur pré-run** (récompense potentielle + distance au
prochain tier + Profondeur du Puits) ; **Daily à seed partagé** (leaderboard comparable même à faible population) ;
**Contrainte de Saison** (`teamFlag` seedé) livrée **avec** la S1. *Pourquoi :* zone vierge = **opportunité #1**
du lab ; le manquant n°1 est le signal **pré-run** (les signaux post-run ne lancent pas une session — seganerds
2026 « uncertainty keeps you queuing ») ; sans différenciateur méta, la S2 = reset de score dans une méta
inchangée (PoE 2). Réenchaîner = near-miss **primaire** (Gris Sage 2025) + identité de run **secondaire** + ladder.
*Transfert :* `state.lua` supporte l'injection de seed → ranked local **avant** backend ; le rating est **méta**
(0 invariant SIM). **Anti-pattern signalé :** pas de **DPS estimé pré-combat** ni de **pré-run directif** (réintroduit
le score caché que LocalThunk a refusé) ; le goal-gradient **informe**, ne **dirige** pas.

**M6 — Verrouiller l'INTÉGRITÉ ASYNC du ranked AVANT de coder le ranked (#LL, prérequis P2).** Capturer le
snapshot **dès le 1er achat** (ou round 2), pas seulement à `startCombat`. *Pourquoi :* un run avorté avant
`startCombat` ne génère aucun ghost → le « concède » sélectionne ses bons départs sans alimenter le pool FIFO
local → **faille d'intégrité silencieuse** (Steam Bazaar août 2025 : « kinda HAVE TO concede to win » ; Reynad a
conçu son matchmaking Swiss autour de ce problème). *Transfert :* ~5 lignes **IO** sur `snapstore.save`, exclusion
du jour-0 identique ; neutralise l'avantage du concède **sans pénalité directe** (cohérent avec la grille sans
pénalité). **Menace pilier #1 si ignoré.**

**M7 — La SIGNATURE du jeu, enfin spécifiée : reliques positionnelles + feedback séquentiel + arêtes mesurées.**
4 **reliques sigil-aware** (`axis_pact`/`bloodline`/`ring_hunger`/`horde_pact`, 0 moteur, lisent
`shapes[shape].edges`, snapshotables) ; le high-roll **activé séquentiellement** (80-120 ms/nœud, accélération
Balatro) au lieu d'affiché en bloc ; **tableau de saturation des ARÊTES** (par sigil × famille × slots).
*Pourquoi :* le plateau-graphe 3×3 est **LE** différenciateur (CLAUDE.md §2), mais aucune des 21 reliques ne
l'exploite et la saturation positionnelle n'a jamais été mesurée en 10 rounds ; Balatro produit le high-roll par
**activation séquentielle visible** (30 ms/Joker = attribution causale), pas par la magnitude (Blake Crosley ;
CHI 2025 Kao n=1699 ; Kritz & Gaina 2025 : saturation positionnelle > saturation de type). *Transfert :* reliques
+ saturation = **data/doc** ; séquentiel = **RENDER** sur le bus existant. Récompenser un sigil **sans le changer**
(égalisateur) ≠ reliques G (qui modifient la topologie, P4).

**M8 — La MÉTA-PROGRESSION comme hook de rétention : Grimoire calibré + cadence de saison juste.** **Grimoire
minimal dès le 1er run** (Chapitre I : reliques + silhouettes), **Chapitre II segmenté par famille** (le joueur
mono-famille passe le seuil 40 % en 2-3 runs, pas 5-7), couche de **maîtrise** par famille (badge sur **victoire
avec l'apex joué**, pas découverte) ; **saisons S1-S2 à 5 semaines** (pas 3). *Pourquoi :* la méta-progression
légère met du temps à « devenir claire » → le hook doit arriver dans la fenêtre critique runs 1-5 (Åslund 2026) ;
collection < 40 % = « bruit de fond » (Yu-Kai Chou CD4) ; 3 sem. = 6-9 runs = une session, pas une saison (Milkman
2014 démontée : landmark naturel ≠ reset arbitraire ; le pool FIFO 200 local a besoin de temps pour se régénérer).
*Transfert :* `grimoire.lua` déjà câblé ; tout est **RENDER + doc**. **Garde-fou :** pas de Grimoire adaptatif (détruit le
mystère) ni de win-rate live (< 30 runs = bruit).

> **Ordre de bataille (5 chantiers dominants).** **P0** (lisibilité/feedback/high-roll/attribution) →
> **P0.5** (audit contenu + axe choc + rang-5 + `dot_family`) en parallèle → **P1.5a** (reliques data, en
> parallèle de P0) → **P1** (types) → **P2** (ranked + Daily + Contrainte de Saison, avec #LL d'abord). Puis
> **P1.5b** (post-choc : swarm scalante, shield, reliques positionnelles), **P1.5c** (F→marchand), **P3**
> (équilibrage auto-itéré + recourbe XP), **P4** (reliques G/sigils + saisons longues), **v1.0** (backend +
> Daily mondial). Calendrier détaillé en **§7**.

> **Menaces aux piliers — à surveiller en permanence (détail §8).** Toute idée de RNG en combat, de PvP live,
> de score chiffré pré-combat, d'asset dessiné, de héros nommé, de grille 2D Backpack, d'intérêt/banque d'or, de
> monétisation P2W, ou d'anomalie globale aléatoire par lobby **casse un pilier** et est rejetée. Le mouvement M6
> (capture snapshot) est le seul risque pilier-async **résiduel et résolu** par la roadmap.

---

## 1. CHANTIER P0 — Lisibilité, feedback, high-roll, attribution, appartenance (jalon v0.9)

> **Pourquoi en premier.** Multiplicateur de fun à coût faible (RENDER ~0,5-1 j/item), et **condition**
> de l'attributabilité dont dépendent le ranked (M5) et la rétention (M8). Convergence de 6 lentilles +
> teardowns (Backpack §4.4, StS §1.4, Balatro §8.2, Artifact postmortem, Snap §7).
> **Tout est RENDER, lu du bus JSONL** (`source/cause/tick` déjà présents) — **0 SIM, 0 invariant**.

| # | Item | Priorité | Quoi (chiffres [PH]) | Source / transfert |
|---|------|----------|----------------------|--------------------|
| 1.1 | **Surlignage des arêtes d'adjacence actives** en build | 1 | au survol/sélection, les arêtes du sigil actif s'allument (qui buffe qui) | la forme EST le graphe (CLAUDE.md §2) ; tue le besoin de « score estimé » |
| 1.2 | **Carte de risque visuelle** (exposition front/back + arêtes) | 1 | `depth = maxCol − cell.x` rendu en couleur ; colonne avant = « exposée » | combat-model-decision §4-6 ; convertit la frustration RNG en skill de placement |
| 1.3 | **Écran post-combat « pourquoi »** | 1 | qui a tué qui, quelle famille a dominé, exposition fatale ; **near-miss = hypothèse testable** (« [unité] a cédé au round N — famille [X] — essaie [unité anti-X] ») + **hint opt-in** (off par défaut) | retention §2.4 ; Grid Sage 2025 (feedback actionnable = mastery) ; **ne JAMAIS prescrire une unité absente du pool** |
| 1.4 | **Moment du Run** (high-roll nommé) — **activation SÉQUENTIELLE** | 1 | la plus longue chaîne du bus, affichée nœud par nœud (80-120 ms, accélération Balatro), ancrée à l'**unité-source + placement** ; seuil mesuré en **P75 sur seeds variées** (pas les 250 fixes) | retention §2.1 ; Blake Crosley + CHI 2025 (n=1699) ; M7 |
| 1.5 | **Nom de Build** (identité de run nommée) | 1 | mode statistique « TU ES PRINCIPALEMENT UN BRÛLEUR [4/10] » ; **seuil progressif** ≥2 early / ≥3 mid / ≥4 late (fallback « ARPENTEUR » à 3 slots) ; **Daily exclu** | dev.to/yurukusa 2026 (« names = identity ») ; précède le Moment du Run |
| 1.6 | **Barre XP de boutique** visible intra-round | 1 (co) | progression vers le prochain tier + « +1 XP (N rounds ou M achats) » ; passive **framée comme un DON grimdark** | progression §2.3 ; Endowed Progress Effect (Nunes & Drèze 2006) |
| 1.7 | **Signal de slot-unlock avec HORIZON DE RUN** | 1 | « un slot = {rounds_remaining_est} combats — ou {3 or} maintenant » (`rounds_remaining_est = (WIN_TARGET − wins) + lives − 1`) | progression §2.2 ; valeur marginale ≠ potentiel total |
| 1.8 | **VRR de boutique** (« le Puits résiste à ta faiblesse ») | 1 | la boutique « se débloque » par paliers visibles → moteur du *one-more-run* ; cible ~30 % des rerolls ; jamais au 1er shop du round ; enveloppe ≤ ~50-60 events pondérés/run | retention §2.3 ; Switchblade 2026 (imprévisibilité boutique = rétention #1 autobattler) ; Hopson |
| 1.9 | **Signal de RELIEF « contre la mort »** (`[unité] a tenu — TA synergie l'a maintenue en vie`) | 1 | post-victoire, unité singulière survivante ; **attribution à l'agence du joueur** (pas au Puits) ; **bloqué tant que CONFIG-SURVIVAL non calibré** (seuil PV par rôle) ; **gate `ghost_is_human`** (décision user) | retention §2.1 (5 VRR positifs = même circuit → manque le contraste hédonique, SDT Dark Souls) ; arXiv 2603.26677 |
| 1.10 | **« Spectre affronté »** (trace d'impact, session initiation) | 1 | au lancement : « tu as croisé l'ombre de N descentes » ; **anonymat grimdark** (pas de noms de joueurs) ; **#Z = IA formulée distinctement** (gate) | retention §2.1 (trace > connexion sociale, SDT-relatedness non prouvée, Ballou 2024) |
| 1.11 | **« Surprise de placement »** (arête révélée post-défaite) | 2 | signal après un drag intentionnel ayant changé une arête (gate `player_move`) ; cap ~10/run | retention §2.4 |
| 1.12 | **Tooltip de cotes de boutique + compteur de copies** | 2 | montre la distribution par tier + « 2/3 » vers la fusion | progression §2.4 |
| 1.13 | **Audit « ≤ 12 mots »** des textes reliques/effets | 3 | lisibilité (nom + effet chiffré + flavor court) | reliques lisibles (relics-design §1) |

> **Validation avant codage :** vérifier la **distribution des 3 signaux VRR** (Moment du Run / VRR boutique /
> relief) pour éviter la sur-saturation. Priorité d'affichage si collision : **Moment du Run (chaîne ≥3) >
> relief > post-mortem diagnostic**.

---

## 2. CHANTIER P0.5 — Audit d'identité du contenu + axe choc + rang-5 + `dot_family` (jalon v0.9.5)

> **Pourquoi tôt, en parallèle de P0.** Convergence de 3 lentilles : on dé-risque le **contenu** avant les
> systèmes qui en dépendent (types P1, ranked P2). **Data/doc + sim**, sauf ~2 réécritures SIM ciblées (choc +
> `afflictionCount`) + data rang-5. **Rebaseline golden uniquement si VOULU + explicite.**

**2.1 — Audit d'identité quantitatif (grille 10 colonnes A-J).** Pour chaque unité : rôle, DPS de frappe,
DPS de DoT, `grant_team`, plancher ET plafond de puissance par rang, dispersion `P90/P10 ≤ 3×`, compatibilité
sigil (auras r3/4), niches orthogonales (bleed=ralentit vs rot=ampute → c'est de l'**i18n**, pas du moteur).
*Pourquoi :* « si un choix est évidemment le meilleur, les designers ont échoué » (cloudfallstudios.com/sts).
**Collisions code-vérifiées à trancher :** `corruptor`/`bile_spitter` rang-3 (op identique, `weaken 0,06 < 0,10`
= dead pick) ; `rust_sentinel` rang-4 = `stormcaller` rang-2 (op identique → viole la décision `cost=rank`) ;
`byakhee` rang-4 DPS 0,160 > `vein_splitter` rang-2 0,091 (inversion cross-rank 1,76×) ; **désert rang-3 burn**
(1 seul poseur actif — ne PAS compter les auras dans le plancher « ≥2 poseurs/rang-3 »).

**2.2 — Rang-5 = BLOQUANT (pas différable).** `deep_kraken` (DPS 0,154) et `skull_colossus` (0,131) sont des
stat-sticks `on_hit` purs dont le DPS dépasse **tous les T3 transforms** (+34 %) → en async, un mur sans
counter-play. Audit à **3 colonnes** (DPS_frappe / DoT_dps / grant_team) : `skull_colossus` = tank-burn opaque
(frappe haute, burn_dps=4 **sous le rang-1** `ash_moth`=7) → **reste burn**, `burn_dps 4→8` (« mur qui brûle
fort »). `deep_kraken` = confond carry/transform → AoE-colonne + `grant_team` OU croisé poison-rot.
**Apex choc = NOUVELLE unité** `type=arcane/abyss` (~15 lignes data) — **pas** le recyclage de `skull_colossus`
(`type="bone", family="crane"` + électricité = DA-invalide, décision #3 ; le « 0 moteur » du recyclage est une
analogie mécanique paresseuse). *Source :* `units.lua:421-424,437-439` (code-vérifié) ; GDC 2019 MegaCrit.

**2.3 — Axe du CHOC = AXE D (condensateur).** Le choc passe par `tickDots` (axe D : décharge/ampli sur le 1er
tick DoT), **pas** `hit()` (axe C infaisable : `dischargeShock` après `damage` → réordonnerait `hit()`, viole
invariants #22-32). L'ampli cible la **`dot_family` du POSEUR** (fallback ordre fixe) — sinon il amplifie burn,
la famille absorbée par les boucliers ≠ celle du build = trahison de promesse. Jaugé en **`burst_DPS_eq`** (pas
`dmg/cd`, qui fait apparaître `galvanizer` faussement « OVER »). **Signal UI famille amplifiée obligatoire.**
Sim **4 configs** ; `discharge_effective_ratio < 0,40` en config sans-DoT → **Option A** (1 rang-3 choc qui
auto-pose un DoT léger avant de charger = fiabilité dépend du **build**, pas de l'adversaire — PoE Lightning
Exposure). *Note : la hiérarchie choc < poison est un problème de **fiabilité**, pas de puissance.*

**2.4 — `dot_family` + lint (prérequis P1).** Poser le champ `dot_family` (porteur déclaratif de la famille,
1 par unité) + règle multi-effets + lint dans `tools/check.sh`. *Pourquoi :* les types (P1) et le Grimoire
segmenté (M8) le lisent ; aujourd'hui il est **déduit dynamiquement** (`toComp` ne crash pas, mais le champ
explicite est requis pour les seuils 2/4).

**2.5 — Corriger `afflictionCount` (faux signal `plague_communion`).** Aujourd'hui il compte la **présence**
→ `wither_bloom` déclenche `plague_communion` à lui seul (`arena.lua:248-252`, code-vérifié). Option C2 (compter
les afflictions réelles). *Lié :* `plague_communion` re-tranché → s'ancre sur **`dot_family_count(BUILD JOUEUR)
≥ 2`**, pas sur la cible (alignement payoff↔agence #JJ ; en async l'ancrage-cible est non-reproductible). Magnitude
= **sim bloquante** (le seul `more` hors-cap ; borner le combo `festering`/`poisonNoCap`).

**2.6 — Sims structurelles AVANT P1 (ordre strict).** `--pool-repr` **AVANT** `--poison-frac` (retirer
`corruptor` change la représentation rang-3 poison → simuler avant la cohorte mesure un pool à corriger) ;
`--poison-frac` + `--no-weaken` mesurent les **DEUX causes** de poison>choc (propagation ET weaken) ;
`--position-variance` calibre les auras d'adjacence ; **tableau de saturation des ARÊTES** (M7) ;
`offer_decision_quality` (densité de décisions réelles de l'offre 1-parmi-3, segmentée par tier) ;
`combat_effect_legibility` (avg/max events/tick, batching si > 4 — une profondeur invisible n'existe pas).

---

## 3. CHANTIER P1.5a — Complétude des reliques, data pure (jalon v0.9.3, en parallèle de P0/P0.5)

> **Pourquoi en parallèle.** 100 % **data + doc**, **sans dépendance** → les retarder dilue les offres
> pendant P0-P0.5. Les reliques E **amplifient** un archétype, ne le créent pas (StS boss-relics forcent le
> theming, pas les nôtres → P1/types = prérequis de fun). Source : relics-design.md ; Giovannetti GDC 2018.

| # | Item | Quoi (chiffres [PH]) |
|---|------|----------------------|
| 3.1 | **Garantie de pertinence d'offre** sur B-E | au moins une relique de l'offre 1-parmi-3 touche un archétype présent dans le build ; **renforcée en early** (≥89 % des offres early contiennent une A triviale → garantir une **décision réelle**) |
| 3.2 | **Règle reliques/archétype** | ≥1 **shaper-mid** (tier ≤3) ET ≥1 **payoff-late** (tier 4) par archétype actif |
| 3.3 | **Rôle temporel** actionnable | colonne shaper/payoff sur chaque relique ; signaler les mismatchs fenêtre/rôle |
| 3.4 | **`carrion_ledger` tier 3 → 2** | sa valeur (+6 XP) est **maximale en early** (bypasse un palier XP) → tier-3 anti-optimal (`relics.lua:64-66`) ; mobalytics StS2 « Act 1 relics function IMMEDIATELY » |
| 3.5 | **`plague_communion`** ancrage compo joueur | `dot_family_count(joueur) ≥ 2`, +25 % flat (PAS un gate ; #JJ) ; magnitude = sim P0.5 |
| 3.6 | **`feeding_frenzy`** = correcte (ne PAS refondre) | `frenzy_gain` existe (`ops.lua:208-217`) ; récompense déjà les kills ennemis = **amplificateur** (pas égalisateur) → cibler la garantie aux builds aggro ≥20 |
| 3.7 | **`famines_math`** = option (a) + tri STABLE | « tes 3 unités les plus COÛTEUSES +30 % dmg / +20 % HP » ; **clé de tri secondaire `id`** (sinon `table.sort` Lua non-stable → viole l'invariant de déterminisme #2) ; spec `R.apply` + test |
| 3.8 | **`second_breath`** reste universelle tier-3 | NE PAS conditionner |
| 3.9 | **Déprioriser les reliques F** | vers le marchand (P1.5c) ; documenter les 3 archétypes éco avant |
| 3.10 | **`hollow_choir`** RÉORIENTÉE (décidé) | retirée de `U.pool` maintenant (counter-regen inexistant, 1 unité) ; **réorientée `pierceShield` en P1.5b** (PAS retirée par inertie) |
| 3.11 | **`sacred_shield`** [PH] | `invulnT=30` ≈ 0,5 s = quasi-inerte (combats `HP_MULT=2`) → régler (candidat : 120 ticks + shield) |
| 3.12 | **Grimoire MINIMAL** (Chapitre I, // P0.5) | reliques découvertes/vues + silhouettes des 21 ; hook méta dès le 1er run (Åslund 2026) ; ~2 h RENDER |

---

## 4. CHANTIER P1 — Synergies par TYPE (jalon v0.10)

> **Pourquoi.** Seul TODO de profondeur explicitement attendu (00-state §7) ; enrichit chaque run avant d'en
> demander 100. **Conditionné par P0.5** (`dot_family` posé + poison non dominant + apex choc existant +
> saturation `inc` ET arêtes calculées). Mécanisme = `grant_team` build-résolu, **golden-safe**.
> Transfert : TFT traits §7 « transférable et même attendu ».

**4.1 — Les types SONT les 5 familles DoT**, lues depuis `dot_family`. **Compteur GLOBAL PUR** (seuils 2/4),
**pas hybride** global+adjacence : dead-zone TFT Galaxies (double condition), et les auras d'adjacence sont
**déjà** l'axe positionnel du type (`--position-variance` mesure le win-rate, pas la frustration ; #D clos).
Source : TFT Galaxies/Inkborn learnings (« big vertical traits must have primary stars » → confirme global pur).

**4.2 — Un twist de palier par famille** = **1 règle `more` bornée**, ≠ sous-cas d'un T3, ≠ vide-T2 :
- **burn-4 = `burnIgnoreShield`** (burn-vuln-bouclier intentionnel, rock-paper-scissors mesurable ; #W clos).
- **bleed-4 = `bleedPierceShield`** (drain progressif 1 pt/tick = identité « bleed ronge » ; burst = **repli**
  seulement si la sim prouve l'inertie face à `ward_weaver` scalant) + signal UI palier-2→4.
- **choc-4 = `tickCount=2`** (les 2 premiers ticks DoT de la famille du poseur sont amplifiés ; cause = compo
  du build, FORTE #JJ ; compatible avec les 2 axes d'apex → **découple #GG** ; #HH clos).
- **poison-4 = `poisonWeakenDeep`** [SPEC À PROUVER] (le weaken s'applique aux passives adverses à coef réduit
  0,30 ; garde-fou : pas sur les teamFlags de TYPE adverses).

**4.3 — Préconditions de gravure (sinon on dépasse la saturation).** Tableau de saturation `inc` par famille
+ **tableau de saturation des ARÊTES** (par sigil × famille × slots ∈ {3,5,7,9} ; alarme < 0,3 à 7 slots →
incompatibilité positionnelle, ex. bleed+ligne — ne PAS prescrire l'aura de cette famille sur ce sigil en P1) ;
test inter-famille 2a/2b avec `shield_caster` actif ; baseline `offer_decision_quality` post-correction.

**4.4 — Profondeur inter-familles (SPEC À PROUVER, P1.5b — pas gravé en P1).** **#FF** : aggravation croisée +
contagion au kill (la **diversification** mécaniquement récompensée, en **Option B symétrique** — les 2 familles
co-présentes du build s'amplifient, condition FORTE #JJ ; rebaseline golden = garde-fou). **`resonance_stone`** :
relique B scalante `+5 % affliction_inc / unité même famille` (la **cohérence** mono-famille ; coût
d'irréversibilité positif à la Balatro). Les deux **entrent dans le tableau de saturation** avant gravure (un
`more` croisé/scalant peut dépasser le cap ×3). *Garde-fou :* `DOT_CAP_MULT=3` borne l'output (#FF-safe).

---

## 5. CHANTIER P2 — Ranked v1 LOCAL + Daily + Contrainte de Saison (jalon v0.11)

> **Pourquoi.** Le moteur du « réenchaîner pour grimper » — zone vierge, opportunité #1. Ranked **local
> avant backend** (`state.lua` injecte déjà le seed ; rating = méta, 0 invariant SIM). **#LL d'abord** (M6).
> Réenchaîner = near-miss **primaire** + identité **secondaire** + ladder (Grid Sage 2025 ; Polygon 2025).

**5.1 — L'unité de compétition est le RUN** (5e confirmation, accord fort). Pas le combat individuel.

**5.2 — Grille de score SANS pénalité + marques de sub-tier.** `+4/+2/+1/0` par run, ~35 pts/tier [PH],
marques au p25 (écrémage explicite). *Pourquoi :* perte injuste amplifie le churn des tiers bas (Activision 2024
SBMM ; CoD matchmaking). **Pas de score intra-run** (StS Ascension l'a abandonné). **Bazaar pré-Legend = sans
pénalité** = notre direction (la perte de points Bazaar depuis 2025 est légitimée par un backend mondial qu'on
n'a pas).

**5.3 — Intégrité async (prérequis bloquants, AVANT le code ranked).**
- **#LL — ancre de snapshot** : capturer dès `shopBuys ≥ 1` OU round 2 (exclusion jour-0 identique) — M6.
- **Pool ranked SÉPARÉ** de l'unranked (champ `mode`) + `RANKED_MIN_POOL` (SOFT=3 / HARD=5 progressif).
- **IA cold-start ranked = 1 build par famille** (6 Encounters) : sinon le pool FIFO biaise vers les familles à
  haut win-rate → le joueur choc ne voit jamais de ghost choc → abandonne.
- **Matchmaking** `(bucket, wins_at_capture, slot_tier_composite)` + fallback descendant ; `slot_tier_composite`
  documenté comme **proxy** uni-dimensionnel (pas une mesure de skill — Cinder over-engineering pour 200 snapshots).
- **Filtre de persistance ghost** : `wins_at_capture ≥ 3 AND slot_tier_composite ≥ MIN_COMPOSITE` (≥6 [PH]) +
  fallback si pool < SOFT.

**5.4 — Moteur PRÉ-RUN** (le manquant n°1). Récompense potentielle + **distance au prochain tier** (sub-tier) +
**Profondeur du Puits** (#KK : round max atteint, axe orthogonal au LP ; **prérequis : vérifier l'escalade IA
dans `encounters.lua`** — sinon mesure un plafond d'éco, pas de skill) + élan 3 runs + signal de pool 🟢🟡🔴.
*Pourquoi :* « uncertainty keeps you queuing » (seganerds 2026) ; Management Science 2026 (+4-6 % via 2 dimensions
d'historique, Lichess 5,4 M parties). **Anti-pattern :** pas de **DPS estimé pré-combat** ni de pré-run **directif**.

**5.5 — Daily = Contrainte du Jour, SEED PARTAGÉ.** `hash(date + contrainte)` → adversaires partagés →
leaderboard comparable **même à 10 joueurs** ; 10+ contraintes compositionnelles (famille × sigil × éco) + filet
pédagogique ; score brut `wins × (10 − lives)`. **Scope = combat seul** (shop libre, variance de build préservée).
**Unranked** (le pool dédié évite le biais de famille dominante). Source : StS Daily ; SAP v0.47 daily ; #BB clos.

**5.6 — Contrainte de Saison** (`grant_team` câblé = 0 moteur, **livrée avec la S1**, pas en P4). 4 `teamFlags`
saisonniers ; cible « **axe RÉSOLU** + plus grand écart [potentiel théorique] − [win-rate réel] » (PAS « bas
win-rate ») ; **prérequis : choc gelé tant que #GG ouvert, burn gelé tant que désert rang-3 non résolu** ;
fallback = modificateur de **sigil pur** (`lineSlow2x`) ; **pré-annonce 24-48 h** (Fresh Start exige l'incertitude
partagée). *Pourquoi :* sans différenciateur méta, la S2 = reset de score dans une méta inchangée (PoE 2).

**5.7 — Cadence de saison.** **S1-S2 = 5 semaines** (pas 3) ; P3+ = 6-8 ; P4+ = 8-10. Garde-fou bas **jamais
< 4 sem.**, haut jamais > 10 sans contenu. *Pourquoi :* 2-3 runs/sem × 5 = 10-15 runs = 1 tier + régénération du
pool FIFO local (Milkman 2014 = garde-fou bas seulement ; GamineAI 2026 : 6-12 sem.). **FIFO de saison** =
persistance filtrée (double critère 5.3) + grâce 7 j. **Reset partiel** −20 % (pas Bronze) ; `< 3 runs/saison`
→ reset à 0 + message clair. **Cosmétique daté** de fin de saison (urgence émotionnelle, log Grimoire + message menu).

**5.8 — Grimoire 3 chapitres COMPLET + maîtrise.** Chap. I (reliques+silhouettes, déjà en v0.9.3), II (unités
**segmenté par famille**, seuil 40 % en 2-3 runs), III (sigils, silhouette Ovsiankina) ; badges
INITIÉ/PRATICIEN/**MAÎTRE** par famille (MAÎTRE = **victoire avec l'apex joué**, pas découverte — SDT-compétence,
fausse maîtrise = churn). Sections non jouées = compteur discret (pas de FOMO inter-familles).

**5.9 — Dernier Souffle** : à 1 vie, relique tier-4 seedée gratuite (#A2 tranché). **5.10 — Score de saison
personnel visible** (`season_wins`, persiste inter-saisons, explicite).

---

## 6. CHANTIERS suivants (post-P2)

**6.1 — P1.5b (post-choc, jalon v0.10.5)** : `swarm_logic` scalante + `shock_conduit` (shaper-mid choc) + 1
relique rot tier-4 (placement-indépendante) + shield pur + **4 reliques POSITIONNELLES** (M7 :
`axis_pact`/`bloodline`/`ring_hunger`/`horde_pact`, 0 moteur, lisent `shapes[shape].edges`, n'imposent aucun
sigil = égalisateurs) + `venom_covenant` (granularité intra-famille poison, après sim) + `hollow_choir →
pierceShield` (décidé) + (option) `apply_status` + (option) reconception `wither_bloom`. *Garde-fou saturation :*
vérifier que `anneau + resonance_stone + ring_hunger` ne dépasse pas le cap ×3 avant de graver dans la même vague.

**6.2 — P1.5c (post-marchand, jalon v0.11.5)** : reliques F (`runOp`) → marchand /3 combats (invariant #20 préservé).

**6.3 — P3 (équilibrage auto-itéré, jalon v0.12, continu)** :
- **Précondition : tableau d'intention des constantes éco** (statique/scalant/soft-cap) AVANT toute sim
  (Machinations 2025 « define the goal before measuring ») ; **table du plafond naturel de la passive** (prédit
  `--xp-climax` sans le lancer : `{2,5,10,18}` → T5 passif à R19 ; `{2,5,10,20}` → T5 toujours actif).
- **Recourbe XP robuste à la variance** (10-19 rd) **+ streaks dans le budget réel + co-calibration shopTier/slots**
  (4e condition, hiérarchie de remèdes R1 communication > R2 data > R3 exclusion, ordre strict).
- **`REROLL_COST` tranché par sim** T1-vs-T3 (l'analogie SAP est corrigée : prix uniformes 1:3 constant ≠ notre
  `cost=rank` qui dérive 1:1→1:5 ; documenter l'**intention** §7.0, ne pas trancher par décret) ; `P(doublon T1)
  ≈ 62 %` justifie partiellement garder = 1.
- **Cotes par rareté/unité** + **pity = SIGNAL sans garantie** (seuil `max(3, 0,5×médiane)` + progression
  visuelle implicite, jamais « garanti dans N » qui neutralise le VRR).
- **Raffinement du roster** (niche vs retrait pool, lié à P0.5) ; **reliques — passe « 1 règle modifiée »**.
- **`--meta-convergence`** (sur runs **unranked libres uniquement**, exclure ranked teamFlag + Daily contrainte).

**6.4 — P4 (reliques G + saisons longues, jalon v0.13)** : reliques **G = topologie via relique** (modifient le
sigil — le plus signature ET le plus cher ; sous-ensemble minimal 1-2 formes + **tests d'exposition AVANT le code**) ;
saisons 5-10 sem. échelonnées par contenu ; rotation de pool. *Prototyper 1 forme PENDANT P3 si le plafond de
connaissance se déclenche (`season_wins ≥ 50 ET Grimoire ≥ 25`).*

**6.5 — v1.0 (backend + Daily mondial)** : backend distant + Daily mondial + effets aura/relique dans le snapshot
(v1 = effets de base) + `snapshot_schema_version` au 1er champ persisté (ou si #Y choisit le vidage complet du FIFO).

**Hors-scope explicite (différés sains)** : passifs de ligne (façade/arrière), contres de taunt
(AoE-colonne/strip/furtivité), 6e famille « Ordre » (gen créatures), monétisation. Le **6e type non-DoT** est
orienté « aucun » (la dispersion DPS tank = audit budget, pas un type).

---

## 7. Calendrier macro (solo dev, jalons `vX.Y`)

> Branches `<type>/<slug>` depuis `dev` ; commit quand `tools/check.sh` est vert (CLAUDE §8). Chaque jalon =
> vert sur les 32 invariants (ou test modifié **explicitement avant**). Coûts = ordre de grandeur solo dev.

| Jalon | Chantier | Contenu clé | Coût | Dépend de | Invariants |
|-------|----------|-------------|------|-----------|------------|
| **v0.9** | P0 | Lisibilité + carte risque + post-combat + Moment du Run (séquentiel, source+placement, P75) + Nom de Build + barre XP + VRR boutique + relief « contre la mort » + spectre affronté | Faible | aucune | +tests RENDER (golden chaîne/source/adjacence, nom de build, VRR, no-crash MAX_TIER) |
| **v0.9.3** | P1.5a | Reliques data (garantie B-E + rôle temporel + `carrion_ledger` 3→2 + `plague_communion` compo + `famines_math` tri stable + déprio F) + **Grimoire minimal** | ~Nul (+2 h) | aucune | adapter #3/#21, +#18-21, +test Grimoire no-crash |
| **v0.9.5** | P0.5 | Audit 10-col A-J + rang-5 BLOQUANT (skull reste burn / apex choc = nouvelle unité) + `dot_family`+lint + **choc AXE D** + `afflictionCount` (C2) + sims structurelles + tableau saturation arêtes | ~Nul (+choc+data) | // P0 | choc + C2 + rang-5 = **rebaseline golden si concerné** ; lint check.sh |
| **v0.10** | P1 | Types (`dot_family`, GLOBAL PUR, twists par famille) — précédé des 2 tableaux de saturation + tests inter-famille | Moyen | P0.5 | +tests type ×2 paliers, cap ×3, −2 invariants vs hybride |
| **v0.10.5** | P1.5b | swarm scalante + shock_conduit + relique rot t4 + shield + **4 reliques positionnelles** + `venom_covenant` + `hollow_choir→pierceShield` (+ #FF/`resonance_stone` si saturation OK) | Faible-Moyen | P0.5 (axe D + arêtes) | reliques gated → golden inchangé ; +test lecture shape |
| **v0.11** | P2 | Ranked local + **#LL ancre snapshot** + pool séparé + RANKED_MIN_POOL + pré-run sub-tier + Profondeur du Puits + Daily seed partagé + Grimoire 3-chap + Contrainte de Saison + Dernier Souffle | Moyen-Élevé | P0 + P0.5 + Grimoire min. | +snapshot (mode/season_id) ; rating=méta (0 invariant SIM) ; +tests #LL/serve/FIFO/daily/#Z |
| **v0.11.5** | P1.5c | F → marchand | Faible | marchand /3 | #20 préservé |
| **v0.12** | P3 | Tableau d'intention éco + recourbe XP robuste + `REROLL_COST` tranché + cotes rareté + pity-signal + meta-convergence | Continu | P1+P1.5+P2 | adapter tests cotes ; rebase golden si `REROLL_COST` change |
| **v0.13** | P4 | Reliques G (sigils) + saisons 5-10 sem. | Élevé | ranked+types | +tests exposition sigils |
| **v1.0** | P4 | Backend + Daily mondial + effets dans snapshot + `sv` | Élevé | tout | étendre encodage snapshot |

---

## 8. Menaces aux piliers + analogies paresseuses DÉJÀ démontées (ne pas re-proposer)

> Source consolidée : `ROADMAP-draft.md §10`. Chaque rejet a un **pourquoi mécaniste sourcé** (le simple
> « X fait ça » n'est jamais recevable). **🔴 = casse un pilier** (rejet absolu). Les autres = mauvais transfert.

| Mécanisme tentant | Verdict | Pourquoi (source) |
|---|---|---|
| **PvP temps réel / pool partagé live / carrousel** | **🔴 NON, jamais** | Viole l'async par snapshots (pilier #1) ; solo dev (tft §V1) |
| **Ciblage / RNG en combat** | **🔴 NON, jamais** | Viole le déterminisme seedé (pilier #2) ; ciblage déterministe = avantage (hs-bg §5.3) |
| **Anomalies globales aléatoires par lobby** | **🔴 NON** | Incompatible snapshots déterministes ; alternative = Contrainte de Saison (identique pour tous, seedée) |
| **Boons mid-combat (Hades)** | **🔴 NON** | Combat auto spectateur ; viole le firewall SIM/RENDER (hades §11) |
| **Héros nommés + Hero Powers** | **🔴 NON** | Pas de héros dans la DA procédurale ; sigils+reliques jouent ce rôle (hs-bg §7.3) |
| **Asset dessiné / sprite manuel apex choc** | **🔴 NON** | Pixel art 100 % procédural (pilier #4) ; recyclage DA-incohérent rejeté (skull_colossus, décision #3) |
| **Monétisation multi-points / P2W** | **🔴 NON, jamais** | Signal hostile (Artifact), trahison (SBB) ; cosmétique procédural seul |
| **Capturer le snapshot ranked seulement à `startCombat`** | **🔴 NON (#LL)** | Run avorté = pas de ghost = pool biaisé (« concede meta », Steam Bazaar août 2025) → capturer au 1er achat (M6) |
| Intérêt / banque d'or | NON | Run court → spirale de mort débutants (tft §V3, balatro §9.3) |
| Grille 2D + rotation (Backpack) | NON | Hors-budget LÖVE + « À ÉVITER » (autobattler-design §4) |
| Score Chips×Mult / **DPS estimé pré-combat** | NON | Trompeur en système asymétrique ; LocalThunk cache le score (GMTK 2024) |
| **Pré-run DIRECTIF** (dicte l'éco du run) | NON | Réintroduit le DPS-estimé démonté ; le goal-gradient INFORME, ne DIRIGE pas (progression §2.3) |
| Unités T5 lockées (Balatro) | NON | 12 % du pool gaté ; Grimoire 3-chap = horizon sans lock (Kammonen 2023) |
| Floors anti-churn / MMR caché à la TFT | NON | Double système LP/MMR caché = confusion #1 ; 6-9 runs/saison ne convergent pas ; `slot_tier_composite` suffit |
| Grille de score AVEC pénalité (Bazaar S1) | NON | Bazaar pré-Legend = SANS pénalité → notre direction (steamcommunity 1617400) |
| Rating par sigil/archétype | NON | 5 ratings = ranked inexploitable (#C clos) |
| Mode Endless | NON | 10 victoires = durée contrôlée (atout async) |
| **Compteur de type HYBRIDE** global+adjacence | NON | Dead-zone TFT Galaxies ; les auras sont déjà l'axe positionnel (#D clos) |
| **Réorienter `skull_colossus` en apex choc** | NON (DA-invalide) | `type="bone", family="crane"` + électricité = incohérence thème/mécanique (décision #3) ; le stat-line ne fait pas l'identité |
| **`feeding_frenzy` refondue / `plague_communion` scalante cible** | NON (code correct) | `frenzy_gain` existe déjà ; ancrage cible = hors agence en async (#JJ → compo joueur) |
| **`dmg/cd` uniforme appliqué au CHOC** | NON (wrong metric) | Le choc est un condensateur → mesurer en `burst_DPS_eq` (StS Totem) |
| **VRR négatif prévisible** (régression de stats) | NON | Déterminisme → même build = signal fixe ≠ VRR |
| **High-roll = problème de probabilité** | NON | Balatro le produit par activation SÉQUENTIELLE visible (M7), pas la magnitude (CHI 2025) |
| **Saisons 3 sem. / 6-8 sem. sans contenu** | NON | 3 sem. = session (Milkman démontée) ; sans contenu = timer perçu → 5 sem. S1-S2, échelonnées par contenu |
| **Twist de palier 4 = sous-cas T3 / qui vide un T2** | NON | Duplication (« burn 4 no-decay » = clone d'ash_maw) / « poison 4 = slow » vide chitin_drone |
| **Partage social / streak des noms de build** | NON | Anonymat grimdark ; streak punit l'exploration (pilier roguelite) |
| **Pity-tracker avec garantie explicite** | NON | « garanti dans N » neutralise le VRR ; signal sans chiffre + progression visuelle |

> **GARDE-FOU TRANSVERSAL `#JJ` — alignement payoff↔agence.** Tout payoff de build (relique, badge, signal,
> palier) **doit s'ancrer sur une cause CONTRÔLÉE PAR LE JOUEUR** — composition (`dot_family_count`, copies,
> aggro), placement (adjacence via sigil), ou décision (achat/level) — **JAMAIS** sur la cible (afflictions
> adverses), l'exposition (unité vue en boutique), ou l'adversaire (ghost figé). En async, l'ancrage-adversaire
> est non-reproductible du point de vue de l'agence, **même si la sim est déterministe**. Un payoff mal ancré
> crée de la **fausse maîtrise** (déception attributionnelle = churn). Source : keithburgun.net/pick-1-of-3 ;
> arXiv 2502.07423 ; balatrowiki.org/w/Jokers. **À appliquer à toute nouvelle relique/badge/signal/palier.**

---

## 9. Index des sources

**Internes (repo, lecture seule)** : `00-state.md` (état + 32 invariants), `BRIEF.md`,
`seed/{decisions,mechanics,tests}.md`, `round-0{1..10}.md` (synthèses), `rounds/r0{1..10}-*.md` (60 critiques),
`docs/research/*`. **Code vérifié (rounds 1-10)** : `units.lua` (`dot_family` absent ; ladder choc 10 unités ;
`U.pool` ≠ `U.order` ; `skull_colossus:421-424` `type=bone` burn_dps=4 ; `deep_kraken:437-439` DPS 0,154 ;
`corruptor`/`bile_spitter` rang-3 op identique ; `rust_sentinel` = `stormcaller`) ; `relics.lua` (21 reliques ;
4 B = `relic_affliction_inc:26-29` identiques ; `carrion_ledger:64-66` tier 3 ; `feeding_frenzy → frenzy_gain` ;
`plague_communion:57-58 → plagueAmp=0.25`) ; `arena.lua:248-252` (condition réelle `plague_communion` sur la
CIBLE), `:325-395` (ordre `hit()`), `:432` (burn PAS d'ignoreShield), `:58` (FATIGUE_START=1020) ; `ops.lua:22`
(`DOT_CAP_MULT=3`), `:187` (`shockChain` consommé), `:208-217` (`frenzy_gain`) ; `state.lua` (`GOLD_PER_ROUND=10`,
`XP_TO_LEVEL={2,5,8,12}` [PH]) ; `shapes.lua` (5 sigils, arêtes) ; `snapstore.lua:save` (#LL).

**Concurrence (teardowns)** : `competitive/{super-auto-pets, tft, balatro, slay-the-spire, hs-battlegrounds,
marvel-snap, the-bazaar, backpack-battles, hades, postmortems}.md`. Verdicts clés transférés : SAP (async/run/
duplicatas = déjà fait, supérieur potentiel ; matchmaking par progression) ; TFT (cotes XP = déjà notre modèle ;
traits = types transférables et **attendus** ; interest/scouting = NON transférables) ; Balatro (score Chips×Mult
= NON ; lisibilité d'effet + *juice* séquentiel = OUI ; Stakes → tiers ranked) ; Bazaar (concede meta = faille
#LL ; reset soft sans pénalité = OUI ; manipulation de cooldown = NON, ciblage déterministe) ; StS (reliques
contextuelles = lock-in ; Daily seedé ; score classé abandonné) ; Hades (boons mid-combat = NON, firewall) ;
postmortems (Underlords −97 % : déclin par rotation absente → Contrainte de Saison ; SBB : monétisation P2W = mort).

**Sources web majeures (sélection, rounds 1-10)** : keithburgun.net/pick-1-of-3 (offre 1-parmi-3) ;
balatrowiki.org/w/Jokers + blakecrosley.com/balatro (high-roll séquentiel / conditions sous contrôle) ;
CHI 2025 Kao n=1699 (amplification sans success-dependency) ; gmtk.substack.com (LocalThunk cache le score) ;
Nunes & Drèze 2006 JCR (Endowed Progress Effect) ; yukaichou.com/collection-set-design-cd4 (seuil 40 %) ;
his.diva-portal.org Åslund 2026 (méta-progression légère) ; Milkman 2014 + GamineAI 2026 (cadence saison) ;
Kritz & Gaina 2025 arxiv 2502.10304 (saturation positionnelle) ; poewiki.net/wiki/{Shock,Ailment,Ignite,Poison,
Bleeding} (familles DoT) ; steamcommunity.com/app/1617400 + bazaar-builds.net (concede meta, reset soft, ghosts) ;
EurekAlert/Management Science juin 2026 (2 dimensions d'historique +4-6 %) ; arXiv 2603.26677 (Ordeal Pleasure) ;
arXiv 2502.07423 (SDT compétence) ; gridsagegames.com 2025 (near-miss = mastery) ; GDC 2019 MegaCrit
(power=complexity, 18M runs/patch) ; cloudfallstudios.com/sts + Giovannetti GDC 2018 (offre triviale ; boss-relics
forcent le theming) ; TFT Galaxies/Inkborn learnings (traits double-condition = dead-zone) ; Activision 2024 SBMM
(perte injuste = churn) ; lua.org/manual/5.1#5.5 (`table.sort` non-stable → tri stable). Liste exhaustive (avec
URLs round par round) : `ROADMAP-draft.md §13`.

---

*Roadmap finale du roadmap-lab, synthétisée le 2026-06-23 après 10 rounds adversariaux (6 lentilles × round).
Lecture seule du repo ; écriture uniquement sous `docs/roadmap-lab/`. Piliers respectés (async snapshots / sim
déterministe seedée / DA grimdark / pixel art procédural). 32 invariants préservés (toutes les recos sont
data/doc/sim/RENDER/IO/config ou décision éditoriale — 0 modification du code du jeu ni des tests). Litiges
restants : `OPEN-QUESTIONS.md`.*
