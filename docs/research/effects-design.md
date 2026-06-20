# The Pit — Conception des effets & synergies (SYNTHÈSE MAÎTRE)

> Distille **4 recherches sourcées** (DoT, amplification/modificateurs, paliers de synergie,
> counterplay/équilibrage) en **un plan actionnable**. Document maître : pour le détail, voir
> `effects-dot-families.md`, `effects-amplification-modifiers.md`, `effects-synergy-tiers.md`,
> `effects-balance-counterplay.md`.
>
> **Statut** : proposition à valider (Kévin). Tous les chiffres = **PLACEHOLDERS** (équilibrage via
> `tools/sim.lua` + auto-itération). Objectif du créateur : *la valeur du jeu vient de la diversité et
> de l'intérêt des interactions entre effets* — profondeur émergente à partir de pièces simples.

---

## 1. L'insight unificateur : DEUX fondations débloquent TOUT

Les 4 recherches convergent sur **deux primitives manquantes**. Une fois posées, **chaque effet,
famille, relique devient de la DATA + un op** — jamais une édition de la boucle de combat.

### Fondation A — La COUCHE DE MODIFICATEURS (`src/effects/stats.lua`, SIM pure)
Une stat (dmg, valeur de bouclier, cd, aggro, **dégâts-pris**) n'est plus un nombre figé mais
`base + liste de mods`. Formule **vérifiée** (PoE *et* Last Epoch) :

```
final = clamp( (base + Σflat) · (1 + Σincreased) · Π(1 + more) )
```

- Les `increased` **s'additionnent** → **commutatif → ordre-indépendant → déterminisme GRATUIT** (pas
  de tri). Les `more` (rares) sont multiplicatifs. `flat` = à plat.
- `resolve(base, mods)` est **pur-SIM**, la stat de base n'est **jamais mutée** (compatible auras/snapshots).
- **Rétro-compat** : `mods = nil` ⇒ renvoie `base` ⇒ **golden-log inchangé**.
- **C'est le socle de** : le malus de poison (« −25 % valeur de bouclier » = un `increased` négatif), le
  CHOC (amplification = `increased` sur `damage_taken`), l'AGGRO modifiable (porte-étendard +aggro voisins).

### Fondation B — Le TICK DE STATUTS GÉNÉRALISÉ (`arena.lua`)
Aujourd'hui le tick du `poison` est **codé en dur** dans `update`. On le remplace par une **table de
statuts** `u.dots = { burn?, bleed?, poison=[stacks], rot? }` + une fonction `tickDots(u, frameDt)`,
**ordre fixe** (burn→bleed→poison→rot) pour le déterminisme. C'est **le seul bloc autorisé à grandir**
(comme la boucle de combat est fermée) : +1 famille = +1 branche **ici** + 1 op de pose. Borné (≈4-6
familles, pas 400).

> **Tout le reste est ouvert/fermé** : une famille = des ops `{trigger, op, params}` + des lignes de
> data + des clés i18n. **Zéro refacto** par effet. C'est la garantie demandée (« qu'on ne se retrouve
> pas dans 3 mois à ne plus pouvoir ajouter d'effets »).

---

## 2. La carte des familles d'effets (l'espace de contenu)

Principe-clé (sourcé PoE/Last Epoch/Grim Dawn) : **un DoT a 3 axes de stacking** (Intensité / Nombre /
Durée). **Donner un axe distinct à chaque famille = identité distincte sans règle nouvelle.**

| Famille | Axe | Identité (joué pour) | Signature | Bouclier | État |
|---|---|---|---|---|---|
| **BURN** (brûlure) | Intensité ↓ | burst / finish | décroît auto + **propage** aux voisins (graphe) | léché | neuf |
| **BLEED** (saignement) | Intensité+cond. | tempo / contrôle | **slow de cadence** + extra quand la cible agit | ignoré | neuf |
| **POISON** (venin) | **Nombre** (N stacks) | scaling / anti-stat | **malus de VALEUR** des capacités (−X %) | ignoré | **refactor v0** |
| **ROT** (pourriture) | Durée ↑ | usure / permanent | enfle si entretenue + **ampute les PV max** | ignoré | neuf (4ᵉ, proposé) |
| **SHOCK** (choc) | stacks (durée) | **amplification** | cible prend **+dégâts/stack** (cap, décroît) | — | neuf (client de A) |
| **SHIELD** (existant) | — | défense / déni | absorbe ; à étendre (regen, riposte) | — | à étendre |
| **AGGRO** (câblé-inerte) | stat | redirection de focus | tank tire le focus ; taunt = override dur | — | à **activer** |

