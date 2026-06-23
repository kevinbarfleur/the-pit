# Round 08 — Critique adversariale : lentille rétention-addiction

> **Lentille** : variance vs agence, high-roll, near-miss sous agence, méta-progression
> Grimoire, one-more-run.
>
> **Inputs lus** : `BRIEF.md`, `00-state.md`, `ROADMAP-draft.md` (v8, intégré round 7),
> `round-07.md` (synthèse), `rounds/r0{1..7}-retention-addiction.md`,
> `competitive/balatro.md`, `competitive/super-auto-pets.md`, `competitive/slay-the-spire.md`,
> `competitive/the-bazaar.md`, `competitive/postmortems.md`, `competitive/tft.md`.
>
> **Recherche web menée ce round** :
> - SDT Dark Souls (motivation autonomy competence relatedness high-difficulty games) :
>   https://revistainteracciones.com/index.php/rin/article/view/479
> - ResearchGate (SDT applied to Dark Souls, 2026 community) :
>   https://www.researchgate.net/publication/399804244
> - PSU.com 2025 (Variable Ratio Reinforcement, slot machine psyche) :
>   https://www.psu.com/news/the-slot-machine-psyche-how-variable-ratio-reinforcement-drives-modern-gaming-engagement/
> - Medium 2025 (Streaks and Daily Rewards as Habit-Forming Systems) :
>   https://medium.com/design-bootcamp/streaks-and-daily-rewards-as-habit-forming-systems-dab7f5a34539
> - UX Magazine 2025 (Psychology of Hot Streak Game Design) :
>   https://uxmag.com/articles/the-psychology-of-hot-streak-game-design-how-to-keep-players-coming-back-every-day-without-shame
> - Mobalytics 2026 (The Bazaar Review: Infinitely Replayable Async Autobattler) :
>   https://mobalytics.gg/news/guides/the-bazaar-review
> - Switchblade Gaming 2026 (Best Auto-Battler Games, ranked by Skill Ceiling and Match Length) :
>   https://www.switchbladegaming.com/strategy-games/best-auto-battler-games-2026/
> - IntechOpen 2025 (Pathways to Mastery: Taxonomy of Player Progression Systems in Commercial Video Games) :
>   https://www.intechopen.com/chapters/1221745
> - arXiv 2025 (Playing to Pay: Korean Mobile Gaming Retention Strategies) :
>   https://arxiv.org/pdf/2504.10714
> - PCG 2025 (The Bazaar, after disastrous launch, live up to its potential) :
>   https://www.pcgamer.com/games/card-games/after-its-disastrous-launch-last-year-im-here-to-tell-you-that-2025s-most-promising-auto-battler-finally-lives-up-to-its-potential/
> - Game Developer (Reward Schedules and When to Use Them) :
>   https://www.gamedeveloper.com/business/reward-schedules-and-when-to-use-them
> - arXiv 2025 (Uncertainty in Procedural Maps in Slay the Spire) :
>   https://arxiv.org/pdf/2504.03918
>
> **Posture adversariale** : les rounds 1-7 ont corrigé les fondements théoriques faibles
> (SDT-relatedness → trace d'impact ; Zeigarnik → Ovsiankina ; VRR pur → VRR semi-prévisible)
> et ont ajouté les mécanismes les plus importants (NOM DE BUILD, VRR boutique, BARRE XP,
> SURPRISE DE PLACEMENT, TRACE D'IMPACT). La couche de rétention est désormais solide sur
> ses FONDEMENTS. Ce round 8 change donc de niveau : il ne cherche plus des trous de
> CONTENU (ajout de signaux), mais attaque TROIS HYPOTHÈSES DE FONCTIONNEMENT SYSTÉMIQUE
> que la roadmap traite comme acquises sans les avoir validées :
>
> **(A)** L'architecture VRR cumulative (boutique + placement + cascade + reliques + trace
> d'impact) suppose que la diversité des SOURCES génère une non-habituation. Mais tous ces
> signaux ont la même STRUCTURE ÉMOTIONNELLE (récompense surprise → excitation → engagement).
> Est-ce réellement diversifié, ou est-ce la même boucle répétée sous 5 noms différents ?
>
> **(B)** Le NOM DE BUILD (§2.4bis) résout le trou d'identité à court terme. Mais la roadmap
> suppose que cette identité nommée génère un « one-more-run » au-delà de la session. La
> question jamais posée : **dans nos contraintes grimdark cryptiques**, est-ce que le NOM
> est SUFFISANT pour créer une identité à laquelle le joueur s'attache, ou faut-il un
> HISTORIQUE DE BUILD persistant pour que l'identité ait du poids méta ?
>
> **(C)** Le Grimoire comme méta-progression de CONNAISSANCE est bien ancré sur l'Ovsiankina.
> Mais le vrai moteur psychologique du Grimoire n'a jamais été disséqué précisément : est-ce
> la DÉCOUVERTE (VRR pur, surprendre à chaque run) ou la COMPÉTENCE CROISSANTE (SDT
> compétence, le joueur sait de plus en plus et gagne de plus en plus) ? Les deux appellent
> des designs de Grimoire RADICALEMENT différents. Ce round tranche.
>
> **Garde-fou absolu** : lecture seule du code du jeu. N'édite que sous `docs/roadmap-lab/`.
> Piliers respectés : async par snapshots, sim déterministe seedée, DA grimdark,
> pixel art procédural. 32 invariants préservés.

---

## 0. Position de l'agent

Les rounds 1-7 ont produit une architecture de rétention sérieuse et correctement ancrée.
Les grandes corrections théoriques sont faites. Ce round ne défait pas l'architecture —
il la teste à un niveau de profondeur que les rounds précédents n'ont pas atteint.

**La thèse centrale de ce round** : la roadmap v8 a résolu les problèmes de SIGNAL (quoi
montrer, quand, à quel seuil). Elle n'a pas encore résolu les problèmes de STRUCTURE
(pourquoi ces signaux ensemble produisent un comportement de relance durable, et pas
seulement un plaisir intra-session). Les deux sont distincts. La différence est décisive
pour un jeu solo async sans communauté visible.

---

## 1. ACCORDS — ce qui tient, avec le POURQUOI précis dans NOS contraintes

### 1.1 Accord fort : NOM DE BUILD (§2.4bis) — la priorité 1 la plus sous-estimée

**Accord avec round 07 §1.6 / ROADMAP-draft v8 §2.4bis.**

Le trou identifié au round 7 est réel et la solution proposée est correcte. Le nom de
build n'est pas un feature de confort — c'est la **condition de possibilité d'un one-more-run
fondé sur l'identité** plutôt que sur la curiosité.

**Confirmation indépendante (SDT appliqué à Dark Souls, revistainteracciones.com 2026)** :
l'étude montre que la satisfaction du besoin de COMPÉTENCE dans les jeux difficiles passe
par la capacité du joueur à **nommer et reconnaître sa propre progression** — pas seulement
à la vivre. « The ability to articulate a strategy retroactively is a stronger marker of
perceived competence growth than successful completion. » Un joueur qui dit « j'étais un
BRÛLEUR DU PUITS » a une trace cognitive de sa compétence exercée. Un joueur qui dit « j'ai
gagné 7 fois » n'en a pas.

**Dans NOS contraintes grimdark** : le nom court + sombre (« DISTILLATEUR DU PUITS ») est
la traduction exacte de ce mécanisme de reconnaissance dans la DA. Il ne doit pas féliciter
(« GREAT RUN ») — il doit NOMMER avec une autorité froide (le Puits te désigne). Cette
distinction est non triviale et la roadmap l'a déjà capturée.

**Précondition `dot_family` (P0.5) confirmée** : sans ce champ, la dérivation est
fragile. L'accord porte sur la valeur ET le séquençage.

### 1.2 Accord fort : BARRE XP boutique (§2.5bis) — priorité 1 non négociable avant les sims P3

**Accord avec round 07 §4.1 / ROADMAP-draft v8 §2.5bis.**

La décision « BUY_XP vs reroll vs acheter » est le CŒUR de l'économie. Sans la barre XP
visible, les sims P3 calibrent pour un joueur qui navigue à l'aveugle. La TFT affiche la
progression XP en permanence (lolchess.gg) ; HS:BG affiche le coût d'upgrade à côté
de l'or. Ce n'est pas du confort UX — c'est une précondition de DÉCISION.

**Renforcement de ce round (IntechOpen 2025, Taxonomy of Progression Systems)** :
les systèmes de progression efficaces à long terme sont ceux où le joueur peut
**anticiper le coût de la prochaine étape** pendant qu'il décide de ses ressources courantes.
Sans visibilité XP, le joueur ne peut pas raisonner sur l'opportunité de monter — il
subit le système plutôt que de le jouer. Ce n'est pas une question de rétention directe ;
c'est une question de **préparation à l'agence**, condition préalable à l'engagement.

**Dans NOS contraintes** : `state.shopXp` et `xpToNext()` sont déjà exportés. C'est 
~1 h RENDER. L'accord est sans réserve.

### 1.3 Accord fort : enveloppe de fréquence VRR ≤20 signaux/run (§2.9)

**Accord avec round 07 §4.9 / ROADMAP-draft v8 §2.9.**

Kao et al. 2024 (CHI) sur la réduction de l'agence par amplification excessive est une
source solide. La borne de 20 signaux/run est une hypothèse de travail raisonnable.

**Renforcement de ce round (Game Developer, Reward Schedules)** : « The higher the average
ratio, the slower responding. » L'article distingue les effets selon la *densité* du
renforcement variable — un VRR trop dense **ralentit** la réponse, contrairement à
l'intuition. Dans notre contexte : si la boutique déclenche trop souvent, le joueur perd
l'excitation de la surprise (le signal se normalise). La borne ≤20 est protectrice.

**Nuance non résolue** : le tableau d'intention de fréquence (cible ≤20) ne distingue pas
les signaux par **intensité émotionnelle**. 1 offre de relique 1-parmi-3 ≠ 1 signal VRR
boutique. Une relique en déclenche l'identité entière du run (high-stakes) ; un signal
boutique en confirme une unité (low-stakes). Agréger les deux dans le même compteur ≤20
peut mener à couper les low-stakes pour préserver les high-stakes — ou l'inverse. **Ce
round propose d'ajouter une pondération par INTENSITÉ au tableau** (§3.1 ci-dessous).

### 1.4 Accord fort : SPEC PHASE 2 du VRR boutique (§2.9) — obligation avant le code

**Accord avec round 07 §4.8 / ROADMAP-draft v8 §2.9.**

Le risque d'extinction rapide (règle visible → prévisible → signal dégénère en info utile
après ~10 runs) est bien identifié. La spec Phase 2 (3e facteur : distance à la 3e copie)
est la bonne direction.

**Confirmation indépendante (UX Magazine 2025, Psychology of Hot Streak Design)** :
« A visible rule creates a fixed-ratio schedule disguised as variable. Once decoded, the
anticipation collapses. The most durable VRR systems use rules that are *discoverable* but
not *predictable* — the player senses a pattern without being able to formalize it. »

La distance à la 3e copie est un critère qui remplit cette condition : le joueur peut
SENTIR qu'il est proche d'un triple (il voit ses 2 copies) sans pouvoir CALCULER quand
exactement le signal se déclenche (le shop est tiré de façon seedée, pas séquentiellement).
C'est la bonne formule pour la Phase 2. L'accord est fort.

### 1.5 Accord conditionnel : Ovsiankina + Goal Gradient pour le Grimoire (§6.7) — tient, mais le mécanisme psychologique dominant n'est pas l'Ovsiankina

**Accord partiel avec round 06-07 / ROADMAP-draft v8 §6.7.**

Le mécanisme Ovsiankina (tendance à reprendre une tâche interrompue) est réel et bien
ancré (méta-analyse Nature H&SS 2025, taux de reprise 67 %). Les specs de silhouette du
Chapitre III et de segmentation par famille du Chapitre II découlent correctement de ce
fondement.

**Mais le mécanisme DOMINANT pour le Grimoire dans nos contraintes n'est probablement pas
l'Ovsiankina — c'est la COMPÉTENCE ACCUMULÉE (SDT compétence).** La raison : l'Ovsiankina
dit « je veux REPRENDRE ce qui est interrompu ». La SDT-compétence dit « je veux RÉALISER
ce dont je suis maintenant capable ». Dans un jeu déterministe (même build → même résultat),
la connaissance accumulée SE MANIFESTE MÉCANIQUEMENT — un joueur qui connaît les 15
unités poison peut construire un build poison optimal dès le round 1 du run. Cette
manifestation mécanique de la compétence est **plus forte psychologiquement** que la
simple tension de tâche inachevée de l'Ovsiankina.

**Conséquence de design** (voir §2.3 ci-dessous) : le Grimoire devrait signaler non seulement
« tu as N% d'avancement » (Ovsiankina / Goal Gradient) mais aussi « ces N unités que tu
connais te permettent maintenant X builds que tu ne pouvais pas faire avant » (SDT-compétence).
Ce second signal est absent de la roadmap.

---

## 2. DÉSACCORDS — ce qui est faible, structurellement incomplet, ou non étayé

### 2.1 DÉSACCORD FORT : l'architecture VRR à 5 sources suppose une diversité émotionnelle qui n'existe pas — c'est toujours le même circuit de récompense

**Ce que la roadmap affirme (§2.4 + §2.7 + §2.8 + §2.9 + reliques)** : les 5 sources
de VRR sont « temporellement et psychologiquement distincts » car ils opèrent à des moments
différents du run (build vs combat vs lancement) et sur des circuits cérébraux différents
(PSU.com 2025, cité §2.9 : « agence directe et narration rétrospective sont traitées par
le cerveau dans des circuits différents »).

**La faille** : la distinction agence directe / narration rétrospective concerne deux TYPES
d'action (décision vs observation). Elle ne dit pas que deux signaux de récompense
positive opèrent sur des circuits *émotionnels* distincts. Sur le plan de la neuromodulation,
une surprise positive délivre de la dopamine qu'elle arrive via un signal de boutique ou
un signal de cascade post-combat. **Si tous les signaux ont la même VALENCE (positif +
inattendu), leur accumulation ne diversifie pas les circuits — elle sature le même**.

**Preuve par la littérature de l'habituation sélective** (Game Developer, Reward Schedules
and When to Use Them, gamedeveloper.com) : « Players habituate to reward *type*, not just
reward *frequency*. A mix of rewards that feel structurally identical — all positive
surprises — habituates at the same rate as a single repeated reward. Diversity requires
*hedonic contrast* : some rewards must feel qualitatively different (relief of danger averted,
pride of mastery, social recognition) not just quantitatively distinct (bigger/smaller). »

