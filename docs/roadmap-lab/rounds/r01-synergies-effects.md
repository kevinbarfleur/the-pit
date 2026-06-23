# Round 01 — Critique adversariale : Lentille synergies-effects

> **Lentille** : synergies d'adjacence et par TYPE, 5 familles DoT, boucliers, auras,
> interactions, hiérarchie poison > tank > choc.
>
> **Statut** : Round 1/10 — attaque directe du brouillon ROADMAP-draft.md v0. Aucun round
> précédent à challenger. Sources web vérifiées le 2026-06-23.
>
> **Garde-fous respectés** : lecture seule du repo ; écriture uniquement sous
> `docs/roadmap-lab/`. Piliers respectés. Ne modifie ni le code, ni les tests.

---

## 0. Position de départ

Le brouillon (§3) traite les synergies par TYPE comme un chantier P1 relativement bien cadré :
les 5 familles DoT deviennent les types, seuils 2/4, `grant_team` existant. Ce qui suit
**conteste 4 points structurels** de cette proposition, **valide 3 autres**, et pose des
**questions ouvertes** non résolues dans le brouillon.

---

## 1. ACCORDS — ce qui tient, avec le pourquoi ancré dans NOS contraintes

### 1.1 Les 5 familles DoT comme types (décision §3.1) — ACCORD FORT

Le brouillon propose que les types d'unités SOIENT les familles mécaniques (burn/bleed/poison/
rot/choc). C'est la bonne décision pour trois raisons qui tiennent spécifiquement à nos contraintes :

**a) Pas de dette taxonomique supplémentaire.** Ajouter une couche « types » orthogonale aux
familles créerait deux systèmes à maintenir et deux compteurs sur l'UI. Le roster est déjà
réparti : burn ~13, bleed ~13, poison ~15, rot ~11, choc 11 (00-state.md §2.1). La distribution
est exploitable telle quelle sans ré-étiqueter les 83 unités.

**b) L'identité de famille EST l'identité de type dans PoE/Last Epoch.** C'est exactement ce
que PoE fait avec Ignite/Bleed/Poison comme identités d'archétype distinctes, chacune avec ses
modificateurs spéciaux. Les ailments PoE sont des types *et* des effets — la même pièce remplit
les deux rôles. Source : [poewiki.net/wiki/Ailment](https://www.poewiki.net/wiki/Ailment).

**c) Compatible avec l'async.** Les synergies de type sont calculées au build, bakées avant le
combat (`grant_team` à `combat_start`, 00-state.md §3). Elles n'exigent aucune information live.
Un snapshot capture les unités avec leurs types sans coût supplémentaire (le type est l'id,
et l'id est déjà dans le snapshot — 00-state.md §5).

**En désaccord partiel sur le 6e type non-DoT** : voir §2.3.

### 1.2 Seuils 2/4 (pas 2/4/6) — ACCORD, mais la justification du brouillon est incomplète

Le brouillon dit « NE PAS copier 2/4/6/8 de TFT calibrés pour 8-28 slots » et propose 2/4
seulement. C'est correct, et la vérification de la distribution TFT actuelle (Set 17 données
MetaBot.gg, tftforge.gg — sources web 2026) confirme que les paliers TFT hauts (6+) supposent
un roster de 6-8 champions du même trait, ce qui sur 9 slots = 67-89 % de la composition. Avec
5 familles et 9 slots max, viser un palier 6 dans une famille = sacrifier 3 slots pour les 4
autres familles → build excessivement contraint, pas de place pour le 6e type structurel.

