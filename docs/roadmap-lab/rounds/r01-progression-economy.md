# Round 01 — Critique adversariale : Progression & Économie

> **Lentille** : Progression & économie — shop-XP passif+acheté, reroll, slots, or, courbe de
> leveling, tension monter-vs-reroll-vs-acheter.
>
> **Mandat** : challenge du brouillon ROADMAP-draft.md depuis cette lentille unique. Accords
> argumentés / désaccords sourcés / propositions concrètes, chiffrées, priorisées. Aucune
> modification du code du jeu. Sources citées pour toute affirmation. Respect des 4 piliers et
> des 32 invariants.
>
> Sources primaires consultées : `docs/roadmap-lab/ROADMAP-draft.md` (brouillon v1),
> `docs/roadmap-lab/00-state.md` (état canonique), `docs/research/progression-economy-prd.md`
> (PRD design verrouillé), `docs/roadmap-lab/competitive/super-auto-pets.md`,
> `docs/roadmap-lab/competitive/tft.md`, `docs/roadmap-lab/competitive/hs-battlegrounds.md`,
> `docs/roadmap-lab/competitive/the-bazaar.md`, `docs/roadmap-lab/competitive/balatro.md`,
> `docs/roadmap-lab/competitive/postmortems.md`, `src/run/state.lua` (via seed/mechanics.md).

---

## 0. Diagnostic de lentille (ce que l'économie doit résoudre)

L'économie d'un autobattler à run court n'est pas une courbe de puissance — c'est un **générateur
de décisions sous contrainte resserrée**. Chaque round, le joueur doit arbitrer entre :
- Acheter une unité (dépenser `cost = rank` or) → puissance immédiate
- Reroller (1 or) → chercher la 3e copie ou un meilleur enabler
- Acheter de l'XP (4 or) → accélérer l'accès aux rangs supérieurs
- Accepter/décliner le slot grant → +1 case vs +3 or
- Vendre une unité (0.5× refund) → pivoter le build

Avec `GOLD_PER_ROUND = 10` et `REROLL_COST = 1`, le budget contraint est dur : 3 unités rang-1 =
10 or, 2 unités rang-2 = 8 or, 1 unité rang-3 = 7 or (laisse 3 rerolls). L'arbitrage XP (4 or
= 1 rang-2 sacrifié) est permanent. C'est **le sel de la phase de build** — et le brouillon le
sous-exploite dans ses propositions concrètes.

---

## 1. Accords (avec pourquoi ils tiennent pour nos contraintes)

### 1.1 Or fixe + streaks : oui, mais pour des raisons plus précises que celles citées

Le brouillon retient le modèle SAP (or frais, non reporté) et l'enrichit de streaks
(`STREAK_CAP = 3`). C'est correct. Mais la justification du brouillon est incomplète.

**Pourquoi ça tient vraiment** :

1. L'or fixe/round élimine l'analyse de "combien est-ce que je devrais conserver ?", qui est une
   charge cognitive sans profondeur stratégique dans notre run de ~20 combats. Dans TFT (25+
   rounds), l'accumulation pour l'intérêt crée un axe stratégique viable car le plateau d'or
   bancable atteint 50+ or ; dans notre run court, le plateau maximal serait ~30–35 or cumulables
   sur 3 rounds, soit +3–4g d'intérêt — trop faible pour justifier la spirale de la mort qu'il
   créerait pour les débutants. Les maths ne soutiennent pas le transfert (tft.md §V3).

2. Les streaks ne sont pas "un axe de profondeur supplémentaire" : ils sont un **égalisateur
   d'exposition**. Un joueur qui perd 3 combats consécutifs reçoit +3 or/round — c'est le
   carrousel async de The Pit (tft.md §V6 : l'anti-snowball via redistribution). C'est plus
   important psychologiquement que l'axe économique lui-même.

3. SAP confirme sans equivoque que l'absence d'intérêt n'est PAS une faiblesse mais une décision
   de design qui simplifie la lecture sans sacrifier la profondeur (super-auto-pets.md §2.1 :
   "l'agence dans l'instant, pas dans l'accumulation"). La profondeur économique de SAP passe par
   les pets à capacité économique ; la nôtre passe par les streaks et la décision XP/unité/reroll.

**Accord maintenu** avec une nuance : les streaks méritent d'être **présentés comme l'anti-snowball
principal** dans l'UI (pas seulement comme un bonus d'or), sinon le joueur voit une récompense et
non un filet. La mention de l'or supplémentaire en cas de streak de défaites doit être distincte
visuellement dans le HUD de run.

