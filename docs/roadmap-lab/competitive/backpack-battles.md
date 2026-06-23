# Backpack Battles — Analyse ultra-approfondie

> **Mandat** : teardown de chaque mécanisme → psychologie → maths chiffrées et sourcées →
> verdict de transférabilité à *The Pit* (async snapshots, run court 10 victoires, sim déterministe, grimdark).
> Sources citées en ligne. Lecture seule du repo jeu.
>
> **Sources primaires consultées** :
> - [backpackbattles.wiki.gg/wiki/Game_Mechanics](https://backpackbattles.wiki.gg/wiki/Game_Mechanics)
> - [backpackbattles.wiki.gg/wiki/Rarity](https://backpackbattles.wiki.gg/wiki/Rarity)
> - [backpackbattles.wiki.gg/wiki/Cooldown](https://backpackbattles.wiki.gg/wiki/Cooldown)
> - [en.wikipedia.org/wiki/Backpack_Battles](https://en.wikipedia.org/wiki/Backpack_Battles)
> - [store.steampowered.com/app/2427700/Backpack_Battles](https://store.steampowered.com/app/2427700/Backpack_Battles/?l=english)
> - [newsletter.gamediscover.co/p/how-backpack-battles-sold-650k-copies](https://newsletter.gamediscover.co/p/how-backpack-battles-sold-650k-copies)
> - [gamerant.com/backpack-battles-auto-battler-inventory-system-good-unique](https://gamerant.com/backpack-battles-auto-battler-inventory-system-good-unique/)
> - [backpack-battles.fandom.com/wiki/Game_Mechanics](https://backpack-battles.fandom.com/wiki/Game_Mechanics)
> - [casualgameguides.com/walkthroughs/backpack-battles/backpack-layout-item-positioning](https://casualgameguides.com/walkthroughs/backpack-battles/backpack-layout-item-positioning)
> - [mobilegamereport.com/articles/backpack-battles-genre-mashup-2026](https://www.mobilegamereport.com/articles/backpack-battles-genre-mashup-2026)
>
> **Dates** : Early Access 8 mars 2024 ; sortie complète 13 juin 2025 ; 640 000 copies en 1 mois
> (IndieArk, cité par [GameDiscoverCo, 24 avril 2024](https://newsletter.gamediscover.co/p/how-backpack-battles-sold-650k-copies)).

---

## 0. Contexte & profil du jeu

Backpack Battles est un auto-battler PvP **asynchrone par snapshots** développé par
**PlayWithFurcifer** (duo allemand Doro et Mario, publié IndieArk). Moteur : Godot. Prix : $14,99.
Reviews Steam 2026 : **92 % Very Positive (5 321 avis)**.

La formule en une phrase : *arrangez des items dans votre inventaire spatial, les synergies
dépendent de l'adjacence dans la grille, puis combattez automatiquement le build snapshoté
d'un autre joueur.* Le « clever hook » selon Simon Carless (GameDiscoverCo) : « *PvP without
time pressure or worries about interacting directly with them* ».

**Chiffres de marché** :
- \#2 Steam new releases mars 2024 par unités, entre Dragon's Dogma 2 et Horizon Forbidden West
  ([GameDiscoverCo, 2024-04-24](https://newsletter.gamediscover.co/p/how-backpack-battles-sold-650k-copies))
- 640 000 unités en 1 mois ; Chine 48 %, Japon 11 %, USA 10 %
- 4 classes jouables, 200+ items en EA, 500+ items en v1.0

---

## 1. La boucle cœur

### 1.1 Teardown précis

```
run = 10 victoires avant 5 défaites (exactement comme The Pit)
rounds max = 18

CHAQUE ROUND :
  1. Shop (phase build) : budget or → acheter/reroll/vendre/arranger
  2. Combat auto (phase battle) : on regarde, duree ~10-20s
  3. Si victoire : on recoit de l'or  
  4. Recettes résolues : items adjacents → éventuellement craftés
  5. Retour shop

VICTOIRE : 10 victoires cumulées sur le run
DÉFAITE : 5 défaites cumulées → fin du run
```

**Source** : [backpack-battles.fandom.com/wiki/Game_Mechanics](https://backpack-battles.fandom.com/wiki/Game_Mechanics) —
*« until you've either won 10 rounds or lost 5, in that case your game is over »*.

### 1.2 Psychologie de la boucle

La boucle est un **near-miss permanent sous agence**. Chaque round, le joueur a le sentiment
d'avoir CHOISI son placement et CONSTRUIT sa victoire — ou d'avoir fait une ERREUR identifiable
(mauvais placement, item manquant). C'est la différence entre near-miss brut (frustration, comme
les machines à sous) et near-miss sous agence (compétence perçue : « *la prochaine fois je ferai
autrement* ») — mécanisme documenté par Clark, 2009 (Neuron) pour les jeux de hasard amélioré
par compétence.

La résolution automatique du combat (10-20 s) agit comme **révélation d'hypothèse** : le joueur
a posé sa théorie (son build), le jeu la teste. Le résultat est immédiat et lisible (combat log).
Cela renforce la boucle apprentissage-action plus vite qu'un jeu RTS ou un combat manuel.

**Le verdict est lisible mais la chaîne causale est complexe** : « j'ai perdu parce que mon
Garlic avait un mauvais voisinage, pas parce que le dé m'a eu ». La défaite est attribuée à
une décision — elle génère l'envie de rejouer.

---

## 2. Économie de la boutique — maths chiffrées

### 2.1 Or par round (source : wiki officiel)

| Round | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8* | 9 | 10 | 11 | 12 | 13 | 14 | 15+ |
|-------|---|---|---|---|---|---|---|----|----|----|----|----|----|----|----|
| Or    |12 | 9 | 9 | 9 |10 |10 |11 | 21 |12 |12  |13  |13  |14  |14  |15  |

*\*Round 8 = shop de sélection de sous-classe unique (+10g bonus).*

Source : [backpack-battles.fandom.com/wiki/Game_Mechanics](https://backpack-battles.fandom.com/wiki/Game_Mechanics)

**Or total sur un run de 10 victoires (rounds 1-13, estimation médiane)** :
12 + 9 + 9 + 9 + 10 + 10 + 11 + 21 + 12 + 12 + 13 ≈ **128 g** sur 11 rounds,
+ or reporté (leftover gold transfers) car **le budget n'est PAS remis à zéro** entre rounds.

**Différence cruciale avec The Pit** : Backpack Battles **conserve l'or non-dépensé d'un round
à l'autre**. The Pit utilise le modèle SAP (or frais/round, pas de report) — décision actée,
voir `state.lua`, `GOLD_PER_ROUND = 10`.

### 2.2 Reroll et vente

- **Reroll** : 1g les 4 premiers, 2g ensuite ([backpackbattles.wiki.gg/wiki/Game_Mechanics](https://backpackbattles.wiki.gg/wiki/Game_Mechanics)).
  L'escalade de coût est le garde-fou anti-churn documenté dans la PRD Pit
  (`progression-economy-prd.md §7` : *« Option anti-spam : reroll 1g → 2g après 4 rerolls/round »*).
- **Vente** : 50 % du prix arrondi au supérieur. Un item en solde acheté et revendu → 0 perte nette.
- **Soldes** : 10 % de chance par slot d'être à -50 %. Cela crée des **occasions opportunistes** sans
  garantie — renforcement variable positif classique.

### 2.3 Items — prix par rareté (source : wiki gemstones)

| Rareté | Common | Rare | Epic | Legendary | Godly |
|--------|--------|------|------|-----------|-------|
| Prix exemple (gemstones) | 1g | 2g | 4g | 8g | 16g |

Les items normaux ont des prix variables (ex. Ripsaw Blade coûtait 10g avant un patch à 9g —
[backpackbattles.wiki.gg/wiki/Patch_1.0.7](https://backpackbattles.wiki.gg/wiki/Patch_1.0.7)).
Le prix n'est **pas strictement corrélé à la rareté** pour tous les items (contrairement au
`cost = rank` de The Pit). Certains items Legendary valent 5-8g, certains Godly valent 10-16g.

### 2.4 Verdict psychologie économie

Le report d'or crée un **axe de gestion supplémentaire** (économiser pour un Godly à 16g en
round 8 vs. reroll immédiat). Cet axe est riche mais porte le risque de « spirale de la mort »
(ne jamais acheter en attendant l'item parfait). Backpack Battles le connaît : les forums Steam
montrent des joueurs bloqués sur des stratégies trop économes.

**The Pit a choisi le modèle SAP (sans report)** : plus simple, aucune spirale de trésorerie,
chaque round repart de zéro. La décision est saine pour un run court de 10 victoires.
L'arbitrage The Pit reste l'XP (monter le tier boutique vs. reroll vs. acheter) — c'est
suffisant sans ajouter le report d'or.

---

## 3. Système de rareté progressive — maths et psychologie

### 3.1 Table de cotes (source : wiki officiel, vérifiée sur deux sources)

| Rareté | R1 | R2 | R3 | R4 | R5 | R6 | R7 | R8 | R9 | R10 | R11 | R12-18 |
|--------|----|----|----|----|----|----|----|----|----|-----|-----|--------|
| Common | 90 | 84 | 75 | 64 | 45 | 29 | 20 | 20 | 20 | 20  | 20  | 20     |
| Rare   | 10 | 15 | 20 | 25 | 35 | 40 | 35 | 30 | 28 | 25  | 23  | 20     |
| Epic   |  0 |  1 |  5 | 10 | 15 | 20 | 25 | 25 | 25 | 25  | 23  | 20     |
| Legendary | 0 | 0 | 0 |  1 |  5 | 10 | 15 | 15 | 15 | 15 | 17  | 20     |
| Godly  |  0 |  0 |  0 |  0 |  0 |  1 |  5 | 10 | 12 | 15  | 17  | 20     |
| Unique |  0 |  0 |  0 |  2 |  2 |  2 |  2 |  2 |  2 |  2  |  2  |  2/3   |

Source : [backpackbattles.wiki.gg/wiki/Rarity](https://backpackbattles.wiki.gg/wiki/Rarity)
et [backpack-battles.fandom.com/wiki/Game_Mechanics](https://backpack-battles.fandom.com/wiki/Game_Mechanics)

### 3.2 Structure mathématique des cotes

**Phase early (rounds 1-4)** : dominance Common (90→64 %), avec Rare qui monte progressivement.
La Legendary n'apparaît qu'à 1 % au round 4. Objectif : **on construit un plancher** (des
enablers simples qui tapent dès maintenant).

**Phase mid (rounds 5-7)** : bascule vers la complexité. Common descend à 29 %, Rare à 40 %
(pic !), Epic monte à 25 %, Legendary à 15 %, Godly apparaît. C'est la **phase de pivot** :
le build de base est défini, on cherche ses synergies.

**Phase late (rounds 12+)** : distribution plate 20/20/20/20/20 pour Common/Rare/Epic/Legendary/Godly.
Chaque slot a une chance EGALE d'apparaître dans n'importe quelle rareté. C'est la **phase de
haute tension** : on peut être comblé (Godly parfait pour le build) ou frustré (Common qui ne sert
plus à rien). La variance est maximale et voulue.

**Unique items** : 2-3 % de chance d'apparaître après le combat (pas sur les rerolls). Maximum 1
unique à la fois. Rareté en dehors du système, fonctionnant comme un **jackpot latent** (on ne peut
pas le forcer par le reroll).

### 3.3 Pools par rareté (neutre cross-classes, wiki.gg 2025)

| Rareté | Pool neutre | Total avec classes |
|--------|-------------|-------------------|
| Common | 16 | ~20 |
| Rare | 13 | ~29 |
| Epic | 11 | ~24 |
| Legendary | 10 | ~28 |
| Godly | 11 | ~14 |

**Pools relativement petits** : 16 Commons seulement. Avec 5 slots de boutique et un reroll à 1g,
la probabilité de voir un même Common plusieurs fois dans un run est élevée. Cela **rend les
recipes réalisables** — voir §6.

### 3.4 Psychologie des cotes progressives

**Anticipation construite** : on sait que le Godly qu'on vise apparaîtra à partir du round 6 (1 %).
Chaque round est un « pas de plus vers la promesse ». Ce système est le **hook d'escalade** — le
joueur sait que son build sera meilleur au prochain round si il survit. Référence : progression en
arc tendu documentée dans les roguelikes (Slay the Spire, boons d'Hades).

**Danger de frustration** : à partir du round 12, la distribution plate peut donner 5 Commons
alors que le joueur vise un Godly. Backpack compense avec le reroll escaladant (2g après 4 rerolls)
et le storage (réserver pour plus tard).

**Verdict pour The Pit** : notre système XP-gated (tier 1-5, cotes de la `progression-economy-prd.md`)
applique la même logique structurelle — cotes en fonction de l'avancement — mais par TIER DE
BOUTIQUE (monté activement) plutôt que par ROUND automatique. La différence clé : Backpack ne demande
pas d'investissement pour accéder aux hautes raretés (elles arrivent d'elles-mêmes avec le temps).
The Pit demande un INVESTISSEMENT (achat XP). Notre modèle a plus de contrôle sur l'arc mais exige
un meilleur calibrage pour que « passif ≈ tier 3 en fin de partie » soit satisfaisant.

---

## 4. Le système spatial — la signature qui coûte cher

### 4.1 Teardown précis

**Inventaire** : grille 2D de **63 tuiles** maximum, démarrée à 12-14 selon la classe. Les items
ont des formes distinctes (1x1, 1x2, 2x2, L-shapes, T-shapes, etc.) et doivent **s'insérer dans
l'espace disponible**.

Achat d'espace : Leather Bag, Fanny Pack, Stamina Sack, Potion Belt, Protective Purse — acheter
ces bags = débloquer des tuiles supplémentaires (jusqu'à 63 max).

**Adjacence** : les effets des items sont souvent conditionnels aux **voisins immédiats** (cases
orthogonales ET diagonales dans la grille). Un item peut avoir un slot ★ qui se « remplit » par
un voisin d'un certain type. Ex. : « Pan deals more damage if it is next to food items »
([en.wikipedia.org/wiki/Backpack_Battles](https://en.wikipedia.org/wiki/Backpack_Battles)).

**Recettes** : deux items adjacents → lors du retour au shop, ils se **craftent automatiquement**
en un item de rang supérieur. Les items peuvent être lockés pour éviter le craft non voulu.

**Rotation** : les items peuvent être retournés/rotés pour s'insérer dans l'espace.

Source : [backpackbattles.wiki.gg/wiki/Game_Mechanics](https://backpackbattles.wiki.gg/wiki/Game_Mechanics) —
*« Each class starts with 12-14 of 63 total tiles that can be rearranged and rotated »*.

### 4.2 Psychologie du puzzle spatial

**Le jeu a créé un nouveau « verbe »** : le verbe d'Inventaire. Chaque joueur de RPG comprend
intuitivement le concept de « ranger son sac ». Backpack Battles exploite cette familiarité
cognitive (schème mental existant) pour créer une profondeur nouvelle.

La **résolution de contraintes spatiales** active des circuits cognitifs différents des autobattlers
classiques — plus proches du puzzle/Tetris. Mobile Game Report 2026 le formule clairement :
*« Roguelite in structure. Puzzle game in execution. Auto-battler in resolution »*
([mobilegamereport.com](https://www.mobilegamereport.com/articles/backpack-battles-genre-mashup-2026)).

Le placement optimal (core carry + support adjacents + fill efficient) est un **problème NP-hard
d'optimisation combinatoire**. Un chercheur a même écrit un solver C++ pour ça
([github.com/ottoblep/backpack-battles-solver](https://github.com/ottoblep/backpack-battles-solver)).
C'est le signal d'une profondeur de placement réelle.

**Feedback immédiat** : le jeu visualise les adjacences pendant le placement (outline des slots ★).
Le joueur voit instantanément quelles synergies sont « en ligne » vs. « hors ligne ».

### 4.3 Le coût réel de ce mécanisme

Voici où l'analogie paresseuse tue : « Backpack fait de l'adjacence, nous aussi → copions ».

NON. Ce sont deux niveaux de complexité très différents :

| Dimension | Backpack Battles | The Pit |
|-----------|-----------------|---------|
| Grille | 2D libre, 63 tuiles, formes variables | Graphe 3×3 fixe, 9 slots, formes d'unités inexistantes |
| Adjacence | Orthogonale ET diagonale, items de tailles hétérogènes, rotation | Orthogonale uniquement, arêtes explicites, topologie gérée par sigil |
| Recipes | Craft auto entre voisins → merge d'items | Merge 3 copies identiques → niveau (déjà implémenté) |
| Drag-drop | Items de formes différentes, rotation, fit dans l'espace | Unités 1x1, cases fixes |
| Engine | Godot + 2 ans d'early access sur ce seul problème | LÖVE + pixel art procédural + SIM déterministe + tout le reste |

**Implémenter la grille Backpack (formes hétérogènes + rotation + contraintes d'espace + recipes
spatiales) en Lua/LÖVE en parallèle de tout le reste est irréaliste.** C'est exactement le
type de piège identifié dans `autobattler-design.md §4` : *« grille 2D type Tetris (rotation/
recettes/adjacence). Résolution : DANS 'À ÉVITER'. »*

### 4.4 Ce qui EST transférable — l'essence, pas la forme

**La psychologie qui survit** : la synergies d'adjacence (voisin buffe voisin) est déjà dans
The Pit via le graphe 3×3 + arêtes explicites + auras build-résolues. Le bénéfice psychologique
— « *où je place mon carry change le résultat* » — est identique. La différence est que dans
The Pit, le placement se fait sur 9 cases dont la topologie varie avec le sigil, ce qui est une
profondeur de placement différente (positionnement stratégique dans un graphe vs. puzzle spatial
libre).

**Ce qui manque** : The Pit n'a pas de feedback visuel des synergies d'adjacence actives PENDANT
le placement. Backpack surligne les ★ en temps réel. C'est un item UI à implémenter (surligner
les arêtes actives sur le plateau) — faible coût, fort bénéfice de lisibilité.

**Les recipes** : le craft par adjacence Backpack est l'analogue des recipes d'item dans PoE ou
des upgrades TFT. Dans The Pit, le merge des duplicatas (`build:checkMerges`) joue ce rôle. La
différence : dans Backpack, un craft spatial peut être *accidentel* (lock requis pour éviter) ;
dans The Pit, le merge est intentionnel (3 copies = niveau+1). **Pas de raison de changer le
modèle The Pit** : l'accidentel de Backpack crée de la friction supplémentaire non désirée dans
un run court.

---

## 5. Moteur de combat — timeline à cooldowns

### 5.1 Teardown précis

Le combat Backpack n'est PAS un ordre fixe (HS:BG / SAP). C'est une **timeline temps réel à
cooldowns** :

- Chaque item a un cooldown exprimé en secondes (ex. Garlic = 4s base, Holy Spear = 2.2s→2.0s
  après patch 1.0.7, [wiki Patch_1.0.7](https://backpackbattles.wiki.gg/wiki/Patch_1.0.7)).
- Les items s'activent indépendamment, sans attendre les autres.
- La formule de cooldown ajusté :
  - Si speed-up > slow-down : `CD = BaseCooldown / (100% + Faster - Slower)`
  - Si slow-down > speed-up : `CD = BaseCooldown * (100% + Slower - Faster)`
  - Cap ±1000% (×10) dans chaque sens.
  Source : [backpackbattles.wiki.gg/wiki/Cooldown](https://backpackbattles.wiki.gg/wiki/Cooldown)

**Buffs qui modifient les cooldowns** :
- Heat : tous les items activent 2 % plus vite par stack.
- Cold : tous les items activent 2 % plus lentement par stack.
- Stun : pause tous les cooldowns pour une durée donnée.

**Fatigue** : déclenche à 17 secondes → 1 dégât/s escaladant (+1 à chaque tick)
aux deux joueurs. Source : [backpack-battles.fandom.com/wiki/Game_Mechanics](https://backpack-battles.fandom.com/wiki/Game_Mechanics) —
*« That happens when 17 seconds have passed »*.

**Précision / miss** : Luck augmente accuracy +5 %/stack, Blind diminue -5 %/stack. Les attaques
peuvent rater.

**Crit** : double damage, influencé par des items spécifiques.

**HP total** : démarre à 25 (round 1) et monte avec les rounds : 25→35→45→55→70→85→100…→350
(round 18). La montée progressive des PV parallèle à la montée des dégâts des items crée une
inflation intentionnelle.

### 5.2 Comparaison avec The Pit

| Axe | Backpack Battles | The Pit |
|-----|-----------------|---------|
| Modèle | Timeline temps réel, tous items activent en parallèle selon cooldown | Cooldown par entité, résolution séquentielle (`tickDots` + frappe) |
| Déterminisme | RNG en combat (crit %, dodge %, damage ranges) | **Déterministe à 100 %** (RNG injecté, pas de dé en combat) |
| Fatigue | 17s → 1+n dégâts/s | `FATIGUE_START = 1020` ticks (~17s @ 60fps) — même valeur ! |
| Durée | ~10-20s | Similaire (golden conclut avant Fatigue) |
| Missrate | Oui (Luck/Blind) | Non (ciblage déterministe, zéro miss) |

The Pit a adopté le bon modèle. La timeline parallèle de Backpack génère des **bugs de boucles
infinies documentés** (items qui se triggent mutuellement indéfiniment) — [autobattler-design.md §4]
le mentionne comme « bugs documentés ». Notre modèle cooldown par entité (séquentiel) est plus
simple ET déterministe, ce qui est un pré-requis absolu pour les snapshots async.

**Le déterminisme de The Pit est un AVANTAGE concurrentiel** sur Backpack. Dans Backpack, un
même build peut avoir des résultats différents à cause du RNG en combat (damage ranges, crits,
dodges). L'adversaire ne peut pas « rejouer » le même combat. Dans The Pit : même seed → même
bataille identique (golden inchangé `970156547`). Cela rend le verdict de défaite attribuable à
une DÉCISION de build, pas à la chance — qualité de jeu supérieure pour les joueurs compétitifs.

---

## 6. Recettes (recipes) — craft spatial

### 6.1 Teardown précis

**Mécanisme** : deux items adjacents dans l'inventaire → au retour au shop, ils se craftent
automatiquement en un item de rang supérieur. *« Recipe items placed next to each other in the
backpack will be combined in the next shop phase »*
([backpackbattles.wiki.gg/wiki/Recipe](https://backpackbattles.wiki.gg/wiki/Recipe)).

**Lock** : clic droit → « Reserved » pour empêcher le craft non voulu.

**Catalyst** : certaines recettes ont un item catalyseur qui reste intact pendant que les deux
ingrédients sont consommés.

**Discovery** : les recettes sont visualisées dans un « Recipe Book » avec les items non encore
craftés affichés en silhouette noire — **collection incomplète visible** = motivation de
découverte (Binding of Isaac, Pokédex).

### 6.2 Psychologie des recettes

**Combinatoire** : avec 500+ items et des dizaines de recettes, l'espace de découverte est
immense. Trouver une recipe nouvelle est une **récompense de type aha moment** — la même chose
que découvrir une synergie dans StS ou un combo dans Balatro.

**Ancrage positif** : le Recipe Book montre les silhouettes des items non découverts. C'est un
**mécanisme de progression méta visible** (même sans méta-progression de stats) — « je n'ai
pas encore découvert ce Legendary ». C'est ce que le BRIEF appelle la « découverte combinatoire »
comme source de rejouabilité.

**Craft accidentel** : la possibilité de crafter par erreur (sans voir que deux items sont
adjacents) ajoute une source de friction et d'apprentissage. Le système de lock compense.

### 6.3 Transférabilité à The Pit

**Ce qui est équivalent** : les recettes Backpack ont pour analogue nos doublons (3 copies →
niveau+1 auto, `build:checkMerges`) — un mécanisme de merge/craft avec résolution automatique.
Le principe psychologique (« trouver la combinaison gagnante ») est couvert.

**Ce qui manque** : nous n'avons pas de **Recipe Book de découverte**. Le Grimoire existe déjà
comme codex de collection (reliques rencontrées), mais pas de codex des **combos d'unités**.
Une piste de contenu futur : un « codex des synergies découvertes » (quels types adjacents ont
été craftés en auras). Coût : faible (data des synergies triggées → entrée Grimoire). Priorité :
basse (V2), mais c'est le mécanisme de méta-progression visible gratuit.

**Les recipes SPATIALES** (adjacence dans la grille → craft) sont **irréalisables dans notre
modèle** (les unités sont 1x1 sur un graphe fixe, pas des items de formes variables dans une
grille libre). Ce serait un changement d'architecture fondamental. À rejeter.

---

## 7. Snapshot asynchrone — le pilier commun

### 7.1 Teardown précis

**Mécanisme confirmé par le développeur** (source indirecte : indieark via GameDiscoverCo) :
*« le client télécharge un lot de snapshots par patch → jouable hors-ligne ; matché par
progression (+ rang en classé) »*. La formulation officielle : *« You are battling other
players' builds, but there's no time pressure or worries about interacting directly with them »*.

**Ce qui est snapshoté** : le build complet (inventaire, items, positions, équipement) + tier
de progression + rang + version du patch.

**Matchmaking** : par rang similaire + point de progression similaire dans la run.

**Offline** : le client télécharge un lot de snapshots → on peut jouer sans connexion active.

**Versions** : les snapshots sont taggés par version de patch. Quand le patch change les items,
les vieux snapshots ne sont plus servis (évite les adversaires obsolètes).

**Pas de bots** confirmé par le dev selon la documentation de recherche (`autobattler-design.md §6`) :
*« pas de bots »* (contrairement à SAP qui a des équipes IA de cold-start).

### 7.2 Comparaison avec The Pit

The Pit a **implémenté le même système** (`src/net/snapshot.lua`, `src/net/snapstore.lua`) avec
en plus le cold-start garanti par IA (`serveComp` → `aiComp` Encounter IA si aucun snapshot).

**Avantage The Pit** : cold-start résolu dès v1 (Backpack n'a pas de bots → problème de pool
vide au lancement). Notre `snapstore.lua` garantit un adversaire même sans joueurs dans le pool
(via `aiComp`).

**Lacune The Pit (v1)** : les effets aura/relique ne sont pas capturés dans le snapshot (v1 =
effets de base). Un adversaire snapshoté ne reflète pas ses reliques actives. À corriger en v2
(`00-state.md §5` : *« effets aura/relique non capturés dans le snapshot »*).

**Ce que Backpack a que nous n'avons pas** : vrai matchmaking par rang (côté serveur). The Pit
n'a actuellement pas de backend distant. La décision de ne pas implémenter le serveur temps réel
est correcte ; mais un **endpoint minimaliste** (save/serve snapshots) reste la cible.

---

## 8. Structure compétitive / Ranked

### 8.1 Teardown précis

**8 rangs** (source : [backpackbattles.wiki.gg/wiki/Game_Mechanics](https://backpackbattles.wiki.gg/wiki/Game_Mechanics)) :
Bronze → Silver → Gold → Platinum → Diamond → Master → Grandmaster → **Grandma** (rang le plus
élevé, nom volontairement absurde/grimdark-light).

**Par personnage, pas par loadout** : on peut avoir un Berserker Diamond et un Reaper Bronze.
Les rangs ne se transfèrent pas entre classes.

**Départ** : tous les joueurs commencent en Bronze.

**Matchmaking** : matché par rang similaire + progression dans la run. Pas de détail public
sur la formule exacte de points.

**Mode Unranked** : *« Low pressure without timers »* — permet de jouer sans enjeu.
**Mode Ranked** : *« Gain points against equal opponents, but still at your own pace »*.
**Custom rules** : or, santé max, règles modifiées (exclu du pool ranked).

Source : [store.steampowered.com/app/2427700](https://store.steampowered.com/app/2427700/Backpack_Battles/?l=english)

**Saisons** : non documenté en détail dans les sources disponibles pour Backpack Battles.

### 8.2 Psychologie du ranked

**Le « réenchaîner pour grimper »** de Backpack tient à plusieurs leviers :
1. **Le rang est par personnage** : si on veut explorer une autre classe, on repart de zéro.
   C'est un FOMO de progression différencié — chaque classe est un « personnage » à monter.
2. **Grandma comme rang ultime** : la touche d'humour absurde dans un jeu sans DA cohérente
   (Backpack n'a pas de DA grimdark) crée un moment de connivence.
3. **Unranked disponible** : la bifurcation pression/détente permet de tester des builds sans
   enjeu avant de les jouer en ranked. Réduit la frustration des « mauvaises runs ».

**Critique** : les forums Steam révèlent une faiblesse majeure : *« no, the game has no
progression system »* (Steam discussions, [2024-03-11](https://steamcommunity.com/app/2427700/discussions/0/4290313152636615559/)).
Les joueurs cherchaient une méta-progression (unlock initial, amélioration cross-run) et
n'en trouvaient pas. Le rang seul ne suffit pas à long terme sans collection ou Grimoire.

### 8.3 Transférabilité à The Pit

**Ce qui transige directement** :
- Bifurcation **Unranked / Ranked** : bon pattern à adopter. Dans The Pit : mode
  Unranked = run normale contre ghosts IA/pool ; mode Ranked = matchmaking par tier de ghost
  (progressif, pas de tier rush). La formulation « sans pression mais à votre rythme » est
  exactement notre modèle async. **Priorité : haute** (structure fondamentale du ranked à concevoir,
  zone vierge identifiée dans `00-state.md §7`).

- **Rangs par archétype/sigil** plutôt que par classe : The Pit n'a pas de classes, mais des
  sigils et des archetypes. On pourrait imaginer un rang général ou des rangs par « archétype
  dominant » (poison build, tank build…). À débattre dans les rounds de lab.

- **Anti-snowball** : Backpack n'a pas documenté de mécanisme anti-snowball dans son ranked.
  The Pit a des garde-fous (`DOT_CAP_MULT = 3`, `BLEED_DPS_CAP = 12`, `SHOCK_STACK_CAP = 8`) —
  avantage concurrentiel pour un ranked sain.

**Ce qui ne transfère PAS** :
- *Rangs par personnage* (Backpack a 4 classes explicites) : dans The Pit, il n'y a pas de
  personnage choisi. La progression ranked doit être pensée différemment (par tier de run ?
  par score cumulatif ? à concevoir ex nihilo).

---

## 9. La question des classes — architecture de build variety

### 9.1 Teardown

Backpack a **4 classes jouables** (Berserker, Pyromancer, Reaper, Ranger) + **sous-classes**
(au round 8, shop spécial de sélection de sous-classe). Chaque classe a des items exclusifs
dans le pool (voir §3.3 : Ranger a 3 Rares spécifiques, Reaper a 2 Rares spécifiques, etc.).

**Effets des classes** :
- Items de classe disponibles en boutique (pool conditionnel)
- Items qui s'activent selon des « Pets » spécifiques à la classe, « Spells », « Cards », etc.
- Sous-classe au round 8 : Berserker peut devenir Shaman (Shaman Mask) ou Wolf (Wolf Emblem),
  chacun débloqueant un pool d'items spécifique.

**Conséquence** : 4 × 2 sous-classes = 8 branches de jeu. La majorité des 500+ items sont
transversaux mais les classes poussent vers des archetypes différents.

### 9.2 Transférabilité à The Pit

**The Pit n'a pas de classes** — c'est une décision actée (roster universel, pas de gatekeeping).
L'équivalent de la build variety par classe dans The Pit, c'est la combinaison **sigil + archétype
DoT + reliques**. C'est une approche différente : au lieu de choisir une classe au départ, on
découvre son archétype à travers les items disponibles et les reliques offertes.

**Avantage The Pit** : moins de charge cognitive initiale (pas de choix de classe bloquant).
La découverte d'archétype est plus organique (SAP-like).

**Manque identifié** : sans classe, il n'y a pas de **point d'ancrage d'identité** pour le joueur
(« je suis un joueur Poison » vs. « je suis un Reaper »). La mémoire projet identifie ce manque
(`BRIEF.md §Contenu` : synergies par TYPE encore TODO). Les synergies par type (unités partageant
un type : Culte, Noyés, Engeance...) sont l'équivalent des classes implicites de The Pit.
**C'est la zone à compléter en priorité.**

---

## 10. Méta-progression — la faiblesse documentée de Backpack

### 10.1 Teardown

Backpack Battles **n'a pas de méta-progression** au sens traditionnel : aucun unlock cross-run,
aucune amélioration persistante, aucun « character roster » à déverrouiller. Seul le rang est
persistant (et les records/achievements Steam).

**Le Recipe Book** (silhouettes des items non craftés) est la seule forme de collection.

**Réaction de la communauté** :
*« It feels disappointing... like playing Vampire Survivors, but nothing changes/grows/evolves.
The first few games are gonna be exactly the same as any number of games »*
(Steam discussions, [2024-03-11](https://steamcommunity.com/app/2427700/discussions/0/4290313152636615559/)).

Cela a été un point de friction significatif en early access — même avec 92 % de reviews positives,
c'est la critique récurrente.

### 10.2 Psychologie et verdict

**Pourquoi Backpack s'en sort malgré tout** : la découverte combinatoire (500+ items, recipes,
synergies) est elle-même la méta-progression — « le prochain run, j'essaie ce combo que j'ai
découvert ». C'est une méta-progression implicite d'expertise, pas de stats. Le rang ranked
ajoute une dimension de progression explicite.

**Ce que The Pit a de plus** : le **Grimoire** (`src/core/grimoire.lua`) est notre méta-progression
explicite cross-run. Une relique apprise est identifiée à jamais (collection). C'est supérieur au
Recipe Book de Backpack car :
1. Lié à un objet avec lore (flavor text grimdark)
2. Persistant avec mémoire explicite (« j'ai trouvé Forked Tongue au run 47 »)
3. Décision active (choisir d'explorer de nouvelles reliques vs. reroll les connues)

**La leçon à ne pas oublier** : le Grimoire **seul ne suffit pas**. Si les reliques sont rares
(3/run actuel), la progression du Grimoire est trop lente. Le PRD `progression-economy-prd.md`
l'a résolu : 5-6 reliques/run (marchand /3 combats + level-up récompense). C'est le bon
calibrage pour que le Grimoire se remplisse à une vitesse satisfaisante.

---

## 11. Onboarding & courbe d'apprentissage

### 11.1 Teardown Backpack

**Point de départ** : 1 classe, 1 sac de départ (choix entre 2), 12-14 tuiles, 12g. Shop de 5
items. Run = 10 victoires avant 5 défaites. La règle est apprise en 30 secondes.

**Frictions early** :
- Les adjacences ★ (star triggers) ne sont pas toujours visibles sans hover.
- La rotation des items (quelle forme, dans quel sens) demande de la pratique.
- Les recettes sont cachées jusqu'à la première découverte (sauf le Recipe Book avec silhouettes).
- L'inventaire peut saturer si on n'achète pas de bags en priorité.

**Ce qui facilite** : le combat dure 10-20s et le résultat est immédiat → feedback loop rapide.
Un run perdu prend ~10-15 minutes maximum (10 rounds × ~2 min/round). La barrière de relance
est faible.

### 11.2 Transférabilité à The Pit

**Bonne leçon** : le run court (10 victoires) est la bonne unité. The Pit a fait le même choix.

**Mauvaise leçon à éviter** : les frictions d'onboarding de Backpack (triggers invisibles, formes
complexes) viennent de la richesse même du système. The Pit est structurellement plus simple
(9 cases 1x1, pas de rotation, adjacences sur le graphe = toujours visibles si l'UI les montre).
L'item UI manquant — **surligner les arêtes actives en build** — est prioritaire pour l'onboarding.

**La lisibilité des sigils** : changer de sigil (`[s]`) est une décision invisible sans feedback
clair sur ce que ça change pour l'exposition des unités. Le `depth` (front/back déterminé par
la forme du sigil) doit être visible dans l'UI de build. Backpack fait mieux ici : l'inventaire
visualise immédiatement les formes et adjacences.

---

## 12. Synthèse adversariale — verdicts de transférabilité

### 12.1 Mécanismes qui SURVIVENT à nos contraintes

| Mécanisme Backpack | Survit à The Pit ? | Adaptation concrète |
|--------------------|-------------------|---------------------|
| Cotes progressives par round | **OUI** (déjà implémenté) | Notre système XP-gating avec tier 1-5 est l'équivalent plus contrôlé. Le calibrage exact est ouvert (Lot 7 PRD). |
| Run 10 victoires / 5 défaites | **OUI** (identique) | Déjà implémenté, aucune adaptation. |
| Snapshot async + offline | **OUI** (déjà implémenté) | Avantage The Pit : cold-start IA garanti ; lacune : effets reliques non capturés (v2). |
| Bifurcation Unranked / Ranked | **OUI (à implémenter)** | Ranked = matchmaking par tier de ghost ; Unranked = run standard. Priorité haute. |
| Reroll escaladant (1g → 2g) | **OUI (à valider)** | Déjà envisagé en PRD §7 comme option anti-spam. À activer si le fuzz montre du churn dégénéré. |
| Collection/discovery visible | **OUI (en partie)** | Grimoire = reliques ; codex synergies discovées = V2. |
| Combat Fatigue à 17s | **OUI (identique)** | `FATIGUE_START = 1020 ticks ≈ 17s` — convergence indépendante sur la même valeur. |
| Feedback adjacences actives en UI | **OUI (manquant)** | Surligner les arêtes actives du graphe en phase build. Coût faible, impact lisibilité fort. |

### 12.2 Mécanismes qui NE SURVIVENT PAS

| Mécanisme Backpack | Raison du rejet | Substitut dans The Pit |
|--------------------|----------------|------------------------|
| Grille spatiale 2D (formes + rotation + 63 tuiles) | Hors-budget archi + hors-scope LÖVE solo dev. La richesse combinatoire vient de la grille libre : non reproductible sans refonte totale. | Plateau-graphe 3×3 + 5 sigils (topologie variable = profondeur différente mais réelle) |
| Recettes spatiales (adjacence → craft auto d'item) | Dépend de la grille spatiale. Irréalisable sans les formes d'items variables. | Merge duplicatas 3→niveau (même psychologie : « trouver la bonne combinaison ») |
| Report d'or entre rounds | Ajoute un axe de gestion incompatible avec la brièveté du run (10 victoires). Risque de spirale de mort validé playtest The Pit (PIège identifié PRD §3.1). | Or frais/round (modèle SAP) — plus simple et équilibrable |
| RNG en combat (crits, dodge, damage range) | Viole le déterminisme (pilier #2). Un snap ne serait plus rejouable identiquement. La défaite deviendrait attribuable au dé, pas au build. | Déterminisme complet (seed injecté, zéro dé en combat) — AVANTAGE concurrentiel |
| Rangs par classe | The Pit n'a pas de classes. L'identité de build vient du sigil + archétype DoT + reliques. | Ranked général + synergies par TYPE (TODO majeur) comme substitut des identités de classe |
| Sous-classes (round 8) | Surcoût d'implémentation, incompatible avec la structure actuelle (pas de personnage player). | Offre de relique G (sigil topologie) comme substitut de « choix d'archétype mid-run ». |
| Unique items (2-3 % one-shot, 1 max) | Concept transférable mais actuellement pas de slot « unique » dans le modèle reliques The Pit. | Reliques transformatives de vague 4 (Forked Tongue, Plague Communion…) jouent le rôle de Unique sans être hors-système. |

### 12.3 Analogies paresseuses à démolir

**1. « Backpack fait de l'adjacence, The Pit aussi → on est pareils »**

FAUX. L'adjacence Backpack est **dans une grille libre 2D à items de formes hétérogènes** où le
puzzle est physique (quelle pièce rentre où). L'adjacence The Pit est **dans un graphe explicite
à 9 nœuds** où le puzzle est stratégique (qui buffe qui, quel archétype vouloir au centre). Ce
sont deux mécaniques différentes avec la même étiquette. Toute comparaison directe de profondeur
est invalide.

**2. « Backpack n'a pas de méta-progression → ce n'est pas un problème »**

FAUX pour The Pit. Backpack compense l'absence de méta-progression par 500+ items et une
communauté de découverte combinatoire (Recipe Book, streams, wikis). The Pit a un roster de
83 unités et 21 reliques — la découverte combinatoire est plus courte à épuiser. Le Grimoire
est nécessaire pour compenser, et son remplissage doit être rapide (5-6 reliques/run).

**3. « Backpack n'a pas de RNG en combat → ils ont eu tort »**

INCORRECT : Backpack HAS RNG en combat (crits, dodge, damage ranges). Ce sont des décisions de
design légitimes pour un jeu à timeline parallèle visible. The Pit a fait le choix opposé
(déterminisme) pour ses besoins propres (snapshots verifiables, verdicts de build attribuables).
Ce n'est pas « mieux » ou « pire » — c'est deux philosophies différentes. The Pit ne doit pas
introduire de RNG en combat pour « ressembler à Backpack ».

**4. « Backpack a vendu 650 000 copies en 1 mois → copions sa formule »**

FAUX comme conclusion. Les 650k copies tiennent à la **combinaison unique** d'un mechanic
novel (le sac), d'un moment de marché (EA Steam mars 2024, très peu de concurrents directs),
d'une distribution (IndieArk pour le marché asiatique), et d'une DA accessible (minimaliste,
couleurs claires). The Pit est en position différente sur chaque dimension. Ce qui est
transférable : le pattern async snapshot comme vecteur de PvP sans netcode — qui est déjà
implémenté. Ce qui ne l'est pas : le mécanisme spatial ou les 500+ items d'un studio qui
y a travaillé 2 ans.

---

## 13. Lacunes identifiées dans The Pit — par priorité

Issues issues directement de l'analyse Backpack, avec priorité relative :

| Lacune | Origine Backpack | Impact The Pit | Priorité |
|--------|-----------------|----------------|----------|
| Feedback visuel adjacences actives en build | Wiki « adjacency ★ surlignées » | Lisibilité synergies build — onboarding | **HAUTE** |
| Structure Ranked / Unranked | Wiki ranked 8 tiers | Zone vierge #1 du lab, retention long terme | **HAUTE** |
| Synergies par TYPE d'unité | Classes avec pools dédiés | Identité d'archétype, profondeur de build variety | **HAUTE** |
| Vitesse de remplissage du Grimoire | Recipe Book + 500+ items | 5-6 reliques/run (PRD déjà décidé, à implémenter) | **MOYENNE (déjà décidée)** |
| Feedback sigil en build (exposition front/back) | Adjacences visuelles claires | Lisibilité du plateau, choix éclairé de sigil | **MOYENNE** |
| Codex des combos/synergies découvertes | Recipe Book (silhouettes) | Méta-progression implicite d'expertise | **BASSE (V2)** |
| Effets reliques/aura dans les snapshots | Snapshots complets (items + effets) | Fidélité du ghost adverse | **BASSE (V2)** |

---

## 14. Note sur la compétitivité — ce que Backpack enseigne sur la rétention

**Chiffre clé** : 92 % Very Positive (5 321 avis en 2026). Backpack a maintenu une communauté
2+ ans après son EA. Facteurs identifiés :

1. **Sessions courtes** (~15-20 min/run) → accessible, « one more run ».
2. **Pas de timer en lobby** (async) → zéro stress social.
3. **Progression de rang visible** → motivation extrinsèque à long terme.
4. **Discovery / profondeur** → les 500+ items et recettes restent à explorer longtemps.
5. **Updates régulières** (patch 1.0.7 visible → plusieurs patches par an).

**Ce que The Pit reproduit** (points 1, 2, 3 avec Grimoire et ranked à venir) et **améliore**
(déterminisme → verdict de build clair ; DA grimdark → cohérence et immersion supérieures ;
pixel art procédural → personnages uniques qui appartiennent au joueur).

**Ce que The Pit n'a pas encore** : le volume de contenu (83 unités vs 500+ items). C'est une
réalité de solo dev vs. studio. La stratégie correcte : **profondeur d'interactions** (4 familles
DoT × synergies croisées × sigils × reliques) > **largeur de contenu** (plus d'unités). Le
modèle SAP (10-12 commons) confirme que la largeur n'est pas le facteur critique.

---

*Rédigé le 2026-06-23. Sources vérifiées en ligne (URLs citées). Lecture seule du repo.*
*À challenger dans les rounds suivants : verdict du ranked, profondeur du feedback build,
priorité des synergies par TYPE.*
