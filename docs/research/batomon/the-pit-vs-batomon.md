# The Pit ⟷ Batomon Showdown — étude comparative (theory-crafting)

> Comparaison **sur données réelles des deux côtés** : The Pit lu dans le code
> (`src/data/units.lua`, `src/effects/ops.lua`, `src/data/relics.lua`, `src/board/`,
> `src/combat/arena.lua` — 3 extractions de code, juin 2026) ; Batomon scrapé intégralement
> depuis batodex.com (`monsters.json` 80, `trinkets.json` 58, `items.json` 32).
> Aucun chiffre supposé (règle d'or §1.a). Batomon = **référence d'addictivité du projet** (CLAUDE.md §2).

---

## 0. Thèse en une phrase

> **La profondeur de theory-crafting ≠ le nombre de mécaniques. C'est le nombre d'axes
> indépendants qui se MULTIPLIENT entre eux, × le degré auquel des effets amplifient
> d'autres effets, × la lisibilité (on ne peut planifier que ce qu'on peut lire).**

Sur cette grille, le verdict est un **paradoxe net** :

- **The Pit est plus profond SOUS la ligne de combat** : 23 ops, **13 interactions inter-afflictions**
  (contagion, propagation à la mort, conversion, aggravate, shield-eat), commandants, caps. Ce qui se
  *passe dans le combat* est plus riche que Batomon — qui a délibérément un combat **mince** (6 stats,
  zéro transmission entre afflictions).
- **Batomon est plus profond AU-DESSUS de la ligne de combat** : c'est la couche *build* — type-identité,
  moteur de boutique, items/transforms, **trinkets méta-multiplicateurs**, pics par niveau — qui crée la
  sensation « je peux planifier un build cassé ». The Pit a **plus de mécanismes mais moins d'axes
  orthogonaux que le joueur pilote activement**.

Autrement dit : **on a sur-investi le simulateur, sous-investi la combinatoire de build.** C'est exactement
là que Batomon « impressionne », et c'est réparable — le framework de The Pit supporte déjà la plupart des
briques manquantes (elles sont *inertes*, pas absentes).

---

## 1. Inventaire côte à côte (chiffres durs)

