# The Pit — Spec de refonte des effets (FINALE, durcie)

> **Statut** : SPEC SOURCE — document autoritaire pour les phases d'implémentation (moteur → contenu →
> équilibrage → commandants/murmures live+UI). Supersede `effects-overhaul-spec.DRAFT.md` (à supprimer).
> Réconcilie les deux brainstorms (`commanders-and-effect-diversity-brainstorm.md`,
> `murmures-hidden-affinities-brainstorm.md`) avec la **faisabilité moteur vérifiée ligne-à-ligne**
> (lecture du code 2026-06-24 : `arena.lua`, `engine.lua`, `stats.lua`, `ops.lua`, `relics.lua`,
> `build.lua`, `run/state.lua`, `snapshot.lua`, `check.sh`) et les recherches comparatives.
>
> **On ne change QUE les effets** des ~79-83 créatures existantes (visuels/familles/noms/types figés).
> **On ne réinvente pas** les décisions actées : reliques **lisibles** (`relics-design.md`),
> progression/éco **verrouillée** (`progression-economy-prd.md`), familles DoT
> (`effects-design.md`, `effects-dot-families.md`). On **corrige** ce qui n'était pas faisable/déterministe
> dans les brainstorms et le DRAFT (cf. §11, journal de convergence).
>
> **Boussole** : faisable-moteur, **déterministe / async-vérifiable / golden-safe**, qui crée la
> **tension de placement** et le **build-around dopaminergique** des références. Tous les chiffres =
> **PLACEHOLDERS** à tuner via `tools/sim.lua` (§9). **Aucune RNG dans le chemin de dégât.**

---

## Sommaire

