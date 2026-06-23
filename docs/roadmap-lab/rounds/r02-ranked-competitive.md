# Round 02 — Critique adversariale : lentille Ranked & Compétitif

> **Lentille** : MMR/ladder, saisons, leaderboards, intégrité async, ce qui pousse à grinder
> le ranked et enchaîner les runs.
>
> **Statut** : round 2/10 — challenge le brouillon v2 (`ROADMAP-draft.md` réécrit post-round 1)
> et la synthèse `round-01.md`. Le round 1 (lentille ranked) avait déjà fourni 5 désaccords
> sourcés qui ont été adoptés. Ce round cherche à CHALLENGER ce qui subsiste, combler les
> lacunes, et apporter des preuves nouvelles sur les points encore [PH] ou ouverts.
>
> **Sources primaires mobilisées** :
> - `docs/roadmap-lab/ROADMAP-draft.md` (v2, cible)
> - `docs/roadmap-lab/round-01.md` (synthèse actée)
> - `docs/roadmap-lab/rounds/r01-ranked-competitive.md` (ma propre critique R1)
> - `docs/roadmap-lab/competitive/{tft,marvel-snap,the-bazaar,super-auto-pets,backpack-battles}.md`
> - `docs/roadmap-lab/00-state.md` (ancrage canonique)
> - Recherche web 2025-2026 citée par URL
>
> **Garde-fous absolus** : lecture seule du repo. N'édite que sous `docs/roadmap-lab/`.
> Piliers intacts : async snapshots / sim déterministe seedée / DA grimdark / pixel art procédural.
> Sources citées par URL pour toute affirmation chiffrée.

---

## 0. TL;DR du challenge R02

**Deux nouvelles preuves factuelles majeures dépassent le round 1.** (1) Le scoring du Bazaar
**Season 2 (patch 2.0, mai 2025)** est plus nuancé que ce que le round 1 a critiqué — ce n'est
**pas la grille `+3/+2/+1/0/−1` S2** mais un système par paliers de wins **sans pénalité
explicite** structuré en brackets. La grille adoptée en `ROADMAP-draft.md §6.2` est donc
**mieux calibrée que sa propre référence** — mais elle n'est pas encore justifiée en termes
de *durée de montée* pour notre rythme de 2-3 runs/semaine. (2) Le **cold-start du pool
ranked est sous-estimé** : The Pit aura un pool de snapshots réels **quasi-vide au lancement**,
et la grille `+4/+2/+1/0` crée une asymétrie perverse qui pousse les joueurs à **farmer des
ascensions faciles contre l'IA** avant que le pool se remplisse. Ce problème n'est pas adressé
dans le brouillon.

Trois **accords profonds** que le round 1 n'a pas complètement justifiés sont solidifiés ici.
Deux **nouvelles propositions concrètes** : (A) une **baseline de vitesse de montée chiffrée**
pour valider la grille `+4/+2/+1/0` ; (B) un mécanisme **d'indexation du score ghost par
win-quality** (pas seulement wins_at_capture) pour résoudre l'intégrité async dès le lancement.

---

## 1. Accords — et POURQUOI ils tiennent à nos contraintes

### 1.1 L'unité de compétition = le run (confirmé, renforcé par preuve Bazaar S2)

**Accord fort, solidifié.** Le round 1 l'avait argumenté depuis SAP + Backpack. La recherche
Bazaar S2 (patch 2.0, mai 2025) confirme directement :

> « The rating calculation was updated to be based on Wins for the run, rather than PvP combat
> results. » — bazaar-builds.net/new-expansion-heal-rank-update-more-patch-2-0-0/ (mai 2025)

Bazaar est passé d'un scoring par *résultat de combat* à un scoring par *performance de run*
exactement comme notre brouillon le propose. Ce pivot est la validation empirique la plus forte
disponible : le jeu async le plus similaire au nôtre a convergé vers exactement notre modèle.

**Pourquoi ça tient à nos contraintes** : notre snapshot est figé à la capture ; affecter le
rating d'un combat individuel (victoire ou défaite contre un ghost précis) serait aberrant.
Un ghost de tier 1 battable au round 1 et un ghost de tier 5 en late-run sont incommensurables
à l'échelle d'un combat. Seul le run entier est la granularité juste.

