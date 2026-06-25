# Psychologie du « god-roll » & méthodologie de simulation par scénarios — The Pit

> **Statut** : RECHERCHE (zéro code). Document de cadrage pour la **Phase C** (équilibrage) de
> `effects-overhaul-spec.md`. Ancré dans CE jeu : autobattler async grimdark, plateau-graphe 3×3,
> combat à cooldowns **déterministe + RNG seedé** (`combat-model-decision.md`), reliques **1-parmi-3 /
> lisibles** (`relics-design.md`), duplicatas **3→niveau**, auras de **commandement** (`command-auras-rollout-spec.md`),
> **murmures** (`murmures-plan.md`).
>
> **Ne réinvente PAS** le banc d'essai déjà documenté (`balance-sim-design.md` : Proving Ground +
> `runsim.lua` politiques/personas + `compcost.lua` modèle d'investissement + matrice de counters) ni
> l'outil `tools/sim.lua` (lift de co-occurrence + σ-flags + murmures). Ce doc **complète** : (Axe 1) la
> *philosophie* du god-roll que ces outils doivent SERVIR ; (Axe 2) le passage de « combats isolés » à
> « **scénarios de joueurs** » (arbres de possibilités sur les strates de theory-craft).
>
> **Hypothèses tranchées** (signalées) listées en §0.

---

## 0. Hypothèses tranchées (signalées d'emblée)

- **H1.** Le banc d'essai cible (`runsim.lua` + `compcost.lua` + Proving Ground + MCP) est le *futur* du
  projet ; `tools/sim.lua` est l'*existant* committé. Je formule les recommandations Axe 2 comme une
  **extension de `tools/sim.lua` VERS** l'architecture de `balance-sim-design.md`, pas une 3e voie.
- **H2.** « God-roll » = le **haut de la queue droite** de la distribution de puissance d'une run, PAS un
  état permanent. On le veut **rare (~queue 95-99e pct), atteignable, et borné par les caps moteur**
  existants (`MULTICAST_MAX=3`, `POISON_STACK_CAP`, `WEAKEN_CAP=0.40`, additif-sur-base). Le god-roll
  n'est pas un bug d'équilibrage : c'est une **cible de design mesurable**.
- **H3.** Les chiffres de seuils (N de sims, bandes σ, percentiles cibles) sont des **placeholders de
  départ** justifiés par les sources ; à recalibrer sur le bruit réel des premiers batches.
- **H4.** Le déterminisme du combat (seed) rend chaque scénario **rejouable** : un god-roll détecté est
  **reproductible** (seed loggée) → on peut l'inspecter au ralenti (Chronicle, `combat-chronicle-spec.md`)
  au lieu de le deviner. C'est un avantage rare que la méthodo doit exploiter.

---

# AXE 1 — Psychologie du god-roll : le fantasme qui fait relancer

## 1.1 La thèse de l'user est juste, et la science la valide

Citation user : *« quand les étoiles s'alignent, le joueur peut créer des compos complètement broken — et
c'est BIEN que ça arrive… c'est le fantasme que ça PEUT arriver qui fait relancer. »* Trois corpus
convergents le confirment :

**(a) Le roguelite REND le broken légitime — parce qu'il est temporaire.** L'argument central de l'analyse
TheGamer sur Balatro/Hades : un jeu linéaire *« a besoin de checks permanents contre le fait que tu
deviennes trop fort, sinon il perd son défi »* ; le roguelite, lui, peut **accorder des pouvoirs absurdes
en sachant qu'ils se réinitialisent à la mort**. *« Because no ability will carry on beyond a run, you're
free to build something completely broken. »* La temporalité **augmente** la valeur perçue du pic : savoir
que *« tôt ou tard, la run finira et tu repartiras de zéro »* rend la puissance extrême plus précieuse, pas
moins. **The Pit coche déjà la case** : mort par-combat + identité protégée au RUN (5 vies / 10 victoires),
zéro carry-over de puissance entre runs. Le god-roll y est donc **mécaniquement sûr**.

**(b) La rareté EST le plaisir (near-miss).** Le même auteur décrit un combo Balatro à *« one in a million
odds, two pairs of Jokers combining out of 150 options »* — et c'est précisément la rareté qui rend
l'instant mémorable. Côté neuro, le **near-miss** (Clark et al., Cambridge 2009) active le **ventral
striatum** — le même centre de récompense dopaminergique qu'une *vraie* victoire — alors même qu'on a
*perdu*. Conséquence mesurée : les near-miss sont *« plus aversifs MAIS plus motivants que les gains »*,
ils **augmentent la persistance de jeu**. Traduction The Pit : **voir le god-roll possible mais ne pas
l'atteindre cette run doit être presque aussi motivant que l'atteindre.** D'où l'impératif de
**télégraphe** (§1.4) : le joueur doit *voir* la pièce manquante (« il me fallait juste 1 multicast de
plus sur la sorcière »).

**(c) Le pic assumé > le plafond dur.** Balatro *« ne plafonne pas la puissance du joueur ; il laisse les
scores exploser dans les millions »* et fait **monter la cible de difficulté en parallèle** : la tension
vient d'une *courbe plus dure*, pas d'un *plafond*. C'est le principe directeur pour The Pit : **on ne
nerfe pas le god-roll, on monte l'adversité** (escalade d'adversaire/round, déjà en place).

> **Garde-fou de cadrage.** Ces ressorts sont *les mêmes* que ceux des machines à sous. The Pit est
> grimdark, pas un casino : on emprunte la **structure de récompense** (rareté + near-miss + power
> fantasy borné), PAS le pay-to-spin ni l'exploitation. La RNG vit **dans la construction** (shop, offre
> de reliques), JAMAIS dans la résolution du combat (déterministe) — règle d'or déjà actée
> (`gd-research-result.md §1.1`). Le « presque » porte sur *« ai-je tiré les bonnes pièces »*, pas sur
> *« le dé a-t-il roulé en ma faveur en combat »*. C'est l'inverse de Mechabellum (« the RNG dictates
> games »), et c'est ce qui rend le god-roll **mérité**.

