# Round 01 — Critique adversariale : lentille Ranked & Compétitif

> **Lentille** : MMR/ladder, saisons, leaderboards, intégrité async, ce qui pousse à grinder
> le ranked et enchaîner les runs.
>
> **Statut** : round 1/10 — attaque le brouillon v0 (`ROADMAP-draft.md`).
>
> **Garde-fous respectés** : lecture seule du repo. N'édite que sous `docs/roadmap-lab/`.
> Piliers intacts. Sources URL citées pour toute affirmation chiffrée.
>
> **Sources primaires mobilisées** :
> - `docs/roadmap-lab/competitive/{super-auto-pets,the-bazaar,tft,marvel-snap,backpack-battles,hs-battlegrounds,slay-the-spire,postmortems}.md`
> - `docs/roadmap-lab/ROADMAP-draft.md` (cible)
> - `docs/roadmap-lab/00-state.md` (ancrage canonique)
> - Recherche web (2025-2026) citée par URL

---

## 0. TL;DR du challenge

**Trois angles de désaccord sérieux sur la section §4 (ranked) du brouillon** : (1) la grille de
scoring `+3/+2/+1/0/−1` COPIE le Bazaar sans adapter ses fondements — le Bazaar lui-même a dû
la patcher deux fois parce qu'elle pilote les mauvais comportements ; (2) les floors anti-churn
sont présentés comme panacea mais ils *cassent* l'équité perçue à moyen terme — la recherche
sur TFT le prouve ; (3) le matchmaking par `rank_bucket` ne résout pas le vrai problème
d'intégrité async identifié dans le Bazaar en 2025. Un accord fort sur la priorité de la daily
seedée et sur le séquencement ranked-après-lisibilité.

---

## 1. Accords — et POURQUOI ils tiennent pour The Pit

### 1.1 L'unité de compétition = le run, pas le combat (§4.1 du brouillon)

**Accord fort.** Le raisonnement du brouillon est juste ET bien sourcé :

> « L'ELO classique ne s'applique pas à un run de 10 combats contre 10 snapshots »
> (super-auto-pets.md §8.4)

Confirmation de la recherche web : Backpack Battles (le seul autre autobattler async actif en
2025 avec un ranked fonctionnel) score exactement par **victoires dans le run** et non par combat
individuel. Le système de points est modulé par le rang courant — à Master il faut ~65 % de
win-rate pour *maintenir* le rang, pas monter
(steamcommunity.com/app/2427700/discussions/4290313152637001687/). C'est le même principe.

**Pourquoi ça tient pour nos contraintes** : notre snapshot n'est pas un adversaire conscient —
il ne peut pas s'adapter mi-run. Scorer un combat isolé serait scorer contre un fantôme figé
dont la puissance est corrélée au tier de build, pas à la décision adverse en temps réel.
Le run entier est la bonne granularité parce que c'est la décision *cumulative* de build qui
est scorée, pas un duel de positionnement isolé.

### 1.2 Daily seedée « Descente du Jour » = proposition la moins chère, la plus haute valeur (§5)

**Accord fort.** La convergence slay-the-spire.md §7.3 + balatro.md §7.9 est solide, et l'argument
architectural est irréfutable : `state.lua:startRun(seed)` supporte déjà l'injection (invariant
test #2). Le leaderboard éphémère 24h est l'anti-pattern des « top-5 intouchables »
(slay-the-spire.md §7.2).

**Pourquoi ça tient pour nos contraintes** : l'async pur est *optimal* pour la daily.
Contrairement à HS:BG daily (qui exige une session synchrone de N joueurs), notre daily peut
se jouer à 3h du matin sur 45 minutes. Zéro friction de session. Aucun concurrent async n'a
implémenté ça proprement avant v1 — c'est un différenciateur réel.

**Renforcement** : la daily est aussi le cold-start résolu pour le pool ranked. Les ghosts
de la daily (pré-sélectionnés le matin) constituent un pool de qualité contrôlée
(tier ≥ moyen, build humain réel) — au lieu de piocher aléatoirement dans le pool général
qui peut être peuplé de builds sub-optimaux early-run.

### 1.3 Bifurcation Unranked/Ranked (§4.5) + pools séparés