1. Diagnostic chiffré
2. Vocabulaire d'effets agnostiques (le cœur) — durci
3. Familles = thèmes
4. Système de tiers d'unités
5. Reliques à 3 paliers nets + cadence ~8/run
6. Commandants
7. Murmures (couche cachée — secondaire/easter-egg)
8. **Liste ordonnée des changements moteur** (keystones d'abord) — *le plan d'implémentation*
9. Méthodologie d'équilibrage
10. Annexe — recherche
11. **Journal de convergence** (critique → résolution)
12. **Questions ouvertes** (avec défaut raisonnable)

---

## 1. Diagnostic chiffré

### 1.1 La monoculture (le problème central)

| Mesure | Valeur | Lecture |
|---|---|---|
| Roster total | ~83 unités | — |
| Effet principal = poser/amplifier une **affliction** | **~63 (75,9 %)** | monoculture DoT confirmée |
| Triggers : `on_hit` | **~63 / 91 effets (~69 %)** | un seul verbe domine : « frappe → applique X » |
| `combat_start` | ~19 | surtout auras DoT + boucliers |
| `on_attacked` / `on_attack` / `on_death` / aucun | 4 / 2 / 3 / 4 | les axes non-DoT sont des miettes |
| Enablers agnostiques (multicast / empower / vuln / hâte-aura / crit / execute) | **0** | le gisement vide |
| Vrais stat-sticks sans effet (palier « hanté ») | **4** (`bandit`, `husk`, `footman`, `mire_thing`) | palier BAS quasi inexistant |
| Synergies positionnelles non-DoT/non-bouclier | **0** | aucune unité ne change le **comportement** d'un voisin |

### 1.2 Les 5 familles DoT sont mécaniquement interchangeables

burn / bleed / poison / rot / shock partagent le même **verbe** (`on_hit → applique`). Les twists
(weaken, slow, ampute, charge) sont des paramètres, pas des verbes distincts. **Conséquence** : il n'y a
**qu'un archétype profond** (« empile un DoT »), décliné 5 fois en réskin.

### 1.3 Les lacunes structurantes (ce qu'il faut combler)

1. **Aucune classe multiplicative.** Tout est additif (chaque stack = +X plat). Balatro prouve que la
   tension `additif vs multiplicatif` est le cœur de l'arc de partie. Il manque les **enablers**
   (multicast/empower/vuln) qui *multiplient toute source*.
2. **Aucun carry amplifiable.** Les gros-dmg-brut (`deep_kraken` 12, `witch` 13, `galvanizer` 11,
   `skull_colossus` 11) ne bénéficient d'**aucun** amplificateur de dégâts d'attaque (l'amplification
   existante est DoT-only). La structure « enablers empilent → 1-2 carries massacrent » est absente.
3. **Synergie positionnelle pauvre.** Les seules auras d'adjacence build-résolues = 4 amplis-DoT
   (soot/clot/miasma/decay) + le bloc bouclier.
4. **Tiers non lisibles.** T1-T2 = surtout des *params* du même op DoT. Pas de palier BAS net (« hanté »),
   pas de palier HAUT net assez nombreux.
5. **Grant-affliction conditionnel, synergie-famille-à-l'achat, triggers `on_kill`/`on_low_hp`/`on_ally_death`** :
   absents ou codés en dur (3 croisements rares non réutilisables).
6. **Reliques : ~4-5/partie** (cible user ~8) et la plupart amplifient *encore* des afflictions.

**Cause racine** : le moteur a *déjà* la grammaire `{trigger × op × target × condition}`
(`engine.lua`). La monoculture n'est pas un manque de moteur, c'est une table EFFECT remplie à 80 % de
DoT, avec la colonne TARGET câblée en dur dans chaque op. **La sortie = enrichir la colonne EFFECT
(enablers agnostiques) + généraliser `target` en data via un seul handler `aura_stat`.**

---

## 2. Vocabulaire d'effets agnostiques (le cœur) — durci

> Principe (a327ex / Balatro) : une unité = `TRIGGER × EFFET × CIBLE × CONDITION`. On peuple la colonne
> EFFET de **verbes agnostiques des afflictions** + on généralise la colonne CIBLE.
> **Légende mapping** : `existing` = champ/op déjà câblé · `new-op` = 1 op à `register` · `new-field` =
> 1 champ lu dans arena · `keystone` = débloqué par un des 5 keystones (§8).

### 2.0 Règle d'or transversale (gravée, NON négociable)

1. **Toute amplification s'applique en `increased` (additif) sur la stat de BASE**, jamais sur le total
   amplifié, jamais en `more` (réservé à des cas rares bornés). La couche `Stats` le fait déjà
   (additif, sans tri = déterminisme gratuit). C'est l'Underlord *Atrophy Aura* : anti-explosion late.
2. **AUCUNE RNG dans le chemin de dégât (`damage()`).** `damage()` est **réentrant** (réflexion de
   bouclier `arena.lua:292-298`, amputation `:300`, décharge choc, fatigue) : un `rng:random()` y serait
   appelé un nombre de fois **dépendant du contexte** → désync async garantie. Toute RNG seedée (crit,
   esquive) se résout **edge-triggered, une seule fois par swing, en AMONT du damage**, dans `hit()`
   (`on_attack` pour le crit) ou dans un pré-check dédié de `hit()` (esquive), **jamais** par-coup-entrant.
3. **Re-frapper se fait au niveau `update()`** (boucle de swing), **JAMAIS** en rappelant `hit()` depuis
   un op (le `ctx` est UNE table réutilisée → aliasing). Les nouveaux triggers différés (`on_kill`,
   `on_ally_death`) utilisent un **ctx dédié** (`killCtx`/`allyDeathCtx`), comme `deathCtx` aujourd'hui.
4. **Champs combat-time initialisés à `nil` dans `makeUnit`** → inertes → golden-safe (comme
   `poisonInc`/`dmgReduce`). Tout nouveau champ suit cette règle.

### 2.1 Tempo / multiplicateurs (la classe multiplicative manquante)

| Verbe | Effet | Trigger | Mapping moteur | Déterminisme / garde-fou |
|---|---|---|---|---|
| **Écho / Multicast** | l'unité re-frappe `N×` par swing (multiplicateur **ENTIER**) | `combat_start` pose `u.multicast` (int ≥1) | **K3** : bouclé dans `Arena:update`, `for k=1,min(u.multicast,MULTICAST_MAX) do if u.target and u.target.alive then self:hit(u,u.target) end end`. JAMAIS via op. | 100 % (zéro RNG) ; **cap dur `MULTICAST_MAX=3`** ; contrat §2.1.1 ci-dessous |
| **Hâte (aura)** | voisin/équipe : `−X%` cooldown | `combat_start` target=role | **existing** `haste` (`cd*(1-haste)`) ; **K1** bake le champ | plancher cd `cd*(1+atkSlow)` non franchi ; cap `haste≤0.40` |
| **Cadence (self)** | l'unité frappe plus/moins vite (commandant lent) | `combat_start` | **existing** `haste` (positif) **+ new-field `cdMult`** (commandant) | `cdMult≥1` ralentit ; borne `[1.0, 2.5]` |

#### 2.1.1 Contrat Multicast (gravé — corrige le blocker « K3 re-entre dans hit() N× »)

`multicast` rejoue le **pipeline complet** de `hit(u, u.target)`. Effets de bord non-idempotents bornés
explicitement :

- **Re-ciblage** : AUCUN. Si `u.target` meurt au sous-coup k, les sous-coups k+1..N sont **perdus**
  (voulu : multicast ≥2 = mono-cible). Re-check `u.target and u.target.alive` avant chaque sous-coup.
- **Consommables** : `firstHit` (`bonus_first`) ET la décharge choc (`dischargeShock` vide le
  condensateur) se consomment au **1er sous-coup** (les sous-coups 2-3 ne les retrouvent pas). C'est
  cohérent et **doit être testé** (idempotence des consommables, `tests/synergies.lua`).
- **Épines / `on_attacked`** : un multicast×3 sur un porte-épines prend **3× les épines** (peut
  s'auto-tuer). C'est **voulu et borné** (les épines sont une stat plate, cap dur `MULTICAST_MAX=3`).
  Test obligatoire `multicast × porte-épines` (§9.1).
- **`self.deaths`** : chaque sous-coup peut tuer → pousse dans `self.deaths` ; le broadcast `on_death`
  reste **différé en fin de frame** (inchangé). L'ordre est figé par §2.4.1.

### 2.2 Amplification offensive (le payoff des carries)

| Verbe | Effet | Trigger | Mapping moteur | Déterminisme / garde-fou |
|---|---|---|---|---|
| **Empower (aura)** | voisin/équipe : `+X%` dégâts d'attaque (`increased`) | `combat_start` target=role | **K1+K2** : bake **`source.atkInc`** (PAS `dmgInc` — collision, cf. §2.6) ; `ctx.amount = Stats.resolve(ctx.amount, {increased=source.atkInc})` dans `hit()` | additif → ordre-indépendant ; cap `atkInc` cumulé `≤+1.50` ; sur la BASE jamais le total |
| **Vulnérabilité / Marque** | l'ennemi frappé prend `+X%` de **toutes** sources (frappe ET DoT) | `on_hit` pose `target.vulnInc` | **K2** : `damage()` applique `Stats.resolve(amount, {increased=target.vulnInc})` (à côté du template `plagueAmp`, `arena.lua:248`) | additif ; **edge-triggered** (refresh, pas cumul/frame) ; cap `vulnInc≤+0.50` ; durée bornée (expire au tick) |
| **Crit / Sauvagerie** | `chance%` seedée → ×2 dégâts de la frappe | **`on_attack`** (mute `ctx.amount`) | **new-op** : `condition.kind="chance"` (déjà câblé, `engine.lua:29`, via `ctx.arena.rng`) → `ctx.amount = ctx.amount*2` | **RNG seedée AVANT damage** (conforme §2.0.2) ; chance bornée `≤0.35` ; ne re-proc PAS un on_hit |
| **Exécution** | si `victim.hp/maxHp < seuil` → frappe `+X%` | **`on_attack`** | **new-op** : lit `ctx.victim.hp/maxHp`, mute `ctx.amount` | pur état ; seuil bas `<25%` ; bonus borné ; jamais d'execute (le commandant est `untargetable`, pas frappable) |

### 2.3 Sustain / défense agnostique

| Verbe | Effet | Trigger | Mapping moteur | Déterminisme / garde-fou |
|---|---|---|---|---|
| **Armure plate (self/aura)** | `−X%` dégâts d'attaque | `combat_start` | **existing** `dmgReduce` (amputé sur `cause=attack` uniquement, `arena.lua:257`) ; aura via **K1** | cap `dmgReduce≤0.60` ; n'agit que sur `cause=attack` |
| **Regen (aura)** | voisin/équipe : `+X` PV/s | `combat_start` target=role | **existing** `regen` tické ; **K1** bake | accumulation ENTIÈRE ; contre = `pierceHeal`/rot anti-heal (existants) |
| **Soin-on-kill** | le tueur se soigne de `X` | **`on_kill`** (new-trigger) | **T-on_kill** + new-op : soigne `ctx.source` (= killer), `killCtx` dédié | file `self.kills` array+ipairs hors réentrance ; soin borné `≤maxHp` |
| **Purge / Cleanse** | retire ses propres afflictions (1× ou périodique) | `combat_start` / **`on_low_hp`** | **new-op** : vide `u.dots` ciblées | pur ; **nouvel axe de contre anti-DoT** ; pas un reset infini (1×, ou cd) |
| **Esquive** *(murmures only)* | `chance%` seedée annule 1 frappe entrante | **dans `hit()` (PAS `damage()`)** | **dodge pré-check seedé** : `hit()` roll `ctx.arena.rng` **avant** `damage`, edge-triggered/swing | **BLOQUÉ** tant que le contrat snapshot §7.4 n'est pas vert ; réservé murmures `≤10%` ; rebaseline golden à l'adoption |

### 2.4 Grant-affliction, croisements & triggers de mort (réutilisables)

| Verbe | Effet | Trigger | Mapping moteur | Déterminisme / garde-fou |
|---|---|---|---|---|
| **Inoculation (grant conditionnel)** | pose l'affliction X **SEULEMENT SI absente** → ouvre un 2e DoT | `on_hit` | **new-op** `grant_affliction_if_absent {family}` : lit `target.dots[family]`, pose si nil | pur état ; 2e affliction faible/courte ; pas de double-stack |
| **Conversion croisée** | DoT A présent → ajoute/convertit en DoT B | `on_hit` | **existing** (déjà en dur : `convert_to_rot`) → **généraliser** op data `{from, to}` | pur, edge-triggered ; borné par les caps de chaque famille |
| **Building (scaling intra-combat)** | gagne `+stat` à chaque allié mort ce combat | **`on_ally_death`** (new-trigger) | **T-on_ally_death** : 3e boucle au broadcast différé, `allyDeathCtx` dédié | array+ipairs ; **stats only, jamais dégât immédiat** ; cap de cumul ; ordre §2.4.1 |

#### 2.4.1 Ordre FIXE du broadcast de fin de frame (gravé — corrige le blocker on_kill/on_ally_death)

`damage()` pousse désormais dans la file de morts un **enregistrement** `{victim, killer=opts.source}`
(au lieu de la seule victime). En fin de frame (`arena.lua:626`), résolution dans cet **ordre déterministe** :

1. **`on_kill`** au `killer` (si `killer.alive`) — `killCtx` dédié. *(soin/scavenger ; on_kill heal borné.)*
2. **`on_death`** aux **ennemis vivants** du mort (`w.team ~= dead.team`) — **comportement existant
   inchangé** (`deathCtx`, propagation DoT).
3. **`on_ally_death`** aux **alliés vivants** du mort (`w.team == dead.team`), **en sautant les morts de
   la frame** (un allié mort cette frame ne reçoit pas `on_ally_death`) — `allyDeathCtx` dédié, **stats
   only**.

Itération externe sur `self.deaths` (ordre de mort) en array+ipairs ; itération interne sur `self.units`
en array+ipairs. **Aucun `pairs`.** Test obligatoire : double-mort simultanée + `on_ally_death` building
(`tests/synergies.lua`) fige l'ordre.

### 2.5 Comportement positionnel / méta

| Verbe | Effet | Trigger | Mapping moteur | Déterminisme / garde-fou |
|---|---|---|---|---|
| **Cleave / Éclaboussure** | la frappe touche les voisins-champ de la cible | `on_hit` | **new-op** : `neighborsOf(target)` (déterministe, `arena.lua:216`), `damage(nb, …, cause="cleave")` **profondeur 1** | **AUCUN on_hit/dischargeShock secondaire** (anti-boucle) ; `ignoreShield=false` ; morts suivent l'ordre §2.4.1 |
| **Focus-fire (aura)** | voisin vise la **même cible** que l'allié X | `combat_start` | **K1** pose `focusWith` ; tie-break dans `chooseTarget` | **effet FAIBLE assumé** : ne change pas le ciblage de colonne, juste le tie-break ⟹ inerte si X et le voisin ne partagent pas la colonne avant. Documenté comme tel (cf. §11). Reclassé **tier MOYEN-bas** (pas un build-definer) |
| **Synergie-famille-à-l'achat** | acheter une autre unité de sa `family` → buff **permanent** (même si revendue) | au build (RunState) | **F-RunState** : compteur **MONOTONE** `familyCount[family]` → bake `+stat` (`increased`) au `buildComp` | SIM-pur ; **compteur JAMAIS décrémenté à la vente** (gravé) ; DR cappé `cap N copies` ; **capture snapshot** : cf. §2.5.1 |

### 2.6 Champs `increased` combat-time (liste exhaustive — corrige la collision `dmgInc`)

Pour éviter toute confusion avec les **params de relique build-time** (ex. `famines_math.dmgInc`,
`relics.lua:35`, consommé une fois par `R.apply` au build), les champs **lus en combat** par
`Stats.resolve` portent des noms **distincts et exhaustifs** :

| Champ combat-time | Effet | Posé par | Lu dans |
|---|---|---|---|
| **`source.atkInc`** | empower (+% dégâts d'attaque sortants) | K1 (aura/commandant) | `hit()` (K2) |
| **`target.vulnInc`** | vulnérabilité (+% dégâts entrants, frappe ET DoT) | `grant_vuln` (on_hit) | `damage()` (K2) |
| **`source.statInc`** | commandant `target=level:N`/`tier:N` (+% stats globales) | K1 (commandant) | bake au build (stats) + lecture combat selon stat |

**Aucun** ne porte le même nom qu'un param de relique/aura existant. **`makeUnit` (`arena.lua:105-131`)
les initialise à `nil`** (golden-safe, comme `poisonInc`/`dmgReduce` déjà présents).

#### 2.5.1 Contrat synergie-famille & snapshot (gravé — corrige le blocker F-RunState)

- `familyCount[family]` est un **compteur MONOTONE** : **incrémenté à l'achat** (`RunState:buy`),
  **JAMAIS décrémenté à la vente** (`RunState:sell` ne le touche pas). « Le buff persiste même si
  revendue » = c'est volontaire et doit être gravé pour qu'un dev ne le décrémente pas par symétrie.
- Le bonus est baké au `buildComp` en `increased` sur la base, **plafonné** (DR : `min(count, CAP)`).
- **Capture snapshot (point dur)** : `snapshot.lua:toComp` reconstruit les stats depuis `Units[id]` +
  level-mult ; il **ne capture PAS** un bonus baké custom → un ghost rejouerait une unité **plus faible**
  (divergence async). **Décision** : le snapshot doit encoder un **`statBonus` par unité** (un petit jeu
  de mods `increased` baké), réinjecté par `toComp`. **Tant que le schéma snapshot n'encode pas ce
  bonus, la synergie-famille reste un effet LOCAL (solo/build courant) et N'EST PAS servie en ghost**
  (le ghost rejoue la base). Cf. K-snapshot §8 et Q-snapshot §12.

---

## 3. Familles = thèmes (identité diversifiée au-delà des afflictions)

> Principe TFT (« Inkborn Fables ») : toute grande verticale DOIT avoir 1-2 *primary stars* (carries
> égoïstes qui scalent quand la famille est dense). La famille reste un **thème** (lore/visuel) ;
> mécaniquement elle est diversifiée. On NE refait PAS les visuels — on RE-MAPPE les effets des ids
> existants. Squelette par famille : **2-3 enablers** (DoT de base) · **1 amplificateur agnostique**
> (empower/vuln/hâte/multicast) · **1-2 carries** (gros dmg qui scalent grâce au cumul positionné) ·
> **1 support/contre** (purge, armure, focus).

| Famille (thème) | DoT/identité | Enabler agnostique greffé (qui) | Carry à amplifier (qui) | Support/contre (qui) |
|---|---|---|---|---|
| **Burn / Forge** | brûlure décroissante (burst) | **Hâte-aura** sur `bellows_priest` | `pyre_tender` (burn front-load) | `cinder_cur` (refresh) ; purge anti-feu |
| **Bleed / Bêtes** | saignement + slow | **Multicast-aura** sur une bête (l'exemple-fondateur de l'user) | `razorkin`/`gash_fiend` amplifiés | `hookjaw` (contrôle tempo) |
| **Poison / Abyssal** | stacks + weaken | **Vuln-on-hit** sur `corruptor` (marque → tout passe ×) | `witch`/`deep_kraken` (apex glass-cannon) | `bile_spitter` (weaken) |
| **Rot / Cour nécrotique** | enfle + ampute PVmax | **Empower-aura** sur `maggot_king` | `rot_hound`/`bore_worm` (attrition) | `gravewarden` (tank/taunt) |
| **Shock / Chœur d'orage** | condensateur, décharge | **Empower/vuln** (le choc EST l'ampli natif) | `thunderhead`/`stormcaller` | `storm_anchor` (persistance) |
| **Order / Séraphins** | boucliers / tank / taunt | **Armure-aura + focus-fire** (`templar`) | — (famille support, pas de carry égoïste : assumé) | `siege_breaker` (strip-shield) |
| **Constructs / Rouages** | stat-sticks robustes | **Synergie-famille-à-l'achat** | `runestone_golem`/`skull_colossus` (carry empower) | `rust_sentinel` (armure) |
| **Hors-la-loi / Crustacés** | burst d'ouverture (`bonus_first`) | **Crit / Exécution** | `marauder` (burst carry) | `bandit` (stat-stick, palier bas) |

**Le levier de tension de placement** : un carry (`witch`) **veut** la portée du multicast-aura ET du
empower-aura ET le bon nœud du sigil (centre = 4 voisins). Construire le board = trouver le placement qui
empile le plus d'enablers sur 1-2 carries. **C'est le dilemme visé.**

---

## 4. Système de tiers d'unités

> Modèle (Balatro / SAP / Bazaar) : la complexité monte avec le tier ; le **bas est grok-able**, le
> **haut réécrit une règle**. Le `rank` (1-5) est la source de vérité (`cost = rank`, PRD §4.2). Trois
> leviers d'escalade SAP : **élargir la CIBLE** · **enrichir la CONDITION** · **monter d'un MÉTA-NIVEAU**
> (T1 agit sur des stats ; T5 agit sur des *abilities*).

| Palier | rank | Critère | Profil d'effet | Exemples (ids) |
|---|---|---|---|---|
| **BAS (« hanté »)** | 1 | aucun op neuf ; cible=self ; petits nombres | stat-stick, ou stat-stick + 1 micro-statut (1 dps) | `bandit`, `husk`, `footman`, `mire_thing` + ~8 promus |
| **BAS-MOYEN** | 2 | 1 enabler mono-DoT simple, aucun twist | « pose 1 affliction » | `emberling`, `rot_grub`, `stormcaller` |
| **MOYEN** | 3 | enabler + 1 petit modificateur, OU 1 enabler agnostique léger (hâte-aura, regen-aura) | torsion/aura qui change un voisin sans réécrire de règle | `corruptor`, `gash_fiend`, **`bellows_priest` (hâte-aura)** |
| **MOYEN-HAUT** | 4 | enabler + twist fort, OU amplificateur agnostique fort (empower-aura, vuln) | aura qui rend un voisin qualitativement meilleur | `pyre_tender`, `templar`, **`maggot_king` (empower-aura)** |
| **HAUT (réécrit une règle)** | 5 | change une loi : multicast, `grant_team`, transform de famille | « tes AUTRES unités fonctionnent différemment » | `ash_maw`, `deep_kraken`, **la bête multicast**, `skull_colossus` |

**Garde-fous** (`effects-design.md §3`) :
- T1/T2/T3 scalent par niveau (duplicatas). **Le haut-tier ne scale QUE ses stats** — jamais son seuil,
  sa bascule, ni son nombre de cibles (anti double-snowball).
- **Loi de puissance des doublons** (PRD §4.3) : rank-1 niveau 3 rivalise EN STATS BRUTES avec
  rank-3/4 niveau 1, sans voler leur **identité d'effet**.
- Aucun haut-tier ne dépend d'une **case précise** (cassé au swap de sigil) — uniquement d'un *type* ou
  d'un *rôle géométrique* (cf. §6.2.1). L'adjacence PEUT conditionner un moyen (T2).

---

## 5. Reliques à 3 paliers nets + cadence ~8/run

> Décision actée (`relics-design.md`) : **lisibles** (nom + effet clair + flavor), team-wide,
> intra-combat, égalisateur. On NE revient PAS aux leurres. Le champ `tier` existe déjà (`relics.lua`) ;
> on **formalise 3 paliers de NATURE** (pas de magnitude) — remède au ressenti « toutes au même tier ».

### 5.1 Le principe par palier

| Palier | Nature | Mapping moteur dominant |
|---|---|---|
| **BAS (Argent)** | **stats plates** universelles | `relic_flat_hp`, `relic_more_dmg`, `relic_dmg_reduce`, `relic_haste` (existants) |
| **MOYEN (Or)** | **transformatif léger** : conditionnel / par famille / par position | `relic_affliction_inc`, `aura_stat` team (empower/vuln), comptés conditionnels |
| **HAUT (Prismatique)** | **réécrit une RÈGLE** (comme une unité T5) | `relic_add_effect` → `grant_team` (multicast-team borné, pierceHeal, no-cap…) |

**Critère dur (Riot Champion Augments)** : un palier HAUT ne doit JAMAIS être « +30 % ». Il (a) ajoute une
ligne d'effet absente des bas paliers, OU (b) franchit un *seuil* qui change le comportement (cap→no-cap,
1×→2× multicast, mono→chaîne).

> **Mapping `tier` actuel → 3 paliers de nature** : `tier 1` → BAS ; `tier 2-3` → MOYEN ; `tier 4+` →
> HAUT. Aucun renommage du champ : on **regroupe** pour l'offre et la cadence (`maxRelicTier` existe déjà,
> `state.lua:353`).

