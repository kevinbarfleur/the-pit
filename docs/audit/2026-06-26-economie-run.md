# Audit economie de run - 2026-06-26

## Verdict court

Ton intuition est juste : l'economie actuelle donne bien l'impression qu'on peut
presque tout acheter, surtout en debut et milieu de run.

Le probleme n'est pas seulement que `GOLD_PER_ROUND = 10` serait trop haut. Le
probleme plus precis est que le jeu a emprunte le revenu fixe de Super Auto Pets
sans emprunter son poids d'achat. Dans SAP, 10 gold achetent au maximum 3 pets a
3 gold, donc chaque achat est lourd. Dans The Pit, `cost = rank` fait qu'un shop
entier de tier 1 coute 5 gold sur 10. Le budget ne devient vraiment tendu qu'a
partir du tier 4.

La consequence est structurelle :

- early : l'or ne force pas assez de choix, on achete large ;
- mid : le joueur peut encore acheter presque tout le shop moyen ;
- late : la tension arrive, mais tard, quand la run est deja orientee ;
- sans banque, l'or non depense disparait, donc le systeme pousse a tout
  consommer maintenant, meme quand le shop n'est pas un vrai dilemme.

Ce n'est donc pas une economie "trop genereuse" au sens global. C'est une
economie dont la pression arrive au mauvais moment.

## Sources et statut documentaire

Cette note est maintenant la source active pour le diagnostic economie de run.
Elle synthetise des recherches internes plus anciennes sur SAP, Batomon, TFT,
roadmap-lab et progression economie. Ces dossiers historiques ont ete retires du
dossier actif pour eviter qu'un agent recharge des decisions depassees.

Documents actifs a croiser avec cette note :

- `CLAUDE.md`
- `docs/research/intensive-simulation-balance-program-HANDOFF.md`
- `docs/research/balance-sim-design.md`
- `docs/audit/monster-level-scaling-design.md`

Code relu :

- `src/run/state.lua`
- `src/data/units.lua`
- `src/data/relics.lua`
- `tests/run.lua`

## Etat actuel du code

Constantes principales dans `src/run/state.lua` :

- gold frais par round : `10`
- reroll : `1`
- taille de shop : `5`
- cout des unites : `cost = rank`, donc rang 1 a 1 gold, rang 5 a 5 gold
- streak bonus : cap a `3`
- slots : grants temporises rounds 2-7, acceptation gratuite, refus pour `+3`
- commandant : offre round 3, refus pour `+4`
- relique refusee : `+3`
- XP passive : `+1` par round a partir du round 2
- achat XP : `4 gold -> 4 XP`
- seuils actuels : `{2, 5, 8, 12}`, soit cumul T2=2, T3=7, T4=15, T5=27

Cotes de boutique actuelles :

| Tier shop | R1 | R2 | R3 | R4 | R5 |
|---|---:|---:|---:|---:|---:|
| 1 | 100 | 0 | 0 | 0 | 0 |
| 2 | 70 | 30 | 0 | 0 | 0 |
| 3 | 44 | 34 | 20 | 2 | 0 |
| 4 | 25 | 30 | 30 | 13 | 2 |
| 5 | 15 | 20 | 30 | 25 | 10 |

Distribution actuelle du roster achetable :

| Rang | Nombre d'unites | Cout moyen |
|---|---:|---:|
| 1 | 12 | 1.00 |
| 2 | 32 | 2.00 |
| 3 | 31 | 3.00 |
| 4 | 25 | 4.00 |
| 5 | 10 | 5.00 |

## Chiffre cle : cout moyen d'un shop complet

Avec `SHOP_SIZE = 5` et `cost = rank`, acheter tout le shop coute en moyenne :

| Tier shop | Cout moyen par offre | Cout moyen du shop entier | Part du budget 10g |
|---|---:|---:|---:|
| 1 | 1.00 | 5.00 | 50 % |
| 2 | 1.30 | 6.50 | 65 % |
| 3 | 1.80 | 9.00 | 90 % |
| 4 | 2.37 | 11.85 | 118 % |
| 5 | 2.95 | 14.75 | 148 % |