### 1.2 XP TFT-style (passive + achetable, ratio 1:1) : oui, mais la calibration est fausse

Le brouillon valide le modèle (ROADMAP-draft.md §4, progression-economy-prd.md §3.1). Le
mécanisme est correct : sans XP passive, le joueur qui n'investit jamais reste tier-1 toute la
partie (absurde) ; avec passive, l'achat n'est qu'une accélération.

L'intention de calibrage est saine : passif ≈ tier-3 en fin de partie, rush → tier-5 vers le
milieu (progression-economy-prd.md §3.3). Cette intention est issue du playtest post-HS,
donc ancrée empiriquement — et non juste copiée de TFT sans adaptation.

**Accord maintenu** sur le principe. La calibration reste [PH] à simuler.

### 1.3 Cotes TFT-style (odds-gating, pas slot-gating) : oui, mais incomplet sans pool par unité

Le brouillon valide le gating par distribution (00-state.md §4.3, tft.md §V1). Correct. La
table de cotes est déjà codée (state.lua) et validée design.

**Ce que le brouillon omet** : dans TFT, la rareté est renforcée par le pool partagé inter-joueurs
(tft.md §1.4 : "si 3 joueurs rushent le même champion, les 30 exemplaires s'épuisent"). The Pit
est async — **pas de pool partagé**. La rareté perçue des hauts rangs repose donc uniquement sur
les cotes de la table, sans la pression sociale de contestation. Conséquence : nos cotes tier-5
à 10% au niveau max (00-state.md §4.3) pourraient être **trop généreuses** par rapport à TFT
(qui a en plus la rareté de contestation). C'est un risque de dilution non traité.

**Accord avec nuance** : les cotes tier-5 méritent une simulation de fréquence d'apparition
par run avant de les considérer équilibrées.

### 1.4 `cost = rank` (décision #10) : oui, ancré psychologiquement et designement

Cette décision unifie le prix et la complexité. Elle est correcte pour deux raisons que le
brouillon cite sans les développer assez :

- **Lisibilité** : le joueur comprend immédiatement qu'une unité coûteuse est plus complexe.
  Pas de déchiffrage "ça coûte 3 mais c'est en fait un T2" (anti-pattern TFT avec des coûts
  uniformes par tier).
- **Budget direct** : l'arbitrage "j'achète deux rang-2 (4 or) ou un rang-4 (4 or)" est
  immédiatement visible. C'est une décision à information complète — le type de satisfaction
  de compétence pure qu'Amabile & Kramer (2011) associent à la progression intrinsèque la
  plus forte.

**Accord total.**

### 1.5 Refund à 0.5× : juste, mais la raison psychologique est incomplète dans le brouillon

Le brouillon mentionne "< coût = pas d'exploit" (00-state.md §4.1). C'est nécessaire mais
insuffisant. La vraie raison : **un refund < coût incite au commitment**. Dans SAP, vente L3 =
3 or sur 18 investis (17% de retour) — intentionnellement bas pour punir les pivots tardifs et
valoriser l'engagement (super-auto-pets.md §2.4). Chez nous, 0.5× fait exactement la même chose :
la décision de vendre = accepter une perte. Cela crée une **asymétrie engageante** : il vaut
mieux planter et assumer que de pivoter en payant le coût de la perte.

**Accord total.** La règle est saine.

---

## 2. Désaccords (avec recherche sourcée)

### 2.1 DÉSACCORD MAJEUR — La tension XP/reroll/achat n'est PAS traitée comme le design central

**Le problème** : le brouillon traite l'économie (§P0, §P1, §P3) comme un système à "calibrer via
sim" et à "implémenter" — mais ne fait jamais l'analyse de ce que **la décision d'acheter de l'XP
coûte réellement à chaque round** et si ce coût crée une tension réelle.

