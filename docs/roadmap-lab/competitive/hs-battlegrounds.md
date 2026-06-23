# Analyse ultra-approfondie — Hearthstone Battlegrounds

> **Mandat** : teardown PRECIS de chaque mécanisme → psychologie (pourquoi ca hook) →
> MATHS chiffrées et SOURCEES → VERDICT DE TRANSFERABILITE a The Pit (async snapshots,
> run court 10 victoires, sim déterministe, grimdark). Demonter les analogies paresseuses.
>
> **Sources primaires** utilisées (URLs citées dans le corps) :
> - hearthstone.wiki.gg (wiki officiel communautaire, mis a jour patch courant)
> - sat.bgknowhow.com (référence stratégique vérifiée avec tables de données)
> - playhearthstone.com / hearthstone.blizzard.com (posts officiels Blizzard)
> - hearthstonetopdecks.com (analyses et traductions des developer insights)
> - esports.gg/news/hearthstone (analyses MMR et monétisation)
> - gamedeveloper.com (interviews dev GDC 2019)
> - game.info.intel.com (interview Corning/Ayala sur la conception)
> - ACM DL research paper (motivations joueurs OCCG, 2019)
> - Frontier Psychology 2016 (partial reinforcement et gambling)
>
> **Garde-fou** : ce document n'édite aucun code. Lecture seule du repo.
> Ecriture exclusivement sous docs/roadmap-lab/.

---

## 0. Contexte : ce qu'est HS Battlegrounds