Conclusion : jusqu'au tier 3, le joueur peut souvent acheter tout ce qui est
propose, ou presque. Le premier moment ou le shop moyen depasse vraiment le
budget arrive au tier 4.

Or, avec la passive XP actuelle, un joueur sans achat XP atteint :

| Round | Tier shop passif |
|---|---:|
| 1-2 | 1 |
| 3-7 | 2 |
| 8-15 | 3 |
| 16-27 | 4 |
| 28+ | 5 |

Dans une run courte vers 10 victoires / 5 vies, beaucoup de la partie se joue
donc en tier 1-3, c'est-a-dire dans la zone ou l'achat n'est pas encore le vrai
goulot d'etranglement.

## Comparaison SAP

SAP fonctionne avec un modele tres lisible :

- 10 gold par tour ;
- pas de banque ;
- reroll 1 gold ;
- pets a 3 gold ;
- tiers deverrouilles par cadence automatique.

Le point important n'est pas "SAP donne 10 gold". Le point important est :

> dans SAP, acheter 3 pets coute 9 gold sur 10.

Donc le joueur ne peut pas tout faire. Il doit choisir entre :

- acheter 3 pets ;
- acheter 2 pets + reroll 2 fois ;
- acheter 1 pet + food + rerolls ;
- freeze pour reporter un choix.

The Pit reprend les 10 gold et le reroll a 1, mais pas le cout fixe lourd des
achats. Avec des rangs 1 a 1 gold, le debut de partie n'a pas la meme pression.
Le systeme ressemble a SAP dans ses constantes, mais pas dans son ratio
psychologique.

Ratio d'effort :

| Jeu / etat | Achat de base | Reroll | Ratio achat/reroll |
|---|---:|---:|---:|
| SAP | 3 | 1 | 3:1 |
| The Pit tier 1 | 1 | 1 | 1:1 |
| The Pit tier 2 moyen | 1.3 | 1 | 1.3:1 |
| The Pit tier 3 moyen | 1.8 | 1 | 1.8:1 |
| The Pit tier 5 moyen | 2.95 | 1 | 2.95:1 |

The Pit ne retrouve le ratio SAP qu'en late. En early, un reroll coute autant
qu'une unite rang 1, mais acheter toutes les unites reste si peu cher que le
joueur a souvent du budget en trop.

## Comparaison TFT

TFT a une economie plus riche :

- banque ;
- interets ;
- streaks ;
- reroll a 2 ;
- unites 1-5 ;
- achat XP 4g -> 4 XP ;
- timing de levels et de rolldowns.

Mais TFT marche parce que l'or garde une valeur future. Ne pas depenser est une
decision, car cela produit de l'interet ou preserve un timing de rolldown. The
Pit, par defaut, n'a pas de banque. L'or non depense est perdu.

Donc The Pit ne peut pas copier directement le "level vs roll vs buy" de TFT
sans porter aussi le poids mental de la banque. Les documents internes ont
raison de rester prudents sur les interets : c'est puissant, mais cela ajoute
une couche de gestion qui n'est pas forcement bonne pour un async court.

Le bon transfert depuis TFT n'est pas "ajouter les interets". C'est plutot :

- rendre le timing d'XP lisible ;
- faire que "acheter XP maintenant" ait un cout d'opportunite visible ;
- mesurer des fenetres de roll par tier ;
- donner une raison de ne pas acheter tout ce qui passe.

## Comparaison Batomon

Les docs Batomon pointent un autre probleme : Batomon force le build par des
axes transversaux, pas seulement par la rarete.

Il y a plus de friction de planification :

- types ;
- items ;
- transformations ;
- effets cross-phase ;
- multiplicateurs meta ;
- identites de build plus tranchees.

The Pit a deja un moteur de combat plus riche que son economie. Mais dans la
phase de build, si les types/items/synergies ne sont pas encore assez actifs,
acheter large est rationnel. Le joueur ne renonce pas vraiment a une direction.