**Calcul concret (que le brouillon n'a pas fait)** :

Avec `GOLD_PER_ROUND = 10`, `REROLL_COST = 1`, `BUY_XP_COST = 4` :
- Acheter 1 unité rang-2 + 2 rerolls = 2 + 2 = 4 or restant → soit BUY XP, soit 4 rerolls
- Acheter 1 unité rang-3 + BUY XP = 3 + 4 = 7 or → il reste 3 or pour 3 rerolls
- BUY XP sans rien acheter = 4 or pour 6 rerolls restants

**Le sel** : BUY XP (4 or) = exactement 1 unité rang-4 sacrifiée, ou 4 rerolls sacrifiés. C'est
une tension réelle, calibrée. Mais ce n'est vrai QUE si l'unité rang-4 est déjà dans la boutique
(la probabilité dépend du tier en cours). En tier-1 (100% rang-1 seulement), BUY XP n'a pas de
coût d'opportunité en unités hauts rangs — ce n'est que du reroll sacrifié. La tension XP ne
devient significative qu'en tier-2 ou 3+, quand le sacrifice d'une unité rang-3 ou 4 est réel.

**Conséquence de design non traitée** : en early (tier 1-2), BUY XP est une décision presque
sans coût perçu → le joueur rushe l'XP par défaut → le tier évolue trop vite → la courbe de
révélation progressive est cassée. Le brouillon parle de calibrer via sim mais ne nomme pas
CE risque précisément.

**Source** : le même problème existe dans Slay the Spire 2 où les joueurs en début de partie
achètent toujours la suppression de carte (75 or) en priorité, ce qui collapse la décision en
séquence prédéterminée plutôt qu'en tension réelle (sts2front.com/tips/gold-economy-guide/). La
tension se crée quand TOUTES les options sont attractives, pas quand l'une est clairement
dominante.

**Proposition concrète** (voir §3.1).

### 2.2 DÉSACCORD — Le gel de boutique (freeze) est trop vite écarté

Le brouillon note "À réévaluer après sim hunt" (ROADMAP-draft.md §10, super-auto-pets.md §7.7)
et le range dans les idées "à l'étude" — sans en faire une priorité. Or le gel est directement lié
à l'économie de progression, pas au contenu.

**Pourquoi le freeze est plus urgent que présenté** :

Avec 83 unités dans le pool (00-state.md §2.1), le temps médian pour trouver la 3e copie d'une
unité rang-2 peut s'avérer prohibitif. Calculons : en tier-2 (70% rang-1, 30% rang-2), 5 slots
par boutique → espérance de voir une unité rang-2 spécifique par boutique = 5 × 0.30 / 23 (nombre
d'unités rang-2) = **6.5% par boutique**. Pour 3 copies : ~46 boutiques en espérance (sans reroll),
soit ~9 rounds entiers. C'est une friction de duplication trop haute, même avec 1 reroll/round.

En SAP (super-auto-pets.md §2.3), le pool Turtle T1 = 10 pets, cote unitaire 10% par slot → 3
copies en ~3-4 rerolls. Chez nous sans freeze, le hunt d'une 3e copie peut durer plusieurs runs
entières — ce qui détruit le "one more roll" psychologique.

**Le freeze résout directement ce problème** sans modifier les cotes ni la SIM. C'est une décision
purement UI/run-state, déterministe. Il ne touche aucun des 32 invariants.

**Le brouillon ne réfute pas le freeze mécanistement** — il dit "utile si hunt > 3 rounds", et
le calcul ci-dessus montre que c'est justement le cas avec notre pool uniforme de 83 unités.

**Source de design** : Stardew Valley résout le même problème avec le "catalogue" (accès garantis
aux items vus) ; SAP avec le freeze gratuit ; HS:BG avec le freeze gratuit (hs-battlegrounds.md
§1.1 : "Freeze boutique : gratuit"). Ce n'est pas un mécanisme de luxe, c'est un anti-frustration
fondamental quand le pool est large.

**Contre-argument à anticiper** : "le freeze réduit l'urgence de décision". Réponse : non si le
freeze a un coût en slots de boutique (un item freezé = un slot de boutique sacrifié, comme SAP).
C'est une décision de management réelle, pas un filet sans coût.

**Proposition concrète** (voir §3.2).

### 2.3 DÉSACCORD — La garantie de composition dans l'offre de reliques est mal ciblée

Le brouillon (ROADMAP-draft.md §6.4) propose "garantir qu'au moins 1 des 3 reliques soit de
tier A ou B". L'intention est bonne (pas 3 reliques E/F inutilisables) mais la formulation est
paresseuse.

**Pourquoi la formulation "tier A ou B garanti" rate la cible** :

1. La pertinence d'une relique dépend du **build courant**, pas de son tier. Une relique A (stat
   plate "+15% HP équipe") peut être inutile si le build est un squishie-carry. Une relique E
   (transformative) peut être la meilleure option pour un build poison stacker au tier-4. Le
   "tier" ne prédit pas la pertinence perçue.

2. TFT a appris cette leçon douloureusement : les "dead choices" ne viennent pas des raretés
   basses — ils viennent du **désalignement entre l'offre et le contexte de build** (tft.md §2.2 :
   "deux reliques mid de puissances perçues trop disparates = rupture de confiance", Riot Gizmos
   & Gadgets learnings). HS:BG garantit "au moins 1 trinket coût ≤2" (hs-battlegrounds.md §4.3)
   mais c'est parce que les trinkets bas coût sont TOUJOURS pertinents indépendamment du build.
   Nos reliques A ne le sont pas toujours.

