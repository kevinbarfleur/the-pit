# R09 — Critique adversariale, lentille RELIQUES (round 9/10)

> **Round** : 9/10. **Lentille** : les 21 reliques — impact, build-defining, archetypes,
> equilibre, lisibilite, niveau de boutique.
> **Sources internes lues ce round** : `src/data/relics.lua` (integrale, relu ligne a ligne) ;
> `docs/research/relics-design.md` ; `00-state.md` ; `ROADMAP-draft.md` (brouillon v9, post-
> round-8) ; `round-08.md` (synthese integrale) ; `rounds/r08-relics.md` (integrale) ;
> `competitive/slay-the-spire.md` ; `competitive/balatro.md`.
> **Garde-fou absolu** : lecture seule du repo de jeu. Ce fichier n'edite que
> `docs/roadmap-lab/`. Piliers : async snapshots / sim deterministe seedee / DA grimdark /
> pixel art procedural. Toute affirmation de design cite une source (URL ou fichier+ligne).

---

## 0. TL;DR — challenge cle (3 phrases)

Le round 8 a adopte les bonnes corrections sur les metriques (`offer_decision_quality`
segmentee, baseline post-garantie-early, drought-protection note, ordre de calibration B) et
la relique B scalante `resonance_stone` comme candidate P1.5b. **Le vrai trou non adresse en
9 rounds : les 4 reliques E (Tier 4 — transformatives) sont des amplificateurs de regles deja
existantes, mais AUCUNE ne cree une INTERACTION NOUVELLE entre familles de DoT, entre unites
du build, ou entre le build et la topologie du plateau — ce sont des ON/OFF binaires sur des
flags existants, pas des reliques « build-defining » au sens de Burgun 2021 ou de Balatro. La
hierarchie SHAPERS/COURONNEURS est mecanistement correcte mais psychologiquement vide : un
COURONNEMENT qui n'amplifie rien d'unique au build du joueur n'est pas un moment de
couronnement, c'est un toggle de flag.** En consequence directe, les reliques les plus
rares et les plus gatees du systeme (tier 4, late run) sont structurellement moins
build-defining que les reliques B tier-2 — une inversion de la hierarchie emotionnelle
attendue.

---

## 1. Accords — ce qui tient, avec le POURQUOI pour nos contraintes

### 1.1 ACCORD FORT — `offer_decision_quality` segmentee par tier d'avancee + pseudo-decision (round-08.md §3.1, adopte)

**Ce que le round 8 acte** : cibles par tier (early <60 % / mid <40 % / late <30 %) + sous-
metrique de divergence de consequence (<20 % pseudo-decisions) + proportion d'offres en
tension reelle (>35 %). Source : `r08-relics.md §2.1/Prop-A` + `round-08.md §3.1`.

**Pourquoi ca tient** : la trivialite structurelle early (≥89 % des offres contiennent une A,
calcul hypergometrique verifie : `1 − C(4,3)/C(7,3) = 1 − 4/35 ≈ 88,6 %` avec 4 A / 7
eligibles en tier-1) n'est pas tunable par les inc des B — elle est architecturale. La
segmentation est correcte et necessite. Elle survit au pilier async : dans un pool LOCAL
(non-partage), la repetition d'offres est plus forte que dans TFT (pool partage entre 8
joueurs) — l'heterogeneite temporelle compte PLUS, pas moins. Source : `competitive/slay-
the-spire.md §2.4` (le rare-climb de StS adresse cette heterogeneite temporelle via un
mecanisme graduel, pas un seuil uniforme).

**Ce qui tient specifiquement pour nos contraintes async** : `offer_decision_quality` mesure
le pool COMPILE, pas les decisions en temps reel — la metrique est donc reproductible de
facon deterministe sur N seeds distincts, ce qui est requis pour calibrer un systeme de
reliques async-safe. La segmentation par tier d'avancee est mesurable depuis `state.wins`
(00-state §4.2, invariant #11-16), sans RNG supplementaire.

---

### 1.2 ACCORD FORT — Relique B scalante `resonance_stone` : adoption SPEC A PROUVER (round-08.md §3.6, P1.5b candidate)

**Ce que le round 8 acte** : `resonance_stone` (+5 % affliction_inc par unite du meme
`dot_family`) adoptee comme candidate P1.5b, conditionnee par le tableau de saturation (P1)
et `dot_family` (P0.5). Source : `round-08.md §3.6`.

**Pourquoi ca tient (et pourquoi la condition est bonne)** :

La critique du round 8 (`r08-relics.md §2.2`) identifie correctement la difference entre :
- **Boost plat** (B actuelles : `kings_bowl` +20 % fixe) : valeur identique qu'on soit a
  1 unite poison ou 6.
- **Boost scalant** (resonance) : valeur CROISSANTE avec la coherence du build.

Ce n'est pas une analogie paresseuse avec Balatro. Le mecanisme psychologique qui transfère
est precis : c'est le **cout d'irreversibilite positif** (sans downside). Dans Balatro,
un Joker conditionnel (ex. Baron : « chaque King en main donne ×1.5 ») monte en valeur si on
continue a drafter des Kings — le joueur NE PERD PAS s'il ne draft pas de Kings, mais la
valeur accumulee est perdue. Source : `competitive/balatro.md §5.3` (« un Joker modifie une
REGLE du jeu » ; Joker conditionnel = scaling par condition).

La condition « dependante du tableau de saturation (P1) » est mecanistement necessaire : un
`+5 % × 6 unites = +30 %` en cumulatif avec le palier-2 (P1, +20 %) + la B plate (+20 %) +
une aura `*Inc` (+10-15 %) depasse aisement le cap `DOT_CAP_MULT=3` (00-state §3, `ops.lua:22`
relu). La precondition est correcte et non-contournable.

**Ce qui tient specifiquement en async** : `resonance_stone` calcule sa valeur AU BUILD,
pas en combat — snapshotable sans modification du format `{shape, units}` (00-state §5).
Compatible avec les snapshots v1 (effets de base) qui ignorent les reliques en v1 (dette
connue) — la valeur scalante est encapassee dans les stats de la compo au moment du
snapshot, exactement comme les auras d'adjacence.

---

### 1.3 ACCORD — Drought protection comme INTENTION documentee (round-08.md §3.3, P3 doc)

**Ce qui tient** : la distinction entre la garantie de pertinence (« si une B est dans
l'offre, sa famille est presente ») et la drought protection (« si le build a une famille
dominante et n'a pas vu de B/E de cette famille depuis 2+ offres, augmenter le poids ») est
exacte. Ce sont deux mecanismes distincts qui se renforcent sans se doubler. Source :
`r08-relics.md §2.4/Prop-D` (verifie la distinction) ; `competitive/slay-the-spire.md §3.2`
(rare-climb StS : la montee de probabilite est COMPLEMENTAIRE de la garantie de carte de
boss, pas redondante).

**Ce qui tient pour nos contraintes** : le poids suppletif est deterministe si calcule depuis
l'etat seede du run (`state.rng` lie au seed du run — invariant #2). La pity-garantie
explicite est correctement rejetee (liste des anti-patterns §10 du brouillon). Note de
precision : le poids suppletif doit s'activer SEULEMENT apres que la garantie de pertinence
a ete satisfaite sans produire la B attendue — cf. `r08-relics.md §4 Q4` (risque de doublement).

---

### 1.4 ACCORD — Hierarchie CREATEURS/SHAPERS/COURONNEURS actee (ROADMAP-draft §4.11)

**Ce qui tient (avec une nuance importante — cf. §2.1 ci-dessous)** : la separation des
roles est mecanistement exacte. Les reliques E amplifient une regle sans la creer — ce n'est
pas un defaut, c'est une consequence du principe #2 (pas de downside, relics-design.md §1).

**Ce qui tient pour nos contraintes async** : dans un systeme de snapshots, une relique sans
downside est preferable (le snapshoteur ne sait pas quels adversaires il affrontera — une
relique a penalite croisee pourrait invalider un run entier sans recours). Source confirme :
`relics-design.md §1 principe #2` ; `round-08.md §1.1`.

