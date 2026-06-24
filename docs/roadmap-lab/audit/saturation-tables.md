# Tableaux de saturation — `inc` par famille × arêtes par sigil

> **Rôle.** Réalise la précondition **#B** du `ROADMAP.md` (« 2 tableaux combinatoires, **0 sim**, AVANT
> P1/gravure des types »). Tout est **code-vérifié** (lecture seule). Aucune valeur n'est supposée.
>
> **Sources.** `inc`/cap : `src/effects/ops.lua`, `src/effects/stats.lua`, `src/data/relics.lua`,
> `src/data/units.lua`. Arêtes/exposition : `src/board/shapes.lua`, `src/board/board.lua`,
> `src/combat/place.lua`, `src/scenes/build.lua`. Audit produit en P0.5 (roadmap-lab, exécution).

---

## 1. Saturation des ARÊTES (sigil × slots débloqués)

Une **arête est active** si ses **deux** extrémités sont ouvertes (l'aura ne se bake que si le slot voisin
est posé — `build.lua:506-507`). Paliers de déblocage = ceux du **jeu réel** (cluster connexe central via
`board.lua:bestEmptyCell`/`ensureOpen`, l.61-91), pas le préfixe d'index.

| sigil | 3 slots | 5 slots | 7 slots | 9 slots | total arêtes | densité@7 (arêtes/slot) |
|---|---|---|---|---|---|---|
| **carré** | 2 | 4 | 7 | **12** | 12 | 1,00 |
| **diamant** | 2 | 4 | 7 | **12** | 12 | 1,00 |
| **anneau** | 2 | 4 | 6 | 9 | 9 | 0,86 |
| **croix** | 2 | 4 | 6 | 8 | 8 | 0,86 |
| **ligne** | 2 | 4 | 6 | 8 | 8 | 0,86 |

**Verdict #B (arêtes) — précondition DÉCHARGÉE.** Aucune combinaison sous le seuil d'alarme `< 0,3` à 7 slots
(minimum réel **0,86**). L'heuristique de cluster connexe (`board.lua:67`, `conn*100`) maximise la connexité à
chaque ouverture → même la **ligne** (pire cas topologique) reste connexe. **Prescrire une aura par-famille sur
n'importe quel sigil est structurellement sain** côté densité d'arêtes (feu vert anticipé pour P1).

> ⚠ **Piège sim (load-bearing).** Cette grille suppose la sémantique **`ensureOpen`** (jeu réel). Les
> tests/sim/`compositions.lua` ouvrent via **`Board:unlock(n)` = préfixe d'index 1..n** (`board.lua:97-101`) →
> pour **carré/croix/diamant**, le sous-ensemble actif diffère (potentiellement moins connexe en early). Quand
> on étendra `tools/sim.lua` pour `--position-variance`, **utiliser la sémantique `ensureOpen`**, sinon on
> mesure une mauvaise topologie. (Pour anneau/ligne, la numérotation suit déjà l'ordre de chaîne → identique.)

### Portée d'aura = degré du slot (la vraie métrique de synergie positionnelle)

Une unité-aura buffe **exactement ses voisins de graphe**. Sa portée = son **degré** dans le sigil :

| sigil | degré max (case-hub) | où | profil d'archétype |
|---|---|---|---|
| carré | **4** | centre (1,1) | hub d'aura central, front en colonne de 3 |
| croix | **4** | centre (2,2) | **mono-carry** : 1 hub à 4 voisins, le reste en file |
| diamant | **4** | centre (2,2) | hub central + ailes (go-wide) |
| anneau | **2** | partout (graphe régulier) | **propagation/contagion**, pas d'empilement d'aura |
| ligne | **2** | les 7 internes | **conduit** (propagation en chaîne), pas d'aura simultanée |

→ Les auras **porteuses d'`inc`** (burn/poison, cf. §2) culminent à **4 voisins** sur carré/croix/diamant
(case-centre) et plafonnent à **2** sur anneau/ligne. **Lecture design** : carré/croix/diamant = sigils
« empilement d'aura » ; anneau/ligne = sigils « propagation » (mort/contagion, où la valeur vient de la chaîne,
pas du nombre de voisins simultanés). Cohérent avec l'intention « **1 forme = 1 archétype** » (CLAUDE.md §3).

---