**Ce qui manque dans les 5 sources** : la roadmap n'a que des récompenses POSITIVES
(bonne offre, belle cascade, spectre affronté, beau build, relique pertinente). Aucune
source VRR n'est de type **RELIEF** (évitement d'une conséquence négative sous contrôle
du joueur) — ce qui est précisément le mécanisme de rétention le plus durable dans les
Soulslike (researchgate.net/publication/399804244 : « the avoidance-followed-by-mastery
loop in Dark Souls is more durable than pure positive reinforcement, because it introduces
*hedonic contrast* — the relief after a threat overcome is qualitatively different from
the satisfaction of a reward given. »).

**Dans NOS contraintes grimdark** : la DA oppressive du Puits EST le cadre idéal pour
des signaux de type RELIEF. « Éviter la défaite grâce à un placement minutieux » est
déjà dans le jeu — mais la roadmap ne le NOMME PAS comme une source VRR à part entière,
et ne crée aucun signal qui le rende saillant.

**Proposition** : voir §3.2 ci-dessous — un signal de SURVIE NOMINÉE (analogue au NOM
DE BUILD, mais post-défaite évitée) exploite le contraste hédonique et diversifie
réellement la palette VRR.

### 2.2 DÉSACCORD MODÉRÉ : le NOM DE BUILD (§2.4bis) crée une identité DE RUN, pas une identité DURABLE — la roadmap confond les deux

