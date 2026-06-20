# Conception d'un Autobattler Asynchrone en Lua/LÖVE2D : Analyse, Synthèse et Recommandations

## TL;DR

- Vous pouvez bâtir un jeu profond ET simple à coder en LÖVE2D en adoptant **UN seul** modèle de combat (cooldowns auto-résolus à la Bazaar/Batomon), **UN plateau-graphe de 9 slots (3×3)** dont la topologie d'adjacence est elle-même un axe de build — modifiable par des **reliques-sigils** qui en redessinent la forme — et le système de duplicatas TFT (3 copies → niveau, max 3). Tout le reste découle logiquement de ces choix. (Preuve de faisabilité directe : **Balatro lui-même est codé en Lua avec le framework LÖVE**.)
- Dans un jeu où toute la profondeur vient de l'**adjacence**, la forme de la grille *est* le graphe de synergies. Passer en multi-rangées n'ajoute pas « plus de cases » mais une **topologie de synergies plus riche** — et la grille mutable transforme la mécanique centrale en axe de build. C'est votre meilleur twist.
- Votre mécanique différenciante — des **reliques cryptiques** dont l'effet n'est pas écrit et se découvre par déduction, avec un savoir persistant entre parties — est validée par Outer Wilds, Tunic et Return of the Obra Dinn : c'est votre meilleur atout, à condition d'en faire un **puzzle soluble** et non une obscurité gratuite.
- L'**asynchrone** (combat contre des « fantômes » enregistrés) est techniquement le choix le plus malin pour un solo dev débutant : pas de netcode temps réel, juste stocker/servir des snapshots JSON de builds, avec un fallback IA. C'est la décision technique à plus fort levier du projet.

## Key Findings