Donc le ressenti "je peux tout acheter" vient aussi d'un manque de cout
d'engagement. Meme si on rend l'or plus rare, si les achats ne creent pas assez
vite une identite de build, l'economie restera floue.

## Diagnostic par phase de partie

### Early : rounds 1-3

Le probleme est le plus visible ici.

Round 1, tier 1 :

- shop de 5 offres ;
- toutes les offres coutent 1 ;
- budget 10 ;
- acheter tout le shop coute 5 ;
- il reste 5 pour reroll / acheter encore / XP.

La vraie contrainte n'est pas l'or, mais les slots, le bench et la lisibilite.
Si l'UI donne l'impression que l'or est la ressource principale, il y a un
decalage : le systeme dit "tu as 10 gold", mais le bon play peut etre "prends
presque tout, trie plus tard".

Le refus de slot a `+3` aggrave ponctuellement ce ressenti : `+3` en early vaut
trois unites rang 1. Refuser un slot peut donner un tour tres gonfle en achats,
alors que la decision strategique devrait etre "tall vs wide".

### Mid : tiers 2-3

La tension augmente, mais reste tardive.

Tier 2 :

- shop moyen : 6.5 gold ;
- le joueur peut encore tout acheter en moyenne ;
- avec un bonus de streak ou un refus, il a beaucoup de marge.

Tier 3 :

- shop moyen : 9 gold ;
- c'est le premier tier ou acheter tout le shop commence a consommer le budget ;
- mais il reste souvent possible de tout prendre si la distribution est basse.

C'est aussi ici que l'XP devrait devenir interessante. Mais `BUY_XP_COST = 4`
vaut quatre unites rang 1, deux unites rang 2, ou plus de quatre rerolls si le
joueur a des bonus. Pour un joueur qui ne comprend pas encore la valeur du tier
suivant, acheter XP peut sembler abstrait, alors qu'acheter des corps concrets
est immediat.

### Late : tiers 4-5

La pression economique devient enfin reelle.

Tier 4 :

- shop moyen : 11.85 gold ;
- acheter tout devient impossible sans bonus ;
- acheter XP, reroll et prendre des rangs 4/5 devient un vrai arbitrage.

Tier 5 :

- shop moyen : 14.75 gold ;
- la boutique depasse nettement le budget ;
- le reroll a 1 devient tres avantageux par rapport au cout moyen d'une offre.

Mais cette tension arrive possiblement trop tard. La run a deja une histoire,
des pertes, des doublons, des slots acceptes ou refuses. Si le debut a appris au
joueur qu'il pouvait presque tout prendre, le late ressemble a une correction
brusque plutot qu'a une economie coherente.

## Probleme secondaire : reroll statique

Les rounds r07-r10 des docs roadmap insistent sur un point important :

`REROLL_COST = 1` n'a pas la meme signification selon le tier.

Avec `cost = rank` :

- tier 1 : un reroll vaut une unite ;
- tier 3 : un reroll vaut environ une demi-offre moyenne ;
- tier 5 : un reroll vaut environ un tiers d'offre moyenne.

Donc le reroll devient de plus en plus bon marche au fil de la partie. C'est
peut-etre une intention correcte si on veut que le late soit plus exploratoire.
Mais si ce n'est pas intentionnel, il faut le corriger.

Option deja notee par les docs :

```lua
rerollCost = math.max(1, shopTier - 1)
```

Ce qui donne :

- tier 1-2 : 1
- tier 3-4 : 2
- tier 5 : 3

Cela corrige surtout le late. Cela ne regle pas le probleme early "je peux tout
acheter".

## Probleme secondaire : decline rewards

Les refus donnent beaucoup de pouvoir d'achat immediat :

- refuser un slot : `+3`
- refuser une relique : `+3`
- refuser le commandant : `+4`

En early, `+3` vaut enorme :

- 3 unites rang 1 ;
- 3 rerolls ;
- 75 % d'un achat XP ;
- 1 unite rang 2 + 1 reroll.

Ces valeurs sont coherentes si l'or est tendu. Mais dans une economie ou le shop
early est deja tres abordable, elles amplifient le sentiment de surplus.

