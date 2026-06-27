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

Etat implementation 2026-06-26:

- `src/run/economy.lua` expose des profils opt-in pour simulation:
  - `baseline`;
  - `sap_cost` avec `costByRank = {2, 3, 4, 5, 6}`;
  - `early_curve` avec revenu `6/6/8/8/8/10...`;
  - `tiered_reroll` avec reroll `1/1/2/2/3`;
  - `sap_cost_tiered_reroll`.
- `RunState.new(seed, { economy = profileId })` applique ces variantes sans
  changer le comportement live par defaut.
- `tools/sim.lua economy [N]` ecrit `runs/report-economy.json` et compare les
  profils sur les politiques reelles du `Rundriver`. Les seeds sont maintenant
  apparies par run/profil pour que les policies comparees demarrent du meme
  monde et divergent seulement par leurs actions.
- Les metriques deja emises couvrent: `full_shop_cost_ratio`,
  `full_shop_afford_rate`, `early_full_shop_afford_rate`,
  `desired_buy_all_rate`, `desired_gold_afford_rate`,
  `desired_slot_limited_rate`, `virtual_bench` pour tester des capacites de
  reserve supplementaires `0/2/4/6` au-dessus du plateau + banc reel du driver
  (`0` = gameplay actuel), `gold_leftover_wasted` via
  `avg_leftover_gold`, `gold_pressure`, `spend_split`, `rerolls_per_run`,
  `xp_buys_per_run`, `sells_per_run`, `sell_gold_per_run`,
  `bench_sells_per_run`, `board_sells_per_run`, `pair_buys_per_run`,
  `merge_buys_per_run`, accept/refus de slots, ventilation par tier, cohorts
  `legacy_all` / `broad_naive` / `broad_prune` / `broad_plan` / `committed` /
  `committed_plan`, `archetype_commitment_rate` et
  `avg_archetype_commit_round`, plus la separation par archetype entre runs ou
  le plan est forme et runs ou il ne l'est pas.
- Le `Rundriver` utilise maintenant le banc existant de la scene build
  (`Build:autoBuy`: plateau vide -> banc -> fusion si plein), au lieu de poser
  les achats uniquement sur le plateau.
- `Rundriver:sellBench` permet aux policies de vendre une reserve comme le
  joueur le fait par drag hors plateau/banc; les ventes sont tracees dans les
  metriques d'economie.
- `Policies.analysisSet` ajoute des variantes `_prune` de `greedy`, `econ` et
  `tall`: elles gardent les niveaux 2+, les paires proches de fusion, les
  pieces premium ou les pieces du plan, et vendent surtout les singletons du
  banc qui ne servent pas un merge immediat.
- `Policies.analysisSet` ajoute aussi des variantes `_plan` qui scorent les
  offres par paires, fusion immediate, rang/cout et appartenance au plan. Elles
  peuvent vendre une faible unite de board seulement si l'offre achetee vaut
  clairement mieux et si le board reste au-dessus d'un plancher de survie.

Run local a `N=20` runs/politique/profil apres instrumentation des offres
desirees, du banc reel et du commitment d'archetype:

- `baseline`: ratio shop/or moyen `0.67`, shop complet achetable `89.0%`,
  offres desirees achetables `21.9%`, desirees affordables en or `84.9%`,
  bloquees par espace `75.7%`, desirees achetables avec +4 reserve virtuelle
  `50.8%`, encore bloquees par espace avec +4 `42.4%`, commitment archetype
  `80.0%`, wins moyens `4.17`, leftover `9.66`.
- `sap_cost`: ratio `1.09`, shop complet achetable `62.5%`,
  offres desirees achetables `18.9%`, desirees affordables en or `65.2%`,
  bloquees par espace `75.3%`, desirees achetables avec +4 reserve virtuelle
  `48.0%`, encore bloquees par espace avec +4 `36.7%`, commitment archetype
  `73.8%`, wins moyens `4.08`, leftover `8.27`.
- `early_curve`: ratio `0.75`, shop complet achetable `87.8%`,
  offres desirees achetables `22.0%`, desirees affordables en or `84.4%`,
  bloquees par espace `72.6%`, desirees achetables avec +4 reserve virtuelle
  `50.2%`, encore bloquees par espace avec +4 `41.7%`, commitment archetype
  `71.2%`, wins moyens `3.97`, leftover `9.08`.