1. **Un seul modèle de combat suffit, et c'est le bon** : le combat à cooldowns auto-résolu (chaque entité agit quand son timer atteint zéro) est utilisé par The Bazaar, Batomon Showdown et Wildfrost. Déterministe, simple à coder, lisible.
2. **La forme du plateau EST le moteur de diversité des builds** : en jeu d'adjacence, la topologie des slots détermine quelles synergies sont possibles. Un plateau-graphe 3×3 dont la forme peut muter (en gardant 9 slots) génère une diversité de compositions énorme à coût d'implémentation quasi nul (c'est de la data, pas du code).
3. **La position crée la profondeur sans complexité de règles** : les synergies d'adjacence orthogonale (haut/bas/gauche/droite) transforment une grille en puzzle combinatoire avec une hiérarchie de cases lisible (centre = case carry).
4. **Le système de duplicatas TFT (3 → niveau, max 3) couplé au leveling devient le moteur économique ET le régulateur de lisibilité** : on ne démarre pas à 9 slots, on les débloque en montant de niveau — combats précoces calmes, combats tardifs pleins.
5. **L'asynchrone est un cadeau pour l'indie** : Super Auto Pets et Backpack Battles prouvent qu'on n'a besoin que de snapshots de builds, jamais de serveurs temps réel.
6. **Re-thème + twist mécanique subtil suffisent à différencier** — Balatro (poker → roguelike) et Luck Be a Landlord (machine à sous → deckbuilder) le prouvent, MAIS seulement si la cohérence thème/mécanique est forte.
7. **Les reliques cryptiques sont votre signature** : la « connaissance comme métaprogression » est quasiment inexploitée dans le genre autobattler — terrain vierge.

## Details

### PARTIE 1 — DESIGN, MÉCANIQUES, ÉCONOMIE

#### 1.1 Le modèle de combat : cooldowns auto-résolus

Le cœur que vous voulez (Bazaar/Batomon) fonctionne ainsi : une fois le combat lancé, chaque objet/créature possède un **cooldown en secondes** ; quand il atteint zéro, l'entité déclenche son effet (attaque, soin, bouclier, debuff), puis le cooldown repart. Dans The Bazaar, les combats se résolvent sans input ; si personne ne meurt, une « Sandstorm » inflige des dégâts croissants pour forcer une fin. Backpack Battles applique exactement la même chose : les objets se déclenchent à intervalles et les combats durent 10-20 s. D'après le Backpack Battles Wiki, la « Fatigue » (Nightfall) démarre **précisément à 17 secondes** : « At the 17 second mark both players take Fatigue damage. Each time Fatigue damage is dealt it is first increased by 1 » — et croît ensuite selon la formule `Damage = PreviousDamage + floor(PreviousDamage/10) + 1`, à partir de 1 dégât à la 17ᵉ seconde. Batomon utilise des cooldowns en secondes (ex. Pebbler 4 s, Cobrex 15 s) avec un **plancher de 1 seconde** (l'UI signale quand une créature atteint cette limite).

**Pourquoi c'est idéal pour LÖVE2D** : c'est une simple file d'événements temporels. Vous tenez une liste d'entités, chacune avec un timer ; à chaque `update(dt)` vous décrémentez, et au passage à zéro vous appliquez l'effet et réinitialisez. Pas de physique, pas de pathfinding, pas de netcode. **Déterminisme** : pour rendre le combat rejouable/vérifiable (essentiel à l'asynchrone), utilisez un **RNG à graine fixe** (seed stockée avec le combat) et un pas de temps fixe — vous pourrez rejouer un combat à l'identique côté client sans le re-simuler côté serveur.

**Lisibilité du combat automatique** : Wildfrost et Batomon montrent qu'il faut de **petits nombres** et un rythme lisible. Wildfrost prouve qu'augmenter/diminuer un seul nombre de 1 peut être énorme quand les valeurs de base sont petites. Recommandation tranchée : timers entre 1 et 12 s, dégâts à deux chiffres au départ, barres de cooldown visibles au-dessus de chaque entité, et un **journal de combat** (Backpack Battles a ajouté un « combat log » exactement pour cette raison de lisibilité).

**RNG vs déterminisme** : le piège classique des autobattlers est le trop-plein de RNG (plaintes récurrentes sur Mechabellum : « the RNG dictates games »). Principe à appliquer : **RNG dans la CONSTRUCTION (shop, drops), déterminisme dans la RÉSOLUTION (combat)**. Le joueur accepte la malchance de shop s'il sait que, une fois son plateau posé, le résultat est mérité. Évitez le ciblage aléatoire en combat ; préférez des règles fixes — Super Auto Pets est totalement déterministe : l'unité la plus à droite frappe la plus à gauche adverse.

#### 1.2 Les synergies positionnelles (le cœur « Batomon »)

C'est votre mécanique préférée et la plus à fort levier pour la profondeur. Dans Batomon Showdown, des créatures buffent leurs **voisins adjacents** (valeurs aux niveaux 1/2/3) :

- **Geminiss** : « On Cast — augmente le Shielding des alliés adjacents de **100%/200%/300%** pour ce combat », cooldown 10 s.
- **Draconarch** : « On Cast — active les capacités 'Start of Battle' des alliés adjacents » (multicast d'effets de début de combat).
- **Stellagon** : donne aux alliés adjacents **sans capacité** un bonus de **multicast**.
- L'UI surligne les cases affectées (adjacents en **rouge**, non-adjacents en **jaune**) — détail crucial de lisibilité.

Les deux effets-clés sont le statut **shock** (électrique) et le **multicast**. D'après les notes officielles du développeur (berrymint, patch 0.5.0), le shock « scale multiplicativement avec lui-même, puisqu'il augmente le rythme d'application du shock et la fréquence de son déclenchement » ; le multicast fait déclencher une capacité plusieurs fois (ex. Puffloon : multicast 1/2/3 selon le niveau). Une créature au **centre** peut donc recevoir shock (du voisin gauche) ET multicast (du voisin droit) → c'est là que naît le puzzle positionnel.

**Comment TFT/Bazaar/Backpack gèrent le placement** :

- **TFT** : grille hexagonale ; le placement compte (front/back line) mais les synergies (« traits ») sont surtout des comptes d'unités d'un même type, pas de l'adjacence stricte.
- **The Bazaar** : plateau **linéaire** ; de nombreux objets font « quand tu utilises l'objet à ma DROITE/GAUCHE… » (ex. « When you use the item to the right of this, Charge the item to the left of this ») — c'est l'adjacence Batomon appliquée aux objets.
- **Backpack Battles** : grille 2D type Tetris où l'adjacence ET la forme comptent. C'est le plus riche, mais le plus complexe à coder/équilibrer (le joueur démarre avec 12 or et 25 PV, un shop de 5 objets rerollable, et une grille de 12-14 tuiles sur 63).

**Recommandation tranchée** : adoptez un **plateau multi-rangées** (voir 1.3), PAS une rangée linéaire unique (trop pauvre en compositions) NI une grille 2D Tetris à formes/rotations/collisions (trop coûteuse à coder et équilibrer en V1). Le sweet-spot est un **plateau-graphe 3×3** avec adjacence orthogonale : trivialement codable, lisible, et déjà explosif combinatoirement.

#### 1.3 Le plateau : 3×3, graphe d'adjacence explicite, et grille mutable (mécanique centrale)

**Le point conceptuel fondamental** : dans un jeu où toute la profondeur naît de l'adjacence, **la forme de la grille EST le graphe de synergies**. Passer d'une rangée à plusieurs n'ajoute donc pas « des cases » — ça enrichit la topologie des combos possibles. C'est pourquoi une rangée linéaire unique est insuffisante : elle plafonne le réseau de synergies à « 2 voisins max, pas de boucle ».

**Format de base : 9 slots, 3×3, adjacence orthogonale (haut/bas/gauche/droite — PAS les diagonales).** Je tranche pour le 9 plutôt que le 2×4 pour une raison précise : en 3×3 orthogonal, on obtient une **hiérarchie de cases lisible** — le centre a 4 voisins, les bords 3, les coins 2. Ça crée une case « roi » au milieu : c'est *là* qu'on pose le carry star-up qui veut empiler les buffs (shock du voisin gauche + multicast du voisin droit + bouclier en haut + haste en bas — votre exemple Batomon, mais en croix). Le 2×4 est plus proche de Batomon visuellement mais **trop uniforme** : aucune case n'est spéciale, donc pas de point focal pour construire. Le 3×3 donne un « build autour du centre » immédiatement compréhensible. Les **diagonales sont écartées** : en 8-connexité le centre touche tout le monde, ce qui tue le puzzle et rend le combat illisible.

**La grille mutable (sigils-reliques) — votre meilleure idée, et thématiquement parfaite.** Inspiration directe : le **système d'idoles de Last Epoch** que vous décrivez — un nombre de slots fixe, mais dont la *forme* du réceptacle peut changer (un polygone devient triangle, cercle…), transformant le puzzle de placement sans inflater la puissance. Transposé chez vous : des **reliques-sigils** redessinent la topologie du plateau en **gardant les 9 slots constants**. On échange une topologie contre une autre, on n'augmente pas la puissance brute — votre instinct d'équilibrage est juste.

**Nuance d'équilibrage cruciale** : ne cherchez **pas** à donner à toutes les formes le même nombre total d'arêtes. Cherchez à ce que **chaque forme ait un archétype qui l'adore**. La « justice » vient de là, pas d'une égalité de connexions. Chaque forme concentre ou disperse l'adjacence différemment :

- **Croix / plus** (centre à 4 voisins, branches isolées) → build **mono-carry extrême** : un monstre nourri par 4 voisins, mais les nourriciers sont faibles.
- **Cercle / anneau** (chaque case 2 voisins, mais en boucle fermée) → builds de **chaîne/propagation** : un effet qui se propage et *boucle* sur lui-même.
- **Diamant** (adjacence répartie, beaucoup de cases à 2-3 voisins) → builds **« go wide »** / essaim où tout le monde se buff un peu.
- **Ligne** (max 2 voisins, pas de boucle) → builds **conduit** qui propagent du début à la fin.

La forme *exprime* l'archétype : cartographie mécanique→stratégie d'une propreté redoutable. **Bonus eldritch** : la géométrie non-euclidienne est un motif **central** de Lovecraft (l'architecture de R'lyeh est décrite comme non-euclidienne, aux angles « faux »). Une relique qui redessine la géométrie de votre cercle d'invocation, où les formes « blasphématoires » débloquent de la puissance, fusionne thème et mécanique exactement — pas un habillage. Vous pouvez même cacher ça dans votre boucle de reliques cryptiques : la forme d'un sigil-relique ne se révèle qu'en l'équipant. La grille de base est le « carré du novice » ; les sigils corrompus la déforment.

**Architecture — et c'est là que ça reste simple malgré la profondeur.** Ne dérivez **pas** l'adjacence des coordonnées. Définissez chaque forme comme un **graphe explicite** : une liste de cases (pour le rendu) + une liste d'arêtes (pour l'adjacence).

```lua
Shape = {
  nom = "carre_novice",
  cases  = { {x=0,y=0}, {x=1,y=0}, {x=2,y=0}, {x=0,y=1}, ... }, -- positions d'affichage
  aretes = { {1,2}, {2,3}, {2,5}, {4,5}, ... },                 -- qui est adjacent à qui
}
-- résolution des synergies : pour chaque unité, on lit ses voisins via `aretes`. Point.

```

Avec les arêtes explicites, **toute** topologie devient exprimable — y compris des liens « impossibles » où deux cases visuellement éloignées sont mystiquement adjacentes (encore le non-euclidien, et c'est gratuit). Chaque slot porte **deux couches de données indépendantes** : sa position de rendu `(x,y)` (utilisée pour le ciblage front/back, cf. 1.4) et ses arêtes de graphe (utilisées pour les synergies). Changer de forme = swapper les listes ; les unités dont la case disparaît retournent au banc, le joueur les replace (ce qu'il *veut* faire de toute façon pour exploiter la nouvelle géométrie).

**La leçon d'archi : construisez le plateau comme un graphe dès le jour 1, même si la V1 ne ship qu'une seule forme.** Ajouter des sigils plus tard = ajouter de la data, zéro refacto. Votre complexité vit dans les **données** (formes, arêtes, synergies), pas dans le code. Séquençage : V1 en 3×3 fixe avec l'archi graphe en place + 2-3 sigils dès le départ pour valider que la rotation de formes est fun, puis extension du bestiaire de sigils au fil du temps.

#### 1.4 Le ciblage front/back (inclus dès la V1)

Vous avez **deux couches positionnelles distinctes et compatibles** : l'**adjacence** (qui détermine les synergies, cf. 1.3) et le **front/back** (qui détermine le ciblage : qui se fait taper en premier). Si le ciblage suit la **colonne** — le combat se résout de gauche à droite, le front = les cases les plus à droite (plus haut `x`) — alors **n'importe quelle forme conserve un « plus à droite »**, donc le système de front survit aux changements de topologie. C'est précisément pour ça que les deux couches de données par slot (position de rendu vs arêtes) sont séparées : le ciblage lit le `x`, les synergies lisent les arêtes, indépendamment.

**Mieux : la forme modifie votre profil de tank.** Une forme large présente un front de 3 tanks ; un diamant présente une pointe — un seul tank encaisse tout mais protège tout le reste. Donc **changer de sigil change à la fois vos synergies ET votre ligne de front** : deux mécaniques pour le prix d'une, 100% cohérentes. L'inclusion en V1 ajoute une tension de build savoureuse : « ma case de synergie idéale (le centre, 4 voisins) est aussi une case exposée » — le joueur arbitre en permanence entre puissance de synergie et survie. C'est le genre de décision qui fait la profondeur sans ajouter une seule règle nouvelle.

Modèle de ciblage recommandé (simple et déterministe, façon Super Auto Pets) : chaque entité frappe la cible adverse vivante la plus avancée dans sa ligne de mire (front d'abord). Pas de ciblage aléatoire. Variantes par type plus tard (assassins qui visent le back, AoE qui touche une colonne) — mais en V1, gardez une règle de ciblage unique et lisible.

#### 1.5 Duplicatas, montée en niveaux, et leveling comme déblocage de slots

**Système de fusion (TFT, repris par Batomon)** : collecter **3 copies** d'une unité la fait monter d'un niveau ; **max 3 niveaux** ; stats et capacités scalent par niveau. Dans Batomon, le format L1/L2/L3 est universel (ex. shield 200/400/600, shock 30/60/90 ; le buff d'adjacence de Geminiss passe de 100% → 200% → 300%). Note : un niveau 4 caché et surpuissant existe dans Batomon, très difficile à atteindre — bon « easter egg » de skill, à manier avec prudence pour l'équilibrage. Codage trivial : un compteur de copies par unité ; à 3, on remplace par la version supérieure. L'une des mécaniques au meilleur rapport profondeur/effort.

**Implications économiques** (le génie de TFT) : ce système crée une tension permanente. Chaque or dépensé en reroll cherche une 3ᵉ copie ; chaque copie sur le banc est un pari. **Interaction décisive avec le plateau** : monter une unité de niveau, c'est aussi renforcer le buff qu'elle donne à ses voisins — donc le star-up et la position se multiplient. Une unité niveau 3 au **centre** d'une grille en croix qui buff ses 4 voisins est un sommet de build.

**Le leveling comme régulateur de lisibilité — révision importante de ma reco précédente.** Avec un plateau de 9 slots, le risque n°1 est l'illisibilité quand 9 entités tapent en même temps. La réponse est le **leveling à la TFT comme déblocage de slots** : vous ne démarrez **pas** à 9. Vous fieldez 2-3 entités au début, et vous **débloquez des cases en montant de niveau** (achat d'XP). Les premiers combats sont calmes et lisibles, les combats tardifs sont pleins. Ça résout la lisibilité ET ça donne enfin un rôle central à l'économie de niveau. **Je révise donc explicitement** : le leveling n'est pas « pour la V2 », c'est un **pilier dès la V1** — c'est lui qui cadence la montée en complexité du plateau. Suggestion : commencer à 3 slots actifs (une seule rangée jouable au début), débloquer la 2ᵉ puis la 3ᵉ rangée par paliers de niveau, jusqu'aux 9 slots en fin de run.

#### 1.6 L'économie et la progression

Synthèse des meilleurs systèmes :

- **TFT** : revenu de base + **intérêts** (+1 or par tranche de 10 or possédés, plafonné à +5 à 50 or) + **streaks** (séries de victoires OU de défaites donnent de l'or) + leveling (achat d'XP pour améliorer les odds du shop ET, chez vous, débloquer des slots) + reroll. Tension centrale : économie vs puissance immédiate (les PV servent de ressource).
- **The Bazaar** : structure en **jours/heures** ; chaque jour = quelques choix (marchand / événement / bonus gratuit) puis un combat. Revenu = « Income » cumulé chaque jour.
- **Super Auto Pets** : ultra-simple — 10 or par tour, pas d'intérêts. Preuve qu'on peut réduire l'économie à l'os et rester addictif.

**Recommandation tranchée** : prenez le squelette Super Auto Pets (or fixe par tour + reroll payant) PLUS le **leveling comme axe central** (il sert maintenant double emploi : odds de shop + déblocage de slots, cf. 1.5) PLUS une couche de tension lisible — les **streaks**. Ajoutez les **intérêts** seulement si les tests montrent l'économie trop plate. Les **augments** de TFT (modificateurs de run) sont excellents pour la rejouabilité mais à réserver à la V2.

#### 1.7 PvP asynchrone / combats fantômes

C'est le pilier technique. Backpack Battles, Super Auto Pets et The Bazaar matchent le joueur contre des **snapshots** de builds créés par d'autres joueurs, parfois des heures avant :

- **Backpack Battles** : « pre-recorded battles/backpacks… these are all real people » ; le jeu charge un build récent d'un autre joueur. Structure : ~5 vies, objectif de 10 victoires.
- **Super Auto Pets** (Wiki officiel) : « the game selects an opponent from a database of teams created by other players on the same turn and matches them against the player's team. The objective is to win 10 battles… Players start with 5 lives… players will gain one life at the start of turn 3 if they have lost any so far. » Et, crucialement (Wikipédia) : « Players battle against either, other players' teams, **or AI-generated teams, if there are no players at that turn** » — le fallback IA est la clé de l'amorçage.

**Implications serveur (gardées simples)** : vous n'avez besoin que de deux endpoints :

1. **Réception** : un build sérialisé (table Lua → JSON) à la fin de chaque tour, taggé par palier (« jour/tour » + niveau de puissance). Le snapshot doit inclure la **forme de plateau active** (le sigil équipé) en plus des unités et de leurs positions.
2. **Service** : un build aléatoire du même palier.

LÖVE2D inclut **LuaSocket** (requêtes HTTP) ; pas besoin de HTTPS natif ni de netcode. Un petit backend (VPS avec SQLite/Postgres, ou service serverless) suffit. Le combat se rejoue côté client à partir du snapshot + seed. **C'est radicalement plus simple que du multijoueur temps réel**, que les forums LÖVE déconseillent unanimement aux débutants (« concurrency for real-time multiplayer games is a hard problem »).

**Équité/fun de l'asynchrone** : la plainte n°1 de Super Auto Pets est le matchmaking par nombre de victoires (un joueur peut affronter quelqu'un avec plus de ressources). Leçon : **matchez par palier de tour/jour (ressources équivalentes), pas par victoires**. Stockez le niveau de puissance avec chaque snapshot.

#### 1.8 Rejouabilité et profondeur à partir de règles simples

Le fil conducteur de TOUS les jeux étudiés (Balatro, Luck Be a Landlord, Super Auto Pets, Backpack Battles) : **un petit jeu de règles + un réseau dense de synergies = profondeur émergente quasi infinie**. Luck Be a Landlord le formule parfaitement : des symboles individuellement simples deviennent un « puzzle de probabilités » via leurs interactions ; les items reconfigurent le fonctionnement plutôt que d'ajouter des stats. Chez vous, **la grille mutable est un multiplicateur de rejouabilité** : chaque forme rouvre l'espace de builds, et les reliques cryptiques rouvrent l'espace de connaissance. Principe directeur : **« simple à implémenter, profond à jouer »** — la profondeur vient des COMBINAISONS (unités × position × forme × reliques), pas du nombre de mécaniques.

#### 1.9 Ce qu'il faut ÉVITER

- **Trop de RNG en combat** (cf. Mechabellum) : gardez le combat déterministe.
- **Grille 2D Tetris** (Backpack Battles) en V1 : formes/rotations/collisions d'objets font exploser l'équilibrage et le code. Le plateau-graphe à slots fixes (1.3) en garde la richesse positionnelle SANS la complexité Tetris — ne confondez pas les deux.
- **Égaliser les arêtes de toutes les formes mutables** : ne visez pas l'égalité de connexions mais « une forme = un archétype qui l'aime » (cf. 1.3). Vouloir des formes parfaitement symétriques en puissance les rendrait fades et difficiles à équilibrer.
- **Boucles de rétroaction négatives** : un joueur malchanceux tôt ne doit pas être condamné (Slay the Spire mitige par des relics/soins). Prévoyez des rattrapages (récupération de vie au tour 3 comme SAP, streaks de défaite payantes).
- **Netcode temps réel** : hors de portée d'un solo débutant.
- **Effets « globaux » illisibles** : si tout buffe tout, le joueur ne lit plus le combat. La force de l'adjacence, c'est justement la localité.
- **Multicast/cooldown non bornés** : Batomon a dû nerfer en boucle l'accès facile au multicast et au shock permanent (fights finissant « insanely fast »). Bornez dès le départ (plancher de cooldown, cap de multicast).
- **Trop de slots débloqués trop vite** : si les 9 cases sont actives dès le début, le combat est illisible et l'économie de leveling perd son sens. Le déblocage progressif (1.5) est une protection, pas une option.

#### 1.10 Analyse de cohérence

Mécaniques qui s'emboîtent SANS contradiction (système unifié) : cooldowns auto-résolus + **plateau-graphe 3×3 mutable** + adjacence orthogonale + ciblage front/back par colonne + duplicatas TFT + **leveling = déblocage de slots** + trinkets par type + asynchrone fantôme + économie Super Auto Pets/streaks. La position détermine les synergies, la forme du plateau rouvre l'espace de position, les duplicatas amplifient à la fois les stats ET les buffs d'adjacence, le leveling cadence la complexité, les trinkets orientent les archétypes par type, l'économie alimente la chasse aux copies, et le front/back partage la même donnée de position que le rendu.

Mécaniques qui CRÉENT des contradictions (à éviter) :

- **Grille 2D Tetris (Backpack) + plateau-graphe à slots fixes** : deux paradigmes spatiaux concurrents. Le graphe à slots fixes gagne (richesse sans coût Tetris).
- **Économie TFT complète + structure jours (Bazaar)** : deux horloges de progression qui se cannibalisent. Choisissez-en une (les tours simples avec leveling).
- **Combat temps réel dynamique (TFT) + auto-résolution (Bazaar)** : incompatibles. Vous avez raison de ne vouloir que l'auto-résolution.

### PARTIE 2 — SAVOIR CRYPTIQUE, INFORMATION CACHÉE, IDENTIFICATION DES OBJETS

#### 2.1 La connaissance comme métaprogression

Le principe : la VRAIE progression n'est pas la puissance du personnage mais ce que le JOUEUR comprend. Outer Wilds en est l'archétype — un guide joueur le résume : « The game runs on your personal curiosity. **Your knowledge = game progression**. » Rien n'y est verrouillé en jeu : on peut finir Outer Wilds en repartant de zéro à chaque mort, armé seulement de notes ; le seul vrai blocage est « in your IRL head ». L'analyse de Game Developer le formule ainsi : « knowledge to become your upgrades… it's them [le joueur] who is improving, not their avatar. »

Pour votre jeu : l'effet d'une relique cryptique, une fois deviné/découvert, devient **connu de façon persistante** entre les runs. C'est la transposition exacte de ce principe à un autobattler — un terrain quasi vierge dans le genre.

#### 2.2 Mécaniques d'identification (tradition roguelike)

NetHack/Angband/DCSS : les objets (potions, parchemins) sont **non-identifiés** ; le joueur déduit ou teste. Tension risque/récompense : boire la potion inconnue peut sauver ou tuer. Une fois un type identifié, tous les objets de ce type le sont pour le reste de la partie. Critique connue (Golden Krone Hotel) : l'identification « à l'aveugle » peut frustrer les nouveaux joueurs. Leçon de design : offrez des **indices déductibles** plutôt qu'un pur tâtonnement.

**Différence clé pour votre jeu** : NetHack ré-identifie à chaque partie (par-run). Vous voulez l'inverse — une **identification persistante** (cross-run), proche d'un Pokédex. C'est plus gratifiant et plus thématique (accumulation de savoir interdit).

#### 2.3 Descriptions cryptiques comme design (Dark Souls/PoE/Bloodborne)

Dark Souls cache son lore dans les descriptions d'objets : le joueur absorbe l'histoire en gérant son équipement. La force : il reconstruit lui-même le sens (« description over exposition »). Le risque : qu'il ne réalise pas qu'il y a quelque chose à décoder.

**Faire de la flavor-text un puzzle SOLUBLE, pas une obscurité gratuite** — c'est la ligne de crête entre « mystère satisfaisant » et « obtusité frustrante ». Techniques concrètes :

- Chaque relique cryptique doit contenir **un indice vérifiable** (un mot-clé thématique pointant vers un type/archétype, ex. « ce qui rampe sous la peau » → poison/saignement).
- Le joueur formule une **hypothèse** puis la teste en combat ; le résultat observable confirme ou infirme.
- Récompensez la déduction par une **inscription au codex** (voir 2.4).

#### 2.4 Systèmes de savoir persistant (le codex)

Modèles :

- **Tunic** : un manuel cryptique se remplit page par page ; « most of Tunic's unlocks are actually the acquisition of knowledge ». Les pages recontextualisent rétroactivement tout ce qu'on croyait savoir. Frostilyte note un point crucial : les trinkets ne sont **pas expliqués avant la page 18** du manuel, et « players are a lot more likely to retain information they had to work out for themselves » — le joueur retient mieux ce qu'il a déduit lui-même.
- **Hades (codex)** : « As Zagreus encounters, gathers, speaks to, or slays the subjects of the Codex… the entries become more complete. » Les entrées se complètent par l'interaction ; la prophétie « Chthonic Knowledge » se valide après **70 entrées révélées**.
- **Return of the Obra Dinn** : déduction validée **par lots de trois** ; quand 3 fates corrects sont logués, « the game will immediately 'lock-in' those fates… They will change from handwritten in the book to print to indicate that they are correct and cannot be changed. » Ce « rule of three » empêche le brute-force et, d'après Wikipédia, « became commonplace in the detective genre » après Obra Dinn. The Case of the Golden Idol reprend cela par segments verrouillés avec un indicateur « deux erreurs ou moins ».

**Recommandation tranchée pour votre jeu** : un **« Grimoire des reliques »** qui se remplit à la découverte. Mécanisme anti-brute-force inspiré d'Obra Dinn : le joueur **propose une interprétation** de la relique (parmi des fragments d'effet) ; l'effet réel ne se **verrouille** dans le grimoire (passage du « manuscrit » à l'« imprimé ») qu'après confirmation par l'observation en combat ou par recoupement de plusieurs indices. Cela transforme la découverte en gameplay actif, pas en simple lecture.

