# Recherche game design — autobattlers (ancrage du design)

> Dissection de TFT, Backpack Battles, The Bazaar, Super Auto Pets, HS Battlegrounds et
> **Batomon Showdown**, vérifiée sur sources fiables. Sert de base au blueprint de `CLAUDE.md`.

## Résumé

L'autobattler à succès = **une boucle** : phase **boutique/build** (toutes les décisions :
acheter, reroll, positionner, combiner) → **combat 100 % auto** (spectateur). La profondeur ne
vient pas de l'input en combat mais de la **tension économique** et de la **découverte
combinatoire** des builds.

Deux clivages structurants pour un solo dev :
1. **Modèle de combat** : TFT/HS:BG/SAP utilisent le plus **simple** (unités tirent dans un
   ordre fixe, résolution auto) ; Backpack/The Bazaar utilisent une **timeline temps réel à
   cooldowns** (plus coûteuse).
2. **Async par snapshots** : SAP, Backpack, The Bazaar et **Batomon Showdown** évitent la netcode
   en stockant des **snapshots figés ("ghosts")** de builds réels, servis selon
   *progression + rang*, avec des **équipes IA** au démarrage. C'est le takeaway #1 : du
   « multijoueur » sans serveur temps réel, jouable hors-ligne.

**Batomon Showdown** est réel (dev solo "berrymint", 2026 — « Super Auto Pets en habits de
Pokémon Showdown »). Son addictivité = modèle async snapshot **sans timer** + gestion d'équipe
simple (6 monstres).

## 1. Boucle de base

Tous : **phase boutique/build → phase combat auto**, répété jusqu'à victoire/élimination.

| Jeu | Ce qu'on clique en build | Condition de victoire |
|---|---|---|
| TFT | acheter (boutique 5), reroll (2g), XP, drag sur grille 28 hex, items, vendre | dernier des 8 (100 PV) |
| HS:BG | acheter (3g), vendre (1g), reroll (1g), freeze, upgrade tavern, repositionner 7 | dernier des 8 (30 PV) |
| Super Auto Pets | acheter (3g), reroll (1g), freeze, ordonner 5, fusionner | 10 trophées avant 5 vies |
| Backpack Battles | boutique 5, drag+rotation sur grille spatiale, reroll, recettes | 10 victoires avant 5 défaites |
| The Bazaar | journée = 6 « heures », arranger 10 slots, upgrade/fuse | 10 victoires PvP avant Prestige 0 |
| Batomon Showdown | acheter Batomon, choisir Trainer, items, équipe de 6, reroll | 10 victoires avant fin des vies |

## 2. Économie (TFT & HS:BG = les deux pôles)

- **TFT (banque/intérêt)** : ~5 or/round ; **intérêt +1 par 10 or, plafonné +5** ; streaks
  +1/+2/+3 ; reroll 2g ; XP 4g→4XP ; combine 3→étoile.
- **HS:BG (tempo pur, pas de banque)** : **+1/tour plafonné 10, NON conservé** entre rounds ;
  **aucun intérêt** ; achat 3g/vente 1g/reroll 1g/freeze gratuit ; triple → doré.
- **SAP** : **10 or/tour fixe**, proche du modèle HS:BG.

Takeaway : l'intérêt (TFT) ajoute un axe stratégique mais une charge d'équilibrage. Le modèle
**+N/round sans report** (HS:BG/SAP) est nettement plus simple à implémenter/équilibrer et domine
les titres « simples-addictifs ».

## 3. Plateau & positionnement

- **TFT** : grille **28 hex**, positionnement très important (le plus coûteux à coder).
- **HS:BG/SAP/Bazaar/Backpack** : **slots linéaires** (7/5/10), bien plus simple. Backpack est
  l'exception : **grille 2D type Tetris** (forme/rotation/adjacence).

Takeaway : **slots ordonnés linéaires** (HS:BG/SAP) = positionnement signifiant à coût minimal.

## 4. Résolution du combat

- **(A) Ordre fixe / pas-à-pas — SIMPLE** : HS:BG/SAP, attaques gauche→droite, cible aléatoire ;
  seul RNG = flip d'ouverture + cible. Boucle déterministe sur deux tableaux + RNG seedé. **Le
  modèle le moins cher**, et prouvé addictif.
