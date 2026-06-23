# Round 09 — Critique adversariale : lentille Ranked & Compétitif

> **Lentille** : MMR/ladder, saisons, leaderboards, intégrité async, ce qui pousse à grinder
> le ranked et enchaîner les runs.
>
> **Statut** : round 9/10. Challenge le brouillon v9 (`ROADMAP-draft.md` post-round-8),
> la synthèse `round-08.md` et le document de lentille précédent `rounds/r08-ranked-competitive.md`.
>
> **Sources primaires mobilisées ce round** :
> - ROADMAP-draft.md §6.1-6.12, §8.0, round-08.md, 00-state.md, rounds/r08-ranked-competitive.md
> - Management Science 2026 (EurekAlert, juin 2026) : « Smarter matchmaking—not just equal skill—could
>   keep millions more gamers playing » — eurekalert.org/news-releases/1130401
> - Invenglobal 2026, « How Game Communities Decide What Feels Fair » — invenglobal.com/cve/articles/23028
> - Kydagames 2026, « Designing Competitive Leaderboards for Repeat Visits » — kydagames.com/blog/designing...
> - SAP v0.41 wiki (ranked versus seasons, juillet 2025) — superautopets.wiki.gg/wiki/Version_0.41
> - SAP v0.28 wiki (ranked design decisions, sept. 2023) — superautopets.wiki.gg/wiki/Version_0.28
> - POE 2 seasonal model design analysis — game-wisdom.com/general/design-philosophy-behind-poe-2... (mars 2026)
> - League of Legends ranked 2025 post-mortem — leagueoflegends.com/en-us/news/dev/dev-ranked-update-season-one-2025/
> - LoL ranked 2026 — leagueoflegends.com/en-us/news/dev/dev-ranked-2026/
> - Legionbound daily ranked mode review — thebigbois.com/action/legionbound-review/ (mai 2026)
> - fairgame.us 2026 : skill-based matchmaking fairness — fairgame.us/skill-based-matchmaking-fairness...
> - yukaichou.com 2026 : leaderboard design Octalysis — yukaichou.com/gamification-analysis/leaderboard-design...
> - Kingdom Clash async PvP matchmaking — pocketgamer.biz (juin 2026)
> - CHI 2026 : player flexibility in competitive systems — dl.acm.org/doi/10.1145/3772318.3791411
> - rise.global 2025 : psychology of competition why leaderboards work — rise.global/2025/06/15/...
> - **Sources déjà actées rounds 1-8 mais relues** : dev.to/yurukusa (2026) ; seganerds.com (2026) ;
>   yukaichou.com (2023) ; gamedesigning.org/poe2 (2026) ; kryptekdev.com (2025) ; bazaar-builds.net (2024-2025)
>
> **Garde-fous absolus** : lecture seule du repo. N'édite que sous `docs/roadmap-lab/`.
> Piliers intacts : async snapshots / sim déterministe seedée / DA grimdark / pixel art procédural.
> 32 invariants préservés.

---

## 0. TL;DR du challenge R09

**Quatre angles, tous mécanistes :**

1. **ACCORD FORT sur les fondations ranked (§6.1-6.5)** — les décisions actées (pas de pénalité,
   SOFT/HARD pool, seed daily partagée, Contrainte de Saison P2) tiennent et s'appuient désormais
   sur des preuves empiriques solides issues d'un corpus 2025-2026 plus dense. Mais l'accord cache
   un problème structurel non adressé : **le ranked propose 2-3 types de motivations IDENTIQUES**
   (progress visible) et aucune motivation de contraste (compétence perçue, identité de style de jeu
   measurable). Sans ça le grind ranked donne l'impression d'aller nulle part.

2. **DÉSACCORD MAJEUR — La grille `+4/+2/+1/0` récompense la DURÉE du run, pas la QUALITÉ.**
   10 victoires contre des IA de pool faible = +4 pts. 10 victoires contre un pool choc (famille
   difficile, déséquilibrée) = +4 pts. Ces deux résultats n'ont aucune raison d'être identiques.
   Le round 8 a adressé le biais de composition du pool (ranked §2.2 — signal distribution familles)
   mais jamais la valeur du résultat en fonction du pool rencontré. C'est le problème fondamental
   d'équité perçue dans notre modèle qui n'a pas encore été challengé.

3. **LACUNE — La zone 0-5 victoires a des marques sub-tier (§6.2) mais aucun signal de COMPÉTENCE
   durable.** Les marques (Survivant/Forgé/Ascendant) sont des attestations de résultat, pas de
   maîtrise. Un joueur qui fait 7-3 run après run pendant 5 saisons n'est jamais « Forgé » (il lui
   faut 8-9 wins). Mais il a prouvé une MAÎTRISE du build à mi-run qui n'est mesurée nulle part.
   C'est un trou de signal de compétence, distinct du trou de signal de rétention.

4. **PROPOSITION NOUVELLE — La « Profondeur du Puits » comme dimension ranked orthogonale au LP.**
   La roadmap n'a qu'une dimension de classement (LP). L'expérience ranked n'a donc qu'un seul
   axe d'amélioration à percevoir. Or la recherche Management Science 2026 prouve que le matchmaking
   qui considère DEUX dimensions d'historique (niveau de skill + historique récent d'outcomes)
   produit +4 à +6 % d'engagement. Une 2e dimension visible (non cachée comme MMR TFT) : la
   « Profondeur du Puits » — le round le plus avancé atteint en ranked cette saison — est simple,
   lisible, grimdark, et donne un axe de progression pour le joueur mid-core qui ne peut pas encore
   atteindre 10 victoires.