**Tension nouveau joueur vs vétéran** : un vétéran qui « a tout compris » perd le mystère. Solutions : (a) un grand pool de reliques avec rotation ; (b) des reliques à effets **contextuels** (l'effet dépend du type voisin ou de la forme du plateau, donc savoir le « quoi » ne suffit pas, il faut le « où/avec quoi ») ; (c) des variantes **« corrompues »** d'une relique connue qui brouillent les certitudes ; (d) à la Hades, faire que l'entrée se complète **par étapes** plutôt qu'en tout-ou-rien. Note : la grille mutable (1.3) renforce naturellement ce point — une relique dont l'effet dépend de la topologie active reste intéressante même une fois « identifiée », car son intérêt varie selon la forme.

#### 2.5 Intégration de l'esthétique lovecraftienne/cryptique

Le thème (Lovecraft + Path of Exile + Dark Souls : sale, sanglant, cryptique) est **mécaniquement natif** au système de savoir caché : l'inconnu eldritch, le savoir interdit, la folie, le déchiffrement. La relique cryptique N'EST PAS un habillage plaqué — elle EST le thème. Déchiffrer une relique = arracher un fragment de vérité interdite. **Et la grille mutable s'y branche directement** : la géométrie non-euclidienne (R'lyeh, les angles « faux ») fait des sigils déformants une expression mécanique du thème, pas une décoration. Redessiner son cercle d'invocation en une forme blasphématoire pour libérer une puissance interdite — thème et système ne font qu'un.