**MAIS** : l'accord s'arrete a l'analyse MECANIQUE. La nuance critique (§2.1 ci-dessous) est
que COURONNEURS ne signifie pas MEMORABLE. L'accord sur la hierarchie est sur la structure,
pas sur la qualite de l'experience produite.

---

### 1.5 ACCORD — Arc temporel ≥1 shaper-mid + ≥1 payoff-late par archetype + ordre de calibration B (round-08.md §3.4/§3.5)

**Ce qui tient** : l'arc incomplet de rot (pas de payoff-late tier-4) et choc (pas de shaper-
mid, dependant de #GG) sont documentes et corriges en P1.5b. L'ordre de calibration B
(bleed/rot AVANT burn) est correct : tuner la famille la plus visible (burn, inc=0.30) avant
les familles faibles (bleed/rot, inc=0.18) serait un biais de confirmation du symptome. Source :
`round-08.md §3.4` ; `r08-relics.md §2.6/Prop-E`.

---

## 2. Desaccords — ce qui est faible, manquant ou faux dans le brouillon

### 2.1 DESACCORD MAJEUR — Les 4 reliques E (tier 4 / transformatives) sont des toggles de flags existants, pas des reliques build-defining

**Ce que le brouillon affirme** : les reliques E sont des « COURONNEURS de commit », les plus
build-defining du systeme. Source : `ROADMAP-draft §4.11`.

**Code verifie ce round (`relics.lua:51-58` relu integrale)** :

```lua
forked_tongue   = { op="relic_add_effect", tier=4,
  params={effect={trigger="combat_start", op="grant_team", params={shockChain=1}}} }
everburn        = { op="relic_add_effect", tier=4,
  params={effect={trigger="combat_start", op="grant_team", params={burnNoDecay=true}}} }
open_wounds     = { op="relic_add_effect", tier=4,
  params={effect={trigger="combat_start", op="grant_team", params={bleedNoExpire=true}}} }
plague_communion = { op="relic_add_effect", tier=4,
  params={effect={trigger="combat_start", op="grant_team", params={plagueAmp=0.25}}} }
```

**Toutes les 4 reliques E posent un `teamFlag` via `grant_team` a `combat_start`. Ce sont des
flags binaires (ON/OFF) sur des mecaniques DEJA EXISTANTES.** La question n'est pas de savoir
si ces flags fonctionnent — ils fonctionnent. La question est : est-ce que « burn ne decroit
plus » (`burnNoDecay`) est un MOMENT DE COURONNEMENT ou un AJUSTEMENT DE PARAMETRE ?

**Pourquoi la distinction est critique (teardown psychologique)** :