### 5.2 Exemplars par palier (mappés moteur)

**BAS — stats plates (existants)** : Pierre-de-sang (`relic_more_dmg`), Carapace (`relic_flat_hp`),
Égide (`relic_dmg_reduce`), Pierre-à-aiguiser (`relic_haste`).

**MOYEN — transformatif léger**
- **Bol-du-Roi** : `+X%` dps poison → `relic_affliction_inc {poison}` (existant).
- **Bannière de Sang** (NOUVEAU) : équipe `+10%` dégâts d'attaque (`increased` sur base) →
  `relic_add_effect {combat_start, aura_stat, {stat=atkInc, target=team, value=0.10}}` (**K1+K2**).
- **Marque du Voyant** (NOUVEAU) : les frappes posent `vuln +15%` 2 s →
  `relic_add_effect {on_hit, grant_vuln, {value=0.15, dur=2}}` (**K2**). L'exposition universelle.
- **Math de la Famine** : `≤3 unités → +X%` (existant ; `p.dmgInc` reste un **param de relique** au build,
  distinct de `atkInc` combat — cf. §2.6).

**HAUT — réécrit une règle**
- **Couronne d'Échos** (NOUVEAU) : l'unité la plus **avancée** gagne `+1 multicast` (mono-cible, fort) →
  `relic_add_effect {combat_start, aura_stat, {stat=multicast, target=role:front, value=1}}` (**K1+K3**).
  Le payoff build-around signature.
