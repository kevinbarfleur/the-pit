# The Pit ⟷ Batomon ⟷ Super Auto Pets — étude comparative à trois

> **Doc maître.** Comparaison sur **données réelles des trois côtés** :
> - The Pit : lu dans le code (3 extractions, juin 2026) — voir `batomon/the-pit-vs-batomon.md` pour le détail axe-par-axe Batomon.
> - Batomon : scrap intégral de batodex.com — `batomon/{monsters,trinkets,items}.json` + `batomon/batodex-digest.md`.
> - SAP : dataset **sapai** (MIT) audité + recherche wiki/méta — `sap/super-auto-pets-data.json` + `sap/sap-digest.md`.
>
> But : (1) situer la **profondeur de theory-crafting** des trois ; (2) tracer le **plan anti-clone** —
> quelles mécaniques **originales** ajouter pour que The Pit ne soit ni un Batomon ni un SAP, en s'appuyant
> sur notre thème grimdark et notre moteur existant.

---

## 0. Thèse : trois jeux, trois « emplacements » de profondeur

La profondeur de theory-crafting = **axes orthogonaux qui se multiplient × effets qui amplifient des effets ×
lisibilité**. Les trois jeux mettent cette profondeur à des **endroits différents** :

| Jeu | Où vit la profondeur | Ce qui lui manque |
|---|---|---|
| **SAP** | **Grammaire d'effets** (`Trigger × Effect × Target`, 21 triggers, composable) + **économie Mort/Invocation** + **polarité positionnelle** + **cap → endgame de removal** | aucun DoT ; combat 1-rangée ; ciblage RNG |
| **Batomon** | **Couche build** : axes orthogonaux (**type-identité** × position × fréquence × éco × **méta-multiplicateurs**) + moteurs **cross-phase** | pas de transmission d'effets ; pas de mort-payoff ; grille statique |
| **The Pit** | **Simulation de combat** : **afflictions + 13 transmissions** (contagion/propagation/conversion) + commandants + whispers + **déterminisme/async** | **types inertes**, **sigils gelés**, pas de mort-économie, pas de mimétisme, pas de méta-multiplicateurs |