**Tension d'archétype propre** : BURN (décroît) ⇄ ROT (croît) ; POISON (réduit le *taux* de soin) ⇄
ROT (réduit le *plafond* de soin) ; BLEED = le seul orienté **contrôle**. Choc + boucliers + aggro
couvrent amplification / défense / placement. Détail mécanique de chaque famille : voir les 4 docs.

---

## 3. Le moule des 3 paliers (T1 / T2 / T3) — la règle de variété

Validé et nommé sur du vocabulaire de design établi (StS « set-up/pay-off », PoE « keystone ») :

- **T1 = ENABLER** (5/famille) : applique l'effet nu. Lisible, « une seule chose » (règle MTG *New
  World Order*). L'amorce de synergie. *Ex. : une unité qui pose juste du poison.*
- **T2 = TWIST** (3/famille) : l'effet **+ une torsion/interaction**. *Ex. : le poison contamine
  l'allié qui shield la cible empoisonnée.* Peut être **conditionné par l'adjacence** (signature
  positionnelle).
- **T3 = TRANSFORM / KEYSTONE** (2/famille) : **redéfinit un archétype / clutch**. **Contrainte
  (correction de la recherche)** : les 2 T3 = **1 finisher + 1 pivot latéral** vers une AUTRE famille
  (ex. *la brûlure transfère le poison*), **jamais 2 finishers** (sinon « meta résolue »).