## 2. Saturation `inc` (famille DoT × sources cumulables)

**Cap dur global** : `DOT_CAP_MULT = 3` (`ops.lua:22`). Toute pose amplifiée est bornée par
`ampDps(base, inc)` à **`base × 3`** (`ops.lua:29-32`) — quel que soit l'`inc` cumulé. La formule `increased`
est **additive** (`stats.lua:39-45` : `(base+flat)·(1+Σinc)·Π(1+more)`). Chaque source écrit dans **un seul
champ scalaire** `spec[family.."Inc"]` par `+=` (relique `relics.lua:87-89` ; aura build-résolue, même champ).

| famille | relique-ampli (B) | aura d'adjacence | autres | **plafond `inc` naturel** | risque |
|---|---|---|---|---|---|
| **burn** | `ember_heart` +0,30 (`relics.lua:27`) | `soot_acolyte` `aura_burn_dps` +0,50/voisin (`units.lua:148-151`) | `everburn` = **flag** (no-decay), pas `inc` | **0,30 + 0,50·N** (0,80 @1 aura) | modéré |
| **poison** | `kings_bowl` +0,20 (`relics.lua:26`) | `miasma_acolyte` `aura_poison_dps` +0,50/voisin (`units.lua:156-158`) | `festering` = **flag** d'équipe (no-cap) | **0,20 + 0,50·N** (0,70 @1 aura) | **ÉLEVÉ** |
| **bleed** | `weeping_nail` +0,18 (`relics.lua:28`) | `clot_mender` = bleed **flat** + slow, **aucun `inc`** (`units.lua:152-154`) | — | **0,18** | faible |
| **rot** | `grave_cap` +0,18 (`relics.lua:29`) | `decay_tender` = **growth** (vitesse), **aucun `inc`** (`units.lua:160-162`) | — | **0,18** | faible |
| **shock** | **aucune** | **aucune** | volt/add/cap/chain/transfer/persist (modificateurs **discrets**) | **0** | non saturable par `inc` |

**Verdicts #B (`inc`) :**
- **Poison = famille à surveiller.** 1 relique + 1 aura voisine = **0,70** d'`inc`, et l'ampli relique est
  délibérément conservateur (0,20 vs 0,30 burn) car le code vise poison comme **apex** (`relics.lua:25`). Tout
  ajout `inc`/`more` poison (ex. `resonance_stone`, `ring_hunger` sur l'anneau) doit **entrer dans ce tableau
  avant gravure** — le cap ×3 borne la **magnitude par pose**, **pas** l'`inc` lui-même.
- **Shock n'est pas saturable par `inc`** (0 source). Il se renforce par modificateurs **discrets** → l'apex
  choc « axe D » (M2/2.3) amplifie le 1er **tick DoT** de la `dot_family` du poseur, hors de cette voie. **Trou
  réel** : aucune relique d'ampli `inc` choc (groupe B couvre 4 familles sur 5).
- **bleed/rot sont « plats »** côté `inc` (0,18, sans aura `inc`). Leur scaling passe par d'autres axes (bleed :
  `BLEED_DPS_CAP=12` enfle avec l'`inc`, `ops.lua:28,146` ; rot : `rotInc` enfle base **et** capDps,
  `ops.lua:178-179`). Pour P1, **ne pas** leur prêter le profil de saturation de burn/poison.

---

## 3. Croisé — appétit d'adjacence × densité de sigil (où NE PAS prescrire une aura en P1)

Familles avec **aura d'adjacence** (donc sensibles à la topologie) : **burn, poison** (porteuses d'`inc`),
**bleed, rot** (auras flat/growth). **Shock = aucune adjacence** (ne lit jamais le graphe).

| famille | aura | meilleur sigil (degré-hub 4) | sigil hostile | note P1 |
|---|---|---|---|---|
| burn | `soot_acolyte` (+inc) | carré/diamant (4 voisins) | ligne/anneau (2) | aura `inc` → veut le hub-4 |
| poison | `miasma_acolyte` (+inc) | carré/diamant | ligne/anneau | **+ surveiller la saturation `inc`** |
| bleed | `clot_mender` (flat+slow) | carré/croix/diamant | — | flat → topologie peu sensible |
| rot | `decay_tender` (growth) | carré/croix/diamant | — | growth → peu sensible à N voisins |
| shock | — | (indifférent) | (indifférent) | propagation par `shockChain`, pas adjacence |