Burgun (keithburgun.net/pick-1-of-3) definit une decision « interesting » comme une decision
qui oriente le build vers des **strategies DISTINCTES avec des couts a ne pas prendre**. Une
relique build-defining au sens de StS (ex. Dead Branch — chaque carte exhausted genere une
carte aleatoire) **change la STRUCTURE des decisions suivantes** : le joueur doit desormais
prioriser les cartes exhausted, reorganiser son deck, reconsiderer son pathing. La relique
ne toggle pas un flag : elle ouvre un **espace de decisions supplementaires**.

Dans The Pit, `everburn` (burn no-decay) modifie le comportement d'une mecanique existante,
mais **ne change pas les decisions de BUILD** : le joueur qui a `everburn` fait exactement
les memes decisions de placement et de composition qu'avant, avec des chiffres plus forts.
Ce n'est pas un COURONNEMENT, c'est un AMPLIFICATEUR CAMOUFFLE EN TRANSFORMATIF.

**Comparaison directe dans notre referentiel (Balatro, notre reference d'addiction, gd-
research-result.md §2.6)** : LocalThunk distingue les Jokers « +Mult » (amplificateurs) des
Jokers « Utility » (modificateurs de REGLE). Un Joker comme Four Fingers (« Flush faisable a
4 cartes ») est une relique E au sens du brouillon — mais son impact est que le joueur DOIT
reconstruire sa strategie (quelles mains jouer, comment construire son deck). `everburn` au
contraire est equivalent a un « ×1.5 sur le Mult des Flushs » — un amplificateur, pas une
regle modfiiee. Source : `competitive/balatro.md §5.3` (distinction Joker « +Mult » vs Joker
« Utility/modifier-de-regle »).

**L'inversion de hierarchie emotionnelle** : en pratique, les 4 B plates (tier-2) sont PLUS
build-defining que les 4 E (tier-4), parce qu'une B comme `kings_bowl` confirme et oriente
le choix d'archetype (decision de composition), tandis qu'une E comme `everburn` valide un
burn deja construit sans changer sa forme. Dans la hierarchie emotionnelle attendue, les
reliques rares et tardives doivent produire un moment de « mon build vient de changer de
dimension » — pas un « mon build existant est maintenant legerement meilleur ».

**Distinction de nos contraintes (DESACCORD CIBLE, pas appel a casser les piliers)** :

Le correctif n'est PAS d'ajouter un downside aux reliques E (principe #2 maintenu). Le
correctif est que les reliques E doivent, en plus de toggler un flag, OUVRIR une dimension
de decision de placement ou de composition qui n'existait pas avant.

Exemple concret : `forked_tongue` (choc rebondit) dans sa forme actuelle toggle
`shockChain=1` — si l'adversaire a une configuration de placement favorable, le rebond est
fort ; sinon il est nul. Mais la DECISION de placement qui capitalise sur le rebond (« ou
placer mes unites choc pour que le rebond touche la cible la plus haute en aggro ») est DEJA
dans le jeu (ciblage deterministe, 00-state §3.3). `forked_tongue` ne cree pas cette
dimension — elle la capitalise.

Une relique E qui CREERAIT une dimension : « les unites adjacentes via le sigil peuvent
**cumuler** leur deplacement d'affliction a la mort » — cree une NOUVELLE DECISION DE
PLACEMENT (grouper les unites de meme famille pour maximiser la propagation a la mort) et une
interaction avec la TOPOLOGIE du sigil actif. C'est de la profondeur emergente.

**Impact sur P1 (synergies par TYPE)** : si les types P1 doivent creer de la profondeur
emergente (`dot_family` + compteur global), les reliques E tier-4 doivent AMPLIFIER cette
profondeur, pas l'ignorer. Une relique E qui ignore les synergies par type (plague_communion
amplifie les dommages sans lien au compteur de type) rate l'occasion d'etre le PAYOFF
ULTIME de l'investissement de build. Source : `ROADMAP-draft §4.11` (hierarchie mentionnee
mais non articulee sur l'interaction avec P1).

**Ce que le brouillon n'adresse pas** : aucun des 9 rounds precedents n'a examine si les
reliques E INTERAGISSENT avec les synergies de TYPE P1. `plague_communion` (+25 % dommages
si 2+ afflictions actives) ignore completement le compteur de type — un build a 1 seule
famille (4 unites poison) et un build 4-familles (1+1+1+1) declenchent `plague_communion`
identiquement si les cibles ont 2+ afflictions actives. La relique la plus transformative du
pool est AVEUGLE a la dimension build-defining la plus importante du jeu (le choix de
familles).

**Source** : `relics.lua:57-58` (relu ce round) ; `competitive/balatro.md §5.3` (Joker =
une regle modifiee, pas un passif) ; keithburgun.net/pick-1-of-3 (decision interesting =
orientation vers strategies distinctes) ; `00-state §2.2` (reliques E = tier 4, late run) ;
`ROADMAP-draft §4.11` (hierarchie build-definition).

---

### 2.2 DESACCORD — `plague_communion` a un bug semantique non detenu par le code : le compte des afflictions actives est sur la CIBLE, pas sur l'equipe du joueur

**Claim implicite du brouillon** : `plague_communion` recompense un build multi-afflictions.
ROADMAP-draft §4.11 la classe comme relique C « palier/payoff » qui recompense le multi-
archetype.

**Code verifie ce round** (`relics.lua:57-58`) :

```lua
plague_communion = { op="relic_add_effect", tier=4,
  params={effect={trigger="combat_start", op="grant_team", params={plagueAmp=0.25}}} }
```