- **Langue Fourchue** : le choc rebondit → `grant_team {shockChain}` (existant).
- **Communion Pestilentielle** : `2+ afflictions → +dégâts` → `grant_team {plagueAmp}` (existant).
- **Brûle-Toujours** : le burn ne décroît plus → `grant_team {burnNoDecay}` (existant).

### 5.3 Cadence d'acquisition (~8 reliques/partie) — chiffrée

> Objectif user : passer de ~4-5 à **~8 reliques/partie** sans casser l'éco ni la lisibilité, aligné
> `progression-economy-prd.md §5`. Modèle TFT : **mixer 3 canaux**, ne pas tout donner au même jalon.
> **État du code** : canaux 1 et 2 existent (`main.lua:121` marchand `% 3` ; `offerLevelUpRelic` borné
> `relicFromLevelThisRound`). **Canal 3 (jalon de palier) est le manquant** → c'est le travail à faire.

| Canal | Cadence | Source (code) | Rendement/run |
|---|---|---|---|
| **1. Marchand** | tous les **3 combats** (victoire OU défaite) | `main.lua:121` `(wins+losses) % 3` ; écran `relicpick` 1-parmi-3 ; refuser → `declineRelic` (+or) | **~3-4** |
| **2. Level-up d'unité** | **1 récompense max/round** | `host.offerLevelUpRelic` + `state.relicFromLevelThisRound` (reset `startRound`) ; cascade incluse | **~2-3** |
| **3. Jalon de palier** (NOUVEAU) | à la **3e et 6e victoire** : 1 relique de palier supérieur **garanti** (cérémonie de boss) | nouveau hook `host.finishCombat` : `if win and (wins==3 or wins==6)` → `relicpick` forcé, tier ≥ MOYEN | **2** |

