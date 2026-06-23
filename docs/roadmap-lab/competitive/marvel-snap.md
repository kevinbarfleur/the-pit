# Marvel Snap — Analyse ultra-approfondie pour *The Pit*

> **Mandat** : teardown précis de chaque mécanisme clé → psychologie → maths chiffrées et sourcées →
> verdict de transférabilité à The Pit (async snapshots, run court 10 victoires, sim déterministe, grimdark).
> Démonter les analogies paresseuses. Citer chaque source avec URL.
>
> **Sources primaires** :
> - Helpshift officiel Marvel Snap : https://marvelsnap.helpshift.com/hc/en/3-marvel-snap/faq/
> - Ben Brode GDC 2023 talk : https://youtu.be/HjhsY2Zuo-c (YouTube, 231k vues)
> - MobileGamer.biz résumé GDC : https://mobilegamer.biz/second-dinners-ben-brode-reveals-marvel-snaps-recipe-for-success-literally/
> - Deconstructor of Fun — Définitive Deconstruction (2023) : https://www.deconstructoroffun.com/blog/2023/5/23/marvel-snap-the-definitive-deconstruction
> - Deconstructor of Fun — Why Snap became a hit (2022) : https://www.deconstructoroffun.com/blog/2022/11/24/marvel-snap-the-one-deconstruction-to-rule-them-all
> - Naavik — Meteoric Rise (2022) : https://naavik.co/digest/marvel-snap/
> - Naavik — Monetization Too Modest (2023) : https://naavik.co/digest/is-marvel-snap-monetization-too-modest/
> - Naavik — Card Acquisition 2023 : https://naavik.co/digest/marvel-snap-card-acquisition-spotlight-caches/
> - SnapComplete ranked data : https://snapcomplete.com/faq/ranked-climb
> - snap.fan maths Snap/retreat : https://snap.fan/guides/stay-or-go/
> - PlaySNAP.pro maths snapping : https://playsnap.pro/posts/fundamentals/Mental-Game-Pt-2/
> - Polygon retreat guide : https://www.polygon.com/guides/23584712/marvel-snap-increase-rank-when-to-retreat/
> - Eric Guan substack — Ancient Inspiration (doubling cube) : https://ericguan.substack.com/p/marvel-snaps-ancient-inspiration
> - Marvel Snap Zone — pool guide : https://marvelsnapzone.com/series/
> - Marvel Snap Fandom wiki — Collection Level : https://marvelsnap.fandom.com/wiki/Collection_Level
> - DualShockers — Pools explained : https://www.dualshockers.com/marvel-snap-collection-pools-series-explained/
> - Game Developer — Simultaneous turns : https://www.gamedeveloper.com/game-platforms/designers-don-t-sleep-on-marvel-snap-s-simultaneous-turns
> - ReverseNerf deconstruction (2022) : https://reversenerf.com/marvel-snap-steals-all-my-free-time-deconstruction/
> - snap.fan — FOMO analysis : https://snap.fan/news/does-marvel-snap-really-want-you-not-to-be-collection-complete/
> - snap.fan — Why so expensive : https://snap.fan/news/why-is-marvel-snap-so-expensive/
> - Marvel Snap Zone — location RNG meta : https://marvelsnapzone.com/how-location-rng-continues-to-influence-deckbuilding-and-meta-calls/
> - FourthLocation — Snap scenarios : https://www.fourthlocation.com/when-do-i-snap-snapping-scenarios-and-tips/

---

## 0. Ce que Marvel Snap EST et ce qu'il n'est PAS

Marvel Snap (Second Dinner, oct. 2022) est un CCG PvP **temps réel**, mobile-first, où deux joueurs
s'affrontent en 6 tours (3-5 minutes) pour contrôler 2 lieux sur 3. 10 cartes par deck, une seule
type de carte (pas de créatures distinctes des sorts), et un mécanisme de pari/bluff (le « Snap » = doublement
des enjeux) emprunté au backgammon. C'est la référence du genre pour « une partie courte, des parties
enchaînées, un ranked qui hook ».

**Analogie paresseuse à démonter d'emblée** : « Marvel Snap fait X, donc The Pit devrait faire X. »
Le danger : Snap est un **CCG PvP temps réel** avec une collection de cartes comme moteur rétentionnel.
The Pit est un **autobattler async** avec une boucle roguelite de 10 combats. Leurs méchanismes
psychologiques ont des *moteurs différents* même quand leur forme ressemble. Chaque section analyse
pourquoi le mécanisme fonctionne ; le verdict de transférabilité demande si ce *pourquoi* survit à nos
contraintes (async par snapshots, sim déterministe, run court, grimdark, solo dev Lua/LÖVE).

---

## 1. MÉCANISME #1 — Le Snap / Cube (doublement des enjeux)

### 1.1 Teardown précis

Chaque match commence à 1 cube. Chaque joueur peut presser « Snap » une fois ; le cube double au
tour suivant. Au tour final, le cube double automatiquement. Maximum : 8 cubes par match (1 → 2 → 4 →
8 si les deux joueurs snapent + auto-double final). Un joueur peut **Retreat** (se retirer) avant la
fin ; il perd le cube actuel mais pas ce qu'il aurait perdu en perdant.

Source : marvelsnap.helpshift.com/hc/en/3-marvel-snap/faq/28-what-is-snapping/

**États possibles :**

| Qui a snapé | Moment | Cubes en jeu |
|---|---|---|
| Personne | Avant final | 1 |
| Personne | Auto-double final | 2 |
| Un joueur | Après son snap | 2 |
| Un joueur + auto-double | Au final | 4 |
| Deux joueurs | Après 2e snap | 4 |
| Deux joueurs + auto-double | Au final | 8 |

### 1.2 Psychologie (sourcée)