#### 2.6 La thèse de différenciation : validée, avec conditions

Votre conviction (changer le THÈME + ajouter des twists subtils suffit à rafraîchir un autobattler familier) est **largement validée** :

- **Balatro** : poker → roguelike deckbuilder ; succès colossal bâti sur un re-thème + jokers à synergies (inspiré ouvertement par Luck Be a Landlord). Décisif : LocalThunk explique avoir **rejeté le langage « gamery » fantasy/combat** — « I dislike the 'gamery' language of fantasy and combat that seem to be way overrepresented in video games… I wanted to lean on different verbiage and visuals » — et décrit le poker comme « a coat of paint to make this seem approachable ». **Le thème et le verbe choisi structurent toute l'expérience.** (Et, fait capital pour vous : **Balatro est codé en Lua avec le framework LÖVE** — preuve directe qu'un hit mondial du genre est réalisable dans votre stack.)
- **Luck Be a Landlord** : machine à sous → deckbuilder stratégique.
- **Super Auto Pets** : autobattler dépouillé + thème mignon = hit.

MAIS la condition est la **cohérence mécanique-thématique**. Un simple reskin cosmétique sans twist mécanique échoue ; le succès vient quand thème et mécanique se renforcent. Vos deux twists (reliques cryptiques + grille mutable non-euclidienne) sont des twists **mécaniques**, pas que des reskins — donc la thèse tient solidement. Défi honnête : l'exécution de la flavor-text « soluble » et l'équilibrage des formes mutables sont difficiles et demanderont beaucoup d'itération et de playtests.

