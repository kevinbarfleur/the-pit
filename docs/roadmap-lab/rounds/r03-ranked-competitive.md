# Round 03 — Critique adversariale : lentille Ranked & Compétitif

> **Lentille** : MMR/ladder, saisons, leaderboards, intégrité async, ce qui pousse à grinder
> le ranked et enchaîner les runs.
>
> **Statut** : round 3/10 — challenge le brouillon v3 (`ROADMAP-draft.md` post-round-2) et
> la synthèse `round-02.md`. Cette lentille a produit des critiques aux rounds 1 et 2 qui ont
> été largement adoptées. Ce round se concentre sur les **litiges encore ouverts** (#G axe choc,
> #H daily, #I grille-ranked, #A2 Dernier Souffle) et sur ce que le brouillon v3 continue de
> **sous-estimer ou de mal cadrer**.
>
> **Sources primaires mobilisées** :
> - `ROADMAP-draft.md` v3 (cible), `round-02.md` (synthèse), `00-state.md` (ancrage)
> - `rounds/r01-ranked-competitive.md`, `rounds/r02-ranked-competitive.md` (historique)
> - `competitive/{the-bazaar,marvel-snap,super-auto-pets,tft,backpack-battles,slay-the-spire}.md`
> - Recherche web 2025-2026 citée par URL
>
> **Garde-fous absolus** : lecture seule du repo. N'édite que sous `docs/roadmap-lab/`.
> Piliers intacts : async snapshots / sim déterministe seedée / DA grimdark / pixel art procédural.
> Sources citées par URL pour toute affirmation chiffrée.

---

## 0. TL;DR du challenge R03

**Trois angles d'attaque ce round.** (1) La grille `+4/+2/+1/0` avec paliers à ~35 pts
**est correctement calibrée en vitesse de montée mais psychologiquement mal architecturée** :
elle crée une zone de stagnation perçue massive (0 pts pour toute chute ≤5 victoires) qui
n'est pas compensée par le `season_wins` seul — les recherches sur le tilt et le ragequit
montrent que le vide de feedback intermédiaire est un facteur de churn documenté (Duradoni
et al. 2026, onlinelibrary.wiley.com). (2) Le **litige #H (daily)** est résoluble avec une
troisième option plus ancrée dans nos contraintes que les deux proposées — une option ignorée
par les deux rounds précédents. (3) Le **`build_cost_proxy`** (matchmaking) est un signal
**beaucoup plus volatil** que le brouillon ne le reconnaît, ce qui crée un problème d'intégrité
async différent et plus grave que le cold-start déjà documenté.

Un accord fort sur le principe général du ranked (unité = run, sans pénalité, pools séparés)
et une nuance sur le Dernier Souffle (#A2) que le brouillon n'a pas encore tranchée.

---

## 1. Accords — et POURQUOI ils tiennent à nos contraintes

### 1.1 L'unité de compétition est le run — ACCORD RÉAFFIRMÉ

**Accord fort, troisième confirmation.** La recherche web confirme que The Bazaar utilise
maintenant un score basé sur les wins par run ("the end goal of the game is to get ten
victories", screenrant.com/bazaar-how-to-play-ranked-ccg/). En cohérence avec les rounds
précédents, c'est le seul modèle cohérent avec notre architecture snapshot.

**Nuance nouvelle** : le Bazaar (screenrant, source vérifiée) a un rating basé sur la **moyenne
des wins par run** en rang Legendary ("rating between 0-1000 based on your average performance",
steamcommunity.com/app/1617400/discussions/0/601916423125834814/). C'est différent d'une accumulation
de points — c'est une **moyenne glissante**. Le brouillon accumule des points ; The Bazaar mesure
une moyenne. Ces deux systèmes ont des psychologies différentes (§2.2).

**Pourquoi l'accumulation de points tient pour The Pit** : la moyenne glissante du Bazaar exige
un volume suffisant de runs pour être stable (~15+ runs pour une moyenne significative). Avec
2-3 runs/semaine, 6-8 semaines = 12-24 runs — acceptable pour une moyenne, mais les premières
runs ont un poids disproportionné. **L'accumulation de points est plus lisible pour un volume
faible de runs**. Pas de re-challenger sur ce point. Accord maintenu.

### 1.2 Grille sans pénalité — ACCORD MAINTENU

**Accord fort.** Recherche web confirmée : Backpack Battles a un système avec **gain et perte
de points** ("you get less and less points the higher up you go", lawod.com/backpack-battles-ranking-system/).
Ce n'est **pas** le modèle que nous ciblons. À l'opposé, le Bazaar S2 = zéro pénalité (vérification
maintenue des rounds précédents).

**Apport nouveau** : la recherche sur les rangs compétitifs (Duradoni et al. 2026,
onlinelibrary.wiley.com) confirme que "rank becomes both a source of pride and a source of
frustration and anxiety about holding an important position" — **les pénalités amplifient l'anxiété**.
Pour The Pit (run court = rythme faible de points = chaque point compte), les pénalités
créeraient une aversion au risque exactement contraire à l'intention design (essayer des builds
risqués). Grille sans pénalité = décision correcte, renforcée par la recherche.

### 1.3 Pools séparés ranked/unranked — ACCORD MAINTENU

Backpack Battles a des matchmakings distincts (lawod.com, vérification directe 2025).
L'asymétrie "ghost ranked ne pollue pas unranked et vice-versa" est un invariant de conception,
déjà vérifiée aux rounds 1 et 2. Pas de nouveau challenge ici.

### 1.4 Daily seedée = différenciateur — ACCORD DE PRINCIPE, mais le FORMAT reste litige #H

**Accord sur le principe** : Slay the Spire 2 a son propre Daily Climb (bossdown.com/guides/
slay-the-spire-2-daily-climb-guide/) avec seed fixe, modifiers imposés, leaderboard éphémère.
Le format StS2 **force une adaptation** (modifiers changent la dynamique) — c'est exactement
ce qui manque aux deux options du litige #H. Voir §3.3 pour la proposition.

**Maths de la daily StS** (slay-the-spire.fandom.com/wiki/Daily_Challenge et Score) : le
score StS intègre des bonus pour des accomplissements spécifiques (pas seulement "survivre").
Ce n'est **pas** simplement `wins × (10-lives) × speed` — c'est un score composite de
conditions remplies. Implication pour litige #H : §3.3.

---

## 2. Désaccords — avec recherche sourcée

### 2.1 DÉSACCORD MAJEUR — La zone 0 pts (chutes ≤5 victoires) est un gouffre de rétention, pas un "non-problème"

**Le brouillon v3 §6.8 propose `season_wins` comme "remède principal du vide intermédiaire"**
avec la note que `COMPLETION_BONUS` est "optionnel". Je dispute que le `season_wins` seul
soit suffisant pour ce vide.

**Le vide est structurel, pas cosmétique.** La grille `+4/+2/+1/0` donne **0 à toute
chute ≤5 victoires**. Un joueur qui fait régulièrement 4-5 victoires (performance mid-core
honorable) reçoit 0 pts de rated progression **toute la saison**. Le `season_wins` lui donne
un chiffre visible ("37 victoires cette saison") mais **aucune valeur de comparaison interpersonnelle**
— ce n'est pas un leaderboard, c'est un journal personnel.

**Ce que la recherche dit** : la recherche sur les systèmes de rang en jeu (Duradoni et al.
2026, International Journal of Computer Games Technology, onlinelibrary.wiley.com/doi/10.1155/ijcg/8961143) :
"rank becomes a source of frustration and anxiety" quand les joueurs perçoivent que leur rang
"does not reflect their actual skill". Pour The Pit, un joueur à 4-5 wins réguliers qui voit
son rated stagnant à 0 pts pendant 3 semaines va percevoir **le système comme ne mesurant pas
son niveau réel** — même si son niveau s'améliore. La recherche sur le tilt (Journal of Applied
Sport Psychology 2025, tandfonline.com) identifie ce "tilt croissant sans signal" comme
précurseur du ragequit.

**L'analogie TFT éclaire le problème** : TFT distribue ~40-60 % des joueurs en Silver/Gold
(esportstales.com/teamfight-tactics/seasonal-rank-system-and-player-distribution) — la majeure
partie du joueurs perçoivent une progression régulière. Notre grille met **toute la zone
mid-core (4-5 wins)** à zéro rated pendant une saison entière. C'est une concentration de
frustration bien pire que TFT.

**La proposition du brouillon ne ferme pas le vide.** `season_wins` est un compteur privé.
Ce qui manque : un signal de **progression relative** pour les joueurs 4-5 wins. Voir §3.1.

### 2.2 DÉSACCORD PARTIEL — Le `build_cost_proxy` est un signal volatile qui peut activement nuire à l'intégrité

**Le brouillon v3 §6.4 propose `build_cost_proxy = Σ(rank × LEVEL_MULT[level])`** comme
critère de matchmaking ordonné pour mieux capturer la "qualité du build".

**Le problème** : le `build_cost_proxy` **varie massivement en cours de run** — et un snapshot
est capturé à un moment précis. Exemple concret avec nos constantes (`LEVEL_MULT = {1.0, 1.8, 3.0}`) :

| Build A (avant merge) | proxy |
|---|---|
| 5 unités rang-3 niveau-1 | 5 × 3 × 1.0 = **15** |
| 5 unités rang-3 niveau-2 | 5 × 3 × 1.8 = **27** |
| 5 unités rang-3 niveau-3 | 5 × 3 × 3.0 = **45** |

Un joueur capture son snapshot après ses 7 premières victoires avec un build à `proxy=15` (encore
en train de collecter les copies). Un autre a `proxy=45` à 5 victoires car il a eu de la chance
avec les doublons. Ils ont le même `wins_at_capture=5` mais un proxy **3× différent**. Le
filtre `proxy ±15` (brouillon §6.4) les met dans des pools différents — mais **le proxy 15 sera
45 deux rounds plus tard si les merges se font**. Le snapshot figé reflète un moment du build,
pas sa **puissance moyenne** sur la run.

**Conséquence** : le `build_cost_proxy` filtre par **état ponctuel de collecte**, pas par
qualité de joueur. Il crée une fausse précision qui **réduit le pool disponible** (aggravant
le cold-start) sans garantir une meilleure équité.

**Ce qui est correct dans le brouillon** : l'intention (enrichir `wins_at_capture`) est bonne.
Mais le proxy doit être plus stable. Voir §3.2 pour une alternative.

### 2.3 DÉSACCORD MINEUR — Le litige #H est mal cadré : les deux options proposées mesurent la même chose

**Le brouillon v3 §6.6 propose deux options** :
- **(a) Efficience par vitesse** : `daily = wins × (10−lives) × speed_mult`
- **(b) Binaire + thème seed** : score = ascensions du jour, ghosts thématiques

**Mon désaccord** : l'option (a) mesure "à quelle vitesse tu es bon" ; l'option (b) mesure
"es-tu bon ce jour-là". Les deux mesurent des **variantes du même comportement** (performance
sur une run) avec des scalings différents. Le brouillon a correctement identifié (dans le
rejection de `×(1+xp)`) que la formule daily doit mesurer quelque chose de **différent** du
ranked — mais ni (a) ni (b) n'y parviennent vraiment.

**La leçon de StS que le brouillon n'a pas tirée** : StS Daily (slay-the-spire.fandom.com/
wiki/Daily_Challenge) impose des **modifiers** (un ennemi aléatoire démarre en Elites, tous
les ennemis ont une rune, etc.) qui **forcent une adaptation**. Ce n'est pas juste "joue
proprement" — c'est "joue proprement **malgré X contrainte**". StS 2 a formalisé cela
(bossdown.com/guides/slay-the-spire-2-daily-climb-guide/). Voir §3.3.