Ben Brode (GDC 2023, mobilegamer.biz) : l'inspiration directe est **le doubling cube du backgammon**.
Deux effets psychologiques distincts, documentés :

**A. « Little Victories » pour le perdant** (GDC 2023, stevelilley.com résumé) :
Le joueur qui Retreat avant la fin n'a pas « perdu » — le message original « You Lose ! » a été changé en
« Escaped ! ». Brode : « It made losing feel like victory. It's a strategic retreat where you don't fall
victim to your opponent's gambit — you escaped! You're a genius! » La décision de se retirer à temps =
compétence démontrée → satisfaction intrinsèque même en situation de défaite.

Ce mécanisme s'appuie sur la théorie du « net joy » (concept Brode cité depuis Hearthstone veteran
Eric Dodds GDC 2014) : un jeu zero-sum génère zéro joie nette (une joie = une peine). Minimax des
pertes → minimax de la frustration.

**B. Bluffing / Information cachée** (ericguan.substack.com) :
La main adverse est cachée. Snaper peut signifier « j'ai les cartes qu'il me faut » ou bluffer pour
provoquer un Retreat. Poker-like. Brode GDC : « We tried 9 different variations of the doubling cube
mechanic before landing on the current one. »

**C. Variance organique des enjeux** (ericguan.substack.com) :
Dans la plupart des jeux compétitifs (LoL, chess), chaque game a exactement les mêmes enjeux. Les
matchs à promotion (passage silver → gold dans LoL) créent de l'intensité artificiellement. Le Snap crée
de l'**intensité organique imprévisible** : vous pouvez perdre 8 cubes d'un coup, ou enchaîner 8
victoires à 1 cube. « Some games will organically and unpredictably become higher-stakes. »

### 1.3 Maths chiffrées

**Équation de base** (snap.fan/guides/stay-or-go/) :

Soient `c` les cubes en jeu, `p` la probabilité estimée de victoire.

- **Auto-double final** (pas de snap précédent) : rester vaut mieux que Retreat si `p > 1/4` (25 %).
- **Snap adverse au final** : rester si `p > 3/8` (37.5 %).
- **Formule générale** (ericguan.substack.com) : le doubler optimal intervient quand `p_win > 50 %` (côté snappeur). Le receiver accepte si `p_win > 25 %`, retreat si `p_win < 25 %`.

**Impact sur le climbing** (playsnap.pro) :

Le matchmaking vise 50 % de win rate. Pourtant on peut grimper. Comment ?
> « One 4-cube win is enough to fund your next four retreats and still break even. »

Modèle cube efficiency :
- Victoire no-snap : +2 cubes (auto-double final). Défaite no-snap : -2 cubes. EV = 0 à 50 %.
- Si vous snappez early quand vous êtes à 70 % de win rate et que l'adversaire ne retreat pas : +4. S'il retreat : +2 (garantis).
- Si vous retreat early sur une main faible : -1 cube seulement.

Donc :
- **Win +4, Loss -1 (retreat)** → break-even à ~20 % win rate sur les matchs snappés.
- **Win +2, Loss -1** → break-even à ~33 % win rate.

Le cube efficiency > 1 est la clé du climbing, pas le win rate brut. Un joueur 50 % win rate avec
cube ratio 3:1 (gagne 3 cubes/victoire, perd 1/défaite) grimpe plus vite qu'un 55 % win rate avec ratio 1.5:1.

Source structure du cube : marvelsnap.helpshift.com/hc/en/3-marvel-snap/faq/95-what-do-cubes-do/

### 1.4 Verdict de transférabilité à The Pit

**Le « pourquoi » du Snap survit-il à nos contraintes ?**

Oui, partiellement — mais le mécanisme sous-jacent est DIFFÉRENT.

Le Snap fonctionne grâce à 3 conditions :
1. **Information asymétrique temps réel** (main cachée adverse = bluff possible).
2. **Agentivité immédiate** (décider de snapper ou non = compétence exprimée maintenant).
3. **Rétroaction instantanée** (le Retreat = résolution immédiate de la décision).

Ces 3 conditions sont **absentes** dans The Pit. Notre combat est **async, déterministe, résolu en une fois**. Il n'y a pas de main à bluffer, pas de snapping mid-combat, pas de retreat possible en cours de combat.

**Analogie directe = FAUSSE.** « Mettre un bouton Snap dans The Pit » n'activerait aucun des mécanismes psychologiques listés.

**Ce qui est transférable : l'objectif, pas la mécanique.**

Le Snap vise à :
- A. Transformer les défaites en « Escaped ! » (agentivité du perdant).
- B. Générer une variance d'enjeux organique (stakes variables).
- C. Créer une compétence visible autour des décisions de risque.

Dans notre contexte **async** :
- **A (Escaped)** : corollaire direct = **le concédé volontaire avant le combat**, aka refuser un matchup adverse connu. Un joueur peut « Retreat » avant de lancer le combat si le snapshot adverse est clairement contre-arqué. Le coût = perdre le round mais pas toutes ses vies. Psychologie identique : « je suis malin d'avoir reconnu que ce build countre le mien. » Mécanisme déjà possible avec notre boucle ; à rendre visible UI/framing.
- **B (stakes variables)** : corollaire = **les reliques comme amplificateur d'enjeux**. Quand une relique « Feeding Frenzy » (snowball au kill) est active, les stakes sont organiquement plus hauts. À terme, une relique-sigil pourrait explicitement « doubler les gains/pertes de cubes du round » — mais cela exige un système de ranked cube d'abord.
- **C (compétence de risque visible)** : aucun équivalent direct — notre combat est trop opaque mid-résolution pour une décision de risque consciente.

**Recommandation** : ne pas copier le Snap. Identifier l'objectif A (reframer la défaite en compétence) et créer un équivalent dans la boucle de run : le **concédé stratégique** avant combat + un message type « Sombre Sagesse — vous avez reconnu le danger à temps ».