3. La vraie garantie nécessaire est **au moins 1 relique activable par le build actuel**. Ce qui
   implique de connaître le build courant au moment du tirage — ce qui est possible (le plateaux
   et ses types sont connus au moment de l'offre relique).

**Ce qui devrait remplacer** : la contrainte "au moins 1 relique dont le type-cible (affliction
de l'offre) correspond à au moins 1 unité présente sur le plateau". Cette contrainte est
déterministe (le plateau est connu au seed du round), ne touche pas l'invariant #3 (même seed +
wins → même offre) tant qu'elle est appliquée avant le Fisher-Yates, et est plus pertinente
qu'une garantie de tier.

**Proposition concrète** (voir §3.3).

### 2.4 DÉSACCORD MINEUR — Le séquençage P0 (lisibilité) avant P1 (types) est sous-défendu

Le brouillon argue que la lisibilité est "bon marché" et "multiplicateur de tout le reste"
(ROADMAP-draft.md §1). C'est vrai pour les éléments visuels (surlignage d'adjacence, exposition
de sigil), mais le regroupement de l'"audit ≤12 mots" avec ces éléments bon marché est trompeur.

**Le vrai coût différencié** :

- Surlignage d'arêtes d'adjacence (§2.1) = RENDER pur, 0 impact SIM, ~1 jour dev
- Aperçu d'exposition sigil (§2.2) = RENDER pur, ~0.5 jour dev
- Tooltip cotes (§2.3) = lecture de constantes existantes, ~0.5 jour dev
- Écran post-combat "pourquoi" (§2.4) = lecture du bus d'événements + test dédié,
  ~2-3 jours dev incluant tests
- Audit textes ≤12 mots (§2.5) = rédaction/édition pur, ~1-2 jours (sous-estimé si 83 unités ×
  effets multiples + 21 reliques)

Le regroupement P0 cache une dispersion de coût 1→10. La lisibilité "pas chère" ce sont les
items §2.1-2.3 ; les items §2.4-2.5 ont un coût réel. Ça n'invalide pas l'ordre, mais ça change
la granularité d'implémentation : §2.1-2.3 peuvent être un lot unique rapide AVANT même de
commencer P1 ; §2.4-2.5 peuvent être intégrés pendant P1 sans bloquer.

**Ce désaccord est mineur** car il touche le séquençage interne de P0, pas l'ordre P0→P1→P2. La
thèse du brouillon reste défendable.

### 2.5 DÉSACCORD — La grille de score de run (§4.2) est structurellement incomplète

Le brouillon propose une grille : ascension 10-0/10-2 = +3, chute < 4V = -1, etc.
(ROADMAP-draft.md §4.2). Le principe est juste, mais **la grille ignore l'incentive perverse
qu'elle crée sur le comportement de jeu**.

**Le problème de "concéder tôt pour limiter la perte"** :