### CONTRAINTE TECHNIQUE (fil rouge LÖVE2D)


| Mécanique                              | Facilité en LÖVE2D | Note                                                          |
| -------------------------------------- | ------------------ | ------------------------------------------------------------- |
| Combat cooldowns auto-résolu           | ★★★★★ Très facile  | File de timers + `update(dt)`                                 |
| Plateau-graphe 3×3 (arêtes explicites) | ★★★★★ Très facile  | `cases` + `aretes`, voisins lus dans le graphe                |
| Adjacence orthogonale (synergies)      | ★★★★★ Très facile  | Parcours de la liste d'arêtes                                 |
| Ciblage front/back (par colonne/`x`)   | ★★★★★ Très facile  | Tri par position de rendu, cible la plus avancée              |
| Grille mutable (sigils-reliques)       | ★★★★☆ Facile       | Swap de la data de forme ; complexité = données, pas code     |
| Duplicatas 3 → niveau                  | ★★★★★ Très facile  | Compteur de copies                                            |
| Leveling = déblocage de slots          | ★★★★★ Très facile  | Paliers d'XP → activation de cases                            |
| Économie tours + streaks               | ★★★★☆ Facile       | Variables d'état                                              |
| Asynchrone fantôme (HTTP + JSON)       | ★★★☆☆ Modéré       | LuaSocket + petit backend ; sérialiser unités+positions+sigil |
| Grille 2D Tetris (Backpack)            | ★★☆☆☆ Difficile    | À éviter en V1 (distinct du plateau-graphe)                   |
| Pixel art auto-généré                  | ★★★☆☆ Modéré       | Voir ci-dessous                                               |