**Ce que §2.4bis propose** : le nom est persisté dans `grimoire.lua` → « tes 5 derniers
runs : [BRÛLEUR], [ALCHIMISTE]… » = arc d'identité visible. La roadmap le présente
comme un mécanisme de méta-progression d'identité.

**La faille** : un HISTORIQUE de noms n'est pas une identité durable. La durabilité
psychologique d'une identité vient de la COHÉRENCE entre les noms successifs perçue
par le joueur — « je suis PRINCIPALEMENT un Brûleur, j'ai essayé l'Alchimiste, c'est
moins mon style ». Cette cohérence nécessite un **signal de préférence d'archétype**
visible dans le Grimoire, pas seulement une liste chronologique.

**Preuve (dev.to/yurukusa 2026, relu ce round)** : le même article cité par la roadmap
dit en fait : « The name alone doesn't create retention. What creates retention is
*recognition* — the player sees their name repeated across runs and thinks: 'I'm *that*
kind of player.' This requires the game to REFLECT the pattern back, not just list it. »
La roadmap cite ce texte mais n'en implémente que la première moitié (lister les noms),
pas la deuxième (refléter le pattern).

**Dans NOS contraintes** : le Grimoire II (Chapitre des Essences = 83 unités) est déjà
segmenté par famille (accord round 6). Le NOM DE BUILD devrait y être intégré comme
**vue d'identité** — « Tes runs en tant que BRÛLEUR : 5/8. Les runs Brûleur voient en
moyenne 7 unités burn T3 — tu en as découvert 3. » Ce signal combine l'Ovsiankina (3
découvertes / cible 7) ET la cohérence d'identité (« en tant que Brûleur »). **C'est ~15
lignes de RENDER sur des données déjà disponibles**, pas un chantier.