## 1.2 Étager la puissance : rien de trop fort tôt, des pics rares en fin de run

Le danger symétrique du god-roll, c'est le **god-roll TROP TÔT** (snowball précoce = run décidée au tour 2,
les 8 combats restants sont une formalité = ennui). La courbe doit ressembler à :

```
puissance
 ^                                          ___ god-roll (queue 95-99e pct, fin de run)
 |                                      ___/
 |                              ___/  ← pic « normal » d'une bonne run (médiane qui monte)
 |                      ___/
 |              ___/  ← early : petits nombres, builds lisibles, peu de variance verticale
 |      ___/
 +----------------------------------------------------------> avancée (victoires / niveau / tier)
   1   2   3   4   5   6   7   8   9   10
```

Leviers concrets, **tous déjà dans le moteur ou actés**, pour produire CETTE courbe :

| Levier | Mécanisme | Effet sur la courbe | Source |
|---|---|---|---|
| **Tiers d'unités** | BAS (rank 1, stat-stick) → HAUT (rank 5, réécrit une règle) | le « réécrit une règle » (multicast, grant_team, transform) n'est **achetable que tard** (cotes de shop par niveau, à venir) | `effects-overhaul-spec.md §4` |
| **Classe multiplicative tardive** | multicast (×N entier), empower/vuln (`increased`) | additif tôt (chips), multiplicatif tard (mult) = arc Balatro | `effects-overhaul-spec.md §2.1-2.2` |
| **Reliques HAUT bornées tôt** | `maxRelicTier` OFF les 2-3 premiers combats ; canal-3 garantit 1 relique de palier sup. à la 3e/6e victoire | pas de game-changer au combat 1 ; pic de puissance **calé en fin** | `effects-overhaul-spec.md §5.3` |
| **Duplicatas 3→niveau** | stats ET auras scalent `{1,1.8,3}` | le triple-up d'un carry + ses auras = pic **construit, pas tiré** | `CLAUDE.md` (v0.8) |
| **Cap dur sur les enablers** | `MULTICAST_MAX=3`, `WEAKEN_CAP`, `POISON_STACK_CAP=8`, amplis en `increased` additif sur la BASE | le god-roll est **fort mais fini** : pas de boucle infinie (anti-Balatro-infini, qui en compétitif async serait toxique) | `effects-overhaul-spec.md §2.0` |

**Règle d'étagement (gravée).** *La puissance d'un effet ∝ la profondeur de run à laquelle on peut
l'obtenir.* Un effet « réécrit une règle » qui serait accessible au combat 1 = god-roll précoce =
**anti-pattern n°1**. Le détecteur sim associé : un **win-rate contextualisé par investissement** qui
serait élevé à **faible investissement** (§2.5).

## 1.3 Blow-out games assumés vs variance frustrante

Un autobattler N'EST PAS sain quand tous les combats sont serrés. Le but du genre — citation user — *« c'est
d'atomiser l'adversaire »*. Le **blow-out** (écrasement) est une **récompense légitime de la maîtrise**
(`balance-sim-design.md §1`). Distinguer **variance saine** de **variance frustrante** :

| | Variance SAINE (à préserver) | Variance FRUSTRANTE (à corriger) |
|---|---|---|
| **Source** | construction (shop, offre de reliques, placement) | résolution (dé en combat, ciblage aléatoire) |
| **Agency** | le joueur a *choisi* (a gardé X, a placé Y au centre) | le joueur subit (le dé a roulé) |
| **Lisibilité** | il sait *pourquoi* il a gagné/perdu (combo télégraphié) | « j'ai perdu et je sais pas pourquoi » |
| **Réparabilité** | un meilleur jeu aurait changé l'issue (skill) | aucun jeu n'aurait changé l'issue (pur hasard) |
| **The Pit** | RNG de shop/offre + skill de placement → **OK, c'est le jeu** | interdite par design : combat déterministe seedé |

**Le blow-out est sain SSI il est mérité ET télégraphié.** Un joueur écrasé doit pouvoir lire *« l'adversaire
avait empilé 3 enablers sur un carry au centre, moi j'avais un tas »* — pas *« j'ai perdu, mystère »*. D'où
le couplage **god-roll ↔ Chronicle** (`combat-chronicle-spec.md`) : le perdant peut **rejouer le combat au
ralenti** (déterministe) et *comprendre* le combo qui l'a atomisé → ce qui transforme une défaite en
**motivation de re-run** (« je veux CE build »). C'est la conversion near-miss → relance, version The Pit.

> **Garde-fou async.** En multi async, le god-roll d'un joueur devient le **ghost** d'un autre. Si un
> god-roll snapshot écrase systématiquement à un palier donné, c'est un **outlier de matchmaking**, pas un
> god-roll sain. Le matchmaking par **palier d'investissement** (pas par victoires — leçon SAP,
> `gd-research-result.md §1.7`) limite ça : un ghost god-roll de fin de run n'est servi qu'à des joueurs de
> fin de run (investissement comparable). **À surveiller en sim** : distribution de win-rate des ghosts
> par tier (§2.6).

## 1.4 Le fantasme de build : lisibilité, télégraphe, « je vois ce que je voudrais toucher »

C'est le **moteur de relance n°1** et il est *séparable* de la puissance. Le joueur ne relance pas pour
re-subir du hasard ; il relance parce qu'il a **entrevu un build** qu'il veut réaliser. Principes (Slay the
Spire / Balatro / TFT) :

1. **Synergies explosives MAIS lisibles.** Référence deckbuilder : les synergies doivent être *« à la fois
   explosives et légibles »* — on construit autour d'un axe *« sans que l'ensemble devienne illisible »*.
   The Pit l'a déjà : adjacence positionnelle surlignée (voisins éclairés), reliques **lisibles** (nom +
   effet chiffré + flavor), tiers où *« le bas est grok-able, le haut réécrit une règle »*.