**Pixel art auto-généré** : faisable et thématiquement pertinent. Approches du plus sûr au plus avancé :

- **Recombinaison de parties** (la plus sûre) : découper des sprites en composants (têtes, corps, membres), recolorer via des « color ramps » par matériau, recombiner aléatoirement. Méthode éprouvée (Oryx GenJam), parfaite pour des monstres eldritch variés.
- **Algorithme type « pixel-sprite-generator » (Zfedoran)** : génère des créatures 2D symétriques procédurales (il existe même des portages réutilisables). Idéal pour un look « spécimens difformes ».
- **Cellular automata** pour des textures organiques/sanglantes.
- **GAN (Pix2Pix/VQ-VAE)** : techniquement possible mais **hors-budget pour un débutant** ; à réserver à plus tard.

Le pixel art auto-généré **renforce le thème** (créatures jamais vues, difformes, cohérentes avec l'inconnu lovecraftien) ET réduit drastiquement la charge artistique d'un solo dev. Contrainte : adoptez un style « low-fi sale » qui pardonne les imperfections de génération — ce qui colle exactement à l'esthétique visée.

## Recommendations

### Synthèse cohérente : esquisse de design

**« GRIMOIRE » (titre de travail) — autobattler asynchrone eldritch.**

**Boucle de base** : le joueur incarne un occultiste assemblant une **congrégation d'entités** sur un **plateau-graphe 3×3 (9 slots)**. On démarre avec 2-3 cases actives ; on **débloque les autres en montant de niveau** (achat d'XP). Chaque jour : phase shop (acheter entités/reliques, réorganiser, reroll payant, monter de niveau) → combat auto-résolu contre le **fantôme** d'un autre joueur du même palier. But : 10 victoires avant d'épuiser ses ~5 vies (structure roguelite Super Auto Pets/Backpack), avec récupération d'une vie au tour 3 si l'on a perdu tôt.