### 1.2 Grille sans pénalité (accord maintenu, MAIS preuve Bazaar plus nuancée qu'annoncé)

**Accord maintenu sur le principe — mais la référence Bazaar du round 1 était partiellement
inexacte.** Le round 1 a décrit la grille Bazaar S2 comme `+3/+2/+1/0/−1` patchée. La réalité
de la patch 2.0 (mai 2025) est plus sophistiquée :

> **Scoring réel Bazaar S2** (screenrant.com/bazaar-how-to-play-ranked-ccg/) :
> - Bronze : 0-3 wins = 0 pts, 4-6 = 1 pt, 7-9 = 2 pts, 10 wins = 3 pts
> - Silver : 0-4 wins = 0 pts, 5-7 = 1 pt, 8-9 = 2 pts, 10 wins = 3 pts
> - Gold : 0-5 wins = 0 pts, 6-8 = 1 pt, 9 = 2 pts, 10 wins = 3 pts
> - Diamond : 0-6 wins = 0 pts, 7-9 = 1 pt, 10 wins = 2 pts

**C'est déjà un système sans pénalité, en brackets progressifs par rang.** La grille adoptée
en `ROADMAP-draft.md §6.2` (`+4/+2/+1/0`) **est donc cohérente avec l'état de l'art** du
seul concurrent async sérieux — et NON une copie de la S1 boguée. Le round 1 avait démonté
une référence incorrecte (la grille S1/S2 boguée). Cela affaiblit rétrospectivement l'acuité
de la critique, mais **valide la direction finale** : le brouillon v2 a convergé vers la même
structure que Bazaar S2 par des routes différentes.

**Ce qui reste à faire** (non résolu par cette vérification) : le brouillon garde ses valeurs
**[PH]** sans jamais les justifier en termes de vitesse de montée. Cf. §3.1.

### 1.3 Bifurcation ranked/unranked + pools séparés (accord fort, architecture validée)

**Accord fort, sans réserve.** La preuve Bazaar est catégorique : le matchmaking ranked
avec des ghosts de rang inférieur uniquement est une nécessité, et non un luxe :

> « Going forward, players will only be matched with ghosts of players of their rank or lower »
> — patch Bazaar 2025 (steamcommunity.com/app/1617400/discussions/0/591781420376206105/)

La pratique de contamination des pools (ghost unranked dans le ranked) **est documentée comme
un bug critique**. Implémenter les pools séparés dès v0.11 (avant d'avoir une base) est correct.
Le coût d'implémentation est marginal (champ `mode` sur le snapshot, filtrage dans `snapstore`).

**Adaptation supplémentaire pour The Pit** : dans Bazaar, un joueur peut devenir son propre
ghost (son build est capturé et servi aux autres). Notre `snapstore:save` fait déjà cela.
L'intégrité ranked repose sur le fait que **le snapshot capturé en ranked ne soit jamais servi
en unranked** (risque de dilution). → A documenter comme invariant de `snapstore`.

### 1.4 Pas de decay avant masse critique (accord, mais seuil non défini)

**Accord maintenu** — mais le round 1 n'a pas défini le seuil. SAP a ajouté le decay à +1800
ELO après une masse critique clairement large (`superautopets.wiki.gg/wiki/Version_history`).
Le brouillon dit « différer à v2 si la base de joueurs le justifie » sans seuil. Ce n'est pas
assez précis pour un solo dev qui doit décider. → Proposition §3.3.

### 1.5 Daily seedée = différenciateur async (accord renforcé par données StS)

**Accord fort.** La validité de la daily seeded est confirmée par les chiffres de Slay the
Spire (maintenant ~7 000 joueurs quotidiens 8 ans après launch — Roguelikes With the Best
Progression Systems, bullethaven.com/blog/BlogPost12, 2026) dont la Daily Climb est citée
comme le facteur de rétention #1 des joueurs long-terme. Pour un jeu async, la daily est
**le seul contenu qui crée une pression temporelle naturelle sans un serveur live**.

**Renforcement spécifique The Pit** : notre daily ne dépend pas d'un lobby ou d'un serveur
(invariant #2 : même seed → même run). Le cold-start du daily (ghosts pré-sélectionnés le
matin) peut être garanti via `serveComp` (fallback IA documenté) dès le jour 1.

---

## 2. Désaccords — avec recherche sourcée

### 2.1 DÉSACCORD MAJEUR — La grille `+4/+2/+1/0` n'est pas justifiée en vitesse de montée

**Le brouillon adopte la grille sans jamais calculer combien de runs il faut pour monter d'un tier.**

Voici le calcul manquant. Hypothèse : rythme 2 runs/semaine (utilisateur mid-core), saison 6-8
semaines = 12-16 runs max par saison. Grille brouillon [PH] :

| Résultat | Δ rating |
|---|---|
| Ascension 10V | +4 |
| Chute 8-9V | +2 |
| Chute 6-7V | +1 |
| Chute 0-5V | 0 |

Paliers de tier non définis [PH]. Supposons **20 pts pour monter d'un tier** (valeur arbitraire
non posée dans le brouillon). Pour un joueur à 50 % d'ascension (50 % des runs = +4, 50 % = 0),
le gain moyen par run = 2 pts. Il faut **10 runs = 5 semaines** pour monter d'un tier. Sur une
saison 6-8 sem. = 1 à 1,5 tiers de progression. C'est **lisible mais lent**.