Si chute <4V = -1 et chute 4-6V = 0/-1, le joueur rationnel avec un mauvais départ peut vouloir
"jeter la run" rapidement (concéder des combats volontairement) pour limiter le delta rating, et
démarrer une nouvelle run. C'est l'exact problème du loss-streak intentionnel de TFT (tft.md
§4.7 : "incitation perverse à perdre pour accumuler des gold loss-streak"). Dans un run complet
où chaque combat dure 30s, il y a une incitation mécanique à ne pas "s'acharner".

**La mécanique de Bazaar pour ce problème** (the-bazaar.md §9.1) : les points ne varient pas
linéairement avec le score de la chute — mais le Bazaar a un volume de runs ~10× supérieur au
nôtre. Avec 2-3 runs/semaine, chaque run compte différemment.

**Solution conceptuelle** : un bonus de "combat fought" pour les chutes — i.e., même une chute
7-5 donne une récompense de persistance (or, fragment de Grimoire, cosmétique). Psychologiquement,
cela transforme "ne vaut pas la peine de finir" en "toujours un intérêt à aller jusqu'au bout"
(analogue au "consolation prize" de Hearthstone en Arena : même en défaite totale, on récupère
une récompense plancher, hs-battlegrounds.md §9.2).

**Proposition concrète** (voir §3.4).

---

## 3. Propositions priorisées (concrètes, chiffrées, ancré sur nos ressources)

### 3.1 P0 — Calibrer le seuil XP actif pour éliminer le "rush XP sans coût d'opportunité" [PRIORITÉ 1]

**Problème** : en tier-1 (boutique 100% rang-1), BUY XP (4 or) n'a pas de coût d'opportunité en
unités hautes — le joueur rush l'XP par défaut. La tension disparaît.

**Proposition** : introduire une **fenêtre de verrouillage XP en early** — les premiers 2 rounds,
BUY XP est désactivé (ou son coût est temporairement X = GOLD_PER_ROUND/2 = 5 or). Passé le
round 3, retour à `BUY_XP_COST = 4`.

**Maths** : avec 5 or pour BUY XP en round 1-2, le joueur doit sacrifier soit 1 achat rang-2 +
reroll (2+1+5 = 8, faisable), soit 5 rerolls (5 or). La tension est réelle dès le début.

**Calibration via sim** : mesurer via `tools/sim.lua` le tier moyen atteint au round 3 par un
joueur qui n'a que l'XP passive vs un joueur qui rush. Si l'écart est > 1 tier, le verrouillage
early est justifié.

**Invariants** : `BUY_XP_COST` est une constante de `state.lua`. Un verrouillage conditionnel sur
le round n'est pas un invariant — il ne touche aucun des 32 garde-fous. Test à ajouter : `tests/run.lua`,
assertion "BUY_XP inaccessible/coûteux rounds 1-2" si l'option verrouillage est retenue.

**Alternative plus simple** : ne pas verrouiller, mais rendre l'XP passive **nulle aux rounds 1-2**
(le joueur reçoit +0 XP passif les 2 premiers rounds, puis +1 à partir du round 3). Cela force
le joueur à DÉCIDER d'investir tôt ou d'attendre — la décision a un coût réel dès le début.

**Coût dev** : changement de constante + 1 condition dans `startRound()`. Trivial.

### 3.2 P0 — Implémenter le gel de boutique (freeze) avec coût en slot [PRIORITÉ 2]

**Quoi** : un item de boutique peut être gelé pour le conserver au prochain round. Un item gelé
occupe un slot de boutique (les 5 slots restent 5 — un gelé + 4 nouveaux). Pas de coût or.

**Pourquoi maintenant** : avec 83 unités et pool uniforme par rang, la probabilité de voir une unité
rang-2 spécifique en 1 reroll est 5 × 0.30 / 23 ≈ 6.5%. En 5 boutiques sans reroll = 28.3% de
chance de voir 1 copie. Pour 3 copies en ~3 rounds sans gel, la probabilité est mathématiquement
< 3%. Le gel est une anti-frustration fondamentale dans notre architecture de pool.

**Architecture** : un champ `frozen = {}` dans l'état de boutique (run_state). Au début du round,
les items gelés occupent leurs slots ; les slots restants sont re-tirés normalement. Déterministe
(les items gelés sont connus au seed du round suivant — ils ne "tirent" pas, ils sont juste
conservés). Aucun invariant touché (le freeze est un état de run, pas de SIM).