`plagueAmp=0.25` est un `teamFlag`. Le comportement est defini dans `arena.lua` (la lecture
du flag `plagueAmp`) — d'apres la description i18n (relic.<id>.effect), il s'active
« si 2+ afflictions actives » [sur la cible adverse].

**Le probleme semantique** : « 2+ afflictions actives sur la cible » peut etre satisfait par
**un seul poseur burn T3** avec propagation (l'ennemi brule et saigne d'une propagation
mort de la meme equipe burn) — pas besoin de build multi-familles. A l'inverse, un build
bleed pur avec 4 unites bleed et `open_wounds` (bleedNoExpire) peut ne pas declencher
`plague_communion` si les ennemis ne cumulent qu'une affliction (bleed seul).

**Le PAYOFF n'est pas aligne sur la STRATEGIE qui devrait le declencher** : la relique est
censee recompenser le multi-affliction (build diversifie), mais elle peut se declencher sur
un build mono-famille (burn avec propagation) et ne pas se declencher sur un build mono-
famille restrictif (bleed pur sans contagion). Ce n'est pas un bug code — c'est une ambiguite
de design. Mais l'ambiguite genere une fausse attribution : le joueur croit que sa strategie
multi-afflictions est recompensee, alors que c'est la contagion adverse involontaire qui
declenche le bonus.

**Distinction de nos contraintes** : en async, un ghost qui possede `plague_communion` peut
etre affonte par un joueur qui n'a pas diversifie ses afflictions — le flag s'active sur la
cible (le joueur adverse), pas sur la source (le ghost). Resultat : `plagueAmp=0.25` beneficie
au ghost quelle que soit la composition du joueur adverse, pourvu que les cibles aient 2+
afflictions. Le payoff n'est pas oriente build, il est oriente matchup (« est-ce que
l'adversaire m'a afflicte en multi ? »). Dans un contexte async, ce n'est pas controllable.

**Source** : `relics.lua:57-58` (relu integrale ce round) ; ROADMAP-draft §4.11 (description
de plague_communion) ; `00-state §3.1` (teamFlags, `grant_team`, lu a `combat_start`) ;
`round-08.md §1.1` (adoption round-08 confirmant plague_communion « gardee telle quelle »
depuis le round 3 — bug semantique jamais detecte).

**Note historique** : le round 3 avait propose de corriger `plague_communion` en une relique
« scalante par famille majoritaire » — le brouillon a correctement rejete cette correction
comme trop complexe (§10, liste des rejets). Mais le brouillon n'a pas resolu le probleme
semantique de base (le declenchement sur la cible). Le rejet de la correction ne signifie pas
que l'original est correct — il signifie que la correction proposee etait mauvaise.

---

### 2.3 DESACCORD PARTIEL — L'impact des reliques A (stats plates, tier 1) est sous-estime comme bruit par deficit d'identite

**Claim du brouillon** : les reliques A (`bloodstone`, `carapace`, `aegis`, `whetstone`) sont
des « FONDATIONS universelles » — valeur toujours positive, 0 vote sur l'identite du build.
Source : `ROADMAP-draft §4.11`.

**Ce qui manque dans cette lecture** :

Le brouillon acte que les reliques A sont universelles et non-narratives. Il ne questionne pas
si cette universalite est un ATOUT ou un DEFICIT pour la session de build. La lecture
optimiste est : « une fondation est utile a n'importe quel build ». La lecture adversariale :
**une fondation universelle est une decision SANS COUT a ne pas prendre** — il n'y a jamais
de raison de ne pas prendre `carapace` (+8 PV, team-wide) si on ne voit pas de B/C/D/E
pertinent pour le build.

Burgun (keithburgun.net/pick-1-of-3) : « When a decision has an obvious answer — one option
is always better regardless of context — it stops being a decision and becomes an action. »
Une relique A dans une offre early contre 2 B non pertinentes n'est pas une decision —
c'est une action (prendre A). Psychologiquement, une action sans tension ne cree pas de
sentiment d'identite de run.

**Ce qui se passe concretement** : si 89 % des offres early contiennent une A (calcul §1.1),
et que le build n'est pas encore engage, le joueur prend systematiquement la A. Pendant 3-4
offres de reliques (les plus charniers psychologiquement, 00-state §2.2 : premier arc 0-1 wins
= early), le joueur n'a jamais eu a DEFINIR son build via une relique — seulement a RENFORCER
ses stats. L'identite de run de §2.4bis (nom de build) ne peut pas etre alimentee par les A
(elles ne portent pas de `dot_family`). La consequence : les reliques ne contribuent pas a
l'identite de run avant le mid (wins 2+). Ce n'est pas un bug, c'est un trou de design.

**La reference correcte** : StS n'a pas de reliques entierement universelles dans ses tiers
principaux — meme les reliques communes les moins puissantes ont une condition d'activation
ou un profil d'usage prefere (Akabeko = utile pour les builds qui attaquent souvent en round
1 ; Centennial Puzzle = utile pour les builds qui piochent sur blessure). Source :
`competitive/slay-the-spire.md §2.1` (description precise des reliques par tier). Meme
Akabeko (+8 ATK 1er round) a un micro-profil (builds aggressifs early).

**Ce n'est PAS un appel a retirer les reliques A** (elles jouent le role de securite
universelle, et le principe « pas de gate » est maintenu). C'est un appel a reconnaitre que
les A contribuent au bruit de decision et que la solution partielle (garantie de pertinence,
B evidentes dans les offres mid) doit etre accompagnee d'un signal d'identite meme en early —
qui pourrait venir de la tonalite grimdark des A (nom + flavor fort, meme pour une fondation)
plutot que de leur mecanique.