| Dimension | **The Pit** | **Batomon Showdown** |
|---|---|---|
| Unités jouables | **83** (coût 1-5 : 12/23/18/20/10) | **80** (tier 1-6, rareté 1:1 au tier) |
| Vocabulaire de combat | 5 familles DoT **+ 23 ops** au total | **6 stats** : damage, burn, poison, heal, shield, shock |
| Familles d'altération | burn(13) bleed(12) poison(15) rot(12) shock(11) | 3 « afflictions » : burn, poison, shock (+ heal/shield défensifs) |
| Triggers | **8** : on_attack, on_hit, on_attacked, combat_start, on_low_hp, on_kill, on_death, on_ally_death | 6 : On Cast, On Battle Start, Ongoing, On Victory, On Knocked Out, passif |
| Portée des triggers | **Combat uniquement** | **Combat ET boutique** (cross-phase : « after you buy… ») |
| Interactions inter-afflictions | **13 chaînes câblées & testées** | **0** (afflictions indépendantes) |
| Modèle de combat | cooldown/entité, déterministe + RNG seedé | cooldown/entité (identique d'esprit) |
| Niveaux d'unité | 3 copies → niveau, **cap 3** `{1, 1.8, 3}` | **4 niveaux** + **multicast débloqué (surtout niv 4)** + **évolution** (5 monstres) |
| Multicast | existe, **cap 3**, ne scale pas au niveau | **pilier de build**, empilable, type-gaté, débloqué au niv 4 (25 monstres) |
| Types | **5** (flesh/bone/arcane/abyss/order) — **cosmétiques, NON câblés** | **14** (Fire/Bug/Toxic/Water/…) — **câblés partout** |
| Synergie de type | **aucune** (le type ne fait rien en jeu) | **massive** : amplis par type, « per unique type », adjacence par type |
| Topologie de plateau | **5 sigils… GELÉS** (`SIGILS_PAUSED=true`, carré only) | aucune (grille fixe à positions nommées) |
| Positionnement | ciblage depth→taunt→aggro ; auras d'adjacence (graphe) | **25/67 abilities positionnelles** (« ally to the left/above », colonnes nommées) |
| Reliques / trinkets | **39** (lisibles, team-wide, build-time) | **58** (lisibles, team-wide) |
| Gating par type sur reliques | **aucun** | **oui** (Fire Orb, Poison Orb, Razor Beak…) |
| Méta-multiplicateurs | **rares** (plague_communion) | **présents & puissants** (Zenith Stone, Link Cable, Master Crown, Onsetra) |
| Items / consommables | **AUCUN** | **32** (reroll-manip, transforms de rareté, buffs de type, éco) |
| Économie comme axe de build | légère (reliques éco) | **forte** (shop-rank, transforms, vie-monnaie, moteurs cross-phase) |
| Commandants | **83 auras de commandement** + 1 commandant actif (intouchable) | aucun (mais trinkets « top middle » ≈ carry désigné) |
| Whispers / affinités cachées | **23 unités** (easter egg) | aucun |
| Lisibilité des effets | **lisible** (leurres retirés) | **lisible** |
| Déterminisme / async | **total** (snapshots, ghosts, replays) | n/a pour notre design |

---

## 2. Comparaison axe par axe

Chaque axe : ce que fait Batomon · ce que fait The Pit · verdict theory-crafting.

### Axe A — Vocabulaire de combat
- **Batomon** : 6 stats, point. Un monstre « cast » à son cooldown et applique ses stats (frappe, brûle,
  empoisonne, soigne, boucle, choque). Pas de bleed/rot/thorns. La défense (heal/shield) est *dans* le
  vocabulaire de base.
- **The Pit** : 5 familles DoT distinctes + 23 ops (lifesteal, thorns, strip_shield, regen, cleave, execute,
  crit, frenzy, purge, conversions…), avec moteur de statuts (stacks, decay, necrosis, discharge) et **6 caps**.
- **Verdict** : The Pit gagne en **richesse de simulation**, Batomon gagne en **clarté/lisibilité**. ⚠️ Notre
  diagnostic interne « monoculture DoT 75,9 % » dit que cette richesse ne se **traduit pas** en diversité de
  build : 5 familles qui font toutes « dégâts dans le temps » sont moins orthogonales que les 6 stats de Batomon
  (dont 2 sont défensives → vrai choix offense/défense). **Leçon : la diversité vient des axes orthogonaux, pas
  du nombre de familles d'un même registre.**

### Axe B — Interactions inter-afflictions ⭐ (The Pit gagne franchement)
- **Batomon** : **aucune.** Le poison ne déclenche rien sur le feu ; pas de propagation, pas de contagion.
- **The Pit** : **13 chaînes** — décharge de choc allié, poison multi-source + weaken, bleed→slow, regen vs DoT,
  **contagion** (plague_bearer), **propagation à la mort** (wildfire_hound, blight_spreader), **aggravate**
  (bloodletter : le bleed explose), **shield-eat** (acid_maw), **conversions croisées** (bleed→rot, poison→feu),
  **festering** (cap poison → 99).
- **Verdict** : c'est notre **profondeur de combat unique**, sans équivalent chez Batomon. Un combo type
  *plague_bearer + festering + The Kings' Bowl + plague_communion + venom_censer* déclenche une **réaction en
  chaîne** (poison qui se propage, non-cappé, amplifié, détonant en feu, + multiplicateur global) que Batomon
  ne peut structurellement pas produire. **À garder et à mettre en avant.**

### Axe C — Type-identité ⭐ (Batomon gagne franchement — notre plus gros trou)
- **Batomon** : 14 types **câblés partout**. Trinkets *Fire Orb* (+3 burn à tous les Fire), *Poison Orb*,
  *Razor Beak* (+1 multicast aux Flying) ; items *Black Sludge*, *Hot Pepper* ; abilities d'adjacence par type
  (Noxnimbus : « adjacent Toxic allies +2 poison ») ; *Prismagon* : « +5 dmg **par type unique** » ; *Rainbow
  Berry* : « +4 dmg par type unique ». ⇒ **deux stratégies opposées et claires** : mono-type (empile les amplis)
  ou rainbow (récompense la diversité). C'est une **colonne vertébrale d'identité de build**.
- **The Pit** : 5 types (flesh/bone/arcane/abyss/order) **purement cosmétiques** — aucune aura ne lit le type.
  Le framework *supporte* `aura_stat target="type:X"` mais **rien ne l'utilise**.
- **Verdict** : Batomon en tire un axe entier ; chez nous il est à **zéro**. **C'est le levier #1 le moins cher
  pour ouvrir de la profondeur** (le moteur est prêt).

### Axe D — Topologie de plateau (signature The Pit… mais inerte)
- **Batomon** : grille fixe à **positions nommées** (top middle, bottom right, leftmost/rightmost column). Pas de
  topologie variable, mais les positions sont des **slots de valeur** ciblés par les trinkets (*Power Crown*,
  *Speed Crest*, *Master Crown*). Positionner devient un puzzle d'optimisation.
- **The Pit** : 5 sigils-graphes (carré/croix/anneau/diamant/ligne) = **notre signature lovecraftienne**…
  **GELÉS** (`SIGILS_PAUSED=true`). Un seul plateau jouable.
- **Verdict** : Batomon exploite *sa* grille statique mieux que The Pit n'exploite *sa* grille variable
  (puisqu'elle est éteinte). Notre axe le plus distinctif est **off**.

### Axe E — Positionnement / adjacence
- **Batomon** : **25/67 abilities** référencent la position (« ally to the left/right/above », « adjacent X
  allies », colonnes). Très lisible, très nombreux. Trinkets *Link Cable* (« adjacent → **tous** les alliés »)
  change la portée.
- **The Pit** : ciblage déterministe (depth→taunt→aggro→tie-break) **live et solide** ; auras d'adjacence
  build-résolues sur le graphe + propagation de combat (proximité Chebyshev). Mais **moins d'effets** explicitement
  positionnels côté unités, et la lisibilité « qui buffe qui » est moins immédiate (pas de « l'allié de gauche »).
- **Verdict** : parité de *mécanisme*, mais Batomon a **plus de contenu positionnel lisible**. *Link Cable* est un
  méta-multiplicateur positionnel qu'on n'a pas.

### Axe F — Leveling
- **Batomon** : **4 niveaux**, courbes de stats par niveau, **multicast débloqué au niveau 4** (pic de puissance →
  *quel* carry monter au 4 est une décision de build), + **évolution** (change l'unité). *Rare Candy* (item) level-up.
- **The Pit** : 3 copies → niveau (cap 3), `LEVEL_MULT {1, 1.8, 3}`. Les stats ET les auras scalent (le multicast
  non). Niveau 1 = identité (golden-safe).
- **Verdict** : Batomon fait du niveau une **décision qualitative** (débloque un *keystone* : multicast) ; chez nous
  c'est surtout un **scaling quantitatif** (×3). On pourrait greffer un *unlock* au niveau 3.

### Axe G — Fréquence (multicast / cooldown speed) ⭐ (le combo « cassé » de Batomon)
- **Batomon** : axe central et empilable. Sources de multicast : *Zephyrex* (+1 perm à l'allié Flying de droite),
  *Saberhorn*, *Stellagon* (+2 aux alliés sans ability), trinkets *Razor Beak*/*Winged Crown*. Cooldown-speed :
  *Formiqueen* (+33 % aux Common adjacents), *Haste Orb*, *Speed Crest*. **Le shock scale avec la fréquence** →
  empiler multicast sur un carry shock = explosion. C'est *le* god-roll ressenti.
- **The Pit** : multicast existe (cap 3, ne scale pas au niveau), haste (cap 0.40), et **notre choc scale aussi avec
  la fréquence** (multicast/chain/haste) — exactement la même asymétrie fréquence/temps. Mais **peu de sources de
  multicast** et un cap dur à 3.
- **Verdict** : même intuition de design des deux côtés ; Batomon en fait un **pilier de build** avec beaucoup de
  sources empilables, nous on le tient en laisse (cap 3, peu de sources). À ouvrir prudemment.

### Axe H — Reliques / trinkets
- **Batomon** (58) : deux familles nettes — (a) **boost team-wide souvent type-gaté** ; (b) **moteurs d'éco/méta**.
  + une poignée de **méta-multiplicateurs** qui amplifient les *autres* effets : *Zenith Stone* (« quand tes monstres
  gagnent des stats, **+80 % de plus** »), *Link Cable* (adjacence→global), *Master Crown* (top-middle +80 % stats),
  *Onsetra* (l'allié de gauche applique ses Ongoing **2×**). Ces effets **multiplicatifs** font exploser la combinatoire.
- **The Pit** (39) : 9 catégories bien structurées — plaques de stats, **amplis d'affliction** (poison/burn/bleed/rot Inc),
  défense/cadence, payoffs conditionnels (famines_math : ≤3 unités → +30 % dmg), **transformatives = réécritures de règle**
  (shockChain, burnNoDecay, bleedNoExpire, plagueAmp), reliques de boutique, **éco** (carryover+intérêts, refund 100 %),
  + V2/V3 (role-targeted : echo_crown = multicast au front). **Lisibles**, build-time, team-wide, equalizer, cappées.
- **Verdict** : nos reliques sont **mûres et saines** (caps, pas de one-shot) et nos *transformatives* sont excellentes
  (changer une règle = très theory-craft). **Ce qui manque** : (1) le **gating par type** (zéro chez nous) ; (2) les
  **méta-multiplicateurs** (amplifier ses amplis) — Batomon en tire l'essentiel de sa combinatoire « broken ».

### Axe I — Items / consommables (axe entier absent chez The Pit)
- **Batomon** : **32 items**, presque tous gratuits, à usage **limité par jour**. Trois rôles : (1) **manipulation de
  reroll** *tier-lockée* (« reroll une boutique 100 % Rare »), (2) **transforms de rareté** (« Common → Uncommon »,
  « level up un monstre »), (3) **buffs ponctuels par type / éco**. ⇒ ce sont les **outils pour FORCER un build
  théorisé** (je vise mono-Toxic → je transforme/reroll vers du Toxic).
- **The Pit** : **rien**. Boutique = unités + reliques, pas de consommables.
- **Verdict** : Batomon a un **axe complet de tempo & de forçage de build** qu'on n'a pas. C'est une grosse partie du
  « je peux *construire* ma combo » plutôt que « j'espère la tirer ».

### Axe J — Économie comme axe de build
- **Batomon** : **shop-rank** (on monte le rang pour voir les hauts tiers), **vie-monnaie** (*Red Coin* : +20 $ / -1 vie),
  **moteurs cross-phase** (*Cinderfly* : « après achat d'un Bug, +10 % CD speed perm »), intérêts (*Piggy Bank*). L'éco
  **est** une stratégie.
- **The Pit** : or fixe/round, reroll, **leveling = déblocage de slot**, streaks, reliques éco (intérêts, carryover,
  refund 100 %). Solide mais **plus mince** comme *axe de theory-craft* (l'éco sert le build, elle n'**est** pas un build).
- **Verdict** : Batomon transforme l'éco en levier de build via le **cross-phase** ; nous restons combat-only.

### Axe K — Commandants & whispers ⭐ (The Pit-unique)
- **The Pit** : **les 83 unités portent une aura de commandement** (role:front/back, team, tier:N, level:N) + 1 commandant
  actif intouchable. **23 unités** portent des *whispers* (affinités cachées, golden-neutres). Deux axes que Batomon n'a pas.
- **Batomon** : pas de commandant (les trinkets « top middle » désignent un carry, c'est l'analogue le plus proche).
- **Verdict** : axe **différenciateur** pour nous, encore jeune — à exploiter (le commandant peut porter une *identité*
  d'équipe : « commandant Toxic → toute l'équipe gagne du poison », ce qui rejoint l'axe type).

### Axe L — Lisibilité & déterminisme
- **Parité** sur la lisibilité (on a retiré leurres/identification). **The Pit gagne** sur le déterminisme + snapshots
  async (notre pilier #3) — non comparable, mais c'est une force structurelle pour l'async-vérifiable.

---

## 3. Pourquoi Batomon « impressionne » en theory-crafting (les 5 raisons structurelles)

1. **Des axes orthogonaux qui se multiplient.** Type × position × niveau × fréquence × éco × trinket. Chaque décision
   interagit avec les autres → produit cartésien, pas somme.
2. **Des méta-multiplicateurs.** Des effets qui amplifient les effets (*Zenith Stone* +80 % à tout gain de stat,
   *Link Cable* adjacence→global, *Onsetra* Ongoing ×2). C'est **multiplicatif** → les combos explosent.
3. **Des moteurs cross-phase.** Le build est une **machine d'achat/éco** qui compose dans le temps (scaling permanent,
   « after you buy X »), pas seulement un plateau figé.
4. **Lisible donc planifiable.** Chaque effet affiche son chiffre → on peut **viser** un build cible…
5. **…et le FORCER.** Items de transform/duplication/reroll-lické → on **fabrique** la combo théorisée au lieu de
   l'espérer. Le type-identité donne la **cible claire** (« je pars mono-Fire »).

The Pit a la brique (1) à moitié (auras, adjacence, reliques) mais **types off + sigils off** ; (2) **rare** ;
(3) **absente** (combat-only) ; (4) **OK** ; (5) **absente** (pas d'items/transforms).

---

## 4. Où The Pit gagne déjà (à ne pas sous-vendre)

- **Réactions en chaîne inter-afflictions** (contagion/propagation/conversion/aggravate/shield-eat) — **13 interactions**,
  zéro équivalent Batomon. Notre signature mécanique.
- **Reliques transformatives** (réécritures de règle : burnNoDecay, shockChain, bleedNoExpire, plagueAmp) — du theory-craft
  « je change une loi du combat ».
- **Commandants + whispers** — deux axes différenciateurs (leadership, affinités cachées).
- **Déterminisme + snapshots async** — pilier multijoueur que Batomon n'adresse pas dans notre modèle.
- **Discipline de caps** (pas de one-shot, reliques égalisatrices) — squelette d'équilibrage plus sain.

---

## 5. À emprunter à Batomon (priorisé par leverage / coût)

> ⚠️ Ce sont des **observations de design**, pas des décisions. Le passage à des mécaniques concrètes doit passer par
> **autobattler-designer** (design) puis **love2d-engineer** (implé) + sims d'équilibrage (`tools/sim.lua`). Listé par
> rapport profondeur-débloquée / coût-d'implé.

1. **CÂBLER LES TYPES** *(leverage énorme, coût faible — le moteur est prêt)*. Donner du sens aux 5 types : amplis
   same-type (« vos unités flesh ont +X »), « par type unique », auras d'adjacence par type, et **reliques type-gatées**.
   Ouvre l'axe **identité de build** (mono-type vs rainbow) qui manque totalement. *Le framework supporte déjà
   `aura_stat target="type:X"`.* **C'est le candidat #1.**
2. **MÉTA-MULTIPLICATEURS** *(leverage élevé, coût moyen)*. 2-3 reliques « amplifie tes amplis » : un *Zenith-Stone*
   (« +X % à toutes tes auras »), un *Link-Cable* (« les effets d'adjacence touchent toute la colonne/le graphe »).
   C'est ce qui crée la combinatoire « broken ». **Attention aux caps** (rester sous nos plafonds existants).
3. **DÉGELER / repenser les SIGILS** *(leverage élevé, coût moyen — c'est notre signature)*. Même 2 sigils vivants,
   offerts en **récompense de relique**, rajoutent l'axe topologie. Lier « 1 forme = 1 archétype » à l'axe type.
4. **EFFETS CROSS-PHASE (build-state)** *(leverage moyen, coût moyen)*. Quelques commandBonus / effets de boutique
   (« après avoir acheté une unité bone, +dmg perm »). **Reste snapshot-déterministe** car résolu *avant* le combat
   (build-state). Ouvre l'axe **moteur d'achat**.
5. **ITEMS / CONSOMMABLES + TRANSFORMS** *(leverage moyen, coût élevé — axe neuf)*. Une couche d'items pour **forcer**
   le build théorisé : reroll-lické, « transforme une unité en type X », « monte une unité d'un niveau ». Transforme
   l'espoir en plan.
6. **UNLOCK PAR NIVEAU** *(leverage moyen, coût faible)*. Au niveau 3, un petit *keystone* qualitatif (pas juste ×3 de
   stats) — façon « multicast au niveau 4 » de Batomon. Rend le choix « qui monter » plus riche.

**Ordre conseillé** : (1) types → (2) méta-multiplicateurs → (3) sigils, car ces trois réutilisent l'existant et
attaquent directement les axes éteints. (4)-(6) sont des chantiers neufs à cadrer ensuite.

---

## Annexe — surface de theory-craft de Batomon (distribution mécanique)

Sur 67/80 monstres avec ability réelle :
`adjacence 25 · scaling permanent 17 · type-gaté 13 · fréquence 12 · défensif 7 · knockout 7 · transform 5 · éco 3`.
Trinkets (58) : `éco 12 · fréquence 11 · scaling 6 · défensif 6 · type 5 · adjacence 5 · copie 3`.
Items (32) : `éco 13 · type 5 · transform 4 · scaling 3`.
Multicast débloqué par niveau (#monstres) : `niv1:6 · niv2:12 · niv3:12 · niv4:25`.
Abilities cross-phase (boutique/éco, pas combat) : **8 monstres** + ~moitié des trinkets.

Données brutes : `monsters.json`, `trinkets.json`, `items.json`, vue lisible `batodex-digest.md`.