Si 40 pts pour monter (comme TFT nécessite beaucoup de LP), un joueur moyen monte à **0.5 tier**
par saison — **ranked inexploitable**.

**Comparaison Bazaar S2** : 3 pts pour Bronze → Silver (score maximum par run = 3 pts).
Un seul run parfait = +3 pts → potentiellement 1 tier. Pour un joueur à 50 % de 10V,
montée Silver à Gold en ~6 runs (3 semaines). Accessible, pas trivial.

**Ce qui est faux dans le brouillon** : les valeurs `+4/+2/+1/0` **sont incompatibles entre
elles** sans définir la hauteur des paliers. Un `+4` max sur des paliers de 30 pts = slow
grind. Sur des paliers de 8 pts = rush trivial. **Ces deux paramètres doivent être définis
ensemble**, pas séparément. Or le brouillon ne pose aucun des deux.

**Source** : Marvel Snap nécessite 630 cubes nets pour passer de Iron à Infinite
(snapcomplete.com/faq/ranked-climb) ; la durée est calibrée précisément en fonction du cube
efficiency. Without the equivalent of «7 cubes per rank», notre grille est une coquille vide.

### 2.2 DÉSACCORD PARTIEL — Le cold-start du pool ranked est une menace existentielle non adressée

**Le brouillon §6.4 (matchmaking) décrit le fallback sur `serveComp` (IA) sans évaluer
l'impact psychologique d'un ranked contre l'IA.**

La recherche sur le cold-start des jeux compétitifs est sans ambiguïté :

> « A smaller player pool means wait times for matches increase and connections may not be
> as strong, which can compound to create a spiral effect. Lower skill players who consistently
> lose are likely to quit, and eventually only high-skilled players remain, creating an
> ecosystem worse overall. » — devforum.roblox.com/t/how-to-solve-cold-start-problem-in-competitive-games

Pour The Pit, ce problème est **amplified** par la grille `+4/+2/+1/0` :

**Le paradoxe de la grille sans-pénalité en cold-start** : avec un pool ranked vide, `serveComp`
(IA cold-start) est servi. Si l'IA est calibrée pour faire 50 % de win-rate au tier 1, le joueur
compétent au tier 1 gagne facilement → ascension fréquente → `+4` fréquents → montée rapide
**contre l'IA, pas contre des humains**. Le rang obtained against AI est non-représentatif.
Quand le pool humain se remplit, le joueur découvre qu'il est sur-ranké → chutes → **aucune pénalité
= il ne descend pas** → le ranked humain devient injouable car les tiers sont pollués par des
joueurs sur-rankés contre l'IA.

La grille Bazaar S2 a le même problème potentiel, mais Bazaar avait une base de players
suffisante dès son open beta (mars 2025 → august 2025 pivot Steam). Pour un **solo dev qui
lance**, c'est une menace réelle.