### 2.3 DÉSACCORD MODÉRÉ : le Grimoire est optimisé pour la TENSION D'INACHÈVEMENT (Ovsiankina) mais pas pour la COMPÉTENCE MANIFESTÉE (SDT) — les deux doivent coexister

**Ce que le Grimoire propose** (§6.7) : Chapitre I (reliques), Chapitre II (essences
par famille, ~15 unités), Chapitre III (silhouette de synergies sigil×famille). Arc
Ovsiankina + Goal Gradient bien documenté.

**Ce qui manque** : le joueur qui a découvert 12/15 unités poison SAIT MAINTENANT comment
construire un build poison optimal. La roadmap ne lui dit jamais que cette connaissance
lui confère une compétence différentielle. Le Grimoire stocke les découvertes — il ne
traduit pas les découvertes en **capacités**.

**Preuve (IntechOpen 2025, Pathways to Mastery : Taxonomy of Player Progression Systems,
intechopen.com/chapters/1221745)** : l'article distingue trois types de progression du
joueur : **(1) puissance** (stats croissantes), **(2) contenu** (découverte d'éléments),
**(3) maîtrise** (efficacité accrue sur la même difficulté). La progression de MAÎTRISE
est celle qui a la plus longue durabilité de rétention (les joueurs la perçoivent comme
une récompense de skill, pas un paywall). Notre Grimoire implémente uniquement le type 2
(contenu découvert), sans jamais établir le lien vers le type 3 (maîtrise acquise).

**Ce que ça implique concrètement** : le Chapitre II (essences par famille) devrait
afficher non seulement « 12/15 unités poison découvertes » mais « MAÎTRISE POISON :
AVANCÉ — tu connais les unités T3 clés (festering, marrow_drinker) ; prochaine découverte
débloque les interactions de propagation. » Ce signal est entièrement data-driven (list
de `dot_family` découverts croisé avec un seuil minimal) et n'exige aucun moteur nouveau.
Il ancre le Grimoire sur la SDT-compétence en plus de l'Ovsiankina.

**Note sur la faisabilité dans NOS contraintes** : le Grimoire stocke déjà les reliques
acquises et les builds nommés (après §2.4bis). Les `dot_family` des unités découvertes
sont dérivables des `id` vus en boutique. Pas de nouveau invariant.

### 2.4 DÉSACCORD LÉGER : le signal TRACE D'IMPACT (§2.8) au lancement suppose une localité du pool qui n'est pas garantie dans notre architecture FIFO

**Ce que §2.8 propose** : au lancement, lire depuis `snapstore.lua` le nombre de combats
résolus contre le ghost LOCAL du joueur. Si N ≥ 1 → message grimdark.

**La faille concrète que les rounds 5-7 ont ouverte mais non résolue** (Q_R5_2 + Q_R7_4,
tous deux encore ouverts en v8) : le store FIFO local contient 200 snapshots. Si le joueur
a fait 5 runs, son ghost est parmi 5 dans le pool (P(son ghost servi) ≈ 1/5 par combat ≈
20 %). Sur 10 combats joués par d'autres instances locales (ou IA), P(son ghost servi au
moins 1 fois) ≈ 1 − (0.8)^10 ≈ 89 %. Donc N > 0 est probable APRÈS quelques sessions.