---

## 1. Accords — et POURQUOI ils tiennent à nos contraintes

### 1.1 ACCORD FORT — Pas de pénalité + SOFT/HARD pool + grille `+4/+2/+1/0` (§6.1-6.2)

**Accord maintenu et renforcé par de nouvelles sources.**

**Ce round** : la recherche EurekAlert/Management Science (juin 2026) confirme le principe dans un
corpus de 5,4 millions de parties d'échecs (Lichess). La conclusion clé :

> *"Traditional skill-based matchmaking guarantees that many players lose as often as they win.
> Over time, repeated losses—or even short losing streaks—can drive frustration and push players
> away."*
> Source : eurekalert.org/news-releases/1130401

Dans notre contexte : une pénalité sur un pool FIFO 200 imparfait = exactement cette situation
(pénalité pour la pauvreté du pool, pas pour la compétence). La grille `+4/+2/+1/0` reste la
bonne réponse. L'accord r07/r08 reste valide.

**Nuance nouvelle** : la même étude montre que le matchmaking considérant l'**historique récent**
(et pas seulement le niveau) améliore l'engagement de 4-6 %. Ce n'est pas un argument pour
complexifier notre matchmaking à court terme (notre pool FIFO est trop petit), mais c'est un
argument pour enrichir notre signal pré-run (§6.11) avec l'historique récent du joueur — ce que
la roadmap ne fait pas encore (voir §3 ci-dessous).

### 1.2 ACCORD FORT — Seed partagée Daily (#BB CLOS, §6.6) + IA ranked 1 build/famille (§6.4bis)

**Accord maintenu.** La valeur psychologique de la comparabilité dans un run à seed partagée est
désormais empiriquement renforcée.

**Légère nuance** : SAP v0.47 (avril 2026) a introduit un « Daily Mode update ». La version SAP la
plus récente montre que même un jeu à seed partagée fonctionne mieux avec une contrainte de session
qu'avec une simple contrainte de pool. Notre implémentation « date + constraint_id » est donc
correcte — la contrainte EST la seed, pas la seed de pool. Ce point était ouvert dans le R08 (#EE-ranked,
scope du seed daily) et est désormais confirmé : seed des combats uniquement, shop libre.

### 1.3 ACCORD FORT — Contrainte Permanente de Saison avancée en P2 (§8.0)

**Accord total.** La recherche POE 2 (game-wisdom.com, mars 2026) confirme de façon décisive :

> *"Every new league ships with balance changes that shift which builds are strongest. Because
> everyone starts from scratch simultaneously, those changes hit the entire player base at the
> same moment. The result is a genuine period of discovery at every league start."*
> Source : game-wisdom.com/general/design-philosophy-behind-poe-2... (mars 2026)

Notre `teamFlag` saisonnier est l'analogue minimal de ce mécanisme à coût quasi nul (0 moteur,
`grant_team` câblé). La S1 sans ce mécanisme = « reset de score dans une méta inchangée » (acté
R08) ; avec la Contrainte de Saison, même les joueurs S1 qui ont appris « poison domine » doivent
réévaluer en S2 (`poisonWeakenStack` par exemple change la dynamique de weaken). **La décision de
l'avancer à P2 est non-négociable sur la base de cette recherche.**