**Implication pratique non adressee** : l'audit `offer_decision_quality` segmente par tier
(§1.1 de ce rapport) mesurera la trivialite early comme inevitable (<60 % triviales acceptable)
— mais ce seuil accepte implicitement que les rounds 1-3 de reliques ne construisent pas
l'identite de run. Est-ce voulu ? Le brouillon ne tranche pas.

**Source** : keithburgun.net/pick-1-of-3 (decision obvious = action) ; `competitive/slay-
the-spire.md §2.1` (tiers de reliques StS, meme les communes ont un micro-profil) ; `r08-
relics.md §1.1` (accord partiel sur le risque de bruit des A en early, non quantifie) ;
`ROADMAP-draft §4.11` ; `relics.lua:20-22` (les 3 A actives, relu ce round).

---

### 2.4 DESACCORD — La relique `feeding_frenzy` est mecaniquement mal specifiee pour un build « bruiser » et risque d'etre silencieuse dans les matchups where elle compte

**Claim du brouillon** : `feeding_frenzy` est le payoff des archetypes bruiser/carries
(`relics-design.md §5 : « kill snowball »`). Source : `ROADMAP-draft §4.2 + §4.8`.

**Code verifie ce round (`relics.lua:39`)** :

```lua
feeding_frenzy = { op="relic_add_effect", tier=3,
  params={effect={trigger="on_death", op="frenzy_gain", params={per=0.08, cap=6}}} }
```

`frenzy_gain` s'active `on_death` — un kill ennemi declenche un bonus (`per=0.08`, cap=6).
La logique d'un kill-snowball est correcte en principe.

**Le probleme de timing** : `on_death` est un broadcast differe hors-reentrance
(`arena.lua:566`, source `round-08.md §1.4`). Dans un build bruiser (aggro elevee, cibles
la colonne avant), le bonus de kill arrive AU TOUR SUIVANT du bruiser qui a tue. Dans un
matchup ou le bruiser tue VITE (matchup facile — les matchups ou `feeding_frenzy` est « le
plus utile »), il a deja atteint son cap de bonus naturellement. Dans un matchup difficile
(build tank adverse avec 40+ aggro et `second_breath`), le bruiser peut ne JAMAIS obtenir
le premier kill — `feeding_frenzy` reste silencieuse exactement quand le joueur en aurait
besoin.

C'est l'anti-pattern exact de Wayline.io/blog/roguelike-itemization (verifie) : « items that
are most useful when you're already winning are luxuries, not enablers. An enabler changes
a losing or neutral matchup ; a luxury amplifies a winning one. » `feeding_frenzy` est une
LUXE (forte dans les matchups gagnants, silencieuse dans les matchups perdants) alors que
le brouillon la classe comme EGALISATEUR (relics-design.md §1 principe #3 : « egaliser le
matchup »).

**Ce n'est pas un appel a retirer `feeding_frenzy`** : le snowball sur kill est un archetype
valide. Mais sa classification comme « egalisateur » dans `relics-design.md §1` est inexacte
— c'est un amplificateur de build engage. Sa position en tier-3 (pas tier-4) est peut-etre
correcte precisement parce qu'elle n'est pas assez universellement applicable pour un tier-4.
Mais la documentation doit etre honnete sur ce qu'elle fait : un payoff bruiser, pas un
egalisateur de matchup.

**Impact sur la garantie de pertinence** : `feeding_frenzy` devrait etre proposee (garantie
de pertinence) uniquement si le build a des unites a aggro elevee ≥20 (bruisers ou tanks).
La garantie de pertinence actuelle (§4.1) ne distingue pas les reliques C par type d'unite
requise — elle garantit seulement la pertinence des B par `dot_family`. Si un joueur sans
bruiser se voit proposer `feeding_frenzy`, la garantie a ete satisfaite de facon
structurellement incorrecte (tier-3 eligible, mais non pertinent pour le build).

**Source** : `relics.lua:39` (relu ce round) ; `relics-design.md §1 principe #3` (egaliser
le matchup) ; Wayline.io/blog/roguelike-itemization (luxury vs enabler, verifie) ; `00-state
§3.3` (ciblage, aggro activee : tank=40, bruiser=15, carry=5) ; `round-08.md §4.6 §4.7`
(IA cold-start ranked).

---

### 2.5 DESACCORD PARTIEL — Les reliques F (de boutique) sont depreciorisees mais leur ROLE ECONOMIQUE dans le run n'est pas encore articule comme des DECISIONS DISTINCTES

**Claim du brouillon** : les reliques F (`carrion_ledger` XP, `black_summons` tier+1,
`beggars_lantern` tier-1) sont depreciorisees (pool-A partiellement) en attente du marchand
P1.5c. Source : `ROADMAP-draft §1.10 + calendrier §9`.

**Ce qui est correct** : la demotion des F comme objets non-pertinents dans les offres de
combat est juste — leur effet (modifier la boutique) est desynchronise de l'acquisition
(recompense de combat). Source confirme : `round-08.md §1.2` (accord fort F→marchand).

**Ce qui reste un trou non adresse** :