**Test à ajouter** : `tests/run.lua`, vérifier que les items gelés persistent correctement entre
rounds et que le comptage de slots est juste (toujours 5 = frozen + nouveaux).

**Coût dev** : état run + affichage build.lua (~1-2 jours). **Priorité haute** car le problème
est structurel (pool de 83).

**Garde-fou** : le freeze ne permet PAS de "stocker des unités pour plusieurs rounds". C'est
différent du "bench" de TFT — une unité non-achetée un round disparaît (peut être gelée AVANT de
disparaître, mais est perdue si non-achetée le round suivant). Cette contrainte préserve la
pression de décision.

### 3.3 P1 — Contrainte de pertinence des offres de reliques (remplace "tier A/B garanti") [PRIORITÉ 2]

**Quoi** : remplacer la garantie "au moins 1 relique tier A ou B" par une contrainte
**contextuelle** : au moins 1 des 3 reliques offertes doit avoir son type-cible (affliction ou
archétype) correspondant à au moins 1 unité sur le plateau courant du joueur.

**Implémentation** : au moment du tirage `rollRelicChoices`, vérifier le plateau actuel
(`run_state.board` ou équivalent). Si aucune des 3 reliques tirées n'est "pertinente" (match de
type), forcer un re-tirage ou substituer la relique la moins pertinente par une tirée dans le
sous-ensemble pertinent.

**Déterminisme** : l'état du plateau est déterministe au moment du tirage (il est connu et figé
pendant le build). La substitution doit être intégrée DANS le Fisher-Yates seedé pour que
l'invariant #3 reste vrai : "même seed + wins → même offre". La mise en oeuvre correcte consiste
à inclure l'état du plateau dans le contexte du seed (ou à post-filtrer de manière déterministe
depuis le même RNG — pas de deuxième tirage séparé).

**Cas dégénéré** : si le plateau est vide (round 1), la contrainte de pertinence ne s'applique pas
et l'offre est entièrement aléatoire. Correct.

**Test à ajouter** : `tests/relics.lua`, assertion "au moins 1 relique offertes match le type
d'au moins 1 unité sur le plateau pour un plateau donné".

**Coût dev** : logique de filtrage dans `rollRelicChoices` (~0.5 jour) + test.

### 3.4 P2 — Bonus "run complétée" (anti-abandon) dans la grille de score ranked [PRIORITÉ 3]

**Quoi** : dans la grille de score de run (ROADMAP-draft.md §4.2), ajouter un bonus fixe
`COMPLETION_BONUS = +1` pour tout run allant jusqu'à sa conclusion naturelle (ascension OU
chute, mais pas abandon). Ce bonus est additionné AVANT le delta rating, et c'est la seule
différence entre "concéder tôt" et "jouer jusqu'au bout".

**Maths avec la grille proposée** :
- Ascension 10-0 : +3 (inchangé)
- Chute 7-9V : +1 + completion_bonus → neutre positif même en chute
- Chute 4-6V : 0 + completion_bonus → légèrement positif
- Chute < 4V : -1 + completion_bonus → neutre ou légèrement négatif

**Psychologie** : ce bonus transforme chaque run abandonné en perte certaine de +1 point.
Il n'existe pas d'incentive à concéder tôt puisque finir la run (même en perdant) rapporte
toujours ce +1. C'est analogue à la récompense "consolation prize" de HS Arena (run complétée
= clé garantie) qui a éliminé les abandons précoces (hs-battlegrounds.md §9.2).

**Implémentation** : flag `run_completed` dans le run-state (déjà proche de `victories` et
`lives` — ajouter 1 boléen). Hors SIM (rating = méta IO comme le Grimoire). Aucun invariant
touché.

**Garde-fou** : le `COMPLETION_BONUS` est un paramètre à calibrer via sim (valeur [PH]). Il doit
être suffisamment faible pour ne pas effacer la pénalité d'une chute catastrophique (< 4V = -1
+ 1 = 0 net), mais suffisamment visible pour décourager l'abandon.