Interpretation provisoire:

- La courbe de revenu reduit un peu le surplus, mais elle ne corrige presque pas
  le probleme pedagogique du tier 1 tant que le shop complet coute 5g.
- Le profil `sap_cost` est le premier levier qui transforme vraiment "je peux
  tout acheter" en arbitrage sur le shop complet.
- Brancher le vrai banc dans le driver a augmente les performances moyennes
  (baseline `3.20 -> 4.17` wins moyens dans ce smoke) et le taux d'achat des
  offres desirees (`14.2% -> 21.9%`). Le simulateur precedent etait donc trop
  pessimiste sur l'accessibilite de run.
- Meme avec le banc live, l'espace reste une contrainte majeure pour les
  policies larges: `desired_slot_limited_rate` reste autour de `73-76%`. La
  decision economique doit donc se lire avec `desired_gold_afford` ET les
  metriques d'espace; `desired_buy_all_rate` seul reste insuffisant.
- Ajouter quatre slots virtuels supplementaires ferait remonter les achats
  desires a environ `50%`, mais il resterait encore `35-42%` de rounds
  limites par l'espace. Cela suggere que le probleme n'est pas seulement "banc
  trop petit"; il vient aussi des policies qui desirent trop d'offres a la fois
  et du manque de tri/vente/merge intelligent.
- Les policies `committed_*` sont presque resolues par le banc reel: elles
  achetent souvent `85-100%` de leurs pieces desirees et restent contraintes
  surtout par l'acces de tier/archetype, pas par la reserve. Les strategies
  `greedy`, `econ` et surtout `tall_dense` restent beaucoup plus sensibles a
  l'espace.
- Les plans `poison`, `burn` et `rot` commit souvent autour des rounds 2-3.
  `tank` reste beaucoup plus difficile: il n'a aucun rang 1, commit tard
  autour du round 5, et gagne peu. C'est un vrai signal d'accessibilite et/ou
  de tuning, pas seulement un probleme d'or.
- Ces chiffres restent un smoke de design a `N=20`; monter `N` et raffiner les
  policies avant de figer un changement live.

Run local suivant a `N=20` runs/politique/profil avec 12 policies
(`legacy_all` = les 9 policies precedentes; `broad_prune` = greedy/econ/tall
avec nettoyage de banc):

- Profil `baseline`, cohort `legacy_all`: wins moyens `4.17`, offres desirees
  achetables `21.9%`, bloquees par espace `75.7%`.
- Profil `baseline`, cohort `broad_naive`: wins moyens `7.38`, offres desirees
  achetables `7.7%`, bloquees par espace `92.3%`, +4 reserve virtuelle
  `47.6%`.
- Profil `baseline`, cohort `broad_prune`: wins moyens `8.03`, offres desirees
  achetables `12.8%`, bloquees par espace `87.2%`, +4 reserve virtuelle
  `68.9%`, `28.6` ventes/run.
- Profil `sap_cost`, cohort `broad_naive`: wins moyens `7.50`, offres desirees
  achetables `8.4%`, bloquees par espace `91.6%`, +4 reserve virtuelle
  `49.6%`.
- Profil `sap_cost`, cohort `broad_prune`: wins moyens `7.50`, offres desirees
  achetables `14.7%`, bloquees par espace `85.3%`, +4 reserve virtuelle
  `70.1%`, `24.2` ventes/run.

Interpretation ajoutee:

- Le pruning prouve que le simulateur precedent etait encore trop naif sur le
  banc pour les strategies larges: `tall_dense` passe par exemple de `5.1` a
  `6.7` wins moyens en baseline, et `econ` / `greedy` gagnent un peu.
- Le pruning ne suffit pas a faire disparaitre le probleme: meme avec vente de
  singletons, les cohorts larges restent bloquees par l'espace `85-87%` du
  temps. Cela pointe vers une combinaison de selection de shop trop large,
  manque de plan de paires, absence de vraie priorisation de board, et peut-etre
  taille de reserve.
- Il ne faut donc pas buff automatiquement le banc tout de suite. La prochaine
  passe doit distinguer: space vraiment insuffisant, policy trop gourmande,
  pieces gardees sans plan, et manque d'incitation a des lignes de build plus
  lisibles.