---

## 2. MÉCANISME #2 — Les 3 Lieux (plateau à variabilité structurelle)

### 2.1 Teardown précis

Chaque match tire 3 lieux aléatoires parmi un pool de 200+ lieux, révélés progressivement
(tour 1, 2, 3). Chaque lieu a un effet unique qui modifie les règles localement (Muir Island :
+1 power/tour par carte jouée ; Bar Sinister : toutes les cartes jouées ici deviennent des copies de la
première ; Sanctum Sanctorum : on ne peut jouer aucune carte ici, etc.).

But : gagner 2 lieux sur 3 par puissance totale.

Source : deconstructoroffun.com definitive deconstruction ; gamedeveloper.com simultaneous turns article.

### 2.2 Psychologie (sourcée)

**A. Chaque partie comme « loot box »** (reversenerf.com) :
Tim Mannveille analogy : chaque game est une « loot box » en termes d'expérience. Les 3 lieux
définissent le terrain de jeu différemment à chaque fois. La combinaison de 3 lieux sur 200+ = variance
quasi infinie (si uniformément distribués : C(200,3) ≈ 1,3 million de combinaisons distinctes).

**B. Adaptabilité comme compétence** (marvelsnapzone.com location RNG meta) :
« Random locations force competitive ladder players to rethink core shells daily. » Les decks rigides
perdent face aux decks flexibles. La variabilité structurelle *récompense la flexibilité de build* plus
que l'optimisation à grain fin.

**C. Réfraîchissement de la méta** (GDC 2023, stevelilley.com résumé) :
« They prepped a lot of locations to slowly add to the game after launch, had different rates for locations
to change meta, and would swap out locations to also impact metas. » Nouveaux lieux = nouvelles synergies à
découvrir = renouvellement de la méta sans ajouter de nouvelles cartes.

### 2.3 Maths chiffrées

Pool de lieux : 200+ distincts (annoncés en 2022 avec plans d'expansion continue).
Taux de révélation : tour 1 (1er lieu), tour 3 (2e), tour début de partie invisible (3e révélé à tour 1 mais « foggy »).

Dans Snap, certains lieux ont des taux d'apparition non uniformes (certains exclus temporairement pour
équilibrage). L'équipe « swaps out locations to impact metas ».

**Impact du nombre de lieux sur la diversité de méta** : les analyses théoriques (leriohub.com « Endgame »)
montrent que sur 3 lieux à points, la décision finale dépend du spread de puissance entre lieux —
générant une analyse combinatoire profonde même avec une mécanique très simple (on ne cible pas les
cartes adverses, pas de destruction, juste du positionnement power).

### 2.4 Verdict de transférabilité à The Pit

**Très fort — le mécanisme coeur est déjà IMPLÉMENTÉ.**

Ce que Snap fait avec ses 3 lieux, The Pit le fait avec ses **5 sigils** (carré/croix/anneau/diamant/ligne).
Chaque sigil = une topologie différente = un archétype différent = un plateau structurellement distinct.
La forme EST le graphe de synergies. Le centre du carré (4 voisins) = la case carry. L'anneau = propagation
en boucle. La ligne = conduit front/back.

**La différence structurelle :** dans Snap, les 3 lieux sont **sélectionnés aléatoirement** à chaque match,
indépendamment des decks des deux joueurs. Dans The Pit, le sigil est **choisi par le joueur** (bascule [s])
et persiste tout le run. C'est une différence de design majeure.

**Avantage du choix (The Pit)** : l'agentivité est totale (le joueur choisit sa topologie = son archétype),
alignée sur la profondeur émergente (CLAUDE.md §2). Pas de frustration « le lieu m'a tué » du type « Bar Sinister
a ruiné mon build ».

**Avantage de l'aléatoire (Snap)** : rejouabilité via surprise permanente. Chaque match est nouveau.

**Ce qui manque à The Pit** : la **surprise** liée à la topologie adverse. Dans un match async, le joueur
ne voit pas les sigils des adversaires. Les snapshots capturent le sigil actif (seed/decisions.md §1.1) mais
le joueur ne sait pas à l'avance contre quel sigil son build sera confronté.

**Opportunité concrète** :
1. Rendre les snapshots adverses partiellement opaques (sigil révélé seulement au combat) = decision
   de build « contre quoi vais-je jouer ? » Un levier de skill.
2. Les **reliques G (topologie/sigils)** — actuellement différées — sont l'exact équivalent « actif » des
   lieux Snap : elles modifient la topologie en cours de run, créant de la surprise. C'est le chantier le
   plus signature à débloquer.