Les reliques F creent une TENSION ECONOMIQUE distincte : `beggars_lantern` (decale les cotes
1 tier plus bas) est la SEULE mecanique du jeu qui cree une OPPOSITION entre la progression
normale de boutique et une strategie de max-doubles (garder les cotes bas pour maximiser les
copies de rang-1/2 en vue des tripletes). Ce n'est pas juste une relique de boutique — c'est
un ARCHETYPE DE RUN (le « tall dup » ou « wide low ») qui n'a pas de signal identitaire clair.

`black_summons` (tier+1 immediat) est la SEULE mecanique qui accelere la courbe XP au-dela
du BUY_XP regulier — et son positionnement en tier-4 (anti-snowball, 00-state §2.2) en fait
une relique tardive pour un effet de timing early. Si le joueur la voit a wins=5 et est deja
en shopTier 4 passivement, son effet est presque nul.

**Ce trou n'est pas bloquant pour P1**, mais il manque dans le brouillon une articulation des
3 archetypes economiques distincts que les F servent :
1. `carrion_ledger` → archetype « rush-tier » (accelerer pour voir les unites rang-4/5 tot)
2. `black_summons` → archetype « spike-mid » (booster une montee de palier precise)
3. `beggars_lantern` → archetype « max-dup » (rester bas pour tripler)

Si ces 3 archetypes ne sont pas documentes avant P1.5c (marchand), le marchand proposera
des reliques F sans que le joueur comprenne pourquoi les ACHETER est une decision
strategique distincte (pas juste un bonus). Source : `relics.lua:64-66` (relu ce round) ;
`00-state §4` (economie run, boutique XP) ; `competitive/balatro.md §7.3` (modele economique
shop : tension achat vs reroll, chaque achat a une strategie de build distincte associee).

---

## 3. Propositions priorisees

### Prop-A — CORRIGER l'alignement de `plague_communion` sur la composition du joueur (PRIORITE 1, data ~5 lignes)

**Quoi** : modifier la condition d'activation de `plague_communion` pour qu'elle se declenche
sur la COMPOSITION DU JOUEUR (nombre de familles DoT distinctes dans le build), pas sur les
afflictions de la cible.

**Mecanique cible** : `plagueAmp` s'active si `build.dot_family_count >= 2` (nombre de
familles DoT distinctes dans la compo du joueur) — lu au `combat_start`. Cette information
est deja disponible (les unites ont leur `dot_family` post-P0.5) et calculable sans RNG.

**Exemple** : un build 3 poison + 1 burn → 2 familles → `plagueAmp = 0.25` actif. Un build
6 poison pur → 1 famille → `plagueAmp` inactif. Le joueur qui choisit la diversification est
recompense ; le joueur mono-famille ne l'est pas.

**Pourquoi c'est important** :
- Aligne le PAYOFF sur la STRATEGIE (diversification multi-famille).
- Interagit directement avec les types P1 (dot_family, seuil 2/4) : `plague_communion` devient
  LE payoff relique des builds multi-types.
- Corrige l'incoherence async : le flag ne depend plus de ce que l'adversaire fait (ses
  afflictions sur nos cibles) mais de ce que nous avons construit.

**Prerequis** : `dot_family` pose sur chaque unite (P0.5, §3.3 ROADMAP-draft).

**Impact sur le golden** : le flag `plagueAmp` est `nil` par defaut → inerte → le golden
est INCHANGE tant que le scenario golden n'a pas 2 familles distinctes dans le build. A
verifier avec un grep du scenario golden (`golden.lua:17`, build exact).

**Compatibilite async** : calculable au BUILD (comme les auras), snapshotable sans changement
de format v1.

**Litige potentiel #HH (neuf)** : cette correction change le comportement de `plague_communion`
pour les builds en cours — les tests `tests/relics.lua` peuvent avoir un scenario qui
presuppose l'ancien comportement. A verifier AVANT de coder.

**Source** : `relics.lua:57-58` (relu ce round) ; §2.2 de ce rapport (bug semantique) ;
`ROADMAP-draft §4.11` (hierarchie CREATEURS/SHAPERS/COURONNEURS) ; `00-state §3.1`
(teamFlags, combat_start) ; P0.5 §3.3 (dot_family).

---

### Prop-B — SPECIFIER que les reliques E doivent OUVRIR une dimension de decision (spec editoriale P1.5b, 0 code, ~5 lignes)

**Quoi** : ajouter dans §4.11 (hierarchie build-definition) un critere editorial pour les
reliques E nouvelles (P1.5b et suivantes) :

```
CRITERE DES COURONNEURS (reliques E tier-4) :
Une relique E est build-defining si et seulement si elle ouvre AU MOINS UNE des 3 dimensions :
  (1) une nouvelle decision de PLACEMENT (interaction avec la topologie du sigil actif)
  (2) une nouvelle interaction entre FAMILLES de DoT (pas juste amplifier une seule)
  (3) un nouveau comportement CONDITIONNEL LIE A LA COMPOSITION (dot_family_count, aggro, 
      nombre de copies, etc.)
Un toggle de flag sur une mecanique existante sans condition nouvelle = SHAPER (tier-2/3),
pas COURONNEMENT (tier-4).
```

**Pourquoi** : sans ce critere, les reliques E futures (P1.5b) risquent d'etre encore des
boosts de flags sans profondeur. Le critere est editorial et ne change pas le code existant —
il guide les decisions de design futures. Source : `competitive/balatro.md §5.3` (Joker
modifie une regle, pas un passif) ; keithburgun.net/pick-1-of-3 (decision interesting =
orientation distincte).