- **(B) Timeline temps réel à cooldowns — RICHE mais coûteux** : The Bazaar (cooldown en
  secondes, Haste/Slow/Freeze, Sandstorm à 30 s), Backpack (Heat/Cold, Fatigue à 17 s). Demande
  un moteur de simulation par frame + bookkeeping de cooldowns + bugs de boucles infinies
  documentés.

Takeaway : **l'ordre fixe HS:BG/SAP est de loin le plus simple** et donne déjà une grande
profondeur émergente. La timeline est un **piège de coût** pour un solo dev sauf si c'est
l'identité du jeu.

## 5. Synergies / identité de build

- **TFT — Traits** : 2–3 origines/classes par unité, paliers 2/4/6.
- **HS:BG — Tribus** : Murlocs/Démons/Mechs… identité mécanique, rotation par lobby.
- **SAP — Packs + chaînage d'abilities** déclenchées (début/faint/hurt).
- **Backpack — adjacence SPATIALE** (signature) + recettes de craft.
- **The Bazaar — types d'items + enchantements + synergie de cooldown**.

Takeaway : les **paliers de tags (tribus/traits)** = la profondeur par ligne de code la moins
chère (quelques tags comptés → gros effets). L'adjacence spatiale (Backpack) est unique mais
demande grille + forme + rotation + recettes.

## 6. Multijoueur async par snapshots — LE pattern critique

Quatre de ces jeux (SAP, Backpack, Bazaar, Batomon) sont **asynchrones** : on n'affronte jamais
un humain en direct.

**Mécanisme (constant)** :
1. En fin de build, le jeu **upload un snapshot figé** de ton plateau, clé = **progression
   (round/victoires)** + **rang**.
2. Un autre joueur à un point comparable reçoit ton snapshot comme adversaire (« ghost »). Le
   combat tourne en local ; le snapshot ne réagit pas.
3. Ton résultat n'affecte pas le joueur snapshoté. Un même snapshot peut servir à plusieurs ;
   tu n'affrontes jamais le tien.

**Spécifiques** :
- **SAP** : sélectionne un adversaire dans une base de plateaux d'autres joueurs **au même tour** ;
  **fallback IA si personne à ce tour** (cold-start résolu). Mode Versus = 1v1 async classé Elo.
- **Backpack Battles** (dev confirmé) : « on prend un adversaire de rang similaire au même point
  de la partie… pas de bots » ; matché par **progression (+ rang en classé)** ; **le client
  télécharge un lot de snapshots par patch → jouable hors-ligne** ; runs custom exclus du pool.
- **The Bazaar** : ghosts matchés par **numéro de jour** ; **ton ghost remplace celui que tu
  affrontes** dans le pool ; **pools séparés par mode** ; premiers ghosts plus faciles.
- **Batomon Showdown** : « multijoueur asynchrone… variété quasi infinie d'équipes de joueurs…
  pas de timer ».

**Pourquoi c'est le takeaway #1 pour un solo dev** :
- **Pas de netcode temps réel, pas de serveur de matchmaking, pas de seuil de concurrence.** Il
  faut juste : une table `{snapshot_blob, progress_bucket, rank_bucket, version}`, un endpoint
  d'upload, une requête « un snapshot aléatoire dans mon bucket ».
- **Cold-start = équipes IA** (SAP). **Versioning = tag de version** sur les snapshots (on cesse
  de servir les lignes périmées). **Pas de timer** → l'addictivité « encore une run ».

Une table Postgres/Supabase + deux endpoints = un MVP complet de ce système.

## 7. Rejouabilité depuis la simplicité

- **Boutiques randomisées** (adaptation à chaque run).
- **Découverte combinatoire** : peu d'unités/items, interactions par tags → espace de builds
  exponentiel.
- **Pools/packs rotatifs** (contestation TFT, packs SAP, tribus HS:BG) : meta mouvante sans code.
- **Snapshots = adversaires infiniment variés** par construction.
- **Ladders classés** : progression long terme par-dessus l'arc roguelike.
- **« Casser le jeu »** : laisser trouver des combos cassés = une feature (Batomon/Backpack).