**Pas d'alarme dure** (toutes les densités@7 ≥ 0,86), donc **aucune prescription d'aura n'est interdite** en P1.
Le vrai signal est plus fin : les auras `inc` (burn/poison) **rendent le plus** au **centre degré-4** de
carré/croix/diamant et **le moins** sur anneau/ligne (degré 2) → en P1, le twist de palier de famille devrait
**récompenser le profil naturel** (burn/poison = empilement central ; anneau/ligne = propagation). C'est une
**orientation**, pas une exclusion.

---

## 4. Exposition (`depth = maxCol − cell.x`) — colonnes vs file unique

`chooseTarget` cible le `depth` **minimal** (colonne avant) → override taunt → aggro → tie-break haut→bas
(`arena.lua:184-211`). `depth = maxC − cell.x`, `maxC` relatif à la **compo posée** (`place.lua:39`,
`build.lua:599`).

| sigil | colonnes (depths distincts) | front | `cell.x` flottant ? | profil |
|---|---|---|---|---|
| **carré** | **3** (×3 cases) | colonne de 3 | non | **sain** — seul vrai front en colonne |
| croix | 5 | 1 case (pointe droite) | non | éventail, front mono-case |
| diamant | 5 | 1 case (pointe droite) | non | losange, front mono-case |
| **anneau** | **9 (fractionnaires)** | 1 case | **OUI (tous, 0,03→4,37)** | **DÉGÉNÉRÉ — file unique** |
| **ligne** | **9 (entiers 0..8)** | 1 case | non (mais tous distincts) | **file unique (par étalement)** |

**Dettes confirmées (CLAUDE.md).** **anneau** (cause = `cell.x` trigonométrique flottant, `shapes.lua:51-54`)
et **ligne** s'épluchent **une case à la fois** → pas de « première ligne » de 3. Seul le **carré** offre de
vraies colonnes. L'epsilon de `neighborsOf` (`arena.lua:214`) existe pour rattraper ces `depth` fractionnaires.

**Impact roadmap :**
- **P0 carte de risque (item 1.2)** : le rendu front/back est **net sur carré**, **trompeur sur anneau/ligne**
  (la « colonne avant » y est une seule case mouvante). À gérer dans le RENDER (afficher l'ordre d'épluchage,
  pas une colonne fictive).
- **M7 reliques positionnelles** : `ring_hunger` (récompense l'anneau) doit composer avec ce profil en file —
  c'est précisément l'« archétype qui aime la forme ». `axis_pact` (axes) rend mieux sur carré/croix.

---

## 5. Récapitulatif des verdicts de précondition

| Précondition (roadmap) | État | Détail |
|---|---|---|
| **#B — saturation des arêtes** | ✅ **déchargée** | min 0,86@7 slots, aucune alarme < 0,3 ; auras prescriptibles partout |
| **#B — saturation `inc`** | ⚠ **poison = watch** | 0,70 @1 aura ; cap ×3 borne la magnitude, pas l'`inc` ; tout ajout poison passe par ce tableau |
| Choc saturable par `inc` ? | ❌ **non** (0 source) | apex « axe D » hors `inc` ; trou de relique B choc |
| Données pour reliques positionnelles (M7) | ✅ **prêtes** | arêtes + degrés + exposition par sigil tabulés ci-dessus |
| Profil d'exposition par sigil | ⚠ **2 dégénérés** | anneau (flottant) + ligne (étalement) en file unique ; carré seul sain |

## 6. Suivi (sim, quand on étendra `tools/sim.lua`)

1. **`--position-variance`** : mesurer le win-rate des auras par sigil **en sémantique `ensureOpen`** (pas
   `unlock`). Calibre la valeur réelle des auras `inc` au hub-4 vs degré-2.
2. **Saturation `inc` dynamique** : quand `resonance_stone`/`ring_hunger`/`venom_covenant` seront spécifiées,
   recalculer la colonne « plafond `inc` naturel » poison/burn **avant** gravure (garde-fou cap ×3).
3. **Exposition** : si un sigil « ligne/anneau » reçoit un twist de palier, vérifier qu'il récompense la
   **propagation** (chaîne) et non l'empilement d'aura (degré 2 plafonné).