- Le diagnostic `tank` est plus net avec `completion_given_plan` /
  `avg_wins_given_plan`: en baseline, `tank` forme son plan dans `7/20` runs
  seulement, au round moyen `5.57`, et ne monte qu'a `1.43` wins moyens une
  fois forme. En `sap_cost`, il ne forme son plan que `5/20` runs et reste a
  `0` win moyen meme quand le plan est forme. Ce n'est donc pas un simple
  probleme d'espace: il faut soit un seed tank rang 1, soit une policy de rush
  tank beaucoup plus survivable, soit un buff mecanique du shell tank.

Dernier run local a `N=20` runs/politique/profil avec 19 policies et seeds
apparies (`broad_plan` = greedy/econ/tall avec paires + priorisation de board;
`committed_plan` = committed avec la meme logique):

- Global `baseline`: wins moyens `5.16`, completion `6.1%`, shop complet
  achetable `94.6%`, offres desirees achetables `23.6%`, bloquees par espace
  `75.4%`, +4 reserve virtuelle `69.6%`, leftover `9.11`, pression or `35.1%`.
- Global `sap_cost`: wins moyens `4.32`, completion `5.8%`, shop complet
  achetable `66.8%`, offres desirees achetables `22.6%`, bloquees par espace
  `74.9%`, +4 reserve virtuelle `67.8%`, leftover `8.68`, pression or `48.5%`.
- Global `early_curve`: wins moyens `4.84`, completion `9.7%`, shop complet
  achetable `93.8%`, offres desirees achetables `22.8%`, bloquees par espace
  `75.0%`, +4 reserve virtuelle `69.0%`, leftover `9.64`, pression or `41.2%`.
- Cohort `baseline/broad_naive`: wins `7.35`, completion `5.0%`, desired
  buy-all `8.2%`, espace limite `91.8%`, paires `4.0`/run, fusions `3.7`/run.
- Cohort `baseline/broad_prune`: wins `7.92`, completion `5.0%`, desired
  buy-all `11.2%`, espace limite `88.8%`, `26.6` ventes/run, paires `6.9`,
  fusions `6.0`.
- Cohort `baseline/broad_plan`: wins `8.78`, completion `21.7%`, desired
  buy-all `14.6%`, espace limite `85.4%`, `17.3` ventes/run dont `0.62`
  board/run, paires `7.8`, fusions `6.4`, +4 reserve virtuelle `87.6%`.
- Cohort `sap_cost/broad_naive`: wins `6.90`, completion `10.0%`, desired
  buy-all `8.7%`, espace limite `91.3%`.
- Cohort `sap_cost/broad_prune`: wins `7.32`, completion `11.7%`, desired
  buy-all `11.8%`, espace limite `88.2%`, `19.9` ventes/run.
- Cohort `sap_cost/broad_plan`: wins `7.77`, completion `10.0%`, desired
  buy-all `17.2%`, espace limite `82.7%`, `13.3` ventes/run dont `0.30`
  board/run, paires `7.5`, fusions `6.3`.
- `committed_plan` n'est pas encore une revolution: en baseline il passe de
  `2.16` a `2.21` wins moyens et garde le meme commitment global `76.2%`.
  Son interet est surtout methodologique: il prouve que la logique de paires ne
  degrade pas les plans committed quand aucune vente n'est necessaire.
- `tank` reste l'outlier: en baseline, seulement `2/20` runs tank forment le
  plan, round moyen `6`, completion `0%`, wins moyens `0.95`. En `sap_cost`,
  seulement `3/20` forment le plan, wins moyens `0.05`. Le probleme tank est
  donc un probleme d'accessibilite/power du shell, pas un probleme de banc.

Interpretation ajoutee apres pair-planning:

- Le simulateur est plus proche d'un joueur: il garde mieux les paires, complete
  plus de fusions et vend moins que le pruning pur.
- `broad_plan` change fortement le diagnostic du banc: avec une meilleure
  selection, +4 reserve virtuelle monterait les achats desires a `87%` environ
  sur les strategies larges, mais le jeu actuel reste encore limite par l'espace
  `82-85%` du temps. On doit donc continuer a ameliorer decision/paires avant
  de toucher la taille du banc live.