HS Battlegrounds (lancé novembre 2019) est un autobattler à 8 joueurs intégré à Hearthstone.
Chaque round : phase **Recruit** (boutique) puis phase **Combat** (auto). Objectif : être le
dernier survivant. Durée typique d'une partie : 20-30 minutes.
Source : [hearthstone.wiki.gg/wiki/Battlegrounds](https://hearthstone.wiki.gg/wiki/Battlegrounds)

---

## 1. MECANISME #1 — Economie d'or : ressource fraiché, non banquée

### 1.1 Teardown précis

Chaque tour, le joueur reçoit de l'or **frais** (non reporté au tour suivant) :
- Tour 1 : **3 or** (mana cap départ)
- Tour 2 : **4 or** (+ 1 / tour)
- Tour 3 : **5 or**
- ...jusqu'a **10 or** (cap absolu)

L'or non dépensé est **perdu**. Aucun intérêt. Pas de banque.

**Coûts fixes in-boutique** :
- Acheter un serviteur : **3 or** (quel que soit son tier)
- Vendre un serviteur : **+1 or** (remboursement)
- Reroll boutique : **1 or**
- Freeze boutique (garder pour le prochain tour) : **gratuit** (jusqu'a 5× par phase)
- Upgrade taverne : voir §2

Source : [icy-veins.com mécaniques guide](https://www.icy-veins.com/hearthstone/hearthstone-battlegrounds-mechanics-guide) ; [hearthstone.wiki.gg/wiki/Battlegrounds](https://hearthstone.wiki.gg/wiki/Battlegrounds)

### 1.2 La « curve » standard — les maths du tempo

La courbe optimale connue (source : [hearthstone-decks.net BG guide 11.5k MMR](https://hearthstone-decks.net/hearthstone-battlegrounds-guide-by-11-5k-mmr-player/)) :

| Tour | Or | Action |
|------|----|--------|
| 1 | 3 | Acheter 1 serviteur |
| 2 | 4 | Upgrade taverne T2 (coût 4) |
| 3 | 5 | Vendre 1 token + acheter 2 |
| 4 | 6 | Acheter 2 |
| 5 | 7 | Acheter 1 + Upgrade T3 (coût 4 apres 1 tour de réduction) |
| 6 | 8 | Acheter 2 ou Upgrade T4 |

La **réduction de -1 or par tour non-upgradé** (source : [bgknowhow.com](http://sat.bgknowhow.com/bgstrategy/general.php)) est le levier de tension principal : plus on attend, moins l'upgrade coûte, mais plus on reste sur des serviteurs faibles. C'est le **dilemme tempo vs puissance** fondamental du jeu.

### 1.3 Psychologie

L'or frais non-reporté crée une **pression de dépense immédiate** (pas de banque = pas de stratégie de rétention). Ce choix :
1. **Élimine la complexité d'intérêt** (présent dans TFT : +1 or / 10 or banqués, cap +5) — le jeu se joue dans l'instant, pas dans l'accumulation.
2. **Force des décisions à chaque tour** — chaque or non dépensé est une erreur. Cela génère une tension cognitive permanente, mais jamais d'analyse paralysante (les chiffres sont petits : 3-10).
3. L'**alternance gain / dépense / perte** ressemble à ce que la psychologie comportementale appelle une **partial reinforcement schedule** — récompenses variables (quels serviteurs offerts, upgrade ou achat ?) qui maintiennent l'engagement mieux qu'un schéma fixe (source : [Frontiers Psychology 2016, partial reinforcement](https://www.frontiersin.org/journals/psychology/articles/10.3389/fpsyg.2016.00046/full)).

Blizzard a explicitement rejeté l'économie TFT avec intérêt pour HS:BG : interview GDC 2019 — les devs voulaient un mode « qui ne se sent pas aussi polarisant » (source : [gamedeveloper.com](https://www.gamedeveloper.com/design/why-the-i-hearthstone-i-devs-wanted-to-make-an-auto-battler)).

### 1.4 Verdict de transférabilité a The Pit

**The Pit utilise déja ce modèle** (or fixe 10/round, GOLD_PER_ROUND = 10, sans banque — state.lua). La lecon HS:BG **confirme le choix** mais ne l'affine pas.

**Analogie paresseuse a éviter** : « HS:BG fait des rerolls a 1 or, The Pit aussi, donc c'est la même chose ». Non. HS:BG a 5 offres toujours visibles + freeze gratuit = l'information est très riche. The Pit a 5 offres aussi mais le **freeze est absent** (chaque round renouvelle la boutique). Le freeze de HS:BG est un levier stratégique que The Pit n'a pas encore et qui mériterait d'être évalué séparément (cf. §9).

**Ce qui manque a The Pit :** The Pit n'a pas de **curve de pression différenciée** par tour. En HS:BG, le dilemme upgrade-taverne crée une tension *organique* qui structure chaque phase de jeu. The Pit a son équivalent dans le déblocage de slots (XP-gating par tier de boutique), mais la **visibilité du coût decroissant** (upgrade coûte -1 / tour passé) n'existe pas. Ajouter ce type de signal (« upgrade disponible, coût diminue ») pourrait amplifier la tension sans modifier la mécanique sous-jacente.

---

## 2. MECANISME #2 — Upgrade de taverne : gating progressif + pression temporelle

### 2.1 Teardown précis

**Coûts de base d'upgrade** (source : [bgknowhow.com tables](http://sat.bgknowhow.com/bgstrategy/general.php)) :

| De T | Vers T | Coût de base | Réduction /tour non-upgradé |
|------|--------|--------------|----------------------------|
| 1 | 2 | 5 or | -1 (minimum 1) |
| 2 | 3 | 7 or | -1 |
| 3 | 4 | 8 or | -1 |
| 4 | 5 | 10 or | -1 |
| 5 | 6 | 10 or | -1 |
| 6 | 7 | 10 or | -1 (Tier 7 = spécial seulement) |

**Nombre de serviteurs offerts par tier** :
- T1 : 3 | T2 : 4 | T3 : 4 | T4 : 5 | T5 : 5 | T6 : 6 | T7 : 6

**Copies de chaque serviteur dans le pool partagé** :
- T1 : 15 copies | T2 : 15 | T3 : 13 | T4 : 11 | T5 : 9 | T6 : 7 | T7 : 5

Source : [bgknowhow.com](http://sat.bgknowhow.com/bgstrategy/general.php) ; [followchain.org pool size](https://www.followchain.org/battlegrounds-shared-pool-size/)

Note historique : les copies T1 ont varié entre 16 et 18 selon les patches ; la valeur courante (15) est celle du patch actuel.

### 2.2 Psychologie

L'upgrade de taverne est le **principal axe de décision long terme** du jeu. Il crée :

1. **Tension tempo vs puissance** : monter vite = moins de serviteurs achetés tôt = davantage de pertes et dégâts reçus. Attendre = s'exposer a des adversaires plus puissants. C'est un **dilemme de timing** qui exige une lecture du lobby (quels adversaires montent vite ?).

2. **Anticipation informée** : chaque tour, le joueur *sait* que le coût baisser d'1 or s'il n'upgrade pas. Cette **transparence complète** du coût futur transforme chaque tour en micro-décision d'optimisation. Contrairement a un slot machine (opaque), ici l'agence est totale — ce qui produit un **sentiment de compétence** documenté comme moteur de rétention dans les jeux multijoueurs (source : [Celia Hodent, GDC 2017, Gamer's Brain UX](https://celiahodent.com/gamers-brain-part-3-ux-engagement-immersion-retention-gdc17-talk/)).

3. **Lisibilité des autres joueurs** : l'upgrade de tier est **visible de tous** (un drapeau affiché a côté de Bob). Cela crée une **pression sociale de menta** — si tous les adversaires sont T4 et que vous êtes T2, la pression psychologique de rattraper est réelle, même sans mécanique coercitive.

### 2.3 Verdict de transférabilité a The Pit

**Analogie paresseuse a démolir** : « HS:BG a des tiers d'upgrade, The Pit a des niveaux de boutique (XP-gating), c'est la même chose, donc adaptons les coûts HS:BG ». Non.

La différence **architecturale fondamentale** :
- HS:BG : l'upgrade est une **décision de timing** (quand dépenser l'or). La puissance des serviteurs offerts monte. Les cotes par tier changent.
- The Pit : l'upgrade de tier débloquerait l'**accès à des serviteurs de rang superieur** (cost=rank). L'XP s'accumule passivement (+1/round) ou s'achète (4 XP pour 4 or, ratio 1:1). Le *rythme* est différent : pas de pression -1/tour, mais une montée continue.

**Ce qui survive** : la notion de **signal public de progression** (le drapeau tier visible). Dans The Pit async (snapshots), ce signal n'existe pas en temps réel — mais il pourrait exister dans l'interface du Grimoire ou du profil de run (afficher le tier max atteint en run). La **pression de lobby** (HS:BG) ne se transpose pas en async pur.

**Ce qui ne survive pas** : la réduction -1/tour. This mechanic crée sa tension sur 10 joueurs qui voient les drapeau des autres en temps réel. En The Pit async, personne ne voit les autres monter. La tension existe déja dans la *boutique elle-même* (qu'est-ce que j'achète avec mes 10 or ?), pas dans la course au tier.

**Opportunité identifiée** : HS:BG prouve que le *coût variable visible* (vs coût fixe) amplifie l'engagement décisionnel. The Pit pourrait explorer un signal similaire : par exemple, un « rabais d'XP sur l'upgrade si on a perdu le round précédent » (filet anti-tilt), renforçant la lisibilité de la progression sans ajouter de complexité cache.

---

## 3. MECANISME #3 — Pool partagé : concurrence informationnelle

### 3.1 Teardown précis

Tous les joueurs piochent dans le **même pool de serviteurs** :
- Quand un serviteur est acheté → retiré du pool
- Quand vendu → remis dans le pool (un triple doré → retourne 3 normaux)
- Quand un joueur meurt → ses serviteurs retournent au pool

**Probabilité de voir un serviteur spécifique (ex. : T5 a Taverne T5)** (calcul approximatif, source : [chixu/battlegrounds-picker methodology](https://github.com/chixu/battlegrounds-picker)) :
- Soit N copies de chaque T5 dans le pool, M unités T5 distinctes
- Si N=9 copies, ~46 unités T5, pool total a T5 = 15×N_T1 + 15×N_T2 + 13×N_T3 + 11×N_T4 + 9×M_T5
- P(voir une unité T5 spécifique dans 1 offre) ≈ 5 × 9 / pool_total_T5

En pratique, avec 6 cartes offertes au T6, 7 copies de chaque T6, P(voir une T6 spécifique en 1 roll) ≈ 6×7 / total ≈ **3-5%** selon le nombre de joueurs encore en vie et les copies détenues.

### 3.2 Psychologie

Le pool partagé introduit une **concurrence informationnelle** : savoir ce que les adversaires détiennent (visible lors des combats) permet de calculer les chances de trouver ses propres copies. C'est du **skill d'observation** — pas du RNG pur.

Toutefois, c'est aussi une source de **frustration perçue** : si les seules copies d'un T6 clé sont chez deux adversaires, la probabilité chute de ~5% a ~0% sur plusieurs rolls. Les forums HS:BG documentent ce grief abondamment (source : [Blizzard forums « it's not random »](https://us.forums.blizzard.com/en/hearthstone/t/battlegrounds-sick-of-the-biased-tavern-ai-its-not-random/154529) ; [forums « skill vs luck »](https://us.forums.blizzard.com/en/hearthstone/t/battlegrounds-arent-skill-based-it-is-pure-luck/98470)).

La psychologie ici est **ambivalente** : le pool partagé crée de la tension et du skill, mais quand la RNG est perçue comme bloquante (copies épuisées), le joueur extériorise la responsabilité — mécanisme de **attribution externe** documenté comme facteur de churn (source : Celia Hodent GDC 2017, ibid.).

### 3.3 Verdict de transférabilité a The Pit

**Non transférable directement** — et pour une raison architecturale, pas de resource.

The Pit est **async par snapshots** : il n'y a pas de lobby partagé en temps réel. Chaque run joue contre des **ghosts** (snapshots figés) ou des équipes IA. Il n'existe pas de pool commun de serviteurs entre joueurs.

**Ce qui existe a la place** : la **pression de rareté émulée** via les cotes par tier de boutique (T5 : 25-15% chances selon le tier). Un joueur ne peut pas « trouver un serviteur rare parce qu'un autre l'a pris » — mais il peut ne pas voir un rang 5 de toute une run parce que les cotes sont faibles. C'est du même *effet psychologique de rareté* via une mécanique différente et plus équitable.

**Opportunité** : dans un contexte async, la **rareté perçue** peut être amplifiée sans frustration réelle via des pools par rang (decision actée : cotes par tier de boutique). La piste du pool partagé entre joueurs actifs existe dans un backend online, mais c'est hors-budget v1 (snapstore.lua current = pool local 200 FIFO).

---

## 4. MECANISME #4 — Tribus (Tribes) : identité de build via tags

### 4.1 Teardown précis

HS:BG a 10 tribus actives (Season 13) : Beasts, Demons, Dragons, Elementals, Mechs, Murlocs, Nagas, Pirates, Quilboars, Undead. **3 tribus sont exclues aléatoirement de chaque lobby** → les 5 restantes + neutres sont jouables.

Distribution par tier (tiré de [bgknowhow.com table](http://sat.bgknowhow.com/bgstrategy/general.php)) — extrait clé :

| Tier | Total serviteurs | Ex. tribus avec le plus de représentants |
|------|-----------------|------------------------------------------|
| T1 | 20 | 2 par tribu (Murloc = 3, Demon = 3 avec neutre) |
| T2 | 33 | 3-4 par tribu |
| T3 | 45 | 4-6 par tribu (Elementals 6, Quilboars 6) |
| T4 | 43 | 3-5 par tribu (Mechs 5, Murlocs 5) |
| T5 | 46 | 4-5 par tribu |
| T6 | 32 | 2-4 par tribu |

**Synergies de tribu** : les synergies sont portées par des serviteurs *au sein* de la tribu qui buffe les autres membres. Ex. : Murloc Warleader (+2/+1 a tous les Murlocs) ; Junkbot (Mechs morts → +2/+2). Pas de « bonus a N membres » global comme TFT — les interactions sont textuelles sur les cartes.

**Menagerie** : une stratégie (pas une tribu) qui consiste a avoir ≥3 tribus distinctes — activant des payoffs comme Lightfang Enforcer (+2/+2 par tribu différente).

Source : [acegameguides.com tribes basics](https://acegameguides.com/what-you-need-to-know-about-battlegrounds-tribes-basics/) ; [hearthstone.wiki.gg](https://hearthstone.wiki.gg/wiki/Battlegrounds)

### 4.2 Psychologie

Les tribus créent une **identité de build immédiate** : le joueur sait dès le T1 qu'il « joue Murloc » ou « joue Mech ». Cette identité précoce génère :

1. **Anticipation goal-directed** : avoir 2 Murlocs crée une attente de trouver le 3e pour un triple, puis les Murlocs-synergy cards. C'est une forme de **near-miss positif sous agence** — le joueur *croit* qu'il peut y arriver (vs near-miss d'une slot machine, sans agence).

2. **Distinctivité mémorielle** : « cette run, j'ai joué Pirates avec triple Hoggar » reste mémorable. La variété des 10 tribus × sélection de lobby × 5-10 corps disponibles par tribu = **espace combinatoire vaste mais naviguable** (pas senti comme chaotique).

3. La rotation des tribus par saison (de nouvelles tribus entrent, d'anciennes sortent) régénère la **curiosité de découverte** a chaque reset, un mécanisme documenté comme rétention de long terme.

Interview Corning (Blizzard) : « les joueurs développent un attachement a des stratégies ou héros particuliers. On doit faire attention a trop les bousculer » (source : [game.info.intel.com interview making of BG](https://game.info.intel.com/gaming-access/the-making-of-hearthstone-battlegrounds-we-wanted-a-mode-that-didnt-feel-as-polarizing)).

### 4.3 Verdict de transférabilité a The Pit

**Partiellement transférable — mais mécanisme sous-jacent différent.**

The Pit utilise des **familles d'affliction** (burn/bleed/poison/rot/choc) comme axe d'identité de build, plus des **adjacences positionnelles**. C'est structurellement différent des tribus HS:BG :

- HS:BG tribes : tag sur le serviteur, serviteurs buffe les autres membres
- The Pit families : DoT *posés sur les ennemis*, pas de buff des alliés par famille
- The Pit adjacence : position sur le plateau-graphe, bonus au voisin (buff allié)

**La transférabilité porte sur la psychologie, pas le mécanisme** : The Pit a besoin d'un système qui donne une **identité de build précoce et lisible**. Les familles DoT partiellement le font (« je joue poison »). Mais les **synergies par TYPE d'unité** (encore un TODO dans CLAUDE.md §7) restent l'espace ouvert le plus direct analogue aux tribus HS:BG.

**Verdict** : les synergies par TYPE en The Pit sont la traduction correcte des tribus HS:BG. L'analogie « implementer des tribus comme HS:BG » est paresseuse (HS:BG a 10 tribus, ~230 cartes, une équipe de dev de 15+). La bonne question est : *quels tags/types créent une identité de build précoce avec le moins de serviteurs ?* Réponse suggérée par HS:BG : 4-5 tags suffisent pour un MVP (les 4 familles DoT sont les candidats naturels), associés a 2-3 serviteurs T1 qui annoncent le tag d'entrée.

---

## 5. MECANISME #5 — Combat : résolution + damage formula

### 5.1 Teardown précis

**Résolution du combat** (source : [hearthstone.wiki.gg combat phase](https://hearthstone.wiki.gg/wiki/Battlegrounds)) :

1. Le joueur avec plus de serviteurs attaque en premier. Si égal → **flip aléatoire**.
2. Attaques en sequence **gauche → droite**, alternant entre les deux camps.
3. Cible : **aléatoire parmi les ennemis** (sauf Taunt → attaque obligatoire les Taunt d'abord, cible aléatoire entre Taunts multiples).
4. Les effets (Deathrattle, Windfury, Divine Shield...) se résolvent selon l'ordre de trigger.

**Calcul des dégâts** (source : [icy-veins mécaniques](https://www.icy-veins.com/hearthstone/hearthstone-battlegrounds-mechanics-guide) ; [sportskeeda guide](https://www.sportskeeda.com/esports/hearthstone-battlegrounds-the-ultimate-guide-to-gameplay-heroes-and-more)) :

```
dégâts = tier_taverne_du_vainqueur + Σ(tier_de_chaque_survivant)
```

Exemple : vainqueur a T4 avec 3 survivants (T1, T2, T4) → 4 + 1 + 2 + 4 = **11 dégâts**
Maximum théorique (~50 dégâts, 7 survivants T6 + T6 taverne) = swing lethal sur 30 PV.

**30 PV de départ**, aucune regeneration naturelle. Un joueur éliminé quitte immédiatement.

### 5.2 Psychologie

La **RNG de ciblage** (cible aléatoire sauf Taunt) est ici la source de tension émotionnelle la plus forte du jeu. Elle produit :

1. **Near-miss sous faible agence** : le joueur a positionné ses Taunt en connaissance de cause, mais la cible des attaques sans Taunt est aléatoire. Résultat : les combats proches peuvent se perdre sur un « mauvais ciblage » — le joueur ressent qu'il était « presque » vainqueur. Les recherches sur les near-misses montrent qu'ils renforcent la persistance même quand l'issue est négative (source : [Frontiers Psychology 2016 ibid.]).

2. **Spectacle dramatique** : l'aléa de ciblage crée des retournements spectaculaires (un petit survivant tue le carry adverse) qui constituent des **moments de haut récit**. Blizzard a explicitement identifié cela comme facteur de rétention : « parfois vous perdez mais vous étiez si près de renverser le combat » (source : [interview making of BG, intel.com ibid.]).

3. **Externalisation de la défaite** : le joueur peut attribuer une perte a la mauvaise cible plutôt qu'a sa stratégie. C'est psychologiquement plus confortable — réduisant le sentiment d'échec — mais aussi une source de plainte chronique sur les forums (« c'est juste du luck ») quand la RNG est excessive.

### 5.3 Verdict de transférabilité a The Pit

**Non transférable — et le non-transfert est une force, pas une lacune.**

The Pit a un **ciblage 100% déterministe** (décision §6 de 00-state.md) : colonne → taunt → aggro → tie-break haut-bas. Zéro dé.

**Pourquoi HS:BG a la RNG de ciblage** : il s'agit d'un compromis conscient fait sur une grid 7 serviteurs linéaire avec des effets de combat instantanés (Deathrattle, Divine Shield). La RNG de ciblage est la **válvula de complexité** qui permettait d'avoir un jeu de hasard sans surcharger les décisions de positionnement. C'est adapté a HS:BG car le positionnement gauche/droite a des effets (qui attaque en premier) mais le *ciblage précis* serait trop coûteux a gérer pour un joueur occasionnel.

The Pit a un modèle supérieur *pour ses contraintes* : le ciblage déterministe signifie que le positionnement sur le plateau-graphe 3×3 EST la stratégie de combat (depth, taunt, aggro). Le **yomi** (« j'aurais dû counter-placer ») remplace le « j'ai été malchanceux ». Cela est :
- **Async-vérifiable** : le snapshot est reproductible, pas de « j'ai été malchanceux »
- **Grimdark-cohérent** : dans un univers de mort déterministe, les entités attaquent ce qui est devant elles, pas au hasard
- **Frustration-réduit** : la source de frustration documentée #1 de HS:BG (ciblage aléatoire) est éliminée

**Danger de l'analogie paresseuse** : « HS:BG a de la RNG de ciblage et les joueurs l'aiment, donc The Pit devrait en avoir ». C'est faux. HS:BG *tolère* la RNG parce que sa session live-multiplayer rend le spectacle dramatique central. The Pit est async — les replays d'un snapshot doivent produire le même résultat. Introduire de la RNG de ciblage exigerait de transmettre le seed dans le snapshot, et la *perception* d'injustice de la cible random serait encore pire sans adversaire humain présent pour en discuter.

---

## 6. MECANISME #6 — Triple / Doré : le moteur de progression build

### 6.1 Teardown précis

**Mécanique** : acheter le 3e exemplaire identique d'un serviteur → **fusion automatique** en version dorée :
- Stats : **double des stats de base** + somme de tous les buffs portés par les 3 copies (jamais sous le min = base stats)
- Effet : version améliorée (ex. Imp Gang Boss golden summon deux imps au lieu d'un)
- Bonus : carte **Triple Reward** en main → Découvrir un serviteur du **tier supérieur** (ou T6 si déja T6)
- Les 3 copies disparaissent du pool partagé (retournent 3 normaux si le doré est vendu)

Source : [bgknowhow.com triple stats page](http://sat.bgknowhow.com/bgbasics/triple_stats.php) ; [hearthstone.fandom.com wiki](https://hearthstone.fandom.com/wiki/Battlegrounds) ; [blizzard.com introducing BG](https://hearthstone.blizzard.com/en-us/news/23156373/introducing-hearthstone-battlegrounds)

**La découverte du Triple Reward est pondérée** : les probabilités de chaque carte découverte sont proportionnelles au nombre de copies disponibles dans le pool (confirmé par développeur DCalkosz) — source : [acegameguides discover mechanic](https://acegameguides.wordpress.com/2021/12/15/what-you-didnt-know-about-the-discover-mechanic-of-battlegrounds/).

### 6.2 Psychologie

Le triple/doré est le mécanisme d'**escalade de power spike** le plus élaboré du jeu. Il produit :

1. **Horizon goal-directed persistant** : avoir 2 copies crée un objectif immédiat (trouver la 3e). Ce « 2 sur 3 » est un des near-misses sous agence les plus efficaces identifiés dans le game design — le joueur *sait* qu'une action précise (acheter ou trouver la 3e copie) mènera a une récompense. C'est radicalement différent d'un near-miss de slot machine (pas d'agence).

2. **Double récompense** : le triple donne *deux* gains simultanés : (a) le serviteur doré amélioré + (b) la découverte d'un serviteur de tier supérieur. Cette **récompense composite** crée un moment de haut point émotionnel qui marque la mémoire de la run.

3. **Profondeur stratégique** : *quand* utiliser la découverte (maintenant = T tier+1 disponible tôt ; plus tard = les cotes sont peut-être meilleures) est une décision non triviale. Cela transforme un reward en problème d'optimisation — maintenant le **smart play** est documenté et partagé dans la communauté.

4. **Meta-narrative** : « cette run j'ai eu un triple Warleader au T3, ça a tout changé » — la run devient une histoire. Les triples sont les *turning points* narratifs de chaque partie. La mémorabilité des runs (near-miss + high moment) est un facteur de rétention documenté pour les jeux de type roguelite (Hades, StS).

### 6.3 Verdict de transférabilité a The Pit

**Transférable structurellement — The Pit a déja le mécanisme, la question est le calibrage du bonus.**

The Pit a les **duplicatas** (décision actée v0.8) : 3 copies → niveau+1 (cap 3), `LEVEL_MULT = {1.0, 1.8, 3.0}`, cascade. C'est la même famille de mécanisme.

**Différence clé** : HS:BG donne une **découverte d'un tier supérieur** avec le triple. The Pit n'a pas d'équivalent — le niveau+1 améliore l'unité mais n'ouvre pas un nouveau contenu. La découverte HS:BG est particulièrement puissante car elle *accélère* la montée en tier tout en récompensant l'investissement dans la tribu.

**Opportunité** : faut-il ajouter une récompense de découverte a la fusion de The Pit ? Évaluation :
- **Pour** : crée le double-reward (moteur émotionnel fort)
- **Contre** : The Pit n'a pas 230 cartes (il en a 83) — la découverte au « tier supérieur » signifierait offrir 1-parmi-3 unités de rang+1 a l'achat. Cela converge avec l'offre de relique (1-parmi-3 tous les 3 combats). Risque de surcharge de choix.
- **Contra-verdict** : la priorité actuelle pour le fun de run *immédiat* est de rendre la fusion de level lisible et visuellement impactante (pips dorés existants, bon), pas d'ajouter un deuxième écran de découverte.

**Garde-fou** : ne pas confondre la *psychologie* (double reward au milestone) et le *mécanisme* (découverte de carte T+1). La psychologie est transférable via d'autres vecteurs : un bandeau animé sur fusion, un son signature, ou une animation grimdark (l'unité se transforme — thème Puits). Le mécanisme de découverte de nouvelle carte serait un scope additionnel non trivial.

---

## 7. MECANISME #7 — Héros : identité asymétrique + reroll

### 7.1 Teardown précis

Au démarrage de chaque partie, le joueur choisit son héros parmi **2 options** (gratuit) ou **4 options** (Season Pass payant — $15-20/saison). Source : [blizzardwatch.com season pass breakdown](https://blizzardwatch.com/2022/09/15/hearthstone-battlegrounds-season-pass-2/).

**Impact gameplay** : chaque héro a un **Hero Power** (actif ou passif) qui définit son style de jeu (ex. : Rafaam achète les serviteurs joués par les adversaires ; Cookie améliore un serviteur par tour). Le Hero Power peut coûter de l'or (actif) ou être gratuit (passif permanent).

**~100+ héros disponibles** dans la rotation. HS:BG filtre les héros disponibles par lobby.

**Impact du pass sur les résultats** (données Old Guardian, source : [hearthstonetopdecks.com pay-to-win analysis](https://www.hearthstonetopdecks.com/how-pay-to-win-is-hearthstone-battlegrounds-now-the-past-and-future-of-bg-monetization/)) :
- Chance d'avoir un héros de top 1/3 (sur 84) avec **2 options** : **62%**
- Chance d'avoir un héros de top 1/3 avec **4 options** : **86%**
- Différence d'espérance de placement a MMR médian : 4.3 (×4) vs 4.4 (×2) — marginal mais systématique sur un grand nombre de parties.

**Season 9** a introduit les **Battlegrounds Tokens** (gagnables via le track de rewards) permettant de reroll un slot héros — 1 token par slot, 1× seulement. Source : [blizzard.com season 9 announcement](https://hearthstone.blizzard.com/en-us/news/24159389/).

### 7.2 Psychologie

1. **Identité de session** : le héro choisi donne une identité immédiate (« cette run, je joue le héros qui améliore les Élémentaux »). Cela positionne le joueur dans un archétype de build avant même d'entrer en boutique. C'est la **motivation de compétence différenciée** (source : ACM research sur les motivations OCCG — Hearthstone players motivés principalement par compétition et immersion, pas socialisation).

2. **FOMO du mauvais héros** : avec seulement 2 options, la probabilité d'un héros « mauvais pour la meta » est ~38%. Cela génère une pression de quitter et relancer la partie. Blizzard l'a reconnu comme design problématique (source : [hearthstonetopdecks season pass criticism](https://www.hearthstonetopdecks.com/how-pay-to-win-is-hearthstone-battlegrounds-now-the-past-and-future-of-bg-monetization/)). C'est un **élément anti-rétention** masqué en fonctionnalité premium.

3. **Hero Power comme moteur économique parallèle** : les Hero Powers actifs (coût 0-2 or) créent un **troisième axe d'allocation d'or** (en plus d'acheter et d'upgrader). C'est une source de profondeur additionnelle sur un vecteur qui n'existe pas dans SAP (pas de Hero Power).

### 7.3 Verdict de transférabilité a The Pit

**Partiellement transférable — les sigils sont l'analogue des Hero Powers, pas des héros.**

The Pit n'a pas de sélection de héros. La **variabilité de run** est fournie par :
- Sélection de sigil (change la topologie du plateau)
- Offres aléatoires de boutique
- Offres de reliques (1-parmi-3 tous les 3 combats)

L'analogue direct du Hero Power HS:BG dans The Pit est le **sigil** (la forme du plateau comme mécanisme de game-defining identity). Mais les sigils sont changés librement en build (touche `[s]`), pas choisis une fois pour la run.

**Analogie paresseuse a éviter** : « HS:BG a des héros avec des pouvoirs différents, The Pit devrait aussi avoir des 'héros' avec des pouvoirs spéciaux ». Evaluation :
- HS:BG a ~100 héros car c'est une exploitation de la propriété intellectuelle existante de Hearthstone (les personnages sont déja dessinés, voicés, connus des joueurs)
- The Pit a un pixel art 100% procédural — les « héros » seraient des entités anonymes
- Ajouter des Hero Powers = ajouter un 4e axe d'allocation d'or (achat / upgrade / hero power). Pour un run de 10 victoires avec un roster de 83 unités, c'est une couche de complexité qui menace la **simplicité de gestion → profondeur émergente** (boussole §0)
- **Verdict** : hors-scope v1. Les reliques lisibles jouent un rôle similaire (chaque relique définit un archétype). Le chemin le plus direct vers l'identité de run asymétrique est la complétion des **reliques G (topologie/sigils)** qui changeraient la forme même du plateau — plus fidèle au pilier grimdark que des « héros » nommés.

---

## 8. MECANISME #8 — Trinkets : récompenses mid-game ciblées (Season 8+)

### 8.1 Teardown précis

Introduits en Season 8 (août 2024). Source : [blizzard.com season 8 announcement](https://hearthstone.blizzard.com/en-gb/news/24119592) ; [developer insights trinkets](https://www.hearthstonetopdecks.com/developer-insights-battlegrounds-trinkets/).

- **Tour 6** : 4 Lesser Trinkets proposés, achat avec or (prix variable selon puissance)
- **Tour 9** : 4 Greater Trinkets proposés, idem
- 56 Lesser + 60 Greater Trinkets distincts (Season 8)
- Les propositions sont **personnalisées** : au moins 1 trinket du type de la tribu principale du joueur ; au moins 1 non-typé ; au moins 1 a coût ≤2
- Pas de doublon dans une offre ; pas de trinket déja possédé dans la 2e offre
- Certains trinkets ont des versions Lesser et Greater (permettant d'empiler ou de diversifier)

**Coût** : variable (proportion de la puissance du trinket). Les trinkets forts coûtent 4-6 or (sur un tour a 10 or), laissant peu de place aux achats de serviteurs ce tour.

### 8.2 Psychologie

Les Trinkets résolvent un problème chronique de HS:BG : **le mid-game était un corridor sans choix build-defining**. Ils ajoutent :

1. **Deux moments de pivot** (T6 et T9) — des points de décision stratégique a alta signification émotionnelle. C'est l'équivalent de la sélection de relique StS (« ce choix va définir le reste de la partie »).

2. **Personnalisation intelligente** (au moins 1 trinket de ta tribu) = le joueur ne se retrouve jamais avec 4 options hors-sujet. Cela maintient la **cohérence de l'identité de build** sans la bloquer.

3. **Trade-off de tempo** : un trinket puissant coûte 4-6 or → le joueur sacrifie ce tour de boutique. C'est une décision visible avec des conséquences immédiates — profondeur sans règle nouvelle.

Les Trinkets ont reçu des critiques pour avoir trop de variance (un player avec un trinket partiellement inadapté peut perdre 6 positions) — signe que l'équilibrage est l'enjeu principal, pas le design du mécanisme (source : [forums BG 2026 « games decided by trinkets »](https://us.forums.blizzard.com/en/hearthstone/t/bgs-are-awful-changes-planned/161018)).

### 8.3 Verdict de transférabilité a The Pit

**Très transférable — c'est l'analogue direct du système de reliques de The Pit.**

The Pit a déja :
- Offres de reliques **1-parmi-3** tous les 3 combats
- Tiers de reliques gatés par l'avancée du run
- Personnalisation via les reliques de type B (amplis d'affliction liés a l'archétype)

**Différence critique** : les Trinkets HS:BG coûtent de l'or (compétition avec l'achat de serviteurs). Les reliques de The Pit sont **gratuites** (pas d'achat a l'or). C'est un choix de design délibéré (relics-design.md §2 : « Pas d'achat a l'or en v1 — les reliques ne concurrencent pas les unités »). Ce choix est **défendable** : The Pit a un or fixe 10/round avec achats/rerolls/upgrades XP qui concurrencent déja — ajouter une relique payante fragmenterait l'attention de l'or.

**Ce que HS:BG enseigne** : le **timing prédéfini** des Trinkets (T6 et T9, toujours) est une excellente leçon. Cela permet au joueur d'anticiper (« dans 2 tours, j'aurai ma relique ») et crée une structure émotionnelle. The Pit offre sa relique tous les **3 combats** (victoires OU défaites d'après relics-design.md §2) — soit approximativement aux rounds 3, 6, 9 d'un run de 10 victoires. C'est proche de T6/T9 en tempo de partie (une run HS:BG dure ~10 rounds). La structure est validée.

**Opportunité** : HS:BG garantit « au moins 1 trinket a coût ≤2 ». The Pit pourrait adopter un principe similaire : garantir que **l'une des 3 reliques proposées est de tier A ou B** (stat plate ou ampli basique) pour que le joueur ne se retrouve jamais avec 3 reliques E/F inutilisables pour son build. Actuellement le tirage est Fisher-Yates seedé sans contrainte sur la composition.

---

## 9. MECANISME #9 — Structure compétitive / MMR (le moteur de « réenchaîner pour grimper »)

### 9.1 Teardown précis

HS:BG utilise un **système dual-rating** (source : [Blizzard dev insights MMR update 2020](https://playhearthstone.com/en-us/blog/23523064/)) :

**Rating externe (visible)** :
- Repart a **0 a chaque saison** (~3-4 mois)
- Floors (planchers) : 2000 / 2500 / 3000 / 3500 / 4000 / 4500 / 5000 / 5500 / 6000 — le rating n'y descend jamais une fois atteint
- Bonus de progression en-dessous de 6500 : un petit gain positif même en cas de perte (s'annule au-dessus de 6500)
- « Rate gain modifier » : si internal > external, le gain de rating après une victoire est multiplié (chasing vers la vraie valeur)

**Rating interne (caché)** :
- N'est **jamais resetté** entre saisons
- Sert uniquement au **matchmaking** (les joueurs affrontent des adversaires de même rating interne)
- Distribution bell-shaped (normale) — re-normalisée périodiquement
- A 4200 (a l'époque du beta) → top 23% ; a 5000 → top 1%

**Placement MMR** :
- Base gain pour 1er place : ~100 MMR
- Maximum possible en début de saison (internal >>> external) : +300
- Perte pour 8e place : environ -30 a -50 (asymétrie favorable)

Source primaire : [Blizzard dev insights rating system update](https://hearthstone.blizzard.com/en-gb/news/23523064) ; [esports.gg MMR battlegrounds](https://esports.gg/news/hearthstone/hearthstone-battlegrounds-rating-system-mmr-and-matchmaking/) ; [hearthstonetopdecks.com dev insights reprint](https://www.hearthstonetopdecks.com/developer-insights-hearthstone-battlegrounds-rating-system-update/)

**Battlegrounds Track (progression cosmétique)** :
- XP gagnée par partie (quelques 10s de XP par partie)
- Track de 40 niveaux (~2000 XP cumulés pour le track complet Season 13) — source : [hearthstone.wiki.gg BG track](https://hearthstone.wiki.gg/wiki/Battlegrounds/Battlegrounds_Track)
- Récompenses : skins héros, emotes, strikes, bartenders (purement cosmétiques)
- La **4e option de héros** au démarrage est derrière le Season Pass ($15-20/saison) — la seule récompense gameplay

### 9.2 Psychologie

Le dual-rating est une réponse a un problème fondamental du MMR dans les jeux 8-joueurs : **le sentiment de stagnation**.

1. **Reset saisonnier = reset visuel de l'espoir** : voir son rating revenir a 0 puis remonter rapidement (grâce au rate gain modifier early) reproduit l'**escalade expérientielle** — chaque début de saison ressemble a un sprint victorieux plutôt qu'a un mur. C'est la psychologie du « nouveau départ » (fresh start effect, documenté en économie comportementale).

2. **Floors comme protection psychologique** : une fois a 3000, on ne peut pas descendre sous 3000. Cela transforme les floors en **acquis identitaires** (« je suis un joueur Diamond/Platinum »). La perte ne détruit pas le progrès, elle l'interrompt. C'est anti-churn puissant.

3. **Matchmaking par internal rating caché** (non resetté) : le joueur joue contre ses pairs réels même au début de saison quand les visibles sont a 0. Le système est équitable mais *ressemble* a un wide-open wild west au début de saison (n'importe qui a 0 rating peut être face a un ancien 8000). La **dissonance apparente** est en réalité un tutoriel naturel du système.

4. **6000 MMR comme mur psychologique** : les forums documentent abondamment que la progression s'arrête a 6000 (plancher final, au-dessus duquel le bonus de progression cesse). C'est la zone de « vrais joueurs compétitifs ». Blizzard l'a reconnu en modifiant les stats d'armure des héros a ce palier (source : [forums HS:BG 6k plateau](https://us.forums.blizzard.com/en/hearthstone/t/think-im-done-w-battlegrounds/157691)).

### 9.3 Verdict de transférabilité a The Pit

**Transférable — et c'est la ZONE LA PLUS VIERGE de The Pit (00-state.md §7 le confirme).**

The Pit n'a actuellement **aucune structure compétitive/ranked**. Tout est a concevoir. Les leçons de HS:BG :

**Adopter (adapté)** :
- **Dual-rating** : rating visible (saisonnier, cumulatif) + rating caché (interne, permanent) pour le matchmaking des snapshots. Concrètement : `snap.tier` (déja présent) + un `playerRating` tag sur les snapshots servent le matchmaking ; l'external rating visible suit la progression de run.
- **Floors** : dans le contexte de The Pit, les floors naturels sont les paliers de run (3 victoires, 5 victoires, 7 victoires). Perdre une run ne devrait pas effacer le progrès vers le palier suivant — une **meta-progression de rating** distinct du score de run garantit cela.
- **Reset saisonnier du rating visible + conservation de l'internal** : The Pit n'a pas encore de saisons. Quand il en aura, ce pattern HS:BG est directement applicable.

**Adapter** :
- HS:BG a 8 joueurs par lobby en temps réel — le rating est mis a jour après chaque partie de 20 min. The Pit a des runs de 10 victoires (potentiellement 1-2h). Le rating devrait être mis a jour **par run complétée** (gain/perte selon le résultat final : ascension / chute / placement intermédiaire).
- **Matchmaking async par snapshot** : The Pit sert des snapshots par `tier≤demandé` (snapstore.lua). Le tier du snapshot peut être enrichi avec une `rank_bucket` (palier de rating) pour matcher des adversaires de niveau similaire. C'est dans les limites v1 identifiées (00-state.md §5 « matchmaking rang »).

**Ne pas adopter** :
- Les **saisons tous les 3-4 mois** avec de nouveaux sets de serviteurs (rotation HS:BG) : The Pit est solo dev, les saisons de contenu ne sont pas en scope pour la roadmap immédiate.
- Le **Season Pass payant pour 4 héros** : The Pit n'a pas de modèle économique B2C défini. Transposer un paywall gameplay sans identité business claire serait prématuré et aliénerait la communauté early (cf. la controverse HS:BG Season 2 sur ce sujet, documentée abondamment).

**Chiffres cibles** (propositions a valider via sim, pas des décisions actées) :
- Rating par ascension : +150 a +300 (selon le nombre de rounds joués et les adversaires battus)
- Rating par chute : -50 a -100 (asymétrie favorable pour éviter la stagnation)
- Floors : tous les 500 points (ex. 500, 1000, 1500, 2000, 2500...)
- Matchmaking snapshot : `rank_bucket` = floor(rating / 500)

---

## 10. MECANISME #10 — Anomalies saisonnières (Season 12+)

### 10.1 Teardown précis

Introduites pour varier la meta entre patches. Source : [playhearthstone.com patch 34.2](https://playhearthstone.com/en-us/blog/24244423/).

- 1 **anomalie par lobby** (tirée aléatoirement parmi ~30 anomalies actives)
- Exemples : « tous les serviteurs ont +1/+1 au départ » ; « les Deathrattles se déclenchent deux fois » ; « les sort spells coûtent 0 »
- **Timewarped Tavern** (Season 12) : 2 fois par partie (tour 6 et 9), un mini-shop spécial avec monnaie Chronum (non-compatible avec l'or), cartes uniques

### 10.2 Psychologie

Les anomalies ont un effet documenté de **meta disruption** bénéfique : elles forcent le pivot, empêchent la solve complète du jeu, renouvellent la « first-time experience » même pour les vétérans.

Toutefois les forums documentent aussi que les **anomalies fortes peuvent décider les parties** indépendamment du skill — source de frustration pour les joueurs compétitifs (source : [forums HS:BG 2026 anomaly critique](https://us.forums.blizzard.com/en/hearthstone/t/think-im-done-w-battlegrounds/157691) ; [forums 2026 bgs trash tier](https://us.forums.blizzard.com/en/hearthstone/t/battlegrounds-is-trash-tier-at-this-point/158989)).

### 10.3 Verdict de transférabilité a The Pit

**Partiellement transférable — via les sigils et les reliques G, pas via des anomalies globales.**

Le problème des anomalies HS:BG en contexte async : si l'anomalie du lobby est aléatoire pour chaque joueur, le snapshot du ghost ne sait pas dans quelle anomalie il va être utilisé. Résultat : le build du ghost (optimisé pour une anomalie) peut être catastrophiquement mauvais contre une autre anomalie. **Incompatible avec le déterminisme des snapshots.**

La **vraie** source de méta-variation dans The Pit est :
1. Les **sigils** (5 topologies distinctes, le joueur choisit) — variation choisie, pas subie
2. Les **reliques G (différées)** — changer la topologie via une relique est le chemin grimdark vers des anomalies thématiques sans briser l'async
3. L'**escalade des adversaires** par round (différents encounters IA) — variation déja codée

Ne pas adopter les anomalies globales aléatoires : trop de RNG non maîtrisé, incompatible avec snapshots déterministes.

---

## 11. PROBLEMES STRUCTURELS DE HS:BG — ce qu'il ne faut PAS copier

> Sources : forums Blizzard (2022-2026), critiques communautaires, analyses joueurs compétitifs

### 11.1 Ciblage aléatoire = frustration endémique

La cible aléatoire en combat (sauf Taunt) est la **plainte #1** des forums depuis le lancement. Elle :
- Crée des défaites « inexplicables » malgré un bon positionnement
- Rend les combats de fin de partie (3 survivants vs 3 survivants) très sensibles a un seul ciblage malheureux
- Génère de l'**attribution externe** (« j'ai perdu a cause du RNG ») qui nuit a la perception de compétence et à long terme au sentiment de progression

**The Pit a résolu ce problème** via le ciblage déterministe. Ne pas revenir en arrière.

### 11.2 Hero selection pay-to-win = aliénation

Mettre la « 4e option de héros » derrière un paywall ($15-20/saison) a généré une **controverse majeure** (Season 2, août 2022) qui a durablement affecté la perception du jeu. Les données montrent un avantage réel (+24% de chance d'avoir un bon héros). Source : [hearthstonetopdecks pay-to-win analysis ibid.].

**The Pit n'a pas de héros** — le problème ne se pose pas. Mais tout contenu gameplay derrière un paywall dans The Pit reproduirait cette dynamique.

### 11.3 Variance croissante = churn des compétitifs

Chaque saison ajoute de nouvelles mécaniques (Trinkets, Anomalies, Timewarped Tavern, Quests...) qui augmentent la variance. Les joueurs compétitifs de haut MMR documentent une frustration croissante : « le jeu est maintenant 90% RNG » (forums 2026). Chaque nouveau layer de hasard dégrade l'intégrité compétitive.

**Leçon pour The Pit** : chaque nouvelle couche de RNG doit être évaluée a l'aune de l'intégrité de la sim déterministe. Le seul vrai RNG dans The Pit est le seed de run (tirages boutique, offres de reliques) — et il est entièrement reproductible. C'est un avantage concurrentiel clair sur HS:BG. **Ne pas diluer.**

### 11.4 Pool partagé + T6 rares = « game decided by lobby » frustration

Avec 7 copies de chaque T6 pour 8 joueurs, une T6-key card peut être épuisée par 2 joueurs qui font triple. Les 6 autres n'y ont jamais accès. Sur les forums (2025-2026) : « game is decided by trinkets and T6 hits, no skill required ». Source : [forums 2026 trash tier ibid.].

**The Pit évite ce problème** : pas de pool partagé entre joueurs (async), les cotes par tier de boutique contrôlent la rareté sans la compétition directe entre joueurs pour les mêmes copies.

---

## 12. SYNTHESE — Tableau des transferabilités

| Mécanisme HS:BG | Transférable ? | Statut The Pit | Action recommandée |
|-----------------|---------------|----------------|-------------------|
| Or frais/round sans banque | Déja adopté | FAIT | Confirmer les valeurs via sim |
| Courbe upgrade avec -1/tour | Non (async sans pression de lobby temps réel) | N/A | Signal de progression alternative (coût dégressif visible si applicable) |
| Pool partagé entre joueurs | Non (async, pas de pool commun) | N/A | Cotes par tier de boutique (équivalent rareté sans compétition directe) |
| Tribus (synergies par tag) | Oui — psychologie, pas copier-coller | TODO dans CLAUDE.md | Synergies par TYPE d'unité = priorité contenu haute |
| Combat order-fixe | Déja adopté (cooldowns, meilleur) | FAIT | Ne pas réintroduire de RNG de ciblage |
| Ciblage aléatoire | NON — source frustration endémique | RÉSOLU (déterministe) | Ne jamais revenir au ciblage random |
| Triple/doré + découverte | Partiel — fusion existe ; découverte pas | PARTIEL | Evaluer une récompense de pivot a la fusion T3 (sans écran de découverte lourd) |
| Héros asymétriques | Non (pas de héros dans The Pit) | N/A | Les sigils + reliques G remplissent ce rôle |
| Trinkets mid-game | Oui — analogue des reliques | FAIT (reliques 1-parmi-3) | Garantir au moins 1 relique A/B dans les 3 proposées |
| Dual-rating MMR | Oui — zone la plus vierge | TODO | Priorité roadmap ranked : dual-rating + floors + snapshot rank_bucket |
| Floors de rating anti-churn | Oui | TODO | Couplé au dual-rating |
| Anomalies globales aléatoires | NON — incompatible snapshots | N/A | Les sigils + reliques G = variation choisie, pas subie |
| Saisons avec reset | Oui (différé, pas en scope v1) | TODO long terme | Quand backend distant + base joueurs |
| Season Pass gameplay | NON — aliénation documentée | N/A | Modèle économique séparé a designer |
| Hero Power comme axe économique | Partiel (différé) | N/A | Les reliques de boutique (runOp) jouent ce rôle |

---

## 13. RECOMMANDATIONS PRIORITAIRES ISSUES DE L'ANALYSE

> Classées par impact/effort pour The Pit, au regard des piliers (async, déterministe, grimdark, procédural).

### Priorité 1 (impact élevé, effort faible — améliore l'existant)
1. **Garantir une composition minimale dans l'offre de reliques** : au moins 1 relique de tier A ou B dans les 3 proposées (analogue a la garantie Trinket HS:BG). Change le générateur Fisher-Yates existant, pas la mécanique.
2. **Signe visuel de progression de boutique** : rendre lisible le coût decroissant de l'upgrade de tier (analogue au -1/tour HS:BG). Même si le mécanisme est différent (XP passive + XP achetée vs coût d'or decroissant), le *signal* est ce qui compte pour la lisibilité.

### Priorité 2 (impact élevé, effort moyen — nouveau contenu)
3. **Synergies par TYPE d'unité** : c'est le TODO majeur identifié dans CLAUDE.md §7. L'analyse HS:BG confirme que les tags/tribus sont le mécanisme le plus efficace pour créer une identité de build précoce. Avec 83 unités réparties sur 5 familles DoT (burn ~13, bleed ~13, poison ~15, rot ~11, choc ~11), les types naturels sont : burn, bleed, poison, rot, choc — exactement les 5 familles DoT. Une synergie de type = « avoir 3+ unités du même type donne +X% dégâts du type ». Applicable sans modifier le moteur SIM (aura build-résolue via `grant_team`, pattern existant).
4. **Récompense visuelle amplifiée a la fusion de level** : le bandeau doré existant est bien, mais une animation grimdark (l'unité « descend plus profond dans le Puits ») pour la fusion T3 → T4 → T5 renforcerait le double-reward psychologique sans ajouter d'écran de découverte.

### Priorité 3 (impact stratégique, effort élevé — infrastructure ranked)
5. **Dual-rating system + floors** : déploiement sur le backend snapshot existant. `playerRating` tag sur les snapshots, `rank_bucket` pour le matchmaking, external rating visible (reset saisonnier) + internal rating caché (permanent). C'est le **moteur de « réenchaîner pour grimper »** manquant.
6. **run_rank_bucket dans snapshots** : modifier snapshot.lua pour inclure un bucket de rating du snapshot → matchmaking par palier dans snapstore.lua `serve()`.

### Ce qui doit rester hors-scope
- Ciblage aléatoire en combat : jamais. The Pit a résolu le problème.
- Anomalies globales aléatoires : incompatible async/déterministe.
- Héros avec Hero Powers : pas de héros nommés dans la DA grimdark procédurale.
- Pool partagé entre joueurs en temps réel : hors-architecture async.

---

## 14. SOURCES CONSOLIDEES

| Affirmation | URL source |
|-------------|------------|
| Or par tour, coûts boutique | https://www.icy-veins.com/hearthstone/hearthstone-battlegrounds-mechanics-guide |
| Coûts upgrade taverne + copies par tier | http://sat.bgknowhow.com/bgstrategy/general.php |
| Pool partagé, copies par tier (dev confirm) | https://www.followchain.org/battlegrounds-shared-pool-size/ + https://hearthstone.wiki.gg/wiki/Battlegrounds/Tavern_Tier |
| Tables pool size numériques (V17.2, données historiques) | https://github.com/chixu/battlegrounds-picker |
| Combat order, damage formula | https://hearthstone.wiki.gg/wiki/Battlegrounds ; https://www.icy-veins.com/hearthstone/hearthstone-battlegrounds-mechanics-guide |
| Triple / golden mechanics | https://hearthstone.wiki.gg/wiki/Battlegrounds ; http://sat.bgknowhow.com/bgbasics/triple_stats.php |
| Triple Reward discover weighted by pool | https://acegameguides.wordpress.com/2021/12/15/what-you-didnt-know-about-the-discover-mechanic-of-battlegrounds/ |
| Tribes list + distribution par tier | http://sat.bgknowhow.com/bgstrategy/general.php ; https://acegameguides.com/what-you-need-to-know-about-battlegrounds-tribes-basics/ |
| Dual-rating system (Blizzard dev insight officiel) | https://playhearthstone.com/en-us/blog/23523064/ ; https://news.blizzard.com/en-gb/article/23523064/ |
| MMR floors, matchmaking explication | https://esports.gg/news/hearthstone/hearthstone-battlegrounds-rating-system-mmr-and-matchmaking/ |
| Personal rating système original | https://news.blizzard.com/en-gb/article/23239989/ |
| Season Pass / 4 hero options | https://hearthstone.blizzard.com/en-us/news/23831408 ; https://blizzardwatch.com/2022/09/15/hearthstone-battlegrounds-season-pass-2/ |
| Pay-to-win analysis, hypergeometric calc | https://www.hearthstonetopdecks.com/how-pay-to-win-is-hearthstone-battlegrounds-now-the-past-and-future-of-bg-monetization/ |
| Battlegrounds Track rewards XP | https://hearthstone.wiki.gg/wiki/Battlegrounds/Battlegrounds_Track |
| Trinkets Season 8 announcement | https://hearthstone.blizzard.com/en-gb/news/24119592 |
| Trinkets developer insights (détails techniques) | https://www.hearthstonetopdecks.com/developer-insights-battlegrounds-trinkets/ ; https://hearthstone.wiki.gg/wiki/Battlegrounds/Trinket |
| Season 9 hero rerolls tokens | https://hearthstone.blizzard.com/en-us/news/24159389/ |
| Season 12 Timewarped Tavern | https://playhearthstone.com/en-us/blog/24244423/ |
| Standard leveling curves | https://www.hearthstonetopdecks.com/battlegrounds-curves-explained/ ; https://esports.gg/news/hearthstone/hearthstone-battlegrounds-leveling-guide/ ; https://hearthstone-decks.net/hearthstone-battlegrounds-guide-by-11-5k-mmr-player/ |
| Psychologie : « didn't feel as polarizing » | https://www.gamedeveloper.com/design/why-the-i-hearthstone-i-devs-wanted-to-make-an-auto-battler ; https://game.info.intel.com/gaming-access/the-making-of-hearthstone-battlegrounds-we-wanted-a-mode-that-didnt-feel-as-polarizing |
| Psychologie : sentiment de compétence et rétention | https://celiahodent.com/gamers-brain-part-3-ux-engagement-immersion-retention-gdc17-talk/ |
| Psychologie : partial reinforcement schedule | https://www.frontiersin.org/journals/psychology/articles/10.3389/fpsyg.2016.00046/full |
| Motivations joueurs OCCG (ACM study) | https://dl.acm.org/doi/10.1145/3292147.3292216 |
| Frustration RNG et forums | https://us.forums.blizzard.com/en/hearthstone/t/battlegrounds-arent-skill-based-it-is-pure-luck/98470 ; https://us.forums.blizzard.com/en/hearthstone/t/battlegrounds-is-trash-tier-at-this-point/158989 ; https://us.forums.blizzard.com/en/hearthstone/t/bgs-are-awful-changes-planned/161018 |
| 6k MMR plateau et design armor | https://us.forums.blizzard.com/en/hearthstone/t/think-im-done-w-battlegrounds/157691 |

---

*Rédigé le 2026-06-23. Lecture seule du repo. Ecriture uniquement sous docs/roadmap-lab/.*
*Toute modification du code ou des tests exige un mandat explicite de l'user.*