**Conclusion d'entrée** : The Pit est profond **dans le fight**, les deux autres sont profonds **dans le build**.
Notre territoire **unique** (ni Batomon ni SAP ne l'ont) = **le combat comme simulation d'afflictions qui se
propagent**. Notre **plan anti-clone** : garder ça comme cœur, et **emprunter à SAP** (pas à Batomon) la couche
de build qui nous manque — parce que la signature de SAP (**Mort & Réanimation, mimétisme**) est *thématiquement
nôtre* (grimdark, Le Puits), là où la signature de Batomon (empiler des types Pokémon) ne l'est pas.

---

## 1. Tableau à trois (chiffres durs)

| Dimension | **The Pit** | **Batomon** | **Super Auto Pets** |
|---|---|---|---|
| Roster | 83 unités | 80 monstres | 89 pets (+8 tokens) |
| Modèle de combat | **cooldown/entité, déterministe** | cooldown/entité | **vagues 1-rangée, ciblage RNG borné** |
| Vocabulaire d'effet | 23 ops, 5 familles DoT | « 6 stats » | **17 effect-kinds, 21 triggers** |
| Triggers | 8 (combat-only) | 6 (dont cross-phase) | **21 (boutique+combat+conditionnels d'état)** |
| Grammaire | `{trigger, op, params, cond, target}` | `{trigger, effet}` | **`Trigger × Effect × Target × Condition`** |
| Transmission inter-effets | **13 chaînes** | 0 | 0 (pas de DoT du tout) |
| DoT / afflictions | **5 familles** (poison/burn/bleed/rot/shock) | 3 (burn/poison/shock) | **aucune** (KO binaire : Peanut) |
| Mort comme ressource | `on_death` (propagation seulement) | « Knockout » mineur (7) | **★ pilier : Faint (17) + Summon (8) + tokens** |
| Copie / mimétisme | aucun | aucun | **★ Tiger/Parrot/Crab/Whale** |
| Types | 5 — **inertes** | **14 — câblés** (identité) | n/a (pas de typage) |
| Topologie | **3×3 graphe mutable — GELÉ** | grille à positions nommées | **1 rangée + polarité devant/derrière** |
| Leveling | 3-copies→niv 3 `{1,1.8,3}` | 4 niv + multicast@4 + évolution | **3-copies→niv 3 + XP (Chocolate) découplé** |
| Buff temp vs permanent | partiel | implicite | **★ explicite (`untilEndOfBattle`)** |
| Reliques / objets | 39 reliques, **0 item** | 58 trinkets + **32 items** | **17 foods → 10 statuses persistants** |
| Méta-multiplicateurs | rares | **présents** (Zenith/Link/Master) | **Tiger/Cat** (amplifient ton meilleur effet) |
| Frein anti-snowball | **caps de lecture** (ATK 1.5, DoT ×4, multicast 3…) | ? | **« works N times/battle » + cap 50/50** |
| Économie | or/round, reroll, level=slot | shop-rank, vie-monnaie, cross-phase | **10 or fixe, no-interest, FREEZE, 1 free roll** |
| Async / sans timer | **★ snapshots déterministes** | ? | **★ pionnier (snapshots, no-timer)** |
| Lisibilité | lisible | lisible | **★ passifs « texte de carte » Hearthstone** |
| Thème | **grimdark Cthulhu×PoE×Souls** | mignon collector | mignon |

---

## 2. Les insights de design de SAP qui comptent pour nous

SAP a 5+ ans, un énorme succès, et une littérature de design. Cinq enseignements **transférables** (sourcés) :

### 2.1 — La composabilité est la preuve de concept de NOTRE moteur
SAP décompose **chaque** unité en `un trigger + un effet + une cible` ([a327ex](https://a327ex.com/posts/super_auto_pets_mechanics)).
21 triggers × 17 effets × ~20 cibles → un espace gigantesque à partir de primitives minuscules. **C'est exactement
la forme de notre `{trigger, op, params, target}`.** Leçon : notre profondeur de build ne viendra **pas** d'ajouter
des familles DoT, mais de **multiplier les triggers et les cibles** (on n'a que 8 triggers combat-only ; SAP en a 21
sur deux phases). Élargir la grammaire > élargir le zoo d'afflictions.

### 2.2 — Le CAP force une transition de phase (réponse à « scaling qui ne gate jamais »)
Le cap **50/50** *termine volontairement* la course au scaling : une fois les deux plateaux cappés, on **ne peut plus
out-stat** → l'endgame appartient au **removal % / KO fixe + placement** (Skunk −99 % PV, Peanut one-shot, Panther
pre-combat), souvent **amplifié par Tiger** ([twoaveragegamers](https://www.twoaveragegamers.com/ultimate-guide-to-super-auto-pets-game-mechanics/)).
**Leçon pour The Pit** : on a *déjà* des caps de lecture (ATK 1.5, DoT ×4, multicast 3). Mais on n'a pas l'**endgame
de removal** qui leur donne un sens stratégique. Un cap **sans** outils de removal = un mur ; un cap **avec** removal
= une bascule « les gros chiffres cèdent au placement/ciblage malin ». À considérer : des effets **%-PV / exécution /
ciblage chirurgical** comme contre-jeu de fin de partie (on a déjà `execute` ; en faire un **axe**).

### 2.3 — Force-multiplicateurs > payloads (le pattern « Tiger »)
Les pièces les plus aimées de SAP (**Tiger** « l'allié devant **répète** son ability », **Cat** « les foods sont
**doublés** ») ne sont pas des gros bâtons : elles **amplifient ton meilleur truc**. Ça aligne deux choses pour nous :
(a) un **op `repeat_ability`** (relancer le descripteur d'effet du voisin au niveau du copieur) **tombe direct dans
notre moteur data+ops+bus** ; (b) ça valide notre pilier #2 « reliques = **égalisateurs/amplificateurs**, pas des
gates ». **Les méta-multiplicateurs créent la combinatoire « broken » que Batomon ET SAP exploitent et qu'on n'a pas.**

### 2.4 — Temporaire vs permanent = soupape d'équilibrage
SAP rend ses effets **les plus bruyants** temporaires (`until end of battle` : Buffalo, Crab, Parrot) → ils
**égalisent un matchup sans capitaliser** en runaway ([Buffalo](https://superautopets.wiki.gg/wiki/Buffalo)).
**Valide notre règle « reliques intra-combat only »** — et suggère de l'étendre **aux abilities d'unités** (un effet
fort = « ce combat seulement »).

### 2.5 — Async / sans timer = le vrai différenciateur (qu'on a déjà)
Les devs SAP : *« l'expérience auto-battler, mais où tu as le temps de réfléchir »* ; la pression est **économique,
pas temporelle** ([CBR](https://www.cbr.com/super-auto-pets-autobattler-tft-hearthstone-battlegrounds/)). C'est
**notre pilier #3** (snapshots déterministes). **Validation** : on a déjà le bon squelette multijoueur ; le ciblage
**100 % déterministe** de The Pit est même *plus* propre que le ciblage RNG de SAP (que les joueurs critiquent, cf. le
perk Donut qui force le déterministe).

---

## 3. Mécaniques SAP *originales* vs Batomon (= le matériau anti-clone)

Ce que SAP a et que Batomon n'a **pas** — donc des ajouts qui ne nous feraient **pas** ressembler à Batomon. Triées
par **fit thématique grimdark** et **constructibilité sur l'existant** :

### ★★★ A — Économie de Mort / Réanimation (le candidat n°1)
SAP : **17 pets `Faint`** (effet *en mourant*) + **8 invocateurs** + tokens, qui se **chaînent** (Sheep→2 Rams,
Cricket→Zombie, Fly→Zombie Fly à chaque mort alliée, **Sleeping Pill** fait *faint* un allié *exprès*). Les unités
faint-buff rendent l'équipe **plus forte en mourant** — l'attrition inversée.
**Pour The Pit** : on a déjà `on_death` (mais seulement pour la propagation d'afflictions). On le pousse en
**économie de tokens** : une unité enfante un spawn 1/1 à la mort ; des unités « moisson » qui scalent quand un allié
tombe ; un objet « sacrifie un allié pour déclencher sa mort ». **Thématiquement PARFAIT** (grimdark, on descend Le
Puits, la mort est le sujet). **Vie-par-entité** est déjà notre modèle → les unités meurent déjà en combat : le
terreau est là, il manque l'op **`summon`** et 4-5 unités death-payoff.

### ★★★ B — Mimétisme / Copie (le pattern Tiger)
SAP : **Tiger** (répète l'ability du voisin), **Parrot** (copie), **Crab** (copie 50 % des PV du plus costaud),
**Whale** (avale un allié, le relâche au niveau du Whale). Value **non-locale** : une unité = fonction d'une autre.
**Pour The Pit** : op `repeat_ability` / `copy_effect` au front ou sur le voisin de graphe. Thème « mimétisme
eldritch » (une chose qui imite une autre = très Cthulhu). Du theory-craft pur, **absent des deux autres jeux** côté
Batomon. **Constructible direct** sur notre bus d'effets.

### ★★ C — Polarité positionnelle (devant/derrière qu'on ne peut pas tous satisfaire)
SAP : les buffs sont **directionnels** — un « buffeur-devant » (Dodo) veut être *derrière* le carry, un
« buffeur-derrière » (Flamingo) veut être *devant* → **on ne peut pas satisfaire les deux avec le même voisin** : le
placement **est** le puzzle. **Pour The Pit** : notre graphe 3×3 est une version *plus riche* ; la leçon est de rendre
nos effets **directionnels** (« l'unité **devant** dans la colonne », « la **ligne arrière** ») plutôt que juste
« adjacents ». Ça densifie l'axe position **sans** nouvelle techno (on a depth + graphe).

### ★★ D — Couche d'objets « Perk » (1 slot rare, qui pose un STATUT)
SAP : **17 foods**, dont une catégorie « perk » = **1 équipement par pet** (rare, **écrase** le précédent) qui pose
un **statut déclenché** : Garlic (−2 dmg/coup), Melon (bloque 20 une fois), **Coconut** (ignore *tout* un coup),
Mushroom (revit 1/1), Chili (splash sur le 2ᵉ ennemi). Plus profond qu'un +X jetable. **Pour The Pit** : si on ajoute
des items (Batomon en a 32, nous 0), **les faire à la SAP** — un slot d'équipement unique qui pose un **statut
persistant** (armure / splash / extra-vie / malédiction), pas un stat-stick. **2ᵉ axe de décision** distinct des
reliques.

### ★★ E — Freins lisibles : « N fois par combat » + Freeze
- **« Works N times per turn/battle »** = un **gouverneur uniforme et lisible** sur tout effet multi-déclenché
  (Snake ×5, Fly ×3, Hippo ×3). On a déjà un budget d'effets (256) ; **l'afficher en texte de carte** (« deux fois
  par combat ») rend l'équilibrage *lisible au joueur*. Adoption facile.
- **Freeze** : verrouiller une offre de boutique d'un tour à l'autre (pour la combiner/se l'offrir au revenu plein).
  Outil de **planification cross-turn** cheap et fort que notre boutique pourrait ajouter.

### ★ F — XP découplé du 3-en-1
SAP : on monte de niveau via **3 copies** *ou* via **Chocolate** (+XP) / Caterpillar. Le niveau n'est pas qu'un
3-en-1. **Pour The Pit** : une source d'XP alternative (objet, relique, événement) ouvrirait des lignes de build sans
dépendre du tirage de doublons.

---

## 4. Mécaniques de Batomon à emprunter (rappel, cf. doc 2-way)

Indépendantes de SAP, toujours valides — **leverage/coût** :
1. **★ Câbler les 5 types** (le moteur supporte déjà `aura_stat target="type:X"`) → axe identité mono-type/rainbow.
2. **★ 2-3 reliques méta-multiplicatrices** (sous nos caps) → combinatoire.
3. **Dégeler 2 sigils** (offerts en relique) → réactiver notre signature topologie.

> Note : le **type** (Batomon) et la **polarité positionnelle** (SAP) sont **complémentaires**, pas redondants —
> l'un est l'axe « *quoi* » (famille), l'autre l'axe « *où* » (placement). Les deux ensemble = la matrice de build.

---

## 5. Le plan ANTI-CLONE : le quadrant signature de The Pit

Comment être reconnaissable au premier coup d'œil, ni Batomon ni SAP :

**GARDER & AMPLIFIER (déjà unique au monde) :**
- **Combat = simulation d'afflictions qui se propagent** (contagion/propagation/conversion/aggravate) — *aucun* des
  deux autres n'a ça. SAP n'a **aucun DoT** ; Batomon n'a **aucune transmission**. **C'est notre cœur.**
- **Déterminisme + snapshots async** (partagé avec SAP, mais plus propre que leur ciblage RNG).
- **Commandants + whispers** (axes différenciateurs déjà à nous).
- **Plateau 3×3 non-euclidien mutable** (notre promesse — à **rallumer**).

**EMPRUNTER À SAP (original *vs* Batomon, et thématiquement nôtre) :**
- **★ Économie Mort/Réanimation** (tokens, faint-payoff, sacrifice) — *la* greffe signature.
- **★ Mimétisme / copie** (op `repeat_ability`).
- **Polarité positionnelle** (effets directionnels devant/derrière sur le graphe).
- **CAP → endgame de removal** (donner du sens à nos caps via un axe exécution/ciblage).
- **Soupape temp/permanent**, **Perk-slot à statut**, **gouverneur « N fois/combat » lisible**, **Freeze**.

**EMPRUNTER À BATOMON (profondeur pas chère) :**
- **Câbler les types**, **méta-multiplicateurs**, **sigils en récompense**.

**La phrase qui nous résume (et qui n'est ni Batomon ni SAP) :**
> *Un autobattler grimdark async où le combat est une **infection qui se propage** (poison/rot/feu qui sautent d'une
> entité à l'autre), où l'**on sacrifie et réanime** ses unités sur un **plateau non-euclidien mutable**, et où les
> gros chiffres finissent par céder à l'**exécution** et au **placement**.*

---

## 6. Roadmap d'ajouts originaux (priorisée)

> ⚠️ Observations de design — **pas** des décisions. Le passage aux mécaniques route par **autobattler-designer**
> (design + équilibrage théorique) → **love2d-engineer** (implé) + sims (`tools/sim.lua`). Ordre = leverage × fit
> thème × réutilisation de l'existant.

| # | Ajout | Source | Original vs | Coût | Pourquoi en premier |
|---|---|---|---|---|---|
| 1 | **Câbler les types** (mono/rainbow) | Batomon | — (Batomon l'a) | **faible** | moteur prêt (`aura_stat type:X`) ; débloque l'axe identité mort-né |
| 2 | **Économie Mort/Réanimation** (op `summon` + 5 unités faint-payoff + sacrifice) | SAP | **Batomon** | moyen | `on_death` + vie-par-entité déjà là ; **fit thème maximal** |
| 3 | **2-3 reliques méta-multiplicatrices** | Batomon+SAP | — | moyen | combinatoire « broken » ; sous nos caps |
| 4 | **Mimétisme** (`repeat_ability` / copie) | SAP | **Batomon** | moyen | tombe dans le bus d'effets ; thème eldritch |
| 5 | **Effets directionnels** (devant/derrière) | SAP | (les deux, version riche) | faible | densifie la position sans nouvelle techno |
| 6 | **Axe removal/exécution de fin** | SAP | **Batomon** | moyen | donne du sens à nos caps (`execute` existe) |
| 7 | **Items = Perk-slot à statut** + **Freeze** | SAP (+Batomon items) | partiellement | élevé | 2ᵉ axe de décision ; chantier neuf |
| 8 | **Dégeler 2 sigils** (en relique) | The Pit | (signature à nous) | moyen | rallume notre promesse topologie |

**Premier bloc conseillé** : **(1) types → (2) mort/réanimation → (3) méta-multiplicateurs**. Les trois réutilisent
l'existant et plantent le **quadrant signature** (identité + death-engine + combinatoire) sans rewrite.

---

## Annexe — sources & données
- Données brutes : `batomon/{monsters,trinkets,items}.json`, `sap/super-auto-pets-data.json`.
- Vues lisibles : `batomon/batodex-digest.md`, `sap/sap-digest.md`, doc 2-way `batomon/the-pit-vs-batomon.md`.
- The Pit : 3 extractions de code (unités+effets / reliques / synergies), juin 2026.
- SAP design (sourcé) : [composabilité a327ex](https://a327ex.com/posts/super_auto_pets_mechanics),
  [espace d'états mattkeeter](https://www.mattkeeter.com/projects/super/),
  [profondeur sans complexité](https://www.mobilegamereport.com/articles/super-auto-pets-depth-vs-casual-2026),
  [wiki officiel](https://superautopets.wiki.gg/). SAP est patch-volatile : *mécaniques* stables, *tier-lists* datées (juin 2026).