**Chiffrage cible ~8** : Canal 1 ≈ 3-4 · Canal 2 ≈ 2-3 · Canal 3 = 2 → **somme ≈ 7-9, moyenne ~8**. Le
**decline→+or** (`declineRelic`) absorbe le surplus sans inflation (la relique non prise devient de l'or).

**Tiérage par avancée** (existant `maxRelicTier`, `state.lua:353`) : early (0-1 win) → BAS · mid (2-4) →
MOYEN · late (5+) → HAUT. Garde-fous (PRD §5.4) : HAUT **OFF les ~2-3 premiers combats** (anti-snowball,
déjà garanti par `maxRelicTier`) ; rareté HAUT atteignable en fin de run (canal 3 le garantit).

**Anti double-comptage (gravé)** : si la 3e/6e victoire **coïncide** avec un jalon marchand (`% 3`), on
ne sert **qu'un seul** écran `relicpick` (priorité au jalon de palier, tier supérieur). Le compteur
`(wins+losses) % 3` n'est pas re-déclenché ce combat. Test `tests/run.lua` (cadence + non-doublon).

---

## 6. Commandants

> Spec finale réconciliant `commanders-...` avec les ENGINE FACTS. Forks tranchés.

### 6.1 Mécanique finale

- **Slot supplémentaire** hors du graphe de sigil (un **piédestal** distinct → lisible « pas
  d'adjacence »). **Opt-in, débloqué en cours de run** (comme les slots), jouable sans au début.
- **Intouchable / invulnérable** : `isCommander=true` + `untargetable=true`. Voir §6.4 pour les **deux**
  endroits où `chooseTarget` doit l'exclure.
- **Corps = VOIE A** (fork F1) : invuln + **cadence lente** (`cdMult ~1.5-2`, un seul cadran qui nerf
  proportionnellement dégâts bruts ET applications de DoT). Garde **tout son kit**. Repli sur **B (fanal
  pur, n'attaque pas)** si la sim révèle un DPS-gratuit dégénéré.
- **Condition de défaite** : le décompte de victoire (`arena.lua:642-659`) **filtre**
  `and not u.isCommander` → **board mort = défaite même si le commandant vit**. Le commandant seul ne
  gagne rien.
- **Perd ses synergies d'adjacence** (hors graphe). Le vrai moteur de profondeur : un bon commandant =
  celui dont l'**aura multiplie le mieux le board**, pas le plus fort perso (découple « bonne unité » et
  « bon leader »).
- **Affligeable/soignable par l'ennemi** : NON (untargetable) ; reçoit les buffs team-wide de SA team.

### 6.2 Budget portée × puissance (l'axe d'équilibrage)

> **Budget = magnitude × nombre de cibles.** L'aura passe par **K1** (`aura_stat`, target=rôle
> géométrique dérivé du sigil = **sigil-invariant**, zéro table par-sigil).

| Portée | Puissance | Cible (`target`) |
|---|---|---|
| **Équipe** | faible | `target=team` |
| **Sous-ensemble conditionnel** | moyenne/forte | `target=tier:N` / `level:N` |
| **Une seule unité** | **très forte** | `target=role:front`/`role:back`/`role:center` |

#### 6.2.1 Résolution des rôles géométriques (gravé — corrige le major K1 « role:front sous-spécifié »)

Les rôles sont résolus **au build** dans `buildComp`, avec un tie-break **IDENTIQUE à `chooseTarget`**
(sinon le commandant choisit une cible d'aura différente du ciblage de combat = non-déterminisme
silencieux) :

- **`role:front`** = `min(depth)` ; tie-break **row asc, puis slot asc** (exactement `chooseTarget`,
  `arena.lua:201-202`).
- **`role:back`** = `max(depth)` ; **même tie-break** (row asc, slot asc).
- **`role:center`** = le **nœud à 4 voisins du graphe du sigil** (lu sur `board.shape`, **pas** le
  `depth`). Si aucun nœud n'a 4 voisins (sigil ligne/anneau), fallback déterministe sur `role:front`.

Le `depth` étant `maxCol - cell.x`, les sigils à `cell.x` **fractionnaire** (anneau — dette connue
`CLAUDE.md`) restent bien définis : le tie-break ordonné lève toute ambiguïté. **Test obligatoire**
`tests/auras.lua` : résoudre les 3 rôles sur **LES 5 SIGILS** → résultat **unique et stable** (anneau
fractionnaire inclus). Sans ce test, `role:front` est un nid à non-déterminisme.

### 6.3 Exemplars (6, un par groupe)

| Commandant | Aura (portée → puissance) | `aura_stat` |
|---|---|---|
| **Le Tambour de Guerre** | équipe `+8%` cadence | `{stat=haste, target=team, value=0.08}` |
| **Le Calice de Sang** | équipe `+5%` vol de vie | `{stat=lifesteal, target=team, value=0.05}` |
| **L'Aïeul** | unités **niveau 1** : `+40%` stats | `{stat=statInc, target=level:1, value=0.40}` |
| **Le Roi des Rats** | unités **tier-1** : `+50%` PV & dmg | `{stat=statInc, target=tier:1, value=0.50}` |
| **La Couronne d'Échos** | la plus **avancée** : `+1` multicast | `{stat=multicast, target=role:front, value=1}` |
| **La Bannière du Bris-Siège** | combat_start : boucliers ennemis `÷2` | `grant_team {stripEnemyShield}` |

**Combo le plus dangereux à border** (fork F11) : Couronne d'Échos → `corruptor` (devant) + miasma-aura
(voisin) : `+1` multicast double la pose de stacks ET de weaken, l'aura voisine amplifie. Caps existants =
garde-fous (`POISON_STACK_CAP=8`, `WEAKEN_CAP=0.40`, `MULTICAST_MAX=3`). **À simuler avant déploiement (§9.1).**

### 6.4 Changements moteur commandant (gravé — corrige le major §6)

1. **`chooseTarget` exclut `isCommander` aux DEUX endroits** :
   - dans le calcul de `minDepth` (`arena.lua:187`) : `... and o.team ~= a.team and not o.isCommander ...`
     — **sinon un commandant untargetable au front fausse la colonne avant de TOUS les ennemis** ;
   - dans la boucle de sélection (`arena.lua:197-198`) : même `and not o.isCommander`.
2. **`damage()`** : `if target.isCommander then return 0 end` (réutilise le pattern invuln
   `arena.lua:247`). Le commandant n'a **pas** de PV pertinents (affichage cosmétique).
3. **`cdMult`** : câbler dans le timer (`arena.lua:581`) :
   `u.atkTimer = u.cd * (1 + u.atkSlow) * (1 - (u.haste or 0)) * (u.cdMult or 1)`. `nil → 1` (golden-safe).
4. **Fatigue & commandant-vs-commandant** : la **FATIGUE frappe les commandants** (`damage` retourne 0
   pour eux, donc l'usure ne les tue pas — mais comme le **décompte de victoire les exclut**, un combat
   commandant-vs-commandant se conclut dès que les deux **boards** sont morts). **Test `tests/props.lua`** :
   fuzz avec un commandant **des deux côtés** → terminaison garantie (le board meurt, la fatigue conclut).
5. **Décompte de victoire** : `arena.lua:642-659` filtre `and not u.isCommander` (déjà prévu §6.1).
6. **Snapshot** : étendre `capture/encode/decode/toComp` avec le **champ commander** (id + aura). **Dette
   connue** — à traiter AVANT d'activer les commandants en multi async (sinon le ghost rejoue un build
   faux). **Bloquant pour le multi, pas pour le solo** (cf. K-snapshot §8).
7. **UI** : piédestal hors-graphe ; au survol → **éclairer les unités affectées** (portée visible) ;
   barre de cadence lente lisible.

---

## 7. Murmures (couche cachée — secondaire/easter-egg)

> Spec finale réconciliant `murmures-...` avec les ENGINE FACTS. **Secondaire** : du spice, jamais
> build-defining. Contrat §2.1 du brainstorm conservé.

### 7.1 Mécanique finale

- **3e capacité cachée** par unité, liée au **lore** (lignée = duo / solitaire = conditionnel).
- **Plafond de magnitude (gravé)** : `~10%` de stat (`increased`, via K1/K2) **OU** 1 effet ponctuel
  one-shot. Tout effet plus fort **gradue en couche visible** (passif ou commandement).
- **Cryptique JUSQUE DANS LE LOG** : le Journal nomme les **unités** (« par la présence de [Y], [X] a été
  renforcé… »), **JAMAIS la valeur**. Découverte par **observation**.
- **Seedé + snapshoté + rejouable** : toute RNG via `ctx.arena.rng` (jamais global).

### 7.2 Architecture (gravé — corrige le blocker « whispers.lua hors firewall »)

**Décision : data déclarative dans `src/data`, exécution par ops dans `src/effects`** (cohérent avec le
pattern `relics.lua` = data / `ops.lua` = exécution).

- `src/data/whispers.lua` = registre **PUREMENT déclaratif** : `id → { kind, trigger, condition, op,
  params, key }`. **Aucune fonction, aucun `math.random`, aucun `love.*`** — uniquement des descripteurs
  de données. (Il vit hors `SIM_DIRS` de `check.sh` ; le garder déclaratif **élimine** le risque qu'un
  RNG global y passe le check inaperçu, exactement le blocker soulevé.)
- Toute la **logique** (résolution présence/adjacence au build ; condition au tick/seuil ; pose de
  l'effet ; **roll seedé** éventuel) vit dans un **op du registre** (`src/effects/`, **dans `SIM_DIRS`**,
  couvert par le firewall RNG + le garde golden). Le murmure = un effet `{trigger, op, params}` injecté
  comme les autres, résolu par `Effects.run` avec `ctx.arena.rng`.
- **Garde-fou CI complémentaire (recommandé)** : ajouter une ligne dans `check.sh` qui **interdit
  `function`/`math.random`/`love.` dans `src/data/whispers.lua`** (lint « data pure »). C'est moins
  fragile que d'ajouter `src/data` entier à `SIM_DIRS` (qui contient `units.lua`, `relics.lua`,
  `encounters.lua` — data légitime sans RNG, mais le scan deviendrait bruyant). Trancher en §12 (Q-whisper).

### 7.3 Format d'événement (2 canaux)

```
bus:emit("murmur", {
  key, source, partner|nil, verb,           -- CANAL JOUEUR : phrasé cryptique i18n, ZÉRO chiffre
  trueKind, trueValue                        -- CANAL DEV : event-log JSONL, vraie magnitude (sim/tuning)
})
```
Verbes vagues (joueur) : `renforcé` · `frappe plus fort` · `se dérobe` · `endure` · `se repaît`.
**Golden-safe** : `murmur` est RENDER-only (comme `affliction_applied`) — aucun abonné SIM ne change
l'issue au-delà de l'effet lui-même.

### 7.4 Esquive (dodge) — BLOQUÉE jusqu'au contrat snapshot (corrige le blocker)

L'esquive est le **seul murmure RNG** et le **seul vrai risque déterministe** (RNG dans le chemin de
frappe). Reclassée **« bloquée jusqu'à test snapshot vert »**, pas « rebaseline et go » :

