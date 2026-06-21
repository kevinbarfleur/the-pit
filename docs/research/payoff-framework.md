# The Pit — Framework PAYOFF : effet de BASE vs effet RENFORCÉ (afflictions · boucliers · auras)

> **Statut** : spec actionnable (2026-06). RÉVISE — sans la jeter — l'anti-double-snowball de
> `effects-design.md` §3-4. Tous les chiffres sont des **placeholders d'équilibrage** à confirmer via
> `tools/sim.lua`, MAIS les **caps** ci-dessous sont des bornes de **conception** (à garder même si on
> retune les magnitudes).
>
> **Ne modifie aucun fichier de gameplay** : ce doc SPÉCIFIE, l'implémentation est faite par Kévin.
> Tous les triggers/ops/champs cités sont vérifiés contre le code réel (`src/effects/ops.lua`,
> `src/effects/stats.lua`, `src/combat/arena.lua` `tickDots/damage/hit/dischargeShock`,
> `src/scenes/build.lua` résolution d'aura).

---

## 0. Le diagnostic (mesuré) et la réponse

**Problème** : les effets « payoff / renforcés » sont mécaniquement faibles donc anti-climatiques.
- Poison base = **6 dmg/stack** (9 avec aura miasma). La CONTAGION (`spread`) = **2 dmg/voisin**
  (1 dps × 120 f), **sans** bénéficier de l'aura → ~22-33 % du vrai effet.
- Feu/pourriture `spread` = **8 dmg/voisin** mais **uniquement à la mort** → quasi jamais vu.
- Macro (sim 150 combats) : **DoT = 22 %** des dégâts, **frappe directe = 78 %**.

**Principe directeur (user)** : « dès qu'un joueur pose une pièce qui RENFORCE un effet, il doit le
SENTIR tout de suite — chiffres, visuel, résultat. Renforcé ≠ base+un peu ; renforcé = une chose
visiblement différente et plus forte. »

**Réponse en une phrase** : on définit un **contrat unique base→renforcé** pour les trois systèmes
(afflictions/spread, boucliers, auras), où chaque pièce de renforcement applique un **palier de saut**
(step) — pas un +5 % — exprimé via la couche de modificateurs (`increased`/`more`/`flat`), borné par
un **cap explicite par axe**, et accompagné d'un **signal « ça s'allume »** (événement bus →
RENDER + nombre + couleur).

---

## 1. Le contrat unique « BASE vs RENFORCÉ » (modèle général)

### 1.1 Définitions

- **BASE** = l'effet nu posé par un enabler (T1). Lisible, une seule chose. Doit rester **modeste**.
- **RENFORCÉ** = l'état d'un effet **après ≥1 pièce de renforcement** (aura, transform, relique,
  duplicata, condition d'adjacence). Doit être **catégoriquement** plus fort, pas incrémentalement.

### 1.2 La règle des PALIERS DE SAUT (« step, pas trickle »)

Chaque pièce de renforcement appartient à **un AXE** et applique un **STEP** discret sur cet axe :

| Axe (générique) | Comment c'est exprimé (moteur) | STEP typique (placeholder) | CAP de l'axe |
|---|---|---|---|
| **Magnitude** (dps / valeur) | `increased` cumulés sur la stat | **+50 %** par pièce | **+200 %** (×3) |
| **Multiplicateur rare** | `more` (Π) — réservé aux T3/reliques | **+50 %** (×1.5) | **2 pièces max** (×2.25) |
| **Portée / largeur** (aura, spread) | +1 case de rayon OU +1 voisin | **+1** | **+2** (rayon 3 / 2 sauts) |
| **Cadence** (cooldown d'aura, pose) | `increased` négatif sur le cd | **−25 %** | **−50 %** (plancher) |
| **Durée** | `flat`/`increased` sur `remaining`/`dur` | **+50 %** | **+150 %** |
| **Conversion / nouvelle propriété** (réflexion, surcharge, croisement) | nouveau comportement (flag) | **on/off** | **1 par effet** (pas d'empilement) |

> **Pourquoi un STEP de +50 % et pas +5 %** : le joueur doit voir le nombre **changer de catégorie**.
> +50 % sur 6 dps = 9 → puis 12 → puis 18 (cap +200 % = ×3). Trois pièces = triple, pas « un peu plus ».

### 1.3 Le GARDE-FOU central (anti-snowball, révisé mais pas jeté)

L'ancien design interdisait quasiment l'amplification. On le **remplace** par **3 verrous chiffrés** :

1. **CAP par axe** (table ci-dessus) — appliqué via `Stats.resolve(base, mods, { max = … })`. Au-delà,
   les pièces supplémentaires **n'ajoutent plus de puissance** (mais peuvent ajouter de la *largeur* ou
   de la *durée* — on canalise le surplus vers un autre axe, pas vers l'infini).
2. **CAP global de renforcement par cible** : la somme des `increased` lus sur **une instance d'effet**
   est clampée à **+200 %** (×3) **quelle que soit** la provenance (aura + transform + relique).
   Empêche le stacking multi-source de péter le cap par-axe.
3. **once-per-source sur les sauts de spread** (cf. §2.4) : une contagion ne se re-propage pas vers une
   case déjà infectée par la **même source** ce combat → pas de boucle A→B→A→B.

> **Le snowball qu'on AUTORISE désormais** : un build dont **tout** est dédié à un axe atteint le cap
> (×3, rayon 3). C'est **fort et lisible**, pas infini. Le snowball qu'on **interdit** : exponentiel
> (more empilés sans limite), ou bouclant (spread sans once-per-source), ou multi-dip (la même pièce
> compte deux fois). La différence : un **plafond atteignable** vs une **courbe sans asymptote**.

---

## 2. AFFLICTIONS & SPREAD

### 2.1 Base→renforcé (afflictions de tick)

Aujourd'hui le tick lit `dps` brut (`b.acc + b.dps*frameDt/60`). On garde ça, mais le `dps` posé/baké
doit passer par `Stats.resolve` pour exprimer les renforcements proprement.

- **BASE** : enabler pose `{ dps = D, dur = T }`. (poison 6, burn 8 décroissant, etc.)
- **RENFORCÉ** : `dps_final = resolve(D, mods, { max = D*3, round="nearest" })` où `mods` =
  - aura de famille (`miasma_acolyte`/`soot_acolyte`/`decay_tender`) → `increased +0.50` **par niveau-pièce**,
  - transform d'équipe (`festering`/`ash_maw`/`pit_maw`) → axe **Durée/cap**, PAS magnitude (sépare les axes),
  - relique d'amplification → `increased` (commun) ou `more` (rare, 1 max).

> **Point CLÉ corrigé** : actuellement l'aura est bakée en `flat +bonus` sur le `dps` du voisin
> (`build.lua:347` `aura_*_dps`). C'est OK mais ça **n'amplifie pas le spread**. On change la sémantique :
> l'aura devient un **`increased` stocké sur l'unité** (ex. `u.poisonInc = 0.50`) lu à la fois par la
> pose normale ET par la pose de spread. Ainsi **le spread hérite de l'amplification** (résout le
> « SANS bénéficier de l'aura → 22-33 % »).

### 2.2 SPREAD proportionnel à l'investissement (décision user #3)

Le spread n'est plus une valeur fixe (2 ou 8). Il est **dérivé de l'état affligé de la SOURCE** (la
case qui transmet), borné :

```
spreadDps = clamp( ceil( sourceLoad × SPREAD_FRAC ), SPREAD_MIN, SPREAD_CAP )
```

où **`sourceLoad`** dépend de la famille (= « combien la source est investie ») :

| Famille | `sourceLoad` (mesure d'investissement) | SPREAD_FRAC | SPREAD_MIN | SPREAD_CAP |
|---|---|---|---|---|
| **POISON** (contagion à la frappe, `plague_bearer`) | **Σ dps des stacks de poison de la SOURCE** (la case frappée transmet son propre fardeau) | **0.60** | 3 | **12** |
| **BURN** (mort en feu, `wildfire_hound`) | **dps de burn du mort** | **0.75** | 4 | **14** |
| **ROT** (mort pourrie, `blight_spreader`) | **dps de rot du mort** (déjà « enflé ») | **0.75** | 4 | **14** |
| **CROSS feu→poison** (`plague_pyre`) | burn du mort → burn voisin (frac 0.75) **+** seed poison `= ceil(burn×0.35)` cap 8 | — | — | feu 14 / poison 8 |

**Conséquences voulues** :
- Plus la source est chargée (stacks nombreux, dps ampli par aura), plus la contagion est grosse →
  **on SENT l'investissement**. Une `plague_bearer` posée seule transmet ~3-4 ; entourée d'auras et de
  stackers, elle transmet jusqu'à **12** (×3-4 vs aujourd'hui).
- Le **CAP** (12/14/8) empêche le snowball : même une source ultra-chargée ne transmet jamais un
  one-shot de voisinage.

> **Chiffres avant/après (poison contagion)** : aujourd'hui spread = **2 dmg/voisin** (1 dps × 120 f).
> Demain, source à 3 stacks ampli (≈9 dps chacun = 27 de load) → spread = clamp(ceil(27×0.60),3,12) =
> **12 dps** sur la durée du stack le plus court → **~24 dmg/voisin** sur 120 f. **×12**. Et c'est
> **cappé** : 10 stacks ne donnent pas 60, ils donnent 12.

### 2.3 Le SPREAD doit aussi durer assez pour être VU

Le spread actuel hérite parfois d'une durée de 120 f (2 s) ce qui passe inaperçu. On fixe :
`spreadDur = max(120, sourceDur × 0.66)` cap 240 f. La contagion vit assez longtemps pour tick **et**
pour être lue à l'écran.

### 2.4 Garde-fous spread (caps explicites)

- **`SPREAD_CAP`** par famille (table §2.2) : 12 (poison) / 14 (burn,rot) / 8 (poison seed du pyre).
- **once-per-source-per-combat** : sur chaque unité, `u.infectedBy[sourceId][family] = true`. Une
  contagion ne se re-pose pas si la même source l'a déjà infectée → **brise la boucle A→B→A**.
  (Déterministe, zéro RNG. Coût mémoire borné : ≤ unités×familles.)
- **profondeur de saut = 1** : la contagion ne re-déclenche PAS la contagion (le voisin infecté par
  spread ne propage pas à son tour). Sauf relique-keystone explicite (futur), jamais par défaut.
- **pas de dégât immédiat au spread** (déjà le cas) : on ne pose que du DoT, jamais un burst → pas de
  cascade de morts en chaîne dans la même frame.

### 2.5 Le signal « ça s'allume » (afflictions)

Le bus émet déjà `spread {from, to, family}` (golden-safe : aucun abonné SIM). On enrichit le payload
pour que le RENDER fasse une transmission **visiblement plus grosse quand c'est gros** :

```
bus:emit("spread", { from, to, family, magnitude = spreadDps, capped = (spreadDps >= CAP) })
```

- RENDER : épaisseur/longueur/vitesse de l'arc ∝ `magnitude` ; `capped == true` → arc **saturé** (flash
  blanc en cœur, le signe « tu as maxé cet axe »). Couleurs déjà prévues : poison vert, feu orange,
  pourriture violet (cf. mémoire affliction-vfx).
- **Nouveau signal d'amplification de POSE** (pas seulement de spread) : quand une pose lit un `mods`
  non-vide (l'effet est renforcé vs base), émettre `bus:emit("amped", { unit=victim, family, mult })`
  pour un **liseré de couleur** sur le nombre de DoT (le « 12 » sort en gras coloré, le « 6 » non).
  Golden-safe (aucun abonné SIM).

---

## 3. BOUCLIERS (intègre l'exemple user)

### 3.1 État actuel & le manque

Aujourd'hui : `shield_aura` (op `combat_start`, `target=neighbors`) baké en **valeur flat** sur le
voisin au build (`build.lua:346`) ; le bouclier est un nombre absorbé dans `Arena:damage`
(`arena.lua:192`). C'est **un one-shot au début du combat** : pas de re-cast, pas de réflexion, pas de
largeur modulable. → aucun « renforcé » lisible.

### 3.2 Modèle base→renforcé (les 5 renforcements de l'exemple user)

On introduit un **bouclier PÉRIODIQUE** : une unité re-shield ses voisins toutes les N secondes. C'est
le socle qui rend les 5 renforcements lisibles.

> **CONTRAINTE MOTEUR (nouveau trigger)** : le bouclier périodique nécessite un tick côté arène. On
> AJOUTE un bloc dans `Arena:tickDots` (ou un `Arena:tickAuras` parallèle, ordre fixe) qui décrémente
> un cooldown par porteur et re-applique le shield. **Pas un nouveau trigger** au sens du registre —
> c'est de la donnée `u.shieldCaster = { value, cd, cdLeft, targets, reflect?, overcharge? }` posée au
> `combat_start` et tickée. Les **cibles** (voisins de plateau) sont **résolues au build** (comme
> aujourd'hui) et **figées** dans `u.shieldCaster.targets` (liste de réfs d'unités) → l'arène n'a pas
> besoin du graphe de sigil. Déterministe, ordre array+ipairs.

| # | Renforcement (exemple user) | Axe | Comment (moteur) | BASE → RENFORCÉ (placeholder) | CAP |
|---|---|---|---|---|---|
| a | **+valeur du bouclier** | Magnitude | `increased` sur `value` du caster | 20 → 30 → 40 → 60 | **×3 (60→… cap +200 %)** |
| b | **ÉLARGIR l'aura** (plus de cases) | Portée | +1 voisin résolu au build (rayon 2) | 1 anneau → 2 anneaux | **rayon 2** (jamais tout le plateau) |
| c | **RÉFLEXION** (thorns sur shield) | Conversion | flag `reflect = frac` ; à l'absorption, `Arena:damage(attacker, absorbed×frac, {ignoreShield})` | off → **renvoie 40 %** de l'absorbé | **frac ≤ 0.60** |
| d | **−cooldown** (re-cast plus vite) | Cadence | `increased` négatif sur `cd` | 4 s → 3 s → 2 s | **plancher 2 s** |
| e | **SURCHARGE** (overcharge) | Conversion | flag `overcharge` : le shield non-consommé au prochain cast **ne s'efface pas, il s'ajoute** (cap) au lieu d'être remplacé | off → cumul jusqu'à **2× la valeur** | **cap = 2× value** |

### 3.3 Pourquoi chaque renforcement « se SENT »

- **a** (valeur) : le nombre de bouclier au-dessus de la tête double/triple — visible direct.
- **b** (largeur) : 2 alliés protégés → 4. À l'écran, l'aura passe d'1 anneau à 2. Décision de
  PLACEMENT qui change (l'axe le plus « positionnel »).
- **c** (réflexion) : l'attaquant **prend des dégâts en frappant le bouclier** → nombre rouge sur
  l'attaquant + son `on_attacked` n'est même pas requis (c'est le shield qui mord). Très lisible vs
  une muraille inerte.
- **d** (cd) : le bouclier **réapparaît visiblement** plus souvent (pulse). Le contraste base (1 cast)
  vs renforcé (pulse régulier) est énorme.
- **e** (surcharge) : un bouclier qui **gonfle** au fil des casts non-consommés → un mur qui devient
  énorme contre un adversaire lent. Le cap 2× empêche l'invincibilité.

### 3.4 Garde-fous boucliers (caps explicites)

- **value cap** : `resolve(value, mods, { max = base×3 })`.
- **rayon cap** : 2 (résolu au build ; le code de `b.neighbors` fait déjà 1 ; rayon 2 = voisins-de-voisins,
  borné, pré-calculé une fois).
- **reflect cap** : `frac ≤ 0.60` (jamais 100 % — pas de mur-miroir invincible).
- **cd plancher** : `max(2 s, cd×(1+Σinc))` (anti-spam de boucliers permanents).
- **overcharge cap** : stock ≤ `2× value` (anti boule-de-neige défensive).
- **counterplay obligatoire (loi du même lot)** : `acid_maw` (venin mange −30 %/pose) et `pierce`
  existent ; ajouter une **relique strip-shield** ou un **cleave qui ignore le bouclier** si on pousse
  la famille (cf. `effects-design.md` §4 SHIELD : pierce/bypass + cleave).

### 3.5 Signal « ça s'allume » (boucliers)

- À chaque re-cast périodique : `bus:emit("shield_cast", { caster, targets, value, capped })`.
- À une absorption avec `reflect` : `bus:emit("reflect", { from=attacker, by=target, amount })` →
  arc épines depuis le bouclier.
- À une surcharge (stock > value) : `bus:emit("overcharge", { unit, stock })` → halo qui grossit.
- Tous golden-safe (aucun abonné SIM ; mêmes garanties que `spread`).

---

## 4. AURAS (modèle général, source du renforcement)

### 4.1 Le pivot d'architecture (résout le bug du spread non-ampli)

**Aujourd'hui** : l'aura baque un `flat +bonus` directement dans le `dps`/`growth` du voisin
(`build.lua` `auraEffects`). Conséquence : la pose normale est bufée, **mais le spread (qui relit l'état
de la source en combat) NON**.

**Demain** : l'aura baque des **MODS sur l'unité** (pas une mutation du dps), stockés en champ lisible :
`u.fam_inc[poison|burn|rot|bleed] = Σ increased` (et `u.shieldInc`, `u.shield_radius`, etc. pour les
boucliers). Le tick et **toutes** les poses (normale **et** spread) lisent ce champ via `Stats.resolve`.
→ **l'amplification suit l'effet partout**, y compris dans la contagion.

> Compat : si `u.fam_inc.poison == nil` → `resolve(base, nil)` = base → **golden inchangé** tant
> qu'aucune aura n'est posée. L'adoption reste progressive (ouvert/fermé respecté).

### 4.2 Les axes d'aura (mêmes paliers que §1.2)

| Op d'aura (nouveau nom suggéré) | Axe | STEP | CAP | Lu par |
|---|---|---|---|---|
| `aura_fam_inc` (remplace `aura_*_dps`) | Magnitude | `increased +0.50` | +200 % (clamp à la lecture) | pose + tick + **spread** |
| `aura_fam_dur` | Durée | `increased +0.50` sur `dur` | +150 % | pose |
| `aura_radius` (boucliers/auras) | Portée | +1 case | rayon 2 | résolution build |
| `aura_cdr` (boucliers périodiques) | Cadence | `increased −0.25` | plancher | tick shield |

### 4.3 Garde-fous auras

- **cap par axe à la LECTURE** (`Stats.resolve(..., {max})`), pas à l'écriture : empiler 4 auras est
  permis, mais l'effet plafonne à ×3 → pas de refacto si on ajoute des sources.
- **cap global de renforcement par instance** = +200 % toutes sources confondues (§1.3 verrou 2).
- **les auras restent build-résolues** (graphe du sigil) → swap de sigil re-cible tout seul, snapshot
  capture l'état dérivé. (Pas de calcul d'aura en combat → arène autonome préservée.)
- **scaling par niveau (duplicatas)** : l'aura scale déjà avec `LEVEL_MULT` (build.lua:340). On garde —
  MAIS le cap par-axe s'applique APRÈS le niveau (un T1/T2 aura niv 3 peut à lui seul approcher le cap).

### 4.4 Signal « ça s'allume » (auras)

- L'aura est **build-time** → le signal est dans la phase BUILD (pas de bus combat) : surligner en
  couleur de famille les voisins bénéficiaires + afficher le **delta chiffré** sur leur infobulle
  (« poison 6 → 9 »). C'est le « tu viens de poser une pièce qui renforce → tu le vois immédiatement »
  au moment du placement, **avant même** le combat. (UI build, pas SIM.)
- En combat, le bénéfice se voit via le signal `amped` (§2.5) sur les nombres de DoT.

---

## 5. Tableau de synthèse des CAPS (le garde-fou, d'un coup d'œil)

| Système | Axe | STEP/pièce | CAP dur | Mécanisme du cap |
|---|---|---|---|---|
| Affliction (dps) | Magnitude | +50 % | **+200 % (×3)** | `resolve(base, mods, {max=base*3})` |
| Affliction (dps) | `more` rare | +50 % | **2 pièces (×2.25)** | data : ≤2 reliques `more` |
| Spread poison | proportionnel | frac 0.60 | **12 dps** | clamp(SPREAD_MIN, SPREAD_CAP) |
| Spread burn/rot | proportionnel | frac 0.75 | **14 dps** | clamp |
| Spread (anti-boucle) | profondeur | — | **1 saut, once-per-source** | `u.infectedBy` |
| Bouclier | valeur | +50 % | **×3** | `resolve(value, mods, {max})` |
| Bouclier | rayon | +1 | **rayon 2** | build-résolu, borné |
| Bouclier | réflexion | on/off | **frac ≤ 0.60** | clamp data |
| Bouclier | cd | −25 % | **plancher 2 s** | `max(2, cd×(1+inc))` |
| Bouclier | surcharge | on/off | **stock ≤ 2× value** | clamp tick |
| Aura | toutes | cf. §4.2 | cap à la LECTURE | `resolve {max}` |
| Renforcement global | toutes sources | — | **+200 % / instance** | clamp somme des inc |

---

## 6. Ordre de livraison conseillé (chaque étape = vert + commit + sim)

> Chaque étape doit laisser `sh tools/check.sh` vert et le golden inchangé **tant qu'aucune unité
> n'active la nouvelle voie** (mods vides = base). On mesure avec `tools/sim.lua` après chaque étape :
> part du DoT (cible : passer de 22 % vers ~40-45 %), distribution TTK, `lift` (combos cassés).

1. **ÉTAPE 1 — Aura→mods (le pivot, débloque tout)** : remplacer le bake `flat` de `aura_*_dps` par un
   champ `u.fam_inc[family]` ; brancher la **lecture** de la pose de DoT via `Stats.resolve(base, mods,
   {max=base*3})`. **Aucune nouvelle unité.** Effet immédiat : les auras existantes deviennent des
   `increased` cappés. Golden : peut bouger (changement VOULU des dps bakés) → rebaser. *Le plus haut
   ROI : c'est ce qui fait que le spread héritera de l'ampli.*

2. **ÉTAPE 2 — Spread proportionnel + caps (résout l'anti-climax #1)** : réécrire les 3 ops de spread
   (`poison.spread`, `spread_burn_on_death`, `spread_rot`) pour dériver `spreadDps` du `sourceLoad`
   (§2.2), avec `clamp(MIN,CAP)`, `spreadDur` (§2.3), `once-per-source` (§2.4) et le payload `magnitude`
   (§2.5). C'est l'étape qui rend la **transmission spectaculaire ET bornée**. Mesurer le spread dans
   la sim (dégâts par cause = poison/burn/rot via event-log).

3. **ÉTAPE 3 — Signal RENDER « ça s'allume »** : enrichir le payload `spread` (magnitude/capped) + 2
   nouveaux événements `amped` (pose renforcée) et — si l'étape 4 est faite — `shield_cast/reflect/
   overcharge`. Côté RENDER seulement (golden-safe). C'est le « il le SENT » visuel.

4. **ÉTAPE 4 — Boucliers périodiques + 5 renforcements** : nouveau bloc de tick d'aura dans l'arène
   (`u.shieldCaster`, cibles figées au build), puis les 5 axes (valeur/rayon/réflexion/cd/surcharge)
   avec leurs caps (§3.4). Livrer **avec** le counter (relique strip-shield / cleave) — loi du même lot.
   Une unité « caster de bouclier périodique » + 1-2 pièces de renforcement pour la démo Proving Ground.

5. **ÉTAPE 5 — Cap global + audit de snowball** : implémenter le verrou §1.3-2 (somme des inc clampée
   par instance) et un test (`tests/stats.lua` ou un nouveau) qui prouve qu'aucun empilement ne dépasse
   ×3 / rayon 2 / spread CAP. Auto-itération sim N=400 : vérifier qu'aucune paire n'a un `lift` aberrant
   après l'ampli (le détecteur de combos cassés).

**Pourquoi cet ordre** : 1 débloque l'héritage d'ampli (sans lui, le spread reste pauvre), 2 livre le
gros gain ressenti, 3 le rend visible, 4 ouvre le 2ᵉ système (boucliers) maintenant que le contrat est
prouvé, 5 verrouille les garde-fous. Étapes 1-3 = la transmission spectaculaire (priorité). 4-5 =
généralisation + sécurité.

---

## 7. Tests à ajouter (déterministes, caps = assertions)

- **stats** : `resolve` respecte `max` (cap par axe) ; somme d'`increased` clampée à +200 %.
- **spread** : `spreadDps` croît avec `sourceLoad` PUIS plafonne au CAP ; `once-per-source` empêche la
  re-infection (combat figé, compter les événements `spread`) ; profondeur de saut = 1.
- **boucliers** : re-cast périodique au bon cd ; réflexion ≤ 60 % ; overcharge ≤ 2× ; cd plancher 2 s.
- **golden** : inchangé tant qu'aucune unité n'active une nouvelle voie (mods nil = base). Rebaser
  explicitement quand une étape change un dps baké (étape 1).
- **props/fuzz** : PV ≥ 0, terminaison, 1 vainqueur tiennent avec l'ampli (le cap empêche le runaway).

---

## 8. Ce qu'on NE fait PAS (cohérence avec la boussole)

- **Pas de `more` empilables sans limite** (réservé reliques, ≤2) — l'exponentiel reste interdit.
- **Pas de spread auto-propageant** (profondeur 1 par défaut) — pas de réaction en chaîne incontrôlée.
- **Pas d'aura calculée en combat** — auras build-résolues, arène autonome (snapshot/async préservés).
- **Pas de bouclier-miroir 100 %** ni d'invincibilité (caps réflexion/surcharge).
- **Pas de retune des magnitudes sans sim** — les STEPs (+50 %, frac 0.60/0.75) sont des placeholders ;
  les **CAPS** (×3, 12/14/8, rayon 2, 60 %, 2×, 2 s) sont des **bornes de conception** à conserver.

> Références : `effects-design.md` (§1 modificateurs, §3 paliers anti-snowball — RÉVISÉ ici, §4
> counterplay), `effects-amplification-modifiers.md`, `effects-dot-families.md` §H (spread/transforms),
> code vérifié : `src/effects/stats.lua`, `src/effects/ops.lua`, `src/combat/arena.lua`
> (`tickDots/damage/hit/dischargeShock`), `src/scenes/build.lua` (résolution d'aura build-time).
