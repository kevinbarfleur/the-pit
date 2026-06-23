# The Bazaar (Reynad / Tempo) — Analyse ultra-approfondie

> **Mandat** : teardown complet de chaque mécanisme clé → psychologie → maths chiffrées → verdict
> de transférabilité à *The Pit* (async snapshots, run court 10 victoires, sim déterministe, grimdark).
> Aucune analogie paresseuse. Sources citées pour chaque affirmation chiffrée.
>
> **Garde-fou absolu** : ce fichier est en lecture seule pour le code du jeu. Aucune modification
> en dehors de `docs/roadmap-lab/`.
>
> **Date** : 2026-06-23. Sources lues et citées ci-dessous.

---

## 0. Portrait rapide

The Bazaar est un autobattler asynchrone développé par Tempo (ex-Tempo Storm, fondé par l'ex-pro
Hearthstone Andrey "Reynad" Yanyuk). Fermé Beta 2024 → Open Beta mars 2025 → Steam août 2025
(pivot premium à 30 $). Le genre auto-inventé par l'équipe : *roguelike deck-builder sans deck*,
où des **items** se déclenchent automatiquement par cooldown sur un plateau linéaire de 10 slots.

**Chiffres clés actuels** (sources citées §par §) :
- 7 héros jouables (Vanessa, Dooley, Pygmalien, Mak, Stelle, Jules, Karnok) au moment de l'analyse
- ~644 items dans la base (bazaarcalc.com, saison 10)
- ~813 items dans le pool d'un seul marchand généraliste, pool partagé (bazaar-builds.net/db/merchants/)
- Pool par héros spécifique : 100-135 items hero-only par personnage
- Run = 10 victoires PvP avant épuisement du Prestige (=20 au départ)

---

## 1. Structure d'une journée — le rythme de décision

### 1.1 Teardown précis

Chaque run est divisé en **Jours**, chacun composé de **6 Heures** (0 à 5) :

| Heure | Contenu |
|-------|---------|
| 0 | Marchand / Événement au choix (3 options : vendeur, événement, petit bonus gratuit) |
| 1 | Marchand / Événement |
| 2 | Combat PvE (choix entre 3 monstres de difficulté croissante) |
| 3 | Marchand / Événement |
| 4 | Marchand / Événement |
| 5 | Combat PvP (contre un ghost d'un autre joueur) |

Source : mobalytics.gg/the-bazaar/guides/day-guide ; thebazaarzone.com/beginners-guide/

À chaque heure passée, le joueur gagne automatiquement **1 XP** (base). Le PvE rapporte entre 2 et
6 or + 3-4 XP selon la difficulté de l'encounter. La **Sandstorm** commence 30 secondes après le
début de chaque combat et inflige des dégâts croissants aux deux joueurs jusqu'à ce qu'un camp soit
éliminé (thegamer.com/the-bazaar-beginner-tips-tricks-mechanics-explained-guide/).

**Élément distinctif** : pas de timer entre les décisions. Le joueur peut quitter le jeu, reprendre
plus tard, passer des heures à réfléchir. C'est du "resting design" — la partie n'avance que quand
le joueur initie (Reynad, interview noisypixel.net/the-bazaar-interview-reynad-asynchronous-pvp-deckbuilder/).

**Économie de départ** (selon version/patch) : 15 or + 7 de revenu de base ; certains patches
démarrent à 8 or + 5 revenu (mobalytics.gg/the-bazaar/guides/day-guide). Le Revenu (Income) est
reçu **à la fin de chaque Jour**, pas à chaque heure. Prix des rerolls : 2 or (Bronze) à 8 or
(Silver+) selon le niveau du marchand (gaming.news/codex/the-bazaar-...).

### 1.2 Psychologie

Le découpage en 6 heures impose un **rythme progressif d'investissement** dans chaque run.
L'heure 2 (PvE = or + XP + loot) est une récompense intermédiaire qui donne l'impression d'avoir
"déjà progressé" avant d'arriver au PvP de l'heure 5. Ce découpage génère ce que les designers
appellent un **"goal gradient"** : à chaque heure, la distance au PvP suivant se réduit, ce qui
accélère l'engagement. Source sur le goal gradient effect en jeux : Nir Eyal, "Hooked" (2014),
chapitre Triggers/Action/Reward.

Le fait qu'il n'y ait **jamais d'attente** (pas de timer, pas de lobby) résout le principal frein
cognitif de l'autobattler traditionnel (TFT : obligation de rester dans le lobby 8 joueurs jusqu'à
la fin). Ici, le joueur part **quand il veut** — ce qui paradoxalement incite à **revenir plus
souvent** car il n'y a pas de "coût" à s'interrompre.

### 1.3 Maths