### 3.5 P3 — Simulation priority : mesurer le hunt médian (3e copie) par rang AVANT de figer les cotes [PRIORITÉ 1, pré-requis]

**Quoi** : avant de valider les cotes par tier (00-state.md §4.3, actuellement [PH]), lancer
`tools/sim.lua` pour mesurer le **nombre médian de boutiques** nécessaires pour obtenir 3 copies
d'une unité rang-1, rang-2 et rang-3, sans gel de boutique.

**Seuils de décision** (à calibrer) :
- Hunt médian rang-1 < 3 boutiques → cotes saines pour le rang-1
- Hunt médian rang-2 < 5 boutiques → acceptable (2-3 rounds de build)
- Hunt médian rang-2 > 5 boutiques → cotes rang-2 trop diluées → soit réduire le pool rang-2,
  soit augmenter % rang-2 en tier-2, soit implémenter le freeze (§3.2)

**Pourquoi urgent** : c'est le pré-requis de toute calibration du reste de l'économie. La tension
XP/reroll/achat dépend de la friction de duplication. Si dupliquer prend 10 rounds, le joueur
n'investit pas dans les doublons et la mécanique LEVEL_MULT {1.0, 1.8, 3.0} est morte. Si
dupliquer prend 2 rounds, l'économie est trop prévisible.

**Implémentation** : extension de `tools/sim.lua` — simuler N boutiques d'un tier donné, compter
les rounds jusqu'à atteindre 3 copies d'un id spécifique (tirage par rang et tier). Résultat :
distribution de "rounds to L2/L3" par rang et tier. Déterministe (seeds fixés).

---

## 4. Questions ouvertes (à trancher en rounds suivants)

### Q1 — La tension XP est-elle perceptible dès le tier-2 sans fenêtre early verrouillée ?

**Hypothèse à tester** : si `BUY_XP_COST = 4` crée une vraie décision coûteuse en tier-2 (car
4 or = 1 unité rang-2 sacrifiée, mais le rang-2 est maintenant utile à 30%), le verrouillage
early (§3.1) est superflu. Si au contraire les simulations montrent que les joueurs rushent l'XP
sans pression en rounds 1-2, le verrouillage est nécessaire.

**Outil** : `tools/sim.lua` (politiques d'achat comparées : "toujours acheter XP dès que
possible" vs "XP seulement quand pas d'unité utile" → win rate + tier moyen à round N).

### Q2 — Le pool de 83 unités est-il trop large pour un système d'économie sans pity/drought-protection ?

**Hypothèse** : avec 83 unités et pool uniforme par rang, le hunt de la 3e copie est trop long
sans mécanisme de protection (freeze ou pity). Le seuil critique est 5 boutiques en médiane pour
un rang-2.

**Outil** : simulation §3.5. Si le résultat est > 5, ajouter le freeze (§3.2) ou réduire le pool
rang-2 (BRIEF.md §Contenu : "Un run avec 20 unités intéressantes > un run avec 83 plates").

### Q3 — Comment éviter que `shop_tier_up` (relique F) ne casse la courbe de progression XP ?

La relique `shop_tier_up` (progression-economy-prd.md §3.4) saute immédiatement un tier. Si le
joueur est en tier-2 et obtient cette relique au round 2, il saute en tier-3 avant même que la
tension XP ne soit établie. Cela peut rendre le système XP caduque pour certains runs.

**Options** : (a) interdire `shop_tier_up` avant le round 4 (déjà partiellement proposé dans
le PRD : "jamais offerte sur les ~2 premiers combats") — à vérifier si la fenêtre est
suffisante ; (b) rendre `shop_tier_up` un changement d'XP (remplir la barre du tier courant
instantanément) plutôt qu'un saut de tier — préserve la sensation de progression.

### Q4 — Le slot grant (déclin = +3 or) crée-t-il une incitation perverse à refuser des cases ?

`SLOT_DECLINE_GOLD = 3` (00-state.md §4.1) — refuser un slot octroie 3 or. Avec `GOLD_PER_ROUND = 10`,
un refus = +30% de budget. Si refuser des cases est optimal économiquement (car 3 or = 3 rerolls),
le joueur rationnel refusera les cases jusqu'au round où en avoir plus est nécessaire, ce qui
contredit l'intention des grants timés ("débloquer progressivement le plateau").