3. Ajouter un **6e sigil** (un sigil « imposé » par l'adversaire snapshot = sa forme visible) pour les
   hauts rangs : le joueur doit build pour contrer un sigil spécifique.

**Garde-fou** : les sigils ne doivent pas être randomisés au niveau du combat (casse le déterminisme +
l'identité de build). La randomisation doit rester au niveau du **choix de build** (quels sigils sont
disponibles à l'offrande ce round ?), pas de la résolution du combat.

---

## 3. MÉCANISME #3 — Tours Simultanés (agentivité sans attente)

### 3.1 Teardown précis

Dans Hearthstone, les tours sont alternés : joueur A agit, puis joueur B. Délai max par tour : 75 s.
Dans Marvel Snap, les deux joueurs agissent **simultanément** et les cartes jouées sont révélées
**ensemble** à la fin du tour.

Source : gamedeveloper.com simultaneous turns article.

### 3.2 Psychologie

**A. Réduction du temps d'attente** (gamedeveloper.com) :
« If players use their full 75 seconds each turn [Hearthstone], a 9-round game could run as long as
22 minutes and 30 seconds. » Snap vise 3-5 minutes. La simultanéité coupe ce temps de moitié ou plus.

**B. Élimination du « trolling par l'horloge »** :
Dans Hearthstone, un joueur peut « clock » l'adversaire délibérément (utiliser tout son temps). Dans Snap,
aucune asymétrie de temps n'est exploitable.

**C. Information cachée → yomi layer** (gamedeveloper.com) :
La simultanéité + les cartes cachées jusqu'à la résolution = layer de prédiction de l'adversaire. Où va-t-il
jouer sa carte clé ? Vais-je bloquer tel lieu ou concéder ? C'est la dimension « rock-paper-scissors » du jeu
mais avec un arbre de décision plus riche.

**D. Brode sur la suppression du ciblage** (stevelilley.com résumé GDC) :
« Targeting [of cards] being confusing on a mobile game so they just removed a layer of targeting from their game
mechanics entirely to fit their targeted game platform and feel. » La simultanéité + suppression du ciblage =
interface ultra-épurée.

### 3.3 Maths chiffrées

Durée moyenne d'un match Snap : ~3-4 minutes (16M installs, $70M en 7 mois, confirme la rétention liée à la
brièveté — deconstructoroffun.com). Hearthstone : 9 rounds × 2 joueurs × 15-75 secondes par tour = 4,5 à
22,5 minutes.

### 3.4 Verdict de transférabilité à The Pit

**Non applicable directement — mais le principe est DÉJÀ PLUS AVANCÉ chez nous.**

Le combat dans The Pit est **entièrement async** : il se résout côté client à partir du snapshot adverse.
Il n'y a pas de « tour simultané » parce qu'il n'y a pas d'adversaire présent. Le « temps d'attente » n'existe
pas — le joueur regarde le combat se dérouler comme un spectateur.

**Ce qui est transférable** : le principe de **brièveté perçue**.
- Snap : 3-4 minutes par match. The Pit visait des combats courts (cooldowns 1-12 s, Fatigue ~17 s). Un combat
  court suffit à obtenir la rétroaction « enchaîner ».
- La pression est sur la **phase build**, pas sur le combat. La phase build doit être aussi épurée que possible.
  Supprimer toute friction inutile en build = principe direct du « targeting removed » de Snap.

**Opportunité concrète** : simplifier l'UI de la phase build pour atteindre « décisions en 30 secondes » de
moyenne. Cible : une session complète (1 build + 1 combat + résultat) = 2-3 minutes, comparable à un match Snap.

---

## 4. MÉCANISME #4 — Collection & Progression (Pool System)

### 4.1 Teardown précis

Les cartes sont réparties en 5 Series (Pool 1-5). La Collection Level (CL) progresse en **upgrading**
visuellement les cartes (Uncommon → Rare → Epic → Legendary → Ultra → Infinity). Chaque upgrade coûte
Credits + Boosters spécifiques à la carte. L'upgrade ne change PAS les stats en jeu ; il change uniquement
le visuel et incrémente la CL.

**Récompenses par CL** (marvelsnap.fandom.com) :

| CL Range | Récompenses | Cartes débloquées |
|---|---|---|
| 1–14 | Cartes starter (ordre fixe) | 8 starters |
| 16–166 | 25 Credits + Mystery Card toutes 8 CL | 38 Series 1 cards |
| 168–214 | 25 Credits + 5 Boosters | 8 Series 1 cards |
| 218–294 | 50 Credits + Mystery Card toutes 16 CL | 10 Series 2 cards |
| 298–498 | 50 Credits + Collector's Cache | 15 Series 2 + 2 Series 3+ |
| 502–754 | 50 Credits + Collector's Cache toutes 16 CL | 16 Series 3+ (avg) |
| 758+ | Collector's Reserve toutes 12 CL | 2 Series 3+ par 96 CL |

**Pool sizes** (dualshockers.com) :

| Series | Pool size | Rareté relative |
|---|---|---|
| 1 | 46 cartes | CL 1-214, ordre pseudo-aléatoire |
| 2 | 25 cartes | CL 215-474 |
| 3 | 77+ cartes | CL 486+, grande partie de la méta |
| 4 | 10 cartes | CL 486+, **10× plus rare** que Series 3 |
| 5 | 12+ cartes | CL 486+, **10× plus rare** que Series 4 = 100× Series 3 |

Source : dualshockers.com/marvel-snap-collection-pools-series-explained/ et marvelsnapzone.com/series/

**Collector's Tokens** (introduits mi-2023) : monnaie accumulée dans le Collection Level Road, permettant
d'acheter directement des cartes Series 3-5 dans un shop rotatif hebdomadaire. Spotlight Caches (2023) :
système de gacha remplaçant les tokens pour les nouvelles cartes.

### 4.2 Psychologie (sourcée)

**A. Progression de collection comme boucle primaire** :
Le loop : jouer des matches → gagner des Boosters (spécifiques à chaque carte) → acheter des upgrades → CL monte → nouvelles cartes débloquées → nouvelles decks possibles → jouer plus de matches. Les Boosters sont **card-specific** : ils ne sont pas fongibles. Cela crée une dépendance à jouer *des cartes spécifiques* pour les upgrader, diversifiant le meta-jeu.

**B. Collection incomplète = FOMO actif** (snap.fan/does-marvel-snap-really-want-you) :
Ben Brode a déclaré que le jeu est conçu pour que les joueurs *ne* soient pas collection-complete. L'incomplétude = toujours quelque chose à poursuivre. Le modèle est celui d'une collection de cartes traditionnelles (Magic) : vous jouez ce que vous avez, aspirez à ce que vous n'avez pas.

**C. Pay-to-Win via Season Pass** (snap.fan FOMO analysis) :
Le Season Pass à $9.99/mois inclut une carte inédite jouable immédiatement. Ces cartes sont souvent délibérément un peu trop fortes pendant leur saison (ex. Loki, Zabu, Ms. Marvel). Les F2P peuvent l'obtenir au mois suivant (Series 5 drop). FOMO calendaire : être à la pointe de la meta = $9.99/mois.

**D. Collection Level Road comme « saut dans le vide »** (deconstructoroffun.com, definitive) :
L'expérience early-game est guidée et ordonnée (starters, puis Recruit Season, puis Series 1 dans l'ordre). L'expérience mid-game (Series 3+) est aléatoire. Ce saut = frustration documentée. L'introduction des Collector's Tokens a partiellement adressé ce problème en donnant de la direction.