**Combat** : cooldowns en secondes (1-12 s), déterministe (seed stockée), petits nombres, barres de cooldown visibles. Marée montante (« Fatigue ») après ~17 s pour forcer une fin. **Ciblage front/back par colonne** (front = cases les plus à droite) : l'unité frappe la cible adverse vivante la plus avancée.

**Profondeur positionnelle (cœur)** : adjacence **orthogonale** (haut/bas/gauche/droite). Chaque entité buffe ses voisins (shock, multicast, bouclier, poison…). Le **centre (4 voisins) est la case carry** ; bords 3 voisins, coins 2. Tension permanente : la meilleure case de synergie est aussi exposée. UI surlignant les cases affectées.

**Grille mutable (signature mécanique)** : des **reliques-sigils** redessinent la topologie du plateau en **gardant 9 slots** (inspiration : idoles de Last Epoch). Chaque forme adore un archétype — croix/mono-carry, cercle/chaîne en boucle, diamant/go-wide, ligne/conduit. Géométrie non-euclidienne = expression directe du thème lovecraftien. Implémenté comme **graphe à arêtes explicites** (data, pas code) ; chaque slot porte position de rendu (pour le ciblage) + arêtes (pour les synergies), indépendamment.

**Duplicatas** : 3 copies → niveau supérieur (max 3) ; stats ET buffs d'adjacence scalent (×1/×2/×3). Le star-up et la position se multiplient.

**Reliques cryptiques (2ᵉ signature)** : items à **flavor-text non explicite**. Le joueur déduit l'effet, l'observe en combat, puis le **verrouille dans le Grimoire** (codex persistant cross-run, anti-brute-force à la Obra Dinn). Bonus par **type d'entité** (eau/soin, roche/bouclier, électrique/shock, poison/DoT, feu/brûlure — identités d'archétype empruntées à Batomon). Effets **contextuels** (dépendant du type voisin ou de la forme active) pour rester intéressants après identification.

**Économie** : or fixe par tour + reroll payant + **leveling central** (odds de shop + déblocage de slots) + **streaks**. Intérêts et augments en V2.

**Asynchrone** : snapshots JSON (unités + positions + sigil actif) envoyés/servis par palier via HTTP (LuaSocket + petit backend), avec **fallback IA**. Combat rejoué côté client à partir du snapshot + seed.

**Art** : sprites de monstres procéduraux (recombinaison de parties + color ramps), style low-fi sale/sanglant.

### Étapes concrètes (par paliers)