**Impact sur les 4 E actuels** : aucun changement au code. Mais documenter honnêtement
que les 4 E actuels satisfont partiellement le critere (forked_tongue → dimension placement
implicite ; everburn/open_wounds → amplificateurs camouflés ; plague_communion → si
Prop-A adoptee, satisfait le critere 2). Le critere s'applique aux reliques FUTURES, pas
aux existantes.

---

### Prop-C — DEFINIR l'archetype economique des 3 reliques F AVANT P1.5c marchand (doc, P0.5 ou P1.5a, ~6 lignes)

**Quoi** : ajouter dans §4.x (ou §4.8) un tableau de 3 lignes documentant les archetypes
economiques distincts des F :

```
Archetypes reliques F (a documenter AVANT le marchand P1.5c) :
  carrion_ledger (+6 XP)   → archetype "rush-tier" : accelere la vision des hauts rangs ;
                             pertinent si le joueur est en deficit d'XP passive.
  black_summons  (tier+1)  → archetype "spike-mid" : monte un palier a un moment precise ;
                             pertinent uniquement si shopTier < MAX_TIER - 1 (sinon nul).
  beggars_lantern (tier-1) → archetype "max-dup" : concentre les cotes bas pour tripler ;
                             conflict avec l'objectif de montee de tier = DECISION REELLE.
```