### 4.3 Verdict de transférabilité à The Pit

**INCOMPATIBLE à 90 % — le moteur est entièrement différent.**

La collection de cartes Marvel Snap repose sur :
1. **La propriété permanente** des cartes (cross-run, cross-session).
2. **La valeur cosmétique** des upgrades (le skin est la progression).
3. **L'espace de deck-building** (combiner 10 cartes parmi des centaines).
4. **Le FOMO calendaire** (Season Pass = carte du mois).

The Pit est un roguelite à **run jetable**. Les cartes (unités) ne sont pas « possédées » entre runs. La méta-progression est le **Grimoire** (collection de reliques apprises) et éventuellement les rangs. Il est structurellement impossible d'implémenter une « collection CL » sur des unités perdues à chaque run.

**Ce qui est partiellement transférable** :

- **Le Grimoire comme « collection »** : la base existe. Chaque relique apprise = ajout au Grimoire. Reliques = la « collection » permanente du joueur. Le Grimoire est l'exact équivalent de la Collection Level Road pour ce qui est de la progression *cross-run* visible. Renforcer sa visibilité et son feed est une priorité.

- **La monnaie de shop ciblée** (Collector's Tokens → shop rotatif) :
  Corollaire possible : un système de méta-progression où les victoires de run accumulent des « fragments » utilisables dans un shop de reliques permanentes (Grimoire unlock ciblé). Cela donnerait de la **direction** dans l'incomplétude du Grimoire, sans trahir le modèle roguelite.

- **Le « nouveau jouet » à chaque saison** (Season Pass) : corollaire dans The Pit = une **relique signature de saison** ou un **nouveau sigil** disponible pour une durée limitée. Cela crée le FOMO calendaire légitime sans être pay-to-win (le principe est cosmético-mécanique, pas power-gate).

**Ce qui est incompatible** :

- La CL Road entière (upgrader les cartes) : nos unités sont générées procéduralement et ne « s'upgradent » pas visuellement. Les duplicatas → niveau est notre système de progression d'unité, il est intra-run.

- Le gacha (Spotlight Caches) : incompatible avec la philosophie « égalisateurs, pas de gates » (BRIEF.md) et avec un roguelite F2P solo.

---

## 5. MÉCANISME #5 — La Structure Ranked / Ladder

### 5.1 Teardown précis

Ladder Snap (marvelsnap.helpshift.com/hc/en/3-marvel-snap/faq/30-how-do-ranks-work/) :

- **100 rangs**, 12 tiers nommés : Recruit (1-4) → Agent (5-9) → Iron (10-19) → Bronze (20-29) →
  Silver (30-39) → Gold (40-49) → Platinum (50-59) → Diamond (60-69) → Vibranium (70-79) →
  Omega (80-89) → Galactic (90-99) → Infinite (100).
- **7 cubes nets** pour monter d'un rang.
- **Floor à Iron (rang 10)** : on ne peut pas descendre en-dessous. Infinite (100) : inaccessible une fois atteint.
- **MMR caché** : parallèle au rang visible. Après Infinite, un système de leaderboard « Snap Points » (basé sur MMR) classe les Infinite.
- **Reset mensuel** (fin de saison) : partiel selon le rang atteint.

**Table de reset** (marvelsnap.helpshift.com + patch April 2025 decay update) :

| Rang fin de saison | Rang de départ saison suivante |
|---|---|
| Infinite (100) | 75 |
| 90-99 (Galactic) | 73 |
| 80-89 (Omega) | 65 |
| 70-79 (Vibranium) | 63 |
| 60-69 (Diamond) | 55 |
| 53-59 (Platinum) | 53 |
| 1-52 | Pas de decay |

Source : officielle + snapcomplete.com (rang reset confirmé depuis les patch notes).

**Proportion d'Infinite** : 22 % des joueurs *trackés* sur SnapComplete ont atteint Infinite ce mois-ci.
SnapComplete note que son public est plus compétitif que la moyenne globale, donc le chiffre global est
probablement plus bas. Second Dinner ne publie pas le taux officiel.

Source : snapcomplete.com/faq/ranked-climb

### 5.2 Psychologie (sourcée)

**A. Tiers nommés = jalons de compétence visibles** :
Passer de Silver à Gold n'est pas seulement +10 rangs ; c'est un label de prestige. Chaque tier croisé
pour la première fois dans une saison = récompense cosmétique. Renforcement du sentiment de progrès sans
saturation (il faut du temps avant le prochain tier).

**B. Reset mensuel = saison recommencée = engagement calendaire** :
Le reset est la clé de l'« enchaîner les runs pour grimper ». Chaque mois = un nouveau départ relatif.
Les joueurs qui n'ont pas atteint Infinite ce mois-ci recommencent plus bas le mois prochain, mais « ça
repart ». Cela génère un engagement cyclique documenté (design des battle passes, cf. progression-economy-prd.md §5).

**C. Floor de rang = protection du débutant** :
Iron 10 = plancher absolu. Un débutant ne peut pas tomber sous Iron même en perdant tout. Cela évite la
« spiral of doom » où un mauvais match-making envoie un joueur fragile dans le vide.

**D. MMR caché séparé du rang visible** :
Le rang visible progresse par cubes. Le MMR est une valeur interne plus précise. Le matchmaking utilise le
MMR (pas le rang affiché), donc deux joueurs Gold peuvent avoir des MMR très différents. Cela réduit le
grief (le « j'ai pas l'expérience de mon rang »), car le matchmaking est *plus juste* que le rang visible
ne le laisse croire.

**E. Infinite Race** :
Une fois Infinite atteint, le leaderboard se mesure par les Snap Points (vitesse d'ascension + wins
post-Infinite). Cela crée un jeu dans le jeu pour les plus compétitifs sans exclure les casuals qui
atteignent Infinite une fois par saison.

### 5.3 Maths chiffrées

Pour grimper du rang 10 (Iron) à Infinite (100) = 90 rangs × 7 cubes = **630 cubes nets** minimum.

Un match no-snap, victoire = +2 cubes. Défaite sans Retreat = -2 cubes. EV à 50 % = 0.
Avec cube efficiency :
- 55 % win rate, cube ratio 2:1 (win +2 cubes, lose -2 cubes) → net 0.1 cubes/game moyen.
  Pour 630 cubes nets, il faut ~6 300 matches à ce rythme.
- 55 % win rate, cube ratio 4:1 (snap + retreat discipliné → win +4, lose -1) → net ~1.75 cubes/game.
  Pour 630 cubes nets : ~360 matches.

Durée estimée : ~3 min/match, 360 matches = 18 heures de jeu pour passer de Iron à Infinite avec
une stratégie disciplinée. Estimation cohérente avec les rapports communautaires (une semaine de jeu casual
= Gold, deux semaines à jouer « sérieusement » = Infinite possible).

Sources : calculs dérivés des formules snap.fan/guides/stay-or-go/, snapcomplete.com

### 5.4 Verdict de transférabilité à The Pit

**Très transférable dans l'objectif, différent dans la mécanique d'ascension.**

**Ce qui survit à nos contraintes** :

- **Tiers nommés** : oui. The Pit peut avoir des tiers de run (ex. Crawlers → Condemned → Damned →
  Forsaken → Pit-Born). Chaque tier = un label prestige + une récompense cosmétique (variant de
  créature ? skin de Grimoire ?) au premier franchissement de saison. Pas d'obstacle pour un solo dev.

- **Reset mensuel partiel** : oui. Réinitialisation de rang selon le palier atteint = engagement calendaire
  sans effacer le progrès. Adapté à The Pit : le rang de saison repart à N-1 tiers si non maintenu.

- **Floor absolu** : oui. Un joueur ne peut pas descendre en-dessous du 1er tier. Implémentation triviale.

- **MMR caché séparé du rang visible** : oui, et c'est IMPORTANT pour le async. Notre matchmaking
  (serve par version/tier dans snapstore.lua) est déjà un système de tier. Le MMR peut être affiné
  indépendamment du rang visible pour éviter le grief.

- **Infinite Race (top de leaderboard)** : oui, adapté. Un leaderboard de « runs réussis en N combats minimum »
  ou « ascension la plus rapide de la saison » correspond exactement au format 10 victoires. Adapté
  à l'async : le leaderboard est calculé offline, pas en temps réel.

**Ce qui diffère (et doit être adapté)** :

- Dans Snap, chaque match = ±cubes. Dans The Pit, chaque **run** = ±rang (une run dure 10 combats,
  pas un match). Le granulaire de progression est différent.

- **Recommandation** : le cube-equivalent dans The Pit est le **résultat de run** (Victoire = ascension /
  Défaite = chute) plutôt que le résultat de match. Chaque run réussie = +N points de rang. Chaque
  run échouée = -M points. La « cube efficiency » devient : à quel rang de tier est-ce que j'affronte
  un snapshot qui me donne un avantage espéré ?

- **Problème de fréquence** : Snap génère 10-20 matches/heure (3-4 min/match). The Pit en l'état génère
  1-2 runs/heure (10 combats × quelques minutes par combat + phase build). La granulaire de feedback
  est 10× plus longue. Implication : les paliers de rang doivent être espacés en conséquence ; sinon
  la progression semble stagnante. Proposer 2-3 tiers max par mois de saison, pas 12 tiers comme Snap.

---

## 6. MÉCANISME #6 — Le Season Pass / Modèle Économique

### 6.1 Teardown précis

**Season Pass** ($9.99/mois, mensuel) :
- Track gratuit : Credits, Boosters, Gold, Variants.
- Track premium : tout le track gratuit + une carte inédite jouable immédiatement + titres, card backs,
  Variants premium.
- La carte premium rejoint Series 5 le mois suivant (F2P peuvent l'obtenir alors).

**Revenues** (plusieurs sources) :
- 5 premiers mois (oct. 2022 – mars 2023) : $50M+ (naavik.co/digest/is-marvel-snap-monetization-too-modest/)
- 7 mois (oct. 2022 – mai 2023) : $70M+ net revenue (deconstructoroffun.com definitive)
- ~20M downloads (naavik.co card acquisition 2023)
- Rapport d'analyste : Snap a « out-performed Hearthstone on revenue in its first 5 months »

**Structure des coûts de monétisation** :
- Season Pass = $9.99/mois = ~$120/an pour maintenir l'accès aux cartes du mois.
- Spotlight Caches (depuis 2023) : remplacement du token shop pour les nouvelles S4/5 ; 1 key/semaine
  gratuite en théorie, 1 carte garantie / mois environ (snap.fan analysis).
- Bundles cosmétiques à $15-$50 (critiqués comme agressifs en 2024).
- Total dépense d'un joueur compétitif F2P : ~300-600 tokens/semaine, ~1200-2400/mois, soit ~1 carte S3/mois
  ciblez via tokens ou ~0,25 carte S4/mois. Très lent.
- Total dépense d'un joueur Season Pass : ~1 carte/mois garantie (la SP card) + progression accélérée.

Sources : snap.fan/news/why-is-marvel-snap-so-expensive/, naavik.co analyses, deconstructoroffun.com

### 6.2 Psychologie (sourcée)

**A. La carte du mois = FOMO compétitif** (snap.fan) :
La carte Season Pass est délibérément légèrement trop forte pendant sa saison de lancement. Les F2P jouent
sans elle pendant 30 jours. FOMO = $9.99. Brode a confirmé cette orientation (indirectement via OTA buffs/nerfs
post-saison). Critique documentée par KMBest (podcast Snapshot ep.71) : « Why are they doing all this to the
cosmetic side and not making things cheaper? »

**B. Sunk cost loop** :
Upgrader une carte = dépenser des Boosters + Credits. Ces ressources ne sont pas récupérables. Plus vous
avez upgradé, plus vous êtes « investis ». Le loop de CL est un classique du sunk cost psychology dans les
jeux de collection.

**C. « Modest monetization » = trust signal** :
Naavik (2023) note que Snap a délibérément évité les modèles agressifs au launch (pas de gacha de cartes,
pas de P2W direct, pas de stamina). Ce « modesty » a généré un goodwill communautaire fort. Ce goodwill s'est
érodé avec les Spotlight Caches et les cosmetics agressifs de 2024.

### 6.3 Verdict de transférabilité à The Pit

**Applicable dans la forme saison, INCOMPATIBLE dans le contenu.**

- **Season Pass $9.99/mois** : Le Pit n'a pas de contenu à « vendre » par saison dans ce modèle. On n'a pas
  de nouvelles cartes exclusives à payer. Si une version payante existe un jour, elle pourrait offrir : track
  cosmétique du Grimoire (nouveaux thèmes visuels de reliques), un sigil de saison exclusif (topologie inédite),
  un biome de fond exclusif. JAMAIS de contenu mécanique exclusif (égalisateurs, pas de gates — BRIEF.md).

- **La carte du mois surpuissante** : anti-pattern direct pour The Pit. Nos reliques doivent être des
  égalisateurs (decisions.md §4.2 garde-fou #3). Une relique saison temporairement OP trahit ce principe.

- **Monnaie secondaire (Collector's Tokens → shop ciblé)** : corollaire valide. Un shop de reliques avec
  une rotation hebdomadaire (ou bi-mensuelle) alimenté par une monnaie gagnée en jouant = direction
  dans l'incomplétude du Grimoire. Sans gacha, sans loot box.

---

## 7. MÉCANISME #7 — L'absence de ciblage et la simplification UX

### 7.1 Teardown précis

Dans la plupart des CCG (Hearthstone, Magic), les cartes peuvent cibler des cartes adverses
spécifiques. Dans Marvel Snap, **aucune carte ne cible une autre carte directement** (dans la
grande majorité des effets). Les effets sont zonaux (s'appliquent à un lieu, pas à une carte).

Source : GDC 2023 (stevelilley.com résumé) : « Targeting being confusing on a mobile game so they just
removed a layer of targeting from their game mechanics entirely. »

### 7.2 Psychologie

Supprimer le ciblage réduit la **complexité** (coût d'entrée) sans réduire la **profondeur** (décisions
intéressantes). Les joueurs ne peuvent pas se plaindre d'un ciblage injuste. Les matchs se résolvent sans
interactions qui semblent aléatoires.

C'est la leçon Brode de la différence Complexité/Profondeur :
- Complexité = coût à payer pour jouer (apprentissage).
- Profondeur = la partie fun (décisions intéressantes).
- Objectif = profondeur élevée, complexité basse → « elegant design ».

Source : GDC 2023 (stevelilley.com résumé section Depth vs. Complexity).

### 7.3 Maths chiffrées

Brode (GDC 2023, mobilegamer.biz) : « If you put more than eight words on the screen, players will not read
them. The average [on-screen] word count for Hearthstone was nine words, and for Snap it's 11. » — Paradox :
Snap est *plus verbeux* que Hearthstone en mots/écran mais *moins complexe* perçu. La distinction = les mots
de Snap décrivent des effets zonal simples vs. les mots HS décrivent du ciblage complexe.

### 7.4 Verdict de transférabilité à The Pit

**Très transférable dans le principe, déjà partiellement implémenté.**

The Pit a déjà supprimé le ciblage aléatoire : notre système de ciblage est **100 % déterministe**
(colonne → taunt → aggro → tie-break). Ce n'est pas un ciblage « par le joueur » — c'est un ciblage
émergent des positions. La plainte « le RNG m'a tué » = impossible (sauf sur la composition de la boutique,
ce qui est normal et documenté comme « input randomness » acceptable — leçon Garfield, GDC Snap).

**Opportunité concrète** : appliquer la règle des « 8 mots max » à toutes les descriptions d'effets et
de reliques. Nos reliques actuelles sont-elles sous ce seuil ? Auditer. Le brief dit « nom évocateur + effet
clair + flavor » — c'est la même ambition. La contrainte Snap est chiffrée : ≤8 mots descriptifs, sinon
les joueurs ne lisent pas.

---

## 8. MÉCANISME #8 — La méta rotation par les lieux (fraîcheur sans nouveau contenu)

### 8.1 Teardown précis

Marvel Snap renouvelle régulièrement le pool de lieux disponibles (temporairement exclus, réintroduits,
modifiés via OTA). Cette rotation change la méta sans ajouter de nouvelles cartes. Un même lieu dominant
peut être temporairement retiré. Les OTAs (over-the-air balance updates) modifient aussi des cartes sans
patch lourd.

Source : marvelsnap.com/may-25th-ota-balance-updates/ (exemple concret d'OTA) ; marvelsnapzone.com/location-rng-meta/

### 8.2 Psychologie

**Coût d'opportunité du méta stable** : une méta stable = les mêmes decks gagnent toujours. Le cerveau
s'adapte et la « découverte » disparaît. Les lieux rotatifs forcent une redécouverte permanente de l'espace
de decks, même sans nouvelles cartes.

**BRIEF analogie pour The Pit** : nos 5 sigils jouent ce rôle, mais de manière stable (on ne les modifie
pas encore). Les **reliques G (topologie)** différées sont exactement le levier d'un « rotation de lieux »
dans notre contexte.

### 8.3 Verdict de transférabilité à The Pit

**OTA de balancing + rotation de contenu = oui, dans la limite du solo dev.**

- Nos reliques et effets d'unités sont déjà balançables via `tools/sim.lua` + data sans patch.
- Un système de « relique de saison retirée / réintroduite » = viable sans nouveau code (on cache des
  ids dans la seed).
- La **rotation de sigils disponibles au Marchand** (reliques G) = l'exact équivalent de la rotation
  de lieux Snap pour modifier la méta de build sans nouveau code.

---

## 9. Postmortem : leçons négatives de Snap (ce qu'il ne faut PAS faire)

### 9.1 FOMO monétaire corrosif (2024)

L'évolution de Snap vers les Spotlight Caches agressives + cosmetics shop (2024) a généré un backlash
documenté (snap.fan/why-is-marvel-snap-so-expensive, snap.fan/does-marvel-snap-really-want-you).
La communauté a perçu un glissement de « modest monetization » vers « whale monetization ».

**Leçon pour The Pit** : si on monétise un jour, le « modesty as trust » est fragile. Le bon signal initial
(pas de P2W, pas de gacha) doit être MAINTENU, pas relâché progressivement. Le relâchement = pire qu'un
modèle agressif dès le début (violation de la promesse initiale = perte de confiance).

### 9.2 « Toujours un nouveau P5 » (power creep et burnout de collection)

Snap a continué à ajouter des cartes Series 4/5 à un rythme croissant (52 nouveaux S5 en 2024 selon les
analyses de marvelsnapzone.com). Le pool incomplet est devenu un fardeau plutôt qu'une aspiration pour les
joueurs mid-game.

**Leçon pour The Pit** : nos 83 unités sont un pool fixe (bien). Ajouter des unités doit être lent et
mesuré. Un run de 10 combats avec 20 unités intéressantes est meilleur qu'un run avec 83 unités plates.
Qualité > quantité de pool.

### 9.3 Season Pass card OP = meta-gate temporaire

Chaque mois, la carte Season Pass était légèrement OP. Résultat : les F2P étaient en désavantage méta
structurel pendant 30 jours. Cela a érodé la confiance en l'équité du jeu.

**Leçon pour The Pit** : les reliques de saison (si on en fait) doivent être des ÉGALISATEURS, jamais des
power-gates. Ni trop fortes, ni derrière paywall. Une relique de saison cosmético-mécanique (sigil inédit +
flavour text exclusif) est acceptable ; une relique déséquilibrant la méta = anti-pattern direct.

---

## 10. Synthèse : matrice de transférabilité

| Mécanisme Snap | Transférable ? | Adaptation pour The Pit |
|---|---|---|
| **Snap/Cube (pari)** | Partiel (psychologie, pas la mécanique) | Reframer la défaite en « Sombre Sagesse » (concédé stratégique) ; reliques comme amplificateurs d'enjeux |
| **3 Lieux (variabilité structurelle)** | Oui — DÉJÀ FAIT via sigils | Renforcer : révéler le sigil adverse au combat, avancer les reliques G (topologie), envisager un 6e sigil imposé |
| **Tours simultanés (brièveté)** | Transposé — build épuré | Viser 2-3 min/session (build + combat + résultat). Supprimer les frictions de l'UI build |
| **Pool System / Collection Level** | Non — moteur roguelite incompatible | Grimoire comme collection cross-run ; shop rotatif de reliques avec monnaie de run ; pas de gacha |
| **Ranked Ladder (tiers, cubes, reset mensuel)** | Oui | Tiers nommés grimdark ; reset mensuel partiel ; floor de rang ; MMR caché séparé ; leaderboard de vitesse d'ascension |
| **Season Pass ($9.99/mois)** | Partiel (la forme, pas le contenu) | Track cosmétique (thèmes Grimoire, sigils), jamais de contenu mécanique exclusif |
| **Suppression du ciblage (UX)** | Oui — DÉJÀ FAIT | Auditer les textes de reliques/effets : ≤8 mots descriptifs |
| **Rotation de lieux (fraîcheur méta)** | Oui | Rotation de reliques G dans le Marchand ; OTA balancing via `sim.lua` |

---

## 11. Questions ouvertes pour les rounds suivants

1. **Concédé stratégique** : faut-il implémenter un mécanisme de « Retreat avant combat » avec coût de run
   (−vies partielles ?) et un reframing UX positif ? Quel est le coût de complexité perçue vs. le gain
   de psychologie ?
2. **Tiers de rang grimdark** : quels noms pour les tiers de rang ? (ex. Crawler / Condemned / Forsaken /
   Pit-Born / Elder). Combien de tiers par saison pour que la progression reste perçue ?
3. **MMR et intégrité du matchmaking async** : le `serve(version, tier)` actuel est-il suffisant comme proxy
   MMR ? Faut-il introduire un score de force de snapshot (sum des stats/reliques) distinct du tier de run ?
4. **Reliques G (topologie)** : ce chantier différé est identifié comme le levier #1 pour reproduire
   l'effet « rotation de lieux Snap ». Quel est le plan de lancement minimal ?
5. **Leaderboard** : dans un jeu async sans matchs tracés en temps réel, comment mesurer le « speed run to
   Infinite » équivalent ? Timestamp de la 10e victoire dans la saison ? Rang max atteint ?

---

*Rédigé : 2026-06-23. Sources web vérifiées et citées. Lecture seule du repo — aucun code modifié.
Périmètre : docs/roadmap-lab/ uniquement.*