**Accord.** Le Bazaar a mis des mois à patcher ça, avec une communauté qui s'est plainte
explicitement du cross-contamination des pools
(steamcommunity.com/app/1617400/discussions/591781420376206105/) :
> « Going forward, players will only be matched with ghosts of players of their rank or lower »
> — patch Bazaar 2025 (thebazaargame.net/guides-news/how-does-matchmaking-work-in-the-bazaar)

Implémenter les pools séparés *dès v0.10* (avant d'avoir une base de joueurs) est le bon ordre.
Le coût est quasi nul (champ `mode` sur le snapshot, filtre dans `snapstore:serve`) ; le coût
de le rater est un ranked pollué par des ghosts unranked sub-optimaux dès le premier joueur.

### 1.4 Pas de decay d'activité avant une masse critique de joueurs

Le brouillon ne mentionne pas le decay — c'est correct. SAP a ajouté un decay à +1800 ELO après
7 jours d'inactivité (superautopets.wiki.gg/wiki/Version_history). **Pour The Pit solo dev, le
decay est une erreur prématurée** : avec une petite base de joueurs, le decay vide les hauts rangs
et crée une impression de jeu mort. À différer à v2 si et seulement si la base de joueurs le justifie.

---

## 2. Désaccords — avec recherche sourcée

### 2.1 DÉSACCORD MAJEUR — La grille de scoring `+3/+2/+1/0/−1` reproduit les bugs du Bazaar S1

Le brouillon (§4.2) propose :

| Résultat | Δ rating |
|---|---|
| Ascension 10-0/10-2 | +3 |
| Ascension 10-3/10-4 | +2 |
| Chute 7-9 victoires | +1 / 0 |
| Chute 4-6 victoires | 0 / −1 |
| Chute < 4 victoires | −1 |

Source citée : Bazaar S2 (the-bazaar.md §9.1). **Problème : cette grille est la grille S2,
APRÈS que le Bazaar ait corrigé la grille S1.** La grille S1 avait une pénalité à <4 wins qui
poussait les joueurs à jouer « safe build » pour sécuriser 4 wins. Bazaar a dû la supprimer
en S2 pour remettre la prise de risque au centre.

Mais la correction S2 a introduit un autre biais : sans pénalité à 0-3 wins, certains joueurs
enchaînent délibérément des runs courtes (< 4 wins) pour accumuler des données ou éviter le
risque de -1. Le problème est confirmé par les discussions Steam :
> « Matching players with similar daily win records could be abused if players intentionally
> lose to secure easier matches later »
> (steamcommunity.com/app/1617400/discussions/591781420376206105/)

**La grille du brouillon a le pire des deux** : le −1 pour <4 wins (= biais S1 vers le safe
play) + pas de bonus pour les 4-6 wins (= pas d'incentive à viser au-delà du plancher). Le
joueur rationnel joue pour ne jamais descendre sous 4 wins, pas pour viser l'ascension.

**Ce qui est faux dans l'analogie du brouillon** : le pourquoi psychologique du scoring Bazaar
*ne se transfère pas* à notre rythme. Le Bazaar vise 3+ runs/jour (30 jours = 60-90 runs/saison).
The Pit vise 2-3 runs/semaine (30 jours = 10-15 runs/saison). Avec seulement 10-15 runs,
**un seul −1 peut détruire l'impression de progression d'une semaine entière**. La valeur
de `STREAK_CAP=3` dans `state.lua` confirme déjà que le design valorise la régularité courte
plutôt que l'accumulation longue.

**Proposition de remplacement** (cf. §4 de ce document) : scoring asymétrique *sans pénalité*,
axé sur le gain seul, avec seuils d'écrémage plus stricts en haut rang — et la *pression*
vient du matchmaking, pas de la grille.

### 2.2 DÉSACCORD — Les floors sont présentés comme avantage sans analyser le coût d'équité perçue

Le brouillon (§4.3) adopte les floors (anti loss-aversion, « acquis identitaire ») sans analyser
leur pathologie documentée dans TFT. La source du brouillon (tft.md §5.2 / hs-battlegrounds.md §9)
décrit le mécanisme mais pas ses effets de bord.

**Ce que la recherche web révèle sur TFT floors** (immortalboost.com/blog/tft-ranked-system-explained/ ;
boosteria.org/guides/tft-lp-mmr-explained) :

> « When players cannot be demoted, their MMR will drop, meaning they will gain less LP for
> every win and more for every loss. » « Many TFT players feel confused by ranked because the
> game shows LP, but the system actually makes its biggest decisions using MMR, which gap
> creates almost every common ranked question. »

Autrement dit : les floors TFT créent un **double système caché** (LP visible vs MMR caché)
qui génère de la frustration et de la confusion. Des joueurs Gold avec un MMR Silver se voient
bloquer leur progression par un système qu'ils ne comprennent pas.

**Pourquoi c'est critique pour The Pit** : notre projet est solo dev, DA grimdark *cryptique*,
pixel art sans assets dessinés. La lisibilité est déjà un axe de risque (Artifact est mort de
l'opacité — postmortems.md §4.4). Un système de rank avec floors + MMR caché **double la charge
cognitive** sur un jeu dont la lisibilité est déjà un challenge. La décision §7 du 00-state.md
(reliques lisibles, leurres retirés) confirme que le design privilégie la clarté. Le ranked
doit suivre.

**Proposition de remplacement** : aucun floor — mais une **règle asymétrique de loss max par
saison** (ex. : on ne peut pas perdre plus de 2 tiers par saison, quelle que soit la dégringolade).
C'est psychologiquement proche (on ne peut pas tout perdre) mais transparent (la règle est lisible,
pas un MMR fantôme).

### 2.3 DÉSACCORD PARTIEL — Le `rank_bucket = floor(rating/500)` ne résout pas le vrai problème Bazaar

Le brouillon propose (§4.4) de filtrer les snapshots par `rank_bucket ≤ bucket joueur`. C'est
un progrès mais insuffisant pour deux raisons :

**Raison A — le bucket est trop grossier avec un petit pool.** Avec 500 pts/bucket et un nouveau
jeu, les 5-10 premiers joueurs ranked sont tous dans le bucket 0. Filtrer par bucket 0 = aucun
filtrage effectif. Le Bazaar a eu ce problème exact : le matchmaking par rank au lancement
matchait tout le monde contre tout le monde faute de volume (steamcommunity.com/app/1617400/
discussions/591780546280023348/). Solution : **fallback tiered** — si le bucket ≥ joueur est
vide, descendre d'un bucket (bucket 0 si nécessaire), pas remonter. L'IA cold-start reste le
dernier filet (déjà garanti : `serveComp`, 00-state.md §5).

**Raison B — le bucket ne capte pas la progression intra-run.** Un joueur ranked bucket 2 qui
en est à son 3e combat (build partiel) affronte un ghost bucket 2 capturé à son 10e combat
(build complet). Ce décalage crée de la frustration injustifiée. La bonne solution :
**matcher par (bucket, wins_actuels)** — exactement comme le Bazaar match par (rank, day_record).
Le snapshot capture déjà les `units` mais pas les `wins_at_capture` — à ajouter au format.

**Ce qui est correct dans le brouillon** : l'idée de `rank_bucket` est le bon outil, juste
sous-spécifiée. La zone sans test (00-state.md §8 : « matchmaking rang ») reste identifiée
correctement — il faudra ajouter un test.

### 2.4 DÉSACCORD MINEUR — Rating par sigil (Litige #C) : la réponse devrait être tranchée ici

Le brouillon laisse le litige #C (rating global vs rating par sigil) ouvert « à trancher en
round ». Voici la réponse issue de la recherche :

**Contre le rating par sigil** : Backpack Battles n'a pas de rating par classe — un seul rating
global (estnn.com/backpack-battles-ranks-guide/). Hades a le Heat par arme, mais Hades est un
roguelite solo ; la comparaison ne tient pas pour un système de ranking de run.

**Argument décisif** : avec 2-3 runs/semaine, fragmenter en 5 ratings (un par sigil) = un joueur
actif a besoin de 5-10 semaines pour avoir un rating significatif sur *un seul* sigil. C'est
le moyen le plus sûr de rendre le ranked inexploitable à court terme. **Rating global, un seul,
point.**

L'incentive à varier les sigils vient d'ailleurs : de la daily (seed du jour peut favoriser
un archétype) et de la méta communautaire — pas du rating fragmenté.

---

## 3. Propositions priorisées (ranked-competitive, The Pit)

### P1 — Grille de scoring asymétrique sans pénalité (remplace §4.2 du brouillon) [PRIORITÉ 1]

**Principe** : on *ne perd jamais* de points avec 0-5 wins. On gagne selon le palier atteint.
La pression vient du matchmaking (difficile de stagner à un bucket si on y reste) et des saisons
(reset partiel). Pas de pression sur le scoring lui-même.

**Grille proposée [PH — à valider via sim]** :

| Résultat du run | Δ rating | Justification |
|---|---|---|
| Ascension 10 victoires | **+4** | Signal fort, récompense le grind complet |
| Chute 8-9 victoires | **+2** | Presque là — mérite du crédit |
| Chute 6-7 victoires | **+1** | Mid-run sain |
| Chute 0-5 victoires | **0** | Pas de pénalité — le joueur essaie, il revient |

**Seuils d'écrémage par rang** : les hauts rangs ne gagnent +4 que si win-streak propre (0 vies
perdues en route). Les bas rangs gagnent +4 à toute ascension. Cet écrémage est *visible* et
lisible — pas un MMR caché.

**Pourquoi ça survit à nos contraintes** :
- 0 pénalité = 0 risk aversion = le joueur tente l'ascension même avec un build imparfait.
  C'est compatible avec le design « égalisateurs, pas gates » (00-state.md §0).
- Pilote le comportement voulu : viser 10 wins, pas éviter les <4.
- Compatible async/déterministe : le score est calculé sur le résultat final du run.

**Source de calibrage** : le modèle SAP post-v0.41 (saisons ajoutées juillet 2025) n'impose
pas de pénalité sur les runs courtes — seul le leaderboard filtre les meilleurs
(store.steampowered.com/news/app/1714040/view/535482242423588579/).

### P2 — Matchmaking par (bucket, wins_at_capture) avec fallback tiered [PRIORITÉ 1]

**Format du snapshot à étendre** :
```lua
-- Ajout au format snapshot.lua (src/net/snapshot.lua)
-- {version, tier, seed, shape, units, rank_bucket, wins_at_capture}
-- wins_at_capture = nombre de victoires du joueur au moment de la capture
```

**Logique de `serve` ranked** :
1. Chercher bucket == joueur.bucket ET wins_at_capture ±2 victoires (même stade de run).
2. Si vide → bucket == joueur.bucket (tous wins).
3. Si vide → bucket == joueur.bucket - 1 (un cran en dessous, jamais au-dessus).
4. Si vide → `serveComp` (IA, cold-start garanti).

**Pourquoi ça résout le décalage intra-run** : on affronte des builds capturés au même stade,
pas des builds end-game contre des builds early-game.

**Test à ajouter** (zone sans filet, 00-state.md §8) : round-trip snapshot avec `rank_bucket` +
`wins_at_capture` ; test que `serve` applique le fallback dans l'ordre ci-dessus.

### P3 — Saisons sans reset MMR + règle asymétrique de perte max [PRIORITÉ 2]

**Mécanisme** :
- MMR interne **jamais resetté** (HS:BG dual-rating, hs-battlegrounds.md §9).
- Rating visible **décroit de 20 % au reset saisonnier** (pas remis à zéro). Un joueur bucket 4
  repart à bucket 3 — visible, prévisible, pas mystérieux.
- Règle asymétrique : pendant une saison, on ne peut pas perdre plus d'un bucket total
  (protection douce, sans floor rigide). Si le joueur revient à son bucket de départ, les runs
  suivantes sont *toujours* du côté gain.
- **Cadence saisons** : 6-8 semaines (vs 4 semaines Bazaar). Avec 2-3 runs/semaine, une saison
  de 4 semaines = seulement 10-15 runs — insuffisant pour une narration de progression.
  6-8 semaines = 15-25 runs = une arc lisible.

**Pourquoi c'est meilleur que les floors** : la règle asymétrique est une *phrase lisible* :
« tu ne peux pas perdre plus d'un tier par saison ». Les floors TFT sont une *mécanique cachée*
avec MMR fantôme. Notre DA grimdark peut même habiller la règle : « Le Puits vous a retenu — vous
ne tombez pas plus bas que là d'où vous venez ».

### P4 — Ghost replacement + wins_at_capture dans le pool [PRIORITÉ 2]

Mécanisme directement emprunté au Bazaar (bazaar-builds.net/did-you-know-how-ghosts-work/) :
quand The Pit sert un ghost ranked, le snapshot du joueur courant *remplace* le ghost servi
dans le pool (FIFO). Résultat : le pool ranked tourne naturellement avec les nouvelles metas,
sans intervention.

Condition : uniquement en ranked (pool distinct), non en unranked. Évite la contamination des
pools (désaccord §2.3 accordé avec le brouillon).

**Coût** : modification de `snapstore:serve` (ajouter `store.save(currentSnapshot)` après
`store.serve`). Zone sans test (00-state.md §8) — ajouter un test de rotation FIFO.

### P5 — Scoring de la daily distinct du ranked [PRIORITÉ 2, livré avec §5 du brouillon]

Le brouillon (§5) propose d'utiliser « le même score » que §4.2 pour la daily. C'est
**une erreur** : la daily n'est pas une run ranked — c'est une compétition de leaderboard
quotidien éphémère. Le scoring doit mesurer *l'efficience*, pas juste le résultat :

**Proposition** : `daily_score = wins × (10 - lives_lost) × (1 + round(xp_spent / GOLD_PER_ROUND))`

- `wins × (10 - lives_lost)` : récompense l'ascension propre (10 wins avec 0 vies perdues = score max).
- `× (1 + facteur xp)` : récompense l'efficience économique (dépenser peu en XP tout en montant = bonus).
- Score 0 si chute (pas de leaderboard de défaite).

Ce scoring daily *ne remplace pas* le scoring ranked — il est calculé dans le RENDER (hors SIM,
aucun invariant touché). Le seed de run garantit que rejouer donne le même score (invariant #2).

**Pourquoi distinct** : si daily = même score que ranked, les joueurs optimisent le même
comportement dans les deux modes. La daily doit forcer une *stratégie différente* (efficience
> risque) pour rester un contenu à part.

---

## 4. Questions ouvertes (héritées + nouvelles)

1. **Litige #A (inversé ou confirmé)** : l'argument anti-ranked-tôt (contenu mince = méta
   solvée en une semaine) tient-il si la daily est implémentée simultanément ? La daily
   crée de la compétition *sans ranked permanent*, ce qui peut suffire pour la rétention
   early. Réponse suggérée : daily d'abord (P2bis §5 du brouillon), ranked 2-3 semaines
   après si la daily prouve l'engagement. Trancher en round 2.

2. **Calibrage de la grille P1** : à quel volume de runs la grille proposée (0/+1/+2/+4)
   se comporte-t-elle mal ? Simuler via `tools/sim.lua` en modélisant 100 saisons fictives
   avec win-rates distribués [0.3-0.8]. Vérifier que le médian du bucket progresse en
   ~8 semaines.

3. **Format du snapshot étendu** : `rank_bucket` + `wins_at_capture` = +2 champs. Aucun
   invariant snapshot existant touché (les invariants #18-21 portent sur les reliques, pas
   le format brut). Mais le round-trip test doit être ajouté (00-state.md §8 : zone sans
   filet). À spécifier en amont du code.

4. **Cadence saisonnière** : 6 ou 8 semaines ? Si les reliques G (sigils) arrivent en v0.12,
   chaque saison peut coïncider avec une rotation légère de sigil dominant — ce qui donne
   une raison *thématique* au reset visible du rating. À articuler.

5. **Fate event (§10 du brouillon)** : le Bazaar a confirmé que le Fate event à 0 prestige
   (the-bazaar.md §7.4) augmente l'engagement — mais The Pit a 5 vies (pas 20 prestige).
   Le Fate event à *1* vie restante (pas 0) serait plus juste en run court. À challenger
   en round 2 : dilue-t-il la tension des 5 vies ou la renforce-t-il ?

---

## 5. Synthèse du bilan par proposition du brouillon (§4)

| Proposition brouillon | Verdict | Action |
|---|---|---|
| Unité de compétition = run (§4.1) | ACCORD — mécanisme correct | Conserver tel quel |
| Grille scoring +3/+2/+1/0/−1 (§4.2) | DÉSACCORD — copie Bazaar S1+S2 sans adapter le rythme | Remplacer par grille P1 (0/+1/+2/+4 asymétrique) |
| Tiers nommés grimdark (§4.3) | ACCORD — purement cosmétique, coût nul | Conserver (noms à valider) |
| Floors anti-churn (§4.3) | DÉSACCORD — double système caché, non-lisible | Remplacer par règle asymétrique de perte max par saison |
| Reset saisonnier partiel (§4.3) | ACCORD PARTIEL — cadence trop courte (4 sem.) | Allonger à 6-8 semaines |
| Matchmaking rank_bucket (§4.4) | ACCORD PARTIEL — bonne idée, sous-spécifiée | Enrichir : (bucket, wins_at_capture) + fallback tiered |
| Bifurcation Unranked/Ranked (§4.5) | ACCORD — pools séparés dès v0.10 | Conserver, implémenter en premier |
| Daily seedée (§5) | ACCORD FORT — livrable avec ranked | Scorer différemment du ranked (P5 ci-dessus) |

---

## 6. Tableau de sources

| Affirmation | Source |
|---|---|
| Backpack Battles score par victoires de run, pas par combat | [steamcommunity.com/app/2427700/discussions/4290313152637001687](https://steamcommunity.com/app/2427700/discussions/4290313152637001687/) |
| Backpack Battles 8 tiers, ~65 % WR requis à Master | [estnn.com/backpack-battles-ranks-guide](https://estnn.com/backpack-battles-ranks-guide/) ; [thegamer.com/backpack-battles-ranks-explained-guide](https://www.thegamer.com/backpack-battles-ranks-explained-guide/) |
| Bazaar matchmaking abuse par lose intentionnel | [steamcommunity.com/app/1617400/discussions/591781420376206105](https://steamcommunity.com/app/1617400/discussions/591781420376206105/) |
| Bazaar patch 2025 : ghost rank ≤ joueur | [thebazaargame.net/guides-news/how-does-matchmaking-work-in-the-bazaar](https://www.thebazaargame.net/guides-news/how-does-matchmaking-work-in-the-bazaar) |
| Bazaar matchmaking chaotique (discussion Steam) | [steamcommunity.com/app/1617400/discussions/591780546280023348](https://steamcommunity.com/app/1617400/discussions/591780546280023348/) |
| TFT floors → MMR caché confus pour joueurs | [immortalboost.com/blog/tft-ranked-system-explained](https://immortalboost.com/blog/teamfight-tactics/ranked-system-explained/) ; [boosteria.org/guides/tft-lp-mmr-explained](https://boosteria.org/guides/tft-lp-mmr-explained-tft-ranked-really-works) |
| TFT no-demotion cross-tier | [dotesports.com/tft/news/how-does-tft-ranking-system-work](https://dotesports.com/tft/news/how-does-tft-ranking-system-work) |
| SAP saisons ajoutées v0.41, juillet 2025 | [superautopets.wiki.gg/wiki/Version_0.41](https://superautopets.wiki.gg/wiki/Version_0.41) ; [store.steampowered.com/news/app/1714040/view/535482242423588579](https://store.steampowered.com/news/app/1714040/view/535482242423588579/) |
| SAP decay 1800 ELO +10/day après 7j inactifs | [superautopets.wiki.gg/wiki/Version_history](https://superautopets.wiki.gg/wiki/Version_history) |
| Bazaar ghost replacement (FIFO) | bazaar-builds.net/did-you-know-how-ghosts-work/ (cité dans the-bazaar.md §8.1) |
| Bazaar S1 grille scoring pénalité <4 wins | thebazaarzone.com/season-2-patch-notes-2-0-0 (cité dans the-bazaar.md §9.2) |
| Bazaar S2 : suppression pénalité → builds plus risqués | thebazaarzone.com/season-2-guide/ (cité dans the-bazaar.md §9.2) |

---

*Produit le 2026-06-23. Lentille : ranked-competitive. Round 1/10. Lecture seule du repo.*
*Prochaine attaque suggérée : lentille unités/synergies (roster 83 unités, synergies par type,
double comptage inc% entre types DoT × reliques B × auras — litige #B du brouillon).*