**Nuance importante (#U, litige ouvert)** : voir §2.2 ci-dessous pour le vrai challenge sur la
sélection de la Contrainte de Saison.

### 1.4 ACCORD FORT — Communication honnête S1 = « Invocations » (§6.5)

**Accord maintenu.** L'article Kingdom Clash (pocketgamer.biz, juin 2026) d'un dev d'autobattler
asynchrone ayant traversé exactement notre problème (lancement local → pool faible → frustration) :

> *"In practice, that's not always easy: players are very vocal about fairness, but they will
> absolutely abuse any available mechanic if it helps them climb higher."*
> Source : pocketgamer.biz (juin 2026)

La conclusion Kingdom Clash : le matchmaking ELO est correct mais la COMMUNICATION sur ses
limites est critique. Notre « Invocations du Puits » préserve l'honnêteté tout en gardant la
fiction grimdark. **C'est la décision R07 qui tient le mieux sur le long terme.**

---

## 2. Désaccords — avec recherche sourcée

### 2.1 DÉSACCORD MAJEUR — La grille `+4/+2/+1/0` récompense la DURÉE, pas la QUALITÉ du run

**Ce que le brouillon v9 §6.2 dit** : Ascension 10 victoires = +4 pts, Chute 8-9 = +2 pts,
Chute 6-7 = +1 pt, Chute 0-5 = 0. Grille calibrée par la hauteur du tier.

**Mon désaccord** : la grille récompense le **résultat binaire de durée de run** (10V vs 8V vs
6V) mais pas la **qualité perçue du parcours**. Deux scénarios identiques en LP :

- **Scénario A** : ascension 10V contre un pool early/mid de familles choc (famille
  sous-performante, matchups faciles structurellement) → +4 LP.
- **Scénario B** : ascension 10V contre un pool saturé de poison (famille dominante, matchups
  difficiles) → +4 LP.

Ces deux runs ne méritent pas le même LP. Le round 8 a adopté le signal de distribution du pool
(§4.8 — « TU AS AFFRONTÉ [N] BRÛLEURS / M SAIGNEURS ») comme transparence, mais **jamais comme
levier de différenciation du score**.

**Preuve via SAP v0.28 (la vraie référence)** : SAP ranked (v0.28, sept. 2023) utilise
**ELO** — la victoire contre un adversaire mieux classé rapporte plus de points. SAP wiki :

> *"It is based on the Elo rating system where you start with 1000 points and then gain and
> lose based on your opponent's score."*
> Source : superautopets.wiki.gg/wiki/Version_0.28

Le R08 a rejeté le MMR caché à la TFT (6-9 runs, pas assez pour converger). Mais il n'a pas
challengé la **grille fixe** elle-même. Une grille fixe est le cas limite où TOUS les adversaires
ont le même score implicite — ce qui est précisément faux dans un FIFO biaisé.

**Pourquoi c'est important pour nous** : avec notre pool FIFO + distribution biaisée
(poison > ... > choc), un joueur qui ascende régulièrement contre un pool poison-dominant reçoit
le même signal LP qu'un joueur qui ascende contre un pool balancé. Sans différenciation, le ranked
**ne mesure pas la compétence** — il mesure la capacité à conclure un run face au pool disponible.
C'est exactement la frustration documentée par Backpack Battles (round 8, §2.2).

**Ma proposition — non sur le MMR caché, mais sur le MODIFICATEUR DE RUN TRANSPARENT** (voir
§3.1 ci-dessous). Ce n'est pas un MMR interne ; c'est un ajustement LP visible et grimdark.

**Pourquoi ce n'est pas un rejet de la grille existante** : la grille `+4/+2/+1/0` reste la
base correcte. Je propose un **multiplicateur borné et transparent** qui la module — pas un
remplacement. L'équité PERÇUE (fairgame.us 2026 : « fairness is about trust, not just math »)
exige que le joueur comprenne pourquoi un run facile et un run difficile ne peuvent pas valoir
exactement la même chose.

### 2.2 DÉSACCORD SUR #U — Le critère de sélection de la Contrainte de Saison est mal posé

**Ce que le brouillon v9 §8.0 dit** : le `teamFlag` saisonnier doit cibler l'archétype
**sous-représenté** (critère #U, litige ouvert : « plus bas win-rate » vs « plus sous-représenté
en pool boutique »).

**Mon désaccord** : les deux critères (#U) ciblent un symptôme (sous-représentation ou faible
win-rate) sans adresser la **cause**. La Contrainte de Saison n'est pas un outil d'équilibrage
(qui appartient à P3 via `tools/sim.lua`) — c'est un outil de **renouveau méta**.

**La distinction est mécaniste** : cibler la famille à bas win-rate (ex. choc) avec un
`teamFlag` qui favorise choc AVANT que le ladder choc soit résolu (décision #GG, litige bloquant
round 8) = **favoriser une famille structurellement sous-performante** → le joueur S2 qui joue
choc avec `shockChain` équipe découvrira en cours de run que l'apex choc n'est toujours pas
satisfaisant → frustration amplifiée par l'échec d'une contrainte saisonnière.

**Preuve POE 2** (game-wisdom.com, mars 2026) :

> *"Skills get buffed, others get adjusted down, new interactions emerge from new mechanics."*

POE 2 couple le `teamFlag` (Contrainte de Saison chez nous) à des changements d'équilibrage
qui précèdent le lancement de la ligue. **Sans co-livraison d'un équilibrage de la famille
ciblée**, la Contrainte de Saison amplifie les défauts existants plutôt que de créer un
renouveau.

**Critère révisé** : la Contrainte de Saison doit cibler la famille qui a le **plus grand écart
entre son potentiel théorique** (sim à composition optimale) et son **résultat réel en play**
(win-rate moyen) — ET ce potentiel théorique doit être **confirmé sain** (axe équilibré,
pas de dette technique comme #GG). Dans la pratique pour la S1/S2 :

- S1 (pas d'équilibrage P3 fait) → cibler `bleedSlow2x` : bleed est un archétype équilibré
  (pas de litige bloquant), sous-représenté vs poison, et son axe est bien compris.
- S2 → cibler burn (si burn midgame résolu — désert rang-3 burn, §1.4 round 8).
- NE PAS cibler choc tant que #GG n'est pas tranché.

**Décision** : ajouter un **prérequis de sélection** dans §8.0 : « la famille ciblée par la
Contrainte de Saison DOIT avoir son axe marqué "résolu" dans `seed/decisions.md` avant d'être
choisie ». Cela évite d'amplifier des familles avec des dettes techniques actives.

### 2.3 DÉSACCORD PARTIEL — Le signal pré-run (§6.11) ne mesure pas ce qui fait RE-QUEUER

**Ce que le brouillon v9 §6.11 dit** : le signal pré-run = grille concrète + distance au
prochain tier + distance à la marque sub-tier. Adopté comme « manquant #1 » (round 4).

**Mon désaccord partiel** : c'est **nécessaire mais insuffisant pour le re-queue**. La
recherche Management Science (EurekAlert 2026) est précise :

> *"The system then optimizes matchups over time with the goal of maximizing long-term engagement
> across the entire player ecosystem. The key insight: matchmaking should not be viewed as a
> series of isolated decisions, but as a dynamic system where every match influences what
> players do next."*
> Source : eurekalert.org/news-releases/1130401

**Ce que ça dit de notre signal pré-run** : il montre où j'en suis (LP, marque) mais pas
l'**élan** de ma progression récente. Deux joueurs à 14/35 LP (Forgé dans 2 runs) :

- Joueur A : 14 pts en 4 runs (3.5 pts/run en moyenne), en progrès.
- Joueur B : 14 pts en 9 runs (1.5 pts/run), plateau depuis 3 sessions.

Le signal pré-run leur affiche la **même chose** (« 4 pts pour Forgé »). Mais la **motivation
de re-queuer** est radicalement différente. L'élan de Joueur A le pousse à jouer ; Joueur B
risque le churn si rien ne différencie son expérience.

**Ce qui est déjà dans la roadmap** : `season_wins` (§6.8) est un signal POST-run. Les marques
sub-tier (§6.2) sont également des attestations de résultat passé. Il n'y a aucun signal
d'**élan récent** (tendance des 2-3 derniers runs) dans le pré-run.

**Ma proposition** (§3.2 ci-dessous) : un **signal d'élan de 3 runs** dans le pré-run, grimdark,
qui différencie l'état psychologique avant de plonger. Coût : RENDER pur, lit l'historique des
3 derniers résultats.

---

## 3. Propositions priorisées

### 3.1 — Modificateur LP VISIBLE par contexte de pool — PRIORITÉ 2 (après P2 ranked baseline)

**Problème** : §2.1 — la grille fixe ne différencie pas la difficulté du pool rencontré.

**Proposition** : après la mesure de la distribution du pool (§4.8 round 8 — signal
« TU AS AFFRONTÉ [N BRÛLEURS / M SAIGNEURS] »), AVANT la distribution du LP final, afficher :

```
ASCENSION 10V — +4 LP (BASE)
Pool reconnu : [6 DISTILLATEURS / 3 SAIGNEURS / 1 BRÛLEUR] — pool CORROSIF
→ JUGEMENT DU PUITS : +1 LP supplémentaire (pool majoritairement dominant)

ASCENSION 10V — +4 LP (BASE)
Pool reconnu : [2 CHOC / 2 BRÛLEURS / 3 SAIGNEURS / 3 MÉLANGÉS] — pool ÉQUITABLE
→ JUGEMENT DU PUITS : +4 LP (base, aucune correction)
```

**Maths (borné et transparent)** :
- Pool « dominant » = ≥ 60 % des ghosts de la famille à win-rate le plus haut (poison run-8) →
  `lp_adjustment = +1` (cap : jamais plus de +1 ou -1 pour éviter la complexité).
- Pool « faible » = ≥ 60 % des ghosts de la famille à win-rate le plus bas (choc) → `lp_adjustment = +1`
  également (difficulté inverse par under-challenge non contrôlé).
- Pool « équitable » (pas de famille > 60 %) → `lp_adjustment = 0`.
- **Jamais de pénalité** (aligné décision §6.2 : `+4/+2/+1/0` sans pénalité).

**Pourquoi c'est valide** :
- L'équité PERÇUE est la condition #1 de la rétention ranked (seganerds.com 2026 ; fairgame.us 2026).
- Le signal de distribution est DÉJÀ adopté (round 8 §4.8) — ce modificateur l'utilise comme
  levier LP, pas seulement comme information.
- Grimdark-cohérent : « Le Puits reconnaît la nature de l'épreuve. »
- Async-safe : calculé depuis les familles des snapshots servis, IO hors SIM, 0 invariant.

**Limites (à documenter)** :
- `+1` borné = modification faible (~2 % de la hauteur d'un tier) → ne déséquilibre pas la courbe.
- Pas de pénalité pour pool « faible » (choc) : le joueur choc qui gagne régulièrement ne doit
  pas être pénalisé parce que son pool était jugé « trop facile » (cela découragerait l'archétype
  sous-représenté).
- **Zone sans test** → test que `lp_adjustment` est correctement calculé sur un golden run avec
  pool connu (golden store famille-distribution).

**Priorité 2** (pas P2 core) : dépend de la mesure `dot_family` des snapshots (P0.5 + `toComp`
déjà partiellement disponible) et de la baseline post-pool (round 8 §4.8). À livrer en P2.5.

### 3.2 — Signal d'ÉLAN des 3 derniers runs dans le pré-run — PRIORITÉ 2 (P2 RENDER)

**Problème** : §2.3 — le signal pré-run mesure la position, pas l'élan.

**Proposition** : dans l'écran pré-run ranked (§6.11), en dessous de la grille LP, ajouter une
ligne d'élan basée sur les 3 derniers runs ranked :

```
RUN 1 (5V-5D) : 0 pt  → RUN 2 (8V-2D) : +2 pts → RUN 3 (10V) : +4 pts
→ "LE PUITS RESSENT TON ASCENSION" [tendance montante]

RUN 1 (10V) : +4 pts  → RUN 2 (6V) : +1 pt  → RUN 3 (4V) : 0 pt
→ "LE PUITS ABSORBE TA CHUTE" [tendance descendante — sans jugement, factuel]

RUN 1 (8V) : +2 pts → RUN 2 (7V) : +1 pt → RUN 3 (9V) : +2 pts
→ "LE PUITS TE TIENT" [plateau — stable]
```

**Psychologie (yukaichou.com 2026 — Octalysis)** :
> *"Leaderboards motivate through the psychological experience of winning, belonging, and visible
> progress. The competition is the mechanism. The motivation is the outcome."*

L'élan est le signal psychologique le plus direct du « je suis en train de progresser ». Les
joueurs en tendance montante re-queuent parce qu'ils voient leur trajectoire ; les joueurs en
plateau ont besoin d'un signal de stabilité (« tu es ici ») plutôt qu'un signal vide.

**Maths** : `trend = sign(lp_run[-1] - lp_run[-3])` — simple, 3 points suffisent pour la
tendance perçue. Si `< 3 runs ranked` → afficher uniquement les runs disponibles sans label de
tendance (pas de signal faux).

**Grimdark** : « LE PUITS RESSENT TON ASCENSION » est factuel et omineux. Pas de félicitation.

**Coût** : RENDER pur, lit l'historique `player.ranked_history[-3:]` (IO hors SIM, 0 invariant).
~30 lignes. Zone sans test → test que le label de tendance est correct sur un golden run ranked
simulé à 3 issues fixes.

**Priorité 2** : enrichissement du §6.11, livrable avec P2 ranked core.

### 3.3 — Dimension « Profondeur du Puits » : axe de progression mid-core ORTHOGONAL au LP — PRIORITÉ 1 (spec P2)

**Problème** : §0 TL;DR §3 — le joueur 7-3 répété n'a jamais de signal de compétence durable.
Les marques Survivant/Forgé/Ascendant récompensent le meilleur résultat mais pas la régularité.

**Proposition** : introduire une **2e dimension visible**, permanente par saison, qui mesure la
**profondeur maximale atteinte** (round le plus avancé, indépendamment du résultat final) :

```
PROFONDEUR DU PUITS — Saison 1 :
  Niveau max atteint : Round 7 (sur 10)
  « LE PUITS T'A VU DESCENDRE JUSQU'AU SEPTIÈME CERCLE »
```

**Psychologie (kydagames.com 2026)** :
> *"Common leaderboard mistakes include stagnant top ten rankings and zero-sum mechanics, which
> severely demotivate casual players. Experts recommend using rolling 7-day resets and highlighting
> personal bests alongside competitive ranks to maintain a highly dynamic, encouraging, and
> balanced gaming ecosystem."*

La Profondeur du Puits est exactement ce « personal best alongside competitive rank » : elle
mesure la **progression individuelle** (jusqu'où es-tu allé ?) indépendamment du résultat de
run (as-tu gagné ou perdu ?). Pour le joueur 7-3 répété, sa Profondeur du Puits = Round 7 — il
sait qu'il descend régulièrement jusqu'au 7e cercle. Ce signal lui donne un axe d'amélioration
concret : « qu'est-ce qui me bloque au round 8 ? »

**Maths** : `depth_record = max(rounds_completed_this_season)`. Méta cross-run, IO hors SIM.
Affiché dans le profil + pré-run. Reset saisonnier (comme le LP).

**Grimdark-cohérent** : les « Cercles du Puits » sont l'archétype grimdark parfait (Dante,
PoE). Chaque round = descente d'un cercle. Le joueur 10V a traversé le 10e cercle (ascension) ;
le joueur 7-3 a atteint le 7e.

**Async-safe** : stat de run, pas de snapshot. 0 invariant.

**Pourquoi c'est différent des marques** : les marques (§6.2) récompensent le **meilleur résultat
final** de la saison. La Profondeur du Puits mesure la **progression interne** (combien de rounds
avançait-on, indépendamment de la défaite finale). Ils sont **complémentaires**.

**Pourquoi ce n'est pas dans la roadmap actuelle** : 8 rounds ont focalisé sur le LP et les
marques finales. La Profondeur du Puits comble le signal de compétence MID-RUN qui manque dans
tout le chantier P2.

**Priorisation : SPEC uniquement pour P2** (2-3 lignes de data, 0 moteur, affichage RENDER).
L'implémentation complète est légère ; le design doit être tranché avant le code.

**Zone sans test** → test que `depth_record` est mis à jour correctement à chaque combat ranked
(golden run ranked à 7 combats).

### 3.4 — Précision de la sélection du `teamFlag` saisonnier : prérequis « axe résolu » — PRIORITÉ 1 (doc, AVANT code P2)

**Problème** : §2.2 — le critère #U (litige ouvert) cible les mauvaises familles si les axes
ne sont pas équilibrés avant la sélection.

**Proposition (doc, 3 lignes, §8.0 prérequis)** :

```
PRÉREQUIS DE SÉLECTION DU TEAMFLAG SAISONNIER (AVANT le code P2) :
  1. La famille ciblée DOIT avoir son axe marqué "résolu" dans seed/decisions.md
     (pas de litige bloquant tel que #GG pour choc, #désert-rang-3 pour burn).
  2. Ordre de priorité parmi les familles "résolues" :
     (a) famille avec le plus grand écart [potentiel théorique sim] - [win-rate réel]
     (b) à égalité : famille la moins représentée dans le pool ghost du tier 3+
  3. S1 prérequis minimal (avant P3) : utiliser bleedSlow2x (bleed = axe résolu,
     sous-représenté vs poison, aucun litige bloquant).
```

**Pourquoi maintenant** : sans ce prérequis documenté, le code P2 pourrait choisir `shockChain`
équipe pour S1 (axe D non implémenté, #GG bloquant) → Contrainte de Saison S1 amplifiait un
archétype cassé → frustration S2 garantie.

**Coût** : 3 lignes dans `seed/decisions.md` ou §8.0 ROADMAP. 0 code. AVANT le code ranked P2.

---

## 4. Démontage des analogies faibles dans la section ranked

### 4.1 — « SAP Arena = notre modèle de référence async » (§6.1, rounds 1-8)

**Analogie partiellement correcte, mais les modes ne sont PAS les mêmes.**

SAP a deux modes distincts depuis v0.28 (septembre 2023) :
1. **Arena** = mode async, 10 victoires, contre des builds générés par IA (pas de snapshots
   humains), **sans ranked**. Toujours casuel.
2. **Versus ranked** = 1v1 temps réel (pas d'async pur), ELO, ajouté v0.28.
3. **Async versus** = ajouté v0.28 également, mais **async MATCHMAKING** (tours programmés,
   timer 2min-3 jours), distinct de Arena.

Source : superautopets.wiki.gg/wiki/Version_0.28 et superautopets.wiki.gg/wiki/Version_0.41.

**Ce que ça change** : quand la roadmap cite « SAP Arena » comme référence de notre modèle async
ranked, elle confond deux modes SAP. Notre modèle est plus proche de « SAP async versus » (builds
capturés = ghosts humains) que de « SAP Arena » (IA générées). **L'analogie SAP Arena est
paresseuse pour le ranked** — SAP Arena n'a jamais eu de ranked LP/ELO.

**Ce qui tient** : SAP Arena est la bonne référence pour la **boucle de run** (10V, casual, pas
de pénalité). Pour le **ranked async**, la référence correcte est SAP v0.41+ (ranked avec saisons,
ajout juillet 2025) qui montre que même SAP a eu besoin d'ajouter des saisons ranked APRÈS coup.
**Correction à apporter §6.1** : distinguer « SAP Arena (référence run-structure) » vs « SAP v0.41+
ranked (référence saisonnière) » dans les annotations de source.

### 4.2 — « Fresh Start Effect (Milkman 2014) = le reset −20 % LP suffit » (§6.3, rounds 3-8)

**Analogie incomplète.**

La recherche POE 2 (game-wisdom.com, mars 2026) est plus précise que Milkman 2014 sur ce qui
déclenche le Fresh Start en contexte de jeu compétitif :

> *"Standard offers stability and permanence. What it can't offer is the specific feeling of a
> shared fresh start — the moment when every player is at level one, the economy is genuinely
> open, and the new META is genuinely unknown."*

Le Fresh Start POE 2 exige **3 conditions simultanées** : (1) reset du progression, (2) nouvelles
règles méta, (3) INCERTITUDE PARTAGÉE (personne ne sait ce qui marche). Notre reset −20 % LP
+ Contrainte de Saison couvre (1) et (2). Mais (3) — l'incertitude partagée — est absente si
les joueurs savent déjà que « bleedSlow2x en S1 → build bleed ». La Contrainte de Saison n'est
pas secrète comme un patch POE 2.

**Ce que ça implique** : la Contrainte de Saison devrait être **annoncée** (comme POE 2 annonce
son patch), pas cachée, pour maximiser la période d'incertitude collective pré-saison. Un signal
dans l'écran pré-run S1→S2 : « LA SAISON DES SAIGNEMENTS COMMENCE — LES RÈGLES DU PUITS ONT
CHANGÉ ». C'est déjà dans le tableau i18n adopté (§4.8 round 8, ligne « Saison active ») — mais
**l'annonce doit précéder le début de saison, pas l'accompagner**. Une pré-annonce 24-48h avant
le reset maximise (3) : les joueurs spéculent ensemble sur l'impact du `bleedSlow2x`.

**Coût** : 0 mécanique. 1 clé i18n supplémentaire `ranked.season_preview` + logique de timing
(afficher si `days_to_season_end < 2`). Doc, 0 code maintenant.

### 4.3 — « LoL LP gain/loss = référence de calibrage » (§6.2 round 4, progression §2.1 round 8)

**Analogie doublement invalide — et LoL lui-même l'a admis.**

La roadmap a retiré TFT comme ancrage de calibrage en round 8 (progression §2.1) car les seuils
TFT sont set-dépendants. La même logique s'applique à LoL LP.

**Preuve directe** — LoL ranked 2025 post-mortem (leagueoflegends.com, mars 2026) :

> *"We hadn't taken a deep dive into our skill distributions in a while which led to some
> moderate rank inflation over the past few years. This led to a few issues, such as overcrowding
> of Master tier in some regions, drift of skill between the same rank in one region vs another."*
> Source : leagueoflegends.com/en-us/news/dev/dev-ranked-update-season-one-2025/

Et LoL ranked 2026 (mars 2026) : hard reset forcé des rangs Masters+ après des erreurs de
calibrage au début de saison — ce qui confirme que LoL lui-même n'a pas de calibrage stable.

**Conséquence pour nous** : ne jamais citer LoL comme référence de CALIBRAGE (ni TFT, même logique
round 8). La seule référence correcte est notre sim `tools/ladder_sim.lua` sur nos contraintes
propres. **§6.2 doit retirer toute mention de calibrage LoL** et se fonder uniquement sur la
cible « 1 tier/saison à 2-3 runs/semaine ».

---

## 5. Questions ouvertes nouvelles

### 5.1 [NOUVEAU litige #HH] — Profondeur du Puits : per-run ou record-saison ?

**Deux options** :
- **Per-run** : la Profondeur du Puits du RUN COURANT affiché dans le score-screen (« tu es
  descendu jusqu'au 7e cercle »). Contextuel, feedback immédiat.
- **Record-saison** : la Profondeur MAX cette saison, affiché dans le profil/pré-run (« ton
  record : 8e cercle »). Signal de progression sur la durée.

**Recommandation** : les DEUX, différents endroits. Per-run dans le score-screen
(feedback), record-saison dans le pré-run (motivation). **À trancher en spec P2 (doc, 0 code).**

### 5.2 [LITIGE #U RE-QUALIFIÉ] — Prérequis « axe résolu » déclenche-t-il un blocage P2 ?

Si bleed est la seule famille « résolue » avant P1/P2, et si S1 doit durer 3 semaines, la
Contrainte de Saison S1 = `bleedSlow2x` par défaut. Mais si le ladder bleed a lui-même des
dettes (ex. une future découverte d'axe), le prérequis pourrait bloquer la saison.

**Recommandation** : définir un **fallback absolu** — si aucune famille n'a d'axe « résolu »
documenté, la Contrainte de Saison S1 est un **modificateur de sigil pur** (ex. `lineSlow2x` :
les unités en formation Ligne ont +15 % vitesse) — indépendant de l'équilibrage des familles.
Les sigils sont structurellement stables (5 sigils, 0 dette connue en dehors du profil d'exposition
anneau). **Documenter ce fallback dans §8.0.**

### 5.3 [PRÉCISION litige #A] — `teamFlag` saisonnier ranked vs mesure `--meta-convergence`

Maintenu ouvert (acté round 8, ranked §5.3). **Clarification supplémentaire** : la mesure
`--meta-convergence` pour #A doit exclure non seulement les runs ranked avec `teamFlag`, mais
aussi les runs DAILY qui ont eu une contrainte familiale (ex. « Jour de Brûlure ») — celles-ci
biaiseraient aussi la convergence méta mesurée sur les runs normaux. **Note à ajouter dans la
spec P2 de `--meta-convergence`.**

### 5.4 [NOUVEAU] — Pré-annonce de la Contrainte de Saison : timing et da implication

Si on annonce la Contrainte de Saison 24-48h avant le reset (§4.2 ci-dessus), cela exige :
(a) que la Contrainte soit finalisée au moins 48h avant le reset — contrainte opérationnelle ;
(b) que la DA grimdark encadre l'annonce comme un « Présage » et non une communication corporate.
**À documenter comme Q_R9 dans §8.0 (pas bloquant, décision éditoriale).**

---

## 6. Tableau de synthèse des propositions

| Proposition | Section roadmap | Priorité | Coût |
|---|---|---|---|
| Prérequis « axe résolu » pour la Contrainte de Saison | §8.0 | **P2 — doc AVANT code** | 3 lignes dans `seed/decisions.md` |
| Profondeur du Puits (axe orthogonal mid-core) | §6.2 nouveau + §6.11 | **P2 — spec + RENDER** | 0 moteur, ~20 lignes IO + RENDER |
| Signal d'élan 3 runs dans le pré-run | §6.11 enrichi | **P2 — RENDER** | ~30 lignes, lit historique ranked |
| Modificateur LP transparent par contexte de pool | §6.2 enrichi | **P2.5** | ~15 lignes IO + RENDER, après baseline pool |
| Pré-annonce Contrainte de Saison (24-48h) | §8.0 | **P2 — doc** | 1 clé i18n + logique timing |
| Retirer LoL comme ancrage de calibrage (comme TFT round 8) | §6.2 | **P2 — doc** | 0 code |
| Corriger référence SAP Arena vs SAP ranked v0.41+ | §6.1 | **P2 — doc** | 0 code |
| Test Profondeur du Puits (golden run ranked 7 combats) | seed/tests.md | **P2 — zone sans test** | ~20 lignes test |
| Test modificateur LP (golden store famille-distribution) | seed/tests.md | **P2.5 — zone sans test** | ~15 lignes test |

---

## 7. Récapitulatif des litiges

| # | Litige | Statut R09 |
|---|---|---|
| **#A** | P1 types vs P2 ranked | Maintenu ; précision : exclure daily contrainte-famille de `--meta-convergence` en plus des runs ranked (§5.3) |
| **#GG** | Apex choc axe A/B vs D | Maintenu BLOQUANT. **Prérequis : choc NE PEUT PAS être la famille ciblée par la Contrainte de Saison tant que #GG non tranché** (§2.2, §3.4) |
| **#U** | Contrainte saison : famille sous-représentée vs bas win-rate | **RE-QUALIFIÉ** : les deux critères sont des symptômes ; le vrai critère = « axe résolu + plus grand écart potentiel/réel » (§2.2, §3.4). **Prérequis documenté dans §8.0 AVANT code P2.** |
| **#HH** | **NOUVEAU** : Profondeur du Puits — per-run vs record-saison ? | Ouvert. Recommandation §5.1 : les deux, différents endroits. |
| **#EE-ranked** | Scope seed daily : combat seul | **CONFIRMÉ** (SAP v0.47 daily mode confirme la séparation shop/combats). |
| **#BB** | Daily ranked vs unranked | **CLOS** (round 8 — conditionnel seed partagé, confirmé §1.2). |
| **#Y** | FIFO de saison au reset | Maintenu ouvert P2. |
| **#FF** | Interactions inter-familles MID | Maintenu (spec à évaluer après saturation). |
| **#AA** | Seuil VRR boutique | Maintenu (calibration P3). |
| **#X** | Relique contre-jeu méta | Maintenu ouvert P1.5b. |
| **#M** | Relique wide quantité vs arête | Maintenu ouvert P1.5b. |

**NEUFS ce round** : **#HH** (Profondeur du Puits per-run vs record-saison).
**CLOS** : aucun (pas d'assez de preuve concluante pour clore #U, seulement re-qualifié).
**RE-QUALIFIÉ** : **#U** (critère de Contrainte de Saison → prérequis « axe résolu »).

---

## 8. Ce qui s'est amélioré ce round (mesurable)

1. **3 analogies paresseuses corrigées** : SAP Arena ≠ SAP ranked v0.41+ (§4.1) ; Fresh
   Start Milkman incomplet sans incertitude partagée (§4.2) ; LoL comme ancrage de calibrage
   aussi invalide que TFT (§4.3 — cohérent avec l'adoption round 8 de progression §2.1).

2. **1 litige #U re-qualifié** : le débat « win-rate vs sous-représentation » était la mauvaise
   question ; le vrai critère est « axe résolu + écart potentiel/réel ». Ce re-cadrage évite
   la S1 avec `shockChain` (axe D non résolu, #GG bloquant).

3. **2 nouvelles dimensions de signal ranked** : Profondeur du Puits (compétence mid-run) et
   Signal d'élan 3 runs (motivation pré-queue). Les 8 rounds précédents n'avaient qu'une
   dimension de signal (LP). Ces deux ajouts répondent directement à la recherche Management
   Science 2026 (matchmaking dynamique considère l'historique récent, +4-6 % engagement).

4. **1 lacune de spec bouchée** : le modificateur LP transparent par contexte de pool (§3.1)
   répond à la critique §2.1 (grille fixe = mêmes LP quelle que soit la difficulté du pool) sans
   casser la grille existante (borne à ±1, jamais de pénalité). La proposition est compatible
   avec les 32 invariants et les 4 piliers.

5. **Sources plus récentes (2025-2026)** : EurekAlert/Management Science (juin 2026), LoL ranked
   post-mortem (mars 2026), POE 2 seasonal model (mars 2026), SAP v0.28/v0.41 (2023-2025). Le
   corpus est plus dense et plus directement pertinent que les rounds précédents.

---

## 9. Index des sources R09

| Affirmation | Source vérifiée |
|---|---|
| Matchmaking dynamique (historique récent) : +4-6 % engagement (Lichess 5.4M parties) | eurekalert.org/news-releases/1130401 (juin 2026) |
| Fairness = trust, pas seulement math : systèmes opaques perçus injustes même si corrects | fairgame.us/skill-based-matchmaking-fairness... (mai 2026) |
| POE 2 Fresh Start = 3 conditions : reset + nouvelles règles + INCERTITUDE PARTAGÉE | game-wisdom.com/general/design-philosophy-behind-poe-2... (mars 2026) |
| LoL rank inflation 2023-2026 : ancrage LP instable, hard reset Masters+ 2026 | leagueoflegends.com/en-us/news/dev/dev-ranked-2026/ (mars 2026) |
| SAP v0.28 : ranked ELO, async versus (modes distincts) | superautopets.wiki.gg/wiki/Version_0.28 (2023) |
| SAP v0.41 : ranked seasons ajoutées après coup (juillet 2025) | superautopets.wiki.gg/wiki/Version_0.41 (2025) |
| Leaderboard : personal best + rank concurrent = motivation maximale (Octalysis) | yukaichou.com/gamification-analysis/leaderboard-design... (avr. 2026) |
| 4 leviers ranked : progress visible / rewards imprévisibles / fairness / reset | seganerds.com (juin 2026, maintenu) |
| Kingdom Clash async PvP : fairness perceived = communication, pas math | pocketgamer.biz (juin 2026) |
| CHI 2026 : spécialisation vs flexibilité persistent malgré les incitations structurelles | dl.acm.org/doi/10.1145/3772318.3791411 (avr. 2026) |
| Leaderboard personal best = signal d'amélioration individuelle, réduit décrochage mid-core | kydagames.com/blog/designing-competitive-leaderboards-repeat-visits.html (avr. 2026) |
| Legionbound daily ranked : axe orthogonal de compétition quotidienne dans un roguelite | thebigbois.com/action/legionbound-review/ (mai 2026) |

---

*Produit le 2026-06-23. Lentille : ranked-competitive. Round 9/10.*
*Lecture seule du repo (aucun code modifié). N'édite que sous `docs/roadmap-lab/`.*
*Piliers respectés : async snapshots / sim déterministe seedée / DA grimdark / pixel art procédural.*
*32 invariants préservés : toutes les propositions sont doc/IO/RENDER ou décisions éditoriales.*
*Zones sans test nouvelles signalées : §3.1 (golden store famille-distribution → modificateur LP) ;*
*§3.3 (golden run ranked 7 combats → depth_record mis à jour) ; §3.2 (golden run ranked 3 issues → label élan).*
*1 litige neuf : #HH (Profondeur du Puits per-run vs record). 1 litige re-qualifié : #U.*
*3 analogies corrigées : SAP Arena vs ranked ; Fresh Start incomplète ; LoL LP ancrage invalide.*