1. **Implémentation** : roll seedé **dans `hit()`** (PAS `damage()`), **edge-triggered une fois par
   swing**, **AVANT** le `damage` (conforme §2.0.2). Si esquive → le swing rate, aucun `damage` appelé.
2. **Pré-condition d'activation** : un test `tests/snapshot.lua` DOIT d'abord vérifier que `toComp`
   **réinjecte les murmures des DEUX camps** (sinon le ghost roule la seed un nombre différent de fois →
   **tout** le combat diverge, pas juste l'esquive). **Tant que ce test n'existe pas et n'est pas vert,
   le dodge hook reste OFF.**
3. Les murmures **non-RNG** (type `+10%` stat, one-shot) sont **sûrs et suffisent pour la v1** : ils
   passent par K1/K2 (additif, déterministe), zéro risque async. **On livre les murmures sans esquive
   d'abord.**
4. **REBASELINE golden** uniquement si une unité **du scénario golden** adopte un murmure RNG (les placer
   hors du scénario golden d'abord = pas de rebaseline).

### 7.5 Exemplars (6, liés au lore — tous NON-RNG sauf Le Lâche, gardé OFF jusqu'à §7.4)

| Murmure | Type | Unités | Condition | Effet (spice) |
|---|---|---|---|---|
| **Le Pacte** | lignée | `witch` ↔ `demon` | adjacence | 1er sang du démon → petit sursaut de venin (one-shot) |
| **Le Cercle de la Forge** | lignée | `bellows_priest` ↔ `pyre_tender` | adjacence | 1re brûlure de la paire plus intense (one-shot) |
| **Le Conclave** | lignée | `deep_kraken` ↔ sa couvée | présence du kraken | couvée `+10%` stat |
| **Le Festin** | solo | `demon` | sous `~30%` PV (`on_low_hp`) | `+10%` vol de vie |
| **Vaisseau Creux** | solo | `husk` | à la mort d'un allié (`on_ally_death`) | `+10%` stat (cumul borné) |
| **Le Lâche** *(OFF v1)* | solo | `bandit` | la plus au fond | `5-10%` esquive (dodge hook) — **bloqué §7.4** |

---

## 8. Liste ordonnée des changements moteur (keystones d'abord)

> Chacun : step · fichier · changement précis · dépendance · **stratégie golden-safe**. Ordre =
> dépendances + rendement. **Règle dure** : re-frapper au niveau `update()` ; nouveaux triggers différés
> = ctx dédié ; aucune RNG dans `damage()`. **Tous les keystones sont golden-safe par construction** (nil
> = inerte) tant qu'aucune unité du **scénario golden** ne porte l'effet.

### 8.1 Phase MOTEUR (keystones — débloquent tout le reste)

| Step | Fichier | Changement | Dépend | Golden-safe |
|---|---|---|---|---|
| **1. K1 — `aura_stat` générique** | `src/scenes/build.lua` (`buildComp`, ~l.823-928) | UN handler qui bake `{stat=haste/atkInc/dmgReduce/regen/vulnApply/multicast/lifesteal/statInc/focusWith, target=neighbors/role:front/back/center/team/tier:N/level:N, value}` sur le spec. **Foyer unique** des auras agnostiques ET des commandants. **Rôles résolus par §6.2.1** (tie-break = chooseTarget). Écritures **additives/commutatives** (`+=`) → l'usage de `pairs(casters)` existant (`build.lua:895`) reste sûr **mais on grave** : `aura_stat` itère `placed` en `ipairs`, écrit par-slot indépendant. | — | aucun champ posé tant qu'aucune unité ne porte l'effet → empreinte inchangée |
| **2. K2 — Stats sur dmg sortant + entrant** | `src/combat/arena.lua` (`hit` ~l.319, `damage` ~l.248-254) | `hit()` : `ctx.amount = Stats.resolve(ctx.amount, source.atkInc and {Stats.increased(source.atkInc)} or nil)` (empower). `damage()` : `amount = Stats.resolve(amount, target.vulnInc and {Stats.increased(target.vulnInc)} or nil)` (vuln, à côté de `plagueAmp`). **Nom `atkInc`** (PAS `dmgInc`, collision §2.6). | — | `atkInc/vulnInc=nil` → Stats renvoie la base. **Aucune unité golden ne les porte** → empreinte inchangée |
| **3. K3 — Multicast entier** | `src/combat/arena.lua` (`update`, bloc swing ~l.591-598) | `u.multicast` (int≥1) → `for k=1,min(u.multicast or 1, MULTICAST_MAX) do if u.target and u.target.alive then self:hit(u,u.target) end end`. Cap `MULTICAST_MAX=3`. **JAMAIS via op.** Contrat §2.1.1 (consommables/épines/morts). | K1 (bake `multicast`) | `multicast=nil`→1 (défaut). Tenir **hors golden** (susceptible de rebaseline même gated) |
| **4. K4 — Slot Commandant** | `src/combat/arena.lua` (`chooseTarget` 184-209 **aux deux endroits**, `damage` 247, timer 581 `cdMult`, victoire 642-659, fatigue) | `isCommander`/`untargetable` (new-field) ; `chooseTarget` exclut `isCommander` **dans minDepth ET dans la sélection** (§6.4) ; `damage` retourne 0 ; `cdMult` câblé ; décompte filtre ; fatigue OK (§6.4.4). | — | aucune unité `isCommander` au golden → inerte |
| **5. T-on_kill** | `arena.lua` (`damage` ~273-282 pousse `{victim,killer}` ; broadcast fin de frame ~626) | file `self.deaths` enrichie `{victim, killer=opts.source}` ; `on_kill` au killer **(ordre §2.4.1 step 1)**, `killCtx` dédié. Débloque soin-on-kill, scavenger, execute-payoff. | — | gated (aucune unité ne l'écoute) ; **enrichir `self.deaths` en table-record est interne** → vérifier que le broadcast `on_death` existant lit `rec.victim` (refacto mécanique, golden inchangé si le scénario n'a pas de killer-effet) |
| **6. T-on_ally_death** | `arena.lua` (broadcast différé ~626-639, **ordre §2.4.1 step 3**) | 3e boucle aux alliés VIVANTS du mort (skip morts de la frame), `allyDeathCtx` dédié, **stats only**. | step 5 (file enrichie) | gated |
| **7. T-on_low_hp** | `arena.lua` (fin `damage` ou `tickDots`) | edge-trigger `u._thresholdFired[seuil]` (pas par-frame). Débloque purge/festin. | — | gated |

### 8.2 Phase CONTENU & ÉCO (data + reliques)

| Step | Fichier | Changement | Dépend | Golden-safe |
|---|---|---|---|---|
| **8. new-ops agnostiques** | `src/effects/ops.lua` | `register` : `crit` (on_attack ×2 via `condition.kind="chance"`), `execute` (on_attack, lit hp%), `grant_vuln` (on_hit pose `vulnInc`), `grant_affliction_if_absent`, `convert_dot {from,to}` (généralise `convert_to_rot`), `cleave` (on_hit, profondeur 1, §2.5), `heal_on_kill` (on_kill), `purge` (on_low_hp/combat_start). | K2, steps 5-7 | data + ops ; gated (aucune unité golden ne les porte) |
| **9. Re-map des effets du roster** | `src/data/units.lua` | RE-MAPPER les effets des ids existants selon §3 (familles=thèmes) + §4 (tiers). **Par vagues vertes** (enablers → auras agnostiques → carries → supports), chaque vague committée. **Rebaseline golden** à chaque vague qui touche une unité du scénario golden (et SEULEMENT alors). | steps 1-8 | **rebaseline contrôlée** par vague ; sim saine (σ, entropie) avant commit |
| **10. F-RunState — synergie-famille** | `src/run/state.lua` (`buy`/`sell`) + `src/scenes/build.lua` (bake) | compteur **MONOTONE** `familyCount[family]` (incr. `buy`, **jamais** décr. `sell`) → bake `+stat increased` (DR cappé) au buildComp. **Effet LOCAL** tant que le snapshot ne l'encode pas (§2.5.1). | K1 | SIM-pur ; n'affecte que les unités porteuses ; **NON servi en ghost** sans K-snapshot |
| **11. R-relics — 3 paliers + canal 3** | `src/data/relics.lua`, `src/run/state.lua`, `src/scenes/main.lua` host | regrouper `tier` en 3 paliers de nature (§5.1) ; ajouter **Bannière de Sang / Marque du Voyant / Couronne d'Échos** (`relic_add_effect` + `aura_stat`) ; **canal 3** (`finishCombat` : `if win and (wins==3 or wins==6)` → relicpick forcé tier≥MOYEN) ; **anti double-comptage** §5.3. | K1, K2, K3 | reliques = data + `R.apply` au build ; canal 3 = routage host (hors SIM) ; golden combat inchangé tant qu'aucune relique du scénario golden ne change |

### 8.3 Phase COMMANDANTS / MURMURES (live + UI)

| Step | Fichier | Changement | Dépend | Golden-safe |
|---|---|---|---|---|
| **12. Commandants data + UI** | `src/data/units.lua` (bonus de commandement par unité), `src/scenes/build.lua` (piédestal), render | 6 commandants v1 (§6.3) via `aura_stat` ; piédestal hors-graphe ; survol = portée éclairée ; barre cadence lente. | K1, K4 | aura build-résolue → l'arène ne connaît pas le plateau (zéro couplage) |
| **13. K5 — Couche Murmures (sans esquive)** | `src/data/whispers.lua` (data **déclarative pure**, §7.2) + op(s) dans `src/effects/` + `src/core/bus.lua` (event `murmur`) + i18n | registre data résolu au build + tick/death via op du registre ; event 2 canaux ; **dodge OFF**. | K1, K2, steps 5-7 | registre vide → zéro émission ; `murmur` RENDER-only |
| **14. K-snapshot — schéma async étendu** | `src/net/snapshot.lua`, `tests/snapshot.lua` | encoder/réinjecter : **commander (id+aura)**, **`statBonus` par unité** (synergie-famille, §2.5.1), **murmures des deux camps** (§7.4). **Pré-requis** pour servir commandants/synergie-famille/murmures-RNG **en ghost**. | steps 10, 12, 13 | nouveau champ optionnel ; ghosts v0 (sans ces effets) inchangés ; **débloque le dodge hook §7.4** une fois vert |
| **15. Dodge hook (esquive)** | `src/combat/arena.lua` (`hit()` pré-check seedé) + `whispers` | roll seedé AVANT damage, edge/swing (§7.4). **Activé SEULEMENT après step 14 vert.** | step 14 | rebaseline golden si une unité golden l'adopte (sinon hors golden) |

**Tâches roadmap moteur directement débloquées** : « Buckets de modifiers (% de stat) » = K2 ;
« Work-queue d'effets (budget 256) » = devient nécessaire si multicast×cleave chaîne (K3+cleave) — borné
par `MULTICAST_MAX=3` × profondeur-1 du cleave, donc pas de budget infini à v1.

---

## 9. Méthodologie d'équilibrage

> Outils existants : `tools/sim.lua` (win%/unité, dmg/cause, part DoT, TTK p10/p50/p90, **lift de
> co-occurrence = détecteur de combos cassés**, drapeaux d'outliers), `tools/relicsim.lua`,
> `tools/scenariosim.lua`, `tools/runsim.lua`, `tests/synergies.lua`, `tests/props.lua`. `PIT_HP_MULT=N`
> balaie la durée. **Principe : un levier à la fois. Bas tier faible / haut tier fort.**

### 9.1 Matrice d'interactions (zéro angle mort)

Toutes les paires d'enablers (multicast / empower / vuln / hâte / crit / execute / grant-affliction /
building / focus-fire / cleave) × (5 familles DoT + brut + bouclier). Pour chaque paire : **compatible**
(lift 1.1-1.5) ou **incompatible-assumé** (anti-synergie documentée, lift ~1.0). **Triples + cas durs
obligatoires** :

| Cas | Risque | Validation |
|---|---|---|
| **multicast × empower × vuln** | 3 multiplicateurs composés → explosion | `tests/synergies.lua` + `lift` ; sous le cap de chaque couche |
| **multicast × afflicteur × ampli-DoT** (Couronne × corruptor × miasma) | snowball poison | caps `POISON_STACK 8 / WEAKEN 0.40 / MULTICAST_MAX 3` tiennent |
| **empower × crit × execute** (burst pur) | one-shot | clamp dégâts ; TTK p10 ne s'effondre pas |
| **multicast × porte-épines** (§2.1.1) | auto-kill du multicaster | borné (3× épines plates, cap 3) — **test explicite** |
| **multicast × choc** (consommable §2.1.1) | décharge consommée 1× | idempotence vérifiée — **test explicite** |
| **cleave × multicast** | morts simultanées, ordre broadcast | ordre §2.4.1 figé — **test explicite** |
| **commandant des deux côtés** (§6.4.4) | non-terminaison | `tests/props.lua` fuzz → terminaison (board+fatigue) |
| **double-mort + on_ally_death** (§2.4.1) | ordre de broadcast | `tests/synergies.lua` fige l'ordre |

### 9.2 Configs de masse par bandes de puissance

Trois **bandes** (teams réalistes par stade), croisées avec **chaque relique** et **chaque commandant** :

| Bande | Composition type | Reliques | Commandants |
|---|---|---|---|
| **EARLY** | stat-sticks rank-1/2, 3-4 slots, 1 sigil | BAS uniquement | aucun / conditionnels tier-1 |
| **MID** | enablers rank-3, 5-6 slots, doublons niv.2 | BAS+MOYEN | tous |
| **END** | carries rank-5 amplifiés, 9 slots, multicast | tous paliers | tous |

**Couverture exhaustive** : chaque bande × chaque relique × chaque commandant (matrice façon `runsim.lua`).
Une chose n'est déclarée équilibrée **qu'une fois ce balayage passé**.

### 9.3 Cible d'archétypes & métrique de viabilité

**Cible (sweet-spot genre)** : **14-18 archétypes viables & distincts** (~5-6 unités/archétype pour ~79
unités, digeste). Refs : TFT ~26 viables / HSReplay « 26 viable comps » / SAP ~19 / Bazaar ~3-4/héros.
14-18 = poison/burn/bleed/rot/shock (×5) + brut/wide/tall/tank/bruiser + chaque enabler ouvrant 1-2 axes
(multicast-carry, empower-line, vuln-spread…).

**Métrique de viabilité (seuil d'équilibre)** :
- **win% contextualisé par investissement/coût** : viable si win% ≥ 50 % **à coût comparable** (une END
  chère DOIT battre une EARLY).
- **présence côté gagnant** : aucune unité/relique/commandant ne dévie de `>2σ` (drapeau `sim.lua`).
- **diversité** : entropie de Shannon des archétypes gagnants ≥ **0,90** (la sim sort déjà ~0,99 en P5).

**Déclaration « équilibré »** ssi, après §9.2 : (a) win% dans `±2σ`, (b) `lift` de co-occurrence < 1,6
(pas de combo cassé), (c) entropie ≥ 0,90. Sinon → tuner **un levier** et re-balayer. **Bas tier faible /
haut tier fort** = vérifié par le win% contextualisé (un rank-1 lvl-1 ne bat jamais un rank-5 amplifié à
coût égal).

---

## 10. Annexe — sources (croisées avec ENGINE FACTS)

- **SAP / grammaire composable** : a327ex.com/posts/super_auto_pets_mechanics ; superautopets.wiki.gg.
- **TFT** : Inkborn Fables Learnings, Runeterra Reforged Learnings (Legends retirés = méta forcée) ;
  augments à 3 tiers (Silver/Gold/Prismatic) ; tft.ninja (positioning).
- **The Bazaar** : thebazaar.wiki.gg (Keywords, Multicast, Haste) ; internal cooldown (anti-boucle) →
  confirme le cap multicast entier.
- **Backpack Battles** : backpackbattles.wiki.gg (stars/diamonds, amplificateurs).
- **Balatro** : balatrowiki (Activation Sequence) ; LocalThunk (pacte 4 lignes/20 mots) ; additif vs
  multiplicatif ; building-jokers.
- **Dopamine/rétention** : GMTK (Balatro feedback) ; Garfield « Looking Within » ; Dota Underlord Atrophy
  Aura (base vs total) ; HS:BG (Deathwing board-wide faible vs buffs ciblés forts) ; Wildfrost (leader
  persistant, mort = défaite).
- **Sweet-spot archétypes** : HSReplay « 26 viable comps » ; StS ~15-20 reliques/run ; TFT 3 augments.
- **Internes** : `commanders-and-effect-diversity-brainstorm.md`, `murmures-hidden-affinities-brainstorm.md`,
  `relics-design.md`, `progression-economy-prd.md`, `effects-design.md`, `effects-dot-families.md`.

---

## 11. Journal de convergence (critique adversariale → résolution)

> 5 lentilles. Chaque issue **blocker/major** est traitée ; les minors notés.

### Blockers

| # | Critique (lentille faisabilité) | Résolution dans la spec |
|---|---|---|
| B1 | **`whispers.lua` hors `SIM_DIRS`** : un RNG global y passerait le check inaperçu. | **§7.2** : `whispers.lua` = **data PUREMENT déclarative** (zéro fonction/RNG/love) ; la **logique + RNG** vivent dans un **op de `src/effects/`** (dans `SIM_DIRS`, sous firewall + golden). Garde-fou CI « data pure » optionnel sur `whispers.lua`. Pattern `relics.lua`(data)/`ops.lua`(exécution). |
| B2 | **Dodge hook = RNG dans `damage()` réentrant** → désync async ; rebaseline insuffisant. | **§2.0.2 + §7.4** : RNG **interdite dans `damage()`** ; esquive = roll **dans `hit()`, edge/swing, AVANT damage**. Reclassée **« bloquée jusqu'à test snapshot vert »** (step 15). Murmures non-RNG livrés d'abord (v1 sans esquive). |
| B3 | **Multicast K3 re-entre dans `hit()` N×** : dischargeShock/firstHit/thorns/morts non spécifiés. | **§2.1.1** (contrat gravé) : re-check `target.alive`, pas de re-ciblage (frappes perdues), firstHit+choc consommés au 1er sous-coup, 3× épines borné par `MULTICAST_MAX=3`, morts → ordre §2.4.1. Tests explicites §9.1 (épines, choc, cleave×multicast). |

### Majors

| # | Critique | Résolution |
|---|---|---|
| M1 | **K1 `role:front` sous-spécifié** (tie-break, depth fractionnaire anneau) + `pairs(casters)`. | **§6.2.1** : `role:front=min(depth)` tie-break **row asc/slot asc = chooseTarget** ; `role:center` = nœud 4-voisins du **graphe** (pas depth) ; `role:back=max(depth)`. **Test sur les 5 sigils** (anneau inclus). `aura_stat` itère `placed` en `ipairs`, écritures par-slot indépendantes (le `pairs(casters)` existant reste sûr car commutatif, **gravé**). |
| M2 | **Collision `dmgInc`** (relique `relic_few_units` build-time vs champ combat). | **§2.6 / K2** : champ combat renommé **`atkInc`** ; le param de relique `famines_math.dmgInc` reste tel quel (build-time, sémantique distincte). Liste des champs increased combat : `atkInc` (empower), `vulnInc` (vuln), `statInc` (commandant). `makeUnit` les initialise à `nil`. |
| M3 | **Commandant : `minDepth` faussé + `cdMult` inexistant + fatigue commandant-vs-commandant.** | **§6.4** : `chooseTarget` exclut `isCommander` **aux deux endroits** (minDepth ET sélection) ; `cdMult` câblé au timer `:581` ; fatigue frappe les commandants (damage=0) mais le **décompte de victoire les exclut** → conclusion par mort du board ; **test props.lua** commandant des deux côtés. |
| M4 | **`on_kill`/`on_ally_death` : tueur non capturé, ordre non figé.** | **§2.4.1** : `self.deaths` enrichi `{victim, killer=opts.source}` ; ordre FIXE fin de frame : (1) on_kill killer, (2) on_death ennemis (existant), (3) on_ally_death alliés vivants (skip morts de frame), stats-only. ctx dédiés. Test double-mort fige l'ordre. |
| M5 | **Cleave/focus-fire mal bornés** (explosion + focus-fire inerte). | **§2.5** : cleave `cause="cleave"`, profondeur 1, **zéro on_hit/choc secondaire**, morts → ordre §2.4.1 ; test cleave×multicast §9.1. **Focus-fire reclassé effet FAIBLE assumé** (tie-break only, inerte hors colonne avant), documenté, sorti du tier HAUT. |
| M6 | **F-RunState : décrément à la vente + capture snapshot.** | **§2.5.1** : compteur **MONOTONE** (jamais décrémenté), gravé ; bonus baké `increased` cappé ; **snapshot ne capture pas le bonus** → synergie-famille **effet LOCAL, NON servi en ghost** tant que K-snapshot (step 14) n'encode pas `statBonus`. |

### Minors notés (sans bloquer)

- **`igniteAt`/`ignited` & autres flags d'unité** : `makeUnit` ne les initialise pas explicitement (posés
  par les ops). Cohérent (nil=inerte), mais à **vérifier** que les nouveaux champs (`atkInc`, `vulnInc`,
  `multicast`, `cdMult`, `isCommander`, `untargetable`, `focusWith`) sont bien posés à `nil` dans le
  `unit = { … }` de `makeUnit` (golden-safe explicite), comme `poisonInc`.
- **`MULTICAST_MAX=3` + cleave profondeur 1** bornent la work-queue → la tâche roadmap « budget 256 »
  n'est pas requise à v1 (notée comme telle §8.3).
- **Purge** crée un nouvel axe de contre anti-DoT puissant : surveiller qu'il ne **casse pas** l'archétype
  poison (le contre doit incliner, pas effacer — pilier relique §relics-design).
- **Le ratio reliques réel (~4-5 ressenti vs ~5-6 théorique)** : le canal 2 (level-up) est sous-utilisé
  early (peu de fusions) → le **canal 3** comble le creux mid/late. Mesurer le réel via `tools/runsim.lua`
  après step 11.

---

## 12. Questions ouvertes (avec défaut raisonnable — ne bloquent pas)

| # | Question | Défaut proposé |
|---|---|---|
| **Q-corps** (F1) | Corps du commandant : Voie A (invuln+lent) ou repli B (fanal pur) ? | **A** par défaut (préserve « il combat », `damage=0` trivial) ; basculer en **B** si `sim.lua` montre un DPS-gratuit > 2σ. |
| **Q-whisper** | Garde-fou CI : lint « data pure » sur `whispers.lua`, ou ajouter `src/data` à `SIM_DIRS` ? | **Lint ciblé** sur `whispers.lua` (interdit `function`/`math.random`/`love.`) — moins bruyant que scanner tout `src/data`. |
| **Q-snapshot** | `statBonus` par unité dans le schéma snapshot (synergie-famille + commandant + murmures) : v1 maintenant ou différé ? | **Différé à step 14** : v1 = synergie-famille/commandant/murmures **en solo seulement** ; le ghost rejoue la base (légèrement plus faible, acceptable). Activer K-snapshot avant le multi async. |
| **Q-multicast-cap** | `MULTICAST_MAX` = 3 (spec) — assez pour le payoff carry ? | **3** (Bazaar-like, async-vérifiable) ; relever à 4 seulement si la sim montre le multicast sous-joué (peu probable vu l'effet ×). |
| **Q-cleave-shield** | Cleave : `ignoreShield=false` (spec) ou ignore ? | **false** (le cleave respecte les boucliers — lisible, anti-burst). Reconsidérer si le cleave est sous-joué vs murs. |
| **Q-canal3** | Jalon de palier : 3e+6e victoire (spec) ou 4e+8e ? | **3e+6e** (donne 2 reliques HAUT garanties sur une run de 10) ; ajuster si la cadence réelle dépasse ~9 (decline absorbe, mais ajuster le pas). |
| **Q-purge-meta** | Purge : 1× par combat ou périodique (cd) ? | **1×** (lisible, ne reset pas l'archétype DoT à l'infini) ; passer en périodique seulement sur une unité HAUT dédiée anti-DoT. |
| **Q-focusfire** | Focus-fire faible (tie-break) : garder ou couper ? | **Garder en MOYEN-bas**, documenté faible ; le **promouvoir** seulement si on ajoute un vrai « pull de colonne » (T3, hors scope v1). |

---

> **Le DRAFT (`effects-overhaul-spec.DRAFT.md`) est SUPERSEDED par ce document.** Le supprimer.