## 8. Reliques cryptiques — précédents & pièges

**Précédents (effets découverts par le jeu)** :
- **Roguelikes (objets non identifiés)** : effet appris par l'usage. Précédent le plus profond.
- **Tunic** : tout le jeu = découverte des mécaniques via un manuel partiellement illisible
  (« la connaissance EST la progression »). Cycle : ignorance → connaissance (on sait que ça
  existe sans savoir quoi) → compréhension (« ça clique »).
- **Hades** : maîtrise méta acquise sur plusieurs runs. **Dark Souls** : lore cryptique pour le
  **thème**, pas pour cacher des mécaniques.

**Patterns** : objets **situationnellement** bons/mauvais (le test devient une vraie décision) ;
de mauvais objets doivent exister mais être parfois utiles ; assez d'objets pour ne pas « résoudre »
l'ID en une run.

**Pièges** : ID purement aléatoire → **frustration / learned helplessness** ; « burden of
knowledge » ; les wikis trivialisent (price-ID, quaff-ID).

**Pattern recommandé (Golden Krone Hotel) — « 1 parmi 3 »** : l'infobulle montre que la relique
est l'un de **trois** effets candidats (mêmes prix → immune au price-ID) → la loterie devient une
**décision informée**, et les candidats randomisés par run résistent au wiki. Solution la mieux
documentée au problème de frustration, et peu coûteuse.

## 9. SYNTHÈSE DE COHÉRENCE — blueprint retenu

> Contraintes : solo dev Lua/LÖVE peu expérimenté ; rejouabilité/profondeur émergente ; async
> par snapshots ; thème grimdark Cthulhu/PoE/Souls avec reliques cryptiques.

**« Économie SAP + combat ordre-fixe HS:BG + synergie tags Backpack-lite + matchmaking ghost The
Bazaar + reliques cryptiques 1-parmi-3 Golden Krone. »**

- **Combat** : **ordre fixe sur slots linéaires (5–7)**, déterministe + RNG seedé. Le moins cher,
  prouvé addictif. **PAS** la timeline temps réel (piège de coût). **PAS** la grille hex (explosion
  de complexité).
- **Positionnement** : slots ordonnés linéaires (+ triggers d'adjacence = saveur Backpack sans la
  machinerie 2D).
- **Économie** : or fixe/round, sans banque ni intérêt (le plus simple à équilibrer).
- **Synergies** : paliers de tags (factions Cthulhu : Culte, Noyés, Engeance, Pestiférés…).
- **Reliques** : 1-parmi-3 cryptique + **lore lisible permanent** une fois identifié (méta-progression).
- **Async** : snapshots `{relic_loadout, progress, rank, version}` + équipes IA seed + tag de
  version + **pas de timer**.
- **Run** : 10 victoires avant N défaites, boutique randomisée.

**Cohérent vs s'entrechoque** :

| Se marie | À éviter |
|---|---|
| éco SAP + combat ordre-fixe HS:BG | timeline temps réel sur slots (coût énorme, sans payoff) |
| slots linéaires + triggers d'adjacence | grille 2D + rotation + recettes Backpack |
| paliers de tags + factions Cthulhu | grille hex + mana + pathfinding TFT |
| snapshots + équipes IA + tag version | banque TFT + reliques + timeline tout en v1 (sur-scope) |
| reliques 1-parmi-3 + déblocage lore | objets non identifiés purement aléatoires |

**En une phrase** : *un autobattler grimdark sans timer où on draft une petite équipe en slots
ordonnés, le combat se résout en ordre fixe, des synergies de tags-factions définissent le build,
les reliques signature démarrent cryptiques (1-parmi-3) et deviennent du lore lisible permanent à
mesure qu'on les identifie, et chaque adversaire est le snapshot async d'une run réelle (IA au
démarrage, taggé par version) — implémentable en LÖVE avec une seule table Postgres.*

## Note

Tous les chiffres (cotes, or, paliers) sont patch-dépendants et dérivent. Ce sont les
**structures** (phases, combat ordre-fixe, snapshots async, paliers, intérêt-ou-non) qui sont
stables et sur lesquelles s'appuie le blueprint. Sources complètes : voir liens dans le corps.