**Ce n'est pas un argument contre la grille sans-pénalité** — c'est un argument pour un mécanisme
de **calibration initiale différencié entre IA-adversaire et ghost-humain**. Cf. §3.2.

### 2.3 DÉSACCORD — L'indexation du snapshot par `wins_at_capture` seule est insuffisante

**Le brouillon §6.4 enrichit le snapshot avec `wins_at_capture` pour matcher par stade de run.**
C'est une amélioration validée. **Mais le `wins_at_capture` ne capture pas la qualité du build à
ce stade.**

Exemple concret : deux snapshots à `wins_at_capture = 5` dans le même bucket — l'un capturé
après 5 victoires consécutives contre des ghosts de tier 3 (build fort, unités leveled), l'autre
après 5 victoires difficiles contre des ghosts de tier 4 avec un build précaire. La confrontation
des deux builds au round 5 sera déséquilibrée **malgré le même stade de run**.

La vraie variable de matchmaking pour l'intégrité async n'est pas **combien de wins** mais
**avec quel investissement économique à ce stade** (or dépensé, niveau de boutique atteint,
slots débloqués). Le Bazaar matche par `(rank, day_record)` — le `day_record` encode l'**état
de progression intra-run** du ghost (il reflète les heures jouées, pas juste les PvP gagnés).

**Pour The Pit** : le snapshot contient déjà `tier` et `units` (avec levels). Une proxy simple
de la qualité du build est le **coût total de l'équipe** (`Σ rank × level_mult` pour toutes les
unités). Ce proxy est calculable sans modifier la SIM (lecture seule des données du snapshot).

**Risque d'analogie paresseuse** : l'agent précédent a proposé `wins_at_capture ±2` comme si
la granularité était suffisante. En async, le pool est trop petit pour que `±2 wins` soit
opérationnel : si on a 200 snapshots total et qu'on filtre sur `bucket == 1 AND wins ∈ [3,5]`,
on peut se retrouver avec **zéro résultat** et tomber directement au fallback IA. La proposition
est correcte en concept mais fragile en implémentation cold-start.

### 2.4 DÉSACCORD — Le score daily n'est pas suffisamment distinct en psychologie

**Le brouillon §6.6 propose `daily = wins × (10 − lives_lost) × (1 + ⌊xp_spent/GOLD_PER_ROUND⌋)`.**

La formule récompense l'efficience. Mais **les trois facteurs sont des proxys de la même chose**
(bien jouer le run), ce qui n'en fait pas une **compétition à part**. Une compétition daily doit
forcer une *stratégie différente* de la run ranked ordinaire pour créer de la valeur additionnelle.

**Analyse par composant** :
- `wins` : identique au ranked (maximiser les victoires).
- `(10 − lives_lost)` : encourage à ne pas perdre de vies, soit exactement ce que le ranked
  encourage aussi (ascension propre, §6.2 brouillon).
- `(1 + ⌊xp_spent/GOLD_PER_ROUND⌋)` : récompense de dépenser moins en XP, soit penalise la
  montée de tier de boutique — anti-stratégique en late-run, incohérent avec l'économie.

**Comparaison StS Daily** : le Daily Climb de StS impose une **seed fixe** qui peut inclure des
cards/reliques inhabituelles, forçant une adaptation de build non-standard. L'enjeu est
d'optimiser *dans des contraintes imposées par la seed* — pas juste d'être efficace.

**Pour The Pit** : la seed daily définit les ghosts adverses (quels builds tu affronte). La
vraie différenciation psychologique est de proposer des ghosts **thématiques** (tous les adversaires
de la daily d'aujourd'hui sont des builds burn → test de ton adaptation contre le burn). Cela
ne nécessite pas une formule de score complexe — juste un **score pur de runs ascensions** dans
le leaderboard éphémère, avec des adversaires curatorialement sélectionnés par thème seed.

Problème de la formule existante : elle est **calculable en avance** (le joueur peut anticiper
son score avant de jouer), ce qui réduit la surprise et l'engagement. Un score connu avant
la run = pas de leaderboard réel, juste une optimisation deterministique.