Sans cette articulation, la garantie de pertinence pour les F (si elles restent dans le
pool partiellement) ne peut pas etre specifiee correctement (pertinent pour quel critere ?
Le build n'a pas de `runOp_family`). Et les tests `tests/relics.lua` invariant #20
(`runOp ne touche aucune stat de combat`) ne verifient pas la pertinence ECONOMIQUE des F.

**Source** : `relics.lua:64-66` (relu ce round) ; `00-state §4` (economie, boutique XP,
constantes [PH]) ; `competitive/balatro.md §7.3` (shop tension, chaque achat a une strategie).

---

### Prop-D — DOCUMENTER explicitement que les reliques A tier-1 ne contribuent pas a l'identite de run et que c'est un CHOIX ACCEPTE (doc, 2 lignes, P0 ou P1.5a)

**Quoi** : dans §4.11 (hierarchie build-definition) ou dans la spec du nom de build §2.4bis :

```
NOTE : les reliques A (stats plates, tier-1) n'alimentent pas le nom de build (pas de
dot_family). En early (≤wins 2), la majorite des offres contient une A (≥89 % des offres
tier-1, calcul hypergometrique) — ceci est accepte : les A sont des stabilisateurs neutres
d'identite, pas des definisseurs. L'identite de run vient des B/C/D/E. Consequence :
le nom de build (§2.4bis) est generalement un fallback ("ARPENTEUR NAISSANT") jusqu'au
round 2-3 meme avec le seuil progressif. C'est voulu.
```

**Pourquoi** : sans cette note, les tests de qualite de decision et le debug du nom de build
early seront confondus par le fait que les A sont dans le pool — on deduira a tort que le
systeme est defectueux. Documenter que c'est voulu empeche la re-decouverte.

---

## 4. Questions ouvertes

### Q1 — Avec la correction Prop-A (`plague_communion` → dot_family_count ≥ 2), quel est l'impact sur le golden actuel ?

Le scenario golden (`golden.lua:17`, seed 970156547) a un build specifique. Si ce build a
≥ 2 familles DoT distinctes, le flag `plagueAmp` sera desormais ACTIF alors qu'il etait
INACTIF avant (selon si le declenchement etait sur la cible ou absent). Un grep du scenario
golden sur les `dot_family` des unites du build est necessaire avant de coder Prop-A.
L'invariant #5 (golden inchange) impose un rebaseline explicite si Prop-A active le flag.

### Q2 — `hollow_choir` (retrait du pool pool-A, round-08.md §1.2) : avec Prop-A sur `plague_communion`, le pool de reliques C devient-il acceptable ?

Apres le retrait de `hollow_choir` du pool (counter d'un archetype inexistant, regen=1 unite),
les reliques C restantes sont `famines_math` (tall, ≤3 unites) et `feeding_frenzy` (bruiser).
Avec Prop-A, `plague_communion` devient un payoff de build multi-famille — mais `plague_communion`
est tier-4, pas tier-3. Le tier-3 manque un PAYOFF MULTI-FAMILLE accessible en mid. Est-ce que
P1 (types) suffit a remplir ce role (palier-2 = 4 unites meme famille = payoff mid) ou faut-il
une relique C a condition `dot_family_count ≥ 2` ?

### Q3 — `beggars_lantern` (tier-2, decale les cotes -1 tier) : sa garantie de pertinence peut-elle etre definie ?

La garantie de pertinence B/E verifie que la famille de la B est presente sur le plateau.
`beggars_lantern` n'a pas de `dot_family` — c'est une relique de boutique. Sa garantie de
pertinence devrait etre conditionnelle : pertinente si le joueur a ≥ 2 unites de meme id
(cherche les triples) OU ≥ 1 unite rang-1 (veut concentrer les cotes bas). Sans ce critere,
elle peut etre proposee en early a un joueur qui ne cherche pas les triples et n'en tirera
aucun benefice (bruit pour cet archetype).

### Q4 — `second_breath` (chaque unite survit 1× a 1 PV) : est-ce un egalisateur ou un avantage structurel ?

`second_breath` est classe en tier-3 defensif. Si elle s'applique a TOUTE l'equipe, elle
double effectivement la duree de vie de chaque unite — ce qui n't est pas un « egalisateur
de matchup » (equitable pour tous) mais un avantage structurel pour les builds a faibles
PV/hauts DPS (carries fragiles qui survivent juste assez pour declencher un effet). A
verifier : interagit-elle avec `rot` (amputation des PV max) ? Si une unite a `secondBreath`
et que ses PV max ont ete amputes a 1 par `rot`, le second souffle a une duree de vie de
0 — ca creer un contre-jeu elegant mais non documente.

---

## 5. Index des sources

| Affirmation | Source |
|-------------|--------|
| Pick 1 of 3 : decision interesting = orientation distincte | keithburgun.net/pick-1-of-3-is-a-missed-game-design-opportunity |
| Joker = une regle modifiee, pas un passif (+Mult vs Utility) | competitive/balatro.md §5.3 (LocalThunk) |
| StS reliques rares = Dead Branch (emergent), pas boosts plats | competitive/slay-the-spire.md §2.1 |
| Roguelike itemization : luxury vs enabler | wayline.io/blog/roguelike-itemization-balancing-randomness-player-agency |
| Code plague_communion : teamFlag plagueAmp=0.25 | relics.lua:57-58 (relu integrale ce round) |
| Code feeding_frenzy : on_death frenzy_gain | relics.lua:39 (relu ce round) |
| Code reliques E : grant_team teamFlags | relics.lua:51-58 (relu ce round) |
| Code reliques A : bloodstone, carapace, aegis, whetstone | relics.lua:20-22, 43 (relu ce round) |
| Code reliques F : carrion_ledger, black_summons, beggars_lantern | relics.lua:64-66 (relu ce round) |
| on_death broadcast differe hors-reentrance | round-08.md §1.4 (code-verifie synthetiseur) |
| Hierarchie CREATEURS/SHAPERS/COURONNEURS | ROADMAP-draft.md §4.11 |
| Principe #2 : pas de downside | relics-design.md §1 |
| Principe #3 : egaliser le matchup | relics-design.md §1 |
| Trivialite structurelle early (88,6 % calcul) | r08-relics.md §2.1 (hypergeo confirme) |
| Garantie de pertinence B/E | ROADMAP-draft §4.1 |
| `famines_math` tri stable id | round-08.md §1.3 (clos) |
| Reliques F : runOp invariant #20 | 00-state §6 invariant #20 |
| Economie run (constantes, shopTier, XP) | 00-state §4 ; state.lua |
| Balatro General Strategy (scaling conditionnel) | balatrogame.fandom.com/wiki/Guide:General_strategy |
| Backpack Battles : luxury pool bais | round-08.md §4.7 (steam mai 2026) |

---

## 6. Synthese pour le synthetiseur

**3 challenges cles de ce round (lentille reliques) :**

1. **Les reliques E tier-4 sont des amplificateurs camouflés, pas des couronneurs build-
   defining.** Les 4 E (`forked_tongue`, `everburn`, `open_wounds`, `plague_communion`) sont
   des toggles de flags existants (`teamFlags`). Elles modifient une intensite, pas une
   REGLE. Pour etre des COURONNEURS au sens de Burgun/Balatro, elles doivent ouvrir une
   dimension de decision (placement, interaction inter-familles, condition de composition).
   Prop-B propose un critere editorial applicable aux E FUTURES ; Prop-A corrige `plague_communion`
   pour qu'elle satisfasse ce critere (dot_family_count ≥ 2).

2. **`plague_communion` a un bug semantique : elle se declenche sur les afflictions de la
   CIBLE, pas sur la composition du JOUEUR.** Un build mono-famille avec propagation peut
   la declencher ; un build multi-famille restrictif peut ne pas la declencher. L'alignement
   payoff/strategie est rompu. Prop-A corrige en 5 lignes data.

3. **Les reliques A (universelles) ne contribuent pas a l'identite de run — et ca n'est pas
   documente comme un choix delibere.** En early (≥89 % des offres contiennent une A), les
   reliques ne construisent pas d'identite de run. Ce n'est pas forcément un problème si c'est
   assumé — mais le brouillon ne le dit pas explicitement, ce qui laisse ouvert le risque
   qu'un round futur tente de le « corriger » sans comprendre que c'est voulu.

---

*Redige le 2026-06-23 par l'agent adversarial, lentille RELIQUES, round 9/10. Lecture seule
du repo de jeu. N'edite que sous `docs/roadmap-lab/`. Piliers respectes : async snapshots /
sim deterministe seedee / DA grimdark / pixel art procedural. Sources citees par URL ou
fichier+ligne. Documents lus : relics.lua (integrale, relu ligne a ligne ce round) ;
relics-design.md ; 00-state.md ; ROADMAP-draft.md (v9) ; round-08.md (integrale) ;
r08-relics.md (integrale) ; competitive/slay-the-spire.md ; competitive/balatro.md.
Rounds precedents lus : r01 a r08-relics.md, round-01 a round-08.*

Sources web consultees :
- [Pick 1 of 3 Is a Missed Game Design Opportunity — Keith Burgun](http://keithburgun.net/pick-1-of-3-is-a-missed-game-design-opportunity/)
- [Roguelike Itemization: Balancing Randomness and Player Agency — Wayline](https://www.wayline.io/blog/roguelike-itemization-balancing-randomness-player-agency)
- [Balatro Wiki — General Strategy Guide (Fandom)](https://balatrogame.fandom.com/wiki/Guide:General_strategy)
- [Slay the Spire Relics Wiki](https://slaythespire.wiki.gg/wiki/Relics)