**À simuler** : quel est le taux optimal de refus de slots par position de run (rounds 2-7) ?
Si > 50% des refus sont optimaux, le montant `SLOT_DECLINE_GOLD` est trop élevé.

### Q5 — La grille de score ranked doit-elle intégrer le tier-de-boutique atteint comme métrique ?

Un joueur qui ascende avec tier-5 actif a investi dans la progression — son run était "de haute
qualité" au-delà du seul résultat. Un bonus de `tier_reached × multiplier_faible` dans le score
pourrait encourager la diversité de stratégie (rush vs buildup lent). Mais cela crée de la
complexité perceptuelle pour le joueur ("pourquoi ai-je gagné moins de points que lui ?").

**À trancher** : si le score ranked est visible, il doit être intuitif. La complexité cachée
(MMR) est OK, mais la formule affichée doit tenir en 1 ligne.

---

## 5. Verdict de challenge (résumé)

Le brouillon pose les bonnes fondations économiques (or frais, XP TFT-style, odds-gating,
cost=rank, streaks comme anti-snowball) et démonte correctement les analogies paresseuses
(intérêt/banque, Backpack 2D, etc.). Ses deux lacunes principales sont :

1. **La tension XP/reroll/achat n'est pas analysée round par round** — le risque de rush XP sans
   coût d'opportunité en early existe et n'est pas traité.
2. **Le freeze de boutique est sous-estimé** — avec 83 unités dans le pool, c'est une
   anti-frustration structurelle, pas une feature optionnelle de V2.

Les propositions §3.1-3.5 sont toutes des ajustements à l'intérieur du cadre existant — aucune
ne remet en cause les décisions définitives ni ne viole les 32 invariants.

---

## Sources

- `docs/roadmap-lab/00-state.md` §4 (constantes éco, cotes, boucle)
- `docs/roadmap-lab/ROADMAP-draft.md` §1-6 (brouillon v1)
- `docs/research/progression-economy-prd.md` §2-3 (PRD verrouillé, XP TFT-style)
- `docs/roadmap-lab/competitive/super-auto-pets.md` §2.1, §2.3, §2.4, §7.4, §7.7
- `docs/roadmap-lab/competitive/tft.md` §1.3, §V2, §V3, §2.2, §4.2, §4.7
- `docs/roadmap-lab/competitive/hs-battlegrounds.md` §1.1-1.3, §4.3, §9.2
- `docs/roadmap-lab/competitive/the-bazaar.md` §9.1
- `docs/roadmap-lab/competitive/balatro.md` §0, §5
- `docs/roadmap-lab/competitive/postmortems.md` §5 (9 lois)
- [Super Auto Pets Wiki — The Basics](https://superautopets.wiki.gg/wiki/The_Basics) (or frais 10/round, freeze SAP)
- [Super Auto Pets — twoaveragegamers.com](https://www.twoaveragegamers.com/ultimate-guide-to-super-auto-pets-game-mechanics/) (maths de fusion, cotes, coûts)
- [TFT Ninja — Leveling](https://tft.ninja/guides/game-mechanics/leveling) (XP 2/round passif, 4g=4XP)
- [op.gg TFT gold-xp](https://op.gg/tft/game-guide/gold-xp) (intérêt, XP passive)
- [Slay the Spire 2 gold economy — sts2front.com](https://sts2front.com/tips/gold-economy-guide/) (décision shop = séquence prédéterminée si une option domine)
- [TFT Economy Mastery — boosteria.org](https://boosteria.org/guides/tft-economy-mastery) (tension level vs roll vs buy)
- [Riot GDC — Gizmos & Gadgets Learnings](https://teamfighttactics.leagueoflegends.com/en-us/news/dev/dev-teamfight-tactics-gizmos-gadgets-learnings/) (dead choices, Heart Augment)
- [Amabile & Kramer 2011 — The Progress Principle](https://hbr.org/2011/05/the-power-of-small-wins) (Progress Principle, objectifs intermédiaires)

---

*Rédigé 2026-06-23. Lentille : progression-economy. Lecture seule du repo de jeu.
N'édite que sous `docs/roadmap-lab/`. Piliers respectés. 32 invariants non modifiés.*