### 2.5 DÉSACCORD MINEUR — L'écrémage du rang « run propre (0 vie perdue) » est opaque

**Le brouillon §6.2** : « en haut rang, +4 seulement si run propre (0 vie perdue). » C'est
une bonne intention (écrémage élite), mais c'est une règle **conditionnelle cachée** : le
joueur haut-rang ne sait pas à l'avance si son run sera scoré +4 ou +2. Cela contredit
directement le principe de **lisibilité** (décision #7 de l'état) et l'argument lui-même
du round 1 contre les floors (« MMR caché = confusion »).

**La règle adoptée** est doublement problématique : (A) elle introduit un **MMR-like shadow
condition** que le joueur découvre après coup, (B) elle n'est calibrée pour aucun seuil de
rang défini ([PH] universel).

**Alternative lisible** : rendre la condition **explicite dans l'UI avant la run** : « Tu es
en Forsaken — seule une ascension sans perte de vie donne +4. » Lisible, même tension, sans
shadow condition.

---

## 3. Propositions priorisées

### P1 — Définir ENSEMBLE hauteur des paliers + grille de score [PRIORITÉ 1 — BLOQUE LE RESTE]

**Problème** : la grille `+4/+2/+1/0` est orpheline sans les paliers de progression.

**Proposition concrète** : calibrer à partir d'une vitesse-cible de montée.

**Cible psychologique de référence** : un joueur mid-core (2 runs/semaine, 50 % d'ascension)
doit percevoir une **progression d'environ 1 tier sur une saison 6-8 semaines**. C'est le
« sweet spot » : pas trivial (1 saison = 1 tier), pas frustrant (pas besoin de 3 saisons).

**Calcul** : 2 runs/sem × 7 sem = 14 runs. 50 % ascension = 7 ascensions × +4 = 28 pts
+ 7 chutes mitigées (mix +1/+2) ≈ 35 pts total sur la saison. Pour 1 tier en 35 pts →
**taille d'un tier = 35 pts**.

Vérification joueur hardcore (4 runs/sem, 70 % d'ascension) : 28 runs × 70 % × +4 = 78 pts.
En 35 pts/tier = **2,2 tiers** par saison → légèrement moins de 3 tiers de progression max.
Acceptable.

**Calibration recommandée [PH à valider via sim]** :
- Taille d'un palier tier : **30-40 pts** (dans la fourchette).
- Grille `+4/+2/+1/0` : compatible avec ce calibrage.
- Nombre de tiers : 5-6 (Crawler → Condemned → Forsaken → Damned → Pit-Born → Void).
  5 tiers × 35 pts = 175 pts = objectif d'un joueur engagé en ~2 saisons.

**Garde-fou** : rating = méta (IO hors SIM), aucun invariant SIM. Simulable via un script
`tools/ladder_sim.lua` indépendant (100 joueurs fictifs × N saisons, distribution win-rates).

**Source** : calibration analogue TFT 7 cubes/rang × 90 rangs = 630 cubes nets confirmée
coherente (snapcomplete.com/faq/ranked-climb) — notre système doit avoir la même rigueur.

### P2 — Mécanisme anti-contamination IA en cold-start [PRIORITÉ 1]

**Problème** : les runs ranked contre l'IA ne devraient pas scorer de la même façon que les
runs contre des ghosts humains.

**Proposition** : introduire un **flag `quality` dans le résultat de run** :
- `quality.human = true` si au moins 80 % des combats (rounds 1-10) étaient contre des
  ghosts humains (not IA).
- `quality.human = false` si la majorité étaient contre `serveComp`.

**Scoring différencié** :
- Run `quality.human = true` : grille normale (`+4/+2/+1/0`).
- Run `quality.human = false` : grille divisée par 2 (`+2/+1/0/0`), **avec notification UI**
  « progression partielle — pool humain insuffisant ».

**Psychologie** : transparent, pas punitif. Le joueur comprend pourquoi sa run vaut moins
et reçoit l'information que le pool manque de ghosts → incitation à jouer plus (contribuer
son propre snapshot).

**Architecture** : le flag `quality.human` est calculé dans `snapstore:serve` (déjà traçable
car `serve` retourne soit un snapshot humain soit `serveComp`). IO hors SIM. **Zone sans test**
(00-state.md §8) → ajouter test de tracking `human_ratio` par run.

**Pas de precedent direct** mais coherent avec la logique Bazaar : « matchmaking only below
your rank » — leur contrainte résout le problème en sens inverse (filtrer les adversaires)
là où nous proposons de peser le résultat.

### P3 — Substituer `wins_at_capture` par `build_cost_proxy` dans le snapshot [PRIORITÉ 2]

**Problème** : `wins_at_capture` est un proxy trop grossier de la force du build à un stade.

**Proposition** : remplacer (ou compléter) par `build_cost_proxy = Σ(unit.rank × LEVEL_MULT[unit.level])`
calculé à la capture. Valeur typique : une équipe T3-T4 à 3 slots niveau 1 → proxy ~12 ;
une équipe T4-T5 à 7 slots niveau 2 → proxy ~60.

**Matching** : `serve` ranked cherche d'abord `bucket == joueur AND |build_cost_proxy - joueur.proxy| ≤ 15`
avant de se rabattre sur `wins_at_capture ±2`.

**Pourquoi plus fiable** : le build_cost_proxy encode à la fois le rang des unités, leur
niveau (investissement) et leur nombre (slots débloqués). Il est nettement plus représentatif
de la « force du ghost » que le seul nombre de victoires.

**Calcul** : lecture de `snapshot.units` (déjà capturé). Pure calcul au moment du `serve`,
pas d'impact sur la SIM ni sur l'encodage du snapshot. Aucun invariant touché.

**Risque** : ajoute 1 champ au snapshot si on veut éviter le calcul à chaque `serve`. À
peser selon la taille du pool (si pool < 500, le calcul dynamique est acceptable).

### P4 — Daily : adversaires thématiques seedés + score binaire run-complet [PRIORITÉ 2]

**Problème** : la formule `wins × (10 − lives_lost) × (1 + xp)` n'est pas suffisamment
différenciante psychologiquement et est calculable a priori.

**Proposition revisée** :

**Adversaires curatoriaux** : la seed du jour définit une **famille thématique** pour les
ghosts (ex : seed 20260621 → adversaires majoritairement burn, seed 20260622 → adversaires
majoritairement poison). Pas de changement de code — juste une pondération dans
`snapstore:serve` de la daily sur le `dominant_dot` des snapshots capturables.

**Score simplifié** : `daily_score = runs_ascended_today × (TIER_BONUS_MULTIPLIER)`. Où
`TIER_BONUS_MULTIPLIER = 1.0` pour Crawlers, `1.1` pour Condemned, etc. Le score valide le
run entier (ascension uniquement), pas l'efficience.

**Pourquoi plus distinct** : le leaderboard quotidien se remplit d'ascensions (binaire),
et le classement interne est fait par vitesse (l'heure de complétion de l'ascension ?) ou
par le nombre d'ascensions dans la journée (pour les très bons). **C'est une épreuve de
vitesse, pas d'efficience** — compétition entièrement différente du ranked (persévérance).

**Garde-fou** : `TIER_BONUS_MULTIPLIER` = nuance cosmétique hors SIM (bonus de leaderboard,
pas de stats) → 0 invariant. Score calculé dans RENDER (invariant #2 garantit la reproductibilité).

### P5 — Préciser la règle d'écrémage élite [PRIORITÉ 3]

**Problème** : la condition « run propre (0 vie perdue) = +4 en haut rang » est opaque.

**Proposition** : la condition est **affichée avant la run** selon le tier du joueur.

**Règle proposée** (avec texte UI grimdark) :
- Tiers 1-3 (Crawler/Condemned/Forsaken) : toute ascension = +4.
- Tiers 4-5 (Damned/Pit-Born) : ascension avec ≤1 vie perdue = +4 ; avec 2-3 vies perdues = +2.
- Tier 6 (Void) : ascension parfaite (0 vie perdue) = +4 ; sinon +2.

**UI** : dans le menu de run, afficher « Condition du Puits [Tier actuel] : … ». Texte
grimdark, info complète. Aucun hidden condition.

**Psychologie** : la transparence augmente le FOMO positivement (le joueur *sait* qu'il
vise quelque chose de harder). Analogue aux « Stakes » de Balatro qui sont explicitement
annoncées avant la run (balatro.md §7.8).

---

## 4. Questions ouvertes (héritées + nouvelles)

### 4.1 [LITIGE #A — réactualisé] L'ordre P1 (types) vs P2 (ranked) dépend du cold-start

Le round 1 avait proposé de le trancher par la sim « compo dominante par sigil ». Je maintiens
ce critère **mais y ajoute** : si le cold-start ranked est un problème (pool quasi-vide),
alors un ranked trop tôt ne donne pas un signal valide de la méta. Les types (P1) en premier
**produisent du contenu et donc des snapshots diversifiés**, ce qui remplit le pool ranked plus
vite. → **Argument additionnel pour P1 avant P2**.

### 4.2 [QUESTION NOUVELLE] Combien de snapshots humains pour que le ranked soit perçu comme
« humain » ?

La proposition P2 (flag `quality.human`) nécessite un seuil. Je ne connais pas ce chiffre —
il dépend du volume de runs par joueur et du rythme d'adoption. Hypothèse de travail :
**>50 ghosts humains par tier** = pool suffisant pour 80 % des combats humains en serve
ranked. À mesurer dans les analytics (hors du scope du lab — à poser comme objectif de launch).

### 4.3 [QUESTION NOUVELLE] La daily thématique est-elle trop restrictive pour les petits
pools ?

Si la seed du jour filtre sur les snapshots burn et que le pool a < 20 snapshots burn,
la daily tombe sur `serveComp` trop souvent → perd son intérêt. Seuil de déclenchement
du filtrage thématique : **si pool thématique < 10 ghosts → seed générale sans filtre**
(fallback transparent). À spécifier dans `snapstore`.

### 4.4 [LITIGE #A2 maintenu] Dernier Souffle — à 0 ou 1 vie restante ?

Je ne reviens pas sur ce litige — il nécessite que la grille de score soit d'abord figée
(P1 de ce round). Le Dernier Souffle avec dette (relique désactivée 1 combat) est la proposition
la plus cohérente avec le design, mais ne pas le résoudre avant que les paliers soient connus.

### 4.5 [QUESTION NOUVELLE] Injection du seed daily dans un contexte multi-plateforme

La daily exige que tous les joueurs jouent le même seed le même jour. Notre `state.lua:startRun(seed)`
supporte cela (invariant #2). Mais : si le jeu est offline-first (LÖVE), le seed daily doit
être transmis au client sans serveur. Solution simple : **seed = hash de la date** (`os.time()`
tronqué au jour) calculé localement — même résultat partout le même jour, zero serveur.
Vérifier que `os.time()` dans LÖVE est fiable cross-plateforme (à confirmer sur love2d.org/wiki).

---

## 5. Synthèse du bilan par proposition du brouillon v2 (§6)

| Proposition v2 | Verdict R02 | Action |
|---|---|---|
| L'unité = le run (§6.1) | ACCORD RENFORCÉ — Bazaar S2 confirme empiriquement | Conserver ; citer Bazaar S2 patch 2.0 |
| Grille `+4/+2/+1/0` (§6.2) | ACCORD mais INCOMPLET — paliers manquants | **Ajouter calibration en P1 (§3.1)** |
| Écrémage run propre hauts rangs (§6.2) | DÉSACCORD partiel — opaque | **Rendre visible avant la run (§3 P5)** |
| Tiers nommés grimdark (§6.3) | ACCORD — cosmétique, pas de changement | Conserver |
| No-floor + règle 1 tier/saison (§6.3) | ACCORD FORT — plus lisible que floors TFT | Conserver |
| Reset −20 % (§6.3) | ACCORD — compatible avec Bazaar S2 reset | Conserver |
| Matchmaking (bucket, wins_at_capture) (§6.4) | ACCORD PARTIEL — insuffisant en cold-start | **Enrichir avec build_cost_proxy (§3 P3)** |
| Pool séparés ranked/unranked (§6.5) | ACCORD FORT — validé Bazaar | Conserver ; documenter invariant snapstore |
| Ghost replacement FIFO (§6.5) | ACCORD — valide en pool ranked uniquement | Conserver |
| Daily score `wins × (10-lives) × (1+xp)` (§6.6) | DÉSACCORD — pas assez différenciant | **Remplacer par score binaire + thème seed (§3 P4)** |
| Codex des synergies (§6.7) | ACCORD — 0 invariant, hors ranked direct | Conserver |

---

## 6. Tableau des sources R02

| Affirmation | Source |
|---|---|
| Bazaar S2 patch 2.0 : scoring basé sur les wins du run (pas les combats PvP) | [bazaar-builds.net/new-expansion-heal-rank-update-more-patch-2-0-0/](https://bazaar-builds.net/new-expansion-heal-rank-update-more-patch-2-0-0/) |
| Bazaar S2 grille complète (Bronze/Silver/Gold/Diamond en brackets) | [screenrant.com/bazaar-how-to-play-ranked-ccg/](https://screenrant.com/bazaar-how-to-play-ranked-ccg/) |
| Bazaar patch ranked : ghosts de rang ≤ joueur uniquement | [steamcommunity.com/app/1617400/discussions/0/591781420376206105/](https://steamcommunity.com/app/1617400/discussions/0/591781420376206105/) |
| Bazaar : préstige perdu = numéro du jour de défaite | [mobalytics.gg/the-bazaar/guides/prestige](https://mobalytics.gg/the-bazaar/guides/prestige) |
| TFT : 630 cubes nets Iron→Infinite, cube efficiency | [snapcomplete.com/faq/ranked-climb](https://snapcomplete.com/faq/ranked-climb) — source en contexte Marvel Snap mais analogue |
| Marvel Snap : reset saison avril 2025, tiers moins pénalisés | [marvelsnap.com/patch-notes-april-1-2025-kwoi0932j3ndi2/](https://marvelsnap.com/patch-notes-april-1-2025-kwoi0932j3ndi2/) |
| StS 8 ans et ~7000 joueurs/jour, daily climb = rétention #1 | [bullethaven.com/blog/BlogPost12_RoguelikesWiththeBestProgressionSystems2026](https://bullethaven.com/blog/BlogPost12_RoguelikesWiththeBestProgressionSystems2026) |
| Cold-start spiral dans les jeux compétitifs (pool réduit) | [devforum.roblox.com/t/how-to-solve-cold-start-problem-in-competitive-games/4649734](https://devforum.roblox.com/t/how-to-solve-cold-start-problem-in-competitive-games/4649734) |
| SAP cold-start : IA utilisée si pas de joueurs au même turn | [en.wikipedia.org/wiki/Super_Auto_Pets](https://en.wikipedia.org/wiki/Super_Auto_Pets) |
| Backpack Battles ranked : rating global, pas par classe | [steamcommunity.com/app/2427700/discussions/0/4290313152637001687/](https://steamcommunity.com/app/2427700/discussions/0/4290313152637001687/) |
| Marvel Snap Infinite leaderboard : cubes nets post-Infinite | [marvelsnap.helpshift.com/hc/en/3-marvel-snap/faq/30-how-do-ranks-work/](https://marvelsnap.helpshift.com/hc/en/3-marvel-snap/faq/30-how-do-ranks-work/) |
| Streaks + milestones réduisent churn 30J de 35 % | [plotline.so/blog/streaks-for-gamification-in-mobile-apps](https://www.plotline.so/blog/streaks-for-gamification-in-mobile-apps) |
| Roguelite daily seeded = même seed/niveaux pour tous | [rogueliker.com/guntouchables-interview/](https://rogueliker.com/guntouchables-interview/) |

---

*Produit le 2026-06-23. Lentille : ranked-competitive. Round 2/10.*
*Lecture seule du repo (aucun code modifié). N'édite que sous `docs/roadmap-lab/`.*
*Piliers respectés : async snapshots / sim déterministe seedée / DA grimdark / pixel art procédural.*
*32 invariants préservés (aucune modification SIM proposée — toutes les propositions sont IO hors SIM,
RENDER ou architecture de snapshot).*