Le refus de slot devrait etre un choix "je sacrifie de la largeur permanente
pour un spike temporaire". Aujourd'hui, le spike peut etre si confortable qu'il
masque le sacrifice.

## Pourquoi ne pas juste baisser l'or a 7 ?

Baisser `GOLD_PER_ROUND` globalement reglerait une partie du symptome, mais ce
n'est pas le levier le plus propre.

Exemple :

- a 7 gold, le shop tier 1 coute 5/7, donc il y a plus de pression ;
- mais tier 4 et 5 deviennent beaucoup plus durs ;
- `BUY_XP_COST = 4` devient enorme ;
- les archetypes qui ont besoin de pieces specifiques risquent de mourir avant
  de se former.

Les diagnostics de balance existants signalent deja que certaines politiques
archetypees ne completent pas leur plan au niveau RUN, meme quand le combat pur
n'est pas le probleme. Cela veut dire qu'il ne faut pas confondre "je peux tout
acheter en early" avec "toute la run est trop riche".

Le risque d'une baisse globale est de rendre le debut plus tendu, mais de casser
encore plus les builds qui ont besoin de direction.

## Le vrai probleme de design

L'economie actuelle veut creer trois choix :

1. acheter des unites ;
2. reroll ;
3. acheter de l'XP.

Mais en debut de run :

- acheter les unites est trop peu cher ;
- reroll est un bon moyen de depenser le surplus ;
- XP est abstrait et cher en valeur relative ;
- les slots sont gratuits par timing ;
- l'or non depense disparait.

Donc le joueur n'est pas pousse a choisir une direction. Il est pousse a prendre
beaucoup d'options, puis a trier. C'est moins une economie de decision qu'une
economie de collecte.

## Recommandation principale

Il faut choisir explicitement quelle economie The Pit veut etre.

### Option A - SAP-like stricte : achat lourd, pas de banque

Objectif : chaque achat early doit faire mal.

Le moyen le plus direct est de casser `cost = rank` et de mettre un plancher plus
haut :

```lua
costByRank = { 2, 3, 4, 5, 6 }
```

Effet :

- tier 1 : shop complet = 10 gold exactement ;
- le budget SAP-like revient ;
- acheter une unite redevient une vraie decision ;
- reroll a 1 retrouve un role clair.

Inconvenients :

- on perd la simplicite "le prix est le rang" ;
- toute la balance des doublons et du sell doit etre retestee ;
- les rangs hauts deviennent tres chers, donc il faut verifier le late.

C'est le changement le plus propre pour corriger le ressenti immediat.

### Option B - Courbe de revenu : garder `cost = rank`, reduire l'early

Objectif : garder la lecture simple, mais donner moins d'or tant que les shops
sont bas.

Exemple a tester :

```lua
goldByRound = {
  [1] = 6,
  [2] = 6,
  [3] = 8,
  [4] = 8,
  [5] = 8,
}
-- puis 10 a partir du round 6
```

Effet :

- le tier 1 n'est plus trivial ;
- le tier 2 reste lisible ;
- le late conserve assez d'or ;
- `cost = rank` reste intact.

Inconvenients :

- on abandonne la purete "10 gold frais par round" ;
- la progression economique devient une regle de plus a expliquer ;
- les refus `+3` deviennent encore plus explosifs en round 1-2 s'ils ne sont
  pas ajustes.

C'est le meilleur compromis si on veut proteger `cost = rank`.

### Option C - Garder le revenu, mais creer de meilleurs puits

Objectif : ne pas toucher au budget, mais rendre les autres depenses plus
attirantes.

Leviers possibles :

- reroll qui scale avec le tier ;
- XP achetable en plus petites portions ;
- achat XP mieux signale par l'UI ;
- reliques/shop-tier qui creent des timings clairs ;
- freeze limitee ou relic-only, pas baseline.

Effet :

- moins invasif ;
- preserve les tests et les constantes principales ;
- ameliore surtout mid/late.

Inconvenient :

- ne corrige pas assez le round 1 : acheter tout le shop coutera toujours 5/10.