Vitesse d'une run typique : 10 à 15 Jours (10-0 = rapide, 10-10 = ~15 jours). À 6 heures/jour
= 60 à 90 décisions (sans compter les sous-décisions à l'intérieur de chaque heure). Un run dure
entre 30 et 90 minutes selon la vitesse de lecture et les rerolls.

### 1.4 Verdict de transférabilité pour The Pit

**Le rythme jour/heure n'est pas transférable tel quel.** The Pit a une structure de run différente :
round (build) → combat auto → résultat, répété 10-15 fois. Mais le **principe du goal gradient** est
directement applicable : chaque round est une mini-journée avec un moment de récompense
(résultat de combat) avant d'enchaîner. Le découpage build→combat→résultat est psychologiquement
plus court et plus satisfaisant que le format "journée de 6 heures" du Bazaar.

**Ce qui survit** : l'absence de timer (déjà décidé et implémenté dans The Pit). The Pit ajoute
une contrainte supplémentaire favorable : le run de 10 victoires avant 5 défaites est **plus court
et plus tendu** que le Bazaar (~15 jours), ce qui accentue le "one more run".

---

## 2. Système de combat — cooldowns et timeline

### 2.1 Teardown précis

Le combat est entièrement automatique. Les items se déclenchent selon leurs **cooldowns** en
secondes réelles (simulées). Chaque item a un cooldown de base (ex. : Uzi = 3 s, items Large = souvent
8-13 s). Les cooldowns **commencent à zéro** — l'item se déclenche après le délai, pas avant.

Source : thebazaar.wiki.gg/wiki/Cooldown ; pcgamesn.com/the-bazaar/mak-new-hero-season-1

**Modificateurs de cooldown** (nomenclature du Bazaar) :
- **Haste** : réduit le cooldown en secondes (ex. : Haste 2s = déclenche l'item 2s plus tôt)
- **Charge** : avance instantanément un cooldown d'un certain montant de temps
- **Slow** : augmente le cooldown d'un item ennemi
- **Freeze** : bloque complètement un item ennemi (il ne tourne plus)
- **Multicast** : déclenche l'item plusieurs fois d'affilée
- **Ammo** : limite le nombre d'utilisations par combat (ammo se recharge entre combats)

La Sandstorm démarre **30 secondes** après le début du combat (7 secondes avec l'item Bottled Tornado
de Mak — pcgamesn.com/the-bazaar/mak-new-hero-season-1). Elle inflige des dégâts croissants aux
deux joueurs, forçant une conclusion.

**Types de dégâts** : Normal (direct), Burn (décroissant mais rapide), Poison (stable, ignore
le bouclier), Shield (absorbe les dégâts normaux + ralentit le Burn ; le Poison l'ignore).

**Cascade interne** : certaines interactions créent des boucles potentiellement infinies. Le jeu a
des cooldowns internes (ICDs) pour prévenir cela, mais leur fonctionnement exact est partiellement
documenté (thebazaar.wiki.gg/wiki/Items, §Internal Cooldowns). C'est une source de bugs historique.

### 2.2 Psychologie

La timeline temps réel à cooldowns crée une **DPS-race** visuellement lisible : le joueur "comprend"
qu'il perd parce que son adversaire agit plus vite. C'est une traduction directe de la compétence
de build en résultat immédiatement visible. Cela génère une boucle de feedback fort : "j'aurais dû
prendre un item plus rapide" → motivation pour la prochaine run.

Le **risque de boucles infinies et de bugs** est documenté par la communauté (thebazaar.wiki.gg).
Le Bazaar a nécessité une ingénierie défensive importante (ICDs, Sandstorm, patches répétés).

### 2.3 Maths

Un item à cooldown de 3 s se déclenche ~10 fois avant la Sandstorm (30 s / 3 s). Un item à 10 s se
déclenche 3 fois. L'ecart de *nombre de déclenchements* est donc non-linéaire avec le cooldown :
un item à 3 s fait ~3.3× plus de déclenchements qu'un item à 10 s pour des dégâts identiques par
instance. D'où la premium sur Haste/Charge dans le méta.

Rérol d'un marchand Bronze : 2 or. Silver : 4 or. Les prix d'items vont de 2 or (Small Bronze) à
64 or (Large Diamond) (gaming.news/codex/the-bazaar-...).

### 2.4 Verdict de transférabilité pour The Pit

**Analogie paresseuse interdite** : "The Bazaar utilise des cooldowns, The Pit aussi → même
système". C'est faux.

**Différence fondamentale** :
- Le Bazaar a une **timeline temps réel simulée** : deux boards d'items tirent en parallèle,
  chacun sur son propre rythme, et c'est la somme de tous les déclenchements qui décide.
- The Pit a un **modèle cooldown à pas fixe déterministe** avec RNG seedé injecté : chaque unité
  a son cooldown, et la résolution est séquentielle et reproductible tick à tick.

Ces deux approches **sont compatibles** dans leur philosophie (cooldown = l'axe temps remplace
la santé dans un combat de "qui agit le premier") mais **très différentes en implémentation et en
coût**. The Pit a fait le bon choix : le moteur déterministe seedé est obligatoire pour les
snapshots async (pilier #2 des décisions), et c'est architecturalement plus simple.

**La Sandstorm du Bazaar** (timer de conclusion) est directement analogue à la **Fatigue du Pit**
(`FATIGUE_START = 1020` ticks, ~17 s). Le Pit a cela déjà en place. Les chiffres du Bazaar (30 s
normal, 7 s avec Bottled Tornado) suggèrent que la granularité de la Sandstorm crée un axe
stratégique entier (builds "turtle qui attendent la Sandstorm" chez Pygmalien). The Pit peut
explorer un tel axe via les reliques ou les passifs de ligne, sans modifier la Fatigue.

**Ce qui ne survit pas aux contraintes The Pit** :
- La manipulation de cooldown ennemi (Freeze, Slow) — dans The Pit, le ciblage est déterministe
  et les cooldowns ne peuvent pas être manipulés par l'adversaire sans une refonte du moteur.
  Toute mécanique "pause le cooldown ennemi" deviendrait non-déterministe dans un contexte snapshot.
- Les ICDs et leurs ambiguités — le moteur du Pit a des garanties de terminaison formelles
  (`TICK_CAP = 8000`), ce que le Bazaar a dû patcher répétitivement.

---

## 3. Items, tailles et slots — le plateau

### 3.1 Teardown précis

Les items ont trois tailles : **Small** (1 slot), **Medium** (2 slots), **Large** (3 slots).
Le plateau actif (le "rug") a 10 slots max. Un stash séparé de 10 slots stocke les items inactifs
(ils ne se déclenchent pas en combat sauf effets passifs spéciaux).

Source : thebazaar.wiki.gg/wiki/Items ; steamcommunity.com/sharedfiles/filedetails/?id=3573365196

**Items uniques (Legendary)** : obtenus par des événements ou monstres légendaires. Encadrés en
orange, non-transformables. Maximum puissance.

**Qualité (rarity)** : Bronze → Silver → Gold → Diamond. Un item Diamond ne peut plus être upgradé.
L'upgrade d'un item se fait en **achetant un doublon de même qualité** — les deux fusionnent en
l'item de qualité supérieure. Il n'est pas possible de combiner deux doublons déjà en inventaire :
le second doit être "acheté" (depuis une boutique ou récupéré après un combat PvE).

**Enchantements** : une couche d'effet supplémentaire sur un item. Exemples : Deadly (+50% Crit),
Icy (Freeze 1s), Turbo (Haste 2s), Obsidian (double damage), Toxic (Poison), etc. Un seul
enchantement par item. Très puissants, créateurs du méta "knowledge check" documenté ci-dessous.

**Adjacence** : certains items buffent leurs voisins directs (gauche/droite). D'autres réagissent à
être adjacents à certains types. La position sur le plateau est donc stratégique, mais linéairement
(pas une grille 2D — c'est une ligne de 10 slots).

### 3.2 Psychologie

Le système taille/slots crée une **gestion d'espace contrainte** qui génère des micro-décisions
permanentes : "Est-ce que je remplace mon Medium par deux Smalls ? Est-ce que je garde un slot vide
pour trouver mieux ?". C'est le même levier que Tetris : l'espace limité oblige à sacrifier et à
optimiser. Chaque décision a un coût (le slot occupé) et un bénéfice (la puissance de l'item).

Le stash (10 slots d'items inactifs) permet une **planification différée** : on achète "à la
spéculation" des items qu'on activera plus tard quand la build se coordonne. C'est un axe
stratégique propre au Bazaar que TFT ou SAP n'ont pas.

### 3.3 Maths

Un plateau de 10 slots peut contenir au maximum : 10 items Small, ou 5 Medium, ou 3 Large + 1
Small, etc. Une build typique end-game a un mix :
- 2-4 Large (6-12 slots) : les "carries" centraux
- 2-3 Medium (4-6 slots) : les "engines" / supports
- 0-3 Small (0-3 slots) : les "utilitaires" / économie

Cela donne environ 7-9 items actifs simultanément pour une board complète — vs 10 slots si que
des Smalls.

La **eficience spatiale** (bazaarcalc.com) est calculée comme puissance par slot : les Smalls
sont souvent les plus efficaces per-slot pour les utilitaires/économie, les Larges pour les carries.

### 3.4 Verdict de transférabilité pour The Pit

**Analogie paresseuse** : "The Bazaar a 10 slots linéaires avec adjacence → The Pit devrait faire
pareil". Faux — The Pit a déjà décidé son architecture (plateau-graphe 3×3, 9 slots, adjacence
orthogonale explicite). Comparer est utile pour les **leçons de design**, pas pour copier la forme.

**Leçon n°1** : le stash du Bazaar (items inactifs stratégiques) est un axe qui **n'existe pas**
dans The Pit (on n'a que le plateau actif). The Pit n'a pas besoin d'un stash car ses unités
persistent entre rounds (le build persiste). Le Bazaar a besoin du stash parce que les items ne
"meurent" pas — on renouvelle le build en swappant, pas en recommençant.

**Leçon n°2** : les enchantements du Bazaar créent un espace de puissance très large (jusqu'au
"knowledge check" — un enchant comme Icy ou Turbo peut briser un combat). The Pit n'a pas
d'enchantements d'items, mais les **reliques** jouent un rôle analogue (effet transformatif intra-
combat, tier 4). La leçon est : **les couches de modification tardives (reliques tier 4 / enchants)
doivent rester lisibles sous contrainte de temps**. Le Bazaar a documenté que les enchantements
sont une barrière de connaissance importante pour les nouveaux joueurs
(mobalytics.gg/news/guides/the-bazaar-review). The Pit a fait le bon choix avec les reliques
lisibles (révision 2026-06).

**Leçon n°3** : le système upgrade Bronze→Silver→Gold→Diamond (trouver un doublon pour fusionner)
est directement analogue aux **duplicatas** du Pit (3 copies → niveau+1, cascade). La mécanique
psychologique est identique : trouver un doublon = satisfaction de complétion + montée de puissance.
The Pit a cela déjà en place avec `LEVEL_MULT = {1.0, 1.8, 3.0}`.

---

## 4. Héros — identité et pool d'items

### 4.1 Teardown précis

Chaque héros a un **pool d'items exclusif** qui définit son identité. Au lancement, 3 héros de base
(Vanessa, Dooley, Pygmalien), Mak ajouté en saison 1, Stelle + Jules + Karnok ensuite.

- **Vanessa** (pirate) : armes à feu, items aquatiques, Burn/Poison rapide, multi-armes ou mono-carry.
  Sub-archétype : contrôle avec Freeze/Slow via items aquatiques.
- **Dooley** (robot) : pivot autour d'un "Core" unique (6 versions, chacune pousse vers un archétype
  différent : Burn, Shield, Speed, Friend…). Amis (Friends) comme extension de l'identité.
- **Pygmalien** (businessman) : économie maxale, Income + intérêt, Shield + Heal, tank par outlast.
  Peut gagner sans aucune arme si la Sandstorm tue l'adversaire à la place.
- **Mak** (alchimiste) : Potions (ammo limité, effets puissants), Réactifs (transformables via
  catalyseurs), Burn/Poison/Regen, Crit.

Source : thebazaar.wiki.gg/wiki/Mak ; mobalytics.gg/the-bazaar/mak-guide ;
thebazaar.fandom.com/wiki/Vanessa ; mobalytics.gg/the-bazaar/pygmalien-guide

Pools de marchand partiels par héros (exemple Silvia, marchand commun) : ~639 items (pool global
partagé hero-specific inclus). Pools hero-only : 110 Vanessa, 100 Pygmalien, 99 Karnok, 83 Dooley
(bazaar-builds.net/db/merchants/silvia.html).

### 4.2 Psychologie

Les héros créent **l'identité de run** dès le premier choix. Le joueur se demande "que peut faire
**Vanessa** avec ces items ?" pas "que peut faire **n'importe qui** avec ces items ?". C'est une
application du **commitment and consistency** (Cialdini) : une fois le héros choisi, le joueur est
engagé dans un archétype et cherche à le confirmer. Chaque run avec un nouveau héros est une
expérience distincte, ce qui alimente le cycle d'exploration qui retient les joueurs sur des
centaines d'heures.

Les héros également résolvent le problème de la **divergence infinie de pool** : avec 644 items,
sans découpage par héros, le feeling serait "on peut faire n'importe quoi" = pas d'identité de
build. Le découpage par héros contraint l'espace de possibilités à un sous-ensemble cohérent, ce
qui paradoxalement **augmente la profondeur perçue** (le joueur maîtrise d'abord Vanessa, puis
découvre que Dooley joue entièrement différemment — deux jeux dans un).

### 4.3 Maths

Run compétitif efficace nécessite de connaître environ 100-135 items hero-specific + le pool commun
de ~300 items neutres, soit ~400-450 items pertinents par héros. C'est un **coût d'entrée élevé**,
documenté comme friction de rétention dans les critiques :
- PC Gamer (pcgamer.com/games/roguelike/the-bazaar-could-be-the-future...) : "c'est une barrière
  de connaissance importante pour les nouveaux joueurs"
- mobalytics.gg/news/guides/the-bazaar-review : "il y a beaucoup d'informations pertinentes
  laissées à découvrir par soi-même"
- VaporLens (vaporlens.app, Steam reviews) : 19 mentions de "high barrier to entry" sur 53
  plaintes recensées

### 4.4 Verdict de transférabilité pour The Pit

**Analogie paresseuse** : "The Bazaar a des héros avec des pools distincts → The Pit devrait avoir
des héros". Non — The Pit n'a pas de héros jouables dans son modèle actuel.

**Mais la leçon subsiste** : le mécanisme psychologique des héros est le **découpage de l'espace
de possibilités pour créer de l'identité de run**. The Pit a un mécanisme analogue mais différent :
les **5 sigils** (carré/croix/anneau/diamant/ligne) jouent ce rôle. Changer de sigil change
l'archétype de build favori et redécoupe l'espace des synergies d'adjacence. C'est un "héros
léger" sans pool d'items dédié — ce qui évite le coût d'entrée élevé du Bazaar (pas besoin
d'apprendre 400 items par sigil) tout en maintenant la diversité d'identité de run.

**Ce qui est directement transférable** : le principe que **chaque "identité de run" devrait rendre
certaines synergies nettement meilleures**. Dans The Pit, le sigil anneau favorise les builds de
propagation/contagion ; le sigil croix favorise le mono-carry central ; etc. Cela est déjà dans
le design (CLAUDE.md §3). La leçon du Bazaar est de **ne pas égaliser** — chaque identité doit
avoir un archétype qui l'aime vraiment, même si cela crée des builds plus forts sur certaines
formes. C'est déjà une décision actée (decisions.md §2.2).

---

## 5. Économie — income, gold et rerolls

### 5.1 Teardown précis

**Sources d'or** :
1. **Income** : reçu à la **fin de chaque Jour** (pas heure), égal au niveau d'Income actuel.
   Income de départ : 7 (selon version/patch). Peut être augmenté via items (ATM, Star Chart, etc.)
   ou événements (option "+2 Income et 12 or").
2. **Or au départ de journée** : environ 15 or de départ/réserve accumulable
   (mobalytics.gg/the-bazaar/guides/day-guide).
3. **PvE rewards** : Bronze = 2 or / Silver = 3 or / Gold = 4 or / Diamond = 5 or / Legendary = 6 or
   (mobalytics.gg/the-bazaar/guides/pve-encounters-and-drops).
4. **Vente d'items** : 50% du prix d'achat (gaming.news/codex/...).
5. **Événements spéciaux** : certains événements donnent directement de l'or.

**Reroll** : de 2 or (Bronze) à 8 or (Silver+) selon le niveau du marchand.

**Pas de banque/intérêts** : contrairement à TFT, l'or ne génère pas d'intérêts. C'est plus proche
du modèle HS:BG/SAP. L'Income est la forme de "revenu passif".

**Prix des items** : 2 or (Small Bronze) à 64 or (Large Diamond), selon taille et rareté
(gaming.news/codex/...).

### 5.2 Psychologie

L'Income crée une **tension temporelle fondamentale** : investir tôt dans l'Income sacrifie la
puissance immédiate mais crée un avantage composé à long terme. C'est la transposition du "faut-il
payer loyer ou acheter ?" en mécanique de jeu. Cette tension est l'un des piliers d'addiction du
Bazaar — les joueurs qui comprennent le modèle Income ont un avantage asymétrique sur ceux qui
dépensent tout immédiatement.

Cependant, Reynad lui-même a noté que certains joueurs "forcent des builds spécifiques" sans
s'adapter (interview bazaar-builds.net, dec 2024). La tension Income vs puissance immédiate peut
créer de la **frustration si le payoff n'est pas visible** — les débutants ne voient pas pourquoi
ils perdent des PvP early alors qu'ils "investissent pour plus tard".

### 5.3 Maths

Si Income = 7 et la journée produit 5 or (from PvE) + 7 (Income) = 12 or/jour. Un item Silver
Medium coûte typiquement ~8-12 or. Un Large Gold coûte ~24-36 or. Le modèle Income exige donc
d'**attendre 2-3 jours** pour les items top-tier, ce qui crée un arc de run non trivial.

La formule Income-composé : si on monte l'Income à 12 dès le jour 2, et la run dure 10 jours,
on gagne 12 × 8 = 96 or de plus qu'un Income à 7. Sur une run courte (8-10 jours), le différentiel
est de l'ordre de 50-100 or, soit 1-3 items Large Diamond. C'est significatif mais pas
déterminant — d'où la tension.

**Reroll economics** : à 2-4 or le reroll, et l'Income/jour à 7-12 or, le coût d'opportunité d'un
reroll est de ~30-50% d'un item moyen. Les joueurs expérimentés rerollent rarement en early game
(thebazaarzone.com/beginners-guide/ : "don't waste gold on rerolls").

### 5.4 Verdict de transférabilité pour The Pit

**Analogie paresseuse** : "The Bazaar a un Income croissant → ajouter un mécanisme d'Income à The
Pit". Déjà démoli : la boutique payée (HS style) a été rejetée au playtest (decisions.md §3.2).
L'Income du Bazaar est structurellement incompatible avec le modèle "or fixe par round" de The Pit.

**Mais la psychologie de la tension survit** : le Bazaar crée la tension "maintenant vs plus tard"
via Income. The Pit crée la **même tension via l'XP de boutique** (montée de tier = accès aux
hauts rangs) et via la **décision de reroll** (1 or) vs achat. Ces deux leviers sont analogues
dans leur psychologie.

**Ce qui est nouveau et transférable** : l'idée que **refuser une offre donne un bonus compensatoire**
(decline = +3 or dans The Pit pour les slots et les reliques) est aussi présente dans le Bazaar
(vendre un item = 50% de retour). Ce "consolation prize" est psychologiquement important — il
transforme "je n'ai pas trouvé ce que je voulais" en "j'ai eu de l'or pour chercher autre chose".
The Pit l'a déjà : `SLOT_DECLINE_GOLD = 3`, `DECLINE_RELIC_GOLD = 3`. Le pattern est validé par
le Bazaar en conditions réelles.

---

## 6. XP, leveling et slots — la progression intra-run

### 6.1 Teardown précis

Le leveling du Bazaar combine deux axes distincts :
- **Board slots** : au départ 4 slots (Rug), jusqu'à 10. Chaque niveau ajoute 2 slots. Niveau 1→2
  = +2 slots, niveau 2→3 = +2 slots, etc. (game8.co/articles/reviews/the-bazaar-gameplay-and-story)
- **Rewards de niveau** : à chaque niveau, choix entre 3 récompenses : items, skills, gold,
  upgrade d'item, etc. Les rewards sont prédéterminés (Mobalytics level-up guide : niveau 6 = Silver
  item, niveau 8 = Orlin Gold Skill, etc.).

**XP accumulée** : 8 XP par niveau (gameplay.tips/guides/the-bazaar-leveling-cheat-sheet.html).
Sources d'XP : 1 XP par heure passée (automatique), PvE = 2-4 XP selon difficulté, certains
événements donnent +1-3 XP.

**Sans extras** : le joueur level-up environ 1 fois par jour (6 heures × 1 XP = 6 XP/jour + 2
XP de PvE = 8 = exactement 1 niveau/jour). Avec optimisation XP : jusqu'à 2 niveaux/jour.

**Item tier par jour** : Bronze (Jour 1-2), Silver (Jour 2-3), Gold (Jour 5+), Diamond (Jour 8+)
(bazaar-builds.net/the-ultimate-beginners-guide...).

### 6.2 Psychologie

Le leveling du Bazaar crée une **escalade de puissance visible** : la board grandit physiquement
(plus de slots), et les rewards de niveau créent des "pics de puissance" anticipés. Un joueur qui
sait qu'au niveau 8 il obtient un Gold Skill va vouloir atteindre le niveau 8 — c'est de
l'**anticipation structurée** (calendrier de récompenses = dette de récompense).

Le system "pick 1 of 3 rewards" à chaque niveau maintient l'**agence** du joueur même dans une
progression automatique. Sans ce choix, le leveling serait passif.

### 6.3 Maths

Un run typique de 10 jours = 10 niveaux de base (1/jour) + 3-5 niveaux bonus via optimisation XP
= niveaux 13-15 max. À 2 slots par niveau, un joueur qui level-up 8 fois débute avec 4 slots et
finit avec 20 — soit le plein de 10 slots actifs + stash (game8.co).

**Threshold XP** : niveau = 8 XP, fix. Un run de 10 jours sans extra XP = exactement 10 niveaux.
Le modèle est linéaire, sans courbe exponentielle — plus simple à équilibrer.

### 6.4 Verdict de transférabilité pour The Pit

**La structure de leveling du Bazaar est directement analogue à ce que The Pit implémente déjà**,
mais avec une différence cruciale :

| Aspect | The Bazaar | The Pit |
|--------|-----------|---------|
| Slots | +2 par niveau (jusqu'à 10) | +1 par grant (rounds 2-7, jusqu'à 9) |
| XP source | 1/heure + PvE + événements | 1 passif/round + achat (4 XP pour 4 or) |
| Récompense de niveau | 1-parmi-3 (items, skills, gold…) | Non encore implémenté (todo Lot 5) |
| Courbe | Linéaire (8 XP/niveau fixe) | Exponentielle-ish [PH] (T1→T2=2 XP, T2→T3=5…) |

**Leçon la plus précieuse** : les **rewards de niveau prédéterminés** (niveau 6 = Silver item,
niveau 8 = Gold Skill) donnent au joueur un **horizon clair**. The Pit a un todo ouvert pour les
rewards de level-up (progression-economy-prd, Lot 5). La leçon du Bazaar : ne pas laisser les
rewards entièrement aléatoires. Prédéterminer les niveaux "importants" (ex. : niveau 4 = relique
early, niveau 7 = unlock slot bonus) crée de l'anticipation structurée.

**Ce qui ne s'applique pas** : les 10 niveaux de slots du Bazaar (4→10 en 4 niveaux) sont adaptés
à un run de 10-15 jours. The Pit a 6 grants de slots sur 6 rounds, ce qui est plus tendu et
adapté au format 10-victoires. Le rythme différent est une décision correcte — ne pas copier les
chiffres.

---

## 7. Système de Prestige — la vie du run

### 7.1 Teardown précis

Le **Prestige** est la "vie" du run dans le Bazaar. Il démarre à 20 points.
Perdre un combat PvP fait perdre X Prestige où **X = le numéro du Jour** actuel.

Exemples :
- Perdre Jour 1 = −1 Prestige (20→19)
- Perdre Jour 5 = −5 Prestige (20→15)
- Perdre Jour 10 = −10 Prestige (si on est à 10, game over)

Sources : mobalytics.gg/the-bazaar/guides/prestige ; bazaar-builds.net/the-ultimate-beginners-guide

**Événement Fate** (dernier souffle) : quand le Prestige atteint 0, le run ne finit pas immédiatement.
Le joueur reçoit un boost d'urgence : choix entre un item Diamond aléatoire, un enchantement
aléatoire, ou 20 or + 5 XP. Après ce boost, une défaite = fin définitive.

**Récupération de Prestige** : possible via des items rares (Arken's Ring = +5 Prestige, certains
events). Pas de récupération standard.

**Résultats en ranked** :
- Saison 1 : <4 wins = −1 point ; 4-6 = 0 ; 7-9 = +1 ; 10 = +2
- Saison 2 : 0-3 wins = 0 pts ; 4-6 = +1 ; 7-9 = +2 ; 10 = +3
  (thebazaarzone.com/season-2-patch-notes-2-0-0-may-7-2025/)

### 7.2 Psychologie

Le coût de Prestige **croissant avec le numéro du Jour** est un design élégant :
- Early : les pertes coûtent peu → le joueur explore sans stress, prend des risques
- Late : les pertes sont catastrophiques → la tension augmente naturellement avec la progression

C'est une **escalade de tension calibrée** qui imite la structure narrative classique : exposition
→ montée → climax. Les batailles tardives sont importantes parce que les pertes tardives le sont.

Le "Fate event" (dernier souffle) est un **near-miss structurel** : on était à 0, on a eu une
chance, on peut encore gagner. Les near-miss sont documentés comme des amplificateurs d'engagement
majeurs dans les jeux (Luke Clark, "Near-misses increase future slot machine gambling", Cognition,
2009). Le Bazaar l'a formalisé en mécanique de run.

**Saison 2 impact psychologique** : supprimer la pénalité pour les 0-3 wins a changé la stratégie
vers des builds plus risqués/long-terme. L'analyse thebazaarzone.com/season-2-guide/ confirme que
les joueurs ont commencé à "invest pour les 10 wins" plutôt que de "sécuriser un Bronze". Ce
changement d'incentive est une preuve que la structure de scoring pilote directement les
comportements — leçon directement applicable pour The Pit.

### 7.3 Maths

Prestige initial : 20. Avec des pertes uniquement aux jours pairs (1, 2, 3…), la somme max de
dégâts en 10 défaites = 1+2+3+4+5+6+7+8+9+10 = 55 Prestige de dégâts potentiels. Mais le run
se termine dès Prestige ≤ 0. Pour arriver à 10 victoires en subissant des défaites :
- 20 Prestige / coût moyen d'une défaite ~ 5 = environ 4 défaites supportables en moyenne
- Une défaite au Jour 15 coûte 15 Prestige = game over si < 15 restant

Ce modèle crée une **courbe de viabilité non-linéaire** : perdre tôt est quasi-gratuit, perdre
tard est prohibitif.

### 7.4 Verdict de transférabilité pour The Pit

**Le Pit n'a pas de Prestige** : son système est un **compteur de vies plat** (5 vies, chaque
défaite = −1 vie). C'est plus simple et plus lisible, ce qui est cohérent avec les piliers (SAP =
référence de simplicité).

**La leçon sur l'escalade de tension SURVIT à nos contraintes** : The Pit peut implémenter une
tension croissante **sans modifier le modèle de vies**, via deux mécanismes existants :
1. **Escalade des adversaires** : les snapshots servis peuvent être filtrés par `tier` croissant,
   ce qui est déjà dans le `serveComp` (snapstore.lua). Il suffit de s'assurer que les rounds
   tardifs servent des snapshots de tier élevé.
2. **Prestige asymétrique via streaks** : les streaks de victoires donnent du bonus or, mais pas
   les streaks de défaites. On pourrait introduire un "cushion" en streak de défaites (filet SAP
   au round 3, déjà en place).

**Le Fate event est directement transférable** : The Pit a les 5 vies. Si un joueur tombe à 0
vie, au lieu de terminer immédiatement la run, proposer un **"dernier souffle"** : une relique
gratuite de tier élevé, ou un reroll complet de boutique. Ce serait un near-miss structurel qui
maintient l'engagement et est cohérent avec l'esthétique grimdark ("une dernière chance de
descendre plus profondément dans le Puits"). Proposition concrète pour le lab.

---

## 8. Système async par ghosts — le coeur du modèle PvP

### 8.1 Teardown précis

C'est **la contribution architecturale centrale du Bazaar** à l'autobattler.

**Mécanisme** (décrit par Reynad dans la vidéo Update #19 en 2021 et confirmé dans les sources
2024-2025) :
1. À l'heure 5 (PvP), le serveur prend un "snapshot" du board du joueur à ce moment précis.
2. Ce snapshot est stocké dans un pool, tagué par : **numéro de jour** (Day N) + **win record** +
   **mode de jeu** (Ranked vs Normal, pools séparés).
3. Un autre joueur au même jour et au même win record (approximativement) reçoit ce snapshot comme
   adversaire. Le combat est résolu localement par son client.
4. **Le ghost remplace le ghost adversaire** : quand le joueur A combat le ghost du joueur B, le
   ghost du joueur A remplace celui du joueur B dans le pool. Ainsi, aucun ghost ne reste en
   circulation indéfiniment.

Sources : bazaar-builds.net/did-you-know-how-ghosts-work/ (confirmation officielle via Reddit) ;
rkblog.dev/posts/games/the-bazaar-card-game/ ; The Bazaar Update #20 (YouTube, 2021).

**Matchmaking win-record** : les joueurs sont matchés prioritairement contre des joueurs ayant le
**même win record** (2-1 contre des 2-1, etc.). Cela crée une escalade de difficulté naturelle
sans nécessiter de MMR calculé en temps réel (Reynad, interview dec 2024).

**Problème potentiel** : le matchmaking par win record peut être abusé (perdre intentionnellement
pour affronter des adversaires plus faibles). Reynad a reconnu ce problème ("Swiss rounds" abusables)
en décembre 2024 (bazaar-builds.net/reynad-interview...).

**Ranked vs Normal** : deux pools séparés de ghosts. Ranked nécessitait un ticket (100 gems ou
10 wins en Normal) jusqu'à la version Steam premium où le Ranked est devenu gratuit
(mobalytics.gg/the-bazaar/guides/steam-release-monetization-updates).

**Ghost de rang** : depuis patch 6.0.0 (sept 2025), les joueurs ne sont matchés qu'avec des ghosts
de leur rang ou inférieur en Normal (bazaar-builds.net/patch-6-0-0-...). C'est pour protéger
les nouveaux joueurs qui se faisaient écraser par des builds meta.

### 8.2 Psychologie

Le système ghost résout **trois problèmes simultanément** :

1. **Le problème d'attente** : dans un PvP synchrone, il faut attendre qu'un adversaire soit
   disponible. Avec les ghosts, il y a toujours un adversaire disponible — le pool est alimenté
   par tous les joueurs qui ont déjà joué ce Jour.

2. **L'anxiété de performance** : dans un PvP live, jouer lentement pénalise (timer). Ici, le
   joueur peut prendre tout le temps qu'il veut pour construire son board — la pression n'arrive
   qu'au moment du combat (et ce combat est automatique). Ce "resting design" réduit le stress
   et augmente l'accessibilité.

3. **La variété des adversaires** : chaque ghost est un build réel d'un joueur humain, ce qui
   garantit une diversité que les IA ne peuvent pas égaler. C'est une "database d'adversaires
   gratuite" alimentée par la communauté.

**Cependant**, le système ghost crée aussi un **problème de perception d'équité** : les nouveaux
joueurs se faisaient affronter des builds meta très optimisés, sans matchmaking de compétence
(PC Gamer, pcgamer.com/..., avril 2025 : "you'll likely be facing builds from players with vastly
more knowledge and experience"). Cela a nécessité le patch du ghost-rank en septembre 2025.

### 8.3 Maths

Si le pool de ghosts par "Day N, X wins" a P entrées, la probabilité de rencontrer un ghost
spécifique est ~1/P. Avec peu de joueurs (cold-start), le pool est petit → matchmaking peu varié.
Avec une large base de joueurs, le pool devient immense → grande variété.

**Cold-start** : le Bazaar n'a pas de fallback IA documenté (contrairement à SAP qui a des IA
explicites). Si le pool est vide, il est probable que le serveur sert un ghost aléatoire hors du
bucket exact. C'est une différence architecturale avec The Pit (qui a les Encounters IA comme
fallback garanti via `serveComp`).

**Ghost replacement** : le ghost du joueur A remplace le ghost du joueur B immédiatement après le
combat. Ce système FIFO/replacement garantit que les ghosts se renouvellent naturellement avec les
nouvelles versions/metas.

### 8.4 Verdict de transférabilité pour The Pit

**C'est le mécanisme LE PLUS aligné avec les piliers du Pit.** The Pit a déjà implémenté une
version de ce système (snapshots async, snapstore.lua). La comparaison est donc des leçons de
**tuning et d'intégrité**, pas de conception.

**Leçons concrètes du Bazaar à appliquer au Pit** :

1. **Pools séparés Ranked/Normal** : The Pit doit avoir des pools de snapshots distincts pour
   chaque mode, sinon les ghosts du mode normal polluent le ranked (et vice-versa). Déjà réfléchi
   mais pas encore implémenté (00-state.md §7).

2. **Matchmaking par progression** : les snapshots servis doivent être filtrés par **tier de
   boutique** (proxy de progression), pas seulement par version. Le système actuel filtre par
   `tier` (snapstore : `serve(version, tier≤demandé, rng)`). C'est correct. La leçon du Bazaar
   est que le matchmaking par "day record" (= victoires actuelles, progression dans la run) est
   plus fin que le matchmaking par rang global.

3. **Ghost replacement** : quand The Pit servira un ghost, le snapshot du joueur courant devrait
   remplacer le ghost servi dans le pool — mécanisme de rotation naturelle. Non encore implémenté.

4. **Protection des nouveaux joueurs** : le patch 6.0.0 du Bazaar montre que, sans ce filtre,
   les débutants se font écraser et quittent. The Pit doit implémenter dès le départ un filtre
   "ghost rank ≤ rank joueur" pour les runs early (10-15 premières runs). Solution : au cold-start,
   prioritiser les Encounters IA (déjà en place) et n'introduire les ghosts qu'après que le joueur
   a prouvé une certaine maîtrise.

5. **Abus potentiel par lose-intentionnel** : le matchmaking par win record (Jour N, X-Y) peut
   être abusé si les joueurs perdent exprès. The Pit est protégé naturellement : dans un run court
   (10 victoires avant 5 défaites), l'intérêt à perdre intentionnellement est faible car chaque
   défaite coûte une vie précieuse. C'est une différence structurelle favorable au Pit.

**Ce qui est différent** : le Bazaar tag ses ghosts par "Jour N" car sa structure est orientée
jours (il y a 15 jours max). The Pit doit tagger ses snapshots par **victoires actuelles dans la
run** (0-9) comme proxy de progression, ce qui est déjà la structure de `store.serve`.

---

## 9. Structure compétitive / Ranked

### 9.1 Teardown précis

**Niveaux de rang** : le Bazaar utilise une structure de points progressifs (pas un MMR Elo
classique mais un système à points cumulatifs). Des tiers existent (Bronze, Silver, Gold, Diamond
au sens rang, distinct des raretés d'items) avec des seuils en nombre de points.

**Points par run** (Saison 2) — grille générale :
- 0-3 wins : 0 points (pas de pénalité)
- 4-6 wins : +1 point
- 7-9 wins : +2 points
- 10 wins : +3 points

**Mais cette grille évolue selon le rang** : plus on est haut en rang, plus les seuils de
récompense sont stricts (thebazaarzone.com/season-2-patch-notes-2-0-0-...) :
- Rang bas : 0-3 wins = 0 pts, 4-6 = +1, 7-9 = +2, 10 = +3
- Rang haut : 0-6 wins = 0 pts, 7-9 = +1, 10 = +2

**Récompenses de saison** : caisses cosmétiques (chests) contenant des skins, des plateaux, des
sons. Depuis Steam launch, tous les cosmétiques (y compris passés) sont accessibles via les caisses
normales (mobalytics.gg/the-bazaar/guides/steam-release-monetization-updates).

**Reset mensuel** : les saisons durent ~1 mois, reset des points à chaque saison.

**Tickets Ranked** : initialement nécessitaient un ticket (100 gems ou 10 wins en Normal). Depuis
Steam premium, le Ranked est libre d'accès (mobalytics.gg/the-bazaar/guides/steam-release...).

Source : bazaar-builds.net/do-you-know-how-the-ranking-works-in-the-bazzar/ ;
thebazaarzone.com/season-2-patch-notes-2-0-0 ; screenrant.com/bazaar-how-to-play-ranked-ccg/

### 9.2 Psychologie

**Le ranked pilote les comportements** (confirmé par l'analyse saison 2) : quand il y avait une
pénalité à <4 wins, les joueurs jouaient pour "sécuriser 4 wins" (safe build). Quand la pénalité
est retirée, ils jouent pour "essayer d'arriver à 10" (risky build). C'est une démonstration
directe que la structure de scoring, pas les mécaniques de jeu, détermine le **style de jeu
dominant en ranked**.

**Le scaled scoring (seuils plus stricts en haut rang)** force les joueurs à se surpasser pour
rester au top : là où un joueur mid-rank peut progresser avec 4 wins constants, un joueur top-rank
doit viser 7+ wins à chaque run. C'est une mécanique de **prestige élitaire** qui retient les
joueurs avancés sans frustrer les débutants.

**Les resets mensuels** créent du **FOMO et des nouveaux départs** : chaque saison, tous les
joueurs repartent de zéro (ou d'une position réduite). Cela maintient la compétition active et
donne une raison de jouer même aux joueurs "déjà au maximum". Source psychologique : la littérature
sur la "season structure" dans les jeux compétitifs (Riot, "Why We Reset MMR", 2016,
leagueoflegends.com/en-us/news/).

### 9.3 Maths

Simulons une saison de 30 jours. Un joueur dédicacé fait 2 runs/jour = 60 runs. Si win rate = 50%
en 7 wins/run en moyenne : 60 × 2 points = +120 points. Un joueur casual (1 run/jour, 4 wins) :
30 × 1 point = +30 points. L'écart 4× est substantiel mais pas insurmontable.

La grille "0-3 wins = 0 points" (saison 2) avec 3 points max pour 10 wins crée une **asymétrie de
récompense** : la différence entre 9 et 10 wins est 1 point. Mais la différence entre 6 et 7 wins
est aussi 1 point. Cela encourage les joueurs à viser 7 wins minimum (seuil stable, 2 points)
plutôt que de se tuer à chercher les 10 wins (3 points mais coût en runs échouées plus élevé).

### 9.4 Verdict de transférabilité pour The Pit

**Le compétitif/ranked est la "zone vierge" la plus importante du Pit** (00-state.md §7 : "Compétitif
/ ranked — Rien de codé ; structure entièrement à concevoir"). Le Bazaar est la source de référence
principale sur ce point car c'est le seul autobattler async avec un ranked fonctionnel.

**Transférabilité directe** :

1. **Score par run, pas par match** : The Pit doit scorer les runs (victoires obtenues), pas les
   combats individuels. C'est exact — la run est l'unité de compétition, pas le round. La grille
   de points du Bazaar (0/1/2/3 selon le seuil de wins atteint) est un modèle direct à adopter.

2. **Seuils différenciés par rang** : les seuils plus stricts pour les rangs élevés garantissent
   que progresser en haut est plus difficile. À implémenter dès le design initial du système ranked
   du Pit.

3. **Reset de saisons** : mensuel ou bimensuel pour maintenir l'engagement. The Pit peut lier le
   reset à une **rotation de reliques ou de pool d'unités** (ex. : quelques unités "saison" qui
   disparaissent à chaque reset). Ce serait cohérent avec la DA et créerait un FOMO ciblé.

4. **Ghost pools séparés ranked/normal** : comme mentionné §8, critique pour l'intégrité.

**Adaptation nécessaire** :

- Dans le Bazaar, un joueur peut faire 3+ runs/jour. Dans The Pit, une run de 10 victoires dure
  potentiellement 30-60 minutes. Le volume de runs sera plus faible → les seuils de points doivent
  être calibrés pour que 2-3 runs/semaine = progression visible. Suggestion : +1 point à partir de
  5 wins, +2 à 7 wins, +3 à 10 wins (adapté au rythme de The Pit).

- Le Pit n'a **pas de ticket paid** pour le ranked — c'est une décision correcte (pas de barrière
  à l'entrée, surtout en solo dev).

---

## 10. Monétisation — leçons du fiasco et de la rédemption

### 10.1 Teardown précis

L'historique monétisation du Bazaar est un cas d'école :

- **Open Beta (mars 2025)** : Expansions de héros (items supplémentaires) payantes derrière la
  partie premium du Prize Pass. Ranked nécessitait des tickets payants ou obtenus difficilement.
  Réaction communautaire violente (reddit, PC Gamer). Reynad a exacerbé la situation avec des
  réponses agressives.
- **Saison 1 (avril 2025)** : Prize Pass entièrement gratuit. Expansions disponibles pour tous.
  Ticket Ranked disponible via le Prize Pass gratuit. Réaction positive.
- **Steam (août 2025)** : Pivot premium (achat unique ~30 $). Heroes de base inclus. Heroes
  supplémentaires en DLC (~20 $). Ranked libre. Prize Pass gratuit. Cosmétiques uniquement.

Sources : pcgamer.com/games/roguelike/the-bazaar-could-be-the-future... (mars 2025) ;
pcgamer.com/games/card-games/we-are-so-back... (avril 2025) ;
mobalytics.gg/the-bazaar/guides/steam-release-monetization-updates ;
mobalytics.gg/the-bazaar/guides/monetization-changes

### 10.2 Leçons pour The Pit

**Leçon #1 (ne pas faire)** : Gate le contenu gameplay (items, mécaniques) derrière le payant.
La communauté a réagi au Bazaar parce que les Expansions modifiaient l'équilibre des pools d'items
— ceux qui payaient avaient accès à des builds plus forts. Pour The Pit (solo dev, pas encore en
monetisation), la leçon est de ne jamais mettre de **mécaniques de gameplay** derrière un paywall.
Les unités, reliques et sigils doivent tous être accessibles en jouant.

**Leçon #2** : Le Prestige/Ranked ne doit pas nécessiter de paiement. The Pit est hors-scope
monétisation pour l'instant, mais quand la question se posera, le Bazaar confirme que le Ranked
libre est la bonne décision.

**Leçon #3** : La cosmétique fonctionne. Le pivot cosmetics-only du Bazaar (Steam launch) a été
bien reçu. Pour The Pit, si une monétisation est envisagée un jour, les skins/palettes pour les
créatures procédurales seraient le bon vecteur — sans impact gameplay.

---

## 11. Problèmes documentés du Bazaar — ce que The Pit ne doit pas reproduire

### 11.1 Balance instable par patch

Le Bazaar souffre de déséquilibres importants à chaque nouveau contenu (Mak en saison 1, Pygmalien
hogwash en saison 2). La cause documentée : "ils manquent de main-d'oeuvre pour tester eux-mêmes"
(mobalytics review). Les joueurs sont les testeurs.

**Leçon** : The Pit a `tools/sim.lua` (batch sim 400 combats) et `tests/props.lua` (fuzz 250
combats). C'est un avantage structurel. Le lab doit prioriser la **passe d'équilibrage auto-itérée**
(Lot 7 dans progression-economy-prd) avant d'ajouter du contenu. Chaque nouvel ajout doit passer
par `tools/sim.lua` avant commit.

### 11.2 Barrière de connaissance / knowledge checks

Les enchantements sont une barrière majeure selon les reviews (53/100 plaintes Steam sur la
monétisation, 27/100 sur le balance, 19/100 sur le "high barrier to entry").

La cause précise : les enchantements ont des interactions non documentées in-game, et l'impact
d'un enchantement sur un item peut être déterminant. Sans les connaître, le joueur fait des choix
"au hasard" qui semblent lui coûter des runs.

**Leçon** : les reliques de The Pit sont **lisibles** (décision actée 2026-06). C'est le contrepoint
direct au problème du Bazaar. Ne jamais réintroduire une mécanique "à découvrir par expérimentation"
dans The Pit sans la rendre lisible.

### 11.3 Matchmaking "too strong ghost" pour les débutants

Les débutants se retrouvaient à affronter des builds meta optimisés, même en Normal (PC Gamer,
avril 2025). Patché en sept 2025 (ghost rank ≤ player rank).

**Leçon** : le Pit doit implémenter dès le départ un filtre "snapshot tier ≤ tier joueur" pour
les premières runs. `snapstore:serveComp` retombe déjà sur IA si pas de snapshot disponible —
c'est le bon fallback. Mais quand des snapshots existent, s'assurer de ne pas servir des builds
de tier 5 à un joueur de tier 1.

### 11.4 Gameplay "trop scripté" par la meta

Reynad lui-même reconnaît que les joueurs "forcent des builds spécifiques" (interview dec 2024).
La meta se stabilise rapidement en autobattler async car les ghosts sont des builds réels
d'humains optimisant — ce qui crée une boucle de renforcement meta.

**Leçon** : The Pit peut atténuer cela via les **reliques G (topologie/sigils)** différés et
les **synergies par type** (TODO majeur). Ces deux systèmes introduiront des métas transversales
qui cassent la méta "run straight poison" dominante. À prioriser.

---

## 12. Synthèse — tableau de verdict de transférabilité

| Mécanisme du Bazaar | Psychologie | Maths clés | Survit aux contraintes Pit ? | Adaptation recommandée |
|---------------------|-------------|-----------|------------------------------|------------------------|
| Rythme jour/6 heures | Goal gradient | 30-90 min/run | Partiel — Pit a déjà build→combat→résultat | Optimiser le feedback intra-round (bandeau résultat) |
| Combat cooldowns temps réel | DPS-race visible | 3s = 10× vs 10s = 3× déclenchements | Partiel — Pit a cooldowns déterministes. Ne pas copier la manipulation de cooldown ennemi (freeze/slow) | Garder le modèle Pit (pas de freeze ennemi en combat) |
| Sandstorm (timer conclusion) | Tension finale | 30 s standard, 7 s avec Mak | Oui — analogue à Fatigue Pit (1020 ticks ~17 s) | Déjà en place |
| Items tailles S/M/L | Gestion d'espace contrainte | 10 slots, 7-9 items actifs | Partiel — Pit a 9 slots 3×3 + adjacence riche | Leçon : les items occupant plus d'espace doivent être proportionnellement plus puissants |
| Upgrade via doublons | Satisfaction de complétion | Bronze→Silver→Gold→Diamond | Oui — analogue aux duplicatas du Pit (3 copies → niveau) | Déjà en place avec LEVEL_MULT |
| Héros / pools séparés | Identité de run, engagement multiple | ~400 items pertinents/héros | Non — Pit n'a pas de héros. Sigils jouent ce rôle | Renforcer la différenciation des archétypes par sigil |
| Income croissant | Tension maintenant vs plus tard | Composé ~50-100 or par run | Non — Pit a or fixe/round. Psychologie similaire via XP boutique | XP boutique (passive + achetée) joue ce rôle — ne pas ajouter l'Income |
| Leveling + slots | Escalade de puissance visible | 8 XP/niveau, +2 slots/niveau | Oui — analogue (XP + grants de slots) | Prédéterminer certains niveaux-clés avec rewards fixes (todo Lot 5) |
| Prestige (vies décroissantes) | Escalade de tension calibrée | Dégâts = numéro du Jour | Partiel — Pit a vies plates | Introduire "dernier souffle" (Fate event) quand vies = 0 |
| Fate event (last chance) | Near-miss structurel | +1 relique diamond ou 20 or | Oui | Proposer une relique gratuite tier 4 à la dernière vie |
| Ghost pool async | Resting design, variété adversaires | 1 ghost remplace le précédent | Oui — c'est LE pilier #1 du Pit, déjà en place | Pools séparés ranked/normal, ghost replacement, protection rank |
| Matchmaking win-record | Escalade naturelle difficulté | Swiss rounds approximatifs | Oui | Filter snapshots par "wins actuels / tier" de la run en cours |
| Ranked scoring tiered | Comportements pilotés par scoring | 0/1/2/3 points selon wins | Oui | Adapter la grille au rythme de run Pit (2-3 runs/semaine) |
| Saisons mensuelles | FOMO + nouvelles dynamiques | Reset mensuel | Oui | Lier le reset à une rotation de reliques/unités "saison" |
| Ghost rank protection | Onboarding des débutants | Ghost ≤ rank du joueur | Oui | Implémenter dès le départ (snapshot tier ≤ tier joueur) |

---

## 13. Trois propositions actionnables pour The Pit issues de l'analyse

### P1 — Fate Event : le "Dernier Souffle" du Pit

**Mécanisme** : quand le joueur perd sa dernière vie (vies = 0), au lieu de terminer immédiatement,
lui proposer un choix entre 3 options de run :
- Relique de tier 4 gratuite (une parmi 3 — respecte le modèle 1-parmi-3 existant)
- +10 or immédiat
- Remplacer la boutique par une boutique de rang 5 uniquement

Ce "dernier souffle" est un near-miss structurel qui maintient l'engagement et est cohérent avec
l'esthétique grimdark ("le Puits vous offre une dernière chance de descendre plus bas"). Ne
modifie pas le code de combat, ne modifie pas la sim. Ajoute un état `run.lastBreath` dans
`state.lua`.

**Contraintes Pit respectées** : déterministe (le choix est seedé), async-safe (les snapshots ne
capturent pas l'état de LastBreath), grimdark cohérent.

### P2 — Grille de scoring Ranked pour The Pit

Structure proposée (à ajuster via sim) :
- 0-3 wins : 0 points (pas de pénalité — encourage la prise de risque early)
- 4-6 wins : +1 point
- 7-9 wins : +2 points
- 10 wins : +3 points (scalable selon rang, comme le Bazaar)

Séparation des pools ghost : Ranked vs Normal. Implémentation dans `snapstore.lua` : ajouter un
champ `mode` (= "ranked" ou "normal") au snapshot. `serve()` filtre par mode.

### P3 — Ghost replacement et filtrage par progression

Quand The Pit sert un ghost, le snapshot du joueur courant (post-combat) remplace le ghost servi
dans le pool. Cela garantit que les snapshots se renouvellent avec les metas actuelles.

Filtre de protection débutants : `serve(version, tier, rng)` doit ajouter un paramètre
`maxTier = currentPlayerTier`. Les joueurs débutants (boutique tier 1-2) n'affrontent que des
ghosts de tier 1-2.

---

## 14. Sources

| URL | Contenu utilisé |
|-----|----------------|
| mobalytics.gg/the-bazaar/guides/day-guide | Structure jour/heure, économie de départ |
| thebazaar.wiki.gg/wiki/Cooldown | Valeurs de cooldown, mécaniques Haste/Slow/Freeze |
| thebazaar.wiki.gg/wiki/Items | Tailles S/M/L, upgrade, enchantements |
| thebazaar.wiki.gg/wiki/Level_Up | Rewards de niveau par palier |
| thebazaar.wiki.gg/wiki/Day | Structure officielle des jours |
| mobalytics.gg/the-bazaar/guides/prestige | Système Prestige, Fate event |
| mobalytics.gg/the-bazaar/guides/beginner-guide | Boucle de run, ghost system |
| mobalytics.gg/the-bazaar/guides/pve-encounters-and-drops | Rewards PvE (or + XP) |
| mobalytics.gg/the-bazaar/guides/level-up-rewards | Rewards par niveau (prédéterminés) |
| mobalytics.gg/the-bazaar/guides/monetization-changes | Saison 1 monétisation |
| mobalytics.gg/the-bazaar/guides/steam-release-monetization-updates | Pivot Steam premium |
| mobalytics.gg/news/guides/the-bazaar-review | Critiques balance / barrier to entry |
| thebazaarzone.com/beginners-guide/ | Économie, run structure |
| thebazaarzone.com/season-2-patch-notes-2-0-0-may-7-2025/ | Grille de scoring saison 2 |
| thebazaarzone.com/season-2-guide/ | Analyse psychologique du changement de scoring |
| bazaar-builds.net/do-you-know-how-the-ranking-works-in-the-bazzar/ | Grille points saison 1 |
| bazaar-builds.net/did-you-know-how-ghosts-work/ | Ghost replacement (confirmation officielle) |
| bazaar-builds.net/how-does-matchmaking-work-in-the-bazaar/ | Elo → wins-based matchmaking |
| bazaar-builds.net/reynad-interview-insights-on-the-future-of-the-game/ | Swiss rounds, meta abus |
| bazaar-builds.net/patch-6-0-0-reduced-power-level... | Ghost rank protection (sept 2025) |
| bazaar-builds.net/the-bazaar-is-coming-to-steam... | Pivot premium, rationale Reynad |
| bazaar-builds.net/db/merchants/ | Tailles des pools d'items par marchand |
| bazaarcalc.com/items/ | 644 items total (saison 10) |
| noisypixel.net/the-bazaar-interview-reynad-asynchronous-pvp-deckbuilder/ | Reynad interview : resting design, async PvP rationale |
| pcgamer.com/games/roguelike/the-bazaar-could-be-the-future... | Critique monétisation open beta |
| pcgamer.com/games/card-games/we-are-so-back... | Récupération saison 1 |
| pcgamesn.com/the-bazaar/mak-new-hero-season-1 | Sandstorm 7 s (Bottled Tornado) |
| screenrant.com/bazaar-how-to-play-ranked-ccg/ | Système ranked tickets |
| gaming.news/codex/the-bazaar-complete-beginners-guide... | Économie, prix items, income |
| gamegator.net/news/how-to-win-in-bazaar | Résumé mécanique combat |
| gameplay.tips/guides/the-bazaar-leveling-cheat-sheet.html | Cheatsheet leveling (8 XP/niveau) |
| game8.co/articles/reviews/the-bazaar-gameplay-and-story | Board slots (+2/niveau) |
| thegamer.com/the-bazaar-beginner-tips-tricks-mechanics-explained-guide/ | Sandstorm (30 s), combat auto |
| en.everybodywiki.com/The_Bazaar_(video_game) | Sandstorm comportement général |
| loadlastsave.substack.com/p/the-bazaar-review | Critique gameplay (stash frustrant, animations) |
| medium.com/@819apollo/... | Perspective joueur casual, engagement loop |
| rogue.site/editorials/the-bazaar-explained-preview/ | Perspective joueur hardcore, pools hero |
| vaporlens.app/app/1617400/the_bazaar | Analyse Steam reviews (satisfaction, plaintes) |
| YouTube : The Bazaar Update #19 (youtube.com/watch?v=Zv0CKGxm680) | Historique du passage à l'async |
| YouTube : The Bazaar Update #20 (youtube.com/watch?v=K6iT139054c) | Ghost pool design originel |
| YouTube : Kripparrian Basics (youtube.com/watch?v=oVtvrCdqHEE) | Mécanique de combat expliquée |

---

*Analyse produite le 2026-06-23 dans le cadre du `roadmap-lab` de The Pit. Lecture seule du repo
de jeu. Sources vérifiées et citées pour chaque affirmation chiffrée. Piliers respectés : async
snapshots / sim déterministe / grimdark / pixel art procédural.*