### 2.4 DÉSACCORD — Le cold-start du pool ranked humain est mal résolu par `quality.human`

**Le brouillon v3 §6.5 propose le flag `quality.human`** : si <80 % de combats contre des
ghosts humains → grille /2. La logique est saine (ne pas sur-ranker des victoires contre l'IA).
Mais l'implémentation crée un **problème de transparence qui contredit le pilier lisibilité**.

**Problème A** : 80 % d'humains = 8 combats sur 10. Dans un run de 10 victoires avant 5
défaites (donc 10-15 combats), le seuil crée un **couperet non-prévisible** : le joueur ne
sait pas pendant la run si sa progression sera "complète" ou "divisée". Il ne le découvre
qu'à la fin. C'est un MMR-like shadow condition — exactement ce qu'on a rejeté pour les floors
TFT (round 1 §2.2 : "double système caché = confusion #1").

**Problème B** : le seuil 80 % peut être impossible à atteindre pendant des semaines si le
pool est vide. Le joueur compétent reçoit systématiquement une grille /2 non par son
comportement mais par **une contrainte structurelle hors de son contrôle**. La recherche
(leveluptalk.com/news/ranked-gaming-fun-frustrations/) confirme que les joueurs perçoivent
comme injuste ce qui est "hors de leur contrôle".

**Alternative** : voir §3.4. La solution n'est pas de pénaliser via la grille mais de
**signaler l'état du pool avant la run** et de laisser le joueur choisir.

---

## 3. Propositions priorisées

### P1 — Ajouter un "rang d'efficacité" sub-tier visible pour les 0-5 wins [PRIORITÉ 1]

**Problème** : vide de feedback pour la zone 0-5 victoires (§2.1).

**Proposition** : à l'intérieur de chaque tier, 3 "marques" (décoratives, pas de rated) basées
sur le **meilleur run de la saison** :
- **Aucune marque** : meilleur run ≤4 wins
- **Marque Survivant** (argent) : meilleur run 5-7 wins
- **Marque Forgé** (or) : meilleur run 8-9 wins
- **Marque Ascendant** (rouge) : ≥1 ascension cette saison

Ces marques sont **cosmétiques**, visibles sur le profil, **ne modifient pas le rated**. Elles
résolvent le vide de feedback sans complexifier la grille de rating.

**Pourquoi ça tient mieux que `season_wins` seul** : une marque est **comparative** (je suis
Forgé, mon collègue est Survivant) là où `season_wins` est privé. La comparaison sociale est
un moteur de grind documenté — même en récompenses cosmétiques (Duradoni et al. 2026).

**Psychologie** : le "pic de la saison" est un signal de compétence perçu — même sans progression
de tier, le joueur voit qu'il a progressé dans sa **meilleure performance**. C'est distinct de
la progression cumulée (points) et de la progression brute (`season_wins`).

**Architecture** : `best_run_wins` stocké dans le meta-state (IO hors SIM, même pattern que
`season_wins`). **0 invariant SIM.** Texte grimdark : "Survivant des Abysses / Forgé dans l'Abîme /
Ascendant du Puits".

**Garde-fou anti-complexity** : 3 marques seulement (pas 7 sous-tiers comme le LP gain TFT).
La comparaison sociale reste simple.

### P2 — Remplacer `build_cost_proxy` par `slot_tier_composite` [PRIORITÉ 1]

**Problème** : proxy volatile capturant un état de collecte instantané (§2.2).

**Proposition** : remplacer `build_cost_proxy` par un **`slot_tier_composite`** = `shopTier × slots_actifs_au_moment_de_capture`. Ce proxy mesure **l'avancement dans la run** (tier boutique atteint × slots ouverts), pas l'état de collecte des copies.

**Comparaison** :
| Mesure | Avantage | Inconvénient |
|---|---|---|
| `build_cost_proxy = Σ(rank × level)` | capture la force brute | volatile (merge possible juste après) |
| `wins_at_capture` | stade du run | ne capte pas la qualité |
| **`slot_tier_composite = shopTier × slots`** | **avancement stable** (shopTier et slots ne régressent pas) | moins précis sur la force des unités |

**Exemple** :
- Joueur A : shopTier=3, slots=6 → composite=18
- Joueur B : shopTier=4, slots=7 → composite=28
- Joueur C : shopTier=2, slots=4 → composite=8

Ce signal est **monotone croissant** dans une run (on ne redescend pas en tier boutique,
on n'enlève pas de slots). Il est donc **stable à la capture** et **informatif sur le stade**.

**Architecture** : calculé **au moment du snapshot** (`build_slot_tier` = nouveau champ, 1 entier).
Lecture dans `src/run/state.lua` (`shopTier` et `slots` = déjà des champs de `state`). **IO hors SIM.**
Matching : `bucket == joueur AND |slot_tier_composite - joueur.composite| ≤ 8` (seuil à calibrer).
Zone sans test → ajouter test de round-trip.

**Compatibilité** : `wins_at_capture` reste utile en critère secondaire. Le proxy remplace
uniquement le `build_cost_proxy` instable.

### P3 — Trancher le litige #H : option (c) = Contrainte du Jour seedée [PRIORITÉ 1]

**Problème** : les options (a) et (b) mesurent des variantes du même comportement (§2.3).

**Troisième option, ignorée des rounds précédents** :

**Option (c) — Contrainte du Jour** : la seed daily impose **une restriction mécanique**
active pendant toute la run daily. Exemples (calculés depuis la seed quotidienne) :
- **Jour de Brûlure** : seules les unités à `dot_family=burn` proposées en boutique (le reste
  disparaît du pool daily) — force un run mono-famille
- **Jour de l'Abîme** : reliques uniquement de catégorie D (défensives) — force un run
  défensif
- **Jour du Puits** : le sigil imposé = `anneau` (on ne peut pas changer via `[s]`)
- **Jour de Sacrifice** : chaque achat d'unité rang-4+ coûte +2 or (pression économique)

**Score** : `daily_score = wins × (10−lives)` — le scoring brut SAP. La contrainte **est** la
différenciation ; le score n'a pas besoin d'être complexe pour que la journée soit différente.

**Pourquoi c'est mécaniquement supérieur à (a) et (b)** :
- Option (a) [speed_mult] : tous jouent le même comportement, certains plus vite. Pas
  distinctif.
- Option (b) [ghosts thématiques] : les adversaires sont thématiques mais le joueur
  joue son build habituel. Pression distante.
- Option (c) **[contrainte active]** : le joueur *lui-même* est contraint — comme StS Daily
  avec ses modifiers. Il ne peut pas "juste mieux jouer son build habituel".

**Verdict de transférabilité** : les modifiers StS (slay-the-spire.fandom.com/wiki/Daily_Challenge)
survivent à nos contraintes async car :
1. La contrainte dérive **de la seed** (déterministe, invariant #2 préservé)
2. Elle ne touche **pas la SIM** — c'est un filtre sur `U.pool` dans la boutique ou un lock
   sur le sigil (RENDER + data, hors SIM)
3. Le leaderboard éphémère garde son sens car **tout le monde joue la même contrainte**

**Sous-question du litige #H (chute 8-9 wins)** : `speed_mult=0` vs `0.5`. Avec l'option (c),
la question disparaît : le score est `wins × (10−lives)`, pas de multiplicateur. Une chute à
8 wins score `8 × 5 = 40` (avec 0 vie perdue). Une ascension score `10 × 10 = 100`. Le
leaderboard daily distingue clairement les niveaux sans punir les quasi-ascensions à 0.

**Architecture** : `dailyConstraint = seedHash % #CONSTRAINTS` (seed du jour → contrainte fixe).
RENDER + modification du pool boutique (déjà paramétrable via `U.pool`). **0 invariant SIM.**
**Zone sans test** → test que la contrainte est identique pour la même date.

### P4 — Remplacer `quality.human` par un signal pré-run transparent [PRIORITÉ 2]

**Problème** : flag punitif découvert après la run, hors contrôle du joueur (§2.4).

**Proposition** : avant de démarrer une run ranked, afficher l'état actuel du pool :
- 🟢 **Pool Vivant** : "≥X ghosts humains disponibles à ton tier — progression complète"
- 🟡 **Pool Mince** : "≤Y ghosts humains — progression partielle, certains combats vs invocations"
- 🔴 **Puits Silencieux** : "Pool ranked vide — les Invocations répondent, la progression
  est différée" (unranked automatique, pas de scored)

Le joueur **choisit** : il peut annuler et jouer unranked, ou accepter le pool mince avec la
connaissance de la grille /2.

**Psychologie** : la transparence avant la décision est psychologiquement très différente
d'une pénalité découverte après. "Je sais que c'est moins bien" vs "j'ai perdu ce que je
croyais avoir gagné". La recherche (GameSpot/leveluptalk : "frustrations comes from things
outside player control") identifie précisément ce second cas comme un driver de churn.

**Architecture** : `snapstore:poolStatus(tier)` → retourne `{count, quality}`. RENDER pré-run,
IO hors SIM. **0 invariant SIM.**

---

## 4. Tranchage des litiges ouverts — positions du round 3

### 4.1 Litige #I — grille `+4/+2/+1/0` + hauteur des paliers + écrémage élite

**Position** : la grille est correcte et les ~35 pts/tier sont défendables (calculs des rounds
1 et 2 maintenus). Ce qui manque (§2.1 round 3) = **le vide mid-core**.

**Résolution proposée** : combiner grille `+4/+2/+1/0` + marques sub-tier (P1 §3.1) + écrémage
élite **explicite avant la run** (brouillon §6.2 adopté) = système complet lisible. Ces trois
éléments ensemble couvrent : la progression rated (points), le feedback intermédiaire (marques),
et la motivation élite (condition affichée avant).

**Calibrage** :
- `+4` pour ascension, tous tiers (condition d'écrémage affichée avant pour tiers 4-6)
- `+2` pour 8-9 wins
- `+1` pour 6-7 wins
- `0` pour ≤5 wins + marques sub-tier cosmétiques
- Palier ~35 pts/tier, 6 tiers grimdark (Crawler/Condemned/Forsaken/Damned/Pit-Born/Void)

**Outils de validation** : script `tools/ladder_sim.lua` (proposition round 2, confirmée) :
100 joueurs fictifs × N saisons, distribution des win-rates [0.3-0.8], mesurer que la zone
médiane (50 % d'ascension) monte d'environ 1 tier/saison.

### 4.2 Litige #H — daily

**Position** : adopter **l'option (c) Contrainte du Jour** comme format principal. Score
`wins × (10−lives)`, contrainte derivée de la seed.

**Contre-argument anticipé** (option b/round précédent) : "les ghosts thématiques sont plus
faciles à implémenter". Vrai — mais ils ne résolvent pas le problème de différenciation
psychologique (§2.3). La contrainte active est mécanique et requiert ~2-3 types de contraintes
à implémenter (filtre `U.pool` ou lock sigil) ; le coût reste faible.

**Implémentation minimale** : commencer avec 2 contraintes seulement (Jour de Brûlure = burn,
Jour de Puits = sigil imposé) pour valider le concept avant d'en ajouter.

### 4.3 Litige #A2 — Dernier Souffle

**Position** : le brouillon note "ne pas figer avant la grille de score + hauteur des paliers
figées". Les paliers étant maintenant défendables (~35 pts, §4.1), ce litige peut être tranché.

**Recommandation** : le Dernier Souffle doit exister et se déclencher **à 1 vie restante**
(pas à 0). Pourquoi 1 et pas 0 :
- À 0 vie, la prochaine défaite = game over. Le Fate event du Bazaar donne un boost à 0 Prestige
  (the-bazaar.md §7.1). **Mais The Pit a 5 vies, pas 20 Prestige** — la perte d'1 vie sur 5
  est beaucoup moins catastrophique que la perte de 1 prestige sur 0. Le Dernier Souffle à 0 vie
  = trop rare pour avoir un impact de rétention (combien de runs finissent vraiment à 0 vie et
  se remontent ?).
- À 1 vie, le joueur est sous **tension élevée mais pas désespéré** — le near-miss "je
  risque tout" est plus fort psychologiquement (Clark 2009 near-miss, cité dans the-bazaar.md §7.2).

**Forme** : une relique de tier 4 gratuite (une parmi 3, 1-parmi-3 déjà seedé et équitable)
habillée en "Le Puits vous donne une dernière chance". Cohérent avec le modèle existant, 0
nouvelle mécanique. La relique est dans la catégorie E (transformative), gardée de type
non-runOp pour ne pas toucher les invariants #20.

**Garde-fou** : la relique est seedée (déterminisme préservé). Elle ne modifie pas le snapshot
(capturé au build). **Zone sans test** → ajouter test que le Dernier Souffle se déclenche
exactement à `lives == 1`, avec le bon tirage seedé.

### 4.4 Litige #C — rating global vs par sigil (CLOS depuis round 1, CONFIRMÉ)

La recherche Backpack Battles (lawod.com/backpack-battles-ranking-system/ : "rating global,
pas par classe") confirme pour la troisième fois. Clos.

---

## 5. Questions ouvertes (héritées + nouvelles)

### 5.1 [NOUVEAU] Le Dernier Souffle doit-il aussi notifier à la fin de run ?

Le Dernier Souffle déclenché à 1 vie, si le joueur remonte et gagne, donne un "Ascension depuis
le Puits" mémorable. Faut-il une **mention spéciale dans l'écran de fin** ("Tu as frôlé l'Abîme
et survived") ? Coût nul (RENDER), valeur de mémorabilité. À articuler avec le "Moment du Run"
(P0 §2.6 du brouillon).

### 5.2 [NOUVEAU] La Contrainte du Jour quotidienne exige un calendrier éditorial

Si l'option (c) est retenue, la daily nécessite que les contraintes soient variées et ne se
répètent pas trop souvent. Avec ~5 contraintes candidates (burn, sigil imposé, défensif,
économique, bleed...), le cycle est ~5 jours. Est-ce suffisant ou faut-il 10-15 contraintes
pour éviter la répétition mécanique ?

### 5.3 [NOUVEAU] Les marques sub-tier doivent-elles se réinitialiser à chaque saison ?

Si les marques (Survivant/Forgé/Ascendant) se réinitialisent à chaque saison, elles créent
de la **pression de progression saisonnière** même pour les joueurs mid-core. Si elles sont
permanentes (meilleures performances historiques), elles deviennent un **journal de progression
à long terme**. Les deux ont leur valeur — à décider.

### 5.4 [Litige #I partiellement tranché — reste ouvert] Seuil de pool pour `quality.human`

La proposition P4 (signal pré-run transparent) remplace le flag punitif mais ne définit pas
les seuils X et Y ("pool vivant" vs "pool mince"). Ces seuils dépendent de la base de joueurs
réelle — hors scope du lab, à mesurer au launch.

### 5.5 [Hérité round 2] Nombre de snapshots humains pour 80 % de combats humains

Non résolu. Hypothèse de travail : >50 ghosts humains par tier = pool suffisant. Reste à
mesurer (hors scope lab).

---

## 6. Synthèse du bilan par proposition du brouillon v3 §6

| Proposition v3 | Verdict R03 | Action recommandée |
|---|---|---|
| Unité de compétition = run (§6.1) | ACCORD RÉAFFIRMÉ | Conserver |
| Grille `+4/+2/+1/0` (§6.2) | ACCORD avec COMPLÉMENT nécessaire | Ajouter marques sub-tier P1 (§3.1) |
| Écrémage élite explicite (§6.2) | ACCORD FORT | Conserver ; confirmer "avant la run" |
| Tiers nommés grimdark (§6.3) | ACCORD | Conserver |
| Règle perte max 1 tier/saison (§6.3) | ACCORD | Conserver |
| Reset −20 % saisonnier (§6.3) | ACCORD | Conserver |
| Matchmaking `build_cost_proxy` (§6.4) | DÉSACCORD — volatile | **Remplacer par `slot_tier_composite` (§3.2)** |
| Pools séparés + ghost replacement (§6.5) | ACCORD FORT | Conserver |
| `quality.human` flag (§6.5) | DÉSACCORD — opaque, punitif | **Remplacer par signal pré-run transparent (§3.4)** |
| Daily `wins × (10−lives) × speed_mult` (§6.6) | ACCORD PARTIEL (formule OK) | **Ajouter la Contrainte du Jour seedée (§3.3) — option (c)** |
| Codex bootstrappé (§6.7) | ACCORD | Conserver |
| `season_wins` perso (§6.8) | ACCORD PARTIEL — insuffisant seul | Compléter avec marques sub-tier (§3.1) |

---

## 7. Tableau des sources R03

| Affirmation | Source |
|---|---|
| The Bazaar Legendary rank = rating 0-1000 basé sur moyenne des wins | [steamcommunity.com/app/1617400/discussions/0/601916423125834814/](https://steamcommunity.com/app/1617400/discussions/0/601916423125834814/) |
| The Bazaar ranked scoring (screenrant, grille S2 sans pénalité) | [screenrant.com/bazaar-how-to-play-ranked-ccg/](https://screenrant.com/bazaar-how-to-play-ranked-ccg/) |
| Backpack Battles ranked = gain/perte de points, pas sans-pénalité | [lawod.com/backpack-battles-ranking-system/](https://www.lawod.com/backpack-battles-ranking-system/) |
| Rank = source d'anxiété et de frustration (Duradoni et al. 2026) | [onlinelibrary.wiley.com/doi/10.1155/ijcg/8961143](https://onlinelibrary.wiley.com/doi/10.1155/ijcg/8961143) |
| Tilt = décision irrationnelle par charge émotionnelle accumulée (J. Applied Sport Psychol. 2025) | [tandfonline.com/doi/full/10.1080/10413200.2025.2483688](https://www.tandfonline.com/doi/full/10.1080/10413200.2025.2483688) |
| Frustration ranked = choses hors contrôle du joueur | [leveluptalk.com/news/ranked-gaming-fun-frustrations/](https://leveluptalk.com/news/ranked-gaming-fun-frustrations/) |
| TFT distribution des rangs (Silver/Gold = majorité) | [esportstales.com/teamfight-tactics/seasonal-rank-system-and-player-distribution](https://www.esportstales.com/teamfight-tactics/seasonal-rank-system-and-player-distribution) |
| TFT : "système montre LP, les décisions sont prises par le MMR caché" | [boosteria.org/guides/tft-lp-mmr-explained](https://boosteria.org/guides/tft-lp-mmr-explained-tft-ranked-really-works) |
| StS Daily Climb : seed fixe + modifiers imposés = format core | [slay-the-spire.fandom.com/wiki/Daily_Challenge](https://slay-the-spire.fandom.com/wiki/Daily_Challenge) |
| StS 2 Daily Climb : modifiers, leaderboard éphémère | [bossdown.com/guides/slay-the-spire-2-daily-climb-guide/](https://bossdown.com/guides/slay-the-spire-2-daily-climb-guide/) |
| SAP Version 0.41 : ajout des saisons ranked, leaderboard mensuel | [superautopets.wiki.gg/wiki/Version_0.41](https://superautopets.wiki.gg/wiki/Version_0.41) |
| Near-miss comme amplificateur d'engagement (Clark 2009) | cité dans `competitive/the-bazaar.md §7.2` (Cognition 2009) |
| Marvel Snap : MMR caché, gains LP pilotés par écart MMR/rang visible | [boosteria.org/guides/tft-lp-mmr-explained](https://boosteria.org/guides/tft-lp-mmr-explained-tft-ranked-really-works) (analogue) ; [marvelsnap.helpshift.com/hc/en/3-marvel-snap/faq/30-how-do-ranks-work/](https://marvelsnap.helpshift.com/hc/en/3-marvel-snap/faq/30-how-do-ranks-work/) |
| SEGANERDS 2026 : ranked systems keep players coming back | [seganerds.com/2026/06/11/why-competitive-rank-systems-keep-players-coming-back-to-online-games/](https://www.seganerds.com/2026/06/11/why-competitive-rank-systems-keep-players-coming-back-to-online-games/) |

---

*Produit le 2026-06-23. Lentille : ranked-competitive. Round 3/10.*
*Lecture seule du repo (aucun code modifié). N'édite que sous `docs/roadmap-lab/`.*
*Piliers respectés : async snapshots / sim déterministe seedée / DA grimdark / pixel art procédural.*
*32 invariants préservés : marques sub-tier = IO + RENDER hors SIM ; `slot_tier_composite` = champ
snapshot lu depuis `state.lua` hors SIM ; Contrainte du Jour = filtre `U.pool` ou lock sigil en build
(RENDER/data) ; signal pré-run = RENDER. Aucune proposition ne touche `arena.lua`, `bus.lua` ou
les tests existants. Zones sans test nouvelles signalées : Dernier Souffle déclenchement exact à
`lives==1`, round-trip snapshot `slot_tier_composite`, Contrainte du Jour = même contrainte pour
même date.*