2. **Télégraphier la pièce manquante.** Le near-miss ne motive que si le joueur **voit** ce qui lui
   manquait. Concrètement pour The Pit :
   - **Offre 1-parmi-3** (reliques tous les 3 combats) : le joueur voit 3 futurs possibles → *« si je
     prends la Couronne d'Échos, ma sorcière devient un carry »*. Les 2 non-pris sont des near-miss
     visibles.
   - **Survol de carry → portée des auras éclairée** (`command-auras-rollout-spec.md`, déjà spécifié) :
     le joueur *voit* « cette case capte le multicast-aura + l'empower-aura » avant d'acheter.
   - **Chronicle / Journal** : nomme les unités qui se sont buffées (« par la présence de Y, X a été
     renforcé ») → le joueur **apprend la grammaire des combos** par observation.
3. **Le build-around dopaminergique (Balatro).** Le cœur émotionnel = trouver une **pièce qui multiplie
   tout** (le « mult » de Balatro) et organiser la run autour. The Pit l'instancie via les **enablers
   agnostiques** (multicast/empower/vuln) : *« empile les enablers sur 1-2 carries »* est LE dilemme visé
   (`effects-overhaul-spec.md §3`). Le fantasme = *« je vais trouver le 2e enabler et ma sorcière atomise
   tout »*.
4. **Murmures = fantasme caché (long terme).** Les murmures (`murmures-plan.md`) ajoutent une couche
   *« et si il y avait MÊME un secret »* — cryptique jusque dans le log. Plafonné spice (~10%), jamais
   build-defining : ils nourrissent le fantasme **sans** créer un god-roll caché obligatoire. (Détecteur
   sim déjà présent : aucun porteur de murmure ne doit être outlier >2σ — `tools/sim.lua`.)

## 1.5 Garde-fous anti-frustration (floors, comeback, protection d'identité)