**Garde-fous (sourcés)** :
- **T1/T2 scalent par niveau** (duplicatas 3→niveau : stats + buff d'adjacence). **Le T3 ne scale QUE
  ses stats — jamais son seuil, sa bascule, ni son nombre de cibles** (anti double-snowball).
- **Aucun T3 ne dépend d'une case précise** (cassé au swap de sigil) — uniquement d'un *type* ou d'un
  *archétype topologique*. L'adjacence PEUT conditionner un T2.
- Catalogue réutilisable (dans `effects-synergy-tiers.md`) : **10 patterns de TWIST** (contagion par
  contact, propagation à la mort, conversion d'overkill, écho sur voisin, refresh, consume…) et
  **9 patterns de TRANSFORM** (conversion d'altération, « tout le type X gagne l'effet », payoff au
  seuil, trade-off keystone, fusion via sigil…). → un MOULE à remplir par famille.

---

## 4. La LOI du counterplay (non négociable)

**Jamais livrer une famille offensive sans son contre dans le MÊME lot.** Contres déterministes (zéro
dé, compatibles replay/async) :

| Famille | Contre jour-1 |
|---|---|
| DoT (tous) | **cleanse** (retire stacks/altérations), regen, immunité courte (« Intangible ») |
| BURN | patience (s'éteint), pare-feu (couper l'adjacence), gros heal burst |
| POISON | **purge de stacks** + **cap de stacks** (anti-explosion) |
| SHIELD | **pierce / bypass** + cleave |
| SHOCK / amp | **cleanse_stacks** + **cap dur** (`clamp` +200 %) + « less effect » sur cibles dures |
| AGGRO | **AoE-colonne** (ignore le guard, garde la colonne) + **strip de taunt** — *jamais le taunt seul* |
| vitesse | **haste additif + plancher de cd** |

**Anti-dégénérescence (sourcé)** : stacker en **durée, pas en intensité** (anti one-shot, façon StS
Vulnerable) ; `flat/increased/more + clamp` (anti explosion exponentielle) ; **once-per-cause + budget
de profondeur** (anti boucle A→B→A) ; altération = **valeur séparée** (anti double-dip).

---

## 5. Mesurer la santé (ce que `tools/sim.lua` doit gagner)

Au-delà du win-rate/unité actuel (tout calculable depuis l'event-log JSONL) :
- **Dégâts par FAMILLE** + ratio overkill (l'event-log attribue déjà `cause=burn/bleed/...`).
- **Co-occurrence `lift(i,j)`** = P(win | i&j) / (P(win|i)·P(win|j)) → **le détecteur de combos cassés**
  (la métrique-clé manquante).
- **Distribution de TTK** (médiane / p10 / p90) + taux de combats non-conclus.
- **Diversité méta** : Gini-Simpson `D = 1 − Σpᵢ²` + entropie normalisée (déjà là).
- **Planchers/plafonds** : alerte si une unité sort de **[0.45, 0.55]** de win-rate (IC95).

**Protocole d'auto-itération** : mesurer → diagnostiquer **un seul** dominant → bouger **UN** levier
(cd/hp d'abord ; bornes structurelles en dernier) → re-mesurer **même N/graine** → keep/revert. N=200-400
en dev, 2000-5000 pour verrouiller. Arrêt : σ(win-rate) sous seuil, entropie au-dessus, aucune unité
hors [0.45, 0.55], aucune paire à `lift` aberrant.

---

## 6. Plan d'implémentation par phases (chaque phase = vert + commit)

> Discipline : i18n pour chaque unité (trivial désormais) ; `sh tools/check.sh` vert avant commit ;
> chaque famille livrée **avec son contre** ; auto-itération sim après chaque famille.

- **Phase 1 — Fondation A (modificateurs)** : `src/effects/stats.lua` (`resolve` + buckets) + tests
  (`tests/stats.lua` : commutativité/déterminisme/clamp). Brancher la **lecture** de `dmg` et `valeur
  de bouclier` via `resolve` (mods vides ⇒ golden inchangé). **Aucune nouvelle unité.**
- **Phase 2 — Fondation B (tick généralisé)** + **refactor POISON** : `u.dots` + `tickDots()` ; le
  poison passe d'**écrasement** à **N stacks** + malus de valeur (1er client de A). Migrer `witch`.
  Mettre à jour golden (changement VOULU). **Vertical slice** : prouve toute la chaîne.
- **Phase 3 — Métriques sim** : dégâts par famille + co-occurrence `lift` + TTK-distribution dans
  `tools/sim.lua`. (Outil avant le contenu de masse → on équilibre dès la 1re famille.)
- **Phase 4 — Familles, une par une** (chacune : ops + ~10 unités 5/3/2 + son contre + auto-itération) :
  POISON (compléter le pool) → BURN (+propagation) → BLEED (+slow) → ROT (+amputation) → SHOCK (amp).
- **Phase 5 — AGGRO activée** : valeurs non nulles + archétype tank + taunt-relique + contres (quand
  les plateaux se remplissent, cf. dette `combat-model-decision.md`).
- **Transverse** : duplicatas 3→niveau (étape gameplay #2) s'imbriquent ici (T1/T2 scalent, T3 non).

---

## 7. Pool proposé (récap — détail dans les docs)

**~40 unités DoT** esquissées (10/famille, 5/3/2, noms EN provisoires, chiffres placeholders) dans
`effects-dot-families.md §H` — dont **4 T3 croisés** (feu→poison, sang→rot, poison→feu, rot→slow+malus).
**~10 unités SHOCK** (stackers / amplificateurs de valeur+cap / `more` rare) dans
`effects-amplification-modifiers.md`. Contres + reliques de cleanse/strip à puiser dans
`effects-balance-counterplay.md`. **À valider/élaguer avant d'implémenter** — on ne code pas 50 unités
à l'aveugle.

---

## 8. Questions ouvertes (à trancher avec Kévin)

1. **ROT** (4ᵉ DoT) : on l'inclut (axe Durée↑, anti-burn/anti-soigneur, très « Puits ») ou on s'en
   tient aux 3 nommés (burn/bleed/poison) ? *Reco : inclure.*
2. **Découpe d'implémentation** : **vertical slice** (2 fondations + poison refait + sim-metrics, on
   prouve la chaîne et les synergies, puis on étend au pool complet) — ou **big-bang** (tout le moule +
   ~40 unités d'un coup) ? *Reco : vertical slice.*
3. **Taille du pool en 1er jet** : pool COMPLET (10/famille) tout de suite, ou **slice représentatif**
   (≈3-4/famille à travers les paliers) pour prouver les synergies, puis production de masse ? *Reco :
   slice d'abord, on auto-itère, on étend quand c'est sain.*
4. Détails mécaniques à figer (listés par famille dans les docs) : brûlure 1-instance ; malus de poison
   = mange le bouclier courant + réduit le taux de soin ; cap de stacks ; amputation maxHp réservée T2+.

> Voir aussi : les 4 docs de recherche · `engine-architecture.md` §12 (file d'attente d'effets, budget
> anti-boucle, buckets) · `combat-model-decision.md` (aggro différée).