C'est une bonne passe complementaire, pas la correction centrale.

### Option D - Batomon-like : pression par engagement de build

Objectif : on accepte que le joueur puisse acheter large, mais chaque achat le
rapproche d'une identite et rend les autres directions moins pertinentes.

Leviers :

- types 2/4 ;
- reliques archétypes plus garanties ;
- items ou transformations ;
- feedback "tu es en train de devenir X" ;
- seuils de famille visibles.

Effet :

- plus profond ;
- meilleur pour la rejouabilite ;
- moins punitif qu'une economie tres rare.

Inconvenient :

- plus long a construire ;
- ne resout pas seul le sentiment de surplus d'or si les prix restent trop bas.

C'est indispensable pour la qualite long terme, mais pas suffisant pour le
probleme economique immediat.

## Ma position

Je ne garderais pas l'economie actuelle telle quelle.

Le couple `10 gold frais + shop 5 + cost=rank + no bank` est trop permissif en
early. Il produit un mauvais apprentissage : le joueur comprend que l'or sert a
vider la boutique, pas a choisir.

Je testerais deux variantes en priorite, dans cet ordre :

1. **Variante prix SAP-like** : `costByRank = {2, 3, 4, 5, 6}` avec 10 gold fixe.
2. **Variante revenu courbe** : `6/6/8/8/8/10...` avec `cost = rank`.

La premiere est plus franche et probablement meilleure pour le feeling. La
deuxieme respecte mieux les decisions de design deja documentees.

Je ne commencerais pas par ajouter banque/interets. Cela transformerait The Pit
vers TFT alors que les docs veulent une partie async courte, lisible, a petits
nombres. L'interet peut etre une relique ou un mode avance, pas la base.

Je ne commencerais pas non plus par seulement augmenter le reroll. Le reroll
scalant est sain pour le late, mais il ne change pas le fait qu'un shop tier 1
coute 5 gold.

## Tests de simulation a ajouter avant decision finale

Pour trancher proprement, il faut mesurer la pression economique au lieu de
debattre au ressenti.

Metrics recommandees :

- `full_shop_cost_ratio` : cout du shop entier / gold disponible par round.
- `buy_all_rate` : % de rounds ou une politique peut acheter toutes les offres
  desirees.
- `gold_leftover_wasted` : or perdu faute de banque.
- `gold_pressure` : depenses utiles / gold disponible.
- `spend_split` : part unites / rerolls / XP / declines.
- `reroll_rate_by_tier` : nombre de rerolls par tier shop.
- `xp_buy_rate_by_tier` : quand l'XP est achetee.
- `bench_overflow_rate` : cas ou l'or existe mais l'espace manque.
- `slot_decline_ev` : valeur reelle de refuser un slot selon round.
- `archetype_commit_round` : round ou le build devient identifiable.
- `committed_archetype_completion` : taux ou poison/tank/rot/etc. arrivent a
  constituer leur plan avant mort/victoire.

Policies minimales :

- random baseline ;
- buy-all ;
- greedy stats ;
- force level fast ;
- committed archetype ;
- econ streak ;
- tall slot-decline ;
- wide slot-accept.

Critere de validation simple :

- early : le joueur ne doit pas pouvoir acheter tout le shop utile et avoir
  encore un plan XP/reroll confortable ;
- mid : il doit choisir entre consolider, roll, ou accelerer le tier ;
- late : le reroll ne doit pas etre un spam automatique sauf intention explicite ;
- les archetypes commit doivent completer plus souvent, pas moins.

## Decision a prendre

La question structurante est :

> Veut-on garder `cost = rank` comme axiome fort, ou veut-on que l'achat early
> pese comme dans SAP ?

Si `cost = rank` est sacre, il faut courber le revenu ou ajouter une autre forme
de pression early.

Si le feeling economique est prioritaire, il faut probablement relever le
plancher de cout des unites et accepter que le rang ne soit plus exactement le
prix.

Dans les deux cas, l'etat actuel doit etre considere comme un placeholder de
tuning, pas comme une economie finale.