**MAIS en S1 réel (phase beta, < 50 joueurs locaux)** : le pool FIFO est partagé localement
(un seul joueur = une seule instance locale). Ses ghosts sont affrontés uniquement par
ses propres combats (le cold-start IA utilise `aiComp`, pas les ghosts locaux). Donc en
S1 sans backend, N = 0 systématiquement — sauf si l'IA est présentée avec une formulation
distincte (#Z, recommandé clos).

**Position de ce round** : #Z DOIT ÊTRE CLOS avant que §2.8 soit implémenté. La roadmap
recommande de clore #Z mais laisse la « décision DA finale à l'user ». Si l'user ne
tranche pas, §2.8 entre dans le code P0 avec un comportement **silencieux pour la majorité
des joueurs S1** — ce qui invalide l'objectif de session-initiation. **Élever #Z en BLOQUANT
l'implémentation de §2.8** jusqu'à la décision DA. Ce n'est pas un changement de design
— c'est un gate de priorisation.

---

## 3. PROPOSITIONS PRIORISÉES (concrètes, chiffrées, ancrées sur nos ressources)

### Proposition A — PONDÉRATION DU TABLEAU DE FRÉQUENCE VRR PAR INTENSITÉ (PRIORITÉ 2, doc ~1 h)

**Problème** : le tableau d'intention de fréquence VRR (§2.9, cible ≤20 signaux/run) agrège
des signaux de poids émotionnel très différents dans le même compteur. Une offre de relique
(identité du run, high-stakes, décision 1-parmi-3) ≠ un signal VRR boutique (low-stakes,
1 unité dans 5). Couper dans l'un ou l'autre sans les distinguer produit un tableau dont
la borne ≤20 est arbitraire.

**Ce** : ajouter au tableau d'intention de fréquence VRR une **colonne POIDS HÉDONIQUE** :

| Source VRR | Fréquence/run | Poids hédonique | Fréquence pondérée/run |
|---|---|---|---|
| Boutique (reroll) | ~9-14 signaux | 1 (low) | 9-14 |
| Moment du Run | ~3-4 signaux | 3 (high — cascade visible) | 9-12 |
| Surprise de Placement | ~2-3 signaux | 2 (medium — near-miss) | 4-6 |
| Offre de Relique | ~4-5 signaux | 4 (very high — décision identitaire) | 16-20 |
| Trace d'impact | 1 signal | 2 (medium — info persistence) | 2 |

**Total pondéré estimé** : 40-54 unités hédoniques. La borne cible devient « ≤50 unités
pondérées/run » — ce qui est plus précis que « ≤20 signaux bruts ». Si les sims montrent
un dépassement → couper en priorité les signaux à poids=1 (boutique, les plus fréquents et
les moins intenses).

**Sourced from** : Game Developer (Reward Schedules, habituation par TYPE, pas fréquence) ;
Kao et al. 2024 (CHI, amplification excessive → réduction d'agence). L'idée que des
récompenses de poids différents s'habituent différemment est standard en neuromodulation.

**Zone sans test** : doc pur, 0 code. Enrichit §2.9 du brouillon.

### Proposition B — SIGNAL « CONTRE LA MORT » = source VRR de RELIEF (PRIORITÉ 2, RENDER ~1 h, 0 SIM)

**Problème identifié §2.1** : tous les signaux VRR de la roadmap sont de valence POSITIVE
(surprise de récompense). La littérature (SDT Dark Souls) montre que le RELIEF (évitement
de conséquence négative sous agence) est une source VRR qualitativement distincte — plus
durable précisément parce qu'elle introduit le contraste hédonique.

**Ce** : après chaque VICTOIRE où le score final d'une unité adverse a dépassé ≥75 % des PV
d'une unité du build avant de mourir (calculé depuis le bus JSONL — `{target, hp_before,
damage, tick}` est déjà encodé), afficher **1 ligne post-combat** distincte du Moment du
Run : **« [NOM_UNITÉ] A TENU — LE PUITS A FAILLI TE CONSUMER »** + surlignage discret de
l'unité survivante.

**Pourquoi distinct du Moment du Run** :
- Moment du Run = « j'ai fait quelque chose de brillant » (agence positive)
- Signal CONTRE LA MORT = « j'ai *évité* quelque chose de terrible » (relief / agence défensive)

Les deux ensemble créent le contraste hédonique. Les deux opèrent sur des unités DIFFÉRENTES
du build. Non cannibalisation.

**Condition de déclenchement** : uniquement sur VICTOIRE (jamais sur défaite — le joueur
en défaite est déjà en mode post-combat ; ajouter un signal « tu as failli survivre »
serait paternaliste) ; uniquement si hp_remaining > 0 (l'unité a vraiment survécu, pas
juste tenu le plus longtemps) ; uniquement si 1 seule unité satisfait la condition (sinon
« failli te consumer » perd sa singularité).

**Garde-fou DA** : la formulation « LE PUITS A FAILLI TE CONSUMER » est grimdark pure —
le Puits est l'ennemi, pas l'ami. 0 félicitation. La survie est présentée comme un MIRACLE
sombre, pas une performance.

**Coût** : RENDER + lecture bus JSONL après combat. 0 SIM. 0 invariant. ~1 h. Zone sans
test → test que la condition se déclenche correctement sur le golden (golden scénario fixe
avec une unité survivante proche de 0 HP).

**Source** : researchgate.net/publication/399804244 (SDT + Dark Souls : avoidance-mastery
loop + hedonic contrast) ; UX Magazine 2025 (contraste hédonique dans les systèmes de
streak) ; Kao et al. 2024 (diversité de valence, pas seulement de fréquence).

### Proposition C — GRIMOIRE : COUCHE DE MAÎTRISE VISIBLE (PRIORITÉ 2, RENDER + data ~2 h)

**Problème identifié §2.3** : le Grimoire implémente la découverte (Ovsiankina) mais pas
la MAÎTRISE MANIFESTÉE (SDT-compétence). Le lien entre « savoir 12/15 unités poison » et
« être maintenant capable de construire un build poison T3 » est invisible.

**Ce** : dans le Chapitre II (essences par famille), ajouter sous le compteur
« {N}/{total} unités découvertes » un **badge de maîtrise** à 3 paliers, dérivé du nombre
d'unités T3 de la famille découvertes (T3 = rang-5 dans notre nomenclature) :

```
MAÎTRISE POISON :
  ○ INITIÉ   — 0/2 unités apex découvertes
  ◑ PRATICIEN — 1/2 unités apex découvertes  
  ● MAÎTRE   — 2/2 unités apex découvertes + ≥1 relique-E poison vue
```

Les « unités apex » de chaque famille = les rangs-5 de cette famille (2-3 par famille,
déjà définis dans `units.lua`). La relique-E poison = `plague_communion` ou `festering`
(déjà identifiables par `relics.lua`).

**Pourquoi 3 paliers seulement** : le Goal Gradient est maximal sur les cibles à
~3-7 étapes (LogRocket 2024, déjà cité round 6). 3 paliers = optimal pour cette sous-section.

**Connexion au NOM DE BUILD (§2.4bis)** : le Grimoire peut ajouter « Tes runs BRÛLEUR
du PUITS : 3 fois INITIÉ, 1 fois PRATICIEN. Prochaine étape : découvrir [ASH_MAW]. »
Ce lien nom-build ↔ maîtrise-famille résout le problème §2.2 (identité de run → identité
durable via la maîtrise).

**Coût** : RENDER + 3 règles de données (seuils apex + relique-E par famille). 0 SIM.
0 invariant. ~2 h. Zone sans test → test que le badge est dérivé correctement de la
liste de grimoire sur le golden.

**Source** : IntechOpen 2025 (maîtrise = type de progression le plus durable) ; SDT
Dark Souls (compétence : « pouvoir NOMMER sa progression ») ; LogRocket 2024 (Goal
Gradient ≤7 étapes) ; dev.to/yurukusa 2026 (identité = pattern reflété, pas liste).

### Proposition D — GATE BLOQUANT #Z AVANT L'IMPLÉMENTATION DE §2.8 (PRIORITÉ 1, décision design)

**Problème identifié §2.4** : le litige #Z (signal spectre en cold-start, N=0 silencieux)
est « recommandé clos » depuis le round 7 mais reste ouvert, laissant la décision DA à
l'user. En l'absence de décision, §2.8 peut entrer en P0 avec le comportement par défaut
(silencieux si N=0) — qui invalide l'objectif de session-initiation pendant toute la
phase S1 (pool quasi-vide).

**Ce** : inscrire dans la roadmap que **l'implémentation de §2.8 est BLOQUÉE par la
décision DA de #Z**. Deux options avec leurs conséquences :

- **Option 1 (silencieux si N=0)** : §2.8 fonctionne uniquement en version communautaire
  (backend). En S1 local → pas de signal de session-initiation du tout → accepté
  explicitement.
- **Option 2 (IA formulation distincte, recommandée)** : « LE PUITS A SOUMIS TON BUILD
  AUX ÉPREUVES DU VIDE — [N] INVOCATION[S] L'ONT ÉPROUVÉ » ; fallback silencieux si N=0
  même pour IA. Fonctionne dès S1 (les encounters IA sont présents). Honnêteté préservée.

**Position de ce round** : Option 2 est la seule qui rende §2.8 utile en S1. Si l'user
tranche « ÉPREUVES DU VIDE casse le cryptique », alors §2.8 est DIFFÉRÉ à la phase
backend — mais cette décision doit être consciente, pas par défaut.

**Coût** : 1 décision DA. 0 code avant la décision. Gate documenté dans le brouillon.

**Source** : Countly 2026 (90 s post-relance = moment critique) ; 00-state §5 (snapshots
cold-start via IA garantis) ; rounds 5-7 (Q_R5_2 + Q_R7_4 non résolus).

---

## 4. QUESTIONS OUVERTES (nouvelles ce round)

**Q_R8_1 — Contraste hédonique calibrable ?** La Proposition B (signal CONTRE LA MORT)
suppose un seuil « ≥75 % des PV perdus avant survie ». Est-ce que ce seuil produit un
taux de déclenchement compatible avec l'enveloppe VRR ≤20/run ? Estimation grossière :
si ~20 % des combats gagnés ont une unité survivante avec ≥75 % des PV perdus → ~2-3
signaux/run sur 10-15 rounds (tous des victoires) → budget pondéré +4-6 unités hédoniques
(poids=2). Compatible avec la borne. À valider via sim (lire `{hp_before, damage_taken}`
depuis le bus sur N=200 runs).

**Q_R8_2 — Badge de maîtrise et découverte de unités apex** : les unités rang-5 sont au
tier 5 de boutique (`shopTier=5`). En P0, le joueur peut finir 10 runs sans jamais voir
d'apex rang-5 si son run se termine avant de monter au tier 5. Le badge INITIÉ/PRATICIEN/
MAÎTRE restera donc à INITIÉ pour la majorité des joueurs S1. Est-ce frustrant (horizon
trop lointain) ou motivant (but visible) ? Réponse : le Goal Gradient est efficace quand
la cible est visible ET perçue comme atteignable dans un horizon proche. Si les apex sont
vus en 1/3 des runs environ → le Goal Gradient fonctionne. Si 1/10 → la cible semble
irréaliste → tirer l'horizon vers un critère plus accessible (ex. « découvrir 2 unités T3
rang-4 de la famille » plutôt que les apex rang-5). À trancher APRÈS la sim hunt-médian
(P3, §7.1 du brouillon — précondition déjà actée).

**Q_R8_3 — Un joueur peut-il avoir 2 runs dans la même session avec des NOMS DE BUILD
différents ?** Si oui, la liste « 5 derniers noms » peut montrer BRÛLEUR / ALCHIMISTE /
BRÛLEUR / BRÛLEUR / SANG-FROID en 2 h de jeu. Le signal d'identité se dilue (le joueur
ne sait plus « qui il est »). La roadmap ne définit pas si le nom persiste PAR JOUR ou
PAR RUN. Si PAR RUN → instabilité de l'identité sur sessions courtes. Si PAR JOUR →
perd la granularité des essais. **Proposition** : le signal d'identité durable (§2.2) ne
devrait afficher que le nom de build du RUN le plus récent + le plus fréquent (mode
statistique sur les 10 derniers) → « TU ES PRINCIPALEMENT UN BRÛLEUR [4/10 runs]. »
~1 phrase RENDER sur des données déjà disponibles.

**Q_R8_4 — Le signal « CONTRE LA MORT » est-il DA-compatible avec le grimdark cryptique ?**
La formulation proposée (« LE PUITS A FAILLI TE CONSUMER ») présente le Puits comme une
force qui a essayé de détruire le joueur. C'est cohérent avec la DA. Mais si ce signal
se déclenche souvent (victoires serrées), le Puits devient l'antagoniste constant
**apparent** — ce qui peut désamorcer le sentiment de progression (« le Puits essaie
toujours de me tuer, j'ai juste de la chance »). Mitigation déjà intégrée : condition
unitaire (1 seule unité satisfait) + uniquement victoire. À valider en playtest.

---

## 5. ACCORDS SOUS CONDITIONS — ce qu'il faut surveiller mais pas modifier

### 5.1 NUANCÉ : la Surprise de Placement (§2.7) reste valide mais la condition de désactivation par déplacement intentionnel est sous-testée

La spec est correcte (cap dur 10 sessions + déplacement intentionnel). Mais le bus
JSONL encode `{cause="player_move"}` seulement si `build.lua` l'émet — ce n'est pas
vérifié dans les garanties de test (00-state §8 : zone sans test). Si `player_move`
n'est pas émis systématiquement lors d'un drag, le critère `grimoire:hasMovedForAdjacency()`
ne se déclenche jamais → la Surprise ne se désactive jamais → bruit après 20 runs.

**Position** : ajouter une assertion simple dans le test headless (drag → vérifier que
le bus reçoit bien `{cause="player_move"}`). 0 invariant (test headless, pas golden).
Bloquant avant l'implémentation de §2.7.

### 5.2 NUANCÉ : #BB (Daily = unranked + leaderboard) adopté, mais la coupure entre daily et run d'identité crée un risque de fragmentation

Adopté en round 7 (§4.4). La recommandation (unranked + leaderboard journalier séparé)
est correcte pour l'intégrité ranked. Mais un Daily run a une contrainte imposée (famille,
sigil) qui peut forcer un NOM DE BUILD différent de l'archétype habituel du joueur. Ex.
un joueur « BRÛLEUR du PUITS habituel » qui fait le Daily poison et devient « DISTILLATEUR
du PUITS » pendant ce run. Le signal d'identité §2.4bis s'applique-t-il aux Daily ou non ?

**Position** : exclure les Daily du signal d'identité Grimoire (ne pas persister le nom
dans `grimoire.lua` pour les Daily) — ils sont des explorations temporaires, pas des
expressions de l'archétype habituel. Même convention que StS (le Daily n'alimente pas
l'Ascension). Doc pur, 0 code.

---

## 6. REJETS — propositions qui auraient pu venir mais qui sont inutiles ou contreproductives

### 6.1 REJETÉ — Partage social des noms de build (screenshot / export)

Tentant : le nom de build est « shareable » (dev.to/yurukusa 2026 : « The name converts
a technical state into a social object. »). Mais notre DA = anonymat grimdark, zéro
identité sociale visible. Un bouton « partager [BRÛLEUR DU PUITS] » rompt l'hermétisme
du Puits et introduit une boucle sociale externe que notre modèle async ne supporte pas.
De plus, pour un jeu solo-dev S1 < 50 joueurs, le partage social est un levier de
croissance (marketing), pas de rétention (psychologie interne). Ces deux objectifs ne
doivent pas être confondus. **Différé à post-v1.0 si une communauté existe.**

### 6.2 REJETÉ — Compteur de streak de NOM DE BUILD (« 3 runs BRÛLEUR consécutifs »)

Tentant : les streaks sont un mécanisme de rétention bien documenté (Medium 2025, Streaks
as Habit-Forming Systems). Mais un streak de build-name crée une **obligation implicite**
de répéter l'archétype — ce qui va à l'encontre de l'exploration. Dans un roguelite, la
liberté d'exploration est un pilier de la rétention à long terme. Imposer une pression
de streak sur l'archétype = punir l'expérimentation. De plus, la DA grimdark oppressive
ne supporte pas les mécaniques de streak explicites (qui impliquent une « récompense à
ne pas perdre » — trop mobile-gamey). **Rejeté, non différable.**

### 6.3 REJETÉ — Signal VRR sur les RECHUTES DE STATS (régression visible en combat)

Idée : « quand une unité de ton build perd ≥50 % de ses PV dans le 1er tick de combat
(exposée front), émettre un signal qui dit que le placement était risqué ». Cela créerait
un VRR négatif (punition surprise). Mais le déterminisme de nos combats (même seed = même
bataille) rend ce signal PRÉVISIBLE (le joueur rejoue le même build = le même signal se
déclenche). Un signal déterministe n'est pas un VRR — c'est un feedback fixe. **Rejeté :
le déterminisme invalide toute VRR négative prévisible.**

---

## 7. CHALLENGE CLÉ (résumé)

La roadmap v8 a une architecture de rétention correctement fondée et bien ancrée (NOM DE
BUILD, VRR boutique, BARRE XP, SURPRISE DE PLACEMENT, enveloppe de fréquence). Le challenge
de ce round est systémique : **tous les signaux VRR sont de valence POSITIVE** (récompense
surprise), ce qui crée une habituation rapide au même circuit émotionnel malgré leur
diversité apparente — il manque un signal de type RELIEF (hedonic contrast, avoidance-mastery
loop). Ce trou est comblé par la Proposition B (Signal « CONTRE LA MORT »), à coût
minimal (~1 h RENDER). En parallèle, **le Grimoire est optimisé pour la tension
d'inachèvement (Ovsiankina) mais pas pour la compétence manifestée (SDT-compétence)** —
ajouter un badge de maîtrise par famille (Proposition C, ~2 h RENDER) ancre le Grimoire
sur les deux piliers psychologiques les plus durables. Enfin, **le litige #Z doit être
clos comme gate bloquant de §2.8** avant l'implémentation : en S1 local, §2.8 est
silencieux pour la majorité des joueurs si #Z n'est pas tranché — ce qui invalide
l'objectif de session-initiation précisément quand il est le plus critique.

---

*Rédigé le 2026-06-23. Lentille : rétention-addiction (variance vs agence, high-roll,
near-miss sous agence, méta-progression Grimoire, one-more-run). Round 8/10 du roadmap-lab.
Lecture seule du repo. N'édite que sous `docs/roadmap-lab/`. Garde-fous : piliers
async/déterministe/grimdark/procédural préservés, 32 invariants non touchés.*

*Sources web vérifiées ce round :*
- *SDT applied to Dark Souls (motivation, autonomy, competence, relatedness) : https://revistainteracciones.com/index.php/rin/article/view/479*
- *ResearchGate (SDT Dark Souls, avoidance-mastery loop) : https://www.researchgate.net/publication/399804244*
- *PSU.com 2025 (VRR, slot machine psyche) : https://www.psu.com/news/the-slot-machine-psyche-how-variable-ratio-reinforcement-drives-modern-gaming-engagement/*
- *Medium 2025 (Streaks and Daily Rewards as Habit-Forming Systems) : https://medium.com/design-bootcamp/streaks-and-daily-rewards-as-habit-forming-systems-dab7f5a34539*
- *UX Magazine 2025 (Psychology of Hot Streak Game Design) : https://uxmag.com/articles/the-psychology-of-hot-streak-game-design-how-to-keep-players-coming-back-every-day-without-shame*
- *Mobalytics 2026 (The Bazaar Review) : https://mobalytics.gg/news/guides/the-bazaar-review*
- *Switchblade Gaming 2026 (Best Auto-Battler Games 2026) : https://www.switchbladegaming.com/strategy-games/best-auto-battler-games-2026/*
- *IntechOpen 2025 (Pathways to Mastery: Taxonomy of Player Progression) : https://www.intechopen.com/chapters/1221745*
- *arXiv 2025 (Playing to Pay: Korean Mobile Gaming Retention) : https://arxiv.org/pdf/2504.10714*
- *PC Gamer 2025 (The Bazaar, post-disastrous launch) : https://www.pcgamer.com/games/card-games/after-its-disastrous-launch-last-year-im-here-to-tell-you-that-2025s-most-promising-auto-battler-finally-lives-up-to-its-potential/*
- *Game Developer (Reward Schedules and When to Use Them) : https://www.gamedeveloper.com/business/reward-schedules-and-when-to-use-them*
- *arXiv 2025 (Uncertainty in Procedural Maps in Slay the Spire) : https://arxiv.org/pdf/2504.03918*
- *dev.to/yurukusa 2026 (build naming, identity vs data) : https://dev.to/yurukusa/50-lines-of-code-15-build-names-one-accidental-challenge-mode-1be1*