1. **Prototype hors-ligne (4-6 semaines)** : combat à cooldowns + **plateau 3×3 en graphe (arêtes explicites)** + adjacence orthogonale + ciblage front/back + déblocage progressif des slots par leveling + 8-10 entités + duplicatas + **2-3 sigils** pour valider la rotation de formes. Adversaires = équipes scriptées. *Seuil de passage : le combat est lisible (grâce au déblocage progressif), le placement change l'issue, et changer de sigil change visiblement la stratégie.*
2. **Économie + run roguelite** : shop, reroll, or, leveling, streaks, 5 vies, 10 victoires. *Seuil : le ressenti « encore une partie » en playtest solo.*
3. **Reliques cryptiques + Grimoire** : 15-20 reliques à effets par type/contextuels, flavor-text soluble, codex persistant. *Seuil : des testeurs déduisent correctement ≥ 50% des reliques sans guide.*
4. **Asynchrone** : sérialisation JSON (incluant le sigil), backend minimal, matchmaking par palier, fallback IA. *Seuil : un build posté par le joueur A est rencontré par le joueur B.*
5. **Pixel art procédural + polish + extension** : générateur de sprites, VFX de combat, journal de combat, **élargissement du bestiaire de sigils** (zéro refacto grâce à l'archi graphe), augments.

### Seuils qui changeraient la recommandation

- Si les playtests montrent que la flavor-text cryptique frustre (&lt; 30% de déductions correctes) → ajoutez des **indices progressifs** (à la Hades, l'entrée se complète par étapes) plutôt que du tout-ou-rien.
- Si l'économie à tours fixes paraît plate → ajoutez les **intérêts**, puis les augments.
- Si le 3×3 paraît trop vertical/profond à l'usage → repliez sur le **2×4 (8 slots)** comme fallback (toujours en graphe, toujours mutable) ; n'allez **pas** vers une grille Tetris.
- Si une forme de sigil domine ou est ignorée → ré-équilibrez par **l'archétype qu'elle sert** (buffer les unités qui aiment cette topologie), pas en égalisant ses arêtes.
- Si le combat à 9 entités reste illisible malgré le déblocage progressif → ralentissez la cadence de déblocage des slots et/ou réduisez le plafond de multicast.
- Si le backend asynchrone est trop lourd → démarrez en **« pseudo-asynchrone »** : pool local d'équipes IA + builds pré-enregistrés livrés avec le jeu, puis branchez le serveur ensuite (modèle Super Auto Pets avec fallback IA confirmé par Wikipédia).

### Les 5 décisions à plus fort levier

1. **Plateau-graphe 3×3 mutable + sigils** (PAS de rangée unique, PAS de grille Tetris) : la forme du plateau devient un axe de build entier ; richesse positionnelle maximale, complexité vivant dans la data, et fusion thème/mécanique (non-euclidien lovecraftien). C'est votre meilleur twist mécanique.
2. **Combat déterministe à seed + ciblage front/back par colonne** : rend l'asynchrone trivial, le jeu juste/vérifiable, et fait survivre le système de front à tous les changements de forme.
3. **Asynchrone par snapshots JSON + fallback IA** : multijoueur sans netcode.
4. **Reliques cryptiques + Grimoire persistant** : votre différenciateur narratif unique, thématiquement natif, renforcé par les effets contextuels liés à la grille.
5. **Leveling = déblocage progressif des slots** : un seul levier qui résout simultanément la lisibilité du combat à 9 entités, donne son sens à l'économie de niveau, et cadence la montée en complexité de chaque run.

## Caveats

- **Batomon Showdown est un jeu indie en demo (versions ~0.5-0.7)** : les chiffres exacts (cooldowns, %) sont spécifiques à une version et bougent à chaque patch. Le format L1/L2/L3 et le terme « level up merge » confirment fortement le modèle « 3 copies → niveau », mais **aucune phrase officielle ne dit littéralement « 3 copies = niveau »** — c'est une inférence solide. Batomon est par ailleurs fait sous **Godot**, pas LÖVE2D.
- **Le système d'idoles de Last Epoch** est cité comme *source d'inspiration* pour la grille mutable, pas comme spécification à reproduire ; le mécanisme « sigils qui remorphent la topologie à slots constants » est votre design, pas une copie d'un patch précis. Adaptez-le librement.
- **La grille mutable ajoute une dimension d'équilibrage réelle** : chaque forme rouvre l'espace de builds, donc chaque sigil multiplie la surface à tester. C'est puissant mais exige de la discipline — limitez le nombre de sigils en V1 (2-3) et élargissez seulement quand l'équilibrage de base est stable.
- La génération de pixel art par **GAN** est citée comme possible mais reste hors de portée d'un débutant ; seules les approches par **recombinaison de parties / automates cellulaires** sont réalistes en V1.
- La vraie difficulté du projet n'est **pas le code** (les mécaniques retenues sont simples, l'archi graphe garde la complexité dans la data) mais **l'équilibrage** (Batomon nerfe le shock/multicast en boucle ; les formes mutables démultiplient les cas) et **l'écriture de flavor-text soluble** — prévoyez beaucoup d'itération et de playtests.
- L'asynchrone suppose une base de joueurs : sans masse critique, **prévoyez dès le départ** le fallback IA + des builds pré-enregistrés livrés avec le jeu.
- Plusieurs sources de Partie 1 (guides communautaires, wikis Fandom, posts Steam) sont de qualité variable ; les faits structurants (mécaniques Bazaar/Backpack/SAP, économie TFT, citation LocalThunk, « rule of three » Obra Dinn) sont en revanche corroborés par des sources fiables (wikis officiels, Wikipédia, interviews développeurs).