- `sap_cost` reste le meilleur levier de pression economique (`66.8%` shop
  complet achetable contre `94.6%` baseline), mais il reduit les wins moyens
  tant que certains shells, surtout tank, ne sont pas plus accessibles.

Ajout apres le scenario `tank` (`tools/sim.lua tank 20`) :

- Le diagnostic tank est maintenant separe en trois hypotheses testables :
  acces, pilotage et puissance mecanique.
- Le shell actuel reste tres faible : a pacing live (`hp x2 / cooldown x1`),
  `current_plan` fait `0%` completion, `0.90` wins moyens, `25%` plan commit
  et seulement `25%` de final boards vraiment tanks.
- Le shell `survival_shell` gagne tres fort (`55%` completion, `9.55` wins
  moyens), mais son actual final tank commit est `0%`. C'est donc un faux ami :
  acheter des corps low-rank robustes sauve la run, mais ne cree pas une
  identite tank lisible.
- `husk_seed` commit souvent (`90%`) mais reste a `0.00` wins live et `0%`
  final tank commit. Husk n'est pas une bonne graine tank sans mecanique
  defensive explicite.
- `demon_seed` est meilleur (`3.95` wins live, jusqu'a `6.00` en `hp2_cd4`),
  mais reste plutot un seed bruiser/lifesteal qu'une vraie entree tank.
- Le buff sim-only de payoff tank ne regle pas l'acces : il agit apres avoir
  trouve des tanks, donc il ne resout pas le trou de rang 1.
- Conclusion economie/design : il ne faut pas juger `sap_cost` ou une courbe
  de revenu tant que tank n'a pas une entree low-rank lisible. Sinon on risque
  d'attribuer a l'economie un probleme qui vient du roster.

Ajout pacing combat :

- Le scenario tank mesure maintenant les durees en secondes (`ticks / 60`) et
  le taux de combats sous 5 secondes.
- Sur `current_plan`, le live donne environ `9.81s` early en moyenne, `9.02s`
  median global, `15.10s` p90, et `10%` d'early fights sous `5s`.
- `cooldown x2` supprime les early fights sous `5s` et monte l'early moyen a
  `17.19s`, mais touche deja la fatigue dans environ `51%` des combats.
- `cooldown x3/x4` pousse presque tout en fatigue (`~89-94%` sur current tank).
  Un `cd x4` global serait donc trop brutal sans deplacer aussi le seuil de
  fatigue/overtime et retuner DoT/shields.
- Prochain test recommande : ajouter ces metriques de duree au scenario global
  non-tank, puis balayer `cd x1.5` / `cd x2` avec fatigue plus tardive.

Ajout apres le scenario global `pacing` (`tools/sim.lua pacing 10`) :

- Les metriques de duree sont maintenant mutualisees dans
  `tools/scenarios/common.lua`; le `Rundriver` peut forward un override
  lab-only de fatigue vers le moteur de match.
- Le live global donne dans ce batch : completion `7.9%`, wins moyens `5.29`,
  early moyen `9.91s`, early fights sous `5s` a `11.6%`, p50 `9.13s`,
  p90 `14.63s`, fatigue `5.3%`.
- `cd x1.5` avec fatigue a `17s` allonge bien (`12.52s` early, p50 `12.25s`)
  mais monte deja la fatigue a `21.6%`.
- `cd x2` avec fatigue a `17s` est trop brutal pour le seuil actuel :
  p50 `16.23s`, p90 `24.48s`, fatigue `45.6%`.
- `cd x1.5` avec fatigue a `24s` est le meilleur candidat preliminaire :
  completion `18.9%`, wins `5.77`, early moyen `13.59s`, early sous `5s`
  `6.8%`, p50 `12.33s`, p90 `20.45s`, fatigue `4.8%`.
- `cd x2` avec fatigue a `24s` reste peut-etre trop lent ou trop sensible a
  l'usure : p50 `16.03s`, p90 `25.90s`, fatigue `14.4%`.
- Conclusion provisoire : ne pas partir sur `cd x4`. La prochaine fenetre de
  tuning credible est plutot `cd x1.35` a `x1.65` avec fatigue autour de
  `22-26s`, a retester a plus grand N apres correction de l'entree tank.

Ajout outil autonome :

- `tools/sim.lua sweep [N]` croise maintenant economie, pacing et politiques
  dans une meme grille deterministe. C'est le mode a utiliser pour verifier les
  interactions avant une decision live.
- Les variables de controle utiles sont :
  `PIT_POLICIES`, `PIT_ECON_PROFILES`, `PIT_BENCH_CAPS`, `PIT_PACE_IDS`,
  `PIT_PACE_PROFILES`, `PIT_TANK_VARIANTS`, `PIT_HP_MULT`,
  `PIT_COMMANDER_MODE`.
- `PIT_COMMANDER_MODE` vaut `ignore` par defaut pour garder les baselines
  historiques. `auto` accepte le piédestal et place le meilleur porteur
  existant de `commandBonus`; `decline` refuse pour l'or.
- Format custom pacing :
  `PIT_PACE_PROFILES=id:hpMult:cdMult:fatigueStart[:fatigueBase[:fatigueRamp]],...`
- Le rapport economie expose maintenant un funnel de fusion approximatif :
  `pair_buys_per_run`, `merge_buys_per_run`, `merge_per_pair_buy`, globalement
  et par tier. C'est une alerte rapide sur les reroll comps qui achetent des
  paires sans arriver au niveau superieur.
- `economy` et `sweep` comptent aussi `commander_placements_per_run` et
  `relic_picks_per_run`, pour tester commandants/reliques dans les memes
  rapports que l'economie.
- Apres l'entree live de `husk` en tank rang 1, l'acces tank est meilleur, mais
  la conclusion importante est plus fine : une comp tank saine doit probablement
  etre mesuree comme `frontline anchor + payload protege`, pas comme un board
  majoritairement tank.
- Dans le probe N=20, `payload_shell` en live donne `55%` completion et `9.50`
  wins moyens avec `100%` de shell final, mais seulement `60%` de front-tank
  anchor. C'est fort, mais pas encore une identite tank assez lisible.

Ajout batch long avec commandants (`runs/long-2026-06-27`,
`PIT_COMMANDER_MODE=auto`) :

- `pacing N=50` confirme que `cd x1.5 + fatigue 24s` est le meilleur candidat
  prudent : completion `15.8%`, wins `6.20`, early `12.77s`, early sous `5s`
  `7.9%`, p50 `11.73s`, p90 `19.40s`, fatigue `2.8%`.
- Le live garde trop de combats courts en early : `17.4%` sous `5s`.
- `cd x2 + fatigue 24s` peut monter la completion dans le sweep integre, mais
  la fatigue monte vers `11%`. C'est utile comme stress test, pas comme premier
  candidat live.
- `sweep N=30` ne valide pas encore `sap_cost` comme changement live :
  `baseline + cd1.5/f24` bat `sap_cost + cd1.5/f24` dans ce batch (`5.93`
  wins vs `5.52`, `12.3%` completion vs `8.6%`). L'economie stricte doit etre
  retestee apres amelioration des shells faibles et du timing de policy.
- `tank N=50` confirme que le probleme tank restant n'est pas seulement l'acces :
  `current_plan` live fait `0%` completion / `1.64` wins, `husk_seed` live
  `0%` / `1.54`, tandis que `payload_shell` live fait `64%` / `9.62` mais avec
  seulement `52%` de front-tank anchor.
- Le probe `payload_arranged` ajoute un placement front deterministe et une
  metrique `prot%` (`front tank + payload derriere`). Il monte `prot%` de
  `52%` a `96%` en live et `94%` en `cd1.5/f24`, mais les wins restent proches
  de `payload_shell`. Conclusion : le placement corrige la lisibilite/protection,
  pas l'equilibrage. Le shell payload est deja fort ; il faut maintenant rendre
  l'identite tank plus intentionnelle.
- `economy N=30` avec commandants signale `sap_cost_tiered_reroll` comme profil
  economie a retester : completion `12.3%`, wins `5.61`, full-shop afford
  `67.9%`, pression or `0.52`, leftover `6.85`. Contrairement a `sap_cost`
  seul, il remet de la pression sans faire chuter autant les resultats.
- Les rapports economie exposent maintenant `by_unit_merge` et
  `unit_merge_watch`. En baseline N=30, la watchlist signale notamment
  `emberling`, `byakhee`, `vanguard_drummer`, `arcane_seer`, `rat_warren`,
  `rear_goad`, `corruptor`, `pyre_herald` comme paires peu converties dans ce
  batch. Ce sont des pistes d'investigation, pas des verdicts automatiques.

Ajout batch autonomie (`runs/long-2026-06-27b`) :

- Le funnel de paires a ete remplace dans `economy` et `sweep` par une premiere
  vraie lecture lifecycle : `merge_lifecycle.resolve_rate`,
  `avg_rounds_to_merge`, paires non resolues et watchlist par unite. Ce n'est
  pas encore une identite de copie vendue/perdue, mais c'est meilleur que
  `merge_per_pair_buy` seul.
- `economy N=40`, commandants auto, profils `baseline`, `early_curve`,
  `sap_cost_tiered_reroll` :
  - `baseline` : completion `9.3%`, wins `5.75`, full-shop afford `93.7%`,
    pression `0.35`, leftover `9.52`, pair resolve `76.4%`.
  - `early_curve` : completion `4.5%`, wins `5.26`, full-shop afford `94.4%`,
    pression `0.42`, leftover `9.97`, pair resolve `77.9%`.
  - `sap_cost_tiered_reroll` : completion `10.1%`, wins `5.41`, full-shop
    afford `69.1%`, pression `0.52`, leftover `8.01`, pair resolve `76.9%`.
- Lecture : `sap_cost_tiered_reroll` est le meilleur candidat de pression, mais
  il ne bat pas baseline en wins moyens dans ce batch. La bonne prochaine etape
  n'est pas de le passer live immediatement, mais de le garder comme candidat
  principal pendant que les policies/roster corrigent les shells sous-puissants.
- `sweep N=20`, live pacing vs `hp2_cd15_f24` :
  - `baseline` passe de `7.4%` completion live a `11.1%` en `cd1.5/f24`.
  - `early_curve` tombe de `8.9%` live a `6.6%` en `cd1.5/f24`.
  - `sap_cost_tiered_reroll` passe de `5.8%` live a `8.2%` en `cd1.5/f24`.
  - La fatigue reste basse (`~2-3%`), donc `cd1.5/f24` reste le candidat
    pacing prudent.
- Nouveau mode `tools/sim.lua coherence [N]` : la puissance est encore trop peu
  reliee a la coherence semantique. `coherence N=36`, matches `8`, donne une
  correlation coherence/winrate de seulement `0.075`. Les piles endgame cheres
  expliquent une partie des low-coherence winners; les vrais signaux a lire
  sont `cheap_strong` et `high_coherence_weak`.
- Outliers a inspecter : `mid_tank`, `mid_shock` et plusieurs generated mixed
  mid piles surperforment; `cross_bleed_rot`, `rot_carre_perfect`,
  `shock_nuke_croix`, `burn_ligne_perfect`, `bleed_lock_anneau` sous-performent
  malgre une coherence lisible. Cela pointe vers un probleme de reward des
  plans DoT/cross-tag par rapport aux shells defensifs/good-stuff midgame.
- Mise a jour suivante : le score de coherence sait maintenant lire des
  reliques comme amplificateurs semantiques (`subscores.relic`, `relicEdges`)
  et le scenario `coherence` peut generer des variantes avec reliques adaptees.
  Attention : cela ne modele pas encore le timing d'obtention des reliques dans
  une run. Pour l'economie, il faut encore mesurer l'acces reel aux reliques et
  ne pas confondre "la relique rend le plan coherent" avec "le joueur peut
  l'obtenir assez souvent au bon moment".
- Mise a jour `level_fit` : le scenario `coherence` genere maintenant des
  variantes levellees des compos fixes et separe les faibles sous-leveles dans
  `underleveled_high_coherence_weak`. C'est important pour l'economie : un plan
  coherent ne doit pas etre juge faible sans verifier si le joueur avait investi
  assez de copies/XP pour son stade.

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
- `merge_lifecycle.resolve_rate` : paires formees qui deviennent vraiment une
  fusion.
- `merge_lifecycle.avg_rounds_to_merge` : delai moyen entre paire et fusion.
- `merge_lifecycle.watch` : unites qui generent des paires mais les convertissent
  mal.
- `level_fit` : adequation entre les niveaux reels du board et le niveau attendu
  pour le stade teste.

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