Le god-roll fantasme n'a de valeur que si **perdre n'est pas une spirale de mort** (sinon le joueur quitte
avant d'avoir entrevu un build). Filets, tous actés/présents :

| Garde-fou | Mécanisme | État | Source |
|---|---|---|---|
| **Floor de run** | 5 vies / 10 victoires ; +1 vie au tour 3 si perte précoce | codé (v0.5) | `gd-research-result.md §1.7` |
| **Streaks de défaite payantes** | série de défaites → or (rattrapage éco) | codé (placeholder) | `CLAUDE.md` |
| **Identité protégée au RUN, pas au combat** | les unités meurent par combat, le BUILD persiste | acté | `combat-model-decision.md` |
| **Reliques = égalisateur, jamais gate** | team-wide, intra-combat, **aucune ne handicape la suite** | acté (pilier #2) | `relics-design.md` |
| **Decline→+or** | refuser une relique non-matchée = or (la malchance d'offre devient ressource) | codé | `effects-overhaul-spec.md §5.3` |
| **Comeback télégraphié** | le joueur qui perd voit l'offre 1-parmi-3 qui PEUT renverser (le « champion qui sauve ») | par design | §1.4 |

> **Anti-pattern (gravé).** Pas de **boucle de rétroaction négative** : un joueur malchanceux tôt ne doit
> pas être condamné (leçon Slay the Spire/SAP, `gd-research-result.md §1.9`). Le **comeback tardif**
> (perdre 2-3 combats puis trouver la relique/commandant qui renverse) est un **scénario à simuler
> explicitement** (§2.4-C), car c'est un pic émotionnel majeur — et un risque d'équilibrage (si le
> comeback est *trop* fiable, le early-game ne compte plus ; s'il est impossible, la frustration tue la
> run).

---

# AXE 2 — Méthodologie de simulation : de « combats isolés » à « scénarios de joueurs »

## 2.1 Le constat : `tools/sim.lua` mesure des COMBATS, pas des RUNS ni des god-rolls

`tools/sim.lua` (existant) tire **2 builds aléatoires symétriques** et agrège win-rate/unité, dégâts/cause,
TTK p10/p50/p90, **lift de co-occurrence** (détecteur de combos), **σ-flags** (outliers du champ),
murmures. C'est un **excellent détecteur de combos cassés au niveau COMBAT**, mais il a **trois angles
morts** par rapport aux Axes ci-dessus :

1. **Pas de notion d'investissement** : un build à 9 unités niveau 3 + reliques affronte un build à 3
   unités niveau 1. Le win-rate brut est alors trompeur (cf. `balance-sim-design.md §1` : *« le win% brut
   ne vaut rien seul »*). `compcost.lua` résout ça — il faut le **brancher dans le détecteur de god-roll**.
2. **Pas de strates de theory-craft** : `sim.lua` ne modélise ni le **placement** (compos quasi-aléatoires),
   ni les **reliques** (sauf le scénario C6 hardcodé), ni le **commandement**, ni les **murmures** comme
   *axes échantillonnés*. Il ne peut donc pas répondre *« quels god-rolls existent et à quelle fréquence »*.
3. **Pas de scénarios joueurs** : il ne simule pas l'**arc d'une run** (early compatible → progression →
   relique qui matche/qui ne matche pas → comeback). Or c'est *là* que vit le fantasme.

`balance-sim-design.md` (cible) comble (1) et amorce (3) via **politiques/personas** + **matrice de
counters**. **Ce doc spécifie comment combler (2)** : l'échantillonnage des **strates de theory-craft** —
le « god-roll explorer ».

## 2.2 Les strates de theory-craft de The Pit (l'espace à échantillonner)

Un « scénario joueur » de The Pit = un point dans le **produit cartésien** de ces strates. C'est l'arbre de
possibilités à explorer :

| Strate | Cardinalité (ordre de grandeur) | Couplage |
|---|---|---|
| **Roster posé** (quelles unités, 2-9 slots) | ~83 unités, combinaisons énormes | porte les effets |
| **Niveaux** (duplicatas 1/2/3 par unité) | ×3 par slot | scale stats + auras |
| **Sigil / topologie** (5 formes) | 5 | définit l'adjacence ET le front |
| **Placement** (quelle unité sur quel nœud) | 9! au pire, mais l'adjacence réduit l'utile | active/désactive les auras |
| **Reliques** (offre 1-parmi-3, ~8/run, 3 paliers) | pool ~18+, ordre compte | égalisateurs / game-changers |
| **Commandant** (1 slot hors-graphe, aura) | ~6 | multiplie le board selon le rôle ciblé |
| **Murmures** (couche cachée, présence/adjacence) | ~6, conditionnels | spice, jamais build-defining |

**Explosion combinatoire** : le produit brut est astronomique (≫10^12). On **NE l'énumère PAS**. On
**échantillonne intelligemment** (§2.3).

## 2.3 Échantillonner l'espace sans explosion — 4 techniques (sourcées)

> Principe : on ne cherche pas la *vérité exhaustive*, on cherche **(a) la distribution de puissance**
> (pour situer le god-roll dans la queue) et **(b) les outliers** (combos cassés). Les deux se font par
> **échantillonnage**, pas par énumération.

**(1) Sampling stratifié par ARCHÉTYPE DE POLITIQUE (le socle).** Au lieu de tirer des builds uniformément
(ce que fait `sim.lua` → majorité de builds incohérents, peu informatifs), on tire des builds **générés par
une politique de jeu** cohérente. `balance-sim-design.md §6` a déjà la taxonomie : `greedy_stats`,
`econ_streak`, `force_level_fast`, `committed_archetype(a, sigil)`, `random_baseline`. **Chaque politique
est une strate** ; on garantit un budget de sims par strate (stratification). Cela concentre le calcul sur
des builds **que de vrais joueurs produiraient**. (Méthode validée : les autobalancers académiques
utilisent des **agents-politiques comme proxy de joueurs rationnels** — MCTS dans *Metagame Autobalancing*,
agents scriptés/RL dans le balancing par simulation.)

**(2) Importance sampling vers les RÉGIONS À RISQUE (le god-roll explorer).** On **sur-échantillonne** les
combinaisons théoriquement explosives (les « candidats prometteurs ») et on **sous-échantillonne** le bruit.
C'est exactement la stratégie de **RuleSmith** (Bayesian optimization + *acquisition-based adaptive
sampling*) : *« les candidats prometteurs reçoivent plus de parties d'évaluation pour une estimation
précise, les candidats exploratoires en reçoivent moins pour une exploration efficace. »* Pour The Pit, les
régions à risque = **les intersections d'enablers** :
- multicast-aura **×** un carry au front **×** empower-aura sur le même nœud (le combo §6.3 de la spec) ;
- Couronne d'Échos **×** echo_crown (relique) **×** hookjaw (unité) = 3 sources de +1 multicast sur le même
  carry (le test C6 *déjà* dans `sim.lua` — c'est le germe du god-roll explorer, à généraliser) ;
- vuln-on-hit **×** multicast (chaque sous-coup re-applique la marque) ;
- toute paire à **lift élevé** détectée par `sim.lua` → promue en région à sur-échantillonner.

**(3) Réduction par INVARIANCE de sigil.** Le placement est la strate la plus coûteuse (9!). Mais les auras
de commandement et les rôles sont **sigil-invariants** (résolus par rôle géométrique : `role:front/center/…`,
`effects-overhaul-spec.md §6.2.1`). On n'échantillonne donc pas 9! placements : on échantillonne les
**placements canoniques** (carry sur chaque type de nœud : centre-4-voisins / front / isolé) × les 5 sigils.
Cela ramène la strate placement à **~15-20 configurations utiles** au lieu de 9!.

**(4) Couverture par PAIRES (combinatorial / pairwise testing).** Pour les strates discrètes (sigil ×
relique-palier × commandant × archétype), au lieu du produit complet, garantir que **chaque PAIRE de
valeurs** apparaît au moins une fois (pairwise) attrape la grande majorité des interactions à 2 facteurs
(qui sont la source des combos cassés) avec un nombre de cas **logarithmique** vs le produit. Le **lift de
co-occurrence** de `sim.lua` est déjà un détecteur d'interactions à 2 facteurs : la couverture pairwise
**garantit qu'on le nourrit** sur toutes les paires structurantes.

## 2.4 Les scénarios joueurs à simuler EXPLICITEMENT (ce que l'user veut)

Au-delà des distributions, **5 scénarios narratifs** doivent être des **tests sim nommés** (chacun = une
politique + une condition de victoire + une métrique de santé). Ce sont les arcs émotionnels de l'Axe 1,
rendus mesurables :

**A — Early-game à synergies compatibles (la promesse de build).**
*Setup* : politique `committed_archetype(a)` aux niveaux 1-3 (board 3-5 slots), 2-3 unités de la même
famille/thème, sigil par défaut (carré). *Question* : un début **cohérent** bat-il un début **incohérent**
(`random_baseline` à investissement égal) ? *Métrique de santé* : win-rate de la compo cohérente vs
incohérente à **investissement égal** doit être **> 50% mais pas écrasant** (la cohérence early récompense
sans décider la run). *Alerte* : > ~70% à invest égal = early trop décisif (snowball précoce, §1.2).

**B — Progressions dures vs faciles selon le build (la courbe de skill).**
*Setup* : faire jouer CHAQUE politique sur N runs PvE (escalade d'adversaire/round, déjà dans
`runsim.lua`). *Question* : quelles stratégies atteignent 10 victoires, en combien de rounds, à quel
investissement final ? *Métrique* : `completion%` + `avg_rounds` + `invest` par politique. *Santé* :
**plusieurs** politiques complètent (diversité, §2.6), aucune ne domine toutes les autres ; la politique la
plus exigeante (placement+reliques+sigil) complète **moins souvent mais avec des blow-outs** (plus de pics)
— c'est la signature « build dur mais payant ».

**C — Reliques qui MATCHENT vs qui NE MATCHENT PAS (chance/malchance d'offre).**
*Setup* : fixer une compo (ex. poison/abyssal), puis simuler deux variantes : (C1) offre de reliques
**alignée** (Bol-du-Roi, Communion Pestilentielle, Marque du Voyant) ; (C2) offre **anti-alignée**
(armure-aura, strip-shield — utiles à un autre archétype). *Question* : de combien la bonne offre déplace
le win-rate / l'`edge` (la **valeur réelle de la relique**, méthode `balance-sim-design.md §5.3` : perfect
vs `missing_clutch`). *Santé* : une relique alignée doit donner un `edge` **net mais borné** (égalisateur,
pas gate — §1.5) ; le decline→+or doit rendre C2 **survivable** (la malchance d'offre n'est pas une
condamnation). *Alerte* : `edge` ≈ 0 → relique décorative ; `edge` qui à lui seul fait passer de < 40% à
> 70% → relique game-changer trop forte (god-roll par relique unique, pas par construction).

**D — Comeback tardif (l'arc émotionnel majeur).**
*Setup* : run scriptée qui **perd 2-3 combats early** (politique volontairement faible début), puis à un
jalon (3e combat → canal-3 relique, ou level-up → commandant) **injecte** la pièce qui renverse. *Question* :
le comeback est-il **possible** (le floor 5-vies tient) ET **non garanti** (le early compte encore) ?
*Métrique* : taux de runs « parties perdantes early » qui atteignent quand même 10 victoires. *Santé* : ce
taux doit être **non nul mais minoritaire** (~15-35% placeholder). *Alerte* : ~0% = pas de comeback
(frustration, spirale de mort) ; > ~60% = le early ne compte plus (la run est décidée en fin quoi qu'il
arrive).

**E — Le god-roll lui-même (le fantasme, mesuré).**
*Setup* : le **god-roll explorer** (§2.3, techniques 2+4) : sur-échantillonner les intersections d'enablers
à **fort investissement** (late, board 7-9, multicast+empower+vuln empilables). *Question* : à quelle
**fréquence** un combo dépasse un seuil de domination (TTK très bas + win-rate > 90% à investissement
**supérieur** légitime) ? *Métrique* : **taux de god-roll** = part des runs late où la puissance entre dans
la queue 95-99e pct. *Santé* (§2.6) : **rare mais non nul** ; **borné** par les caps (jamais de TTK = 1
swing / boucle infinie) ; **divers** (plusieurs combos différents atteignent la queue, pas toujours le même).
*Alerte* : un **unique** combo monopolise la queue → méta-god-roll unique (à nerfer cibleusement) ; taux = 0
→ le plafond de puissance est trop bas (pas de power fantasy, §1.2) ; TTK dégénéré (1 swing) → cap moteur à
resserrer.

## 2.5 Détection du « broken » : le faisceau de signaux (pas une métrique unique)

Aucune métrique seule ne suffit. On **croise** (un broken réel tire sur **plusieurs** signaux à la fois) :

| Signal | Outil | Ce qu'il attrape | Seuil d'alerte (placeholder) |
|---|---|---|---|
| **Lift de co-occurrence** | `sim.lua` (existant) | paires qui sur-performent la moyenne solo de leurs membres | `lift > ~1.4` sur `appear ≥ PAIR_MIN` → inspecter |
| **σ-flag (outlier de champ)** | `sim.lua` (existant) | unité hors `mean ± max(0.08, 1.5σ)` | `> +2σ` → broken candidat ; `< -2σ` → mort |
| **Win-rate CONTEXTUALISÉ par invest** | `compcost.lua` (cible) | compo qui gagne **SOUS son coût** (invest ≤ adversaire mais win% ≫ 50) | gagne à invest **inférieur ou égal** hors counter intentionnel = le **seul vrai broken** |
| **TTK dégénéré** | `sim.lua` p10 | combats finis en quasi 1 swing (burst non borné) | `p10` qui s'effondre vs baseline → cap à resserrer |
| **`edge` (valeur de pièce clutch)** | `runsim.lua` (cible) | relique/unité qui à elle seule renverse | `edge` qui fait franchir 40%→70% → game-changer trop fort |
| **Entropie / σ de santé méta** | `sim.lua` (existant) | concentration de la méta sur peu de builds | entropie qui **baisse** patch-sur-patch = méta qui se referme |

**La hiérarchie des signaux (gravée).** Le **win-rate contextualisé par investissement** est le **juge
suprême** (`balance-sim-design.md §1`) : on ne flague **que** ce qui gagne **sous son coût**, **hors counter
intentionnel** (table `DESIGNED` : poison/burn/rot/shock > tank, bleed > bruiser, tank > bruiser). Une compo
chère qui écrase une compo bon marché = **sain** (récompense de maîtrise = god-roll légitime). Lift + σ sont
des **détecteurs de candidats** ; le contexte d'investissement **tranche** broken vs mérité.

**Isoler un levier (« 1 levier à la fois »).** Règle de tuning (RuleSmith / sim-driven RL le confirment :
on attribue l'impact en **variant un paramètre, le reste figé**). Procédure :
1. Détecter un outlier (faisceau ci-dessus).
2. Former **une** hypothèse de cause (ex. « le cap multicast laisse passer un burst »).
3. Varier **un seul** levier (les deux boutons de `compcost.lua` : `LEVEL_GOLD` ou un poids ; ou un cap
   moteur ; ou une valeur d'aura). **Tout le reste figé.** Seed batch identique.
4. Re-sim, comparer le `report.json` (diff-able par construction). Garder si le faisceau s'apaise **sans**
   créer un nouvel outlier ailleurs.
5. **Rebaseline golden** si — et seulement si — une unité du scénario golden change (`effects-overhaul-spec.md`).

## 2.6 Métriques de SANTÉ d'un autobattler (la cible globale)

Un autobattler est sain quand **4 propriétés** tiennent simultanément (pas « tout le monde à 50% ») :

1. **Diversité des builds gagnants** (pas 1 méta unique). Mesure : **entropie** du vecteur de win-rate
   (déjà dans `sim.lua`, *haut = sain*) + nombre de politiques distinctes qui complètent (§2.4-B) + nombre
   de combos distincts qui atteignent la queue god-roll (§2.4-E). C'est l'objectif explicite des
   autobalancers compétitifs : *« win-rates représentant des joueurs rationnels »* sur **plusieurs**
   stratégies, pas convergence vers une seule.
2. **Taux de god-roll rare mais non nul.** Mesure : part des runs late entrant dans la queue 95-99e pct
   (§2.4-E). *Rare* (le fantasme reste spécial, near-miss) *mais non nul* (le fantasme est atteignable). 0 =
   plafond trop bas ; trop fréquent = god-roll banalisé (plus de near-miss, plus de relance).
3. **Absence de « trop fort trop tôt ».** Mesure : win-rate contextualisé par investissement **croissant**
   avec l'investissement (§2.5) ; pas de pic de puissance à faible invest (§1.2). Un effet « réécrit une
   règle » obtenu au combat 1 = échec de cette propriété.
4. **Counters lisibles et respectés.** Mesure : la **matrice de counters** (`runsim.lua`) reproduit la
   table `DESIGNED` (les counters voulus se produisent) **sans** counter non-voulu écrasant. Un counter
   intentionnel n'est **jamais** flaggé (sémantique `DESIGNED`, `balance-sim-design.md §4`).

**Combien de sims pour la significativité ?** Les sources donnent des planchers **étonnamment bas** quand on
mesure une *différence de win-rate* stable : le balancing par RL converge à **n ≥ 14 itérations** sous le
critère `μ_n + σ < 0.05` (variance de la métrique de balance sous 5%). Mais ça, c'est **par cellule de
matrice** (un matchup donné). Pour The Pit, distinguer deux régimes :
- **Matrice de counters / scénarios A-D** (signal = différence de win-rate entre 2 configs) : viser
  **M ≥ 50 matchs/cellule** (`balance-sim-design.md §7` note que M < 50 sort des 0%/100% bruités) ; 14 est
  le strict minimum théorique, 50 donne la marge.
- **Distribution de puissance / god-roll explorer (E)** (signal = **queue** d'une distribution, pas une
  moyenne) : il faut **beaucoup plus** d'échantillons pour estimer un 95-99e pct stable. Viser **N ≥ 2000**
  runs/batch pour le god-roll explorer, et **sur-échantillonner** les régions à risque (importance sampling,
  §2.3-2) pour ne pas gâcher 2000 runs sur du bruit. Le **lift** de `sim.lua` n'est fiable qu'à grand N
  (`PAIR_MIN` scale en `N/150`) — cohérent avec ce régime.

## 2.7 Architecture cible : étendre `tools/sim.lua` en moteur de scénarios

Recommandations d'architecture (alignées sur `balance-sim-design.md`, sans le ré-spécifier), de la plus
simple à la plus avancée. **Tout reste SIM-pur, seedé, déterministe, diff-able.**

**(1) Brancher l'investissement.** Faire entrer `compcost.lua` dans `sim.lua` : chaque combat loggue
l'`invest` des deux camps ; le rapport calcule le **win-rate contextualisé** (gagne-t-on sous son coût ?) en
plus du win-rate brut. *C'est le single levier qui transforme `sim.lua` d'un détecteur de combat en
détecteur de broken.* (Le scénario C6 hardcodé en est le prototype : le généraliser.)

**(2) Politiques de joueur paramétrables (le cœur).** Remplacer `randomBuild()` par un **sélecteur de
politique** (`src/lab/policies.lua`, taxonomie `balance-sim-design.md §6`). Chaque run de sim = (politique,
seed) → build cohérent. Stratification : budget garanti par politique. *C'est ce qui rend les scénarios A-D
exprimables.*

**(3) Le god-roll explorer (importance sampling).** Un mode de sim dédié qui **construit délibérément** les
intersections d'enablers à fort investissement (§2.3-2), measure la **distribution de puissance** (TTK +
win-rate contextualisé), sort le **taux de god-roll** + la **liste des combos de queue** + leur **diversité**.
Réutilise le détecteur de lift comme oracle de candidats à promouvoir. *C'est ce qui rend le scénario E
exprimable — et c'est neuf vs l'existant.*

**(4) Matrice de counters paramétrable.** Compos parfaites par archétype × archétype, M matchs/cellule, avec
table `DESIGNED` (counters intentionnels non-flaggés) et `invest` par archétype. (Déjà spécifié
`balance-sim-design.md §5.2` — à brancher comme **mode** de l'outil unifié, pas un outil séparé.)

**(5) Rapports diff-ables + golden de méta.** `report.json` est déjà diff-able (clés triées). Ajouter :
`invest_context` par unité/compo, `godroll_rate`, `comeback_rate`, `policy_completion`, `counter_matrix`,
`meta_entropy` (existe). **Garder un `report.json` de référence** versionné (golden de méta) → tout drift
patch-sur-patch est un **diff lisible** (méta qui se referme = entropie qui chute = visible au diff).

**(6) Couche persona LLM (MCP, optionnelle).** `balance-sim-design.md §6` : les mêmes politiques deviennent
des **personas LLM** qui jouent une vraie partie via les outils MCP et rendent un retour **qualitatif** (fun,
frustrations, builds émergents, *« ai-je ressenti le near-miss / le fantasme »*) que le batch quantitatif ne
capte pas. **C'est le seul outil qui mesure l'Axe 1 *ressenti*** (le quantitatif mesure la *structure* du
god-roll ; le persona mesure s'il est *vécu* comme tel).

---

## 3. CHECKLIST D'ÉQUILIBRAGE (Phase C — directement exploitable)

Cocher avant de considérer une passe d'équilibrage close. Ordre = priorité.

**Santé structurelle (le faisceau)**
- [ ] Win-rate **contextualisé par investissement** branché : aucune compo ne gagne **sous son coût** hors
      counter intentionnel (`DESIGNED`). *(Juge suprême — §2.5.)*
- [ ] Aucun **σ-flag > +2σ** non expliqué par un counter voulu. *(`sim.lua` existant.)*
- [ ] Aucun **lift > ~1.4** non expliqué (combo inspecté : voulu ou cassé ?). *(`sim.lua` existant.)*
- [ ] **TTK p10** non dégénéré (pas de burst quasi-1-swing) ; **caps moteur tiennent** (multicast ≤ 3,
      poison ≤ 8, weaken ≤ 0.40, amplis additifs sur base).
- [ ] **Entropie de santé méta** stable ou en hausse vs golden de méta précédent (la méta ne se referme
      pas). *(`sim.lua` existant.)*

**Courbe de puissance (Axe 1)**
- [ ] Pas de **« trop fort trop tôt »** : win-rate-contextualisé **croît** avec l'investissement ; aucun
      effet « réécrit une règle » accessible aux combats 1-3 (`maxRelicTier` OFF early).
- [ ] **Taux de god-roll** mesuré : **rare (queue 95-99e pct) mais non nul** ; **divers** (≥ 3 combos
      distincts atteignent la queue, pas 1 méta-god-roll unique). *(Scénario E.)*
- [ ] **Blow-outs présents et mérités** : les blow-outs corrèlent avec un écart d'investissement/maîtrise,
      pas avec un dé.

**Anti-frustration (filets)**
- [ ] **Comeback rate** non nul mais minoritaire (~15-35%) : le floor 5-vies tient, le early compte encore.
      *(Scénario D.)*
- [ ] **Malchance d'offre survivable** : compo + reliques anti-alignées (C2) reste jouable (decline→+or
      absorbe). *(Scénario C.)*
- [ ] Aucune relique ne **gate** (handicape la suite) : toutes égalisatrices, intra-combat, team-wide.
      *(`relics-design.md`.)*

**Counters & diversité**
- [ ] **Matrice de counters** reproduit `DESIGNED` (counters voulus présents, aucun non-voulu écrasant).
- [ ] **Plusieurs politiques** complètent 10 victoires (pas 1 stratégie dominante). *(Scénario B.)*
- [ ] **Murmures** : aucun porteur outlier > 2σ (spice, jamais build-defining). *(`sim.lua` existant.)*

**Discipline de tuning**
- [ ] **1 seul levier varié** par itération, reste figé, même seed batch.
- [ ] `report.json` **diff-é** vs précédent ; pas de nouvel outlier introduit.
- [ ] **Golden rebaseliné** UNIQUEMENT si une unité du scénario golden change.

---

## 4. PLAN DE SIMULATION (Phase C — quels scénarios, combien de runs, quelles métriques, quels seuils)

> À exécuter dans l'ordre. Chaque ligne = un mode de l'outil unifié (extension de `tools/sim.lua` vers
> l'archi §2.7). Seuils = **placeholders** (H3) à recalibrer sur le bruit réel.

| # | Scénario | Mode / setup | N (runs ou matchs) | Métriques clés | Seuils d'alerte |
|---|---|---|---|---|---|
| **P0** | **Baseline méta** (santé globale, l'existant) | builds aléatoires symétriques (sim.lua actuel) | N ≥ 2000 combats | σ champ, entropie, TTK p10/p50/p90, status-share, lift top/bottom, σ-flags | entropie ↓ vs golden ; σ-flag > 2σ ; lift > 1.4 ; status-share hors ~50-70% |
| **P1** | **Investissement branché** | + `compcost.lua` : log invest 2 camps, win-rate contextualisé | N ≥ 2000 | win-rate **sous coût** par unité/compo | gagne à invest ≤ adversaire hors `DESIGNED` |
| **P2** | **Progressions par politique** (scénario B) | `runsim.lua` : chaque politique, escalade PvE | ≥ 100 runs/politique | `completion%`, `avg_rounds`, `invest` final, vs `random_baseline` | une politique domine toutes ; aucune ne complète ; baseline non battu |
| **P3** | **Matrice de counters** (santé counters) | compos parfaites archétype×archétype + `DESIGNED` | M ≥ 50 matchs/cellule | win% ligne-vs-col + invest/archétype + drapeaux | counter voulu absent ; counter non-voulu écrasant ; gagne sous coût |
| **P4** | **Early cohérent vs incohérent** (scénario A) | `committed_archetype` niv 1-3 vs `random_baseline`, invest égal | M ≥ 50/cellule | win% à **invest égal** | > ~70% (early décisif) ou < ~50% (cohérence non récompensée) |
| **P5** | **Reliques match/no-match** (scénario C) | compo fixée × offre alignée (C1) vs anti-alignée (C2) ; perfect vs missing_clutch | M ≥ 50/variante | `edge` (valeur de la relique) ; survivabilité C2 | `edge`≈0 (décorative) ; `edge` 40%→70% (game-changer) ; C2 non survivable |
| **P6** | **Comeback tardif** (scénario D) | run scriptée perdante early + injection clutch au jalon | ≥ 200 runs scriptées | taux runs perdantes-early → 10 victoires | ~0% (spirale) ou > ~60% (early inutile) |
| **P7** | **God-roll explorer** (scénario E) | importance sampling des intersections d'enablers, fort invest | N ≥ 2000, régions à risque sur-échantillonnées | **taux de god-roll** (queue 95-99e pct), **diversité** des combos de queue, TTK queue | 0% (plafond trop bas) ; 1 combo monopolise (méta unique) ; TTK = 1-swing (cap à resserrer) |
| **P8** | **Combos commandant/relique ciblés** (régression) | scénarios hardcodés (C6 existant + nouveaux) : caps tiennent | déterministe, 1 seed/combo | multicast borné à 3 ; pas de one-shot ; combat conclut | cap franchi ; boucle infinie ; one-shot |
| **P9** | **Persona LLM** (qualitatif, MCP) | personas = politiques jouant une vraie partie | quelques runs/persona | retour fun/frustration/near-miss vécu/builds émergents | « pas vu de fantasme » ; « frustration de hasard » ; « 1 seul build viable » |

**Cadence recommandée.** P0-P1 + P8 à **chaque** vague de contenu (régression rapide, déterministe). P2-P7
à **chaque jalon d'équilibrage** (passe P5 de l'overhaul). P9 (persona LLM) **ponctuellement** quand le
quantitatif est vert mais qu'on doute du *ressenti* (l'Axe 1 vécu).

**Boucle de tuning (gravée).** détecter (faisceau §2.5) → 1 hypothèse → **1 levier** (les 2 boutons
`compcost` / 1 cap / 1 aura) → re-sim **même seed** → diff `report.json` → garder si le faisceau s'apaise
sans nouvel outlier → rebaseline golden **ssi** scénario golden touché. **Jamais 2 leviers à la fois.**

---

## 5. Synthèse en une page (le contrat Phase C)

1. **Le god-roll est une CIBLE de design, pas un accident.** On le veut **rare, atteignable, borné,
   divers, télégraphié**. Mesure : P7 (taux de queue 95-99e pct + diversité).
2. **La RNG vit dans la construction, le combat est déterministe.** Le « presque » porte sur les pièces
   tirées (near-miss d'offre 1-parmi-3), jamais sur un dé en combat. C'est ce qui rend le god-roll
   **mérité** et le blow-out **lisible**.
3. **Le win-rate brut ne juge rien ; l'investissement tranche.** On ne flague QUE ce qui gagne **sous son
   coût**, **hors counter intentionnel**. Une compo chère qui atomise une compo pauvre = sain.
4. **On échantillonne les strates de theory-craft, on ne les énumère pas** : sampling stratifié par
   politique + importance sampling vers les intersections d'enablers + invariance de sigil + couverture
   pairwise.
5. **5 scénarios joueurs nommés** (early cohérent / progressions / reliques match-no-match / comeback /
   god-roll) deviennent des **modes de sim** mesurables, branchés sur le banc d'essai existant
   (`runsim.lua` + `compcost.lua` + `sim.lua`).
6. **1 levier à la fois, diff-able, golden-discipliné.** Le déterminisme rend chaque god-roll détecté
   **reproductible** (seed) et **inspectable** (Chronicle) — on tune sur des faits, pas des intuitions.

---

## Sources

- TheGamer — *Balatro And Hades Turn You Into A Video Game God* (power fantasy roguelite, broken builds temporaires, rareté du god-roll) : <https://www.thegamer.com/balatro-hades-roguelike-overpowered/>
- Roguelike Games — *The 10 Best Balatro Seeds* (blow-out / power spikes / infinite loops / score explosif) : <https://roguelikegames.com/best-balatro-seeds/>
- Prof. Boston / TeachBoston — *The Near-Miss Effect: How Slot Machines Engineer Almost-Wins* : <https://www.teachboston.org/near-miss-effect-slots/>
- Casino Center — *Slot Machine Psychology: How the Near Miss Effect Drives Player Behavior* (Clark et al. 2009, ventral striatum) : <https://www.casinocenter.com/slot-machine-psychology-how-the-near-miss-effect-drives-player-behavior-in-online-gaming/>
- The Psychology of Games — *The Near-Miss Effect and Game Rewards* : <https://www.psychologyofgames.com/2016/09/the-near-miss-effect-and-game-rewards/>
- Springer / Journal of Gambling Studies — *The Near-Miss Effect in Slot Machines: A Review and Experimental Analysis* : <https://link.springer.com/article/10.1007/s10899-019-09891-8>
- Prof. Boston / TeachBoston — *Variable Reward Schedules* (ratio variable, Skinner) : <https://www.teachboston.org/variable-reward-schedules-gambling/>
- Frostilyte Writes — *Do You Like Deck-Building Roguelikes? Try Balatro* (combos = vraie identité roguelike, lisibilité) : <https://frostilyte.ca/2024/03/08/do-you-like-deck-building-roguelikes-try-balatro/>
- arXiv 2006.04419 — *Metagame Autobalancing for Competitive Multiplayer Games* (MCTS comme proxy de joueurs rationnels, win-rate entre matchups) : <https://arxiv.org/abs/2006.04419>
- arXiv 2503.18748 — *Simulation-Driven Balancing of Competitive Game Levels with RL* (objectif win-rates égaux, boucle reward-sim, seuil n ≥ 14 sous μ+σ < 0.05, isolation de levier par fréquence de swap) : <https://arxiv.org/html/2503.18748v1>
- arXiv 2602.06232 — *RuleSmith: Multi-Agent LLMs for Automated Game Balancing* (Bayesian optimization + acquisition-based adaptive sampling : plus de games aux candidats prometteurs ; self-play LLM ; win-rate disparity → 0%) : <https://arxiv.org/abs/2602.06232>
- Horn et al. 2018 — *A Monte Carlo Approach to Skill-Based Automated Playtesting* (agents de skill variable, playouts Monte-Carlo pour évaluer le design) : <https://www.ncbi.nlm.nih.gov/pmc/articles/PMC6319931/>
- Hearthstone Top Decks — *How Does Hearthstone Battlegrounds Compare to Other Auto Battlers?* (économie or fixe/tour, power spikes par palier, scaling late) : <https://www.hearthstonetopdecks.com/how-does-hearthstone-battlegrounds-compare-to-other-auto-battlers/>
- CBR — *Why Super Auto Pets Is Better Than TFT or Battlegrounds* (autobattler dépouillé, scaling par level-up) : <https://www.cbr.com/super-auto-pets-autobattler-tft-hearthstone-battlegrounds/>

### Documents internes ancrant la recherche (non-web)
- `docs/research/gd-research-result.md` (blueprint : RNG construction / combat déterministe, floors, async, anti-snowball)
- `docs/research/effects-overhaul-spec.md` (tiers, enablers agnostiques multicast/empower/vuln, caps moteur, commandants, murmures)
- `docs/research/balance-sim-design.md` (banc d'essai cible : politiques/personas, `compcost.lua`, matrice `DESIGNED`, win% contextualisé)
- `docs/research/relics-design.md` (reliques lisibles, égalisatrices, 1-parmi-3, decline→+or)
- `docs/research/combat-model-decision.md` (vie par entité, identité protégée au run, ciblage déterministe)
- `docs/research/combat-chronicle-spec.md` (inspecteur de combat : rejouer le god-roll au ralenti)
- `tools/sim.lua` (existant : lift de co-occurrence, σ-flags, TTK percentiles, détecteur de murmures, scénario C6)