**Ce que le brouillon ne dit pas** : la vraie raison pour laquelle 2/4 tient, c'est la
**pression de slot** spécifique à notre format. Avec 9 slots max et 5-6 types, un joueur qui
court un seul type sacrifie la diversité défensive (pas de tank, pas de tank/bouclier). Les
seuils 2/4 créent un **optimum de diversité** : un joueur peut tenir 2 types à palier 4
(8 slots) et garder 1 slot pour un joker — ce qui correspond exactement à la structure de compos
saines en autobattler (cf. [gangles.ca autobattler design](https://gangles.ca/2024/07/07/balatro-auto-chess/)).

**Recommandation** : expliciter dans le brouillon que le seuil 6 est interdit *par contrainte de
pression de slot*, pas juste parce que TFT le fait avec 28 hexagones. La justification mécanique
est plus robuste que l'analogie de taille de plateau.

### 1.3 `grant_team` comme vecteur d'implémentation — ACCORD TECHNIQUE

Le brouillon cite `grant_team` (pattern existant, 00-state.md §3, `teamFlags`) comme le mécanisme
d'implémentation des paliers de type. C'est architecturalement correct et bien choisi :

- Déterministe : calculé à `combat_start`, avant tout tick. Compatible golden invariant #5.
- Ouvert/fermé : ajouter un palier de type = +1 flag + 1 condition de count, sans toucher
  la boucle de combat.
- Déjà validé par les transforms T3 existants (ash_maw, pit_maw) qui utilisent `teamFlags`
  avec gating — « tout gated → golden inchangé » (00-state.md §3).

L'implémentation est **gated** donc non-cassante pour le golden, ce qui est la garantie critique
pour travailler en toute sécurité dans un système de test aussi strict.

### 1.4 Contre-argument à Litige #B (double comptage inc%) — ACCORD PARTIEL

Le brouillon soulève lui-même la question (Litige #B §3, p. 10) : les types DoT créent-ils un
double comptage avec les reliques B (amplis d'affliction) et les auras d'adjacence ? La réponse
correcte est : **le double comptage est réel mais borné par le cap ×3 existant**.

Notre couche de modificateurs (`stats.lua`, 00-state.md §3) utilise `increased` additif pour
tous les pourcentages de ce type. Cumuler « type burn +20% » + « relique burn +30% » + « aura
adjacence burn +15% » donne un `increased` total de +65%, pas un `×1.2×1.3×1.15`. La formule
`(base + Σflat)(1 + Σincreased) * Π(more)` contient l'emballement automatiquement tant que les
types restent dans `increased`. Le `DOT_CAP_MULT = 3` (`ops.lua:22`, 00-state.md §3) est un
filet supplémentaire. Le Litige #B est donc techniquement résolu par l'architecture, mais
**les valeurs [PH] doivent être vérifiées** — c'est la vraie question à ne pas oublier.

---

## 2. DESACCORDS — ce qui est faible, manquant ou non étayé, avec recherche sourcée

### 2.1 DESACCORD FORT : La hiérarchie poison > choc est diagnostiquée mais le traitement proposé est superficiel

Le brouillon (§6.1) mentionne la hiérarchie poison > tank > … > choc comme une cible
d'équilibrage pour P3. Il propose le « ladder choc 5/3/2 » (1 seule unité choc aujourd'hui)
comme levier de contenu direct. C'est correct comme direction mais **dangereusement sous-analysé**.

**Le problème structurel du choc, non posé dans le brouillon :**

Le choc dans The Pit est décrit comme « 0 dégât à la pose ; décharge au prochain coup, ignore
bouclier » (00-state.md §3.1). C'est un **condensateur** : l'effet est **différé** et
**conditionnel** (il faut être frappé après la pose). Ce design a un défaut fondamental que
*aucune quantité de contenu (ladder 5/3/2) ne peut corriger seul* :

**Le choc est la seule famille dont le payoff dépend d'un événement qu'on ne contrôle pas.**
Les 4 autres familles DoT font des dégâts au tick, indépendamment du comportement de
l'adversaire. Le choc, lui, ne « paie » que si la cible survit assez longtemps pour être
frappée après la pose, et si c'est cette unité précise qui est frappée. Dans un combat
déterministe où les unités meurent vite (les unités front-column sont ciblées en premier),
une unité choquée peut mourir *avant* que la décharge se produise — le choc devient une
perte sèche d'effet.

Ce mécanisme de « payoff différé conditionnel sur survie » est exactement ce que PoE a
identifié comme problème avec les ailments à « on-hit crit only » (un ailment qui ne se déclenche
que sous condition de crit rend la famille trop volatile et frustrante).
Source : [pathofexile.fandom.com/wiki/Damage_over_time](https://pathofexile.fandom.com/wiki/Damage_over_time)

**Ce que le brouillon aurait dû demander :** avant d'ajouter 11 nouvelles unités choc, il faut
décider si l'axe de design actuel du choc (condensateur différé) est intrinsèquement viable dans
notre format de combat. Une unité qui meurt vite (front-column, aggro faible) ne peut pas
bénéficier de son propre choc accumulé.

**Proposition concrète** : soit (a) corriger l'axe de design pour que le choc soit partiellement
utile même sans décharge (mini-dégâts à la pose, ex : « pose 2 stacks = 0 dégâts, décharge =
bonus × stacks »), soit (b) lier le choc à des unités intrinsèquement arrière/carry (aggro basse)
qui survivent assez pour décharger. L'axe (b) est plus cohérent avec notre ciblage déterministe
car ces unités seront ciblées en *dernier* (profondeur élevée). Le brouillon ne pose pas ce
choix — il l'évite.

**Impact sur la roadmap** : le « ladder choc 5/3/2 » de P3 devrait être précédé d'une décision
d'axe de design (P1 ou P3) qui répond à : « quel est le profil-cible d'une unité choc viable
dans notre ciblage colonne→taunt→aggro ? ». Sans ça, les 11 unités choc seront aussi sous-
optimales que l'unité unique actuelle.

### 2.2 DESACCORD FORT : Le twist de palier 4 par famille n'est pas symmetric — certains sont cassants

Le brouillon propose (§3.2, [PH]) des twists de palier 4 par famille :
- burn 4 = les brûlures se propagent au voisin à la mort (comportement déjà existant)
- poison 4 = +1 stack cap
- bleed 4 = aggravate renforcé
- rot 4 = amputation +X%
- choc 4 = +1 cap condensateur

Ce tableau illustre un problème de **symétrie de puissance entre les twists** qui n'est pas
mentionné dans le brouillon :

**burn 4 et poison 4 sont fondamentalement différents en puissance** :
- burn 4 = twist de *propagation* (scope AoE, touche plusieurs ennemis). C'est un T3-7 (propagation
  en chaîne) au niveau de palier 4 — c'est fort.
- poison 4 = +1 au cap de stacks (de 8 à 9). Sur une famille à 15 unités avec des effets de
  weaken déjà actifs, c'est *marginalement* plus fort mais pas un twist lisible.

La théorie de paliers établie (effects-synergy-tiers.md §3.2, citant MTG NWO et StS archetypes)
exige que les twists de palier soient de **puissance comparable** et **lisibles** (comprehension
haute). Un twist « +1 stack cap » est opaque et trop faible. Un twist « propagation AoE » est
puissant mais potentiellement snowball si mal borné (§1.6 de effects-balance-counterplay.md :
propagation incontrôlée).

Source vérifiée : [magic.wizards.com/en/news/making-magic/quite-rarity-2018-03-12](https://magic.wizards.com/en/news/making-magic/quite-rarity-2018-03-12)
— les effets de palier doivent être lisibles ET puissants de façon comparable pour ne pas créer
une hiérarchie implicite de types (« burn est toujours mieux que poison à palier 4 »).

**Proposition concrète** : pour chaque twist de palier 4, vérifier deux critères :
1. **Lisibilité** : un joueur peut-il comprendre l'effet en ≤ 8 mots (standard Snap, marvel-snap.md §7.3) ?
2. **Puissance comparable** : le sim doit montrer un lift(paire de type, victoire) comparable entre
   familles au même palier (±0.05 max).

**Poison 4 = "+1 stack cap" est une analogie paresseuse avec « on amplifie le nombre ». Le vrai
twist de poison 4 devrait modifier une règle, pas un chiffre.** Proposition : « poison 4 = le
weaken affecte aussi la cadence d'attaque (pas seulement les capacités) » — c'est lisible, c'est
un changement de règle, et c'est cohérent avec l'axe « malus sur la valeur des capacités » déjà
posé (00-state.md §3.1).

### 2.3 DESACCORD MODERE : Le 6e type non-DoT (Carrion/Bulwark) est un fourre-tout mal justifié

Le brouillon (§3.1) propose un 6e type « structurel » pour les tank/bouclier/bruiser, nommé
[PH] « Carrion » ou « Bulwark ». La justification est absente au-delà de « pour les non-DoT ».

**Le problème** : un type défensif fourre-tout (tank + bouclier + bruiser = 3 rôles distincts
dans un seul type) ne crée pas d'identité de build. Les synergies de type fonctionnent
psychologiquement parce qu'elles créent un **objectif intermédiaire lisible** (Progress Principle,
Amabile & Kramer 2011, cité en tft.md §4.3). « J'ai 2 Bulwark, il me faut 2 de plus pour le
palier » n'a de sens que si le joueur comprend **pourquoi mettre 4 Bulwark**. Si le bonus de
palier 4 est « +20% d'armure équipe » pour un mix de tanks + shields + bruisers qui n'ont aucune
synergie interne, c'est un bonus invisible.

**Les 5 familles DoT ont une identité claire** parce que l'effet de famille a un axe unique.
Un type « tank/shield/bruiser » n'a pas d'axe commun autre que « unités défensives ». C'est la
définition d'un type fourre-tout.

**RechercheWeb sur les types fourrre-tout dans TFT** : la post-mortem Set 1 de TFT identifie
explicitement les « traits trop larges » comme une source d'équilibrage impossible — « Blademaster
encompassed too much, any unit with multi-hit was Blademaster ».
Source : [teamfighttactics.leagueoflegends.com/en-us/news/dev/dev-tft-set-1-learnings](https://teamfighttactics.leagueoflegends.com/en-us/news/dev/dev-tft-set-1-learnings/)

**Proposition** : au lieu d'un 6e type « défensif fourre-tout », envisager deux alternatives :
- **Option A** : pas de 6e type en v0.9. 5 types DoT suffisent pour 83 unités (les non-DoT sont
  simplement sans type, comme les « vanilla » de SAP). La complexité est réduite, la lisibilité
  est maintenue.
- **Option B** : si un 6e type est voulu, l'axe doit être *mécanique*, pas *archétypal*. Exemple :
  « Sentinel = unités avec on_attacked triggers (épines, bouclier périodique, riposte) » — l'axe
  commun est le trigger, pas le rôle. Le palier 4 Sentinel = « les triggered effects se
  déclenchent deux fois au 1er coup reçu par combat ». C'est un twist d'axe mécanique, lisible.

### 2.4 DESACCORD MODERE : La proposition de synergies par TYPE ignore le PLACEMENT comme couche de décision différentielle

Le brouillon (§3) construit les synergies de type comme un mécanisme de « build direction
précoce » (« identité de build précoce et lisible »). C'est correct. Mais il ne réalise pas que
**les synergies de type et les synergies d'adjacence ont des couches de décision DIFFERENTES**
qui peuvent ou non se compléter ou se contredire.

Les synergies d'adjacence (voisin buffe voisin) imposent des contraintes de PLACEMENT sur le
plateau-graphe. Les synergies de type imposent des contraintes de COMPOSITION (nombre d'unités
du même type). Ces deux systèmes peuvent entrer en conflit :

- Un joueur voulant maximiser « 4 poison » doit mettre 4 unités poison sur le plateau.
- S'il veut maximiser l'adjacence, il doit mettre les poison T2/T3 adjacents aux poison T1
  (pour le payoff enabler→payoff, effects-synergy-tiers.md §1.2).
- Si ces deux contraintes s'alignent = richesse décisionnelle.
- Si elles se contredisent (4 poison groupés cassent la synergie d'adjacence avec les boucliers)
  = frustration de règles contradictoires.

**Ce problème n'est pas mentionné dans le brouillon.** C'est une lacune, pas une erreur, mais
elle est sérieuse dans un jeu dont la signature est le plateau-graphe avec adjacence.

**Ce que le brouillon aurait dû faire** : au lieu de traiter les synergies par TYPE comme
indépendantes des synergies d'adjacence, les lier explicitement. Proposition : **les bonus de
palier de type ne s'activent que pour les unités du type adjacentes entre elles sur le plateau**
(= un compteur d'adjacence-type, pas un compteur global). Cela crée une tension placement +
composition, au lieu d'une simple composition.

Précédent : dans SAP, les triggers positionnels (« le pet à droite ») et les triggers de type
(une famille de pets comme les Fish) interagissent spatialement — c'est cette interaction qui
crée la profondeur de placement
([a327ex.com/posts/super_auto_pets_mechanics](https://a327ex.com/posts/super_auto_pets_mechanics)).
The Pit a un plateau-graphe beaucoup plus riche : utilisons-le pour les synergies de type, pas
juste pour l'adjacence.

### 2.5 DESACCORD FAIBLE : Le brouillon ne pose pas la question des contre-synergies entre familles

Les 12 contrats de synergie existants (invariants #22-32, 00-state.md §6) couvrent des
interactions *intra-run* (bleed→rot, poison→burn). Mais avec l'ajout de paliers de type, on
crée potentiellement des **counter-synergies inter-type** : une composition 4 burn peut être
contrecarrée par un adversaire avec des unités à anti-propagation-feu (si ce counterplay existe).

Le brouillon ne discute pas des counter-synergies de type comme outil d'équilibrage ou de
profondeur. C'est une lacune à moyen terme (P3), pas critique pour P1, mais à anticiper.
En particulier : si le twist de palier 4 burn = propagation AoE, un adversaire avec des unités
à immunité feu (futur) ou à cleanse périodique peut counter ce palier. Cette interaction devrait
être planifiée, pas découverte après l'implémentation.

Source : effects-balance-counterplay.md §2.6 — règle processus : « aucune famille offensive
n'est mergée sans son contre déterministe dans le même lot ». Cette règle doit s'étendre aux
**paliers de type** : un palier de type qui confère un bonus offensif doit avoir un counter
accessible à l'adversaire.

---

## 3. PROPOSITIONS PRIORISEES

### P1-A : Décision d'axe de design pour le choc AVANT le ladder 5/3/2 [Haute priorité, P1]

**Quoi** : avant de créer 11 nouvelles unités choc, trancher :
- Axe A : choc = « condensateur carry arrière » — les unités choc ont aggro basse et cd long,
  survivent en arrière, déchargent sur les ennemis qui les atteignent en dernier. Le palier 2
  choc = « les stacks choc posés à distance (not_adjacent) ont leur décharge amplifiée ×1.5 ».
- Axe B : choc = refonte mineure — le choc inflige 1 dégât à la pose (pas seulement à la
  décharge), la décharge amplifie ×K. Cela rend le choc viable même si la cible meurt avant.

**Chiffrer via sim** : après décision d'axe, lancer `tools/sim.lua` avec 400+ combats pour
vérifier que le win% choc monte dans `[0.45, 0.55]` (cible équilibrage, 00-state.md §6 et
effects-balance-counterplay.md §3.7). L'axe retenu devient l'identité du ladder 5/3/2.

**Coût** : faible (décision de design data, pas de refonte moteur). Bloque P3 sans bloquer P0.

### P1-B : Twist de palier 4 = « 1 règle modifiée », pas un chiffre [Moyenne priorité, P1]

**Quoi** : pour chaque famille, remplacer les twists purement numériques par des twists qui
modifient une règle (palier de la taxonomie T2-TWIST, effects-synergy-tiers.md §3.1) :
- burn 4 : « les brûlures ne décroissent pas en 1 tour chez les ennemis en front-column »
  → lisible, change une règle, favorise le push front.
- bleed 4 : « aggravate = les dégâts de swing doublent si la cible bleed est aussi rot »
  → interaction inter-famille, lisible.
- poison 4 : « le weaken réduit aussi la cadence d'attaque de −20% » → change un axe.
- rot 4 : « l'amputation s'applique au max HP final (après réduction de niveau) et non au
  HP courant » → change le timing de l'effet.
- choc 4 : conditionnel à la décision §P1-A.

**Chiffrer** : sim lift(type4, victoire) pour chaque famille, alerte si > 0.10.

### P1-C : Synergies de type ancrées dans l'adjacence (pas compteur global) [Haute priorité, P1]

**Quoi** : le compteur de palier de type est calculé sur les **unités adjacentes du même type**
sur le plateau-graphe (via les arêtes du sigil actif), pas sur le total du plateau. Avantages :
- Couple placement et composition (unicité de The Pit).
- Empêche un joueur de bénéficier du palier 4 en dispersant ses unités sans pensée positionnelle.
- Compatible avec les sigils mutables : en changeant de sigil, les arêtes changent → le palier
  de type peut chuter → décision de sigil plus riche.

**Garde-fou invariant** : le calcul d'adjacence-type est build-résolu (même architecture que
les auras d'adjacence, `engine-architecture.md` §6.6) → déterministe, golden-safe si gated.

**Coût** : légèrement plus complexe à implémenter qu'un simple count global, mais l'architecture
d'arêtes explicites est déjà là (`shapes.lua`). Un helper `countAdjacentOfType(board, cell, type)`
sur le graphe d'arêtes suffit.

### P2-A : Audit de symétrie des twists avant implémentation [Moyenne priorité, P2]

**Quoi** : pour les 5-6 twists de palier 4, construire un tableau : lisibilité (≤ 8 mots ?),
type d'effet (règle vs chiffre), puissance relative estimée (faible/moyen/fort), présence
d'un counter disponible. Valider via sim (lift) avant de coder.

**Objectif** : que les 5 familles aient des twists de puissance perçue comparable, mesurée
à la fois par sim (lift proche) et par playtest de lisibilité.

### P3-A : Définir le counter de chaque palier de type en même temps que le palier [P3]

**Quoi** : appliquer la règle de processus d'effects-balance-counterplay.md §2.6 aux paliers de
type. Pour chaque palier offensif (burn 4 = propagation), identifier le counter déterministe
(cleanse AoE, immunité courte, mécanique d'isolement). Le counter n'a pas besoin d'exister en
v0.9, mais il doit être *planifié* dans la spec de la famille.

---

## 4. QUESTIONS OUVERTES (non résolues par ce round)

### Q1 : L'axe de design du choc est-il viable en l'état (condensateur différé) ?

Le brouillon évite cette question. Elle doit être tranchée avant P3. Formulation opérationnelle :
« Dans nos 400 combats de fuzz actuel, quel est le taux de décharge de choc qui se produit *après
la mort de la cible* (= choc gaspillé) ? » Si ce taux > 30%, l'axe est fondamentalement cassé.

### Q2 : Les synergies de type doivent-elles être un compteur d'adjacence ou un compteur global ?

Ce round propose l'adjacence (§2.4, §3.P1-C). Argument inverse : le compteur global est plus
simple à comprendre pour un joueur, l'adjacence ajoute une couche de règle nouvelle. La réponse
dépend de la cible de complexité en P1. À trancher : simple (global) ou riche mais unique
(adjacence-type) ?

### Q3 : Poison 4 — quel twist de règle est lisible ET différent de l'axe weaken existant ?

L'axe weaken (malus sur la valeur des capacités) est déjà l'identité de poison. Le palier 4 doit
aller plus loin sans doubler le même axe. Options : (a) weaken affecte la cadence (cf. §2.2),
(b) poison 4 = les stacks poison ne se réduisent pas au fil du temps sur les unités en back-column,
(c) poison 4 = les stacks poison d'une unité morte sautent sur l'unité la plus proche à sa mort.
Option (c) est la plus forte thématiquement (poison se répand à la mort) mais est un T2-2 (propagation
à la mort, cf. effects-synergy-tiers.md §4.A) — est-ce trop complexe pour un palier de type ?

### Q4 : Le 6e type non-DoT — nécessaire en v0.9 ou différable ?

Ce round suggère de le différer ou de le remplacer par un axe mécanique (Sentinel = on_attacked).
À trancher en round suivant avec une lentille « unités ».

### Q5 : Comment le sim détectera-t-il un déséquilibre de palier de type ?

Les invariants actuels ne couvrent pas les paliers de type (zone sans test, 00-state.md §8). Le
lift(type-à-palier-4, victoire) est la métrique naturelle, mais il faut des compos de test qui
déclenchent les paliers. À spécifier avant d'implémenter.

---

## 5. Synthèse hiérarchisée pour le brouillon

| Critique | Sévérité | Impact roadmap | Action recommandée |
|----------|----------|----------------|--------------------|
| Choc : axe condensateur différé potentiellement cassé | **FORTE** | Bloque P3-ladder | Décider axe design AVANT ladder |
| Twists de palier 4 asymétriques (poison≈chiffre, burn≈règle) | **FORTE** | Déséquilibre perçu | Réviser vers « 1 règle modifiée » par famille |
| 6e type non-DoT = fourre-tout sans axe | **MODÉRÉE** | Lisibilité P1 | Différer ou remplacer par Sentinel (axe trigger) |
| Synergies de type découplées de l'adjacence | **MODÉRÉE** | Profondeur plateau gâchée | Envisager compteur adjacence-type |
| Counter des paliers offensifs non planifié | **FAIBLE** | Risque P3 | Planifier en spec, livrer en P3 |

---

## Index des sources (URLs vérifiées)

- TFT Set 17 trait data 2026 : [tftforge.gg/en/synergies](https://tftforge.gg/en/synergies/) ; [metabot.gg/en/TFT/17/traits/tier](https://metabot.gg/en/TFT/17/traits/tier)
- TFT Set 1 learnings (traits trop larges, unités surchargées) : [teamfighttactics.leagueoflegends.com/en-us/news/dev/dev-tft-set-1-learnings](https://teamfighttactics.leagueoflegends.com/en-us/news/dev/dev-tft-set-1-learnings/)
- PoE ailments (burn/bleed/poison axes distincts) : [pathofexile.fandom.com/wiki/Damage_over_time](https://pathofexile.fandom.com/wiki/Damage_over_time) ; [pathofexile.fandom.com/wiki/Bleeding](https://pathofexile.fandom.com/wiki/Bleeding) ; [poewiki.net/wiki/Ailment](https://www.poewiki.net/wiki/Ailment)
- MTG rareté et comprehension : [magic.wizards.com/en/news/making-magic/quite-rarity-2018-03-12](https://magic.wizards.com/en/news/making-magic/quite-rarity-2018-03-12)
- StS Slay the Spire statuts (Intensity vs Duration) : [slaythespire.wiki.gg/wiki/Debuffs](https://slaythespire.wiki.gg/wiki/Debuffs)
- SAP triggers positionnels et types : [a327ex.com/posts/super_auto_pets_mechanics](https://a327ex.com/posts/super_auto_pets_mechanics)
- Balatro & auto-chess (courbe de valeur, placement) : [gangles.ca/2024/07/07/balatro-auto-chess](https://gangles.ca/2024/07/07/balatro-auto-chess/)
- Autochess snowball design : [gamedeveloper.com/design/autochess-market-status-and-design-analysis](https://www.gamedeveloper.com/design/autochess-market-status-and-design-analysis)
- **Sources internes** : `docs/roadmap-lab/00-state.md` (état canonique, 32 invariants), `docs/research/effects-synergy-tiers.md` (template T1/T2/T3, catalogue patterns), `docs/research/effects-balance-counterplay.md` (bornes, protocole sim), `docs/roadmap-lab/competitive/tft.md` (traits, psychologie Progress Principle), `docs/roadmap-lab/competitive/super-auto-pets.md` (adjacence, types)

---

*Round 01 rédigé le 2026-06-23. Lecture seule du code. N'édite que sous `docs/roadmap-lab/`.
Les propositions P1-A, P1-B, P1-C, P2-A, P3-A sont des orientations de design — leur
implémentation est soumise au vote des rounds suivants. Les 32 invariants de test (00-state.md §6)
ne sont pas modifiés par ce round : les synergies de type n'existent pas encore dans les tests.*
